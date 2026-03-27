-- test_route_manager.lua
-- Focused regression tests for route_manager entry guards.

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

local function make_env(options)
    options = options or {}
    local outputs = {}
    local start_route_calls = 0
    local pathfind_calls = 0
    local pathfind_mode = options.pathfind_mode or "always_path"
    local pathfind_block_key = options.pathfind_block_key or "5,3"
    local reroute_calls = 0
    local module_names = {
        "addresses",
        "auto_step",
        "debug_tools",
        "game_snapshot",
        "map_reader",
        "navigation",
        "objects",
        "path_debug",
        "pathfinder",
        "route_manager",
        "tolk",
    }

    for _, name in ipairs(module_names) do
        save_module(name)
        package.loaded[name] = nil
    end

    _G.memory = _G.memory or {}
    _G.memory.readbyte = function()
        return 0
    end
    _G.memory.writebyte = function() end

    package.preload["addresses"] = function()
        return {
            NPC_COUNT = 20,
            NPC_DATA_START = 0,
            NPC_ENTRY_SIZE = 3,
        }
    end

    package.preload["navigation"] = function()
        return {
            get_position = function()
                return 0x05, 5, 4
            end,
        }
    end

    package.preload["objects"] = function()
        return {
            TYPE_CHEST = "chest",
            TYPE_NPC = "npc",
            TYPE_DOOR = "door",
            current_object = function()
                return {name = "Chest", type = "chest", x = 6, y = 1}
            end,
            update_npcs = function() end,
            get_blocking_positions = function()
                return {}
            end,
            request_refresh = function() end,
        }
    end

    package.preload["pathfinder"] = function()
        return {
            pathfind_to = function(_, _, _, _, _, blocking)
                pathfind_calls = pathfind_calls + 1
                reroute_calls = reroute_calls + 1
                if pathfind_mode == "reroute_no_path" and reroute_calls >= 2 then
                    return "No path found", nil, nil
                end
                if pathfind_mode == "block_sensitive" and blocking and blocking[pathfind_block_key] then
                    return "No path found", nil, nil
                end
                return "Path: 1 north", "north", {
                    {x = 5, y = 3, direction = "north"},
                }
            end,
            pathfind_to_adjacent = function(_, _, _, _, _, blocking)
                pathfind_calls = pathfind_calls + 1
                reroute_calls = reroute_calls + 1
                if pathfind_mode == "reroute_no_path" and reroute_calls >= 2 then
                    return "No path found", nil, nil
                end
                if pathfind_mode == "block_sensitive" and blocking and blocking[pathfind_block_key] then
                    return "No path found", nil, nil
                end
                return "Approach: 1 north", "north", {
                    {x = 5, y = 3, direction = "north"},
                }
            end,
        }
    end

    package.preload["map_reader"] = function()
        return {
            is_walkable = function()
                return true
            end,
        }
    end

    package.preload["auto_step"] = function()
        local stub = {
            start_route = function()
                start_route_calls = start_route_calls + 1
                return true
            end,
        }
        return stub
    end

    package.preload["tolk"] = function()
        return {
            output_interrupt = function(msg)
                outputs[#outputs + 1] = msg
            end,
        }
    end

    package.preload["debug_tools"] = function()
        return {
            DEBUG_MODE = true,
            info = function() end,
            debug = function() end,
            error = function() end,
        }
    end

    package.preload["path_debug"] = function()
        return {
            store_path = function() end,
            is_validating = function() return false end,
            is_step_mode = function() return false end,
        }
    end

    package.preload["game_snapshot"] = function()
        return {
            keys = 0,
            terrain_offset = 0x10,
        }
    end

    local route_manager = require "route_manager"

    return {
        outputs = outputs,
        auto_step = package.loaded["auto_step"],
        route_manager = route_manager,
        pathfind_calls = function() return pathfind_calls end,
        start_route_calls = function() return start_route_calls end,
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

local function assert_contains(haystack, needle, message)
    if not string.find(haystack, needle, 1, true) then
        error(string.format("%s: missing %s in %s", message, needle, haystack), 2)
    end
end

local tests = {}

function tests.autowalk_guard_blocks_planning()
    local env = make_env()
    env.route_manager.set_autowalk_guard(function()
        return false, "Wait for the upper dialogue window to clear before auto-walking"
    end)

    env.route_manager.autowalk_to_current()

    assert_equal(env.pathfind_calls(), 0, "guarded autowalk should not call the path planner")
    assert_equal(env.start_route_calls(), 0, "guarded autowalk should not queue route steps")
    assert_contains(
        table.concat(env.outputs, "\n"),
        "Wait for the upper dialogue window to clear before auto-walking",
        "guarded autowalk should surface the refusal reason"
    )

    env.restore()
end

function tests.blocked_step_records_runtime_block_immediately()
    local env = make_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "up")

    assert_equal(
        env.route_manager.count_runtime_blocks(0x05),
        1,
        "blocked step should be recorded as a runtime block immediately"
    )
    assert_equal(
        env.route_manager.build_path_blocking(0x05)["5,3"],
        "runtime",
        "blocked destination should appear as runtime in path blocking table"
    )

    env.restore()
end

function tests.duplicate_blocked_step_does_not_double_count()
    local env = make_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "up")
    env.auto_step.on_blocked(5, 4, "up")

    assert_equal(
        env.route_manager.count_runtime_blocks(0x05),
        1,
        "duplicate blocked steps should not create multiple runtime blocks"
    )

    env.restore()
end

function tests.reroute_cancellation_keeps_runtime_blocks()
    local env = make_env({pathfind_mode = "reroute_no_path"})

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "up")

    assert_equal(
        env.route_manager.count_runtime_blocks(0x05),
        1,
        "reroute cancellation should keep the runtime block for future routes"
    )
    assert_contains(
        table.concat(env.outputs, "\n"),
        "No path found. Pathfinding cancelled.",
        "reroute cancellation should be announced"
    )

    env.restore()
end

function tests.autowalk_freezes_npcs_and_releases_on_route_complete()
    local env = make_env()

    env.route_manager.autowalk_to_current()
    assert_equal(
        env.route_manager.is_npc_freeze_active(),
        true,
        "autowalk should freeze NPCs before planning even for non-NPC targets"
    )

    env.auto_step.on_route_complete()
    assert_equal(
        env.route_manager.is_npc_freeze_active(),
        false,
        "route completion should release NPC freeze"
    )

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
