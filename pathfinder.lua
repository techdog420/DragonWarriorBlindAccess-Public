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
local debug_tools = require "debug_tools"

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

local function build_blocked_table(npc_positions, goal_x, goal_y, block_goal)
    local blocked = {}
    if npc_positions then
        for _, npc in ipairs(npc_positions) do
            if block_goal or not (npc.x == goal_x and npc.y == goal_y) then
                blocked[npc.x .. "," .. npc.y] = true
            end
        end
        for k, v in pairs(npc_positions) do
            if type(k) == "string" then
                blocked[k] = v
            end
        end
    end
    if block_goal then
        blocked[goal_x .. "," .. goal_y] = true
    end
    return blocked
end

-- face_direction(from_x, from_y, to_x, to_y): Return the cardinal direction
-- the player must face when standing at (from_x, from_y) to interact with
-- something at (to_x, to_y) one tile away.
-- Returns nil if the positions are the same (shouldn't happen in practice).
local function face_direction(from_x, from_y, to_x, to_y)
    if to_y < from_y then return "north"
    elseif to_y > from_y then return "south"
    elseif to_x > from_x then return "east"
    elseif to_x < from_x then return "west"
    end
    return nil
end

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

-- find_path(map_id, start_x, start_y, goal_x, goal_y, blocked_positions, opts):
-- Find the shortest path from (start_x, start_y) to (goal_x, goal_y)
-- on the given map.
--
-- blocked_positions: optional blocked-position collection. Accepts either:
--   - keyed table: {["x,y"] = true}
--   - array of {x=..., y=...} tables
-- Used for dynamic blockers such as NPC locations.
--
-- opts: optional table of debug callbacks (nil for zero overhead):
--   on_visit(x, y, g_score, f_score)    — node popped and expanded
--   on_reject(x, y, reason)             — neighbor not added to open set
--     reason: "already_closed", "already_better", "out_of_bounds",
--             "blocked_npc", "not_walkable"
--   on_complete({success, path_length, nodes_visited, reason})
--     Called on search finish; reason is nil on success.
-- See path_debug.lua build_find_path_opts() for the callback factory.
--
-- Returns:
--   On success: a list of {x, y, direction} steps from start to goal
--   On failure: nil (no path exists)
--   On skip: nil (overworld or invalid map)
function M.find_path(map_id, start_x, start_y, goal_x, goal_y, blocked_positions, opts)
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

    -- Optional debug callbacks (zero overhead when nil)
    local on_visit   = opts and opts.on_visit
    local on_reject  = opts and opts.on_reject
    local on_complete = opts and opts.on_complete

    -- Key function: convert (x, y) to a string key for table lookups.
    -- Lua tables can't use pairs of numbers as keys, so we serialize them.
    local function key(x, y)
        return x .. "," .. y
    end

    local function is_blocked(x, y)
        local k = key(x, y)
        if blocked_positions[k] then
            return true
        end
        for _, pos in ipairs(blocked_positions) do
            if pos.x == x and pos.y == y then
                return true
            end
        end
        return false
    end

    -- Check if a position is passable (walkable tile AND not blocked)
    local function is_passable(x, y)
        -- Bounds check
        if x < 0 or x >= width or y < 0 or y >= height then
            return false
        end
        -- NPC/dynamic block check
        if is_blocked(x, y) then
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

    -- Safety limit on A* iterations.
    -- Each tile can be popped from the heap multiple times when better
    -- paths are found (one push per neighbor direction = up to 4 pops
    -- per tile). A plain width*height limit is too tight for maps where
    -- walls force long detours — the search exhausts the budget before
    -- finding the route around the obstacle.
    local max_iterations = width * height * 4
    local iterations = 0

    while open.size > 0 do
        iterations = iterations + 1
        if iterations > max_iterations then
            if on_complete then
                on_complete({success = false, path_length = 0, nodes_visited = iterations, reason = "max_iterations"})
            end
            return nil  -- Gave up (shouldn't happen on valid maps)
        end

        -- Pop the most promising node (lowest f-score)
        local current_f, current = heap_pop(open)
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
            if on_complete then
                on_complete({success = true, path_length = #path, nodes_visited = iterations})
            end
            return path
        end

        -- Skip already-explored nodes (can happen with duplicate
        -- entries in the heap from re-insertions with better scores)
        if not closed[current_key] then
            closed[current_key] = true

            if on_visit then on_visit(cx, cy, g_score[current_key] or 0, current_f or 0) end

            -- Explore neighbors (4 cardinal directions)
            local current_g = g_score[current_key]

            for _, dir in ipairs(DIRECTIONS) do
                local nx = cx + dir.dx
                local ny = cy + dir.dy
                local nk = key(nx, ny)

                if closed[nk] then
                    -- Already fully explored
                    if on_reject then on_reject(nx, ny, "already_closed") end
                elseif nx == goal_x and ny == goal_y then
                    -- Always allow reaching the exact goal tile
                    local tentative_g = current_g + 1
                    if not g_score[nk] or tentative_g < g_score[nk] then
                        g_score[nk] = tentative_g
                        came_from[nk] = current_key
                        came_from_dir[nk] = dir.name
                        heap_push(open, tentative_g + heuristic(nx, ny), {x = nx, y = ny})
                    else
                        if on_reject then on_reject(nx, ny, "already_better") end
                    end
                elseif nx < 0 or nx >= width or ny < 0 or ny >= height then
                    -- Out of map bounds
                    if on_reject then on_reject(nx, ny, "out_of_bounds") end
                elseif is_blocked(nx, ny) then
                    -- NPC or runtime-blocked cell
                    if on_reject then on_reject(nx, ny, "blocked_npc") end
                elseif map_reader.is_walkable(map_id, nx, ny) ~= true then
                    -- Tile not walkable (wall, water, etc.)
                    if on_reject then on_reject(nx, ny, "not_walkable") end
                else
                    -- Passable neighbor
                    local tentative_g = current_g + 1
                    if not g_score[nk] or tentative_g < g_score[nk] then
                        g_score[nk] = tentative_g
                        came_from[nk] = current_key
                        came_from_dir[nk] = dir.name
                        heap_push(open, tentative_g + heuristic(nx, ny), {x = nx, y = ny})
                    else
                        if on_reject then on_reject(nx, ny, "already_better") end
                    end
                end
            end
        end -- if not closed
    end

    -- Open set exhausted without reaching the goal — no path exists
    if on_complete then
        on_complete({success = false, path_length = 0, nodes_visited = iterations, reason = "no_path"})
    end
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

function M.find_route_to(map_id, start_x, start_y, goal_x, goal_y, npc_positions, opts)
    if map_id == 0x00 then
        return nil
    end
    local blocked = build_blocked_table(npc_positions, goal_x, goal_y, false)
    return M.find_path(map_id, start_x, start_y, goal_x, goal_y, blocked, opts)
end

function M.find_route_to_adjacent(map_id, start_x, start_y, goal_x, goal_y, npc_positions, opts)
    if map_id == 0x00 then
        return nil, nil, nil
    end

    local blocked = build_blocked_table(npc_positions, goal_x, goal_y, true)
    local adj_tiles = {
        {x = goal_x,     y = goal_y - 1},
        {x = goal_x,     y = goal_y + 1},
        {x = goal_x - 1, y = goal_y    },
        {x = goal_x + 1, y = goal_y    },
    }

    local best_path = nil
    local best_adj = nil
    for _, adj in ipairs(adj_tiles) do
        local walkable = map_reader.is_walkable(map_id, adj.x, adj.y)
        local npc_blocked = blocked[adj.x .. "," .. adj.y]
        debug_tools.debug("pathfind adj (" .. adj.x .. "," .. adj.y .. ") walkable=" .. tostring(walkable) .. " npc_blocked=" .. tostring(npc_blocked))
        if walkable == true and not npc_blocked then
            local path = M.find_path(map_id, start_x, start_y, adj.x, adj.y, blocked, opts)
            if path then
                debug_tools.debug("  path length=" .. #path .. " steps: " .. M.format_path(path))
            else
                debug_tools.debug("  no path to this adj tile")
            end
            if path and (not best_path or #path < #best_path) then
                best_path = path
                best_adj = adj
            end
        end
    end

    if not best_path then
        return nil, nil, nil
    end

    -- Guard: if best_path is empty (shouldn't happen given the dist>1 check
    -- above, but defensive against edge cases), treat as already-adjacent.
    if #best_path == 0 then
        return best_path, face_direction(start_x, start_y, goal_x, goal_y), best_adj
    end

    local last = best_path[#best_path]
    local face = face_direction(last.x, last.y, goal_x, goal_y)
    return best_path, face, best_adj
end

-- ============================================================
-- High-Level API
-- ============================================================

-- pathfind_to_adjacent(map_id, start, goal, npc_positions):
-- Like pathfind_to but targets a tile ADJACENT to the goal instead of the
-- goal itself. Used for NPC/door targets — the player needs to stand next to
-- the target to interact (press A), not on the target's own tile.
--
-- Returns three values:
--   result_string  — "Adjacent", "Approach: N north, M east", or "No path found"
--   face_dir       — cardinal direction to face on arrival (e.g. "north"), or nil
--   path           — raw path table (list of {x, y, direction} steps), or nil
--
-- "Adjacent" means the player is already within 1 step of the goal;
-- face_dir in that case is the direction from the player's current tile
-- toward the goal, so they can orient immediately; path is an empty table.
function M.pathfind_to_adjacent(map_id, start_x, start_y, goal_x, goal_y, npc_positions, opts)
    debug_tools.info(string.format("pathfind_to_adjacent: map=0x%02X start=(%d,%d) goal=(%d,%d)", map_id, start_x, start_y, goal_x, goal_y))

    -- Already adjacent (or standing on the goal tile)
    local dist = math.abs(start_x - goal_x) + math.abs(start_y - goal_y)
    if dist <= 1 then
        return "Adjacent", face_direction(start_x, start_y, goal_x, goal_y), {}
    end

    -- For the overworld, just give direction + distance (no A*)
    if map_id == 0x00 then
        local objects = require "objects"
        return objects.get_direction_string(start_x, start_y, goal_x, goal_y), nil, nil
    end

    local best_path, face, best_adj = M.find_route_to_adjacent(
        map_id, start_x, start_y, goal_x, goal_y, npc_positions, opts)
    if best_path then
        -- Log the chosen path with tile types for each step
        if best_adj then
            debug_tools.info("pathfind chosen adj=(" .. best_adj.x .. "," .. best_adj.y .. ") path=" .. M.format_path(best_path))
            for i, step in ipairs(best_path) do
                local tt = map_reader.get_tile_type(map_id, step.x, step.y)
                debug_tools.debug("  step " .. i .. ": (" .. step.x .. "," .. step.y .. ") dir=" .. step.direction .. " tile=" .. tostring(tt))
            end
        end
        return "Approach: " .. M.format_path(best_path), face, best_path
    else
        debug_tools.info("pathfind no path to any adj of (" .. goal_x .. "," .. goal_y .. ")")
        return "No path found", nil, nil
    end
end

-- pathfind_to(map_id, start_x, start_y, goal_x, goal_y, npc_positions):
-- Find a path and return a formatted direction string.
--
-- npc_positions: optional list of {x=, y=} tables for NPCs to avoid.
--
-- Returns three values:
--   result_string  — "Path: 3 north, 2 east", "Already there", or "No path found"
--   face_dir       — cardinal direction the player faces on arrival, or nil
--   path           — raw path table (list of {x, y, direction} steps), or nil
function M.pathfind_to(map_id, start_x, start_y, goal_x, goal_y, npc_positions, opts)
    -- Already at the goal
    if start_x == goal_x and start_y == goal_y then
        return "Already there", nil, {}
    end

    -- For the overworld, just give direction + distance (no A*)
    if map_id == 0x00 then
        local objects = require "objects"
        local dir_str = objects.get_direction_string(start_x, start_y, goal_x, goal_y)
        return dir_str, nil, nil
    end

    local path = M.find_route_to(map_id, start_x, start_y, goal_x, goal_y, npc_positions, opts)

    if path then
        -- Compute face direction from the last step toward the goal
        local last = path[#path]
        local face = nil
        if last then
            face = last.direction
        end
        return "Path: " .. M.format_path(path), face, path
    else
        return "No path found", nil, nil
    end
end

return M
