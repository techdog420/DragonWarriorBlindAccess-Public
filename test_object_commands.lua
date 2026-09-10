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

local function make_env(opts)
    opts = opts or {}
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
    local filter_count = 0

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
                return opts.needs_refresh == true
            end,
            update_npcs = function()
                sequence[#sequence + 1] = "update_npcs"
            end,
            refresh = function(map_id)
                sequence[#sequence + 1] = string.format("refresh:0x%02X", map_id)
                filter_count = 19
            end,
            next_filter = function()
                sequence[#sequence + 1] = "next_filter"
                return "NPCs"
            end,
            get_filter_name = function()
                return "NPCs"
            end,
            get_filter_summary = function()
                return "NPCs"
            end,
            get_count = function()
                return filter_count
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
            open_services = function()
                sequence[#sequence + 1] = "open_services"
                return "Services. Inn. Reachable"
            end,
            describe_visible_area = function()
                sequence[#sequence + 1] = "describe_visible_area"
                return "Torchlight. North blocked"
            end,
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
        object_commands = object_commands,
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
function tests.quick_services_uses_shared_browser_without_auto_walk()
    local env = make_env()
    env.commands.quick_services()
    assert_equal(env.sequence[1], "open_services", "command uses shared service selection")
    assert_equal(env.spoken[1], "Services. Inn. Reachable", "command speaks result")
    assert_equal(env.last_autowalk_opts(), nil, "command never auto-walks")
    env.restore()
end

function tests.navigation_module_reload_primes_objects_for_same_frame_filter_navigation()
    local env = make_env({needs_refresh = true})

    assert_equal(env.sequence[1], "refresh:0x09", "registering commands after reload should synchronously build objects for the live map")
    env.commands.next_filter()

    assert_equal(env.sequence[2], "next_filter", "filter navigation should run after the live map object list exists")
    assert_equal(env.spoken[1], "NPCs. fresh object", "same-frame NPC filter navigation should not announce an empty list")

    env.restore()
end


function tests.current_object_refreshes_object_cache_for_current_map_before_describing()
    local env = make_env()

    assert_equal(type(env.commands.current_object), "function", "current_object command should be registered")
    env.commands.current_object()

    assert_equal(env.sequence[1], "check_refresh:0x09", "current_object should refresh object cache for the live map before describing")
    assert_equal(env.sequence[2], "describe_current_object", "current_object should describe only after refresh")
    assert_equal(env.spoken[1], "fresh object", "current_object should speak the refreshed object description")

    env.restore()
end

function tests.visible_area_command_refreshes_and_speaks_local_report()
    local env = make_env()

    assert_equal(type(env.commands.visible_area), "function", "visible_area command should be registered")
    env.commands.visible_area()

    assert_equal(env.sequence[1], "check_refresh:0x09", "visible_area should refresh the live map first")
    assert_equal(env.sequence[2], "describe_visible_area", "visible_area should report after refresh")
    assert_equal(env.spoken[1], "Torchlight. North blocked", "visible_area should speak the report")
    assert_equal(env.logs[1], "VISIBLE_AREA: Torchlight. North blocked", "visible_area should log structured evidence")

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
