-- maps.lua
-- Map ID to human-readable name lookup.
-- Map IDs come from RAM address 0x0045.
--
-- Source of truth:
--   Data Crystal Dragon Warrior/RAM map (retrieved 2026-03-27)
--   https://datacrystal.tcrf.net/wiki/Dragon_Warrior/RAM_map
--
-- Important: the live RAM map uses 0x01 for the overworld, not 0x00.
-- Several early versions of this project assumed a synthetic 0x00 world map
-- ID, which caused location names and object tables to drift from the real
-- game state. Keep these IDs aligned with the raw value in RAM.

local M = {}

M.WORLD_MAP_ID = 0x01

-- Map names indexed by map ID byte value
M.names = {
    [0x01] = "World Map",
    [0x02] = "Charlock Castle",
    [0x03] = "Ruins of Hauksness",
    [0x04] = "Tantegel Castle",
    [0x05] = "Tantegel Castle Throne Room",
    [0x06] = "Dragonlord's Lair",
    [0x07] = "Kol",
    [0x08] = "Brecconary",
    [0x09] = "Garinham",
    [0x0A] = "Cantlin",
    [0x0B] = "Rimuldar",
    [0x0C] = "Sun Shrine",
    [0x0D] = "Rain Shrine",
    [0x0E] = "Magic Temple",
    [0x0F] = "Dragonlord B1",
    [0x10] = "Dragonlord B2",
    [0x11] = "Dragonlord B3",
    [0x12] = "Dragonlord B4",
    [0x13] = "Dragonlord B5",
    [0x14] = "Dragonlord B6",
    [0x15] = "Swamp Cave",
    [0x16] = "Mountain Cave",
    [0x17] = "Mountain Cave B2",
    [0x18] = "Garin's Grave B1",
    [0x19] = "Garin's Grave B2",
    [0x1A] = "Garin's Grave B3",
    [0x1B] = "Garin's Grave B4",
    [0x1C] = "Erdrick's Cave B1",
    [0x1D] = "Erdrick's Cave B2",
}

-- get_name(id): Return the map name for a given map ID, or "Unknown" if not found.
function M.get_name(id)
    return M.names[id] or ("Unknown Map " .. id)
end

function M.is_overworld(map_id, terrain_offset)
    return terrain_offset == 0x00 or map_id == M.WORLD_MAP_ID
end

return M
