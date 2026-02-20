-- pathfinder.lua
-- A* pathfinding for Dragon Warrior grid maps.
--
-- Finds the shortest walkable path between two points on an interior
-- map (towns, castles, dungeons). Uses the tile grid from map_reader.lua
-- to determine which tiles are passable.
--
-- Key design decisions:
-- - 4-directional movement only (no diagonals — DW1 grid movement)
-- - Manhattan distance heuristic (optimal for 4-directional grids)
-- - Grid-based neighbor lookup for O(1) adjacency checks
-- - NPC positions can be marked as impassable (can't walk through them)
-- - Skips overworld (map 0x00) — too large, use direction+distance instead
-- - Returns path as grouped direction steps: "3 north, 2 east, 1 north"
--
-- Based on standard A* algorithm, adapted for DW1's tile system.
-- Reference: pokemon-access a-star.lua (MIT licensed)

local map_reader = require "map_reader"

local M = {}

-- ============================================================
-- Direction Constants
-- ============================================================
-- The four cardinal directions as (dx, dy) offsets.
-- In DW1: +X = east (right), +Y = south (down)
local DIRECTIONS = {
    {dx =  0, dy = -1, name = "north"},
    {dx =  0, dy =  1, name = "south"},
    {dx = -1, dy =  0, name = "west"},
    {dx =  1, dy =  0, name = "east"},
}

-- ============================================================
-- Priority Queue (Min-Heap)
-- ============================================================
-- A simple binary min-heap for the A* open set. Each entry has a
-- priority (f-score) and a value (the node). Lower priority = higher
-- urgency (explored first).
--
-- We need this because Lua doesn't have a built-in priority queue,
-- and scanning a flat list for the minimum would be O(n) per step.

local function heap_new()
    return {data = {}, size = 0}
end

-- heap_push(heap, priority, value): Add an element to the heap.
local function heap_push(heap, priority, value)
    heap.size = heap.size + 1
    heap.data[heap.size] = {priority = priority, value = value}

    -- Bubble up: swap with parent while smaller
    local i = heap.size
    while i > 1 do
        local parent = math.floor(i / 2)
        if heap.data[i].priority < heap.data[parent].priority then
            heap.data[i], heap.data[parent] = heap.data[parent], heap.data[i]
            i = parent
        else
            break
        end
    end
end

-- heap_pop(heap): Remove and return the element with the lowest priority.
-- Returns priority, value. Returns nil, nil if empty.
local function heap_pop(heap)
    if heap.size == 0 then return nil, nil end

    local top = heap.data[1]
    heap.data[1] = heap.data[heap.size]
    heap.data[heap.size] = nil
    heap.size = heap.size - 1

    -- Bubble down: swap with smallest child while larger
    local i = 1
    while true do
        local left = i * 2
        local right = i * 2 + 1
        local smallest = i

        if left <= heap.size and heap.data[left].priority < heap.data[smallest].priority then
            smallest = left
        end
        if right <= heap.size and heap.data[right].priority < heap.data[smallest].priority then
            smallest = right
        end

        if smallest ~= i then
            heap.data[i], heap.data[smallest] = heap.data[smallest], heap.data[i]
            i = smallest
        else
            break
        end
    end

    return top.priority, top.value
end

-- ============================================================
-- A* Pathfinding
-- ============================================================

-- find_path(map_id, start_x, start_y, goal_x, goal_y, blocked_positions):
-- Find the shortest path from (start_x, start_y) to (goal_x, goal_y)
-- on the given map.
--
-- blocked_positions: optional table of {["x,y"] = true} for positions
-- that should be treated as impassable (e.g., NPC locations).
--
-- Returns:
--   On success: a list of {x, y, direction} steps from start to goal
--   On failure: nil (no path exists)
--   On skip: nil (overworld or invalid map)
function M.find_path(map_id, start_x, start_y, goal_x, goal_y, blocked_positions)
    -- Don't pathfind on the overworld (too large, ~120x120 tiles)
    if map_id == 0x00 then
        return nil
    end

    -- Get map dimensions for bounds checking
    local width, height = map_reader.get_map_dimensions(map_id)
    if not width or not height then return nil end

    -- Verify the goal is within bounds
    if goal_x < 0 or goal_x >= width or goal_y < 0 or goal_y >= height then
        return nil
    end

    blocked_positions = blocked_positions or {}

    -- Key function: convert (x, y) to a string key for table lookups.
    -- Lua tables can't use pairs of numbers as keys, so we serialize them.
    local function key(x, y)
        return x .. "," .. y
    end

    -- Check if a position is passable (walkable tile AND not blocked)
    local function is_passable(x, y)
        -- Bounds check
        if x < 0 or x >= width or y < 0 or y >= height then
            return false
        end
        -- NPC/dynamic block check
        if blocked_positions[key(x, y)] then
            return false
        end
        -- Tile walkability check
        local walkable = map_reader.is_walkable(map_id, x, y)
        return walkable == true
    end

    -- The goal tile itself must be reachable (or be the destination
    -- even if it's technically non-walkable, like a chest tile).
    -- We allow pathfinding TO a non-walkable goal by checking the
    -- tile adjacent to the goal instead.

    -- Manhattan distance heuristic (admissible for 4-directional movement)
    local function heuristic(x, y)
        return math.abs(x - goal_x) + math.abs(y - goal_y)
    end

    -- A* data structures
    local open = heap_new()           -- Priority queue of nodes to explore
    local g_score = {}                -- Best known cost to reach each node
    local came_from = {}              -- Parent node for path reconstruction
    local came_from_dir = {}          -- Direction taken to reach each node
    local closed = {}                 -- Nodes we've fully explored

    -- Initialize with the start node
    local start_key = key(start_x, start_y)
    g_score[start_key] = 0
    heap_push(open, heuristic(start_x, start_y), {x = start_x, y = start_y})

    -- Safety limit: don't explore more nodes than the entire map
    -- (prevents runaway computation on large/complex maps)
    local max_iterations = width * height
    local iterations = 0

    while open.size > 0 do
        iterations = iterations + 1
        if iterations > max_iterations then
            return nil  -- Gave up (shouldn't happen on valid maps)
        end

        -- Pop the most promising node (lowest f-score)
        local _, current = heap_pop(open)
        local cx, cy = current.x, current.y
        local current_key = key(cx, cy)

        -- Found the goal!
        if cx == goal_x and cy == goal_y then
            -- Reconstruct path by following came_from chain
            local path = {}
            local k = current_key
            while came_from[k] do
                local parent_key = came_from[k]
                local dir = came_from_dir[k]
                -- Parse parent coordinates from key
                local px, py = parent_key:match("^(%d+),(%d+)$")
                px, py = tonumber(px), tonumber(py)
                -- Insert at the beginning (we're going backwards)
                table.insert(path, 1, {
                    x = cx,
                    y = cy,
                    direction = dir,
                })
                cx, cy = px, py
                k = parent_key
            end
            return path
        end

        -- Skip already-explored nodes (can happen with duplicate
        -- entries in the heap from re-insertions with better scores)
        if not closed[current_key] then
            closed[current_key] = true

            -- Explore neighbors (4 cardinal directions)
            local current_g = g_score[current_key]

            for _, dir in ipairs(DIRECTIONS) do
                local nx = cx + dir.dx
                local ny = cy + dir.dy
                local nk = key(nx, ny)

                -- Only process neighbors that haven't been fully explored
                if not closed[nk] then
                    -- Check passability (goal tile gets special treatment)
                    local passable
                    if nx == goal_x and ny == goal_y then
                        -- Always allow reaching the exact goal tile
                        passable = true
                    else
                        passable = is_passable(nx, ny)
                    end

                    if passable then
                        local tentative_g = current_g + 1  -- All moves cost 1

                        -- Is this a better path to this neighbor?
                        if not g_score[nk] or tentative_g < g_score[nk] then
                            g_score[nk] = tentative_g
                            came_from[nk] = current_key
                            came_from_dir[nk] = dir.name
                            local f = tentative_g + heuristic(nx, ny)
                            heap_push(open, f, {x = nx, y = ny})
                        end
                    end
                end
            end
        end -- if not closed
    end

    -- Open set exhausted without reaching the goal — no path exists
    return nil
end

-- ============================================================
-- Path Formatting
-- ============================================================

-- format_path(path): Convert a list of directional steps into a
-- human-readable string by grouping consecutive same-direction steps.
--
-- Input: {{direction="north"}, {direction="north"}, {direction="east"}}
-- Output: "2 north, 1 east"
--
-- This is much easier to follow by ear than step-by-step directions.
function M.format_path(path)
    if not path or #path == 0 then
        return "Already there"
    end

    local groups = {}
    local current_dir = path[1].direction
    local current_count = 1

    for i = 2, #path do
        if path[i].direction == current_dir then
            current_count = current_count + 1
        else
            groups[#groups + 1] = current_count .. " " .. current_dir
            current_dir = path[i].direction
            current_count = 1
        end
    end
    -- Don't forget the last group
    groups[#groups + 1] = current_count .. " " .. current_dir

    return table.concat(groups, ", ")
end

-- ============================================================
-- High-Level API
-- ============================================================

-- pathfind_to_adjacent(map_id, start, goal, npc_positions):
-- Like pathfind_to but targets a tile ADJACENT to the goal instead of the
-- goal itself. Used for NPC targets — the player needs to stand next to an
-- NPC to interact (press A), not on the NPC's own tile (which is blocked
-- by the NPC's collision).
--
-- Returns "Adjacent" if the player is already within 1 step of the goal.
-- Otherwise routes to the closest reachable tile next to the goal.
function M.pathfind_to_adjacent(map_id, start_x, start_y, goal_x, goal_y, npc_positions)
    -- Already adjacent (or standing on the goal tile)
    local dist = math.abs(start_x - goal_x) + math.abs(start_y - goal_y)
    if dist <= 1 then
        return "Adjacent"
    end

    -- For the overworld, just give direction + distance (no A*)
    if map_id == 0x00 then
        local objects = require "objects"
        return objects.get_direction_string(start_x, start_y, goal_x, goal_y)
    end

    -- Build blocked positions: other NPCs plus the goal tile itself.
    -- We block the goal tile so A* stops one step short.
    local blocked = {}
    if npc_positions then
        for _, npc in ipairs(npc_positions) do
            blocked[npc.x .. "," .. npc.y] = true
        end
    end
    blocked[goal_x .. "," .. goal_y] = true

    -- Try each of the 4 cardinal neighbors of the goal as a destination.
    -- A* to each walkable neighbor; keep the shortest resulting path.
    local adj_tiles = {
        {x = goal_x,     y = goal_y - 1},  -- north of NPC
        {x = goal_x,     y = goal_y + 1},  -- south of NPC
        {x = goal_x - 1, y = goal_y    },  -- west of NPC
        {x = goal_x + 1, y = goal_y    },  -- east of NPC
    }

    local best_path = nil
    for _, adj in ipairs(adj_tiles) do
        -- is_walkable returns true/false/nil; nil means out-of-bounds
        if map_reader.is_walkable(map_id, adj.x, adj.y) == true then
            local path = M.find_path(map_id, start_x, start_y, adj.x, adj.y, blocked)
            if path and (not best_path or #path < #best_path) then
                best_path = path
            end
        end
    end

    if best_path then
        return "Approach: " .. M.format_path(best_path)
    else
        return "No path found"
    end
end

-- pathfind_to(map_id, start_x, start_y, goal_x, goal_y, npc_positions):
-- Find a path and return a formatted direction string.
--
-- npc_positions: optional list of {x=, y=} tables for NPCs to avoid.
--
-- Returns:
--   On success: "Path: 3 north, 2 east, 1 north"
--   On failure: "No path found"
--   On overworld: direction+distance string (no A*)
function M.pathfind_to(map_id, start_x, start_y, goal_x, goal_y, npc_positions)
    -- For the overworld, just give direction + distance (no A*)
    if map_id == 0x00 then
        local objects = require "objects"
        local dir_str = objects.get_direction_string(start_x, start_y, goal_x, goal_y)
        return dir_str
    end

    -- Build blocked positions table from NPC list
    local blocked = {}
    if npc_positions then
        for _, npc in ipairs(npc_positions) do
            -- Don't block the goal itself (in case an NPC is the target)
            if not (npc.x == goal_x and npc.y == goal_y) then
                blocked[npc.x .. "," .. npc.y] = true
            end
        end
    end

    -- Run A*
    local path = M.find_path(map_id, start_x, start_y, goal_x, goal_y, blocked)

    if path then
        return "Path: " .. M.format_path(path)
    else
        return "No path found"
    end
end

return M
