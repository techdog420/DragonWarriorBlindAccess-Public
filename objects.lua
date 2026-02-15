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

-- Human-readable names for each filter mode
local FILTER_NAMES = {
    [M.FILTER_ALL]   = "All",
    [M.FILTER_NPC]   = "NPCs",
    [M.FILTER_EXIT]  = "Exits",
    [M.FILTER_CHEST] = "Chests",
    [M.FILTER_STAIR] = "Stairs",
}

-- How many filter modes there are (for wraparound)
local FILTER_COUNT = 5

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
-- Hard-Coded Stair/Warp Locations
-- ============================================================
-- Since the ROM format for stair data isn't fully documented,
-- we hard-code known locations for the most important early-game
-- maps. Each entry: {map_id, x, y, name, dest_description}
--
-- These will be replaced with ROM reading once we reverse-engineer
-- the stair data format at ROM 0xF3D8-0xF50B.

local STAIRS = {
    -- Tantegel Castle (0x08)
    -- Stairs down to throne room
    {map = 0x08, x = 1, y = 1, name = "Stairs Down", dest = "Throne Room"},
    -- Stairs leading to the courtyard treasure room
    {map = 0x08, x = 29, y = 1, name = "Stairs Down", dest = "Treasure Room"},

    -- Tantegel Castle Throne Room (0x09)
    -- Stairs back up to the main castle floor
    {map = 0x09, x = 1, y = 1, name = "Stairs Up", dest = "Tantegel Castle"},

    -- Erdrick's Cave B1 (0x12)
    {map = 0x12, x = 1, y = 1, name = "Stairs Down", dest = "B2"},

    -- Erdrick's Cave B2 (0x13)
    {map = 0x13, x = 1, y = 1, name = "Stairs Up", dest = "B1"},

    -- Swamp Cave (0x17)
    {map = 0x17, x = 0, y = 0, name = "Stairs Up", dest = "World Map"},

    -- Mountain Cave (0x18)
    {map = 0x18, x = 6, y = 5, name = "Stairs Down", dest = "B2"},

    -- Mountain Cave B2 (0x19)
    {map = 0x19, x = 6, y = 5, name = "Stairs Up", dest = "Mountain Cave"},

    -- Garin's Grave B1 (0x1A)
    {map = 0x1A, x = 19, y = 0, name = "Stairs Down", dest = "B2"},

    -- Garin's Grave B2 (0x1B)
    {map = 0x1B, x = 19, y = 0, name = "Stairs Up", dest = "B1"},
    {map = 0x1B, x = 12, y = 12, name = "Stairs Down", dest = "B3"},

    -- Garin's Grave B3 (0x1C)
    {map = 0x1C, x = 12, y = 12, name = "Stairs Up", dest = "B2"},
    {map = 0x1C, x = 1, y = 1, name = "Stairs Down", dest = "B4"},

    -- Garin's Grave B4 (0x1D)
    {map = 0x1D, x = 1, y = 1, name = "Stairs Up", dest = "B3"},

    -- Charlock Castle (0x0A)
    {map = 0x0A, x = 10, y = 1, name = "Stairs Down", dest = "B1"},

    -- Charlock Castle B1-B7 (0x01-0x07)
    {map = 0x01, x = 10, y = 1, name = "Stairs Up", dest = "Charlock Castle"},
    {map = 0x01, x = 7, y = 7, name = "Stairs Down", dest = "B2"},
    {map = 0x02, x = 7, y = 7, name = "Stairs Up", dest = "B1"},
    {map = 0x02, x = 3, y = 3, name = "Stairs Down", dest = "B3"},
    {map = 0x03, x = 3, y = 3, name = "Stairs Up", dest = "B2"},
    {map = 0x03, x = 7, y = 7, name = "Stairs Down", dest = "B4"},
    {map = 0x04, x = 7, y = 7, name = "Stairs Up", dest = "B3"},
    {map = 0x04, x = 1, y = 1, name = "Stairs Down", dest = "B5"},
    {map = 0x05, x = 1, y = 1, name = "Stairs Up", dest = "B4"},
    {map = 0x05, x = 7, y = 7, name = "Stairs Down", dest = "B6"},
    {map = 0x06, x = 7, y = 7, name = "Stairs Up", dest = "B5"},
    {map = 0x06, x = 4, y = 4, name = "Stairs Down", dest = "B7"},

    -- Charlock B7 - Dragonlord's Throne Room (0x07)
    {map = 0x07, x = 4, y = 4, name = "Stairs Up", dest = "B6"},

    -- Charlock B8 (0x16) — hidden basement
    {map = 0x16, x = 9, y = 0, name = "Stairs Up", dest = "Charlock Castle"},
}

-- ============================================================
-- Hard-Coded Exit Locations
-- ============================================================
-- Exits are the tiles that return you to the parent map (usually
-- the overworld). For towns, this is usually the bottom edge.
-- For dungeons, this is usually near the entrance stairs.

local EXITS = {
    -- Towns — exits are at the town entrance (south edge usually)
    {map = 0x0C, x = 15, y = 29, name = "Exit", dest = "World Map"},      -- Tantegel Town
    {map = 0x0D, x = 15, y = 14, name = "Exit", dest = "World Map"},      -- Kol
    {map = 0x0E, x = 15, y = 29, name = "Exit", dest = "World Map"},      -- Brecconary
    {map = 0x0F, x = 15, y = 14, name = "Exit", dest = "World Map"},      -- Garinham
    {map = 0x10, x = 14, y = 29, name = "Exit", dest = "World Map"},      -- Cantlin
    {map = 0x11, x = 15, y = 14, name = "Exit", dest = "World Map"},      -- Rimuldar

    -- Castles — exits are typically at the south entrance
    {map = 0x08, x = 15, y = 29, name = "Exit", dest = "World Map"},      -- Tantegel Castle
    {map = 0x0A, x = 10, y = 19, name = "Exit", dest = "World Map"},      -- Charlock Castle

    -- Shrines
    {map = 0x14, x = 4, y = 4, name = "Exit", dest = "World Map"},        -- Northern Shrine
    {map = 0x15, x = 4, y = 4, name = "Exit", dest = "World Map"},        -- Southern Shrine

    -- Cave entrances (the "stairs up" at the entrance)
    {map = 0x12, x = 0, y = 0, name = "Exit", dest = "World Map"},        -- Erdrick's Cave B1
    {map = 0x18, x = 0, y = 0, name = "Exit", dest = "World Map"},        -- Mountain Cave
    {map = 0x1A, x = 0, y = 0, name = "Exit", dest = "World Map"},        -- Garin's Grave B1
}

-- ============================================================
-- State
-- ============================================================

-- The current combined object list for this map
local object_list = {}

-- The filtered view of the object list (what the player cycles through)
local filtered_list = {}

-- Current selection index (1-based, into filtered_list)
local current_index = 1

-- Current filter mode
local current_filter = M.FILTER_ALL

-- Which map we last built the object list for (to detect map changes)
local current_map_id = nil

-- Frame counter for periodic NPC position updates
local npc_refresh_counter = 0
local NPC_REFRESH_INTERVAL = 20  -- Re-read NPC positions every 20 frames (~0.33s)

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
        local chest_y = rom.readbyte(base + 2)

        if chest_map == map_id then
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
local function build_object_list(map_id)
    local _, px, py = nav.get_position()
    local objects = {}

    -- Gather objects from all sources
    local npcs = parse_npcs(map_id)
    for _, npc in ipairs(npcs) do
        objects[#objects + 1] = npc
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
local function rebuild_filtered_list()
    filtered_list = apply_filter(object_list, current_filter)

    -- Clamp the current index to the new list size
    if current_index > #filtered_list then
        current_index = 1
    end
    if current_index < 1 then
        current_index = 1
    end
end

-- ============================================================
-- Public API: List Management
-- ============================================================

-- refresh(map_id): Rebuild the entire object list for a new map.
-- Call this on map changes. Resets selection to the first object.
function M.refresh(map_id)
    current_map_id = map_id
    object_list = build_object_list(map_id)
    current_index = 1
    rebuild_filtered_list()
end

-- update_npcs(): Re-read NPC positions from RAM without doing a full
-- rebuild. Preserves the current selection by matching object IDs.
-- Call this periodically (every ~20 frames) since NPCs move.
function M.update_npcs()
    if current_map_id == nil then return end

    -- Remember which object is currently selected (by ID)
    local selected_id = nil
    if filtered_list[current_index] then
        selected_id = filtered_list[current_index].id
    end

    -- Rebuild the full list (NPCs may have moved)
    object_list = build_object_list(current_map_id)
    rebuild_filtered_list()

    -- Try to restore selection by ID
    if selected_id then
        for i, obj in ipairs(filtered_list) do
            if obj.id == selected_id then
                current_index = i
                return
            end
        end
    end
    -- If we couldn't find the previously selected object, index
    -- stays wherever rebuild_filtered_list() clamped it.
end

-- check_refresh(map_id): Called every frame from the main loop.
-- Handles map-change detection and periodic NPC position refresh.
function M.check_refresh(map_id)
    -- Full rebuild on map change
    if map_id ~= current_map_id then
        M.refresh(map_id)
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
    return obj.name .. ": " .. direction
end

-- describe_current(): Describe the currently selected object.
-- Includes the object's position in the list (e.g., "2 of 5").
function M.describe_current()
    if #filtered_list == 0 then
        return "No objects found"
    end

    local obj = filtered_list[current_index]
    local desc = M.describe_object(obj)
    return desc .. " (" .. current_index .. " of " .. #filtered_list .. ")"
end

return M
