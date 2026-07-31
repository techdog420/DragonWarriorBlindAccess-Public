-- test_hotkeys.lua
-- Regression tests for hotkey-side object navigation speech coalescing.

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
    local frame = 0
    local selected = 0
    local outputs = {}
    local pathfind_calls = 0
    local autowalk_calls = 0
    local freeze_calls = 0
    local visited_calls = 0
    local route_status_calls = 0
    local route_start_calls = 0
    local route_status_opts = {}
    local route_guidance_opts = {}
    local pathability_filter_calls = 0
    local pathability_refresh_calls = 0
    local teleport_modes = {}
    local teleport_requests = {}
    local describe_calls = {}
    local route_start_objects = {}
    local focused_route_ids = {}
    local object_refresh_calls = 0
    local object_refresh_request_calls = 0
    local object_cache_refresh_calls = 0
    local live_npc_refresh_calls = 0
    local filter_name = options.filter_name or "NPCs"
    local all_filter_calls = 0
    local debug_errors = {}
    local input_suppress_calls = 0
    local auto_step_suppress_calls = {}
    local object_count = options.object_count or 1
    local delay = options.delay
    if delay == nil then delay = 2 end
    local original_memory = _G.memory
    local original_dw_qol_state = _G.DW_QOL_STATE

    local module_names = {
        "addresses",
        "auto_step",
        "chars",
        "config",
        "debug_tools",
        "emulator_compat",
        "game_snapshot",
        "hotkeys",
        "items",
        "key_combo",
        "map_reader",
        "menu",
        "navigation",
        "objects",
        "overworld_routes",
        "route_manager",
        "text",
        "tolk",
    }

    for _, name in ipairs(module_names) do
        save_module(name)
        package.loaded[name] = nil
    end

    local settings = {
        key_position = "Shift+W|F17",
        key_hp = "Shift+H|F19",
        key_level = "Shift+I",
        key_gold = "Shift+G|F20",
        key_experience = "Shift+E",
        key_stats = "Shift+R",
        key_screen_text = "Shift+T",
        key_diag_cursor = "Ctrl+M",
        key_diag_ppu_dump = "Ctrl+D",
        key_diag_title = "Ctrl+Y",
        key_diag_tiles = "Ctrl+N",
        key_freeze_npcs = "Shift+F",
        key_object_prev = "J|F13",
        key_object_current = "K|F14",
        key_object_next = "L|F15",
        key_pathfind = "O|F16",
        key_route_guidance = "R",
        key_auto_walk = "U|F18",
        key_filter = "Q",
        key_filter_prev = "Shift+J",
        key_filter_all = "Shift+K",
        key_filter_next = "Shift+L",
        key_pathability_filter = "Shift+O",
        key_mark_visited = "Shift+V",
        key_teleport_exact = "Shift+Enter",
        key_teleport_north = "Shift+Up",
        key_teleport_south = "Shift+Down",
        key_teleport_west = "Shift+Left",
        key_teleport_east = "Shift+Right",
        object_nav_speech_coalesce_frames = tostring(delay),
        tile_diag_dump_on_hotkey = options.tile_diag_dump_on_hotkey or "false",
    }

    package.preload["config"] = function()
        return {
            get = function(key)
                return settings[key]
            end,
        }
    end

    package.preload["tolk"] = function()
        return {
            output = function(message)
                outputs[#outputs + 1] = {frame = frame, message = message, interrupt = false}
            end,
            output_interrupt = function(message)
                outputs[#outputs + 1] = {frame = frame, message = message, interrupt = true}
            end,
        }
    end

    package.preload["auto_step"] = function()
        return {
            suppress_direction_tracking = function(frames)
                auto_step_suppress_calls[#auto_step_suppress_calls + 1] = frames
            end,
        }
    end

    package.preload["debug_tools"] = function()
        return {
            debug = function() end,
            error = function(message)
                debug_errors[#debug_errors + 1] = message
            end,
        }
    end

    package.preload["emulator_compat"] = function()
        return {
            is_fceux = options.is_fceux == true,
            clear_ppu_cache = function() end,
            get_ppu_source_rows = function()
                return {}
            end,
        }
    end

    package.preload["addresses"] = function()
        return {
            MAP_ID = 0x01,
            PLAYER_X = 0x02,
            PLAYER_Y = 0x03,
            TILE_TYPE = 0x04,
        }
    end

    package.preload["chars"] = function()
        return {
            decode_bytes = function()
                return ""
            end,
        }
    end

    package.preload["navigation"] = function()
        return {
            get_position_string = function()
                if options.position_error then
                    error(options.position_error, 2)
                end
                return "Tantegel Castle Throne Room, 5, 7"
            end,
            get_position = function()
                return options.map_id or 0x01, options.player_x or 30, options.player_y or 32
            end,
        }
    end

    package.preload["game_snapshot"] = function()
        return {
            terrain_offset = options.snapshot_terrain_offset or 0x00,
        }
    end

    package.preload["text"] = function()
        return {
            get_full_screen_text = function()
                return ""
            end,
            decode_row = function()
                return ""
            end,
        }
    end

    package.preload["menu"] = function()
        return {
            get_cursor_info = function()
                return "cursor"
            end,
        }
    end

    package.preload["items"] = function()
        return {
            read_status_string = function()
                return "status"
            end,
        }
    end

    package.preload["map_reader"] = function()
        return {
            get_walkability_details = function(_, x, y)
                local cells = {
                    ["4,15"] = {tile_type = 4, effective_walkable = true, reason = "tile_type"},
                    ["4,14"] = {tile_type = 2, effective_walkable = false, reason = "tile_type"},
                    ["4,16"] = {tile_type = 6, effective_walkable = true, reason = "tile_type"},
                    ["3,15"] = {tile_type = 0, effective_walkable = false, reason = "tile_type"},
                    ["5,15"] = {tile_type = 1, effective_walkable = true, reason = "tile_type"},
                }
                return cells[x .. "," .. y]
            end,
            get_metadata = function()
                error("full tile diagnostic dump should not run during the normal N hotkey", 2)
            end,
        }
    end

    package.preload["objects"] = function()
        return {
            next_object = function()
                selected = selected + 1
                return {name = "Object " .. selected}
            end,
            prev_object = function()
                selected = selected + 1
                return {name = "Object " .. selected}
            end,
            next_filter = function()
                return filter_name
            end,
            prev_filter = function()
                return options.prev_filter_name or "All"
            end,
            all_filter = function()
                all_filter_calls = all_filter_calls + 1
                return "All"
            end,
            travel_filter = function()
                filter_name = "Travel"
                return "Travel"
            end,
            all_pathability_filter = function()
                return "All"
            end,
            select_object_by_id = function(object_id)
                focused_route_ids[#focused_route_ids + 1] = object_id
                return {id = object_id, name = "Route next"}
            end,
            refresh = function()
                object_refresh_calls = object_refresh_calls + 1
            end,
            request_refresh = function()
                object_refresh_request_calls = object_refresh_request_calls + 1
            end,
            check_refresh = function()
                object_cache_refresh_calls = object_cache_refresh_calls + 1
            end,
            needs_refresh = function()
                return options.objects_need_refresh == true
            end,
            update_npcs = function()
                live_npc_refresh_calls = live_npc_refresh_calls + 1
            end,
            current_object = function()
                if options.no_current_object then
                    return nil
                end
                return options.current_object or {
                    id = "overworld_erdrick_s_cave",
                    name = "Erdrick's Cave",
                    x = 28,
                    y = 12,
                }
            end,
            get_count = function()
                return object_count
            end,
            mark_current_visited = function()
                visited_calls = visited_calls + 1
                if options.no_current_object then
                    return nil
                end
                return {name = "Object " .. selected}
            end,
        }
    end

    package.preload["overworld_routes"] = function()
        return {
            is_active = function()
                return options.route_active == true
            end,
            status = function(_, _, _, opts)
                route_status_calls = route_status_calls + 1
                route_status_opts[#route_status_opts + 1] = opts or false
                return options.route_status_info or {
                    message = "Route to Erdrick's Cave. Next: North trail marker, 12 north",
                    log = "event=status route=erdrick waypoint=North trail marker index=5",
                    object_id = "route_erdrick_05",
                }
            end,
            start_for_object = function(obj)
                route_start_calls = route_start_calls + 1
                route_start_objects[#route_start_objects + 1] = obj
                if options.route_start_error then
                    return nil, options.route_start_error
                end
                return options.route_start_info or {
                    message = "Route to Erdrick's Cave. Next: North trail marker, 12 north",
                    log = "event=start route=erdrick waypoint=North trail marker index=5",
                    object_id = "route_erdrick_05",
                    refresh = true,
                }
            end,
            guidance_for_object = function(obj, _, _, _, opts)
                route_guidance_opts[#route_guidance_opts + 1] = opts or false
                if options.route_active == true and not options.route_guidance_starts_when_active then
                    route_status_calls = route_status_calls + 1
                    return options.route_status_info or {
                        message = "Route to Erdrick's Cave. Next: North trail marker, 12 north",
                        log = "event=status route=erdrick waypoint=North trail marker index=5",
                        object_id = "route_erdrick_05",
                    }
                end

                route_start_calls = route_start_calls + 1
                route_start_objects[#route_start_objects + 1] = obj
                if options.route_start_error then
                    return nil, options.route_start_error
                end
                return options.route_start_info or {
                    message = "Route to Erdrick's Cave. Next: North trail marker, 12 north",
                    log = "event=start route=erdrick waypoint=North trail marker index=5",
                    object_id = "route_erdrick_05",
                    refresh = true,
                }
            end,
        }
    end

    package.preload["route_manager"] = function()
        return {
            describe_current_object = function(opts)
                describe_calls[#describe_calls + 1] = opts or {}
                return "Object " .. selected
            end,
            toggle_npc_freeze = function()
                freeze_calls = freeze_calls + 1
            end,
            pathfind_to_current = function()
                pathfind_calls = pathfind_calls + 1
            end,
            autowalk_to_current = function()
                autowalk_calls = autowalk_calls + 1
            end,
            next_object_pathability_filter = function()
                pathability_filter_calls = pathability_filter_calls + 1
                return options.pathability_info or {
                    name = "All, reachable",
                    count = object_count,
                }
            end,
            refresh_object_pathability_filter_if_needed = function()
                pathability_refresh_calls = pathability_refresh_calls + 1
            end,
        }
    end

    _G.memory = {
        readbyte = function(address)
            if address == 0x01 then return 0x08 end
            if address == 0x02 then return 4 end
            if address == 0x03 then return 15 end
            if address == 0x04 then return 6 end
            return 0
        end,
    }
    _G.DW_QOL_STATE = {
        suppress_teleport_input = function()
            input_suppress_calls = input_suppress_calls + 1
        end,
    }

    local hotkeys = require "hotkeys"
    hotkeys._reset_for_tests()
    hotkeys.set_teleport_handler(function(mode, opts)
        teleport_modes[#teleport_modes + 1] = mode
        teleport_requests[#teleport_requests + 1] = opts or false
    end)

    return {
        outputs = outputs,
        update = function(keys, game_state, allow_object_hotkeys, object_hotkey_block_reason)
            frame = frame + 1
            hotkeys.update(keys or {}, game_state, allow_object_hotkeys, object_hotkey_block_reason)
        end,
        pending = function()
            return hotkeys._pending_object_nav_speech_for_tests()
        end,
        pathfind_calls = function()
            return pathfind_calls
        end,
        autowalk_calls = function()
            return autowalk_calls
        end,
        freeze_calls = function()
            return freeze_calls
        end,
        visited_calls = function()
            return visited_calls
        end,
        route_status_calls = function()
            return route_status_calls
        end,
        route_start_calls = function()
            return route_start_calls
        end,
        route_status_opts = route_status_opts,
        route_guidance_opts = route_guidance_opts,
        route_start_objects = route_start_objects,
        focused_route_ids = focused_route_ids,
        object_refresh_calls = function()
            return object_refresh_calls
        end,
        object_refresh_request_calls = function()
            return object_refresh_request_calls
        end,
        object_cache_refresh_calls = function()
            return object_cache_refresh_calls
        end,
        live_npc_refresh_calls = function()
            return live_npc_refresh_calls
        end,
        pathability_filter_calls = function()
            return pathability_filter_calls
        end,
        pathability_refresh_calls = function()
            return pathability_refresh_calls
        end,
        all_filter_calls = function()
            return all_filter_calls
        end,
        input_suppress_calls = function()
            return input_suppress_calls
        end,
        auto_step_suppress_calls = auto_step_suppress_calls,
        debug_errors = debug_errors,
        teleport_modes = teleport_modes,
        teleport_requests = teleport_requests,
        describe_calls = describe_calls,
        restore = function()
            _G.memory = original_memory
            _G.DW_QOL_STATE = original_dw_qol_state
            restore_modules(module_names)
        end,
    }
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local tests = {}

function tests.next_object_waits_for_idle_gap_before_speaking()
    local env = make_env({delay = 2})

    env.update({L = true})
    assert_equal(#env.outputs, 0, "next-object tap should not speak immediately")
    local pending, frames = env.pending()
    assert_equal(pending, "Object 1", "next-object tap should queue the description")
    assert_equal(frames, 2, "newly queued object speech should keep the full delay")

    env.update({})
    assert_equal(#env.outputs, 0, "first idle frame should not flush yet")
    env.update({})

    assert_equal(#env.outputs, 1, "second idle frame should flush")
    assert_equal(env.outputs[1].message, "Object 1", "flushed speech should describe the selected object")

    env.restore()
end

function tests.rapid_next_taps_only_speak_latest_object()
    local env = make_env({delay = 2})

    env.update({L = true})
    env.update({})
    env.update({L = true})
    env.update({})
    env.update({})

    assert_equal(#env.outputs, 1, "rapid next-object taps should coalesce to one utterance")
    assert_equal(env.outputs[1].message, "Object 2", "coalesced speech should use the latest selection")

    env.restore()
end

function tests.current_object_speaks_immediately_and_clears_pending_nav_speech()
    local env = make_env({delay = 3})

    env.update({L = true})
    env.update({})
    env.update({K = true})

    assert_equal(#env.outputs, 1, "current-object hotkey should speak immediately")
    assert_equal(env.outputs[1].message, "Object 1", "current-object should describe the live selection")

    env.update({})
    env.update({})
    env.update({})
    assert_equal(#env.outputs, 1, "cleared pending object speech should not speak later")

    env.restore()
end

function tests.high_function_key_alternatives_trigger_controller_hotkeys()
    local env = make_env({delay = 0})

    env.update({F17 = true})
    assert_equal(#env.outputs, 1, "F17 should speak position")
    assert_equal(env.outputs[1].message, "Tantegel Castle Throne Room, 5, 7",
        "F17 should use the position readout binding")

    env.update({})
    env.update({F19 = true})
    assert_equal(#env.outputs, 2, "F19 should speak HP and MP")
    assert_equal(env.outputs[2].message, "HP 0 of 0, MP 0 of 0", "F19 should use the HP readout binding")

    env.update({})
    env.update({F20 = true})
    assert_equal(#env.outputs, 3, "F20 should speak gold")
    assert_equal(env.outputs[3].message, "0 gold", "F20 should use the gold readout binding")

    env.update({})
    env.update({F14 = true})
    assert_equal(#env.outputs, 4, "F14 should describe the current object")
    assert_equal(env.outputs[4].message, "Object 0", "F14 should use the current-object binding")

    env.update({})
    env.update({F16 = true})
    assert_equal(env.pathfind_calls(), 1, "F16 should use the pathfind binding")

    env.update({})
    env.update({F18 = true})
    assert_equal(env.autowalk_calls(), 0, "held F18 auto-walk should defer route execution")

    env.update({})
    assert_equal(env.autowalk_calls(), 1, "released F18 should use the auto-walk binding")

    env.restore()
end

function tests.object_browse_hotkeys_do_not_rebuild_full_npc_list()
    local env = make_env({delay = 0})

    env.update({K = true})
    assert_equal(env.object_cache_refresh_calls(), 1, "current-object readout should refresh the current map object cache")
    assert_equal(env.live_npc_refresh_calls(), 0, "current-object readout should not rebuild all moving NPC positions")

    env.update({})
    env.update({L = true})
    assert_equal(env.object_cache_refresh_calls(), 2, "next-object browse should refresh the current map object cache")
    assert_equal(env.live_npc_refresh_calls(), 0, "next-object browse should not rebuild all moving NPC positions")

    env.update({})
    env.update({J = true})
    assert_equal(env.object_cache_refresh_calls(), 3, "previous-object browse should refresh the current map object cache")
    assert_equal(env.live_npc_refresh_calls(), 0, "previous-object browse should not rebuild all moving NPC positions")

    env.restore()
end

function tests.path_actions_refresh_live_npcs_before_planning()
    local env = make_env({delay = 0})

    env.update({O = true})
    assert_equal(env.object_cache_refresh_calls(), 1, "pathfind should refresh the current map object cache before planning")
    assert_equal(env.live_npc_refresh_calls(), 1, "pathfind should refresh moving NPC positions before planning")
    assert_equal(env.pathfind_calls(), 1, "pathfind hotkey should still invoke route planning")

    env.update({})
    env.update({U = true})
    assert_equal(env.object_cache_refresh_calls(), 1, "held auto-walk hotkey should defer route planning")
    assert_equal(env.live_npc_refresh_calls(), 1, "held auto-walk hotkey should defer live NPC refresh")
    assert_equal(env.autowalk_calls(), 0, "auto-walk hotkey should wait for key release")

    env.update({})
    assert_equal(env.object_cache_refresh_calls(), 2, "auto-walk should refresh the current map object cache before planning")
    assert_equal(env.live_npc_refresh_calls(), 2, "auto-walk should refresh moving NPC positions before planning")
    assert_equal(env.autowalk_calls(), 1, "auto-walk hotkey should invoke route execution after key release")

    env.restore()
end

function tests.deferred_autowalk_cancels_if_release_frame_is_blocked()
    local env = make_env({delay = 0})
    local state = {state = "field"}

    env.update({U = true}, state, true)
    assert_equal(env.autowalk_calls(), 0, "held auto-walk hotkey should defer while U is down")

    env.update({}, state, false, "Close the command menu first")

    assert_equal(env.autowalk_calls(), 0, "deferred auto-walk should re-check object guards when U is released")
    assert_equal(env.outputs[1].message, "Close the command menu first",
        "cancelled deferred auto-walk should explain the current object-control guard")

    env.restore()
end

function tests.pathfind_hotkey_suppresses_nearby_direction_edges()
    local env = make_env({delay = 0})

    env.update({O = true})

    assert_equal(env.pathfind_calls(), 1, "pathfind hotkey should still invoke route planning")
    assert_equal(#env.auto_step_suppress_calls, 1, "pathfind should debounce near-simultaneous D-pad taps")
    assert_equal(env.auto_step_suppress_calls[1], 8, "pathfind should use the short object-hotkey debounce window")

    env.restore()
end

function tests.route_guidance_hotkey_suppresses_nearby_direction_edges()
    local env = make_env({delay = 0, snapshot_terrain_offset = 0x00})

    env.update({R = true})

    assert_equal(env.route_start_calls(), 1, "route guidance should still start from the selected object")
    assert_equal(#env.auto_step_suppress_calls, 1, "route guidance should debounce near-simultaneous D-pad taps")
    assert_equal(env.auto_step_suppress_calls[1], 8, "route guidance should use the short object-hotkey debounce window")

    env.restore()
end

function tests.pathability_hotkey_suppresses_nearby_direction_edges()
    local env = make_env({delay = 0})

    env.update({Shift = true, O = true})

    assert_equal(env.pathability_filter_calls(), 1, "pathability filter should still cycle")
    assert_equal(#env.auto_step_suppress_calls, 1, "pathability filter should debounce near-simultaneous D-pad taps")
    assert_equal(env.auto_step_suppress_calls[1], 8, "pathability filter should use the short object-hotkey debounce window")

    env.restore()
end

function tests.tile_diag_hotkey_speaks_without_full_dump_by_default()
    local env = make_env()

    env.update({Control = true, N = true})

    assert_equal(#env.outputs, 1, "tile diagnostic hotkey should speak once")
    assert_equal(
        env.outputs[1].message,
        "At 4,15. RAM 6. Here 4W. N 2X. S 6W. W 0X. E 1W",
        "tile diagnostic hotkey should speak the compact coordinate summary"
    )

    env.restore()
end

function tests.modified_hotkeys_do_not_fire_as_bare_keys()
    local env = make_env()

    env.update({N = true})
    env.update({})
    env.update({F = true})

    assert_equal(#env.outputs, 0, "bare diagnostic key should not speak")
    assert_equal(env.freeze_calls(), 0, "bare freeze key should not toggle NPC freeze")

    env.update({})
    env.update({Shift = true, F = true})
    assert_equal(env.freeze_calls(), 1, "Shift+F should toggle NPC freeze")

    env.restore()
end

function tests.shift_r_keeps_stats_without_starting_route_guidance()
    local env = make_env({delay = 0})

    env.update({Shift = true, R = true})

    assert_equal(#env.outputs, 1, "Shift+R should speak stats only")
    assert_equal(env.outputs[1].message, "status", "Shift+R should preserve the existing stats hotkey")
    assert_equal(env.route_start_calls(), 0, "Shift+R should not also start route guidance")
    assert_equal(env.route_status_calls(), 0, "Shift+R should not report route status")

    env.restore()
end

function tests.blocked_shift_r_keeps_stats_without_object_guard()
    local env = make_env({delay = 0})

    env.update({Shift = true, R = true}, nil, false)

    assert_equal(#env.outputs, 1, "blocked object controls should not swallow Shift+R stats")
    assert_equal(env.outputs[1].message, "status", "Shift+R stats should still run while object controls are blocked")
    assert_equal(env.input_suppress_calls(), 0, "Shift+R should not be treated as a blocked object key")
    assert_equal(env.route_start_calls(), 0, "route guidance should not run from Shift+R")

    env.restore()
end

function tests.object_only_hotkeys_respect_allowance_and_non_object_hotkeys_still_run()
    local env = make_env({delay = 0})

    env.update({Shift = true, W = true}, nil, false)
    assert_equal(#env.outputs, 1, "non-object hotkey should still run when object hotkeys are blocked")
    assert_equal(env.outputs[1].message, "Tantegel Castle Throne Room, 5, 7", "position announcement should run through the same frame")
    assert_equal(env.outputs[1].interrupt, false, "read-only status hotkeys should not interrupt route speech")

    env.update({L = true}, nil, false)
    env.update({Shift = true, F = true}, nil, false)
    env.update({Shift = true, O = true}, nil, false)
    env.update({Shift = true, Q = true}, nil, false)
    env.update({R = true}, nil, false)

    assert_equal(#env.outputs, 6, "blocked object hotkeys should report why they did not run")
    assert_equal(env.outputs[2].message, "Object controls unavailable right now",
        "blocked object hotkey should give an audible guard message")
    assert_equal(env.outputs[6].message, "Object controls unavailable right now",
        "each fresh blocked object hotkey should give an audible guard message")
    assert_equal(env.input_suppress_calls(), 3, "blocked non-path object hotkeys should suppress leaked game input")
    assert_equal(#env.auto_step_suppress_calls, 2, "blocked path/readout hotkeys should debounce direction edges instead")
    assert_equal(#env.describe_calls, 0, "object navigation should be fully blocked when allowance is false")
    assert_equal(env.freeze_calls(), 0, "freeze command should not run when blocked")
    assert_equal(env.pathfind_calls(), 0, "pathfind should not run when blocked")
    assert_equal(env.autowalk_calls(), 0, "auto-walk should not run when blocked")
    assert_equal(env.visited_calls(), 0, "visited marker should not run when blocked")
    assert_equal(env.route_start_calls(), 0, "route guidance should not run when blocked")

    env.restore()
end

function tests.blocked_object_hotkey_uses_specific_reason_when_available()
    local env = make_env({delay = 0})

    env.update({L = true}, {state = "field"}, false, "Wait for movement to finish")

    assert_equal(#env.outputs, 1, "blocked object hotkey should explain why it did not run")
    assert_equal(env.outputs[1].message, "Wait for movement to finish",
        "movement gating should avoid the generic object-controls message")
    assert_equal(env.outputs[1].interrupt, false, "blocked guard speech should not interrupt route announcements")
    assert_equal(#env.auto_step_suppress_calls, 1, "movement-gated object hotkeys should debounce nearby D-pad taps")
    assert_equal(env.auto_step_suppress_calls[1], 8, "movement-gated object hotkeys should use the short debounce window")
    assert_equal(env.input_suppress_calls(), 0,
        "movement-gated object hotkeys should not trigger teleport-style controller suppression")

    env.restore()
end

function tests.blocked_object_browse_hotkeys_use_movement_safe_guard()
    local env = make_env({delay = 0})
    local state = {state = "field"}

    env.update({J = true}, state, false, "Wait for movement to finish")
    env.update({}, state, false, "Wait for movement to finish")
    env.update({K = true}, state, false, "Wait for movement to finish")
    env.update({}, state, false, "Wait for movement to finish")
    env.update({L = true}, state, false, "Wait for movement to finish")

    assert_equal(#env.outputs, 3, "each blocked browse hotkey should speak one guard")
    assert_equal(env.outputs[1].message, "Wait for movement to finish",
        "blocked J should ask the player to wait for stable movement")
    assert_equal(env.outputs[2].message, "Wait for movement to finish",
        "blocked K should ask the player to wait for stable movement")
    assert_equal(env.outputs[3].message, "Wait for movement to finish",
        "blocked L should ask the player to wait for stable movement")
    assert_equal(#env.auto_step_suppress_calls, 3,
        "blocked J/K/L should debounce nearby D-pad taps during active movement")
    assert_equal(env.input_suppress_calls(), 0,
        "blocked J/K/L should not trigger teleport-style controller suppression during active movement")

    env.restore()
end

function tests.blocked_object_hotkey_during_dialogue_uses_safe_guard()
    local env = make_env({delay = 0})

    env.update({K = true}, {state = "field"}, false, "Wait for dialogue to finish")

    assert_equal(#env.outputs, 1, "blocked object readout should explain why it did not run")
    assert_equal(env.outputs[1].message, "Wait for dialogue to finish",
        "dialogue gating should avoid the generic object-controls message")
    assert_equal(#env.auto_step_suppress_calls, 1,
        "dialogue-gated object hotkeys should debounce nearby D-pad taps")
    assert_equal(env.auto_step_suppress_calls[1], 8,
        "dialogue-gated object hotkeys should use the short object-hotkey debounce window")
    assert_equal(env.input_suppress_calls(), 0,
        "dialogue-gated object hotkeys should not trigger teleport-style controller suppression")

    env.restore()
end

function tests.blocked_pathfind_hotkey_suppresses_nearby_direction_edges()
    local env = make_env({delay = 0})

    env.update({O = true}, {state = "field"}, false, "Wait for movement to finish")

    assert_equal(env.pathfind_calls(), 0, "blocked O should not run pathfinding while movement is active")
    assert_equal(#env.auto_step_suppress_calls, 1, "blocked O should still debounce near-simultaneous D-pad taps")
    assert_equal(env.auto_step_suppress_calls[1], 8, "blocked O should use the short object-hotkey debounce window")
    assert_equal(env.input_suppress_calls(), 0, "blocked O should not trigger teleport-style controller suppression during active movement")
    assert_equal(env.outputs[1].message, "Wait for movement to finish",
        "blocked O should still explain why pathfinding did not run")

    env.restore()
end

function tests.blocked_autowalk_hotkey_suppresses_nearby_direction_edges()
    local env = make_env({delay = 0})

    env.update({U = true}, {state = "field"}, false, "Wait for movement to finish")

    assert_equal(env.autowalk_calls(), 0, "blocked U should not start auto-walk while movement is active")
    assert_equal(#env.auto_step_suppress_calls, 1, "blocked U should debounce near-simultaneous D-pad taps")
    assert_equal(env.auto_step_suppress_calls[1], 8, "blocked U should use the short object-hotkey debounce window")
    assert_equal(env.input_suppress_calls(), 0, "blocked U should not trigger teleport-style controller suppression during active movement")
    assert_equal(env.outputs[1].message, "Wait for movement to finish",
        "blocked U should still explain why auto-walk did not start")

    env.restore()
end

function tests.r_reports_active_route_status_while_movement_blocks_actions()
    local env = make_env({delay = 0, route_active = true, snapshot_terrain_offset = 0x00})

    env.update({R = true}, {state = "field"}, false, "Wait for movement to finish")

    assert_equal(env.route_status_calls(), 1, "R should report active route status while movement is settling")
    assert_equal(env.route_status_opts[1].terrain_offset, 0x00, "blocked active-route status should pass snapshot terrain_offset")
    assert_equal(env.route_start_calls(), 0, "R should not restart an active route while blocked")
    assert_equal(#env.outputs, 1, "route status should speak without the block message")
    assert_equal(env.outputs[1].message, "Route to Erdrick's Cave. Next: North trail marker, 12 north",
        "blocked active-route R should still speak the route status")
    assert_equal(env.outputs[1].interrupt, false, "route status should not interrupt route progress speech")
    assert_equal(env.input_suppress_calls(), 0, "read-only R status should not need game-input suppression")

    env.restore()
end

function tests.blocked_active_route_r_stays_read_only_even_with_new_destination_selected()
    local env = make_env({
        delay = 0,
        route_active = true,
        route_guidance_starts_when_active = true,
        current_object = {id = "overworld_brecconary", name = "Brecconary", x = 48, y = 41},
    })

    env.update({R = true}, {state = "field"}, false, "Wait for movement to finish")

    assert_equal(env.route_status_calls(), 1, "blocked active-route R should only report status")
    assert_equal(env.route_start_calls(), 0, "blocked active-route R should not replace routes while movement is unstable")
    assert_equal(env.outputs[1].message, "Route to Erdrick's Cave. Next: North trail marker, 12 north",
        "blocked active-route R should preserve read-only status speech")

    env.restore()
end

function tests.r_waits_to_start_route_while_movement_blocks_actions()
    local env = make_env({delay = 0})

    env.update({R = true}, {state = "field"}, false, "Wait for movement to finish")

    assert_equal(env.route_status_calls(), 0, "inactive route should not report status")
    assert_equal(env.route_start_calls(), 0, "R should not start a new route from a moving tile")
    assert_equal(#env.outputs, 1, "blocked route start should speak one guard")
    assert_equal(env.outputs[1].message, "Wait for movement to finish",
        "route start should ask the player to wait for stable position")

    env.restore()
end

function tests.held_blocked_object_hotkey_keeps_suppressing_input_without_repeating_speech()
    local env = make_env({delay = 0})

    env.update({Shift = true, Up = true}, nil, false)
    env.update({Shift = true, Up = true}, nil, false)
    env.update({Shift = true, Up = true}, nil, false)

    assert_equal(#env.outputs, 1, "held blocked hotkey should speak the guard only once")
    assert_equal(env.outputs[1].message, "Object controls unavailable right now",
        "held blocked hotkey should announce the object-control guard")
    assert_equal(env.input_suppress_calls(), 3,
        "held blocked hotkey should suppress leaked game input every frame")

    env.restore()
end

function tests.position_hotkey_reports_unavailable_instead_of_crashing()
    local env = make_env({position_error = "snapshot not ready"})

    env.update({Shift = true, W = true})

    assert_equal(#env.outputs, 1, "position failure should still speak one fallback")
    assert_equal(env.outputs[1].message, "Position unavailable", "position failure should use a clear fallback")
    assert_equal(#env.debug_errors, 1, "position failure should be logged for debugging")

    env.restore()
end

function tests.object_navigation_hotkeys_request_brief_descriptions()
    local env = make_env({delay = 0})

    env.update({L = true})

    assert_equal(#env.describe_calls, 1, "next-object should describe the selection")
    assert_equal(env.describe_calls[1].include_reachability, false,
        "next-object should skip path reachability checks")
    assert_equal(env.describe_calls[1].include_debug_coords, false,
        "next-object should skip raw coordinate debug details")

    env.update({})
    env.update({K = true})

    assert_equal(#env.describe_calls, 2, "current-object should describe the selection")
    assert_equal(env.describe_calls[2].include_reachability, false,
        "current-object should skip path reachability checks")
    assert_equal(env.describe_calls[2].include_debug_coords, false,
        "current-object should skip raw coordinate debug details")

    env.update({})
    env.update({Q = true})

    assert_equal(#env.describe_calls, 3, "filter hotkey should describe the first filtered object")
    assert_equal(env.describe_calls[3].include_reachability, false,
        "filter hotkey should skip path reachability checks")
    assert_equal(env.describe_calls[3].include_debug_coords, false,
        "filter hotkey should skip raw coordinate debug details")

    env.restore()
end

function tests.shift_o_cycles_pathability_filter_without_pathfinding()
    local env = make_env({delay = 0})

    env.update({Shift = true, O = true})

    assert_equal(env.pathability_filter_calls(), 1, "Shift+O should cycle the pathability filter")
    assert_equal(env.pathfind_calls(), 0, "Shift+O should not fall through to plain pathfind")
    assert_equal(#env.outputs, 1, "pathability hotkey should speak the new filtered selection")
    assert_equal(env.outputs[1].message, "All, reachable. Object 0", "pathability speech should include the stacked filter label")
    assert_equal(env.describe_calls[1].include_reachability, false,
        "pathability filter speech should not run another reachability preview")
    assert_equal(env.describe_calls[1].include_debug_coords, false,
        "pathability filter speech should stay brief")

    env.restore()
end

function tests.zero_delay_preserves_immediate_object_navigation_speech()
    local env = make_env({delay = 0})

    env.update({L = true})

    assert_equal(#env.outputs, 1, "zero coalesce delay should preserve immediate speech")
    assert_equal(env.outputs[1].message, "Object 1", "immediate speech should describe the selected object")

    env.restore()
end

function tests.route_actions_clear_pending_object_speech_without_speaking_it()
    local env = make_env({delay = 3})

    env.update({L = true})
    env.update({})
    env.update({O = true})

    assert_equal(env.pathfind_calls(), 1, "pathfind hotkey should still run")
    assert_equal(#env.outputs, 0, "pathfind should clear stale pending object speech")

    env.update({})
    env.update({})
    env.update({})
    assert_equal(#env.outputs, 0, "cleared pending object speech should not flush after pathfind")

    env.restore()
end

function tests.r_starts_guided_route_from_selected_travel_object()
    local env = make_env({delay = 0, snapshot_terrain_offset = 0x00})

    env.update({R = true})

    assert_equal(env.route_start_calls(), 1, "R should start route guidance from the selected object")
    assert_equal(env.route_status_calls(), 0, "inactive route should start instead of only reporting status")
    assert_equal(env.route_start_objects[1].name, "Erdrick's Cave", "route start should receive the selected object")
    assert_equal(env.route_guidance_opts[1].terrain_offset, 0x00, "route start should pass snapshot terrain_offset")
    assert_equal(env.object_refresh_calls(), 0, "route start should avoid an immediate object-list rebuild")
    assert_equal(env.object_refresh_request_calls(), 1, "route start should request a deferred route-marker refresh")
    assert_equal(env.focused_route_ids[1], nil, "route start should preserve the selected destination focus")
    assert_equal(#env.outputs, 1, "route guidance should speak one route message")
    assert_equal(env.outputs[1].message, "Route to Erdrick's Cave. Next: North trail marker, 12 north",
        "route guidance should speak the next waypoint")
    assert_equal(env.outputs[1].interrupt, false, "route guidance should queue behind route progress speech")
    assert_equal(env.pathfind_calls(), 0, "R should not run the O heading/path preview")
    assert_equal(env.autowalk_calls(), 0, "R should not run auto-walk")

    env.restore()
end

function tests.r_reports_active_route_status_without_restarting()
    local env = make_env({delay = 0, route_active = true, snapshot_terrain_offset = 0x00})

    env.update({R = true})

    assert_equal(env.route_status_calls(), 1, "R should report active route status")
    assert_equal(env.route_start_calls(), 0, "active route status should not restart the route")
    assert_equal(env.route_guidance_opts[1].terrain_offset, 0x00, "active route status should pass snapshot terrain_offset")
    assert_equal(env.object_refresh_calls(), 0, "active route status should avoid an immediate object-list rebuild")
    assert_equal(env.object_refresh_request_calls(), 0, "active route status should not refresh route markers without a route change")
    assert_equal(env.focused_route_ids[1], nil, "active route status should preserve the selected destination focus")
    assert_equal(env.outputs[1].message, "Route to Erdrick's Cave. Next: North trail marker, 12 north",
        "active route status should speak the next waypoint")
    assert_equal(env.outputs[1].interrupt, false, "active route status should not interrupt route progress speech")

    env.restore()
end

function tests.r_reports_missing_guided_route_and_preserves_heading_workflow()
    local env = make_env({
        delay = 0,
        current_object = {id = "overworld_brecconary", name = "Brecconary", x = 48, y = 41},
        route_start_error = "No guided route for Brecconary. Use O for heading.",
    })

    env.update({R = true})

    assert_equal(env.route_start_calls(), 1, "R should check route availability for the selected object")
    assert_equal(#env.outputs, 1, "missing route should speak one explanation")
    assert_equal(env.outputs[1].message, "No guided route for Brecconary. Use O for heading.",
        "missing route should steer the player back to O for a plain heading")
    assert_equal(env.pathfind_calls(), 0, "missing route should not silently run O")

    env.restore()
end

function tests.shift_j_l_cycle_filters_without_scrolling_objects()
    local env = make_env({delay = 0, filter_name = "Travel", prev_filter_name = "Treasure"})

    env.update({Shift = true, L = true})
    assert_equal(#env.outputs, 1, "Shift+L should speak the next filter")
    assert_equal(env.outputs[1].message, "Travel. Object 0", "Shift+L should announce the filter selection")
    assert_equal(#env.describe_calls, 1, "filter hotkey should describe the filtered object")

    env.update({})
    env.update({Shift = true, J = true})
    assert_equal(#env.outputs, 2, "Shift+J should speak the previous filter")
    assert_equal(env.outputs[2].message, "Treasure. Object 0", "Shift+J should announce the previous filter")
    assert_equal(#env.describe_calls, 2, "previous-filter hotkey should describe the filtered object")

    env.restore()
end

function tests.shift_k_jumps_filter_back_to_all_without_current_object_speech()
    local env = make_env({delay = 0})

    env.update({Shift = true, K = true})

    assert_equal(env.all_filter_calls(), 1, "Shift+K should reset to the All filter")
    assert_equal(#env.outputs, 1, "Shift+K should speak the All filter")
    assert_equal(env.outputs[1].message, "All. Object 0", "Shift+K should announce the All filter selection")
    assert_equal(#env.describe_calls, 1, "filter reset should describe the filtered object")

    env.restore()
end

function tests.mark_visited_speaks_manual_confirmation()
    local env = make_env({delay = 0})

    env.update({Shift = true, V = true})

    assert_equal(env.visited_calls(), 1, "visited hotkey should mark the current object")
    assert_equal(#env.outputs, 1, "visited hotkey should speak confirmation")
    assert_equal(env.outputs[1].message, "Object 0 marked visited", "visited hotkey should name the object")

    env.restore()
end

function tests.teleport_hotkeys_call_registered_handler()
    local env = make_env({delay = 0})

    env.update({Shift = true, Enter = true})
    assert_equal(env.object_cache_refresh_calls(), 1, "exact teleport should refresh the current map object cache before reading the selected object")
    assert_equal(env.live_npc_refresh_calls(), 1, "exact teleport should refresh live object positions before reading the selected object")
    env.update({})
    env.update({Shift = true, Up = true})
    assert_equal(env.object_cache_refresh_calls(), 2, "adjacent teleport should refresh the current map object cache before reading the selected object")
    assert_equal(env.live_npc_refresh_calls(), 2, "adjacent teleport should refresh live object positions before reading the selected object")
    env.update({})
    env.update({Shift = true, Right = true})
    assert_equal(env.object_cache_refresh_calls(), 3, "every teleport hotkey should refresh the current map object cache")
    assert_equal(env.live_npc_refresh_calls(), 3, "every teleport hotkey should refresh live object positions")

    assert_equal(#env.teleport_modes, 3, "teleport hotkeys should call the handler")
    assert_equal(env.teleport_modes[1], "exact", "Shift+Enter should request exact teleport")
    assert_equal(env.teleport_modes[2], "north", "Shift+Up should request north-of-target teleport")
    assert_equal(env.teleport_modes[3], "east", "Shift+Right should request east-of-target teleport")

    env.restore()
end

function tests.teleport_hotkeys_ignore_a_new_modifier_over_a_stale_trigger()
    local env = make_env({delay = 0})

    env.update({Down = true})
    env.update({RightShift = true, Down = true})
    assert_equal(#env.teleport_modes, 0, "new Shift must not request south teleport over stale Down")

    env.update({RightShift = true, Down = true, Enter = true})
    assert_equal(#env.teleport_modes, 1, "fresh Enter should request exact teleport despite stale Down")
    assert_equal(env.teleport_modes[1], "exact", "exact teleport should win once Enter gets a fresh edge")

    env.update({RightShift = true})
    env.update({RightShift = true, Down = true})
    assert_equal(#env.teleport_modes, 2, "new Down should request south teleport while Shift is held")
    assert_equal(env.teleport_modes[2], "south", "fresh nonmodifier edge should preserve directional teleport")

    env.restore()
end

function tests.fceux_selected_teleport_hotkey_arms_release_guard()
    local env = make_env({delay = 0, is_fceux = true})

    env.update({Shift = true, Enter = true})

    assert_equal(env.teleport_modes[1], "exact", "FCEUX exact teleport hotkey should still request selected-object teleport")
    assert_equal(type(env.teleport_requests[1]), "table", "FCEUX teleport hotkey should pass handler options")
    assert_equal(env.teleport_requests[1].suppress_input, true, "FCEUX selected teleport should arm logical suppression; main skips its immediate joypad neutralization")

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
