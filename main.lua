-- main.lua
-- Dragon Warrior Accessibility Mod — Entry Point
--
-- This is the main script loaded by BizHawk or FCEUX. It runs the core polling loop:
-- every frame we read game state from RAM, compare to the previous frame,
-- and speak any changes through Tolk (screen reader bridge).
--
-- Preferred BizHawk command line:
--   EmuHawk.exe --lua=main.lua "Dragon Warrior (USA) (Rev 1).nes"
-- FCEUX fallback:
--   qfceux.exe --loadlua=main.lua "Dragon Warrior (USA) (Rev 1).nes"

-- ============================================================
-- Module Loading
-- ============================================================
-- Some launch paths leave the emulator's current working directory somewhere other
-- than the mod folder. Resolve this script's directory explicitly and prepend
-- it to package.path before the first require() so sibling modules load
-- reliably whether the script is started by command line or through the UI.
local main_source = debug.getinfo(1, "S").source
local main_script_dir = main_source:match("@?(.*[\\/])") or ""
if main_script_dir ~= "" then
    local script_package_path = table.concat({
        main_script_dir .. "?.lua",
        main_script_dir .. "?/init.lua",
    }, ";")
    if not package.path:find(main_script_dir, 1, true) then
        package.path = script_package_path .. ";" .. package.path
    end
end

-- One-time reload migration: older objects.lua builds kept visited flags in a
-- module-local table. Copy that table into reload_state before the module cache
-- is cleared so the first source reload after this patch does not erase the
-- player's current visited list.
function _G.DW_MIGRATE_OBJECT_VISITS_ON_RELOAD()
    local old_objects = package.loaded["objects"]
    if type(old_objects) ~= "table"
       or type(old_objects.is_visited) ~= "function"
       or type(debug) ~= "table"
       or type(debug.getupvalue) ~= "function" then
        return
    end

    local reload_state = rawget(_G, "DW_OBJECTS_RELOAD_STATE")
    if type(reload_state) ~= "table" then
        reload_state = {}
        _G.DW_OBJECTS_RELOAD_STATE = reload_state
    end
    if type(reload_state.visited_by_map) == "table" then
        return
    end

    local visited_bucket = nil
    for i = 1, 20 do
        local name, value = debug.getupvalue(old_objects.is_visited, i)
        if not name then break end
        if name == "visited_bucket" then
            visited_bucket = value
            break
        end
    end
    if type(visited_bucket) ~= "function" then
        return
    end

    for i = 1, 20 do
        local name, value = debug.getupvalue(visited_bucket, i)
        if not name then break end
        if name == "visited_by_map" and type(value) == "table" then
            reload_state.visited_by_map = value
            return
        end
    end
end
_G.DW_MIGRATE_OBJECT_VISITS_ON_RELOAD()
_G.DW_MIGRATE_OBJECT_VISITS_ON_RELOAD = nil

-- BizHawk console/script reloads can re-run main.lua inside the same Lua
-- state, leaving required project modules cached. Clear our modules before
-- requiring them so a console reload actually picks up code changes.
for _, mod_name in ipairs({
    "addresses", "auto_step", "battle", "chars", "config",
    "debug_tools", "emulator_compat", "event_bus", "game_snapshot",
    "hotkey_filter", "hotkeys", "items", "key_combo", "map_reader",
    "map_survey", "maps", "menu", "merchant", "navigation",
    "object_commands", "objects", "overworld_routes", "path_debug", "pathfinder",
    "route_manager", "scan_profiler", "state", "text",
}) do
    package.loaded[mod_name] = nil
end

local emulator_compat = require "emulator_compat" -- FCEUX/BizHawk API shim
local scan_profiler = require "scan_profiler" -- BizHawk scan throttling/profiling

local tolk = require "tolk"         -- Speech output (Python bridge to screen reader)
local addr = require "addresses"    -- RAM address constants
local battle = require "battle"     -- Battle command menu helpers
local chars = require "chars"       -- Text encoding table
local text = require "text"         -- Screen buffer reading
local nav = require "navigation"    -- Position and map tracking
local state = require "state"       -- Game state detection
local menu = require "menu"         -- Command menu cursor tracking
local config = require "config"     -- User-configurable settings
local objects = require "objects"   -- Map object detection and navigation
local pathfinder = require "pathfinder" -- A* pathfinding for interior maps
local map_reader = require "map_reader" -- ROM map data (tile grids)
local auto_step = require "auto_step"  -- Tap-to-step D-pad extension
local items = require "items"          -- Item/equipment/spell lookup tables
local merchant = require "merchant"    -- Dedicated merchant/shop UI detection
local debug_tools = require "debug_tools"  -- Debug logging and automation (no-op when debug_mode=false)
local path_debug = require "path_debug"    -- Pathfinding debug/test tools (no-op when debug_mode=false)
local map_survey = require "map_survey"    -- Autonomous map/object survey workflow
local snapshot = require "game_snapshot"   -- Centralized per-frame RAM reads
local event_bus = require "event_bus"      -- Pub/sub event system for module decoupling
local route_mgr = require "route_manager" -- Pathfinding coordination, NPC freeze, runtime blocks
local hotkeys   = require "hotkeys"        -- Keyboard hotkey handling
local hotkey_filter = require "hotkey_filter" -- Emulator-specific keyboard policy
local key_combo = require "key_combo"      -- Configurable key-combo helpers

-- Direction constants (kept here for debug diagnostic functions).
local DIR_TO_DELTA = route_mgr.get_dir_to_delta()
scan_profiler.setup(emulator_compat)

local function parse_int_arg(token)
    if not token then return nil end
    token = token:match("^%s*(.-)%s*$")
    if token == "" then return nil end
    if token:match("^[-+]?0[xX][%da-fA-F]+$") then
        return tonumber(token)
    end
    if token:match("^[-+]?%d+$") then
        return tonumber(token)
    end
    return nil
end

local function parse_xy_arg(arg)
    if not arg then return nil end
    local x_s, y_s = arg:match("^%s*([^,]+)%s*,%s*([^,]+)%s*$")
    if not x_s then return nil end
    local x = parse_int_arg(x_s)
    local y = parse_int_arg(y_s)
    if x == nil or y == nil then return nil end
    return x, y
end

local function parse_map_xy_arg(arg, default_map_id)
    if not arg then return nil end
    local a, b, c = arg:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")
    if a and b and c then
        local map_id = parse_int_arg(a)
        local x = parse_int_arg(b)
        local y = parse_int_arg(c)
        if map_id == nil or x == nil or y == nil then return nil end
        return map_id, x, y
    end
    local x, y = parse_xy_arg(arg)
    if x == nil then return nil end
    return default_map_id, x, y
end

local function has_directional_block(entry)
    return type(entry) == "table" and next(entry) ~= nil
end

local function blocks_all_approaches(entry)
    return type(entry) == "table"
        and entry.north and entry.south and entry.east and entry.west
end

local function get_block_flags(blocking, x, y, approach)
    -- blocking is the merged table from route_mgr.build_path_blocking(),
    -- which already contains NPC positions ("npc"), static directional
    -- blocks (table), and runtime directional blocks (merged into tables).
    local key = x .. "," .. y
    local entry = blocking and blocking[key] or nil
    local npc_blocked = (entry == "npc")
    local directional_blocked = has_directional_block(entry)
    local approach_blocked = false

    if approach and type(entry) == "table" then
        approach_blocked = (entry[approach] == true)
    end

    return {
        npc_blocked = npc_blocked,
        directional_blocked = directional_blocked,
        approach = approach,
        approach_blocked = approach_blocked,
        fully_blocked = blocks_all_approaches(entry),
    }
end

-- Cardinal names accepted as aliases for joypad keys.
local CARDINAL_TO_KEY = {north = "up", south = "down", east = "right", west = "left"}
local MOVE_DIR_TO_APPROACH = {up = "south", down = "north", left = "east", right = "west"}

local function parse_move_arg(arg, default_x, default_y)
    if not arg then return nil end
    local dir = arg:match("^%s*([%a]+)%s*$")
    if dir then
        dir = dir:lower()
        dir = CARDINAL_TO_KEY[dir] or dir
        if DIR_TO_DELTA[dir] then
            return default_x, default_y, dir
        end
    end
    local x, y, dir2 = arg:match("^%s*(%-?%d+)%s*,%s*(%-?%d+)%s*,%s*([%a]+)%s*$")
    if not x then return nil end
    dir2 = dir2:lower()
    dir2 = CARDINAL_TO_KEY[dir2] or dir2
    if not DIR_TO_DELTA[dir2] then return nil end
    return tonumber(x), tonumber(y), dir2
end

local function build_tile_report(map_id, x, y, blocking, approach)
    local details = map_reader.get_walkability_details(map_id, x, y)
    local tile_type = map_reader.get_tile_type(map_id, x, y)
    local map_width, map_height = map_reader.get_map_dimensions(map_id)
    local flags = get_block_flags(blocking, x, y, approach)
    local base_walkable = details and details.base_walkable
    local walkable = details and details.effective_walkable
    local permanent_blocked = details and details.permanent_blocked
    local effective_passable = (walkable == true) and not flags.npc_blocked and not flags.approach_blocked
    if approach == nil and flags.fully_blocked then
        effective_passable = false
    end
    return {
        tile_type = tile_type,
        base_walkable = base_walkable,
        walkable = walkable,
        permanent_blocked = permanent_blocked,
        npc_blocked = flags.npc_blocked,
        directional_blocked = flags.directional_blocked,
        blocked_approach = flags.approach,
        approach_blocked = flags.approach_blocked,
        effective_passable = effective_passable,
        reason = details and details.reason or nil,
        map_width = map_width,
        map_height = map_height,
    }
end

local function log_tile_report(map_id, x, y)
    local blocking = route_mgr.build_path_blocking(map_id)
    local report = build_tile_report(map_id, x, y, blocking)
    local msg = string.format(
        "TILE map=0x%02X x=%d y=%d dims=%sx%s tile=%s base_walkable=%s walkable=%s reason=%s permanent_blocked=%s npc_blocked=%s directional_blocked=%s effective_passable=%s",
        map_id, x, y, tostring(report.map_width), tostring(report.map_height),
        tostring(report.tile_type), tostring(report.base_walkable),
        tostring(report.walkable), tostring(report.reason), tostring(report.permanent_blocked),
        tostring(report.npc_blocked), tostring(report.directional_blocked),
        tostring(report.effective_passable))
    debug_tools.info(msg)
    return msg
end

local function log_move_report(from_x, from_y, dir)
    local map_id = snapshot.map_id
    local meta = DIR_TO_DELTA[dir]
    if not meta then
        debug_tools.error("MOVE invalid dir: " .. tostring(dir))
        return nil
    end
    local dest_x = from_x + meta.dx
    local dest_y = from_y + meta.dy
    local blocking = route_mgr.build_path_blocking(map_id)
    local approach = MOVE_DIR_TO_APPROACH[dir]
    local report = build_tile_report(map_id, dest_x, dest_y, blocking, approach)
    local msg = string.format(
        "MOVE map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d) dims=%sx%s tile=%s base_walkable=%s walkable=%s reason=%s permanent_blocked=%s npc_blocked=%s directional_blocked=%s blocked_approach=%s approach_blocked=%s effective_passable=%s",
        map_id, from_x, from_y, dir, dest_x, dest_y,
        tostring(report.map_width), tostring(report.map_height), tostring(report.tile_type),
        tostring(report.base_walkable), tostring(report.walkable), tostring(report.reason),
        tostring(report.permanent_blocked), tostring(report.npc_blocked),
        tostring(report.directional_blocked),
        tostring(report.blocked_approach), tostring(report.approach_blocked),
        tostring(report.effective_passable))
    debug_tools.info(msg)
    return msg, report
end

local edge_probe_state = nil
local edge_verify_state = nil
local EDGE_VERIFY_DEFAULT_ATTEMPTS = 5
local EDGE_VERIFY_MAX_ATTEMPTS = 15
local EDGE_VERIFY_SETTLE_FRAMES = 18
local EDGE_VERIFY_BETWEEN_SETTLE_FRAMES = 30
local get_autowalk_unavailable_reason

local function parse_edge_verify_arg(arg, default_x, default_y)
    if not arg then return nil end
    local parts = {}
    for part in tostring(arg):gmatch("[^,]+") do
        parts[#parts + 1] = part:match("^%s*(.-)%s*$")
    end
    if #parts == 1 or #parts == 2 then
        local dir = parts[1] and parts[1]:lower()
        dir = CARDINAL_TO_KEY[dir] or dir
        if not DIR_TO_DELTA[dir] then
            return nil
        end
        local attempts = parse_int_arg(parts[2]) or EDGE_VERIFY_DEFAULT_ATTEMPTS
        attempts = math.max(1, math.min(EDGE_VERIFY_MAX_ATTEMPTS, attempts))
        return default_x, default_y, dir, attempts, false
    end
    if #parts == 3 or #parts == 4 then
        local x = parse_int_arg(parts[1])
        local y = parse_int_arg(parts[2])
        local dir = parts[3] and parts[3]:lower()
        dir = CARDINAL_TO_KEY[dir] or dir
        if x == nil or y == nil or not DIR_TO_DELTA[dir] then
            return nil
        end
        local attempts = parse_int_arg(parts[4]) or EDGE_VERIFY_DEFAULT_ATTEMPTS
        attempts = math.max(1, math.min(EDGE_VERIFY_MAX_ATTEMPTS, attempts))
        return x, y, dir, attempts, true
    end
    return nil
end

local function get_edge_probe_source_flags(map_id, x, y, approach)
    local key = x .. "," .. y
    local static_entry = map_reader.get_directional_blocks(map_id)[key]
    local runtime_entry = route_mgr.is_cell_runtime_blocked(map_id, x, y)
    local static_directional_blocked = has_directional_block(static_entry)
    local runtime_directional_blocked = has_directional_block(runtime_entry)
    local static_approach_blocked = false
    local runtime_approach_blocked = false

    if approach and type(static_entry) == "table" then
        static_approach_blocked = (static_entry[approach] == true)
    end
    if approach and type(runtime_entry) == "table" then
        runtime_approach_blocked = (runtime_entry[approach] == true)
    end

    return {
        static_directional_blocked = static_directional_blocked,
        static_approach_blocked = static_approach_blocked,
        runtime_directional_blocked = runtime_directional_blocked,
        runtime_approach_blocked = runtime_approach_blocked,
    }
end

local function log_edge_probe_mismatch(probe, final_report, status)
    if not probe or not probe.start_report then
        return
    end

    local start_report = probe.start_report
    local kind = nil

    if status == "moved" and (start_report.approach_blocked or start_report.effective_passable == false) then
        kind = "moved_through_modeled_block"
    elseif status == "blocked"
        and start_report.permanent_blocked ~= true
        and start_report.npc_blocked ~= true
        and start_report.approach_blocked ~= true
        and start_report.effective_passable == true then
        kind = "blocked_despite_open_preview"
    end

    if not kind then
        return
    end

    local approach = MOVE_DIR_TO_APPROACH[probe.dir]
    local source_flags = get_edge_probe_source_flags(probe.map_id, probe.dest_x, probe.dest_y, approach)
    debug_tools.info(string.format(
        "EDGE_PROBE_MODEL_MISMATCH map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d) kind=%s start_approach_blocked=%s start_effective_passable=%s final_approach_blocked=%s final_effective_passable=%s static_approach_blocked=%s runtime_approach_blocked=%s static_directional_blocked=%s runtime_directional_blocked=%s",
        probe.map_id,
        probe.from_x,
        probe.from_y,
        probe.dir,
        probe.dest_x,
        probe.dest_y,
        kind,
        tostring(start_report.approach_blocked),
        tostring(start_report.effective_passable),
        tostring(final_report.approach_blocked),
        tostring(final_report.effective_passable),
        tostring(source_flags.static_approach_blocked),
        tostring(source_flags.runtime_approach_blocked),
        tostring(source_flags.static_directional_blocked),
        tostring(source_flags.runtime_directional_blocked)))
end

local function edge_probe_timeout_frames()
    local base = tonumber(config.get("auto_step_timeout")) or 45
    -- Probes must outlast auto_step's full blocked-move lifecycle:
    -- the initial attempt, turn re-press, and the internal timeout retries
    -- before auto_step finally publishes route_blocked.
    return (base * 5)
end

local function finish_edge_probe(status, reason)
    local probe = edge_probe_state
    if not probe then
        return
    end
    local map_id, px, py = nav.get_position()
    local blocking = route_mgr.build_path_blocking(probe.map_id)
    local approach = MOVE_DIR_TO_APPROACH[probe.dir]
    local report = build_tile_report(probe.map_id, probe.dest_x, probe.dest_y, blocking, approach)
    local msg = string.format(
        "EDGE_PROBE_RESULT map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d) status=%s final=(%d,%d) tile=%s base_walkable=%s walkable=%s permanent_blocked=%s npc_blocked=%s directional_blocked=%s blocked_approach=%s approach_blocked=%s effective_passable=%s reason=%s",
        probe.map_id,
        probe.from_x,
        probe.from_y,
        probe.dir,
        probe.dest_x,
        probe.dest_y,
        tostring(status),
        px or -1,
        py or -1,
        tostring(report.tile_type),
        tostring(report.base_walkable),
        tostring(report.walkable),
        tostring(report.permanent_blocked),
        tostring(report.npc_blocked),
        tostring(report.directional_blocked),
        tostring(report.blocked_approach),
        tostring(report.approach_blocked),
        tostring(report.effective_passable),
        tostring(reason or ""))
    debug_tools.info(msg)
    log_edge_probe_mismatch(probe, report, status)
    tolk.output_interrupt(string.format(
        "Edge probe %s from %d,%d to %d,%d.",
        tostring(status), probe.from_x, probe.from_y, probe.dest_x, probe.dest_y))
    edge_probe_state = nil
end

local function classify_edge_verify_result(verify, final_status)
    local r = verify.results
    if final_status == "cancelled" then
        return "cancelled"
    end
    if (r.map_changed or 0) > 0 then
        return "inconclusive_map_changed"
    end
    if (r.interrupted or 0) > 0 then
        return "inconclusive_interrupted"
    end
    if (r.refused or 0) > 0 or (r.drifted or 0) > 0 then
        return "inconclusive_control"
    end
    if (r.timed_out or 0) > 0 then
        return "inconclusive_timeout"
    end
    if r.blocked == verify.attempts and r.moved == 0 then
        return "confirmed_blocked"
    end
    if r.moved == verify.attempts and r.blocked == 0 then
        return "confirmed_passable"
    end
    if r.moved > 0 and r.blocked > 0 then
        return "mixed"
    end
    return "inconclusive"
end

local function finish_edge_verify(final_status, reason)
    local verify = edge_verify_state
    if not verify then
        return
    end
    auto_step.cancel_active_step(true)
    local classification = classify_edge_verify_result(verify, final_status)
    local runtime_added = false
    local runtime_cleared = false
    if classification == "confirmed_blocked" then
        runtime_added = route_mgr.confirm_runtime_block_for_step(
            verify.map_id,
            verify.from_x,
            verify.from_y,
            verify.dir,
            "verified_probe")
    elseif classification == "confirmed_passable" then
        runtime_cleared = route_mgr.clear_runtime_block_for_step(
            verify.map_id,
            verify.from_x,
            verify.from_y,
            verify.dir,
            "verified_passable")
    end
    debug_tools.info(string.format(
        "EDGE_VERIFY_RESULT map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d) attempts=%d moved=%d blocked=%d timed_out=%d refused=%d drifted=%d map_changed=%d interrupted=%d classification=%s reason=%s runtime_added=%s runtime_cleared=%s",
        verify.map_id,
        verify.from_x,
        verify.from_y,
        verify.dir,
        verify.dest_x,
        verify.dest_y,
        verify.attempts,
        verify.results.moved,
        verify.results.blocked,
        verify.results.timed_out,
        verify.results.refused,
        verify.results.drifted,
        verify.results.map_changed,
        verify.results.interrupted,
        classification,
        tostring(reason or final_status or ""),
        tostring(runtime_added),
        tostring(runtime_cleared)))
    edge_verify_state = nil
end

local function record_edge_verify_attempt(status, reason)
    local verify = edge_verify_state
    if not verify then
        return
    end
    local _, px, py = nav.get_position()
    verify.results[status] = (verify.results[status] or 0) + 1
    debug_tools.info(string.format(
        "EDGE_VERIFY_ATTEMPT map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d) attempt=%d/%d status=%s final=(%d,%d) frames=%d reason=%s",
        verify.map_id,
        verify.from_x,
        verify.from_y,
        verify.dir,
        verify.dest_x,
        verify.dest_y,
        verify.attempt,
        verify.attempts,
        tostring(status),
        px or -1,
        py or -1,
        verify.frames or 0,
        tostring(reason or "")))
    auto_step.cancel_active_step(true)
    if verify.attempt >= verify.attempts then
        finish_edge_verify("complete", reason)
        return
    end
    verify.phase = "between"
    verify.frames = 0
    verify.settle_frames = EDGE_VERIFY_BETWEEN_SETTLE_FRAMES
end

local function start_edge_verify_attempt()
    local verify = edge_verify_state
    if not verify then
        return
    end
    local ok, teleport_reason = DW_QOL_STATE.perform_teleport_to(
        verify.from_x,
        verify.from_y,
        nil,
        {speak = false, check_npc = false, allow_edge_verify = true})
    if not ok then
        verify.results.refused = verify.results.refused + 1
        finish_edge_verify("aborted", "teleport_failed:" .. tostring(teleport_reason))
        return
    end
    snapshot.update()
    objects.update_npcs()
    local msg, start_report = log_move_report(verify.from_x, verify.from_y, verify.dir)
    verify.attempt = verify.attempt + 1
    verify.phase = "settle"
    verify.frames = 0
    verify.settle_frames = EDGE_VERIFY_SETTLE_FRAMES
    verify.start_report = start_report
    debug_tools.info(string.format(
        "EDGE_VERIFY_ATTEMPT_START map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d) attempt=%d/%d preview=%s",
        verify.map_id,
        verify.from_x,
        verify.from_y,
        verify.dir,
        verify.dest_x,
        verify.dest_y,
        verify.attempt,
        verify.attempts,
        tostring(msg or "")))
end

local function tick_edge_verify()
    local verify = edge_verify_state
    if not verify then
        return
    end
    local reason = get_autowalk_unavailable_reason()
    if reason then
        verify.results.interrupted = verify.results.interrupted + 1
        finish_edge_verify("interrupted", reason)
        return
    end
    local map_id, px, py = nav.get_position()
    if map_id ~= verify.map_id then
        verify.results.map_changed = verify.results.map_changed + 1
        finish_edge_verify("aborted", "map_changed")
        return
    end
    if verify.phase == "arming" then
        verify.settle_frames = (verify.settle_frames or 1) - 1
        if verify.settle_frames <= 0 then
            verify.phase = "between"
        end
        return
    end
    if verify.phase == "between" then
        verify.settle_frames = (verify.settle_frames or 0) - 1
        if verify.settle_frames > 0 then
            return
        end
        start_edge_verify_attempt()
        return
    end
    if verify.phase == "settle" then
        verify.settle_frames = verify.settle_frames - 1
        if verify.settle_frames <= 0 then
            verify.phase = "running"
            verify.frames = 0
            if not auto_step.inject_step(verify.dir) then
                record_edge_verify_attempt("refused", "inject_refused")
            end
        end
        return
    end
    if verify.phase ~= "running" then
        return
    end
    verify.frames = verify.frames + 1
    if px == verify.dest_x and py == verify.dest_y then
        record_edge_verify_attempt("moved", "position_changed")
        return
    end
    if px ~= verify.from_x or py ~= verify.from_y then
        record_edge_verify_attempt("drifted", "unexpected_position")
        return
    end
    if verify.frames >= edge_probe_timeout_frames() then
        record_edge_verify_attempt("timed_out", "timeout")
    end
end

local function tick_edge_probe()
    local probe = edge_probe_state
    if not probe then
        return
    end
    local map_id, px, py = nav.get_position()
    probe.frames = probe.frames + 1
    if map_id ~= probe.map_id then
        finish_edge_probe("map_changed", "map_changed")
        return
    end
    if px == probe.dest_x and py == probe.dest_y then
        finish_edge_probe("moved", "position_changed")
        return
    end
    if probe.frames >= edge_probe_timeout_frames() then
        finish_edge_probe("timed_out", "timeout")
    end
end

event_bus.subscribe("route_blocked", function(data)
    local verify = edge_verify_state
    if verify and data
       and verify.phase == "running"
       and data.from_x == verify.from_x
       and data.from_y == verify.from_y
       and data.dir == verify.dir then
        record_edge_verify_attempt("blocked", "route_blocked")
    end
    local probe = edge_probe_state
    if not probe or not data then
        return
    end
    if data.from_x == probe.from_x and data.from_y == probe.from_y and data.dir == probe.dir then
        finish_edge_probe("blocked", "route_blocked")
    end
end)

local function report_blockers_for_current_map()
    local map_id = snapshot.map_id
    local blocking = objects.get_blocking_positions()
    local runtime = route_mgr.format_runtime_blocks(map_id)
    debug_tools.info(string.format(
        "BLOCKERS map=0x%02X npc_count=%d runtime_count=%d",
        map_id, #blocking, #runtime))
    for _, pos in ipairs(blocking) do
        debug_tools.info(string.format("BLOCKER_NPC map=0x%02X x=%d y=%d", map_id, pos.x, pos.y))
    end
    for _, cell_key in ipairs(runtime) do
        debug_tools.info(string.format("BLOCKER_RUNTIME map=0x%02X cell=%s", map_id, cell_key))
    end
end


-- ============================================================
-- Startup
-- ============================================================
-- Announce that the accessibility mod is loaded and ready.
tolk.output("Dragon Warrior Accessibility Mod loaded.")
FCEU.message("DW Access Mod loaded")

-- NOTE: auto_step.on_blocked and auto_step.on_route_complete callbacks
-- are now set in route_manager.lua (loaded above). They handle re-routing,
-- NPC freeze lifecycle, and runtime block recording.

-- ============================================================
-- Constants
-- ============================================================
-- Frame thresholds and grace windows. Grouped so the chunk-level
-- locals stay well under Lua 5.1's 200-local-per-chunk ceiling.
local K = {
    STARTUP_FRAMES                    = 120,  -- 2s of grace after script load
    STABLE_THRESHOLD                  = 30,   -- frames of no change for "done"
    BATTLE_DIALOGUE_STABLE_THRESHOLD  = 14,
    BATTLE_DIALOGUE_FAST_THRESHOLD    = 6,
    BATTLE_DIALOGUE_GRACE_THRESHOLD   = 6,
    BATTLE_DIALOGUE_GRACE             = 120,
    UPPER_STABLE_THRESHOLD            = 30,
    MERCHANT_STABLE_THRESHOLD         = 12,
    FIELD_GRACE                       = 90,   -- 1.5s post-load baseline reset
    FIELD_DEBOUNCE                    = 30,   -- ~0.5s before "Game started."
    TITLE_STABLE                      = 8,    -- frames before announcing cursor
    CURSOR_HOLD                       = 20,   -- blink-off margin before drop
    CHALLENGER_ACCEPT                 = 18,   -- competing-cursor accept threshold
    MOVEMENT_DIALOGUE_HOLD            = 360,
    MENU_UPPER_ABSORB                 = 45,
    RECENT_FIELD_ACTION_HOLD          = 180,
    -- ~40s post-boot window where BizHawk's heavier scan path skips dialogue
    -- and menu polling on idle frames. The hint relaxes back to normal as
    -- soon as movement, dialogue, or menu state is detected. Tuned high
    -- because BizHawk's PPU read cost dominates the first few seconds; can
    -- be re-tuned empirically once steady-state perf is profiled.
    BIZHAWK_BOOT_DIALOGUE_HOLD        = 2400,
}

-- ============================================================
-- Previous-Frame State
-- ============================================================
-- We track values from the previous frame so we only speak when
-- something actually changes. Without this, we'd repeat the same
-- info 60 times per second.
--
-- All previous-frame trackers live on PREV so the chunk-level
-- locals stay well under Lua 5.1's 200-local-per-chunk ceiling.
-- (Note: "prev_keys" lives in hotkeys.lua; use distinct names here.)
local PREV = {
    -- player stats
    hp = nil, mp = nil, level = nil,
    -- inventory (chest detection)
    gold = nil, magic_keys = nil, herbs = nil, items = nil,
    -- lower dialogue
    dialogue = "", announced_dialogue = "", stable_count = 0,
    -- upper dialogue
    upper_dialogue = "", announced_upper = "",
    upper_stable_count = 0, upper_baseline = "", upper_active = false,
    -- merchant
    merchant_text = "", announced_merchant = "",
    merchant_selection = nil, merchant_price = nil,
    -- battle menu
    battle_menu_open = false, battle_cursor_x = nil, battle_cursor_y = nil,
    battle_spell_mode = false, battle_spell_entry_pending = false,
    battle_spell_index = nil, battle_joy_a = false, battle_joy_b = false,
    battle_opening_dialogue_pending = false,
    battle_fast_dialogue = "", battle_fast_prefix = "",
    battle_fast_stable_count = 0,
    -- y<=3 cleaned dialogue
    clean_y1 = "", clean_stable_count = 0,
    -- title cursor
    title_cursor_row = nil, title_cursor_col = nil,
    title_no_cursor_text = "",
    -- name entry
    is_name_entry = false, name_d8 = nil, name_d9 = nil,
    -- save-slot / message-speed
    save_slot_d9 = nil, msg_speed_d9 = nil,
    -- command menu
    cmd_x = nil, cmd_y = nil,
    joy_a_cmd = false, joy_b_status = false,
    -- row1 trace
    row1_lower_dialogue_active = false,
}

-- Startup grace period: skip all change-detection announcements for the
-- first K.STARTUP_FRAMES frames. This lets all the "previous" values
-- initialize from whatever garbage is in RAM at boot without triggering
-- a flood of false announcements (level-up to 255, lost 255 HP, etc.).
local startup_counter = 0     -- Counts up to K.STARTUP_FRAMES

-- Dialogue stabilization tracking
-- Dragon Warrior renders text character by character, so we can't read
-- dialogue the instant it changes. Instead, we wait for the text to
-- stop changing (stabilize) before announcing it.
-- (PREV.dialogue, PREV.announced_dialogue, PREV.stable_count above;
-- K.STABLE_THRESHOLD = 30 frames = 0.5s @ 60fps)

-- Upper dialogue tracking (chest messages, shop text, etc.)
-- Some dialogue windows appear in the upper screen area (rows 1-18)
-- instead of the lower area. We track these separately because the
-- status display (name/LV/HP/MP/G/E) is always present in the upper
-- area and must be filtered out. PREV.upper_dialogue / .announced_upper
-- / .upper_stable_count / .upper_baseline / .upper_active live above.

-- Merchant module: state on MER (defined further below); per-frame
-- text/selection/price baselines on PREV.merchant_*.
local submenu_mode = nil              -- nil (normal), "STATUS", or "ITEM"
local game_state = {state = nil}      -- updated once per frame by state.check_for_changes()
local battle_dialogue_grace_frames = 0
local battle_spell_recovery_available = false

-- y≤3 cleaned-text stability tracking lives on PREV.clean_y1 / .clean_stable_count.
-- The raw dialogue may oscillate every 8–12 frames due to command-menu cursor
-- blink (tile 0x42 adjacent to uppercase labels). PREV.clean_stable_count tracks
-- how long the UPPERCASE-STRIPPED version has been unchanged. Once stable for
-- K.STABLE_THRESHOLD frames, announce exactly once — same as the normal path.

-- y=1 movement tracking (interior maps only).
-- At map y=1, NES scroll displaces the status bar so our LV/HP checks
-- sometimes can't classify the upper text correctly. The reliable signal
-- is player MOVEMENT: when the player moves at y=1 (or just arrives there),
-- the next stable upper text is background noise/status, not dialogue.
-- NPC dialogue appears while the player is frozen (no x/y movement), so
-- it bypasses baseline absorption and gets announced normally.
local y1_baseline_pending = false  -- true when next stable y=1 text is a baseline
local y1_prev_player_x    = nil    -- player X on the previous frame while at y=1

-- Post-start grace period: after a title→field transition (game load),
-- silently re-initialize change-detection baselines for K.FIELD_GRACE frames.
-- The game's load sequence takes several frames during which HP may briefly
-- read 0 and map IDs cycle through intermediate values. Without this, those
-- transient values trigger false "Lost 15 HP" / "Charlock Castle" announcements.
local post_start_grace = 0   -- Counts down from K.FIELD_GRACE when a game starts
local skip_first_hp_check = false  -- Skip one HP/MP check after grace ends

-- Debounce for TITLE→FIELD transition.
-- When backing out of a title sub-menu the screen fades briefly, which clears
-- QUEST/ADVENTUR tiles from the PPU for a few frames. That momentarily makes
-- ppu_shows_title_content() return false while level RAM still holds a value
-- 1-30, causing a false STATE_FIELD for ~5-10 frames. We suppress the "Game
-- started." announcement until FIELD has been stable for K.FIELD_DEBOUNCE frames.
local field_from_title_ct = 0    -- counts up while FIELD follows TITLE

-- True when in actual gameplay (STATE_FIELD or STATE_BATTLE).
-- False on STATE_TITLE. Used to gate interior-map guards in
-- check_dialogue() and check_upper_dialogue() so they don't
-- misfire on garbage/uninitialized RAM during the title screen.
local in_gameplay = false
local MER

-- Title screen cursor tracker.
-- Tracks which menu item or sub-menu slot the cursor is on and announces
-- it when the cursor settles. Uses a hold-timer (not debounce) to survive
-- cursor blink gaps without letting a stale second cursor take over.
-- PREV.title_cursor_row / .title_cursor_col carry the announced position.
-- TITLE.stable below; K.TITLE_STABLE = 8 frames of stability after
-- cursor_just_moved before announcing.

get_autowalk_unavailable_reason = function()
    if game_state.state ~= state.STATE_FIELD then
        return "Auto-walk is only available while walking on the field"
    end
    if debug_tools.is_sweep_active() then
        return "Auto-walk is unavailable during map sweep"
    end
    if path_debug.is_step_mode() then
        return "Finish step mode before auto-walking"
    end
    if DW_QOL_STATE.command_menu_blocks_field_movement
       and DW_QOL_STATE.command_menu_blocks_field_movement() then
        return "Close the command menu before auto-walking"
    end
    if submenu_mode ~= nil then
        return "Close the submenu before auto-walking"
    end
    if MER.active then
        return "Close the merchant interface before auto-walking"
    end
    if PREV.dialogue ~= "" then
        return "Wait for dialogue to finish before auto-walking"
    end
    if PREV.upper_active then
        return "Wait for the upper dialogue window to clear before auto-walking"
    end
    return nil
end

route_mgr.set_autowalk_guard(function()
    local reason = get_autowalk_unavailable_reason()
    return reason == nil, reason
end)

-- PREV.is_name_entry: true when the name-entry alphabet grid is on screen.
-- Tracks transitions so we announce "Name entry." exactly once.
-- PREV.is_name_entry / .name_d8 / .name_d9 hold the per-frame baselines.

-- TITLE.name_entry_active: sticky flag — once name entry is detected
-- (BACK+END on row 22), stays true until the screen changes (save-slot/speed
-- screen opens, or state leaves TITLE). Prevents the race condition where
-- the cursor settles before row 22 finishes rendering.

-- Name entry symbol lookup: grid positions (D8, D9) that correspond to
-- punctuation symbols need human-readable spoken names.
-- D9=2, D8>=4 are the symbols on the uppercase keyboard row 16.
-- D9=5, D8>=4 are , . and then BACK/END on the lowercase keyboard row 22.
local NAME_ENTRY_SYMBOLS = {
    -- Uppercase row symbols (D9=2, D8=4-9)
    ["4,2"] = "hyphen",
    ["5,2"] = "apostrophe",
    ["6,2"] = "exclamation",
    ["7,2"] = "question mark",
    ["8,2"] = "open paren",
    ["9,2"] = "close paren",
    -- Lowercase row symbols and controls (D9=5, D8=4-7)
    ["4,5"] = "comma",
    ["5,5"] = "period",
    ["6,5"] = "BACK",
    ["9,5"] = "END",
}

NAME_ENTRY_SYMBOLS._visible = false
NAME_ENTRY_SYMBOLS._a_was_down = false
NAME_ENTRY_SYMBOLS._a_suppressed_logged = false
NAME_ENTRY_SYMBOLS._a_release_frames = 0

function NAME_ENTRY_SYMBOLS.reset_guard()
    NAME_ENTRY_SYMBOLS._a_was_down = false
    NAME_ENTRY_SYMBOLS._a_suppressed_logged = false
    NAME_ENTRY_SYMBOLS._a_release_frames = 0
end

function NAME_ENTRY_SYMBOLS.apply_guard()
    if game_state.state ~= state.STATE_TITLE or not NAME_ENTRY_SYMBOLS._visible then
        NAME_ENTRY_SYMBOLS.reset_guard()
        return
    end

    local joy = current_joy
    if not joy or not joy.A then
        if NAME_ENTRY_SYMBOLS._a_was_down then
            NAME_ENTRY_SYMBOLS._a_release_frames = NAME_ENTRY_SYMBOLS._a_release_frames + 1
            if NAME_ENTRY_SYMBOLS._a_release_frames >= 6 then
                NAME_ENTRY_SYMBOLS.reset_guard()
            end
        else
            NAME_ENTRY_SYMBOLS._a_suppressed_logged = false
            NAME_ENTRY_SYMBOLS._a_release_frames = 0
        end
        return
    end

    if NAME_ENTRY_SYMBOLS._a_was_down then
        NAME_ENTRY_SYMBOLS._a_release_frames = 0
        local cleaned = {}
        for _, key in ipairs({"up", "down", "left", "right", "B", "select", "start"}) do
            cleaned[key] = joy and joy[key] or false
        end
        cleaned.A = false
        joypad.set(1, cleaned)
        if not NAME_ENTRY_SYMBOLS._a_suppressed_logged then
            debug_tools.debug("NAME_ENTRY_A_SUPPRESS held A after first frame")
            NAME_ENTRY_SYMBOLS._a_suppressed_logged = true
        end
        return
    end

    NAME_ENTRY_SYMBOLS._a_was_down = true
    NAME_ENTRY_SYMBOLS._a_release_frames = 0
end

-- Text seen on the last no-cursor title frame lives on PREV.title_no_cursor_text.
-- TITLE.no_cursor_stable holds the stability counter. Used to announce screens
-- that have no cursor tile (e.g. "PRESS START BUTTON" splash).

-- Save-slot screen state (BEGIN / CONTINUE / COPY / ERASE) — TITLE.save_slot_open.
-- All four sub-screens share the same inner-box layout (slots at rows 20/22/24,
-- digit at col 26) and are handled by a single unified handler. Detected by
-- the inner sub-menu box top-left corner tile (0x64) at row 18, col 10.
-- D9 prev lives on PREV.save_slot_d9.

-- Message speed selection — TITLE.msg_speed_open.
-- D9 tracks which speed is selected: 0=FAST (row 22), 1=NORMAL (row 24), 2=SLOW (row 26).
-- Detected by "FAST" bytes at PPU row 22, cols 15-18. D9 prev lives on PREV.msg_speed_d9.

-- Cursor hold state.
-- Once a cursor is confirmed, we hold that position through blink-off gaps.
-- A different cursor is only accepted after the held cursor has been absent
-- for K.CURSOR_HOLD consecutive frames, preventing sub-menu cursor blink-off
-- from letting the stale main-menu cursor "steal" the held position.
-- DW1 cursor blink-off is ~12-15 frames; K.CURSOR_HOLD = 20 provides margin.
--
-- Title-screen cursor tracking uses a "challenger" model:
--
--   TITLE.cursor_held_row/col: the last accepted cursor position.
--   TITLE.challenger_row/col/frames: a competing cursor we are watching.
--
--   A challenger must be seen CONSECUTIVELY for K.CHALLENGER_ACCEPT frames
--   before it displaces the held cursor. Key rule: when the HELD cursor tile
--   is physically on screen, the challenger streak resets to zero. This
--   prevents two independently blinking cursors from oscillating — the held
--   cursor's ~20-frame blink-on period resets any challenger whose streak
--   has not yet reached the threshold.
--
--   K.CHALLENGER_ACCEPT must satisfy:
--     > blink-off duration (~12-15 frames) — stale cursors never accumulate
--     < blink-on duration  (~20-48 frames) — genuine cursors always succeed
--   18 frames satisfies both constraints with comfortable margin.
-- Title-screen mutable state, grouped on TITLE so chunk locals stay under
-- Lua 5.1's ceiling. PREV.title_cursor_row / .title_cursor_col / .is_name_entry
-- / .name_d8 / .name_d9 / .save_slot_d9 / .msg_speed_d9 / .title_no_cursor_text
-- carry per-frame baselines for this cluster.
-- K.CURSOR_HOLD = 20 frames before cursor_present expires on blink-off.
-- K.CHALLENGER_ACCEPT = 18 frames; must be > blink-off, < blink-on.
local TITLE = {
    cursor_held_row    = nil,
    cursor_held_col    = nil,
    cursor_hold_timer  = 0,
    challenger_row     = nil,
    challenger_col     = nil,
    challenger_frames  = 0,    -- consecutive frames challenger has been last-wins
    stable             = 0,    -- frames since cursor_just_moved (K.TITLE_STABLE gate)
    no_cursor_stable   = 0,    -- stability counter for no-cursor screens
    name_entry_active  = false,
    save_slot_open     = false,
    msg_speed_open     = false,
}

-- Frame counter for throttling periodic checks
-- Some checks don't need to run every frame; we use this to
-- spread work across frames.
local frame_count = 0
DW_QOL_STATE = rawget(_G, "DW_QOL_STATE") or {}
_G.DW_QOL_STATE = DW_QOL_STATE
DW_QOL_STATE.pending_talk_visit = nil
DW_QOL_STATE.teleport_input_suppress_frames = 0
DW_QOL_STATE.TELEPORT_INPUT_SUPPRESS_FRAMES = 6
DW_QOL_STATE.TELEPORT_INPUT_RELEASE_MAX_FRAMES = 90
DW_QOL_STATE.teleport_input_suppress_until_release = nil
DW_QOL_STATE.pending_teleport_face = nil

-- Sub-menu tracking: STATUS, SPELL, and ITEM screens opened from the command menu.
-- When the player selects STATUS, SPELL, or ITEM, the game opens a sub-menu that
-- reuses the D8/D9 cursor RAM for a different purpose. Without tracking,
-- the command menu handler interprets item cursor positions as command menu
-- items (D9=0 → "TALK", D9=1 → "STATUS", etc.).
--
-- submenu_mode: nil (normal), "STATUS", "SPELL", or "ITEM"
-- PREV.cmd_x / .cmd_y: cursor position on the previous frame, used to detect
--   the single-frame jump from a command menu item to a sub-menu cursor.

-- Command-menu / sub-menu / dialogue-hold state. Grouped on CMD so chunk locals
-- stay under Lua 5.1's ceiling. PREV.joy_a_cmd / .joy_b_status hold per-frame
-- A/B button baselines used by this cluster.
local CMD = {
    menu_confirmed       = false,  -- true after a genuine open/cursor move
    yesno_status_block   = 0,      -- brief cooldown after Yes/No dismissal
    cursor_hold          = 0,      -- frames since last visible command-menu cursor
    last_live_x          = nil,
    last_live_y          = nil,
    menu_live            = false,  -- true once a fresh field-menu session is re-armed
    rearm_required       = false,  -- blocks stale row-1 menu residue after TALK/YES-NO
    movement_dialogue    = 0,      -- residual hold while text follows movement
    menu_upper_absorb    = 0,      -- post-menu upper-window baseline-absorb window
    recent_field_action  = 0,      -- recent field input window
    bizhawk_boot_dialogue = 0,     -- early-boot dialogue throttle (BizHawk)
    spell_entry_pending  = false,  -- suppress first SPELL submenu cursor jump
}

-- Merchant module state. PREV.merchant_text / .announced_merchant /
-- .merchant_selection / .merchant_price hold per-frame baselines.
MER = {
    active            = false,  -- shop UI currently up
    intro_pending     = false,  -- speak "Merchant" prefix on first selection
    stable_count      = 0,      -- stability counter for merchant text changes
    scan_present      = false,  -- last full merchant-layout scan result
    scan_present_frame = -1000, -- frame_count at last scan_present refresh
}

local current_joy = {}
local current_joy_any = false

DW_QOL_STATE.cmd_open_speech_delay = 6
DW_QOL_STATE.cmd_open_speech_pending_frames = 0

DW_QOL_STATE.clear_cmd_open_speech_pending = function()
    DW_QOL_STATE.cmd_open_speech_pending_frames = 0
end

DW_QOL_STATE.command_open_message = function(item)
    return item and ("Command. " .. item) or "Command."
end

DW_QOL_STATE.queue_cmd_open_speech = function()
    DW_QOL_STATE.cmd_open_speech_pending_frames = DW_QOL_STATE.cmd_open_speech_delay
end

DW_QOL_STATE.speak_cmd_open = function(item)
    DW_QOL_STATE.clear_cmd_open_speech_pending()
    tolk.output(DW_QOL_STATE.command_open_message(item))
end

DW_QOL_STATE.flush_pending_cmd_open = function(item)
    if DW_QOL_STATE.cmd_open_speech_pending_frames <= 0 then
        return false
    end
    DW_QOL_STATE.speak_cmd_open(item)
    return true
end

DW_QOL_STATE.tick_pending_cmd_open = function(frame_delta, item)
    if DW_QOL_STATE.cmd_open_speech_pending_frames <= 0 then
        return false
    end
    DW_QOL_STATE.cmd_open_speech_pending_frames = math.max(
        0,
        DW_QOL_STATE.cmd_open_speech_pending_frames - scan_profiler.stable_delta(frame_delta))
    if DW_QOL_STATE.cmd_open_speech_pending_frames == 0 then
        DW_QOL_STATE.speak_cmd_open(item)
        return true
    end
    return false
end

DW_QOL_STATE.command_menu_blocks_field_movement = function()
    -- menu.is_open() is a raw COMMAND-header PPU match. After TALK or other
    -- dialogue transitions, COMMAND text can linger in nametable memory after
    -- the field menu has stopped being interactive. Movement/autowalk should
    -- only be blocked by a confirmed live command-menu session. The raw header
    -- is safe once paired with CMD.menu_live, because TALK/menu-close paths
    -- clear CMD.menu_live before stale PPU text can linger.
    return CMD.menu_live and (CMD.cursor_hold > 0 or menu.is_open())
end

DW_QOL_STATE.arm_talk_visit_marker = function()
    DW_QOL_STATE.pending_talk_visit = {frame = frame_count}
end

DW_QOL_STATE.mark_pending_talk_visit = function(event)
    if not DW_QOL_STATE.pending_talk_visit then
        return
    end
    local pending_age = frame_count - DW_QOL_STATE.pending_talk_visit.frame
    if pending_age > 720 then
        debug_tools.debug("VISITED_AUTO skipped: TALK marker expired age=" .. tostring(pending_age))
        DW_QOL_STATE.pending_talk_visit = nil
        return
    end
    local dialogue_text = event and event.text or ""
    if tostring(dialogue_text):lower():find("there is no one there", 1, true) then
        debug_tools.debug("VISITED_AUTO skipped: TALK did not find anyone")
        DW_QOL_STATE.pending_talk_visit = nil
        return
    end

    local map_id, px, py = nav.get_position()
    local obj = objects.mark_adjacent_npc_visited(map_id, px, py)
    if obj then
        debug_tools.info(string.format(
            "VISITED_AUTO map=0x%02X target_id=%s target_name=%s",
            map_id,
            tostring(obj.id),
            tostring(obj.name)))
    else
        debug_tools.debug("VISITED_AUTO skipped: no adjacent NPC matched TALK dialogue")
    end
    DW_QOL_STATE.pending_talk_visit = nil
end

event_bus.subscribe("dialogue_new", function(event)
    DW_QOL_STATE.mark_pending_talk_visit(event)
end)

-- Hidden row-1 command diagnostics.
-- Writes compact transition lines to row1_menu_diag.txt so row-1 menu/guard
-- bugs can be inspected without adding spoken noise during play. Gated on
-- DEBUG_MODE: leaving this on unconditionally meant filesystem I/O on the
-- gameplay hot path every time the player crossed an interior y<=1 row.
local ROW1_TRACE_ENABLED = debug_tools.DEBUG_MODE
local ROW1_TRACE_FILE = "row1_menu_diag.txt"
local row1_trace_frame = 0
-- prev row1 lower-dialogue baseline lives on PREV.row1_lower_dialogue_active.

-- Startup loop diagnostics.
-- When debug_mode=true, capture a few immediate loop markers in a separate
-- file so launcher/debug issues can distinguish "script loaded" from
-- "FCEU.frameadvance() returned and the loop continued".
local STARTUP_LOOP_TRACE_ENABLED = debug_tools.DEBUG_MODE
local STARTUP_LOOP_TRACE_FILE = "startup_loop_diag.txt"

local function should_trace_startup_loop()
    return frame_count <= 3 or frame_count == 60 or frame_count == 120 or frame_count == 180
end

local function trace_startup_loop(event)
    if not STARTUP_LOOP_TRACE_ENABLED or not should_trace_startup_loop() then return end
    local f = io.open(STARTUP_LOOP_TRACE_FILE, "a")
    if f then
        f:write(string.format(
            "frame=%d startup=%d event=%s\n",
            frame_count,
            startup_counter,
            tostring(event)
        ))
        f:close()
    end
end

-- NOTE: Hotkey handling (handle_hotkeys, is_key_pressed, prev_keys) has been
-- extracted to hotkeys.lua. The main loop calls hotkeys.update(keys).


-- ============================================================
-- Automatic Announcements
-- ============================================================
-- These fire automatically when game state changes, without
-- the player pressing any hotkeys.

-- get_scroll_tiles(): Read the NES horizontal scroll offset in NES tile units.
--
-- addr.SCROLL_X holds the PPU $2005 shadow register in PIXELS (0-255).
-- Dividing by 8 converts to NES tile units (0-31) as expected by read_ppu_row.
--
-- Example: at interior map x=8, value = 88 pixels = 11 NES tiles.
-- Dialogue text at screen col 5 + 11 = NT col 16, with chars 17+ overflowing
-- into NT1 ($2400) — the root cause of truncated text at east map edges.
local function get_scroll_tiles()
    if addr.SCROLL_X == nil then return 0 end
    return math.floor(memory.readbyte(addr.SCROLL_X) / 8)
end

DW_QOL_STATE.get_scroll_base_nametable = function()
    if addr.PPU_CTRL == nil then return 0 end
    return memory.readbyte(addr.PPU_CTRL) % 2
end

-- get_dialogue_start_row(): Compute the nametable row where the dialogue window begins.
--
-- DW1's dialogue window always appears at VISUAL row 19. The NES vertical scroll
-- register (addr.SCROLL_Y = 0x0007) shifts which NAMETABLE row that maps to:
--   nametable_row = (19 + scroll_tiles) % 30
--
-- Empirically confirmed from title_diag data:
--   player y=8:  scroll_px=16,  scroll_tiles=2,  nametable row (19+2)%30 = 21
--   player y=15: scroll_px=128, scroll_tiles=16, first dialogue line at row (19+16)%30 = 5
--               second line at row 6 (matching "there." in the y=15 title_diag)
--   scroll=0:    nametable row 19 (confirmed by guard dump — text at rows 19-21)
--
-- Bug threshold: at player y >= 12, scroll_tiles >= 10, first dialogue row < 19 —
-- outside the old hardcoded 19-29 range, causing silent command menu responses.
local function get_dialogue_start_row()
    local scroll_y_px = snapshot.scroll_y
    return (19 + math.floor(scroll_y_px / 8)) % 30
end

local function get_vertical_scroll_tiles()
    return math.floor((snapshot.scroll_y or 0) / 8) % 30
end

local function get_merchant_screen_contexts()
    local scroll_tiles = get_scroll_tiles()
    local base_nametable = DW_QOL_STATE.get_scroll_base_nametable()
    local vertical_scroll_tiles = get_vertical_scroll_tiles()
    return {
        {label = "fixed", scroll_tiles = 0, base_nametable = 0, vertical_scroll_tiles = 0},
        {
            label = "live",
            scroll_tiles = scroll_tiles,
            base_nametable = base_nametable,
            vertical_scroll_tiles = vertical_scroll_tiles,
        },
        {
            label = "live_alt_base",
            scroll_tiles = scroll_tiles,
            base_nametable = (base_nametable + 1) % 2,
            vertical_scroll_tiles = vertical_scroll_tiles,
        },
    }
end

-- check_hp_mp_changes(): Announce HP/MP changes (damage, healing, spell use).
local function check_hp_mp_changes()
    local hp = snapshot.hp
    local mp = snapshot.mp

    -- Battle log already narrates damage/spell results. Suppress the generic
    -- HP/MP delta announcer during battle and the immediate post-battle grace
    -- window so it does not talk over combat dialogue.
    if game_state.state == state.STATE_BATTLE or battle_dialogue_grace_frames > 0 then
        PREV.hp = hp
        PREV.mp = mp
        return
    end

    -- Only announce after we have a baseline (skip the very first frame)
    if PREV.hp ~= nil then
        -- HP decreased: player took damage
        if hp < PREV.hp then
            local damage = PREV.hp - hp
            tolk.output("Lost " .. damage .. " HP. HP " .. hp)
        -- HP increased: player healed
        elseif hp > PREV.hp then
            local healed = hp - PREV.hp
            tolk.output("Recovered " .. healed .. " HP. HP " .. hp)
        end
    end

    if PREV.mp ~= nil then
        -- MP decreased: spell was cast
        if mp < PREV.mp then
            local cost = PREV.mp - mp
            tolk.output("Used " .. cost .. " MP. MP " .. mp)
        -- MP increased: MP restored (inn, item)
        elseif mp > PREV.mp then
            local restored = mp - PREV.mp
            tolk.output("Recovered " .. restored .. " MP. MP " .. mp)
        end
    end

    PREV.hp = hp
    PREV.mp = mp
end

-- check_level_up(): Announce level-ups.
local function check_level_up()
    local level = snapshot.level
    if PREV.level ~= nil and level > PREV.level then
        tolk.output("Level up! Now level " .. level)
    end
    PREV.level = level
end

-- check_chest_collection(): Detect when the player collects a chest's
-- contents and mark it as opened in the object list.
--
-- Detection: if gold, keys, herbs, or items increase while in field
-- state (not battle) and a chest is within 1 tile of the player,
-- that chest is marked opened. Battle rewards are excluded because
-- they happen in STATE_BATTLE, not STATE_FIELD.
local function check_chest_collection()
    local gold       = snapshot.gold
    local magic_keys = snapshot.keys
    local herbs      = snapshot.herbs
    local cur_items = {
        snapshot.items[1],
        snapshot.items[2],
        snapshot.items[3],
        snapshot.items[4],
    }

    local gained = false
    if PREV.gold       ~= nil and gold       > PREV.gold       then gained = true end
    if PREV.magic_keys ~= nil and magic_keys > PREV.magic_keys then gained = true end
    if PREV.herbs      ~= nil and herbs      > PREV.herbs      then gained = true end
    if PREV.items ~= nil then
        for i = 1, 4 do
            if cur_items[i] ~= PREV.items[i] then gained = true; break end
        end
    end

    if gained then
        local _, px, py = nav.get_position()
        local nearby = objects.get_nearby_chests(px, py, 1)
        if nearby[1] then
            objects.mark_chest_opened(nearby[1].obj.id)
        end
    end

    PREV.gold       = gold
    PREV.magic_keys = magic_keys
    PREV.herbs      = herbs
    PREV.items      = cur_items
end

-- check_map_change(): Announce when the player enters a new area.
local function check_map_change()
    local changes = nav.check_for_changes()
    if changes.position_changed and not changes.map_changed then
        CMD.movement_dialogue = K.MOVEMENT_DIALOGUE_HOLD
    elseif CMD.movement_dialogue > 0 then
        CMD.movement_dialogue = CMD.movement_dialogue - 1
    end

    if changes.map_changed and changes.map_name then
        tolk.output(changes.map_name)
        debug_tools.on_map_change(snapshot.map_id)
        objects.on_map_change(snapshot.map_id, {previous_map_id = changes.previous_map_id})
        event_bus.publish("map_changed", {map_id = snapshot.map_id})
        -- Clear pathfinding state (target, runtime blocks, NPC freeze).
        route_mgr.on_map_change()
        -- Reset y=1 tracking so the new map establishes a fresh baseline.
        -- Without this, if the player was at y=1 on the previous map with the
        -- same X coordinate as the new map's y=1 position, the arrival check
        -- (player_x ~= y1_prev_player_x) would not fire and the baseline would
        -- never be re-established for the new map's different tile layout.
        y1_prev_player_x    = nil
        y1_baseline_pending = false
    elseif game_state.state == state.STATE_FIELD then
        objects.observe_npcs(snapshot.map_id)
    end

    if game_state.state == state.STATE_FIELD then
        local route_event = require("overworld_routes").observe_position(snapshot.map_id, snapshot.x, snapshot.y)
        if route_event then
            debug_tools.info("OVERWORLD_ROUTE: " .. tostring(route_event.log or route_event.message))
            if route_event.refresh and objects.request_refresh then
                objects.request_refresh()
            end
            if route_event.message then
                tolk.output(route_event.message)
            end
        end
    end
end

-- strip_overlap(old, new): Find where new text diverges from old text.
-- Dragon Warrior scrolls the dialogue window, so the new window contents
-- often start with the tail end of the previous page. This function finds
-- that overlap and returns only the genuinely new portion.
--
-- Example:
--   old = "the precious globe and hid it in the darkness."
--   new = "darkness. 'Now, AAAAAAAA, thou must help us..."
--   returns "'Now, AAAAAAAA, thou must help us..."
local function strip_overlap(old, new)
    return text.extract_new_dialogue(old, new)
end

if ROW1_TRACE_ENABLED then
    local f = io.open(ROW1_TRACE_FILE, "w")
    if f then
        f:write("=== Row 1 command trace ===\n")
        f:close()
    end
end

if STARTUP_LOOP_TRACE_ENABLED then
    local f = io.open(STARTUP_LOOP_TRACE_FILE, "w")
    if f then
        f:write("=== Startup loop trace ===\n")
        f:close()
    end
end

local function is_row1_interior_context()
    if not in_gameplay then return false end
    local py = snapshot.player_y
    return not snapshot.is_overworld and py <= 1
end

local function trace_row1(event, changes, extra)
    if not ROW1_TRACE_ENABLED or not is_row1_interior_context() then return end

    local fields = {
        string.format("f=%d", row1_trace_frame),
        event,
        "open=" .. tostring(menu.is_open()),
        "opened=" .. tostring(changes and changes.menu_opened or false),
        "closed=" .. tostring(changes and changes.menu_closed or false),
        "move=" .. tostring(changes and changes.cursor_moved or false),
        "xy=" .. tostring(changes and changes.cursor_x or "nil") .. "," .. tostring(changes and changes.cursor_y or "nil"),
        "confirmed=" .. tostring(CMD.menu_confirmed),
        "live=" .. tostring(CMD.menu_live),
        "rearm=" .. tostring(CMD.rearm_required),
        "hold=" .. tostring(CMD.cursor_hold),
        "yesno=" .. tostring(menu.is_yesno_active()),
        "yesseen=" .. tostring(menu.yesno_cursor_seen()),
        "block=" .. tostring(CMD.yesno_status_block),
        "submenu=" .. tostring(submenu_mode),
    }

    if extra then
        for _, part in ipairs(extra) do
            fields[#fields + 1] = part
        end
    end

    local f = io.open(ROW1_TRACE_FILE, "a")
    if f then
        f:write(table.concat(fields, " | ") .. "\n")
        f:close()
    end
end

local function joypad_has_input(joy)
    return joy.A or joy.B or joy.up or joy.down or joy.left or joy.right
        or joy.start or joy.select
end

local function has_blocking_live_input()
    if not current_joy_any then
        return false
    end
    if auto_step.is_auto_active and auto_step.is_auto_active() then
        return false
    end
    return true
end

local function field_dialogue_guard_active()
    -- This guard is only for passive field play. Post-battle result/status
    -- screens still run under STATE_BATTLE and should be allowed through the
    -- normal dialogue readers when no menu is active.
    if game_state.state ~= state.STATE_FIELD then return false end
    if not in_gameplay then return false end
    if has_blocking_live_input() then return false end
    if DW_QOL_STATE.command_menu_blocks_field_movement() or submenu_mode ~= nil or menu.is_yesno_active() then return false end
    if MER.active then return false end
    return CMD.recent_field_action == 0
end

local function bizhawk_dialogue_hint()
    if not scan_profiler.is_enabled() then return false end
    if game_state.state ~= state.STATE_FIELD then return false end
    return CMD.bizhawk_boot_dialogue > 0
        or PREV.dialogue ~= ""
        or PREV.announced_dialogue ~= ""
        or PREV.upper_active
end

local function lower_dialogue_stable_threshold(dialogue)
    if dialogue == "" then
        return K.STABLE_THRESHOLD
    end

    if battle_dialogue_grace_frames > 0 then
        -- Enemy HP drops to 0 before the final combat line fully resolves,
        -- so the game can leave STATE_BATTLE while that line is still on
        -- screen. Once the text looks complete, announce it quickly before
        -- the victory page replaces it.
        if dialogue:find("[a-z]") and dialogue:match("[%.!?]$") then
            return K.BATTLE_DIALOGUE_GRACE_THRESHOLD
        end
        return K.BATTLE_DIALOGUE_STABLE_THRESHOLD
    end

    if game_state.state == state.STATE_BATTLE then
        return K.BATTLE_DIALOGUE_STABLE_THRESHOLD
    end

    return K.STABLE_THRESHOLD
end

local function reset_merchant_state(sync_dialogue_baselines)
    MER.active = false
    PREV.merchant_text = ""
    PREV.announced_merchant = ""
    PREV.merchant_selection = nil
    PREV.merchant_price = nil
    MER.intro_pending = false
    MER.stable_count = 0
    MER.scan_present = false

    if not sync_dialogue_baselines then
        return
    end

    PREV.dialogue = text.read_dialogue_window_filtered(get_scroll_tiles(), get_dialogue_start_row(), DW_QOL_STATE.get_scroll_base_nametable())
    PREV.stable_count = 0

    PREV.upper_baseline = text.read_upper_window(get_scroll_tiles(), DW_QOL_STATE.get_scroll_base_nametable())
    PREV.upper_dialogue = PREV.upper_baseline
    PREV.announced_upper = PREV.upper_baseline
    PREV.upper_stable_count = 0
    PREV.upper_active = false
end

local function reset_battle_menu_state()
    PREV.battle_menu_open = false
    PREV.battle_cursor_x = nil
    PREV.battle_cursor_y = nil
    PREV.battle_spell_mode = false
    PREV.battle_spell_entry_pending = false
    PREV.battle_spell_index = nil
    PREV.battle_joy_a = false
    PREV.battle_joy_b = false
    PREV.battle_opening_dialogue_pending = false
    PREV.battle_fast_dialogue = ""
    PREV.battle_fast_prefix = ""
    PREV.battle_fast_stable_count = 0
end

local function is_battle_spell_screen_visible()
    local upper = text.read_upper_window(
        get_scroll_tiles(),
        DW_QOL_STATE.get_scroll_base_nametable())
    return battle.is_spell_screen_text(upper, items.get_spell_entries())
end

local function speak_battle_spell_selection(prefix, d9)
    local selection = items.describe_spell_at_d9(d9 or 0)
    local msg = (prefix or "") .. selection
    debug_tools.info("BATTLE_SPELL: " .. msg)
    tolk.output_interrupt(msg)
end

local function check_merchant_screen(frame_delta)
    frame_delta = scan_profiler.stable_delta(frame_delta)
    if not in_gameplay or submenu_mode ~= nil or menu.is_yesno_active() then
        if MER.active then
            reset_merchant_state(true)
        end
        MER.scan_present = false
        MER.scan_present_frame = frame_count
        return false
    end

    local info = merchant.analyze_current_screen({contexts = get_merchant_screen_contexts()})
    MER.scan_present = info.active
    MER.scan_present_frame = frame_count
    if not info.active then
        if MER.active then
            reset_merchant_state(true)
        end
        return false
    end

    local was_active = MER.active
    MER.active = true
    if not was_active then
        MER.intro_pending = true
    end

    local offer = merchant.get_cursor_offer(info.context)
    local selection = offer and offer.name or nil
    local price = offer and offer.price or nil
    if selection and (selection ~= PREV.merchant_selection or price ~= PREV.merchant_price) then
        PREV.merchant_selection = selection
        PREV.merchant_price = price
        local msg
        local price_text = price and string.format("%d gold.", price) or nil
        if MER.intro_pending then
            if price_text then
                msg = string.format("Merchant. Gold %d. %s. %s", snapshot.gold, selection, price_text)
            else
                msg = string.format("Merchant. Gold %d. %s.", snapshot.gold, selection)
            end
            MER.intro_pending = false
        else
            if price_text then
                msg = string.format("%s. %s", selection, price_text)
            else
                msg = selection
            end
        end
        debug_tools.info("MERCHANT_SELECT: " .. msg)
        tolk.output_interrupt(msg)
        PREV.announced_merchant = info.raw_text
        MER.stable_count = 0
        PREV.merchant_text = info.raw_text
        return true
    end

    if info.raw_text ~= PREV.merchant_text then
        PREV.merchant_text = info.raw_text
        MER.stable_count = 0
    else
        MER.stable_count = MER.stable_count + frame_delta
    end

    if MER.stable_count >= K.MERCHANT_STABLE_THRESHOLD
       and info.raw_text ~= PREV.announced_merchant then
        debug_tools.info("MERCHANT: " .. info.summary)
        tolk.output_interrupt(info.summary)
        PREV.announced_merchant = info.raw_text
        MER.intro_pending = false
    end

    return true
end

local function check_battle_menu()
    local cursor_x, cursor_y = menu.get_cursor_position()
    local changes = {
        cursor_x = cursor_x,
        cursor_y = cursor_y,
        cursor_moved = (cursor_x ~= PREV.battle_cursor_x or cursor_y ~= PREV.battle_cursor_y),
        menu_closed = false,
    }
    local joy = joypad.read(1)
    local a_now = joy.A or false
    local b_now = joy.B or false
    local a_just = a_now and not PREV.battle_joy_a
    local b_just = b_now and not PREV.battle_joy_b
    PREV.battle_joy_a = a_now
    PREV.battle_joy_b = b_now
    local item = battle.get_menu_item(cursor_x, cursor_y)

    -- Full upper-window spell detection is expensive in BizHawk. Use it only
    -- when the script reloads directly into an unknown battle menu state. Normal
    -- SPELL entry is tracked from the A press or the immediately-following
    -- A-held cursor jump into the spell list.
    local maybe_spell_list_transition = changes.cursor_moved
        and PREV.battle_cursor_x == 1 and PREV.battle_cursor_y == 0
        and cursor_x == 0 and cursor_y == 0
        and a_now
    if maybe_spell_list_transition then
        PREV.battle_spell_mode = true
        PREV.battle_spell_entry_pending = false
        PREV.battle_spell_index = cursor_y
        PREV.battle_menu_open = true
        PREV.battle_cursor_x = cursor_x
        PREV.battle_cursor_y = cursor_y
        speak_battle_spell_selection("Spells. ", cursor_y)
        return
    end

    if not PREV.battle_spell_mode and battle_spell_recovery_available then
        battle_spell_recovery_available = false
        if is_battle_spell_screen_visible() then
            PREV.battle_spell_mode = true
            PREV.battle_spell_entry_pending = false
            PREV.battle_spell_index = cursor_y
            PREV.battle_menu_open = true
            PREV.battle_cursor_x = cursor_x
            PREV.battle_cursor_y = cursor_y
            speak_battle_spell_selection("Spells. ", cursor_y)
            return
        end
    end

    if PREV.battle_spell_mode then
        if changes.menu_closed then
            PREV.battle_spell_mode = false
            PREV.battle_spell_entry_pending = false
            PREV.battle_spell_index = nil
            PREV.battle_menu_open = false
            return
        end

        if b_just or a_just then
            PREV.battle_spell_mode = false
            PREV.battle_spell_entry_pending = false
            PREV.battle_spell_index = nil
            PREV.battle_menu_open = false
            return
        end

        if PREV.battle_spell_entry_pending and changes.cursor_moved then
            PREV.battle_spell_entry_pending = false
            PREV.battle_spell_index = cursor_y
            PREV.battle_cursor_x = cursor_x
            PREV.battle_cursor_y = cursor_y
            return
        end

        if changes.cursor_moved or cursor_y ~= PREV.battle_spell_index then
            PREV.battle_spell_entry_pending = false
            PREV.battle_spell_index = cursor_y
            PREV.battle_cursor_x = cursor_x
            PREV.battle_cursor_y = cursor_y
            speak_battle_spell_selection("", cursor_y)
        end
        return
    end

    if item == "SPELL" and a_just then
        if items.get_spell_count() == 0 then
            debug_tools.info("BATTLE_SPELL: Spells. Empty.")
            tolk.output_interrupt("Spells. Empty.")
        else
            PREV.battle_spell_mode = true
            PREV.battle_spell_entry_pending = true
            PREV.battle_spell_index = cursor_y
            PREV.battle_menu_open = true
            PREV.battle_cursor_x = cursor_x
            PREV.battle_cursor_y = cursor_y
            speak_battle_spell_selection("Spells. ", cursor_y)
        end
        return
    end

    if a_just then
        -- Selecting a top-level battle command will lead into action dialogue.
        -- Keep the current cursor remembered so the held A press does not
        -- immediately re-announce the same command while the screen transitions.
        PREV.battle_menu_open = true
        PREV.battle_cursor_x = cursor_x
        PREV.battle_cursor_y = cursor_y
        return
    end

    local announce = false

    if not PREV.battle_menu_open then
        announce = true
    elseif cursor_x ~= PREV.battle_cursor_x or cursor_y ~= PREV.battle_cursor_y then
        announce = true
    end

    PREV.battle_menu_open = true
    PREV.battle_cursor_x = cursor_x
    PREV.battle_cursor_y = cursor_y

    if not announce then
        return
    end

    if item then
        debug_tools.info("BATTLE_MENU: " .. item)
        tolk.output(item)
    elseif changes.cursor_moved then
        debug_tools.info(string.format("BATTLE_MENU_RAW: x=%s y=%s", tostring(cursor_x), tostring(cursor_y)))
        tolk.output("Battle cursor " .. tostring(cursor_x) .. ", " .. tostring(cursor_y))
    end
end

local function has_visible_cursor_tile()
    for row = 0, 29 do
        local row_start = 0x2000 + row * 32
        for col = 0, 31 do
            local tile = ppu.readbyte(row_start + col)
            if tile == 0x42 or tile == 0x43 then
                return true
            end
        end
    end
    return false
end

-- check_command_menu(): Announce command menu opening, cursor movement,
-- and handle STATUS/ITEM sub-menu transitions.
--
-- Sub-menu detection:
--   STATUS: A is pressed while a confirmed field command menu is open and
--           the cursor is on STATUS(0,1). Suppressed during a Yes/No prompt
--           and for a few frames after it dismisses, because guard 1 reuses
--           the same window and cursor RAM while asking about Princess Gwaelin.
--
--   ITEM:   While the menu is open, cursor jumps from ITEM(1,1) to (0,*)
--           in a single frame with D9 also changing. This can't happen from
--           normal cursor movement since DW1 menus only move one axis per
--           frame. In ITEM mode, D9 tracks the item cursor and we announce
--           item names from the nybble-encoded RAM slots. Exits when D8
--           returns to 1 (back to command menu) or menu closes entirely.
--
-- Guard: When a Yes/No prompt is active, the game reuses the command menu
-- window (same "COMMAND" header, same cursor RAM). Suppress command menu
-- announcements during yes/no prompts.
local function check_command_menu(frame_delta)
    frame_delta = scan_profiler.stable_delta(frame_delta)
    local changes = menu.check_for_changes()

    -- Field command-menu speech must never run outside actual field state.
    -- Battle screens can reuse cursor RAM and window/header patterns that
    -- superficially resemble the field command menu, but they need their own
    -- dedicated reader. Keep menu.check_for_changes() above so menu.lua's
    -- cached state stays fresh, then bail out silently here.
    if game_state.state ~= state.STATE_FIELD then
        CMD.menu_confirmed = false
        CMD.menu_live = false
        CMD.cursor_hold = 0
        DW_QOL_STATE.clear_cmd_open_speech_pending()
        return
    end

    -- Merchant/shop layouts can coexist with the same cursor RAM and some of
    -- the same window/header signals the command-menu logic watches. When the
    -- merchant screen is present, it must fully override command-menu speech.
    local merchant_present = MER.active or MER.scan_present
    -- Fallback scan only when MER.scan_present is stale (>4 frames). The
    -- check_merchant_screen producer runs at interval 3-12 frames, so a fresh
    -- false result is trustworthy and we can skip the duplicate full-screen
    -- PPU read here.
    if not merchant_present and (frame_count - MER.scan_present_frame) > 4 then
        local info = merchant.analyze_current_screen({contexts = get_merchant_screen_contexts()})
        MER.scan_present = info.active
        MER.scan_present_frame = frame_count
        merchant_present = info.active
    end
    if merchant_present then
        CMD.menu_confirmed = false
        CMD.menu_live = false
        CMD.cursor_hold = 0
        CMD.spell_entry_pending = false
        DW_QOL_STATE.clear_cmd_open_speech_pending()
        if submenu_mode == "ITEM" or submenu_mode == "STATUS" or submenu_mode == "SPELL" then
            submenu_mode = nil
        end
        return
    end

    -- Save previous cursor position for transition detection, then update.
    local was_x = PREV.cmd_x
    local was_y = PREV.cmd_y
    PREV.cmd_x = changes.cursor_x
    PREV.cmd_y = changes.cursor_y

    -- === STATUS sub-menu mode ===
    -- Stay in STATUS until the command menu re-opens (player pressed B to
    -- return to the command menu) or B is pressed (in case pressing B from
    -- STATUS goes directly to the field on some game versions).
    if submenu_mode == "STATUS" then
        local joy = joypad.read(1)
        local b_just = joy.B and not PREV.joy_b_status
        PREV.joy_b_status = joy.B
        if changes.menu_opened or b_just then
            submenu_mode = nil
            -- Reset cursor tracking so the first frame back in the command
            -- menu sees a cursor_moved and announces the current position.
            -- Without this, PREV.cmd_x/y can match the post-STATUS cursor
            -- values, making the entire next menu session silent.
            PREV.cmd_x = nil
            PREV.cmd_y = nil
            if changes.menu_opened then
                CMD.menu_upper_absorb = K.MENU_UPPER_ABSORB
                CMD.menu_live = true
                CMD.rearm_required = false
                CMD.last_live_x = changes.cursor_x
                CMD.last_live_y = changes.cursor_y
                local open_item = changes.item_name or menu.get_menu_item(changes.cursor_x, changes.cursor_y)
                trace_row1("CMD_OPEN_FROM_STATUS", changes, {
                    "cursor=" .. tostring(has_visible_cursor_tile()),
                    "item=" .. tostring(open_item),
                })
                DW_QOL_STATE.queue_cmd_open_speech()
                debug_tools.on_menu_open()
                event_bus.publish("menu_opened")
            end
        end
        return
    end

    -- === ITEM sub-menu mode ===
    if submenu_mode == "ITEM" then
        if changes.menu_closed then
            -- Entire menu closed (item was used, or player backed out
            -- past the command menu). Exit sub-menu.
            submenu_mode = nil
            CMD.menu_upper_absorb = K.MENU_UPPER_ABSORB
            CMD.menu_live = false
            DW_QOL_STATE.clear_cmd_open_speech_pending()
            trace_row1("CMD_CLOSE_FROM_ITEM", changes, {})
            return
        end
        if changes.cursor_moved and changes.cursor_x == 1 then
            -- D8 jumped back to right column → returned to command menu.
            -- Announce the command menu item the cursor landed on.
            submenu_mode = nil
            CMD.menu_live = true
            CMD.rearm_required = false
            local cmd_item = menu.get_menu_item(changes.cursor_x, changes.cursor_y)
            if cmd_item then
                trace_row1("CMD_CURSOR_FROM_ITEM", changes, {
                    "item=" .. cmd_item,
                })
                tolk.output(cmd_item)
            end
            return
        end
        -- Item cursor moved within the list — announce the new item name.
        if changes.cursor_moved then
            trace_row1("ITEM_CURSOR", changes, {
                "item=" .. tostring(items.get_item_at_d9(changes.cursor_y)),
            })
            tolk.output(items.get_item_at_d9(changes.cursor_y))
        end
        return
    end

    -- === SPELL sub-menu mode ===
    if submenu_mode == "SPELL" then
        if changes.menu_closed then
            -- Entire menu closed (spell was cast, or player backed out
            -- past the command menu). Exit sub-menu.
            submenu_mode = nil
            CMD.menu_upper_absorb = K.MENU_UPPER_ABSORB
            CMD.menu_live = false
            CMD.spell_entry_pending = false
            DW_QOL_STATE.clear_cmd_open_speech_pending()
            trace_row1("CMD_CLOSE_FROM_SPELL", changes, {})
            return
        end
        if changes.cursor_moved and changes.cursor_x == 1 then
            -- D8 jumped back to right column -> returned to command menu.
            submenu_mode = nil
            CMD.menu_live = true
            CMD.rearm_required = false
            CMD.spell_entry_pending = false
            local cmd_item = menu.get_menu_item(changes.cursor_x, changes.cursor_y)
            if cmd_item then
                trace_row1("CMD_CURSOR_FROM_SPELL", changes, {
                    "item=" .. cmd_item,
                })
                tolk.output(cmd_item)
            end
            return
        end
        if changes.cursor_moved and CMD.spell_entry_pending then
            -- The frame after selecting SPELL can jump from the command cursor
            -- to the first spell row. Entry already spoke that row.
            CMD.spell_entry_pending = false
            return
        end
        -- Spell cursor moved within the list - announce the new spell name.
        if changes.cursor_moved then
            trace_row1("SPELL_CURSOR", changes, {
                "spell=" .. tostring(items.describe_spell_at_d9(changes.cursor_y)),
            })
            tolk.output(items.describe_spell_at_d9(changes.cursor_y))
        end
        return
    end

    -- === Normal command menu handling ===

    -- If a real command menu just opened while the Yes/No hold timer was still
    -- counting down from a blink gap or prior false positive, clear that stale
    -- Yes/No state so the menu can announce normally. Only do this when the
    -- cursor was NOT physically seen before YES/NO on this frame.
    if changes.menu_opened and not menu.yesno_cursor_seen() then
        menu.reset_yesno()
    end

    -- Track A button EVERY frame (even during yes/no) so PREV.joy_a_cmd
    -- stays fresh. If we only tracked after the yesno guard, PREV.joy_a_cmd
    -- would go stale and produce a false rising-edge when yesno dismisses.
    local joy_a_now = joypad.read(1).A or false
    local a_just = joy_a_now and not PREV.joy_a_cmd
    PREV.joy_a_cmd = joy_a_now

    -- Yes/No prompt reuses the command menu UI — suppress command menu
    -- announcements while it is active (check_yesno_prompt handles them).
    if menu.is_yesno_active() then
        -- A yes/no prompt is not a real field command menu. Clear the
        -- confirmation flag so the prompt-confirm A press cannot be
        -- misinterpreted as selecting STATUS on the dismissal edge.
        CMD.menu_confirmed = false
        CMD.menu_live = false
        CMD.cursor_hold = 0
        DW_QOL_STATE.clear_cmd_open_speech_pending()
        trace_row1("CMD_BLOCK_YESNO", changes, {})
        return
    end

    local lower_dialogue_active = text.read_dialogue_window_filtered(get_scroll_tiles(), get_dialogue_start_row(), DW_QOL_STATE.get_scroll_base_nametable()) ~= ""
    local cursor_visible = has_visible_cursor_tile()

    -- If lower dialogue is still visible, COMMAND/header/cursor tiles are
    -- stale backing UI rather than a usable field menu. This is especially
    -- common inside shops: the game redraws TALK/STATUS/etc. behind purchase
    -- prompts and error text while D8/D9 continue to change.
    if lower_dialogue_active and not changes.menu_opened then
        CMD.menu_confirmed = false
        CMD.menu_live = false
        CMD.cursor_hold = 0
        DW_QOL_STATE.clear_cmd_open_speech_pending()
        trace_row1("CMD_BLOCK_LOWER_DIALOGUE", changes, {
            "cursor=" .. tostring(cursor_visible),
        })
        return
    end

    if is_row1_interior_context() then
        if lower_dialogue_active ~= PREV.row1_lower_dialogue_active then
            trace_row1("DIALOGUE_LOWER_" .. (lower_dialogue_active and "ON" or "OFF"), changes, {
                "cursor=" .. tostring(cursor_visible),
            })
        end
        PREV.row1_lower_dialogue_active = lower_dialogue_active
    else
        PREV.row1_lower_dialogue_active = false
    end

    -- COMMAND text can linger in PPU after the real menu has closed. A visible
    -- cursor tile is the reliable signal that the player is actually in a live
    -- command menu session, so keep a short hold timer to bridge cursor blink.
    if menu.is_open() and cursor_visible then
        CMD.cursor_hold = 12
    elseif CMD.cursor_hold > 0 then
        CMD.cursor_hold = math.max(0, CMD.cursor_hold - frame_delta)
    end

    -- STATUS uses the same COMMAND header and cursor coordinates as the field
    -- menu, so only accept it from a confirmed live command-menu session.
    -- Row-1 interiors can produce noisy COMMAND-header matches, so rely on
    -- either a real menu-open A press or a subsequent cursor movement to mark
    -- the session confirmed instead of allowing any bare A press on STATUS.
    local live_x = CMD.last_live_x or changes.cursor_x
    local live_y = CMD.last_live_y or changes.cursor_y
    if a_just and CMD.menu_confirmed and CMD.menu_live
       and CMD.yesno_status_block == 0
       and not CMD.rearm_required
       and live_x == 0 and live_y == 1 then
        submenu_mode = "STATUS"
        CMD.menu_confirmed = false
        CMD.menu_live = false
        CMD.cursor_hold = 0
        PREV.joy_b_status = false
        CMD.menu_upper_absorb = K.MENU_UPPER_ABSORB
        trace_row1("CMD_STATUS_FIRE", changes, {
            "live_xy=" .. tostring(live_x) .. "," .. tostring(live_y),
            "lower=" .. tostring(lower_dialogue_active),
            "cursor=" .. tostring(cursor_visible),
        })
        tolk.output("Status. " .. items.read_status_string())
        return
    elseif a_just and live_x == 0 and live_y == 1 and CMD.rearm_required then
        trace_row1("CMD_STATUS_GATE_BLOCK", changes, {
            "live_xy=" .. tostring(live_x) .. "," .. tostring(live_y),
            "lower=" .. tostring(lower_dialogue_active),
            "cursor=" .. tostring(cursor_visible),
        })
    end

    -- SPELL uses the same command menu header, but the selected-spell list
    -- reuses D9 as a list index and may not leave a visible cursor tile. Enter
    -- the mode from the confirmed SPELL command so a one-spell list still
    -- speaks immediately instead of waiting for a cursor move that cannot
    -- happen.
    if a_just and CMD.menu_confirmed and CMD.menu_live
       and not CMD.rearm_required
       and live_x == 1 and live_y == 0 then
        local count = items.get_spell_count()
        if count == 0 then
            trace_row1("CMD_SPELL_EMPTY", changes, {})
            tolk.output("Spells. Empty.")
        else
            submenu_mode = "SPELL"
            CMD.menu_live = false
            CMD.spell_entry_pending = true
            trace_row1("CMD_SPELL_FIRE", changes, {
                "spell=" .. tostring(items.describe_spell_at_d9(changes.cursor_y)),
            })
            tolk.output("Spells. " .. items.describe_spell_at_d9(changes.cursor_y))
        end
        return
    end

    -- After TALK or YES/NO, row-1 interiors can leave stale COMMAND/cursor
    -- residue in RAM and the PPU. Require a fresh menu re-arm before treating
    -- any of that state as a live field menu again.
    if CMD.rearm_required and not changes.menu_opened and not changes.cursor_moved then
        trace_row1("CMD_WAIT_REARM", changes, {
            "lower=" .. tostring(lower_dialogue_active),
            "cursor=" .. tostring(cursor_visible),
            "a=" .. tostring(a_just),
        })
        return
    end

    if changes.menu_closed then
        CMD.menu_confirmed = false
        CMD.menu_live = false
        CMD.cursor_hold = 0
        DW_QOL_STATE.clear_cmd_open_speech_pending()
        CMD.menu_upper_absorb = K.MENU_UPPER_ABSORB
        trace_row1("CMD_CLOSE", changes, {})
        debug_tools.on_menu_close()
        event_bus.publish("menu_closed")
        return
    end

    -- Detect ITEM sub-menu entry via cursor jump.
    -- Cursor was on ITEM(1,1) and jumped to (0,*) in one frame while menu
    -- stays open. Both D8 and D9 change simultaneously — impossible from
    -- D-pad input (which changes one axis per frame).
    if changes.cursor_moved and was_x == 1 and was_y == 1
       and changes.cursor_x == 0 and changes.cursor_y ~= was_y then
        local count = items.get_item_count()
        if count == 0 then
            -- No items: game will show an error message and return to the
            -- command menu. Don't enter ITEM mode (exit conditions won't
            -- fire because the item list never actually opens).
            trace_row1("CMD_ITEM_EMPTY", changes, {})
            tolk.output("Items. Empty.")
        else
            submenu_mode = "ITEM"
            CMD.menu_live = false
            trace_row1("CMD_ITEM_FIRE", changes, {
                "item=" .. tostring(items.get_item_at_d9(changes.cursor_y)),
            })
            tolk.output("Items. " .. items.get_item_at_d9(changes.cursor_y))
        end
        return
    end

    -- Normal menu opening and cursor movement.
    if changes.menu_opened then
        -- At y<=1 on interior maps, map tile noise in the scrolling nametable
        -- area (rows 6-17) can accidentally contain the "COMMAN" byte sequence
        -- that is_command_menu_open() searches for, producing a spurious
        -- menu-opened event. Suppress the opening announcement; cursor_moved
        -- events still work correctly once the player actually navigates.
        local py  = snapshot.player_y
        if not (not snapshot.is_overworld and py <= 1) then
            -- Menu just opened. DW1 remembers the last-used cursor position,
            -- so announce the actual highlighted item rather than assuming
            -- TALK.
            CMD.menu_upper_absorb = K.MENU_UPPER_ABSORB
            CMD.menu_confirmed = true
            CMD.menu_live = true
            CMD.rearm_required = false
            CMD.cursor_hold = math.max(CMD.cursor_hold, 12)
            CMD.last_live_x = changes.cursor_x
            CMD.last_live_y = changes.cursor_y
            local open_item = changes.item_name or menu.get_menu_item(changes.cursor_x, changes.cursor_y)
            trace_row1("CMD_OPEN", changes, {
                "cursor=" .. tostring(cursor_visible),
                "item=" .. tostring(open_item),
            })
            DW_QOL_STATE.queue_cmd_open_speech()
            debug_tools.on_menu_open()
            event_bus.publish("menu_opened")
        elseif a_just then
            -- North-edge suppression avoids false spoken openings from map-tile
            -- noise, but a real command-menu open confirmed by an A press still
            -- deserves the "Command." announcement so the player knows the menu
            -- is open. False-positive map-tile triggers have a_just=false (no
            -- physical button) so they stay silent; only genuine A presses speak.
            CMD.menu_upper_absorb = K.MENU_UPPER_ABSORB
            CMD.menu_confirmed = true
            CMD.menu_live = true
            CMD.rearm_required = false
            CMD.cursor_hold = 12
            CMD.last_live_x = changes.cursor_x
            CMD.last_live_y = changes.cursor_y
            local open_item = changes.item_name or menu.get_menu_item(changes.cursor_x, changes.cursor_y)
            trace_row1("CMD_OPEN_Y1", changes, {
                "cursor=" .. tostring(cursor_visible),
                "item=" .. tostring(open_item),
            })
            DW_QOL_STATE.queue_cmd_open_speech()
            debug_tools.on_menu_open()
            event_bus.publish("menu_opened")
        end
    elseif changes.cursor_moved and not changes.menu_closed then
        -- Cursor moved within the open menu — announce the new item.
        -- A real D-pad move inside the menu confirms this is a live menu
        -- session, even in row-1 scroll cases where the opening line itself
        -- was intentionally suppressed.
        CMD.menu_confirmed = true
        CMD.menu_live = true
        CMD.rearm_required = false
        CMD.last_live_x = changes.cursor_x
        CMD.last_live_y = changes.cursor_y
        local item = changes.item_name
        if item then
            trace_row1("CMD_CURSOR", changes, {
                "item=" .. item,
                "lower=" .. tostring(lower_dialogue_active),
                "cursor=" .. tostring(cursor_visible),
            })
            if not DW_QOL_STATE.flush_pending_cmd_open(item) then
                tolk.output(item)
            end
        else
            -- Unknown cursor position — announce raw values so the user
            -- can report them for mapping.
            trace_row1("CMD_CURSOR_RAW", changes, {
                "lower=" .. tostring(lower_dialogue_active),
                "cursor=" .. tostring(cursor_visible),
            })
            if not DW_QOL_STATE.flush_pending_cmd_open(nil) then
                tolk.output("Cursor " .. changes.cursor_x .. ", " .. changes.cursor_y)
            end
        end
    elseif not changes.menu_closed then
        DW_QOL_STATE.tick_pending_cmd_open(
            frame_delta,
            changes.item_name or menu.get_menu_item(changes.cursor_x, changes.cursor_y))
    end

    -- Selecting TALK consumes the current field-menu session. Row-1 dialogue
    -- and yes/no follow-ups must re-open or move the cursor again before any
    -- later STATUS-like residue is allowed to act as a live menu.
    if a_just and not changes.menu_opened
       and changes.cursor_x == 0 and changes.cursor_y == 0
       and CMD.menu_confirmed then
        CMD.menu_live = false
        CMD.rearm_required = true
        DW_QOL_STATE.clear_cmd_open_speech_pending()
        DW_QOL_STATE.arm_talk_visit_marker()
        trace_row1("CMD_TALK_FIRE", changes, {
            "cursor=" .. tostring(cursor_visible),
        })
    end
end

-- check_yesno_prompt(): Announce Yes/No prompt appearance and cursor movement.
--
-- Dragon Warrior NPCs sometimes ask yes/no questions ("Dost thou need
-- guidance? YES NO"). The player moves the cursor between YES and NO with
-- the D-pad and confirms with A. Without this function, the cursor change
-- is completely silent since the cursor tile decodes to "" in our text system.
--
-- We call menu.check_yesno_changes() (which also caches the result for
-- check_dialogue()'s guard) and announce:
--   - "YES NO prompt. YES" when the window first appears
--   - "YES" or "NO" when the cursor moves between options
local function check_yesno_prompt(frame_delta)
    frame_delta = scan_profiler.stable_delta(frame_delta)
    local changes = menu.check_yesno_changes(frame_delta)
    if changes.active then
        CMD.yesno_status_block = 10
        CMD.menu_live = false
        CMD.rearm_required = true
        trace_row1("YESNO_ACTIVE", nil, {
            "sel=" .. tostring(changes.selection),
        })
    elseif CMD.yesno_status_block > 0 then
        CMD.yesno_status_block = math.max(0, CMD.yesno_status_block - frame_delta)
    end

    if changes.just_dismissed then
        CMD.menu_confirmed = false
        CMD.menu_live = false
        CMD.cursor_hold = 0
        CMD.rearm_required = true
        trace_row1("YESNO_DISMISS", nil, {})
    end

    if changes.just_appeared then
        -- On the title screen (e.g. erase-quest confirmation), rows 19-29
        -- contain title menu text, not dialogue. Skip question reading there.
        if in_gameplay then
            -- The guard's question may not have completed its 30-frame
            -- stabilization before the Yes/No window appeared. Read the
            -- lower dialogue area right now and announce any text that
            -- hasn't been spoken yet, so the player hears the question
            -- before the Yes/No prompt. Update PREV.announced_dialogue so the
            -- normal dialogue system doesn't repeat it.
            local question = text.read_dialogue_window_filtered(get_scroll_tiles(), get_dialogue_start_row(), DW_QOL_STATE.get_scroll_base_nametable())
            -- Only announce the question if it contains real dialogue text
            -- (at least one lowercase letter). Purely-uppercase strings are either
            -- command menu tiles that haven't been overwritten yet, or the player's
            -- name partially rendered before the rest of the sentence appeared.
            -- The normal dialogue stability path will catch the full text once it
            -- finishes rendering.
            local new_question = strip_overlap(PREV.announced_dialogue, question)
            if new_question ~= "" and question ~= PREV.announced_dialogue and new_question:find("[a-z]") then
                debug_tools.on_dialogue(new_question)
                event_bus.publish("dialogue_new", {text = new_question})
                tolk.output(new_question)
                PREV.announced_dialogue = question
            end
        end
        trace_row1("YESNO_APPEAR", nil, {
            "sel=" .. tostring(changes.selection),
        })
        -- Queue the prompt announcement after the question text
        tolk.output("YES NO prompt. " .. (changes.selection or ""))
    elseif changes.selection_changed then
        -- Cursor moved — announce the newly highlighted option.
        trace_row1("YESNO_CURSOR", nil, {
            "sel=" .. tostring(changes.selection),
        })
        tolk.output(changes.selection)
    end
end

-- read_y1_dialogue(): Read the dialogue text rows for player y≤3.
--
-- At y≤3 on interior maps, the NES vertical scroll shifts the dialogue window
-- upward by 2 nametable rows per player y unit below y=4. The response text
-- that normally sits at nametable rows 19-20 (y=4) is instead at:
--   y=3 → rows 17-18       y=2 → rows 15-16       y=1 → rows 13-14
-- Formula: text_row = 11 + 2 * py   (verified from PPU dumps)
--
-- Some messages use a taller window with 4+ text lines, or two stacked
-- sub-windows. At y=1 the guard's final page spans rows 15-19 (text_row=13),
-- so text_row+5 misses row 19. We scan 9 rows (text_row through text_row+8)
-- to cover the full depth of any window variant. The lowercase filter keeps
-- only rows with real text — border tiles and map tiles decode to "" or
-- uppercase and are silently dropped.
local function read_y1_dialogue(dialogue_fallback)
    local py = snapshot.player_y
    -- Clamp so row numbers stay in valid nametable range (0-29).
    local text_row = math.max(0, 11 + 2 * py)
    local lines = {}
    for row = text_row, math.min(29, text_row + 8) do
        local decoded = text.decode_row(row, get_scroll_tiles(), DW_QOL_STATE.get_scroll_base_nametable())
        if decoded:find("[a-z]") and not text.is_status_text(decoded) then
            lines[#lines + 1] = decoded
        end
    end
    local result = table.concat(lines, " ")
    if dialogue_fallback and dialogue_fallback:find("[a-z]")
       and text.dialogue_score(dialogue_fallback) > text.dialogue_score(result) then
        -- The fixed row formula covers the original row-1 guard cases, but
        -- BizHawk scroll/base state can place text in the normal filtered
        -- lower window instead, or can make the fixed scan catch only the
        -- first line of a multi-line NPC message. Use the richer already-
        -- filtered candidate so short TALK failures and moved-NPC dialogue
        -- are not absorbed or truncated.
        result = dialogue_fallback
    end
    return result
end

-- strip_noise(str): Remove runs of 4+ consecutive zero characters that
-- result from PPU background tiles (CHR index 0x00 → digit "0" in DW1
-- encoding). These appear in large groups on the title screen wherever
-- the nametable is "empty". Actual digit text never has runs that long.
local function strip_noise(str)
    return (str:gsub("0000+", ""):match("^%s*(.-)%s*$") or "")
end


-- decode_row_from_col(row, start_col): Decode PPU nametable tiles on a row
-- starting at start_col, reading through NT0 then NT1. Returns trimmed string.
-- Used to read the item text that follows a cursor tile without including
-- the (empty-decoded) cursor tile itself.
local function decode_row_from_col(row, start_col)
    local bytes = {}
    for col = start_col, 31 do
        bytes[#bytes + 1] = ppu.readbyte(0x2000 + row * 32 + col)
    end
    -- Also read NT1 for text that overflows past column 31.
    for col = 0, 31 do
        bytes[#bytes + 1] = ppu.readbyte(0x2400 + row * 32 + col)
    end
    local t = chars.decode_bytes(bytes)
    return t:match("^%s*(.-)%s*$") or ""
end

-- Title-screen sub-menu detection helpers.
-- Each returns true when its specific screen overlay is visible in the PPU.
--
-- Detection strategy: check a small fixed byte sequence that is unique to
-- each screen and stable (always rendered at the same position).

-- Save-slot sub-screen detection.
-- Save-slot sub-screens come in two layouts depending on the menu option chosen:
--
--   BEGIN A NEW QUEST:
--     Inner box top-left (0x64) at row 18, col 10.
--     Three empty slots displayed at rows 20 / 22 / 24; digit at col 26.
--     D9 (0-2) selects which slot row.
--
--   CONTINUE / COPY / ERASE A QUEST:
--     Inner box top-left (0x64) at row 12, col 6.
--     One slot displayed at row 14; digit at col 22.
--     D9 changes if multiple saves exist; slot row stays 14 (single row in box).
--
-- Returns "begin" or "continue" when a slot screen is open, nil otherwise.
local function save_slot_screen_type()
    -- Require BOTH the box corner tile (0x64) AND a valid slot digit (1-9)
    -- at the expected position. This prevents false positives when other
    -- sub-menus (message speed, etc.) happen to have 0x64 border tiles at
    -- the same positions. Check "continue" first since its box at (12,6)
    -- can overlap with other sub-menu borders.
    if ppu.readbyte(0x2000 + 12 * 32 + 6) == 0x64 then
        local digit = ppu.readbyte(0x2000 + 14 * 32 + 22)
        if digit >= 1 and digit <= 9 then return "continue" end
    end
    if ppu.readbyte(0x2000 + 18 * 32 + 10) == 0x64 then
        local digit = ppu.readbyte(0x2000 + 20 * 32 + 26)
        if digit >= 1 and digit <= 9 then return "begin" end
    end
    return nil
end

-- Message speed screen: options FAST/NORMAL/SLOW at PPU rows 22/24/26.
-- Detect by "FAST" at row 22 cols 15-18.
-- "FAST" = F=0x29 A=0x24 S=0x36 T=0x37.
local FAST_BYTES = {0x29, 0x24, 0x36, 0x37}
local function is_message_speed_open()
    local base = 0x2000 + 22 * 32 + 15
    for i = 1, 4 do
        if ppu.readbyte(base + i - 1) ~= FAST_BYTES[i] then return false end
    end
    return true
end

-- Speed names indexed by D9 value (0=FAST, 1=NORMAL, 2=SLOW).
local SPEED_NAMES = {[0] = "FAST", [1] = "NORMAL", [2] = "SLOW"}

-- announce_adventure_slot(): Read and speak the selected save slot.
-- slot_row: the PPU row containing the slot entry.
-- digit_col: column of the slot-number digit byte (raw DW1 digit 0x01-0x09).
-- Returns false if the slot isn't rendered yet (digit out of range 1-9).
local function announce_adventure_slot(slot_row, digit_col)
    local slot_digit = ppu.readbyte(0x2000 + slot_row * 32 + digit_col)
    -- Guard: 0x5F (space, value 95) appears before the PPU finishes rendering.
    -- Only proceed when the digit byte is a valid slot number (1-9 in DW1).
    if slot_digit < 1 or slot_digit > 9 then return false end
    local row_text = text.decode_row(slot_row)
    -- "ADVENTURE LOG N" is the empty-slot label. If present, just say "Slot N".
    -- Otherwise the row has character info (name, level) — include it.
    if row_text:find("ADVENTURE") then
        tolk.output("Slot " .. slot_digit)
    else
        tolk.output("Slot " .. slot_digit .. ": " .. row_text)
    end
    return true
end

-- check_title_screen(): Title-screen announcer.
--
-- Handles four distinct title-screen contexts in priority order:
--   1. Message speed screen  — D9 tracks FAST/NORMAL/SLOW selection.
--   2. "CONTINUE" adventure log — D9 tracks slot; slots at rows 14/16.
--   3. "BEGIN" adventure log    — D9 tracks slot; slots at rows 20/22.
--   4. Name-entry screen       — first-token of letter under cursor.
--   5. All other title screens — cursor-tile scan with hold-timer.
local function check_title_screen()
    -- Guard: when a Yes/No prompt is active (e.g. erase-quest confirmation),
    -- let check_yesno_prompt() handle it — don't compete with cursor scanning.
    if menu.is_yesno_active() then return end

    -- ---- Message Speed: D9-based speed selection ----
    -- The message speed screen shows FAST/NORMAL/SLOW at PPU rows 22/24/26.
    -- D9 tracks which is selected: 0=FAST, 1=NORMAL, 2=SLOW.
    -- The cursor-tile approach fails (two simultaneous cursors: title menu +
    -- speed option); D9 is instant and reliable.
    local spd_open = is_message_speed_open()
    if spd_open then
        NAME_ENTRY_SYMBOLS._visible = false
        NAME_ENTRY_SYMBOLS.reset_guard()
        local d9 = snapshot.cursor_y
        if not TITLE.msg_speed_open then
            -- First frame the screen is open: record current selection as baseline
            -- without announcing it. The speed is already selected; the player only
            -- needs to hear it when they actively change it.
            PREV.msg_speed_d9 = d9
        elseif d9 ~= PREV.msg_speed_d9 then
            PREV.msg_speed_d9 = d9
            local speed_name = SPEED_NAMES[d9]
            if speed_name then
                tolk.output(speed_name)
            else
                -- Unexpected D9: read the PPU row directly as fallback.
                local speed_row = 22 + d9 * 2
                local row_text  = text.decode_row(speed_row)
                if row_text ~= "" then tolk.output(row_text) end
            end
        end
        TITLE.msg_speed_open = true
        return
    else
        if TITLE.msg_speed_open then PREV.msg_speed_d9 = nil end
        TITLE.msg_speed_open = false
    end

    -- ---- Save-slot screen: unified handler for BEGIN / CONTINUE / COPY / ERASE ----
    -- BEGIN uses the bottom inner box (row 18, col 10); slots at rows 20/22/24, digit col 26.
    -- CONTINUE/COPY/ERASE use the top inner box (row 12, col 6); slot at row 14, digit col 22.
    local slot_type = save_slot_screen_type()
    local slot_open = (slot_type ~= nil)
    if slot_open then
        NAME_ENTRY_SYMBOLS._visible = false
        NAME_ENTRY_SYMBOLS.reset_guard()
        local d9 = snapshot.cursor_y
        if d9 ~= PREV.save_slot_d9 then
            local slot_row, digit_col
            if slot_type == "begin" then
                slot_row  = 20 + d9 * 2
                digit_col = 26
            else
                -- CONTINUE / COPY / ERASE: inner box has slot rows at 14 and 16.
                -- D9 selects which slot: D9=0 → row 14, D9=1 → row 16.
                slot_row  = 14 + d9 * 2
                digit_col = 22
            end
            -- Only announce when the slot digit is valid (1-9). If the PPU
            -- hasn't rendered it yet, PREV.save_slot_d9 stays nil and we
            -- retry next frame. No fallback to raw row text — that reads
            -- stale main-menu text before the slot content renders.
            if announce_adventure_slot(slot_row, digit_col) then
                PREV.save_slot_d9 = d9
            end
        end
        TITLE.save_slot_open = true
        return
    else
        if TITLE.save_slot_open then PREV.save_slot_d9 = nil end
        TITLE.save_slot_open = false
    end

    -- Detect name-entry screen: row 22 uniquely contains BACK and END.
    -- We only need a small region for this; avoid reading all 30 rows.
    local row22 = text.decode_row(22)
    local is_name_entry = (row22:find("BACK") ~= nil and row22:find("END") ~= nil)
    NAME_ENTRY_SYMBOLS._visible = is_name_entry
    if not is_name_entry then
        NAME_ENTRY_SYMBOLS.reset_guard()
    end

    -- Sticky TITLE.name_entry_active: once detected, stays true until the screen
    -- changes. This prevents the race condition where the cursor settles
    -- before row 22 finishes rendering (BACK/END not yet present).
    if is_name_entry then
        TITLE.name_entry_active = true
    end

    -- Announce name-entry context once on transition into it.
    if is_name_entry and not PREV.is_name_entry then
        tolk.output("Name entry. Arrow keys to select letter, BACK to delete, END to finish.")
        -- Initialize D8/D9 tracking so the first cursor position is announced.
        PREV.name_d8 = nil
        PREV.name_d9 = nil
    end
    PREV.is_name_entry = is_name_entry

    -- ---- Name entry: D8/D9-based cursor (instant, no challenger delay) ----
    -- When TITLE.name_entry_active, read cursor position directly from D8/D9 RAM.
    -- This bypasses the 26-frame challenger model entirely, giving instant
    -- response to arrow key presses.
    if TITLE.name_entry_active then
        local d8 = snapshot.cursor_x
        local d9 = snapshot.cursor_y
        if d8 ~= PREV.name_d8 or d9 ~= PREV.name_d9 then
            PREV.name_d8 = d8
            PREV.name_d9 = d9

            -- Check symbol lookup first (symbols need spoken names)
            local sym_key = d8 .. "," .. d9
            local sym_name = NAME_ENTRY_SYMBOLS[sym_key]
            if sym_name then
                tolk.output(sym_name)
            else
                -- Read the letter/text from the PPU grid.
                -- Grid layout: PPU row = 12 + d9 * 2, column = 6 + d8 * 2.
                local ppu_row = 12 + d9 * 2
                local ppu_col = 6 + d8 * 2
                local byte_val = ppu.readbyte(0x2000 + ppu_row * 32 + ppu_col)
                local ch = chars.decode_byte(byte_val)

                if ch and ch ~= "" and ch ~= " " then
                    -- Single letter: add "cap " prefix for uppercase keyboard
                    if d9 <= 2 then
                        tolk.output("cap " .. ch)
                    else
                        tolk.output(ch)
                    end
                else
                    -- Cursor tile or unmapped byte at position: read the text
                    -- after cursor using the PPU row decode (for BACK/END etc.)
                    local row_text = decode_row_from_col(ppu_row, ppu_col + 1)
                    local token = row_text:match("^%s*(%S+)") or row_text
                    if token ~= "" then
                        tolk.output(token)
                    end
                end
            end
        end
        return  -- Skip the challenger model entirely during name entry
    end

    -- Scan all PPU rows for cursor tiles (0x42 or 0x43).
    -- Last-wins: bottom-most cursor is treated as the active one.
    -- When a sub-menu is open, the main-menu cursor (higher on screen)
    -- and the sub-menu cursor (lower) are both visible; we want the lower.
    local cursor_row, cursor_col = nil, nil
    for row = 0, 29 do
        for col = 0, 31 do
            local tile = ppu.readbyte(0x2000 + row * 32 + col)
            if tile == 0x42 or tile == 0x43 then
                cursor_row, cursor_col = row, col
                break
            end
        end
    end

    -- Cursor acceptance: consecutive challenger model.
    --
    -- When the held cursor tile is physically on screen: refresh the hold
    -- timer and reset the challenger streak to 0.
    -- When a different cursor is on screen: increment its consecutive streak.
    -- If the streak reaches the acceptance threshold, that cursor becomes the
    -- new held cursor.
    -- During blink-off (no cursor visible): count down the hold timer but
    -- leave the challenger streak unchanged (blink gaps don't reset progress).
    --
    -- Acceptance threshold: when TITLE.cursor_held_row is nil (no held cursor, fresh
    -- menu open), use a reduced threshold (3 frames) since there's no competing
    -- cursor to protect against. When displacing an existing held cursor, use
    -- the full K.CHALLENGER_ACCEPT (18 frames) for anti-oscillation.
    local accept_threshold = (TITLE.cursor_held_row == nil) and 3 or K.CHALLENGER_ACCEPT
    if cursor_row ~= nil then
        if cursor_row == TITLE.cursor_held_row and cursor_col == TITLE.cursor_held_col then
            -- Held cursor tile physically present: refresh timer, reset challenger.
            TITLE.cursor_hold_timer = K.CURSOR_HOLD
            TITLE.challenger_row    = nil
            TITLE.challenger_col    = nil
            TITLE.challenger_frames = 0
        else
            -- A different cursor is visible: advance consecutive streak.
            if cursor_row == TITLE.challenger_row and cursor_col == TITLE.challenger_col then
                TITLE.challenger_frames = TITLE.challenger_frames + 1
            else
                -- New position: start a fresh streak.
                TITLE.challenger_row    = cursor_row
                TITLE.challenger_col    = cursor_col
                TITLE.challenger_frames = 1
            end
            if TITLE.challenger_frames >= accept_threshold then
                TITLE.cursor_held_row   = TITLE.challenger_row
                TITLE.cursor_held_col   = TITLE.challenger_col
                TITLE.cursor_hold_timer = K.CURSOR_HOLD
                TITLE.challenger_row    = nil
                TITLE.challenger_col    = nil
                TITLE.challenger_frames = 0
            end
            -- Keep cursor_present alive while challenger accumulates.
            if TITLE.cursor_hold_timer > 0 then
                TITLE.cursor_hold_timer = TITLE.cursor_hold_timer - 1
            end
        end
    else
        -- Blink-off: pause challenger streak, count down timer.
        if TITLE.cursor_hold_timer > 0 then
            TITLE.cursor_hold_timer = TITLE.cursor_hold_timer - 1
        end
    end

    -- cursor_just_moved: held cursor settled at a new position.
    -- Update prev immediately so this only fires once per move.
    local cursor_present    = (TITLE.cursor_hold_timer > 0)
    local cursor_just_moved = cursor_present
                              and (TITLE.cursor_held_row ~= PREV.title_cursor_row
                                   or TITLE.cursor_held_col ~= PREV.title_cursor_col)

    if cursor_just_moved then
        TITLE.stable          = 0
        PREV.title_cursor_row = TITLE.cursor_held_row
        PREV.title_cursor_col = TITLE.cursor_held_col
    else
        TITLE.stable = TITLE.stable + 1
    end

    -- Announce after a brief stability wait to let the cursor row finish rendering.
    if TITLE.stable == K.TITLE_STABLE and PREV.title_cursor_row then
        local item = decode_row_from_col(PREV.title_cursor_row, PREV.title_cursor_col + 1)
        -- Fall back to the full row when the post-cursor text has no letters
        -- (e.g. cursor sits between "ADVENTURE LOG " and "1").
        if not item:find("[a-zA-Z]") then
            item = text.decode_row(PREV.title_cursor_row)
        end
        if item ~= "" then
            tolk.output(item)
        end
    end

    -- No-cursor fallback: announce screens that have no cursor tile at all
    -- (e.g. "PRESS START BUTTON" splash). Only fires when:
    --   • no cursor is held (TITLE.cursor_hold_timer expired)
    --   • no cursor is being tracked as a challenger (TITLE.challenger_frames == 0)
    --   • not in name entry (handled separately)
    -- The TITLE.challenger_frames guard prevents this from firing during the normal
    -- cursor acceptance window (18 frames) when a menu first opens — without
    -- it, the fallback reads all screen text as a block announcement before
    -- the cursor is officially accepted.
    if not cursor_present and TITLE.cursor_held_row == nil
       and TITLE.challenger_frames == 0 and not is_name_entry then
        -- Collect rows that contain at least one letter (upper or lower).
        -- Apply strip_noise to remove runs of zeros from empty PPU tiles
        -- (CHR tile 0x00 = digit '0') before checking for letter content.
        local lines = {}
        for row = 0, 29 do
            local line = strip_noise(text.decode_row(row)):match("^%s*(.-)%s*$")
            if line ~= "" and line:find("[a-zA-Z]") then
                lines[#lines + 1] = line
            end
        end
        local full_text = table.concat(lines, " ")
        if full_text == PREV.title_no_cursor_text then
            TITLE.no_cursor_stable = TITLE.no_cursor_stable + 1
        else
            PREV.title_no_cursor_text = full_text
            TITLE.no_cursor_stable    = 0
        end
        if TITLE.no_cursor_stable == K.TITLE_STABLE and full_text ~= "" then
            tolk.output(full_text)
            -- Reset so we don't re-announce the same static screen every frame.
            TITLE.no_cursor_stable = TITLE.no_cursor_stable + 1
        end
    else
        -- Cursor is present (or name-entry): reset no-cursor tracking.
        PREV.title_no_cursor_text = ""
        TITLE.no_cursor_stable    = 0
    end

end

-- check_dialogue(): Read dialogue window and announce when text changes.
-- Dragon Warrior renders text one character at a time, so we wait until
-- the text stops changing for K.STABLE_THRESHOLD frames before announcing.
-- This prevents reading partial text like "The Dragonl" mid-render.
-- When text does stabilize, we strip any overlap with the previous
-- announcement so we only speak genuinely new text.
--
-- At low Y positions on interior maps, the command-menu window overlaps rows
-- 19-29 due to NES vertical scroll. The cursor tile blinks between 0x42
-- (empty) and 0x5F (space) adjacent to uppercase border tiles, producing a
-- 1-space frame-to-frame difference that prevents raw stability from ever
-- being reached. Empirically this affects player rows 1-3; row 4 and below
-- are unaffected (scroll pushes the menu window clear of rows 19-29).
-- Fix: strip runs of 3+ consecutive uppercase letters (and adjacent spaces)
-- before comparing. This normalizes both cursor-blink states to the same
-- string. We then apply the SAME K.STABLE_THRESHOLD to the cleaned text —
-- the cleaned text IS stable even during cursor blink, so the threshold is
-- reached and the announcement fires exactly once. This prevents the
-- per-character "ki…kid…kidnap…" chatter from the old per-change approach.
local function speak_new_dialogue(new_text, battle_dialogue_mode, priority)
    debug_tools.on_dialogue(new_text)
    event_bus.publish("dialogue_new", {text = new_text})
    if battle_dialogue_mode then
        if PREV.battle_opening_dialogue_pending or priority == "interrupt" then
            PREV.battle_opening_dialogue_pending = false
            tolk.output_interrupt(new_text)
        else
            tolk.output(new_text)
        end
    elseif PREV.announced_dialogue == "" then
        tolk.output_interrupt(new_text)
    else
        tolk.output(new_text)
    end
end

local function maybe_announce_battle_opening(dialogue)
    if not PREV.battle_opening_dialogue_pending then return false end
    if game_state.state ~= state.STATE_BATTLE then return false end
    if dialogue == "" or not dialogue:find("draws near", 1, true) then return false end

    local new_text = battle.extract_new_text(PREV.announced_dialogue, dialogue)
    if new_text == "" or not battle.is_coherent_dialogue(new_text) then return false end

    speak_new_dialogue(new_text, true)
    PREV.announced_dialogue = dialogue
    PREV.dialogue = dialogue
    PREV.stable_count = 0
    PREV.clean_y1 = dialogue
    PREV.clean_stable_count = 0
    return true
end

local function announced_battle_prefix(dialogue, new_text, complete_text)
    local start_pos = dialogue:find(new_text, 1, true)
    if start_pos then
        local end_pos = start_pos + #complete_text - 1
        return dialogue:sub(1, end_pos):match("^%s*(.-)%s*$") or complete_text
    end
    return complete_text
end

local function maybe_announce_fast_battle_dialogue(dialogue, frame_delta)
    if game_state.state ~= state.STATE_BATTLE and battle_dialogue_grace_frames <= 0 then
        return false
    end
    if PREV.battle_opening_dialogue_pending then
        return false
    end
    if dialogue == "" or not dialogue:find("[a-z]") then
        return false
    end

    local new_text = battle.extract_new_text(PREV.announced_dialogue, dialogue)
    if new_text == "" then
        return false
    end

    local complete_text = battle.fast_action_prefix(new_text)
    if complete_text == "" then
        PREV.battle_fast_dialogue = ""
        PREV.battle_fast_prefix = ""
        PREV.battle_fast_stable_count = 0
        return false
    end

    local announced_prefix = announced_battle_prefix(dialogue, new_text, complete_text)
    if complete_text ~= PREV.battle_fast_dialogue or announced_prefix ~= PREV.battle_fast_prefix then
        PREV.battle_fast_dialogue = complete_text
        PREV.battle_fast_prefix = announced_prefix
        PREV.battle_fast_stable_count = 0
        PREV.dialogue = dialogue
        PREV.stable_count = 0
        return true
    end

    PREV.battle_fast_stable_count = PREV.battle_fast_stable_count + frame_delta
    if PREV.battle_fast_stable_count < K.BATTLE_DIALOGUE_FAST_THRESHOLD then
        PREV.dialogue = dialogue
        PREV.stable_count = 0
        return true
    end

    speak_new_dialogue(complete_text, true, "interrupt")
    PREV.announced_dialogue = announced_prefix
    PREV.dialogue = dialogue
    PREV.stable_count = 0
    PREV.battle_fast_dialogue = ""
    PREV.battle_fast_prefix = ""
    PREV.battle_fast_stable_count = 0
    PREV.clean_y1 = dialogue
    PREV.clean_stable_count = 0
    return true
end

local function check_dialogue(frame_delta, refresh_ppu)
    frame_delta = scan_profiler.stable_delta(frame_delta)
    if refresh_ppu and emulator_compat.clear_ppu_cache then
        emulator_compat.clear_ppu_cache()
    end
    local py  = snapshot.player_y
    local at_y1 = in_gameplay and not snapshot.is_overworld and py <= 3

    -- Use the filtered reader for ALL y positions: it applies a per-row
    -- lowercase filter to exclude status bar fragments (uppercase "E", "G",
    -- digits) that bleed into rows 19-29 at certain NES scroll positions.
    local dialogue = text.read_dialogue_window_filtered(get_scroll_tiles(), get_dialogue_start_row(), DW_QOL_STATE.get_scroll_base_nametable())
    local battle_dialogue_mode = (game_state.state == state.STATE_BATTLE or battle_dialogue_grace_frames > 0)
    if battle_dialogue_mode then
        dialogue = battle.normalize_dialogue(dialogue)
    end
    local lower_dialogue_visible = (dialogue ~= "")
    local stable_threshold = lower_dialogue_stable_threshold(dialogue)

    if maybe_announce_battle_opening(dialogue) then
        return
    end

    if maybe_announce_fast_battle_dialogue(dialogue, frame_delta) then
        return
    end

    if (field_dialogue_guard_active() and not lower_dialogue_visible) or
       (CMD.movement_dialogue > 0 and not has_blocking_live_input() and not DW_QOL_STATE.command_menu_blocks_field_movement()
        and submenu_mode == nil and not menu.is_yesno_active()) then
        PREV.dialogue = dialogue
        PREV.stable_count = 0
        if at_y1 then
            local y1_dialogue = read_y1_dialogue(dialogue)
            local clean = y1_dialogue:gsub("[%s]*[A-Z][A-Z][A-Z]+[%s]*", "")
            PREV.clean_y1 = clean:match("^%s*(.-)%s*$") or ""
            PREV.clean_stable_count = 0
        end
        return
    end

    if at_y1 then
        -- Use the lowercase-only row filter so command-menu tiles and NT1 noise
        -- are excluded before computing clean. read_y1_dialogue() keeps only
        -- rows with at least one lowercase letter — these are the rows with real
        -- response text. Then strip any remaining uppercase runs (e.g., if a row
        -- mixes a command label with part of the response on the same line).
        local y1_dialogue = read_y1_dialogue(dialogue)
        local clean = y1_dialogue:gsub("[%s]*[A-Z][A-Z][A-Z]+[%s]*", "")
        clean = clean:match("^%s*(.-)%s*$") or ""

        -- Track stability of the cleaned text.
        -- The raw dialogue oscillates (cursor blink), but clean is stable.
        if clean ~= PREV.clean_y1 then
            PREV.clean_stable_count = 0
            PREV.clean_y1 = clean
        else
            PREV.clean_stable_count = PREV.clean_stable_count + frame_delta
        end

        -- Announce once after the cleaned text has been stable for K.STABLE_THRESHOLD
        -- frames. This prevents the per-character "ki … kid … kidnap …" chatter.
        if PREV.clean_stable_count >= stable_threshold then
            if clean:find("[a-z]") and clean ~= PREV.announced_dialogue then
                -- Real response text or NPC dialogue — announce only the new portion.
                -- DW1 scrolls the dialogue window so successive windows share a
                -- tail/prefix boundary. strip_overlap prevents re-announcing the
                -- question that already appeared at the top of the next window.
                local new_text
                if battle_dialogue_mode then
                    new_text = battle.extract_new_text(PREV.announced_dialogue, clean)
                else
                    new_text = strip_overlap(PREV.announced_dialogue, clean)
                end
                if new_text ~= "" then
                    if not battle_dialogue_mode or battle.is_coherent_dialogue(new_text) then
                        speak_new_dialogue(new_text, battle_dialogue_mode)
                        PREV.announced_dialogue = clean
                    end
                end
            elseif not clean:find("[a-z]") and PREV.announced_dialogue ~= "" then
                -- No lowercase: command menu noise — reset for next real text.
                PREV.announced_dialogue = ""
            end
        end

        -- Keep raw PREV.stable_count/PREV.dialogue in sync so the normal path
        -- picks up cleanly when the player moves from y≤3 to y>3.
        if dialogue ~= PREV.dialogue then
            PREV.stable_count = 0
            PREV.dialogue = dialogue
        else
            PREV.stable_count = PREV.stable_count + frame_delta
        end
        return
    end

    -- Normal path (y>1): wait for K.STABLE_THRESHOLD frames of no change.
    if dialogue ~= PREV.dialogue then
        -- Text is still changing — reset the stability counter
        PREV.stable_count = 0
        PREV.dialogue = dialogue
    else
        -- Text hasn't changed since last check — increment stability counter
        PREV.stable_count = PREV.stable_count + frame_delta
    end

    -- Once text has been stable long enough and differs from what we
    -- already announced, speak only the new portion.
    if PREV.stable_count >= stable_threshold then
        if dialogue ~= "" and dialogue ~= PREV.announced_dialogue then
            -- Absorb purely-uppercase text (command menu tiles, map tiles)
            -- without announcing — same principle as the at_y1 uppercase filter.
            -- Real NPC dialogue always contains at least one lowercase letter.
            if not dialogue:find("[a-z]") then
                PREV.announced_dialogue = dialogue
            else
                local new_text
                if battle_dialogue_mode then
                    new_text = battle.extract_new_text(PREV.announced_dialogue, dialogue)
                else
                    new_text = strip_overlap(PREV.announced_dialogue, dialogue)
                end
                if new_text ~= "" then
                    if not battle_dialogue_mode or battle.is_coherent_dialogue(new_text) then
                        speak_new_dialogue(new_text, battle_dialogue_mode)
                        PREV.announced_dialogue = dialogue
                    end
                end
            end
        elseif dialogue == "" and PREV.announced_dialogue ~= "" then
            -- Keep the last announced battle page through the short
            -- post-battle grace window so stale lower-window leftovers do not
            -- re-announce as a fresh reward fragment after the window clears.
            if not battle_dialogue_mode then
                PREV.announced_dialogue = ""
            end
        end
    end
end

-- check_upper_dialogue(): Detect and announce dialogue windows that
-- appear in the upper screen area (rows 1-18).
--
-- The upper screen normally shows the status display (name, LV, HP,
-- MP, G, E) which is always present during field gameplay. When a
-- dialogue window opens (chest message, shop text, etc.), it either:
--   (a) Replaces the status display (the NES overwrites those PPU tiles)
--   (b) Appears alongside/below the status display (additional content)
--
-- We distinguish between status display and dialogue by:
--   - Checking for "LV" and "HP" markers that the status display contains
--   - Checking if the text length exceeds what's expected for just stats
-- When the status display is replaced by dialogue, those markers vanish.
-- When dialogue appears alongside, the total text length exceeds ~50 chars.
local function check_upper_dialogue(frame_delta, refresh_ppu)
    frame_delta = scan_profiler.stable_delta(frame_delta)
    if refresh_ppu and emulator_compat.clear_ppu_cache then
        emulator_compat.clear_ppu_cache()
    end
    -- Command-menu open/close redraws can leave the status bar or menu text in
    -- transitional states that look like fresh upper dialogue. Absorb the
    -- current upper text into the baseline for a short window around those
    -- transitions so normal status text is never announced as dialogue.
    if DW_QOL_STATE.command_menu_blocks_field_movement() or CMD.menu_upper_absorb > 0 then
        local upper = text.read_upper_window(get_scroll_tiles(), DW_QOL_STATE.get_scroll_base_nametable())
        PREV.upper_baseline = upper
        PREV.upper_dialogue = upper
        PREV.announced_upper = upper
        PREV.upper_stable_count = 0
        PREV.upper_active = false
        if CMD.menu_upper_absorb > 0 then
            CMD.menu_upper_absorb = math.max(0, CMD.menu_upper_absorb - frame_delta)
        end
        return
    end

    -- Auto-walk drives directional input across many frames. In the throne room
    -- this can make the upper PPU rows flicker through transient status/map
    -- redraw states that are not real dialogue, but can still satisfy the upper
    -- dialogue classifier for a frame and cancel the route. While an auto-walk
    -- route is active, treat upper-window changes as baseline-only noise.
    if auto_step.is_route_active and auto_step.is_route_active() then
        local upper = text.read_upper_window(get_scroll_tiles(), DW_QOL_STATE.get_scroll_base_nametable())
        PREV.upper_baseline = upper
        PREV.upper_dialogue = upper
        PREV.announced_upper = upper
        PREV.upper_stable_count = 0
        PREV.upper_active = false
        return
    end

    if field_dialogue_guard_active() or
       (CMD.movement_dialogue > 0 and not has_blocking_live_input() and submenu_mode == nil
        and not menu.is_yesno_active()) then
        local upper = text.read_upper_window(get_scroll_tiles(), DW_QOL_STATE.get_scroll_base_nametable())
        PREV.upper_baseline = upper
        PREV.upper_dialogue = upper
        PREV.upper_stable_count = 0
        PREV.upper_active = false
        return
    end

    -- y=1 movement tracking for interior maps.
    -- Update the pending-baseline flag every frame so it reflects current
    -- player movement even during the upper-text stability wait period.
    if in_gameplay and not snapshot.is_overworld then
        local player_y = snapshot.player_y
        if player_y <= 1 then
            local player_x = snapshot.player_x
            if player_x ~= y1_prev_player_x then
                -- Player moved (or just arrived at y=1). The next stable upper
                -- text is status bar noise, not dialogue — mark for absorption.
                y1_baseline_pending = true
            end
            y1_prev_player_x = player_x
        else
            -- Player moved above y=1; reset y=1 tracking state.
            y1_baseline_pending = false
            y1_prev_player_x    = nil
        end
    end

    local upper = text.read_upper_window(get_scroll_tiles(), DW_QOL_STATE.get_scroll_base_nametable())

    -- Guard 1's post-Yes/No reply continues in the LOWER dialogue window while
    -- the status bar remains visible above it. In that state, the upper scan can
    -- misclassify the status bar as fresh upper-window dialogue and speak the
    -- full stats. When real lower dialogue text is present, prefer it and treat
    -- the current upper text as baseline-only content.
    local lower_dialogue = text.read_dialogue_window_filtered(get_scroll_tiles(), get_dialogue_start_row(), DW_QOL_STATE.get_scroll_base_nametable())
    if lower_dialogue ~= "" then
        PREV.upper_baseline = upper
        PREV.upper_dialogue = upper
        PREV.announced_upper = upper
        PREV.upper_stable_count = 0
        PREV.upper_active = false
        return
    end

    -- Track changes with stabilization (same approach as lower dialogue)
    if upper ~= PREV.upper_dialogue then
        PREV.upper_stable_count = 0
        PREV.upper_dialogue = upper
    else
        PREV.upper_stable_count = PREV.upper_stable_count + frame_delta
    end

    -- Only process once text has stabilized for the upper-window threshold.
    -- This is longer than the lower-dialogue threshold to allow the status
    -- bar (which redraws incrementally after player stops moving) to fully
    -- render before we inspect it. See K.UPPER_STABLE_THRESHOLD above.
    if PREV.upper_stable_count < K.UPPER_STABLE_THRESHOLD then return end

    -- y=1 baseline absorption: if the player moved while at y=1, absorb this
    -- stable text as the new baseline without announcing it. The player is
    -- frozen during NPC dialogue, so dialogue text reaches here with
    -- y1_baseline_pending = false and gets announced normally.
    --
    -- IMPORTANT: set PREV.announced_upper = upper (not ""). If we used "",
    -- the command menu's PREV.upper_stable_count reset would cause the SAME noise
    -- to be re-processed 30 frames after the menu closes and look "new" (since
    -- announced is "" but upper is non-empty). Marking it as already-processed
    -- prevents that re-announcement. NPC dialogue is different text, so it still
    -- triggers normally when the player is stationary and upper text changes.
    if y1_baseline_pending then
        PREV.upper_baseline = upper
        PREV.upper_active = false
        PREV.announced_upper = upper  -- mark as processed, not ""
        y1_baseline_pending = false
        return
    end

    -- At y<=1 on interior maps, nametable rows 1-18 contain ONLY:
    --   - Status bar rows (rows 0-5, some may be within 1-18)
    --   - The NES map area (rows 6-17): north-wall tiles that have CHR
    --     indices in the text character range (0x00-0x5F) and decode as
    --     letters. Stone/wall tiles often use 0x24-0x2C which decode as
    --     uppercase A-L. These look identical to text but are not dialogue.
    --   - Possibly command menu item columns (rows 1-5, right side) but NOT
    --     the "COMMAND" header, which is at nametable rows 27-28 (outside
    --     rows 1-18 at y=1 with scroll=0).
    -- Real NPC dialogue in DW1 ALWAYS renders in the lower window (rows
    -- 18-27) and is handled by check_lower_dialogue. Nothing in rows 1-18
    -- at y=1 is ever genuine dialogue — absorb unconditionally.
    if in_gameplay and not snapshot.is_overworld and snapshot.player_y <= 1 then
        PREV.upper_baseline = upper
        PREV.announced_upper = upper
        PREV.upper_active = false
        return
    end

    -- If the current text exactly matches the known baseline (e.g., after NPC
    -- dialogue ends and the screen returns to its pre-dialogue state), treat it
    -- as baseline content. Reset dialogue tracking so the next real change is
    -- caught cleanly, without announcing the return-to-baseline itself.
    if upper == PREV.upper_baseline then
        if PREV.upper_active then
            PREV.upper_active = false
            PREV.announced_upper = upper
        end
        return
    end

    -- Also check for command menu text. After the menu closes, its tiles
    -- may linger in the PPU for several frames. We search for "COMMAN"
    -- (6-char prefix) rather than "COMMAND" because near the east map edge
    -- (player at x=8) the trailing 'D' wraps to the next nametable row and
    -- is absent from the decoded text. "COMMAN" matches both the full and
    -- truncated form. It only appears as the menu window title.
    local has_menu_text = upper:find("COMMAN") ~= nil

    if has_menu_text then
        -- Stale command menu — not dialogue.
        if PREV.upper_active then
            PREV.upper_active = false
            -- Use `upper` (not "") so the same NPC dialogue text does not look
            -- "new" when the menu disappears and the text reverts to just
            -- the dialogue portion. If we used "" here, the dialogue would
            -- re-announce itself after every command menu open/close cycle.
            PREV.announced_upper = upper
        end
        return
    end

    -- Extract the genuinely new text. Strategy depends on whether the
    -- status display is still visible alongside the dialogue.
    local has_status_markers = text.is_status_text(upper)
    local new_text
    if has_status_markers then
        -- Status display still visible + extra dialogue content.
        -- Strip the known status baseline to get just the dialogue.
        new_text = strip_overlap(PREV.upper_baseline, upper)
    else
        -- Status display was entirely replaced by the dialogue window.
        -- The entire upper text is dialogue content.
        new_text = upper
    end

    -- Status-only content with no new text after removing the baseline.
    -- This keeps the baseline fresh without suppressing real upper-window
    -- dialogue that happens to include the status bar markers.
    if has_status_markers and new_text == "" then
        PREV.upper_baseline = upper
        if PREV.upper_active then
            PREV.upper_active = false
            PREV.announced_upper = upper
        end
        return
    end

    -- If stripping the baseline didn't help (no overlap found, returned
    -- the full text including status), and we have a previous announcement,
    -- try stripping that instead to find just the NEW portion.
    if new_text == upper and PREV.announced_upper ~= "" then
        new_text = strip_overlap(PREV.announced_upper, upper)
    end

    -- Baseline overlap can leave just the persistent status row as the
    -- extracted "new" text. Hero names contain lowercase letters, so this must
    -- be checked before the lowercase-dialogue filter below.
    if new_text ~= "" and text.is_status_text(new_text) then
        PREV.upper_baseline = upper
        PREV.announced_upper = upper
        PREV.upper_active = false
        debug_tools.debug("UPPER_DIALOGUE_SUPPRESS_STATUS: " .. new_text)
        return
    end

    -- Filter: suppress announcements that contain no lowercase letters.
    --
    -- Real DW1 dialogue always uses mixed case — lowercase body text with
    -- uppercase proper nouns/labels (e.g. "Thou hast found the KEY!").
    -- Uppercase-only strings are one of three false-positive sources:
    --   1. Map tile noise: CHR tile indices for wall/floor graphics near the
    --      north map edge (player at y=1) fall in the text character range
    --      and decode as letters like 'A' (tile index 0x24). These tiles
    --      appear in PPU rows 1-18 and look like text to read_upper_window().
    --   2. Lingering command menu text: after the menu closes, tiles for
    --      TALK, STATUS, STAIRS, SEARCH, etc. may persist in the PPU for
    --      a frame or two before the game clears them.
    --   3. Status bar labels: HP, MP, LV, G, E — always uppercase, never
    --      counted as dialogue (already filtered by is_just_status above,
    --      but belt-and-suspenders here).
    -- If new_text is non-empty but has zero lowercase letters, treat it as
    -- noise and absorb it into the baseline so it doesn't re-trigger.
    if new_text ~= "" and not new_text:find("[a-z]") then
        if has_status_markers then
            PREV.upper_baseline = upper
        end
        -- Mark as processed (not "") so the next stabilization with the same
        -- text is caught by the "upper == PREV.announced_upper" check and
        -- skips the full classification pipeline, rather than re-running all
        -- filters on identical content.
        PREV.announced_upper = upper
        PREV.upper_active = false
        return
    end

    -- Skip if we already announced this exact text
    if upper == PREV.announced_upper then
        PREV.upper_active = false
        return
    end

    -- Real dialogue detected — mark the window as active.
    PREV.upper_active = true

    if new_text ~= "" then
        debug_tools.on_dialogue(new_text)
        event_bus.publish("dialogue_new", {text = new_text})
        tolk.output_interrupt(new_text)
    end
    PREV.announced_upper = upper
end

-- NOTE: Pathfinding functions (build_pathfind_message, plan_path_to_object,
-- queue_path_steps, pathfind_to_current, autowalk_to_current) have been
-- extracted to route_manager.lua.

-- ============================================================
-- Remote Command Registrations
-- ============================================================
-- These commands can be triggered by writing to dw_commands.txt,
-- e.g.:  echo next_object > dw_commands.txt
-- or via the wrapper script:  ./dw_commands.sh next_object
--
-- Requires debug_mode=true in dw_access.ini.
-- For a full script restart, use Script > Reload in FCEUX's script window.
-- To pick up config file changes without restart, use: reload_config

require("object_commands").register()

-- speak:TEXT — test that TTS is working, e.g.: echo speak:Hello world > dw_commands.txt
debug_tools.register_command("speak", function(arg)
    if arg and arg ~= "" then
        tolk.output_interrupt(arg)
    end
end)

debug_tools.register_command("speech_status", function()
    local backend = tolk.get_backend and tolk.get_backend() or "unknown"
    local ready = tolk.is_ready and tolk.is_ready()
    local available = tolk.is_available and tolk.is_available()
    local err = tolk.get_last_error and tolk.get_last_error() or "none"
    local status = string.format(
        "Speech status. backend=%s. ready=%s. available=%s. error=%s",
        tostring(backend), tostring(ready), tostring(available), tostring(err))
    debug_tools.info(status)
    tolk.output_interrupt(status)
end)

debug_tools.register_command("report_title_state", function()
    local d8 = memory.readbyte(addr.MENU_CURSOR_X)
    local d9 = memory.readbyte(addr.MENU_CURSOR_Y)
    local buttons = memory.readbyte(addr.BUTTONS_PRESSED)
    local joy = joypad.read(1) or {}
    local ppu_row = 12 + d9 * 2
    local ppu_col = 6 + d8 * 2
    local cursor_byte = nil
    local cursor_char = ""
    if ppu_row >= 0 and ppu_row <= 29 and ppu_col >= 0 and ppu_col <= 31 then
        cursor_byte = ppu.readbyte(0x2000 + ppu_row * 32 + ppu_col)
        cursor_char = chars.decode_byte(cursor_byte) or ""
    end

    debug_tools.info(string.format(
        "TITLE_STATE state=%s name_entry_visible=%s TITLE.name_entry_active=%s d8=%d d9=%d cursor_row=%d cursor_col=%d cursor_byte=%s cursor_char=%s buttons=0x%02X joyA=%s joy=%s%s%s%s%s%s%s%s",
        tostring(game_state.state),
        tostring(NAME_ENTRY_SYMBOLS._visible),
        tostring(TITLE.name_entry_active),
        d8,
        d9,
        ppu_row,
        ppu_col,
        cursor_byte and string.format("0x%02X", cursor_byte) or "nil",
        cursor_char ~= "" and cursor_char or "-",
        buttons,
        tostring(joy.A == true),
        joy.up and "up+" or "",
        joy.down and "down+" or "",
        joy.left and "left+" or "",
        joy.right and "right+" or "",
        joy.A and "A+" or "",
        joy.B and "B+" or "",
        joy.select and "select+" or "",
        joy.start and "start+" or ""))

    for row = 6, 26 do
        local decoded = strip_noise(text.decode_row(row))
        if decoded ~= "" then
            debug_tools.info(string.format("TITLE_ROW row=%02d text=%s", row, decoded))
        end
    end
    tolk.output_interrupt("Title state reported")
end)

debug_tools.register_command("report_scan_stats", function()
    if not scan_profiler.is_enabled() then
        debug_tools.info("SCAN_PROFILE unavailable: not running under BizHawk")
        tolk.output_interrupt("Scan stats unavailable outside BizHawk")
        return
    end

    debug_tools.info("SCAN_PROFILE recording=" .. tostring(scan_profiler.is_recording()))
    debug_tools.info(scan_profiler.ppu_stats_line())
    local lines = scan_profiler.profile_lines()
    if #lines == 0 then
        if scan_profiler.is_recording() then
            debug_tools.info("SCAN_PROFILE none")
        else
            debug_tools.info("SCAN_PROFILE none — run start_scan_profiling first")
        end
    else
        for _, line in ipairs(lines) do
            debug_tools.info(line)
        end
    end
    tolk.output_interrupt("Scan stats reported")
end)

debug_tools.register_command("reset_scan_stats", function()
    scan_profiler.reset()
    debug_tools.info("SCAN_PROFILE reset")
    tolk.output_interrupt("Scan stats reset")
end)

debug_tools.register_command("start_scan_profiling", function()
    if scan_profiler.start_recording() then
        debug_tools.info("SCAN_PROFILE recording started")
        tolk.output_interrupt("Scan profiling started")
    else
        debug_tools.info("SCAN_PROFILE recording unavailable: not running under BizHawk")
        tolk.output_interrupt("Scan profiling unavailable outside BizHawk")
    end
end)

debug_tools.register_command("stop_scan_profiling", function()
    scan_profiler.stop_recording()
    debug_tools.info("SCAN_PROFILE recording stopped")
    tolk.output_interrupt("Scan profiling stopped")
end)

debug_tools.register_command("report_blockers", function()
    objects.update_npcs()
    report_blockers_for_current_map()
    local map_id = snapshot.map_id
    tolk.output_interrupt(string.format(
        "Blockers reported. %d runtime blocks on map %02X",
        route_mgr.count_runtime_blocks(map_id), map_id))
end)

debug_tools.register_command("report_npcs", function()
    local map_id = snapshot.map_id
    objects.update_npcs()
    debug_tools.info(string.format("NPCS map=0x%02X", map_id))
    for slot = 0, addr.NPC_COUNT - 1 do
        local base = addr.NPC_DATA_START + (slot * addr.NPC_ENTRY_SIZE)
        local byte0 = memory.readbyte(base)
        local byte1 = memory.readbyte(base + 1)
        local byte2 = memory.readbyte(base + 2)
        local x = byte0 % 0x20
        local y = byte1 % 0x20
        local active = not ((x == 0 and y == 0) or (x == 31 and y == 31))
        if active then
            local sprite_type = math.floor(byte0 / 0x20)
            local direction = math.floor(byte1 / 0x20) % 4
            local obj = objects.find_object_by_id("npc_" .. slot)
            debug_tools.info(string.format(
                "NPC_SLOT map=0x%02X slot=%d id=npc_%d name=%s x=%d y=%d sprite=%d dir=%d move=0x%02X service=%s raw=%02X,%02X,%02X",
                map_id, slot, slot,
                obj and tostring(obj.name) or "unknown",
                x, y, sprite_type, direction, byte2,
                tostring(obj and obj.service == true or false),
                byte0, byte1, byte2))
        end
    end
    tolk.output_interrupt("NPCs reported")
end)

debug_tools.register_command("report_runtime_blocks", function()
    local map_id = snapshot.map_id
    local count = route_mgr.count_runtime_blocks(map_id)
    if count == 0 then
        debug_tools.info(string.format("RUNTIME_BLOCKS map=0x%02X none", map_id))
        tolk.output_interrupt("No runtime blocked cells")
        return
    end
    debug_tools.info(string.format("RUNTIME_BLOCKS map=0x%02X count=%d", map_id, count))
    for _, entry in ipairs(route_mgr.get_runtime_block_entries(map_id)) do
        debug_tools.info(string.format(
            "RUNTIME_BLOCK map=0x%02X x=%d y=%d key=%s dirs=%s",
            map_id,
            entry.x,
            entry.y,
            entry.key,
            table.concat(entry.dir_list, ",")))
    end
    tolk.output_interrupt(string.format("%d runtime blocked cells on map %02X", count, map_id))
end)

debug_tools.register_command("report_upper_dialogue_state", function()
    if emulator_compat.clear_ppu_cache then
        emulator_compat.clear_ppu_cache()
    end
    local upper = text.read_upper_window(get_scroll_tiles(), DW_QOL_STATE.get_scroll_base_nametable())
    local lower = text.read_dialogue_window_filtered(get_scroll_tiles(), get_dialogue_start_row(), DW_QOL_STATE.get_scroll_base_nametable())
    local scroll_tiles = get_scroll_tiles()
    local base_nametable = DW_QOL_STATE.get_scroll_base_nametable()
    local msg = string.format(
        "UPPER_STATE active=%s menu_raw=%s menu_active=%s submenu=%s scroll_tiles=%d base_nt=%d PREV.dialogue_len=%d PREV.announced_dialogue_len=%d upper_len=%d baseline_len=%d announced_len=%d lower_len=%d upper=%q baseline=%q announced=%q lower=%q prev_lower=%q announced_lower=%q",
        tostring(PREV.upper_active),
        tostring(menu.is_open()),
        tostring(DW_QOL_STATE.command_menu_blocks_field_movement()),
        tostring(submenu_mode),
        scroll_tiles,
        base_nametable,
        #(PREV.dialogue or ""),
        #(PREV.announced_dialogue or ""),
        #(upper or ""),
        #(PREV.upper_baseline or ""),
        #(PREV.announced_upper or ""),
        #(lower or ""),
        tostring(upper or ""),
        tostring(PREV.upper_baseline or ""),
        tostring(PREV.announced_upper or ""),
        tostring(lower or ""),
        tostring(PREV.dialogue or ""),
        tostring(PREV.announced_dialogue or "")
    )
    debug_tools.info(msg)
    tolk.output_interrupt("Upper dialogue state reported")
end)

debug_tools.register_command("report_menu_state", function()
    if emulator_compat.clear_ppu_cache then
        emulator_compat.clear_ppu_cache()
    end
    local raw_open = menu.is_command_menu_open()
    local cached_open = menu.is_open()
    local cursor_x, cursor_y = menu.get_cursor_position()
    local item = menu.get_menu_item(cursor_x, cursor_y) or "unknown"
    local lower = text.read_dialogue_window_filtered(
        get_scroll_tiles(),
        get_dialogue_start_row(),
        DW_QOL_STATE.get_scroll_base_nametable())
    local msg = string.format(
        "MENU_STATE raw_open=%s cached_open=%s active_block=%s cursor_visible=%s cursor=(%s,%s) item=%s cmd_confirmed=%s cmd_live=%s cmd_rearm=%s cmd_hold=%d yesno=%s yesno_seen=%s submenu=%s merchant_active=%s merchant_scan=%s lower_len=%d scroll_tiles=%d base_nt=%d dialogue_start_row=%d",
        tostring(raw_open),
        tostring(cached_open),
        tostring(DW_QOL_STATE.command_menu_blocks_field_movement()),
        tostring(has_visible_cursor_tile()),
        tostring(cursor_x),
        tostring(cursor_y),
        tostring(item),
        tostring(CMD.menu_confirmed),
        tostring(CMD.menu_live),
        tostring(CMD.rearm_required),
        CMD.cursor_hold,
        tostring(menu.is_yesno_active()),
        tostring(menu.yesno_cursor_seen()),
        tostring(submenu_mode),
        tostring(MER.active),
        tostring(MER.scan_present),
        #(lower or ""),
        get_scroll_tiles(),
        DW_QOL_STATE.get_scroll_base_nametable(),
        get_dialogue_start_row())
    debug_tools.info(msg)
    tolk.output_interrupt("Menu state reported")
end)

debug_tools.register_command("report_merchant_state", function()
    if emulator_compat.clear_ppu_cache then
        emulator_compat.clear_ppu_cache()
    end
    local info = merchant.analyze_current_screen({contexts = get_merchant_screen_contexts()})
    local offer = merchant.get_cursor_offer(info.context)
    local ctx = info.context or {}
    local scroll_tiles = get_scroll_tiles()
    local base_nametable = DW_QOL_STATE.get_scroll_base_nametable()
    local msg = string.format(
        "MERCHANT_STATE active=%s buy_prompt=%s status_markers=%d offers=%q summary=%q cursor_name=%q cursor_price=%s cursor_row=%s context=%s context_scroll=%s context_base=%s context_vertical=%s scroll_tiles=%d base_nt=%d dialogue_start_row=%d",
        tostring(info.active),
        tostring(info.buy_prompt),
        tonumber(info.status_marker_count) or 0,
        table.concat(info.offers or {}, ", "),
        tostring(info.summary or ""),
        tostring(offer and offer.name or ""),
        tostring(offer and offer.price or "nil"),
        tostring(offer and offer.row or "nil"),
        tostring(info.context_label or ""),
        tostring(ctx.scroll_tiles or "nil"),
        tostring(ctx.base_nametable or "nil"),
        tostring(ctx.vertical_scroll_tiles or "nil"),
        scroll_tiles,
        base_nametable,
        get_dialogue_start_row())
    debug_tools.info(msg)
    local rows = merchant.read_rows(info.context)
    for row = 0, 29 do
        local line = rows[row]
        if line and line ~= "" then
            debug_tools.info(string.format("MERCHANT_ROW row=%02d text=%q", row, tostring(line)))
        end
    end
    tolk.output_interrupt("Merchant state reported")
end)

debug_tools.register_command("clear_runtime_blocks", function(arg)
    if arg and arg:match("^%s*all%s*$") then
        route_mgr.clear_runtime_blocks("all")
        tolk.output_interrupt("Cleared runtime blocks for all maps")
        return
    end
    local map_id = snapshot.map_id
    if arg and arg ~= "" then
        map_id = parse_int_arg(arg)
        if map_id == nil then
            debug_tools.error("clear_runtime_blocks usage: clear_runtime_blocks, clear_runtime_blocks:MAP_ID, or clear_runtime_blocks:all")
            return
        end
    end
    route_mgr.clear_runtime_blocks(map_id)
    tolk.output_interrupt(string.format("Cleared runtime blocks for map %02X", map_id))
end)

-- Runtime block debug commands are registered via route_manager
route_mgr.register_debug_commands(function() return snapshot.map_id end)

debug_tools.register_command("inspect_tile", function(arg)
    local x, y = parse_xy_arg(arg)
    if not x then
        debug_tools.error("inspect_tile usage: inspect_tile:X,Y")
        return
    end
    objects.update_npcs()
    local map_id = snapshot.map_id
    local msg = log_tile_report(map_id, x, y)
    tolk.output_interrupt(msg)
end)

debug_tools.register_command("inspect_move", function(arg)
    local _, px, py = nav.get_position()
    local from_x, from_y, dir = parse_move_arg(arg, px, py)
    if not from_x then
        debug_tools.error("inspect_move usage: inspect_move:DIR or inspect_move:X,Y,DIR")
        return
    end
    objects.update_npcs()
    local msg = log_move_report(from_x, from_y, dir)
    if msg then
        tolk.output_interrupt(msg)
    end
end)

debug_tools.register_command("probe_edge", function(arg)
    local _, px, py = nav.get_position()
    local from_x, from_y, dir = parse_move_arg(arg, px, py)
    if not from_x then
        debug_tools.error("probe_edge usage: probe_edge:DIR or probe_edge:X,Y,DIR")
        return
    end
    if edge_probe_state then
        debug_tools.error("probe_edge: a probe is already active")
        return
    end
    if from_x ~= px or from_y ~= py then
        debug_tools.error(string.format(
            "probe_edge: stand on (%d,%d) first; current position is (%d,%d)",
            from_x, from_y, px, py))
        return
    end
    if map_survey.is_active() then
        debug_tools.error("probe_edge: stop the active survey first")
        return
    end
    if auto_step.is_route_active() then
        debug_tools.error("probe_edge: wait for the current auto-walk step/route to finish")
        return
    end
    objects.update_npcs()
    local msg, start_report = log_move_report(from_x, from_y, dir)
    local delta = DIR_TO_DELTA[dir]
    edge_probe_state = {
        map_id = snapshot.map_id,
        from_x = from_x,
        from_y = from_y,
        dir = dir,
        dest_x = from_x + delta.dx,
        dest_y = from_y + delta.dy,
        start_report = start_report,
        frames = 0,
    }
    debug_tools.info(string.format(
        "EDGE_PROBE_START map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d)",
        snapshot.map_id,
        from_x,
        from_y,
        dir,
        edge_probe_state.dest_x,
        edge_probe_state.dest_y))
    auto_step.inject_step(dir)
    if msg then
        tolk.output_interrupt("Edge probe started. " .. msg)
    else
        tolk.output_interrupt("Edge probe started")
    end
end)

debug_tools.register_command("probe_edge_verify", function(arg)
    local _, px, py = nav.get_position()
    local from_x, from_y, dir, attempts, explicit_origin = parse_edge_verify_arg(arg, px, py)
    if not from_x then
        debug_tools.error("probe_edge_verify usage: probe_edge_verify:DIR[,ATTEMPTS] or probe_edge_verify:X,Y,DIR[,ATTEMPTS]")
        return
    end
    if edge_verify_state then
        debug_tools.error("probe_edge_verify: verification is already active")
        return
    end
    if edge_probe_state then
        debug_tools.error("probe_edge_verify: wait for the active edge probe to finish")
        return
    end
    if (from_x ~= px or from_y ~= py) and not explicit_origin then
        debug_tools.error(string.format(
            "probe_edge_verify: stand on (%d,%d) first; current position is (%d,%d)",
            from_x, from_y, px, py))
        return
    end
    if map_survey.is_active() then
        debug_tools.error("probe_edge_verify: stop the active survey first")
        return
    end
    if auto_step.is_route_active() then
        debug_tools.error("probe_edge_verify: wait for the current auto-walk step/route to finish")
        return
    end
    local reason = get_autowalk_unavailable_reason()
    if reason then
        debug_tools.error("probe_edge_verify refused: " .. reason)
        return
    end
    local delta = DIR_TO_DELTA[dir]
    edge_verify_state = {
        map_id = snapshot.map_id,
        from_x = from_x,
        from_y = from_y,
        dir = dir,
        dest_x = from_x + delta.dx,
        dest_y = from_y + delta.dy,
        attempts = attempts,
        attempt = 0,
        phase = "arming",
        frames = 0,
        settle_frames = 1,
        results = {
            moved = 0,
            blocked = 0,
            timed_out = 0,
            refused = 0,
            drifted = 0,
            map_changed = 0,
            interrupted = 0,
        },
    }
    debug_tools.info(string.format(
        "EDGE_VERIFY_START map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d) attempts=%d settle_frames=%d between_settle_frames=%d",
        snapshot.map_id,
        from_x,
        from_y,
        dir,
        edge_verify_state.dest_x,
        edge_verify_state.dest_y,
        attempts,
        EDGE_VERIFY_SETTLE_FRAMES,
        EDGE_VERIFY_BETWEEN_SETTLE_FRAMES))
    if explicit_origin and (from_x ~= px or from_y ~= py) then
        debug_tools.info(string.format(
            "EDGE_VERIFY_RELOCATE map=0x%02X current=(%d,%d) origin=(%d,%d)",
            snapshot.map_id,
            px or -1,
            py or -1,
            from_x,
            from_y))
    end
end)

debug_tools.register_command("stop_probe_edge", function()
    if not edge_probe_state then
        debug_tools.error("stop_probe_edge: no active probe")
        return
    end
    auto_step.cancel_active_step(true)
    finish_edge_probe("cancelled", "manual_stop")
end)

debug_tools.register_command("stop_probe_edge_verify", function()
    if not edge_verify_state then
        debug_tools.error("stop_probe_edge_verify: no active verification")
        return
    end
    finish_edge_verify("cancelled", "manual_stop")
end)

debug_tools.register_command("pathfind_to", function(arg)
    local goal_x, goal_y = parse_xy_arg(arg)
    if goal_x == nil then
        debug_tools.error("pathfind_to usage: pathfind_to:X,Y")
        return
    end
    local map_id, px, py = nav.get_position()
    objects.update_npcs()
    local blocking = route_mgr.build_path_blocking(map_id)
    local opts = path_debug.build_find_path_opts()
    local result = pathfinder.pathfind_to(map_id, px, py, goal_x, goal_y, blocking, opts)
    local stats = opts and opts._get_stats() or {}
    local reason = stats and stats.reason
    local msg = string.format("Pathfind to %d,%d. %s%s",
        goal_x, goal_y, result,
        reason and (" [" .. reason .. "]") or "")
    debug_tools.info(msg)
    tolk.output_interrupt(msg)
end)

debug_tools.register_command("pathfind_adjacent", function(arg)
    local goal_x, goal_y = parse_xy_arg(arg)
    if goal_x == nil then
        debug_tools.error("pathfind_adjacent usage: pathfind_adjacent:X,Y")
        return
    end
    local map_id, px, py = nav.get_position()
    objects.update_npcs()
    local blocking = route_mgr.build_path_blocking(map_id)
    local result, face_dir = pathfinder.pathfind_to_adjacent(map_id, px, py, goal_x, goal_y, blocking)
    local msg = string.format("Pathfind adjacent to %d,%d. %s", goal_x, goal_y, result)
    if face_dir then
        msg = msg .. ". Face " .. face_dir
    end
    debug_tools.info(msg)
    tolk.output_interrupt(msg)
end)

debug_tools.register_command("report_path_state", function()
    local map_id = snapshot.map_id
    objects.update_npcs()
    local target = route_mgr.get_last_pathfind_obj()
    if target then
        debug_tools.info(string.format(
            "PATH_STATE target=%s type=%s x=%d y=%d map=0x%02X runtime_count=%d",
            tostring(target.name), tostring(target.type),
            target.x, target.y, map_id, route_mgr.count_runtime_blocks(map_id)))
    else
        debug_tools.info(string.format(
            "PATH_STATE target=nil map=0x%02X runtime_count=%d",
            map_id, route_mgr.count_runtime_blocks(map_id)))
    end
    report_blockers_for_current_map()
    tolk.output_interrupt("Path state reported")
end)

debug_tools.register_command("__config_reloaded", function()
    if tolk.reload_config then
        tolk.reload_config()
    end
    if hotkey_filter.reload_config then
        hotkey_filter.reload_config()
    end
end)

debug_tools.register_command("freeze_npcs", function()
    route_mgr.freeze_npcs()
    debug_tools.info("NPCs frozen")
    tolk.output_interrupt("NPCs frozen")
end)

debug_tools.register_command("unfreeze_npcs", function()
    route_mgr.unfreeze_npcs()
    debug_tools.info("NPCs unfrozen")
    tolk.output_interrupt("NPCs unfrozen")
end)

-- Neighbor search order for teleport_to :near mode. Cardinals first, then
-- diagonals. First walkable cell wins.
local TELEPORT_NEAR_OFFSETS = {
    {dx = 0,  dy = -1, name = "north"},
    {dx = 1,  dy = 0,  name = "east"},
    {dx = 0,  dy = 1,  name = "south"},
    {dx = -1, dy = 0,  name = "west"},
    {dx = 1,  dy = -1, name = "northeast"},
    {dx = 1,  dy = 1,  name = "southeast"},
    {dx = -1, dy = 1,  name = "southwest"},
    {dx = -1, dy = -1, name = "northwest"},
}

-- Parse teleport_to argument: "X,Y" or "X,Y,FLAG" where FLAG is near|force.
local function parse_teleport_arg(arg)
    if not arg then return nil end
    local x_s, y_s, flag = arg:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([%a]+)%s*$")
    if x_s then
        local x = parse_int_arg(x_s)
        local y = parse_int_arg(y_s)
        if x ~= nil and y ~= nil then
            return x, y, flag:lower()
        end
        return nil
    end
    local x, y = parse_xy_arg(arg)
    if x ~= nil then
        return x, y, nil
    end
    return nil
end

-- teleport_to:X,Y[,near|force]
--   (default) exact: refuse if target not walkable
--   near:     fall back to first walkable cardinal/diagonal neighbor
--   force:    skip walkability check entirely (debug/unstick; may strand in wall)
--
-- Keyboard teleport hotkeys also map to NES Start/D-pad in BizHawk. Keep the
-- leaked game input neutral until the non-modifier trigger key is released.
local TELEPORT_MODE_CONFIG_KEYS = {
    exact = "key_teleport_exact",
    north = "key_teleport_north",
    south = "key_teleport_south",
    west = "key_teleport_west",
    east = "key_teleport_east",
}

local function teleport_key_spec_for_mode(mode)
    local key = TELEPORT_MODE_CONFIG_KEYS[mode]
    if not key then
        return nil
    end
    return config.get(key)
end

local function trimmed_combo_part(part)
    return tostring(part or ""):match("^%s*(.-)%s*$")
end

local function is_modifier_combo_part(part)
    local cleaned = trimmed_combo_part(part):lower():gsub("[%s_-]", "")
    return cleaned == "shift"
        or cleaned == "ctrl"
        or cleaned == "control"
        or cleaned == "ctl"
        or cleaned == "alt"
        or cleaned == "option"
end

local function primary_combo_part(spec)
    local fallback = nil
    for part in tostring(spec or ""):gmatch("[^+]+") do
        local trimmed = trimmed_combo_part(part)
        if trimmed ~= "" then
            fallback = fallback or trimmed
            if not is_modifier_combo_part(trimmed) then
                return trimmed
            end
        end
    end
    return fallback
end

local function neutralize_teleport_input(extra)
    local cleaned = {
        up = false,
        down = false,
        left = false,
        right = false,
        start = false,
        select = false,
    }
    if extra then
        for k, v in pairs(extra) do
            cleaned[k] = v
        end
    end
    joypad.set(1, cleaned)
end

DW_QOL_STATE.suppress_teleport_input = function(mode)
    DW_QOL_STATE.pending_teleport_face = nil
    DW_QOL_STATE.teleport_input_suppress_frames = DW_QOL_STATE.TELEPORT_INPUT_SUPPRESS_FRAMES
    local spec = teleport_key_spec_for_mode(mode)
    if spec and spec ~= "" then
        DW_QOL_STATE.teleport_input_suppress_until_release = {
            mode = tostring(mode),
            spec = spec,
            trigger_spec = primary_combo_part(spec) or spec,
            held_frames = 0,
        }
        debug_tools.debug(string.format(
            "TELEPORT_INPUT_SUPPRESS mode=%s spec=%s trigger=%s",
            tostring(mode),
            tostring(spec),
            tostring(DW_QOL_STATE.teleport_input_suppress_until_release.trigger_spec)))
    end
    neutralize_teleport_input()
end

DW_QOL_STATE.teleport_hotkey_still_held = function(keys)
    local hold = DW_QOL_STATE.teleport_input_suppress_until_release
    if not hold then
        return false
    end

    if key_combo.is_down(keys, hold.trigger_spec or hold.spec) then
        hold.held_frames = (hold.held_frames or 0) + 1
        local max_frames = tonumber(DW_QOL_STATE.TELEPORT_INPUT_RELEASE_MAX_FRAMES) or 90
        if max_frames > 0 and hold.held_frames >= max_frames then
            debug_tools.info(string.format(
                "TELEPORT_INPUT_RELEASE_TIMEOUT mode=%s trigger=%s held_frames=%d",
                tostring(hold.mode),
                tostring(hold.trigger_spec or hold.spec),
                hold.held_frames))
            DW_QOL_STATE.teleport_input_suppress_until_release = nil
            return false
        end
        return true
    end

    debug_tools.debug(string.format(
        "TELEPORT_INPUT_RELEASED mode=%s trigger=%s held_frames=%d",
        tostring(hold.mode),
        tostring(hold.trigger_spec or hold.spec),
        tonumber(hold.held_frames) or 0))
    DW_QOL_STATE.teleport_input_suppress_until_release = nil
    return false
end

DW_QOL_STATE.apply_pending_teleport_face = function()
    local face = DW_QOL_STATE.pending_teleport_face
    if not face then
        return false
    end
    DW_QOL_STATE.pending_teleport_face = nil
    if auto_step.suppress_direction_tracking then
        auto_step.suppress_direction_tracking(4)
    end
    neutralize_teleport_input({[face.dir] = true})
    DW_QOL_STATE.teleport_input_suppress_frames = 2
    debug_tools.info(string.format(
        "TELEPORT_FACE target=%s face=%s dir=%s landing=(%s,%s)",
        tostring(face.target_name),
        tostring(face.face_dir),
        tostring(face.dir),
        face.landing_x ~= nil and tostring(face.landing_x) or "?",
        face.landing_y ~= nil and tostring(face.landing_y) or "?"))
    return true
end

DW_QOL_STATE.queue_teleport_face = function(face_dir, target_name, landing)
    local dir = CARDINAL_TO_KEY[face_dir]
    if not dir then
        return false
    end
    DW_QOL_STATE.pending_teleport_face = {
        dir = dir,
        face_dir = face_dir,
        target_name = target_name or "target",
        landing_x = landing and landing.x or nil,
        landing_y = landing and landing.y or nil,
    }
    return true
end

-- Always refuses during menus, dialogue, battle, sweeps, active routes, and
-- edge probes. Writes RAM 0x003A/0x003B for the new position; for the overworld
-- also updates 0x0042/0x003E shadow bytes. Clears any pending auto_step state.
DW_QOL_STATE.perform_teleport_to = function(tx, ty, flag, opts)
    opts = opts or {}
    if tx == nil then
        debug_tools.error("teleport usage: X,Y[,near|force]")
        if opts.speak ~= false then
            tolk.output_interrupt("Teleport: invalid arguments")
        end
        return false, "invalid arguments"
    end
    if flag ~= nil and flag ~= "near" and flag ~= "force" then
        debug_tools.error("teleport_to: unknown flag '" .. flag .. "' (use near or force)")
        if opts.speak ~= false then
            tolk.output_interrupt("Teleport: unknown flag " .. flag)
        end
        return false, "unknown flag"
    end

    local reason = get_autowalk_unavailable_reason()
    if reason then
        debug_tools.error("teleport_to refused: " .. reason)
        if opts.speak ~= false then
            tolk.output_interrupt("Teleport refused. " .. reason)
        end
        return false, reason
    end
    if auto_step.is_route_active() then
        debug_tools.error("teleport_to refused: auto-walk route active")
        if opts.speak ~= false then
            tolk.output_interrupt("Teleport refused. Wait for auto-walk to finish")
        end
        return false, "route active"
    end
    if edge_probe_state ~= nil then
        debug_tools.error("teleport_to refused: edge probe active")
        if opts.speak ~= false then
            tolk.output_interrupt("Teleport refused. Edge probe active")
        end
        return false, "edge probe active"
    end
    if edge_verify_state ~= nil and opts.allow_edge_verify ~= true then
        debug_tools.error("teleport_to refused: edge verification active")
        if opts.speak ~= false then
            tolk.output_interrupt("Teleport refused. Edge verification active")
        end
        return false, "edge verification active"
    end
    if map_survey.is_active() then
        debug_tools.error("teleport_to refused: map survey active")
        if opts.speak ~= false then
            tolk.output_interrupt("Teleport refused. Survey active")
        end
        return false, "survey active"
    end

    local map_id = snapshot.map_id
    local width, height = map_reader.get_map_dimensions(map_id)
    local function in_bounds(x, y)
        if width == nil or height == nil then return true end
        return x >= 0 and y >= 0 and x < width and y < height
    end

    if not in_bounds(tx, ty) then
        debug_tools.error(string.format(
            "teleport_to refused: (%d,%d) out of bounds (map %dx%d)",
            tx, ty, width or -1, height or -1))
        if opts.speak ~= false then
            tolk.output_interrupt("Teleport refused. Target out of bounds")
        end
        return false, "out of bounds"
    end

    local landing_x, landing_y = tx, ty
    local landing_note = nil

    if flag ~= "force" then
        local walkable = map_reader.is_walkable(map_id, tx, ty)
        if walkable ~= true then
            if flag == "near" then
                for _, off in ipairs(TELEPORT_NEAR_OFFSETS) do
                    local nx, ny = tx + off.dx, ty + off.dy
                    if in_bounds(nx, ny) and map_reader.is_walkable(map_id, nx, ny) == true then
                        landing_x, landing_y = nx, ny
                        landing_note = off.name
                        break
                    end
                end
                if landing_note == nil then
                    debug_tools.error(string.format(
                        "teleport_to refused: (%d,%d) not walkable and no walkable neighbor",
                        tx, ty))
                    if opts.speak ~= false then
                        tolk.output_interrupt("Teleport refused. No walkable cell near target")
                    end
                    return false, "no walkable neighbor"
                end
            else
                local tile_type = map_reader.get_tile_type(map_id, tx, ty)
                local tile_str = tile_type and string.format("0x%02X", tile_type) or "?"
                debug_tools.error(string.format(
                    "teleport_to refused: (%d,%d) not walkable (tile=%s); use near or force",
                    tx, ty, tile_str))
                if opts.speak ~= false then
                    if opts.manual then
                        tolk.output_interrupt("Teleport refused. Target cell is not walkable")
                    else
                        tolk.output_interrupt(string.format(
                            "Teleport refused. %d, %d not walkable. Use near or force flag",
                            tx, ty))
                    end
                end
                return false, "not walkable"
            end
        end
    end

    if flag ~= "force" and opts.check_npc ~= false then
        if objects.is_npc_at(map_id, landing_x, landing_y) then
            debug_tools.error(string.format(
                "teleport_to refused: (%d,%d) occupied by NPC",
                landing_x, landing_y))
            if opts.speak ~= false then
                tolk.output_interrupt("Teleport refused. Target cell is occupied by an NPC")
            end
            return false, "npc occupied"
        end
    end

    -- Cancel any in-flight step/repress so the engine doesn't re-inject motion
    -- from the old position after the RAM write.
    auto_step.cancel_active_step(true)

    -- Log the full 0x0030-0x004F range before and after the write so we can
    -- compare movement-state bytes (0x003C, 0x003E, 0x0042 etc.) across probe
    -- sessions. The post-write dump shows exactly which bytes teleport changes.
    if debug_tools.DEBUG_MODE then
        local bytes = {}
        for a = 0x0030, 0x004F do bytes[#bytes+1] = string.format("%02X", memory.readbyte(a)) end
        debug_tools.info(string.format(
            "TELEPORT_PRE to=(%d,%d) map=0x%02X ram0030_004F=%s",
            landing_x, landing_y, map_id, table.concat(bytes, " ")))
    end

    memory.writebyte(addr.PLAYER_X, landing_x)
    memory.writebyte(addr.PLAYER_Y, landing_y)
    if map_id == 0x00 then
        memory.writebyte(addr.OVERWORLD_X, landing_x)
        memory.writebyte(addr.OVERWORLD_Y, landing_y)
    end
    -- Normalize movement-engine state so probes from this position get
    -- reproducible results. Without this, stale 0x003C (e.g. 0x08 "leftward
    -- arrival") causes the engine to turn-in-place on the first press and then
    -- block on retry, making the same open edge appear engine-blocked.
    memory.writebyte(addr.MOVEMENT_STATE,    0x00)
    memory.writebyte(addr.MOVEMENT_SUBPIXEL, 0x00)
    -- Keep later commands in the same command poll from reading the pre-teleport
    -- cached position via navigation/game_snapshot.
    snapshot.update()

    if debug_tools.DEBUG_MODE then
        local bytes = {}
        for a = 0x0030, 0x004F do bytes[#bytes+1] = string.format("%02X", memory.readbyte(a)) end
        debug_tools.info(string.format(
            "TELEPORT_POST to=(%d,%d) map=0x%02X ram0030_004F=%s",
            landing_x, landing_y, map_id, table.concat(bytes, " ")))
    end

    DW_QOL_STATE.suppress_teleport_input()

    local msg
    if landing_note then
        msg = string.format("Teleported to (%d,%d), %s of (%d,%d)",
            landing_x, landing_y, landing_note, tx, ty)
    elseif flag == "force" then
        msg = string.format("Teleported to (%d,%d) (forced)", landing_x, landing_y)
    else
        msg = string.format("Teleported to (%d,%d)", landing_x, landing_y)
    end
    debug_tools.info(msg)
    if opts.speak ~= false then
        tolk.output_interrupt(msg)
    end
    return true, msg
end

debug_tools.register_command("teleport_to", function(arg)
    local tx, ty, flag = parse_teleport_arg(arg)
    DW_QOL_STATE.perform_teleport_to(tx, ty, flag)
end)

DW_QOL_STATE.TELEPORT_SELECTED_OFFSETS = {
    north = {dx = 0, dy = -1, face_dir = "south"},
    south = {dx = 0, dy = 1, face_dir = "north"},
    west = {dx = -1, dy = 0, face_dir = "east"},
    east = {dx = 1, dy = 0, face_dir = "west"},
}

hotkeys.set_teleport_handler(function(mode)
    DW_QOL_STATE.suppress_teleport_input(mode)

    local obj = objects.current_object()
    if not obj then
        tolk.output_interrupt("No object selected")
        return
    end

    local tx, ty = obj.x, obj.y
    local landing = nil
    if mode == "exact" and obj.type == objects.TYPE_NPC and objects.resolve_teleport_landing then
        local map_id = snapshot.map_id
        local err
        landing, err = objects.resolve_teleport_landing(obj, map_id, {check_npc = true})
        if not landing then
            local msg = "Teleport refused. No open cell next to " .. tostring(obj.name or "NPC")
            debug_tools.error(string.format(
                "TELEPORT_SELECTED refused mode=exact target_id=%s target_name=%s target=(%d,%d) reason=%s",
                tostring(obj.id),
                tostring(obj.name),
                obj.x,
                obj.y,
                tostring(err)))
            tolk.output_interrupt(msg)
            return
        end
        tx, ty = landing.x, landing.y
    elseif mode ~= "exact" then
        local off = DW_QOL_STATE.TELEPORT_SELECTED_OFFSETS[mode]
        if not off then
            tolk.output_interrupt("Teleport: unknown direction")
            return
        end
        tx = obj.x + off.dx
        ty = obj.y + off.dy
        if obj.type == objects.TYPE_NPC then
            landing = {
                x = tx,
                y = ty,
                target_x = obj.x,
                target_y = obj.y,
                note = mode,
                face_dir = off.face_dir,
                reason = "manual_adjacent",
            }
        end
    end

    local ok = DW_QOL_STATE.perform_teleport_to(tx, ty, nil, {check_npc = true, manual = true})
    if ok then
        if landing and landing.face_dir then
            DW_QOL_STATE.queue_teleport_face(landing.face_dir, obj.name, {x = tx, y = ty})
        end
        debug_tools.info(string.format(
            "TELEPORT_SELECTED mode=%s target_id=%s target_name=%s target=(%d,%d) landing=(%d,%d)",
            tostring(mode),
            tostring(obj.id),
            tostring(obj.name),
            landing and landing.target_x or obj.x,
            landing and landing.target_y or obj.y,
            tx,
            ty)
            .. (landing and string.format(
                " landing_reason=%s landing_note=%s face_dir=%s",
                tostring(landing.reason),
                tostring(landing.note),
                tostring(landing.face_dir)) or ""))
    end
end)

-- ============================================================
-- Path Debug Commands
-- ============================================================
-- These commands provide detailed pathfinding diagnostics.
-- All output goes to dw_debug.log. Requires debug_mode=true.

debug_tools.register_command("debug_pathfind_to", function(arg)
    local goal_x, goal_y = parse_xy_arg(arg)
    if not goal_x then
        debug_tools.error("debug_pathfind_to usage: debug_pathfind_to:X,Y")
        return
    end
    local map_id, px, py = nav.get_position()
    objects.update_npcs()
    local blocking = route_mgr.build_path_blocking(map_id)
    local opts = path_debug.build_find_path_opts()
    local result, face_dir, path = pathfinder.pathfind_to(
        map_id, px, py, goal_x, goal_y, blocking, opts)
    path_debug.store_path(map_id, px, py, goal_x, goal_y, path, opts)
    local stats = opts and opts._get_stats() or {}
    local reason = stats and stats.reason
    local msg = string.format("Debug pathfind to (%d,%d): %s%s (visited=%d path=%d)",
        goal_x, goal_y, result,
        reason and (" [" .. reason .. "]") or "",
        stats.nodes_visited or 0, path and #path or 0)
    debug_tools.info(msg)
    tolk.output_interrupt(msg)
end)

debug_tools.register_command("debug_pathfind_adjacent", function(arg)
    local goal_x, goal_y = parse_xy_arg(arg)
    if not goal_x then
        debug_tools.error("debug_pathfind_adjacent usage: debug_pathfind_adjacent:X,Y")
        return
    end
    local map_id, px, py = nav.get_position()
    objects.update_npcs()
    local blocking = route_mgr.build_path_blocking(map_id)
    local opts = path_debug.build_find_path_opts()
    local result, face_dir, path = pathfinder.pathfind_to_adjacent(
        map_id, px, py, goal_x, goal_y, blocking, opts)
    path_debug.store_path(map_id, px, py, goal_x, goal_y, path, opts)
    local stats = opts and opts._get_stats() or {}
    local reason = stats and stats.reason
    local msg = string.format("Debug pathfind adjacent to (%d,%d): %s%s (visited=%d path=%d)",
        goal_x, goal_y, result,
        reason and (" [" .. reason .. "]") or "",
        stats.nodes_visited or 0, path and #path or 0)
    if face_dir then msg = msg .. ". Face " .. face_dir end
    debug_tools.info(msg)
    tolk.output_interrupt(msg)
end)

debug_tools.register_command("trace_path", function()
    path_debug.trace_path()
    tolk.output_interrupt("Path trace logged")
end)

debug_tools.register_command("dump_search_log", function()
    path_debug.dump_search_log()
    tolk.output_interrupt("Search log dumped")
end)

debug_tools.register_command("start_step_mode", function()
    path_debug.start_step_mode()
    tolk.output_interrupt("Step mode started")
end)

debug_tools.register_command("stop_step_mode", function()
    path_debug.stop_step_mode()
    tolk.output_interrupt("Step mode stopped")
end)

debug_tools.register_command("step_path", function()
    local stepped = path_debug.step_path(auto_step)
    if not stepped then
        tolk.output_interrupt("No more steps")
    else
        tolk.output_interrupt("Step")
    end
end)

debug_tools.register_command("validate_path", function()
    path_debug.start_validate(auto_step)
    tolk.output_interrupt("Path validation started")
end)

debug_tools.register_command("stop_validate", function()
    path_debug.stop_validate()
    tolk.output_interrupt("Validation stopped")
end)

debug_tools.register_command("test_path", function(arg)
    local map_id = nav.get_position()
    route_mgr.clear_runtime_blocks(map_id)
    -- Keep deterministic fixture tests independent of live NPC movement.
    -- The suite already clears runtime blocks above, so use an empty snapshot.
    local blocking_snapshot = {}
    path_debug.run_test(arg, auto_step, function()
        return blocking_snapshot
    end)
    tolk.output_interrupt("Test scenarios logged")
end)

debug_tools.register_command("list_tests", function()
    path_debug.list_tests()
    tolk.output_interrupt("Test list logged")
end)

debug_tools.register_command("dump_path_grid", function()
    path_debug.dump_path_grid()
    tolk.output_interrupt("Path grid dumped")
end)

debug_tools.register_command("survey_map", function(arg)
    local ok, err = map_survey.start_object_survey(arg)
    if not ok then
        debug_tools.error("survey_map: " .. tostring(err))
        tolk.output_interrupt(tostring(err))
    end
end)

debug_tools.register_command("report_survey_start", function(arg)
    local ok, info = map_survey.report_start_viability(arg)
    if not ok then
        debug_tools.error("report_survey_start: " .. tostring(info))
        tolk.output_interrupt(tostring(info))
        return
    end

    local status = info.isolated_start and "isolated" or "viable"
    tolk.output_interrupt(string.format(
        "Survey start %s on map %02X at (%d,%d). Reachable area %d with %d open exits for %d targets.",
        status,
        info.map_id,
        info.start_x,
        info.start_y,
        info.reachable_area,
        info.open_exit_count,
        info.target_count))
end)

debug_tools.register_command("survey_objects", function(arg)
    local ok, err = map_survey.start_object_survey(arg)
    if not ok then
        debug_tools.error("survey_objects: " .. tostring(err))
        tolk.output_interrupt(tostring(err))
    end
end)

debug_tools.register_command("survey_target", function(arg)
    local ok, err = map_survey.start_target_survey(arg)
    if not ok then
        debug_tools.error("survey_target: " .. tostring(err))
        tolk.output_interrupt(tostring(err))
    end
end)

debug_tools.register_command("stop_survey", function()
    local ok, msg = map_survey.stop_survey()
    if not ok then
        debug_tools.error("stop_survey: " .. tostring(msg))
        tolk.output_interrupt(tostring(msg))
        return
    end
    tolk.output_interrupt(msg)
end)

debug_tools.register_command("report_failed_targets", function(arg)
    local map_id = parse_int_arg(arg) or snapshot.map_id
    local count = map_survey.report_failed_targets(map_id)
    if count == 0 then
        tolk.output_interrupt(string.format("No failed survey targets on map %02X", map_id))
    else
        tolk.output_interrupt(string.format("Reported %d failed survey targets on map %02X", count, map_id))
    end
end)

debug_tools.register_command("report_strong_candidates", function(arg)
    local map_id = parse_int_arg(arg) or snapshot.map_id
    local count = map_survey.report_strong_candidates(map_id)
    if count == 0 then
        tolk.output_interrupt(string.format("No strong reroute candidates on map %02X", map_id))
    else
        tolk.output_interrupt(string.format("Reported %d strong reroute candidates on map %02X", count, map_id))
    end
end)

debug_tools.register_command("report_survey_findings", function(arg)
    local map_id = parse_int_arg(arg) or snapshot.map_id
    local findings = map_survey.report_findings(map_id)
    if not findings or ((findings.failed_targets or 0) == 0 and (findings.strong_candidates or 0) == 0) then
        tolk.output_interrupt(string.format("No survey findings for map %02X", map_id))
    else
        tolk.output_interrupt(string.format(
            "Survey findings for map %02X. %d failed targets, %d strong reroute candidates.",
            map_id,
            findings.failed_targets or 0,
            findings.strong_candidates or 0))
    end
end)

debug_tools.register_command("report_candidate_suggestions", function(arg)
    local map_id = parse_int_arg(arg) or snapshot.map_id
    local count = map_survey.report_candidate_suggestions(map_id)
    if count == 0 then
        tolk.output_interrupt(string.format("No candidate suggestions for map %02X", map_id))
    else
        tolk.output_interrupt(string.format("Reported %d candidate suggestions for map %02X", count, map_id))
    end
end)

debug_tools.register_command("list_blocked_candidates", function(arg)
    local map_id = parse_int_arg(arg) or snapshot.map_id
    local count = map_survey.list_blocked_candidates(map_id)
    if count == 0 then
        tolk.output_interrupt(string.format("No blocked candidates on map %02X", map_id))
    else
        tolk.output_interrupt(string.format("Listed %d blocked candidates on map %02X", count, map_id))
    end
end)

debug_tools.register_command("dump_survey_report", function(arg)
    local map_id = parse_int_arg(arg) or snapshot.map_id
    local count = map_survey.dump_survey_report(map_id)
    if count == 0 then
        tolk.output_interrupt(string.format("No survey report for map %02X", map_id))
    else
        tolk.output_interrupt(string.format("Dumped survey report with %d targets for map %02X", count, map_id))
    end
end)

debug_tools.register_command("export_blocked_candidates", function(arg)
    local map_id = parse_int_arg(arg) or snapshot.map_id
    local count = map_survey.export_blocked_candidates(map_id)
    if count == 0 then
        tolk.output_interrupt(string.format("No blocked candidates to export for map %02X", map_id))
    else
        tolk.output_interrupt(string.format("Exported %d blocked candidates for map %02X", count, map_id))
    end
end)

debug_tools.register_command("export_directional_candidates", function(arg)
    local map_id = parse_int_arg(arg) or snapshot.map_id
    local count = map_survey.export_directional_candidates(map_id)
    if count == 0 then
        tolk.output_interrupt(string.format("No directional candidate exports for map %02X", map_id))
    else
        tolk.output_interrupt(string.format("Exported %d directional candidate entries for map %02X", count, map_id))
    end
end)

debug_tools.register_command("reset_survey_candidates", function(arg)
    local map_id = parse_int_arg(arg) or snapshot.map_id
    map_survey.reset_candidates(map_id)
    tolk.output_interrupt(string.format("Cleared survey candidates for map %02X", map_id))
end)

-- ============================================================
-- Main Loop
-- ============================================================
-- This is the core of the FCEUX Lua script. It runs forever,
-- advancing the emulator one frame at a time. Between frames,
-- we read game state, detect changes, and speak updates.
--
-- The loop MUST call FCEU.frameadvance() exactly once per
-- iteration — without it, the emulator freezes.

local function log_script_error(err)
    local message = debug.traceback(tostring(err), 2)
    local error_path = main_script_dir .. "dw_script_error.log"
    local f = io.open(error_path, "a")
    if f then
        f:write(os.date("!%Y-%m-%dT%H:%M:%SZ"), "\n")
        f:write(message, "\n\n")
        f:close()
    end

    pcall(function()
        debug_tools.error("UNHANDLED_SCRIPT_ERROR " .. tostring(err))
    end)
    pcall(function()
        tolk.output_interrupt("Script error. See dw_script_error.log.")
    end)
    return message
end

local table_unpack = unpack or table.unpack

local function checked_call(label, fn, ...)
    local args = {...}
    local function invoke()
        return fn(table_unpack(args))
    end
    local ok, result = xpcall(invoke, function(err)
        return log_script_error(label .. ": " .. tostring(err))
    end)
    if not ok then
        error(result)
    end
    return result
end

local function checked_scan(label, fn, ...)
    return scan_profiler.call(label, checked_call, label, fn, ...)
end

while true do
    trace_startup_loop("loop_top")
    row1_trace_frame = frame_count

    -- Read all tracked RAM values into the snapshot table.
    -- This MUST happen before any module reads from the snapshot this frame.
    checked_scan("snapshot.update", snapshot.update)

    -- Get current game state before handling hotkeys so context-sensitive
    -- actions can suppress field-only handlers during battle.
    game_state = checked_scan("state.check_for_changes", state.check_for_changes)
    in_gameplay = (game_state.state ~= state.STATE_TITLE)

    -- Read keyboard state for hotkeys
    local keys = checked_scan("input.get", input.get)
    if emulator_compat.is_bizhawk then
        keys = hotkey_filter.filter_bizhawk_keys(keys, config)
    end
    current_joy = checked_scan("joypad.read", joypad.read, 1)
    current_joy_any = joypad_has_input(current_joy)
    -- No explicit PPU flush needed: frameadvance() already cleared the cache
    -- at the start of this tick (PPU_CACHE_HOLD_FRAMES=1).

    -- Process on-demand hotkeys (player-initiated).
    -- hotkeys.update() also saves prev_keys internally for key-down detection.
    -- Do not include current live joypad input in this allowance: BizHawk maps
    -- Enter/arrow teleport hotkeys to Start/D-pad too, so that would make
    -- teleport hotkeys refuse themselves before hotkeys.lua can neutralize the
    -- leaked game input.
    local object_hotkey_block_reason = checked_call("object_hotkey_allowance", function()
        if game_state.state ~= state.STATE_FIELD then
            return "Object controls unavailable right now"
        end
        if debug_tools.is_sweep_active() then
            return "Object controls unavailable during map sweep"
        end
        if path_debug.is_step_mode() then
            return "Finish step mode before using object controls"
        end
        if DW_QOL_STATE.command_menu_blocks_field_movement
           and DW_QOL_STATE.command_menu_blocks_field_movement() then
            return "Close the command menu first"
        end
        if submenu_mode ~= nil then
            return "Close the submenu first"
        end
        if MER.active then
            return "Close the merchant interface first"
        end
        if PREV.dialogue ~= "" or PREV.announced_dialogue ~= "" then
            return "Wait for dialogue to finish"
        end
        if PREV.upper_active then
            return "Wait for the upper window to clear"
        end
        if auto_step.is_route_active and auto_step.is_route_active() then
            return "Wait for movement to finish"
        end
        return nil
    end)
    checked_scan(
        "hotkeys.update",
        hotkeys.update,
        keys,
        game_state,
        object_hotkey_block_reason == nil,
        object_hotkey_block_reason)

    -- Startup grace period: during the first K.STARTUP_FRAMES frames,
    -- let all the "previous" tracking values initialize silently.
    -- We still run the detection functions (so prev_ values get set),
    -- but we suppress their announcements by skipping the output block.
    if startup_counter < K.STARTUP_FRAMES then
        startup_counter = startup_counter + 1

        -- Silently initialize previous-frame values so they don't
        -- trigger false change detections after the grace period ends.
        PREV.hp = snapshot.hp
        PREV.mp = snapshot.mp
        PREV.level = snapshot.level
        PREV.gold       = snapshot.gold
        PREV.magic_keys = snapshot.keys
        PREV.herbs      = snapshot.herbs
        PREV.items = {
            snapshot.items[1],
            snapshot.items[2],
            snapshot.items[3],
            snapshot.items[4],
        }
        nav.check_for_changes()   -- Initialize map/position tracking
        menu.check_for_changes()  -- Initialize menu cursor tracking
        if game_state.state == state.STATE_FIELD then
            checked_call("objects.observe_npcs", objects.observe_npcs, snapshot.map_id)
        end
        if game_state.state ~= state.STATE_TITLE then
            checked_call("objects.check_refresh", objects.check_refresh, snapshot.map_id)
        end

        -- On the very last frame of the grace period, announce current
        -- state so the player knows where they are. Without this, the
        -- title screen transition would be missed since it happened
        -- during the grace period.
        if startup_counter == K.STARTUP_FRAMES then
            -- Initialize the upper dialogue baseline so the status display
            -- text doesn't get announced as "new dialogue" after the grace period.
            PREV.upper_baseline = text.read_upper_window(get_scroll_tiles(), DW_QOL_STATE.get_scroll_base_nametable())
            PREV.upper_dialogue = PREV.upper_baseline
            reset_merchant_state(false)
            reset_battle_menu_state()
            battle_spell_recovery_available = (game_state.state == state.STATE_BATTLE)

            if game_state.state == state.STATE_TITLE then
                PREV.title_cursor_row       = nil
                PREV.title_cursor_col       = nil
                PREV.is_name_entry          = false
                TITLE.name_entry_active           = false
                NAME_ENTRY_SYMBOLS._visible       = false
                NAME_ENTRY_SYMBOLS.reset_guard()
                PREV.name_d8                = nil
                PREV.name_d9                = nil
                TITLE.stable                = 0
                TITLE.cursor_held_row             = nil
                TITLE.cursor_held_col             = nil
                TITLE.cursor_hold_timer           = 0
                TITLE.challenger_row              = nil
                TITLE.challenger_col              = nil
                TITLE.challenger_frames           = 0
                PREV.title_no_cursor_text   = ""
                TITLE.no_cursor_stable      = 0
                TITLE.save_slot_open          = false
                PREV.save_slot_d9           = nil
                TITLE.msg_speed_open          = false
                PREV.msg_speed_d9           = nil
                field_from_title_ct         = 0
                reset_merchant_state(false)
                reset_battle_menu_state()
                tolk.output("Title screen.")
            end
        end
    else
        -- Normal operation: announce state transitions and changes

        -- Announce state transitions
        if game_state.changed then
            if game_state.state == state.STATE_TITLE then
                PREV.title_cursor_row       = nil
                PREV.title_cursor_col       = nil
                PREV.is_name_entry          = false
                TITLE.name_entry_active           = false
                NAME_ENTRY_SYMBOLS._visible       = false
                NAME_ENTRY_SYMBOLS.reset_guard()
                PREV.name_d8                = nil
                PREV.name_d9                = nil
                TITLE.stable                = 0
                TITLE.cursor_held_row             = nil
                TITLE.cursor_held_col             = nil
                TITLE.cursor_hold_timer           = 0
                TITLE.challenger_row              = nil
                TITLE.challenger_col              = nil
                TITLE.challenger_frames           = 0
                PREV.title_no_cursor_text   = ""
                TITLE.no_cursor_stable      = 0
                TITLE.save_slot_open          = false
                PREV.save_slot_d9           = nil
                TITLE.msg_speed_open          = false
                PREV.msg_speed_d9           = nil
                field_from_title_ct         = 0
                reset_merchant_state(false)
                reset_battle_menu_state()
                tolk.output("Title screen.")
            elseif game_state.state == state.STATE_BATTLE then
                PREV.is_name_entry = false
                TITLE.name_entry_active = false
                NAME_ENTRY_SYMBOLS._visible = false
                NAME_ENTRY_SYMBOLS.reset_guard()
                PREV.name_d8 = nil
                PREV.name_d9 = nil
                reset_merchant_state(false)
                reset_battle_menu_state()
                PREV.dialogue = ""
                PREV.announced_dialogue = ""
                PREV.stable_count = 0
                PREV.clean_y1 = ""
                PREV.clean_stable_count = 0
                PREV.battle_opening_dialogue_pending = true
                tolk.output_interrupt("Battle!")
                debug_tools.on_battle_start()
                event_bus.publish("battle_started")
            elseif game_state.state == state.STATE_FIELD then
                PREV.is_name_entry = false
                TITLE.name_entry_active = false
                NAME_ENTRY_SYMBOLS._visible = false
                NAME_ENTRY_SYMBOLS.reset_guard()
                PREV.name_d8 = nil
                PREV.name_d9 = nil
                reset_battle_menu_state()
                -- Transitioning from title to field: start or continue debounce.
                if game_state.prev_state == state.STATE_TITLE then
                    field_from_title_ct = 1
                end
            end
        end

        -- Debounce: count consecutive FIELD frames that follow a TITLE state.
        -- Only announce "Game started." once the count reaches the threshold.
        -- If the state dips back to TITLE (sub-menu backing out), reset the counter.
        if field_from_title_ct > 0 then
            if game_state.state == state.STATE_FIELD then
                field_from_title_ct = field_from_title_ct + 1
                if field_from_title_ct == K.FIELD_DEBOUNCE then
                    tolk.output("Game started.")
                    post_start_grace = K.FIELD_GRACE
                    field_from_title_ct = 0
                    if scan_profiler.is_enabled() then
                        CMD.bizhawk_boot_dialogue = K.BIZHAWK_BOOT_DIALOGUE_HOLD
                    end
                end
            else
                -- State left FIELD (back to TITLE or into BATTLE) — false alarm.
                field_from_title_ct = 0
            end
        end

        -- Treat the title-to-field debounce as not-yet-gameplay. This keeps
        -- title-menu fades and erase-confirmation transitions from running
        -- gameplay dialogue/map/auto-step logic while state RAM is unstable.
        in_gameplay = (game_state.state ~= state.STATE_TITLE and field_from_title_ct == 0)

        -- Run Yes/No detection first so the rest of the frame sees current
        -- prompt state. Guard 1 reuses the command-menu window and cursor RAM,
        -- so stale prompt state here can leak into false STATUS handling.
        local dialogue_hint = bizhawk_dialogue_hint()
        local yesno_interval = menu.is_yesno_active() and 2 or (dialogue_hint and 24 or 4)
        local run_yesno, yesno_delta = scan_profiler.should_run("yesno_prompt", yesno_interval, frame_count)
        if run_yesno then
            checked_scan("check_yesno_prompt", check_yesno_prompt, yesno_delta)
        end

        if game_state.state == state.STATE_FIELD then
            if CMD.bizhawk_boot_dialogue > 0 then
                CMD.bizhawk_boot_dialogue = CMD.bizhawk_boot_dialogue - 1
            end
            if current_joy_any or DW_QOL_STATE.command_menu_blocks_field_movement() or submenu_mode ~= nil or menu.is_yesno_active() then
                CMD.recent_field_action = K.RECENT_FIELD_ACTION_HOLD
            elseif CMD.recent_field_action > 0 then
                CMD.recent_field_action = CMD.recent_field_action - 1
            end
        else
            CMD.bizhawk_boot_dialogue = 0
            CMD.recent_field_action = 0
        end

        if game_state.state == state.STATE_BATTLE then
            battle_dialogue_grace_frames = K.BATTLE_DIALOGUE_GRACE
        elseif battle_dialogue_grace_frames > 0 then
            battle_dialogue_grace_frames = battle_dialogue_grace_frames - 1
        end

        -- Run automatic checks based on current state.
        -- Skip gameplay checks while on the title screen — the stat
        -- addresses contain garbage/uninitialized data there.
        if game_state.state ~= state.STATE_TITLE then
            if post_start_grace > 0 or field_from_title_ct > 0 then
                -- Silently re-initialize change-detection baselines during
                -- post-start grace OR title-to-field debounce so transient
                -- load-sequence RAM values don't fire false HP/map announcements.
                -- The debounce period (field_from_title_ct > 0) covers the first
                -- ~30 frames before grace officially starts; without this, HP
                -- changes during loading trigger false "Gained X HP" announcements.
                PREV.hp         = snapshot.hp
                PREV.mp         = snapshot.mp
                PREV.level      = snapshot.level
                PREV.gold       = snapshot.gold
                PREV.magic_keys = snapshot.keys
                PREV.herbs      = snapshot.herbs
                PREV.items = {
                    snapshot.items[1],
                    snapshot.items[2],
                    snapshot.items[3],
                    snapshot.items[4],
                }
                if post_start_grace > 0 then
                    post_start_grace = post_start_grace - 1
                    checked_call("nav.check_for_changes", nav.check_for_changes)  -- Initialize map tracking silently
                    if post_start_grace == 0 then
                        -- Grace period just ended. Announce the now-stable
                        -- starting location so the player knows where they are.
                        local map_name = nav.get_map_name()
                        if map_name then tolk.output(map_name) end
                        -- Skip one HP/MP check so the first real frame doesn't
                        -- compare a potentially stale last-grace-frame value
                        -- against a just-updated current value.
                        skip_first_hp_check = true
                    end
                end
            else
                checked_call("check_map_change", check_map_change)
                if skip_first_hp_check then
                    -- Re-initialize baselines instead of checking for changes.
                    PREV.hp    = snapshot.hp
                    PREV.mp    = snapshot.mp
                    PREV.level = snapshot.level
                    skip_first_hp_check = false
                else
                    checked_call("check_hp_mp_changes", check_hp_mp_changes)
                    checked_call("check_level_up", check_level_up)
                end
            end
            if game_state.state == state.STATE_BATTLE then
                local run_battle_menu = true
                local battle_menu_delta = 1
                if scan_profiler.is_enabled() then
                    run_battle_menu, battle_menu_delta = scan_profiler.should_run("battle_menu", 3, frame_count)
                end
                if run_battle_menu then
                    checked_scan("check_battle_menu", check_battle_menu, battle_menu_delta)
                end
            else
                local menu_attention = menu.is_open()
                    or DW_QOL_STATE.command_menu_blocks_field_movement()
                    or submenu_mode ~= nil
                    or CMD.menu_confirmed
                    or menu.is_yesno_active()
                    or current_joy_any
                    or CMD.recent_field_action > 0
                local menu_interval = menu_attention and 2 or 4
                local run_menu, menu_delta = false, 0
                if not dialogue_hint or menu_attention then
                    run_menu, menu_delta = scan_profiler.should_run("command_menu", menu_interval, frame_count)
                end
                if run_menu then
                    checked_scan("check_command_menu", check_command_menu, menu_delta)
                end
            end

            -- Keep the object list fresh: detect map changes and
            -- periodically re-read NPC positions (they move around).
            local map_id = snapshot.map_id
            local run_object_refresh = true
            local object_refresh_needed = objects.needs_refresh
                and checked_call("objects.needs_refresh", objects.needs_refresh, map_id)
            if scan_profiler.is_enabled() then
                if object_refresh_needed then
                    run_object_refresh = true
                elseif dialogue_hint then
                    run_object_refresh = false
                else
                    run_object_refresh = scan_profiler.should_run("objects.check_refresh", 120, frame_count)
                end
            end
            if run_object_refresh then
                checked_scan("objects.check_refresh", objects.check_refresh, map_id)
            end

            -- Detect chest collection (only meaningful during field movement,
            -- but safe to run any time we're not on the title screen).
            if game_state.state == state.STATE_FIELD then
                checked_call("check_chest_collection", check_chest_collection)
            end
        end

        -- Dialogue checks — run every frame to track text changes.
        -- Both lower (rows 19-29) and upper (rows 1-18) dialogue are only
        -- meaningful during gameplay. On the title screen, graphic tiles in
        -- those rows decode as spurious digits/uppercase and produce false
        -- announcements. check_title_screen() handles all title-screen text.
        if in_gameplay then
            local merchant_active = MER.active
            local merchant_interval = MER.active and 3 or (dialogue_hint and 12 or 8)
            local run_merchant = false
            local merchant_delta = 0
            -- The shop item list always includes lower prompt text ("What dost
            -- thou wish to buy?"), so dialogue_hint stays true while the
            -- merchant cursor is active. Do not let the dialogue throttle starve
            -- merchant scanning, or the command-menu fallback can regain control
            -- after buy/error/continue cycles.
            run_merchant, merchant_delta = scan_profiler.should_run("merchant_screen", merchant_interval, frame_count)
            if run_merchant then
                merchant_active = checked_scan("check_merchant_screen", check_merchant_screen, merchant_delta)
            end
            if not merchant_active then
                local lower_interval = (game_state.state == state.STATE_BATTLE or battle_dialogue_grace_frames > 0) and 3
                    or (dialogue_hint and 12 or 6)
                local run_lower, lower_delta = scan_profiler.should_run("lower_dialogue", lower_interval, frame_count)
                if run_lower then
                    checked_scan("check_dialogue", check_dialogue, lower_delta, dialogue_hint)
                end

                local upper_interval = PREV.upper_active and 8 or (dialogue_hint and 30 or 10)
                local run_upper, upper_delta = scan_profiler.should_run("upper_dialogue", upper_interval, frame_count)
                if run_upper then
                    checked_scan("check_upper_dialogue", check_upper_dialogue, upper_delta, dialogue_hint)
                end
            end
        else
            reset_merchant_state(false)
            checked_scan("check_title_screen", check_title_screen)
        end
    end

    -- Increment frame counter monotonically so debug log frame prefixes stay
    -- ordered across long sessions. Lua numbers can represent this safely.
    frame_count = frame_count + 1

    -- Debug tools: process command file, flush logs, apply simulated input.
    -- All of this is a no-op when debug_mode=false in dw_access.ini.
    local sim_input = checked_scan("debug_tools.tick", debug_tools.tick, frame_count, game_state.state)
    checked_scan("path_debug.tick", path_debug.tick)  -- Drive validation state machine (no-op when debug_mode=false)
    local raw_debug_input_this_frame = sim_input and sim_input._raw
    if sim_input then
        if emulator_compat.clear_ppu_cache then
            emulator_compat.clear_ppu_cache()
        end
        -- sweep_map returns input tagged with _sweep=true. report/debug probes
        -- can also request a one-frame raw injection via _raw=true.
        -- These should go directly to joypad.set() — NOT through
        -- auto_step.inject_step(), which would start a competing auto-hold.
        --
        -- Normal simulate_input directions DO go through inject_step so the
        -- full tap-to-step hold sequence fires (auto_step reads joypad.read(),
        -- not joypad.set() output, so a bare joypad.set() of a direction would
        -- only turn the character without moving).
        if sim_input._sweep or sim_input._raw then
            joypad.set(1, sim_input)
        else
            local dir_sim = sim_input.up or sim_input.down or sim_input.left or sim_input.right
            if dir_sim then
                local dir = sim_input.up and "up"
                         or sim_input.down and "down"
                         or sim_input.left and "left"
                         or sim_input.right and "right"
                auto_step.inject_step(dir)
            else
                joypad.set(1, sim_input)
            end
        end
    end

    NAME_ENTRY_SYMBOLS.apply_guard()

    local teleport_input_suppressed_this_frame = false
    local teleport_face_input_this_frame = false
    local teleport_hotkey_held = checked_call(
        "teleport_hotkey_release",
        DW_QOL_STATE.teleport_hotkey_still_held,
        keys) == true
    if DW_QOL_STATE.teleport_input_suppress_frames > 0 or teleport_hotkey_held then
        neutralize_teleport_input()
        if DW_QOL_STATE.teleport_input_suppress_frames > 0 then
            DW_QOL_STATE.teleport_input_suppress_frames = DW_QOL_STATE.teleport_input_suppress_frames - 1
        end
        teleport_input_suppressed_this_frame = true
    else
        teleport_face_input_this_frame = checked_call(
            "teleport_face",
            DW_QOL_STATE.apply_pending_teleport_face) == true
    end

    -- Auto-step: extend brief D-pad taps into full tile steps.
    -- Only active when the player is walking on the field (not in
    -- menus, dialogue, battle, or on the title screen).
    local can_walk = game_state.state == state.STATE_FIELD
                     and field_from_title_ct == 0
                     and post_start_grace == 0
                     and not debug_tools.is_sweep_active()  -- suspend during map sweep
                     and not path_debug.is_step_mode()      -- suspend during step-by-step mode
                     and (
                         path_debug.is_validating()
                         or (
                             not DW_QOL_STATE.command_menu_blocks_field_movement()
                             and submenu_mode == nil
                             and not MER.active
                             and PREV.dialogue == ""
                             and not PREV.upper_active
                         )
                     )
    if debug_tools.DEBUG_MODE and not can_walk then
        local active_target = route_mgr.get_last_pathfind_obj and route_mgr.get_last_pathfind_obj()
        if active_target or (path_debug.is_validating and path_debug.is_validating()) then
            local can_walk_log = rawget(_G, "DW_CAN_WALK_LOG") or {}
            local block_key = table.concat({
                tostring(game_state.state),
                tostring(debug_tools.is_sweep_active()),
                tostring(path_debug.is_step_mode()),
                tostring(path_debug.is_validating()),
                tostring(menu.is_open()),
                tostring(DW_QOL_STATE.command_menu_blocks_field_movement()),
                tostring(submenu_mode),
                tostring(#(PREV.dialogue or "")),
                tostring(PREV.upper_active),
                active_target and tostring(active_target.name) or "nil",
            }, "|")
            if can_walk_log.key ~= block_key or (frame_count - (can_walk_log.frame or -9999)) >= 60 then
                debug_tools.debug(string.format(
                    "CAN_WALK false: state=%s sweep=%s step_mode=%s validating=%s menu_raw=%s menu_active=%s submenu=%s PREV.dialogue_len=%d PREV.upper_active=%s target=%s",
                    tostring(game_state.state),
                    tostring(debug_tools.is_sweep_active()),
                    tostring(path_debug.is_step_mode()),
                    tostring(path_debug.is_validating()),
                    tostring(menu.is_open()),
                    tostring(DW_QOL_STATE.command_menu_blocks_field_movement()),
                    tostring(submenu_mode),
                    #(PREV.dialogue or ""),
                    tostring(PREV.upper_active),
                    active_target and tostring(active_target.name) or "nil"))
                can_walk_log.key = block_key
                can_walk_log.frame = frame_count
                _G.DW_CAN_WALK_LOG = can_walk_log
            end
        end
    end
    checked_call("tick_edge_probe", tick_edge_probe)
    checked_call("tick_edge_verify", tick_edge_verify)
    checked_scan("map_survey.tick", map_survey.tick, can_walk)
    -- Raw debug input is meant to exercise the game engine directly. Do not let
    -- auto_step observe the simulated press/release edge, or it can synthesize
    -- a blocked auto-step after the raw hold and pollute probe/survey evidence.
    if not raw_debug_input_this_frame
       and not teleport_input_suppressed_this_frame
       and not teleport_face_input_this_frame then
        checked_scan("auto_step.update", auto_step.update, can_walk)
    end

    -- Advance the emulator by one frame. This is required —
    -- without it, the emulator hangs.
    trace_startup_loop("before_frameadvance")
    FCEU.frameadvance()
    trace_startup_loop("after_frameadvance")

    -- If NPC freeze is active, restore NPC position bytes to their snapshot.
    -- The NES game's NPC movement routines ran during frameadvance and may
    -- have written new positions; we undo that here so our code sees stable
    -- NPC coordinates on the next frame.
    route_mgr.apply_npc_freeze()
    map_survey.apply_npc_parking()
end
