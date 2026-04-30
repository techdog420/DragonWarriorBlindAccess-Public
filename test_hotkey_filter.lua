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
        key_object_prev = "J",
        key_object_current = "K",
        key_object_next = "L",
        key_pathfind = "O",
        key_auto_walk = "U",
        key_filter = "F",
        key_freeze_npcs = "X",
        key_diag_tiles = "N",
        key_stats = "S",
        key_diag_ppu_dump = "D",
    })

    local filtered = hotkey_filter.filter_bizhawk_keys({
        J = true,
        K = true,
        L = true,
        O = true,
        U = true,
        F = true,
        X = true,
        N = true,
        S = true,
        D = true,
    }, config)

    assert_equal(filtered.J, true, "previous-object key should pass")
    assert_equal(filtered.K, true, "current-object key should pass")
    assert_equal(filtered.L, true, "next-object key should pass")
    assert_equal(filtered.O, true, "pathfind key should pass")
    assert_equal(filtered.U, true, "auto-walk key should pass")
    assert_equal(filtered.F, true, "filter key should pass")
    assert_equal(filtered.X, true, "freeze key should pass")
    assert_equal(filtered.N, true, "tile diagnostic key should pass")
    assert_equal(filtered.S, nil, "status key should be blocked by default")
    assert_equal(filtered.D, nil, "diagnostic key should be blocked by default")
end

function tests.custom_allowlist_can_enable_future_qol_shortcut()
    local config = make_config({
        enable_bizhawk_keyboard_hotkeys = "false",
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
