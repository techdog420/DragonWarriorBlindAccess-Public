-- test_route_frontier_classifier.lua
-- Focused unit tests for route-frontier candidate classification.

local classifier = require "route_frontier_classifier"

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or "assert_equal failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local tests = {}

function tests.runtime_blocked_hidden_wall_is_not_treated_as_hidden_bridge()
    local result = classifier.classify_candidate({
        is_walkable = false,
        blocked_reason = "blocked_runtime",
    })

    assert_equal(result.reason, "blocked_runtime",
        "runtime-blocked not-walkable candidates should keep the runtime block reason")
    assert_equal(result.allow_hidden_bridge, false,
        "runtime-blocked not-walkable candidates should not be surfaced as hidden bridges")
end

function tests.open_hidden_wall_candidate_stays_hidden_bridge_eligible()
    local result = classifier.classify_candidate({
        is_walkable = false,
        blocked_reason = nil,
    })

    assert_equal(result.reason, "not_walkable",
        "plain non-walkable candidates should keep the not_walkable reason")
    assert_equal(result.allow_hidden_bridge, true,
        "plain non-walkable candidates should remain eligible for hidden-bridge detection")
end

function tests.walkable_unreached_candidate_stays_unknown()
    local result = classifier.classify_candidate({
        is_walkable = true,
        blocked_reason = nil,
    })

    assert_equal(result.reason, "unknown_unreached",
        "walkable unreached candidates without a block reason should stay unknown")
    assert_equal(result.allow_hidden_bridge, false,
        "walkable candidates are never hidden-bridge probes")
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
