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

local nav = require "navigation"
local config = require "config"

local M = {}

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

-- Cooldown: after a successful auto-step, wait a few frames before
-- allowing another one. This prevents accidental double-steps when
-- the player taps quickly.
local cooldown = 0
local COOLDOWN_FRAMES = 4  -- ~67ms at 60fps

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

-- get_pressed_direction(joy): Return the first direction found pressed.
-- If multiple directions are pressed, returns just the first one found.
-- This is fine since DW1 doesn't use diagonal movement.
local function get_pressed_direction(joy)
    for _, dir in ipairs(DIRECTIONS) do
        if joy[dir] then
            return dir
        end
    end
    return nil
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
        return
    end

    -- Read current joypad state (player 1)
    local joy = joypad.read(1)

    -- Read current tile position
    local _, px, py = nav.get_position()

    -- Get the configured timeout (max frames to auto-hold)
    local timeout = tonumber(config.get("auto_step_timeout")) or 30

    -- If we can't walk right now, cancel any active auto-hold
    if not can_walk then
        auto_dir = nil
        tracked_dir = nil
        cooldown = 0
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
        -- Cancel if player pressed any direction manually
        if is_any_direction_pressed(joy) then
            auto_dir = nil
        -- Cancel if position changed (step completed!)
        elseif px ~= auto_start_x or py ~= auto_start_y then
            auto_dir = nil
            cooldown = COOLDOWN_FRAMES  -- Prevent double-step
        -- Cancel if timeout reached (blocked by wall)
        elseif auto_frames >= timeout then
            auto_dir = nil
        else
            -- Still auto-holding: inject the direction and increment counter
            joypad.set(1, {[auto_dir] = true})
            auto_frames = auto_frames + 1
        end

        -- Update prev_held and return — while auto-holding, we don't
        -- process new press/release tracking
        for _, dir in ipairs(DIRECTIONS) do
            prev_held[dir] = joy[dir] or false
        end
        return
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
                    auto_dir = tracked_dir
                    auto_frames = 0
                    auto_start_x = px
                    auto_start_y = py
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

return M
