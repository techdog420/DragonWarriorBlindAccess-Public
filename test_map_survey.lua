-- test_map_survey.lua
-- Focused unit tests for the autonomous survey workflow.

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
    local logs = {}
    local outputs = {}
    local route_active = false
    local runtime_count = options.runtime_count or 0
    local nav_map_id = options.map_id or 0x08
    local nav_x = options.x or 5
    local nav_y = options.y or 5
    local object = options.object or {id = "chest_1", name = "Chest", type = "chest", x = 8, y = 5}
    local objects_list = options.objects or {object}
    local module_names = {
        "auto_step",
        "debug_tools",
        "event_bus",
        "map_reader",
        "map_survey",
        "navigation",
        "objects",
        "route_manager",
        "tolk",
    }

    for _, name in ipairs(module_names) do
        save_module(name)
        package.loaded[name] = nil
    end

    package.preload["debug_tools"] = function()
        return {
            DEBUG_MODE = true,
            info = function(msg) logs[#logs + 1] = tostring(msg) end,
            debug = function(msg) logs[#logs + 1] = tostring(msg) end,
            error = function(msg) logs[#logs + 1] = tostring(msg) end,
        }
    end

    package.preload["tolk"] = function()
        return {
            output_interrupt = function(msg)
                outputs[#outputs + 1] = tostring(msg)
            end,
        }
    end

    package.preload["event_bus"] = function()
        local subscribers = {}
        local next_id = 1
        return {
            subscribe = function(event_name, fn)
                if not subscribers[event_name] then
                    subscribers[event_name] = {}
                end
                local id = next_id
                next_id = next_id + 1
                subscribers[event_name][#subscribers[event_name] + 1] = {id = id, fn = fn}
                return id
            end,
            publish = function(event_name, data)
                local list = subscribers[event_name] or {}
                for _, entry in ipairs(list) do
                    entry.fn(data)
                end
            end,
        }
    end

    package.preload["navigation"] = function()
        return {
            get_position = function()
                return nav_map_id, nav_x, nav_y
            end,
        }
    end

    package.preload["objects"] = function()
        return {
            current_object = function() return object end,
            get_objects = function() return objects_list end,
            find_object_by_id = function(id)
                for _, obj in ipairs(objects_list) do
                    if id == obj.id then
                        return obj
                    end
                end
                return nil
            end,
            update_npcs = function() end,
        }
    end

    package.preload["map_reader"] = function()
        return {
            get_walkability_details = function(_, x, y)
                if options.permanent_blocked and options.permanent_blocked[x .. "," .. y] then
                    return {effective_walkable = false, permanent_blocked = true}
                end
                return {effective_walkable = true, permanent_blocked = false}
            end,
        }
    end

    package.preload["auto_step"] = function()
        return {
            is_route_active = function() return route_active end,
            cancel_active_step = function()
                route_active = false
            end,
        }
    end

    package.preload["route_manager"] = function()
        local default_autowalk = options.autowalk or {
            status = "queued",
            result = "Path: 3 east",
            path_mode = "direct",
            path = {
                {x = 6, y = 5, direction = "east"},
                {x = 7, y = 5, direction = "east"},
                {x = 8, y = 5, direction = "east"},
            },
        }
        local autowalk_sequence = options.autowalk_sequence
        local autowalk_index = 0
        local alternate = options.alternate or {
            direct = {result = "No path found", path = nil},
            adjacent = {result = "Approach: 2 east", path = {
                {x = 6, y = 5, direction = "east"},
                {x = 7, y = 5, direction = "east"},
            }},
        }
        local clear_calls = 0
        return {
            autowalk_to_object = function(target)
                if options.autowalk_fn then
                    return options.autowalk_fn({
                        target = target,
                        runtime_count = runtime_count,
                        clear_calls = clear_calls,
                    })
                end
                local spec = default_autowalk
                if autowalk_sequence and autowalk_sequence[1] then
                    autowalk_index = autowalk_index + 1
                    spec = autowalk_sequence[autowalk_index] or autowalk_sequence[#autowalk_sequence]
                end
                if spec.status == "queued" then
                    route_active = true
                end
                local copy = {}
                for k, v in pairs(spec) do
                    copy[k] = v
                end
                return copy
            end,
            plan_path_to_object = function(_, opts)
                local mode = opts and opts.path_mode or "direct"
                local spec = alternate[mode] or {result = "No path found", path = nil}
                local copy = {}
                for k, v in pairs(spec) do
                    copy[k] = v
                end
                copy.path_mode = mode
                return copy
            end,
            get_dir_to_delta = function()
                return {
                    up = {dx = 0, dy = -1},
                    down = {dx = 0, dy = 1},
                    left = {dx = -1, dy = 0},
                    right = {dx = 1, dy = 0},
                }
            end,
            build_path_blocking = function()
                return options.blocking or {}
            end,
            count_runtime_blocks = function()
                return runtime_count
            end,
            clear_runtime_blocks = function()
                clear_calls = clear_calls + 1
                runtime_count = 0
            end,
        }
    end

    local survey = require "map_survey"
    local bus = require "event_bus"

    return {
        survey = survey,
        logs = logs,
        outputs = outputs,
        publish = function(event_name, data)
            if event_name == "route_blocked" then
                runtime_count = runtime_count + 1
            end
            if event_name == "route_completed" or event_name == "route_cancelled" then
                route_active = false
            end
            bus.publish(event_name, data)
        end,
        restore = function()
            restore_modules(module_names)
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

local tests = {}

function tests.no_path_with_alternate_route_is_classified_as_wrong_adjacency()
    local env = make_env({
        autowalk = {
            status = "no_path",
            result = "No path found",
            path_mode = "direct",
            path = nil,
        },
        alternate = {
            direct = {result = "No path found", path = nil},
            adjacent = {result = "Approach: 2 east", path = {
                {x = 6, y = 5, direction = "east"},
                {x = 7, y = 5, direction = "east"},
            }},
        },
    })

    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    env.survey.tick(true)

    local run = env.survey.get_last_run(0x08)
    local result = run and run.results[1]
    assert_equal(result.failure_classification, "wrong_adjacency_or_interaction_assumption",
        "alternate adjacency route should reclassify the failure")

    env.restore()
end

function tests.blocked_tile_retry_success_is_recorded_as_candidate_evidence()
    local env = make_env()

    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    env.publish("route_blocked", {from_x = 5, from_y = 5, dir = "right"})
    env.publish("route_blocked", {from_x = 6, from_y = 6, dir = "up"})
    env.publish("route_completed")
    env.survey.tick(true)

    local run = env.survey.get_last_run(0x08)
    local result = run and run.results[1]
    assert_equal(result.movement_succeeded, true, "route completion should mark the target successful")
    assert_equal(result.retry_succeeded, true, "reroute success should be recorded")
    assert_equal(result.suspected_blocked_tiles[1], "6,5", "blocked destination should be tracked as a candidate")
    assert_equal(env.survey.list_blocked_candidates(0x08), 1, "candidate list should contain the implicated tile")
    assert_equal(env.survey.report_strong_candidates(0x08), 1, "reroute-backed repeated evidence should be surfaced as a strong candidate")
    assert_equal(env.survey.report_candidate_suggestions(0x08), 1, "medium/high confidence candidates should produce suggestions")
    assert_equal(env.survey.export_directional_candidates(0x08), 1, "directional export should include suggested entries")
    assert_contains(table.concat(env.logs, "\n"), "confidence=high",
        "retry success should raise the candidate confidence")
    assert_contains(table.concat(env.logs, "\n"), '["6,5"] = {south=true, west=true}',
        "directional export should preserve only the observed blocked approaches")

    env.restore()
end

function tests.blocked_tile_failure_is_classified_as_suspected_engine_blocked()
    local env = make_env()

    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    env.publish("route_blocked", {from_x = 5, from_y = 5, dir = "right"})
    env.publish("route_cancelled", {reason = "reroute_no_path"})
    env.survey.tick(true)

    local run = env.survey.get_last_run(0x08)
    local result = run and run.results[1]
    assert_equal(result.movement_succeeded, false, "route cancellation should record a failure")
    assert_equal(result.failure_classification, "suspected_engine_blocked_tile",
        "blocked live movement on a nominally passable tile should be classified conservatively")

    env.restore()
end

function tests.transient_no_path_is_retried_once_before_recording_failure()
    local env = make_env({
        autowalk_sequence = {
            {
                status = "no_path",
                result = "No path found",
                path_mode = "direct",
                path = nil,
            },
            {
                status = "queued",
                result = "Path: 2 east",
                path_mode = "direct",
                path = {
                    {x = 6, y = 5, direction = "east"},
                    {x = 7, y = 5, direction = "east"},
                },
            },
        },
        alternate = {
            direct = {result = "No path found", path = nil},
            adjacent = {result = "No path found", path = nil},
        },
    })

    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)

    local run = env.survey.get_last_run(0x08)
    local result = run and run.results[1]
    assert_equal(run.summary.successes, 1, "successful retry should preserve a clean survey result")
    assert_equal(run.summary.failures, 0, "transient no-path should not be recorded as a failure when retry succeeds")
    assert_equal(result.movement_succeeded, true, "requeued target should succeed on retry")
    assert_contains(table.concat(env.logs, "\n"), "SURVEY_REQUEUE",
        "transient no-path should be requeued once")

    env.restore()
end

function tests.survey_logs_include_attempt_start_position()
    local env = make_env({
        map_id = 0x05,
        x = 3,
        y = 5,
    })

    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_ATTEMPT run=1 map=0x05", "attempt log should be emitted")
    assert_contains(joined, "start=(3,5)", "attempt/result logs should include the live start position")

    env.restore()
end

function tests.survey_clears_runtime_blocks_between_attempts()
    local env = make_env({
        objects = {
            {id = "npc_1", name = "First", type = "npc", x = 8, y = 5},
            {id = "npc_2", name = "Second", type = "npc", x = 9, y = 5},
        },
        autowalk_fn = function(ctx)
            if ctx.target.id == "npc_1" then
                return {
                    status = "queued",
                    result = "Path: 1 east",
                    path_mode = "adjacent",
                    path = {
                        {x = 6, y = 5, direction = "east"},
                    },
                }
            end

            if ctx.target.id == "npc_2" then
                if ctx.runtime_count > 0 then
                    return {
                        status = "no_path",
                        result = "No path found",
                        path_mode = "adjacent",
                        path = nil,
                    }
                end
                return {
                    status = "queued",
                    result = "Path: 1 east",
                    path_mode = "adjacent",
                    path = {
                        {x = 6, y = 5, direction = "east"},
                    },
                }
            end

            return {
                status = "no_path",
                result = "No path found",
                path_mode = "adjacent",
                path = nil,
            }
        end,
        alternate = {
            direct = {result = "No path found", path = nil},
            adjacent = {result = "No path found", path = nil},
        },
    })

    env.survey.start_object_survey()
    env.survey.tick(true)
    env.publish("route_blocked", {from_x = 5, from_y = 5, dir = "right"})
    env.publish("route_cancelled", {reason = "reroute_no_path"})
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)

    local run = env.survey.get_last_run(0x08)
    assert_equal(run.summary.failures, 1, "only the first target should fail")
    assert_equal(run.summary.successes, 1, "the second target should get a clean retry-free plan")
    assert_contains(table.concat(env.logs, "\n"), "SURVEY_ATTEMPT_RESET run=1 map=0x08 target_id=npc_2 cleared_runtime_blocks=1",
        "second attempt should clear stale runtime blockers before planning")

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
