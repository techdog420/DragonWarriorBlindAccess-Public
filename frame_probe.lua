-- frame_probe.lua
-- Writes a heartbeat every 60 frames so we can tell whether qfceux is
-- actually advancing frames after command-line startup.

local source = debug.getinfo(1, "S").source
local script_dir = source:match("@?(.*[\\/])") or ""
local out_path = script_dir .. "frame_probe.txt"
local frame = 0

local function write_line(text)
    local f = io.open(out_path, "a")
    if not f then return end
    f:write(text .. "\n")
    f:close()
end

os.remove(out_path)
write_line("frame_probe started")
write_line("source=" .. tostring(source))
FCEU.message("frame_probe.lua loaded")

while true do
    frame = frame + 1
    if frame % 60 == 0 then
        write_line(string.format("frame=%d", frame))
    end
    FCEU.frameadvance()
end
