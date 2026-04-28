-- test_speech.lua
-- Minimal test to verify the tested speech path works.
-- Load this in FCEUX: File > Load Lua Script > select this file.
--
-- In the current tested qfceux.exe 2.6.6 environment this usually means the
-- Python bridge fallback, not the direct FFI path.
--
-- If everything works, you should hear "Speech bridge test successful"
-- through your screen reader. The FCEUX output pane will also show
-- status messages so you can see what's happening.

print("=== Speech Bridge Test ===")
print("")
if not FCEU then
    print("SKIP: FCEUX globals are not available; load this diagnostic script in FCEUX to run it.")
    os.exit(0)
end

-- Step 1: Try to load the tolk module (which launches speech_bridge.py)
print("Loading tolk module...")
FCEU.message("Loading tolk...")

local ok, tolk = pcall(require, "tolk")

if not ok then
    -- If require failed, tolk contains the error message
    print("FAILED to load tolk module!")
    print("Error: " .. tostring(tolk))
    FCEU.message("tolk load FAILED - check output")
else
    print("tolk module loaded successfully!")
    FCEU.message("tolk loaded OK")

    local backend = tolk.get_backend and tolk.get_backend() or "unknown"
    local ready = tolk.is_ready and tolk.is_ready() or false
    local available = tolk.is_available and tolk.is_available() or false
    local last_error = tolk.get_last_error and tolk.get_last_error() or "none"

    print("Backend:   " .. tostring(backend))
    print("Available: " .. tostring(available))
    print("Ready:     " .. tostring(ready))
    if last_error ~= nil and last_error ~= "none" then
        print("Error:     " .. tostring(last_error))
    end

    if not ready then
        print("FAILED: speech system not ready")
        FCEU.message("Speech NOT ready - check console output")
    else

        -- Step 2: Try speaking
        print("Attempting speech output...")
        FCEU.message("Attempting speech...")

        local speak_ok, speak_err = pcall(function()
            tolk.output("Speech bridge test successful. Hello from Dragon Warrior.")
        end)

        if speak_ok then
            print("Speech command sent successfully!")
            print("If you heard speech, the bridge is working.")
            FCEU.message("Speech sent - did you hear it?")
        else
            print("FAILED to send speech command!")
            print("Error: " .. tostring(speak_err))
            FCEU.message("Speech FAILED - check output")
        end
    end
end

print("")
print("=== Test complete ===")

-- Keep the emulator running
while true do
    FCEU.frameadvance()
end
