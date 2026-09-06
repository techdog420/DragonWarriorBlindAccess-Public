-- test_route_manager.lua
-- Focused regression tests for route_manager entry guards.

local original_preload = {}
local original_loaded = {}
local original_emulator_compat = _G.DW_EMULATOR_COMPAT
local original_joypad = _G.joypad
local original_os_clock = os.clock

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
    local warning_outputs = {}
    local published_events = {}
    local event_subscribers = {}
    local function publish_event(name, payload)
        published_events[#published_events + 1] = {name = name, payload = payload}
        for _, handler in ipairs(event_subscribers[name] or {}) do
            handler(payload)
        end
    end
    local start_route_calls = 0
    local last_start_route_steps = nil
    local last_start_route_opts = nil
    local overworld_plan_calls = 0
    local inject_step_calls = 0
    local last_inject_opts = nil
    local suppress_direction_tracking_calls = 0
    local last_suppress_direction_tracking_frames = nil
    local cancel_active_step_calls = {}
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
    local debug_infos = {}
    local registered_commands = {}
    local joypad_sets = {}
    local memory_values = options.memory_values or {}
    local memory_writes = {}
    local input_refusal = options.input_refusal
    local current_object = options.current_object or {id = "chest_1", name = "Chest", type = "chest", x = 6, y = 1}
    local object_list = options.object_list or {current_object}
    local current_map_id = options.start_map_id or 0x05
    local current_x = options.start_x or 5
    local current_y = options.start_y or 4
    local clock_now = 0
    local pathability_filter = 1
    local pathability_statuses = {}
    local pathability_status_updates = 0
    local module_names = {
        "addresses",
        "auto_step",
        "config",
        "darkness",
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
        local function memory_blocking_positions()
            local positions = {}
            for slot = 0, 19 do
                local base = slot * 3
                local byte0 = memory_values[base] or 0
                local byte1 = memory_values[base + 1] or 0
                local byte2 = memory_values[base + 2] or 0
                local x = byte0 % 32
                local y = byte1 % 32
                if not ((x == 0 and y == 0) or (x == 31 and y == 31)) then
                    positions[#positions + 1] = {
                        id = "npc_" .. slot,
                        x = x,
                        y = y,
                        movement = byte2,
                    }
                end
            end
            return positions
        end
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
            describe_current = function(desc_opts)
                if options.describe_current_fn then
                    return options.describe_current_fn(current_object, desc_opts)
                end
                return options.current_description or (current_object.name .. ": 3 north (1 of 1)")
            end,
            update_npcs = function()
                update_npcs_calls = update_npcs_calls + 1
            end,
            get_blocking_positions = function()
                if options.blocking_positions_fn then
                    return options.blocking_positions_fn(memory_values)
                end
                if options.blocking_positions_from_memory then
                    return memory_blocking_positions()
                end
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
            if options.pathfind_no_path and options.pathfind_no_path(blocking or {}) then
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
            format_path = function(path)
                if not path or #path == 0 then
                    return "Already there"
                end
                return "Path: " .. #path .. " step(s)"
            end,
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
                if options.pathfind_to_fn then
                    local result, face_dir, path = options.pathfind_to_fn(start_x, start_y, goal_x, goal_y, blocking, opts)
                    if result ~= nil then
                        return result, face_dir, path
                    end
                end
                if pathfind_mode == "always_no_path" then
                    return "No path found", nil, nil
                end
                if pathfind_mode == "hazard_only" and not (opts and opts.walkability_snapshot) then
                    return "No path found", nil, nil
                end
                if pathfind_mode == "direct_no_path_adjacent_ok" then
                    return "No path found", nil, nil
                end
                if pathfind_mode == "reroute_no_path" and reroute_calls >= 2 then
                    return "No path found", nil, nil
                end
                if options.pathfind_no_path and options.pathfind_no_path(blocking or {}) then
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
                if pathfind_mode == "hazard_only" and not (opts and opts.walkability_snapshot) then
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
                if options.pathfind_to_adjacent_fn then
                    local result, face_dir, path = options.pathfind_to_adjacent_fn(start_x, start_y, goal_x, goal_y, blocking, opts)
                    if result ~= nil then
                        return result, face_dir, path
                    end
                end
                if pathfind_mode == "already_adjacent" then
                    return "Adjacent", "north", {}
                end
                if options.already_adjacent_after_first and reroute_calls > 1 then
                    return "Adjacent", "north", {}
                end
                if pathfind_mode == "always_no_path" then
                    return "No path found", nil, nil
                end
                if pathfind_mode == "hazard_only" and not (opts and opts.walkability_snapshot) then
                    return "No path found", nil, nil
                end
                if pathfind_mode == "reroute_no_path" and reroute_calls >= 2 then
                    return "No path found", nil, nil
                end
                if options.pathfind_no_path and options.pathfind_no_path(blocking or {}) then
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
                if pathfind_mode == "hazard_only" and not (opts and opts.walkability_snapshot) then
                    return nil, nil, nil, {}
                end
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
        local hazard_cells = options.hazard_cells or {}
        return {
            get_map_dimensions = function()
                return options.map_width or 10, options.map_height or 10
            end,
            get_directional_blocks = function()
                return {}
            end,
            get_entry_settle_frames = function(map_id, x, y, approach)
                local by_map = options.entry_settle_frames
                    and options.entry_settle_frames[map_id]
                local entry = by_map and by_map[tostring(x) .. "," .. tostring(y)]
                return math.max(0, math.floor(tonumber(
                    type(entry) == "table" and entry[approach] or 0
                ) or 0))
            end,
            get_entry_prime_frames = function(map_id, x, y, approach)
                local by_map = options.entry_prime_frames
                    and options.entry_prime_frames[map_id]
                local entry = by_map and by_map[tostring(x) .. "," .. tostring(y)]
                return math.max(0, math.floor(tonumber(
                    type(entry) == "table" and entry[approach] or 0
                ) or 0))
            end,
            is_hazard_cell = function(_, x, y)
                return hazard_cells[x .. "," .. y] or false
            end,
            get_walkability_snapshot = function(_, opts)
                local allow_hazards = opts and opts.allow_hazards == true
                local snapshot = {}
                for y = 0, (options.map_height or 10) - 1 do
                    snapshot[y] = {}
                    for x = 0, (options.map_width or 10) - 1 do
                        local key = x .. "," .. y
                        snapshot[y][x] = not non_walkable_cells[key]
                            and (allow_hazards or not hazard_cells[key])
                    end
                end
                return snapshot
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
                if x == 0 and y == 0 then
                    return options.walkable_origin == true
                end
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
            inject_step = function(dir, opts)
                inject_step_calls = inject_step_calls + 1
                last_injected_dir = dir
                last_inject_opts = opts
            end,
            suppress_direction_tracking = function(frames)
                suppress_direction_tracking_calls = suppress_direction_tracking_calls + 1
                last_suppress_direction_tracking_frames = frames
            end,
            cancel_active_step = function(clear_queued_route, force_release)
                cancel_active_step_calls[#cancel_active_step_calls + 1] = {
                    clear_queued_route = clear_queued_route,
                    force_release = force_release,
                }
            end,
            is_route_active = function()
                return options.auto_step_route_active == true
            end,
        }
        return stub
    end

    package.preload["tolk"] = function()
        local function record_output(msg)
            outputs[#outputs + 1] = msg
        end
        local function record_warning(msg)
            warning_outputs[#warning_outputs + 1] = msg
            record_output(msg)
        end
        return {
            output_interrupt = record_output,
            output_warning = record_warning,
        }
    end

    local overworld_plan_opts_log = {}
    local overworld_start_calls = {}
    package.preload["overworld_routes"] = function()
        return {
            active_destination = function()
                return options.overworld_active_destination
            end,
            network_entry_candidates = function()
                return options.overworld_network_candidates or {}
            end,
            network_transition_cells = function()
                return options.overworld_transition_cells or {}
            end,
            is_network_corridor_cell = function(x, y)
                if options.overworld_network_cell_fn then
                    return options.overworld_network_cell_fn(x, y)
                end
                return options.overworld_on_network ~= false
            end,
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
            active_route_matches_object = function(obj)
                if options.overworld_active_route_matches_object_fn then
                    return options.overworld_active_route_matches_object_fn(obj)
                end
                return options.overworld_active_route_matches_object == true
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
        local function input_refusal_details(value)
            if type(value) == "table" then
                return tostring(value.details or "")
            end
            return tostring(value)
        end

        local function input_refusal_allowed(value, opts)
            return type(value) == "table"
                and value.allow_route_blocked_self_input == true
                and opts
                and opts.allow_route_blocked_self_input == true
                and opts.route_blocked_timing_suspect == true
                and tostring(opts.route_blocked_dir or "") == tostring(value.route_blocked_dir or "")
        end

        return {
            DEBUG_MODE = true,
            info = function(msg)
                debug_infos[#debug_infos + 1] = msg
            end,
            debug = function() end,
            error = function(msg)
                debug_infos[#debug_infos + 1] = msg
            end,
            register_command = function(name, fn)
                registered_commands[name] = fn
            end,
            input_contamination_refusal = function(command_name, opts)
                if not input_refusal then
                    return nil
                end
                if input_refusal_allowed(input_refusal, opts) then
                    debug_infos[#debug_infos + 1] = "INPUT_CONTAMINATION_IGNORED test_stub"
                    return nil
                end
                local details = input_refusal_details(input_refusal)
                return string.format(
                    "%s refused: input contaminated (%s)",
                    tostring(command_name or "command"),
                    details),
                    details
            end,
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
            publish = publish_event,
            subscribe = function(name, handler)
                if not event_subscribers[name] then
                    event_subscribers[name] = {}
                end
                event_subscribers[name][#event_subscribers[name] + 1] = handler
                return #event_subscribers[name]
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
            light_radius = options.snapshot_light_radius or 0,
            radiant_timer = options.snapshot_radiant_timer or 0,
        }
    end

    os.clock = function()
        return clock_now
    end

    local route_manager = require "route_manager"

    return {
        outputs = outputs,
        warning_outputs = warning_outputs,
        published_events = function() return published_events end,
        publish_event = publish_event,
        auto_step = package.loaded["auto_step"],
        route_manager = route_manager,
        snapshot = package.loaded["game_snapshot"],
        pathfind_calls = function() return pathfind_calls end,
        update_npcs_calls = function() return update_npcs_calls end,
        request_refresh_calls = function() return request_refresh_calls end,
        debug_infos = function() return debug_infos end,
        invoke_command = function(name, arg)
            local fn = registered_commands[name]
            if not fn then
                error("command not registered: " .. tostring(name))
            end
            return fn(arg)
        end,
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
        last_inject_opts = function() return last_inject_opts end,
        suppress_direction_tracking_calls = function() return suppress_direction_tracking_calls end,
        last_suppress_direction_tracking_frames = function() return last_suppress_direction_tracking_frames end,
        cancel_active_step_calls = cancel_active_step_calls,
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
        set_input_refusal = function(value)
            input_refusal = value
        end,
        advance_clock = function(seconds)
            clock_now = clock_now + seconds
        end,
        joypad_sets = joypad_sets,
        restore = function()
            restore_modules(module_names)
            _G.DW_EMULATOR_COMPAT = original_emulator_compat
            _G.joypad = original_joypad
            os.clock = original_os_clock
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

local function assert_truthy(value, message)
    if not value then
        error(message, 2)
    end
end

local function make_path_from_dirs(start_x, start_y, dirs)
    local x = start_x
    local y = start_y
    local path = {}
    for i, dir in ipairs(dirs) do
        if dir == "north" then
            y = y - 1
        elseif dir == "south" then
            y = y + 1
        elseif dir == "west" then
            x = x - 1
        elseif dir == "east" then
            x = x + 1
        else
            error("unsupported test dir: " .. tostring(dir), 2)
        end
        path[i] = {x = x, y = y, direction = dir}
    end
    return path
end

local function repeated_dirs(dir, count)
    local dirs = {}
    for i = 1, count do
        dirs[i] = dir
    end
    return dirs
end

local function assert_write_value(memory_writes, index, address, expected, message)
    local write = memory_writes[index]
    if not write then
        error(string.format("%s: missing write #%d", message, index), 2)
    end
    if write.address ~= address or write.value ~= expected then
        error(string.format(
            "%s: expected write #%d to be address %d value %s, got address %s value %s",
            message,
            index,
            address,
            tostring(expected),
            tostring(write.address),
            tostring(write.value)), 2)
    end
end

local function assert_write_set(memory_writes, start_index, expected_by_address, message)
    local actual = {}
    for i = start_index, #memory_writes do
        local write = memory_writes[i]
        actual[write.address] = write.value
    end
    for address, expected in pairs(expected_by_address) do
        if actual[address] ~= expected then
            error(string.format(
                "%s: expected address %d value %s, got %s",
                message,
                address,
                tostring(expected),
                tostring(actual[address])), 2)
        end
    end
end

local tests = {}

function tests.player_stop_clears_route_context_and_force_releases_direction()
    local env = make_env({auto_step_route_active = true})

    env.route_manager.autowalk_to_current()
    assert_truthy(env.route_manager.get_last_pathfind_obj(),
        "auto-walk setup should retain the selected target")

    local stopped = env.route_manager.stop_auto_walk("player hotkey")

    assert_equal(stopped, true, "active route cancellation should report success")
    assert_equal(#env.cancel_active_step_calls, 1,
        "player cancellation should cancel the active auto-step exactly once")
    assert_equal(env.cancel_active_step_calls[1].clear_queued_route, true,
        "player cancellation should clear queued route steps")
    assert_equal(env.cancel_active_step_calls[1].force_release, true,
        "player cancellation should force-release held direction input")
    assert_equal(env.route_manager.get_last_pathfind_obj(), nil,
        "player cancellation should clear route-manager target context")

    env.restore()
end

function tests.player_stop_is_safe_noop_after_path_preview_without_active_route()
    local env = make_env()

    env.route_manager.pathfind_to_current()
    assert_truthy(env.route_manager.get_last_pathfind_obj(),
        "path preview should retain its target without starting auto-walk")

    local stopped = env.route_manager.stop_auto_walk("player hotkey")

    assert_equal(stopped, false, "path preview alone should not count as active auto-walk")
    assert_equal(#env.cancel_active_step_calls, 0,
        "idle cancellation should not inject a neutral controller frame")
    assert_truthy(env.route_manager.get_last_pathfind_obj(),
        "idle cancellation should preserve path-preview target context")

    env.restore()
end

function tests.overworld_terminal_arrival_force_releases_before_final_carry()
    local env = make_env({
        is_overworld = true,
        overworld_segment = {
            route = {
                id = "great_swamp_cantlin",
                title = "Eastern Great Swamp Search Area",
            },
            waypoint = {
                name = "Eastern Great Swamp Search Area",
                x = 89,
                y = 112,
            },
            index = 38,
            steps = {"right"},
            message = "Auto-walk to Eastern Great Swamp Search Area.",
            object_id = "route_great_swamp_cantlin_38",
        },
    })

    env.route_manager.autowalk_to_current()
    local handled = env.route_manager.on_overworld_route_event({
        terminal = true,
        route = {id = "great_swamp_cantlin"},
        message = "Arrived at Eastern Great Swamp Search Area",
    })

    assert_equal(handled, true,
        "terminal overworld arrival should stop the active segment immediately")
    assert_equal(#env.cancel_active_step_calls, 1,
        "terminal overworld arrival should cancel queued movement exactly once")
    assert_equal(env.cancel_active_step_calls[1].clear_queued_route, true,
        "terminal overworld arrival should clear the queued route")
    assert_equal(env.cancel_active_step_calls[1].force_release, true,
        "terminal overworld arrival should force-release the final direction")
    assert_equal(env.route_manager.get_last_pathfind_obj(), nil,
        "terminal overworld arrival should clear route-manager context")

    env.restore()
end

function tests.overworld_nonterminal_event_does_not_stop_active_segment()
    local env = make_env({
        is_overworld = true,
        overworld_segment = {
            route = {id = "great_swamp_cantlin", title = "Great Swamp"},
            waypoint = {name = "Great Swamp east lane", x = 89, y = 113},
            index = 37,
            steps = {"right"},
            message = "Auto-walk to Great Swamp east lane.",
            object_id = "route_great_swamp_cantlin_37",
        },
    })

    env.route_manager.autowalk_to_current()
    local handled = env.route_manager.on_overworld_route_event({
        terminal = false,
        route = {id = "great_swamp_cantlin"},
        message = "Reached Great Swamp east lane",
    })

    assert_equal(handled, false,
        "ordinary waypoint events should leave the queued segment active")
    assert_equal(#env.cancel_active_step_calls, 0,
        "ordinary waypoint events should not force-release movement")

    env.restore()
end

function tests.navigation_reload_rebinds_objects_module()
    local env = make_env({current_description = "Chest: 3 north (1 of 1)"})
    local replacement = {}
    for key, value in pairs(package.loaded["objects"]) do
        replacement[key] = value
    end
    replacement.current_object = function()
        return {id = "npc_4", name = "Weapons Merchant", type = "npc", x = 16, y = 3}
    end
    replacement.describe_current = function()
        return "Weapons Merchant: 1 east (1 of 4)"
    end
    package.loaded["objects"] = replacement

    env.route_manager.refresh_navigation_modules()

    assert_equal(
        env.route_manager.describe_current_object({include_reachability = false}),
        "Weapons Merchant: 1 east (1 of 4)",
        "navigation reload should keep route-manager object selection on the reloaded objects module"
    )

    env.restore()
end

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

function tests.autowalk_guard_receives_route_options()
    local env = make_env()
    local received_opts = nil
    env.route_manager.set_autowalk_guard(function(opts)
        received_opts = opts
        return true
    end)

    local result = env.route_manager.autowalk_to_object(
        {id = "survey_target", name = "Survey Target", type = "chest", x = 6, y = 1},
        {speak = false, survey_safe = true})

    assert_equal(result.status, "queued", "allowed guarded autowalk should still queue")
    assert_truthy(received_opts ~= nil, "guard should receive the autowalk option table")
    assert_equal(received_opts.survey_safe, true, "guard should see survey-safe internal route starts")
    assert_equal(env.start_route_calls(), 1, "allowed guarded autowalk should queue route steps")

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
            waypoint = {
                name = "Garinham east ridge",
                x = 16,
                y = 6,
                route_early_twitch_timeout_frames = 90,
                route_hold_after_movement_start_frames = 60,
                route_reset_movement_on_turn_settle = true,
                route_final_inject_limit = 10,
            },
            index = 14,
            steps = {"up", "left", "left", "left"},
            route_final_carry_x = 16,
            route_final_carry_y = 5,
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
    assert_equal(
        env.last_start_route_opts().route_early_twitch_timeout_frames,
        90,
        "overworld segment should forward waypoint-specific queued-route twitch timing"
    )
    assert_equal(
        env.last_start_route_opts().route_hold_after_movement_start_frames,
        60,
        "overworld segment should forward waypoint-specific queued-route hold timing"
    )
    assert_equal(
        env.last_start_route_opts().route_reset_movement_on_turn_settle,
        true,
        "overworld segment should forward waypoint-specific movement-reset timing"
    )
    assert_equal(
        env.last_start_route_opts().route_final_inject_limit,
        10,
        "overworld segment should forward waypoint-specific final press timing"
    )
    assert_equal(
        env.last_start_route_opts().route_final_carry_x,
        16,
        "overworld segment should forward the allowed carry column"
    )
    assert_equal(
        env.last_start_route_opts().route_final_carry_y,
        5,
        "overworld segment should forward the allowed carry row"
    )
    assert_equal(
        env.last_start_route_opts().route_accept_final_drift_completion,
        nil,
        "overworld segment should not use broad same-direction carry"
    )
    assert_contains(env.outputs[#env.outputs], "Overworld auto-walk", "overworld auto-walk should be announced")

    env.restore()
end

local function off_network_recovery_env(extra)
    extra = extra or {}
    local options = {
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 10,
        start_y = 10,
        map_width = 40,
        map_height = 40,
        overworld_on_network = false,
        overworld_active_route_id = "cantlin_staging",
        overworld_active_destination = {
            id = "great_swamp_cantlin",
            title = "Eastern Great Swamp Search Area",
        },
        overworld_network_candidates = {
            {
                x = 10,
                y = 13,
                name = "Safe network entry",
                route_id = "great_swamp_cantlin",
                route_title = "Eastern Great Swamp Search Area",
                next_waypoint = {name = "Southern plains west road"},
                opening_length = 2,
            },
        },
        pathfind_to_fn = function(start_x, start_y, goal_x, goal_y)
            if goal_x == 10 and goal_y == 13 then
                return "Path", nil, {
                    {x = 10, y = 11, direction = "south"},
                    {x = 10, y = 12, direction = "south"},
                    {x = 10, y = 13, direction = "south"},
                }
            end
            return "No path found", nil, nil
        end,
        overworld_start_result = {
            route = {
                id = "great_swamp_cantlin",
                title = "Eastern Great Swamp Search Area",
            },
            waypoint = {name = "Southern plains west road"},
            message = "Route recalculated",
        },
    }
    for key, value in pairs(extra) do
        options[key] = value
    end
    return make_env(options)
end

function tests.off_network_recovery_autowalk_stops_at_network_and_hands_off_destination()
    local env = off_network_recovery_env({
        config_values = {
            overworld_auto_walk_continuous = "true",
        },
    })

    local result = env.route_manager.autowalk_to_current()

    assert_equal(result.status, "recovery_queued",
        "off-network auto-walk should queue the decoded-safe recovery path")
    assert_equal(result.boundary_stop, true,
        "recovery should explicitly stop at the waypoint-network boundary")
    assert_equal(env.overworld_plan_calls(), 0,
        "off-network recovery should not queue the ordinary axis-ordered segment")
    assert_equal(env.start_route_calls(), 1,
        "recovery should queue exactly one movement route")
    assert_equal(env.last_start_route_steps()[1], "down",
        "recovery should convert A-star south steps to controller directions")
    assert_equal(env.last_start_route_steps()[3], "down",
        "recovery should preserve the complete safe path")
    assert_equal(env.last_start_route_opts().start_x, 10,
        "recovery should bind the queued route to the live start X")
    assert_equal(env.last_start_route_opts().start_y, 10,
        "recovery should bind the queued route to the live start Y")
    assert_contains(env.outputs[#env.outputs], "Auto-walk will stop at the waypoint network",
        "startup speech should explain the safety boundary")

    env.set_position(0x01, 10, 13)
    env.auto_step.on_route_complete()

    assert_equal(env.start_route_calls(), 1,
        "continuous mode must not silently queue the first guided segment")
    assert_equal(#env.overworld_start_calls(), 1,
        "network arrival should recalculate the selected final destination once")
    assert_equal(env.overworld_start_calls()[1].route_id, "great_swamp_cantlin",
        "handoff should preserve the player's final destination")
    assert_equal(env.overworld_start_calls()[1].x, 10,
        "handoff should start from the reached network-entry X")
    assert_equal(env.overworld_start_calls()[1].y, 13,
        "handoff should start from the reached network-entry Y")
    assert_contains(env.outputs[#env.outputs], "Press auto-walk again to continue",
        "network arrival should require explicit authorization for the guided leg")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "OVERWORLD_RECOVERY_AUTO_WALK event=complete",
        "network handoff should be recorded in structured logs")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "continuous_requested=true boundary_stop=true",
        "continuous configuration should remain stopped at the recovery boundary")

    env.restore()
end

function tests.off_network_recovery_menu_interrupt_replans_from_current_position()
    local path_starts = {}
    local env = off_network_recovery_env({
        config_values = {
            overworld_auto_walk_continuous = "true",
        },
        pathfind_to_fn = function(start_x, start_y, goal_x, goal_y)
            path_starts[#path_starts + 1] = {x = start_x, y = start_y}
            if start_x ~= 10 or goal_x ~= 10 or goal_y ~= 13
               or start_y < 10 or start_y >= 13 then
                return "No path found", nil, nil
            end
            local path = {}
            for y = start_y + 1, goal_y do
                path[#path + 1] = {x = 10, y = y, direction = "south"}
            end
            return "Path", nil, path
        end,
    })

    local initial = env.route_manager.autowalk_to_current()

    assert_equal(initial.status, "recovery_queued",
        "off-network auto-walk should begin the full recovery path")
    assert_equal(#env.last_start_route_steps(), 3,
        "initial recovery should queue all three steps to the network")

    env.set_position(0x01, 10, 11)
    local output_count_before_cancel = #env.outputs
    env.auto_step.on_route_cancelled({
        reason = "can_walk_false",
        current_x = 10,
        current_y = 11,
    })

    assert_equal(#env.outputs, output_count_before_cancel,
        "menu interruption should not add cancellation speech")
    assert_equal(#env.overworld_start_calls(), 0,
        "interruption before network arrival must not hand off the destination")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "OVERWORLD_RECOVERY_AUTO_WALK event=cancel reason=can_walk_false current=(10,11)",
        "menu interruption should retain structured recovery evidence")

    local resumed = env.route_manager.autowalk_to_current()

    assert_equal(resumed.status, "recovery_queued",
        "the next auto-walk press should resume recovery")
    assert_equal(resumed.start_y, 11,
        "resumed recovery should bind to the live interrupted row")
    assert_equal(resumed.path_length, 2,
        "resumed recovery should plan only the two remaining steps")
    assert_equal(#path_starts, 2,
        "interrupted recovery should invoke the pathfinder once per attempt")
    assert_equal(path_starts[1].y, 10,
        "the initial attempt should plan from the original position")
    assert_equal(path_starts[2].y, 11,
        "the resumed attempt should replan from the current position")
    assert_equal(env.start_route_calls(), 2,
        "resumption should queue exactly one replacement movement route")
    assert_equal(#env.last_start_route_steps(), 2,
        "the replacement route should omit the completed step")

    env.set_position(0x01, 10, 13)
    env.auto_step.on_route_complete()

    assert_equal(#env.overworld_start_calls(), 1,
        "network arrival should hand off exactly once after resumption")
    assert_equal(env.overworld_start_calls()[1].route_id, "great_swamp_cantlin",
        "resumed recovery must preserve the final destination")
    assert_equal(env.start_route_calls(), 2,
        "continuous mode must remain stopped at the network boundary")
    assert_contains(env.outputs[#env.outputs], "Press auto-walk again to continue",
        "resumed recovery should still require a fresh boundary authorization")

    env.restore()
end

function tests.manual_overworld_drift_recovers_then_resumes_preserved_destination()
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 19,
        start_y = 7,
        map_width = 40,
        map_height = 20,
        current_object = {
            id = "route_garinham_14",
            name = "Route next: Garinham east ridge",
            type = "exit",
            x = 16,
            y = 6,
        },
        overworld_active_route_id = "garinham",
        overworld_active_destination = {
            id = "garinham",
            title = "Garinham",
        },
        overworld_network_cell_fn = function(_, y)
            return y == 7
        end,
        overworld_network_candidates = {
            {
                x = 19,
                y = 7,
                name = "Original route corridor",
                route_id = "garinham",
                route_title = "Garinham",
                next_waypoint = {name = "Garinham east ridge"},
                opening_length = 4,
            },
        },
        pathfind_to_fn = function(start_x, start_y, goal_x, goal_y)
            if start_x == 19 and start_y == 9
               and goal_x == 19 and goal_y == 7 then
                return "Path", nil, {
                    {x = 19, y = 8, direction = "north"},
                    {x = 19, y = 7, direction = "north"},
                }
            end
            return "No path found", nil, nil
        end,
        overworld_segment = {
            route = {id = "garinham", title = "Garinham"},
            waypoint = {
                name = "Garinham east ridge",
                x = 16,
                y = 6,
            },
            index = 14,
            steps = {"up", "left", "left", "left"},
            message = "Auto-walk to Garinham east ridge, 1 north, 3 west. 4 step(s).",
            object_id = "route_garinham_14",
        },
        overworld_start_result = {
            route = {id = "garinham", title = "Garinham"},
            waypoint = {name = "Garinham east ridge"},
            message = "Route recalculated",
        },
        config_values = {
            overworld_auto_walk_continuous = "true",
        },
    })

    local initial = env.route_manager.autowalk_to_current()
    assert_equal(initial.status, "queued",
        "on-network travel should begin with the ordinary guided segment")
    assert_equal(env.overworld_plan_calls(), 1,
        "the first auto-walk should use the ordinary waypoint planner")

    env.auto_step.on_route_cancelled({
        reason = "live_input_interrupt",
        current_x = 19,
        current_y = 7,
        source = "manual_drift",
    })
    env.set_position(0x01, 19, 9)

    local recovery = env.route_manager.autowalk_to_current()
    assert_equal(recovery.status, "recovery_queued",
        "the next auto-walk after manual drift should queue bounded recovery")
    assert_equal(env.overworld_plan_calls(), 1,
        "off-network recovery should not synthesize an ordinary waypoint opening")
    assert_equal(env.start_route_calls(), 2,
        "recovery should queue one new movement route after the cancelled segment")
    assert_equal(env.last_start_route_steps()[1], "up",
        "recovery should begin toward the selected network entry")
    assert_equal(env.last_start_route_steps()[2], "up",
        "recovery should include the complete two-step return")

    env.set_position(0x01, 19, 7)
    env.auto_step.on_route_complete()

    assert_equal(#env.overworld_start_calls(), 1,
        "network arrival should recalculate the preserved destination once")
    assert_equal(env.overworld_start_calls()[1].route_id, "garinham",
        "manual drift recovery must preserve the original final destination")
    assert_equal(env.start_route_calls(), 2,
        "continuous mode must stop at the recovery boundary")
    assert_contains(env.outputs[#env.outputs], "Press auto-walk again to continue",
        "recovery should require explicit authorization before resuming travel")

    local resumed = env.route_manager.autowalk_to_current()
    assert_equal(resumed.status, "queued",
        "the second boundary press should resume ordinary guided travel")
    assert_equal(env.overworld_plan_calls(), 2,
        "resumed travel should return to the ordinary waypoint planner")
    assert_equal(env.start_route_calls(), 3,
        "resumed travel should queue exactly one guided segment")

    env.restore()
end

function tests.off_network_recovery_autowalk_refuses_hazardous_manual_preview()
    local env = off_network_recovery_env({
        start_x = 10,
        start_y = 14,
        hazard_cells = {
            ["10,13"] = "poison_swamp",
        },
        pathfind_to_fn = function(start_x, start_y, goal_x, goal_y, _, path_opts)
            local row = path_opts and path_opts.walkability_snapshot
                and path_opts.walkability_snapshot[goal_y]
            if not row or row[goal_x] ~= true then
                return "No path found", nil, nil
            end
            return "Path", nil, {
                {x = 10, y = 13, direction = "north"},
            }
        end,
    })

    local result = env.route_manager.autowalk_to_current()

    assert_equal(result.status, "planned_with_hazard",
        "hazard-only recovery should retain the warned preview status")
    assert_equal(result.auto_walk_allowed, false,
        "hazard-only recovery should remain ineligible for auto-walk")
    assert_equal(env.start_route_calls(), 0,
        "hazard-only recovery must not queue movement")
    assert_contains(env.outputs[#env.outputs], "Recovery auto-walk stopped",
        "player speech should explain that hazardous recovery did not begin")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "reason=hazardous_recovery",
        "hazard refusal should be structured in the debug log")

    env.restore()
end

function tests.off_network_recovery_autowalk_uses_reauthorizable_safe_checkpoints()
    local env = off_network_recovery_env({
        map_height = 50,
        overworld_network_candidates = {
            {
                x = 10,
                y = 35,
                name = "Distant network entry",
                route_id = "great_swamp_cantlin",
                route_title = "Eastern Great Swamp Search Area",
                next_waypoint = {name = "Southern plains west road"},
                opening_length = 2,
            },
        },
        pathfind_to_fn = function(_, start_y)
            local long_path = {}
            for y = start_y + 1, 35 do
                long_path[#long_path + 1] = {
                    x = 10, y = y, direction = "south",
                }
            end
            return "Path", nil, long_path
        end,
    })

    local result = env.route_manager.autowalk_to_current()

    assert_equal(result.status, "recovery_queued",
        "an over-limit safe recovery should queue one bounded checkpoint")
    assert_equal(result.checkpoint_stop, true,
        "the first slice should be marked as a checkpoint stop")
    assert_equal(result.boundary_stop, false,
        "a checkpoint must not be mislabeled as the waypoint-network boundary")
    assert_equal(result.network_entry_path_length, 25,
        "checkpoint diagnostics should retain the full safe distance")
    assert_equal(#env.last_start_route_steps(), 24,
        "the first checkpoint must preserve the 24-step safety bound")
    assert_contains(env.outputs[#env.outputs], "press it again to continue recovery",
        "checkpoint startup speech should explain the next authorization")

    env.set_position(0x01, 10, 34)
    env.auto_step.on_route_complete()

    assert_equal(#env.overworld_start_calls(), 0,
        "checkpoint arrival must not perform a premature network handoff")
    assert_contains(env.outputs[#env.outputs], "Recovery checkpoint reached",
        "checkpoint completion should be announced distinctly")

    local final_slice = env.route_manager.autowalk_to_current()
    assert_equal(final_slice.status, "recovery_queued",
        "a second authorization should queue the remaining safe recovery")
    assert_equal(final_slice.checkpoint_stop, false,
        "the final slice should target the actual network boundary")
    assert_equal(final_slice.boundary_stop, true,
        "the final slice should retain the explicit network boundary stop")
    assert_equal(#env.last_start_route_steps(), 1,
        "the second slice should contain only the remaining step")

    env.set_position(0x01, 10, 35)
    env.auto_step.on_route_complete()
    assert_equal(#env.overworld_start_calls(), 1,
        "only actual network arrival should hand off the destination")

    env.restore()
end

function tests.off_network_recovery_blocker_stops_without_destination_handoff()
    local env = off_network_recovery_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(10, 10, "down", {queued_route = true})

    assert_equal(#env.overworld_start_calls(), 0,
        "blocked recovery must not hand off before reaching the network")
    assert_equal(env.published_events()[#env.published_events()].payload.reason,
        "overworld_recovery_blocked",
        "blocked recovery should publish its specific stop reason")
    assert_contains(env.outputs[#env.outputs], "Recovery auto-walk stopped",
        "blocked recovery should use recovery-specific player speech")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "OVERWORLD_RECOVERY_AUTO_WALK event=blocked",
        "blocked recovery should be visible in structured logs")

    env.restore()
end

function tests.overworld_timing_timeout_diagnostic_is_suppressed_when_battle_appears()
    local env = off_network_recovery_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(10, 10, "down", {
        queued_route = true,
        movement_started = true,
        timing_suspect = true,
    })

    assert_equal(#env.seam_entries(0x01), 0,
        "timing-suspect overworld timeout should defer seam evidence during battle-onset grace")
    assert_equal(env.published_events()[#env.published_events()].payload.reason,
        "overworld_recovery_blocked",
        "diagnostic grace must not delay the player-facing route stop")

    env.publish_event("battle_started")

    assert_equal(#env.seam_entries(0x01), 0,
        "battle onset should discard the deferred blocked-seam observation")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "SEAM_OBSERVATION_SUPPRESSED reason=battle_started",
        "battle suppression should be explicit in diagnostics")

    env.restore()
end

function tests.overworld_timing_timeout_diagnostic_is_released_without_battle()
    local env = off_network_recovery_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(10, 10, "down", {
        queued_route = true,
        movement_started = true,
        timing_suspect = true,
    })

    for _ = 1, env.route_manager.BATTLE_ONSET_DIAGNOSTIC_GRACE_FRAMES - 1 do
        env.route_manager.tick_diagnostics()
    end
    assert_equal(#env.seam_entries(0x01), 0,
        "blocked-seam evidence should remain deferred through the grace window")

    env.route_manager.tick_diagnostics()

    assert_equal(#env.seam_entries(0x01), 1,
        "a timeout without battle onset should still become blocked-seam evidence")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "SEAM_OBSERVATION_RELEASED reason=battle_grace_elapsed",
        "released seam evidence should retain a diagnostic explanation")

    env.restore()
end

local function poison_swamp_confirmation_env()
    return make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 5,
        start_y = 4,
        current_object = {
            id = "route_swamp_1",
            name = "Route next: Swamp crossing",
            type = "exit",
            x = 6,
            y = 4,
        },
        overworld_active_route_id = "swamp_route",
        overworld_active_destination = {id = "swamp_route", title = "Swamp Cave"},
        hazard_cells = {
            ["6,4"] = "poison_swamp",
        },
        overworld_segment = {
            route = {id = "swamp_route", title = "Swamp Cave"},
            waypoint = {name = "Swamp crossing", x = 6, y = 4},
            index = 1,
            steps = {"right"},
            message = "Auto-walk to Swamp crossing, 1 east. 1 step.",
            object_id = "route_swamp_1",
        },
    })
end

function tests.overworld_poison_swamp_second_autowalk_press_confirms_crossing()
    local env = poison_swamp_confirmation_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_route_cancelled({
        reason = "dangerous_tile",
        current_x = 5,
        current_y = 4,
        dir = "right",
        dest_x = 6,
        dest_y = 4,
        hazard = "poison_swamp",
        source = "queued_route",
    })

    assert_contains(env.outputs[#env.outputs],
        "Press auto-walk again to continue through this swamp",
        "first poison-swamp refusal should explain the second-press override")

    env.route_manager.autowalk_to_current()

    assert_equal(env.start_route_calls(), 2,
        "second auto-walk press should queue the matching segment again")
    assert_equal(env.last_start_route_opts().allowed_route_hazard, "poison_swamp",
        "confirmed segment should authorize only poison swamp")
    assert_contains(env.outputs[#env.outputs], "Poison swamp confirmed",
        "second auto-walk press should announce accepted risk")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "AUTO_WALK_HAZARD_CONFIRM_ACCEPTED",
        "accepted override should be recorded in structured logs")

    env.restore()
end

function tests.overworld_poison_swamp_confirmation_expires_before_second_press()
    local env = poison_swamp_confirmation_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_route_cancelled({
        reason = "dangerous_tile",
        current_x = 5,
        current_y = 4,
        dir = "right",
        dest_x = 6,
        dest_y = 4,
        hazard = "poison_swamp",
    })
    env.advance_clock(11)
    env.route_manager.autowalk_to_current()

    assert_equal(env.last_start_route_opts().allowed_route_hazard, nil,
        "expired warning should not authorize a later swamp crossing")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "reason=confirmation expired",
        "expired confirmation should explain why it was cleared")

    env.restore()
end

function tests.overworld_poison_swamp_confirmation_is_cleared_by_player_stop()
    local env = poison_swamp_confirmation_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_route_cancelled({
        reason = "dangerous_tile",
        current_x = 5,
        current_y = 4,
        dir = "right",
        dest_x = 6,
        dest_y = 4,
        hazard = "poison_swamp",
    })
    env.route_manager.stop_auto_walk("player hotkey")
    env.route_manager.autowalk_to_current()

    assert_equal(env.last_start_route_opts().allowed_route_hazard, nil,
        "explicit stop should revoke a pending swamp confirmation")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "reason=player hotkey",
        "explicit stop should log confirmation cleanup")

    env.restore()
end

function tests.overworld_poison_swamp_confirmation_is_cleared_when_field_actions_stop()
    local env = poison_swamp_confirmation_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_route_cancelled({
        reason = "dangerous_tile",
        current_x = 5,
        current_y = 4,
        dir = "right",
        dest_x = 6,
        dest_y = 4,
        hazard = "poison_swamp",
    })
    env.auto_step.on_walkability_lost()
    env.route_manager.autowalk_to_current()

    assert_equal(env.last_start_route_opts().allowed_route_hazard, nil,
        "battle, dialogue, or menu interruption should revoke swamp confirmation")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "reason=field actions unavailable",
        "field-state cleanup should be recorded in structured logs")

    env.restore()
end

function tests.overworld_poison_swamp_confirmation_clears_after_safe_terrain()
    local env = poison_swamp_confirmation_env()

    env.route_manager.autowalk_to_current()
    env.auto_step.on_route_cancelled({
        reason = "dangerous_tile",
        current_x = 5,
        current_y = 4,
        dir = "right",
        dest_x = 6,
        dest_y = 4,
        hazard = "poison_swamp",
    })
    env.route_manager.autowalk_to_current()
    env.auto_step.on_step_complete(5, 4, "right", 6, 4, {
        queued_route = true,
        source = "auto_hold",
    })
    env.auto_step.on_step_complete(6, 4, "right", 7, 4, {
        queued_route = true,
        source = "auto_hold",
    })
    env.set_position(0x01, 7, 4)
    env.route_manager.autowalk_to_current()

    assert_equal(env.last_start_route_opts().allowed_route_hazard, nil,
        "reaching safe terrain should end the contiguous swamp authorization")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "reason=safe terrain reached",
        "safe-terrain cleanup should be recorded in structured logs")

    env.restore()
end

function tests.overworld_autowalk_default_stops_after_one_waypoint_segment()
    local options = {
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 19,
        start_y = 7,
        overworld_active_route_id = "garinham",
        current_object = {
            id = "route_garinham_14",
            name = "Route next: Garinham east ridge",
            type = "exit",
            x = 16,
            y = 6,
        },
        overworld_segment = {
            route = {id = "garinham", title = "Garinham"},
            waypoint = {name = "Garinham east ridge", x = 16, y = 6},
            index = 14,
            steps = {"up"},
            message = "Auto-walk to Garinham east ridge.",
            object_id = "route_garinham_14",
        },
    }
    local env = make_env(options)

    env.route_manager.autowalk_to_current()
    assert_equal(env.route_manager.overworld_route_event_speech({
        message = "Reached Garinham east ridge. Next: Garinham north lane.",
    }), "Reached Garinham east ridge. Next: Garinham north lane.",
        "one-segment mode should preserve routine waypoint speech")
    options.overworld_segment = {
        route = {id = "garinham", title = "Garinham"},
        waypoint = {name = "Garinham north lane", x = 16, y = 5},
        index = 15,
        steps = {"up"},
        message = "Auto-walk to Garinham north lane.",
        object_id = "route_garinham_15",
    }
    env.auto_step.on_route_complete()

    assert_equal(env.overworld_plan_calls(), 1,
        "default overworld auto-walk should not plan another waypoint")
    assert_equal(env.start_route_calls(), 1,
        "default overworld auto-walk should remain one segment per command")

    env.restore()
end

function tests.overworld_autowalk_continuous_config_queues_next_waypoint()
    local options = {
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 19,
        start_y = 7,
        overworld_active_route_id = "garinham",
        config_values = {
            overworld_auto_walk_continuous = "true",
        },
        current_object = {
            id = "route_garinham_14",
            name = "Route next: Garinham east ridge",
            type = "exit",
            x = 16,
            y = 6,
        },
        overworld_segment = {
            route = {id = "garinham", title = "Garinham"},
            waypoint = {name = "Garinham east ridge", x = 16, y = 6},
            index = 14,
            steps = {"up"},
            message = "Auto-walk to Garinham east ridge.",
            object_id = "route_garinham_14",
        },
    }
    local env = make_env(options)

    env.route_manager.autowalk_to_current()
    options.overworld_segment = {
        route = {id = "garinham", title = "Garinham"},
        waypoint = {
            name = "Garinham north lane",
            x = 15,
            y = 6,
            route_hold_after_movement_start_frames = 60,
        },
        index = 15,
        steps = {"left"},
        message = "Auto-walk to Garinham north lane.",
        object_id = "route_garinham_15",
    }
    env.auto_step.on_route_complete()

    assert_equal(env.overworld_plan_calls(), 2,
        "continuous overworld auto-walk should plan the next waypoint")
    assert_equal(env.start_route_calls(), 2,
        "continuous overworld auto-walk should queue the next segment")
    assert_equal(env.last_start_route_steps()[1], "left",
        "continuous overworld auto-walk should use the new waypoint steps")
    assert_equal(env.last_start_route_opts().route_hold_after_movement_start_frames, 60,
        "continuous chaining should preserve the next waypoint timing metadata")

    env.restore()
end

function tests.overworld_continuous_speech_suppresses_routine_waypoints_but_keeps_warnings()
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 19,
        start_y = 7,
        overworld_active_route_id = "garinham",
        config_values = {
            overworld_auto_walk_continuous = "true",
        },
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

    local initial_speech = table.concat(env.outputs, "\n")
    assert_contains(initial_speech,
        "Continuous overworld auto-walk to Garinham",
        "continuous mode should announce the route destination at startup")
    assert_not_contains(initial_speech,
        "Auto-walk to Garinham east ridge",
        "continuous mode should not announce its first internal waypoint")

    assert_equal(env.route_manager.overworld_route_event_speech({
        message = "Reached Garinham east ridge. Next: Garinham north lane.",
    }), nil, "continuous mode should silence routine waypoint speech")
    assert_equal(env.route_manager.overworld_route_event_speech({
        message = "Bridge crossing. Monsters may become more dangerous. Next: West lane.",
        warning_message = "Bridge crossing. Monsters may become more dangerous.",
    }), "Bridge crossing. Monsters may become more dangerous.",
        "continuous mode should keep safety warnings without the routine waypoint suffix")
    assert_equal(env.route_manager.overworld_route_event_speech({
        message = "Arrived at Garinham",
        terminal = true,
    }), "Arrived at Garinham",
        "continuous mode should still announce terminal arrival")
    assert_equal(env.route_manager.overworld_route_map_change_speech("Garinham", {
        message = "Arrived at Garinham",
        terminal = true,
    }), nil, "terminal route arrival should replace the redundant map-name announcement")
    assert_equal(env.route_manager.overworld_route_map_change_speech("Garinham", nil),
        "Garinham", "ordinary map changes should retain their map-name announcement")

    env.restore()
end

function tests.overworld_blocker_mode_chains_even_when_continuous_config_is_off()
    local options = {
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 19,
        start_y = 7,
        overworld_active_route_id = "garinham",
        config_values = {
            overworld_auto_walk_continuous = "false",
        },
        current_object = {
            id = "route_garinham_14",
            name = "Route next: Garinham east ridge",
            type = "exit",
            x = 16,
            y = 6,
        },
        overworld_segment = {
            route = {id = "garinham", title = "Garinham"},
            waypoint = {name = "Garinham east ridge", x = 16, y = 6},
            index = 14,
            steps = {"up"},
            message = "Auto-walk to Garinham east ridge.",
            object_id = "route_garinham_14",
        },
    }
    local env = make_env(options)

    env.route_manager.autowalk_to_current({
        speak = true,
        stop_on_blocker = true,
    })
    options.overworld_segment = {
        route = {id = "garinham", title = "Garinham"},
        waypoint = {name = "Garinham north lane", x = 16, y = 5},
        index = 15,
        steps = {"up"},
        message = "Auto-walk to Garinham north lane.",
        object_id = "route_garinham_15",
    }
    env.auto_step.on_route_complete()

    assert_equal(env.overworld_plan_calls(), 2,
        "overworld blocker mode should continue hunting across waypoints")
    assert_equal(env.start_route_calls(), 2,
        "overworld blocker mode should queue the next segment")

    env.restore()
end

function tests.overworld_continuous_mode_stops_cleanly_when_route_is_finished()
    local options = {
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 24,
        start_y = 89,
        overworld_active_route_id = "hauksness",
        config_values = {
            overworld_auto_walk_continuous = "true",
        },
        current_object = {
            id = "route_hauksness_final",
            name = "Route next: Hauksness",
            type = "exit",
            x = 25,
            y = 89,
        },
        overworld_segment = {
            route = {id = "hauksness", title = "Hauksness"},
            waypoint = {name = "Hauksness", x = 25, y = 89, final = true},
            index = 58,
            steps = {"right"},
            message = "Auto-walk to Hauksness.",
            object_id = "route_hauksness_final",
        },
    }
    local env = make_env(options)

    env.route_manager.autowalk_to_current()
    options.overworld_active_route_id = nil
    env.auto_step.on_route_complete()

    assert_equal(env.overworld_plan_calls(), 1,
        "finished continuous route should not ask for another segment")
    assert_equal(env.start_route_calls(), 1,
        "finished continuous route should not queue more movement")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "event=continuous_stop",
        "finished continuous route should log an intentional stop")

    env.restore()
end

function tests.overworld_autowalk_keeps_final_segment_strict()
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 24,
        start_y = 89,
        current_object = {
            id = "route_hauksness_final",
            name = "Route next: Hauksness",
            type = "exit",
            x = 25,
            y = 89,
        },
        overworld_segment = {
            route = {id = "hauksness", title = "Hauksness"},
            waypoint = {name = "Hauksness", x = 25, y = 89, final = true},
            index = 1,
            steps = {"right"},
            message = "Auto-walk to Hauksness, 1 east. 1 step.",
            object_id = "route_hauksness_final",
        },
    })

    local plan = env.route_manager.autowalk_to_current()
    local opts = env.last_start_route_opts()

    assert_equal(plan.status, "queued", "final overworld segment should queue")
    assert_equal(opts.route_final_carry_x, nil,
        "final segment should not pass a carry column")
    assert_equal(opts.route_final_carry_y, nil,
        "final segment should not pass a carry row")

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

function tests.overworld_blocker_mode_reports_exact_edge_without_reroute()
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 19,
        start_y = 7,
        overworld_active_route_id = "garinham",
        current_object = {
            id = "route_garinham_14",
            name = "Route next: Garinham east ridge",
            type = "exit",
            x = 16,
            y = 6,
        },
        overworld_segment = {
            route = {id = "garinham", title = "Garinham"},
            waypoint = {name = "Garinham east ridge", x = 16, y = 6},
            index = 14,
            steps = {"up"},
            message = "Auto-walk to Garinham east ridge.",
            object_id = "route_garinham_14",
        },
    })

    env.route_manager.autowalk_to_current({
        speak = true,
        stop_on_blocker = true,
    })
    env.auto_step.on_blocked(19, 7, "up", {
        queued_route = true,
        movement_started = false,
    })

    assert_equal(env.pathfind_calls(), 0,
        "overworld blocker mode should not invoke interior A* rerouting")
    assert_equal(env.start_route_calls(), 1,
        "overworld blocker mode should stop after the first blocked edge")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "AUTO_WALK_BLOCKER_FOUND map=0x01",
        "overworld blocker mode should emit the structured blocker report")
    assert_contains(table.concat(env.outputs, "\n"),
        "Auto-walk stopped at blocker from 19,7 up to 19,6",
        "overworld blocker mode should speak the exact failed edge")
    assert_contains(table.concat(env.outputs, "\n"),
        "add_blocked_edge:19,7,UP",
        "overworld blocker mode should provide the matching runtime patch command")
    local events = env.published_events()
    assert_equal(events[#events].payload.reason, "stop_on_blocker",
        "overworld blocker mode should publish the blocker-hunt stop reason")

    env.restore()
end

function tests.autowalk_refuses_contaminated_input_before_planning()
    local env = make_env({
        input_refusal = "keys=LeftAlt joy=- bridge=- buttons=0x20",
    })

    local result = env.route_manager.autowalk_to_object(
        {id = "exit_1", name = "Exit", type = "exit", x = 6, y = 1},
        {speak = true})

    assert_equal(result.status, "input_contaminated", "contaminated input should refuse auto-walk")
    assert_equal(result.ok, false, "contaminated input should not report a queued route")
    assert_equal(env.pathfind_calls(), 0, "contaminated auto-walk should not plan a path")
    assert_equal(env.start_route_calls(), 0, "contaminated auto-walk should not queue movement")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "AUTO_WALK_ABORT reason=input_contaminated target=Exit source=autowalk_to_object keys=LeftAlt joy=- bridge=- buttons=0x20",
        "auto-walk should log the same contamination details as probe guardrails")
    assert_contains(table.concat(env.outputs, "\n"),
        "Auto-walk refused. Input contaminated.",
        "auto-walk should announce the refusal")

    env.restore()
end

function tests.autowalk_aborts_contaminated_input_on_block_without_reroute_or_seam_record()
    local env = make_env()

    env.route_manager.autowalk_to_object(
        {id = "exit_1", name = "Exit", type = "exit", x = 6, y = 1},
        {speak = true})
    local pathfinds_after_start = env.pathfind_calls()
    env.set_input_refusal("keys=LeftAlt joy=- bridge=- buttons=0x20")

    env.auto_step.on_blocked(5, 4, "up", {queued_route = true})

    local events = env.published_events()
    assert_equal(env.pathfind_calls(), pathfinds_after_start, "contaminated block should not trigger reroute planning")
    assert_equal(env.start_route_calls(), 1, "contaminated block should not queue another route")
    assert_equal(events[#events].name, "route_cancelled", "contaminated block should publish route cancellation")
    assert_equal(events[#events].payload.reason, "input_contaminated", "route cancellation should tag contamination")
    assert_equal(#env.seam_entries(0x05), 0, "contaminated block should not record seam evidence")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "AUTO_WALK_ABORT reason=input_contaminated target=Exit source=route_blocked keys=LeftAlt joy=- bridge=- buttons=0x20",
        "in-flight auto-walk abort should include contamination details")
    assert_contains(table.concat(env.outputs, "\n"),
        "Auto-walk refused. Input contaminated.",
        "in-flight auto-walk abort should be announced")

    env.restore()
end

function tests.autowalk_allows_timing_suspect_route_blocked_self_input_for_retry()
    local env = make_env()

    env.route_manager.autowalk_to_current()
    env.set_input_refusal({
        details = "keys=LeftAlt joy=- bridge=- buttons=0x20",
        allow_route_blocked_self_input = true,
        route_blocked_dir = "down",
    })
    env.auto_step.on_blocked(5, 4, "down", {
        queued_route = true,
        movement_started = true,
        movement_start_frame = 4,
        timeout_retries = 0,
        turn_represses = 0,
        timing_suspect = true,
        source = "queued_route",
    })

    assert_equal(env.inject_step_calls(), 1, "self-input route block should continue into the timing retry path")
    assert_equal(env.last_injected_dir(), "down", "timing retry should retry the same blocked direction")
    assert_equal(#env.published_events(), 0, "self-input timing retry should not cancel the route")
    assert_not_contains(table.concat(env.debug_infos(), "\n"),
        "AUTO_WALK_ABORT reason=input_contaminated",
        "self-input timing retry should not log an auto-walk contamination abort")

    env.restore()
end

function tests.primed_entry_block_never_falls_back_to_raw_seam_retry()
    local env = make_env({pathfind_mode = "reroute_no_path"})

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "down", {
        queued_route = true,
        movement_started = true,
        movement_start_frame = 4,
        timeout_retries = 1,
        turn_represses = 1,
        timing_suspect = true,
        source = "queued_route",
        entry_prime_waveform = true,
        entry_prime_frames = 1,
        entry_prime_settle_frames = 16,
    })

    assert_equal(env.inject_step_calls(), 1,
        "an exhausted primed entry should receive one cadence-aware seam retry")
    local retry_opts = env.last_inject_opts()
    assert_equal(retry_opts and retry_opts.source, "seam_retry",
        "cadence-aware retry should preserve seam-retry ownership")
    assert_equal(retry_opts and retry_opts.entry_prime_frames, 1,
        "cadence-aware retry should preserve the one-frame prime")
    assert_equal(retry_opts and retry_opts.entry_settle_frames, 16,
        "cadence-aware retry should preserve all sixteen neutral frames")
    assert_truthy(not (retry_opts and retry_opts.hold_after_movement_start),
        "cadence-aware retry must not fall back to the raw hold-after-twitch mode")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "mode=entry_cadence prime=1 settle=16",
        "cadence-aware seam retry should identify its waveform in the log")

    env.restore()
end

function tests.entry_cadence_seam_state_does_not_leak_to_another_edge()
    local env = make_env({pathfind_mode = "reroute_no_path"})

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "down", {
        queued_route = true,
        movement_started = true,
        timing_suspect = true,
        entry_prime_waveform = true,
        entry_prime_frames = 1,
        entry_prime_settle_frames = 16,
    })
    env.auto_step.on_blocked(6, 4, "down", {
        queued_route = true,
        movement_started = true,
        timing_suspect = true,
    })

    assert_equal(env.inject_step_calls(), 2,
        "test setup should start one retry for each distinct seam")
    local unrelated_opts = env.last_inject_opts()
    assert_truthy(not (unrelated_opts and unrelated_opts.entry_prime_frames),
        "a different seam must not inherit the prior edge cadence")
    assert_equal(unrelated_opts and unrelated_opts.hold_after_movement_start, true,
        "an unrelated unmarked seam should retain ordinary hold-after-twitch retry")

    env.restore()
end

function tests.overworld_battle_cancel_clears_without_speech_spam()
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 19,
        start_y = 7,
        config_values = {
            overworld_auto_walk_continuous = "true",
        },
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
    assert_equal(env.overworld_plan_calls(), 1,
        "battle should not plan the next waypoint in continuous mode")
    assert_equal(env.start_route_calls(), 1,
        "battle should not queue another movement segment in continuous mode")
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

function tests.overworld_autowalk_to_current_preserves_active_route_after_object_refresh()
    -- Map changes reset object selection to a nearby landmark. Bare U should
    -- continue guidance started with R instead of treating that refresh as a
    -- deliberate destination change.
    local kol_obj = {id = "overworld_kol", name = "Kol", x = 104, y = 10}
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 104,
        start_y = 10,
        current_object = kol_obj,
        overworld_active_route_id = "northern_cave",
        overworld_route_for_object = "kol",
        overworld_active_route_matches_object = false,
        overworld_segment = {
            route = {id = "northern_cave", title = "Northern Cave"},
            waypoint = {name = "Kol forest west edge", x = 96, y = 13},
            index = 2,
            steps = {"left"},
            message = "Auto-walk to Kol forest west edge.",
            object_id = "route_northern_cave_02",
        },
    })

    env.route_manager.autowalk_to_current({speak = true})

    assert_equal(#env.overworld_start_calls(), 0,
        "bare U should not replace active guidance with the refreshed Kol selection")
    assert_equal(env.overworld_plan_calls(), 1,
        "bare U should queue the active Northern Cave segment")

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

function tests.overworld_autowalk_preserves_active_variant_for_same_destination()
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 8,
        start_y = 3,
        overworld_active_route_id = "kol_hauksness",
        overworld_route_for_object = "kol",
        overworld_active_route_matches_object = true,
        overworld_segment = {
            route = {id = "kol_hauksness", title = "Kol"},
            waypoint = {name = "Garinham north coast lane", x = 14, y = 3},
            index = 55,
            steps = {"right"},
            message = "Auto-walk to Garinham north coast lane.",
            object_id = "route_kol_hauksness_55",
        },
    })

    local kol_obj = {id = "overworld_kol", name = "Kol", x = 104, y = 10}
    env.route_manager.autowalk_to_object(kol_obj, {speak = true})

    assert_equal(#env.overworld_start_calls(), 0, "same-destination variant should remain active")
    assert_equal(env.overworld_plan_calls(), 1, "active same-destination variant should plan its next segment")

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
        name = "Magic Key Merchant",
        type = "npc",
        id = "npc_3",
        x = 4,
        y = 7,
        interaction_x = 4,
        interaction_y = 5,
        interaction_face_dir = "south",
    }
    local env = make_env({
        start_map_id = 0x0B,
        start_x = 29,
        start_y = 14,
        current_object = merchant,
        config_values = {
            auto_walk_npc_hold_frames = "0",
            auto_walk_face_target_frames = "1",
        },
    })

    local plan = env.route_manager.plan_path_to_object(merchant)
    local direct = env.last_direct_call()
    assert_equal(plan.path_mode, "direct", "Rimuldar key service should route directly to the public stand")
    assert_equal(plan.interaction_goal, true, "Rimuldar key service plan should identify the public stand as an interaction goal")
    assert_equal(plan.goal_x, 4, "Rimuldar key service plan should target the public stand X")
    assert_equal(plan.goal_y, 5, "Rimuldar key service plan should target the public stand Y")
    assert_equal(plan.face_dir, "south", "Rimuldar key service plan should use service metadata instead of pathfinder facing")
    assert_equal(direct.start_x, 29, "Rimuldar key service pathfinder call should start at the live entrance X")
    assert_equal(direct.start_y, 14, "Rimuldar key service pathfinder call should start at the live entrance Y")
    assert_equal(direct.goal_x, 4, "Rimuldar key service pathfinder call should use the interaction X")
    assert_equal(direct.goal_y, 5, "Rimuldar key service pathfinder call should use the interaction Y")

    local queued = env.route_manager.autowalk_to_current()
    assert_equal(queued.status, "queued", "Rimuldar key service autowalk should queue the direct route")
    env.auto_step.on_route_complete()
    env.route_manager.apply_npc_freeze()
    assert_equal(env.joypad_sets[#env.joypad_sets].buttons.down, true, "Rimuldar key service arrival should face south toward the seller")

    env.restore()
end

function tests.hauksness_axe_knight_landmark_stops_at_safe_approach_and_faces_east()
    local landmark = {
        id = "landmark_hauksness_axe_knight",
        name = "Axe Knight Approach",
        type = "exit",
        x = 18,
        y = 12,
        interaction_x = 17,
        interaction_y = 12,
        interaction_face_dir = "east",
        interaction_label = "safe approach",
    }
    local env = make_env({
        start_map_id = 0x03,
        start_x = 15,
        start_y = 12,
        map_width = 20,
        map_height = 20,
        current_object = landmark,
        object_list = {landmark},
        config_values = {
            auto_walk_face_target_frames = "1",
        },
        pathfind_to_fn = function(start_x, start_y, goal_x, goal_y)
            if goal_x == 17 and goal_y == 12 then
                return "Path: 2 east", "east",
                    make_path_from_dirs(start_x, start_y, {"east", "east"})
            end
            return "No path found", nil, nil
        end,
    })

    local plan = env.route_manager.plan_path_to_object(landmark)
    local direct = env.last_direct_call()
    assert_equal(plan.interaction_goal, true, "Axe Knight route should use the safe interaction stand")
    assert_equal(plan.goal_x, 17, "Axe Knight route should stop west of the encounter")
    assert_equal(plan.goal_y, 12, "Axe Knight route should stay on the encounter row")
    assert_equal(plan.face_dir, "east", "Axe Knight route should finish facing the encounter")
    assert_equal(direct.goal_x, 17, "pathfinder should target the safe stand X")
    assert_equal(direct.goal_y, 12, "pathfinder should target the safe stand Y")
    for _, step in ipairs(plan.path) do
        assert_equal(
            step.x == 18 and step.y == 12,
            false,
            "planned movement must not include the combat trigger tile"
        )
    end

    local queued = env.route_manager.autowalk_to_current()
    local steps = env.last_start_route_steps()
    assert_equal(queued.status, "queued", "Axe Knight approach should queue a normal route")
    assert_equal(#steps, 2, "Axe Knight approach should queue only the two safe east steps")
    assert_equal(steps[1], "right", "first queued step should move toward the safe stand")
    assert_equal(steps[2], "right", "final queued step should land on the safe stand")

    env.auto_step.on_route_complete()
    env.route_manager.apply_npc_freeze()
    assert_equal(
        env.joypad_sets[#env.joypad_sets].buttons.right,
        true,
        "arrival should face east without taking another movement step"
    )

    env.restore()
end

function tests.rimuldar_path_marks_only_the_cadence_entry_step()
    local target = {id = "exit_test", name = "Test destination", type = "exit", x = 1, y = 1}
    local path = {
        {x = 3, y = 0, direction = "north"},
        {x = 2, y = 0, direction = "west"},
        {x = 1, y = 0, direction = "west"},
        {x = 0, y = 0, direction = "west"},
        {x = 0, y = 1, direction = "south"},
        {x = 1, y = 1, direction = "east"},
    }
    local env = make_env({
        start_map_id = 0x0B,
        start_x = 3,
        start_y = 1,
        current_object = target,
        entry_settle_frames = {
            [0x0B] = {["0,0"] = {east = 16}},
        },
        entry_prime_frames = {
            [0x0B] = {["0,0"] = {east = 1}},
        },
        pathfind_to_fn = function()
            return "Path: north, 3 west, south, east", "east", path
        end,
    })

    local result = env.route_manager.autowalk_to_object(target, {speak = false})
    local route_opts = env.last_start_route_opts()
    local settles = route_opts.settle_before_steps
    local primes = route_opts.prime_before_steps

    assert_equal(result.status, "queued", "synthetic Rimuldar route should queue")
    assert_equal(settles and settles[4], 16, "entry step should receive the verified settle")
    assert_equal(primes and primes[4], 1, "entry step should receive the verified movement prime")
    assert_equal(settles and settles[2], nil, "earlier west steps should retain ordinary timing")
    assert_equal(settles and settles[3], nil, "the approach step should not settle early")
    assert_equal(settles and settles[5], nil, "the south turn should not inherit the entry settle")
    assert_equal(primes and primes[3], nil, "the approach step should not prime early")
    assert_equal(primes and primes[5], nil, "the south turn should not inherit the entry prime")
    assert_contains(
        table.concat(env.debug_infos(), "\n"),
        "AUTO_WALK_ENTRY_SETTLE map=0x0B from=(1,0) dest=(0,0) dir=left step=4 frames=16 prime=1",
        "entry cadence planning should log both requirements and the immediate route origin"
    )

    env.restore()
end

function tests.rimuldar_path_marks_cadence_entry_when_it_is_step_one()
    local target = {id = "entry_test", name = "Entry destination", type = "exit", x = 0, y = 0}
    local env = make_env({
        start_map_id = 0x0B,
        walkable_origin = true,
        start_x = 1,
        start_y = 0,
        current_object = target,
        entry_settle_frames = {
            [0x0B] = {["0,0"] = {east = 16}},
        },
        entry_prime_frames = {
            [0x0B] = {["0,0"] = {east = 1}},
        },
        pathfind_to_fn = function()
            return "Path: 1 west", "west", {
                {x = 0, y = 0, direction = "west"},
            }
        end,
    })

    local result = env.route_manager.autowalk_to_object(target, {speak = false})
    local route_opts = env.last_start_route_opts()
    local settles = route_opts.settle_before_steps
    local primes = route_opts.prime_before_steps

    assert_equal(result.status, "queued", "one-step Rimuldar route should queue")
    assert_equal(settles and settles[1], 16, "first entry step should retain its settle")
    assert_equal(primes and primes[1], 1, "first entry step should retain its movement prime")
    assert_contains(
        table.concat(env.debug_infos(), "\n"),
        "AUTO_WALK_ENTRY_SETTLE map=0x0B from=(1,0) dest=(0,0) dir=left step=1 frames=16 prime=1",
        "first-step entry cadence planning should log both requirements and the supplied route origin"
    )

    env.restore()
end

function tests.multi_interaction_door_routes_to_reachable_stand_and_describes_that_stand()
    local door = {
        name = "B2 Door",
        type = "door",
        id = "door_17_17",
        x = 17,
        y = 17,
        interaction_x = 17,
        interaction_y = 18,
        interaction_face_dir = "north",
        interaction_points = {
            {x = 17, y = 18, face_dir = "north"},
            {x = 17, y = 16, face_dir = "south"},
        },
    }
    local env = make_env({
        start_map_id = 0x18,
        start_x = 13,
        start_y = 15,
        current_object = door,
        pathfind_to_fn = function(_, _, goal_x, goal_y)
            if goal_x == 17 and goal_y == 18 then
                return "No path found", nil, nil
            end
            if goal_x == 17 and goal_y == 16 then
                return "Path: 1 south, 4 east", "south", {
                    {x = 13, y = 16, direction = "south"},
                    {x = 14, y = 16, direction = "east"},
                    {x = 15, y = 16, direction = "east"},
                    {x = 16, y = 16, direction = "east"},
                    {x = 17, y = 16, direction = "east"},
                }
            end
            return nil
        end,
        unreachable_goal_key = "17,18",
        describe_current_fn = function(_, desc_opts)
            local ix = desc_opts and desc_opts.interaction_x or 17
            local iy = desc_opts and desc_opts.interaction_y or 18
            if ix == 17 and iy == 16 then
                return "B2 Door: 2 south, 4 east, interaction 1 south, 4 east (1 of 1)"
            end
            return "B2 Door: 2 south, 4 east, interaction 3 south, 4 east (1 of 1)"
        end,
    })

    local plan = env.route_manager.plan_path_to_object(door)
    assert_equal(plan.result, "Path: 1 south, 4 east", "multi-interaction door should route to the reachable stand")
    assert_equal(plan.goal_x, 17, "multi-interaction door should keep the door column")
    assert_equal(plan.goal_y, 16, "multi-interaction door should choose the north-side stand when reachable")
    assert_equal(plan.face_dir, "south", "multi-interaction door should face the door from the chosen stand")
    assert_equal(plan.selected_interaction.y, 16, "route plan should expose the selected interaction stand")

    local desc = env.route_manager.describe_current_object()
    assert_contains(desc, "interaction 1 south, 4 east", "current-object readout should describe the selected reachable stand")
    assert_not_contains(desc, "Not currently reachable", "current-object readout should not mark the alternate reachable stand unreachable")

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

function tests.overworld_network_entry_preview_selects_nearest_reachable_safe_entry()
    local function path_to(start_x, start_y, goal_x, goal_y)
        local path = {}
        local x, y = start_x, start_y
        while x ~= goal_x do
            x = x + (goal_x > x and 1 or -1)
            path[#path + 1] = {
                x = x,
                y = y,
                direction = goal_x > start_x and "east" or "west",
            }
        end
        while y ~= goal_y do
            y = y + (goal_y > y and 1 or -1)
            path[#path + 1] = {
                x = x,
                y = y,
                direction = goal_y > start_y and "south" or "north",
            }
        end
        return path
    end

    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 10,
        start_y = 10,
        map_width = 20,
        map_height = 20,
        non_walkable_cells = {
            ["11,10"] = true,
        },
        overworld_active_destination = {
            id = "charlock_castle",
            title = "Charlock Castle",
        },
        overworld_network_candidates = {
            {
                x = 11, y = 10, name = "Blocked nearby entry",
                route_id = "tantegel_charlock", route_title = "Tantegel Castle",
                next_waypoint = {name = "Bridge road"}, opening_length = 2,
            },
            {
                x = 10, y = 13, name = "Reachable network entry",
                route_id = "tantegel_charlock", route_title = "Tantegel Castle",
                next_waypoint = {name = "Bridge road"}, opening_length = 3,
            },
            {
                x = 16, y = 10, name = "Farther network entry",
                route_id = "charlock_return", route_title = "Charlock Castle",
                next_waypoint = {name = "Island road"}, opening_length = 2,
            },
        },
        overworld_transition_cells = {
            {x = 9, y = 9, name = "Town entrance"},
        },
        pathfind_to_fn = function(start_x, start_y, goal_x, goal_y)
            if goal_x == 11 and goal_y == 10 then
                return "No path found", nil, nil
            end
            local path = path_to(start_x, start_y, goal_x, goal_y)
            return "Path", nil, path
        end,
    })

    local result = env.route_manager.preview_overworld_network_entry()

    assert_equal(result.status, "planned",
        "preview should find a reachable network entry")
    assert_equal(result.entry_x, 10,
        "preview should select the nearest reachable entry X")
    assert_equal(result.entry_y, 13,
        "preview should select the nearest reachable entry Y")
    assert_equal(result.path_length, 3,
        "preview should report the decoded-safe recovery length")
    assert_equal(result.final_destination_id, "charlock_castle",
        "preview should preserve the active final destination")
    assert_equal(result.rejected_unreachable, 1,
        "preview should count the rejected nearer entry")
    assert_equal(result.skipped_farther, 1,
        "preview should stop once remaining lower bounds cannot win")
    assert_equal(env.pathfind_calls(), 1,
        "the distance field should need only one final A-star path")
    assert_equal(result.search_timing and result.search_timing.fallback, false,
        "matching distance-field and A-star results should avoid legacy fallback")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "method=single_field", "preview should log the optimized search method")
    assert_equal(env.last_direct_call().opts.allow_overworld, true,
        "recovery search should explicitly opt into overworld A star")
    assert_equal(env.last_direct_call().blocking["9,9"], true,
        "recovery search should block automatic transition landmarks")
    assert_equal(env.start_route_calls(), 0,
        "preview must not queue movement")
    assert_contains(result.message, "Preview only; no movement started",
        "spoken preview should make its read-only behavior explicit")

    env.restore()
end

function tests.overworld_network_entry_preview_refuses_when_no_safe_entry_exists()
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 10,
        start_y = 10,
        map_width = 20,
        map_height = 20,
        overworld_active_destination = {
            id = "charlock_castle",
            title = "Charlock Castle",
        },
        overworld_network_candidates = {
            {
                x = 11, y = 10, name = "Isolated entry",
                route_id = "tantegel_charlock", route_title = "Tantegel Castle",
                next_waypoint = {name = "Bridge road"}, opening_length = 2,
            },
        },
        pathfind_mode = "always_no_path",
    })

    local result = env.route_manager.preview_overworld_network_entry()

    assert_equal(result.status, "no_safe_entry",
        "preview should fail closed when no entry is safely reachable")
    assert_equal(result.ok, false,
        "unreachable recovery preview should not report success")
    assert_equal(result.rejected_unreachable, 1,
        "unreachable entry should be included in diagnostics")
    assert_equal(result.search_timing and result.search_timing.fallback, true,
        "distance-field disagreement should fail safe through legacy A-star search")
    assert_equal(env.start_route_calls(), 0,
        "failed preview must not queue movement")
    assert_contains(result.message, "No decoded-safe waypoint-network entry",
        "failure should explain that no safe entry was found")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "OVERWORLD_RECOVERY_SEARCH_FALLBACK",
        "distance-field disagreement should be explicit in the debug log")

    env.restore()
end

function tests.overworld_network_entry_preview_warns_when_poison_swamp_is_required()
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 103,
        start_y = 51,
        map_width = 120,
        map_height = 120,
        hazard_cells = {
            ["103,50"] = "poison_swamp",
        },
        overworld_active_destination = {
            id = "swamp_cave_north",
            title = "Swamp Cave North",
        },
        overworld_network_candidates = {
            {
                x = 103, y = 50, name = "Swamp Cave approach",
                route_id = "swamp_cave", route_title = "Swamp Cave",
                next_waypoint = {name = "Swamp Cave entrance"}, opening_length = 1,
            },
        },
        pathfind_to_fn = function(_, _, goal_x, goal_y, _, path_opts)
            local row = path_opts and path_opts.walkability_snapshot
                and path_opts.walkability_snapshot[goal_y]
            if not row or row[goal_x] ~= true then
                return "No path found", nil, nil
            end
            return "Path", nil, {
                {x = goal_x, y = goal_y, direction = "north"},
            }
        end,
    })

    local result = env.route_manager.preview_overworld_network_entry()

    assert_equal(result.status, "planned_with_hazard",
        "required poison swamp should remain available only as a warned manual preview")
    assert_equal(result.ok, true, "manual hazardous preview should still describe the route")
    assert_equal(result.decoded_safe, false, "hazardous recovery must not be labeled decoded-safe")
    assert_equal(result.auto_walk_allowed, false,
        "hazardous recovery should be explicitly ineligible for auto-walk")
    assert_equal(result.requires_manual_hazard_crossing, true,
        "hazardous recovery should explicitly prohibit silent auto-walk")
    assert_equal(result.hazard_summary and result.hazard_summary.first_hazard, "poison_swamp",
        "preview should identify poison swamp rather than a generic walkable tile")
    assert_equal(result.hazard_summary and result.hazard_summary.first_step, 1,
        "preview should report the immediate swamp boundary")
    assert_contains(result.message, "Warning. No decoded-safe recovery path is available",
        "manual recovery preview should warn when safe routing is impossible")
    assert_contains(result.message, "Unsafe route crosses poison swamp: 1 tile, first in 1 step",
        "warning should identify the damaging terrain and its distance")
    assert_contains(result.message, "Continue manually to enter hazards",
        "warning should keep hazardous crossing under player control")
    assert_equal(env.start_route_calls(), 0,
        "hazardous recovery preview must remain read-only")

    env.restore()
end

function tests.overworld_network_entry_preview_requires_active_destination()
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 10,
        start_y = 10,
    })

    local result = env.route_manager.preview_overworld_network_entry()

    assert_equal(result.status, "no_active_route",
        "preview should require a selected Travel destination")
    assert_equal(env.pathfind_calls(), 0,
        "missing destination should fail before pathfinding")
    assert_contains(result.message, "Select a Travel destination first",
        "failure should explain how to establish recovery context")

    env.restore()
end

function tests.overworld_network_entry_preview_recognizes_current_network_cell()
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 10,
        start_y = 10,
        overworld_active_destination = {
            id = "charlock_castle",
            title = "Charlock Castle",
        },
        overworld_network_candidates = {
            {
                x = 10, y = 10, name = "Current corridor cell",
                route_id = "tantegel_charlock", route_title = "Tantegel Castle",
                next_waypoint = {name = "Bridge road"}, opening_length = 2,
            },
        },
        pathfind_to_fn = function()
            return "Already there", nil, {}
        end,
    })

    local result = env.route_manager.preview_overworld_network_entry()

    assert_equal(result.status, "already_on_network",
        "zero-step preview should identify current network membership")
    assert_equal(result.path_length, 0,
        "current network membership should require no recovery steps")
    assert_contains(result.message, "Already there",
        "preview should clearly report the zero-step recovery path")
    assert_equal(env.start_route_calls(), 0,
        "zero-step preview must remain read-only")

    env.restore()
end

function tests.overworld_recovery_coverage_audit_separates_near_and_over_limit_cells()
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        map_width = 5,
        map_height = 1,
        overworld_network_candidates = {
            {x = 0, y = 0, opening_length = 1},
        },
        overworld_transition_cells = {},
        overworld_network_cell_fn = function(x, y)
            return x == 0 and y == 0
        end,
    })

    local result = env.route_manager.audit_overworld_recovery_coverage(
        "charlock_castle", {map_id = 0x01, max_recovery_steps = 2})

    assert_equal(result.status, "complete", "coverage audit should complete")
    assert_equal(result.counts.network, 1, "entry corridor should count as network")
    assert_equal(result.counts.safe_within_limit, 2,
        "two off-network cells should be within the two-step limit")
    assert_equal(result.counts.safe_over_limit, 2,
        "two off-network cells should exceed the two-step limit")
    assert_equal(result.max_safe_distance, 4,
        "audit should report the farthest decoded-safe recovery distance")
    assert_equal(result.samples.safe_over_limit[1].x, 4,
        "over-limit samples should start with the farthest coordinate")
    assert_contains(table.concat(env.debug_infos(), "\n"),
        "safe_over_limit=2", "structured audit log should include the gap count")
    assert_equal(env.start_route_calls(), 0, "coverage audit must not queue movement")

    env.restore()
end

function tests.overworld_recovery_coverage_audit_identifies_hazard_only_region()
    local walls = {}
    for x = 0, 4 do
        walls[x .. ",0"] = true
        walls[x .. ",2"] = true
    end
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        map_width = 5,
        map_height = 3,
        non_walkable_cells = walls,
        hazard_cells = { ["2,1"] = "poison_swamp" },
        overworld_network_candidates = {
            {x = 0, y = 1, opening_length = 1},
        },
        overworld_transition_cells = {},
        overworld_network_cell_fn = function(x, y)
            return x == 0 and y == 1
        end,
    })

    local result = env.route_manager.audit_overworld_recovery_coverage(
        "magic_temple", {map_id = 0x01, max_recovery_steps = 2})

    assert_equal(result.counts.network, 1, "entry corridor should count as network")
    assert_equal(result.counts.safe_within_limit, 1,
        "safe recovery should stop before poison swamp")
    assert_equal(result.counts.hazard_required, 3,
        "swamp and the region beyond it should require hazardous recovery")
    assert_equal(result.counts.nonwalkable, 10,
        "wall rows should remain outside recovery coverage")
    assert_equal(result.counts.unreachable, 0,
        "hazard-connected cells should not be mislabeled unreachable")
    assert_equal(result.samples.hazard_required[1].x, 4,
        "hazard-only samples should start with the farthest coordinate")
    assert_equal(#result.samples.unreachable, 0,
        "unreachable diagnostics should remain empty when every cell is classified")
    assert_equal(env.start_route_calls(), 0, "coverage audit must remain read-only")

    env.restore()
end

function tests.pathfind_reports_unsafe_hazard_route_when_safe_route_is_blocked()
    local env = make_env({
        pathfind_mode = "hazard_only",
        path_length = 2,
        current_object = {name = "Shrine Stairs", type = "exit", x = 5, y = 1},
        hazard_cells = {
            ["5,3"] = "damage",
            ["5,2"] = "damage",
        },
    })

    env.route_manager.pathfind_to_current()

    local output = table.concat(env.outputs, "\n")
    assert_contains(output, "Shrine Stairs. Path: 1 north", "path preview should still present the unsafe route")
    assert_contains(output, "No safe route", "path preview should explain that only an unsafe route exists")
    assert_contains(output, "Unsafe route crosses damage floor: 2 tiles, first in 1 step", "hazards should be summarized as one compact cluster")
    assert_not_contains(output, "Shrine Stairs. No path found", "path preview should no longer collapse to an error-only message")
    assert_equal(#env.warning_outputs, 1, "unsafe path preview should use deferred warning speech")

    env.restore()
end

function tests.autowalk_stops_before_immediate_hazard()
    local env = make_env({
        pathfind_mode = "hazard_only",
        path_length = 2,
        current_object = {name = "Shrine Stairs", type = "exit", x = 5, y = 1},
        hazard_cells = {
            ["5,3"] = "damage",
            ["5,2"] = "damage",
        },
    })

    local plan = env.route_manager.autowalk_to_current()

    assert_equal(plan.status, "hazard_boundary", "autowalk should stop immediately when the first step is hazardous")
    assert_equal(env.start_route_calls(), 0, "autowalk should not queue any steps when already at the hazard boundary")
    assert_contains(table.concat(env.outputs, "\n"), "Hazard ahead.", "autowalk should warn when the hazard is immediate")
    assert_equal(#env.warning_outputs, 1, "immediate hazard boundary should use deferred warning speech")

    env.restore()
end

function tests.autowalk_queues_safe_prefix_before_hazard()
    local env = make_env({
        pathfind_mode = "hazard_only",
        path_length = 2,
        current_object = {
            id = "exit_5_1",
            name = "Shrine Stairs",
            type = "exit",
            x = 5,
            y = 1,
        },
        hazard_cells = {
            ["5,2"] = "damage",
        },
    })

    local plan = env.route_manager.autowalk_to_current()

    assert_equal(plan.status, "queued", "autowalk should queue the safe prefix of an unsafe route")
    assert_equal(plan.ok, true, "safe-prefix hazard fallback should succeed")
    assert_equal(env.start_route_calls(), 1, "autowalk should queue the safe prefix once")
    assert_equal(#env.last_start_route_steps(), 1, "autowalk should stop before the first hazard tile")
    assert_equal(env.last_start_route_steps()[1], "up", "safe prefix should preserve the non-hazard opening step")
    local direct = env.last_direct_call()
    assert_equal(type(direct and direct.opts and direct.opts.walkability_snapshot), "table", "hazard fallback should replan with hazards allowed")
    assert_contains(table.concat(env.outputs, "\n"), "Auto-walk will stop before the hazard.", "autowalk should announce the hazard stop")

    env.auto_step.on_route_complete()

    assert_contains(table.concat(env.outputs, "\n"), "Auto-walk stopped before hazard after 1 steps", "completion should report the early stop before hazard")
    assert_contains(table.concat(env.outputs, "\n"), "Unsafe route crosses damage floor: 1 tile, first in 2 steps", "completion should restate the hazard warning")

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

function tests.adjacent_coordinate_out_of_bounds_reason_survives_no_path_inference()
    local stats = {}
    local marker_opts = {
        on_complete = function(next_stats)
            stats = next_stats or {}
        end,
        _get_stats = function()
            return stats
        end,
    }
    local env = make_env({
        start_map_id = 0x18,
        start_x = 9,
        start_y = 1,
        map_width = 20,
        map_height = 20,
        pathfind_to_adjacent_fn = function(_, _, _, _, _, opts)
            if opts and opts.on_complete then
                opts.on_complete({success = false, path_length = 0, nodes_visited = 0, reason = "goal_out_of_bounds"})
            end
            return "No path found", nil, nil
        end,
    })

    local plan = env.route_manager.plan_path_to_coordinates(20, 1, {
        path_mode = "adjacent",
        pathfinder_opts = marker_opts,
        store_debug_path = false,
    })

    assert_equal(plan.result, "No path found", "out-of-bounds adjacent coordinate should stay unreachable")
    assert_equal(plan.no_path_reason, "goal_out_of_bounds", "route manager should preserve adjacent goal_out_of_bounds reason")
    assert_equal(marker_opts._get_stats().reason, "goal_out_of_bounds", "diagnostic stats should not be overwritten by no-path inference")
    assert_equal(plan.message, "Coordinate 20,1. No path found. Target is outside this map", "message should not blame NPC clutter for an out-of-bounds coordinate")

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

function tests.object_pathability_filter_recomputes_when_dungeon_light_changes()
    local env = make_env({
        start_map_id = 0x1C,
        start_x = 5,
        start_y = 4,
        snapshot_terrain = 0x20,
        snapshot_light_radius = 1,
        object_list = {
            {id = "stair_1", name = "Stairs", type = "stair", x = 5, y = 4},
        },
    })

    env.route_manager.set_object_pathability_filter("reachable")
    local updates_after_first_pass = env.pathability_status_updates()

    env.snapshot.light_radius = 3
    local info = env.route_manager.refresh_object_pathability_filter_if_needed()

    assert_equal(info.refreshed, true, "changed dungeon light should invalidate cached pathability")
    assert_equal(
        env.pathability_status_updates() > updates_after_first_pass,
        true,
        "changed light radius must recompute even when the visible object ids do not change"
    )

    env.restore()
end

function tests.object_pathability_filter_seeds_from_boundary_exit_neighbor()
    local env = make_env({
        start_map_id = 0x08,
        start_x = 0,
        start_y = 15,
        map_width = 30,
        map_height = 30,
        object_list = {
            {id = "exit_0_15", name = "Exit to World Map", type = "exit", x = 0, y = 15},
            {id = "npc_inside", name = "Townsperson", type = "npc", x = 2, y = 15},
        },
        non_walkable_cells = {
            ["0,15"] = true,
        },
    })

    local info = env.route_manager.set_object_pathability_filter("reachable")
    local statuses = env.pathability_statuses()

    assert_equal(info.reachable, 2, "boundary exit start should still reach the adjacent town component")
    assert_equal(statuses.exit_0_15, true, "standing on the exit should keep the exit reachable")
    assert_equal(statuses.npc_inside, true, "reachable filter should not collapse to only the exit from the exit tile")

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
    assert_equal(env.last_injected_dir(), "up", "seam brute-force should retry the blocked direction")
    assert_equal(
        env.last_inject_opts() and env.last_inject_opts().source,
        "seam_retry",
        "seam brute-force should use the seam-retry step source"
    )
    assert_equal(
        env.last_inject_opts() and env.last_inject_opts().hold_after_movement_start,
        true,
        "seam brute-force should keep holding after a movement twitch"
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
        env.last_inject_opts() and env.last_inject_opts().source,
        "seam_retry",
        "timing-suspect retries should use the seam-retry injection mode"
    )
    assert_equal(
        env.last_inject_opts() and env.last_inject_opts().hold_after_movement_start,
        true,
        "timing-suspect retries should keep holding after movement starts"
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

function tests.timing_retry_temp_block_clears_after_successful_seam_retry()
    local env = make_env({pathfind_mode = "always_path"})

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "up", {
        queued_route = true,
        movement_started = true,
        movement_start_frame = 5,
        timeout_retries = 1,
        turn_represses = 1,
    })
    env.auto_step.on_step_complete(5, 4, "up", 5, 3, {
        queued_route = false,
        source = "auto_hold",
        input_source = "seam_retry",
    })

    local followup = env.last_direct_call()
    assert_equal(
        followup.blocking["5,3"],
        nil,
        "a successful timing-suspect seam retry should clear its route-local avoid before the follow-up plan"
    )
    assert_contains(
        table.concat(env.debug_infos(), "\n"),
        "AUTO_WALK_TEMP_BLOCK_CLEAR",
        "clearing a successful timing-suspect seam should be logged"
    )
    assert_equal(
        env.route_manager.count_runtime_blocks(0x05),
        0,
        "timing-suspect retry avoidance should not become a persistent runtime block"
    )
    local seam = env.route_manager.get_seam_observation(0x05, 5, 3, "south")
    assert_equal(
        seam and seam.blocked_count or 0,
        0,
        "a successful timing retry should not leave a fake blocked seam count behind"
    )
    assert_equal(
        seam and seam.moved_count or 0,
        1,
        "a successful timing retry should preserve the later moved observation"
    )
    assert_equal(
        env.seam_summary(0x05).noisy,
        0,
        "a successful timing retry should not downgrade the seam to noisy"
    )
    assert_equal(
        env.seam_summary(0x05).passable_only,
        1,
        "a successful timing retry should leave the seam classified as passable"
    )

    env.restore()
end

function tests.seam_retry_followup_relaxes_route_temp_blocks_when_they_eliminate_all_paths()
    local function has_block(blocking, key, approach)
        return type(blocking[key]) == "table" and blocking[key][approach] == true
    end
    local older_block_plans = 0
    local env = make_env({
        pathfind_no_path = function(blocking)
            if has_block(blocking, "4,4", "east") then
                older_block_plans = older_block_plans + 1
                return older_block_plans >= 2
            end
            return false
        end,
    })

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "left", {
        queued_route = true,
        movement_started = false,
    })
    env.auto_step.on_blocked(5, 4, "up", {
        queued_route = true,
        movement_started = true,
        movement_start_frame = 5,
        timeout_retries = 1,
        turn_represses = 1,
    })
    env.auto_step.on_step_complete(5, 4, "up", 5, 3, {
        queued_route = false,
        source = "auto_hold",
        input_source = "seam_retry",
    })

    local followup = env.last_direct_call()
    assert_equal(
        env.start_route_calls(),
        3,
        "seam-retry follow-up should queue a relaxed path when older temp blocks make the graph impossible"
    )
    assert_equal(
        followup.blocking["4,4"],
        nil,
        "the relaxed follow-up plan should remove older route-local timing avoids"
    )
    assert_equal(
        followup.blocking["5,3"],
        nil,
        "the crossed seam should already be clear in the relaxed follow-up plan"
    )
    assert_contains(
        table.concat(env.debug_infos(), "\n"),
        "AUTO_WALK_TEMP_BLOCK_RELAX",
        "relaxing over-constraining route-local temp blocks should be logged"
    )

    env.restore()
end

function tests.seam_retry_followup_retries_once_after_cleared_temp_block_false_negative()
    local force_followup_no_path = false
    local followup_direct_calls = 0
    local env = make_env({
        current_object = {id = "exit_1", name = "Exit", type = "exit", x = 6, y = 1},
        pathfind_to_fn = function()
            if not force_followup_no_path then
                return nil
            end
            followup_direct_calls = followup_direct_calls + 1
            if followup_direct_calls == 1 then
                return "No path found", nil, nil
            end
            return nil
        end,
    })

    env.route_manager.autowalk_to_current()
    force_followup_no_path = true
    env.auto_step.on_blocked(5, 4, "up", {
        queued_route = true,
        movement_started = true,
        movement_start_frame = 5,
        timeout_retries = 1,
        turn_represses = 1,
    })
    env.auto_step.on_step_complete(5, 4, "up", 5, 3, {
        queued_route = false,
        source = "auto_hold",
        input_source = "seam_retry",
    })

    assert_equal(
        env.start_route_calls(),
        2,
        "a cleared-temp-block seam follow-up false negative should try one refreshed route before cancelling"
    )
    assert_equal(
        followup_direct_calls,
        2,
        "the cleared-temp-block false negative should trigger one refreshed direct planning attempt"
    )
    assert_contains(
        table.concat(env.debug_infos(), "\n"),
        "AUTO_WALK_SEAM_FOLLOWUP_RETRY",
        "the refreshed seam follow-up retry should be logged"
    )
    assert_not_contains(
        table.concat(env.outputs, "\n"),
        "No path found after seam crossing",
        "a successful refreshed follow-up should not announce seam cancellation"
    )

    env.restore()
end

function tests.blocked_step_reroute_relaxes_older_route_temp_blocks_but_keeps_current_edge()
    local function has_block(blocking, key, approach)
        return type(blocking[key]) == "table" and blocking[key][approach] == true
    end
    local env = make_env({
        pathfind_no_path = function(blocking)
            return has_block(blocking, "4,4", "east")
                and has_block(blocking, "5,3", "south")
        end,
    })

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(5, 4, "left", {queued_route = true})
    env.auto_step.on_blocked(5, 4, "up", {queued_route = true})

    local relaxed = env.last_direct_call()
    assert_equal(
        env.start_route_calls(),
        3,
        "blocked-step reroute should queue a relaxed detour after dropping older temp blocks"
    )
    assert_equal(
        type(relaxed.blocking["4,4"]) == "table" and relaxed.blocking["4,4"].east or nil,
        nil,
        "blocked-step relax should clear older route-local temp blocks"
    )
    assert_equal(
        relaxed.blocking["5,3"].south,
        true,
        "blocked-step relax should keep the current failed edge blocked"
    )
    assert_contains(
        table.concat(env.debug_infos(), "\n"),
        "source=blocked_step_reroute_no_path",
        "blocked-step temp-block relaxation should be logged"
    )

    env.restore()
end

function tests.unconfirmed_reroute_blocks_accumulate_for_active_route_only()
    local target = {
        id = "exit_29_29",
        name = "Southeast Exit",
        type = "exit",
        x = 29,
        y = 29,
    }
    local env = make_env({
        start_map_id = 0x04,
        start_x = 26,
        start_y = 7,
        map_width = 30,
        map_height = 30,
        current_object = target,
        object_list = {target},
    })

    env.route_manager.autowalk_to_current()
    env.auto_step.on_blocked(26, 7, "up", {
        queued_route = true,
        movement_started = false,
    })
    local first_blocking = env.last_direct_call().blocking

    assert_equal(
        first_blocking["26,6"].south,
        true,
        "first soft reroute should block the failed northward edge for this route"
    )

    env.auto_step.on_blocked(26, 7, "right", {
        queued_route = true,
        movement_started = false,
    })
    local second_blocking = env.last_direct_call().blocking

    assert_equal(
        second_blocking["26,6"].south,
        true,
        "second soft reroute should retain the previous route-local failed edge"
    )
    assert_equal(
        second_blocking["27,7"].west,
        true,
        "second soft reroute should also include the newly failed edge"
    )
    assert_equal(
        env.route_manager.count_runtime_blocks(0x04),
        0,
        "route-local soft blocks should not promote noisy route evidence to runtime map data"
    )

    env.restore()
end

function tests.autowalk_stop_on_blocker_reports_edge_without_reroute()
    local env = make_env({pathfind_mode = "always_path"})

    env.route_manager.autowalk_to_object(
        {id = "exit_1", name = "Exit", type = "exit", x = 6, y = 1},
        {speak = true, stop_on_blocker = true})
    env.auto_step.on_blocked(5, 4, "up", {
        queued_route = true,
        movement_started = false,
    })

    assert_equal(env.start_route_calls(), 1, "blocker-hunt autowalk should not reroute after first blocker")
    assert_equal(env.inject_step_calls(), 0, "blocker-hunt autowalk should not start seam brute-force retries")
    assert_equal(
        env.route_manager.count_runtime_blocks(0x05),
        0,
        "blocker-hunt autowalk should report, not inject, runtime blockers"
    )
    assert_contains(
        table.concat(env.outputs, "\n"),
        "Auto-walk stopped at blocker from 5,4 up to 5,3",
        "blocker-hunt autowalk should announce the failed edge"
    )
    assert_contains(
        table.concat(env.outputs, "\n"),
        "add_blocked_edge:5,4,UP",
        "blocker-hunt autowalk should provide the matching runtime patch command"
    )
    local events = env.published_events()
    assert_equal(events[#events].name, "route_cancelled", "blocker-hunt stop should publish route_cancelled")
    assert_equal(events[#events].payload.reason, "stop_on_blocker", "blocker-hunt cancellation should be distinguishable")

    env.restore()
end

function tests.autowalk_stop_on_blocker_retries_timing_suspect_before_reporting()
    local env = make_env({pathfind_mode = "always_path"})

    env.route_manager.autowalk_to_object(
        {id = "exit_1", name = "Exit", type = "exit", x = 6, y = 1},
        {speak = true, stop_on_blocker = true})
    env.auto_step.on_blocked(5, 4, "up", {
        queued_route = true,
        movement_started = true,
        movement_start_frame = 1,
        timeout_retries = 0,
        turn_represses = 0,
        timing_suspect = true,
    })

    assert_equal(
        env.inject_step_calls(),
        1,
        "blocker-hunt mode should retry movement-start timeouts before reporting a patchable edge"
    )
    assert_equal(
        env.last_inject_opts() and env.last_inject_opts().source,
        "seam_retry",
        "blocker-hunt timing retries should use the same seam-retry path as normal autowalk"
    )
    assert_equal(env.start_route_calls(), 1, "timing retry should not queue a reroute before the direct retry")
    assert_not_contains(
        table.concat(env.outputs, "\n"),
        "Auto-walk stopped at blocker",
        "timing-suspect blocker-hunt steps should not announce a manual patch before retrying"
    )
    local events = env.published_events()
    assert_equal(#events, 0, "timing retry should not publish stop_on_blocker before the direct retry")

    env.restore()
end

function tests.tantegel_shrine_autowalk_avoids_high_x29_final_descent()
    local target = {
        id = "stair_29_29",
        name = "Sun Shrine Stairs and Southeast Exit",
        type = "stair",
        x = 29,
        y = 29,
    }
    local env = make_env({
        start_map_id = 0x04,
        start_x = 29,
        start_y = 3,
        map_width = 30,
        map_height = 30,
        current_object = target,
        object_list = {target},
        pathfind_to_fn = function(start_x, start_y, goal_x, goal_y, blocking)
            if goal_x ~= 29 or goal_y ~= 29 then
                return nil
            end
            if type(blocking["29,4"]) == "table" and blocking["29,4"].north == true then
                local dirs = {"west"}
                for _, dir in ipairs(repeated_dirs("south", 4)) do dirs[#dirs + 1] = dir end
                dirs[#dirs + 1] = "east"
                for _, dir in ipairs(repeated_dirs("south", 22)) do dirs[#dirs + 1] = dir end
                return "Path: 1 west, 4 south, 1 east, 22 south", "south",
                    make_path_from_dirs(start_x, start_y, dirs)
            end
            return "Path: 26 south", "south",
                make_path_from_dirs(start_x, start_y, repeated_dirs("south", 26))
        end,
    })

    local plan = env.route_manager.autowalk_to_current()
    local steps = env.last_start_route_steps()
    local replacement_call = env.last_direct_call()

    assert_equal(plan.status, "queued", "shrine autowalk should still queue after reshaping the final approach")
    assert_equal(steps[1], "left", "risky high x=29 descent should be replaced by the side approach")
    assert_equal(
        replacement_call.blocking["29,4"].north,
        true,
        "replacement planning should block only the first risky high x=29 south edge"
    )
    assert_contains(
        table.concat(env.debug_infos(), "\n"),
        "AUTO_WALK_FINAL_APPROACH_AVOID",
        "final-approach route shaping should be logged"
    )

    env.restore()
end

function tests.tantegel_shrine_lower_x29_descent_stays_available()
    local target = {
        id = "stair_29_29",
        name = "Sun Shrine Stairs and Southeast Exit",
        type = "stair",
        x = 29,
        y = 29,
    }
    local env = make_env({
        start_map_id = 0x04,
        start_x = 29,
        start_y = 7,
        map_width = 30,
        map_height = 30,
        current_object = target,
        object_list = {target},
        pathfind_to_fn = function(start_x, start_y, goal_x, goal_y)
            if goal_x ~= 29 or goal_y ~= 29 then
                return nil
            end
            return "Path: 22 south", "south",
                make_path_from_dirs(start_x, start_y, repeated_dirs("south", 22))
        end,
    })

    local plan = env.route_manager.autowalk_to_current()
    local steps = env.last_start_route_steps()

    assert_equal(plan.status, "queued", "lower x=29 shrine approach should still queue normally")
    assert_equal(#steps, 22, "lower x=29 approach should keep the direct descent")
    assert_equal(steps[1], "down", "lower x=29 approach should not be detoured")
    assert_equal(env.pathfind_calls(), 1, "non-risky lower descent should not trigger a second planning call")
    assert_not_contains(
        table.concat(env.debug_infos(), "\n"),
        "AUTO_WALK_FINAL_APPROACH_AVOID",
        "lower x=29 descent should not log final-approach avoidance"
    )

    env.restore()
end

function tests.tantegel_shrine_drift_reroute_avoids_high_x29_final_descent()
    local target = {
        id = "stair_29_29",
        name = "Sun Shrine Stairs and Southeast Exit",
        type = "stair",
        x = 29,
        y = 29,
    }
    local env = make_env({
        start_map_id = 0x04,
        start_x = 7,
        start_y = 8,
        map_width = 30,
        map_height = 30,
        current_object = target,
        object_list = {target},
        pathfind_to_fn = function(start_x, start_y, goal_x, goal_y, blocking)
            if goal_x ~= 29 or goal_y ~= 29 then
                return nil
            end
            if start_x == 29 and start_y == 3 then
                if type(blocking["29,4"]) == "table" and blocking["29,4"].north == true then
                    local dirs = {"west"}
                    for _, dir in ipairs(repeated_dirs("south", 4)) do dirs[#dirs + 1] = dir end
                    dirs[#dirs + 1] = "east"
                    for _, dir in ipairs(repeated_dirs("south", 22)) do dirs[#dirs + 1] = dir end
                    return "Path: 1 west, 4 south, 1 east, 22 south", "south",
                        make_path_from_dirs(start_x, start_y, dirs)
                end
                return "Path: 26 south", "south",
                    make_path_from_dirs(start_x, start_y, repeated_dirs("south", 26))
            end
            return "Path: 1 east", "east",
                make_path_from_dirs(start_x, start_y, {"east"})
        end,
    })

    env.route_manager.autowalk_to_current()
    env.set_position(0x04, 29, 3)
    env.auto_step.on_route_cancelled({
        reason = "route_drift_off_path",
        current_x = 29,
        current_y = 3,
        source = "test_drift",
    })

    local steps = env.last_start_route_steps()
    assert_equal(env.start_route_calls(), 2, "drift reroute should queue a follow-up route")
    assert_equal(steps[1], "left", "drift reroute should avoid the high x=29 final descent")
    assert_contains(
        table.concat(env.debug_infos(), "\n"),
        "context=route_drift_reroute",
        "drift-reroute final-approach avoidance should include the reroute context"
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

function tests.rimuldar_destination_seam_uses_standard_south_facing_arrival()
    local merchant = {
        id = "npc_12",
        name = "Magic Key Merchant",
        type = "npc",
        x = 4,
        y = 7,
        interaction_x = 4,
        interaction_y = 5,
        interaction_face_dir = "south",
    }
    local env = make_env({
        start_map_id = 0x0B,
        start_x = 4,
        start_y = 4,
        current_object = merchant,
        object_list = {merchant},
        config_values = {
            auto_walk_npc_hold_frames = "0",
            auto_walk_face_target_frames = "1",
        },
        pathfind_to_fn = function(start_x, start_y)
            if start_x == 4 and start_y == 4 then
                return "Path: 1 south", "south", {
                    {x = 4, y = 5, direction = "south"},
                }
            end
            if start_x == 4 and start_y == 5 then
                return "Already there", "south", {}
            end
        end,
    })

    local queued = env.route_manager.autowalk_to_object(merchant)
    assert_equal(queued.status, "queued", "merchant seam test should queue its opening step")
    env.auto_step.on_blocked(4, 4, "down", {
        queued_route = true,
        movement_started = true,
        movement_start_frame = 5,
    })
    env.publish_event("route_step_completed", {
        from_x = 4, from_y = 4, dir = "down", to_x = 4, to_y = 5,
        source = "auto_hold", input_source = "seam_retry", queued_route = false,
    })
    env.auto_step.on_step_complete(4, 4, "down", 4, 5, {
        queued_route = false,
        source = "auto_hold",
        input_source = "seam_retry",
    })

    local step_index = nil
    local route_index = nil
    local route_count = 0
    for index, event in ipairs(env.published_events()) do
        if event.name == "route_step_completed" then step_index = index end
        if event.name == "route_completed" then
            route_index = index
            route_count = route_count + 1
        end
    end

    assert_equal(env.inject_step_calls(), 1, "blocked route should use one seam retry")
    assert_equal(env.start_route_calls(), 1, "destination seam should not queue an empty follow-up")
    assert_equal(route_count, 1, "destination seam should publish route completion exactly once")
    assert_truthy(step_index and route_index and step_index < route_index,
        "tile completion should precede route completion")
    assert_equal(env.suppress_direction_tracking_calls(), 1,
        "standard seam arrival should queue safe facing suppression")
    env.route_manager.apply_npc_freeze()
    assert_equal(env.joypad_sets[#env.joypad_sets].buttons.down, true,
        "destination seam arrival should face south toward the seller")
    assert_contains(table.concat(env.outputs, "\n"),
        "Auto-walk complete. Arrived at Magic Key Merchant",
        "destination seam should use standard completion speech")

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
    assert_equal(
        env.last_start_route_opts().initial_settle_frames,
        16,
        "route drift reroute should wait for movement state to settle before the next step"
    )
    assert_equal(
        env.last_start_route_opts().start_x,
        5,
        "route drift reroute should pass the planned path start x through to auto_step"
    )
    assert_equal(
        env.last_start_route_opts().start_y,
        4,
        "route drift reroute should pass the planned path start y through to auto_step"
    )

    env.restore()
end

function tests.seam_retry_completion_does_not_reset_route_drift_limit()
    local env = make_env()

    env.route_manager.autowalk_to_current()

    for i = 1, 6 do
        env.auto_step.on_route_cancelled({
            reason = "route_drift_off_path",
            current_x = 8,
            current_y = 16 + i,
            source = "route_settle_catchup",
        })
        env.auto_step.on_step_complete(8, 16 + i, "up", 8, 15 + i, {
            queued_route = false,
            source = "seam_retry",
        })
    end

    env.auto_step.on_route_cancelled({
        reason = "route_drift_off_path",
        current_x = 8,
        current_y = 23,
        source = "route_settle_catchup",
    })

    local saw_limit = false
    for _, event in ipairs(env.published_events()) do
        local payload = event.payload or {}
        if event.name == "route_cancelled"
           and payload.reason == "route_drift_reroute_limit"
           and payload.current_x == 8
           and payload.current_y == 23 then
            saw_limit = true
            break
        end
    end

    assert_equal(
        saw_limit,
        true,
        "route drift reroute guard should still fire when only seam-retry steps complete between drifts"
    )
    assert_contains(
        table.concat(env.outputs, "\n"),
        "Movement drift did not settle",
        "route drift limit should announce cancellation"
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
    assert_equal(env.memory_writes[1].value, 0x80, "parking should move mobile NPC X to the ROM-inactive coordinate")
    assert_equal(env.memory_writes[2].address, 1, "parking should write the mobile non-target slot Y")
    assert_equal(env.memory_writes[2].value, 0x60, "parking should move mobile NPC Y to the ROM-inactive coordinate")
    assert_equal(#env.memory_writes, 2, "parking should not write stationary or selected target NPC slots")

    env.auto_step.on_route_complete()

    assert_equal(env.route_manager.is_autowalk_npc_parking_active(), false, "route completion should release mobile NPC parking")
    assert_equal(env.memory_writes[3].address, 0, "restore should write the original mobile NPC X")
    assert_equal(env.memory_writes[3].value, 0x80 + 4, "restore should put the mobile NPC X back")
    assert_equal(env.memory_writes[4].address, 1, "restore should write the original mobile NPC Y")
    assert_equal(env.memory_writes[4].value, 0x60 + 4, "restore should put the mobile NPC Y back")

    env.restore()
end

function tests.autowalk_skips_mobile_parking_when_map_origin_is_walkable()
    local env = make_env({
        start_map_id = 0x0B,
        walkable_origin = true,
        config_values = {
            auto_walk_park_mobile_npcs = "true",
            auto_walk_npc_hold_frames = "0",
        },
        memory_values = {
            [0] = 0x80 + 4,
            [1] = 0x60 + 4,
            [2] = 0x12,
        },
    })

    local plan = env.route_manager.autowalk_to_current()
    local logs = table.concat(env.debug_infos(), "\n")

    assert_equal(plan.status, "queued", "walkable-origin route should still queue")
    assert_equal(plan.npc_mode, "live_npcs", "walkable-origin route should use live NPC blocking")
    assert_equal(
        env.route_manager.get_active_route_npc_mode(),
        "live_npcs",
        "queued route should retain the safe live-NPC mode"
    )
    assert_equal(
        env.route_manager.is_autowalk_npc_parking_active(),
        false,
        "walkable-origin route must not activate coordinate parking"
    )
    assert_equal(#env.memory_writes, 0, "walkable-origin refusal must not write NPC RAM")
    assert_contains(
        logs,
        "AUTO_WALK_NPC_PARK_SKIP map=0x0B reason=walkable_origin origin=(0,0)",
        "parking refusal should name the collision reason"
    )

    env.restore()
end

function tests.parked_autowalk_plans_after_mobile_npc_parking()
    local env = make_env({
        is_bizhawk = true,
        pathfind_mode = "block_sensitive",
        pathfind_block_key = "5,2",
        blocking_positions_from_memory = true,
        config_values = {
            auto_walk_park_mobile_npcs = "true",
        },
        memory_values = {
            [0] = 0x80 + 5,
            [1] = 0x60 + 2,
            [2] = 0x12,
        },
    })

    local plan = env.route_manager.autowalk_to_current()
    local direct = env.last_direct_call()

    assert_equal(plan.status, "queued", "parked autowalk should plan from the post-park NPC snapshot")
    assert_equal(plan.npc_mode, "park_mobile_npcs", "initial autowalk plan should record the parked NPC mode")
    assert_equal(direct.blocking["5,2"], nil, "mobile NPC's original tile should not block the parked plan")
    assert_equal(env.route_manager.get_active_route_npc_mode(), "park_mobile_npcs", "queued route should remember the parked NPC mode")
    assert_contains(
        table.concat(env.debug_infos(), "\n"),
        "npc_mode=park_mobile_npcs",
        "route planning logs should expose the parked NPC mode"
    )

    env.restore()
end

function tests.parked_autowalk_reroute_keeps_mobile_npcs_parked()
    local env = make_env({
        is_bizhawk = true,
        pathfind_mode = "block_sensitive",
        pathfind_block_key = "5,2",
        blocking_positions_from_memory = true,
        config_values = {
            auto_walk_park_mobile_npcs = "true",
        },
        memory_values = {
            [0] = 0x80 + 5,
            [1] = 0x60 + 2,
            [2] = 0x12,
        },
    })

    env.route_manager.autowalk_to_current()
    env.memory_values[0] = 0x80 + 5
    env.memory_values[1] = 0x60 + 2
    env.auto_step.on_blocked(5, 4, "up")

    local direct = env.last_direct_call()
    assert_equal(env.start_route_calls(), 2, "blocked parked autowalk should reroute successfully")
    assert_equal(direct.blocking["5,2"], nil, "reroute should rebuild blocking after reapplying mobile NPC parking")
    assert_contains(
        table.concat(env.debug_infos(), "\n"),
        "context=blocked_step_reroute",
        "reroute planning should be logged with its route context"
    )
    assert_contains(
        table.concat(env.debug_infos(), "\n"),
        "npc_mode=park_mobile_npcs",
        "reroute planning should keep the active parked NPC mode"
    )

    env.restore()
end

function tests.parked_autowalk_reactively_parks_new_mobile_npc_blocker()
    local env = make_env({
        is_bizhawk = true,
        pathfind_mode = "block_sensitive",
        pathfind_block_key = "5,3",
        blocking_positions_from_memory = true,
        config_values = {
            auto_walk_park_mobile_npcs = "true",
        },
    })

    env.route_manager.autowalk_to_current()
    env.memory_values[0] = 0x80 + 5
    env.memory_values[1] = 0x60 + 3
    env.memory_values[2] = 0x12
    env.auto_step.on_blocked(5, 4, "up")

    local direct = env.last_direct_call()
    local logs = table.concat(env.debug_infos(), "\n")
    assert_equal(env.start_route_calls(), 2, "blocked parked autowalk should reroute after reactively parking a new mobile NPC")
    assert_equal(direct.blocking["5,3"], nil, "reactively parked mobile NPC should not remain in the reroute blocking table")
    assert_equal(env.memory_writes[1].value, 0x80, "reactive parking should move the blocking NPC X to the ROM-inactive coordinate")
    assert_equal(env.memory_writes[2].value, 0x60, "reactive parking should move the blocking NPC Y to the ROM-inactive coordinate")
    assert_contains(logs, "AUTO_WALK_NPC_BLOCK", "reactive parking should still log the NPC blocker")
    assert_contains(logs, "kind=mobile", "NPC blocker log should classify mobile blockers")
    assert_contains(logs, "AUTO_WALK_NPC_REACTIVE_PARK", "reactive parking should be visible in route logs")

    env.restore()
end

function tests.parked_autowalk_reactive_parking_validates_raw_npc_slot()
    local expose_bad_slot = false
    local env = make_env({
        is_bizhawk = true,
        pathfind_mode = "block_sensitive",
        pathfind_block_key = "5,3",
        config_values = {
            auto_walk_park_mobile_npcs = "true",
        },
        blocking_positions_fn = function()
            if not expose_bad_slot then
                return {}
            end
            return {
                {
                    id = "npc_0",
                    name = "Guard",
                    x = 5,
                    y = 3,
                    slot = 39,
                    movement = 0x12,
                },
            }
        end,
    })

    env.route_manager.autowalk_to_current()
    env.memory_values[0] = 0x80 + 5
    env.memory_values[1] = 0x60 + 3
    env.memory_values[2] = 0x12
    env.memory_values[117] = 0x80 + 5
    env.memory_values[118] = 0x60 + 3
    env.memory_values[119] = 0x12
    expose_bad_slot = true
    env.auto_step.on_blocked(5, 4, "up")

    assert_equal(env.memory_writes[1].address, 0, "reactive parking should use the validated NPC id slot")
    assert_equal(env.memory_writes[2].address, 1, "reactive parking should use the validated NPC id slot y byte")
    for _, write in ipairs(env.memory_writes) do
        assert_truthy(
            write.address < 117 or write.address > 119,
            "reactive parking should not trust an out-of-range raw NPC slot"
        )
    end

    env.restore()
end

function tests.parked_autowalk_reactive_parking_refuses_unidentified_bad_slot()
    local expose_bad_slot = false
    local env = make_env({
        is_bizhawk = true,
        pathfind_mode = "block_sensitive",
        pathfind_block_key = "5,3",
        config_values = {
            auto_walk_park_mobile_npcs = "true",
        },
        blocking_positions_fn = function()
            if not expose_bad_slot then
                return {}
            end
            return {
                {
                    name = "Unknown NPC",
                    x = 5,
                    y = 3,
                    slot = 39,
                    movement = 0x12,
                },
            }
        end,
    })

    env.route_manager.autowalk_to_current()
    env.memory_values[117] = 0x80 + 5
    env.memory_values[118] = 0x60 + 3
    env.memory_values[119] = 0x12
    expose_bad_slot = true
    env.auto_step.on_blocked(5, 4, "up")

    assert_equal(#env.memory_writes, 0, "unidentified out-of-range NPC slots should not write RAM")
    assert_not_contains(
        table.concat(env.debug_infos(), "\n"),
        "AUTO_WALK_NPC_REACTIVE_PARK",
        "unidentified out-of-range NPC slots should not be parked"
    )

    env.restore()
end

function tests.parked_autowalk_stationary_npc_reroute_uses_cautious_message()
    local env = make_env({
        is_bizhawk = true,
        pathfind_mode = "block_sensitive",
        pathfind_block_key = "5,3",
        blocking_positions_from_memory = true,
        config_values = {
            auto_walk_park_mobile_npcs = "true",
        },
    })

    env.route_manager.autowalk_to_current()
    env.memory_values[0] = 0x80 + 5
    env.memory_values[1] = 0x60 + 3
    env.memory_values[2] = 0x00
    env.auto_step.on_blocked(5, 4, "up")

    local output = table.concat(env.outputs, "\n")
    local logs = table.concat(env.debug_infos(), "\n")
    assert_contains(logs, "kind=stationary", "NPC blocker log should classify stationary blockers")
    assert_contains(
        output,
        "Route may be blocked by a stationary NPC",
        "stationary reroute blockers should not be announced as roaming NPC movement"
    )
    assert_not_contains(
        output,
        "Route blocked by NPC movement",
        "stationary reroute blockers should avoid the mobile-NPC wording"
    )

    env.restore()
end

function tests.parked_autowalk_npc_block_check_ignores_parked_mobile_npc()
    local env = make_env({
        is_bizhawk = true,
        blocking_positions_from_memory = true,
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
    env.memory_values[0] = 0x80 + 5
    env.memory_values[1] = 0x60 + 3
    env.auto_step.on_blocked(5, 4, "up")

    assert_not_contains(
        table.concat(env.debug_infos(), "\n"),
        "AUTO_WALK_NPC_BLOCK",
        "parked mobile NPCs should not be reported as live NPC route blockers"
    )
    assert_not_contains(
        table.concat(env.outputs, "\n"),
        "Route blocked by NPC movement",
        "parked mobile NPCs should not surface the temporary NPC-clutter message"
    )

    env.restore()
end

function tests.parked_autowalk_still_respects_stationary_npc_blocker()
    local env = make_env({
        is_bizhawk = true,
        pathfind_mode = "block_sensitive",
        pathfind_block_key = "5,2",
        blocking_positions_from_memory = true,
        config_values = {
            auto_walk_park_mobile_npcs = "true",
        },
        memory_values = {
            [0] = 0x80 + 5,
            [1] = 0x60 + 2,
            [2] = 0x00,
        },
    })

    local plan = env.route_manager.autowalk_to_current()
    local direct = env.last_direct_call()

    assert_equal(plan.status, "no_path", "stationary NPC blockers should still be honored")
    assert_equal(direct.blocking["5,2"], "npc", "stationary NPC should remain in the parked plan blocking table")

    env.restore()
end

function tests.parked_autowalk_still_respects_selected_target_npc()
    local env = make_env({
        is_bizhawk = true,
        pathfind_mode = "block_sensitive",
        pathfind_block_key = "6,1",
        blocking_positions_from_memory = true,
        current_object = {id = "npc_0", name = "Merchant", type = "npc", x = 6, y = 1},
        config_values = {
            auto_walk_park_mobile_npcs = "true",
            auto_walk_npc_hold_frames = "0",
        },
        memory_values = {
            [0] = 0x80 + 6,
            [1] = 0x60 + 1,
            [2] = 0x12,
        },
    })

    env.route_manager.autowalk_to_current()
    local adjacent = env.last_adjacent_call()

    assert_equal(#env.memory_writes, 0, "selected target NPC should be exempt from mobile parking")
    assert_equal(adjacent.blocking["6,1"], "npc", "selected target NPC should still participate in the planning snapshot")

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

function tests.autowalk_parking_merges_pending_deferred_restore_with_new_mobile_parking()
    local env = make_env({
        is_bizhawk = true,
        pathfind_mode = "block_sensitive",
        pathfind_block_key = "7,4",
        blocking_positions_from_memory = true,
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
    local plan = env.route_manager.autowalk_to_current()
    local direct = env.last_direct_call()

    assert_equal(plan.status, "queued", "new autowalk should still plan while a deferred restore is pending")
    assert_equal(direct.blocking["7,4"], nil, "new mobile NPCs should be parked even when a deferred restore is pending")
    assert_equal(env.route_manager.is_autowalk_npc_parking_active(), true, "new autowalk should keep the deferred restore in the active parking state")
    assert_equal(#env.memory_writes, 4, "new autowalk should park newly scanned mobile NPCs while preserving the deferred one")
    assert_equal(env.memory_writes[3].value, 0x80, "new mobile NPC X should be parked at the ROM-inactive coordinate")
    assert_equal(env.memory_writes[4].value, 0x60, "new mobile NPC Y should be parked at the ROM-inactive coordinate")
    assert_contains(
        table.concat(env.debug_infos(), "\n"),
        "AUTO_WALK_NPC_PARK_START merged_pending_restore slots=1",
        "parking logs should expose pending restore merging"
    )

    env.set_position(0x05, 5, 2)
    env.auto_step.on_route_complete()

    assert_equal(env.route_manager.is_autowalk_npc_parking_active(), false, "pending restore should still complete after the player moves")
    assert_write_set(env.memory_writes, 5, {
        [0] = 0x80 + 5,
        [1] = 0x60 + 3,
        [3] = 0x80 + 7,
        [4] = 0x60 + 4,
    }, "pending restore should preserve original NPC coordinates and restore the new parked NPC")

    env.restore()
end

function tests.autowalk_parking_throttles_deferred_restore_retry_logs()
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

    local function retry_log_count()
        local count = 0
        for _, line in ipairs(env.debug_infos()) do
            if line:find("deferred restore retry", 1, true) then
                count = count + 1
            end
        end
        return count
    end

    env.route_manager.autowalk_to_current()
    env.set_position(0x05, 5, 3)
    env.auto_step.on_route_complete()

    local before = retry_log_count()
    env.route_manager.apply_npc_freeze()
    local after_first = retry_log_count()
    env.route_manager.apply_npc_freeze()
    local after_second = retry_log_count()

    assert_equal(after_first, before + 1, "first deferred retry should be logged")
    assert_equal(after_second, after_first, "immediate second deferred retry should be throttled")
    assert_equal(env.route_manager.is_autowalk_npc_parking_active(), true, "restore should remain pending while player occupies the original NPC tile")

    env.set_position(0x05, 5, 2)
    env.route_manager.apply_npc_freeze()

    assert_equal(env.route_manager.is_autowalk_npc_parking_active(), false, "pending restore should complete immediately once the player leaves the tile")
    assert_equal(env.memory_writes[#env.memory_writes - 1].value, 0x80 + 5, "deferred restore should put the NPC X back")
    assert_equal(env.memory_writes[#env.memory_writes].value, 0x60 + 3, "deferred restore should put the NPC Y back")

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
    assert_equal(env.memory_writes[1].value, 0x80, "no-path setup should park the mobile NPC at the ROM-inactive X coordinate")
    assert_equal(env.memory_writes[2].value, 0x60, "no-path setup should park the mobile NPC at the ROM-inactive Y coordinate")
    assert_equal(env.memory_writes[3].value, 0x80 + 4, "no-path cleanup should restore the mobile NPC X")
    assert_equal(env.memory_writes[4].value, 0x60 + 4, "no-path cleanup should restore the mobile NPC Y")

    env.restore()
end

function tests.manual_park_npcs_command_parks_all_npcs_and_restores()
    local env = make_env({
        memory_values = {
            [0] = 0x80 + 4,  [1] = 0x60 + 4,  [2] = 0x12, -- mobile
            [3] = 0x80 + 5,  [4] = 0x60 + 5,  [5] = 0x00, -- stationary
        },
    })

    env.route_manager.register_debug_commands(function() return 0x05 end)
    env.invoke_command("park_npcs")

    assert_equal(env.route_manager.is_autowalk_npc_parking_active(), true, "manual park should leave parking active")
    assert_equal(#env.memory_writes, 4, "manual full park should move mobile and stationary NPCs")
    assert_equal(env.memory_writes[1].value, 0x80, "manual park should move the first NPC X to the ROM-inactive coordinate")
    assert_equal(env.memory_writes[2].value, 0x60, "manual park should move the first NPC Y to the ROM-inactive coordinate")
    assert_equal(env.memory_writes[3].value, 0x80, "manual park should move the second NPC X to the ROM-inactive coordinate")
    assert_equal(env.memory_writes[4].value, 0x60, "manual park should move the second NPC Y to the ROM-inactive coordinate")
    assert_contains(table.concat(env.outputs, "\n"), "Parked 2 all NPC slot(s).", "manual park should announce parked slot count")

    env.invoke_command("restore_parked_npcs")

    assert_equal(env.route_manager.is_autowalk_npc_parking_active(), false, "manual restore should clear parking when the player is not occupying the original tile")
    assert_equal(#env.memory_writes, 8, "manual restore should write both NPCs back")
    assert_write_set(env.memory_writes, 5, {
        [0] = 0x80 + 4,
        [1] = 0x60 + 4,
        [3] = 0x80 + 5,
        [4] = 0x60 + 5,
    }, "manual restore should put both NPCs back")
    assert_contains(table.concat(env.outputs, "\n"), "Parked NPCs restored.", "manual restore should announce success")

    env.restore()
end

function tests.manual_park_npcs_mobile_mode_skips_stationary_slots()
    local env = make_env({
        memory_values = {
            [0] = 0x80 + 4,  [1] = 0x60 + 4,  [2] = 0x12, -- mobile
            [3] = 0x80 + 5,  [4] = 0x60 + 5,  [5] = 0x00, -- stationary
        },
    })

    env.route_manager.register_debug_commands(function() return 0x05 end)
    env.invoke_command("park_npcs", "mobile")

    assert_equal(env.route_manager.is_autowalk_npc_parking_active(), true, "manual mobile park should leave parking active")
    assert_equal(#env.memory_writes, 2, "manual mobile park should move only the mobile NPC")
    assert_equal(env.memory_writes[1].address, 0, "manual mobile park should only write the moving NPC X")
    assert_equal(env.memory_writes[2].address, 1, "manual mobile park should only write the moving NPC Y")
    assert_contains(table.concat(env.outputs, "\n"), "Parked 1 mobile NPC slot(s).", "manual mobile park should announce its mode")

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

function tests.overworld_continuous_autowalk_suppresses_segment_step_progress()
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 110,
        start_y = 76,
        overworld_active_route_id = "magic_temple",
        config_values = {
            overworld_auto_walk_continuous = "true",
        },
        overworld_segment = {
            route = {id = "magic_temple", title = "Magic Temple"},
            waypoint = {name = "Southern road east wall", x = 110, y = 86},
            index = 6,
            steps = {"down", "down", "down", "down", "down", "down", "down", "down", "down", "down"},
            message = "Auto-walk to Southern road east wall.",
            object_id = "route_magic_temple_6",
        },
    })

    env.route_manager.autowalk_to_current()
    for i = 1, 6 do
        env.auto_step.on_step_complete(110, 75 + i, "down", 110, 76 + i, {
            queued_route = true,
            source = "test",
        })
    end

    assert_not_contains(
        table.concat(env.outputs, "\n"),
        "Auto-walk 6 of 10 steps",
        "continuous mode should not present per-segment counts as journey progress")

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

function tests.target_npc_hold_uses_explicit_hold_coordinates()
    local env = make_env({
        is_bizhawk = true,
        config_values = {
            auto_walk_npc_hold_frames = "0",
        },
        memory_values = {
            [6] = 0x80 + 24,
            [7] = 0x60 + 5,
            [8] = 0x22,
        },
    })

    local ok = env.route_manager.hold_target_npc({
        name = "Fairy Water Merchant",
        type = "npc",
        id = "npc_2",
        x = 24,
        y = 3,
        target_hold_x = 24,
        target_hold_y = 4,
    }, "fixed service trigger", 3)

    assert_equal(ok, true, "explicit hold coordinates should still start the NPC hold")
    assert_equal(env.memory_writes[1].address, 7, "explicit hold should write the target slot Y byte")
    assert_equal(env.memory_writes[1].value, 0x60 + 4, "explicit hold should pin target hold Y instead of object Y")
    assert_equal(#env.memory_writes, 1, "explicit hold should skip unchanged X and movement byte writes")

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

function tests.player_path_preview_masks_walkability_outside_dungeon_light()
    local target = {id = "stair_6_4", name = "Stairs", type = "stair", x = 6, y = 4}
    local env = make_env({
        start_map_id = 0x1C,
        start_x = 5,
        start_y = 4,
        current_object = target,
        object_list = {target},
        snapshot_terrain = 0x20,
        snapshot_light_radius = 3,
        config_values = {
            darkness_navigation_limits = "authentic",
        },
    })

    env.route_manager.pathfind_to_current()

    local call = env.last_direct_call()
    local walkability = call and call.opts and call.opts.walkability_snapshot
    assert_equal(walkability ~= nil, true, "ordinary dungeon preview should receive a light-limited map")
    assert_equal(walkability[4][4], true, "cell one tile west should remain visible")
    assert_equal(walkability[4][5], true, "hero cell should remain visible")
    assert_equal(walkability[4][6], true, "cell one tile east should remain visible")
    assert_equal(walkability[4][7], false, "cell two tiles east should be hidden")
    assert_equal(walkability[2][5], false, "cell two tiles north should be hidden")

    env.restore()
end

function tests.player_can_disable_darkness_navigation_limits()
    local target = {id = "stair_7_4", name = "Stairs", type = "stair", x = 7, y = 4}
    local env = make_env({
        start_map_id = 0x1C,
        start_x = 5,
        start_y = 4,
        current_object = target,
        object_list = {target},
        snapshot_terrain = 0x20,
        snapshot_light_radius = 1,
        config_values = {
            darkness_navigation_limits = "false",
        },
    })

    env.route_manager.pathfind_to_current()

    local call = env.last_direct_call()
    assert_equal(
        call and call.opts and call.opts.walkability_snapshot,
        nil,
        "the opt-out should restore full decoded path planning")
    assert_equal(
        call and call.opts and call.opts.darkness_visibility,
        nil,
        "the opt-out should not label failures as limited visibility")

    env.restore()
end

function tests.autowalk_rechecks_darkness_before_each_queued_step()
    local target = {id = "stair_6_4", name = "Stairs", type = "stair", x = 6, y = 4}
    local env = make_env({
        start_map_id = 0x1C,
        start_x = 5,
        start_y = 4,
        current_object = target,
        object_list = {target},
        snapshot_terrain = 0x20,
        snapshot_light_radius = 3,
        config_values = {
            darkness_navigation_limits = "authentic",
        },
    })

    env.route_manager.autowalk_to_current()

    local route_opts = env.last_start_route_opts()
    assert_equal(type(route_opts and route_opts.step_guard), "function",
        "ordinary dungeon auto-walk should install a live darkness guard")
    local allowed = route_opts.step_guard({
        current_x = 5,
        current_y = 4,
        to_x = 5,
        to_y = 3,
        dir = "up",
        step_index = 1,
        remaining_path = {
            {x = 5, y = 3, dir = "up", step_index = 1},
        },
    })
    assert_equal(allowed, true, "a step and target inside the current light should remain allowed")

    local tail_allowed, tail_cancel = route_opts.step_guard({
        current_x = 5,
        current_y = 4,
        to_x = 5,
        to_y = 3,
        dir = "up",
        step_index = 1,
        remaining_path = {
            {x = 5, y = 3, dir = "up", step_index = 1},
            {x = 5, y = 2, dir = "up", step_index = 2},
        },
    })
    assert_equal(tail_allowed, false,
        "auto-walk should not retain a decoded route tail beyond current light")
    assert_equal(tail_cancel.hidden, "remaining_route",
        "the cancellation should identify a hidden queued route tail")

    env.snapshot.light_radius = 1
    local still_allowed, cancel_data = route_opts.step_guard({
        current_x = 5,
        current_y = 4,
        to_x = 5,
        to_y = 3,
        dir = "up",
        step_index = 1,
        remaining_path = {
            {x = 5, y = 3, dir = "up", step_index = 1},
        },
    })
    assert_equal(still_allowed, false, "auto-walk should stop when the route leaves current light")
    assert_equal(cancel_data.reason, "darkness_visibility_boundary",
        "darkness stop should have a structured cancellation reason")
    assert_equal(cancel_data.hidden, "next_step",
        "the cancellation should identify the immediately hidden step")

    env.auto_step.on_route_cancelled(cancel_data)
    assert_contains(table.concat(env.warning_outputs, "\n"),
        "remaining route is outside the current light",
        "the player should hear why auto-walk stopped")

    env.restore()
end

function tests.darkness_autowalk_guard_allows_configured_unrestricted_navigation()
    local target = {id = "stair_7_4", name = "Stairs", type = "stair", x = 7, y = 4}
    local env = make_env({
        start_map_id = 0x1C,
        start_x = 5,
        start_y = 4,
        current_object = target,
        object_list = {target},
        snapshot_terrain = 0x20,
        snapshot_light_radius = 1,
        config_values = {
            darkness_navigation_limits = "false",
        },
    })

    env.route_manager.autowalk_to_current()

    local route_opts = env.last_start_route_opts()
    assert_equal(type(route_opts and route_opts.step_guard), "function",
        "the live guard should remain installed so config reloads apply during a route")
    local allowed = route_opts.step_guard({
        current_x = 5,
        current_y = 4,
        to_x = 5,
        to_y = 3,
        dir = "up",
        step_index = 1,
        remaining_path = {
            {x = 5, y = 3, dir = "up", step_index = 1},
        },
    })
    assert_equal(allowed, true,
        "the darkness opt-out should keep queued auto-walk unrestricted")

    env.restore()
end

function tests.balanced_autowalk_runs_while_lit_then_stops_when_light_expires()
    local target = {id = "stair_7_4", name = "Stairs", type = "stair", x = 7, y = 4}
    local env = make_env({
        start_map_id = 0x1C,
        start_x = 5,
        start_y = 4,
        current_object = target,
        object_list = {target},
        snapshot_terrain = 0x20,
        snapshot_light_radius = 3,
        config_values = {
            darkness_navigation_limits = "balanced",
        },
    })

    env.route_manager.autowalk_to_current()

    local call = env.last_direct_call()
    assert_equal(call and call.opts and call.opts.walkability_snapshot, nil,
        "balanced mode should plan against the full decoded dungeon while lit")
    local route_opts = env.last_start_route_opts()
    local step = {
        current_x = 5,
        current_y = 4,
        to_x = 6,
        to_y = 4,
        dir = "right",
        step_index = 1,
        remaining_path = {
            {x = 6, y = 4, dir = "right", step_index = 1},
            {x = 7, y = 4, dir = "right", step_index = 2},
        },
    }
    assert_equal(route_opts.step_guard(step), true,
        "balanced mode should allow the complete route while light is present")

    env.snapshot.light_radius = 1
    local allowed, cancel_data = route_opts.step_guard(step)
    assert_equal(allowed, false, "balanced auto-walk should stop when light expires")
    assert_equal(cancel_data.reason, "darkness_visibility_boundary",
        "balanced cutoff should use the normal structured darkness reason")
    assert_contains(cancel_data.message, "use a Torch or cast Radiant",
        "balanced cutoff should explain how to restore navigation")
    env.auto_step.on_route_cancelled(cancel_data)
    assert_contains(table.concat(env.warning_outputs, "\n"), "use a Torch or cast Radiant",
        "the balanced recovery explanation should reach player-facing warning speech")

    env.restore()
end

function tests.darkness_policy_is_preserved_for_drift_reroutes()
    local target = {id = "stair_5_3", name = "Stairs", type = "stair", x = 5, y = 3}
    local env = make_env({
        start_map_id = 0x1C,
        start_x = 5,
        start_y = 4,
        current_object = target,
        object_list = {target},
        snapshot_terrain = 0x20,
        snapshot_light_radius = 3,
        config_values = {
            darkness_navigation_limits = "authentic",
        },
    })

    env.route_manager.autowalk_to_current()
    env.auto_step.on_route_cancelled({
        reason = "route_drift_off_path",
        current_x = 5,
        current_y = 4,
        source = "test",
    })

    local call = env.last_direct_call()
    assert_equal(call and call.opts and call.opts.darkness_visibility ~= nil, true,
        "drift reroute planning should retain the active darkness mask")
    assert_equal(type(env.last_start_route_opts().step_guard), "function",
        "drift reroute execution should retain the live darkness guard")

    env.restore()
end

function tests.visible_area_report_uses_physical_light_even_when_navigation_is_unrestricted()
    local env = make_env({
        start_map_id = 0x1C,
        start_x = 5,
        start_y = 4,
        snapshot_terrain = 0x20,
        snapshot_light_radius = 3,
        config_values = {
            darkness_navigation_limits = "false",
        },
        object_list = {
            {id = "stair_visible", name = "Visible stairs", type = "stair", x = 6, y = 4},
            {id = "chest_hidden", name = "Hidden chest", type = "chest", x = 7, y = 4},
        },
    })

    local report = env.route_manager.describe_visible_area()

    assert_contains(report, "Navigation assistance is unrestricted by darkness",
        "the report should disclose the opt-out")
    assert_contains(report, "Visible stairs", "the report should include an object inside the light")
    assert_not_contains(report, "Hidden chest", "the report must not reveal an object outside the light")

    env.restore()
end

function tests.explicit_developer_plan_remains_unrestricted_in_darkness()
    local target = {id = "stair_6_4", name = "Stairs", type = "stair", x = 6, y = 4}
    local env = make_env({
        start_map_id = 0x1C,
        start_x = 5,
        start_y = 4,
        current_object = target,
        object_list = {target},
        snapshot_terrain = 0x20,
        snapshot_light_radius = 1,
    })

    env.route_manager.plan_path_to_object(target, {})

    local call = env.last_direct_call()
    assert_equal(
        call and call.opts and call.opts.walkability_snapshot,
        nil,
        "explicit developer planning should retain the full decoded map unless visibility is requested")

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
