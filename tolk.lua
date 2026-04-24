-- tolk.lua
-- Speech output wrapper for screen readers (NVDA, JAWS, Narrator).
--
-- Strategy: Try loading Tolk.dll directly via LuaJIT FFI first (instant,
-- zero-latency). If FFI fails (e.g., DLL missing, wrong architecture, or the
-- current FCEUX build does not expose the ffi module),
-- fall back to the Python bridge (speech_bridge.py via io.popen).
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
-- Some historical/project notes assume FCEUX provides LuaJIT ffi support.
-- In the current tested Windows qfceux.exe 2.6.6 environment, require("ffi")
-- fails, so the Python bridge path is the expected runtime path unless the
-- emulator build changes.

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

    -- Load Tolk.dll from the script directory or system PATH.
    ffi_tolk = ffi.load("tolk")
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
        bridge:write(cmd .. "\n")
        bridge:flush()
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

local function reload_config()
    debounce_secs = (tonumber(config.get("speech_debounce_ms")) or 1000) / 1000.0
end

reload_config()

-- ============================================================
-- Public API
-- ============================================================

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
    if backend == "ffi" then
        send_ffi(text, false)
    elseif backend == "bridge" then
        if not send_bridge("speak:" .. text) then
            notify_fallback(text)
        end
    else
        notify_fallback(text)
    end
end

-- output_interrupt(text): Speak text, immediately cutting off
-- whatever the screen reader is currently saying.
-- Use this for urgent info (HP changes, position updates).
local function output_interrupt(text)
    if backend == "ffi" then
        send_ffi(text, true)
    elseif backend == "bridge" then
        if not send_bridge("interrupt:" .. text) then
            notify_fallback(text)
        end
    else
        notify_fallback(text)
    end
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
    silence = silence,
    reload_config = reload_config,
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
