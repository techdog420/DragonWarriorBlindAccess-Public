-- navigation.lua
-- Player position tracking, map change detection, and location announcements.
--
-- This module tracks the player's position and current map every frame.
-- When the map changes (player enters a new area), it announces the new
-- location name. On-demand hotkeys can read current coordinates and map.
--
-- Reads position data from the game_snapshot module (updated once per frame
-- in main.lua). Falls back to direct RAM reads if the snapshot hasn't been
-- loaded yet (e.g. during require-time initialization of other modules).

local maps = require "maps"
local snapshot = require "game_snapshot"

local M = {}

-- Previous-frame state for change detection
-- We store these so we can compare current values and only speak when
-- something actually changes.
M.prev_map_id = nil
M.prev_x = nil
M.prev_y = nil

-- get_position(): Read current player position.
-- Returns map_id, x, y.
-- On the overworld (map 0), uses the overworld-specific coordinates.
-- In other maps, uses the local map coordinates.
-- Reads from the game_snapshot (populated each frame by snapshot.update()).
function M.get_position()
    return snapshot.map_id, snapshot.x, snapshot.y
end

-- get_map_name(): Return the name of the current map.
function M.get_map_name()
    return maps.get_name(snapshot.map_id)
end

-- get_position_string(): Return a human-readable position string.
-- Format: "MapName (X, Y)"
function M.get_position_string()
    local map_id, x, y = M.get_position()
    local name = maps.get_name(map_id)
    return name .. " (" .. x .. ", " .. y .. ")"
end

-- check_for_changes(): Compare current position to previous frame.
-- Returns a table with fields:
--   map_changed (boolean): true if the map ID changed
--   position_changed (boolean): true if X or Y changed
--   map_name (string): name of current map (only if map_changed)
-- Call this once per frame in the main loop.
function M.check_for_changes()
    local map_id, x, y = M.get_position()
    local result = {
        map_changed = false,
        position_changed = false,
    }

    -- Check if the map changed (player entered a new area)
    if map_id ~= M.prev_map_id then
        result.map_changed = true
        result.map_name = maps.get_name(map_id)
    end

    -- Check if position changed (player moved)
    if x ~= M.prev_x or y ~= M.prev_y then
        result.position_changed = true
    end

    -- Store current values for next frame's comparison
    M.prev_map_id = map_id
    M.prev_x = x
    M.prev_y = y

    return result
end

return M
