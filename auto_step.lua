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

local M = {}

-- Optional callback: called when a step times out (player was blocked by
-- a wall or moving NPC). Main.lua sets this to trigger automatic re-routing.
-- Signature: M.on_blocked(from_x, from_y, blocked_dir)
-- TRANSITION: Both this callback AND event_bus "route_blocked" fire.
-- Once all callers migrate to the event bus, this field can be removed.
M.on_blocked = nil

-- Optional callback: called when all queued route steps have been walked
-- (the last step's position change confirmed). Use this to release any
-- state that was set up for the route (e.g., NPC freeze).
-- Signature: M.on_route_complete()
-- TRANSITION: Both this callback AND event_bus "route_completed" fire.
M.on_route_complete = nil

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
local route_steps = nil    -- Array of queued directions for auto-walk
local route_index = 1

-- Cooldown: after a successful auto-step, wait a few frames before
-- allowing another one. This prevents accidental double-steps when
-- the player taps quickly.
local cooldown = 0
local COOLDOWN_FRAMES = 4  -- ~67ms at 60fps

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

local function clear_route()
    route_steps = nil
    route_index = 1
end

local function begin_step(dir, px, py)
    auto_dir = dir
    auto_frames = 1
    auto_start_x = px
    auto_start_y = py
    tracked_dir = nil
    joypad.set(1, {[dir] = true})
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
        auto_dir = nil
        tracked_dir = nil
        cooldown = 0
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
        auto_dir = nil
        tracked_dir = nil
        cooldown = 0
        clear_route()
        -- Don't update prev_held here — we still need to track joypad
        -- state so we detect fresh presses correctly when can_walk
        -- becomes true again.
        for _, dir in ipairs(DIRECTIONS) do
            prev_held[dir] = joy[dir] or false
        end
        return
    end

    -- Tick down cooldown
    if cooldown > 0 then
        cooldown = cooldown - 1
    end

    -- --------------------------------------------------------
    -- Phase 1: Check if auto-hold should stop
    -- --------------------------------------------------------
    if auto_dir then
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
            if DEBUG then tolk.output("auto-step cancelled, different direction") end
            auto_dir = nil
            clear_route()
        -- Cancel if position changed (step completed!)
        elseif px ~= auto_start_x or py ~= auto_start_y then
            if DEBUG then tolk.output("step done, " .. auto_frames .. " frames") end
            auto_dir = nil
            cooldown = COOLDOWN_FRAMES  -- Prevent double-step
        -- Cancel if timeout reached (blocked by wall / step never started)
        elseif auto_frames >= timeout then
            if DEBUG then tolk.output("auto-step timeout") end
            -- Record this blocked move so the collision map accumulates
            -- automatically during normal play. In debug mode, this writes to
            -- dw_blocks.log; outside debug mode it's a no-op.
            local map_id = nav.get_position()  -- first return value is map_id
            -- auto_dir is FCEUX joypad key ("up"/"down"/"left"/"right") which
            -- matches the dir strings used by record_block.
            debug_tools.record_block(map_id, auto_start_x, auto_start_y, auto_dir)
            -- Save blocked info before clearing auto_dir so on_blocked can use it
            local blocked_from_x = auto_start_x
            local blocked_from_y = auto_start_y
            local blocked_dir    = auto_dir
            auto_dir = nil
            clear_route()
            -- Notify the main loop so it can re-route around the obstacle.
            -- Pass the blocked starting position and direction so the handler
            -- can record the destination cell and avoid routing through it again.
            local block_data = {
                from_x = blocked_from_x,
                from_y = blocked_from_y,
                dir = blocked_dir,
            }
            event_bus.publish("route_blocked", block_data)
            if M.on_blocked then
                M.on_blocked(blocked_from_x, blocked_from_y, blocked_dir)
            end
        else
            -- Only inject during the initiation phase. After INJECT_LIMIT
            -- frames, the game has committed to the step — stop injecting
            -- and just wait for position to change. This prevents the game
            -- from seeing the direction held when the step finishes and
            -- immediately starting a second step (overshoot).
            if auto_frames <= INJECT_LIMIT then
                joypad.set(1, {[auto_dir] = true})
            end
            auto_frames = auto_frames + 1
        end

        -- Update prev_held and return — while auto-holding, we don't
        -- process new press/release tracking
        for _, dir in ipairs(DIRECTIONS) do
            prev_held[dir] = joy[dir] or false
        end
        return
    end

    if route_steps and is_any_direction_pressed(joy) then
        clear_route()
    end

    if route_steps and cooldown <= 0 then
        local next_dir = route_steps[route_index]
        if next_dir then
            route_index = route_index + 1
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
                    begin_step(tracked_dir, px, py)
                    if DEBUG then tolk.output("auto-step " .. auto_dir) end
                end
            end
            -- Either way, stop tracking this press
            tracked_dir = nil
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
    begin_step(dir, px, py)
end

function M.start_route(steps)
    clear_route()
    if not steps or #steps == 0 then
        return false
    end
    route_steps = {}
    for i, dir in ipairs(steps) do
        route_steps[i] = dir
    end
    route_index = 1
    return true
end

function M.clear_route()
    clear_route()
end

return M
