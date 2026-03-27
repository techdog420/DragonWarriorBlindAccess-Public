-- battle.lua
-- Battle command menu helpers.
--
-- Dragon Warrior's battle command screen uses a different cursor mapping than
-- the field command menu even though it reuses the same cursor RAM/header
-- mechanics. Keep the mapping isolated here so battle handling stays separate.

local M = {}

local ITEMS = {
    [0] = {[0] = "FIGHT", [1] = "SPELL"},
    [1] = {[0] = "RUN",   [1] = "ITEM"},
}
local OVERLAP_MIN_LEN = 8

function M.get_menu_item(x, y)
    local row = ITEMS[y]
    if row then
        return row[x]
    end
    return nil
end

function M.normalize_dialogue(text)
    if text == "" then
        return text
    end

    local normalized = text

    -- The battle/result lower window can pick up stale gold-macro bytes from
    -- reused nametable rows. Preserve the real reward line, then scrub the
    -- remaining macro placeholders from battle-log text.
    normalized = normalized:gsub("%[GOLD%]%s*increas", "Gold increas")
    normalized = normalized:gsub("%[GOLD%]", "")

    -- The battle command prompt has dedicated menu speech and should not be
    -- appended to the log narration. If both sides are present, keep the
    -- already-visible battle text before the prompt. If the prompt is the
    -- prefix to a fresh action line, keep the trailing action text instead.
    local prompt_start, prompt_end = normalized:find("Command%?")
    if prompt_start then
        local before = normalized:sub(1, prompt_start - 1):match("^%s*(.-)%s*$") or ""
        local after = normalized:sub(prompt_end + 1):match("^%s*(.-)%s*$") or ""
        if before ~= "" and before:find("[a-z]") then
            normalized = before
        else
            normalized = after
        end
    end

    -- When a damage line is cut off and the next action sentence begins, drop
    -- the incomplete prefix rather than reading both mashed together.
    normalized = normalized:gsub("^.-reduced by%s+([A-Z].*)$", "%1")
    normalized = normalized:gsub("^.-decreased by%s+([A-Z].*)$", "%1")

    -- Border redraw noise often shows up as dot runs between real words.
    normalized = normalized:gsub("%.%.+", " ")
    normalized = normalized:gsub("%s+%.([A-Z])", " %1")
    normalized = normalized:gsub("%s+%.([a-z])", " %1")

    normalized = normalized:gsub("^%.%s*", "")
    normalized = normalized:gsub("%s+", " ")
    normalized = normalized:match("^%s*(.-)%s*$") or ""

    return normalized
end

function M.extract_new_text(old_text, new_text)
    local old = tostring(old_text or "")
    local new = tostring(new_text or "")

    if new == "" then
        return ""
    end
    if old == "" then
        return new
    end
    if new == old then
        return ""
    end

    -- Battle windows often scroll a previously spoken sentence fragment into
    -- a fresh page. If the whole new page is already contained in the prior
    -- page, there is nothing new to say.
    if old:find(new, 1, true) then
        return ""
    end

    -- Strip only substantial prefix overlap. The generic dialogue matcher is
    -- too permissive for battle pages and can splice unrelated sentences
    -- together on short accidental matches.
    for start = 1, #old do
        local suffix = old:sub(start)
        if #suffix >= OVERLAP_MIN_LEN and new:sub(1, #suffix) == suffix then
            local remainder = new:sub(#suffix + 1)
            remainder = remainder:match("^%s*(.-)%s*$") or remainder
            return remainder
        end
    end

    return new
end

function M.is_coherent_dialogue(text)
    local s = tostring(text or "")
    if s == "" then
        return false
    end
    if not s:find("[a-z]") then
        return false
    end
    if not s:match("[%.!?]$") then
        return false
    end
    -- Mid-word lowercase->uppercase joins like "ntsThe" are a reliable sign
    -- that we caught the page before the rows were assembled coherently.
    if s:find("%l%u") then
        return false
    end
    -- Split rows also produce stray one-letter tokens like "T", "d", "i".
    for token in s:gmatch("[A-Za-z']+") do
        if #token == 1 and token ~= "A" and token ~= "I" and token ~= "a" then
            return false
        end
    end
    return true
end

return M
