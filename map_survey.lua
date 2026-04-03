-- map_survey.lua
-- Autonomous map-level survey and blocked-tile diagnostics.
--
-- Drives repeated object-target pathfinding/autowalk attempts on the current
-- map, records structured per-target results, and accumulates conservative
-- blocked-tile candidates separate from permanent map data.

local auto_step   = require "auto_step"
local debug_tools = require "debug_tools"
local event_bus   = require "event_bus"
local map_reader  = require "map_reader"
local nav         = require "navigation"
local objects     = require "objects"
local route_mgr   = require "route_manager"
local tolk        = require "tolk"

local M = {}

local CONFIDENCE_RANK = {low = 1, medium = 2, high = 3}

local survey_state = nil
local blocked_candidates = {}
local last_runs = {}
local run_counter = 0
local tick_counter = 0

local function trim(s)
    if s == nil then return nil end
    return tostring(s):match("^%s*(.-)%s*$")
end

local function parse_int(token)
    token = trim(token)
    if not token or token == "" then return nil end
    if token:match("^[-+]?0[xX][%da-fA-F]+$") then
        return tonumber(token)
    end
    if token:match("^[-+]?%d+$") then
        return tonumber(token)
    end
    return nil
end

local function split_arg_list(arg)
    local parts = {}
    if not arg or trim(arg) == "" then
        return parts
    end
    for token in tostring(arg):gmatch("[^,]+") do
        parts[#parts + 1] = trim(token)
    end
    return parts
end

local function cell_key(x, y)
    return x .. "," .. y
end

local function shallow_copy(tbl)
    local copy = {}
    if not tbl then return copy end
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

local function copy_object(obj)
    if not obj then return nil end
    return {
        id = obj.id,
        name = obj.name,
        type = obj.type,
        x = obj.x,
        y = obj.y,
    }
end

local function refresh_object(obj)
    if not obj or not obj.id then
        return copy_object(obj)
    end
    local live = objects.find_object_by_id(obj.id)
    if live then
        return copy_object(live)
    end
    return copy_object(obj)
end

local function join_sorted_keys(tbl, sep)
    local keys = {}
    if tbl then
        for k, v in pairs(tbl) do
            if v then
                keys[#keys + 1] = tostring(k)
            end
        end
    end
    table.sort(keys)
    return table.concat(keys, sep or "|")
end

local function count_truthy_keys(tbl)
    local n = 0
    if not tbl then return n end
    for _, v in pairs(tbl) do
        if v then
            n = n + 1
        end
    end
    return n
end

local function sorted_truthy_keys(tbl)
    local keys = {}
    if not tbl then return keys end
    for k, v in pairs(tbl) do
        if v then
            keys[#keys + 1] = tostring(k)
        end
    end
    table.sort(keys)
    return keys
end

local function bool_str(v)
    if v then return "true" end
    return "false"
end

local function ensure_map_candidates(map_id)
    if not blocked_candidates[map_id] then
        blocked_candidates[map_id] = {}
    end
    return blocked_candidates[map_id]
end

local function compute_candidate_confidence(entry)
    if not entry then return "low" end
    if entry.retry_successes >= 1 then
        return "high"
    end
    if entry.target_count >= 2 or entry.count >= 3 then
        return "high"
    end
    if entry.count >= 2 or entry.failure_count >= 1 then
        return "medium"
    end
    return "low"
end

local function sorted_candidate_entries(map_id)
    local entries = {}
    local map_entries = blocked_candidates[map_id] or {}
    for _, entry in pairs(map_entries) do
        entry.confidence = compute_candidate_confidence(entry)
        entries[#entries + 1] = entry
    end
    table.sort(entries, function(a, b)
        local ra = CONFIDENCE_RANK[a.confidence] or 0
        local rb = CONFIDENCE_RANK[b.confidence] or 0
        if ra ~= rb then return ra > rb end
        if a.count ~= b.count then return a.count > b.count end
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)
    return entries
end

local function is_strong_reroute_candidate(entry)
    if not entry then return false end
    if entry.retry_successes <= 0 then
        return false
    end
    if entry.count >= 2 then
        return true
    end
    if entry.target_count >= 2 then
        return true
    end
    if count_truthy_keys(entry.approaches) >= 2 then
        return true
    end
    return false
end

local function strong_candidate_entries(map_id)
    local result = {}
    for _, entry in ipairs(sorted_candidate_entries(map_id)) do
        if is_strong_reroute_candidate(entry) then
            result[#result + 1] = entry
        end
    end
    return result
end

local function build_candidate_suggestion(entry)
    local approaches = sorted_truthy_keys(entry and entry.approaches)
    local count = #approaches
    if count == 0 then
        return nil
    end
    local kind = (count == 4) and "full_block" or "directional"
    return {
        map_id = entry.map_id,
        key = entry.key,
        x = entry.x,
        y = entry.y,
        kind = kind,
        approaches = approaches,
        confidence = entry.confidence,
        count = entry.count,
        target_count = entry.target_count,
        retry_successes = entry.retry_successes,
    }
end

local function candidate_suggestions(map_id)
    local result = {}
    for _, entry in ipairs(sorted_candidate_entries(map_id)) do
        local include = entry.retry_successes > 0
            or (CONFIDENCE_RANK[entry.confidence] or 0) >= CONFIDENCE_RANK.medium
        if include then
            local suggestion = build_candidate_suggestion(entry)
            if suggestion then
                result[#result + 1] = suggestion
            end
        end
    end
    return result
end

local function log_result(result)
    local suspected = result.suspected_blocked_tiles and table.concat(result.suspected_blocked_tiles, "|") or ""
    local blocked = result.blocked_tiles and table.concat(result.blocked_tiles, "|") or ""
    local alt_mode = result.alternate_mode or ""
    local alt_found = result.alternate_path_found
    if alt_found == nil then alt_found = false end
    debug_tools.info(string.format(
        "SURVEY_RESULT run=%d map=0x%02X target_id=%s target_type=%s target_name=%q start=(%d,%d) target=(%d,%d) path_mode=%s path_found=%s path_length=%d movement_succeeded=%s final=(%d,%d) failure_class=%s blocked_events=%d suspected_tiles=%s blocked_tiles=%s retry_succeeded=%s alternate_mode=%s alternate_path_found=%s reason=%s",
        result.run_id or 0,
        result.map_id or 0,
        tostring(result.target_id or ""),
        tostring(result.target_type or ""),
        tostring(result.target_name or ""),
        result.start_x or -1,
        result.start_y or -1,
        result.target_x or -1,
        result.target_y or -1,
        tostring(result.path_mode or ""),
        bool_str(result.path_found),
        result.path_length or 0,
        bool_str(result.movement_succeeded),
        result.final_x or -1,
        result.final_y or -1,
        tostring(result.failure_classification or "none"),
        result.blocked_event_count or 0,
        suspected ~= "" and suspected or "-",
        blocked ~= "" and blocked or "-",
        bool_str(result.retry_succeeded),
        alt_mode ~= "" and alt_mode or "-",
        bool_str(alt_found),
        tostring(result.reason or ""))
    )
end

local function compute_summary(run)
    local summary = {
        total = 0,
        successes = 0,
        failures = 0,
        no_route_found = 0,
        route_found_but_movement_failed = 0,
        suspected_engine_blocked_tile = 0,
        command_timing_or_state_issue = 0,
        wrong_adjacency_or_interaction_assumption = 0,
    }
    if not run then return summary end
    summary.total = #run.results
    for _, result in ipairs(run.results) do
        if result.movement_succeeded then
            summary.successes = summary.successes + 1
        else
            summary.failures = summary.failures + 1
            local key = result.failure_classification
            if key and summary[key] ~= nil then
                summary[key] = summary[key] + 1
            end
        end
    end
    return summary
end

local function finish_run(speak_message)
    if not survey_state then
        return
    end
    survey_state.summary = compute_summary(survey_state)
    last_runs[survey_state.map_id] = survey_state
    debug_tools.info(string.format(
        "SURVEY_COMPLETE run=%d map=0x%02X targets=%d successes=%d failures=%d no_route=%d movement_failed=%d suspected_engine_blocked=%d state_issues=%d adjacency_issues=%d",
        survey_state.run_id,
        survey_state.map_id,
        survey_state.summary.total,
        survey_state.summary.successes,
        survey_state.summary.failures,
        survey_state.summary.no_route_found,
        survey_state.summary.route_found_but_movement_failed,
        survey_state.summary.suspected_engine_blocked_tile,
        survey_state.summary.command_timing_or_state_issue,
        survey_state.summary.wrong_adjacency_or_interaction_assumption))
    if speak_message ~= false then
        tolk.output_interrupt(string.format(
            "Survey complete on map %02X. %d successes, %d failures.",
            survey_state.map_id,
            survey_state.summary.successes,
            survey_state.summary.failures))
    end
    survey_state = nil
end

local function resolve_target_by_token(token)
    token = trim(token)
    if not token or token == "" then
        return objects.current_object()
    end
    local obj = objects.find_object_by_id(token)
    if obj then
        return obj
    end
    local index = parse_int(token)
    if index and index >= 1 then
        local list = objects.get_objects()
        return list[index]
    end
    return nil
end

local function get_default_survey_targets()
    local list = objects.get_objects()
    local targets = {}
    for i, obj in ipairs(list) do
        targets[i] = copy_object(obj)
    end
    return targets
end

local function get_failed_targets_for_map(map_id)
    local run = last_runs[map_id]
    if not run then
        return {}
    end
    local targets = {}
    for _, result in ipairs(run.results) do
        if not result.movement_succeeded then
            local obj = objects.find_object_by_id(result.target_id) or {
                id = result.target_id,
                name = result.target_name,
                type = result.target_type,
                x = result.target_x,
                y = result.target_y,
            }
            targets[#targets + 1] = copy_object(obj)
        end
    end
    return targets
end

local function analyze_alternate_mode(target, primary_mode)
    local alternate_mode = (primary_mode == "adjacent") and "direct" or "adjacent"
    local plan = route_mgr.plan_path_to_object(target, {
        path_mode = alternate_mode,
        store_debug_path = false,
        survey_safe = true,
    })
    if not plan then
        return alternate_mode, false, 0
    end
    local path_found = plan.result ~= "No path found"
    return alternate_mode, path_found, plan.path and #plan.path or 0
end

local function classify_attempt(attempt)
    local alternate_mode, alternate_path_found = analyze_alternate_mode(attempt.target, attempt.path_mode)
    attempt.alternate_mode = alternate_mode
    attempt.alternate_path_found = alternate_path_found

    if attempt.success then
        return nil
    end

    if attempt.plan_status == "no_path" then
        if alternate_path_found then
            return "wrong_adjacency_or_interaction_assumption"
        end
        return "no_route_found"
    end

    if #attempt.suspected_tiles > 0 then
        return "suspected_engine_blocked_tile"
    end
    if #attempt.blocked_tiles > 0 then
        return "route_found_but_movement_failed"
    end
    return "command_timing_or_state_issue"
end

local function should_retry_transient_no_path(attempt, failure_classification)
    if not survey_state or not attempt then
        return false
    end
    if failure_classification ~= "no_route_found" then
        return false
    end
    if attempt.plan_status ~= "no_path" then
        return false
    end
    if #attempt.blocked_tiles > 0 or #attempt.suspected_tiles > 0 then
        return false
    end
    local retries = survey_state.retry_counts[attempt.target.id] or 0
    return retries < 1
end

local function finalize_attempt(attempt)
    if not survey_state or not attempt then
        return
    end
    if survey_state.active_attempt and survey_state.active_attempt ~= attempt then
        return
    end
    local map_id, final_x, final_y = nav.get_position()
    local failure_classification = classify_attempt(attempt)

    if should_retry_transient_no_path(attempt, failure_classification) then
        survey_state.retry_counts[attempt.target.id] = (survey_state.retry_counts[attempt.target.id] or 0) + 1
        survey_state.targets[#survey_state.targets + 1] = refresh_object(attempt.target)
        survey_state.index = survey_state.index + 1
        survey_state.active_attempt = nil
        debug_tools.info(string.format(
            "SURVEY_REQUEUE run=%d map=0x%02X target_id=%s reason=transient_no_path retry=%d",
            survey_state.run_id,
            attempt.map_id,
            tostring(attempt.target.id),
            survey_state.retry_counts[attempt.target.id]))
        return
    end

    local result = {
        run_id = survey_state.run_id,
        map_id = attempt.map_id,
        target_id = attempt.target.id,
        target_type = attempt.target.type,
        target_name = attempt.target.name,
        start_x = attempt.start_x,
        start_y = attempt.start_y,
        target_x = attempt.target.x,
        target_y = attempt.target.y,
        path_mode = attempt.path_mode,
        path_found = attempt.path_found,
        path_length = attempt.path_length or 0,
        movement_succeeded = attempt.success == true,
        final_x = final_x,
        final_y = final_y,
        failure_classification = failure_classification,
        suspected_blocked_tiles = shallow_copy(attempt.suspected_tiles),
        blocked_tiles = shallow_copy(attempt.blocked_tiles),
        blocked_event_count = #attempt.blocked_tiles,
        retry_succeeded = attempt.success == true and #attempt.blocked_tiles > 0,
        alternate_mode = attempt.alternate_mode,
        alternate_path_found = attempt.alternate_path_found,
        reason = attempt.reason or attempt.plan_status or "",
        finished_on_same_map = (map_id == attempt.map_id),
    }
    survey_state.results[#survey_state.results + 1] = result
    survey_state.result_by_id[result.target_id] = result
    survey_state.index = survey_state.index + 1
    survey_state.active_attempt = nil

    if result.retry_succeeded then
        local map_candidates = blocked_candidates[result.map_id] or {}
        for _, key in ipairs(result.suspected_blocked_tiles) do
            local entry = map_candidates[key]
            if entry then
                entry.retry_successes = entry.retry_successes + 1
                entry.confidence = compute_candidate_confidence(entry)
            end
        end
    end

    if not result.movement_succeeded and result.failure_classification == "suspected_engine_blocked_tile" then
        local map_candidates = blocked_candidates[result.map_id] or {}
        for _, key in ipairs(result.suspected_blocked_tiles) do
            local entry = map_candidates[key]
            if entry then
                entry.failure_count = entry.failure_count + 1
                entry.confidence = compute_candidate_confidence(entry)
            end
        end
    end

    log_result(result)
end

local function record_candidate(attempt, blocked_event)
    local map_id = attempt.map_id
    local x = blocked_event.dest_x
    local y = blocked_event.dest_y
    local key = cell_key(x, y)
    local details = map_reader.get_walkability_details(map_id, x, y)
    if not details or details.effective_walkable ~= true or details.permanent_blocked then
        return false
    end

    objects.update_npcs()
    local blocking = route_mgr.build_path_blocking(map_id)
    local block = blocking[key]
    if block == "npc" then
        return false
    end
    if type(block) == "table" and block[blocked_event.approach] then
        return false
    end

    local map_entries = ensure_map_candidates(map_id)
    local entry = map_entries[key]
    if not entry then
        entry = {
            map_id = map_id,
            key = key,
            x = x,
            y = y,
            count = 0,
            target_ids = {},
            target_count = 0,
            approaches = {},
            retry_successes = 0,
            failure_count = 0,
            last_target_id = nil,
            confidence = "low",
        }
        map_entries[key] = entry
    end

    entry.count = entry.count + 1
    entry.approaches[blocked_event.approach] = true
    if not entry.target_ids[attempt.target.id] then
        entry.target_ids[attempt.target.id] = true
        entry.target_count = entry.target_count + 1
    end
    entry.last_target_id = attempt.target.id
    entry.confidence = compute_candidate_confidence(entry)

    if not attempt.suspected_tile_set[key] then
        attempt.suspected_tile_set[key] = true
        attempt.suspected_tiles[#attempt.suspected_tiles + 1] = key
    end
    return true
end

local function on_route_blocked(data)
    if not survey_state or not survey_state.active_attempt or not data then
        return
    end
    local attempt = survey_state.active_attempt
    local dir_meta = route_mgr.get_dir_to_delta()[data.dir]
    local dest_x = (data.from_x or 0) + (dir_meta and dir_meta.dx or 0)
    local dest_y = (data.from_y or 0) + (dir_meta and dir_meta.dy or 0)
    local approach = ({
        up = "south",
        down = "north",
        left = "east",
        right = "west",
    })[data.dir]
    local blocked_event = {
        from_x = data.from_x,
        from_y = data.from_y,
        dir = data.dir,
        dest_x = dest_x,
        dest_y = dest_y,
        approach = approach,
    }
    attempt.blocked_tiles[#attempt.blocked_tiles + 1] = cell_key(dest_x, dest_y)
    record_candidate(attempt, blocked_event)
end

local function on_route_completed()
    if not survey_state or not survey_state.active_attempt then
        return
    end
    local attempt = survey_state.active_attempt
    attempt.success = true
    attempt.reason = (#attempt.blocked_tiles > 0) and "reroute_succeeded_after_runtime_block" or "route_completed"
    finalize_attempt(attempt)
end

local function on_route_cancelled(data)
    if not survey_state or not survey_state.active_attempt then
        return
    end
    local attempt = survey_state.active_attempt
    attempt.success = false
    attempt.reason = data and data.reason or "route_cancelled"
    finalize_attempt(attempt)
    if survey_state and survey_state.stop_after_attempt then
        finish_run(false)
    end
end

local function on_map_changed(data)
    if not survey_state or not data then
        return
    end
    if data.map_id ~= survey_state.map_id then
        survey_state.stop_after_attempt = true
        survey_state.stop_reason = "map_changed"
        if not survey_state.active_attempt then
            finish_run(false)
        end
    end
end

event_bus.subscribe("route_blocked", on_route_blocked)
event_bus.subscribe("route_completed", on_route_completed)
event_bus.subscribe("route_cancelled", on_route_cancelled)
event_bus.subscribe("map_changed", on_map_changed)

local function start_attempt(target)
    local map_id, start_x, start_y = nav.get_position()
    local stale_runtime_blocks = route_mgr.count_runtime_blocks(map_id) or 0
    if stale_runtime_blocks > 0 then
        route_mgr.clear_runtime_blocks(map_id)
        debug_tools.info(string.format(
            "SURVEY_ATTEMPT_RESET run=%d map=0x%02X target_id=%s cleared_runtime_blocks=%d",
            survey_state and survey_state.run_id or 0,
            map_id,
            tostring(target and target.id or ""),
            stale_runtime_blocks))
    end
    local plan = route_mgr.autowalk_to_object(target, {
        speak = false,
        store_debug_path = false,
        survey_safe = true,
    })
    local attempt = {
        target = copy_object(target),
        map_id = map_id,
        start_x = start_x,
        start_y = start_y,
        path_mode = plan and plan.path_mode or nil,
        path_found = plan and plan.result ~= "No path found" or false,
        path_length = plan and (plan.path and #plan.path or 0) or 0,
        blocked_tiles = {},
        suspected_tiles = {},
        suspected_tile_set = {},
        plan_status = plan and plan.status or "unknown",
        reason = plan and plan.status or "unknown",
        success = false,
    }

    if plan and plan.status == "queued" then
        survey_state.active_attempt = attempt
        debug_tools.info(string.format(
            "SURVEY_ATTEMPT run=%d map=0x%02X idx=%d/%d target_id=%s target_type=%s target_name=%q start=(%d,%d) target=(%d,%d) mode=%s path_length=%d",
            survey_state.run_id,
            survey_state.map_id,
            survey_state.index + 1,
            #survey_state.targets,
            tostring(target.id),
            tostring(target.type),
            tostring(target.name),
            start_x,
            start_y,
            target.x,
            target.y,
            tostring(plan.path_mode or ""),
            attempt.path_length))
        return
    end

    if plan then
        attempt.success = (plan.status == "already_there")
        attempt.reason = plan.status
        finalize_attempt(attempt)
    else
        finalize_attempt(attempt)
    end
end

local function start_run(targets, opts)
    if not debug_tools.DEBUG_MODE then
        return false, "Survey commands require debug_mode=true"
    end
    if survey_state then
        return false, "A survey is already active"
    end
    local map_id = nav.get_position()
    if not targets or #targets == 0 then
        return false, string.format("No survey targets found on map %02X", map_id)
    end
    run_counter = run_counter + 1
    survey_state = {
        run_id = run_counter,
        map_id = map_id,
        targets = targets,
        options = opts or {},
        index = 0,
        results = {},
        result_by_id = {},
        retry_counts = {},
        active_attempt = nil,
        stop_after_attempt = false,
        stop_reason = nil,
    }
    debug_tools.info(string.format(
        "SURVEY_START run=%d map=0x%02X targets=%d mode=%s runtime_blocks=%d",
        survey_state.run_id,
        survey_state.map_id,
        #targets,
        tostring((opts and opts.mode) or "objects"),
        route_mgr.count_runtime_blocks(map_id)))
    tolk.output_interrupt(string.format(
        "Survey started on map %02X. %d target%s queued.",
        map_id,
        #targets,
        (#targets == 1) and "" or "s"))
    return true, nil
end

function M.start_object_survey(arg)
    local map_id = nav.get_position()
    local token = trim(arg)
    if token == "retry_failed" or token == "failed" then
        return start_run(get_failed_targets_for_map(map_id), {mode = "retry_failed"})
    end
    return start_run(get_default_survey_targets(), {mode = "objects"})
end

function M.start_target_survey(arg)
    local parts = split_arg_list(arg)
    local target = resolve_target_by_token(parts[1])
    if not target then
        return false, "Target not found"
    end
    return start_run({copy_object(target)}, {mode = "target"})
end

function M.stop_survey()
    if not survey_state then
        return false, "No active survey"
    end
    local map_id = survey_state.map_id
    survey_state.stop_after_attempt = true
    survey_state.stop_reason = "manual_stop"
    if survey_state.active_attempt then
        auto_step.cancel_active_step(true)
        survey_state.active_attempt.success = false
        survey_state.active_attempt.reason = "manual_stop"
        finalize_attempt(survey_state.active_attempt)
    end
    finish_run(false)
    return true, string.format("Stopped survey on map %02X", map_id)
end

function M.tick(can_walk)
    tick_counter = tick_counter + 1
    if not debug_tools.DEBUG_MODE or not survey_state then
        return
    end

    if survey_state.active_attempt then
        if not auto_step.is_route_active() then
            -- Grace frame: route_completed/route_cancelled events may arrive
            -- on the same frame via event_bus but after tick() runs. Wait one
            -- extra frame so the event has a chance to finalize the attempt
            -- before we declare it orphaned.
            if not survey_state.active_attempt.grace_frame then
                survey_state.active_attempt.grace_frame = true
                return
            end
            survey_state.active_attempt.success = false
            survey_state.active_attempt.reason = "route_inactive_without_completion"
            finalize_attempt(survey_state.active_attempt)
            if survey_state and survey_state.stop_after_attempt then
                finish_run(false)
            end
        end
        return
    end

    if survey_state.stop_after_attempt then
        finish_run(false)
        return
    end

    if survey_state.index >= #survey_state.targets then
        finish_run(true)
        return
    end

    if not can_walk then
        return
    end

    start_attempt(survey_state.targets[survey_state.index + 1])
end

function M.is_active()
    return survey_state ~= nil
end

-- reset_candidates(map_id): Clear accumulated blocked-tile candidates for a
-- map. Candidates persist across surveys by design (to accumulate evidence),
-- but this lets you start fresh if the data is stale or tainted.
function M.reset_candidates(map_id)
    map_id = map_id or nav.get_position()
    blocked_candidates[map_id] = nil
    debug_tools.info(string.format("SURVEY: cleared blocked candidates for map 0x%02X", map_id))
end

function M.get_last_run(map_id)
    map_id = map_id or nav.get_position()
    return last_runs[map_id]
end

function M.report_failed_targets(map_id)
    map_id = map_id or nav.get_position()
    local run = last_runs[map_id]
    if not run then
        debug_tools.info(string.format("SURVEY_FAILED map=0x%02X none", map_id))
        return 0
    end
    local count = 0
    for _, result in ipairs(run.results) do
        if not result.movement_succeeded then
            count = count + 1
            debug_tools.info(string.format(
                "SURVEY_FAILED map=0x%02X target_id=%s target_name=%q class=%s target=(%d,%d) final=(%d,%d) suspected=%s",
                map_id,
                tostring(result.target_id),
                tostring(result.target_name),
                tostring(result.failure_classification or "none"),
                result.target_x,
                result.target_y,
                result.final_x or -1,
                result.final_y or -1,
                (#(result.suspected_blocked_tiles or {}) > 0)
                    and table.concat(result.suspected_blocked_tiles, "|")
                    or "-"))
        end
    end
    if count == 0 then
        debug_tools.info(string.format("SURVEY_FAILED map=0x%02X none", map_id))
    end
    return count
end

function M.list_blocked_candidates(map_id)
    map_id = map_id or nav.get_position()
    local entries = sorted_candidate_entries(map_id)
    if #entries == 0 then
        debug_tools.info(string.format("SURVEY_CANDIDATES map=0x%02X none", map_id))
        return 0
    end
    debug_tools.info(string.format("SURVEY_CANDIDATES map=0x%02X count=%d", map_id, #entries))
    for _, entry in ipairs(entries) do
        debug_tools.info(string.format(
            "SURVEY_CANDIDATE map=0x%02X x=%d y=%d key=%s count=%d targets=%d retry_successes=%d failure_count=%d confidence=%s approaches=%s",
            map_id,
            entry.x,
            entry.y,
            entry.key,
            entry.count,
            entry.target_count,
            entry.retry_successes,
            entry.failure_count,
            tostring(entry.confidence),
            join_sorted_keys(entry.approaches, "|")))
    end
    return #entries
end

function M.report_strong_candidates(map_id)
    map_id = map_id or nav.get_position()
    local entries = strong_candidate_entries(map_id)
    if #entries == 0 then
        debug_tools.info(string.format("SURVEY_STRONG_CANDIDATES map=0x%02X none", map_id))
        return 0
    end
    debug_tools.info(string.format("SURVEY_STRONG_CANDIDATES map=0x%02X count=%d", map_id, #entries))
    for _, entry in ipairs(entries) do
        debug_tools.info(string.format(
            "SURVEY_STRONG_CANDIDATE map=0x%02X x=%d y=%d key=%s count=%d targets=%d retry_successes=%d approaches=%s confidence=%s",
            map_id,
            entry.x,
            entry.y,
            entry.key,
            entry.count,
            entry.target_count,
            entry.retry_successes,
            join_sorted_keys(entry.approaches, "|"),
            tostring(entry.confidence)))
    end
    return #entries
end

function M.dump_survey_report(map_id)
    map_id = map_id or nav.get_position()
    local run = last_runs[map_id]
    if not run then
        debug_tools.info(string.format("SURVEY_REPORT map=0x%02X none", map_id))
        return 0
    end
    local summary = compute_summary(run)
    debug_tools.info(string.format(
        "SURVEY_REPORT map=0x%02X run=%d total=%d successes=%d failures=%d no_route=%d movement_failed=%d suspected_engine_blocked=%d state_issues=%d adjacency_issues=%d",
        map_id,
        run.run_id,
        summary.total,
        summary.successes,
        summary.failures,
        summary.no_route_found,
        summary.route_found_but_movement_failed,
        summary.suspected_engine_blocked_tile,
        summary.command_timing_or_state_issue,
        summary.wrong_adjacency_or_interaction_assumption))
    for _, result in ipairs(run.results) do
        log_result(result)
    end
    return summary.total
end

function M.report_findings(map_id)
    map_id = map_id or nav.get_position()
    local run = last_runs[map_id]
    local failed = M.report_failed_targets(map_id)
    local strong = M.report_strong_candidates(map_id)
    if not run then
        debug_tools.info(string.format("SURVEY_FINDINGS map=0x%02X none", map_id))
        return {failed_targets = 0, strong_candidates = 0}
    end
    debug_tools.info(string.format(
        "SURVEY_FINDINGS map=0x%02X run=%d failed_targets=%d strong_reroute_candidates=%d",
        map_id,
        run.run_id,
        failed,
        strong))
    return {
        failed_targets = failed,
        strong_candidates = strong,
    }
end

function M.report_candidate_suggestions(map_id)
    map_id = map_id or nav.get_position()
    local suggestions = candidate_suggestions(map_id)
    if #suggestions == 0 then
        debug_tools.info(string.format("SURVEY_CANDIDATE_SUGGESTIONS map=0x%02X none", map_id))
        return 0
    end
    debug_tools.info(string.format("SURVEY_CANDIDATE_SUGGESTIONS map=0x%02X count=%d", map_id, #suggestions))
    for _, suggestion in ipairs(suggestions) do
        debug_tools.info(string.format(
            "SURVEY_CANDIDATE_SUGGESTION map=0x%02X x=%d y=%d key=%s kind=%s approaches=%s confidence=%s count=%d retry_successes=%d targets=%d",
            map_id,
            suggestion.x,
            suggestion.y,
            suggestion.key,
            suggestion.kind,
            table.concat(suggestion.approaches, "|"),
            tostring(suggestion.confidence),
            suggestion.count,
            suggestion.retry_successes,
            suggestion.target_count))
    end
    return #suggestions
end

function M.export_directional_candidates(map_id)
    map_id = map_id or nav.get_position()
    local suggestions = candidate_suggestions(map_id)
    debug_tools.info(string.format("SURVEY_DIRECTIONAL_EXPORT map=0x%02X count=%d", map_id, #suggestions))
    if #suggestions == 0 then
        return 0
    end
    debug_tools.info(string.format("    [0x%02X] = {", map_id))
    for _, suggestion in ipairs(suggestions) do
        if suggestion.kind == "full_block" then
            debug_tools.info(string.format(
                '        ["%s"] = {north=true, south=true, east=true, west=true},  -- confidence=%s count=%d retry_successes=%d',
                suggestion.key,
                suggestion.confidence,
                suggestion.count,
                suggestion.retry_successes))
        else
            local dir_parts = {}
            for _, approach in ipairs(suggestion.approaches) do
                dir_parts[#dir_parts + 1] = approach .. "=true"
            end
            debug_tools.info(string.format(
                '        ["%s"] = {%s},  -- confidence=%s count=%d retry_successes=%d',
                suggestion.key,
                table.concat(dir_parts, ", "),
                suggestion.confidence,
                suggestion.count,
                suggestion.retry_successes))
        end
    end
    debug_tools.info("    },")
    return #suggestions
end

function M.export_blocked_candidates(map_id)
    map_id = map_id or nav.get_position()
    local entries = sorted_candidate_entries(map_id)
    debug_tools.info(string.format("SURVEY_CANDIDATE_EXPORT map=0x%02X count=%d", map_id, #entries))
    if #entries == 0 then
        return 0
    end
    debug_tools.info(string.format("    [0x%02X] = {", map_id))
    for _, entry in ipairs(entries) do
        debug_tools.info(string.format(
            '        ["%s"] = {count=%d, confidence=%q, retry_successes=%d, targets=%d, approaches={%s}},',
            entry.key,
            entry.count,
            entry.confidence,
            entry.retry_successes,
            entry.target_count,
            join_sorted_keys(entry.approaches, "=true, ") .. (next(entry.approaches) and "=true" or "")))
    end
    debug_tools.info("    },")
    return #entries
end

return M
