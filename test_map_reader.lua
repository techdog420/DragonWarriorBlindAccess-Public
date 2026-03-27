-- test_map_reader.lua
-- Focused regression tests for permanent walkability overrides.

local original_preload = {}
local original_loaded = {}

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

local function make_env(opts)
    opts = opts or {}
    local module_names = {
        "addresses",
        "map_reader",
    }
    for _, name in ipairs(module_names) do
        save_module(name)
        package.loaded[name] = nil
    end

    package.preload["addresses"] = function()
        return {
            ROM_MAP_META_START = 0,
            ROM_MAP_META_SIZE = 5,
            DOOR_ARRAY_MAX = 0,
            DOOR_X_POS_START = 0,
            DOOR_Y_POS_START = 0,
            DOOR_ARRAY_STRIDE = 0,
            TERRAIN_OFFSET = 0,
        }
    end

    local rom_bytes = opts.rom_bytes or {}
    local memory_bytes = opts.memory_bytes or {}

    _G.rom = _G.rom or {}
    _G.memory = _G.memory or {}
    _G.rom.readbyte = function(address)
        return rom_bytes[address] or 0
    end
    _G.memory.readbyte = function(address)
        return memory_bytes[address] or 0
    end
    _G.AND = _G.AND or function(a, b)
        local result = 0
        local bit = 1
        while a > 0 and b > 0 do
            local a_bit = a % 2
            local b_bit = b % 2
            if a_bit == 1 and b_bit == 1 then
                result = result + bit
            end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            bit = bit * 2
        end
        return result
    end

    local map_reader = require "map_reader"

    return {
        map_reader = map_reader,
        restore = function()
            restore_modules(module_names)
        end,
    }
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local tests = {}

function tests.throne_room_keeps_east_descent_open()
    local env = make_env()

    assert_equal(
        env.map_reader.is_permanently_blocked_override(0x05, 7, 2),
        false,
        "throne room east-side descent at (7,2) should remain open"
    )

    env.restore()
end

function tests.throne_room_trapped_pocket_stays_blocked()
    local env = make_env()

    assert_equal(env.map_reader.is_permanently_blocked_override(0x05, 2, 3), true, "(2,3) should stay blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x05, 4, 3), true, "(4,3) should stay blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x05, 3, 4), true, "(3,4) should stay blocked")

    env.restore()
end

function tests.metadata_width_height_are_inclusive_coordinates()
    local env = make_env({
        rom_bytes = {
            [0] = 0x00,
            [1] = 0x80,
            [2] = 29,
            [3] = 29,
            [4] = 0,
        },
    })

    local meta = env.map_reader.get_metadata(0)
    assert_equal(meta.width, 30, "map metadata width should include the max X coordinate")
    assert_equal(meta.height, 30, "map metadata height should include the max Y coordinate")

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
