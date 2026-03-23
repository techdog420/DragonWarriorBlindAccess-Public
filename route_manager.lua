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
local nav        = require "navigation"
local objects    = require "objects"
local pathfinder = require "pathfinder"
local map_reader = require "map_reader"
local auto_step  = require "auto_step"
local tolk       = require "tolk"
local debug_tools = require "debug_tools"
local path_debug = require "path_debug"
local snapshot   = require "game_snapshot"

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
-- Format: runtime_blocked[map_id]["x,y"] = true  (cleared on map change)
local runtime_blocked = {}

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

-- apply_npc_freeze(): Restore snapshotted NPC bytes to RAM.
-- Call once per frame immediately after FCEU.frameadvance().
-- No-op when npc_freeze_active is false, so it's safe to call every frame.
function M.apply_npc_freeze()
    if not npc_freeze_active then return end
    for i = 0, addr.NPC_COUNT - 1 do
        local base = addr.NPC_DATA_START + i * addr.NPC_ENTRY_SIZE
        local snap = frozen_npc_snapshot[i]
        memory.writebyte(base,     snap[1])
        memory.writebyte(base + 1, snap[2])
        memory.writebyte(base + 2, snap[3])
    end
end

-- toggle_npc_freeze(): Toggle NPC position freeze on/off.
-- Returns true if freeze is now active, false if released.
function M.toggle_npc_freeze()
    if npc_freeze_active then
        npc_freeze_active = false
        frozen_npc_snapshot = {}
        tolk.output_interrupt("NPCs unfrozen.")
        return false
    else
        capture_npc_snapshot()
        npc_freeze_active = true
        tolk.output_interrupt("NPCs frozen.")
        return true
    end
end

-- freeze_npcs() / unfreeze_npcs(): Direct control for remote commands.
function M.freeze_npcs()
    capture_npc_snapshot()
    npc_freeze_active = true
end

function M.unfreeze_npcs()
    npc_freeze_active = false
    frozen_npc_snapshot = {}
end

-- is_npc_freeze_active(): Query freeze state (for can_walk guard, etc.)
function M.is_npc_freeze_active()
    return npc_freeze_active
end

-- ============================================================
-- Runtime Blocked Cells
-- ============================================================

-- build_path_blocking(map_id): Combine NPC positions + runtime blocks
-- into a single blocking table for the A* pathfinder.
function M.build_path_blocking(map_id)
    local blocking = objects.get_blocking_positions()
    if runtime_blocked[map_id] then
        for cell_key, _ in pairs(runtime_blocked[map_id]) do
            blocking[cell_key] = true
        end
    end
    return blocking
end

-- count_runtime_blocks(map_id): Return count of runtime-discovered blocks.
function M.count_runtime_blocks(map_id)
    local n = 0
    if runtime_blocked[map_id] then
        for _ in pairs(runtime_blocked[map_id]) do
            n = n + 1
        end
    end
    return n
end

-- format_runtime_blocks(map_id): Return sorted list of "x,y" block keys.
function M.format_runtime_blocks(map_id)
    local parts = {}
    if runtime_blocked[map_id] then
        for cell_key, _ in pairs(runtime_blocked[map_id]) do
            parts[#parts + 1] = cell_key
        end
    end
    table.sort(parts)
    return parts
end

-- is_cell_runtime_blocked(map_id, x, y): Check if a specific cell is blocked.
function M.is_cell_runtime_blocked(map_id, x, y)
    return runtime_blocked[map_id] and runtime_blocked[map_id][x .. "," .. y] or false
end

-- clear_runtime_blocks(map_id_or_all): Clear runtime blocks.
-- Pass a map_id to clear one map, or "all" to clear everything.
function M.clear_runtime_blocks(map_id_or_all)
    if map_id_or_all == "all" then
        runtime_blocked = {}
    else
        runtime_blocked[map_id_or_all] = nil
    end
end

-- ============================================================
-- Path Planning
-- ============================================================

-- build_pathfind_message(obj, result, face_dir): Create a human-readable
-- message describing the pathfinding result. Includes key count for doors
-- and locked-door hint for unreachable chests.
local function build_pathfind_message(obj, result, face_dir)
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
    if obj.type == objects.TYPE_CHEST and result == "No path found" then
        local terrain = snapshot.terrain_offset
        if terrain == 0x10 then
            msg = msg .. ". Chest may be behind locked door. Navigate to a door object first"
        end
    end
    return msg
end

-- plan_path_to_object(obj): Compute a path from the player to the given
-- object. Returns (result, face_dir, path, message, map_id).
local function plan_path_to_object(obj)
    local map_id, px, py = nav.get_position()
    objects.update_npcs()
    local blocking = M.build_path_blocking(map_id)
    local target_walkable = map_reader.is_walkable(map_id, obj.x, obj.y)
    local result, face_dir, path
    if obj.type == objects.TYPE_NPC
    or obj.type == objects.TYPE_DOOR
    or not target_walkable then
        result, face_dir, path = pathfinder.pathfind_to_adjacent(map_id, px, py, obj.x, obj.y, blocking)
    else
        result, face_dir, path = pathfinder.pathfind_to(map_id, px, py, obj.x, obj.y, blocking)
    end
    -- Store path for debug recall (trace_path, validate_path, etc.)
    if debug_tools.DEBUG_MODE then
        path_debug.store_path(map_id, px, py, obj.x, obj.y, path, nil)
    end
    return result, face_dir, path, build_pathfind_message(obj, result, face_dir), map_id
end

-- queue_path_steps(path): Convert A* path to auto_step route directions.
-- Returns true if the route was queued successfully.
local function queue_path_steps(path)
    if not path or #path == 0 then
        return false
    end
    local steps = {}
    for i, step in ipairs(path) do
        local dir = DIR_NAME_TO_KEY[step.direction]
        if not dir then
            return false
        end
        steps[i] = dir
    end
    if auto_step.start_route(steps) then
        reroute_failures = 0
        return true
    end
    return false
end

-- ============================================================
-- Public API: Pathfinding Commands
-- ============================================================

-- pathfind_to_current(): Plan a path to the currently selected object.
-- Announces the result via speech. Freezes NPCs if targeting an NPC.
function M.pathfind_to_current()
    local obj = objects.current_object()
    if not obj then
        tolk.output_interrupt("No object selected")
        return
    end
    last_pathfind_obj = obj
    if obj.type == objects.TYPE_NPC then
        capture_npc_snapshot()
        npc_freeze_active = true
    end
    local _, _, _, msg = plan_path_to_object(obj)
    tolk.output_interrupt(msg)
end

-- autowalk_to_current(): Plan and auto-walk to the currently selected object.
-- Only works on interior maps (not overworld).
function M.autowalk_to_current()
    local obj = objects.current_object()
    if not obj then
        tolk.output_interrupt("No object selected")
        return
    end
    last_pathfind_obj = obj
    if obj.type == objects.TYPE_NPC then
        capture_npc_snapshot()
        npc_freeze_active = true
    end
    local result, face_dir, path, msg, map_id = plan_path_to_object(obj)
    if map_id == 0x00 then
        debug_tools.info("AUTO_WALK: unavailable on overworld for " .. obj.name)
        tolk.output_interrupt("Auto-walk is only available on interior maps. " .. msg)
        return
    end
    if result == "No path found" then
        debug_tools.info("AUTO_WALK: no path for " .. obj.name)
        tolk.output_interrupt(msg)
        return
    end
    if not path or #path == 0 then
        debug_tools.info("AUTO_WALK: already adjacent to " .. obj.name)
        tolk.output_interrupt("Already there. " .. build_pathfind_message(obj, "Adjacent", face_dir))
        return
    end
    if not queue_path_steps(path) then
        debug_tools.error("AUTO_WALK: failed to queue route for " .. obj.name)
        tolk.output_interrupt("Auto-walk could not queue the route")
        return
    end
    debug_tools.info("AUTO_WALK: queued " .. #path .. " step(s) for " .. obj.name)
    tolk.output_interrupt("Auto-walk. " .. msg)
end

-- ============================================================
-- Auto-Step Callbacks
-- ============================================================
-- These are wired to auto_step's callback mechanism. They handle
-- rerouting when a step is blocked and cleanup when a route completes.

auto_step.on_blocked = function(from_x, from_y, blocked_dir)
    if not last_pathfind_obj then return end

    reroute_failures = reroute_failures + 1
    if reroute_failures >= REROUTE_FAILURE_LIMIT then
        debug_tools.info("reroute_failures=" .. reroute_failures .. ": giving up on " .. last_pathfind_obj.name)
        last_pathfind_obj = nil
        reroute_failures = 0
        if npc_freeze_active then
            npc_freeze_active = false
            frozen_npc_snapshot = {}
        end
        objects.request_refresh()
        tolk.output_interrupt("Cannot reach destination. Pathfinding cancelled.")
        return
    end

    local map_id, px, py = nav.get_position()

    -- Refresh NPC positions so we can exclude NPC-occupied cells
    -- from the runtime_blocked set (NPC blocks are temporary).
    objects.update_npcs()

    -- Record the engine-blocked destination in the runtime blocked set.
    if from_x and from_y and blocked_dir then
        local dx = (blocked_dir == "right" and 1) or (blocked_dir == "left" and -1) or 0
        local dy = (blocked_dir == "down"  and 1) or (blocked_dir == "up"   and -1) or 0
        local dest_x = from_x + dx
        local dest_y = from_y + dy
        -- Only record as engine-blocked if no NPC currently occupies the cell.
        local npc_positions = objects.get_blocking_positions()
        local dest_key = dest_x .. "," .. dest_y
        local npc_at_dest = npc_positions[dest_key]
        if not npc_at_dest then
            for _, npc in ipairs(npc_positions) do
                if npc.x == dest_x and npc.y == dest_y then
                    npc_at_dest = true
                    break
                end
            end
        end
        if not npc_at_dest then
            if not runtime_blocked[map_id] then
                runtime_blocked[map_id] = {}
            end
            local cell_key = dest_key
            if not runtime_blocked[map_id][cell_key] then
                runtime_blocked[map_id][cell_key] = true
                debug_tools.info("runtime block: map=" .. map_id
                    .. " cell=(" .. dest_x .. "," .. dest_y .. ")"
                    .. " via " .. blocked_dir .. " from (" .. from_x .. "," .. from_y .. ")")
            end
        else
            debug_tools.debug("block at (" .. dest_x .. "," .. dest_y .. ") is NPC, not recording")
        end
    end

    -- Re-freeze only if the target is an NPC
    if last_pathfind_obj.type == objects.TYPE_NPC then
        capture_npc_snapshot()
        npc_freeze_active = true
    end

    -- Build blocking table and re-route
    local blocking = M.build_path_blocking(map_id)
    local result, face_dir, path
    local target_walkable = map_reader.is_walkable(map_id, last_pathfind_obj.x, last_pathfind_obj.y)
    if last_pathfind_obj.type == objects.TYPE_NPC
    or last_pathfind_obj.type == objects.TYPE_DOOR
    or not target_walkable then
        result, face_dir, path = pathfinder.pathfind_to_adjacent(
            map_id, px, py,
            last_pathfind_obj.x, last_pathfind_obj.y, blocking)
    else
        result, face_dir, path = pathfinder.pathfind_to(
            map_id, px, py,
            last_pathfind_obj.x, last_pathfind_obj.y, blocking)
    end

    if result == "No path found" then
        last_pathfind_obj = nil
        reroute_failures = 0
        tolk.output_interrupt("No path found. Pathfinding cancelled.")
        return
    end

    local msg = "Re-routing. " .. build_pathfind_message(last_pathfind_obj, result, face_dir)
    tolk.output_interrupt(msg)

    if path and #path > 0 then
        queue_path_steps(path)
    end
end

auto_step.on_route_complete = function()
    reroute_failures = 0
    last_pathfind_obj = nil
    if npc_freeze_active then
        npc_freeze_active = false
        frozen_npc_snapshot = {}
        debug_tools.info("NPC freeze released: autowalk route complete")
    end
    objects.request_refresh()
end

-- ============================================================
-- Map Change Handler
-- ============================================================

-- on_map_change(): Clear all route-related state when the player enters
-- a new map. Called from the main loop's check_map_change().
function M.on_map_change()
    last_pathfind_obj = nil
    reroute_failures = 0
    runtime_blocked = {}
    npc_freeze_active = false
    frozen_npc_snapshot = {}
end

-- ============================================================
-- State Queries (for debug commands)
-- ============================================================

-- get_last_pathfind_obj(): Return the current pathfind target (or nil).
function M.get_last_pathfind_obj()
    return last_pathfind_obj
end

-- get_dir_to_delta(): Return the direction-to-delta table.
-- Used by debug diagnostic functions.
function M.get_dir_to_delta()
    return DIR_TO_DELTA
end

return M
