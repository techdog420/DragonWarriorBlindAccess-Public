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
-- PPU Nametable 1 (second horizontal nametable, used when scroll wraps past col 31).
-- When the NES horizontal scroll offset is S tiles and the dialogue text starts
-- at screen column C, the tile lands at nametable column (C + S) % 32. If
-- (C + S) >= 32 the tile is in NT1 instead of NT0. Dialogue text at x=8 on
-- large interior maps (e.g. Tantegel Castle main hall) can overflow into NT1,
-- causing the last several characters to be silently missed from read_ppu_row().
local PPU_NT1 = 0x2400
local SCREEN_WIDTH = 32
local SCREEN_HEIGHT = 30
local DIALOGUE_OVERLAP_MIN_LEN = 12

-- Background/empty tile in PPU nametable (different from CPU RAM's 0xFF)
local BG_TILE = 0x9F

-- read_ppu_row(row, scroll_tiles, base_nametable): Read one visible screen row,
-- accounting for horizontal scroll offset and active horizontal nametable.
--
-- row: 0-29 (top to bottom)
-- scroll_tiles: horizontal scroll in tiles (0-31). Default 0 (no scroll).
-- base_nametable: 0 for NT0-first, 1 for NT1-first. This is PPUCTRL bit 0.
--
-- When the NES horizontal scroll register is non-zero, the visible 32-column
-- screen row can straddle two nametables. At the King on map 0x05, the active
-- base is NT1 and scroll is 22 tiles, so the visible order is NT1 cols 22-31,
-- then NT0 cols 0-21. Reading NT0 then NT1 scrambles lines like
-- "'I am greatly pleased" into "greatly pleased 'I am".
--
-- Returns a table of 32 byte values in screen-column order (left to right).
function M.read_ppu_row(row, scroll_tiles, base_nametable)
    scroll_tiles = math.floor(tonumber(scroll_tiles) or 0) % SCREEN_WIDTH
    base_nametable = math.floor(tonumber(base_nametable) or 0) % 2
    local bytes = {}
    for col = 0, SCREEN_WIDTH - 1 do
        local virtual_col = scroll_tiles + col
        local nt_col = virtual_col % SCREEN_WIDTH
        local nt_index = (base_nametable + math.floor(virtual_col / SCREEN_WIDTH)) % 2
        local nt_base = (nt_index == 0) and PPU_NT0 or PPU_NT1
        bytes[col + 1] = ppu.readbyte(nt_base + (row * SCREEN_WIDTH) + nt_col)
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

-- decode_row(row, scroll_tiles, base_nametable): Read and decode one visible
-- screen row to a string.
-- Trims leading/trailing spaces.
--
-- If scroll/base are omitted, this reads the unscrolled NT0 row, preserving the
-- old behavior for title/menu callers. Dialogue callers should pass both values
-- from main.lua so row text is decoded in screen-column order.
function M.decode_row(row, scroll_tiles, base_nametable)
    local bytes = M.read_ppu_row(row, scroll_tiles, base_nametable)
    local text = chars.decode_bytes(bytes)
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
-- read_dialogue_window(scroll_tiles, base_nametable): Read text from the lower dialogue area.
-- scroll_tiles: optional horizontal scroll offset (default 0). See read_ppu_row.
function M.read_dialogue_window(scroll_tiles, base_nametable)
    local lines = {}
    for row = 19, 29 do
        local decoded = M.decode_row(row, scroll_tiles, base_nametable)
        if decoded ~= "" then
            lines[#lines + 1] = decoded
        end
    end
    return table.concat(lines, " ")
end

-- read_dialogue_window_filtered(scroll_tiles, start_row): Same as
-- read_dialogue_window but applies a per-row lowercase filter. Only rows
-- containing at least one lowercase letter are included. This filters out
-- status bar fragments (uppercase labels like "E", "G", "HP") that bleed
-- into the dialogue area at certain NES scroll positions.
-- NPC dialogue always contains lowercase text, so real dialogue passes through.
--
-- start_row: first nametable row of the dialogue window (default 19).
--   DW1's dialogue window always appears at the same visual position on screen,
--   but NES vertical scroll shifts which nametable row that maps to. Use
--   get_dialogue_start_row() in main.lua to compute this from RAM 0x0007.
--   The function reads 11 rows starting at start_row with modular wrap (% 30),
--   so it handles both the normal case (start_row 19-29) and the scrolled case
--   (start_row < 19, wrapping across row 0).
local function dialogue_score(dialogue)
    local score = 0
    for _ in tostring(dialogue or ""):gmatch("[a-z]") do
        score = score + 1
    end
    return score
end

M.dialogue_score = dialogue_score

local function read_dialogue_window_filtered_for_base(scroll_tiles, start_row, base_nametable)
    start_row = start_row or 19
    local lines = {}
    for i = 0, 10 do
        local row = (start_row + i) % 30
        local decoded = M.decode_row(row, scroll_tiles, base_nametable)
        if decoded ~= "" and decoded:find("[a-z]") and not M.is_status_text(decoded) then
            lines[#lines + 1] = decoded
        end
    end
    return table.concat(lines, " ")
end

function M.read_dialogue_window_filtered(scroll_tiles, start_row, base_nametable)
    local primary = read_dialogue_window_filtered_for_base(scroll_tiles, start_row, base_nametable)

    -- BizHawk can report a transient PPUCTRL base bit that does not match the
    -- nametable order holding dialogue after Yes/No transitions. When the
    -- reported order misses the lower text, try the opposite order and keep the
    -- one with more lowercase dialogue.
    if base_nametable ~= nil then
        local alternate_base = (math.floor(tonumber(base_nametable) or 0) + 1) % 2
        local alternate = read_dialogue_window_filtered_for_base(scroll_tiles, start_row, alternate_base)
        if dialogue_score(alternate) > dialogue_score(primary) then
            return alternate
        end
    end

    return primary
end

-- extract_new_dialogue(old, new): Return only the text that was not already
-- announced on the prior dialogue page.
--
-- DW1 scrolls old lower-window text upward as new prompt text appears. Most
-- pages overlap as old suffix -> new prefix, but Yes/No prompts can expose a
-- line starting from the middle of the previous page. In that case the new
-- visible text starts with a phrase already contained in old, followed by the
-- actual question.
function M.extract_new_dialogue(old, new)
    old = tostring(old or "")
    new = tostring(new or "")

    if new == "" then return "" end
    if old == "" then return new end
    if old == new then return "" end
    if old:find(new, 1, true) then return "" end

    local found_overlap = false
    for start = 1, #old do
        local suffix = old:sub(start)
        if new:sub(1, #suffix) == suffix then
            found_overlap = true
            local remainder = new:sub(#suffix + 1)
            remainder = remainder:match("^%s*(.-)%s*$") or remainder
            if remainder ~= "" then
                return remainder
            end
        end
    end

    if found_overlap then
        return ""
    end

    for len = math.min(#new, #old), DIALOGUE_OVERLAP_MIN_LEN, -1 do
        local prefix = new:sub(1, len)
        if old:find(prefix, 1, true) then
            local remainder = new:sub(len + 1)
            remainder = remainder:match("^%s*(.-)%s*$") or remainder
            if remainder ~= "" then
                return remainder
            end
            return ""
        end
    end

    return new
end

-- read_upper_window(): Read text from the upper portion of the screen
-- (rows 1-18). This captures chest messages, shop text, and other
-- dialogue windows that appear above the standard dialogue area.
--
-- The persistent status display (player name, LV, HP, MP, G, E) is also
-- present in this region (roughly rows 1-7). Callers must distinguish
-- between the status display and actual dialogue content.
-- read_upper_window(scroll_tiles, base_nametable): Read text from the upper screen area.
-- scroll_tiles: optional horizontal scroll offset (default 0). See read_ppu_row.
function M.read_upper_window(scroll_tiles, base_nametable)
    local lines = {}
    for row = 1, 18 do
        local decoded = M.decode_row(row, scroll_tiles, base_nametable)
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
    if text:find("LV") ~= nil and text:find("HP") ~= nil then
        return true
    end

    -- Menu/status redraws can split the status bar across rows or spaces,
    -- yielding strings like "Ivy V 1 L P 15 H P 0 M 0 G 0 E". Collapse the
    -- text to letters only and look for the status-bar marker order there.
    local letters_only = text:gsub("[^A-Za-z]", "")
    if letters_only:find("LV") ~= nil and letters_only:find("HP") ~= nil then
        return true
    end

    return letters_only:find("VLPHPMGE") ~= nil
end

-- is_status_anywhere(start_row, end_row): Check if the status bar is
-- visible anywhere in the given PPU row range, by looking for "LV" and
-- "HP" together in the SAME decoded row.
--
-- At map y=1, NES vertical scroll shifts the status bar so some of its
-- rows land outside the primary 1-18 scan window. Scanning rows 0-29
-- finds it even when scrolled. Requiring same-row prevents false positives
-- from LV/HP appearing in unrelated separate rows. (The y=1 baseline
-- absorption mechanism in check_upper_dialogue handles any remaining
-- noise suppression at y=1 where this check is insufficient.)
function M.is_status_anywhere(start_row, end_row)
    for row = start_row, end_row do
        local t = M.decode_row(row)
        if t:find("LV") ~= nil and t:find("HP") ~= nil then
            return true
        end
    end
    return false
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
