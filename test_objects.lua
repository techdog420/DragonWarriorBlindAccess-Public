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
        "darkness",
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
    local combat_flags = options.combat_flags or 0
    local nav_map_id = 0x01
    local nav_x = 0
    local nav_y = 0
    local tile_grid_calls = 0
    local large_tiles = options.large_tiles or {}
    local walkable_tiles = options.walkable_tiles or {}
    local directional_blocks = options.directional_blocks or {}
    local tile_grid = options.tile_grid
    local memory_bytes = options.memory_bytes or {}

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
            if address == 0x00DF then
                return combat_flags
            end
            if memory_bytes[address] ~= nil then
                return memory_bytes[address]
            end
            return npc_ram[address] or 0
        end,
    }

    local rom_bytes = options.rom_bytes or {}
    _G.rom = {
        readbyte = function(address)
            return rom_bytes[address] or 0
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
            ROM_CHEST_START = options.rom_chest_start or 0,
            ROM_CHEST_END = options.rom_chest_end or -1,
            ROM_CHEST_SIZE = 4,
            TERRAIN_OFFSET = 0x0016,
            COMBAT_FLAGS = 0x00DF,
            CHEST_X_POS_START = 0x601C,
            CHEST_Y_POS_START = 0x601D,
            CHEST_ARRAY_MAX = 8,
            CHEST_ARRAY_STRIDE = 2,
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
                return tile_grid
            end,
            get_metadata = function()
                if tile_grid then
                    return {
                        width = options.map_width or 32,
                        height = options.map_height or 32,
                    }
                end
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
                if key == "darkness_navigation_limits" then
                    return options.darkness_navigation_limits or "true"
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
        set_combat_flags = function(value)
            combat_flags = value
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
        set_memory = function(address, value)
            memory_bytes[address] = value
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

local function find_by_id(objects, id)
    for _, obj in ipairs(objects.get_objects()) do
        if obj.id == id then
            return obj
        end
    end
    return nil
end

local tests = {}

function tests.rom_chest_open_status_uses_native_treasure_ram_across_reload()
    local env = make_env({
        npc_count = 0,
        rom_chest_start = 0,
        rom_chest_end = 3,
        rom_bytes = {
            [0] = 0x06, [1] = 13, [2] = 13, [3] = 0x02,
        },
    })

    env.set_position(0x06, 13, 13)
    env.objects.refresh(0x06)
    local chest = assert(env.objects.find_object_by_id("chest_0"))
    assert_equal(chest.native_chest, true, "ROM-parsed chests should use the game's native pickup history")

    assert_equal(
        env.objects.record_fallback_treasure_collection_at(13, 13),
        nil,
        "ROM chests should be excluded from fallback collection tracking")
    assert_equal(
        env.objects.describe_object(chest):find("(opened)", 1, true),
        nil,
        "fallback collection tracking should not mark a native chest opened")

    env.set_memory(0x601C, 13)
    env.set_memory(0x601D, 13)
    assert_equal(
        env.objects.describe_object(chest):find("(opened)", 1, true) ~= nil,
        true,
        "native treasure RAM should mark the matching ROM chest opened")

    env.objects = env.reload_objects()
    env.objects.refresh(0x06)
    chest = assert(env.objects.find_object_by_id("chest_0"))
    assert_equal(
        env.objects.describe_object(chest):find("(opened)", 1, true) ~= nil,
        true,
        "native treasure RAM should preserve opened status across Lua reloads")

    env.restore()
end

function tests.non_rom_treasure_fallback_requires_exact_coordinate()
    local env = make_env({npc_count = 0})

    env.set_position(0x07, 9, 6)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x07)
    local flute = assert(env.objects.find_object_by_id("chest_kol_fairy_flute"))

    assert_equal(
        env.objects.record_fallback_treasure_collection_at(10, 6),
        nil,
        "adjacent inventory changes should not mark a hidden treasure collected")
    assert_equal(
        env.objects.describe_object(flute):find("(opened)", 1, true),
        nil,
        "an adjacent inventory change should leave hidden treasure closed")

    assert_equal(
        env.objects.record_fallback_treasure_collection_at(9, 6).id,
        "chest_kol_fairy_flute",
        "an exact-coordinate inventory change should record the hidden treasure")
    assert_equal(
        env.objects.describe_object(flute):find("(opened)", 1, true) ~= nil,
        true,
        "the hidden treasure fallback should report collected session state")

    env.restore()
end

function tests.garins_grave_b1_rom_chests_and_b2_stairs_are_exposed()
    local env = make_env({
        rom_chest_start = 0,
        rom_chest_end = 11,
        rom_bytes = {
            [0] = 0x18, [1] = 11, [2] = 0, [3] = 0x02,
            [4] = 0x18, [5] = 12, [6] = 0, [7] = 0x12,
            [8] = 0x18, [9] = 13, [10] = 0, [11] = 0x13,
        },
    })

    env.objects.refresh(0x18)

    assert_equal(find_by_id(env.objects, "stair_19_0"), nil, "stale B1 stairs placeholder should stay removed")

    local stairs = find_by_id(env.objects, "stair_1_18")
    assert_equal(stairs.name, "Stairs Down", "B1 stairs down should avoid revealing the destination floor")

    for index, x in ipairs({11, 12, 13}) do
        local chest = find_by_id(env.objects, "chest_" .. (index - 1))
        assert_equal(chest.x, x, "B1 chest x should match ROM table")
        assert_equal(chest.y, 0, "B1 row-0 chest coordinates should be preserved")
        assert_equal(chest.interaction_x, nil, "B1 chests should route to the chest tile, not an offset stand")
    end

    env.set_terrain_offset(0x20)
    env.objects.refresh(0x19)

    assert_equal(find_by_id(env.objects, "stair_19_0"), nil, "stale B2 stairs placeholder should stay removed")
    for _, stair_id in ipairs({
        "stair_11_2",
        "stair_1_1",
        "stair_12_1",
        "stair_5_6",
        "stair_1_10",
        "stair_12_10",
    }) do
        assert_equal(find_by_id(env.objects, stair_id) ~= nil, true, "B2 should expose " .. stair_id)
    end

    assert_equal(find_by_id(env.objects, "stair_11_2").name, "Stairs Up", "B2 up stairs should keep direction without naming B1")
    assert_equal(find_by_id(env.objects, "stair_1_1").name, "Northwest Stairs Down", "B2 northwest stairs should keep compass and down direction without naming B3")
    assert_equal(find_by_id(env.objects, "stair_12_1").name, "Northeast Stairs Down", "B2 northeast stairs should keep compass and down direction without naming B3")
    assert_equal(find_by_id(env.objects, "stair_5_6").name, "Central Stairs Down", "B2 center stairs should keep central and down direction without naming B3")
    assert_equal(find_by_id(env.objects, "stair_1_10").name, "Southwest Stairs Down", "B2 southwest stairs should keep compass and down direction without naming B3")
    assert_equal(find_by_id(env.objects, "stair_12_10").name, "Southeast Stairs Down", "B2 southeast stairs should keep compass and down direction without naming B3")

    env.restore()
end

function tests.garins_grave_b3_and_b4_rom_stairs_are_exposed()
    local env = make_env()

    env.set_terrain_offset(0x20)
    env.objects.refresh(0x1A)

    assert_equal(find_by_id(env.objects, "stair_12_12"), nil, "stale B3 stairs placeholder should stay removed")
    assert_equal(find_by_id(env.objects, "stair_1_1"), nil, "stale B3 down-stairs placeholder should stay removed")
    for _, stair_id in ipairs({
        "stair_14_1",
        "stair_18_1",
        "stair_6_11",
        "stair_2_17",
        "stair_18_13",
        "stair_9_5",
        "stair_10_9",
    }) do
        assert_equal(find_by_id(env.objects, stair_id) ~= nil, true, "B3 should expose " .. stair_id)
    end

    local b3_upper = find_by_id(env.objects, "stair_9_5")
    local b3_lower = find_by_id(env.objects, "stair_10_9")
    assert_equal(find_by_id(env.objects, "stair_14_1").name, "Northwest Stairs Up", "B3 northwest return stairs should keep compass and up direction without naming B2")
    assert_equal(find_by_id(env.objects, "stair_18_1").name, "Northeast Stairs Up", "B3 northeast return stairs should keep compass and up direction without naming B2")
    assert_equal(find_by_id(env.objects, "stair_6_11").name, "Central Stairs Up", "B3 center return stairs should keep central and up direction without naming B2")
    assert_equal(find_by_id(env.objects, "stair_2_17").name, "Southwest Stairs Up", "B3 southwest return stairs should keep compass and up direction without naming B2")
    assert_equal(find_by_id(env.objects, "stair_18_13").name, "Southeast Stairs Up", "B3 southeast return stairs should keep compass and up direction without naming B2")
    assert_equal(b3_upper.name, "Upper Stairs Down", "B3 stair_9_5 should keep upper and down direction without naming B4")
    assert_equal(b3_lower.name, "Lower Stairs Down", "B3 stair_10_9 should keep lower and down direction without naming B4")

    env.objects.refresh(0x1B)

    assert_equal(find_by_id(env.objects, "stair_1_1"), nil, "stale B4 stairs placeholder should stay removed")
    for _, stair_id in ipairs({"stair_0_4", "stair_5_4"}) do
        assert_equal(find_by_id(env.objects, stair_id) ~= nil, true, "B4 should expose " .. stair_id)
    end

    local b4_west = find_by_id(env.objects, "stair_0_4")
    local b4_east = find_by_id(env.objects, "stair_5_4")
    assert_equal(b4_west.name, "West Stairs Up", "B4 stair_0_4 should keep west and up direction without naming B3")
    assert_equal(b4_east.name, "East Stairs Up", "B4 stair_5_4 should keep east and up direction without naming B3")

    env.restore()
end

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

function tests.hauksness_never_exposes_stale_town_npc_ram()
    local env = make_env({npc_count = 20})

    env.set_position(0x03, 0, 10)
    env.set_terrain_offset(0x10)
    env.objects.on_map_change(0x03, {previous_map_id = 0x01})

    for _ = 1, 100 do
        env.objects.check_refresh(0x03)
    end

    assert_equal(#env.objects.get_blocking_positions(), 0, "Hauksness should not turn unused town NPC RAM into blockers")
    env.objects.next_filter()
    assert_equal(env.objects.get_count(), 0, "Hauksness NPC filter should not expose unused town NPC RAM")

    env.restore()
end

function tests.charlock_never_exposes_stale_town_npc_ram()
    local env = make_env({npc_count = 20})

    env.set_position(0x02, 10, 19)
    env.set_terrain_offset(0x10)
    env.objects.on_map_change(0x02, {previous_map_id = 0x04})

    for _ = 1, 100 do
        env.objects.check_refresh(0x02)
    end

    assert_equal(#env.objects.get_blocking_positions(), 0, "Charlock should not turn stale castle NPC RAM into blockers")
    env.objects.next_filter()
    assert_equal(env.objects.get_count(), 0, "Charlock NPC filter should not expose stale castle NPC RAM")

    env.restore()
end

function tests.hauksness_exposes_safe_axe_knight_travel_landmark_without_treasure_hint()
    local env = make_env({npc_count = 20})

    env.set_position(0x03, 17, 12)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x03)

    local id = "landmark_hauksness_axe_knight"
    local landmark = env.objects.find_object_by_id(id)
    assert_equal(landmark ~= nil, true, "Hauksness should expose the fixed Axe Knight approach")
    assert_equal(landmark.name, "Axe Knight Approach", "encounter landmark should use the approved player-facing name")
    assert_equal(landmark.type, env.objects.TYPE_EXIT, "encounter landmark should reuse the Travel-compatible type")
    assert_equal(landmark.x, 18, "encounter landmark should retain the fixed battle X")
    assert_equal(landmark.y, 12, "encounter landmark should retain the fixed battle Y")
    assert_equal(landmark.interaction_x, 17, "encounter landmark should route to the safe west stand X")
    assert_equal(landmark.interaction_y, 12, "encounter landmark should route to the safe west stand Y")
    assert_equal(landmark.interaction_face_dir, "east", "safe stand should face east toward the encounter")
    assert_equal(landmark.interaction_label, "safe approach", "object speech should identify the preparation point")
    assert_equal(
        env.objects.describe_object(landmark),
        "Axe Knight Approach: 1 east, safe approach here",
        "object speech should identify the encounter and safe stand without naming the reward"
    )

    local expected_by_filter = {
        [env.objects.FILTER_ALL] = true,
        [env.objects.FILTER_NPC] = false,
        [env.objects.FILTER_SERVICE] = false,
        [env.objects.FILTER_TREASURE] = false,
        [env.objects.FILTER_TRAVEL] = true,
        [env.objects.FILTER_DOOR] = false,
    }
    for filter, expected in pairs(expected_by_filter) do
        env.objects.set_filter(filter)
        assert_equal(
            env.objects.find_object_by_id(id, {filtered = true}) ~= nil,
            expected,
            "Axe Knight approach filter membership should match the approved design"
        )
    end

    env.objects.set_filter(env.objects.FILTER_TREASURE)
    assert_equal(env.objects.get_count(), 0, "Hauksness should not expose the buried armor under Treasure")

    local exposed = (landmark.name .. " " .. env.objects.describe_object(landmark)):lower()
    assert_equal(exposed:find("armor", 1, true), nil, "landmark speech should not name the armor")
    assert_equal(exposed:find("erdrick", 1, true), nil, "landmark speech should not name the reward")
    assert_equal(exposed:find("search", 1, true), nil, "landmark speech should not suggest SEARCH")

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
    assert_equal(b1_stair.name, "Stairs Down", "Erdrick B1 stairs should keep down direction without naming B2")

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
    assert_equal(b2_stair.name, "Stairs Up", "Erdrick B2 stairs should keep up direction without naming B1")

    env.restore()
end

function tests.other_internal_dungeon_stairs_avoid_destination_spoilers()
    local env = make_env()

    env.set_terrain_offset(0x20)

    env.objects.refresh(0x16)
    assert_equal(find_by_id(env.objects, "stair_0_0").name, "Northwest Stairs Down", "Mountain Cave F1 northwest stairs should be distinct without naming B2")
    assert_equal(find_by_id(env.objects, "stair_6_5").name, "Central Stairs Down", "Mountain Cave F1 central stairs should be distinct without naming B2")
    assert_equal(find_by_id(env.objects, "stair_12_12").name, "Southeast Stairs Down", "Mountain Cave F1 southeast stairs should be distinct without naming B2")

    env.objects.refresh(0x17)
    assert_equal(find_by_id(env.objects, "stair_0_0").name, "Northwest Stairs Up", "Mountain Cave B2 northwest stairs should be distinct without naming F1")
    assert_equal(find_by_id(env.objects, "stair_6_5").name, "Central Stairs Up", "Mountain Cave B2 central stairs should be distinct without naming F1")
    assert_equal(find_by_id(env.objects, "stair_12_12").name, "Southeast Stairs Up", "Mountain Cave B2 southeast stairs should be distinct without naming F1")

    env.objects.refresh(0x02)
    assert_equal(find_by_id(env.objects, "stair_10_1").name, "Stairs Down", "Charlock Castle stairs should keep down direction without naming B1")
    assert_equal(find_by_id(env.objects, "stair_4_14").name, "West Stairs Down", "Charlock Castle west decoy stairs should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_15_14").name, "East Stairs Down", "Charlock Castle east decoy stairs should use the live-proven coordinate")

    env.objects.refresh(0x0F)
    assert_equal(find_by_id(env.objects, "stair_9_0").name, "North Stairs Up", "Dragonlord B1 north stairs should use the live-proven return stand without naming Charlock Castle")
    assert_equal(find_by_id(env.objects, "stair_10_1"), nil, "Dragonlord B1 should not expose the false north-stair coordinate")
    assert_equal(find_by_id(env.objects, "stair_8_13").name, "West Stairs Up", "Dragonlord B1 west decoy return should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_17_15").name, "East Stairs Up", "Dragonlord B1 east decoy return should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_15_1").name, "North Stairs Down", "Dragonlord B1 sword-network connector should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_13_7").name, "Northeast Stairs Down", "Dragonlord B1 sword-branch stairs should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_19_7").name, "East Stairs Down", "Dragonlord B1 east connector should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_14_9").name, "Central Stairs Down", "Dragonlord B1 central connector should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_2_14").name, "Southwest Stairs Down", "Dragonlord B1 southwest connector should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_2_4").name, "Northwest Stairs Down", "Dragonlord B1 northwest connector should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_8_19").name, "South Stairs Down", "Dragonlord B1 south stairs should use the ROM-confirmed main-spine coordinate without naming B2")
    assert_equal(find_by_id(env.objects, "stair_7_7"), nil, "Dragonlord B1 should not expose the provisional south-stair coordinate")

    env.objects.refresh(0x10)
    assert_equal(find_by_id(env.objects, "stair_5_0").name, "North Stairs Up", "Dragonlord B2 north return stairs should use the live-proven main-spine landing without naming B1")
    assert_equal(find_by_id(env.objects, "stair_3_0").name, "North Stairs Down", "Dragonlord B2 north descent should use the live-proven main-spine coordinate without naming B3")
    assert_equal(find_by_id(env.objects, "stair_8_0").name, "Northeast Stairs Up", "Dragonlord B2 sword-network B1 connector should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_9_1").name, "Northeast Stairs Down", "Dragonlord B2 sword-network B3 connector should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_4_4").name, "Central Stairs Up", "Dragonlord B2 sword-room return should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_9_8").name, "Southeast Stairs Up", "Dragonlord B2 southeast connector should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_8_9").name, "South Stairs Up", "Dragonlord B2 south connector should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_0_1").name, "West Stairs Up", "Dragonlord B2 west connector should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_0_0").name, "Northwest Stairs Up", "Dragonlord B2 northwest connector should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_7_7"), nil, "Dragonlord B2 should not expose the stale southeast up-stair placeholder")
    assert_equal(find_by_id(env.objects, "stair_3_3"), nil, "Dragonlord B2 should not expose the stale northwest down-stair placeholder")

    env.objects.refresh(0x11)
    assert_equal(find_by_id(env.objects, "stair_7_0").name, "North Stairs Up", "Dragonlord B3 main arrival stair should use the ROM-backed coordinate")
    assert_equal(find_by_id(env.objects, "stair_2_2").name, "Northwest Stairs Up", "Dragonlord B3 northwest return stair should use the ROM-backed coordinate")
    assert_equal(find_by_id(env.objects, "stair_5_4").name, "Central Stairs Up", "Dragonlord B3 central return stair should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_0_9").name, "Southwest Stairs Up", "Dragonlord B3 southwest return stair should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_1_6").name, "West Stairs Down", "Dragonlord B3 main descent should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_7_7").name, "Southeast Stairs Down", "Dragonlord B3 sword-branch descent should use the ROM-backed coordinate")
    assert_equal(find_by_id(env.objects, "stair_3_3"), nil, "Dragonlord B3 should not expose the stale ordinary-floor placeholder")

    env.objects.refresh(0x12)
    assert_equal(find_by_id(env.objects, "stair_0_9").name, "Southwest Stairs Up", "Dragonlord B4 main arrival stair should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_7_7").name, "Southeast Stairs Up", "Dragonlord B4 sword-branch return should use the ROM-backed coordinate")
    assert_equal(find_by_id(env.objects, "stair_2_2").name, "Northwest Stairs Down", "Dragonlord B4 main descent should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_8_1").name, "Northeast Stairs Down", "Dragonlord B4 false-branch descent should use the ROM-backed coordinate")

    env.objects.refresh(0x13)
    assert_equal(find_by_id(env.objects, "stair_9_0").name, "Northeast Stairs Up", "Dragonlord B5 main arrival stair should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_4_0").name, "North Stairs Up", "Dragonlord B5 false-branch return should use the ROM-backed coordinate")
    assert_equal(find_by_id(env.objects, "stair_0_0").name, "Northwest Stairs Down", "Dragonlord B5 main descent should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_5_5").name, "Central Stairs Down", "Dragonlord B5 false-branch descent should use the ROM-backed coordinate")

    env.objects.refresh(0x14)
    assert_equal(find_by_id(env.objects, "stair_0_6").name, "West Stairs Up", "Dragonlord B6 main arrival stair should use the live-proven coordinate")
    assert_equal(find_by_id(env.objects, "stair_0_0").name, "Northwest Stairs Up", "Dragonlord B6 false-branch return should use the ROM-backed coordinate")
    assert_equal(find_by_id(env.objects, "stair_9_0").name, "Northeast Loop Stairs", "Dragonlord B6 same-floor loop stair should be labeled without a false floor direction")
    assert_equal(find_by_id(env.objects, "stair_9_6").name, "East Stairs Down", "Dragonlord B6 final descent should use the live-proven coordinate")

    env.objects.refresh(0x06)
    assert_equal(find_by_id(env.objects, "stair_10_29").name, "South Stairs Up", "Dragonlord's Lair should expose the live-proven return stair under Travel")

    env.restore()
end

function tests.charlock_castle_exposes_live_side_room_doors()
    local env = make_env({npc_count = 0})

    env.set_position(0x02, 15, 9)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x02)
    env.objects.set_filter(env.objects.FILTER_DOOR)

    local doors = env.objects.get_objects({filtered = true})
    assert_equal(#doors, 2, "Charlock Castle should expose both live-opened side-room doors")
    local by_id = {}
    for _, door in ipairs(doors) do
        by_id[door.id] = door
    end

    local west = by_id.door_4_8
    assert_equal(west ~= nil, true, "Charlock Castle should expose the west side-room door")
    assert_equal(west.name, "West Side Room Door", "Charlock west door should have a positional label")
    assert_equal(#west.interaction_points, 2, "Charlock west door should support both approach sides")
    assert_equal(west.interaction_points[1].x, 4, "Charlock west door public stand x should match live OPEN proof")
    assert_equal(west.interaction_points[1].y, 7, "Charlock west door public stand y should match live OPEN proof")
    assert_equal(west.interaction_points[1].face_dir, "south", "Charlock west door public stand should face south")

    local east = by_id.door_15_8
    assert_equal(east ~= nil, true, "Charlock Castle should expose the east side-room door")
    assert_equal(east.name, "East Side Room Door", "Charlock east door should have a positional label")
    assert_equal(#east.interaction_points, 2, "Charlock east door should support both approach sides")
    assert_equal(east.interaction_points[2].x, 15, "Charlock east door room-side stand x should match the decoded pocket")
    assert_equal(east.interaction_points[2].y, 9, "Charlock east door room-side stand y should match the decoded pocket")
    assert_equal(east.interaction_points[2].face_dir, "north", "Charlock east door room-side stand should face north")

    env.restore()
end

function tests.dragonlord_lair_boss_npc_uses_final_encounter_label()
    local env = make_env()

    env.set_npc(0, 0xA0 + 16, 0x18, 0x00) -- Old Man sprite at (16,24)
    env.objects.refresh(0x06)

    local boss = find_by_id(env.objects, "npc_0")
    assert_equal(boss ~= nil, true, "Dragonlord's Lair should expose the final NPC")
    assert_equal(boss.name, "Dragonlord", "the final NPC should not keep the generic Old Man sprite label")
    assert_equal(boss.x, 16, "Dragonlord should keep the live-confirmed X coordinate")
    assert_equal(boss.y, 24, "Dragonlord should keep the live-confirmed Y coordinate")
    assert_equal(boss.service, false, "Dragonlord should remain outside the Services filter")

    env.restore()
end

function tests.dragonlord_lair_uses_confirmed_treasure_door_not_type_five_stair()
    local grid = {}
    for y = 0, 29 do
        grid[y] = {}
    end
    grid[29][10] = 5 -- Live STAIRS-command entry tile, not a locked door.

    local env = make_env({
        npc_count = 0,
        tile_grid = grid,
        map_width = 30,
        map_height = 30,
    })
    env.set_terrain_offset(0x20) -- Reproduce the stale dungeon scan at map entry.
    env.objects.refresh(0x06)

    assert_equal(find_by_id(env.objects, "door_10_29"), nil, "Dragonlord's Lair return stair must not be duplicated as a door")
    local door = find_by_id(env.objects, "door_17_12")
    assert_equal(door ~= nil, true, "Dragonlord's Lair should expose the live-opened treasure-room door")
    assert_equal(door.name, "Treasure Room Door", "Dragonlord's Lair door should identify the treasure room")
    assert_equal(door.interaction_x, 18, "treasure-room door should route first to the live-proven east stand")
    assert_equal(door.interaction_y, 12, "treasure-room door east stand should preserve the live Y coordinate")
    assert_equal(door.interaction_face_dir, "west", "treasure-room door east stand should face west")
    assert_equal(door.interaction_points[2].x, 16, "treasure-room door should retain the inside west stand")
    assert_equal(door.interaction_points[2].y, 12, "treasure-room door inside stand should preserve the live Y coordinate")
    assert_equal(door.interaction_points[2].face_dir, "east", "treasure-room door inside stand should face east")

    env.restore()
end

function tests.mountain_cave_exit_uses_live_stairs_command_tile()
    local env = make_env()

    env.set_terrain_offset(0x20)
    env.objects.refresh(0x16)

    local exit = env.objects.select_object_by_id("exit_0_7")
    assert_equal(exit ~= nil, true, "Mountain Cave should expose the live STAIRS-command exit tile")
    assert_equal(exit.name, "Exit to World Map", "Mountain Cave exit should keep the normal Travel label")
    assert_equal(exit.x, 0, "Mountain Cave exit should stay on the west boundary")
    assert_equal(exit.y, 7, "Mountain Cave exit should use the live entry and STAIRS-command row")
    assert_equal(env.objects.select_object_by_id("exit_0_0"), nil, "Mountain Cave should not retain the stale unreachable exit at (0,0)")

    env.restore()
end

function tests.tantegel_castle_southeast_corner_combines_shrine_stairs_and_exit()
    local env = make_env()

    env.set_terrain_offset(0x10)
    env.objects.refresh(0x04)

    local sun_shrine_stair
    local duplicate_southeast_exit
    local stale_top_right_stair
    local stale_throne_stair
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.type == env.objects.TYPE_STAIR then
            if obj.id == "stair_29_29" then
                sun_shrine_stair = obj
            elseif obj.id == "stair_29_1" then
                stale_top_right_stair = obj
            elseif obj.id == "stair_1_1" then
                stale_throne_stair = obj
            end
        elseif obj.type == env.objects.TYPE_EXIT and obj.id == "exit_29_29" then
            duplicate_southeast_exit = obj
        end
    end

    assert_equal(sun_shrine_stair ~= nil, true, "Tantegel Castle should expose the live STAIRS command at the southeast corner")
    assert_equal(sun_shrine_stair.x, 29, "Sun Shrine stairs should use the live-confirmed x coordinate")
    assert_equal(sun_shrine_stair.y, 29, "Sun Shrine stairs should use the live-confirmed y coordinate")
    assert_equal(sun_shrine_stair.name, "Sun Shrine Stairs and Southeast Exit", "shared southeast tile should have one combined Travel label")
    assert_equal(duplicate_southeast_exit, nil, "Tantegel Castle should not duplicate the shared southeast Travel tile")
    assert_equal(stale_top_right_stair, nil, "Tantegel Castle should not expose the disproved top-right stairs marker")
    assert_equal(stale_throne_stair, nil, "Tantegel Castle should not expose the disproved throne-room stairs marker at (1,1)")

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
    assert_equal(south_stair.name, "South Stairs Up", "Swamp Cave south stairs should keep position and up direction without naming the overworld landing")

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

function tests.swamp_cave_exposes_gwaelin_before_escort_flag()
    local env = make_env({combat_flags = 0x08})

    env.set_position(0x15, 5, 19)
    env.set_terrain_offset(0x20)
    env.objects.refresh(0x15)

    local princess = find_by_id(env.objects, "npc_princess_gwaelin")
    assert_equal(princess ~= nil, true, "Swamp Cave should expose Princess Gwaelin before the escort flag is set")
    assert_equal(princess.name, "Princess Gwaelin", "Princess object should use the live dialogue name")
    assert_equal(princess.type, env.objects.TYPE_NPC, "Princess should be browsed with NPCs")
    assert_equal(princess.x, 5, "Princess object x should match the live TALK target")
    assert_equal(princess.y, 18, "Princess object y should match the live TALK target")
    assert_equal(princess.interaction_x, 5, "Princess should route to the live stand tile")
    assert_equal(princess.interaction_y, 19, "Princess should route to the live stand tile")
    assert_equal(princess.interaction_face_dir, "north", "Princess interaction should face north from the stand")
    assert_equal(princess.interaction_label, "talk", "Princess interaction should be labeled as talk")
    assert_equal(princess.service, false, "Princess should not appear in the service filter")

    env.objects.set_filter(env.objects.FILTER_NPC)
    local filtered_princess = env.objects.find_object_by_id("npc_princess_gwaelin", {filtered = true})
    assert_equal(filtered_princess ~= nil, true, "NPC filter should include Princess Gwaelin in Swamp Cave")

    env.restore()
end

function tests.swamp_cave_hides_gwaelin_after_escort_flag()
    local env = make_env({combat_flags = 0x09})

    env.set_position(0x15, 5, 19)
    env.set_terrain_offset(0x20)
    env.objects.refresh(0x15)

    local princess = find_by_id(env.objects, "npc_princess_gwaelin")
    assert_equal(princess, nil, "Swamp Cave should hide Princess Gwaelin once the escort flag is set")

    env.restore()
end

function tests.swamp_cave_refreshes_gwaelin_visibility_when_escort_flag_changes()
    local env = make_env({combat_flags = 0x08})

    env.set_position(0x15, 5, 19)
    env.set_terrain_offset(0x20)
    env.objects.refresh(0x15)
    assert_equal(find_by_id(env.objects, "npc_princess_gwaelin") ~= nil, true, "Princess should be visible before escort acceptance")

    env.set_combat_flags(0x09)
    env.objects.check_refresh(0x15)
    assert_equal(find_by_id(env.objects, "npc_princess_gwaelin"), nil, "Princess should be hidden as soon as the escort flag appears")

    env.restore()
end

function tests.battle_status_flag_changes_preserve_same_map_object_selection()
    local env = make_env({combat_flags = 0x0A})

    env.set_position(0x03, 0, 10)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x03)
    env.objects.next_object()
    assert_equal(
        env.objects.current_object().id,
        "landmark_hauksness_axe_knight",
        "test should begin with the Axe Knight approach selected"
    )

    env.set_combat_flags(0x0E)
    env.objects.check_refresh(0x03)
    assert_equal(
        env.objects.current_object().id,
        "landmark_hauksness_axe_knight",
        "battle-only status flag changes should not reset the object navigator"
    )

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

function tests.reentering_known_npc_map_from_world_does_not_wait_out_stale_retry()
    local env = make_env()

    env.set_position(0x0D, 4, 9)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x0D)
    env.objects.set_filter(env.objects.FILTER_NPC)
    assert_equal(env.objects.get_count(), 1, "initial Rain Shrine visit should accept the old man NPC RAM")

    env.set_position(0x01, 81, 1)
    env.set_terrain_offset(0x00)
    env.objects.check_refresh(0x01)
    assert_equal(env.objects.get_count(), 0, "world map should clear the prior shrine NPC list")

    env.set_position(0x0D, 4, 9)
    env.set_terrain_offset(0x10)
    env.objects.on_map_change(0x0D, {previous_map_id = 0x01})
    assert_equal(env.objects.get_count(), 0, "transition frame should still defer NPC parsing")
    assert_equal(env.objects.needs_refresh(0x0D), true, "deferred NPC rebuild should be visible to the main loop")

    env.objects.check_refresh(0x0D)
    assert_equal(env.objects.get_count(), 1, "known same-map NPC signature should populate on the first deferred refresh")
    assert_equal(env.objects.needs_refresh(0x0D), false, "known same-map NPC signature should not trigger the long stale retry")

    env.restore()
end

function tests.known_npc_map_terrain_flip_does_not_treat_same_map_signature_as_stale()
    local env = make_env()

    env.set_position(0x0D, 4, 9)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x0D)
    env.objects.set_filter(env.objects.FILTER_NPC)
    assert_equal(env.objects.get_count(), 1, "initial Rain Shrine visit should accept the old man NPC RAM")

    env.set_position(0x01, 81, 1)
    env.set_terrain_offset(0x00)
    env.objects.check_refresh(0x01)
    assert_equal(env.objects.get_count(), 0, "world map should clear the prior shrine NPC list")

    env.set_position(0x0D, 4, 9)
    env.objects.check_refresh(0x0D)
    assert_equal(env.objects.get_count(), 0, "map-id transition with non-NPC terrain should not parse NPCs")

    env.set_terrain_offset(0x10)
    env.objects.check_refresh(0x0D)
    assert_equal(env.objects.get_count(), 0, "terrain transition frame should still defer NPC parsing")
    assert_equal(env.objects.needs_refresh(0x0D), true, "terrain transition should request the deferred NPC rebuild")

    env.objects.check_refresh(0x0D)
    assert_equal(env.objects.get_count(), 1, "same-map known NPC signature should populate after the terrain flip")
    assert_equal(env.objects.needs_refresh(0x0D), false, "same-map terrain flip should not enter the long stale retry")

    env.restore()
end

function tests.reload_inside_known_npc_map_does_not_treat_same_map_signature_as_stale()
    local env = make_env()

    env.set_position(0x0D, 4, 9)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x0D)
    env.objects.set_filter(env.objects.FILTER_NPC)
    assert_equal(env.objects.get_count(), 1, "initial Rain Shrine visit should accept the old man NPC RAM")

    env.objects = env.reload_objects()
    env.set_position(0x0D, 4, 9)
    env.set_terrain_offset(0x10)
    env.objects.check_refresh(0x0D)
    env.objects.set_filter(env.objects.FILTER_NPC)
    assert_equal(env.objects.get_count(), 0, "reload startup frame should still defer NPC parsing")
    assert_equal(env.objects.needs_refresh(0x0D), true, "reload startup should request the deferred NPC rebuild")

    env.objects.check_refresh(0x0D)
    assert_equal(env.objects.get_count(), 1, "reloaded same-map NPC signature should populate on the first deferred refresh")
    assert_equal(env.objects.needs_refresh(0x0D), false, "reloaded same-map signature should not enter the long stale retry")

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
    assert_equal(env.objects.get_count(), 16, "plain world-map Travel should only list major destinations")

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

function tests.cantlin_exit_uses_live_southeast_transition_stand()
    local env = make_env()

    env.set_position(0x0A, 20, 28)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x00, 0x00)
    env.objects.refresh(0x0A)

    local obj = env.objects.select_object_by_id("exit_20_29")
    assert_equal(obj ~= nil, true, "Cantlin should expose the live southeast world-map exit")
    assert_equal(obj.name, "Exit to World Map", "Cantlin should keep the normal town-exit label")
    assert_equal(obj.x, 20, "Cantlin exit should use the live transition X")
    assert_equal(obj.y, 29, "Cantlin exit should use the live transition row")
    assert_equal(obj.interaction_x, 20, "Cantlin exit route should stop on the safe north stand")
    assert_equal(obj.interaction_y, 28, "Cantlin exit stand should avoid stepping through the transition")
    assert_equal(obj.interaction_face_dir, "south", "Cantlin exit stand should face toward the world transition")
    assert_equal(env.objects.select_object_by_id("exit_14_29"), nil, "Cantlin should not expose the striped-barrier placeholder exit")

    env.restore()
end

function tests.cantlin_exposes_separate_town_entrance_waypoint()
    local env = make_env()

    env.set_position(0x0A, 16, 0)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x00, 0x00)
    env.objects.refresh(0x0A)

    local entrance = env.objects.select_object_by_id("travel_cantlin_entrance")
    assert_equal(entrance ~= nil, true, "Cantlin should expose its arrival shelf as a Travel waypoint")
    assert_equal(entrance.name, "Town Entrance", "Cantlin arrival waypoint should have a player-facing label")
    assert_equal(entrance.x, 16, "Cantlin arrival waypoint should use the live player-facing X")
    assert_equal(entrance.y, 0, "Cantlin arrival waypoint should use the live top shelf")

    local exit = env.objects.select_object_by_id("exit_20_29")
    assert_equal(exit ~= nil, true, "Cantlin should preserve the separate southeast world-map exit")

    local northeast_exit = env.objects.select_object_by_id("exit_29_0")
    assert_equal(northeast_exit ~= nil, true, "Cantlin should expose the live northeast world-map exit")
    assert_equal(northeast_exit.name, "Northeast Exit to World Map", "Cantlin northeast exit should have a distinct Travel label")
    assert_equal(northeast_exit.interaction_x, 28, "Cantlin northeast exit should route to the safe west stand")
    assert_equal(northeast_exit.interaction_y, 0, "Cantlin northeast exit stand should remain on the north lane")
    assert_equal(northeast_exit.interaction_face_dir, "east", "Cantlin northeast exit stand should face toward the transition")

    local north_exit = env.objects.select_object_by_id("exit_23_0")
    assert_equal(north_exit ~= nil, true, "Cantlin should expose the live north world-map exit")
    assert_equal(north_exit.name, "North Exit to World Map", "Cantlin north exit should have a distinct Travel label")
    assert_equal(north_exit.interaction_x, 23, "Cantlin north exit should route to the safe south stand")
    assert_equal(north_exit.interaction_y, 1, "Cantlin north exit stand should remain inside town")
    assert_equal(north_exit.interaction_face_dir, "north", "Cantlin north exit stand should face toward the transition")

    env.objects.travel_filter()
    local travel_ids = {}
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        travel_ids[obj.id] = true
    end
    assert_equal(travel_ids["travel_cantlin_entrance"], true, "Cantlin Town Entrance should appear under Travel")
    assert_equal(travel_ids["exit_20_29"], true, "Cantlin southeast exit should remain under Travel")
    assert_equal(travel_ids["exit_29_0"], true, "Cantlin northeast exit should appear under Travel")
    assert_equal(travel_ids["exit_23_0"], true, "Cantlin north exit should appear under Travel")

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

function tests.garinham_does_not_expose_unconfirmed_top_edge_grave_candidate()
    local env = make_env()

    env.set_position(0x09, 18, 1)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x00, 0x00)
    env.objects.refresh(0x09)

    local obj = env.objects.select_object_by_id("exit_18_0")
    assert_equal(obj, nil, "Garinham (18,0)->UP is a world-map exit edge, not the grave stairs object")

    env.restore()
end

function tests.garinham_exposes_confirmed_grave_stairs()
    local env = make_env()

    env.set_position(0x09, 19, 0)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x00, 0x00)
    env.objects.refresh(0x09)

    local obj = env.objects.select_object_by_id("stair_19_0")
    assert_equal(obj ~= nil, true, "Garinham should expose the live-confirmed grave stairs")
    assert_equal(obj.name, "Stairs to Garin's Grave", "Garinham grave stairs should have a distinct navigation label")
    assert_equal(obj.x, 19, "Garinham grave stairs X should match ROM stair table and live STAIRS proof")
    assert_equal(obj.y, 0, "Garinham grave stairs Y should match ROM stair table and live STAIRS proof")

    env.restore()
end

function tests.garins_grave_b1_exposes_live_return_stairs()
    local env = make_env()

    env.set_position(0x18, 6, 11)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x00, 0x00)
    env.objects.refresh(0x18)

    local stale_exit = env.objects.select_object_by_id("exit_0_0")
    assert_equal(stale_exit, nil, "Garin's Grave B1 should not expose the stale fake world-map exit at (0,0)")

    local obj = env.objects.select_object_by_id("stair_6_11")
    assert_equal(obj ~= nil, true, "Garin's Grave B1 should expose the live return stairs")
    assert_equal(obj.name, "Stairs to Garinham", "Garin's Grave B1 return stairs should have a distinct navigation label")
    assert_equal(obj.x, 6, "Garin's Grave B1 return stairs X should match live entry/exit proof")
    assert_equal(obj.y, 11, "Garin's Grave B1 return stairs Y should match live entry/exit proof")

    env.restore()
end

function tests.hauksness_exit_uses_live_west_entry_tile_and_manual_transition()
    local env = make_env({npc_count = 20})

    env.set_position(0x03, 17, 12)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x03)

    local id = "exit_0_10"
    local exit = env.objects.find_object_by_id(id)
    assert_equal(exit ~= nil, true, "Hauksness should expose its live west-edge exit")
    assert_equal(exit.name, "Exit to World Map", "Hauksness should use the normal world-map exit label")
    assert_equal(exit.type, env.objects.TYPE_EXIT, "Hauksness exit should use the Travel-compatible type")
    assert_equal(exit.x, 0, "Hauksness exit should use the live west boundary X")
    assert_equal(exit.y, 10, "Hauksness exit should use the live entry row")
    assert_equal(exit.interaction_x, 0, "Hauksness exit route should stop on the boundary tile")
    assert_equal(exit.interaction_y, 10, "Hauksness exit stand should match the live entry row")
    assert_equal(exit.interaction_face_dir, "west", "Hauksness exit stand should face the world transition")
    assert_equal(exit.interaction_label, "exit", "Hauksness exit should use the generic interaction label")

    local expected_by_filter = {
        [env.objects.FILTER_ALL] = true,
        [env.objects.FILTER_NPC] = false,
        [env.objects.FILTER_SERVICE] = false,
        [env.objects.FILTER_TREASURE] = false,
        [env.objects.FILTER_TRAVEL] = true,
        [env.objects.FILTER_DOOR] = false,
    }
    for filter, expected in pairs(expected_by_filter) do
        env.objects.set_filter(filter)
        assert_equal(
            env.objects.find_object_by_id(id, {filtered = true}) ~= nil,
            expected,
            "Hauksness exit filter membership should match the approved design"
        )
    end

    env.restore()
end

function tests.rimuldar_exits_use_live_transition_tiles()
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

    local northwest_exit = env.objects.select_object_by_id("exit_0_3")
    assert_equal(northwest_exit ~= nil, true, "Rimuldar should expose the live west-edge Magic Key maze exit")
    assert_equal(northwest_exit.name, "Northwest Exit to World Map", "Rimuldar alternate exit should be labeled distinctly")
    assert_equal(northwest_exit.x, 0, "Rimuldar northwest exit should use the live west-edge transition X")
    assert_equal(northwest_exit.y, 3, "Rimuldar northwest exit should use the live transition row")
    assert_equal(northwest_exit.interaction_x, 0, "Rimuldar northwest exit route should stop on the live west-edge exit stand")
    assert_equal(northwest_exit.interaction_y, 3, "Rimuldar northwest exit stand should match the live transition row")
    assert_equal(northwest_exit.interaction_face_dir, "west", "Rimuldar northwest exit stand should face west toward the world transition")
    assert_equal(env.objects.select_object_by_id("exit_4_3"), nil, "Rimuldar should not expose the stale blocked north-facing exit at (4,3)")

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

function tests.magic_temple_exit_uses_live_west_entry_stairs()
    local env = make_env()

    env.set_position(0x0E, 0, 4)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x00, 0x00)
    env.objects.refresh(0x0E)

    local obj = env.objects.select_object_by_id("exit_0_4")
    assert_equal(obj ~= nil, true, "Magic Temple should expose the live west entry stairs")
    assert_equal(obj.name, "Exit to World Map", "Magic Temple should keep the normal exit label")
    assert_equal(obj.x, 0, "Magic Temple exit should use the live entry X")
    assert_equal(obj.y, 4, "Magic Temple exit should use the live entry row")
    assert_equal(obj.interaction_x, 0, "Magic Temple exit route should stand on the stair tile")
    assert_equal(obj.interaction_y, 4, "Magic Temple exit stand should match the live stair row")

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

function tests.rainbow_bridge_unlock_point_is_available_as_overworld_landmark()
    local env = make_env()

    env.set_position(0x01, 65, 49)
    env.set_terrain_offset(0x00)
    env.objects.refresh(0x01)
    env.objects.travel_filter()

    local bridge = env.objects.select_object_by_id("overworld_rainbow_bridge")
    assert_equal(bridge ~= nil, true, "World map should expose the Rainbow Bridge unlock point")
    assert_equal(bridge.name, "Rainbow Bridge unlock point", "Travel should identify the Rainbow Drop use stand")
    assert_equal(bridge.x, 65, "Rainbow Bridge unlock point should use the decoded overworld X")
    assert_equal(bridge.y, 49, "Rainbow Bridge unlock point should use the decoded overworld Y")

    local lookup = assert(env.objects.find_overworld_landmark("rainbow drop"))
    assert_equal(lookup.id, "overworld_rainbow_bridge", "Rainbow Drop lookup should resolve to the unlock point")

    env.restore()
end

function tests.magic_temple_landmark_uses_clear_label_and_stable_id()
    local env = make_env()

    env.set_position(0x01, 108, 109)
    env.set_terrain_offset(0x00)
    env.objects.refresh(0x01)
    env.objects.travel_filter()

    local temple = env.objects.select_object_by_id("overworld_southern_cave")
    assert_equal(temple ~= nil, true, "Magic Temple should retain the route-compatible object id")
    assert_equal(temple.name, "Magic Temple", "Travel should use the player-facing Magic Temple label")
    assert_equal(temple.x, 108, "Magic Temple should retain the validated overworld X")
    assert_equal(temple.y, 109, "Magic Temple should retain the validated overworld Y")

    local by_name = assert(env.objects.find_overworld_landmark("Magic Temple"))
    assert_equal(by_name.id, "overworld_southern_cave", "Magic Temple lookup should retain the stable object id")

    local by_old_name = assert(env.objects.find_overworld_landmark("Southern Cave"))
    assert_equal(by_old_name.id, "overworld_southern_cave", "legacy Southern Cave lookup should remain compatible")

    env.restore()
end

function tests.world_map_exposes_great_swamp_search_area_without_token_square()
    local env = make_env()

    env.set_position(0x01, 73, 102)
    env.set_terrain_offset(0x00)
    env.objects.refresh(0x01)

    local obj = env.objects.select_object_by_id(
        "overworld_eastern_great_swamp_search_area")
    assert_equal(obj ~= nil, true, "World Map should expose the search area")
    assert_equal(obj.name, "Eastern Great Swamp Search Area",
        "landmark should use a clue-preserving name")
    assert_equal(obj.type, env.objects.TYPE_EXIT,
        "search area should remain Travel-compatible")
    assert_equal(obj.x, 89, "safe pin x")
    assert_equal(obj.y, 112, "safe pin y")
    assert_equal(obj.x == 83 and obj.y == 113, false,
        "search-area landmark must not expose the buried square")

    local speech = env.objects.describe_object(obj):lower()
    assert_equal(speech:find("token", 1, true), nil,
        "object speech should not name the token")
    assert_equal(speech:find("erdrick", 1, true), nil,
        "object speech should not name Erdrick")

    env.restore()
end

function tests.sun_shrine_exit_uses_live_west_entry_tile()
    local env = make_env()

    env.set_position(0x0C, 0, 4)
    env.set_terrain_offset(0x20)
    env.set_npc(0, 0x00, 0x00)
    env.objects.refresh(0x0C)

    local obj = env.objects.select_object_by_id("exit_0_4")
    assert_equal(obj ~= nil, true, "Sun Shrine should expose the live west exit")
    assert_equal(obj.name, "Stairs to Tantegel Castle", "Sun Shrine should describe the live return stairs")
    assert_equal(obj.x, 0, "Sun Shrine exit should use the live entry X")
    assert_equal(obj.y, 4, "Sun Shrine exit should use the live entry row")

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

    env.set_npc(0, 0x2A, 0x08, 0x60) -- x=10, y=8 with a roaming movement byte
    assert_equal(env.objects.current_object().x, 5, "object list should stay stale before a refresh")
    assert_equal(
        env.objects.describe_current({include_debug_coords = false}),
        "Guard (roaming): 1 north (1 of 1)",
        "current-object speech should use the selected NPC slot's live position and movement status")
    assert_equal(
        env.objects.describe_current({include_debug_coords = false, use_live_npc = false}),
        "Guard (stationary): 2 north, 5 west (1 of 1)",
        "tests and debug callers can still opt into cached object-list coordinates and movement status")

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
        "Guard (stationary, visited): 2 south (1 of 1)",
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
        "Guard (stationary, visited): 2 south (1 of 1)",
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
        "Guard (stationary, visited): 1 north (1 of 1)",
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
        "Weapons Merchant (stationary): 2 north, counter here (1 of 4)",
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
            ["0x0C:24,25"] = true,
        },
        walkable_tiles = {
            ["0x0C:23,25"] = true,
        },
        npc_count = 3,
    })

    env.set_position(0x0C, 12, 23)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x60 + 5, 0x04, 0x00)
    env.set_npc(1, 0x60 + 10, 0x15, 0x00)
    env.set_npc(2, 0x60 + 25, 0x19, 0x00)
    env.objects.refresh(0x0C)

    local merchant3 = nil
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.name == "Merchant 3" then
            merchant3 = obj
        end
    end

    assert_equal(merchant3 ~= nil, true, "Generic Merchant 3 should be present in the service list")
    assert_equal(merchant3.interaction_x, 23, "Merchant 3 should use the public stand west of the raw large tile")
    assert_equal(merchant3.interaction_y, 25, "Merchant 3 counter stand Y should match the raw large tile row")
    assert_equal(merchant3.interaction_face_dir, "east", "Merchant 3 should face east through the counter")
    assert_equal(merchant3.interaction_label, "counter", "inferred service stand should be labeled as a counter")

    env.restore()
end

function tests.cantlin_confirmed_inn_merchant_uses_live_counter_stand()
    local env = make_env({npc_count = 4})

    env.set_position(0x0A, 8, 5)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x60 + 5, 0x04, 0x00)
    env.set_npc(1, 0x60 + 20, 0x04, 0x00)
    env.set_npc(2, 0x60 + 22, 0x04, 0x00)
    env.set_npc(3, 0x60 + 8, 0x03, 0x00) -- Merchant 4, live-confirmed inn
    env.objects.refresh(0x0A)

    local inn = nil
    local generic_merchant4 = nil
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.name == "Inn" then
            inn = obj
        elseif obj.name == "Merchant 4" then
            generic_merchant4 = obj
        end
    end

    assert_equal(inn ~= nil, true, "Cantlin Merchant 4 should be labeled as Inn after live TALK proof")
    assert_equal(inn.service, true, "Cantlin Inn should remain in Services")
    assert_equal(inn.x, 8, "Cantlin Inn NPC X should match live NPC RAM")
    assert_equal(inn.y, 3, "Cantlin Inn NPC Y should match live NPC RAM")
    assert_equal(inn.interaction_x, 8, "Cantlin Inn should use the live-confirmed public counter stand X")
    assert_equal(inn.interaction_y, 5, "Cantlin Inn should use the live-confirmed public counter stand Y")
    assert_equal(inn.interaction_face_dir, "north", "Cantlin Inn should face north toward the keeper")
    assert_equal(generic_merchant4, nil, "Cantlin Merchant 4 should not keep the generic label")

    env.objects.next_filter() -- NPCs
    env.objects.next_filter() -- Services
    local service_names = {}
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        service_names[#service_names + 1] = obj.name
    end
    local service_text = table.concat(service_names, ", ")
    assert_equal(service_text:find("Inn", 1, true) ~= nil, true, "Services should include the confirmed Cantlin Inn")
    assert_equal(service_text:find("Merchant 4", 1, true), nil, "Services should not keep the stale Cantlin Merchant 4 label")

    local marked = env.objects.mark_adjacent_npc_visited(0x0A, 8, 5)
    assert_equal(marked.id, inn.id, "Cantlin Inn public counter stand should mark the inn visited")
    assert_equal(env.objects.is_visited(inn, 0x0A), true, "Cantlin Inn counter visit should persist from the public stand")

    env.restore()
end

function tests.cantlin_service_roles_survive_inactive_merchant_slots()
    local env = make_env({npc_count = 20})

    env.set_position(0x0A, 15, 1)
    env.set_terrain_offset(0x10)
    env.set_npc(2, 0x60 + 20, 0x06, 0x00)
    env.set_npc(4, 0x60 + 22, 0x04, 0x00)
    env.set_npc(10, 0x60 + 8, 0x03, 0x00) -- Stable inn slot; ordinal shifts to Merchant 3.
    env.set_npc(13, 0x60 + 2, 0x0C, 0x00) -- Stable radish slot; ordinal shifts to Merchant 4.
    env.set_npc(14, 0x60 + 7, 0x0C, 0x00)
    env.set_npc(15, 0x40 + 24, 0x0C, 0x00)
    env.set_npc(16, 0xC0 + 22, 0x0D, 0x00)
    env.set_npc(19, 0x60 + 27, 0x1A, 0x00)
    env.objects.refresh(0x0A)

    local inn = find_by_id(env.objects, "npc_10")
    local radish = find_by_id(env.objects, "npc_13")
    assert_equal(inn.name, "Inn", "Cantlin stable slot 10 should remain the Inn when merchant ordinals shift")
    assert_equal(inn.service, true, "Cantlin stable Inn slot should remain in Services")
    assert_equal(inn.interaction_x, 8, "Cantlin stable Inn slot should keep the public counter stand X")
    assert_equal(inn.interaction_y, 5, "Cantlin stable Inn slot should keep the public counter stand Y")
    assert_equal(radish.name, "Radish Merchant", "Cantlin stable slot 13 should not inherit the shifted Inn ordinal")
    assert_equal(radish.service, false, "Cantlin Radish Merchant should stay out of Services")
    assert_equal(radish.interaction_x, 4, "Cantlin Radish Merchant should keep its dialogue counter stand X")
    assert_equal(radish.interaction_y, 12, "Cantlin Radish Merchant should keep its dialogue counter stand Y")

    env.objects.next_filter() -- NPCs
    env.objects.next_filter() -- Services
    local service_ids = {}
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        service_ids[obj.id] = true
    end
    assert_equal(service_ids["npc_10"], true, "Services should include the stable Cantlin Inn slot")
    assert_equal(service_ids["npc_13"], nil, "Services should exclude the stable Cantlin Radish Merchant slot")

    env.restore()
end
function tests.cantlin_roaming_weapons_merchant_keeps_adjacent_routing()
    local env = make_env({npc_count = 2})

    env.set_position(0x0A, 22, 5)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x60 + 5, 0x04, 0x00)
    env.set_npc(1, 0x60 + 22, 0x04, 0x00) -- Merchant 2, live-confirmed weapons/armor shop
    env.objects.refresh(0x0A)

    local roaming_weapons = nil
    local generic_merchant2 = nil
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.name == "Roaming Weapons Merchant" then
            roaming_weapons = obj
        elseif obj.name == "Merchant 2" then
            generic_merchant2 = obj
        end
    end

    assert_equal(roaming_weapons ~= nil, true, "Cantlin Merchant 2 should be labeled as Roaming Weapons Merchant")
    assert_equal(roaming_weapons.service, true, "Cantlin Roaming Weapons Merchant should remain in Services")
    assert_equal(roaming_weapons.x, 22, "Cantlin Roaming Weapons Merchant NPC X should match live NPC RAM")
    assert_equal(roaming_weapons.y, 4, "Cantlin Roaming Weapons Merchant NPC Y should match live NPC RAM")
    assert_equal(roaming_weapons.interaction_x, nil, "Cantlin Roaming Weapons Merchant should not infer a fixed counter stand")
    assert_equal(generic_merchant2, nil, "Cantlin Merchant 2 should not keep the generic label")

    env.objects.next_filter() -- NPCs
    env.objects.next_filter() -- Services
    local service_names = {}
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        service_names[#service_names + 1] = obj.name
    end
    local service_text = table.concat(service_names, ", ")
    assert_equal(service_text:find("Roaming Weapons Merchant", 1, true) ~= nil, true, "Services should identify the roaming Cantlin Weapons Merchant")
    assert_equal(service_text:find("Merchant 2", 1, true), nil, "Services should not keep the stale Cantlin Merchant 2 label")

    env.restore()
end

function tests.cantlin_magic_key_merchant_uses_verified_south_counter_stand()
    local env = make_env({npc_count = 12})

    env.set_position(0x0A, 16, 0)
    env.set_terrain_offset(0x10)
    env.set_npc(11, 0xA0 + 27, 0x06, 0x00) -- Stable Old Man 2 slot at (27,6)
    env.objects.refresh(0x0A)

    local key_merchant = env.objects.find_object_by_id("npc_11")
    assert_equal(key_merchant ~= nil, true, "Cantlin stable Old Man 2 slot should be present")
    assert_equal(key_merchant.name, "Magic Key Merchant", "Cantlin Old Man 2 should use the confirmed key-shop label")
    assert_equal(key_merchant.service, true, "Cantlin Magic Key Merchant should appear in Services")
    assert_equal(key_merchant.movement, 0x00, "Cantlin Magic Key Merchant should be classified as stationary")
    assert_equal(key_merchant.x, 27, "Cantlin Magic Key Merchant NPC X should match live NPC RAM")
    assert_equal(key_merchant.y, 6, "Cantlin Magic Key Merchant NPC Y should match live NPC RAM")
    assert_equal(key_merchant.interaction_x, 27, "Cantlin Magic Key Merchant should use the public south counter stand X")
    assert_equal(key_merchant.interaction_y, 8, "Cantlin Magic Key Merchant should use the public south counter stand Y")
    assert_equal(key_merchant.interaction_face_dir, "north", "Cantlin Magic Key Merchant stand should face north")
    assert_equal(key_merchant.interaction_label, "counter", "Cantlin Magic Key Merchant stand should be labeled as a counter")

    env.objects.set_filter(env.objects.FILTER_SERVICE)
    local service_ids = {}
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        service_ids[obj.id] = true
    end
    assert_equal(service_ids["npc_11"], true, "Services should include the Cantlin Magic Key Merchant")

    env.set_position(0x0A, 27, 8)
    local marked = env.objects.mark_adjacent_npc_visited(0x0A, 27, 8)
    assert_equal(marked.id, key_merchant.id, "Cantlin key-shop stand should mark the Magic Key Merchant visited")
    assert_equal(env.objects.is_visited(key_merchant, 0x0A), true, "Cantlin key-shop visit should persist on the seller")

    env.restore()
end
function tests.cantlin_fairy_water_merchant_uses_live_counter_stand()
    local env = make_env({npc_count = 2})

    env.set_position(0x0A, 20, 13)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0xC0 + 1, 0x01, 0x00)
    env.set_npc(1, 0xC0 + 22, 0x0D, 0x00) -- Woman 2, live-confirmed Fairy Water seller
    env.objects.refresh(0x0A)

    local fairy_water = env.objects.find_object_by_id("npc_1")
    assert_equal(fairy_water ~= nil, true, "Cantlin Woman 2 should be present")
    assert_equal(fairy_water.name, "Fairy Water Merchant", "Cantlin Woman 2 should use the live service label")
    assert_equal(fairy_water.service, true, "Cantlin Fairy Water Merchant should appear in Services")
    assert_equal(fairy_water.x, 22, "Cantlin Fairy Water Merchant NPC X should match live NPC RAM")
    assert_equal(fairy_water.y, 13, "Cantlin Fairy Water Merchant NPC Y should match live NPC RAM")
    assert_equal(fairy_water.interaction_x, 20, "Cantlin Fairy Water Merchant should use the live west counter stand X")
    assert_equal(fairy_water.interaction_y, 13, "Cantlin Fairy Water Merchant should use the live counter row")
    assert_equal(fairy_water.interaction_face_dir, "east", "Cantlin Fairy Water Merchant should face east across the counter")
    assert_equal(fairy_water.interaction_label, "counter", "Cantlin Fairy Water Merchant stand should be labeled as a counter")

    env.objects.set_filter(env.objects.FILTER_SERVICE)
    local selected = env.objects.find_object_by_id("npc_1")
    assert_equal(selected ~= nil, true, "Services should include the Cantlin Fairy Water Merchant")
    assert_equal(selected.name, "Fairy Water Merchant", "Services should expose the live Fairy Water label")

    local marked = env.objects.mark_adjacent_npc_visited(0x0A, 20, 13)
    assert_equal(marked.id, fairy_water.id, "Cantlin Fairy Water counter stand should mark the seller visited")
    assert_equal(env.objects.is_visited(fairy_water, 0x0A), true, "Cantlin Fairy Water visit should persist from the counter stand")

    env.restore()
end
function tests.cantlin_premium_weapons_merchant_uses_live_counter_stand()
    local env = make_env({npc_count = 2})

    env.set_position(0x0A, 26, 12)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x60 + 1, 0x01, 0x00)
    env.set_npc(1, 0x40 + 24, 0x0C, 0x00) -- Guard 4 sprite, live-confirmed premium seller
    env.objects.refresh(0x0A)

    local premium = env.objects.find_object_by_id("npc_1")
    assert_equal(premium ~= nil, true, "Cantlin Guard 4 should be present")
    assert_equal(premium.name, "Premium Weapons Merchant", "Cantlin Guard 4 should use the live premium shop label")
    assert_equal(premium.service, true, "Cantlin premium weapons merchant should appear in Services")
    assert_equal(premium.x, 24, "Cantlin premium weapons merchant NPC X should match live NPC RAM")
    assert_equal(premium.y, 12, "Cantlin premium weapons merchant NPC Y should match live NPC RAM")
    assert_equal(premium.interaction_x, 26, "Cantlin premium weapons merchant should use the reachable east counter stand X")
    assert_equal(premium.interaction_y, 12, "Cantlin premium weapons merchant should use the live counter row")
    assert_equal(premium.interaction_face_dir, "west", "Cantlin premium weapons merchant should face west across the counter")
    assert_equal(premium.interaction_label, "counter", "Cantlin premium weapons merchant stand should be labeled as a counter")

    env.objects.set_filter(env.objects.FILTER_SERVICE)
    local selected = env.objects.find_object_by_id("npc_1")
    assert_equal(selected ~= nil, true, "Services should include the Cantlin premium weapons merchant")

    local marked = env.objects.mark_adjacent_npc_visited(0x0A, 26, 12)
    assert_equal(marked.id, premium.id, "Cantlin premium counter stand should mark the seller visited")
    assert_equal(env.objects.is_visited(premium, 0x0A), true, "Cantlin premium merchant visit should persist from the counter stand")

    env.restore()
end

function tests.cantlin_confirmed_tool_merchant_uses_live_counter_stand()
    local env = make_env({npc_count = 6})

    env.set_position(0x0A, 5, 12)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x60 + 11, 0x02, 0x00)
    env.set_npc(1, 0x60 + 22, 0x04, 0x00)
    env.set_npc(2, 0x60 + 1, 0x14, 0x00)
    env.set_npc(3, 0x60 + 8, 0x03, 0x00)
    env.set_npc(4, 0x60 + 2, 0x0C, 0x00)
    env.set_npc(5, 0x60 + 7, 0x0C, 0x00) -- Merchant 6, live-confirmed tool shop
    env.objects.refresh(0x0A)

    local tool_merchant = nil
    local generic_merchant6 = nil
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.name == "Tool Merchant" then
            tool_merchant = obj
        elseif obj.name == "Merchant 6" then
            generic_merchant6 = obj
        end
    end

    assert_equal(tool_merchant ~= nil, true, "Cantlin Merchant 6 should be labeled as Tool Merchant after live TALK proof")
    assert_equal(tool_merchant.service, true, "Cantlin Tool Merchant should remain in Services")
    assert_equal(tool_merchant.x, 7, "Cantlin Tool Merchant NPC X should match live NPC RAM")
    assert_equal(tool_merchant.y, 12, "Cantlin Tool Merchant NPC Y should match live NPC RAM")
    assert_equal(tool_merchant.interaction_x, 5, "Cantlin Tool Merchant should use the live-confirmed public counter stand X")
    assert_equal(tool_merchant.interaction_y, 12, "Cantlin Tool Merchant should use the live-confirmed public counter stand Y")
    assert_equal(tool_merchant.interaction_face_dir, "east", "Cantlin Tool Merchant should face east from the counter")
    assert_equal(generic_merchant6, nil, "Cantlin Merchant 6 should not keep the generic label")

    env.objects.set_filter(env.objects.FILTER_SERVICE)
    local service_names = {}
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        service_names[#service_names + 1] = obj.name
    end
    local service_text = table.concat(service_names, ", ")
    assert_equal(service_text:find("Tool Merchant", 1, true) ~= nil, true, "Services should include the confirmed Cantlin Tool Merchant")
    assert_equal(service_text:find("Merchant 6", 1, true), nil, "Services should not keep the stale Cantlin Merchant 6 label")

    local marked = env.objects.mark_adjacent_npc_visited(0x0A, 5, 12)
    assert_equal(marked.id, tool_merchant.id, "Cantlin Tool Merchant public counter stand should mark the tool merchant visited")
    assert_equal(env.objects.is_visited(tool_merchant, 0x0A), true, "Cantlin Tool Merchant counter visit should persist from the public stand")

    env.restore()
end

function tests.cantlin_second_tool_merchant_uses_live_counter_stand()
    local env = make_env({npc_count = 20})

    env.set_position(0x0A, 4, 7)
    env.set_terrain_offset(0x10)
    env.set_npc(12, 0x00 + 2, 0x07, 0x00) -- Person 2, live-confirmed Herb/Torch shop
    env.objects.refresh(0x0A)

    local tool_merchant = env.objects.find_object_by_id("npc_12")
    assert_equal(tool_merchant ~= nil, true, "Cantlin Person 2 should be present")
    assert_equal(tool_merchant.name, "Tool Merchant 2", "Cantlin Person 2 should use the second tool-shop label")
    assert_equal(tool_merchant.service, true, "Cantlin Tool Merchant 2 should appear in Services")
    assert_equal(tool_merchant.x, 2, "Cantlin Tool Merchant 2 NPC X should match live NPC RAM")
    assert_equal(tool_merchant.y, 7, "Cantlin Tool Merchant 2 NPC Y should match live NPC RAM")
    assert_equal(tool_merchant.interaction_x, 4, "Cantlin Tool Merchant 2 should use the public east counter stand X")
    assert_equal(tool_merchant.interaction_y, 7, "Cantlin Tool Merchant 2 should use the live counter row")
    assert_equal(tool_merchant.interaction_face_dir, "west", "Cantlin Tool Merchant 2 should face west across the counter")
    assert_equal(tool_merchant.interaction_label, "counter", "Cantlin Tool Merchant 2 stand should be labeled as a counter")

    env.objects.set_filter(env.objects.FILTER_SERVICE)
    local selected = env.objects.find_object_by_id("npc_12")
    assert_equal(selected ~= nil, true, "Services should include Cantlin Tool Merchant 2")

    local marked = env.objects.mark_adjacent_npc_visited(0x0A, 4, 7)
    assert_equal(marked.id, tool_merchant.id, "Cantlin Tool Merchant 2 counter stand should mark the seller visited")
    assert_equal(env.objects.is_visited(tool_merchant, 0x0A), true, "Cantlin Tool Merchant 2 visit should persist from the counter stand")

    env.restore()
end

function tests.cantlin_merchant_7_uses_live_weapons_counter()
    local env = make_env({npc_count = 7})

    env.set_position(0x0A, 25, 26)
    env.set_terrain_offset(0x10)
    for i = 0, 5 do
        env.set_npc(i, 0x60 + i + 1, 0x01, 0x00)
    end
    env.set_npc(6, 0x60 + 27, 0x1A, 0x00) -- Merchant 7, live-confirmed weapons shop
    env.objects.refresh(0x0A)

    local weapons = env.objects.find_object_by_id("npc_6")
    assert_equal(weapons ~= nil, true, "Cantlin Merchant 7 should be present")
    assert_equal(weapons.name, "Weapons Merchant", "Cantlin Merchant 7 should use the live shop label")
    assert_equal(weapons.service, true, "Cantlin Merchant 7 should remain in Services")
    assert_equal(weapons.x, 27, "Cantlin Merchant 7 NPC X should match live NPC RAM")
    assert_equal(weapons.y, 26, "Cantlin Merchant 7 NPC Y should match live NPC RAM")
    assert_equal(weapons.interaction_x, 25, "Cantlin Merchant 7 should use the live-confirmed public counter stand X")
    assert_equal(weapons.interaction_y, 26, "Cantlin Merchant 7 should use the live-confirmed public counter stand Y")
    assert_equal(weapons.interaction_face_dir, "east", "Cantlin Merchant 7 should face east from the counter")

    env.objects.set_filter(env.objects.FILTER_SERVICE)
    local selected = env.objects.find_object_by_id("npc_6")
    assert_equal(selected.name, "Weapons Merchant", "Services should expose Cantlin Merchant 7 as a Weapons Merchant")

    local marked = env.objects.mark_adjacent_npc_visited(0x0A, 25, 26)
    assert_equal(marked.id, weapons.id, "Cantlin Merchant 7 public counter stand should mark the weapons merchant visited")
    assert_equal(env.objects.is_visited(weapons, 0x0A), true, "Cantlin Merchant 7 counter visit should persist from the public stand")

    env.restore()
end

function tests.cantlin_dialogue_only_merchants_stay_out_of_services()
    local env = make_env({npc_count = 3})

    env.set_position(0x0A, 5, 27)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x60 + 2, 0x05, 0x00) -- Merchant 1, live-confirmed buried-treasure dialogue
    env.set_npc(1, 0x60 + 6, 0x11, 0x00)
    env.set_npc(2, 0x60 + 4, 0x1B, 0x00) -- Merchant 3, live-confirmed Hauksness dialogue
    env.objects.refresh(0x0A)

    local merchant1 = env.objects.find_object_by_id("npc_0")
    assert_equal(merchant1 ~= nil, true, "Cantlin Merchant 1 should remain browsable")
    assert_equal(merchant1.name, "Merchant 1", "Cantlin Merchant 1 should keep its generic NPC label")
    assert_equal(merchant1.service, false, "Cantlin dialogue-only Merchant 1 should not appear in Services")

    local merchant3 = env.objects.find_object_by_id("npc_2")
    assert_equal(merchant3 ~= nil, true, "Cantlin Merchant 3 should remain browsable")
    assert_equal(merchant3.name, "Merchant 3", "Cantlin Merchant 3 should keep its generic NPC label")
    assert_equal(merchant3.service, false, "Cantlin dialogue-only Merchant 3 should not appear in Services")

    env.objects.set_filter(env.objects.FILTER_SERVICE)
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        assert_equal(obj.id ~= "npc_0", true, "Services should not route to Cantlin Merchant 1")
        assert_equal(obj.id ~= "npc_2", true, "Services should not route to Cantlin Merchant 3")
    end

    env.restore()
end

function tests.cantlin_radish_merchant_stays_out_of_services()
    local env = make_env({npc_count = 14})

    env.set_position(0x0A, 4, 12)
    env.set_terrain_offset(0x10)
    env.set_npc(13, 0x60 + 2, 0x0C, 0x00) -- Stable slot 13, live-confirmed radish dialogue
    env.objects.refresh(0x0A)

    local radish = env.objects.find_object_by_id("npc_13")
    assert_equal(radish ~= nil, true, "Cantlin stable Radish Merchant slot should be present")
    assert_equal(radish.name, "Radish Merchant", "Cantlin stable slot 13 should get the live dialogue label")
    assert_equal(radish.service, false, "Radish dialogue merchant should not be treated as an essential service")
    assert_equal(radish.interaction_x, 4, "Radish Merchant should route to the live-confirmed public stand X")
    assert_equal(radish.interaction_y, 12, "Radish Merchant should route to the live-confirmed public stand Y")
    assert_equal(radish.interaction_face_dir, "west", "Radish Merchant public stand should face west")
    assert_equal(radish.interaction_label, "counter", "Radish Merchant public stand should be labeled as a counter")

    env.objects.set_filter(env.objects.FILTER_SERVICE)
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        assert_equal(obj.name ~= "Radish Merchant", true, "Services should not include the radish dialogue merchant")
        assert_equal(obj.id ~= "npc_13", true, "Services should not route to the stable Cantlin Radish Merchant slot")
    end

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

function tests.kol_exposes_confirmed_locked_doors()
    local env = make_env({npc_count = 0})

    env.set_position(0x07, 8, 12)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x07)

    env.objects.set_filter(env.objects.FILTER_DOOR)

    local doors = env.objects.get_objects({filtered = true})
    assert_equal(#doors, 2, "Kol should expose both live-confirmed locked doors")
    local by_id = {}
    for _, door in ipairs(doors) do
        by_id[door.id] = door
    end

    local western = by_id.door_7_12
    assert_equal(western ~= nil, true, "Kol should expose the western-building door")
    assert_equal(western.name, "Western Building Door", "Kol western-building door should have a useful navigation label")
    assert_equal(western.x, 7, "Kol western-building door x should match opened-door RAM")
    assert_equal(western.y, 12, "Kol western-building door y should match opened-door RAM")
    assert_equal(western.interaction_x, 8, "Kol western-building door should route to the public east stand")
    assert_equal(western.interaction_y, 12, "Kol western-building door stand should match live verifier proof")
    assert_equal(western.interaction_face_dir, "west", "Kol western-building door should open from the east stand facing west")

    local west_side = by_id.door_1_14
    assert_equal(west_side ~= nil, true, "Kol should expose the west-side locked door")
    assert_equal(west_side.name, "West Side Door", "Kol west-side door should have a distinct navigation label")
    assert_equal(west_side.x, 1, "Kol west-side door x should match opened-door RAM")
    assert_equal(west_side.y, 14, "Kol west-side door y should match opened-door RAM")
    assert_equal(west_side.interaction_x, 1, "Kol west-side door should route to the public south stand")
    assert_equal(west_side.interaction_y, 15, "Kol west-side door stand should match live open proof")
    assert_equal(west_side.interaction_face_dir, "north", "Kol west-side door should open from the south stand facing north")

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
    assert_equal(fairy_water.interaction_x, 22, "Fairy Water Merchant should route to the public counter stand")
    assert_equal(fairy_water.interaction_y, 4, "Fairy Water Merchant stand should stay on the trigger row")
    assert_equal(fairy_water.interaction_face_dir, "east", "Fairy Water Merchant stand should face east across the counter")
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

function tests.brecconary_fairy_water_moving_rows_use_fixed_public_counter_stand()
    for _, y in ipairs({3, 4, 5}) do
        local env = make_env({npc_count = 1})

        env.set_position(0x08, 22, y)
        env.set_terrain_offset(0x10)
        env.set_npc(0, 0xC0 + 24, y, 0x00) -- Woman 1, Fairy Water merchant
        env.objects.refresh(0x08)

        local fairy_water = nil
        for _, obj in ipairs(env.objects.get_objects()) do
            if obj.name == "Fairy Water Merchant" then
                fairy_water = obj
                break
            end
        end

        assert_equal(fairy_water ~= nil, true, "Fairy Water Merchant should be labeled on row " .. tostring(y))
        assert_equal(fairy_water.service, true, "Fairy Water Merchant should remain a Service on row " .. tostring(y))
        assert_equal(fairy_water.interaction_x, 22, "Fairy Water Merchant should use the fixed public west stand on row " .. tostring(y))
        assert_equal(fairy_water.interaction_y, 4, "Fairy Water Merchant stand should stay on the live-confirmed trigger row")
        assert_equal(fairy_water.interaction_face_dir, "east", "Fairy Water Merchant should face east from the fixed stand")
        assert_equal(fairy_water.target_hold_x, 24, "Fairy Water Merchant should pin the target NPC on the trigger column")
        assert_equal(fairy_water.target_hold_y, 4, "Fairy Water Merchant should pin the target NPC on the trigger row")

        env.restore()
    end
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

function tests.tantegel_throne_room_king_appears_in_services()
    local env = make_env({npc_count = 1})

    env.set_position(0x05, 4, 4)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x80 + 3, 0x03, 0x00) -- King at the throne
    env.objects.refresh(0x05)

    local king = nil
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.name == "King" then
            king = obj
            break
        end
    end

    assert_equal(king ~= nil, true, "Throne Room King should be listed")
    assert_equal(king.service, true, "Throne Room King should appear in Services for saving")
    assert_equal(king.interaction_x, nil, "King should keep ordinary adjacent-NPC routing")

    env.objects.next_filter() -- NPCs
    env.objects.next_filter() -- Services
    local service = env.objects.current_object()
    assert_equal(service ~= nil, true, "Services filter should include the King")
    assert_equal(service.name, "King", "King should be the throne-room service")

    env.restore()
end

function tests.tantegel_throne_room_returned_gwaelin_is_labeled_as_npc()
    local env = make_env({npc_count = 2})

    env.set_position(0x05, 6, 4)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x80 + 3, 0x03, 0x00) -- King at the throne
    env.set_npc(1, 0xC0 + 6, 0x03, 0x00) -- Returned Gwaelin at the live-confirmed throne-room cell
    env.objects.refresh(0x05)

    local princess = nil
    for _, obj in ipairs(env.objects.get_objects()) do
        if obj.name == "Princess Gwaelin" then
            princess = obj
            break
        end
    end

    assert_equal(princess ~= nil, true, "Returned Gwaelin should be labeled in the throne room")
    assert_equal(princess.type, env.objects.TYPE_NPC, "Returned Gwaelin should remain browsable as an NPC")
    assert_equal(princess.service, false, "Returned Gwaelin should not appear in Services")
    assert_equal(princess.x, 6, "Returned Gwaelin x should match the live throne-room object")
    assert_equal(princess.y, 3, "Returned Gwaelin y should match the live throne-room object")

    env.objects.next_filter() -- NPCs
    local npc_princess = env.objects.find_object_by_id(princess.id, {filtered = true})
    assert_equal(npc_princess ~= nil, true, "NPC filter should include returned Gwaelin")

    env.objects.next_filter() -- Services
    local service_names = {}
    for _, obj in ipairs(env.objects.get_objects({filtered = true})) do
        service_names[#service_names + 1] = obj.name
    end
    local service_text = table.concat(service_names, ", ")
    assert_equal(service_text:find("Princess Gwaelin", 1, true), nil, "Services should omit returned Gwaelin")
    assert_equal(service_text:find("King", 1, true) ~= nil, true, "Services should still include the King")

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
    local dialogue_merchant = nil
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
        elseif obj.name == "Merchant 1" then
            dialogue_merchant = obj
        elseif obj.name == "Merchant 2" then
            generic_merchant2 = obj
        elseif obj.name == "Merchant 3" then
            generic_merchant3 = obj
        elseif obj.name == "Merchant 4" then
            generic_merchant4 = obj
        end
    end

    assert_equal(dialogue_merchant ~= nil, true, "Garinham dialogue-only Merchant 1 should stay browsable")
    assert_equal(dialogue_merchant.service, false, "Garinham dialogue-only Merchant 1 should not appear in Services")
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
    assert_equal(service_text:find("Merchant 1", 1, true), nil, "Services should omit Garinham dialogue-only Merchant 1")
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

    env.set_position(0x0B, 23, 9)
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
    assert_equal(magic_key_merchant.interaction_y, 5, "Rimuldar Magic Key Merchant should use the live-confirmed public stand Y")
    assert_equal(magic_key_merchant.interaction_face_dir, "south", "Rimuldar Magic Key Merchant should face south toward the seller")
    assert_equal(magic_key_merchant.blocks_movement, true, "Rimuldar Magic Key Merchant should block movement while still using the public stand")
    assert_equal(dialogue_merchant1 ~= nil, true, "Rimuldar Merchant 1 should stay browsable as an NPC")
    assert_equal(dialogue_merchant1.service, false, "Rimuldar Merchant 1 greeting NPC should not appear in Services")
    assert_equal(weapons_merchant ~= nil, true, "Rimuldar Merchant 2 should be labeled as Weapons Merchant")
    assert_equal(weapons_merchant.service, true, "Rimuldar Weapons Merchant should remain in Services")
    assert_equal(weapons_merchant.x, 23, "Rimuldar Weapons Merchant NPC X should match live NPC RAM")
    assert_equal(weapons_merchant.y, 7, "Rimuldar Weapons Merchant NPC Y should match live NPC RAM")
    assert_equal(weapons_merchant.interaction_x, 23, "Rimuldar Weapons Merchant should use the normal-walk counter stand X")
    assert_equal(weapons_merchant.interaction_y, 9, "Rimuldar Weapons Merchant should use the normal-walk counter stand Y")
    assert_equal(weapons_merchant.interaction_face_dir, "north", "Rimuldar Weapons Merchant should face north across the counter")
    assert_equal(weapons_merchant.interaction_points, nil, "Rimuldar Weapons Merchant should not expose the teleport-only (24,7) stand as a route fallback")
    assert_equal(generic_merchant2, nil, "Rimuldar Merchant 2 should not keep the generic label")
    assert_equal(inn ~= nil, true, "Rimuldar Merchant 3 should be labeled as Inn")
    assert_equal(inn.service, true, "Rimuldar Inn should remain in Services")
    assert_equal(inn.x, 16, "Rimuldar Inn NPC X should match live NPC RAM")
    assert_equal(inn.y, 18, "Rimuldar Inn NPC Y should match live NPC RAM")
    assert_equal(inn.interaction_x, 18, "Rimuldar Inn should use the reachable east-side public stand X")
    assert_equal(inn.interaction_y, 18, "Rimuldar Inn should use the reachable east-side public stand Y")
    assert_equal(inn.interaction_face_dir, "west", "Rimuldar Inn should face west toward the inn keeper")
    assert_equal(type(inn.interaction_points), "table", "Rimuldar Inn should keep both proven interaction stands")
    assert_equal(#inn.interaction_points, 2, "Rimuldar Inn should expose reachable and legacy prompt stands")
    assert_equal(inn.interaction_points[1].x, 18, "Rimuldar Inn primary interaction point should be the reachable stand X")
    assert_equal(inn.interaction_points[1].y, 18, "Rimuldar Inn primary interaction point should be the reachable stand Y")
    assert_equal(inn.interaction_points[1].face_dir, "west", "Rimuldar Inn primary interaction point should face west")
    assert_equal(inn.interaction_points[2].x, 16, "Rimuldar Inn alternate interaction point should preserve old stand X")
    assert_equal(inn.interaction_points[2].y, 17, "Rimuldar Inn alternate interaction point should preserve old stand Y")
    assert_equal(inn.interaction_points[2].face_dir, "south", "Rimuldar Inn alternate interaction point should face south")
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

    local marked_key = env.objects.mark_adjacent_npc_visited(0x0B, 4, 5)
    assert_equal(marked_key.id, magic_key_merchant.id, "Rimuldar key-shop public stand should mark the Magic Key Merchant visited")
    assert_equal(env.objects.is_visited(magic_key_merchant, 0x0B), true, "Rimuldar key-shop visit should persist on the seller")
    local marked = env.objects.mark_adjacent_npc_visited(0x0B, 23, 9)
    assert_equal(marked and marked.id, weapons_merchant.id, "Rimuldar normal-walk counter stand should mark the weapon merchant visited")
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
    assert_equal(outer.interaction_x, 21, "Rimuldar outer door primary route should stand north of the door")
    assert_equal(outer.interaction_y, 20, "Rimuldar outer door primary stand should be reachable from the entrance side")
    assert_equal(outer.interaction_face_dir, "south", "Rimuldar outer door primary stand should face south toward the door")
    assert_equal(#outer.interaction_points, 2, "Rimuldar outer door should keep both reachable-side and inside-side stands")
    assert_equal(outer.interaction_points[1].x, 21, "Rimuldar outer door first alternate stand x should match the public side")
    assert_equal(outer.interaction_points[1].y, 20, "Rimuldar outer door first alternate stand y should match the public side")
    assert_equal(outer.interaction_points[1].face_dir, "south", "Rimuldar outer door first alternate should face south")
    assert_equal(outer.interaction_points[2].x, 21, "Rimuldar outer door second alternate stand x should preserve the inside proof")
    assert_equal(outer.interaction_points[2].y, 22, "Rimuldar outer door second alternate stand y should preserve the inside proof")
    assert_equal(outer.interaction_points[2].face_dir, "north", "Rimuldar outer door second alternate should face north")
    local inner = by_id.door_22_23
    assert_equal(inner ~= nil, true, "Rimuldar Wings chest door should be listed")
    assert_equal(inner.name, "Wings Chest Door", "Rimuldar Wings chest door should have a distinct navigation label")
    assert_equal(inner.x, 22, "Rimuldar Wings chest door x should match opened-door RAM")
    assert_equal(inner.y, 23, "Rimuldar Wings chest door y should match opened-door RAM")
    assert_equal(inner.interaction_x, 21, "Rimuldar Wings chest door primary route should stand west of the door")
    assert_equal(inner.interaction_y, 23, "Rimuldar Wings chest door primary stand should match the approach-side proof")
    assert_equal(inner.interaction_face_dir, "east", "Rimuldar Wings chest door primary stand should face east toward the door")
    assert_equal(#inner.interaction_points, 2, "Rimuldar Wings chest door should keep both approach-side and chest-side stands")
    assert_equal(inner.interaction_points[1].x, 21, "Rimuldar Wings chest door first alternate stand x should match the approach side")
    assert_equal(inner.interaction_points[1].y, 23, "Rimuldar Wings chest door first alternate stand y should match the approach side")
    assert_equal(inner.interaction_points[1].face_dir, "east", "Rimuldar Wings chest door first alternate should face east")
    assert_equal(inner.interaction_points[2].x, 23, "Rimuldar Wings chest door second alternate stand x should preserve the chest-side proof")
    assert_equal(inner.interaction_points[2].y, 23, "Rimuldar Wings chest door second alternate stand y should preserve the chest-side proof")
    assert_equal(inner.interaction_points[2].face_dir, "west", "Rimuldar Wings chest door second alternate should face west")

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

    local doors = env.objects.get_objects({filtered = true})
    assert_equal(#doors, 2, "Tantegel Castle should expose only the two live-confirmed 1F locked doors")
    local west_treasure = nil
    local magic_key_area = nil
    for _, door in ipairs(doors) do
        if door.id == "door_4_13" then
            west_treasure = door
        elseif door.id == "door_18_6" then
            magic_key_area = door
        elseif door.id == "door_10_30" then
            assert_equal(true, false, "door_10_30 should no longer be modeled as a door object")
        end
    end
    assert_equal(west_treasure ~= nil, true, "Tantegel Castle should expose the west treasure-room door")
    assert_equal(west_treasure.name, "Treasure Room Door", "west treasure-room door should have a distinct navigation label")
    assert_equal(west_treasure.x, 4, "west treasure-room door x should match opened-door RAM")
    assert_equal(west_treasure.y, 13, "west treasure-room door y should match opened-door RAM")
    assert_equal(west_treasure.survey_exclude, nil, "west treasure-room door should be available to normal surveys")
    assert_equal(magic_key_area ~= nil, true, "Tantegel Castle should expose the north magic-key-area door")
    assert_equal(magic_key_area.name, "Magic Key Area Door", "north magic-key-area door should have a distinct navigation label")
    assert_equal(magic_key_area.x, 18, "north magic-key-area door x should match opened-door RAM")
    assert_equal(magic_key_area.y, 6, "north magic-key-area door y should match opened-door RAM")
    assert_equal(magic_key_area.survey_exclude, nil, "north magic-key-area door should be available to normal surveys")

    env.restore()
end

function tests.tantegel_route_false_npc_cell_does_not_block_movement()
    local env = make_env({npc_count = 1})

    env.set_position(0x04, 26, 14)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x20 + 26, 0x0F, 0x00) -- Guard at live-verified false blocker (26,15)
    env.objects.refresh(0x04)

    local guard = env.objects.find_object_by_id("npc_0")
    assert_equal(guard ~= nil, true, "Tantegel guard object should still be browsable")
    assert_equal(guard.blocks_movement, false, "Tantegel (26,15) guard should not block the Sun Shrine route after live movement proof")

    local blocking_cells = {}
    for _, pos in ipairs(env.objects.get_blocking_positions()) do
        blocking_cells[pos.x .. "," .. pos.y] = true
    end
    assert_equal(blocking_cells["26,15"], nil, "Tantegel (26,15) should not be reported as an NPC blocker")

    env.restore()
end

function tests.garinham_route_false_old_man_cell_does_not_block_movement()
    local env = make_env({npc_count = 1})

    env.set_position(0x09, 13, 1)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0xA0 + 14, 0x40 + 1, 0x00) -- Old Man at live-verified false blocker (14,1)
    env.objects.refresh(0x09)

    local old_man = env.objects.find_object_by_id("npc_0")
    assert_equal(old_man ~= nil, true, "Garinham old man object should still be browsable")
    assert_equal(old_man.blocks_movement, false, "Garinham (14,1) old man should not block the hidden grave route after live movement proof")

    local blocking_cells = {}
    for _, pos in ipairs(env.objects.get_blocking_positions()) do
        blocking_cells[pos.x .. "," .. pos.y] = true
    end
    assert_equal(blocking_cells["14,1"], nil, "Garinham (14,1) should not be reported as an NPC blocker")

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
        elseif door.id == "door_5_23" then
            inn_west = door
        end
    end

    assert_equal(northeast ~= nil, true, "Brecconary should expose the northeast hidden door")
    assert_equal(northeast.name, "Northeast Door", "northeast door should have a distinct navigation label")
    assert_equal(northeast.x, 21, "northeast door x should match the topology frontier")
    assert_equal(northeast.y, 6, "northeast door y should match the topology frontier")

    assert_equal(inn_west ~= nil, true, "Brecconary should expose the inn west-room door")
    assert_equal(inn_west.name, "Inn West Room Door", "inn west-room door should have a distinct navigation label")
    assert_equal(inn_west.x, 5, "inn west-room door x should match live opened-door RAM")
    assert_equal(inn_west.y, 23, "inn west-room door y should match live opened-door RAM")

    env.restore()
end


function tests.cantlin_exposes_confirmed_locked_doors()
    local env = make_env()

    env.set_position(0x0A, 25, 9)
    env.set_terrain_offset(0x10)
    env.set_npc(0, 0x00, 0x00)
    env.objects.refresh(0x0A)

    env.objects.set_filter(env.objects.FILTER_DOOR)

    local doors = env.objects.get_objects({filtered = true})
    local by_id = {}
    for _, door in ipairs(doors) do
        if door.id == "door_25_12" then
            assert_equal(true, false, "Cantlin should not expose the disproved east facade door candidate")
        end
        by_id[door.id] = door
    end

    local eastern = by_id.door_26_9
    assert_equal(eastern ~= nil, true, "Cantlin should expose the live-confirmed eastern building door")
    assert_equal(eastern.name, "Eastern Building Door", "Cantlin eastern door should have a useful navigation label")
    assert_equal(eastern.x, 26, "Cantlin eastern door x should match opened-door RAM")
    assert_equal(eastern.y, 9, "Cantlin eastern door y should match opened-door RAM")
    assert_equal(eastern.interaction_x, 25, "Cantlin eastern door should route to the public west stand")
    assert_equal(eastern.interaction_y, 9, "Cantlin eastern door stand should match live verifier proof")
    assert_equal(eastern.interaction_face_dir, "east", "Cantlin eastern door should open from the west stand facing east")

    local central_right = by_id.door_15_25
    assert_equal(central_right ~= nil, true, "Cantlin should expose the live-confirmed central right door")
    assert_equal(central_right.name, "Central Right Door", "Cantlin central right door should have a useful navigation label")
    assert_equal(central_right.x, 15, "Cantlin central right door x should match opened-door RAM")
    assert_equal(central_right.y, 25, "Cantlin central right door y should match opened-door RAM")
    assert_equal(central_right.interaction_x, 15, "Cantlin central right door should route to the public north stand")
    assert_equal(central_right.interaction_y, 24, "Cantlin central right door stand should match live verifier proof")
    assert_equal(central_right.interaction_face_dir, "south", "Cantlin central right door should open from the north stand facing south")

    local central_left = by_id.door_14_25
    assert_equal(central_left ~= nil, true, "Cantlin should expose the live-confirmed central left door")
    assert_equal(central_left.name, "Central Left Door", "Cantlin central left door should have a useful navigation label")
    assert_equal(central_left.x, 14, "Cantlin central left door x should match opened-door RAM")
    assert_equal(central_left.y, 25, "Cantlin central left door y should match opened-door RAM")
    assert_equal(central_left.interaction_x, 14, "Cantlin central left door should route to the public north stand")
    assert_equal(central_left.interaction_y, 24, "Cantlin central left door stand should match live verifier proof")
    assert_equal(central_left.interaction_face_dir, "south", "Cantlin central left door should open from the north stand facing south")

    local western_north = by_id.door_4_21
    assert_equal(western_north ~= nil, true, "Cantlin should expose the live-confirmed western shop north door")
    assert_equal(western_north.name, "Western Shop North Door", "Cantlin western shop north door should have a useful navigation label")
    assert_equal(western_north.x, 4, "Cantlin western shop north door x should match opened-door RAM")
    assert_equal(western_north.y, 21, "Cantlin western shop north door y should match opened-door RAM")
    assert_equal(western_north.interaction_x, 4, "Cantlin western shop north door should route to the public north stand")
    assert_equal(western_north.interaction_y, 20, "Cantlin western shop north door stand should match live verifier proof")
    assert_equal(western_north.interaction_face_dir, "south", "Cantlin western shop north door should open from the north stand facing south")

    local western_east = by_id.door_8_25
    assert_equal(western_east ~= nil, true, "Cantlin should expose the live-confirmed western shop east door")
    assert_equal(western_east.name, "Western Shop East Door", "Cantlin western shop east door should have a useful navigation label")
    assert_equal(western_east.x, 8, "Cantlin western shop east door x should match opened-door RAM")
    assert_equal(western_east.y, 25, "Cantlin western shop east door y should match opened-door RAM")
    assert_equal(western_east.interaction_x, 7, "Cantlin western shop east door should route to the public west stand")
    assert_equal(western_east.interaction_y, 25, "Cantlin western shop east door stand should match live verifier proof")
    assert_equal(western_east.interaction_face_dir, "east", "Cantlin western shop east door should open from the west stand facing east")

    env.restore()
end

function tests.garinham_does_not_expose_disproved_east_locked_door()
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

    local doors = env.objects.get_objects({filtered = true})
    local grave_route = nil
    local inner_door = nil
    for _, door in ipairs(doors) do
        if door.id == "door_19_16" then
            assert_equal(true, false, "Garinham should not expose the disproved east locked door")
        elseif door.id == "door_18_9" then
            assert_equal(true, false, "Garinham should not expose the old grave-route door guess")
        elseif door.id == "door_17_10" then
            grave_route = door
        elseif door.id == "door_4_6" then
            inner_door = door
        end
    end

    assert_equal(#doors, 2, "Garinham should expose the confirmed grave-route and inner locked-building doors")
    assert_equal(grave_route ~= nil, true, "Garinham should expose the grey-building grave-route door")
    assert_equal(grave_route.name, "Grave Route Door", "Garinham grave-route door should have a distinct navigation label")
    assert_equal(grave_route.x, 17, "Garinham grave-route door x should match the confirmed door-RAM coordinate")
    assert_equal(grave_route.y, 10, "Garinham grave-route door y should match the confirmed door-RAM coordinate")
    assert_equal(grave_route.interaction_x, 17, "Garinham grave-route door should route to the north-side stand")
    assert_equal(grave_route.interaction_y, 9, "Garinham grave-route door stand should match the user's OPEN position")
    assert_equal(grave_route.interaction_face_dir, "south", "Garinham grave-route door should face south to open")
    assert_equal(type(grave_route.interaction_points), "table", "Garinham grave-route door should expose alternate interaction points")
    assert_equal(#grave_route.interaction_points, 2, "Garinham grave-route door should expose both proven interaction stands")
    assert_equal(grave_route.interaction_points[1].x, 17, "Garinham grave-route primary interaction point should preserve north stand X")
    assert_equal(grave_route.interaction_points[1].y, 9, "Garinham grave-route primary interaction point should preserve north stand Y")
    assert_equal(grave_route.interaction_points[1].face_dir, "south", "Garinham grave-route primary interaction point should face south")
    assert_equal(grave_route.interaction_points[2].x, 17, "Garinham grave-route alternate interaction point should expose public south stand X")
    assert_equal(grave_route.interaction_points[2].y, 11, "Garinham grave-route alternate interaction point should expose public south stand Y")
    assert_equal(grave_route.interaction_points[2].face_dir, "north", "Garinham grave-route alternate interaction point should face north")
    assert_equal(inner_door ~= nil, true, "Garinham should expose the confirmed inner locked-building door")
    assert_equal(inner_door.name, "Locked Building Door", "Garinham inner door should have a distinct navigation label")
    assert_equal(inner_door.x, 4, "Garinham inner door x should match opened-door RAM proof")
    assert_equal(inner_door.y, 6, "Garinham inner door y should match opened-door RAM proof")
    assert_equal(inner_door.interaction_x, 4, "Garinham inner door should route to the south-side stand")
    assert_equal(inner_door.interaction_y, 7, "Garinham inner door stand should match the successful OPEN/passage side")
    assert_equal(inner_door.interaction_face_dir, "north", "Garinham inner door should face north to open")

    env.restore()
end

function tests.garins_grave_b1_exposes_confirmed_southeast_b2_door()
    local env = make_env()

    env.set_position(0x18, 17, 18)
    env.set_terrain_offset(0x20)
    env.set_npc(0, 0x00, 0x00)
    env.objects.refresh(0x18)

    env.objects.next_filter() -- NPCs
    env.objects.next_filter() -- Exits
    env.objects.next_filter() -- Chests
    env.objects.next_filter() -- Stairs
    env.objects.next_filter() -- Doors

    local doors = env.objects.get_objects({filtered = true})
    local b2_door = nil
    for _, door in ipairs(doors) do
        if door.id == "door_17_17" then
            b2_door = door
        end
    end

    assert_equal(#doors, 1, "Garin's Grave B1 should expose only the confirmed southeast B2 door")
    assert_equal(b2_door ~= nil, true, "Garin's Grave B1 should expose the confirmed southeast B2 door")
    assert_equal(b2_door.name, "B2 Door", "Garin's Grave B1 southeast door should have a distinct navigation label")
    assert_equal(b2_door.x, 17, "Garin's Grave B1 southeast door x should match opened-door RAM proof")
    assert_equal(b2_door.y, 17, "Garin's Grave B1 southeast door y should match opened-door RAM proof")
    assert_equal(b2_door.interaction_x, 17, "Garin's Grave B1 southeast door should route to the south stand")
    assert_equal(b2_door.interaction_y, 18, "Garin's Grave B1 southeast door stand should match the successful OPEN position")
    assert_equal(b2_door.interaction_face_dir, "north", "Garin's Grave B1 southeast door should face north to open")
    assert_equal(#b2_door.interaction_points, 2, "Garin's Grave B1 B2 door should keep both proven interaction stands")
    assert_equal(b2_door.interaction_points[1].x, 17, "B2 door primary interaction point should preserve south stand X")
    assert_equal(b2_door.interaction_points[1].y, 18, "B2 door primary interaction point should preserve south stand Y")
    assert_equal(b2_door.interaction_points[1].face_dir, "north", "B2 door primary interaction point should face north")
    assert_equal(b2_door.interaction_points[2].x, 17, "B2 door alternate interaction point should expose north stand X")
    assert_equal(b2_door.interaction_points[2].y, 16, "B2 door alternate interaction point should expose north stand Y")
    assert_equal(b2_door.interaction_points[2].face_dir, "south", "B2 door alternate interaction point should face south")

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

function tests.dungeon_object_browsing_only_exposes_the_visible_square()
    local env = make_env({npc_count = 0})

    env.set_position(0x1C, 0, 0)
    env.set_terrain_offset(0x20)
    env.objects.refresh(0x1C)
    env.objects.set_visibility_context({
        map_id = 0x1C,
        terrain_offset = 0x20,
        x = 0,
        y = 0,
        light_radius = 1,
    })

    local visible = env.objects.get_objects({filtered = true})
    assert_equal(#visible, 1, "unlit Erdrick B1 should expose only the stair under the hero")
    assert_equal(visible[1].id, "exit_0_0", "the current-tile exit should remain browsable")
    assert_equal(
        env.objects.find_object_by_id("stair_9_9", {filtered = true}),
        nil,
        "far B2 stairs should stay hidden from ordinary browsing")
    assert_equal(
        env.objects.find_object_by_id("stair_9_9") ~= nil,
        true,
        "developer-facing full object data should remain intact")

    env.restore()
end

function tests.dungeon_object_browsing_can_be_unrestricted_by_config()
    local env = make_env({
        npc_count = 0,
        darkness_navigation_limits = "false",
    })

    env.set_position(0x1C, 0, 0)
    env.set_terrain_offset(0x20)
    env.objects.refresh(0x1C)
    env.objects.set_visibility_context({
        map_id = 0x1C,
        terrain_offset = 0x20,
        x = 0,
        y = 0,
        light_radius = 1,
    })

    assert_equal(
        env.objects.find_object_by_id("stair_9_9", {filtered = true}) ~= nil,
        true,
        "config opt-out should restore full decoded object browsing")

    env.restore()
end

function tests.dungeon_visibility_updates_as_the_hero_moves_or_light_changes()
    local env = make_env({npc_count = 0})

    env.set_position(0x1C, 0, 0)
    env.set_terrain_offset(0x20)
    env.objects.refresh(0x1C)
    env.objects.set_visibility_context({
        map_id = 0x1C,
        terrain_offset = 0x20,
        x = 8,
        y = 8,
        light_radius = 3,
    })

    assert_equal(
        env.objects.find_object_by_id("stair_9_9", {filtered = true}) ~= nil,
        true,
        "a stair one tile diagonally away should be visible in a 3 by 3 light window")
    assert_equal(
        env.objects.find_object_by_id("exit_0_0", {filtered = true}),
        nil,
        "the distant entrance should remain hidden")

    env.objects.set_visibility_context({
        map_id = 0x1C,
        terrain_offset = 0x20,
        x = 7,
        y = 8,
        light_radius = 1,
    })
    assert_equal(env.objects.get_count(), 0, "moving away after the light fades should hide both stairs")

    env.objects.set_visibility_context({
        map_id = 0x1C,
        terrain_offset = 0x10,
        x = 7,
        y = 8,
        light_radius = 1,
    })
    assert_equal(env.objects.get_count() >= 2, true, "lit terrain should restore the complete object browser")

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
