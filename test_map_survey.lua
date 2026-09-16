-- test_map_survey.lua
-- Focused unit tests for the autonomous survey workflow.

local original_preload = {}
local original_loaded = {}
local original_memory = _G.memory
local original_and = _G.AND

local function shallow_copy(tbl)
    local copy = {}
    if not tbl then
        return copy
    end
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

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
    local autowalk_calls = 0
    local plan_call_count = 0
    local plan_calls = {}
    local nav_map_id = options.map_id or 0x08
    local nav_x = options.x or 5
    local nav_y = options.y or 5
    local object = options.object or {id = "chest_1", name = "Chest", type = "chest", x = 8, y = 5}
    local objects_list = options.objects or {object}
    local npc_bytes = {[0x00C5] = options.hp or 30}
    local input_refusal = options.input_refusal
    local active_step_state = options.active_step_state
    local module_names = {
        "addresses",
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

    if options.npc_bytes then
        for address, value in pairs(options.npc_bytes) do
            npc_bytes[address] = value
        end
    end

    _G.AND = _G.AND or function(a, b)
        local result = 0
        local bit = 1
        while a > 0 and b > 0 do
            local a_bit = a % 2
            local b_bit = b % 2
            if a_bit == 1 and b_bit == 1 then
                result = result + bit
            end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            bit = bit * 2
        end
        return result
    end

    _G.memory = {
        readbyte = function(address)
            return npc_bytes[address] or 0
        end,
        writebyte = function(address, value)
            npc_bytes[address] = value
        end,
    }

    package.preload["addresses"] = function()
        return {
            NPC_COUNT = 20,
            NPC_DATA_START = 0x0051,
            NPC_ENTRY_SIZE = 3,
            CURRENT_HP = 0x00C5,
        }
    end

    package.preload["debug_tools"] = function()
        local function input_refusal_details(value)
            if type(value) == "table" then
                return tostring(value.details or "")
            end
            return tostring(value)
        end

        local function input_refusal_allowed(value, opts)
            return type(value) == "table"
                and value.allow_route_blocked_self_input == true
                and opts
                and opts.allow_route_blocked_self_input == true
                and opts.route_blocked_timing_suspect == true
                and tostring(opts.route_blocked_dir or "") == tostring(value.route_blocked_dir or "")
        end

        return {
            DEBUG_MODE = true,
            info = function(msg) logs[#logs + 1] = tostring(msg) end,
            debug = function(msg) logs[#logs + 1] = tostring(msg) end,
            error = function(msg) logs[#logs + 1] = tostring(msg) end,
            input_contamination_refusal = function(command_name, opts)
                if not input_refusal then
                    return nil
                end
                if input_refusal_allowed(input_refusal, opts) then
                    logs[#logs + 1] = "INPUT_CONTAMINATION_IGNORED test_stub"
                    return nil
                end
                local details = input_refusal_details(input_refusal)
                return string.format(
                    "%s refused: input contaminated (%s)",
                    tostring(command_name or "command"),
                    details),
                    details
            end,
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
            get_active_step_state = function() return active_step_state end,
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
                autowalk_calls = autowalk_calls + 1
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
                plan_call_count = plan_call_count + 1
                plan_calls[#plan_calls + 1] = {
                    target_id = target and target.id or nil,
                    start_x = opts and opts.start_x or nil,
                    start_y = opts and opts.start_y or nil,
                    map_id = opts and opts.map_id or nil,
                    path_mode = opts and opts.path_mode or nil,
                    skip_npcs = opts and opts.skip_npcs or false,
                    blocking = opts and opts.blocking and shallow_copy(opts.blocking) or nil,
                }
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
            get_seam_observation = function(_, x, y, approach)
                local observations = options.seam_observations or {}
                return observations[string.format("%d,%d:%s", x, y, tostring(approach))]
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
        route_active = function()
            return route_active
        end,
        set_position = function(map_id, x, y)
            nav_map_id = map_id or nav_map_id
            nav_x = x or nav_x
            nav_y = y or nav_y
        end,
        clear_route_context_calls = function()
            return package.loaded["route_manager"] and clear_route_context_calls or 0
        end,
        autowalk_calls = function() return autowalk_calls end,
        plan_call_count = function()
            return plan_call_count
        end,
        plan_calls = function()
            return plan_calls
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
            _G.memory = original_memory
            _G.AND = original_and
        end,
        set_input_refusal = function(value)
            input_refusal = value
        end,
        set_active_step_state = function(value)
            active_step_state = value
        end,
        set_route_active = function(value)
            route_active = value == true
        end,
        read_npc_slot = function(slot)
            local base = 0x0051 + (slot * 3)
            return npc_bytes[base] or 0, npc_bytes[base + 1] or 0, npc_bytes[base + 2] or 0
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

local function count_occurrences(haystack, needle)
    local count = 0
    local pos = 1
    while true do
        local next_pos = string.find(haystack, needle, pos, true)
        if not next_pos then
            return count
        end
        count = count + 1
        pos = next_pos + #needle
    end
end

local tests = {}

function tests.battle_started_pauses_survey_without_recording_failed_target()
    local env = make_env()

    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    assert_equal(env.route_active(), true, "survey should begin by queueing an auto-walk route")

    env.publish("battle_started")
    assert_equal(env.route_active(), false, "battle pause should cancel the active route")

    env.survey.tick(false)
    local paused_logs = table.concat(env.logs, "\n")
    assert_contains(paused_logs, "SURVEY_PAUSE run=1 map=0x08 reason=battle_started target_id=chest_1",
        "battle start should be logged as a survey pause")
    assert_not_contains(paused_logs, "SURVEY_RESULT", "battle pause should not finalize the target as a failure")
    assert_equal(env.survey.get_last_run(0x08), nil, "paused survey should not produce a completed run")

    env.survey.tick(true)
    local resumed_logs = table.concat(env.logs, "\n")
    assert_contains(resumed_logs, "SURVEY_RESUME run=1 map=0x08 reason=battle_started target_id=chest_1",
        "survey should log resume after field movement becomes safe again")
    assert_equal(count_occurrences(resumed_logs, "SURVEY_ATTEMPT run=1"), 2,
        "the interrupted target should be attempted again after battle")
    assert_equal(env.route_active(), true, "survey should queue the route again after resume")

    env.publish("route_completed", {})
    env.survey.tick(true)
    local final_logs = table.concat(env.logs, "\n")
    assert_contains(final_logs, "SURVEY_RESULT run=1 map=0x08 target_id=chest_1",
        "resumed survey should still record the completed target")
    assert_contains(final_logs, "movement_succeeded=true",
        "resumed target should be recorded as successful")
    assert_equal(count_occurrences(final_logs, "SURVEY_RESULT run=1"), 1,
        "battle interruption should not create an extra failed result")

    env.restore()
end

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

function tests.reroute_only_retry_success_stays_diagnostic_until_direct_repro()
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
    assert_equal(env.survey.report_strong_candidates(0x08), 0, "reroute-only evidence should wait for focused repro")
    assert_equal(env.survey.report_candidate_suggestions(0x08), 0, "reroute-only candidates should not produce pasteable suggestions")
    assert_equal(env.survey.export_directional_candidates(0x08), 0, "reroute-only candidates should not export directional blocks")
    assert_equal(env.survey.export_blocked_candidates(0x08), 0, "reroute-only candidates should not export pasteable blocked data")
    assert_contains(table.concat(env.logs, "\n"), "confidence=needs_repro",
        "retry success without direct repro should be marked as needing confirmation")
    assert_contains(table.concat(env.logs, "\n"), "SURVEY_CANDIDATE_EXPORT_SKIP",
        "diagnostic-only candidates should be explicitly skipped by blocked export")

    env.restore()
end

function tests.timing_suspect_route_block_is_ignored_as_candidate()
    local env = make_env()

    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    env.publish("route_blocked", {
        from_x = 5,
        from_y = 5,
        dir = "right",
        timing_suspect = true,
    })
    env.publish("route_completed")
    env.survey.tick(true)

    local run = env.survey.get_last_run(0x08)
    local result = run and run.results[1]
    assert_equal(result.movement_succeeded, true, "timing-suspect retry should still allow route success")
    assert_equal(result.blocked_event_count, 0, "timing-suspect route blocks should not count as survey blockers")
    assert_equal(result.retry_succeeded, false, "timing-suspect route blocks should not be treated as reroute evidence")
    assert_equal(env.survey.list_blocked_candidates(0x08), 0, "timing-suspect route blocks should not become candidates")
    assert_contains(
        table.concat(env.logs, "\n"),
        "SURVEY_TIMING_BLOCK_IGNORED",
        "survey should log when it ignores a timing-suspect route block"
    )

    env.restore()
end

function tests.directly_confirmed_retry_candidate_is_exportable()
    local env = make_env({
        seam_observations = {
            ["6,5:west"] = {
                blocked_count = 3,
                moved_count = 0,
                last_result = "blocked",
                last_source = "manual_block",
            },
        },
    })

    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    env.publish("route_blocked", {from_x = 5, from_y = 5, dir = "right"})
    env.publish("route_blocked", {from_x = 6, from_y = 6, dir = "up"})
    env.publish("route_completed")
    env.survey.tick(true)

    assert_equal(env.survey.list_blocked_candidates(0x08), 1, "candidate list should contain the implicated tile")
    assert_equal(env.survey.report_strong_candidates(0x08), 1, "directly confirmed reroute evidence should be strong")
    assert_equal(env.survey.report_candidate_suggestions(0x08), 1, "directly confirmed candidates should produce suggestions")
    assert_equal(env.survey.export_directional_candidates(0x08), 1, "directional export should include directly confirmed approaches")
    assert_equal(env.survey.export_blocked_candidates(0x08), 1, "blocked export should include directly confirmed candidates")
    assert_contains(table.concat(env.logs, "\n"), "confidence=high",
        "manual direct repro should raise the candidate confidence")
    assert_contains(table.concat(env.logs, "\n"), '["6,5"] = {west=true}',
        "directional export should include only directly confirmed approaches for reroute-only evidence")

    env.restore()
end

function tests.noisy_seam_candidate_is_downgraded()
    local env = make_env({
        seam_observations = {
            ["6,5:west"] = {
                blocked_count = 3,
                moved_count = 1,
                last_result = "moved",
                last_source = "auto_hold",
            },
        },
    })

    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    env.publish("route_blocked", {from_x = 5, from_y = 5, dir = "right"})
    env.publish("route_completed")
    env.survey.tick(true)

    assert_equal(env.survey.list_blocked_candidates(0x08), 1, "noisy candidate should remain visible")
    assert_equal(env.survey.report_strong_candidates(0x08), 0, "noisy candidates should not be strong")
    assert_equal(env.survey.report_candidate_suggestions(0x08), 0, "noisy candidates should not produce pasteable suggestions")
    assert_equal(env.survey.export_blocked_candidates(0x08), 0, "noisy candidates should not export pasteable blocked data")
    assert_contains(table.concat(env.logs, "\n"), "confidence=needs_repro",
        "mixed moved/blocked seam evidence should need repro")
    assert_contains(table.concat(env.logs, "\n"), "SURVEY_CANDIDATE_EXPORT_SKIP",
        "noisy candidates should be reported as skipped diagnostics")

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

function tests.survey_start_refuses_contaminated_input()
    local env = make_env({
        input_refusal = "keys=LeftAlt joy=- bridge=- buttons=0x20",
    })

    local ok, err = env.survey.start_target_survey("chest_1")

    assert_equal(ok, false, "contaminated input should refuse survey startup")
    assert_contains(err or "", "input contaminated", "startup error should explain contamination")
    assert_equal(env.survey.is_active(), false, "refused survey should not remain active")
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_START_ABORT", "survey should log the startup abort")
    assert_contains(joined, "reason=input_contaminated", "survey should tag input contamination aborts")
    assert_contains(joined, "buttons=0x20", "survey abort log should include the stuck game button byte")

    env.restore()
end

function tests.active_survey_aborts_contaminated_route_block_without_candidates()
    local env = make_env()

    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    env.set_input_refusal("keys=LeftAlt joy=- bridge=- buttons=0x20")
    env.publish("route_blocked", {from_x = 5, from_y = 5, dir = "right"})

    assert_equal(env.survey.is_active(), false, "contaminated route evidence should stop the active survey")
    assert_equal(env.route_active(), false, "survey abort should cancel the active auto-step route")
    assert_equal(env.clear_route_context_calls() > 0, true, "survey abort should clear route manager context")
    assert_equal(env.survey.list_blocked_candidates(0x08), 0, "contaminated route block should not record candidates")
    local run = env.survey.get_last_run(0x08)
    assert_equal(run and #run.results or -1, 0, "contaminated in-flight attempt should not become a survey result")
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_ABORT", "survey should log the active abort")
    assert_contains(joined, "reason=input_contaminated", "active abort should tag input contamination")
    assert_contains(joined, "source=route_blocked", "active abort should identify the route event source")
    assert_not_contains(joined, "SURVEY_CANDIDATE map=0x08", "contaminated blocks should not be visible candidates")

    env.restore()
end

function tests.active_survey_allows_timing_suspect_route_blocked_self_input()
    local env = make_env()

    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    env.set_input_refusal({
        details = "keys=LeftAlt joy=- bridge=- buttons=0x20",
        allow_route_blocked_self_input = true,
        route_blocked_dir = "down",
    })
    env.publish("route_blocked", {
        from_x = 5,
        from_y = 5,
        dir = "down",
        timing_suspect = true,
        source = "queued_route",
    })

    assert_equal(env.survey.is_active(), true, "self-injected timing-suspect route input should not abort the survey")
    assert_equal(env.route_active(), true, "self-injected route-block input should leave the route active for retry handling")
    assert_equal(env.survey.list_blocked_candidates(0x08), 0, "timing-suspect self input should not record survey candidates")
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_TIMING_BLOCK_IGNORED", "timing-suspect route block should still be ignored by survey evidence")
    assert_not_contains(joined, "SURVEY_ABORT", "self-injected timing-suspect input should not abort the survey")

    env.restore()
end

function tests.active_survey_tick_aborts_contaminated_input_without_route_event()
    local env = make_env()

    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    env.set_input_refusal("keys=LeftAlt joy=- bridge=- buttons=0x20")
    env.set_route_active(false)
    env.survey.tick(true)

    assert_equal(env.survey.is_active(), false, "tick should stop a survey when contamination appears between events")
    assert_equal(env.route_active(), false, "tick abort should cancel the active auto-step route")
    assert_equal(env.survey.list_blocked_candidates(0x08), 0, "tick contamination abort should not create candidates")
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_ABORT", "tick should log the survey abort")
    assert_contains(joined, "source=tick", "tick abort should identify its source")
    assert_contains(joined, "buttons=0x20", "tick abort should include the stuck game button byte")

    env.restore()
end

function tests.active_survey_tick_does_not_abort_contamination_signature_during_active_route_settle()
    local env = make_env()

    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    env.set_input_refusal("keys=LeftAlt joy=- bridge=- buttons=0x80")
    env.set_active_step_state(nil)
    env.set_route_active(true)
    env.survey.tick(true)

    assert_equal(env.survey.is_active(), true, "active queued route settle should not be treated as idle input contamination")
    assert_equal(env.route_active(), true, "active queued route false positive should not cancel the route")
    local joined = table.concat(env.logs, "\n")
    assert_not_contains(joined, "SURVEY_ABORT", "active queued route false positive should not abort the survey")

    env.restore()
end

function tests.active_survey_tick_does_not_abort_contamination_signature_during_active_auto_step()
    local env = make_env()

    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    env.set_input_refusal("keys=LeftAlt joy=- bridge=- buttons=0x10")
    env.set_active_step_state({
        dir = "up",
        source = "queued_route",
        movement_started = true,
    })
    env.survey.tick(true)

    assert_equal(env.survey.is_active(), true, "active auto-step movement should not be treated as idle input contamination")
    assert_equal(env.route_active(), true, "active auto-step false positive should not cancel the route")
    local joined = table.concat(env.logs, "\n")
    assert_not_contains(joined, "SURVEY_ABORT", "active auto-step false positive should not abort the survey")

    env.restore()
end

function tests.orphaned_route_landed_on_suspect_is_classified_as_state_issue()
    local env = make_env()

    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    env.publish("route_blocked", {from_x = 5, from_y = 5, dir = "right"})
    env.set_position(0x08, 6, 5)
    env.set_route_active(false)
    env.survey.tick(true)
    env.survey.tick(true)
    env.survey.tick(true)

    local run = env.survey.get_last_run(0x08)
    local result = run and run.results[1]
    assert_equal(result.movement_succeeded, false, "orphaned route should record a failure")
    assert_equal(
        result.failure_classification,
        "command_timing_or_state_issue",
        "an orphaned route that landed on the suspected tile should not become blocker evidence"
    )
    assert_contains(
        table.concat(env.logs, "\n"),
        "SURVEY_CLASSIFY_DOWNGRADE",
        "classifier should log the downgrade reason"
    )

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
    assert_equal(env.survey.list_blocked_candidates(0x08), 2, "state-issue candidates should remain visible for diagnostics")
    assert_equal(env.survey.report_strong_candidates(0x08), 0, "state-issue-only candidates should not be strong map-data candidates")
    assert_equal(env.survey.report_candidate_suggestions(0x08), 0, "state-issue-only candidates should not produce pasteable suggestions")
    assert_equal(env.survey.export_directional_candidates(0x08), 0, "state-issue-only candidates should not export directional blocks")
    assert_equal(env.survey.export_blocked_candidates(0x08), 0, "state-issue-only candidates should not export pasteable blocked data")
    assert_contains(table.concat(env.logs, "\n"), "confidence=needs_repro",
        "state-issue-only candidates should be marked as needing direct repro")

    env.restore()
end

function tests.route_churn_cap_stops_target_as_state_issue()
    local env = make_env()

    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    for _ = 1, 33 do
        env.publish("route_blocked", {from_x = 5, from_y = 5, dir = "right"})
    end

    local run = env.survey.get_last_run(0x08)
    local result = run and run.results[1]
    local joined = table.concat(env.logs, "\n")
    assert_equal(env.survey.is_active(), false, "route churn cap should stop the active survey")
    assert_equal(env.route_active(), false, "route churn cap should cancel the active route")
    assert_equal(env.clear_route_context_calls() > 0, true, "route churn cap should clear route manager context")
    assert_equal(result.movement_succeeded, false, "capped target should be recorded as a failed movement attempt")
    assert_equal(result.failure_classification, "command_timing_or_state_issue",
        "route churn cap should not promote noisy reroute evidence as map truth")
    assert_equal(result.blocked_event_count, 33, "capped result should preserve the observed block count")
    assert_equal(result.reason, "route_churn_cap", "result should explain the safety stop")
    assert_equal(run.summary.command_timing_or_state_issue, 1,
        "route churn cap should be counted as a state issue")
    assert_equal(env.survey.report_strong_candidates(0x08), 0,
        "route churn candidates should not become strong map-data candidates")
    assert_equal(env.survey.export_directional_candidates(0x08), 0,
        "route churn candidates should not export directional blocks")
    assert_contains(joined, "SURVEY_ROUTE_CHURN_ABORT",
        "survey should log the route churn safety stop")

    env.restore()
end

function tests.manual_stop_after_repeated_timing_blocks_is_state_issue_not_engine_block()
    local env = make_env()

    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    for _ = 1, 4 do
        env.publish("route_blocked", {from_x = 5, from_y = 5, dir = "right"})
    end
    local ok = env.survey.stop_survey()

    local run = env.survey.get_last_run(0x08)
    local result = run and run.results[1]
    assert_equal(ok, true, "manual stop should stop the survey")
    assert_equal(result.reason, "manual_stop", "result should preserve the manual stop reason")
    assert_equal(result.failure_classification, "command_timing_or_state_issue",
        "manual-stop churn evidence should not become suspected engine-blocked geometry")
    assert_equal(run.summary.command_timing_or_state_issue, 1,
        "manual-stop churn should count as a state issue")
    assert_equal(run.summary.suspected_engine_blocked_tile, 0,
        "manual-stop churn should not count as suspected engine-blocked")
    assert_equal(env.survey.report_strong_candidates(0x08), 0,
        "manual-stop churn candidates should not be strong map-data candidates")

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

function tests.route_drift_cancellation_is_retried_once_from_live_position()
    local env = make_env({
        autowalk_sequence = {
            {
                status = "queued",
                result = "Path: north then east",
                path_mode = "adjacent",
                path = {
                    {x = 5, y = 4, direction = "north"},
                    {x = 6, y = 4, direction = "east"},
                },
            },
            {
                status = "queued",
                result = "Path: corrected from drift",
                path_mode = "adjacent",
                path = {
                    {x = 6, y = 3, direction = "east"},
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
    env.set_position(0x08, 5, 3)
    env.publish("route_cancelled", {reason = "route_drift_off_path"})
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)

    local run = env.survey.get_last_run(0x08)
    local result = run and run.results[1]
    local joined = table.concat(env.logs, "\n")
    assert_equal(run.summary.successes, 1, "same-map route drift should get one clean retry")
    assert_equal(run.summary.failures, 0, "successful drift retry should not pollute survey failures")
    assert_equal(result.movement_succeeded, true, "requeued route drift should be able to succeed on retry")
    assert_contains(joined, "SURVEY_REQUEUE run=1 map=0x08 target_id=chest_1 reason=route_drift_retry retry=1",
        "route drift should be retried once as timing noise")
    assert_contains(joined, "SURVEY_ATTEMPT run=1 map=0x08 idx=1/1 retry=1 target_id=chest_1 target_type=chest target_name=\"Chest\" start=(5,3)",
        "route drift retry should plan from the live drifted position")

    env.restore()
end

function tests.route_drift_retry_runs_before_later_survey_targets()
    local env = make_env({
        objects = {
            {id = "chest_1", name = "Chest 1", type = "chest", x = 8, y = 5},
            {id = "chest_2", name = "Chest 2", type = "chest", x = 9, y = 5},
        },
        autowalk_sequence = {
            {
                status = "queued",
                result = "Path: north then east",
                path_mode = "adjacent",
                path = {
                    {x = 5, y = 4, direction = "north"},
                    {x = 6, y = 4, direction = "east"},
                },
            },
            {
                status = "queued",
                result = "Path: corrected from drift",
                path_mode = "adjacent",
                path = {
                    {x = 6, y = 3, direction = "east"},
                },
            },
            {
                status = "queued",
                result = "Path: later target",
                path_mode = "adjacent",
                path = {
                    {x = 7, y = 3, direction = "east"},
                },
            },
        },
        alternate = {
            direct = {result = "No path found", path = nil},
            adjacent = {result = "No path found", path = nil},
        },
    })

    env.survey.start_object_survey()
    env.survey.tick(true)
    env.set_position(0x08, 5, 3)
    env.publish("route_cancelled", {reason = "route_drift_off_path"})
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)
    env.survey.tick(true)

    local joined = table.concat(env.logs, "\n")
    assert_contains(
        joined,
        "retry=1 target_id=chest_1 target_type=chest target_name=\"Chest 1\" start=(5,3)",
        "route drift should immediately retry the drifted target"
    )
    assert_contains(
        joined,
        "retry=0 target_id=chest_2",
        "survey should still continue to the later target"
    )
    assert_before(
        joined,
        "retry=1 target_id=chest_1",
        "retry=0 target_id=chest_2",
        "route drift retry should run before later survey targets consume the drifted position"
    )

    env.restore()
end

function tests.route_drift_retry_is_still_allowed_after_transient_no_path_retry()
    local env = make_env({
        autowalk_sequence = {
            {
                status = "no_path",
                result = "No path found",
                path_mode = "adjacent",
                path = nil,
            },
            {
                status = "queued",
                result = "Path: north then east",
                path_mode = "adjacent",
                path = {
                    {x = 5, y = 4, direction = "north"},
                    {x = 6, y = 4, direction = "east"},
                },
            },
            {
                status = "queued",
                result = "Path: corrected from drift",
                path_mode = "adjacent",
                path = {
                    {x = 6, y = 3, direction = "east"},
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
    env.set_position(0x08, 5, 3)
    env.publish("route_cancelled", {reason = "route_drift_off_path"})
    env.survey.tick(true)
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)

    local run = env.survey.get_last_run(0x08)
    local result = run and run.results[1]
    local joined = table.concat(env.logs, "\n")
    assert_equal(run.summary.successes, 1, "route drift after a transient no-path retry should still get one correction attempt")
    assert_equal(run.summary.failures, 0, "successful drift retry should not leave a state issue failure")
    assert_equal(result.movement_succeeded, true, "second retry should be able to finish the target")
    assert_contains(joined, "SURVEY_REQUEUE run=1 map=0x08 target_id=chest_1 reason=transient_no_path retry=1",
        "initial no-path should still consume only the transient planning retry")
    assert_contains(joined, "SURVEY_REQUEUE run=1 map=0x08 target_id=chest_1 reason=route_drift_retry retry=2",
        "later route drift should get a separate retry reason slot")
    assert_contains(joined, "SURVEY_ATTEMPT run=1 map=0x08 idx=1/1 retry=2 target_id=chest_1 target_type=chest target_name=\"Chest\" start=(5,3)",
        "the drift retry should plan from the live drifted position")

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
    assert_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=2/2 defer=1 target_id=npc_b reason=continuation_trap trap_reason=small_area landing=(7,5) reachable_area=1 remaining_targets=1 reachable_remaining=0 unreachable_remaining=1",
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

function tests.successful_attempts_do_not_run_alternate_mode_previews()
    local env = make_env()

    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)
    env.survey.tick(true)

    assert_equal(env.plan_call_count(), 0,
        "successful attempts should not pay for alternate-mode or skip-NPC replans")

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

    local ok, err = env.survey.start_target_survey("chest_1")

    local joined = table.concat(env.logs, "\n")
    assert_equal(ok, false, "low-exit single-target surveys should abort before launching")
    assert_equal(err, "Survey start (3,5) has only 2 open exits; move to a more open position",
        "low-exit aborts should return a clear guidance message")
    assert_contains(joined, "SURVEY_START_ABORT run=1 map=0x05 reason=low_exit_count start=(3,5) targets=1 open_exit_count=2 open_exits=south|west",
        "survey should log the low-exit abort with the opening coordinates")
    assert_contains(joined, "blocked_exits=north:directional(south)|east:directional(west)",
        "survey start context should explain blocked exits")
    assert_not_contains(joined, "SURVEY_START run=1 map=0x05 start=(3,5) targets=1",
        "aborted low-exit starts should not log a normal survey start")

    env.restore()
end

function tests.survey_target_accepts_exact_display_name()
    local env = make_env({
        object = {id = "npc_6", name = "Guard 3", type = "npc", x = 13, y = 17},
        objects = {
            {id = "npc_6", name = "Guard 3", type = "npc", x = 13, y = 17},
        },
    })

    local ok, err = env.survey.start_target_survey("Guard 3")
    assert_equal(ok, true, "exact display name should resolve as a survey target")
    assert_equal(err, nil, "exact display name should not return an error")
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)

    local run = env.survey.get_last_run(0x08)
    local result = run and run.results[1]
    assert_equal(result.target_id, "npc_6", "exact display name should resolve to the matching object id")

    env.restore()
end

function tests.survey_target_accepts_unique_partial_display_name()
    local env = make_env({
        objects = {
            {id = "npc_guard_3", name = "Castle Guard 3", type = "npc", x = 13, y = 17},
            {id = "chest_1", name = "Treasure Chest", type = "chest", x = 8, y = 5},
        },
    })

    local ok, err = env.survey.start_target_survey("guard 3")
    assert_equal(ok, true, "unique partial display names should resolve as survey targets")
    assert_equal(err, nil, "unique partial display names should not return an error")
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)

    local run = env.survey.get_last_run(0x08)
    local result = run and run.results[1]
    assert_equal(result.target_id, "npc_guard_3", "partial display name should resolve to the matching object id")

    env.restore()
end

function tests.survey_target_preserves_service_interaction_metadata()
    local captured_target = nil
    local env = make_env({
        objects = {
            {
                id = "npc_inn",
                name = "Inn",
                type = "npc",
                service = true,
                x = 10,
                y = 21,
                interaction_x = 8,
                interaction_y = 21,
                interaction_face_dir = "east",
            },
        },
        autowalk_fn = function(ctx)
            captured_target = ctx.target
            return {
                status = "queued",
                result = "Path: 1 west",
                path_mode = "direct",
                path = {{x = 8, y = 21, direction = "west"}},
            }
        end,
    })

    local ok, err = env.survey.start_target_survey("Inn")
    assert_equal(ok, true, "service display name should resolve as a survey target")
    assert_equal(err, nil, "service target should not return an error")
    env.survey.tick(true)

    assert_equal(captured_target and captured_target.interaction_x, 8,
        "survey autowalk should preserve service interaction X")
    assert_equal(captured_target and captured_target.interaction_y, 21,
        "survey autowalk should preserve service interaction Y")
    assert_equal(captured_target and captured_target.interaction_face_dir, "east",
        "survey autowalk should preserve service interaction facing")
    assert_equal(captured_target and captured_target.service, true,
        "survey autowalk should preserve service marker")

    env.restore()
end

function tests.survey_target_rejects_ambiguous_partial_name()
    local env = make_env({
        objects = {
            {id = "npc_guard_1", name = "Guard 1", type = "npc", x = 13, y = 17},
            {id = "npc_guard_2", name = "Guard 2", type = "npc", x = 14, y = 17},
        },
    })

    local ok, err = env.survey.start_target_survey("Guard")
    assert_equal(ok, false, "ambiguous partial names should not guess at a target")
    assert_contains(err or "", "Ambiguous target token", "ambiguous partial names should return a clear error")

    env.restore()
end

function tests.park_npcs_mode_parks_non_target_npcs_and_restores_on_finish()
    local env = make_env({
        object = {id = "npc_0", name = "Guard 1", type = "npc", x = 8, y = 5},
        objects = {
            {id = "npc_0", name = "Guard 1", type = "npc", x = 8, y = 5},
            {id = "npc_1", name = "Guard 2", type = "npc", x = 10, y = 5},
        },
        npc_bytes = {
            [0x0051] = 0x28, [0x0052] = 0x05, [0x0053] = 0x01,
            [0x0054] = 0x2A, [0x0055] = 0x05, [0x0056] = 0x01,
        },
    })

    env.survey.start_target_survey("npc_0,park_npcs")
    env.survey.tick(true)

    local slot0_b0, slot0_b1 = env.read_npc_slot(0)
    local slot1_b0, slot1_b1 = env.read_npc_slot(1)
    local joined = table.concat(env.logs, "\n")
    assert_equal(slot0_b0, 0x28, "target NPC should remain restored for its own attempt")
    assert_equal(slot0_b1, 0x05, "target NPC Y byte should remain unchanged")
    assert_equal(slot1_b0, 0x20, "non-target NPC should be parked at the ROM-inactive X coordinate")
    assert_equal(slot1_b1, 0x00, "non-target NPC should be parked at the ROM-inactive Y coordinate")
    assert_contains(joined, "SURVEY_NPC_PARK_START run=1 map=0x08 parked_slots=2",
        "parked mode should log its initial parking pass")
    assert_contains(joined, "SURVEY_NPC_PARK_TARGET run=1 map=0x08 target_id=npc_0 exempt_slot=0 parked_slots=1",
        "parked mode should log the exempt target NPC slot")

    env.publish("route_completed")
    env.survey.tick(true)

    local restored_b0, restored_b1 = env.read_npc_slot(1)
    assert_equal(restored_b0, 0x2A, "parked NPC should be restored when the survey finishes")
    assert_equal(restored_b1, 0x05, "parked NPC Y byte should be restored when the survey finishes")
    assert_contains(table.concat(env.logs, "\n"),
        "SURVEY_NPC_PARK_RESTORE run=1 map=0x08 restored=true restored_slots=2 reason=complete",
        "parked mode should log restoration on survey completion")

    env.restore()
end

function tests.park_npcs_mode_retargets_exemption_between_npc_attempts()
    local env = make_env({
        object = {id = "npc_0", name = "Guard 1", type = "npc", x = 8, y = 5},
        objects = {
            {id = "npc_0", name = "Guard 1", type = "npc", x = 8, y = 5},
            {id = "npc_1", name = "Guard 2", type = "npc", x = 10, y = 5},
        },
        npc_bytes = {
            [0x0051] = 0x28, [0x0052] = 0x05, [0x0053] = 0x01,
            [0x0054] = 0x2A, [0x0055] = 0x05, [0x0056] = 0x01,
        },
    })

    env.survey.start_object_survey("park_npcs")
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)
    env.survey.tick(true)

    local slot0_b0, slot0_b1 = env.read_npc_slot(0)
    local slot1_b0, slot1_b1 = env.read_npc_slot(1)
    local joined = table.concat(env.logs, "\n")
    assert_equal(slot0_b0, 0x20, "the first NPC should be re-parked at the ROM-inactive X coordinate")
    assert_equal(slot0_b1, 0x00, "the first NPC Y byte should be parked at the ROM-inactive coordinate")
    assert_equal(slot1_b0, 0x2A, "the next target NPC should be restored for its attempt")
    assert_equal(slot1_b1, 0x05, "the next target NPC Y byte should be restored")
    assert_contains(joined, "SURVEY_NPC_PARK_TARGET run=1 map=0x08 target_id=npc_1 exempt_slot=1 parked_slots=1",
        "parked mode should retarget the live exemption as the queue advances")

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

function tests.survey_aborts_multi_exit_start_when_almost_no_targets_are_reachable()
    local allowed = {
        ["5,5"] = true,
        ["5,4"] = true,
        ["5,3"] = true,
        ["5,2"] = true,
        ["5,6"] = true,
        ["5,7"] = true,
        ["5,8"] = true,
        ["6,5"] = true,
        ["7,5"] = true,
        ["8,5"] = true,
        ["6,4"] = true,
        ["7,4"] = true,
        ["8,4"] = true,
    }
    local env = make_env({
        map_id = 0x08,
        x = 5,
        y = 5,
        objects = {
            {id = "local_guard", name = "Local Guard", type = "npc", x = 6, y = 5},
            {id = "far_1", name = "Far 1", type = "npc", x = 20, y = 5},
            {id = "far_2", name = "Far 2", type = "npc", x = 21, y = 5},
            {id = "far_3", name = "Far 3", type = "npc", x = 22, y = 5},
            {id = "far_4", name = "Far 4", type = "npc", x = 23, y = 5},
            {id = "far_5", name = "Far 5", type = "npc", x = 24, y = 5},
            {id = "far_6", name = "Far 6", type = "npc", x = 25, y = 5},
            {id = "far_7", name = "Far 7", type = "npc", x = 26, y = 5},
        },
        walkability_fn = function(x, y)
            return allowed[x .. "," .. y] == true
        end,
        plan_fn = function(target)
            if target and target.id == "local_guard" then
                return {
                    result = "Approach: 1 east",
                    path = {{x = 6, y = 5, direction = "east"}},
                }
            end
            return {result = "No path found", path = nil}
        end,
    })

    local ok, info = env.survey.report_start_viability("park_npcs")

    assert_equal(ok, true, "coverage preflight should return structured start information")
    assert_equal(info.reachable_area, 13, "coverage preflight should not depend on the tiny-area threshold")
    assert_equal(info.open_exit_count, 3, "coverage preflight should allow multi-exit pockets to be measured")
    assert_equal(info.reachable_targets, 1, "coverage preflight should count reachable targets")
    assert_equal(info.unreachable_targets, 7, "coverage preflight should count unreachable targets")
    assert_equal(info.isolated_start, true, "coverage preflight should flag starts that reach almost no targets")
    assert_equal(info.isolation_reason, "low_target_coverage", "coverage preflight should report its reason")

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_START_STATUS map=0x08 mode=objects start=(5,5) targets=8 reachable_area=13 open_exit_count=3",
        "coverage preflight should preserve normal start status fields")
    assert_contains(joined, "reachable_targets=1 unreachable_targets=7 isolation_reason=low_target_coverage",
        "coverage preflight should log target reachability")

    local start_ok, err = env.survey.start_object_survey("park_npcs")
    assert_equal(start_ok, false, "survey should abort before generating a wall of stranded failures")
    assert_equal(err, "Survey start (5,5) is stranded: only 1 of 8 targets are reachable",
        "coverage abort should explain the target coverage problem")

    joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_START_ABORT run=1 map=0x08 reason=isolated_start start=(5,5) targets=8 reachable_area=13 open_exit_count=3",
        "coverage abort should log the usual start-abort fields")
    assert_contains(joined, "isolation_reason=low_target_coverage reachable_targets=1 unreachable_targets=7",
        "coverage abort should log why the multi-exit start was rejected")

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

function tests.default_object_survey_skips_survey_excluded_targets()
    local env = make_env({
        map_id = 0x04,
        x = 10,
        y = 10,
        objects = {
            {id = "exit_11_29", name = "Exit to World Map", type = "exit", x = 11, y = 29},
            {id = "door_10_30", name = "Door", type = "door", x = 10, y = 30, survey_exclude = true},
        },
    })

    local ok, info = env.survey.report_start_viability()

    assert_equal(ok, true, "preflight should still succeed with non-excluded survey targets")
    assert_equal(info.target_count, 1, "default object survey should skip objects marked survey_exclude")
    assert_contains(table.concat(env.logs, "\n"), "SURVEY_START_STATUS map=0x04 mode=objects start=(10,10) targets=1",
        "preflight should log only the included default targets")

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
        plan_fn = function(target, opts)
            if target.id == "trap_npc" then
                return {
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
                result = "Approach: 1 east",
                path_mode = "adjacent",
                path = {
                    {x = 6, y = 5, direction = "east"},
                },
            }
        end,
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

function tests.survey_defers_large_landing_that_strands_most_remaining_targets()
    local env = make_env({
        objects = {
            {id = "trap_npc", name = "Trap NPC", type = "npc", x = 9, y = 5},
            {id = "local_safe", name = "Local Safe", type = "npc", x = 9, y = 6},
            {id = "far_a", name = "Far A", type = "npc", x = 15, y = 5},
            {id = "far_b", name = "Far B", type = "npc", x = 16, y = 5},
            {id = "far_c", name = "Far C", type = "npc", x = 17, y = 5},
        },
        walkability_fn = function(x, y)
            if y == 5 and x >= 5 and x <= 8 then
                return true
            end
            if x == 5 and (y == 4 or y == 6) then
                return true
            end
            if x >= 8 and x <= 12 and y >= 3 and y <= 7 then
                return true
            end
            return false
        end,
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
                result = "Path: 1 east",
                path_mode = "direct",
                path = {
                    {x = 6, y = 5, direction = "east"},
                },
            }
        end,
        plan_fn = function(target, opts)
            local mode = opts and opts.path_mode or (target.type == "npc" and "adjacent" or "direct")
            if opts and opts.start_x == 8 and opts.start_y == 5 and target.id == "local_safe" then
                return {
                    result = "Approach: 1 south",
                    path_mode = mode,
                    path = {
                        {x = 8, y = 6, direction = "south"},
                    },
                }
            end
            if opts and opts.start_x == 8 and opts.start_y == 5 then
                return {
                    result = "No path found",
                    path_mode = mode,
                    path = nil,
                }
            end
            return {
                result = "Path: 1 east",
                path_mode = mode,
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

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=1/5 defer=1 target_id=trap_npc reason=continuation_trap trap_reason=stranded_remainder landing=(8,5) reachable_area=30 remaining_targets=4 reachable_remaining=1 unreachable_remaining=3",
        "large landings that strand most of the remaining queue should defer before the survey walks in")

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
        plan_fn = function(target, opts)
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
            return {
                result = "Approach: 1 east",
                path_mode = "adjacent",
                path = {
                    {x = 6, y = 5, direction = "east"},
                },
            }
        end,
    })

    env.survey.start_object_survey()
    env.survey.tick(true)
    env.survey.tick(true)
    env.publish("route_completed")
    env.survey.tick(true)

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=1/2 defer=1 target_id=trap_npc reason=continuation_trap trap_reason=small_area landing=(9,5) reachable_area=0 remaining_targets=1 reachable_remaining=1 unreachable_remaining=0",
        "trap targets should still defer while one other target remains")
    assert_before(
        joined,
        "SURVEY_ATTEMPT run=1 map=0x08 idx=2/2 retry=0 target_id=safe_npc",
        "SURVEY_ATTEMPT run=1 map=0x08 idx=1/2 retry=0 target_id=trap_npc",
        "the safe target should complete before the trap target is finally allowed")

    env.restore()
end

function tests.clustered_isolated_start_skips_unreachable_remainder_but_keeps_local_targets()
    local env = make_env({
        objects = {
            {id = "npc_a", name = "NPC A", type = "npc", x = 8, y = 5},
            {id = "npc_b", name = "NPC B", type = "npc", x = 9, y = 5},
            {id = "reachable_local", name = "Reachable Local", type = "npc", x = 5, y = 6},
            {id = "unreachable_far", name = "Unreachable Far", type = "npc", x = 20, y = 20},
        },
        autowalk_fn = function(ctx)
            if ctx.target.id == "reachable_local" then
                return {
                    status = "queued",
                    result = "Approach: 1 south",
                    path_mode = "adjacent",
                    path = {
                        {x = 5, y = 6, direction = "south"},
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
        plan_fn = function(target, opts)
            local mode = opts and opts.path_mode or (target.type == "npc" and "adjacent" or "direct")
            if target.id == "reachable_local" then
                return {
                    result = "Approach: 1 south",
                    path_mode = mode,
                    path = {
                        {x = 5, y = 6, direction = "south"},
                    },
                }
            end
            return {
                result = "No path found",
                path_mode = mode,
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
    local result_a = run and run.result_by_id["npc_a"]
    local result_reachable = run and run.result_by_id["reachable_local"]
    local result_far = run and run.result_by_id["unreachable_far"]
    assert_contains(joined, "SURVEY_STRANDED_SCAN_DEFER run=1 map=0x08 start=(5,5) pending_targets=3 reachable_targets=1 unreachable_targets=2",
        "when a reachable continuation remains, stranded-start cleanup should move first instead of trimming the queue")
    assert_contains(joined, "SURVEY_RESULT run=1 map=0x08 target_id=unreachable_far",
        "unreachable targets should get their own attempt after reachable continuations have had a chance to move the survey")
    assert_contains(joined, "SURVEY_STRANDED_SCAN run=1 map=0x08 start=(5,5) pending_targets=1 reachable_targets=0 skipped_targets=1",
        "once no reachable continuation remains, stranded-start cleanup can still trim stale retries")
    assert_contains(joined, "SURVEY_ATTEMPT run=1 map=0x08 idx=3/4 retry=0 target_id=reachable_local",
        "reachable pocket-local targets should stay in the queue and still be attempted")
    assert_equal(result_a.failure_classification, "gated_or_isolated_region",
        "stale retries from the stranded start should be folded into the isolated-region bucket")
    assert_equal(result_far.failure_classification, "gated_or_isolated_region",
        "unreachable targets should still be recorded as isolated-region failures")
    assert_equal(result_reachable.movement_succeeded, true,
        "reachable local targets should still complete successfully after the stranded-start cleanup")
    assert_equal(run.summary.successes, 1, "only the local reachable target should succeed")
    assert_equal(run.summary.gated_or_isolated_region, 3,
        "the two unreachable targets and the stale retry should all count as isolated/gated results")

    env.restore()
end

function tests.survey_can_defer_same_target_again_for_different_trap_landing()
    local trap_calls = 0
    local env = make_env({
        objects = {
            {id = "trap_npc", name = "Trap NPC", type = "npc", x = 9, y = 5},
            {id = "retry_1", name = "Retry 1", type = "npc", x = 12, y = 5},
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
        plan_fn = function(target, opts)
            local mode = opts and opts.path_mode or "adjacent"
            if target.id == "trap_npc" then
                if trap_calls <= 1 then
                    return {
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
                result = "No path found",
                path_mode = mode,
                path = nil,
            }
        end,
    })

    env.survey.start_object_survey()
    for _ = 1, 3 do
        env.survey.tick(true)
    end

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=1/2 defer=1 target_id=trap_npc reason=continuation_trap trap_reason=small_area landing=(8,5)",
        "first trap landing should still be deferred")
    assert_contains(joined, "SURVEY_REQUEUE run=1 map=0x08 target_id=retry_1 reason=transient_no_path retry=1",
        "a retryable target should stay behind the trap so the second defer still matters")
    assert_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=1/2 defer=2 target_id=trap_npc reason=continuation_trap trap_reason=small_area landing=(9,5)",
        "a different trap landing for the same target should be deferred too")

    env.restore()
end

function tests.survey_can_defer_same_target_again_for_same_trap_landing()
    local trap_calls = 0
    local env = make_env({
        objects = {
            {id = "trap_npc", name = "Trap NPC", type = "npc", x = 9, y = 5},
            {id = "retry_1", name = "Retry 1", type = "npc", x = 12, y = 5},
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
        plan_fn = function(target, opts)
            local mode = opts and opts.path_mode or "adjacent"
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
            return {
                result = "No path found",
                path_mode = mode,
                path = nil,
            }
        end,
    })

    env.survey.start_object_survey()
    for _ = 1, 3 do
        env.survey.tick(true)
    end

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=1/2 defer=1 target_id=trap_npc reason=continuation_trap trap_reason=small_area landing=(9,5)",
        "first repeat trap landing should be deferred")
    assert_contains(joined, "SURVEY_REQUEUE run=1 map=0x08 target_id=retry_1 reason=transient_no_path retry=1",
        "a retryable target should keep the same landing worthwhile to defer again")
    assert_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=1/2 defer=2 target_id=trap_npc reason=continuation_trap trap_reason=small_area landing=(9,5)",
        "same trap landing should be deferrable a second time")

    env.restore()
end

function tests.same_landing_defer_stops_once_no_worthwhile_targets_remain()
    local env = make_env({
        objects = {
            {id = "trap_npc_a", name = "Trap NPC A", type = "npc", x = 9, y = 5},
            {id = "retry_1", name = "Retry 1", type = "npc", x = 12, y = 5},
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
            if ctx.target.id == "trap_npc_a" then
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
        plan_fn = function(target, opts)
            local mode = opts and opts.path_mode or "adjacent"
            if target.id == "trap_npc_a" then
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
            return {
                result = "No path found",
                path_mode = mode,
                path = nil,
            }
        end,
    })

    env.survey.start_object_survey()
    for _ = 1, 5 do
        env.survey.tick(true)
    end

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=1/2 defer=1 target_id=trap_npc_a reason=continuation_trap trap_reason=small_area landing=(9,5)",
        "same landing should still defer while the retryable target remains")
    assert_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=1/2 defer=2 target_id=trap_npc_a reason=continuation_trap trap_reason=small_area landing=(9,5)",
        "the same landing should defer again while the requeued target still matters")
    assert_not_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=1/2 defer=3 target_id=trap_npc_a",
        "once the only remaining target is exhausted, the trap target should stop deferring forever")
    assert_contains(joined, "SURVEY_ATTEMPT run=1 map=0x08 idx=1/2 retry=0 target_id=trap_npc_a",
        "the trap target should eventually be allowed once nothing worthwhile remains behind it")

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
            if string.sub(target.id, 1, 6) == "filler" then
                return {
                    result = "Path: 1 east",
                    path = {
                        {x = 6, y = 5, direction = "east"},
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
    assert_contains(joined, "SURVEY_DEFER run=1 map=0x08 idx=2/9 defer=1 target_id=trap_npc reason=continuation_trap trap_reason=small_area landing=(9,5)",
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

function tests.route_drift_recovery_keeps_the_original_survey_attempt()
    local env = make_env()
    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    env.set_position(0x08, 5, 3)
    -- auto_step publishes cancellation BEFORE calling route_manager, which
    -- starts its corrective route synchronously on this same frame.
    env.publish("route_cancelled", {reason = "route_drift_off_path"})
    assert_not_contains(table.concat(env.logs, "\n"), "SURVEY_REQUEUE",
        "survey must wait for the route manager's recovery decision")
    env.set_route_active(true)
    env.survey.tick(true)
    env.survey.tick(true)
    assert_equal(env.autowalk_calls(), 1, "survey must not compete with the corrective walk")
    assert_equal(env.clear_route_context_calls(), 0, "recovery must retain its route context")
    assert_equal(env.survey.is_active(), true, "survey must wait for actual arrival")
    assert_not_contains(table.concat(env.logs, "\n"), "SURVEY_RESULT",
        "an active correction is not a failed survey result")
    env.set_position(0x08, 7, 5)
    env.publish("route_completed")
    env.survey.tick(true)
    local run = env.survey.get_last_run(0x08)
    assert_equal(run.summary.successes, 1, "completed drift recovery should succeed")
    assert_equal(run.summary.failures, 0, "recovery should not leave a false failure")
    assert_equal(run.results[1].start_x, 5, "retain the original attempt start X")
    assert_equal(run.results[1].start_y, 5, "retain the original attempt start Y")
    assert_contains(table.concat(env.logs, "\n"), "SURVEY_DRIFT_RECOVERY",
        "continued recovery should have a structured log")
    env.restore()
end

function tests.route_drift_completion_in_the_same_frame_finishes_once()
    local env = make_env()
    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    env.publish("route_cancelled", {reason = "route_drift_off_path"})
    -- Recovery can find that the player is already at a usable approach.
    env.set_position(0x08, 7, 5)
    env.publish("route_completed")
    env.survey.tick(true)
    local run = env.survey.get_last_run(0x08)
    assert_equal(run ~= nil, true, "same-frame completion should finish the survey")
    assert_equal(run.summary.successes, 1, "zero-step recovery should count as arrival")
    assert_equal(run.summary.failures, 0, "raw drift notification is not a failure")
    assert_equal(env.autowalk_calls(), 1, "same-frame completion must not queue a retry")
    env.restore()
end

function tests.route_drift_terminal_failure_supersedes_the_raw_cancellation()
    local env = make_env()
    env.survey.start_target_survey("chest_1")
    env.survey.tick(true)
    env.publish("route_cancelled", {reason = "route_drift_off_path"})
    env.publish("route_cancelled", {reason = "route_drift_reroute_limit"})
    env.survey.tick(true)
    local run = env.survey.get_last_run(0x08)
    assert_equal(run ~= nil, true, "terminal recovery failure should finish the attempt")
    assert_equal(run.summary.failures, 1, "terminal recovery failure must be recorded")
    assert_equal(run.results[1].reason, "route_drift_reroute_limit", "retain the actual terminal reason")
    assert_equal(env.autowalk_calls(), 1, "do not bypass the route-manager retry limit")
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
