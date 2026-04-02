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

local M = {}

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
-- The player can cycle through filters with the F key to show
-- only certain types of objects.
M.FILTER_ALL    = 1
M.FILTER_NPC    = 2
M.FILTER_EXIT   = 3
M.FILTER_CHEST  = 4
M.FILTER_STAIR  = 5
M.FILTER_DOOR   = 6

-- Human-readable names for each filter mode
local FILTER_NAMES = {
    [M.FILTER_ALL]   = "All",
    [M.FILTER_NPC]   = "NPCs",
    [M.FILTER_EXIT]  = "Exits",
    [M.FILTER_CHEST] = "Chests",
    [M.FILTER_STAIR] = "Stairs",
    [M.FILTER_DOOR]  = "Doors",
}

-- How many filter modes there are (for wraparound)
local FILTER_COUNT = 6

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
    {map = 0x1C, x = 1, y = 1, name = "Stairs Down", dest = "B2"},

    -- Erdrick's Cave B2 (0x1D)
    {map = 0x1D, x = 1, y = 1, name = "Stairs Up", dest = "B1"},

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

-- Which map we last built the object list for (to detect map changes)
local current_map_id = nil
local current_terrain_offset = nil

-- Frame counter for periodic NPC position updates
local npc_refresh_counter = 0
local NPC_REFRESH_INTERVAL = 20  -- Re-read NPC positions every 20 frames (~0.33s)

-- When true, check_refresh() will rebuild the object list on the next call
-- (after frameadvance has run and RAM reflects real NPC positions).
local refresh_pending = false

local function get_terrain_offset()
    return memory.readbyte(addr.TERRAIN_OFFSET)
end

local function is_overworld_context()
    return get_terrain_offset() == 0x00
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
    -- The overworld does not expose a live NPC table. After leaving an
    -- interior map, the old town/castle NPC bytes can linger in RAM for a
    -- while, so treat any world-map terrain context as having no NPC objects.
    if is_overworld_context() then
        return {}
    end

    local npcs = {}

    -- Count occurrences of each sprite name for numbering duplicates.
    -- We do two passes: first count, then assign numbers.
    local name_counts = {}
    local entries = {}

    -- First pass: parse all valid NPC entries
    for i = 0, addr.NPC_COUNT - 1 do
        local base = addr.NPC_DATA_START + (i * addr.NPC_ENTRY_SIZE)
        local byte0 = memory.readbyte(base)
        local byte1 = memory.readbyte(base + 1)

        -- Extract fields using FCEUX bitwise operations
        local sprite_type = AND(byte0, 0xE0) / 32   -- bits 7-5 (divide by 32 = shift right 5)
        local x = AND(byte0, 0x1F)                   -- bits 4-0
        local y = AND(byte1, 0x1F)                    -- bits 4-0

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
                slot = i,  -- RAM slot index, useful as a stable ID
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

        npcs[#npcs + 1] = {
            x = entry.x,
            y = entry.y,
            name = display_name,
            type = M.TYPE_NPC,
            id = "npc_" .. entry.slot,  -- Stable ID survives list reordering
        }
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
        for _, npc in ipairs(npcs) do
            objects[#objects + 1] = npc
        end
    end

    local stairs = get_stairs(map_id)
    for _, stair in ipairs(stairs) do
        objects[#objects + 1] = stair
    end

    local chests = parse_chests(map_id)
    for _, chest in ipairs(chests) do
        objects[#objects + 1] = chest
    end

    local exits = get_exits(map_id)
    for _, exit in ipairs(exits) do
        objects[#objects + 1] = exit
    end

    local doors = parse_doors(map_id)
    for _, door in ipairs(doors) do
        objects[#objects + 1] = door
    end

    -- Hardcoded doors for maps where the magic-key door tile is type-15
    -- (wall) in ROM, so parse_doors() (which scans for type-11 tiles) will
    -- not find them. These are listed explicitly here so they appear in
    -- navigation and pathfinding as blocked cells until opened.
    local EXTRA_DOORS = {
        -- Map 0x04: Tantegel Castle south gate to the world map. The gate is
        -- visually two tiles wide; both door cells need to appear in the
        -- object list because town/castle door scanning is disabled.
        [0x04] = {
            {x=10, y=30, name="Door", type=M.TYPE_DOOR, id="door_10_30"},
            {x=11, y=30, name="Door", type=M.TYPE_DOOR, id="door_11_30"},
        },
        -- Map 0x05: Tantegel Castle Throne Room, south-wall arch at (4,7).
        -- The ROM tile is type-15; is_walkable() in map_reader.lua checks
        -- the opened-door RAM directly for this cell.
        [0x05] = {{x=4, y=7, name="Door", type=M.TYPE_DOOR, id="door_4_7"}},
    }
    local extra = EXTRA_DOORS[map_id]
    if extra then
        for _, d in ipairs(extra) do
            objects[#objects + 1] = d
        end
    end

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

-- apply_filter(objects, filter): Return a new list containing only
-- objects matching the current filter. FILTER_ALL returns everything.
local function apply_filter(objects, filter)
    if filter == M.FILTER_ALL then
        return objects
    end

    -- Map filter constants to object types
    local filter_type = nil
    if filter == M.FILTER_NPC then
        filter_type = M.TYPE_NPC
    elseif filter == M.FILTER_EXIT then
        filter_type = M.TYPE_EXIT
    elseif filter == M.FILTER_CHEST then
        filter_type = M.TYPE_CHEST
    elseif filter == M.FILTER_STAIR then
        filter_type = M.TYPE_STAIR
    elseif filter == M.FILTER_DOOR then
        filter_type = M.TYPE_DOOR
    end

    local result = {}
    for _, obj in ipairs(objects) do
        if obj.type == filter_type then
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
    object_list = build_object_list(map_id, opts)
    npc_refresh_counter = 0
    refresh_pending = opts.defer_npcs == true
    current_index = 1
    selected_id = nil  -- Clear selection on full refresh (new map)
    rebuild_filtered_list()
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

-- check_refresh(map_id): Called every frame from the main loop.
-- Handles map-change detection and periodic NPC position refresh.
function M.check_refresh(map_id)
    local terrain_offset = get_terrain_offset()

    -- Full rebuild on map change
    if map_id ~= current_map_id or terrain_offset ~= current_terrain_offset then
        local entering_overworld = terrain_offset == 0x00
        M.refresh(map_id, {
            skip_npcs = not entering_overworld,
            defer_npcs = not entering_overworld,
        })
        return
    end

    -- Deferred rebuild requested by request_refresh()
    if refresh_pending then
        refresh_pending = false
        npc_refresh_counter = 0
        M.update_npcs()
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
    return name .. ": " .. direction
end

-- describe_current(): Describe the currently selected object.
-- Includes the object's position in the list (e.g., "2 of 5").
-- Also includes raw coordinate debug info to help verify distance math.
function M.describe_current()
    if #filtered_list == 0 then
        return "No objects found"
    end

    local obj = filtered_list[current_index]
    local desc = M.describe_object(obj)
    -- Include raw coordinates for debugging distance calculations.
    -- Format: "Chest: 1 east (2 of 5) [player 4,3 obj 5,3]"
    local _, px, py = nav.get_position()
    return desc .. " (" .. current_index .. " of " .. #filtered_list .. ")" ..
           " [player " .. px .. "," .. py .. " obj " .. obj.x .. "," .. obj.y .. "]"
end

return M
