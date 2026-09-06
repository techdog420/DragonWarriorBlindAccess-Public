-- test_config.lua
-- Local unit tests for repository-shipped configuration defaults.

local tests = {}

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

function tests.route_turn_movement_reset_default_is_safe()
    package.loaded["config"] = nil
    local config = require("config")
    assert_equal(
        config.get_default("auto_step_reset_movement_on_route_turn_settle"),
        "false",
        "route-turn movement reset default should stay disabled after stat-corruption repro"
    )
end

function tests.player_auto_walk_stop_has_safe_default_binding()
    package.loaded["config"] = nil
    local config = require("config")
    assert_equal(
        config.get_default("key_stop_auto_walk"),
        "Shift+U",
        "player auto-walk cancellation should use the accessible Shift+U chord"
    )
end

function tests.route_status_has_read_only_default_binding()
    package.loaded["config"] = nil
    local config = require("config")
    assert_equal(
        config.get_default("key_route_status"),
        "Shift+R",
        "read-only route status should use the accessible Shift+R chord"
    )
    assert_equal(
        config.get_default("key_stats"),
        "Shift+B",
        "full stats should remain available without colliding with route status"
    )
end

function tests.overworld_continuous_auto_walk_is_opt_in()
    package.loaded["config"] = nil
    local config = require("config")
    assert_equal(
        config.get_default("overworld_auto_walk_continuous"),
        "false",
        "continuous overworld auto-walk should preserve one-segment behavior by default"
    )
end

function tests.darkness_navigation_has_accessible_defaults()
    package.loaded["config"] = nil
    local config = require("config")
    assert_equal(
        config.get_default("darkness_navigation_limits"),
        "balanced",
        "balanced darkness navigation should be the accessible default"
    )
    assert_equal(
        config.get_default("key_visible_area"),
        "Shift+N|F21",
        "the local visible-area report should have a player-safe binding"
    )
end

local passed = 0
local failed = 0

for name, fn in pairs(tests) do
    local ok, err = pcall(fn)
    if ok then
        print("PASS  " .. name)
        passed = passed + 1
    else
        print("FAIL  " .. name .. ": " .. tostring(err))
        failed = failed + 1
    end
end

print(string.format("Ran %d Lua unit tests", passed + failed))

if failed > 0 then
    os.exit(1)
end
