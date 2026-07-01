-- debug_tools.lua
-- Debugging and automation framework for Dragon Warrior Accessibility Mod.
--
-- ALL public functions are near-zero-cost no-ops when DEBUG_MODE is false,
-- so this module is safe to leave required in release builds.
--
-- To enable:  set debug_mode=true  in dw_access.ini
-- To disable: set debug_mode=false in dw_access.ini  (default)
--
-- Log output:    dw_debug.log      (cleared on startup; appended each session)
-- Command input: dw_commands.txt   (read every ~1 second; cleared after processing)
--
-- Log entry format:
--   [FRAME:nnnnn][LEVEL][state] message
--
-- Supported commands (one per line in dw_commands.txt):
--   log_state            -- write a full game-state snapshot to the log
--   report_position      -- write effective map/x/y to the log
--   report_coords        -- write effective + raw coordinate bytes to the log
--   debug_seed_open_doors:X,Y;X,Y -- seed opened-door RAM slots for route tests
--   report_movement_state[:TAG] -- dump movement/camera-adjacent RAM bytes
--   toggle_debug         -- flip DEBUG_MODE on/off at runtime
--   simulate_input:UP    -- inject a one-frame D-pad or button press
--   simulate_input:UP,12 -- inject 12 consecutive frames of the same press
--   simulate_raw_input:UP -- inject a one-frame raw D-pad or button press
--   simulate_raw_input:UP,12 -- inject 12 consecutive raw frames (bypasses auto_step)
--   simulate_raw_sequence:RIGHT,40,0;LEFT,40,0 -- raw timed sequence, bypasses auto_step
--   simulate_input:DOWN
--   simulate_input:LEFT
--   simulate_input:RIGHT
--   simulate_input:A
--   simulate_input:B
--   simulate_input:START
--   simulate_input:SELECT
--   clear_input          -- inject a neutral joypad frame to clear stale held input
--   input_status[:TAG]   -- log current input.get(), joypad.read(1), and bridge state
--   trace_input[:FRAMES] -- log input.get(), joypad.read(1), and bridge changes
--   launcher_probe[:TAG] -- write a deterministic launcher readiness marker
--   dump_grid            -- dump tile type + walkability grid for current map
--   export_blocks        -- format all recorded blocked moves as MAP_BLOCKED_CELLS Lua entries
--   sweep_map            -- legacy unsafe teleport-backed sweep of current map
--   sweep_teleport_legacy -- explicit alias for the legacy teleport sweep
--   crawl_map_frontier   -- review-only frontier crawl for candidate map data
--   stop_sweep           -- cancel active sweep
--   Lines beginning with ; are treated as comments and ignored.

local M = {}

-- ============================================================
-- Dependencies
-- ============================================================
local config     = require "config"
local bridge_hotkeys = require "bridge_hotkeys"
local addr       = require "addresses"
local maps_m     = require "maps"
local map_reader = require "map_reader"

-- emulator_compat is loaded by main.lua before us; fall back to the global it
-- registers so we don't introduce a circular require. Uses rawget so missing
-- detection (e.g. running under a future emulator) leaves both flags false and
-- callers can fail safe.
local emulator_compat = rawget(_G, "DW_EMULATOR_COMPAT") or { is_fceux = false, is_bizhawk = false }

-- ============================================================
-- Configuration
-- ============================================================

-- Master switch. Controlled by dw_access.ini: debug_mode=true/false.
-- When false, every public function returns immediately with no work done.
M.DEBUG_MODE = (config.get("debug_mode") == "true")

-- Log level constants (public so callers can pass them to M.log).
M.ERROR = 1
M.INFO  = 2
M.DEBUG = 3

local LOG_LEVEL_STRS  = { [1]="ERROR", [2]="INFO", [3]="DEBUG" }

-- Map level name strings to integer values for config parsing.
local function parse_log_level(s)
    local map = { ERROR=1, INFO=2, DEBUG=3 }
    return s and map[s:upper()] or 3  -- default: DEBUG (log everything)
end

-- Current minimum level to write. Messages below this level are dropped.
-- Controlled by dw_access.ini: debug_log_level=ERROR|INFO|DEBUG
local current_log_level = parse_log_level(config.get("debug_log_level"))

local function config_bool(key, fallback)
    local value = config.get(key)
    if value == nil then
        return fallback
    end
    value = tostring(value):lower()
    if value == "true" or value == "1" or value == "yes" or value == "on" then
        return true
    end
    if value == "false" or value == "0" or value == "no" or value == "off" then
        return false
    end
    return fallback
end

local function legacy_block_log_enabled()
    return config_bool("auto_step_record_debug_blocks", false)
end

-- ============================================================
-- File Paths
-- ============================================================
-- Derive the script directory from this file's source path so all
-- output files land next to the Lua scripts, wherever the mod lives.
local _src       = debug.getinfo(1, "S").source
local script_dir = _src:match("@?(.*[\\/])") or ""

local function default_processing_file(command_file)
    local base, ext = tostring(command_file or ""):match("^(.*)(%.[^%.\\/]+)$")
    if base then
        return base .. ".processing" .. ext
    end
    return tostring(command_file or "dw_commands") .. ".processing"
end

local LOG_FILE    = rawget(_G, "DW_DEBUG_LOG_FILE_OVERRIDE") or (script_dir .. "dw_debug.log")
local CMD_FILE    = rawget(_G, "DW_COMMAND_FILE_OVERRIDE") or (script_dir .. "dw_commands.txt")
local CMD_PROCESSING_FILE = rawget(_G, "DW_COMMAND_PROCESSING_FILE_OVERRIDE") or default_processing_file(CMD_FILE)
local KEYBOARD_BRIDGE_FILE = script_dir .. "dw_keyboard_input.txt"
-- Optional legacy record of engine-blocked moves. This is disabled by default
-- because noisy movement/probe collisions should not become persistent map
-- evidence. Explicit sweep/export debugging can opt back in via config.
local BLOCKS_FILE = script_dir .. "dw_blocks.log"

-- ============================================================
-- Internal State
-- ============================================================
local log_buffer       = {}   -- Lines queued before next disk flush
local LOG_FLUSH_FRAMES = 60   -- Flush to disk every 60 frames (~1 sec at 60fps)
local CMD_CHECK_FRAMES = 60   -- Check command file every 60 frames

local pending_input  = nil    -- Joypad table to apply on next frame, or nil
local pending_input_hold = nil  -- {buttons=table, frames_remaining=n}, or nil
local pending_input_release = false -- Clear stale joypad.set state after debug-owned input.
local pending_input_release_raw = false -- Keep raw debug-input release invisible to auto_step.
local pending_input_sequence = nil -- Timed debug-owned input script, one step at a time.
local input_trace = nil     -- Per-frame input trace state for keyboard/joypad diagnostics.
local stuck_alt_frames = 0  -- Consecutive frames where LeftAlt appears stuck and joy1 is idle.
local stuck_alt_warned = false
local STUCK_ALT_WARN_FRAMES = 120
local last_player_stat_integrity_warning = nil
local player_stat_integrity_state = nil
local player_stat_frameadvance_before_sample = nil
local last_player_stat_transition_dump_frame = nil
local PLAYER_STAT_TRACE_MAX = 180
local recent_player_stat_trace = {}
local keyboard_bridge_active = false
local external_keyboard_bridge_active = false
local external_stale_alt_ignored_active = false
local external_keyboard_bridge_missing_logged = false
-- Content cache for the keyboard_bridge.ps1 sidecar's output file. The sidecar
-- only rewrites the file when key state changes, so the same bytes show up on
-- the vast majority of frames. Caching the parsed bridge table avoids the
-- gmatch + table allocation each frame; we still read the file (cheap, ~30B)
-- to detect the rare state changes within one frame.
local external_bridge_last_line = nil
local external_bridge_cached_table = nil
local current_frame  = 0      -- Set each tick; used in log entry prefix
local current_state  = "unknown"  -- Set each tick; used in log entry prefix

-- Custom commands registered by main.lua via M.register_command().
-- Maps command name -> function(arg), where arg is the text after ':' or nil.
local custom_commands = {}

-- ============================================================
-- Block Detection State
-- ============================================================
-- blocked_entries: set of "0xMM:x,y:dir" keys for all known engine-blocked
-- moves. Loaded from dw_blocks.log at startup so the database survives
-- across sessions. New discoveries are added via M.record_block().
local blocked_entries = {}

-- ============================================================
-- Map Sweep State Machine
-- ============================================================
-- The sweep command (sweep_map) teleports the player to every nominally-
-- walkable tile on the current map, probes all 4 directions via joypad
-- injection, and records which moves the engine rejects. This produces a
-- complete MAP_BLOCKED_CELLS override table without requiring manual
-- exploration. sweep_tick() advances one frame at a time inside tick().
--
-- sweep == nil means no sweep is active.
local sweep = nil

-- Forward declaration so M.tick (defined before sweep_tick's body) can
-- reference it. In Lua 5.1, a local isn't in scope until its declaration,
-- so without this, the sweep_tick() call inside M.tick would resolve as a
-- global lookup (nil) and error on every frame when debug_mode=true.
local sweep_tick

-- Forward declaration for the same reason: process_command (line ~316) calls
-- persist_sweep_blocks from the stop_sweep branch, but the body is defined
-- later in the sweep section.
local persist_sweep_blocks

-- Forward declaration: release NPC freeze that sweep_map acquired automatically.
-- Uses a late require to avoid circular dependency (route_manager requires debug_tools).
local sweep_unfreeze_npcs

-- Direction metadata used by both the sweep and export_blocks.
local DIR_META = {
    { key="up",    dx=0,  dy=-1 },
    { key="down",  dx=0,  dy=1  },
    { key="left",  dx=-1, dy=0  },
    { key="right", dx=1,  dy=0  },
}
-- Reverse lookup: direction string → delta
local DIR_DELTA = {}
for _, d in ipairs(DIR_META) do DIR_DELTA[d.key] = d end

-- ============================================================
-- Startup: open / clear log file
-- ============================================================
-- We clear the log at startup (not append across sessions) so each run
-- produces a clean file that's easy to hand to external tools.
-- When debug is OFF we never touch the disk at all.
if M.DEBUG_MODE then
    local f = io.open(LOG_FILE, "w")
    if f then
        f:write("=== Dragon Warrior Debug Log ===\n")
        f:write(string.format("Started: %s\n", os.date("%Y-%m-%d %H:%M:%S")))
        f:write("================================\n\n")
        f:close()
    end

    if legacy_block_log_enabled() then
        -- Load previously recorded block entries from dw_blocks.log so we don't
        -- re-announce or re-persist discoveries from earlier sessions.
        local bf = io.open(BLOCKS_FILE, "r")
        if bf then
            for line in bf:lines() do
                local t = line:match("^%s*(.-)%s*$")
                -- Lines starting with '#' are comments (e.g. header lines written
                -- by export_blocks). Plain entries look like "0x04:7,5:up".
                if t ~= "" and t:sub(1,1) ~= "#" then
                    blocked_entries[t] = true
                end
            end
            bf:close()
        end
    end
end

-- ============================================================
-- Logging
-- ============================================================

-- log(level, message): Buffer a log entry for later disk flush.
-- level: M.ERROR / M.INFO / M.DEBUG
-- message: any string; will be prefixed with frame, level, and state.
function M.log(level, message)
    if not M.DEBUG_MODE then return end
    if level > current_log_level then return end
    local entry = string.format("[FRAME:%05d][%s][%s] %s",
        current_frame,
        LOG_LEVEL_STRS[level] or "?",
        current_state,
        tostring(message))
    log_buffer[#log_buffer + 1] = entry
end

-- Convenience wrappers so callers don't need to pass the level constant.
function M.error(msg) M.log(M.ERROR, msg) end
function M.info(msg)  M.log(M.INFO,  msg) end
function M.debug(msg) M.log(M.DEBUG, msg) end

-- flush_log(): Write buffered lines to disk and clear the buffer.
-- Called automatically every LOG_FLUSH_FRAMES frames by tick().
local function flush_log()
    if #log_buffer == 0 then return end
    local f = io.open(LOG_FILE, "a")
    if f then
        for _, line in ipairs(log_buffer) do
            f:write(line .. "\n")
        end
        f:close()
    end
    log_buffer = {}
end

function M.flush()
    flush_log()
end

local function trace_teleport_tick(label)
    local qol = rawget(_G, "DW_QOL_STATE")
    local guard = qol and qol.teleport_state_guard
    if not M.DEBUG_MODE
       or not guard
       or (guard.frames or 0) <= 0 then
        return
    end
    M.info(string.format(
        "TELEPORT_TICK_%s map=0x%02X landing=(%d,%d) frames_left=%d reason=%s",
        tostring(label),
        guard.map_id or -1,
        guard.x or -1,
        guard.y or -1,
        guard.frames or 0,
        tostring(guard.reason or "teleport")))
    flush_log()
end

-- ============================================================
-- State Snapshot
-- ============================================================

local function format_ram_range(first_addr, last_addr)
    local bytes = {}
    for a = first_addr, last_addr do
        bytes[#bytes + 1] = string.format("%02X", memory.readbyte(a))
    end
    return table.concat(bytes, " ")
end

local function read_ram_range_bytes(first_addr, last_addr)
    local bytes = {}
    for a = first_addr, last_addr do
        bytes[#bytes + 1] = memory.readbyte(a)
    end
    return bytes
end

local function format_byte_table(bytes)
    local parts = {}
    for i = 1, #bytes do
        parts[#parts + 1] = string.format("%02X", bytes[i])
    end
    return table.concat(parts, " ")
end

local function capture_player_stat_trace_sample(frame_override, state_override)
    local stat_bytes = read_ram_range_bytes(addr.EXPERIENCE_LO, addr.FLAGS_CF)
    return {
        frame = frame_override or current_frame,
        state = state_override or current_state,
        map_id = memory.readbyte(addr.MAP_ID),
        x = memory.readbyte(addr.PLAYER_X),
        y = memory.readbyte(addr.PLAYER_Y),
        hp = memory.readbyte(addr.CURRENT_HP),
        max_hp = memory.readbyte(addr.MAX_HP),
        mp = memory.readbyte(addr.CURRENT_MP),
        max_mp = memory.readbyte(addr.MAX_MP),
        level = memory.readbyte(addr.LEVEL),
        strength = memory.readbyte(addr.STRENGTH),
        agility = memory.readbyte(addr.AGILITY),
        attack = memory.readbyte(addr.ATTACK),
        defense = memory.readbyte(addr.DEFENSE),
        spells = memory.readbyte(addr.SPELLS),
        flags_cf = memory.readbyte(addr.FLAGS_CF),
        enemy_hp = memory.readbyte(addr.ENEMY_HP),
        stat_bytes = stat_bytes,
        stat_ram = format_byte_table(stat_bytes),
    }
end

local function push_player_stat_trace_sample(sample)
    recent_player_stat_trace[#recent_player_stat_trace + 1] = sample
    if #recent_player_stat_trace > PLAYER_STAT_TRACE_MAX then
        table.remove(recent_player_stat_trace, 1)
    end
end

local function describe_trace_changes(prev_bytes, current_bytes)
    if not prev_bytes or not current_bytes then
        return "initial"
    end
    local changed = {}
    for i = 1, math.min(#prev_bytes, #current_bytes) do
        if prev_bytes[i] ~= current_bytes[i] then
            changed[#changed + 1] = string.format("%02X", addr.EXPERIENCE_LO + i - 1)
        end
    end
    if #changed == 0 then
        return "none"
    end
    return table.concat(changed, ",")
end

local function has_known_spell_bits(spells, flags_cf)
    return (tonumber(spells) or 0) ~= 0 or ((tonumber(flags_cf) or 0) % 4) ~= 0
end

local function build_player_stat_integrity_report(context, sample)
    local map_id   = sample and sample.map_id or memory.readbyte(addr.MAP_ID)
    local px       = sample and sample.x or memory.readbyte(addr.PLAYER_X)
    local py       = sample and sample.y or memory.readbyte(addr.PLAYER_Y)
    local hp       = sample and sample.hp or memory.readbyte(addr.CURRENT_HP)
    local mp       = sample and sample.mp or memory.readbyte(addr.CURRENT_MP)
    local level    = sample and sample.level or memory.readbyte(addr.LEVEL)
    local strength = sample and sample.strength or memory.readbyte(addr.STRENGTH)
    local agility  = sample and sample.agility or memory.readbyte(addr.AGILITY)
    local max_hp   = sample and sample.max_hp or memory.readbyte(addr.MAX_HP)
    local max_mp   = sample and sample.max_mp or memory.readbyte(addr.MAX_MP)
    local attack   = sample and sample.attack or memory.readbyte(addr.ATTACK)
    local defense  = sample and sample.defense or memory.readbyte(addr.DEFENSE)
    local spells   = sample and sample.spells or memory.readbyte(addr.SPELLS)
    local flags_cf = sample and sample.flags_cf or memory.readbyte(addr.FLAGS_CF)
    local stat_ram = sample and sample.stat_ram or format_ram_range(addr.EXPERIENCE_LO, addr.FLAGS_CF)
    local issues = {}

    if level >= 3 and not has_known_spell_bits(spells, flags_cf) then
        issues[#issues + 1] = "missing_spells_for_level"
    end
    if level >= 3 and max_mp == 0 then
        issues[#issues + 1] = "zero_max_mp_for_spell_level"
    end
    if level >= 10 and max_hp <= 20 then
        issues[#issues + 1] = "implausible_max_hp_for_level"
    end
    if level >= 10 and strength <= 8 and agility <= 8 then
        issues[#issues + 1] = "implausible_primary_stats_for_level"
    end
    if hp > max_hp then
        issues[#issues + 1] = "current_hp_exceeds_max"
    end
    if mp > max_mp then
        issues[#issues + 1] = "current_mp_exceeds_max"
    end

    if #issues == 0 then
        return nil
    end

    return {
        context = tostring(context or "unspecified"),
        map_id = map_id,
        x = px,
        y = py,
        hp = hp,
        max_hp = max_hp,
        mp = mp,
        max_mp = max_mp,
        level = level,
        strength = strength,
        agility = agility,
        attack = attack,
        defense = defense,
        spells = spells,
        flags_cf = flags_cf,
        stat_ram = stat_ram,
        issues = issues,
    }
end

function M.check_player_stat_integrity(context)
    if not M.DEBUG_MODE then return true end

    local report = build_player_stat_integrity_report(context)
    if not report then
        last_player_stat_integrity_warning = nil
        return true
    end

    local issue_text = table.concat(report.issues, ",")
    local warning_key = string.format(
        "%s|0x%02X|%d,%d|%d|%s",
        report.context,
        report.map_id or 0,
        report.x or -1,
        report.y or -1,
        report.level or -1,
        report.stat_ram or "")
    if warning_key ~= last_player_stat_integrity_warning then
        M.info(string.format(
            "PLAYER_STAT_INTEGRITY_WARNING context=%s map=0x%02X pos=(%d,%d) level=%d hp=%d/%d mp=%d/%d stats=STR=0x%02X AGI=0x%02X ATK=0x%02X DEF=0x%02X spells=CE=0x%02X CF=0x%02X issues=%s stat_ram=%s",
            report.context,
            report.map_id or 0,
            report.x or -1,
            report.y or -1,
            report.level or -1,
            report.hp or 0,
            report.max_hp or 0,
            report.mp or 0,
            report.max_mp or 0,
            report.strength or 0,
            report.agility or 0,
            report.attack or 0,
            report.defense or 0,
            report.spells or 0,
            report.flags_cf or 0,
            issue_text,
            report.stat_ram or ""))
        last_player_stat_integrity_warning = warning_key
    end
    return false, report
end

function M.dump_recent_player_stat_trace(context, current_sample)
    if not M.DEBUG_MODE then return end

    local entries = {}
    for i = 1, #recent_player_stat_trace do
        entries[#entries + 1] = {
            origin = "history",
            sample = recent_player_stat_trace[i],
        }
    end
    if current_sample then
        entries[#entries + 1] = {
            origin = "current",
            sample = current_sample,
        }
    end

    M.info(string.format(
        "PLAYER_STAT_TRACE_BEGIN context=%s count=%d",
        tostring(context or "unspecified"),
        #entries))

    local previous = nil
    for i = 1, #entries do
        local entry = entries[i]
        local sample = entry.sample
        M.info(string.format(
            "PLAYER_STAT_TRACE origin=%s frame=%d state=%s map=0x%02X pos=(%d,%d) hp=%d/%d mp=%d/%d level=%d enemy_hp=%d changed=%s stat_ram=%s",
            tostring(entry.origin),
            sample.frame or 0,
            tostring(sample.state or "?"),
            sample.map_id or 0,
            sample.x or -1,
            sample.y or -1,
            sample.hp or 0,
            sample.max_hp or 0,
            sample.mp or 0,
            sample.max_mp or 0,
            sample.level or 0,
            sample.enemy_hp or 0,
            describe_trace_changes(previous and previous.stat_bytes or nil, sample.stat_bytes),
            tostring(sample.stat_ram or "")))
        previous = sample
    end

    M.info(string.format(
        "PLAYER_STAT_TRACE_END context=%s",
        tostring(context or "unspecified")))
end

local function log_player_stat_integrity_transition(from_state, to_state, report)
    M.info(string.format(
        "PLAYER_STAT_INTEGRITY_TRANSITION from=%s to=%s map=0x%02X pos=(%d,%d) level=%d hp=%d/%d mp=%d/%d stats=STR=0x%02X AGI=0x%02X ATK=0x%02X DEF=0x%02X spells=CE=0x%02X CF=0x%02X issues=%s stat_ram=%s",
        tostring(from_state or "unknown"),
        tostring(to_state or "unknown"),
        report.map_id or 0,
        report.x or -1,
        report.y or -1,
        report.level or -1,
        report.hp or 0,
        report.max_hp or 0,
        report.mp or 0,
        report.max_mp or 0,
        report.strength or 0,
        report.agility or 0,
        report.attack or 0,
        report.defense or 0,
        report.spells or 0,
        report.flags_cf or 0,
        table.concat(report.issues or {}, ","),
        report.stat_ram or ""))
end

local function monitor_player_stat_integrity(sample)
    if not M.DEBUG_MODE then return end
    local state = tostring(current_state or "")
    if state ~= "field" and state ~= "battle" then
        return
    end

    local report = build_player_stat_integrity_report("tick")
    if report then
        if player_stat_integrity_state ~= "bad" then
            log_player_stat_integrity_transition(player_stat_integrity_state or "unknown", "bad", report)
            M.dump_recent_player_stat_trace("stat_transition", sample)
            last_player_stat_transition_dump_frame = current_frame
        end
        player_stat_integrity_state = "bad"
        return
    end

    if player_stat_integrity_state == "bad" then
        M.info(string.format(
            "PLAYER_STAT_INTEGRITY_TRANSITION from=bad to=clean map=0x%02X pos=(%d,%d) stat_ram=%s",
            sample.map_id or 0,
            sample.x or -1,
            sample.y or -1,
            sample.stat_ram or ""))
    end
    player_stat_integrity_state = "clean"
end

local function gameplay_state_for_stat_boundary()
    local state = tostring(current_state or "")
    return state == "field" or state == "battle"
end

function M.before_frameadvance()
    if not M.DEBUG_MODE then return end
    if not gameplay_state_for_stat_boundary() then
        player_stat_frameadvance_before_sample = nil
        return
    end
    player_stat_frameadvance_before_sample = capture_player_stat_trace_sample(
        current_frame,
        tostring(current_state or "unknown"))
end

function M.after_frameadvance()
    if not M.DEBUG_MODE then return end
    local before = player_stat_frameadvance_before_sample
    player_stat_frameadvance_before_sample = nil
    if not before or not gameplay_state_for_stat_boundary() then
        return
    end

    local after = capture_player_stat_trace_sample(
        (current_frame or 0) + 1,
        tostring(current_state or "unknown") .. ":after_frameadvance")
    local before_report = build_player_stat_integrity_report("before_frameadvance", before)
    local after_report = build_player_stat_integrity_report("after_frameadvance", after)
    local before_state = before_report and "bad" or "clean"
    local after_state = after_report and "bad" or "clean"
    if before_state == after_state then
        return
    end

    local report = after_report or before_report or {}
    M.info(string.format(
        "PLAYER_STAT_FRAMEADVANCE_TRANSITION from=%s to=%s pre_frame=%d post_frame=%d state=%s before_map=0x%02X before_pos=(%d,%d) after_map=0x%02X after_pos=(%d,%d) before_hp=%d/%d before_mp=%d/%d before_level=%d after_hp=%d/%d after_mp=%d/%d after_level=%d changed=%s issues=%s before_stat_ram=%s after_stat_ram=%s",
        before_state,
        after_state,
        before.frame or current_frame or 0,
        after.frame or ((current_frame or 0) + 1),
        tostring(current_state or "unknown"),
        before.map_id or 0,
        before.x or -1,
        before.y or -1,
        after.map_id or 0,
        after.x or -1,
        after.y or -1,
        before.hp or 0,
        before.max_hp or 0,
        before.mp or 0,
        before.max_mp or 0,
        before.level or 0,
        after.hp or 0,
        after.max_hp or 0,
        after.mp or 0,
        after.max_mp or 0,
        after.level or 0,
        describe_trace_changes(before.stat_bytes, after.stat_bytes),
        table.concat(report.issues or {}, ","),
        tostring(before.stat_ram or ""),
        tostring(after.stat_ram or "")))
end

-- build_snapshot(): Capture all relevant game state into a string block.
-- Reads RAM directly. Returns a multi-line human-readable string.
-- Format is KEY: VALUE so it's easy to parse with simple text tools.
local function build_snapshot()
    local map_id   = memory.readbyte(addr.MAP_ID)
    local terrain  = memory.readbyte(addr.TERRAIN_OFFSET)
    local px
    local py
    px = memory.readbyte(addr.PLAYER_X)
    py = memory.readbyte(addr.PLAYER_Y)
    local hp       = memory.readbyte(addr.CURRENT_HP)
    local max_hp   = memory.readbyte(addr.MAX_HP)
    local mp       = memory.readbyte(addr.CURRENT_MP)
    local max_mp   = memory.readbyte(addr.MAX_MP)
    local level    = memory.readbyte(addr.LEVEL)
    local strength = memory.readbyte(addr.STRENGTH)
    local agility  = memory.readbyte(addr.AGILITY)
    local attack   = memory.readbyte(addr.ATTACK)
    local defense  = memory.readbyte(addr.DEFENSE)
    local gold     = memory.readbyte(addr.GOLD_LO) + memory.readbyte(addr.GOLD_HI) * 256
    local exp      = memory.readbyte(addr.EXPERIENCE_LO) + memory.readbyte(addr.EXPERIENCE_HI) * 256
    local keys     = memory.readbyte(addr.KEYS)
    local herbs    = memory.readbyte(addr.HERBS)
    local enemy_hp = memory.readbyte(addr.ENEMY_HP)
    local d8       = memory.readbyte(addr.MENU_CURSOR_X)
    local d9       = memory.readbyte(addr.MENU_CURSOR_Y)
    local spells   = memory.readbyte(addr.SPELLS)
    local flags_cf = memory.readbyte(addr.FLAGS_CF)
    local combat_flags = memory.readbyte(addr.COMBAT_FLAGS)
    local quest_flags  = memory.readbyte(addr.QUEST_FLAGS)
    local map_name = maps_m.get_name(map_id)

    local lines = {
        "--- State Snapshot ---",
        string.format("frame:     %d",          current_frame),
        string.format("state:     %s",          current_state),
        string.format("map_id:    0x%02X (%s)", map_id, map_name),
        string.format("pos:       x=%d, y=%d",  px, py),
        string.format("raw_pos:   player=(%d,%d) overworld=(%d,%d)",
            memory.readbyte(addr.PLAYER_X),
            memory.readbyte(addr.PLAYER_Y),
            memory.readbyte(addr.OVERWORLD_X),
            memory.readbyte(addr.OVERWORLD_Y)),
        string.format("hp:        %d / %d",     hp, max_hp),
        string.format("mp:        %d / %d",     mp, max_mp),
        string.format("level:     %d",          level),
        string.format("stats:     STR=0x%02X AGI=0x%02X ATK=0x%02X DEF=0x%02X",
            strength, agility, attack, defense),
        string.format("gold:      %d",          gold),
        string.format("exp:       %d",          exp),
        string.format("keys:      %d",          keys),
        string.format("herbs:     %d",          herbs),
        string.format("enemy_hp:  %d",          enemy_hp),
        string.format("cursor:    D8=%d D9=%d", d8, d9),
        string.format("stat_ram:  BA-CF=%s", format_ram_range(addr.EXPERIENCE_LO, addr.FLAGS_CF)),
        string.format("spells:    CE=0x%02X CF=0x%02X", spells, flags_cf),
        string.format("flags:     combat=0x%02X quest=0x%02X", combat_flags, quest_flags),
        string.format("terrain:   0x%02X",      terrain),
        "----------------------",
    }
    return table.concat(lines, "\n")
end

-- snapshot(): Log a full state snapshot at INFO level.
-- Each line gets its own log entry so the frame/state prefix appears on every line.
function M.snapshot()
    if not M.DEBUG_MODE then return end
    local snap = build_snapshot()
    for line in snap:gmatch("[^\n]+") do
        M.info(line)
    end
    M.check_player_stat_integrity("snapshot")
end

-- ============================================================
-- Event Hooks
-- ============================================================
-- Call these from main.lua at the indicated event points.
-- All are no-ops when DEBUG_MODE is false — negligible overhead.

-- Call when the command menu opens (inside check_command_menu when confirmed).
function M.on_menu_open()
    if not M.DEBUG_MODE then return end
    M.debug("EVENT: command menu opened")
end

-- Call when the command menu closes.
function M.on_menu_close()
    if not M.DEBUG_MODE then return end
    M.debug("EVENT: command menu closed")
end

-- Call when new dialogue text is announced.
-- text: the dialogue string being spoken
function M.on_dialogue(text_str)
    if not M.DEBUG_MODE then return end
    M.debug("EVENT: dialogue: " .. (text_str or ""))
end

-- Call on STATE_BATTLE entry transition in main.lua.
function M.on_battle_start()
    if not M.DEBUG_MODE then return end
    if build_player_stat_integrity_report("battle_start") then
        if last_player_stat_transition_dump_frame
           and (current_frame - last_player_stat_transition_dump_frame) <= PLAYER_STAT_TRACE_MAX then
            M.info(string.format(
                "PLAYER_STAT_TRACE_SKIPPED context=battle_start reason=recent_transition_dump transition_frame=%d",
                last_player_stat_transition_dump_frame))
        else
            M.dump_recent_player_stat_trace("battle_start", capture_player_stat_trace_sample())
        end
    end
    M.info("EVENT: battle started")
    M.snapshot()  -- Auto-snapshot on battle start so enemy type etc. are captured
end

-- Call inside check_map_change() when changes.map_changed is true.
-- new_id: the new map ID (read from RAM after nav.check_for_changes updates it)
function M.on_map_change(new_id)
    if not M.DEBUG_MODE then return end
    local new_name = new_id and maps_m.get_name(new_id) or "?"
    M.info(string.format("EVENT: map change -> 0x%02X (%s)", new_id or 0, new_name))
    M.check_player_stat_integrity("map_change")
end

-- ============================================================
-- Command File Processing
-- ============================================================

-- Button name strings (from command file) mapped to joypad.set() key names.
-- FCEUX joypad.set() accepts lowercase keys for directions, uppercase A/B.
local BUTTON_MAP = {
    UP     = "up",
    DOWN   = "down",
    LEFT   = "left",
    RIGHT  = "right",
    A      = "A",
    B      = "B",
    START  = "start",
    SELECT = "select",
}

local JOYPAD_BUTTONS = {"up", "down", "left", "right", "A", "B", "select", "start"}

local function full_joypad_state(buttons)
    local state = {}
    for _, name in ipairs(JOYPAD_BUTTONS) do
        state[name] = false
    end
    for name, pressed in pairs(buttons or {}) do
        state[name] = pressed
    end
    return state
end

local function neutral_raw_joypad_state()
    return full_joypad_state({_raw = true})
end

local function parse_button_command_args(arg_text)
    local btn_str, frames_str = tostring(arg_text or ""):match("^%s*([^,]+)%s*,?%s*(.-)%s*$")
    btn_str = btn_str and btn_str:upper() or ""
    local btn_key = BUTTON_MAP[btn_str]
    if not btn_key then
        return nil, nil, nil
    end

    local frames = 1
    if frames_str and frames_str ~= "" then
        if not frames_str:match("^%d+$") then
            return btn_key, btn_str, nil, "invalid frame count '" .. frames_str .. "' (must be a positive integer)"
        end
        frames = tonumber(frames_str)
        if not frames or frames < 1 then
            return btn_key, btn_str, nil, "frame count must be >= 1"
        end
    end

    return btn_key, btn_str, frames
end

local function parse_input_sequence(arg_text, force_raw)
    local sequence = {}
    for part in tostring(arg_text or ""):gmatch("[^;]+") do
        local btn_str, frames_str, wait_str =
            part:match("^%s*([^,]+)%s*,%s*(%d+)%s*,?%s*(%d*)%s*$")
        btn_str = btn_str and btn_str:upper() or ""
        local raw_step = force_raw == true
        if btn_str:sub(1, 4) == "RAW_" then
            raw_step = true
            btn_str = btn_str:sub(5)
        end
        local btn_key = BUTTON_MAP[btn_str]
        if not btn_key then
            return nil, "unknown button '" .. tostring(btn_str) .. "'"
        end
        local frames = tonumber(frames_str)
        local wait_frames = tonumber(wait_str) or 0
        if not frames or frames < 1 then
            return nil, "invalid frame count for " .. btn_str
        end
        if wait_frames < 0 then
            return nil, "invalid wait count for " .. btn_str
        end
        local buttons = full_joypad_state({ [btn_key] = true })
        if raw_step then
            buttons._raw = true
        end
        sequence[#sequence + 1] = {
            buttons = buttons,
            frames = frames,
            wait_after = wait_frames,
            label = (raw_step and "RAW_" or "") .. btn_str,
        }
    end
    if #sequence == 0 then
        return nil, "empty sequence"
    end
    return sequence
end

local function queue_input_sequence(sequence)
    pending_input = nil
    pending_input_hold = nil
    pending_input_release = false
    pending_input_release_raw = false
    pending_input_sequence = {
        steps = sequence,
        index = 1,
        frames_remaining = 0,
        wait_remaining = 0,
        active_buttons = nil,
        release_raw = false,
        wait_raw = false,
    }
    M.debug("Queued input sequence steps=" .. tostring(#sequence))
end

local function input_sequence_tick()
    local seq = pending_input_sequence
    if not seq then
        return nil
    end

    if seq.wait_remaining and seq.wait_remaining > 0 then
        seq.wait_remaining = seq.wait_remaining - 1
        local neutral = full_joypad_state({})
        if seq.wait_raw then
            neutral._raw = true
        end
        return neutral
    end

    if not seq.active_buttons then
        local step = seq.steps[seq.index]
        if not step then
            local release_raw = seq.release_raw == true
            M.debug(string.format(
                "INPUT_SEQUENCE_DONE steps=%d release_raw=%s",
                #seq.steps,
                tostring(release_raw)))
            pending_input_sequence = nil
            local neutral = full_joypad_state({})
            if release_raw then
                neutral._raw = true
            end
            return neutral
        end
        seq.active_buttons = step.buttons
        seq.frames_remaining = step.frames
        seq.wait_after = step.wait_after or 0
        seq.wait_raw = step.buttons and step.buttons._raw == true
        seq.release_raw = false
        M.debug(string.format(
            "INPUT_SEQUENCE step=%d/%d button=%s frames=%d wait_after=%d",
            seq.index,
            #seq.steps,
            tostring(step.label),
            seq.frames_remaining,
            seq.wait_after))
        seq.index = seq.index + 1
    end

    local buttons = seq.active_buttons
    seq.frames_remaining = seq.frames_remaining - 1
    if seq.frames_remaining <= 0 then
        seq.release_raw = buttons and buttons._raw == true
        seq.active_buttons = nil
        seq.wait_remaining = seq.wait_after
    end
    return buttons
end

local function queue_pending_input(buttons, frames, description)
    pending_input = nil
    pending_input_hold = nil
    pending_input_release = false
    pending_input_release_raw = false
    pending_input_sequence = nil

    if frames and frames > 1 then
        pending_input_hold = {
            buttons = buttons,
            frames_remaining = frames,
        }
    else
        pending_input = buttons
    end

    if description then
        if frames and frames > 1 then
            M.debug(string.format("Queued %s for %d frames", description, frames))
        else
            M.debug("Queued " .. description)
        end
    end
end

local function clamp_trace_frames(value)
    local frames = tonumber(value)
    if not frames then
        return 300
    end
    frames = math.floor(frames)
    if frames < 1 then
        return 1
    end
    if frames > 1800 then
        return 1800
    end
    return frames
end

local function format_pressed_keys(keys)
    local names = {}
    for name, pressed in pairs(keys or {}) do
        if pressed == true then
            names[#names + 1] = tostring(name)
        end
    end
    table.sort(names)
    if #names == 0 then
        return "-"
    end
    return table.concat(names, "+")
end

local function format_joy_buttons(joy)
    local names = {}
    local order = {"up", "down", "left", "right", "A", "B", "select", "start"}
    for _, name in ipairs(order) do
        if joy and joy[name] then
            names[#names + 1] = name
        end
    end
    if #names == 0 then
        return "-"
    end
    return table.concat(names, "+")
end

local function has_joy_buttons(joy)
    local order = {"up", "down", "left", "right", "A", "B", "select", "start"}
    for _, name in ipairs(order) do
        if joy and joy[name] then
            return true
        end
    end
    return false
end

local function is_left_alt_pressed(keys)
    if not keys then
        return false
    end
    return keys.LeftAlt
        or keys.LEFTALT
        or keys.leftalt
        or keys["Left Alt"]
        or keys["LEFT ALT"]
        or keys["left alt"]
        or false
end

local function is_key_pressed(keys, ...)
    if not keys then
        return false
    end
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        if keys[name] then
            return true
        end
    end
    return false
end

local function build_keyboard_bridge_input(frame)
    -- The stuck-Alt heuristic addresses an FCEUX-specific quirk where the
    -- menu bar steals input focus and the joypad goes silent until Alt is
    -- released. BizHawk doesn't have this issue, and a BizHawk player who
    -- holds Alt (e.g. Alt+Tab to consult a guide) would otherwise have the
    -- bridge synthesize phantom inputs from F/D/S/arrows on return.
    if not emulator_compat.is_fceux then
        return nil
    end
    if config.get("enable_keyboard_input_bridge") == "false" then
        return nil
    end

    local keys = input.get()
    local joy = joypad.read(1)
    if not is_left_alt_pressed(keys) or has_joy_buttons(joy) then
        local was_active = keyboard_bridge_active
        if keyboard_bridge_active then
            M.info(string.format(
                "INPUT_BRIDGE_CLEAR frame=%d keys=%s joy1=%s",
                frame or current_frame,
                format_pressed_keys(keys),
                format_joy_buttons(joy)
            ))
        end
        keyboard_bridge_active = false
        if was_active then
            return neutral_raw_joypad_state()
        end
        return nil
    end

    local bridge = full_joypad_state({})
    if is_key_pressed(keys, "Up", "UP", "up") then bridge.up = true end
    if is_key_pressed(keys, "Down", "DOWN", "down") then bridge.down = true end
    if is_key_pressed(keys, "Left", "LEFT", "left") then bridge.left = true end
    if is_key_pressed(keys, "Right", "RIGHT", "right") then bridge.right = true end
    if is_key_pressed(keys, "F", "f") then bridge.A = true end
    if is_key_pressed(keys, "D", "d") then bridge.B = true end
    -- Do not translate Return here: Alt+Enter is an FCEUX/windowing shortcut
    -- that can latch in SDL and become repeated Start. The external sidecar
    -- bridge still maps an intentional Enter press to "start" ahead of this.
    if is_key_pressed(keys, "S", "s") then bridge.select = true end

    if not has_joy_buttons(bridge) then
        local was_active = keyboard_bridge_active
        if keyboard_bridge_active then
            M.info(string.format(
                "INPUT_BRIDGE_CLEAR frame=%d keys=%s joy1=%s",
                frame or current_frame,
                format_pressed_keys(keys),
                format_joy_buttons(joy)
            ))
        end
        keyboard_bridge_active = false
        if was_active then
            return neutral_raw_joypad_state()
        end
        return nil
    end

    bridge._raw = true
    if not keyboard_bridge_active then
        M.info(string.format(
            "INPUT_BRIDGE_ACTIVE frame=%d keys=%s buttons=%s native_joy1=%s reason=stuck_alt_idle_joypad",
            frame or current_frame,
            format_pressed_keys(keys),
            format_joy_buttons(bridge),
            format_joy_buttons(joy)
        ))
    end
    keyboard_bridge_active = true
    return bridge
end

local function shallow_copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

local function parse_external_keyboard_bridge()
    local f = io.open(KEYBOARD_BRIDGE_FILE, "r")
    if not f then
        if not external_keyboard_bridge_missing_logged then
            M.info("INPUT_EXTERNAL_BRIDGE_MISSING path=" .. KEYBOARD_BRIDGE_FILE)
            external_keyboard_bridge_missing_logged = true
        end
        external_bridge_last_line = nil
        external_bridge_cached_table = nil
        return nil
    end

    external_keyboard_bridge_missing_logged = false
    local line = f:read("*l") or ""
    f:close()
    line = line:match("^%s*(.-)%s*$") or ""

    -- Cache hit: sidecar hasn't rewritten the file. Return a copy so callers
    -- can mutate fields like `_raw` without corrupting the cached state.
    if line == external_bridge_last_line and external_bridge_cached_table then
        return shallow_copy(external_bridge_cached_table)
    end

    local bridge = full_joypad_state({})
    if line ~= "" and line ~= "-" then
        for part in line:gmatch("[^,]+") do
            local button = part:match("^%s*(.-)%s*$")
            if button == "up" or button == "down" or button == "left" or button == "right"
               or button == "A" or button == "B" or button == "start" or button == "select" then
                bridge[button] = true
            end
        end
    end

    external_bridge_last_line = line
    external_bridge_cached_table = bridge
    return shallow_copy(bridge)
end

local function read_keyboard_bridge_line()
    local f = io.open(KEYBOARD_BRIDGE_FILE, "r")
    if not f then
        return "(missing)"
    end
    local line = f:read("*l") or ""
    f:close()
    line = line:match("^%s*(.-)%s*$") or ""
    if line == "" then
        return "(empty)"
    end
    return line
end

local function build_external_keyboard_bridge_input(frame)
    -- External bridge feeds the FCEUX-only keyboard_bridge.ps1 sidecar, which
    -- watches the OS keyboard while FCEUX's menu has focus. BizHawk reads the
    -- keyboard directly through its own input system, so the sidecar is not
    -- relevant there.
    if not emulator_compat.is_fceux then
        return nil
    end
    if config.get("enable_keyboard_input_bridge") == "false" then
        return nil
    end

    local keys = input.get()
    local joy = joypad.read(1)
    local fceux_stale = is_left_alt_pressed(keys)
    local bridge = parse_external_keyboard_bridge()
    if not bridge then
        return nil
    end

    local bridge_active = has_joy_buttons(bridge)
    if not fceux_stale and not bridge_active then
        local was_active = external_keyboard_bridge_active
        if external_keyboard_bridge_active then
            M.info(string.format(
                "INPUT_EXTERNAL_BRIDGE_CLEAR frame=%d reason=fceux_input_recovered keys=%s joy1=%s",
                frame or current_frame,
                format_pressed_keys(keys),
                format_joy_buttons(joy)
            ))
        end
        external_keyboard_bridge_active = false
        external_stale_alt_ignored_active = false
        if was_active then
            return neutral_raw_joypad_state()
        end
        return nil
    end

    if fceux_stale and not bridge_active then
        -- Alt+Tab can leave FCEUX/SDL reporting LeftAlt forever even though
        -- the physical key is up. Treat LeftAlt-only idle state as diagnostic
        -- noise, not synthetic joypad input, so the bug stays benign during
        -- normal Windows window-switching.
        local was_active = external_keyboard_bridge_active
        if external_keyboard_bridge_active then
            M.info(string.format(
                "INPUT_EXTERNAL_BRIDGE_CLEAR frame=%d reason=fceux_stale_alt_ignored keys=%s joy1=%s",
                frame or current_frame,
                format_pressed_keys(keys),
                format_joy_buttons(joy)
            ))
        end
        external_keyboard_bridge_active = false
        if not external_stale_alt_ignored_active then
            M.info(string.format(
                "INPUT_STALE_ALT_IGNORED frame=%d keys=%s joy1=%s bridge=%s reason=fceux_alt_tab_latch",
                frame or current_frame,
                format_pressed_keys(keys),
                format_joy_buttons(joy),
                format_joy_buttons(bridge)
            ))
        end
        external_stale_alt_ignored_active = true
        if was_active then
            return neutral_raw_joypad_state()
        end
        return nil
    else
        bridge._raw = true
    end
    external_stale_alt_ignored_active = false
    if not external_keyboard_bridge_active then
        M.info(string.format(
            "INPUT_EXTERNAL_BRIDGE_ACTIVE frame=%d keys=%s native_joy1=%s bridge=%s reason=fceux_stale_keyboard_state",
            frame or current_frame,
            format_pressed_keys(keys),
            format_joy_buttons(joy),
            format_joy_buttons(bridge)
        ))
    elseif bridge_active then
        M.debug(string.format(
            "INPUT_EXTERNAL_BRIDGE_APPLY frame=%d keys=%s native_joy1=%s bridge=%s",
            frame or current_frame,
            format_pressed_keys(keys),
            format_joy_buttons(joy),
            format_joy_buttons(bridge)
        ))
    end
    external_keyboard_bridge_active = true
    return bridge
end

local function log_input_status(tag)
    local keys = input.get()
    local joy = joypad.read(1)
    local bridge_line = read_keyboard_bridge_line()
    local mod_bridge_line = bridge_hotkeys.read_state_line()
    M.info(string.format(
        "INPUT_STATUS tag=%s keys=%s joy1=%s bridge=%s mod_bridge=%s left_alt=%s",
        tostring(tag or "manual"),
        format_pressed_keys(keys),
        format_joy_buttons(joy),
        bridge_line,
        mod_bridge_line,
        tostring(is_left_alt_pressed(keys))
    ))
end

local function update_stuck_alt_watch(frame)
    -- FCEUX-only: BizHawk doesn't lose joypad focus on Alt, so the watch
    -- has nothing to detect there.
    if not emulator_compat.is_fceux then
        return
    end
    local keys = input.get()
    local joy = joypad.read(1)
    local left_alt = is_left_alt_pressed(keys)
    local joy_idle = not has_joy_buttons(joy)
    local bridge_active = false
    if left_alt and joy_idle then
        local bridge = parse_external_keyboard_bridge()
        bridge_active = bridge and has_joy_buttons(bridge) or false
    end

    if left_alt and joy_idle and not bridge_active then
        stuck_alt_frames = stuck_alt_frames + 1
        if not stuck_alt_warned and stuck_alt_frames >= STUCK_ALT_WARN_FRAMES then
            stuck_alt_warned = true
            M.info(string.format(
                "INPUT_STUCK_ALT frame=%d frames=%d keys=%s joy1=%s recovery=stale_alt_ignored_or_run_recover_fceux_input benign=true",
                frame or current_frame,
                stuck_alt_frames,
                format_pressed_keys(keys),
                format_joy_buttons(joy)
            ))
        end
        return
    end

    if stuck_alt_warned then
        M.info(string.format(
            "INPUT_STUCK_ALT_CLEAR frame=%d frames=%d keys=%s joy1=%s",
            frame or current_frame,
            stuck_alt_frames,
            format_pressed_keys(keys),
            format_joy_buttons(joy)
        ))
    end
    stuck_alt_frames = 0
    stuck_alt_warned = false
end

local function update_input_trace(frame)
    if not input_trace then
        return
    end

    local keys = format_pressed_keys(input.get())
    local joy = format_joy_buttons(joypad.read(1))
    local mod_bridge = bridge_hotkeys.read_state_line()
    local changed = (keys ~= input_trace.last_keys)
        or (joy ~= input_trace.last_joy)
        or (mod_bridge ~= input_trace.last_mod_bridge)
    local heartbeat = (input_trace.frames_remaining % 60 == 0)

    if changed or heartbeat then
        M.info(string.format(
            "INPUT_TRACE frame=%d remaining=%d keys=%s joy1=%s mod_bridge=%s reason=%s",
            frame or current_frame,
            input_trace.frames_remaining,
            keys,
            joy,
            mod_bridge,
            changed and "changed" or "heartbeat"
        ))
        input_trace.last_keys = keys
        input_trace.last_joy = joy
        input_trace.last_mod_bridge = mod_bridge
        input_trace.samples = input_trace.samples + 1
    end

    input_trace.frames_remaining = input_trace.frames_remaining - 1
    if input_trace.frames_remaining <= 0 then
        M.info(string.format("INPUT_TRACE_END frame=%d samples=%d",
            frame or current_frame,
            input_trace.samples or 0))
        input_trace = nil
    end
end

-- process_command(cmd): Execute one trimmed command string.
local function process_command(cmd)
    if cmd == "" then return end

    local command_start_clock = os.clock()
    M.debug("CMD: " .. cmd)
    -- Flush the command marker before running the handler. If a diagnostic
    -- command wedges or crashes the script, the last attempted command is still
    -- visible in dw_debug.log instead of being stranded in the in-memory buffer.
    flush_log()

    if cmd == "log_state" then
        -- Write a full state snapshot to the log immediately.
        M.snapshot()

    elseif cmd == "report_position" then
        -- Write just the map and coordinates (lightweight alternative to log_state).
        local map_id = memory.readbyte(addr.MAP_ID)
        local terrain = memory.readbyte(addr.TERRAIN_OFFSET)
        local px, py
        px = memory.readbyte(addr.PLAYER_X)
        py = memory.readbyte(addr.PLAYER_Y)
        M.info(string.format("POSITION: map=0x%02X(%s) x=%d y=%d",
            map_id, maps_m.get_name(map_id), px, py))

    elseif cmd == "report_door_state" then
        local entries = {}
        for i = 0, addr.DOOR_ARRAY_MAX - 1 do
            local dx = memory.readbyte(addr.DOOR_X_POS_START + i * addr.DOOR_ARRAY_STRIDE)
            local dy = memory.readbyte(addr.DOOR_Y_POS_START + i * addr.DOOR_ARRAY_STRIDE)
            entries[#entries + 1] = string.format("%d=(%d,%d)", i, dx, dy)
        end
        M.info(string.format(
            "DOOR_STATE keys=%d slots=%s",
            memory.readbyte(addr.KEYS),
            table.concat(entries, " ")))

    elseif cmd:sub(1, 21) == "debug_seed_open_doors" then
        local arg = cmd:match("^debug_seed_open_doors:%s*(.-)%s*$")
        if not arg or arg == "" then
            M.error("debug_seed_open_doors usage: debug_seed_open_doors:X,Y[;X,Y...] or debug_seed_open_doors:clear")
        else
            local normalized_arg = arg:match("^%s*(.-)%s*$"):lower()
            local doors = {}
            local bad_part = nil
            if normalized_arg ~= "clear" and normalized_arg ~= "none" then
                for part in arg:gmatch("[^;]+") do
                    local x_s, y_s = part:match("^%s*(%d+)%s*,%s*(%d+)%s*$")
                    local x, y = tonumber(x_s), tonumber(y_s)
                    if not x or not y then
                        bad_part = part
                        break
                    end
                    doors[#doors + 1] = {x = x, y = y}
                end
            end

            if bad_part then
                M.error("debug_seed_open_doors: invalid coordinate '" .. tostring(bad_part) .. "'")
            elseif #doors > addr.DOOR_ARRAY_MAX then
                M.error(string.format(
                    "debug_seed_open_doors: too many doors (%d > %d)",
                    #doors,
                    addr.DOOR_ARRAY_MAX))
            else
                for i = 0, addr.DOOR_ARRAY_MAX - 1 do
                    local door = doors[i + 1]
                    memory.writebyte(addr.DOOR_X_POS_START + i * addr.DOOR_ARRAY_STRIDE, door and door.x or 0)
                    memory.writebyte(addr.DOOR_Y_POS_START + i * addr.DOOR_ARRAY_STRIDE, door and door.y or 0)
                end

                local entries = {}
                for i, door in ipairs(doors) do
                    entries[#entries + 1] = string.format("%d=(%d,%d)", i - 1, door.x, door.y)
                end
                M.info("DEBUG_SEED_OPEN_DOORS slots=" .. (#entries > 0 and table.concat(entries, " ") or "none"))
            end
        end

    elseif cmd == "report_coords" then
        -- Write both effective coordinates and the raw interior/overworld RAM bytes.
        local map_id = memory.readbyte(addr.MAP_ID)
        local terrain = memory.readbyte(addr.TERRAIN_OFFSET)
        local player_x = memory.readbyte(addr.PLAYER_X)
        local player_y = memory.readbyte(addr.PLAYER_Y)
        local overworld_x = memory.readbyte(addr.OVERWORLD_X)
        local overworld_y = memory.readbyte(addr.OVERWORLD_Y)
        local effective_x = player_x
        local effective_y = player_y
        M.info(string.format(
            "COORDS: map=0x%02X(%s) terrain=0x%02X effective=(%d,%d) player=(%d,%d) overworld=(%d,%d) raw003C_0043=%02X %02X %02X %02X %02X %02X %02X %02X",
            map_id,
            maps_m.get_name(map_id),
            terrain,
            effective_x,
            effective_y,
            player_x,
            player_y,
            overworld_x,
            overworld_y,
            memory.readbyte(0x003C),
            memory.readbyte(0x003D),
            memory.readbyte(0x003E),
            memory.readbyte(0x003F),
            memory.readbyte(0x0040),
            memory.readbyte(0x0041),
            memory.readbyte(0x0042),
            memory.readbyte(0x0043)
        ))

    elseif cmd == "report_movement_state" or cmd:sub(1, 22) == "report_movement_state:" then
        -- Dump compact RAM windows around known/suspect movement state bytes.
        -- This is intentionally text-first and machine-readable for comparing
        -- pass/block cases around stale teleport/camera/subtile state.
        local tag = cmd:match("^report_movement_state:(.+)$") or "-"
        local map_id = memory.readbyte(addr.MAP_ID)
        local terrain = memory.readbyte(addr.TERRAIN_OFFSET)
        local player_x = memory.readbyte(addr.PLAYER_X)
        local player_y = memory.readbyte(addr.PLAYER_Y)
        local overworld_x = memory.readbyte(addr.OVERWORLD_X)
        local overworld_y = memory.readbyte(addr.OVERWORLD_Y)
        local ppu_ctrl = addr.PPU_CTRL and memory.readbyte(addr.PPU_CTRL) or 0
        local scroll_x = addr.SCROLL_X and memory.readbyte(addr.SCROLL_X) or 0
        local scroll_y = addr.SCROLL_Y and memory.readbyte(addr.SCROLL_Y) or 0
        local buttons = addr.BUTTONS_PRESSED and memory.readbyte(addr.BUTTONS_PRESSED) or 0
        M.info(string.format(
            "MOVEMENT_STATE tag=%s map=0x%02X(%s) terrain=0x%02X player=(%d,%d) overworld=(%d,%d) ppu_ctrl=0x%02X scroll_x=0x%02X scroll_y=0x%02X buttons=0x%02X ram0000_001F=%s ram0030_004F=%s ram0090_0093=%s",
            tag,
            map_id,
            maps_m.get_name(map_id),
            terrain,
            player_x,
            player_y,
            overworld_x,
            overworld_y,
            ppu_ctrl,
            scroll_x,
            scroll_y,
            buttons,
            format_ram_range(0x0000, 0x001F),
            format_ram_range(0x0030, 0x004F),
            format_ram_range(0x0090, 0x0093)
        ))

    elseif cmd == "toggle_debug" then
        -- Flip DEBUG_MODE at runtime. Useful for activating debug mid-session
        -- without reloading the script. Note: the log file is NOT re-cleared
        -- when toggling back on — new entries append to whatever was written before.
        M.DEBUG_MODE = not M.DEBUG_MODE
        -- Always write this line (bypass the DEBUG_MODE guard) so the toggle
        -- is visible in the log even when turning it back off.
        local entry = string.format("[FRAME:%05d][INFO][%s] DEBUG_MODE toggled to: %s",
            current_frame, current_state, tostring(M.DEBUG_MODE))
        log_buffer[#log_buffer + 1] = entry
        flush_log()

    elseif cmd:sub(1, 15) == "simulate_input:" then
        -- Queue a one-frame joypad injection. tick() applies it before frameadvance.
        -- Only one input is queued at a time; the last simulate_input in the file wins.
        -- Optional trailing ",N" holds the same press for N consecutive frames.
        local btn_key, btn_str, frames, err = parse_button_command_args(cmd:sub(16))
        if btn_key and frames then
            queue_pending_input(full_joypad_state({ [btn_key] = true }), frames, "joypad: " .. btn_str)
        elseif err then
            M.error("simulate_input: " .. err .. ". Usage: simulate_input:BTN or simulate_input:BTN,FRAMES")
        else
            M.error("simulate_input: unknown button. Valid buttons: UP DOWN LEFT RIGHT A B START SELECT")
        end

    elseif cmd:sub(1, 19) == "simulate_raw_input:" then
        -- Queue a raw joypad injection that bypasses auto_step.
        -- Optional trailing ",N" holds the same raw press for N frames.
        local btn_key, btn_str, frames, err = parse_button_command_args(cmd:sub(20))
        if btn_key and frames then
            queue_pending_input(full_joypad_state({ [btn_key] = true, _raw = true }), frames, "raw joypad: " .. btn_str)
        elseif err then
            M.error("simulate_raw_input: " .. err .. ". Usage: simulate_raw_input:BTN or simulate_raw_input:BTN,FRAMES")
        else
            M.error("simulate_raw_input: unknown button. Valid buttons: UP DOWN LEFT RIGHT A B START SELECT")
        end

    elseif cmd:sub(1, 18) == "simulate_sequence:" then
        -- Queue a timed sequence: BTN,FRAMES,WAIT;BTN,FRAMES,WAIT;...
        -- WAIT emits neutral input frames before the next step.
        local sequence, err = parse_input_sequence(cmd:sub(19))
        if sequence then
            queue_input_sequence(sequence)
        else
            M.error("simulate_sequence: " .. tostring(err)
                .. ". Usage: simulate_sequence:A,8,40;RIGHT,12,30;DOWN,12,30;A,4,0")
        end

    elseif cmd:sub(1, 22) == "simulate_raw_sequence:" then
        -- Queue a timed raw sequence that bypasses auto_step for every step.
        local sequence, err = parse_input_sequence(cmd:sub(23), true)
        if sequence then
            queue_input_sequence(sequence)
        else
            M.error("simulate_raw_sequence: " .. tostring(err)
                .. ". Usage: simulate_raw_sequence:RIGHT,40,0;LEFT,40,0")
        end

    elseif cmd == "clear_input" or cmd == "neutral_input" then
        -- Explicit recovery hook for stale joypad.set state after a failed probe
        -- or external script reload. tick() emits the neutral frame immediately.
        queue_pending_input(full_joypad_state({}), 1, "neutral joypad")

    elseif cmd == "input_status" or cmd:sub(1, 13) == "input_status:" then
        local tag = cmd:match("^input_status:(.+)$") or "manual"
        log_input_status(tag)

    elseif cmd == "trace_input" or cmd:sub(1, 12) == "trace_input:" then
        local arg = cmd:match("^trace_input:(.+)$")
        local frames = clamp_trace_frames(arg)
        input_trace = {
            frames_remaining = frames,
            last_keys = nil,
            last_joy = nil,
            last_mod_bridge = nil,
            samples = 0,
        }
        M.info(string.format("INPUT_TRACE_START frames=%d", frames))

    elseif cmd == "dump_grid" then
        -- Dump the tile type and walkability for every cell in the current map.
        -- Output format: one row per line, each cell shown as TT/W where TT=tile
        -- type (hex) and W=walkability: '+' walkable, '-' not, '?' out-of-bounds.
        -- Engine-blocked cells (MAP_BLOCKED_CELLS) show as '-' even if tile is
        -- nominally walkable. Use this to identify discrepancies.
        local map_id = memory.readbyte(addr.MAP_ID)
        local w, h   = map_reader.get_map_dimensions(map_id)
        if not w or not h then
            M.error("dump_grid: no dimensions for map 0x" .. string.format("%02X", map_id))
        else
            M.info(string.format("GRID map=0x%02X (%s) size=%dx%d", map_id, maps_m.get_name(map_id), w, h))
            for y = 0, h - 1 do
                local row = string.format("y=%02d ", y)
                for x = 0, w - 1 do
                    local tt = map_reader.get_tile_type(map_id, x, y)
                    local wk = map_reader.is_walkable(map_id, x, y)
                    local flag = (wk == true) and "+" or "-"
                    if tt == nil then flag = "?" end
                    row = row .. string.format("%X%s ", tt or 0, flag)
                end
                M.info(row)
            end
            M.info("GRID END")
        end

    elseif cmd == "reload_config" then
        -- Re-read dw_access.ini at runtime. Useful after editing settings without
        -- restarting the script. Some settings still depend on a callback from
        -- other modules to refresh any cached copies after config.load().
        config.load()
        current_log_level = parse_log_level(config.get("debug_log_level"))
        M.DEBUG_MODE = (config.get("debug_mode") == "true")
        local reload_hook = custom_commands["__config_reloaded"]
        if reload_hook then
            local ok, err = pcall(reload_hook)
            if not ok then
                M.error("reload_config hook failed: " .. tostring(err))
            end
        end
        M.info("Config reloaded from dw_access.ini")

    elseif cmd == "launcher_probe" or cmd:sub(1, 15) == "launcher_probe:" then
        -- Lightweight launcher readiness marker. This avoids touching the speech
        -- backend so launch verification can focus on command polling alone.
        local tag = "ready"
        if cmd:sub(1, 15) == "launcher_probe:" then
            tag = cmd:sub(16):match("^%s*(.-)%s*$")
            if tag == "" then
                tag = "ready"
            end
        end
        M.info("LAUNCHER_PROBE: " .. tag)

    elseif cmd == "export_blocks" then
        -- Format all recorded block entries (from dw_blocks.log + current session)
        -- as MAP_BLOCKED_CELLS Lua table entries ready to paste into map_reader.lua.
        --
        -- For each blocked move "from (x,y) in dir", we derive the destination
        -- cell (x+dx, y+dy) and emit it as ["dest_x,dest_y"] = true. Multiple
        -- source directions that point to the same destination cell are collapsed
        -- into one entry with a comment listing the blocked approaches.
        local by_map = {}
        for key, _ in pairs(blocked_entries) do
            local map_hex, sx, sy, dir_s =
                key:match("^(0x%x+):(%d+),(%d+):(%a+)$")
            if map_hex and DIR_DELTA[dir_s] then
                sx, sy = tonumber(sx), tonumber(sy)
                local d = DIR_DELTA[dir_s]
                local cell = string.format("%d,%d", sx + d.dx, sy + d.dy)
                if not by_map[map_hex] then by_map[map_hex] = {} end
                local entry = by_map[map_hex][cell]
                if not entry then
                    by_map[map_hex][cell] = { dirs = {dir_s} }
                else
                    entry.dirs[#entry.dirs + 1] = dir_s
                end
            end
        end

        -- Count total unique destination cells across all maps.
        local total = 0
        for _, cells in pairs(by_map) do
            for _ in pairs(cells) do total = total + 1 end
        end

        if total == 0 then
            M.info("export_blocks: no blocks recorded yet. Play with debug_mode=true to accumulate trusted runtime data. Legacy sweep_map output is review-only.")
        else
            M.info(string.format("export_blocks: %d unique destination cells across %d maps",
                total, (function() local n=0; for _ in pairs(by_map) do n=n+1 end; return n end)()))
            M.info("=== MAP_BLOCKED_CELLS (paste into map_reader.lua) ===")
            for map_hex, cells in pairs(by_map) do
                M.info(string.format("    [%s] = {", map_hex))
                for cell, info in pairs(cells) do
                    M.info(string.format('        ["%s"] = true,  -- blocked from: %s',
                        cell, table.concat(info.dirs, ", ")))
                end
                M.info("    },")
            end
            M.info("=== end export_blocks ===")
        end

    elseif cmd == "sweep_map" or cmd == "sweep_teleport_legacy" then
        -- Start a systematic walkability sweep of the current map.
        -- The sweep teleports the player to every tile that map_reader considers
        -- walkable, probes all 4 directions via joypad injection, and records any
        -- moves the engine rejects. This exposes hidden engine walls that don't
        -- appear in the ROM tile data.
        --
        -- While the sweep is active:
        --   - auto_step is suspended (main.lua checks M.is_sweep_active())
        --   - the player is teleported around the map automatically
        --   - random encounters may occur in dungeon maps (use with caution there)
        --
        -- Legacy/unsafe: results are review-only and are not persisted to
        -- dw_blocks.log because teleport setup can poison blocker evidence.
        --
        -- Usage: echo sweep_teleport_legacy > dw_commands.txt
        --        (sweep_map remains a backwards-compatible legacy alias)
        -- To cancel mid-sweep: echo stop_sweep > dw_commands.txt
        if sweep then
            M.info("SWEEP: already active (use stop_sweep to cancel)")
        else
            M.info(string.format(
                "SWEEP_LEGACY_UNSAFE command=%s trusted=false teleport_used=true output=review_only persistence=skipped recommended=sweep_walk",
                cmd))
            local map_id = memory.readbyte(addr.MAP_ID)
            local terrain = memory.readbyte(addr.TERRAIN_OFFSET)
            if maps_m.is_overworld(map_id, terrain) then
                M.error("SWEEP: overworld not supported (too large; use on interior maps)")
            else
                sweep = {
                    phase      = "init",
                    origin_map = map_id,
                    tile_list  = nil,
                    tile_idx   = 0,
                    map_w      = nil,
                    map_h      = nil,
                    dir_idx    = 0,
                    tile_x     = nil,
                    tile_y     = nil,
                    settle_timer  = 0,
                    inject_timer  = 0,
                    probe_timer   = 0,
                    found_blocks  = {},
                    legacy_unsafe = true,
                    trusted       = false,
                    command_name   = cmd,
                    -- Cells that killed the player during a previous probe attempt.
                    -- These are skipped as probe origins and as probe destinations.
                    death_cells   = {},
                    -- Timing constants (frames):
                    SETTLE = 20,  -- Frames to hold position before testing; covers
                                  -- any in-progress walk animation (~16 frames max).
                    INJECT = 12,  -- Frames to hold direction key; enough for DW1 to
                                  -- commit to a step (turn ~8fr + initiation ~4fr).
                    PROBE  = 45,  -- Total frames to wait for position change before
                                  -- declaring the move blocked (matches auto_step timeout).
                }
                M.info(string.format("SWEEP: starting on map 0x%02X — legacy unsafe, NPCs will auto-freeze, player will teleport",
                    map_id))
            end
        end

    elseif cmd == "stop_sweep" then
        local stop_hook = custom_commands["__stop_sweep"]
        local handled_by_hook = false
        if stop_hook then
            local ok, handled_or_err = pcall(stop_hook)
            if not ok then
                M.error("stop_sweep hook failed: " .. tostring(handled_or_err))
            else
                handled_by_hook = handled_or_err == true
            end
        end
        if handled_by_hook then
            -- Movement-backed sweep_walk/crawl_map_frontier stop was handled by main.lua.
        elseif sweep then
            M.info(string.format("SWEEP: stopped by user at tile %d/%d",
                sweep.tile_idx, sweep.tile_list and #sweep.tile_list or 0))
            persist_sweep_blocks(sweep)
            sweep = nil
            sweep_unfreeze_npcs()
        else
            M.info("SWEEP: no active sweep to stop")
        end

    else
        -- Dispatch to custom commands registered by main.lua.
        -- Supports both bare names ("next_object") and colon-arg form ("speak:Hello").
        local cmd_name, cmd_arg = cmd:match("^([^:]+):?(.*)$")
        cmd_arg = (cmd_arg and cmd_arg ~= "") and cmd_arg or nil
        if cmd_name and custom_commands[cmd_name] then
            local ok, err = pcall(custom_commands[cmd_name], cmd_arg)
            if not ok then
                M.error("Command '" .. cmd_name .. "' failed: " .. tostring(err))
            end
        else
            M.error("Unknown command: '" .. cmd .. "'. Built-ins: log_state, report_position, report_coords, report_movement_state[:TAG], toggle_debug, simulate_input:BTN, simulate_raw_input:BTN, clear_input, input_status[:TAG], trace_input[:FRAMES], dump_grid, reload_config, launcher_probe[:TAG], export_blocks, sweep_map, sweep_teleport_legacy, stop_sweep")
        end
    end
    local elapsed_ms = (os.clock() - command_start_clock) * 1000
    if elapsed_ms >= 25 then
        M.info(string.format("CMD_TIMING command=%s ms=%.3f", cmd, elapsed_ms))
    end
    flush_log()
end

-- check_commands(): Read dw_commands.txt, process each line, then clear the file.
-- Called every CMD_CHECK_FRAMES frames by tick().
-- The file is cleared BEFORE processing so that even if a command triggers an
-- error the file won't be re-processed next cycle.
local function check_commands()
    local f = io.open(CMD_FILE, "r")
    if not f then return end  -- File doesn't exist — nothing to do.
    f:close()

    os.remove(CMD_PROCESSING_FILE)
    local renamed = os.rename(CMD_FILE, CMD_PROCESSING_FILE)
    local read_path = renamed and CMD_PROCESSING_FILE or CMD_FILE
    local rf = io.open(read_path, "r")
    if not rf then return end
    local contents = rf:read("*all")
    rf:close()

    if renamed then
        -- Recreate the live command file immediately so new commands can be
        -- queued while we process the current batch.
        local fw = io.open(CMD_FILE, "a")
        if fw then fw:close() end
    else
        -- Fallback path if rename fails; preserve the previous clear-first
        -- behavior so commands still fire once.
        local fw = io.open(CMD_FILE, "w")
        if fw then fw:close() end
    end

    -- Process each non-blank, non-comment line.
    for line in contents:gmatch("[^\r\n]+") do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" and trimmed:sub(1, 1) ~= ";" then
            process_command(trimmed)
        end
    end

    if renamed then
        os.remove(CMD_PROCESSING_FILE)
    end
end

-- ============================================================
-- Per-Frame Tick
-- ============================================================

-- tick(frame, game_state_str): Call once per main loop, BEFORE FCEU.frameadvance().
--
--   frame:          current frame_count from main.lua
--   game_state_str: current state string (e.g. state.STATE_FIELD)
--
-- Returns a joypad input table if a simulate_input command was received this
-- cycle, or nil otherwise. Main loop must apply it:
--
--   local sim = debug_tools.tick(frame_count, game_state.state)
--   if sim then joypad.set(1, sim) end
--
-- When DEBUG_MODE is false the function returns nil immediately.
function M.tick(frame, game_state_str)
    if not M.DEBUG_MODE then return nil end

    current_frame = frame
    current_state = game_state_str or "unknown"

    -- Check the command file once per second (every CMD_CHECK_FRAMES frames).
    -- Using modulo on the raw frame count keeps the interval steady regardless
    -- of when tick() starts being called.
    if frame % CMD_CHECK_FRAMES == 0 then
        check_commands()
        trace_teleport_tick("POST_COMMANDS")
    end

    update_stuck_alt_watch(frame)
    update_input_trace(frame)
    trace_teleport_tick("POST_INPUT_WATCH")

    -- Flush the log buffer to disk once per second as well.
    -- Staggering this from the command check (offset by 30 frames) spreads
    -- two I/O operations across different frames to avoid a single-frame spike.
    if frame % LOG_FLUSH_FRAMES == 30 then
        flush_log()
    end

    -- Advance the map sweep state machine one frame. The sweep returns a
    -- joypad input table when it needs to inject a direction key. That table
    -- is tagged with _sweep=true so main.lua routes it directly to joypad.set()
    -- instead of through auto_step.inject_step() (which reads joypad.read()
    -- and wouldn't see our injection anyway).
    local sweep_inp = sweep_tick()
    trace_teleport_tick("POST_SWEEP_TICK")
    if sweep_inp then
        pending_input_release = true
    end

    -- Return and clear any pending simulated input.
    -- Sweep input takes priority over queued button commands.
    local sequence_inp = nil
    if not sweep_inp then
        sequence_inp = input_sequence_tick()
    end
    local held_inp = nil
    if not sweep_inp and not sequence_inp and pending_input_hold then
        held_inp = pending_input_hold.buttons
        pending_input_hold.frames_remaining = pending_input_hold.frames_remaining - 1
        if pending_input_hold.frames_remaining <= 0 then
            pending_input_release_raw = pending_input_hold.buttons and pending_input_hold.buttons._raw or false
            pending_input_hold = nil
            pending_input_release = true
        end
    end

    -- pending_input and pending_input_hold are mutually exclusive: queue_pending_input
    -- sets one or the other but never both. So when held_inp is active, pending_input
    -- is already nil — the guard below is defensive insurance, not for the multi-frame case.
    local inp = sweep_inp or sequence_inp or held_inp or pending_input
    if not sweep_inp and not sequence_inp and not held_inp then
        if pending_input then
            pending_input_release_raw = pending_input._raw or false
            pending_input_release = true
        elseif pending_input_release then
            pending_input_release = false
            inp = full_joypad_state({})
            if pending_input_release_raw then
                inp._raw = true
            end
            pending_input_release_raw = false
        end
        pending_input = nil
    end
    local stat_sample = capture_player_stat_trace_sample(frame, game_state_str or "unknown")
    monitor_player_stat_integrity(stat_sample)
    push_player_stat_trace_sample(stat_sample)
    trace_teleport_tick("PRE_RETURN")
    return inp
        or build_external_keyboard_bridge_input(frame)
        or build_keyboard_bridge_input(frame)
end

-- ============================================================
-- Custom Command Registration
-- ============================================================

-- register_command(name, fn): Register a custom command handler callable from
-- dw_commands.txt. Call this from main.lua after all modules are loaded.
--
--   name  — command name as written in the file (e.g. "next_object")
--   fn    — function(arg) where arg is the text after the first ':',
--            or nil if the command had no colon (e.g. "speak:Hello" → arg="Hello";
--            "next_object" → arg=nil).
--
-- Example:
--   debug_tools.register_command("speak", function(arg)
--       tolk.output_interrupt(arg or "")
--   end)
--
-- Custom commands are dispatched after all built-in commands are checked.
-- If debug_mode is false the function is a no-op so main.lua can always call it.
function M.register_command(name, fn)
    if not M.DEBUG_MODE then return end
    custom_commands[name] = fn
end

-- ============================================================
-- Block Recording
-- ============================================================

-- record_block(map_id, x, y, dir): Record one engine-blocked movement.
--
--   map_id  — current map (from RAM)
--   x, y    — tile the player was standing on when the move was rejected
--   dir     — direction tried: "up" | "down" | "left" | "right"
--
-- This is called automatically by auto_step.lua whenever a step attempt
-- times out (the player held a direction and the engine never moved them).
-- New entries are appended to dw_blocks.log so the database persists across
-- sessions. Duplicate entries are silently ignored.
function M.record_block(map_id, x, y, dir)
    if not M.DEBUG_MODE then return end
    if not legacy_block_log_enabled() then return end
    local key = string.format("0x%02X:%d,%d:%s", map_id, x, y, dir)
    if blocked_entries[key] then return end  -- already known; skip

    blocked_entries[key] = true
    -- Append to persistent log so this survives a script reload.
    local f = io.open(BLOCKS_FILE, "a")
    if f then
        f:write(key .. "\n")
        f:close()
    end
    -- Compute the destination cell that is blocked (one step in dir from x,y).
    local d = DIR_DELTA[dir] or {dx=0, dy=0}
    M.info(string.format(
        "NEW BLOCK: map=0x%02X from=(%d,%d) dir=%s  dest=(%d,%d)",
        map_id, x, y, dir, x + d.dx, y + d.dy))
end

-- is_sweep_active(): Return true when a map sweep is running.
-- main.lua checks this to suspend auto_step so it doesn't interfere with
-- the sweep's own joypad injections.
function M.is_sweep_active()
    return sweep ~= nil
end

-- ============================================================
-- Map Sweep: Internal State Machine
-- ============================================================
-- sweep_tick() is called once per frame from tick() while a sweep is active.
-- It advances the sweep one step and returns a joypad table (or nil) that
-- main.lua should apply via joypad.set() for the CURRENT frame.
--
-- The returned table is tagged with _sweep=true so main.lua skips the
-- auto_step.inject_step() path and calls joypad.set() directly instead.
-- (auto_step reads joypad.read() not joypad.set() output, so multi-frame
-- direction injections from the sweep won't create auto_step hold sequences.)
--
-- Sweep phases:
--   init        : build list of walkable tiles; move to next_tile
--   teleport    : write player position bytes; move to settle
--   settle      : keep re-writing position each frame until stable (SETTLE frames)
--   next_dir    : advance dir_idx; if all 4 done, move to teleport for next tile
--   inject      : inject direction via joypad for INJECT frames
--   probe       : wait up to PROBE frames for position to change
--   settle_back : after a successful step, teleport back and wait SETTLE frames
--   export      : write results, clear sweep

-- Tile types that indicate a map-transition tile (stair/exit). Moving onto
-- these during the sweep would warp to a different map, aborting the sweep.
-- We skip testing any direction whose destination has one of these types.
-- town/castle tileset: 5=stairs; dungeon tileset: 4=stairs.
local TRANSITION_TYPES = { [4]=true, [5]=true }

-- persist_sweep_blocks(sw): Write trusted entries from sw.found_blocks to
-- dw_blocks.log (skipping duplicates already in blocked_entries). Legacy
-- teleport sweep output is explicitly untrusted and is never persisted here.
persist_sweep_blocks = function(sw)
    if not sw or not sw.found_blocks then return end
    if sw.legacy_unsafe then
        M.info(string.format(
            "SWEEP_LEGACY_UNSAFE persist_skipped=true trusted=false teleport_used=true command=%s",
            tostring(sw.command_name or "sweep_map")))
        return
    end
    -- Collect new keys first, then batch-write once (avoids open/close per entry).
    local new_keys = {}
    for key, _ in pairs(sw.found_blocks) do
        if not blocked_entries[key] then
            new_keys[#new_keys + 1] = key
            blocked_entries[key] = true
        end
    end
    if #new_keys > 0 then
        local f = io.open(BLOCKS_FILE, "a")
        if f then
            for _, key in ipairs(new_keys) do
                f:write(key .. "\n")
            end
            f:close()
        end
        M.info(string.format("SWEEP: persisted %d block(s) to dw_blocks.log", #new_keys))
    end
end

-- sweep_unfreeze_npcs(): Release the NPC freeze that sweep_map acquired.
-- Late-requires route_manager to avoid circular dependency at load time.
sweep_unfreeze_npcs = function()
    local ok, route_mgr = pcall(require, "route_manager")
    if ok and route_mgr then
        route_mgr.unfreeze_npcs()
        M.info("SWEEP: NPCs auto-unfrozen")
    end
end

-- sweep_tick(): Advance sweep one frame. Returns a joypad input table or nil.
-- Assigned to the forward-declared local above so M.tick can call it.
sweep_tick = function()
    if not sweep then return nil end

    local cur_map = memory.readbyte(addr.MAP_ID)
    local cur_x   = memory.readbyte(addr.PLAYER_X)
    local cur_y   = memory.readbyte(addr.PLAYER_Y)

    -- ---- phase: paused_death ----
    -- Player died (hit a death square). Waiting for the user to quick-load
    -- back to the sweep map, then the sweep auto-resumes at the next tile.
    if sweep.phase == "paused_death" then
        if cur_map ~= sweep.origin_map then
            return nil  -- still on wrong map; keep waiting silently
        end
        -- Back on the sweep map — resume.
        local n_deaths = 0
        for _ in pairs(sweep.death_cells) do n_deaths = n_deaths + 1 end
        M.info(string.format(
            "SWEEP RESUMED: map=0x%02X  tile %d/%d  %d death cell%s will be skipped",
            cur_map, sweep.tile_idx, #sweep.tile_list,
            n_deaths, n_deaths == 1 and "" or "s"))
        sweep.phase = "next_tile"
        -- Fall through to next_tile handling this same frame.
    end

    -- Safety: pause (not abort) if the map changed unexpectedly.
    -- This catches death squares that kill the player mid-sweep.
    -- The user can quick-load back to the map to auto-resume.
    if cur_map ~= sweep.origin_map then
        -- Record whatever tile(s) may have caused the death so they are skipped
        -- on resume: the current probe origin, plus the destination if a
        -- directional probe was in flight.
        if sweep.tile_x then
            sweep.death_cells[sweep.tile_x .. "," .. sweep.tile_y] = true
        end
        if sweep.dir_idx and sweep.dir_idx > 0
        and sweep.dir_idx <= #DIR_META and sweep.tile_x then
            local dir = DIR_META[sweep.dir_idx]
            sweep.death_cells[
                (sweep.tile_x + dir.dx) .. "," .. (sweep.tile_y + dir.dy)] = true
        end
        local n_deaths = 0
        for _ in pairs(sweep.death_cells) do n_deaths = n_deaths + 1 end
        M.info(string.format(
            "SWEEP PAUSED (death): tile %d/%d (%d,%d) map 0x%02X→0x%02X"
            .. " — quick-load to resume  [%d death cell%s marked]",
            sweep.tile_idx, sweep.tile_list and #sweep.tile_list or 0,
            sweep.tile_x or 0, sweep.tile_y or 0,
            sweep.origin_map, cur_map,
            n_deaths, n_deaths == 1 and "" or "s"))
        persist_sweep_blocks(sweep)
        sweep.phase = "paused_death"
        return nil
    end

    -- ---- phase: init ----
    if sweep.phase == "init" then
        local w, h = map_reader.get_map_dimensions(cur_map)
        if not w then
            M.error("SWEEP: no map dimensions for map 0x" .. string.format("%02X", cur_map))
            sweep = nil
            return nil
        end
        sweep.map_w = w
        sweep.map_h = h

        -- Auto-freeze NPCs so the sweep doesn't record transient NPC-blocked
        -- cells as permanent engine walls. Late-require avoids circular dependency.
        local ok, route_mgr = pcall(require, "route_manager")
        if ok and route_mgr then
            route_mgr.freeze_npcs()
            M.info("SWEEP: NPCs auto-frozen")
        end

        -- Snapshot NPC positions to exclude from both probe recording (destination
        -- check) AND origin tile list (teleporting onto an NPC causes odd behavior).
        sweep.npc_cells = {}
        for i = 0, addr.NPC_COUNT - 1 do
            local base  = addr.NPC_DATA_START + (i * addr.NPC_ENTRY_SIZE)
            local byte0 = memory.readbyte(base)
            local byte1 = memory.readbyte(base + 1)
            local nx = AND(byte0, 0x1F)
            local ny = AND(byte1, 0x1F)
            if not (nx == 0 and ny == 0) and not (nx == 31 and ny == 31) then
                sweep.npc_cells[nx .. "," .. ny] = true
            end
        end
        local npc_count = 0
        for _ in pairs(sweep.npc_cells) do npc_count = npc_count + 1 end
        M.info(string.format("SWEEP: NPC snapshot: %d active NPCs excluded from origin+dest tiles", npc_count))

        -- Collect all tiles that map_reader considers walkable. These are our
        -- candidates; the sweep determines which ones have hidden engine walls.
        -- Skip row 0 and col 0 — engine always blocks them (x==0 or y==0 guard
        -- in map_reader.is_walkable). Also skip the bottom and right border rows
        -- to avoid testing exits at map edges.
        --
        -- Also excluded from the origin list:
        --   - Transition tiles (stairs/exits): teleporting onto them warps the map.
        --   - NPC-occupied tiles: teleporting onto an NPC causes odd engine behavior.
        sweep.tile_list = {}
        for y = 1, h - 2 do
            for x = 1, w - 2 do
                if map_reader.is_walkable(cur_map, x, y) == true then
                    local tile_type = map_reader.get_tile_type(cur_map, x, y)
                    if not (tile_type and TRANSITION_TYPES[tile_type])
                    and not sweep.npc_cells[x .. "," .. y] then
                        sweep.tile_list[#sweep.tile_list + 1] = {x=x, y=y}
                    end
                end
            end
        end
        M.info(string.format("SWEEP: map=0x%02X  %dx%d  %d walkable tiles to probe",
            cur_map, w, h, #sweep.tile_list))
        sweep.tile_idx = 0
        sweep.phase = "next_tile"
        return nil
    end

    -- ---- phase: next_tile ----
    if sweep.phase == "next_tile" then
        -- Advance tile index, skipping any tiles marked as death cells.
        repeat
            sweep.tile_idx = sweep.tile_idx + 1
            if sweep.tile_idx > #sweep.tile_list then
                sweep.phase = "export"
                return nil
            end
            local t = sweep.tile_list[sweep.tile_idx]
            local skip_key = t.x .. "," .. t.y
            if sweep.death_cells[skip_key] then
                M.debug(string.format("SWEEP SKIP (death cell): (%d,%d)", t.x, t.y))
            else
                break
            end
        until false
        -- Log progress periodically so the user knows the sweep is alive.
        local total = #sweep.tile_list
        if sweep.tile_idx % 50 == 0 or sweep.tile_idx == total then
            M.info(string.format("SWEEP: progress %d/%d tiles (%.0f%%)",
                sweep.tile_idx, total, 100 * sweep.tile_idx / total))
        end
        local tile = sweep.tile_list[sweep.tile_idx]
        sweep.tile_x = tile.x
        sweep.tile_y = tile.y
        sweep.dir_idx = 0
        -- Teleport player to this tile.
        memory.writebyte(addr.PLAYER_X, sweep.tile_x)
        memory.writebyte(addr.PLAYER_Y, sweep.tile_y)
        sweep.settle_timer = sweep.SETTLE
        sweep.phase = "settle"
        return nil
    end

    -- ---- phase: settle ----
    -- Re-write position every frame until it sticks AND we've waited long
    -- enough for any in-progress walk animation to finish.
    if sweep.phase == "settle" then
        -- Note: map-change is caught by the top-level pause guard above, so
        -- we never reach here with cur_map ~= origin_map.
        -- Keep asserting the desired position so the game can't overwrite it.
        memory.writebyte(addr.PLAYER_X, sweep.tile_x)
        memory.writebyte(addr.PLAYER_Y, sweep.tile_y)
        -- Count down only once the position actually matches what we wrote.
        if cur_x == sweep.tile_x and cur_y == sweep.tile_y then
            sweep.settle_timer = sweep.settle_timer - 1
            if sweep.settle_timer <= 0 then
                sweep.phase = "next_dir"
            end
        end
        return nil
    end

    -- ---- phase: next_dir ----
    if sweep.phase == "next_dir" then
        sweep.dir_idx = sweep.dir_idx + 1
        if sweep.dir_idx > #DIR_META then
            -- All 4 directions tested for this tile; move on.
            sweep.phase = "next_tile"
            return nil
        end

        local dir = DIR_META[sweep.dir_idx]
        local dest_x = sweep.tile_x + dir.dx
        local dest_y = sweep.tile_y + dir.dy

        -- Skip out-of-bounds destinations (would trigger map exit).
        if dest_x < 0 or dest_x >= sweep.map_w
        or dest_y < 0 or dest_y >= sweep.map_h then
            -- Loop immediately (stay in next_dir phase, advance dir next frame).
            return nil
        end

        -- Skip stair / exit tile types — stepping on them warps the map.
        local dest_tile = map_reader.get_tile_type(cur_map, dest_x, dest_y)
        if dest_tile and TRANSITION_TYPES[dest_tile] then
            return nil
        end

        -- Also skip destinations map_reader already marks as non-walkable
        -- (tile-type walls). We only care about tiles that LOOK walkable but
        -- the engine rejects — those are the hidden walls we need to find.
        local dest_walkable = map_reader.is_walkable(cur_map, dest_x, dest_y)
        if dest_walkable ~= true then
            return nil
        end

        -- Skip probing toward a known death cell — stepping there would kill
        -- the player and interrupt the sweep again.
        if sweep.death_cells[dest_x .. "," .. dest_y] then
            M.debug(string.format("SWEEP SKIP (death cell dest): (%d,%d)->%s  dest=(%d,%d)",
                sweep.tile_x, sweep.tile_y, dir.key, dest_x, dest_y))
            return nil
        end

        -- Set up the probe for this direction.
        sweep.probe_start_x  = cur_x
        sweep.probe_start_y  = cur_y
        sweep.probe_timer    = sweep.PROBE
        sweep.inject_timer   = sweep.INJECT
        sweep.phase          = "inject"
        return nil
    end

    -- ---- phase: inject ----
    -- Hold the direction key for INJECT frames so the game commits to a step.
    if sweep.phase == "inject" then
        -- Did the player move already (very fast engine response)?
        if cur_x ~= sweep.tile_x or cur_y ~= sweep.tile_y then
            -- Step completed — passable; teleport back.
            sweep.phase = "settle_back"
            sweep.settle_timer = sweep.SETTLE
            memory.writebyte(addr.PLAYER_X, sweep.tile_x)
            memory.writebyte(addr.PLAYER_Y, sweep.tile_y)
            return nil
        end

        -- Check-then-decrement so we inject for exactly INJECT frames
        -- (inject_timer=12 → inject frames 1..12, then switch to probe).
        if sweep.inject_timer > 0 then
            sweep.inject_timer = sweep.inject_timer - 1
            sweep.probe_timer  = sweep.probe_timer  - 1
            -- Return the direction key tagged as a sweep input.
            -- The _sweep tag tells main.lua to call joypad.set() directly instead
            -- of routing through auto_step.inject_step().
            local dir_key = DIR_META[sweep.dir_idx].key
            return {[dir_key] = true, _sweep = true}
        else
            -- Done injecting; wait for position to change.
            sweep.phase = "probe"
            return nil
        end
    end

    -- ---- phase: probe ----
    -- Wait up to PROBE frames for the position to change.
    if sweep.phase == "probe" then
        if cur_x ~= sweep.tile_x or cur_y ~= sweep.tile_y then
            -- Position changed — the step succeeded. Tile is passable.
            -- Teleport back so we can test the next direction from the same origin.
            sweep.phase = "settle_back"
            sweep.settle_timer = sweep.SETTLE
            memory.writebyte(addr.PLAYER_X, sweep.tile_x)
            memory.writebyte(addr.PLAYER_Y, sweep.tile_y)
            return nil
        end

        sweep.probe_timer = sweep.probe_timer - 1
        if sweep.probe_timer <= 0 then
            -- Timeout: engine blocked this move.
            local dir  = DIR_META[sweep.dir_idx]
            local dest_x = sweep.tile_x + dir.dx
            local dest_y = sweep.tile_y + dir.dy
            local dest_key = dest_x .. "," .. dest_y
            -- Skip recording if the destination is an NPC position. An NPC
            -- standing on a tile blocks movement just like a wall, but the
            -- tile itself is walkable; recording it would be a false positive.
            if sweep.npc_cells and sweep.npc_cells[dest_key] then
                M.debug(string.format("SWEEP SKIP (NPC): (%d,%d)->%s  dest=(%d,%d)",
                    sweep.tile_x, sweep.tile_y, dir.key, dest_x, dest_y))
            else
                local key = string.format("0x%02X:%d,%d:%s",
                    sweep.origin_map, sweep.tile_x, sweep.tile_y, dir.key)
                if not sweep.found_blocks[key] then
                    sweep.found_blocks[key] = true
                    M.info(string.format("SWEEP BLOCKED: (%d,%d)->%s  dest=(%d,%d)",
                        sweep.tile_x, sweep.tile_y, dir.key, dest_x, dest_y))
                end
            end
            -- Advance to the next direction.
            sweep.phase = "next_dir"
        end
        return nil
    end

    -- ---- phase: settle_back ----
    -- After a successful step, we teleported the player back. Keep asserting
    -- the position until the game accepts it, then test the next direction.
    if sweep.phase == "settle_back" then
        -- Note: map-change is caught by the top-level pause guard above, so
        -- we never reach here with cur_map ~= origin_map.
        memory.writebyte(addr.PLAYER_X, sweep.tile_x)
        memory.writebyte(addr.PLAYER_Y, sweep.tile_y)
        if cur_x == sweep.tile_x and cur_y == sweep.tile_y then
            sweep.settle_timer = sweep.settle_timer - 1
            if sweep.settle_timer <= 0 then
                sweep.phase = "next_dir"
            end
        end
        return nil
    end

    -- ---- phase: export ----
    if sweep.phase == "export" then
        -- Count totals.
        local n_new = 0
        for _ in pairs(sweep.found_blocks) do n_new = n_new + 1 end

        M.info(string.format("SWEEP COMPLETE: map=0x%02X  %d tiles probed  %d new blocks found",
            sweep.origin_map, #sweep.tile_list, n_new))

        if n_new > 0 then
            -- Group by destination cell (for MAP_BLOCKED_CELLS format).
            -- Multiple blocked-from directions that all point to the same dest
            -- cell collapse into one entry because MAP_BLOCKED_CELLS blocks all
            -- access to that cell regardless of direction.
            local dest_cells = {}
            for key, _ in pairs(sweep.found_blocks) do
                local _, sx, sy, dir_s =
                    key:match("^(0x%x+):(%d+),(%d+):(%a+)$")
                if dir_s and DIR_DELTA[dir_s] then
                    local d = DIR_DELTA[dir_s]
                    sx, sy = tonumber(sx), tonumber(sy)
                    local cell = string.format("%d,%d", sx + d.dx, sy + d.dy)
                    dest_cells[cell] = dest_cells[cell] or {}
                    dest_cells[cell][#dest_cells[cell]+1] = dir_s  -- source dirs
                end
            end

            M.info("=== LEGACY UNSAFE SWEEP OUTPUT: review only, trusted=false, prefer sweep_walk ===")
            M.info(string.format("    [0x%02X] = {", sweep.origin_map))
            for cell, dirs in pairs(dest_cells) do
                M.info(string.format('        ["%s"] = true,  -- blocked from: %s',
                    cell, table.concat(dirs, ", ")))
            end
            M.info("    },")
            M.info("=== end legacy unsafe sweep output; do not paste without walked verification ===")

            -- Legacy teleport-backed output is review-only; persist_sweep_blocks
            -- logs trusted=false and skips dw_blocks.log for these runs.
            persist_sweep_blocks(sweep)
        else
            M.info("SWEEP: no hidden engine blocks found on this map — tile data matches engine.")
        end

        sweep = nil
        sweep_unfreeze_npcs()
        return nil
    end

    -- Unknown phase — defensive reset.
    M.error("SWEEP: unknown phase '" .. tostring(sweep and sweep.phase) .. "' — aborting")
    sweep = nil
    sweep_unfreeze_npcs()
    return nil
end

-- ============================================================
-- Event Bus Integration
-- ============================================================
-- The event_bus module provides decoupled pub/sub messaging. Currently,
-- main.lua calls both the direct hook functions (on_menu_open, etc.) AND
-- publishes corresponding events. The direct hooks above handle logging.
--
-- In a future phase, main.lua will stop calling the direct hooks and only
-- publish events. At that point, subscribe handlers here to replace the
-- direct hooks. For now, we just require the module so it's available and
-- leave the subscriptions commented to avoid duplicate log entries.
--
-- Example (activate when direct hooks are removed from main.lua):
--   event_bus.subscribe("menu_opened", function() M.debug("EVENT: command menu opened") end)
--   event_bus.subscribe("battle_started", function() M.info("EVENT: battle started"); M.snapshot() end)

local event_bus = require "event_bus"  -- luacheck: ignore (loaded for future use)

-- ============================================================
-- Shutdown
-- ============================================================

-- shutdown(): Flush any remaining buffered log entries.
-- Call from main.lua if you add a pcall/xpcall wrapper around the main loop.
-- FCEUX does not guarantee cleanup callbacks, but this helps during normal exit.
function M.shutdown()
    if not M.DEBUG_MODE then return end
    M.info("Script shutting down.")
    flush_log()
end

return M
