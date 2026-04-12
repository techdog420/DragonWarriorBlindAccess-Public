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
            return {}
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

local tests = {}

function tests.turn_only_attempt_represses_before_full_timeout()
    local env = make_env()
    env.auto_step.inject_step("right")

    for _ = 1, 24 do
        env.update(true)
    end

    local saw_fast_repress = false
    for frame = 19, 30 do
        local buttons = env.injected[frame]
        if buttons and buttons.right then
            saw_fast_repress = true
            break
        end
    end

    assert_truthy(
        saw_fast_repress,
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

function tests.turn_repress_uses_short_inject_window()
    local env = make_env()
    env.auto_step.inject_step("right")

    for _ = 1, 30 do
        env.update(true)
    end

    local repress_injections = 0
    for frame = 19, 30 do
        local buttons = env.injected[frame]
        if buttons and buttons.right then
            repress_injections = repress_injections + 1
        end
    end

    assert_truthy(
        repress_injections > 0 and repress_injections <= 5,
        "turn re-press should use a short inject window to avoid overshooting into a second tile"
    )

    env.restore()
end

function tests.turn_repress_waits_for_release_gap_before_rearming()
    local env = make_env()
    env.auto_step.inject_step("right")

    for _ = 1, 24 do
        env.update(true)
    end

    assert_truthy(
        env.injected[19] == nil and env.injected[20] == nil,
        "turn re-press should leave a short fully released gap before rearming"
    )

    local saw_repress_after_gap = false
    for frame = 21, 32 do
        local buttons = env.injected[frame]
        if buttons and buttons.right then
            saw_repress_after_gap = true
            break
        end
    end

    assert_truthy(
        saw_repress_after_gap,
        "turn re-press should still resume shortly after the release gap"
    )

    env.restore()
end

function tests.turn_repress_cancels_if_step_completes_during_release_gap()
    local env = make_env()
    env.auto_step.inject_step("right")

    for _ = 1, 18 do
        env.update(true)
    end

    -- Simulate the engine finally committing the original step while the
    -- release gap is in progress. Re-pressing from the new tile would cause
    -- the double-step bug we saw in live testing.
    env.set_position(4, 1)

    for _ = 1, 6 do
        env.update(true)
    end

    local saw_rearm = false
    for frame = 19, 30 do
        local buttons = env.injected[frame]
        if buttons and buttons.right then
            saw_rearm = true
            break
        end
    end

    assert_truthy(
        not saw_rearm,
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

function tests.timeout_retry_after_turn_repress_restores_full_inject_window()
    local env = make_env()
    env.auto_step.inject_step("right")

    for _ = 1, 95 do
        env.update(true)
    end

    local retry_injections = 0
    for frame = 78, 95 do
        local buttons = env.injected[frame]
        if buttons and buttons.right then
            retry_injections = retry_injections + 1
        end
    end

    assert_truthy(
        retry_injections >= 8,
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
