-- map_crawler.lua
-- Review-only live frontier crawler for map decoding.
--
-- This probes outward from the player's current tile, records what the engine
-- actually accepts, and exports candidate Lua snippets for human review. It
-- intentionally does not write map_reader.lua, runtime blockers, or dw_blocks.log.

local addr        = require "addresses"
local auto_step   = require "auto_step"
local debug_tools = require "debug_tools"
local event_bus   = require "event_bus"
local map_reader  = require "map_reader"
local maps        = require "maps"
local nav         = require "navigation"
local route_mgr   = require "route_manager"
local tolk        = require "tolk"

local M = {}

local LOW_HP_ABORT_THRESHOLD = 8
local PARKED_NPC_COORD = 31
local DEFAULT_ATTEMPTS = 3
local DEFAULT_MAX_EDGES = 200
local MAX_ATTEMPTS = 15
local MAX_EDGES = 2000
local MANUAL_STOP_SETTLE_FRAMES = 30
local STEP_SETTLE_FRAMES = 16

local DIRECTIONS = {
    {key = "up",    name = "north", dx = 0,  dy = -1, approach = "south", reverse = "down"},
    {key = "down",  name = "south", dx = 0,  dy = 1,  approach = "north", reverse = "up"},
    {key = "left",  name = "west",  dx = -1, dy = 0,  approach = "east",  reverse = "right"},
    {key = "right", name = "east",  dx = 1,  dy = 0,  approach = "west",  reverse = "left"},
}

local DIR_BY_KEY = {}
for _, dir in ipairs(DIRECTIONS) do
    DIR_BY_KEY[dir.key] = dir
end

-- Derive the script directory from this file's source path so the export
-- file lands next to the rest of the project's runtime files (dw_debug.log,
-- dw_commands.txt, ...). Matches the convention used in debug_tools.lua.
local _src       = debug.getinfo(1, "S").source
local script_dir = _src:match("@?(.*[\\/])") or ""

local crawler_state = nil
local reports_by_map = {}
local run_counter = 0
local last_report_map_id = nil

-- Forward declarations: finish_run calls these, but their bodies depend on
-- helpers and module functions defined further down (format_direction_table,
-- M.get_passthrough_candidates, M.get_directional_candidates).
local write_export_file
local speak_finish_summary
local write_sweep_status_file
local write_sweep_output_files

local function bit_and(a, b)
    if type(AND) == "function" then
        return AND(a, b)
    end
    local result = 0
    local bit = 1
    a = tonumber(a) or 0
    b = tonumber(b) or 0
    while a > 0 and b > 0 do
        if (a % 2 == 1) and (b % 2 == 1) then
            result = result + bit
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bit = bit * 2
    end
    return result
end

local function trim(value)
    if value == nil then return nil end
    return tostring(value):match("^%s*(.-)%s*$")
end

local function parse_bool(value)
    value = trim(value)
    if not value then return nil end
    value = value:lower()
    if value == "true" or value == "1" or value == "yes" or value == "on" then
        return true
    end
    if value == "false" or value == "0" or value == "no" or value == "off" then
        return false
    end
    return nil
end

local function parse_options(arg)
    local opts = {
        attempts = DEFAULT_ATTEMPTS,
        max_edges = DEFAULT_MAX_EDGES,
        park_mobile_npcs = true,
    }
    if not arg or trim(arg) == "" then
        return opts
    end
    for token in tostring(arg):gmatch("[^,]+") do
        local key, value = token:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if not key then
            return nil, "Unknown crawl option: " .. tostring(trim(token))
        end
        key = key:lower()
        if key == "attempts" then
            local n = tonumber(value)
            if not n then return nil, "attempts must be a number" end
            opts.attempts = math.max(1, math.min(MAX_ATTEMPTS, math.floor(n)))
        elseif key == "max_edges" then
            local n = tonumber(value)
            if not n then return nil, "max_edges must be a number" end
            opts.max_edges = math.max(1, math.min(MAX_EDGES, math.floor(n)))
        elseif key == "park_mobile_npcs" then
            local b = parse_bool(value)
            if b == nil then return nil, "park_mobile_npcs must be true or false" end
            opts.park_mobile_npcs = b
        else
            return nil, "Unknown crawl option: " .. tostring(key)
        end
    end
    return opts
end

local function cell_key(x, y)
    return tostring(x) .. "," .. tostring(y)
end

local function edge_key(from_x, from_y, dir)
    return string.format("%d,%d:%s", from_x, from_y, tostring(dir))
end

local function count_table_entries(tbl)
    local n = 0
    for _ in pairs(tbl or {}) do
        n = n + 1
    end
    return n
end

local function is_active_npc_slot(byte0, byte1)
    local x = bit_and(byte0, 0x1F)
    local y = bit_and(byte1, 0x1F)
    return not ((x == 0 and y == 0) or (x == PARKED_NPC_COORD and y == PARKED_NPC_COORD))
end

local function write_npc_bytes(slot, byte0, byte1, byte2)
    local base = addr.NPC_DATA_START + (slot * addr.NPC_ENTRY_SIZE)
    memory.writebyte(base, byte0)
    memory.writebyte(base + 1, byte1)
    memory.writebyte(base + 2, byte2)
end

local function capture_mobile_npc_parking_state(map_id)
    local state = {
        map_id = map_id,
        slots = {},
    }
    for slot = 0, addr.NPC_COUNT - 1 do
        local base = addr.NPC_DATA_START + (slot * addr.NPC_ENTRY_SIZE)
        local byte0 = memory.readbyte(base)
        local byte1 = memory.readbyte(base + 1)
        local byte2 = memory.readbyte(base + 2)
        if is_active_npc_slot(byte0, byte1) and tonumber(byte2) ~= 0 then
            state.slots[slot] = {
                byte0 = byte0,
                byte1 = byte1,
                byte2 = byte2,
                parked_byte0 = bit_and(byte0, 0xE0) + PARKED_NPC_COORD,
                parked_byte1 = bit_and(byte1, 0xE0) + PARKED_NPC_COORD,
            }
        end
    end
    return state
end

local function apply_npc_parking_state(state)
    if not state then return 0 end
    local map_id = nav.get_position()
    if map_id ~= state.map_id then
        return 0
    end
    local parked = 0
    for slot, snapshot in pairs(state.slots or {}) do
        write_npc_bytes(slot, snapshot.parked_byte0, snapshot.parked_byte1, snapshot.byte2)
        parked = parked + 1
    end
    return parked
end

local function restore_npc_parking_state(state)
    if not state then return 0, true end
    local map_id = nav.get_position()
    if map_id ~= state.map_id then
        return 0, false
    end
    local restored = 0
    for slot, snapshot in pairs(state.slots or {}) do
        write_npc_bytes(slot, snapshot.byte0, snapshot.byte1, snapshot.byte2)
        restored = restored + 1
    end
    return restored, true
end

local function stationary_npc_at(x, y)
    for slot = 0, addr.NPC_COUNT - 1 do
        local base = addr.NPC_DATA_START + (slot * addr.NPC_ENTRY_SIZE)
        local byte0 = memory.readbyte(base)
        local byte1 = memory.readbyte(base + 1)
        local byte2 = memory.readbyte(base + 2)
        if is_active_npc_slot(byte0, byte1) and tonumber(byte2) == 0 then
            local nx = bit_and(byte0, 0x1F)
            local ny = bit_and(byte1, 0x1F)
            if nx == x and ny == y then
                return {slot = slot, x = nx, y = ny, byte0 = byte0, byte1 = byte1, byte2 = byte2}
            end
        end
    end
    return nil
end

local function get_door_context(map_id, x, y)
    if type(map_reader.get_door_cell_context) == "function" then
        local ok, ctx = pcall(map_reader.get_door_cell_context, map_id, x, y)
        if ok and ctx then
            return ctx
        end
    end
    local details = map_reader.get_walkability_details(map_id, x, y)
    if details and (details.reason == "door_closed" or details.reason == "door_open") then
        return {
            is_door = true,
            open = details.reason == "door_open",
            context = details.reason,
        }
    end
    return nil
end

local function get_report(map_id, create)
    local report = reports_by_map[map_id]
    if not report and create then
        report = {
            map_id = map_id,
            edges = {},
            counts = {},
            passthroughs = {},
            directionals = {},
            stationary_npcs = {},
            transitions = {},
            door_frontiers = {},
            unstable_cells = {},
        }
        reports_by_map[map_id] = report
    end
    if create then
        last_report_map_id = map_id
    end
    return report
end

local function add_count(report, classification)
    report.counts[classification] = (report.counts[classification] or 0) + 1
end

local function format_door_context(ctx)
    if not ctx or not ctx.is_door then return "-" end
    local slots = ctx.open_slots and table.concat(ctx.open_slots, "|") or "-"
    return string.format("door=(%s,%s) open=%s slots=%s",
        tostring(ctx.door_x or ctx.x or "-"),
        tostring(ctx.door_y or ctx.y or "-"),
        tostring(ctx.open == true),
        slots)
end

-- Mark a cell as unstable. The DFS will then skip remaining probes from this
-- cell (start_next_edge bumps frame.next_dir past #DIRECTIONS) and any
-- passthrough candidate already recorded AT this cell is dropped.
--
-- Directional candidates are intentionally NOT pruned here: they are keyed by
-- destination, not origin, so a candidate at cell D recorded via a probe from
-- the now-unstable cell X is about what we observed AT D. The current unstable
-- reasons describe issues with the cell itself or its entry edge; once marked,
-- DFS skips remaining probes from that cell.
local function mark_unstable_candidate(report, x, y, reason)
    if not report or x == nil or y == nil then
        return
    end
    local key = cell_key(x, y)
    if not report.unstable_cells then
        report.unstable_cells = {}
    end
    local existing = report.unstable_cells[key]
    report.unstable_cells[key] = {
        x = x,
        y = y,
        reason = reason,
    }
    if crawler_state and crawler_state.report == report then
        crawler_state.unstable_cells[key] = reason or true
    end
    if not existing or existing.reason ~= reason then
        debug_tools.info(string.format(
            "MAP_CRAWL_UNSTABLE_CANDIDATE map=0x%02X cell=(%d,%d) reason=%s",
            report.map_id or 0,
            x,
            y,
            tostring(reason or "unstable_origin")))
    end
    if report.passthroughs and report.passthroughs[key] then
        report.passthroughs[key] = nil
    end
end

local function record_edge(record)
    local state = crawler_state
    local report = state and state.report or get_report(record.map_id, true)
    record.index = #report.edges + 1
    report.edges[#report.edges + 1] = record
    add_count(report, record.classification)

    if record.classification == "false_wall_candidate" then
        local key = cell_key(record.dest_x, record.dest_y)
        if not (report.unstable_cells and report.unstable_cells[key]) then
            if not report.passthroughs[key] then
                report.passthroughs[key] = {
                    x = record.dest_x,
                    y = record.dest_y,
                    approaches = {},
                }
            end
            if record.approach then
                report.passthroughs[key].approaches[record.approach] = true
            end
        end
    elseif record.classification == "directional_block_candidate" then
        local key = cell_key(record.dest_x, record.dest_y)
        if not report.directionals[key] then
            report.directionals[key] = {x = record.dest_x, y = record.dest_y, dirs = {}}
        end
        report.directionals[key].dirs[record.approach] = true
    elseif record.classification == "stationary_npc_blocked" then
        report.stationary_npcs[cell_key(record.dest_x, record.dest_y)] = record.npc_slot or true
    elseif record.classification == "transition_candidate" then
        mark_unstable_candidate(report, record.from_x, record.from_y, "origin_transition")
        report.transitions[#report.transitions + 1] = record
    elseif record.classification == "boundary_frontier" then
        mark_unstable_candidate(report, record.from_x, record.from_y, "origin_boundary_frontier")
    elseif record.classification == "door_frontier" then
        report.door_frontiers[cell_key(record.dest_x, record.dest_y)] = record
    elseif record.classification == "movement_drift" or record.classification == "position_drift" then
        mark_unstable_candidate(report, record.from_x, record.from_y, "origin_" .. tostring(record.classification))
    end

    debug_tools.info(string.format(
        "MAP_CRAWL_EDGE run=%d map=0x%02X index=%d from=(%d,%d) dir=%s dest=(%d,%d) class=%s attempts=%d blocked_attempts=%d model_walkable=%s model_reason=%s tile=%s approach=%s door_context=%s note=%s",
        record.run_id or 0,
        record.map_id or 0,
        record.index,
        record.from_x or -1,
        record.from_y or -1,
        tostring(record.dir or "-"),
        record.dest_x or -1,
        record.dest_y or -1,
        tostring(record.classification),
        record.attempts or 0,
        record.blocked_attempts or 0,
        tostring(record.model_walkable),
        tostring(record.model_reason or "-"),
        tostring(record.tile_type or "-"),
        tostring(record.approach or "-"),
        format_door_context(record.door_context),
        tostring(record.note or "-")))
    if state and state.command_name == "sweep_walk" then
        write_sweep_status_file(state, "probing", "edge:" .. tostring(record.classification), nil, record)
    end
end

local function model_context(map_id, x, y)
    local details = map_reader.get_walkability_details(map_id, x, y)
    if not details then
        return {model_walkable = nil, model_reason = "no_details", tile_type = nil}
    end
    return {
        details = details,
        model_walkable = details.effective_walkable,
        model_reason = details.reason,
        tile_type = details.tile_type,
        hazard = details.hazard == true,
    }
end

local function in_bounds(map_id, x, y)
    local width, height = map_reader.get_map_dimensions(map_id)
    return width and height and x >= 0 and y >= 0 and x < width and y < height
end

local function make_record(edge, classification, extra)
    local state = crawler_state
    local map_id = edge.map_id or (state and state.map_id)
    local ctx = model_context(map_id, edge.dest_x, edge.dest_y)
    local record = {
        run_id = edge.run_id or (state and state.run_id),
        map_id = map_id,
        from_x = edge.from_x,
        from_y = edge.from_y,
        dir = edge.dir,
        dest_x = edge.dest_x,
        dest_y = edge.dest_y,
        approach = edge.approach,
        classification = classification,
        attempts = edge.attempt or 0,
        blocked_attempts = edge.blocked_attempts or 0,
        timing_suspect_blocked_attempts = edge.timing_suspect_blocked_attempts or 0,
        model_walkable = ctx.model_walkable,
        model_reason = ctx.model_reason,
        tile_type = ctx.tile_type,
        door_context = edge.door_context,
    }
    if extra then
        for k, v in pairs(extra) do
            record[k] = v
        end
    end
    return record
end

local function finish_run(completed, reason)
    local state = crawler_state
    if not state then
        return
    end

    if state.npc_parking then
        local restored_slots, restored = restore_npc_parking_state(state.npc_parking)
        debug_tools.info(string.format(
            "MAP_CRAWL_NPC_PARK_RESTORE run=%d map=0x%02X restored=%s restored_slots=%d reason=%s",
            state.run_id,
            state.map_id,
            restored and "true" or "false",
            restored_slots,
            tostring(reason or "complete")))
    end

    local report = state.report
    local pt_count = M.count_passthrough_candidates(state.map_id)
    local dir_count = M.count_directional_candidate_cells(state.map_id)
    debug_tools.info(string.format(
        "MAP_CRAWL_FINISH run=%d map=0x%02X completed=%s reason=%s edges=%d passthrough_candidates=%d directional_candidates=%d stationary_npc_cells=%d transitions=%d",
        state.run_id,
        state.map_id,
        tostring(completed == true),
        tostring(reason or "complete"),
        #(report.edges or {}),
        pt_count,
        dir_count,
        M.count_stationary_npc_cells(state.map_id),
        #(report.transitions or {})))

    -- Write the per-map export file on every finish (option A: even aborted
    -- runs may have salvageable candidates). Failures are logged but never
    -- block the speech announcement or the state cleanup that follow.
    local export_path = write_export_file(state, completed == true, reason)
    if export_path then
        debug_tools.info(string.format(
            "MAP_CRAWL_EXPORT_FILE run=%d map=0x%02X path=%s",
            state.run_id, state.map_id, export_path))
    end
    if state.command_name == "sweep_walk" then
        write_sweep_output_files(state, completed == true, reason, export_path)
        write_sweep_status_file(state, "finished", "finished:" .. tostring(reason or "complete"), reason)
    end

    speak_finish_summary(completed == true, reason, pt_count, dir_count)

    crawler_state = nil
end

local function begin_manual_stop_settle(active_edge)
    local state = crawler_state
    if not state then
        return
    end
    local _, px, py = nav.get_position()
    state.stop_requested = true
    state.stop_reason = "manual_stop"
    state.stop_wait_frames = MANUAL_STOP_SETTLE_FRAMES
    state.stop_origin_x = px
    state.stop_origin_y = py
    state.stop_expected_x = active_edge and active_edge.dest_x or nil
    state.stop_expected_y = active_edge and active_edge.dest_y or nil
    state.stop_dir = active_edge and active_edge.dir or nil
    state.pending_retry = nil
    state.pending_return = nil
    state.active_edge = nil
    debug_tools.info(string.format(
        "MAP_CRAWL_STOP_WAIT run=%d map=0x%02X origin=(%d,%d) dir=%s expected=(%s,%s) wait_frames=%d",
        state.run_id,
        state.map_id,
        px or -1,
        py or -1,
        tostring(state.stop_dir or "-"),
        tostring(state.stop_expected_x or "-"),
        tostring(state.stop_expected_y or "-"),
        state.stop_wait_frames))
end

local function classify_blocked(edge)
    -- Re-check for a stationary NPC even though maybe_prepare_probe already
    -- did so before injecting. The two checks fire at different points in the
    -- step lifecycle and can legitimately disagree: a mobile NPC could
    -- escape its parked slot during frameadvance and become a fresh blocker
    -- by the time the step is reported as blocked. Caching the preflight
    -- result would mask that case, so the duplicate scan is intentional.
    local stationary = stationary_npc_at(edge.dest_x, edge.dest_y)
    if stationary then
        return "stationary_npc_blocked", {npc_slot = stationary.slot}
    end
    local door = edge.door_context or get_door_context(edge.map_id, edge.dest_x, edge.dest_y)
    if door and door.is_door and not door.open then
        return "door_frontier", {door_context = door}
    end
    local ctx = model_context(edge.map_id, edge.dest_x, edge.dest_y)
    local directional_blocks = map_reader.get_directional_blocks and map_reader.get_directional_blocks(edge.map_id) or nil
    local existing_entry = directional_blocks and directional_blocks[edge.dest_x .. "," .. edge.dest_y] or nil
    if existing_entry and edge.approach and existing_entry[edge.approach] == true then
        return "modeled_blocked", {note = "approach_already_modeled"}
    end
    if ctx.model_walkable == true then
        return "directional_block_candidate", nil
    end
    if ctx.model_reason == "out_of_bounds" then
        return "boundary_blocked", nil
    end
    return "modeled_blocked", nil
end

local function start_edge(edge)
    local state = crawler_state
    if not state then return false end
    edge.run_id = state.run_id
    edge.map_id = state.map_id
    edge.attempt = (edge.attempt or 0) + 1

    local current_map, px, py = nav.get_position()
    if current_map ~= state.map_id or px ~= edge.from_x or py ~= edge.from_y then
        record_edge(make_record(edge, "position_drift", {
            final_x = px,
            final_y = py,
            new_map_id = current_map,
            note = "start_edge_position_mismatch",
        }))
        finish_run(false, "position_drift")
        return false
    end

    state.active_edge = edge
    debug_tools.info(string.format(
        "MAP_CRAWL_PROBE run=%d map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d) attempt=%d/%d kind=%s",
        state.run_id,
        state.map_id,
        edge.from_x,
        edge.from_y,
        edge.dir,
        edge.dest_x,
        edge.dest_y,
        edge.attempt,
        state.options.attempts,
        tostring(edge.kind or "probe")))
    if state.command_name == "sweep_walk" then
        write_sweep_status_file(state, "probing", "probe_started", nil, edge)
    end
    local ok = auto_step.inject_step(edge.dir, {
        source = "map_crawl",
        release_after_inject_limit = true,
    })
    if not ok then
        state.active_edge = nil
        record_edge(make_record(edge, "probe_refused", {note = "auto_step_refused"}))
        return false
    end
    return true
end

local function release_after_step_outcome()
    if type(auto_step.cancel_active_step) == "function" then
        auto_step.cancel_active_step(true, true)
    end
end

local function build_edge(from_x, from_y, dir, kind)
    local meta = DIR_BY_KEY[dir]
    return {
        kind = kind or "probe",
        from_x = from_x,
        from_y = from_y,
        dir = dir,
        dest_x = from_x + meta.dx,
        dest_y = from_y + meta.dy,
        approach = meta.approach,
        blocked_attempts = 0,
        timing_suspect_blocked_attempts = 0,
        attempt = 0,
    }
end

local function start_return_edge(edge)
    return start_edge(edge)
end

local function maybe_start_pending_return()
    local state = crawler_state
    if not state or not state.pending_return then
        return false
    end
    local edge = state.pending_return
    state.pending_return = nil
    return start_return_edge(edge)
end

local function max_recorded_edges_reached(state)
    if not state or not state.report or not state.options then
        return false
    end
    return #(state.report.edges or {}) >= state.options.max_edges
end

local function record_preflight_skip(edge, classification, extra)
    record_edge(make_record(edge, classification, extra))
    crawler_state.probed_edges[edge_key(edge.from_x, edge.from_y, edge.dir)] = true
end

local function maybe_prepare_probe(edge)
    local state = crawler_state
    local ctx = model_context(state.map_id, edge.dest_x, edge.dest_y)
    edge.door_context = get_door_context(state.map_id, edge.dest_x, edge.dest_y)

    if not in_bounds(state.map_id, edge.dest_x, edge.dest_y) or ctx.model_reason == "engine_boundary" then
        record_preflight_skip(edge, "boundary_frontier", {note = "destination_boundary"})
        return false
    end

    if ctx.hazard or map_reader.is_hazard_cell(state.map_id, edge.dest_x, edge.dest_y) then
        record_preflight_skip(edge, "hazard_skipped", {note = "destination_hazard"})
        return false
    end

    if edge.door_context and edge.door_context.is_door and not edge.door_context.open then
        record_preflight_skip(edge, "door_frontier", {door_context = edge.door_context})
        return false
    end

    local stationary = stationary_npc_at(edge.dest_x, edge.dest_y)
    if stationary then
        record_preflight_skip(edge, "stationary_npc_blocked", {npc_slot = stationary.slot})
        return false
    end

    return true
end

local function start_next_edge()
    local state = crawler_state
    if not state then return end

    if max_recorded_edges_reached(state) then
        finish_run(false, "max_edges")
        return
    end

    if maybe_start_pending_return() then
        return
    end

    while crawler_state do
        if max_recorded_edges_reached(state) then
            finish_run(false, "max_edges")
            return
        end

        local frame = state.stack[#state.stack]
        if not frame then
            finish_run(true, "complete")
            return
        end

        local _, px, py = nav.get_position()
        if px ~= frame.x or py ~= frame.y then
            debug_tools.error(string.format(
                "MAP_CRAWL_ABORT run=%d map=0x%02X reason=position_drift expected=(%d,%d) current=(%d,%d)",
                state.run_id, state.map_id, frame.x, frame.y, px or -1, py or -1))
            finish_run(false, "position_drift")
            return
        end

        if state.unstable_cells[cell_key(frame.x, frame.y)] then
            frame.next_dir = #DIRECTIONS + 1
        end

        if frame.next_dir > #DIRECTIONS then
            if #state.stack == 1 then
                finish_run(true, "complete")
                return
            end
            local child = table.remove(state.stack)
            local parent = state.stack[#state.stack]
            local edge = build_edge(child.x, child.y, child.parent_reverse_dir, "backtrack")
            edge.dest_x = parent.x
            edge.dest_y = parent.y
            edge.approach = DIR_BY_KEY[edge.dir].approach
            start_edge(edge)
            return
        end

        local dir_meta = DIRECTIONS[frame.next_dir]
        frame.next_dir = frame.next_dir + 1
        local ekey = edge_key(frame.x, frame.y, dir_meta.key)
        if not state.probed_edges[ekey] then
            local edge = build_edge(frame.x, frame.y, dir_meta.key, "probe")
            state.probed_edges[ekey] = true
            state.probed_edge_count = state.probed_edge_count + 1
            if maybe_prepare_probe(edge) then
                start_edge(edge)
                return
            end
        end
    end
end

local function handle_step_complete(data)
    local state = crawler_state
    if not state or not state.active_edge then return end
    local edge = state.active_edge
    if data and (data.from_x ~= edge.from_x or data.from_y ~= edge.from_y or data.dir ~= edge.dir) then
        return
    end
    state.active_edge = nil

    local current_map, px, py = nav.get_position()
    if current_map ~= state.map_id then
        record_edge(make_record(edge, "transition_candidate", {
            note = string.format("map_changed_to_0x%02X", current_map or 0),
            new_map_id = current_map,
            final_x = px,
            final_y = py,
        }))
        finish_run(false, "map_change")
        return
    end

    if px ~= edge.dest_x or py ~= edge.dest_y then
        record_edge(make_record(edge, "movement_drift", {
            note = "unexpected_landing",
            final_x = px,
            final_y = py,
        }))
        finish_run(false, "movement_drift")
        return
    end

    release_after_step_outcome()

    local classification = "open_floor"
    local note = nil
    local mixed_origin_reason = nil
    if (edge.blocked_attempts or 0) > 0 then
        classification = "mixed_probe"
        local ctx = model_context(edge.map_id, edge.dest_x, edge.dest_y)
        if ctx.model_walkable == false then
            mixed_origin_reason = "mixed_false_wall_origin"
        else
            mixed_origin_reason = "mixed_probe_origin"
        end
        note = mixed_origin_reason
    else
        local ctx = model_context(edge.map_id, edge.dest_x, edge.dest_y)
        if ctx.model_walkable == false then
            local timeout_retries = tonumber(data and data.timeout_retries) or 0
            local turn_represses = tonumber(data and data.turn_represses) or 0
            local source = data and data.source or nil
            if source == "pending_repress"
               or timeout_retries > 0
               or turn_represses > 0
               or (edge.timing_suspect_blocked_attempts or 0) > 0 then
                classification = "timing_suspect_false_wall"
                note = string.format(
                    "source=%s timeout_retries=%d turn_represses=%d timing_suspect_blocks=%d",
                    tostring(source or "-"),
                    timeout_retries,
                    turn_represses,
                    edge.timing_suspect_blocked_attempts or 0)
            else
                classification = "false_wall_candidate"
            end
        elseif edge.door_context and edge.door_context.is_door and edge.door_context.open then
            classification = "open_door_passage"
        elseif (edge.timing_suspect_blocked_attempts or 0) > 0 then
            note = "timing_suspect_retry"
        end
    end

    record_edge(make_record(edge, classification, {
        final_x = px,
        final_y = py,
        door_context = edge.door_context,
        note = note,
    }))
    if classification == "timing_suspect_false_wall" then
        mark_unstable_candidate(state.report, edge.dest_x, edge.dest_y, "timing_suspect_false_wall")
    elseif mixed_origin_reason then
        mark_unstable_candidate(state.report, edge.dest_x, edge.dest_y, mixed_origin_reason)
    end
    state.step_settle_frames = STEP_SETTLE_FRAMES

    if edge.kind == "backtrack" or edge.kind == "return_to_frontier" then
        return
    end

    local dest_key = cell_key(edge.dest_x, edge.dest_y)
    if state.cells[dest_key] then
        state.pending_return = build_edge(edge.dest_x, edge.dest_y, DIR_BY_KEY[edge.dir].reverse, "return_to_frontier")
        return
    end

    state.cells[dest_key] = true
    if in_bounds(state.map_id, edge.dest_x, edge.dest_y) then
        state.stack[#state.stack + 1] = {
            x = edge.dest_x,
            y = edge.dest_y,
            next_dir = 1,
            parent_reverse_dir = DIR_BY_KEY[edge.dir].reverse,
        }
    else
        -- Defensive: maybe_prepare_probe already rejects out-of-bounds
        -- destinations as boundary_frontier before we ever inject, so this
        -- branch is unreachable in normal flow. Kept in case a future
        -- map_reader edit allows in-bounds preflight to disagree with the
        -- crawler's in_bounds check at landing time.
        state.pending_return = build_edge(edge.dest_x, edge.dest_y, DIR_BY_KEY[edge.dir].reverse, "return_to_frontier")
    end
end

local function handle_blocked(data)
    local state = crawler_state
    if not state or not state.active_edge then return end
    local edge = state.active_edge
    if data and (data.from_x ~= edge.from_x or data.from_y ~= edge.from_y or data.dir ~= edge.dir) then
        return
    end

    local timing_suspect_block = data
        and (data.timing_suspect == true or data.movement_started == true)
    if timing_suspect_block then
        edge.timing_suspect_blocked_attempts = (edge.timing_suspect_blocked_attempts or 0) + 1
    else
        edge.blocked_attempts = (edge.blocked_attempts or 0) + 1
    end
    release_after_step_outcome()
    state.step_settle_frames = STEP_SETTLE_FRAMES
    if edge.attempt < state.options.attempts then
        debug_tools.info(string.format(
            "MAP_CRAWL_RETRY run=%d map=0x%02X from=(%d,%d) dir=%s blocked_attempts=%d timing_suspect_blocks=%d next_attempt=%d/%d",
            state.run_id,
            state.map_id,
            edge.from_x,
            edge.from_y,
            edge.dir,
            edge.blocked_attempts or 0,
            edge.timing_suspect_blocked_attempts or 0,
            edge.attempt + 1,
            state.options.attempts))
        state.active_edge = nil
        state.pending_retry = edge
        return
    end

    state.active_edge = nil
    local classification, extra
    if edge.kind == "backtrack" then
        -- A failed backtrack means we cannot safely return to the parent
        -- frame. It is more likely a transient (mobile NPC re-spawn,
        -- timing edge, position desync) than real one-way geometry, and
        -- we already walked the opposite direction across this edge.
        -- Keep it purely diagnostic and abort the run instead of writing
        -- a directional candidate for the parent cell.
        classification = "backtrack_blocked"
        extra = {note = "backtrack_to_parent_blocked"}
    elseif edge.kind == "return_to_frontier" then
        -- A failed return to a previously visited frontier leaves the
        -- crawler standing away from the DFS frame it is about to resume.
        -- Treat it like a recovery failure, not map geometry.
        classification = "return_to_frontier_blocked"
        extra = {note = "return_to_visited_frontier_blocked"}
    elseif (edge.blocked_attempts or 0) == 0
       and (edge.timing_suspect_blocked_attempts or 0) > 0 then
        classification = "timing_suspect_blocked"
        extra = {note = "movement_started_timeout"}
    else
        classification, extra = classify_blocked(edge)
    end
    record_edge(make_record(edge, classification, extra))
    if edge.kind == "backtrack" or edge.kind == "return_to_frontier" then
        finish_run(false, classification)
    end
end

local function tick_context_state(context)
    if type(context) == "table" then
        return context.state or context.game_state
    end
    return context
end

local function interrupted_step_classification(can_walk, context)
    if can_walk == false and tick_context_state(context) == "battle" then
        return "battle_interrupted", "battle_started_during_probe"
    end
    return "auto_step_lost", "active_step_cleared_without_event"
end

local function tick_impl(can_walk, context)
    local state = crawler_state
    if not debug_tools.DEBUG_MODE or not state then
        return
    end

    local map_id, px, py = nav.get_position()
    if state.stop_requested then
        if map_id ~= state.map_id then
            debug_tools.info(string.format(
                "MAP_CRAWL_STOP_SETTLED run=%d map=0x%02X final_map=0x%02X final=(%d,%d) reason=map_changed_after_stop",
                state.run_id,
                state.map_id,
                map_id or 0,
                px or -1,
                py or -1))
            finish_run(false, state.stop_reason or "manual_stop")
            return
        end
        if px ~= state.stop_origin_x or py ~= state.stop_origin_y then
            debug_tools.info(string.format(
                "MAP_CRAWL_STOP_SETTLED run=%d map=0x%02X final=(%d,%d) expected=(%s,%s) reason=position_changed_after_stop",
                state.run_id,
                state.map_id,
                px or -1,
                py or -1,
                tostring(state.stop_expected_x or "-"),
                tostring(state.stop_expected_y or "-")))
            finish_run(false, state.stop_reason or "manual_stop")
            return
        end
        state.stop_wait_frames = (state.stop_wait_frames or 0) - 1
        if state.stop_wait_frames <= 0 then
            debug_tools.info(string.format(
                "MAP_CRAWL_STOP_SETTLED run=%d map=0x%02X final=(%d,%d) expected=(%s,%s) reason=no_post_stop_movement",
                state.run_id,
                state.map_id,
                px or -1,
                py or -1,
                tostring(state.stop_expected_x or "-"),
                tostring(state.stop_expected_y or "-")))
            finish_run(false, state.stop_reason or "manual_stop")
        end
        return
    end
    if map_id ~= state.map_id then
        if state.active_edge then
            local edge = state.active_edge
            state.active_edge = nil
            record_edge(make_record(edge, "transition_candidate", {
                note = string.format("map_changed_to_0x%02X", map_id or 0),
                new_map_id = map_id,
                final_x = px,
                final_y = py,
            }))
        end
        finish_run(false, "map_change")
        return
    end

    local cur_hp = memory.readbyte(addr.CURRENT_HP)
    if cur_hp <= LOW_HP_ABORT_THRESHOLD then
        if state.active_edge then
            auto_step.cancel_active_step(true, true)
        end
        debug_tools.info(string.format(
            "MAP_CRAWL_ABORT run=%d map=0x%02X reason=low_hp hp=%d threshold=%d",
            state.run_id, state.map_id, cur_hp, LOW_HP_ABORT_THRESHOLD))
        tolk.output_interrupt(string.format("Map crawl aborted: HP critical (%d).", cur_hp))
        finish_run(false, "low_hp")
        return
    end

    if state.active_edge then
        local auto_step_state = nil
        if type(auto_step.get_active_step_state) == "function" then
            auto_step_state = auto_step.get_active_step_state()
        end
        if auto_step_state == nil then
            -- auto_step silently cleared the in-flight step (can_walk
            -- dropped, a different live direction interrupted it, the
            -- config flag toggled, ...) without firing
            -- route_step_completed or route_blocked. Don't hang waiting
            -- for an event that will never arrive. The classification is
            -- diagnostic-only -- record_edge does not promote it into
            -- passthroughs or directionals.
            local edge = state.active_edge
            local classification, note = interrupted_step_classification(can_walk, context)
            state.active_edge = nil
            record_edge(make_record(edge, classification, {
                note = note,
                final_x = px,
                final_y = py,
            }))
            finish_run(false, classification)
        end
        return
    end
    if auto_step.is_route_active and auto_step.is_route_active() then
        return
    end
    if (state.step_settle_frames or 0) > 0 then
        release_after_step_outcome()
        state.step_settle_frames = state.step_settle_frames - 1
        return
    end
    if not can_walk then
        return
    end

    if state.pending_retry then
        local retry = state.pending_retry
        state.pending_retry = nil
        start_edge(retry)
        return
    end

    start_next_edge()
end

local function start_impl(arg, context)
    context = context or {}
    if crawler_state then
        return false, "Map crawl already active"
    end
    local opts, err = parse_options(arg)
    if not opts then
        return false, err
    end

    local map_id, px, py = nav.get_position()
    local terrain = memory.readbyte(addr.TERRAIN_OFFSET)
    if maps.is_overworld(map_id, terrain) then
        return false, "Map crawl refuses overworld maps in V1"
    end
    if not map_reader.get_tile_grid(map_id) then
        return false, string.format("No interior map grid for map %02X", map_id)
    end
    local start = model_context(map_id, px, py)
    if start.model_reason == "out_of_bounds" or start.hazard then
        return false, "Current tile is not a safe crawl start"
    end

    run_counter = run_counter + 1
    local report = get_report(map_id, true)
    report.edges = {}
    report.counts = {}
    report.passthroughs = {}
    report.directionals = {}
    report.stationary_npcs = {}
    report.transitions = {}
    report.door_frontiers = {}
    report.unstable_cells = {}

    crawler_state = {
        run_id = run_counter,
        map_id = map_id,
        command_name = context.command_name or "crawl_map_frontier",
        method = "normal_movement",
        teleport_used = false,
        started_at = os.time(),
        started_clock = os.clock(),
        options = opts,
        start_x = px,
        start_y = py,
        stack = {{x = px, y = py, next_dir = 1}},
        cells = {[cell_key(px, py)] = true},
        probed_edges = {},
        probed_edge_count = 0,
        report = report,
        npc_parking = nil,
        unstable_cells = {},
    }

    if opts.park_mobile_npcs then
        crawler_state.npc_parking = capture_mobile_npc_parking_state(map_id)
        local parked = apply_npc_parking_state(crawler_state.npc_parking)
        debug_tools.info(string.format(
            "MAP_CRAWL_NPC_PARK_START run=%d map=0x%02X parked_slots=%d",
            crawler_state.run_id,
            map_id,
            parked))
    end

    debug_tools.info(string.format(
        "MAP_CRAWL_START run=%d map=0x%02X start=(%d,%d) attempts=%d max_edges=%d park_mobile_npcs=%s start_model_walkable=%s start_reason=%s",
        crawler_state.run_id,
        map_id,
        px,
        py,
        opts.attempts,
        opts.max_edges,
        tostring(opts.park_mobile_npcs),
        tostring(start.model_walkable),
        tostring(start.model_reason or "-")))
    if crawler_state.command_name == "sweep_walk" then
        debug_tools.info(string.format(
            "SWEEP_WALK_START run=%d map=0x%02X method=%s teleport_used=%s backing=crawl_map_frontier",
            crawler_state.run_id,
            map_id,
            crawler_state.method,
            tostring(crawler_state.teleport_used)))
        write_sweep_status_file(crawler_state, "starting", "started", nil, {
            from_x = px,
            from_y = py,
        })
    end
    tolk.output_interrupt(string.format("Map frontier crawl started on map %02X", map_id))
    return true
end

function M.start(arg)
    return start_impl(arg, {command_name = "crawl_map_frontier"})
end

function M.start_walk_sweep(arg)
    return start_impl(arg, {command_name = "sweep_walk"})
end

function M.stop()
    if not crawler_state then
        return false, "No active map crawl"
    end
    local active_edge = crawler_state.active_edge
    local active_step_state = nil
    if type(auto_step.get_active_step_state) == "function" then
        active_step_state = auto_step.get_active_step_state()
    end
    auto_step.cancel_active_step(true, true)
    if active_edge
       and active_step_state
       and active_step_state.dir == active_edge.dir
       and active_step_state.movement_started == true then
        local map_id = crawler_state.map_id
        begin_manual_stop_settle(active_edge)
        return true, string.format("Stopping map crawl on map %02X", map_id)
    end
    finish_run(false, "manual_stop")
    -- finish_run already spoke the "Map crawl stopped ..." summary; return a
    -- nil message so the stop_map_crawl command does not double-announce.
    return true, nil
end

function M.tick(can_walk, context)
    local ok, err = pcall(tick_impl, can_walk, context)
    if not ok then
        if crawler_state and crawler_state.active_edge then
            auto_step.cancel_active_step(true, true)
        end
        debug_tools.error("MAP_CRAWL_ABORT reason=script_error error=" .. tostring(err))
        finish_run(false, "script_error")
    end
end

function M.apply_npc_parking()
    if crawler_state and crawler_state.npc_parking then
        apply_npc_parking_state(crawler_state.npc_parking)
    end
end

function M.is_active()
    return crawler_state ~= nil
end

function M.count_passthrough_candidates(map_id)
    local report = get_report(map_id)
    local n = 0
    if report then
        for _ in pairs(M.get_passthrough_candidates(report.map_id) or {}) do
            n = n + 1
        end
    end
    return n
end

function M.count_directional_candidate_cells(map_id)
    local report = get_report(map_id)
    local n = 0
    if report then
        for _ in pairs(M.get_directional_candidates(report.map_id) or {}) do
            n = n + 1
        end
    end
    return n
end

function M.count_stationary_npc_cells(map_id)
    local report = get_report(map_id)
    local n = 0
    if report then
        for _ in pairs(report.stationary_npcs or {}) do n = n + 1 end
    end
    return n
end

local function sorted_keys(tbl)
    local keys = {}
    for key in pairs(tbl or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function direction_list(dirs)
    local names = {}
    for _, name in ipairs({"north", "south", "east", "west"}) do
        if dirs and dirs[name] then
            names[#names + 1] = name
        end
    end
    return names
end

local function current_seam_classification(map_id, x, y, approach)
    if not route_mgr or type(route_mgr.get_seam_observation) ~= "function" then
        return nil
    end
    local ok, observation = pcall(route_mgr.get_seam_observation, map_id, x, y, approach)
    if not ok or not observation then
        return nil
    end
    return observation.classification
end

local function keep_passthrough_candidate(map_id, cell)
    local approaches = cell and cell.approaches
    if type(approaches) ~= "table" or next(approaches) == nil then
        return true
    end
    local saw_observation = false
    for approach in pairs(approaches) do
        local classification = current_seam_classification(map_id, cell.x, cell.y, approach)
        if classification == nil then
            return true
        end
        saw_observation = true
        if classification == "passable_only" then
            return true
        end
    end
    return not saw_observation
end

local function filtered_directional_dirs(map_id, cell)
    local kept = {}
    for approach in pairs((cell and cell.dirs) or {}) do
        local classification = current_seam_classification(map_id, cell.x, cell.y, approach)
        if classification == nil
           or classification == "blocked_only"
           or classification == "confirmed_blocked" then
            kept[approach] = true
        end
    end
    return kept
end

function M.get_passthrough_candidates(map_id)
    local report = get_report(map_id)
    local filtered = {}
    if not report then
        return filtered
    end
    for key, cell in pairs(report.passthroughs or {}) do
        if keep_passthrough_candidate(report.map_id, cell) then
            filtered[key] = cell
        end
    end
    return filtered
end

function M.get_directional_candidates(map_id)
    local report = get_report(map_id)
    local filtered = {}
    if not report then
        return filtered
    end
    for key, cell in pairs(report.directionals or {}) do
        local dirs = filtered_directional_dirs(report.map_id, cell)
        if next(dirs) ~= nil then
            filtered[key] = {
                x = cell.x,
                y = cell.y,
                dirs = dirs,
            }
        end
    end
    return filtered
end

function M.report(map_id)
    map_id = map_id or (crawler_state and crawler_state.map_id) or last_report_map_id or nav.get_position()
    local report = get_report(map_id)
    if not report then
        debug_tools.info(string.format("MAP_CRAWL_SUMMARY map=0x%02X none", map_id or 0))
        return 0
    end
    local passthroughs = M.get_passthrough_candidates(map_id)
    local directionals = M.get_directional_candidates(map_id)
    debug_tools.info(string.format(
        "MAP_CRAWL_SUMMARY map=0x%02X edges=%d passthrough_candidates=%d directional_candidate_cells=%d stationary_npc_cells=%d door_frontiers=%d transitions=%d",
        map_id,
        #(report.edges or {}),
        M.count_passthrough_candidates(map_id),
        M.count_directional_candidate_cells(map_id),
        M.count_stationary_npc_cells(map_id),
        #sorted_keys(report.door_frontiers or {}),
        #(report.transitions or {})))
    for _, key in ipairs(sorted_keys(passthroughs)) do
        local cell = passthroughs[key]
        debug_tools.info(string.format("MAP_CRAWL_HIGH_VALUE map=0x%02X type=passthrough cell=(%d,%d)", map_id, cell.x, cell.y))
    end
    for _, key in ipairs(sorted_keys(directionals)) do
        local cell = directionals[key]
        debug_tools.info(string.format(
            "MAP_CRAWL_HIGH_VALUE map=0x%02X type=directional cell=(%d,%d) approaches=%s",
            map_id, cell.x, cell.y, table.concat(direction_list(cell.dirs), ",")))
    end
    return #(report.edges or {})
end

function M.dump_report(map_id)
    map_id = map_id or (crawler_state and crawler_state.map_id) or last_report_map_id or nav.get_position()
    local report = get_report(map_id)
    if not report then
        debug_tools.info(string.format("MAP_CRAWL_DUMP map=0x%02X none", map_id or 0))
        return 0
    end
    for _, record in ipairs(report.edges or {}) do
        debug_tools.info(string.format(
            "MAP_CRAWL_DUMP_EDGE map=0x%02X index=%d from=(%d,%d) dir=%s dest=(%d,%d) class=%s attempts=%d blocked_attempts=%d model_walkable=%s reason=%s note=%s",
            map_id,
            record.index or 0,
            record.from_x or -1,
            record.from_y or -1,
            tostring(record.dir or "-"),
            record.dest_x or -1,
            record.dest_y or -1,
            tostring(record.classification or "-"),
            record.attempts or 0,
            record.blocked_attempts or 0,
            tostring(record.model_walkable),
            tostring(record.model_reason or "-"),
            tostring(record.note or "-")))
    end
    return #(report.edges or {})
end

local function format_direction_table(dirs)
    local parts = {}
    for _, name in ipairs(direction_list(dirs)) do
        parts[#parts + 1] = name .. " = true"
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function export_file_path(map_id)
    return script_dir .. string.format("dw_crawl_%02x.txt", map_id or 0)
end

local function sweep_output_base_path(state)
    return script_dir .. string.format("sweep_walk_%02x_run%03d", state.map_id or 0, state.run_id or 0)
end

local function sweep_status_file_path()
    return script_dir .. "sweep_status.txt"
end

local function current_frame_count()
    if type(emu) == "table" and type(emu.framecount) == "function" then
        local ok, value = pcall(emu.framecount)
        if ok and value ~= nil then
            return value
        end
    end
    if type(FCEU) == "table" and type(FCEU.framecount) == "function" then
        local ok, value = pcall(FCEU.framecount)
        if ok and value ~= nil then
            return value
        end
    end
    return -1
end

local function json_escape(value)
    value = tostring(value or "")
    value = value:gsub("\\", "\\\\")
    value = value:gsub('"', '\\"')
    value = value:gsub("\b", "\\b")
    value = value:gsub("\f", "\\f")
    value = value:gsub("\n", "\\n")
    value = value:gsub("\r", "\\r")
    value = value:gsub("\t", "\\t")
    return value
end

local function json_string(value)
    return '"' .. json_escape(value) .. '"'
end

local function json_bool(value)
    return value and "true" or "false"
end

local function json_number(value)
    return tostring(tonumber(value) or 0)
end

local function write_file(path, content, fail_tag, state)
    local file, err = io.open(path, "w")
    if not file then
        debug_tools.error(string.format(
            "%s run=%d map=0x%02X path=%s error=%s",
            fail_tag,
            state and state.run_id or 0,
            state and state.map_id or 0,
            tostring(path),
            tostring(err)))
        return nil
    end
    file:write(content)
    file:close()
    return path
end

local function sweep_edge_status(record)
    local class = record and record.classification or ""
    if class == "open_floor" or class == "open_door_passage" or class == "false_wall_candidate" then
        return "passable"
    end
    if class == "directional_block_candidate" or class == "modeled_blocked" or class == "boundary_blocked" then
        return "blocked"
    end
    if class == "stationary_npc_blocked" or class == "door_frontier" then
        return "dynamic_blocked"
    end
    if class == "transition_candidate" then
        return "transition"
    end
    if class == "movement_drift"
        or class == "position_drift"
        or class == "auto_step_lost"
        or class == "battle_interrupted"
        or class == "backtrack_blocked"
        or class == "return_to_frontier_blocked" then
        return "unsafe_abort"
    end
    return "unknown"
end

local function sweep_edge_confidence(record, status)
    local class = record and record.classification or ""
    if status == "passable" then
        if class == "false_wall_candidate" then
            return "observed_review"
        end
        return "observed"
    end
    if status == "blocked" then
        if class == "modeled_blocked" or class == "boundary_blocked" then
            return "modeled"
        end
        if tonumber(record and record.blocked_attempts) and tonumber(record.blocked_attempts) >= 2 then
            return "verified"
        end
        return "candidate"
    end
    if status == "dynamic_blocked" then
        return "dynamic"
    end
    if status == "transition" then
        return "observed"
    end
    if status == "unsafe_abort" then
        return "unsafe"
    end
    return "ambiguous"
end

local function build_sweep_stats(state, completed, reason)
    local report = state.report or {}
    local counts = {
        passable = 0,
        blocked = 0,
        confirmed_blockers = 0,
        unknown = 0,
        dynamic_blocked = 0,
        transition = 0,
        unsafe_abort = 0,
    }
    for _, record in ipairs(report.edges or {}) do
        local status = sweep_edge_status(record)
        counts[status] = (counts[status] or 0) + 1
        if status == "blocked" and sweep_edge_confidence(record, status) == "verified" then
            counts.confirmed_blockers = counts.confirmed_blockers + 1
        end
    end

    local runtime_seconds = 0
    if state.started_at then
        runtime_seconds = math.max(0, os.difftime(os.time(), state.started_at))
    end

    return {
        run_id = state.run_id or 0,
        completed = completed == true,
        reason = reason or "complete",
        runtime_seconds = runtime_seconds,
        cells_visited = count_table_entries(state.cells),
        frontier = #(state.stack or {}),
        edges_tested = #(report.edges or {}),
        passable_edges = counts.passable or 0,
        blocked_edges = counts.blocked or 0,
        confirmed_blockers = counts.confirmed_blockers or 0,
        unknown_edges = counts.unknown or 0,
        dynamic_blockers = counts.dynamic_blocked or 0,
        transitions = counts.transition or 0,
        unsafe_aborts = counts.unsafe_abort or 0,
        passthrough_candidates = M.count_passthrough_candidates(state.map_id),
        directional_candidate_cells = M.count_directional_candidate_cells(state.map_id),
        stationary_npc_cells = M.count_stationary_npc_cells(state.map_id),
    }
end

local function sorted_cells(cells)
    local list = {}
    for key in pairs(cells or {}) do
        local x, y = key:match("^(-?%d+),(-?%d+)$")
        list[#list + 1] = {
            key = key,
            x = tonumber(x) or 0,
            y = tonumber(y) or 0,
        }
    end
    table.sort(list, function(a, b)
        if a.y == b.y then
            return a.x < b.x
        end
        return a.y < b.y
    end)
    return list
end

local function format_json_edge(record)
    local status = sweep_edge_status(record)
    local confidence = sweep_edge_confidence(record, status)
    local parts = {}
    parts[#parts + 1] = "{"
    parts[#parts + 1] = string.format('      "index": %s,', json_number(record.index))
    parts[#parts + 1] = string.format('      "from": {"x": %s, "y": %s},',
        json_number(record.from_x), json_number(record.from_y))
    parts[#parts + 1] = string.format('      "direction": %s,', json_string(record.dir or ""))
    parts[#parts + 1] = string.format('      "to": {"x": %s, "y": %s},',
        json_number(record.dest_x), json_number(record.dest_y))
    parts[#parts + 1] = string.format('      "status": %s,', json_string(status))
    parts[#parts + 1] = string.format('      "confidence": %s,', json_string(confidence))
    parts[#parts + 1] = string.format('      "source_classification": %s,',
        json_string(record.classification or "unknown"))
    parts[#parts + 1] = string.format('      "attempts": %s,', json_number(record.attempts))
    parts[#parts + 1] = string.format('      "blocked_attempts": %s,',
        json_number(record.blocked_attempts))
    parts[#parts + 1] = string.format('      "reason": %s,',
        json_string(record.model_reason or record.note or record.classification or "unknown"))
    parts[#parts + 1] = string.format('      "note": %s', json_string(record.note or ""))
    parts[#parts + 1] = "    }"
    return table.concat(parts, "\n")
end

local function append_json_edge_array(lines, field_name, records, wanted_status)
    local filtered = {}
    for _, record in ipairs(records or {}) do
        if sweep_edge_status(record) == wanted_status then
            filtered[#filtered + 1] = record
        end
    end
    lines[#lines + 1] = string.format('  "%s": [', field_name)
    for index, record in ipairs(filtered) do
        local edge_json = format_json_edge(record)
        if index < #filtered then
            edge_json = edge_json .. ","
        end
        lines[#lines + 1] = edge_json
    end
    lines[#lines + 1] = "  ],"
end

local function build_sweep_json(state, completed, reason, export_path, summary_path)
    local stats = build_sweep_stats(state, completed, reason)
    local report = state.report or {}
    local map_name = (type(maps.get_name) == "function") and maps.get_name(state.map_id) or "?"
    local lines = {}
    lines[#lines + 1] = "{"
    lines[#lines + 1] = string.format('  "command": %s,', json_string(state.command_name or "sweep_walk"))
    lines[#lines + 1] = string.format('  "run_id": %s,', json_number(state.run_id))
    lines[#lines + 1] = string.format('  "map_id": %s,', json_number(state.map_id))
    lines[#lines + 1] = string.format('  "map_hex": %s,', json_string(string.format("%02X", state.map_id or 0)))
    lines[#lines + 1] = string.format('  "map_name": %s,', json_string(map_name))
    lines[#lines + 1] = string.format('  "method": %s,', json_string(state.method or "normal_movement"))
    lines[#lines + 1] = string.format('  "teleport_used": %s,', json_bool(state.teleport_used == true))
    lines[#lines + 1] = string.format('  "completed": %s,', json_bool(completed == true))
    lines[#lines + 1] = string.format('  "reason": %s,', json_string(reason or "complete"))
    lines[#lines + 1] = string.format('  "start": {"x": %s, "y": %s},',
        json_number(state.start_x), json_number(state.start_y))
    lines[#lines + 1] = '  "cells": ['
    local cells = sorted_cells(state.cells)
    for index, cell in ipairs(cells) do
        local suffix = (index < #cells) and "," or ""
        lines[#lines + 1] = string.format(
            '    {"x": %s, "y": %s, "status": "walkable", "confidence": "observed"}%s',
            json_number(cell.x), json_number(cell.y), suffix)
    end
    lines[#lines + 1] = "  ],"
    lines[#lines + 1] = '  "edges": ['
    for index, record in ipairs(report.edges or {}) do
        local edge_json = format_json_edge(record)
        if index < #(report.edges or {}) then
            edge_json = edge_json .. ","
        end
        lines[#lines + 1] = edge_json
    end
    lines[#lines + 1] = "  ],"
    append_json_edge_array(lines, "unknowns", report.edges, "unknown")
    append_json_edge_array(lines, "dynamic_blockers", report.edges, "dynamic_blocked")
    append_json_edge_array(lines, "transitions", report.edges, "transition")
    append_json_edge_array(lines, "unsafe_aborts", report.edges, "unsafe_abort")
    lines[#lines + 1] = '  "stats": {'
    lines[#lines + 1] = string.format('    "runtime_seconds": %s,', json_number(stats.runtime_seconds))
    lines[#lines + 1] = string.format('    "cells_visited": %s,', json_number(stats.cells_visited))
    lines[#lines + 1] = string.format('    "frontier": %s,', json_number(stats.frontier))
    lines[#lines + 1] = string.format('    "edges_tested": %s,', json_number(stats.edges_tested))
    lines[#lines + 1] = string.format('    "passable_edges": %s,', json_number(stats.passable_edges))
    lines[#lines + 1] = string.format('    "blocked_edges": %s,', json_number(stats.blocked_edges))
    lines[#lines + 1] = string.format('    "confirmed_blockers": %s,', json_number(stats.confirmed_blockers))
    lines[#lines + 1] = string.format('    "unknown_edges": %s,', json_number(stats.unknown_edges))
    lines[#lines + 1] = string.format('    "dynamic_blockers": %s,', json_number(stats.dynamic_blockers))
    lines[#lines + 1] = string.format('    "transitions": %s,', json_number(stats.transitions))
    lines[#lines + 1] = string.format('    "unsafe_aborts": %s', json_number(stats.unsafe_aborts))
    lines[#lines + 1] = "  },"
    lines[#lines + 1] = '  "outputs": {'
    lines[#lines + 1] = string.format('    "review_snippets": %s,', json_string(export_path or ""))
    lines[#lines + 1] = string.format('    "summary": %s', json_string(summary_path or ""))
    lines[#lines + 1] = "  },"
    lines[#lines + 1] = string.format('  "confidence_notes": %s',
        json_string("Safe to use passable edges; review confirmed blockers; do not blindly patch unknown or dynamic edges."))
    lines[#lines + 1] = "}"
    return table.concat(lines, "\n") .. "\n"
end

local function build_sweep_summary(state, completed, reason, export_path, json_path)
    local stats = build_sweep_stats(state, completed, reason)
    local verb = completed and "complete" or "ended"
    local lines = {}
    lines[#lines + 1] = "SWEEP_WALK " .. verb .. "."
    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("Map: %02X", state.map_id or 0)
    lines[#lines + 1] = "Method: normal movement"
    lines[#lines + 1] = "Teleport used: no"
    lines[#lines + 1] = string.format("Start cell: %d,%d", state.start_x or -1, state.start_y or -1)
    lines[#lines + 1] = "Completed: " .. tostring(completed == true)
    lines[#lines + 1] = "Reason: " .. tostring(reason or "complete")
    lines[#lines + 1] = string.format("Runtime seconds: %d", stats.runtime_seconds or 0)
    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("Visited cells: %d", stats.cells_visited or 0)
    lines[#lines + 1] = string.format("Tested edges: %d", stats.edges_tested or 0)
    lines[#lines + 1] = string.format("Passable edges: %d", stats.passable_edges or 0)
    lines[#lines + 1] = string.format("Confirmed blockers: %d", stats.confirmed_blockers or 0)
    lines[#lines + 1] = string.format("Blocked review edges: %d", stats.blocked_edges or 0)
    lines[#lines + 1] = string.format("Unknown edges: %d", stats.unknown_edges or 0)
    lines[#lines + 1] = string.format("Dynamic/NPC suspect edges: %d", stats.dynamic_blockers or 0)
    lines[#lines + 1] = string.format("Map transitions found: %d", stats.transitions or 0)
    lines[#lines + 1] = string.format("Unexpected aborts: %d", stats.unsafe_aborts or 0)
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Output:"
    lines[#lines + 1] = tostring(json_path or "")
    lines[#lines + 1] = tostring(export_path or "")
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Confidence:"
    lines[#lines + 1] = "Safe to use passable edges."
    lines[#lines + 1] = "Safe to review confirmed blockers."
    lines[#lines + 1] = "Do not blindly patch unknown/dynamic edges."
    return table.concat(lines, "\n") .. "\n"
end

write_sweep_status_file = function(state, phase, last_event, last_error, edge)
    if not state or state.command_name ~= "sweep_walk" then
        return nil
    end
    state.status_phase = phase or state.status_phase or "active"
    state.status_last_event = last_event or state.status_last_event or "active"
    state.status_last_error = last_error or state.status_last_error
    if edge then
        state.status_current_x = edge.from_x or edge.x or state.status_current_x or state.start_x
        state.status_current_y = edge.from_y or edge.y or state.status_current_y or state.start_y
        state.status_current_dir = edge.dir or state.status_current_dir or "-"
    elseif not state.status_current_x then
        state.status_current_x = state.start_x
        state.status_current_y = state.start_y
        state.status_current_dir = "-"
    end

    local stats = build_sweep_stats(state, phase == "finished", last_error)
    local active = phase ~= "finished"
    local lines = {}
    lines[#lines + 1] = "active=" .. tostring(active)
    lines[#lines + 1] = string.format("run=%d", state.run_id or 0)
    lines[#lines + 1] = string.format("map=%02X", state.map_id or 0)
    lines[#lines + 1] = "method=" .. tostring(state.method or "normal_movement")
    lines[#lines + 1] = "teleport_used=" .. tostring(state.teleport_used == true)
    lines[#lines + 1] = "phase=" .. tostring(state.status_phase or "-")
    lines[#lines + 1] = string.format("cell=%d,%d", state.status_current_x or -1, state.status_current_y or -1)
    lines[#lines + 1] = "dir=" .. tostring(state.status_current_dir or "-")
    lines[#lines + 1] = string.format("visited=%d", stats.cells_visited or 0)
    lines[#lines + 1] = string.format("frontier=%d", stats.frontier or 0)
    lines[#lines + 1] = string.format("edges=%d", stats.edges_tested or 0)
    lines[#lines + 1] = string.format("passable=%d", stats.passable_edges or 0)
    lines[#lines + 1] = string.format("blocked=%d", stats.blocked_edges or 0)
    lines[#lines + 1] = string.format("confirmed_blockers=%d", stats.confirmed_blockers or 0)
    lines[#lines + 1] = string.format("unknown=%d", stats.unknown_edges or 0)
    lines[#lines + 1] = string.format("dynamic=%d", stats.dynamic_blockers or 0)
    lines[#lines + 1] = string.format("transitions=%d", stats.transitions or 0)
    lines[#lines + 1] = string.format("unsafe_aborts=%d", stats.unsafe_aborts or 0)
    lines[#lines + 1] = "last_event=" .. tostring(state.status_last_event or "-")
    lines[#lines + 1] = "last_error=" .. tostring(state.status_last_error or "")
    lines[#lines + 1] = string.format("updated_frame=%s", tostring(current_frame_count()))
    local path = sweep_status_file_path()
    local written = write_file(path, table.concat(lines, "\n") .. "\n",
        "SWEEP_WALK_STATUS_FILE_FAIL", state)
    if written then
        debug_tools.info(string.format(
            "SWEEP_WALK_STATUS_FILE run=%d map=0x%02X path=%s phase=%s active=%s",
            state.run_id or 0,
            state.map_id or 0,
            written,
            tostring(state.status_phase or "-"),
            tostring(active)))
    end
    return written
end

write_sweep_output_files = function(state, completed, reason, export_path)
    if not state or state.command_name ~= "sweep_walk" then
        return nil, nil
    end
    local base = sweep_output_base_path(state)
    local json_path = base .. ".json"
    local summary_path = base .. "_summary.txt"
    local summary = build_sweep_summary(state, completed, reason, export_path, json_path)
    local summary_written = write_file(summary_path, summary, "SWEEP_WALK_SUMMARY_FILE_FAIL", state)
    if summary_written then
        debug_tools.info(string.format(
            "SWEEP_WALK_SUMMARY_FILE run=%d map=0x%02X path=%s",
            state.run_id or 0,
            state.map_id or 0,
            summary_written))
    end
    local json = build_sweep_json(state, completed, reason, export_path, summary_path)
    local json_written = write_file(json_path, json, "SWEEP_WALK_JSON_FILE_FAIL", state)
    if json_written then
        debug_tools.info(string.format(
            "SWEEP_WALK_JSON_FILE run=%d map=0x%02X path=%s",
            state.run_id or 0,
            state.map_id or 0,
            json_written))
    end
    return json_written, summary_written
end

-- Body for the forward-declared write_export_file. Writes a per-map Lua
-- snippet file (overwrites on each run) with a comment header, paste-ready
-- MAP_PASSTHROUGH_CELLS / MAP_DIRECTIONAL_BLOCKS entries, and informational
-- comment blocks for stationary NPCs, closed doors, and unstable cells.
write_export_file = function(state, completed, reason)
    local map_id = state.map_id
    local report = state.report
    local passthroughs = M.get_passthrough_candidates(map_id)
    local directionals = M.get_directional_candidates(map_id)
    local pt_keys = sorted_keys(passthroughs)
    local dir_keys = sorted_keys(directionals)
    local npc_keys = sorted_keys(report.stationary_npcs or {})
    local door_keys = sorted_keys(report.door_frontiers or {})
    local unstable_keys = sorted_keys(report.unstable_cells or {})

    local path = export_file_path(map_id)
    local file, err = io.open(path, "w")
    if not file then
        debug_tools.error(string.format(
            "MAP_CRAWL_EXPORT_FILE_FAIL run=%d map=0x%02X path=%s error=%s",
            state.run_id or 0, map_id or 0, path, tostring(err)))
        return nil
    end

    local map_name = (type(maps.get_name) == "function") and maps.get_name(map_id) or "?"
    file:write("-- Map crawler export\n")
    file:write(string.format("-- map: 0x%02X (%s)\n", map_id, map_name))
    file:write(string.format("-- run: %d\n", state.run_id or 0))
    file:write(string.format("-- completed: %s\n", tostring(completed == true)))
    file:write(string.format("-- reason: %s\n", tostring(reason or "complete")))
    file:write(string.format("-- timestamp: %s\n", os.date("!%Y-%m-%dT%H:%M:%SZ")))
    file:write(string.format(
        "-- edges: %d  passthrough: %d  directional: %d  stationary_npc: %d  door_frontier: %d  unstable: %d\n",
        #(report.edges or {}),
        #pt_keys,
        #dir_keys,
        #npc_keys,
        #door_keys,
        #unstable_keys))
    file:write("--\n\n")

    file:write(string.format("-- MAP_PASSTHROUGH_CELLS additions (%d):\n", #pt_keys))
    if #pt_keys == 0 then
        file:write("--   (none)\n")
    else
        for _, key in ipairs(pt_keys) do
            file:write(string.format('["%s"] = true,\n', key))
        end
    end
    file:write("\n")

    file:write(string.format("-- MAP_DIRECTIONAL_BLOCKS additions (%d):\n", #dir_keys))
    if #dir_keys == 0 then
        file:write("--   (none)\n")
    else
        for _, key in ipairs(dir_keys) do
            local cell = directionals[key]
            file:write(string.format('["%s"] = %s,\n', key, format_direction_table(cell.dirs)))
        end
    end
    file:write("\n")

    if #npc_keys > 0 then
        file:write(string.format("-- Stationary NPC cells (%d, informational):\n", #npc_keys))
        for _, key in ipairs(npc_keys) do
            file:write(string.format('--   "%s" -> npc_slot %s\n', key, tostring(report.stationary_npcs[key])))
        end
        file:write("\n")
    end

    if #door_keys > 0 then
        file:write(string.format("-- Closed door frontiers (%d, informational):\n", #door_keys))
        for _, key in ipairs(door_keys) do
            local entry = report.door_frontiers[key]
            local door_x, door_y = "-", "-"
            if entry and entry.door_context then
                door_x = tostring(entry.door_context.door_x or entry.door_context.x or "-")
                door_y = tostring(entry.door_context.door_y or entry.door_context.y or "-")
            end
            file:write(string.format('--   "%s" -> door at (%s,%s)\n', key, door_x, door_y))
        end
        file:write("\n")
    end

    if #unstable_keys > 0 then
        file:write(string.format("-- Unstable cells excluded from candidates (%d):\n", #unstable_keys))
        for _, key in ipairs(unstable_keys) do
            local entry = report.unstable_cells[key]
            local reason_text = "unknown"
            if type(entry) == "table" then
                reason_text = tostring(entry.reason or "unknown")
            elseif entry ~= nil then
                reason_text = tostring(entry)
            end
            file:write(string.format('--   "%s" -> reason: %s\n', key, reason_text))
        end
        file:write("\n")
    end

    file:close()
    return path
end

-- Body for the forward-declared speak_finish_summary. Always emits a single
-- tolk message describing the outcome and salvaged candidate counts, except
-- for low-HP aborts (which already spoke their own message) and script
-- errors (where we may be in a half-broken state and don't want to claim
-- counts that could mislead).
speak_finish_summary = function(completed, reason, pt_count, dir_count)
    if reason == "low_hp" then
        return
    end
    if reason == "script_error" then
        tolk.output_interrupt("Map crawl errored. Check log.")
        return
    end
    local prefix
    if completed then
        prefix = "Map crawl complete"
    elseif reason == "manual_stop" then
        prefix = "Map crawl stopped"
    else
        prefix = "Map crawl ended: " .. tostring(reason or "unknown")
    end
    tolk.output_interrupt(string.format(
        "%s. %d passthrough, %d directional.",
        prefix,
        pt_count or 0,
        dir_count or 0))
end

function M.export_candidates(map_id)
    map_id = map_id or (crawler_state and crawler_state.map_id) or last_report_map_id or nav.get_position()
    local report = get_report(map_id)
    if not report then
        debug_tools.info(string.format("MAP_CRAWL_EXPORT map=0x%02X none", map_id or 0))
        return 0
    end
    local passthroughs = M.get_passthrough_candidates(map_id)
    local directionals = M.get_directional_candidates(map_id)
    local count = 0
    for _, key in ipairs(sorted_keys(passthroughs)) do
        debug_tools.info(string.format(
            "MAP_CRAWL_EXPORT_PASSTHROUGH map=0x%02X line='[\"%s\"] = true,'",
            map_id, key))
        count = count + 1
    end
    for _, key in ipairs(sorted_keys(directionals)) do
        local cell = directionals[key]
        debug_tools.info(string.format(
            "MAP_CRAWL_EXPORT_DIRECTIONAL map=0x%02X line='[\"%s\"] = %s,'",
            map_id, key, format_direction_table(cell.dirs)))
        count = count + 1
    end
    if count == 0 then
        debug_tools.info(string.format("MAP_CRAWL_EXPORT map=0x%02X no_review_candidates=true", map_id))
    end
    return count
end

function M.reset(map_id)
    map_id = map_id or (crawler_state and crawler_state.map_id) or nav.get_position()
    reports_by_map[map_id] = nil
    debug_tools.info(string.format("MAP_CRAWL_RESET map=0x%02X", map_id or 0))
end

local function safe_event_handler(fn, data)
    local ok, err = pcall(fn, data or {})
    if not ok then
        debug_tools.error("MAP_CRAWL_ABORT reason=script_error error=" .. tostring(err))
        finish_run(false, "script_error")
    end
end

-- Subscriptions are at module load. If the emulator hot-reloads this script
-- without resetting the Lua state, the event bus will end up with duplicate
-- handlers. That is harmless: each handler returns early when crawler_state
-- is nil or when the event's (from_x, from_y, dir) does not match the active
-- edge, so duplicates either no-op or repeat identical work.
event_bus.subscribe("route_step_completed", function(data)
    safe_event_handler(handle_step_complete, data)
end)

event_bus.subscribe("route_blocked", function(data)
    safe_event_handler(handle_blocked, data)
end)

return M
