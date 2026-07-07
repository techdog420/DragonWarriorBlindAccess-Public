-- map_survey.lua
-- Autonomous map-level survey and blocked-tile diagnostics.
--
-- Drives repeated object-target pathfinding/autowalk attempts on the current
-- map, records structured per-target results, and accumulates conservative
-- blocked-tile candidates separate from permanent map data.

local auto_step   = require "auto_step"
local addr        = require "addresses"
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
-- Dragon Warrior's NPC renderer skips slots only when both low coordinate bits
-- are zero. Parking at 31,31 still leaves slots active and can wedge the OAM
-- clear loop near Cantlin, so use the engine's inactive coordinate.
local PARKED_NPC_COORD = 0
local CONTINUATION_TRAP_AREA_LIMIT = 16
local CONTINUATION_TRAP_MIN_REMAINING = 1
local CONTINUATION_TRAP_MAX_DEFER_LANDINGS = 2
local ISOLATED_START_CLUSTER_MIN_TARGETS = 2
-- Defer a large-area landing only when it would strand most of the remaining
-- queue. "Most" means the landing reaches strictly less than half of them and
-- we have at least this many remaining targets to average over, so a single
-- unreachable outlier in a 2-target tail does not trip the heuristic.
local CONTINUATION_TRAP_STRANDED_MAJORITY_MIN_TARGETS = 3
local SURVEY_START_ABORT_AREA_LIMIT = 16
local SURVEY_START_ABORT_HARD_AREA_LIMIT = 12
local SURVEY_START_ABORT_MAX_OPEN_EXITS = 2
local SURVEY_START_ABORT_MIN_TARGETS_FOR_COVERAGE = 8
local SURVEY_START_ABORT_MAX_REACHABLE_TARGETS = 1
local ADJACENT_ISOLATED_MAX_OPEN_EXITS = 1
local ADJACENT_ISOLATED_TINY_AREA_LIMIT = 2
local SURVEY_MAX_TOTAL_RETRIES_PER_TARGET = 2
local SURVEY_ROUTE_CHURN_BLOCK_EVENT_LIMIT = 32
-- Abort the survey if current HP drops to or below this value to prevent
-- the character dying mid-run on damage tiles (swamp/traps in some areas).
local SURVEY_LOW_HP_ABORT_THRESHOLD = 8

local SURVEY_DIRECTIONS = {
    {name = "north", dx = 0, dy = -1, approach = "south"},
    {name = "south", dx = 0, dy = 1, approach = "north"},
    {name = "west",  dx = -1, dy = 0, approach = "east"},
    {name = "east",  dx = 1, dy = 0, approach = "west"},
}

local function trim(s)
    if s == nil then return nil end
    return tostring(s):match("^%s*(.-)%s*$")
end

local function normalize_target_token(value)
    value = trim(value)
    if not value or value == "" then
        return nil
    end
    return value:lower()
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

local function parse_survey_tokens(arg, opts)
    opts = opts or {}
    local parsed = {
        park_npcs = false,
        retry_failed = false,
        target_token = nil,
    }

    for _, token in ipairs(split_arg_list(arg)) do
        local lower = tostring(token):lower()
        if lower == "park_npcs" then
            parsed.park_npcs = true
        elseif lower == "retry_failed" or lower == "failed" then
            if not opts.allow_retry_failed then
                return nil, "retry_failed is only valid for object survey commands"
            end
            parsed.retry_failed = true
        elseif opts.allow_target_token and not parsed.target_token then
            parsed.target_token = token
        else
            return nil, "Unknown survey option: " .. tostring(token)
        end
    end

    return parsed
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
        service = obj.service,
        interaction_x = obj.interaction_x,
        interaction_y = obj.interaction_y,
        interaction_face_dir = obj.interaction_face_dir,
    }
end

local function copy_target_list(list)
    local copy = {}
    if not list then return copy end
    for i, obj in ipairs(list) do
        copy[i] = copy_object(obj)
    end
    return copy
end

local function get_survey_npc_mode(opts)
    if opts and opts.park_npcs then
        return "park_npcs"
    end
    return "live"
end

local function input_contamination_refusal(command_name, opts)
    if debug_tools.input_contamination_refusal then
        return debug_tools.input_contamination_refusal(command_name, opts)
    end
    if debug_tools.edge_probe_input_refusal then
        return debug_tools.edge_probe_input_refusal(command_name)
    end
    return nil
end

local function has_active_auto_step()
    if auto_step.is_route_active then
        local ok, active = pcall(auto_step.is_route_active)
        if ok and active == true then
            return true
        end
    end
    if not auto_step.get_active_step_state then
        return false
    end
    local ok, state = pcall(auto_step.get_active_step_state)
    return ok and state ~= nil
end

local function is_active_npc_slot(byte0, byte1)
    local x = AND(byte0, 0x1F)
    local y = AND(byte1, 0x1F)
    if x == 0 and y == 0 then
        return false
    end
    if x == PARKED_NPC_COORD and y == PARKED_NPC_COORD then
        return false
    end
    return true
end

local function parse_npc_slot_id(object_id)
    local slot = tostring(object_id or ""):match("^npc_(%d+)$")
    if not slot then return nil end
    return tonumber(slot)
end

local function write_npc_bytes(slot, byte0, byte1, byte2)
    local base = addr.NPC_DATA_START + (slot * addr.NPC_ENTRY_SIZE)
    memory.writebyte(base, byte0)
    memory.writebyte(base + 1, byte1)
    memory.writebyte(base + 2, byte2)
end

local function capture_npc_parking_state()
    local map_id = nav.get_position()
    local state = {
        map_id = map_id,
        slots = {},
        exempt_slot = nil,
    }

    for slot = 0, addr.NPC_COUNT - 1 do
        local base = addr.NPC_DATA_START + (slot * addr.NPC_ENTRY_SIZE)
        local byte0 = memory.readbyte(base)
        local byte1 = memory.readbyte(base + 1)
        local byte2 = memory.readbyte(base + 2)
        if is_active_npc_slot(byte0, byte1) then
            state.slots[slot] = {
                byte0 = byte0,
                byte1 = byte1,
                byte2 = byte2,
                parked_byte0 = AND(byte0, 0xE0) + PARKED_NPC_COORD,
                parked_byte1 = AND(byte1, 0xE0) + PARKED_NPC_COORD,
            }
        end
    end

    return state
end

local function apply_npc_parking_state(state)
    if not state then return 0 end
    local parked = 0
    for slot, snapshot in pairs(state.slots) do
        if slot ~= state.exempt_slot then
            write_npc_bytes(slot, snapshot.parked_byte0, snapshot.parked_byte1, snapshot.byte2)
            parked = parked + 1
        end
    end
    return parked
end

local function set_npc_parking_exempt_slot(state, exempt_slot)
    if not state then
        return nil, false
    end
    if state.exempt_slot == exempt_slot then
        return exempt_slot, false
    end
    state.exempt_slot = exempt_slot
    if exempt_slot ~= nil then
        local snapshot = state.slots[exempt_slot]
        if snapshot then
            write_npc_bytes(exempt_slot, snapshot.byte0, snapshot.byte1, snapshot.byte2)
        end
    end
    return exempt_slot, true
end

local function restore_npc_parking_state(state)
    if not state then
        return 0, false
    end
    local map_id = nav.get_position()
    if map_id ~= state.map_id then
        return 0, false
    end

    local restored = 0
    for slot, snapshot in pairs(state.slots) do
        write_npc_bytes(slot, snapshot.byte0, snapshot.byte1, snapshot.byte2)
        restored = restored + 1
    end
    return restored, true
end

local function get_target_exempt_slot(target)
    local npc_type = objects.TYPE_NPC or "npc"
    if not target or target.type ~= npc_type then
        return nil
    end
    return parse_npc_slot_id(target.id)
end

local function apply_survey_npc_parking()
    if not survey_state or not survey_state.npc_parking then
        return 0
    end
    return apply_npc_parking_state(survey_state.npc_parking)
end

local function update_survey_npc_parking_for_target(target)
    if not survey_state or not survey_state.npc_parking then
        return
    end

    local exempt_slot, changed = set_npc_parking_exempt_slot(
        survey_state.npc_parking,
        get_target_exempt_slot(target))
    local parked = apply_survey_npc_parking()
    if changed then
        debug_tools.info(string.format(
            "SURVEY_NPC_PARK_TARGET run=%d map=0x%02X target_id=%s exempt_slot=%s parked_slots=%d",
            survey_state.run_id or 0,
            survey_state.map_id or 0,
            tostring(target and target.id or ""),
            exempt_slot and tostring(exempt_slot) or "-",
            parked))
    end
end

local function release_survey_npc_parking(reason)
    if not survey_state or not survey_state.npc_parking then
        return
    end

    local restored_slots, restored = restore_npc_parking_state(survey_state.npc_parking)
    debug_tools.info(string.format(
        "SURVEY_NPC_PARK_RESTORE run=%d map=0x%02X restored=%s restored_slots=%d reason=%s",
        survey_state.run_id or 0,
        survey_state.map_id or 0,
        restored and "true" or "false",
        restored_slots,
        tostring(reason or "complete")))
    survey_state.npc_parking = nil
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

local function join_or_dash(list)
    if not list or #list == 0 then
        return "-"
    end
    return table.concat(list, "|")
end

local function append_direction(parts, dir_name)
    parts[#parts + 1] = dir_name
end

local function build_blocking_signature(blocking)
    if not blocking then
        return "-"
    end

    local parts = {}
    for key, value in pairs(blocking) do
        if type(value) == "table" then
            parts[#parts + 1] = key .. ":" .. table.concat(sorted_truthy_keys(value), ",")
        else
            parts[#parts + 1] = key .. ":" .. tostring(value)
        end
    end
    table.sort(parts)
    if #parts == 0 then
        return "-"
    end
    return table.concat(parts, ";")
end

local function invalidate_preview_caches()
    if not survey_state then
        return
    end
    survey_state.preview_cache = {}
    survey_state.cell_diagnostics_cache = {}
    survey_state.blocking_cache = {}
end

local function get_cached_blocking(map_id, skip_npcs)
    local opts = skip_npcs and {skip_npcs = true} or nil
    if not survey_state then
        local blocking = route_mgr.build_path_blocking(map_id, opts)
        return blocking, build_blocking_signature(blocking)
    end

    local cache_key = string.format("0x%02X:%s", map_id, skip_npcs and "skip" or "full")
    local cached = survey_state.blocking_cache and survey_state.blocking_cache[cache_key]
    if cached then
        return cached.blocking, cached.signature
    end

    local blocking = route_mgr.build_path_blocking(map_id, opts)
    local signature = build_blocking_signature(blocking)
    cached = {
        blocking = blocking,
        signature = signature,
    }
    survey_state.blocking_cache = survey_state.blocking_cache or {}
    survey_state.blocking_cache[cache_key] = cached
    return blocking, signature
end

local function inspect_passable_exits(map_id, x, y, blocking)
    if not blocking then
        blocking = route_mgr.build_path_blocking(map_id, {skip_npcs = true})
    end
    local open_dirs = {}
    local blocked_dirs = {}

    for _, dir in ipairs(SURVEY_DIRECTIONS) do
        local nx = x + dir.dx
        local ny = y + dir.dy
        local details = map_reader.get_walkability_details(map_id, nx, ny)
        local block = blocking and blocking[cell_key(nx, ny)] or nil

        if not details or details.effective_walkable ~= true then
            blocked_dirs[#blocked_dirs + 1] = dir.name .. ":tile"
        elseif block == "npc" then
            blocked_dirs[#blocked_dirs + 1] = dir.name .. ":npc"
        elseif type(block) == "table" and block[dir.approach] then
            blocked_dirs[#blocked_dirs + 1] = dir.name .. ":directional(" .. dir.approach .. ")"
        else
            append_direction(open_dirs, dir.name)
        end
    end

    return {
        open_dirs = open_dirs,
        blocked_dirs = blocked_dirs,
        open_count = #open_dirs,
    }
end

local function is_effectively_walkable(map_id, x, y, blocking, approach)
    local details = map_reader.get_walkability_details(map_id, x, y)
    if not details or details.effective_walkable ~= true or details.permanent_blocked then
        return false
    end

    local block = blocking and blocking[cell_key(x, y)] or nil
    if not block then
        return true
    end
    if type(block) == "table" then
        if not approach then
            return true
        end
        return block[approach] ~= true
    end
    return false
end

local function count_reachable_walk_area(map_id, start_x, start_y, blocking, limit)
    limit = limit or 128
    if not is_effectively_walkable(map_id, start_x, start_y, blocking, nil) then
        return 0
    end

    local queue = {{x = start_x, y = start_y}}
    local head = 1
    local seen = {[cell_key(start_x, start_y)] = true}
    local count = 0

    while head <= #queue and count < limit do
        local current = queue[head]
        head = head + 1
        count = count + 1

        for _, dir in ipairs(SURVEY_DIRECTIONS) do
            local nx = current.x + dir.dx
            local ny = current.y + dir.dy
            local key = cell_key(nx, ny)
            if not seen[key] and is_effectively_walkable(map_id, nx, ny, blocking, dir.approach) then
                seen[key] = true
                queue[#queue + 1] = {x = nx, y = ny}
            end
        end
    end

    return count
end

local function format_direction_list(list)
    if list and #list > 0 then
        return table.concat(list, "|")
    end
    return "-"
end

local function get_cell_diagnostics(map_id, x, y, opts)
    opts = opts or {}
    local skip_npcs = opts.skip_npcs == true
    local blocking = opts.blocking
    local blocking_signature = opts.blocking_signature
    if not blocking then
        blocking, blocking_signature = get_cached_blocking(map_id, skip_npcs)
    elseif not blocking_signature then
        blocking_signature = build_blocking_signature(blocking)
    end

    local cache_key = nil
    if survey_state and opts.no_cache ~= true then
        cache_key = table.concat({
            string.format("0x%02X", map_id),
            tostring(x),
            tostring(y),
            skip_npcs and "skip" or "full",
            blocking_signature or "-",
        }, "|")
        local cached = survey_state.cell_diagnostics_cache and survey_state.cell_diagnostics_cache[cache_key]
        if cached then
            return cached
        end
    end

    local exit_info = inspect_passable_exits(map_id, x, y, blocking)
    local info = {
        map_id = map_id,
        start_x = x,
        start_y = y,
        reachable_area = count_reachable_walk_area(map_id, x, y, blocking),
        open_exit_count = exit_info.open_count,
        open_dirs = exit_info.open_dirs,
        blocked_dirs = exit_info.blocked_dirs,
        open_exits_text = format_direction_list(exit_info.open_dirs),
        blocked_exits_text = format_direction_list(exit_info.blocked_dirs),
    }

    if cache_key then
        survey_state.cell_diagnostics_cache[cache_key] = info
    end
    return info
end

local count_reachable_targets_from_start

local function analyze_survey_start(targets, map_id, start_x, start_y)
    local start_info = get_cell_diagnostics(map_id, start_x, start_y, {skip_npcs = true})
    local target_count = targets and #targets or 0
    local reachable_targets = nil
    local unreachable_targets = nil
    if target_count >= SURVEY_START_ABORT_MIN_TARGETS_FOR_COVERAGE
       and count_reachable_targets_from_start then
        local summary = count_reachable_targets_from_start(targets, map_id, start_x, start_y)
        reachable_targets = summary.reachable
        unreachable_targets = summary.unreachable
    end
    local isolated_by_area = target_count > 1
        and (
            start_info.reachable_area <= SURVEY_START_ABORT_HARD_AREA_LIMIT
            or (
                start_info.reachable_area <= SURVEY_START_ABORT_AREA_LIMIT
                and start_info.open_exit_count <= SURVEY_START_ABORT_MAX_OPEN_EXITS
            )
        )
    local isolated_by_target_coverage = target_count >= SURVEY_START_ABORT_MIN_TARGETS_FOR_COVERAGE
        and reachable_targets ~= nil
        and reachable_targets <= SURVEY_START_ABORT_MAX_REACHABLE_TARGETS

    return {
        map_id = map_id,
        start_x = start_x,
        start_y = start_y,
        target_count = target_count,
        reachable_targets = reachable_targets,
        unreachable_targets = unreachable_targets,
        reachable_area = start_info.reachable_area,
        open_exit_count = start_info.open_exit_count,
        open_dirs = start_info.open_dirs,
        blocked_dirs = start_info.blocked_dirs,
        open_exits_text = start_info.open_exits_text,
        blocked_exits_text = start_info.blocked_exits_text,
        isolated_start = isolated_by_area or isolated_by_target_coverage,
        isolation_reason = isolated_by_area and "small_reachable_area"
            or (isolated_by_target_coverage and "low_target_coverage" or nil),
        area_limit = SURVEY_START_ABORT_AREA_LIMIT,
        hard_area_limit = SURVEY_START_ABORT_HARD_AREA_LIMIT,
        open_exit_limit = SURVEY_START_ABORT_MAX_OPEN_EXITS,
        coverage_min_targets = SURVEY_START_ABORT_MIN_TARGETS_FOR_COVERAGE,
        coverage_reachable_limit = SURVEY_START_ABORT_MAX_REACHABLE_TARGETS,
    }
end

local function no_targets_message(mode, map_id)
    if mode == "retry_failed" then
        return string.format("No failed survey targets are currently loaded on map %02X", map_id)
    end
    return string.format("No survey targets found on map %02X", map_id)
end

local function plan_preview_for_target(map_id, start_x, start_y, target, opts)
    if not target then
        return nil
    end

    opts = opts or {}
    local skip_npcs = opts.skip_npcs == true
    local blocking = opts.blocking
    local blocking_signature = opts.blocking_signature
    if not blocking then
        blocking, blocking_signature = get_cached_blocking(map_id, skip_npcs)
    elseif not blocking_signature then
        blocking_signature = build_blocking_signature(blocking)
    end

    local cache_key = nil
    if survey_state and opts.no_cache ~= true then
        cache_key = table.concat({
            string.format("0x%02X", map_id),
            tostring(start_x),
            tostring(start_y),
            tostring(target.id or cell_key(target.x or -1, target.y or -1)),
            tostring(target.x or -1),
            tostring(target.y or -1),
            tostring(opts.path_mode or "auto"),
            skip_npcs and "skip" or "full",
            blocking_signature or "-",
        }, "|")
        local cached = survey_state.preview_cache and survey_state.preview_cache[cache_key]
        if cached then
            return cached
        end
    end

    local plan_opts = {
        map_id = map_id,
        start_x = start_x,
        start_y = start_y,
        blocking = blocking,
        skip_npcs = skip_npcs,
        path_mode = opts.path_mode,
        store_debug_path = false,
        survey_safe = opts.survey_safe ~= false,
    }
    if opts.allow_adjacent_fallback ~= nil then
        plan_opts.allow_adjacent_fallback = opts.allow_adjacent_fallback
    end

    local plan = route_mgr.plan_path_to_object(target, plan_opts)
    if cache_key then
        survey_state.preview_cache[cache_key] = plan
    end
    return plan
end

count_reachable_targets_from_start = function(targets, map_id, start_x, start_y)
    local total = targets and #targets or 0
    if total == 0 then
        return {total = 0, reachable = 0, unreachable = 0}
    end

    local blocking = nil
    if route_mgr.build_path_blocking then
        blocking = route_mgr.build_path_blocking(map_id, {skip_npcs = true})
    end

    local reachable = 0
    local unreachable = 0
    for _, target in ipairs(targets) do
        local plan = route_mgr.plan_path_to_object(target, {
            map_id = map_id,
            start_x = start_x,
            start_y = start_y,
            blocking = blocking,
            skip_npcs = true,
            store_debug_path = false,
            survey_safe = true,
        })
        if plan and plan.result ~= "No path found" then
            reachable = reachable + 1
        else
            unreachable = unreachable + 1
        end
    end

    return {
        total = total,
        reachable = reachable,
        unreachable = unreachable,
    }
end

local function summarize_remaining_reachability(map_id, start_x, start_y, opts)
    opts = opts or {}
    if not survey_state or not survey_state.queue then
        return {
            total = 0,
            reachable = 0,
            unreachable = 0,
        }
    end

    local skip_npcs = opts.skip_npcs == true
    local blocking = opts.blocking
    local blocking_signature = opts.blocking_signature
    if not blocking then
        blocking, blocking_signature = get_cached_blocking(map_id, skip_npcs)
    elseif not blocking_signature then
        blocking_signature = build_blocking_signature(blocking)
    end

    local first_index = opts.first_index or ((survey_state.queue_index or 0) + 1)
    local exclude_index = opts.exclude_index
    local total = 0
    local reachable = 0
    local unreachable = 0

    for i = first_index, #survey_state.queue do
        local entry = survey_state.queue[i]
        if i ~= exclude_index and entry and entry.target then
            total = total + 1
            local plan = plan_preview_for_target(map_id, start_x, start_y, entry.target, {
                skip_npcs = skip_npcs,
                blocking = blocking,
                blocking_signature = blocking_signature,
                survey_safe = true,
            })
            if plan and plan.result ~= "No path found" then
                reachable = reachable + 1
            else
                unreachable = unreachable + 1
            end
        end
    end

    return {
        total = total,
        reachable = reachable,
        unreachable = unreachable,
    }
end

local function get_plan_landing(start_x, start_y, plan)
    if plan and plan.path and #plan.path > 0 then
        local last = plan.path[#plan.path]
        return last.x, last.y
    end
    return start_x, start_y
end

local function remaining_targets_after_current()
    if not survey_state or not survey_state.queue then
        return 0
    end

    local remaining = 0
    for i = (survey_state.queue_index or 0) + 2, #survey_state.queue do
        if survey_state.queue[i] and survey_state.queue[i].target then
            remaining = remaining + 1
        end
    end
    return remaining
end

local function evaluate_continuation_trap(queue_entry, map_id, start_x, start_y, plan, remaining_targets_override, queue_position_override)
    if not survey_state or not queue_entry or not queue_entry.target or not plan or not plan.path or #plan.path == 0 then
        return nil
    end

    local target_id = queue_entry.target.id
    local landing_x, landing_y = get_plan_landing(start_x, start_y, plan)
    local landing_key = cell_key(landing_x, landing_y)
    local deferred_landings = survey_state.defer_landings[target_id] or {}
    local landing_defer_count = deferred_landings[landing_key] or 0
    if landing_defer_count == 0 and count_truthy_keys(deferred_landings) >= CONTINUATION_TRAP_MAX_DEFER_LANDINGS then
        return nil
    end

    local remaining_targets = remaining_targets_override
    if remaining_targets == nil then
        remaining_targets = remaining_targets_after_current()
    end
    if remaining_targets < CONTINUATION_TRAP_MIN_REMAINING then
        return nil
    end

    local structural_blocking, blocking_signature = get_cached_blocking(map_id, true)
    local next_index = (survey_state.queue_index or 0) + 1
    local remaining_first_index = next_index + 1
    local exclude_index = nil
    if queue_position_override and queue_position_override > next_index then
        exclude_index = queue_position_override
    end
    local landing_info = get_cell_diagnostics(map_id, landing_x, landing_y, {
        skip_npcs = true,
        blocking = structural_blocking,
        blocking_signature = blocking_signature,
    })
    local remaining_coverage = summarize_remaining_reachability(map_id, landing_x, landing_y, {
        first_index = remaining_first_index,
        exclude_index = exclude_index,
        skip_npcs = true,
        blocking = structural_blocking,
        blocking_signature = blocking_signature,
    })
    local strands_all_remaining = remaining_coverage.total > 0 and remaining_coverage.reachable == 0
    local strands_majority = remaining_coverage.total >= CONTINUATION_TRAP_STRANDED_MAJORITY_MIN_TARGETS
        and remaining_coverage.reachable * 2 < remaining_coverage.total

    if landing_info.reachable_area > CONTINUATION_TRAP_AREA_LIMIT
        and (strands_all_remaining or strands_majority)
    then
        local current_coverage = summarize_remaining_reachability(map_id, start_x, start_y, {
            first_index = remaining_first_index,
            exclude_index = exclude_index,
            skip_npcs = true,
            blocking = structural_blocking,
            blocking_signature = blocking_signature,
        })
        if remaining_coverage.reachable >= current_coverage.reachable then
            return nil
        end
    end

    if landing_info.reachable_area > CONTINUATION_TRAP_AREA_LIMIT
        and not strands_all_remaining
        and not strands_majority
    then
        return nil
    end

    -- For large areas: if all remaining targets are still reachable from the
    -- landing, there is nothing to protect against — don't defer. This
    -- terminates the defer loop that occurs when every remaining target is
    -- inside the large area itself.
    -- For small areas (≤ CONTINUATION_TRAP_AREA_LIMIT): always treat as a
    -- trap regardless of plan reachability — the planner may report routes
    -- as reachable even from a 0- or 1-cell pocket because it doesn't model
    -- physical movement constraints from that landing.
    if remaining_coverage.unreachable == 0 and landing_info.reachable_area > CONTINUATION_TRAP_AREA_LIMIT then
        return nil
    end

    return {
        landing_x = landing_x,
        landing_y = landing_y,
        landing_key = landing_key,
        reachable_area = landing_info.reachable_area,
        remaining_targets = remaining_targets,
        reachable_remaining = remaining_coverage.reachable,
        unreachable_remaining = remaining_coverage.unreachable,
        trap_reason = (landing_info.reachable_area <= CONTINUATION_TRAP_AREA_LIMIT)
            and "small_area"
            or "stranded_remainder",
    }
end

local function should_defer_continuation_trap(queue_entry, map_id, start_x, start_y, plan, queue_position_override)
    local trap = evaluate_continuation_trap(queue_entry, map_id, start_x, start_y, plan, nil, queue_position_override)
    if not trap then
        return false
    end

    if trap.remaining_targets == 1 and survey_state and survey_state.queue then
        local other_entry = survey_state.queue[(survey_state.queue_index or 0) + 2]
        if other_entry and other_entry.target and other_entry.target.id ~= queue_entry.target.id then
            local other_plan = plan_preview_for_target(map_id, start_x, start_y, other_entry.target, {
                store_debug_path = false,
                survey_safe = true,
            })
            local other_trap = evaluate_continuation_trap(other_entry, map_id, start_x, start_y, other_plan, 1, (survey_state.queue_index or 0) + 2)
            if other_trap then
                debug_tools.info(string.format(
                    "SURVEY_ENDGAME_ALLOW run=%d map=0x%02X idx=%d/%d target_id=%s other_target_id=%s landing=(%d,%d) reachable_area=%d reason=paired_continuation_traps remaining_targets=%d",
                    survey_state.run_id,
                    map_id,
                    queue_entry.original_index or ((survey_state.queue_index or 0) + 1),
                    survey_state.target_total,
                    tostring(queue_entry.target.id),
                    tostring(other_entry.target.id),
                    trap.landing_x,
                    trap.landing_y,
                    trap.reachable_area,
                    trap.remaining_targets))
                return false
            end
        end
    end

    return true, trap
end

local function is_reachable_plan(plan)
    return plan and plan.result ~= "No path found"
end

local function plan_path_length(plan)
    if not plan or not plan.path then
        return 0
    end
    return #plan.path
end

local function is_retry_or_deferred_entry(entry)
    if not survey_state or not entry or not entry.target then
        return false
    end
    return (entry.retry_number or 0) > 0
        or (survey_state.defer_counts[entry.target.id] or 0) > 0
end

local function maybe_reprioritize_queue()
    if not survey_state or not survey_state.queue then
        return
    end

    local next_index = survey_state.queue_index + 1
    local current_entry = survey_state.queue[next_index]
    if not is_retry_or_deferred_entry(current_entry) then
        return
    end

    local start_map_id, start_x, start_y = nav.get_position()
    local best_index = nil
    local best_group = nil
    local best_retry = nil
    local best_path_length = nil

    for i = next_index, #survey_state.queue do
        local entry = survey_state.queue[i]
        if entry and entry.target then
            local plan = plan_preview_for_target(start_map_id, start_x, start_y, entry.target, {
                survey_safe = true,
            })
            if is_reachable_plan(plan) then
                local should_skip = should_defer_continuation_trap(
                    entry,
                    start_map_id,
                    start_x,
                    start_y,
                    plan,
                    i)
                if not should_skip then
                    local candidate_group = is_retry_or_deferred_entry(entry) and 0 or 1
                    local retry_number = entry.retry_number or 0
                    local path_length = plan_path_length(plan)
                    if not best_index
                        or candidate_group < best_group
                        or (candidate_group == best_group and retry_number < best_retry)
                        or (candidate_group == best_group and retry_number == best_retry and path_length < best_path_length)
                        or (candidate_group == best_group and retry_number == best_retry and path_length == best_path_length and i < best_index)
                    then
                        best_index = i
                        best_group = candidate_group
                        best_retry = retry_number
                        best_path_length = path_length
                    end
                end
            end
        end
    end

    if not best_index or best_index == next_index then
        return
    end

    local chosen = survey_state.queue[best_index]
    local replaced = survey_state.queue[next_index]
    table.remove(survey_state.queue, best_index)
    table.insert(survey_state.queue, next_index, chosen)
    debug_tools.info(string.format(
        "SURVEY_REORDER run=%d map=0x%02X start=(%d,%d) queue_from=%d queue_to=%d target_id=%s retry=%d path_length=%d replaced_target_id=%s reason=reachable_priority",
        survey_state.run_id,
        start_map_id,
        start_x,
        start_y,
        best_index,
        next_index,
        tostring(chosen.target and chosen.target.id or ""),
        chosen.retry_number or 0,
        best_path_length or 0,
        tostring(replaced and replaced.target and replaced.target.id or "")))
end

local function get_or_create_no_path_cluster(map_id, start_x, start_y)
    if not survey_state then
        return nil
    end

    local key = cell_key(start_x, start_y)
    local cluster = survey_state.no_path_clusters[key]
    if cluster then
        return cluster
    end

    local start_info = get_cell_diagnostics(map_id, start_x, start_y, {skip_npcs = true})
    cluster = {
        key = key,
        start_x = start_x,
        start_y = start_y,
        count = 0,
        target_ids = {},
        target_count = 0,
        reachable_area = start_info.reachable_area,
        open_exit_count = start_info.open_exit_count,
        open_dirs = start_info.open_dirs,
        blocked_dirs = start_info.blocked_dirs,
        last_logged_target_count = 0,
        last_stranded_scan_target_count = 0,
    }
    survey_state.no_path_clusters[key] = cluster
    return cluster
end

local function ensure_map_candidates(map_id)
    if not blocked_candidates[map_id] then
        blocked_candidates[map_id] = {}
    end
    return blocked_candidates[map_id]
end

local function get_candidate_seam_observation(entry, approach)
    if not entry or not approach or type(route_mgr.get_seam_observation) ~= "function" then
        return nil
    end
    return route_mgr.get_seam_observation(entry.map_id, entry.x, entry.y, approach)
end

local function seam_observation_is_noisy(observation)
    return observation
        and (observation.blocked_count or 0) > 0
        and (observation.moved_count or 0) > 0
end

local function seam_observation_has_direct_block_repro(observation)
    return observation
        and observation.last_result == "blocked"
        and observation.last_source == "manual_block"
        and (observation.blocked_count or 0) > 0
        and (observation.moved_count or 0) == 0
end

local function candidate_has_noisy_seam(entry)
    if not entry then
        return false
    end
    for _, approach in ipairs(sorted_truthy_keys(entry.approaches)) do
        if seam_observation_is_noisy(get_candidate_seam_observation(entry, approach)) then
            return true
        end
    end
    return false
end

local function candidate_has_direct_block_repro(entry)
    if not entry then
        return false
    end
    for _, approach in ipairs(sorted_truthy_keys(entry.approaches)) do
        if seam_observation_has_direct_block_repro(get_candidate_seam_observation(entry, approach)) then
            return true
        end
    end
    return false
end

local function candidate_exportable_approaches(entry)
    local approaches = {}
    if not entry then
        return approaches
    end
    local requires_direct_repro = (entry.failure_count or 0) == 0
        and (entry.retry_successes or 0) > 0
    for _, approach in ipairs(sorted_truthy_keys(entry.approaches)) do
        local observation = get_candidate_seam_observation(entry, approach)
        if not seam_observation_is_noisy(observation) then
            if not requires_direct_repro or seam_observation_has_direct_block_repro(observation) then
                approaches[#approaches + 1] = approach
            end
        end
    end
    return approaches
end

local function compute_candidate_confidence(entry)
    if not entry then return "low" end
    if candidate_has_noisy_seam(entry) then
        return "needs_repro"
    end
    if candidate_has_direct_block_repro(entry) then
        return "high"
    end
    if (entry.state_issue_count or 0) > 0 and (entry.failure_count or 0) == 0 then
        return "needs_repro"
    end
    if (entry.retry_successes or 0) > 0 and (entry.failure_count or 0) == 0 then
        return "needs_repro"
    end
    if (entry.retry_successes or 0) >= 1 then
        return "high"
    end
    if (entry.target_count or 0) >= 2 or (entry.count or 0) >= 3 then
        return "high"
    end
    if (entry.count or 0) >= 2 or (entry.failure_count or 0) >= 1 then
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
    if compute_candidate_confidence(entry) == "needs_repro" then
        return false
    end
    if (entry.state_issue_count or 0) > 0 and (entry.failure_count or 0) == 0 then
        return false
    end
    if (entry.retry_successes or 0) <= 0 then
        return false
    end
    if (entry.count or 0) >= 2 then
        return true
    end
    if (entry.target_count or 0) >= 2 then
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
    local approaches = candidate_exportable_approaches(entry)
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
        state_issue_count = entry.state_issue_count or 0,
    }
end

local function candidate_suggestions(map_id)
    local result = {}
    for _, entry in ipairs(sorted_candidate_entries(map_id)) do
        if (entry.state_issue_count or 0) > 0
            and (entry.failure_count or 0) == 0
            and not candidate_has_direct_block_repro(entry) then
            -- Diagnostic-only until a focused repro separates map data from
            -- route execution/state noise.
        else
            local include = (CONFIDENCE_RANK[entry.confidence] or 0) >= CONFIDENCE_RANK.medium
            if include then
                local suggestion = build_candidate_suggestion(entry)
                if suggestion then
                    result[#result + 1] = suggestion
                end
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
        gated_or_isolated_region = 0,
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

local function sorted_failure_start_entries(run)
    local entries_by_key = {}
    if not run or not run.results then
        return {}
    end

    for _, result in ipairs(run.results) do
        if not result.movement_succeeded then
            local key = cell_key(result.start_x or -1, result.start_y or -1)
            local entry = entries_by_key[key]
            if not entry then
                entry = {
                    key = key,
                    start_x = result.start_x or -1,
                    start_y = result.start_y or -1,
                    failures = 0,
                    classifications = {
                        no_route_found = 0,
                        gated_or_isolated_region = 0,
                        route_found_but_movement_failed = 0,
                        suspected_engine_blocked_tile = 0,
                        command_timing_or_state_issue = 0,
                        wrong_adjacency_or_interaction_assumption = 0,
                    },
                    target_ids = {},
                    target_names = {},
                    target_count = 0,
                }
                entries_by_key[key] = entry
            end

            entry.failures = entry.failures + 1
            local classification = result.failure_classification
            if classification and entry.classifications[classification] ~= nil then
                entry.classifications[classification] = entry.classifications[classification] + 1
            end
            if result.target_id and not entry.target_ids[result.target_id] then
                entry.target_ids[result.target_id] = true
                entry.target_names[#entry.target_names + 1] = tostring(result.target_name or result.target_id)
                entry.target_count = entry.target_count + 1
            end
        end
    end

    local entries = {}
    for _, entry in pairs(entries_by_key) do
        table.sort(entry.target_names)
        entries[#entries + 1] = entry
    end
    table.sort(entries, function(a, b)
        if a.failures ~= b.failures then return a.failures > b.failures end
        if a.start_y ~= b.start_y then return a.start_y < b.start_y end
        return a.start_x < b.start_x
    end)
    return entries
end

local function log_failure_start_entries(map_id, entries)
    if #entries == 0 then
        debug_tools.info(string.format("SURVEY_FAILURE_STARTS map=0x%02X none", map_id))
        return 0
    end

    debug_tools.info(string.format("SURVEY_FAILURE_STARTS map=0x%02X count=%d", map_id, #entries))
    for _, entry in ipairs(entries) do
        debug_tools.info(string.format(
            "SURVEY_FAILURE_START map=0x%02X start=(%d,%d) failures=%d distinct_targets=%d gated_or_isolated=%d no_route=%d movement_failed=%d suspected_engine_blocked=%d state_issues=%d adjacency_issues=%d targets=%s",
            map_id,
            entry.start_x,
            entry.start_y,
            entry.failures,
            entry.target_count,
            entry.classifications.gated_or_isolated_region or 0,
            entry.classifications.no_route_found or 0,
            entry.classifications.route_found_but_movement_failed or 0,
            entry.classifications.suspected_engine_blocked_tile or 0,
            entry.classifications.command_timing_or_state_issue or 0,
            entry.classifications.wrong_adjacency_or_interaction_assumption or 0,
            join_or_dash(entry.target_names)))
    end
    return #entries
end

local function is_clean_no_path_result(result)
    if not result or result.movement_succeeded then
        return false
    end
    if result.failure_classification ~= "no_route_found" then
        return false
    end
    if (result.blocked_event_count or 0) > 0 then
        return false
    end
    if result.alternate_path_found then
        return false
    end
    if result.reason ~= "no_path" then
        return false
    end
    if result.finished_on_same_map == false then
        return false
    end
    return result.final_x == result.start_x and result.final_y == result.start_y
end

local function retroactively_reclassify_isolated_start_results(run)
    if not run or not run.results or not run.no_path_clusters then
        return 0
    end

    local changed = 0
    for _, result in ipairs(run.results) do
        if is_clean_no_path_result(result) then
            local cluster = run.no_path_clusters[cell_key(result.start_x or -1, result.start_y or -1)]
            if cluster and cluster.target_count >= ISOLATED_START_CLUSTER_MIN_TARGETS then
                result.failure_classification = "gated_or_isolated_region"
                changed = changed + 1
                debug_tools.info(string.format(
                    "SURVEY_RECLASSIFY run=%d map=0x%02X start=(%d,%d) target_id=%s from=no_route_found to=gated_or_isolated_region reason=isolated_start_cluster distinct_targets=%d",
                    run.run_id or 0,
                    run.map_id or 0,
                    result.start_x or -1,
                    result.start_y or -1,
                    tostring(result.target_id or ""),
                    cluster.target_count or 0))
            end
        end
    end

    return changed
end

local function finish_run(speak_message)
    if not survey_state then
        return
    end
    release_survey_npc_parking(survey_state.stop_reason or (speak_message == false and "aborted" or "complete"))
    retroactively_reclassify_isolated_start_results(survey_state)
    survey_state.summary = compute_summary(survey_state)
    last_runs[survey_state.map_id] = survey_state
    debug_tools.info(string.format(
        "SURVEY_COMPLETE run=%d map=0x%02X targets=%d successes=%d failures=%d no_route=%d gated_or_isolated=%d movement_failed=%d suspected_engine_blocked=%d state_issues=%d adjacency_issues=%d",
        survey_state.run_id,
        survey_state.map_id,
        survey_state.summary.total,
        survey_state.summary.successes,
        survey_state.summary.failures,
        survey_state.summary.no_route_found,
        survey_state.summary.gated_or_isolated_region,
        survey_state.summary.route_found_but_movement_failed,
        survey_state.summary.suspected_engine_blocked_tile,
        survey_state.summary.command_timing_or_state_issue,
        survey_state.summary.wrong_adjacency_or_interaction_assumption))
    if survey_state.summary.failures > 0 then
        log_failure_start_entries(survey_state.map_id, sorted_failure_start_entries(survey_state))
    end
    if speak_message ~= false then
        tolk.output_interrupt(string.format(
            "Survey complete on map %02X. %d successes, %d failures.",
            survey_state.map_id,
            survey_state.summary.successes,
            survey_state.summary.failures))
    end
    survey_state = nil
end

local function abort_survey_if_input_contaminated(source, command_name, input_opts)
    if not survey_state then
        return false
    end
    if source == "tick" and has_active_auto_step() then
        return false
    end
    local refusal, details = input_contamination_refusal(command_name or "survey_objects", input_opts)
    if not refusal then
        return false
    end
    local attempt = survey_state.active_attempt
    debug_tools.error(refusal)
    debug_tools.info(string.format(
        "SURVEY_ABORT run=%d map=0x%02X reason=input_contaminated source=%s target_id=%s %s",
        survey_state.run_id or 0,
        survey_state.map_id or 0,
        tostring(source or "-"),
        tostring(attempt and attempt.target and attempt.target.id or "-"),
        tostring(details or "")))
    if attempt then
        auto_step.cancel_active_step(true)
        if route_mgr.clear_active_route_context then
            route_mgr.clear_active_route_context("survey input contaminated")
        end
        survey_state.active_attempt = nil
    end
    survey_state.stop_reason = "input_contaminated"
    finish_run(false)
    tolk.output_interrupt("Survey aborted. Input contaminated.")
    return true
end

local function resolve_target_by_token(token)
    token = trim(token)
    if not token or token == "" then
        return objects.current_object(), nil
    end
    local obj = objects.find_object_by_id(token)
    if obj then
        return obj, nil
    end
    local index = parse_int(token)
    if index and index >= 1 then
        local list = objects.get_objects()
        return list[index], nil
    end

    local normalized = normalize_target_token(token)
    if not normalized then
        return nil, "Target not found"
    end

    local list = objects.get_objects()
    local exact_matches = {}
    local partial_matches = {}
    for _, candidate in ipairs(list) do
        local candidate_id = normalize_target_token(candidate and candidate.id)
        local candidate_name = normalize_target_token(candidate and candidate.name)
        local matched_exact = false

        if candidate_id and candidate_id == normalized then
            exact_matches[#exact_matches + 1] = candidate
            matched_exact = true
        elseif candidate_name and candidate_name == normalized then
            exact_matches[#exact_matches + 1] = candidate
            matched_exact = true
        end

        if not matched_exact then
            local id_match = candidate_id and string.find(candidate_id, normalized, 1, true)
            local name_match = candidate_name and string.find(candidate_name, normalized, 1, true)
            if id_match or name_match then
                partial_matches[#partial_matches + 1] = candidate
            end
        end
    end

    local matches = exact_matches
    if #matches == 0 then
        matches = partial_matches
    end
    if #matches == 1 then
        return matches[1], nil
    end
    if #matches > 1 then
        local labels = {}
        local limit = math.min(#matches, 4)
        for i = 1, limit do
            local candidate = matches[i]
            labels[#labels + 1] = string.format(
                "%s(%s)",
                tostring(candidate.name or "?"),
                tostring(candidate.id or "?"))
        end
        if #matches > limit then
            labels[#labels + 1] = "..."
        end
        return nil, string.format(
            "Ambiguous target token %q matched %d objects: %s",
            tostring(token),
            #matches,
            table.concat(labels, ", "))
    end
    return nil, "Target not found"
end

local function get_default_survey_targets()
    local list = objects.get_objects()
    local targets = {}
    for _, obj in ipairs(list) do
        if not (obj and obj.survey_exclude == true) then
            targets[#targets + 1] = copy_object(obj)
        end
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

local function analyze_alternate_mode(target, primary_mode, opts)
    opts = opts or {}
    local map_id = opts.map_id or nav.get_position()
    local _, start_x, start_y = nav.get_position()
    start_x = opts.start_x or start_x
    start_y = opts.start_y or start_y
    local alternate_mode = (primary_mode == "adjacent") and "direct" or "adjacent"
    local plan = plan_preview_for_target(map_id, start_x, start_y, target, {
        path_mode = alternate_mode,
        survey_safe = true,
        skip_npcs = opts.skip_npcs == true,
    })
    if not plan then
        return alternate_mode, false, 0, nil
    end
    local path_found = plan.result ~= "No path found"
    return alternate_mode, path_found, plan.path and #plan.path or 0, plan
end

local function analyze_skip_npcs_path(target, primary_mode, opts)
    opts = opts or {}
    local map_id = opts.map_id or nav.get_position()
    local _, start_x, start_y = nav.get_position()
    start_x = opts.start_x or start_x
    start_y = opts.start_y or start_y
    local plan = plan_preview_for_target(map_id, start_x, start_y, target, {
        path_mode = primary_mode,
        survey_safe = true,
        skip_npcs = true,
    })
    if not plan then
        return false, 0, nil
    end
    local path_found = plan.result ~= "No path found"
    return path_found, plan.path and #plan.path or 0, plan
end

local function analyze_isolated_adjacent_landings(attempt)
    if not attempt or attempt.path_mode ~= "adjacent" then
        return nil
    end
    local diagnostics = attempt.adjacent_diagnostics
    if not diagnostics or #diagnostics == 0 then
        return nil
    end

    local viable = 0
    local single_exit = 0
    local tiny = 0
    for _, diag in ipairs(diagnostics) do
        if diag.walkable == true and not diag.blocker then
            viable = viable + 1
            if (diag.open_exits or 99) <= ADJACENT_ISOLATED_MAX_OPEN_EXITS then
                single_exit = single_exit + 1
            end
            if (diag.reachable_area or 999) <= ADJACENT_ISOLATED_TINY_AREA_LIMIT then
                tiny = tiny + 1
            end
        end
    end

    if viable == 0 or single_exit ~= viable or tiny == 0 then
        return nil
    end

    return {
        viable_adjacent = viable,
        single_exit_adjacent = single_exit,
        tiny_adjacent = tiny,
    }
end

local function final_matches_suspected_tile(attempt, final_map_id, final_x, final_y)
    if not attempt or final_map_id ~= attempt.map_id or final_x == nil or final_y == nil then
        return false
    end
    return attempt.suspected_tile_set[cell_key(final_x, final_y)] == true
end

local function classify_attempt(attempt, final_map_id, final_x, final_y)
    attempt.alternate_mode = nil
    attempt.alternate_path_found = false
    attempt.skip_npcs_path_found = false

    if attempt.success then
        return nil
    end

    local alternate_mode, alternate_path_found = analyze_alternate_mode(attempt.target, attempt.path_mode, {
        map_id = attempt.map_id,
        start_x = attempt.start_x,
        start_y = attempt.start_y,
    })
    attempt.alternate_mode = alternate_mode
    attempt.alternate_path_found = alternate_path_found

    if attempt.plan_status == "no_path" then
        local adjacent_isolated = analyze_isolated_adjacent_landings(attempt)
        if adjacent_isolated then
            debug_tools.info(string.format(
                "SURVEY_TARGET_ISOLATED_ADJACENT run=%d map=0x%02X start=(%d,%d) target_id=%s target=(%d,%d) viable_adjacent=%d single_exit_adjacent=%d tiny_adjacent=%d reason=single_exit_micro_landing",
                survey_state and survey_state.run_id or 0,
                attempt.map_id or 0,
                attempt.start_x or -1,
                attempt.start_y or -1,
                tostring(attempt.target and attempt.target.id or ""),
                attempt.target and attempt.target.x or -1,
                attempt.target and attempt.target.y or -1,
                adjacent_isolated.viable_adjacent,
                adjacent_isolated.single_exit_adjacent,
                adjacent_isolated.tiny_adjacent))
            return "gated_or_isolated_region"
        end
        if alternate_path_found then
            return "wrong_adjacency_or_interaction_assumption"
        end
        local skip_npcs_path_found, skip_npcs_path_length = analyze_skip_npcs_path(attempt.target, attempt.path_mode, {
            map_id = attempt.map_id,
            start_x = attempt.start_x,
            start_y = attempt.start_y,
        })
        attempt.skip_npcs_path_found = skip_npcs_path_found
        if skip_npcs_path_found then
            debug_tools.info(string.format(
                "SURVEY_NPC_BLOCKED_ROUTE run=%d map=0x%02X start=(%d,%d) target_id=%s target=(%d,%d) path_mode=%s ignored_npc_path_length=%d",
                survey_state and survey_state.run_id or 0,
                attempt.map_id or 0,
                attempt.start_x or -1,
                attempt.start_y or -1,
                tostring(attempt.target and attempt.target.id or ""),
                attempt.target and attempt.target.x or -1,
                attempt.target and attempt.target.y or -1,
                tostring(attempt.path_mode or ""),
                skip_npcs_path_length or 0))
            return "command_timing_or_state_issue"
        end
        return "no_route_found"
    end

    if attempt.reason == "route_churn_cap" or attempt.route_churn_capped then
        return "command_timing_or_state_issue"
    end

    if attempt.reason == "manual_stop" and (#attempt.suspected_tiles > 0 or #attempt.blocked_tiles > 0) then
        debug_tools.info(string.format(
            "SURVEY_CLASSIFY_DOWNGRADE run=%d map=0x%02X target_id=%s from=manual_stop_route_evidence to=command_timing_or_state_issue suspected_tiles=%d blocked_events=%d",
            survey_state and survey_state.run_id or 0,
            attempt.map_id or 0,
            tostring(attempt.target and attempt.target.id or ""),
            #attempt.suspected_tiles,
            #attempt.blocked_tiles))
        return "command_timing_or_state_issue"
    end

    if #attempt.suspected_tiles > 0 then
        if attempt.reason == "route_inactive_without_completion"
            and #attempt.suspected_tiles == 1
            and final_matches_suspected_tile(attempt, final_map_id, final_x, final_y)
        then
            debug_tools.info(string.format(
                "SURVEY_CLASSIFY_DOWNGRADE run=%d map=0x%02X target_id=%s from=suspected_engine_blocked_tile to=command_timing_or_state_issue reason=orphaned_route_landed_on_suspect final=(%d,%d)",
                survey_state and survey_state.run_id or 0,
                attempt.map_id or 0,
                tostring(attempt.target and attempt.target.id or ""),
                final_x or -1,
                final_y or -1))
            return "command_timing_or_state_issue"
        end
        if attempt.reason == "reroute_no_path" and #attempt.suspected_tiles > 1 then
            return "command_timing_or_state_issue"
        end
        return "suspected_engine_blocked_tile"
    end
    if #attempt.blocked_tiles > 0 then
        return "route_found_but_movement_failed"
    end
    return "command_timing_or_state_issue"
end

local function observe_clean_no_path_cluster(attempt, final_map_id, final_x, final_y)
    if not survey_state or not attempt then
        return nil
    end
    if attempt.plan_status ~= "no_path" then
        return nil
    end
    if attempt.alternate_path_found then
        return nil
    end
    if #attempt.blocked_tiles > 0 or #attempt.suspected_tiles > 0 then
        return nil
    end
    if final_map_id ~= attempt.map_id then
        return nil
    end
    if final_x ~= attempt.start_x or final_y ~= attempt.start_y then
        return nil
    end
    local refreshed_target = refresh_object(attempt.target)
    local current_plan = plan_preview_for_target(attempt.map_id, attempt.start_x, attempt.start_y, refreshed_target, {
        path_mode = attempt.path_mode,
        survey_safe = true,
    })
    if is_reachable_plan(current_plan) then
        return nil
    end

    local cluster = get_or_create_no_path_cluster(attempt.map_id, attempt.start_x, attempt.start_y)
    cluster.count = cluster.count + 1
    if not cluster.target_ids[attempt.target.id] then
        cluster.target_ids[attempt.target.id] = true
        cluster.target_count = cluster.target_count + 1
    end

    if cluster.target_count >= ISOLATED_START_CLUSTER_MIN_TARGETS
        and cluster.target_count > (cluster.last_logged_target_count or 0)
    then
        cluster.last_logged_target_count = cluster.target_count
        debug_tools.info(string.format(
            "SURVEY_ISOLATED_START run=%d map=0x%02X start=(%d,%d) no_path_events=%d distinct_targets=%d reachable_area=%d open_exit_count=%d open_exits=%s blocked_exits=%s latest_target_id=%s reason=clustered_clean_no_path",
            survey_state.run_id,
            attempt.map_id,
            attempt.start_x,
            attempt.start_y,
            cluster.count,
            cluster.target_count,
            cluster.reachable_area,
            cluster.open_exit_count,
            join_or_dash(cluster.open_dirs),
            join_or_dash(cluster.blocked_dirs),
            tostring(attempt.target.id)))
    end

    return cluster
end

local function get_retry_reason(attempt, failure_classification, final_map_id, final_x, final_y)
    if not survey_state or not attempt then
        return nil
    end
    local target_id = attempt.target.id
    local retries = survey_state.retry_counts[attempt.target.id] or 0
    local reason_counts = survey_state.retry_reason_counts[target_id] or {}
    local function already_retried(reason)
        return (reason_counts[reason] or 0) >= 1
    end
    if retries >= SURVEY_MAX_TOTAL_RETRIES_PER_TARGET then
        return nil
    end

    if failure_classification == "no_route_found" then
        if retries >= 1 or already_retried("transient_no_path") then
            return nil
        end
        if attempt.plan_status ~= "no_path" then
            return nil
        end
        if #attempt.blocked_tiles > 0 or #attempt.suspected_tiles > 0 then
            return nil
        end
        return "transient_no_path"
    end

    if failure_classification == "command_timing_or_state_issue" then
        if attempt.plan_status ~= "queued" then
            return nil
        end
        if #attempt.blocked_tiles > 0 or #attempt.suspected_tiles > 0 then
            return nil
        end
        if final_map_id ~= attempt.map_id then
            return nil
        end
        if attempt.reason == "route_drift_off_path" then
            if already_retried("route_drift_retry") then
                return nil
            end
            return "route_drift_retry"
        end
        if attempt.reason ~= "route_inactive_without_completion" then
            return nil
        end
        if retries >= 1 or already_retried("timing_orphaned_route") then
            return nil
        end
        if final_x ~= attempt.start_x or final_y ~= attempt.start_y then
            return nil
        end
        return "timing_orphaned_route"
    end

    return nil
end

local function retry_should_run_next(reason)
    return reason == "route_drift_retry"
        or reason == "timing_orphaned_route"
end

local function should_skip_entry_from_stranded_start(entry, map_id, start_x, start_y)
    if not entry or not entry.target then
        return false, nil
    end

    local target = refresh_object(entry.target)
    local primary_plan = plan_preview_for_target(map_id, start_x, start_y, target, {
        survey_safe = true,
    })
    if is_reachable_plan(primary_plan) then
        return false, {
            target = target,
            primary_plan = primary_plan,
        }
    end

    local primary_mode = primary_plan and primary_plan.path_mode or nil
    local alternate_mode, alternate_path_found = analyze_alternate_mode(target, primary_mode, {
        map_id = map_id,
        start_x = start_x,
        start_y = start_y,
    })
    if alternate_path_found then
        return false, {
            target = target,
            primary_plan = primary_plan,
            alternate_mode = alternate_mode,
            alternate_path_found = true,
        }
    end

    local skip_npcs_path_found = analyze_skip_npcs_path(target, primary_mode, {
        map_id = map_id,
        start_x = start_x,
        start_y = start_y,
    })
    if skip_npcs_path_found then
        return false, {
            target = target,
            primary_plan = primary_plan,
            alternate_mode = alternate_mode,
            alternate_path_found = false,
            skip_npcs_path_found = true,
        }
    end

    return true, {
        target = target,
        primary_plan = primary_plan,
        alternate_mode = alternate_mode,
        alternate_path_found = false,
        skip_npcs_path_found = false,
    }
end

local function build_stranded_skip_result(entry, detail, map_id, start_x, start_y)
    local target = detail and detail.target or refresh_object(entry.target)
    local primary_plan = detail and detail.primary_plan or nil
    return {
        run_id = survey_state.run_id,
        map_id = map_id,
        target_id = target.id,
        target_type = target.type,
        target_name = target.name,
        start_x = start_x,
        start_y = start_y,
        target_x = target.x,
        target_y = target.y,
        path_mode = primary_plan and primary_plan.path_mode or nil,
        path_found = false,
        path_length = 0,
        movement_succeeded = false,
        final_x = start_x,
        final_y = start_y,
        failure_classification = "gated_or_isolated_region",
        suspected_blocked_tiles = {},
        blocked_tiles = {},
        blocked_event_count = 0,
        retry_succeeded = false,
        alternate_mode = detail and detail.alternate_mode or nil,
        alternate_path_found = detail and detail.alternate_path_found or false,
        reason = "stranded_start_unreachable",
        finished_on_same_map = true,
    }
end

local function skip_stranded_start_remainder(cluster)
    if not survey_state or not cluster then
        return 0
    end
    if (cluster.last_stranded_scan_target_count or 0) >= cluster.target_count then
        return 0
    end

    local first_index = (survey_state.queue_index or 0) + 1
    if first_index > #survey_state.queue then
        cluster.last_stranded_scan_target_count = cluster.target_count
        return 0
    end

    cluster.last_stranded_scan_target_count = cluster.target_count
    local start_info = get_cell_diagnostics(survey_state.map_id, cluster.start_x, cluster.start_y, {
        skip_npcs = true,
    })
    local pending_summary = summarize_remaining_reachability(survey_state.map_id, cluster.start_x, cluster.start_y, {
        first_index = first_index,
        skip_npcs = true,
    })
    if pending_summary.total == 0 then
        return 0
    end
    if pending_summary.reachable > 0 and start_info.reachable_area > CONTINUATION_TRAP_AREA_LIMIT then
        debug_tools.info(string.format(
            "SURVEY_STRANDED_SCAN_DEFER run=%d map=0x%02X start=(%d,%d) pending_targets=%d reachable_targets=%d unreachable_targets=%d reachable_area=%d open_exit_count=%d latest_target_id=%s reason=reachable_continuations_pending",
            survey_state.run_id,
            survey_state.map_id,
            cluster.start_x,
            cluster.start_y,
            pending_summary.total,
            pending_summary.reachable,
            pending_summary.unreachable,
            start_info.reachable_area,
            start_info.open_exit_count,
            tostring(survey_state.results[#survey_state.results] and survey_state.results[#survey_state.results].target_id or "")))
        return 0
    end

    local compacted_queue = {}
    for i = 1, survey_state.queue_index do
        compacted_queue[#compacted_queue + 1] = survey_state.queue[i]
    end

    local skipped = 0
    local still_reachable = 0
    for i = first_index, #survey_state.queue do
        local entry = survey_state.queue[i]
        if entry and entry.target then
            local should_skip, detail = should_skip_entry_from_stranded_start(
                entry,
                survey_state.map_id,
                cluster.start_x,
                cluster.start_y)
            if should_skip then
                local result = build_stranded_skip_result(
                    entry,
                    detail,
                    survey_state.map_id,
                    cluster.start_x,
                    cluster.start_y)
                survey_state.results[#survey_state.results + 1] = result
                survey_state.result_by_id[result.target_id] = result
                skipped = skipped + 1
                debug_tools.info(string.format(
                    "SURVEY_SKIP run=%d map=0x%02X start=(%d,%d) target_id=%s target_name=%q class=%s reason=%s",
                    survey_state.run_id,
                    survey_state.map_id,
                    cluster.start_x,
                    cluster.start_y,
                    tostring(result.target_id or ""),
                    tostring(result.target_name or ""),
                    tostring(result.failure_classification or ""),
                    tostring(result.reason or "")))
                log_result(result)
            else
                compacted_queue[#compacted_queue + 1] = entry
                still_reachable = still_reachable + 1
            end
        end
    end

    survey_state.queue = compacted_queue
    debug_tools.info(string.format(
        "SURVEY_STRANDED_SCAN run=%d map=0x%02X start=(%d,%d) pending_targets=%d reachable_targets=%d skipped_targets=%d reachable_area=%d open_exit_count=%d latest_target_id=%s reason=isolated_start_cluster",
        survey_state.run_id,
        survey_state.map_id,
        cluster.start_x,
        cluster.start_y,
        pending_summary.total,
        still_reachable,
        skipped,
        start_info.reachable_area,
        start_info.open_exit_count,
        tostring(survey_state.results[#survey_state.results] and survey_state.results[#survey_state.results].target_id or "")))
    if still_reachable == 0 then
        debug_tools.info(string.format(
            "SURVEY_STRANDED_END run=%d map=0x%02X start=(%d,%d) skipped_targets=%d reason=no_remaining_reachable_targets",
            survey_state.run_id,
            survey_state.map_id,
            cluster.start_x,
            cluster.start_y,
            skipped))
    end
    return skipped
end

local function finalize_attempt(attempt)
    if not survey_state or not attempt then
        return
    end
    if survey_state.active_attempt and survey_state.active_attempt ~= attempt then
        return
    end
    local map_id, final_x, final_y = nav.get_position()
    local failure_classification = classify_attempt(attempt, map_id, final_x, final_y)
    local no_path_cluster = observe_clean_no_path_cluster(attempt, map_id, final_x, final_y)
    if no_path_cluster and no_path_cluster.target_count >= ISOLATED_START_CLUSTER_MIN_TARGETS then
        failure_classification = "gated_or_isolated_region"
    end

    local retry_reason = get_retry_reason(attempt, failure_classification, map_id, final_x, final_y)
    if retry_reason then
        local target_id = attempt.target.id
        survey_state.retry_counts[target_id] = (survey_state.retry_counts[target_id] or 0) + 1
        survey_state.retry_reason_counts[target_id] = survey_state.retry_reason_counts[target_id] or {}
        survey_state.retry_reason_counts[target_id][retry_reason] =
            (survey_state.retry_reason_counts[target_id][retry_reason] or 0) + 1
        local retry_entry = {
            target = refresh_object(attempt.target),
            original_index = attempt.original_index,
            retry_number = survey_state.retry_counts[target_id],
        }
        survey_state.queue_index = survey_state.queue_index + 1
        if retry_should_run_next(retry_reason) then
            table.insert(survey_state.queue, survey_state.queue_index + 1, retry_entry)
        else
            survey_state.queue[#survey_state.queue + 1] = retry_entry
        end
        survey_state.active_attempt = nil
        debug_tools.info(string.format(
            "SURVEY_REQUEUE run=%d map=0x%02X target_id=%s reason=%s retry=%d",
            survey_state.run_id,
            attempt.map_id,
            tostring(target_id),
            retry_reason,
            survey_state.retry_counts[target_id]))
        invalidate_preview_caches()
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
    survey_state.queue_index = survey_state.queue_index + 1
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

    if not result.movement_succeeded and result.failure_classification == "command_timing_or_state_issue" then
        local map_candidates = blocked_candidates[result.map_id] or {}
        for _, key in ipairs(result.suspected_blocked_tiles) do
            local entry = map_candidates[key]
            if entry then
                entry.state_issue_count = (entry.state_issue_count or 0) + 1
                entry.confidence = compute_candidate_confidence(entry)
            end
        end
    end

    log_result(result)
    if no_path_cluster and no_path_cluster.target_count >= ISOLATED_START_CLUSTER_MIN_TARGETS then
        skip_stranded_start_remainder(no_path_cluster)
    end
    -- Full flush between attempts: the player (and any un-parked NPCs) may
    -- have moved, and cached previews/diagnostics are keyed on start position
    -- and blocking signature. Keeping them would also grow unbounded over a
    -- long run. on_route_blocked + start_attempt handle within-attempt drift.
    invalidate_preview_caches()
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
            state_issue_count = 0,
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

local function abort_active_attempt_for_route_churn(attempt)
    if not survey_state or not attempt or attempt.route_churn_capped then
        return false
    end
    attempt.route_churn_capped = true
    attempt.success = false
    attempt.reason = "route_churn_cap"
    survey_state.stop_after_attempt = true
    survey_state.stop_reason = "route_churn_cap"
    local _, final_x, final_y = nav.get_position()
    debug_tools.info(string.format(
        "SURVEY_ROUTE_CHURN_ABORT run=%d map=0x%02X target_id=%s blocked_events=%d suspected_tiles=%d limit=%d final=(%d,%d) reason=route_churn_cap",
        survey_state.run_id or 0,
        survey_state.map_id or 0,
        tostring(attempt.target and attempt.target.id or "-"),
        #attempt.blocked_tiles,
        #attempt.suspected_tiles,
        SURVEY_ROUTE_CHURN_BLOCK_EVENT_LIMIT,
        final_x or -1,
        final_y or -1))
    auto_step.cancel_active_step(true)
    if route_mgr.clear_active_route_context then
        route_mgr.clear_active_route_context("survey route churn cap")
    end
    finalize_attempt(attempt)
    finish_run(false)
    tolk.output_interrupt("Survey stopped. Route churn cap reached.")
    return true
end

local function on_route_blocked(data)
    if not survey_state or not survey_state.active_attempt or not data then
        return
    end
    local input_opts = nil
    if data.timing_suspect == true then
        input_opts = {
            allow_route_blocked_self_input = true,
            route_blocked_timing_suspect = true,
            route_blocked_dir = data.dir,
            route_blocked_source = data.source,
        }
    end
    if abort_survey_if_input_contaminated("route_blocked", "survey_objects", input_opts) then
        return
    end
    if data.timing_suspect == true then
        debug_tools.info(string.format(
            "SURVEY_TIMING_BLOCK_IGNORED run=%d map=0x%02X from=(%d,%d) dir=%s reason=timing_suspect_route_timeout",
            survey_state.run_id or 0,
            survey_state.map_id or 0,
            data.from_x or -1,
            data.from_y or -1,
            tostring(data.dir or "-")))
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
    if #attempt.blocked_tiles > SURVEY_ROUTE_CHURN_BLOCK_EVENT_LIMIT then
        abort_active_attempt_for_route_churn(attempt)
        return
    end
    invalidate_preview_caches()
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
    if abort_survey_if_input_contaminated("route_cancelled", "survey_objects") then
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

local function pause_for_battle()
    if not survey_state then
        return
    end
    if survey_state.paused_reason == "battle_started" then
        return
    end

    local attempt = survey_state.active_attempt
    if attempt then
        auto_step.cancel_active_step(true)
        if route_mgr.clear_active_route_context then
            route_mgr.clear_active_route_context("survey battle pause")
        end
        survey_state.active_attempt = nil
    end

    survey_state.paused_reason = "battle_started"
    survey_state.paused_target_id = attempt and attempt.target and attempt.target.id or nil
    debug_tools.info(string.format(
        "SURVEY_PAUSE run=%d map=0x%02X reason=battle_started target_id=%s queue_index=%d",
        survey_state.run_id,
        survey_state.map_id,
        tostring(survey_state.paused_target_id or "-"),
        survey_state.queue_index or 0))
    tolk.output_interrupt("Survey paused for battle. It will resume when safe.")
end

local function resume_from_pause_if_ready(can_walk)
    if not survey_state or not survey_state.paused_reason then
        return true
    end
    if not can_walk then
        return false
    end

    local map_id = nav.get_position()
    if map_id ~= survey_state.map_id then
        survey_state.stop_after_attempt = true
        survey_state.stop_reason = "map_changed"
        debug_tools.info(string.format(
            "SURVEY_ABORT run=%d map=0x%02X reason=map_changed_while_paused current_map=0x%02X pause_reason=%s",
            survey_state.run_id,
            survey_state.map_id,
            map_id or -1,
            tostring(survey_state.paused_reason)))
        finish_run(false)
        return false
    end

    debug_tools.info(string.format(
        "SURVEY_RESUME run=%d map=0x%02X reason=%s target_id=%s queue_index=%d",
        survey_state.run_id,
        survey_state.map_id,
        tostring(survey_state.paused_reason),
        tostring(survey_state.paused_target_id or "-"),
        survey_state.queue_index or 0))
    tolk.output_interrupt("Survey resumed.")
    survey_state.paused_reason = nil
    survey_state.paused_target_id = nil
    return true
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
event_bus.subscribe("battle_started", pause_for_battle)
event_bus.subscribe("map_changed", on_map_changed)

local function start_attempt(queue_entry)
    local target = queue_entry and queue_entry.target
    if not target then
        return
    end
    if abort_survey_if_input_contaminated("start_attempt", "survey_objects") then
        return
    end
    update_survey_npc_parking_for_target(target)
    objects.update_npcs()  -- sync cache: reflects new exempt slot + parked positions
    local map_id, start_x, start_y = nav.get_position()
    local stale_runtime_blocks = route_mgr.count_runtime_blocks(map_id) or 0
    if stale_runtime_blocks > 0 then
        route_mgr.clear_runtime_blocks(map_id)
        invalidate_preview_caches()
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
        prequeue_hook = function(candidate_plan)
            local defer, info = should_defer_continuation_trap(
                queue_entry,
                map_id,
                start_x,
                start_y,
                candidate_plan)
            if not defer then
                return true
            end
            return false, {
                status = "deferred_continuation_trap",
                continuation_trap = info,
                message = string.format(
                    "Deferred %s because landing (%d,%d) reaches %d walkable tiles and only %d of %d remaining targets stay reachable",
                    tostring(target.name),
                    info.landing_x,
                    info.landing_y,
                    info.reachable_area,
                    info.reachable_remaining or 0,
                    info.remaining_targets),
            }
        end,
    })
    local attempt = {
        target = copy_object(target),
        map_id = map_id,
        start_x = start_x,
        start_y = start_y,
        original_index = queue_entry.original_index,
        retry_number = queue_entry.retry_number or 0,
        path_mode = plan and plan.path_mode or nil,
        path_found = plan and plan.result ~= "No path found" or false,
        path_length = plan and (plan.path and #plan.path or 0) or 0,
        adjacent_diagnostics = plan and plan.adjacent_diagnostics or nil,
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
            "SURVEY_ATTEMPT run=%d map=0x%02X idx=%d/%d retry=%d target_id=%s target_type=%s target_name=%q start=(%d,%d) target=(%d,%d) mode=%s path_length=%d",
            survey_state.run_id,
            survey_state.map_id,
            attempt.original_index or (survey_state.queue_index + 1),
            survey_state.target_total,
            attempt.retry_number,
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

    if plan and plan.status == "deferred_continuation_trap" then
        local trap = plan.continuation_trap or {}
        survey_state.defer_landings[target.id] = survey_state.defer_landings[target.id] or {}
        if trap.landing_key then
            survey_state.defer_landings[target.id][trap.landing_key] =
                (survey_state.defer_landings[target.id][trap.landing_key] or 0) + 1
        end
        survey_state.defer_counts[target.id] = (survey_state.defer_counts[target.id] or 0) + 1
        survey_state.queue[#survey_state.queue + 1] = {
            target = refresh_object(target),
            original_index = queue_entry.original_index,
            retry_number = queue_entry.retry_number or 0,
        }
        survey_state.queue_index = survey_state.queue_index + 1
        debug_tools.info(string.format(
            "SURVEY_DEFER run=%d map=0x%02X idx=%d/%d defer=%d target_id=%s reason=continuation_trap trap_reason=%s landing=(%d,%d) reachable_area=%d remaining_targets=%d reachable_remaining=%d unreachable_remaining=%d",
            survey_state.run_id,
            survey_state.map_id,
            attempt.original_index or (survey_state.queue_index + 1),
            survey_state.target_total,
            survey_state.defer_counts[target.id],
            tostring(target.id),
            tostring(trap.trap_reason or ""),
            trap.landing_x or start_x,
            trap.landing_y or start_y,
            trap.reachable_area or 0,
            trap.remaining_targets or 0,
            trap.reachable_remaining or 0,
            trap.unreachable_remaining or 0))
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
    local map_id, start_x, start_y = nav.get_position()
    if not targets or #targets == 0 then
        return false, no_targets_message(opts and opts.mode, map_id)
    end
    local refusal, details = input_contamination_refusal("survey_objects")
    if refusal then
        run_counter = run_counter + 1
        debug_tools.error(refusal)
        debug_tools.info(string.format(
            "SURVEY_START_ABORT run=%d map=0x%02X reason=input_contaminated start=(%d,%d) targets=%d %s",
            run_counter,
            map_id,
            start_x,
            start_y,
            #targets,
            tostring(details or "")))
        tolk.output_interrupt("Survey aborted. Input contaminated.")
        return false, refusal
    end
    local start_info = analyze_survey_start(targets, map_id, start_x, start_y)
    run_counter = run_counter + 1
    if start_info.isolated_start then
        debug_tools.info(string.format(
            "SURVEY_START_ABORT run=%d map=0x%02X reason=isolated_start start=(%d,%d) targets=%d reachable_area=%d open_exit_count=%d open_exits=%s blocked_exits=%s isolation_reason=%s reachable_targets=%s unreachable_targets=%s",
            run_counter,
            start_info.map_id,
            start_info.start_x,
            start_info.start_y,
            start_info.target_count,
            start_info.reachable_area,
            start_info.open_exit_count,
            start_info.open_exits_text,
            start_info.blocked_exits_text,
            tostring(start_info.isolation_reason or "unknown"),
            tostring(start_info.reachable_targets or "-"),
            tostring(start_info.unreachable_targets or "-")))
        if start_info.isolation_reason == "low_target_coverage" then
            tolk.output_interrupt(string.format(
                "Survey aborted on map %02X. Start (%d,%d) is stranded: only %d of %d targets are reachable.",
                start_info.map_id,
                start_info.start_x,
                start_info.start_y,
                start_info.reachable_targets or 0,
                start_info.target_count))
            return false, string.format(
                "Survey start (%d,%d) is stranded: only %d of %d targets are reachable",
                start_info.start_x,
                start_info.start_y,
                start_info.reachable_targets or 0,
                start_info.target_count)
        else
            tolk.output_interrupt(string.format(
                "Survey aborted on map %02X. Start (%d,%d) is isolated: reachable area %d with %d open exits.",
                start_info.map_id,
                start_info.start_x,
                start_info.start_y,
                start_info.reachable_area,
                start_info.open_exit_count))
            return false, string.format(
                "Survey start (%d,%d) is isolated: reachable area %d with %d open exits",
                start_info.start_x,
                start_info.start_y,
                start_info.reachable_area,
                start_info.open_exit_count)
        end
    end
    if start_info.open_exit_count <= 2 then
        debug_tools.info(string.format(
            "SURVEY_START_ABORT run=%d map=0x%02X reason=low_exit_count start=(%d,%d) targets=%d open_exit_count=%d open_exits=%s blocked_exits=%s",
            run_counter,
            start_info.map_id,
            start_info.start_x,
            start_info.start_y,
            start_info.target_count,
            start_info.open_exit_count,
            start_info.open_exits_text,
            start_info.blocked_exits_text))
        tolk.output_interrupt(string.format(
            "Survey aborted: start (%d,%d) has only %d open exits. Move to a more open position and try again.",
            start_info.start_x,
            start_info.start_y,
            start_info.open_exit_count))
        return false, string.format(
            "Survey start (%d,%d) has only %d open exits; move to a more open position",
            start_info.start_x,
            start_info.start_y,
            start_info.open_exit_count)
    end
    survey_state = {
        run_id = run_counter,
        map_id = map_id,
        start_x = start_x,
        start_y = start_y,
        targets = copy_target_list(targets),
        target_total = #targets,
        queue = {},
        queue_index = 0,
        options = opts or {},
        results = {},
        result_by_id = {},
        retry_counts = {},
        retry_reason_counts = {},
        defer_counts = {},
        defer_landings = {},
        no_path_clusters = {},
        preview_cache = {},
        cell_diagnostics_cache = {},
        blocking_cache = {},
        active_attempt = nil,
        stop_after_attempt = false,
        stop_reason = nil,
        paused_reason = nil,
        paused_target_id = nil,
        npc_parking = nil,
    }
    for i, target in ipairs(survey_state.targets) do
        survey_state.queue[i] = {
            target = copy_object(target),
            original_index = i,
            retry_number = 0,
        }
    end
    if survey_state.options.park_npcs then
        survey_state.npc_parking = capture_npc_parking_state()
        debug_tools.info(string.format(
            "SURVEY_NPC_PARK_START run=%d map=0x%02X parked_slots=%d exempt_slot=-",
            survey_state.run_id,
            survey_state.map_id,
            apply_survey_npc_parking()))
        objects.update_npcs()  -- sync cache: parked NPCs at inactive (0,0) filtered out
    end
    debug_tools.info(string.format(
        "SURVEY_START run=%d map=0x%02X start=(%d,%d) targets=%d mode=%s npc_mode=%s runtime_blocks=%d",
        survey_state.run_id,
        survey_state.map_id,
        survey_state.start_x,
        survey_state.start_y,
        survey_state.target_total,
        tostring((opts and opts.mode) or "objects"),
        get_survey_npc_mode(opts),
        route_mgr.count_runtime_blocks(map_id)))
    debug_tools.info(string.format(
        "SURVEY_START_CONTEXT run=%d map=0x%02X start=(%d,%d) open_exit_count=%d open_exits=%s blocked_exits=%s",
        survey_state.run_id,
        survey_state.map_id,
        survey_state.start_x,
        survey_state.start_y,
        start_info.open_exit_count,
        start_info.open_exits_text,
        start_info.blocked_exits_text))
    tolk.output_interrupt(string.format(
        "Survey started on map %02X. %d target%s queued.%s",
        map_id,
        survey_state.target_total,
        (survey_state.target_total == 1) and "" or "s",
        survey_state.options.park_npcs and " Park NPC mode active." or ""))
    return true, nil
end

local function get_object_survey_targets(arg, map_id)
    local parsed, err = parse_survey_tokens(arg, {allow_retry_failed = true})
    if not parsed then
        return nil, nil, nil, err
    end
    if parsed.retry_failed then
        return get_failed_targets_for_map(map_id), "retry_failed", parsed
    end
    return get_default_survey_targets(), "objects", parsed
end

function M.start_object_survey(arg)
    local map_id = nav.get_position()
    local targets, mode, parsed, err = get_object_survey_targets(arg, map_id)
    if not targets then
        return false, err
    end
    return start_run(targets, {
        mode = mode,
        park_npcs = parsed and parsed.park_npcs or false,
    })
end

function M.report_start_viability(arg)
    local map_id, start_x, start_y = nav.get_position()
    local targets, mode, parsed, err = get_object_survey_targets(arg, map_id)
    if not targets then
        debug_tools.info(string.format(
            "SURVEY_START_STATUS map=0x%02X mode=%s start=(%d,%d) targets=0 status=invalid_args npc_mode=%s",
            map_id,
            tostring(mode or "objects"),
            start_x,
            start_y,
            get_survey_npc_mode(parsed)))
        return false, err
    end
    if not targets or #targets == 0 then
        debug_tools.info(string.format(
            "SURVEY_START_STATUS map=0x%02X mode=%s start=(%d,%d) targets=0 status=no_targets npc_mode=%s",
            map_id,
            tostring(mode),
            start_x,
            start_y,
            get_survey_npc_mode(parsed)))
        return false, no_targets_message(mode, map_id)
    end

    local start_info = analyze_survey_start(targets, map_id, start_x, start_y)
    start_info.mode = mode
    debug_tools.info(string.format(
        "SURVEY_START_STATUS map=0x%02X mode=%s start=(%d,%d) targets=%d reachable_area=%d open_exit_count=%d open_exits=%s blocked_exits=%s status=%s hard_area_limit=%d area_limit=%d open_exit_limit=%d reachable_targets=%s unreachable_targets=%s isolation_reason=%s coverage_min_targets=%d coverage_reachable_limit=%d npc_mode=%s",
        map_id,
        tostring(mode),
        start_x,
        start_y,
        start_info.target_count,
        start_info.reachable_area,
        start_info.open_exit_count,
        start_info.open_exits_text,
        start_info.blocked_exits_text,
        start_info.isolated_start and "isolated_start" or "viable",
        start_info.hard_area_limit,
        start_info.area_limit,
        start_info.open_exit_limit,
        tostring(start_info.reachable_targets or "-"),
        tostring(start_info.unreachable_targets or "-"),
        tostring(start_info.isolation_reason or "-"),
        start_info.coverage_min_targets,
        start_info.coverage_reachable_limit,
        get_survey_npc_mode(parsed)))
    return true, start_info
end

function M.start_target_survey(arg)
    local parsed, err = parse_survey_tokens(arg, {allow_target_token = true})
    if not parsed then
        return false, err
    end
    local target, target_err = resolve_target_by_token(parsed.target_token)
    if not target then
        return false, target_err or "Target not found"
    end
    return start_run({copy_object(target)}, {
        mode = "target",
        park_npcs = parsed.park_npcs,
    })
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
        if route_mgr.clear_active_route_context then
            route_mgr.clear_active_route_context("survey manual stop")
        end
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

    if abort_survey_if_input_contaminated("tick", "survey_objects") then
        return
    end

    local cur_hp = memory.readbyte(addr.CURRENT_HP)
    if cur_hp <= SURVEY_LOW_HP_ABORT_THRESHOLD then
        if survey_state.active_attempt then
            auto_step.cancel_active_step(true)
        end
        debug_tools.info(string.format(
            "SURVEY_ABORT run=%d map=0x%02X reason=low_hp hp=%d threshold=%d",
            survey_state.run_id, survey_state.map_id, cur_hp, SURVEY_LOW_HP_ABORT_THRESHOLD))
        tolk.output_interrupt(string.format(
            "Survey aborted: HP critical (%d). Heal and retry.", cur_hp))
        survey_state.stop_reason = "low_hp"
        finish_run(false)
        return
    end

    if not resume_from_pause_if_ready(can_walk) then
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
            if route_mgr.clear_active_route_context then
                route_mgr.clear_active_route_context("survey orphaned route")
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

    if survey_state.queue_index >= #survey_state.queue then
        finish_run(true)
        return
    end

    if not can_walk then
        return
    end

    maybe_reprioritize_queue()
    start_attempt(survey_state.queue[survey_state.queue_index + 1])
end

function M.apply_npc_parking()
    apply_survey_npc_parking()
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

function M.report_failure_starts(map_id)
    map_id = map_id or nav.get_position()
    local run = last_runs[map_id]
    if not run then
        debug_tools.info(string.format("SURVEY_FAILURE_STARTS map=0x%02X none", map_id))
        return 0
    end
    return log_failure_start_entries(map_id, sorted_failure_start_entries(run))
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
            "SURVEY_CANDIDATE map=0x%02X x=%d y=%d key=%s count=%d targets=%d retry_successes=%d failure_count=%d state_issues=%d confidence=%s approaches=%s",
            map_id,
            entry.x,
            entry.y,
            entry.key,
            entry.count,
            entry.target_count,
            entry.retry_successes,
            entry.failure_count,
            entry.state_issue_count or 0,
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
            "SURVEY_STRONG_CANDIDATE map=0x%02X x=%d y=%d key=%s count=%d targets=%d retry_successes=%d state_issues=%d approaches=%s confidence=%s",
            map_id,
            entry.x,
            entry.y,
            entry.key,
            entry.count,
            entry.target_count,
            entry.retry_successes,
            entry.state_issue_count or 0,
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
        "SURVEY_REPORT map=0x%02X run=%d total=%d successes=%d failures=%d no_route=%d gated_or_isolated=%d movement_failed=%d suspected_engine_blocked=%d state_issues=%d adjacency_issues=%d",
        map_id,
        run.run_id,
        summary.total,
        summary.successes,
        summary.failures,
        summary.no_route_found,
        summary.gated_or_isolated_region,
        summary.route_found_but_movement_failed,
        summary.suspected_engine_blocked_tile,
        summary.command_timing_or_state_issue,
        summary.wrong_adjacency_or_interaction_assumption))
    for _, result in ipairs(run.results) do
        log_result(result)
    end
    M.report_failure_starts(map_id)
    return summary.total
end

function M.report_findings(map_id)
    map_id = map_id or nav.get_position()
    local run = last_runs[map_id]
    local failed = M.report_failed_targets(map_id)
    local failure_starts = M.report_failure_starts(map_id)
    local strong = M.report_strong_candidates(map_id)
    if not run then
        debug_tools.info(string.format("SURVEY_FINDINGS map=0x%02X none", map_id))
        return {failed_targets = 0, failure_starts = 0, strong_candidates = 0}
    end
    debug_tools.info(string.format(
        "SURVEY_FINDINGS map=0x%02X run=%d failed_targets=%d failure_starts=%d strong_reroute_candidates=%d",
        map_id,
        run.run_id,
        failed,
        failure_starts,
        strong))
    return {
        failed_targets = failed,
        failure_starts = failure_starts,
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
            "SURVEY_CANDIDATE_SUGGESTION map=0x%02X x=%d y=%d key=%s kind=%s approaches=%s confidence=%s count=%d retry_successes=%d state_issues=%d targets=%d",
            map_id,
            suggestion.x,
            suggestion.y,
            suggestion.key,
            suggestion.kind,
            table.concat(suggestion.approaches, "|"),
            tostring(suggestion.confidence),
            suggestion.count,
            suggestion.retry_successes,
            suggestion.state_issue_count or 0,
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
    local suggestions = candidate_suggestions(map_id)
    local exportable_keys = {}
    for _, suggestion in ipairs(suggestions) do
        exportable_keys[suggestion.key] = true
    end

    local skipped = #entries - #suggestions
    debug_tools.info(string.format(
        "SURVEY_CANDIDATE_EXPORT map=0x%02X count=%d skipped_diagnostics=%d",
        map_id, #suggestions, skipped))
    for _, entry in ipairs(entries) do
        if not exportable_keys[entry.key] then
            debug_tools.info(string.format(
                "SURVEY_CANDIDATE_EXPORT_SKIP map=0x%02X key=%s confidence=%s count=%d retry_successes=%d state_issues=%d reason=not_exportable_needs_repro",
                map_id,
                entry.key,
                tostring(entry.confidence),
                entry.count,
                entry.retry_successes,
                entry.state_issue_count or 0))
        end
    end
    if #suggestions == 0 then
        return 0
    end
    debug_tools.info(string.format("    [0x%02X] = {", map_id))
    for _, suggestion in ipairs(suggestions) do
        if suggestion.kind == "full_block" then
            debug_tools.info(string.format(
                '        ["%s"] = {north=true, south=true, east=true, west=true},  -- confidence=%s count=%d retry_successes=%d state_issues=%d',
                suggestion.key,
                suggestion.confidence,
                suggestion.count,
                suggestion.retry_successes,
                suggestion.state_issue_count or 0))
        else
            local dir_parts = {}
            for _, approach in ipairs(suggestion.approaches) do
                dir_parts[#dir_parts + 1] = approach .. "=true"
            end
            debug_tools.info(string.format(
                '        ["%s"] = {%s},  -- confidence=%s count=%d retry_successes=%d state_issues=%d',
                suggestion.key,
                table.concat(dir_parts, ", "),
                suggestion.confidence,
                suggestion.count,
                suggestion.retry_successes,
                suggestion.state_issue_count or 0))
        end
    end
    debug_tools.info("    },")
    return #suggestions
end

return M
