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
--   report_position      -- write current map/x/y to the log
--   toggle_debug         -- flip DEBUG_MODE on/off at runtime
--   simulate_input:UP    -- inject a one-frame D-pad or button press
--   simulate_input:DOWN
--   simulate_input:LEFT
--   simulate_input:RIGHT
--   simulate_input:A
--   simulate_input:B
--   simulate_input:START
--   simulate_input:SELECT
--   Lines beginning with ; are treated as comments and ignored.

local M = {}

-- ============================================================
-- Dependencies
-- ============================================================
local config = require "config"
local addr   = require "addresses"
local maps_m = require "maps"

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

local LOG_FILE = script_dir .. "dw_debug.log"
local CMD_FILE = script_dir .. "dw_commands.txt"

-- ============================================================
-- Internal State
-- ============================================================
local log_buffer       = {}   -- Lines queued before next disk flush
local LOG_FLUSH_FRAMES = 60   -- Flush to disk every 60 frames (~1 sec at 60fps)
local CMD_CHECK_FRAMES = 60   -- Check command file every 60 frames

local pending_input  = nil    -- Joypad table to apply on next frame, or nil
local current_frame  = 0      -- Set each tick; used in log entry prefix
local current_state  = "unknown"  -- Set each tick; used in log entry prefix

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
    local px       = memory.readbyte(addr.PLAYER_X)
    local py       = memory.readbyte(addr.PLAYER_Y)
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
    local terrain  = memory.readbyte(addr.TERRAIN_OFFSET)
    local map_name = maps_m.get_name(map_id)

    local lines = {
        "--- State Snapshot ---",
        string.format("frame:     %d",          current_frame),
        string.format("state:     %s",          current_state),
        string.format("map_id:    0x%02X (%s)", map_id, map_name),
        string.format("pos:       x=%d, y=%d",  px, py),
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
        local px     = memory.readbyte(addr.PLAYER_X)
        local py     = memory.readbyte(addr.PLAYER_Y)
        M.info(string.format("POSITION: map=0x%02X(%s) x=%d y=%d",
            map_id, maps_m.get_name(map_id), px, py))

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

    else
        M.error("Unknown command: '" .. cmd .. "'")
    end
end

-- check_commands(): Read dw_commands.txt, process each line, then clear the file.
-- Called every CMD_CHECK_FRAMES frames by tick().
-- The file is cleared BEFORE processing so that even if a command triggers an
-- error the file won't be re-processed next cycle.
local function check_commands()
    local f = io.open(CMD_FILE, "r")
    if not f then return end  -- File doesn't exist — nothing to do.

    local contents = f:read("*all")
    f:close()

    -- Clear the file immediately so commands fire exactly once.
    local fw = io.open(CMD_FILE, "w")
    if fw then fw:close() end

    -- Process each non-blank, non-comment line.
    for line in contents:gmatch("[^\r\n]+") do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" and trimmed:sub(1, 1) ~= ";" then
            process_command(trimmed)
        end
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

    -- Return and clear any pending simulated input so it fires exactly once.
    local inp = pending_input
    pending_input = nil
    return inp
end

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
