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
    local published_events = {}
    local start_route_calls = 0
    local last_start_route_steps = nil
    local last_start_route_opts = nil
    local overworld_plan_calls = 0
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
    local current_map_id = options.start_map_id or 0x05
    local current_x = options.start_x or 5
    local current_y = options.start_y or 4
    local pathability_filter = 1
    local pathability_statuses = {}
    local pathability_status_updates = 0
    local module_names = {
        "addresses",
        "auto_step",
        "config",
        "debug_tools",
        "event_bus",
        "game_snapshot",
        "map_reader",
        "maps",
        "navigation",
        "objects",
        "overworld_routes",
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
                return current_map_id, current_x, current_y
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
                pathability_status_updates = pathability_status_updates + 1
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
            pathfind_to = function(_, start_x, start_y, goal_x, goal_y, blocking, opts)
                pathfind_calls = pathfind_calls + 1
                reroute_calls = reroute_calls + 1
                last_direct_call = {
                    start_x = start_x,
                    start_y = start_y,
                    goal_x = goal_x,
                    goal_y = goal_y,
                    blocking = blocking,
                    opts = opts,
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
                if options.already_adjacent_after_first and reroute_calls > 1 then
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
            start_route = function(steps, opts)
                start_route_calls = start_route_calls + 1
                last_start_route_steps = steps
                last_start_route_opts = opts
                return options.start_route_result ~= false
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

    local overworld_plan_opts_log = {}
    local overworld_start_calls = {}
    package.preload["overworld_routes"] = function()
        return {
            plan_next_segment = function(map_id, x, y, plan_opts)
                overworld_plan_calls = overworld_plan_calls + 1
                overworld_plan_opts_log[#overworld_plan_opts_log + 1] = plan_opts or false
                if options.overworld_segment_error then
                    return nil, options.overworld_segment_error
                end
                return options.overworld_segment
            end,
            route_id_for_object = function(obj)
                if options.overworld_route_for_object_fn then
                    return options.overworld_route_for_object_fn(obj)
                end
                return options.overworld_route_for_object
            end,
            active_route_id = function()
                return options.overworld_active_route_id
            end,
            start = function(route_id, map_id, x, y)
                overworld_start_calls[#overworld_start_calls + 1] = {
                    route_id = route_id, map_id = map_id, x = x, y = y,
                }
                if options.overworld_start_error then
                    return nil, options.overworld_start_error
                end
                return options.overworld_start_result or {message = "started"}
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

    package.preload["event_bus"] = function()
        return {
            publish = function(name, payload)
                published_events[#published_events + 1] = {name = name, payload = payload}
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
            terrain_offset = options.snapshot_terrain or 0x10,
        }
    end

    local route_manager = require "route_manager"

    return {
        outputs = outputs,
        published_events = function() return published_events end,
        auto_step = package.loaded["auto_step"],
        route_manager = route_manager,
        pathfind_calls = function() return pathfind_calls end,
        update_npcs_calls = function() return update_npcs_calls end,
        request_refresh_calls = function() return request_refresh_calls end,
        pathability_statuses = function() return pathability_statuses end,
        pathability_status_updates = function() return pathability_status_updates end,
        pathability_filter = function() return pathability_filter end,
        start_route_calls = function() return start_route_calls end,
        last_start_route_steps = function() return last_start_route_steps end,
        last_start_route_opts = function() return last_start_route_opts end,
        overworld_plan_calls = function() return overworld_plan_calls end,
        overworld_plan_opts_log = function() return overworld_plan_opts_log end,
        overworld_start_calls = function() return overworld_start_calls end,
        inject_step_calls = function() return inject_step_calls end,
        last_injected_dir = function() return last_injected_dir end,
        suppress_direction_tracking_calls = function() return suppress_direction_tracking_calls end,
        last_suppress_direction_tracking_frames = function() return last_suppress_direction_tracking_frames end,
        last_direct_call = function() return last_direct_call end,
        last_adjacent_call = function() return last_adjacent_call end,
        seam_summary = function(map_id) return route_manager.get_seam_summary(map_id) end,
        seam_entries = function(map_id) return route_manager.get_seam_entries(map_id) end,
        memory_values = memory_values,
        memory_writes = memory_writes,
        set_position = function(map_id, x, y)
            current_map_id = map_id
            current_x = x
            current_y = y
        end,
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

function tests.overworld_autowalk_queues_active_waypoint_segment()
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 19,
        start_y = 7,
        current_object = {id = "route_garinham_14", name = "Route next: Garinham east ridge", type = "exit", x = 16, y = 6},
        overworld_segment = {
            route = {id = "garinham", title = "Garinham"},
            waypoint = {name = "Garinham east ridge", x = 16, y = 6},
            index = 14,
            steps = {"up", "left", "left", "left"},
            message = "Auto-walk to Garinham east ridge, 1 north, 3 west. 4 step(s).",
            object_id = "route_garinham_14",
        },
    })

    local plan = env.route_manager.autowalk_to_current()

    assert_equal(plan.status, "queued", "overworld auto-walk should queue the segment")
    assert_equal(env.overworld_plan_calls(), 1, "overworld segment planner should be used")
    assert_equal(env.pathfind_calls(), 0, "overworld auto-walk should not call interior pathfinding")
    assert_equal(env.start_route_calls(), 1, "overworld segment should queue auto_step")
    assert_equal(env.last_start_route_steps()[1], "up", "queued segment should preserve planned steps")
    assert_equal(env.last_start_route_opts().settle_frames, 0, "overworld segment should use no interior settle delay")
    assert_contains(env.outputs[#env.outputs], "Overworld auto-walk", "overworld auto-walk should be announced")

    env.restore()
end

function tests.overworld_blocked_segment_stops_without_reroute()
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 19,
        start_y = 7,
        current_object = {id = "route_garinham_14", name = "Route next: Garinham east ridge", type = "exit", x = 16, y = 6},
        overworld_segment = {
            route = {id = "garinham", title = "Garinham"},
            waypoint = {name = "Garinham east ridge", x = 16, y = 6},
            index = 14,
            steps = {"up", "left", "left", "left"},
            message = "Auto-walk to Garinham east ridge, 1 north, 3 west. 4 step(s).",
            object_id = "route_garinham_14",
        },
    })

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(19, 7, "up", {queued_route = true})

    local events = env.published_events()
    assert_equal(env.pathfind_calls(), 0, "blocked overworld segment should not reroute through interior A*")
    assert_equal(env.start_route_calls(), 1, "blocked overworld segment should not queue a reroute")
    assert_equal(events[#events].payload.reason, "overworld_blocked", "blocked overworld segment should publish a stop reason")
    assert_contains(env.outputs[#env.outputs], "Overworld auto-walk stopped", "blocked segment should tell the player it stopped")

    env.restore()
end

function tests.overworld_battle_cancel_clears_without_speech_spam()
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 19,
        start_y = 7,
        current_object = {id = "route_garinham_14", name = "Route next: Garinham east ridge", type = "exit", x = 16, y = 6},
        overworld_segment = {
            route = {id = "garinham", title = "Garinham"},
            waypoint = {name = "Garinham east ridge", x = 16, y = 6},
            index = 14,
            steps = {"up", "left", "left", "left"},
            message = "Auto-walk to Garinham east ridge, 1 north, 3 west. 4 step(s).",
            object_id = "route_garinham_14",
        },
    })

    env.route_manager.autowalk_to_current()
    local outputs_before_cancel = #env.outputs
    env.auto_step.on_route_cancelled({reason = "can_walk_false", current_x = 19, current_y = 7})

    assert_equal(env.pathfind_calls(), 0, "battle/menu cancel should not reroute an overworld segment")
    assert_equal(#env.outputs, outputs_before_cancel, "can_walk_false cancel should leave battle/menu speech in charge")

    env.restore()
end

function tests.overworld_autowalk_forwards_advance_opt_to_planner()
    -- autowalk_overworld_segment must pass advance_if_at_waypoint=true so
    -- the planner advances past a waypoint the player is already standing on.
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 16,
        start_y = 6,
        current_object = {id = "route_garinham_14", name = "Route next: Garinham east ridge", type = "exit", x = 16, y = 6},
        overworld_segment = {
            route = {id = "garinham", title = "Garinham"},
            waypoint = {name = "Garinham east ridge", x = 16, y = 6},
            index = 14,
            steps = {"up"},
            message = "Auto-walk to Garinham east ridge.",
            object_id = "route_garinham_14",
        },
    })

    env.route_manager.autowalk_to_current()

    local opts_log = env.overworld_plan_opts_log()
    assert_equal(#opts_log, 1, "overworld planner should be invoked once")
    assert_equal(opts_log[1].advance_if_at_waypoint, true, "autowalk should opt into already-at-waypoint advance")

    env.restore()
end

function tests.overworld_autowalk_to_object_switches_routes_when_destination_differs()
    -- Selecting an object whose route differs from the active route should
    -- start the new route before queuing a segment, so the player doesn't
    -- silently advance the wrong destination.
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 48,
        start_y = 41,
        overworld_active_route_id = "brecconary",
        overworld_route_for_object = "garinham",
        overworld_start_result = {message = "Route to Garinham started"},
        overworld_segment = {
            route = {id = "garinham", title = "Garinham"},
            waypoint = {name = "Garinham south lane", x = 5, y = 4},
            index = 1,
            steps = {"up"},
            message = "Auto-walk to Garinham south lane.",
            object_id = "route_garinham_01",
        },
    })

    local garinham_obj = {id = "overworld_garinham", name = "Garinham", x = 2, y = 2}
    env.route_manager.autowalk_to_object(garinham_obj, {speak = true})

    local starts = env.overworld_start_calls()
    assert_equal(#starts, 1, "differing destination should trigger route switch")
    assert_equal(starts[1].route_id, "garinham", "switch should target the new route")
    assert_equal(env.overworld_plan_calls(), 1, "segment planner should still queue after the switch")
    assert_equal(env.pathfind_calls(), 0, "overworld route switch must not fall through to interior pathfinding")

    env.restore()
end

function tests.overworld_autowalk_to_object_skips_switch_when_same_destination()
    -- When the selected object's route matches the active route, no switch
    -- is needed — autowalk should just advance the active route's segment.
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 48,
        start_y = 41,
        overworld_active_route_id = "garinham",
        overworld_route_for_object = "garinham",
        overworld_segment = {
            route = {id = "garinham", title = "Garinham"},
            waypoint = {name = "Garinham south lane", x = 5, y = 4},
            index = 1,
            steps = {"up"},
            message = "Auto-walk to Garinham south lane.",
            object_id = "route_garinham_01",
        },
    })

    local garinham_obj = {id = "overworld_garinham", name = "Garinham", x = 2, y = 2}
    env.route_manager.autowalk_to_object(garinham_obj, {speak = true})

    assert_equal(#env.overworld_start_calls(), 0, "same destination should not call start")
    assert_equal(env.overworld_plan_calls(), 1, "same-destination autowalk should still plan")

    env.restore()
end

function tests.overworld_autowalk_to_object_reports_start_error_without_planning()
    -- If the route switch itself errors, autowalk_to_object must surface the
    -- failure and not call the segment planner.
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 48,
        start_y = 41,
        overworld_active_route_id = "brecconary",
        overworld_route_for_object = "garinham",
        overworld_start_error = "Unknown overworld route",
    })

    local garinham_obj = {id = "overworld_garinham", name = "Garinham", x = 2, y = 2}
    local result = env.route_manager.autowalk_to_object(garinham_obj, {speak = true})

    assert_equal(result.status, "route_start_failed", "failed switch should surface a status")
    assert_equal(result.ok, false, "failed switch should not report ok")
    assert_equal(env.overworld_plan_calls(), 0, "failed switch should not invoke the planner")
    assert_contains(env.outputs[#env.outputs], "Unknown overworld route", "failed switch should be spoken")

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

function tests.repeated_route_blocked_steps_stay_soft_until_verified()
    local env = make_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "up")
    env.auto_step.on_blocked(5, 4, "up")
    env.auto_step.on_blocked(5, 4, "up")

    assert_equal(
        env.route_manager.count_runtime_blocks(0x05),
        0,
        "repeated queued route blocks should not promote into hard runtime map blockers"
    )
    assert_equal(
        env.route_manager.build_path_blocking(0x05)["5,3"],
        nil,
        "normal path blocking should not include unverified route-only seam memory"
    )
    assert_equal(
        env.route_manager.build_path_blocking(0x05, {include_unconfirmed_seams = true})["5,3"],
        nil,
        "unconfirmed seam memory should stay diagnostic even when callers request it"
    )

    env.restore()
end

function tests.manual_edge_command_can_promote_and_clear_runtime_block()
    local env = make_env()

    env.route_manager.inject_runtime_block_for_step(0x05, 5, 4, "up", "manual_edge")

    assert_equal(
        env.route_manager.count_runtime_blocks(0x05),
        1,
        "manual edge confirmation should be allowed to create a runtime block"
    )
    assert_equal(
        env.route_manager.build_path_blocking(0x05)["5,3"].south,
        true,
        "manual edge runtime block should appear in normal path blocking"
    )

    env.route_manager.clear_runtime_block_for_step(0x05, 5, 4, "up", "verified_passable")

    assert_equal(
        env.route_manager.count_runtime_blocks(0x05),
        0,
        "confirmed passable verification should clear the matching runtime block"
    )

    env.restore()
end

function tests.reroute_temporary_block_does_not_mutate_manual_runtime_dirs()
    local env = make_env()

    env.route_manager.inject_runtime_block_for_step(0x05, 5, 4, "up", "manual_edge")
    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(6, 3, "left")

    local entries = env.route_manager.get_runtime_block_entries(0x05)
    assert_equal(#entries, 1, "route-only reroute should not create another hard runtime block")
    assert_equal(entries[1].key, "5,3", "manual runtime block should remain on the original cell")
    assert_equal(entries[1].dirs.south, true, "manual approach should remain recorded")
    assert_equal(entries[1].dirs.east, nil, "temporary route-only approach should stay out of runtime blocks")

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

function tests.repeated_verified_probe_blocks_do_not_promote_runtime_block()
    local env = make_env()

    env.route_manager.record_seam_result_for_step(0x05, 5, 4, "up", "blocked", "verified_probe")
    env.route_manager.record_seam_result_for_step(0x05, 5, 4, "up", "blocked", "verified_probe")
    env.route_manager.record_seam_result_for_step(0x05, 5, 4, "up", "blocked", "verified_probe")

    assert_equal(
        env.route_manager.count_runtime_blocks(0x05),
        0,
        "verified probe observations should stay diagnostic until a human promotes the edge"
    )
    assert_equal(
        env.seam_summary(0x05).blocked_only,
        1,
        "verified probe blocks should still be visible in seam observations"
    )

    env.restore()
end

function tests.verified_probe_move_marks_prior_manual_blocks_noisy()
    local env = make_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "up", {queued_route = false})
    env.route_manager.record_seam_result_for_step(0x05, 5, 4, "up", "moved", "verified_probe_move")

    assert_equal(
        env.seam_summary(0x05).noisy,
        1,
        "a successful verifier move should make previous manual block evidence noisy"
    )
    assert_equal(
        env.route_manager.build_path_blocking(0x05, {include_unconfirmed_seams = true})["5,3"],
        nil,
        "mixed verifier evidence should not become a soft reroute block"
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

function tests.successful_traversal_marks_repeated_route_blocks_noisy()
    -- Repeated route-only blocks are diagnostic seam memory, not hard map data.
    -- A later successful traversal makes the seam noisy so it will not be used
    -- as a soft reroute block until a stronger verifier confirms it.
    local env = make_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "up")
    env.auto_step.on_blocked(5, 4, "up")
    env.auto_step.on_blocked(5, 4, "up")
    env.auto_step.on_step_complete(5, 4, "up", 5, 3, {queued_route = false, source = "test"})

    assert_equal(
        env.route_manager.count_runtime_blocks(0x05),
        0,
        "route-only seam observations should not create a confirmed runtime block"
    )
    assert_equal(
        env.seam_summary(0x05).confirmed_blocked,
        0,
        "route-only seam should not be classified confirmed without verifier evidence"
    )
    assert_equal(
        env.seam_summary(0x05).noisy,
        1,
        "mixed route/probe evidence should classify the seam as noisy"
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

function tests.runtime_directional_block_does_not_block_chest_target_walkability()
    local env = make_env()
    env.route_manager.inject_runtime_block_for_step(0x05, 7, 1, "left", "directional_test")

    local plan = env.route_manager.plan_path_to_object({
        name = "Blocked Directional Chest",
        type = "chest",
        x = 6,
        y = 1,
    })

    assert_equal(
        plan.path_mode,
        "direct",
        "partial directional runtime block should still allow direct chest routing"
    )
    assert_equal(
        env.route_manager.is_pathfinding_walkable(0x05, 6, 1),
        true,
        "runtime blocks with open approaches should remain pathfinding-walkable"
    )
    assert_equal(env.last_direct_call().goal_x, 6, "direct call should still target the chest X")
    assert_equal(env.last_direct_call().goal_y, 1, "direct call should still target the chest Y")
    assert_equal(env.last_adjacent_call(), nil, "one-way runtime block should not force adjacent fallback")

    env.route_manager.inject_runtime_block(0x05, 6, 1)
    assert_equal(
        env.route_manager.is_pathfinding_walkable(0x05, 6, 1),
        false,
        "fully blocked runtime cell should remain non-walkable"
    )

    local plan_after_full_block = env.route_manager.plan_path_to_object({
        name = "Now Fully Blocked Chest",
        type = "chest",
        x = 6,
        y = 1,
    })
    assert_equal(
        plan_after_full_block.path_mode,
        "adjacent",
        "fully blocked runtime cell should fall back to adjacent planning"
    )

    env.restore()
end

function tests.service_interaction_goal_routes_to_counter_tile_and_faces_service()
    local merchant = {
        name = "Merchant 2",
        type = "npc",
        id = "npc_1",
        x = 5,
        y = 4,
        interaction_x = 5,
        interaction_y = 6,
        interaction_face_dir = "north",
    }
    local env = make_env({
        start_map_id = 0x08,
        start_x = 8,
        start_y = 5,
        current_object = merchant,
        config_values = {
            auto_walk_npc_hold_frames = "0",
            auto_walk_face_target_frames = "1",
        },
    })

    local plan = env.route_manager.plan_path_to_object(merchant)
    local direct = env.last_direct_call()
    assert_equal(plan.path_mode, "direct", "counter services should route directly to the interaction square")
    assert_equal(plan.goal_x, 5, "counter service plan should target the doorway X")
    assert_equal(plan.goal_y, 6, "counter service plan should target the doorway Y")
    assert_equal(plan.face_dir, "north", "counter service plan should face toward the merchant after arrival")
    assert_equal(direct.goal_x, 5, "direct pathfinder call should use the interaction X")
    assert_equal(direct.goal_y, 6, "direct pathfinder call should use the interaction Y")

    env.route_manager.autowalk_to_current()
    env.auto_step.on_route_complete()
    env.route_manager.apply_npc_freeze()
    assert_equal(env.joypad_sets[#env.joypad_sets].buttons.up, true, "direct service arrival should face the merchant")

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

function tests.direct_route_planning_passes_debug_pathfinder_options()
    local env = make_env({
        current_object = {name = "Chest", type = "chest", x = 6, y = 1},
    })
    local marker_opts = {on_visit = function() end}

    env.route_manager.plan_path_to_object({
        name = "Chest",
        type = "chest",
        x = 6,
        y = 1,
    }, {
        path_mode = "direct",
        pathfinder_opts = marker_opts,
    })

    assert_equal(
        env.last_direct_call().opts.on_visit,
        marker_opts.on_visit,
        "direct route-manager plans should pass debug pathfinder callbacks through to A*"
    )

    env.restore()
end

function tests.coordinate_debug_planning_uses_route_manager_path_policy()
    local env = make_env()
    local marker_opts = {on_complete = function() end}

    local plan = env.route_manager.plan_path_to_coordinates(6, 1, {
        path_mode = "direct",
        pathfinder_opts = marker_opts,
        store_debug_path = false,
    })

    assert_equal(plan.coordinate_target, true, "coordinate plans should be marked for debug callers")
    assert_equal(plan.path_mode, "direct", "coordinate direct debug plans should keep direct path mode")
    assert_equal(env.last_direct_call().opts.on_complete, marker_opts.on_complete, "coordinate debug plans should use the shared route-manager A* options")

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
    assert_equal(env.pathfind_calls(), 0, "batch pathability should use one flood-fill instead of per-object A*")

    local calls_after_first_pass = env.pathfind_calls()
    env.route_manager.refresh_object_pathability_filter_if_needed()
    assert_equal(env.pathfind_calls(), calls_after_first_pass, "unchanged pathability context should reuse the cached result")

    env.restore()
end

function tests.object_pathability_filter_recomputes_when_position_changes()
    local env = make_env({
        object_list = {
            {id = "chest_1", name = "Chest", type = "chest", x = 6, y = 1},
        },
    })

    env.route_manager.set_object_pathability_filter("reachable")
    local updates_after_first_pass = env.pathability_status_updates()

    env.set_position(0x05, 6, 4)
    local info = env.route_manager.refresh_object_pathability_filter_if_needed()

    assert_equal(info.refreshed, true, "changed player position should refresh pathability")
    assert_equal(
        env.pathability_status_updates() > updates_after_first_pass,
        true,
        "changed player position must not reuse stale reachability data"
    )

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

function tests.suspect_route_timeout_bruteforces_before_silent_reroute()
    local env = make_env({pathfind_mode = "always_path"})

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "up", {
        queued_route = true,
        movement_started = true,
        movement_start_frame = 5,
        timeout_retries = 1,
        turn_represses = 1,
    })

    assert_equal(
        env.inject_step_calls(),
        1,
        "a movement-start route timeout should directly retry the same seam before accepting an alternate reroute"
    )
    assert_equal(
        env.start_route_calls(),
        1,
        "the suspicious timeout should not silently queue an alternate route first"
    )
    assert_not_contains(
        table.concat(env.outputs, "\n"),
        "Re-routing.",
        "the suspicious timeout should not be announced as a normal reroute before direct retry"
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

function tests.successful_seam_bruteforce_at_destination_publishes_route_complete()
    local target = {id = "exit_1", name = "Exit", type = "exit", x = 5, y = 2}
    local env = make_env({
        current_object = target,
        object_list = {target},
        non_walkable_cells = {["5,2"] = true},
        already_adjacent_after_first = true,
    })

    env.route_manager.autowalk_to_object(target, {survey_safe = true, speak = false})
    env.auto_step.on_blocked(5, 4, "up", {
        queued_route = true,
        movement_started = true,
        movement_start_frame = 5,
    })
    env.auto_step.on_step_complete(5, 4, "up", 5, 3, {queued_route = false, source = "test"})

    local saw_route_complete = false
    for _, event in ipairs(env.published_events()) do
        if event.name == "route_completed" then
            saw_route_complete = true
            break
        end
    end

    assert_equal(
        env.start_route_calls(),
        1,
        "seam brute force that reaches the goal should not queue an empty follow-up route"
    )
    assert_equal(
        saw_route_complete,
        true,
        "seam brute force that reaches the goal should publish route_completed for survey listeners"
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
        0,
        "failed seam brute-force retries should remain soft evidence until repeated verification"
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

function tests.autowalk_reroutes_from_route_drift_tile()
    local env = make_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_route_cancelled({
        reason = "route_drift_off_path",
        current_x = 8,
        current_y = 16,
        source = "route_settle_catchup",
    })

    assert_equal(
        env.start_route_calls(),
        2,
        "route drift should queue a fresh route from the drifted position"
    )
    assert_equal(
        env.last_direct_call().start_x,
        8,
        "route drift reroute should plan from the current drifted x"
    )
    assert_equal(
        env.last_direct_call().start_y,
        16,
        "route drift reroute should plan from the current drifted y"
    )
    assert_contains(
        table.concat(env.outputs, "\n"),
        "Re-routing after drift",
        "route drift recovery should announce that it is re-routing"
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

function tests.autowalk_parks_mobile_non_target_npcs_when_enabled()
    local env = make_env({
        is_bizhawk = true,
        current_object = {id = "npc_2", name = "Merchant", type = "npc", x = 6, y = 1},
        config_values = {
            auto_walk_park_mobile_npcs = "true",
            auto_walk_npc_hold_frames = "0",
        },
        memory_values = {
            [0] = 0x80 + 4,  [1] = 0x60 + 4,  [2] = 0x12, -- mobile non-target
            [3] = 0x80 + 5,  [4] = 0x60 + 5,  [5] = 0x00, -- stationary
            [6] = 0x80 + 6,  [7] = 0x60 + 1,  [8] = 0x12, -- selected target
        },
    })

    env.route_manager.autowalk_to_current()

    assert_equal(env.route_manager.is_npc_freeze_active(), false, "mobile parking should use targeted parking instead of full freeze")
    assert_equal(env.route_manager.is_autowalk_npc_parking_active(), true, "autowalk parking should stay active while route is queued")
    assert_equal(env.memory_writes[1].address, 0, "parking should write the mobile non-target slot X")
    assert_equal(env.memory_writes[1].value, 0x80 + 31, "parking should move mobile NPC X to sentinel coordinate")
    assert_equal(env.memory_writes[2].address, 1, "parking should write the mobile non-target slot Y")
    assert_equal(env.memory_writes[2].value, 0x60 + 31, "parking should move mobile NPC Y to sentinel coordinate")
    assert_equal(#env.memory_writes, 2, "parking should not write stationary or selected target NPC slots")

    env.auto_step.on_route_complete()

    assert_equal(env.route_manager.is_autowalk_npc_parking_active(), false, "route completion should release mobile NPC parking")
    assert_equal(env.memory_writes[3].address, 0, "restore should write the original mobile NPC X")
    assert_equal(env.memory_writes[3].value, 0x80 + 4, "restore should put the mobile NPC X back")
    assert_equal(env.memory_writes[4].address, 1, "restore should write the original mobile NPC Y")
    assert_equal(env.memory_writes[4].value, 0x60 + 4, "restore should put the mobile NPC Y back")

    env.restore()
end

function tests.autowalk_parking_defers_restore_when_player_occupies_original_npc_tile()
    local env = make_env({
        is_bizhawk = true,
        config_values = {
            auto_walk_park_mobile_npcs = "true",
        },
        memory_values = {
            [0] = 0x80 + 5,
            [1] = 0x60 + 3,
            [2] = 0x12,
        },
    })

    env.route_manager.autowalk_to_current()
    env.set_position(0x05, 5, 3)
    env.auto_step.on_route_complete()

    assert_equal(env.route_manager.is_autowalk_npc_parking_active(), true, "restore should defer while player occupies the NPC's original tile")
    assert_equal(#env.memory_writes, 2, "deferred restore should leave the NPC parked")

    env.set_position(0x05, 5, 2)
    env.route_manager.apply_npc_freeze()

    assert_equal(env.route_manager.is_autowalk_npc_parking_active(), false, "deferred restore should finish once the player leaves the original NPC tile")
    assert_equal(env.memory_writes[3].value, 0x80 + 5, "deferred restore should put the NPC X back")
    assert_equal(env.memory_writes[4].value, 0x60 + 3, "deferred restore should put the NPC Y back")

    env.restore()
end

function tests.autowalk_parking_does_not_overwrite_pending_deferred_restore()
    local env = make_env({
        is_bizhawk = true,
        config_values = {
            auto_walk_park_mobile_npcs = "true",
        },
        memory_values = {
            [0] = 0x80 + 5,
            [1] = 0x60 + 3,
            [2] = 0x12,
        },
    })

    env.route_manager.autowalk_to_current()
    env.set_position(0x05, 5, 3)
    env.auto_step.on_route_complete()
    env.memory_values[3] = 0x80 + 7
    env.memory_values[4] = 0x60 + 4
    env.memory_values[5] = 0x12
    env.route_manager.autowalk_to_current()

    assert_equal(env.route_manager.is_autowalk_npc_parking_active(), true, "new autowalk should leave the deferred restore owned by the original parking state")
    assert_equal(#env.memory_writes, 2, "new autowalk should not park a new slot while a deferred restore is pending")

    env.set_position(0x05, 5, 2)
    env.route_manager.apply_npc_freeze()

    assert_equal(env.route_manager.is_autowalk_npc_parking_active(), false, "pending restore should still complete after the player moves")
    assert_equal(env.memory_writes[3].value, 0x80 + 5, "pending restore should preserve the original NPC X")
    assert_equal(env.memory_writes[4].value, 0x60 + 3, "pending restore should preserve the original NPC Y")

    env.restore()
end

function tests.autowalk_parking_restores_on_immediate_no_path()
    local env = make_env({
        is_bizhawk = true,
        pathfind_mode = "always_no_path",
        config_values = {
            auto_walk_park_mobile_npcs = "true",
        },
        memory_values = {
            [0] = 0x80 + 4,
            [1] = 0x60 + 4,
            [2] = 0x12,
        },
    })

    env.route_manager.autowalk_to_current()

    assert_equal(env.route_manager.is_autowalk_npc_parking_active(), false, "immediate no-path should restore parked NPCs")
    assert_equal(env.memory_writes[1].value, 0x80 + 31, "no-path setup should park the mobile NPC")
    assert_equal(env.memory_writes[2].value, 0x60 + 31, "no-path setup should park the mobile NPC")
    assert_equal(env.memory_writes[3].value, 0x80 + 4, "no-path cleanup should restore the mobile NPC X")
    assert_equal(env.memory_writes[4].value, 0x60 + 4, "no-path cleanup should restore the mobile NPC Y")

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
    assert_equal(#env.memory_writes, 2, "NPC hold should skip unchanged movement byte writes")

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
    assert_equal(#env.memory_writes, 2, "moving NPC hold should skip unchanged movement byte writes")

    env.memory_values[0] = 0x80 + 4
    env.memory_values[1] = 0x60 + 4
    env.memory_values[2] = 0x13
    env.route_manager.apply_npc_freeze()

    assert_equal(env.memory_writes[3].value, 0x80 + 7, "per-frame NPC hold should keep target X pinned")
    assert_equal(env.memory_writes[4].value, 0x60 + 5, "per-frame NPC hold should keep target Y pinned")
    assert_equal(env.memory_writes[5].value, 0x12, "per-frame NPC hold should keep movement byte pinned")
    assert_equal(env.joypad_sets[#env.joypad_sets].buttons.up, true, "arrival should still face the held NPC")
    assert_equal(env.suppress_direction_tracking_calls(), 1, "NPC facing tap should suppress auto-step edge tracking")
    assert_equal(env.last_suppress_direction_tracking_frames(), 8, "suppression should cover face hold, release, and cleanup frames")

    env.restore()
end

function tests.selected_teleport_can_hold_target_npc_without_autowalk()
    local env = make_env({
        is_bizhawk = true,
        config_values = {
            auto_walk_npc_hold_frames = "0",
        },
        memory_values = {
            [6] = 0x80 + 4,
            [7] = 0x40 + 4,
            [8] = 0x22,
        },
    })

    local ok = env.route_manager.hold_target_npc({
        name = "Woman 2",
        type = "npc",
        id = "npc_2",
        x = 10,
        y = 13,
    }, "selected teleport", 3)

    assert_equal(ok, true, "selected teleport should be able to pin a target NPC without starting auto-walk")
    assert_equal(env.memory_writes[1].address, 6, "selected-teleport hold should write the target slot byte 0")
    assert_equal(env.memory_writes[1].value, 0x80 + 10, "selected-teleport hold should pin the target X")
    assert_equal(env.memory_writes[2].address, 7, "selected-teleport hold should write the target slot byte 1")
    assert_equal(env.memory_writes[2].value, 0x40 + 13, "selected-teleport hold should pin the target Y")
    assert_equal(#env.memory_writes, 2, "selected-teleport hold should skip unchanged movement byte writes")

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

function tests.survey_safe_autowalk_skips_arrival_input_and_speech()
    local target = {name = "King", type = "npc", id = "npc_10", x = 5, y = 3}
    local env = make_env({
        is_bizhawk = true,
        current_object = target,
        config_values = {
            auto_walk_npc_hold_frames = "2",
            auto_walk_face_target_frames = "2",
        },
    })

    env.route_manager.autowalk_to_object(target, {
        survey_safe = true,
        speak = false,
        store_debug_path = false,
    })
    env.auto_step.on_route_complete()
    env.route_manager.apply_npc_freeze()

    assert_equal(#env.joypad_sets, 0, "survey routes should not inject post-arrival facing input")
    assert_equal(#env.memory_writes, 0, "survey routes should not hold the target NPC after arrival")
    assert_equal(env.suppress_direction_tracking_calls(), 0, "survey routes should not arm facing-input suppression")
    assert_equal(table.concat(env.outputs, "\n"), "", "silent survey routes should not announce normal arrival speech")

    env.restore()
end

function tests.survey_safe_autowalk_keeps_turn_settle_but_skips_straight_settle()
    local target = {name = "King", type = "npc", id = "npc_10", x = 5, y = 3}
    local env = make_env({
        current_object = target,
        path_length = 2,
    })

    env.route_manager.autowalk_to_object(target, {
        survey_safe = true,
        speak = false,
    })

    local opts = env.last_start_route_opts()
    assert_equal(opts and opts.settle_frames, 30, "survey routes should retain long settle frames for direction changes")
    assert_equal(opts and opts.settle_same_direction, false, "survey routes should skip the long settle between straight same-direction steps")

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

function tests.survey_safe_already_adjacent_skips_arrival_input()
    local target = {name = "King", type = "npc", id = "npc_10", x = 5, y = 3}
    local env = make_env({
        pathfind_mode = "already_adjacent",
        current_object = target,
        config_values = {
            auto_walk_npc_hold_frames = "2",
            auto_walk_face_target_frames = "1",
        },
    })

    local plan = env.route_manager.autowalk_to_object(target, {
        survey_safe = true,
        speak = false,
        store_debug_path = false,
    })
    env.route_manager.apply_npc_freeze()

    assert_equal(plan.status, "already_there", "survey-safe adjacent target should still finalize as already_there")
    assert_equal(#env.joypad_sets, 0, "survey-safe adjacent target should not inject facing input")
    assert_equal(#env.memory_writes, 0, "survey-safe adjacent target should not hold the target NPC")
    assert_equal(env.suppress_direction_tracking_calls(), 0, "survey-safe adjacent target should not suppress direction tracking")
    assert_equal(table.concat(env.outputs, "\n"), "", "silent survey-safe adjacent target should not speak")

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

function tests.autowalk_no_path_ignores_irrelevant_closed_door_hint()
    local env = make_env({
        pathfind_mode = "always_no_path",
        current_object = {name = "Merchant 4", type = "npc", x = 8, y = 8},
        closed_door_cells = {
            ["5,3"] = true,
        },
        non_walkable_cells = {
            ["5,3"] = true,
            ["8,7"] = true,
            ["8,9"] = true,
            ["7,8"] = true,
            ["9,8"] = true,
        },
    })

    env.route_manager.autowalk_to_current()

    local output = table.concat(env.outputs, "\n")
    assert_contains(output, "No path found", "irrelevant closed-door no-path should still report no path")
    assert_not_contains(
        output,
        "Route is blocked by a closed door",
        "closed-door hint should only appear when opening the door reaches the selected target"
    )

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

function tests.autowalk_no_path_softens_stationary_npc_hint_when_blocker_cannot_move()
    local target = {id = "npc_10", name = "Merchant 2", type = "npc", x = 6, y = 1}
    local stationary = {id = "npc_12", name = "Woman 3", type = "npc", x = 5, y = 3, movement = 0}
    local env = make_env({
        pathfind_mode = "block_sensitive",
        pathfind_block_key = "5,3",
        current_object = target,
        object_list = {target, stationary},
        blocking_positions = {
            {x = 5, y = 3},
        },
    })

    env.route_manager.autowalk_to_current()

    local output = table.concat(env.outputs, "\n")
    assert_contains(
        output,
        "Route may be blocked by a stationary NPC",
        "stationary NPC blockers should be announced as possible blockers without false certainty"
    )
    assert_contains(
        output,
        "Try again in a moment",
        "stationary blocker output should leave room for a quick retry when NPC state changes"
    )
    assert_not_contains(
        output,
        "Waiting will not clear this route",
        "stationary blocker output should not claim retrying cannot help"
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
