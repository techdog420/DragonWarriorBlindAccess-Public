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
-- Raw Block Access
-- ============================================================
-- The game map bytes themselves store two block IDs per byte. This is useful
-- for engine triggers such as block 0xF ("Large Tile" / counter), even where
-- the accessibility pathfinding grid has local overrides or older decoder
-- assumptions layered on top of it.

function M.get_raw_block_id(map_id, x, y)
    if maps.is_overworld(map_id) then
        return nil
    end

    local meta = M.get_metadata(map_id)
    if not meta then return nil end

    x = tonumber(x)
    y = tonumber(y)
    if x == nil or y == nil then return nil end
    x = math.floor(x)
    y = math.floor(y)

    if x < 0 or x >= meta.width or y < 0 or y >= meta.height then
        return nil
    end

    local bytes_per_row = math.ceil(meta.width / 2)
    local byte_offset = meta.data_ptr + y * bytes_per_row + math.floor(x / 2)
    local byte = rom.readbyte(byte_offset)
    if byte == nil then
        return nil
    end

    byte = math.floor(tonumber(byte) or 0) % 256
    if x % 2 == 0 then
        return math.floor(byte / 16) % 16
    end
    return byte % 16
end

function M.is_large_tile(map_id, x, y)
    return M.get_raw_block_id(map_id, x, y) == 0x0F
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
-- override non-walkable tile types and map-specific entrance edge cells
-- can override the generic interior boundary rule.
local MAP_PASSTHROUGH_CELLS = {
    -- Map 0x04: Tantegel Castle main hall
    -- Live probing on 2026-04-11 and 2026-04-13 confirmed a decoder gap in the
    -- y=16 corridor: the engine allows standing on and traversing these cells,
    -- but the ROM grid decodes them as tile type 11 ("wall"). Keep this
    -- narrowly scoped to the directly confirmed cells until more live evidence
    -- suggests additional passthroughs in this band.
    [0x04] = {
        -- y=16 corridor: tile=11 in ROM but engine-walkable (decoder gap).
        -- x=13,14: bidirectional (confirmed 2026-04-21 probes from both north and south).
        -- x=15,16,17: ONE-WAY southward only — northward entry engine-blocked (south=true
        --   in MAP_DIRECTIONAL_BLOCKS). See also x=18,19,20 which are floor tiles (type 4)
        --   with the same one-way pattern.
        ["13,16"] = true,
        ["14,16"] = true,
        ["15,16"] = true,
        ["16,16"] = true,
        ["17,16"] = true,
        -- y=4 north corridor decoder gap: tile=0 in ROM but engine-walkable.
        -- (14,4) and (15,4) confirmed 2026-04-16 via live probe.
        -- (14,3), (14,5), (15,5) confirmed 2026-04-21: probe_edge moved into them
        -- despite base_walkable=false (additional decoder gap cells).
        -- Full confirmed passable path: (12,4)→(13,4)→(14,4)→(15,4)→(16,4)→(17,4)
        -- entering the east wing. (16,4)+(17,4) are regular floor tiles (type 4).
        ["14,3"] = true,
        ["14,4"] = true,
        ["14,5"] = true,
        ["15,4"] = true,
        ["15,5"] = true,
        -- x=5 column y=6 decoder gap: tile=0 but engine-walkable.
        -- Connects (5,7) [tile=6, walkable] to (5,5) [tile=6, walkable].
        -- Confirmed 2026-04-22 via probe_edge: status=moved, tile=0, moved_through_modeled_block.
        ["5,6"] = true,
        -- y=4 strip decoder gaps: tile=0 but engine-walkable. Confirmed 2026-04-22 via probe_edge
        -- (all three: status=moved, tile=0, moved_through_modeled_block).
        -- These form the bypass route around engine-blocked (6,5):
        --   (4,5)→north→(4,4)→east→(5,4)→east→(6,4)→east→(7,4)[passthrough]→north→east wing.
        -- Also resolves (5,5) dead-end: from (5,5) north→(5,4)→(6,4)→(7,4) is now viable.
        ["4,4"] = true, ["5,4"] = true, ["6,4"] = true,
        -- x=7-8, y=3-5 northwest corridor decoder gaps: tile=0 but engine-walkable.
        -- (7,3)+(7,4): confirmed 2026-04-21 via probe_edge (status=moved, tile=0).
        -- (7,3) south=true: engine blocks northward entry from (7,4) — confirmed 2026-04-22
        --   probe_edge:UP from (7,4) → blocked_despite_open_preview. (7,3) is still reachable
        --   from (7,2) going south. See MAP_DIRECTIONAL_BLOCKS ["7,3"] = {south=true}.
        -- (8,3): confirmed engine-walkable but east→(9,3) is engine-blocked;
        --   see MAP_DIRECTIONAL_BLOCKS ["9,3"] = {west=true}.
        -- (8,4): decoder gap (tile=0) bridging (7,4) to the regular-floor corridor at (9,4)+.
        --   Confirmed 2026-04-22 probe_edge:RIGHT from (7,4) → moved_through_modeled_block.
        --   Completes the y=4 east corridor: (4,4)→…→(7,4)→(8,4)→(9,4)→…→(13,4)→(14,4)→east wing.
        ["7,3"] = true,
        ["7,4"] = true,
        ["8,3"] = true,
        ["8,4"] = true,
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
        -- Weapon shop west-side column. These cells are engine-walkable, but
        -- Woman 3 can stand at (4,7). The west column stays modeled as
        -- engine-walkable where appropriate, but the adjacent shop pockets are
        -- pathfinder-forbidden below until a normal public approach is decoded.
        ["4,6"] = true,
        ["4,7"] = true,
        -- West-wing throat cells. These ROM-decode as type-0, but 2026-05-11
        -- live manual movement showed (3,8)->UP into (3,7), (3,8)->DOWN into
        -- (3,9), and east/west movement between (2,9) and (3,9). The northern
        -- cap remains closed: repeated (3,7)->UP attempts into (3,6) blocked.
        ["3,7"] = true,
        ["2,9"] = true,
        ["3,9"] = true,
        -- Merchant 2 doorway/counter interaction throat. The ROM tiles decode
        -- as non-walkable type 0, but live movement reaches (5,7) from the
        -- south and then (5,6); TALK opens the weapon/armor shop from (5,6)
        -- while facing north.
        ["5,6"] = true,
        ["5,7"] = true,
        -- Merchant 4 alternate/debug tool-shop interaction tile. The ROM decodes this tile as
        -- non-walkable type 0, but 2026-05-11 live probes moved
        -- (25,27)->UP into (25,26) 3/3 times; TALK from there while facing
        -- north opens the tool shop. Object routing now prefers the public
        -- stand at (23,25) facing east, but this tile remains a real
        -- one-way/isolated interaction pocket and should stay modeled.
        ["25,26"] = true,
        -- Lower public approach toward Merchant 4. The ROM decodes (20,26)
        -- as type-0/non-walkable, but 2026-05-12 manual movement and logs
        -- repeatedly crossed (20,25)<->(20,26) in both directions.
        ["20,26"] = true,
        -- East-west corridor near Merchant 4 tracking. Older trap-cell data
        -- kept this pathfinder-forbidden, but 2026-05-14 manual movement and
        -- raw verifier proof crossed into (17,22) from both (16,22) and
        -- (18,22). Keep it explicitly walkable so the model matches the
        -- engine-passable corridor.
        ["17,22"] = true,
        -- Merchant 4 lower-west bridge candidate. The ROM decodes (17,25) as
        -- type-0/non-walkable, and it remains modeled as a standable
        -- passthrough so other approaches can be investigated. A later
        -- 2026-05-14 route/probe pass superseded the older noisy open result:
        -- (16,25)->RIGHT into (17,25) blocks from the west approach.
        ["17,25"] = true,
        -- Merchant 4 public-side false walls. Fresh 2026-05-12 edge verifier
        -- evidence moved (22,26)->RIGHT into (23,26) 5/5 times. (21,26)
        -- remains standable for alternate approaches, but a later 2026-05-14
        -- retest superseded the older return-route evidence: entering it
        -- from (22,26)->LEFT blocks from the east approach.
        ["21,26"] = true,
        ["23,26"] = true,
        -- Merchant 4 east-side false wall. Edge verifier confirmed
        -- (27,25)->DOWN into (27,26) moved 3/3, with six total moved seam
        -- observations in the same live map-0x08 log.
        ["27,26"] = true,
        -- East-wing false-wall throat. This ROM-decodes as type-0, but
        -- 2026-05-11 manual movement repeatedly crossed (22,24)->UP into
        -- (22,23) and (22,23)->DOWN back into (22,24). Leaving it as a wall
        -- strands the player in a pocket with no reachable objects.
        ["22,24"] = true,
        -- Old Man 2 / Curse Remover public approach. The ROM decodes (24,12)
        -- as a wall, but 2026-05-14 manual movement and logs crossed
        -- (24,13)->UP into (24,12), (24,12)->UP into (24,11), and
        -- (24,11)->DOWN back into (24,12). This opens the real public TALK
        -- stand south of Old Man 2 at (24,10).
        ["24,12"] = true,
        ["8,18"] = true,
        ["8,19"] = true,
        ["9,18"] = true,
        ["10,18"] = true,
        ["11,18"] = true,
        ["11,19"] = true,
    },

    -- Map 0x1C: Erdrick's Cave B1 entrance strip.
    -- Live probes on 2026-05-08 confirmed the engine moves
    -- (0,0) -> right -> (1,0) -> down -> (1,1), and the reverse
    -- (1,1) -> up -> (1,0) -> left -> (0,0), despite (0,0)/(1,0)
    -- decoding as type-9 edge/wall cells. Keep this limited to the
    -- confirmed entrance path; (0,1) still behaves as a boundary wall.
    [0x1C] = {
        ["0,0"] = true,
        ["1,0"] = true,
    },

    -- Map 0x1D: Erdrick's Cave B2 left-edge loop.
    -- The generic dungeon edge rule marks x=0 cells as boundaries, but live
    -- route-shaped probes on 2026-05-10 confirmed the intended B2 loop crosses
    -- from (1,7) into (0,7), walks north through (0,6)/(0,5)/(0,4), then
    -- returns east to (1,4). A later reroute proved the upper continuation:
    -- (1,2)->LEFT moved into (0,2) 15/15, then a forced-origin probe from
    -- (0,2)->UP moved into (0,1). A later route-shaped probe sequence proved
    -- the top edge continues from (0,1)->UP through (0,0)..(6,0), then drops
    -- into (6,1). Adjacent edge cells such as (0,8), (0,9), and (0,3) stayed
    -- blocked or mixed, so keep this route strip narrow.
    [0x1D] = {
        ["0,0"] = true,
        ["0,1"] = true,
        ["0,2"] = true,
        ["0,4"] = true,
        ["0,5"] = true,
        ["0,6"] = true,
        ["0,7"] = true,
        ["1,0"] = true,
        ["2,0"] = true,
        ["3,0"] = true,
        ["4,0"] = true,
        ["5,0"] = true,
        ["6,0"] = true,
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
    -- Map 0x04: Tantegel Castle main hall
    -- y=6 magic-key door band: five F- (type 15) tiles confirmed by dump_grid
    -- (2026-04-26). These are the ONLY type-15 tiles on this map.
    --
    -- These doors provide the DIRECT CENTER crossing from the main hall (y=7+)
    -- to the north section (y=5 and above). Of the five, only (14,6) is useful
    -- for pathfinding: it leads to (14,5)[passthrough]→(14,4)[passthrough]→east
    -- wing. Doors (10,6)–(13,6) exit to cells in the antechamber north wall
    -- (y=5, x=8-12 in MAP_BLOCKED_CELLS) and provide no viable path.
    --
    -- NOTE: The x=5 decoder gap bypass reaches the y=4 east connector up to the
    -- west side of the confirmed east-wall seams: (5,7)→(5,6)[passthrough]→
    -- (5,5)→(5,4)[passthrough]→(6,4)[passthrough]→(7,4)[passthrough]→
    -- (8,4)[passthrough]→y=4 corridor. It does NOT prove all east-side targets
    -- are key-free: the far-east cluster past the confirmed 21,4/21,5 west
    -- blocks remains no-path from (10,8)/(10,10) in parked-NPC checks
    -- (2026-04-26). The magic-key doors provide a shorter center crossing once opened.
    --
    -- Opening any door (facing north + OPEN command + magic key) records that
    -- door's (x,y) in the opened-door RAM array ($600C/$600D, up to 8 slots).
    -- The pathfinder then routes through whichever door(s) are open. Doors reset
    -- to closed on each map re-entry (RAM clears on map load).
    [0x04] = {
        ["10,6"] = {x=10, y=6},
        ["11,6"] = {x=11, y=6},
        ["12,6"] = {x=12, y=6},
        ["13,6"] = {x=13, y=6},
        ["14,6"] = {x=14, y=6},
    },
    -- Map 0x05: Tantegel Castle Throne Room
    -- (4,7) = south-wall arch doorway. ROM tile is type-15 (wall), but the
    -- game engine places a magic-key door here at runtime. Once the player
    -- uses a magic key, the position is recorded in the opened-door RAM and
    -- the cell becomes passable (leading to the corridor and stairs at (8,8)).
    [0x05] = {
        ["4,7"] = {x=4, y=7},
    },
    -- Map 0x08: Brecconary
    -- External guide/map comparison plus local topology frontier analysis found
    -- two locked doors that the ROM tile scan cannot infer: the northeast
    -- building door and the west room in the inn.
    [0x08] = {
        ["21,6"] = {x=21, y=6},
        ["5,22"] = {x=5, y=22},
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
    --   SOUTH:      (11,9) — tile type 6 (walkable floor), NOT a door; antechamber south
    --               is open. Old "closed door" label was a misidentification (confirmed
    --               2026-04-26 via dump_grid: 6+ at (11,9)).
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
        -- (6,5): engine-blocked; south approach confirmed 2026-04-22 (survey from (5,5) east).
        -- Full block (not directional) — bypass route is via (4,4)→(5,4)→(6,4)→(7,4).
        ["6,5"]  = true,
        ["6,6"]  = true, ["6,7"]  = true, ["6,8"]  = true, ["6,9"] = true, ["6,10"] = true,
        -- West-wing boundary: x=1-2 at y=6-8 are void/impassable.
        -- Entries (4,6), (3,7), (4,7), (5,7), (3,8), (4,8), (5,8) removed 2026-04-08:
        -- confirmed false positives by tester — they were sealing off the west wing
        -- from all directions, blocking A* from routing to guards at (3,6)/(5,6).
        ["1,6"]  = true, ["2,6"]  = true,
        ["1,7"]  = true, ["2,7"]  = true,
        ["1,8"]  = true, ["2,8"]  = true,
        -- (3,9) and (3,10) removed 2026-04-16: confirmed false positives via live probe.
        -- probe_edge:DOWN from (3,9) returned status=moved final=(3,10) with
        -- EDGE_PROBE_MODEL_MISMATCH kind=moved_through_modeled_block. Both cells
        -- have tile=6 and are engine-walkable. Removing them restores connectivity
        -- from (3,8) south through the west-wing corridor to Guard 4 at (2,14)
        -- and chests at (2,14)/(3,15).
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
        -- x=15 wall confirmed y=10 through y=15.
        -- Live repros on 2026-04-13 show (15,16) is part of the false-wall
        -- corridor band and must stay open.
        ["15,10"] = true, ["16,10"] = true, ["17,10"] = true,
        ["18,10"] = true, ["19,10"] = true,
        ["15,11"] = true, ["16,11"] = true, ["17,11"] = true,
        ["18,11"] = true, ["19,11"] = true,
        ["15,12"] = true,  -- engine blocks eastward entry from (14,12); confirmed in-game
        ["15,13"] = true,  -- engine blocks eastward entry from (14,13); confirmed in-game
        ["15,14"] = true,  -- engine wall at x=14→15 extends through y=14; confirmed in-game
        ["15,15"] = true,  -- engine wall continues through y=15; confirmed in-game

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
        -- Empirically confirmed 2026-03-23: from (20,19), east->(21,19)
        -- fails live movement despite tile=6, walkable=true, npc_blocked=false,
        -- runtime_blocked=false. Retest on 2026-05-14 proved (20,20) is a
        -- standable crossing tile; only its east exit is modeled directionally.
        ["14,19"] = true, ["21,19"] = true,
        -- South-central hall hidden barriers.
        -- Empirically confirmed 2026-03-24 during validate_path recheck:
        -- (15,18)->(15,19) and (17,20)->(17,21) both fail live movement even
        -- though inspect_move/inspect_tile report tile=6, walkable=true,
        -- npc_blocked=false, runtime_blocked=false.
        ["13,21"] = true, ["13,22"] = true, ["13,23"] = true, ["15,19"] = true, ["16,21"] = true, ["17,21"] = true, ["18,21"] = true, ["21,21"] = true,
        -- Row 16 upper-chamber retested 2026-04-13/2026-04-21:
        -- x=13-17 at y=16 are MAP_PASSTHROUGH_CELLS (tile=11 but engine-walkable). x=13,14
        -- are bidirectional; x=15,16,17 are one-way southward (south=true in directional
        -- blocks). x=18,19,20 are floor tiles with the same one-way pattern. (15,16) also
        -- has west=true. See MAP_PASSTHROUGH_CELLS and MAP_DIRECTIONAL_BLOCKS below.
        ["19,21"] = true,
        -- (13,13): one-way-entry trap. Tile type=4 (floor), accepts entry from west (x=12
        -- going east), but all 4 exits blocked (engine refuses south/west/north/east).
        -- Confirmed by survey run 5 (2026-04-15): blocked_events=4, all directions 3-for-3 timeout.
        -- Pathfinder chose it as adj to Guard 3 (14,13) with 3-step path; (14,12) is the
        -- safe 5-step alternative. Blocking (13,13) makes A* pick (14,12) instead.
        ["13,13"] = true,
        -- (28,11): one-way-entry trap. Tile type=8 (walkable in ROM), but all 4 engine exits
        -- blocked: north→(28,10) refused, south→(28,12) refused, east→(29,11) refused,
        -- west→(27,11) is void tile. Confirmed 2026-04-16 via survey runtime blocks during
        -- Guard 1 path (approach from south via (28,12)→north is the only way in).
        -- A* currently routes through here on the only model path to Guard 1's cluster (y=4,
        -- x=9-15). Blocking it forces A* to route one step east via (29,12)→(29,11)→(29,9)
        -- instead, which the engine has not blocked.
        ["28,11"] = true,
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
        -- East-wing pocket walls confirmed by survey run (2026-04-19).
        -- Start at (22,22) routes south to (22,23); from there (22,22) is a
        -- one-way entry (can't re-enter from south) and (23,23) is blocked
        -- from the west. Two confirmed blocks cut the pocket off entirely.
        ["22,22"] = true, ["23,23"] = true,
        -- West alcove walls confirmed by survey run (2026-04-19).
        -- The west alcove (x=1-3, y=11-15) is a sealed room; the only entrance
        -- is through (4,16) to the south. Tile type is 6 (carpet) in ROM for all
        -- of these, so A* treats them as walkable — but the engine refuses entry.
        -- Seam observer confirmed all 11 cells as engine-blocked during survey.
        -- Adding them here prevents A* from routing through the walls and
        -- triggering the confirm→reroute→no-path failure cascade.
        --
        --   East wall:  x=4, y=11-15 (player at x≤3 can't move east past column 4)
        --   North wall: y=10, x=1-3  (player at y≥11 can't move north into y=10)
        --   South wall: y=16, x=1-3  (player at y≤15 can't move south into y=16)
        ["4,11"] = true, ["4,12"] = true, ["4,13"] = true, ["4,14"] = true, ["4,15"] = true,
        ["1,10"] = true, ["2,10"] = true, ["3,10"] = true,
        ["1,16"] = true, ["2,16"] = true, ["3,16"] = true,
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
    -- Most entries here are engine-blocked from all walkable-adjacent directions.
    -- One-way/trap cells may also be listed when the engine can strand the
    -- player there; those are pathfinder-forbidden even if a noisy entry probe
    -- once appeared to move into the cell.
    [0x08] = {
        ["21,4"]  = true,  -- tile=8; blocked from all 4 walkable neighbors
        ["2,7"]   = true,  -- tile=1; blocked from 3 walkable neighbors (4th is void)
        ["26,25"] = true,  -- tile=6; blocked from 2 walkable neighbors (others are void)
        ["11,26"] = true,  -- tile=6; blocked from all 4 walkable neighbors
        ["23,27"] = true,  -- tile=6; blocked from 3 walkable neighbors
        ["26,27"] = true,  -- tile=6; blocked from 3 walkable neighbors
        -- South-east one-way/trap cell. The 2026-04-26 parked survey reached
        -- (16,23), then all four exits direct-probed as blocked despite open
        -- previews. A follow-up entry probe from (16,24)->UP also blocked after
        -- the earlier route-run move, so keep A* out of this cell entirely.
        ["16,23"] = true,
        -- North-east one-way/trap cell. The 2026-04-26 parked survey reached
        -- (18,17) while routing to Person 1, then split direct probes from a
        -- teleport-normalized start confirmed UP/LEFT/DOWN all block despite
        -- open previews. RIGHT is already a wall tile, so keep A* out entirely.
        ["18,17"] = true,
        -- Superseded 2026-05-14: the older (17,22) trap-cell note was stale.
        -- Manual movement and raw edge verification now prove the east-west
        -- corridor through (17,22) is engine-passable from both sides, so keep
        -- it out of the permanent blocker list.
        -- Weapon-shop service pockets. 2026-05-06 merchant-to-exit auto-walk
        -- first proved the east pocket at (6,4)/(6,5) has no usable exit, then
        -- follow-up routing from (4,4)/(5,5) proved the west/south talk squares
        -- are also sealed by directional walls plus stationary Woman 3 at
        -- (4,7). These cells are engine-enterable and can open the shop when
        -- manually positioned, but autonomous routing must avoid them. Merchant
        -- 2 is handled by a service interaction override that targets the
        -- doorway/counter square at (5,6), facing north.
        ["4,4"] = true,
        ["4,5"] = true,
        ["4,6"] = true,
        ["5,5"] = true,
        ["6,4"] = true,
        ["6,5"] = true,
    },
}

-- ============================================================
-- Per-Map Hazard Cell Overrides
-- ============================================================
-- These cells are engine-walkable but unsafe for autonomous movement.
-- Keep them separate from MAP_BLOCKED_CELLS so logs and diagnostics do not
-- misreport them as walls.
--
-- Format: MAP_HAZARD_CELLS[map_id]["x,y"] = "damage"
local MAP_HAZARD_CELLS = {
    [0x04] = {
        -- 2026-05-05 playtest: stepping from (10,19) to (10,18) took 15 HP
        -- and led directly into the "Thou art dead." sequence. Treat as
        -- pathfinder-forbidden for normal auto-walk/teleport/auto-step use.
        ["10,18"] = "damage",
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
    --   EAST WALL at x=6, y=13-16: directional; y=13 now blocks both horizontal
    --     approaches, while y=14-16 also block both east/west approaches
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
        -- x=6 east wall: y=14-16 confirmed via runtime reroutes 2026-04-08.
        -- y=6-8 and y=10 are full blocks in MAP_BLOCKED_CELLS (not listed here).
        -- y=9 promoted to MAP_BLOCKED_CELLS after direct live retest 2026-04-11:
        --   both (5,9)->(6,9) and (7,9)->(6,9) fail in-engine, so it is not a
        --   usable crossing and should not remain directional-only.
        -- y=11-12: removed speculative entries (never confirmed by runtime blocks).
        -- y=13 revised 2026-04-26: a fresh parked survey and two split direct
        -- probes from (5,13)->(6,13) all blocked despite an open preview. Keep
        -- this as a horizontal seam block together with the east-side repro below.
        ["6,14"] = {east = true, west = true},     -- run7 west added; count=2 retry_successes=2
        ["6,15"] = {east = true, west = true},     -- run7 west added; count=2 retry_successes=2
        ["6,16"] = {east = true, west = true, south = true},  -- run7 west added; count=2 retry_successes=2
        -- y=16 south wall: x=1-4 confirmed via runtime reroutes 2026-04-08.
        -- x=5 not confirmed by any runtime block; removed (was extrapolated).
        ["1,16"] = {south = true},
        ["2,16"] = {south = true},
        -- Reconfirmed 2026-04-19 by direct probing:
        -- east ((5,16)->(4,16)) blocks cleanly; west ((3,16)->(4,16)) blocked
        -- twice on immediate retest; south ((4,17)->(4,16)) moved through the
        -- old modeled block twice. Keep east+west and drop the stale south face.
        ["4,16"] = {east = true, west = true},
        -- x=4 east wall (y=9-16): west wing interior east boundary.
        -- y=9 and y=15-16 previously confirmed; y=10-12 and y=14 confirmed 2026-04-09 via survey_map
        -- (count=5-6 high confidence each, east=true = can't enter from east/move west into cell).
        -- (4,7): east wall confirmed 2026-04-13 (approach=east, auto_step:left from (5,7)).
        -- west=true added 2026-04-26: post-reload direct probe from (3,7) RIGHT
        -- stayed at (3,7), while neighboring reroute-only candidates (3,6 south
        -- and 4,6 north) moved on focused repro and should not be modeled.
        -- south=true added 2026-04-22: probe_edge from (4,8) UP -> status=blocked,
        -- EDGE_PROBE_MODEL_MISMATCH blocked_despite_open_preview. Engine blocks the
        -- northward step from (4,8) into (4,7); model was missing this face.
        -- With south=true, A* bypasses (6,5) [MAP_BLOCKED_CELLS] via the y=4 passthrough strip:
        -- (4,5)→north→(4,4)→east→(5,4)→east→(6,4)→east→(7,4)→east→(8,4)→east wing via y=4.
        -- (4,4),(5,4),(6,4) confirmed 2026-04-22 as engine-walkable decoder gaps.
        -- (8,4) confirmed 2026-04-22 as decoder gap (tile=0); bridges (7,4) to regular floor at (9,4)+.
        -- y=13 reopened 2026-04-18: direct probe from (5,13)->(4,13) moved cleanly,
        -- and once inside, west-side targets regained short valid paths.
        ["4,7"]  = {east = true, west = true, south = true},
        ["4,9"]  = {east = true, north = true},  -- antechamber south door region; confirmed
        ["4,10"] = {east = true},                -- survey run4 count=5 high
        ["4,11"] = {east = true},                -- survey run4 count=5 high
        ["4,12"] = {east = true},                -- survey run4 count=5 high
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
        ["8,9"]  = {east = true, south = true, north = true},  -- count=13, retry_successes=1; north confirmed 2026-04-15 runtime block (auto_step:down from (8,8))
        ["6,11"] = {east = true, west = true},     -- count=6 east; run6 west (oscillation fix)
        ["6,12"] = {east = true, west = true},      -- east: count=1 medium; west: confirmed 2026-04-10 survey pass 8
        -- Reconfirmed by direct seam probes:
        -- (7,13)->(6,13) blocks from the east; fresh 2026-04-26 post-reload
        -- checks also block (5,13)->(6,13) from the west twice and promote the
        -- seam to confirmed_blocked after the survey hit.
        ["6,13"] = {east = true, west = true},
        -- Reconfirmed 2026-04-19 after reload:
        -- (5,13)->(4,13) now blocks cleanly on direct probe, while
        -- (4,13)->(5,13) still moves. Model the west-pocket gate as a one-way
        -- east-approach block without sealing the corridor from inside.
        ["4,13"] = {east = true},
        -- West corridor band (y=16-18, x=9-12):
        -- x=9-12 at y=16 form a north-approach wall extending the y=16 barrier westward.
        ["9,16"]  = {north = true, west = true},   -- count=30
        ["10,16"] = {north = true},                -- count=15
        ["11,16"] = {north = true},                -- count=15
        -- (13,16)->(12,16) blocked twice by direct probe on 2026-04-12 and
        -- also failed during a long Guard 2 survey route, so this cell blocks
        -- east approach in addition to the earlier north-side evidence.
        ["12,16"] = {north = true, east = true},
        -- (15,16): west=true confirmed real (probe_edge:RIGHT from (14,16) blocked 2026-04-21).
        -- south=true restored 2026-04-21: MAP_PASSTHROUGH_CELL (tile=11 but engine-walkable).
        -- All of x=15..20 at y=16 are one-way southward — northward entry blocked by engine.
        -- Only x=13,14 at y=16 are bidirectional (confirmed by probe 2026-04-21).
        ["15,16"] = {west = true, south = true},
        -- (16,16): south=true restored — same one-way southward pattern as (15,16).
        -- east=true was a false positive (probe_edge:LEFT from (17,16) moved freely 2026-04-21).
        ["16,16"] = {south = true},
        -- (17,16): south=true restored — same one-way southward pattern.
        ["17,16"] = {south = true},
        -- (18,16): floor tile (type 4). South=true confirmed real — re-verify probe from
        -- (18,17) UP blocked; northward entry from (18,15) DOWN moved freely (one-way).
        ["18,16"] = {south = true},
        -- (19,16): south=true confirmed real 2026-04-21. Northward entry from (19,15) free.
        ["19,16"] = {south = true},
        -- (20,16) south: blocks north step from (20,17). Confirmed by 10 independent survey
        -- failures in run 4 (2026-04-15). Previously removed as "false positive" after run 2,
        -- but run 4 with the cache-coherence bug fixed still fails consistently. Real block.
        ["20,16"] = {south = true},
        -- (21,17) west: blocks east step from (20,17). Same run-4 evidence (10 failures).
        -- Manual test on session S115 verified (20,17)↔(21,17) but only tested approach
        -- from east (going west). West approach (going east from (20,17)) is engine-blocked.
        -- With (21,18) and (21,19) already full-blocked, east wing is entered via y≤16 only.
        ["21,17"] = {west = true},
        -- 2026-05-14 southeast hall retest: (20,20) is standable and raw probes
        -- crossed north/south/west plus reverse east. Only (20,20)->RIGHT into
        -- (21,20) blocked, so model the west approach to (21,20) one-way.
        ["21,20"] = {west = true},
        -- (7,3) south=true: engine blocks northward entry from (7,4).
        -- Confirmed 2026-04-22 probe_edge:UP from (7,4) → blocked_despite_open_preview.
        -- (7,3) exits south to (7,4) freely; only entry from below is blocked.
        -- East wing is reached via y=4 corridor, not through (7,3).
        ["7,3"]   = {south = true},
        -- x=6 north corridor east-entry blocks (y=1-3): engine walls separating the
        -- King's chamber west section from the main hall. Confirmed 2026-04-22 via
        -- probe_edge:RIGHT from (5,1)/(5,2) → blocked_despite_open_preview (tile=4/6,
        -- both model-open). (6,3) inferred from survey run 2 suspected_tiles and the
        -- consistent x=6 barrier pattern at y=1-3.
        ["6,1"]   = {west = true},
        ["6,2"]   = {west = true},
        ["6,3"]   = {west = true},
        -- (9,3) west=true: engine blocks eastward step from (8,3) into (9,3).
        -- Confirmed 2026-04-21: probe_edge:RIGHT from (8,3) returned status=blocked.
        -- (8,3) is a decoder-gap passthrough cell; this block prevents A* from routing
        -- through the (8,3)→(9,3) wall seam.
        ["9,3"]   = {west = true},
        -- South gate east-wall band follow-up (2026-04-26):
        -- A restarted parked survey after the south-gate door was entered found
        -- repeated queued-route blocks along the castle exit wall. Runtime blocks
        -- were cleared, then split direct probes from each adjacent start all
        -- logged EDGE_PROBE_MODEL_MISMATCH blocked_despite_open_preview.
        ["16,28"] = {south = true},
        -- 2026-05-14 Sage-route follow-up: user reported (17,27)->DOWN
        -- blocked; probe_edge_verify confirmed 5/5 raw holds stayed at
        -- (17,27). Keep (17,28) standable but close the north approach too.
        ["17,28"] = {south = true, north = true},
        -- 2026-05-14 Sage-route follow-up: user reported (18,27)->DOWN
        -- blocked; probe_edge_verify confirmed 5/5 raw holds stayed at
        -- (18,27). Keep (18,28) standable but close the north approach too.
        ["18,28"] = {south = true, north = true},
        -- 2026-05-14 Sage-route follow-up: an earlier verifier had reported
        -- (18,27)->RIGHT passable, but a later clean-state recheck plus a
        -- repeat after clear_input/cleared seam memory both stayed blocked
        -- 5/5. Treat the earlier passable result as contaminated.
        -- (18,26)->RIGHT into (19,26) later showed the same early-twitch
        -- pattern and verified blocked 5/5 twice, so close that west approach
        -- too while keeping the counter stand at (18,26) usable.
        -- (18,25)->RIGHT into (19,25) then verified blocked 5/5 twice after
        -- the return route rerouted north, so close that west approach too.
        ["19,25"] = {west = true},
        ["19,26"] = {west = true},
        ["19,27"] = {west = true},
        ["19,28"] = {south = true},
        ["20,29"] = {west = true},
        -- Throne-room north-entry seams confirmed 2026-04-24 after full Lua reload.
        -- Controlled direct probes from (8,4)/(14,4)/(15,4) UP each blocked 3/3
        -- and logged EDGE_PROBE_MODEL_MISMATCH blocked_despite_open_preview.
        ["8,3"]   = {south = true},
        ["14,3"]  = {south = true},
        -- East-connector reroute wall band follow-up (2026-04-26):
        -- The fresh parked-NPC survey re-learned 17..20,6 north and 21,4/21,5 west
        -- as blocked via queued auto_step. Controlled probe_edge repeated that, but
        -- the first raw held-input pass falsely appeared to split the set. After
        -- full script reload and normalized adjacent-start controls, raw input also
        -- stayed in place for 20,6 north and 21,4/21,5 west. Treat the earlier
        -- "moved" result as contaminated by stale movement/subtile state.
        ["17,6"]  = {north = true},
        ["18,6"]  = {north = true},
        ["19,6"]  = {north = true},
        ["20,6"]  = {north = true},
        ["21,4"]  = {west = true},
        ["21,5"]  = {west = true},
        -- x=15 east-entry: re-confirmed 2026-04-24 via natural walk (teleport
        -- normalization removed as a variable). 90-frame LEFT hold from (17,y)
        -- stopped at (16,y) for y=1,2,3 — engine blocks entry from (16,y)->LEFT.
        -- Earlier "moved" probes were anomalous sub-pixel states from overshoot
        -- movement; natural walk is ground truth.
        ["15,1"]  = {east = true},
        ["15,2"]  = {east = true},
        ["15,3"]  = {east = true, south = true},
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
        ["8,27"]  = {west = true, east = true, south = true}, -- run1 west count=15; east confirmed 2026-04-22 (from (9,27) west step blocked); south from run2
        -- (9,26) south=true added 2026-04-22: probe_edge from (9,27) UP → status=blocked,
        -- EDGE_PROBE_MODEL_MISMATCH blocked_despite_open_preview. Engine blocks northward
        -- entry from (9,27); model had north=true (can't move south from (9,25)) but
        -- was missing the complementary south face.
        ["9,26"]  = {north = true, south = true},           -- run2 north count=2; south confirmed 2026-04-22
        ["9,28"]  = {east = true, south = true, north = true}, -- run2 east/south count=13; north added 2026-04-22 (from (9,27) south step to (9,28) engine-blocked)
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
        -- (12,19) south approach re-confirmed 2026-04-21: 4 blocked events, 0 moved
        -- in fresh survey run 6. Earlier "repeated live probes confirmed open" (2026-04-11)
        -- contradicted by this run. Restoring south=true alongside the existing east=true.
        -- (13,20)->(14,20) failed twice live with no reroute contamination, so
        -- promote that seam to a directional west-side engine block.
        -- (12,24)->(13,24) blocked twice live on 2026-04-12 after runtime
        -- clears. 2026-05-14 raw verifier also confirmed (14,24)->LEFT
        -- into (13,24) blocked 5/5, so keep both horizontal approaches closed.
        ["12,19"] = {east = true, south = true},
        ["13,24"] = {west = true, east = true},
        -- (14,20): north is a wall tile (14,19 in MAP_BLOCKED_CELLS); west/south/east all engine-blocked.
        -- west: (13,20)→(14,20) confirmed 2026-04-14 runtime; south: probe from (14,21) north BLOCKED 2026-04-15;
        -- east: probe from (15,20) west BLOCKED 2026-04-15. Dead-end alcove; unreachable from all live sides.
        ["14,20"] = {west = true, south = true, east = true},
        -- (15,21): east is a wall tile (16,21 in MAP_BLOCKED_CELLS); north+south engine-blocked; west clear.
        -- north: probe from (15,20) south BLOCKED 2026-04-15; south: probe from (15,22) north BLOCKED 2026-04-15.
        -- One-way entry from west only (14,21 → 15,21 passable).
        ["15,21"] = {north = true, south = true},
        -- (12,28): west: run1 count=1 medium; north: auto_step:down from
        -- (12,27) 3/3 retry fail + probe confirm 2026-04-15. South approach
        -- added 2026-05-14 after the castle entrance -> throne-room stair route
        -- repeatedly tried (12,29)->UP; probe_edge_verify confirmed 5/5 blocked.
        ["12,28"] = {west = true, north = true, south = true},
        -- (13,28).south added 2026-05-14 from the same stair-route failure:
        -- (13,29)->UP verified 5/5 blocked after the route rerouted east.
        ["13,28"] = {south = true},
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
        -- NW building west wall (x=3).
        -- 2026-04-27 post-reload survey re-confirmed (2,5)->RIGHT into
        -- (3,5) as blocked five times, including brute-force/manual confirms.
        -- An earlier moved probe was likely a noisy/subtile state and is
        -- outweighed by the clean route-context repro.
        -- NW building top and east walls.
        -- The 2026-04-02 survey repeatedly rerouted into y=3 from the north,
        -- confirming the roofline across x=4-7 in addition to the already
        -- known east wall at x=7.
        -- 2026-05-06 route validation re-confirmed (8,4)->LEFT into (7,4)
        -- is blocked; an earlier moved probe was noisy. Later merchant-to-exit
        -- auto-walk from the shop pocket also confirmed (6,4)->RIGHT into
        -- (7,4), (6,5)->RIGHT into (7,5), (6,5)->LEFT into (5,5), and
        -- (6,4)->UP into (6,3) as blocked after three repeated route attempts.
        -- A follow-up public-side route re-confirmed (8,5)->LEFT into (7,5)
        -- is blocked. Merchant 2 is not reached from the upper `(5,3)` tile;
        -- he is a counter interaction from doorway square (5,6), facing north.
        -- 2026-05-09 parked survey + probe_edge_verify confirmed (5,2)->DOWN
        -- into (5,3) blocks 5/5 despite an open model preview.
        ["4,3"]  = {north = true, south = true},
        ["5,3"]  = {north = true},
        ["6,3"]  = {north = true, south = true},
        ["7,3"]  = {north = true, east = true},
        ["3,4"]  = {west = true, east = true},
        ["3,5"]  = {west = true, east = true},
        ["7,4"]  = {east = true, west = true},
        ["5,5"]  = {east = true},
        ["7,5"]  = {east = true, west = true},
        -- 2026-05-10 selected-NPC teleport repro over-promoted two noisy
        -- throat edges. Manual/live rechecks on 2026-05-11 and 2026-05-12
        -- repeatedly crossed both (5,7)<->(5,8) and (5,7)<->(5,6), so keep
        -- those vertical seams open. The east wall into (6,7) remains modeled.
        ["6,7"]  = {west = true},
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
        ["23,9"] = {north = true, east = true, south = true},
        ["24,9"] = {north = true},
        ["25,9"] = {north = true, west = true},
        ["26,9"] = {north = true, east = true},
        -- 2026-05-13 Old Man 2 / Curse Remover adjacent-cell trap pass:
        -- raw teleport can place the hero on TALK-adjacent cells around
        -- (24,10), but the west and north landings have directional trap
        -- edges. Keep these as directional edges so diagnostics can still
        -- distinguish the engine-enterable cells from ordinary walls, while
        -- selected-object teleport and A* avoid false "back out" routes.
        -- Manual follow-up corrected the noisy south landing: (24,11) and
        -- (24,12) are vertically passable and form the public path to Old
        -- Man 2's TALK stand.
        ["24,8"] = {south = true},
        ["22,10"] = {east = true},
        ["23,10"] = {north = true, west = true},
        -- West-pocket gate into the west-side exit corridor. 2026-05-07
        -- BizHawk playtest: auto-walk from Merchant 2 toward the world-map
        -- exit routed through (5,13)->LEFT, timed out, published
        -- approach=east for (4,13), then rerouted successfully via (5,12).
        -- Keep only this approach blocked; the reroute entered (4,13) from
        -- the north and crossed west normally.
        ["4,13"] = {east = true},
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
        -- 2026-05-07 inn route follow-up: after retargeting the inn to the
        -- public stand tile at (8,21), auto-walk from the town entrance first
        -- planned through (7,17)->RIGHT, timed out on entry to (8,17), then
        -- rerouted cleanly around it and reached the inn.
        ["8,17"]  = {west = true},
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
        -- 2026-04-26 follow-up: direct probes after Guard 4 churn confirmed
        -- (7,25)->RIGHT into (8,25), (7,26)->RIGHT into (8,26), and
        -- (8,25)->DOWN into (8,26) are blocked despite open previews.
        ["5,23"]  = {east = true},
        ["8,25"]  = {east = true, west = true},
        ["8,26"]  = {east = true, north = true, west = true},
        ["3,27"]  = {south = true},
        ["4,27"]  = {south = true},
        ["5,27"]  = {south = true},
        ["6,27"]  = {south = true},
        ["7,27"]  = {south = true},
        -- 2026-04-26 follow-up: the fresh parked survey repeatedly blocked
        -- (8,28)->UP into (8,27). A split direct probe and a 90-frame raw hold
        -- both stayed at (8,28), while the reverse (8,27)->DOWN moved through.
        -- Model only the south approach; leaving the reverse open preserves
        -- the observed one-way behavior.
        ["8,27"]  = {south = true},
        ["9,27"]  = {north = true, south = true},
        -- 2026-04-26 Brecconary survey + split probe correction:
        -- (10,26)->DOWN into (10,27) blocked 13 times including a direct probe.
        -- 2026-04-27 follow-up: normalized teleport probes from (10,28)->UP can
        -- move, but the route-realistic sequence (11,28)->LEFT then (10,28)->UP
        -- blocks, and a 120-frame raw UP hold from that state stays pinned.
        -- Model the south approach so routes avoid this context-sensitive seam.
        ["10,27"] = {north = true, south = true},
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
        -- Merchant 4 lower-west bridge candidate. 2026-05-14 live route
        -- failure plus raw probe_edge_verify from (16,25) confirmed
        -- (16,25)->RIGHT into (17,25) blocked 3/3 with
        -- reason=raw_hold_timeout. Keep (17,25) itself as a passthrough, but
        -- close the west approach so A* stops routing through this seam.
        ["17,25"] = {west = true},
        -- Merchant 4 counter movement seam. The raw large-tile trigger at
        -- (24,25) and the public stand at (23,25) can both open the tool shop
        -- while facing east, but walking across the seam is still blocked:
        -- (24,25)->LEFT blocked 5/5 and the reverse (23,25)->RIGHT also
        -- blocked repeatedly. Keep the movement edge closed while routing
        -- normal shop interaction to the public stand at (23,25) facing east.
        ["23,25"] = {east = true},
        ["24,25"] = {west = true},
        -- After (23,26) was confirmed as a public-side passthrough, the next
        -- eastward seam into (24,26) still blocked 5/5. Keep this directional
        -- so other approaches to (24,26) can be investigated independently.
        ["24,26"] = {west = true},
        -- The interaction tile can be entered from the south, but cannot be exited
        -- back south: (25,27)->UP moved 3/3 into the tool-shop stand at
        -- (25,26), while (25,26)->DOWN blocked 5/5.
        ["25,27"] = {north = true},
        -- The inside row also cannot exit west from Merchant 4's southeast
        -- pocket: validate_path failed immediately at (25,27)->LEFT, then
        -- probe_edge_verify confirmed (25,27)->LEFT blocked 5/5 into (24,27).
        -- After the row-28 bypass was modeled, the next route tried
        -- (24,28)->UP; probe_edge_verify confirmed that south approach to
        -- (24,27) also blocked 5/5 on map 0x08.
        ["24,27"] = {east = true, south = true},
        -- The planner's next invented exit from the same pocket was south into
        -- (25,28); probe_edge_verify confirmed (25,27)->DOWN blocked 5/5.
        -- The later row-28 bypass tried (24,28)->RIGHT into the same cell;
        -- probe_edge_verify confirmed that west approach blocked 5/5 too.
        ["25,28"] = {north = true, west = true},
        -- The bottom-row bypass after the (25,28).west patch tried
        -- (24,28)->DOWN into (24,29); probe_edge_verify confirmed the north
        -- approach blocked 5/5 on map 0x08.
        ["24,29"] = {north = true},
        -- Continuing the same bypass search, the route then tried
        -- (23,28)->DOWN into (23,29); probe_edge_verify confirmed the north
        -- approach blocked 5/5 on map 0x08, with no runtime blocker added.
        ["23,29"] = {north = true},
        -- The next bottom-row bypass tried (22,28)->DOWN into (22,29);
        -- probe_edge_verify confirmed the north approach blocked 5/5 on
        -- map 0x08, again with runtime blockers left empty.
        ["22,29"] = {north = true},
        -- After (27,26) proved passable, the planner tried a lower-right loop.
        -- Live validate_path failed at (28,27)->DOWN, and a direct verifier
        -- attempt blocked on the same edge before cancellation. Later, after
        -- the row-28 west/south exits were modeled, the planner tried
        -- (27,28)->RIGHT into the same cell; repeated manual right taps
        -- blocked and the user confirmed the east exit is engine-blocked.
        ["28,28"] = {north = true, west = true},
        -- Public-route approach toward Merchant 4's southeast pocket. The
        -- user manually verified the vertical x=22 cluster is open from
        -- (22,21) through (22,26)'s north edge, while the south edge out of
        -- (22,26) is hard engine-blocked. Keep only the confirmed south exit
        -- closed here; east/west around this cluster is still unverified.
        ["22,27"] = {north = true},
        -- Return-route retry from the public stand repeatedly failed at
        -- (22,26)->LEFT into (21,26), then manual movement confirmed the same
        -- blocked seam. Keep (21,26) standable, but close its east approach.
        ["21,26"] = {east = true},
        -- Same public-route frontier. The user manually verified
        -- (22,25)->LEFT into (21,25) as hard engine-blocked, and the live log
        -- recorded repeated manual blocks on map 0x08 while leaving runtime
        -- blockers empty. Keep this as a scoped east-approach block.
        ["21,25"] = {east = true},
        -- The next Merchant 4 route candidate tried (23,22)->DOWN into
        -- (23,23). The user manually verified the engine blocks this seam,
        -- matching repeated live manual blocks on map 0x08. Keep it
        -- directional so other approaches to (23,23) can be checked later.
        ["23,23"] = {north = true},
        -- A later validation-only failure at (25,22)->DOWN was manually
        -- disproved: the user crossed from (25,22) into (25,23) repeatedly.
        -- Keep (25,23).north open unless new manual evidence says otherwise.
        -- The next route reached (27,28) cleanly, then failed west into
        -- (26,28). Repeated manual left taps from (27,28) also blocked, and
        -- the user confirmed this is engine-blocked. Keep only the east
        -- approach closed so other approaches to (26,28) stay investigable.
        ["26,28"] = {east = true},
        -- The follow-up detour tried (27,28)->DOWN into (27,29). Validation
        -- and repeated manual down taps blocked there while inspect still said
        -- open, and the user confirmed the south exit is engine-blocked.
        ["27,29"] = {north = true},
        -- After the (20,26) false-wall fix, A* tried to enter (21,27) from
        -- the west. Fresh validation plus probe_edge_verify on 2026-05-12
        -- blocked (20,27)->RIGHT 5/5, while runtime blockers stayed empty.
        ["21,27"] = {west = true},
    },

    -- Map 0x1C: Erdrick's Cave B1
    --
    -- 2026-05-08 first dungeon routes between the corrected B1 stairs at
    -- (9,9) and the entrance. The decoded dungeon tiles are walkable, but
    -- direct probe_edge checks after clearing runtime blocks confirmed these
    -- engine seams block from the listed approaches. Keep these
    -- directional-only so neighboring cells remain available from approaches
    -- that have not failed. Later same-day route evidence showed the newest
    -- single-probe additions were noisy. The 2026-05-08/09 probe_edge_verify
    -- pass then reconfirmed the listed start-choke/east-column approaches with
    -- 5/5 blocked attempts each; mixed verifier results remain unmodeled.
    [0x1C] = {
        ["2,1"] = {west = true, south = true, east = true}, -- west/south/east approaches blocked 5/5
        ["2,3"] = {west = true, north = true}, -- west/north approaches blocked 5/5
        ["3,3"] = {north = true, south = true}, -- (3,2)->DOWN and (3,4)->UP blocked
        ["4,1"] = {south = true}, -- (4,2)->UP blocked 5/5 by probe_edge_verify
        ["4,3"] = {north = true, south = true, east = true}, -- north/south/east approaches blocked 5/5
        ["5,1"] = {south = true, east = true}, -- south/east approaches blocked 5/5
        ["2,4"] = {east = true, west = true}, -- (3,4)->LEFT and (1,4)->RIGHT blocked
        ["1,5"] = {north = true, south = true}, -- north/south approaches blocked 5/5
        ["2,5"] = {south = true}, -- (2,6)->UP blocked 5/5 by probe_edge_verify
        ["3,5"] = {north = true, south = true}, -- north/south approaches blocked 5/5
        ["4,5"] = {north = true, east = true, south = true}, -- north/east/south approaches blocked 5/5
        ["7,2"] = {west = true, north = true},  -- west/north approaches blocked 5/5
        ["8,2"] = {south = true, east = true}, -- south/east approaches blocked 5/5
        ["7,3"] = {south = true, east = true}, -- south/east approaches blocked 5/5
        ["6,3"] = {north = true}, -- (6,2)->DOWN blocked
        ["6,4"] = {west = true, south = true, east = true}, -- west/south/east approaches blocked 5/5
        ["6,6"] = {west = true, north = true, east = true}, -- west/north/east approaches blocked 5/5
        ["6,7"] = {east = true}, -- (7,7)->LEFT blocked 5/5 by probe_edge_verify
        ["8,5"] = {west = true}, -- (7,5)->RIGHT blocked 5/5 by probe_edge_verify
        ["9,5"] = {south = true}, -- (9,6)->UP blocked 5/5 by probe_edge_verify
        ["8,6"] = {west = true, south = true, east = true}, -- west/south/east approaches blocked 5/5
        ["5,7"] = {north = true, south = true, west = true}, -- north/south/west approaches blocked 5/5
        ["8,8"] = {west = true, north = true, east = true}, -- west/north/east approaches blocked
        ["8,9"] = {west = true, east = true},  -- west/east approaches blocked 5/5
    },

    -- Map 0x1D: Erdrick's Cave B2
    --
    -- 2026-05-10 first chest-route pass. B2 had no permanent seam model, so
    -- auto-walk kept rediscovering hidden one-way maze walls while routing
    -- toward the chest at (9,3). Only direct probe_edge_verify 5/5 blocked
    -- consensus is promoted here; mixed first-pass results stayed runtime-only
    -- until a later direct verifier pass confirmed them cleanly. Later natural
    -- route failures promoted repeated queued-route plus seam-retry blockers
    -- when the graph also identified the missing passthrough route.
    [0x1D] = {
        ["1,1"] = {north = true, south = true, west = true}, -- north/west blocked after top-edge route; south blocked 15/15
        ["2,1"] = {north = true, south = true}, -- north blocked from (2,0); south route-blocked 4/4
        ["3,1"] = {north = true, south = true}, -- north blocked from (3,0); south route-blocked 4/4
        ["4,1"] = {north = true, south = true}, -- north blocked from (4,0); south route-blocked 4/4
        ["1,3"] = {south = true}, -- (1,4)->UP blocked 5/5 after left-edge route opened
        ["2,3"] = {south = true, east = true}, -- south 5/5; (3,3)->LEFT route-blocked 2/2
        ["4,3"] = {west = true, north = true}, -- west 5/5; (4,2)->DOWN route-blocked 4/4
        ["4,4"] = {east = true, west = true}, -- east 5/5; (3,4)->RIGHT route-blocked 4/4
        ["5,1"] = {north = true, east = true}, -- north blocked from (5,0); reverse route (6,1)->LEFT blocked 10/10
        ["5,2"] = {east = true, west = true}, -- east 10/10; (4,2)->RIGHT route-blocked 4/4
        ["5,3"] = {south = true, east = true}, -- (5,4)->UP blocked 5/5; reverse route (6,3)->LEFT blocked 10/10
        ["3,5"] = {south = true, north = true, west = true}, -- south 5/5; north/west route-blocked 4/4
        ["4,5"] = {east = true}, -- (5,5)->LEFT blocked 5/5
        ["1,5"] = {west = true}, -- (0,5)->RIGHT route-blocked 2/2 after left-edge loop
        ["6,4"] = {west = true, north = true}, -- (5,4)->RIGHT blocked 5/5; reverse route (6,3)->DOWN blocked 10/10
        ["6,5"] = {east = true, south = true, west = true}, -- (7,5)->LEFT, (6,6)->UP, and (5,5)->RIGHT blocked 5/5
        ["4,6"] = {east = true, west = true}, -- (5,6)->LEFT and (3,6)->RIGHT blocked 5/5
        ["4,7"] = {south = true, west = true}, -- (4,8)->UP and (3,7)->RIGHT blocked 5/5 after fresh recheck
        ["5,7"] = {north = true, east = true}, -- (5,6)->DOWN and (6,7)->LEFT blocked 5/5
        ["7,7"] = {north = true}, -- (7,6)->DOWN blocked 5/5
        ["7,4"] = {south = true, north = true, east = true}, -- (7,5)->UP, (7,3)->DOWN, and (8,4)->LEFT blocked after verifier consensus
        ["8,5"] = {west = true, south = true, north = true}, -- (7,5)->RIGHT, (8,6)->UP, and (8,4)->DOWN blocked after verifier consensus
        ["9,5"] = {south = true, north = true}, -- (9,6)->UP raw-hold blocked; reverse route (9,4)->DOWN blocked 10/10
        ["1,6"] = {south = true}, -- (1,7)->UP blocked 5/5
        ["2,6"] = {south = true, east = true}, -- (2,7)->UP blocked 5/5; (3,6)->LEFT blocked 10/10 after real reload
        ["8,7"] = {south = true, north = true, east = true}, -- (8,8)->UP, (8,6)->DOWN, and (9,7)->LEFT blocked 5/5
        ["5,8"] = {south = true, east = true, west = true}, -- (5,9)->UP, (6,8)->LEFT, and (4,8)->RIGHT blocked 5/5
        ["7,8"] = {west = true, east = true}, -- (6,8)->RIGHT and (8,8)->LEFT blocked 5/5
        ["7,9"] = {east = true}, -- (8,9)->LEFT blocked by route-shaped raw walk and fresh 15/15 verifier
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

    local passthroughs = MAP_PASSTHROUGH_CELLS[map_id]
    if passthroughs and passthroughs[key] then
        details.base_walkable = true
        details.effective_walkable = true
        details.reason = "passthrough"
        return details
    end

    if not maps.is_overworld(map_id) and (x == 0 or y == 0) then
        details.base_walkable = false
        details.effective_walkable = false
        details.reason = "engine_boundary"
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

function M.is_hazard_cell(map_id, x, y)
    local hazards = MAP_HAZARD_CELLS[map_id]
    return hazards and hazards[x .. "," .. y] or false
end

function M.get_walkability_details(map_id, x, y)
    local details = lookup_walkability_base(map_id, x, y)
    if not details then return nil end
    details.hazard = M.is_hazard_cell(map_id, x, y) or false
    details.permanent_blocked = M.is_permanently_blocked_override(map_id, x, y) and true or false
    if details.hazard then
        details.effective_walkable = false
        details.reason = "hazard"
    elseif details.permanent_blocked then
        details.effective_walkable = false
        details.reason = "permanent_blocked"
    end
    return details
end

local function build_open_door_set()
    local opened = {}
    for i = 0, addr.DOOR_ARRAY_MAX - 1 do
        local dx = memory.readbyte(addr.DOOR_X_POS_START + i * addr.DOOR_ARRAY_STRIDE)
        local dy = memory.readbyte(addr.DOOR_Y_POS_START + i * addr.DOOR_ARRAY_STRIDE)
        if dx ~= 0 then
            opened[dx .. "," .. dy] = true
        end
    end
    return opened
end

function M.get_walkability_snapshot(map_id)
    local grid = M.get_tile_grid(map_id)
    if not grid then return nil end

    local meta = M.get_metadata(map_id)
    if not meta then return nil end

    local walkable_table = M.get_walkability_table(map_id)
    if not walkable_table then return nil end

    local snapshot = {}
    local is_overworld = maps.is_overworld(map_id)
    local passthroughs = MAP_PASSTHROUGH_CELLS[map_id]
    local door_cells = MAP_DOOR_CELLS[map_id]
    local open_doors = door_cells and build_open_door_set() or nil
    local overrides = MAP_BLOCKED_CELLS[map_id]
    local hazards = MAP_HAZARD_CELLS[map_id]

    for y = 0, meta.height - 1 do
        local row = {}
        snapshot[y] = row
        for x = 0, meta.width - 1 do
            local key = x .. "," .. y
            local walkable = false
            if passthroughs and passthroughs[key] then
                walkable = true
            elseif not is_overworld and (x == 0 or y == 0) then
                walkable = false
            elseif door_cells and door_cells[key] then
                local dc = door_cells[key]
                walkable = open_doors and open_doors[dc.x .. "," .. dc.y] == true or false
            else
                local tile_type = grid[y] and grid[y][x]
                walkable = tile_type ~= nil and walkable_table[tile_type] == true or false
            end
            if overrides and overrides[key] then
                walkable = false
            end
            if hazards and hazards[key] then
                walkable = false
            end
            row[x] = walkable
        end
    end

    return snapshot
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
