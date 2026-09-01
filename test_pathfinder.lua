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

local function make_rimuldar_integration_env()
    local rows = {
        "000000000000000000000000000000",
        "000222222222222222000000000000",
        "022244488000000002222000000000",
        "0E0066480000088800082222000000",
        "220066400006666666688002222000",
        "284666408006080611600000882000",
        "2844F4400446444644600444442000",
        "204666400466646664600466642200",
        "20444440046664666468044F441200",
        "200000000444444444666666641200",
        "20000002280000080060C466641200",
        "208022222200066666660466641220",
        "210228882208666666660444448020",
        "212280082006660000660000888820",
        "2111808220666008006666666666E6",
        "2122882200660088006666666666E6",
        "21022220006608804D600880088820",
        "208000080066008444644444448020",
        "20000088806608846F646646640220",
        "204444444466408444666666640200",
        "204666666666400466666646648200",
        "204666646666408446444B44448200",
        "204446646666401466646646642200",
        "2846F66664464014666466B6342000",
        "284446646666401444444444442000",
        "224666646666481111800882222000",
        "024666666666488008002222000000",
        "024444444444488882222000000000",
        "000222222222222222000000000000",
        "000000000000000000000000000000",
    }
    local data_start = 0x200
    local map_id = 0x0B
    local base = map_id * 5
    local cpu_ptr = data_start - 0x10 + 0x8000
    local rom_bytes = {
        [base] = cpu_ptr % 256,
        [base + 1] = math.floor(cpu_ptr / 256),
        [base + 2] = 29,
        [base + 3] = 29,
        [base + 4] = 0,
    }

    for y, row in ipairs(rows) do
        assert(#row == 30, string.format("Rimuldar fixture row %d must contain 30 block IDs", y - 1))
        for x = 1, 30, 2 do
            rom_bytes[data_start + (y - 1) * 15 + math.floor((x - 1) / 2)] = assert(tonumber(row:sub(x, x + 1), 16))
        end
    end

    local module_names = {
        "addresses",
        "config",
        "debug_tools",
        "map_reader",
        "maps",
        "pathfinder",
    }
    local saved_modules = {}
    for _, name in ipairs(module_names) do
        saved_modules[name] = {
            preload = package.preload[name],
            loaded = package.loaded[name],
        }
        package.loaded[name] = nil
    end

    package.preload["addresses"] = function()
        return {
            ROM_MAP_META_START = 0,
            ROM_MAP_META_SIZE = 5,
            DOOR_ARRAY_MAX = 0,
            DOOR_X_POS_START = 0,
            DOOR_Y_POS_START = 0,
            DOOR_ARRAY_STRIDE = 0,
            TERRAIN_OFFSET = 0x10,
        }
    end
    package.preload["config"] = function()
        return {get = function() return nil end}
    end
    package.preload["debug_tools"] = function()
        return {
            info = function() end,
            debug = function() end,
            error = function() end,
        }
    end
    package.preload["map_reader"] = nil
    package.preload["maps"] = nil
    package.preload["pathfinder"] = nil

    local saved_globals = {
        rom = _G.rom,
        memory = _G.memory,
        AND = _G.AND,
    }
    _G.rom = {
        readbyte = function(address)
            return rom_bytes[address] or 0
        end,
    }
    _G.memory = {
        readbyte = function(address)
            if address == 0x10 then return 0x10 end
            return 0
        end,
    }
    _G.AND = function(a, b)
        local result = 0
        local bit = 1
        while a > 0 and b > 0 do
            if a % 2 == 1 and b % 2 == 1 then
                result = result + bit
            end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            bit = bit * 2
        end
        return result
    end

    local restored = false
    local function restore()
        if restored then return end
        for _, name in ipairs(module_names) do
            package.preload[name] = saved_modules[name].preload
            package.loaded[name] = saved_modules[name].loaded
        end
        _G.rom = saved_globals.rom
        _G.memory = saved_globals.memory
        _G.AND = saved_globals.AND
        restored = true
    end

    local ok, result = pcall(function()
        local map_reader = require "map_reader"
        local pathfinder = require "pathfinder"
        return {
            map_reader = map_reader,
            pathfinder = pathfinder,
        }
    end)
    if not ok then
        restore()
        error(result, 0)
    end

    result.restore = restore
    return result
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

local function with_cleanup(body, cleanup)
    local ok, err = pcall(body)
    local cleanup_ok, cleanup_err = pcall(cleanup)

    if not ok then
        if not cleanup_ok then
            error(string.format("%s (cleanup failed: %s)", tostring(err), tostring(cleanup_err)), 0)
        end
        error(err, 0)
    end
    if not cleanup_ok then
        error(cleanup_err, 0)
    end
end

local function path_to_string(path)
    local parts = {}
    for _, step in ipairs(path or {}) do
        parts[#parts + 1] = string.format("%s->%d,%d", step.direction or "?", step.x or -1, step.y or -1)
    end
    return table.concat(parts, " ")
end

local tests = {}

function tests.overworld_astar_requires_explicit_opt_in_and_respects_safe_snapshot()
    local env = make_stub_env()
    env.set_grid(5, 3)

    local default_path = env.pathfinder.find_path(
        0x01, 0, 1, 4, 1, {})
    assert_equal(default_path, nil,
        "ordinary overworld pathfinding should remain disabled")

    local snapshot = {}
    for y = 0, 2 do
        snapshot[y] = {}
        for x = 0, 4 do
            snapshot[y][x] = true
        end
    end
    snapshot[1][2] = false

    local result, _, path = env.pathfinder.pathfind_to(
        0x01,
        0,
        1,
        4,
        1,
        {},
        {
            allow_overworld = true,
            walkability_snapshot = snapshot,
        })

    assert_truthy(path, "explicit overworld A* should return a path")
    assert_equal(#path, 6,
        "safe overworld path should detour around the blocked snapshot cell")
    for _, step in ipairs(path) do
        assert_truthy(not (step.x == 2 and step.y == 1),
            "safe overworld path must not cross the blocked snapshot cell")
    end
    assert_contains(result, "Path:",
        "explicit overworld A* should return grouped path guidance")

    env.restore()
end

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

function tests.goal_out_of_bounds_reports_reason_without_search()
    local env = make_stub_env()
    env.set_grid(5, 5)

    local opts = env.path_debug.build_find_path_opts()
    local path = env.pathfinder.find_path(0x04, 1, 1, 5, 1, {}, opts)
    local stats = opts._get_stats()

    assert_equal(path, nil, "out-of-bounds goal should not return a path")
    assert_equal(stats.reason, "goal_out_of_bounds", "out-of-bounds goal should set goal_out_of_bounds reason")
    assert_equal(stats.nodes_visited, 0, "out-of-bounds goal should not visit nodes")

    env.restore()
end

function tests.adjacent_goal_out_of_bounds_does_not_route_to_boundary_stand()
    local env = make_stub_env()
    env.set_grid(5, 5)

    local opts = env.path_debug.build_find_path_opts()
    local result, face_dir, path = env.pathfinder.pathfind_to_adjacent(0x04, 1, 1, 5, 1, {}, opts)
    local stats = opts._get_stats()

    assert_equal(result, "No path found", "out-of-bounds adjacent goal should not route to boundary stand")
    assert_equal(face_dir, nil, "out-of-bounds adjacent goal should not return a face direction")
    assert_equal(path, nil, "out-of-bounds adjacent goal should not return a path")
    assert_equal(stats.reason, "goal_out_of_bounds", "out-of-bounds adjacent goal should report goal_out_of_bounds")
    assert_equal(stats.nodes_visited, 0, "out-of-bounds adjacent goal should not search adjacent stands")

    local direct_opts = env.path_debug.build_find_path_opts()
    local raw_path, raw_face, raw_adj = env.pathfinder.find_route_to_adjacent(0x04, 1, 1, 5, 1, {}, direct_opts)
    local direct_stats = direct_opts._get_stats()

    assert_equal(raw_path, nil, "low-level adjacent helper should reject out-of-bounds goal")
    assert_equal(raw_face, nil, "low-level adjacent helper should not face an out-of-bounds goal")
    assert_equal(raw_adj, nil, "low-level adjacent helper should not select a boundary stand")
    assert_equal(direct_stats.reason, "goal_out_of_bounds", "low-level adjacent helper should report goal_out_of_bounds")

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

function tests.rimuldar_live_magic_key_route_uses_real_decoder_and_pathfinder()
    local env = make_rimuldar_integration_env()

    with_cleanup(function()
        assert_equal(env.map_reader.get_raw_block_id(0x0B, 1, 3), 0xE, "Rimuldar bridge raw block")
        assert_equal(env.map_reader.get_raw_block_id(0x0B, 4, 5), 0x6, "Rimuldar merchant stand raw block")
        assert_equal(env.map_reader.get_raw_block_id(0x0B, 4, 6), 0xF, "Rimuldar counter raw block")
        assert_equal(env.map_reader.is_walkable(0x0B, 4, 6), false, "Rimuldar counter should not be walkable")

        local blockers = {
            ["27,0"] = true,
            ["2,4"] = true,
            ["4,7"] = true,
        }
        local path = env.pathfinder.find_path(0x0B, 29, 14, 4, 5, blockers)
        assert_truthy(path ~= nil, "real Rimuldar stack should find the live Magic Key route")
        -- The manually walked proof used a 54-move x=5 tail. Correct terrain
        -- also permits the shorter (4,3)->(4,4)->(4,5) tail, so A* uses 52.
        assert_equal(#path, 52, "real Rimuldar route should use the deterministic shortest path: " .. path_to_string(path))

        local waypoints = {
            {29, 2}, {21, 2}, {21, 0}, {0, 0}, {0, 3}, {1, 3}, {2, 3},
            {3, 3}, {4, 3}, {4, 4}, {4, 5},
        }
        local next_waypoint = 1
        for _, step in ipairs(path) do
            local waypoint = waypoints[next_waypoint]
            if waypoint and step.x == waypoint[1] and step.y == waypoint[2] then
                next_waypoint = next_waypoint + 1
            end
        end
        assert_equal(
            next_waypoint,
            #waypoints + 1,
            "real Rimuldar route should visit every required waypoint in order: " .. path_to_string(path)
        )

        local forbidden = {
            ["27,0"] = true,
            ["2,4"] = true,
            ["4,7"] = true,
            ["4,6"] = true,
        }
        for _, step in ipairs(path) do
            local key = step.x .. "," .. step.y
            assert_equal(forbidden[key], nil, "real Rimuldar route should avoid blocked/counter cell " .. key)
        end

        local open_top_bank = env.pathfinder.find_path(0x0B, 26, 0, 28, 0, {})
        assert_truthy(open_top_bank ~= nil, "unoccupied top-bank control should have a path")
        assert_equal(#open_top_bank, 2, "unoccupied top-bank control should use the direct two-step route")
        assert_equal(open_top_bank[1].x, 27, "unoccupied top-bank control should cross terrain under Person 4")
        assert_equal(open_top_bank[1].y, 0, "unoccupied top-bank control should remain on row 0")
        assert_equal(open_top_bank[2].x, 28, "unoccupied top-bank control should reach the east-side endpoint")
        assert_equal(open_top_bank[2].y, 0, "unoccupied top-bank endpoint should remain on row 0")

        local blocked_top_bank = env.pathfinder.find_path(0x0B, 26, 0, 28, 0, {["27,0"] = true})
        assert_equal(blocked_top_bank, nil, "Person 4 at (27,0) should split the local top-bank lane")
    end, env.restore)
end

function tests.rimuldar_magic_key_return_uses_nearby_world_exit()
    local env = make_rimuldar_integration_env()

    with_cleanup(function()
        local blockers = {
            ["2,4"] = true,
            ["4,7"] = true,
        }
        local nearby_exit = env.pathfinder.find_path(0x0B, 4, 5, 0, 3, blockers)
        assert_truthy(nearby_exit ~= nil, "real Rimuldar stack should route from the Magic Key stand to the nearby west-exit stand")
        assert_equal(#nearby_exit, 6, "Magic Key return should reach the live west-edge stand: " .. path_to_string(nearby_exit))

        local expected = {
            {"west", 3, 5},
            {"north", 3, 4},
            {"north", 3, 3},
            {"west", 2, 3},
            {"west", 1, 3},
            {"west", 0, 3},
        }
        for index, step in ipairs(expected) do
            assert_equal(nearby_exit[index].direction, step[1], "Magic Key exit route direction mismatch: " .. path_to_string(nearby_exit))
            assert_equal(nearby_exit[index].x, step[2], "Magic Key exit route X mismatch: " .. path_to_string(nearby_exit))
            assert_equal(nearby_exit[index].y, step[3], "Magic Key exit route Y mismatch: " .. path_to_string(nearby_exit))
        end

        local east_return = env.pathfinder.find_path(0x0B, 4, 5, 29, 13, blockers)
        assert_truthy(east_return ~= nil, "Magic Key pocket should reverse the x=0 route back to the east entrance")
        local entered_west_exit_stand = false
        local used_false_bridge = false
        for _, step in ipairs(east_return) do
            if step.x == 0 and step.y == 3 and step.direction == "west" then
                entered_west_exit_stand = true
            elseif step.x == 2 and step.y == 5 and step.direction == "west" then
                used_false_bridge = true
            end
        end
        assert_equal(entered_west_exit_stand, true, "east-entrance return should enter the live (0,3) west-edge stand: " .. path_to_string(east_return))
        assert_equal(used_false_bridge, false, "east-entrance return must avoid the blocked (3,5)->(2,5) false bridge: " .. path_to_string(east_return))
    end, env.restore)
end

function tests.rimuldar_weapons_counter_round_trip_uses_west_corridor()
    local env = make_rimuldar_integration_env()

    with_cleanup(function()
        local blockers = { ["23,7"] = true }
        local function assert_run(path, first_index, last_index, direction, label)
            for index = first_index, last_index do
                assert_equal(path[index].direction, direction,
                    string.format("%s step %d should move %s: %s", label, index, direction, path_to_string(path)))
            end
        end

        local outbound = env.pathfinder.find_path(0x0B, 29, 14, 23, 9, blockers)
        assert_truthy(outbound ~= nil, "real Rimuldar stack should route from the entrance to the Weapons counter")
        assert_equal(#outbound, 21, "Weapons route should use the proven west corridor: " .. path_to_string(outbound))
        assert_run(outbound, 1, 11, "west", "entrance-to-counter")
        assert_run(outbound, 12, 16, "north", "entrance-to-counter")
        assert_run(outbound, 17, 21, "east", "entrance-to-counter")
        assert_equal(outbound[21].x, 23, "Weapons route should finish on public counter stand X")
        assert_equal(outbound[21].y, 9, "Weapons route should finish on public counter stand Y")

        local returned = env.pathfinder.find_path(0x0B, 23, 9, 29, 14, blockers)
        assert_truthy(returned ~= nil, "real Rimuldar stack should route back from the Weapons counter")
        assert_equal(#returned, 21, "Weapons return should use the proven west corridor: " .. path_to_string(returned))
        assert_run(returned, 1, 5, "west", "counter-to-entrance")
        assert_run(returned, 6, 10, "south", "counter-to-entrance")
        assert_run(returned, 11, 21, "east", "counter-to-entrance")
        assert_equal(returned[21].x, 29, "Weapons return should finish on entrance approach X")
        assert_equal(returned[21].y, 14, "Weapons return should finish on entrance approach Y")
    end, env.restore)
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
