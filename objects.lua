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
local darkness = require "darkness"
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
-- Tile scanning is disabled for both tilesets. Actual door positions must be
-- added to EXTRA_DOORS after live OPEN proof. The former dungeon type-5 scan
-- was disproved in Dragonlord's Lair: type 5 at (10,29) is the return stair,
-- while OPEN from (18,12) recorded the real type-11 door at (17,12).
local DOOR_TILE_TOWN    = nil
local DOOR_TILE_DUNGEON = nil

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
    -- Southeast corner special tile: STAIRS works here, while south/east
    -- movement exits the castle to the World Map.
    {
        map = 0x04,
        x = 29,
        y = 29,
        name = "Stairs Down",
        dest = "Sun Shrine",
        object_name = "Sun Shrine Stairs and Southeast Exit",
    },

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
    {map = 0x1C, x = 9, y = 9, name = "Stairs Down", dest = "B2", object_name = "Stairs Down"},

    -- Erdrick's Cave B2 (0x1D)
    -- Confirmed live: STAIRS at (8,9) moves to B1 (map 0x1C) at (9,9).
    {map = 0x1D, x = 8, y = 9, name = "Stairs Up", dest = "B1", object_name = "Stairs Up"},

    -- Mountain Cave F1 (0x16). All three STAIRS transitions were verified
    -- live on 2026-07-30 and match the ROM pairs. Northwest and southeast
    -- reach isolated B2 pockets; central reaches the main B2 area.
    {map = 0x16, x = 0, y = 0, name = "Northwest Stairs Down", dest = "B2", object_name = "Northwest Stairs Down"},
    {map = 0x16, x = 6, y = 5, name = "Central Stairs Down", dest = "B2", object_name = "Central Stairs Down"},
    {map = 0x16, x = 12, y = 12, name = "Southeast Stairs Down", dest = "B2", object_name = "Southeast Stairs Down"},

    -- Mountain Cave B2 (0x17). Reverse STAIRS transitions return to the
    -- same coordinates on F1.
    {map = 0x17, x = 0, y = 0, name = "Northwest Stairs Up", dest = "Mountain Cave", object_name = "Northwest Stairs Up"},
    {map = 0x17, x = 6, y = 5, name = "Central Stairs Up", dest = "Mountain Cave", object_name = "Central Stairs Up"},
    {map = 0x17, x = 12, y = 12, name = "Southeast Stairs Up", dest = "Mountain Cave", object_name = "Southeast Stairs Up"},

    -- Garinham (0x09)
    -- ROM stair-down table entry at 0xF411 is `09 13 00`. Live STAIRS from
    -- (19,0) changed to map 0x18 / Garin's Grave B1; user manual check
    -- confirmed the return stairs come back to this town tile.
    {
        map = 0x09,
        x = 19,
        y = 0,
        name = "Stairs Down",
        dest = "Garin's Grave B1",
        object_name = "Stairs to Garin's Grave",
    },

    -- Garin's Grave B1 (0x18)
    -- Live FCEUX proof after entering from Garinham: the hero appears on
    -- `(6,11)`, and using STAIRS from that same tile returns to Garinham
    -- `(19,0)`. Keep the older fake `exit_0_0` out of EXITS below.
    {
        map = 0x18,
        x = 6,
        y = 11,
        name = "Stairs Up",
        dest = "Garinham",
        object_name = "Stairs to Garinham",
    },
    -- ROM stair-down table entry at 0xF456 is `18 01 12`. User manual check
    -- disproved the older `(19,0)` placeholder; live inspect shows `(1,18)`
    -- is a walkable B1 tile, pending final STAIRS transition proof to map 0x19.
    {map = 0x18, x = 1, y = 18, name = "Stairs Down", dest = "B2", object_name = "Stairs Down"},

    -- Garin's Grave B2 (0x19)
    -- Local ROM stair tables plus the Realm of Darkness composite map line up:
    -- B2 is a 13x11 stair hub with one up stair and five separate down stairs.
    -- The older placeholders `(19,0)` / `(12,12)` were impossible on this map.
    {map = 0x19, x = 11, y = 2, name = "Stairs Up", dest = "B1", object_name = "Stairs Up"},
    {map = 0x19, x = 1, y = 1, name = "Stairs Down", dest = "B3", object_name = "Northwest Stairs Down"},
    {map = 0x19, x = 12, y = 1, name = "Stairs Down", dest = "B3", object_name = "Northeast Stairs Down"},
    {map = 0x19, x = 5, y = 6, name = "Stairs Down", dest = "B3", object_name = "Central Stairs Down"},
    {map = 0x19, x = 1, y = 10, name = "Stairs Down", dest = "B3", object_name = "Southwest Stairs Down"},
    {map = 0x19, x = 12, y = 10, name = "Stairs Down", dest = "B3", object_name = "Southeast Stairs Down"},

    -- Garin's Grave B3 (0x1A)
    -- Local ROM stair tables show five returns up to B2 plus two down stairs
    -- to B4. User live proof confirmed the fourth B2 stair in table order:
    -- B2 southwest `(1,10)` deposits on B3 `(2,17)`.
    {map = 0x1A, x = 14, y = 1, name = "Stairs Up", dest = "B2", object_name = "Northwest Stairs Up"},
    {map = 0x1A, x = 18, y = 1, name = "Stairs Up", dest = "B2", object_name = "Northeast Stairs Up"},
    {map = 0x1A, x = 6, y = 11, name = "Stairs Up", dest = "B2", object_name = "Central Stairs Up"},
    {map = 0x1A, x = 2, y = 17, name = "Stairs Up", dest = "B2", object_name = "Southwest Stairs Up"},
    {map = 0x1A, x = 18, y = 13, name = "Stairs Up", dest = "B2", object_name = "Southeast Stairs Up"},
    {map = 0x1A, x = 9, y = 5, name = "Stairs Down", dest = "B4", object_name = "Upper Stairs Down"},
    {map = 0x1A, x = 10, y = 9, name = "Stairs Down", dest = "B4", object_name = "Lower Stairs Down"},

    -- Garin's Grave B4 (0x1B)
    -- ROM stair tables show two returns from B4 back to B3.
    {map = 0x1B, x = 0, y = 4, name = "Stairs Up", dest = "B3", object_name = "West Stairs Up"},
    {map = 0x1B, x = 5, y = 4, name = "Stairs Up", dest = "B3", object_name = "East Stairs Up"},

    -- Charlock Castle (0x02). The west and east visible stairs are decoys
    -- behind locked side-room doors; both transitions and their B1 returns
    -- were verified live on 2026-08-07.
    {map = 0x02, x = 10, y = 1, name = "Stairs Down", dest = "B1", object_name = "Stairs Down"},
    {map = 0x02, x = 4, y = 14, name = "Stairs Down", dest = "B1", object_name = "West Stairs Down"},
    {map = 0x02, x = 15, y = 14, name = "Stairs Down", dest = "B1", object_name = "East Stairs Down"},

    -- Dragonlord dungeon (raw map IDs from Data Crystal RAM map).
    -- The early floors below are still the best-known mappings from earlier
    -- reverse-engineering. Deeper floor IDs were mis-labeled in older builds,
    -- so we only keep the entries we can map confidently today.
    -- Live STAIRS checks on 2026-08-04 returned to Charlock from the B1
    -- arrival stand (9,0); the older (10,1) coordinate reported no stairs.
    {map = 0x0F, x = 9, y = 0, name = "Stairs Up", dest = "Charlock Castle", object_name = "North Stairs Up"},
    -- Live sword-network traversal entered from B2 at (15,1) and returned
    -- through the same stair during the completed reverse route.
    {map = 0x0F, x = 15, y = 1, name = "Stairs Down", dest = "B2", object_name = "North Stairs Down"},
    -- The visible ground-floor decoys return from isolated B1 components.
    {map = 0x0F, x = 8, y = 13, name = "Stairs Up", dest = "Charlock Castle", object_name = "West Stairs Up"},
    {map = 0x0F, x = 17, y = 15, name = "Stairs Up", dest = "Charlock Castle", object_name = "East Stairs Up"},
    -- The northeast branch enters the isolated B2 Erdrick's Sword room.
    -- Both directions were traversed live on 2026-08-06.
    {map = 0x0F, x = 13, y = 7, name = "Stairs Down", dest = "B2", object_name = "Northeast Stairs Down"},
    -- Four more B1 stairs form two isolated B2 connector pairs. Ordinary
    -- traversal proved every transition on 2026-08-08: (19,7)/(14,9) use
    -- B2 (9,8)/(8,9), and (2,14)/(2,4) use B2 (0,1)/(0,0).
    {map = 0x0F, x = 19, y = 7, name = "Stairs Down", dest = "B2", object_name = "East Stairs Down"},
    {map = 0x0F, x = 14, y = 9, name = "Stairs Down", dest = "B2", object_name = "Central Stairs Down"},
    {map = 0x0F, x = 2, y = 14, name = "Stairs Down", dest = "B2", object_name = "Southwest Stairs Down"},
    {map = 0x0F, x = 2, y = 4, name = "Stairs Down", dest = "B2", object_name = "Northwest Stairs Down"},
    -- The pinned ROM stair graph places B1's main-spine descent at (8,19);
    -- the older (7,7) entry was provisional and pointed at ordinary floor.
    {map = 0x0F, x = 8, y = 19, name = "Stairs Down", dest = "B2", object_name = "South Stairs Down"},
    -- Live main-spine traversal on 2026-08-04 entered B2 at (5,0), then
    -- followed the decoded floor route to the real B3 descent at (3,0).
    -- The older (7,7) and (3,3) entries were ordinary floor/wall placeholders.
    {map = 0x10, x = 5, y = 0, name = "Stairs Up", dest = "B1", object_name = "North Stairs Up"},
    {map = 0x10, x = 3, y = 0, name = "Stairs Down", dest = "B3", object_name = "North Stairs Down"},
    -- Adjacent live-proven connectors in the sword network: (8,0) reaches
    -- B1 (15,1), while (9,1) reaches B3 (2,2).
    {map = 0x10, x = 8, y = 0, name = "Stairs Up", dest = "B1", object_name = "Northeast Stairs Up"},
    {map = 0x10, x = 9, y = 1, name = "Stairs Down", dest = "B3", object_name = "Northeast Stairs Down"},
    {map = 0x10, x = 4, y = 4, name = "Stairs Up", dest = "B1", object_name = "Central Stairs Up"},
    -- Isolated B1-return pairs, traversed end to end on 2026-08-08.
    {map = 0x10, x = 9, y = 8, name = "Stairs Up", dest = "B1", object_name = "Southeast Stairs Up"},
    {map = 0x10, x = 8, y = 9, name = "Stairs Up", dest = "B1", object_name = "South Stairs Up"},
    {map = 0x10, x = 0, y = 1, name = "Stairs Up", dest = "B1", object_name = "West Stairs Up"},
    {map = 0x10, x = 0, y = 0, name = "Stairs Up", dest = "B1", object_name = "Northwest Stairs Up"},
    -- B3 has four distinct returns to B2 and two descents to B4. The main
    -- route entered at (7,0), traversed the false-stair loop through (0,9),
    -- re-entered at (5,4), and reached the true descent at (1,6). The other
    -- two coordinates come from the same pinned ROM stair graph.
    {map = 0x11, x = 7, y = 0, name = "Stairs Up", dest = "B2", object_name = "North Stairs Up"},
    {map = 0x11, x = 2, y = 2, name = "Stairs Up", dest = "B2", object_name = "Northwest Stairs Up"},
    {map = 0x11, x = 5, y = 4, name = "Stairs Up", dest = "B2", object_name = "Central Stairs Up"},
    {map = 0x11, x = 0, y = 9, name = "Stairs Up", dest = "B2", object_name = "Southwest Stairs Up"},
    {map = 0x11, x = 1, y = 6, name = "Stairs Down", dest = "B4", object_name = "West Stairs Down"},
    {map = 0x11, x = 7, y = 7, name = "Stairs Down", dest = "B4", object_name = "Southeast Stairs Down"},
    -- B4 has two returns to B3 and two descents to B5. The main-spine pair
    -- (0,9) / (2,2) was traversed live on 2026-08-06; the other coordinates
    -- come from the same pinned ROM stair graph and were inspected live.
    {map = 0x12, x = 0, y = 9, name = "Stairs Up", dest = "B3", object_name = "Southwest Stairs Up"},
    {map = 0x12, x = 7, y = 7, name = "Stairs Up", dest = "B3", object_name = "Southeast Stairs Up"},
    {map = 0x12, x = 2, y = 2, name = "Stairs Down", dest = "B5", object_name = "Northwest Stairs Down"},
    {map = 0x12, x = 8, y = 1, name = "Stairs Down", dest = "B5", object_name = "Northeast Stairs Down"},
    -- B5 has two returns to B4 and two descents to B6. The main perimeter
    -- pair (9,0) / (0,0) was traversed live on 2026-08-06; the inner pair is
    -- pinned to the ROM stair graph and remains a separately decoded branch.
    {map = 0x13, x = 9, y = 0, name = "Stairs Up", dest = "B4", object_name = "Northeast Stairs Up"},
    {map = 0x13, x = 4, y = 0, name = "Stairs Up", dest = "B4", object_name = "North Stairs Up"},
    {map = 0x13, x = 0, y = 0, name = "Stairs Down", dest = "B6", object_name = "Northwest Stairs Down"},
    {map = 0x13, x = 5, y = 5, name = "Stairs Down", dest = "B6", object_name = "Central Stairs Down"},
    -- B6's main pair (0,6) / (9,6) was traversed live on 2026-08-06. The
    -- upper pair is the ROM-backed false branch: (0,0) returns to B5, while
    -- (9,0) loops back to (0,0) on this same floor.
    {map = 0x14, x = 0, y = 6, name = "Stairs Up", dest = "B5", object_name = "West Stairs Up"},
    {map = 0x14, x = 0, y = 0, name = "Stairs Up", dest = "B5", object_name = "Northwest Stairs Up"},
    {map = 0x14, x = 9, y = 0, name = "Loop Stairs", dest = "B6", object_name = "Northeast Loop Stairs"},
    {map = 0x14, x = 9, y = 6, name = "Stairs Down", dest = "Dragonlord's Lair", object_name = "East Stairs Down"},
    -- Live reverse transition on 2026-08-06 returned from the lair entry to
    -- B6 (9,6). Expose the command-stair tile under the Travel filter.
    {map = 0x06, x = 10, y = 29, name = "Stairs Up", dest = "B6", object_name = "South Stairs Up"},

    -- Swamp Cave (0x15)
    -- ROM up-stair table entry 15 00 1D at file offset 0xF486. Live checks
    -- showed (5,29) is only a bottom-right alcove; the exit is the west-edge
    -- tile reached from row 29.
    {map = 0x15, x = 0, y = 29, name = "Stairs Up", dest = "South Island", object_name = "South Stairs Up"},
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
    {
        map = 0x03,
        x = 0,
        y = 10,
        name = "Exit",
        dest = "World Map",
        interaction_x = 0,
        interaction_y = 10,
        interaction_face_dir = "west",
        interaction_label = "exit",
    },                                                                      -- Hauksness
    {
        map = 0x07,
        x = 19,
        y = 23,
        name = "Exit",
        dest = "World Map",
        interaction_x = 19,
        interaction_y = 23,
        interaction_face_dir = "south",
        interaction_label = "exit",
    },                                                                      -- Kol
    {map = 0x08, x = 0,  y = 15, name = "Exit", dest = "World Map"},      -- Brecconary (confirmed via live PPU dump)
    {
        map = 0x09,
        x = 0,
        y = 14,
        name = "Exit",
        dest = "World Map",
        interaction_x = 1,
        interaction_y = 14,
        interaction_face_dir = "west",
        interaction_label = "exit",
    },                                                                      -- Garinham
    {
        map = 0x0A,
        x = 20,
        y = 29,
        name = "Exit",
        dest = "World Map",
        interaction_x = 20,
        interaction_y = 28,
        interaction_face_dir = "south",
        interaction_label = "exit",
    },                                                                      -- Cantlin, live southeast transition
    {
        map = 0x0A,
        x = 23,
        y = 0,
        name = "Exit",
        dest = "World Map",
        object_name = "North Exit to World Map",
        interaction_x = 23,
        interaction_y = 1,
        interaction_face_dir = "north",
        interaction_label = "exit",
    },                                                                      -- Cantlin, live north transition
    {
        map = 0x0A,
        x = 29,
        y = 0,
        name = "Exit",
        dest = "World Map",
        object_name = "Northeast Exit to World Map",
        interaction_x = 28,
        interaction_y = 0,
        interaction_face_dir = "east",
        interaction_label = "exit",
    },                                                                      -- Cantlin, live northeast transition
    {
        map = 0x0B,
        x = 29,
        y = 13,
        name = "Exit",
        dest = "World Map",
        interaction_x = 29,
        interaction_y = 13,
        interaction_face_dir = "east",
        interaction_label = "exit",
    },                                                                      -- Rimuldar
    {
        map = 0x0B,
        x = 0,
        y = 3,
        name = "Exit",
        dest = "World Map",
        object_name = "Northwest Exit to World Map",
        interaction_x = 0,
        interaction_y = 3,
        interaction_face_dir = "west",
        interaction_label = "exit",
    },                                                                      -- Rimuldar west-edge Magic Key maze exit

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
    {
        map = 0x0C,
        x = 0,
        y = 4,
        name = "Exit",
        dest = "Tantegel Castle",
        object_name = "Stairs to Tantegel Castle",
    },                                                                      -- Sun Shrine
    {
        map = 0x0D,
        x = 4,
        y = 9,
        name = "Exit",
        dest = "World Map",
        interaction_x = 4,
        interaction_y = 9,
        interaction_face_dir = "south",
        interaction_label = "exit",
    },                                                                      -- Rain Shrine
    {
        map = 0x0E,
        x = 0,
        y = 4,
        name = "Exit",
        dest = "World Map",
        interaction_x = 0,
        interaction_y = 4,
        interaction_label = "exit",
    },                                                                      -- Magic Temple

    -- Cave entrances (the "stairs up" at the entrance)
    {
        map = 0x15,
        x = 0,
        y = 0,
        name = "Exit",
        dest = "World Map",
        object_name = "North Exit to World Map",
    },                                                                      -- Swamp Cave
    -- Mountain Cave live entry and exit stand. The World Map entrance lands
    -- at (0,7); using the STAIRS command on that tile returns to (29,57).
    {map = 0x16, x = 0, y = 7, name = "Exit", dest = "World Map"},        -- Mountain Cave
    {map = 0x1C, x = 0, y = 0, name = "Exit", dest = "World Map"},        -- Erdrick's Cave B1
}

-- Interior waypoints that belong under Travel but do not change maps.
-- Cantlin's world-map arrival shelf is separate from its southeast exit.
local LOCAL_TRAVEL_POINTS = {
    {map = 0x0A, x = 16, y = 0, name = "Town Entrance", id = "travel_cantlin_entrance"},
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
    {dx = -42, dy = -41, name = "Garinham"},
    {dx =  61, dy = -33, name = "Kol"},
    {dx =  38, dy = -42, name = "Northern Cave"},
    {dx = -14, dy =  14, name = "Mountain Cave"},
    {dx =  61, dy =   1, name = "Swamp Cave"},
    {dx =  61, dy =   6, name = "Swamp Cave South Entrance"},
    {
        dx = 22,
        dy = 6,
        name = "Rainbow Bridge unlock point",
        id = "overworld_rainbow_bridge",
        aliases = {"Rainbow Bridge", "Rainbow Drop", "Rainbow Drop use point"},
    },
    {dx =  59, dy =  29, name = "Rimuldar"},
    {
        dx = 65,
        dy = 66,
        name = "Magic Temple",
        id = "overworld_southern_cave",
        aliases = {"Southern Cave"},
    },
    {dx =  30, dy =  59, name = "Cantlin"},
    {dx = -18, dy =  46, name = "Hauksness"},
    {dx =  46, dy =  69, name = "Eastern Great Swamp Search Area"},
    {dx =   5, dy =   5, name = "Charlock Castle"},
}

local function wrap_overworld_coord(value)
    value = value % OVERWORLD_SIZE
    if value < 0 then
        value = value + OVERWORLD_SIZE
    end
    return value
end

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function landmark_slug(value)
    local slug = trim(value):lower():gsub("[^%w]+", "_")
    slug = slug:gsub("^_+", ""):gsub("_+$", "")
    return slug
end

local function landmark_compact(value)
    return trim(value):lower():gsub("[^%w]+", "")
end

local function overworld_landmark_id(name)
    return "overworld_" .. landmark_slug(name)
end

local function build_overworld_landmark_object(landmark)
    return {
        x = wrap_overworld_coord(OVERWORLD_TANTEGEL_X + landmark.dx),
        y = wrap_overworld_coord(OVERWORLD_TANTEGEL_Y + landmark.dy),
        name = landmark.name,
        type = M.TYPE_EXIT,
        id = landmark.id or overworld_landmark_id(landmark.name),
    }
end

-- ============================================================
-- Chest Opened Status
-- ============================================================
-- ROM chests use the game's native taken-treasure coordinate array. This is
-- authoritative for the current interior run and survives Lua script reloads.
-- A narrow cache remains only for non-ROM treasure objects such as hidden
-- SEARCH locations, which do not appear in the native chest array.
--
-- Key: non-ROM treasure id string
-- Value: true if the treasure has been collected this session
local opened_fallback_treasures = {}

local function is_native_chest_opened(x, y)
    for i = 0, addr.CHEST_ARRAY_MAX - 1 do
        local chest_x = memory.readbyte(
            addr.CHEST_X_POS_START + i * addr.CHEST_ARRAY_STRIDE)
        local chest_y = memory.readbyte(
            addr.CHEST_Y_POS_START + i * addr.CHEST_ARRAY_STRIDE)
        if (chest_x ~= 0 or chest_y ~= 0) and chest_x == x and chest_y == y then
            return true
        end
    end
    return false
end

-- is_chest_opened(...): ROM chests use native RAM; other treasures use cache.
function M.is_chest_opened(chest_id, x, y, native_chest)
    if native_chest == true and x ~= nil and y ~= nil then
        return is_native_chest_opened(x, y)
    end
    return opened_fallback_treasures[chest_id] == true
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
local visibility_context = darkness.context({terrain_offset = 0x10})
local visibility_signature = darkness.signature(visibility_context)

-- Which map we last built the object list for (to detect map changes)
local current_map_id = nil
local current_terrain_offset = nil
local current_object_state_flags = nil

-- Frame counter for periodic NPC position updates
local npc_refresh_counter = 0
local NPC_REFRESH_INTERVAL = 20  -- Re-read NPC positions every 20 frames (~0.33s)
local MAP_ENTRY_NPC_REFRESH_CHECKS = 90
local MAP_ENTRY_NPC_REFRESH_INTERVAL = 8
local PRINCESS_GWAELIN_ESCORT_FLAG = 0x01

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

local function get_combat_flags()
    if addr.COMBAT_FLAGS == nil then
        return 0
    end
    return memory.readbyte(addr.COMBAT_FLAGS)
end

-- COMBAT_FLAGS also contains transient battle-status bits. Only the Gwaelin
-- escort bit affects the object list, so battle state must not trigger a
-- same-map full refresh and reset the selected object.
local function get_object_state_flags()
    return AND(get_combat_flags(), PRINCESS_GWAELIN_ESCORT_FLAG)
end

local function princess_gwaelin_is_escorted()
    return get_object_state_flags() ~= 0
end

local function is_overworld_context()
    return get_terrain_offset() == 0x00
end

local MAPS_WITHOUT_NPCS = {
    [0x02] = true, -- Charlock Castle uses town terrain but has no NPC table.
    [0x03] = true, -- Ruins of Hauksness uses town terrain but has no NPCs.
}

local function current_context_allows_npcs(map_id)
    if map_id ~= nil and MAPS_WITHOUT_NPCS[map_id] then
        return false
    end
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
    if map_id == nil or not current_context_allows_npcs(map_id) then
        return
    end
    remember_accepted_npc_signature(map_id, read_npc_signature())
end

-- record_fallback_treasure_collection_at(px, py): Record session state only
-- for a non-ROM treasure on the player's exact tile. ROM chests never pass
-- through this inference path; their native RAM coordinates are authoritative.
function M.record_fallback_treasure_collection_at(px, py)
    for _, obj in ipairs(object_list) do
        if obj.type == M.TYPE_CHEST
            and obj.native_chest ~= true
            and obj.x == px
            and obj.y == py then
            opened_fallback_treasures[obj.id] = true
            return obj
        end
    end
    return nil
end

-- ============================================================
-- NPC Parsing
-- ============================================================

local NONBLOCKING_NPC_CELLS = {
    -- 2026-05-23 Tantegel Castle Sun Shrine route: Guard 3 can appear at
    -- (26,15) in the object list and block the only safe post-hazard route,
    -- but probe_edge_verify:26,14,DOWN,5 moved into that cell 3/5 despite
    -- npc_blocked=true. Treat this specific occupancy as non-blocking.
    [0x04] = {
        ["26,15"] = true,
    },
    -- 2026-05-25 Garin's Grave entrance investigation: Old Man 3 appears at
    -- (14,1) on the hidden dark-wall route, but live movement from (13,1)
    -- crossed into his cell and TALK then reported "There is no one there."
    -- Keep him browsable, but do not let pathfinding treat him as a wall.
    [0x09] = {
        ["14,1"] = true,
    },
}

local function npc_blocks_movement(map_id, x, y)
    local by_map = NONBLOCKING_NPC_CELLS[map_id]
    if by_map and by_map[x .. "," .. y] then
        return false
    end
    return true
end

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
    if not current_context_allows_npcs(map_id) then
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
            blocks_movement = npc_blocks_movement(map_id, entry.x, entry.y),
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
        local rom_y = rom.readbyte(base + 2)
        local chest_y = rom_y  -- player coordinate = ROM value directly

        if chest_map == map_id then
            chests[#chests + 1] = {
                x = chest_x,
                y = chest_y,
                name = "Chest",
                type = M.TYPE_CHEST,
                id = "chest_" .. i,
                native_chest = true,
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
-- Locked doors are not reliably distinguishable from ordinary walls or stairs
-- by tile type. Both scan constants are currently nil, so verified doors come
-- from EXTRA_DOORS. Keep this scanner fail-closed unless a tile rule is proven
-- for an entire tileset rather than inferred from one coordinate.
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
                name = stair.object_name or (stair.name .. " to " .. stair.dest),
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
                name = exit.object_name or ("Exit to " .. exit.dest),
                type = M.TYPE_EXIT,
                id = "exit_" .. exit.x .. "_" .. exit.y,
                interaction_x = exit.interaction_x,
                interaction_y = exit.interaction_y,
                interaction_face_dir = exit.interaction_face_dir,
                interaction_label = exit.interaction_label,
            }
        end
    end
    return result
end

local function get_local_travel_points(map_id)
    local result = {}
    for _, point in ipairs(LOCAL_TRAVEL_POINTS) do
        if point.map == map_id then
            result[#result + 1] = {
                x = point.x,
                y = point.y,
                name = point.name,
                type = M.TYPE_EXIT,
                id = point.id,
            }
        end
    end
    return result
end

local function get_overworld_landmarks()
    local result = {}
    for _, landmark in ipairs(OVERWORLD_LANDMARKS) do
        result[#result + 1] = build_overworld_landmark_object(landmark)
    end
    for _, waypoint in ipairs(overworld_routes.get_active_waypoint_objects()) do
        result[#result + 1] = waypoint
    end
    return result
end

local function is_overworld_travel_object(obj)
    if not obj or obj.type ~= M.TYPE_EXIT then
        return false
    end
    local id = tostring(obj.id or "")
    return id:match("^overworld_") ~= nil or id:match("^route_") ~= nil
end

function M.find_overworld_landmark(query)
    local needle_slug = landmark_slug(query)
    local needle_compact = landmark_compact(query)
    if needle_slug == "" then
        return nil, "missing landmark name"
    end

    local exact_match = nil
    local prefix_matches = {}
    for _, landmark in ipairs(OVERWORLD_LANDMARKS) do
        local obj = build_overworld_landmark_object(landmark)
        local name_slug = landmark_slug(obj.name)
        local id_slug = landmark_slug(obj.id)
        local name_compact = landmark_compact(obj.name)
        local id_compact = landmark_compact(obj.id)
        local alias_exact = false
        local alias_prefix = false
        for _, alias in ipairs(landmark.aliases or {}) do
            local alias_slug = landmark_slug(alias)
            local alias_compact = landmark_compact(alias)
            if needle_slug == alias_slug
                or needle_compact == alias_compact then
                alias_exact = true
            end
            if alias_slug:sub(1, #needle_slug) == needle_slug
                or alias_compact:sub(1, #needle_compact) == needle_compact then
                alias_prefix = true
            end
        end
        if needle_slug == name_slug
            or needle_slug == id_slug
            or needle_compact == name_compact
            or needle_compact == id_compact
            or alias_exact then
            exact_match = obj
            break
        end
        if name_slug:sub(1, #needle_slug) == needle_slug
            or name_compact:sub(1, #needle_compact) == needle_compact
            or alias_prefix then
            prefix_matches[#prefix_matches + 1] = obj
        end
    end

    if exact_match then
        return exact_match, nil
    end
    if #prefix_matches == 1 then
        return prefix_matches[1], nil
    end
    if #prefix_matches > 1 then
        return nil, "ambiguous overworld landmark: " .. trim(query)
    end
    return nil, "unknown overworld landmark: " .. trim(query)
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
    -- Map 0x02: Charlock Castle side rooms containing the two visible decoy
    -- stairs. Both doors were opened live from their public north stands;
    -- retain room-side stands so navigation can also route back out.
    [0x02] = {
        {
            x=4,
            y=8,
            name="West Side Room Door",
            type=M.TYPE_DOOR,
            id="door_4_8",
            interaction_x=4,
            interaction_y=7,
            interaction_face_dir="south",
            interaction_points={
                {x=4, y=7, face_dir="south"},
                {x=4, y=9, face_dir="north"},
            },
        },
        {
            x=15,
            y=8,
            name="East Side Room Door",
            type=M.TYPE_DOOR,
            id="door_15_8",
            interaction_x=15,
            interaction_y=7,
            interaction_face_dir="south",
            interaction_points={
                {x=15, y=7, face_dir="south"},
                {x=15, y=9, face_dir="north"},
            },
        },
    },
    -- Map 0x04: Tantegel Castle.
    -- Keep only confirmed locked-key doors here; gate access at the south
    -- entrance is modeled via exit_11_29 in EXITS.
    [0x04] = {
        {x=4, y=13, name="Treasure Room Door", type=M.TYPE_DOOR, id="door_4_13"},
        {x=18, y=6, name="Magic Key Area Door", type=M.TYPE_DOOR, id="door_18_6"},
    },
    -- Map 0x05: Tantegel Castle Throne Room, south-wall arch at (4,7).
    -- The ROM tile is type-15; is_walkable() in map_reader.lua checks the
    -- opened-door RAM directly for this cell.
    [0x05] = {{x=4, y=7, name="Door", type=M.TYPE_DOOR, id="door_4_7"}},
    -- Map 0x06: Dragonlord's Lair treasure room. OPEN from the natural east
    -- stand `(18,12)` consumed one key and wrote door RAM slot `(17,12)`.
    -- The room-side stand is also walkable, so preserve the return approach.
    [0x06] = {
        {
            x=17,
            y=12,
            name="Treasure Room Door",
            type=M.TYPE_DOOR,
            id="door_17_12",
            interaction_x=18,
            interaction_y=12,
            interaction_face_dir="west",
            interaction_points={
                {x=18, y=12, face_dir="west"},
                {x=16, y=12, face_dir="east"},
            },
        },
    },
    -- Map 0x07: Kol locked doors. Live verifier proof opened them from the
    -- public east stands and recorded their opened-door RAM slots.
    [0x07] = {
        {
            x=7,
            y=12,
            name="Western Building Door",
            type=M.TYPE_DOOR,
            id="door_7_12",
            interaction_x=8,
            interaction_y=12,
            interaction_face_dir="west",
        },
        {
            x=1,
            y=14,
            name="West Side Door",
            type=M.TYPE_DOOR,
            id="door_1_14",
            interaction_x=1,
            interaction_y=15,
            interaction_face_dir="north",
        },
    },
    -- Map 0x08: Brecconary has two locked doors that are not encoded as a
    -- distinct town door tile: the northeast building and the west room in the
    -- inn. External guide/map labels disagree on nearby service names, so keep
    -- the navigation labels positional. The inn door was live-confirmed by
    -- OPEN from (6,23) facing west, which wrote opened-door RAM slot (5,23).
    [0x08] = {
        {x=21, y=6, name="Northeast Door", type=M.TYPE_DOOR, id="door_21_6"},
        {x=5, y=23, name="Inn West Room Door", type=M.TYPE_DOOR, id="door_5_23"},
    },
    -- Map 0x09: Garinham. The old `(19,16)` east guess was disproved live by
    -- OPEN reporting "There is no door here." The grave-route follow-up found
    -- the grey-building door by opening from (17,9) facing south; door RAM
    -- recorded the opened cell as (17,10). A later public-side verifier routed
    -- to (17,11) facing north and readied the same expected door cell, so keep
    -- both stands and let route planning choose the reachable side. The inner
    -- locked-building door opens from the south stand `(4,7)` facing north,
    -- records door cell `(4,6)`, and leads into the one-cell guard pocket at
    -- `(4,5)`.
    [0x09] = {
        {
            x=17,
            y=10,
            name="Grave Route Door",
            type=M.TYPE_DOOR,
            id="door_17_10",
            interaction_x=17,
            interaction_y=9,
            interaction_face_dir="south",
            interaction_points={
                {x=17, y=9, face_dir="south"},
                {x=17, y=11, face_dir="north"},
            },
        },
        {
            x=4,
            y=6,
            name="Locked Building Door",
            type=M.TYPE_DOOR,
            id="door_4_6",
            interaction_x=4,
            interaction_y=7,
            interaction_face_dir="north",
        },
    },
    -- Map 0x0A: Cantlin. Live OPEN proof confirmed the eastern building
    -- door from `(25,9)` facing east, the central pair from `(15,24)`
    -- and `(14,24)` facing south, and the western shop north door from
    -- `(4,20)` facing south plus the western shop east door from `(7,25)`
    -- facing east.
    [0x0A] = {
        {
            x=26,
            y=9,
            name="Eastern Building Door",
            type=M.TYPE_DOOR,
            id="door_26_9",
            interaction_x=25,
            interaction_y=9,
            interaction_face_dir="east",
        },
        {
            x=15,
            y=25,
            name="Central Right Door",
            type=M.TYPE_DOOR,
            id="door_15_25",
            interaction_x=15,
            interaction_y=24,
            interaction_face_dir="south",
        },
        {
            x=14,
            y=25,
            name="Central Left Door",
            type=M.TYPE_DOOR,
            id="door_14_25",
            interaction_x=14,
            interaction_y=24,
            interaction_face_dir="south",
        },
        {
            x=4,
            y=21,
            name="Western Shop North Door",
            type=M.TYPE_DOOR,
            id="door_4_21",
            interaction_x=4,
            interaction_y=20,
            interaction_face_dir="south",
        },
        {
            x=8,
            y=25,
            name="Western Shop East Door",
            type=M.TYPE_DOOR,
            id="door_8_25",
            interaction_x=7,
            interaction_y=25,
            interaction_face_dir="east",
        },
    },
    -- Map 0x18: Garin's Grave B1 southeast locked door toward B2. Live OPEN
    -- from `(17,18)` facing north wrote slot `1=(17,17)` into door RAM, and a
    -- direct edge probe immediately moved into `(17,17)`. Later live routing
    -- reached the same door from the north-side maze component, so expose both
    -- proven stands and let route planning choose the reachable side.
    [0x18] = {
        {
            x=17,
            y=17,
            name="B2 Door",
            type=M.TYPE_DOOR,
            id="door_17_17",
            interaction_x=17,
            interaction_y=18,
            interaction_face_dir="north",
            interaction_points={
                {x=17, y=18, face_dir="north"},
                {x=17, y=16, face_dir="south"},
            },
        },
    },
    -- Map 0x0B: Rimuldar inn / Wings chest doors. Gamer Corner lists the inn
    -- treasure as behind an outer and inner door; live opened-door RAM confirmed
    -- (21,21) from the south stand and (22,23) from both approach/chest sides.
    [0x0B] = {
        {
            x=21, y=21, name="Rimuldar Inn Outer Door", type=M.TYPE_DOOR, id="door_21_21",
            interaction_x=21, interaction_y=20, interaction_face_dir="south",
            interaction_points={
                {x=21, y=20, face_dir="south"},
                {x=21, y=22, face_dir="north"},
            },
        },
        {
            x=22, y=23, name="Wings Chest Door", type=M.TYPE_DOOR, id="door_22_23",
            interaction_x=21, interaction_y=23, interaction_face_dir="east",
            interaction_points={
                {x=21, y=23, face_dir="east"},
                {x=23, y=23, face_dir="west"},
            },
        },
    },
    -- Map 0x15: Swamp Cave / Quagmire Cave. Live OPEN probes from both (5,21)
    -- and (5,19) reported the no-key door message, triangulating the door cell
    -- at (5,20). Route to the south stand tile for normal key-side access.
    [0x15] = {
        {
            x=5, y=20, name="Gwaelin Door", type=M.TYPE_DOOR, id="door_5_20",
            interaction_x=5, interaction_y=21, interaction_face_dir="north",
        },
    },
}

local EXTRA_TREASURES = {
    -- Kol: guides place the Fairy Flute four steps south of the bath. Mike's
    -- map image has one bath/water tile at (9,2), and live inspection proved
    -- the four-south search tile (9,6) is walkable.
    [0x07] = {
        {x=9, y=6, name="Disturbed Earth Near Bath", type=M.TYPE_CHEST, id="chest_kol_fairy_flute"},
    },
}

-- Static local-map landmarks that belong under Travel but are not exits,
-- stairs, NPCs, or treasure objects.
local EXTRA_LANDMARKS = {
    -- Hauksness fixed encounter. Route to the safe west stand and leave the
    -- final east step under player control. The buried reward intentionally
    -- remains absent from player-facing object data.
    [0x03] = {
        {
            x = 18,
            y = 12,
            name = "Axe Knight Approach",
            type = M.TYPE_EXIT,
            id = "landmark_hauksness_axe_knight",
            interaction_x = 17,
            interaction_y = 12,
            interaction_face_dir = "east",
            interaction_label = "safe approach",
        },
    },
}

local SERVICE_INTERACTION_OVERRIDES = {
    -- Tantegel Castle MP-restoring Sage. The NPC occupies (20,26), but the
    -- live TALK trigger works from the public west-side stand at (18,26)
    -- while facing east across the counter/seam.
    [0x04] = {
        ["20,26"] = {x = 18, y = 26, face_dir = "east", label = "counter", name = "Sage"},
    },

    -- Kol services. Merchant 2 occupies (19,4); live TALK from the public stand
    -- at (19,2) facing south opened the 20 GOLD inn prompt. Merchant 3 occupies
    -- (22,12); selected teleport landed at the public stand (20,12), faced east,
    -- and TALK opened the live weapon/armor shop menu. Merchant 4 occupies
    -- (14,21); selected teleport landed at (12,21), faced east, and TALK opened
    -- the live tool shop menu.
    [0x07] = {
        ["19,4"] = {x = 19, y = 2, face_dir = "south", label = "counter", name = "Inn"},
        ["22,12"] = {x = 20, y = 12, face_dir = "east", label = "counter", name = "Weapons Merchant"},
        ["14,21"] = {x = 12, y = 21, face_dir = "east", label = "counter", name = "Tool Merchant"},
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
        -- The Fairy Water seller is a Woman sprite who can pace behind the NE
        -- counter, but live TALK proof only opens the prompt when she is held
        -- on the center trigger row. Route to the fixed public stand and pin
        -- the target row briefly after arrival.
        ["24,3"] = {x = 22, y = 4, face_dir = "east", label = "counter", name = "Fairy Water Merchant", target_hold_x = 24, target_hold_y = 4},
        ["24,4"] = {x = 22, y = 4, face_dir = "east", label = "counter", name = "Fairy Water Merchant", target_hold_x = 24, target_hold_y = 4},
        ["24,5"] = {x = 22, y = 4, face_dir = "east", label = "counter", name = "Fairy Water Merchant", target_hold_x = 24, target_hold_y = 4},
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

    -- Cantlin services. Person 2 occupies (2,7); live TALK proof from the
    -- public counter stand at (4,7) facing west opened the Herb/Torch shop.
    -- Merchant 4 occupies (8,3); live TALK proof from the
    -- public counter stand at (8,5) facing north opened the 100 GOLD inn
    -- prompt. Merchant 6 occupies (7,12); live TALK proof from (5,12) facing
    -- east opened the tool-shop prompt. Woman 2 occupies (22,13); TALK from
    -- (20,13) facing east opened the 38 GOLD Fairy Water prompt. Merchant 7
    -- occupies (27,26); TALK from public stand (25,26) facing east opened the
    -- weapons/armor prompt. Guard 4 occupies (24,12); the reachable public
    -- stand is the hidden type-15 cell (26,12), where west-facing TALK opened
    -- the premium Flame Sword/Silver Shield shop across counter cell (25,12).
    -- Old Man 2 occupies (27,6); live TALK proof opened the Magic Key shop
    -- from the public stand at (27,8), facing north across counter cell (27,7).
    [0x0A] = {
        ["2,7"] = {x = 4, y = 7, face_dir = "west", label = "counter", name = "Tool Merchant 2"},
        ["8,3"] = {x = 8, y = 5, face_dir = "north", label = "counter", name = "Inn"},
        ["7,12"] = {x = 5, y = 12, face_dir = "east", label = "counter", name = "Tool Merchant"},
        ["22,13"] = {x = 20, y = 13, face_dir = "east", label = "counter", name = "Fairy Water Merchant"},
        ["24,12"] = {x = 26, y = 12, face_dir = "west", label = "counter", name = "Premium Weapons Merchant"},
        ["27,6"] = {x = 27, y = 8, face_dir = "north", label = "counter", name = "Magic Key Merchant"},
        ["27,26"] = {x = 25, y = 26, face_dir = "east", label = "counter", name = "Weapons Merchant"},
    },

    -- Rimuldar services. Old Man 1 is the Magic Key seller at (4,7), behind
    -- the raw-0xF counter at (4,6). The player uses the public stand at (4,5),
    -- facing south. Merchant 1 at (2,4) is only the greeter, so keep him
    -- browsable but out of Services. Merchant 2 occupies (23,7).
    --
    -- Normal movement from the east entrance reaches the public weapon-shop
    -- counter stand at (23,9) through the lower west corridor. On 2026-07-17,
    -- north-facing TALK there opened the weapons/armor prompt. The older
    -- (24,7) prompt proof required teleporting into the enclosed merchant room,
    -- so do not expose it as a route fallback. Merchant 3 occupies (16,18);
    -- early TALK proof opened the 55 GOLD inn prompt from (16,17), but the
    -- public route to that stand later collapsed. A follow-up live prompt
    -- opened from the reachable east-side stand at (18,18), facing west.
    [0x0B] = {
        ["4,7"] = {x = 4, y = 5, face_dir = "south", label = "counter", name = "Magic Key Merchant"},
        ["23,7"] = {x = 23, y = 9, face_dir = "north", label = "counter", name = "Weapons Merchant"},
        ["16,18"] = {
            x = 18,
            y = 18,
            face_dir = "west",
            label = "counter",
            name = "Inn",
            interaction_points = {
                {x = 18, y = 18, face_dir = "west", label = "counter"},
                {x = 16, y = 17, face_dir = "south", label = "counter"},
            },
        },
    },
}

local SERVICE_ROLE_OVERRIDES = {
    -- Dragonlord's Lair uses the town/castle NPC table for the final encounter.
    -- The boss occupies (16,24) and appears as a generic Old Man sprite in RAM;
    -- expose his actual role without treating him as a normal service NPC.
    [0x06] = {
        cells = {
            ["16,24"] = {name = "Dragonlord", infer_counter = false, service = false},
        },
    },
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
    -- Tantegel Throne Room King. Players visit him to save, so include him in
    -- Services while keeping normal adjacent-NPC routing. Returned Gwaelin is
    -- a normal Woman sprite at the throne-room cell, so label her without
    -- adding service behavior.
    [0x05] = {
        names = {
            ["King"] = {name = "King", infer_counter = false},
        },
        cells = {
            ["6,3"] = {name = "Princess Gwaelin", infer_counter = false, service = false},
        },
    },
    -- Kol public services; stand/facing data is modeled in
    -- SERVICE_INTERACTION_OVERRIDES above.
    [0x07] = {
        names = {
            ["Merchant 2"] = {name = "Inn", infer_counter = true},
            ["Merchant 3"] = {name = "Weapons Merchant", infer_counter = true},
            ["Merchant 4"] = {name = "Tool Merchant", infer_counter = true},
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
            ["24,3"] = {name = "Fairy Water Merchant", infer_counter = false},
            ["24,4"] = {name = "Fairy Water Merchant", infer_counter = false},
            ["24,5"] = {name = "Fairy Water Merchant", infer_counter = false},
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
    -- Cantlin service proof is still partial. Merchant 2 is the live-confirmed
    -- roaming weapons/armor shop and should keep adjacent-NPC routing.
    -- Person 2 is the live-confirmed Herb/Torch tool shop. Merchant 4 is the
    -- live-confirmed inn keeper, Merchant 6 is the other tool shop,
    -- Woman 2 is the live-confirmed Fairy Water seller, and Merchant 7 is the
    -- second live-confirmed weapons/armor shop. Old Man 2 is the confirmed
    -- stationary Magic Key seller. Their fixed stands are modeled in
    -- SERVICE_INTERACTION_OVERRIDES above.
    -- Merchant 5 at (2,12) only gives the
    -- radish dialogue from the public counter side, so keep him out of Services.
    [0x0A] = {
        -- Cantlin can deactivate an earlier NPC RAM slot, which renumbers
        -- duplicate Merchant display names. Prefer stable RAM-slot IDs for
        -- confirmed roles; retain name mappings for older fixtures/fallbacks.
        ids = {
            ["npc_4"] = {name = "Roaming Weapons Merchant", infer_counter = false},
            ["npc_10"] = {name = "Inn", infer_counter = true},
            ["npc_11"] = {name = "Magic Key Merchant", infer_counter = true},
            ["npc_12"] = {name = "Tool Merchant 2", infer_counter = true},
            ["npc_13"] = {
                name = "Radish Merchant",
                infer_counter = false,
                service = false,
                interaction_x = 4,
                interaction_y = 12,
                interaction_face_dir = "west",
                interaction_label = "counter",
            },
            ["npc_14"] = {name = "Tool Merchant", infer_counter = true},
            ["npc_15"] = {name = "Premium Weapons Merchant", infer_counter = true},
            ["npc_16"] = {name = "Fairy Water Merchant", infer_counter = true},
            ["npc_19"] = {name = "Weapons Merchant", infer_counter = true},
        },
        names = {
            ["Merchant 2"] = {name = "Roaming Weapons Merchant", infer_counter = false},
            ["Merchant 4"] = {name = "Inn", infer_counter = true},
            ["Merchant 6"] = {name = "Tool Merchant", infer_counter = true},
            ["Merchant 7"] = {name = "Weapons Merchant", infer_counter = true},
            ["Woman 2"] = {name = "Fairy Water Merchant", infer_counter = true},
        },
        cells = {
            ["2,7"] = {
                name = "Tool Merchant 2",
                infer_counter = true,
                service = true,
            },
            ["27,6"] = {
                name = "Magic Key Merchant",
                infer_counter = true,
                service = true,
            },
            ["24,12"] = {
                name = "Premium Weapons Merchant",
                infer_counter = true,
                service = true,
            },
            ["2,12"] = {
                name = "Radish Merchant",
                infer_counter = false,
                service = false,
                interaction_x = 4,
                interaction_y = 12,
                interaction_face_dir = "west",
                interaction_label = "counter",
            },
        },
    },
    -- Rimuldar Old Man 1 is the live-confirmed Magic Key seller, Merchant 2 is
    -- the weapon/armor shop, and Merchant 3 is the inn keeper. Interaction
    -- stands are modeled in SERVICE_INTERACTION_OVERRIDES above.
    [0x0B] = {
        names = {
            ["Old Man 1"] = {name = "Magic Key Merchant", infer_counter = false},
            ["Merchant 2"] = {name = "Weapons Merchant", infer_counter = true},
            ["Merchant 3"] = {name = "Inn", infer_counter = true},
        },
        cells = {
            ["4,7"] = {name = "Magic Key Merchant", infer_counter = false},
        },
    },
}

local SERVICE_EXCLUSIONS = {
    -- Kol Merchant 1 gives the southern-island/Rimuldar hint, not a shop
    -- prompt. Keep him browsable under NPCs without sending Services to him.
    [0x07] = {
        ["Merchant 1"] = true,
    },

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

    -- Garinham Merchant 1 gives the darkness/map hint, not a shop prompt.
    -- Keep him browseable under NPCs without sending Services to him.
    [0x09] = {
        ["Merchant 1"] = true,
    },

    -- Cantlin Merchants 1 and 3 only give Wynn/Hauksness treasure hints.
    -- Keep them browsable under NPCs without advertising them as services.
    [0x0A] = {
        ["Merchant 1"] = true,
        ["Merchant 3"] = true,
    },

    -- Rimuldar Merchant 1 only gives the short "Welcome!" greeting. The live
    -- Magic Key seller is Old Man 1 at (4,7), modeled as a service above.
    [0x0B] = {
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
    local entry = by_map.ids and by_map.ids[obj.id]
    if not entry then
        entry = by_map.names and by_map.names[obj.name]
    end
    if not entry and by_map.cells then
        entry = by_map.cells[obj.x .. "," .. obj.y]
    end
    if not entry then
        return nil
    end
    obj.service = entry.service ~= false
    if entry.name then
        obj.name = entry.name
    end
    if entry.interaction_x ~= nil and entry.interaction_y ~= nil then
        obj.interaction_x = entry.interaction_x
        obj.interaction_y = entry.interaction_y
        obj.interaction_face_dir = entry.interaction_face_dir
        obj.interaction_label = entry.interaction_label
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
        obj.interaction_points = override.interaction_points
        obj.target_hold_x = override.target_hold_x
        obj.target_hold_y = override.target_hold_y
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
    append_objects(objects, get_local_travel_points(map_id))
    append_objects(objects, parse_doors(map_id))

    local extra = EXTRA_DOORS[map_id]
    if extra then
        append_objects(objects, extra)
    end
    extra = EXTRA_TREASURES[map_id]
    if extra then
        append_objects(objects, extra)
    end
    extra = EXTRA_LANDMARKS[map_id]
    if extra then
        append_objects(objects, extra)
    end

    static_object_cache[map_id] = objects
    return objects
end

local function get_special_npcs(map_id)
    if map_id ~= 0x15 or princess_gwaelin_is_escorted() then
        return {}
    end

    return {
        {
            x = 5,
            y = 18,
            name = "Princess Gwaelin",
            type = M.TYPE_NPC,
            id = "npc_princess_gwaelin",
            service = false,
            blocks_movement = true,
            interaction_x = 5,
            interaction_y = 19,
            interaction_face_dir = "north",
            interaction_label = "talk",
        },
    }
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
    append_objects(objects, get_special_npcs(map_id))
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

local function matches_visibility(obj)
    return darkness.is_visible(visibility_context, obj and obj.x, obj and obj.y)
end

-- apply_filter(objects, filter): Return a new list containing only objects
-- matching the current type and pathability filters.
local function apply_filter(objects, filter)
    if filter == M.FILTER_ALL
       and current_pathability_filter == M.PATHABILITY_ALL
       and visibility_context.limited ~= true then
        return objects
    end

    local result = {}
    for _, obj in ipairs(objects) do
        if matches_visibility(obj)
           and matches_type_filter(obj, filter)
           and matches_pathability_filter(obj) then
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

-- set_visibility_context(state): Update the player-facing dungeon visibility
-- window. This only rebuilds the filtered browser view; the complete decoded
-- object list remains available to explicit developer diagnostics.
function M.set_visibility_context(state)
    local next_context = darkness.context(state)
    local next_signature = darkness.signature(next_context)
    visibility_context = next_context
    if next_signature == visibility_signature then
        return false
    end
    visibility_signature = next_signature
    pathability_status_by_id = {}
    rebuild_filtered_list()
    return true
end

function M.get_visibility_context()
    local copy = {}
    for key, value in pairs(visibility_context) do
        copy[key] = value
    end
    return copy
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
    current_object_state_flags = get_object_state_flags()
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
    local allows_npcs = current_context_allows_npcs(map_id)
    local stale_npc_signature = nil
    local npc_refresh_checks = 0
    if allows_npcs then
        local current_signature = read_npc_signature()
        local previous_map_id = opts.previous_map_id
        if previous_map_id == nil and current_map_id ~= map_id then
            previous_map_id = current_map_id
        end
        local previous_signature = nil
        -- Only quarantine byte-identical NPC RAM from a different previous map.
        -- Same-map terrain flips and script reloads can legitimately see the
        -- already-known NPC signature and should settle after the normal
        -- one-frame deferred refresh.
        if previous_map_id ~= nil and previous_map_id ~= map_id then
            previous_signature = accepted_npc_signature_by_map[previous_map_id]
        elseif previous_map_id == nil and accepted_npc_signature_by_map[map_id] ~= current_signature then
            previous_signature = last_accepted_npc_signature
        end
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
    local object_state_flags = get_object_state_flags()
    return refresh_pending
        or map_entry_npc_refresh_checks > 0
        or map_id ~= current_map_id
        or terrain_offset ~= current_terrain_offset
        or object_state_flags ~= current_object_state_flags
end

-- check_refresh(map_id): Called every frame from the main loop.
-- Handles map-change detection and periodic NPC position refresh.
function M.check_refresh(map_id)
    local terrain_offset = get_terrain_offset()
    local object_state_flags = get_object_state_flags()

    -- Full rebuild on map, terrain, or object-relevant quest flag changes.
    if map_id ~= current_map_id
       or terrain_offset ~= current_terrain_offset
       or object_state_flags ~= current_object_state_flags then
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
-- opts.filtered=true to return the current filtered view instead. Pass
-- opts.visible=true to keep all object types but apply dungeon visibility.
function M.get_objects(opts)
    opts = opts or {}
    local source = opts.filtered and filtered_list or object_list
    local result = {}
    for _, obj in ipairs(source) do
        if opts.filtered or opts.visible ~= true or matches_visibility(obj) then
            result[#result + 1] = obj
        end
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
        if obj.type == M.TYPE_NPC and obj.blocks_movement ~= false then
            local slot = nil
            if obj.id then
                slot = tonumber(tostring(obj.id):match("^npc_(%d+)$"))
            end
            result[#result + 1] = {
                x = obj.x,
                y = obj.y,
                id = obj.id,
                name = obj.name,
                slot = slot,
                movement = obj.movement,
                service = obj.service,
                type = obj.type,
            }
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
        if is_overworld_context() and is_overworld_travel_object(obj) then
            return {
                x = obj.x,
                y = obj.y,
                target_x = obj.x,
                target_y = obj.y,
                reason = "overworld_travel",
            }, nil
        end
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
local function apply_description_interaction_override(obj, opts)
    if not obj or not opts then
        return obj
    end
    if opts.interaction_x == nil or opts.interaction_y == nil then
        return obj
    end

    local next_obj = {}
    for k, v in pairs(obj) do
        next_obj[k] = v
    end
    next_obj.interaction_x = opts.interaction_x
    next_obj.interaction_y = opts.interaction_y
    if opts.interaction_face_dir ~= nil then
        next_obj.interaction_face_dir = opts.interaction_face_dir
    end
    if opts.interaction_label ~= nil then
        next_obj.interaction_label = opts.interaction_label
    end
    return next_obj
end

local function npc_movement_status(obj)
    local movement = tonumber(obj and obj.movement)
    if movement == nil then
        return "movement unknown"
    end
    if movement == 0 then
        return "stationary"
    end
    return "roaming"
end

function M.describe_object(obj, opts)
    if not obj then return "No objects" end
    opts = opts or {}
    obj = apply_description_interaction_override(obj, opts)

    local _, px, py = nav.get_position()
    local direction = M.get_direction_string(px, py, obj.x, obj.y)
    local name = obj.name
    if obj.type == M.TYPE_CHEST
        and M.is_chest_opened(obj.id, obj.x, obj.y, obj.native_chest) then
        name = name .. " (opened)"
    end
    if obj.type == M.TYPE_DOOR and is_door_opened(obj.x, obj.y) then
        name = name .. " (opened)"
    end

    local visited = M.is_visited(obj)
    if obj.type == M.TYPE_NPC and opts.include_npc_movement_status == true then
        local annotations = {npc_movement_status(obj)}
        if visited then
            annotations[#annotations + 1] = "visited"
        end
        name = name .. " (" .. table.concat(annotations, ", ") .. ")"
    elseif visited then
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
    obj = apply_description_interaction_override(obj, opts)
    local desc = M.describe_object(obj, {
        include_npc_movement_status = opts.include_npc_movement_status ~= false,
    })
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
