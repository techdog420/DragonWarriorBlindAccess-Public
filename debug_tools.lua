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
--   toggle_debug         -- flip DEBUG_MODE on/off at runtime
--   simulate_input:UP    -- inject a one-frame D-pad or button press
--   simulate_raw_input:UP -- inject a one-frame raw D-pad or button press
--   simulate_input:DOWN
--   simulate_input:LEFT
--   simulate_input:RIGHT
--   simulate_input:A
--   simulate_input:B
--   simulate_input:START
--   simulate_input:SELECT
--   dump_grid            -- dump tile type + walkability grid for current map
--   export_blocks        -- format all recorded blocked moves as MAP_BLOCKED_CELLS Lua entries
--   sweep_map            -- start systematic walkability sweep of current map
--   stop_sweep           -- cancel active sweep
--   Lines beginning with ; are treated as comments and ignored.

local M = {}

-- ============================================================
-- Dependencies
-- ============================================================
local config     = require "config"
local addr       = require "addresses"
local maps_m     = require "maps"
local map_reader = require "map_reader"

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

-- ============================================================
-- File Paths
-- ============================================================
-- Derive the script directory from this file's source path so all
-- output files land next to the Lua scripts, wherever the mod lives.
local _src       = debug.getinfo(1, "S").source
local script_dir = _src:match("@?(.*[\\/])") or ""

local LOG_FILE    = script_dir .. "dw_debug.log"
local CMD_FILE    = script_dir .. "dw_commands.txt"
local CMD_PROCESSING_FILE = script_dir .. "dw_commands.processing.txt"
-- Persistent record of every engine-blocked move discovered this session or
-- in previous sessions. One entry per line: "0xMM:x,y:dir"
-- New discoveries are appended during play. export_blocks formats this file
-- as copy-pasteable MAP_BLOCKED_CELLS Lua table entries.
local BLOCKS_FILE = script_dir .. "dw_blocks.log"

-- ============================================================
-- Internal State
-- ============================================================
local log_buffer       = {}   -- Lines queued before next disk flush
local LOG_FLUSH_FRAMES = 60   -- Flush to disk every 60 frames (~1 sec at 60fps)
local CMD_CHECK_FRAMES = 60   -- Check command file every 60 frames

local pending_input  = nil    -- Joypad table to apply on next frame, or nil
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

-- ============================================================
-- State Snapshot
-- ============================================================

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
    local gold     = memory.readbyte(addr.GOLD_LO) + memory.readbyte(addr.GOLD_HI) * 256
    local exp      = memory.readbyte(addr.EXPERIENCE_LO) + memory.readbyte(addr.EXPERIENCE_HI) * 256
    local enemy_hp = memory.readbyte(addr.ENEMY_HP)
    local d8       = memory.readbyte(addr.MENU_CURSOR_X)
    local d9       = memory.readbyte(addr.MENU_CURSOR_Y)
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
        string.format("gold:      %d",          gold),
        string.format("exp:       %d",          exp),
        string.format("enemy_hp:  %d",          enemy_hp),
        string.format("cursor:    D8=%d D9=%d", d8, d9),
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
    M.info("EVENT: battle started")
    M.snapshot()  -- Auto-snapshot on battle start so enemy type etc. are captured
end

-- Call inside check_map_change() when changes.map_changed is true.
-- new_id: the new map ID (read from RAM after nav.check_for_changes updates it)
function M.on_map_change(new_id)
    if not M.DEBUG_MODE then return end
    local new_name = new_id and maps_m.get_name(new_id) or "?"
    M.info(string.format("EVENT: map change -> 0x%02X (%s)", new_id or 0, new_name))
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

-- process_command(cmd): Execute one trimmed command string.
local function process_command(cmd)
    if cmd == "" then return end

    M.debug("CMD: " .. cmd)

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
        local btn_str = cmd:sub(16):upper()
        local btn_key = BUTTON_MAP[btn_str]
        if btn_key then
            pending_input = { [btn_key] = true }
            M.debug("Queued joypad: " .. btn_str)
        else
            M.error("simulate_input: unknown button '" .. btn_str ..
                "'. Valid: UP DOWN LEFT RIGHT A B START SELECT")
        end

    elseif cmd:sub(1, 19) == "simulate_raw_input:" then
        -- Queue a one-frame raw joypad injection that bypasses auto_step.
        local btn_str = cmd:sub(20):upper()
        local btn_key = BUTTON_MAP[btn_str]
        if btn_key then
            pending_input = { [btn_key] = true, _raw = true }
            M.debug("Queued raw joypad: " .. btn_str)
        else
            M.error("simulate_raw_input: unknown button '" .. btn_str ..
                "'. Valid: UP DOWN LEFT RIGHT A B START SELECT")
        end

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
            M.info("export_blocks: no blocks recorded yet. Play with debug_mode=true to accumulate data, or run sweep_map.")
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

    elseif cmd == "sweep_map" then
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
        -- Results are written to the log and to dw_blocks.log. Run export_blocks
        -- after completion to get the Lua table entries for map_reader.lua.
        --
        -- Usage: echo sweep_map > dw_commands.txt
        -- To cancel mid-sweep: echo stop_sweep > dw_commands.txt
        if sweep then
            M.info("SWEEP: already active (use stop_sweep to cancel)")
        else
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
                M.info(string.format("SWEEP: starting on map 0x%02X — NPCs will auto-freeze, player will teleport",
                    map_id))
            end
        end

    elseif cmd == "stop_sweep" then
        if sweep then
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
            M.error("Unknown command: '" .. cmd .. "'. Built-ins: log_state, report_position, report_coords, toggle_debug, simulate_input:BTN, simulate_raw_input:BTN, dump_grid, reload_config, export_blocks, sweep_map, stop_sweep")
        end
    end
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
    end

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

    -- Return and clear any pending simulated input so it fires exactly once.
    -- Sweep input takes priority over simulate_input commands.
    local inp = sweep_inp or pending_input
    if not sweep_inp then pending_input = nil end
    return inp
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

-- persist_sweep_blocks(sw): Write all entries from sw.found_blocks to
-- dw_blocks.log (skipping duplicates already in blocked_entries).
-- Called both on normal completion (export phase) and on all abort paths so
-- that partial sweep data is never silently discarded.
persist_sweep_blocks = function(sw)
    if not sw or not sw.found_blocks then return end
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

            M.info(string.format("    [0x%02X] = {", sweep.origin_map))
            for cell, dirs in pairs(dest_cells) do
                M.info(string.format('        ["%s"] = true,  -- blocked from: %s',
                    cell, table.concat(dirs, ", ")))
            end
            M.info("    },")
            M.info("=== (paste the above block into MAP_BLOCKED_CELLS in map_reader.lua) ===")

            -- Persist new blocks to dw_blocks.log so passive logger benefits too.
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
