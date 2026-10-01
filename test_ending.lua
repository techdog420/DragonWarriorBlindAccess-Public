local ending = require "ending"
local chars = require "chars"
local function blank()
    local rows = {}
    for row = 1, 30 do
        rows[row] = {}
        for col = 1, 32 do rows[row][col] = 0x5F end
    end
    return rows
end
local function put(rows, row, value)
    for i = 1, #value do
        local c = value:byte(i)
        rows[row][i] = c == 32 and 0x5F or (c - 65 + 0x24)
    end
end
local function art(rows, row, first, count, column)
    for i = 0, count - 1 do rows[row][(column or 11) + i] = first + i end
end
local function settle(kind, value)
    local outputs = {}
    for i = 1, 40 do
        local output = ending.update(kind, value, 8)
        if output then outputs[#outputs + 1] = output end
    end
    return outputs
end

assert(ending.is_active({level=255, map_id=4, hp=149, max_hp=149}))
for _, s in ipairs({
    {level=21, map_id=4, hp=149, max_hp=149},
    {level=255, map_id=0, hp=255, max_hp=255},
    {level=255, map_id=4, hp=0, max_hp=0},
}) do assert(not ending.is_active(s), "ordinary gameplay/title must remain outside ending") end

local rows = blank()
put(rows, 10, "SCENARIO WRITTEN BY")
put(rows, 12, "YUJI HORII")
local kind, value = ending.classify(rows, chars.decode_bytes)
assert(kind == "credits" and value == "SCENARIO WRITTEN BY YUJI HORII")
ending.reset()
assert(#settle(kind, value) == 1, "stable credits should be read once")
ending.update("credits", "", 8)
assert(#settle(kind, value) == 1, "same credit can recur after a different page")

rows = blank()
-- Actual ROM illustration layout; each run is a different screen row.
art(rows, 13, 0x10, 3, 16)
art(rows, 14, 0x13, 4, 15)
art(rows, 15, 0x17, 4, 15)
art(rows, 16, 0x1B, 4, 15)
art(rows, 17, 0x1F, 4, 15)
kind, value = ending.classify(rows, chars.decode_bytes)
assert(kind == "credits" and value == "", "illustration must not speak alphabet fragments")
-- Recreate final capture, including its blank margin and second artwork row.
rows = blank()
art(rows, 14, 0x3E, 12)
kind, value = ending.classify(rows, chars.decode_bytes)
assert(kind ~= "terminal" and value == "", "partial final artwork must stay silent")
art(rows, 15, 0x4A, 12)
kind, value = ending.classify(rows, chars.decode_bytes)
assert(kind == "terminal" and value == "The End.", "live final tile fixture")
ending.reset()
local outputs = settle(kind, value)
assert(#outputs == 1 and outputs[1] == "The End.")
ending.update("credits", "", 8)
assert(#settle(kind, value) == 0, "terminal fade must not announce The End twice")
ending.reset()
assert(#settle(kind, value) == 1, "a new ending session must announce again")
rows[14][11] = 0x3D
assert(ending.classify(rows, chars.decode_bytes) ~= "terminal", "near-match must not become The End")

rows = blank()
put(rows, 12, "BASED ON DRAGON QUEST")
put(rows, 14, "COPYRIGHT ARMOR PROJECT")
kind, value = ending.classify(rows, chars.decode_bytes)
assert(kind == "credits" and value == "BASED ON DRAGON QUEST COPYRIGHT ARMOR PROJECT")
print("PASS ending: credits, artwork, terminal stability, replay, ordinary-state guards")
