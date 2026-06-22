-- test_teleport_state.lua
-- Focused tests for RAM writes used by teleport_to.

local original_loaded = package.loaded["teleport_state"]
local original_preload_addresses = package.preload["addresses"]
local original_loaded_addresses = package.loaded["addresses"]
local original_memory = _G.memory

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local function make_env(initial)
    local bytes = {}
    for address, value in pairs(initial or {}) do
        bytes[address] = value
    end

    package.loaded["teleport_state"] = nil
    package.loaded["addresses"] = nil
    package.preload["addresses"] = function()
        return {
            PLAYER_X = 0x003A,
            PLAYER_Y = 0x003B,
            OVERWORLD_Y = 0x003E,
            OVERWORLD_X = 0x0042,
            SCROLL_X = 0x0005,
            SCROLL_Y = 0x0007,
            PLAYER_SPRITE_X = 0x0090,
            PLAYER_SPRITE_Y = 0x0092,
        }
    end

    _G.memory = {
        readbyte = function(address)
            return bytes[address] or 0
        end,
        writebyte = function(address, value)
            bytes[address] = value
        end,
    }

    return {
        bytes = bytes,
        teleport_state = require "teleport_state",
        restore = function()
            package.loaded["teleport_state"] = original_loaded
            package.preload["addresses"] = original_preload_addresses
            package.loaded["addresses"] = original_loaded_addresses
            _G.memory = original_memory
        end,
    }
end

local tests = {}

function tests.apply_landing_translates_indoor_screen_state_by_tile_delta()
    local env = make_env({
        [0x003A] = 1,
        [0x003B] = 7,
        [0x0005] = 0xB0,
        [0x0007] = 0xE0,
        [0x0090] = 0xB0,
        [0x0092] = 0xD0,
    })

    local result = env.teleport_state.apply_landing(4, 7, {is_overworld = false})

    assert_equal(result.dx, 3, "teleport should report the X tile delta")
    assert_equal(result.dy, 0, "teleport should report the Y tile delta")
    assert_equal(result.screen_synced, true, "indoor teleport should synchronize screen-relative RAM")
    assert_equal(env.bytes[0x003A], 4, "teleport should write PLAYER_X")
    assert_equal(env.bytes[0x003B], 7, "teleport should write PLAYER_Y")
    assert_equal(env.bytes[0x0005], 0xE0, "teleport should translate scroll X by 16 pixels per tile")
    assert_equal(env.bytes[0x0090], 0xE0, "teleport should translate player sprite X by 16 pixels per tile")
    assert_equal(env.bytes[0x0007], 0xE0, "unchanged Y should leave scroll Y alone")
    assert_equal(env.bytes[0x0092], 0xD0, "unchanged Y should leave player sprite Y alone")

    env.restore()
end

function tests.apply_landing_updates_overworld_shadow_coordinates()
    local env = make_env({
        [0x003A] = 2,
        [0x003B] = 2,
        [0x003E] = 2,
        [0x0042] = 2,
        [0x0005] = 0x40,
        [0x0090] = 0x40,
    })

    local result = env.teleport_state.apply_landing(104, 49, {is_overworld = true})

    assert_equal(result.screen_synced, false, "overworld teleport should not translate screen bytes by large map deltas")
    assert_equal(env.bytes[0x003A], 104, "overworld teleport should write PLAYER_X")
    assert_equal(env.bytes[0x003B], 49, "overworld teleport should write PLAYER_Y")
    assert_equal(env.bytes[0x0042], 104, "overworld teleport should write OVERWORLD_X")
    assert_equal(env.bytes[0x003E], 49, "overworld teleport should write OVERWORLD_Y")
    assert_equal(env.bytes[0x0005], 0x40, "overworld teleport should leave scroll X unchanged")
    assert_equal(env.bytes[0x0090], 0x40, "overworld teleport should leave player sprite X unchanged")

    env.restore()
end

local count = 0
for name, fn in pairs(tests) do
    fn()
    count = count + 1
end

print(string.format("test_teleport_state.lua: %d tests passed", count))
