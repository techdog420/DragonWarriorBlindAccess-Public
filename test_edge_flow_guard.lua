-- test_edge_flow_guard.lua
-- Focused unit tests for mutually exclusive edge-probe command guards.

local ok, guard = pcall(require, "edge_flow_guard")

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or "assert_equal failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

assert_equal(ok, true, "edge_flow_guard module should load")

local tests = {}

function tests.no_active_flow_allows_start()
    assert_equal(
        guard.refusal_message("probe_edge", {
            probe_state = nil,
            verify_state = nil,
            seeded_probe_state = nil,
        }),
        nil,
        "no active edge flow should allow a new command to start"
    )
end

function tests.refuses_while_probe_active()
    assert_equal(
        guard.refusal_message("probe_edge_verify", {
            probe_state = {},
            verify_state = nil,
            seeded_probe_state = nil,
        }),
        "probe_edge_verify: wait for the active edge probe to finish",
        "verification should not start while a probe is active"
    )
end

function tests.refuses_while_verification_active()
    assert_equal(
        guard.refusal_message("probe_edge", {
            probe_state = nil,
            verify_state = {},
            seeded_probe_state = nil,
        }),
        "probe_edge: wait for the active edge verification to finish",
        "probe should not start while verification is active"
    )
end

function tests.refuses_while_seeded_probe_active()
    assert_equal(
        guard.refusal_message("probe_edge", {
            probe_state = nil,
            verify_state = nil,
            seeded_probe_state = {},
        }),
        "probe_edge: wait for the active seeded edge probe to finish",
        "probe should not start while a seeded probe is active"
    )
end

local failures = 0
local total = 0

for name, fn in pairs(tests) do
    total = total + 1
    local passed, err = pcall(fn)
    if passed then
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
