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
-- Simple single-tier system: auto_step's BLOCK_RETRY_LIMIT filters
-- intermittent misses before on_blocked fires, so we record immediately.
local runtime_blocked = {}
local autowalk_guard = nil

local function cell_key(x, y)
    return x .. "," .. y
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
    for k in pairs(map_blocks) do
        local x, y = parse_cell_key(k)
        blocks[#blocks + 1] = {key = k, x = x, y = y}
    end
    table.sort(blocks, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        return a.x < b.x
    end)
    return blocks
end

local function record_runtime_block(map_id, from_x, from_y, blocked_dir)
    if not map_id or from_x == nil or from_y == nil or not blocked_dir then
        return false
    end

    local dx = (blocked_dir == "right" and 1) or (blocked_dir == "left" and -1) or 0
    local dy = (blocked_dir == "down"  and 1) or (blocked_dir == "up"   and -1) or 0
    local dest_x = from_x + dx
    local dest_y = from_y + dy
    local k = cell_key(dest_x, dest_y)
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

    if not runtime_blocked[map_id] then
        runtime_blocked[map_id] = {}
    end
    if runtime_blocked[map_id][k] then
        return false
    end
    runtime_blocked[map_id][k] = true
    debug_tools.info(string.format(
        "runtime block: map=0x%02X cell=(%d,%d) source=%s",
        map_id, dest_x, dest_y, source))
    return true
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

local function freeze_npcs_for_pathing()
    capture_npc_snapshot()
    npc_freeze_active = true
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

-- build_path_blocking(map_id): Combine NPC positions + runtime blocks
-- into a single blocking table for the A* pathfinder.
function M.build_path_blocking(map_id)
    local blocking = objects.get_blocking_positions()
    for _, pos in ipairs(blocking) do
        blocking[cell_key(pos.x, pos.y)] = "npc"
    end
    if runtime_blocked[map_id] then
        for k, _ in pairs(runtime_blocked[map_id]) do
            blocking[k] = "runtime"
        end
    end
    return blocking
end

-- count_runtime_blocks(map_id): Return count of runtime-discovered blocks.
function M.count_runtime_blocks(map_id)
    return #collect_runtime_blocks(map_id)
end

-- format_runtime_blocks(map_id): Return sorted list of "x,y" block keys.
function M.format_runtime_blocks(map_id)
    local parts = {}
    for _, block in ipairs(collect_runtime_blocks(map_id)) do
        parts[#parts + 1] = block.key
    end
    return parts
end

-- get_runtime_block_entries(map_id): Return sorted runtime block entries.
function M.get_runtime_block_entries(map_id)
    return collect_runtime_blocks(map_id)
end

-- is_cell_runtime_blocked(map_id, x, y): Check if a specific cell is blocked.
function M.is_cell_runtime_blocked(map_id, x, y)
    return runtime_blocked[map_id] and runtime_blocked[map_id][cell_key(x, y)] or false
end

-- inject_runtime_block(map_id, x, y): Manually add a runtime blocked tile.
function M.inject_runtime_block(map_id, x, y)
    return add_runtime_block(map_id, x, y, "manual_command")
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

-- format_runtime_blocks_as_lua(map_id): Return copy-pasteable MAP_BLOCKED_CELLS lines.
function M.format_runtime_blocks_as_lua(map_id)
    local entries = collect_runtime_blocks(map_id)
    local lines = {
        string.format("    [0x%02X] = {", map_id),
    }
    for _, block in ipairs(entries) do
        lines[#lines + 1] = string.format('        ["%s"] = true,', block.key)
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

-- ============================================================
-- Path Planning
-- ============================================================

local function get_goal_block_reason(blocking, x, y)
    if not blocking then return nil end
    return blocking[cell_key(x, y)]
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

-- plan_path_to_object(obj): Compute a path from the player to the given
-- object. Returns (result, face_dir, path, message, map_id).
local function plan_path_to_object(obj)
    local map_id, px, py = nav.get_position()
    objects.update_npcs()
    local blocking = M.build_path_blocking(map_id)
    local target_walkable = M.is_pathfinding_walkable(map_id, obj.x, obj.y)
    local result, face_dir, path
    local no_path_reason = nil
    local goal_block_reason = get_goal_block_reason(blocking, obj.x, obj.y)
    if obj.type == objects.TYPE_NPC
    or obj.type == objects.TYPE_DOOR
    or not target_walkable then
        result, face_dir, path = pathfinder.pathfind_to_adjacent(map_id, px, py, obj.x, obj.y, blocking)
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
    -- Store path for debug recall (trace_path, validate_path, etc.)
    if debug_tools.DEBUG_MODE then
        path_debug.store_path(map_id, px, py, obj.x, obj.y, path, nil)
    end
    return result, face_dir, path, build_pathfind_message(obj, result, face_dir, no_path_reason), map_id
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
-- Announces the result via speech. Freezes NPCs before planning so the
-- announced route matches the live route state.
function M.pathfind_to_current()
    local obj = objects.current_object()
    if not obj then
        tolk.output_interrupt("No object selected")
        return
    end
    freeze_npcs_for_pathing()
    last_pathfind_obj = obj
    local _, _, _, msg = plan_path_to_object(obj)
    tolk.output_interrupt(msg)
end

-- autowalk_to_current(): Plan and auto-walk to the currently selected object.
-- Only works on interior maps (not overworld). NPCs are frozen during route
-- planning and released when the route completes or fails.
function M.autowalk_to_current()
    local obj = objects.current_object()
    if not obj then
        tolk.output_interrupt("No object selected")
        return
    end
    if autowalk_guard then
        local ok, reason = autowalk_guard()
        if ok == false then
            debug_tools.info("AUTO_WALK: blocked before planning for " .. obj.name)
            tolk.output_interrupt(reason or "Cannot auto-walk right now")
            return
        end
    end
    local map_id = nav.get_position()
    freeze_npcs_for_pathing()
    last_pathfind_obj = obj
    local result, face_dir, path, msg = plan_path_to_object(obj)
    if maps.is_overworld(map_id, snapshot.terrain_offset) then
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
    if path_debug.is_validating and path_debug.is_validating() then
        debug_tools.debug("route_manager: ignoring blocked step during validation")
        return
    end
    if path_debug.is_step_mode and path_debug.is_step_mode() then
        debug_tools.debug("route_manager: ignoring blocked step during step mode")
        return
    end

    local map_id = nav.get_position()
    record_runtime_block(map_id, from_x, from_y, blocked_dir)
    if not last_pathfind_obj then return end

    reroute_failures = reroute_failures + 1
    if reroute_failures >= REROUTE_FAILURE_LIMIT then
        debug_tools.info("reroute_failures=" .. reroute_failures .. ": giving up on " .. last_pathfind_obj.name)
        last_pathfind_obj = nil
        reroute_failures = 0
        if npc_freeze_active then
            npc_freeze_active = false
            frozen_npc_snapshot = {}
            debug_tools.info("NPC freeze released: reroute failure limit reached")
        end
        objects.request_refresh()
        tolk.output_interrupt("Cannot reach destination. Pathfinding cancelled.")
        return
    end

    local _, px, py = nav.get_position()

    -- Build blocking table and re-route
    local blocking = M.build_path_blocking(map_id)
    local result, face_dir, path
    local target_walkable = M.is_pathfinding_walkable(map_id, last_pathfind_obj.x, last_pathfind_obj.y)
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
        if npc_freeze_active then
            npc_freeze_active = false
            frozen_npc_snapshot = {}
            debug_tools.info("NPC freeze released: no path found on reroute")
        end
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
