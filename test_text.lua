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

local function write_visible_row(row, value, scroll_tiles, base_nametable)
    scroll_tiles = scroll_tiles or 0
    base_nametable = base_nametable or 0
    for i = 1, #value do
        local ch = value:sub(i, i)
        local screen_col = i - 1
        local virtual_col = scroll_tiles + screen_col
        local nt_col = virtual_col % 32
        local nt_index = (base_nametable + math.floor(virtual_col / 32)) % 2
        local base = (nt_index == 0) and 0x2000 or 0x2400
        ppu_bytes[base + row * 32 + nt_col] = encode[ch] or 0x9F
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

function tests.decode_row_handles_nt1_first_horizontal_wrap()
    clear_ppu()
    write_visible_row(19, "I am greatly pleased", 22, 1)

    assert_equal(
        text.decode_row(19, 22, 1),
        "I am greatly pleased",
        "row decoder should assemble NT1-then-NT0 visible order when base nametable is NT1"
    )
end

function tests.dialogue_filter_handles_nt1_first_horizontal_wrap()
    clear_ppu()
    write_visible_row(19, "I am greatly pleased", 22, 1)
    write_visible_row(20, "that thou hast returned", 22, 1)

    assert_equal(
        text.read_dialogue_window_filtered(22, 19, 1),
        "I am greatly pleased that thou hast returned",
        "dialogue reader should preserve row text order across NT1-to-NT0 wrap"
    )
end

function tests.dialogue_filter_recovers_when_reported_base_nametable_is_stale()
    clear_ppu()
    write_visible_row(19, "'Goodbye now, Bill.", 22, 1)
    write_visible_row(20, "Take care and tempt", 22, 1)
    write_visible_row(21, "not the Fates.", 22, 1)

    assert_equal(
        text.read_dialogue_window_filtered(22, 19, 0),
        "'Goodbye now, Bill. Take care and tempt not the Fates.",
        "dialogue reader should try the alternate nametable order when the reported base misses text"
    )
end

function tests.extract_new_dialogue_strips_yesno_tail_prefix()
    local old = "'Before reaching thy next level of experience thou must gain 7 Points."
    local new = "experience thou must gain 7 Points. 'Will thou tell me now of thy deeds so they won't be forgotten?'"

    assert_equal(
        text.extract_new_dialogue(old, new),
        "'Will thou tell me now of thy deeds so they won't be forgotten?'",
        "yes/no prompt reader should strip repeated tail text from the prior dialogue page"
    )
end

function tests.extract_new_dialogue_strips_continue_question_tail_prefix()
    local old = "'Thy deeds have been recorded on the Imperial Scrolls of Honor."
    local new = "recorded on the Imperial Scrolls of Honor. 'Dost thou wish to continue thy quest?'"

    assert_equal(
        text.extract_new_dialogue(old, new),
        "'Dost thou wish to continue thy quest?'",
        "yes/no prompt reader should speak only the newly revealed continue question"
    )
end

function tests.extract_new_dialogue_keeps_farewell_after_continue_question()
    local old = "'Dost thou wish to continue thy quest?'"
    local new = "'Dost thou wish to continue thy quest?' 'Goodbye now, Bill. Take care and tempt not the Fates."

    assert_equal(
        text.extract_new_dialogue(old, new),
        "'Goodbye now, Bill. Take care and tempt not the Fates.",
        "dialogue overlap helper should keep the King's farewell after the repeated continue question"
    )
end

function tests.extract_new_dialogue_keeps_non_overlapping_text()
    assert_equal(
        text.extract_new_dialogue("'I am greatly pleased", "'Before reaching thy next level"),
        "'Before reaching thy next level",
        "dialogue overlap helper should preserve unrelated new text"
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
