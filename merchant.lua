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

local SCREEN_WIDTH = 32
local SCREEN_HEIGHT = 30
local ROW_START = 0
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

local ACTION_PROMPT_SELECTIONS = {
    [0] = "Buy",
    [1] = "Sell",
}

local FIELD_COMMAND_TOKENS = {
    TALK = true,
    SPELL = true,
    STATUS = true,
    ITEM = true,
    STAIRS = true,
    DOOR = true,
    SEARCH = true,
    TAKE = true,
}

local catalog_cache = nil

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

local function row_text(rows, row)
    return rows[row] or rows[row - ROW_START + 1] or ""
end

local function get_scroll_context(opts)
    opts = opts or {}

    -- Shop screens are menu overlays in screen coordinates. The game may leave
    -- field scroll registers non-zero underneath them, so the default reader
    -- must not apply live field scroll unless a caller explicitly asks for it.
    local scroll_tiles = opts.scroll_tiles
    if scroll_tiles == nil then
        scroll_tiles = 0
    end

    local base_nametable = opts.base_nametable
    if base_nametable == nil then
        base_nametable = 0
    end

    local vertical_scroll_tiles = opts.vertical_scroll_tiles
    if vertical_scroll_tiles == nil then
        vertical_scroll_tiles = 0
    end

    return {
        label = opts.label,
        scroll_tiles = math.floor(tonumber(scroll_tiles) or 0) % SCREEN_WIDTH,
        base_nametable = math.floor(tonumber(base_nametable) or 0) % 2,
        vertical_scroll_tiles = math.floor(tonumber(vertical_scroll_tiles) or 0) % SCREEN_HEIGHT,
    }
end

local function nametable_row_for_visible_row(visible_row, ctx)
    return (visible_row + ctx.vertical_scroll_tiles) % SCREEN_HEIGHT
end

local function read_visible_virtual_row(visible_row, ctx)
    local NT0 = 0x2000
    local NT1 = 0x2400
    local bytes = {}
    local nametable_row = nametable_row_for_visible_row(visible_row, ctx)

    -- Return two screen-widths in visible order. The first 32 bytes are the
    -- actual visible row; the next 32 preserve text that wraps into the paired
    -- horizontal nametable, which is where shop prices can live.
    local col = 0
    while col < (SCREEN_WIDTH * 2) do
        local virtual_col = ctx.scroll_tiles + col
        local nt_col = virtual_col % SCREEN_WIDTH
        local nt_index = (ctx.base_nametable + math.floor(virtual_col / SCREEN_WIDTH)) % 2
        local nt_base = (nt_index == 0) and NT0 or NT1
        local run_len = math.min((SCREEN_WIDTH * 2) - col, SCREEN_WIDTH - nt_col)
        append_bytes(bytes, read_ppu_range(nt_base + nametable_row * SCREEN_WIDTH + nt_col, run_len))
        col = col + run_len
    end

    return bytes
end

local function extract_price(fragment)
    local digits = tostring(fragment or ""):match("(%d+)")
    return digits and tonumber(digits) or nil
end

local function get_catalog_entries()
    if catalog_cache then
        return catalog_cache
    end

    local entries = {}
    local names = items.get_shop_catalog_names and items.get_shop_catalog_names()
        or items.get_equipment_catalog_names()
    for _, name in ipairs(names) do
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

local function has_field_command_backdrop(rows)
    local seen = {}
    local count = 0

    for row = ROW_START, ROW_END do
        local line = row_text(rows, row)
        for token in tostring(line or ""):gmatch("[A-Za-z']+") do
            if FIELD_COMMAND_TOKENS[token] and not seen[token] then
                seen[token] = true
                count = count + 1
            end
        end
    end

    -- A held ITEM list keeps the normal field command menu visible behind the
    -- inventory. Merchant action prompts can leave a few command words visible,
    -- but not the full command backdrop.
    return count >= 6 and (seen.TALK or seen.STATUS or seen.STAIRS)
end

local function has_shop_offer_layout_evidence(rows)
    for row = ROW_START, ROW_END do
        local line = row_text(rows, row)

        -- Tool and equipment shops usually show a numeric price on at least one
        -- offer row. Held ITEM lists do not price inventory entries.
        if extract_price(line) and match_offer_prefix(line) then
            return true
        end

        local saw_status = false
        local saw_offer_fragment = false
        for token in tostring(line or ""):gmatch("[A-Za-z']+") do
            if STATUS_TOKENS[token] then
                saw_status = true
            elseif not FIELD_COMMAND_TOKENS[token]
                   and token:match("^[A-Z]")
                   and #token > 1 then
                saw_offer_fragment = true
            end
        end

        -- Older/shop-scroll layouts split offers across status rows, e.g.
        -- "LV 1 Pole" or "MP 18 Scale". That is strong shop evidence even when
        -- the active buy prompt is not visible in the current scan.
        if saw_status and saw_offer_fragment then
            return true
        end
    end

    return false
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

local function has_buy_prompt(raw_text)
    local lower = tostring(raw_text or ""):lower()
    return lower:find("what dost thou wish", 1, true) ~= nil
        and lower:find("to buy", 1, true) ~= nil
end

local function row_has_word(rows, wanted)
    for row = ROW_START, ROW_END do
        local line = row_text(rows, row)
        for token in tostring(line or ""):gmatch("[A-Za-z']+") do
            if token == wanted then
                return true
            end
        end
    end
    return false
end

local function has_action_prompt(raw_text, rows)
    local lower = tostring(raw_text or ""):lower()
    return lower:find("what can i do for", 1, true) ~= nil
        and row_has_word(rows, "BUY")
        and row_has_word(rows, "SELL")
end

local function has_discard_prompt(raw_text)
    local lower = tostring(raw_text or ""):lower()
    return lower:find("must now disc", 1, true) ~= nil
        and lower:find("other item", 1, true) ~= nil
        and lower:find("what shall th", 1, true) ~= nil
end

local function get_action_selection(cursor_y)
    local y = tonumber(cursor_y)
    if y == nil then
        return nil
    end
    return ACTION_PROMPT_SELECTIONS[y]
end

function M.read_rows(opts)
    local ctx = get_scroll_context(opts)
    local rows = {}
    for visible_row = ROW_START, ROW_END do
        local nametable_row = nametable_row_for_visible_row(visible_row, ctx)
        rows[visible_row] = text.decode_row(nametable_row, ctx.scroll_tiles, ctx.base_nametable)
    end
    return rows
end

function M.get_cursor_offer(opts)
    local ctx = get_scroll_context(opts)

    for visible_row = ROW_START, ROW_END do
        local row_bytes = read_visible_virtual_row(visible_row, ctx)
        for col = 0, SCREEN_WIDTH - 1 do
            local b = row_bytes[col + 1]
            if CURSOR_TILES[b] then
                local bytes = {}
                for x = col + 2, #row_bytes do
                    bytes[#bytes + 1] = row_bytes[x]
                end
                local fragment = chars.decode_bytes(bytes):match("^%s*(.-)%s*$") or ""
                local selection = match_offer_prefix(fragment)
                local price = extract_price(fragment)
                -- The premium Cantlin row contains only the shared "Silver"
                -- prefix and its price; the item name continues on the next row.
                if selection == "Silver Harp" and price == 14800 then
                    selection = "Silver Shield"
                end
                if selection then
                    return {
                        name = selection,
                        price = price,
                        row = visible_row,
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
    local buy_prompt = has_buy_prompt(raw_text)
    local discard_prompt = has_discard_prompt(raw_text)
    local action_prompt = not discard_prompt and has_action_prompt(raw_text, rows)
    local action_selection = action_prompt and get_action_selection(opts.cursor_y) or nil
    local command_backdrop = has_field_command_backdrop(rows)
    local offer_layout_evidence = has_shop_offer_layout_evidence(rows)
    local offer_list_active = not discard_prompt
        and not command_backdrop
        and #offers >= 2
        and (buy_prompt or (status_marker_count >= 4 and offer_layout_evidence))
    local active = offer_list_active or action_prompt

    local summary = nil
    if action_prompt then
        local parts = {"Merchant. Buy or Sell."}
        if action_selection then
            parts[#parts + 1] = action_selection .. "."
        end
        summary = table.concat(parts, " ")
    elseif offer_list_active then
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
        buy_prompt = buy_prompt,
        discard_prompt = discard_prompt,
        action_prompt = action_prompt,
        action_selection = action_selection,
        mode = action_prompt and "action" or (offer_list_active and "offers" or nil),
        summary = summary,
    }
end

local function score_inactive_info(info)
    local score = 0
    if info.discard_prompt then
        score = score + 1000
    end
    if info.buy_prompt then
        score = score + 100
    end
    score = score + ((info.offers and #info.offers or 0) * 10)
    score = score + (tonumber(info.status_marker_count) or 0)
    score = score + text.dialogue_score(info.raw_text)
    return score
end

local function analyze_context(opts)
    local ctx = get_scroll_context(opts)
    local info = M.analyze_rows(M.read_rows(ctx), {
        gold = snapshot.gold,
        cursor_y = snapshot.cursor_y,
    })
    info.context = ctx
    info.context_label = ctx.label
    return info
end

function M.analyze_current_screen(opts)
    if opts and type(opts.contexts) == "table" then
        local fallback = nil
        local fallback_score = nil
        for _, ctx in ipairs(opts.contexts) do
            local info = analyze_context(ctx)
            if info.active or info.discard_prompt then
                return info
            end

            local score = score_inactive_info(info)
            if not fallback or score > fallback_score then
                fallback = info
                fallback_score = score
            end
        end

        return fallback or analyze_context(nil)
    end

    return analyze_context(opts)
end

return M
