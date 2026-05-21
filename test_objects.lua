-- test_objects.lua
-- Regression tests for object-list refresh behavior across map changes.

local original_preload = {}
local original_loaded = {}
local original_memory = _G.memory
local original_rom = _G.rom
local original_and = _G.AND
local original_emulator_compat = _G.DW_EMULATOR_COMPAT
local original_object_reload_state = _G.DW_OBJECTS_RELOAD_STATE

local function save_module(name)
    original_preload[name] = package.preload[name]
    original_loaded[name] = package.loaded[name]
end

local function restore_modules(names)
    for _, name in ipairs(names) do
        package.preload[name] = original_preload[name]
        package.loaded[name] = original_loaded[name]
    end
end

local function make_env(options)
    options = options or {}
    local module_names = {
        "addresses",
        "config",
        "map_reader",
        "maps",
        "navigation",
        "objects",
        "overworld_routes",
    }

    for _, name in ipairs(module_names) do
        save_module(name)
        package.loaded[name] = nil
    end

    _G.DW_OBJECTS_RELOAD_STATE = {}

    local npc_ram = {
        [0] = 0x25, -- sprite type 1 (Guard), x=5
        [1] = 0x07, -- y=7
    }
    local terrain_offset = 0x10
    local nav_map_id = 0x01
    local nav_x = 0
    local nav_y = 0
    local tile_grid_calls = 0
    local large_tiles = options.large_tiles or {}
    local walkable_tiles = options.walkable_tiles or {}
    local directional_blocks = options.directional_blocks or {}

    _G.AND = function(a, b)
        local result = 0
        local bit = 1
        while a > 0 or b > 0 do
            if (a % 2 == 1) and (b % 2 == 1) then
                result = result + bit
            end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            bit = bit * 2
        end
        return result
    end

    _G.memory = {
        readbyte = function(address)
            if address == 0x0016 then
                return terrain_offset
            end
            return npc_ram[address] or 0
        end,
    }

    _G.rom = {
        readbyte = function()
            return 0
        end,
    }

    _G.DW_EMULATOR_COMPAT = {
        is_bizhawk = options.is_bizhawk == true,
    }

    package.preload["addresses"] = function()
        return {
            NPC_COUNT = options.npc_count or 1,
            NPC_DATA_START = 0,
            NPC_ENTRY_SIZE = 3,
            ROM_CHEST_START = 0,
            ROM_CHEST_END = -1,
            ROM_CHEST_SIZE = 4,
            TERRAIN_OFFSET = 0x0016,
        }
    end

    package.preload["navigation"] = function()
        return {
            get_position = function()
                return nav_map_id, nav_x, nav_y
            end,
        }
    end

    package.preload["map_reader"] = function()
        return {
            get_tile_grid = function()
                tile_grid_calls = tile_grid_calls + 1
                return nil
            end,
            get_metadata = function()
                return nil
            end,
            get_map_dimensions = function()
                return options.map_width or 32, options.map_height or 32
            end,
            is_large_tile = function(map_id, x, y)
                return large_tiles[string.format("0x%02X:%d,%d", map_id, x, y)] == true
            end,
            is_walkable = function(map_id, x, y)
                return walkable_tiles[string.format("0x%02X:%d,%d", map_id, x, y)] == true
            end,
            get_directional_blocks = function(map_id)
                return directional_blocks[map_id]
                    or directional_blocks[string.format("0x%02X", map_id)]
                    or {}
            end,
        }
    end

    package.preload["maps"] = function()
        local M = {
            WORLD_MAP_ID = 0x01,
            get_name = function(map_id)
                return string.format("Map %02X", map_id)
            end,
        }
        function M.is_overworld(map_id, terrain_offset_arg)
            return terrain_offset_arg == 0x00 or map_id == M.WORLD_MAP_ID
        end
        return M
    end

    package.preload["config"] = function()
        return {
            get = function(key)
                if key == "bizhawk_periodic_npc_refresh" then
                    return options.bizhawk_periodic_npc_refresh or "false"
                end
                if key == "bizhawk_map_entry_prewarm_path_grid" then
                    return options.bizhawk_map_entry_prewarm_path_grid or "false"
                end
                return nil
            end,
        }
    end

    local objects = require "objects"

    return {
        objects = objects,
        set_terrain_offset = function(value)
            terrain_offset = value
        end,
        set_npc = function(slot, byte0, byte1, byte2)
            local base = slot * 3
            npc_ram[base] = byte0
            npc_ram[base + 1] = byte1
            npc_ram[base + 2] = byte2 or 0
        end,
        set_position = function(map_id, x, y)
            nav_map_id = map_id
            nav_x = x
            nav_y = y
        end,
        get_tile_grid_calls = function()
            return tile_grid_calls
        end,
        reload_objects = function()
            package.loaded["objects"] = nil
            objects = require "objects"
            return objects
        end,
        restore = function()
            restore_modules(module_names)
            _G.memory = original_memory
            _G.rom = original_rom
            _G.AND = original_and
            _G.DW_EMULATOR_COMPAT = original_emulator_compat
            _G.DW_OBJECTS_RELOAD_STATE = original_object_reload_state
        end,
    }
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local tests = {}

function tests.world_map_refresh_drops_stale_interior_npcs()
    local env = make_env()

    env.objects.refresh(0x1F)
    assert_equal(env.objects.get_count(), 1, "interior maps should still parse active NPC RAM")

    env.set_terrain_offset(0x00)
    env.objects.refresh(0x01)
    assert_equal(#env.objects.get_blocking_positions(), 0, "world map should not treat stale NPC RAM as blockers")

    env.objects.next_filter()
    assert_equal(env.objects.get_count(), 0, "world map should expose no NPC entries after switching to the NPC filter")

    env.restore()
end

function tests.dungeon_refresh_drops_stale_town_npcs()
    local env = make_env({npc_count = 4})

    env.set_position(0x08, 1, 15)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x60 + 5, 0x04, 0x00)
    env.set_npc(1, 0x20 + 4, 0x08, 0x00)
    env.set_npc(2, 0xC0 + 15, 0x18, 0x00)
    env.set_npc(3, 0x60 + 25, 0x19, 0x00)
    env.objects.refresh(0x08)
    env.objects.next_filter()
    assert_equal(env.objects.get_count(), 4, "town map should expose live NPC RAM")

    env.set_position(0x1C, 0, 0)
    env.set_terrain_offset(0x20)
    env.objects.on_map_change(0x1C, {previous_map_id = 0x08})
    env.objects.all_filter()
    assert_equal(env.objects.get_count(), 2, "dungeon map should keep only static exit/stair objects")

    env.objects.next_filter()
    assert_equal(env.objects.get_count(), 0, "dungeon NPC filter should not expose stale town NPCs")

    for _ = 1, 100 do
        env.objects.check_refresh(0x1C)
    end
    env.objects.all_filter()
    assert_equal(env.objects.get_count(), 2, "dungeon map should not force-accept stale NPC RAM after retries")
    env.objects.next_filter()
    assert_equal(env.objects.get_count(), 0, "dungeon NPC filter should stay empty after refresh checks")

    env.restore()
end

function tests.erdricks_cave_static_stairs_use_live_confirmed_coordinates()
    local env = make_env()

    env.set_terrain_offset(0x20)
    env.objects.refresh(0x1C)
    local b1_stair
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.type == env.objects.TYPE_STAIR then
            b1_stair = obj
            break
        end
    end
    assert_equal(b1_stair ~= nil, true, "Erdrick B1 should expose a static stair object")
    assert_equal(b1_stair.id, "stair_9_9", "Erdrick B1 stair id should match the live trigger")
    assert_equal(b1_stair.x, 9, "Erdrick B1 stairs should be at the live-confirmed x coordinate")
    assert_equal(b1_stair.y, 9, "Erdrick B1 stairs should be at the live-confirmed y coordinate")

    env.objects.refresh(0x1D)
    local b2_stair
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.type == env.objects.TYPE_STAIR then
            b2_stair = obj
            break
        end
    end
    assert_equal(b2_stair ~= nil, true, "Erdrick B2 should expose a static stair object")
    assert_equal(b2_stair.id, "stair_8_9", "Erdrick B2 stair id should match the live trigger")
    assert_equal(b2_stair.x, 8, "Erdrick B2 stairs should be at the live-confirmed x coordinate")
    assert_equal(b2_stair.y, 9, "Erdrick B2 stairs should be at the live-confirmed y coordinate")

    env.restore()
end

function tests.swamp_cave_exposes_distinct_north_and_south_travel_objects()
    local env = make_env()

    env.set_terrain_offset(0x20)
    env.objects.refresh(0x15)

    local north_exit
    local south_stair
    local stale_corridor_exit
    local entrance_stair
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.type == env.objects.TYPE_STAIR then
            if obj.x == 0 and obj.y == 29 then
                south_stair = obj
            elseif obj.x == 0 and obj.y == 0 then
                entrance_stair = obj
            end
        elseif obj.type == env.objects.TYPE_EXIT then
            if obj.x == 0 and obj.y == 0 then
                north_exit = obj
            elseif obj.x == 0 and obj.y == 25 then
                stale_corridor_exit = obj
            end
        end
    end

    assert_equal(north_exit ~= nil, true, "Swamp Cave should expose the north world-map exit")
    assert_equal(south_stair ~= nil, true, "Swamp Cave should expose the south-island stairs")
    assert_equal(entrance_stair, nil, "Swamp Cave should not duplicate the north exit as a stairs object")
    assert_equal(stale_corridor_exit, nil, "Swamp Cave west-corridor bend should not be modeled as the south exit")
    assert_equal(north_exit.id, "exit_0_0", "Swamp Cave north exit id should match the entrance tile")
    assert_equal(north_exit.name, "North Exit to World Map", "Swamp Cave north exit should have a distinct label")
    assert_equal(south_stair.id, "stair_0_29", "Swamp Cave south stairs id should match the ROM exit tile")
    assert_equal(south_stair.name, "Stairs Up to South Island", "Swamp Cave south stairs should have a distinct label")

    env.objects.travel_filter()
    local filtered = env.objects.get_objects({filtered = true})
    local swamp_travel_count = 0
    for _, obj in ipairs(filtered) do
        if obj.id == "exit_0_0" or obj.id == "stair_0_29" then
            swamp_travel_count = swamp_travel_count + 1
        end
    end
    assert_equal(swamp_travel_count, 2, "Travel filter should expose both Swamp Cave travel objects for route testing")

    env.objects.set_filter(env.objects.FILTER_DOOR)
    local doors = env.objects.get_objects({filtered = true})
    assert_equal(#doors, 1, "Swamp Cave should expose the live-confirmed Gwaelin locked door")
    local door = doors[1]
    assert_equal(door.id, "door_5_20", "Swamp Cave Gwaelin door id should match the locked-door coordinate")
    assert_equal(door.name, "Gwaelin Door", "Swamp Cave locked door should have a useful navigation label")
    assert_equal(door.x, 5, "Swamp Cave Gwaelin door x should match the live OPEN probes")
    assert_equal(door.y, 20, "Swamp Cave Gwaelin door y should match the live OPEN probes")
    assert_equal(door.interaction_x, 5, "Swamp Cave Gwaelin door should route to the south stand x")
    assert_equal(door.interaction_y, 21, "Swamp Cave Gwaelin door should route to the south stand y")
    assert_equal(door.interaction_face_dir, "north", "Swamp Cave Gwaelin door should face north from the stand")

    env.restore()
end

function tests.terrain_flip_forces_refresh_even_when_map_id_sticks()
    local env = make_env()

    env.objects.check_refresh(0x1F)
    env.objects.next_filter()
    assert_equal(env.objects.get_count(), 0, "initial interior map-change refresh should defer NPC parsing until the next frame")

    env.objects.check_refresh(0x1F)
    assert_equal(env.objects.get_count(), 1, "deferred refresh should expose the active interior NPC")

    env.set_terrain_offset(0x00)
    env.objects.check_refresh(0x1F)
    assert_equal(#env.objects.get_blocking_positions(), 0, "world-map terrain should clear stale interior NPC blockers even with same map id")
    assert_equal(env.objects.get_count(), 0, "world-map NPC filter should stay empty after clearing stale interior NPCs")
    env.objects.next_filter()
    env.objects.next_filter()
    env.objects.next_filter()
    env.objects.next_filter()
    env.objects.next_filter()
    assert_equal(env.objects.get_count() > 0, true, "world-map all filter should replace the stale interior list with landmark objects")

    env.restore()
end

function tests.interior_map_change_defers_npcs_until_next_frame()
    local env = make_env()

    env.set_position(0x04, 10, 10)
    env.set_terrain_offset(0x10)
    env.objects.check_refresh(0x04)
    env.objects.next_filter()
    assert_equal(env.objects.get_count(), 0, "initial interior map-change refresh should defer NPC parsing until the next frame")

    env.objects.check_refresh(0x04)
    assert_equal(env.objects.get_count(), 1, "deferred refresh should populate NPCs on the next frame")
    local castle_npc = env.objects.current_object()
    assert_equal(castle_npc.x, 5, "castle NPC x should match the current RAM bytes after deferred refresh")
    assert_equal(castle_npc.y, 7, "castle NPC y should match the current RAM bytes after deferred refresh")

    env.set_position(0x08, 15, 15)
    env.set_npc(0, 0x2A, 0x09) -- x=10, y=9 with sprite type 1
    env.objects.check_refresh(0x08)
    assert_equal(env.objects.get_count(), 0, "entering a new interior map should suppress stale NPCs on the transition frame")

    env.objects.check_refresh(0x08)
    assert_equal(env.objects.get_count(), 1, "next-frame refresh should populate the new map NPCs")
    local town_npc = env.objects.current_object()
    assert_equal(town_npc.x, 10, "town NPC x should come from the refreshed RAM bytes")
    assert_equal(town_npc.y, 9, "town NPC y should come from the refreshed RAM bytes")

    env.restore()
end

function tests.deferred_map_entry_refresh_is_visible_to_main_loop()
    local env = make_env()

    env.set_position(0x08, 15, 15)
    env.set_terrain_offset(0x10)
    assert_equal(env.objects.needs_refresh(0x08), true, "new map should request an immediate object refresh")

    env.objects.check_refresh(0x08)
    env.objects.next_filter()
    assert_equal(env.objects.get_count(), 0, "transition-frame object list should still defer NPC parsing")
    assert_equal(env.objects.needs_refresh(0x08), true, "deferred NPC rebuild should bypass main-loop throttling")

    env.objects.check_refresh(0x08)
    assert_equal(env.objects.get_count(), 1, "next refresh should populate active town NPCs")
    assert_equal(env.objects.needs_refresh(0x08), false, "settled object list should return to periodic refresh timing")

    env.restore()
end

function tests.map_change_event_refreshes_even_when_map_id_matches_current_cache()
    local env = make_env()

    env.set_position(0x04, 10, 10)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x04)
    env.objects.next_filter()
    assert_equal(env.objects.current_object().x, 5, "test should start with the original map NPC")

    env.set_npc(0, 0x2A, 0x09) -- x=10, y=9 with sprite type 1
    env.objects.on_map_change(0x04)
    assert_equal(env.objects.get_count(), 0, "map-change event should clear stale NPCs immediately")

    env.objects.check_refresh(0x04)
    assert_equal(env.objects.get_count(), 1, "next check should populate NPCs from the new map context")
    assert_equal(env.objects.current_object().x, 10, "refreshed NPC x should come from current RAM")
    assert_equal(env.objects.current_object().y, 9, "refreshed NPC y should come from current RAM")

    env.restore()
end

function tests.map_entry_rejects_previous_map_npc_signature_until_ram_changes()
    local env = make_env()

    env.set_position(0x05, 8, 8)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x05)
    env.objects.next_filter()
    assert_equal(env.objects.current_object().x, 5, "test should start with previous-map NPC RAM accepted")

    env.set_position(0x04, 7, 7)
    env.objects.on_map_change(0x04, {previous_map_id = 0x05})
    assert_equal(env.objects.get_count(), 0, "map entry should clear NPCs while RAM still matches the previous map")

    env.objects.check_refresh(0x04)
    assert_equal(env.objects.get_count(), 0, "deferred refresh should not parse byte-identical previous-map NPC RAM")
    assert_equal(env.objects.needs_refresh(0x04), true, "stale NPC RAM should keep the map-entry refresh active")

    env.set_npc(0, 0x2A, 0x09) -- x=10, y=9 with sprite type 1
    env.objects.check_refresh(0x04)
    assert_equal(env.objects.get_count(), 1, "changed NPC RAM should populate the new map")
    assert_equal(env.objects.current_object().x, 10, "new map NPC x should come from changed RAM")
    assert_equal(env.objects.current_object().y, 9, "new map NPC y should come from changed RAM")
    assert_equal(env.objects.needs_refresh(0x04), false, "settled NPC RAM should end the map-entry retry")

    env.restore()
end

function tests.map_entry_npc_signature_survives_objects_module_reload()
    local env = make_env()

    env.set_position(0x05, 8, 8)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x05)
    env.objects.next_filter()
    assert_equal(env.objects.current_object().x, 5, "test should start with previous-map NPC RAM accepted")

    env.objects = env.reload_objects()

    env.set_position(0x04, 7, 7)
    env.objects.on_map_change(0x04, {previous_map_id = 0x05})
    env.objects.next_filter()
    assert_equal(env.objects.get_count(), 0, "reloaded object module should still reject stale previous-map NPC RAM")

    env.objects.check_refresh(0x04)
    assert_equal(env.objects.get_count(), 0, "reloaded deferred refresh should keep rejecting byte-identical previous-map NPC RAM")
    assert_equal(env.objects.needs_refresh(0x04), true, "reloaded stale NPC RAM should keep the map-entry refresh active")

    env.set_npc(0, 0x2A, 0x09) -- x=10, y=9 with sprite type 1
    env.objects.check_refresh(0x04)
    assert_equal(env.objects.get_count(), 1, "changed NPC RAM should populate the new map after a module reload")
    assert_equal(env.objects.current_object().x, 10, "new map NPC x should come from changed RAM after reload")
    assert_equal(env.objects.current_object().y, 9, "new map NPC y should come from changed RAM after reload")

    env.restore()
end

function tests.map_entry_rejects_observed_previous_map_signature_after_reload()
    local env = make_env()

    env.set_position(0x05, 8, 8)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x05)
    env.objects.next_filter()
    assert_equal(env.objects.current_object().x, 5, "test should start with previous-map NPC RAM accepted")

    env.set_npc(0, 0x26, 0x07) -- previous-map NPC moved after the object list was built
    env.objects.observe_npcs(0x05)
    env.objects = env.reload_objects()

    env.set_position(0x04, 7, 7)
    env.objects.on_map_change(0x04, {previous_map_id = 0x05})
    env.objects.next_filter()
    assert_equal(env.objects.get_count(), 0, "reloaded map entry should reject the latest observed previous-map NPC RAM")

    env.objects.check_refresh(0x04)
    assert_equal(env.objects.get_count(), 0, "observed previous-map NPC RAM should stay hidden until RAM changes")

    env.set_npc(0, 0x2A, 0x09) -- x=10, y=9 with sprite type 1
    env.objects.check_refresh(0x04)
    assert_equal(env.objects.get_count(), 1, "changed NPC RAM should populate after observed stale RAM clears")
    assert_equal(env.objects.current_object().x, 10, "new map NPC x should come from changed RAM")
    assert_equal(env.objects.current_object().y, 9, "new map NPC y should come from changed RAM")

    env.restore()
end

function tests.map_entry_signature_ignores_npc_direction_bits()
    local env = make_env()

    env.set_position(0x05, 8, 8)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x05)
    env.objects.next_filter()
    assert_equal(env.objects.current_object().y, 7, "test should start with previous-map NPC RAM accepted")

    env.set_npc(0, 0x25, 0x47) -- same y=7, changed facing bits
    env.set_position(0x04, 7, 7)
    env.objects.on_map_change(0x04, {previous_map_id = 0x05})
    assert_equal(env.objects.get_count(), 0, "direction-only NPC RAM changes should still be treated as previous-map stale RAM")

    env.objects.check_refresh(0x04)
    assert_equal(env.objects.get_count(), 0, "direction-only stale NPC RAM should stay hidden until coordinates change")

    env.set_npc(0, 0x2A, 0x09)
    env.objects.check_refresh(0x04)
    env.objects.check_refresh(0x04)
    assert_equal(env.objects.get_count(), 1, "changed NPC coordinates should populate the new map")

    env.restore()
end

function tests.startup_object_refresh_primes_previous_map_signature()
    local env = make_env()

    env.set_position(0x05, 8, 8)
    env.set_terrain_offset(0x10)
    env.objects.check_refresh(0x05)
    env.objects.check_refresh(0x05)
    env.objects.next_filter()
    assert_equal(env.objects.current_object().x, 5, "startup object refresh should accept the current map NPC RAM")

    env.set_position(0x04, 7, 7)
    env.objects.on_map_change(0x04, {previous_map_id = 0x05})
    env.objects.all_filter()
    env.objects.next_filter()
    assert_equal(env.objects.get_count(), 0, "primed signature should reject stale NPC RAM after a quick stairs transition")

    env.objects.check_refresh(0x04)
    assert_equal(env.objects.get_count(), 0, "deferred quick-transition refresh should still suppress stale NPC RAM")

    env.set_npc(0, 0x2A, 0x09)
    env.objects.check_refresh(0x04)
    assert_equal(env.objects.get_count(), 1, "changed NPC RAM should populate after the startup-primed transition")

    env.restore()
end

function tests.fceux_map_entry_prewarms_path_grid()
    local env = make_env()

    env.set_position(0x04, 10, 10)
    env.set_terrain_offset(0x10)
    env.objects.check_refresh(0x04)

    assert_equal(env.get_tile_grid_calls(), 1, "FCEUX map entry should keep the old path-grid prewarm behavior")

    env.restore()
end

function tests.bizhawk_map_entry_skips_path_grid_prewarm_by_default()
    local env = make_env({is_bizhawk = true})

    env.set_position(0x04, 10, 10)
    env.set_terrain_offset(0x10)
    env.objects.check_refresh(0x04)

    assert_equal(env.get_tile_grid_calls(), 0, "BizHawk map entry should avoid synchronous path-grid prewarm by default")

    env.restore()
end

function tests.bizhawk_map_entry_prewarm_can_be_opted_in()
    local env = make_env({
        is_bizhawk = true,
        bizhawk_map_entry_prewarm_path_grid = "true",
    })

    env.set_position(0x04, 10, 10)
    env.set_terrain_offset(0x10)
    env.objects.check_refresh(0x04)

    assert_equal(env.get_tile_grid_calls(), 1, "BizHawk map-entry prewarm should stay available as an opt-in")

    env.restore()
end

function tests.world_map_anchor_places_tantegel_nearest_to_live_probe_position()
    local env = make_env()

    env.set_position(0x01, 43, 43)
    env.set_terrain_offset(0x00)
    env.objects.refresh(0x01)

    local obj = env.objects.current_object()
    assert_equal(obj.name, "Tantegel Castle", "live probe position should sort Tantegel Castle first")
    assert_equal(obj.x, 43, "Tantegel Castle x should match the calibrated overworld anchor")
    assert_equal(obj.y, 43, "Tantegel Castle y should match the verified Tantegel transition tile")

    env.restore()
end

function tests.inactive_overworld_route_does_not_clutter_travel_filter()
    local env = make_env()

    env.set_position(0x01, 30, 32)
    env.set_terrain_offset(0x00)
    require("overworld_routes").reset_for_tests()
    env.objects.refresh(0x01)
    env.objects.travel_filter()

    local found_route_marker = false
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        if obj.route_waypoint then
            found_route_marker = true
            break
        end
    end

    assert_equal(found_route_marker, false, "inactive route waypoints should stay out of the Travel list")
    assert_equal(env.objects.get_count(), 14, "plain world-map Travel should only list major destinations")

    env.restore()
end

function tests.active_overworld_route_adds_travel_waypoint()
    local env = make_env()

    env.set_position(0x01, 30, 32)
    env.set_terrain_offset(0x00)
    require("overworld_routes").start("erdric", 0x01, 30, 32)
    env.objects.refresh(0x01)
    env.objects.travel_filter()

    local found = false
    local route_count = 0
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        if obj.route_waypoint then
            route_count = route_count + 1
        end
        if obj.id == "route_erdrick_07" then
            found = true
            assert_equal(obj.name, "Route next: East choke approach", "active route waypoint should be labeled as next")
            assert_equal(obj.type, env.objects.TYPE_EXIT, "route waypoints should appear under Travel")
        end
    end

    assert_equal(found, true, "active route waypoint should be present in the Travel filter")
    assert_equal(route_count, 2, "active route should expose only the next two route waypoints")

    require("overworld_routes").reset_for_tests()
    env.restore()
end

function tests.route_waypoint_can_be_selected_after_route_start()
    local env = make_env()

    env.set_position(0x01, 33, 27)
    env.set_terrain_offset(0x00)
    local info = require("overworld_routes").start("cave", 0x01, 33, 27)
    env.objects.refresh(0x01)
    env.objects.travel_filter()
    local selected = env.objects.select_object_by_id(info.object_id)

    assert_equal(selected.id, "route_erdrick_08", "route start should expose the nearest active route waypoint")
    assert_equal(env.objects.current_object().name, "Route next: Eastern mountain lane", "current object should become the active route waypoint")

    require("overworld_routes").reset_for_tests()
    env.restore()
end

function tests.active_route_refresh_preserves_selected_destination_focus()
    local env = make_env()
    local routes = require("overworld_routes")

    env.set_position(0x01, 30, 32)
    env.set_terrain_offset(0x00)
    routes.reset_for_tests()
    env.objects.refresh(0x01)
    env.objects.travel_filter()
    local selected = env.objects.select_object_by_id("overworld_erdrick_s_cave")
    assert_equal(selected ~= nil, true, "test should start with Erdrick's Cave selected")

    routes.start_for_object(selected, 0x01, 30, 32)
    env.objects.request_refresh()
    env.objects.check_refresh(0x01)
    assert_equal(
        env.objects.current_object().id,
        "overworld_erdrick_s_cave",
        "starting a route should not move focus from the selected destination to the waypoint marker")

    routes.observe_position(0x01, 35, 32)
    env.objects.request_refresh()
    env.objects.check_refresh(0x01)
    assert_equal(
        env.objects.current_object().id,
        "overworld_erdrick_s_cave",
        "advancing an active route should not steal destination focus during object refresh")

    routes.reset_for_tests()
    env.restore()
end

function tests.brecconary_exit_matches_live_west_edge_probe()
    local env = make_env()

    env.set_position(0x08, 0, 15)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x00, 0x00)
    env.objects.refresh(0x08)

    local obj = env.objects.current_object()
    assert_equal(obj.name, "Exit to World Map", "Brecconary should expose its town exit object")
    assert_equal(obj.x, 0, "Brecconary exit should sit on the west-edge entry column")
    assert_equal(obj.y, 15, "Brecconary exit should match the live entry row")

    env.restore()
end

function tests.kol_exit_uses_live_south_entry_tile()
    local env = make_env()

    env.set_position(0x07, 19, 23)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x00, 0x00)
    env.objects.refresh(0x07)

    local obj = env.objects.select_object_by_id("exit_19_23")
    assert_equal(obj ~= nil, true, "Kol should expose the live south town exit")
    assert_equal(obj.name, "Exit to World Map", "Kol should keep the normal town-exit label")
    assert_equal(obj.x, 19, "Kol exit should use the live arrival X")
    assert_equal(obj.y, 23, "Kol exit should use the live arrival/exit row")
    assert_equal(obj.interaction_x, 19, "Kol exit route should stand on the south exit tile")
    assert_equal(obj.interaction_y, 23, "Kol exit stand should match the live exit row")
    assert_equal(obj.interaction_face_dir, "south", "Kol exit stand should face south toward the world")

    env.restore()
end

function tests.garinham_exit_uses_live_west_entry_not_inn_corridor()
    local env = make_env()

    env.set_position(0x09, 1, 14)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x00, 0x00)
    env.objects.refresh(0x09)

    local obj = env.objects.select_object_by_id("exit_0_14")
    assert_equal(obj ~= nil, true, "Garinham should expose the live west-side town exit")
    assert_equal(obj.name, "Exit to World Map", "Garinham should keep the normal town-exit label")
    assert_equal(obj.x, 0, "Garinham exit should use the live entry boundary X")
    assert_equal(obj.y, 14, "Garinham exit should use the live entry row")
    assert_equal(obj.interaction_x, 1, "Garinham exit route should stop on the west entry stand")
    assert_equal(obj.interaction_y, 14, "Garinham exit stand should share the entry row")
    assert_equal(obj.interaction_face_dir, "west", "Garinham exit stand should face out toward the world")

    env.restore()
end

function tests.rimuldar_exit_uses_live_east_entry_tile()
    local env = make_env()

    env.set_position(0x0B, 29, 13)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x00, 0x00)
    env.objects.refresh(0x0B)

    local obj = env.objects.select_object_by_id("exit_29_13")
    assert_equal(obj ~= nil, true, "Rimuldar should expose the live east-side town exit")
    assert_equal(obj.name, "Exit to World Map", "Rimuldar should keep the normal town-exit label")
    assert_equal(obj.x, 29, "Rimuldar exit should use the live east-edge entry X")
    assert_equal(obj.y, 13, "Rimuldar exit should use the live entry row")
    assert_equal(obj.interaction_x, 29, "Rimuldar exit route should stand on the east entry tile")
    assert_equal(obj.interaction_y, 13, "Rimuldar exit stand should match the live entry row")
    assert_equal(obj.interaction_face_dir, "east", "Rimuldar exit stand should face out toward the world")

    local northwest_exit = env.objects.select_object_by_id("exit_4_3")
    assert_equal(northwest_exit ~= nil, true, "Rimuldar should expose the live northwest Magic Key maze exit")
    assert_equal(northwest_exit.name, "Northwest Exit to World Map", "Rimuldar alternate exit should be labeled distinctly")
    assert_equal(northwest_exit.x, 4, "Rimuldar northwest exit should use the live false-wall exit X")
    assert_equal(northwest_exit.y, 3, "Rimuldar northwest exit should use the live false-wall exit Y")
    assert_equal(northwest_exit.interaction_x, 4, "Rimuldar northwest exit route should stand on the false-wall exit tile")
    assert_equal(northwest_exit.interaction_y, 3, "Rimuldar northwest exit stand should match the live false-wall exit row")
    assert_equal(northwest_exit.interaction_face_dir, "north", "Rimuldar northwest exit stand should face north toward the world transition")

    env.restore()
end

function tests.rain_shrine_exit_uses_live_bottom_entry_tile()
    local env = make_env()

    env.set_position(0x0D, 4, 9)
    env.set_terrain_offset(0x20)
    env.set_npc(0, 0x00, 0x00)
    env.objects.refresh(0x0D)

    local obj = env.objects.select_object_by_id("exit_4_9")
    assert_equal(obj ~= nil, true, "Rain Shrine should expose the live bottom exit")
    assert_equal(obj.name, "Exit to World Map", "Rain Shrine should keep the normal exit label")
    assert_equal(obj.x, 4, "Rain Shrine exit should use the live entry X")
    assert_equal(obj.y, 9, "Rain Shrine exit should use the live entry row")
    assert_equal(obj.interaction_x, 4, "Rain Shrine exit route should stand on the bottom entry tile")
    assert_equal(obj.interaction_y, 9, "Rain Shrine exit stand should match the live entry row")
    assert_equal(obj.interaction_face_dir, "south", "Rain Shrine exit stand should face south toward the world")

    env.restore()
end

function tests.garinham_overworld_landmark_uses_western_coordinate()
    local env = make_env()

    env.set_position(0x01, 2, 2)
    env.set_terrain_offset(0x00)
    env.objects.refresh(0x01)

    local obj = env.objects.select_object_by_id("overworld_garinham")
    assert_equal(obj ~= nil, true, "World map should expose Garinham as a Travel object")
    assert_equal(obj.x, 1, "Garinham overworld landmark should use the western guide coordinate")
    assert_equal(obj.y, 2, "Garinham overworld landmark should keep the guide northing")

    local landing = assert(env.objects.resolve_teleport_landing(obj, 0x01, {check_npc = false}))
    assert_equal(landing.x, 1, "overworld landmark teleport should land on the landmark x")
    assert_equal(landing.y, 2, "overworld landmark teleport should land on the landmark y")
    assert_equal(landing.reason, "overworld_travel", "overworld landmark teleport should bypass missing map-reader walkability")

    env.restore()
end

function tests.swamp_cave_south_entrance_is_available_as_overworld_landmark()
    local env = make_env()

    env.set_position(0x01, 104, 49)
    env.set_terrain_offset(0x00)
    env.objects.refresh(0x01)
    env.objects.travel_filter()

    local south = env.objects.select_object_by_id("overworld_swamp_cave_south_entrance")
    assert_equal(south ~= nil, true, "World map should expose the south Swamp Cave entrance")
    assert_equal(south.name, "Swamp Cave South Entrance", "south entrance should have a distinct Travel label")
    assert_equal(south.x, 104, "south entrance should use the validated overworld X")
    assert_equal(south.y, 49, "south entrance should use the validated overworld Y")

    local north = env.objects.find_overworld_landmark("Swamp Cave")
    assert_equal(north.id, "overworld_swamp_cave", "plain Swamp Cave lookup should still resolve to the north entrance")

    local lookup = env.objects.find_overworld_landmark("swamp cave south")
    assert_equal(lookup.id, "overworld_swamp_cave_south_entrance", "south entrance should be findable by prefix")

    env.restore()
end

function tests.find_overworld_landmark_supports_names_ids_and_prefixes()
    local env = make_env()

    local garinham = assert(env.objects.find_overworld_landmark("Garinham"))
    assert_equal(garinham.id, "overworld_garinham", "landmark lookup should accept display names")
    assert_equal(garinham.x, 1, "landmark lookup should return the same coordinate used by Travel objects")
    assert_equal(garinham.y, 2, "landmark lookup should return the same coordinate used by Travel objects")

    local by_id = assert(env.objects.find_overworld_landmark("overworld_garinham"))
    assert_equal(by_id.name, "Garinham", "landmark lookup should accept object ids")

    local erdrick = assert(env.objects.find_overworld_landmark("erdricks"))
    assert_equal(erdrick.id, "overworld_erdrick_s_cave", "landmark lookup should tolerate missing apostrophes")

    env.restore()
end

function tests.find_overworld_landmark_rejects_ambiguous_prefixes()
    local env = make_env()

    local landmark, err = env.objects.find_overworld_landmark("c")
    assert_equal(landmark, nil, "ambiguous landmark prefixes should not pick an arbitrary destination")
    assert_equal(err, "ambiguous overworld landmark: c", "ambiguous landmark prefixes should explain the refusal")

    env.restore()
end

function tests.service_filter_lists_merchant_npcs()
    local env = make_env()

    env.set_position(0x08, 5, 5)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x65, 0x47, 0xFC) -- sprite type 3 (Merchant), x=5, y=7, facing bits set
    env.objects.refresh(0x08)

    env.objects.next_filter() -- NPCs
    env.objects.next_filter() -- Services

    assert_equal(env.objects.get_count(), 1, "Services filter should include merchant-type NPCs")
    local obj = env.objects.current_object()
    assert_equal(obj.name, "Merchant", "merchant sprite should keep its service-facing label")
    assert_equal(obj.service, true, "merchant NPCs should be marked as services")
    assert_equal(obj.direction, 2, "NPC parser should expose facing bits for diagnostics")
    assert_equal(obj.movement, 0xFC, "NPC parser should expose movement byte for route diagnostics")

    env.restore()
end

function tests.all_filter_jumps_back_to_all_objects()
    local env = make_env()

    env.set_position(0x08, 5, 5)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x08)
    env.objects.next_filter() -- NPCs
    assert_equal(env.objects.get_filter_name(), "NPCs", "test should start on the NPC filter")

    local filter_name = env.objects.all_filter()
    assert_equal(filter_name, "All", "all_filter should report the All filter")
    assert_equal(env.objects.get_filter_name(), "All", "current filter should return to All")
    assert_equal(env.objects.get_count() > 0, true, "All filter should expose available map objects")

    env.restore()
end

function tests.pathability_filter_stacks_with_object_categories()
    local env = make_env()

    env.set_position(0x08, 5, 5)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x25, 0x07) -- sprite type 1 (Guard), x=5, y=7
    env.objects.refresh(0x08)

    env.objects.set_pathability_statuses({
        npc_0 = true,
        exit_0_15 = false,
    })
    env.objects.set_pathability_filter(env.objects.PATHABILITY_REACHABLE)

    assert_equal(env.objects.get_filter_summary(), "All, reachable", "filter summary should combine type and pathability filters")
    assert_equal(env.objects.get_count(), 1, "reachable filter should hide unreachable objects")
    assert_equal(env.objects.current_object().id, "npc_0", "reachable filter should expose the reachable NPC")

    env.objects.next_filter() -- NPCs
    assert_equal(env.objects.get_filter_summary(), "NPCs, reachable", "type filter should keep the active pathability suffix")
    assert_equal(env.objects.get_count(), 1, "reachable NPC category should keep the NPC")

    env.objects.next_filter() -- Services
    env.objects.next_filter() -- Treasure
    env.objects.next_filter() -- Travel
    assert_equal(env.objects.get_count(), 0, "reachable Travel category should hide the unreachable exit")

    env.objects.set_pathability_filter(env.objects.PATHABILITY_UNREACHABLE)
    assert_equal(env.objects.get_filter_summary(), "Travel, unreachable", "unreachable mode should stack with Travel")
    assert_equal(env.objects.get_count(), 1, "unreachable Travel category should expose the exit")
    assert_equal(env.objects.current_object().id, "exit_0_15", "unreachable filter should expose the unreachable exit")

    env.restore()
end

function tests.pathability_all_restores_normal_category_count()
    local env = make_env()

    env.set_position(0x08, 5, 5)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x25, 0x07)
    env.objects.refresh(0x08)
    local all_count = env.objects.get_count()

    env.objects.set_pathability_statuses({
        npc_0 = true,
        exit_0_15 = false,
    })
    env.objects.set_pathability_filter(env.objects.PATHABILITY_REACHABLE)
    assert_equal(env.objects.get_count(), 1, "test should start with a narrowed reachable list")

    env.objects.all_pathability_filter()
    assert_equal(env.objects.get_pathability_filter_name(), "All", "all pathability filter should report All")
    assert_equal(env.objects.get_filter_summary(), "All", "summary should drop the pathability suffix in All mode")
    assert_equal(env.objects.get_count(), all_count, "All pathability should restore the normal object list")

    env.restore()
end

function tests.npc_occupancy_check_reads_live_ram_without_full_refresh()
    local env = make_env({is_bizhawk = true})

    env.set_position(0x04, 0, 0)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x04)
    env.objects.next_filter()

    env.set_npc(0, 0x2A, 0x09) -- x=10, y=9 with sprite type 1
    assert_equal(env.objects.current_object().x, 5, "object list should stay stale before a refresh")
    assert_equal(env.objects.is_npc_at(0x04, 10, 9), true, "occupancy check should read the current NPC RAM")
    assert_equal(env.objects.is_npc_at(0x04, 5, 7), false, "occupancy check should not use stale object-list positions")

    env.restore()
end

function tests.current_object_description_reads_live_npc_slot_without_full_refresh()
    local env = make_env({is_bizhawk = true})

    env.set_position(0x04, 10, 9)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x04)
    env.objects.next_filter()

    env.set_npc(0, 0x2A, 0x08) -- x=10, y=8 with sprite type 1
    assert_equal(env.objects.current_object().x, 5, "object list should stay stale before a refresh")
    assert_equal(
        env.objects.describe_current({include_debug_coords = false}),
        "Guard: 1 north (1 of 1)",
        "current-object speech should use the selected NPC slot's live position")
    assert_equal(
        env.objects.describe_current({include_debug_coords = false, use_live_npc = false}),
        "Guard: 2 north, 5 west (1 of 1)",
        "tests and debug callers can still opt into cached object-list coordinates")

    env.restore()
end

function tests.npc_selected_teleport_landing_uses_adjacent_cell()
    local env = make_env({
        walkable_tiles = {
            ["0x08:5,5"] = true,
            ["0x08:5,6"] = true,
        },
    })

    env.set_position(0x08, 1, 15)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x08)
    env.objects.next_filter()

    local landing = assert(env.objects.resolve_teleport_landing(env.objects.current_object(), 0x08))
    assert_equal(landing.x, 5, "NPC exact teleport should not land on the occupied NPC x")
    assert_equal(landing.y, 6, "NPC exact teleport should use a cardinal adjacent cell")
    assert_equal(landing.note, "north", "landing note should describe the stand cell relative to the NPC")
    assert_equal(landing.face_dir, "south", "landing face direction should point back at the NPC")

    env.restore()
end

function tests.npc_selected_teleport_landing_skips_occupied_adjacent_cell()
    local env = make_env({
        npc_count = 2,
        walkable_tiles = {
            ["0x08:5,6"] = true,
            ["0x08:6,7"] = true,
            ["0x08:7,7"] = true,
        },
    })

    env.set_position(0x08, 1, 15)
    env.set_terrain_offset(0x10)
    env.set_npc(1, 0x25, 0x06) -- another guard occupies the north landing
    env.objects.refresh(0x08)
    env.objects.next_filter()
    env.objects.select_object_by_id("npc_0")

    local landing = assert(env.objects.resolve_teleport_landing(env.objects.current_object(), 0x08))
    assert_equal(landing.x, 6, "NPC teleport should skip occupied adjacent landings")
    assert_equal(landing.y, 7, "NPC teleport should choose the next open cardinal landing")
    assert_equal(landing.note, "east", "landing note should describe the fallback side")

    env.restore()
end

function tests.npc_selected_teleport_landing_reads_live_slot_without_refresh()
    local env = make_env({
        is_bizhawk = true,
        walkable_tiles = {
            ["0x08:10,7"] = true,
            ["0x08:10,8"] = true,
        },
    })

    env.set_position(0x08, 1, 15)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x08)
    env.objects.next_filter()
    local selected = env.objects.current_object()

    env.set_npc(0, 0x2A, 0x09) -- same selected slot moved to x=10, y=9
    assert_equal(selected.x, 5, "cached selected object should stay stale before a refresh")

    local landing = assert(env.objects.resolve_teleport_landing(selected, 0x08))
    assert_equal(landing.x, 10, "selected teleport should read the NPC slot's live x")
    assert_equal(landing.y, 8, "selected teleport should land adjacent to the live NPC y")
    assert_equal(selected.x, 5, "resolve should not rebuild or mutate the cached object")

    env.restore()
end

function tests.npc_selected_teleport_landing_skips_adjacent_cell_with_no_escape()
    local env = make_env({
        walkable_tiles = {
            ["0x08:5,7"] = true,
            ["0x08:5,6"] = true,
            ["0x08:5,8"] = true,
            ["0x08:6,7"] = true,
            ["0x08:4,8"] = true,
            ["0x08:4,9"] = true,
        },
        directional_blocks = {
            [0x08] = {
                ["5,6"] = {south = true},
                ["5,8"] = {north = true},
                ["6,7"] = {west = true},
            },
        },
    })

    env.set_position(0x08, 1, 15)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x24, 0x07) -- Synthetic adjacent-NPC no-escape case.
    env.objects.refresh(0x08)
    env.objects.next_filter()

    local landing = assert(env.objects.resolve_teleport_landing(env.objects.current_object(), 0x08))
    assert_equal(landing.x, 4, "NPC teleport should skip adjacent cells with no non-target escape")
    assert_equal(landing.y, 8, "NPC teleport should use the first open adjacent cell that can be exited")
    assert_equal(landing.note, "south", "landing note should describe the usable stand cell")
    assert_equal(landing.face_dir, "north", "landing should still face back to the NPC")

    env.restore()
end

function tests.service_selected_teleport_landing_uses_interaction_stand()
    local env = make_env({
        walkable_tiles = {
            ["0x08:5,6"] = true,
        },
    })

    env.set_position(0x08, 1, 15)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x65, 0x04) -- Merchant at Brecconary weapon counter
    env.objects.refresh(0x08)
    env.objects.next_filter()

    local landing = assert(env.objects.resolve_teleport_landing(env.objects.current_object(), 0x08))
    assert_equal(landing.x, 5, "service teleport should use its public interaction stand x")
    assert_equal(landing.y, 6, "service teleport should use its public interaction stand y")
    assert_equal(landing.reason, "interaction", "service override should be treated as an interaction landing")
    assert_equal(landing.face_dir, "north", "service landing should preserve the interaction facing")

    env.restore()
end

function tests.non_npc_selected_teleport_landing_uses_exact_walkable_cell()
    local env = make_env({
        walkable_tiles = {
            ["0x08:9,9"] = true,
        },
    })

    local landing = assert(env.objects.resolve_teleport_landing({
        name = "Stairs Down",
        type = env.objects.TYPE_STAIR,
        x = 9,
        y = 9,
    }, 0x08, {check_npc = false}))

    assert_equal(landing.x, 9, "walkable non-NPC teleport should use the target x")
    assert_equal(landing.y, 9, "walkable non-NPC teleport should use the target y")
    assert_equal(landing.reason, "exact", "walkable non-NPC landing should stay exact")

    env.restore()
end

function tests.non_npc_selected_teleport_landing_uses_adjacent_cell_when_target_blocked()
    local env = make_env({
        walkable_tiles = {
            ["0x08:1,15"] = true,
            ["0x08:2,15"] = true,
        },
    })

    local landing = assert(env.objects.resolve_teleport_landing({
        name = "Exit to World Map",
        type = env.objects.TYPE_EXIT,
        x = 0,
        y = 15,
    }, 0x08, {check_npc = false}))

    assert_equal(landing.x, 1, "blocked non-NPC teleport should use an adjacent landing x")
    assert_equal(landing.y, 15, "blocked non-NPC teleport should use an adjacent landing y")
    assert_equal(landing.target_x, 0, "landing should retain the selected object target x")
    assert_equal(landing.target_y, 15, "landing should retain the selected object target y")
    assert_equal(landing.note, "east", "landing note should describe the stand cell relative to the object")
    assert_equal(landing.face_dir, "west", "landing face direction should point back at the object")
    assert_equal(landing.reason, "adjacent", "blocked non-NPC landing should be marked adjacent")

    env.restore()
end

function tests.visited_flags_are_map_scoped_and_clearable()
    local env = make_env()

    env.set_position(0x08, 5, 5)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x08)
    env.objects.next_filter()

    local obj = env.objects.current_object()
    env.objects.mark_current_visited()
    assert_equal(env.objects.is_visited(obj), true, "marked object should be visited on the current map")
    assert_equal(
        env.objects.describe_current({include_debug_coords = false}),
        "Guard (visited): 2 south (1 of 1)",
        "visited object descriptions should include the visited flag")

    env.set_position(0x09, 5, 5)
    env.objects.refresh(0x09)
    env.objects.next_filter()
    assert_equal(env.objects.is_visited(env.objects.current_object()), false, "visited flags should not bleed across maps")

    env.set_position(0x08, 5, 5)
    env.objects.refresh(0x08)
    env.objects.next_filter()
    assert_equal(env.objects.clear_visited(), 1, "clear_visited should return the count cleared for the current map")
    assert_equal(env.objects.is_visited(env.objects.current_object()), false, "clear_visited should remove the current map flag")

    env.restore()
end

function tests.visited_flags_survive_objects_module_reload()
    local env = make_env()

    env.set_position(0x08, 5, 5)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x08)
    env.objects.next_filter()

    local obj = env.objects.current_object()
    env.objects.mark_current_visited()

    env.objects = env.reload_objects()
    assert_equal(env.objects.is_visited(obj, 0x08), true, "visited flag should survive a source reload")

    env.objects.refresh(0x08)
    env.objects.next_filter()
    assert_equal(
        env.objects.describe_current({include_debug_coords = false}),
        "Guard (visited): 2 south (1 of 1)",
        "reloaded object descriptions should keep the visited flag")

    assert_equal(env.objects.clear_visited("all"), 1, "clear_visited all should clear the reload-persistent visit")
    env.objects = env.reload_objects()
    assert_equal(env.objects.is_visited(obj, 0x08), false, "cleared visits should stay cleared after reload")

    env.restore()
end

function tests.talk_visit_marker_uses_live_npc_ram_when_object_list_position_is_stale()
    local env = make_env()

    env.set_position(0x04, 10, 9)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x04)
    env.objects.next_filter()
    local obj = env.objects.current_object()
    assert_equal(obj.id, "npc_0", "test should start with the NPC selected")
    assert_equal(obj.x, 5, "test object-list NPC should start away from the player")

    env.set_npc(0, 0x2A, 0x08) -- x=10, y=8, adjacent north of player
    local marked = env.objects.mark_adjacent_npc_visited(0x04, 10, 9)
    assert_equal(marked.id, "npc_0", "live adjacent NPC slot should be marked even when cached coordinates are stale")
    assert_equal(env.objects.is_visited(obj, 0x04), true, "visited flag should apply to the cached object with the same NPC slot id")
    assert_equal(
        env.objects.describe_current({include_debug_coords = false}),
        "Guard (visited): 1 north (1 of 1)",
        "visited object speech should use the live selected NPC slot")

    env.restore()
end

function tests.brecconary_counter_service_marks_selected_merchant_visited()
    local env = make_env()

    env.set_position(0x08, 5, 6)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x60 + 5, 0x04, 0x00) -- Merchant at (5,4)
    env.objects.refresh(0x08)

    local obj = env.objects.current_object()
    assert_equal(obj.name, "Weapons Merchant", "Brecconary weapon-shop service should have a player-facing label")
    assert_equal(obj.interaction_x, 5, "Brecconary merchant should expose the counter interaction X")
    assert_equal(obj.interaction_y, 6, "Brecconary merchant should expose the counter interaction Y")
    assert_equal(obj.interaction_face_dir, "north", "Brecconary merchant should face north from the counter")
    assert_equal(
        env.objects.describe_current({include_debug_coords = false}),
        "Weapons Merchant: 2 north, counter here (1 of 4)",
        "merchant description should name the usable counter square")

    local marked = env.objects.mark_adjacent_npc_visited(0x08, 5, 6)
    assert_equal(marked.id, "npc_0", "counter interaction should mark the selected merchant visited")
    assert_equal(env.objects.is_visited(obj, 0x08), true, "counter interaction visit should persist on the merchant")

    env.restore()
end

function tests.brecconary_counter_service_marks_merchant_even_when_not_selected()
    local env = make_env({npc_count = 2})

    env.set_position(0x08, 5, 6)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x60 + 5, 0x04, 0x00) -- Merchant at (5,4)
    env.set_npc(1, 0x20 + 20, 0x14, 0x00) -- Non-service NPC away from the counter
    env.objects.refresh(0x08)

    local merchant = env.objects.find_object_by_id("npc_0")
    assert_equal(merchant.name, "Weapons Merchant", "test should expose the weapon-shop merchant")
    local selected = env.objects.select_object_by_id("npc_1")
    assert_equal(selected.id, "npc_1", "test should force a different selected object")

    local marked = env.objects.mark_adjacent_npc_visited(0x08, 5, 6)
    assert_equal(marked.id, "npc_0", "counter interaction should mark the service merchant, not the selected NPC")
    assert_equal(env.objects.is_visited(merchant, 0x08), true, "counter visit should persist on the merchant")
    assert_equal(env.objects.is_visited(selected, 0x08), false, "unrelated selected NPC should not be marked visited")

    env.restore()
end

function tests.service_counter_inference_uses_adjacent_large_tile_public_stand()
    local env = make_env({
        large_tiles = {
            ["0x0A:9,21"] = true,
            ["0x0A:24,25"] = true,
        },
        walkable_tiles = {
            ["0x0A:8,21"] = true,
            ["0x0A:23,25"] = true,
        },
        npc_count = 4,
    })

    env.set_position(0x0A, 12, 23)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x60 + 5, 0x04, 0x00)
    env.set_npc(1, 0x60 + 1, 0x01, 0x00)
    env.set_npc(2, 0x60 + 10, 0x15, 0x00)
    env.set_npc(3, 0x60 + 25, 0x19, 0x00)
    env.objects.refresh(0x0A)

    local merchant3 = nil
    local merchant4 = nil
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.name == "Merchant 3" then
            merchant3 = obj
        elseif obj.name == "Merchant 4" then
            merchant4 = obj
        end
    end

    assert_equal(merchant3 ~= nil, true, "Generic Merchant 3 should be present in the service list")
    assert_equal(merchant3.interaction_x, 8, "Merchant 3 should use the public stand west of the raw large tile")
    assert_equal(merchant3.interaction_y, 21, "Merchant 3 counter stand Y should match the raw large tile row")
    assert_equal(merchant3.interaction_face_dir, "east", "Merchant 3 should face east through the counter")
    assert_equal(merchant3.interaction_label, "counter", "inferred service stand should be labeled as a counter")

    assert_equal(merchant4 ~= nil, true, "Generic Merchant 4 should be present in the service list")
    assert_equal(merchant4.interaction_x, 23, "Merchant 4 should use the public stand west of the raw large tile")
    assert_equal(merchant4.interaction_y, 25, "Merchant 4 counter stand Y should match the raw large tile row")
    assert_equal(merchant4.interaction_face_dir, "east", "Merchant 4 should face east through the counter")

    env.restore()
end

function tests.brecconary_confirmed_counter_services_use_live_talk_tiles()
    local env = make_env({
        large_tiles = {
            ["0x08:9,21"] = true,
            ["0x08:24,25"] = true,
        },
        walkable_tiles = {
            ["0x08:8,21"] = true,
            ["0x08:9,21"] = true,
            ["0x08:23,25"] = true,
            ["0x08:24,25"] = true,
            ["0x08:25,26"] = true,
        },
        npc_count = 4,
    })

    env.set_position(0x08, 12, 23)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x60 + 15, 0x08, 0x00) -- Dialogue-only Merchant 1
    env.set_npc(1, 0x60 + 5, 0x04, 0x00)
    env.set_npc(2, 0x60 + 10, 0x15, 0x00)
    env.set_npc(3, 0x60 + 25, 0x19, 0x00)
    env.objects.refresh(0x08)

    local dialogue_merchant = nil
    local inn = nil
    local tool_merchant = nil
    local weapons = nil
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.name == "Merchant 1" then
            dialogue_merchant = obj
        elseif obj.name == "Inn" then
            inn = obj
        elseif obj.name == "Tool Merchant" then
            tool_merchant = obj
        elseif obj.name == "Weapons Merchant" then
            weapons = obj
        end
    end

    assert_equal(dialogue_merchant ~= nil, true, "Brecconary dialogue-only Merchant 1 should stay browsable")
    assert_equal(dialogue_merchant.service, false, "Dialogue-only Merchant 1 should not appear in Services")
    assert_equal(weapons ~= nil, true, "Brecconary weapon merchant should remain a service")
    assert_equal(weapons.service, true, "Weapons Merchant should stay in Services")
    assert_equal(inn ~= nil, true, "Brecconary inn should be present")
    assert_equal(inn.interaction_x, 8, "Inn should use the live-confirmed public stand tile")
    assert_equal(inn.interaction_y, 21, "Inn public stand Y should match the counter row")
    assert_equal(inn.interaction_face_dir, "east", "Inn should face east toward the inn keeper")

    assert_equal(tool_merchant ~= nil, true, "Brecconary tool merchant should be present")
    assert_equal(tool_merchant.service, true, "Tool Merchant should stay in Services")
    assert_equal(tool_merchant.interaction_x, 23, "Tool Merchant should use the live-confirmed public pocket stand")
    assert_equal(tool_merchant.interaction_y, 25, "Tool Merchant public counter stand should match the counter row")
    assert_equal(tool_merchant.interaction_face_dir, "east", "Tool Merchant should face east through the blocked counter edge")

    env.objects.next_filter() -- NPCs
    env.objects.next_filter() -- Services
    local service_names = {}
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        service_names[#service_names + 1] = obj.name
    end
    local service_text = table.concat(service_names, ", ")
    assert_equal(service_text:find("Merchant 1", 1, true), nil, "Services filter should omit dialogue-only Merchant 1")
    assert_equal(service_text:find("Weapons Merchant", 1, true) ~= nil, true, "Services filter should include Weapons Merchant")
    assert_equal(service_text:find("Inn", 1, true) ~= nil, true, "Services filter should include Inn")
    assert_equal(service_text:find("Tool Merchant", 1, true) ~= nil, true, "Services filter should include Tool Merchant")

    local marked = env.objects.mark_adjacent_npc_visited(0x08, 23, 25)
    assert_equal(marked.id, tool_merchant.id, "Tool Merchant public counter stand should mark the tool merchant visited")
    assert_equal(env.objects.is_visited(tool_merchant, 0x08), true, "Tool Merchant counter visit should persist from the public stand")

    env.restore()
end

function tests.kol_confirmed_services_and_dialogue_merchant_filtering()
    local env = make_env({npc_count = 4})

    env.set_position(0x07, 12, 21)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x60 + 5, 0x14, 0x00)  -- Merchant 1, Rimuldar hint NPC
    env.set_npc(1, 0x60 + 19, 0x04, 0x00) -- Merchant 2, confirmed Inn
    env.set_npc(2, 0x60 + 22, 0x0C, 0x00) -- Merchant 3, confirmed weapon/armor shop
    env.set_npc(3, 0x60 + 14, 0x15, 0x00) -- Merchant 4, confirmed tool shop
    env.objects.refresh(0x07)

    local merchant1 = nil
    local inn = nil
    local weapons = nil
    local tools = nil
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.name == "Merchant 1" then
            merchant1 = obj
        elseif obj.name == "Inn" then
            inn = obj
        elseif obj.name == "Weapons Merchant" then
            weapons = obj
        elseif obj.name == "Tool Merchant" then
            tools = obj
        end
    end

    assert_equal(merchant1 ~= nil, true, "Kol dialogue-only Merchant 1 should stay browsable as an NPC")
    assert_equal(merchant1.service, false, "Kol dialogue-only Merchant 1 should not appear in Services")
    assert_equal(inn ~= nil, true, "Kol Merchant 2 should be labeled as Inn after live TALK proof")
    assert_equal(inn.service, true, "Kol Inn should remain in Services")
    assert_equal(inn.interaction_x, 19, "Kol Inn should use the live-confirmed public stand X")
    assert_equal(inn.interaction_y, 2, "Kol Inn should use the live-confirmed public stand Y")
    assert_equal(inn.interaction_face_dir, "south", "Kol Inn should face south toward the keeper")
    assert_equal(weapons ~= nil, true, "Kol Merchant 3 should be labeled as Weapons Merchant after live shop-menu proof")
    assert_equal(weapons.service, true, "Kol Weapons Merchant should remain in Services")
    assert_equal(weapons.interaction_x, 20, "Kol Weapons Merchant should use the live-confirmed public stand X")
    assert_equal(weapons.interaction_y, 12, "Kol Weapons Merchant should use the live-confirmed public stand Y")
    assert_equal(weapons.interaction_face_dir, "east", "Kol Weapons Merchant should face east through the counter")
    assert_equal(tools ~= nil, true, "Kol Merchant 4 should be labeled as Tool Merchant after live shop-menu proof")
    assert_equal(tools.service, true, "Kol Tool Merchant should remain in Services")
    assert_equal(tools.interaction_x, 12, "Kol Tool Merchant should use the live-confirmed public stand X")
    assert_equal(tools.interaction_y, 21, "Kol Tool Merchant should use the live-confirmed public stand Y")
    assert_equal(tools.interaction_face_dir, "east", "Kol Tool Merchant should face east through the counter")

    env.objects.next_filter() -- NPCs
    local npc_names = {}
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        npc_names[#npc_names + 1] = obj.name
    end
    local npc_text = table.concat(npc_names, ", ")
    assert_equal(npc_text:find("Merchant 1", 1, true) ~= nil, true, "NPCs should include Kol Merchant 1")

    env.objects.next_filter() -- Services
    local service_names = {}
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        service_names[#service_names + 1] = obj.name
    end
    local service_text = table.concat(service_names, ", ")
    assert_equal(service_text:find("Merchant 1", 1, true), nil, "Services should omit Kol dialogue-only Merchant 1")
    assert_equal(service_text:find("Merchant 2", 1, true), nil, "Services should not keep the stale Kol Merchant 2 label")
    assert_equal(service_text:find("Merchant 3", 1, true), nil, "Services should not keep the stale Kol Merchant 3 label")
    assert_equal(service_text:find("Merchant 4", 1, true), nil, "Services should not keep the stale Kol Merchant 4 label")
    assert_equal(service_text:find("Inn", 1, true) ~= nil, true, "Services should include the confirmed Kol Inn")
    assert_equal(service_text:find("Weapons Merchant", 1, true) ~= nil, true, "Services should include the confirmed Kol Weapons Merchant")
    assert_equal(service_text:find("Tool Merchant", 1, true) ~= nil, true, "Services should include the confirmed Kol Tool Merchant")

    env.restore()
end

function tests.kol_hidden_fairy_flute_search_tile_is_treasure()
    local env = make_env({npc_count = 0})

    env.set_position(0x07, 1, 22)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x07)

    local flute = env.objects.find_object_by_id("chest_kol_fairy_flute")
    assert_equal(flute ~= nil, true, "Kol should expose the hidden Fairy Flute search tile")
    assert_equal(flute.name, "Disturbed Earth Near Bath", "hidden Kol treasure should hint at the search spot without naming the reward")
    assert_equal(flute.type, env.objects.TYPE_CHEST, "hidden Kol treasure should appear under Treasure")
    assert_equal(flute.x, 9, "Fairy Flute search tile X should be four steps south of the bath")
    assert_equal(flute.y, 6, "Fairy Flute search tile Y should be four steps south of the bath")

    env.objects.next_filter() -- NPCs
    env.objects.next_filter() -- Services
    env.objects.next_filter() -- Treasure
    local found = false
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        if obj.id == "chest_kol_fairy_flute" then
            found = true
            break
        end
    end
    assert_equal(found, true, "Treasure filter should include the Kol Fairy Flute search tile")

    env.restore()
end

function tests.brecconary_confirmed_named_services_are_labeled()
    local env = make_env({npc_count = 4})

    env.set_position(0x08, 20, 10)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0xC0 + 24, 0x04, 0x00) -- Woman 1, Fairy Water merchant
    env.set_npc(1, 0xC0 + 1, 0x01, 0x00)  -- Woman 2
    env.set_npc(2, 0xA0 + 1, 0x01, 0x00)  -- Old Man 1
    env.set_npc(3, 0xA0 + 24, 0x0A, 0x00) -- Old Man 2, curse remover
    env.objects.refresh(0x08)

    local fairy_water = nil
    local curse_remover = nil
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.name == "Fairy Water Merchant" then
            fairy_water = obj
        elseif obj.name == "Curse Remover" then
            curse_remover = obj
        end
    end

    assert_equal(fairy_water ~= nil, true, "Woman 1 should be labeled as Fairy Water Merchant")
    assert_equal(fairy_water.service, true, "Fairy Water Merchant should appear in Services")
    assert_equal(fairy_water.interaction_x, nil, "Fairy Water Merchant should route as an adjacent NPC")
    assert_equal(curse_remover ~= nil, true, "Old Man 2 should be labeled as Curse Remover")
    assert_equal(curse_remover.service, true, "Curse Remover should appear in Services")
    assert_equal(curse_remover.interaction_x, nil, "Curse Remover should route as an adjacent NPC")

    env.objects.next_filter() -- NPCs
    env.objects.next_filter() -- Services
    local service_names = {}
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        service_names[#service_names + 1] = obj.name
    end
    local service_text = table.concat(service_names, ", ")
    assert_equal(service_text:find("Fairy Water Merchant", 1, true) ~= nil, true, "Services should include Fairy Water Merchant")
    assert_equal(service_text:find("Curse Remover", 1, true) ~= nil, true, "Services should include Curse Remover")

    env.restore()
end

function tests.tantegel_castle_sage_service_is_labeled()
    local env = make_env({npc_count = 2})

    env.set_position(0x04, 20, 25)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0xA0 + 1, 0x01, 0x00)   -- Old Man 1
    env.set_npc(1, 0xA0 + 20, 0x1A, 0x00)  -- Old Man 2, MP-restoring sage
    env.objects.refresh(0x04)

    local sage = nil
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.name == "Sage" then
            sage = obj
            break
        end
    end

    assert_equal(sage ~= nil, true, "Old Man 2 should be labeled as Sage")
    assert_equal(sage.service, true, "Sage should appear in Services")
    assert_equal(sage.interaction_x, 18, "Sage should use the live-confirmed west-side interaction stand")
    assert_equal(sage.interaction_y, 26, "Sage interaction stand should stay on the counter row")
    assert_equal(sage.interaction_face_dir, "east", "Sage interaction should face east toward the NPC")

    env.objects.next_filter() -- NPCs
    env.objects.next_filter() -- Services
    local service_names = {}
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        service_names[#service_names + 1] = obj.name
    end
    local service_text = table.concat(service_names, ", ")
    assert_equal(service_text:find("Sage", 1, true) ~= nil, true, "Services should include Sage")

    env.restore()
end

function tests.tantegel_castle_dialogue_merchants_stay_out_of_services()
    local env = make_env({npc_count = 3})

    env.set_position(0x04, 12, 29)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x60 + 6, 0x16, 0x00)   -- Merchant 1, dialogue-only
    env.set_npc(1, 0x60 + 5, 0x12, 0x00)   -- Merchant 2, dialogue-only
    env.set_npc(2, 0x60 + 24, 0x01, 0x00)  -- Merchant 3, magic-key seller
    env.objects.refresh(0x04)

    local merchant1 = nil
    local merchant2 = nil
    local key_merchant = nil
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.name == "Merchant 1" then
            merchant1 = obj
        elseif obj.name == "Merchant 2" then
            merchant2 = obj
        elseif obj.name == "Magic Key Merchant" then
            key_merchant = obj
        end
    end

    assert_equal(merchant1 ~= nil, true, "Dialogue-only Merchant 1 should stay browsable as an NPC")
    assert_equal(merchant1.service, false, "Dialogue-only Merchant 1 should not appear in Services")
    assert_equal(merchant2 ~= nil, true, "Dialogue-only Merchant 2 should stay browsable as an NPC")
    assert_equal(merchant2.service, false, "Dialogue-only Merchant 2 should not appear in Services")
    assert_equal(key_merchant ~= nil, true, "Merchant 3 should be labeled as Magic Key Merchant")
    assert_equal(key_merchant.service, true, "Magic Key Merchant should remain in Services")

    env.objects.next_filter() -- NPCs
    local npc_names = {}
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        npc_names[#npc_names + 1] = obj.name
    end
    local npc_text = table.concat(npc_names, ", ")
    assert_equal(npc_text:find("Merchant 1", 1, true) ~= nil, true, "NPCs should include Merchant 1")
    assert_equal(npc_text:find("Merchant 2", 1, true) ~= nil, true, "NPCs should include Merchant 2")

    env.objects.next_filter() -- Services
    local service_names = {}
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        service_names[#service_names + 1] = obj.name
    end
    local service_text = table.concat(service_names, ", ")
    assert_equal(service_text:find("Merchant 1", 1, true), nil, "Services should omit dialogue-only Merchant 1")
    assert_equal(service_text:find("Merchant 2", 1, true), nil, "Services should omit dialogue-only Merchant 2")
    assert_equal(service_text:find("Magic Key Merchant", 1, true) ~= nil, true, "Services should include Magic Key Merchant")

    env.restore()
end

function tests.garinham_confirmed_public_merchants_are_labeled()
    local env = make_env({npc_count = 4})

    env.set_position(0x09, 10, 16)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x60 + 10, 0x04, 0x00) -- Merchant 1, other shopkeeper
    env.set_npc(1, 0x60 + 3, 0x0A, 0x00)  -- Merchant 2, live-confirmed item shop
    env.set_npc(2, 0x60 + 17, 0x0F, 0x00) -- Merchant 3, other shopkeeper
    env.set_npc(3, 0x60 + 10, 0x12, 0x00) -- Merchant 4, live-confirmed weapon/armor shop
    env.objects.refresh(0x09)

    local tool_merchant = nil
    local inn = nil
    local weapons_merchant = nil
    local generic_merchant2 = nil
    local generic_merchant3 = nil
    local generic_merchant4 = nil
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.name == "Tool Merchant" then
            tool_merchant = obj
        elseif obj.name == "Inn" then
            inn = obj
        elseif obj.name == "Weapons Merchant" then
            weapons_merchant = obj
        elseif obj.name == "Merchant 2" then
            generic_merchant2 = obj
        elseif obj.name == "Merchant 3" then
            generic_merchant3 = obj
        elseif obj.name == "Merchant 4" then
            generic_merchant4 = obj
        end
    end

    assert_equal(tool_merchant ~= nil, true, "Garinham Merchant 2 should be labeled as Tool Merchant")
    assert_equal(tool_merchant.service, true, "Garinham Tool Merchant should remain in Services")
    assert_equal(generic_merchant2, nil, "Garinham Merchant 2 should not keep the generic label")
    assert_equal(inn ~= nil, true, "Garinham Merchant 3 should be labeled as Inn")
    assert_equal(inn.service, true, "Garinham Inn should remain in Services")
    assert_equal(inn.interaction_x, 15, "Garinham Inn should use the live-confirmed public counter stand X")
    assert_equal(inn.interaction_y, 15, "Garinham Inn should use the live-confirmed public counter stand Y")
    assert_equal(inn.interaction_face_dir, "east", "Garinham Inn should face east through the counter")
    assert_equal(generic_merchant3, nil, "Garinham Merchant 3 should not keep the generic label")
    assert_equal(weapons_merchant ~= nil, true, "Garinham Merchant 4 should be labeled as Weapons Merchant")
    assert_equal(weapons_merchant.service, true, "Garinham Weapons Merchant should remain in Services")
    assert_equal(weapons_merchant.interaction_x, 10, "Garinham Weapons Merchant should use the live-confirmed counter stand X")
    assert_equal(weapons_merchant.interaction_y, 16, "Garinham Weapons Merchant should use the live-confirmed counter stand Y")
    assert_equal(weapons_merchant.interaction_face_dir, "south", "Garinham Weapons Merchant should face south through the counter")
    assert_equal(generic_merchant4, nil, "Garinham Merchant 4 should not keep the generic label")

    env.objects.next_filter() -- NPCs
    env.objects.next_filter() -- Services
    local service_names = {}
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        service_names[#service_names + 1] = obj.name
    end
    local service_text = table.concat(service_names, ", ")
    assert_equal(service_text:find("Tool Merchant", 1, true) ~= nil, true, "Services should include Garinham Tool Merchant")
    assert_equal(service_text:find("Inn", 1, true) ~= nil, true, "Services should include Garinham Inn")
    assert_equal(service_text:find("Weapons Merchant", 1, true) ~= nil, true, "Services should include Garinham Weapons Merchant")

    local marked = env.objects.mark_adjacent_npc_visited(0x09, 15, 15)
    assert_equal(marked.id, inn.id, "Garinham Inn public counter stand should mark the inn visited")
    assert_equal(env.objects.is_visited(inn, 0x09), true, "Garinham Inn counter visit should persist from the public stand")

    env.restore()
end

function tests.rimuldar_confirmed_services_use_live_counter_stands()
    local env = make_env({npc_count = 4})

    env.set_position(0x0B, 24, 7)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x60 + 2, 0x04, 0x00) -- Merchant 1, other service slot
    env.set_npc(1, 0x60 + 23, 0x47, 0x00) -- Merchant 2, live weapon/armor shop at (23,7)
    env.set_npc(2, 0x60 + 16, 0x12, 0x00) -- Merchant 3, live 55 G inn at (16,18)
    env.set_npc(3, 0xA0 + 4, 0x07, 0x00) -- Old Man 1, live Magic Key shop at (4,7)
    env.objects.refresh(0x0B)

    local magic_key_merchant = nil
    local weapons_merchant = nil
    local inn = nil
    local dialogue_merchant1 = nil
    local generic_merchant2 = nil
    local generic_merchant3 = nil
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.name == "Magic Key Merchant" then
            magic_key_merchant = obj
        elseif obj.name == "Weapons Merchant" then
            weapons_merchant = obj
        elseif obj.name == "Inn" then
            inn = obj
        elseif obj.name == "Merchant 1" then
            dialogue_merchant1 = obj
        elseif obj.name == "Merchant 2" then
            generic_merchant2 = obj
        elseif obj.name == "Merchant 3" then
            generic_merchant3 = obj
        end
    end

    assert_equal(magic_key_merchant ~= nil, true, "Rimuldar Old Man 1 should be labeled as Magic Key Merchant")
    assert_equal(magic_key_merchant.service, true, "Rimuldar Magic Key Merchant should appear in Services")
    assert_equal(magic_key_merchant.x, 4, "Rimuldar Magic Key Merchant NPC X should match live NPC RAM")
    assert_equal(magic_key_merchant.y, 7, "Rimuldar Magic Key Merchant NPC Y should match live NPC RAM")
    assert_equal(magic_key_merchant.interaction_x, 4, "Rimuldar Magic Key Merchant should use the live-confirmed public stand X")
    assert_equal(magic_key_merchant.interaction_y, 6, "Rimuldar Magic Key Merchant should use the live-confirmed public stand Y")
    assert_equal(magic_key_merchant.interaction_face_dir, "south", "Rimuldar Magic Key Merchant should face south toward the seller")
    assert_equal(magic_key_merchant.blocks_movement, true, "Rimuldar Magic Key Merchant should block movement while still using the north-side counter stand")
    assert_equal(dialogue_merchant1 ~= nil, true, "Rimuldar Merchant 1 should stay browsable as an NPC")
    assert_equal(dialogue_merchant1.service, false, "Rimuldar Merchant 1 greeting NPC should not appear in Services")
    assert_equal(weapons_merchant ~= nil, true, "Rimuldar Merchant 2 should be labeled as Weapons Merchant")
    assert_equal(weapons_merchant.service, true, "Rimuldar Weapons Merchant should remain in Services")
    assert_equal(weapons_merchant.x, 23, "Rimuldar Weapons Merchant NPC X should match live NPC RAM")
    assert_equal(weapons_merchant.y, 7, "Rimuldar Weapons Merchant NPC Y should match live NPC RAM")
    assert_equal(weapons_merchant.interaction_x, 24, "Rimuldar Weapons Merchant should use the live-confirmed counter stand X")
    assert_equal(weapons_merchant.interaction_y, 7, "Rimuldar Weapons Merchant should use the live-confirmed counter stand Y")
    assert_equal(weapons_merchant.interaction_face_dir, "west", "Rimuldar Weapons Merchant should face west from the counter")
    assert_equal(generic_merchant2, nil, "Rimuldar Merchant 2 should not keep the generic label")
    assert_equal(inn ~= nil, true, "Rimuldar Merchant 3 should be labeled as Inn")
    assert_equal(inn.service, true, "Rimuldar Inn should remain in Services")
    assert_equal(inn.x, 16, "Rimuldar Inn NPC X should match live NPC RAM")
    assert_equal(inn.y, 18, "Rimuldar Inn NPC Y should match live NPC RAM")
    assert_equal(inn.interaction_x, 16, "Rimuldar Inn should use the live-confirmed public stand X")
    assert_equal(inn.interaction_y, 17, "Rimuldar Inn should use the live-confirmed public stand Y")
    assert_equal(inn.interaction_face_dir, "south", "Rimuldar Inn should face south toward the inn keeper")
    assert_equal(generic_merchant3, nil, "Rimuldar Merchant 3 should not keep the generic label")

    local blocking_cells = {}
    for _, pos in ipairs(env.objects.get_blocking_positions()) do
        blocking_cells[pos.x .. "," .. pos.y] = true
    end
    assert_equal(blocking_cells["4,7"], true, "Rimuldar Magic Key Merchant should block routing through the occupied seller cell")
    assert_equal(blocking_cells["23,7"], true, "Rimuldar Weapons Merchant should still block movement")
    assert_equal(blocking_cells["16,18"], true, "Rimuldar Inn keeper should still block movement")

    env.objects.next_filter() -- NPCs
    env.objects.next_filter() -- Services
    local service_names = {}
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        service_names[#service_names + 1] = obj.name
    end
    local service_text = table.concat(service_names, ", ")
    assert_equal(service_text:find("Magic Key Merchant", 1, true) ~= nil, true, "Services should include Rimuldar Magic Key Merchant")
    assert_equal(service_text:find("Weapons Merchant", 1, true) ~= nil, true, "Services should include Rimuldar Weapons Merchant")
    assert_equal(service_text:find("Inn", 1, true) ~= nil, true, "Services should include Rimuldar Inn")
    assert_equal(service_text:find("Merchant 1", 1, true), nil, "Services should omit Rimuldar greeting-only Merchant 1")
    assert_equal(service_text:find("Merchant 3", 1, true), nil, "Services should not keep the stale Rimuldar Merchant 3 label")

    local marked_key = env.objects.mark_adjacent_npc_visited(0x0B, 4, 6)
    assert_equal(marked_key.id, magic_key_merchant.id, "Rimuldar key-shop public stand should mark the Magic Key Merchant visited")
    assert_equal(env.objects.is_visited(magic_key_merchant, 0x0B), true, "Rimuldar key-shop visit should persist on the seller")
    local marked = env.objects.mark_adjacent_npc_visited(0x0B, 24, 7)
    assert_equal(marked.id, weapons_merchant.id, "Rimuldar counter stand should mark the weapon merchant visited")
    assert_equal(env.objects.is_visited(weapons_merchant, 0x0B), true, "Rimuldar counter visit should persist on the merchant")
    local marked_inn = env.objects.mark_adjacent_npc_visited(0x0B, 16, 17)
    assert_equal(marked_inn.id, inn.id, "Rimuldar inn public stand should mark the inn visited")
    assert_equal(env.objects.is_visited(inn, 0x0B), true, "Rimuldar inn visit should persist on the merchant")

    env.restore()
end

function tests.rimuldar_exposes_inn_and_wings_chest_doors()
    local env = make_env()

    env.set_position(0x0B, 23, 23)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x00, 0x00)
    env.objects.refresh(0x0B)

    env.objects.next_filter() -- NPCs
    env.objects.next_filter() -- Exits
    env.objects.next_filter() -- Chests
    env.objects.next_filter() -- Stairs
    env.objects.next_filter() -- Doors

    assert_equal(env.objects.get_count(), 2, "Rimuldar should expose both inn doors")
    local by_id = {}
    for _, door in ipairs(env.objects.get_objects({filtered = true})) do
        by_id[door.id] = door
    end
    local outer = by_id.door_21_21
    assert_equal(outer ~= nil, true, "Rimuldar inn outer door should be listed")
    assert_equal(outer.name, "Rimuldar Inn Outer Door", "Rimuldar inn outer door should have a distinct navigation label")
    assert_equal(outer.x, 21, "Rimuldar inn outer door x should match opened-door RAM")
    assert_equal(outer.y, 21, "Rimuldar inn outer door y should match opened-door RAM")
    local inner = by_id.door_22_23
    assert_equal(inner ~= nil, true, "Rimuldar Wings chest door should be listed")
    assert_equal(inner.name, "Wings Chest Door", "Rimuldar Wings chest door should have a distinct navigation label")
    assert_equal(inner.x, 22, "Rimuldar Wings chest door x should match opened-door RAM")
    assert_equal(inner.y, 23, "Rimuldar Wings chest door y should match opened-door RAM")

    env.restore()
end

function tests.tantegel_castle_exposes_reachable_navigation_doors()
    local env = make_env()

    env.set_position(0x04, 10, 29)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x00, 0x00)
    env.objects.refresh(0x04)

    env.objects.next_filter() -- NPCs
    env.objects.next_filter() -- Exits
    env.objects.next_filter() -- Chests
    env.objects.next_filter() -- Stairs
    env.objects.next_filter() -- Doors

    assert_equal(env.objects.get_count(), 2, "Tantegel Castle should expose the south gate and useful center crossing doors")
    local obj = env.objects.current_object()
    assert_equal(obj.id, "door_10_30", "the west south-gate tile should be the remaining door object")
    assert_equal(obj.x, 10, "south gate door x should match the reachable gate tile")
    assert_equal(obj.y, 30, "south gate door y should match the reachable gate tile")
    assert_equal(obj.survey_exclude, true, "south gate door should stay excluded from autonomous surveys")

    local doors = env.objects.get_objects({filtered = true})
    local center = nil
    for _, door in ipairs(doors) do
        if door.id == "door_14_6" then
            center = door
            break
        end
    end
    assert_equal(center ~= nil, true, "Tantegel Castle should expose the useful center crossing door")
    assert_equal(center.name, "Center Door", "center crossing door should have a distinct navigation label")
    assert_equal(center.x, 14, "center crossing door x should match the useful y=6 crossing")
    assert_equal(center.y, 6, "center crossing door y should match the useful y=6 crossing")
    assert_equal(center.survey_exclude, true, "center crossing door should stay excluded from autonomous surveys")

    env.restore()
end

function tests.brecconary_exposes_hidden_locked_doors()
    local env = make_env()

    env.set_position(0x08, 1, 15)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x00, 0x00)
    env.objects.refresh(0x08)

    env.objects.next_filter() -- NPCs
    env.objects.next_filter() -- Exits
    env.objects.next_filter() -- Chests
    env.objects.next_filter() -- Stairs
    env.objects.next_filter() -- Doors

    assert_equal(env.objects.get_count(), 2, "Brecconary should expose both hidden locked doors")
    local doors = env.objects.get_objects({filtered = true})
    local northeast = nil
    local inn_west = nil
    for _, door in ipairs(doors) do
        if door.id == "door_21_6" then
            northeast = door
        elseif door.id == "door_5_22" then
            inn_west = door
        end
    end

    assert_equal(northeast ~= nil, true, "Brecconary should expose the northeast hidden door")
    assert_equal(northeast.name, "Northeast Door", "northeast door should have a distinct navigation label")
    assert_equal(northeast.x, 21, "northeast door x should match the topology frontier")
    assert_equal(northeast.y, 6, "northeast door y should match the topology frontier")

    assert_equal(inn_west ~= nil, true, "Brecconary should expose the inn west-room door")
    assert_equal(inn_west.name, "Inn West Room Door", "inn west-room door should have a distinct navigation label")
    assert_equal(inn_west.x, 5, "inn west-room door x should match the topology frontier")
    assert_equal(inn_west.y, 22, "inn west-room door y should match the topology frontier")

    env.restore()
end

function tests.garinham_exposes_confirmed_east_locked_door()
    local env = make_env()

    env.set_position(0x09, 19, 17)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x00, 0x00)
    env.objects.refresh(0x09)

    env.objects.next_filter() -- NPCs
    env.objects.next_filter() -- Exits
    env.objects.next_filter() -- Chests
    env.objects.next_filter() -- Stairs
    env.objects.next_filter() -- Doors

    assert_equal(env.objects.get_count(), 1, "Garinham should expose the confirmed east locked door")
    local door = env.objects.current_object()
    assert_equal(door.id, "door_19_16", "Garinham east door id should match the confirmed coordinate")
    assert_equal(door.name, "East Door", "Garinham east door should have a distinct navigation label")
    assert_equal(door.x, 19, "Garinham east door x should match the live no-key movement probe")
    assert_equal(door.y, 16, "Garinham east door y should match the live no-key movement probe")

    env.restore()
end

function tests.fceux_periodic_refresh_updates_moving_npcs()
    local env = make_env()

    env.set_position(0x04, 0, 0)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x04)
    env.objects.next_filter()
    local initial = env.objects.current_object()
    assert_equal(initial.x, 5, "initial NPC x should come from RAM")
    assert_equal(initial.y, 7, "initial NPC y should come from RAM")

    env.set_npc(0, 0x2A, 0x09) -- x=10, y=9 with sprite type 1
    for _ = 1, 20 do
        env.objects.check_refresh(0x04)
    end

    local refreshed = env.objects.current_object()
    assert_equal(refreshed.x, 10, "FCEUX periodic refresh should update moving NPC x")
    assert_equal(refreshed.y, 9, "FCEUX periodic refresh should update moving NPC y")

    env.restore()
end

function tests.bizhawk_periodic_refresh_is_disabled_by_default()
    local env = make_env({is_bizhawk = true})

    env.set_position(0x04, 0, 0)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x04)
    env.objects.next_filter()

    env.set_npc(0, 0x2A, 0x09) -- x=10, y=9 with sprite type 1
    for _ = 1, 25 do
        env.objects.check_refresh(0x04)
    end

    local stale = env.objects.current_object()
    assert_equal(stale.x, 5, "BizHawk should not refresh moving NPC x in the background by default")
    assert_equal(stale.y, 7, "BizHawk should not refresh moving NPC y in the background by default")

    env.restore()
end

function tests.bizhawk_periodic_refresh_can_be_opted_in()
    local env = make_env({
        is_bizhawk = true,
        bizhawk_periodic_npc_refresh = "true",
    })

    env.set_position(0x04, 0, 0)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x04)
    env.objects.next_filter()

    env.set_npc(0, 0x2A, 0x09) -- x=10, y=9 with sprite type 1
    for _ = 1, 20 do
        env.objects.check_refresh(0x04)
    end

    local refreshed = env.objects.current_object()
    assert_equal(refreshed.x, 10, "BizHawk opt-in periodic refresh should update moving NPC x")
    assert_equal(refreshed.y, 9, "BizHawk opt-in periodic refresh should update moving NPC y")

    env.restore()
end

local failures = 0
local total = 0

for name, fn in pairs(tests) do
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        io.write(string.format("PASS  %s\n", name))
    else
        failures = failures + 1
        io.write(string.format("FAIL  %s: %s\n", name, tostring(err)))
    end
end

io.write(string.format("Ran %d Lua unit tests\n", total))

if failures > 0 then
    os.exit(1)
end
