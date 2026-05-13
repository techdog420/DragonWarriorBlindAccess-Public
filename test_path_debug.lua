-- test_path_debug.lua
-- Unit tests for path_debug validation timing behavior.

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

local function make_env()
    local px, py = 0, 0
    local logs = {}
    local inject_calls = 0
    local active = false
    local tick_count = 0

    local module_names = {
        "config",
        "debug_tools",
        "map_reader",
        "navigation",
        "path_debug",
        "pathfinder",
    }
    for _, name in ipairs(module_names) do
        save_module(name)
        package.loaded[name] = nil
    end

    package.preload["config"] = function()
        return {
            get = function(key)
                if key == "auto_step_timeout" then
                    return "2"
                end
                return nil
            end,
        }
    end

    package.preload["debug_tools"] = function()
        return {
            DEBUG_MODE = true,
            debug = function(msg)
                logs[#logs + 1] = "DEBUG: " .. tostring(msg)
            end,
            info = function(msg)
                logs[#logs + 1] = "INFO: " .. tostring(msg)
            end,
            error = function(msg)
                logs[#logs + 1] = "ERROR: " .. tostring(msg)
            end,
        }
    end

    package.preload["map_reader"] = function()
        return {}
    end

    package.preload["navigation"] = function()
        return {
            get_position = function()
                return 0x08, px, py
            end,
        }
    end

    package.preload["pathfinder"] = function()
        return {}
    end

    local path_debug = require "path_debug"

    local auto_step = {
        inject_step = function()
            inject_calls = inject_calls + 1
            active = true
        end,
        cancel_active_step = function()
            active = false
        end,
        is_auto_active = function()
            return active
        end,
    }

    return {
        path_debug = path_debug,
        auto_step = auto_step,
        logs = logs,
        set_position = function(x, y)
            px, py = x, y
        end,
        set_auto_active = function(value)
            active = value
        end,
        get_inject_calls = function()
            return inject_calls
        end,
        is_auto_active = function()
            return active
        end,
        tick = function(before_tick)
            tick_count = tick_count + 1
            if before_tick then
                before_tick(tick_count)
            end
            path_debug.tick()
        end,
        run_ticks = function(count, before_tick)
            for _ = 1, count do
                tick_count = tick_count + 1
                if before_tick then
                    before_tick(tick_count)
                end
                path_debug.tick()
            end
        end,
        restore = function()
            restore_modules(module_names)
        end,
    }
end

local function assert_truthy(value, message)
    if not value then
        error(message, 2)
    end
end

local function logs_contain(logs, pattern)
    for _, line in ipairs(logs) do
        if line:find(pattern, 1, true) then
            return true
        end
    end
    return false
end

local tests = {}

function tests.validate_waits_for_late_arrival_before_reporting_mismatch()
    local env = make_env()
    env.path_debug.store_path(0x08, 0, 0, 1, 0, {
        {x = 1, y = 0, direction = "east"},
    }, nil)
    env.path_debug.start_validate(env.auto_step)

    env.run_ticks(120, function(tick)
        if tick >= 62 then
            env.set_position(1, 0)
        end
    end)

    assert_truthy(
        logs_contain(env.logs, "INFO: VALIDATE COMPLETE: 1/1 steps OK, 0 mismatches"),
        "late arrival should complete validation without a mismatch"
    )
    assert_truthy(
        logs_contain(env.logs, "DEBUG: VALIDATE step 1: auto_step still active at (0,0), extending wait"),
        "validator should extend its wait while auto_step is still active"
    )
    assert_truthy(
        not logs_contain(env.logs, "MISMATCH expected"),
        "late arrival should not be logged as a mismatch"
    )

    env.restore()
end

function tests.validate_treats_already_arrived_step_as_late_success()
    local env = make_env()
    env.path_debug.store_path(0x08, 0, 0, 1, 0, {
        {x = 1, y = 0, direction = "east"},
    }, nil)
    env.path_debug.start_validate(env.auto_step)

    env.run_ticks(80, function(tick)
        if tick >= 35 then
            env.set_position(1, 0)
        end
    end)

    assert_truthy(
        logs_contain(env.logs, "INFO: VALIDATE step 1: already at expected (1,0) before inject; treating as late arrival"),
        "already-arrived steps should be treated as late success instead of desync"
    )
    assert_truthy(
        logs_contain(env.logs, "INFO: VALIDATE COMPLETE: 1/1 steps OK, 0 mismatches"),
        "late pre-inject arrival should still complete validation"
    )
    assert_truthy(
        not logs_contain(env.logs, "DESYNC before inject"),
        "already-arrived steps should not trigger a desync abort"
    )

    env.restore()
end

function tests.validate_does_not_mark_success_while_auto_step_is_still_active()
    local env = make_env()
    env.path_debug.store_path(0x08, 0, 0, 1, 0, {
        {x = 1, y = 0, direction = "east"},
    }, nil)
    env.path_debug.start_validate(env.auto_step)

    env.run_ticks(120, function(tick)
        if tick >= 50 then
            env.set_position(1, 0)
        end
        if tick >= 70 then
            env.set_auto_active(false)
        end
    end)

    assert_truthy(
        logs_contain(env.logs, "DEBUG: VALIDATE step 1: reached expected (1,0), confirming settle"),
        "validator should confirm arrival stability before counting the step as successful"
    )
    assert_truthy(
        logs_contain(env.logs, "INFO: VALIDATE COMPLETE: 1/1 steps OK, 0 mismatches"),
        "validation should still complete once auto_step goes idle at the expected tile"
    )

    env.restore()
end

function tests.validate_does_not_reinject_while_auto_step_is_active_at_start_tile()
    local env = make_env()
    env.path_debug.store_path(0x08, 0, 0, 1, 0, {
        {x = 1, y = 0, direction = "east"},
    }, nil)
    env.path_debug.start_validate(env.auto_step)

    env.run_ticks(50)

    assert_truthy(
        env.get_inject_calls() == 1,
        "validator should not inject the same step again while auto_step is still active; calls=" .. tostring(env.get_inject_calls())
    )
    assert_truthy(
        logs_contain(env.logs, "DEBUG: VALIDATE step 1: auto_step still active at (0,0), extending wait"),
        "validator should extend the wait for an active auto_step instead of racing it"
    )
    assert_truthy(
        not logs_contain(env.logs, "DEBUG: VALIDATE step 1: no movement yet at (0,0), retrying"),
        "validator should not retry while the original auto_step is still active"
    )

    env.restore()
end

function tests.validate_cancels_active_auto_step_after_terminal_mismatch()
    local env = make_env()
    env.path_debug.store_path(0x08, 0, 0, 1, 0, {
        {x = 1, y = 0, direction = "east"},
    }, nil)
    env.path_debug.start_validate(env.auto_step)

    env.run_ticks(220)

    assert_truthy(
        logs_contain(env.logs, "INFO: VALIDATE step 1: MISMATCH expected (1,0) actual (0,0)"),
        "validation should eventually report a terminal mismatch when movement never arrives"
    )
    assert_truthy(
        not env.is_auto_active(),
        "validation abort should cancel any still-active injected auto_step"
    )

    env.restore()
end

local failures = 0
local total = 0

for name, fn in pairs(tests) do
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        print("PASS  " .. name)
    else
        failures = failures + 1
        print("FAIL  " .. name .. ": " .. tostring(err))
    end
end

print(string.format("Ran %d Lua unit tests", total))

if failures > 0 then
    os.exit(1)
end
