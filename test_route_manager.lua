-- test_route_manager.lua
-- Focused regression tests for route_manager entry guards.

local original_preload = {}
local original_loaded = {}
local original_emulator_compat = _G.DW_EMULATOR_COMPAT
local original_joypad = _G.joypad

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
    local suppress_direction_tracking_calls = 0
    local last_suppress_direction_tracking_frames = nil
    local last_injected_dir = nil
    local pathfind_calls = 0
    local last_direct_call = nil
    local last_adjacent_call = nil
    local pathfind_mode = options.pathfind_mode or "always_path"
    local pathfind_block_key = options.pathfind_block_key or "5,3"
    local path_length = options.path_length or 1
    local reroute_calls = 0
    local update_npcs_calls = 0
    local request_refresh_calls = 0
    local joypad_sets = {}
    local memory_values = options.memory_values or {}
    local memory_writes = {}
    local current_object = options.current_object or {id = "chest_1", name = "Chest", type = "chest", x = 6, y = 1}
    local object_list = options.object_list or {current_object}
    local pathability_filter = 1
    local pathability_statuses = {}
    local module_names = {
        "addresses",
        "auto_step",
        "config",
        "debug_tools",
        "game_snapshot",
        "map_reader",
        "maps",
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
    _G.memory.readbyte = function(address)
        return memory_values[address] or 0
    end
    _G.memory.writebyte = function(address, value)
        memory_writes[#memory_writes + 1] = {address = address, value = value}
        memory_values[address] = value
    end
    _G.DW_EMULATOR_COMPAT = {
        is_bizhawk = options.is_bizhawk == true,
    }
    _G.joypad = {
        set = function(player, buttons)
            joypad_sets[#joypad_sets + 1] = {player = player, buttons = buttons}
        end,
    }

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

    package.preload["maps"] = function()
        return {
            is_overworld = function()
                return options.is_overworld == true
            end,
        }
    end

    package.preload["objects"] = function()
        local pathability_names = {
            [1] = "All",
            [2] = "Reachable",
            [3] = "Unreachable",
        }
        return {
            TYPE_CHEST = "chest",
            TYPE_NPC = "npc",
            TYPE_DOOR = "door",
            TYPE_EXIT = "exit",
            TYPE_STAIR = "stair",
            PATHABILITY_ALL = 1,
            PATHABILITY_REACHABLE = 2,
            PATHABILITY_UNREACHABLE = 3,
            current_object = function()
                return current_object
            end,
            describe_object = function(obj)
                return (obj and obj.name or "Object") .. ": 3 north"
            end,
            describe_current = function()
                return options.current_description or (current_object.name .. ": 3 north (1 of 1)")
            end,
            update_npcs = function()
                update_npcs_calls = update_npcs_calls + 1
            end,
            get_blocking_positions = function()
                return options.blocking_positions or {}
            end,
            get_objects = function()
                local copy = {}
                for i, obj in ipairs(object_list) do
                    copy[i] = obj
                end
                return copy
            end,
            set_pathability_statuses = function(statuses)
                pathability_statuses = statuses or {}
            end,
            clear_pathability_statuses = function()
                pathability_statuses = {}
            end,
            set_pathability_filter = function(filter)
                pathability_filter = filter
                return pathability_names[pathability_filter]
            end,
            get_pathability_filter = function()
                return pathability_filter
            end,
            get_pathability_filter_name = function()
                return pathability_names[pathability_filter]
            end,
            is_pathability_filter_active = function()
                return pathability_filter ~= 1
            end,
            get_filter_summary = function()
                if pathability_filter == 1 then
                    return "All"
                end
                return "All, " .. pathability_names[pathability_filter]:lower()
            end,
            get_count = function()
                return options.object_count or #object_list
            end,
            request_refresh = function()
                request_refresh_calls = request_refresh_calls + 1
            end,
        }
    end

    package.preload["pathfinder"] = function()
        local function should_return_no_path(blocking)
            if pathfind_mode == "always_no_path" then
                return true
            end
            if pathfind_mode == "reroute_no_path" and reroute_calls >= 2 then
                return true
            end
            if pathfind_mode == "block_sensitive" and blocking and blocking[pathfind_block_key] then
                return true
            end
            return false
        end
        local function one_step_path()
            local path = {}
            for i = 1, path_length do
                path[i] = {x = 5, y = 4 - i, direction = "north"}
            end
            return path
        end
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
                if options.unreachable_goal_key and goal_x .. "," .. goal_y == options.unreachable_goal_key then
                    return "No path found", nil, nil
                end
                return "Path: 1 north", "north", one_step_path()
            end,
            find_route_to = function(_, start_x, start_y, goal_x, goal_y, blocking)
                pathfind_calls = pathfind_calls + 1
                reroute_calls = reroute_calls + 1
                last_direct_call = {
                    start_x = start_x,
                    start_y = start_y,
                    goal_x = goal_x,
                    goal_y = goal_y,
                    blocking = blocking,
                }
                if pathfind_mode == "direct_no_path_adjacent_ok"
                and goal_x == current_object.x
                and goal_y == current_object.y then
                    return nil
                end
                if should_return_no_path(blocking) then
                    return nil
                end
                if options.unreachable_goal_key and goal_x .. "," .. goal_y == options.unreachable_goal_key then
                    return nil
                end
                return one_step_path()
            end,
            pathfind_to_adjacent = function(_, start_x, start_y, goal_x, goal_y, blocking, opts)
                pathfind_calls = pathfind_calls + 1
                reroute_calls = reroute_calls + 1
                last_adjacent_call = {
                    start_x = start_x,
                    start_y = start_y,
                    goal_x = goal_x,
                    goal_y = goal_y,
                    blocking = blocking,
                    opts = opts,
                }
                if pathfind_mode == "already_adjacent" then
                    return "Adjacent", "north", {}
                end
                if pathfind_mode == "always_no_path" then
                    return "No path found", nil, nil
                end
                if pathfind_mode == "reroute_no_path" and reroute_calls >= 2 then
                    return "No path found", nil, nil
                end
                if pathfind_mode == "block_sensitive" and blocking and blocking[pathfind_block_key] then
                    return "No path found", nil, nil
                end
                return "Approach: 1 north", "north", one_step_path()
            end,
            find_route_to_adjacent = function(_, start_x, start_y, goal_x, goal_y, blocking, opts)
                pathfind_calls = pathfind_calls + 1
                reroute_calls = reroute_calls + 1
                last_adjacent_call = {
                    start_x = start_x,
                    start_y = start_y,
                    goal_x = goal_x,
                    goal_y = goal_y,
                    blocking = blocking,
                    opts = opts,
                }
                if should_return_no_path(blocking) then
                    return nil, nil, nil, {}
                end
                return one_step_path(), "north", {x = 5, y = 3}, {}
            end,
        }
    end

    package.preload["map_reader"] = function()
        local closed_door_cells = options.closed_door_cells or {}
        local non_walkable_cells = options.non_walkable_cells or closed_door_cells
        return {
            get_map_dimensions = function()
                return options.map_width or 10, options.map_height or 10
            end,
            get_directional_blocks = function()
                return {}
            end,
            get_walkability_details = function(_, x, y)
                local k = x .. "," .. y
                if closed_door_cells[k] then
                    return {
                        effective_walkable = false,
                        reason = "door_closed",
                    }
                end
                if non_walkable_cells[k] then
                    return {
                        effective_walkable = false,
                        reason = "wall",
                    }
                end
                return {
                    effective_walkable = true,
                    reason = "tile_walkable",
                }
            end,
            is_walkable = function(_, x, y)
                if non_walkable_cells[x .. "," .. y] then
                    return false
                end
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
            suppress_direction_tracking = function(frames)
                suppress_direction_tracking_calls = suppress_direction_tracking_calls + 1
                last_suppress_direction_tracking_frames = frames
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

    package.preload["config"] = function()
        return {
            get = function(key)
                return options.config_values and options.config_values[key] or nil
            end,
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
        update_npcs_calls = function() return update_npcs_calls end,
        request_refresh_calls = function() return request_refresh_calls end,
        pathability_statuses = function() return pathability_statuses end,
        pathability_filter = function() return pathability_filter end,
        start_route_calls = function() return start_route_calls end,
        inject_step_calls = function() return inject_step_calls end,
        last_injected_dir = function() return last_injected_dir end,
        suppress_direction_tracking_calls = function() return suppress_direction_tracking_calls end,
        last_suppress_direction_tracking_frames = function() return last_suppress_direction_tracking_frames end,
        last_direct_call = function() return last_direct_call end,
        last_adjacent_call = function() return last_adjacent_call end,
        seam_summary = function(map_id) return route_manager.get_seam_summary(map_id) end,
        seam_entries = function(map_id) return route_manager.get_seam_entries(map_id) end,
        memory_writes = memory_writes,
        joypad_sets = joypad_sets,
        restore = function()
            restore_modules(module_names)
            _G.DW_EMULATOR_COMPAT = original_emulator_compat
            _G.joypad = original_joypad
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
    env.auto_step.on_blocked(5, 4, "up")
    env.auto_step.on_blocked(5, 4, "up")
    env.auto_step.on_blocked(5, 4, "up")

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

function tests.repeated_manual_blocked_steps_do_not_promote_runtime_block()
    local env = make_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "up", {queued_route = false})
    env.auto_step.on_blocked(5, 4, "up", {queued_route = false})
    env.auto_step.on_blocked(5, 4, "up", {queued_route = false})

    assert_equal(
        env.route_manager.count_runtime_blocks(0x05),
        0,
        "manual blocked steps should not promote into pathfinding runtime blocks"
    )
    assert_equal(
        env.seam_summary(0x05).blocked_only,
        1,
        "manual blocked steps should remain diagnostic seam observations"
    )

    env.restore()
end

function tests.queued_route_block_into_live_npc_does_not_promote_runtime_block()
    local env = make_env({
        pathfind_mode = "always_no_path",
        blocking_positions = {
            {x = 5, y = 3},
        },
    })

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "up")

    assert_equal(
        env.route_manager.count_runtime_blocks(0x05),
        0,
        "queued route blocks caused by live NPCs should not become runtime map blockers"
    )
    assert_equal(
        env.inject_step_calls(),
        0,
        "NPC blocks should not trigger seam brute-force retries"
    )
    assert_contains(
        table.concat(env.outputs, "\n"),
        "Route blocked by NPC movement",
        "NPC route blocks should give a player-facing temporary clutter message"
    )

    env.restore()
end

function tests.successful_traversal_marks_noisy_seam_but_confirmed_block_persists()
    -- After 3 consecutive blocks, the seam is confirmed and a runtime block is
    -- added. A single successful traversal changes the seam to "noisy" but does
    -- NOT clear the runtime block — one state-dependent pass is not enough
    -- evidence to erase a confirmed engine block. The block persists until either
    -- clear_runtime_blocks is called explicitly, or the map changes.
    local env = make_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "up")
    env.auto_step.on_blocked(5, 4, "up")
    env.auto_step.on_blocked(5, 4, "up")
    env.auto_step.on_step_complete(5, 4, "up", 5, 3, {queued_route = false, source = "test"})

    assert_equal(
        env.route_manager.count_runtime_blocks(0x05),
        1,
        "confirmed runtime block should NOT be cleared by a single successful traversal"
    )
    -- Because the runtime block persists, classify_seam_entry returns
    -- "confirmed_blocked" (runtime check fires first), not "noisy".
    assert_equal(
        env.seam_summary(0x05).confirmed_blocked,
        1,
        "seam with persistent runtime block should still be classified confirmed_blocked"
    )
    assert_equal(
        env.seam_summary(0x05).noisy,
        0,
        "noisy count should be 0 because runtime block keeps confirmed_blocked classification"
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

function tests.current_object_description_marks_unreachable_without_freezing_npcs()
    local env = make_env({pathfind_mode = "always_no_path"})

    local desc = env.route_manager.describe_current_object()

    assert_contains(desc, "Chest: 3 north", "object browser should keep the normal object description")
    assert_contains(desc, "Not currently reachable", "object browser should flag unreachable objects")
    assert_equal(
        env.route_manager.is_npc_freeze_active(),
        false,
        "object browser reachability preview should not freeze NPCs"
    )
    assert_equal(
        env.start_route_calls(),
        0,
        "object browser reachability preview should not queue movement"
    )

    env.restore()
end

function tests.bizhawk_object_description_skips_reachability_by_default()
    local env = make_env({
        is_bizhawk = true,
        pathfind_mode = "always_no_path",
    })

    local desc = env.route_manager.describe_current_object()

    assert_not_contains(desc, "Not currently reachable", "BizHawk default object descriptions should avoid path checks")
    assert_equal(env.pathfind_calls(), 0, "BizHawk default object descriptions should not call pathfinder")

    env.restore()
end

function tests.bizhawk_object_description_can_opt_into_reachability()
    local env = make_env({
        is_bizhawk = true,
        pathfind_mode = "always_no_path",
        config_values = {
            bizhawk_object_reachability_descriptions = "true",
        },
    })

    local desc = env.route_manager.describe_current_object()

    assert_contains(desc, "Not currently reachable", "BizHawk reachability setting should preserve path-check descriptions")
    if env.pathfind_calls() <= 0 then
        error("BizHawk reachability setting should call pathfinder", 2)
    end

    env.restore()
end

function tests.bizhawk_pathfind_uses_cached_object_blockers_by_default()
    local env = make_env({
        is_bizhawk = true,
        blocking_positions = {{x = 5, y = 3}},
    })

    env.route_manager.pathfind_to_current()

    assert_equal(env.update_npcs_calls(), 0, "BizHawk pathfind should avoid forced live NPC refresh by default")
    assert_equal(env.route_manager.is_npc_freeze_active(), false, "show-path should not leave NPC freeze active")
    local direct = env.last_direct_call()
    assert_equal(direct.blocking["5,3"], "npc", "cached object blockers should still be passed to pathfinding")

    env.restore()
end

function tests.bizhawk_route_refresh_npcs_can_be_opted_in()
    local env = make_env({
        is_bizhawk = true,
        config_values = {
            bizhawk_route_refresh_npcs = "true",
        },
    })

    env.route_manager.pathfind_to_current()

    assert_equal(env.update_npcs_calls(), 1, "BizHawk route refresh option should preserve live NPC refresh when requested")

    env.restore()
end

function tests.gameplay_adjacent_planning_skips_metrics_by_default()
    local env = make_env({
        current_object = {name = "Person", type = "npc", x = 6, y = 1},
    })

    env.route_manager.pathfind_to_current()

    assert_equal(
        env.last_adjacent_call().opts.use_adjacent_metrics,
        false,
        "normal object pathing should skip expensive adjacent tie metrics"
    )

    env.restore()
end

function tests.survey_safe_adjacent_planning_keeps_metrics()
    local env = make_env({
        current_object = {name = "Person", type = "npc", x = 6, y = 1},
    })

    env.route_manager.plan_path_to_object({
        name = "Person",
        type = "npc",
        x = 6,
        y = 1,
    }, {survey_safe = true})

    assert_equal(
        env.last_adjacent_call().opts.use_adjacent_metrics,
        nil,
        "survey-safe planning should keep adjacent diagnostics enabled"
    )

    env.restore()
end

function tests.current_object_description_leaves_reachable_objects_unchanged()
    local env = make_env()

    local desc = env.route_manager.describe_current_object()

    assert_equal(
        desc,
        "Chest: 3 north (1 of 1)",
        "reachable object descriptions should stay concise"
    )

    env.restore()
end

function tests.current_object_description_allows_chest_adjacent_fallback()
    local env = make_env({pathfind_mode = "direct_no_path_adjacent_ok"})

    local desc = env.route_manager.describe_current_object()

    assert_not_contains(
        desc,
        "Not currently reachable",
        "object browser should treat a chest as reachable when adjacent fallback works"
    )
    assert_equal(env.pathfind_calls() > 1, true, "chest preview should try another reachable tile after direct failure")

    env.restore()
end

function tests.object_pathability_filter_batches_reachability_without_npc_blocks()
    local env = make_env({
        object_list = {
            {id = "chest_reachable", name = "Reachable Chest", type = "chest", x = 6, y = 1},
            {id = "chest_unreachable", name = "Unreachable Chest", type = "chest", x = 8, y = 1},
        },
        blocking_positions = {{x = 6, y = 1}},
        unreachable_goal_key = "8,1",
        non_walkable_cells = {
            ["8,0"] = true,
            ["8,2"] = true,
            ["7,1"] = true,
            ["9,1"] = true,
        },
    })

    local info = env.route_manager.set_object_pathability_filter("reachable")
    local statuses = env.pathability_statuses()

    assert_equal(info.reachable, 1, "batch pathability should count reachable objects")
    assert_equal(info.unreachable, 1, "batch pathability should count unreachable objects")
    assert_equal(statuses.chest_reachable, true, "reachable target should be cached by object id")
    assert_equal(statuses.chest_unreachable, false, "unreachable target should be cached by object id")
    assert_equal(env.update_npcs_calls(), 0, "pathability filter should not force live NPC refresh")
    assert_equal(env.route_manager.is_npc_freeze_active(), false, "pathability filter should not freeze NPCs")

    local calls_after_first_pass = env.pathfind_calls()
    env.route_manager.refresh_object_pathability_filter_if_needed()
    assert_equal(env.pathfind_calls(), calls_after_first_pass, "unchanged pathability context should reuse the cached result")

    env.restore()
end

function tests.object_pathability_filter_resets_to_all_on_overworld()
    local env = make_env({is_overworld = true})

    local info = env.route_manager.set_object_pathability_filter("reachable")

    assert_equal(info.unavailable, true, "overworld should report reachability filtering unavailable")
    assert_equal(env.pathability_filter(), 1, "overworld pathability request should reset filter to All")
    assert_equal(env.pathfind_calls(), 0, "overworld pathability request should not call pathfinder")

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

function tests.failed_seam_bruteforce_retries_again_then_cancels_cleanly()
    local env = make_env({pathfind_mode = "reroute_no_path"})

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "up")
    env.auto_step.on_blocked(5, 4, "up", {queued_route = false})
    local retry_observation = env.route_manager.get_seam_observation(0x05, 5, 3, "south")

    assert_equal(
        env.inject_step_calls(),
        2,
        "a failed seam brute-force step should trigger the second retry before giving up"
    )
    assert_equal(
        retry_observation.last_source,
        "seam_retry_block",
        "failed seam brute-force retries should not be recorded as direct manual repros"
    )
    assert_not_contains(
        table.concat(env.outputs, "\n"),
        "No path found. Pathfinding cancelled.",
        "the second seam retry should not cancel until it also fails"
    )

    env.auto_step.on_blocked(5, 4, "up", {queued_route = false})

    assert_equal(
        env.route_manager.count_runtime_blocks(0x05),
        1,
        "three one-sided seam failures should promote the seam into a runtime block"
    )
    assert_contains(
        table.concat(env.outputs, "\n"),
        "No path found. Pathfinding cancelled.",
        "after the seam retry limit is exhausted the route should cancel cleanly"
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
    assert_equal(
        env.request_refresh_calls(),
        1,
        "FCEUX route completion should keep refreshing objects after cleanup"
    )

    env.restore()
end

function tests.bizhawk_route_complete_skips_object_refresh_by_default()
    local env = make_env({is_bizhawk = true})

    env.route_manager.autowalk_to_current()
    env.auto_step.on_route_complete()

    assert_equal(
        env.request_refresh_calls(),
        0,
        "BizHawk route completion should avoid the slow object refresh by default"
    )

    env.restore()
end

function tests.bizhawk_route_cleanup_refresh_can_be_opted_in()
    local env = make_env({
        is_bizhawk = true,
        config_values = {
            bizhawk_route_cleanup_refresh_objects = "true",
        },
    })

    env.route_manager.autowalk_to_current()
    env.auto_step.on_route_complete()

    assert_equal(
        env.request_refresh_calls(),
        1,
        "BizHawk route cleanup refresh option should preserve the old object refresh"
    )

    env.restore()
end

function tests.bizhawk_route_cancel_skips_object_refresh_by_default()
    local env = make_env({is_bizhawk = true})

    env.route_manager.autowalk_to_current()
    env.auto_step.on_route_cancelled({reason = "test_cancel"})

    assert_equal(
        env.request_refresh_calls(),
        0,
        "BizHawk route cancellation should avoid the slow object refresh by default"
    )

    env.restore()
end

function tests.bizhawk_autowalk_skips_npc_freeze_by_default()
    local env = make_env({is_bizhawk = true})

    env.route_manager.autowalk_to_current()

    assert_equal(
        env.route_manager.is_npc_freeze_active(),
        false,
        "BizHawk autowalk should avoid per-frame NPC RAM freeze by default"
    )

    env.restore()
end

function tests.bizhawk_autowalk_freeze_can_be_opted_in()
    local env = make_env({
        is_bizhawk = true,
        config_values = {
            bizhawk_autowalk_freeze_npcs = "true",
        },
    })

    env.route_manager.autowalk_to_current()

    assert_equal(
        env.route_manager.is_npc_freeze_active(),
        true,
        "BizHawk autowalk freeze option should preserve the old NPC freeze behavior when requested"
    )

    env.restore()
end

function tests.autowalk_completion_speaks_arrival()
    local env = make_env({path_length = 3})

    env.route_manager.autowalk_to_current()
    env.auto_step.on_route_complete()

    local output = table.concat(env.outputs, "\n")
    assert_contains(output, "Auto-walk complete. Arrived at Chest after 3 steps", "route completion should announce arrival")

    env.restore()
end

function tests.autowalk_speaks_progress_on_long_routes()
    local env = make_env({path_length = 8})

    env.route_manager.autowalk_to_current()
    for i = 1, 6 do
        env.auto_step.on_step_complete(5, 5 - i, "up", 5, 4 - i, {
            queued_route = true,
            source = "test",
        })
    end

    assert_contains(
        table.concat(env.outputs, "\n"),
        "Auto-walk 6 of 8 steps",
        "long queued routes should speak progress at the configured interval")

    env.restore()
end

function tests.autowalk_to_npc_holds_target_after_arrival()
    local env = make_env({
        is_bizhawk = true,
        current_object = {name = "Person", type = "npc", id = "npc_2", x = 6, y = 1},
        config_values = {
            auto_walk_npc_hold_frames = "2",
        },
    })

    env.route_manager.autowalk_to_current()
    env.auto_step.on_route_complete()
    env.route_manager.apply_npc_freeze()

    local output = table.concat(env.outputs, "\n")
    assert_contains(output, "Target held briefly. Use TALK now", "NPC arrival should prompt the player to talk")
    assert_equal(env.memory_writes[1].address, 6, "NPC hold should write the target slot byte 0")
    assert_equal(env.memory_writes[2].address, 7, "NPC hold should write the target slot byte 1")
    assert_equal(env.memory_writes[3].address, 8, "NPC hold should write the target slot byte 2")

    env.restore()
end

function tests.autowalk_to_moving_npc_holds_planned_target_tile()
    local env = make_env({
        is_bizhawk = true,
        current_object = {name = "Guard 1", type = "npc", id = "npc_0", x = 7, y = 5},
        config_values = {
            auto_walk_npc_hold_frames = "2",
            auto_walk_face_target_frames = "2",
        },
        memory_values = {
            [0] = 0x80 + 4,
            [1] = 0x60 + 4,
            [2] = 0x12,
        },
    })

    env.route_manager.autowalk_to_current()
    env.auto_step.on_route_complete()

    assert_equal(env.memory_writes[1].address, 0, "moving NPC hold should write slot byte 0 immediately")
    assert_equal(env.memory_writes[1].value, 0x80 + 7, "moving NPC hold should pin target X while preserving sprite bits")
    assert_equal(env.memory_writes[2].address, 1, "moving NPC hold should write slot byte 1 immediately")
    assert_equal(env.memory_writes[2].value, 0x60 + 5, "moving NPC hold should pin target Y while preserving facing bits")
    assert_equal(env.memory_writes[3].address, 2, "moving NPC hold should preserve movement byte")
    assert_equal(env.memory_writes[3].value, 0x12, "moving NPC hold should preserve movement byte value")

    env.route_manager.apply_npc_freeze()

    assert_equal(env.memory_writes[4].value, 0x80 + 7, "per-frame NPC hold should keep target X pinned")
    assert_equal(env.memory_writes[5].value, 0x60 + 5, "per-frame NPC hold should keep target Y pinned")
    assert_equal(env.memory_writes[6].value, 0x12, "per-frame NPC hold should keep movement byte pinned")
    assert_equal(env.joypad_sets[#env.joypad_sets].buttons.up, true, "arrival should still face the held NPC")
    assert_equal(env.suppress_direction_tracking_calls(), 1, "NPC facing tap should suppress auto-step edge tracking")
    assert_equal(env.last_suppress_direction_tracking_frames(), 8, "suppression should cover face hold, release, and cleanup frames")

    env.restore()
end

function tests.autowalk_to_npc_faces_target_after_arrival()
    local env = make_env({
        is_bizhawk = true,
        current_object = {name = "King", type = "npc", id = "npc_10", x = 5, y = 3},
        config_values = {
            auto_walk_npc_hold_frames = "0",
            auto_walk_face_target_frames = "2",
        },
    })

    env.route_manager.autowalk_to_current()
    env.auto_step.on_route_complete()
    assert_equal(#env.joypad_sets, 0, "facing input should wait for the post-frame hook")
    assert_equal(env.suppress_direction_tracking_calls(), 1, "facing tap should suppress auto-step edge tracking")

    env.route_manager.apply_npc_freeze()
    assert_equal(env.joypad_sets[#env.joypad_sets].buttons.up, true, "arrival should press toward the NPC")
    env.route_manager.apply_npc_freeze()
    assert_equal(env.joypad_sets[#env.joypad_sets].buttons.up, true, "face input should hold for configured frames")
    env.route_manager.apply_npc_freeze()
    assert_equal(env.joypad_sets[#env.joypad_sets].buttons.up, false, "face input should release after the hold")

    env.restore()
end

function tests.autowalk_already_adjacent_faces_target()
    local env = make_env({
        pathfind_mode = "already_adjacent",
        current_object = {name = "King", type = "npc", id = "npc_10", x = 5, y = 3},
        config_values = {
            auto_walk_npc_hold_frames = "0",
            auto_walk_face_target_frames = "1",
        },
    })

    env.route_manager.autowalk_to_current()
    env.route_manager.apply_npc_freeze()

    assert_equal(env.joypad_sets[#env.joypad_sets].buttons.up, true, "already-adjacent auto-walk should face the target")
    assert_equal(env.suppress_direction_tracking_calls(), 1, "already-adjacent facing tap should suppress auto-step edge tracking")

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

function tests.autowalk_no_path_mentions_closed_door_hint()
    local env = make_env({
        pathfind_mode = "always_no_path",
        current_object = {name = "Stairs Down", type = "stair", x = 8, y = 8},
        closed_door_cells = {
            ["5,3"] = true,
        },
    })

    env.route_manager.autowalk_to_current()

    local output = table.concat(env.outputs, "\n")
    assert_contains(output, "No path found", "closed-door no-path should still report no path")
    assert_contains(output, "Route is blocked by a closed door", "closed-door no-path should include a recovery hint")
    assert_contains(output, "Get a magic key from a chest", "zero-key closed-door hint should point to the chest/key step")

    env.restore()
end

function tests.autowalk_no_path_mentions_npc_clutter_when_npc_free_route_exists()
    local env = make_env({
        pathfind_mode = "block_sensitive",
        pathfind_block_key = "5,3",
        blocking_positions = {
            {x = 5, y = 3},
        },
    })

    env.route_manager.autowalk_to_current()

    assert_contains(
        table.concat(env.outputs, "\n"),
        "Route is currently blocked by NPC movement",
        "no-path output should explain when NPC clutter is the likely route blocker"
    )

    env.restore()
end

function tests.autowalk_npc_clutter_hint_takes_precedence_over_nearby_closed_door()
    local env = make_env({
        pathfind_mode = "block_sensitive",
        pathfind_block_key = "5,3",
        blocking_positions = {
            {x = 5, y = 3},
        },
        closed_door_cells = {
            ["6,4"] = true,
        },
    })

    env.route_manager.autowalk_to_current()

    local output = table.concat(env.outputs, "\n")
    assert_contains(
        output,
        "Route is currently blocked by NPC movement",
        "npc-free route evidence should beat a generic closed-door frontier"
    )
    assert_not_contains(
        output,
        "Route is blocked by a closed door",
        "closed-door hint should not override a live NPC clutter explanation"
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
