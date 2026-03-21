-- tolk.lua
-- Speech output wrapper using a Python bridge to Tolk.dll.
--
-- FCEUX's Lua 5.1 doesn't have LuaJIT's FFI, so we can't load DLLs
-- directly from Lua. Instead, we launch a Python helper process
-- (speech_bridge.py) and send commands to it through a pipe.
--
-- The bridge reads one command per line from stdin:
--   "speak:Hello world"     -> speak without interrupting
--   "interrupt:Hello world" -> speak, cutting off current speech
--   "silence"               -> stop all speech
--
-- Requirements:
--   - Python 3 installed and on the system PATH
--   - speech_bridge.py in the same directory as this script
--   - Tolk.dll + supporting DLLs in the same directory

-- Figure out the directory this script lives in.
-- debug.getinfo(1, "S").source returns something like "@D:\modding\dragonwarrior1\tolk.lua"
-- We strip the "@" prefix and extract just the directory part.
local source = debug.getinfo(1, "S").source
local script_dir = source:match("@?(.*[\\/])") or ""

local config = require "config"

-- Launch the Python bridge process with a write-mode pipe.
-- io.popen(..., "w") gives us a file handle we can write to;
-- anything we write goes to the bridge's stdin.
local bridge = io.popen('python "' .. script_dir .. 'speech_bridge.py"', "w")

-- If the bridge failed to launch, set up dummy functions that just
-- use FCEU.message() as a fallback (visible on screen, not spoken).
if not bridge then
    FCEU.message("ERROR: Could not launch speech bridge!")
    print("ERROR: Could not launch speech_bridge.py")
    print("Make sure Python 3 is installed and in your PATH.")
    return {
        output = function(text) FCEU.message(text) end,
        output_interrupt = function(text) FCEU.message(text) end,
        silence = function() end,
    }
end

-- send_command(cmd): Write a command line to the bridge process.
-- Each command must end with a newline. We flush after every write
-- to ensure the bridge receives it immediately (no buffering delay).
local function send_command(cmd)
    bridge:write(cmd .. "\n")
    bridge:flush()
end

-- Debounce for output() only (not output_interrupt).
-- Prevents the same string from being queued multiple times within a short
-- window when two code paths happen to fire for the same event in adjacent
-- frames. output_interrupt() is never debounced — it is always intentional
-- (hotkeys, first-page announcements) and the caller expects it to fire.
local debounce_secs = (tonumber(config.get("speech_debounce_ms")) or 1000) / 1000.0
local last_queued_text = ""
local last_queued_time = -10000.0  -- far in the past so the first call always fires

-- output(text): Speak text through the screen reader.
-- Does NOT interrupt speech that's already playing — new text
-- is queued after the current utterance finishes.
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
    send_command("speak:" .. text)
end

-- output_interrupt(text): Speak text, immediately cutting off
-- whatever the screen reader is currently saying.
-- Use this for urgent info (HP changes, position updates).
local function output_interrupt(text)
    send_command("interrupt:" .. text)
end

-- silence(): Stop all speech immediately, without saying anything new.
local function silence()
    send_command("silence")
end

-- Return the public interface. Other modules do:
--   local tolk = require "tolk"
--   tolk.output("Hello")
return {
    output = output,
    output_interrupt = output_interrupt,
    silence = silence,
}
