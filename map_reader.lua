-- map_reader.lua
-- ROM map data reading for Dragon Warrior.
--
-- Reads map metadata and tile data from the ROM to build 2D tile grids.
-- Dragon Warrior stores maps as RLE-compressed tile data in the ROM.
-- Each map has a metadata entry (5 bytes) with a data pointer, width,
-- height, and border tile. The width/height bytes are stored as the
-- maximum in-map coordinate, so the actual dimensions are +1. The tile
-- data uses nibble-based RLE:
-- high nibble = tile type (0-15), low nibble = repeat count minus 1.
--
-- The overworld uses a more complex system with row-offset
-- pointers, so we skip A* pathfinding for it and only build tile grids
-- for interior maps (towns, dungeons, castles).
--
-- Tile walkability is determined per-tileset. The game uses different
-- tile graphics for overworld, towns, and dungeons, but the tile TYPE
-- numbers (0-15) have consistent meanings within each category.

local addr = require "addresses"
local maps = require "maps"

local M = {}

-- ============================================================
-- Constants
-- ============================================================

-- Number of maps in the game (0x00 through 0x1D = 30 metadata entries).
local NUM_MAPS = 30

-- ROM address where map metadata table begins.
-- Each entry is 5 bytes: pointer_lo, pointer_hi, width_max, height_max, border_tile
local META_START = addr.ROM_MAP_META_START  -- 0x002A

-- The iNES header is 16 bytes. rom.readbyte() in FCEUX reads from the
-- file including this header, so ROM address 0x0000 = file offset 0x0000.
-- But the PRG-ROM data starts at file offset 0x0010.
-- The metadata pointers appear to be file offsets already (they point to
-- addresses like 0x00C1 which is where Charlock Castle data starts).
-- We'll use rom.readbyte() directly with these addresses.

-- ============================================================
-- Map Metadata Cache
-- ============================================================
-- We cache metadata for all maps on first access since it never changes.
-- Each entry: {data_ptr, width, height, border_tile}
local meta_cache = {}

-- load_metadata(): Read the 5-byte metadata entry for every map from ROM.
-- Called once on first use, then cached.
local function load_metadata()
    for map_id = 0, NUM_MAPS - 1 do
        local base = META_START + (map_id * addr.ROM_MAP_META_SIZE)
        local ptr_lo = rom.readbyte(base)
        local ptr_hi = rom.readbyte(base + 1)
        -- DW1 stores the maximum interior coordinate here, not a tile count.
        -- Example: the throne room is empirically 9x9, while the ROM byte is 8.
        local width = rom.readbyte(base + 2) + 1
        local height = rom.readbyte(base + 3) + 1
        local border = rom.readbyte(base + 4)

        -- Combine the 2-byte pointer (little-endian).
        -- The ROM stores map data pointers as NES CPU addresses (e.g. $8402).
        -- rom.readbyte() uses file offsets including the 16-byte iNES header.
        -- PRG-ROM is mapped at CPU $8000-$FFFF, starting at file offset $0010.
        -- Convert: file_offset = cpu_addr - $8000 + $0010
        local data_ptr = ptr_lo + ptr_hi * 256 - 0x8000 + 0x0010

        meta_cache[map_id] = {
            data_ptr = data_ptr,
            width = width,
            height = height,
            border_tile = border,
        }
    end
end

-- get_metadata(map_id): Return the metadata for a map.
-- Loads the cache on first call.
function M.get_metadata(map_id)
    if not meta_cache[0] then
        load_metadata()
    end
    return meta_cache[map_id]
end

-- ============================================================
-- RLE Decompression
-- ============================================================

-- decompress_map(map_id): Read RLE-compressed tile data from ROM and
-- produce a 2D tile grid.
--
-- RLE format (nibble-based):
--   Each byte encodes one run of tiles.
--   High nibble (bits 7-4) = tile type (0-15)
--   Low nibble (bits 3-0) = repeat count minus 1 (so 0 means 1 tile, 15 means 16)
--
-- The tiles fill the grid left-to-right, top-to-bottom.
-- Returns a 2D table: tiles[y][x] where y and x are 0-based.
-- Returns nil if map_id is invalid or is the overworld.
function M.decompress_map(map_id)
    -- Skip the overworld — it uses a different, more complex format
    -- with row-offset pointers that we don't handle yet
    if maps.is_overworld(map_id) then
        return nil
    end

    local meta = M.get_metadata(map_id)
    if not meta then return nil end

    local width = meta.width
    local height = meta.height
    local total_tiles = width * height

    -- Build empty grid
    local tiles = {}
    for y = 0, height - 1 do
        tiles[y] = {}
    end

    -- Read RLE data starting at the map's data pointer.
    -- The data_ptr from metadata is the ROM file offset.
    local rom_offset = meta.data_ptr
    local tile_count = 0

    -- Safety limit to prevent infinite loops if data is corrupt
    local max_bytes = 4096

    for _ = 1, max_bytes do
        if tile_count >= total_tiles then break end

        local byte = rom.readbyte(rom_offset)
        rom_offset = rom_offset + 1

        -- High nibble = tile type, low nibble = run length - 1
        -- FCEUX bitwise: AND() for masking, divide for shift
        local tile_type = AND(byte, 0xF0) / 16  -- bits 7-4
        local run_length = AND(byte, 0x0F) + 1  -- bits 3-0, plus 1

        -- Place tiles into the grid
        for _ = 1, run_length do
            if tile_count >= total_tiles then break end

            local y = math.floor(tile_count / width)
            local x = tile_count % width

            tiles[y][x] = tile_type
            tile_count = tile_count + 1
        end
    end

    return tiles
end

-- ============================================================
-- Tile Grid Cache
-- ============================================================
-- We cache decompressed tile grids since they're static (ROM data
-- never changes). Keyed by map_id.
local grid_cache = {}

-- get_tile_grid(map_id): Get the 2D tile grid for a map.
-- Returns cached version if available, otherwise decompresses from ROM.
-- Returns nil for the overworld or invalid map IDs.
function M.get_tile_grid(map_id)
    if grid_cache[map_id] then
        return grid_cache[map_id]
    end

    local grid = M.decompress_map(map_id)
    if grid then
        grid_cache[map_id] = grid
    end
    return grid
end

-- ============================================================
-- Walkability
-- ============================================================
-- Tile walkability depends on the tileset. Dragon Warrior uses
-- different graphics for different map categories, but the tile
-- type numbers (0-15 from the RLE data) have consistent meanings.
--
-- These tables are best guesses based on common NES RPG patterns
-- and will need empirical verification. Use the diagnostic hotkey
-- to check what tile type the player is standing on, then update
-- these tables.
--
-- Convention: true = walkable (player can step on this tile)

-- Town/castle tileset (terrain_offset = 0x10)
-- Used by: Tantegel Castle, towns, throne rooms
local WALKABLE_TOWN = {
    [0]  = false,  -- void / boundary (confirmed impassable on Charlock B4: type-0
                   --   tiles form a barrier row the player cannot cross. Some
                   --   Brecconary corridor cells use type-0 in ROM despite being
                   --   live-passable; handle those with MAP_PASSTHROUGH_CELLS.)
    [1]  = true,   -- floor variant
    [2]  = false,  -- wall / building
    [3]  = true,   -- railing / decorative barrier (visually solid but walkable;
                   --   confirmed: player can cross throne room railing y=5, x=1-7,
                   --   which are all type-3. Update if proven non-walkable elsewhere.)
    [4]  = true,   -- floor (castle/throne carpet)
    [5]  = true,   -- stairs
    [6]  = true,   -- floor variant (throne dais, side passages)
    [7]  = false,  -- water / decoration
    [8]  = true,   -- chest (walkable to reach it)
    [9]  = true,   -- floor variant
    [10] = true,   -- floor variant
    [11] = false,  -- wall (NOT a locked door — OPEN command returns "no door here"
                   --   when facing type-11 on Charlock B4, confirmed in-game.
                   --   Actual magic-key doors have tile type 15 in ROM, tracked
                   --   by the game engine separately from tile type data.)
    [12] = false,  -- wall
    [13] = true,   -- floor
    [14] = true,   -- floor
    [15] = false,  -- edge / boundary
}

-- Dungeon/cave tileset (terrain_offset = 0x20)
-- Used by: Charlock Castle floors, Erdrick's Cave, etc.
local WALKABLE_DUNGEON = {
    [0]  = true,   -- floor
    [1]  = false,  -- wall
    [2]  = true,   -- floor variant
    [3]  = false,  -- wall variant
    [4]  = true,   -- stairs
    [5]  = false,  -- locked door (BLK_DOOR source tile in dungeon/cave maps)
    [6]  = false,  -- barrier
    [7]  = true,   -- chest
    [8]  = true,   -- floor
    [9]  = false,  -- wall
    [10] = true,   -- floor
    [11] = false,  -- wall
    [12] = false,  -- wall
    [13] = true,   -- floor
    [14] = true,   -- floor
    [15] = false,  -- wall
}

-- Overworld tileset (terrain_offset = 0x00)
-- Not used for pathfinding (overworld is too large for A*),
-- but included for reference.
local WALKABLE_OVERWORLD = {
    [0]  = true,   -- grass
    [1]  = true,   -- desert
    [2]  = true,   -- hill
    [3]  = false,  -- mountain
    [4]  = true,   -- bridge
    [5]  = false,  -- water
    [6]  = true,   -- forest
    [7]  = true,   -- swamp
    [8]  = true,   -- town entrance
    [9]  = true,   -- cave entrance
    [10] = true,   -- castle entrance
    [11] = true,   -- bridge variant
    [12] = false,  -- mountain variant
    [13] = true,   -- stairs
    [14] = true,   -- field
    [15] = false,  -- barrier
}

-- Map from terrain_offset value to walkability table.
-- We read terrain_offset from RAM address 0x0016 to determine
-- which tileset the current map uses.
local WALKABILITY_TABLES = {
    [0x00] = WALKABLE_OVERWORLD,
    [0x10] = WALKABLE_TOWN,
    [0x20] = WALKABLE_DUNGEON,
}

-- ============================================================
-- Per-Map Passthrough Cell Overrides
-- ============================================================
-- Some cells ARE walkable despite their tile type appearing to be a
-- wall (type 15 in town maps, etc.). These include exit arches,
-- staircase tiles, and interior corridor floors where the game uses
-- the same tile type for both solid walls and passable areas.
--
-- Format: MAP_PASSTHROUGH_CELLS[map_id]["x,y"] = true
-- A cell listed here is always treated as walkable regardless of
-- its tile type. Checked BEFORE the tile-type lookup so these
-- override non-walkable tile types.
local MAP_PASSTHROUGH_CELLS = {
    -- Map 0x04: Tantegel Castle main hall
    -- Live probing on 2026-04-11 confirmed a decoder gap in the y=16 corridor:
    -- the engine allows standing on and traversing (13,16) and (14,16), but
    -- the ROM grid decodes both cells as tile type 11 ("wall"). Keep this
    -- narrowly scoped to the two directly confirmed cells until more live
    -- evidence suggests additional passthroughs in this band.
    [0x04] = {
        ["13,16"] = true,
        ["14,16"] = true,
    },

    -- Map 0x05: Tantegel Castle Throne Room
    -- The south wall (y=7) and bottom row (y=8) are type-15 in ROM, but
    -- the east section contains a corridor that is physically walkable:
    --   (4,8)-(7,8) = corridor floor tiles leading east to the staircase
    --   (8,8) = staircase entry — player stands here to use it
    -- NOTE: (4,7) is the magic-key DOOR cell — it is in MAP_DOOR_CELLS
    -- below (walkable only after the door has been opened, not always).
    -- All confirmed empirically: player walked (4,4)→south→(4,8)→east→(8,8).
    [0x05] = {
        ["4,8"] = true, ["5,8"] = true, ["6,8"] = true,
        ["7,8"] = true, ["8,8"] = true,
    },

    -- Map 0x08: Brecconary
    -- Live probe/inspect rechecks on 2026-04-02 confirmed south-middle
    -- corridor cells that are walkable in-engine despite decoding as
    -- non-walkable type-0/type-12 cells. Keep this narrowly scoped to the
    -- directly confirmed cells until the rest of the corridor is mapped.
    [0x08] = {
        ["8,18"] = true,
        ["8,19"] = true,
        ["9,18"] = true,
        ["10,18"] = true,
        ["11,18"] = true,
        ["11,19"] = true,
    },
}

-- ============================================================
-- Per-Map Magic-Key Door Cell Overrides
-- ============================================================
-- Some cells have tile type 15 (wall) in ROM but host a magic-key door
-- at runtime. parse_doors() in objects.lua looks for tile type 11, so it
-- misses these. We list them here so is_walkable() can check the game's
-- opened-door RAM ($600C/$600D) directly.
--
-- Format: MAP_DOOR_CELLS[map_id]["x,y"] = {x=X, y=Y}
-- When a cell is listed here, is_walkable() returns true ONLY if the
-- door at (x,y) appears in the opened-door array; otherwise false.
local MAP_DOOR_CELLS = {
    -- Map 0x05: Tantegel Castle Throne Room
    -- (4,7) = south-wall arch doorway. ROM tile is type-15 (wall), but the
    -- game engine places a magic-key door here at runtime. Once the player
    -- uses a magic key, the position is recorded in the opened-door RAM and
    -- the cell becomes passable (leading to the corridor and stairs at (8,8)).
    [0x05] = {
        ["4,7"] = {x=4, y=7},
    },
}

-- ============================================================
-- Per-Map Blocked Cell Overrides
-- ============================================================
-- Some cells are physically blocked by the game engine via sprite
-- collision or other mechanisms that don't show up in tile types.
-- We hardcode these overrides here after empirical confirmation.
--
-- Format: MAP_BLOCKED_CELLS[map_id]["x,y"] = true
-- A cell listed here is always treated as non-walkable regardless
-- of its tile type.
local MAP_BLOCKED_CELLS = {
    -- Map 0x04: Tantegel Castle main hall
    --
    -- The castle contains an "antechamber" zone (x=7-12, y=6-9) that has
    -- one-directional engine barriers on all sides. Tiles in this zone read
    -- as walkable in ROM but the engine enforces these walls:
    --
    --   NORTH wall: y=5, x=8-12  — engine blocks northward exit from y=6
    --   WEST wall:  x=6, y=6     — engine blocks westward exit from x=7
    --   EAST wall:  x=13, y=7   — engine blocks eastward exit from x=12
    --   SOUTH:      door at (11,9) — closed door, requires OPEN command to exit
    --
    -- The antechamber can be ENTERED from the east (moving west from x=13 to
    -- x=12) but not EXITED east. Pathfinding must route around it entirely via
    -- the north corridor (y=1-2) to reach west-wing guards at (5,6), (3,6), etc.
    --
    -- To approach west-wing guards, the correct path from the main hall is:
    --   east to x=23+ (where y=6 is open), north past y=5, loop west via y=2
    --   corridor, south into west wing to stand adjacent to the target guard.
    [0x04] = {
        -- North wall of antechamber (y=5, x=8-12)
        -- (7,5) removed 2026-04-08: floor tile (type 4), confirmed false positive by tester
        ["8,5"]  = true, ["9,5"]  = true,
        ["10,5"] = true, ["11,5"] = true, ["12,5"] = true,
        -- West wall (x=6): engine blocks at y=6, y=7, y=8, y=9, y=10.
        -- y=7 and y=8 re-added 2026-04-08: initially removed as suspected floor-tile
        -- false positives, but re-confirmed as full all-direction engine blocks after
        -- investigation showed y=7-8 were genuine wall cells.
        -- y=9 at x=6 was previously modeled as a one-way crossing, but direct
        -- live retests on 2026-04-11 showed movement fails from both (5,9)->(6,9)
        -- and (7,9)->(6,9). With y=8 and y=10 already full blocks, this makes
        -- (6,9) an isolated dead wall cell rather than a usable crossing.
        -- y=10 at x=6: confirmed engine-blocked (also listed in MAP_DIRECTIONAL_BLOCKS east).
        ["6,6"]  = true, ["6,7"]  = true, ["6,8"]  = true, ["6,9"] = true, ["6,10"] = true,
        -- West-wing boundary: x=1-2 at y=6-8 are void/impassable.
        -- Entries (4,6), (3,7), (4,7), (5,7), (3,8), (4,8), (5,8) removed 2026-04-08:
        -- confirmed false positives by tester — they were sealing off the west wing
        -- from all directions, blocking A* from routing to guards at (3,6)/(5,6).
        ["1,6"]  = true, ["2,6"]  = true,
        ["1,7"]  = true, ["2,7"]  = true,
        ["1,8"]  = true, ["2,8"]  = true,
        ["3,9"]  = true, ["3,10"] = true,
        -- East wall of antechamber (x=13, y=7): engine blocks eastward exit
        -- (13,8) and (13,9) removed 2026-04-08: floor tiles (type 4), false positives confirmed by tester
        ["13,7"] = true,
        -- Upper-room zone (x=15-19, y=10-16): engine-blocked zone separating the
        -- main hall (x=21+) from the antechamber/corridor area (x=7-13).
        -- The engine barrier is a wall at column x=15, running further south
        -- than the tile data (all 4+/8+) suggests:
        --   y=9:  x=14-19 removed 2026-04-08 — tester confirmed false positives
        --         (these were blocking the east corridor completely)
        --   y=10: x=15-19 blocked (x=14 is the walkable corridor column)
        --   y=11: x=15-19 blocked (x=14 still open)
        --   y=12: x=15 confirmed blocked (tile=8, movement east from x=14 fails)
        --         x=19-20 are void tiles (0-) so naturally non-walkable
        --   y=13: x=15 confirmed blocked (tile=4, movement east from x=14 fails)
        -- x=15 wall confirmed y=10 through y=16; y=17 is the first passable row.
        -- A* routes south to y=17 then east to x=21+ then north to bypass.
        ["15,10"] = true, ["16,10"] = true, ["17,10"] = true,
        ["18,10"] = true, ["19,10"] = true,
        ["15,11"] = true, ["16,11"] = true, ["17,11"] = true,
        ["18,11"] = true, ["19,11"] = true,
        ["15,12"] = true,  -- engine blocks eastward entry from (14,12); confirmed in-game
        ["15,13"] = true,  -- engine blocks eastward entry from (14,13); confirmed in-game
        ["15,14"] = true,  -- engine wall at x=14→15 extends through y=14; confirmed in-game
        ["15,15"] = true,  -- engine wall continues through y=15; confirmed in-game
        ["15,16"] = true,  -- engine wall continues through y=16; y=17 is first passable row

        -- Sweep data (2026-03-21, freeze_npcs + death-pause, NPC-exclusion).
        -- These 15 cells are confirmed engine-blocked from ALL walkable-adjacent
        -- directions (blocked from 4/4 probed directions). Cells blocked from fewer
        -- directions are omitted: they are accessible from another direction and
        -- should not be in MAP_BLOCKED_CELLS (would break A* connectivity).
        --
        -- y=19: wall band — x=4-10 and x=24-25 confirmed impassable from all sides
        ["4,19"]  = true, ["5,19"]  = true, ["6,19"]  = true, ["7,19"]  = true,
        ["8,19"]  = true, ["9,19"]  = true, ["10,19"] = true,
        ["24,19"] = true, ["25,19"] = true,
        -- y=21: wall stubs confirmed impassable from all sides
        ["10,21"] = true, ["11,21"] = true,
        -- y=24: room divider confirmed impassable from all sides
        ["19,24"] = true, ["20,24"] = true, ["21,24"] = true, ["22,24"] = true,
        -- South-east hall corner near the merchant wing.
        -- Empirically confirmed 2026-03-23: from (20,19), both east->(21,19)
        -- and south->(20,20) fail live movement despite tile=6, walkable=true,
        -- npc_blocked=false, runtime_blocked=false. Block them so A* does not
        -- route through hidden engine-collision cells in this corner.
        ["14,19"] = true, ["20,20"] = true, ["21,19"] = true,
        -- South-central hall hidden barriers.
        -- Empirically confirmed 2026-03-24 during validate_path recheck:
        -- (15,18)->(15,19) and (17,20)->(17,21) both fail live movement even
        -- though inspect_move/inspect_tile report tile=6, walkable=true,
        -- npc_blocked=false, runtime_blocked=false.
        ["13,21"] = true, ["13,22"] = true, ["13,23"] = true, ["15,19"] = true, ["16,21"] = true, ["17,21"] = true, ["18,21"] = true, ["21,21"] = true,
        ["16,16"] = true, ["17,16"] = true, ["18,16"] = true, ["19,16"] = true, ["19,21"] = true,
        -- x=12 column engine barriers at y=17-18 confirmed 2026-04-09 via survey_map:
        -- survey consistently suspects these as blocking the northward path from (13,19).
        -- A* routes through (12,19)→(12,18)→(12,17) to reach north hall; engine refuses.
        -- With these blocked, A* correctly routes east to x=17-20 corridor then north.
        ["12,17"] = true, ["12,18"] = true,
        -- South-west full block confirmed 2026-04-09 via survey_map (all 4 approaches blocked, count=13)
        ["3,22"] = true,
        ["16,24"] = true, ["17,24"] = true, ["18,24"] = true, ["21,22"] = true, ["21,23"] = true,
        ["13,25"] = true, ["12,26"] = true, ["13,26"] = true, ["16,25"] = true, ["16,27"] = true, ["13,27"] = true, ["15,28"] = true,
        ["21,18"] = true,
        ["14,28"] = true,
        -- North corridor hidden barriers near the castle center.
        -- Empirically confirmed 2026-03-23: from (21,3), both west->(20,3)
        -- and east->(22,3) fail one-step validation even though inspect_move
        -- and direct pathfinding report tile=6 walkable=true.
        ["20,3"] = true, ["22,3"] = true,
        -- North-east corridor hidden barriers near the right edge.
        -- Empirically confirmed 2026-03-23: from (27,3), both north->(27,2)
        -- and west->(26,3) fail one-step validation even though inspect_move
        -- and direct pathfinding report them as walkable.
        ["27,2"] = true, ["26,3"] = true,
        -- Upper north corridor hidden barrier.
        -- Empirically confirmed 2026-03-23: from (19,3), north->(19,2)
        -- fails one-step validation even though inspect_move and direct
        -- pathfinding report tile=6 walkable=true.
        ["19,2"] = true,
    },

    -- Map 0x05: Tantegel Castle Throne Room
    -- Most tiles at y=2, x=2-8 are type 4 (floor) in ROM but the engine
    -- blocks them via the throne/dais sprite collision. The older sweep
    -- data overstated this row: (7,2) is reachable and must remain open so
    -- A* can descend from the top corridor on the east side.
    --
    -- Additional throne-area hidden barriers confirmed 2026-03-25:
    -- the side tiles flanking the king pocket still behave as blocked from
    -- the surrounding floor, but live recheck on 2026-03-31 confirmed the
    -- king is normally approached from (3,4). Keep the side blockers while
    -- leaving the south interaction tile open so pathfind_to_adjacent can
    -- route to the king for normal save interaction.
    [0x05] = {
        ["2,2"] = true, ["3,2"] = true, ["4,2"] = true,
        ["5,2"] = true, ["6,2"] = true,
        ["8,2"] = true,
        ["2,3"] = true, ["4,3"] = true,
    },

    -- Map 0x08: Brecconary (30x30 town, west-edge exit at (0,15))
    --
    -- Sweep data (2026-03-27, auto-freeze, NPC exclusion).
    -- Only 6 cells are engine-blocked from ALL walkable-adjacent directions.
    -- Directional wall bands are tracked separately below and extended only
    -- after direct probe confirmation.
    [0x08] = {
        ["21,4"]  = true,  -- tile=8; blocked from all 4 walkable neighbors
        ["2,7"]   = true,  -- tile=1; blocked from 3 walkable neighbors (4th is void)
        ["26,25"] = true,  -- tile=6; blocked from 2 walkable neighbors (others are void)
        ["11,26"] = true,  -- tile=6; blocked from all 4 walkable neighbors
        ["23,27"] = true,  -- tile=6; blocked from 3 walkable neighbors
        ["26,27"] = true,  -- tile=6; blocked from 3 walkable neighbors
    },
}

-- ============================================================
-- Per-Map Directional Block Overrides
-- ============================================================
-- Some cells are passable from certain directions but blocked from others
-- (e.g., building walls in towns that prevent east/west entry but allow
-- north/south passage). These are distinct from MAP_BLOCKED_CELLS which
-- block ALL approach directions.
--
-- Format: MAP_DIRECTIONAL_BLOCKS[map_id]["x,y"] = {direction = true, ...}
-- where direction is the approach direction that is blocked:
--   north = blocked when approaching from the north (moving south into cell)
--   south = blocked when approaching from the south (moving north into cell)
--   east  = blocked when approaching from the east  (moving west into cell)
--   west  = blocked when approaching from the west  (moving east into cell)
local MAP_DIRECTIONAL_BLOCKS = {
    -- Map 0x04: Tantegel Castle main hall
    -- West-wing barrier walls discovered via autowalk reroutes 2026-04-08.
    --
    -- The west wing (x=1-5, y=7-15) is surrounded by engine walls:
    --   EAST FULL BLOCKS at x=6, y=6-8, y=10: in MAP_BLOCKED_CELLS (all directions)
    --   EAST WALL at x=6, y=13-16: directional (blocked when approaching from east)
    --   SOUTH WALL at y=16, x=1-4,6: blocked when approaching from south
    --   y=9 at x=6 is the ONLY valid antechamber→west wing crossing — NOT blocked.
    --   y=11-12 at x=6: unconfirmed; speculative entries removed 2026-04-08.
    --
    -- Antechamber south corridor (x=13-14, y=9) confirmed 2026-04-09:
    --   These cells form a one-way east-entry corridor along the antechamber south wall.
    --   (13,9): blocked from west, north, south — only reachable from east (from (14,9))
    --   (14,9): blocked from north, south — reachable from east (x=15) and west (x=13)
    --   A* must not attempt to use these cells as a vertical shortcut at y=9.
    --
    -- x=15 wall north extension confirmed 2026-04-09:
    --   The engine wall at x=15 (confirmed y=10-16 in MAP_BLOCKED_CELLS) continues
    --   northward. (15,7) and (15,8) are floor tiles (type 4) that the engine blocks
    --   only when approaching from the west (moving east from x=14). Approaching from
    --   east, north, or south is passable.
    --
    -- Interior directional barriers:
    --   (4,9): blocked from east and north — antechamber south door region
    --   (4,15): blocked from east
    --   (4,16): blocked from east and south
    [0x04] = {
        -- x=6 east wall: y=13-16 confirmed via runtime reroutes 2026-04-08.
        -- y=6-8 and y=10 are full blocks in MAP_BLOCKED_CELLS (not listed here).
        -- y=9 promoted to MAP_BLOCKED_CELLS after direct live retest 2026-04-11:
        --   both (5,9)->(6,9) and (7,9)->(6,9) fail in-engine, so it is not a
        --   usable crossing and should not remain directional-only.
        -- y=11-12: removed speculative entries (never confirmed by runtime blocks).
        ["6,13"] = {east = true, west = true},     -- run6 west added (oscillation fix)
        ["6,14"] = {east = true, west = true},     -- run7 west added; count=2 retry_successes=2
        ["6,15"] = {east = true, west = true},     -- run7 west added; count=2 retry_successes=2
        ["6,16"] = {east = true, west = true, south = true},  -- run7 west added; count=2 retry_successes=2
        -- y=16 south wall: x=1-4 confirmed via runtime reroutes 2026-04-08.
        -- x=5 not confirmed by any runtime block; removed (was extrapolated).
        ["1,16"] = {south = true},
        ["2,16"] = {south = true},
        ["3,16"] = {south = true},
        ["4,16"] = {east = true, south = true},  -- confirmed both east and south
        -- x=4 east wall (y=9-16): west wing interior east boundary.
        -- y=9 and y=15-16 previously confirmed; y=10-14 confirmed 2026-04-09 via survey_map
        -- (count=5-6 high confidence each, east=true = can't enter from east/move west into cell).
        ["4,9"]  = {east = true, north = true},  -- antechamber south door region; confirmed
        ["4,10"] = {east = true},                -- survey run4 count=5 high
        ["4,11"] = {east = true},                -- survey run4 count=5 high
        ["4,12"] = {east = true},                -- survey run4 count=5 high
        ["4,13"] = {east = true},                -- survey run4 count=6 high retry_successes=1
        ["4,14"] = {east = true},                -- survey run4 count=5 high
        ["4,15"] = {east = true},                -- confirmed via runtime reroute
        -- Antechamber south corridor: confirmed 2026-04-09 via inspect_move probing
        ["13,9"] = {west = true, north = true, south = true},
        ["14,9"] = {north = true, south = true},
        -- x=15 wall north extension: confirmed 2026-04-09 via inspect_move probing
        ["15,7"] = {west = true},
        ["15,8"] = {west = true},
        -- Survey-confirmed directional blocks 2026-04-09 (survey_map run, 22 failures / 30 targets)
        -- All entries confidence=high unless noted. Approach conventions:
        --   north=true: approaching from north (moving south into cell) is blocked
        --   west=true:  approaching from west  (moving east  into cell) is blocked
        --   east=true:  approaching from east  (moving west  into cell) is blocked
        --   south=true: approaching from south (moving north into cell) is blocked
        --
        -- Antechamber south area (y=7-12):
        ["7,9"]  = {north = true, south = true},  -- count=15
        ["8,9"]  = {east = true, south = true},   -- count=13, retry_successes=1 (strong)
        ["6,11"] = {east = true, west = true},     -- count=6 east; run6 west (oscillation fix)
        ["6,12"] = {east = true, west = true},      -- east: count=1 medium; west: confirmed 2026-04-10 survey pass 8
        -- West corridor band (y=16-18, x=9-12):
        -- x=9-12 at y=16 form a north-approach wall extending the y=16 barrier westward.
        ["9,16"]  = {north = true, west = true},   -- count=30
        ["10,16"] = {north = true},                -- count=15
        ["11,16"] = {north = true},                -- count=15
        -- (13,16)->(12,16) blocked twice by direct probe on 2026-04-12 and
        -- also failed during a long Guard 2 survey route, so this cell blocks
        -- east approach in addition to the earlier north-side evidence.
        ["12,16"] = {north = true, east = true},
        ["9,18"]  = {west = true},                 -- count=15
        -- South-west corridor (y=19-29, x=1-8):
        -- Complex maze of directional barriers in the castle's south-west quadrant.
        -- Run 1 (2026-04-09): found west/north/east approaches.
        -- Run 2 (2026-04-09): found additional east/south approaches on same cells
        --   after run-1 blocks were loaded, confirming multi-direction blocks.
        ["1,19"]  = {south = true},                        -- run1 count=1 medium
        ["2,19"]  = {north = true, south = true},          -- run1 count=7
        ["7,20"]  = {east = true, west = true},            -- run1 west; run2 east
        ["7,21"]  = {south = true, west = true},           -- run1 count=30
        ["8,21"]  = {east = true, north = true},           -- run2 count=12
        ["8,22"]  = {east = true, west = true},            -- run1 west; run2 east
        ["8,23"]  = {east = true, west = true},            -- run1 west; run2 east
        ["8,24"]  = {east = true, west = true},            -- run1 west; run2 east
        ["8,25"]  = {east = true, west = true},            -- run1 west; run2 east
        ["8,27"]  = {west = true},                         -- run1 count=15
        ["9,26"]  = {north = true},                        -- run2 count=2 medium
        ["9,28"]  = {east = true, south = true},           -- run2 count=13 retry_successes=1
        -- (5,24)->(6,24) succeeded twice live on 2026-04-12, so the old west
        -- approach blocker was stale. Keep the north-side evidence only until
        -- that approach is directly reprobed.
        ["6,24"]  = {north = true},
        ["2,24"]  = {north = true, west = true},           -- run1 count=30
        ["3,24"]  = {east = true, north = true},           -- run1 count=30
        ["1,25"]  = {north = true},                        -- run1 count=15
        ["4,25"]  = {east = true, north = true},           -- run1 count=30
        ["4,26"]  = {east = true},                         -- run1 count=15
        ["5,27"]  = {east = true, north = true},           -- run1 count=30
        ["2,28"]  = {south = true},                        -- run2 count=5
        ["3,28"]  = {south = true},                        -- run2 count=5
        ["4,28"]  = {south = true},                        -- run2 count=5
        ["5,28"]  = {south = true},                        -- run2 count=5
        ["6,28"]  = {north = true, south = true},          -- run1 north; run2 south
        ["7,28"]  = {north = true, south = true},          -- run1 north; run2 south
        ["8,28"]  = {south = true},                        -- run2 count=6
        ["1,29"]  = {east = true},                         -- run2 count=5
        ["11,19"] = {south = true},                        -- run2 count=7
        -- Fresh 2026-04-11/2026-04-12 seam repros:
        -- (12,20)->(12,19) succeeded twice live, so the old south approach
        -- blocker was stale. The east approach is still left in place pending
        -- a direct repro because earlier survey runs repeatedly failed there.
        -- (13,20)->(14,20) failed twice live with no reroute contamination, so
        -- promote that seam to a directional west-side engine block.
        -- (12,24)->(13,24) blocked twice live on 2026-04-12 after runtime
        -- clears, so keep this south-pocket seam closed from the west side.
        ["12,19"] = {east = true},
        ["13,24"] = {west = true},
        ["14,20"] = {west = true},
        ["12,28"] = {west = true},                         -- run1 count=1 medium
    },

    -- Map 0x05: Tantegel Castle Throne Room
    -- Survey/autowalk reroute evidence on 2026-03-31:
    --   (7,3) blocked from west and east across repeated reroutes.
    --   (7,2) blocked from east and north across repeated reroutes.
    -- Live one-step probe and manual movement recheck on 2026-03-31
    -- reconfirmed that (7,4)->(7,3) is engine-blocked, so restore the
    -- south approach block. The north chest remains reachable by routing
    -- up the west corridor (x=1) and then east across y=1.
    [0x05] = {
        ["7,3"] = {east = true, south = true, west = true},
        ["7,2"] = {east = true, north = true},
        ["9,3"] = {west = true},
        ["9,4"] = {west = true},
        ["9,5"] = {west = true},
    },

    -- Map 0x08: Brecconary (30x30 town)
    -- Building walls block movement from specific directions.
    -- Confirmed via runtime block discovery during autowalk testing 2026-03-29
    -- plus direct edge-probe rechecks where noted.
    [0x08] = {
        -- NW building west wall (x=3)
        ["3,4"]  = {west = true},
        ["3,5"]  = {west = true},
        -- NW building top and east walls.
        -- The 2026-04-02 survey repeatedly rerouted into y=3 from the north,
        -- confirming the roofline across x=4-7 in addition to the already
        -- known east wall at x=7.
        ["4,3"]  = {north = true},
        ["5,3"]  = {north = true},
        ["6,3"]  = {north = true},
        ["7,3"]  = {north = true, east = true},
        ["7,4"]  = {east = true},
        ["7,5"]  = {east = true},
        -- Center-east building west wall (x=18)
        ["18,10"] = {west = true},
        ["18,11"] = {west = true},
        ["18,12"] = {west = true, south = true},
        -- Center-east building south wall
        ["19,12"] = {south = true},
        -- NE building west wall (x=20)
        ["20,2"] = {west = true, north = true},
        ["20,3"] = {west = true},
        ["20,4"] = {west = true},
        ["20,5"] = {west = true},
        -- NE building north wall (y=2)
        ["21,2"] = {north = true},
        ["22,2"] = {north = true},
        ["23,2"] = {north = true},
        ["24,2"] = {north = true},
        ["25,2"] = {north = true},
        ["26,2"] = {north = true},
        -- NE building east wall / top edge corner.
        -- Survey rerun after per-target runtime-block resets on 2026-04-02
        -- repeatedly trapped routes against the same band, surfacing
        -- east-approach blocks near x=27 and north-approach blocks at
        -- y=9,x=21-26 across 19 failed targets. A direct live repro on
        -- 2026-04-03 then confirmed the omitted (27,5) edge case: from
        -- (28,5), explicit one-step validation to (27,5) failed and
        -- auto_step published a runtime block with approach=east. Clearing
        -- runtime blockers afterward did not restore the older no-path case
        -- from (28,2) to (24,10), so that planner isolation was pre-existing
        -- rather than caused by this cell.
        ["27,2"] = {north = true, east = true},
        ["27,3"] = {east = true},
        ["27,4"] = {east = true},
        ["27,5"] = {east = true},
        -- NE building entrance (south wall, y=6)
        ["25,6"] = {south = true},
        ["26,6"] = {south = true},
        ["27,6"] = {south = true, east = true},
        -- NE building east boundary (x=29)
        ["29,2"] = {west = true},
        -- NE/southeast corridor north wall band.
        ["21,9"] = {north = true},
        ["22,9"] = {north = true},
        ["23,9"] = {north = true},
        ["24,9"] = {north = true},
        ["25,9"] = {north = true},
        ["26,9"] = {north = true, east = true},
        -- South-middle wall bands.
        -- After the Brecconary false-wall passthrough fix on 2026-04-02, the
        -- survey could finally escape the old pocket and repeatedly exercised
        -- the south-middle corridors. The latest reroute-heavy surveys then
        -- promoted x=11,y=21-25 from "possible over-promotion" to strong map
        -- data: Merchant 3 and Guard 6 both failed on that east-approach band,
        -- while Person 1, Person 4, and Guard 3 succeeded only after rerouting
        -- around the same cells.
        ["11,20"] = {north = true, east = true},
        ["11,21"] = {east = true},
        ["11,22"] = {east = true},
        ["11,23"] = {east = true, west = true},
        ["11,24"] = {east = true, west = true},
        ["11,25"] = {east = true, west = true},
        -- Merchant 1 south-approach pocket.
        -- The 2026-04-03 survey still hit a live reroute failure here after
        -- the northeast fixes. A focused replay from (8,13) toward Merchant 1
        -- confirmed the first blocked step at (8,19)->(7,19): validation
        -- stalled, then auto_step published runtime block approach=east for
        -- cell (7,19). Follow-up live probes then confirmed three more cells
        -- in the same pocket: (6,21)->(6,20) fails with approach=south,
        -- (6,21)->(5,21) fails with approach=east, and (6,21)->(7,21) fails
        -- with approach=west. Promote only the directly reproduced entries.
        ["5,21"]  = {east = true},
        ["6,20"]  = {south = true},
        ["7,19"]  = {east = true},
        ["7,21"]  = {west = true},
        ["7,22"]  = {north = true, south = true, west = true},
        ["8,22"]  = {north = true, south = true},
        ["9,20"]  = {west = true},
        ["9,21"]  = {west = true},
        ["9,22"]  = {south = true},
        ["10,22"] = {south = true},
        ["8,24"]  = {east = true, north = true},
        -- Southwest survey reroute trap.
        -- The 2026-04-03 survey regression that dropped from 13/21 to 1/21
        -- successes repeatedly failed the same reroute sequence from (9,25):
        -- (9,26)->(9,27) published approach=north, (9,26)->(8,26) published
        -- approach=east, and (9,25)->(8,25) published approach=east. The very
        -- first attempt from (6,23) also failed on (6,23)->(5,23) with
        -- approach=east. Promote these directly reproduced cells so the next
        -- survey can test beyond the same southwest pocket.
        ["5,23"]  = {east = true},
        ["8,25"]  = {east = true},
        ["8,26"]  = {east = true},
        ["3,27"]  = {south = true},
        ["4,27"]  = {south = true},
        ["5,27"]  = {south = true},
        ["6,27"]  = {south = true},
        ["7,27"]  = {south = true},
        ["8,27"]  = {south = true},
        ["9,27"]  = {north = true, south = true},
        ["10,27"] = {south = true},
        ["11,27"] = {east = true, south = true},
        -- Center/southeast reroute cluster.
        -- Repeated successful reroutes after the 2026-04-02 pocket fix kept
        -- surfacing the same hidden barriers around the merchant wing and the
        -- center hall. Promote only the strongest repeated cells first.
        ["18,21"] = {north = true, south = true},
        ["19,20"] = {north = true, west = true},
        ["19,21"] = {east = true, south = true},
        ["20,19"] = {north = true, west = true},
        ["20,20"] = {south = true},
        ["21,18"] = {west = true},
        ["21,20"] = {south = true},
        ["22,20"] = {east = true, south = true},
        -- Fresh 2026-04-05 survey evidence upgraded (7,20) from a one-sided
        -- suspect to a two-sided hidden barrier: Woman 2 and Guard 4 both
        -- failed on (7,21)->(7,20) with approach=south, while the earlier
        -- Merchant 1 pocket repro had already confirmed the east approach.
        ["7,20"] = {east = true, south = true},
        ["24,17"] = {north = true},
        ["25,16"] = {west = true},
        ["25,12"] = {south = true},
        ["26,11"] = {east = true},
        ["26,12"] = {east = true, south = true},
        ["26,16"] = {north = true},
        ["27,16"] = {east = true, north = true},
        ["28,17"] = {east = true, north = true},
        ["15,28"] = {north = true, west = true},
        ["16,27"] = {north = true, west = true},
    },
}

-- get_directional_blocks(map_id): Return the directional block table for
-- a map, or an empty table if none are defined.
-- Each entry is keyed by "x,y" with a value table of blocked approach
-- directions: {north=true, south=true, east=true, west=true}.
function M.get_directional_blocks(map_id)
    return MAP_DIRECTIONAL_BLOCKS[map_id] or {}
end

local function lookup_walkability_base(map_id, x, y)
    local grid = M.get_tile_grid(map_id)
    if not grid then return nil end

    local meta = M.get_metadata(map_id)
    if not meta then return nil end

    local details = {
        map_id = map_id,
        x = x,
        y = y,
        tile_type = nil,
        base_walkable = nil,
        permanent_blocked = false,
        effective_walkable = nil,
        reason = nil,
    }

    if x < 0 or x >= meta.width or y < 0 or y >= meta.height then
        details.base_walkable = false
        details.effective_walkable = false
        details.reason = "out_of_bounds"
        return details
    end

    local key = x .. "," .. y
    local tile_type = grid[y][x]
    details.tile_type = tile_type

    if not maps.is_overworld(map_id) and (x == 0 or y == 0) then
        details.base_walkable = false
        details.effective_walkable = false
        details.reason = "engine_boundary"
        return details
    end

    local passthroughs = MAP_PASSTHROUGH_CELLS[map_id]
    if passthroughs and passthroughs[key] then
        details.base_walkable = true
        details.effective_walkable = true
        details.reason = "passthrough"
        return details
    end

    local door_cells = MAP_DOOR_CELLS[map_id]
    if door_cells and door_cells[key] then
        local dc = door_cells[key]
        for i = 0, addr.DOOR_ARRAY_MAX - 1 do
            local dx = memory.readbyte(addr.DOOR_X_POS_START + i * addr.DOOR_ARRAY_STRIDE)
            local dy = memory.readbyte(addr.DOOR_Y_POS_START + i * addr.DOOR_ARRAY_STRIDE)
            if dx ~= 0 and dx == dc.x and dy == dc.y then
                details.base_walkable = true
                details.effective_walkable = true
                details.reason = "door_open"
                return details
            end
        end
        details.base_walkable = false
        details.effective_walkable = false
        details.reason = "door_closed"
        return details
    end

    if tile_type == nil then
        return details
    end

    local walkable_table = M.get_walkability_table(map_id)
    if not walkable_table then
        return details
    end

    local result = walkable_table[tile_type]
    if result == nil then
        result = false
    end
    details.base_walkable = result
    details.effective_walkable = result
    details.reason = "tile_type"
    return details
end

function M.is_permanently_blocked_override(map_id, x, y)
    local overrides = MAP_BLOCKED_CELLS[map_id]
    return overrides and overrides[x .. "," .. y] or false
end

function M.get_walkability_details(map_id, x, y)
    local details = lookup_walkability_base(map_id, x, y)
    if not details then return nil end
    details.permanent_blocked = M.is_permanently_blocked_override(map_id, x, y) and true or false
    if details.permanent_blocked then
        details.effective_walkable = false
        details.reason = "permanent_blocked"
    end
    return details
end

-- is_walkable(map_id, x, y): Check if a tile at (x, y) is passable.
-- Returns true if the player can walk on this tile, false if it's a wall.
-- Returns nil if we can't determine walkability (no grid data, etc.).
function M.is_walkable(map_id, x, y)
    local details = M.get_walkability_details(map_id, x, y)
    if not details then return nil end
    return details.effective_walkable
end

-- get_walkability_table(map_id): Return the appropriate walkability
-- table for the current map.
--
-- We read TERRAIN_OFFSET from RAM (address 0x0016) instead of using a
-- hardcoded map-category table, because the game itself sets this byte
-- correctly for every map at load time:
--   0x00 = overworld, 0x10 = town/castle, 0x20 = dungeon/cave
-- Reading it from RAM is more reliable than guessing from map IDs.
function M.get_walkability_table(map_id)
    local terrain_offset = memory.readbyte(addr.TERRAIN_OFFSET)
    local tbl = WALKABILITY_TABLES[terrain_offset]
    if tbl then return tbl end
    -- Unknown terrain offset — fall back to overworld (safest default)
    return WALKABLE_OVERWORLD
end

-- get_map_dimensions(map_id): Return width, height for a map.
-- Convenience function used by pathfinder.
function M.get_map_dimensions(map_id)
    local meta = M.get_metadata(map_id)
    if not meta then return nil, nil end
    return meta.width, meta.height
end

-- get_tile_type(map_id, x, y): Return the raw tile type at a position.
-- Useful for diagnostics (figuring out which tile types are walkable).
function M.get_tile_type(map_id, x, y)
    local grid = M.get_tile_grid(map_id)
    if not grid then return nil end

    local meta = M.get_metadata(map_id)
    if not meta then return nil end

    if x < 0 or x >= meta.width or y < 0 or y >= meta.height then
        return nil
    end

    return grid[y][x]
end

return M
