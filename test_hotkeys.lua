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
    local describe_calls = {}
    local filter_name = options.filter_name or "NPCs"
    local object_count = options.object_count or 1
    local delay = options.delay
    if delay == nil then delay = 2 end
    local original_memory = _G.memory

    local module_names = {
        "addresses",
        "chars",
        "config",
        "debug_tools",
        "hotkeys",
        "items",
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
        key_position = "P",
        key_hp = "H",
        key_level = "I",
        key_gold = "G",
        key_experience = "E",
        key_stats = "S",
        key_screen_text = "T",
        key_diag_cursor = "M",
        key_diag_ppu_dump = "D",
        key_diag_title = "V",
        key_diag_tiles = "N",
        key_freeze_npcs = "X",
        key_object_prev = "J",
        key_object_current = "K",
        key_object_next = "L",
        key_pathfind = "O",
        key_auto_walk = "U",
        key_filter = "F",
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
            get_count = function()
                return object_count
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

    env.update({N = true})

    assert_equal(#env.outputs, 1, "tile diagnostic hotkey should speak once")
    assert_equal(
        env.outputs[1].message,
        "At 4,15. RAM 6. Here 4W. N 2X. S 6W. W 0X. E 1W",
        "tile diagnostic hotkey should speak the compact coordinate summary"
    )

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
    env.update({F = true})

    assert_equal(#env.describe_calls, 3, "filter hotkey should describe the first filtered object")
    assert_equal(env.describe_calls[3].include_reachability, false,
        "filter hotkey should skip path reachability checks")
    assert_equal(env.describe_calls[3].include_debug_coords, false,
        "filter hotkey should skip raw coordinate debug details")

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
