-- text.lua
-- Screen buffer reading and text decoding for Dragon Warrior.
--
-- The NES PPU (video chip) stores the visible screen layout in "nametables".
-- Dragon Warrior's text is rendered in PPU Nametable 0, starting at PPU
-- address 0x2000. Each byte is a tile ID (32 tiles wide, 30 rows tall).
--
-- IMPORTANT: The CPU RAM "screen buffer" at 0x0400-0x07BF only contains
-- window borders, NOT the actual text content. Text must be read from the
-- PPU nametable using ppu.readbyte(). This was discovered through testing:
-- the CPU buffer showed empty dialogue windows while the PPU had the text.
--
-- We decode tile IDs using the custom character encoding (see chars.lua)
-- to extract readable text strings.

local addr = require "addresses"
local chars = require "chars"

local M = {}

-- PPU Nametable 0 is where Dragon Warrior renders all its text.
-- This is the PPU address space (accessed via ppu.readbyte), NOT CPU RAM.
local PPU_NT0 = 0x2000
local SCREEN_WIDTH = 32
local SCREEN_HEIGHT = 30

-- Background/empty tile in PPU nametable (different from CPU RAM's 0xFF)
local BG_TILE = 0x9F

-- read_ppu_row(row): Read a single row from PPU nametable 0.
-- row: 0-29 (top to bottom)
-- Returns a table of 32 byte values (one per tile in the row).
function M.read_ppu_row(row)
    local start = PPU_NT0 + (row * SCREEN_WIDTH)
    local bytes = {}
    for col = 0, SCREEN_WIDTH - 1 do
        bytes[col + 1] = ppu.readbyte(start + col)
    end
    return bytes
end

-- read_ppu_region(top_row, left_col, width, height): Read a rectangular
-- region of the PPU nametable.
-- Returns a table of tables (one sub-table per row, each containing byte values).
function M.read_ppu_region(top_row, left_col, width, height)
    local rows = {}
    for r = 0, height - 1 do
        local row_bytes = {}
        local row_start = PPU_NT0 + ((top_row + r) * SCREEN_WIDTH) + left_col
        for c = 0, width - 1 do
            row_bytes[c + 1] = ppu.readbyte(row_start + c)
        end
        rows[r + 1] = row_bytes
    end
    return rows
end

-- decode_row(row): Read and decode one screen row to a string.
-- Trims leading/trailing spaces.
function M.decode_row(row)
    local bytes = M.read_ppu_row(row)
    local text = chars.decode_bytes(bytes)
    -- Trim leading and trailing spaces
    return text:match("^%s*(.-)%s*$") or ""
end

-- decode_region(top_row, left_col, width, height): Read and decode a
-- rectangular screen region. Returns one string per row in a table.
function M.decode_region(top_row, left_col, width, height)
    local region = M.read_ppu_region(top_row, left_col, width, height)
    local lines = {}
    for i = 1, #region do
        local text = chars.decode_bytes(region[i])
        -- Trim leading and trailing spaces
        text = text:match("^%s*(.-)%s*$") or ""
        if text ~= "" then
            lines[#lines + 1] = text
        end
    end
    return lines
end

-- has_dialogue_window(): Check if there's readable text in the dialogue
-- area (lower portion of the screen, rows 19-29).
--
-- Rather than searching for specific window border tiles (which vary
-- across DW1's many window types), we simply check if there's any
-- decodable text in the area where dialogue appears. Map/terrain tiles
-- use tile IDs in the 0x60+ range which have no entry in the decode
-- table, so they produce empty strings. Only actual text tiles
-- (letters, numbers, punctuation in the 0x00-0x5F range) decode to
-- characters.
function M.has_dialogue_window()
    for row = 19, 29 do
        local text = M.decode_row(row)
        if text ~= "" then
            return true
        end
    end
    return false
end

-- read_dialogue_window(): Read text from the lower portion of the screen.
--
-- DW1 renders dialogue below the command menu / stats area. The command
-- menu occupies roughly rows 0-19, and dialogue appears in rows 19-29.
-- By reading only the lower rows, we avoid picking up command menu text
-- (which is handled separately by check_command_menu).
--
-- This approach is more robust than border detection because DW1 uses
-- different window border positions, columns, and possibly tile IDs for
-- different dialogue types (King's speech, guard talk, chest messages,
-- system messages). Reading the raw text avoids all of those issues.
--
-- Note: chest messages that appear in the UPPER portion of the screen
-- (rows 4-15) are not caught here and need separate handling.
function M.read_dialogue_window()
    local lines = {}
    for row = 19, 29 do
        local decoded = M.decode_row(row)
        if decoded ~= "" then
            lines[#lines + 1] = decoded
        end
    end
    return table.concat(lines, " ")
end

-- read_upper_window(): Read text from the upper portion of the screen
-- (rows 1-18). This captures chest messages, shop text, and other
-- dialogue windows that appear above the standard dialogue area.
--
-- The persistent status display (player name, LV, HP, MP, G, E) is also
-- present in this region (roughly rows 1-7). Callers must distinguish
-- between the status display and actual dialogue content.
function M.read_upper_window()
    local lines = {}
    for row = 1, 18 do
        local decoded = M.decode_row(row)
        if decoded ~= "" then
            lines[#lines + 1] = decoded
        end
    end
    return table.concat(lines, " ")
end

-- is_status_text(text): Check if a text string appears to be just the
-- persistent status display (player stats always shown on the field).
-- The status display contains "LV" and "HP" markers. When a dialogue
-- window replaces or extends beyond the status area, these markers
-- disappear or the text becomes significantly longer.
function M.is_status_text(text)
    return text:find("LV") ~= nil and text:find("HP") ~= nil
end

-- get_full_screen_text(): Read the entire PPU nametable and return all
-- decoded text as a single string. Useful for debugging.
function M.get_full_screen_text()
    local all_lines = {}
    for row = 0, SCREEN_HEIGHT - 1 do
        local text = M.decode_row(row)
        if text ~= "" then
            all_lines[#all_lines + 1] = text
        end
    end
    return table.concat(all_lines, ". ")
end

-- snapshot(): Take a snapshot of the PPU nametable bytes.
-- Returns a flat table of 960 byte values (row-major order).
-- Useful for comparing frames to detect text changes.
function M.snapshot()
    local snap = {}
    for i = 0, (SCREEN_WIDTH * SCREEN_HEIGHT) - 1 do
        snap[i + 1] = ppu.readbyte(PPU_NT0 + i)
    end
    return snap
end

-- compare_snapshots(old, new): Check if two screen snapshots differ.
-- Returns true if any byte changed, false otherwise.
function M.compare_snapshots(old, new)
    if old == nil or new == nil then return true end
    for i = 1, #old do
        if old[i] ~= new[i] then
            return true
        end
    end
    return false
end

return M
