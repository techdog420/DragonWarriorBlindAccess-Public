-- test_game_snapshot.lua
-- Regression tests for effective coordinate selection in game_snapshot.

local original_preload = {}
local original_loaded = {}
local original_memory = _G.memory

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

local function make_env()
    local module_names = {
        "addresses",
        "maps",
        "game_snapshot",
    }

    for _, name in ipairs(module_names) do
        save_module(name)
        package.loaded[name] = nil
    end

    local ram = {
        [0x0045] = 0x01, -- map id: world map
        [0x003A] = 44,   -- player x
        [0x003B] = 35,   -- player y
        [0x0042] = 44,   -- dedicated overworld x byte
        [0x003E] = 4,    -- stale dedicated overworld y byte
        [0x0016] = 0x00, -- terrain: overworld
    }

    _G.memory = {
        readbyte = function(address)
            return ram[address] or 0
        end,
    }

    package.preload["addresses"] = function()
        return {
            MAP_ID = 0x0045,
            PLAYER_X = 0x003A,
            PLAYER_Y = 0x003B,
            OVERWORLD_X = 0x0042,
            OVERWORLD_Y = 0x003E,
            TERRAIN_OFFSET = 0x0016,
            CURRENT_HP = 0x00C5,
            MAX_HP = 0x00CA,
            CURRENT_MP = 0x00C6,
            MAX_MP = 0x00CB,
            LEVEL = 0x00C7,
            STRENGTH = 0x00C8,
            AGILITY = 0x00C9,
            ATTACK = 0x00CC,
            DEFENSE = 0x00CD,
            EXPERIENCE_LO = 0x00BA,
            EXPERIENCE_HI = 0x00BB,
            GOLD_LO = 0x00BC,
            GOLD_HI = 0x00BD,
            EQUIPMENT = 0x00BE,
            KEYS = 0x00BF,
            HERBS = 0x00C0,
            ITEMS_START = 0x00C1,
            SPELLS = 0x00CE,
            FLAGS_CF = 0x00CF,
            COMBAT_FLAGS = 0x00DF,
            QUEST_FLAGS = 0x00E4,
            ENEMY_TYPE = 0x00E0,
            ENEMY_HP = 0x00E2,
            MENU_CURSOR_X = 0x00D8,
            MENU_CURSOR_Y = 0x00D9,
            TILE_TYPE = 0x0015,
            SCROLL_Y = 0x0007,
            LIGHT_RADIUS = 0x00D0,
            RADIANT_TIMER = 0x00DA,
            REPEL_TIMER = 0x00DB,
            BUTTONS_PRESSED = 0x0047,
        }
    end

    package.preload["maps"] = function()
        return {
            is_overworld = function(map_id, terrain_offset)
                return map_id == 0x01 or terrain_offset == 0x00
            end,
        }
    end

    local snapshot = require "game_snapshot"
    return {
        snapshot = snapshot,
        restore = function()
            restore_modules(module_names)
            _G.memory = original_memory
        end,
    }
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local tests = {}

function tests.overworld_effective_position_uses_player_bytes()
    local env = make_env()

    env.snapshot.update()

    assert_equal(env.snapshot.is_overworld, true, "snapshot should detect overworld state")
    assert_equal(env.snapshot.overworld_y, 4, "raw dedicated overworld Y byte should remain available for diagnostics")
    assert_equal(env.snapshot.x, 44, "effective overworld X should use player bytes")
    assert_equal(env.snapshot.y, 35, "effective overworld Y should ignore stale dedicated overworld bytes")

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
