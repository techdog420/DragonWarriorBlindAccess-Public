-- test_auto_step.lua
-- Local unit tests for auto_step behavior that can run outside FCEUX.

local original_preload = {}
local original_loaded = {}
local original_joypad = _G.joypad
local original_memory = _G.memory
local original_os_clock = os.clock

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
    local recorded_blocks = {}
    local outputs = {}
    local live_joy = {}
    local sticky_joy = {}
    local movement_state = opts.movement_state or 0x10
    local movement_subpixel = opts.movement_subpixel or 0x10
    local memory_writes = {}
    local clock_now = 0

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
            MOVEMENT_STATE = 0x003C,
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
            record_block = function(...)
                recorded_blocks[#recorded_blocks + 1] = {...}
            end,
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
            is_permanently_blocked_override = function(mid, x, y)
                local by_map = opts.permanent_blocked_cells and opts.permanent_blocked_cells[mid]
                return by_map and by_map[x .. "," .. y] or false
            end,
            get_directional_blocks = function(mid)
                return opts.directional_blocks and opts.directional_blocks[mid] or {}
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
            output_interrupt = function(message)
                outputs[#outputs + 1] = message
            end,
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
            if address == 0x003C then
                return movement_state
            end
            if address == 0x003D then
                return movement_subpixel
            end
            return 0
        end,
        writebyte = function(address, value)
            memory_writes[#memory_writes + 1] = {address = address, value = value}
            if address == 0x003C then
                movement_state = value
            elseif address == 0x003D then
                movement_subpixel = value
            end
        end,
    }
    os.clock = function()
        return clock_now
    end

    local auto_step = require "auto_step"

    return {
        auto_step = auto_step,
        injected = injected,
        published = published,
        recorded_blocks = recorded_blocks,
        outputs = outputs,
        memory_writes = memory_writes,
        set_position = function(x, y)
            px, py = x, y
        end,
        set_joy = function(buttons)
            live_joy = buttons or {}
        end,
        set_subpixel = function(value)
            movement_subpixel = value
        end,
        set_movement_state = function(value)
            movement_state = value
        end,
        advance_clock = function(seconds)
            clock_now = clock_now + seconds
        end,
        update = function(can_walk)
            frame = frame + 1
            auto_step.update(can_walk)
        end,
        restore = function()
            restore_modules(module_names)
            _G.joypad = original_joypad
            _G.memory = original_memory
            os.clock = original_os_clock
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

function tests.movement_started_timeout_waits_for_post_release_settle()
    local env = make_env({
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_timeout = "4",
            auto_step_block_retry_limit = "0",
            auto_step_route_early_release_grace_frames = "10",
        },
    })
    env.auto_step.inject_step("right", {
        source = "seam_retry",
        hold_after_movement_start = true,
    })

    env.update(true)
    env.set_subpixel(0x20)
    for _ = 1, 64 do
        env.update(true)
    end

    assert_truthy(
        env.auto_step.is_auto_active(),
        "movement-started timeout should stay active during the post-release settle window"
    )

    env.set_position(5, 1)
    env.update(true)

    local saw_complete = false
    local saw_blocked = false
    for _, event in ipairs(env.published) do
        if event.name == "route_step_completed" then
            local payload = event.payload or {}
            if payload.from_x == 3 and payload.from_y == 1 and payload.to_x == 5 and payload.to_y == 1 then
                saw_complete = true
            end
        elseif event.name == "route_blocked" then
            saw_blocked = true
        end
    end

    assert_truthy(saw_complete, "post-release settle should treat delayed movement as a completed step")
    assert_truthy(not saw_blocked, "post-release settle should avoid publishing route_blocked when movement lands after release")

    env.restore()
end

function tests.blocked_step_does_not_record_debug_block_by_default()
    local env = make_env()
    env.auto_step.inject_step("right")

    for _ = 1, 300 do
        env.update(true)
    end

    assert_truthy(#env.recorded_blocks == 0, "automatic debug block recording should be opt-in")

    env.restore()
end

function tests.blocked_step_records_debug_block_when_enabled()
    local env = make_env({
        config_values = {
            auto_step_record_debug_blocks = "true",
        },
    })
    env.auto_step.inject_step("right")

    for _ = 1, 300 do
        env.update(true)
    end

    assert_truthy(#env.recorded_blocks > 0, "debug block recording should still be available when explicitly enabled")

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

function tests.manual_no_movement_step_keeps_holding_until_turn_repress()
    local env = make_env()
    env.auto_step.inject_step("right")

    for _ = 1, 14 do
        env.update(true)
    end

    assert_truthy(
        env.injected[14] and env.injected[14].right,
        "manual/probe auto-step should keep holding before turn re-press if movement has not started"
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

function tests.manual_auto_step_keeps_holding_after_inject_window_when_not_started()
    local env = make_env()
    env.auto_step.inject_step("right")

    for _ = 1, 13 do
        env.update(true)
    end

    assert_truthy(
        env.injected[13] and env.injected[13].right,
        "manual auto-step should keep holding after the inject window when movement has not started"
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

function tests.manual_auto_step_allows_confirmed_known_hazard_destination()
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

    assert_truthy(
        not env.auto_step.is_auto_active(),
        "first manual tap should warn and avoid auto-holding into a known hazard"
    )
    assert_truthy(
        env.outputs[1] == "Damage floor ahead. Press up again to enter.",
        "first manual hazard tap should give an explicit confirmation instruction"
    )

    env.set_joy({up = true})
    env.update(true)
    env.set_joy({})
    env.update(true)

    assert_truthy(
        env.auto_step.is_auto_active(),
        "second same-direction manual tap should confirm and auto-hold into the hazard"
    )

    env.restore()
end

function tests.manual_hazard_confirmation_expires()
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

    env.advance_clock(3)
    env.set_joy({up = true})
    env.update(true)
    env.set_joy({})
    env.update(true)

    assert_truthy(
        not env.auto_step.is_auto_active(),
        "expired hazard confirmation should require a fresh warning tap"
    )
    assert_truthy(
        #env.outputs == 2,
        "expired hazard confirmation should warn again instead of entering"
    )

    env.restore()
end

function tests.manual_auto_step_does_not_extend_known_directional_wall()
    local env = make_env({
        map_id = 0x08,
        directional_blocks = {
            [0x08] = {["26,28"] = {east = true}},
        },
    })
    env.set_position(27, 28)

    env.set_joy({left = true})
    env.update(true)
    env.set_joy({})
    env.update(true)

    for _ = 1, 8 do
        env.update(true)
    end

    assert_truthy(
        not env.auto_step.is_auto_active(),
        "manual tap-to-step should not auto-hold into a known directional wall"
    )
    for frame, buttons in pairs(env.injected) do
        assert_truthy(
            not has_any_direction(buttons),
            string.format("known directional wall should not inject D-pad input at frame %d", frame)
        )
    end

    env.restore()
end

function tests.manual_auto_step_does_not_extend_known_permanent_block()
    local env = make_env({
        map_id = 0x08,
        permanent_blocked_cells = {
            [0x08] = {["26,27"] = true},
        },
    })
    env.set_position(27, 27)

    env.set_joy({left = true})
    env.update(true)
    env.set_joy({})
    env.update(true)

    for _ = 1, 8 do
        env.update(true)
    end

    assert_truthy(
        not env.auto_step.is_auto_active(),
        "manual tap-to-step should not auto-hold into a known permanent block"
    )
    for frame, buttons in pairs(env.injected) do
        assert_truthy(
            not has_any_direction(buttons),
            string.format("known permanent block should not inject D-pad input at frame %d", frame)
        )
    end

    env.restore()
end

function tests.inject_step_still_tests_known_directional_wall()
    local env = make_env({
        map_id = 0x08,
        directional_blocks = {
            [0x08] = {["26,28"] = {east = true}},
        },
    })
    env.set_position(27, 28)

    local accepted = env.auto_step.inject_step("left")

    assert_truthy(accepted, "debug/probe injection should still be able to test known directional walls")
    assert_truthy(env.auto_step.is_auto_active(), "debug/probe injection should still start an active step")

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
            auto_step_route_early_release_grace_frames = "0",
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

function tests.manual_tap_collision_uses_manual_retry_limit()
    local env = make_env({
        config_values = {
            auto_step_timeout = "4",
            auto_step_block_retry_limit = "1",
            auto_step_manual_block_retry_limit = "0",
            auto_step_turn_repress_delay = "30",
        },
    })

    env.set_joy({right = true})
    env.update(true)
    env.set_joy({})
    env.update(true)
    for _ = 1, 10 do
        env.update(true)
    end

    local blocked_payload = nil
    for _, event in ipairs(env.published) do
        if event.name == "route_blocked" then
            blocked_payload = event.payload
            break
        end
    end

    assert_truthy(blocked_payload ~= nil, "manual wall bump should still report a blocked step")
    assert_truthy(blocked_payload.timeout_retries == 0, "manual wall bump should not pay the route/probe retry window")
    assert_truthy(blocked_payload.source == "manual_tap", "manual wall bump should be tagged as a player tap")
    assert_truthy(blocked_payload.queued_route == false, "manual wall bump should not look like a queued route")

    env.restore()
end

function tests.inject_step_collision_keeps_configured_retry_limit()
    local env = make_env({
        config_values = {
            auto_step_timeout = "4",
            auto_step_block_retry_limit = "1",
            auto_step_manual_block_retry_limit = "0",
            auto_step_turn_repress_delay = "30",
        },
    })

    env.auto_step.inject_step("right")
    for _ = 1, 12 do
        env.update(true)
    end

    local blocked_payload = nil
    for _, event in ipairs(env.published) do
        if event.name == "route_blocked" then
            blocked_payload = event.payload
            break
        end
    end

    assert_truthy(blocked_payload ~= nil, "probe/debug injected collision should still report a blocked step")
    assert_truthy(blocked_payload.timeout_retries == 1, "probe/debug injected collision should keep the configured retry")
    assert_truthy(blocked_payload.source == "inject_step", "probe/debug injected collision should keep its source tag")
    assert_truthy(blocked_payload.queued_route == false, "inject_step collision should remain separate from queued routes")

    env.restore()
end

function tests.queued_route_timeout_retry_does_not_hold_early_twitch()
    local env = make_env({
        sticky_joypad_set = true,
        config_values = {
            auto_step_timeout = "4",
            auto_step_block_retry_limit = "1",
            auto_step_release_on_movement_start = "true",
            auto_step_route_early_release_grace_frames = "6",
        },
    })
    env.auto_step.start_route({"right"})

    env.update(true)
    env.update(true)
    env.update(true)
    env.update(true)
    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)

    assert_truthy(
        env.injected[6] and not has_any_direction(env.injected[6]),
        "queued-route timeout retries should release after immediate subpixel twitches to avoid extra-tile drift"
    )

    env.restore()
end

function tests.manual_early_subpixel_twitch_keeps_holding_input()
    local env = make_env({
        sticky_joypad_set = true,
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_route_early_release_grace_frames = "10",
        },
    })
    env.auto_step.inject_step("right")

    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)

    assert_truthy(
        env.injected[2] and env.injected[2].right,
        "manual/probe early subpixel twitches should keep the D-pad held instead of creating a fake blocked step"
    )

    env.restore()
end

function tests.seam_retry_late_subpixel_twitch_keeps_holding_input()
    local env = make_env({
        sticky_joypad_set = true,
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_route_early_release_grace_frames = "10",
        },
    })
    env.auto_step.inject_step("right", {
        source = "seam_retry",
        hold_after_movement_start = true,
    })

    for _ = 1, 14 do
        env.update(true)
    end
    env.set_subpixel(0x20)
    env.update(true)
    env.update(true)

    assert_truthy(
        env.injected[15] and env.injected[15].right,
        "seam retry should keep holding when movement starts after the normal early-twitch grace window"
    )
    assert_truthy(
        env.injected[16] and env.injected[16].right,
        "seam retry should continue holding on the frame after a late twitch"
    )

    env.restore()
end

function tests.seam_retry_bounded_hold_releases_before_tile_completion()
    local env = make_env({
        sticky_joypad_set = true,
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_route_early_release_grace_frames = "10",
        },
    })
    env.auto_step.inject_step("right", {
        source = "seam_retry",
        hold_after_movement_start = true,
        hold_after_movement_start_frames = 4,
    })

    env.update(true)
    env.set_subpixel(0x20)
    for _ = 1, 8 do
        env.update(true)
    end

    assert_truthy(
        env.injected[6] and env.injected[6].right,
        "seam retry should hold through the configured post-movement-start window"
    )
    assert_truthy(
        env.injected[7] and not has_any_direction(env.injected[7]),
        "seam retry should release before tile completion once the bounded hold expires"
    )

    env.restore()
end

function tests.physical_manual_early_subpixel_twitch_releases_after_tap()
    local env = make_env({
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_route_early_release_grace_frames = "10",
            auto_step_manual_early_hold_frames = "6",
        },
    })

    env.set_joy({right = true})
    env.update(true)
    env.set_joy({})
    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)

    assert_truthy(
        env.injected[3] and env.injected[3].right,
        "physical manual taps should briefly hold after an early subpixel twitch so open-floor taps can commit"
    )

    for _ = 1, 25 do
        env.update(true)
    end
    local sequences = collect_direction_sequences(env, "right", 35)
    assert_truthy(
        #sequences == 1,
        "physical manual taps should not re-press after the short early-twitch hold"
    )
    assert_truthy(
        sequences[1].count < 20,
        "physical manual early-twitch hold should stay short enough to avoid long wall/NPC pressure"
    )

    env.restore()
end

function tests.physical_manual_early_subpixel_twitch_silently_cancels_before_blocked_timeout()
    local env = make_env({
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_route_early_release_grace_frames = "10",
        },
    })

    env.set_joy({right = true})
    env.update(true)
    env.set_joy({})
    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)

    for _ = 1, 45 do
        env.update(true)
    end

    for _, event in ipairs(env.published) do
        assert_truthy(
            event.name ~= "route_blocked",
            "released physical wall bumps should not publish blocked seam events after early twitch cancellation"
        )
    end
    assert_truthy(
        not env.auto_step.is_auto_active(),
        "released physical wall bump should be inactive after early twitch cancellation"
    )

    env.restore()
end

function tests.movement_start_subpixel_releases_injected_direction_when_grace_disabled()
    local env = make_env({
        sticky_joypad_set = true,
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_route_early_release_grace_frames = "0",
        },
    })
    env.auto_step.inject_step("right")

    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)

    assert_truthy(
        env.injected[2] and not has_any_direction(env.injected[2]),
        "auto_step should still release D-pad on movement start when the early-grace hold is disabled"
    )

    env.restore()
end

function tests.physical_manual_early_subpixel_twitch_accepts_late_tile_completion_after_release()
    local env = make_env({
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_route_early_release_grace_frames = "10",
        },
    })

    env.set_joy({right = true})
    env.update(true)
    env.set_joy({})
    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)

    for _ = 1, 14 do
        env.update(true)
    end

    env.set_position(4, 1)
    env.update(true)

    local saw_completion = false
    for _, event in ipairs(env.published) do
        local payload = event.payload or {}
        if event.name == "route_step_completed"
           and payload.queued_route == false
           and payload.from_x == 3
           and payload.from_y == 1
           and payload.to_x == 4
           and payload.to_y == 1
           and payload.dir == "right" then
            saw_completion = true
        end
        assert_truthy(
            event.name ~= "route_blocked",
            "late physical manual completion after release should not be reported as a blocked seam"
        )
    end

    assert_truthy(saw_completion, "physical manual tap should still accept late tile completion after releasing the synthetic hold")

    env.restore()
end

function tests.manual_early_subpixel_twitch_accepts_late_tile_completion()
    local env = make_env({
        sticky_joypad_set = true,
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_route_early_release_grace_frames = "10",
        },
    })
    env.auto_step.inject_step("right")

    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)

    for _ = 1, 14 do
        env.update(true)
    end

    env.set_position(4, 1)
    env.update(true)

    local saw_completion = false
    for _, event in ipairs(env.published) do
        local payload = event.payload or {}
        if event.name == "route_step_completed"
           and payload.queued_route == false
           and payload.from_x == 3
           and payload.from_y == 1
           and payload.to_x == 4
           and payload.to_y == 1
           and payload.dir == "right" then
            saw_completion = true
        end
        assert_truthy(
            event.name ~= "route_blocked",
            "late completion after an early manual twitch should not be reported as a blocked seam"
        )
    end

    local right_sequences = collect_direction_sequences(env, "right", 25)
    assert_truthy(#right_sequences == 1, "early manual twitches should not schedule a same-direction turn re-press")
    assert_truthy(saw_completion, "manual/probe step should accept late tile completion after an early movement twitch")

    env.restore()
end

function tests.inject_step_retry_after_movement_twitch_does_not_turn_repress()
    local env = make_env({
        sticky_joypad_set = true,
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_timeout = "6",
            auto_step_block_retry_limit = "1",
            auto_step_route_early_release_grace_frames = "10",
            auto_step_turn_repress_delay = "3",
            auto_step_turn_repress_limit = "1",
        },
    })
    env.auto_step.inject_step("right")

    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)

    for _ = 1, 6 do
        env.update(true)
    end

    env.set_subpixel(0x30)
    env.update(true)

    for _ = 1, 8 do
        env.update(true)
    end

    local right_sequences = collect_direction_sequences(env, "right", 30)
    assert_truthy(
        #right_sequences <= 2,
        "debug/probe inject_step should not add a turn re-press after a retry already saw movement start"
    )

    env.restore()
end

function tests.queued_route_early_subpixel_twitch_keeps_holding_input()
    local env = make_env({
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_route_early_release_grace_frames = "10",
        },
    })
    env.auto_step.start_route({"right"})

    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)

    assert_truthy(
        env.injected[2] and env.injected[2].right,
        "queued-route early subpixel twitches should keep the D-pad held instead of creating a fake blocked step"
    )

    env.restore()
end

function tests.queued_route_early_subpixel_twitch_releases_before_turn()
    local env = make_env({
        sticky_joypad_set = true,
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_route_early_release_grace_frames = "10",
            auto_step_turn_repress_delay = "3",
        },
    })
    env.auto_step.start_route({"right", "down"})

    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)

    assert_truthy(
        env.injected[2] and not has_any_direction(env.injected[2]),
        "queued route should release early movement twitches when the next step turns"
    )

    for _ = 1, 12 do
        env.update(true)
    end

    local right_sequences = collect_direction_sequences(env, "right", 20)
    assert_truthy(
        #right_sequences == 1,
        "queued route should not re-press the old direction before a turn after an early twitch"
    )

    env.restore()
end

function tests.queued_route_uses_shorter_inject_on_continuing_step_before_turn()
    local env = make_env({
        config_values = {
            auto_step_inject_limit = "12",
            auto_step_route_pre_turn_inject_limit = "7",
        },
    })

    env.auto_step.start_route({"right", "right", "down"})
    env.update(true)
    env.set_position(4, 1)
    env.update(true)

    for _ = 1, 5 do
        env.update(true)
    end

    local state = env.auto_step.get_active_step_state()
    assert_truthy(
        state and state.dir == "right" and state.inject_limit == 7,
        "last continuing queued step before a turn should use the shorter pre-turn inject limit"
    )

    env.restore()
end

function tests.queued_route_early_twitch_reports_short_timing_block_without_repress()
    local env = make_env({
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_timeout = "60",
            auto_step_block_retry_limit = "1",
            auto_step_route_early_release_grace_frames = "10",
            auto_step_route_turn_repress_timeout_frames = "12",
            auto_step_inject_limit = "3",
            auto_step_turn_repress_delay = "3",
            auto_step_turn_repress_release_frames = "1",
        },
    })
    env.auto_step.start_route({"right"})

    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)

    for _ = 1, 5 do
        env.update(true)
    end

    env.set_subpixel(0x30)
    env.update(true)

    for _ = 1, 50 do
        env.update(true)
    end

    local blocked_event
    for _, event in ipairs(env.published) do
        if event.name == "route_blocked" then
            blocked_event = event
            break
        end
    end

    assert_truthy(
        blocked_event and blocked_event.frame < 45,
        "queued-route early movement twitches should report to the route manager before the full wall timeout"
    )
    assert_truthy(
        blocked_event.payload and blocked_event.payload.movement_started == true,
        "short route timeout reports should preserve movement-start metadata for the route manager timing retry"
    )
    assert_truthy(
        blocked_event.payload and blocked_event.payload.timing_suspect == true,
        "short route timeout reports should be marked as timing-suspect survey noise"
    )

    local right_sequences = collect_direction_sequences(env, "right", 35)
    assert_truthy(
        #right_sequences == 1,
        "queued-route early movement twitches should not schedule a same-direction turn re-press that can commit an extra tile"
    )

    env.restore()
end

function tests.queued_route_early_twitch_waits_for_late_tile_completion()
    local env = make_env({
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_timeout = "60",
            auto_step_block_retry_limit = "1",
            auto_step_route_early_release_grace_frames = "10",
            auto_step_route_early_twitch_timeout_frames = "32",
            auto_step_route_turn_repress_timeout_frames = "24",
            auto_step_inject_limit = "3",
            auto_step_turn_repress_delay = "3",
            auto_step_turn_repress_release_frames = "1",
        },
    })
    env.auto_step.start_route({"right", "up"})

    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)

    for _ = 1, 23 do
        env.update(true)
    end

    for _, event in ipairs(env.published) do
        assert_truthy(
            event.name ~= "route_blocked",
            "early queued-route twitches should wait past the direct-retry timeout when the tile may still complete"
        )
    end

    env.set_position(4, 1)
    env.update(true)

    local saw_completion = false
    for _, event in ipairs(env.published) do
        local payload = event.payload or {}
        if event.name == "route_step_completed"
           and payload.queued_route == true
           and payload.from_x == 3
           and payload.from_y == 1
           and payload.to_x == 4
           and payload.to_y == 1
           and payload.dir == "right" then
            saw_completion = true
        end
        assert_truthy(
            event.name ~= "route_blocked",
            "late tile completion should finish the queued route step instead of starting a seam retry"
        )
    end
    assert_truthy(
        saw_completion,
        "queued route should accept late completion after an early movement twitch"
    )

    env.restore()
end

function tests.queued_route_turn_repress_timing_timeout_counts_after_movement_start()
    local env = make_env({
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_timeout = "60",
            auto_step_block_retry_limit = "1",
            auto_step_route_early_release_grace_frames = "10",
            auto_step_route_turn_repress_timeout_frames = "12",
            auto_step_inject_limit = "3",
            auto_step_turn_repress_delay = "3",
            auto_step_turn_repress_release_frames = "1",
        },
    })
    env.auto_step.start_route({"right", "up"})

    local saw_repress = false
    for _ = 1, 20 do
        env.update(true)
        local state = env.auto_step.get_active_step_state()
        if state and (state.turn_represses or 0) > 0 then
            saw_repress = true
            break
        end
    end
    assert_truthy(saw_repress, "test setup should reach a turn re-press step")

    for _ = 1, 8 do
        env.update(true)
    end
    env.set_subpixel(0x20)
    env.update(true)

    for _ = 1, 6 do
        env.update(true)
    end

    for _, event in ipairs(env.published) do
        assert_truthy(
            event.name ~= "route_blocked",
            "turn re-press movement twitches should not time out from the original press frame"
        )
    end

    env.set_position(4, 1)
    env.update(true)

    local saw_completion = false
    for _, event in ipairs(env.published) do
        local payload = event.payload or {}
        if event.name == "route_step_completed"
           and payload.queued_route == true
           and payload.from_x == 3
           and payload.from_y == 1
           and payload.to_x == 4
           and payload.to_y == 1
           and payload.dir == "right" then
            saw_completion = true
        end
    end
    assert_truthy(
        saw_completion,
        "queued route should accept late completion after a turn re-press movement twitch"
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

function tests.cancel_active_step_can_force_release_injected_validation_input()
    local env = make_env({sticky_joypad_set = true})
    env.auto_step.inject_step("right")

    env.update(true)
    env.auto_step.cancel_active_step(false, true)

    assert_truthy(
        env.injected[1] and not has_any_direction(env.injected[1]),
        "forced cancel should immediately neutralize injected validation input"
    )

    env.update(true)
    assert_truthy(
        env.injected[2] and not has_any_direction(env.injected[2]),
        "forced cancel should keep post-step release neutral on the next frame"
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
        repress and repress.count >= 20,
        "turn re-press should keep holding after a turn-only attempt so the follow-up press can start movement reliably"
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

function tests.early_subpixel_twitch_does_not_schedule_turn_repress_before_timeout()
    local env = make_env({
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_route_early_release_grace_frames = "10",
        },
    })
    env.auto_step.inject_step("right")

    env.update(true)
    env.set_subpixel(0x20)
    for _ = 1, 35 do
        env.update(true)
    end

    local sequences = collect_direction_sequences(env, "right", 40)
    local repressed_before_timeout = false
    for _, sequence in ipairs(sequences) do
        if sequence.start > 18 then
            repressed_before_timeout = true
            break
        end
    end

    assert_truthy(
        not repressed_before_timeout,
        "early subpixel twitches should not trigger a same-direction turn re-press before timeout"
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

function tests.inject_step_success_force_releases_sticky_direction_after_completion()
    local env = make_env({sticky_joypad_set = true})
    env.auto_step.inject_step("right")

    for _ = 1, 6 do
        env.update(true)
    end

    env.set_position(4, 1)
    env.update(true)

    for _ = 1, 4 do
        env.update(true)
    end

    assert_truthy(
        env.injected[8] and not has_any_direction(env.injected[8]),
        "debug/probe injected steps should force a neutral frame even if the emulator still reports the old direction"
    )
    assert_truthy(
        env.injected[9] and not has_any_direction(env.injected[9]),
        "debug/probe injected steps should keep neutral long enough to prevent post-arrival overshoot"
    )

    env.restore()
end

function tests.seam_retry_success_force_releases_sticky_direction_after_completion()
    local env = make_env({sticky_joypad_set = true})
    env.auto_step.inject_step("right", {
        source = "seam_retry",
        hold_after_movement_start = true,
    })

    for _ = 1, 6 do
        env.update(true)
    end

    env.set_position(4, 1)
    env.update(true)

    for _ = 1, 4 do
        env.update(true)
    end

    assert_truthy(
        env.injected[8] and not has_any_direction(env.injected[8]),
        "seam retries should force a neutral frame even if the emulator still reports the old direction"
    )
    assert_truthy(
        env.injected[9] and not has_any_direction(env.injected[9]),
        "seam retries should keep neutral long enough to prevent post-arrival overshoot"
    )

    env.restore()
end

function tests.seam_retry_success_resets_movement_state_after_completion()
    local env = make_env({
        movement_state = 0xE0,
        movement_subpixel = 0x90,
    })
    env.auto_step.inject_step("right", {
        source = "seam_retry",
        hold_after_movement_start = true,
    })

    for _ = 1, 6 do
        env.update(true)
    end

    env.set_position(4, 1)
    env.update(true)

    assert_truthy(
        env.memory_writes[1]
            and env.memory_writes[1].address == 0x003C
            and env.memory_writes[1].value == 0x00,
        "seam retry completion should clear movement state before follow-up planning"
    )
    assert_truthy(
        env.memory_writes[2]
            and env.memory_writes[2].address == 0x003D
            and env.memory_writes[2].value == 0x00,
        "seam retry completion should clear movement subpixel before follow-up planning"
    )

    env.restore()
end

function tests.inject_step_completion_preserves_original_input_source()
    local env = make_env()
    env.auto_step.inject_step("right", {source = "seam_retry"})

    env.update(true)
    env.set_position(4, 1)
    env.update(true)

    local completed_payload = nil
    for _, event in ipairs(env.published) do
        if event.name == "route_step_completed" then
            completed_payload = event.payload
            break
        end
    end

    assert_truthy(completed_payload ~= nil, "successful injected steps should publish completion")
    assert_truthy(completed_payload.source == "auto_hold", "completion should keep the existing auto-hold source label")
    assert_truthy(
        completed_payload.input_source == "seam_retry",
        "completion should preserve the original injected source for route-manager follow-up planning"
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

function tests.turn_repress_retry_keeps_holding_instead_of_chattering()
    local env = make_env()
    env.auto_step.inject_step("right")

    for _ = 1, 140 do
        env.update(true)
    end

    local sequences = collect_direction_sequences(env, "right", 140)
    local repress = sequences[2]

    assert_truthy(
        repress and repress.count >= 60 and sequences[3] == nil,
        "turn re-press retry should keep holding rather than chattering through short repeated press windows"
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

function tests.queued_routes_honor_initial_settle_before_first_step()
    local env = make_env()
    env.auto_step.start_route({"right"}, {initial_settle_frames = 5})

    for _ = 1, 5 do
        env.update(true)
    end

    for frame = 1, 5 do
        assert_truthy(
            not has_any_direction(env.injected[frame]),
            "queued route should stay neutral during the initial settle window"
        )
    end

    env.update(true)

    assert_truthy(
        env.injected[6] and env.injected[6].right,
        "queued route should start the first step after the initial settle window"
    )

    env.restore()
end

function tests.queued_routes_consume_matching_drift_during_initial_settle()
    local env = make_env()
    env.auto_step.start_route({"right", "down"}, {
        initial_settle_frames = 5,
        start_x = 3,
        start_y = 1,
    })

    env.set_position(4, 1)
    env.update(true)

    local saw_catchup = false
    for _, event in ipairs(env.published) do
        local payload = event.payload or {}
        if event.name == "route_step_completed"
           and payload.source == "route_settle_catchup"
           and payload.from_x == 3
           and payload.from_y == 1
           and payload.to_x == 4
           and payload.to_y == 1
           and payload.dir == "right" then
            saw_catchup = true
            break
        end
    end
    assert_truthy(
        saw_catchup,
        "queued route should consume drift that matches the first planned step during initial settle"
    )

    for frame = 1, 5 do
        local buttons = env.injected[frame]
        assert_truthy(
            not (buttons and buttons.right),
            "queued route should not re-press a first step consumed during initial settle"
        )
    end

    env.restore()
end

function tests.queued_routes_cancel_unmatched_drift_during_initial_settle()
    local env = make_env()
    env.auto_step.start_route({"right"}, {
        initial_settle_frames = 5,
        start_x = 3,
        start_y = 1,
    })

    env.set_position(3, 2)
    env.update(true)

    local saw_cancel = false
    for _, event in ipairs(env.published) do
        local payload = event.payload or {}
        if event.name == "route_cancelled"
           and payload.reason == "route_drift_off_path"
           and payload.from_x == 3
           and payload.from_y == 1
           and payload.current_x == 3
           and payload.current_y == 2
           and payload.source == "route_settle_catchup" then
            saw_cancel = true
            break
        end
    end
    assert_truthy(
        saw_cancel,
        "queued route should cancel when initial-settle drift does not match the planned path"
    )

    env.update(true)
    assert_truthy(
        not (env.injected[2] and env.injected[2].right),
        "queued route should not continue after unmatched initial-settle drift"
    )

    env.restore()
end

function tests.queued_routes_can_skip_configured_settle_on_straight_segments()
    local env = make_env()
    env.auto_step.start_route({"right", "right"}, {
        settle_frames = 8,
        settle_same_direction = false,
    })

    env.update(true)
    env.set_position(4, 1)
    env.update(true)

    for _ = 1, 8 do
        env.update(true)
    end

    local saw_second_step_before_full_settle = false
    for frame = 5, 10 do
        local buttons = env.injected[frame]
        if buttons and buttons.right then
            saw_second_step_before_full_settle = true
            break
        end
    end

    assert_truthy(
        saw_second_step_before_full_settle,
        "queued route should be able to skip configured settle frames between straight same-direction steps"
    )

    env.restore()
end

function tests.queued_routes_still_settle_on_direction_change_when_straight_settle_disabled()
    local env = make_env({
        config_values = {
            auto_step_route_turn_settle_frames = "0",
        },
    })
    env.auto_step.start_route({"right", "down"}, {
        settle_frames = 8,
        settle_same_direction = false,
    })

    env.update(true)
    env.set_position(4, 1)
    env.update(true)

    for _ = 1, 8 do
        env.update(true)
    end

    for frame = 3, 10 do
        local buttons = env.injected[frame]
        assert_truthy(
            not (buttons and buttons.down),
            "queued route should still wait before changing direction when straight settle is disabled"
        )
    end

    local saw_down = false
    for _ = 1, 10 do
        env.update(true)
    end
    for frame = 11, 20 do
        local buttons = env.injected[frame]
        if buttons and buttons.down then
            saw_down = true
            break
        end
    end

    assert_truthy(
        saw_down,
        "queued route should resume after the configured turn settle when straight settle is disabled"
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

function tests.queued_route_final_step_neutralizes_before_route_complete()
    local env = make_env({
        sticky_joypad_set = true,
        config_values = {
            auto_step_route_final_settle_frames = "5",
        },
    })
    env.auto_step.start_route({"right"})

    env.update(true)
    env.set_position(4, 1)
    env.update(true)

    for _ = 1, 4 do
        env.update(true)
    end

    for frame = 3, 6 do
        assert_truthy(
            env.injected[frame] and not has_any_direction(env.injected[frame]),
            "queued route final settle should actively neutralize the D-pad before completion"
        )
    end

    for _, event in ipairs(env.published) do
        assert_truthy(
            event.name ~= "route_completed",
            "queued route should not publish completion during final neutral settle"
        )
    end

    for _ = 1, 8 do
        env.update(true)
    end

    local complete_frame = nil
    for _, event in ipairs(env.published) do
        if event.name == "route_completed" then
            complete_frame = event.frame
            break
        end
    end
    assert_truthy(
        complete_frame ~= nil and complete_frame >= 9,
        "queued route completion should wait until after the final neutral settle"
    )

    env.restore()
end

function tests.queued_route_final_step_resets_movement_state()
    local env = make_env({
        movement_state = 0x05,
        movement_subpixel = 0x20,
        config_values = {
            auto_step_route_final_settle_frames = "5",
        },
    })
    env.auto_step.start_route({"right"})

    env.update(true)
    env.set_position(4, 1)
    env.update(true)

    local cleared_move = false
    local cleared_subpixel = false
    for _, write in ipairs(env.memory_writes) do
        if write.address == 0x003C and write.value == 0x00 then
            cleared_move = true
        elseif write.address == 0x003D and write.value == 0x00 then
            cleared_subpixel = true
        end
    end

    assert_truthy(
        cleared_move and cleared_subpixel,
        "queued route final step should clear movement engine state before waiting on completion"
    )

    env.restore()
end

function tests.queued_route_final_settle_keeps_resetting_movement_state()
    local env = make_env({
        movement_state = 0x05,
        movement_subpixel = 0x20,
        config_values = {
            auto_step_route_final_settle_frames = "5",
        },
    })
    env.auto_step.start_route({"right"})

    env.update(true)
    env.set_position(4, 1)
    env.update(true)

    local writes_after_completion = #env.memory_writes
    env.set_movement_state(0x06)
    env.set_subpixel(0x40)
    env.update(true)

    local cleared_again = false
    for i = writes_after_completion + 1, #env.memory_writes do
        local write = env.memory_writes[i]
        if write.address == 0x003C and write.value == 0x00 then
            cleared_again = true
            break
        end
    end

    assert_truthy(
        cleared_again,
        "queued route final settle should keep clearing movement state if the engine re-arms it"
    )

    env.restore()
end

function tests.queued_route_final_settle_skips_movement_reset_when_disabled()
    local env = make_env({
        movement_state = 0x05,
        movement_subpixel = 0x20,
        config_values = {
            auto_step_route_final_settle_frames = "5",
            auto_step_reset_movement_on_route_turn_settle = "false",
        },
    })
    env.auto_step.start_route({"right"})

    env.update(true)
    env.set_position(4, 1)
    env.update(true)

    local cleared_on_completion = false
    for _, write in ipairs(env.memory_writes) do
        if (write.address == 0x003C or write.address == 0x003D)
           and write.value == 0x00 then
            cleared_on_completion = true
            break
        end
    end

    assert_truthy(
        not cleared_on_completion,
        "queued route final settle should not clear movement engine state when the reset toggle is disabled"
    )

    local writes_after_completion = #env.memory_writes
    env.set_movement_state(0x06)
    env.set_subpixel(0x40)
    env.update(true)

    local cleared_during_settle = false
    for i = writes_after_completion + 1, #env.memory_writes do
        local write = env.memory_writes[i]
        if (write.address == 0x003C or write.address == 0x003D)
           and write.value == 0x00 then
            cleared_during_settle = true
            break
        end
    end

    assert_truthy(
        not cleared_during_settle,
        "queued route final settle should not keep clearing movement state when the reset toggle is disabled"
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

function tests.queued_route_turn_settle_resets_movement_state()
    local env = make_env({
        movement_state = 0x40,
        movement_subpixel = 0x90,
    })
    env.auto_step.start_route({"right", "up"})

    env.update(true)
    env.set_position(4, 1)
    env.update(true)

    local cleared_move = false
    local cleared_subpixel = false
    for _, write in ipairs(env.memory_writes) do
        if write.address == 0x003C and write.value == 0x00 then
            cleared_move = true
        elseif write.address == 0x003D and write.value == 0x00 then
            cleared_subpixel = true
        end
    end

    assert_truthy(
        cleared_move and cleared_subpixel,
        "queued route turn settle should clear stale movement engine state before changing direction"
    )

    local writes_after_completion = #env.memory_writes
    env.set_movement_state(0x41)
    env.set_subpixel(0x91)
    env.update(true)

    local cleared_again = false
    for i = writes_after_completion + 1, #env.memory_writes do
        local write = env.memory_writes[i]
        if write.address == 0x003C and write.value == 0x00 then
            cleared_again = true
            break
        end
    end

    assert_truthy(
        cleared_again,
        "queued route turn settle should keep clearing movement state during the settle window"
    )

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

function tests.queued_route_completion_must_match_injected_direction()
    local env = make_env()
    env.auto_step.start_route({"right", "down"})

    env.update(true)
    env.set_position(3, 2)
    env.update(true)

    local saw_cancel = false
    for _, event in ipairs(env.published) do
        local payload = event.payload or {}
        if event.name == "route_cancelled"
           and payload.reason == "route_drift_off_path"
           and payload.source == "auto_hold_mismatch"
           and payload.from_x == 3
           and payload.from_y == 1
           and payload.expected_x == 4
           and payload.expected_y == 1
           and payload.current_x == 3
           and payload.current_y == 2 then
            saw_cancel = true
        end
        assert_truthy(
            event.name ~= "route_step_completed",
            "queued route should not publish a completed step when the landed tile does not match the injected direction"
        )
    end
    assert_truthy(
        saw_cancel,
        "queued route should cancel when the engine moves a different direction than the injected route step"
    )

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
