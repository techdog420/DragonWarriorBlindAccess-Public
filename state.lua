-- state.lua
-- Game state detection for Dragon Warrior.
--
-- The game can be in several distinct states (title screen, exploring,
-- in battle, in a menu, viewing dialogue, etc.). We detect the current
-- state by reading various RAM addresses and comparing patterns.
-- The main loop uses this to decide which handler should process each frame.

local snapshot = require "game_snapshot"

local M = {}

-- Game state constants
-- These are our own labels (not from the game's RAM) for clarity.
M.STATE_TITLE     = "title"      -- Title screen / save selection (no game loaded)
M.STATE_FIELD     = "field"      -- Walking around (overworld, town, or dungeon)
M.STATE_BATTLE    = "battle"     -- In combat with an enemy
M.STATE_UNKNOWN   = "unknown"    -- Can't determine state

-- Previous state for change detection
M.prev_state = nil

-- PPU byte patterns for text unique to the title screen.
-- These appear on the title menu and adventure log, never during gameplay.
--
-- "QUEST"   : Q=0x34, U=0x38, E=0x28, S=0x36, T=0x37
--   Appears in "BEGIN A NEW QUEST", "CONTINUE A QUEST", etc.
-- "ADVENTUR" : A=0x24, D=0x27, V=0x39, E=0x28, N=0x31, T=0x37, U=0x38, R=0x35
--   Appears in "ADVENTURE LOG" header on the save-slot selection screen.
--
-- When level RAM is 1-30 but we are still on the title screen (e.g. after
-- the adventure log preview loaded a save's level into RAM), these patterns
-- tell us reliably that we have NOT yet started a game.
--
-- During gameplay the scan short-circuits quickly (no title text on screen).
local QUEST    = {0x34, 0x38, 0x28, 0x36, 0x37}          -- 5 bytes
local ADVENTUR = {0x24, 0x27, 0x39, 0x28, 0x31, 0x37, 0x38, 0x35}  -- 8 bytes

local function ppu_shows_title_content()
    for row = 0, 29 do
        local base = 0x2000 + row * 32

        -- Scan for QUEST (5 bytes); last valid start col is 31-5+1 = 27
        for col = 0, 27 do
            if ppu.readbyte(base + col) == QUEST[1] then
                local ok = true
                for i = 2, 5 do
                    if ppu.readbyte(base + col + i - 1) ~= QUEST[i] then
                        ok = false; break
                    end
                end
                if ok then return true end
            end
        end

        -- Scan for ADVENTUR (8 bytes); last valid start col is 31-8+1 = 24
        for col = 0, 24 do
            if ppu.readbyte(base + col) == ADVENTUR[1] then
                local ok = true
                for i = 2, 8 do
                    if ppu.readbyte(base + col + i - 1) ~= ADVENTUR[i] then
                        ok = false; break
                    end
                end
                if ok then return true end
            end
        end
    end
    return false
end

-- detect(): Determine the current game state.
-- Returns one of the STATE_* constants.
--
-- Detection strategy:
-- 1. If level == 0 or > 30: definitely title screen (uninitialized RAM).
-- 2. If level is 1-30 AND gameplay not yet confirmed AND PPU shows title
--    content ("QUEST" or "ADVENTUR"): still on title screen / adventure log.
--    (Covers the case where "CONTINUE A QUEST" loaded save data into RAM.)
-- 3. If enemy HP > 0: battle.
-- 4. Otherwise: field exploration.
--
-- The PPU check (step 2) short-circuits quickly during gameplay since
-- title text is not present on screen.
function M.detect()
    local level = snapshot.level
    if level == 0 or level > 30 then
        return M.STATE_TITLE
    end

    -- Level is 1-30: could be an adventure log preview or real gameplay,
    -- or a return to the title after playing (stale level in RAM).
    -- The screen fade that precedes actual game start clears the title text
    -- from the PPU, so ppu_shows_title_content() returns false at that point,
    -- allowing the TITLE→FIELD transition to fire correctly.
    -- During gameplay the scan short-circuits quickly (no "QUEST"/"ADVENTUR" tiles).
    if ppu_shows_title_content() then
        return M.STATE_TITLE
    end

    local enemy_hp = snapshot.enemy_hp
    if enemy_hp > 0 then
        return M.STATE_BATTLE
    end

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
