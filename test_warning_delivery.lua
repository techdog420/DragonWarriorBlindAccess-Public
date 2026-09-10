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

function tests.pending_updates_and_cancellation_preserve_fifo_and_delivered_records()
    local queue = warning_delivery.new({neutral_frames=0})
    local first = queue:submit("First")
    local health = queue:submit("Old HP")
    local last = queue:submit("Last")
    assert(queue:update(health.id, "Current HP"))
    assert_equal(queue:cancel(first.id).id, first.id, "cancel only the requested record")
    local ready = queue:take_ready()
    assert_equal(#ready, 2, "other records survive cancellation")
    assert_equal(ready[1].text, "Current HP", "updated warning keeps its FIFO position")
    assert_equal(ready[2].id, last.id, "following warning stays behind updated warning")
    assert_equal(queue:update(health.id, "Too late"), nil, "delivered warning cannot be changed")
    assert_equal(queue:cancel(health.id), nil, "delivered warning cannot be cancelled")
end

function tests.physical_activity_overrides_stale_keys_without_bypassing_real_holds()
    assert_equal(warning_delivery.keyboard_has_input({Space=true}, false), false, "released physical Space")
    assert_equal(warning_delivery.keyboard_has_input({}, true), true, "physical hold while emulator reports no keys")
    assert_equal(warning_delivery.keyboard_has_input({Space=true}, nil), true, "older bridge retains fallback")
end

function tests.muting_travel_cancels_pending_without_muting_health()
    local q = warning_delivery.new({neutral_frames = 2})
    q:observe_input(true)
    local travel = q:submit("Swamp ahead", {kind="travel"})
    local health = q:submit("Low health")
    q:submit("Light expired", {kind="travel"})
    local cancelled = q:set_kind_enabled("travel", false)
    assert_equal(#cancelled, 2, "all pending travel cancelled")
    assert_equal(cancelled[1].id, travel.id, "cancellation preserves order")
    assert_equal(q:submit("Hazard ahead", {kind="travel"}), nil, "muted travel is not queued")
    q:observe_input(false); q:observe_input(false)
    local ready = q:take_ready()
    assert_equal(#ready, 1, "health retained")
    assert_equal(ready[1].id, health.id, "health identity retained")
    q:set_kind_enabled("travel", true)
    assert_equal(q:take_ready(), nil, "old travel does not replay")
    assert(q:submit("New hazard", {kind="travel"}))
    assert_equal(#q:take_ready(), 1, "new travel allowed after enabling")
end

function tests.retained_speech_bridge_uses_reloaded_config_instance()
    local current = {get=function(key) if key=="travel_warnings" then return "false" end return nil end}
    local sent = {}
    local lib = {Tolk_Load=function() end, Tolk_Output=function(text) sent[#sent+1]=text end}
    local sandbox = setmetatable({
        io={open=function() return nil end, popen=function() return nil end},
        print=function() end,
        require=function(name)
            if name=="config" then return current end
            if name=="ffi" then return {cdef=function() end, load=function() return lib end} end
            if name=="encoding" then return {to_utf16=function(text) return text end} end
            return require(name)
        end,
    }, {__index=_G})
    local chunk = assert(loadfile("tolk.lua"))
    setfenv(chunk, sandbox)
    local speech = chunk()
    assert_equal(speech.output_travel_warning("muted"), nil, "initial Off")
    current = {get=function(key) if key=="travel_warnings" then return "true" end return nil end}
    assert(speech.output_travel_warning("Light expands"))
    speech.flush_warnings()
    assert_equal(sent[1], "Light expands", "new On instance takes effect without restarting bridge")
    speech.output_travel_warning("pending travel")
    speech.output_warning("required confirmation")
    current = {get=function(key) if key=="travel_warnings" then return "false" end return nil end}
    speech.flush_warnings()
    assert_equal(#sent, 2, "only required speech survives new Off instance")
    assert_equal(sent[2], "required confirmation", "required prompt retained")
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
