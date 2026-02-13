-- memory.lua
-- RAM address constants for Dragon Warrior (USA) (Rev 1).
-- All addresses are for the NES CPU address space (2KB RAM: 0x0000-0x07FF).
-- Source: DataCrystal RAM map (https://datacrystal.tcrf.net/wiki/Dragon_Warrior/RAM_map)

local M = {}

-- Player Location
M.MAP_ID            = 0x0045  -- Current map ID (see maps.lua for names)
M.PLAYER_X          = 0x003A  -- Player X on current map
M.PLAYER_Y          = 0x003B  -- Player Y on current map
M.OVERWORLD_Y       = 0x003E  -- Player Y on the overworld (map 0x00)
M.OVERWORLD_X       = 0x0042  -- Player X on the overworld (map 0x00)

-- Environment / Terrain
M.TILE_TYPE         = 0x0015  -- Exterior tile type (0=grass, 15=water, etc.)
M.TERRAIN_OFFSET    = 0x0016  -- $20=caves, $10=towns, $00=world map
M.LIGHT_RADIUS      = 0x00D0  -- Dungeon light radius (01, 03, 05, 07)
M.RADIANT_TIMER     = 0x00DA  -- Radiant spell countdown timer
M.REPEL_TIMER       = 0x00DB  -- Repel timer (counts down by 2 from 0xFF)

-- Player Stats
M.EXPERIENCE_LO     = 0x00BA  -- Experience points (low byte)
M.EXPERIENCE_HI     = 0x00BB  -- Experience points (high byte)
M.GOLD_LO           = 0x00BC  -- Gold (low byte)
M.GOLD_HI           = 0x00BD  -- Gold (high byte)
M.EQUIPMENT         = 0x00BE  -- Compiled equipment byte (sword/armor/shield)
M.KEYS              = 0x00BF  -- Magic Keys count
M.HERBS             = 0x00C0  -- Herbs count
M.ITEMS_START       = 0x00C1  -- Items start (4 bytes = 8 nybble-encoded slots)
M.ITEMS_END         = 0x00C4  -- Items end
M.CURRENT_HP        = 0x00C5  -- Current hit points
M.CURRENT_MP        = 0x00C6  -- Current magic points
M.LEVEL             = 0x00C7  -- Player level
M.STRENGTH          = 0x00C8  -- Strength stat
M.AGILITY           = 0x00C9  -- Agility stat
M.MAX_HP            = 0x00CA  -- Maximum HP
M.MAX_MP            = 0x00CB  -- Maximum MP
M.ATTACK            = 0x00CC  -- Attack Power (strength + weapon)
M.DEFENSE           = 0x00CD  -- Defense Power (agility + armor + shield)
M.SPELLS            = 0x00CE  -- Spells known (bitfield, bits 0-7 = 8 spells)
M.FLAGS_CF          = 0x00CF  -- More spells + quest progress flags

-- Combat
M.MENU_CURSOR_X     = 0x00D8  -- Menu horizontal cursor position
M.MENU_CURSOR_Y     = 0x00D9  -- Menu vertical cursor position
M.COMBAT_FLAGS      = 0x00DF  -- Combat/quest flags (princess, death necklace, status)
M.ENEMY_TYPE        = 0x00E0  -- Enemy type pointer / terrain type
M.ENEMY_HP          = 0x00E2  -- Enemy current HP
M.QUEST_FLAGS       = 0x00E4  -- Quest progress (Golem/Dragonlord/Green Dragon)

-- Input
M.BUTTONS_PRESSED   = 0x0047  -- Currently pressed button(s)

-- NPCs
-- 20 NPC entries starting at 0x0051, 3 bytes each (type, position, direction)
M.NPC_DATA_START    = 0x0051
M.NPC_DATA_END      = 0x008C
M.NPC_ENTRY_SIZE    = 3
M.NPC_COUNT         = 20

-- Text
M.TEXT_POINTER_LO   = 0x009F  -- Text pointer (low byte)
M.TEXT_POINTER_HI   = 0x00A0  -- Text pointer (high byte)

-- Screen Buffer
-- The PPU name table is mirrored/copied to this RAM range.
-- Contains the visible tile IDs for the text/UI layer.
M.SCREEN_BUF_START  = 0x0400  -- Screen buffer start
M.SCREEN_BUF_END    = 0x07BF  -- Screen buffer end
M.SCREEN_WIDTH      = 32      -- NES screen is 32 tiles wide
M.SCREEN_HEIGHT     = 30      -- NES screen is 30 tiles tall (but 0x0400-0x07BF = 960 bytes = 30*32)

-- Title Screen Detection
-- CHR page register: 0x00 = title screen, 0x01 = gameplay
M.CHR_PAGE          = 0x6002

return M
