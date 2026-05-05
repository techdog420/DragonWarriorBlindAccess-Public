-- test_objects.lua
-- Regression tests for object-list refresh behavior across map changes.

local original_preload = {}
local original_loaded = {}
local original_memory = _G.memory
local original_rom = _G.rom
local original_and = _G.AND
local original_emulator_compat = _G.DW_EMULATOR_COMPAT

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

    local npc_ram = {
        [0] = 0x25, -- sprite type 1 (Guard), x=5
        [1] = 0x07, -- y=7
    }
    local terrain_offset = 0x10
    local nav_map_id = 0x01
    local nav_x = 0
    local nav_y = 0

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
            NPC_COUNT = 1,
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
                return nil
            end,
            get_metadata = function()
                return nil
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
        set_npc = function(slot, byte0, byte1)
            local base = slot * 3
            npc_ram[base] = byte0
            npc_ram[base + 1] = byte1
        end,
        set_position = function(map_id, x, y)
            nav_map_id = map_id
            nav_x = x
            nav_y = y
        end,
        restore = function()
            restore_modules(module_names)
            _G.memory = original_memory
            _G.rom = original_rom
            _G.AND = original_and
            _G.DW_EMULATOR_COMPAT = original_emulator_compat
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
    env.set_npc(0, 0x65, 0x07) -- sprite type 3 (Merchant), x=5, y=7
    env.objects.refresh(0x08)

    env.objects.next_filter() -- NPCs
    env.objects.next_filter() -- Services

    assert_equal(env.objects.get_count(), 1, "Services filter should include merchant-type NPCs")
    local obj = env.objects.current_object()
    assert_equal(obj.name, "Merchant", "merchant sprite should keep its service-facing label")
    assert_equal(obj.service, true, "merchant NPCs should be marked as services")

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
