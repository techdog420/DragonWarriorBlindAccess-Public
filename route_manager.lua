-- route_manager.lua
-- Pathfinding coordination, NPC freeze, and runtime block tracking.
--
-- Owns the lifecycle of a pathfinding/auto-walk session:
--   1. Plan a path to an object (plan_path_to_object)
--   2. Optionally queue auto-walk steps (autowalk_to_current)
--   3. Handle rerouting when a step is blocked (on_blocked callback)
--   4. Release NPC freeze when the route completes (on_route_complete)
--   5. Clear state on map change (on_map_change)
--
-- Also manages the NPC position freeze, which locks NPC bytes in RAM
-- so the pathfinder sees stable positions during multi-step routes.
--
-- Extracted from main.lua to reduce coupling. The main loop calls:
--   route_manager.apply_npc_freeze()  -- after FCEU.frameadvance()
--   route_manager.on_map_change()     -- when map changes
-- Hotkeys/commands call:
--   route_manager.pathfind_to_current()
--   route_manager.autowalk_to_current()
--   route_manager.toggle_npc_freeze()

local addr       = require "addresses"
local maps       = require "maps"
local nav        = require "navigation"
local objects    = require "objects"
local pathfinder = require "pathfinder"
local map_reader = require "map_reader"
local auto_step  = require "auto_step"
local tolk       = require "tolk"
local debug_tools = require "debug_tools"
local path_debug = require "path_debug"
local snapshot   = require "game_snapshot"
local event_bus  = require "event_bus"
local config     = require "config"
local overworld_routes = require "overworld_routes"
local emulator_compat = rawget(_G, "DW_EMULATOR_COMPAT") or {}

local M = {}

local function trace_autowalk_boundary(label, detail)
    if not debug_tools.DEBUG_MODE then
        return
    end
    local message = "AUTO_WALK_TRACE " .. tostring(label)
    if detail and detail ~= "" then
        message = message .. " " .. tostring(detail)
    end
    debug_tools.info(message)
    if debug_tools.flush then
        debug_tools.flush()
    end
end

-- ============================================================
-- Direction Constants
-- ============================================================
-- Maps FCEUX joypad direction keys to movement deltas and facing names.

local DIR_TO_DELTA = {
    up    = {dx = 0, dy = -1, face = "north"},
    down  = {dx = 0, dy =  1, face = "south"},
    left  = {dx = -1, dy = 0, face = "west"},
    right = {dx =  1, dy = 0, face = "east"},
}

-- Reverse map: cardinal name → FCEUX joypad key.
local DIR_NAME_TO_KEY = {
    north = "up",
    south = "down",
    west  = "left",
    east  = "right",
}

local PATH_DIRECTIONS = {
    {dx =  0, dy = -1, name = "north", approach = "south"},
    {dx =  0, dy =  1, name = "south", approach = "north"},
    {dx = -1, dy =  0, name = "west",  approach = "east"},
    {dx =  1, dy =  0, name = "east",  approach = "west"},
}

-- ============================================================
-- State
-- ============================================================

-- Last object the player pathfound to. Kept so on_blocked can re-route
-- to the same target when a moving NPC blocks a step.
local last_pathfind_obj = nil

-- Consecutive on_blocked calls without a successful step.
-- After REROUTE_FAILURE_LIMIT, pathfinding is cancelled.
local reroute_failures = 0
local route_drift_reroutes = 0
local REROUTE_FAILURE_LIMIT = 3
local ROUTE_DRIFT_REROUTE_LIMIT = 6
M.OVERWORLD_RECOVERY_AUTO_WALK_MAX_STEPS = 24

-- NPC freeze: lock NPC positions in RAM for reliable pathfinding.
-- When active, apply_npc_freeze() restores NPC bytes to their snapshot
-- values after every FCEU.frameadvance(), undoing any AI movement.
local npc_freeze_active = false
local frozen_npc_snapshot = {}  -- Array [0..19] of {b0, b1, b2}
local autowalk_npc_parking = nil

-- Runtime engine-blocked cells injected by explicit manual commands.
-- Route-timeout observations live in seam_memory as diagnostics only. Reroutes
-- may temporarily block the single edge that just failed, but old seam-memory
-- noise must not become pathfinding truth until a human promotes it.
local runtime_blocked = {}
local seam_memory = {}
local seam_retry_state = nil
local active_route_temp_blocks = nil
local autowalk_guard = nil
local active_route_settle_frames = 0
local active_route_settle_same_direction = true
local active_route_target = nil
local active_route_face_dir = nil
local active_route_completion_actions = true
local active_route_speak_completion = true
local active_route_total_steps = 0
local active_route_completed_steps = 0
local active_route_allow_hazards = false
local active_route_hazard_stop = nil
local active_route_stop_on_blocker = false
local active_route_npc_mode = "live_npcs"
local active_route_parked_slots = nil
local active_overworld_segment = nil
M._overworld_hazard_confirmation = {
    current = nil,
    pending_seconds = 10,
    active_idle_seconds = 20,
}
M.BATTLE_ONSET_DIAGNOSTIC_GRACE_FRAMES = 3
M._pending_overworld_timeout_observation = nil
local target_npc_hold = nil
local target_face_input = nil
local object_pathability_signature = nil
local last_pathability_result = nil
local SURVEY_ROUTE_SETTLE_FRAMES = 30
local TARGET_FACE_RELEASE_FRAMES = 2

local function count_active_route_temp_blocks(map_id)
    if not active_route_temp_blocks then
        return 0
    end
    local count = 0
    local function count_map_blocks(map_blocks)
        for _, dirs in pairs(map_blocks or {}) do
            if type(dirs) == "table" then
                for _, enabled in pairs(dirs) do
                    if enabled then
                        count = count + 1
                    end
                end
            end
        end
    end
    if map_id ~= nil then
        count_map_blocks(active_route_temp_blocks[map_id])
    else
        for _, map_blocks in pairs(active_route_temp_blocks) do
            count_map_blocks(map_blocks)
        end
    end
    return count
end
local SEAM_BRUTE_FORCE_RETRY_LIMIT = 2
local NPC_PARK_DEFERRED_RETRY_FRAMES = 30
local APPROACH_ORDER = {north = 1, south = 2, west = 3, east = 4}
local TANTEGEL_CASTLE_MAP_ID = 0x04
local TANTEGEL_SHRINE_EXIT_X = 29
local TANTEGEL_SHRINE_EXIT_Y = 29
local TANTEGEL_SHRINE_RISKY_X29_ENTRY_MAX_Y = 7
local TANTEGEL_SHRINE_RISKY_X29_SUFFIX_MIN = 20
local apply_autowalk_npc_parking_state

local function cell_key(x, y)
    return x .. "," .. y
end

function M._overworld_hazard_confirmation.clear(reason)
    if not M._overworld_hazard_confirmation.current then
        return false
    end
    local confirmation = M._overworld_hazard_confirmation.current
    M._overworld_hazard_confirmation.current = nil
    debug_tools.info(string.format(
        "AUTO_WALK_HAZARD_CONFIRM_CLEARED state=%s map=0x%02X position=(%s,%s) hazard=%s reason=%s",
        tostring(confirmation.state or "-"),
        confirmation.map_id or -1,
        tostring(confirmation.current_x),
        tostring(confirmation.current_y),
        tostring(confirmation.hazard or "-"),
        tostring(reason or "unspecified")))
    return true
end

function M._overworld_hazard_confirmation.destination_id()
    local destination = overworld_routes.active_destination()
    return destination and destination.id or nil
end

function M._overworld_hazard_confirmation.arm(cancel_data, segment)
    if not cancel_data
       or cancel_data.reason ~= "dangerous_tile"
       or cancel_data.hazard ~= "poison_swamp"
       or not segment then
        return false
    end
    M._overworld_hazard_confirmation.clear("replaced by new warning")
    M._overworld_hazard_confirmation.current = {
        state = "pending",
        map_id = select(1, nav.get_position()),
        current_x = cancel_data.current_x,
        current_y = cancel_data.current_y,
        dir = cancel_data.dir,
        dest_x = cancel_data.dest_x,
        dest_y = cancel_data.dest_y,
        hazard = cancel_data.hazard,
        route_id = segment.route_id,
        destination_id = M._overworld_hazard_confirmation.destination_id(),
        clock = os.clock(),
        entered = false,
    }
    debug_tools.info(string.format(
        "AUTO_WALK_HAZARD_CONFIRM_ARMED map=0x%02X from=(%s,%s) dir=%s dest=(%s,%s) hazard=%s route=%s destination=%s expires=%ds",
        M._overworld_hazard_confirmation.current.map_id or -1,
        tostring(M._overworld_hazard_confirmation.current.current_x),
        tostring(M._overworld_hazard_confirmation.current.current_y),
        tostring(M._overworld_hazard_confirmation.current.dir),
        tostring(M._overworld_hazard_confirmation.current.dest_x),
        tostring(M._overworld_hazard_confirmation.current.dest_y),
        tostring(M._overworld_hazard_confirmation.current.hazard),
        tostring(M._overworld_hazard_confirmation.current.route_id or "-"),
        tostring(M._overworld_hazard_confirmation.current.destination_id or "-"),
        M._overworld_hazard_confirmation.pending_seconds))
    return true
end

function M._overworld_hazard_confirmation.allowed_for_segment(segment, map_id, px, py)
    local confirmation = M._overworld_hazard_confirmation.current
    if not confirmation then
        return nil, false
    end
    local now = os.clock()
    local destination_id = M._overworld_hazard_confirmation.destination_id()
    if confirmation.map_id ~= map_id
       or confirmation.destination_id ~= destination_id then
        M._overworld_hazard_confirmation.clear("route context changed")
        return nil, false
    end

    if confirmation.state == "pending" then
        local delta = segment and segment.steps
            and DIR_TO_DELTA[segment.steps[1]] or nil
        local first_x = delta and (px + delta.dx) or nil
        local first_y = delta and (py + delta.dy) or nil
        local route_id = segment and segment.route and segment.route.id or nil
        if now - confirmation.clock > M._overworld_hazard_confirmation.pending_seconds then
            M._overworld_hazard_confirmation.clear("confirmation expired")
            return nil, false
        end
        if confirmation.current_x ~= px
           or confirmation.current_y ~= py
           or confirmation.dir ~= (segment.steps and segment.steps[1])
           or confirmation.dest_x ~= first_x
           or confirmation.dest_y ~= first_y
           or confirmation.route_id ~= route_id
           or map_reader.is_hazard_cell(map_id, first_x, first_y) ~= "poison_swamp" then
            M._overworld_hazard_confirmation.clear("warning context no longer matches")
            return nil, false
        end
        confirmation.state = "active"
        confirmation.clock = now
        debug_tools.info(string.format(
            "AUTO_WALK_HAZARD_CONFIRM_ACCEPTED map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d) hazard=%s route=%s destination=%s",
            map_id or -1,
            px or -1,
            py or -1,
            tostring(confirmation.dir),
            confirmation.dest_x or -1,
            confirmation.dest_y or -1,
            tostring(confirmation.hazard),
            tostring(route_id or "-"),
            tostring(destination_id or "-")))
        return confirmation.hazard, true
    end

    if confirmation.state ~= "active"
       or now - confirmation.clock > M._overworld_hazard_confirmation.active_idle_seconds then
        M._overworld_hazard_confirmation.clear("active confirmation expired")
        return nil, false
    end
    local current_hazard = map_reader.is_hazard_cell(map_id, px, py)
    if current_hazard == confirmation.hazard then
        confirmation.entered = true
        confirmation.current_x = px
        confirmation.current_y = py
        confirmation.clock = now
        return confirmation.hazard, false
    end
    if confirmation.entered then
        M._overworld_hazard_confirmation.clear("safe terrain reached")
        return nil, false
    end
    return confirmation.hazard, false
end

function M._overworld_hazard_confirmation.after_step(map_id, to_x, to_y)
    local confirmation = M._overworld_hazard_confirmation.current
    if not confirmation or confirmation.state ~= "active" then
        return
    end
    if confirmation.map_id ~= map_id
       or confirmation.destination_id ~= M._overworld_hazard_confirmation.destination_id() then
        M._overworld_hazard_confirmation.clear("route context changed after step")
        return
    end
    local hazard = map_reader.is_hazard_cell(map_id, to_x, to_y)
    if hazard == confirmation.hazard then
        confirmation.entered = true
        confirmation.current_x = to_x
        confirmation.current_y = to_y
        confirmation.clock = os.clock()
    elseif confirmation.entered then
        M._overworld_hazard_confirmation.clear("safe terrain reached")
    end
end

-- Hot-reload the static pathing sources from disk without resetting
-- runtime route state. This is used in live debugging when map_reader
-- changes after the current session started (for example manual script
-- edits in a long-running FCEUX run).
local function refresh_navigation_modules()
    package.loaded["overworld_routes"] = nil
    package.loaded["map_reader"] = nil
    package.loaded["pathfinder"] = nil
    objects = require "objects"
    overworld_routes = require "overworld_routes"
    map_reader = require "map_reader"
    pathfinder = require "pathfinder"
end

-- Explicit manual/diagnostic hook for main.lua.
function M.refresh_navigation_modules()
    refresh_navigation_modules()
end

local function copy_direction_table(dirs)
    local copy = {}
    for d, v in pairs(dirs or {}) do
        copy[d] = v
    end
    return copy
end

local function copy_blocking_table(blocking)
    local copy = {}
    for k, value in pairs(blocking or {}) do
        if type(value) == "table" then
            copy[k] = copy_direction_table(value)
        else
            copy[k] = value
        end
    end
    return copy
end

local function log_route_plan_timing(plan, elapsed_ms)
    if not plan or elapsed_ms < 25 then
        return
    end
    local target = plan.target or {}
    debug_tools.info(string.format(
        "ROUTE_PLAN_TIMING map=0x%02X start=(%d,%d) target_id=%s target_name=%s mode=%s npc_mode=%s result=%s path_len=%d ms=%.3f",
        plan.map_id or -1,
        plan.start_x or -1,
        plan.start_y or -1,
        tostring(target.id or "-"),
        tostring(target.name or "-"),
        tostring(plan.path_mode or "-"),
        tostring(plan.npc_mode or "-"),
        tostring(plan.result or "-"),
        plan.path and #plan.path or 0,
        elapsed_ms))
end

local function count_plan_blockers(blocking)
    local counts = {
        npc = 0,
        runtime = 0,
        directional = 0,
        full = 0,
    }
    for _, value in pairs(blocking or {}) do
        if value == "npc" then
            counts.npc = counts.npc + 1
        elseif value == "runtime" then
            counts.runtime = counts.runtime + 1
        elseif type(value) == "table" then
            counts.directional = counts.directional + 1
        else
            counts.full = counts.full + 1
        end
    end
    return counts
end

local function log_auto_walk_no_path_detail(plan)
    if not plan then
        return
    end
    local target = plan.target or {}
    local counts = count_plan_blockers(plan.blocking)
    debug_tools.info(string.format(
        "AUTO_WALK_NO_PATH_DETAIL map=0x%02X start=(%d,%d) target_id=%s target_name=%s goal=(%d,%d) mode=%s npc_mode=%s reason=%s goal_block=%s target_walkable=%s npc_blocks=%d runtime_blocks=%d directional_blocks=%d full_blocks=%d",
        plan.map_id or -1,
        plan.start_x or -1,
        plan.start_y or -1,
        tostring(target.id or "-"),
        tostring(target.name or "-"),
        plan.goal_x or -1,
        plan.goal_y or -1,
        tostring(plan.path_mode or "-"),
        tostring(plan.npc_mode or "-"),
        tostring(plan.no_path_reason or "-"),
        tostring(plan.goal_block_reason or "-"),
        tostring(plan.target_walkable),
        counts.npc,
        counts.runtime,
        counts.directional,
        counts.full))
end

local function log_route_planning_snapshot(plan)
    if not plan then
        return
    end
    local target = plan.target or {}
    local counts = count_plan_blockers(plan.blocking)
    debug_tools.info(string.format(
        "ROUTE_PLAN_SNAPSHOT map=0x%02X context=%s start=(%d,%d) target_id=%s target_name=%s goal=(%d,%d) mode=%s npc_mode=%s parked_slots=%s npc_blocks=%d route_temp_blocks=%d result=%s path_len=%d",
        plan.map_id or -1,
        tostring(plan.plan_context or "plan"),
        plan.start_x or -1,
        plan.start_y or -1,
        tostring(target.id or "-"),
        tostring(target.name or "-"),
        plan.goal_x or -1,
        plan.goal_y or -1,
        tostring(plan.path_mode or "-"),
        tostring(plan.npc_mode or "-"),
        plan.parked_slots == nil and "-" or tostring(plan.parked_slots),
        counts.npc,
        count_active_route_temp_blocks(plan.map_id),
        tostring(plan.result or "-"),
        plan.path and #plan.path or 0))
end

local copy_opts

local function config_bool(key, default)
    local value = config.get(key)
    if value == nil then
        return default
    end
    value = tostring(value):lower()
    if value == "true" or value == "1" or value == "yes" then
        return true
    end
    if value == "false" or value == "0" or value == "no" then
        return false
    end
    return default
end

local function normalize_npc_mode(mode)
    if mode == "skip_npcs" or mode == "park_mobile_npcs" or mode == "live_npcs" then
        return mode
    end
    return nil
end

local function route_npc_mode_from_opts(opts)
    opts = opts or {}
    local mode = normalize_npc_mode(opts.npc_mode)
    if mode then
        return mode
    end
    if opts.skip_npcs then
        return "skip_npcs"
    end
    if opts.park_mobile_npcs then
        return "park_mobile_npcs"
    end
    return "live_npcs"
end

local function route_planning_opts(opts, npc_mode, context)
    local next_opts = copy_opts(opts)
    npc_mode = normalize_npc_mode(npc_mode) or route_npc_mode_from_opts(next_opts)
    next_opts.npc_mode = npc_mode
    if context then
        next_opts.plan_context = context
    end
    if npc_mode == "skip_npcs" then
        next_opts.skip_npcs = true
        next_opts.park_mobile_npcs = false
    elseif npc_mode == "park_mobile_npcs" then
        next_opts.skip_npcs = false
        next_opts.park_mobile_npcs = true
    else
        next_opts.skip_npcs = false
        next_opts.park_mobile_npcs = false
    end
    return next_opts
end

local function active_route_planning_opts(opts, context)
    local next_opts = route_planning_opts(opts, active_route_npc_mode or "live_npcs", context)
    if active_route_parked_slots ~= nil then
        next_opts.planning_parked_slots = active_route_parked_slots
    end
    return next_opts
end

local function config_int(key, default, min_value, max_value)
    local value = tonumber(config.get(key))
    if not value then
        return default
    end
    value = math.floor(value)
    if min_value and value < min_value then
        return min_value
    end
    if max_value and value > max_value then
        return max_value
    end
    return value
end

local function route_turn_settle_frames()
    return config_int("auto_step_route_turn_settle_frames", 16, 0, 60)
end

local function neutralize_directions()
    if not joypad or not joypad.set then
        return
    end
    joypad.set(1, {
        up = false,
        down = false,
        left = false,
        right = false,
    })
end

local function release_target_face(reason)
    if target_face_input and reason then
        debug_tools.debug("target face released: " .. tostring(reason))
    end
    target_face_input = nil
end

local function queue_target_face(face_dir, target)
    local dir = DIR_NAME_TO_KEY[face_dir]
    if not dir or not joypad or not joypad.set then
        return false
    end
    local frames = config_int("auto_walk_face_target_frames", 8, 0, 60)
    if frames <= 0 then
        return false
    end
    target_face_input = {
        dir = dir,
        frames = frames,
        release_frames = TARGET_FACE_RELEASE_FRAMES,
        name = target and target.name or "target",
    }
    if auto_step.suppress_direction_tracking then
        auto_step.suppress_direction_tracking(frames + TARGET_FACE_RELEASE_FRAMES + 4)
    end
    debug_tools.info(string.format(
        "AUTO_WALK_FACE target=%s face=%s dir=%s frames=%d",
        tostring(target_face_input.name),
        tostring(face_dir),
        tostring(dir),
        frames))
    return true
end

local function apply_target_face()
    if not target_face_input then
        return
    end
    if not joypad or not joypad.set then
        release_target_face("joypad unavailable")
        return
    end
    if target_face_input.frames > 0 then
        joypad.set(1, {[target_face_input.dir] = true})
        target_face_input.frames = target_face_input.frames - 1
        return
    end
    if target_face_input.release_frames > 0 then
        neutralize_directions()
        target_face_input.release_frames = target_face_input.release_frames - 1
        return
    end
    release_target_face("face complete")
end

local function speak_noninterrupting(message)
    if tolk.output then
        tolk.output(message)
    else
        tolk.output_interrupt(message)
    end
end

local function should_refresh_npcs_for_plan(opts)
    opts = opts or {}
    if opts.skip_npcs then
        return false
    end
    if opts.refresh_npcs ~= nil then
        return opts.refresh_npcs ~= false
    end
    if emulator_compat.is_bizhawk == true then
        return config_bool("bizhawk_route_refresh_npcs", false)
    end
    return true
end

local function should_freeze_npcs_for_autowalk(opts)
    opts = opts or {}
    if opts.freeze_npcs ~= nil then
        return opts.freeze_npcs ~= false
    end
    if emulator_compat.is_bizhawk == true then
        return config_bool("bizhawk_autowalk_freeze_npcs", false)
    end
    return true
end

local function should_park_mobile_npcs_for_autowalk(opts)
    opts = opts or {}
    if opts.survey_safe then
        return false
    end
    if opts.park_mobile_npcs ~= nil then
        return opts.park_mobile_npcs ~= false
    end
    return config_bool("auto_walk_park_mobile_npcs", false)
end

function M.autowalk_npc_parking_safe(map_id)
    if map_reader.is_walkable
       and map_reader.is_walkable(map_id, 0, 0) == true then
        return false, "walkable_origin"
    end
    return true, nil
end

local function should_refresh_objects_after_route()
    if emulator_compat.is_bizhawk == true then
        return config_bool("bizhawk_route_cleanup_refresh_objects", false)
    end
    return true
end

copy_opts = function(opts)
    local next_opts = {}
    for k, v in pairs(opts or {}) do
        next_opts[k] = v
    end
    return next_opts
end

local function pathfinder_opts_for_plan(opts, map_id)
    opts = opts or {}
    local path_opts = opts.pathfinder_opts or opts
    local next_opts
    if path_opts == opts then
        next_opts = copy_opts(opts)
    else
        next_opts = copy_opts(path_opts)
    end
    if opts.allow_hazards == true
       and map_id ~= nil
       and next_opts.walkability_snapshot == nil
       and map_reader.get_walkability_snapshot then
        next_opts.walkability_snapshot = map_reader.get_walkability_snapshot(map_id, {
            allow_hazards = true,
        })
    end
    return next_opts
end

local function adjacent_path_opts(opts, map_id)
    opts = opts or {}
    local next_opts = pathfinder_opts_for_plan(opts, map_id)
    if next_opts.use_adjacent_metrics ~= nil or opts.survey_safe == true then
        return next_opts
    end
    next_opts.use_adjacent_metrics = false
    return next_opts
end

local function parse_cell_key(k)
    local x, y = tostring(k):match("^(%-?%d+),(%-?%d+)$")
    if not x then return nil, nil end
    return tonumber(x), tonumber(y)
end

local function collect_runtime_blocks(map_id)
    local blocks = {}
    local map_blocks = runtime_blocked[map_id]
    if not map_blocks then
        return blocks
    end
    for k, dirs in pairs(map_blocks) do
        if type(dirs) == "table" and next(dirs) then
            local x, y = parse_cell_key(k)
            -- Build a sorted direction list for display
            local dir_list = {}
            for d in pairs(dirs) do dir_list[#dir_list + 1] = d end
            table.sort(dir_list)
            blocks[#blocks + 1] = {key = k, x = x, y = y, dirs = dirs, dir_list = dir_list}
        end
    end
    table.sort(blocks, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)
    return blocks
end

-- Map auto_step blocked_dir to the approach side of the destination cell.
-- When the player at (28,2) presses LEFT and fails to enter (27,2),
-- blocked_dir="left" and the approach is "east" (source is east of dest).
local DIR_TO_APPROACH = {
    right = "west",   -- source is west of dest
    left  = "east",   -- source is east of dest
    down  = "north",  -- source is north of dest
    up    = "south",  -- source is south of dest
}

local function get_destination_for_dir(from_x, from_y, dir)
    local delta = DIR_TO_DELTA[dir]
    local approach = DIR_TO_APPROACH[dir]
    if not delta or not approach then
        return nil, nil, nil
    end
    return from_x + delta.dx, from_y + delta.dy, approach
end

local function valid_npc_slot(slot)
    -- NPC RAM is adjacent to player stats; never let derived slots address past it.
    local slot_num = tonumber(slot)
    if slot_num == nil then
        return nil
    end
    slot_num = math.floor(slot_num)
    if slot_num < 0 or slot_num >= addr.NPC_COUNT then
        return nil
    end
    return slot_num
end

local function npc_slot_from_id(id)
    if not id then
        return nil
    end
    local slot = tonumber(tostring(id):match("^npc_(%d+)$"))
    return valid_npc_slot(slot)
end

local function normalize_npc_movement(value)
    if value == nil then
        return nil
    end
    return tonumber(value)
end

local function is_mobile_npc_blocker(npc)
    local movement = normalize_npc_movement(npc and npc.movement)
    return movement ~= nil and movement ~= 0
end

local function npc_blocker_kind(npc)
    local movement = normalize_npc_movement(npc and npc.movement)
    if movement == nil then
        return "unknown"
    end
    if movement == 0 then
        return "stationary"
    end
    return "mobile"
end

local function format_npc_movement(value)
    local movement = normalize_npc_movement(value)
    if movement == nil then
        return "-"
    end
    return string.format("0x%02X", movement % 256)
end

local function is_npc_slot_parked(slot)
    return autowalk_npc_parking ~= nil
        and slot ~= nil
        and autowalk_npc_parking.slots ~= nil
        and autowalk_npc_parking.slots[slot] ~= nil
end

local function add_runtime_block_direction(map_id, dest_x, dest_y, approach, source)
    if not map_id or dest_x == nil or dest_y == nil or not approach then
        return false
    end
    local k = cell_key(dest_x, dest_y)

    if not runtime_blocked[map_id] then
        runtime_blocked[map_id] = {}
    end
    if not runtime_blocked[map_id][k] then
        runtime_blocked[map_id][k] = {}
    end
    if runtime_blocked[map_id][k][approach] then
        return false  -- already recorded this direction
    end
    runtime_blocked[map_id][k][approach] = true
    debug_tools.info(string.format(
        "runtime block: map=0x%02X cell=(%d,%d) approach=%s source=%s",
        map_id, dest_x, dest_y, approach, tostring(source or "-")))
    return true
end

local function clear_runtime_block_direction(map_id, dest_x, dest_y, approach, source)
    local map_blocks = runtime_blocked[map_id]
    if not map_blocks then
        return false
    end
    local k = cell_key(dest_x, dest_y)
    local entry = map_blocks[k]
    if type(entry) ~= "table" or entry[approach] ~= true then
        return false
    end
    entry[approach] = nil
    if not next(entry) then
        map_blocks[k] = nil
    end
    if not next(map_blocks) then
        runtime_blocked[map_id] = nil
    end
    debug_tools.info(string.format(
        "runtime block cleared: map=0x%02X cell=(%d,%d) approach=%s source=%s",
        map_id, dest_x, dest_y, approach, tostring(source or "-")))
    return true
end

local function is_destination_occupied_by_npc(map_id, from_x, from_y, blocked_dir)
    local dest_x, dest_y = get_destination_for_dir(from_x, from_y, blocked_dir)
    if not dest_x or not dest_y then
        return false
    end
    if active_route_npc_mode == "park_mobile_npcs"
       and autowalk_npc_parking
       and apply_autowalk_npc_parking_state then
        apply_autowalk_npc_parking_state(autowalk_npc_parking)
    end
    objects.update_npcs()
    local npc_positions = objects.get_blocking_positions()
    for _, npc in ipairs(npc_positions) do
        if npc.x == dest_x and npc.y == dest_y then
            local slot = valid_npc_slot(npc.slot) or npc_slot_from_id(npc.id)
            local blocker = {
                x = npc.x,
                y = npc.y,
                id = npc.id,
                name = npc.name,
                slot = slot,
                movement = npc.movement,
                service = npc.service,
                kind = npc_blocker_kind(npc),
                parked = is_npc_slot_parked(slot),
            }
            return true, dest_x, dest_y, blocker
        end
    end
    return false, dest_x, dest_y
end

local function add_runtime_block_for_step(map_id, from_x, from_y, dir, source)
    local dest_x, dest_y, approach = get_destination_for_dir(from_x, from_y, dir)
    if not dest_x or not approach then
        return false
    end
    return add_runtime_block_direction(map_id, dest_x, dest_y, approach, source)
end

local function clear_runtime_block_for_step(map_id, from_x, from_y, dir, source)
    local dest_x, dest_y, approach = get_destination_for_dir(from_x, from_y, dir)
    if not dest_x or not approach then
        return false
    end
    return clear_runtime_block_direction(map_id, dest_x, dest_y, approach, source)
end

local function get_seam_entry(map_id, x, y, approach, create)
    local k = cell_key(x, y)
    local map_entries = seam_memory[map_id]
    if not map_entries then
        if not create then return nil end
        map_entries = {}
        seam_memory[map_id] = map_entries
    end
    local cell_entries = map_entries[k]
    if not cell_entries then
        if not create then return nil end
        cell_entries = {}
        map_entries[k] = cell_entries
    end
    local entry = cell_entries[approach]
    if not entry and create then
        entry = {
            key = k,
            x = x,
            y = y,
            approach = approach,
            blocked_count = 0,
            moved_count = 0,
            consecutive_blocked = 0,
            consecutive_moved = 0,
            last_result = nil,
            last_source = nil,
            last_from_x = nil,
            last_from_y = nil,
        }
        cell_entries[approach] = entry
    end
    return entry
end

local function classify_seam_entry(map_id, x, y, approach, entry)
    if not entry then
        return nil
    end
    local runtime_entry = runtime_blocked[map_id] and runtime_blocked[map_id][cell_key(x, y)]
    if type(runtime_entry) == "table" and runtime_entry[approach] == true then
        return "confirmed_blocked"
    end
    if entry.blocked_count > 0 and entry.moved_count > 0 then
        return "noisy"
    end
    if entry.blocked_count > 0 then
        return "blocked_only"
    end
    if entry.moved_count > 0 then
        return "passable_only"
    end
    return "unseen"
end

local function observe_seam_result(map_id, from_x, from_y, dir, result, source)
    local dest_x, dest_y, approach = get_destination_for_dir(from_x, from_y, dir)
    if not dest_x or not approach then
        return nil, nil
    end

    local entry = get_seam_entry(map_id, dest_x, dest_y, approach, true)
    local previous_class = classify_seam_entry(map_id, dest_x, dest_y, approach, entry)

    if result == "blocked" then
        entry.blocked_count = entry.blocked_count + 1
        entry.consecutive_blocked = entry.consecutive_blocked + 1
        entry.consecutive_moved = 0
    elseif result == "moved" then
        entry.moved_count = entry.moved_count + 1
        entry.consecutive_moved = entry.consecutive_moved + 1
        entry.consecutive_blocked = 0
    end

    entry.last_result = result
    entry.last_source = source
    entry.last_from_x = from_x
    entry.last_from_y = from_y

    local new_class = classify_seam_entry(map_id, dest_x, dest_y, approach, entry)
    debug_tools.info(string.format(
        "SEAM_OBSERVATION map=0x%02X cell=(%d,%d) approach=%s result=%s blocked=%d moved=%d classification=%s source=%s",
        map_id,
        dest_x,
        dest_y,
        approach,
        tostring(result),
        entry.blocked_count,
        entry.moved_count,
        tostring(new_class),
        tostring(source or "-")))
    if previous_class ~= new_class then
        debug_tools.info(string.format(
            "SEAM_CLASS_CHANGE map=0x%02X cell=(%d,%d) approach=%s from=%s to=%s",
            map_id,
            dest_x,
            dest_y,
            approach,
            tostring(previous_class),
            tostring(new_class)))
    end
    return entry, new_class
end

function M._release_pending_overworld_timeout_observation(reason)
    local pending = M._pending_overworld_timeout_observation
    if not pending then
        return false
    end
    M._pending_overworld_timeout_observation = nil
    debug_tools.info(string.format(
        "SEAM_OBSERVATION_RELEASED reason=%s map=0x%02X from=(%d,%d) dir=%s source=%s",
        tostring(reason or "unknown"),
        pending.map_id or -1,
        pending.from_x or -1,
        pending.from_y or -1,
        tostring(pending.dir),
        tostring(pending.source or "-")))
    observe_seam_result(
        pending.map_id,
        pending.from_x,
        pending.from_y,
        pending.dir,
        "blocked",
        pending.source)
    return true
end

function M._suppress_pending_overworld_timeout_observation(reason)
    local pending = M._pending_overworld_timeout_observation
    if not pending then
        return false
    end
    M._pending_overworld_timeout_observation = nil
    debug_tools.info(string.format(
        "SEAM_OBSERVATION_SUPPRESSED reason=%s map=0x%02X from=(%d,%d) dir=%s source=%s",
        tostring(reason or "unknown"),
        pending.map_id or -1,
        pending.from_x or -1,
        pending.from_y or -1,
        tostring(pending.dir),
        tostring(pending.source or "-")))
    return true
end

function M._defer_overworld_timeout_observation(map_id, from_x, from_y, dir, source)
    if M._pending_overworld_timeout_observation then
        M._release_pending_overworld_timeout_observation("replaced_by_new_timeout")
    end
    M._pending_overworld_timeout_observation = {
        map_id = map_id,
        from_x = from_x,
        from_y = from_y,
        dir = dir,
        source = source,
        frames_remaining = M.BATTLE_ONSET_DIAGNOSTIC_GRACE_FRAMES,
    }
    debug_tools.info(string.format(
        "SEAM_OBSERVATION_DEFERRED reason=battle_onset_grace frames=%d map=0x%02X from=(%d,%d) dir=%s source=%s",
        M.BATTLE_ONSET_DIAGNOSTIC_GRACE_FRAMES,
        map_id or -1,
        from_x or -1,
        from_y or -1,
        tostring(dir),
        tostring(source or "-")))
end

function M.tick_diagnostics()
    local pending = M._pending_overworld_timeout_observation
    if not pending then
        return false
    end
    pending.frames_remaining = pending.frames_remaining - 1
    if pending.frames_remaining <= 0 then
        M._release_pending_overworld_timeout_observation("battle_grace_elapsed")
        return true
    end
    return false
end

if event_bus.subscribe then
    event_bus.subscribe("battle_started", function()
        M._suppress_pending_overworld_timeout_observation("battle_started")
    end)
end

local function collect_seam_entries(map_id)
    local entries = {}
    local map_entries = seam_memory[map_id]
    if not map_entries then
        return entries
    end
    for _, by_approach in pairs(map_entries) do
        for approach, entry in pairs(by_approach) do
            entries[#entries + 1] = {
                key = entry.key,
                x = entry.x,
                y = entry.y,
                approach = approach,
                blocked_count = entry.blocked_count,
                moved_count = entry.moved_count,
                classification = classify_seam_entry(map_id, entry.x, entry.y, approach, entry),
            }
        end
    end
    table.sort(entries, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        if a.x ~= b.x then return a.x < b.x end
        return (APPROACH_ORDER[a.approach] or 99) < (APPROACH_ORDER[b.approach] or 99)
    end)
    return entries
end

local function get_seam_summary(map_id)
    local summary = {
        total = 0,
        confirmed_blocked = 0,
        noisy = 0,
        blocked_only = 0,
        passable_only = 0,
    }
    for _, entry in ipairs(collect_seam_entries(map_id)) do
        summary.total = summary.total + 1
        if summary[entry.classification] ~= nil then
            summary[entry.classification] = summary[entry.classification] + 1
        end
    end
    return summary
end

local function clear_seam_memory(map_id_or_all)
    if map_id_or_all == "all" then
        seam_memory = {}
        seam_retry_state = nil
        return
    end
    seam_memory[map_id_or_all] = nil
    if seam_retry_state and seam_retry_state.map_id == map_id_or_all then
        seam_retry_state = nil
    end
end

local function add_temporary_directional_block(blocking, from_x, from_y, dir)
    local dest_x, dest_y, approach = get_destination_for_dir(from_x, from_y, dir)
    if not dest_x or not approach then
        return nil, nil, nil
    end
    local k = cell_key(dest_x, dest_y)
    local entry = blocking[k]
    if entry ~= "npc" then
        if type(entry) ~= "table" then
            entry = {}
            blocking[k] = entry
        end
        entry[approach] = true
    end
    return dest_x, dest_y, approach
end

local function record_active_route_temp_block(map_id, from_x, from_y, dir, source)
    local dest_x, dest_y, approach = get_destination_for_dir(from_x, from_y, dir)
    if not map_id or not dest_x or not approach then
        return false
    end
    if not active_route_temp_blocks then
        active_route_temp_blocks = {}
    end
    if not active_route_temp_blocks[map_id] then
        active_route_temp_blocks[map_id] = {}
    end
    local k = cell_key(dest_x, dest_y)
    if not active_route_temp_blocks[map_id][k] then
        active_route_temp_blocks[map_id][k] = {}
    end
    if active_route_temp_blocks[map_id][k][approach] then
        return false
    end
    active_route_temp_blocks[map_id][k][approach] = true
    debug_tools.info(string.format(
        "AUTO_WALK_TEMP_BLOCK map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d) approach=%s source=%s count=%d",
        map_id,
        from_x or -1,
        from_y or -1,
        tostring(dir),
        dest_x,
        dest_y,
        approach,
        tostring(source or "-"),
        count_active_route_temp_blocks(map_id)))
    return true
end

local function clear_active_route_temp_block_for_step(map_id, from_x, from_y, dir, source)
    local dest_x, dest_y, approach = get_destination_for_dir(from_x, from_y, dir)
    local map_blocks = active_route_temp_blocks and active_route_temp_blocks[map_id]
    if not map_blocks or not dest_x or not approach then
        return false
    end
    local k = cell_key(dest_x, dest_y)
    local entry = map_blocks[k]
    if type(entry) ~= "table" or entry[approach] ~= true then
        return false
    end
    entry[approach] = nil
    if not next(entry) then
        map_blocks[k] = nil
    end
    if not next(map_blocks) then
        active_route_temp_blocks[map_id] = nil
    end
    if not next(active_route_temp_blocks) then
        active_route_temp_blocks = nil
    end
    debug_tools.info(string.format(
        "AUTO_WALK_TEMP_BLOCK_CLEAR map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d) approach=%s source=%s count=%d",
        map_id,
        from_x or -1,
        from_y or -1,
        tostring(dir),
        dest_x,
        dest_y,
        approach,
        tostring(source or "-"),
        count_active_route_temp_blocks(map_id)))
    return true
end

local function clear_active_route_temp_blocks(map_id, source)
    local count = count_active_route_temp_blocks(map_id)
    if count == 0 then
        return 0
    end

    if map_id then
        if active_route_temp_blocks then
            active_route_temp_blocks[map_id] = nil
            if not next(active_route_temp_blocks) then
                active_route_temp_blocks = nil
            end
        end
    else
        active_route_temp_blocks = nil
    end

    debug_tools.info(string.format(
        "AUTO_WALK_TEMP_BLOCK_RELAX map=%s source=%s cleared=%d",
        map_id and string.format("0x%02X", map_id) or "all",
        tostring(source or "-"),
        count))
    return count
end

local function clear_active_route_temp_blocks_except(map_id, keep_from_x, keep_from_y, keep_dir, source)
    local map_blocks = active_route_temp_blocks and active_route_temp_blocks[map_id]
    if not map_blocks then
        return 0
    end

    local keep_x, keep_y, keep_approach = get_destination_for_dir(keep_from_x, keep_from_y, keep_dir)
    local keep_key = keep_x and keep_y and cell_key(keep_x, keep_y) or nil
    local cleared = 0

    for k, dirs in pairs(map_blocks) do
        if type(dirs) == "table" then
            for approach, enabled in pairs(dirs) do
                if enabled and not (k == keep_key and approach == keep_approach) then
                    dirs[approach] = nil
                    cleared = cleared + 1
                end
            end
            if not next(dirs) then
                map_blocks[k] = nil
            end
        end
    end

    if not next(map_blocks) then
        active_route_temp_blocks[map_id] = nil
    end
    if active_route_temp_blocks and not next(active_route_temp_blocks) then
        active_route_temp_blocks = nil
    end

    if cleared > 0 then
        debug_tools.info(string.format(
            "AUTO_WALK_TEMP_BLOCK_RELAX map=0x%02X source=%s cleared=%d kept_dest=(%d,%d) kept_approach=%s count=%d",
            map_id,
            tostring(source or "-"),
            cleared,
            keep_x or -1,
            keep_y or -1,
            tostring(keep_approach or "-"),
            count_active_route_temp_blocks(map_id)))
    end
    return cleared
end

local function apply_active_route_temp_blocks(blocking, map_id)
    local map_blocks = active_route_temp_blocks and active_route_temp_blocks[map_id]
    if not blocking or not map_blocks then
        return 0
    end
    local applied = 0
    for k, dirs in pairs(map_blocks) do
        if type(dirs) == "table" then
            for approach, enabled in pairs(dirs) do
                if enabled then
                    local entry = blocking[k]
                    if entry ~= "npc" then
                        if type(entry) ~= "table" then
                            entry = {}
                            blocking[k] = entry
                        end
                        if entry[approach] ~= true then
                            entry[approach] = true
                        end
                        applied = applied + 1
                    end
                end
            end
        end
    end
    return applied
end

local function same_seam_retry(map_id, from_x, from_y, dir)
    return seam_retry_state
        and seam_retry_state.map_id == map_id
        and seam_retry_state.from_x == from_x
        and seam_retry_state.from_y == from_y
        and seam_retry_state.dir == dir
end

local function start_seam_bruteforce(map_id, from_x, from_y, dir, block_data)
    local function entry_cadence_for_seam(dest_x, dest_y, approach)
        local prime_frames = 0
        local settle_frames = 0
        local hold_after_movement_start = false
        local hold_after_movement_start_frames = nil

        if block_data and block_data.entry_prime_waveform == true then
            prime_frames = tonumber(block_data.entry_prime_frames) or 0
            settle_frames = tonumber(block_data.entry_prime_settle_frames) or 0
            hold_after_movement_start = block_data.entry_hold_after_movement_start == true
            hold_after_movement_start_frames = tonumber(
                block_data.entry_hold_after_movement_start_frames)
        elseif same_seam_retry(map_id, from_x, from_y, dir)
           and (tonumber(seam_retry_state.entry_prime_frames) or 0) > 0 then
            prime_frames = tonumber(seam_retry_state.entry_prime_frames) or 0
            settle_frames = tonumber(seam_retry_state.entry_settle_frames) or 0
            hold_after_movement_start = seam_retry_state.entry_hold_after_movement_start == true
            hold_after_movement_start_frames = tonumber(
                seam_retry_state.entry_hold_after_movement_start_frames)
        elseif map_reader.get_entry_prime_frames then
            prime_frames = map_reader.get_entry_prime_frames(
                map_id, dest_x, dest_y, approach)
            if map_reader.get_entry_settle_frames then
                settle_frames = map_reader.get_entry_settle_frames(
                    map_id, dest_x, dest_y, approach)
            end
        end

        prime_frames = math.max(0, math.min(120, math.floor(tonumber(prime_frames) or 0)))
        settle_frames = math.max(0, math.min(120, math.floor(tonumber(settle_frames) or 0)))
        return prime_frames, settle_frames,
            hold_after_movement_start, hold_after_movement_start_frames
    end

    local attempts = 1
    if same_seam_retry(map_id, from_x, from_y, dir) then
        attempts = seam_retry_state.attempts + 1
    end
    if attempts > SEAM_BRUTE_FORCE_RETRY_LIMIT then
        return false
    end
    local dest_x, dest_y, approach = get_destination_for_dir(from_x, from_y, dir)
    local entry_prime_frames, entry_settle_frames,
        entry_hold_after_movement_start, entry_hold_after_movement_start_frames =
        entry_cadence_for_seam(dest_x, dest_y, approach)
    seam_retry_state = {
        map_id = map_id,
        from_x = from_x,
        from_y = from_y,
        dir = dir,
        dest_x = dest_x,
        dest_y = dest_y,
        approach = approach,
        attempts = attempts,
        entry_prime_frames = entry_prime_frames,
        entry_settle_frames = entry_settle_frames,
        entry_hold_after_movement_start = entry_hold_after_movement_start,
        entry_hold_after_movement_start_frames = entry_hold_after_movement_start_frames,
    }
    if entry_prime_frames > 0 then
        debug_tools.info(string.format(
            "SEAM_BRUTE_FORCE map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d) attempt=%d/%d mode=entry_cadence prime=%d settle=%d",
            map_id,
            from_x,
            from_y,
            tostring(dir),
            dest_x or -1,
            dest_y or -1,
            attempts,
            SEAM_BRUTE_FORCE_RETRY_LIMIT,
            entry_prime_frames,
            entry_settle_frames))
        auto_step.inject_step(dir, {
            source = "seam_retry",
            entry_prime_frames = entry_prime_frames,
            entry_settle_frames = entry_settle_frames,
            hold_after_movement_start = entry_hold_after_movement_start,
            hold_after_movement_start_frames = entry_hold_after_movement_start_frames,
        })
    else
        debug_tools.info(string.format(
            "SEAM_BRUTE_FORCE map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d) attempt=%d/%d mode=hold_after_twitch",
            map_id,
            from_x,
            from_y,
            tostring(dir),
            dest_x or -1,
            dest_y or -1,
            attempts,
            SEAM_BRUTE_FORCE_RETRY_LIMIT))
        auto_step.inject_step(dir, {
            source = "seam_retry",
            hold_after_movement_start = true,
            hold_after_movement_start_frames = config_int("auto_step_seam_retry_hold_after_start_frames", 12, 0, 60),
        })
    end
    return true
end

local function clear_seam_retry_state()
    seam_retry_state = nil
end

local function is_suspect_route_timeout(block_data)
    return block_data
        and block_data.queued_route ~= false
        and block_data.movement_started == true
end

-- ============================================================
-- NPC Freeze
-- ============================================================

-- capture_npc_snapshot(): Read all 20 NPC entries (3 bytes each) from RAM
-- and save them into frozen_npc_snapshot. Called when freeze is activated.
-- Byte 0: sprite type (bits 7-5) + X position (bits 4-0).
-- Byte 1: animation frame (bit 7) + direction (bits 6-5) + Y position (bits 4-0).
-- Byte 2: movement behavior code.
local function capture_npc_snapshot()
    frozen_npc_snapshot = {}
    for i = 0, addr.NPC_COUNT - 1 do
        local base = addr.NPC_DATA_START + i * addr.NPC_ENTRY_SIZE
        frozen_npc_snapshot[i] = {
            memory.readbyte(base),
            memory.readbyte(base + 1),
            memory.readbyte(base + 2),
        }
    end
end

local function parse_npc_slot(obj)
    if not obj or not obj.id then return nil end
    local slot = tostring(obj.id):match("^npc_(%d+)$")
    return valid_npc_slot(slot)
end

local function decode_npc_coords(byte0, byte1)
    return byte0 % 32, byte1 % 32
end

local function is_active_npc_slot(byte0, byte1)
    local x, y = decode_npc_coords(byte0, byte1)
    return not ((x == 0 and y == 0) or (x == 31 and y == 31))
end

local function write_npc_bytes_if_changed(slot, byte0, byte1, byte2)
    local safe_slot = valid_npc_slot(slot)
    if safe_slot == nil then
        debug_tools.error(string.format(
            "NPC write refused: slot=%s out of range 0..%d (would corrupt RAM near player stats)",
            tostring(slot),
            (addr.NPC_COUNT or 1) - 1))
        return false
    end

    local base = addr.NPC_DATA_START + safe_slot * addr.NPC_ENTRY_SIZE
    if memory.readbyte(base) ~= byte0 then
        memory.writebyte(base, byte0)
    end
    if memory.readbyte(base + 1) ~= byte1 then
        memory.writebyte(base + 1, byte1)
    end
    if memory.readbyte(base + 2) ~= byte2 then
        memory.writebyte(base + 2, byte2)
    end
    return true
end

apply_autowalk_npc_parking_state = function(state)
    if not state then
        return 0
    end
    local parked = 0
    for slot, snapshot in pairs(state.slots or {}) do
        if write_npc_bytes_if_changed(slot, snapshot.parked_byte0, snapshot.parked_byte1, snapshot.byte2) then
            parked = parked + 1
        end
    end
    return parked
end

local function release_autowalk_npc_parking(reason)
    if not autowalk_npc_parking then
        return
    end
    local map_id, px, py = nav.get_position()
    local state = autowalk_npc_parking
    local is_deferred_retry = reason == "deferred restore retry"
    local retry_attempts = state.retry_attempts or 0
    if is_deferred_retry then
        retry_attempts = retry_attempts + 1
    end
    if map_id ~= state.map_id then
        debug_tools.info(string.format(
            "AUTO_WALK_NPC_PARK_RESTORE map=0x%02X restored=false restored_slots=0 deferred_slots=0 reason=%s map_changed=true",
            state.map_id or 0,
            tostring(reason or "release")))
        autowalk_npc_parking = nil
        return
    end

    local restored = 0
    local deferred = {}
    local deferred_count = 0
    for slot, snapshot in pairs(state.slots or {}) do
        if snapshot.x == px and snapshot.y == py then
            deferred[slot] = snapshot
            deferred_count = deferred_count + 1
        else
            if write_npc_bytes_if_changed(slot, snapshot.byte0, snapshot.byte1, snapshot.byte2) then
                restored = restored + 1
            end
        end
    end

    debug_tools.info(string.format(
        "AUTO_WALK_NPC_PARK_RESTORE map=0x%02X restored=true restored_slots=%d deferred_slots=%d reason=%s",
        state.map_id or 0,
        restored,
        deferred_count,
        tostring(reason or "release")))

    if deferred_count > 0 then
        autowalk_npc_parking = {
            map_id = state.map_id,
            slots = deferred,
            pending_restore = true,
            retry_attempts = retry_attempts,
            retry_delay_frames = is_deferred_retry and NPC_PARK_DEFERRED_RETRY_FRAMES or 0,
        }
    else
        autowalk_npc_parking = nil
    end
end

local function pending_restore_overlaps_player(state)
    if not state or not state.pending_restore then
        return false
    end
    local _, px, py = nav.get_position()
    for _, snapshot in pairs(state.slots or {}) do
        if snapshot.x == px and snapshot.y == py then
            return true
        end
    end
    return false
end

local function merge_pending_restore_slots_into_parking(state, pending_state)
    local inherited = 0
    if not state or not pending_state then
        return inherited
    end
    for slot, snapshot in pairs(pending_state.slots or {}) do
        if state.slots[slot] == nil then
            state.slots[slot] = snapshot
            inherited = inherited + 1
        end
    end
    return inherited
end

local function start_autowalk_npc_parking(target, opts)
    opts = opts or {}
    local map_id = nav.get_position()
    release_autowalk_npc_parking("new autowalk parking")
    local pending_state = nil
    if autowalk_npc_parking then
        if autowalk_npc_parking.pending_restore and autowalk_npc_parking.map_id == map_id then
            pending_state = autowalk_npc_parking
        else
            debug_tools.info("AUTO_WALK_NPC_PARK_START skipped: pending restore still active")
            return 0
        end
    end
    local exempt_slot = parse_npc_slot(target)
    local state = {
        map_id = map_id,
        slots = {},
        exempt_slot = exempt_slot,
        pending_restore = false,
    }
    local count = merge_pending_restore_slots_into_parking(state, pending_state)
    if count > 0 then
        debug_tools.info(string.format(
            "AUTO_WALK_NPC_PARK_START merged_pending_restore slots=%d",
            count))
    end
    for slot = 0, addr.NPC_COUNT - 1 do
        if slot ~= exempt_slot and state.slots[slot] == nil then
            local base = addr.NPC_DATA_START + slot * addr.NPC_ENTRY_SIZE
            local byte0 = memory.readbyte(base)
            local byte1 = memory.readbyte(base + 1)
            local byte2 = memory.readbyte(base + 2)
            if is_active_npc_slot(byte0, byte1)
               and (opts.park_stationary_npcs == true or tonumber(byte2) ~= 0) then
                local x, y = decode_npc_coords(byte0, byte1)
                state.slots[slot] = {
                    byte0 = byte0,
                    byte1 = byte1,
                    byte2 = byte2,
                    -- Low coordinates (0,0) make the ROM skip the slot; (31,31)
                    -- stays active and can wedge the sprite-OAM clear loop.
                    parked_byte0 = byte0 - (byte0 % 32),
                    parked_byte1 = byte1 - (byte1 % 32),
                    x = x,
                    y = y,
                }
                count = count + 1
            end
        end
    end

    autowalk_npc_parking = state
    local parked = apply_autowalk_npc_parking_state(state)
    debug_tools.info(string.format(
        "AUTO_WALK_NPC_PARK_START map=0x%02X parked_slots=%d exempt_slot=%s",
        map_id or 0,
        parked,
        exempt_slot and tostring(exempt_slot) or "-"))
    if count == 0 then
        autowalk_npc_parking = nil
    end
    return parked
end

local function add_live_npc_to_autowalk_parking(map_id, npc, reason)
    if active_route_npc_mode ~= "park_mobile_npcs" then
        return false, "not_parked_mode"
    end
    local slot = npc and (valid_npc_slot(npc.slot) or npc_slot_from_id(npc.id))
    if slot == nil then
        return false, "missing_slot"
    end
    local exempt_slot = parse_npc_slot(active_route_target or last_pathfind_obj)
    if slot == exempt_slot then
        return false, "target_exempt"
    end
    if autowalk_npc_parking and autowalk_npc_parking.pending_restore then
        return false, "pending_restore"
    end
    if autowalk_npc_parking and autowalk_npc_parking.map_id ~= map_id then
        return false, "map_mismatch"
    end
    if autowalk_npc_parking
       and autowalk_npc_parking.slots
       and autowalk_npc_parking.slots[slot] then
        return false, "already_parked"
    end

    local base = addr.NPC_DATA_START + slot * addr.NPC_ENTRY_SIZE
    local byte0 = memory.readbyte(base)
    local byte1 = memory.readbyte(base + 1)
    local byte2 = memory.readbyte(base + 2)
    if not is_active_npc_slot(byte0, byte1) then
        return false, "inactive_slot"
    end
    if tonumber(byte2) == 0 then
        return false, "stationary"
    end

    if not autowalk_npc_parking then
        autowalk_npc_parking = {
            map_id = map_id,
            slots = {},
            exempt_slot = exempt_slot,
            pending_restore = false,
        }
    end

    local x, y = decode_npc_coords(byte0, byte1)
    autowalk_npc_parking.slots[slot] = {
        byte0 = byte0,
        byte1 = byte1,
        byte2 = byte2,
        -- Low coordinates (0,0) make the ROM skip the slot; (31,31) stays active.
        parked_byte0 = byte0 - (byte0 % 32),
        parked_byte1 = byte1 - (byte1 % 32),
        x = x,
        y = y,
    }
    local parked = apply_autowalk_npc_parking_state(autowalk_npc_parking)
    active_route_parked_slots = parked
    debug_tools.info(string.format(
        "AUTO_WALK_NPC_REACTIVE_PARK map=0x%02X slot=%d id=%s name=%s x=%d y=%d movement=0x%02X parked_slots=%d reason=%s",
        map_id or 0,
        slot,
        tostring(npc and npc.id or ("npc_" .. slot)),
        tostring(npc and npc.name or "NPC"),
        x or -1,
        y or -1,
        byte2 or 0,
        parked,
        tostring(reason or "npc_block")))
    return true
end

local function npc_blocked_route_message(npc)
    if npc_blocker_kind(npc) == "stationary" then
        return "Route may be blocked by a stationary NPC or an out-of-date NPC position. Try again in a moment, or choose another interaction point."
    end
    if npc_blocker_kind(npc) == "mobile" then
        return "Route blocked by NPC movement. Wait for them to move and try again."
    end
    return "Route blocked by NPC movement. Wait for them to move and try again."
end

local function parse_manual_park_npcs_mode(arg)
    local mode = tostring(arg or ""):match("^%s*(.-)%s*$"):lower()
    if mode == "" or mode == "all" or mode == "full" then
        return "all", {park_stationary_npcs = true}
    end
    if mode == "mobile" or mode == "moving" then
        return "mobile", {}
    end
    return nil, nil
end

local function prepare_route_planning_blocking(map_id, opts)
    opts = opts or {}
    local npc_mode = route_npc_mode_from_opts(opts)
    opts.npc_mode = npc_mode
    local parked_slots = opts.planning_parked_slots

    if npc_mode == "park_mobile_npcs" then
        if autowalk_npc_parking then
            parked_slots = apply_autowalk_npc_parking_state(autowalk_npc_parking)
        end
        opts.planning_parked_slots = parked_slots
        if opts.refresh_npcs ~= false then
            objects.update_npcs()
        end
    elseif npc_mode == "skip_npcs" then
        opts.skip_npcs = true
    elseif should_refresh_npcs_for_plan(opts) then
        objects.update_npcs()
    end

    local build_opts = nil
    if npc_mode == "skip_npcs" then
        build_opts = {skip_npcs = true}
    end
    local blocking = M.build_path_blocking(map_id, build_opts)
    apply_active_route_temp_blocks(blocking, map_id)
    return blocking, npc_mode, parked_slots
end

local function release_target_npc_hold(reason)
    if target_npc_hold and reason then
        debug_tools.info("NPC target hold released: " .. reason)
    end
    target_npc_hold = nil
end

local function encode_npc_coordinate_byte(current_byte, coord)
    local coord_num = tonumber(coord)
    if not coord_num or coord_num < 0 or coord_num > 31 then
        return current_byte, false
    end
    coord_num = math.floor(coord_num)
    return (current_byte - (current_byte % 32)) + coord_num, true
end

local function write_target_npc_snapshot(slot, snapshot)
    write_npc_bytes_if_changed(slot, snapshot[1], snapshot[2], snapshot[3])
end

local function start_target_npc_hold(obj, opts)
    opts = opts or {}
    if not obj or obj.type ~= objects.TYPE_NPC then
        return false
    end
    local frames = tonumber(opts.frames)
    if frames == nil then
        frames = config_int("auto_walk_npc_hold_frames", 480, 0, 3600)
    else
        frames = math.max(0, math.min(3600, math.floor(frames)))
    end
    if frames <= 0 then
        return false
    end
    local slot = parse_npc_slot(obj)
    if not slot then
        debug_tools.debug("NPC target hold skipped: could not parse slot for " .. tostring(obj.id))
        return false
    end

    local base = addr.NPC_DATA_START + slot * addr.NPC_ENTRY_SIZE
    local byte0 = memory.readbyte(base)
    local byte1 = memory.readbyte(base + 1)
    local byte2 = memory.readbyte(base + 2)
    local hold_x = obj.target_hold_x
    if hold_x == nil then
        hold_x = obj.x
    end
    local hold_y = obj.target_hold_y
    if hold_y == nil then
        hold_y = obj.y
    end
    local target_byte0, used_target_x = encode_npc_coordinate_byte(byte0, hold_x)
    local target_byte1, used_target_y = encode_npc_coordinate_byte(byte1, hold_y)
    local snapshot = {
        target_byte0,
        target_byte1,
        byte2,
    }
    target_npc_hold = {
        slot = slot,
        frames = frames,
        name = obj.name,
        snapshot = snapshot,
    }
    write_target_npc_snapshot(slot, snapshot)
    debug_tools.info(string.format(
        "NPC target hold started: target=%s slot=%d frames=%d at=(%s,%s)",
        tostring(obj.name),
        slot,
        frames,
        used_target_x and tostring(hold_x) or "live",
        used_target_y and tostring(hold_y) or "live"))
    return true
end

function M.hold_target_npc(obj, reason, frames)
    local ok = start_target_npc_hold(obj, {frames = frames})
    if ok and reason then
        debug_tools.info("NPC target hold requested: " .. tostring(reason))
    end
    return ok
end

function M.release_target_npc_hold(reason)
    release_target_npc_hold(reason)
end

local function freeze_npcs_for_pathing()
    capture_npc_snapshot()
    npc_freeze_active = true
end

-- apply_npc_freeze(): Restore snapshotted NPC bytes to RAM.
-- Call once per frame immediately after FCEU.frameadvance().
-- No-op when npc_freeze_active is false, so it's safe to call every frame.
-- Diff-only: skip writebyte when RAM already matches the snapshot. Most
-- frozen NPCs don't change RAM-side, so this avoids 60 redundant BizHawk
-- writebyte calls per frame.
function M.apply_npc_freeze()
    if npc_freeze_active then
        for i = 0, addr.NPC_COUNT - 1 do
            local snap = frozen_npc_snapshot[i]
            if snap then
                write_npc_bytes_if_changed(i, snap[1], snap[2], snap[3])
            end
        end
    end
    if autowalk_npc_parking then
        if autowalk_npc_parking.pending_restore then
            local retry_delay_frames = tonumber(autowalk_npc_parking.retry_delay_frames) or 0
            if retry_delay_frames > 0 and pending_restore_overlaps_player(autowalk_npc_parking) then
                autowalk_npc_parking.retry_delay_frames = retry_delay_frames - 1
            else
                release_autowalk_npc_parking("deferred restore retry")
            end
        else
            apply_autowalk_npc_parking_state(autowalk_npc_parking)
        end
    end
    if target_npc_hold then
        write_target_npc_snapshot(target_npc_hold.slot, target_npc_hold.snapshot)
        target_npc_hold.frames = target_npc_hold.frames - 1
        if target_npc_hold.frames <= 0 then
            release_target_npc_hold("timer expired")
        end
    end
    apply_target_face()
end

-- toggle_npc_freeze(): Toggle NPC position freeze on/off.
-- Returns true if freeze is now active, false if released.
function M.toggle_npc_freeze()
    if npc_freeze_active then
        npc_freeze_active = false
        frozen_npc_snapshot = {}
        release_autowalk_npc_parking("manual unfreeze")
        release_target_npc_hold("manual unfreeze")
        tolk.output_interrupt("NPCs unfrozen.")
        return false
    else
        release_autowalk_npc_parking("manual full freeze")
        release_target_npc_hold("manual full freeze")
        capture_npc_snapshot()
        npc_freeze_active = true
        tolk.output_interrupt("NPCs frozen.")
        return true
    end
end

-- freeze_npcs() / unfreeze_npcs(): Direct control for remote commands.
function M.freeze_npcs()
    release_autowalk_npc_parking("full freeze requested")
    release_target_npc_hold("full freeze requested")
    capture_npc_snapshot()
    npc_freeze_active = true
end

function M.unfreeze_npcs()
    npc_freeze_active = false
    frozen_npc_snapshot = {}
    release_autowalk_npc_parking("manual unfreeze")
    release_target_npc_hold("manual unfreeze")
end

-- is_npc_freeze_active(): Query freeze state (for can_walk guard, etc.)
function M.is_npc_freeze_active()
    return npc_freeze_active
end

function M.is_autowalk_npc_parking_active()
    return autowalk_npc_parking ~= nil
end

function M.manual_park_npcs(arg)
    local mode, opts = parse_manual_park_npcs_mode(arg)
    if not mode then
        return nil, "park_npcs usage: park_npcs, park_npcs:all, or park_npcs:mobile"
    end
    release_target_npc_hold("manual npc park")
    local parked = start_autowalk_npc_parking(nil, opts)
    return {
        mode = mode,
        parked_slots = parked,
        active = autowalk_npc_parking ~= nil,
    }
end

function M.restore_manual_parked_npcs(reason)
    local had_active = autowalk_npc_parking ~= nil
    release_autowalk_npc_parking(reason or "manual restore parked npcs")
    return {
        had_active = had_active,
        active = autowalk_npc_parking ~= nil,
    }
end

-- set_autowalk_guard(fn): Install a main-loop-owned predicate used to veto
-- auto-walk starts when field-state gates say movement is unsafe.
-- fn(opts) should return (ok, reason). ok=false prevents route planning and
-- speaks reason to the user.
function M.set_autowalk_guard(fn)
    autowalk_guard = fn
end

-- ============================================================
-- Runtime Blocked Cells
-- ============================================================

-- build_path_blocking(map_id, opts): Combine NPC positions + runtime blocks +
-- static directional blocks into a single blocking table for A*.
--
-- opts.skip_npcs (boolean): When true, omit NPC positions from the blocking
--   table.  Used by map_survey to test map connectivity without frozen NPCs
--   creating artificial isolation.
--
-- Values in the returned table:
--   "npc"                          — NPC occupies the cell (fully blocked)
--   {north=true, east=true, ...}   — directional engine wall (blocked from
--                                    listed approach sides only)
function M.build_path_blocking(map_id, opts)
    opts = opts or {}
    local blocking = {}
    if not opts.skip_npcs then
        local positions = objects.get_blocking_positions()
        for _, pos in ipairs(positions) do
            blocking[cell_key(pos.x, pos.y)] = "npc"
        end
    end
    -- Merge static directional blocks from map_reader (building walls etc.)
    local static_dirs = map_reader.get_directional_blocks(map_id)
    if static_dirs then
        for k, dirs in pairs(static_dirs) do
            if not blocking[k] then
                -- Copy the direction table so runtime/temporary blocks can be merged in.
                blocking[k] = copy_direction_table(dirs)
            end
        end
    end
    -- `include_unconfirmed_seams` is intentionally ignored. Seam-memory is
    -- noisy on this engine and remains diagnostic-only; active autowalk
    -- reroutes keep their own route-local temporary blocks for edges that
    -- failed during the current route.
    -- Merge runtime directional blocks
    if runtime_blocked[map_id] then
        for k, dirs in pairs(runtime_blocked[map_id]) do
            if not blocking[k] then
                -- Keep the pathfinding overlay mutable without aliasing the
                -- verified runtime table. Reroute-only temporary blocks are
                -- added to this table during planning and must stay soft.
                blocking[k] = copy_direction_table(dirs)
            elseif type(blocking[k]) == "table" then
                -- Merge directions into existing directional entry
                for d, v in pairs(dirs) do
                    blocking[k][d] = v
                end
            end
            -- If blocking[k] == "npc", NPC takes precedence (fully blocked)
        end
    end
    return blocking
end

-- count_runtime_blocks(map_id): Return count of runtime-discovered blocks.
function M.count_runtime_blocks(map_id)
    return #collect_runtime_blocks(map_id)
end

function M.get_seam_entries(map_id)
    return collect_seam_entries(map_id)
end

function M.get_seam_observation(map_id, x, y, approach)
    local entry = get_seam_entry(map_id, x, y, approach, false)
    if not entry then
        return nil
    end
    return {
        key = entry.key,
        x = entry.x,
        y = entry.y,
        approach = approach,
        blocked_count = entry.blocked_count,
        moved_count = entry.moved_count,
        consecutive_blocked = entry.consecutive_blocked,
        consecutive_moved = entry.consecutive_moved,
        last_result = entry.last_result,
        last_source = entry.last_source,
        last_from_x = entry.last_from_x,
        last_from_y = entry.last_from_y,
        classification = classify_seam_entry(map_id, x, y, approach, entry),
    }
end

function M.count_seam_entries(map_id)
    return #collect_seam_entries(map_id)
end

function M.get_seam_summary(map_id)
    return get_seam_summary(map_id)
end

-- format_runtime_blocks(map_id): Return sorted list of "x,y(dirs)" strings.
function M.format_runtime_blocks(map_id)
    local parts = {}
    for _, block in ipairs(collect_runtime_blocks(map_id)) do
        parts[#parts + 1] = block.key .. "(" .. table.concat(block.dir_list, ",") .. ")"
    end
    return parts
end

-- get_runtime_block_entries(map_id): Return sorted runtime block entries.
function M.get_runtime_block_entries(map_id)
    return collect_runtime_blocks(map_id)
end

-- is_cell_runtime_blocked(map_id, x, y): Check if a specific cell has any
-- directional runtime block. Returns false if no block, or a table of
-- blocked directions if any exist.
function M.is_cell_runtime_blocked(map_id, x, y)
    local entry = runtime_blocked[map_id] and runtime_blocked[map_id][cell_key(x, y)]
    if not entry then return false end
    if type(entry) == "table" and next(entry) then return entry end
    return false
end

local function is_fully_blocked_directionally(dirs)
    return dirs and dirs.north and dirs.south and dirs.east and dirs.west
end

-- inject_runtime_block(map_id, x, y): Manually add a runtime blocked tile
-- (blocks all 4 approach directions).
function M.inject_runtime_block(map_id, x, y)
    local k = cell_key(x, y)
    if not runtime_blocked[map_id] then
        runtime_blocked[map_id] = {}
    end
    runtime_blocked[map_id][k] = {north=true, south=true, east=true, west=true}
    debug_tools.info(string.format(
        "runtime block (manual): map=0x%02X cell=(%d,%d) all_dirs",
        map_id, x, y))
    return true
end

function M.inject_runtime_block_for_step(map_id, from_x, from_y, dir, source)
    return add_runtime_block_for_step(map_id, from_x, from_y, dir, source or "manual_edge")
end

-- Compatibility/manual API only. Verifiers and blocked-step observations record
-- seam evidence; they do not call this helper automatically.
function M.confirm_runtime_block_for_step(map_id, from_x, from_y, dir, source)
    return M.inject_runtime_block_for_step(map_id, from_x, from_y, dir, source or "manual_confirmed")
end

function M.clear_runtime_block_for_step(map_id, from_x, from_y, dir, source)
    return clear_runtime_block_for_step(map_id, from_x, from_y, dir, source or "verified_passable")
end

function M.record_seam_result_for_step(map_id, from_x, from_y, dir, result, source)
    if result ~= "blocked" and result ~= "moved" then
        return nil, nil
    end
    return observe_seam_result(map_id, from_x, from_y, dir, result, source or "manual_probe")
end

-- is_pathfinding_walkable(map_id, x, y): Static walkability plus runtime overlay.
function M.is_pathfinding_walkable(map_id, x, y)
    if map_reader.is_walkable(map_id, x, y) ~= true then
        return false
    end
    local runtime_blocked = M.is_cell_runtime_blocked(map_id, x, y)
    if runtime_blocked and is_fully_blocked_directionally(runtime_blocked) then
        return false
    elseif runtime_blocked then
        return true
    end
    return true
end

-- format_runtime_blocks_as_lua(map_id): Return copy-pasteable
-- MAP_DIRECTIONAL_BLOCKS lines for directional blocks.
function M.format_runtime_blocks_as_lua(map_id)
    local entries = collect_runtime_blocks(map_id)
    local lines = {
        string.format("    [0x%02X] = {", map_id),
    }
    for _, block in ipairs(entries) do
        local dir_parts = {}
        for _, d in ipairs(block.dir_list) do
            dir_parts[#dir_parts + 1] = d .. "=true"
        end
        lines[#lines + 1] = string.format('        ["%s"] = {%s},', block.key, table.concat(dir_parts, ", "))
    end
    lines[#lines + 1] = "    },"
    return lines, #entries
end

-- clear_runtime_blocks(map_id_or_all): Clear runtime blocks.
-- Pass a map_id to clear one map, or "all" to clear everything.
function M.clear_runtime_blocks(map_id_or_all)
    if map_id_or_all == "all" then
        local cleared = 0
        for mid in pairs(runtime_blocked) do
            cleared = cleared + M.count_runtime_blocks(mid)
        end
        runtime_blocked = {}
        debug_tools.info(string.format("runtime blocks cleared: scope=all count=%d", cleared))
        return cleared
    else
        local cleared = M.count_runtime_blocks(map_id_or_all)
        runtime_blocked[map_id_or_all] = nil
        debug_tools.info(string.format(
            "runtime blocks cleared: map=0x%02X count=%d",
            map_id_or_all, cleared))
        return cleared
    end
end

function M.clear_seam_memory(map_id_or_all)
    clear_seam_memory(map_id_or_all)
    debug_tools.info(string.format(
        "seam memory cleared: %s",
        map_id_or_all == "all" and "scope=all" or string.format("map=0x%02X", map_id_or_all)))
end

-- ============================================================
-- Path Planning
-- ============================================================

local function get_goal_block_reason(blocking, x, y)
    if not blocking then return nil end
    return blocking[cell_key(x, y)]
end

local function goal_is_out_of_bounds(map_id, goal_x, goal_y)
    if goal_x == nil or goal_y == nil then
        return false
    end
    local width, height = map_reader.get_map_dimensions(map_id)
    if not width or not height then
        return false
    end
    return goal_x < 0 or goal_x >= width or goal_y < 0 or goal_y >= height
end

local function pathfinder_failure_reason(opts)
    local path_opts = opts and (opts.pathfinder_opts or opts)
    if not (path_opts and path_opts._get_stats) then
        return nil
    end
    local stats = path_opts._get_stats()
    if stats and stats.success == false then
        return stats.reason
    end
    return nil
end

local function release_npc_freeze(reason)
    if not npc_freeze_active then
        return
    end
    npc_freeze_active = false
    frozen_npc_snapshot = {}
    if reason then
        debug_tools.info("NPC freeze released: " .. reason)
    end
end

local function release_route_npc_controls(reason)
    release_npc_freeze(reason)
    release_autowalk_npc_parking(reason)
end

local function clear_active_route_context(reason, refresh_objects)
    last_pathfind_obj = nil
    reroute_failures = 0
    route_drift_reroutes = 0
    active_route_settle_frames = 0
    active_route_settle_same_direction = true
    active_route_target = nil
    active_route_face_dir = nil
    active_route_completion_actions = true
    active_route_speak_completion = true
    active_route_total_steps = 0
    active_route_completed_steps = 0
    active_route_allow_hazards = false
    active_route_hazard_stop = nil
    active_route_stop_on_blocker = false
    active_route_npc_mode = "live_npcs"
    active_route_parked_slots = nil
    active_overworld_segment = nil
    active_route_temp_blocks = nil
    release_target_face(reason or "route context cleared")
    clear_seam_retry_state()
    release_route_npc_controls(reason)
    if refresh_objects then
        objects.request_refresh()
    end
end

function M._input_contamination_refusal(command_name, opts)
    if debug_tools.input_contamination_refusal then
        return debug_tools.input_contamination_refusal(command_name, opts)
    end
    if debug_tools.edge_probe_input_refusal then
        return debug_tools.edge_probe_input_refusal(command_name)
    end
    return nil
end

local function input_refusal_opts_for_route_block(block_data, blocked_dir)
    if not block_data or block_data.timing_suspect ~= true then
        return nil
    end
    return {
        allow_route_blocked_self_input = true,
        route_blocked_timing_suspect = true,
        route_blocked_dir = block_data.dir or blocked_dir,
        route_blocked_source = block_data.source,
    }
end

function M._abort_autowalk_if_input_contaminated(command_name, target, source, opts)
    local refusal, details = M._input_contamination_refusal(
        command_name or "auto_walk",
        opts and opts.input_refusal_opts or nil)
    if not refusal then
        return nil
    end
    local target_name = target and target.name or "destination"
    debug_tools.error(refusal)
    debug_tools.info(string.format(
        "AUTO_WALK_ABORT reason=input_contaminated target=%s source=%s %s",
        tostring(target_name),
        tostring(source or "-"),
        tostring(details or "")))
    clear_active_route_context("autowalk input contaminated", should_refresh_objects_after_route())
    if not opts or opts.speak ~= false then
        tolk.output_interrupt("Auto-walk refused. Input contaminated.")
    end
    return {
        status = "input_contaminated",
        ok = false,
        message = refusal,
        target = target,
    }
end

local function use_post_arrival_actions(opts)
    opts = opts or {}
    if opts.post_arrival_actions == false or opts.survey_safe then
        return false
    end
    return true
end

local function set_active_route_context(target, path_len, face_dir, opts)
    opts = opts or {}
    active_route_target = target
    active_route_face_dir = face_dir
    active_route_completion_actions = use_post_arrival_actions(opts)
    active_route_speak_completion = opts.speak ~= false
    active_route_total_steps = tonumber(path_len) or 0
    active_route_completed_steps = 0
    active_route_allow_hazards = opts.allow_hazards == true
    active_route_hazard_stop = opts.hazard_stop
    active_route_stop_on_blocker = opts.stop_on_blocker == true
    active_route_npc_mode = route_npc_mode_from_opts(opts)
    active_route_parked_slots = opts.planning_parked_slots
    active_route_temp_blocks = {}
end

local function update_active_route_remaining(path_len, face_dir, hazard_stop)
    local remaining = tonumber(path_len) or 0
    active_route_total_steps = active_route_completed_steps + remaining
    active_route_face_dir = face_dir
    active_route_hazard_stop = hazard_stop
end

local function add_interaction_point(points, seen, x, y, face_dir, label)
    if x == nil or y == nil then
        return
    end
    local key = tostring(x) .. "," .. tostring(y)
    if seen[key] then
        return
    end
    seen[key] = true
    points[#points + 1] = {
        x = x,
        y = y,
        face_dir = face_dir,
        label = label,
    }
end

local function object_interaction_points(obj)
    local points = {}
    local seen = {}
    if not obj then
        return points
    end

    add_interaction_point(
        points,
        seen,
        obj.interaction_x,
        obj.interaction_y,
        obj.interaction_face_dir,
        obj.interaction_label)

    if type(obj.interaction_points) == "table" then
        for _, point in ipairs(obj.interaction_points) do
            add_interaction_point(
                points,
                seen,
                point.x or point.interaction_x,
                point.y or point.interaction_y,
                point.face_dir or point.interaction_face_dir,
                point.label or point.interaction_label)
        end
    end

    return points
end

local function interaction_point_for_goal(obj, goal_x, goal_y)
    if goal_x == nil or goal_y == nil then
        return nil
    end
    for _, point in ipairs(object_interaction_points(obj)) do
        if point.x == goal_x and point.y == goal_y then
            return point
        end
    end
    return nil
end

local function object_with_interaction(obj, point)
    if not obj or not point then
        return obj
    end
    local next_obj = {}
    for k, v in pairs(obj) do
        next_obj[k] = v
    end
    next_obj.interaction_x = point.x
    next_obj.interaction_y = point.y
    next_obj.interaction_face_dir = point.face_dir
    next_obj.interaction_label = point.label
    next_obj.interaction_points = nil
    return next_obj
end

local function add_selected_interaction_to_opts(opts, point)
    if not point then
        return opts
    end
    local next_opts = copy_opts(opts or {})
    next_opts.interaction_x = point.x
    next_opts.interaction_y = point.y
    next_opts.interaction_face_dir = point.face_dir
    next_opts.interaction_label = point.label
    return next_opts
end

local function get_plan_goal(obj)
    if obj
       and obj.interaction_x ~= nil
       and obj.interaction_y ~= nil then
        return obj.interaction_x, obj.interaction_y, true
    end
    return obj and obj.x or nil, obj and obj.y or nil, false
end

local function get_plan_face_dir(obj, uses_interaction)
    if uses_interaction and obj and obj.interaction_face_dir then
        return obj.interaction_face_dir
    end
    return nil
end

local function should_face_after_plan(plan)
    return plan
       and plan.face_dir ~= nil
       and (plan.path_mode == "adjacent" or plan.interaction_goal == true)
end

local function resolve_path_mode(obj, map_id, opts)
    opts = opts or {}
    local path_mode = opts.path_mode
    local goal_x, goal_y, uses_interaction = get_plan_goal(obj)
    local target_walkable = M.is_pathfinding_walkable(map_id, goal_x, goal_y)
    if path_mode == "direct" or path_mode == "adjacent" then
        return path_mode, target_walkable
    end
    if uses_interaction then
        return "direct", target_walkable
    end
    if opts.survey_safe and (obj.type == objects.TYPE_EXIT or obj.type == objects.TYPE_STAIR) then
        return "adjacent", target_walkable
    end
    if obj.type == objects.TYPE_NPC
    or obj.type == objects.TYPE_DOOR
    or not target_walkable then
        return "adjacent", target_walkable
    end
    return "direct", target_walkable
end

local function resolve_plan_origin(opts)
    local map_id, start_x, start_y = nav.get_position()
    if not opts then
        return map_id, start_x, start_y
    end
    if opts.map_id ~= nil then
        map_id = opts.map_id
    end
    if opts.start_x ~= nil then
        start_x = opts.start_x
    end
    if opts.start_y ~= nil then
        start_y = opts.start_y
    end
    return map_id, start_x, start_y
end

local function try_adjacent_fallback(obj, map_id, start_x, start_y, blocking, opts, current)
    if not opts.allow_adjacent_fallback then
        return current
    end
    if obj.type ~= objects.TYPE_CHEST then
        return current
    end
    if current.path_mode ~= "direct" or current.result ~= "No path found" then
        return current
    end

    local result, face_dir, path, adjacent_diagnostics = pathfinder.pathfind_to_adjacent(
        map_id, start_x, start_y, obj.x, obj.y, blocking, adjacent_path_opts(opts, map_id))
    if result == "No path found" then
        return current
    end

    current.result = result
    current.face_dir = face_dir
    current.path = path
    current.adjacent_diagnostics = adjacent_diagnostics
    current.path_mode = "adjacent"
    current.no_path_reason = "direct_failed_adjacent_fallback"
    return current
end

-- build_pathfind_message(obj, result, face_dir): Create a human-readable
-- message describing the pathfinding result. Includes key count for doors
-- and locked-door hint for unreachable chests.
local function build_pathfind_message(obj, result, face_dir, no_path_reason)
    local msg = obj.name .. ". " .. result
    if face_dir then
        if obj.type == objects.TYPE_DOOR then
            msg = msg .. ". Face " .. face_dir .. " then use Open command"
        else
            msg = msg .. ". Face " .. face_dir
        end
    end
    if obj.type == objects.TYPE_DOOR then
        local key_count = snapshot.keys
        if key_count == 0 then
            msg = msg .. ". No magic keys"
        elseif key_count == 1 then
            msg = msg .. ". 1 magic key"
        else
            msg = msg .. ". " .. key_count .. " magic keys"
        end
    end
    if result == "No path found" and no_path_reason == "closed_door" then
        if snapshot.keys == 0 then
            msg = msg .. ". Route is blocked by a closed door. Get a magic key from a chest, then navigate to a door object and use Open command"
        else
            msg = msg .. ". Route is blocked by a closed door. Navigate to a door object and use Open command first"
        end
        return msg
    end
    if result == "No path found" and no_path_reason == "npc_clutter" then
        msg = msg .. ". Route is currently blocked by NPC movement. Wait for them to move and try again"
        return msg
    end
    if result == "No path found" and no_path_reason == "stationary_npc_blocker" then
        msg = msg .. ". Route may be blocked by a stationary NPC or an out-of-date NPC position. Try again in a moment, or choose another interaction point"
        return msg
    end
    if result == "No path found" and no_path_reason == "goal_out_of_bounds" then
        msg = msg .. ". Target is outside this map"
        return msg
    end
    if obj.type == objects.TYPE_CHEST and result == "No path found" then
        if no_path_reason == "goal_blocked_npc" then
            msg = msg .. ". Chest tile is currently occupied by an NPC. Wait for it to move before auto-walking"
            return msg
        elseif no_path_reason == "goal_blocked_runtime" then
            msg = msg .. ". Route is temporarily blocked by a runtime collision mark"
            return msg
        end
        local terrain = snapshot.terrain_offset
        if terrain == 0x10 then
            msg = msg .. ". Chest may be behind locked door. Navigate to a door object first"
        end
    end
    return msg
end

local function hazard_label(hazard)
    if hazard == "damage" then
        return "damage floor"
    elseif hazard == "poison_swamp" then
        return "poison swamp"
    end
    return tostring(hazard or "dangerous tile")
end

local function plural_word(count, singular, plural)
    if count == 1 then
        return singular
    end
    return plural or (singular .. "s")
end

local function analyze_path_hazards(map_id, path)
    if not path or not map_reader.is_hazard_cell then
        return nil
    end
    local summary = {
        total = 0,
        first_step = nil,
        first_hazard = nil,
        clusters = {},
        counts_by_hazard = {},
    }
    local current = nil
    for i, step in ipairs(path) do
        local hazard = map_reader.is_hazard_cell(map_id, step.x, step.y)
        if hazard then
            summary.total = summary.total + 1
            summary.counts_by_hazard[hazard] = (summary.counts_by_hazard[hazard] or 0) + 1
            if not summary.first_step then
                summary.first_step = i
                summary.first_hazard = hazard
            end
            if current and current.hazard == hazard and current.stop_step == i - 1 then
                current.stop_step = i
                current.tiles = current.tiles + 1
            else
                current = {
                    hazard = hazard,
                    start_step = i,
                    stop_step = i,
                    tiles = 1,
                }
                summary.clusters[#summary.clusters + 1] = current
            end
        else
            current = nil
        end
    end
    if summary.total == 0 then
        return nil
    end
    return summary
end

local function format_hazard_summary(summary)
    if not summary then
        return nil
    end
    local hazard = summary.first_hazard
    local hazard_count = summary.counts_by_hazard[hazard] or summary.total
    return string.format(
        "%s: %d %s, first in %d %s",
        hazard_label(hazard),
        hazard_count,
        plural_word(hazard_count, "tile"),
        summary.first_step or 1,
        plural_word(summary.first_step or 1, "step"))
end

local function append_path_hazard_summary(plan)
    local summary = analyze_path_hazards(plan.map_id, plan.path)
    if not summary then
        return
    end
    plan.hazard_summary = summary
    plan.message = plan.message .. ". " .. format_hazard_summary(summary)
end

local plan_path_to_object

local function try_interaction_alternate_plan(obj, map_id, px, py, blocking, opts, current_plan)
    if not current_plan
       or current_plan.result ~= "No path found"
       or opts._skip_interaction_alternates then
        return current_plan
    end

    local points = object_interaction_points(obj)
    if #points <= 1 then
        return current_plan
    end

    for _, point in ipairs(points) do
        if point.x ~= current_plan.goal_x or point.y ~= current_plan.goal_y then
            local alt_opts = copy_opts(opts)
            alt_opts._skip_interaction_alternates = true
            alt_opts.map_id = map_id
            alt_opts.start_x = px
            alt_opts.start_y = py
            alt_opts.blocking = blocking
            alt_opts.store_debug_path = false

            local alt_plan = plan_path_to_object(object_with_interaction(obj, point), alt_opts)
            if alt_plan and alt_plan.result ~= "No path found" then
                alt_plan.target = obj
                alt_plan.selected_interaction = point
                alt_plan.message = build_pathfind_message(
                    obj,
                    alt_plan.result,
                    alt_plan.face_dir,
                    alt_plan.no_path_reason)
                return alt_plan
            end
        end
    end

    return current_plan
end

local function build_hazard_warning(summary, prefix)
    if not summary then
        return prefix or "Warning."
    end
    return (prefix or "Warning.") .. " Unsafe route crosses " ..
        format_hazard_summary(summary) .. ". Continue manually to enter hazards."
end

local function maybe_use_unsafe_hazard_plan(obj, map_id, opts, plan)
    if not plan
       or plan.result ~= "No path found"
       or opts.allow_hazards == true
       or not plan.unsafe_hazard_summary then
        return plan, opts
    end

    local unsafe_opts = copy_opts(opts)
    unsafe_opts.allow_hazards = true
    unsafe_opts.hazard_preview = false
    unsafe_opts.store_debug_path = false

    local unsafe_plan = plan_path_to_object(obj, unsafe_opts)
    if unsafe_plan
       and unsafe_plan.result ~= "No path found"
       and unsafe_plan.path
       and #unsafe_plan.path > 0 then
        unsafe_plan.message = "Unsafe route. " .. tostring(unsafe_plan.message or "")
        debug_tools.info(string.format(
            "AUTO_WALK_HAZARD_FALLBACK map=0x%02X target_id=%s target_name=%s goal=(%d,%d)",
            map_id or -1,
            tostring(obj.id or "-"),
            tostring(obj.name or "-"),
            obj.x or -1,
            obj.y or -1))
        return unsafe_plan, unsafe_opts
    end

    return plan, opts
end

local function maybe_stop_before_hazard(plan)
    if not plan
       or not plan.path
       or not plan.hazard_summary
       or not plan.hazard_summary.first_step then
        return plan
    end

    local safe_steps = math.max(0, tonumber(plan.hazard_summary.first_step) - 1)
    local trimmed = {}
    for i = 1, safe_steps do
        trimmed[i] = plan.path[i]
    end
    plan.path = trimmed
    plan.hazard_stop = {
        summary = plan.hazard_summary,
        safe_steps = safe_steps,
    }
    return plan
end

local AUTOWALK_EXECUTION_PLAN_CONTEXTS = {
    autowalk_initial = true,
    blocked_step_reroute = true,
    blocked_step_reroute_relaxed = true,
    route_drift_reroute = true,
    seam_retry_followup = true,
    seam_retry_followup_relaxed = true,
    seam_retry_followup_refreshed = true,
}

local function find_tantegel_shrine_risky_x29_descent(plan)
    if not plan
       or plan.map_id ~= TANTEGEL_CASTLE_MAP_ID
       or plan.goal_x ~= TANTEGEL_SHRINE_EXIT_X
       or plan.goal_y ~= TANTEGEL_SHRINE_EXIT_Y
       or plan.path_mode ~= "direct"
       or not plan.path
       or #plan.path == 0 then
        return nil
    end

    local path = plan.path
    local last = path[#path]
    if not last
       or last.x ~= TANTEGEL_SHRINE_EXIT_X
       or last.y ~= TANTEGEL_SHRINE_EXIT_Y then
        return nil
    end

    local suffix_start = nil
    for i = #path, 1, -1 do
        local step = path[i]
        if step
           and step.direction == "south"
           and step.x == TANTEGEL_SHRINE_EXIT_X then
            suffix_start = i
        else
            break
        end
    end

    if not suffix_start then
        return nil
    end

    local first = path[suffix_start]
    local suffix_len = #path - suffix_start + 1
    if suffix_len < TANTEGEL_SHRINE_RISKY_X29_SUFFIX_MIN
       or not first
       or first.y > TANTEGEL_SHRINE_RISKY_X29_ENTRY_MAX_Y then
        return nil
    end

    return {
        suffix_start = suffix_start,
        suffix_len = suffix_len,
        first_dest_x = first.x,
        first_dest_y = first.y,
        block_from_x = first.x,
        block_from_y = first.y - 1,
    }
end

local function maybe_avoid_tantegel_shrine_exit_latch(plan, opts)
    if not plan
       or not opts
       or opts.disable_tantegel_shrine_exit_latch_avoid == true
       or not AUTOWALK_EXECUTION_PLAN_CONTEXTS[plan.plan_context]
       or plan.result == "No path found" then
        return plan
    end

    local risk = find_tantegel_shrine_risky_x29_descent(plan)
    if not risk then
        return plan
    end

    local blocking = copy_blocking_table(plan.blocking)
    local dest_x, dest_y, approach = add_temporary_directional_block(
        blocking,
        risk.block_from_x,
        risk.block_from_y,
        "down")
    if not dest_x or not dest_y or not approach then
        return plan
    end

    local result, face_dir, path = pathfinder.pathfind_to(
        plan.map_id,
        plan.start_x,
        plan.start_y,
        plan.goal_x,
        plan.goal_y,
        blocking,
        pathfinder_opts_for_plan(opts, plan.map_id))

    local replacement = {
        map_id = plan.map_id,
        goal_x = plan.goal_x,
        goal_y = plan.goal_y,
        path_mode = plan.path_mode,
        path = path,
    }
    local replacement_risk = find_tantegel_shrine_risky_x29_descent(replacement)
    if result ~= "No path found" and path and #path > 0 and not replacement_risk then
        debug_tools.info(string.format(
            "AUTO_WALK_FINAL_APPROACH_AVOID map=0x%02X context=%s target_id=%s target_name=%s start=(%d,%d) goal=(%d,%d) blocked_dest=(%d,%d) approach=%s risky_suffix_y=%d risky_suffix_len=%d old_path_len=%d new_path_len=%d",
            plan.map_id or -1,
            tostring(plan.plan_context or "-"),
            tostring(plan.target and plan.target.id or "-"),
            tostring(plan.target and plan.target.name or "-"),
            plan.start_x or -1,
            plan.start_y or -1,
            plan.goal_x or -1,
            plan.goal_y or -1,
            dest_x,
            dest_y,
            tostring(approach),
            risk.first_dest_y or -1,
            risk.suffix_len or -1,
            plan.path and #plan.path or 0,
            #path))
        plan.blocking = blocking
        plan.result = result
        plan.face_dir = face_dir
        plan.path = path
        plan.final_approach_avoid = {
            dest_x = dest_x,
            dest_y = dest_y,
            approach = approach,
            original_suffix_y = risk.first_dest_y,
            original_suffix_len = risk.suffix_len,
        }
    else
        debug_tools.info(string.format(
            "AUTO_WALK_FINAL_APPROACH_AVOID_FAILED map=0x%02X context=%s target_id=%s start=(%d,%d) blocked_dest=(%d,%d) approach=%s result=%s replacement_risky=%s old_path_len=%d new_path_len=%d",
            plan.map_id or -1,
            tostring(plan.plan_context or "-"),
            tostring(plan.target and plan.target.id or "-"),
            plan.start_x or -1,
            plan.start_y or -1,
            dest_x,
            dest_y,
            tostring(approach),
            tostring(result or "-"),
            tostring(replacement_risk ~= nil),
            plan.path and #plan.path or 0,
            path and #path or 0))
    end

    return plan
end

local function face_direction_between(from_x, from_y, to_x, to_y)
    if to_y < from_y then return "north"
    elseif to_y > from_y then return "south"
    elseif to_x > from_x then return "east"
    elseif to_x < from_x then return "west"
    end
    return nil
end

local function is_standable_for_hint(map_id, x, y, blocking)
    if map_reader.is_walkable(map_id, x, y) ~= true then
        return false
    end
    local block = blocking and blocking[cell_key(x, y)]
    return not block or type(block) == "table"
end

local find_quiet_route_to_adjacent
local find_relevant_closed_door_frontier

local function find_stationary_npc_on_path(path)
    if not path then
        return nil
    end
    local stationary_by_cell = {}
    for _, obj in ipairs(objects.get_objects()) do
        if obj.type == objects.TYPE_NPC
        and tonumber(obj.movement) == 0
        and obj.x ~= nil
        and obj.y ~= nil then
            stationary_by_cell[cell_key(obj.x, obj.y)] = obj
        end
    end
    for _, step in ipairs(path) do
        local obj = stationary_by_cell[cell_key(step.x, step.y)]
        if obj then
            return obj
        end
    end
    return nil
end

local function infer_no_path_reason(map_id, start_x, start_y, blocking, obj, path_mode, opts)
    if obj and not (opts and opts.blocking) then
        local goal_x, goal_y = get_plan_goal(obj)
        local npc_free_blocking = M.build_path_blocking(map_id, {skip_npcs = true})
        local npc_free_path = nil
        if path_mode == "adjacent" then
            npc_free_path = find_quiet_route_to_adjacent(
                map_id,
                start_x,
                start_y,
                goal_x,
                goal_y,
                npc_free_blocking,
                opts and opts.pathfinder_opts or nil)
        else
            npc_free_path = pathfinder.find_route_to(
                map_id,
                start_x,
                start_y,
                goal_x,
                goal_y,
                npc_free_blocking,
                opts and opts.pathfinder_opts or nil)
        end
        if npc_free_path then
            local stationary_npc = find_stationary_npc_on_path(npc_free_path)
            if stationary_npc then
                debug_tools.info(string.format(
                    "NO_PATH_STATIONARY_NPC map=0x%02X target=%s blocker=%s id=%s x=%d y=%d",
                    map_id,
                    tostring(obj.name),
                    tostring(stationary_npc.name),
                    tostring(stationary_npc.id),
                    stationary_npc.x or -1,
                    stationary_npc.y or -1))
                return "stationary_npc_blocker"
            end
            return "npc_clutter"
        end
    end
    if find_relevant_closed_door_frontier
       and find_relevant_closed_door_frontier(map_id, start_x, start_y, blocking, obj) then
        return "closed_door"
    end
    return nil
end

function find_quiet_route_to_adjacent(map_id, start_x, start_y, goal_x, goal_y, blocking, opts)
    if goal_is_out_of_bounds(map_id, goal_x, goal_y) then
        return nil, nil
    end

    local adj_tiles = {
        {x = goal_x,     y = goal_y - 1},
        {x = goal_x,     y = goal_y + 1},
        {x = goal_x - 1, y = goal_y    },
        {x = goal_x + 1, y = goal_y    },
    }

    for _, adj in ipairs(adj_tiles) do
        local block = blocking and blocking[cell_key(adj.x, adj.y)]
        if (not block or type(block) == "table")
        and map_reader.is_walkable(map_id, adj.x, adj.y) == true then
            local path = pathfinder.find_route_to(
                map_id, start_x, start_y, adj.x, adj.y, blocking, opts)
            if path then
                return path, face_direction_between(adj.x, adj.y, goal_x, goal_y)
            end
        end
    end

    return nil, nil
end

local function plan_object_reachability(obj, opts)
    if not obj then
        return nil
    end
    opts = opts or {}
    local map_id, px, py = resolve_plan_origin(opts)

    -- On the overworld we intentionally keep object browsing to bearing and
    -- distance. Interior A* is not available or useful there.
    local terrain_offset = snapshot.terrain_offset
    if maps.is_overworld(map_id, terrain_offset) then
        return {
            target = obj,
            map_id = map_id,
            start_x = px,
            start_y = py,
            reachable = nil,
            status = "overworld",
        }
    end

    local blocking = opts.blocking
    if not blocking then
        objects.update_npcs()
        blocking = M.build_path_blocking(map_id, opts.skip_npcs and {skip_npcs = true} or nil)
    end

    local goal_x, goal_y, uses_interaction = get_plan_goal(obj)
    local path_mode, target_walkable = resolve_path_mode(obj, map_id, opts)
    local goal_block_reason = get_goal_block_reason(blocking, goal_x, goal_y)
    local dist = math.abs(px - goal_x) + math.abs(py - goal_y)
    local path = nil
    local face_dir = get_plan_face_dir(obj, uses_interaction)
    local selected_interaction = interaction_point_for_goal(obj, goal_x, goal_y)
    local adjacent_diagnostics = nil
    local no_path_reason = nil

    if path_mode == "adjacent" then
        if dist <= 1 then
            return {
                target = obj,
                map_id = map_id,
                start_x = px,
                start_y = py,
                goal_x = goal_x,
                goal_y = goal_y,
                interaction_goal = uses_interaction,
                path_mode = path_mode,
                target_walkable = target_walkable,
                goal_block_reason = goal_block_reason,
                reachable = true,
                status = "adjacent",
                selected_interaction = selected_interaction,
            }
        end
        path, face_dir = find_quiet_route_to_adjacent(
            map_id, px, py, goal_x, goal_y, blocking, opts.pathfinder_opts)
    else
        if px == goal_x and py == goal_y then
            return {
                target = obj,
                map_id = map_id,
                start_x = px,
                start_y = py,
                goal_x = goal_x,
                goal_y = goal_y,
                interaction_goal = uses_interaction,
                path_mode = path_mode,
                target_walkable = target_walkable,
                goal_block_reason = goal_block_reason,
                reachable = true,
                status = "already_there",
                face_dir = face_dir,
                selected_interaction = selected_interaction,
            }
        elseif goal_block_reason == "npc" then
            no_path_reason = "goal_blocked_npc"
        elseif goal_block_reason == "runtime" then
            no_path_reason = "goal_blocked_runtime"
        else
            path = pathfinder.find_route_to(
                map_id, px, py, goal_x, goal_y, blocking, opts.pathfinder_opts)
        end

        if not path and obj.type == objects.TYPE_CHEST and opts.allow_adjacent_fallback ~= false then
            local fallback_path, fallback_face = find_quiet_route_to_adjacent(
                map_id, px, py, goal_x, goal_y, blocking, opts.pathfinder_opts)
            if fallback_path then
                path = fallback_path
                face_dir = fallback_face
                path_mode = "adjacent"
                no_path_reason = "direct_failed_adjacent_fallback"
            end
        end
    end

    local reachability = {
        target = obj,
        map_id = map_id,
        start_x = px,
        start_y = py,
        goal_x = goal_x,
        goal_y = goal_y,
        interaction_goal = uses_interaction,
        path_mode = path_mode,
        target_walkable = target_walkable,
        goal_block_reason = goal_block_reason,
        no_path_reason = no_path_reason,
        reachable = path ~= nil,
        status = path and "reachable" or "no_path",
        path = path,
        face_dir = face_dir,
        adjacent_diagnostics = adjacent_diagnostics,
        selected_interaction = selected_interaction,
    }

    if reachability.reachable == false and not opts._skip_interaction_alternates then
        local points = object_interaction_points(obj)
        if #points > 1 then
            for _, point in ipairs(points) do
                if point.x ~= goal_x or point.y ~= goal_y then
                    local alt_opts = copy_opts(opts)
                    alt_opts._skip_interaction_alternates = true
                    alt_opts.map_id = map_id
                    alt_opts.start_x = px
                    alt_opts.start_y = py
                    alt_opts.blocking = blocking
                    local alt = plan_object_reachability(object_with_interaction(obj, point), alt_opts)
                    if alt and alt.reachable ~= false then
                        alt.target = obj
                        alt.selected_interaction = point
                        return alt
                    end
                end
            end
        end
    end

    return reachability
end

local function normalize_pathability_filter(filter)
    if type(filter) == "number"
       and filter >= objects.PATHABILITY_ALL
       and filter <= objects.PATHABILITY_UNREACHABLE then
        return filter
    end

    local text = tostring(filter or ""):match("^%s*(.-)%s*$"):lower()
    if text == "" or text == "next" then
        return nil
    end
    if text == "all" then
        return objects.PATHABILITY_ALL
    end
    if text == "reachable" or text == "pathable" or text == "pathible" then
        return objects.PATHABILITY_REACHABLE
    end
    if text == "unreachable" or text == "nonreachable"
       or text == "non-reachable" or text == "blocked" then
        return objects.PATHABILITY_UNREACHABLE
    end
    return nil
end

local function runtime_block_signature(map_id)
    local parts = {}
    for _, entry in ipairs(collect_runtime_blocks(map_id)) do
        parts[#parts + 1] = entry.key .. ":" .. table.concat(entry.dir_list or {}, ",")
    end
    return table.concat(parts, ";")
end

local function object_pathability_context_signature(map_id, start_x, start_y, targets)
    local parts = {
        tostring(map_id),
        tostring(start_x),
        tostring(start_y),
        runtime_block_signature(map_id),
        tostring(#targets),
    }
    for _, obj in ipairs(targets) do
        parts[#parts + 1] = table.concat({
            tostring(obj.id or "-"),
            tostring(obj.type or "-"),
            tostring(obj.x or "-"),
            tostring(obj.y or "-"),
            tostring(obj.interaction_x or "-"),
            tostring(obj.interaction_y or "-"),
        }, ":")
    end
    return table.concat(parts, "|")
end

local function pathability_supported(map_id)
    return not maps.is_overworld(map_id, snapshot.terrain_offset)
end

local function is_blocked_from_approach(blocking, x, y, approach)
    local block = blocking and blocking[cell_key(x, y)]
    if not block then
        return false
    end
    if type(block) == "table" then
        return block[approach] == true
    end
    return true
end

local function is_fully_blocked(blocking, x, y)
    local block = blocking and blocking[cell_key(x, y)]
    if not block then
        return false
    end
    if type(block) ~= "table" then
        return true
    end
    return block.north and block.south and block.east and block.west
end

local function is_static_directional_blocked(directional_blocks, x, y, approach)
    local block = directional_blocks and directional_blocks[cell_key(x, y)]
    return type(block) == "table" and block[approach] == true
end

local function is_walkable_from_snapshot(map_id, x, y, walkability_snapshot, walkability_cache)
    local row = walkability_snapshot and walkability_snapshot[y]
    if row and row[x] ~= nil then
        return row[x] == true
    end
    local key = cell_key(x, y)
    if walkability_cache[key] ~= nil then
        return walkability_cache[key]
    end
    local walkable = map_reader.is_walkable(map_id, x, y) == true
    walkability_cache[key] = walkable
    return walkable
end

local function build_pathability_reachable_set(map_id, start_x, start_y, blocking)
    local width, height = map_reader.get_map_dimensions(map_id)
    if not width or not height then
        return nil
    end
    if start_x < 0 or start_x >= width or start_y < 0 or start_y >= height then
        return nil
    end

    if is_fully_blocked(blocking, start_x, start_y) then
        return {}
    end

    local walkability_snapshot = map_reader.get_walkability_snapshot
        and map_reader.get_walkability_snapshot(map_id)
        or nil
    local walkability_cache = {}
    local directional_blocks = map_reader.get_directional_blocks
        and map_reader.get_directional_blocks(map_id)
        or {}
    local reachable = {}
    local queue = {}
    local function enqueue_reachable(x, y)
        local key = cell_key(x, y)
        if reachable[key] then
            return
        end
        reachable[key] = true
        queue[#queue + 1] = {x = x, y = y}
    end

    if is_walkable_from_snapshot(map_id, start_x, start_y, walkability_snapshot, walkability_cache) then
        enqueue_reachable(start_x, start_y)
    else
        for _, dir in ipairs(PATH_DIRECTIONS) do
            local nx = start_x + dir.dx
            local ny = start_y + dir.dy
            if nx >= 0 and nx < width
            and ny >= 0 and ny < height
            and not is_blocked_from_approach(blocking, nx, ny, dir.approach)
            and not is_static_directional_blocked(directional_blocks, nx, ny, dir.approach)
            and is_walkable_from_snapshot(map_id, nx, ny, walkability_snapshot, walkability_cache) then
                enqueue_reachable(nx, ny)
            end
        end
        if #queue == 0 then
            return {}
        end
    end

    local head = 1

    while head <= #queue do
        local current = queue[head]
        head = head + 1

        for _, dir in ipairs(PATH_DIRECTIONS) do
            local nx = current.x + dir.dx
            local ny = current.y + dir.dy
            local key = cell_key(nx, ny)
            if not reachable[key]
            and nx >= 0 and nx < width
            and ny >= 0 and ny < height
            and not is_blocked_from_approach(blocking, nx, ny, dir.approach)
            and not is_static_directional_blocked(directional_blocks, nx, ny, dir.approach)
            and is_walkable_from_snapshot(map_id, nx, ny, walkability_snapshot, walkability_cache) then
                enqueue_reachable(nx, ny)
            end
        end
    end

    return reachable
end

local function is_reachable_cell(reachable, x, y)
    return reachable and reachable[cell_key(x, y)] == true
end

local function object_reachable_from_set(obj, map_id, start_x, start_y, blocking, reachable)
    local interaction_points = object_interaction_points(obj)
    if #interaction_points > 0 then
        for _, point in ipairs(interaction_points) do
            if start_x == point.x and start_y == point.y then
                return true
            end
            if M.is_pathfinding_walkable(map_id, point.x, point.y)
               and is_reachable_cell(reachable, point.x, point.y) then
                return true
            end
        end
        return false
    end

    local goal_x, goal_y, uses_interaction = get_plan_goal(obj)
    if goal_x == nil or goal_y == nil then
        return nil
    end

    local path_mode, target_walkable = resolve_path_mode(obj, map_id, {
        blocking = blocking,
        skip_npcs = true,
    })
    local dist = math.abs(start_x - goal_x) + math.abs(start_y - goal_y)

    if path_mode == "adjacent" then
        if dist <= 1 then
            return true
        end
        for _, dir in ipairs(PATH_DIRECTIONS) do
            local adj_x = goal_x + dir.dx
            local adj_y = goal_y + dir.dy
            if is_reachable_cell(reachable, adj_x, adj_y) then
                return true
            end
        end
        return false
    end

    if start_x == goal_x and start_y == goal_y then
        return true
    end
    if target_walkable and is_reachable_cell(reachable, goal_x, goal_y) then
        return true
    end
    if obj.type == objects.TYPE_CHEST then
        for _, dir in ipairs(PATH_DIRECTIONS) do
            if is_reachable_cell(reachable, goal_x + dir.dx, goal_y + dir.dy) then
                return true
            end
        end
    end
    return false
end

local function collect_reachable_closed_door_frontiers(map_id, start_x, start_y, blocking)
    if not map_reader.get_map_dimensions or not map_reader.get_walkability_details then
        return {}
    end
    local width, height = map_reader.get_map_dimensions(map_id)
    if not width or not height then
        return {}
    end
    if not is_standable_for_hint(map_id, start_x, start_y, blocking) then
        return {}
    end

    local directional_blocks = map_reader.get_directional_blocks
        and map_reader.get_directional_blocks(map_id)
        or {}
    local queue = {{x = start_x, y = start_y}}
    local seen = {[cell_key(start_x, start_y)] = true}
    local frontiers = {}
    local head = 1

    while head <= #queue do
        local current = queue[head]
        head = head + 1

        for _, dir in ipairs(PATH_DIRECTIONS) do
            local nx = current.x + dir.dx
            local ny = current.y + dir.dy
            local nk = cell_key(nx, ny)
            if not seen[nk]
            and nx >= 0 and nx < width
            and ny >= 0 and ny < height
            and not is_blocked_from_approach(blocking, nx, ny, dir.approach)
            and not is_static_directional_blocked(directional_blocks, nx, ny, dir.approach) then
                local details = map_reader.get_walkability_details(map_id, nx, ny)
                if details and details.reason == "door_closed" then
                    seen[nk] = true
                    frontiers[#frontiers + 1] = {x = nx, y = ny}
                elseif is_standable_for_hint(map_id, nx, ny, blocking) then
                    seen[nk] = true
                    queue[#queue + 1] = {x = nx, y = ny}
                end
            end
        end
    end

    return frontiers
end

local function build_reachable_set_with_open_doors(map_id, start_x, start_y, blocking, open_door_keys)
    local width, height = map_reader.get_map_dimensions(map_id)
    if not width or not height then
        return nil
    end
    if start_x < 0 or start_x >= width or start_y < 0 or start_y >= height then
        return nil
    end
    if not is_standable_for_hint(map_id, start_x, start_y, blocking) then
        return {}
    end

    local directional_blocks = map_reader.get_directional_blocks
        and map_reader.get_directional_blocks(map_id)
        or {}
    local reachable = {[cell_key(start_x, start_y)] = true}
    local queue = {{x = start_x, y = start_y}}
    local head = 1

    while head <= #queue do
        local current = queue[head]
        head = head + 1

        for _, dir in ipairs(PATH_DIRECTIONS) do
            local nx = current.x + dir.dx
            local ny = current.y + dir.dy
            local nk = cell_key(nx, ny)
            if not reachable[nk]
            and nx >= 0 and nx < width
            and ny >= 0 and ny < height
            and not is_blocked_from_approach(blocking, nx, ny, dir.approach)
            and not is_static_directional_blocked(directional_blocks, nx, ny, dir.approach) then
                local opened_for_hint = open_door_keys and open_door_keys[nk] == true
                if opened_for_hint or is_standable_for_hint(map_id, nx, ny, blocking) then
                    reachable[nk] = true
                    queue[#queue + 1] = {x = nx, y = ny}
                end
            end
        end
    end

    return reachable
end

find_relevant_closed_door_frontier = function(map_id, start_x, start_y, blocking, obj)
    local frontiers = collect_reachable_closed_door_frontiers(map_id, start_x, start_y, blocking)
    if #frontiers == 0 then
        return nil
    end
    if not obj then
        return frontiers[1]
    end

    local open_door_keys = {}
    for _, door in ipairs(frontiers) do
        open_door_keys[cell_key(door.x, door.y)] = true
    end

    local reachable = build_reachable_set_with_open_doors(
        map_id,
        start_x,
        start_y,
        blocking,
        open_door_keys)
    if object_reachable_from_set(obj, map_id, start_x, start_y, blocking, reachable) then
        return frontiers[1]
    end
    return nil
end

function M.refresh_object_pathability_filter(opts)
    opts = opts or {}
    if not opts.force and not objects.is_pathability_filter_active() then
        return {
            name = objects.get_filter_summary(),
            pathability_name = objects.get_pathability_filter_name(),
            count = objects.get_count(),
            active = false,
            refreshed = false,
        }
    end

    local map_id, start_x, start_y = resolve_plan_origin(opts)
    if not pathability_supported(map_id) then
        object_pathability_signature = nil
        last_pathability_result = nil
        objects.clear_pathability_statuses()
        objects.set_pathability_filter(objects.PATHABILITY_ALL)
        return {
            name = objects.get_filter_summary(),
            pathability_name = objects.get_pathability_filter_name(),
            count = objects.get_count(),
            active = false,
            unavailable = true,
            refreshed = false,
        }
    end

    local targets = objects.get_objects()
    local signature = object_pathability_context_signature(map_id, start_x, start_y, targets)
    if not opts.force and signature == object_pathability_signature then
        return {
            name = objects.get_filter_summary(),
            pathability_name = objects.get_pathability_filter_name(),
            count = objects.get_count(),
            active = objects.is_pathability_filter_active(),
            refreshed = false,
        }
    end

    local started = os.clock()
    local statuses = {}
    local reachable = 0
    local unreachable = 0
    local blocking = M.build_path_blocking(map_id, {skip_npcs = true})
    local reachable_cells = build_pathability_reachable_set(map_id, start_x, start_y, blocking)
    for _, obj in ipairs(targets) do
        local is_reachable = nil
        if reachable_cells ~= nil then
            is_reachable = object_reachable_from_set(obj, map_id, start_x, start_y, blocking, reachable_cells)
        else
            local reachability = plan_object_reachability(obj, {
                map_id = map_id,
                start_x = start_x,
                start_y = start_y,
                blocking = blocking,
                skip_npcs = true,
                store_debug_path = false,
            })
            is_reachable = reachability and reachability.reachable
        end

        if is_reachable == true then
            if obj.id then
                statuses[obj.id] = true
            end
            reachable = reachable + 1
        elseif is_reachable == false then
            if obj.id then
                statuses[obj.id] = false
            end
            unreachable = unreachable + 1
        end
    end

    objects.set_pathability_statuses(statuses)
    object_pathability_signature = signature

    local elapsed_ms = (os.clock() - started) * 1000
    if elapsed_ms >= 25 then
        debug_tools.info(string.format(
            "OBJECT_PATHABILITY_TIMING map=0x%02X start=(%d,%d) targets=%d reachable=%d unreachable=%d ms=%.3f",
            map_id,
            start_x,
            start_y,
            #targets,
            reachable,
            unreachable,
            elapsed_ms))
    end

    last_pathability_result = {
        name = objects.get_filter_summary(),
        pathability_name = objects.get_pathability_filter_name(),
        count = objects.get_count(),
        active = objects.is_pathability_filter_active(),
        refreshed = true,
        total = #targets,
        reachable = reachable,
        unreachable = unreachable,
    }
    return last_pathability_result
end

function M.refresh_object_pathability_filter_if_needed()
    return M.refresh_object_pathability_filter({force = false})
end

function M.set_object_pathability_filter(filter)
    local mode = normalize_pathability_filter(filter)
    if not mode then
        return nil, "pathability_filter usage: pathability_filter, pathability_filter:all, pathability_filter:reachable, pathability_filter:unreachable, or pathability_filter:refresh"
    end

    if mode == objects.PATHABILITY_ALL then
        object_pathability_signature = nil
        last_pathability_result = nil
        objects.set_pathability_filter(objects.PATHABILITY_ALL)
        return {
            name = objects.get_filter_summary(),
            pathability_name = objects.get_pathability_filter_name(),
            count = objects.get_count(),
            active = false,
        }
    end

    local refresh = M.refresh_object_pathability_filter({force = true})
    if refresh and refresh.unavailable then
        return refresh
    end
    objects.set_pathability_filter(mode)
    return {
        name = objects.get_filter_summary(),
        pathability_name = objects.get_pathability_filter_name(),
        count = objects.get_count(),
        active = true,
        refreshed = refresh and refresh.refreshed,
        total = refresh and refresh.total,
        reachable = refresh and refresh.reachable,
        unreachable = refresh and refresh.unreachable,
    }
end

function M.next_object_pathability_filter()
    local current = objects.get_pathability_filter()
    local next_filter = current + 1
    if next_filter > objects.PATHABILITY_UNREACHABLE then
        next_filter = objects.PATHABILITY_ALL
    end
    return M.set_object_pathability_filter(next_filter)
end

function M.object_reachability(obj, opts)
    return plan_object_reachability(obj, opts)
end

function M.describe_object_with_reachability(obj, base_description, opts)
    opts = opts or {}
    if not obj then
        return base_description or "No objects found"
    end
    local desc = base_description or objects.describe_object(obj)
    if opts.include_reachability == false
       or (opts.include_reachability == nil
           and emulator_compat.is_bizhawk == true
           and config.get("bizhawk_object_reachability_descriptions") ~= "true") then
        return desc
    end
    local reachability = plan_object_reachability(obj, opts)
    if not base_description and reachability and reachability.selected_interaction then
        desc = objects.describe_object(
            object_with_interaction(obj, reachability.selected_interaction))
    end
    if reachability and reachability.reachable == false then
        return desc .. ". Not currently reachable"
    end
    return desc
end

function M.describe_current_object(opts)
    opts = opts or {}
    local obj = objects.current_object()
    if not obj then
        return "No objects found"
    end
    if opts.include_reachability == false
       or (opts.include_reachability == nil
           and emulator_compat.is_bizhawk == true
           and config.get("bizhawk_object_reachability_descriptions") ~= "true") then
        return objects.describe_current(opts)
    end

    local reachability = plan_object_reachability(obj, opts)
    local desc_opts = add_selected_interaction_to_opts(opts, reachability and reachability.selected_interaction)
    local desc = objects.describe_current(desc_opts)
    if reachability and reachability.reachable == false then
        return desc .. ". Not currently reachable"
    end
    return desc
end

-- plan_path_to_object(obj): Compute a path from the player to the given
-- object. Returns (result, face_dir, path, message, map_id).
plan_path_to_object = function(obj, opts)
    opts = route_planning_opts(opts or nil)
    refresh_navigation_modules()
    local plan_start_clock = os.clock()
    local map_id, px, py = resolve_plan_origin(opts)
    -- `survey_safe` is used by map_survey for classification/retry behavior,
    -- but the actual movement plan must still respect frozen NPC blockers.
    -- Callers that truly want an NPC-free blocking table must opt in with
    -- skip_npcs=true explicitly.
    local skip_npcs = opts.skip_npcs
    local blocking = opts.blocking
    local npc_mode = route_npc_mode_from_opts(opts)
    local parked_slots = opts.planning_parked_slots
    if not blocking then
        -- Only refresh NPCs when we're about to rebuild blocking from live state.
        -- Preview callers that pass a precomputed blocking table already encode
        -- the NPC snapshot they want.
        blocking, npc_mode, parked_slots = prepare_route_planning_blocking(map_id, opts)
    end
    local goal_x, goal_y, uses_interaction = get_plan_goal(obj)
    local path_mode, target_walkable = resolve_path_mode(obj, map_id, opts)
    local result, face_dir, path, adjacent_diagnostics
    local no_path_reason = nil
    local goal_block_reason = get_goal_block_reason(blocking, goal_x, goal_y)
    local selected_interaction = interaction_point_for_goal(obj, goal_x, goal_y)
    if path_mode == "adjacent" then
        result, face_dir, path, adjacent_diagnostics = pathfinder.pathfind_to_adjacent(
            map_id, px, py, goal_x, goal_y, blocking, adjacent_path_opts(opts, map_id))
    else
        if goal_block_reason == "npc" then
            result, face_dir, path = "No path found", nil, nil
            no_path_reason = "goal_blocked_npc"
        elseif goal_block_reason == "runtime" then
            result, face_dir, path = "No path found", nil, nil
            no_path_reason = "goal_blocked_runtime"
        else
            result, face_dir, path = pathfinder.pathfind_to(
                map_id,
                px,
                py,
                goal_x,
                goal_y,
                blocking,
                pathfinder_opts_for_plan(opts, map_id))
            if uses_interaction and path then
                face_dir = get_plan_face_dir(obj, uses_interaction) or face_dir
            end
        end
    end
    if result == "No path found" and no_path_reason == nil then
        no_path_reason = pathfinder_failure_reason(opts)
    end
    if result == "No path found" and no_path_reason == nil then
        no_path_reason = infer_no_path_reason(map_id, px, py, blocking, obj, path_mode, opts)
    end
    local plan = {
        target = obj,
        map_id = map_id,
        start_x = px,
        start_y = py,
        goal_x = goal_x,
        goal_y = goal_y,
        interaction_goal = uses_interaction,
        path_mode = path_mode,
        target_walkable = target_walkable,
        goal_block_reason = goal_block_reason,
        no_path_reason = no_path_reason,
        blocking = blocking,
        npc_mode = npc_mode,
        parked_slots = parked_slots,
        plan_context = opts.plan_context,
        result = result,
        face_dir = face_dir,
        path = path,
        adjacent_diagnostics = adjacent_diagnostics,
        selected_interaction = selected_interaction,
        message = build_pathfind_message(obj, result, face_dir, no_path_reason),
    }
    plan = try_interaction_alternate_plan(obj, map_id, px, py, blocking, opts, plan)
    plan = try_adjacent_fallback(obj, map_id, px, py, blocking, opts, plan)
    plan = maybe_avoid_tantegel_shrine_exit_latch(plan, opts)
    plan.message = build_pathfind_message(obj, plan.result, plan.face_dir, plan.no_path_reason)
    append_path_hazard_summary(plan)
    if opts.hazard_preview == true
       and opts.allow_hazards ~= true
       and plan.result == "No path found" then
        local unsafe_opts = copy_opts(opts)
        unsafe_opts.map_id = map_id
        unsafe_opts.start_x = px
        unsafe_opts.start_y = py
        unsafe_opts.blocking = blocking
        unsafe_opts.allow_hazards = true
        unsafe_opts.hazard_preview = false
        unsafe_opts.store_debug_path = false
        local unsafe_plan = plan_path_to_object(obj, unsafe_opts)
        local unsafe_summary = unsafe_plan and analyze_path_hazards(map_id, unsafe_plan.path)
        if unsafe_summary then
            plan.unsafe_hazard_summary = unsafe_summary
            plan.unsafe_path = unsafe_plan.path
            plan.unsafe_result = unsafe_plan.result
            plan.unsafe_face_dir = unsafe_plan.face_dir
            plan.unsafe_no_path_reason = unsafe_plan.no_path_reason
            plan.message = build_pathfind_message(
                obj,
                unsafe_plan.result,
                unsafe_plan.face_dir,
                unsafe_plan.no_path_reason) .. ". " ..
                build_hazard_warning(unsafe_summary, "Warning. No safe route.")
        end
    end
    -- Store path for debug recall (trace_path, validate_path, etc.)
    if debug_tools.DEBUG_MODE and opts.store_debug_path ~= false then
        path_debug.store_path(map_id, px, py, plan.goal_x, plan.goal_y, plan.path, nil)
    end
    log_route_planning_snapshot(plan)
    log_route_plan_timing(plan, (os.clock() - plan_start_clock) * 1000)
    return plan
end

function M.plan_path_to_object(obj, opts)
    if not obj then return nil end
    return plan_path_to_object(obj, opts)
end

function M.plan_path_to_coordinates(goal_x, goal_y, opts)
    opts = opts or {}
    local target = {
        id = string.format("coord_%s_%s", tostring(goal_x), tostring(goal_y)),
        name = opts.name or string.format("Coordinate %s,%s", tostring(goal_x), tostring(goal_y)),
        type = opts.target_type or "coordinate",
        x = goal_x,
        y = goal_y,
    }
    if opts.interaction_x ~= nil and opts.interaction_y ~= nil then
        target.interaction_x = opts.interaction_x
        target.interaction_y = opts.interaction_y
        target.interaction_face_dir = opts.interaction_face_dir
    end

    local parked = false
    local parked_slots = nil
    if opts.park_mobile_npcs == true then
        parked_slots = start_autowalk_npc_parking(target, opts)
        parked = true
    end

    opts = route_planning_opts(opts, nil, "coordinate_plan")
    opts.planning_parked_slots = parked_slots
    local plan = plan_path_to_object(target, opts)
    if plan then
        plan.coordinate_target = true
    end

    if parked then
        release_autowalk_npc_parking("coordinate debug plan complete")
    end
    return plan
end

-- Find a decoded-safe path from the current world-map position to an exact
-- waypoint-network cell. If poison swamp is unavoidable, retain a manual-only
-- preview with an explicit hazard warning. This planner remains read-only:
-- executable recovery consumes its safe result separately without changing
-- preview command semantics.
function M._overworld_recovery_distance_field(
    map_id, start_x, start_y, blocking, walkability_snapshot)
    local width, height = map_reader.get_map_dimensions(map_id)
    if not width or not height or not walkability_snapshot then
        return {}, 0
    end
    local directional_blocks = map_reader.get_directional_blocks
        and map_reader.get_directional_blocks(map_id) or {}
    local distances = {[cell_key(start_x, start_y)] = 0}
    local queue = {{x = start_x, y = start_y}}
    local head = 1
    local visited = 0

    local function is_walkable(x, y)
        local row = walkability_snapshot[y]
        return row and row[x] == true
    end
    local function blocks_entry(x, y, approach)
        local key = cell_key(x, y)
        local dynamic = blocking and blocking[key]
        if dynamic and type(dynamic) ~= "table" then
            return true
        end
        if type(dynamic) == "table" and dynamic[approach] == true then
            return true
        end
        local static = directional_blocks[key]
        return type(static) == "table" and static[approach] == true
    end

    while queue[head] do
        local cell = queue[head]
        head = head + 1
        visited = visited + 1
        local current_distance = distances[cell_key(cell.x, cell.y)]
        for _, step in ipairs(PATH_DIRECTIONS) do
            local nx = cell.x + step.dx
            local ny = cell.y + step.dy
            local key = cell_key(nx, ny)
            if nx >= 0 and nx < width and ny >= 0 and ny < height
               and distances[key] == nil
               and is_walkable(nx, ny)
               and not blocks_entry(nx, ny, step.approach) then
                distances[key] = current_distance + 1
                queue[#queue + 1] = {x = nx, y = ny}
            end
        end
    end
    return distances, visited
end

function M.preview_overworld_network_entry(opts)
    opts = opts or {}
    local preview_started = os.clock()
    local function candidate_distance(px, py, candidate)
        return math.abs(px - candidate.x) + math.abs(py - candidate.y)
    end
    local function log_preview(result)
        local timing = result.search_timing
        if timing then
            debug_tools.info(string.format(
                "OVERWORLD_RECOVERY_SEARCH_TIMING route=%s method=single_field candidates=%d pathfind_calls=%d safe_nodes=%d hazard_nodes=%d candidate_ms=%.3f snapshot_ms=%.3f safe_field_ms=%.3f safe_astar_ms=%.3f hazard_field_ms=%.3f hazard_astar_ms=%.3f total_ms=%.3f fallback=%s",
                tostring(result.final_destination_id or "-"),
                tonumber(result.candidate_count) or 0,
                tonumber(timing.pathfind_calls) or 0,
                tonumber(timing.safe_nodes) or 0,
                tonumber(timing.hazard_nodes) or 0,
                tonumber(timing.candidate_ms) or 0,
                tonumber(timing.snapshot_ms) or 0,
                tonumber(timing.safe_field_ms) or 0,
                tonumber(timing.safe_astar_ms) or 0,
                tonumber(timing.hazard_field_ms) or 0,
                tonumber(timing.hazard_astar_ms) or 0,
                tonumber(timing.total_ms) or 0,
                tostring(timing.fallback == true)))
        end
        debug_tools.info(string.format(
            "OVERWORLD_RECOVERY_PREVIEW status=%s map=0x%02X from=(%s,%s) entry=(%s,%s) path_len=%s route=%s next=%s final=%s candidates=%d rejected_opening=%d rejected_unreachable=%d skipped_farther=%d hazardous=%s hazard_tiles=%d hazard_first_step=%s rejected_safe_unreachable=%d preview_only=true",
            tostring(result.status or "unknown"),
            result.map_id or -1,
            tostring(result.start_x),
            tostring(result.start_y),
            tostring(result.entry_x or "-"),
            tostring(result.entry_y or "-"),
            tostring(result.path_length or "-"),
            tostring(result.route_id or "-"),
            tostring(result.next_waypoint_name or "-"),
            tostring(result.final_destination_id or "-"),
            tonumber(result.candidate_count) or 0,
            tonumber(result.rejected_opening) or 0,
            tonumber(result.rejected_unreachable) or 0,
            tonumber(result.skipped_farther) or 0,
            tostring(result.requires_manual_hazard_crossing == true),
            tonumber(result.hazard_summary and result.hazard_summary.total) or 0,
            tostring(result.hazard_summary and result.hazard_summary.first_step or "-"),
            tonumber(result.rejected_safe_unreachable) or 0))
    end
    local map_id, px, py = resolve_plan_origin(opts)
    local terrain_offset = opts.terrain_offset
    if terrain_offset == nil then
        terrain_offset = snapshot.terrain_offset
    end
    if not maps.is_overworld(map_id, terrain_offset) then
        local result = {
            status = "not_overworld",
            ok = false,
            preview_only = true,
            map_id = map_id,
            start_x = px,
            start_y = py,
            candidate_count = 0,
            rejected_opening = 0,
            rejected_unreachable = 0,
            skipped_farther = 0,
            message = "Overworld recovery preview is only available on the world map",
        }
        log_preview(result)
        return result
    end

    local destination = overworld_routes.active_destination()
    if not destination then
        local result = {
            status = "no_active_route",
            ok = false,
            preview_only = true,
            map_id = map_id,
            start_x = px,
            start_y = py,
            candidate_count = 0,
            rejected_opening = 0,
            rejected_unreachable = 0,
            skipped_farther = 0,
            message = "No overworld route active. Select a Travel destination first.",
        }
        log_preview(result)
        return result
    end

    local candidate_started = os.clock()
    local candidates = overworld_routes.network_entry_candidates(
        destination.id, map_id, {terrain_offset = terrain_offset})
    local candidate_ms = (os.clock() - candidate_started) * 1000
    local snapshot_started = os.clock()
    local safe_snapshot = map_reader.get_walkability_snapshot
        and map_reader.get_walkability_snapshot(map_id) or nil
    local snapshot_ms = (os.clock() - snapshot_started) * 1000
    if not safe_snapshot then
        local result = {
            status = "walkability_unavailable",
            ok = false,
            preview_only = true,
            map_id = map_id,
            start_x = px,
            start_y = py,
            final_destination_id = destination.id,
            candidate_count = #candidates,
            rejected_opening = 0,
            rejected_unreachable = 0,
            skipped_farther = 0,
            message = "Overworld recovery preview refused because decoded walkability is unavailable",
        }
        log_preview(result)
        return result
    end

    table.sort(candidates, function(a, b)
        local ad = candidate_distance(px, py, a)
        local bd = candidate_distance(px, py, b)
        if ad ~= bd then return ad < bd end
        if a.y ~= b.y then return a.y < b.y end
        if a.x ~= b.x then return a.x < b.x end
        return tostring(a.name) < tostring(b.name)
    end)

    local planning_opts = route_planning_opts(opts, nil, "overworld_recovery_preview")
    planning_opts.terrain_offset = terrain_offset
    local blocking = planning_opts.blocking
    if not blocking then
        blocking = prepare_route_planning_blocking(map_id, planning_opts)
    else
        blocking = copy_blocking_table(blocking)
    end
    for _, cell in ipairs(overworld_routes.network_transition_cells()) do
        if cell.x ~= px or cell.y ~= py then
            blocking[cell_key(cell.x, cell.y)] = true
        end
    end

    local max_opening_steps = tonumber(opts.max_opening_steps) or 24
    local function legacy_search_candidates(walkability_snapshot)
        local search = {
            best = nil,
            rejected_opening = 0,
            rejected_unreachable = 0,
            skipped_farther = 0,
            pathfind_calls = 0,
        }
        for index, candidate in ipairs(candidates) do
            local lower_bound = candidate_distance(px, py, candidate)
            if search.best and lower_bound > #search.best.path then
                search.skipped_farther = search.skipped_farther + (#candidates - index + 1)
                break
            elseif (tonumber(candidate.opening_length) or math.huge)
                    > max_opening_steps then
                search.rejected_opening = search.rejected_opening + 1
            else
                search.pathfind_calls = search.pathfind_calls + 1
                local result, _, path = pathfinder.pathfind_to(
                    map_id,
                    px,
                    py,
                    candidate.x,
                    candidate.y,
                    blocking,
                    {
                        allow_overworld = true,
                        walkability_snapshot = walkability_snapshot,
                    })
                if path then
                    if not search.best or #path < #search.best.path then
                        search.best = {
                            candidate = candidate,
                            path = path,
                            path_result = result,
                        }
                    end
                else
                    search.rejected_unreachable = search.rejected_unreachable + 1
                end
            end
        end
        return search
    end


    local function search_candidates(walkability_snapshot)
        local field_started = os.clock()
        local distances, nodes = M._overworld_recovery_distance_field(
            map_id, px, py, blocking, walkability_snapshot)
        local field_ms = (os.clock() - field_started) * 1000
        local search = {
            best = nil,
            rejected_opening = 0,
            rejected_unreachable = 0,
            skipped_farther = 0,
            pathfind_calls = 0,
            nodes = nodes,
            field_ms = field_ms,
            astar_ms = 0,
            fallback = false,
        }
        local selected = nil
        for index, candidate in ipairs(candidates) do
            local lower_bound = candidate_distance(px, py, candidate)
            if selected and lower_bound > selected.distance then
                search.skipped_farther = search.skipped_farther
                    + (#candidates - index + 1)
                break
            elseif (tonumber(candidate.opening_length) or math.huge)
                    > max_opening_steps then
                search.rejected_opening = search.rejected_opening + 1
            else
                local distance = distances[cell_key(candidate.x, candidate.y)]
                if distance == nil then
                    search.rejected_unreachable = search.rejected_unreachable + 1
                elseif not selected or distance < selected.distance then
                    selected = {candidate = candidate, distance = distance}
                end
            end
        end

        if selected then
            local astar_started = os.clock()
            search.pathfind_calls = 1
            local result, _, path = pathfinder.pathfind_to(
                map_id,
                px,
                py,
                selected.candidate.x,
                selected.candidate.y,
                blocking,
                {
                    allow_overworld = true,
                    walkability_snapshot = walkability_snapshot,
                })
            search.astar_ms = (os.clock() - astar_started) * 1000
            if path and #path == selected.distance then
                search.best = {
                    candidate = selected.candidate,
                    path = path,
                    path_result = result,
                }
            else
                -- Fail safely if the lightweight field ever disagrees with
                -- A*. The legacy search is slower, but preserves behavior for
                -- an unexpected pathfinding rule until it can be diagnosed.
                local legacy = legacy_search_candidates(walkability_snapshot)
                legacy.nodes = nodes
                legacy.field_ms = field_ms
                legacy.astar_ms = search.astar_ms
                legacy.pathfind_calls = legacy.pathfind_calls + 1
                legacy.fallback = true
                debug_tools.info(string.format(
                    "OVERWORLD_RECOVERY_SEARCH_FALLBACK route=%s selected=(%d,%d) field_distance=%s astar_distance=%s",
                    tostring(destination.id),
                    selected.candidate.x,
                    selected.candidate.y,
                    tostring(selected.distance),
                    tostring(path and #path or "unreachable")))
                return legacy
            end
        end
        return search
    end

    local safe_search = search_candidates(safe_snapshot)
    local selected_search = safe_search
    local best = safe_search.best
    local hazard_summary = nil
    local requires_manual_hazard_crossing = false

    -- A few required overworld approaches cross poison swamp. Prefer every
    -- decoded-safe alternative first, then retain a warned manual preview when
    -- the only reachable network entry crosses modeled hazards.
    if not best then
        local hazard_snapshot = map_reader.get_walkability_snapshot(map_id, {
            allow_hazards = true,
        })
        if hazard_snapshot then
            local hazard_search = search_candidates(hazard_snapshot)
            local candidate_summary = hazard_search.best
                and analyze_path_hazards(map_id, hazard_search.best.path)
                or nil
            if candidate_summary then
                selected_search = hazard_search
                best = hazard_search.best
                hazard_summary = candidate_summary
                requires_manual_hazard_crossing = true
            end
        end
    end

    local search_timing = {
        candidate_ms = candidate_ms,
        snapshot_ms = snapshot_ms,
        safe_nodes = safe_search.nodes or 0,
        hazard_nodes = selected_search ~= safe_search
            and (selected_search.nodes or 0) or 0,
        safe_field_ms = safe_search.field_ms or 0,
        safe_astar_ms = safe_search.astar_ms or 0,
        hazard_field_ms = selected_search ~= safe_search
            and (selected_search.field_ms or 0) or 0,
        hazard_astar_ms = selected_search ~= safe_search
            and (selected_search.astar_ms or 0) or 0,
        pathfind_calls = (safe_search.pathfind_calls or 0)
            + (selected_search ~= safe_search and selected_search.pathfind_calls or 0),
        fallback = safe_search.fallback == true
            or selected_search.fallback == true,
        total_ms = (os.clock() - preview_started) * 1000,
    }

    local rejected_opening = selected_search.rejected_opening
    local rejected_unreachable = selected_search.rejected_unreachable
    local skipped_farther = selected_search.skipped_farther

    if not best then
        local result = {
            status = "no_safe_entry",
            ok = false,
            preview_only = true,
            map_id = map_id,
            start_x = px,
            start_y = py,
            final_destination_id = destination.id,
            final_destination_title = destination.title,
            candidate_count = #candidates,
            rejected_opening = rejected_opening,
            rejected_unreachable = rejected_unreachable,
            skipped_farther = skipped_farther,
            search_timing = search_timing,
            message = string.format(
                "No decoded-safe waypoint-network entry is reachable for %s",
                tostring(destination.title)),
        }
        log_preview(result)
        return result
    end

    local candidate = best.candidate
    local next_waypoint = candidate.next_waypoint
    local path_description = pathfinder.format_path(best.path)
    local status = requires_manual_hazard_crossing and "planned_with_hazard"
        or (#best.path == 0 and "already_on_network" or "planned")
    local entry_safety = requires_manual_hazard_crossing and "Network entry" or "Safe network entry"
    local warning = requires_manual_hazard_crossing
        and (" " .. build_hazard_warning(
            hazard_summary,
            "Warning. No decoded-safe recovery path is available."))
        or ""
    local message = string.format(
        "Recovery preview. Final destination: %s. %s: %s at %d,%d. %s.%s Then current leg to %s. Next: %s. Preview only; no movement started.",
        tostring(destination.title),
        entry_safety,
        tostring(candidate.name or "waypoint"),
        candidate.x,
        candidate.y,
        path_description,
        warning,
        tostring(candidate.route_title or "waypoint network"),
        tostring(next_waypoint and next_waypoint.name or "route handoff"))
    local result = {
        status = status,
        ok = true,
        preview_only = true,
        map_id = map_id,
        start_x = px,
        start_y = py,
        entry_x = candidate.x,
        entry_y = candidate.y,
        entry_name = candidate.name,
        path = best.path,
        path_length = #best.path,
        path_description = path_description,
        route_id = candidate.route_id,
        route_title = candidate.route_title,
        next_waypoint_name = next_waypoint and next_waypoint.name or nil,
        final_destination_id = destination.id,
        final_destination_title = destination.title,
        candidate_count = #candidates,
        rejected_opening = rejected_opening,
        rejected_unreachable = rejected_unreachable,
        skipped_farther = skipped_farther,
        rejected_safe_unreachable = requires_manual_hazard_crossing
            and safe_search.rejected_unreachable or 0,
        hazard_summary = hazard_summary,
        decoded_safe = not requires_manual_hazard_crossing,
        auto_walk_allowed = not requires_manual_hazard_crossing,
        requires_manual_hazard_crossing = requires_manual_hazard_crossing,
        search_timing = search_timing,
        message = message,
    }
    log_preview(result)
    return result
end

-- Audit decoded overworld recovery coverage for one Travel destination. This
-- is deliberately read-only and ignores transient NPC/runtime blockers: it
-- measures the stable map geometry that the recovery planner can rely on.
-- Distances are computed backwards from all eligible network entries so a
-- full 120x120 map costs two breadth-first passes instead of one A* per cell.
function M.audit_overworld_recovery_coverage(route_name, opts)
    opts = opts or {}

    local destination = route_name
    if destination == nil or destination == "" then
        local active = overworld_routes.active_destination()
        destination = active and active.id or nil
    end
    if destination == nil then
        local result = {
            status = "no_destination",
            ok = false,
            message = "Recovery coverage audit needs a Travel destination",
        }
        debug_tools.info("OVERWORLD_RECOVERY_AUDIT status=no_destination")
        return result
    end

    local map_id = tonumber(opts.map_id)
    if map_id == nil then
        map_id = select(1, resolve_plan_origin(opts))
    end
    local terrain_offset = opts.terrain_offset
    if terrain_offset == nil then
        terrain_offset = snapshot.terrain_offset
    end
    if not maps.is_overworld(map_id, terrain_offset) then
        local result = {
            status = "not_overworld",
            ok = false,
            route_id = destination,
            map_id = map_id,
            message = "Recovery coverage audit is only available for the world map",
        }
        debug_tools.info(string.format(
            "OVERWORLD_RECOVERY_AUDIT status=not_overworld route=%s map=0x%02X",
            tostring(destination), map_id or -1))
        return result
    end

    local width, height = map_reader.get_map_dimensions(map_id)
    local safe_snapshot = map_reader.get_walkability_snapshot
        and map_reader.get_walkability_snapshot(map_id) or nil
    local hazard_snapshot = map_reader.get_walkability_snapshot
        and map_reader.get_walkability_snapshot(map_id, {allow_hazards = true}) or nil
    if not width or not height or not safe_snapshot or not hazard_snapshot then
        local result = {
            status = "walkability_unavailable",
            ok = false,
            route_id = destination,
            map_id = map_id,
            message = "Recovery coverage audit refused because decoded walkability is unavailable",
        }
        debug_tools.info(string.format(
            "OVERWORLD_RECOVERY_AUDIT status=walkability_unavailable route=%s map=0x%02X",
            tostring(destination), map_id or -1))
        return result
    end

    local candidates = overworld_routes.network_entry_candidates(
        destination, map_id, {terrain_offset = terrain_offset})
    local max_opening_steps = tonumber(opts.max_opening_steps) or 24
    local max_recovery_steps = tonumber(opts.max_recovery_steps)
        or M.OVERWORLD_RECOVERY_AUTO_WALK_MAX_STEPS
    local eligible = {}
    local rejected_opening = 0
    for _, candidate in ipairs(candidates) do
        if (tonumber(candidate.opening_length) or math.huge) <= max_opening_steps then
            eligible[#eligible + 1] = candidate
        else
            rejected_opening = rejected_opening + 1
        end
    end

    local transition_lookup = {}
    for _, cell in ipairs(overworld_routes.network_transition_cells()) do
        transition_lookup[cell_key(cell.x, cell.y)] = true
    end
    local directional_blocks = map_reader.get_directional_blocks
        and map_reader.get_directional_blocks(map_id) or {}

    local function snapshot_walkable(walkability, x, y)
        local row = walkability[y]
        return row and row[x] == true
    end

    -- Reverse traversal preserves directional entry restrictions: when the
    -- search visits predecessor P from cell C, it verifies that P may enter C.
    local function distances_to_entries(walkability)
        local distances = {}
        local queue = {}
        local seeded = 0
        for _, candidate in ipairs(eligible) do
            local key = cell_key(candidate.x, candidate.y)
            if not transition_lookup[key]
               and snapshot_walkable(walkability, candidate.x, candidate.y)
               and distances[key] == nil then
                distances[key] = 0
                queue[#queue + 1] = {x = candidate.x, y = candidate.y}
                seeded = seeded + 1
            end
        end

        local head = 1
        while queue[head] do
            local cell = queue[head]
            head = head + 1
            local current_key = cell_key(cell.x, cell.y)
            local current_distance = distances[current_key]
            local current_blocks = directional_blocks[current_key]
            for _, step in ipairs(PATH_DIRECTIONS) do
                local px = cell.x - step.dx
                local py = cell.y - step.dy
                local predecessor_key = cell_key(px, py)
                if px >= 0 and px < width and py >= 0 and py < height
                   and distances[predecessor_key] == nil
                   and not transition_lookup[predecessor_key]
                   and snapshot_walkable(walkability, px, py)
                   and not (current_blocks and current_blocks[step.approach] == true) then
                    distances[predecessor_key] = current_distance + 1
                    queue[#queue + 1] = {x = px, y = py}
                end
            end
        end
        return distances, seeded
    end

    local safe_distances, safe_entry_count = distances_to_entries(safe_snapshot)
    local hazard_distances, hazard_entry_count = distances_to_entries(hazard_snapshot)
    local counts = {
        network = 0,
        safe_within_limit = 0,
        safe_over_limit = 0,
        hazard_required = 0,
        unreachable = 0,
        transition = 0,
        nonwalkable = 0,
    }
    local samples = {
        safe_over_limit = {},
        hazard_required = {},
        unreachable = {},
    }
    local max_safe_distance = 0

    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local key = cell_key(x, y)
            if transition_lookup[key] then
                counts.transition = counts.transition + 1
            elseif not snapshot_walkable(hazard_snapshot, x, y) then
                counts.nonwalkable = counts.nonwalkable + 1
            elseif overworld_routes.is_network_corridor_cell(x, y) then
                counts.network = counts.network + 1
            else
                local safe_distance = safe_distances[key]
                local hazard_distance = hazard_distances[key]
                if safe_distance ~= nil then
                    if safe_distance > max_safe_distance then
                        max_safe_distance = safe_distance
                    end
                    if safe_distance <= max_recovery_steps then
                        counts.safe_within_limit = counts.safe_within_limit + 1
                    else
                        counts.safe_over_limit = counts.safe_over_limit + 1
                        samples.safe_over_limit[#samples.safe_over_limit + 1] = {
                            x = x, y = y, distance = safe_distance,
                        }
                    end
                elseif hazard_distance ~= nil then
                    counts.hazard_required = counts.hazard_required + 1
                    samples.hazard_required[#samples.hazard_required + 1] = {
                        x = x, y = y, distance = hazard_distance,
                    }
                else
                    counts.unreachable = counts.unreachable + 1
                    samples.unreachable[#samples.unreachable + 1] = {x = x, y = y}
                end
            end
        end
    end

    local function sort_distance_samples(items)
        table.sort(items, function(a, b)
            if a.distance ~= b.distance then return a.distance > b.distance end
            if a.y ~= b.y then return a.y < b.y end
            return a.x < b.x
        end)
    end
    sort_distance_samples(samples.safe_over_limit)
    sort_distance_samples(samples.hazard_required)
    table.sort(samples.unreachable, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)

    local sample_limit = math.max(0, math.floor(tonumber(opts.sample_limit) or 5))
    local unreachable_sample_limit = math.max(sample_limit,
        math.floor(tonumber(opts.unreachable_sample_limit) or 12))
    for category, items in pairs(samples) do
        local category_limit = category == "unreachable"
            and unreachable_sample_limit or sample_limit
        while #items > category_limit do
            table.remove(items)
        end
    end

    local status = #eligible == 0 and "no_eligible_entries" or "complete"
    local result = {
        status = status,
        ok = status == "complete",
        route_id = destination,
        map_id = map_id,
        width = width,
        height = height,
        candidate_count = #candidates,
        eligible_candidate_count = #eligible,
        safe_entry_count = safe_entry_count,
        hazard_entry_count = hazard_entry_count,
        rejected_opening = rejected_opening,
        max_opening_steps = max_opening_steps,
        max_recovery_steps = max_recovery_steps,
        max_safe_distance = max_safe_distance,
        counts = counts,
        samples = samples,
    }
    result.message = string.format(
        "Recovery audit for %s. Network %d. Safe within %d steps %d. Safe beyond limit %d. Hazard required %d. Unreachable %d. Maximum safe distance %d.",
        tostring(destination), counts.network, max_recovery_steps,
        counts.safe_within_limit, counts.safe_over_limit,
        counts.hazard_required, counts.unreachable, max_safe_distance)

    debug_tools.info(string.format(
        "OVERWORLD_RECOVERY_AUDIT status=%s route=%s map=0x%02X size=%dx%d candidates=%d eligible=%d rejected_opening=%d safe_entries=%d hazard_entries=%d network=%d safe_within_limit=%d safe_over_limit=%d hazard_required=%d unreachable=%d transition=%d nonwalkable=%d max_safe_distance=%d recovery_limit=%d",
        status, tostring(destination), map_id, width, height, #candidates,
        #eligible, rejected_opening, safe_entry_count, hazard_entry_count,
        counts.network, counts.safe_within_limit, counts.safe_over_limit,
        counts.hazard_required, counts.unreachable, counts.transition,
        counts.nonwalkable, max_safe_distance, max_recovery_steps))
    for category, items in pairs(samples) do
        for _, sample in ipairs(items) do
            debug_tools.info(string.format(
                "OVERWORLD_RECOVERY_AUDIT_SAMPLE route=%s category=%s x=%d y=%d distance=%s",
                tostring(destination), category, sample.x, sample.y,
                tostring(sample.distance or "-")))
        end
    end
    return result
end

local queue_overworld_segment_steps
local queue_path_steps
local overworld_segment_target

function M.autowalk_overworld_recovery(opts, map_id, px, py, continuous_requested)
    opts = opts or {}
    local result = M.preview_overworld_network_entry({
        terrain_offset = snapshot.terrain_offset,
    })
    if result.status == "already_on_network" then
        return result
    end

    local function refuse(reason, message)
        result.ok = false
        result.auto_walk_allowed = false
        result.recovery_execution = true
        result.preview_only = false
        result.message = message or result.message
        debug_tools.info(string.format(
            "OVERWORLD_RECOVERY_AUTO_WALK event=refused status=%s reason=%s map=0x%02X from=(%s,%s) entry=(%s,%s) steps=%s final=%s",
            tostring(result.status or "unavailable"),
            tostring(reason or "unavailable"),
            map_id or -1,
            tostring(px),
            tostring(py),
            tostring(result.entry_x or "-"),
            tostring(result.entry_y or "-"),
            tostring(result.path_length or "-"),
            tostring(result.final_destination_id or "-")))
        if opts.speak ~= false then
            tolk.output_interrupt(result.message or "Recovery auto-walk is unavailable")
        end
        return result
    end

    if result.ok ~= true then
        return refuse(result.status or "preview_failed")
    end
    if result.auto_walk_allowed ~= true then
        return refuse("hazardous_recovery",
            "Recovery auto-walk stopped. " .. tostring(result.message))
    end
    if not result.path or #result.path == 0 then
        return refuse("empty_recovery_path",
            "Recovery auto-walk stopped because no recovery steps were available")
    end
    local full_path = result.path
    local full_path_length = #full_path
    local checkpoint_stop = full_path_length
        > M.OVERWORLD_RECOVERY_AUTO_WALK_MAX_STEPS
    if checkpoint_stop then
        local path_slice = {}
        for index = 1, M.OVERWORLD_RECOVERY_AUTO_WALK_MAX_STEPS do
            path_slice[index] = full_path[index]
        end
        result.path = path_slice
        result.path_length = #path_slice
        result.network_entry_path_length = full_path_length
    end

    release_target_face("new overworld recovery auto-walk")
    release_target_npc_hold("new overworld recovery auto-walk")
    release_npc_freeze("new overworld recovery auto-walk")
    last_pathfind_obj = nil
    reroute_failures = 0

    if not queue_path_steps(result.path, {
        map_id = map_id,
        start_x = px,
        start_y = py,
        settle_frames = 0,
        settle_same_direction = true,
    }) then
        result.status = "queue_failed"
        return refuse("queue_failed",
            "Recovery auto-walk could not queue the safe path")
    end

    local recovery_target = result.path[#result.path]
    local recovery_segment = {
        route = {
            id = result.route_id,
            title = result.route_title,
        },
        waypoint = {
            name = checkpoint_stop and "safe recovery checkpoint"
                or (result.entry_name or "waypoint network entry"),
            x = recovery_target.x,
            y = recovery_target.y,
        },
        object_id = string.format(
            "overworld_recovery_entry_%s_%s",
            tostring(result.entry_x),
            tostring(result.entry_y)),
    }
    active_overworld_segment = {
        recovery = true,
        route_id = result.route_id,
        route_title = result.route_title,
        waypoint_name = recovery_segment.waypoint.name,
        waypoint_x = result.entry_x,
        waypoint_y = result.entry_y,
        target_x = recovery_target.x,
        target_y = recovery_target.y,
        recovery_checkpoint = checkpoint_stop,
        remaining_steps = full_path_length - #result.path,
        steps = #result.path,
        continuous = false,
        continuous_requested = continuous_requested == true,
        stop_on_blocker = opts.stop_on_blocker == true,
        final_destination_id = result.final_destination_id,
        final_destination_title = result.final_destination_title,
        next_waypoint_name = result.next_waypoint_name,
    }
    set_active_route_context(
        overworld_segment_target(recovery_segment),
        #result.path,
        nil,
        {
            post_arrival_actions = false,
            speak = false,
            stop_on_blocker = opts.stop_on_blocker == true,
        })

    result.status = "recovery_queued"
    result.ok = true
    result.preview_only = false
    result.recovery_execution = true
    result.boundary_stop = not checkpoint_stop
    result.checkpoint_stop = checkpoint_stop
    if checkpoint_stop then
        result.message = string.format(
            "Recovery auto-walk. Safe checkpoint at %d,%d, %d steps. The waypoint network is %d safe steps away. Final destination: %s. Auto-walk will stop at the checkpoint; press it again to continue recovery.",
            recovery_target.x,
            recovery_target.y,
            #result.path,
            full_path_length,
            tostring(result.final_destination_title or "selected destination"))
    else
        result.message = string.format(
            "Recovery auto-walk. Safe network entry: %s at %d,%d, %d steps. Final destination: %s. Auto-walk will stop at the waypoint network.",
            tostring(result.entry_name or "waypoint"),
            result.entry_x,
            result.entry_y,
            #result.path,
            tostring(result.final_destination_title or "selected destination"))
    end
    debug_tools.info(string.format(
        "OVERWORLD_RECOVERY_AUTO_WALK event=start map=0x%02X from=(%d,%d) target=(%d,%d) entry=(%d,%d) steps=%d full_steps=%d route=%s next=%s final=%s continuous_requested=%s checkpoint_stop=%s boundary_stop=%s",
        map_id or -1,
        px or -1,
        py or -1,
        recovery_target.x or -1,
        recovery_target.y or -1,
        result.entry_x or -1,
        result.entry_y or -1,
        #result.path,
        full_path_length,
        tostring(result.route_id or "-"),
        tostring(result.next_waypoint_name or "-"),
        tostring(result.final_destination_id or "-"),
        tostring(continuous_requested == true),
        tostring(checkpoint_stop),
        tostring(not checkpoint_stop)))
    if opts.speak ~= false then
        tolk.output_interrupt(result.message)
    end
    return result
end

function M.autowalk_overworld_segment(opts)
    opts = opts or {}
    local stop_on_blocker = opts.stop_on_blocker == true
    local continuous = opts.overworld_continuous
    if continuous == nil then
        -- Blocker-hunt mode is explicitly a whole-route diagnostic pass on
        -- the overworld, even when ordinary continuous travel is disabled.
        continuous = stop_on_blocker
            or config_bool("overworld_auto_walk_continuous", false)
    else
        continuous = continuous == true
    end
    if autowalk_guard and not opts.skip_guard then
        local ok, reason = autowalk_guard(opts)
        if ok == false then
            debug_tools.info(string.format(
                "OVERWORLD_AUTO_WALK: event=guard_blocked reason=%s",
                tostring(reason or "unspecified")))
            if opts.speak ~= false then
                tolk.output_interrupt(reason or "Cannot auto-walk right now")
            end
            return {
                status = "guard_blocked",
                ok = false,
                message = reason or "Cannot auto-walk right now",
            }
        end
    end

    local map_id, px, py = nav.get_position()
    if overworld_routes.is_network_corridor_cell
       and not overworld_routes.is_network_corridor_cell(px, py) then
        local recovery = M.autowalk_overworld_recovery(
            opts, map_id, px, py, continuous)
        if recovery.status ~= "already_on_network" then
            return recovery
        end
    end
    local segment, err = overworld_routes.plan_next_segment(map_id, px, py, {
        terrain_offset = snapshot.terrain_offset,
        advance_if_at_waypoint = true,
    })
    if not segment then
        local message = err or "No overworld route active"
        debug_tools.info(string.format(
            "OVERWORLD_AUTO_WALK: event=unavailable map=0x%02X position=(%s,%s) reason=%s",
            map_id or -1,
            tostring(px),
            tostring(py),
            tostring(message)))
        if opts.speak ~= false then
            tolk.output_interrupt(message)
        end
        return {
            status = "unavailable",
            ok = false,
            message = message,
        }
    end

    if not segment.steps or #segment.steps == 0 then
        debug_tools.info(string.format(
            "OVERWORLD_AUTO_WALK: event=already route=%s waypoint=%s index=%s position=(%s,%s)",
            tostring(segment.route and segment.route.id or "-"),
            tostring(segment.waypoint and segment.waypoint.name or "-"),
            tostring(segment.index),
            tostring(px),
            tostring(py)))
        if opts.speak ~= false then
            tolk.output_interrupt(segment.message or "Already at overworld waypoint")
        end
        segment.status = segment.status or "already_at_waypoint"
        segment.ok = true
        return segment
    end

    release_target_face("new overworld auto-walk")
    release_target_npc_hold("new overworld auto-walk")
    release_npc_freeze("new overworld auto-walk")
    last_pathfind_obj = nil
    reroute_failures = 0

    local allowed_route_hazard, hazard_confirmed =
        M._overworld_hazard_confirmation.allowed_for_segment(segment, map_id, px, py)

    if not queue_overworld_segment_steps(segment.steps, {
        route_early_twitch_timeout_frames = segment.waypoint and segment.waypoint.route_early_twitch_timeout_frames,
        route_hold_after_movement_start_frames = segment.waypoint and segment.waypoint.route_hold_after_movement_start_frames,
        route_reset_movement_on_turn_settle = segment.waypoint and segment.waypoint.route_reset_movement_on_turn_settle,
        route_final_inject_limit = segment.waypoint and segment.waypoint.route_final_inject_limit,
        route_final_carry_x = segment.route_final_carry_x,
        route_final_carry_y = segment.route_final_carry_y,
        allowed_route_hazard = allowed_route_hazard,
    }) then
        if hazard_confirmed then
            M._overworld_hazard_confirmation.clear("confirmed route could not be queued")
        end
        debug_tools.error(string.format(
            "OVERWORLD_AUTO_WALK: event=queue_failed route=%s waypoint=%s index=%s steps=%d",
            tostring(segment.route and segment.route.id or "-"),
            tostring(segment.waypoint and segment.waypoint.name or "-"),
            tostring(segment.index),
            #segment.steps))
        if opts.speak ~= false then
            tolk.output_interrupt("Overworld auto-walk could not queue the route")
        end
        segment.status = "queue_failed"
        segment.ok = false
        segment.message = "Overworld auto-walk could not queue the route"
        return segment
    end

    active_overworld_segment = {
        route_id = segment.route and segment.route.id or nil,
        route_title = segment.route and segment.route.title or nil,
        waypoint_name = segment.waypoint and segment.waypoint.name or nil,
        waypoint_x = segment.waypoint and segment.waypoint.x or nil,
        waypoint_y = segment.waypoint and segment.waypoint.y or nil,
        index = segment.index,
        steps = #segment.steps,
        route_final_carry_x = segment.route_final_carry_x,
        route_final_carry_y = segment.route_final_carry_y,
        continuous = continuous,
        stop_on_blocker = stop_on_blocker,
        allowed_route_hazard = allowed_route_hazard,
    }
    set_active_route_context(overworld_segment_target(segment), #segment.steps, nil, {
        post_arrival_actions = false,
        speak = false,
        stop_on_blocker = stop_on_blocker,
    })
    debug_tools.info(string.format(
        "OVERWORLD_AUTO_WALK: event=start route=%s waypoint=%s index=%s steps=%d from=(%d,%d) to=(%s,%s) carry=(%s,%s) continuous=%s stop_on_blocker=%s",
        tostring(active_overworld_segment.route_id or "-"),
        tostring(active_overworld_segment.waypoint_name or "-"),
        tostring(active_overworld_segment.index),
        #segment.steps,
        px or -1,
        py or -1,
        tostring(active_overworld_segment.waypoint_x),
        tostring(active_overworld_segment.waypoint_y),
        tostring(active_overworld_segment.route_final_carry_x),
        tostring(active_overworld_segment.route_final_carry_y),
        tostring(continuous),
        tostring(stop_on_blocker)))
    segment.status = "queued"
    segment.ok = true
    if opts.speak ~= false then
        local speech_message
        if hazard_confirmed then
            speech_message = "Poison swamp confirmed. Auto-walk continuing through this swamp."
        elseif stop_on_blocker then
            speech_message = "Overworld blocker hunt toward "
                .. tostring(active_overworld_segment.route_title or "the route destination")
        elseif continuous then
            speech_message = "Continuous overworld auto-walk to "
                .. tostring(active_overworld_segment.route_title or "the route destination")
        else
            speech_message = "Overworld auto-walk. "
                .. tostring(segment.message or "Next waypoint queued")
        end
        tolk.output_interrupt(speech_message)
    end
    return segment
end

-- queue_path_steps(path): Convert A* path to auto_step route directions.
-- Returns true if the route was queued successfully.
queue_path_steps = function(path, opts)
    if not path or #path == 0 then
        return false
    end
    opts = opts or {}
    local function entry_cadence_before_steps_for_path(map_id, route_path, start_x, start_y)
        if not map_reader.get_entry_settle_frames
           and not map_reader.get_entry_prime_frames then
            return nil, nil
        end

        local settles = {}
        local primes = {}
        for step_index, step in ipairs(route_path or {}) do
            local key_dir = DIR_NAME_TO_KEY[step.direction]
            local approach = key_dir and DIR_TO_APPROACH[key_dir]
            local settle_frames = approach and map_reader.get_entry_settle_frames
                and map_reader.get_entry_settle_frames(
                    map_id, step.x, step.y, approach) or 0
            local prime_frames = approach and map_reader.get_entry_prime_frames
                and map_reader.get_entry_prime_frames(
                    map_id, step.x, step.y, approach) or 0
            if settle_frames > 0 then
                settles[step_index] = settle_frames
            end
            if prime_frames > 0 then
                primes[step_index] = prime_frames
            end
            if settle_frames > 0 or prime_frames > 0 then
                local origin = step_index == 1
                    and {x = start_x, y = start_y}
                    or route_path[step_index - 1]
                debug_tools.info(string.format(
                    "AUTO_WALK_ENTRY_SETTLE map=0x%02X from=(%d,%d) dest=(%d,%d) dir=%s step=%d frames=%d prime=%d",
                    map_id or -1,
                    tonumber(origin and origin.x) or -1,
                    tonumber(origin and origin.y) or -1,
                    tonumber(step.x) or -1,
                    tonumber(step.y) or -1,
                    tostring(key_dir),
                    step_index,
                    settle_frames,
                    prime_frames))
            end
        end

        return next(settles) and settles or nil,
            next(primes) and primes or nil
    end

    local steps = {}
    local start_x = tonumber(opts.start_x)
    local start_y = tonumber(opts.start_y)
    for i, step in ipairs(path) do
        local dir = DIR_NAME_TO_KEY[step.direction]
        if not dir then
            return false
        end
        steps[i] = dir
        if i == 1 and (start_x == nil or start_y == nil) then
            local delta = DIR_TO_DELTA[dir]
            if delta and step.x ~= nil and step.y ~= nil then
                start_x = tonumber(step.x) and (tonumber(step.x) - delta.dx) or start_x
                start_y = tonumber(step.y) and (tonumber(step.y) - delta.dy) or start_y
            end
        end
    end
    local live_map_id = select(1, nav.get_position())
    local map_id = tonumber(opts.map_id) or live_map_id
    local settle_before_steps, prime_before_steps = entry_cadence_before_steps_for_path(
        map_id, path, start_x, start_y)
    local settle_frames = opts.settle_frames
    if settle_frames == nil then
        settle_frames = active_route_settle_frames or 0
    end
    settle_frames = math.max(0, tonumber(settle_frames) or 0)
    local settle_same_direction = opts.settle_same_direction
    if settle_same_direction == nil then
        settle_same_direction = active_route_settle_same_direction
    end
    settle_same_direction = settle_same_direction ~= false
    trace_autowalk_boundary("queue_path_steps_before_start_route", string.format(
        "steps=%d start=(%s,%s) settle=%d same_direction=%s",
        #steps,
        tostring(start_x),
        tostring(start_y),
        settle_frames,
        tostring(settle_same_direction)))
    if auto_step.start_route(steps, {
        settle_frames = settle_frames,
        settle_same_direction = settle_same_direction,
        initial_settle_frames = opts.initial_settle_frames,
        start_x = start_x,
        start_y = start_y,
        settle_before_steps = settle_before_steps,
        prime_before_steps = prime_before_steps,
    }) then
        trace_autowalk_boundary("queue_path_steps_after_start_route", string.format(
            "result=true steps=%d",
            #steps))
        active_route_settle_frames = settle_frames
        active_route_settle_same_direction = settle_same_direction
        reroute_failures = 0
        return true
    end
    trace_autowalk_boundary("queue_path_steps_after_start_route", string.format(
        "result=false steps=%d",
        #steps))
    return false
end

queue_overworld_segment_steps = function(steps, opts)
    opts = opts or {}
    if not steps or #steps == 0 then
        return false
    end
    if auto_step.start_route(steps, {
        settle_frames = 0,
        settle_same_direction = true,
        route_early_twitch_timeout_frames = opts.route_early_twitch_timeout_frames,
        route_hold_after_movement_start_frames = opts.route_hold_after_movement_start_frames,
        route_reset_movement_on_turn_settle = opts.route_reset_movement_on_turn_settle,
        route_final_inject_limit = opts.route_final_inject_limit,
        route_final_carry_x = opts.route_final_carry_x,
        route_final_carry_y = opts.route_final_carry_y,
        allowed_route_hazard = opts.allowed_route_hazard,
    }) then
        active_route_settle_frames = 0
        active_route_settle_same_direction = true
        reroute_failures = 0
        return true
    end
    return false
end

overworld_segment_target = function(segment)
    local point = segment and segment.waypoint or {}
    return {
        id = segment and segment.object_id or nil,
        name = point.name and ("Route waypoint: " .. point.name) or "Route waypoint",
        type = objects.TYPE_EXIT,
        x = point.x,
        y = point.y,
        route_id = segment and segment.route and segment.route.id or nil,
        route_index = segment and segment.index or nil,
        route_waypoint = true,
    }
end

-- ============================================================
-- Public API: Pathfinding Commands
-- ============================================================

-- pathfind_to_current(): Plan a path to the currently selected object.
-- Announces the result via speech. This is a preview command, so it does not
-- hold the NPC freeze after planning. Under BizHawk it also avoids a forced
-- live NPC refresh by default because those RAM reads audibly hitch the emulator.
function M.pathfind_to_current()
    local obj = objects.current_object()
    if not obj then
        tolk.output_interrupt("No object selected")
        return
    end
    last_pathfind_obj = obj
    local plan = plan_path_to_object(obj, {hazard_preview = true})
    tolk.output_interrupt(plan.message)
end

function M.autowalk_to_object(obj, opts)
    opts = opts or {}
    release_target_face("new auto-walk")
    release_target_npc_hold("new auto-walk")
    if opts.allow_adjacent_fallback == nil then
        opts.allow_adjacent_fallback = true
    end
    if not obj then
        return {
            status = "no_object",
            ok = false,
            message = "No object selected",
        }
    end
    local contamination = M._abort_autowalk_if_input_contaminated("auto_walk", obj, "autowalk_to_object", opts)
    if contamination then
        return contamination
    end
    if autowalk_guard then
        local ok, reason = autowalk_guard(opts)
        if ok == false then
            debug_tools.info(string.format(
                "AUTO_WALK: blocked before planning for %s reason=%s",
                tostring(obj.name),
                tostring(reason or "unspecified")))
            if opts.speak ~= false then
                tolk.output_interrupt(reason or "Cannot auto-walk right now")
            end
            return {
                status = "guard_blocked",
                ok = false,
                message = reason or "Cannot auto-walk right now",
                target = obj,
            }
        end
    end
    local map_id, px, py = nav.get_position()
    trace_autowalk_boundary("autowalk_to_object_entry", string.format(
        "target=%s map=0x%02X pos=(%d,%d) speak=%s",
        tostring(obj.name),
        map_id or -1,
        px or -1,
        py or -1,
        tostring(opts.speak ~= false)))
    local terrain_offset = snapshot.terrain_offset
    active_route_temp_blocks = nil
    if maps.is_overworld(map_id, terrain_offset) then
        -- On the overworld, autowalk follows the active guided route rather
        -- than running interior pathfinding. If the selected object maps to a
        -- different route than the active one, switch routes first so the
        -- caller doesn't silently advance a stale destination.
        local target_route_id = overworld_routes.route_id_for_object(obj, map_id, px, py, terrain_offset)
        local active_route_id = overworld_routes.active_route_id()
        local active_route_matches_object = active_route_id
            and overworld_routes.active_route_matches_object(obj)
        local follow_active_route = active_route_id
            and opts.follow_active_overworld_route == true
        trace_autowalk_boundary("overworld_route_match", string.format(
            "target_id=%s target_route=%s active_route=%s active_matches=%s follow_active=%s",
            tostring(obj.id or "-"),
            tostring(target_route_id or "-"),
            tostring(active_route_id or "-"),
            tostring(active_route_matches_object == true),
            tostring(follow_active_route == true)))
        if target_route_id
           and target_route_id ~= active_route_id
           and not active_route_matches_object
           and not follow_active_route then
            local started, start_err = overworld_routes.start(target_route_id, map_id, px, py, {
                terrain_offset = terrain_offset,
            })
            if not started then
                debug_tools.info(string.format(
                    "AUTO_WALK: overworld route switch failed for %s reason=%s",
                    tostring(obj.name),
                    tostring(start_err or "unspecified")))
                if opts.speak ~= false then
                    tolk.output_interrupt(start_err or "Could not start route")
                end
                return {
                    status = "route_start_failed",
                    ok = false,
                    message = start_err or "Could not start route",
                    target = obj,
                }
            end
        end
        return M.autowalk_overworld_segment({
            speak = opts.speak,
            skip_guard = true,
            stop_on_blocker = opts.stop_on_blocker,
            overworld_continuous = opts.overworld_continuous,
        })
    end
    local npc_mode = route_npc_mode_from_opts(opts)
    local parked_slots = nil
    local park_mobile_npcs = should_park_mobile_npcs_for_autowalk(opts)
    if park_mobile_npcs then
        local parking_safe, parking_skip_reason = M.autowalk_npc_parking_safe(map_id)
        if not parking_safe then
            park_mobile_npcs = false
            npc_mode = "live_npcs"
            debug_tools.info(string.format(
                "AUTO_WALK_NPC_PARK_SKIP map=0x%02X reason=%s origin=(0,0)",
                map_id or 0,
                tostring(parking_skip_reason or "unsafe_origin")))
        end
    end
    if park_mobile_npcs then
        parked_slots = start_autowalk_npc_parking(obj, opts)
        npc_mode = "park_mobile_npcs"
    elseif should_freeze_npcs_for_autowalk(opts) then
        freeze_npcs_for_pathing()
    else
        debug_tools.debug("AUTO_WALK: NPC freeze skipped for this route")
    end
    opts = route_planning_opts(opts, npc_mode, "autowalk_initial")
    opts.planning_parked_slots = parked_slots
    last_pathfind_obj = obj
    if opts.hazard_preview == nil then
        opts.hazard_preview = true
    end
    trace_autowalk_boundary("before_plan_path", string.format(
        "target=%s npc_mode=%s",
        tostring(obj.name),
        tostring(npc_mode)))
    local plan = plan_path_to_object(obj, opts)
    trace_autowalk_boundary("after_plan_path", string.format(
        "target=%s result=%s path_len=%d",
        tostring(obj.name),
        tostring(plan and plan.result),
        plan and plan.path and #plan.path or 0))
    plan, opts = maybe_use_unsafe_hazard_plan(obj, map_id, opts, plan)
    if opts.allow_hazards == true then
        plan = maybe_stop_before_hazard(plan)
        if plan.hazard_stop then
            plan.message = "Unsafe route available. " ..
                build_hazard_warning(plan.hazard_stop.summary, "Auto-walk will stop before the hazard.")
        end
    end
    plan.status = "planned"
    plan.ok = false
    if plan.result == "No path found" then
        release_route_npc_controls("autowalk immediate no-path")
        log_auto_walk_no_path_detail(plan)
        debug_tools.info("AUTO_WALK: no path for " .. obj.name)
        if opts.speak ~= false then
            tolk.output_interrupt(plan.message)
        end
        plan.status = "no_path"
        plan.message = plan.message
        return plan
    end
    if not plan.path or #plan.path == 0 then
        if plan.hazard_stop then
            release_route_npc_controls("autowalk hazard boundary")
            plan.status = "hazard_boundary"
            plan.message = build_hazard_warning(plan.hazard_stop.summary, "Hazard ahead.")
            if opts.speak ~= false then
                tolk.output_interrupt(plan.message)
            end
            return plan
        end
        release_route_npc_controls("autowalk already at destination")
        debug_tools.info("AUTO_WALK: already adjacent to " .. obj.name)
        plan.status = "already_there"
        plan.message = "Already there. " .. build_pathfind_message(obj, "Adjacent", plan.face_dir)
        if use_post_arrival_actions(opts) and should_face_after_plan(plan) then
            queue_target_face(plan.face_dir, obj)
        end
        if use_post_arrival_actions(opts) and start_target_npc_hold(obj) then
            plan.message = plan.message .. ". Target held briefly. Use TALK now"
        end
        if opts.speak ~= false then
            tolk.output_interrupt(plan.message)
        end
        return plan
    end
    if opts.prequeue_hook then
        local ok, override = opts.prequeue_hook(plan)
        if ok == false then
            release_route_npc_controls("autowalk prequeue deferred")
            if type(override) == "table" then
                for k, v in pairs(override) do
                    plan[k] = v
                end
            end
            plan.status = plan.status or "prequeue_rejected"
            plan.ok = false
            return plan
        end
    end
    local settle_frames = opts.route_settle_frames
    if settle_frames == nil and opts.survey_safe then
        settle_frames = SURVEY_ROUTE_SETTLE_FRAMES
    end
    if settle_frames == nil then
        settle_frames = 0
    end
    local settle_same_direction = opts.route_settle_same_direction
    if settle_same_direction == nil and opts.survey_safe then
        settle_same_direction = false
    end
    if settle_same_direction == nil then
        settle_same_direction = true
    end
    trace_autowalk_boundary("before_queue_path_steps", string.format(
        "target=%s path_len=%d settle=%d same_direction=%s",
        tostring(obj.name),
        #plan.path,
        settle_frames,
        tostring(settle_same_direction)))
    if not queue_path_steps(plan.path, {
        map_id = plan.map_id,
        settle_frames = settle_frames,
        settle_same_direction = settle_same_direction,
    }) then
        active_route_settle_frames = 0
        active_route_settle_same_direction = true
        release_route_npc_controls("autowalk queue failure")
        debug_tools.error("AUTO_WALK: failed to queue route for " .. obj.name)
        plan.status = "queue_failed"
        plan.message = "Auto-walk could not queue the route"
        if opts.speak ~= false then
            tolk.output_interrupt(plan.message)
        end
        return plan
    end
    trace_autowalk_boundary("after_queue_path_steps", string.format(
        "target=%s path_len=%d",
        tostring(obj.name),
        #plan.path))
    debug_tools.info("AUTO_WALK: queued " .. #plan.path .. " step(s) for " .. obj.name)
    opts.hazard_stop = plan.hazard_stop
    trace_autowalk_boundary("before_set_active_route_context", string.format(
        "target=%s path_len=%d face_dir=%s",
        tostring(obj.name),
        #plan.path,
        tostring(should_face_after_plan(plan) and plan.face_dir or nil)))
    set_active_route_context(obj, #plan.path, should_face_after_plan(plan) and plan.face_dir or nil, opts)
    trace_autowalk_boundary("after_set_active_route_context", string.format(
        "target=%s",
        tostring(obj.name)))
    plan.status = "queued"
    plan.ok = true
    plan.path_length = #plan.path
    if opts.speak ~= false then
        trace_autowalk_boundary("before_autowalk_speech", string.format(
            "target=%s",
            tostring(obj.name)))
        tolk.output_interrupt("Auto-walk. " .. plan.message)
        trace_autowalk_boundary("after_autowalk_speech", string.format(
            "target=%s",
            tostring(obj.name)))
    end
    return plan
end

-- autowalk_to_current(): Plan and auto-walk to the currently selected object.
-- Interior maps use A* object pathing. On the overworld, an active guided
-- route can queue one waypoint segment without invoking interior pathfinding.
function M.autowalk_to_current(opts)
    opts = opts or {}
    local obj = objects.current_object()
    if not obj then
        local map_id = nav.get_position()
        if maps.is_overworld(map_id, snapshot.terrain_offset) then
            local overworld_opts = copy_opts(opts)
            overworld_opts.speak = opts.speak ~= false
            return M.autowalk_overworld_segment(overworld_opts)
        end
        if opts.speak ~= false then
            tolk.output_interrupt("No object selected")
        end
        return
    end
    local next_opts = copy_opts(opts)
    if next_opts.speak == nil then
        next_opts.speak = true
    end
    -- Bare U advances guidance already started with R. Map changes can reset
    -- object focus to a nearby landmark; that automatic refresh must not
    -- silently replace the active destination. Explicit object-target calls
    -- retain their route-switching behavior.
    next_opts.follow_active_overworld_route = true
    return M.autowalk_to_object(obj, next_opts)
end

-- Return the speech payload for an overworld route-position event. Continuous
-- travel logs every waypoint but speaks only warnings and terminal arrival;
-- route_status remains available for progress on demand.
function M.overworld_route_event_speech(route_event)
    if not route_event then
        return nil
    end
    if not active_overworld_segment
       or active_overworld_segment.continuous ~= true
       or route_event.terminal == true then
        return route_event.message
    end
    return route_event.warning_message
end

-- A terminal guided-route message already names the destination, so it should
-- replace the generic map-name announcement rather than follow it.
function M.overworld_route_map_change_speech(map_name, route_event)
    if route_event and route_event.terminal == true then
        return nil
    end
    return map_name
end

local function reroute_after_route_drift(cancel_data, target)
    if not target then
        return false
    end
    local map_id, live_x, live_y = nav.get_position()
    local start_x = tonumber(cancel_data and cancel_data.current_x) or live_x
    local start_y = tonumber(cancel_data and cancel_data.current_y) or live_y
    if start_x == nil or start_y == nil then
        return false
    end

    route_drift_reroutes = route_drift_reroutes + 1
    if route_drift_reroutes > ROUTE_DRIFT_REROUTE_LIMIT then
        debug_tools.info(string.format(
            "AUTO_WALK_DRIFT_REROUTE_LIMIT map=0x%02X target=%s current=(%d,%d) count=%d reason=%s",
            map_id or -1,
            tostring(target.name),
            start_x or -1,
            start_y or -1,
            route_drift_reroutes,
            tostring(cancel_data and cancel_data.source or "route_drift")))
        event_bus.publish("route_cancelled", {
            reason = "route_drift_reroute_limit",
            target = target,
            map_id = map_id,
            current_x = start_x,
            current_y = start_y,
            source = cancel_data and cancel_data.source or "route_drift",
        })
        clear_active_route_context("route drift reroute limit reached", should_refresh_objects_after_route())
        tolk.output_interrupt("Auto-walk cancelled. Movement drift did not settle.")
        return true
    end

    local plan = plan_path_to_object(target, active_route_planning_opts({
        map_id = map_id,
        start_x = start_x,
        start_y = start_y,
        allow_adjacent_fallback = true,
        allow_hazards = active_route_allow_hazards,
        store_debug_path = false,
    }, "route_drift_reroute"))
    if active_route_allow_hazards then
        plan = maybe_stop_before_hazard(plan)
    end

    if plan.result == "No path found" then
        debug_tools.info(string.format(
            "AUTO_WALK_DRIFT_REROUTE_FAILED map=0x%02X target=%s current=(%d,%d) reason=no_path",
            map_id or -1,
            tostring(target.name),
            start_x or -1,
            start_y or -1))
        return false
    end

    if not plan.path or #plan.path == 0 then
        if plan.hazard_stop then
            clear_active_route_context("route drift hazard boundary", should_refresh_objects_after_route())
            tolk.output_interrupt(build_hazard_warning(plan.hazard_stop.summary, "Hazard ahead."))
            return true
        end
        event_bus.publish("route_completed")
        clear_active_route_context("route drift reached destination", should_refresh_objects_after_route())
        tolk.output_interrupt("Auto-walk complete. Arrived at " .. tostring(target.name or "destination"))
        return true
    end

    if not queue_path_steps(plan.path, {
        map_id = map_id,
        settle_frames = active_route_settle_frames,
        settle_same_direction = active_route_settle_same_direction,
        initial_settle_frames = route_turn_settle_frames(),
    }) then
        debug_tools.info(string.format(
            "AUTO_WALK_DRIFT_REROUTE_FAILED map=0x%02X target=%s current=(%d,%d) reason=queue_failed",
            map_id or -1,
            tostring(target.name),
            start_x or -1,
            start_y or -1))
        return false
    end

    update_active_route_remaining(#plan.path, should_face_after_plan(plan) and plan.face_dir or nil, plan.hazard_stop)
    debug_tools.info(string.format(
        "AUTO_WALK_DRIFT_REROUTE map=0x%02X target=%s current=(%d,%d) path_len=%d",
        map_id or -1,
        tostring(target.name),
        start_x or -1,
        start_y or -1,
        #plan.path))
    tolk.output_interrupt("Re-routing after drift. " .. build_pathfind_message(
        target,
        plan.result,
        plan.face_dir,
        plan.no_path_reason))
    return true
end

-- ============================================================
-- Auto-Step Callbacks
-- ============================================================
-- These are wired to auto_step's callback mechanism. They handle
-- rerouting when a step is blocked and cleanup when a route completes.

auto_step.on_blocked = function(from_x, from_y, blocked_dir, block_data)
    if path_debug.is_validating and path_debug.is_validating() then
        debug_tools.debug("route_manager: ignoring blocked step during validation")
        return
    end
    if path_debug.is_step_mode and path_debug.is_step_mode() then
        debug_tools.debug("route_manager: ignoring blocked step during step mode")
        return
    end

    local map_id = nav.get_position()
    local blocked_target = active_route_target or last_pathfind_obj
    local contamination = M._abort_autowalk_if_input_contaminated("auto_walk", blocked_target, "route_blocked", {
        speak = true,
        input_refusal_opts = input_refusal_opts_for_route_block(block_data, blocked_dir),
    })
    if contamination then
        event_bus.publish("route_cancelled", {
            reason = "input_contaminated",
            target = blocked_target,
            map_id = map_id,
            from_x = from_x,
            from_y = from_y,
            blocked_dir = blocked_dir,
        })
        return
    end

    local is_manual_block = (block_data and block_data.queued_route == false)
    local is_seam_retry_block = same_seam_retry(map_id, from_x, from_y, blocked_dir)
    local is_npc_block, npc_x, npc_y, npc_blocker = is_destination_occupied_by_npc(map_id, from_x, from_y, blocked_dir)
    local active_overworld_block = active_overworld_segment ~= nil
    local source = is_npc_block
        and "npc_block"
        or (is_seam_retry_block and "seam_retry_block")
        or (is_manual_block and "manual_block" or "queued_route_block")
    local delay_timing_retry_observation = is_suspect_route_timeout(block_data)
        and not is_seam_retry_block
        and not is_npc_block
        and not active_overworld_block
    local defer_battle_onset_observation = is_suspect_route_timeout(block_data)
        and active_overworld_block
        and not active_route_stop_on_blocker
        and not is_seam_retry_block
        and not is_npc_block
    local seam_class = nil
    local function record_blocked_observation()
        if seam_class ~= nil then
            return
        end
        local _, observed_class = observe_seam_result(map_id, from_x, from_y, blocked_dir, "blocked", source)
        seam_class = observed_class
    end
    if not delay_timing_retry_observation and not defer_battle_onset_observation then
        record_blocked_observation()
    end
    if is_npc_block then
        local slot = npc_blocker and npc_blocker.slot
        debug_tools.info(string.format(
            "AUTO_WALK_NPC_BLOCK map=0x%02X from=(%d,%d) dir=%s npc=(%d,%d) id=%s slot=%s name=%s kind=%s movement=%s parked=%s npc_mode=%s",
            map_id,
            from_x or -1,
            from_y or -1,
            tostring(blocked_dir),
            npc_x or -1,
            npc_y or -1,
            tostring(npc_blocker and npc_blocker.id or "-"),
            slot ~= nil and tostring(slot) or "-",
            tostring(npc_blocker and npc_blocker.name or "-"),
            tostring(npc_blocker and npc_blocker.kind or "unknown"),
            format_npc_movement(npc_blocker and npc_blocker.movement),
            tostring(npc_blocker and npc_blocker.parked == true),
            tostring(active_route_npc_mode or "-")))
    end
    if is_manual_block and not is_seam_retry_block then
        debug_tools.debug("route_manager: ignoring blocked step outside queued route")
        return
    end
    if active_overworld_block and not active_route_stop_on_blocker then
        if defer_battle_onset_observation then
            M._defer_overworld_timeout_observation(map_id, from_x, from_y, blocked_dir, source)
        end
        local recovery_block = active_overworld_segment.recovery == true
        event_bus.publish("route_cancelled", {
            reason = recovery_block and "overworld_recovery_blocked" or "overworld_blocked",
            target = active_route_target,
            map_id = map_id,
            from_x = from_x,
            from_y = from_y,
            blocked_dir = blocked_dir,
        })
        debug_tools.info(string.format(
            "OVERWORLD_AUTO_WALK: event=blocked route=%s waypoint=%s index=%s from=(%s,%s) dir=%s source=%s",
            tostring(active_overworld_segment.route_id or "-"),
            tostring(active_overworld_segment.waypoint_name or "-"),
            tostring(active_overworld_segment.index),
            tostring(from_x),
            tostring(from_y),
            tostring(blocked_dir),
            tostring(source)))
        if recovery_block then
            debug_tools.info(string.format(
                "OVERWORLD_RECOVERY_AUTO_WALK event=blocked map=0x%02X from=(%s,%s) dir=%s entry=(%s,%s) final=%s source=%s",
                map_id or -1,
                tostring(from_x),
                tostring(from_y),
                tostring(blocked_dir),
                tostring(active_overworld_segment.waypoint_x),
                tostring(active_overworld_segment.waypoint_y),
                tostring(active_overworld_segment.final_destination_id or "-"),
                tostring(source)))
        end
        local waypoint_name = active_overworld_segment.waypoint_name or "the next waypoint"
        clear_active_route_context("overworld auto-walk blocked", should_refresh_objects_after_route())
        local prefix = recovery_block
            and "Recovery auto-walk stopped"
            or "Overworld auto-walk stopped"
        tolk.output_interrupt(prefix .. ". Blocked moving " .. tostring(blocked_dir) .. " toward " .. waypoint_name)
        return
    end
    if not last_pathfind_obj and not active_overworld_block then return end

    if delay_timing_retry_observation
       and start_seam_bruteforce(map_id, from_x, from_y, blocked_dir, block_data) then
        record_active_route_temp_block(map_id, from_x, from_y, blocked_dir, "timing_retry")
        debug_tools.info(string.format(
            "AUTO_WALK_TIMING_RETRY map=0x%02X from=(%d,%d) dir=%s movement_start_frame=%s timeout_retries=%s turn_represses=%s",
            map_id,
            from_x or -1,
            from_y or -1,
            tostring(blocked_dir),
            tostring(block_data and block_data.movement_start_frame),
            tostring(block_data and block_data.timeout_retries),
            tostring(block_data and block_data.turn_represses)))
        return
    end

    if active_route_stop_on_blocker then
        local dest_x, dest_y, approach = get_destination_for_dir(from_x, from_y, blocked_dir)
        local upper_dir = tostring(blocked_dir or ""):upper()
        local command = string.format("add_blocked_edge:%d,%d,%s", from_x or -1, from_y or -1, upper_dir)
        local target = active_route_target or last_pathfind_obj
        event_bus.publish("route_cancelled", {
            reason = "stop_on_blocker",
            target = target,
            map_id = map_id,
            from_x = from_x,
            from_y = from_y,
            blocked_dir = blocked_dir,
            dest_x = dest_x,
            dest_y = dest_y,
            approach = approach,
            npc_blocked = is_npc_block == true,
            timing_suspect = block_data and block_data.timing_suspect == true,
            patch_command = (is_npc_block and nil or command),
        })
        debug_tools.info(string.format(
            "AUTO_WALK_BLOCKER_FOUND map=0x%02X target_id=%s target_name=%s from=(%d,%d) dir=%s dest=(%d,%d) approach=%s source=%s npc_blocked=%s timing_suspect=%s patch_command=%s",
            map_id or -1,
            tostring(target and target.id or "-"),
            tostring(target and target.name or "-"),
            from_x or -1,
            from_y or -1,
            tostring(blocked_dir),
            dest_x or -1,
            dest_y or -1,
            tostring(approach or "-"),
            tostring(source or "-"),
            tostring(is_npc_block == true),
            tostring(block_data and block_data.timing_suspect == true),
            is_npc_block and "-" or command))
        clear_active_route_context("stop on blocker", should_refresh_objects_after_route())
        if is_npc_block then
            tolk.output_interrupt(string.format(
                "Auto-walk stopped at NPC blocker from %d,%d %s to %d,%d. Do not patch unless it repeats without NPC clutter.",
                from_x or -1,
                from_y or -1,
                tostring(blocked_dir),
                dest_x or -1,
                dest_y or -1))
        else
            tolk.output_interrupt(string.format(
                "Auto-walk stopped at blocker from %d,%d %s to %d,%d. Runtime patch: %s",
                from_x or -1,
                from_y or -1,
                tostring(blocked_dir),
                dest_x or -1,
                dest_y or -1,
                command))
        end
        return
    end

    if seam_class == nil then
        record_blocked_observation()
    end

    if is_suspect_route_timeout(block_data)
       and not is_seam_retry_block
       and not is_npc_block
       and seam_class ~= "confirmed_blocked"
       and start_seam_bruteforce(map_id, from_x, from_y, blocked_dir, block_data) then
        record_active_route_temp_block(map_id, from_x, from_y, blocked_dir, "timing_retry")
        debug_tools.info(string.format(
            "AUTO_WALK_TIMING_RETRY map=0x%02X from=(%d,%d) dir=%s movement_start_frame=%s timeout_retries=%s turn_represses=%s",
            map_id,
            from_x or -1,
            from_y or -1,
            tostring(blocked_dir),
            tostring(block_data and block_data.movement_start_frame),
            tostring(block_data and block_data.timeout_retries),
            tostring(block_data and block_data.turn_represses)))
        return
    end

    local reactive_npc_parked = false
    if is_npc_block
       and active_route_npc_mode == "park_mobile_npcs"
       and is_mobile_npc_blocker(npc_blocker) then
        reactive_npc_parked = add_live_npc_to_autowalk_parking(map_id, npc_blocker, "blocked_step")
    end

    local _, px, py = nav.get_position()
    if seam_class ~= "confirmed_blocked" and not is_npc_block then
        record_active_route_temp_block(map_id, from_x, from_y, blocked_dir, source)
    end

    local reroute_opts = active_route_planning_opts({
        map_id = map_id,
        start_x = px,
        start_y = py,
        allow_adjacent_fallback = true,
        allow_hazards = active_route_allow_hazards,
        store_debug_path = false,
    }, "blocked_step_reroute")
    local blocking = prepare_route_planning_blocking(map_id, reroute_opts)
    reroute_opts.blocking = blocking
    local plan = plan_path_to_object(last_pathfind_obj, reroute_opts)
    if active_route_allow_hazards then
        plan = maybe_stop_before_hazard(plan)
    end

    if plan.result == "No path found"
    and not is_npc_block
    and count_active_route_temp_blocks(map_id) > 1
    and clear_active_route_temp_blocks_except(
        map_id,
        from_x,
        from_y,
        blocked_dir,
        "blocked_step_reroute_no_path") > 0 then
        reroute_opts = active_route_planning_opts({
            map_id = map_id,
            start_x = px,
            start_y = py,
            allow_adjacent_fallback = true,
            allow_hazards = active_route_allow_hazards,
            store_debug_path = false,
        }, "blocked_step_reroute_relaxed")
        blocking = prepare_route_planning_blocking(map_id, reroute_opts)
        reroute_opts.blocking = blocking
        plan = plan_path_to_object(last_pathfind_obj, reroute_opts)
        if active_route_allow_hazards then
            plan = maybe_stop_before_hazard(plan)
        end
    end

    if plan.result == "No path found"
    and seam_class ~= "confirmed_blocked"
    and not is_npc_block
    and start_seam_bruteforce(map_id, from_x, from_y, blocked_dir, block_data) then
        return
    end

    reroute_failures = reroute_failures + 1
    if reroute_failures >= REROUTE_FAILURE_LIMIT then
        debug_tools.info("reroute_failures=" .. reroute_failures .. ": giving up on " .. last_pathfind_obj.name)
        event_bus.publish("route_cancelled", {
            reason = "reroute_failure_limit",
            target = last_pathfind_obj,
            map_id = map_id,
            from_x = from_x,
            from_y = from_y,
            blocked_dir = blocked_dir,
        })
        clear_active_route_context("reroute failure limit reached", should_refresh_objects_after_route())
        tolk.output_interrupt("Cannot reach destination. Pathfinding cancelled.")
        return
    end

    if plan.result == "No path found" then
        event_bus.publish("route_cancelled", {
            reason = is_npc_block and not reactive_npc_parked and "reroute_npc_block" or "reroute_no_path",
            target = last_pathfind_obj,
            map_id = map_id,
            from_x = from_x,
            from_y = from_y,
            blocked_dir = blocked_dir,
        })
        clear_active_route_context("no path found on reroute", should_refresh_objects_after_route())
        if is_npc_block and not reactive_npc_parked then
            tolk.output_interrupt(npc_blocked_route_message(npc_blocker))
        else
            tolk.output_interrupt("No path found. Pathfinding cancelled.")
        end
        return
    end

    clear_seam_retry_state()
    local msg = "Re-routing. " .. build_pathfind_message(
        last_pathfind_obj,
        plan.result,
        plan.face_dir,
        plan.no_path_reason)
    tolk.output_interrupt(msg)

    if plan.path and #plan.path > 0 then
        if queue_path_steps(plan.path, {
            map_id = map_id,
            settle_frames = active_route_settle_frames,
            initial_settle_frames = route_turn_settle_frames(),
        }) then
            update_active_route_remaining(#plan.path, should_face_after_plan(plan) and plan.face_dir or nil, plan.hazard_stop)
        end
    else
        clear_active_route_context("reroute reached destination", should_refresh_objects_after_route())
    end
end

do
    (function()
        local function finish_active_route_arrival(reason, opts)
            opts = opts or {}
            local overworld_segment = active_overworld_segment
            local target = opts.target or active_route_target or last_pathfind_obj
            local face_dir = opts.face_dir or active_route_face_dir
            local total_steps = active_route_total_steps
            local completion_actions = active_route_completion_actions
            local speak_completion = active_route_speak_completion
            local hazard_stop = active_route_hazard_stop
            local continuous_overworld = overworld_segment
                and overworld_segment.continuous == true
            local stop_on_blocker = overworld_segment
                and overworld_segment.stop_on_blocker == true

            if opts.publish_route_completed == true then
                event_bus.publish("route_completed")
            end
            clear_active_route_context(reason or "autowalk route complete",
                should_refresh_objects_after_route())

            if overworld_segment then
                debug_tools.info(string.format(
                    "OVERWORLD_AUTO_WALK: event=complete route=%s waypoint=%s index=%s steps=%s",
                    tostring(overworld_segment.route_id or "-"),
                    tostring(overworld_segment.waypoint_name or "-"),
                    tostring(overworld_segment.index),
                    tostring(overworld_segment.steps)))
            end

            if overworld_segment and overworld_segment.recovery == true then
                local map_id, px, py = nav.get_position()
                if overworld_segment.recovery_checkpoint == true then
                    debug_tools.info(string.format(
                        "OVERWORLD_RECOVERY_AUTO_WALK event=checkpoint_complete map=0x%02X position=(%s,%s) target=(%s,%s) entry=(%s,%s) steps=%s remaining_steps=%s final=%s continuous_requested=%s checkpoint_stop=true boundary_stop=false",
                        map_id or -1,
                        tostring(px),
                        tostring(py),
                        tostring(overworld_segment.target_x),
                        tostring(overworld_segment.target_y),
                        tostring(overworld_segment.waypoint_x),
                        tostring(overworld_segment.waypoint_y),
                        tostring(overworld_segment.steps),
                        tostring(overworld_segment.remaining_steps),
                        tostring(overworld_segment.final_destination_id or "-"),
                        tostring(overworld_segment.continuous_requested == true)))
                    tolk.output_interrupt(string.format(
                        "Recovery checkpoint reached. The waypoint network remains about %s safe steps away. Final destination: %s. Press auto-walk again to continue recovery.",
                        tostring(overworld_segment.remaining_steps or "several"),
                        tostring(overworld_segment.final_destination_title
                            or "selected destination")))
                    return
                end
                local handoff, handoff_err = overworld_routes.start(
                    overworld_segment.final_destination_id,
                    map_id,
                    px,
                    py,
                    {terrain_offset = snapshot.terrain_offset})
                local next_name = handoff and handoff.waypoint
                    and handoff.waypoint.name
                    or overworld_segment.next_waypoint_name
                    or "the next guided waypoint"
                debug_tools.info(string.format(
                    "OVERWORLD_RECOVERY_AUTO_WALK event=complete map=0x%02X position=(%s,%s) entry=(%s,%s) final=%s handoff_route=%s next=%s continuous_requested=%s boundary_stop=true result=%s",
                    map_id or -1,
                    tostring(px),
                    tostring(py),
                    tostring(overworld_segment.waypoint_x),
                    tostring(overworld_segment.waypoint_y),
                    tostring(overworld_segment.final_destination_id or "-"),
                    tostring(handoff and handoff.route and handoff.route.id or "-"),
                    tostring(next_name),
                    tostring(overworld_segment.continuous_requested == true),
                    handoff and "handoff_ready" or tostring(handoff_err or "handoff_failed")))
                if handoff then
                    tolk.output_interrupt(string.format(
                        "Recovery complete. Waypoint network reached at %s. Final destination: %s. Next: %s. Press auto-walk again to continue.",
                        tostring(overworld_segment.waypoint_name or "the safe entry"),
                        tostring(overworld_segment.final_destination_title or "selected destination"),
                        tostring(next_name)))
                else
                    tolk.output_interrupt(string.format(
                        "Recovery complete. Waypoint network reached, but route handoff failed: %s. Use route status before continuing.",
                        tostring(handoff_err or "unknown route")))
                end
                return
            end

            if continuous_overworld then
                local active_route_id = overworld_routes.active_route_id()
                if not active_route_id then
                    debug_tools.info(string.format(
                        "OVERWORLD_AUTO_WALK: event=continuous_stop route=%s waypoint=%s index=%s reason=route_finished",
                        tostring(overworld_segment.route_id or "-"),
                        tostring(overworld_segment.waypoint_name or "-"),
                        tostring(overworld_segment.index)))
                    return
                end

                local next_segment = M.autowalk_overworld_segment({
                    speak = false,
                    overworld_continuous = true,
                    stop_on_blocker = stop_on_blocker,
                })
                if next_segment and next_segment.status == "queued" then
                    debug_tools.info(string.format(
                        "OVERWORLD_AUTO_WALK: event=continue route=%s waypoint=%s index=%s",
                        tostring(next_segment.route and next_segment.route.id or active_route_id),
                        tostring(next_segment.waypoint and next_segment.waypoint.name or "-"),
                        tostring(next_segment.index)))
                else
                    debug_tools.info(string.format(
                        "OVERWORLD_AUTO_WALK: event=continuous_stop route=%s waypoint=%s index=%s reason=%s",
                        tostring(overworld_segment.route_id or active_route_id or "-"),
                        tostring(overworld_segment.waypoint_name or "-"),
                        tostring(overworld_segment.index),
                        tostring(next_segment and next_segment.status or "unavailable")))
                end
                return
            end

            if target then
                if hazard_stop then
                    local msg = "Auto-walk stopped before hazard"
                    if total_steps and total_steps > 0 then
                        msg = msg .. string.format(" after %d steps", total_steps)
                    end
                    msg = msg .. ". " .. build_hazard_warning(hazard_stop.summary)
                    if speak_completion then
                        tolk.output_interrupt(msg)
                    end
                    return
                end

                local msg = string.format("Auto-walk complete. Arrived at %s",
                    target.name or "destination")
                if total_steps and total_steps > 0 then
                    msg = msg .. string.format(" after %d steps", total_steps)
                end
                if completion_actions then
                    queue_target_face(face_dir, target)
                end
                if completion_actions
                   and target.type == objects.TYPE_NPC
                   and start_target_npc_hold(target) then
                    msg = msg .. ". Target held briefly. Use TALK now"
                end
                if speak_completion then
                    tolk.output_interrupt(msg)
                end
            elseif speak_completion then
                tolk.output_interrupt("Auto-walk complete")
            end
        end

        -- The overworld route observer sees a newly reached tile before
        -- auto_step sees that same position change later in the frame. Stop
        -- the queued route immediately on terminal arrival so a sticky final
        -- direction cannot carry the hero one tile past the destination.
        function M.on_overworld_route_event(route_event)
            local overworld_segment = active_overworld_segment
            if not route_event
               or route_event.terminal ~= true
               or not overworld_segment then
                return false
            end

            local event_route_id = route_event.route and route_event.route.id
            if event_route_id ~= nil
               and overworld_segment.route_id ~= nil
               and event_route_id ~= overworld_segment.route_id then
                return false
            end

            auto_step.cancel_active_step(true, true)
            finish_active_route_arrival("overworld terminal arrival observed")
            return true
        end

auto_step.on_step_complete = function(from_x, from_y, dir, to_x, to_y, step_data)
    if path_debug.is_validating and path_debug.is_validating() then
        debug_tools.debug("route_manager: ignoring step completion during validation")
        return
    end
    if path_debug.is_step_mode and path_debug.is_step_mode() then
        debug_tools.debug("route_manager: ignoring step completion during step mode")
        return
    end

    local map_id = nav.get_position()
    M._overworld_hazard_confirmation.after_step(map_id, to_x, to_y)
    local step_source = step_data and step_data.source or "step_complete"
    local input_source = step_data and step_data.input_source or step_source
    observe_seam_result(
        map_id,
        from_x,
        from_y,
        dir,
        "moved",
        step_source)
    clear_active_route_temp_block_for_step(
        map_id,
        from_x,
        from_y,
        dir,
        step_source)
    reroute_failures = 0
    if step_data and step_data.queued_route then
        route_drift_reroutes = 0
    end
    if step_data and step_data.queued_route and active_route_total_steps > 0 then
        active_route_completed_steps = active_route_completed_steps + 1
        local progress_interval = config_int("auto_walk_progress_interval", 6, 0, 60)
        if progress_interval > 0
           and not (active_overworld_segment and active_overworld_segment.continuous == true)
           and active_route_total_steps > progress_interval
           and active_route_completed_steps < active_route_total_steps
           and active_route_completed_steps % progress_interval == 0 then
            speak_noninterrupting(string.format(
                "Auto-walk %d of %d steps",
                active_route_completed_steps,
                active_route_total_steps))
        end
    end

    if not same_seam_retry(map_id, from_x, from_y, dir) then
        if seam_retry_state then
            clear_seam_retry_state()
        end
        return
    end

    local target = last_pathfind_obj
    clear_seam_retry_state()
    if not target then
        return
    end

    local plan = plan_path_to_object(target, active_route_planning_opts({
        map_id = map_id,
        start_x = to_x,
        start_y = to_y,
        allow_adjacent_fallback = true,
        allow_hazards = active_route_allow_hazards,
        store_debug_path = false,
    }, "seam_retry_followup"))
    if active_route_allow_hazards then
        plan = maybe_stop_before_hazard(plan)
    end

    if plan.result == "No path found" and count_active_route_temp_blocks(map_id) > 0 then
        clear_active_route_temp_blocks(map_id, "seam_retry_followup_no_path")
        plan = plan_path_to_object(target, active_route_planning_opts({
            map_id = map_id,
            start_x = to_x,
            start_y = to_y,
            allow_adjacent_fallback = true,
            allow_hazards = active_route_allow_hazards,
            store_debug_path = false,
        }, "seam_retry_followup_relaxed"))
        if active_route_allow_hazards then
            plan = maybe_stop_before_hazard(plan)
        end
    end

    if plan.result == "No path found" and count_active_route_temp_blocks(map_id) == 0 then
        debug_tools.info(string.format(
            "AUTO_WALK_SEAM_FOLLOWUP_RETRY map=0x%02X start=(%d,%d) target_id=%s target_name=%s reason=no_path_after_cleared_temp_blocks",
            map_id or -1,
            to_x or -1,
            to_y or -1,
            tostring(target and target.id or "-"),
            tostring(target and target.name or "-")))
        plan = plan_path_to_object(target, active_route_planning_opts({
            map_id = map_id,
            start_x = to_x,
            start_y = to_y,
            allow_adjacent_fallback = true,
            allow_hazards = active_route_allow_hazards,
            store_debug_path = false,
            refresh_npcs = true,
        }, "seam_retry_followup_refreshed"))
        if active_route_allow_hazards then
            plan = maybe_stop_before_hazard(plan)
        end
    end

    if plan.result == "No path found" then
        event_bus.publish("route_cancelled", {
            reason = "seam_bruteforce_no_path",
            target = target,
            map_id = map_id,
            from_x = from_x,
            from_y = from_y,
            blocked_dir = dir,
        })
        clear_active_route_context("no path found after seam brute force", should_refresh_objects_after_route())
        tolk.output_interrupt("No path found after seam crossing. Pathfinding cancelled.")
        return
    end

    if not plan.path or #plan.path == 0 then
        if plan.hazard_stop then
            clear_active_route_context("seam brute force hazard boundary", should_refresh_objects_after_route())
            tolk.output_interrupt("Seam crossed. " .. build_hazard_warning(plan.hazard_stop.summary, "Hazard ahead."))
            return
        end
        finish_active_route_arrival("seam brute force reached destination", {
            target = target,
            face_dir = should_face_after_plan(plan) and plan.face_dir or nil,
            publish_route_completed = true,
        })
        return
    end

    if not queue_path_steps(plan.path, {
        map_id = map_id,
        settle_frames = active_route_settle_frames,
        initial_settle_frames = route_turn_settle_frames(),
    }) then
        clear_active_route_context("queue failure after seam brute force", should_refresh_objects_after_route())
        tolk.output_interrupt("Seam crossed, but auto-walk could not queue the follow-up route.")
        return
    end
    update_active_route_remaining(#plan.path, should_face_after_plan(plan) and plan.face_dir or nil, plan.hazard_stop)

    tolk.output_interrupt("Seam crossed. " .. build_pathfind_message(
        target,
        plan.result,
        plan.face_dir,
        plan.no_path_reason))
end

auto_step.on_route_complete = function()
    finish_active_route_arrival("autowalk route complete")
end
    end)()
end

auto_step.on_route_cancelled = function(cancel_data)
    local reason = cancel_data and cancel_data.reason or "auto_step_cancelled"
    local message = cancel_data and cancel_data.message
    local overworld_segment = active_overworld_segment
    local had_target = active_route_target or last_pathfind_obj
    if overworld_segment then
        debug_tools.info(string.format(
            "OVERWORLD_AUTO_WALK: event=cancel route=%s waypoint=%s index=%s reason=%s current=(%s,%s) expected_carry=(%s,%s)",
            tostring(overworld_segment.route_id or "-"),
            tostring(overworld_segment.waypoint_name or "-"),
            tostring(overworld_segment.index),
            tostring(reason),
            tostring(cancel_data and cancel_data.current_x),
            tostring(cancel_data and cancel_data.current_y),
            tostring(overworld_segment.route_final_carry_x),
            tostring(overworld_segment.route_final_carry_y)))
        if overworld_segment.recovery == true then
            debug_tools.info(string.format(
                "OVERWORLD_RECOVERY_AUTO_WALK event=cancel reason=%s current=(%s,%s) entry=(%s,%s) final=%s",
                tostring(reason),
                tostring(cancel_data and cancel_data.current_x),
                tostring(cancel_data and cancel_data.current_y),
                tostring(overworld_segment.waypoint_x),
                tostring(overworld_segment.waypoint_y),
                tostring(overworld_segment.final_destination_id or "-")))
        end
        clear_active_route_context("overworld auto_step route cancelled: " .. tostring(reason), should_refresh_objects_after_route())
        if M._overworld_hazard_confirmation.arm(cancel_data, overworld_segment) then
            tolk.output_interrupt(
                "Poison swamp ahead. Auto-walk stopped. Press auto-walk again to continue through this swamp.")
        else
            M._overworld_hazard_confirmation.clear("overworld route cancelled: " .. tostring(reason))
            if reason ~= "can_walk_false" then
                local prefix = overworld_segment.recovery == true
                    and "Recovery auto-walk cancelled. "
                    or "Overworld auto-walk cancelled. "
                tolk.output_interrupt(prefix .. tostring(message or reason))
            end
        end
        return
    end
    M._overworld_hazard_confirmation.clear("non-overworld route cancelled: " .. tostring(reason))
    if reason == "route_drift_off_path"
       and reroute_after_route_drift(cancel_data, had_target) then
        return
    end
    clear_active_route_context("auto_step route cancelled: " .. tostring(reason), should_refresh_objects_after_route())
    if had_target and reason ~= "can_walk_false" then
        tolk.output_interrupt("Auto-walk cancelled. " .. tostring(message or reason))
    end
end

auto_step.on_walkability_lost = function()
    M._overworld_hazard_confirmation.clear("field actions unavailable")
end

-- ============================================================
-- Map Change Handler
-- ============================================================

-- on_map_change(): Clear all route-related state when the player enters
-- a new map. Called from the main loop's check_map_change().
function M.on_map_change()
    if last_pathfind_obj then
        event_bus.publish("route_cancelled", {
            reason = "map_changed",
            target = last_pathfind_obj,
            map_id = snapshot.map_id,
        })
    end
    runtime_blocked = {}
    M._suppress_pending_overworld_timeout_observation("map_changed")
    M._overworld_hazard_confirmation.clear("map change")
    clear_seam_retry_state()
    release_target_face("map change")
    release_target_npc_hold("map change")
    clear_active_route_context("map change", false)
end

-- ============================================================
-- State Queries (for debug commands)
-- ============================================================

-- get_last_pathfind_obj(): Return the current pathfind target (or nil).
function M.get_last_pathfind_obj()
    return last_pathfind_obj
end

function M.get_active_route_npc_mode()
    return active_route_npc_mode
end

function M.clear_active_route_context(reason)
    clear_active_route_context(reason, true)
end

-- stop_auto_walk(reason): Cancel every layer of active movement assistance.
-- Returns true when an auto-step route or route-manager target was active.
function M.stop_auto_walk(reason)
    local had_active = active_route_target ~= nil
        or active_overworld_segment ~= nil
        or (auto_step.is_route_active and auto_step.is_route_active())
    local stop_reason = tostring(reason or "manual stop_auto_walk")
    M._overworld_hazard_confirmation.clear(stop_reason)

    if not had_active then
        debug_tools.info(string.format(
            "AUTO_WALK: manually stopped active=false reason=%s", stop_reason))
        return false
    end

    auto_step.cancel_active_step(true, true)
    clear_active_route_context(stop_reason, should_refresh_objects_after_route())
    debug_tools.info(string.format(
        "AUTO_WALK: manually stopped active=%s reason=%s",
        tostring(had_active), stop_reason))
    return had_active
end

-- get_dir_to_delta(): Return the direction-to-delta table.
-- Used by debug diagnostic functions.
function M.get_dir_to_delta()
    return DIR_TO_DELTA
end

-- ============================================================
-- Debug Command Registration
-- ============================================================
-- Registers runtime-block debug commands with debug_tools.
-- Called once from main.lua during startup.

function M.register_debug_commands(get_map_id_fn)
    -- Helper: parse "X,Y" or "MAP_ID,X,Y" argument.
    local function parse_int(token)
        if not token then return nil end
        token = token:match("^%s*(.-)%s*$")
        if token == "" then return nil end
        if token:match("^[-+]?0[xX][%da-fA-F]+$") then return tonumber(token) end
        if token:match("^[-+]?%d+$") then return tonumber(token) end
        return nil
    end

    local function parse_xy(arg)
        if not arg then return nil end
        local xs, ys = arg:match("^%s*([^,]+)%s*,%s*([^,]+)%s*$")
        if not xs then return nil end
        local x, y = parse_int(xs), parse_int(ys)
        if x == nil or y == nil then return nil end
        return x, y
    end

    local function parse_map_xy(arg, default_map)
        if not arg then return nil end
        local a, b, c = arg:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")
        if a and b and c then
            local mid, x, y = parse_int(a), parse_int(b), parse_int(c)
            if mid == nil or x == nil or y == nil then return nil end
            return mid, x, y
        end
        local x, y = parse_xy(arg)
        if x == nil then return nil end
        return default_map, x, y
    end

    local function parse_direction(token)
        if not token then return nil end
        local dir = token:match("^%s*(.-)%s*$"):lower()
        return DIR_NAME_TO_KEY[dir] or (DIR_TO_DELTA[dir] and dir) or nil
    end

    local function parse_map_xy_dir(arg, default_map)
        if not arg then return nil end
        local a, b, c, d = arg:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")
        if a and b and c and d then
            local mid, x, y = parse_int(a), parse_int(b), parse_int(c)
            local dir = parse_direction(d)
            if mid == nil or x == nil or y == nil or dir == nil then return nil end
            return mid, x, y, dir
        end
        local xs, ys, ds = arg:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")
        if not xs then return nil end
        local x, y = parse_int(xs), parse_int(ys)
        local dir = parse_direction(ds)
        if x == nil or y == nil or dir == nil then return nil end
        return default_map, x, y, dir
    end

    debug_tools.register_command("add_blocked_tile", function(arg)
        local mid, x, y = parse_map_xy(arg, get_map_id_fn())
        if mid == nil then
            debug_tools.error("add_blocked_tile usage: add_blocked_tile:X,Y or add_blocked_tile:MAP_ID,X,Y")
            return
        end
        local added = M.inject_runtime_block(mid, x, y)
        if added then
            tolk.output_interrupt(string.format("Added blocked tile %d,%d on map %02X", x, y, mid))
        else
            tolk.output_interrupt(string.format("Blocked tile %d,%d already injected on map %02X", x, y, mid))
        end
    end)

    debug_tools.register_command("add_blocked_edge", function(arg)
        local mid, x, y, dir = parse_map_xy_dir(arg, get_map_id_fn())
        if mid == nil then
            debug_tools.error("add_blocked_edge usage: add_blocked_edge:X,Y,DIR or add_blocked_edge:MAP_ID,X,Y,DIR")
            return
        end
        local added = M.inject_runtime_block_for_step(mid, x, y, dir, "manual_edge_command")
        if added then
            tolk.output_interrupt(string.format("Added blocked edge from %d,%d %s on map %02X", x, y, dir, mid))
        else
            tolk.output_interrupt(string.format("Blocked edge from %d,%d %s already injected on map %02X", x, y, dir, mid))
        end
    end)

    debug_tools.register_command("list_blocked_tiles", function(arg)
        local mid = get_map_id_fn()
        if arg and arg ~= "" then
            mid = parse_int(arg)
            if mid == nil then
                debug_tools.error("list_blocked_tiles usage: list_blocked_tiles or list_blocked_tiles:MAP_ID")
                return
            end
        end
        local entries = collect_runtime_blocks(mid)
        if #entries == 0 then
            debug_tools.info(string.format("RUNTIME_BLOCKS map=0x%02X none", mid))
            tolk.output_interrupt(string.format("No runtime blocked tiles on map %02X", mid))
        else
            debug_tools.info(string.format("RUNTIME_BLOCKS map=0x%02X count=%d", mid, #entries))
            for _, entry in ipairs(entries) do
                debug_tools.info(string.format(
                    "RUNTIME_BLOCK map=0x%02X x=%d y=%d key=%s",
                    mid, entry.x, entry.y, entry.key))
            end
            tolk.output_interrupt(string.format("%d runtime blocked tiles on map %02X", #entries, mid))
        end
    end)

    debug_tools.register_command("report_seam_cells", function(arg)
        local mid = get_map_id_fn()
        if arg and arg ~= "" then
            mid = parse_int(arg)
            if mid == nil then
                debug_tools.error("report_seam_cells usage: report_seam_cells or report_seam_cells:MAP_ID")
                return
            end
        end
        local summary = get_seam_summary(mid)
        debug_tools.info(string.format(
            "SEAM_SUMMARY map=0x%02X total=%d confirmed_blocked=%d noisy=%d blocked_only=%d passable_only=%d",
            mid,
            summary.total,
            summary.confirmed_blocked,
            summary.noisy,
            summary.blocked_only,
            summary.passable_only))
        if summary.total == 0 then
            tolk.output_interrupt(string.format("No seam observations on map %02X", mid))
        else
            tolk.output_interrupt(string.format(
                "%d seam observations on map %02X. %d confirmed blocked, %d noisy.",
                summary.total,
                mid,
                summary.confirmed_blocked,
                summary.noisy))
        end
    end)

    debug_tools.register_command("list_seam_cells", function(arg)
        local mid = get_map_id_fn()
        if arg and arg ~= "" then
            mid = parse_int(arg)
            if mid == nil then
                debug_tools.error("list_seam_cells usage: list_seam_cells or list_seam_cells:MAP_ID")
                return
            end
        end
        local entries = collect_seam_entries(mid)
        if #entries == 0 then
            debug_tools.info(string.format("SEAM_LIST map=0x%02X none", mid))
            tolk.output_interrupt(string.format("No seam observations on map %02X", mid))
            return
        end
        debug_tools.info(string.format("SEAM_LIST map=0x%02X count=%d", mid, #entries))
        for _, entry in ipairs(entries) do
            debug_tools.info(string.format(
                "SEAM_CELL map=0x%02X x=%d y=%d approach=%s blocked=%d moved=%d classification=%s",
                mid,
                entry.x,
                entry.y,
                entry.approach,
                entry.blocked_count,
                entry.moved_count,
                entry.classification))
        end
        tolk.output_interrupt(string.format("%d seam observations on map %02X", #entries, mid))
    end)

    debug_tools.register_command("clear_blocked_tiles", function(arg)
        if arg and arg:match("^%s*all%s*$") then
            M.clear_runtime_blocks("all")
            tolk.output_interrupt("Cleared blocked tiles for all maps")
            return
        end
        local mid = get_map_id_fn()
        if arg and arg ~= "" then
            mid = parse_int(arg)
            if mid == nil then
                debug_tools.error("clear_blocked_tiles usage: clear_blocked_tiles, clear_blocked_tiles:MAP_ID, or clear_blocked_tiles:all")
                return
            end
        end
        M.clear_runtime_blocks(mid)
        tolk.output_interrupt(string.format("Cleared blocked tiles for map %02X", mid))
    end)

    debug_tools.register_command("clear_seam_cells", function(arg)
        if arg and arg:match("^%s*all%s*$") then
            M.clear_seam_memory("all")
            tolk.output_interrupt("Cleared seam observations for all maps")
            return
        end
        local mid = get_map_id_fn()
        if arg and arg ~= "" then
            mid = parse_int(arg)
            if mid == nil then
                debug_tools.error("clear_seam_cells usage: clear_seam_cells, clear_seam_cells:MAP_ID, or clear_seam_cells:all")
                return
            end
        end
        M.clear_seam_memory(mid)
        tolk.output_interrupt(string.format("Cleared seam observations for map %02X", mid))
    end)

    debug_tools.register_command("is_blocked_tile", function(arg)
        local mid, x, y = parse_map_xy(arg, get_map_id_fn())
        if mid == nil then
            debug_tools.error("is_blocked_tile usage: is_blocked_tile:X,Y or is_blocked_tile:MAP_ID,X,Y")
            return
        end
        local rt_blocked = M.is_cell_runtime_blocked(mid, x, y)
        local walkable = M.is_pathfinding_walkable(mid, x, y)
        debug_tools.info(string.format(
            "BLOCKED_TILE_CHECK map=0x%02X x=%d y=%d runtime_blocked=%s effective_passable=%s",
            mid, x, y, tostring(rt_blocked), tostring(walkable)))
        tolk.output_interrupt(string.format(
            "Blocked tile check map %02X at %d,%d. runtime_blocked=%s. effective_passable=%s",
            mid, x, y, tostring(rt_blocked), tostring(walkable)))
    end)

    debug_tools.register_command("dump_blocked_tiles", function(arg)
        local mid = get_map_id_fn()
        if arg and arg ~= "" then
            mid = parse_int(arg)
            if mid == nil then
                debug_tools.error("dump_blocked_tiles usage: dump_blocked_tiles or dump_blocked_tiles:MAP_ID")
                return
            end
        end
        local lines, count = M.format_runtime_blocks_as_lua(mid)
        debug_tools.info(string.format("RUNTIME_BLOCK_EXPORT map=0x%02X count=%d", mid, count))
        if count == 0 then
            debug_tools.info("RUNTIME_BLOCK_EXPORT: no runtime blocked tiles to dump")
            tolk.output_interrupt(string.format("No runtime blocked tiles to dump for map %02X", mid))
        else
            debug_tools.info("=== runtime blocked tiles (copy into MAP_BLOCKED_CELLS) ===")
            for _, line in ipairs(lines) do
                debug_tools.info(line)
            end
            debug_tools.info("=== end runtime blocked tiles ===")
            tolk.output_interrupt(string.format("Dumped %d runtime blocked tiles for map %02X", count, mid))
        end
    end)

    debug_tools.register_command("park_npcs", function(arg)
        local result, err = M.manual_park_npcs(arg)
        if not result then
            debug_tools.error(err)
            return
        end
        debug_tools.info(string.format(
            "MANUAL_NPC_PARK mode=%s parked_slots=%d active=%s",
            result.mode,
            result.parked_slots or 0,
            tostring(result.active)))
        tolk.output_interrupt(string.format(
            "Parked %d %s NPC slot(s).",
            result.parked_slots or 0,
            result.mode))
    end)

    debug_tools.register_command("restore_parked_npcs", function()
        local result = M.restore_manual_parked_npcs("manual restore parked npcs")
        debug_tools.info(string.format(
            "MANUAL_NPC_PARK_RESTORE had_active=%s active=%s",
            tostring(result.had_active),
            tostring(result.active)))
        if result.active then
            tolk.output_interrupt("Parked NPC restore deferred.")
        elseif result.had_active then
            tolk.output_interrupt("Parked NPCs restored.")
        else
            tolk.output_interrupt("No parked NPCs to restore.")
        end
    end)
end

return M
