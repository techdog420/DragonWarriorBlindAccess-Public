-- test_walked_edge_verifier.lua
-- Unit tests for non-teleport walked edge and door verification helpers.

local ok, verifier = pcall(require, "walked_edge_verifier")

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error((message or "assert_equal failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assert_truthy(value, message)
    if not value then
        error(message or "assert_truthy failed", 2)
    end
end

local function assert_log_contains(logs, needle, message)
    for _, line in ipairs(logs) do
        if tostring(line):find(needle, 1, true) then
            return
        end
    end
    error((message or "log line not found") .. ": " .. tostring(needle), 2)
end

local function make_controller()
    local state = {
        map_id = 0x09,
        x = 10,
        y = 10,
        keys = 6,
        slots = {},
    }
    local calls = {
        logs = {},
        routes = {},
        probes = {},
        speaks = {},
        teleports = 0,
    }
    local ctrl = verifier.new({
        dir_to_delta = {
            up = {dx = 0, dy = -1},
            down = {dx = 0, dy = 1},
            left = {dx = -1, dy = 0},
            right = {dx = 1, dy = 0},
        },
        get_position = function()
            return state.map_id, state.x, state.y
        end,
        route_to = function(target, opts)
            calls.routes[#calls.routes + 1] = {target = target, opts = opts}
            return {status = "queued", ok = true, path_length = 3}
        end,
        start_probe = function(dir, source)
            calls.probes[#calls.probes + 1] = {dir = dir, source = source}
            return true
        end,
        door_snapshot = function()
            local slots = {}
            for i, slot in ipairs(state.slots) do
                slots[i] = {index = slot.index, x = slot.x, y = slot.y}
            end
            return {keys = state.keys, slots = slots}
        end,
        log_info = function(msg)
            calls.logs[#calls.logs + 1] = msg
        end,
        log_error = function(msg)
            calls.logs[#calls.logs + 1] = msg
        end,
        speak = function(msg)
            calls.speaks[#calls.speaks + 1] = msg
        end,
        teleport = function()
            calls.teleports = calls.teleports + 1
        end,
    })
    return ctrl, state, calls
end

assert_equal(ok, true, "walked_edge_verifier module should load")

local tests = {}

function tests.routes_to_origin_before_starting_probe()
    local ctrl, state, calls = make_controller()
    local started = ctrl:start_edge("4,5,UP")
    assert_equal(started, true, "walked edge verifier should start")
    assert_equal(#calls.routes, 1, "route should be queued to requested origin")
    assert_equal(calls.routes[1].target.x, 4, "route target x")
    assert_equal(calls.routes[1].target.y, 5, "route target y")
    assert_equal(calls.routes[1].opts.allow_adjacent_fallback, false, "route must land exactly on origin")
    assert_equal(calls.routes[1].opts.path_mode, "direct", "route planner must not choose adjacent-origin mode")
    assert_equal(#calls.probes, 0, "probe should wait until route completes")

    state.x = 4
    state.y = 5
    ctrl:on_route_completed()
    assert_equal(#calls.probes, 0, "route completion should arm, not immediately probe")
    ctrl:tick()

    assert_equal(#calls.probes, 1, "probe should start after route completion at origin")
    assert_equal(calls.probes[1].dir, "up", "probe direction should be normalized")
    assert_equal(calls.probes[1].source, "walked_edge_verify", "probe source should identify walked verifier")
    assert_equal(calls.teleports, 0, "walked verifier must not call teleport")
    assert_log_contains(calls.logs, "WALKED_EDGE_VERIFY_PROBE", "probe start should be logged")
end

function tests.already_at_origin_starts_probe_without_route()
    local ctrl, state, calls = make_controller()
    state.x = 4
    state.y = 5

    local started = ctrl:start_edge("4,5,left")

    assert_equal(started, true, "walked edge verifier should start at current origin")
    assert_equal(#calls.routes, 0, "no route should be queued when already at origin")
    assert_equal(#calls.probes, 1, "probe should start immediately")
    assert_equal(calls.probes[1].dir, "left", "probe direction should be preserved")
    assert_log_contains(calls.logs, "origin_status=already_at_origin", "already-origin state should be logged")
end

function tests.route_completion_at_wrong_origin_aborts()
    local ctrl, state, calls = make_controller()
    assert_equal(ctrl:start_edge("4,5,RIGHT"), true, "walked edge verifier should start")

    state.x = 4
    state.y = 6
    ctrl:on_route_completed()

    assert_equal(#calls.probes, 0, "wrong-origin completion must not probe")
    assert_log_contains(calls.logs, "reason=route_completed_wrong_origin", "wrong-origin abort should be logged")
end

function tests.route_cancellation_aborts_pending_verifier()
    local ctrl, _, calls = make_controller()
    assert_equal(ctrl:start_edge("4,5,DOWN"), true, "walked edge verifier should start")

    ctrl:on_route_cancelled({reason = "stop_on_blocker"})

    assert_equal(#calls.probes, 0, "cancelled route must not probe")
    assert_log_contains(calls.logs, "reason=route_cancelled:stop_on_blocker", "route cancellation should be logged")
end

function tests.route_drift_cancellation_waits_for_reroute()
    local ctrl, state, calls = make_controller()
    assert_equal(ctrl:start_door_stand("4,7,UP"), true, "door verifier should start")

    ctrl:on_route_cancelled({reason = "route_drift_off_path"})
    state.x = 4
    state.y = 7
    ctrl:on_route_completed()

    assert_log_contains(calls.logs, "DOOR_VERIFY_READY", "recoverable route drift should not clear pending door verifier")
    assert_equal(ctrl:finish_door_after(), true, "door verifier should still be active after drift reroute completion")
end

function tests.door_stand_records_baseline_and_compares_after_open()
    local ctrl, state, calls = make_controller()
    state.x = 4
    state.y = 7
    state.keys = 6

    assert_equal(ctrl:start_door_stand("4,7,UP"), true, "door verifier should start")
    assert_equal(#calls.routes, 0, "already at door stand should not queue a route")
    assert_log_contains(calls.logs, "DOOR_VERIFY_READY", "door readiness should be logged")
    assert_log_contains(calls.logs, "expected_door=(4,6)", "expected door coordinate should be derived from stand+dir")

    state.keys = 5
    state.slots = {{index = 0, x = 4, y = 6}}
    assert_equal(ctrl:finish_door_after(), true, "door verifier should finish")
    assert_log_contains(calls.logs, "DOOR_VERIFY_RESULT", "door result should be logged")
    assert_log_contains(calls.logs, "expected_present=true", "opened-door slot should be detected")
    assert_log_contains(calls.logs, "key_delta=1", "key consumption should be reported")
end

function tests.door_stand_route_completion_logs_ready_without_opening()
    local ctrl, state, calls = make_controller()
    assert_equal(ctrl:start_door_stand("4,7,NORTH"), true, "door verifier should start")
    assert_equal(#calls.routes, 1, "route should be queued to door stand")

    state.x = 4
    state.y = 7
    ctrl:on_route_completed()

    assert_log_contains(calls.logs, "DOOR_VERIFY_READY", "door verifier should become ready after route completion")
    assert_equal(#calls.probes, 0, "door verifier should not run edge probe or OPEN automatically")
    assert_equal(calls.teleports, 0, "door verifier must not call teleport")
end

local failures = 0
local total = 0

for name, fn in pairs(tests) do
    total = total + 1
    local passed, err = pcall(fn)
    if passed then
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
