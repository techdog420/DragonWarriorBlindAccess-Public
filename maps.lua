-- maps.lua
-- Map ID to human-readable name lookup.
-- Map ID is stored at RAM address 0x0045.
-- There are 30 maps total (0x00 = world map, 0x01-0x1D = interior locations).

local M = {}

-- Map names indexed by map ID byte value
M.names = {
    [0x00] = "World Map",
    [0x01] = "Charlock Castle B1",
    [0x02] = "Charlock Castle B2",
    [0x03] = "Charlock Castle B3",
    -- NOTE: DataCrystal lists 0x04-0x07 as Charlock B4-B7 and 0x08-0x09 as
    -- Tantegel Castle/Throne Room, but empirical in-RAM testing on USA Rev 1
    -- confirms the opposite: 0x04=Tantegel Castle, 0x05=Tantegel Throne Room.
    -- DataCrystal IDs for 0x06-0x09 are unverified in RAM.
    [0x04] = "Tantegel Castle",
    [0x05] = "Tantegel Castle Throne Room",
    [0x06] = "Charlock Castle B6",          -- DataCrystal; unverified in RAM
    [0x07] = "Charlock Castle B7 - Dragonlord's Throne Room",  -- DataCrystal; unverified in RAM
    [0x08] = "Tantegel Castle (alt)",        -- DataCrystal says Tantegel Castle; unverified in RAM
    [0x09] = "Tantegel Castle Throne Room (alt)", -- DataCrystal; unverified in RAM
    [0x0A] = "Charlock Castle",
    [0x0B] = "Cave",
    [0x0C] = "Tantegel Town",
    [0x0D] = "Kol",
    [0x0E] = "Brecconary",
    [0x0F] = "Garinham",
    [0x10] = "Cantlin",
    [0x11] = "Rimuldar",
    [0x12] = "Erdrick's Cave B1",
    [0x13] = "Erdrick's Cave B2",
    [0x14] = "Northern Shrine",
    [0x15] = "Southern Shrine",
    [0x16] = "Charlock Castle B8",
    [0x17] = "Swamp Cave",
    [0x18] = "Mountain Cave",
    [0x19] = "Mountain Cave B2",
    [0x1A] = "Garin's Grave B1",
    [0x1B] = "Garin's Grave B2",
    [0x1C] = "Garin's Grave B3",
    [0x1D] = "Garin's Grave B4",
}

-- get_name(id): Return the map name for a given map ID, or "Unknown" if not found.
function M.get_name(id)
    return M.names[id] or ("Unknown Map " .. id)
end

return M
