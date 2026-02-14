-- state.lua
-- Game state detection for Dragon Warrior.
--
-- The game can be in several distinct states (title screen, exploring,
-- in battle, in a menu, viewing dialogue, etc.). We detect the current
-- state by reading various RAM addresses and comparing patterns.
-- The main loop uses this to decide which handler should process each frame.

local addr = require "addresses"

local M = {}

-- Game state constants
-- These are our own labels (not from the game's RAM) for clarity.
M.STATE_TITLE     = "title"      -- Title screen / save selection (no game loaded)
M.STATE_FIELD     = "field"      -- Walking around (overworld, town, or dungeon)
M.STATE_BATTLE    = "battle"     -- In combat with an enemy
M.STATE_UNKNOWN   = "unknown"    -- Can't determine state

-- Previous state for change detection
M.prev_state = nil

-- detect(): Determine the current game state.
-- Returns one of the STATE_* constants.
--
-- Detection strategy:
-- 1. Check if player level == 0: title/save screen (no game loaded yet)
-- 2. Check if enemy HP > 0: likely in battle
-- 3. Otherwise: field exploration
--
-- The level check works because during gameplay the player's level is
-- always 1 or higher. On the title screen, save selection, and name
-- entry screens, no game data is loaded so level reads as 0.
--
-- Note: The battle heuristic (enemy HP > 0) may need refinement —
-- enemy HP could have stale data between fights. We'll improve this
-- as we test with the actual game.
function M.detect()
    -- Title screen check: if the player's level is 0 or invalid, no game
    -- is loaded. Dragon Warrior's max level is 30. On the title screen,
    -- RAM is uninitialized (0xFF = 255), and after the game initializes
    -- but before loading a save, level may be 0. Either way, we're not
    -- in gameplay.
    local level = memory.readbyte(addr.LEVEL)
    if level == 0 or level > 30 then
        return M.STATE_TITLE
    end

    -- Battle check: if enemy HP > 0, we're probably in battle.
    local enemy_hp = memory.readbyte(addr.ENEMY_HP)
    if enemy_hp > 0 then
        return M.STATE_BATTLE
    end

    -- Everything else is "field" (walking around).
    return M.STATE_FIELD
end

-- check_for_changes(): Detect state and return change info.
-- Returns a table with:
--   state (string): current state constant
--   changed (boolean): true if state differs from last frame
--   prev_state (string): what the state was last frame
function M.check_for_changes()
    local current = M.detect()
    local result = {
        state = current,
        changed = (current ~= M.prev_state),
        prev_state = M.prev_state,
    }
    M.prev_state = current
    return result
end

return M
