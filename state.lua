-- state.lua
-- Game state detection for Dragon Warrior.
--
-- The game can be in several distinct states (title screen, exploring,
-- in battle, in a menu, viewing dialogue, etc.). We detect the current
-- state by reading various RAM addresses and comparing patterns.
-- The main loop uses this to decide which handler should process each frame.

local addr = require "addresses"
local snapshot = require "game_snapshot"

local M = {}
local emulator_compat = rawget(_G, "DW_EMULATOR_COMPAT") or {}
local is_bizhawk = emulator_compat.is_bizhawk == true

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

local function encode_upper(text)
    local bytes = {}
    for i = 1, #text do
        local c = text:byte(i)
        if c >= 65 and c <= 90 then
            bytes[#bytes + 1] = 0x24 + (c - 65)
        end
    end
    return bytes
end

local ERASE     = encode_upper("ERASE")
local CHARACTER = encode_upper("CHARACTER")
local BACK      = encode_upper("BACK")
local END_WORD  = encode_upper("END")

local TITLE_SINGLE_PATTERNS = {
    QUEST,
    ADVENTUR,
}

local TITLE_PATTERN_GROUPS = {
    -- Erase confirmation: "Do You Want To Erase This Character?"
    -- The title menu has valid save RAM loaded, but this is not gameplay.
    {patterns = {ERASE, CHARACTER}},
    -- Name entry: row 22 uniquely carries BACK and END on the alphabet grid.
    {patterns = {BACK, END_WORD}, row_start = 22, row_end = 22},
}
-- BizHawk's PPU-domain reads are slow enough that a full title-pattern scan
-- during field play can dominate frame time. Once gameplay is confirmed, keep
-- the safety rescan rare; level RAM still catches normal boot/title cases.
local BIZHAWK_TITLE_RESCAN_INTERVAL = 3600
local BIZHAWK_CHR_PAGE_RESCAN_INTERVAL = 30
local detect_frame = 0
local title_scan_frame = nil
local title_scan_cache = false
local title_scan_after_field = false
local sprite_chr_page_cache = 0x02
local sprite_chr_page_frame = nil
local prev_enemy_hp = 0

local function row_contains(row_bytes, pattern)
    local last_start = #row_bytes - #pattern + 1
    if last_start < 1 then return false end
    for start = 1, last_start do
        if row_bytes[start] == pattern[1] then
            local ok = true
            for i = 2, #pattern do
                if row_bytes[start + i - 1] ~= pattern[i] then
                    ok = false
                    break
                end
            end
            if ok then return true end
        end
    end
    return false
end

local function group_is_complete(matches, group)
    for i = 1, #group.patterns do
        if not matches[i] then return false end
    end
    return true
end

local function ppu_shows_title_content()
    local group_matches = {}
    for i = 1, #TITLE_PATTERN_GROUPS do
        group_matches[i] = {}
    end

    for row = 0, 29 do
        local base = 0x2000 + row * 32
        local row_bytes = {}
        for col = 0, 31 do
            row_bytes[col + 1] = ppu.readbyte(base + col)
        end

        for _, pattern in ipairs(TITLE_SINGLE_PATTERNS) do
            if row_contains(row_bytes, pattern) then return true end
        end

        for group_index, group in ipairs(TITLE_PATTERN_GROUPS) do
            local row_allowed = (group.row_start == nil or row >= group.row_start)
                                and (group.row_end == nil or row <= group.row_end)
            if row_allowed then
                for pattern_index, pattern in ipairs(group.patterns) do
                    if not group_matches[group_index][pattern_index]
                       and row_contains(row_bytes, pattern) then
                        group_matches[group_index][pattern_index] = true
                    end
                end
                if group_is_complete(group_matches[group_index], group) then return true end
            end
        end
    end
    return false
end

local function should_scan_title_content()
    if not is_bizhawk then
        return true
    end
    if not title_scan_after_field then
        return true
    end
    if title_scan_frame == nil then
        return true
    end
    return (detect_frame - title_scan_frame) >= BIZHAWK_TITLE_RESCAN_INTERVAL
end

local function cached_ppu_shows_title_content()
    if should_scan_title_content() then
        title_scan_cache = ppu_shows_title_content()
        title_scan_frame = detect_frame
    end
    return title_scan_cache
end

local function read_sprite_chr_page(enemy_hp)
    if not is_bizhawk then
        return memory.readbyte(addr.CHR_PAGE_SPRITES)
    end

    enemy_hp = tonumber(enemy_hp) or 0
    local should_read = false

    if enemy_hp > 0 then
        should_read = (prev_enemy_hp <= 0)
            or sprite_chr_page_frame == nil
            or ((detect_frame - sprite_chr_page_frame) >= BIZHAWK_CHR_PAGE_RESCAN_INTERVAL)
    elseif M.prev_state == M.STATE_BATTLE then
        should_read = true
    else
        sprite_chr_page_cache = 0x02
    end

    if should_read then
        sprite_chr_page_cache = memory.readbyte(addr.CHR_PAGE_SPRITES)
        sprite_chr_page_frame = detect_frame
    end

    prev_enemy_hp = enemy_hp
    return sprite_chr_page_cache
end

-- detect(): Determine the current game state.
-- Returns one of the STATE_* constants.
--
-- Detection strategy:
-- 1. If level == 0 or > 30: definitely title screen (uninitialized RAM).
-- 2. If level is 1-30 AND gameplay not yet confirmed AND PPU shows title
--    content ("QUEST" or "ADVENTUR"): still on title screen / adventure log.
--    (Covers the case where "CONTINUE A QUEST" loaded save data into RAM.)
-- 3. If the battle sprite CHR page is active: battle.
-- 4. As a fallback, if enemy HP > 0 and the sprite CHR page is neither the
--    known field page (0x02) nor the known battle page (0x03): battle.
--    This preserves a safety net for odd transitional frames without letting
--    stale enemy HP force battle while the normal field sprite page is active.
-- 4. Otherwise: field exploration.
--
-- The PPU check (step 2) short-circuits quickly during gameplay since
-- title text is not present on screen.
function M.detect()
    detect_frame = detect_frame + 1
    local level = snapshot.level
    if level == 0 or level > 30 then
        title_scan_after_field = false
        return M.STATE_TITLE
    end

    -- Level is 1-30: could be an adventure log preview or real gameplay,
    -- or a return to the title after playing (stale level in RAM).
    -- The screen fade that precedes actual game start clears the title text
    -- from the PPU, so ppu_shows_title_content() returns false at that point,
    -- allowing the TITLE→FIELD transition to fire correctly.
    -- During gameplay the scan short-circuits quickly (no "QUEST"/"ADVENTUR" tiles).
    if cached_ppu_shows_title_content() then
        title_scan_after_field = false
        return M.STATE_TITLE
    end

    local enemy_hp = snapshot.enemy_hp
    local sprite_chr_page = read_sprite_chr_page(enemy_hp)
    if sprite_chr_page == 0x03 then
        title_scan_after_field = true
        return M.STATE_BATTLE
    end

    if enemy_hp > 0 and sprite_chr_page ~= 0x02 then
        title_scan_after_field = true
        return M.STATE_BATTLE
    end

    title_scan_after_field = true
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
