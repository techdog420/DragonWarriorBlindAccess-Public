-- test_object_commands.lua
-- Regression tests for command-layer object browsing behavior.

local original_preload = {}
local original_loaded = {}

local function save_module(name)
    original_preload[name] = package.preload[name]
    original_loaded[name] = package.loaded[name]
    package.loaded[name] = nil
end

local function restore_modules(names)
    for _, name in ipairs(names) do
        package.preload[name] = original_preload[name]
        package.loaded[name] = original_loaded[name]
    end
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local function make_env()
    local module_names = {
        "debug_tools",
        "navigation",
        "objects",
        "overworld_routes",
        "route_manager",
        "tolk",
        "game_snapshot",
        "object_commands",
    }
    for _, name in ipairs(module_names) do
        save_module(name)
    end

    local commands = {}
    local sequence = {}
    local spoken = {}
    local logs = {}
    local last_autowalk_opts = nil

    package.preload["debug_tools"] = function()
        return {
            register_command = function(name, fn)
                commands[name] = fn
            end,
            info = function(message)
                logs[#logs + 1] = message
            end,
            error = function(message)
                logs[#logs + 1] = "ERROR: " .. tostring(message)
            end,
        }
    end

    package.preload["navigation"] = function()
        return {
            get_position = function()
                return 0x09, 19, 0
            end,
        }
    end

    package.preload["objects"] = function()
        return {
            TYPE_EXIT = "exit",
            check_refresh = function(map_id)
                sequence[#sequence + 1] = string.format("check_refresh:0x%02X", map_id)
            end,
            needs_refresh = function()
                return false
            end,
            update_npcs = function()
                sequence[#sequence + 1] = "update_npcs"
            end,
            get_objects = function()
                return {}
            end,
        }
    end

    package.preload["overworld_routes"] = function()
        return {}
    end

    package.preload["route_manager"] = function()
        return {
            describe_current_object = function()
                sequence[#sequence + 1] = "describe_current_object"
                return "fresh object"
            end,
            autowalk_to_current = function(opts)
                sequence[#sequence + 1] = "autowalk_to_current"
                last_autowalk_opts = opts
                return {status = "queued"}
            end,
        }
    end

    package.preload["tolk"] = function()
        return {
            output_interrupt = function(message)
                spoken[#spoken + 1] = message
            end,
        }
    end

    package.preload["game_snapshot"] = function()
        return {
            terrain_offset = 0x10,
        }
    end

    local object_commands = require "object_commands"
    object_commands.register()

    return {
        commands = commands,
        sequence = sequence,
        spoken = spoken,
        logs = logs,
        last_autowalk_opts = function()
            return last_autowalk_opts
        end,
        restore = function()
            restore_modules(module_names)
        end,
    }
end

local tests = {}

function tests.current_object_refreshes_object_cache_for_current_map_before_describing()
    local env = make_env()

    assert_equal(type(env.commands.current_object), "function", "current_object command should be registered")
    env.commands.current_object()

    assert_equal(env.sequence[1], "check_refresh:0x09", "current_object should refresh object cache for the live map before describing")
    assert_equal(env.sequence[2], "describe_current_object", "current_object should describe only after refresh")
    assert_equal(env.spoken[1], "fresh object", "current_object should speak the refreshed object description")

    env.restore()
end

function tests.auto_walk_blocker_command_enables_stop_on_blocker_mode()
    local env = make_env()

    assert_equal(type(env.commands.auto_walk_blocker), "function", "auto_walk_blocker command should be registered")
    env.commands.auto_walk_blocker()

    assert_equal(env.sequence[1], "check_refresh:0x09", "auto_walk_blocker should refresh the current map first")
    assert_equal(env.sequence[2], "check_refresh:0x09", "auto_walk_blocker should refresh before live NPC update")
    assert_equal(env.sequence[3], "update_npcs", "auto_walk_blocker should refresh live NPC blockers")
    assert_equal(env.sequence[4], "autowalk_to_current", "auto_walk_blocker should delegate to route_manager")
    assert_equal(env.last_autowalk_opts().stop_on_blocker, true, "auto_walk_blocker should enable blocker-hunt mode")
    assert_equal(env.last_autowalk_opts().speak, true, "auto_walk_blocker should speak like normal auto_walk")

    env.restore()
end

local count = 0
for name, fn in pairs(tests) do
    count = count + 1
    local ok, err = pcall(fn)
    if ok then
        print("PASS  " .. name)
    else
        print("FAIL  " .. name .. ": " .. tostring(err))
        os.exit(1)
    end
end

print(string.format("Ran %d Lua unit tests", count))
