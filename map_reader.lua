-- map_reader.lua
-- ROM map data reading for Dragon Warrior.
--
-- Reads map metadata and tile data from the ROM to build 2D tile grids.
-- Dragon Warrior stores maps as RLE-compressed tile data in the ROM.
-- Each map has a metadata entry (5 bytes) with a data pointer, width,
-- height, and border tile. The tile data uses nibble-based RLE:
-- high nibble = tile type (0-15), low nibble = repeat count minus 1.
--
-- The overworld (map 0x00) uses a more complex system with row-offset
-- pointers, so we skip A* pathfinding for it and only build tile grids
-- for interior maps (towns, dungeons, castles).
--
-- Tile walkability is determined per-tileset. The game uses different
-- tile graphics for overworld, towns, and dungeons, but the tile TYPE
-- numbers (0-15) have consistent meanings within each category.

local addr = require "addresses"

local M = {}

-- ============================================================
-- Constants
-- ============================================================

-- Number of maps in the game (0x00 through 0x1D = 30 maps)
local NUM_MAPS = 30

-- ROM address where map metadata table begins.
-- Each entry is 5 bytes: pointer_lo, pointer_hi, width, height, border_tile
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
        local width = rom.readbyte(base + 2)
        local height = rom.readbyte(base + 3)
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
-- Returns nil if map_id is invalid or is the overworld (map 0).
function M.decompress_map(map_id)
    -- Skip the overworld — it uses a different, more complex format
    -- with row-offset pointers that we don't handle yet
    if map_id == 0x00 then
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
                   --   tiles form a barrier row the player cannot cross. If this
                   --   ever breaks Tantegel Castle navigation, add specific
                   --   MAP_PASSTHROUGH_CELLS entries for map 0x08.)
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
    --   NORTH wall: y=5, x=7-12  — engine blocks northward exit from y=6
    --   WEST wall:  x=6, y=6-8   — engine blocks westward exit from x=7
    --   EAST wall:  x=13, y=7-8  — engine blocks eastward exit from x=12
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
        -- North wall of antechamber (y=5, x=7-12)
        ["7,5"]  = true, ["8,5"]  = true, ["9,5"]  = true,
        ["10,5"] = true, ["11,5"] = true, ["12,5"] = true,
        -- West wall (x=6): engine blocks all directions at y=6, y=7, y=8.
        -- y=9 at x=6 is void (0-) in tile data, already non-walkable.
        -- y=10 at x=6: confirmed engine-blocked eastward from (5,10).
        ["6,6"]  = true, ["6,7"]  = true, ["6,8"]  = true, ["6,10"] = true,
        -- West-wing dead zone: x=1-5, y=6-9 has NO A*-navigable exits.
        -- Engine blocks northward re-entry to y=6 from y=7 (all x=1-5 confirmed).
        -- x=6 blocks eastward exit at y=6-8. y=9 is void (tile 0) at x=1-10
        -- except x=3 which is reachable from y=8 but engine-blocks onward to y=10.
        -- Block the entire zone so A* never routes the player into it.
        -- Guards at (3,6)/(5,6) are approached from y=5 via the north corridor.
        ["1,6"]  = true, ["2,6"]  = true, ["4,6"]  = true,
        ["1,7"]  = true, ["2,7"]  = true, ["3,7"]  = true, ["5,7"]  = true,
        ["1,8"]  = true, ["2,8"]  = true, ["3,8"]  = true,
        ["4,8"]  = true, ["5,8"]  = true,
        ["3,9"]  = true, ["3,10"] = true,
        -- West-wing east boundary at y=7: engine blocks westward movement from
        -- (5,7) to (4,7). Kept here to prevent A* loop at that position.
        ["4,7"]  = true,
        -- East wall of antechamber (x=13, y=7-9): engine blocks eastward exit
        ["13,7"] = true, ["13,8"] = true, ["13,9"] = true,
        -- Upper-room zone (x=14-19, y=9-13): engine-blocked zone separating the
        -- main hall (x=21+) from the antechamber/corridor area (x=7-13).
        -- The engine barrier is a wall between column x=14 and x=15, running
        -- further south than the tile data (all 4+/8+) suggests:
        --   y=9:  x=14-19 all blocked
        --   y=10: x=15-19 blocked (x=14 is the walkable corridor column)
        --   y=11: x=15-19 blocked (x=14 still open)
        --   y=12: x=15 confirmed blocked (tile=8, movement east from x=14 fails)
        --         x=19-20 are void tiles (0-) so naturally non-walkable
        --   y=13: x=15 confirmed blocked (tile=4, movement east from x=14 fails)
        -- x=15 wall confirmed y=9 through y=16; y=17 is the first passable row.
        -- A* routes south to y=17 then east to x=21+ then north to bypass.
        ["14,9"] = true, ["15,9"] = true, ["16,9"] = true,
        ["17,9"] = true, ["18,9"] = true, ["19,9"] = true,
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
    },

    -- Map 0x05: Tantegel Castle Throne Room
    -- Tiles at y=2, x=2-8 are type 4 (floor) in ROM but the engine
    -- blocks them via the throne/dais sprite collision. Only (1,2)
    -- is reachable (confirmed empirically by player movement tests).
    [0x05] = {
        ["2,2"] = true, ["3,2"] = true, ["4,2"] = true,
        ["5,2"] = true, ["6,2"] = true, ["7,2"] = true,
        ["8,2"] = true,
    },
}

-- is_walkable(map_id, x, y): Check if a tile at (x, y) is passable.
-- Returns true if the player can walk on this tile, false if it's a wall.
-- Returns nil if we can't determine walkability (no grid data, etc.).
function M.is_walkable(map_id, x, y)
    local grid = M.get_tile_grid(map_id)
    if not grid then return nil end

    local meta = M.get_metadata(map_id)
    if not meta then return nil end

    -- Bounds check
    if x < 0 or x >= meta.width or y < 0 or y >= meta.height then
        return false
    end

    -- Engine boundary: the game prevents player movement to x=0 or y=0
    -- on interior maps even when those tiles have walkable types.
    -- Confirmed empirically:
    --   x=0: the left side passage (x=0) in the throne room shows tile type
    --         6W but the player is always blocked there.
    --   y=0: hard engine boundary on all interior maps.
    --   y=1: IS accessible (player confirmed reaching row 1 in the throne room
    --         by going around via x=1).
    -- Skip this check for the overworld (map 0x00).
    if map_id ~= 0x00 and (x == 0 or y == 0) then
        return false
    end

    -- Per-map passthrough overrides: cells walkable despite tile type.
    -- Check this BEFORE the tile-type table so these take priority.
    local passthroughs = MAP_PASSTHROUGH_CELLS[map_id]
    if passthroughs and passthroughs[x .. "," .. y] then
        return true
    end

    -- Per-map magic-key door cells: walkable only after the door is opened.
    -- These have tile type 15 (wall) in ROM so parse_doors() misses them.
    -- We check the game's opened-door RAM arrays directly ($600C/$600D).
    local door_cells = MAP_DOOR_CELLS[map_id]
    if door_cells and door_cells[x .. "," .. y] then
        local dc = door_cells[x .. "," .. y]
        for i = 0, addr.DOOR_ARRAY_MAX - 1 do
            local dx = memory.readbyte(addr.DOOR_X_POS_START + i * addr.DOOR_ARRAY_STRIDE)
            local dy = memory.readbyte(addr.DOOR_Y_POS_START + i * addr.DOOR_ARRAY_STRIDE)
            if dx ~= 0 and dx == dc.x and dy == dc.y then
                return true   -- door opened → cell passable
            end
        end
        return false          -- door still closed → cell blocked
    end

    -- Per-map sprite-collision overrides (cells blocked by game engine
    -- mechanisms not reflected in tile types).
    local overrides = MAP_BLOCKED_CELLS[map_id]
    if overrides and overrides[x .. "," .. y] then
        return false
    end

    local tile_type = grid[y][x]
    if tile_type == nil then return nil end

    -- Determine which walkability table to use based on the map.
    -- We use terrain_offset (RAM 0x0016) but since that's a runtime value,
    -- we need a map-based lookup. Categorize maps by their type:
    local walkable_table = M.get_walkability_table(map_id)
    if not walkable_table then return nil end

    local result = walkable_table[tile_type]
    -- Default to non-walkable for unknown tile types
    if result == nil then return false end
    return result
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
