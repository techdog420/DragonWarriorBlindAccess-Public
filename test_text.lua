-- test_text.lua
-- Focused regression tests for dialogue/status text filtering.

local original_ppu = ppu
local original_loaded_text = package.loaded["text"]
package.loaded["text"] = nil

local chars = require "chars"

local encode = {}
for byte, ch in pairs(chars.decode) do
    if #ch == 1 and encode[ch] == nil then
        encode[ch] = byte
    end
end

local ppu_bytes = {}
ppu = {
    readbyte = function(addr)
        return ppu_bytes[addr] or 0x9F
    end,
}

local text = require "text"

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %q, got %q", message, tostring(expected), tostring(actual)), 2)
    end
end

local function assert_true(actual, message)
    if not actual then
        error(message, 2)
    end
end

local function clear_ppu()
    ppu_bytes = {}
end

local function write_row(row, value)
    for i = 1, #value do
        local ch = value:sub(i, i)
        local col = i - 1
        local base = col < 32 and 0x2000 or 0x2400
        ppu_bytes[base + row * 32 + (col % 32)] = encode[ch] or 0x9F
    end
end

local tests = {}

function tests.status_text_accepts_lowercase_name()
    assert_true(
        text.is_status_text("Bill LV   1 HP  15 MP   0 G  120 E    0"),
        "status detector should catch lowercase hero names"
    )
end

function tests.dialogue_filter_skips_status_only_row()
    clear_ppu()
    write_row(19, "Bill LV   1 HP  15 MP   0 G  120 E    0")

    assert_equal(
        text.read_dialogue_window_filtered(0, 19),
        "",
        "lower dialogue reader should ignore persistent status rows"
    )
end

function tests.dialogue_filter_keeps_real_bill_dialogue()
    clear_ppu()
    write_row(19, "Bill LV   1 HP  15 MP   0 G  120 E    0")
    write_row(20, "Bill, please save the Princess.")

    assert_equal(
        text.read_dialogue_window_filtered(0, 19),
        "Bill, please save the Princess.",
        "status filtering should not suppress real dialogue with the hero name"
    )
end

local failures = 0
local total = 0

for name, fn in pairs(tests) do
    total = total + 1
    local ok, err = pcall(fn)
    if ok then
        io.write(string.format("PASS  %s\n", name))
    else
        failures = failures + 1
        io.write(string.format("FAIL  %s: %s\n", name, tostring(err)))
    end
end

io.write(string.format("Ran %d Lua unit tests\n", total))

ppu = original_ppu
package.loaded["text"] = original_loaded_text

if failures > 0 then
    os.exit(1)
end
