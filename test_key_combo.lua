-- test_key_combo.lua
-- Focused tests for configurable hotkey parsing.

local key_combo = require "key_combo"

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local tests = {}

function tests.alternative_hotkey_spec_accepts_high_function_key_choice()
    assert_equal(
        key_combo.is_down({F14 = true}, "K|F14"),
        true,
        "F14 alternative should count as the configured hotkey")
end

function tests.alternative_hotkey_spec_preserves_edge_detection()
    assert_equal(
        key_combo.is_pressed({F14 = true}, {}, "K|F14"),
        true,
        "new F14 press should trigger an alternative hotkey")
    assert_equal(
        key_combo.is_pressed({F14 = true}, {F14 = true}, "K|F14"),
        false,
        "held F14 alternative should not repeat")
end

function tests.trigger_edge_requires_the_nonmodifier_key_to_be_new()
    assert_equal(
        key_combo.is_trigger_pressed(
            {RightShift = true, Down = true},
            {Down = true},
            "Shift+Down"),
        false,
        "new Shift must not activate a combo over a stale Down key")
    assert_equal(
        key_combo.is_trigger_pressed(
            {RightShift = true, Down = true},
            {Down = true},
            "Down+Shift"),
        false,
        "modifier-last remaps must still use Down as the trigger")
    assert_equal(
        key_combo.is_trigger_pressed(
            {RightShift = true, Down = true},
            {RightShift = true},
            "Shift+Down"),
        true,
        "new Down should activate a combo while Shift is held")
    assert_equal(
        key_combo.is_trigger_pressed(
            {RightShift = true, Down = true},
            {},
            "Shift+Down"),
        true,
        "simultaneous Shift and Down should still activate the combo")
end

function tests.trigger_edge_supports_aliases_and_alternatives()
    assert_equal(
        key_combo.is_trigger_pressed(
            {LeftShift = true, Return = true},
            {LeftShift = true},
            "Shift+Enter|F20"),
        true,
        "Return should activate the Enter trigger alias")
    assert_equal(
        key_combo.is_trigger_pressed(
            {F20 = true},
            {},
            "Shift+Enter|F20"),
        true,
        "a plain alternative should use its own key edge")
end

function tests.alternative_hotkey_spec_keeps_modifier_requirements()
    assert_equal(
        key_combo.is_down({O = true}, "Shift+O|F20"),
        false,
        "bare O should not trigger a Shift+O alternative")
    assert_equal(
        key_combo.is_down({LeftShift = true, O = true}, "Shift+O|F20"),
        true,
        "Shift+O should still trigger its combo alternative")
    assert_equal(
        key_combo.is_down({F20 = true}, "Shift+O|F20"),
        true,
        "F20 should trigger the alternate binding without Shift")
end

function tests.add_aliases_includes_every_alternative()
    local aliases = {}

    key_combo.add_aliases(aliases, "Shift+O|F20")

    assert_equal(aliases.LeftShift, true, "Shift aliases should be included")
    assert_equal(aliases.O, true, "letter aliases should be included")
    assert_equal(aliases.F20, true, "function-key alternative should be included")
end

local total = 0
for name, fn in pairs(tests) do
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        io.write("PASS  " .. name .. "\n")
    else
        io.stderr:write("FAIL  " .. name .. ": " .. tostring(err) .. "\n")
        os.exit(1)
    end
end

io.write(string.format("Ran %d Lua unit tests\n", total))
