-- tolk.lua
-- Speech output wrapper for screen readers (NVDA, JAWS, Narrator).
--
-- Strategy: Try loading Tolk.dll directly via LuaJIT FFI first (instant,
-- zero-latency). If FFI fails (e.g., DLL missing, wrong architecture),
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
-- FCEUX bundles LuaJIT which supports ffi.cdef and ffi.load.
-- encoding.lua (already in this project) provides UTF-8 → UTF-16
-- conversion that Tolk expects for its string arguments.

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
    print("tolk.lua: FFI backend active (Tolk.dll loaded directly)")
else
    last_error = "FFI load failed: " .. tostring(ffi_err)
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
    -- Helper: resolve the Python command from config
    local function get_python_cmd()
        local python_cmd = config.get("speech_python_cmd")
        if not python_cmd or python_cmd == "" then
            return "python"
        end
        return python_cmd
    end

    local python_cmd = get_python_cmd()
    local bridge_script = script_dir .. "speech_bridge.py"
    local launch_cmd = 'python "' .. bridge_script .. '"'

    -- If a custom python command is configured, use it instead
    if python_cmd ~= "python" then
        launch_cmd = '"' .. python_cmd .. '" "' .. bridge_script .. '"'
    end

    print("tolk.lua: Launching Python bridge: " .. launch_cmd)
    local ok, err = pcall(function()
        bridge = io.popen(launch_cmd, "w")
    end)

    if ok and bridge then
        backend = "bridge"
        bridge_started = true
        bridge_ready = true
        last_error = nil
        print("tolk.lua: Python bridge active")
    else
        last_error = last_error .. "; bridge also failed: " .. tostring(err)
        print("tolk.lua: Python bridge failed: " .. tostring(err))
    end
end

-- If neither backend works, all speech calls go to FCEU.message/print
if backend == "none" then
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
