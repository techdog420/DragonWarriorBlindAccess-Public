-- merchant.lua
-- Dedicated merchant/shop screen detection and summarization.
--
-- Dragon Warrior's merchant interface is neither normal dialogue nor a
-- standard command sub-menu. It mixes the player's status panel with a list
-- of offered equipment, spanning rows that the normal lower/upper dialogue
-- readers split apart. This module detects that layout and produces a stable,
-- readable summary.

local items = require "items"
local snapshot = require "game_snapshot"
local text = require "text"
local chars = require "chars"

local M = {}

local ROW_START = 15
local ROW_END = 29

local STATUS_TOKENS = {
    LV = true,
    HP = true,
    MP = true,
    G = true,
    E = true,
}

local CURSOR_TILES = {
    [0x42] = true,
    [0x43] = true,
}

local catalog_cache = nil

local function row_text(rows, row)
    return rows[row] or rows[row - ROW_START + 1] or ""
end

local function get_catalog_entries()
    if catalog_cache then
        return catalog_cache
    end

    local entries = {}
    for _, name in ipairs(items.get_equipment_catalog_names()) do
        local tokens = {}
        for token in name:gmatch("%S+") do
            tokens[#tokens + 1] = token
        end
        entries[#entries + 1] = {
            name = name,
            tokens = tokens,
        }
    end

    table.sort(entries, function(a, b)
        if #a.tokens ~= #b.tokens then
            return #a.tokens > #b.tokens
        end
        return a.name < b.name
    end)

    catalog_cache = entries
    return catalog_cache
end

local function split_words(str)
    local words = {}
    for token in tostring(str or ""):gmatch("[A-Za-z']+") do
        words[#words + 1] = token
    end
    return words
end

local function match_offer_prefix(fragment)
    local words = split_words(fragment)
    if #words == 0 then
        return nil
    end

    local matched = nil
    for _, entry in ipairs(get_catalog_entries()) do
        if #words <= #entry.tokens then
            local ok = true
            for i = 1, #words do
                if entry.tokens[i] ~= words[i] then
                    ok = false
                    break
                end
            end
            if ok then
                if #words == #entry.tokens then
                    return entry.name
                end
                matched = matched or entry.name
            end
        end
    end

    return matched
end

local function extract_status_marker_count(rows)
    local seen = {}
    for row = ROW_START, ROW_END do
        local line = row_text(rows, row)
        for token in line:gmatch("[A-Za-z']+") do
            if STATUS_TOKENS[token] then
                seen[token] = true
            end
        end
    end

    local count = 0
    for token in pairs(seen) do
        if STATUS_TOKENS[token] then
            count = count + 1
        end
    end
    return count
end

local function extract_offer_names(rows)
    local words = {}
    for row = ROW_START, ROW_END do
        local line = row_text(rows, row)
        for token in line:gmatch("[A-Za-z']+") do
            if not STATUS_TOKENS[token] then
                words[#words + 1] = token
            end
        end
    end

    local offers = {}
    local seen = {}
    local catalog = get_catalog_entries()
    local i = 1

    while i <= #words do
        local matched = nil
        for _, entry in ipairs(catalog) do
            if i + #entry.tokens - 1 <= #words then
                local ok = true
                for j = 1, #entry.tokens do
                    if words[i + j - 1] ~= entry.tokens[j] then
                        ok = false
                        break
                    end
                end
                if ok then
                    matched = entry
                    break
                end
            end
        end

        if matched then
            if not seen[matched.name] then
                seen[matched.name] = true
                offers[#offers + 1] = matched.name
            end
            i = i + #matched.tokens
        else
            i = i + 1
        end
    end

    return offers
end

function M.read_rows()
    local rows = {}
    for row = ROW_START, ROW_END do
        rows[row] = text.decode_row(row)
    end
    return rows
end

local function read_price_for_row(row)
    local NT0 = 0x2000
    local NT1 = 0x2400
    local W = 32
    local digits = {}

    -- Merchant prices live in the left side of NT1 on the selected item's row.
    -- Example from live dump:
    --   Bamboo Pole   -> NT1 c3=01 c4=00  => 10
    --   Club          -> NT1 c3=06 c4=00  => 60
    --   Copper Sword  -> NT1 c2=01 c3=08 c4=00 => 180
    for col = 0, 7 do
        local b = ppu.readbyte(NT1 + row * W + col)
        if b >= 0 and b <= 9 then
            digits[#digits + 1] = tostring(b)
        elseif #digits > 0 then
            break
        end
    end

    if #digits == 0 then
        return nil
    end

    return tonumber(table.concat(digits))
end

function M.get_cursor_offer()
    local NT0 = 0x2000
    local NT1 = 0x2400
    local W = 32

    for row = ROW_START, ROW_END do
        for col = 0, W - 1 do
            local b = ppu.readbyte(NT0 + row * W + col)
            if CURSOR_TILES[b] then
                local bytes = {}
                for x = col + 1, W - 1 do
                    bytes[#bytes + 1] = ppu.readbyte(NT0 + row * W + x)
                end
                for x = 0, W - 1 do
                    bytes[#bytes + 1] = ppu.readbyte(NT1 + row * W + x)
                end
                local fragment = chars.decode_bytes(bytes):match("^%s*(.-)%s*$") or ""
                local selection = match_offer_prefix(fragment)
                if selection then
                    return {
                        name = selection,
                        price = read_price_for_row(row),
                        row = row,
                    }
                end
            end
        end
    end

    return nil
end

function M.get_cursor_selection()
    local offer = M.get_cursor_offer()
    return offer and offer.name or nil
end

function M.analyze_rows(rows, opts)
    opts = opts or {}

    local nonempty_lines = {}
    for row = ROW_START, ROW_END do
        local line = row_text(rows, row)
        if line ~= "" then
            nonempty_lines[#nonempty_lines + 1] = line
        end
    end

    local raw_text = table.concat(nonempty_lines, " | ")
    local offers = extract_offer_names(rows)
    local status_marker_count = extract_status_marker_count(rows)
    local active = status_marker_count >= 4 and #offers >= 2

    local summary = nil
    if active then
        local parts = {"Merchant."}
        if opts.gold ~= nil then
            parts[#parts + 1] = "Gold " .. tostring(opts.gold) .. "."
        end
        parts[#parts + 1] = "Offered: " .. table.concat(offers, ", ") .. "."
        summary = table.concat(parts, " ")
    end

    return {
        active = active,
        raw_text = raw_text,
        offers = offers,
        status_marker_count = status_marker_count,
        summary = summary,
    }
end

function M.analyze_current_screen()
    return M.analyze_rows(M.read_rows(), {
        gold = snapshot.gold,
    })
end

return M
