-- tolk.lua
-- Speech output wrapper for screen readers (NVDA, JAWS, Narrator).
--
-- Strategy: Try loading Tolk.dll directly via LuaJIT FFI first (instant,
-- zero-latency). BizHawk's LuaJIT exposes ffi; FCEUX qfceux.exe does not.
-- If FFI fails (DLL missing, wrong architecture, or no ffi module), fall back
-- to the Python bridge (speech_bridge.py via io.popen).
--
-- The FFI path calls Tolk functions in-process — no subprocess, no pipe,
-- no startup delay. The Python bridge is kept as a fallback for environments
-- where the DLL can't be loaded directly.
--
-- Requirements (FFI path):
--   - Tolk.dll in the same directory as this script (or on PATH)
--   - encoding.lua for UTF-8 to UTF-16 conversion
--   - nvdaControllerClient32.dll / SAAPI32.dll alongside Tolk.dll
--
-- Requirements (bridge fallback):
--   - Python 3 installed and on the system PATH (or speech_python_cmd set)
--   - speech_bridge.py in the same directory as this script

local config = require "config"
local warning_delivery = require "warning_delivery"

-- ============================================================
-- Determine script directory
-- ============================================================
-- debug.getinfo(1, "S").source returns "@D:\modding\dragonwarrior1\tolk.lua"
-- We strip the "@" prefix and extract just the directory part.
local source = debug.getinfo(1, "S").source
local script_dir = source:match("@?(.*[\\/])") or ""

local function trim(s)
    return (tostring(s):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function is_absolute_path(path)
    return path:match("^%a:[/\\]") ~= nil or path:match("^\\\\") ~= nil
end

local function get_cwd()
    local ok, result = pcall(function()
        local p = io.popen("cd", "r")
        if not p then return nil end
        local out = p:read("*a")
        p:close()
        return trim(out)
    end)
    if ok then
        return result
    end
    return nil
end

local function join_path(base, rel)
    if not base or base == "" then
        return rel
    end
    local sep = base:match("[\\/]$") and "" or "\\"
    return base .. sep .. rel
end

local cwd = get_cwd()
if script_dir ~= "" and not is_absolute_path(script_dir) and cwd and cwd ~= "" then
    script_dir = join_path(cwd, script_dir)
end

local backend_log_path = script_dir .. "speech_backend.log"

local function backend_log(message)
    local ok, err = pcall(function()
        local f = io.open(backend_log_path, "a")
        if f then
            f:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. tostring(message) .. "\n")
            f:close()
        end
    end)
    if not ok then
        print("tolk.lua: backend log write failed: " .. tostring(err))
    end
end

-- ============================================================
-- Backend: which speech path is active
-- ============================================================
local backend = "none"       -- "ffi", "bridge", or "none"
local last_error = nil       -- last error message (nil = no error)

-- FCEU.message fallback for when speech isn't available
local function notify_fallback(text)
    if FCEU and FCEU.message then
        FCEU.message(text)
    else
        print(text)
    end
end

-- ============================================================
-- Attempt 1: FFI / Tolk.dll (preferred — zero latency)
-- ============================================================
-- BizHawk's Lua runtime is LuaJIT-based and does expose ffi, so the FFI path
-- is the preferred backend there. FCEUX qfceux.exe 2.6.6 (the current tested
-- fallback build) does not expose ffi, so on FCEUX the Python bridge is the
-- expected runtime path. ffi.load("tolk") searches the host process's CWD
-- and PATH — under BizHawk that is the emulator's install directory, not
-- the mod folder. We try an absolute path first so Tolk.dll resolves
-- regardless of where the emulator chose to run from, then fall back to
-- the bare name for legacy installs.

local ffi_tolk = nil     -- FFI Tolk library handle
local encoding = nil      -- encoding.lua module

local ffi_ok, ffi_err = pcall(function()
    local ffi = require "ffi"
    encoding = require "encoding"

    -- Declare the Tolk C API functions we need.
    -- Tolk_Output takes a wide string and a bool for interrupt mode.
    ffi.cdef[[
        void Tolk_Load();
        bool Tolk_IsLoaded();
        void Tolk_Unload();
        void Tolk_Output(const char *s, bool interrupt);
        void Tolk_Silence();
    ]]

    -- Try the script-local DLL first (handles BizHawk's CWD-elsewhere case),
    -- then the bare name (legacy/system-wide installs).
    local abs_dll = script_dir .. "Tolk.dll"
    local load_ok, lib_or_err = pcall(ffi.load, abs_dll)
    if not load_ok or not lib_or_err then
        backend_log("ffi.load(absolute) failed: " .. tostring(lib_or_err) .. " — retrying bare name")
        load_ok, lib_or_err = pcall(ffi.load, "tolk")
        if not load_ok or not lib_or_err then
            error(lib_or_err or "ffi.load failed for both absolute and bare name")
        end
    end
    ffi_tolk = lib_or_err
    ffi_tolk.Tolk_Load()
end)

if ffi_ok and ffi_tolk then
    backend = "ffi"
    backend_log("FFI backend active")
    print("tolk.lua: FFI backend active (Tolk.dll loaded directly)")
else
    last_error = "FFI load failed: " .. tostring(ffi_err)
    backend_log(last_error)
    print("tolk.lua: FFI unavailable (" .. tostring(ffi_err) .. "), trying Python bridge...")
end

-- ============================================================
-- Attempt 2: Python bridge fallback
-- ============================================================
-- Only launched if FFI failed. The bridge reads commands from stdin:
--   "speak:Hello world"     -> speak without interrupting
--   "interrupt:Hello world" -> speak, cutting off current speech
--   "silence"               -> stop all speech

local bridge = nil          -- io.popen handle (nil if not using bridge)
local bridge_started = false
local bridge_ready = false

if backend ~= "ffi" then
    local function resolve_path(path)
        if not path or path == "" then
            return path
        end
        if path:find("[/\\]") and not is_absolute_path(path) then
            return join_path(script_dir, path)
        end
        return path
    end

    local function quote_arg(path)
        return '"' .. tostring(path) .. '"'
    end

    -- Helper: resolve the Python command from config
    local function get_python_cmd()
        local python_cmd = config.get("speech_python_cmd")
        if not python_cmd or python_cmd == "" then
            return "python"
        end
        return resolve_path(python_cmd)
    end

    local python_cmd = get_python_cmd()
    local bridge_script = script_dir .. "speech_bridge.py"
    local status_path = script_dir .. "speech_bridge.status"
    local log_path = script_dir .. "speech_bridge.log"
    local launch_log_path = script_dir .. "speech_bridge_launch.log"

    pcall(os.remove, status_path)
    pcall(os.remove, log_path)

    local child_cmd = quote_arg(python_cmd)
        .. " " .. quote_arg(bridge_script)
        .. " " .. quote_arg(status_path)
        .. " " .. quote_arg(log_path)
        .. " 1>>" .. quote_arg(launch_log_path)
        .. " 2>&1"
    local launch_cmd = 'cmd /c "' .. child_cmd .. '"'

    backend_log("cwd=" .. tostring(cwd))
    backend_log("script_dir=" .. tostring(script_dir))
    backend_log("bridge child command: " .. child_cmd)
    backend_log("bridge launch command: " .. launch_cmd)
    print("tolk.lua: Launching Python bridge: " .. launch_cmd)
    local ok, err = pcall(function()
        bridge = io.popen(launch_cmd, "w")
    end)

    if ok and bridge then
        backend = "bridge"
        bridge_started = true
        bridge_ready = true
        last_error = nil
        backend_log("Python bridge active")
        print("tolk.lua: Python bridge active")
    else
        last_error = last_error .. "; bridge also failed: " .. tostring(err)
        backend_log("Python bridge failed: " .. tostring(err))
        print("tolk.lua: Python bridge failed: " .. tostring(err))
    end
end

-- If neither backend works, all speech calls go to FCEU.message/print
if backend == "none" then
    backend_log("No speech backend available")
    notify_fallback("WARNING: No speech backend available!")
    print("tolk.lua: No speech backend. Install Tolk.dll or Python 3.")
end

-- ============================================================
-- send_command: route speech to whichever backend is active
-- ============================================================
-- For FFI: call Tolk functions directly (in-process, instant)
-- For bridge: write command string to pipe
-- For none: FCEU.message fallback

local function send_ffi(text, interrupt)
    local ok, err = pcall(function()
        ffi_tolk.Tolk_Output(encoding.to_utf16(text), interrupt)
    end)
    if not ok then
        last_error = "FFI call failed: " .. tostring(err)
        backend_log(last_error)
        print("tolk.lua ERROR: " .. last_error)
        notify_fallback(text)
        return false
    end
    return true
end

local function send_bridge(cmd)
    if not bridge_ready or not bridge then
        return false
    end
    local ok, err = pcall(function()
        -- Lua file I/O commonly returns nil, error rather than throwing.
        -- Check both operations so a dead bridge cannot remain "ready".
        assert(bridge:write(cmd .. "\n"))
        assert(bridge:flush())
    end)
    if not ok then
        bridge_ready = false
        last_error = "bridge write failed: " .. tostring(err)
        backend_log(last_error)
        print("tolk.lua ERROR: " .. last_error)
        notify_fallback("Speech bridge unavailable")
        return false
    end
    return true
end

-- ============================================================
-- Debounce for output() only (not output_interrupt).
-- Prevents the same string from being queued multiple times within
-- a short window when two code paths fire for the same event in
-- adjacent frames. output_interrupt() is never debounced — it is
-- always intentional (hotkeys, first-page announcements).
-- ============================================================
local debounce_secs = 1.0
local last_queued_text = ""
local last_queued_time = -10000.0  -- far in the past so first call always fires
local warning_queue = warning_delivery.new({neutral_frames = 12})
local warning_event_handler = nil
local delivery_observer = nil

local function reload_config()
    config = require "config" -- main.lua may replace config while retaining this bridge
    debounce_secs = (tonumber(config.get("speech_debounce_ms")) or 1000) / 1000.0
    warning_queue:set_neutral_frames(tonumber(config.get("warning_idle_frames")) or 12)
end

reload_config()

-- ============================================================
-- Public API
-- ============================================================

local function report_warning_event(action, record, state, deferred)
    if not warning_event_handler then
        return
    end
    pcall(warning_event_handler, {
        action = action,
        id = record and record.id or nil,
        text = record and record.text or nil,
        deferred = deferred == true,
        pending_count = state and state.pending_count or 0,
        neutral_frames = state and state.neutral_frames or 0,
        neutral_frames_required = state and state.neutral_frames_required or 0,
    })
end

local function deliver(text, interrupt, metadata)
    local sent = false
    if backend == "ffi" then
        sent = send_ffi(text, interrupt)
    elseif backend == "bridge" then
        local command = interrupt and "interrupt:" or "speak:"
        sent = send_bridge(command .. text)
        if not sent then
            notify_fallback(text)
            sent = true
        end
    else
        notify_fallback(text)
        sent = true
    end

    if sent and delivery_observer then
        local event = {
            text = text,
            interrupt = interrupt == true,
            kind = metadata and metadata.kind or "speech",
            id = metadata and metadata.id or nil,
            deferred = metadata and metadata.deferred == true or false,
        }
        pcall(delivery_observer, event)
    end
    return sent
end

-- output(text): Speak text through the screen reader.
-- Does NOT interrupt speech already playing — new text is queued.
-- Suppresses duplicate text queued within speech_debounce_ms milliseconds.
local function output(text)
    if debounce_secs > 0 then
        local now = os.clock()
        if text == last_queued_text and (now - last_queued_time) < debounce_secs then
            return
        end
        last_queued_text = text
        last_queued_time = now
    end
    deliver(text, false, {kind = "speech"})
end

-- output_interrupt(text): Speak text, immediately cutting off
-- whatever the screen reader is currently saying.
-- Use this for urgent info (HP changes, position updates).
local function output_interrupt(text)
    deliver(text, true, {kind = "speech"})
end

-- output_warning(text): Preserve an important message until keyboard/controller
-- input has been neutral for warning_idle_frames.  Warnings are separate FIFO
-- records so later speech-history support can retain their original boundaries.
local function sync_travel_warnings()
    config = require "config" -- follow the current menu/config instance after Lua reload
    local cancelled = warning_queue:set_kind_enabled("travel", config.get("travel_warnings") == "true")
    for _, record in ipairs(cancelled) do
        report_warning_event("cancelled", record, warning_queue:get_state(), record.deferred)
    end
end

local function output_warning(text, interrupt, kind)
    sync_travel_warnings()
    local record = warning_queue:submit(text, {
        interrupt = interrupt ~= false,
        kind = kind or "warning",
    })
    if record then
        report_warning_event(
            "queued",
            record,
            warning_queue:get_state(),
            record.deferred == true)
    end
    return record
end

-- Called once near the start of each emulator frame, before speech-producing
-- checks.  Synthetic auto-walk input should be excluded by the caller.
local function update_warning_input(active)
    sync_travel_warnings()
    warning_queue:observe_input(active == true)
end

-- Called near the end of each emulator frame so released warnings are the last
-- speech submitted that frame.  Only the first record interrupts; later records
-- queue behind it so one deferred warning cannot erase another.
local function flush_warnings()
    sync_travel_warnings()
    local ready = warning_queue:take_ready()
    if not ready then
        return 0
    end

    for index, record in ipairs(ready) do
        local effective_interrupt = index == 1 and record.interrupt == true
        deliver(record.text, effective_interrupt, {
            kind = record.kind,
            id = record.id,
            deferred = record.deferred == true,
        })
        report_warning_event(
            "delivered",
            record,
            warning_queue:get_state(),
            record.deferred == true)
    end
    return #ready
end

-- silence(): Stop all speech immediately, without saying anything new.
local function silence()
    if backend == "ffi" then
        pcall(function() ffi_tolk.Tolk_Silence() end)
    elseif backend == "bridge" then
        send_bridge("silence")
    end
end

-- Return the public interface. Other modules do:
--   local tolk = require "tolk"
--   tolk.output("Hello")
return {
    output = output,
    output_interrupt = output_interrupt,
    output_warning = output_warning,
    output_travel_warning = function(text, interrupt)
        return output_warning(text, interrupt, "travel")
    end,
    cancel_warning = function(id)
        local record = warning_queue:cancel(id)
        if record then report_warning_event("cancelled", record, warning_queue:get_state(), record.deferred) end
        return record ~= nil
    end,
    update_warning = function(id, text)
        local record = warning_queue:update(id, text)
        if record then report_warning_event("updated", record, warning_queue:get_state(), record.deferred) end
        return record ~= nil
    end,
    update_warning_input = update_warning_input,
    flush_warnings = flush_warnings,
    silence = silence,
    reload_config = reload_config,
    set_warning_event_handler = function(handler)
        warning_event_handler = type(handler) == "function" and handler or nil
    end,
    -- Future speech-history support can subscribe here.  The observer runs only
    -- after a message is actually handed to a backend, including deferred warnings.
    set_delivery_observer = function(observer)
        delivery_observer = type(observer) == "function" and observer or nil
    end,
    get_warning_state = function()
        return warning_queue:get_state()
    end,
    -- Introspection API for debug commands
    is_available = function()
        return backend ~= "none"
    end,
    is_ready = function()
        if backend == "ffi" then
            -- Ask Tolk.dll if it's actually loaded and connected to a screen reader
            local ok, loaded = pcall(function() return ffi_tolk.Tolk_IsLoaded() end)
            return ok and loaded
        end
        if backend == "bridge" then return bridge_ready end
        return false
    end,
    is_started = function()
        if backend == "ffi" then return true end
        return bridge_started
    end,
    get_backend = function()
        return backend
    end,
    get_last_error = function()
        return last_error
    end,
}
