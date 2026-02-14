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

return M
