-- speech_frame_probe.lua
-- Uses the speech bridge log as a frame-advance heartbeat.

local tolk = require "tolk"
local frame = 0

tolk.output("Speech frame probe started.")
FCEU.message("speech_frame_probe.lua loaded")

while true do
    frame = frame + 1
    if frame == 60 or frame == 120 or frame == 180 then
        tolk.output(string.format("Speech frame probe tick %d.", frame))
    end
    FCEU.frameadvance()
end
