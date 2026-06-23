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
        -- 2026-05-23 focused crawler from the Sun Shrine forward-route
        -- boundary exported (14,14), and probe_edge_verify:14,15,UP,5 moved
        -- into it 6/6 including the stability recheck.
        ["14,14"] = true,
        ["15,4"] = true,
        ["15,5"] = true,
        -- 2026-05-24 west-pocket continuation uncovered a hidden vertical
        -- decoder-gap alcove above `(16,15)`: direct current-position probes
        -- moved `(16,15)->UP` through tile-0 `(16,14)` and settled at
        -- `(16,13)`, while `(16,13)->DOWN` moved back out to `(16,15)`.
        ["16,13"] = true,
        ["16,14"] = true,
        -- 2026-05-23 forward Sun Shrine route: x=15 was mixed and x=16 was
        -- blocked, but probe_edge_verify:14,5,DOWN,5 moved into (14,6) 6/6.
        -- Forced-origin probes then exited down to (14,7) and back up.
        ["14,6"] = true,
        -- 2026-05-23 door-side Sun Shrine route: with the Magic Key Area Door
        -- open, probe_edge_verify:21,8,RIGHT,5 entered (22,8) 6/6 despite
        -- tile=0, and a forced-origin follow-up moved (22,8)->DOWN into
        -- (22,9). This is the hidden top-right exterior strip connector.
        ["22,8"] = true,
        -- Follow-up after (22,8)->DOWN was proven blocked: the same exterior
        -- strip continues east across tile-0 cells. Direct/raw probes moved
        -- (22,8)->(23,8), forced (23,8)->(24,8), (24,8)->(25,8),
        -- forced (25,8)->(26,8), then (26,8)->DOWN into normal floor (26,9).
        ["23,8"] = true,
        ["24,8"] = true,
        ["25,8"] = true,
        ["26,8"] = true,
        -- 2026-05-25 hidden-bridge frontier follow-up: with the route split
        -- between the normal castle side and the southeast x=29 lane,
        -- probe_edge_verify:29,7,DOWN,5 moved into tile-0 (29,8) 6/6
        -- including the stability recheck. This opens the proven vertical
        -- strip toward (29,9) without reopening the guarded west entries into
        -- the world-map transition cells.
        ["29,8"] = true,
        -- 2026-05-23 Sun Shrine forward route: user manual play found the
        -- x=25 north/south descent. Direct probe_edge_verify:25,10,DOWN,5
        -- entered (25,11) 6/6 despite tile=0, and a force-positioned raw probe
        -- from (25,11)->DOWN entered ordinary floor at (25,12).
        ["25,11"] = true,
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
        -- South gate exit tile. Live FCEUX validation on 2026-05-25 showed
        -- queued movement from the south gate row can settle on tile-0
        -- `(11,29)`, and pathfinding from that tile reaches the open
        -- Magic Key Merchant route via `(11,28)`. Keep the surrounding
        -- verified south-gate wall blockers intact; this opens only the
        -- standable exit cell itself.
        ["11,29"] = true,
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

    -- Map 0x09: Garinham
    -- Tool Merchant return-route pocket. The ROM decodes (2,13) as type-2
    -- wall, but a 2026-05-14 verifier moved (2,12)->DOWN into it 5/5 times.
    -- Keep this scoped to confirmed seams; nearby false exits are handled by
    -- directional blockers below. A 2026-06-19 `sweep_walk` then crossed the
    -- adjacent `(3,13)` type-2 wall from east, west, and south. Follow-up
    -- non-teleport same-origin probes from walked origins `(4,13)->LEFT` and
    -- `(2,13)->RIGHT` both entered `(3,13)` and carried through it. A later
    -- door-pocket frontier check proved `(1,13)` is also standable from east,
    -- west, and south, but its north exit into `(1,12)` blocks below.
    [0x09] = {
        ["1,13"] = true,
        ["2,13"] = true,
        ["3,13"] = true,
        -- Garin's Grave "wall of darkness" entrance. Guide clue says to push
        -- into the dark wall three tiles east of the west wall; live
        -- probe_edge_verify from (3,4)->UP moved into this ROM-wall tile 6/6
        -- after a stability recheck.
        ["3,3"] = true,
        -- Top-edge hidden lane. Live probe_edge from (18,1)->UP moved into
        -- (18,0), then (18,0)->UP changed to 0x01 World Map, not Garin's
        -- Grave B1. Keep the standable edge cell open.
        ["18,0"] = true,
        -- The old lower hidden-bridge candidate at (19,10) came from
        -- teleport-backed verifier proof. A 2026-06-17 same-origin inn-return
        -- route plus direct probe from (19,11)->UP blocked repeatedly, so keep
        -- that wall closed unless a fresh walked route proves another approach.
        -- Lower west passage. A 2026-06-19 `sweep_walk` reached `(4,17)` by
        -- normal movement, then moved `(4,17)->LEFT` into this type-11 wall
        -- cell and backtracked out. Fresh same-origin `probe_edge` checks
        -- after reload reproduced `(4,17)->LEFT` and `(3,17)->RIGHT`.
        ["3,17"] = true,
        -- ROM stair-down table entry 0xF411 is `09 13 00`; live STAIRS from
        -- this top-right boundary tile changed to map 0x18 / Garin's Grave B1.
        ["19,0"] = true,
    },

    -- Map 0x0B: Rimuldar
    -- Magic Key shop north/water-edge approach. The route from the east side
    -- reaches the weapon-shop stand at (24,7); live edge probing moved
    -- (24,7)->UP into (24,6) even though the ROM decodes (24,6) as tile 0.
    -- Once north of this bridge, the existing grid routes cleanly west to
    -- Old Man 1's Magic Key shop stand at (4,6).
    --
    -- The entrance-to-key-shop route also needs the x=19 hidden connector:
    -- 2026-05-17 raw probes moved (19,10)->UP into (19,9) 3/3, then
    -- (19,9)->UP into (19,8), and (18,9)->RIGHT into (19,9) 3/3 even though
    -- (19,9) decodes as tile 15. This is the actual bridge around the
    -- false north pocket near (24,9).
    --
    -- After that bridge, the route crosses row 8 at (14,8): (14,9)->UP
    -- verified 3/3 into this tile, and live position then continued to the
    -- row-7 lane with both (14,8)->UP and (14,8)->DOWN inspecting open.
    -- Neighboring (15,8) also moved but is occupied by Woman 3, so keep the
    -- public route on the clean (14,8) connector.
    --
    -- The northwest key-shop search exposed (2,7) as a standable hidden cell,
    -- but later route-shaped evidence superseded the early west-entry probe:
    -- repeated attempts from (1,7)->RIGHT into (2,7) blocked cleanly. Keep
    -- (2,7) as passable for non-west approaches, and close its west approach
    -- in MAP_DIRECTIONAL_BLOCKS below.
    --
    -- (14,9)->LEFT into (13,9) verified 3/3, then a forced current-position
    -- probe moved (13,9)->UP into (13,8); held movement continued to (13,7).
    -- The earlier x=1 strip is also engine-passable, but the later route
    -- found one-way walls before it can reach the key counter.
    --
    -- The next hidden turn in the one-way maze is at (16,8). After the
    -- row-10 north entries at x=13..17 proved blocked, live raw-hold probes
    -- found the valid entrance-side route: (18,10)->UP into (18,9), west to
    -- (16,9), then (16,9)->UP into hidden (16,8) and onward to row 7 before
    -- dropping back through (14,8)/(14,9) toward the key counter.
    --
    -- The final key-counter maze turns through the upper one-way lane:
    -- (7,3)->LEFT into (6,3) verified 3/3 passable even though (6,3)
    -- decodes as tile 0, and the held move continued through to (5,3).
    -- From there, live seam observations moved (5,3)->DOWN into (5,4),
    -- (5,4)->DOWN into (5,5), (5,5)->LEFT into (4,5), and
    -- (4,5)->DOWN into the public key-shop stand at (4,6).
    --
    -- A later return-side pass showed the lower escape strip is also real:
    -- the user crossed down through the key-shop lane, including the
    -- one-way-looking (4,8)->DOWN into (4,9), and local ROM-backed A* needs
    -- (4,7)..(4,9) open to reconnect the stand to the exit route after the
    -- upper row-6 false drops were sealed.
    --
    -- The next loop pass sealed both exits from (3,11), which means the
    -- return route must leave the key seller by the lower hidden lane instead
    -- of dropping into that dead pocket. Live proof moved (4,7)->RIGHT into
    -- (5,7) in 2/3 raw attempts, earlier user movement stepped through the
    -- (6,7)/(6,8)/(6,9) column, and route-shaped A* reconnects through
    -- (7,9)->(7,10) once those false-wall cells are exposed.
    --
    -- Follow-up testing showed (5,7) itself is a tiny one-way pocket east of
    -- the key merchant, so the return route should not use it. The inbound
    -- route instead needs the south-side hidden turn: live manual movement
    -- walked (13,15)->DOWN into false-wall (13,16), then continued through
    -- row 17 toward the proven west/key-shop lane. Once the false entry into
    -- (7,10) was sealed, the return route needed the adjacent live-walked
    -- connector (8,9): manual movement crossed (7,9)<->(8,9) twice. The
    -- next noisy manual pass also stepped through false-wall cells on the west
    -- pocket and upper return route: (1,14)->(2,14)->(3,14), (4,14)/(5,14),
    -- (8,7)/(8,8), and (14,5). The later route simulation uses the row-14
    -- cells as the shorter entrance/recovery corridor after new false exits
    -- around rows 8, 11, and 16 are sealed.
    --
    -- The next manual return-side probe exposed the upper false-wall exit
    -- lane: (3,5)->UP moved into (3,4), and the player was able to stand on
    -- false-wall (4,3) before pressing north and changing to the world map.
    -- Model (4,3) as the northwest exit stand, but block the edge into (4,2)
    -- below so ordinary in-town paths do not route through the map transition.
    --
    -- The next FCEUX pass added more manually walked false-wall cells while
    -- chasing the Magic Key counter and return route. (1,13), (1,5), and
    -- (3,9) are recovery/approach pockets on the west side; (15,5) is the
    -- upper return connector that keeps the east-exit route open after
    -- (14,5)->DOWN into (14,6) proved blocked.
    --
    -- After the (5,15) south/east exits were confirmed blocked, the nearest
    -- component bridge was (1,12): (1,13)->UP into it moved 4/5, and
    -- (1,11)->DOWN into it moved 5/5. A local ROM-backed route simulation with
    -- only this passthrough added reconnects (5,15) to the key stand at (4,6).
    -- That first route still used the noisy (1,7)->RIGHT into (2,7) connector,
    -- and the latest focused route evidence now closes that west entry. The
    -- next probe batch exposed an alternate one-way bridge candidate through
    -- (3,8), but later route-shaped evidence superseded the noisy/manual
    -- north-entry proof: (3,9)->UP into (3,8) blocked repeatedly under queued
    -- route plus seam retries. The reverse target-side entry from
    -- (4,8)->LEFT also blocked 5/5, so (3,8) remains a standable hidden cell
    -- but has blocked south and east approaches. Do not expose (2,13) yet:
    -- (2,14)->UP moved 5/5, but (3,13)->LEFT into it blocked 5/5 and
    -- (1,13)->RIGHT was mixed.
    --
    -- After (2,7).west closed, the next frontier pass found another real
    -- false-wall tile on the lower lane: (4,9)->RIGHT into (5,9) verified
    -- 5/5 passable. The candidate north break from (5,9) into (5,8) then
    -- blocked from a forced origin, so (5,9) is useful as lane data but is
    -- not the missing key-counter bridge. The later (2,5) lead was a stale /
    -- noisy bridge too: fresh route and probe evidence block westward entry
    -- from (1,5). A clean post-recovery edge verifier later corrected the
    -- last west-side candidate: (1,8)->RIGHT into (2,8) moved 5/5, and a raw
    -- forced-origin reverse probe from (2,8)->LEFT also moved. This makes
    -- (2,8) the missing standable false-wall connector into the (3,8)->(3,7)
    -- turn; keep the lower south approach from (2,9) blocked directionally.
    -- The corrected town-tileset route then reached the row-10 frontier, where
    -- (9,10)->LEFT into (8,10) reconfirmed blocked 5/5 but (9,10)->UP into
    -- (9,9) moved 5/5. Expose only (9,9) here; keep (8,10).east closed.
    --
    -- The post-merchant NPC walkabout found Old Man 3's west-side access seam:
    -- the player moved (2,23)->LEFT into false-wall (1,23) twice, then moved
    -- (1,23)->RIGHT into false-wall (2,23). Expose both cells so the public
    -- route can stand at (2,23) facing east for Old Man 3's temple clue.
    --
    -- South-side false-wall connector: live FCEUX movement proved
    -- (13,19)->UP moves into false-wall (13,18) and continues to the
    -- public-side row, while the reverse route moves back down through
    -- (13,18) to (13,19). Nearby row-18 shelf cells at (22,18)..(24,18)
    -- are real but dead-ended north/east/west in follow-up probes. Later
    -- locked-room bashing showed this connector is not currently reachable
    -- from the opened Wings door pocket at (23,23); do not treat it as a
    -- solved walk-out route from that pocket.
    -- The forward entrance-to-Wings route later found the clean public-side
    -- approach into that shelf: direct probe_edge_verify:23,17,DOWN,5 moved
    -- into (23,18) 5/5. The south approach from (23,19)->UP stayed mixed, so
    -- keep this as a passthrough cell rather than changing directional blocks.
    -- Later chest-room bashing found a separate row-22 false-wall shelf:
    -- (24,23)->UP entered (24,22), (24,22)->LEFT entered (23,22) repeatedly,
    -- and (23,22)->RIGHT returned to (24,22). Expose only those live-proven
    -- shelf cells; the top and lower exits are handled directionally below.
    -- More locked-room probing showed the row-22 branch is real but currently
    -- dead-ended: (22,23)->UP moved into (22,22), then (22,22)->LEFT moved
    -- into (21,22), but the north/west exits loop into known blockers.
    -- The lower row-25 hidden strip is also real: forced-origin
    -- (21,24)->DOWN moved to (21,25), (20,25)->LEFT verified passable 5/5
    -- into (19,25), and forced-origin (19,25)->LEFT moved into (18,25).
    -- However, the apparent (21,23)->DOWN throat is not usable from the
    -- door-side approach; keep its north entry blocked directionally below.
    -- Entrance-to-Weapons follow-up: once (21,8).west was sealed, the
    -- planner needed the east x=29 hidden north strip. Verified
    -- (29,13)->UP into (29,12) moved 5/5, then forced raw probes moved
    -- (29,12)->UP, (29,11)->UP, (29,10)->UP, and (29,9)->UP cleanly 5/5
    -- each. (29,8) is ordinary floor, so no passthrough is needed there.
    [0x0B] = {
        ["1,5"] = true,
        ["1,7"] = true,
        ["1,8"] = true,
        ["1,12"] = true,
        ["1,13"] = true,
        ["1,14"] = true,
        ["1,23"] = true,
        ["2,5"] = true,
        ["2,7"] = true,
        ["2,8"] = true,
        ["2,14"] = true,
        ["2,23"] = true,
        ["3,4"] = true,
        ["3,5"] = true,
        ["3,7"] = true,
        ["3,8"] = true,
        ["3,9"] = true,
        ["3,14"] = true,
        ["4,3"] = true,
        ["4,5"] = true,
        ["4,14"] = true,
        ["4,7"] = true,
        ["4,8"] = true,
        ["4,9"] = true,
        ["5,3"] = true,
        ["5,5"] = true,
        ["5,7"] = true,
        ["5,9"] = true,
        ["5,14"] = true,
        ["6,3"] = true,
        ["6,7"] = true,
        ["6,8"] = true,
        ["6,9"] = true,
        ["7,9"] = true,
        ["8,7"] = true,
        ["8,8"] = true,
        ["8,9"] = true,
        ["9,9"] = true,
        -- 2026-05-21 frontier-crawler follow-up after the x=12 regression
        -- rerun: `(11,17)->UP` into `(11,16)` moved 5/5, and five forced raw
        -- probes from `(11,16)->UP` into `(11,15)` all moved cleanly.
        ["11,15"] = true,
        ["11,16"] = true,
        -- 2026-05-21 post-reload frontier-crawler run: after the crawler
        -- correctly treated (13,1) as an unstable north-edge frontier and
        -- backtracked to (13,2), direct verifiers confirmed this adjacent
        -- x=12 strip: (13,2)->LEFT, (12,7)->DOWN, (12,10)->UP, and
        -- (12,10)->DOWN each moved 5/5.
        -- A later regression pass from (13,20) extended the same live-proven
        -- x=12 column farther south: direct verifiers confirmed
        -- (12,14)->DOWN into (12,15), (12,17)->UP into (12,16), and
        -- (12,17)->DOWN into (12,18) 5/5. Keep `(12,20)` review-only for now;
        -- its first verifier came back mixed.
        ["12,2"] = true,
        ["12,8"] = true,
        ["12,9"] = true,
        ["12,11"] = true,
        ["12,15"] = true,
        ["12,16"] = true,
        ["12,18"] = true,
        -- 2026-05-21 frontier-crawler/verifier follow-up from the Rimuldar
        -- west-side vertical strip: (13,5)->UP into (13,4) and
        -- (13,3)->UP into (13,2) each moved 5/5. Do not promote (13,1)
        -- yet; it behaves like an unstable north-edge frontier and can settle
        -- at (13,0) after raw probes.
        ["13,2"] = true,
        ["13,4"] = true,
        ["13,8"] = true,
        ["13,9"] = true,
        ["13,15"] = true,
        ["13,16"] = true,
        ["13,18"] = true,
        -- 2026-05-20 FCEUX: (13,21)->UP into (13,20) moved 5/5, and a
        -- force-origin raw probe from (13,20)->UP moved into (13,19).
        ["13,20"] = true,
        -- 2026-05-20 FCEUX raw probe: (14,16)->RIGHT moved into (15,16)
        -- while both cells decoded as blocked false-wall tiles.
        ["14,16"] = true,
        ["15,16"] = true,
        ["14,5"] = true,
        ["14,8"] = true,
        ["15,5"] = true,
        ["16,8"] = true,
        ["18,25"] = true,
        ["19,9"] = true,
        ["19,25"] = true,
        ["21,22"] = true,
        ["21,24"] = true,
        ["22,22"] = true,
        ["23,22"] = true,
        ["23,18"] = true,
        ["24,6"] = true,
        ["24,22"] = true,
        -- 2026-05-21 frontier-crawler follow-up: direct verifiers confirmed
        -- (29,1)->DOWN into (29,2), (29,5)->UP into (29,4),
        -- (29,5)->DOWN into (29,6), and (29,8)->UP into (29,7) 5/5.
        -- (29,3) is the chained strip cell: force-origin raw probes moved
        -- into it from both (29,2)->DOWN and (29,4)->UP. Recheck with
        -- probe_edge_verify after these passthroughs are live if needed.
        -- The forced-start upper-strip crawl later exported (28,2), and
        -- probe_edge_verify:29,2,LEFT,5 reconfirmed the east entry 5/5 with
        -- no drift, timeout, or map change.
        -- The next west-advanced frontier pass from (28,2) confirmed
        -- (28,2)->DOWN into (28,3), (28,5)->UP into (28,4), and
        -- (28,5)->DOWN into (28,6) 5/5. After reloading those live,
        -- probe_edge_verify:DOWN,5 from (28,6) also moved into (28,7) 5/5
        -- with no drift, timeout, or map change.
        -- The next post-reload frontier pass starting from (28,7) advanced
        -- one column farther west. `probe_edge_verify:LEFT,5` from (28,2)
        -- confirmed `(27,2)` passable 5/5, and five forced raw
        -- `probe_edge:DOWN` checks from `(27,2)` consistently moved into
        -- `(27,3)`.
        -- The following pass from `(27,3)` continued the strip into x=26/x=25:
        -- `probe_edge_verify:LEFT,5` from `(27,2)` confirmed `(26,2)` 5/5,
        -- then five forced raw probes each confirmed `(26,2)->DOWN` into
        -- `(26,3)`, `(26,3)->LEFT` into `(25,3)`, and `(25,3)->UP` into
        -- `(25,2)`.
        -- The next post-reload crawl from `(25,3)` kept extending the same
        -- hidden run westward: repeated moved edges proved `(24,2)`, `(24,3)`,
        -- and even the tile-type-2 cell `(24,4)` are traversable, with the
        -- crawler then continuing onward through `(24,5)` and the already
        -- modeled `(24,6)` bridge.
        ["24,2"] = true,
        ["24,3"] = true,
        ["24,4"] = true,
        ["25,2"] = true,
        ["25,3"] = true,
        ["26,2"] = true,
        ["26,3"] = true,
        ["27,2"] = true,
        ["27,3"] = true,
        ["28,2"] = true,
        ["28,3"] = true,
        ["28,4"] = true,
        ["28,6"] = true,
        ["28,7"] = true,
        ["29,2"] = true,
        ["29,3"] = true,
        ["29,4"] = true,
        ["29,6"] = true,
        ["29,7"] = true,
        ["29,9"] = true,
        ["29,10"] = true,
        ["29,11"] = true,
        ["29,12"] = true,
    },

    -- Map 0x07: Kol
    -- South entrance/exit false-wall strip. Live arrival from the world map
    -- lands at (19,23), and manual movement from (19,22)->DOWN moved into
    -- (19,23). A second DOWN from (19,23) exited town. Adjacent bottom-edge
    -- cells also moved live: (20,23) from the west during service setup and
    -- (18,23) as the player's current pathability-filter start tile. These
    -- ROM-decode as type-0 walls, so expose only the confirmed strip cells as
    -- passthroughs.
    [0x07] = {
        ["18,23"] = true,
        ["19,23"] = true,
        ["20,23"] = true,
    },

    -- Map 0x0C: Sun Shrine / Stones of Sunlight chamber.
    -- The player lands live on (0,2), the return stairs are the west-edge
    -- object at (0,4), and manual movement proved (1,7)->LEFT reaches (0,7).
    -- The generic interior boundary rule would otherwise isolate these cells.
    [0x0C] = {
        ["0,2"] = true,
        ["0,4"] = true,
        ["0,7"] = true,
    },

    -- Map 0x15: Swamp Cave north-south west-edge corridor.
    -- The generic dungeon edge rule marks x=0 as a boundary, but live play on
    -- 2026-05-16 walked the x=0 corridor in both directions. The proven
    -- corridor bend at (0,25): repeated south attempts from there did not
    -- complete a tile step. The south-island exit is a separate west-edge
    -- cell at (0,29), identified from the ROM up-stair table entry
    -- 15 00 1D at file offset 0xF486 and reached from row 29.
    -- A later route from the island exit back to the original entrance proved
    -- (0,28) passable from the south/east side. Keep (0,26)..(0,27) closed
    -- until live movement proves otherwise.
    -- The 2026-06-22 reverse South Stairs route walked the middle strip
    -- `(2,16)..(2,18)` while returning to the Gwaelin door stand; these decode
    -- blocked but are standable from the vertical route.
    [0x15] = {
        ["0,0"] = true,
        ["0,1"] = true,
        ["0,2"] = true,
        ["0,3"] = true,
        ["0,4"] = true,
        ["0,5"] = true,
        ["0,6"] = true,
        ["0,7"] = true,
        ["0,8"] = true,
        ["0,9"] = true,
        ["0,10"] = true,
        ["0,11"] = true,
        ["0,12"] = true,
        ["0,13"] = true,
        ["0,14"] = true,
        ["0,15"] = true,
        ["0,16"] = true,
        ["0,17"] = true,
        ["0,18"] = true,
        ["0,19"] = true,
        ["0,20"] = true,
        ["0,21"] = true,
        ["0,22"] = true,
        ["0,23"] = true,
        ["0,24"] = true,
        ["0,25"] = true,
        ["0,28"] = true,
        ["0,29"] = true,
        ["2,16"] = true,
        ["2,17"] = true,
        ["2,18"] = true,
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

    -- Map 0x18: Garin's Grave B1 northeast treasure row.
    -- The generic dungeon edge rule marks y=0 as an engine boundary, but live
    -- B1 testing showed the treasure row itself is standable: the hero started
    -- on `(11,0)` and SEARCH reported a treasure box, forced teleport to
    -- `(12,0)` held stable and SEARCH reported a treasure box, and forced
    -- teleport to `(13,0)` held stable through the teleport guard. Moving north
    -- past this row can still leave the map, so keep this scoped to the three
    -- ROM chest cells.
    [0x18] = {
        ["11,0"] = true,
        ["12,0"] = true,
        ["13,0"] = true,
    },

    -- Map 0x19: Garin's Grave B2 northwest escape strip.
    -- The B3 west chest return route comes back to the B2 northwest landing.
    -- Live FCEUX movement on 2026-06-16 first proved `(1,2)->LEFT` enters
    -- decoded boundary cell `(0,2)` and the strip continues down through
    -- `(0,11)`. A follow-up from the stair cell proved `(1,1)<->(0,1)` and
    -- `(0,1)->DOWN` into `(0,2)` too. `(0,11)->RIGHT` exits to `(1,11)`, while
    -- `(0,11)->DOWN` is blocked/out of bounds. Keep this to the direct escape
    -- cells; unrelated B2 stair-hub reachability should still be proven route
    -- by route.
    [0x19] = {
        ["0,1"] = true,
        ["0,2"] = true,
        ["0,3"] = true,
        ["0,4"] = true,
        ["0,5"] = true,
        ["0,6"] = true,
        ["0,7"] = true,
        ["0,8"] = true,
        ["0,9"] = true,
        ["0,10"] = true,
        ["0,11"] = true,
    },

    -- Map 0x1A: Garin's Grave B3 hidden bridge/top-edge cells.
    -- The Silver Harp escape frontier found `(4,13)->DOWN` as the only
    -- hidden bridge candidate; direct verifier moved into `(4,14)` 6/6, and
    -- a raw follow-up tap continued south to `(4,15)`.
    -- The west chest / likely Cursed Belt return route later proved two
    -- false-wall seams: the top-row `(8,0)->(9,0)->(10,0)` seam is standable,
    -- the west chest side can enter decoded-wall cells `(1,2)` and `(2,2)`,
    -- and the later return-route dig proved the left-edge strip `(0,2)`
    -- through `(0,6)` can be occupied even though the generic dungeon-edge
    -- rule marks x=0 as an engine boundary. The `(1,2)`/`(2,2)` pocket's south
    -- exits and the left-edge strip's east exits are modeled directionally
    -- below.
    -- Keep the override scoped to the live-proven cells.
    [0x1A] = {
        ["0,2"] = true,
        ["0,3"] = true,
        ["0,4"] = true,
        ["0,5"] = true,
        ["0,6"] = true,
        ["1,2"] = true,
        ["2,2"] = true,
        ["4,14"] = true,
        ["8,0"] = true,
        ["9,0"] = true,
        ["10,0"] = true,
    },

    -- Map 0x1B: Garin's Grave B4 west return stairs.
    -- The generic dungeon edge rule marks x=0 as an engine boundary, but the
    -- Silver Harp return route proved `(1,4)->LEFT` enters the west return
    -- stair tile `(0,4)` 6/6. Keep this scoped to the stair cell.
    [0x1B] = {
        ["0,4"] = true,
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
    -- Live FCEUX door checks on 2026-05-22 found the two real 1F
    -- magic-key doors. The old y=6 type-15 band is not a door band: OPEN
    -- returns "There is no door here" there, and live movement can enter
    -- several of those cells without consuming keys or writing door RAM.
    --
    -- Opening a door records that door's (x,y) in the opened-door RAM array
    -- ($600C/$600D, up to 8 slots). The pathfinder then routes through
    -- whichever door(s) are open. Doors reset to closed on each map re-entry
    -- (RAM clears on map load).
    [0x04] = {
        ["4,13"] = {x=4, y=13},
        ["18,6"] = {x=18, y=6},
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
    -- Map 0x09: Garinham
    -- Guide data lists town-scope locked doors, but the old `(19,16)` east
    -- guess was disproved live: OPEN from `(19,17)` facing north reported
    -- "There is no door here." Follow-up manual OPEN probes while working back
    -- from the grave route found the grey-building door by standing at (17,9)
    -- facing south; fresh DOOR_STATE then recorded slot 0=(17,10). Nearby
    -- false candidates such as (18,9), (19,7), and (19,9) stayed unmodeled.
    -- The inner locked-building door is floor-backed: OPEN/pass-through from
    -- the south stand `(4,7)` recorded door RAM `(4,6)`, then led into the
    -- one-cell guard pocket at `(4,5)`.
    [0x09] = {
        ["17,10"] = {x=17, y=10},
        ["4,6"] = {x=4, y=6},
    },
    -- Map 0x0B: Rimuldar inn / Wings chest locked doors.
    -- External guide data lists two inn doors. Live FCEUX door RAM confirmed
    -- the outer door at (21,21) after OPEN from (21,22) facing north, and the
    -- inner Wings chest door at (22,23) after OPEN from inside while Bill stood
    -- at (23,23). Both decode as ordinary floor, so these manual door overrides
    -- keep pathfinding from treating them as public floor until opened-door RAM
    -- says they are open.
    [0x0B] = {
        ["21,21"] = {x=21, y=21},
        ["22,23"] = {x=22, y=23},
    },
    -- Map 0x15: Swamp Cave / Quagmire Cave locked Gwaelin branch.
    -- The first (5,22) hypothesis was disproven live. Follow-up OPEN probes
    -- found the real door at (5,20): both (5,21) and (5,19) reported "Thou
    -- hast not a key to use", and OPEN checks only the four adjacent cells.
    [0x15] = {
        ["5,20"] = {x=5, y=20},
    },
    -- Map 0x18: Garin's Grave B1 southeast locked door toward B2.
    -- On 2026-05-30, live FCEUX validation showed OPEN from `(17,18)` facing
    -- north consumed a key and wrote slot `1=(17,17)` into the opened-door
    -- RAM array. A direct `probe_edge:UP` from `(17,18)` then moved into
    -- `(17,17)` despite the old south-approach seam model, proving this cell
    -- is a real magic-key door rather than a directional wall.
    [0x18] = {
        ["17,17"] = {x=17, y=17},
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
        -- Do not block (19,21): the 2026-05-23 frontier crawl flagged it as a
        -- timing-suspect false wall, then direct live probes moved into it from
        -- (19,20), (19,22), and (20,21). Its west exit still cannot progress
        -- because (18,21) remains a full-cell blocker.
        -- (13,13): one-way-entry trap. Tile type=4 (floor), accepts entry from west (x=12
        -- going east), but all 4 exits blocked (engine refuses south/west/north/east).
        -- Confirmed by survey run 5 (2026-04-15): blocked_events=4, all directions 3-for-3 timeout.
        -- Pathfinder chose it as adj to Guard 3 (14,13) with 3-step path; (14,12) is the
        -- safe 5-step alternative. Blocking (13,13) makes A* pick (14,12) instead.
        ["13,13"] = true,
        -- (28,11): was previously modeled as a full blocker from one-way data, but live
        -- probing proved it is physically walkable:
        -- - (28,10)->DOWN entered (28,11) repeatedly during probe_edge_verify
        -- - (28,11)->UP moved back to (28,10) on probe_edge
        -- - (28,11)->RIGHT moved to the World Map at (29,11)
        -- Keep this cell in the standard walkability model (tile=8) and do not add
        -- full-cell or directional blocks here.
        -- x=12 column engine barriers at y=17-18 confirmed 2026-04-09 via survey_map:
        -- survey consistently suspects these as blocking the northward path from (13,19).
        -- A* routes through (12,19)→(12,18)→(12,17) to reach north hall; engine refuses.
        -- With these blocked, A* correctly routes east to x=17-20 corridor then north.
        ["12,17"] = true, ["12,18"] = true,
        -- South-west full block confirmed 2026-04-09 via survey_map (all 4 approaches blocked, count=13)
        ["3,22"] = true,
        ["16,24"] = true, ["17,24"] = true, ["18,24"] = true,
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
        -- Later FCEUX rechecks disproved (22,22) as a full blocker:
        -- (23,22)->LEFT moved into it cleanly on 2026-05-24. Keep the
        -- remaining shelf throat directional and leave only the confirmed
        -- row-23 wall as a full blocker here.
        ["23,23"] = true,
        -- West alcove walls confirmed by survey run (2026-04-19).
        -- The west alcove (x=1-3, y=11-15) is a sealed room; the only entrance
        -- is through (4,16) to the south. Tile type is 6 (carpet) in ROM for all
        -- of these, so A* treats them as walkable — but the engine refuses entry.
        -- Seam observer confirmed all 11 cells as engine-blocked during survey.
        -- Live FCEUX recheck on 2026-05-22 kept most of the x=4 strip
        -- sealed: (3,11..15)->RIGHT, (5,12..15)->LEFT, and (4,16)->UP all
        -- verified blocked 5/5; (5,11)->LEFT repeated as blocked 10/10.
        -- The later door investigation split out (4,13) as the real west
        -- treasure-room magic-key door, so that coordinate belongs in
        -- MAP_DOOR_CELLS instead of this full-block list.
        -- Adding them here prevents A* from routing through the walls and
        -- triggering the confirm→reroute→no-path failure cascade.
        --
        --   East wall:  x=4, y=11-12 and 14-15 (4,13 is a door)
        --   North wall: y=10, x=1-3  (player at y≥11 can't move north into y=10)
        --   South wall: y=16, x=1-3  (player at y≤15 can't move south into y=16)
        ["4,11"] = true, ["4,12"] = true, ["4,14"] = true, ["4,15"] = true,
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
        -- 2026-05-22 Sun Shrine route: autowalk from the entrance to (29,29)
        -- crossed the neighboring barrier pocket and left HP at 9. The route
        -- stepped through these passable tile-6 cells while avoiding only the
        -- previously modeled (10,18) hazard. Follow-up FCEUX live checks
        -- cleared (11,19): raw probe movement into that cell succeeded and HP
        -- stayed 54/54 afterward, so keep only the north pair hazardous.
        ["9,18"] = "damage",
        ["11,18"] = "damage",
        -- 2026-05-23 Sun Shrine forward route: a natural BizHawk autowalk
        -- from the both-doors-open throne-side save crossed this lower
        -- x=25/x=26 pocket and later died in the same cluster. Follow-up
        -- live probes cleared (26,20) specifically, but repeated evidence
        -- still supports the remaining three-cell damage segment so A* uses
        -- the far-east descent instead of routing through the damage.
        ["25,18"] = "damage",
        ["26,18"] = "damage",
        ["26,19"] = "damage",
        -- 2026-05-23 throne-side reroute after (26,16)/(27,17) fixes:
        -- a natural BizHawk autowalk detoured through the x=23 barrier lane
        -- and HP dropped from 54/54 before the lane to 9/54 at (23,21).
        -- Keep the observed vertical segment hazard-forbidden so A* does not
        -- trade a hidden-wall loop for a lethal damage route.
        ["23,18"] = "damage",
        ["23,19"] = "damage",
        ["23,20"] = "damage",
        ["23,21"] = "damage",
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
    -- Antechamber south corridor (x=13-14, y=9):
    --   This corridor appears state/order sensitive. A 2026-05-24 fresh FCEUX
    --   recheck moved (12,9)->RIGHT, but a later restored-state autowalk and
    --   direct verifier blocked (12,9)->RIGHT 5/5 while (13,9)->LEFT moved 6/6.
    --   Keep the west approach open in the default map model because closing it
    --   can make the entrance-side route impossible when Guard 7 occupies
    --   (8,8). Live failures are handled with route-local temp blocks.
    --
    -- x=15 wall north extension confirmed 2026-04-09:
    --   The engine wall at x=15 (confirmed y=10-16 in MAP_BLOCKED_CELLS) continues
    --   northward. (15,7) and (15,8) are floor tiles (type 4) that the engine blocks
    --   only when approaching from the west (moving east from x=14). Approaching from
    --   east, north, or south is passable.
    --
    -- Interior directional barriers:
    --   (4,9): blocked from east and north — antechamber south door region
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
        -- x=4 east wall: west wing interior east boundary.
        -- y=11-15 are full blocked cells in MAP_BLOCKED_CELLS, not
        -- directional-only entries. The old directional shadows were removed
        -- after the 2026-05-22 live recheck resolved the evidence conflict.
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
        ["4,7"]  = {east = true, west = true, south = true},
        ["4,9"]  = {east = true, north = true},  -- antechamber south door region; confirmed
        ["4,10"] = {east = true},                -- survey run4 count=5 high
        -- Antechamber south corridor: confirmed 2026-04-09 via inspect_move probing
        -- 2026-05-22 Sun Shrine route after hazard expansion: the planner
        -- detoured through the east wing and repeatedly tried north approaches
        -- from the y=4 corridor; queued step plus seam retry stayed blocked.
        -- 2026-05-23 post-(22,8) reload route test: the new top-right route
        -- looped at (14,6)->UP. Direct probe_edge_verify:14,6,UP,5 blocked
        -- 5/5, so close the south approach too while leaving (14,5) itself
        -- standable for routes that can naturally reach it from valid sides.
        ["14,5"] = {north = true, south = true},
        ["15,5"] = {north = true},
        -- 2026-05-25 restored-state autowalk and direct verifier:
        -- (12,9)->RIGHT blocked 5/5 while reverse (13,9)->LEFT moved 6/6,
        -- but closing west by default can remove the only entrance-side route
        -- around stationary Guard 7. Keep west open here and let route-local
        -- temp blocks handle live gate rejection.
        ["13,9"] = {north = true, south = true},
        -- 2026-05-23 fixed-verifier retest: (14,8)->DOWN into (14,9)
        -- blocked 5/5 with blocked_model_mismatch=5. Earlier moved evidence
        -- was another unstable row-9 latch result. Keep west open but close
        -- north and south approaches.
        ["14,9"] = {north = true, south = true},
        -- x=15 wall north extension: confirmed 2026-04-09 via inspect_move probing.
        -- 2026-05-22 key-merchant return route repeatedly hit the same wall from
        -- the east side; direct probe_edge_verify from (16,7)->LEFT and
        -- (16,8)->LEFT each blocked 5/5.
        -- 2026-05-23 Sun Shrine route bracketing later found a verifier-only
        -- moved_model_mismatch on (14,7)->RIGHT, but route-shaped autowalk
        -- evidence blocked 9/9 at this edge. Keep both horizontal approaches
        -- closed until a natural route proves otherwise.
        ["15,7"] = {west = true, east = true},
        ["15,8"] = {west = true, east = true},
        -- Key-merchant return cleanup. Autowalk from the opened (18,6) door
        -- toward the exit repeatedly tried (16,8)->DOWN; direct verifier
        -- confirmed the north approach into (16,9) blocked 5/5.
        ["16,9"] = {north = true},
        -- 2026-05-22 Sun Shrine route after hazard expansion: the planner
        -- detoured through the east wing and repeatedly tried north approaches
        -- from row 8; queued step plus seam retry stayed blocked.
        -- Entrance-route verification then confirmed (18,8)->DOWN and
        -- (19,8)->DOWN blocked 5/5 after the first four patches.
        ["17,9"] = {north = true},
        ["18,9"] = {north = true},
        ["19,9"] = {north = true},
        ["20,9"] = {north = true},
        ["21,9"] = {north = true},
        -- 2026-05-23 top-right Sun Shrine route: after (22,8) was promoted as
        -- the hidden exterior-strip passthrough, route-shaped movement and a
        -- clean direct probe_edge_verify:22,8,DOWN,5 both stayed blocked at
        -- the north approach into (22,9). Keep the row-8 connector open while
        -- closing this southward descent.
        ["22,9"] = {north = true},
        -- 2026-05-24 Sage-route alternate-path check: after routing around the
        -- mixed (21,17).east seam, direct probe_edge_verify:24,8,DOWN,5
        -- blocked 5/5 with blocked_model_mismatch=5. Keep the top strip
        -- horizontal-only here instead of letting A* descend through (24,9).
        ["24,9"] = {north = true},
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
        -- The older (4,13) directional-only note was superseded by the
        -- 2026-05-22 live recheck; (4,13) is now modeled as the live
        -- treasure-room magic-key door in MAP_DOOR_CELLS.
        -- West corridor band (y=16-18, x=9-12):
        -- x=9-12 at y=16 form a north-approach wall extending the y=16 barrier westward.
        ["9,16"]  = {north = true, west = true},   -- count=30
        ["10,16"] = {north = true},                -- count=15
        ["11,16"] = {north = true},                -- count=15
        -- (13,16)->(12,16) blocked twice by direct probe on 2026-04-12 and
        -- also failed during a long Guard 2 survey route, so this cell blocks
        -- east approach in addition to the earlier north-side evidence.
        ["12,16"] = {north = true, east = true},
        -- (15,16): south=true restored 2026-04-21: MAP_PASSTHROUGH_CELL
        -- (tile=11 but engine-walkable). A 2026-05-23 throne-room-to-Sun-
        -- Shrine route failure at (14,16)->RIGHT was reproduced with
        -- probe_edge_verify:14,16,RIGHT,5, which blocked 5/5 with no drift,
        -- map change, or NPC contamination. Close only the west approach.
        ["15,16"] = {south = true, west = true},
        -- (16,16): south=true restored — same one-way southward pattern as (15,16).
        -- east=true was a false positive (probe_edge:LEFT from (17,16) moved freely 2026-04-21).
        -- 2026-05-25 key-merchant-to-exit route shakedown, after clean restore
        -- and input recovery, confirmed (16,15)->DOWN blocks 5/5. Keep the
        -- cell standable via MAP_PASSTHROUGH_CELLS but close its north entry.
        ["16,16"] = {south = true, north = true},
        -- (17,16): south=true restored — same one-way southward pattern. The
        -- same clean 2026-05-25 shakedown confirmed (17,15)->DOWN blocks 5/5.
        ["17,16"] = {south = true, north = true},
        -- (18,16): floor tile (type 4). South=true confirmed real — re-verify probe from
        -- (18,17) UP blocked; northward entry from (18,15) DOWN moved freely (one-way).
        ["18,16"] = {south = true},
        -- (19,16): south=true confirmed real 2026-04-21. A later 2026-05-24
        -- Sage-route verifier from (19,15)->DOWN blocked 5/5 with no drift,
        -- map change, or interruption, so the north approach is also closed.
        ["19,16"] = {south = true, north = true},
        -- (20,16) south: blocks north step from (20,17). Confirmed by 10
        -- independent survey failures in run 4 (2026-04-15). A later
        -- 2026-05-24 Sage-route verifier from (20,15)->DOWN also blocked 5/5,
        -- so close the north approach too.
        ["20,16"] = {south = true, north = true},
        -- 2026-05-23 post-reload fixed-verifier retest confirmed the
        -- one-way seam: (20,17)->RIGHT blocked 5/5, while reverse
        -- (21,17)->LEFT moved 6/6 including the stability recheck.
        -- A later 2026-05-24 post-row-22-corridor autowalk retest exposed
        -- the sibling east-side face too: direct probe_edge_verify from
        -- live `(22,17)->LEFT` blocked 5/5 with no drift, map change, or
        -- interruption, so the east approach is also closed.
        ["21,17"] = {east = true, west = true},
        -- The same 2026-05-24 retest repeatedly rerouted into
        -- `(22,17)->UP`; direct probe_edge_verify there also blocked 5/5
        -- with no drift, map change, or interruption, so close the south
        -- approach into `(22,16)`.
        -- A later north-pocket reroute from live `(22,15)` also blocked 5/5
        -- on `(22,15)->DOWN`, so the north approach is closed too.
        ["22,16"] = {south = true, north = true},
        -- 2026-05-24 follow-up after the row-22 corridor restoration:
        -- live autowalk then exposed the next west-face walls in this row-15/16
        -- pocket. Direct probe_edge_verify from forced `(25,15)` blocked 5/5
        -- with no drift, map change, or interruption, so close the east
        -- approach into `(24,15)`.
        ["24,15"] = {east = true},
        -- 2026-05-24 rerouted shrine continuation after promoting
        -- `(21,14).north`: direct probe_edge_verify from forced `(25,14)`
        -- blocked 5/5 with no drift, map change, or interruption, so close
        -- the east approach into `(24,14)`.
        ["24,14"] = {east = true},
        -- 2026-05-24 clean restore after rejecting `(23,16).south` as a false
        -- candidate: the rerouted shrine path then repeatedly stalled on
        -- `(21,13)->DOWN`. Direct probe_edge_verify from forced `(21,13)`
        -- blocked 5/5 with no drift, map change, or interruption, so close
        -- the north approach into `(21,14)`.
        -- A later reroute from live `(22,14)` also blocked 5/5 on
        -- `(22,14)->LEFT`, so the east approach is closed too.
        ["21,14"] = {north = true, east = true, west = true},
        -- The sibling row directly below also blocked on direct verifier from
        -- forced `(25,16)`, so keep the east approach into `(24,16)` closed.
        ["24,16"] = {east = true},
        -- 2026-05-24 recovered shrine-route rerun from live `(25,15)` kept
        -- looping on the row-17 north faces. Fresh direct probe_edge_verify
        -- from forced `(23,17)` then blocked 5/5 with no drift, map change, or
        -- interruption, so close the south approach into `(23,16)`.
        -- A later reroute from live `(23,15)` also blocked 5/5 on
        -- `(23,15)->DOWN`, so the north approach is closed too.
        ["23,16"] = {south = true, north = true},
        -- The sibling face at `(24,17)->UP` verified the same way from a clean
        -- stopped origin, so also close the south approach into `(24,16)`.
        -- A later reroute from live `(24,15)` also blocked 5/5 on
        -- `(24,15)->DOWN`, so the north approach is closed too.
        ["24,16"] = {east = true, south = true, north = true},
        -- 2026-05-24 rerouted north-pocket follow-up after the row-17
        -- promotions: direct probe_edge_verify from live `(22,15)` blocked 5/5
        -- with no drift, map change, or interruption, so close the east
        -- approach into `(21,15)`.
        ["21,15"] = {east = true, west = true},
        -- 2026-05-24 west-pocket continuation after emulator recovery:
        -- direct probe_edge_verify from live `(19,14)` blocked 5/5 on the west
        -- approach into `(18,14)`, while forced `(18,14)->RIGHT` moved back
        -- through and settled east. Keep only the east approach closed; the
        -- north face stayed mixed and should remain unmodeled for now.
        ["18,14"] = {east = true},
        -- 2026-05-24 west-pocket continuation after the hidden-alcove bridge:
        -- live `(19,15)->LEFT` blocked cleanly from a natural routed arrival,
        -- while forced `(18,15)->RIGHT` moved back through and later
        -- `(17,15)->RIGHT` also moved into `(18,15)`. Keep only the east
        -- approach closed; the old west-side runtime helper was disproved and
        -- removed after the direct reverse probe.
        ["18,15"] = {east = true},
        -- 2026-05-24 southeast-pocket bridge retest after user manual run-up:
        -- live `(20,22)->RIGHT` kept blocking from a natural route arrival and
        -- from a clean reloaded standstill, while forced `(21,22)->LEFT` moved
        -- back through and settled at `(19,22)`. Mirroring this one-way seam
        -- at runtime collapsed west-side hazards-allowed planning from
        -- `(17,15)` to `No path found`, while forced `(21,22)` still had a
        -- clean remainder route `8 east, 7 south`. Keep the east approach into
        -- `(21,22)` closed even though the teleported verifier stayed mixed.
        ["21,22"] = {west = true},
        -- 2026-05-24 west-pocket continuation after the row-23 bridge fix:
        -- natural routed `(20,23)->RIGHT` into `(21,23)` blocked repeatedly,
        -- and a quiet current-position `probe_edge:RIGHT` from `(20,23)` also
        -- blocked with `raw_hold_timeout`, while forced `(21,23)->LEFT` moved
        -- back through and settled at `(20,23)`. Close only the west approach
        -- into `(21,23)`.
        ["21,23"] = {west = true},
        -- 2026-05-24 same row-23 bracket from the east side:
        -- current-position `(21,23)->RIGHT` into `(22,23)` also blocked on a
        -- quiet direct probe, while forced `(22,23)->LEFT` moved back through
        -- and settled at `(20,23)`. Close only the west approach into
        -- `(22,23)`.
        ["22,23"] = {west = true},
        -- 2026-05-14 southeast hall retest: (20,20) is standable and raw probes
        -- crossed north/south/west plus reverse east. Only (20,20)->RIGHT into
        -- (21,20) blocked, so model the west approach to (21,20) one-way.
        -- 2026-05-24 Sage-route verifier from (22,20) then confirmed the east
        -- approach blocked 5/5 with no drift, map change, or interruption.
        ["21,20"] = {west = true, east = true},
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
        -- 2026-05-22 follow-up found (18,6) is a real magic-key door:
        -- OPEN from (18,5) facing south consumed a key and wrote door RAM
        -- slot 1=(18,6), so it is modeled in MAP_DOOR_CELLS instead of as
        -- a permanent directional blocker.
        ["17,6"]  = {north = true},
        ["19,6"]  = {north = true},
        -- 2026-05-22 key-merchant entrance-route follow-up: the actual route
        -- to the merchant stand can traverse row 6 horizontally, but row 7
        -- cannot enter the row-6 counter/wall band from below at x=20..23.
        -- Direct probe_edge_verify checks from (20,7)..(23,7) UP each blocked
        -- 5/5; (18,6)->RIGHT and (19,7)->UP later rechecked passable 5/5, so
        -- keep (19,6).west/south open.
        ["20,6"]  = {north = true, south = true},
        ["21,6"]  = {south = true},
        ["22,6"]  = {south = true},
        ["23,6"]  = {south = true},
        -- 2026-05-25 follow-up after the southeast-stairs detour: later clean
        -- verifiers moved 6/6 for (25,5)->DOWN, (26,5)->DOWN, (25,7)->UP,
        -- (26,7)->UP, and (26,7)->RIGHT. Keep (25,6), (26,6), and the
        -- west approach into (27,7) open; the earlier route blockers were
        -- state/timing contamination.
        -- Magic-key merchant counter/wall pocket. The service stand is (24,3)
        -- facing north; (24,2)/(25,2) look walkable to the ROM decoder but
        -- direct raw verifiers from below blocked 5/5.
        ["24,2"]  = {south = true},
        ["25,2"]  = {south = true},
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
        -- (12,28): west: run1 count=1 medium; north: auto_step:down from
        -- (12,27) 3/3 retry fail + probe confirm 2026-04-15. South approach
        -- added 2026-05-14 after the castle entrance -> throne-room stair route
        -- repeatedly tried (12,29)->UP; probe_edge_verify confirmed 5/5 blocked.
        ["12,28"] = {west = true, north = true, south = true},
        -- (13,28).south added 2026-05-14 from the same stair-route failure:
        -- (13,29)->UP verified 5/5 blocked after the route rerouted east.
        ["13,28"] = {south = true},
        -- Sun Shrine stair pocket. Started from the small pocket side on
        -- 2026-05-22; direct verifiers from (27,28) in all four directions
        -- blocked 5/5, proving this is not the entrance bridge.
        ["26,28"] = {east = true},
        ["27,27"] = {south = true},
        ["27,29"] = {north = true},
        ["28,28"] = {west = true},
        -- 2026-05-22 accidental throne-room route shakedown: the route looped
        -- between (28,16)/(28,17), and direct queued + seam-retry evidence
        -- showed the east approach into (27,17) blocked in that run.
        -- Same shakedown found the initial westward entry from (28,20) into
        -- this southeast pocket blocked on queued route plus seam retry.
        ["27,20"] = {east = true, west = true, south = true},
        -- 2026-05-23 throne-room-to-Sun-Shrine autowalk reached the southeast
        -- pocket after the (21,17).west fix. Hardened direct verifiers then
        -- confirmed these false exits blocked 5/5 with no drift, map change,
        -- or interruption. (25,22).north supersedes an earlier mixed result
        -- after a later quiet verifier from the live pinball point.
        -- After the x=25 descent passthrough was added, the next clean route
        -- loop hit (26,14)->RIGHT; direct verifier blocked 5/5.
        -- The top-strip reload route then reached the x=25 descent and hit
        -- (26,13)->RIGHT repeatedly; direct probe_edge_verify:26,13,RIGHT,5
        -- confirmed the west approach into (27,13) blocked 5/5.
        -- After the lower damage pocket was modeled as hazard-forbidden,
        -- probe_edge_verify:26,12,RIGHT,5 confirmed the row-12 approach
        -- into (27,12) blocked 5/5 with no drift, map change, or interruption.
        -- The same route then reached (26,17). After a later direct forced-origin
        -- passability signal was observed once, fresh autowalk and direct verifier
        -- checks now consistently block the bridge step to the west. Treat this as
        -- a confirmed one-way wall.
        -- 2026-05-24 live hazard-pocket continuation from the revived FCEUX
        -- state confirmed the next two east exits are the same kind of hidden
        -- west-approach wall. From live current positions on the hazard tiles,
        -- raw `probe_edge:RIGHT` from (26,18) and from (26,19) each blocked
        -- three times with `raw_hold_timeout`, while `inspect_move` still
        -- previewed ordinary floor and no modeled directional block.
        -- The same restored-save branch then reached (27,20), where the
        -- southward continuation into (27,21) blocked 3/3 from a live current
        -- position even though the model still previewed the north approach as
        -- open. Once that north approach was blocked at runtime, the planner
        -- immediately rerouted through (28,20)->(28,21)->(28,22), and
        -- current-position raw probing confirmed (27,20)->RIGHT into (28,20)
        -- moved cleanly.
        -- 2026-05-24 later FCEUX shrine-route continuation from live position
        -- (26,21) reached (26,20), then repeatedly failed on the eastward
        -- continuation into (27,20). Direct probe_edge_verify:26,20,RIGHT,5
        -- blocked 5/5 with no drift, map change, or interruption, while
        -- reverse probe_edge_verify:27,20,LEFT,5 moved 6/6 including the
        -- delayed stability recheck. Keep this as a west-approach one-way
        -- seam too.
        -- Its reroute then tried (26,17)->UP; probe_edge_verify:26,17,UP,5
        -- confirmed the south approach into (26,16) blocked 5/5.
        -- After the x=23 damage lane was made hazard-forbidden, the only
        -- remaining safe-looking bridge repeatedly stalled at (25,16)->RIGHT;
        -- a frozen-NPC probe_edge_verify:25,16,RIGHT,10 confirmed the west
        -- approach into (26,16) blocked 10/10.
        -- The later live route then looped on the neighboring (25,15)->RIGHT
        -- face; direct probe_edge_verify:25,15,RIGHT,5 confirmed the west
        -- approach into (26,15) blocked 5/5. Hardened follow-up from
        -- (26,14) confirmed the north approach into (26,15) blocked 5/5
        -- with no drift, no map changes, and no interruptions.
        -- 2026-05-24 follow-up after the seam-retry/autowalk patch restored
        -- the west approach into (27,21) as a real blocker. Fresh FCEUX
        -- retests after reload all failed from live state:
        -- probe_edge:RIGHT from (26,21) blocked, simulate_raw_sequence and
        -- simulate_raw_input holds from (26,21) stayed put, and long raw
        -- RIGHT,80 from (25,21) only reached/stopped at (26,21).
        -- Runtime reblocking (27,21).west also collapsed hazards-allowed
        -- planning to (29,29) from both checked entrances, so the shrine
        -- bridge is unresolved again rather than executable through 26,21.
        ["26,15"] = {west = true, north = true},
        ["26,16"] = {south = true, west = true},
        ["27,18"] = {west = true},
        ["27,19"] = {west = true},
        ["27,21"] = {north = true, west = true},
        ["27,12"] = {west = true},
        ["27,13"] = {west = true},
        ["27,14"] = {west = true},
        ["27,17"] = {west = true},
        -- 2026-05-24 FCEUX lower-shelf retest around the shrine approach:
        -- (23,21)->DOWN into (23,22) blocked on raw hold timeout, while
        -- reverse (23,22)->UP moved cleanly. The adjacent west shelf showed
        -- the same one-way shape: (22,21)->DOWN into (22,22) blocked, but
        -- (23,22)->LEFT moved into (22,22). A same-day recheck at the x=26
        -- descent settled the earlier mixed evidence too:
        -- probe_edge_verify:26,21,DOWN,5 blocked 5/5, while
        -- probe_edge_verify:26,22,UP,5 moved 6/6 including the stability
        -- recheck. Later same-day current-position probes inside the restored
        -- pocket also blocked both `(23,22)->RIGHT` into `(24,22)` and the
        -- reverse `(24,22)->LEFT`, so the east-west seam between those two
        -- cells is closed as well. Continuing one cell farther east, direct
        -- probes also blocked both `(24,22)->RIGHT` into `(25,22)` and the
        -- reverse `(25,22)->LEFT`, while `(24,22)->DOWN` blocked but forced
        -- `(24,23)->UP` moved back through and settled at `(24,21)`. A
        -- follow-up pocket dig then found the next shelf is over-open too:
        -- direct current-position `(25,22)->RIGHT` and forced
        -- `(26,22)->LEFT` both blocked, and direct current-position
        -- `(25,22)->DOWN` plus forced `(25,23)->UP` also both blocked. With
        -- those two seams mirrored at runtime, hazards-allowed planning from
        -- `(25,22)` finally collapsed to `No path found`, so keep the row-22
        -- / row-23 throat closed in both directions. A later same-day clean
        -- verifier pair closed the x=26 throat too:
        -- - probe_edge_verify:26,22,DOWN,5 blocked 5/5
        -- - probe_edge_verify:26,23,UP,5 blocked 5/5
        -- - probe_edge_verify:27,22,DOWN,5 blocked 5/5
        -- - probe_edge_verify:27,23,UP,5 blocked 5/5
        -- - probe_edge_verify:27,23,DOWN,5 blocked 5/5
        -- - probe_edge_verify:27,24,UP,5 blocked 5/5
        -- - probe_edge_verify:24,23,DOWN,5 blocked 5/5
        -- - probe_edge_verify:24,24,UP,5 blocked 5/5
        -- - probe_edge_verify:25,23,DOWN,5 blocked 5/5
        -- - probe_edge_verify:25,24,UP,5 blocked 5/5
        -- - probe_edge_verify:26,23,DOWN,5 blocked 5/5
        -- - probe_edge_verify:26,24,UP,5 blocked 5/5
        -- - probe_edge_verify:27,23,RIGHT,5 blocked 5/5
        -- - probe_edge_verify:28,23,LEFT,5 blocked 5/5
        -- - probe_edge_verify:27,24,LEFT,5 blocked 5/5
        -- - probe_edge_verify:26,24,RIGHT,5 blocked 5/5
        -- - probe_edge_verify:27,24,RIGHT,5 blocked 5/5
        -- - probe_edge_verify:28,24,LEFT,5 blocked 5/5
        -- - probe_edge_verify:27,24,DOWN,5 blocked 5/5
        -- - probe_edge_verify:27,25,UP,5 blocked 5/5
        -- That pair matches the live executor stall where forced
        -- `(26,22)->auto_walk:29,29` planned `5 south, 3 east, 2 south` but
        -- never left `(26,22)` on the first south step. The x=27 pair closes
        -- the sibling south descent that appeared after the x=26 throat was
        -- corrected, the same x=24/x=25/x=26 columns also close south on the
        -- way into row 24, the x=27/x=28 handoff at row 23 is closed in both
        -- directions, the adjacent x=27 lower pair closes the follow-up south
        -- continuation the planner still tried from `(27,23)`, and the row-24
        -- shelf itself is now verified boxed on all four sides.
        ["22,22"] = {north = true},
        ["23,22"] = {north = true, east = true},
        ["24,22"] = {north = true, west = true, east = true},
        ["25,22"] = {north = true, west = true, east = true, south = true},
        ["26,22"] = {north = true, west = true, east = true, south = true},
        ["24,23"] = {north = true, south = true},
        ["24,24"] = {north = true},
        ["25,23"] = {north = true, south = true},
        ["25,24"] = {north = true},
        ["26,23"] = {north = true, south = true},
        ["26,24"] = {north = true, east = true},
        ["27,23"] = {north = true, east = true, south = true},
        ["28,23"] = {west = true, south = true},
        -- 2026-05-24 post-reload east-pocket bracketing first looked like a
        -- one-way horizontal shelf plus a real south break at the bottom of
        -- the x=28 conveyor. Later same-day recheck after the x=26 throat
        -- closure disproved the west side staying open:
        -- - probe_edge_verify:26,22,RIGHT,5 blocked 5/5
        -- - probe_edge_verify:27,22,LEFT,5 blocked 5/5
        -- Keep the whole x=26/x=27 seam closed in both directions. The x=28
        -- checks remain:
        -- - probe_edge_verify:28,22,LEFT,5 blocked 5/5
        -- - probe_edge_verify:28,23,DOWN,5 blocked 5/5
        -- - probe_edge_verify:28,24,UP,5 blocked 5/5
        -- Direct settled probes still move vertically through (28,22) between
        -- (28,21) and (28,23), but forced `(29,22)->LEFT` also blocked 5/5,
        -- so only the vertical conveyor stays open there. Keep the west-east
        -- shelf shut from both confirmed x=27 faces and the east-facing x=28
        -- side.
        ["27,22"] = {north = true, west = true, east = true, south = true},
        -- 2026-05-25 restored row-21 route retest: direct probe_edge from
        -- live `(27,21)->RIGHT`, probe_edge_verify:27,21,RIGHT,5, and the
        -- routed autowalk seam retry all blocked entry into `(28,21)` from
        -- the west. Mirroring this edge collapses the false route to
        -- `(29,29)`. Keep `(28,21).east` out of permanent data because
        -- `(29,21)->LEFT` remains state/timing-dependent.
        ["28,21"] = {west = true},
        ["28,22"] = {east = true},
        ["27,24"] = {north = true, west = true, east = true, south = true},
        ["28,24"] = {north = true, west = true},
        ["27,25"] = {north = true},
        -- Upper-right exterior lane: clean route testing with both doors open
        -- showed westward entries into (29,9) and (29,10) can trigger the
        -- World Map transition instead of progressing toward the Sun Shrine.
        -- 2026-05-25 route-temp-block validation found the same behavior
        -- higher up: entering (29,3) from (28,3) reached the World Map before
        -- the queued south descent could continue. Keep these as pathfinder
        -- guards so routes use the x=25 descent.
        ["29,3"] = {west = true},
        ["29,9"] = {west = true},
        ["29,10"] = {west = true},
        -- 2026-05-23 autowalk stall near the throne-side bridge corridor:
        -- direct probe_edge_verify showed one-way west-approach blocks into
        -- (27,9) and (27,10): moving from (26,9)->(27,9) and (26,10)->(27,10)
        -- was blocked 5/5 while reverse moves stayed open.
        ["27,9"] = {west = true},
        ["27,10"] = {west = true},
        -- Southeast exterior lane / world-map exit pocket. Fresh 2026-05-24
        -- rechecks showed this east boundary is mixed, not uniformly open:
        -- - (28,20)->RIGHT changes to the World Map immediately
        -- - (28,21)->RIGHT enters/stops on the castle-side x=29 lane
        -- - (28,22)->RIGHT enters/stops on the castle-side x=29 lane
        -- - (28,23)->RIGHT changes to the World Map immediately
        -- - (29,21)->RIGHT and (29,22)->RIGHT also exit to the World Map
        -- So the planner should only consider westward entry into the x=29
        -- lane at y=21-22; y=20 and y=23 are exterior-exit seams instead.
        -- A 2026-05-22 recheck with both Tantegel doors open also proved
        -- (29,28)->DOWN moves into (29,29) and continues to the World Map at
        -- (43,43). Keep the west approach closed from the earlier
        -- small-pocket verifier, but do not block the north approach or the
        -- route cannot reach the exit tile.
        ["29,20"] = {west = true},
        ["29,23"] = {west = true},
        ["28,29"] = {east = true},
        ["29,29"] = {west = true},
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

    -- Map 0x07: Kol
    -- First parked survey from the live entry lane targeted Person 1 and
    -- looped at (20,18), alternating between north into (20,17) and east into
    -- (21,18). The stopped run logged 51 blocked south-approach observations
    -- for (20,17) and 50 blocked west-approach observations for (21,18), while
    -- surrounding seams such as (20,18), (20,19), (20,21), and the bottom
    -- entrance strip moved. Keep these directional so the standable target-side
    -- cells are not over-blocked before the rest of Kol is decoded.
    [0x07] = {
        -- Merchant 1 autowalk from (19,23) to the service NPC at (8,19)
        -- repeatedly bounced between (11,18) and (11,19). Entering (10,18)
        -- and (10,19) from the east blocked 35+ times each with no moved
        -- observations, while nearby seams such as (11,18) from the south and
        -- (11,19) from the north remained passable/noisy.
        ["10,18"] = {east = true},
        ["10,19"] = {east = true},
        -- Follow-up Merchant 1 attempts after a clean reload advanced into
        -- Kol's inner west approach. The route repeatedly rediscovered these
        -- counter/building seams while trying to reach the target near
        -- (6,17)/(6,19). The strongest loop was at (8,15): (7,15) from the
        -- east and (8,16) from the north both reached 45+ blocked observations
        -- with no moves before the route was manually broken by moving right
        -- to (9,15).
        ["7,15"] = {east = true},
        -- After the service routes opened up more Kol NPC browsing, the route
        -- toward the west-side Old Man 1 looped between (8,11) and (8,12).
        -- Entering (7,11)/(7,12) from the east repeatedly blocked with no
        -- moves, while the vertical connector between (8,11) and (8,12)
        -- remained passable.
        ["7,11"] = {east = true},
        ["7,12"] = {east = true},
        ["8,16"] = {north = true},
        ["9,16"] = {north = true},
        ["10,16"] = {east = true, north = true},
        ["11,20"] = {north = true},
        -- The next clean run routed from (9,15) toward Merchant 1's stand at
        -- (11,21). It looped between (12,18) and (13,18), repeatedly trying
        -- to enter (12,19) and (13,19) from the north. Earlier in the same
        -- route, one queued step plus its seam retry also proved the adjacent
        -- north/east seams below. Noisy seams such as (15,16).west and
        -- (17,21).east had moved evidence and are intentionally left open.
        -- Later Merchant 4 path testing disproved the old (16,22).east
        -- candidate; the (16,22)<->(17,22) seam is passable both ways.
        ["12,19"] = {west = true, north = true},
        ["13,19"] = {north = true},
        ["14,19"] = {north = true},
        ["15,19"] = {north = true},
        ["16,19"] = {east = true, north = true},
        ["16,20"] = {east = true},
        ["16,21"] = {east = true},
        -- Inn-to-exit autowalk from the confirmed Inn stand at (19,2)
        -- repeatedly bounced along row 2, trying to enter (21,3) and (22,3)
        -- from the north. The later return-to-Inn route reached the same cells
        -- from the south and looped between (21,4)/(22,4). Both approaches are
        -- proven blocked-only, while row-2 movement and the (21,4)<->(22,4)
        -- side seams had moved evidence and stay open.
        ["21,3"] = {north = true, south = true},
        ["22,3"] = {north = true, south = true},
        -- Follow-up Inn-to-exit retest after the row-3 fix advanced the loop
        -- to the east wall. The route alternated between row 1 and row 2,
        -- trying to enter (23,1) and (23,2) from the west; both remained
        -- blocked-only while (22,1)<->(22,2) and row-2 west/east approaches
        -- kept moved evidence.
        ["23,1"] = {west = true},
        ["23,2"] = {west = true},
        -- Third Inn-to-exit pass drifted one tile west during turn settle,
        -- recovered with AUTO_WALK_DRIFT_REROUTE, then got into a stable loop
        -- from (10,3). The initial (10,3).north observation moved on retry and
        -- is left open; the real pair was south into (10,4) and east into
        -- (11,3), both blocked-only with repeated seam retries. Later noisy
        -- but successful round-trip evidence also showed (10,4) blocking from
        -- the south, and (11,3) from the north.
        ["10,4"] = {north = true, south = true},
        ["11,3"] = {west = true, north = true},
        -- Entrance-to-Inn retest after the row-3 south blocks routed around the
        -- northeast wall and looped across row 4. The repeated blockers were
        -- entering (23,3) from the south and entering (20,4) from the east;
        -- adjacent row-4 movement through (21,4), (22,4), and (23,4) moved
        -- repeatedly and stays open.
        ["20,4"] = {east = true},
        ["23,3"] = {south = true},
        -- The next entrance-to-Inn pass routed west and settled into a loop
        -- around (11,5), (12,5), and (12,4). Entering (11,4) from the south
        -- and east stayed blocked-only, while the surrounding seams through
        -- (11,5), (12,5), and (12,4) moved repeatedly.
        ["11,4"] = {east = true, south = true},
        -- Successful Inn/exit round-trip cleanup: these seams caused runtime
        -- reroutes but did not strand the path. (9,2).south and (10,4).south
        -- reached four blocked observations in the fresh success log. The
        -- later Old Man 4/clue route also proved the east approach into the
        -- bath tile at (9,2), then repeatedly blocked the east approaches into
        -- the northwest old-man pocket at (2,1)/(2,2). The row-17 pair and
        -- (11,3).north repeated across the fresh success log and earlier
        -- return evidence. Noisy seams such as (10,3).west and (18,18).east
        -- moved on retry and stay open.
        ["2,1"] = {east = true},
        ["2,2"] = {east = true},
        ["9,2"] = {east = true, south = true},
        -- Weapon/armor merchant-to-exit autowalk from the confirmed public
        -- stand at (20,12) first reached (19,13); entry into (19,13) from
        -- the north was noisy and eventually moved, but the route then looped
        -- between south into (19,14) and west into (18,13). The stopped run
        -- ended with (19,14).north at 22 blocked / 0 moved and (18,13).east
        -- at 21 blocked / 0 moved. A later entrance-to-weapon/armor-merchant
        -- retest found the south approaches into (18,14)/(19,14) blocked
        -- repeatedly while the horizontal seam at row 15 moved repeatedly.
        -- A later clean-but-noisy return to the exit repeated the earlier
        -- low-count return-lane blockers: the weapon-counter edge at
        -- (21,12).west, the north entry into (18,13), and the west entry into
        -- (18,14) all stayed blocked-only across reloads, while the route
        -- recovered around them and still completed.
        ["18,13"] = {east = true, north = true},
        ["18,14"] = {south = true, west = true},
        ["19,14"] = {north = true, south = true},
        ["21,12"] = {west = true},
        -- Entrance-to-weapon/armor-merchant retest after the prior patch
        -- reached the east approach lane, then looped between (20,19) and
        -- (20,20) while trying to enter (21,19)/(21,20) from the west. Both
        -- targets reached 20+ blocked observations with no moved observations;
        -- the vertical seam between (20,19) and (20,20) moved repeatedly.
        ["21,19"] = {west = true},
        ["21,20"] = {west = true},
        -- Next entrance-to-weapon/armor-merchant retest routed around the west
        -- approaches above, then looped between (20,15) and (21,15) while
        -- trying to move north into (20,14)/(21,14). The stopped run reached
        -- 24 blocked / 0 moved on both south approaches, while the horizontal
        -- seam between (20,15) and (21,15) moved repeatedly. A later retest
        -- made it to the east side and looped between (22,15)/(23,15), with
        -- the north moves into (22,14)/(23,14) blocked repeatedly and row-15
        -- horizontal movement confirmed noisy-but-passable.
        ["20,14"] = {south = true},
        ["21,14"] = {south = true},
        ["22,14"] = {south = true},
        ["23,14"] = {south = true},
        -- The same noisy return lane also re-hit (18,17).west as blocked-only
        -- before recovering through the lower path. After the return-lane
        -- cleanup changed route geometry, the next return-to-exit attempt
        -- found the row-17 north approaches too: a low-count blocked-only
        -- hit on (18,17).north, then a stable loop between (19,16)/(20,16)
        -- trying to enter (19,17)/(20,17) from the north. The row-16
        -- horizontal seam moved repeatedly and stays open.
        ["18,17"] = {north = true, south = true, west = true},
        ["19,17"] = {north = true, south = true},
        ["20,17"] = {north = true, south = true},
        ["21,18"] = {west = true},
    },

    -- Map 0x0D: Rain Shrine / Northern Cave
    --
    -- First old-man routes from the cave entrance tried to walk straight north
    -- through row 6. The ROM model marks the shrine floor as tile=14 and
    -- walkable, but live auto-walk repeatedly blocked northward entry into
    -- these cells from below while surrounding horizontal/lower seams moved.
    -- Keep these as directional south-approach blocks so the side approaches
    -- around the Staff of Rain wise man remain available. A follow-up route
    -- then proved the west face of the same hidden wall cluster: movement
    -- along column x=1 is valid, but entry eastward into x=2 at rows 3-6
    -- repeatedly blocks. Manual old-man routing later proved the top approach
    -- is also directional: southward entry into row 2 blocks through the early
    -- corridor, while the far-east descent and row-4 return path moved. The
    -- return route from the wise man later exposed the mid-wall: entry into
    -- (5,5), (6,6), (7,5), and (7,6) from the listed approaches verified
    -- blocked 5/5. The final noisy-cleanup passes added (5,3).east,
    -- (7,6).east, (7,5).east, and the lower row north-approach blocks at
    -- (6,9)/(7,9). A raw verifier left (5,3).south open because that edge was
    -- mixed/passable; (8,9).north also stays open because the verifier hit a
    -- map-change case instead of a stable block.
    [0x0D] = {
        ["3,2"] = {north = true},
        ["4,2"] = {north = true},
        ["5,2"] = {north = true},
        ["6,2"] = {north = true},
        ["2,3"] = {west = true},
        ["2,4"] = {west = true},
        ["2,5"] = {west = true},
        ["2,6"] = {south = true, west = true},
        ["5,3"] = {east = true},
        ["3,6"] = {south = true},
        ["4,6"] = {south = true},
        ["5,5"] = {north = true, east = true},
        ["5,6"] = {south = true},
        ["6,6"] = {north = true, south = true},
        ["6,9"] = {north = true},
        ["7,5"] = {east = true, north = true, west = true},
        ["7,6"] = {east = true, south = true},
        ["7,9"] = {north = true},
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

    -- Map 0x09: Garinham
    [0x09] = {
        -- 2026-05-14 Tool Merchant return-route check. User manual movement
        -- from (3,11) confirmed north and west open, while south into (3,12)
        -- and east into (4,11) are engine-blocked. Keep these directional so
        -- the open north/west seams and the cell itself remain usable.
        ["4,11"] = {west = true},
        -- Follow-up exit autowalks wandered around the same building pocket.
        -- Direct probe_edge_verify checks after stopping the loop confirmed:
        -- (2,12)->RIGHT, (3,10)->RIGHT, and (3,10)->UP all blocked 5/5 with
        -- reason=raw_hold_timeout, despite open tile previews. The next route
        -- attempt then looped at (2,10); verifiers confirmed (2,10)->UP and
        -- (2,10)->LEFT blocked 5/5 too. Follow-up manual movement confirmed
        -- (2,10)<->(3,10) crosses both ways despite a bump sound, so keep that
        -- seam open. The next loop moved to (2,11)/(2,12); verifiers confirmed
        -- both left exits blocked 5/5. The entrance-to-Tool-Merchant route
        -- then bounced along the x=7 lane; verifiers confirmed left movement
        -- into the x=6 wall line blocked 5/5 at y=10, y=11, and y=12.
        -- The Weapons Merchant return route exposed the southeast exit lane:
        -- verifiers confirmed (10,16)->RIGHT and (13,14)->RIGHT blocked 5/5.
        -- The entrance-to-Weapons-Merchant route then bounced around the same
        -- counter throat; raw verifiers confirmed (12,15)->LEFT,
        -- (12,16)->LEFT, and (12,15)->DOWN blocked 5/5. The first replan then
        -- tried (15,14)->LEFT into (14,14), which is also blocked 5/5 even
        -- though the reverse exit step (14,14)->RIGHT is valid. The next
        -- replan then verified (15,16)->LEFT and (15,15)->LEFT blocked 5/5
        -- as well. Another replan used the noisy-but-passable
        -- (15,13)->LEFT seam, then verified (14,13)->DOWN blocked 5/5. A
        -- later successful round trip still bumped on (10,15)->RIGHT and
        -- (13,15)->RIGHT; raw verifiers confirmed both blocked 5/5. The
        -- nearby (15,17)->LEFT edge looked suspicious in route logs but raw
        -- verification moved 5/5, so keep (14,17).east open.
        -- A 2026-06-20 locked-room door-stand pass then rechecked the
        -- lower passage with non-teleport walked verifiers: `(3,13)->UP` and
        -- `(4,13)->UP` both blocked after clean route-to-origin settles. This
        -- supersedes the older teleport-backed/open `(4,12).south` note.
        ["11,15"] = {east = true, west = true},
        ["11,16"] = {east = true, west = true},
        ["12,16"] = {north = true},
        ["3,12"] = {north = true, south = true, west = true},
        ["4,12"] = {south = true},
        ["5,12"] = {south = true},
        ["14,14"] = {east = true, north = true, west = true},
        ["14,15"] = {east = true, west = true},
        ["14,16"] = {east = true},
        ["6,10"] = {east = true},
        ["6,11"] = {east = true},
        ["6,12"] = {east = true, south = true},
        -- 2026-05-25 Garin's Grave entrance investigation. These route-shaped
        -- false entries were confirmed with direct probe_edge_verify checks
        -- after the selected `(19,16)` door proved fake. A later post-reload
        -- route to `(18,1)` promoted the formerly mixed `(13,4).west`,
        -- `(19,7).west`, and `(19,9).west` seams after clean verifiers.
        -- Door-RAM seed tests did not open any of those three, so keep them as
        -- walls. Older probe_edge_verify output suggested `(14,10)->RIGHT`
        -- could move into `(15,10)`, but a 2026-06-20 full-NPC-parked
        -- same-origin verifier blocked that approach with no NPC or runtime
        -- blocker. `(15,11)->UP` blocked 5/5, and `(16,11)->UP` into
        -- `(16,10)` blocked 5/5.
        -- Trail-blazing from the door to the grave later proved the top lane
        -- stops at `(13,1)->RIGHT`: `(14,1).west` blocked 5/5 with no NPC at
        -- `(14,1)`. Later keyless return cleanup produced one noisy moved
        -- observation, but same-origin probes from `(15,1)->LEFT` then
        -- blocked on `(14,1).east`; keep both approaches closed.
        ["14,1"] = {east = true, west = true},
        -- Reverse trail-blazing from Garin's Grave stairs showed the upper
        -- row is one-way/exit-prone: clean verifiers blocked downward movement
        -- from x=15..18 into row 2. The 2026-06-17 grave-to-inn cleanup then
        -- gave cleaner same-origin proof for `(19,1)->DOWN`, the x=4..11
        -- row-1 down band, two row-3 down seams, the row-8 down band, and
        -- the `(16,9)->LEFT` seam. Keep these directional so the cells
        -- themselves remain available for object browsing and alternate
        -- approaches.
        -- A locked-room sweep review later verified `(1,3)->UP`,
        -- `(2,3)->UP`, and `(3,2)->LEFT` as blocked walked edges despite
        -- open tile previews.
        -- The Silver Harp return pass also proved `(19,0)->LEFT` into the
        -- top-edge exit cell `(18,0)` blocks 5/5, while `(18,1)->UP` moved
        -- before the world-map transition; close only the east approach.
        ["18,0"] = {east = true},
        ["1,2"] = {south = true},
        ["2,2"] = {east = true, south = true},
        ["4,2"] = {north = true, west = true},
        ["5,2"] = {north = true},
        ["6,2"] = {north = true},
        ["7,2"] = {north = true},
        ["8,2"] = {north = true},
        ["9,2"] = {north = true},
        ["10,2"] = {north = true},
        ["11,2"] = {north = true, south = true},
        ["15,2"] = {north = true},
        ["16,2"] = {north = true},
        ["17,2"] = {north = true},
        ["18,2"] = {north = true},
        ["19,2"] = {north = true},
        ["2,4"] = {north = true},
        ["3,4"] = {north = true},
        ["1,9"] = {north = true},
        ["2,9"] = {north = true, south = true},
        ["3,9"] = {north = true, south = true},
        ["4,9"] = {north = true},
        ["5,9"] = {north = true},
        ["6,9"] = {north = true},
        ["7,9"] = {north = true, south = true},
        ["8,9"] = {north = true, south = true},
        ["9,9"] = {north = true, south = true},
        ["10,9"] = {north = true, south = true},
        ["11,9"] = {north = true, south = true},
        ["12,9"] = {north = true, south = true},
        ["13,9"] = {north = true, south = true},
        ["14,9"] = {north = true, south = true},
        ["15,9"] = {east = true, north = true},
        ["15,10"] = {south = true, west = true},
        ["16,10"] = {north = true, south = true},
        -- Inner locked-building guard pocket. After opening the floor-backed
        -- door at `(4,6)`, repeated manual taps plus a raw same-origin probe
        -- from `(4,5)->UP` blocked into `(4,4)` with no NPC/runtime blocker.
        ["4,4"] = {south = true},
        ["13,3"] = {west = true},
        ["13,4"] = {west = true},
        ["13,5"] = {west = true},
        ["13,6"] = {south = true, west = true},
        ["14,6"] = {south = true},
        ["15,6"] = {south = true},
        ["16,6"] = {south = true},
        ["17,6"] = {south = true},
        ["18,6"] = {south = true},
        ["19,7"] = {west = true},
        ["19,8"] = {west = true},
        ["19,9"] = {west = true},
        ["17,14"] = {north = true},
        ["18,14"] = {east = true},
        ["4,10"] = {west = true},
        ["1,10"] = {east = true},
        ["1,11"] = {east = true},
        ["1,12"] = {east = true, south = true},
        -- 2026-06-20 sweep_walk from the broad Garinham component reached
        -- `(7,17)` by normal movement, then found down/left/right blocked
        -- twice each. Follow-up non-teleport walked verifiers from the same
        -- origin reproduced all three raw-hold timeouts with no NPC/runtime
        -- blocker while the north approach into `(7,17)` stayed usable.
        ["6,17"] = {east = true},
        ["7,18"] = {north = true},
        ["8,17"] = {west = true},
        -- Continuing that broad-component sweep after reload found another
        -- lower-row pocket: `(8,15)->DOWN`, `(10,16)->DOWN`, and
        -- `(10,16)->LEFT` each blocked twice, then non-teleport walked
        -- verifiers reproduced all three raw-hold timeouts. The route into
        -- `(8,15)` and `(10,16)` stayed open, so keep these approach-specific.
        ["8,16"] = {north = true},
        -- A follow-up reload sweep found `(9,15)->DOWN` blocked twice. A
        -- walked verifier routed into `(9,15)` from the west, then reproduced
        -- the down-edge raw-hold timeout; merge that north face with the
        -- already verified east face from `(10,16)->LEFT`.
        ["9,16"] = {east = true, north = true},
        ["10,17"] = {north = true},
    },

    -- Map 0x18: Garin's Grave B1
    [0x18] = {
        -- 2026-05-27 northeast chest-row trail cutting. A live route from the
        -- opened chest area back toward the Garinham stairs repeatedly hit
        -- these hidden one-way seams with seam brute-force retries before
        -- adding runtime blocks. Keep them directional so the known passable
        -- row-1/row-2 connector cells stay available. The `(11,1).south`
        -- seam was noisy and eventually moved, and `(14,1).west` was only
        -- seen once before a battle interrupted the route, so neither is
        -- promoted here.
        ["10,1"] = {east = true, west = true},
        ["10,2"] = {east = true, west = true},
        ["10,3"] = {east = true, west = true},
        ["10,4"] = {south = true, west = true},
        ["10,6"] = {south = true},
        ["10,9"] = {east = true, south = true, west = true},
        ["11,4"] = {north = true, south = true},
        ["12,4"] = {east = true},
        ["12,5"] = {east = true, west = true},
        ["12,6"] = {east = true, south = true, west = true},
        ["12,3"] = {north = true, west = true},
        ["13,3"] = {north = true, south = true},
        -- A follow-up return route from the chest area eventually reached the
        -- Garinham stairs, but only after repeatedly bumping into these
        -- additional approach-specific seams and rerouting around them.
        -- Keep the noisy moved-after-retry seams unmodeled: `(14,1).west`,
        -- `(15,1).west`, `(17,2).west`, `(14,7).east`, `(6,7).east`, and
        -- `(5,7).east`.
        ["14,2"] = {east = true, north = true, west = true},
        -- The next route back toward the chests exposed the x=14..16 wall
        -- band from the other side. Direct `probe_edge_verify` checks on
        -- 2026-05-27 confirmed each promoted edge below blocked 5/5 with no
        -- drift or interruptions. A later cleanup pass superseded the earlier
        -- mixed `(17,1).south` result with a clean 5/5 blocked verifier.
        -- Later combat-detour routes found a lower middle seam cluster. Direct
        -- verification promoted `(10,3).west`, `(10,4).west`,
        -- `(11,4).south`, `(12,5).west`, and `(12,6).west`. Later direct
        -- probes superseded the originally mixed/interrupted entries,
        -- including the manual-route offender `(10,1).west`, which blocked
        -- 8/8 from `(9,1)->RIGHT` with no drift, map change, or interruption.
        -- A later return-route audit similarly superseded older mixed/passable
        -- `(16,1).west` evidence with a clean 8/8 blocked verifier from
        -- `(15,1)->RIGHT`.
        -- Fresh direct verification also confirmed the row-4/5/6 side entries
        -- around x=12/x=14 blocked 5/5, plus `(14,6).south`.
        ["14,4"] = {east = true, west = true},
        ["14,5"] = {east = true, west = true},
        ["14,6"] = {east = true, south = true, west = true},
        ["15,3"] = {north = true, south = true},
        ["16,1"] = {west = true},
        ["16,3"] = {east = true, north = true},
        ["16,4"] = {west = true},
        ["16,5"] = {east = true, west = true},
        ["16,6"] = {east = true, south = true, west = true},
        ["17,1"] = {south = true},
        -- 2026-06-16 entrance/stair cleanup also superseded older mixed
        -- `(16,9).east` evidence: two clean same-origin `probe_edge:LEFT`
        -- checks from normally reached `(17,9)` blocked into `(16,9)`.
        -- Pulling the current runtime overlay before the next reload also
        -- promoted the first down-stair route polish blocks at
        -- `(17,9)->UP` into `(17,8)` and `(18,7)->DOWN` into `(18,8)`.
        ["16,9"] = {east = true},
        ["17,8"] = {north = true, south = true},
        ["18,8"] = {north = true},
        -- A later B2-stairs autowalk tried the `(3,7)` south/east exits.
        -- Direct verifiers confirmed `(4,7).west` blocked 8/8 and, after a
        -- mixed first check plus validator abort, `(3,8).north` blocked 15/15.
        -- Later B2-stairs validation passes also confirmed `(4,6).west` and
        -- `(3,5).south`.
        ["3,5"] = {south = true},
        ["3,8"] = {north = true},
        ["3,9"] = {east = true},
        ["3,10"] = {south = true},
        ["4,6"] = {west = true},
        ["4,7"] = {west = true},
        -- Continued lower-west B2-stairs probes confirmed the next maze wall
        -- band with clean 8/8 direct verifiers. `(2,15).north` was initially
        -- mixed, then acted out under live validation and rechecked blocked
        -- 8/8. `(1,7).east`, `(1,8).east`, `(1,9).east`, `(1,10).east`,
        -- `(1,12).east`, and `(1,13).east` followed the same
        -- validate-then-direct pattern. `(3,10).south`, `(3,12).north`,
        -- `(3,12).west`, `(3,13).south`, `(3,13).west`, `(4,13).north`,
        -- `(4,13).south`, `(5,10).west`, and `(5,11).west` also promoted
        -- after validator aborts plus clean 8/8 verifiers. The row-6 crossing
        -- into `(1,6)` is passable, but the south descent into `(1,7)` is also
        -- blocked.
        ["1,7"] = {east = true, north = true},
        ["1,8"] = {east = true},
        ["1,9"] = {east = true},
        ["1,10"] = {east = true},
        ["1,11"] = {east = true},
        ["1,12"] = {east = true},
        ["1,13"] = {east = true},
        ["1,14"] = {east = true},
        -- 2026-05-28 entrance-side west-pocket continuation: after sealing the
        -- reverse-side contour, live validation from `(8,19)` kept tracing the
        -- outer west shelf and direct 15/15 verifiers confirmed
        -- `(7,18).south`, `(4,18).south`, `(3,16).south`, `(4,17).west`, and
        -- `(2,17).east`. The adjacent `(3,19).east` seam stayed noisy and
        -- moved on retry, so it remains unmodeled. After the next reload,
        -- replanning from `(3,18)` exposed a second five-seam batch in the
        -- same pocket: `(4,18).west`, `(2,17).south`, `(1,15).south`,
        -- `(3,16).west`, and `(2,15).south`.
        ["1,15"] = {south = true},
        ["2,15"] = {north = true, south = true},
        ["2,17"] = {east = true, south = true},
        ["3,12"] = {east = true, north = true, west = true},
        ["3,13"] = {south = true, west = true},
        ["3,15"] = {east = true, north = true},
        ["3,16"] = {south = true, west = true},
        ["4,13"] = {north = true, south = true, west = true},
        ["4,16"] = {north = true},
        ["5,10"] = {east = true, north = true, west = true},
        ["5,11"] = {east = true, north = true, west = true},
        -- First B2-stairs push from `(6,11)` hit the lower B1 maze wall band.
        -- Direct probes confirmed these entries blocked 5/5. A follow-up
        -- lower-maze push superseded the earlier mixed `(5,14).east`
        -- result with a clean 5/5 direct verifier. A later validator abort
        -- plus direct 8/8 verifier confirmed `(5,14).west`, and added the
        -- row-15/17
        -- dead-end seams below. `(5,16).east` also started mixed, then the
        -- route validator and a stronger 8/8 direct verifier confirmed it as
        -- blocked. `(6,18).north`, `(4,17).east`, `(7,17).west`,
        -- `(6,15).south`, `(8,18).north`, and `(8,13).east` followed the
        -- same pattern and were promoted after validator aborts plus clean
        -- 8/8 verifiers. The later east-side loop route similarly confirmed
        -- `(10,8).west`, `(10,10).west`, `(10,11).east/west`,
        -- `(10,12).east/west`, `(10,13).south/west`,
        -- `(11,10).south`, `(11,13).north`, `(12,12).east/north/west`,
        -- `(12,13).south`, `(13,13).north/south`, `(13,17).north`,
        -- `(14,8).north`, `(14,11).west`, `(14,13).east/north`,
        -- `(14,14).west`, `(14,15).east/west`, `(14,16).east/west`,
        -- `(15,14).north/south`,
        -- `(15,17).north`,
        -- `(16,11).west`,
        -- `(16,12).west`, `(16,14).north`, `(16,15).east/south/west`,
        -- `(16,17).north`,
        -- `(17,11).north/east`, `(17,12).east`, `(17,13).east/west`,
        -- `(17,14).south`, `(17,17).north`,
        -- `(18,14).north/east`, `(18,15).east/south/west`,
        -- `(18,17).north`, `(19,12).south`, and `(19,17).north`.
        -- A later B2-stairs north-hook cleanup kept pushing the live route
        -- north and west until direct 8/8 verifiers promoted `(10,9).east`,
        -- `(11,10).north`, `(14,10).east`, `(16,11).north`, and
        -- `(16,12).south`. The next follow-up batch climbed farther up the
        -- same hook and confirmed `(11,8).south`, `(12,8).south`,
        -- `(12,10).north`, `(13,10).north`, and `(14,10).north`.
        -- Continued live validation of the B2-stairs route from the entrance
        -- side then confirmed the southward false entries into the same upper
        -- lane: `(10,7)->DOWN`, `(11,7)->DOWN`, `(12,7)->DOWN`,
        -- `(13,7)->DOWN`, and `(15,8)->LEFT` all blocked cleanly under direct
        -- 15-attempt verifiers. The later `auto_walk_blocker` cleanup
        -- confirmed `(16,7)->DOWN` into `(16,8)` with route evidence plus two
        -- current-position same-origin probes, while still leaving unrelated
        -- row-7 mirrors runtime-only until direct probes from below confirm
        -- them.
        -- Pulling the current 2026-06-16 runtime overlay before the next
        -- reload also promoted the route-polish blocks at `(7,9)->DOWN` into
        -- `(7,10)` and `(19,11)->DOWN` into `(19,12)`.
        -- A later 2026-05-29 recheck in a clean no-runtime-block state
        -- disproved the provisional west-entry reopening entirely:
        -- `validate_path` from `(6,11)` aborted at `(4,14)->RIGHT`, and
        -- direct 5/5 verifiers reconfirmed both `(5,14).west` and
        -- `(5,15).west` blocked.
        -- `(11,14).east` was noisy and moved on validator retry, so it
        -- stays open.
        -- 2026-05-30 return-route cleanup from the B2 stairs rechecked the
        -- southeast shelf after the B1 door confirmation. Direct
        -- `probe_edge_verify:17,17,LEFT,5` confirmed `(16,17).east` blocked
        -- 5/5 with no drift or interruptions. The sibling lower-lane face at
        -- `(17,18)->DOWN` into `(17,19)` was mixed in that pass, but the
        -- 2026-06-16 `auto_walk_blocker` cleanup normally walked back to
        -- `(17,18)` and blocked two fresh same-origin `probe_edge:DOWN`
        -- checks, promoting `(17,19).north`. A compact
        -- `auto_walk_blocker:17,19` follow-up then found the east approach
        -- from `(18,19)->LEFT`, and two same-origin probes confirmed that
        -- face too. One final replanned `auto_walk_blocker:17,19` exposed
        -- the west approach from `(16,19)->RIGHT`, which also blocked under
        -- repeated same-origin probes.
        -- 2026-06-05 Silver Harp escape route from the B1 lower pocket:
        -- direct verifiers confirmed `(5,19)->UP` and `(6,19)->UP` blocked
        -- 5/5. A later 2026-06-16 entrance/stair route cleanup superseded
        -- the old `(3,17)->RIGHT` passable note: normal-walked route evidence
        -- and repeated same-origin probes both blocked entry into `(4,17)`
        -- from the west, closing the false short return route.
        ["4,17"] = {east = true, west = true},
        ["4,18"] = {south = true, west = true},
        ["5,14"] = {east = true, west = true},
        ["5,15"] = {west = true},
        ["5,12"] = {east = true, west = true},
        ["5,16"] = {east = true, south = true},
        ["5,18"] = {north = true, south = true},
        ["6,13"] = {north = true, south = true},
        ["6,15"] = {north = true, south = true},
        ["6,18"] = {north = true, south = true},
        ["6,8"] = {north = true, south = true},
        ["7,13"] = {east = true, north = true, south = true},
        ["7,15"] = {north = true, south = true},
        ["7,17"] = {east = true, north = true, west = true},
        ["7,18"] = {south = true},
        ["7,10"] = {north = true, south = true},
        ["7,8"] = {north = true},
        ["8,13"] = {east = true, north = true, south = true},
        ["8,15"] = {north = true, south = true},
        -- 2026-05-28 reverse-side contour continuation: after sealing the
        -- earlier south-rim pocket, direct 15/15 verifiers from `(8,19)`,
        -- `(9,19)`, and `(10,18)` confirmed `(8,18).south`, `(9,18).east`,
        -- `(9,18).south`, `(10,17).south`, and `(11,18).west`.
        ["8,18"] = {north = true, south = true, west = true},
        ["8,8"] = {north = true},
        ["9,15"] = {north = true, south = true},
        ["9,17"] = {north = true, west = true},
        ["9,18"] = {east = true, south = true},
        ["10,8"] = {north = true, west = true},
        ["10,10"] = {west = true},
        ["10,11"] = {east = true, west = true},
        ["10,12"] = {east = true, west = true},
        ["10,13"] = {south = true, west = true},
        ["10,15"] = {east = true, north = true, south = true},
        ["10,17"] = {north = true, south = true},
        ["11,8"] = {north = true, south = true},
        ["11,10"] = {north = true, south = true},
        ["11,13"] = {north = true, south = true},
        ["11,17"] = {north = true},
        -- 2026-05-28 reverse-side contour follow-up: after the lower-lane
        -- detours around the B2-side south rim, direct 15/15 verifiers
        -- confirmed `(11,19)->UP`, `(12,18)->LEFT`, `(14,19)->LEFT`,
        -- `(18,18)->UP`, and `(19,18)->UP` all block despite open previews.
        ["11,18"] = {east = true, south = true, west = true},
        ["12,8"] = {north = true, south = true},
        -- 2026-05-28 upper-hook south-approach cleanup: direct 15/15 verifiers
        -- from below confirmed the mirrored northbound entries into the same
        -- row-8/row-10 pocket cells blocked at (12,11)->UP, (13,11)->UP,
        -- (14,12)->UP, (13,9)->UP, and (14,9)->UP.
        -- The later reverse-side lower-lane pass from the B2 stairs also
        -- confirmed one-way blockers at (7,18)->RIGHT, (12,19)->RIGHT,
        -- (12,18)->UP, (13,18)->UP, and (14,18)->UP 15/15; preserve those as
        -- `(8,18).west`, `(13,19).west`, `(12,17).south`, `(13,17).south`,
        -- and `(14,17).south`.
        ["12,10"] = {north = true, south = true},
        ["12,12"] = {east = true, north = true, west = true},
        ["12,13"] = {south = true},
        ["12,17"] = {north = true, south = true},
        ["13,8"] = {north = true, south = true},
        ["13,10"] = {north = true, south = true},
        ["13,13"] = {north = true, south = true},
        ["13,17"] = {north = true, south = true},
        ["13,19"] = {east = true, west = true},
        ["14,8"] = {east = true, north = true, south = true},
        ["14,10"] = {east = true, north = true},
        ["14,11"] = {east = true, west = true, south = true},
        ["14,13"] = {east = true, north = true},
        ["14,14"] = {west = true},
        ["14,15"] = {east = true, west = true},
        ["14,16"] = {east = true, west = true},
        ["14,17"] = {north = true, south = true},
        -- 2026-05-28 reverse-side lower-lane cleanup: after runtime detours
        -- around the B2-side bottom row, direct 15/15 verifiers confirmed
        -- `(14,18)->RIGHT`, `(15,19)->UP`, `(16,18)->LEFT`, `(16,18)->UP`,
        -- and `(17,18)->UP` all block despite open tile previews.
        ["15,18"] = {east = true, south = true, west = true},
        ["15,14"] = {north = true, south = true},
        ["15,17"] = {north = true},
        ["16,8"] = {north = true},
        ["16,11"] = {north = true, west = true},
        ["16,12"] = {south = true, west = true},
        ["16,14"] = {north = true},
        ["16,15"] = {east = true, south = true, west = true},
        ["16,17"] = {east = true, north = true, south = true},
        ["17,11"] = {east = true, north = true},
        ["17,12"] = {east = true},
        ["17,13"] = {east = true, west = true},
        ["17,14"] = {south = true},
        ["17,19"] = {east = true, north = true, west = true},
        ["18,14"] = {east = true, north = true},
        ["18,15"] = {east = true, south = true, west = true},
        ["18,17"] = {north = true, south = true},
        ["19,12"] = {north = true, south = true},
        ["19,17"] = {north = true, south = true},
        -- User/manual route polishing later confirmed the lower-middle seams
        -- around `(8,10)` and `(10,9)` with clean 8/8 direct verifiers.
        ["8,10"] = {east = true, south = true},
    },

    -- Map 0x19: Garin's Grave B2
    [0x19] = {
        -- 2026-05-30 southwest B2 stair route cleanup. The return run toward
        -- `(1,10)` repeatedly snagged on the west pocket, then focused direct
        -- verifiers confirmed both blockers 5/5 with no drift, map change, or
        -- interruption:
        --   `(3,10)->LEFT` into `(2,10)` blocks from the east.
        --   `(3,10)->UP` into `(3,9)` blocks from the south.
        -- A later clean same-origin verifier from `(2,11)` confirmed the
        -- lower return face too: `(2,11)->UP` into `(2,10)` blocked 5/5, so
        -- `(2,10).south` is now modeled. A later Northwest Stairs Down route
        -- from the southwest-stair side blocked `(1,10)->RIGHT` under normal
        -- route execution plus same-origin `probe_edge:RIGHT`, so
        -- `(2,10).west` is modeled too.
        ["2,10"] = {east = true, south = true, west = true},
        ["3,9"] = {south = true},
        -- Post-reload direct verifier pass on the southwest-stair return route
        -- confirmed the left-edge false entries into `(2,3)` through `(2,7)`.
        -- Adjacent vertical suspects `(1,2).south` and `(1,9).north` stayed
        -- mixed at first, so only the clean west-approach strip was modeled
        -- here initially. A later safe false-setting route pass then
        -- direct-verified the reverse faces too: `(3,4)->LEFT`,
        -- `(3,7)->LEFT`, and `(3,8)->LEFT` each blocked 5/5 under
        -- same-origin `probe_edge_verify`.
        -- The next live return pass filled the remaining west-pocket seam and
        -- upper lip band: `(3,5)->LEFT` and `(3,4..8,4)->UP` confirmed
        -- `(2,5).east`, `(3,3).south`, `(4,3).south`, `(5,3).south`,
        -- `(6,3).south`, and `(7,3).south` blocked 5/5.
        ["2,4"] = {east = true, west = true},
        ["2,5"] = {east = true, west = true},
        ["2,6"] = {east = true, west = true},
        ["2,7"] = {east = true, west = true},
        -- The 2026-06-16 west-chest escape-route cleanup proved the earlier
        -- mixed faces from normal play: `(1,3)->UP`, `(1,1)->DOWN`,
        -- `(1,1)->RIGHT`, `(1,2)->RIGHT`, `(1,8)->RIGHT`, and `(1,8)->DOWN`
        -- all blocked under same-origin probes while the left-edge strip
        -- provided the real return path.
        ["2,8"] = {east = true, west = true},
        ["1,2"] = {east = true, north = true, south = true},
        ["2,1"] = {east = true, south = true, west = true},
        ["2,2"] = {east = true, west = true},
        ["2,3"] = {north = true, west = true},
        ["3,3"] = {north = true, south = true},
        ["4,1"] = {south = true, west = true},
        ["4,3"] = {north = true, south = true},
        ["5,1"] = {south = true},
        ["5,3"] = {north = true, south = true},
        ["6,3"] = {south = true},
        ["7,3"] = {south = true},
        -- A later B2 return pass exposed another row-9 band. Direct follow-up
        -- verifiers confirmed `(4,10)->UP`, `(9,10)->UP`, `(10,10)->UP`, and
        -- `(12,10)->UP` blocked 5/5. `(5,10)->UP` first settled into a mixed
        -- teleport-artifact pattern, but a later normal-route Northwest Stairs
        -- Down attempt plus same-origin `probe_edge:UP` from `(5,10)` blocked
        -- cleanly, so `(5,9).south` is modeled. A 2026-06-05 cleanup pass
        -- direct-verified `(6,10)->UP`, `(7,10)->UP`, and `(8,10)->UP` as 5/5
        -- blocked from the south.
        -- A fresh 2026-05-30 verifier pass from the north side then proved the
        -- row-9 trap strip extends across `(3..7,9)`: `(3,8)->DOWN` through
        -- `(7,8)->DOWN` each blocked 5/5 under explicit verifier teleports.
        -- A later reroute higher up the same column found `(6,8)->UP` blocking
        -- on three separate fresh-start `probe_edge:UP` shots while reverse
        -- `probe_edge_verify:DOWN,5` from `(6,7)` moved 6/6, so `(6,7).south`
        -- is modeled as another directional seam even though the repeated
        -- verifier from `(6,8)` stayed teleport-artifact mixed. A later
        -- southwest-stair follow-up then direct-verified `(1,10)->UP` into
        -- `(1,9)` blocked 5/5 from the same start, so `(1,9).south` was
        -- modeled too. The later B2 west-chest escape cleanup also proved
        -- `(1,8)->DOWN` into `(1,9)` blocked from the north, and the follow-up
        -- same-origin route probe from `(0,9)->RIGHT` proved `(1,9).west`.
        ["1,9"] = {north = true, south = true, west = true},
        ["3,9"] = {north = true, south = true},
        ["4,9"] = {north = true, south = true},
        ["5,9"] = {north = true, east = true, south = true},
        ["6,7"] = {south = true},
        ["6,9"] = {north = true, east = true, south = true, west = true},
        ["7,9"] = {north = true},
        ["9,9"] = {south = true},
        ["10,9"] = {south = true},
        ["12,9"] = {east = true, south = true},
        -- 2026-05-30 out-and-back cleanup after the stat-corruption A/B rerun.
        -- Fresh direct verifiers confirmed two right-side false entries cleanly
        -- 5/5 from the east, while nearby `(12,4).east` stayed mixed at the
        -- time and the top-right hook near `(10..11,1..3)` moved 6/6. A later
        -- 2026-06-07 normal-route Central Stairs Down pass walked to `(13,4)`,
        -- then same-origin `probe_edge:LEFT` blocked into `(12,4)`, so
        -- `(12,4).east` is now modeled too. A later 2026-06-05
        -- noisy southwest-stair return pass re-opened that top-right hook: the
        -- repeated verifier on `(11,1)->LEFT` stayed teleport-artifact mixed,
        -- but three separate fresh-start `probe_edge:LEFT` checks from real
        -- `(11,1)` all blocked and reverse `probe_edge_verify:10,1,RIGHT,5`
        -- moved 6/6 with stability recheck, so `(10,1).east` is now modeled.
        -- A later entry-side polish pass from live `(11,2)` then confirmed
        -- `(11,2)->LEFT` blocked 5/5 while reverse
        -- `probe_edge_verify:10,2,RIGHT,5` moved 6/6 with stability recheck,
        -- so `(10,2).east` is also modeled. A follow-up direct verifier then
        -- confirmed `(11,2)->DOWN` into `(11,3)` blocked 5/5, so
        -- `(11,3).north` is now modeled too. The reverse face from `(11,3)`
        -- moved on its first attempt before a Metal Scorpion battle
        -- interrupted the verifier, so only the north approach was promoted at
        -- first. A later direct verifier on `(13,3)->LEFT` blocked 5/5
        -- cleanly, so `(12,3).east` is now modeled. The sibling north face was
        -- initially left open because teleport-backed verifier evidence was
        -- mixed, but a 2026-06-06 normal-route Central Stairs Down attempt
        -- reached `(12,2)` by walking, then `(12,2)->DOWN` blocked through
        -- route retry plus two same-origin `probe_edge:DOWN` checks. That
        -- supersedes the old teleport-artifact note, so `(12,3).north` is now
        -- modeled too. The next follow-up started from live `(12,3)` when the
        -- planner still wanted to go west: same-origin `probe_edge_verify:LEFT,5`
        -- from `(12,3)` blocked 5/5 into `(11,3)`, and the reverse
        -- `probe_edge_verify:RIGHT,5` from `(11,3)` stayed teleport-artifact
        -- mixed. Three fresh-start `teleport_to:11,3` plus `probe_edge:RIGHT`
        -- checks then all blocked at `raw_hold_timeout`, so the seam is now
        -- modeled on both faces as `(11,3).east` and `(12,3).west`.
        -- On 2026-06-05, live same-origin `probe_edge_verify:LEFT,5` from
        -- `(13,9)` confirmed `(12,9).east` blocked 5/5 after an earlier
        -- teleport verifier stayed mixed.
        ["10,1"] = {east = true},
        ["10,2"] = {east = true},
        ["11,3"] = {north = true, east = true},
        ["12,3"] = {north = true, east = true, west = true},
        -- A later noisy mid-pocket loop around `(9,5)` and `(9,6)` was split by
        -- same-origin direct verifiers: `(9,6)->DOWN` into `(9,7)` and
        -- `(9,5)->RIGHT` into `(10,5)` blocked 5/5, and the previously
        -- unmodeled `(9,5)->LEFT` into `(8,5)` also blocked 5/5. The next
        -- pass approached that same pocket from the west/top and confirmed
        -- `(7,5)->RIGHT`, `(8,4)->DOWN`, and `(8,4)->UP` all blocked 5/5 into
        -- `(8,5).west`, `(8,5).north`, and `(8,3).south`. `(9,6)->RIGHT` and
        -- `(9,4)->UP` moved 6/6 and remain intentionally open here. A later
        -- top-row follow-up rechecked `(9,3)->LEFT` directly after the planner
        -- still wanted to peel west there; it blocked 5/5 while reverse
        -- `probe_edge_verify:RIGHT,5` from `(8,3)` moved 6/6 with stability
        -- recheck, so `(8,3).east` is now modeled too. A later
        -- revisit from the live southwest-stair route rechecked `(9,6)->LEFT`
        -- directly from the tile and found the forward face blocked 5/5 twice,
        -- while reverse `probe_edge_verify:RIGHT,5` from `(8,6)` moved 6/6 with
        -- stability recheck, so `(8,6).east` is now modeled as a directional
        -- seam. The next reroute toward the southwest B3 stairs then exposed a
        -- west strip on the same `x=8` column: `(7,6)->RIGHT` and
        -- `(7,7)->RIGHT` both blocked 5/5 under same-origin verifiers, while
        -- `(7,8)->RIGHT` showed a teleport-artifact mixed verifier but blocked
        -- on three separate fresh-start `probe_edge:RIGHT` shots and still let
        -- reverse `probe_edge_verify:LEFT,5` from `(8,8)` move 6/6. The next east-pocket cleanup pass direct-verified
        -- `(11,6)->RIGHT`, `(11,6)->LEFT`, `(11,6)->DOWN`, `(11,5)->LEFT`,
        -- and `(11,5)->RIGHT` as 5/5 blocked, and three fresh-start
        -- `probe_edge:DOWN` checks from `(10,4)` also blocked into `(10,5)`.
        -- A later center-right cleanup resumed from live `(10,8)` after an
        -- autowalk loop and then direct-verified the vertical strip on both
        -- sides of row 8: same-origin `probe_edge_verify:UP,5` from
        -- `(9,8)`, `(10,8)`, `(11,8)`, and `(12,8)` each blocked 5/5 into
        -- `(9,7)`, `(10,7)`, `(11,7)`, and `(12,7)`, while
        -- `probe_edge_verify:DOWN,5` from those same row-8 starts also blocked
        -- 5/5 into `(9,9)`, `(10,9)`, `(11,9)`, and `(12,9)`.
        -- One last southwest-stair follow-up then revisited the earlier
        -- noisy `(8,8)->DOWN` route hit. `probe_edge_verify:DOWN,5` from
        -- `(8,8)` stayed mixed (`moved=2 blocked=3`), but three separate
        -- fresh-start `probe_edge:DOWN` checks from `(8,8)` all blocked and
        -- reverse `probe_edge_verify:UP,5` from `(8,9)` also blocked 5/5, so
        -- both faces of the seam are now modeled. The next noisy reroute seam
        -- at `(8,9)->LEFT` behaved similarly: repeated verifier from `(8,9)`
        -- stayed mixed (`moved=3 blocked=2`), but three fresh-start
        -- `probe_edge:LEFT` checks from `(8,9)` all blocked and reverse
        -- `probe_edge_verify:RIGHT,5` from `(7,9)` also blocked 5/5, so the
        -- `(7,9)<->(8,9)` pair is modeled too. The next leftward reroute did
        -- the same one cell farther west: repeated verifier from `(7,9)` stayed
        -- mixed (`moved=1 blocked=4`), but three fresh-start `probe_edge:LEFT`
        -- checks from `(7,9)` all blocked and reverse `probe_edge_verify:RIGHT,5`
        -- from `(6,9)` also blocked 5/5, so `(6,9)<->(7,9)` is modeled too.
        -- A 2026-06-07 Central Stairs Down route then walked normally to
        -- `(9,8)` and `(13,6)`: route retries plus same-origin `probe_edge:LEFT`
        -- blocked into `(8,8)` and `(12,6)`, so `(8,8).east` and
        -- `(12,6).east` are modeled.
        ["7,9"] = {north = true, east = true, south = true, west = true},
        ["8,3"] = {south = true, east = true},
        ["8,5"] = {east = true, north = true, west = true},
        ["8,6"] = {east = true, west = true},
        ["8,7"] = {west = true},
        ["8,8"] = {east = true, south = true, west = true},
        ["8,9"] = {north = true, south = true, west = true},
        ["9,7"] = {north = true, south = true},
        ["9,9"] = {north = true, south = true},
        ["10,7"] = {south = true},
        ["10,5"] = {east = true, north = true, west = true},
        ["10,6"] = {east = true},
        ["10,9"] = {north = true, south = true},
        ["11,7"] = {north = true, south = true},
        ["11,9"] = {north = true},
        -- The next southwest-stair reroute polished the lower detour too:
        -- repeated verifier on `(12,10)->LEFT` stayed 1-moved/4-blocked
        -- teleport-artifact mixed, but three fresh-start `probe_edge:LEFT`
        -- checks from `(12,10)` all blocked and reverse
        -- `probe_edge_verify:11,10,RIGHT,5` moved 6/6 with stability recheck,
        -- so `(11,10).east` is now modeled. The follow-up autowalk then
        -- completed with only timing retries at `(12,10)->DOWN` and
        -- `(2,11)->LEFT`, both of which self-cleared and stay unmodeled.
        ["11,10"] = {east = true},
        ["12,4"] = {east = true},
        ["12,5"] = {east = true, west = true},
        ["12,6"] = {east = true, west = true},
        -- A later east-side reroute from the top-right pocket direct-verified
        -- `(12,6)->DOWN` into `(12,7)` as blocked 5/5 from the same start,
        -- so `(12,7).north` is now modeled too.
        ["12,7"] = {east = true, north = true, south = true},
        ["12,9"] = {east = true, north = true, south = true},
    },

    -- Map 0x1A: Garin's Grave B3
    [0x1A] = {
        -- 2026-05-30 southwest-pocket route to the B4 stairs. After the
        -- autowalk to `(10,9)` wandered and then got post-battle menu/input
        -- noise, direct verifiers cleanly confirmed the west strip entries
        -- into `(1,12)` and `(1,13)` block 5/5 from the east. Later live
        -- reroutes from the `(9,13)` pocket also confirmed the north lip
        -- into `(8,12)` and `(9,12)` blocks 5/5 from the south.
        --
        -- Nearby candidates did not hold up strongly enough to promote here:
        -- `(3,14)->UP` into `(3,13)` moved 5/5 on stability recheck, and both
        -- `(3,15)->LEFT` into `(2,15)` plus `(4,15)->RIGHT` into `(5,15)`
        -- stayed mixed at `moved=1 blocked=4`. The later east-wall reroute
        -- band then finally settled cleanly too: direct 5/5 verifiers from
        -- `(9,13..17)->RIGHT` confirmed the west-facing strip into
        -- `(10,13..17)`. Once that strip was modeled, the route peeled farther
        -- west and exposed another clean corner cluster: `(6,13)->UP`,
        -- `(7,13)->UP`, and `(6,13)->LEFT` all blocked 5/5 into `(6,12)`,
        -- `(7,12)`, and `(5,13)`. The later south-loop attempt also confirmed
        -- `(5,17)->DOWN` blocks 5/5 into `(5,18)` from the north. After the
        -- resumed route post-combat, the left pocket finally settled too:
        -- `(2,16)->UP`, `(3,15)->LEFT`, and a later rerun of `(2,16)->LEFT`
        -- all blocked 5/5 into `(2,15)` from the south/east and `(1,16)` from
        -- the east. The next upper approach then confirmed `(2,9)->RIGHT` and
        -- `(2,8)->RIGHT` both block 5/5 into `(3,9)` and `(3,8)` from the
        -- west. A later retry from `(2,8)` toward the lower B4 stair then
        -- exposed the remaining west pocket lip: `(2,8)->UP`,
        -- `(2,8)->LEFT`, `(2,9)->LEFT`, `(2,10)->RIGHT`, and
        -- `(2,11)->RIGHT` all blocked 5/5 into `(2,7)`, `(1,8)`, `(1,9)`,
        -- `(3,10)`, and `(3,11)`. The follow-up live dig from the southwest
        -- stair chain superseded the older mixed/open reads around the lower
        -- B4-stair approach: direct verifiers cleanly confirmed the west entry
        -- into `(5,2)`, north entries into `(6,2)`, `(3,5)`, and `(2,7)`,
        -- the double-sided choke at `(3,13)`, the north entry into `(2,15)`,
        -- the east-entry strip into `(1,10)`, `(1,11)`, `(1,14)`, and
        -- `(1,17)`, plus the north lips into `(2,18)`, `(3,18)`, `(4,18)`,
        -- and `(9,18)`. A hidden-wall candidate at `(4,14)` later moved 6/6
        -- from the south, but that is still route evidence only and should
        -- stay out of the permanent model for now. The follow-up sealed-state
        -- pass on 2026-06-02 then compared the stable 49-edge B3 runtime
        -- reseed against the frontier debugger and promoted the remaining
        -- model-consistent approach blocks around the bridge strip, top pocket,
        -- and lower-B4-stair approach. The 2026-06-05 live continuation then
        -- exposed two missing opposite approaches in that same strip:
        -- `(4,13)->RIGHT` into `(5,13)` and `(6,4)->LEFT` into `(5,4)` each
        -- blocked 5/5 under direct verifier. The same post-reload dig crossed
        -- a suspect top-side seam to `(8,6)`, then cleanly confirmed the
        -- target-side pocket is sealed from `(9,6)` by `(8,6).east`,
        -- `(10,6).west`, and `(9,7).north`; the Silver Harp return route
        -- then confirmed `(11,6)->LEFT` into `(10,6)` blocked 5/5 too.
        -- The 2026-06-06 central-stair pocket check then confirmed
        -- `(6,11)->LEFT` into `(5,11)` and `(7,11)->DOWN` into `(7,12)`
        -- with repeated live route retries plus same-origin probes.
        -- The lower-stair harp route later confirmed `(10,8)->UP` into
        -- `(10,7)` blocked twice under same-origin `probe_edge`; the return
        -- route from the harp chest similarly confirmed `(13,8)->DOWN` into
        -- `(13,9)` blocked twice.
        -- The same lower-stair side object-pruning pass then chased false
        -- reachable top-object routes and promoted only same-origin double
        -- probe confirmations around rows 3-9. The follow-up Northwest Stairs
        -- Up pocket cleanup closed the false route to the west chest: the
        -- `(10,1)->LEFT`, row-2 down probes into `(10..15,3)`, and
        -- `(15,1/2)->RIGHT` all blocked from normally walked same-origin
        -- positions; with those runtime blocks, only the Northwest Stairs Up
        -- remained reachable in that pocket.
        -- The 2026-06-07 Northeast Stairs Up pocket cleanup confirmed the
        -- northwest-stair/chest bypasses are sealed at the east side:
        -- `(17,1)->LEFT`, `(17,2)->LEFT`, `(17,2)->DOWN`, `(18,2)->DOWN`,
        -- and `(19,2)->DOWN` all blocked under same-origin live probes.
        -- The same-day Southeast Stairs Up pocket pass chased the false
        -- Silver Harp chest route through the lower and southeast floor
        -- space. Every entry below from the y=18/19 bottom-row strip and the
        -- southeast rows 12-18 comes from live same-origin `probe_edge`
        -- confirmation after battle/menu interruptions were cleared.
        -- The 2026-06-15 Cursed Belt search then superseded the old mixed
        -- `(5,15).west` note with clean same-origin probes from the accessible
        -- southwest side. It promoted the west-chest approach at `(3,1).west`,
        -- the sealed `(5,15)` pocket, and the remaining row-14/16/18 runtime
        -- closures that made `debug_route_frontier:1,1,100` report no hidden
        -- bridge candidates from the current component.
        -- The 2026-06-16 NW/top-row rerun kept the `(9,0)<->(10,0)`
        -- passthrough, but closed the false Cursed Belt route exposed by that
        -- passthrough: same-origin probes blocked `(14,1)->LEFT`,
        -- `(9,0)->DOWN`, and the remaining hidden candidate `(10,2)->LEFT`.
        -- The follow-up chest-side dig proved `(1,2)` and `(2,2)` are
        -- standable false-wall cells, but their south exits into `(1,3)` and
        -- `(2,3)` block under repeated same-origin probes. The return-route
        -- cleanup then closed the east exits from the left-edge strip, the
        -- false row-1 shortcuts through `(3,1)`/`(9,1)`/`(11,1)`, and the
        -- lower-left detours the live route used before it found the real
        -- west-edge entry.
        -- The follow-up object-pruning dig from `Northwest Stairs Up` found
        -- the false reachable routes to `Upper Stairs Down`, `Southeast
        -- Stairs Up`, and `Southwest Stairs Up` all collapse behind two
        -- normally walked same-origin probes: `(5,1)->DOWN` into `(5,2)` and
        -- `(1,6)->DOWN` into `(1,7)`.
        ["3,1"] = {east = true, west = true},
        ["9,1"] = {east = true, north = true, west = true},
        ["11,1"] = {west = true},
        ["13,1"] = {east = true},
        ["16,1"] = {east = true, west = true},
        ["5,2"] = {north = true, west = true},
        ["6,2"] = {north = true, south = true},
        ["8,2"] = {south = true},
        ["9,2"] = {east = true},
        ["16,2"] = {east = true, west = true},
        ["1,3"] = {north = true, west = true},
        ["2,3"] = {north = true, south = true},
        ["3,3"] = {east = true},
        ["1,4"] = {east = true, west = true},
        ["1,5"] = {east = true, south = true, west = true},
        ["5,3"] = {east = true, west = true},
        ["7,3"] = {south = true, east = true, west = true},
        ["9,3"] = {south = true, west = true},
        ["10,3"] = {north = true},
        ["11,3"] = {north = true},
        ["12,3"] = {north = true, south = true},
        ["13,3"] = {north = true, south = true},
        ["14,3"] = {north = true, south = true},
        ["15,3"] = {north = true},
        ["17,3"] = {north = true, south = true},
        ["18,3"] = {north = true, south = true},
        ["19,3"] = {north = true, south = true},
        ["5,4"] = {east = true, west = true},
        ["10,4"] = {west = true},
        ["11,4"] = {east = true, south = true},
        ["15,4"] = {south = true, west = true},
        ["16,4"] = {east = true},
        ["3,5"] = {north = true, west = true},
        ["4,5"] = {north = true, south = true},
        ["5,5"] = {south = true, east = true},
        ["7,5"] = {north = true, east = true, west = true},
        ["10,5"] = {east = true, west = true},
        ["16,5"] = {west = true},
        ["17,5"] = {north = true, south = true},
        ["18,5"] = {east = true, north = true},
        ["16,6"] = {east = true, west = true},
        ["3,6"] = {east = true, west = true},
        ["7,6"] = {west = true},
        ["8,6"] = {north = true, south = true, east = true},
        ["9,6"] = {north = true},
        ["10,6"] = {east = true, west = true},
        ["18,6"] = {east = true, west = true},
        ["1,7"] = {north = true},
        ["2,7"] = {north = true, south = true},
        ["3,7"] = {east = true, west = true},
        ["5,7"] = {north = true, west = true},
        ["7,7"] = {east = true, west = true},
        ["9,7"] = {north = true, west = true},
        ["10,7"] = {east = true, south = true},
        ["16,7"] = {east = true, west = true},
        ["18,7"] = {east = true, south = true, west = true},
        ["1,8"] = {east = true},
        ["3,8"] = {east = true, west = true},
        ["7,8"] = {east = true, west = true},
        ["9,8"] = {east = true, west = true},
        ["15,8"] = {north = true, west = true},
        ["16,8"] = {east = true},
        ["1,9"] = {east = true},
        ["3,9"] = {east = true, west = true},
        ["7,9"] = {east = true, west = true},
        ["9,9"] = {east = true, west = true},
        ["12,9"] = {north = true, west = true},
        ["13,9"] = {north = true, south = true},
        ["14,9"] = {north = true},
        ["15,9"] = {south = true},
        ["16,9"] = {east = true, south = true},
        ["1,10"] = {east = true},
        ["3,10"] = {east = true, west = true},
        ["5,10"] = {north = true, west = true},
        ["6,10"] = {north = true, south = true, west = true},
        ["7,10"] = {south = true, east = true},
        ["9,10"] = {south = true, west = true},
        ["10,10"] = {north = true, south = true},
        ["11,10"] = {north = true, south = true},
        ["12,10"] = {south = true, east = true},
        ["14,10"] = {east = true, west = true},
        ["18,10"] = {west = true},
        ["1,11"] = {east = true},
        ["3,11"] = {east = true, west = true},
        ["5,11"] = {east = true, north = true, west = true},
        ["14,11"] = {east = true, west = true},
        ["1,12"] = {east = true},
        ["3,12"] = {east = true, west = true},
        ["5,12"] = {west = true},
        ["6,12"] = {north = true, south = true},
        ["7,12"] = {north = true, south = true},
        ["8,12"] = {north = true, south = true},
        ["9,12"] = {north = true, south = true},
        ["10,12"] = {north = true},
        ["11,12"] = {north = true, south = true},
        ["12,12"] = {north = true, south = true},
        ["13,12"] = {north = true, south = true},
        ["14,12"] = {south = true},
        ["15,12"] = {east = true, north = true, south = true},
        ["17,12"] = {east = true},
        ["1,13"] = {east = true},
        ["3,13"] = {south = true, east = true, west = true},
        ["5,13"] = {east = true, west = true},
        ["10,13"] = {east = true, west = true},
        ["17,13"] = {east = true},
        ["1,14"] = {east = true},
        ["5,14"] = {west = true},
        ["8,14"] = {east = true, north = true, west = true},
        ["10,14"] = {east = true, west = true},
        ["17,14"] = {south = true},
        ["18,14"] = {east = true, south = true},
        ["2,15"] = {north = true, south = true, east = true},
        ["5,15"] = {east = true, west = true},
        ["8,15"] = {east = true, west = true},
        ["10,15"] = {east = true, west = true},
        ["16,15"] = {east = true},
        ["1,16"] = {east = true},
        ["4,16"] = {north = true, south = true, west = true},
        ["5,16"] = {south = true},
        ["6,16"] = {north = true, south = true},
        ["7,16"] = {north = true, south = true},
        ["8,16"] = {east = true, south = true},
        ["10,16"] = {west = true},
        ["11,16"] = {north = true, south = true},
        ["12,16"] = {north = true, south = true},
        ["13,16"] = {north = true, south = true},
        ["14,16"] = {east = true, north = true, south = true},
        ["16,16"] = {east = true},
        ["18,16"] = {east = true, west = true},
        ["1,17"] = {east = true},
        ["10,17"] = {east = true, west = true},
        ["16,17"] = {east = true},
        ["18,17"] = {west = true},
        ["1,18"] = {south = true},
        ["2,18"] = {north = true, south = true},
        ["3,18"] = {north = true, south = true},
        ["4,18"] = {north = true, south = true},
        ["5,18"] = {north = true, south = true},
        ["6,18"] = {north = true, south = true},
        ["8,18"] = {north = true, south = true},
        ["9,18"] = {north = true, south = true},
        ["10,18"] = {south = true},
        ["11,18"] = {north = true, south = true},
        ["12,18"] = {north = true, south = true},
        ["13,18"] = {north = true, south = true},
        ["14,18"] = {east = true, north = true, south = true},
        ["17,18"] = {north = true},
        ["18,18"] = {east = true},
    },

    -- Map 0x1B: Garin's Grave B4
    [0x1B] = {
        -- 2026-06-06 Silver Harp connector dig from B4 West Stairs Up to
        -- East Stairs Up, then stabilization for the return route. These are
        -- live same-origin probe confirmations after the user returned from
        -- the inn; teleport was only used for coarse repositioning, then the
        -- route was normalized by walking before direct probes.
        -- Autowalk-only candidates such as `(5,2).west`, `(7,1).west`, and
        -- `(6,3).north` are intentionally left out until they have direct
        -- same-origin probe confirmation.
        -- Do not model `(4,7).north`: later live movement from `(4,6)->DOWN`
        -- reached `(4,7)`, disproving that earlier battle-interrupted guess.
        ["3,1"] = {east = true, south = true},
        ["2,2"] = {east = true},
        ["5,2"] = {east = true},
        ["1,3"] = {south = true},
        ["5,3"] = {south = true},
        ["6,3"] = {south = true},
        ["3,4"] = {south = true, west = true},
        ["4,4"] = {east = true},
        ["4,5"] = {south = true, west = true},
        ["1,5"] = {east = true, north = true},
        ["5,5"] = {north = true},
        ["6,5"] = {east = true, north = true, south = true},
        ["2,6"] = {east = true, north = true},
        ["5,6"] = {east = true, south = true, west = true},
        ["3,7"] = {east = true, north = true},
        ["7,7"] = {north = true, west = true},
    },

    -- Map 0x0B: Rimuldar
    [0x0B] = {
        -- 2026-05-17 first town walkabout. The exit-route replan from
        -- (28,14) repeatedly failed moving UP into (28,13), including the
        -- seam brute-force retry, while (29,14)->UP into the confirmed east
        -- exit tile at (29,13) moved cleanly. Fresh NPC dump showed no NPC at
        -- (28,13)/(28,14), so keep this as a directional south-approach wall
        -- rather than NPC clutter or a full-cell block.
        -- The later clean entrance-to-key-shop pass also found the east
        -- approach blocked from (29,13)->LEFT, while the route into and out of
        -- the actual exit tile (29,13) remained open.
        -- 2026-05-21 live recheck on a restored two-door save changed the
        -- earlier interpretation: `probe_edge_verify:29,13,LEFT,5` blocked 5/5
        -- with no drift, while the reverse `probe_edge_verify:28,13,RIGHT,5`
        -- stepped onto `(29,13)` and then immediately changed to world map.
        -- Model this as a one-way exit seam: `(28,13)` blocks entry from the
        -- east, but `(29,13)` remains the live exit tile.
        ["28,13"] = {south = true, east = true},

        -- 2026-05-17 Magic Key route shakedown. These edges each verified
        -- 3/3 blocked with probe_edge_verify while routing from the east
        -- entrance toward Old Man 1's key counter. Keep them directional.
        -- Earlier (25,12).south/east evidence was mixed, but the later
        -- weapon-route loop blocked both approaches repeatedly before stale
        -- Alt returned, so those edges are promoted below.
        ["24,12"] = {north = true, south = true},
        ["23,12"] = {south = true},
        ["25,11"] = {east = true, west = true},
        ["25,12"] = {east = true, south = true},
        ["20,10"] = {south = true, west = true},
        -- 2026-05-21 entrance-to-Weapons route follow-up:
        -- `probe_edge_verify:20,8,RIGHT,5` blocked entry into (21,8) from
        -- the west 5/5 after the route found the next x=21 barrier.
        ["21,8"] = {west = true},
        ["21,6"] = {west = true},
        ["21,7"] = {west = true},
        ["21,11"] = {west = true},
        ["21,12"] = {south = true, west = true},
        ["24,8"] = {south = true},
        ["13,6"] = {north = true, south = true},
        ["13,8"] = {east = true},
        ["14,6"] = {east = true, north = true, south = true},
        -- Final key-counter maze walls. Autowalk and seam retries repeatedly
        -- found the false exits around the (4,6) public stand: (3,5)->DOWN
        -- into (3,6) blocked 3/3 during the queued route, while stand-side
        -- loops found (4,6)->LEFT into (3,6) and (4,6)->RIGHT into (5,6)
        -- blocked 26+ times each. A follow-up forced raw probe also found
        -- the tempting x=6 descent blocked: (6,3)->DOWN into (6,4) blocked
        -- twice, and (5,5)->DOWN into (5,6) plus (5,5)->RIGHT into (6,5)
        -- blocked after many manual twitches plus direct forced probes. The
        -- return-side shortcut (6,4)->DOWN into (6,5) then verified 3/3
        -- blocked too, so the planner must turn through (5,5)->(4,5)->(4,6)
        -- into the stand. A later reloaded return route repeatedly blocked
        -- (5,4)->RIGHT into (6,4) and (5,3)->RIGHT into (6,3) before stale
        -- Alt resumed, so the viable return now climbs through the upper
        -- hidden lane instead of the x=6 west approaches.
        ["3,6"] = {north = true, east = true},
        -- (5,6) directional is the systematic entry below ({north,south,west});
        -- this slot used to repeat it as {north,west} and was silently dropped
        -- by Lua's last-key-wins rule.
        ["6,4"] = {east = true, north = true, west = true},
        ["6,5"] = {east = true, north = true, west = true},
        ["6,6"] = {east = true},
        ["2,6"] = {west = true},
        ["17,6"] = {east = true},
        ["17,7"] = {east = true},
        -- Entrance-side one-way maze cleanup from the final Magic Key route
        -- pass. The false row-10 north entries into row 9 blocked under raw
        -- verification, while the proven connector is farther east:
        -- (18,10)->UP, then west through row 9, then up through hidden
        -- (16,8). A later fresh run showed the (12,7) false exits are real
        -- after all: both (12,7)->UP into (12,6) and (12,7)->RIGHT into
        -- (13,7) blocked 5/5, then reconfirmed 3/3 after a script restart.
        -- Keep the still-mixed seam at (5,3).east open. A later clean
        -- FCEUX autowalk run showed the false row-6 return drops are real:
        -- (8,6)->RIGHT into (9,6), (9,5)->DOWN into (9,6),
        -- (11,6)->RIGHT into (12,6), (12,5)->DOWN into (12,6), and
        -- (13,5)->DOWN into (13,6) all blocked before stale Alt resumed.
        -- The same entrance-side pass also repeatedly blocked
        -- (18,9)->LEFT into (17,9), superseding the earlier mixed
        -- (17,9).east evidence.
        -- Later return-side autowalk passes through the key-shop lower lane
        -- found multiple false pocket exits before stale Alt reappeared. The
        -- first reached (6,10) cleanly, then repeatedly failed
        -- (6,10)->DOWN into (6,11) and (6,10)->RIGHT into (7,10). A follow-up
        -- after the one-way (4,8)->(4,9) discovery queued a route from
        -- (4,10) and looped cleanly on (4,10)->DOWN into (4,11) and
        -- (5,10)->DOWN into (5,11). Keep these directional-only so the
        -- planner can still use any separately proven approaches later. The
        -- next entrance-side pass then cleanly looped on the false west/down
        -- exits around x=9: (9,10)->LEFT into (8,10), (9,10)->DOWN into
        -- (9,11), (9,13)->UP into (9,12), and (9,13)->LEFT into (8,13).
        -- These happened before stale LeftAlt returned and each had repeated
        -- queued-route plus seam-retry block observations.
        -- The next both-direction test found another clean entrance-side
        -- trio before Alt returned: (22,13)->UP into (22,12),
        -- (10,12)->LEFT into (9,12), and (9,14)->LEFT into (8,14). The return
        -- route then proved the pocket below (3,11) is closed from both
        -- visible exits: (3,11)->DOWN into (3,12) and (3,11)->RIGHT into
        -- (4,11) repeatedly blocked. Exposing the lower hidden lane above is
        -- what keeps the key-shop stand connected after these dead ends are
        -- sealed.
        -- The next loop batch proved the visible south connector into row 17
        -- is also one-way/closed from the east: (18,17)->LEFT into (17,17)
        -- blocked across queued routes and seam retries. That same batch
        -- showed (5,7) is a tiny trap east of the key seller: attempts out of
        -- it to (5,6), (4,7), (6,7), and (5,8) all repeatedly blocked, while
        -- (4,7)->RIGHT into (5,7) remained the earlier one-way entry. The
        -- latest both-direction pass then found high-confidence entrance-side
        -- loops at (7,16)->UP into (7,15) and (7,16)->LEFT into (6,16), each
        -- reaching 80+ blocked observations with no moves before stale Alt
        -- returned. Return-side walking through the lower lane repeatedly
        -- blocked (7,9)->DOWN into (7,10), while nearby (4,9).north,
        -- (4,10).north, and row-14 blips moved on retry and stay open. The
        -- next reloaded pass added clean blocker evidence at the false north
        -- entries from row 17 into (5,16)/(6,16), the dead pocket exits from
        -- (3,14) into (3,13)/(3,15), the lower return drop into (8,10), the
        -- row-6 return entry into (10,6), and the repeatedly blocked east
        -- approach into (6,3). The older (6,3).east move note is superseded
        -- by this later route-shaped 6x block cluster. The latest pre-Alt
        -- FCEUX route batch then added the remaining false entries:
        -- (4,17)->UP into (4,16), (3,17)->UP into (3,16),
        -- (7,12)->UP into (7,11), (4,9)->UP into (4,8),
        -- (6,9)->UP into (6,8), (5,4)->RIGHT into (6,4), and
        -- (5,3)->RIGHT into (6,3). Nearby seams such as (4,5).south,
        -- (5,5).west, (5,3).south, (4,10).north, (6,10).north,
        -- (26,14).east, and (29,14).north all moved on retry or were stale-Alt
        -- contaminated, so they stay unmodeled. The next route/manual pass
        -- sealed the south/west row-15 pocket from (2,16), the row-13 pocket
        -- from (4,13), and the false upper return target (5,2). Manual
        -- movement then found a northwest exit from (4,3)->UP; keep the exit
        -- stand passable, but block (4,2).south so normal in-town A* treats
        -- that edge as a world transition rather than a walkable corridor.
        -- The follow-up FCEUX pass added the next clean one-way walls:
        -- (2,15)->RIGHT into (3,15), (5,12)->LEFT into (4,12), and
        -- (5,12)->UP into (5,11) on the entrance side; (14,5)->DOWN into
        -- (14,6), (24,11)->RIGHT into (25,11), and (24,11)->DOWN into
        -- (24,12) on return. The same run repeatedly blocked (1,7)->RIGHT
        -- into (2,7), and the latest route-shaped pass repeated that failure
        -- cleanly enough to supersede the earlier mixed/open probes. Close
        -- (2,7).west while leaving the cell itself passable. The alternate
        -- one-way connector through (3,8) looked promising, but the later
        -- route-shaped pass repeatedly blocked (3,9)->UP into (3,8) before
        -- stale Alt returned; the earlier manual/probe open result is treated
        -- as noisy. (4,8)->LEFT into (3,8) also blocked 5/5, so model both
        -- (3,8).south and (3,8).east below.
        -- The next log also showed that the selected
        -- Magic Key stand at (4,6) is correct: TALK from there opened the key
        -- shop, but trying to leave south repeatedly hit Old Man 1's occupied
        -- NPC cell at (4,7). Keep (4,6).north open so the public stand is
        -- reachable from the maze, and let object NPC blocking handle (4,7).
        -- The same clean pre-Alt section promoted more one-way maze walls:
        -- (1,15)->RIGHT into (2,15), (6,12)->UP into (6,11),
        -- (7,12)->RIGHT into (8,12), (4,5)->UP into (4,4), and
        -- (4,4)->UP into (4,3). The next route-to-merchant attempt reached
        -- (6,14), then repeatedly alternated between (6,14)->RIGHT into
        -- (7,14) and (6,14)->DOWN into (6,15), both blocked cleanly before
        -- stale Alt returned. The subsequent key-route attempt looped from
        -- (7,13), repeatedly blocking (7,13)->RIGHT into (8,13) and
        -- (7,13)->DOWN into (7,14), also before stale Alt returned.
        -- The stricter manual/projection loop then promoted only the clean
        -- seam-list blockers: (4,15)->LEFT into (3,15), (4,15)->DOWN into
        -- (4,16), and (5,15)->RIGHT into (6,15). After reload, autowalk
        -- reached (5,15) and the fresh seam list showed (5,15)->DOWN into
        -- (5,16) blocked 3/3 with no moves before the next stale-Alt warning.
        -- Direct edge verifiers then confirmed both exits from (5,15):
        -- DOWN into (5,16) and RIGHT into (6,15) each blocked 3/3.
        -- After (2,7).west closed, the upper-left bridge candidates were
        -- checked directly: (1,5)->UP into (1,4) and (1,5)->LEFT into (0,5)
        -- each blocked 5/5, and the later (1,5)->RIGHT into (2,5) candidate
        -- rechecked as a clean route/probe blocker. Follow-up frontier checks
        -- then closed the candidate south entries into (2,8) and (5,8), plus
        -- the x=7 candidate exits left into (6,8), (6,7), and (6,2). The
        -- (3,8)->(3,7)->(3,6) false-wall turn still keeps (3,7) and
        -- (3,6).south open. A clean post-recovery verifier later proved
        -- (1,8)->RIGHT into (2,8) 5/5 passable, making this the missing
        -- west-side bridge while the lower (2,9)->UP approach remains closed.
        -- The lower-lane candidate also self-disproved: (4,8)->RIGHT into
        -- (5,8) blocked 5/5, so do not let A* enter that pocket from the west.
        -- Wings chest room shelf follow-up: after NPCs were frozen,
        -- probe_edge_verify:23,23,DOWN,5 confirmed (23,23)->DOWN into
        -- (23,24) blocked 5/5 despite an open type-8 tile preview. A later
        -- max verifier also flagged (14,19)->RIGHT, but that edge proved noisy
        -- in a fresh run after reload; it now needs to stay open for the main
        -- in-town path. After the row-22 shelf was modeled and the user
        -- reloaded FCEUX,
        -- probe_edge_verify:23,22,UP,5 confirmed (23,22)->UP into (23,21)
        -- blocked 5/5 too. The next Wings route loops directly confirmed
        -- (21,20)->RIGHT into (22,20) blocked 5/5, then the locked-room
        -- return search found the row-22 shelf and lower/right branches are
        -- one-way pockets. Keep these directional: (20,25)->DOWN into
        -- (20,26), (21,25)->DOWN into (21,26), (22,25)->DOWN into
        -- (22,26), (22,25)->RIGHT into (23,25), (20,22)->UP into
        -- (20,21), (20,22)->LEFT into (19,22), and (20,25)->UP into
        -- (20,24) remain blocked. A later probe batch showed
        -- (24,23)->RIGHT into (25,23) and (24,23)->DOWN into (24,24)
        -- are passable; those earlier blocks were removed.
        -- parked-NPC return survey reached (20,23) and hit (20,23)->LEFT
        -- into (19,23); probe_edge_verify confirmed that east approach
        -- blocked 10/10. The same lower-room sweep confirmed (20,23)->DOWN
        -- into (20,24), (22,23)->DOWN into (22,24), and forced-origin
        -- (16,25)->UP into (16,24) as blocked. A fresh teleport/probe could
        -- move (21,23)->DOWN into (21,24), but every legitimate door-side
        -- approach failed: parked survey blocked the edge three times, raw
        -- holds after entering (21,23) from east/west/north all timed out,
        -- and OPEN while facing south reported no door. Keep (21,24).north
        -- closed so A* does not choose that false throat. Forced-origin
        -- checks from the now-proven row-22 branch also blocked
        -- (21,22)->UP and (22,22)->UP, so close the south approaches into
        -- (21,21)/(22,21). Leave (20,21).north open after it moved 5/5, and
        -- leave (21,21).north open after it stayed mixed. The next inn-to-exit
        -- autowalk/direct verifiers confirmed the row-19 south approaches at
        -- (16,20)->UP and (17,20)->UP block, while (17,19).east and
        -- (15,24).south stayed mixed and (21,24).south moved 3/3.
        -- A later drifted exit route stepped (28,16)->RIGHT into (29,16) and
        -- immediately changed to the world map, so guard that transition row
        -- the same way the northwest exit guards (4,2).south.
        ["0,5"] = {east = true},
        ["1,4"] = {south = true},
        ["2,5"] = {west = true},
        -- Block the west approach into (2,7); keep (2,7) itself as a passthrough
        -- hidden-cell connector.
        ["2,7"] = {west = true},
        ["2,8"] = {south = true},
        ["2,15"] = {south = true, west = true},
        ["3,12"] = {north = true},
        ["3,13"] = {south = true, east = true},
        ["3,15"] = {north = true, east = true, west = true},
        ["3,16"] = {south = true, west = true},
        ["3,8"] = {east = true, south = true},
        ["4,2"] = {south = true},
        ["4,3"] = {south = true},
        ["4,4"] = {south = true},
        ["4,7"] = {east = true},
        ["4,8"] = {south = true},
        ["4,12"] = {south = true, east = true},
        ["4,11"] = {north = true, west = true},
        ["4,16"] = {north = true, south = true},
        ["5,2"] = {south = true},
        ["5,6"] = {north = true, south = true, west = true},
        ["5,8"] = {north = true, south = true, west = true},
        ["5,11"] = {north = true, south = true},
        ["5,16"] = {north = true, south = true},
        ["6,3"] = {east = true, west = true},
        ["6,2"] = {east = true},
        ["6,7"] = {east = true, west = true},
        ["6,8"] = {east = true, south = true},
        ["6,11"] = {north = true, south = true},
        ["6,15"] = {north = true, west = true},
        ["6,16"] = {east = true, south = true},
        ["7,14"] = {north = true, west = true},
        ["8,10"] = {east = true, north = true},
        ["8,12"] = {west = true},
        ["8,13"] = {east = true, west = true},
        ["8,14"] = {east = true},
        ["7,10"] = {north = true, west = true},
        ["7,11"] = {south = true},
        ["7,15"] = {south = true},
        ["9,6"] = {north = true, west = true},
        ["9,11"] = {north = true},
        ["9,12"] = {east = true, south = true},
        ["10,6"] = {east = true, north = true},
        -- 2026-05-21: parked-NPC entrance-to-chest reroutes tried the lower
        -- west branch; direct verifiers confirmed these entries blocked 5/5.
        ["12,21"] = {east = true},
        ["12,22"] = {east = true},
        ["12,23"] = {east = true},
        ["12,24"] = {east = true},
        ["12,25"] = {east = true},
        ["12,26"] = {east = true},
        ["12,6"] = {north = true, south = true, west = true},
        ["13,7"] = {east = true, west = true},
        ["13,9"] = {south = true},
        ["14,9"] = {east = true, south = true},
        -- 2026-05-21: after the entrance-to-Wings route stopped overshooting,
        -- direct raw verifiers exposed a real north-approach barrier along
        -- row 17. These entries each blocked 5/5 from y=16; (18,16)->DOWN and
        -- (28,16)->DOWN moved 5/5 and remain open crossings.
        ["19,17"] = {north = true},
        ["20,17"] = {north = true},
        ["21,17"] = {north = true, west = true},
        ["22,17"] = {north = true},
        ["23,17"] = {north = true},
        ["24,17"] = {north = true},
        ["25,17"] = {north = true},
        -- (15,19): one-way row-19 connector. Fresh FCEUX verification after
        -- closing the command menu blocked (14,19)->RIGHT 3/3, while the
        -- reverse (15,19)->LEFT moved 3/3. Close only the west approach.
        ["15,19"] = {west = true},
        -- (15,21): east is a wall tile (16,21 in MAP_BLOCKED_CELLS); north+south engine-blocked; west now confirmed blocked.
        -- North from (15,20) and south from (15,22) were blocked earlier; latest direct probes (14,21->right,5)
        -- stayed blocked with raw hold timeouts even with open directional preview.
        ["15,21"] = {north = true, south = true, west = true},
        -- (15,22): west approach from (14,22) also stays blocked after direct probe 5/5 raw hold timeout.
        -- 2026-05-21 return-route fallback from (16,22) confirmed the east
        -- approach blocked 5/5 too.
        ["15,22"] = {east = true, west = true},
        -- Return-side lower pocket edges. Planned entrance-to-chest routes tried
        -- crossing east from (14,23)/(14,24), but direct FCEUX verifiers blocked
        -- both 5/5. Keep these as directional so nearby row-23/24 cells remain
        -- available from their legitimate approaches.
        -- The later chest-return route also tried entering (15,23) from the
        -- east via (16,23)->LEFT; direct verifier confirmed that approach
        -- blocked 5/5 too.
        ["15,23"] = {east = true, west = true},
        -- 2026-05-21: live autowalk looped between lower-row fallback routes;
        -- direct probe_edge_verify:15,25,UP,5 confirmed this south approach
        -- blocked 5/5 by raw holds.
        ["15,24"] = {west = true, south = true},
        -- 2026-05-21: after the (16,27) reroute, autowalk tried dropping
        -- from (15,27); probe_edge_verify:15,27,DOWN,5 confirmed blocked 5/5.
        ["15,28"] = {north = true},
        -- (15,17): west approach from (14,17) confirmed blocked 5/5 in FCEUX
        -- on 2026-05-20. Reverse (15,17)->LEFT evidence stays modeled separately
        -- as open on (14,17).east.
        ["15,17"] = {west = true},
        ["15,9"] = {south = true},
        ["16,9"] = {south = true},
        -- (16,19): west approach from (15,19) is now confirmed 5/5 blocked in direct `probe_edge_verify` checks.
        ["16,19"] = {south = true, west = true, east = true},
        -- 2026-05-21: return-route fallback reached (17,21) and repeatedly
        -- tried to enter (16,21) from the east; direct
        -- probe_edge_verify:17,21,LEFT,5 confirmed blocked 5/5. A later
        -- fallback from (16,22)->UP confirmed the south approach blocked 5/5
        -- too. A later chest-return autowalk loop and fresh direct
        -- probe_edge_verify:16,20,DOWN,5 then blocked the north approach 5/5
        -- as well, so all three confirmed entries stay closed.
        ["16,21"] = {east = true, south = true, north = true},
        -- 2026-05-21: return-route fallback from (16,23)->DOWN confirmed the
        -- north approach into (16,24) blocked 5/5. The older south approach
        -- blocker remains from the lower-strip forced probe.
        ["16,24"] = {north = true, south = true},
        -- 2026-05-21: lower fallback reroute from the entrance side reached
        -- (16,27), but probe_edge_verify:16,27,DOWN,5 confirmed this north
        -- approach blocked 5/5.
        ["16,28"] = {north = true},
        ["17,9"] = {east = true, south = true},
        ["17,17"] = {east = true},
        ["17,19"] = {south = true},
        -- 2026-05-21: same lower fallback reached (16,27), but
        -- probe_edge_verify:16,27,RIGHT,5 confirmed this west approach
        -- blocked 5/5.
        ["17,27"] = {west = true},
        -- 2026-05-21 chest-return route harvesting: after the noisy
        -- (16,20)->DOWN seam stayed direct-passable, successive fallback
        -- routes tried the row-20 south exits. Direct verifiers confirmed
        -- (18,20)->DOWN, (19,20)->DOWN, and (20,20)->DOWN all blocked 5/5.
        -- The next reroute crossed through (17,21) and tried (17,21)->RIGHT;
        -- direct verifier confirmed that west approach into (18,21) too.
        ["18,21"] = {north = true, west = true},
        ["19,21"] = {north = true},
        ["19,22"] = {east = true},
        ["19,23"] = {east = true},
        ["20,21"] = {north = true, south = true},
        ["20,24"] = {north = true, south = true},
        ["20,26"] = {north = true},
        -- 2026-05-21: row-25 fallback tried entering from the south, but
        -- probe_edge_verify:21,25,UP,5 confirmed blocked 5/5.
        ["21,24"] = {north = true, south = true},
        ["21,26"] = {north = true},
        -- (21,20) west approach is a confirmed one-way seam:
        -- `probe_edge_verify:21,20,right,10` stayed blocked 10/10 on clean
        -- probe runs, while `22,20`->LEFT is confirmed passable 10/10.
        ["21,20"] = {west = true},
        ["22,12"] = {south = true},
        -- 2026-05-21: chest-return autowalk from the lower fallback area
        -- looped on (23,20)->LEFT into (22,20); direct verifier confirmed
        -- the east approach blocked 5/5. The older west approach remains
        -- from the Wings route verifier.
        ["22,20"] = {east = true, west = true},
        -- 2026-05-20: `probe_edge_verify:24,20,RIGHT,5` was confirmed
        -- blocked 5/5 as a one-way wall. Keep reverse approach open.
        ["24,20"] = {east = true},
        -- 2026-05-21: once row-17 north approaches were modeled, the next
        -- entrance-to-chest route tried (21,21)->RIGHT into (22,21). Direct
        -- raw verification blocked 5/5, so close only the west approach.
        ["22,21"] = {west = true},
        -- The follow-up return-route fallback from (24,22) repeatedly tried
        -- to enter the upper shelf at (24,21); direct
        -- probe_edge_verify:24,22,UP,5 confirmed this south approach blocked
        -- 5/5. Keep (24,22)<->(24,23) open; that edge moved during the same
        -- run and is only noisy.
        ["24,21"] = {south = true},
        -- 2026-05-21: after the outer-door-to-chest route succeeded, the
        -- chest-to-exit/entrance return planner looped on (23,20)->DOWN.
        -- Direct probe_edge_verify:23,20,DOWN,5 confirmed the north approach
        -- into (23,21) blocked 5/5. The next live return-route run then
        -- looped on (23,22)->UP; direct probe_edge_verify:23,22,UP,5
        -- confirmed the south approach blocked 5/5 too.
        ["23,21"] = {north = true, south = true},
        -- Same return-route run alternated with (23,22)->LEFT into the
        -- row-22 shelf; direct probe_edge_verify:23,22,LEFT,5 confirmed this
        -- east approach into (22,22) blocked 5/5.
        ["22,22"] = {east = true},
        ["22,26"] = {north = true},
        ["23,25"] = {west = true},
        -- 2026-05-21: full entrance-to-chest validation first tried crossing
        -- west from (29,17); probe_edge_verify:29,17,LEFT,5 blocked 5/5.
        -- (28,16)->DOWN into this cell moved 5/5, so keep the north approach
        -- open and close only the east approach.
        ["28,17"] = {east = true},
        ["29,16"] = {west = true},
    },

    -- Map 0x15: Swamp Cave lower return route
    --
    -- 2026-05-16 route from the south-island exit area back to the original
    -- entrance exposed one-way cave seams below the west-corridor bend. Keep
    -- these directional-only: the route-shaped log proves specific failed
    -- approaches, while other approaches should remain available until direct
    -- probes say otherwise.
    [0x15] = {
        -- 2026-06-21 Swamp Cave sweep/autowalk validation: non-teleport
        -- verify_walked_edge reached each origin by normal movement, then
        -- raw-held into an open preview that stayed blocked.
        ["2,14"] = {north = true, south = true}, -- blocked from (2,13)->DOWN and later (2,15)->UP
        ["3,9"] = {north = true}, -- (3,8)->DOWN blocked
        ["4,8"] = {west = true}, -- (3,8)->RIGHT blocked
        ["1,24"] = {south = true}, -- (1,25)->UP blocked, retried, then became PATH_RUNTIME_BLOCK
        ["1,27"] = {north = true, south = true}, -- north blocked 28x from (1,26); south blocked from (1,28)
        ["2,28"] = {south = true, east = true, west = true}, -- failed from (2,29), (3,28), and (1,28)
        ["2,27"] = {north = true, east = true}, -- north blocked 26x from (2,26); east blocked from (3,27)
        -- Gwaelin Door route: south-exit-to-door auto-walk looped at (3,23)
        -- until stopped, then direct edge probes confirmed both approaches
        -- block despite walkable tile previews.
        ["3,22"] = {south = true, north = true}, -- (3,23)->UP and later (3,21)->DOWN blocked
        ["4,23"] = {west = true, east = true}, -- blocked from (3,23)->RIGHT and (5,23)->LEFT
        -- Follow-up post-battle route from (3,26) toward Gwaelin Door looped
        -- on (3,24)->RIGHT. probe_edge_verify:3,24,RIGHT,3 confirmed 3/3
        -- blocked despite an open tile preview. The nearby (2,23)->UP seam
        -- was initially mixed, then later confirmed blocked 3/3 after the
        -- lower detour reached the west side. The next loops confirmed the
        -- north edge into (5,22), west edge into (4,23), (4,25)->UP into
        -- (4,24), (1,23)->UP into (1,22), and west-edge re-entries from
        -- (0,19)->RIGHT into (1,19), (0,20)->RIGHT into (1,20),
        -- (0,21)->RIGHT into (1,21), and (0,22)->RIGHT into (1,22) as
        -- blocked 3/3. Follow-up manual validation found the x=0 corridor's
        -- east re-entry blocked through (0,9)->RIGHT, with (0,8) the first
        -- open eastward cell. A later reverse-route polish cleanly confirmed
        -- the formerly mixed (5,24)->LEFT into (4,24) seam plus lower return
        -- reroute blockers at (3,29)->RIGHT, (3,26)->RIGHT, and
        -- (3,25)->LEFT.
        -- 2026-06-22 South Stairs Up polish used auto_walk_blocker from the
        -- opened-door / Princess route side. The west-corridor route remained
        -- passable through (1,26)..(0,29), while these route-derived seams
        -- repeatedly blocked and then allowed the route to reach (0,29).
        ["1,9"] = {west = true, east = true, north = true},
        ["1,10"] = {west = true, east = true},
        ["1,11"] = {west = true, east = true},
        ["1,12"] = {west = true, east = true},
        ["1,13"] = {west = true, east = true},
        ["1,14"] = {west = true},
        ["1,15"] = {west = true, east = true},
        ["1,16"] = {west = true, east = true},
        ["1,17"] = {west = true, east = true},
        ["1,18"] = {west = true, east = true},
        ["1,19"] = {west = true, east = true},
        ["1,20"] = {west = true, east = true},
        ["1,21"] = {west = true, east = true},
        ["1,22"] = {south = true, west = true},
        ["2,22"] = {south = true, north = true},
        ["2,25"] = {west = true, east = true},
        ["3,14"] = {north = true, east = true, south = true},
        ["3,16"] = {north = true, west = true},
        ["3,17"] = {west = true},
        ["3,18"] = {west = true},
        ["3,19"] = {west = true},
        ["3,20"] = {south = true, west = true},
        ["4,16"] = {north = true},
        ["4,20"] = {south = true},
        ["4,22"] = {north = true},
        ["4,24"] = {west = true, south = true, east = true},
        ["4,26"] = {west = true},
        ["4,29"] = {west = true},
        ["5,16"] = {north = true},
        ["5,22"] = {south = true, north = true},
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

function M.get_door_cell_context(map_id, x, y)
    local door_cells = MAP_DOOR_CELLS[map_id]
    local key = x .. "," .. y
    local dc = door_cells and door_cells[key]
    if not dc then
        return nil
    end

    local open_slots = {}
    local open = false
    for i = 0, addr.DOOR_ARRAY_MAX - 1 do
        local dx = memory.readbyte(addr.DOOR_X_POS_START + i * addr.DOOR_ARRAY_STRIDE)
        local dy = memory.readbyte(addr.DOOR_Y_POS_START + i * addr.DOOR_ARRAY_STRIDE)
        if dx ~= 0 then
            open_slots[#open_slots + 1] = string.format("%d:%d,%d", i, dx, dy)
            if dx == dc.x and dy == dc.y then
                open = true
            end
        end
    end

    return {
        is_door = true,
        x = x,
        y = y,
        door_x = dc.x,
        door_y = dc.y,
        open = open,
        open_slots = open_slots,
    }
end

function M.get_walkability_snapshot(map_id, opts)
    opts = opts or {}
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
    local allow_hazards = opts.allow_hazards == true

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
            if hazards and hazards[key] and not allow_hazards then
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
