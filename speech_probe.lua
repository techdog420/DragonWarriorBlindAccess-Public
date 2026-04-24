-- speech_probe.lua
-- Minimal startup probe for qfceux + tolk bridge lifetime.

local tolk = require "tolk"

tolk.output("Speech probe started.")
FCEU.message("speech_probe.lua loaded")

while true do
    FCEU.frameadvance()
end
