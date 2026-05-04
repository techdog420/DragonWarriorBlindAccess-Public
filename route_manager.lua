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
local emulator_compat = rawget(_G, "DW_EMULATOR_COMPAT") or {}

local M = {}

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

-- ============================================================
-- State
-- ============================================================

-- Last object the player pathfound to. Kept so on_blocked can re-route
-- to the same target when a moving NPC blocks a step.
local last_pathfind_obj = nil

-- Consecutive on_blocked calls without a successful step.
-- After REROUTE_FAILURE_LIMIT, pathfinding is cancelled.
local reroute_failures = 0
local REROUTE_FAILURE_LIMIT = 3

-- NPC freeze: lock NPC positions in RAM for reliable pathfinding.
-- When active, apply_npc_freeze() restores NPC bytes to their snapshot
-- values after every FCEU.frameadvance(), undoing any AI movement.
local npc_freeze_active = false
local frozen_npc_snapshot = {}  -- Array [0..19] of {b0, b1, b2}

-- Runtime engine-blocked cells discovered during auto-step timeouts.
-- These are the CONFIRMED route blockers that pathfinding should avoid.
-- Noisy seam observations live in a separate table below so mixed cells do
-- not get promoted into permanent-looking route facts too early.
local runtime_blocked = {}
local seam_memory = {}
local seam_retry_state = nil
local autowalk_guard = nil
local active_route_settle_frames = 0
local active_route_target = nil
local active_route_face_dir = nil
local active_route_total_steps = 0
local active_route_completed_steps = 0
local target_npc_hold = nil
local target_face_input = nil
local SURVEY_ROUTE_SETTLE_FRAMES = 30
local TARGET_FACE_RELEASE_FRAMES = 2
local SEAM_CONFIRM_BLOCK_THRESHOLD = 3
local SEAM_BRUTE_FORCE_RETRY_LIMIT = 2
local APPROACH_ORDER = {north = 1, south = 2, west = 3, east = 4}

local function cell_key(x, y)
    return x .. "," .. y
end

local function log_route_plan_timing(plan, elapsed_ms)
    if not plan or elapsed_ms < 25 then
        return
    end
    local target = plan.target or {}
    debug_tools.info(string.format(
        "ROUTE_PLAN_TIMING map=0x%02X start=(%d,%d) target_id=%s target_name=%s mode=%s result=%s path_len=%d ms=%.3f",
        plan.map_id or -1,
        plan.start_x or -1,
        plan.start_y or -1,
        tostring(target.id or "-"),
        tostring(target.name or "-"),
        tostring(plan.path_mode or "-"),
        tostring(plan.result or "-"),
        plan.path and #plan.path or 0,
        elapsed_ms))
end

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

local function should_refresh_objects_after_route()
    if emulator_compat.is_bizhawk == true then
        return config_bool("bizhawk_route_cleanup_refresh_objects", false)
    end
    return true
end

local function adjacent_path_opts(opts)
    opts = opts or {}
    if opts.use_adjacent_metrics ~= nil or opts.survey_safe == true then
        return opts
    end
    local next_opts = {}
    for k, v in pairs(opts) do
        next_opts[k] = v
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

local function record_runtime_block(map_id, from_x, from_y, blocked_dir)
    if not map_id or from_x == nil or from_y == nil or not blocked_dir then
        return false
    end

    local dest_x, dest_y, approach = get_destination_for_dir(from_x, from_y, blocked_dir)
    local source = string.format("auto_step:%s from (%d,%d)", blocked_dir, from_x, from_y)

    -- Don't record if an NPC occupies the destination (NPC blocks are temporary)
    objects.update_npcs()
    local npc_positions = objects.get_blocking_positions()
    for _, npc in ipairs(npc_positions) do
        if npc.x == dest_x and npc.y == dest_y then
            debug_tools.debug("block at (" .. dest_x .. "," .. dest_y .. ") is NPC, not recording")
            return false
        end
    end

    return add_runtime_block_direction(map_id, dest_x, dest_y, approach, source)
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
        -- Only clear the runtime block when there is NO prior blocking evidence
        -- for this approach direction. A single "moved" in a seam that has also
        -- blocked (noisy classification) does NOT erase the runtime block — the
        -- block stays until the seam is purely passable. This prevents one
        -- state-contaminated probe from cancelling a seam-confirmed engine block
        -- and allowing A* to plan routes through an unreliable cell.
        if entry.blocked_count == 0 then
            clear_runtime_block_direction(map_id, dest_x, dest_y, approach, "successful traversal")
        end
    end

    entry.last_result = result
    entry.last_source = source
    entry.last_from_x = from_x
    entry.last_from_y = from_y

    if result == "blocked"
    and entry.moved_count == 0
    and entry.blocked_count >= SEAM_CONFIRM_BLOCK_THRESHOLD then
        add_runtime_block_direction(
            map_id,
            dest_x,
            dest_y,
            approach,
            string.format(
                "seam_confirm:%s blocked=%d moved=%d",
                tostring(source or "-"),
                entry.blocked_count,
                entry.moved_count))
    end

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

local function same_seam_retry(map_id, from_x, from_y, dir)
    return seam_retry_state
        and seam_retry_state.map_id == map_id
        and seam_retry_state.from_x == from_x
        and seam_retry_state.from_y == from_y
        and seam_retry_state.dir == dir
end

local function start_seam_bruteforce(map_id, from_x, from_y, dir)
    local attempts = 1
    if same_seam_retry(map_id, from_x, from_y, dir) then
        attempts = seam_retry_state.attempts + 1
    end
    if attempts > SEAM_BRUTE_FORCE_RETRY_LIMIT then
        return false
    end
    local dest_x, dest_y, approach = get_destination_for_dir(from_x, from_y, dir)
    seam_retry_state = {
        map_id = map_id,
        from_x = from_x,
        from_y = from_y,
        dir = dir,
        dest_x = dest_x,
        dest_y = dest_y,
        approach = approach,
        attempts = attempts,
    }
    debug_tools.info(string.format(
        "SEAM_BRUTE_FORCE map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d) attempt=%d/%d",
        map_id,
        from_x,
        from_y,
        tostring(dir),
        dest_x or -1,
        dest_y or -1,
        attempts,
        SEAM_BRUTE_FORCE_RETRY_LIMIT))
    auto_step.inject_step(dir)
    return true
end

local function clear_seam_retry_state()
    seam_retry_state = nil
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
    slot = tonumber(slot)
    if not slot or slot < 0 or slot >= addr.NPC_COUNT then
        return nil
    end
    return slot
end

local function release_target_npc_hold(reason)
    if target_npc_hold and reason then
        debug_tools.info("NPC target hold released: " .. reason)
    end
    target_npc_hold = nil
end

local function start_target_npc_hold(obj)
    if not obj or obj.type ~= objects.TYPE_NPC then
        return false
    end
    local frames = config_int("auto_walk_npc_hold_frames", 480, 0, 3600)
    if frames <= 0 then
        return false
    end
    local slot = parse_npc_slot(obj)
    if not slot then
        debug_tools.debug("NPC target hold skipped: could not parse slot for " .. tostring(obj.id))
        return false
    end

    local base = addr.NPC_DATA_START + slot * addr.NPC_ENTRY_SIZE
    target_npc_hold = {
        slot = slot,
        frames = frames,
        name = obj.name,
        snapshot = {
            memory.readbyte(base),
            memory.readbyte(base + 1),
            memory.readbyte(base + 2),
        },
    }
    debug_tools.info(string.format(
        "NPC target hold started: target=%s slot=%d frames=%d",
        tostring(obj.name), slot, frames))
    return true
end

local function freeze_npcs_for_pathing()
    capture_npc_snapshot()
    npc_freeze_active = true
end

-- apply_npc_freeze(): Restore snapshotted NPC bytes to RAM.
-- Call once per frame immediately after FCEU.frameadvance().
-- No-op when npc_freeze_active is false, so it's safe to call every frame.
function M.apply_npc_freeze()
    apply_target_face()
    if npc_freeze_active then
        for i = 0, addr.NPC_COUNT - 1 do
            local base = addr.NPC_DATA_START + i * addr.NPC_ENTRY_SIZE
            local snap = frozen_npc_snapshot[i]
            memory.writebyte(base,     snap[1])
            memory.writebyte(base + 1, snap[2])
            memory.writebyte(base + 2, snap[3])
        end
    end
    if target_npc_hold then
        local base = addr.NPC_DATA_START + target_npc_hold.slot * addr.NPC_ENTRY_SIZE
        local snap = target_npc_hold.snapshot
        memory.writebyte(base,     snap[1])
        memory.writebyte(base + 1, snap[2])
        memory.writebyte(base + 2, snap[3])
        target_npc_hold.frames = target_npc_hold.frames - 1
        if target_npc_hold.frames <= 0 then
            release_target_npc_hold("timer expired")
        end
    end
end

-- toggle_npc_freeze(): Toggle NPC position freeze on/off.
-- Returns true if freeze is now active, false if released.
function M.toggle_npc_freeze()
    if npc_freeze_active then
        npc_freeze_active = false
        frozen_npc_snapshot = {}
        release_target_npc_hold("manual unfreeze")
        tolk.output_interrupt("NPCs unfrozen.")
        return false
    else
        release_target_npc_hold("manual full freeze")
        capture_npc_snapshot()
        npc_freeze_active = true
        tolk.output_interrupt("NPCs frozen.")
        return true
    end
end

-- freeze_npcs() / unfreeze_npcs(): Direct control for remote commands.
function M.freeze_npcs()
    release_target_npc_hold("full freeze requested")
    capture_npc_snapshot()
    npc_freeze_active = true
end

function M.unfreeze_npcs()
    npc_freeze_active = false
    frozen_npc_snapshot = {}
    release_target_npc_hold("manual unfreeze")
end

-- is_npc_freeze_active(): Query freeze state (for can_walk guard, etc.)
function M.is_npc_freeze_active()
    return npc_freeze_active
end

-- set_autowalk_guard(fn): Install a main-loop-owned predicate used to veto
-- auto-walk starts when field-state gates say movement is unsafe.
-- fn() should return (ok, reason). ok=false prevents route planning and
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
    local blocking = {}
    if not (opts and opts.skip_npcs) then
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
                -- Copy the direction table so runtime blocks can be merged in
                local copy = {}
                for d, v in pairs(dirs) do copy[d] = v end
                blocking[k] = copy
            end
        end
    end
    -- Merge runtime directional blocks
    if runtime_blocked[map_id] then
        for k, dirs in pairs(runtime_blocked[map_id]) do
            if not blocking[k] then
                blocking[k] = dirs
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

-- is_pathfinding_walkable(map_id, x, y): Static walkability plus runtime overlay.
function M.is_pathfinding_walkable(map_id, x, y)
    if map_reader.is_walkable(map_id, x, y) ~= true then
        return false
    end
    if M.is_cell_runtime_blocked(map_id, x, y) then
        return false
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

local function clear_active_route_context(reason, refresh_objects)
    last_pathfind_obj = nil
    reroute_failures = 0
    active_route_settle_frames = 0
    active_route_target = nil
    active_route_face_dir = nil
    active_route_total_steps = 0
    active_route_completed_steps = 0
    release_target_face(reason or "route context cleared")
    clear_seam_retry_state()
    release_npc_freeze(reason)
    if refresh_objects then
        objects.request_refresh()
    end
end

local function set_active_route_context(target, path_len, face_dir)
    active_route_target = target
    active_route_face_dir = face_dir
    active_route_total_steps = tonumber(path_len) or 0
    active_route_completed_steps = 0
end

local function update_active_route_remaining(path_len, face_dir)
    local remaining = tonumber(path_len) or 0
    active_route_total_steps = active_route_completed_steps + remaining
    active_route_face_dir = face_dir
end

local function resolve_path_mode(obj, map_id, opts)
    opts = opts or {}
    local path_mode = opts.path_mode
    local target_walkable = M.is_pathfinding_walkable(map_id, obj.x, obj.y)
    if path_mode == "direct" or path_mode == "adjacent" then
        return path_mode, target_walkable
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
        map_id, start_x, start_y, obj.x, obj.y, blocking, adjacent_path_opts(opts))
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

local function find_closed_door_frontier(map_id, start_x, start_y, blocking)
    if not map_reader.get_map_dimensions or not map_reader.get_walkability_details then
        return nil
    end
    local width, height = map_reader.get_map_dimensions(map_id)
    if not width or not height then
        return nil
    end
    if not is_standable_for_hint(map_id, start_x, start_y, blocking) then
        return nil
    end

    local queue = {{x = start_x, y = start_y}}
    local seen = {[cell_key(start_x, start_y)] = true}
    local head = 1

    while head <= #queue do
        local current = queue[head]
        head = head + 1

        for _, dir in pairs(DIR_TO_DELTA) do
            local nx = current.x + dir.dx
            local ny = current.y + dir.dy
            if nx >= 0 and nx < width and ny >= 0 and ny < height then
                local nk = cell_key(nx, ny)
                if not seen[nk] then
                    local details = map_reader.get_walkability_details(map_id, nx, ny)
                    if details and details.reason == "door_closed" then
                        return {x = nx, y = ny}
                    end
                    if is_standable_for_hint(map_id, nx, ny, blocking) then
                        seen[nk] = true
                        queue[#queue + 1] = {x = nx, y = ny}
                    end
                end
            end
        end
    end

    return nil
end

local function infer_no_path_reason(map_id, start_x, start_y, blocking)
    if find_closed_door_frontier(map_id, start_x, start_y, blocking) then
        return "closed_door"
    end
    return nil
end

local function find_quiet_route_to_adjacent(map_id, start_x, start_y, goal_x, goal_y, blocking, opts)
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
    if maps.is_overworld(map_id, snapshot.terrain_offset) then
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

    local path_mode, target_walkable = resolve_path_mode(obj, map_id, opts)
    local goal_block_reason = get_goal_block_reason(blocking, obj.x, obj.y)
    local dist = math.abs(px - obj.x) + math.abs(py - obj.y)
    local path = nil
    local face_dir = nil
    local adjacent_diagnostics = nil
    local no_path_reason = nil

    if path_mode == "adjacent" then
        if dist <= 1 then
            return {
                target = obj,
                map_id = map_id,
                start_x = px,
                start_y = py,
                path_mode = path_mode,
                target_walkable = target_walkable,
                goal_block_reason = goal_block_reason,
                reachable = true,
                status = "adjacent",
            }
        end
        path, face_dir = find_quiet_route_to_adjacent(
            map_id, px, py, obj.x, obj.y, blocking, opts.pathfinder_opts)
    else
        if px == obj.x and py == obj.y then
            return {
                target = obj,
                map_id = map_id,
                start_x = px,
                start_y = py,
                path_mode = path_mode,
                target_walkable = target_walkable,
                goal_block_reason = goal_block_reason,
                reachable = true,
                status = "already_there",
            }
        elseif goal_block_reason == "npc" then
            no_path_reason = "goal_blocked_npc"
        elseif goal_block_reason == "runtime" then
            no_path_reason = "goal_blocked_runtime"
        else
            path = pathfinder.find_route_to(
                map_id, px, py, obj.x, obj.y, blocking, opts.pathfinder_opts)
        end

        if not path and obj.type == objects.TYPE_CHEST and opts.allow_adjacent_fallback ~= false then
            local fallback_path, fallback_face = find_quiet_route_to_adjacent(
                map_id, px, py, obj.x, obj.y, blocking, opts.pathfinder_opts)
            if fallback_path then
                path = fallback_path
                face_dir = fallback_face
                path_mode = "adjacent"
                no_path_reason = "direct_failed_adjacent_fallback"
            end
        end
    end

    return {
        target = obj,
        map_id = map_id,
        start_x = px,
        start_y = py,
        path_mode = path_mode,
        target_walkable = target_walkable,
        goal_block_reason = goal_block_reason,
        no_path_reason = no_path_reason,
        reachable = path ~= nil,
        status = path and "reachable" or "no_path",
        path = path,
        face_dir = face_dir,
        adjacent_diagnostics = adjacent_diagnostics,
    }
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
    if reachability and reachability.reachable == false then
        return desc .. ". Not currently reachable"
    end
    return desc
end

function M.describe_current_object(opts)
    local obj = objects.current_object()
    if not obj then
        return "No objects found"
    end
    return M.describe_object_with_reachability(obj, objects.describe_current(opts), opts)
end

-- plan_path_to_object(obj): Compute a path from the player to the given
-- object. Returns (result, face_dir, path, message, map_id).
local function plan_path_to_object(obj, opts)
    opts = opts or {}
    local plan_start_clock = os.clock()
    local map_id, px, py = resolve_plan_origin(opts)
    -- `survey_safe` is used by map_survey for classification/retry behavior,
    -- but the actual movement plan must still respect frozen NPC blockers.
    -- Callers that truly want an NPC-free blocking table must opt in with
    -- skip_npcs=true explicitly.
    local skip_npcs = opts.skip_npcs
    local blocking = opts.blocking
    if not blocking then
        -- Only refresh NPCs when we're about to rebuild blocking from live state.
        -- Preview callers that pass a precomputed blocking table already encode
        -- the NPC snapshot they want.
        if should_refresh_npcs_for_plan(opts) then
            objects.update_npcs()
        end
        blocking = M.build_path_blocking(map_id, skip_npcs and {skip_npcs = true} or nil)
    end
    local path_mode, target_walkable = resolve_path_mode(obj, map_id, opts)
    local result, face_dir, path, adjacent_diagnostics
    local no_path_reason = nil
    local goal_block_reason = get_goal_block_reason(blocking, obj.x, obj.y)
    if path_mode == "adjacent" then
        result, face_dir, path, adjacent_diagnostics = pathfinder.pathfind_to_adjacent(
            map_id, px, py, obj.x, obj.y, blocking, adjacent_path_opts(opts))
    else
        if goal_block_reason == "npc" then
            result, face_dir, path = "No path found", nil, nil
            no_path_reason = "goal_blocked_npc"
        elseif goal_block_reason == "runtime" then
            result, face_dir, path = "No path found", nil, nil
            no_path_reason = "goal_blocked_runtime"
        else
            result, face_dir, path = pathfinder.pathfind_to(map_id, px, py, obj.x, obj.y, blocking)
        end
    end
    if result == "No path found" and no_path_reason == nil then
        no_path_reason = infer_no_path_reason(map_id, px, py, blocking)
    end
    local plan = {
        target = obj,
        map_id = map_id,
        start_x = px,
        start_y = py,
        goal_x = obj.x,
        goal_y = obj.y,
        path_mode = path_mode,
        target_walkable = target_walkable,
        goal_block_reason = goal_block_reason,
        no_path_reason = no_path_reason,
        blocking = blocking,
        result = result,
        face_dir = face_dir,
        path = path,
        adjacent_diagnostics = adjacent_diagnostics,
        message = build_pathfind_message(obj, result, face_dir, no_path_reason),
    }
    plan = try_adjacent_fallback(obj, map_id, px, py, blocking, opts, plan)
    plan.message = build_pathfind_message(obj, plan.result, plan.face_dir, plan.no_path_reason)
    -- Store path for debug recall (trace_path, validate_path, etc.)
    if debug_tools.DEBUG_MODE and opts.store_debug_path ~= false then
        path_debug.store_path(map_id, px, py, obj.x, obj.y, plan.path, nil)
    end
    log_route_plan_timing(plan, (os.clock() - plan_start_clock) * 1000)
    return plan
end

function M.plan_path_to_object(obj, opts)
    if not obj then return nil end
    return plan_path_to_object(obj, opts)
end

-- queue_path_steps(path): Convert A* path to auto_step route directions.
-- Returns true if the route was queued successfully.
local function queue_path_steps(path, opts)
    if not path or #path == 0 then
        return false
    end
    opts = opts or {}
    local steps = {}
    for i, step in ipairs(path) do
        local dir = DIR_NAME_TO_KEY[step.direction]
        if not dir then
            return false
        end
        steps[i] = dir
    end
    local settle_frames = opts.settle_frames
    if settle_frames == nil then
        settle_frames = active_route_settle_frames or 0
    end
    settle_frames = math.max(0, tonumber(settle_frames) or 0)
    if auto_step.start_route(steps, {settle_frames = settle_frames}) then
        active_route_settle_frames = settle_frames
        reroute_failures = 0
        return true
    end
    return false
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
    local plan = plan_path_to_object(obj)
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
    if autowalk_guard then
        local ok, reason = autowalk_guard()
        if ok == false then
            debug_tools.info("AUTO_WALK: blocked before planning for " .. obj.name)
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
    local map_id = nav.get_position()
    if should_freeze_npcs_for_autowalk(opts) then
        freeze_npcs_for_pathing()
    else
        debug_tools.debug("AUTO_WALK: NPC freeze skipped for this route")
    end
    last_pathfind_obj = obj
    local plan = plan_path_to_object(obj, opts)
    plan.status = "planned"
    plan.ok = false
    if maps.is_overworld(map_id, snapshot.terrain_offset) then
        release_npc_freeze("autowalk unavailable on overworld")
        debug_tools.info("AUTO_WALK: unavailable on overworld for " .. obj.name)
        if opts.speak ~= false then
            tolk.output_interrupt("Auto-walk is only available on interior maps. " .. plan.message)
        end
        plan.status = "unavailable"
        plan.message = "Auto-walk is only available on interior maps. " .. plan.message
        return plan
    end
    if plan.result == "No path found" then
        release_npc_freeze("autowalk immediate no-path")
        debug_tools.info("AUTO_WALK: no path for " .. obj.name)
        if opts.speak ~= false then
            tolk.output_interrupt(plan.message)
        end
        plan.status = "no_path"
        plan.message = plan.message
        return plan
    end
    if not plan.path or #plan.path == 0 then
        release_npc_freeze("autowalk already at destination")
        debug_tools.info("AUTO_WALK: already adjacent to " .. obj.name)
        plan.status = "already_there"
        plan.message = "Already there. " .. build_pathfind_message(obj, "Adjacent", plan.face_dir)
        if plan.path_mode == "adjacent" then
            queue_target_face(plan.face_dir, obj)
        end
        if start_target_npc_hold(obj) then
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
            release_npc_freeze("autowalk prequeue deferred")
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
    if not queue_path_steps(plan.path, {settle_frames = settle_frames}) then
        active_route_settle_frames = 0
        release_npc_freeze("autowalk queue failure")
        debug_tools.error("AUTO_WALK: failed to queue route for " .. obj.name)
        plan.status = "queue_failed"
        plan.message = "Auto-walk could not queue the route"
        if opts.speak ~= false then
            tolk.output_interrupt(plan.message)
        end
        return plan
    end
    debug_tools.info("AUTO_WALK: queued " .. #plan.path .. " step(s) for " .. obj.name)
    set_active_route_context(obj, #plan.path, plan.path_mode == "adjacent" and plan.face_dir or nil)
    plan.status = "queued"
    plan.ok = true
    plan.path_length = #plan.path
    if opts.speak ~= false then
        tolk.output_interrupt("Auto-walk. " .. plan.message)
    end
    return plan
end

-- autowalk_to_current(): Plan and auto-walk to the currently selected object.
-- Only works on interior maps (not overworld). FCEUX keeps the old NPC-freeze
-- behavior; BizHawk skips per-frame NPC RAM freezing by default for performance
-- and relies on reroute handling if an NPC moves into the path.
function M.autowalk_to_current()
    local obj = objects.current_object()
    if not obj then
        tolk.output_interrupt("No object selected")
        return
    end
    M.autowalk_to_object(obj, {speak = true})
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
    local is_manual_block = (block_data and block_data.queued_route == false)
    local is_seam_retry_block = same_seam_retry(map_id, from_x, from_y, blocked_dir)
    local source = is_seam_retry_block
        and "seam_retry_block"
        or (is_manual_block and "manual_block" or "queued_route_block")
    local _, seam_class = observe_seam_result(map_id, from_x, from_y, blocked_dir, "blocked", source)
    if is_manual_block and not is_seam_retry_block then
        debug_tools.debug("route_manager: ignoring blocked step outside queued route")
        return
    end
    if not last_pathfind_obj then return end

    local _, px, py = nav.get_position()

    local blocking = M.build_path_blocking(map_id)
    if seam_class ~= "confirmed_blocked" then
        add_temporary_directional_block(blocking, from_x, from_y, blocked_dir)
    end
    local plan = plan_path_to_object(last_pathfind_obj, {
        map_id = map_id,
        start_x = px,
        start_y = py,
        blocking = blocking,
        allow_adjacent_fallback = true,
        store_debug_path = false,
    })

    if plan.result == "No path found"
    and seam_class ~= "confirmed_blocked"
    and start_seam_bruteforce(map_id, from_x, from_y, blocked_dir) then
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
            reason = "reroute_no_path",
            target = last_pathfind_obj,
            map_id = map_id,
            from_x = from_x,
            from_y = from_y,
            blocked_dir = blocked_dir,
        })
        clear_active_route_context("no path found on reroute", should_refresh_objects_after_route())
        tolk.output_interrupt("No path found. Pathfinding cancelled.")
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
        if queue_path_steps(plan.path, {settle_frames = active_route_settle_frames}) then
            update_active_route_remaining(#plan.path, plan.path_mode == "adjacent" and plan.face_dir or nil)
        end
    else
        clear_active_route_context("reroute reached destination", should_refresh_objects_after_route())
    end
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
    observe_seam_result(
        map_id,
        from_x,
        from_y,
        dir,
        "moved",
        step_data and step_data.source or "step_complete")
    reroute_failures = 0
    if step_data and step_data.queued_route and active_route_total_steps > 0 then
        active_route_completed_steps = active_route_completed_steps + 1
        local progress_interval = config_int("auto_walk_progress_interval", 6, 0, 60)
        if progress_interval > 0
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

    local plan = plan_path_to_object(target, {
        map_id = map_id,
        start_x = to_x,
        start_y = to_y,
        allow_adjacent_fallback = true,
        store_debug_path = false,
    })

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
        clear_active_route_context("seam brute force reached destination", should_refresh_objects_after_route())
        tolk.output_interrupt("Seam crossed. " .. build_pathfind_message(
            target,
            plan.result,
            plan.face_dir,
            plan.no_path_reason))
        return
    end

    if not queue_path_steps(plan.path, {settle_frames = active_route_settle_frames}) then
        clear_active_route_context("queue failure after seam brute force", should_refresh_objects_after_route())
        tolk.output_interrupt("Seam crossed, but auto-walk could not queue the follow-up route.")
        return
    end
    update_active_route_remaining(#plan.path, plan.path_mode == "adjacent" and plan.face_dir or nil)

    tolk.output_interrupt("Seam crossed. " .. build_pathfind_message(
        target,
        plan.result,
        plan.face_dir,
        plan.no_path_reason))
end

auto_step.on_route_complete = function()
    local target = active_route_target or last_pathfind_obj
    local face_dir = active_route_face_dir
    local total_steps = active_route_total_steps
    clear_active_route_context("autowalk route complete", should_refresh_objects_after_route())
    if target then
        local msg = string.format("Auto-walk complete. Arrived at %s", target.name or "destination")
        if total_steps and total_steps > 0 then
            msg = msg .. string.format(" after %d steps", total_steps)
        end
        queue_target_face(face_dir, target)
        if target.type == objects.TYPE_NPC and start_target_npc_hold(target) then
            msg = msg .. ". Target held briefly. Use TALK now"
        end
        tolk.output_interrupt(msg)
    else
        tolk.output_interrupt("Auto-walk complete")
    end
end

auto_step.on_route_cancelled = function(cancel_data)
    local reason = cancel_data and cancel_data.reason or "auto_step_cancelled"
    local had_target = active_route_target or last_pathfind_obj
    clear_active_route_context("auto_step route cancelled: " .. tostring(reason), should_refresh_objects_after_route())
    if had_target and reason ~= "can_walk_false" then
        tolk.output_interrupt("Auto-walk cancelled. " .. tostring(reason))
    end
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

function M.clear_active_route_context(reason)
    clear_active_route_context(reason, true)
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
end

return M
