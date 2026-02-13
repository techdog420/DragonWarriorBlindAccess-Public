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
M.STATE_FIELD     = "field"      -- Walking around (overworld, town, or dungeon)
M.STATE_BATTLE    = "battle"     -- In combat with an enemy
M.STATE_UNKNOWN   = "unknown"    -- Can't determine state

-- Previous state for change detection
M.prev_state = nil

-- detect(): Determine the current game state.
-- Returns one of the STATE_* constants.
--
-- Detection strategy (simplified for now):
-- 1. Check if enemy HP > 0: likely in battle
-- 2. Otherwise: field exploration
--
-- Title screen detection was removed — the CHR page register at 0x6002
-- is outside normal NES RAM and proved unreliable. We'll revisit title
-- detection once we can test with the game.
--
-- Note: This is a first-pass heuristic. We'll refine detection as we
-- learn more about how the game signals each state.
function M.detect()
    -- Battle check: if enemy HP > 0, we're probably in battle.
    -- This may need refinement — enemy HP could have stale data between fights.
    -- We'll improve this as we test with the actual game.
    local enemy_hp = memory.readbyte(addr.ENEMY_HP)

    if enemy_hp > 0 then
        return M.STATE_BATTLE
    end

    -- For now, everything else is "field" (walking around).
    -- We'll add menu and dialogue detection in later iterations by
    -- watching the screen buffer for text window patterns.
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
