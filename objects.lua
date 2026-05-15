-- objects.lua
-- Object detection and navigation for Dragon Warrior.
--
-- Detects objects on the current map (NPCs, stairs, chests, exits) and
-- provides a list the player can cycle through with J/K/L hotkeys.
-- Each object includes its position, type, and name so the player can
-- hear direction and distance information.
--
-- Object sources:
--   - NPCs: parsed from RAM every few frames (they move)
--   - Stairs: hard-coded per map (ROM format not yet reverse-engineered)
--   - Chests: read from ROM (static, loaded on map change)
--   - Exits: hard-coded per map (the tile that returns to the parent map)
--
-- Modeled after the pokemon-access project's object navigation pattern:
-- a flat list of all objects, sorted by distance, with filter cycling.

local addr = require "addresses"
local maps = require "maps"
local nav = require "navigation"
local map_reader = require "map_reader"
local config = require "config"
local emulator_compat = rawget(_G, "DW_EMULATOR_COMPAT") or {}
local overworld_routes = require "overworld_routes"

local M = {}

local reload_state = rawget(_G, "DW_OBJECTS_RELOAD_STATE")
if type(reload_state) ~= "table" then
    reload_state = {}
    _G.DW_OBJECTS_RELOAD_STATE = reload_state
end
if type(reload_state.accepted_npc_signature_by_map) ~= "table" then
    reload_state.accepted_npc_signature_by_map = {}
end
if type(reload_state.visited_by_map) ~= "table" then
    reload_state.visited_by_map = {}
end

-- ============================================================
-- Object Type Constants
-- ============================================================
-- These identify what kind of object each entry is, used for
-- filtering and display.
M.TYPE_NPC    = "npc"
M.TYPE_STAIR  = "stair"
M.TYPE_CHEST  = "chest"
M.TYPE_EXIT   = "exit"
M.TYPE_DOOR   = "door"

-- ============================================================
-- Filter Constants
-- ============================================================
-- The player can cycle through filters with the filter hotkey to show
-- only certain types of objects.
M.FILTER_ALL    = 1
M.FILTER_NPC    = 2
M.FILTER_SERVICE = 3
M.FILTER_TREASURE = 4
M.FILTER_TRAVEL = 5
M.FILTER_DOOR   = 6
-- Backward-compatible aliases for older tests/debug code.
M.FILTER_EXIT   = M.FILTER_TRAVEL
M.FILTER_CHEST  = M.FILTER_TREASURE
M.FILTER_STAIR  = M.FILTER_TRAVEL

M.PATHABILITY_ALL = 1
M.PATHABILITY_REACHABLE = 2
M.PATHABILITY_UNREACHABLE = 3

-- Human-readable names for each filter mode
local FILTER_NAMES = {
    [M.FILTER_ALL]      = "All",
    [M.FILTER_NPC]      = "NPCs",
    [M.FILTER_SERVICE]  = "Services",
    [M.FILTER_TREASURE] = "Treasure",
    [M.FILTER_TRAVEL]   = "Travel",
    [M.FILTER_DOOR]     = "Doors",
}

-- How many filter modes there are (for wraparound)
local FILTER_COUNT = 6

local PATHABILITY_NAMES = {
    [M.PATHABILITY_ALL] = "All",
    [M.PATHABILITY_REACHABLE] = "Reachable",
    [M.PATHABILITY_UNREACHABLE] = "Unreachable",
}

local PATHABILITY_COUNT = 3

-- ============================================================
-- NPC Sprite Type Names
-- ============================================================
-- Dragon Warrior uses sprite types 0-7, encoded in bits 7-5 of
-- the first NPC data byte. These names are approximate — the
-- actual appearance depends on the sprite graphics loaded.
local SPRITE_NAMES = {
    [0] = "Person",       -- Generic townsfolk (can be man or woman)
    [1] = "Guard",        -- Red guard / soldier
    [2] = "Guard",        -- Grey/blue guard variant
    [3] = "Merchant",     -- Shop keeper
    [4] = "King",         -- Royalty
    [5] = "Old Man",      -- Elder / sage
    [6] = "Woman",        -- Female NPC
    [7] = "Guard",        -- Another guard variant
}

local apply_service_interaction_override

-- ============================================================
-- Door Tile Type Constants
-- ============================================================
-- CONFIRMED: DW1 does NOT encode locked doors as a distinct tile type
-- in the ROM map data. The actual magic-key door positions appear as
-- ordinary wall tiles in the tile grid (type 15 on map 0x05, confirmed
-- empirically). The game engine tracks door positions through a separate
-- data structure, independent of the tile type.
--
-- Consequence: scanning the ROM tile grid for a "door tile type" does
-- NOT find interactive locked doors. Type-11 tiles in town/castle maps
-- are WALLS (confirmed: OPEN command returns "there is no door here"
-- when facing a type-11 tile on Charlock B4). Type-11 is non-walkable
-- but is not an interactive door.
--
-- DOOR_TILE_TOWN is set to nil to disable town/castle door scanning.
-- Actual door positions must be added manually to EXTRA_DOORS below
-- once confirmed in-game (like the map 0x05 door at (4,7)).
--
-- DOOR_TILE_DUNGEON (5) is unconfirmed — left as-is but not yet tested.
local DOOR_TILE_TOWN    = nil  -- DISABLED: type-11 is a wall, not a door
local DOOR_TILE_DUNGEON = 5    -- unconfirmed: locked door tile in dungeon/cave maps

-- ============================================================
-- Door Opened Status
-- ============================================================
-- When the player opens a door with a Magic Key, DW1 stores the door's
-- position in cartridge work RAM arrays at $600C/$600D (8 slots, 2-byte
-- stride). These are cleared when re-entering a map, so door state is
-- session-only — exactly like our chest opened cache.
--
-- is_door_opened(x, y): Return true if the door at (x, y) appears in
-- the game's opened-door RAM array. Scans all 8 slots.
local function is_door_opened(x, y)
    for i = 0, addr.DOOR_ARRAY_MAX - 1 do
        local dx = memory.readbyte(addr.DOOR_X_POS_START + i * addr.DOOR_ARRAY_STRIDE)
        local dy = memory.readbyte(addr.DOOR_Y_POS_START + i * addr.DOOR_ARRAY_STRIDE)
        -- A non-zero X value that matches both coordinates = opened door.
        -- Empty slots have dx=0 (no valid door is at x=0 — engine blocks it).
        if dx ~= 0 and dx == x and dy == y then
            return true
        end
    end
    return false
end

-- ============================================================
-- Hard-Coded Stair/Warp Locations
-- ============================================================
-- Since the ROM format for stair data isn't fully documented,
-- we hard-code known locations for the most important early-game
-- maps. Each entry: {map_id, x, y, name, dest_description}
--
-- These will be replaced with ROM reading once we reverse-engineer
-- the stair data format at ROM 0xF3D8-0xF50B.

local STAIRS = {
    -- Tantegel Castle (0x04)
    -- Stairs down to throne room
    {map = 0x04, x = 1, y = 1, name = "Stairs Down", dest = "Throne Room"},
    -- Stairs leading to the courtyard treasure room
    {map = 0x04, x = 29, y = 1, name = "Stairs Down", dest = "Treasure Room"},

    -- Map 0x05 (Tantegel Castle Throne Room, empirically confirmed)
    -- Staircase at east end of the south corridor (x=8, y=8). Player stands
    -- at (8,8) to use it. Reached by walking south through the arch at (4,7)
    -- into the y=8 corridor, then east to (8,8). Leads to Tantegel Castle
    -- (map 0x04) at (7,7) — confirmed in-game 2026-03-23.
    {map = 0x05, x = 8, y = 8, name = "Stairs Down", dest = "Tantegel Castle"},
    -- Return stair: Tantegel Castle (map 0x04) at (7,7) leads back to Throne Room (map 0x05)
    {map = 0x04, x = 7, y = 7, name = "Stairs Up", dest = "Tantegel Castle Throne Room"},

    -- Erdrick's Cave B1 (0x1C)
    -- Confirmed live: STAIRS at (9,9) moves to B2 (map 0x1D) at (8,9).
    {map = 0x1C, x = 9, y = 9, name = "Stairs Down", dest = "B2"},

    -- Erdrick's Cave B2 (0x1D)
    -- Confirmed live: STAIRS at (8,9) moves to B1 (map 0x1C) at (9,9).
    {map = 0x1D, x = 8, y = 9, name = "Stairs Up", dest = "B1"},

    -- Swamp Cave (0x15)
    {map = 0x15, x = 0, y = 0, name = "Stairs Up", dest = "World Map"},

    -- Mountain Cave (0x16)
    {map = 0x16, x = 6, y = 5, name = "Stairs Down", dest = "B2"},

    -- Mountain Cave B2 (0x17)
    {map = 0x17, x = 6, y = 5, name = "Stairs Up", dest = "Mountain Cave"},

    -- Garin's Grave B1 (0x18)
    {map = 0x18, x = 19, y = 0, name = "Stairs Down", dest = "B2"},

    -- Garin's Grave B2 (0x19)
    {map = 0x19, x = 19, y = 0, name = "Stairs Up", dest = "B1"},
    {map = 0x19, x = 12, y = 12, name = "Stairs Down", dest = "B3"},

    -- Garin's Grave B3 (0x1A)
    {map = 0x1A, x = 12, y = 12, name = "Stairs Up", dest = "B2"},
    {map = 0x1A, x = 1, y = 1, name = "Stairs Down", dest = "B4"},

    -- Garin's Grave B4 (0x1B)
    {map = 0x1B, x = 1, y = 1, name = "Stairs Up", dest = "B3"},

    -- Charlock Castle (0x02)
    {map = 0x02, x = 10, y = 1, name = "Stairs Down", dest = "B1"},

    -- Dragonlord dungeon (raw map IDs from Data Crystal RAM map).
    -- The early floors below are still the best-known mappings from earlier
    -- reverse-engineering. Deeper floor IDs were mis-labeled in older builds,
    -- so we only keep the entries we can map confidently today.
    {map = 0x0F, x = 10, y = 1, name = "Stairs Up", dest = "Charlock Castle"},
    {map = 0x0F, x = 7, y = 7, name = "Stairs Down", dest = "B2"},
    {map = 0x10, x = 7, y = 7, name = "Stairs Up", dest = "B1"},
    {map = 0x10, x = 3, y = 3, name = "Stairs Down", dest = "B3"},
    {map = 0x11, x = 3, y = 3, name = "Stairs Up", dest = "B2"},
}

-- ============================================================
-- Hard-Coded Exit Locations
-- ============================================================
-- Exits are the tiles that return you to the parent map (usually
-- the overworld). For towns, this is usually the bottom edge.
-- For dungeons, this is usually near the entrance stairs.

local EXITS = {
    -- Towns — exits are at the town entrance. Most face south, but
    -- Brecconary's confirmed world-map handoff is on the west edge.
    {map = 0x07, x = 15, y = 14, name = "Exit", dest = "World Map"},      -- Kol
    {map = 0x08, x = 0,  y = 15, name = "Exit", dest = "World Map"},      -- Brecconary (confirmed via live PPU dump)
    {map = 0x09, x = 15, y = 14, name = "Exit", dest = "World Map"},      -- Garinham
    {map = 0x0A, x = 14, y = 29, name = "Exit", dest = "World Map"},      -- Cantlin
    {map = 0x0B, x = 15, y = 14, name = "Exit", dest = "World Map"},      -- Rimuldar

    -- Castles — exits are typically at the south entrance
    -- NOTE: map 0x05 = Tantegel Throne Room (empirically confirmed, 9x9).
    -- (4,7) is the arch in the south wall that leads to the y=8 corridor
    -- within the same map (not a map exit). Pathfinding to stairs at (8,8)
    -- automatically routes south through (4,7) and east to the staircase.
    -- The actual map exit from map 0x05 is via the stairs at (8,8).
    -- Map 0x04: live castle map. The south gate exit is reached from the
    -- interior bottom row at (11,29); the visible gate door panels sit just
    -- south of it at (10,30) and (11,30).
    {map = 0x04, x = 11, y = 29, name = "Exit", dest = "World Map"},      -- Tantegel Castle
    {map = 0x02, x = 10, y = 19, name = "Exit", dest = "World Map"},      -- Charlock Castle

    -- Shrines
    {map = 0x0C, x = 4, y = 4, name = "Exit", dest = "World Map"},        -- Sun Shrine
    {map = 0x0D, x = 4, y = 4, name = "Exit", dest = "World Map"},        -- Rain Shrine
    {map = 0x0E, x = 4, y = 4, name = "Exit", dest = "World Map"},        -- Magic Temple

    -- Cave entrances (the "stairs up" at the entrance)
    {map = 0x15, x = 0, y = 0, name = "Exit", dest = "World Map"},        -- Swamp Cave
    {map = 0x16, x = 0, y = 0, name = "Exit", dest = "World Map"},        -- Mountain Cave
    {map = 0x18, x = 0, y = 0, name = "Exit", dest = "World Map"},        -- Garin's Grave B1
    {map = 0x1C, x = 0, y = 0, name = "Exit", dest = "World Map"},        -- Erdrick's Cave B1
}

-- Major overworld destinations, stored relative to Tantegel Castle using the
-- coordinate convention from Gamer Corner's Dragon Warrior location guide.
--
-- The dedicated overworld coordinate bytes turned out to be unreliable for
-- landmark math. Terminal verification on 2026-03-27 showed repeated
-- world-map <-> Tantegel transitions through player coordinate (43,43), while
-- the old dedicated overworld bytes still reported (51,4). We now anchor the
-- overworld against the live player-coordinate system instead.
local OVERWORLD_SIZE = 120
local OVERWORLD_TANTEGEL_X = 43
local OVERWORLD_TANTEGEL_Y = 43

local OVERWORLD_LANDMARKS = {
    {dx =   0, dy =   0, name = "Tantegel Castle"},
    {dx =   5, dy =  -2, name = "Brecconary"},
    {dx = -15, dy = -31, name = "Erdrick's Cave"},
    {dx = -41, dy = -41, name = "Garinham"},
    {dx =  61, dy = -33, name = "Kol"},
    {dx =  38, dy = -42, name = "Northern Cave"},
    {dx = -14, dy =  14, name = "Mountain Cave"},
    {dx =  61, dy =   1, name = "Swamp Cave"},
    {dx =  59, dy =  29, name = "Rimuldar"},
    {dx =  65, dy =  66, name = "Southern Cave"},
    {dx =  30, dy =  59, name = "Cantlin"},
    {dx = -18, dy =  46, name = "Hauksness"},
    {dx =   5, dy =   5, name = "Charlock Castle"},
}

local function wrap_overworld_coord(value)
    value = value % OVERWORLD_SIZE
    if value < 0 then
        value = value + OVERWORLD_SIZE
    end
    return value
end

-- ============================================================
-- Chest Opened Status (Session-Level Cache)
-- ============================================================
-- DW1 uses a password save system (no battery backup), so chest
-- opened status is only relevant within a play session — exactly
-- like the game's own behavior. We track this ourselves because
-- the RAM address for the game's chest flag bitfield isn't yet
-- documented on DataCrystal.
--
-- Key: chest id string (e.g. "chest_4")
-- Value: true if the chest has been collected this session
local opened_chests = {}

-- mark_chest_opened(chest_id): Record that a chest has been collected.
-- Called from main.lua when an inventory gain is detected near a chest.
function M.mark_chest_opened(chest_id)
    opened_chests[chest_id] = true
end

-- is_chest_opened(chest_id): True if chest was collected this session.
function M.is_chest_opened(chest_id)
    return opened_chests[chest_id] == true
end

-- ============================================================
-- State
-- ============================================================

-- The current combined object list for this map
local object_list = {}
local static_object_cache = {}
local visited_by_map = reload_state.visited_by_map

-- The filtered view of the object list (what the player cycles through)
local filtered_list = {}

-- Current selection index (1-based, into filtered_list)
local current_index = 1

-- Persistent selected object ID for reference-based selection.
-- When the list re-sorts (NPC movement), we restore selection by ID
-- rather than trusting the numeric index.
local selected_id = nil

-- Current filter mode
local current_filter = M.FILTER_ALL
local current_pathability_filter = M.PATHABILITY_ALL
local pathability_status_by_id = {}

-- Which map we last built the object list for (to detect map changes)
local current_map_id = nil
local current_terrain_offset = nil

-- Frame counter for periodic NPC position updates
local npc_refresh_counter = 0
local NPC_REFRESH_INTERVAL = 20  -- Re-read NPC positions every 20 frames (~0.33s)
local MAP_ENTRY_NPC_REFRESH_CHECKS = 90
local MAP_ENTRY_NPC_REFRESH_INTERVAL = 8

-- When true, check_refresh() will rebuild the object list on the next call
-- (after frameadvance has run and RAM reflects real NPC positions).
local refresh_pending = false
local refresh_defer_checks = 0
local map_entry_stale_npc_signatures = nil
local map_entry_npc_refresh_checks = 0
local map_entry_npc_refresh_gap = 0
local map_entry_force_accept_npcs = false
local last_accepted_npc_signature = reload_state.last_accepted_npc_signature
local accepted_npc_signature_by_map = reload_state.accepted_npc_signature_by_map

local function active_map_id(map_id)
    if map_id ~= nil then return map_id end
    if current_map_id ~= nil then return current_map_id end
    local mid = nav.get_position()
    return mid
end

local function visited_bucket(map_id, create)
    map_id = active_map_id(map_id)
    if map_id == nil then return nil end
    if not visited_by_map[map_id] and create then
        visited_by_map[map_id] = {}
    end
    return visited_by_map[map_id], map_id
end

local function get_terrain_offset()
    return memory.readbyte(addr.TERRAIN_OFFSET)
end

local function is_overworld_context()
    return get_terrain_offset() == 0x00
end

local function current_context_allows_npcs()
    local terrain_offset = get_terrain_offset()
    -- Dungeon/cave maps do not expose a usable NPC table. Town/castle NPC RAM
    -- can linger after map entry, so keep live NPC parsing to interior maps
    -- with the town/castle terrain set.
    return terrain_offset == 0x10
end

local function periodic_npc_refresh_enabled()
    if emulator_compat.is_bizhawk ~= true then
        return true
    end
    return config.get("bizhawk_periodic_npc_refresh") == "true"
end

local function map_entry_path_grid_prewarm_enabled()
    if emulator_compat.is_bizhawk ~= true then
        return true
    end
    return config.get("bizhawk_map_entry_prewarm_path_grid") == "true"
end

local function prewarm_path_grid(map_id)
    if is_overworld_context() then
        return
    end
    if not map_entry_path_grid_prewarm_enabled() then
        return
    end
    if map_reader.get_tile_grid then
        map_reader.get_tile_grid(map_id)
    end
end

local function read_npc_snapshot()
    local parts = {}
    local entries = {}
    for i = 0, addr.NPC_COUNT - 1 do
        local base = addr.NPC_DATA_START + (i * addr.NPC_ENTRY_SIZE)
        local byte0 = memory.readbyte(base)
        local byte1 = memory.readbyte(base + 1)
        local byte2 = memory.readbyte(base + 2)
        local y_only = byte1 % 0x20
        parts[#parts + 1] = string.format(
            "%02X%02X",
            byte0,
            y_only)
        entries[#entries + 1] = {
            slot = i,
            byte0 = byte0,
            byte1 = byte1,
            byte2 = byte2,
        }
    end
    return table.concat(parts, ""), entries
end

local function read_npc_signature()
    local signature = read_npc_snapshot()
    return signature
end

local function clear_map_entry_npc_retry()
    map_entry_stale_npc_signatures = nil
    map_entry_npc_refresh_checks = 0
    map_entry_npc_refresh_gap = 0
    map_entry_force_accept_npcs = false
end

local function remember_map_entry_stale_npc_signature(signature)
    if signature == nil then return end
    if map_entry_stale_npc_signatures == nil then
        map_entry_stale_npc_signatures = {}
    end
    map_entry_stale_npc_signatures[signature] = true
end

local function is_map_entry_stale_npc_signature(signature)
    return map_entry_stale_npc_signatures ~= nil
        and map_entry_stale_npc_signatures[signature] == true
end

local function remember_accepted_npc_signature(map_id, signature)
    if map_id == nil or signature == nil then return end
    last_accepted_npc_signature = signature
    reload_state.last_accepted_npc_signature = signature
    accepted_npc_signature_by_map[map_id] = signature
end

function M.observe_npcs(map_id)
    if map_id == nil or is_overworld_context() then
        return
    end
    remember_accepted_npc_signature(map_id, read_npc_signature())
end

-- get_nearby_chests(px, py, max_dist): Return chests within max_dist
-- Manhattan distance of (px, py), sorted closest first.
-- Used by main.lua to identify which chest was just collected.
-- Must be declared here (after object_list) so the closure captures
-- the local variable rather than treating it as a global.
function M.get_nearby_chests(px, py, max_dist)
    max_dist = max_dist or 1
    local result = {}
    for _, obj in ipairs(object_list) do
        if obj.type == M.TYPE_CHEST then
            local dist = math.abs(obj.x - px) + math.abs(obj.y - py)
            if dist <= max_dist then
                result[#result + 1] = {obj = obj, dist = dist}
            end
        end
    end
    table.sort(result, function(a, b) return a.dist < b.dist end)
    return result
end

-- ============================================================
-- NPC Parsing
-- ============================================================

-- parse_npcs(map_id): Read NPC data from RAM and return a list of
-- NPC objects. Each NPC entry in RAM is 3 bytes starting at 0x0051:
--   Byte 0: bits 7-5 = sprite type (0-7), bits 4-0 = X position
--   Byte 1: bit 7 = frame, bits 6-5 = direction, bits 4-0 = Y position
--   Byte 2: movement behavior
--
-- We filter out inactive entries by checking for coordinates that
-- are clearly invalid (both zero, or both 31 which seems to mark
-- unused slots).
local function parse_npcs(map_id)
    -- Only town/castle interiors expose useful NPC RAM for object browsing.
    -- Overworld and dungeon/cave contexts can retain stale NPC bytes from the
    -- previous map, so never turn those bytes into current-map objects.
    if not current_context_allows_npcs() then
        return {}
    end

    local current_signature, raw_entries = read_npc_snapshot()
    if not map_entry_force_accept_npcs
       and is_map_entry_stale_npc_signature(current_signature) then
        return {}
    end

    remember_accepted_npc_signature(map_id, current_signature)
    if map_entry_stale_npc_signatures ~= nil then
        clear_map_entry_npc_retry()
    end

    local npcs = {}

    -- Count occurrences of each sprite name for numbering duplicates.
    -- We do two passes: first count, then assign numbers.
    local name_counts = {}
    local entries = {}

    -- First pass: parse all valid NPC entries
    for _, raw in ipairs(raw_entries) do
        local byte0 = raw.byte0
        local byte1 = raw.byte1

        -- Extract fields using FCEUX bitwise operations
        local sprite_type = AND(byte0, 0xE0) / 32   -- bits 7-5 (divide by 32 = shift right 5)
        local x = AND(byte0, 0x1F)                   -- bits 4-0
        local y = AND(byte1, 0x1F)                    -- bits 4-0
        local direction = math.floor(byte1 / 0x20) % 4

        -- Filter out likely-inactive entries:
        -- If both coordinates are 0, the slot is probably unused.
        -- If both are 31 (0x1F), it's also likely unused (max value = sentinel).
        local is_active = true
        if x == 0 and y == 0 then
            is_active = false
        elseif x == 31 and y == 31 then
            is_active = false
        end

        if is_active then
            local name = SPRITE_NAMES[sprite_type] or "NPC"
            name_counts[name] = (name_counts[name] or 0) + 1
            entries[#entries + 1] = {
                x = x,
                y = y,
                sprite_type = sprite_type,
                base_name = name,
                slot = raw.slot,  -- RAM slot index, useful as a stable ID
                direction = direction,
                movement = raw.byte2,
            }
        end
    end

    -- Second pass: number duplicates.
    -- If there are multiple Guards, they become "Guard 1", "Guard 2", etc.
    -- If there's only one of a type, no number is added.
    local name_seen = {}
    for _, entry in ipairs(entries) do
        local base_name = entry.base_name
        local display_name

        if name_counts[base_name] > 1 then
            -- Multiple NPCs of this type — add a number
            name_seen[base_name] = (name_seen[base_name] or 0) + 1
            display_name = base_name .. " " .. name_seen[base_name]
        else
            -- Only one of this type — no number needed
            display_name = base_name
        end

        local is_service = entry.sprite_type == 3
        local npc = {
            x = entry.x,
            y = entry.y,
            name = display_name,
            type = M.TYPE_NPC,
            sprite_type = entry.sprite_type,
            base_name = base_name,
            service = is_service,
            direction = entry.direction,
            movement = entry.movement,
            id = "npc_" .. entry.slot,  -- Stable ID survives list reordering
        }
        npcs[#npcs + 1] = apply_service_interaction_override(npc, map_id)
    end

    return npcs
end

-- ============================================================
-- Chest Parsing (from ROM)
-- ============================================================

-- parse_chests(map_id): Read chest data from ROM and return chests
-- for the given map. Each ROM entry is 4 bytes:
--   Byte 0: map ID
--   Byte 1: X position
--   Byte 2: Y position
--   Byte 3: contents code
--
-- We filter to only return chests on the current map.
local function parse_chests(map_id)
    local chests = {}
    -- +1 because both start and end addresses are inclusive
    local num_bytes = addr.ROM_CHEST_END - addr.ROM_CHEST_START + 1
    local num_entries = math.floor(num_bytes / addr.ROM_CHEST_SIZE)

    for i = 0, num_entries - 1 do
        local base = addr.ROM_CHEST_START + (i * addr.ROM_CHEST_SIZE)
        local chest_map = rom.readbyte(base)
        local chest_x = rom.readbyte(base + 1)
        -- ROM chest Y matches the player coordinate directly (no offset).
        -- Formula: chest_y = ROM_y.
        -- Empirically confirmed on map 5 (throne room):
        --   Chest [6] at ROM_y=1 was physically found at game y=1. ✓
        --   Chests [4],[5] at ROM_y=4 → game y=4 (1 south of player at y=3). ✓
        -- ROM_y=0 is an invalid sentinel (skips Mountain Cave placeholder entries).
        local rom_y = rom.readbyte(base + 2)
        local chest_y = rom_y  -- player coordinate = ROM value directly

        if chest_map == map_id and rom_y > 0 then
            chests[#chests + 1] = {
                x = chest_x,
                y = chest_y,
                name = "Chest",
                type = M.TYPE_CHEST,
                id = "chest_" .. i,
            }
        end
    end

    return chests
end

-- ============================================================
-- Door Parsing (from tile grid)
-- ============================================================

-- parse_doors(map_id): Scan the ROM tile grid for locked door tiles
-- and return a list of door objects for the given map.
--
-- Unlike chests (stored in a dedicated ROM table), doors ARE the tile
-- itself: a locked door is a tile of type DOOR_TILE_TOWN (11) in castle
-- maps or DOOR_TILE_DUNGEON (5) in cave maps. We find them by scanning
-- the decompressed tile grid that map_reader already builds for us.
--
-- DW1 confirmed to have actual locked doors only on map 4 (Tantegel
-- Castle) and map 9. Other maps return an empty list from this scan.
local function parse_doors(map_id)
    -- Determine the door tile type for the current terrain.
    -- TERRAIN_OFFSET at $0016 is set by the game on every map load.
    local terrain_offset = memory.readbyte(addr.TERRAIN_OFFSET)
    local door_tile
    if terrain_offset == 0x10 then
        door_tile = DOOR_TILE_TOWN      -- nil: town/castle door tile type unknown
    elseif terrain_offset == 0x20 then
        door_tile = DOOR_TILE_DUNGEON   -- dungeon/cave maps (unconfirmed)
    else
        return {}  -- overworld or unknown tileset — no locked doors
    end

    -- If the door tile type is unknown for this tileset, skip scanning.
    -- Known doors on this map type must be listed in EXTRA_DOORS below.
    if door_tile == nil then
        return {}
    end

    local grid = map_reader.get_tile_grid(map_id)
    if not grid then return {} end

    local meta = map_reader.get_metadata(map_id)
    if not meta then return {} end

    local doors = {}
    for y = 0, meta.height - 1 do
        for x = 0, meta.width - 1 do
            if grid[y] and grid[y][x] == door_tile then
                doors[#doors + 1] = {
                    x    = x,
                    y    = y,
                    name = "Door",
                    type = M.TYPE_DOOR,
                    id   = "door_" .. x .. "_" .. y,
                }
            end
        end
    end
    return doors
end

-- ============================================================
-- Stair/Exit Lookup
-- ============================================================

-- get_stairs(map_id): Return hard-coded stair entries for this map.
local function get_stairs(map_id)
    local result = {}
    for _, stair in ipairs(STAIRS) do
        if stair.map == map_id then
            result[#result + 1] = {
                x = stair.x,
                y = stair.y,
                name = stair.name .. " to " .. stair.dest,
                type = M.TYPE_STAIR,
                id = "stair_" .. stair.x .. "_" .. stair.y,
            }
        end
    end
    return result
end

-- get_exits(map_id): Return hard-coded exit entries for this map.
local function get_exits(map_id)
    local result = {}
    for _, exit in ipairs(EXITS) do
        if exit.map == map_id then
            result[#result + 1] = {
                x = exit.x,
                y = exit.y,
                name = "Exit to " .. exit.dest,
                type = M.TYPE_EXIT,
                id = "exit_" .. exit.x .. "_" .. exit.y,
            }
        end
    end
    return result
end

local function get_overworld_landmarks()
    local result = {}
    for _, landmark in ipairs(OVERWORLD_LANDMARKS) do
        result[#result + 1] = {
            x = wrap_overworld_coord(OVERWORLD_TANTEGEL_X + landmark.dx),
            y = wrap_overworld_coord(OVERWORLD_TANTEGEL_Y + landmark.dy),
            name = landmark.name,
            type = M.TYPE_EXIT,
            id = "overworld_" .. landmark.name:gsub("[^%w]+", "_"):lower(),
        }
    end
    for _, waypoint in ipairs(overworld_routes.get_active_waypoint_objects()) do
        result[#result + 1] = waypoint
    end
    return result
end

-- ============================================================
-- Distance and Direction
-- ============================================================

-- get_distance(px, py, ox, oy): Calculate Manhattan distance between
-- the player and an object. Used for sorting objects closest-first.
local function get_distance(px, py, ox, oy)
    return math.abs(px - ox) + math.abs(py - oy)
end

-- get_direction_string(px, py, ox, oy): Build a human-readable
-- direction and distance string from the player to an object.
-- Examples:
--   "3 north, 2 east"
--   "5 south"
--   "here"
function M.get_direction_string(px, py, ox, oy)
    -- Check if the player is standing on the object
    if px == ox and py == oy then
        return "here"
    end

    local parts = {}

    -- Vertical component (north/south)
    -- In Dragon Warrior, lower Y = further north (top of screen)
    if oy < py then
        parts[#parts + 1] = (py - oy) .. " north"
    elseif oy > py then
        parts[#parts + 1] = (oy - py) .. " south"
    end

    -- Horizontal component (east/west)
    -- Higher X = further east (right side of screen)
    if ox > px then
        parts[#parts + 1] = (ox - px) .. " east"
    elseif ox < px then
        parts[#parts + 1] = (px - ox) .. " west"
    end

    return table.concat(parts, ", ")
end

-- ============================================================
-- Object List Building
-- ============================================================

-- Hardcoded doors for maps where the magic-key door tile is type-15 (wall) in
-- ROM, so parse_doors() cannot find them. Cache these with other static object
-- sources; opened status is checked live when the object is described.
local EXTRA_DOORS = {
    -- Map 0x04: Tantegel Castle south gate to the world map. The gate is
    -- visually two tiles wide, but live pathing confirms only the west door
    -- tile is actionable from inside the castle. The east visual half at
    -- (11,30) has no reachable adjacent stand tile, so exposing it as a
    -- separate object just creates a permanent false survey failure.
    --
    -- Keep this object for explicit door navigation, but exclude it from
    -- autonomous surveys: approaching it from (10,29) can step through the
    -- castle exit and end the run on the world map.
    [0x04] = {
        {x=10, y=30, name="Door", type=M.TYPE_DOOR, id="door_10_30", survey_exclude=true},
        {x=14, y=6, name="Center Door", type=M.TYPE_DOOR, id="door_14_6", survey_exclude=true},
    },
    -- Map 0x05: Tantegel Castle Throne Room, south-wall arch at (4,7).
    -- The ROM tile is type-15; is_walkable() in map_reader.lua checks the
    -- opened-door RAM directly for this cell.
    [0x05] = {{x=4, y=7, name="Door", type=M.TYPE_DOOR, id="door_4_7"}},
    -- Map 0x08: Brecconary has two locked doors that are not encoded as a
    -- distinct town door tile: the northeast building and the west room in the
    -- inn. External guide/map labels disagree on nearby service names, so keep
    -- the navigation labels positional; local topology isolates Woman 1 behind
    -- (21,6) and Guard 4 behind (5,22).
    [0x08] = {
        {x=21, y=6, name="Northeast Door", type=M.TYPE_DOOR, id="door_21_6"},
        {x=5, y=22, name="Inn West Room Door", type=M.TYPE_DOOR, id="door_5_22"},
    },
    -- Map 0x09: Garinham. Guide data lists two town-scope locked doors, but
    -- only the public east-end locked-building entrance has a live coordinate
    -- so far. The internal grey-building door should be added after keys let us
    -- confirm its exact cell from inside.
    [0x09] = {
        {x=19, y=16, name="East Door", type=M.TYPE_DOOR, id="door_19_16"},
    },
}

local SERVICE_INTERACTION_OVERRIDES = {
    -- Tantegel Castle MP-restoring Sage. The NPC occupies (20,26), but the
    -- live TALK trigger works from the public west-side stand at (18,26)
    -- while facing east across the counter/seam.
    [0x04] = {
        ["20,26"] = {x = 18, y = 26, face_dir = "east", label = "counter", name = "Sage"},
    },

    -- Brecconary weapon/armor shop. The keeper occupies (5,4), but TALK opens
    -- the shop from the doorway/counter square at (5,6) while facing north.
    -- The inn can be opened from the public west-side stand tile at (8,21)
    -- while facing east. The intermediate counter tile (9,21) is walkable but
    -- blocks west-side entry, so routing directly to it strands public paths.
    -- The tool shop counter can be used from the public west-side stand at
    -- (23,25) while facing east. Walking east into the raw counter trigger at
    -- (24,25) is engine-blocked, but TALK still reaches the counter across
    -- that blocked movement edge.
    [0x08] = {
        ["5,4"] = {x = 5, y = 6, face_dir = "north", label = "counter", name = "Weapons Merchant"},
        ["10,21"] = {x = 8, y = 21, face_dir = "east", label = "counter", name = "Inn"},
        ["25,25"] = {x = 23, y = 25, face_dir = "east", label = "counter", name = "Tool Merchant"},
    },

    -- Garinham public shops. The inn keeper occupies (17,15); live TALK proof
    -- from the public counter stand at (15,15) facing east opened the inn
    -- prompt. The weapon/armor keeper occupies (10,18), while live TALK proof
    -- from the public counter stand at (10,16) facing south opened the shop.
    [0x09] = {
        ["17,15"] = {x = 15, y = 15, face_dir = "east", label = "counter", name = "Inn"},
        ["10,18"] = {x = 10, y = 16, face_dir = "south", label = "counter", name = "Weapons Merchant"},
    },
}

local SERVICE_ROLE_OVERRIDES = {
    -- User-validated Tantegel Castle MP restoration service. The interaction
    -- stand is modeled in SERVICE_INTERACTION_OVERRIDES above.
    [0x04] = {
        names = {
            ["Merchant 3"] = {name = "Magic Key Merchant", infer_counter = true},
            ["Old Man 2"] = {name = "Sage", infer_counter = false},
        },
        cells = {
            ["20,26"] = {name = "Sage", infer_counter = false},
        },
    },
    -- Confirmed Brecconary special-service NPCs that are not merchant sprites.
    -- They should appear in Services, but route like ordinary adjacent NPCs.
    [0x08] = {
        names = {
            ["Woman 1"] = {name = "Fairy Water Merchant", infer_counter = false},
            ["Old Man 2"] = {name = "Curse Remover", infer_counter = false},
        },
        cells = {
            ["24,4"] = {name = "Fairy Water Merchant", infer_counter = false},
            ["24,10"] = {name = "Curse Remover", infer_counter = false},
        },
    },
    -- Garinham public shops. Live play opened the item list from Merchant 2,
    -- the inn prompt from Merchant 3, and the weapon/armor list from Merchant 4.
    [0x09] = {
        names = {
            ["Merchant 2"] = {name = "Tool Merchant", infer_counter = true},
            ["Merchant 3"] = {name = "Inn", infer_counter = true},
            ["Merchant 4"] = {name = "Weapons Merchant", infer_counter = true},
        },
    },
}

local SERVICE_EXCLUSIONS = {
    -- Tantegel Castle Merchants 1 and 2 only offer dialogue. Keep them
    -- browsable under NPCs, but keep Services focused on actual shops.
    [0x04] = {
        ["Merchant 1"] = true,
        ["Merchant 2"] = true,
    },

    -- Brecconary Merchant 1 only gives ordinary dialogue, so keep him in NPCs
    -- but out of the Services filter.
    [0x08] = {
        ["Merchant 1"] = true,
    },
}

local COUNTER_DIRECTIONS = {
    {dx =  0, dy = -1, face_dir = "south"},
    {dx =  1, dy =  0, face_dir = "west"},
    {dx =  0, dy =  1, face_dir = "north"},
    {dx = -1, dy =  0, face_dir = "east"},
}

local NPC_TELEPORT_ADJACENT_OFFSETS = {
    {dx =  0, dy = -1, note = "north", face_dir = "south"},
    {dx =  1, dy =  0, note = "east",  face_dir = "west"},
    {dx =  0, dy =  1, note = "south", face_dir = "north"},
    {dx = -1, dy =  0, note = "west",  face_dir = "east"},
}

local TELEPORT_ESCAPE_DIRECTIONS = {
    {dx =  0, dy = -1, approach = "south"},
    {dx =  1, dy =  0, approach = "west"},
    {dx =  0, dy =  1, approach = "north"},
    {dx = -1, dy =  0, approach = "east"},
}

local CONFIRMED_DIRECT_COUNTER_TILES = {
}

local function safe_is_large_tile(map_id, x, y)
    if type(map_reader.is_large_tile) ~= "function" then
        return false
    end
    local ok, result = pcall(map_reader.is_large_tile, map_id, x, y)
    return ok and result == true
end

local function safe_is_walkable(map_id, x, y)
    if type(map_reader.is_walkable) ~= "function" then
        return false
    end
    local ok, result = pcall(map_reader.is_walkable, map_id, x, y)
    return ok and result == true
end

local function confirmed_direct_counter_tile(map_id, obj_key, x, y)
    local by_map = CONFIRMED_DIRECT_COUNTER_TILES[map_id]
    local entry = by_map and by_map[obj_key]
    return entry ~= nil and entry.x == x and entry.y == y
end

local function is_service_excluded(obj, map_id)
    local by_map = SERVICE_EXCLUSIONS[map_id]
    return by_map ~= nil and by_map[obj.name] == true
end

local function apply_service_role_override(obj, map_id)
    local by_map = SERVICE_ROLE_OVERRIDES[map_id]
    if not by_map then
        return nil
    end
    local entry = by_map.names and by_map.names[obj.name]
    if not entry and by_map.cells then
        entry = by_map.cells[obj.x .. "," .. obj.y]
    end
    if not entry then
        return nil
    end
    obj.service = true
    if entry.name then
        obj.name = entry.name
    end
    return entry
end

local function infer_service_interaction(obj, map_id)
    local obj_key = obj.x .. "," .. obj.y
    local fallback = nil

    for _, dir in ipairs(COUNTER_DIRECTIONS) do
        local counter_x = obj.x + dir.dx
        local counter_y = obj.y + dir.dy
        if safe_is_large_tile(map_id, counter_x, counter_y) then
            local stand_x = obj.x + dir.dx * 2
            local stand_y = obj.y + dir.dy * 2
            if safe_is_walkable(map_id, stand_x, stand_y) then
                obj.interaction_x = stand_x
                obj.interaction_y = stand_y
                obj.interaction_face_dir = dir.face_dir
                obj.interaction_label = "counter"
                return obj
            end
            if not fallback
               and safe_is_walkable(map_id, counter_x, counter_y)
               and confirmed_direct_counter_tile(map_id, obj_key, counter_x, counter_y) then
                fallback = {
                    x = counter_x,
                    y = counter_y,
                    face_dir = dir.face_dir,
                }
            end
        end
    end

    if fallback then
        obj.interaction_x = fallback.x
        obj.interaction_y = fallback.y
        obj.interaction_face_dir = fallback.face_dir
        obj.interaction_label = "counter"
    end
    return obj
end

apply_service_interaction_override = function(obj, map_id)
    if not obj then
        return obj
    end
    local role_override = apply_service_role_override(obj, map_id)
    if obj.service == true and is_service_excluded(obj, map_id) then
        obj.service = false
        return obj
    end
    if obj.service ~= true then
        return obj
    end
    local by_cell = SERVICE_INTERACTION_OVERRIDES[map_id]
    local override = by_cell and by_cell[obj.x .. "," .. obj.y]
    if override then
        if override.name then
            obj.name = override.name
        end
        obj.interaction_x = override.x
        obj.interaction_y = override.y
        obj.interaction_face_dir = override.face_dir
        obj.interaction_label = override.label
        return obj
    end
    if role_override and role_override.infer_counter == false then
        return obj
    end
    return infer_service_interaction(obj, map_id)
end

local function append_objects(dest, source)
    for _, obj in ipairs(source) do
        dest[#dest + 1] = obj
    end
end

local function get_static_objects(map_id)
    if static_object_cache[map_id] then
        return static_object_cache[map_id]
    end

    local objects = {}
    append_objects(objects, get_stairs(map_id))
    append_objects(objects, parse_chests(map_id))
    append_objects(objects, get_exits(map_id))
    append_objects(objects, parse_doors(map_id))

    local extra = EXTRA_DOORS[map_id]
    if extra then
        append_objects(objects, extra)
    end

    static_object_cache[map_id] = objects
    return objects
end

-- build_object_list(map_id): Assemble the full object list for a map.
-- Combines NPCs, stairs, chests, and exits into a single flat list
-- sorted by distance from the player (closest first).
local function build_object_list(map_id, opts)
    opts = opts or {}
    local _, px, py = nav.get_position()

    -- When the terrain offset says "world map", ignore interior object tables
    -- entirely. Populate the list from a dedicated landmark table instead.
    if is_overworld_context() then
        local landmarks = get_overworld_landmarks()
        table.sort(landmarks, function(a, b)
            local da = get_distance(px, py, a.x, a.y)
            local db = get_distance(px, py, b.x, b.y)
            if da == db then
                return a.id < b.id
            end
            return da < db
        end)
        return landmarks
    end

    local objects = {}

    -- Gather objects from all sources
    if not opts.skip_npcs then
        local npcs = parse_npcs(map_id)
        append_objects(objects, npcs)
    end
    append_objects(objects, get_static_objects(map_id))

    -- Sort by distance from player (closest first)
    table.sort(objects, function(a, b)
        local da = get_distance(px, py, a.x, a.y)
        local db = get_distance(px, py, b.x, b.y)
        -- Stable sort tie-breaker: use object ID string
        if da == db then
            return a.id < b.id
        end
        return da < db
    end)

    return objects
end

-- ============================================================
-- Filtering
-- ============================================================

local function matches_type_filter(obj, filter)
    if filter == M.FILTER_ALL then
        return true
    end

    return (filter == M.FILTER_NPC and obj.type == M.TYPE_NPC)
        or (filter == M.FILTER_SERVICE and obj.type == M.TYPE_NPC and obj.service == true)
        or (filter == M.FILTER_TREASURE and obj.type == M.TYPE_CHEST)
        or (filter == M.FILTER_TRAVEL and (obj.type == M.TYPE_EXIT or obj.type == M.TYPE_STAIR))
        or (filter == M.FILTER_DOOR and obj.type == M.TYPE_DOOR)
end

local function matches_pathability_filter(obj)
    if current_pathability_filter == M.PATHABILITY_ALL then
        return true
    end

    local status = obj and obj.id and pathability_status_by_id[obj.id]
    if current_pathability_filter == M.PATHABILITY_REACHABLE then
        return status == true
    end
    if current_pathability_filter == M.PATHABILITY_UNREACHABLE then
        return status == false
    end
    return true
end

-- apply_filter(objects, filter): Return a new list containing only objects
-- matching the current type and pathability filters.
local function apply_filter(objects, filter)
    if filter == M.FILTER_ALL and current_pathability_filter == M.PATHABILITY_ALL then
        return objects
    end

    local result = {}
    for _, obj in ipairs(objects) do
        if matches_type_filter(obj, filter) and matches_pathability_filter(obj) then
            result[#result + 1] = obj
        end
    end
    return result
end

-- rebuild_filtered_list(): Rebuild the filtered view from the current
-- object list and filter setting. Called after the object list changes
-- or when the filter changes.
-- Preserves selection by matching selected_id in the new list.
local function rebuild_filtered_list()
    filtered_list = apply_filter(object_list, current_filter)

    -- Try to restore selection by ID (survives re-sort from NPC movement)
    if selected_id and #filtered_list > 0 then
        for i, obj in ipairs(filtered_list) do
            if obj.id == selected_id then
                current_index = i
                return
            end
        end
    end

    -- ID not found or no selection — clamp index
    if current_index > #filtered_list then
        current_index = 1
    end
    if current_index < 1 then
        current_index = 1
    end
    -- Update selected_id to match wherever we landed
    if filtered_list[current_index] then
        selected_id = filtered_list[current_index].id
    else
        selected_id = nil
    end
end

-- ============================================================
-- Public API: List Management
-- ============================================================

-- refresh(map_id): Rebuild the entire object list for a new map.
-- Call this on map changes. Resets selection to the first object.
function M.refresh(map_id, opts)
    opts = opts or {}
    current_map_id = map_id
    current_terrain_offset = get_terrain_offset()
    prewarm_path_grid(map_id)
    object_list = build_object_list(map_id, opts)
    pathability_status_by_id = {}
    npc_refresh_counter = 0
    refresh_pending = opts.defer_npcs == true
    refresh_defer_checks = math.max(0, tonumber(opts.defer_checks) or 0)
    map_entry_stale_npc_signatures = nil
    remember_map_entry_stale_npc_signature(opts.stale_npc_signature)
    map_entry_npc_refresh_checks = math.max(0, tonumber(opts.npc_refresh_checks) or 0)
    map_entry_npc_refresh_gap = 0
    map_entry_force_accept_npcs = false
    current_index = 1
    selected_id = nil  -- Clear selection on full refresh (new map)
    rebuild_filtered_list()
end

function M.on_map_change(map_id, opts)
    opts = opts or {}
    local allows_npcs = current_context_allows_npcs()
    local stale_npc_signature = nil
    local npc_refresh_checks = 0
    if allows_npcs then
        local current_signature = read_npc_signature()
        local previous_map_id = opts.previous_map_id
        if previous_map_id == nil and current_map_id ~= map_id then
            previous_map_id = current_map_id
        end
        local previous_signature = previous_map_id and accepted_npc_signature_by_map[previous_map_id]
            or last_accepted_npc_signature
        if previous_signature ~= nil and current_signature == previous_signature then
            stale_npc_signature = current_signature
            npc_refresh_checks = MAP_ENTRY_NPC_REFRESH_CHECKS
        end
    end
    M.refresh(map_id, {
        skip_npcs = true,
        defer_npcs = allows_npcs,
        stale_npc_signature = stale_npc_signature,
        npc_refresh_checks = npc_refresh_checks,
    })
end

-- update_npcs(): Re-read NPC positions from RAM without doing a full
-- rebuild. Preserves the current selection by matching object IDs.
-- Call this periodically (every ~20 frames) since NPCs move.
function M.update_npcs()
    if current_map_id == nil then return end

    -- Rebuild the full list (NPCs may have moved).
    -- rebuild_filtered_list() preserves selection by selected_id automatically.
    object_list = build_object_list(current_map_id)
    rebuild_filtered_list()
end

-- request_refresh(): Schedule an NPC position rebuild for the next
-- check_refresh() call. Use this instead of update_npcs() when calling
-- from code that runs before frameadvance() — the deferred rebuild
-- ensures RAM reflects the game's actual NPC positions (not a frozen
-- snapshot that was restored during the previous frame).
function M.request_refresh()
    refresh_pending = true
end

function M.needs_refresh(map_id)
    local terrain_offset = get_terrain_offset()
    return refresh_pending
        or map_entry_npc_refresh_checks > 0
        or map_id ~= current_map_id
        or terrain_offset ~= current_terrain_offset
end

-- check_refresh(map_id): Called every frame from the main loop.
-- Handles map-change detection and periodic NPC position refresh.
function M.check_refresh(map_id)
    local terrain_offset = get_terrain_offset()

    -- Full rebuild on map change
    if map_id ~= current_map_id or terrain_offset ~= current_terrain_offset then
        M.on_map_change(map_id, {previous_map_id = current_map_id})
        return
    end

    -- Deferred rebuild requested by request_refresh()
    if refresh_pending then
        if refresh_defer_checks > 0 then
            refresh_defer_checks = refresh_defer_checks - 1
            return
        end
        refresh_pending = false
        refresh_defer_checks = 0
        npc_refresh_counter = 0
        M.update_npcs()
        return
    end

    if map_entry_npc_refresh_checks > 0 then
        if map_entry_npc_refresh_gap > 0 then
            map_entry_npc_refresh_gap = map_entry_npc_refresh_gap - 1
            return
        end
        map_entry_npc_refresh_checks = map_entry_npc_refresh_checks - 1
        map_entry_force_accept_npcs = map_entry_npc_refresh_checks <= 0
        M.update_npcs()
        map_entry_force_accept_npcs = false
        if map_entry_stale_npc_signatures ~= nil and map_entry_npc_refresh_checks > 0 then
            map_entry_npc_refresh_gap = MAP_ENTRY_NPC_REFRESH_INTERVAL
        end
        return
    end

    -- BizHawk memory-domain calls are slow enough that periodic background
    -- object rebuilds can audibly hitch the emulator. Keep explicit route,
    -- debug, and deferred map-load refreshes intact, but avoid doing this in
    -- the idle frame loop unless the user opts back in.
    if not periodic_npc_refresh_enabled() then
        return
    end

    -- Periodic NPC position update
    npc_refresh_counter = npc_refresh_counter + 1
    if npc_refresh_counter >= NPC_REFRESH_INTERVAL then
        npc_refresh_counter = 0
        M.update_npcs()
    end
end

-- ============================================================
-- Public API: Navigation (called from hotkeys)
-- ============================================================

-- next_object(): Move selection to the next object in the filtered list.
-- Wraps around to the first object after the last.
-- Returns the selected object, or nil if the list is empty.
function M.next_object()
    if #filtered_list == 0 then return nil end

    current_index = current_index + 1
    if current_index > #filtered_list then
        current_index = 1  -- Wrap to start
    end

    selected_id = filtered_list[current_index].id
    return filtered_list[current_index]
end

-- prev_object(): Move selection to the previous object in the filtered list.
-- Wraps around to the last object before the first.
-- Returns the selected object, or nil if the list is empty.
function M.prev_object()
    if #filtered_list == 0 then return nil end

    current_index = current_index - 1
    if current_index < 1 then
        current_index = #filtered_list  -- Wrap to end
    end

    selected_id = filtered_list[current_index].id
    return filtered_list[current_index]
end

-- current_object(): Return the currently selected object without
-- changing the selection. Returns nil if the list is empty.
function M.current_object()
    if #filtered_list == 0 then return nil end
    return filtered_list[current_index]
end

-- next_filter(): Cycle to the next filter mode.
-- Returns the filter name string (e.g., "NPCs", "All").
function M.next_filter()
    current_filter = current_filter + 1
    if current_filter > FILTER_COUNT then
        current_filter = M.FILTER_ALL  -- Wrap to All
    end

    -- Rebuild filtered view and reset index
    current_index = 1
    selected_id = nil  -- Clear selection on filter change
    rebuild_filtered_list()

    return FILTER_NAMES[current_filter]
end

function M.prev_filter()
    current_filter = current_filter - 1
    if current_filter < M.FILTER_ALL then
        current_filter = FILTER_COUNT
    end

    current_index = 1
    selected_id = nil
    rebuild_filtered_list()

    return FILTER_NAMES[current_filter]
end

function M.all_filter()
    return M.set_filter(M.FILTER_ALL)
end

function M.set_filter(filter)
    filter = tonumber(filter) or M.FILTER_ALL
    if filter < M.FILTER_ALL or filter > FILTER_COUNT then
        filter = M.FILTER_ALL
    end
    current_filter = filter
    current_index = 1
    selected_id = nil
    rebuild_filtered_list()

    return FILTER_NAMES[current_filter]
end

function M.travel_filter()
    return M.set_filter(M.FILTER_TRAVEL)
end

function M.select_object_by_id(object_id)
    if not object_id then
        return nil
    end
    for i, obj in ipairs(filtered_list) do
        if obj.id == object_id then
            current_index = i
            selected_id = obj.id
            return obj
        end
    end
    return nil
end

function M.set_pathability_filter(filter)
    if filter < M.PATHABILITY_ALL or filter > PATHABILITY_COUNT then
        filter = M.PATHABILITY_ALL
    end
    current_pathability_filter = filter
    current_index = 1
    selected_id = nil
    rebuild_filtered_list()
    return PATHABILITY_NAMES[current_pathability_filter]
end

function M.next_pathability_filter()
    local next_filter = current_pathability_filter + 1
    if next_filter > PATHABILITY_COUNT then
        next_filter = M.PATHABILITY_ALL
    end
    return M.set_pathability_filter(next_filter)
end

function M.all_pathability_filter()
    return M.set_pathability_filter(M.PATHABILITY_ALL)
end

function M.set_pathability_statuses(status_by_id)
    pathability_status_by_id = status_by_id or {}
    rebuild_filtered_list()
end

function M.clear_pathability_statuses()
    pathability_status_by_id = {}
    rebuild_filtered_list()
end

function M.get_pathability_filter()
    return current_pathability_filter
end

function M.get_pathability_filter_name()
    return PATHABILITY_NAMES[current_pathability_filter]
end

function M.is_pathability_filter_active()
    return current_pathability_filter ~= M.PATHABILITY_ALL
end

function M.get_filter_summary()
    local type_name = FILTER_NAMES[current_filter]
    if current_pathability_filter == M.PATHABILITY_ALL then
        return type_name
    end
    local path_name = PATHABILITY_NAMES[current_pathability_filter]:lower()
    return type_name .. ", " .. path_name
end

-- get_filter_name(): Return the name of the current filter.
function M.get_filter_name()
    return FILTER_NAMES[current_filter]
end

-- get_count(): Return how many objects are in the current filtered list.
function M.get_count()
    return #filtered_list
end

-- get_objects(opts): Return a shallow copy of the current object list.
-- By default returns all detected objects for the map; pass
-- opts.filtered=true to return the current filtered view instead.
function M.get_objects(opts)
    opts = opts or {}
    local source = opts.filtered and filtered_list or object_list
    local result = {}
    for i, obj in ipairs(source) do
        result[i] = obj
    end
    return result
end

-- find_object_by_id(object_id, opts): Look up an object by stable ID.
-- Searches the full object list by default; pass opts.filtered=true to
-- limit the lookup to the current filtered view.
function M.find_object_by_id(object_id, opts)
    if not object_id then return nil end
    opts = opts or {}
    local source = opts.filtered and filtered_list or object_list
    for _, obj in ipairs(source) do
        if obj.id == object_id then
            return obj
        end
    end
    return nil
end

function M.is_visited(obj, map_id)
    if not obj or not obj.id then return false end
    local bucket = visited_bucket(map_id, false)
    return bucket and bucket[obj.id] == true or false
end

function M.mark_visited(obj, map_id)
    if not obj or not obj.id then return nil end
    local bucket, resolved_map_id = visited_bucket(map_id, true)
    if not bucket then return nil end
    bucket[obj.id] = true
    return obj, resolved_map_id
end

function M.mark_current_visited()
    local obj = M.current_object()
    return M.mark_visited(obj)
end

function M.clear_visited(map_id_or_all)
    if map_id_or_all == "all" then
        local cleared = 0
        for _, bucket in pairs(visited_by_map) do
            for _ in pairs(bucket) do
                cleared = cleared + 1
            end
        end
        for map_id in pairs(visited_by_map) do
            visited_by_map[map_id] = nil
        end
        return cleared
    end

    local map_id = active_map_id(map_id_or_all)
    local bucket = map_id and visited_by_map[map_id] or nil
    local cleared = 0
    if bucket then
        for _ in pairs(bucket) do
            cleared = cleared + 1
        end
        visited_by_map[map_id] = nil
    end
    return cleared
end

function M.mark_adjacent_npc_visited(map_id, px, py)
    map_id = active_map_id(map_id)
    if px == nil or py == nil then
        local _, cur_x, cur_y = nav.get_position()
        px, py = cur_x, cur_y
    end

    local selected = M.current_object()
    if selected
       and selected.type == M.TYPE_NPC
       and math.abs(selected.x - px) + math.abs(selected.y - py) <= 1 then
        return M.mark_visited(selected, map_id)
    end
    if selected
       and selected.type == M.TYPE_NPC
       and selected.interaction_x == px
       and selected.interaction_y == py then
        return M.mark_visited(selected, map_id)
    end

    local interaction_best = nil
    for _, obj in ipairs(object_list) do
        if obj.type == M.TYPE_NPC
           and obj.interaction_x == px
           and obj.interaction_y == py
           and (not interaction_best or obj.id < interaction_best.id) then
            interaction_best = obj
        end
    end
    if interaction_best then
        return M.mark_visited(interaction_best, map_id)
    end

    local best = nil
    local best_dist = nil
    for _, obj in ipairs(object_list) do
        if obj.type == M.TYPE_NPC then
            local dist = math.abs(obj.x - px) + math.abs(obj.y - py)
            if dist <= 1 and (not best_dist or dist < best_dist or obj.id < best.id) then
                best = obj
                best_dist = dist
            end
        end
    end
    if best then
        return M.mark_visited(best, map_id)
    end

    local selected_slot = nil
    if selected and selected.id then
        selected_slot = tonumber(tostring(selected.id):match("^npc_(%d+)$"))
    end

    local live_best = nil
    local live_best_dist = nil
    for slot = 0, addr.NPC_COUNT - 1 do
        local base = addr.NPC_DATA_START + (slot * addr.NPC_ENTRY_SIZE)
        local byte0 = memory.readbyte(base)
        local byte1 = memory.readbyte(base + 1)
        local x = AND(byte0, 0x1F)
        local y = AND(byte1, 0x1F)
        if not (x == 0 and y == 0) and not (x == 31 and y == 31) then
            local dist = math.abs(x - px) + math.abs(y - py)
            if dist <= 1 then
                local id = "npc_" .. slot
                local existing = M.find_object_by_id(id)
                local candidate = existing or {
                    id = id,
                    type = M.TYPE_NPC,
                    name = "NPC " .. (slot + 1),
                    x = x,
                    y = y,
                }
                if slot == selected_slot then
                    return M.mark_visited(candidate, map_id)
                end
                if not live_best_dist or dist < live_best_dist or id < live_best.id then
                    live_best = candidate
                    live_best_dist = dist
                end
            end
        end
    end
    return M.mark_visited(live_best, map_id)
end

-- get_blocking_positions(): Return a list of {x, y} for all objects that
-- physically block movement even though their tile type is walkable floor.
-- In DW1, only NPCs block movement — you cannot walk through an NPC.
-- Chests do NOT block movement: the player can walk onto a chest tile
-- (which opens the chest). Empirically confirmed: player was observed
-- standing on chest tile (4,4) while the chest was still listed as
-- unopened. Including chests in the block list caused "No path found"
-- when a chest happened to be on the only available route.
function M.get_blocking_positions()
    local result = {}
    for _, obj in ipairs(object_list) do
        if obj.type == M.TYPE_NPC then
            result[#result + 1] = {x = obj.x, y = obj.y}
        end
    end
    return result
end

function M.is_npc_at(map_id, x, y)
    if x == nil or y == nil then return false end
    for _, npc in ipairs(parse_npcs(map_id)) do
        if npc.x == x and npc.y == y then
            return true
        end
    end
    return false
end

local function map_contains(map_id, x, y)
    if type(map_reader.get_map_dimensions) ~= "function" then
        return true
    end
    local ok, width, height = pcall(map_reader.get_map_dimensions, map_id)
    if not ok or width == nil or height == nil then
        return true
    end
    return x >= 0 and y >= 0 and x < width and y < height
end

local function live_npc_object(obj, map_id)
    if not obj or obj.type ~= M.TYPE_NPC or not obj.id then
        return obj
    end
    local slot = tonumber(tostring(obj.id):match("^npc_(%d+)$"))
    if slot == nil or slot < 0 or slot >= addr.NPC_COUNT then
        return obj
    end

    local base = addr.NPC_DATA_START + (slot * addr.NPC_ENTRY_SIZE)
    local byte0 = memory.readbyte(base)
    local byte1 = memory.readbyte(base + 1)
    local byte2 = memory.readbyte(base + 2)
    local x = AND(byte0, 0x1F)
    local y = AND(byte1, 0x1F)
    if (x == 0 and y == 0) or (x == 31 and y == 31) then
        return obj
    end

    local live = {}
    for k, v in pairs(obj) do
        live[k] = v
    end
    live.x = x
    live.y = y
    live.sprite_type = AND(byte0, 0xE0) / 32
    live.direction = math.floor(byte1 / 0x20) % 4
    live.movement = byte2
    live.service = live.sprite_type == 3
    return apply_service_interaction_override(live, map_id)
end

local function teleport_landing_open(map_id, x, y, opts)
    opts = opts or {}
    if not map_contains(map_id, x, y) then
        return false, "out of bounds"
    end
    if safe_is_walkable(map_id, x, y) ~= true then
        return false, "not walkable"
    end
    if opts.check_npc ~= false and M.is_npc_at(map_id, x, y) then
        return false, "npc occupied"
    end
    return true, nil
end

local function teleport_step_blocked(map_id, dest_x, dest_y, approach)
    if type(map_reader.get_directional_blocks) ~= "function" then
        return false
    end
    local blocks = map_reader.get_directional_blocks(map_id) or {}
    local entry = blocks[dest_x .. "," .. dest_y]
    return entry ~= nil and entry[approach] == true
end

local function teleport_landing_has_escape(map_id, x, y, target_x, target_y, opts)
    opts = opts or {}
    if opts.require_escape == false then
        return true
    end

    for _, dir in ipairs(TELEPORT_ESCAPE_DIRECTIONS) do
        local nx, ny = x + dir.dx, y + dir.dy
        if nx ~= target_x or ny ~= target_y then
            local ok = teleport_landing_open(map_id, nx, ny, opts)
            if ok and not teleport_step_blocked(map_id, nx, ny, dir.approach) then
                return true
            end
        end
    end

    return false
end

function M.resolve_teleport_landing(obj, map_id, opts)
    opts = opts or {}
    if not obj then
        return nil, "no object selected"
    end
    map_id = active_map_id(map_id)

    if obj.type ~= M.TYPE_NPC then
        local ok = teleport_landing_open(map_id, obj.x, obj.y, opts)
        if ok then
            return {
                x = obj.x,
                y = obj.y,
                target_x = obj.x,
                target_y = obj.y,
                reason = "exact",
            }, nil
        end
        for _, off in ipairs(NPC_TELEPORT_ADJACENT_OFFSETS) do
            local nx, ny = obj.x + off.dx, obj.y + off.dy
            ok = teleport_landing_open(map_id, nx, ny, opts)
            if ok and teleport_landing_has_escape(map_id, nx, ny, obj.x, obj.y, opts) then
                return {
                    x = nx,
                    y = ny,
                    target_x = obj.x,
                    target_y = obj.y,
                    note = off.note,
                    face_dir = off.face_dir,
                    reason = "adjacent",
                }, nil
            end
        end
        return nil, "no open adjacent cell"
    end

    local target = opts.use_live_npc == false and obj or live_npc_object(obj, map_id)
    if target.interaction_x ~= nil and target.interaction_y ~= nil then
        local ok = teleport_landing_open(map_id, target.interaction_x, target.interaction_y, opts)
        if ok then
            return {
                x = target.interaction_x,
                y = target.interaction_y,
                target_x = target.x,
                target_y = target.y,
                note = target.interaction_label or "interaction",
                face_dir = target.interaction_face_dir,
                reason = "interaction",
            }, nil
        end
    end

    for _, off in ipairs(NPC_TELEPORT_ADJACENT_OFFSETS) do
        local nx, ny = target.x + off.dx, target.y + off.dy
        local ok = teleport_landing_open(map_id, nx, ny, opts)
        if ok and teleport_landing_has_escape(map_id, nx, ny, target.x, target.y, opts) then
            return {
                x = nx,
                y = ny,
                target_x = target.x,
                target_y = target.y,
                note = off.note,
                face_dir = off.face_dir,
                reason = "adjacent",
            }, nil
        end
    end

    return nil, "no open adjacent cell"
end

-- ============================================================
-- Public API: Object Description
-- ============================================================

-- describe_object(obj): Return a human-readable description of an
-- object, including its name and direction/distance from the player.
-- Format: "Guard 1: 3 north, 2 east" or "Chest: here"
function M.describe_object(obj)
    if not obj then return "No objects" end

    local _, px, py = nav.get_position()
    local direction = M.get_direction_string(px, py, obj.x, obj.y)
    local name = obj.name
    if obj.type == M.TYPE_CHEST and M.is_chest_opened(obj.id) then
        name = name .. " (opened)"
    end
    if obj.type == M.TYPE_DOOR and is_door_opened(obj.x, obj.y) then
        name = name .. " (opened)"
    end
    if M.is_visited(obj) then
        name = name .. " (visited)"
    end
    if obj.interaction_x ~= nil and obj.interaction_y ~= nil then
        local interaction_direction = M.get_direction_string(px, py, obj.interaction_x, obj.interaction_y)
        local label = obj.interaction_label or "interaction"
        if interaction_direction == "here" then
            return name .. ": " .. direction .. ", " .. label .. " here"
        end
        return name .. ": " .. direction .. ", " .. label .. " " .. interaction_direction
    end
    return name .. ": " .. direction
end

-- describe_current(): Describe the currently selected object.
-- Includes the object's position in the list (e.g., "2 of 5").
-- Also includes raw coordinate debug info to help verify distance math.
function M.describe_current(opts)
    opts = opts or {}
    if #filtered_list == 0 then
        return "No objects found"
    end

    local obj = filtered_list[current_index]
    if opts.use_live_npc ~= false then
        obj = live_npc_object(obj, opts.map_id)
    end
    local desc = M.describe_object(obj)
    local with_count = desc .. " (" .. current_index .. " of " .. #filtered_list .. ")"
    if opts.include_debug_coords == false then
        return with_count
    end

    -- Include raw coordinates for debugging distance calculations.
    -- Format: "Chest: 1 east (2 of 5) [player 4,3 obj 5,3]"
    local _, px, py = nav.get_position()
    local debug_suffix = " [player " .. px .. "," .. py .. " obj " .. obj.x .. "," .. obj.y
    if obj.interaction_x ~= nil and obj.interaction_y ~= nil then
        debug_suffix = debug_suffix .. " interact " .. obj.interaction_x .. "," .. obj.interaction_y
    end
    return with_count .. debug_suffix .. "]"
end

return M
