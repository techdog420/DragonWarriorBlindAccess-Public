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
