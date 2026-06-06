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
            check_refresh = function(map_id)
                sequence[#sequence + 1] = string.format("check_refresh:0x%02X", map_id)
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
