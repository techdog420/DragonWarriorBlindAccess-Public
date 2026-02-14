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

-- has_dialogue_window(): Check if the dialogue window border is visible.
-- Looks for the window border pattern in the PPU nametable.
-- The top border (row 18) starts with 0x64 (top-left corner) and 0x62 (top edge).
function M.has_dialogue_window()
    -- Check for the top-left corner tile of the dialogue window
    -- Row 18, column 4 should be 0x64 (top-left corner)
    local corner = ppu.readbyte(PPU_NT0 + (18 * SCREEN_WIDTH) + 4)
    return corner == 0x64
end

-- read_dialogue_window(): Read the text from the dialogue window.
-- Dragon Warrior's dialogue window occupies rows 18-27 in the PPU nametable.
-- Row 18 = top border, row 27 = bottom border.
-- Text content is in rows 19-26, columns 5-26 (inside the borders).
function M.read_dialogue_window()
    -- First check if the dialogue window is actually open
    if not M.has_dialogue_window() then
        return ""
    end

    -- Read the content area inside the window borders
    -- Columns 5-26 = 22 characters wide, rows 19-26 = 8 rows tall
    local lines = M.decode_region(19, 5, 22, 8)
    return table.concat(lines, " ")
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
