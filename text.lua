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

local function read_ppu_range(address, length)
    if ppu and ppu.readbyterange then
        local bytes = ppu.readbyterange(address, length)
        if type(bytes) == "table" and #bytes == length then
            return bytes
        end
    end

    local bytes = {}
    for i = 0, length - 1 do
        bytes[i + 1] = ppu.readbyte(address + i)
    end
    return bytes
end

local function append_bytes(target, source)
    for i = 1, #source do
        target[#target + 1] = source[i]
    end
end

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

    local first_nt = (base_nametable == 0) and PPU_NT0 or PPU_NT1
    local second_nt = (base_nametable == 0) and PPU_NT1 or PPU_NT0
    local first_len = SCREEN_WIDTH - scroll_tiles

    append_bytes(bytes, read_ppu_range(first_nt + row * SCREEN_WIDTH + scroll_tiles, first_len))
    if scroll_tiles > 0 then
        append_bytes(bytes, read_ppu_range(second_nt + row * SCREEN_WIDTH, scroll_tiles))
    end
    return bytes
end

-- read_ppu_region(top_row, left_col, width, height): Read a rectangular
-- region of the PPU nametable.
-- Returns a table of tables (one sub-table per row, each containing byte values).
function M.read_ppu_region(top_row, left_col, width, height)
    local rows = {}
    for r = 0, height - 1 do
        local row_start = PPU_NT0 + ((top_row + r) * SCREEN_WIDTH) + left_col
        rows[r + 1] = read_ppu_range(row_start, width)
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

local LOW_ROW_UI_TOKENS = {
    "COMMAND",
    "TALK",
    "SPELL",
    "STATUS",
    "ITEM",
    "STAIRS",
    "DOOR",
    "SEARCH",
    "TAKE",
}

-- clean_low_row_dialogue(dialogue): Remove command-menu/status-map noise from
-- y<=3 lower-window scans without deleting meaningful uppercase game words.
--
-- The old caller stripped every 3+ letter uppercase run, which removed GOLD
-- from chest rewards (`Of GOLD thou hast gained 12`) and collapsed the spacing.
-- Strip known command labels first, then only the A-L-only map-tile noise that
-- motivated the original y<=3 special path. This preserves tokens such as
-- GOLD, KEY, and item names while still removing COMMAND/TALK/etc.
function M.clean_low_row_dialogue(dialogue)
    local clean = tostring(dialogue or "")
    for _, token in ipairs(LOW_ROW_UI_TOKENS) do
        clean = clean:gsub("%f[%u]" .. token .. "%f[^%u]", " ")
    end
    clean = clean:gsub("[%s]*[A-L][A-L][A-L]+[%s]*", " ")
    clean = clean:gsub("%s+", " ")
    return clean:match("^%s*(.-)%s*$") or ""
end

local function is_status_marker_fragment(decoded)
    local compact = tostring(decoded or ""):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
    if compact == "" or #compact > 32 then
        return false
    end
    if compact == "LV" or compact == "HP" or compact == "MP" then
        return true
    end
    if compact:match("^[VP]%s+%d+") then
        return true
    end
    if compact:match("^LV%s+%d+") or compact:match("^HP%s+%d+") or compact:match("^MP%s+%d+") then
        return true
    end
    if compact:match("^G%d+") or compact:match("^E%d+") then
        return true
    end
    return false
end

local function compact_text(decoded)
    return tostring(decoded or ""):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
end

local function lua_pattern_escape(s)
    return tostring(s or ""):gsub("([^%w])", "%%%1")
end

local function is_short_name_fragment(decoded)
    decoded = tostring(decoded or "")
    return decoded:match("^[A-Z][A-Za-z0-9]*$") ~= nil and #decoded <= 8
end

local function is_status_name_token(decoded)
    local compact = compact_text(decoded)
    return compact ~= ""
        and #compact <= 8
        and compact:find("%s") == nil
        and compact:find("[a-z]") ~= nil
        and compact:match("^[A-Za-z0-9]+$") ~= nil
end

local STATUS_VALUE_LABELS = {"LV", "HP", "MP", "V", "P", "G", "E"}

local function is_fused_status_value_fragment(decoded)
    local compact = compact_text(decoded)
    if compact == "" or #compact > 32 then
        return false
    end
    if compact:find("[%.%!%?,'\"]") then
        return false
    end

    for _, label in ipairs(STATUS_VALUE_LABELS) do
        local start_pos, end_pos = compact:find(label, 1, true)
        if start_pos and start_pos > 1 then
            local prefix = compact:sub(1, start_pos - 1)
            local suffix = compact:sub(end_pos + 1):match("^%s*(.-)%s*$") or ""
            if prefix:find("[a-z]")
               and prefix:match("^[A-Za-z0-9]+$")
               and suffix:match("^%d+$") then
                return true
            end
        end
    end
    return false
end

local function is_fused_status_label_fragment_token(token)
    local bare = tostring(token or ""):match("^([A-Za-z0-9]+)[%.%!%?,:;]*$")
    if not bare or #bare < 2 or #bare > 6 then
        return false
    end
    if not bare:find("[a-z]") and not bare:find("%d") then
        return false
    end
    return bare:match("^[A-Za-z0-9]*[HMPVGEL]$") ~= nil
end

local function strip_fused_status_label_prefix(token)
    local raw = tostring(token or "")
    local bare, suffix = raw:match("^([A-Za-z0-9]+)([^A-Za-z0-9]*)$")
    if not bare then
        return raw
    end

    local single_prefix, remainder = bare:match("^([LHMVGEP])([A-Z][a-z].*)$")
    if single_prefix and remainder then
        return remainder .. (suffix or "")
    end

    for prefix_len = math.min(6, #bare - 1), 2, -1 do
        local prefix = bare:sub(1, prefix_len)
        local remainder = bare:sub(prefix_len + 1)
        if is_fused_status_label_fragment_token(prefix)
           and remainder:find("[a-z]") then
            return remainder .. (suffix or "")
        end
    end
    return raw
end

local INLINE_STATUS_VALUE_LABELS = {
    LV = true,
    HP = true,
    MP = true,
    V = true,
    P = true,
    G = true,
    E = true,
}

local INLINE_STATUS_SINGLE_LABELS = {
    L = true,
    H = true,
    M = true,
    V = true,
    P = true,
    G = true,
    E = true,
}

local function split_dialogue_token(token)
    local prefix, bare, suffix = tostring(token or ""):match("^([^A-Za-z0-9]*)([A-Za-z0-9]+)([^A-Za-z0-9]*)$")
    return prefix or "", bare, suffix or ""
end

local function is_numeric_dialogue_token(token)
    local _, bare = split_dialogue_token(token)
    return bare ~= nil and bare:match("^%d+$") ~= nil
end

local function is_status_label_cluster(token)
    token = tostring(token or "")
    if token == "" or token:find("[^A-Z]") then
        return false
    end
    if not token:match("^[GHMELPV]+$") then
        return false
    end
    for _, label in ipairs(STATUS_VALUE_LABELS) do
        if token:find(label, 1, true) then
            return true
        end
    end
    return false
end

local function is_spaced_status_value_fragment(compact)
    compact = compact_text(compact)
    if compact == "" or compact:find("[%.%!%?,'\"]") then
        return false
    end
    local clustered_name, clustered_label = compact:match("^([A-Z][A-Za-z0-9]*)%s+([A-Z]+)%s+[%d%s]+$")
    if clustered_name
       and #clustered_name <= 8
       and clustered_name:find("[a-z]")
       and is_status_label_cluster(clustered_label) then
        return true
    end
    for _, label in ipairs(STATUS_VALUE_LABELS) do
        local name = compact:match("^([A-Z][A-Za-z0-9]*)%s+" .. label .. "%s+[%d%s]+$")
        if name and #name <= 8 and name:find("[a-z]") then
            return true
        end
    end
    return false
end

local function is_spaced_status_name_value_fragment(compact)
    compact = compact_text(compact)
    local name = compact:match("^([A-Z][A-Za-z0-9]*)%s+%d+$")
    if name and #name <= 4 and name:find("[a-z]") then
        return true
    end

    local status_name = compact:match("^[GHMELPV]%s+([A-Z][A-Za-z0-9]*)$")
    return status_name ~= nil and #status_name <= 4 and status_name:find("[a-z]") ~= nil
end

local function is_fused_status_value_name_fragment(compact)
    compact = compact_text(compact)
    local labels, name = compact:match("^([GHMELPV]+)%d+([A-Z][A-Za-z0-9]*)$")
    return labels ~= nil
        and is_status_label_cluster(labels)
        and #name <= 8
        and name:find("[a-z]") ~= nil
end

local function is_multi_token_status_residue(compact)
    compact = compact_text(compact)
    if compact == "" or not compact:find("%s")
       or compact:find("[%.%!%?,'\"]") then
        return false
    end

    local token_count = 0
    local markers = 0
    local values = 0
    for token in compact:gmatch("%S+") do
        token_count = token_count + 1
        local marker = is_status_marker_fragment(token)
            or INLINE_STATUS_VALUE_LABELS[token] == true
            or is_fused_status_value_fragment(token)
        local value = token:match("^%d+$") ~= nil
            or token:match("^[GE]%d+$") ~= nil
            or is_fused_status_value_fragment(token)
        local tiny_name_fragment = #token <= 2
            and token:find("[a-z]") ~= nil
            and token:match("^[A-Za-z0-9]+$") ~= nil


        if marker then
            markers = markers + 1
        end
        if value then
            values = values + 1
        end
        if not marker and not value and not tiny_name_fragment then
            return false
        end
    end

    return token_count >= 3 and markers >= 1 and values >= 1
end


function M.is_passive_field_status_noise(dialogue)
    local compact = compact_text(dialogue)
    if compact == "" then
        return false
    end
    if is_fused_status_value_fragment(compact) then
        return true
    end
    if is_fused_status_label_fragment_token(compact) then
        return true
    end
    local label, tiny_suffix = compact:match("^([A-Z]+)%s+%d+([a-z][a-z]?)$")
    if label and INLINE_STATUS_VALUE_LABELS[label] and tiny_suffix then
        return true
    end
    if is_spaced_status_value_fragment(compact) or is_spaced_status_name_value_fragment(compact) then
        return true
    end
    if is_fused_status_value_name_fragment(compact) then
        return true
    end
    if compact:match("^[A-Z][A-Za-z]*[GE]%d+[GE]%d+%s+%d+[A-Z][A-Za-z]*$") then
        return true
    end
    if is_multi_token_status_residue(compact) then
        return true
    end
    if compact:find("%s") then
        return false
    end
    local numeric_wrapped_name = compact:match("^%d+([A-Z][A-Za-z]*)%d+$")
    if numeric_wrapped_name
       and #numeric_wrapped_name <= 8
       and numeric_wrapped_name:find("[a-z]") ~= nil then
        return true
    end
    if compact:upper() == "GOLD" then
        return true
    end
    if #compact <= 3 and compact:match("^[a-z][a-z0-9]*$") then
        return true
    end
    if #compact <= 8
       and compact:find("[a-z]") ~= nil
       and compact:match("^%d+[A-Z][A-Za-z0-9]*$") ~= nil then
        return true
    end
    return #compact <= 8
        and compact:find("[a-z]") ~= nil
        and compact:match("^[A-Z][A-Za-z0-9]*$") ~= nil
end

function M.upper_marker_for_lower_dialogue(upper, lower_dialogue)
    local lower = compact_text(lower_dialogue)
    if lower ~= "" then
        return lower
    end
    return tostring(upper or "")
end

local function add_set_value(set, ordered, value)
    value = compact_text(value)
    if value == "" or set[value] then return end
    set[value] = true
    ordered[#ordered + 1] = value
end

local function sorted_fragments_desc(values)
    local copy = {}
    for i = 1, #(values or {}) do
        copy[i] = values[i]
    end
    table.sort(copy, function(a, b)
        if #a == #b then return a < b end
        return #a > #b
    end)
    return copy
end

local function has_fragmented_status_context(rows, index, paired_rows)
    local labels = 0
    local values = 0
    local split_name_pair = false

    if paired_rows then
        local selected = tostring(rows[index] or ""):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
        local paired = tostring(paired_rows[index] or ""):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
        split_name_pair = selected ~= "" and paired ~= ""
            and (is_short_name_fragment(selected .. paired) or is_short_name_fragment(paired .. selected))
    end

    local function count_fragment(compact)
        if compact == "V" or compact == "P" or compact == "LV" or compact == "HP" or compact == "MP" then
            labels = labels + 1
        elseif is_status_marker_fragment(compact) then
            labels = labels + 1
        elseif compact:match("^%d+$") or compact:match("^[GE]%d+$") then
            values = values + 1
        end
    end

    for offset = -8, 8 do
        if offset ~= 0 then
            local compact = tostring(rows[index + offset] or ""):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
            count_fragment(compact)
            if paired_rows then
                local paired = tostring(paired_rows[index + offset] or ""):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
                count_fragment(paired)
            end
        end
    end
    return (labels >= 2 and values >= 1) or labels >= 3 or (split_name_pair and labels >= 1 and values >= 1)
end

local function has_fragmented_status_context_anywhere(rows, paired_rows)
    local labels = 0
    local values = 0
    local function count_fragment(compact)
        if compact == "V" or compact == "P" or compact == "LV" or compact == "HP" or compact == "MP" then
            labels = labels + 1
        elseif is_status_marker_fragment(compact) then
            labels = labels + 1
        elseif compact:match("^%d+$") or compact:match("^[GE]%d+$") then
            values = values + 1
        end
    end

    for i = 1, #(rows or {}) do
        local compact = tostring(rows[i] or ""):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
        count_fragment(compact)
        if paired_rows then
            local paired = tostring(paired_rows[i] or ""):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
            count_fragment(paired)
        end
    end
    return (labels >= 2 and values >= 1) or labels >= 3
end

local function add_numeric_status_fragments(set, decoded)
    local compact = compact_text(decoded)
    for label, value in compact:gmatch("([A-Z]+)%s*(%d+)") do
        if INLINE_STATUS_VALUE_LABELS[label] then
            set[value] = true
            for start_index = 1, #value do
                for end_index = start_index, #value do
                    set[value:sub(start_index, end_index)] = true
                end
            end
        end
    end
end

local function build_status_context(rows, paired_rows)
    local context = {
        has_status = has_fragmented_status_context_anywhere(rows, paired_rows),
        name_fragments = {},
        split_fragments = {},
        ordered_split_fragments = {},
        numeric_fragments = {},
    }
    local ordered_name_fragments = {}

    for i = 1, #(rows or {}) do
        local selected = compact_text(rows[i])
        local paired = compact_text(paired_rows and paired_rows[i] or "")

        add_numeric_status_fragments(context.numeric_fragments, selected)
        add_numeric_status_fragments(context.numeric_fragments, paired)
        add_numeric_status_fragments(context.numeric_fragments, selected .. paired)
        add_numeric_status_fragments(context.numeric_fragments, paired .. selected)

        if selected ~= "" and paired ~= "" then
            local joined = selected .. paired
            local reverse_joined = paired .. selected
            if is_status_name_token(joined) or is_status_name_token(reverse_joined) then
                context.has_status = true
                add_set_value(context.split_fragments, context.ordered_split_fragments, selected)
                add_set_value(context.split_fragments, context.ordered_split_fragments, paired)
                add_set_value(context.name_fragments, ordered_name_fragments, joined)
                add_set_value(context.name_fragments, ordered_name_fragments, reverse_joined)
            end
        end

        if context.has_status and is_status_name_token(selected) then
            add_set_value(context.name_fragments, ordered_name_fragments, selected)
        end
        if context.has_status and is_status_name_token(paired) then
            add_set_value(context.name_fragments, ordered_name_fragments, paired)
        end
    end

    context.ordered_split_fragments = sorted_fragments_desc(context.ordered_split_fragments)
    return context
end

local function strip_padded_status_suffix(decoded)
    local cleaned = tostring(decoded or "")
    local patterns = {
        "%s%s+LV%s*%d*$",
        "%s%s+HP%s*%d*$",
        "%s%s+MP%s*%d*$",
        "%s%s+G%d+$",
        "%s%s+E%d+$",
        "%s%s+[A-Z][A-Za-z0-9]?[A-Za-z0-9]?[A-Za-z0-9]?$",
    }
    cleaned = cleaned:gsub("%s%s+[A-Z][A-Za-z0-9]?[A-Za-z0-9]?[A-Za-z0-9]?%s+", " ")
    for _, pattern in ipairs(patterns) do
        cleaned = cleaned:gsub(pattern, "")
    end
    return cleaned:gsub("%s+$", "")
end

local function strip_derived_name_fragment_noise(decoded, context)
    local cleaned = tostring(decoded or "")
    if not context or not context.has_status then
        return cleaned
    end

    local compact = compact_text(cleaned)
    if compact:upper() == "GOLD" then
        return ""
    end
    if context.name_fragments[compact] or context.split_fragments[compact] then
        return ""
    end

    for _, fragment in ipairs(context.ordered_split_fragments or {}) do
        -- Avoid stripping a real "I am..." style line just because a one-letter
        -- hero-name fragment is visible in the status display.
        if #fragment >= 2 then
            local escaped = lua_pattern_escape(fragment)
            local prefix_pattern = "^%s*" .. escaped .. "%s+(.+)$"
            local remainder = cleaned:match(prefix_pattern)
            if remainder and remainder:find("[a-z]") then
                cleaned = remainder
            end

            local suffix_pattern = "^(.-)%s+" .. escaped .. "%s*$"
            local before = cleaned:match(suffix_pattern)
            if before and before:find("[a-z]") then
                cleaned = before
            end
        end
    end

    return cleaned:match("^%s*(.-)%s*$") or ""
end

local function is_numeric_status_slice(tokens, index, context)
    if not context or not context.numeric_fragments then
        return false
    end

    local prefix, bare, suffix = split_dialogue_token(tokens[index])
    if not bare or not bare:match("^%d+$") or prefix ~= "" or suffix ~= ""
       or not context.has_status then
        return false
    end

    local follows_completed_sentence = index == #tokens and index > 1
        and tostring(tokens[index - 1]):match("[%.%!%?][\"']?$") ~= nil
    if not context.numeric_fragments[bare] then
        return follows_completed_sentence
    end

    local candidate_count = 0
    for _, candidate in ipairs(tokens) do
        local candidate_prefix, candidate_bare, candidate_suffix = split_dialogue_token(candidate)
        if candidate_bare and candidate_bare:match("^%d+$")
           and candidate_prefix == "" and candidate_suffix == ""
           and context.numeric_fragments[candidate_bare] then
            candidate_count = candidate_count + 1
        end
    end
    if candidate_count >= 2 then
        return true
    end

    if #bare >= 2 and index > 1 and index < #tokens then
        local _, previous = split_dialogue_token(tokens[index - 1])
        local _, following = split_dialogue_token(tokens[index + 1])
        if previous and previous:lower() == "for" then
            return false
        end
        if following and following:upper() == "GOLD" then
            return false
        end
        return true
    end

    if follows_completed_sentence then
        return true
    end
    return false
end

local function strip_inline_status_fragment_noise(decoded, context)
    local cleaned = tostring(decoded or "")
    if not context or not context.has_status then
        return cleaned
    end

    local tokens = {}
    for token in cleaned:gmatch("%S+") do
        tokens[#tokens + 1] = token
    end

    local parts = {}
    local i = 1
    while i <= #tokens do
        local token = tokens[i]
        local _, bare = split_dialogue_token(token)

        if bare and is_status_marker_fragment(bare) then
            i = i + 1
        elseif bare
           and INLINE_STATUS_VALUE_LABELS[bare]
           and i < #tokens
           and is_numeric_dialogue_token(tokens[i + 1]) then
            i = i + 2
        elseif bare and is_numeric_status_slice(tokens, i, context) then
            i = i + 1
        elseif bare
           and bare:match("^%d+$")
           and i < #tokens
           and is_numeric_dialogue_token(tokens[i + 1]) then
            i = i + 2
        elseif bare
           and #bare == 1
           and INLINE_STATUS_SINGLE_LABELS[bare] then
            i = i + 1
        elseif not is_fused_status_label_fragment_token(token) then
            parts[#parts + 1] = strip_fused_status_label_prefix(token)
            i = i + 1
        else
            i = i + 1
        end
    end
    local joined = table.concat(parts, " "):gsub("%s+([%.%!%?,:;])", "%1")
    return joined:match("^%s*(.-)%s*$") or ""
end

local function strip_repeated_inline_single_status_noise(dialogue)
    local tokens = {}
    local noise_count = 0
    for token in tostring(dialogue or ""):gmatch("%S+") do
        tokens[#tokens + 1] = token
        local _, bare = split_dialogue_token(token)
        if bare and #bare == 1 and INLINE_STATUS_SINGLE_LABELS[bare] then
            noise_count = noise_count + 1
        end
    end
    if noise_count < 2 then
        return dialogue
    end

    local parts = {}
    for _, token in ipairs(tokens) do
        local _, bare = split_dialogue_token(token)
        if not (bare and #bare == 1 and INLINE_STATUS_SINGLE_LABELS[bare]) then
            parts[#parts + 1] = token
        end
    end
    return table.concat(parts, " "):gsub("%s+([%.%!%?,:;])", "%1")
end

local function has_nearby_status_marker(rows, index)
    for offset = -4, 4 do
        if offset ~= 0 then
            local neighbor = rows[index + offset]
            if neighbor and (M.is_status_text(neighbor) or is_status_marker_fragment(neighbor)) then
                return true
            end
        end
    end
    return has_fragmented_status_context(rows, index)
end

local function is_cross_nametable_status_fragment(candidate, candidate_rows, other_rows)
    local compact = tostring(candidate or ""):match("^%s*(.-)%s*$") or ""
    if compact == "" or compact:find("%s") or #compact > 8 or not compact:find("[a-z]") then
        return false
    end

    for i, selected in ipairs(candidate_rows) do
        if selected == compact then
            local other = other_rows[i] or ""
            if is_short_name_fragment(other .. selected) or is_short_name_fragment(selected .. other) then
                return has_nearby_status_marker(candidate_rows, i)
                    or has_nearby_status_marker(other_rows, i)
                    or has_fragmented_status_context(candidate_rows, i, other_rows)
            end
        end
    end
    return false
end

local function wants_numeric_dialogue_continuation(decoded)
    local compact = compact_text(decoded)
    return compact:match("[Ii]ncreases by$") ~= nil
        or compact:match("[Ii]ncrease by$") ~= nil
        or compact:match("reduced by$") ~= nil
        or compact:match("decreased by$") ~= nil
end

local function is_numeric_dialogue_continuation(decoded)
    local compact = compact_text(decoded)
    return compact:match("^%d+[%.,!%?]*$") ~= nil
end

local function read_dialogue_rows_for_base(scroll_tiles, start_row, base_nametable)
    start_row = start_row or 19
    local decoded_rows = {}
    for i = 0, 10 do
        local row = (start_row + i) % 30
        decoded_rows[#decoded_rows + 1] = M.decode_row(row, scroll_tiles, base_nametable)
    end
    return decoded_rows
end

local function read_status_context_rows_for_base(scroll_tiles, base_nametable)
    local decoded_rows = {}
    for row = 0, 18 do
        decoded_rows[#decoded_rows + 1] = M.decode_row(row, scroll_tiles, base_nametable)
    end
    return decoded_rows
end

local function strip_ppu_placeholder_noise(decoded)
    local cleaned = tostring(decoded or ""):gsub("%[GOLD%]", " ")
    cleaned = cleaned:gsub("%s+", " ")
    return cleaned:match("^%s*(.-)%s*$") or ""
end

local function filtered_dialogue_from_rows(decoded_rows, paired_rows, context_rows, paired_context_rows)
    local status_context = build_status_context(context_rows or decoded_rows, paired_context_rows or paired_rows)

    local function is_status_name_fragment(index, decoded)
        local paired = paired_rows and tostring(paired_rows[index] or ""):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
        local split_name_pair = paired ~= ""
            and (is_short_name_fragment(decoded .. paired) or is_short_name_fragment(paired .. decoded))
        if not is_short_name_fragment(decoded) and not split_name_pair then
            return false
        end

        return has_nearby_status_marker(decoded_rows, index)
            or (paired_rows and has_fragmented_status_context(decoded_rows, index, paired_rows))
            or (split_name_pair and has_fragmented_status_context_anywhere(context_rows, paired_context_rows))
    end

    local lines = {}
    for i, decoded in ipairs(decoded_rows) do
        local cleaned = strip_padded_status_suffix(decoded)
        cleaned = strip_derived_name_fragment_noise(cleaned, status_context)
        cleaned = strip_inline_status_fragment_noise(cleaned, status_context)
        cleaned = strip_ppu_placeholder_noise(cleaned)
        local fused_status_value = status_context.has_status
            and is_fused_status_value_fragment(cleaned)
        if cleaned ~= "" and cleaned:find("[a-z]")
           and not M.is_status_text(decoded)
           and not fused_status_value
           and not is_fused_status_label_fragment_token(cleaned)
           and not is_status_name_fragment(i, cleaned) then
            lines[#lines + 1] = cleaned
        elseif #lines > 0
           and is_numeric_dialogue_continuation(cleaned)
           and wants_numeric_dialogue_continuation(lines[#lines]) then
            lines[#lines + 1] = cleaned
        end
    end
    return table.concat(lines, " ")
end

local function read_dialogue_window_filtered_for_base(scroll_tiles, start_row, base_nametable, paired_rows)
    local decoded_rows = read_dialogue_rows_for_base(scroll_tiles, start_row, base_nametable)
    return filtered_dialogue_from_rows(decoded_rows, paired_rows), decoded_rows
end

function M.read_dialogue_window_filtered(scroll_tiles, start_row, base_nametable)
    local primary
    local primary_rows
    local result = primary

    -- BizHawk can report a transient PPUCTRL base bit that does not match the
    -- nametable order holding dialogue after Yes/No transitions. When the
    -- reported order misses the lower text, try the opposite order and keep the
    -- one with more lowercase dialogue.
    if base_nametable ~= nil then
        local alternate_base = (math.floor(tonumber(base_nametable) or 0) + 1) % 2
        primary_rows = read_dialogue_rows_for_base(scroll_tiles, start_row, base_nametable)
        local alternate_rows = read_dialogue_rows_for_base(scroll_tiles, start_row, alternate_base)
        local primary_context_rows = read_status_context_rows_for_base(scroll_tiles, base_nametable)
        local alternate_context_rows = read_status_context_rows_for_base(scroll_tiles, alternate_base)
        primary = filtered_dialogue_from_rows(primary_rows, alternate_rows, primary_context_rows, alternate_context_rows)
        result = primary
        local alternate = filtered_dialogue_from_rows(alternate_rows, primary_rows, alternate_context_rows, primary_context_rows)
        if is_cross_nametable_status_fragment(primary, primary_rows, alternate_rows) then
            primary = ""
            result = ""
        end
        if dialogue_score(alternate) > dialogue_score(primary)
           and not is_cross_nametable_status_fragment(alternate, alternate_rows, primary_rows) then
            result = alternate
        end
    else
        primary, primary_rows = read_dialogue_window_filtered_for_base(scroll_tiles, start_row, base_nametable)
        result = primary
    end

    if M.is_status_equipment_text(result) then
        return ""
    end
    return strip_repeated_inline_single_status_noise(result)
end

local function dialogue_debug_rows(rows)
    local parts = {}
    for index, row in ipairs(rows or {}) do
        local compact = compact_text(row)
        if compact ~= "" then
            parts[#parts + 1] = string.format("%d:%q", index, compact)
        end
    end
    return table.concat(parts, "|")
end

local function dialogue_debug_numbers(context)
    local values = {}
    for value in pairs((context and context.numeric_fragments) or {}) do
        values[#values + 1] = value
    end
    table.sort(values, function(a, b)
        if #a == #b then return a < b end
        return #a < #b
    end)
    return table.concat(values, ",")
end

function M.describe_dialogue_filter_state(scroll_tiles, start_row, base_nametable)
    local primary_base = math.floor(tonumber(base_nametable) or 0) % 2
    local alternate_base = (primary_base + 1) % 2
    local primary_rows = read_dialogue_rows_for_base(scroll_tiles, start_row, primary_base)
    local alternate_rows = read_dialogue_rows_for_base(scroll_tiles, start_row, alternate_base)
    local primary_context_rows = read_status_context_rows_for_base(scroll_tiles, primary_base)
    local alternate_context_rows = read_status_context_rows_for_base(scroll_tiles, alternate_base)

    local function describe(base, rows, paired_rows, context_rows, paired_context_rows)
        local context = build_status_context(context_rows, paired_context_rows)
        local filtered = filtered_dialogue_from_rows(
            rows, paired_rows, context_rows, paired_context_rows)
        return string.format(
            "base=%d has_status=%s numbers={%s} rows={%s} context={%s} filtered=%q",
            base,
            tostring(context.has_status),
            dialogue_debug_numbers(context),
            dialogue_debug_rows(rows),
            dialogue_debug_rows(context_rows),
            filtered)
    end

    return describe(
        primary_base, primary_rows, alternate_rows,
        primary_context_rows, alternate_context_rows)
        .. " || "
        .. describe(
            alternate_base, alternate_rows, primary_rows,
            alternate_context_rows, primary_context_rows)
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
    text = tostring(text or "")
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

    local compact = text:gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
    if not compact:find("[%.%!%?,'\"]") then
        if compact:match("^[VP]%s+%d+%s+[A-Za-z0-9]*HP%s+%d+%s+[A-Za-z0-9]*MP%s+%d+%s+[A-Za-z0-9]*G%d+%s+[A-Za-z0-9]*E%d+") then
            return true
        end
        if compact:match("^[A-Z]%s+[A-Za-z0-9]*H%s+[A-Za-z0-9]*M%s+[A-Za-z0-9]*G%s+[A-Za-z0-9]*E%s+%d+%s+%d+%s+[A-Z][A-Za-z0-9]*$") then
            return true
        end
        if compact:match("^[A-Za-z0-9]*H%s+[A-Za-z0-9]*M%s+[A-Za-z0-9]*G%s+[A-Za-z0-9]*E%s+%d+%s+%d+%s+[A-Z][A-Za-z0-9]*$") then
            return true
        end
    end
    if compact:match("^[A-Z][A-Za-z0-9]*%s+LV%s+%d+$") then
        return true
    end
    if compact:match("^%S+%s+V%s+P%s+P%s+%d+%s+%d+%s+%S+%s+LV%s+%d+$") then
        return true
    end

    return letters_only:find("VLPHPMGE") ~= nil
end

function M.is_status_equipment_text(text)
    text = tostring(text or "")
    local compact = text:gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
    if #compact == 0 or #compact > 100 then
        return false
    end
    local weapon_pos = compact:find("WEAPON:", 1, true)
    local armor_pos = compact:find("ARMOR:", 1, true)
    return weapon_pos == 1 and armor_pos ~= nil and armor_pos > weapon_pos
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
    return read_ppu_range(PPU_NT0, SCREEN_WIDTH * SCREEN_HEIGHT)
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
