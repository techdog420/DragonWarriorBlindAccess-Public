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
            MAP_ID = 0x0045,
            PLAYER_X = 0x003A,
            PLAYER_Y = 0x003B,
            MOVEMENT_STATE = 0x003C,
            MOVEMENT_SUBPIXEL = 0x003D,
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
        set_byte = function(address, value)
            bytes[address] = value
        end,
        restore = function()
            package.loaded["teleport_state"] = original_loaded
            package.preload["addresses"] = original_preload_addresses
            package.loaded["addresses"] = original_loaded_addresses
            _G.memory = original_memory
        end,
    }
end

local tests = {}

function tests.movement_guard_accepts_stable_nonzero_field_state()
    local env = make_env({
        [0x0045] = 0x01,
        [0x003A] = 108,
        [0x003B] = 109,
        [0x003C] = 0x7F,
        [0x003D] = 0x90,
        [0x003E] = 109,
        [0x0042] = 108,
        [0x0005] = 0x00,
        [0x0007] = 0x00,
        [0x0090] = 0xC0,
        [0x0092] = 0xD0,
    })

    for _ = 1, 5 do
        env.teleport_state.observe_movement_state()
    end
    local settled_before, _, _, stable_before =
        env.teleport_state.is_movement_settled(6)
    assert_equal(settled_before, false,
        "teleport should wait for the full stability window")
    assert_equal(stable_before, 5,
        "movement guard should report the observed stable-frame count")

    env.teleport_state.observe_movement_state()
    local settled, movement_state, movement_subpixel, stable_frames =
        env.teleport_state.is_movement_settled(6)

    assert_equal(settled, true,
        "teleport should accept a stable field state even when movement-adjacent bytes are nonzero")
    assert_equal(movement_state, 0x7F,
        "movement guard should report the movement-state byte")
    assert_equal(movement_subpixel, 0x90,
        "movement guard should report the subpixel byte")
    assert_equal(stable_frames, 6,
        "movement guard should retain the full stability count")

    env.restore()
end

function tests.movement_guard_restarts_window_when_transition_state_changes()
    local env = make_env({
        [0x0045] = 0x01,
        [0x003A] = 108,
        [0x003B] = 109,
        [0x003C] = 0x7F,
        [0x003D] = 0x90,
        [0x003E] = 109,
        [0x0042] = 108,
        [0x0005] = 0x00,
        [0x0007] = 0x00,
        [0x0090] = 0xC0,
        [0x0092] = 0xD0,
    })

    for _ = 1, 6 do
        env.teleport_state.observe_movement_state()
    end
    assert_equal(env.teleport_state.is_movement_settled(6), true,
        "baseline should become teleport-safe after six stable frames")

    env.set_byte(0x0005, 0x10)
    env.teleport_state.observe_movement_state()
    local settled_after_scroll, _, _, stable_after_scroll =
        env.teleport_state.is_movement_settled(6)
    assert_equal(settled_after_scroll, false,
        "a changed scroll byte should mark the movement transition unsettled")
    assert_equal(stable_after_scroll, 1,
        "a changed transition signature should restart the stability window")

    for _ = 1, 5 do
        env.teleport_state.observe_movement_state()
    end
    assert_equal(env.teleport_state.is_movement_settled(6), true,
        "unchanged state should become safe again after the complete window")

    env.set_byte(0x003A, 109)
    env.teleport_state.observe_movement_state()
    local settled_after_tile, _, _, stable_after_tile =
        env.teleport_state.is_movement_settled(6)
    assert_equal(settled_after_tile, false,
        "a changed player tile should restart the stability window")
    assert_equal(stable_after_tile, 1,
        "tile movement should leave only one stable observation")

    env.restore()
end

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
