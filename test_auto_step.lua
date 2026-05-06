-- test_auto_step.lua
-- Local unit tests for auto_step behavior that can run outside FCEUX.

local original_preload = {}
local original_loaded = {}
local original_joypad = _G.joypad
local original_memory = _G.memory

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

local function make_env(opts)
    opts = opts or {}
    local map_id = opts.map_id or 0x05
    local px, py = 3, 1
    local frame = 0
    local injected = {}
    local published = {}
    local live_joy = {}
    local sticky_joy = {}
    local movement_subpixel = opts.movement_subpixel or 0x10

    local module_names = {
        "addresses",
        "auto_step",
        "config",
        "debug_tools",
        "emulator_compat",
        "event_bus",
        "map_reader",
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
                if opts.config_values and opts.config_values[key] ~= nil then
                    return opts.config_values[key]
                end
                if key == "enable_auto_step" then
                    return "true"
                elseif key == "auto_step_timeout" then
                    return "60"
                end
                return nil
            end,
        }
    end

    package.preload["addresses"] = function()
        return {
            MOVEMENT_SUBPIXEL = 0x003D,
        }
    end

    package.preload["emulator_compat"] = function()
        return {
            is_bizhawk = opts.is_bizhawk == true,
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
                published[#published + 1] = {name = name, payload = payload, frame = frame}
            end,
        }
    end

    package.preload["map_reader"] = function()
        return {
            is_hazard_cell = function(mid, x, y)
                local by_map = opts.hazard_cells and opts.hazard_cells[mid]
                return by_map and by_map[x .. "," .. y] or false
            end,
        }
    end

    package.preload["navigation"] = function()
        return {
            get_position = function()
                return map_id, px, py
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
            if opts.sticky_joypad_set then
                local merged = {}
                for key, value in pairs(sticky_joy or {}) do
                    if value and key:sub(1, 1) ~= "_" then
                        merged[key] = value
                    end
                end
                for key, value in pairs(live_joy or {}) do
                    if value then
                        merged[key] = value
                    else
                        merged[key] = nil
                    end
                end
                return merged
            end
            return live_joy
        end,
        set = function(_, buttons)
            injected[frame] = buttons
            if opts.sticky_joypad_set then
                sticky_joy = buttons or {}
            end
        end,
    }
    _G.memory = {
        readbyte = function(address)
            if address == 0x003D then
                return movement_subpixel
            end
            return 0
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
        set_subpixel = function(value)
            movement_subpixel = value
        end,
        update = function(can_walk)
            frame = frame + 1
            auto_step.update(can_walk)
        end,
        restore = function()
            restore_modules(module_names)
            _G.joypad = original_joypad
            _G.memory = original_memory
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

function tests.blocked_step_flushes_stale_direction_with_neutral_frames()
    local env = make_env()
    env.auto_step.inject_step("right")

    for _ = 1, 300 do
        env.update(true)
    end

    local blocked_frame = nil
    for _, event in ipairs(env.published) do
        if event.name == "route_blocked" then
            blocked_frame = event.frame
            break
        end
    end

    assert_truthy(blocked_frame ~= nil, "test setup should observe a blocked step")
    assert_truthy(
        env.injected[blocked_frame] and not has_any_direction(env.injected[blocked_frame]),
        "auto_step should actively clear the D-pad on the same frame it reports a blocked step"
    )

    env.update(true)

    assert_truthy(
        env.injected[blocked_frame + 1] and not has_any_direction(env.injected[blocked_frame + 1]),
        "auto_step should keep the D-pad neutral immediately after a blocked step"
    )

    env.restore()
end

function tests.inject_window_does_not_neutralize_live_direction()
    local env = make_env()
    env.auto_step.inject_step("right")

    env.set_joy({right = true})
    for _ = 1, 14 do
        env.update(true)
    end

    assert_truthy(
        env.injected[13] == nil and env.injected[14] == nil,
        "auto_step should not emit neutral joypad frames over a live held direction after the inject window"
    )

    env.restore()
end

function tests.queued_route_neutralizes_after_inject_window()
    local env = make_env()
    env.auto_step.start_route({"right"})

    for _ = 1, 14 do
        env.update(true)
    end

    assert_truthy(
        env.injected[14] and not has_any_direction(env.injected[14]),
        "queued route should actively clear sticky D-pad state after the inject window"
    )
    env.restore()
end

function tests.manual_auto_step_neutralizes_after_inject_window_when_released()
    local env = make_env()
    env.auto_step.inject_step("right")

    for _ = 1, 13 do
        env.update(true)
    end

    assert_truthy(
        env.injected[13] and not has_any_direction(env.injected[13]),
        "manual auto-step should clear stale injected D-pad after the inject window"
    )
    env.restore()
end

function tests.manual_auto_step_refuses_known_hazard_destination()
    local env = make_env({
        map_id = 0x04,
        hazard_cells = {
            [0x04] = {["10,18"] = "damage"},
        },
    })
    env.set_position(10, 19)

    env.set_joy({up = true})
    env.update(true)
    env.set_joy({})
    env.update(true)

    for _ = 1, 8 do
        env.update(true)
    end

    assert_truthy(
        not env.auto_step.is_auto_active(),
        "manual tap-to-step should not auto-hold into a known hazard"
    )
    for frame, buttons in pairs(env.injected) do
        assert_truthy(
            not has_any_direction(buttons),
            string.format("hazard refusal should not inject D-pad input at frame %d", frame)
        )
    end

    env.restore()
end

function tests.queued_route_cancels_before_known_hazard_destination()
    local env = make_env({
        map_id = 0x04,
        hazard_cells = {
            [0x04] = {["10,18"] = "damage"},
        },
    })
    env.set_position(10, 19)
    env.auto_step.start_route({"up", "left"})

    env.update(true)

    local saw_cancel = false
    for _, event in ipairs(env.published) do
        local payload = event.payload or {}
        if event.name == "route_cancelled"
           and payload.reason == "dangerous_tile"
           and payload.dest_x == 10
           and payload.dest_y == 18 then
            saw_cancel = true
            break
        end
    end
    assert_truthy(saw_cancel, "queued route should cancel before stepping into a known hazard")
    assert_truthy(not env.auto_step.is_route_active(), "hazard-cancelled route should no longer be active")
    for frame, buttons in pairs(env.injected) do
        assert_truthy(
            not has_any_direction(buttons),
            string.format("hazard-cancelled route should not inject D-pad input at frame %d", frame)
        )
    end

    env.restore()
end

function tests.subpixel_release_can_be_disabled()
    local env = make_env({
        sticky_joypad_set = true,
        config_values = {
            auto_step_release_on_movement_start = "false",
        },
    })
    env.auto_step.start_route({"right"})

    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)

    assert_truthy(
        env.injected[2] and env.injected[2].right,
        "subpixel changes should not release D-pad when the option is disabled"
    )

    env.restore()
end

function tests.timeout_retry_resets_movement_started_flag()
    local env = make_env({
        sticky_joypad_set = true,
        config_values = {
            auto_step_timeout = "4",
            auto_step_block_retry_limit = "1",
            auto_step_release_on_movement_start = "true",
        },
    })
    env.auto_step.start_route({"right"})

    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)
    env.update(true)
    env.update(true)
    env.update(true)
    env.update(true)

    assert_truthy(
        env.injected[6] and env.injected[6].right,
        "timeout retry should inject a real held direction after an early movement-start release"
    )

    env.restore()
end

function tests.movement_start_subpixel_releases_injected_direction()
    local env = make_env({
        sticky_joypad_set = true,
        config_values = {
            auto_step_release_on_movement_start = "true",
        },
    })
    env.auto_step.start_route({"right"})

    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)

    assert_truthy(
        env.injected[2] and not has_any_direction(env.injected[2]),
        "auto_step should release D-pad as soon as movement subpixel changes"
    )

    env.restore()
end

function tests.cancel_active_step_does_not_emit_sticky_neutral()
    local env = make_env({sticky_joypad_set = true})
    env.auto_step.inject_step("right")

    env.update(true)
    env.auto_step.cancel_active_step(true)

    assert_truthy(
        env.injected[1] and env.injected[1].right,
        "cancel_active_step should not emit a neutral joypad.set that can stick over live controller input"
    )

    env.restore()
end

function tests.can_walk_false_clears_release_state_without_neutralizing()
    local env = make_env({sticky_joypad_set = true})
    env.auto_step.inject_step("right")

    for _ = 1, 6 do
        env.update(true)
    end

    env.set_position(4, 1)
    env.update(true)
    env.update(false)
    env.update(false)
    env.update(true)

    assert_truthy(
        env.injected[8] == nil and env.injected[9] == nil and env.injected[10] == nil,
        "can_walk=false should clear post-step release state without sending repeated neutral input on title/menu screens"
    )

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

function tests.turn_repress_handles_early_subpixel_turn_without_waiting_for_timeout()
    local env = make_env()
    env.auto_step.inject_step("right")

    env.update(true)
    env.set_subpixel(0x20)
    for _ = 1, 35 do
        env.update(true)
    end

    local sequences = collect_direction_sequences(env, "right", 40)
    local repress = sequences[2]

    assert_truthy(
        repress and repress.start < 40,
        "early subpixel-only turn attempts should still re-press before the full timeout"
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
        env.injected[7] and not has_any_direction(env.injected[7]),
        "auto_step should actively clear the D-pad on the same frame it observes step completion"
    )
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

function tests.queued_route_post_step_release_ignores_stale_direction_blip()
    local env = make_env()
    env.auto_step.start_route({"right", "right"})

    env.update(true)
    env.set_position(4, 1)
    env.update(true)

    env.set_joy({right = true})
    env.update(true)
    env.set_joy({})

    for _ = 1, 8 do
        env.update(true)
    end

    local right_sequences = collect_direction_sequences(env, "right", 16)
    assert_truthy(
        #right_sequences >= 2,
        "a stale direction blip during queued-route post-step release should not clear the route"
    )

    env.restore()
end

function tests.queued_route_direction_change_waits_for_default_turn_settle()
    local env = make_env()
    env.auto_step.start_route({"right", "down"})

    env.update(true)
    env.set_position(4, 1)
    env.update(true)

    for _ = 1, 12 do
        env.update(true)
    end

    for frame = 3, 14 do
        local buttons = env.injected[frame]
        assert_truthy(
            not (buttons and buttons.down),
            "queued route should wait before injecting a different direction after a completed step"
        )
    end

    local saw_down = false
    for _ = 1, 12 do
        env.update(true)
    end
    for frame = 15, 30 do
        local buttons = env.injected[frame]
        if buttons and buttons.down then
            saw_down = true
            break
        end
    end

    assert_truthy(
        saw_down,
        "queued route should resume with the new direction after the turn settle gap"
    )

    env.restore()
end

function tests.queued_route_turn_settle_actively_neutralizes_stale_direction()
    local env = make_env()
    env.auto_step.start_route({"right", "down"})

    env.update(true)
    env.set_position(4, 1)
    env.update(true)

    for _ = 1, 8 do
        env.update(true)
    end

    for frame = 3, 10 do
        assert_truthy(
            env.injected[frame] and not has_any_direction(env.injected[frame]),
            "queued route turn settle should actively send neutral D-pad frames until the next direction starts"
        )
    end

    env.restore()
end

function tests.queued_route_live_input_cancels_after_release_gap()
    local env = make_env()
    env.auto_step.start_route({"right", "right"}, {settle_frames = 3})

    env.update(true)
    env.set_position(4, 1)
    env.update(true)

    -- Hold live input past the automatic post-step neutral gap. This is a real
    -- interruption, not a one-frame stale joypad blip.
    env.set_joy({right = true})
    for _ = 1, 5 do
        env.update(true)
    end

    local saw_cancel = false
    for _, event in ipairs(env.published) do
        local payload = event.payload or {}
        if event.name == "route_cancelled"
           and payload.reason == "live_input_interrupt"
           and payload.source == "route_settle" then
            saw_cancel = true
            break
        end
    end
    assert_truthy(
        saw_cancel,
        "live direction held beyond the post-step release gap should cancel the queued route instead of being consumed as catch-up"
    )

    env.restore()
end

function tests.queued_routes_consume_matching_drift_during_settle()
    local env = make_env()
    env.auto_step.start_route({"right", "right", "down"}, {settle_frames = 3})

    env.update(true)
    env.set_position(4, 1)
    env.update(true)
    env.set_position(5, 1)

    for _ = 1, 10 do
        env.update(true)
    end

    local right_sequences = collect_direction_sequences(env, "right", 20)
    assert_truthy(
        #right_sequences == 1,
        "queued route should consume drift that already completed the next planned step instead of re-pressing that direction"
    )

    local saw_down = false
    for frame = 3, 20 do
        local buttons = env.injected[frame]
        if buttons and buttons.down then
            saw_down = true
            break
        end
    end
    assert_truthy(
        saw_down,
        "queued route should resume with the following planned direction after consuming drift"
    )

    local saw_catchup = false
    for _, event in ipairs(env.published) do
        local payload = event.payload or {}
        if event.name == "route_step_completed"
           and payload.source == "route_settle_catchup"
           and payload.from_x == 4
           and payload.from_y == 1
           and payload.to_x == 5
           and payload.to_y == 1
           and payload.dir == "right" then
            saw_catchup = true
            break
        end
    end
    assert_truthy(
        saw_catchup,
        "queued route catch-up should publish a step completion for the drifted tile"
    )

    env.restore()
end

function tests.queued_routes_cancel_unmatched_drift_during_settle()
    local env = make_env()
    env.auto_step.start_route({"right", "right", "down"}, {settle_frames = 3})

    env.update(true)
    env.set_position(4, 1)
    env.update(true)
    env.set_position(4, 0)

    for _ = 1, 10 do
        env.update(true)
    end

    local saw_cancel = false
    for _, event in ipairs(env.published) do
        local payload = event.payload or {}
        if event.name == "route_cancelled"
           and payload.reason == "route_drift_off_path"
           and payload.from_x == 4
           and payload.from_y == 1
           and payload.current_x == 4
           and payload.current_y == 0 then
            saw_cancel = true
            break
        end
    end
    assert_truthy(
        saw_cancel,
        "queued route should cancel when live position drifts off the planned path"
    )

    for frame = 3, 20 do
        local buttons = env.injected[frame]
        assert_truthy(
            not (buttons and (buttons.right or buttons.down)),
            "queued route should not continue stale directions after off-path drift"
        )
    end

    env.restore()
end

function tests.suppressed_direction_press_does_not_start_auto_step()
    local env = make_env()

    env.auto_step.suppress_direction_tracking(4)
    env.set_joy({up = true})
    env.update(true)
    env.set_joy({})
    env.update(true)

    for _ = 1, 8 do
        env.update(true)
    end

    for frame, buttons in pairs(env.injected) do
        assert_truthy(
            not has_any_direction(buttons),
            string.format("suppressed direction tap should not inject auto-step input at frame %d", frame)
        )
    end

    for _, event in ipairs(env.published) do
        assert_truthy(
            event.name ~= "route_blocked",
            "suppressed direction tap should not become a blocked movement event"
        )
    end

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
