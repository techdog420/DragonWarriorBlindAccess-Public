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
    local clear_route_context_calls = 0
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
                if options.walkability_fn then
                    local custom = options.walkability_fn(x, y)
                    if type(custom) == "table" then
                        if custom.effective_walkable == nil then
                            custom.effective_walkable = custom.permanent_blocked ~= true
                        end
                        if custom.permanent_blocked == nil then
                            custom.permanent_blocked = false
                        end
                        return custom
                    end
                    if custom ~= nil then
                        return {
                            effective_walkable = custom == true,
                            permanent_blocked = custom ~= true,
                        }
                    end
                end
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
            autowalk_to_object = function(target, opts)
                if options.autowalk_fn then
                    local spec = options.autowalk_fn({
                        target = target,
                        runtime_count = runtime_count,
                        clear_calls = clear_calls,
                    })
                    if spec and opts and opts.prequeue_hook then
                        local hook_ok, override = opts.prequeue_hook(spec)
                        if hook_ok == false and type(override) == "table" then
                            for k, v in pairs(override) do
                                spec[k] = v
                            end
                        end
                    end
                    return spec
                end
                local spec = default_autowalk
                if autowalk_sequence and autowalk_sequence[1] then
                    autowalk_index = autowalk_index + 1
                    spec = autowalk_sequence[autowalk_index] or autowalk_sequence[#autowalk_sequence]
                end
                local copy = {}
                for k, v in pairs(spec) do
                    copy[k] = v
                end
                if opts and opts.prequeue_hook then
                    local hook_ok, override = opts.prequeue_hook(copy)
                    if hook_ok == false and type(override) == "table" then
                        for k, v in pairs(override) do
                            copy[k] = v
                        end
                    end
                end
                if copy.status == "queued" then
                    route_active = true
                end
                return copy
            end,
            plan_path_to_object = function(target, opts)
                if options.plan_fn then
                    local spec = options.plan_fn(target, opts)
                    if spec then
                        local copy = {}
                        for k, v in pairs(spec) do
                            copy[k] = v
                        end
                        copy.path_mode = copy.path_mode or (opts and opts.path_mode or "direct")
                        return copy
                    end
                end
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
            clear_active_route_context = function()
                clear_route_context_calls = clear_route_context_calls + 1
            end,
        }
    end

    local survey = require "map_survey"
    local bus = require "event_bus"

    return {
        survey = survey,
        logs = logs,
        outputs = outputs,
        set_route_active = function(value)
            route_active = value
        end,
        clear_route_context_calls = function()
            return package.loaded["route_manager"] and clear_route_context_calls or 0
        end,
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

local function assert_not_contains(haystack, needle, message)
    if string.find(haystack, needle, 1, true) then
        error(string.format("%s: unexpected %s in %s", message, needle, haystack), 2)
    end
end

local function assert_before(haystack, first, second, message)
    local first_pos = string.find(haystack, first, 1, true)
    local second_pos = string.find(haystack, second, 1, true)
    if not first_pos or not second_pos or first_pos >= second_pos then
        error(string.format("%s: expected %s before %s in %s", message, first, second, haystack), 2)
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

function tests.no_path_that_clears_when_npcs_are_ignored_is_classified_as_state_issue()
    local env = make_env({
        object = {id = "npc_guard", name = "Guard", type = "npc", x = 8, y = 5},
        autowalk = {
            status = "no_path",
            result = "No path found",
            path_mode = "adjacent",
            path = nil,
        },
        plan_fn = function(_, opts)
            local mode = opts and opts.path_mode or "adjacent"
            if opts and opts.skip_npcs then
                return {
                    result = "Approach: 3 east",
                    path_mode = mode,
                    path = {
                        {x = 6, y = 5, direction = "east"},
                        {x = 7, y = 5, direction = "east"},
                        {x = 8, y = 5, direction = "east"},
                    },
                }
            end
            return {
                result = "No path found",
                path_mode = mode,
                path = nil,
            }
        end,
    })

    env.survey.start_target_survey("npc_guard")
    env.survey.tick(true)
    env.survey.tick(true)

    local run = env.survey.get_last_run(0x08)
    local result = run and run.results[1]
    local joined = table.concat(env.logs, "\n")
    assert_equal(result.failure_classification, "command_timing_or_state_issue",
        "survey no-path should be treated as a state issue when an NPC-free route exists")
    assert_contains(joined, "SURVEY_NPC_BLOCKED_ROUTE run=1 map=0x08 start=(5,5) target_id=npc_guard",
        "survey should log when frozen NPC blockers are the difference")
    assert_not_contains(joined, "SURVEY_REQUEUE run=1 map=0x08 target_id=npc_guard reason=transient_no_path retry=1",
        "NPC-blocked no-path should not be retried as a clean map no-route")

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

function tests.multi_tile_reroute_no_path_is_classified_as_state_issue()
    local env = make_env()

    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    env.publish("route_blocked", {from_x = 5, from_y = 5, dir = "right"})
    env.publish("route_blocked", {from_x = 7, from_y = 5, dir = "up"})
    env.publish("route_cancelled", {reason = "reroute_no_path"})
    env.survey.tick(true)

    local run = env.survey.get_last_run(0x08)
    local result = run and run.results[1]
    assert_equal(result.movement_succeeded, false, "route cancellation should still record a failure")
    assert_equal(
        result.failure_classification,
        "command_timing_or_state_issue",
        "multi-tile reroute-no-path failures should not be promoted to engine-block evidence"
    )

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
    local joined = table.concat(env.logs, "\n")
    assert_equal(run.summary.successes, 1, "successful retry should preserve a clean survey result")
    assert_equal(run.summary.failures, 0, "transient no-path should not be recorded as a failure when retry succeeds")
    assert_equal(result.movement_succeeded, true, "requeued target should succeed on retry")
    assert_contains(joined, "SURVEY_REQUEUE",
        "transient no-path should be requeued once")
    assert_contains(joined, "SURVEY_ATTEMPT run=1 map=0x08 idx=1/1 retry=1",
        "retry attempts should keep the original target denominator stable")
    assert_contains(joined, "SURVEY_COMPLETE run=1 map=0x08 targets=1 successes=1 failures=0",
        "completed survey totals should stay anchored to the original target set")

    env.restore()
end

function tests.orphaned_queued_route_is_retried_once_before_recording_state_issue()
    local env = make_env({
        autowalk_sequence = {
            {
                status = "queued",
                result = "Path: 2 east",
                path_mode = "direct",
                path = {
                    {x = 6, y = 5, direction = "east"},
                    {x = 7, y = 5, direction = "east"},
                },
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
    env.set_route_active(false)
    env.survey.tick(true)
    env.survey.tick(true)
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)

    local run = env.survey.get_last_run(0x08)
    local result = run and run.results[1]
    local joined = table.concat(env.logs, "\n")
    assert_equal(run.summary.successes, 1, "clean orphaned routes should get one retry before counting as a failure")
    assert_equal(run.summary.failures, 0, "successful orphaned-route retry should not pollute survey failures")
    assert_equal(result.movement_succeeded, true, "requeued orphaned route should be able to succeed on retry")
    assert_equal(
        env.clear_route_context_calls(),
        1,
        "orphaned queued routes should clear stale route-manager context before retrying"
    )
    assert_contains(joined, "SURVEY_REQUEUE run=1 map=0x08 target_id=chest_1 reason=timing_orphaned_route retry=1",
        "orphaned queued routes should be retried once as timing noise")

    env.restore()
end

function tests.clustered_clean_no_path_from_same_start_is_classified_as_gated_or_isolated()
    local env = make_env({
        objects = {
            {id = "npc_a", name = "NPC A", type = "npc", x = 8, y = 5},
            {id = "npc_b", name = "NPC B", type = "npc", x = 9, y = 5},
        },
        autowalk = {
            status = "no_path",
            result = "No path found",
            path_mode = "direct",
            path = nil,
        },
        alternate = {
            direct = {result = "No path found", path = nil},
            adjacent = {result = "No path found", path = nil},
        },
    })

    env.survey.start_object_survey()
    env.survey.tick(true)
    env.survey.tick(true)
    env.survey.tick(true)
    env.survey.tick(true)

    local run = env.survey.get_last_run(0x08)
    local joined = table.concat(env.logs, "\n")
    local result_a = run and run.result_by_id["npc_a"]
    local result_b = run and run.result_by_id["npc_b"]
    assert_contains(joined, "SURVEY_REQUEUE run=1 map=0x08 target_id=npc_a reason=transient_no_path retry=1",
        "the first isolated no-path target should still get one transient retry")
    assert_not_contains(joined, "SURVEY_REQUEUE run=1 map=0x08 target_id=npc_b reason=transient_no_path retry=1",
        "once a clean no-path cluster forms, later targets from the same start should not be retried as transient")
    assert_contains(joined, "SURVEY_ISOLATED_START run=1 map=0x08 start=(5,5) no_path_events=2 distinct_targets=2",
        "the survey should log when repeated clean no-path failures indicate a gated or isolated region")
    assert_equal(result_b.failure_classification, "gated_or_isolated_region",
        "the second distinct no-path target from the same unchanged start should be classified as gated or isolated")
    assert_equal(run.summary.gated_or_isolated_region, 2,
        "clustered no-path failures should be counted separately in the survey summary")
    assert_contains(joined, "SURVEY_FAILURE_STARTS map=0x08 count=1",
        "survey completion should emit grouped failure-start reporting")
    assert_contains(joined, "SURVEY_FAILURE_START map=0x08 start=(5,5) failures=2 distinct_targets=2 gated_or_isolated=2 no_route=0",
        "the grouped failure-start report should summarize the isolated pocket cleanly")
    assert_equal(env.survey.report_failure_starts(0x08), 1,
        "failure-start reporting should return the number of grouped failure pockets")

    env.restore()
end

function tests.single_target_with_only_single_exit_micro_landings_is_classified_as_gated_or_isolated()
    local env = make_env({
        objects = {
            {id = "npc_guard", name = "Guard", type = "npc", x = 20, y = 25},
        },
        autowalk = {
            status = "no_path",
            result = "No path found",
            path_mode = "adjacent",
            path = nil,
            adjacent_diagnostics = {
                {x = 20, y = 24, walkable = false, blocker = nil},
                {x = 20, y = 26, walkable = false, blocker = nil},
                {x = 19, y = 25, walkable = true, blocker = nil, path_found = false, reachable_area = 2, open_exits = 1},
                {x = 21, y = 25, walkable = true, blocker = nil, path_found = false, reachable_area = 128, open_exits = 1},
            },
        },
        alternate = {
            direct = {result = "No path found", path = nil},
            adjacent = {result = "No path found", path = nil},
        },
    })

    env.survey.start_object_survey()
    env.survey.tick(true)
    env.survey.tick(true)

    local run = env.survey.get_last_run(0x08)
    local result = run and run.results[1]
    local joined = table.concat(env.logs, "\n")
    assert_equal(result.failure_classification, "gated_or_isolated_region",
        "single-target no-path results with only single-exit micro-landings should classify as gated or isolated")
    assert_equal(run.summary.gated_or_isolated_region, 1,
        "micro-landing isolation should count in the gated-or-isolated summary bucket")
    assert_equal(run.summary.no_route_found, 0,
        "micro-landing isolation should not be left behind as a generic no-route result")
    assert_not_contains(joined, "SURVEY_REQUEUE run=1 map=0x08 target_id=npc_guard reason=transient_no_path retry=1",
        "micro-landing isolation should not burn the one transient no-path retry")
    assert_contains(joined, "SURVEY_TARGET_ISOLATED_ADJACENT run=1 map=0x08 start=(5,5) target_id=npc_guard target=(20,25) viable_adjacent=2 single_exit_adjacent=2 tiny_adjacent=1 reason=single_exit_micro_landing",
        "survey should log why a single-target adjacent no-path was treated as a gated or isolated landing problem")

    env.restore()
end

function tests.earlier_clean_no_path_results_are_reclassified_when_same_start_cluster_forms_later()
    local merchant_b_calls = 0
    local allowed = {
        ["2,4"] = true, ["3,4"] = true, ["4,4"] = true, ["5,4"] = true, ["6,4"] = true,
        ["2,5"] = true, ["3,5"] = true, ["4,5"] = true, ["5,5"] = true, ["6,5"] = true, ["7,5"] = true,
        ["2,6"] = true, ["3,6"] = true, ["4,6"] = true, ["5,6"] = true, ["6,6"] = true,
        ["2,7"] = true, ["3,7"] = true, ["4,7"] = true, ["5,7"] = true, ["6,7"] = true,
    }
    local env = make_env({
        x = 5,
        y = 5,
        objects = {
            {id = "npc_a", name = "NPC A", type = "npc", x = 8, y = 5},
            {id = "npc_b", name = "NPC B", type = "npc", x = 9, y = 5},
        },
        walkability_fn = function(x, y)
            return allowed[x .. "," .. y] == true
        end,
        blocking = {
            ["6,5"] = {east = true},
        },
        autowalk_fn = function(ctx)
            if ctx.target.id == "npc_b" then
                merchant_b_calls = merchant_b_calls + 1
                if merchant_b_calls == 1 then
                    return {
                        status = "queued",
                        result = "Path: 2 east",
                        path_mode = "direct",
                        path = {
                            {x = 6, y = 5, direction = "east"},
                            {x = 7, y = 5, direction = "east"},
                        },
                    }
                end
            end
            return {
                status = "no_path",
                result = "No path found",
                path_mode = "direct",
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
    env.survey.tick(true)
    env.survey.tick(true)
    env.survey.tick(true)
    env.survey.tick(true)

    local run = env.survey.get_last_run(0x08)
    local joined = table.concat(env.logs, "\n")
    local result_a = run and run.result_by_id["npc_a"]
    local result_b = run and run.result_by_id["npc_b"]
    assert_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=2/2 defer=1 target_id=npc_b reason=continuation_trap landing=(7,5) reachable_area=1 remaining_targets=1",
        "the second target should be deferred into a one-way continuation trap so the first retry records before the cluster forms")
    assert_contains(joined, "SURVEY_RECLASSIFY run=1 map=0x08 start=(5,5) target_id=npc_a from=no_route_found to=gated_or_isolated_region reason=isolated_start_cluster distinct_targets=2",
        "finish_run should retroactively fold the earlier clean no-path result into the isolated-start cluster")
    assert_equal(result_a.failure_classification, "gated_or_isolated_region",
        "earlier clean no-path results from the same isolated start should be reclassified before summary")
    assert_equal(result_b.failure_classification, "gated_or_isolated_region",
        "later clustered no-path results should remain gated or isolated")
    assert_equal(run.summary.gated_or_isolated_region, 2,
        "reclassification should move both same-start clean no-path failures into the isolated bucket")
    assert_equal(run.summary.no_route_found, 0,
        "retroactive cluster cleanup should remove the stale no-route count from the summary")
    assert_contains(joined, "SURVEY_FAILURE_START map=0x08 start=(5,5) failures=2 distinct_targets=2 gated_or_isolated=2 no_route=0",
        "failure-start grouping should reflect the retroactive isolated-start reclassification")

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

function tests.survey_start_logs_context_and_low_exit_warning()
    local env = make_env({
        map_id = 0x05,
        x = 3,
        y = 5,
        blocking = {
            ["3,4"] = {south = true},
            ["4,5"] = {west = true},
        },
    })

    env.survey.start_target_survey("chest_1")

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_START run=1 map=0x05 start=(3,5) targets=1",
        "survey start log should include the opening coordinates")
    assert_contains(joined, "SURVEY_START_CONTEXT run=1 map=0x05 start=(3,5) open_exit_count=2 open_exits=south|west",
        "survey start context should record the immediate open exits")
    assert_contains(joined, "blocked_exits=north:directional(south)|east:directional(west)",
        "survey start context should explain blocked exits")
    assert_contains(joined, "SURVEY_START_WARNING run=1 map=0x05 reason=low_exit_count start=(3,5) open_exit_count=2 open_exits=south|west",
        "survey should warn when the starting tile has only a couple of exits")

    env.restore()
end

function tests.survey_aborts_from_isolated_start_pocket()
    local env = make_env({
        map_id = 0x05,
        x = 5,
        y = 5,
        objects = {
            {id = "npc_1", name = "North Target", type = "npc", x = 5, y = 4},
            {id = "npc_2", name = "South Target", type = "npc", x = 5, y = 6},
        },
        walkability_fn = function(x, y)
            local allowed = {
                ["5,4"] = true,
                ["5,5"] = true,
                ["5,6"] = true,
            }
            return allowed[x .. "," .. y] == true
        end,
    })

    local ok, err = env.survey.start_object_survey()

    assert_equal(ok, false, "survey should abort instead of starting from an isolated pocket")
    assert_equal(err, "Survey start (5,5) is isolated: reachable area 3 with 2 open exits",
        "abort reason should describe the isolated start")
    assert_equal(env.survey.is_active(), false, "aborted survey should not remain active")
    assert_equal(env.survey.get_last_run(0x05), nil, "aborted survey should not record a completed run")

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_START_ABORT run=1 map=0x05 reason=isolated_start start=(5,5) targets=2 reachable_area=3 open_exit_count=2 open_exits=north|south",
        "survey should log the isolated start abort with reachability context")
    assert_contains(joined, "blocked_exits=west:tile|east:tile",
        "survey should record the blocked exits that caused the isolated start abort")
    assert_equal(env.outputs[1], "Survey aborted on map 05. Start (5,5) is isolated: reachable area 3 with 2 open exits.",
        "survey should announce the isolated start abort")

    env.restore()
end

function tests.survey_reports_start_viability_without_launching_run()
    local env = make_env({
        map_id = 0x05,
        x = 5,
        y = 5,
        objects = {
            {id = "npc_1", name = "North Target", type = "npc", x = 5, y = 4},
            {id = "npc_2", name = "South Target", type = "npc", x = 5, y = 6},
        },
        walkability_fn = function(x, y)
            local allowed = {
                ["5,4"] = true,
                ["5,5"] = true,
                ["5,6"] = true,
            }
            return allowed[x .. "," .. y] == true
        end,
    })

    local ok, info = env.survey.report_start_viability()

    assert_equal(ok, true, "start viability preflight should report instead of failing")
    assert_equal(info.isolated_start, true, "preflight should flag the tiny start pocket as isolated")
    assert_equal(info.reachable_area, 3, "preflight should report the reachable area from the current tile")
    assert_equal(info.open_exit_count, 2, "preflight should report the immediate open exits")
    assert_equal(info.target_count, 2, "preflight should use the same target set as object survey")
    assert_equal(env.survey.is_active(), false, "preflight should not start an active survey")
    assert_equal(env.survey.get_last_run(0x05), nil, "preflight should not create a completed run")

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_START_STATUS map=0x05 mode=objects start=(5,5) targets=2 reachable_area=3 open_exit_count=2 open_exits=north|south",
        "preflight should log the start viability summary")
    assert_contains(joined, "status=isolated_start hard_area_limit=12 area_limit=16 open_exit_limit=2",
        "preflight should report why the start is considered isolated")

    env.restore()
end

function tests.survey_aborts_tiny_four_exit_start_due_to_hard_area_limit()
    local env = make_env({
        map_id = 0x05,
        x = 5,
        y = 5,
        objects = {
            {id = "npc_1", name = "North Target", type = "npc", x = 5, y = 3},
            {id = "npc_2", name = "East Target", type = "npc", x = 7, y = 5},
        },
        walkability_fn = function(x, y)
            local allowed = {
                ["5,5"] = true,
                ["5,4"] = true,
                ["5,3"] = true,
                ["5,6"] = true,
                ["5,7"] = true,
                ["4,5"] = true,
                ["3,5"] = true,
                ["6,5"] = true,
                ["7,5"] = true,
                ["6,4"] = true,
            }
            return allowed[x .. "," .. y] == true
        end,
    })

    local ok, info = env.survey.report_start_viability()

    assert_equal(ok, true, "hard-area preflight should still return structured start information")
    assert_equal(info.isolated_start, true, "tiny reachable areas should be isolated even with more than two exits")
    assert_equal(info.reachable_area, 10, "hard-area preflight should report the full small pocket size")
    assert_equal(info.open_exit_count, 4, "hard-area preflight should preserve the true exit count")

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_START_STATUS map=0x05 mode=objects start=(5,5) targets=2 reachable_area=10 open_exit_count=4",
        "hard-area preflight should log the tiny multi-exit start")
    assert_contains(joined, "status=isolated_start hard_area_limit=12 area_limit=16 open_exit_limit=2",
        "hard-area preflight should explain which threshold classified the start as isolated")

    local start_ok, err = env.survey.start_object_survey()
    assert_equal(start_ok, false, "survey should abort from a tiny start pocket even when it has several exits")
    assert_equal(err, "Survey start (5,5) is isolated: reachable area 10 with 4 open exits",
        "hard-area abort should describe the small reachable area directly")

    env.restore()
end

function tests.retry_failed_start_viability_reports_clear_no_history_message()
    local env = make_env({
        map_id = 0x08,
        x = 10,
        y = 25,
        objects = {
            {id = "npc_1", name = "Guard", type = "npc", x = 10, y = 24},
        },
    })

    local ok, err = env.survey.report_start_viability("retry_failed")

    assert_equal(ok, false, "retry_failed preflight should fail cleanly when no prior failures are loaded")
    assert_equal(err, "No failed survey targets are currently loaded on map 08",
        "retry_failed preflight should explain that reload cleared the failed-target memory")
    assert_equal(env.survey.is_active(), false, "no-history preflight should not start a survey")

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_START_STATUS map=0x08 mode=retry_failed start=(10,25) targets=0 status=no_targets",
        "retry_failed preflight should log that no failed targets are currently available")

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

function tests.survey_defers_small_continuation_pocket_once()
    local env = make_env({
        objects = {
            {id = "trap_npc", name = "Trap NPC", type = "npc", x = 9, y = 5},
            {id = "safe_npc", name = "Safe NPC", type = "npc", x = 12, y = 5},
            {id = "safe_npc_2", name = "Safe NPC 2", type = "npc", x = 13, y = 5},
            {id = "safe_npc_3", name = "Safe NPC 3", type = "npc", x = 14, y = 5},
            {id = "safe_npc_4", name = "Safe NPC 4", type = "npc", x = 15, y = 5},
        },
        permanent_blocked = {
            ["7,5"] = true,
            ["8,4"] = true,
            ["9,4"] = true,
            ["8,6"] = true,
            ["9,6"] = true,
            ["10,4"] = true,
            ["10,5"] = true,
            ["10,6"] = true,
        },
        blocking = {
            ["9,5"] = "npc",
        },
        autowalk_fn = function(ctx)
            if ctx.target.id == "trap_npc" then
                return {
                    status = "queued",
                    result = "Approach: 3 east",
                    path_mode = "adjacent",
                    path = {
                        {x = 6, y = 5, direction = "east"},
                        {x = 7, y = 5, direction = "east"},
                        {x = 8, y = 5, direction = "east"},
                    },
                }
            end

            return {
                status = "queued",
                result = "Approach: 1 east",
                path_mode = "adjacent",
                path = {
                    {x = 6, y = 5, direction = "east"},
                },
            }
        end,
        alternate = {
            direct = {result = "No path found", path = nil},
            adjacent = {result = "No path found", path = nil},
        },
    })

    env.survey.start_object_survey()
    env.survey.tick(true)
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=1/5 defer=1 target_id=trap_npc reason=continuation_trap",
        "small landing pockets should be deferred once during broader surveys")
    assert_contains(joined, 'SURVEY_ATTEMPT run=1 map=0x08 idx=2/5 retry=0 target_id=safe_npc',
        "the next target should be attempted before revisiting the deferred pocket target")
    assert_contains(joined, 'SURVEY_ATTEMPT run=1 map=0x08 idx=1/5 retry=0 target_id=trap_npc',
        "the deferred target should be retried later rather than dropped")

    env.restore()
end

function tests.survey_defers_continuation_pocket_until_it_is_last_remaining_target()
    local env = make_env({
        objects = {
            {id = "trap_npc", name = "Trap NPC", type = "npc", x = 9, y = 5},
            {id = "safe_npc", name = "Safe NPC", type = "npc", x = 12, y = 5},
        },
        permanent_blocked = {
            ["7,5"] = true,
            ["8,4"] = true,
            ["9,4"] = true,
            ["8,6"] = true,
            ["9,6"] = true,
            ["10,4"] = true,
            ["10,5"] = true,
            ["10,6"] = true,
        },
        blocking = {
            ["9,5"] = "npc",
        },
        autowalk_fn = function(ctx)
            if ctx.target.id == "trap_npc" then
                return {
                    status = "queued",
                    result = "Approach: 4 east",
                    path_mode = "adjacent",
                    path = {
                        {x = 6, y = 5, direction = "east"},
                        {x = 7, y = 5, direction = "east"},
                        {x = 8, y = 5, direction = "east"},
                        {x = 9, y = 5, direction = "east"},
                    },
                }
            end

            return {
                status = "queued",
                result = "Approach: 1 east",
                path_mode = "adjacent",
                path = {
                    {x = 6, y = 5, direction = "east"},
                },
            }
        end,
        alternate = {
            direct = {result = "No path found", path = nil},
            adjacent = {result = "No path found", path = nil},
        },
    })

    env.survey.start_object_survey()
    env.survey.tick(true)
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=1/2 defer=1 target_id=trap_npc reason=continuation_trap landing=(9,5) reachable_area=0 remaining_targets=1",
        "trap targets should still defer while one other target remains")
    assert_before(
        joined,
        "SURVEY_ATTEMPT run=1 map=0x08 idx=2/2 retry=0 target_id=safe_npc",
        "SURVEY_ATTEMPT run=1 map=0x08 idx=1/2 retry=0 target_id=trap_npc",
        "the safe target should complete before the trap target is finally allowed")

    env.restore()
end

function tests.survey_can_defer_same_target_again_for_different_trap_landing()
    local trap_calls = 0
    local env = make_env({
        objects = {
            {id = "trap_npc", name = "Trap NPC", type = "npc", x = 9, y = 5},
            {id = "retry_1", name = "Retry 1", type = "npc", x = 12, y = 5},
            {id = "retry_2", name = "Retry 2", type = "npc", x = 13, y = 5},
            {id = "retry_3", name = "Retry 3", type = "npc", x = 14, y = 5},
            {id = "retry_4", name = "Retry 4", type = "npc", x = 15, y = 5},
            {id = "retry_5", name = "Retry 5", type = "npc", x = 16, y = 5},
        },
        permanent_blocked = {
            ["7,5"] = true,
            ["8,4"] = true,
            ["8,6"] = true,
            ["9,4"] = true,
            ["9,6"] = true,
            ["10,4"] = true,
            ["10,6"] = true,
        },
        blocking = {
            ["9,5"] = "npc",
        },
        autowalk_fn = function(ctx)
            if ctx.target.id == "trap_npc" then
                trap_calls = trap_calls + 1
                if trap_calls == 1 then
                    return {
                        status = "queued",
                        result = "Approach: 3 east",
                        path_mode = "adjacent",
                        path = {
                            {x = 6, y = 5, direction = "east"},
                            {x = 7, y = 5, direction = "east"},
                            {x = 8, y = 5, direction = "east"},
                        },
                    }
                end
                return {
                    status = "queued",
                    result = "Approach: 4 east",
                    path_mode = "adjacent",
                    path = {
                        {x = 6, y = 5, direction = "east"},
                        {x = 7, y = 5, direction = "east"},
                        {x = 8, y = 5, direction = "east"},
                        {x = 9, y = 5, direction = "east"},
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
    for _ = 1, 7 do
        env.survey.tick(true)
    end

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=1/6 defer=1 target_id=trap_npc reason=continuation_trap landing=(8,5)",
        "first trap landing should still be deferred")
    assert_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=1/6 defer=2 target_id=trap_npc reason=continuation_trap landing=(9,5)",
        "a different trap landing for the same target should be deferred too")

    env.restore()
end

function tests.survey_can_defer_same_target_again_for_same_trap_landing()
    local trap_calls = 0
    local env = make_env({
        objects = {
            {id = "trap_npc", name = "Trap NPC", type = "npc", x = 9, y = 5},
            {id = "retry_1", name = "Retry 1", type = "npc", x = 12, y = 5},
            {id = "retry_2", name = "Retry 2", type = "npc", x = 13, y = 5},
            {id = "retry_3", name = "Retry 3", type = "npc", x = 14, y = 5},
            {id = "retry_4", name = "Retry 4", type = "npc", x = 15, y = 5},
            {id = "retry_5", name = "Retry 5", type = "npc", x = 16, y = 5},
        },
        permanent_blocked = {
            ["7,5"] = true,
            ["8,4"] = true,
            ["9,4"] = true,
            ["8,6"] = true,
            ["9,6"] = true,
            ["10,4"] = true,
            ["10,6"] = true,
        },
        blocking = {
            ["9,5"] = "npc",
        },
        autowalk_fn = function(ctx)
            if ctx.target.id == "trap_npc" then
                trap_calls = trap_calls + 1
                return {
                    status = "queued",
                    result = "Approach: 4 east",
                    path_mode = "adjacent",
                    path = {
                        {x = 6, y = 5, direction = "east"},
                        {x = 7, y = 5, direction = "east"},
                        {x = 8, y = 5, direction = "east"},
                        {x = 9, y = 5, direction = "east"},
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
    for _ = 1, 7 do
        env.survey.tick(true)
    end

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=1/6 defer=1 target_id=trap_npc reason=continuation_trap landing=(9,5)",
        "first repeat trap landing should be deferred")
    assert_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=1/6 defer=2 target_id=trap_npc reason=continuation_trap landing=(9,5)",
        "same trap landing should be deferrable a second time")

    env.restore()
end

function tests.survey_can_defer_same_target_again_for_same_trap_landing_more_than_twice()
    local env = make_env({
        objects = {
            {id = "trap_npc_a", name = "Trap NPC A", type = "npc", x = 9, y = 5},
            {id = "trap_npc_b", name = "Trap NPC B", type = "npc", x = 9, y = 6},
        },
        permanent_blocked = {
            ["7,5"] = true,
            ["8,4"] = true,
            ["9,4"] = true,
            ["8,6"] = true,
            ["9,6"] = true,
            ["10,4"] = true,
            ["10,6"] = true,
        },
        blocking = {
            ["9,5"] = "npc",
        },
        autowalk_fn = function(ctx)
            if ctx.target.id == "trap_npc_a" or ctx.target.id == "trap_npc_b" then
                return {
                    status = "queued",
                    result = "Approach: 4 east",
                    path_mode = "adjacent",
                    path = {
                        {x = 6, y = 5, direction = "east"},
                        {x = 7, y = 5, direction = "east"},
                        {x = 8, y = 5, direction = "east"},
                        {x = 9, y = 5, direction = "east"},
                    },
                }
            end
        end,
        alternate = {
            direct = {result = "No path found", path = nil},
            adjacent = {result = "No path found", path = nil},
        },
    })

    env.survey.start_object_survey()
    for _ = 1, 6 do
        env.survey.tick(true)
    end

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=1/2 defer=3 target_id=trap_npc_a reason=continuation_trap landing=(9,5)",
        "same trap landing should keep deferring while other worthwhile targets remain")

    env.restore()
end

function tests.endgame_paired_continuation_traps_do_not_ping_pong_forever()
    local env = make_env({
        objects = {
            {id = "trap_a", name = "Trap A", type = "npc", x = 9, y = 5},
            {id = "trap_b", name = "Trap B", type = "npc", x = 10, y = 5},
        },
        permanent_blocked = {
            ["7,5"] = true,
            ["8,4"] = true,
            ["9,4"] = true,
            ["8,6"] = true,
            ["9,6"] = true,
            ["10,4"] = true,
            ["10,5"] = true,
            ["10,6"] = true,
        },
        blocking = {
            ["9,5"] = "npc",
            ["10,5"] = "npc",
        },
        autowalk_fn = function()
            return {
                status = "queued",
                result = "Approach: 3 east",
                path_mode = "adjacent",
                path = {
                    {x = 6, y = 5, direction = "east"},
                    {x = 7, y = 5, direction = "east"},
                    {x = 8, y = 5, direction = "east"},
                },
            }
        end,
        plan_fn = function()
            return {
                result = "Approach: 3 east",
                path_mode = "adjacent",
                path = {
                    {x = 6, y = 5, direction = "east"},
                    {x = 7, y = 5, direction = "east"},
                    {x = 8, y = 5, direction = "east"},
                },
            }
        end,
        alternate = {
            direct = {result = "No path found", path = nil},
            adjacent = {result = "Approach: 3 east", path = {
                {x = 6, y = 5, direction = "east"},
                {x = 7, y = 5, direction = "east"},
                {x = 8, y = 5, direction = "east"},
            }},
        },
    })

    env.survey.start_object_survey()
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)

    local joined = table.concat(env.logs, "\n")
    local run = env.survey.get_last_run(0x08)
    assert_contains(joined, "SURVEY_ENDGAME_ALLOW run=1 map=0x08 idx=1/2 target_id=trap_a other_target_id=trap_b landing=(8,5) reachable_area=1 reason=paired_continuation_traps remaining_targets=1",
        "when the last two pending targets are both continuation traps, the survey should stop deferring and allow one through")
    assert_not_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=1/2 defer=1 target_id=trap_a",
        "the first endgame trap target should not be endlessly deferred")
    assert_equal(run.summary.successes, 2, "paired endgame trap targets should be allowed to complete instead of ping-ponging")

    env.restore()
end

function tests.reorder_does_not_misfire_paired_trap_allow_when_next_later_entry_is_same_target()
    local env = make_env({
        objects = {
            {id = "stale_npc", name = "Stale NPC", type = "npc", x = 12, y = 5},
            {id = "trap_npc", name = "Trap NPC", type = "npc", x = 9, y = 5},
        },
        permanent_blocked = {
            ["7,5"] = true,
            ["8,4"] = true,
            ["9,4"] = true,
            ["8,6"] = true,
            ["9,6"] = true,
            ["10,4"] = true,
            ["10,5"] = true,
            ["10,6"] = true,
        },
        blocking = {
            ["9,5"] = "npc",
        },
        autowalk_fn = function(ctx)
            if ctx.target.id == "trap_npc" then
                return {
                    status = "queued",
                    result = "Approach: 3 east",
                    path_mode = "adjacent",
                    path = {
                        {x = 6, y = 5, direction = "east"},
                        {x = 7, y = 5, direction = "east"},
                        {x = 8, y = 5, direction = "east"},
                    },
                }
            end

            return {
                status = "no_path",
                result = "No path found",
                path_mode = "direct",
                path = nil,
            }
        end,
        plan_fn = function(target, opts)
            if target.id == "trap_npc" then
                return {
                    result = "Approach: 3 east",
                    path_mode = opts and opts.path_mode or "adjacent",
                    path = {
                        {x = 6, y = 5, direction = "east"},
                        {x = 7, y = 5, direction = "east"},
                        {x = 8, y = 5, direction = "east"},
                    },
                }
            end
            return {
                result = "No path found",
                path_mode = opts and opts.path_mode or "direct",
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
    env.survey.tick(true)
    env.survey.tick(true)
    env.survey.tick(true)

    local joined = table.concat(env.logs, "\n")
    assert_not_contains(joined, "SURVEY_ENDGAME_ALLOW run=1 map=0x08 idx=2/2 target_id=trap_npc other_target_id=trap_npc",
        "endgame trap allowance should not trigger when the only later entry is the same deferred target")
    assert_not_contains(joined, "SURVEY_REORDER run=1 map=0x08 start=(5,5) queue_from=4 queue_to=3 target_id=trap_npc",
        "queue reprioritization should not pull the same deferred trap target forward on top of a stale retry")

    env.restore()
end

function tests.reachable_retry_is_promoted_ahead_of_stale_no_path_retry()
    local attempt_counts = {}
    local env = make_env({
        objects = {
            {id = "npc_a", name = "NPC A", type = "npc", x = 8, y = 5},
            {id = "npc_b", name = "NPC B", type = "npc", x = 9, y = 5},
        },
        autowalk_fn = function(ctx)
            attempt_counts[ctx.target.id] = (attempt_counts[ctx.target.id] or 0) + 1
            if ctx.target.id == "npc_b" and attempt_counts[ctx.target.id] >= 2 then
                return {
                    status = "queued",
                    result = "Path: 2 east",
                    path_mode = "direct",
                    path = {
                        {x = 6, y = 5, direction = "east"},
                        {x = 7, y = 5, direction = "east"},
                    },
                }
            end
            return {
                status = "no_path",
                result = "No path found",
                path_mode = "direct",
                path = nil,
            }
        end,
        plan_fn = function(target, opts)
            local mode = opts and opts.path_mode or "direct"
            if mode == "direct"
                and not (opts and opts.skip_npcs)
                and target.id == "npc_b"
                and (attempt_counts[target.id] or 0) >= 1
            then
                return {
                    result = "Path: 2 east",
                    path = {
                        {x = 6, y = 5, direction = "east"},
                        {x = 7, y = 5, direction = "east"},
                    },
                }
            end
            return {
                result = "No path found",
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
    env.survey.tick(true)
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)
    env.survey.tick(true)

    local run = env.survey.get_last_run(0x08)
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_REORDER run=1 map=0x08 start=(5,5) queue_from=4 queue_to=3 target_id=npc_b retry=1 path_length=2 replaced_target_id=npc_a reason=reachable_priority",
        "reachable retries should be promoted ahead of stale no-path retries")
    assert_before(
        joined,
        "SURVEY_REORDER run=1 map=0x08 start=(5,5) queue_from=4 queue_to=3 target_id=npc_b retry=1 path_length=2 replaced_target_id=npc_a reason=reachable_priority",
        "SURVEY_ATTEMPT run=1 map=0x08 idx=2/2 retry=1 target_id=npc_b",
        "reordered retry should be attempted immediately")
    assert_before(
        joined,
        "SURVEY_ATTEMPT run=1 map=0x08 idx=2/2 retry=1 target_id=npc_b",
        "SURVEY_RESULT run=1 map=0x08 target_id=npc_a",
        "the rescued reachable retry should run before the stale retry is consumed")
    assert_equal(run.summary.successes, 1, "reachable retried target should still complete successfully")
    assert_equal(run.summary.failures, 1, "stale retry should remain recorded as a failure")

    env.restore()
end

function tests.reorder_skips_candidates_that_still_qualify_for_continuation_trap_deferral()
    local attempt_counts = {}
    local env = make_env({
        objects = {
            {id = "npc_a", name = "NPC A", type = "npc", x = 8, y = 5},
            {id = "trap_npc", name = "Trap NPC", type = "npc", x = 9, y = 5},
            {id = "npc_b", name = "NPC B", type = "npc", x = 12, y = 5},
            {id = "filler_1", name = "Filler 1", type = "npc", x = 13, y = 5},
            {id = "filler_2", name = "Filler 2", type = "npc", x = 14, y = 5},
            {id = "filler_3", name = "Filler 3", type = "npc", x = 15, y = 5},
            {id = "filler_4", name = "Filler 4", type = "npc", x = 16, y = 5},
            {id = "npc_c", name = "NPC C", type = "npc", x = 17, y = 5},
            {id = "npc_d", name = "NPC D", type = "npc", x = 18, y = 5},
        },
        permanent_blocked = {
            ["7,5"] = true,
            ["8,4"] = true,
            ["9,4"] = true,
            ["8,6"] = true,
            ["9,6"] = true,
            ["10,4"] = true,
            ["10,5"] = true,
            ["10,6"] = true,
        },
        blocking = {
            ["9,5"] = "npc",
        },
        autowalk_fn = function(ctx)
            local id = ctx.target.id
            attempt_counts[id] = (attempt_counts[id] or 0) + 1
            if id == "trap_npc" then
                return {
                    status = "queued",
                    result = "Approach: 4 east",
                    path_mode = "adjacent",
                    path = {
                        {x = 6, y = 5, direction = "east"},
                        {x = 7, y = 5, direction = "east"},
                        {x = 8, y = 5, direction = "east"},
                        {x = 9, y = 5, direction = "east"},
                    },
                }
            end
            if id == "npc_b" and attempt_counts[id] >= 2 then
                return {
                    status = "queued",
                    result = "Path: 1 south, 1 east",
                    path_mode = "direct",
                    path = {
                        {x = 5, y = 6, direction = "south"},
                        {x = 6, y = 6, direction = "east"},
                    },
                }
            end
            if string.sub(id, 1, 6) == "filler" then
                return {
                    status = "queued",
                    result = "Path: 1 east",
                    path_mode = "direct",
                    path = {
                        {x = 6, y = 5, direction = "east"},
                    },
                }
            end
            return {
                status = "no_path",
                result = "No path found",
                path_mode = "direct",
                path = nil,
            }
        end,
        plan_fn = function(target, opts)
            local mode = opts and opts.path_mode or "direct"
            if target.id == "trap_npc" then
                return {
                    result = "Approach: 4 east",
                    path_mode = "adjacent",
                    path = {
                        {x = 6, y = 5, direction = "east"},
                        {x = 7, y = 5, direction = "east"},
                        {x = 8, y = 5, direction = "east"},
                        {x = 9, y = 5, direction = "east"},
                    },
                }
            end
            if mode == "direct"
                and not (opts and opts.skip_npcs)
                and target.id == "npc_b"
                and (attempt_counts[target.id] or 0) >= 1
            then
                return {
                    result = "Path: 1 south, 1 east",
                    path = {
                        {x = 5, y = 6, direction = "south"},
                        {x = 6, y = 6, direction = "east"},
                    },
                }
            end
            return {
                result = "No path found",
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
    env.survey.tick(true)
    env.survey.tick(true)
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)
    env.survey.tick(true)
    env.survey.tick(true)

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=2/9 defer=1 target_id=trap_npc reason=continuation_trap landing=(9,5)",
        "trap candidate should be deferred during the initial pass")
    assert_contains(joined, "SURVEY_REORDER run=1 map=0x08 start=(5,5) queue_from=12 queue_to=10 target_id=npc_b retry=1 path_length=2 replaced_target_id=npc_a reason=reachable_priority",
        "reorder should choose the safe reachable retry instead of the deferred trap target")
    assert_not_contains(joined, "SURVEY_REORDER run=1 map=0x08 start=(5,5) queue_from=11 queue_to=10 target_id=trap_npc",
        "reorder should not pull a deferred continuation-trap target back to the front")
    assert_before(
        joined,
        "SURVEY_REORDER run=1 map=0x08 start=(5,5) queue_from=12 queue_to=10 target_id=npc_b retry=1 path_length=2 replaced_target_id=npc_a reason=reachable_priority",
        "SURVEY_ATTEMPT run=1 map=0x08 idx=3/9 retry=1 target_id=npc_b",
        "the safe retry should run immediately after it is promoted")

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
