-- route_frontier.lua
-- Shared read-only frontier analysis for debug commands and town audits.
local M = {}

function M.analyze(params)
    local map_id, start_x, start_y = params.map_id, params.start_x, params.start_y
    local goal_x, goal_y = params.goal_x, params.goal_y
    local map_reader = params.map_reader or require "map_reader"
    local route_mgr = params.route_manager or require "route_manager"
    local width, height = map_reader.get_map_dimensions(map_id)
    local walkability = params.walkability or map_reader.get_walkability_snapshot(map_id)
    local blocking = params.blocking or route_mgr.build_path_blocking(map_id, {skip_npcs = params.skip_npcs})
    local directional_blocks = map_reader.get_directional_blocks(map_id)
    local frontier_classifier = require "route_frontier_classifier"
    if not width or not height or not walkability then return nil, "Map data unavailable" end
    local ROUTE_FRONTIER_DIRECTIONS = {
        {name = "right", dx = 1, dy = 0, approach = "west"},
        {name = "left",  dx = -1, dy = 0, approach = "east"},
        {name = "down",  dx = 0, dy = 1, approach = "north"},
        {name = "up",    dx = 0, dy = -1, approach = "south"},
    }

    local function route_frontier_block_reason(map_id, blocking, directional_blocks, x, y, approach)
        local key = x .. "," .. y
        local dynamic = blocking and blocking[key]

        if dynamic and type(dynamic) ~= "table" then
            return dynamic == "runtime" and "blocked_runtime" or "blocked_npc"
        end

        local runtime = route_mgr.is_cell_runtime_blocked and route_mgr.is_cell_runtime_blocked(map_id, x, y)
        if type(runtime) == "table" and runtime[approach] == true then
            return "blocked_runtime"
        end

        local static = directional_blocks and directional_blocks[key]
        if static and static[approach] == true then
            return "blocked_directional"
        end
        if type(dynamic) == "table" and dynamic[approach] == true then
            return "blocked_dynamic"
        end
        return nil
    end

    local function route_frontier_reason_rank(reason)
        if reason == "blocked_runtime" then return 0 end
        if reason == "blocked_directional" then return 1 end
        if reason == "blocked_dynamic" then return 2 end
        if reason == "not_walkable" then return 3 end
        if reason == "blocked_npc" then return 4 end
        return 5
    end

    local function route_frontier_bridge_rank(frontier)
        if frontier.hidden_bridge_to_target then return 0 end
        if frontier.bridge_to_target then return 1 end
        return 2
    end

    local function key(x, y)
        return x .. "," .. y
    end

    local function is_walkable_snapshot(x, y)
        local row = walkability[y]
        return row and row[x] == true
    end

    local reachable = {}
    local queue = {}
    local start_key = key(start_x, start_y)
    reachable[start_key] = true
    queue[#queue + 1] = {x = start_x, y = start_y, dist = 0}

    local head = 1
    while queue[head] do
        local cell = queue[head]
        head = head + 1
        for _, step in ipairs(ROUTE_FRONTIER_DIRECTIONS) do
            local nx = cell.x + step.dx
            local ny = cell.y + step.dy
            if nx >= 0 and nx < width and ny >= 0 and ny < height
               and is_walkable_snapshot(nx, ny)
               and not route_frontier_block_reason(map_id, blocking, directional_blocks, nx, ny, step.approach) then
                local neighbor_key = key(nx, ny)
                if not reachable[neighbor_key] then
                    reachable[neighbor_key] = true
                    queue[#queue + 1] = {x = nx, y = ny, dist = cell.dist + 1}
                end
            end
        end
    end

    local target_side = {}
    local target_queue = {}
    local goals = params.goal_points or {{x = goal_x, y = goal_y}}
    for _, goal in ipairs(goals) do
        if goal.x >= 0 and goal.x < width and goal.y >= 0 and goal.y < height
           and is_walkable_snapshot(goal.x, goal.y) and not target_side[key(goal.x, goal.y)] then
            target_side[key(goal.x, goal.y)] = {dist = 0}
            target_queue[#target_queue + 1] = {x = goal.x, y = goal.y, dist = 0}
        end
    end

    -- Reverse reachability: a cell is on the target side if it can move,
    -- using the same directional/NPC/runtime rules, to a cell that can reach
    -- the target. This is more useful than plain Manhattan distance on maps
    -- with one-way-looking engine walls.
    local target_head = 1
    while target_queue[target_head] do
        local cell = target_queue[target_head]
        target_head = target_head + 1
        for _, step in ipairs(ROUTE_FRONTIER_DIRECTIONS) do
            local px = cell.x - step.dx
            local py = cell.y - step.dy
            if px >= 0 and px < width and py >= 0 and py < height
               and is_walkable_snapshot(px, py)
               and not route_frontier_block_reason(map_id, blocking, directional_blocks, cell.x, cell.y, step.approach) then
                local predecessor_key = key(px, py)
                if not target_side[predecessor_key] then
                    target_side[predecessor_key] = {dist = cell.dist + 1}
                    target_queue[#target_queue + 1] = {x = px, y = py, dist = cell.dist + 1}
                end
            end
        end
    end

    local function walkability_detail_for_cell(x, y)
        if not map_reader.get_walkability_details then
            return nil
        end
        return map_reader.get_walkability_details(map_id, x, y)
    end

    local function is_hidden_wall_candidate(details)
        if not details then
            return false
        end
        if details.effective_walkable == true then
            return false
        end
        if details.permanent_blocked == true or details.hazard == true then
            return false
        end
        return details.reason == "tile_type"
            or details.reason == "wall"
            or details.reason == "not_walkable"
    end

    local function find_one_cell_hidden_bridge(x, y, details)
        if not is_hidden_wall_candidate(details) then
            return nil
        end
        local best
        for _, step in ipairs(ROUTE_FRONTIER_DIRECTIONS) do
            local nx = x + step.dx
            local ny = y + step.dy
            if nx >= 0 and nx < width and ny >= 0 and ny < height
               and is_walkable_snapshot(nx, ny)
               and not reachable[key(nx, ny)] then
                local target_side_entry = target_side[key(nx, ny)]
                if target_side_entry
                   and not route_frontier_block_reason(map_id, blocking, directional_blocks, nx, ny, step.approach) then
                    local candidate = {
                        exit_dir = step.name,
                        exit_x = nx,
                        exit_y = ny,
                        target_side_distance = target_side_entry.dist + 1,
                    }
                    if not best
                       or candidate.target_side_distance < best.target_side_distance
                       or (candidate.target_side_distance == best.target_side_distance
                           and candidate.exit_dir < best.exit_dir) then
                        best = candidate
                    end
                end
            end
        end
        return best
    end

    local frontiers = {}
    local bridge_candidate_count = 0
    local hidden_bridge_candidate_count = 0
    for _, cell in ipairs(queue) do
        for _, step in ipairs(ROUTE_FRONTIER_DIRECTIONS) do
            local nx = cell.x + step.dx
            local ny = cell.y + step.dy
            if nx >= 0 and nx < width and ny >= 0 and ny < height
               and not reachable[key(nx, ny)] then
                local dest_walkable = is_walkable_snapshot(nx, ny)
                local blocked_reason = route_frontier_block_reason(map_id, blocking, directional_blocks, nx, ny, step.approach)
                local details = walkability_detail_for_cell(nx, ny)
                local classified = frontier_classifier.classify_candidate({
                    is_walkable = dest_walkable,
                    blocked_reason = blocked_reason,
                })
                local reason = classified.reason
                local target_side_entry = dest_walkable and target_side[key(nx, ny)] or nil
                local hidden_bridge = nil
                local bridge_to_target = target_side_entry ~= nil
                if not bridge_to_target and classified.allow_hidden_bridge then
                    hidden_bridge = find_one_cell_hidden_bridge(nx, ny, details)
                    if hidden_bridge then
                        bridge_to_target = true
                        target_side_entry = {
                            dist = hidden_bridge.target_side_distance,
                        }
                        hidden_bridge_candidate_count = hidden_bridge_candidate_count + 1
                    end
                end
                if bridge_to_target then
                    bridge_candidate_count = bridge_candidate_count + 1
                end
                frontiers[#frontiers + 1] = {
                    from_x = cell.x,
                    from_y = cell.y,
                    dir = step.name,
                    dest_x = nx,
                    dest_y = ny,
                    approach = step.approach,
                    reason = reason,
                    bridge_to_target = bridge_to_target,
                    hidden_bridge_to_target = hidden_bridge ~= nil,
                    hidden_exit_dir = hidden_bridge and hidden_bridge.exit_dir or nil,
                    hidden_exit_x = hidden_bridge and hidden_bridge.exit_x or nil,
                    hidden_exit_y = hidden_bridge and hidden_bridge.exit_y or nil,
                    target_side_distance = target_side_entry and target_side_entry.dist or nil,
                    target_distance = math.abs(nx - goal_x) + math.abs(ny - goal_y),
                    start_distance = cell.dist,
                    tile_type = details and details.tile_type or nil,
                    walk_reason = details and details.reason or nil,
                }
            end
        end
    end

    table.sort(frontiers, function(a, b)
        local ab = route_frontier_bridge_rank(a)
        local bb = route_frontier_bridge_rank(b)
        if ab ~= bb then return ab < bb end
        local ar = route_frontier_reason_rank(a.reason)
        local br = route_frontier_reason_rank(b.reason)
        if ar ~= br then return ar < br end
        if a.bridge_to_target and b.bridge_to_target then
            local at = a.target_side_distance or 9999
            local bt = b.target_side_distance or 9999
            if at ~= bt then return at < bt end
        end
        if a.target_distance ~= b.target_distance then
            return a.target_distance < b.target_distance
        end
        if a.start_distance ~= b.start_distance then
            return a.start_distance < b.start_distance
        end
        if a.dest_y ~= b.dest_y then return a.dest_y > b.dest_y end
        if a.dest_x ~= b.dest_x then return a.dest_x > b.dest_x end
        if a.from_y ~= b.from_y then return a.from_y < b.from_y end
        if a.from_x ~= b.from_x then return a.from_x < b.from_x end
        return a.dir < b.dir
    end)

    local target_reachable = false
    for _, goal in ipairs(goals) do
        if reachable[key(goal.x, goal.y)] then target_reachable = true end
    end
    return {frontiers = frontiers, reachable_count = #queue, target_reachable = target_reachable,
        target_side_count = #target_queue, bridge_count = bridge_candidate_count,
        hidden_bridge_count = hidden_bridge_candidate_count}
end

return M
