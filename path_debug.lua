-- path_debug.lua
-- Pathfinding debug, diagnostics, and automated testing.
--
-- Provides structured logging of A* search internals, path tracing,
-- step-by-step execution, path validation, and repeatable test scenarios.
-- All functionality is gated behind debug_mode=true — zero overhead when
-- disabled.
--
-- Usage from dw_commands.sh:
--   ./dw_commands.sh debug_pathfind_to:3,3    # Pathfind with full search logging
--   ./dw_commands.sh trace_path               # Show last computed path
--   ./dw_commands.sh dump_search_log          # Show per-node A* visit/reject log
--   ./dw_commands.sh start_step_mode          # Load last path for stepping
--   ./dw_commands.sh step_path                # Execute one step
--   ./dw_commands.sh validate_path            # Walk path, check each step
--   ./dw_commands.sh test_path                # Run test scenarios for current map
--   ./dw_commands.sh dump_path_grid           # Tile grid with path overlay

local debug_tools = require "debug_tools"
local pathfinder  = require "pathfinder"
local map_reader  = require "map_reader"
local nav         = require "navigation"
local config      = require "config"

local M = {}

-- ============================================================
-- Module State (persists between commands within a session)
-- ============================================================
-- last_path: most recent path result — array of {x, y, direction}
-- last_path_info: metadata about the path request and outcome
-- last_search_log: per-node visit/reject entries from A* (only
--   populated when using debug_pathfind_to / debug_pathfind_adjacent)
-- step_buffer / step_index: for step-by-step execution mode
-- validate_state: state machine for walk-and-check validation

local last_path        = nil
local last_path_info   = nil
local last_search_log  = nil
local step_buffer      = nil
local step_index       = 0
local step_mode        = false
local validate_state   = nil

-- Direction name to FCEUX joypad key mapping.
-- Used by step_path and validate_tick.
local DIR_KEY_MAP = {north = "up", south = "down", west = "left", east = "right"}

-- Safety margin (frames) added to auto_step_timeout for validation waits.
-- The actual wait is auto_step_timeout + this margin, so it adapts to
-- the user's configured timeout.
local VALIDATE_MARGIN_FRAMES = 5

-- ============================================================
-- Section A: Callback Factory
-- ============================================================
-- build_find_path_opts(): Create an opts table with callbacks for
-- pathfinder.find_path(). The callbacks capture per-node data into
-- closure-local tables that can be retrieved after the search finishes.
--
-- Returns nil when debug_mode=false (zero overhead for production calls).

function M.build_find_path_opts()
    if not debug_tools.DEBUG_MODE then return nil end

    local log = {}
    local stats = {
        nodes_visited  = 0,
        nodes_rejected = 0,
        iterations     = 0,
        success        = false,
        path_length    = 0,
        reason         = nil,
    }

    local opts = {}

    -- on_visit(x, y, g_score, f_score): Called when a node is popped
    -- from the open set and expanded (neighbors explored).
    opts.on_visit = function(x, y, g, f)
        stats.nodes_visited = stats.nodes_visited + 1
        stats.iterations = stats.iterations + 1
        log[#log + 1] = string.format("VISIT (%d,%d) g=%d f=%d", x, y, g, f)
    end

    -- on_reject(x, y, reason): Called when a neighbor is NOT added
    -- to the open set. reason is one of:
    --   "already_closed"  — already fully explored
    --   "already_better"  — a shorter path to this node already exists
    --   "out_of_bounds"   — outside map dimensions
    --   "blocked_npc"     — NPC or runtime-blocked cell
    --   "not_walkable"    — tile type is not walkable (wall, water, etc.)
    opts.on_reject = function(x, y, reason)
        stats.nodes_rejected = stats.nodes_rejected + 1
        log[#log + 1] = string.format("REJECT (%d,%d) reason=%s", x, y, reason)
    end

    -- on_complete(final_stats): Called when the search finishes
    -- (success or failure). final_stats has: success, path_length,
    -- nodes_visited, reason (nil on success, "no_path" or "max_iterations").
    opts.on_complete = function(final_stats)
        if final_stats then
            for k, v in pairs(final_stats) do
                stats[k] = v
            end
        end
    end

    -- Internal accessors: retrieve accumulated data after find_path returns
    opts._get_log = function() return log end
    opts._get_stats = function() return stats end

    return opts
end

-- ============================================================
-- Section B: Path Storage
-- ============================================================
-- store_path(): Save the last computed path and its metadata.
-- Called from main.lua after any pathfind call so trace_path,
-- step_path, and validate_path can recall it.

function M.store_path(map_id, sx, sy, gx, gy, path, opts)
    last_path = path
    last_path_info = {
        map_id  = map_id,
        start_x = sx, start_y = sy,
        goal_x  = gx, goal_y  = gy,
        success = (path ~= nil and type(path) == "table" and #path > 0),
        stats   = opts and opts._get_stats and opts._get_stats() or nil,
    }
    last_search_log = opts and opts._get_log and opts._get_log() or nil
end

-- get_last_path(): Return stored path and info, or nil.
function M.get_last_path()
    return last_path, last_path_info
end

-- ============================================================
-- Section C: trace_path Command
-- ============================================================
-- Log the last computed path as:
--   1. Search stats (nodes visited, rejected, path length)
--   2. Coordinate sequence: (7,4)->(8,4)->(9,4)
--   3. Direction sequence: EAST, EAST, SOUTH
--   4. Per-step detail with tile types (at DEBUG level)

function M.trace_path()
    if not debug_tools.DEBUG_MODE then return end
    if not last_path_info then
        debug_tools.info("TRACE: no path stored. Run pathfind_to or debug_pathfind_to first.")
        return
    end

    local info = last_path_info
    debug_tools.info(string.format("TRACE: map=0x%02X start=(%d,%d) goal=(%d,%d) success=%s",
        info.map_id, info.start_x, info.start_y, info.goal_x, info.goal_y,
        tostring(info.success)))

    -- Search stats (only present from debug_pathfind_to calls)
    if info.stats then
        local s = info.stats
        debug_tools.info(string.format(
            "TRACE STATS: visited=%d rejected=%d iterations=%d path_length=%d reason=%s",
            s.nodes_visited or 0, s.nodes_rejected or 0,
            s.iterations or 0, s.path_length or 0,
            tostring(s.reason or "success")))
    end

    if not last_path or #last_path == 0 then
        debug_tools.info("TRACE: empty path (already at goal or no path found)")
        return
    end

    -- Coordinate sequence: (start)->(step1)->(step2)->...
    local coords = {}
    coords[1] = string.format("(%d,%d)", info.start_x, info.start_y)
    for _, step in ipairs(last_path) do
        coords[#coords + 1] = string.format("(%d,%d)", step.x, step.y)
    end
    debug_tools.info("TRACE COORDS: " .. table.concat(coords, "->"))

    -- Direction sequence: EAST, EAST, SOUTH
    local dirs = {}
    for _, step in ipairs(last_path) do
        dirs[#dirs + 1] = step.direction:upper()
    end
    debug_tools.info("TRACE DIRS: " .. table.concat(dirs, ", "))

    -- Per-step detail with tile types (DEBUG level — only visible at debug_log_level=DEBUG)
    for i, step in ipairs(last_path) do
        local tt = map_reader.get_tile_type(info.map_id, step.x, step.y)
        local wk = map_reader.is_walkable(info.map_id, step.x, step.y)
        debug_tools.debug(string.format("  step %d: (%d,%d) %s tile=0x%X walkable=%s",
            i, step.x, step.y, step.direction, tt or 0, tostring(wk)))
    end
end

-- ============================================================
-- Section D: dump_search_log Command
-- ============================================================
-- Output the per-node visit/reject log from the last instrumented
-- pathfind (debug_pathfind_to / debug_pathfind_adjacent).
-- This can be very verbose — hundreds of lines on large maps.
-- Separate from trace_path to avoid flooding.

function M.dump_search_log()
    if not debug_tools.DEBUG_MODE then return end
    if not last_search_log then
        debug_tools.info("SEARCH_LOG: no search log stored. Use debug_pathfind_to or debug_pathfind_adjacent first.")
        return
    end

    debug_tools.info(string.format("SEARCH_LOG: %d entries", #last_search_log))
    for _, line in ipairs(last_search_log) do
        debug_tools.debug(line)
    end
    debug_tools.info("SEARCH_LOG END")
end

-- ============================================================
-- Section E: Step-by-Step Execution
-- ============================================================
-- Load the last computed path into a step buffer, then execute
-- one step at a time via the step_path command. Each step is
-- logged with current position and expected destination.

-- start_step_mode(): Load last path into step buffer.
function M.start_step_mode()
    if not debug_tools.DEBUG_MODE then return end
    if validate_state then
        debug_tools.info("STEP_MODE: cannot start — validation is active. Use stop_validate first.")
        return
    end
    if not last_path or #last_path == 0 then
        debug_tools.info("STEP_MODE: no path to step through. Run a pathfind first.")
        return
    end
    step_buffer = last_path
    step_index = 0
    step_mode = true
    debug_tools.info(string.format("STEP_MODE: loaded %d steps. Use step_path to advance.", #step_buffer))
end

-- stop_step_mode(): Cancel step-by-step execution.
function M.stop_step_mode()
    if step_mode then
        debug_tools.info(string.format("STEP_MODE: stopped at step %d/%d",
            step_index, step_buffer and #step_buffer or 0))
    end
    step_buffer = nil
    step_index = 0
    step_mode = false
end

-- step_path(auto_step_module): Execute one step from the step buffer.
-- auto_step_module must have an inject_step(dir_key) function.
-- Returns true if a step was injected, false if done or no buffer.
function M.step_path(auto_step_module)
    if not debug_tools.DEBUG_MODE then return false end
    if not step_mode or not step_buffer then
        debug_tools.info("STEP_PATH: not in step mode. Use start_step_mode first.")
        return false
    end

    step_index = step_index + 1
    if step_index > #step_buffer then
        debug_tools.info("STEP_PATH: all steps completed")
        M.stop_step_mode()
        return false
    end

    local step = step_buffer[step_index]
    local dir_key = DIR_KEY_MAP[step.direction]

    local _, px, py = nav.get_position()
    debug_tools.info(string.format(
        "STEP_PATH [%d/%d]: at=(%d,%d) dir=%s expected_dest=(%d,%d)",
        step_index, #step_buffer, px, py, step.direction, step.x, step.y))

    if dir_key and auto_step_module and auto_step_module.inject_step then
        auto_step_module.inject_step(dir_key)
    else
        debug_tools.error("STEP_PATH: invalid direction '" .. tostring(step.direction) .. "' or missing auto_step module")
    end

    return true
end

-- is_step_mode(): Query whether step-by-step mode is active.
-- Used by main.lua to suspend auto_step.update() during stepping.
function M.is_step_mode()
    return step_mode
end

-- ============================================================
-- Section F: Path Validation State Machine
-- ============================================================
-- Walk the stored path automatically, comparing expected position
-- after each step to the player's actual position. Logs mismatches
-- immediately and provides a summary at the end.
--
-- Phases: next → inject → wait → check → next → ... → done
--
-- inject: call auto_step.inject_step(dir_key) for current step
-- wait: count down VALIDATE_WAIT_FRAMES for the step animation to finish
-- check: compare expected (step.x, step.y) vs actual (nav.get_position())
-- next: advance to next step or finish

-- validate_tick(): Advance the validation state machine one frame.
-- Called from M.tick(). Returns nil (no joypad injection needed —
-- we use auto_step.inject_step which handles joypad internally).
local function validate_tick()
    if not validate_state then return end
    local vs = validate_state

    if vs.phase == "next" then
        vs.index = vs.index + 1
        if vs.index > #vs.path then
            -- All steps done — report summary
            debug_tools.info(string.format(
                "VALIDATE COMPLETE: %d/%d steps OK, %d mismatches",
                vs.completed, #vs.path, #vs.mismatches))
            for _, m in ipairs(vs.mismatches) do
                debug_tools.info(string.format(
                    "  MISMATCH step %d: expected (%d,%d) actual (%d,%d)",
                    m.step, m.expected_x, m.expected_y, m.actual_x, m.actual_y))
            end
            validate_state = nil
            return
        end

        -- Inject the next step
        local step = vs.path[vs.index]
        local dir_key_map = {north = "up", south = "down", west = "left", east = "right"}
        local dir_key = dir_key_map[step.direction]

        local _, px, py = nav.get_position()
        debug_tools.debug(string.format(
            "VALIDATE step %d/%d: at=(%d,%d) dir=%s expect=(%d,%d)",
            vs.index, #vs.path, px, py, step.direction, step.x, step.y))

        if dir_key and vs.auto_step and vs.auto_step.inject_step then
            vs.auto_step.inject_step(dir_key)
        else
            debug_tools.error("VALIDATE: invalid direction or missing auto_step module at step " .. vs.index)
            validate_state = nil
            return
        end
        local timeout = tonumber(config.get("auto_step_timeout")) or 60
        vs.wait_frames = timeout + VALIDATE_MARGIN_FRAMES
        vs.phase = "wait"
        return
    end

    if vs.phase == "wait" then
        vs.wait_frames = vs.wait_frames - 1
        if vs.wait_frames <= 0 then
            vs.phase = "check"
        end
        return
    end

    if vs.phase == "check" then
        local step = vs.path[vs.index]
        local _, px, py = nav.get_position()

        if px == step.x and py == step.y then
            vs.completed = vs.completed + 1
            debug_tools.debug(string.format("VALIDATE step %d: OK at (%d,%d)", vs.index, px, py))
        else
            vs.mismatches[#vs.mismatches + 1] = {
                step       = vs.index,
                expected_x = step.x,
                expected_y = step.y,
                actual_x   = px,
                actual_y   = py,
            }
            debug_tools.info(string.format(
                "VALIDATE step %d: MISMATCH expected (%d,%d) actual (%d,%d)",
                vs.index, step.x, step.y, px, py))
        end
        vs.phase = "next"
        return
    end
end

-- start_validate(auto_step_module): Begin validation walk of stored path.
function M.start_validate(auto_step_module)
    if not debug_tools.DEBUG_MODE then return end
    if step_mode then
        debug_tools.info("VALIDATE: cannot start — step mode is active. Use stop_step_mode first.")
        return
    end
    if not last_path or #last_path == 0 then
        debug_tools.info("VALIDATE: no path to validate. Run a pathfind first.")
        return
    end

    validate_state = {
        path        = last_path,
        index       = 0,
        phase       = "next",
        wait_frames = 0,
        mismatches  = {},
        completed   = 0,
        auto_step   = auto_step_module,
    }
    debug_tools.info(string.format("VALIDATE: starting validation of %d-step path", #last_path))
end

-- stop_validate(): Cancel active validation.
function M.stop_validate()
    if validate_state then
        debug_tools.info(string.format(
            "VALIDATE: stopped at step %d/%d (%d mismatches so far)",
            validate_state.index, #validate_state.path, #validate_state.mismatches))
        validate_state = nil
    else
        debug_tools.info("VALIDATE: no validation in progress")
    end
end

-- is_validating(): Query whether validation walk is in progress.
-- Used by main.lua to suspend normal auto_step during validation.
function M.is_validating()
    return validate_state ~= nil
end

-- ============================================================
-- Section G: Test Scenarios
-- ============================================================
-- Map-specific test cases with known start/goal positions.
-- Each scenario runs pathfinding (NOT actual movement) and logs
-- the result with full search stats.
--
-- Scenarios are keyed by map_id. Each entry:
--   name:    unique test name
--   start_x, start_y: pathfind origin
--   goal_x, goal_y:   pathfind destination
--   adjacent: if true, use pathfind_to_adjacent (for NPCs/doors)

local TEST_SCENARIOS = {
    [0x04] = {  -- Tantegel Castle
        {name = "spawn_to_king",       start_x = 10, start_y = 12, goal_x = 3,  goal_y = 3,  adjacent = true},
        {name = "spawn_to_stairs",     start_x = 10, start_y = 12, goal_x = 17, goal_y = 24, adjacent = false},
        {name = "guard_to_merchant",   start_x = 6,  start_y = 4,  goal_x = 24, goal_y = 25, adjacent = true},
        {name = "north_to_south",      start_x = 10, start_y = 4,  goal_x = 10, goal_y = 27, adjacent = false},
        {name = "east_wing_to_west",   start_x = 24, start_y = 8,  goal_x = 3,  goal_y = 8,  adjacent = false},
    },
    [0x05] = {  -- Tantegel Castle Throne Room
        -- Start positions must be inside the throne room (y=1-6), north of the
        -- locked door at (4,7). Starting at y>=7 disconnects the start from the
        -- goal when the door is closed (default game state).
        {name = "room_center_to_north", start_x = 4, start_y = 5, goal_x = 4, goal_y = 1, adjacent = false},
        {name = "room_center_to_king",  start_x = 4, start_y = 6, goal_x = 4, goal_y = 3, adjacent = true},
    },
}

-- list_tests(): Log available test scenarios for current map.
function M.list_tests()
    if not debug_tools.DEBUG_MODE then return end
    local map_id = nav.get_position()
    local scenarios = TEST_SCENARIOS[map_id]
    if not scenarios then
        debug_tools.info(string.format("TEST: no test scenarios defined for map 0x%02X", map_id))
        return
    end
    debug_tools.info(string.format("TEST: %d scenario(s) for map 0x%02X:", #scenarios, map_id))
    for _, s in ipairs(scenarios) do
        debug_tools.info(string.format("  %s: (%d,%d)->(%d,%d) %s",
            s.name, s.start_x, s.start_y, s.goal_x, s.goal_y,
            s.adjacent and "adjacent" or "direct"))
    end
end

-- run_test(scenario_name, auto_step_module, blocking_fn):
-- Run a named test scenario, or all scenarios for the current map
-- if scenario_name is nil.
--
-- blocking_fn(map_id) should return the blocking table (NPC positions
-- + runtime blocks) — matches build_path_blocking() in main.lua.
function M.run_test(scenario_name, auto_step_module, blocking_fn)
    if not debug_tools.DEBUG_MODE then return end
    local map_id = nav.get_position()
    local scenarios = TEST_SCENARIOS[map_id]
    if not scenarios then
        debug_tools.info(string.format("TEST: no test scenarios for map 0x%02X", map_id))
        return
    end

    -- Select which scenarios to run
    local to_run = {}
    if scenario_name and scenario_name ~= "" then
        for _, s in ipairs(scenarios) do
            if s.name == scenario_name then
                to_run[1] = s
                break
            end
        end
        if #to_run == 0 then
            debug_tools.info("TEST: unknown scenario '" .. scenario_name .. "'")
            M.list_tests()
            return
        end
    else
        to_run = scenarios
    end

    debug_tools.info(string.format("TEST: running %d scenario(s) on map 0x%02X", #to_run, map_id))

    local pass_count = 0
    local fail_count = 0

    for _, scenario in ipairs(to_run) do
        local blocking = blocking_fn and blocking_fn(map_id) or {}
        local opts = M.build_find_path_opts()

        local result, face_dir, path
        if scenario.adjacent then
            result, face_dir, path = pathfinder.pathfind_to_adjacent(
                map_id, scenario.start_x, scenario.start_y,
                scenario.goal_x, scenario.goal_y, blocking, opts)
        else
            result, face_dir, path = pathfinder.pathfind_to(
                map_id, scenario.start_x, scenario.start_y,
                scenario.goal_x, scenario.goal_y, blocking, opts)
        end

        local stats = opts and opts._get_stats() or {}
        local path_len = path and #path or 0
        local ok = (result ~= "No path found" and path_len > 0)

        if ok then
            pass_count = pass_count + 1
        else
            fail_count = fail_count + 1
        end

        debug_tools.info(string.format(
            "TEST [%s]: %s -> %s visited=%d rejected=%d path=%d",
            scenario.name, ok and "PASS" or "FAIL", tostring(result),
            stats.nodes_visited or 0, stats.nodes_rejected or 0, path_len))

        -- Store last result so trace_path / dump_path_grid can inspect it
        M.store_path(map_id, scenario.start_x, scenario.start_y,
            scenario.goal_x, scenario.goal_y, path, opts)
    end

    debug_tools.info(string.format("TEST SUMMARY: %d passed, %d failed", pass_count, fail_count))
end

-- ============================================================
-- Section H: dump_path_grid Command
-- ============================================================
-- Overlay the stored path on the tile grid. Cell markers:
--   S = start position
--   G = goal position
--   N/S/E/W = path step (direction initial)
--   + = walkable tile (not on path)
--   - = not walkable tile
--   ? = unknown walkability

function M.dump_path_grid()
    if not debug_tools.DEBUG_MODE then return end
    if not last_path_info then
        debug_tools.info("PATH_GRID: no path stored. Run a pathfind first.")
        return
    end

    local map_id = last_path_info.map_id
    local w, h = map_reader.get_map_dimensions(map_id)
    if not w then
        debug_tools.error("PATH_GRID: no dimensions for map 0x" .. string.format("%02X", map_id))
        return
    end

    -- Build set of path cells for O(1) lookup.
    -- Value is the direction initial (N/S/E/W) for path steps.
    local path_cells = {}
    if last_path then
        for _, step in ipairs(last_path) do
            path_cells[step.x .. "," .. step.y] = step.direction:sub(1, 1):upper()
        end
    end
    -- Mark start and goal (overwrites if path passes through them)
    local si = last_path_info
    path_cells[si.start_x .. "," .. si.start_y] = "S"
    path_cells[si.goal_x .. "," .. si.goal_y] = "G"

    debug_tools.info(string.format("PATH_GRID map=0x%02X (%dx%d) S=(%d,%d) G=(%d,%d)",
        map_id, w, h, si.start_x, si.start_y, si.goal_x, si.goal_y))

    for y = 0, h - 1 do
        local row = string.format("y=%02d ", y)
        for x = 0, w - 1 do
            local cell_key = x .. "," .. y
            local tt = map_reader.get_tile_type(map_id, x, y)
            local tt_hex = string.format("%X", tt or 0)

            if path_cells[cell_key] then
                -- Path cell: show tile type + direction/marker
                row = row .. tt_hex .. path_cells[cell_key] .. " "
            else
                -- Non-path cell: show tile type + walkability
                local wk = map_reader.is_walkable(map_id, x, y)
                local flag = (wk == true) and "+" or (wk == nil and "?" or "-")
                row = row .. tt_hex .. flag .. " "
            end
        end
        debug_tools.info(row)
    end
    debug_tools.info("PATH_GRID END")
end

-- ============================================================
-- Section I: Per-Frame Tick
-- ============================================================
-- Called once per frame from main.lua. Drives the validation
-- state machine. No-op when debug_mode=false.

function M.tick()
    if not debug_tools.DEBUG_MODE then return end
    validate_tick()
end

return M
