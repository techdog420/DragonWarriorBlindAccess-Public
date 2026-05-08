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
            is_large_tile = function(map_id, x, y)
                return large_tiles[string.format("0x%02X:%d,%d", map_id, x, y)] == true
            end,
            is_walkable = function(map_id, x, y)
                return walkable_tiles[string.format("0x%02X:%d,%d", map_id, x, y)] == true
            end,
        }
    end

    package.preload["maps"] = function()
        return {
            get_name = function(map_id)
                return string.format("Map %02X", map_id)
            end,
        }
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
        "Guard (visited): 2 north, 5 west (1 of 1)",
        "stale cached object should show visited once its live slot was marked")

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
        "Weapons Merchant: 2 north, counter here (1 of 2)",
        "merchant description should name the usable counter square")

    local marked = env.objects.mark_adjacent_npc_visited(0x08, 5, 6)
    assert_equal(marked.id, "npc_0", "counter interaction should mark the selected merchant visited")
    assert_equal(env.objects.is_visited(obj, 0x08), true, "counter interaction visit should persist on the merchant")

    env.restore()
end

function tests.service_counter_inference_uses_adjacent_large_tile_public_stand()
    local env = make_env({
        large_tiles = {
            ["0x09:9,21"] = true,
            ["0x09:24,25"] = true,
        },
        walkable_tiles = {
            ["0x09:8,21"] = true,
            ["0x09:23,25"] = true,
        },
        npc_count = 4,
    })

    env.set_position(0x09, 12, 23)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x60 + 5, 0x04, 0x00)
    env.set_npc(1, 0x60 + 1, 0x01, 0x00)
    env.set_npc(2, 0x60 + 10, 0x15, 0x00)
    env.set_npc(3, 0x60 + 25, 0x19, 0x00)
    env.objects.refresh(0x09)

    local merchant3 = nil
    local merchant4 = nil
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.name == "Merchant 3" then
            merchant3 = obj
        elseif obj.name == "Merchant 4" then
            merchant4 = obj
        end
    end

    assert_equal(merchant3 ~= nil, true, "Brecconary Merchant 3 should be present in the service list")
    assert_equal(merchant3.interaction_x, 8, "Merchant 3 should use the public stand west of the raw large tile")
    assert_equal(merchant3.interaction_y, 21, "Merchant 3 counter stand Y should match the raw large tile row")
    assert_equal(merchant3.interaction_face_dir, "east", "Merchant 3 should face east through the counter")
    assert_equal(merchant3.interaction_label, "counter", "inferred service stand should be labeled as a counter")

    assert_equal(merchant4 ~= nil, true, "Brecconary Merchant 4 should be present in the service list")
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
        },
        npc_count = 4,
    })

    env.set_position(0x08, 12, 23)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x60 + 5, 0x04, 0x00)
    env.set_npc(1, 0x60 + 1, 0x01, 0x00)
    env.set_npc(2, 0x60 + 10, 0x15, 0x00)
    env.set_npc(3, 0x60 + 25, 0x19, 0x00)
    env.objects.refresh(0x08)

    local inn = nil
    local merchant4 = nil
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.name == "Inn" then
            inn = obj
        elseif obj.name == "Merchant 4" then
            merchant4 = obj
        end
    end

    assert_equal(inn ~= nil, true, "Brecconary inn should be present")
    assert_equal(inn.interaction_x, 8, "Inn should use the live-confirmed public stand tile")
    assert_equal(inn.interaction_y, 21, "Inn public stand Y should match the counter row")
    assert_equal(inn.interaction_face_dir, "east", "Inn should face east toward the inn keeper")

    assert_equal(merchant4 ~= nil, true, "Brecconary Merchant 4 should be present")
    assert_equal(merchant4.interaction_x, 24, "Merchant 4 should use the live-confirmed tool-shop counter tile")
    assert_equal(merchant4.interaction_y, 25, "Merchant 4 live-confirmed counter Y should match the tool-shop large tile")
    assert_equal(merchant4.interaction_face_dir, "east", "Merchant 4 should face east toward the tool-shop keeper")

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
