-- test_pathfinder.lua
-- Local unit tests for pathfinder/path debug behavior that can run outside FCEUX.

local original_preload = {}
local original_loaded = {}

local function save_module(name)
    original_preload[name] = package.preload[name]
    original_loaded[name] = package.loaded[name]
end

local function restore_modules(names)
    for _, name in ipairs(names) do
        package.preload[name] = original_preload[name]
        package.loaded[name] = original_loaded[name]
    end
end

local function make_stub_env()
    local grid = {}
    local width = 0
    local height = 0
    local directional_blocks = {}
    local logs = {}
    local walkable_calls = 0

    local function set_grid(new_width, new_height, blocked_cells)
        width = new_width
        height = new_height
        grid = {}
        walkable_calls = 0
        for y = 0, height - 1 do
            for x = 0, width - 1 do
                grid[x .. "," .. y] = true
            end
        end
        for _, cell in ipairs(blocked_cells or {}) do
            grid[cell.x .. "," .. cell.y] = false
        end
    end

    local function set_directional_blocks(new_blocks)
        directional_blocks = new_blocks or {}
    end

    local module_names = {
        "config",
        "debug_tools",
        "map_reader",
        "navigation",
        "objects",
        "path_debug",
        "pathfinder",
    }
    for _, name in ipairs(module_names) do
        save_module(name)
        package.loaded[name] = nil
    end

    package.preload["config"] = function()
        return {
            get = function(key)
                if key == "auto_step_timeout" then
                    return "60"
                end
                return nil
            end,
        }
    end

    package.preload["debug_tools"] = function()
        return {
            DEBUG_MODE = true,
            info = function(msg) logs[#logs + 1] = "INFO:" .. tostring(msg) end,
            debug = function(msg) logs[#logs + 1] = "DEBUG:" .. tostring(msg) end,
            error = function(msg) logs[#logs + 1] = "ERROR:" .. tostring(msg) end,
        }
    end

    package.preload["map_reader"] = function()
        return {
            get_map_dimensions = function()
                return width, height
            end,
            is_walkable = function(_, x, y)
                walkable_calls = walkable_calls + 1
                if x < 0 or x >= width or y < 0 or y >= height then
                    return false
                end
                return grid[x .. "," .. y]
            end,
            get_tile_type = function(_, x, y)
                if grid[x .. "," .. y] == false then
                    return 0x01
                end
                return 0x00
            end,
            get_directional_blocks = function()
                return directional_blocks
            end,
        }
    end

    package.preload["navigation"] = function()
        return {
            get_position = function()
                return 0x04, 1, 1
            end,
        }
    end

    package.preload["objects"] = function()
        return {
            get_direction_string = function(start_x, start_y, goal_x, goal_y)
                return string.format("from %d,%d to %d,%d", start_x, start_y, goal_x, goal_y)
            end,
        }
    end

    local pathfinder = require "pathfinder"
    local path_debug = require "path_debug"

    return {
        set_grid = set_grid,
        set_directional_blocks = set_directional_blocks,
        logs = logs,
        pathfinder = pathfinder,
        path_debug = path_debug,
        get_walkable_call_count = function()
            return walkable_calls
        end,
        restore = function()
            restore_modules(module_names)
        end,
    }
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local function assert_truthy(value, message)
    if not value then
        error(message, 2)
    end
end

local function assert_contains(haystack, needle, message)
    if not string.find(haystack, needle, 1, true) then
        error(string.format("%s: missing %s in %s", message, needle, haystack), 2)
    end
end

local tests = {}

function tests.goal_blocked_reports_reason_without_search()
    local env = make_stub_env()
    env.set_grid(5, 5)

    local opts = env.path_debug.build_find_path_opts()
    local path = env.pathfinder.find_path(0x04, 1, 1, 3, 1, {["3,1"] = true}, opts)
    local stats = opts._get_stats()

    assert_equal(path, nil, "blocked goal should not return a path")
    assert_equal(stats.reason, "goal_blocked", "blocked goal should set goal_blocked reason")
    assert_equal(stats.nodes_visited, 0, "blocked goal should not visit nodes")

    env.restore()
end

function tests.goal_not_walkable_reports_reason_without_search()
    local env = make_stub_env()
    env.set_grid(5, 5, {{x = 3, y = 1}})

    local opts = env.path_debug.build_find_path_opts()
    local path = env.pathfinder.find_path(0x04, 1, 1, 3, 1, {}, opts)
    local stats = opts._get_stats()

    assert_equal(path, nil, "non-walkable goal should not return a path")
    assert_equal(stats.reason, "goal_not_walkable", "non-walkable goal should set goal_not_walkable reason")
    assert_equal(stats.nodes_visited, 0, "non-walkable goal should not visit nodes")

    env.restore()
end

function tests.adjacent_pathing_accepts_occupied_goal_tile()
    local env = make_stub_env()
    env.set_grid(5, 5)

    local result, face_dir, path = env.pathfinder.pathfind_to_adjacent(0x04, 1, 1, 3, 1, {["3,1"] = true})

    assert_equal(result, "Approach: 1 east", "adjacent path should route to the open neighbor")
    assert_equal(face_dir, "east", "adjacent path should face the occupied goal")
    assert_truthy(path ~= nil and #path == 1, "adjacent path should contain one step")
    assert_equal(path[1].x, 2, "adjacent path should stop next to the goal")
    assert_equal(path[1].y, 1, "adjacent path should stop next to the goal")

    env.restore()
end

function tests.adjacent_pathing_accepts_directional_block_table_landing()
    local env = make_stub_env()
    env.set_grid(5, 5)

    local result, face_dir, path = env.pathfinder.pathfind_to_adjacent(
        0x04,
        1, 1,
        3, 1,
        {["2,1"] = {north = true}}
    )

    assert_equal(result, "Approach: 1 east", "adjacent path should allow a landing tile with unrelated directional blocks")
    assert_equal(face_dir, "east", "landing west of the goal should still face east")
    assert_truthy(path ~= nil and #path == 1, "directional table blocker should not make the landing tile fully occupied")
    assert_equal(path[1].x, 2, "adjacent path should choose the direct landing tile")
    assert_equal(path[1].y, 1, "adjacent path should choose the direct landing tile")

    env.restore()
end

function tests.adjacent_pathing_debug_stats_keep_success_after_later_failed_candidate()
    local env = make_stub_env()
    env.set_grid(5, 5, {
        {x = 1, y = 2},
        {x = 2, y = 1},
        {x = 3, y = 0},
        {x = 4, y = 1},
        {x = 4, y = 3},
    })

    local opts = env.path_debug.build_find_path_opts()
    local result, face_dir, path = env.pathfinder.pathfind_to_adjacent(
        0x04,
        0, 2,
        3, 2,
        {["3,2"] = true},
        opts
    )
    local stats = opts._get_stats()

    assert_contains(result, "Approach:", "adjacent path should still find a route")
    assert_truthy(face_dir ~= nil, "chosen adjacent landing should include a facing direction")
    assert_truthy(path ~= nil and #path > 0, "adjacent path should return the chosen route")
    assert_equal(stats.success, true, "debug stats should report the chosen adjacent route as successful")
    assert_equal(stats.reason, nil, "later failed adjacent candidates should not leave a stale no_path reason")
    assert_equal(stats.path_length, #path, "debug stats should keep the chosen adjacent route length")

    env.restore()
end

function tests.runtime_block_rejections_are_exposed_in_debug_log()
    local env = make_stub_env()
    env.set_grid(5, 5)

    local opts = env.path_debug.build_find_path_opts()
    local path = env.pathfinder.find_path(0x04, 1, 1, 3, 1, {["2,1"] = "runtime"}, opts)
    local log = table.concat(opts._get_log(), "\n")
    local info_log = table.concat(env.logs, "\n")

    assert_truthy(path ~= nil and #path > 0, "runtime-blocked neighbor should still allow an alternate route")
    assert_contains(log, "REJECT (2,1) reason=blocked_runtime", "debug log should record runtime-blocked rejection")
    assert_contains(info_log, "PATH_RUNTIME_BLOCK map=0x04 x=2 y=1 context=neighbor", "runtime blocker usage should be logged")

    env.restore()
end

function tests.runtime_block_neighbor_logs_are_deduped_across_searches()
    local env = make_stub_env()
    env.set_grid(5, 5)

    local first_opts = env.path_debug.build_find_path_opts()
    local second_opts = env.path_debug.build_find_path_opts()

    local first_path = env.pathfinder.find_path(0x04, 1, 1, 3, 1, {["2,1"] = "runtime"}, first_opts)
    local second_path = env.pathfinder.find_path(0x04, 1, 1, 3, 1, {["2,1"] = "runtime"}, second_opts)
    local info_log = table.concat(env.logs, "\n")
    local _, count = info_log:gsub("PATH_RUNTIME_BLOCK map=0x04 x=2 y=1 context=neighbor", "")

    assert_truthy(first_path ~= nil and #first_path > 0, "first search should still find an alternate route")
    assert_truthy(second_path ~= nil and #second_path > 0, "second search should still find an alternate route")
    assert_equal(count, 1, "neighbor runtime-block logs should be emitted only once across repeated searches")

    env.restore()
end

function tests.plans_around_permanent_directional_block()
    local env = make_stub_env()
    env.set_grid(4, 3)
    env.set_directional_blocks({
        ["2,1"] = {west = true},
    })

    local opts = env.path_debug.build_find_path_opts()
    local path = env.pathfinder.find_path(0x04, 1, 1, 3, 1, {}, opts)
    local log = table.concat(opts._get_log(), "\n")

    assert_truthy(path ~= nil and #path > 0, "permanent directional block should not make target unreachable")
    assert_equal(#path, 4, "planner should route around one blocked directional approach")
    assert_truthy(path[1].x ~= 2 or path[1].y ~= 1, "first step should not take blocked direct approach")
    assert_contains(log, "REJECT (2,1) reason=blocked_directional", "debug log should record permanent directional rejection")

    env.restore()
end

function tests.mixed_static_and_runtime_block_is_reported_as_directional()
    local env = make_stub_env()
    env.set_grid(5, 5)
    env.set_directional_blocks({
        ["2,1"] = {west = true},
    })

    local opts = env.path_debug.build_find_path_opts()
    local path = env.pathfinder.find_path(0x04, 1, 1, 3, 1, {["2,1"] = {west = true}}, opts)
    local log = table.concat(opts._get_log(), "\n")

    assert_truthy(path ~= nil and #path > 0, "runtime overlap should still allow an alternate route")
    assert_contains(log, "REJECT (2,1) reason=blocked_directional", "mixed block should be classified as blocked_directional")

    env.restore()
end

function tests.adjacent_pathing_prefers_larger_reachable_area_on_equal_length_tie()
    local env = make_stub_env()
    env.set_grid(6, 5, {
        {x = 2, y = 2},
        {x = 1, y = 1},
        {x = 3, y = 1},
        {x = 3, y = 0},
        {x = 2, y = 0},
        {x = 4, y = 1},
        {x = 2, y = 3},
    })

    local result, face_dir, path = env.pathfinder.pathfind_to_adjacent(
        0x04,
        0, 0,
        2, 2,
        {["2,2"] = true}
    )

    assert_equal(result, "Approach: 2 south, 1 east", "adjacent path should still use the shortest route")
    assert_equal(face_dir, "east", "adjacent path should face the occupied goal from the chosen landing tile")
    assert_truthy(path ~= nil and #path == 3, "adjacent path should contain the chosen route")
    assert_equal(path[#path].x, 1, "tie-breaker should choose the equal-length landing tile with the larger reachable area")
    assert_equal(path[#path].y, 2, "tie-breaker should avoid the smaller reachable-area pocket")

    env.restore()
end

function tests.adjacent_pathing_can_skip_equal_length_metrics()
    local env = make_stub_env()
    env.set_grid(6, 5, {
        {x = 2, y = 2},
        {x = 1, y = 1},
        {x = 3, y = 1},
        {x = 3, y = 0},
        {x = 2, y = 0},
        {x = 4, y = 1},
        {x = 2, y = 3},
    })

    local path, _, _, diagnostics = env.pathfinder.find_route_to_adjacent(
        0x04,
        0, 0,
        2, 2,
        {["2,2"] = true},
        {use_adjacent_metrics = false}
    )

    assert_truthy(path ~= nil, "adjacent pathing should still find a route when metrics are disabled")
    for _, diag in ipairs(diagnostics or {}) do
        assert_equal(diag.reachable_area, nil, "metrics-disabled adjacent pathing should not compute reachable area")
        assert_equal(diag.open_exits, nil, "metrics-disabled adjacent pathing should not compute open exits")
    end

    env.restore()
end

function tests.adjacent_pathing_skips_candidates_that_cannot_beat_current_best()
    local env = make_stub_env()
    env.set_grid(7, 7)

    local path, face_dir, best_adj, diagnostics = env.pathfinder.find_route_to_adjacent(
        0x04,
        0, 5,
        4, 5,
        {["4,5"] = true}
    )

    assert_truthy(path ~= nil and #path == 3, "adjacent route should find the shortest reachable landing")
    assert_equal(face_dir, "east", "route should face the occupied goal from the chosen landing")
    assert_equal(best_adj.x, 3, "west landing should be chosen as the closest adjacent tile")
    assert_equal(best_adj.y, 5, "west landing should be chosen as the closest adjacent tile")

    local skipped = false
    for _, diag in ipairs(diagnostics or {}) do
        if diag.skipped_reason == "longer_than_best" then
            skipped = true
            assert_equal(diag.path_found, false, "skipped candidates should not run A*")
            assert_equal(diag.reachable_area, nil, "skipped candidates should not run area diagnostics")
            assert_equal(diag.open_exits, nil, "skipped candidates should not run exit diagnostics")
        end
    end

    assert_truthy(skipped, "at least one longer adjacent candidate should be pruned")

    env.restore()
end

function tests.find_path_caches_walkability_per_search()
    local env = make_stub_env()
    env.set_grid(8, 8)

    local path = env.pathfinder.find_path(0x04, 0, 0, 7, 7, {})

    assert_truthy(path ~= nil and #path > 0, "test setup should find an open-grid path")
    assert_truthy(
        env.get_walkable_call_count() <= 64,
        "A* should not ask map_reader.is_walkable more than once per in-bounds cell during one search"
    )

    env.restore()
end

function tests.find_path_prefers_straight_progress_on_equal_length_ties()
    local env = make_stub_env()
    env.set_grid(5, 3, {
        {x = 4, y = 1},
    })

    local path = env.pathfinder.find_path(0x04, 4, 2, 0, 0, {})

    assert_truthy(path ~= nil and #path == 6, "test setup should still produce the shortest route")
    assert_equal(path[1].direction, "west", "blocked north start should force the initial west step")
    assert_equal(path[2].direction, "west", "equal-length tie after the forced segment should keep the route moving straight")
    assert_equal(path[3].direction, "west", "planner should keep delaying the turn while the straight option stays optimal")
    assert_equal(path[4].direction, "west", "planner should finish the straight run before turning")
    assert_equal(path[5].direction, "north", "planner should turn only after the straight segment is exhausted")
    assert_equal(path[6].direction, "north", "remaining shortest path should still finish with the needed north steps")

    env.restore()
end

function tests.trace_path_distinguishes_no_path_from_already_there()
    local env = make_stub_env()
    env.set_grid(5, 5)

    local opts = env.path_debug.build_find_path_opts()
    opts.on_complete({success = false, path_length = 0, nodes_visited = 12, reason = "no_path"})
    env.path_debug.store_path(0x04, 1, 1, 3, 3, nil, opts)
    env.path_debug.trace_path()

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "TRACE: no path found", "trace_path should log explicit no-path result")

    env.restore()
end

function tests.trace_path_reports_goal_not_walkable_reason()
    local env = make_stub_env()
    env.set_grid(5, 5)

    local opts = env.path_debug.build_find_path_opts()
    opts.on_complete({success = false, path_length = 0, nodes_visited = 0, reason = "goal_not_walkable"})
    env.path_debug.store_path(0x04, 1, 1, 3, 3, nil, opts)
    env.path_debug.trace_path()

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "TRACE: goal is not walkable", "trace_path should report blocked-goal reason")

    env.restore()
end

local failures = 0
local total = 0

for name, fn in pairs(tests) do
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        io.write(string.format("PASS  %s\n", name))
    else
        failures = failures + 1
        io.write(string.format("FAIL  %s: %s\n", name, tostring(err)))
    end
end

io.write(string.format("Ran %d Lua unit tests\n", total))

if failures > 0 then
    os.exit(1)
end
