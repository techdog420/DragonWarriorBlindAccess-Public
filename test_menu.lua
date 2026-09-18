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

function tests.rimuldar_person4_north_edge_talk_sequence()
    local env = make_env()
    local base = {
        is_interior = true,
        map_id = 0x0B,
        player_x = 27,
        player_y = 1, -- Person 4 is talked to from Rimuldar (27,1).
        a_just = true,
        menu_opened = false,
        cursor_moved = false,
    }
    local candidate = {
        frame = 223,
        map_id = base.map_id,
        player_x = base.player_x,
        player_y = base.player_y,
    }

    assert_equal(env.menu.is_north_edge_talk_menu_start({
        is_interior = base.is_interior,
        player_y = base.player_y,
        a_just = base.a_just,
        menu_opened = base.menu_opened,
        cursor_moved = base.cursor_moved,
        raw_menu_open = false,
        cursor_visible = false,
    }), true, "first A should remember the north-edge TALK menu attempt")

    assert_equal(env.menu.is_north_edge_talk_menu_confirmation({
        is_interior = base.is_interior,
        frame = 305,
        map_id = base.map_id,
        player_x = base.player_x,
        player_y = base.player_y,
        north_edge_talk_candidate = candidate,
        a_just = base.a_just,
        menu_opened = base.menu_opened,
        cursor_moved = base.cursor_moved,
        raw_menu_open = false,
        cursor_visible = false,
        cursor_x = 0,
        cursor_y = 0,
    }), true, "live second A should confirm TALK even when north-edge menu graphics stay hidden")

    assert_equal(env.menu.is_north_edge_talk_menu_confirmation({
        is_interior = base.is_interior,
        frame = 305,
        map_id = base.map_id,
        player_x = base.player_x,
        player_y = base.player_y,
        north_edge_talk_candidate = candidate,
        a_just = base.a_just,
        menu_opened = base.menu_opened,
        cursor_moved = base.cursor_moved,
        raw_menu_open = true,
        cursor_visible = true,
        cursor_x = 0,
        cursor_y = 0,
    }), true, "visible default TALK cursor should remain a valid confirmation")

    assert_equal(env.menu.is_north_edge_talk_menu_confirmation({
        is_interior = base.is_interior,
        player_y = base.player_y,
        north_edge_talk_candidate = false,
        a_just = base.a_just,
        menu_opened = base.menu_opened,
        cursor_moved = base.cursor_moved,
        raw_menu_open = true,
        cursor_visible = true,
        cursor_x = 0,
        cursor_y = 0,
    }), false, "stale north-edge command residue must not arm a visit without the first A")

    assert_equal(env.menu.is_north_edge_talk_candidate_valid({
        is_interior = base.is_interior,
        frame = 944,
        map_id = base.map_id,
        player_x = base.player_x,
        player_y = base.player_y,
        north_edge_talk_candidate = candidate,
    }), false, "candidate should expire after the bounded confirmation window")

    assert_equal(env.menu.is_north_edge_talk_candidate_valid({
        is_interior = base.is_interior,
        frame = 305,
        map_id = base.map_id,
        player_x = 26,
        player_y = base.player_y,
        north_edge_talk_candidate = candidate,
    }), false, "moving off the interaction cell should cancel the candidate")

    assert_equal(env.menu.is_north_edge_talk_candidate_valid({
        is_interior = base.is_interior,
        frame = 305,
        map_id = base.map_id,
        player_x = base.player_x,
        player_y = base.player_y,
        north_edge_talk_candidate = candidate,
        cancel_input = true,
    }), false, "directional or B input should cancel the default-TALK candidate")

    assert_equal(env.menu.is_north_edge_talk_menu_start({
        is_interior = true,
        player_y = 2,
        a_just = true,
        menu_opened = false,
        cursor_moved = false,
        raw_menu_open = false,
        cursor_visible = false,
    }), false, "the fallback must remain limited to the guarded north edge")

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
