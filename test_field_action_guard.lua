-- test_field_action_guard.lua
-- Focused unit tests for shared field movement command guards.

local ok, guard = pcall(require, "field_action_guard")

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or "assert_equal failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

assert_equal(ok, true, "field_action_guard module should load")

local tests = {}

function tests.clear_field_allows_auto_walk()
    assert_equal(
        guard.reason("auto_walk", {
            is_field = true,
        }),
        nil,
        "auto-walk should be allowed when no unsafe field UI or movement flow is active"
    )
end

function tests.auto_walk_refuses_yes_no_prompt()
    assert_equal(
        guard.reason("auto_walk", {
            is_field = true,
            yesno_active = true,
        }),
        "Answer or close the prompt before auto-walking",
        "auto-walk should not start while a Yes/No prompt can consume input"
    )
end

function tests.teleport_refuses_dialogue_with_teleport_wording()
    assert_equal(
        guard.reason("teleport", {
            is_field = true,
            dialogue_active = true,
        }),
        "Wait for dialogue to finish before teleporting",
        "teleport should use teleport-specific refusal wording"
    )
end

function tests.survey_reason_beats_generic_route_reason()
    assert_equal(
        guard.reason("auto_walk", {
            is_field = true,
            survey_active = true,
            route_active = true,
        }),
        "Stop the active survey before auto-walking",
        "survey state should explain the real owner of active movement"
    )
end

function tests.object_controls_refuse_yes_no_prompt()
    assert_equal(
        guard.reason("object_controls", {
            is_field = true,
            yesno_active = true,
        }),
        "Answer or close the prompt first",
        "object hotkeys should not run while a Yes/No prompt is active"
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
