-- test_auto_step.lua
-- Local unit tests for auto_step behavior that can run outside FCEUX.

local original_preload = {}
local original_loaded = {}
local original_joypad = _G.joypad

local function save_module(name)
    original_preload[name] = package.preload[name]
    original_loaded[name] = package.loaded[name]
end

local function restore_modules(names)
    for _, name in ipairs(names) do
        package.preload[name] = original_preload[name]
        package.loaded[name] = original_loaded[name]
    end
end

local function make_env()
    local px, py = 3, 1
    local frame = 0
    local injected = {}
    local published = {}
    local live_joy = {}

    local module_names = {
        "auto_step",
        "config",
        "debug_tools",
        "event_bus",
        "navigation",
        "tolk",
    }
    for _, name in ipairs(module_names) do
        save_module(name)
        package.loaded[name] = nil
    end

    package.preload["config"] = function()
        return {
            get = function(key)
                if key == "enable_auto_step" then
                    return "true"
                elseif key == "auto_step_timeout" then
                    return "60"
                end
                return nil
            end,
        }
    end

    package.preload["debug_tools"] = function()
        return {
            record_block = function() end,
            debug = function() end,
            info = function() end,
            error = function() end,
        }
    end

    package.preload["event_bus"] = function()
        return {
            publish = function(name, payload)
                published[#published + 1] = {name = name, payload = payload}
            end,
        }
    end

    package.preload["navigation"] = function()
        return {
            get_position = function()
                return 0x05, px, py
            end,
        }
    end

    package.preload["tolk"] = function()
        return {
            output = function() end,
            output_interrupt = function() end,
        }
    end

    _G.joypad = {
        read = function()
            return live_joy
        end,
        set = function(_, buttons)
            injected[frame] = buttons
        end,
    }

    local auto_step = require "auto_step"

    return {
        auto_step = auto_step,
        injected = injected,
        published = published,
        set_position = function(x, y)
            px, py = x, y
        end,
        set_joy = function(buttons)
            live_joy = buttons or {}
        end,
        update = function(can_walk)
            frame = frame + 1
            auto_step.update(can_walk)
        end,
        restore = function()
            restore_modules(module_names)
            _G.joypad = original_joypad
        end,
    }
end

local function assert_truthy(value, message)
    if not value then
        error(message, 2)
    end
end

local function has_any_direction(buttons)
    return buttons and (buttons.up or buttons.down or buttons.left or buttons.right)
end

local function collect_direction_sequences(env, dir, max_frame)
    local sequences = {}
    local active_start = nil
    local active_count = 0

    for frame = 0, max_frame do
        local buttons = env.injected[frame]
        local pressed = buttons and buttons[dir] or false
        if pressed then
            if active_start == nil then
                active_start = frame
                active_count = 1
            else
                active_count = active_count + 1
            end
        elseif active_start ~= nil then
            sequences[#sequences + 1] = {
                start = active_start,
                count = active_count,
            }
            active_start = nil
            active_count = 0
        end
    end

    if active_start ~= nil then
        sequences[#sequences + 1] = {
            start = active_start,
            count = active_count,
        }
    end

    return sequences
end

local tests = {}

function tests.turn_only_attempt_represses_before_full_timeout()
    local env = make_env()
    env.auto_step.inject_step("right")

    for _ = 1, 60 do
        env.update(true)
    end

    local sequences = collect_direction_sequences(env, "right", 60)
    local repress = sequences[2]

    assert_truthy(
        repress and repress.start < 60,
        "auto_step should re-press quickly after a turn-only attempt instead of waiting for full timeout"
    )

    env.restore()
end

function tests.never_moving_step_still_reports_blocked()
    local env = make_env()
    env.auto_step.inject_step("right")

    for _ = 1, 300 do
        env.update(true)
    end

    local saw_blocked = false
    for _, event in ipairs(env.published) do
        if event.name == "route_blocked" then
            saw_blocked = true
            break
        end
    end

    assert_truthy(saw_blocked, "blocked steps should still publish route_blocked after retries are exhausted")

    env.restore()
end

function tests.turn_repress_uses_full_inject_window_after_turn_only_attempt()
    local env = make_env()
    env.auto_step.inject_step("right")

    for _ = 1, 60 do
        env.update(true)
    end

    local sequences = collect_direction_sequences(env, "right", 60)
    local repress = sequences[2]

    assert_truthy(
        repress and repress.count >= 8,
        "turn re-press should restore a full inject window after a turn-only attempt so the follow-up press can start movement reliably"
    )

    env.restore()
end

function tests.turn_repress_waits_for_release_gap_before_rearming()
    local env = make_env()
    env.auto_step.inject_step("right")

    for _ = 1, 60 do
        env.update(true)
    end

    local sequences = collect_direction_sequences(env, "right", 60)
    local repress = sequences[2]

    assert_truthy(
        repress ~= nil,
        "test setup should observe a short turn re-press sequence"
    )
    assert_truthy(
        env.injected[repress.start - 1] and not has_any_direction(env.injected[repress.start - 1])
        and env.injected[repress.start - 2] and not has_any_direction(env.injected[repress.start - 2]),
        "turn re-press should actively send a short neutral gap before rearming"
    )

    assert_truthy(
        repress.start >= 2,
        "turn re-press should still resume shortly after the release gap"
    )

    env.restore()
end

function tests.live_direction_input_cancels_active_queued_route_step()
    local env = make_env()
    env.auto_step.start_route({"right"})

    env.update(true)
    env.set_joy({left = true})
    env.update(true)
    env.set_joy({})

    for _ = 1, 4 do
        env.update(true)
    end

    local saw_recontinued_right = false
    for frame = 2, 6 do
        local buttons = env.injected[frame]
        if buttons and buttons.right then
            saw_recontinued_right = true
            break
        end
    end

    assert_truthy(
        not saw_recontinued_right,
        "live manual direction input should cancel an active queued route step"
    )

    env.restore()
end

function tests.turn_repress_cancels_if_step_completes_during_release_gap()
    -- Two-phase pattern: probe_env runs first to discover the timing constants
    -- (specifically when the re-press sequence starts) without relying on
    -- hardcoded frame numbers. probe_env.restore() clears package.loaded so
    -- the second make_env() gets a fresh module with independent state.
    -- If restore() is ever skipped, env will share stale module state with
    -- probe_env and repress.start will refer to the wrong instance.
    local probe_env = make_env()
    probe_env.auto_step.inject_step("right")

    for _ = 1, 60 do
        probe_env.update(true)
    end

    local probe_sequences = collect_direction_sequences(probe_env, "right", 60)
    local repress = probe_sequences[2]
    assert_truthy(repress ~= nil and repress.start >= 2, "test setup should observe a re-press sequence")
    probe_env.restore()

    local env = make_env()
    env.auto_step.inject_step("right")

    for _ = 1, (repress.start - 2) do
        env.update(true)
    end

    -- Simulate the engine finally committing the original step while the
    -- release gap is in progress. Re-pressing from the new tile would cause
    -- the double-step bug we saw in live testing.
    env.set_position(4, 1)

    for _ = 1, 8 do
        env.update(true)
    end

    local sequences = collect_direction_sequences(env, "right", repress.start + 8)

    assert_truthy(
        #sequences == 1,
        "turn re-press should be cancelled once the original step finishes during the release gap"
    )

    env.restore()
end

function tests.successful_step_flushes_stale_direction_with_neutral_frames()
    local env = make_env()
    env.auto_step.inject_step("right")

    for _ = 1, 6 do
        env.update(true)
    end

    env.set_position(4, 1)
    env.update(true)
    env.update(true)
    env.update(true)

    assert_truthy(
        env.injected[8] and not has_any_direction(env.injected[8]),
        "auto_step should actively send a neutral frame immediately after a successful step"
    )
    assert_truthy(
        env.injected[9] and not has_any_direction(env.injected[9]),
        "auto_step should keep the D-pad neutral long enough to flush stale held input"
    )

    env.restore()
end

function tests.post_step_release_preserves_non_direction_buttons()
    local env = make_env()
    env.auto_step.inject_step("right")

    for _ = 1, 6 do
        env.update(true)
    end

    env.set_position(4, 1)
    env.update(true)
    env.set_joy({A = true})
    env.update(true)

    assert_truthy(
        env.injected[8] and env.injected[8].A and not has_any_direction(env.injected[8]),
        "post-step neutral frames should preserve live non-direction buttons while clearing the D-pad"
    )

    env.restore()
end

function tests.timeout_retry_after_turn_repress_restores_full_inject_window()
    local env = make_env()
    env.auto_step.inject_step("right")

    for _ = 1, 140 do
        env.update(true)
    end

    local sequences = collect_direction_sequences(env, "right", 140)
    local retry = sequences[3]

    assert_truthy(
        retry and retry.count >= 8,
        "timeout retries after a turn re-press should restore a full inject window before reporting blocked"
    )

    env.restore()
end

function tests.queued_routes_wait_for_configured_settle_gap_before_next_step()
    local env = make_env()
    env.auto_step.start_route({"right", "right"}, {settle_frames = 8})

    env.update(true)
    env.set_position(4, 1)
    env.update(true)

    for _ = 1, 8 do
        env.update(true)
    end

    for _ = 1, 10 do
        env.update(true)
    end

    for frame = 3, 10 do
        assert_truthy(
            not has_any_direction(env.injected[frame]),
            "queued route should not start the next step before the configured settle gap finishes"
        )
    end

    local saw_second_step = false
    for frame = 11, 20 do
        local buttons = env.injected[frame]
        if buttons and buttons.right then
            saw_second_step = true
            break
        end
    end

    assert_truthy(
        saw_second_step,
        "queued route should resume once the settle gap has elapsed"
    )

    env.restore()
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
