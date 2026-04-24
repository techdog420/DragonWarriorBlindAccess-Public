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
    local inject_step_calls = 0
    local last_injected_dir = nil
    local pathfind_calls = 0
    local last_direct_call = nil
    local last_adjacent_call = nil
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
                return options.blocking_positions or {}
            end,
            request_refresh = function() end,
        }
    end

    package.preload["pathfinder"] = function()
        return {
            pathfind_to = function(_, start_x, start_y, goal_x, goal_y, blocking)
                pathfind_calls = pathfind_calls + 1
                reroute_calls = reroute_calls + 1
                last_direct_call = {
                    start_x = start_x,
                    start_y = start_y,
                    goal_x = goal_x,
                    goal_y = goal_y,
                    blocking = blocking,
                }
                if pathfind_mode == "always_no_path" then
                    return "No path found", nil, nil
                end
                if pathfind_mode == "direct_no_path_adjacent_ok" then
                    return "No path found", nil, nil
                end
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
            pathfind_to_adjacent = function(_, start_x, start_y, goal_x, goal_y, blocking)
                pathfind_calls = pathfind_calls + 1
                reroute_calls = reroute_calls + 1
                last_adjacent_call = {
                    start_x = start_x,
                    start_y = start_y,
                    goal_x = goal_x,
                    goal_y = goal_y,
                    blocking = blocking,
                }
                if pathfind_mode == "always_no_path" then
                    return "No path found", nil, nil
                end
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
            get_directional_blocks = function()
                return {}
            end,
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
            inject_step = function(dir)
                inject_step_calls = inject_step_calls + 1
                last_injected_dir = dir
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
        inject_step_calls = function() return inject_step_calls end,
        last_injected_dir = function() return last_injected_dir end,
        last_direct_call = function() return last_direct_call end,
        last_adjacent_call = function() return last_adjacent_call end,
        seam_summary = function(map_id) return route_manager.get_seam_summary(map_id) end,
        seam_entries = function(map_id) return route_manager.get_seam_entries(map_id) end,
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

local function assert_not_contains(haystack, needle, message)
    if string.find(haystack, needle, 1, true) then
        error(string.format("%s: unexpected %s in %s", message, needle, haystack), 2)
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

function tests.first_blocked_step_stays_in_seam_memory_until_confirmed()
    local env = make_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "up", {queued_route = false})

    assert_equal(
        env.route_manager.count_runtime_blocks(0x05),
        0,
        "first blocked step should stay in seam memory instead of becoming a hard runtime block"
    )
    assert_equal(
        env.seam_summary(0x05).blocked_only,
        1,
        "first blocked step should create one blocked-only seam observation"
    )

    env.restore()
end

function tests.repeated_blocked_steps_promote_runtime_block_after_threshold()
    local env = make_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "up", {queued_route = false})
    env.auto_step.on_blocked(5, 4, "up", {queued_route = false})
    env.auto_step.on_blocked(5, 4, "up", {queued_route = false})

    assert_equal(
        env.route_manager.count_runtime_blocks(0x05),
        1,
        "repeated one-sided blocked steps should promote a confirmed runtime block"
    )
    assert_equal(
        env.route_manager.build_path_blocking(0x05)["5,3"].south,
        true,
        "promoted seam should appear as a directional runtime block"
    )

    env.restore()
end

function tests.successful_traversal_clears_runtime_block_and_marks_noisy_seam()
    local env = make_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "up", {queued_route = false})
    env.auto_step.on_blocked(5, 4, "up", {queued_route = false})
    env.auto_step.on_blocked(5, 4, "up", {queued_route = false})
    env.auto_step.on_step_complete(5, 4, "up", 5, 3, {queued_route = false, source = "test"})

    assert_equal(
        env.route_manager.count_runtime_blocks(0x05),
        0,
        "a successful traversal should clear the promoted runtime block again"
    )
    assert_equal(
        env.seam_summary(0x05).noisy,
        1,
        "mixed blocked and moved history should be classified as a noisy seam"
    )

    env.restore()
end

function tests.non_route_blocked_step_does_not_trigger_reroute()
    local env = make_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "up", {queued_route = false})

    assert_equal(
        env.route_manager.count_runtime_blocks(0x05),
        0,
        "non-route blocked steps should not immediately create runtime blocks"
    )
    assert_equal(
        env.seam_summary(0x05).blocked_only,
        1,
        "non-route blocked steps should still be remembered as seam observations"
    )
    assert_equal(
        env.pathfind_calls(),
        1,
        "non-route blocked steps should not trigger reroute pathfinding"
    )
    assert_equal(
        env.start_route_calls(),
        1,
        "non-route blocked steps should not queue a reroute"
    )

    env.restore()
end

function tests.survey_safe_planning_still_respects_frozen_npc_blockers()
    local env = make_env({
        pathfind_mode = "block_sensitive",
        pathfind_block_key = "5,3",
        blocking_positions = {
            {x = 5, y = 3},
        },
    })

    local plan = env.route_manager.plan_path_to_object({
        name = "Chest",
        type = "chest",
        x = 6,
        y = 1,
    }, {
        survey_safe = true,
        store_debug_path = false,
    })

    assert_equal(
        plan.result,
        "No path found",
        "survey_safe planning should not ignore frozen NPC blockers during actual route planning"
    )

    env.restore()
end

function tests.preview_planning_can_override_origin_and_blocking_state()
    local env = make_env({
        pathfind_mode = "direct_no_path_adjacent_ok",
    })

    local plan = env.route_manager.plan_path_to_object({
        name = "Preview Chest",
        type = "chest",
        x = 6,
        y = 1,
    }, {
        map_id = 0x07,
        start_x = 8,
        start_y = 8,
        blocking = {["8,7"] = {south = true}},
        allow_adjacent_fallback = true,
        store_debug_path = false,
    })

    local direct = env.last_direct_call()
    local adjacent = env.last_adjacent_call()
    assert_equal(plan.map_id, 0x07, "preview plans should report the overridden map id")
    assert_equal(plan.start_x, 8, "preview plans should use the overridden start X")
    assert_equal(plan.start_y, 8, "preview plans should use the overridden start Y")
    assert_equal(plan.path_mode, "adjacent", "preview planning should preserve chest adjacent fallback behavior")
    assert_equal(direct.start_x, 8, "direct preview planning should call the pathfinder with the overridden start X")
    assert_equal(direct.start_y, 8, "direct preview planning should call the pathfinder with the overridden start Y")
    assert_equal(direct.blocking["8,7"].south, true, "direct preview planning should pass through the supplied blocking state")
    assert_equal(adjacent.start_x, 8, "adjacent fallback should reuse the overridden preview origin")
    assert_equal(adjacent.start_y, 8, "adjacent fallback should reuse the overridden preview origin")
    assert_equal(adjacent.blocking["8,7"].south, true, "adjacent fallback should reuse the supplied preview blocking state")

    env.restore()
end

function tests.reroute_no_path_bruteforces_unconfirmed_seam()
    local env = make_env({pathfind_mode = "reroute_no_path"})

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "up")

    assert_equal(
        env.inject_step_calls(),
        1,
        "an unconfirmed seam with no alternate route should trigger a brute-force retry"
    )
    assert_equal(
        env.route_manager.count_runtime_blocks(0x05),
        0,
        "an unconfirmed seam should not be promoted to a hard runtime block on the first reroute failure"
    )
    assert_not_contains(
        table.concat(env.outputs, "\n"),
        "No path found. Pathfinding cancelled.",
        "the first no-path reroute on an unconfirmed seam should not cancel immediately"
    )

    env.restore()
end

function tests.successful_seam_bruteforce_requeues_followup_route()
    local env = make_env({pathfind_mode = "block_sensitive"})

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "up")
    env.auto_step.on_step_complete(5, 4, "up", 5, 3, {queued_route = false, source = "test"})

    assert_equal(
        env.inject_step_calls(),
        1,
        "blocked seam should still trigger a brute-force step first"
    )
    assert_equal(
        env.start_route_calls(),
        2,
        "a successful brute-force seam step should queue a fresh follow-up route"
    )
    assert_contains(
        table.concat(env.outputs, "\n"),
        "Seam crossed.",
        "successful seam brute force should be announced"
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

function tests.autowalk_immediate_no_path_releases_npc_freeze()
    local env = make_env({pathfind_mode = "always_no_path"})

    env.route_manager.autowalk_to_current()

    assert_equal(
        env.route_manager.is_npc_freeze_active(),
        false,
        "immediate autowalk no-path should release NPC freeze"
    )
    assert_contains(
        table.concat(env.outputs, "\n"),
        "No path found",
        "immediate no-path should be announced"
    )

    env.restore()
end

function tests.autowalk_falls_back_to_adjacent_for_chest_when_direct_fails()
    local env = make_env({pathfind_mode = "direct_no_path_adjacent_ok"})

    env.route_manager.autowalk_to_current()

    assert_equal(env.start_route_calls(), 1, "chest fallback should still queue a route")
    assert_contains(
        table.concat(env.outputs, "\n"),
        "Auto-walk.",
        "fallback success should be announced as a normal autowalk"
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
