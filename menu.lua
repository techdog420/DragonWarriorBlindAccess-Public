-- menu.lua
-- Command menu tracking for Dragon Warrior.
--
-- When the player opens the command menu (by pressing A on the field),
-- a window appears with 6 options in a 2-column, 3-row grid:
--
--   TALK    SPELL
--   STATUS  ITEM
--   STAIRS  SEARCH
--
-- We detect when the command menu window is open by scanning the PPU
-- nametable for the word "COMMAND" (the window header). Then we track
-- the cursor position at RAM 0x00D8 (X) and 0x00D9 (Y) and announce
-- which menu item the cursor is pointing at.
--
-- The exact cursor values for each menu item need to be discovered by
-- testing with the actual game. Use the M hotkey (in main.lua) to read
-- raw cursor values while navigating the menu, then update the lookup
-- table below.

local addr = require "addresses"

local M = {}

-- ============================================================
-- PPU Constants
-- ============================================================
local PPU_NT0 = 0x2000
local SCREEN_WIDTH = 32

-- "COMMAND" in Dragon Warrior's character encoding:
-- C=0x26, O=0x32, M=0x30, M=0x30, A=0x24, N=0x31, D=0x27
local COMMAND_BYTES = {0x26, 0x32, 0x30, 0x30, 0x24, 0x31, 0x27}

-- ============================================================
-- Command Menu Item Lookup
-- ============================================================
-- Maps cursor (X, Y) values to menu item names.
-- These values are best guesses and will need to be confirmed
-- by testing. The M hotkey in main.lua reports the raw values.
--
-- IMPORTANT: Update these after testing with the actual game!
-- Use the M hotkey while navigating the command menu to read
-- the cursor X and Y for each option, then fix this table.

-- We store the lookup as a nested table: ITEMS[y][x] = name
-- This makes the lookup fast: just two table indexing operations.
local ITEMS = {}

-- Confirmed by testing: X is 0 or 1 for left/right column,
-- Y is 0, 1, 2, or 3 for four rows. The 4th row (y=3) contains
-- contextual commands (SEARCH and TAKE) that aren't always shown
-- in the visible menu but are still selectable.
-- Row 2 col 1 is labeled SEARCH in-game but functions as OPEN (door).
ITEMS[0] = {[0] = "TALK",    [1] = "SPELL"}
ITEMS[1] = {[0] = "STATUS",  [1] = "ITEM"}
ITEMS[2] = {[0] = "STAIRS",  [1] = "OPEN"}
ITEMS[3] = {[0] = "SEARCH",  [1] = "TAKE"}

-- ============================================================
-- State Tracking
-- ============================================================
-- We track previous cursor position and menu visibility so we
-- only announce when something actually changes.

local prev_cursor_x = nil   -- Previous cursor X value
local prev_cursor_y = nil   -- Previous cursor Y value
local prev_menu_open = false -- Whether the command menu was open last frame

-- ============================================================
-- Cheap State Query
-- ============================================================

-- is_open(): Return whether the command menu was open as of the last
-- check_for_changes() call. This is a cheap lookup (no PPU reads)
-- so other modules can query menu state without extra overhead.
function M.is_open()
    return prev_menu_open
end

-- ============================================================
-- Menu Detection
-- ============================================================

-- is_command_menu_open(): Check if the command menu window is visible.
-- Scans the first few rows of the PPU nametable for the word "COMMAND"
-- (the window's header text). Returns true if found.
--
-- We only scan rows 0-4 to keep it efficient (5 rows * 32 bytes =
-- 160 PPU reads, which is fine at 60fps).
function M.is_command_menu_open()
    -- Scan rows 0 through 4, looking for the 7-byte sequence "COMMAND"
    for row = 0, 4 do
        local row_start = PPU_NT0 + (row * SCREEN_WIDTH)
        -- Check each possible starting column (0 through 25, since
        -- "COMMAND" is 7 bytes and the row is 32 bytes wide)
        for col = 0, 25 do
            -- Quick check: does the first byte match 'C' (0x26)?
            -- This avoids reading all 7 bytes for non-matching positions.
            if ppu.readbyte(row_start + col) == COMMAND_BYTES[1] then
                -- First byte matches — check the rest
                local match = true
                for i = 2, #COMMAND_BYTES do
                    if ppu.readbyte(row_start + col + i - 1) ~= COMMAND_BYTES[i] then
                        match = false
                        break
                    end
                end
                if match then
                    return true
                end
            end
        end
    end
    return false
end

-- ============================================================
-- Cursor Reading
-- ============================================================

-- get_cursor_position(): Read the current menu cursor X and Y from RAM.
-- Returns two values: cursor_x, cursor_y
function M.get_cursor_position()
    return memory.readbyte(addr.MENU_CURSOR_X),
           memory.readbyte(addr.MENU_CURSOR_Y)
end

-- get_menu_item(x, y): Look up which menu item the cursor is on.
-- Returns the item name string, or nil if the position doesn't
-- match any known item.
function M.get_menu_item(x, y)
    local row = ITEMS[y]
    if row then
        return row[x]
    end
    return nil
end

-- get_cursor_info(): Get a diagnostic string with raw cursor values
-- and the resolved menu item name. Useful for testing/debugging.
function M.get_cursor_info()
    local x, y = M.get_cursor_position()
    local item = M.get_menu_item(x, y) or "unknown"
    return "Cursor X=" .. x .. " Y=" .. y .. " (" .. item .. ")"
end

-- ============================================================
-- Change Detection
-- ============================================================

-- check_for_changes(): Check if the command menu state has changed.
-- Returns a table with:
--   menu_opened (bool): true if the menu just opened this frame
--   menu_closed (bool): true if the menu just closed this frame
--   cursor_moved (bool): true if cursor position changed
--   item_name (string or nil): name of the current menu item
--   cursor_x (number): raw cursor X value
--   cursor_y (number): raw cursor Y value
function M.check_for_changes()
    local menu_open = M.is_command_menu_open()
    local cursor_x, cursor_y = M.get_cursor_position()

    local result = {
        menu_opened = menu_open and not prev_menu_open,
        menu_closed = not menu_open and prev_menu_open,
        cursor_moved = false,
        item_name = nil,
        cursor_x = cursor_x,
        cursor_y = cursor_y,
    }

    -- Only track cursor changes while the menu is open
    if menu_open then
        -- Check if cursor moved since last frame
        if cursor_x ~= prev_cursor_x or cursor_y ~= prev_cursor_y then
            result.cursor_moved = true
            result.item_name = M.get_menu_item(cursor_x, cursor_y)
        end
    end

    -- Update tracking state for next frame
    prev_cursor_x = cursor_x
    prev_cursor_y = cursor_y
    prev_menu_open = menu_open

    return result
end

-- ============================================================
-- Yes/No Prompt Detection
-- ============================================================
-- When an NPC asks a yes/no question (e.g., "Dost thou need guidance?"),
-- Dragon Warrior shows a small window with YES and NO options. The cursor
-- (PPU tile 0x42) appears directly before the currently selected option.
--
-- We scan the lower dialogue area (rows 19-29) for the pattern:
--   cursor tile (0x42) immediately before YES or NO option bytes.
--
-- Dragon Warrior character encoding for these options:
--   Y=0x3C, E=0x28, S=0x36  →  YES = {0x3C, 0x28, 0x36}
--   N=0x31, O=0x32           →  NO  = {0x31, 0x32}
-- The cursor tile is the same 0x42 used by the command menu (decodes to "").
local YES_BYTES  = {0x3C, 0x28, 0x36}   -- "YES" in DW1 encoding
local NO_BYTES   = {0x31, 0x32}          -- "NO" in DW1 encoding
local CURSOR_TILE = 0x42                 -- Same cursor arrow used by command menu

-- Rows to scan for the Yes/No prompt.
-- In DW1, the Yes/No window reuses the command menu window (same "COMMAND"
-- header, rows 0-18 area), not the lower dialogue area. Scan the full
-- screen to handle both possible layouts.
local YESNO_ROW_START = 0
local YESNO_ROW_END   = 29

-- State tracking for Yes/No prompt
local prev_yesno_selection = nil   -- "YES", "NO", or nil (no prompt active)
local last_yesno_selection = nil   -- Cached result for is_yesno_active()

-- get_yesno_state(): Scan the full screen for a Yes/No prompt.
--
-- Uses two independent checks to survive cursor blink animation:
--
--   ACTIVE: require BOTH uppercase "YES" (0x3C 0x28 0x36) AND uppercase
--   "NO" (0x31 0x32) to be present anywhere on screen. These labels stay
--   rendered even while the cursor tile blinks off, so active/inactive
--   detection does not depend on the cursor being visible.
--   Uppercase YES/NO only appear in the Yes/No window — regular dialogue
--   uses lowercase characters (different byte values).
--
--   SELECTION: look for cursor tile (0x42) immediately before YES or NO
--   (up to one space gap). Returns nil during blink frames when the cursor
--   tile is absent; check_yesno_changes() holds the last known value then.
--
-- Returns: active (bool), cursor_selection ("YES"/"NO"/nil)
local function get_yesno_state()
    local has_yes          = false
    local has_no           = false
    local cursor_selection = nil

    for row = YESNO_ROW_START, YESNO_ROW_END do
        local row_start = PPU_NT0 + (row * SCREEN_WIDTH)

        -- Read the full row once to avoid repeated ppu.readbyte calls
        local row_bytes = {}
        for col = 0, SCREEN_WIDTH - 1 do
            row_bytes[col + 1] = ppu.readbyte(row_start + col)
        end

        for col = 1, SCREEN_WIDTH do
            local b = row_bytes[col]

            -- Presence: uppercase YES (3 bytes starting here)
            if not has_yes
            and b == YES_BYTES[1]
            and row_bytes[col + 1] == YES_BYTES[2]
            and row_bytes[col + 2] == YES_BYTES[3] then
                has_yes = true
            end

            -- Presence: uppercase NO (2 bytes starting here)
            if not has_no
            and b == NO_BYTES[1]
            and row_bytes[col + 1] == NO_BYTES[2] then
                has_no = true
            end

            -- Selection: cursor tile followed (within 4 bytes) by YES or NO
            if cursor_selection == nil and b == CURSOR_TILE then
                for offset = 1, 4 do
                    local i = col + offset
                    if i > SCREEN_WIDTH then break end
                    local b1 = row_bytes[i]
                    local b2 = row_bytes[i + 1] or 0
                    local b3 = row_bytes[i + 2] or 0
                    if b1 == NO_BYTES[1] and b2 == NO_BYTES[2] then
                        cursor_selection = "NO"
                        break
                    end
                    if b1 == YES_BYTES[1] and b2 == YES_BYTES[2] and b3 == YES_BYTES[3] then
                        cursor_selection = "YES"
                        break
                    end
                    if b1 ~= 0x5F then break end  -- non-space: stop gap search
                end
            end
        end

        -- Early exit once all information is found
        if has_yes and has_no and cursor_selection ~= nil then break end
    end

    return (has_yes and has_no), cursor_selection
end

-- check_yesno_changes(): Detect Yes/No prompt state transitions each frame.
-- Call this once per frame; the result is cached for is_yesno_active().
--
-- Active/inactive is driven by label presence, not cursor visibility, so
-- cursor blink animation does not cause spurious appear/dismiss events.
-- When the prompt is active but the cursor is mid-blink, the previous
-- selection is held until the cursor becomes visible again.
--
-- Returns a table with:
--   active (bool):            true if a Yes/No prompt is currently visible
--   just_appeared (bool):     true if the prompt appeared this frame
--   just_dismissed (bool):    true if the prompt disappeared this frame
--   selection_changed (bool): true if cursor moved between YES and NO
--   selection (string/nil):   current selection "YES" or "NO", or nil
function M.check_yesno_changes()
    local active, cursor_selection = get_yesno_state()

    -- Resolve effective selection:
    --   Prompt absent  → nil (regardless of cursor)
    --   Cursor visible → cursor_selection ("YES" or "NO")
    --   Cursor blink   → prev_yesno_selection (labels still rendered)
    local selection
    if not active then
        selection = nil
    elseif cursor_selection ~= nil then
        selection = cursor_selection
    else
        selection = prev_yesno_selection  -- hold through blink gap
    end

    -- Update cache for is_yesno_active()
    last_yesno_selection = selection

    local result = {
        active            = (selection ~= nil),
        just_appeared     = (selection ~= nil) and (prev_yesno_selection == nil),
        just_dismissed    = (selection == nil) and (prev_yesno_selection ~= nil),
        selection_changed = (selection ~= nil)
                            and (prev_yesno_selection ~= nil)
                            and (selection ~= prev_yesno_selection),
        selection         = selection,
    }
    prev_yesno_selection = selection
    return result
end

-- is_yesno_active(): Return whether a Yes/No prompt was detected on the
-- last check_yesno_changes() call. This is a cheap lookup (no PPU reads)
-- so check_dialogue() can guard itself without an extra PPU scan.
-- Must be called AFTER check_yesno_changes() each frame.
function M.is_yesno_active()
    return last_yesno_selection ~= nil
end

return M
