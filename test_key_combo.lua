-- test_key_combo.lua
-- Focused tests for configurable hotkey parsing.

local key_combo = require "key_combo"

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local tests = {}

function tests.alternative_hotkey_spec_accepts_bridge_choice()
    assert_equal(
        key_combo.is_down({Bridge2 = true}, "K|Bridge2"),
        true,
        "Bridge2 alternative should count as the configured hotkey")
end

function tests.alternative_hotkey_spec_preserves_edge_detection()
    assert_equal(
        key_combo.is_pressed({Bridge2 = true}, {}, "K|Bridge2"),
        true,
        "new Bridge2 press should trigger an alternative hotkey")
    assert_equal(
        key_combo.is_pressed({Bridge2 = true}, {Bridge2 = true}, "K|Bridge2"),
        false,
        "held Bridge2 alternative should not repeat")
end

function tests.alternative_hotkey_spec_keeps_modifier_requirements()
    assert_equal(
        key_combo.is_down({O = true}, "Shift+O|Bridge10"),
        false,
        "bare O should not trigger a Shift+O alternative")
    assert_equal(
        key_combo.is_down({LeftShift = true, O = true}, "Shift+O|Bridge10"),
        true,
        "Shift+O should still trigger its combo alternative")
    assert_equal(
        key_combo.is_down({Bridge10 = true}, "Shift+O|Bridge10"),
        true,
        "Bridge10 should trigger the alternate binding without Shift")
end

function tests.add_aliases_includes_every_alternative()
    local aliases = {}

    key_combo.add_aliases(aliases, "Shift+O|Bridge10")

    assert_equal(aliases.LeftShift, true, "Shift aliases should be included")
    assert_equal(aliases.O, true, "letter aliases should be included")
    assert_equal(aliases.Bridge10, true, "bridge aliases should be included")
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
