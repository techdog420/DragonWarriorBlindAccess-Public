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
-- - Skips the overworld — too large, use direction+distance instead
-- - Returns path as grouped direction steps: "3 north, 2 east, 1 north"
--
-- Based on standard A* algorithm, adapted for DW1's tile system.
-- Reference: pokemon-access a-star.lua (MIT licensed)

local map_reader = require "map_reader"
local debug_tools = require "debug_tools"
local maps = require "maps"

local M = {}
local runtime_block_neighbor_log = {}

-- ============================================================
-- Direction Constants
-- ============================================================
-- The four cardinal directions as (dx, dy) offsets.
-- In DW1: +X = east (right), +Y = south (down)
--
-- `approach` is the side of the DESTINATION cell that the player arrives
-- from. Used for directional engine-wall checks: DW1 buildings have walls
-- that block entry from one side only (e.g. you can't step east into a
-- cell, but you CAN step south into the same cell).
local DIRECTIONS = {
    {dx =  0, dy = -1, name = "north", approach = "south"},
    {dx =  0, dy =  1, name = "south", approach = "north"},
    {dx = -1, dy =  0, name = "west",  approach = "east"},
    {dx =  1, dy =  0, name = "east",  approach = "west"},
}

local function is_directional_blocked(directional_blocks, x, y, approach)
    local block = directional_blocks and directional_blocks[x .. "," .. y]
    return type(block) == "table" and block[approach] == true
end

local function count_open_exits(map_id, x, y, blocked_positions, directional_blocks)
    local open = 0

    for _, dir in ipairs(DIRECTIONS) do
        local nx = x + dir.dx
        local ny = y + dir.dy
        local block = blocked_positions[nx .. "," .. ny]
        local directional_block = is_directional_blocked(directional_blocks, nx, ny, dir.approach)

        if (not block or (type(block) == "table" and block[dir.approach] ~= true))
            and not directional_block then
            if map_reader.is_walkable(map_id, nx, ny) == true then
                open = open + 1
            end
        end
    end

    return open
end

local function count_reachable_area(map_id, start_x, start_y, blocked_positions, directional_blocks, limit)
    limit = limit or 128
    if map_reader.is_walkable(map_id, start_x, start_y) ~= true then
        return 0
    end

    local start_key = start_x .. "," .. start_y
    local start_block = blocked_positions[start_key]
    if start_block and type(start_block) ~= "table" then
        return 0
    end

    local queue = {{x = start_x, y = start_y}}
    local head = 1
    local seen = {[start_key] = true}
    local count = 0

    while head <= #queue and count < limit do
        local current = queue[head]
        head = head + 1
        count = count + 1

        for _, dir in ipairs(DIRECTIONS) do
            local nx = current.x + dir.dx
            local ny = current.y + dir.dy
            local nk = nx .. "," .. ny

            if not seen[nk] then
                local block = blocked_positions[nk]
                local blocked_from_approach = false
                if block then
                    if type(block) == "table" then
                        blocked_from_approach = (block[dir.approach] == true)
                    else
                        blocked_from_approach = true
                    end
                end

                local directional_block = is_directional_blocked(directional_blocks, nx, ny, dir.approach)
                if not blocked_from_approach and not directional_block and map_reader.is_walkable(map_id, nx, ny) == true then
                    seen[nk] = true
                    queue[#queue + 1] = {x = nx, y = ny}
                end
            end
        end
    end

    return count
end

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
--             "blocked_npc", "blocked_runtime", "blocked_directional", "not_walkable"
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
    if maps.is_overworld(map_id) then
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

    local directional_blocks = map_reader.get_directional_blocks and map_reader.get_directional_blocks(map_id) or {}

    local function is_fully_blocked_directionally(x, y)
        local block = directional_blocks[key(x, y)]
        return block and block.north and block.south and block.east and block.west
    end

    -- is_blocked(x, y, approach): Check if a cell is blocked.
    -- `approach` is the side the player arrives from ("north","south","east","west").
    -- For directional runtime blocks (table value), only the matching direction
    -- counts. For NPC/"npc" blocks, the cell is always fully blocked.
    local function is_blocked(x, y, approach)
        local k = key(x, y)
        local block = blocked_positions[k]
        if not block then return false end
        if type(block) == "table" then
            -- Directional runtime block: only blocked from specific sides
            return block[approach] == true
        end
        return true  -- "npc" or legacy boolean
    end

    local runtime_block_log = {}

    -- get_block_reason(x, y, approach): Like is_blocked but returns the
    -- reason string ("npc", "runtime") or nil if not blocked from this side.
    local function get_block_reason(x, y, approach)
        local k = key(x, y)
        local block = blocked_positions[k]
        if not block then return nil end
        if type(block) == "table" then
            if block[approach] then return "runtime" end
            return nil  -- blocked table but not from this approach
        end
        if block == "runtime" then return "runtime" end
        return "npc"
    end

    local function log_runtime_block_use(x, y, context)
        local log_key = context .. ":" .. key(x, y)
        if runtime_block_log[log_key] then
            return
        end
        runtime_block_log[log_key] = true
        if context == "neighbor" then
            local global_key = string.format("0x%02X:%s", map_id, key(x, y))
            if runtime_block_neighbor_log[global_key] then
                return
            end
            runtime_block_neighbor_log[global_key] = true
        end
        debug_tools.info(string.format(
            "PATH_RUNTIME_BLOCK map=0x%02X x=%d y=%d context=%s",
            map_id, x, y, context))
    end

    -- Direct pathfinding targets must themselves be standable. Callers that
    -- need to interact with a non-walkable or occupied goal should use
    -- pathfind_to_adjacent(), which searches neighboring cells instead.
    --
    -- For directional runtime blocks (table), the goal is only unreachable
    -- if blocked from ALL 4 directions. Partial blocks still allow the
    -- search to find a valid approach.
    if not (start_x == goal_x and start_y == goal_y) then
        local goal_k = key(goal_x, goal_y)
        local goal_block = blocked_positions[goal_k]
        if goal_block then
            if type(goal_block) == "table" then
                -- Directional: only reject if every approach is blocked
                if goal_block.north and goal_block.south
                and goal_block.east  and goal_block.west then
                    log_runtime_block_use(goal_x, goal_y, "goal")
                    if on_complete then
                        on_complete({success = false, path_length = 0, nodes_visited = 0, reason = "goal_blocked"})
                    end
                    return nil
                end
                -- else: some approaches open, let search proceed
            else
                -- "npc" or legacy binary block — fully blocked
                if goal_block == "runtime" then
                    log_runtime_block_use(goal_x, goal_y, "goal")
                end
                if on_complete then
                    on_complete({success = false, path_length = 0, nodes_visited = 0, reason = "goal_blocked"})
                end
                return nil
            end
        end
        if is_fully_blocked_directionally(goal_x, goal_y) then
            if on_complete then
                on_complete({success = false, path_length = 0, nodes_visited = 0, reason = "goal_blocked"})
            end
            return nil
        end
        if map_reader.is_walkable(map_id, goal_x, goal_y) ~= true then
            if on_complete then
                on_complete({success = false, path_length = 0, nodes_visited = 0, reason = "goal_not_walkable"})
            end
            return nil
        end
    end

    -- Check if a position is passable (walkable tile AND not blocked).
    -- This answers "can the player stand on this cell?" so directional
    -- blocks (table values) are ignored — they restrict specific approach
    -- directions but the cell itself is standable. The neighbor-expansion
    -- loop uses is_blocked(x,y,approach) for directional filtering instead.
    local function is_passable(x, y)
        -- Bounds check
        if x < 0 or x >= width or y < 0 or y >= height then
            return false
        end
        -- NPC/dynamic block check (no approach = full blocks only)
        local k = key(x, y)
        local block = blocked_positions[k]
        if block and type(block) ~= "table" then
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
                    -- Goal tile: still respect directional blocks on the final
                    -- approach. A blocked approach direction here means the engine
                    -- will refuse the last step. The search may reach the goal
                    -- via a different (unblocked) direction instead.
                    if is_blocked(nx, ny, dir.approach) then
                        if on_reject then on_reject(nx, ny, "blocked_runtime") end
                    elseif is_directional_blocked(directional_blocks, nx, ny, dir.approach) then
                        if on_reject then on_reject(nx, ny, "blocked_directional") end
                    else
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
                elseif nx < 0 or nx >= width or ny < 0 or ny >= height then
                    -- Out of map bounds
                    if on_reject then on_reject(nx, ny, "out_of_bounds") end
                else
                    local block_reason = get_block_reason(nx, ny, dir.approach)
                    local permanent_directional_block = is_directional_blocked(directional_blocks, nx, ny, dir.approach)
                    if block_reason or permanent_directional_block then
                        local reject_reason = nil
                        if block_reason == "runtime" and not permanent_directional_block then
                            reject_reason = "blocked_runtime"
                        elseif block_reason == "npc" then
                            reject_reason = "blocked_npc"
                        else
                            -- Either runtime and static blocking overlap, or only static
                            -- directional lock applies.
                            reject_reason = "blocked_directional"
                        end

                        if block_reason == "runtime" and not permanent_directional_block then
                            log_runtime_block_use(nx, ny, "neighbor")
                        end

                        if on_reject then
                            on_reject(nx, ny, reject_reason)
                        end
                    else
                        if map_reader.is_walkable(map_id, nx, ny) ~= true then
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
    if maps.is_overworld(map_id) then
        return nil
    end
    local blocked = build_blocked_table(npc_positions, goal_x, goal_y, false)
    return M.find_path(map_id, start_x, start_y, goal_x, goal_y, blocked, opts)
end

function M.find_route_to_adjacent(map_id, start_x, start_y, goal_x, goal_y, npc_positions, opts)
    if maps.is_overworld(map_id) then
        return nil, nil, nil, nil
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
    local best_adj_open_exits = -1
    local best_adj_area = -1
    local diagnostics = {}
    local directional_blocks = map_reader.get_directional_blocks and map_reader.get_directional_blocks(map_id) or {}
    for _, adj in ipairs(adj_tiles) do
        local walkable = map_reader.is_walkable(map_id, adj.x, adj.y)
        local blocker = blocked[adj.x .. "," .. adj.y]
        local diag = {
            x = adj.x,
            y = adj.y,
            walkable = walkable == true,
            blocker = blocker,
            path_found = false,
            reachable_area = nil,
            open_exits = nil,
        }
        debug_tools.debug("pathfind adj (" .. adj.x .. "," .. adj.y .. ") walkable=" .. tostring(walkable) .. " blocker=" .. tostring(blocker))
        if blocker == "runtime" then
            debug_tools.info(string.format(
                "PATH_RUNTIME_BLOCK map=0x%02X x=%d y=%d context=adjacent_candidate",
                map_id, adj.x, adj.y))
        end
        if walkable == true and not blocker then
            local path = M.find_path(map_id, start_x, start_y, adj.x, adj.y, blocked, opts)
            local open_exits = count_open_exits(map_id, adj.x, adj.y, blocked, directional_blocks)
            local reachable_area = count_reachable_area(map_id, adj.x, adj.y, blocked, directional_blocks)
            diag.path_found = path ~= nil
            diag.reachable_area = reachable_area
            diag.open_exits = open_exits
            if path then
                debug_tools.debug(
                    "  path length=" .. #path
                    .. " steps: " .. M.format_path(path)
                    .. " reachable_area=" .. reachable_area
                    .. " open_exits=" .. open_exits)
            else
                debug_tools.debug(
                    "  no path to this adj tile (reachable_area=" .. reachable_area
                    .. " open_exits=" .. open_exits .. ")")
            end
            if path and (
                not best_path
                or #path < #best_path
                or (#path == #best_path and reachable_area > best_adj_area)
                or (#path == #best_path and reachable_area == best_adj_area and open_exits > best_adj_open_exits)
            ) then
                best_path = path
                best_adj = adj
                best_adj_open_exits = open_exits
                best_adj_area = reachable_area
            end
        end
        diagnostics[#diagnostics + 1] = diag
    end

    if not best_path then
        return nil, nil, nil, diagnostics
    end

    -- Guard: if best_path is empty (shouldn't happen given the dist>1 check
    -- above, but defensive against edge cases), treat as already-adjacent.
    if #best_path == 0 then
        return best_path, face_direction(start_x, start_y, goal_x, goal_y), best_adj, diagnostics
    end

    local last = best_path[#best_path]
    local face = face_direction(last.x, last.y, goal_x, goal_y)
    return best_path, face, best_adj, diagnostics
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
    if maps.is_overworld(map_id) then
        local objects = require "objects"
        return objects.get_direction_string(start_x, start_y, goal_x, goal_y), nil, nil
    end

    local best_path, face, best_adj, diagnostics = M.find_route_to_adjacent(
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
        return "Approach: " .. M.format_path(best_path), face, best_path, diagnostics
    else
        debug_tools.info("pathfind no path to any adj of (" .. goal_x .. "," .. goal_y .. ")")
        return "No path found", nil, nil, diagnostics
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
    if maps.is_overworld(map_id) then
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
