-- test_speech.lua
-- Minimal test to verify the speech bridge works.
-- Load this in FCEUX: File > Load Lua Script > select this file.
--
-- If everything works, you should hear "Speech bridge test successful"
-- through your screen reader. The FCEUX output pane will also show
-- status messages so you can see what's happening.

print("=== Speech Bridge Test ===")
print("")

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

print("")
print("=== Test complete ===")

-- Keep the emulator running
while true do
    FCEU.frameadvance()
end
