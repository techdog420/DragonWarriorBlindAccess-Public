-- rom_probe.lua
-- Writes a one-shot summary of whether FCEUX exposed ROM and RAM access
-- during startup so launcher experiments can distinguish "script loaded"
-- from "game loaded".

local source = debug.getinfo(1, "S").source
local script_dir = source:match("@?(.*[\\/])") or ""
local out_path = script_dir .. "rom_probe.txt"

local function append_line(text)
    local f = io.open(out_path, "a")
    if not f then return end
    f:write(text .. "\n")
    f:close()
end

local function safe_call(label, fn, ...)
    local ok, value = pcall(fn, ...)
    append_line(string.format("%s_ok=%s", label, tostring(ok)))
    append_line(string.format("%s_value=%s", label, tostring(value)))
end

local function snapshot(tag)
    append_line("snapshot=" .. tag)
    safe_call(tag .. "_rom16", rom.readbyte, 0x10)
    safe_call(tag .. "_rom17", rom.readbyte, 0x11)
    safe_call(tag .. "_rom18", rom.readbyte, 0x12)
    safe_call(tag .. "_rom19", rom.readbyte, 0x13)
    safe_call(tag .. "_ram0", memory.readbyte, 0x0000)
    safe_call(tag .. "_ram45", memory.readbyte, 0x0045)
end

os.remove(out_path)
append_line("rom_probe started")
append_line("source=" .. tostring(source))
snapshot("startup")
FCEU.message("rom_probe.lua loaded")

local frame = 0
while true do
    frame = frame + 1
    if frame == 60 or frame == 120 or frame == 180 then
        snapshot("frame" .. frame)
    end
    FCEU.frameadvance()
end
