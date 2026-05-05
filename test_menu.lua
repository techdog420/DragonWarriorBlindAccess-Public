-- test_menu.lua
-- Regression tests for command/yes-no menu tracking.

local original_preload = {}
local original_loaded = {}
local original_ppu = _G.ppu

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

local function make_env(initial_bytes)
    local module_names = {
        "game_snapshot",
        "menu",
    }

    for _, name in ipairs(module_names) do
        save_module(name)
        package.loaded[name] = nil
    end

    local bytes = initial_bytes or {}
    _G.ppu = {
        readbyte = function(address)
            return bytes[address] or 0x9F
        end,
    }

    package.preload["game_snapshot"] = function()
        return {
            cursor_x = 0,
            cursor_y = 0,
        }
    end

    local menu = require "menu"
    return {
        menu = menu,
        set_bytes = function(next_bytes)
            bytes = next_bytes or {}
        end,
        restore = function()
            restore_modules(module_names)
            _G.ppu = original_ppu
        end,
    }
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local tests = {}

local COMMAND_BYTES = {0x26, 0x32, 0x30, 0x30, 0x24, 0x31, 0x27}

local function write_sequence(bytes, base, row, col, sequence)
    for i, value in ipairs(sequence) do
        bytes[base + row * 32 + col + i - 1] = value
    end
end

function tests.command_menu_detects_nt1_to_nt0_wrap()
    local bytes = {}
    write_sequence(bytes, 0x2400, 4, 29, {COMMAND_BYTES[1], COMMAND_BYTES[2], COMMAND_BYTES[3]})
    write_sequence(bytes, 0x2000, 4, 0, {COMMAND_BYTES[4], COMMAND_BYTES[5], COMMAND_BYTES[6], COMMAND_BYTES[7]})

    local env = make_env(bytes)
    assert_equal(env.menu.is_command_menu_open(), true, "command menu scanner should detect NT1-to-NT0 wrapped COMMAND header")
    env.restore()
end

function tests.yesno_detects_nt1_to_nt0_wrap()
    local bytes = {}
    write_sequence(bytes, 0x2400, 19, 30, {0x42, 0x3C}) -- cursor, Y
    write_sequence(bytes, 0x2000, 19, 0, {0x28, 0x36, 0x9F}) -- E, S, boundary

    local env = make_env(bytes)
    local appeared = env.menu.check_yesno_changes()
    assert_equal(appeared.active, true, "wrapped yes/no prompt should become active")
    assert_equal(appeared.selection, "YES", "wrapped yes/no prompt should select YES")
    env.restore()
end

function tests.yesno_hold_timer_accepts_frame_delta()
    local bytes = {
        [0x2000] = 0x42, -- cursor
        [0x2001] = 0x3C, -- Y
        [0x2002] = 0x28, -- E
        [0x2003] = 0x36, -- S
        [0x2004] = 0x9F,
    }
    local env = make_env(bytes)

    local appeared = env.menu.check_yesno_changes()
    assert_equal(appeared.active, true, "prompt should become active")
    assert_equal(appeared.selection, "YES", "prompt should select YES")

    env.set_bytes({})
    local dismissed = env.menu.check_yesno_changes(30)
    assert_equal(dismissed.active, false, "frame delta should expire the hold timer")
    assert_equal(dismissed.just_dismissed, true, "expired prompt should report dismissal")

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
