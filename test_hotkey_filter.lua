-- test_hotkey_filter.lua
-- Regression tests for BizHawk keyboard hotkey filtering.

local original_loaded = package.loaded["hotkey_filter"]
package.loaded["hotkey_filter"] = nil

local hotkey_filter = require "hotkey_filter"

local function make_config(values)
    values = values or {}
    return {
        get = function(key)
            return values[key]
        end,
    }
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local tests = {}

function tests.default_bizhawk_filter_allows_object_navigation_keys()
    local config = make_config({
        enable_bizhawk_keyboard_hotkeys = "false",
        enable_bizhawk_diagnostic_hotkeys = "false",
        key_position = "Shift+P",
        key_hp = "Shift+H",
        key_level = "Shift+I",
        key_gold = "Shift+G",
        key_experience = "Shift+E",
        key_stats = "Shift+R",
        key_screen_text = "Shift+T",
        key_object_prev = "J",
        key_object_current = "K",
        key_object_next = "L",
        key_pathfind = "O",
        key_auto_walk = "U",
        key_filter = "Q",
        key_filter_prev = "Shift+J",
        key_filter_all = "Shift+K",
        key_filter_next = "Shift+L",
        key_pathability_filter = "Shift+O",
        key_mark_visited = "Shift+V",
        key_teleport_exact = "Shift+Enter",
        key_teleport_north = "Shift+Up",
        key_teleport_south = "Shift+Down",
        key_teleport_west = "Shift+Left",
        key_teleport_east = "Shift+Right",
        key_freeze_npcs = "Shift+F",
        key_diag_cursor = "Ctrl+M",
        key_diag_tiles = "Ctrl+N",
        key_diag_title = "Ctrl+Y",
        key_diag_ppu_dump = "Ctrl+D",
    })

    local filtered = hotkey_filter.filter_bizhawk_keys({
        J = true,
        K = true,
        L = true,
        O = true,
        U = true,
        Q = true,
        Shift = true,
        P = true,
        H = true,
        I = true,
        G = true,
        E = true,
        R = true,
        T = true,
        F = true,
        LeftCtrl = true,
        Enter = true,
        Up = true,
        Right = true,
        V = true,
        M = true,
        N = true,
        Y = true,
        S = true,
        D = true,
    }, config)

    assert_equal(filtered.Shift, true, "player-info modifier should pass")
    assert_equal(filtered.P, true, "position key should pass")
    assert_equal(filtered.H, true, "HP key should pass")
    assert_equal(filtered.I, true, "level key should pass")
    assert_equal(filtered.G, true, "gold key should pass")
    assert_equal(filtered.E, true, "experience key should pass")
    assert_equal(filtered.R, true, "stats key should pass")
    assert_equal(filtered.T, true, "screen-text key should pass")
    assert_equal(filtered.J, true, "previous-object key should pass")
    assert_equal(filtered.K, true, "current-object key should pass")
    assert_equal(filtered.L, true, "next-object key should pass")
    assert_equal(filtered.O, true, "pathfind key should pass")
    assert_equal(filtered.U, true, "auto-walk key should pass")
    assert_equal(filtered.Q, true, "filter key should pass")
    assert_equal(filtered.K, true, "filter-all/current-object key should pass")
    assert_equal(filtered.F, true, "freeze key should pass")
    assert_equal(filtered.Enter, true, "teleport exact key should pass")
    assert_equal(filtered.Up, true, "teleport north key should pass")
    assert_equal(filtered.Right, true, "teleport east key should pass")
    assert_equal(filtered.V, true, "mark visited key should pass")
    assert_equal(filtered.LeftCtrl, true, "tile diagnostic modifier should pass")
    assert_equal(filtered.N, true, "tile diagnostic key should pass")
    assert_equal(filtered.M, nil, "cursor diagnostic key should be blocked by default")
    assert_equal(filtered.Y, nil, "title diagnostic key should be blocked by default")
    assert_equal(filtered.S, nil, "status key should be blocked by default")
    assert_equal(filtered.D, nil, "diagnostic key should be blocked by default")
end

function tests.blank_allowlist_falls_back_to_player_safe_defaults()
    local config = make_config({
        enable_bizhawk_keyboard_hotkeys = "false",
        enable_bizhawk_diagnostic_hotkeys = "false",
        bizhawk_keyboard_hotkey_allowlist = "",
        key_position = "Shift+P",
        key_object_next = "L",
        key_diag_tiles = "Ctrl+N",
        key_diag_ppu_dump = "Ctrl+D",
    })

    local filtered = hotkey_filter.filter_bizhawk_keys({
        Shift = true,
        P = true,
        L = true,
        LeftCtrl = true,
        N = true,
        D = true,
    }, config)

    assert_equal(filtered.Shift, true, "blank allowlist should still pass position modifier")
    assert_equal(filtered.P, true, "blank allowlist should still pass player readout key")
    assert_equal(filtered.L, true, "blank allowlist should still pass object navigation key")
    assert_equal(filtered.LeftCtrl, true, "blank allowlist should still pass compact tile readout modifier")
    assert_equal(filtered.N, true, "blank allowlist should still pass compact tile readout key")
    assert_equal(filtered.D, nil, "blank allowlist should not pass developer dump key")
end

function tests.combo_allowlist_does_not_pass_bare_component_key()
    local config = make_config({
        enable_bizhawk_keyboard_hotkeys = "false",
        enable_bizhawk_diagnostic_hotkeys = "false",
        key_object_prev = "J",
        key_object_current = "K",
        key_object_next = "L",
        key_pathfind = "O",
        key_auto_walk = "U",
        key_filter = "Q",
        key_pathability_filter = "Shift+O",
        key_freeze_npcs = "Shift+F",
        key_diag_tiles = "Ctrl+N",
    })

    local filtered = hotkey_filter.filter_bizhawk_keys({
        N = true,
        F = true,
    }, config)

    assert_equal(filtered.N, nil, "bare tile diagnostic key should not pass without Ctrl")
    assert_equal(filtered.F, nil, "bare freeze key should not pass without Shift")
end

function tests.custom_allowlist_can_enable_pathability_combo()
    local config = make_config({
        enable_bizhawk_keyboard_hotkeys = "false",
        enable_bizhawk_diagnostic_hotkeys = "false",
        bizhawk_keyboard_hotkey_allowlist = "key_pathability_filter",
        key_pathability_filter = "Shift+O",
        key_object_next = "L",
    })

    local filtered = hotkey_filter.filter_bizhawk_keys({
        Shift = true,
        O = true,
        L = true,
    }, config)

    assert_equal(filtered.Shift, true, "pathability combo modifier should pass when listed")
    assert_equal(filtered.O, true, "pathability combo key should pass when listed")
    assert_equal(filtered.L, nil, "unlisted object navigation key should remain blocked")
end

function tests.custom_allowlist_can_enable_future_qol_shortcut()
    local config = make_config({
        enable_bizhawk_keyboard_hotkeys = "false",
        enable_bizhawk_diagnostic_hotkeys = "false",
        bizhawk_keyboard_hotkey_allowlist = "key_object_next, key_qol_marker",
        key_object_next = "L",
        key_qol_marker = "Q",
        key_stats = "S",
    })

    local filtered = hotkey_filter.filter_bizhawk_keys({
        L = true,
        Q = true,
        S = true,
    }, config)

    assert_equal(filtered.L, true, "listed object key should pass")
    assert_equal(filtered.Q, true, "future QoL key should pass when listed by config setting name")
    assert_equal(filtered.S, nil, "unlisted status key should remain blocked")
end

function tests.custom_allowlist_can_still_enable_diagnostics_intentionally()
    local config = make_config({
        enable_bizhawk_keyboard_hotkeys = "false",
        enable_bizhawk_diagnostic_hotkeys = "true",
        bizhawk_keyboard_hotkey_allowlist = "key_diag_ppu_dump",
        key_diag_ppu_dump = "Ctrl+D",
        key_diag_tiles = "Ctrl+N",
    })

    local filtered = hotkey_filter.filter_bizhawk_keys({
        LeftCtrl = true,
        D = true,
        N = true,
    }, config)

    assert_equal(filtered.LeftCtrl, true, "explicit diagnostic modifier should pass")
    assert_equal(filtered.D, true, "explicit diagnostic dump key should pass")
    assert_equal(filtered.N, nil, "unlisted compact tile diagnostic should remain blocked")
end

function tests.diagnostic_keys_require_diagnostic_flag_even_when_listed()
    local config = make_config({
        enable_bizhawk_keyboard_hotkeys = "false",
        enable_bizhawk_diagnostic_hotkeys = "false",
        bizhawk_keyboard_hotkey_allowlist = "key_diag_ppu_dump",
        key_diag_ppu_dump = "Ctrl+D",
    })

    local filtered = hotkey_filter.filter_bizhawk_keys({
        LeftCtrl = true,
        D = true,
    }, config)

    assert_equal(filtered.LeftCtrl, nil, "diagnostic modifier should stay blocked when flag is false")
    assert_equal(filtered.D, nil, "diagnostic dump key should stay blocked when flag is false")
end

function tests.diagnostic_flag_adds_developer_diagnostics_to_safe_defaults()
    local config = make_config({
        enable_bizhawk_keyboard_hotkeys = "false",
        enable_bizhawk_diagnostic_hotkeys = "true",
        bizhawk_keyboard_hotkey_allowlist = "",
        key_diag_cursor = "Ctrl+M",
        key_diag_ppu_dump = "Ctrl+D",
        key_diag_title = "Ctrl+Y",
    })

    local filtered = hotkey_filter.filter_bizhawk_keys({
        LeftCtrl = true,
        M = true,
        D = true,
        Y = true,
    }, config)

    assert_equal(filtered.LeftCtrl, true, "diagnostic modifier should pass when flag is true")
    assert_equal(filtered.M, true, "cursor diagnostic key should pass when flag is true")
    assert_equal(filtered.D, true, "PPU dump diagnostic key should pass when flag is true")
    assert_equal(filtered.Y, true, "title diagnostic key should pass when flag is true")
end

function tests.full_bizhawk_hotkeys_setting_passes_keys_through()
    local config = make_config({
        enable_bizhawk_keyboard_hotkeys = "true",
    })
    local keys = {S = true, D = true, L = true}

    assert_equal(hotkey_filter.filter_bizhawk_keys(keys, config), keys, "full-hotkey mode should preserve original key table")
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

package.loaded["hotkey_filter"] = original_loaded

io.write(string.format("Ran %d Lua unit tests\n", total))

if failures > 0 then
    os.exit(1)
end
