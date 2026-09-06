-- test_warning_delivery.lua
-- Deterministic tests for the input-idle warning queue.

package.loaded["warning_delivery"] = nil
local warning_delivery = require "warning_delivery"

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local tests = {}

function tests.keyboard_activity_ignores_modifier_only_and_mouse_state()
    assert_equal(
        warning_delivery.keyboard_has_input({
            LeftAlt = true,
            LeftWindows = true,
            RightWindows = true,
            Shift = true,
            xmouse = 32,
        }),
        false,
        "modifier-only or mouse state should not hold warnings forever")
    assert_equal(
        warning_delivery.keyboard_has_input({Shift = true, W = true}),
        true,
        "a screen-reader chord with a non-modifier key should count as input")
    assert_equal(
        warning_delivery.keyboard_has_input({Up = true}),
        true,
        "movement key should count as input")
end

function tests.idle_warning_is_ready_without_an_artificial_delay()
    local queue = warning_delivery.new({neutral_frames = 3})
    queue:submit("The light fades.")
    local ready = queue:take_ready()
    assert_equal(#ready, 1, "idle queue should deliver on the current frame")
    assert_equal(ready[1].text, "The light fades.", "warning text")
    assert_equal(ready[1].deferred, false, "already-idle warning should not be marked deferred")
end

function tests.active_input_holds_warning_until_full_neutral_window()
    local queue = warning_delivery.new({neutral_frames = 3})
    queue:observe_input(true)
    queue:submit("Dangerous tile ahead")
    assert_equal(queue:take_ready(), nil, "held input should defer warning")

    queue:observe_input(false)
    assert_equal(queue:take_ready(), nil, "first neutral frame")
    queue:observe_input(false)
    assert_equal(queue:take_ready(), nil, "second neutral frame")
    queue:observe_input(false)
    local ready = queue:take_ready()
    assert_equal(#ready, 1, "third neutral frame should release warning")
    assert_equal(ready[1].deferred, true, "held warning should retain deferred metadata")
end

function tests.renewed_input_restarts_the_neutral_countdown()
    local queue = warning_delivery.new({neutral_frames = 2})
    queue:observe_input(true)
    queue:submit("Warning one")
    queue:observe_input(false)
    queue:observe_input(true)
    queue:observe_input(false)
    assert_equal(queue:take_ready(), nil, "renewed input should restart idle detection")
    queue:observe_input(false)
    assert_equal(#queue:take_ready(), 1, "full second neutral window should release warning")
end

function tests.multiple_warnings_keep_fifo_message_boundaries()
    local queue = warning_delivery.new({neutral_frames = 1})
    queue:observe_input(true)
    local first = queue:submit("The light dims.")
    local second = queue:submit("Poison swamp ahead.", {interrupt = false})
    queue:observe_input(false)
    local ready = queue:take_ready()
    assert_equal(#ready, 2, "both warnings should remain available")
    assert_equal(ready[1].id, first.id, "first warning order")
    assert_equal(ready[2].id, second.id, "second warning order")
    assert_equal(ready[2].interrupt, false, "per-message metadata should survive deferral")
end

function tests.empty_warning_is_ignored()
    local queue = warning_delivery.new({neutral_frames = 1})
    assert_equal(queue:submit(""), nil, "empty string")
    assert_equal(queue:submit(nil), nil, "nil warning")
    assert_equal(queue:get_state().pending_count, 0, "ignored warnings should not enter queue")
end

function tests.reconfigured_delay_preserves_pending_warning()
    local queue = warning_delivery.new({neutral_frames = 5})
    queue:observe_input(true)
    queue:submit("Warning")
    queue:observe_input(false)
    queue:set_neutral_frames(1)
    local state = queue:get_state()
    assert_equal(state.pending_count, 1, "config reload should preserve pending warning")
    assert_equal(#queue:take_ready(), 1, "shorter configured delay should take effect")
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
