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
    local logs = {}

    local function set_grid(new_width, new_height, blocked_cells)
        width = new_width
        height = new_height
        grid = {}
        for y = 0, height - 1 do
            for x = 0, width - 1 do
                grid[x .. "," .. y] = true
            end
        end
        for _, cell in ipairs(blocked_cells or {}) do
            grid[cell.x .. "," .. cell.y] = false
        end
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
        logs = logs,
        pathfinder = pathfinder,
        path_debug = path_debug,
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
