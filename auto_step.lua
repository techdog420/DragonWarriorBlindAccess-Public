-- auto_step.lua
-- Tap-to-step: extends brief D-pad taps into full tile steps.
--
-- Dragon Warrior requires the D-pad to be held for ~16-30 frames
-- (~0.25-0.5 seconds) to complete one tile of movement. A quick tap
-- just turns the character without stepping. This module detects
-- quick taps and automatically holds the direction until the player's
-- tile position changes (or a timeout is reached, meaning the player
-- is blocked by a wall).
--
-- How it works:
--   1. Each frame, read joypad to detect direction presses
--   2. When a direction is first pressed, record the player's tile position
--   3. When the direction is released:
--      - If position changed during the press: natural step, do nothing
--      - If position didn't change: start auto-holding that direction
--   4. Auto-hold injects the direction via joypad.set() each frame
--   5. Auto-hold stops when:
--      - Player's tile position changes (step completed)
--      - Timeout reached (blocked by wall/obstacle)
--      - Player presses any new direction (cancel)
--   6. After a successful step, a short cooldown prevents double-stepping

local nav         = require "navigation"
local config      = require "config"
local tolk        = require "tolk"
local debug_tools = require "debug_tools"
local event_bus   = require "event_bus"
local addr_ok, addr = pcall(require, "addresses")
if not addr_ok then
    addr = nil
end
local compat_ok, emulator_compat = pcall(require, "emulator_compat")
if not compat_ok then
    emulator_compat = nil
end
local map_reader_ok, map_reader = pcall(require, "map_reader")
if not map_reader_ok then
    map_reader = nil
end

local M = {}

-- Optional callback: called when a step times out (player was blocked by
-- a wall or moving NPC). Main.lua sets this to trigger automatic re-routing.
-- Signature: M.on_blocked(from_x, from_y, blocked_dir, block_data)
-- TRANSITION: Both this callback AND event_bus "route_blocked" fire.
-- Once all callers migrate to the event bus, this field can be removed.
M.on_blocked = nil

-- Optional callback: called when all queued route steps have been walked
-- (the last step's position change confirmed). Use this to release any
-- state that was set up for the route (e.g., NPC freeze).
-- Signature: M.on_route_complete()
-- TRANSITION: Both this callback AND event_bus "route_completed" fire.
M.on_route_complete = nil

-- Optional callback: called when a queued route is cancelled by auto_step
-- itself (live input, field-state loss, or off-path drift). Route managers can
-- use this to release NPC freeze and clear active destination context.
-- Signature: M.on_route_cancelled(cancel_data)
-- TRANSITION: Both this callback AND event_bus "route_cancelled" fire.
M.on_route_cancelled = nil

-- Optional callback: called when an injected/auto-held step completes and the
-- player reaches a new tile. Useful for runtime seam tracking and route repair
-- after a manual one-step brute-force retry.
-- Signature: M.on_step_complete(from_x, from_y, dir, to_x, to_y, step_data)
-- TRANSITION: Both this callback AND event_bus "route_step_completed" fire.
M.on_step_complete = nil

-- Debug flag: set to true to hear speech for every auto-step event.
local DEBUG = false

-- ============================================================
-- Direction Constants
-- ============================================================
-- The four cardinal directions, named to match FCEUX joypad fields.
-- FCEUX's joypad.read() and joypad.set() use these exact string keys.
local DIRECTIONS = {"up", "down", "left", "right"}

-- ============================================================
-- State Tracking
-- ============================================================

-- Per-direction tracking: was each direction held last frame?
-- We need this to detect the exact frame a direction is pressed or released.
local prev_held = {up = false, down = false, left = false, right = false}

-- Position when a direction was first pressed.
-- If the position hasn't changed by the time the direction is released,
-- we know the tap was too short to complete a step.
local press_start_x = nil
local press_start_y = nil

-- Which direction (if any) we started tracking on press.
-- Only one direction is tracked at a time (the most recent press).
local tracked_dir = nil

-- Auto-hold state: when active, we inject this direction each frame
local auto_dir = nil       -- Direction string ("up", "down", etc.) or nil
local auto_frames = 0      -- How many frames we've been auto-holding
local auto_start_x = nil   -- Position when auto-hold started
local auto_start_y = nil
local auto_timeout_retries = 0
local auto_turn_represses = 0
local auto_inject_limit = nil
local auto_start_subpixel = nil
local auto_movement_started = false
local auto_movement_start_frame = nil
local auto_step_source = nil
local pending_repress = nil
local route_steps = nil    -- Array of queued directions for auto-walk
local route_index = 1
local route_settle_frames = 0
local route_settle_default = 0
local route_settle_same_direction = true
local route_last_x = nil
local route_last_y = nil
local post_step_release_frames = 0
local suppress_direction_tracking_frames = 0

-- Cooldown: after a successful auto-step, wait a few frames before
-- allowing another one. This prevents accidental double-steps when
-- the player taps quickly.
local cooldown = 0
local COOLDOWN_FRAMES = 4  -- ~67ms at 60fps
local POST_STEP_RELEASE_FRAMES = 2

-- Injection limit: how many frames to actually inject the direction.
-- We only need to hold long enough for the game to commit to the step
-- (get through the turn animation and start walking). After that, the
-- game completes the step on its own. If we inject for the entire step
-- duration, the game starts a SECOND step because it sees the direction
-- still held when step 1 finishes.
--
-- DW1 turn animation: ~8 frames. Step initiation: a few more frames.
-- 12 frames should be plenty to get through turn + start of step.
local INJECT_LIMIT = 12

-- If the player has not moved shortly after the initial inject window,
-- assume the game consumed that press as a turn-in-place. DW1 often
-- requires a fresh press after turning before movement begins.
--
-- Re-arm promptly after a turn-only attempt so open steps do not stall waiting
-- for the full timeout. The release gap below must actively neutralize the
-- D-pad before this re-press, otherwise the engine can treat the sequence as
-- one continuous hold and chain into an unwanted second tile.
local TURN_REPRESS_DELAY = 18
local TURN_REPRESS_LIMIT = 1
-- After a turn-only attempt, the follow-up press still needs a normal
-- hold window on live hardware. A short 4-frame re-press left survey/
-- probe routes stuck at open floor like map 0x04 (11,11)->left, while a
-- full re-hold after the turn completed the step cleanly.
local TURN_REPRESS_INJECT_LIMIT = INJECT_LIMIT
-- After deciding the first press was only a turn, leave the D-pad fully
-- released for a couple of frames before re-pressing. This reduces the risk
-- that the engine treats the re-press as a continuation of the old hold and
-- chains into a second tile of movement.
local TURN_REPRESS_RELEASE_FRAMES = 2
local ROUTE_DRIFT_CATCHUP_LIMIT = 3
-- Tile coordinates can update before the walking animation and old D-pad
-- state have fully settled. Queued auto-walk can chain straight segments
-- immediately, but direction changes need a short pause or the engine may
-- continue the previous direction for one more cell.
local ROUTE_TURN_SETTLE_FRAMES = 16
-- BizHawk's movement subpixel byte can twitch while the engine is only
-- settling/turning. For queued routes, keep holding through very early twitches
-- instead of treating them as confirmed walking movement.
local ROUTE_EARLY_RELEASE_GRACE_FRAMES = 10
-- Physical tap-to-step needs a little more help on open floor after an early
-- subpixel twitch, but not the long hold used by probes/routes. Keep this
-- short so released wall/NPC bumps still stop quickly.
local MANUAL_EARLY_HOLD_FRAMES = 8
-- If a queued route already needed a turn re-press and only sees another early
-- subpixel twitch, retry sooner than the normal wall timeout.
local ROUTE_TURN_REPRESS_TIMEOUT_FRAMES = 24
-- Early queued-route twitches may be real movement that just has not reached
-- the next tile yet. Give them enough time to finish before route_manager
-- tries a direct seam retry, which can otherwise re-press into a tile boundary.
local ROUTE_EARLY_TWITCH_TIMEOUT_FRAMES = 32

-- Before reporting a blocked move, allow a few internal retries of the same
-- step from the same tile/direction. Live probing on Map 0x04 showed that
-- long multi-turn routes can still hit rare triple-miss timing noise even
-- when the destination edge is genuinely passable, so keep one extra retry
-- before promoting the move into runtime-block evidence.
local BLOCK_RETRY_LIMIT = 3

local function config_int(key, fallback, min_value, max_value)
    local value = tonumber(config.get(key))
    if not value then
        return fallback
    end
    value = math.floor(value)
    if min_value and value < min_value then
        return min_value
    end
    if max_value and value > max_value then
        return max_value
    end
    return value
end

local function config_bool(key, fallback)
    local value = config.get(key)
    if value == nil then
        return fallback
    end
    value = tostring(value):lower()
    if value == "true" or value == "1" or value == "yes" or value == "on" then
        return true
    end
    if value == "false" or value == "0" or value == "no" or value == "off" then
        return false
    end
    return fallback
end

function M.should_record_debug_blocks()
    return config_bool("auto_step_record_debug_blocks", false)
end

local function get_inject_limit()
    return config_int("auto_step_inject_limit", INJECT_LIMIT, 1, 120)
end

local function get_turn_repress_delay()
    return config_int("auto_step_turn_repress_delay", TURN_REPRESS_DELAY, 1, 180)
end

local function get_turn_repress_limit()
    return config_int("auto_step_turn_repress_limit", TURN_REPRESS_LIMIT, 0, 10)
end

local function get_turn_repress_inject_limit()
    return config_int("auto_step_turn_repress_inject_limit", get_inject_limit(), 1, 120)
end

local function get_turn_repress_release_frames()
    return config_int("auto_step_turn_repress_release_frames", TURN_REPRESS_RELEASE_FRAMES, 0, 30)
end

local function get_block_retry_limit()
    return config_int("auto_step_block_retry_limit", BLOCK_RETRY_LIMIT, 0, 10)
end

local function get_manual_block_retry_limit()
    return config_int("auto_step_manual_block_retry_limit", 0, 0, 10)
end

local function get_active_block_retry_limit()
    if auto_step_source == "manual_tap" then
        return get_manual_block_retry_limit()
    end
    return get_block_retry_limit()
end

local function get_route_turn_settle_frames()
    return config_int("auto_step_route_turn_settle_frames", ROUTE_TURN_SETTLE_FRAMES, 0, 60)
end

local function get_route_early_release_grace_frames()
    return config_int("auto_step_route_early_release_grace_frames", ROUTE_EARLY_RELEASE_GRACE_FRAMES, 0, 30)
end

local function get_manual_early_hold_frames()
    return config_int("auto_step_manual_early_hold_frames", MANUAL_EARLY_HOLD_FRAMES, 0, 30)
end

local function get_route_turn_repress_timeout_frames()
    return config_int("auto_step_route_turn_repress_timeout_frames", ROUTE_TURN_REPRESS_TIMEOUT_FRAMES, 1, 120)
end

local function get_route_early_twitch_timeout_frames()
    return config_int("auto_step_route_early_twitch_timeout_frames", ROUTE_EARLY_TWITCH_TIMEOUT_FRAMES, 1, 120)
end

local function should_release_on_movement_start()
    local configured = config.get("auto_step_release_on_movement_start")
    return configured == "true" or configured == "1" or configured == "yes"
end

local function queued_route_turn_after_current_step()
    if route_steps == nil or auto_dir == nil then
        return false
    end
    local next_dir = route_steps[route_index]
    return next_dir ~= nil and next_dir ~= auto_dir
end

local function should_hold_early_movement_start()
    if auto_movement_start_frame == nil then
        return false
    end
    if auto_step_source == "manual_tap" then
        local grace = get_route_early_release_grace_frames()
        local hold_frames = get_manual_early_hold_frames()
        if grace <= 0
           or hold_frames <= 0
           or auto_movement_start_frame > grace then
            return false
        end
        local hold_until = auto_movement_start_frame + hold_frames
        local inject_limit = auto_inject_limit or get_inject_limit()
        if inject_limit and hold_until > inject_limit then
            hold_until = inject_limit
        end
        return auto_frames <= hold_until
    end
    -- Holding through an early twitch is useful on straightaways, but before a
    -- route turn it can commit one extra tile in the old direction.
    if queued_route_turn_after_current_step() then
        return false
    end
    if auto_timeout_retries > 0 then
        return false
    end
    local grace = get_route_early_release_grace_frames()
    return grace > 0 and auto_movement_start_frame <= grace
end

local function is_early_route_movement_twitch()
    if route_steps == nil
       or auto_movement_start_frame == nil
       or auto_timeout_retries > 0 then
        return false
    end
    local grace = get_route_early_release_grace_frames()
    return grace > 0 and auto_movement_start_frame <= grace
end

local function get_route_timing_suspect_timeout_frames()
    if route_steps == nil
       or not auto_movement_started
       or auto_timeout_retries > 0 then
        return nil
    end
    if auto_turn_represses > 0 then
        return get_route_turn_repress_timeout_frames()
    end
    if is_early_route_movement_twitch() then
        return get_route_early_twitch_timeout_frames()
    end
    return nil
end

local function should_use_route_timing_suspect_timeout()
    return get_route_timing_suspect_timeout_frames() ~= nil
end

-- ============================================================
-- Helper Functions
-- ============================================================

-- is_any_direction_pressed(joy): Check if any D-pad direction is held.
-- joy: table from joypad.read(1)
-- Returns true if at least one direction is pressed.
local function is_any_direction_pressed(joy)
    for _, dir in ipairs(DIRECTIONS) do
        if joy[dir] then
            return true
        end
    end
    return false
end

local function copy_non_direction_buttons(joy)
    local buttons = {up = false, down = false, left = false, right = false}
    if joy.A then buttons.A = true end
    if joy.B then buttons.B = true end
    if joy.start then buttons.start = true end
    if joy.select then buttons.select = true end
    return buttons
end

local function neutralize_direction(joy)
    joypad.set(1, copy_non_direction_buttons(joy or {}))
end

local function read_joypad_safe()
    if joypad and joypad.read then
        local ok, joy = pcall(joypad.read, 1)
        if ok and type(joy) == "table" then
            return joy
        end
    end
    return {}
end

local function read_movement_subpixel()
    if not addr or not addr.MOVEMENT_SUBPIXEL or not memory or not memory.readbyte then
        return nil
    end
    local ok, value = pcall(memory.readbyte, addr.MOVEMENT_SUBPIXEL)
    if ok then
        return value
    end
    return nil
end

local function clear_route()
    route_steps = nil
    route_index = 1
    route_settle_frames = 0
    route_settle_default = 0
    route_settle_same_direction = true
    route_last_x = nil
    route_last_y = nil
end

local function start_post_step_release(force)
    post_step_release_frames = force and -POST_STEP_RELEASE_FRAMES or POST_STEP_RELEASE_FRAMES
end

local function begin_step(dir, px, py, state)
    if route_steps and route_last_x == nil and route_last_y == nil then
        route_last_x = px
        route_last_y = py
    end
    auto_dir = dir
    auto_frames = 1
    auto_start_x = px
    auto_start_y = py
    auto_timeout_retries = state and state.timeout_retries or 0
    auto_turn_represses = state and state.turn_represses or 0
    auto_inject_limit = state and state.inject_limit or get_inject_limit()
    auto_start_subpixel = read_movement_subpixel()
    auto_movement_started = false
    auto_movement_start_frame = nil
    auto_step_source = state and state.source or (route_steps and "queued_route" or "manual_tap")
    pending_repress = nil
    tracked_dir = nil
    debug_tools.debug(string.format(
        "auto_step begin_step dir=%s from=(%d,%d) timeout_retries=%d turn_represses=%d inject_limit=%d source=%s",
        tostring(dir), px or -1, py or -1, auto_timeout_retries, auto_turn_represses,
        auto_inject_limit or -1, tostring(auto_step_source)))
    joypad.set(1, {[dir] = true})
end

local function direction_delta(dir)
    if dir == "up" then
        return 0, -1
    elseif dir == "down" then
        return 0, 1
    elseif dir == "left" then
        return -1, 0
    elseif dir == "right" then
        return 1, 0
    end
    return 0, 0
end

local function approach_for_direction(dir)
    if dir == "up" then
        return "south"
    elseif dir == "down" then
        return "north"
    elseif dir == "left" then
        return "east"
    elseif dir == "right" then
        return "west"
    end
    return nil
end

local function get_static_blocked_destination(dir, px, py)
    if not map_reader or px == nil or py == nil then
        return nil
    end
    local dx, dy = direction_delta(dir)
    local approach = approach_for_direction(dir)
    if (dx == 0 and dy == 0) or not approach then
        return nil
    end
    local map_id = nav.get_position()
    local dest_x = px + dx
    local dest_y = py + dy

    if map_reader.is_permanently_blocked_override
       and map_reader.is_permanently_blocked_override(map_id, dest_x, dest_y) then
        return {
            map_id = map_id,
            x = dest_x,
            y = dest_y,
            approach = approach,
            reason = "permanent_blocked",
        }
    end

    if map_reader.get_directional_blocks then
        local directional_blocks = map_reader.get_directional_blocks(map_id)
        local entry = directional_blocks and directional_blocks[dest_x .. "," .. dest_y]
        if type(entry) == "table" and entry[approach] == true then
            return {
                map_id = map_id,
                x = dest_x,
                y = dest_y,
                approach = approach,
                reason = "directional_blocked",
            }
        end
    end

    return nil
end

local function refuse_manual_static_blocked_step(dir, px, py)
    local blocked = get_static_blocked_destination(dir, px, py)
    if not blocked then
        return false
    end
    debug_tools.debug(string.format(
        "AUTO_STEP_REFUSED_STATIC_BLOCK map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d) approach=%s reason=%s source=manual_tap",
        blocked.map_id or -1,
        px or -1,
        py or -1,
        tostring(dir),
        blocked.x or -1,
        blocked.y or -1,
        tostring(blocked.approach),
        tostring(blocked.reason)))
    return true
end

local function clear_pending_repress()
    pending_repress = nil
end

local function clear_direction_press_tracking()
    tracked_dir = nil
    press_start_x = nil
    press_start_y = nil
end

local function schedule_turn_repress(dir)
    pending_repress = {
        dir = dir,
        timeout_retries = auto_timeout_retries,
        turn_represses = auto_turn_represses + 1,
        inject_limit = get_turn_repress_inject_limit(),
        release_frames = get_turn_repress_release_frames(),
        start_x = auto_start_x,
        start_y = auto_start_y,
        source = auto_step_source,
    }
    auto_dir = nil
    auto_frames = 0
    auto_start_x = nil
    auto_start_y = nil
end

local function reset_active_step()
    auto_dir = nil
    auto_frames = 0
    auto_start_x = nil
    auto_start_y = nil
    auto_timeout_retries = 0
    auto_turn_represses = 0
    auto_inject_limit = nil
    auto_start_subpixel = nil
    auto_movement_started = false
    auto_movement_start_frame = nil
    auto_step_source = nil
    clear_pending_repress()
end

local function route_settle_after_step(completed_dir)
    local next_dir = route_steps and route_steps[route_index]
    local direction_change = next_dir and completed_dir and next_dir ~= completed_dir
    local settle_frames = 0
    if route_settle_same_direction or direction_change then
        settle_frames = route_settle_default or 0
    end
    if direction_change then
        local turn_settle = get_route_turn_settle_frames()
        if turn_settle > settle_frames then
            debug_tools.debug(string.format(
                "auto_step route turn settle prev=%s next=%s frames=%d",
                tostring(completed_dir), tostring(next_dir), turn_settle))
            settle_frames = turn_settle
        end
    end
    return settle_frames
end

local function emit_step_complete(from_x, from_y, dir, to_x, to_y, source)
    local step_data = {
        from_x = from_x,
        from_y = from_y,
        dir = dir,
        to_x = to_x,
        to_y = to_y,
        source = source,
        queued_route = (route_steps ~= nil),
    }
    event_bus.publish("route_step_completed", step_data)
    if M.on_step_complete then
        local ok, err = pcall(M.on_step_complete, from_x, from_y, dir, to_x, to_y, step_data)
        if not ok then
            debug_tools.error("on_step_complete error: " .. tostring(err))
        end
    end
end

local function emit_route_cancelled(cancel_data)
    cancel_data = cancel_data or {}
    event_bus.publish("route_cancelled", cancel_data)
    if M.on_route_cancelled then
        local ok, err = pcall(M.on_route_cancelled, cancel_data)
        if not ok then
            debug_tools.error("on_route_cancelled error: " .. tostring(err))
        end
    end
end

local function cancel_route_for_drift(px, py, source)
    local last_x = route_last_x
    local last_y = route_last_y
    local next_index = route_index
    debug_tools.debug(string.format(
        "auto_step clear_route: off-path drift from=(%d,%d) current=(%d,%d) next_index=%d source=%s",
        last_x or -1, last_y or -1, px or -1, py or -1, next_index or -1,
        tostring(source)))
    clear_route()
    emit_route_cancelled({
        reason = "route_drift_off_path",
        from_x = last_x,
        from_y = last_y,
        current_x = px,
        current_y = py,
        next_index = next_index,
        source = source,
    })
end

local function consume_route_drift(px, py, source)
    if not route_steps
       or route_last_x == nil
       or route_last_y == nil
       or px == nil
       or py == nil
       or (px == route_last_x and py == route_last_y) then
        return 0, false
    end

    local simulated_x = route_last_x
    local simulated_y = route_last_y
    local matched = 0
    local max_index = math.min(#route_steps, route_index + ROUTE_DRIFT_CATCHUP_LIMIT - 1)
    for i = route_index, max_index do
        local dx, dy = direction_delta(route_steps[i])
        simulated_x = simulated_x + dx
        simulated_y = simulated_y + dy
        if simulated_x == px and simulated_y == py then
            matched = i - route_index + 1
            break
        end
    end

    if matched == 0 then
        debug_tools.debug(string.format(
            "auto_step route drift not on queued path from=(%d,%d) current=(%d,%d) next_index=%d",
            route_last_x or -1, route_last_y or -1, px or -1, py or -1, route_index or -1))
        return 0, true
    end

    for _ = 1, matched do
        local dir = route_steps[route_index]
        local from_x = route_last_x
        local from_y = route_last_y
        local dx, dy = direction_delta(dir)
        local to_x = from_x + dx
        local to_y = from_y + dy
        route_last_x = to_x
        route_last_y = to_y
        route_index = route_index + 1
        debug_tools.debug(string.format(
            "auto_step route catch-up dir=%s from=(%d,%d) to=(%d,%d) source=%s",
            tostring(dir), from_x or -1, from_y or -1, to_x or -1, to_y or -1,
            tostring(source)))
        emit_step_complete(from_x, from_y, dir, to_x, to_y, source)
    end

    return matched, false
end

local function get_hazard_destination(dir, px, py)
    if not map_reader or not map_reader.is_hazard_cell or px == nil or py == nil then
        return nil
    end
    local map_id = nav.get_position()
    local dx, dy = direction_delta(dir)
    if dx == 0 and dy == 0 then
        return nil
    end
    local dest_x = px + dx
    local dest_y = py + dy
    local hazard = map_reader.is_hazard_cell(map_id, dest_x, dest_y)
    if not hazard then
        return nil
    end
    return {
        map_id = map_id,
        x = dest_x,
        y = dest_y,
        hazard = hazard,
    }
end

local function refuse_hazard_step(dir, px, py, source)
    local hazard = get_hazard_destination(dir, px, py)
    if hazard then
        debug_tools.info(string.format(
            "AUTO_STEP_REFUSED_HAZARD map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d) hazard=%s source=%s queued_route=%s",
            hazard.map_id or -1,
            px or -1,
            py or -1,
            tostring(dir),
            hazard.x or -1,
            hazard.y or -1,
            tostring(hazard.hazard),
            tostring(source),
            tostring(route_steps ~= nil)))
        clear_direction_press_tracking()
        if source == "pending_repress" then
            clear_pending_repress()
        end
        if route_steps then
            clear_route()
            emit_route_cancelled({
                reason = "dangerous_tile",
                message = "Dangerous tile ahead",
                current_x = px,
                current_y = py,
                dir = dir,
                dest_x = hazard.x,
                dest_y = hazard.y,
                hazard = hazard.hazard,
                source = source,
            })
        elseif source == "manual_tap" or source == "inject_step" then
            tolk.output_interrupt("Dangerous tile ahead")
        end
        return true
    end

    if source == "manual_tap" and refuse_manual_static_blocked_step(dir, px, py) then
        clear_direction_press_tracking()
        return true
    end

    return false
end

-- ============================================================
-- Core Update
-- ============================================================

-- update(can_walk): Call once per frame from the main loop.
--
-- can_walk: boolean — true when auto-stepping is safe (field state,
--   no menu open, no dialogue active). When false, auto-step is
--   completely disabled and any active auto-hold is cancelled.
--
-- This function reads joypad input, tracks direction presses/releases,
-- and injects joypad input when auto-holding a direction.
function M.update(can_walk)
    -- Check if the feature is enabled in config
    local enabled = config.get("enable_auto_step")
    if enabled == "false" then
        -- Feature disabled — reset all state and return
        reset_active_step()
        clear_direction_press_tracking()
        cooldown = 0
        suppress_direction_tracking_frames = 0
        clear_route()
        return
    end

    -- Read current joypad state (player 1)
    local joy = joypad.read(1)

    -- Read current tile position
    local _, px, py = nav.get_position()

    -- Get the configured timeout (max frames to wait for position change).
    -- This covers the full step: injection phase + animation completion.
    -- A turn (~8 frames) + step (~16 frames) = ~24 frames, so 45 gives margin.
    local timeout = tonumber(config.get("auto_step_timeout")) or 45

    -- If we can't walk right now, cancel any active auto-hold
    if not can_walk then
        local had_route = (route_steps ~= nil)
        if auto_dir or pending_repress then
            debug_tools.debug(string.format(
                "auto_step cancel: can_walk=false auto_dir=%s pending_repress=%s",
                tostring(auto_dir), pending_repress and tostring(pending_repress.dir) or "nil"))
        end
        reset_active_step()
        clear_direction_press_tracking()
        cooldown = 0
        post_step_release_frames = 0
        clear_route()
        if had_route then
            emit_route_cancelled({
                reason = "can_walk_false",
                current_x = px,
                current_y = py,
            })
        end
        -- Don't update prev_held here — we still need to track joypad
        -- state so we detect fresh presses correctly when can_walk
        -- becomes true again.
        for _, dir in ipairs(DIRECTIONS) do
            prev_held[dir] = joy[dir] or false
        end
        return
    end

    if suppress_direction_tracking_frames > 0
       and not auto_dir
       and not pending_repress
       and route_steps == nil
       and route_settle_frames <= 0 then
        suppress_direction_tracking_frames = suppress_direction_tracking_frames - 1
        clear_direction_press_tracking()
        for _, dir in ipairs(DIRECTIONS) do
            prev_held[dir] = joy[dir] or false
        end
        return
    end

    -- Tick down cooldown
    if cooldown > 0 then
        cooldown = cooldown - 1
    end

    if pending_repress and is_any_direction_pressed(joy) then
        debug_tools.debug("auto_step cancel pending repress: live direction input detected")
        clear_pending_repress()
    end

    if pending_repress
       and pending_repress.start_x ~= nil
       and pending_repress.start_y ~= nil
       and (px ~= pending_repress.start_x or py ~= pending_repress.start_y) then
        local completed = pending_repress
        debug_tools.debug(string.format(
            "auto_step cancel pending repress: position changed to (%d,%d) from (%d,%d)",
            px or -1, py or -1, pending_repress.start_x or -1, pending_repress.start_y or -1))
        clear_pending_repress()
        cooldown = COOLDOWN_FRAMES
        neutralize_direction(joy)
        start_post_step_release()
        local expected_x = completed.start_x
        local expected_y = completed.start_y
        if completed.dir == "up" then
            expected_y = expected_y - 1
        elseif completed.dir == "down" then
            expected_y = expected_y + 1
        elseif completed.dir == "left" then
            expected_x = expected_x - 1
        elseif completed.dir == "right" then
            expected_x = expected_x + 1
        end
        if route_steps ~= nil and (px ~= expected_x or py ~= expected_y) then
            debug_tools.debug(string.format(
                "auto_step clear_route: step landed off direction dir=%s from=(%d,%d) expected=(%d,%d) current=(%d,%d) source=pending_repress_mismatch",
                tostring(completed.dir),
                completed.start_x or -1,
                completed.start_y or -1,
                expected_x or -1,
                expected_y or -1,
                px or -1,
                py or -1))
            clear_route()
            emit_route_cancelled({
                reason = "route_drift_off_path",
                from_x = completed.start_x,
                from_y = completed.start_y,
                expected_x = expected_x,
                expected_y = expected_y,
                current_x = px,
                current_y = py,
                active_dir = completed.dir,
                source = "pending_repress_mismatch",
            })
            for _, dir in ipairs(DIRECTIONS) do
                prev_held[dir] = joy[dir] or false
            end
            return
        end
        if route_steps then
            route_last_x = px
            route_last_y = py
            route_settle_frames = route_settle_after_step(completed.dir)
        end
        emit_step_complete(completed.start_x, completed.start_y, completed.dir, px, py, "pending_repress")
        for _, dir in ipairs(DIRECTIONS) do
            prev_held[dir] = joy[dir] or false
        end
        return
    end

    if post_step_release_frames ~= 0
       and (post_step_release_frames < 0 or route_steps ~= nil or not is_any_direction_pressed(joy)) then
        neutralize_direction(joy)
        if post_step_release_frames < 0 then
            post_step_release_frames = post_step_release_frames + 1
        else
            post_step_release_frames = post_step_release_frames - 1
        end
        for _, dir in ipairs(DIRECTIONS) do
            prev_held[dir] = joy[dir] or false
        end
        return
    end

    if pending_repress and pending_repress.release_frames and pending_repress.release_frames > 0 then
        -- Make the repress gap a real neutral release on live hardware. A
        -- passive wait was not enough to clear the held direction reliably.
        neutralize_direction(joy)
        pending_repress.release_frames = pending_repress.release_frames - 1
        for _, dir in ipairs(DIRECTIONS) do
            prev_held[dir] = joy[dir] or false
        end
        return
    end

    if pending_repress and not auto_dir and cooldown <= 0 and not is_any_direction_pressed(joy) then
        debug_tools.debug("auto_step resume pending repress")
        if refuse_hazard_step(pending_repress.dir, px, py, "pending_repress") then
            for _, dir in ipairs(DIRECTIONS) do
                prev_held[dir] = joy[dir] or false
            end
            return
        end
        begin_step(pending_repress.dir, px, py, pending_repress)
        for _, dir in ipairs(DIRECTIONS) do
            prev_held[dir] = joy[dir] or false
        end
        return
    end

    -- --------------------------------------------------------
    -- Phase 1: Check if auto-hold should stop
    -- --------------------------------------------------------
    if auto_dir then
        local current_subpixel = read_movement_subpixel()
        -- Cancel if player pressed a DIFFERENT direction (they want
        -- to go another way). Pressing the SAME direction we're already
        -- auto-holding is fine — just let it continue.
        local different_dir = false
        for _, dir in ipairs(DIRECTIONS) do
            if joy[dir] and dir ~= auto_dir then
                different_dir = true
                break
            end
        end

        if different_dir then
            local had_route = (route_steps ~= nil)
            local interrupted_dir = auto_dir
            debug_tools.debug("auto_step cancel: different live direction pressed")
            if DEBUG then tolk.output("auto-step cancelled, different direction") end
            reset_active_step()
            clear_route()
            if had_route then
                emit_route_cancelled({
                    reason = "live_input_interrupt",
                    current_x = px,
                    current_y = py,
                    active_dir = interrupted_dir,
                })
            end
        -- Cancel if position changed (step completed!)
        elseif px ~= auto_start_x or py ~= auto_start_y then
            local completed_from_x = auto_start_x
            local completed_from_y = auto_start_y
            local completed_dir = auto_dir
            local completed_frames = auto_frames
            local completed_retries = auto_timeout_retries
            local completed_turn_represses = auto_turn_represses
            local completed_inject_limit = auto_inject_limit
            local completed_queued_route = (route_steps ~= nil)
            local expected_x = completed_from_x
            local expected_y = completed_from_y
            if completed_dir == "up" then
                expected_y = expected_y - 1
            elseif completed_dir == "down" then
                expected_y = expected_y + 1
            elseif completed_dir == "left" then
                expected_x = expected_x - 1
            elseif completed_dir == "right" then
                expected_x = expected_x + 1
            end
            if completed_queued_route and (px ~= expected_x or py ~= expected_y) then
                reset_active_step()
                cooldown = COOLDOWN_FRAMES
                neutralize_direction(joy)
                start_post_step_release()
                debug_tools.debug(string.format(
                    "auto_step clear_route: step landed off direction dir=%s from=(%d,%d) expected=(%d,%d) current=(%d,%d) source=auto_hold_mismatch",
                    tostring(completed_dir),
                    completed_from_x or -1,
                    completed_from_y or -1,
                    expected_x or -1,
                    expected_y or -1,
                    px or -1,
                    py or -1))
                clear_route()
                emit_route_cancelled({
                    reason = "route_drift_off_path",
                    from_x = completed_from_x,
                    from_y = completed_from_y,
                    expected_x = expected_x,
                    expected_y = expected_y,
                    current_x = px,
                    current_y = py,
                    active_dir = completed_dir,
                    source = "auto_hold_mismatch",
                })
                for _, dir in ipairs(DIRECTIONS) do
                    prev_held[dir] = joy[dir] or false
                end
                return
            end
            debug_tools.debug(string.format(
                "auto_step complete dir=%s from=(%d,%d) to=(%d,%d) frames=%d timeout_retries=%d turn_represses=%d inject_limit=%d queued_route=%s",
                tostring(completed_dir),
                completed_from_x or -1,
                completed_from_y or -1,
                px or -1,
                py or -1,
                completed_frames or -1,
                completed_retries or -1,
                completed_turn_represses or -1,
                completed_inject_limit or -1,
                tostring(completed_queued_route)))
            if DEBUG then tolk.output("step done, " .. auto_frames .. " frames") end
            reset_active_step()
            cooldown = COOLDOWN_FRAMES  -- Prevent double-step
            neutralize_direction(joy)
            start_post_step_release()
            if route_steps then
                route_last_x = px
                route_last_y = py
                route_settle_frames = route_settle_after_step(completed_dir)
            end
            emit_step_complete(completed_from_x, completed_from_y, completed_dir, px, py, "auto_hold")
        elseif should_release_on_movement_start()
           and auto_start_subpixel ~= nil
           and current_subpixel ~= nil
           and not auto_movement_started
           and current_subpixel ~= auto_start_subpixel then
            auto_movement_started = true
            auto_movement_start_frame = auto_frames
            debug_tools.debug(string.format(
                "auto_step movement started dir=%s from=(%d,%d) frame=%d subpixel=0x%02X->0x%02X queued_route=%s",
                tostring(auto_dir),
                auto_start_x or -1,
                auto_start_y or -1,
                auto_frames or -1,
                auto_start_subpixel or -1,
                current_subpixel or -1,
                tostring(route_steps ~= nil)))
            if should_hold_early_movement_start() then
                debug_tools.debug(string.format(
                    "auto_step early movement twitch held dir=%s from=(%d,%d) frame=%d grace=%d queued_route=%s",
                    tostring(auto_dir),
                    auto_start_x or -1,
                    auto_start_y or -1,
                    auto_movement_start_frame or -1,
                    get_route_early_release_grace_frames(),
                    tostring(route_steps ~= nil)))
                joypad.set(1, {[auto_dir] = true})
            else
                neutralize_direction(joy)
            end
        -- If the first press only turned the player, release for one frame and
        -- issue a fresh press instead of waiting for the full blocked timeout.
        elseif auto_frames >= get_turn_repress_delay()
           and auto_turn_represses < get_turn_repress_limit()
           and (
               not auto_movement_started
               or (
                   auto_step_source ~= "manual_tap"
                   and
                   auto_movement_start_frame ~= nil
                   and auto_movement_start_frame <= get_route_early_release_grace_frames()
                   and not should_hold_early_movement_start()
                   and not (
                       route_steps ~= nil
                       and auto_dir ~= nil
                       and route_steps[route_index] ~= nil
                       and route_steps[route_index] ~= auto_dir
                   )
               )
           ) then
            debug_tools.debug(string.format(
                "auto_step schedule turn repress dir=%s from=(%d,%d) frame=%d",
                tostring(auto_dir), auto_start_x or -1, auto_start_y or -1, auto_frames))
            schedule_turn_repress(auto_dir)
        -- Cancel if timeout reached (blocked by wall / step never started)
        else
            local effective_timeout = timeout
            local route_timing_timeout = get_route_timing_suspect_timeout_frames()
            if route_timing_timeout then
                effective_timeout = math.min(timeout, route_timing_timeout)
            end
            if route_steps == nil
               and auto_step_source == "manual_tap"
               and auto_movement_started
               and auto_movement_start_frame ~= nil
               and (auto_frames - auto_movement_start_frame) >= 20
               and not is_any_direction_pressed(joy) then
                debug_tools.debug(string.format(
                    "auto_step cancel manual_tap early-twitch wait dir=%s from=(%d,%d) frames=%d movement_start_frame=%s",
                    tostring(auto_dir),
                    auto_start_x or -1,
                    auto_start_y or -1,
                    auto_frames or -1,
                    tostring(auto_movement_start_frame)))
                reset_active_step()
                neutralize_direction(joy)
                start_post_step_release()
                for _, dir in ipairs(DIRECTIONS) do
                    prev_held[dir] = joy[dir] or false
                end
                return
            end
            if auto_frames < effective_timeout then
                -- Only inject during the initiation phase. After INJECT_LIMIT
                -- frames, the game has committed to the step — stop injecting
                -- and just wait for position to change. This prevents the game
                -- from seeing the direction held when the step finishes and
                -- immediately starting a second step (overshoot).
                if auto_movement_started and not should_hold_early_movement_start() then
                    neutralize_direction(joy)
                elseif auto_frames <= (auto_inject_limit or INJECT_LIMIT) then
                    joypad.set(1, {[auto_dir] = true})
                elseif route_steps == nil and not auto_movement_started and not is_any_direction_pressed(joy) then
                    -- Manual/probe steps that have not started moving yet need
                    -- a real held press. Releasing at the generic inject window
                    -- can turn open seams into false blocked observations.
                    joypad.set(1, {[auto_dir] = true})
                elseif route_steps or not is_any_direction_pressed(joy) then
                    -- Actively release after the initiation window so a sticky
                    -- joypad.set cannot commit the next tile. Preserve a real
                    -- live hold for manual movement; queued routes own their input.
                    neutralize_direction(joy)
                end
                auto_frames = auto_frames + 1
            else
                local block_retry_limit = get_active_block_retry_limit()
                local timing_suspect_timeout = should_use_route_timing_suspect_timeout()
                if auto_timeout_retries < block_retry_limit and not timing_suspect_timeout then
                    auto_timeout_retries = auto_timeout_retries + 1
                    auto_frames = 1
                    -- If the short turn re-press was not enough to start movement,
                    -- escalate retries back to a full inject window before treating
                    -- the destination as blocked.
                    auto_inject_limit = get_inject_limit()
                    auto_start_subpixel = read_movement_subpixel()
                    auto_movement_started = false
                    auto_movement_start_frame = nil
                    joypad.set(1, {[auto_dir] = true})
                    debug_tools.debug(string.format(
                        "auto_step timeout retry %d/%d from=(%d,%d) dir=%s inject_limit=%d timeout=%d turn_represses=%d source=%s",
                        auto_timeout_retries, block_retry_limit,
                        auto_start_x or -1, auto_start_y or -1, tostring(auto_dir),
                        auto_inject_limit or -1,
                        effective_timeout or -1,
                        auto_turn_represses or -1,
                        tostring(auto_step_source)))
                    for _, dir in ipairs(DIRECTIONS) do
                        prev_held[dir] = joy[dir] or false
                    end
                    return
                end
                if DEBUG then tolk.output("auto-step timeout") end
                -- Optional legacy recorder. Keep it off by default: noisy
                -- blocked attempts should not accumulate persistent map data.
                local map_id = nav.get_position()  -- first return value is map_id
                -- auto_dir is FCEUX joypad key ("up"/"down"/"left"/"right") which
                -- matches the dir strings used by record_block.
                if M.should_record_debug_blocks() and not timing_suspect_timeout then
                    debug_tools.record_block(map_id, auto_start_x, auto_start_y, auto_dir)
                end
                -- Save blocked info before clearing auto_dir so on_blocked can use it
                local blocked_from_x = auto_start_x
                local blocked_from_y = auto_start_y
                local blocked_dir    = auto_dir
                local blocked_queued_route = (route_steps ~= nil)
                local blocked_movement_started = auto_movement_started
                local blocked_movement_start_frame = auto_movement_start_frame
                local blocked_timeout_retries = auto_timeout_retries
                local blocked_turn_represses = auto_turn_represses
                local blocked_inject_limit = auto_inject_limit
                local blocked_source = auto_step_source
                debug_tools.debug(string.format(
                    "auto_step blocked dir=%s from=(%d,%d) frames=%d timeout_retries=%d/%d turn_represses=%d inject_limit=%d queued_route=%s timeout=%d movement_started=%s movement_start_frame=%s source=%s",
                    tostring(blocked_dir),
                    blocked_from_x or -1,
                    blocked_from_y or -1,
                    auto_frames or -1,
                    auto_timeout_retries or -1,
                    block_retry_limit or -1,
                    auto_turn_represses or -1,
                    auto_inject_limit or -1,
                    tostring(blocked_queued_route),
                    effective_timeout or -1,
                    tostring(blocked_movement_started),
                    tostring(blocked_movement_start_frame),
                    tostring(blocked_source)))
                reset_active_step()
                clear_route()
                neutralize_direction(joy)
                start_post_step_release()
                -- Notify the main loop so it can re-route around the obstacle.
                -- Pass the blocked starting position and direction so the handler
                -- can record the destination cell and avoid routing through it again.
                local block_data = {
                    from_x = blocked_from_x,
                    from_y = blocked_from_y,
                    dir = blocked_dir,
                    queued_route = blocked_queued_route,
                    movement_started = blocked_movement_started,
                    movement_start_frame = blocked_movement_start_frame,
                    timeout_retries = blocked_timeout_retries,
                    turn_represses = blocked_turn_represses,
                    inject_limit = blocked_inject_limit,
                    timeout = effective_timeout,
                    timing_suspect = timing_suspect_timeout,
                    source = blocked_source,
                }
                event_bus.publish("route_blocked", block_data)
                if M.on_blocked then
                    M.on_blocked(blocked_from_x, blocked_from_y, blocked_dir, block_data)
                end
            end
        end

        -- Update prev_held and return — while auto-holding, we don't
        -- process new press/release tracking
        for _, dir in ipairs(DIRECTIONS) do
            prev_held[dir] = joy[dir] or false
        end
        return
    end

    if route_steps and route_settle_frames > 0 then
        if is_any_direction_pressed(joy) then
            debug_tools.debug("auto_step clear_route: live direction input interrupted queued route during settle")
            clear_route()
            emit_route_cancelled({
                reason = "live_input_interrupt",
                current_x = px,
                current_y = py,
                source = "route_settle",
            })
            for _, dir in ipairs(DIRECTIONS) do
                prev_held[dir] = joy[dir] or false
            end
            return
        end
        neutralize_direction(joy)
        local consumed, off_path = consume_route_drift(px, py, "route_settle_catchup")
        if consumed > 0 then
            route_settle_frames = route_settle_default or 0
            for _, dir in ipairs(DIRECTIONS) do
                prev_held[dir] = joy[dir] or false
            end
            return
        end
        if off_path then
            cancel_route_for_drift(px, py, "route_settle_catchup")
            for _, dir in ipairs(DIRECTIONS) do
                prev_held[dir] = joy[dir] or false
            end
            return
        end
        route_settle_frames = route_settle_frames - 1
        for _, dir in ipairs(DIRECTIONS) do
            prev_held[dir] = joy[dir] or false
        end
        return
    end

    if route_steps and is_any_direction_pressed(joy) then
        debug_tools.debug("auto_step clear_route: live direction input interrupted queued route")
        clear_route()
        emit_route_cancelled({
            reason = "live_input_interrupt",
            current_x = px,
            current_y = py,
            source = "route_step",
        })
    end

    if route_steps and cooldown <= 0 then
        local consumed, off_path = consume_route_drift(px, py, "route_settle_catchup")
        if consumed > 0 then
            route_settle_frames = route_settle_default or 0
            for _, dir in ipairs(DIRECTIONS) do
                prev_held[dir] = joy[dir] or false
            end
            return
        end
        if off_path then
            cancel_route_for_drift(px, py, "route_settle_catchup")
            for _, dir in ipairs(DIRECTIONS) do
                prev_held[dir] = joy[dir] or false
            end
            return
        end
        local next_dir = route_steps[route_index]
        if next_dir then
            route_index = route_index + 1
            if refuse_hazard_step(next_dir, px, py, "queued_route") then
                for _, dir in ipairs(DIRECTIONS) do
                    prev_held[dir] = joy[dir] or false
                end
                return
            end
            begin_step(next_dir, px, py)
            for _, dir in ipairs(DIRECTIONS) do
                prev_held[dir] = joy[dir] or false
            end
            return
        end
        -- All steps have been walked (auto_dir is nil here, so the last step's
        -- position change has already been processed). Fire the completion callback.
        clear_route()
        event_bus.publish("route_completed")
        if M.on_route_complete then
            local ok, err = pcall(M.on_route_complete)
            if not ok then
                debug_tools.error("on_route_complete error: " .. tostring(err))
            end
        end
    end

    -- --------------------------------------------------------
    -- Phase 2: Detect new direction presses
    -- --------------------------------------------------------
    -- A "new press" is a direction that's held this frame but wasn't
    -- held last frame (rising edge).
    for _, dir in ipairs(DIRECTIONS) do
        local held_now = joy[dir] or false
        local held_prev = prev_held[dir] or false

        if held_now and not held_prev then
            -- Fresh press — record starting position
            tracked_dir = dir
            press_start_x = px
            press_start_y = py
        end
    end

    -- --------------------------------------------------------
    -- Phase 3: Detect direction releases
    -- --------------------------------------------------------
    -- If the tracked direction was released and the position didn't
    -- change, trigger auto-step.
    if tracked_dir then
        local held_now = joy[tracked_dir] or false
        local held_prev = prev_held[tracked_dir] or false

        if not held_now and held_prev then
            -- Direction was just released
            if cooldown <= 0 then
                -- Check if position changed during the press
                if px == press_start_x and py == press_start_y then
                    -- Position didn't change — the tap was too short.
                    -- Start auto-holding this direction to complete the step.
                    if not refuse_hazard_step(tracked_dir, px, py, "manual_tap") then
                        begin_step(tracked_dir, px, py, {source = "manual_tap"})
                        if DEBUG then tolk.output("auto-step " .. auto_dir) end
                    end
                end
            end
            -- Either way, stop tracking this press
            clear_direction_press_tracking()
        end
    end

    -- --------------------------------------------------------
    -- Update previous-frame state
    -- --------------------------------------------------------
    for _, dir in ipairs(DIRECTIONS) do
        prev_held[dir] = joy[dir] or false
    end
end

-- inject_step(dir): Directly trigger an auto-held step without physical joypad input.
-- For use by debug/automation tools (e.g., simulate_input commands in debug_tools).
-- 'dir' must be one of: "up", "down", "left", "right".
-- The step executes only if can_walk is true when update() runs this frame.
-- Calling joypad.set() here covers the current frame; update() covers subsequent frames.
function M.inject_step(dir)
    local _, px, py = nav.get_position()
    clear_route()
    debug_tools.debug(string.format("auto_step inject_step dir=%s at=(%d,%d)", tostring(dir), px or -1, py or -1))
    if refuse_hazard_step(dir, px, py, "inject_step") then
        return false
    end
    begin_step(dir, px, py, {source = "inject_step"})
    return true
end

-- suppress_direction_tracking(frames): Temporarily ignore raw D-pad
-- press/release edges without cancelling queued route or active auto-step
-- state. Used by route_manager's post-arrival facing helper: it injects a
-- short direction press to turn toward an NPC, and that artificial tap must
-- not be reinterpreted here as a player tap-to-step request.
function M.suppress_direction_tracking(frames)
    frames = tonumber(frames) or 0
    frames = math.floor(frames)
    if frames <= 0 then
        return
    end
    if frames > suppress_direction_tracking_frames then
        suppress_direction_tracking_frames = frames
    end
    clear_direction_press_tracking()
end

-- opts: { settle_frames = N, settle_same_direction = true|false }
-- Note: opts.autonomous was removed; live input always cancels a queued step.
function M.start_route(steps, opts)
    opts = opts or {}
    clear_route()
    if not steps or #steps == 0 then
        return false
    end
    route_steps = {}
    for i, dir in ipairs(steps) do
        route_steps[i] = dir
    end
    route_index = 1
    route_settle_default = math.max(0, tonumber(opts.settle_frames) or 0)
    route_settle_same_direction = opts.settle_same_direction ~= false
    route_settle_frames = 0
    return true
end

function M.clear_route()
    clear_route()
end

function M.cancel_active_step(clear_queued_route, force_release)
    reset_active_step()
    tracked_dir = nil
    press_start_x = nil
    press_start_y = nil
    post_step_release_frames = 0
    if clear_queued_route then
        clear_route()
    end
    if force_release then
        neutralize_direction(read_joypad_safe())
        start_post_step_release(true)
    end
end

function M.is_auto_active()
    return auto_dir ~= nil or pending_repress ~= nil
end

function M.is_route_active()
    return auto_dir ~= nil or pending_repress ~= nil or route_steps ~= nil or route_settle_frames > 0
end

return M
