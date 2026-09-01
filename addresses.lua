-- addresses.lua
-- RAM address constants for Dragon Warrior (USA) (Rev 1).
--
-- All addresses are for the NES CPU address space (2KB RAM: 0x0000-0x07FF).
-- Source: DataCrystal RAM map (https://datacrystal.tcrf.net/wiki/Dragon_Warrior/RAM_map)
--
-- NOTE: This file was originally called memory.lua, but FCEUX has a
-- built-in global called "memory" (with readbyte, readbyterange, etc.).
-- Naming our module "memory" caused require("memory") to return FCEUX's
-- built-in instead of our file. Renamed to "addresses" to avoid the conflict.

local M = {}

-- Player Location
M.MAP_ID            = 0x0045  -- Current map ID (see maps.lua for names)
M.PLAYER_X          = 0x003A  -- Player X on current map
M.PLAYER_Y          = 0x003B  -- Player Y on current map
-- Movement state / facing direction byte.
-- Observed values after completed steps: 0x04 (west), 0x06 (east), 0x08 (after
-- leftward arrival), 0x00 (idle). Encoding not yet confirmed from disassembly.
-- Confirmed normalization target: write 0x00 on teleport_to to eliminate
-- state-dependent collision artifacts. When stale (e.g. 0x08 "leftward arrival"),
-- a subsequent LEFT press may turn-in-place instead of stepping, causing engine
-- to reject the step after full retry timeout.
M.MOVEMENT_STATE    = 0x003C  -- Suspected movement state / facing direction
-- Sub-pixel / animation offset byte adjacent to MOVEMENT_STATE.
-- Value 0x90 observed when teleport leaves stale state that blocks probes;
-- value 0x00 observed when probes succeed. Write 0x00 on teleport_to alongside
-- MOVEMENT_STATE to fully normalize the movement engine state.
M.MOVEMENT_SUBPIXEL = 0x003D  -- Sub-pixel offset or animation state (write 0x00 on teleport)
M.OVERWORLD_Y       = 0x003E  -- Dedicated overworld Y byte (not reliable as effective player Y)
M.OVERWORLD_X       = 0x0042  -- Dedicated overworld X byte (diagnostic; semantics still under investigation)

-- Environment / Terrain
M.TILE_TYPE         = 0x0015  -- Exterior tile type (0=grass, 15=water, etc.)
M.TERRAIN_OFFSET    = 0x0016  -- $20=caves, $10=towns, $00=world map
-- PPU control shadow. Bit 0 selects the horizontal base nametable used with
-- the scroll shadow below: 0 = NT0 first, 1 = NT1 first. Live King dialogue at
-- map 0x05 position (3,4) had PPU_CTRL=0x03 and SCROLL_X=0xB0, which means the
-- visible dialogue row starts in NT1 and wraps into NT0.
M.PPU_CTRL          = 0x0004
-- Horizontal scroll shadow register — pixel offset (0-255).
-- DW1 stores the pending PPU $2005 horizontal scroll value here and writes it
-- during NMI/VBlank. On interior maps, non-zero values shift dialogue tiles into
-- PPU nametable 1 ($2400) at player positions near the east edge of a map,
-- causing characters to be silently missed.
-- 0x0005 matched the live King wrap glitch with value 0xB0 (22 tiles); combined
-- with PPU_CTRL bit 0, the reader must assemble NT1 columns 22-31 before NT0.
-- Divide by 8 (pixels per NES tile) to get NES tile scroll offset for read_ppu_row.
M.SCROLL_X          = 0x0005
-- Vertical scroll shadow register — pixel offset written to PPU $2005 vertical.
-- Empirically confirmed via title_diag at two player positions:
--   player y=8:  0x0007 = 0x10 = 16  px  (= (8-7)*16)
--   player y=14: 0x0007 = 0x70 = 112 px  (= (14-7)*16)
-- Formula: max(0, player_y - 7) * 16 pixels.  Dividing by 8 gives NES tile units.
-- The dialogue window always appears at VISUAL row 19; its NAMETABLE row is:
--   (19 + floor(0x0007/8)) % 30
-- Used by get_dialogue_start_row() in main.lua.
M.SCROLL_Y          = 0x0007  -- Vertical scroll shadow (pixels; 0 when player_y <= 7)
-- Player sprite/screen-position low bytes. Live FCEUX evidence showed RAM
-- teleports can update PLAYER_X/Y while leaving these bytes at the old tile,
-- which poisons the next movement probe. Keep these synchronized by applying
-- the same 16-pixel tile delta used for the logical teleport.
M.PLAYER_SPRITE_X   = 0x0090
M.PLAYER_SPRITE_Y   = 0x0092
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
M.SCREEN_HEIGHT     = 30      -- NES screen is 30 tiles tall (960 bytes = 30*32)

-- ============================================================
-- ROM Addresses
-- ============================================================
-- These are file offsets into the ROM (read with rom.readbyte).
-- Note: rom.readbyte() in FCEUX includes the 16-byte iNES header,
-- so ROM address 0x0000 in the file is iNES header byte 0.
-- The actual PRG-ROM data starts at file offset 0x0010.

-- Map Metadata (5 bytes per map: data pointer low, high, width, height, border tile)
-- 30 map metadata entries total (0x00 through 0x1D).
M.ROM_MAP_META_START = 0x002A  -- Start of map metadata table in ROM file
M.ROM_MAP_META_SIZE  = 5       -- Bytes per map entry

-- Map Tile Data — RLE compressed tiles start after the metadata table.
-- Each map's data pointer (from metadata) gives the offset into PRG-ROM.
M.ROM_MAP_DATA_START = 0x00C1  -- First map's tile data begins here

-- Overworld map. The 120x120 world map is encoded independently from the
-- packed interior maps: each row has a little-endian CPU pointer into an RLE
-- stream whose bytes are TTTTLLLL (tile ID, run length minus one). These are
-- iNES file offsets, including the 16-byte header, for rom.readbyte().
M.ROM_OVERWORLD_DATA_START = 0x1D6D
M.ROM_OVERWORLD_ROW_POINTERS = 0x2663
M.ROM_OVERWORLD_CPU_BASE = 0x9D5D
M.OVERWORLD_MAP_SIZE = 120

-- Chest Data — 5 bytes per chest entry (map ID, X, Y, contents)
-- Contains all treasure chests in the game.
M.ROM_CHEST_START    = 0x5DDD  -- Start of chest data table
M.ROM_CHEST_END      = 0x5E58  -- End of chest data table
M.ROM_CHEST_SIZE     = 4       -- Bytes per chest entry (map, X, Y, contents)

-- Stair/Warp Data (format not fully documented yet)
-- Stairs down: connects a tile on one map to entry point on another
M.ROM_STAIRS_DOWN_START = 0xF3D8  -- Stair-down entries
M.ROM_STAIRS_DOWN_END   = 0xF471
-- Stairs up: reverse direction warps
M.ROM_STAIRS_UP_START   = 0xF472
M.ROM_STAIRS_UP_END     = 0xF50B

-- Opened Door Position Arrays (cartridge work RAM at $6000-$7FFF)
-- DW1 tracks doors opened during the current map visit in these arrays.
-- Cleared when re-entering a map (the arrays reset to 0 on map load).
-- Layout: X positions at $600C, $600E, $6010 ... (stride 2, up to 8 slots)
--         Y positions at $600D, $600F, $6011 ... (stride 2, interleaved with X)
-- An entry of (0, 0) means the slot is empty.
-- Source: DoorXPos/DoorYPos in nmikstas/dragon-warrior-disassembly
M.DOOR_X_POS_START  = 0x600C  -- Start of opened door X position array
M.DOOR_Y_POS_START  = 0x600D  -- Start of opened door Y position array
M.DOOR_ARRAY_MAX    = 8       -- Maximum simultaneously tracked open doors
M.DOOR_ARRAY_STRIDE = 2       -- Bytes between consecutive entries

-- Taken Treasure Position Array (cartridge work RAM at $6000-$7FFF)
-- GetTreasure writes the player's X/Y coordinate here before awarding the
-- chest contents. The game reads the same eight interleaved coordinate pairs
-- to replace taken chest tiles with floor, and clears them on overworld entry.
-- Source: TrsrXPos/TrsrYPos in nmikstas/dragon-warrior-disassembly
M.CHEST_X_POS_START  = 0x601C  -- Start of taken chest X position array
M.CHEST_Y_POS_START  = 0x601D  -- Start of taken chest Y position array
M.CHEST_ARRAY_MAX    = 8       -- Maximum simultaneously tracked taken chests
M.CHEST_ARRAY_STRIDE = 2       -- Bytes between consecutive entries

-- Mapper / CHR page registers in cartridge work RAM.
-- 0x6002 selects the background CHR page (title/gameplay split).
-- 0x6003 selects the sprite CHR page: 0x02 on field/title, 0x03 in battle.
M.CHR_PAGE_BG       = 0x6002
M.CHR_PAGE_SPRITES  = 0x6003

return M
