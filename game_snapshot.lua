-- game_snapshot.lua
-- Centralized per-frame game state snapshot.
--
-- Reads all frequently-accessed RAM addresses into a single table once per
-- frame. Other modules read from this snapshot instead of making scattered
-- memory.readbyte() calls, which:
--
--   1. Makes data flow explicit — every consumer reads from the same source.
--   2. Guarantees consistency — all values come from the same frame.
--   3. Enables testability — inject fake data by writing to the snapshot table.
--   4. Reduces coupling — modules no longer depend on addresses.lua directly.
--
-- Usage:
--   local snapshot = require "game_snapshot"
--
--   -- Call once per frame, BEFORE any module reads from it:
--   snapshot.update()
--
--   -- Then access fields directly:
--   local hp = snapshot.hp
--   local map_id = snapshot.map_id
--
-- NOTE: This module does NOT replace PPU reads (ppu.readbyte) or ROM reads
-- (rom.readbyte). Those are used by specialized modules (menu.lua, text.lua,
-- map_reader.lua) for nametable scanning and tile data, which don't fit the
-- "read once, use many" pattern.
--
-- NOTE: This module does NOT replace memory.writebyte() calls (NPC freeze).
-- Write operations remain in the modules that own them.

local addr = require "addresses"

local M = {}

-- ============================================================
-- Player Location
-- ============================================================
M.map_id      = 0    -- Current map ID (0x00 = overworld)
M.player_x    = 0    -- Player X on current (interior) map
M.player_y    = 0    -- Player Y on current (interior) map
M.overworld_x = 0    -- Player X on the overworld
M.overworld_y = 0    -- Player Y on the overworld

-- ============================================================
-- Effective Position (resolves overworld vs. interior)
-- ============================================================
-- These are the "real" coordinates — overworld coords when map_id == 0,
-- interior coords otherwise. Matches navigation.lua's get_position() logic.
M.x = 0
M.y = 0

-- ============================================================
-- Player Stats
-- ============================================================
M.hp       = 0    -- Current HP
M.max_hp   = 0    -- Maximum HP
M.mp       = 0    -- Current MP
M.max_mp   = 0    -- Maximum MP
M.level    = 0    -- Player level (1-30 in gameplay, 0 or >30 on title)
M.strength = 0    -- Strength stat
M.agility  = 0    -- Agility stat
M.attack   = 0    -- Attack power (strength + weapon)
M.defense  = 0    -- Defense power (agility + armor + shield)
M.exp      = 0    -- Experience points (16-bit: lo + hi*256)
M.gold     = 0    -- Gold (16-bit: lo + hi*256)

-- ============================================================
-- Equipment & Inventory
-- ============================================================
M.equipment = 0   -- Compiled equipment byte (weapon/armor/shield)
M.keys      = 0   -- Magic Keys count
M.herbs     = 0   -- Herbs count
-- Raw item bytes (4 bytes, each holding 2 nybble-encoded item slots).
-- items[1] = 0x00C1, items[2] = 0x00C2, items[3] = 0x00C3, items[4] = 0x00C4.
M.items     = {0, 0, 0, 0}

-- ============================================================
-- Spells & Flags
-- ============================================================
M.spells       = 0  -- Spells known bitfield (0x00CE)
M.flags_cf     = 0  -- More spells + quest progress (0x00CF)
M.combat_flags = 0  -- Combat/quest flags (0x00DF)
M.quest_flags  = 0  -- Quest progress (0x00E4)

-- ============================================================
-- Combat
-- ============================================================
M.enemy_type = 0   -- Enemy type pointer / terrain type (0x00E0)
M.enemy_hp   = 0   -- Enemy current HP (0x00E2)

-- ============================================================
-- Menu Cursor
-- ============================================================
M.cursor_x = 0    -- Menu horizontal cursor (D8 / 0x00D8)
M.cursor_y = 0    -- Menu vertical cursor (D9 / 0x00D9)

-- ============================================================
-- Environment
-- ============================================================
M.tile_type      = 0  -- Exterior tile type (0x0015)
M.terrain_offset = 0  -- Terrain offset: 0x20=caves, 0x10=towns, 0x00=world map
M.scroll_y       = 0  -- Vertical scroll shadow (pixels, 0x0007)
M.light_radius   = 0  -- Dungeon light radius (0x00D0)
M.radiant_timer  = 0  -- Radiant spell countdown (0x00DA)
M.repel_timer    = 0  -- Repel countdown (0x00DB)

-- ============================================================
-- Input (NES buttons — NOT keyboard; keyboard uses input.get())
-- ============================================================
M.buttons = 0     -- Currently pressed button(s) (0x0047)

-- ============================================================
-- Update
-- ============================================================

-- update(): Read all tracked RAM values into this table.
-- Call ONCE per frame at the top of the main loop, BEFORE any
-- module that reads from the snapshot.
--
-- Performance: ~35 memory.readbyte() calls per frame. Each call is a
-- simple FFI read in FCEUX — negligible compared to PPU/ROM reads
-- and speech processing. Total cost is well under 1 microsecond.
function M.update()
    -- Player location
    M.map_id      = memory.readbyte(addr.MAP_ID)
    M.player_x    = memory.readbyte(addr.PLAYER_X)
    M.player_y    = memory.readbyte(addr.PLAYER_Y)
    M.overworld_x = memory.readbyte(addr.OVERWORLD_X)
    M.overworld_y = memory.readbyte(addr.OVERWORLD_Y)

    -- Effective position (overworld vs. interior)
    if M.map_id == 0x00 then
        M.x = M.overworld_x
        M.y = M.overworld_y
    else
        M.x = M.player_x
        M.y = M.player_y
    end

    -- Player stats
    M.hp       = memory.readbyte(addr.CURRENT_HP)
    M.max_hp   = memory.readbyte(addr.MAX_HP)
    M.mp       = memory.readbyte(addr.CURRENT_MP)
    M.max_mp   = memory.readbyte(addr.MAX_MP)
    M.level    = memory.readbyte(addr.LEVEL)
    M.strength = memory.readbyte(addr.STRENGTH)
    M.agility  = memory.readbyte(addr.AGILITY)
    M.attack   = memory.readbyte(addr.ATTACK)
    M.defense  = memory.readbyte(addr.DEFENSE)
    M.exp      = memory.readbyte(addr.EXPERIENCE_LO)
                 + memory.readbyte(addr.EXPERIENCE_HI) * 256
    M.gold     = memory.readbyte(addr.GOLD_LO)
                 + memory.readbyte(addr.GOLD_HI) * 256

    -- Equipment & inventory
    M.equipment = memory.readbyte(addr.EQUIPMENT)
    M.keys      = memory.readbyte(addr.KEYS)
    M.herbs     = memory.readbyte(addr.HERBS)
    M.items[1]  = memory.readbyte(addr.ITEMS_START)
    M.items[2]  = memory.readbyte(addr.ITEMS_START + 1)
    M.items[3]  = memory.readbyte(addr.ITEMS_START + 2)
    M.items[4]  = memory.readbyte(addr.ITEMS_START + 3)

    -- Spells & flags
    M.spells       = memory.readbyte(addr.SPELLS)
    M.flags_cf     = memory.readbyte(addr.FLAGS_CF)
    M.combat_flags = memory.readbyte(addr.COMBAT_FLAGS)
    M.quest_flags  = memory.readbyte(addr.QUEST_FLAGS)

    -- Combat
    M.enemy_type = memory.readbyte(addr.ENEMY_TYPE)
    M.enemy_hp   = memory.readbyte(addr.ENEMY_HP)

    -- Menu cursor
    M.cursor_x = memory.readbyte(addr.MENU_CURSOR_X)
    M.cursor_y = memory.readbyte(addr.MENU_CURSOR_Y)

    -- Environment
    M.tile_type      = memory.readbyte(addr.TILE_TYPE)
    M.terrain_offset = memory.readbyte(addr.TERRAIN_OFFSET)
    M.scroll_y       = memory.readbyte(addr.SCROLL_Y)
    M.light_radius   = memory.readbyte(addr.LIGHT_RADIUS)
    M.radiant_timer  = memory.readbyte(addr.RADIANT_TIMER)
    M.repel_timer    = memory.readbyte(addr.REPEL_TIMER)

    -- Input
    M.buttons = memory.readbyte(addr.BUTTONS_PRESSED)
end

return M
