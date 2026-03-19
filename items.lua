-- items.lua
-- Item, equipment, and spell lookup tables for Dragon Warrior.
--
-- Provides functions to read inventory, equipment, and spells from RAM
-- and convert them to human-readable names. Used by the STATUS and ITEM
-- sub-menu handlers in main.lua, and by the S (stats) hotkey.
--
-- Item encoding: RAM 0x00C1-0x00C4 holds 8 items in 4 bytes, 2 per byte
-- (high nybble = even slot, low nybble = odd slot). Values 0x1-0xF map
-- to specific items; 0x0 = empty slot.
--
-- Equipment encoding: RAM 0x00BE packs weapon (bits 7-5), armor (bits 4-2),
-- and shield (bits 1-0) into a single byte.  Format: %WWWAAASS
--
-- Spell encoding: RAM 0x00CE is a bitfield of 8 spells (bits 0-7).
-- RAM 0x00CF bits 0-1 hold 2 more spells (Healmore, Hurtmore).
--
-- Sources: DataCrystal RAM map, nmikstas/dragon-warrior-disassembly

local addr = require "addresses"

local M = {}

-- ============================================================
-- Item Nybble Lookup (DataCrystal RAM map)
-- ============================================================
-- Each nybble in 0x00C1-0x00C4 maps to one item. The high nybble
-- of each byte is the even-numbered slot, low nybble is the odd slot.
-- Example: byte 0x00C1 = 0x1F means slot 0 = Torch, slot 1 = Herb.

local ITEM_NAMES = {
    -- [0x0] = nil (empty slot)
    [0x1] = "Torch",
    [0x2] = "Fairy Water",
    [0x3] = "Wings",
    [0x4] = "Dragon's Scale",
    [0x5] = "Fairy Flute",
    [0x6] = "Fighter's Ring",
    [0x7] = "Erdrick's Token",
    [0x8] = "Gwaelin's Love",
    [0x9] = "Cursed Belt",
    [0xA] = "Silver Harp",
    [0xB] = "Death Necklace",
    [0xC] = "Stones of Sunlight",
    [0xD] = "Staff of Rain",
    [0xE] = "Rainbow Drop",
    [0xF] = "Herb",
}

-- ============================================================
-- Equipment Lookup (dragon-warrior-disassembly)
-- ============================================================
-- RAM 0x00BE format: %WWWAAASS
--   Bits 7-5 (mask 0xE0): Weapon index (0-7)
--   Bits 4-2 (mask 0x1C): Armor index (0-7)
--   Bits 1-0 (mask 0x03): Shield index (0-3)

local WEAPON_NAMES = {
    [0x00] = nil,              -- None
    [0x20] = "Bamboo Pole",
    [0x40] = "Club",
    [0x60] = "Copper Sword",
    [0x80] = "Hand Axe",
    [0xA0] = "Broad Sword",
    [0xC0] = "Flame Sword",
    [0xE0] = "Erdrick's Sword",
}

local ARMOR_NAMES = {
    [0x00] = nil,              -- None
    [0x04] = "Clothes",
    [0x08] = "Leather Armor",
    [0x0C] = "Chain Mail",
    [0x10] = "Half Plate",
    [0x14] = "Full Plate",
    [0x18] = "Magic Armor",
    [0x1C] = "Erdrick's Armor",
}

local SHIELD_NAMES = {
    [0x00] = nil,              -- None
    [0x01] = "Small Shield",
    [0x02] = "Large Shield",
    [0x03] = "Silver Shield",
}

-- ============================================================
-- Spell Lookup (dragon-warrior-disassembly)
-- ============================================================
-- Spells are tracked as bitfields across two RAM bytes:
--   0x00CE bits 0-7: Heal, Hurt, Sleep, Radiant, Stopspell, Outside, Return, Repel
--   0x00CF bits 0-1: Healmore, Hurtmore (upper bits are quest flags, not spells)

local SPELL_LIST = {
    {byte_addr = addr.SPELLS,   bit_num = 0, name = "Heal"},
    {byte_addr = addr.SPELLS,   bit_num = 1, name = "Hurt"},
    {byte_addr = addr.SPELLS,   bit_num = 2, name = "Sleep"},
    {byte_addr = addr.SPELLS,   bit_num = 3, name = "Radiant"},
    {byte_addr = addr.SPELLS,   bit_num = 4, name = "Stopspell"},
    {byte_addr = addr.SPELLS,   bit_num = 5, name = "Outside"},
    {byte_addr = addr.SPELLS,   bit_num = 6, name = "Return"},
    {byte_addr = addr.SPELLS,   bit_num = 7, name = "Repel"},
    {byte_addr = addr.FLAGS_CF, bit_num = 0, name = "Healmore"},
    {byte_addr = addr.FLAGS_CF, bit_num = 1, name = "Hurtmore"},
}

-- ============================================================
-- Public API
-- ============================================================

-- get_equipment(): Decode the equipment byte at 0x00BE.
-- Returns three values: weapon_name, armor_name, shield_name.
-- Each is a string or nil (nil = nothing equipped in that slot).
function M.get_equipment()
    local eq = memory.readbyte(addr.EQUIPMENT)
    local weapon = WEAPON_NAMES[AND(eq, 0xE0)]
    local armor  = ARMOR_NAMES[AND(eq, 0x1C)]
    local shield = SHIELD_NAMES[AND(eq, 0x03)]
    return weapon, armor, shield
end

-- get_spells(): Return a list of spell names the player currently knows.
-- Returns a table of name strings (empty table if no spells known).
-- Spells are listed in learning order (Heal first, Hurtmore last).
function M.get_spells()
    local known = {}
    for _, spell in ipairs(SPELL_LIST) do
        local byte_val = memory.readbyte(spell.byte_addr)
        -- BIT(n) is an FCEUX global that returns 2^n (bit mask).
        if AND(byte_val, BIT(spell.bit_num)) ~= 0 then
            known[#known + 1] = spell.name
        end
    end
    return known
end

-- get_nybble_items(): Read the 8 nybble-encoded item slots from RAM.
-- Returns an ordered list of {name=string} for non-empty slots.
-- Slot 0 is high nybble of 0x00C1, slot 1 is low nybble, etc.
local function get_nybble_items()
    local result = {}
    for slot = 0, 7 do
        local byte_offset = math.floor(slot / 2)
        local raw = memory.readbyte(addr.ITEMS_START + byte_offset)
        local nybble
        if slot % 2 == 0 then
            -- Even slot: high nybble (bits 7-4)
            nybble = math.floor(AND(raw, 0xF0) / 16)
        else
            -- Odd slot: low nybble (bits 3-0)
            nybble = AND(raw, 0x0F)
        end
        local name = ITEM_NAMES[nybble]
        if name then
            result[#result + 1] = {name = name}
        end
    end
    return result
end

-- get_all_items(): Build the full ITEM menu list as the game displays it.
-- DW1's ITEM menu shows Magic Keys first (from 0x00BF count), then Herbs
-- (from 0x00C0 count), then the nybble-encoded items from 0x00C1-0x00C4.
-- Each entry is {name=string}. D9 indexes this combined list.
--
-- NOTE: Herbs also appear as nybble value 0xF in the item slots, so they
-- are NOT added separately from the herb counter — we only include the
-- nybble items. Magic Keys have no nybble value and ARE added from the
-- counter. If this ordering is wrong, we'll see it during testing and
-- swap herbs/keys position.
function M.get_all_items()
    local result = {}

    -- Magic Keys: tracked at 0x00BF (count), not in nybble slots.
    -- The game shows "Magic Key" in the ITEM menu when count > 0.
    local keys = memory.readbyte(addr.KEYS)
    if keys > 0 then
        result[#result + 1] = {name = "Magic Key"}
    end

    -- Nybble-encoded items (includes Herbs as nybble 0xF)
    local nybble_items = get_nybble_items()
    for _, entry in ipairs(nybble_items) do
        result[#result + 1] = entry
    end

    return result
end

-- get_item_count(): Return total items visible in the ITEM menu.
function M.get_item_count()
    return #M.get_all_items()
end

-- get_item_at_d9(d9): Get the item name at ITEM menu cursor position d9.
-- D9 indexes the combined item list (keys + nybble items, 0-based).
-- Returns the item name string, or "Empty" if d9 is past the last item.
function M.get_item_at_d9(d9)
    local all = M.get_all_items()
    local idx = d9 + 1  -- convert 0-based D9 to 1-based Lua index
    if idx <= #all then
        return all[idx].name
    end
    return "Empty"
end

-- read_status_string(): Build a comprehensive status readout from RAM.
-- Includes level, HP/MP, all stats, experience, gold, equipment, and spells.
-- Returns a single string with ". " separators (screen-reader friendly —
-- the period causes a brief pause between each stat).
function M.read_status_string()
    local level  = memory.readbyte(addr.LEVEL)
    local hp     = memory.readbyte(addr.CURRENT_HP)
    local max_hp = memory.readbyte(addr.MAX_HP)
    local mp     = memory.readbyte(addr.CURRENT_MP)
    local max_mp = memory.readbyte(addr.MAX_MP)
    local str    = memory.readbyte(addr.STRENGTH)
    local agi    = memory.readbyte(addr.AGILITY)
    local atk    = memory.readbyte(addr.ATTACK)
    local def    = memory.readbyte(addr.DEFENSE)
    local exp    = memory.readbyte(addr.EXPERIENCE_LO)
                 + memory.readbyte(addr.EXPERIENCE_HI) * 256
    local gold   = memory.readbyte(addr.GOLD_LO)
                 + memory.readbyte(addr.GOLD_HI) * 256

    local weapon, armor, shield = M.get_equipment()
    local spells = M.get_spells()

    local parts = {
        "Level " .. level,
        "HP " .. hp .. " of " .. max_hp,
        "MP " .. mp .. " of " .. max_mp,
        "Strength " .. str,
        "Agility " .. agi,
        "Attack " .. atk,
        "Defense " .. def,
        "Experience " .. exp,
        "Gold " .. gold,
        "Weapon: " .. (weapon or "none"),
        "Armor: " .. (armor or "none"),
        "Shield: " .. (shield or "none"),
    }

    if #spells > 0 then
        parts[#parts + 1] = "Spells: " .. table.concat(spells, ", ")
    else
        parts[#parts + 1] = "Spells: none"
    end

    return table.concat(parts, ". ")
end

-- read_items_string(): Build a summary of all held items from RAM.
-- Returns a string listing all non-empty item slots, or "No items."
function M.read_items_string()
    local all = M.get_all_items()
    if #all == 0 then
        return "No items."
    end
    local names = {}
    for _, entry in ipairs(all) do
        names[#names + 1] = entry.name
    end
    return table.concat(names, ", ")
end

return M
