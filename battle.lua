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
local HERO_STOPSPELL_MASK = 0x10
local HERO_SLEEP_MASK = 0x80

local function has_mask(flags, mask)
    local value = math.floor(tonumber(flags) or 0)
    return value % (mask * 2) >= mask
end

local function complete_prefix_without_coherence_check(text)
    local s = tostring(text or "")
    local last_punctuation = nil
    for i = 1, #s do
        local ch = s:sub(i, i)
        if ch == "." or ch == "!" or ch == "?" then
            last_punctuation = i
        end
    end
    if not last_punctuation then
        return ""
    end
    local prefix = s:sub(1, last_punctuation):match("^%s*(.-)%s*$") or ""
    if prefix:find("[a-z]") then
        return prefix
    end
    return ""
end

local function drop_truncated_damage_prefix(text, phrase)
    local _, _, before, after = text:find("^(.-)" .. phrase .. "%s+([A-Z].*)$")
    if not after then
        return text
    end

    local complete_prefix = complete_prefix_without_coherence_check(before)
    after = after:match("^%s*(.-)%s*$") or after
    if complete_prefix ~= "" then
        return complete_prefix .. " " .. after
    end
    return after
end

function M.get_menu_item(x, y)
    local row = ITEMS[y]
    if row then
        return row[x]
    end
    return nil
end

function M.is_spell_screen_text(text, spell_entries)
    local upper = tostring(text or ""):upper()
    if upper == "" then
        return false
    end

    for _, spell in ipairs(spell_entries or {}) do
        local name = tostring(spell.name or ""):upper()
        if name ~= "" and upper:find(name, 1, true) then
            return true
        end
    end
    return false
end

function M.is_hero_asleep(combat_flags)
    return has_mask(combat_flags, HERO_SLEEP_MASK)
end

function M.is_hero_stopspelled(combat_flags)
    return has_mask(combat_flags, HERO_STOPSPELL_MASK)
end

function M.describe_hero_status_change(old_flags, new_flags)
    local messages = {}
    local old_asleep = M.is_hero_asleep(old_flags)
    local new_asleep = M.is_hero_asleep(new_flags)
    local old_stopspelled = M.is_hero_stopspelled(old_flags)
    local new_stopspelled = M.is_hero_stopspelled(new_flags)

    if old_asleep ~= new_asleep then
        messages[#messages + 1] = new_asleep and "Asleep." or "Awake."
    end
    if old_stopspelled ~= new_stopspelled then
        messages[#messages + 1] = new_stopspelled and "Spells blocked." or "Spells restored."
    end

    return table.concat(messages, " ")
end

function M.spell_menu_status_prefix(combat_flags)
    if M.is_hero_stopspelled(combat_flags) then
        return "Spells blocked. "
    end
    return ""
end

function M.describe_spell_selection(selection, combat_flags, include_intro)
    local text = tostring(selection or "")
    if not include_intro then
        return text
    end
    if M.is_hero_stopspelled(combat_flags) then
        return M.spell_menu_status_prefix(combat_flags) .. text
    end
    return "Spells. " .. text
end

function M.describe_spell_command_unavailable(combat_flags, spell_count, hero_state, opts)
    local ignore_stopspell = opts and opts.ignore_stopspell
    if not ignore_stopspell and M.is_hero_stopspelled(combat_flags) then
        return "Spells blocked."
    end
    if tonumber(spell_count) == 0 then
        local level = tonumber(hero_state and hero_state.level) or 0
        local mp = tonumber(hero_state and hero_state.mp) or 0
        if level >= 3 or mp > 0 then
            return "Spells blocked."
        end
        return "Spells. Empty."
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
    normalized = normalized:gsub("Experience%s+Gold%s+increases", "Experience increases")
    normalized = normalized:gsub("GOLD%s+Gold%s+increases", "GOLD increases")
    normalized = normalized:gsub("Thy%s+([A-Za-z%s]+)%s+Gold%s+(increases?%s+by)", "Thy %1 %2")

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

    -- When a damage line is cut off and the next action/reward sentence begins,
    -- drop the incomplete damage fragment. Preserve any already-complete action
    -- sentence before it so one-hit kills still speak "Bill attacks!".
    normalized = drop_truncated_damage_prefix(normalized, "reduced by")
    normalized = drop_truncated_damage_prefix(normalized, "decreased by")

    -- Border redraw noise often shows up as dot runs between real words.
    normalized = normalized:gsub("%.%.+", " ")
    -- Horizontal nametable alignment can place a border dot directly after a
    -- word while the battle window redraws. These two forms are continuations,
    -- not sentence boundaries.
    normalized = normalized:gsub("Hit%.%s+Points", "Hit Points")
    normalized = normalized:gsub("(%l)%.%s+(%l)", "%1 %2")
    normalized = normalized:gsub("(%a)%s+%.%s+(%a)", "%1 %2")
    normalized = normalized:gsub("%s+%.([A-Z])", " %1")
    normalized = normalized:gsub("%s+%.([a-z])", " %1")
    normalized = normalized:gsub("([%.!?])%s+%.", "%1")

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

function M.complete_sentence_prefix(text)
    local s = tostring(text or "")
    if s == "" then
        return ""
    end

    local last_punctuation = nil
    for i = 1, #s do
        local ch = s:sub(i, i)
        if ch == "." or ch == "!" or ch == "?" then
            last_punctuation = i
        end
    end

    if not last_punctuation then
        return ""
    end

    local prefix = s:sub(1, last_punctuation):match("^%s*(.-)%s*$") or ""
    if prefix ~= "" and M.is_coherent_dialogue(prefix) then
        return prefix
    end
    return ""
end

function M.is_fast_action_dialogue(text)
    local s = tostring(text or "")
    if s == "" then
        return false
    end

    if s:find("draws near", 1, true)
        or s:find("Thou hast done well", 1, true)
        or s:find("Experience", 1, true)
        or s:find("GOLD", 1, true)
        or s:find("Gold", 1, true) then
        return false
    end

    local lower = s:lower()
    return s:find("attacks", 1, true) ~= nil
        or s:find("Hit Point", 1, true) ~= nil
        or s:find("Hit Points", 1, true) ~= nil
        or s:find("reduced by", 1, true) ~= nil
        or s:find("decreased by", 1, true) ~= nil
        or lower:find("miss", 1, true) ~= nil
        or lower:find("dodg", 1, true) ~= nil
end

function M.fast_action_prefix(text)
    local s = tostring(text or "")
    local best = ""

    for i = 1, #s do
        local ch = s:sub(i, i)
        if ch == "." or ch == "!" or ch == "?" then
            local prefix = s:sub(1, i):match("^%s*(.-)%s*$") or ""
            if prefix ~= ""
                and M.is_coherent_dialogue(prefix)
                and M.is_fast_action_dialogue(prefix) then
                best = prefix
            end
        end
    end

    return best
end

return M
