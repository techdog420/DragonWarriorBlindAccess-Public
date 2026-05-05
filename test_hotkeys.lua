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
    local pathability_filter_calls = 0
    local pathability_refresh_calls = 0
    local teleport_modes = {}
    local describe_calls = {}
    local filter_name = options.filter_name or "NPCs"
    local all_filter_calls = 0
    local object_count = options.object_count or 1
    local delay = options.delay
    if delay == nil then delay = 2 end
    local original_memory = _G.memory

    local module_names = {
        "addresses",
        "chars",
        "config",
        "debug_tools",
        "emulator_compat",
        "hotkeys",
        "items",
        "key_combo",
        "map_reader",
        "menu",
        "navigation",
        "objects",
        "route_manager",
        "text",
        "tolk",
    }

    for _, name in ipairs(module_names) do
        save_module(name)
        package.loaded[name] = nil
    end

    local settings = {
        key_position = "Shift+W",
        key_hp = "Shift+H",
        key_level = "Shift+I",
        key_gold = "Shift+G",
        key_experience = "Shift+E",
        key_stats = "Shift+R",
        key_screen_text = "Shift+T",
        key_diag_cursor = "Ctrl+M",
        key_diag_ppu_dump = "Ctrl+D",
        key_diag_title = "Ctrl+Y",
        key_diag_tiles = "Ctrl+N",
        key_freeze_npcs = "Shift+F",
        key_object_prev = "J",
        key_object_current = "K",
        key_object_next = "L",
        key_pathfind = "O",
        key_auto_walk = "U",
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
            output_interrupt = function(message)
                outputs[#outputs + 1] = {frame = frame, message = message}
            end,
        }
    end

    package.preload["debug_tools"] = function()
        return {
            debug = function() end,
        }
    end

    package.preload["emulator_compat"] = function()
        return {
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
                return "Tantegel Castle Throne Room, 5, 7"
            end,
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

    local hotkeys = require "hotkeys"
    hotkeys._reset_for_tests()
    hotkeys.set_teleport_handler(function(mode)
        teleport_modes[#teleport_modes + 1] = mode
    end)

    return {
        outputs = outputs,
        update = function(keys)
            frame = frame + 1
            hotkeys.update(keys or {})
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
        pathability_filter_calls = function()
            return pathability_filter_calls
        end,
        pathability_refresh_calls = function()
            return pathability_refresh_calls
        end,
        all_filter_calls = function()
            return all_filter_calls
        end,
        teleport_modes = teleport_modes,
        describe_calls = describe_calls,
        restore = function()
            _G.memory = original_memory
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
    env.update({})
    env.update({Shift = true, Up = true})
    env.update({})
    env.update({Shift = true, Right = true})

    assert_equal(#env.teleport_modes, 3, "teleport hotkeys should call the handler")
    assert_equal(env.teleport_modes[1], "exact", "Shift+Enter should request exact teleport")
    assert_equal(env.teleport_modes[2], "north", "Shift+Up should request north-of-target teleport")
    assert_equal(env.teleport_modes[3], "east", "Shift+Right should request east-of-target teleport")

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
