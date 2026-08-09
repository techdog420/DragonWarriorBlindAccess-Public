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

local function write_visible_tile(row, screen_col, byte, scroll_tiles, base_nametable)
    scroll_tiles = scroll_tiles or 0
    base_nametable = base_nametable or 0
    local virtual_col = scroll_tiles + screen_col
    local nt_col = virtual_col % 32
    local nt_index = (base_nametable + math.floor(virtual_col / 32)) % 2
    local base = (nt_index == 0) and 0x2000 or 0x2400
    ppu_bytes[base + row * 32 + nt_col] = byte
end

local function write_scrolled_base_fragment(row, base_nametable, scroll_tiles, value)
    local base = (base_nametable == 0) and 0x2000 or 0x2400
    for i = 1, #value do
        local ch = value:sub(i, i)
        ppu_bytes[base + row * 32 + scroll_tiles + i - 1] = encode[ch] or 0x9F
    end
end

local tests = {}

function tests.dialogue_filter_strips_gold_placeholder_from_talk_result()
    clear_ppu()
    write_visible_row(23, "There is no one       there.", 16, 0)
    write_visible_tile(23, 20, 0xF5, 16, 0)

    assert_equal(
        text.read_dialogue_window_filtered(16, 23, 0),
        "There is no one there.",
        "literal GOLD placeholder tiles should not contaminate TALK results"
    )
end

function tests.dialogue_filter_strips_gold_placeholder_from_stairs_result()
    clear_ppu()
    write_visible_row(23, "There are no stairs    here.", 16, 0)
    write_visible_tile(23, 20, 0xF5, 16, 0)

    assert_equal(
        text.read_dialogue_window_filtered(16, 23, 0),
        "There are no stairs here.",
        "literal GOLD placeholder tiles should not contaminate STAIRS results"
    )
end

function tests.status_text_accepts_lowercase_name()
    assert_true(
        text.is_status_text("Bill LV   1 HP  15 MP   0 G  120 E    0"),
        "status detector should catch lowercase hero names"
    )
end

function tests.status_text_accepts_scrolled_fragmented_status_display()
    assert_true(
        text.is_status_text("Bi V P P 21 12 Bill LV  15"),
        "status detector should catch scrolled status rows split into fragments"
    )
end

function tests.status_text_accepts_command_menu_scroll_status_fragments()
    for _, fragment in ipairs({
        "V  15 llHP  86 1MP  54 8G21530 5E12610 530 610 Bill",
        "L llH 1M 8G 5E 530 610 Bill",
        "llH 1M 8G 5E 530 610 Bill",
    }) do
        assert_true(
            text.is_status_text(fragment),
            "status detector should catch command-menu scroll status fragment: " .. fragment
        )
    end
end

function tests.status_text_keeps_real_dialogue_with_hp_word()
    assert_equal(
        text.is_status_text("Low HP"),
        false,
        "ordinary dialogue mentioning HP should not be status text"
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

function tests.dialogue_filter_keeps_levelup_numeric_continuation_row()
    clear_ppu()
    write_visible_row(19, "Thy power increases by", 0, 0)
    write_visible_row(20, "4.", 0, 0)
    write_visible_row(21, "Thy Response Speed", 0, 0)
    write_visible_row(22, "increases by 6.", 0, 0)

    assert_equal(
        text.read_dialogue_window_filtered(0, 19, 0),
        "Thy power increases by 4. Thy Response Speed increases by 6.",
        "lower dialogue reader should preserve numeric-only level-up stat values"
    )
end

function tests.dialogue_filter_keeps_uppercase_spell_name_continuation()
    clear_ppu()
    write_visible_row(19, "Wizard chants the spell of", 0, 0)
    write_visible_row(20, "HURTMORE.", 0, 0)
    write_visible_row(22, "But that spell hath", 0, 0)
    write_visible_row(23, "been blocked.", 0, 0)

    assert_equal(
        text.read_dialogue_window_filtered(0, 19, 0),
        "Wizard chants the spell of HURTMORE. But that spell hath been blocked.",
        "standalone uppercase spell names should remain in battle dialogue"
    )
end

function tests.dialogue_filter_skips_wrapped_status_name_fragment()
    clear_ppu()
    write_visible_row(1, "Bill", 8, 0)
    write_visible_row(2, "LV  1 HP  8 MP  6 G2148 E1258", 8, 0)

    assert_equal(
        text.read_dialogue_window_filtered(8, 25, 0),
        "",
        "wrapped lower dialogue reader should ignore the player-name status fragment"
    )
end

function tests.dialogue_filter_skips_wrapped_split_status_name_fragment()
    clear_ppu()
    write_visible_row(2, "Bill", 8, 0)
    write_visible_row(4, "LV  1", 8, 0)

    assert_equal(
        text.read_dialogue_window_filtered(8, 25, 0),
        "",
        "wrapped lower dialogue reader should ignore name fragments near split status rows"
    )
end

function tests.dialogue_filter_skips_cross_nametable_split_status_name_fragment()
    clear_ppu()
    write_scrolled_base_fragment(2, 0, 6, "Bi")
    write_scrolled_base_fragment(2, 1, 6, "ll")
    write_scrolled_base_fragment(4, 0, 6, "LV")
    write_scrolled_base_fragment(6, 0, 6, "HP")
    write_scrolled_base_fragment(8, 0, 6, "MP")
    write_scrolled_base_fragment(10, 0, 6, "G21")
    write_scrolled_base_fragment(4, 1, 6, "15")
    write_scrolled_base_fragment(6, 1, 6, "86")
    write_scrolled_base_fragment(8, 1, 6, "64")
    write_scrolled_base_fragment(10, 1, 6, "489")

    assert_equal(
        text.read_dialogue_window_filtered(6, 1, 0),
        "",
        "alternate nametable fallback should ignore split status-name fragments"
    )
end

function tests.dialogue_filter_skips_reported_base_split_status_name_fragment()
    clear_ppu()
    write_scrolled_base_fragment(2, 0, 6, "Bi")
    write_scrolled_base_fragment(2, 1, 6, "ll")
    write_scrolled_base_fragment(4, 0, 6, "LV")
    write_scrolled_base_fragment(6, 0, 6, "HP")
    write_scrolled_base_fragment(8, 0, 6, "MP")
    write_scrolled_base_fragment(10, 0, 6, "G21")
    write_scrolled_base_fragment(4, 1, 6, "15")
    write_scrolled_base_fragment(6, 1, 6, "86")
    write_scrolled_base_fragment(8, 1, 6, "64")
    write_scrolled_base_fragment(10, 1, 6, "489")

    assert_equal(
        text.read_dialogue_window_filtered(6, 1, 1),
        "",
        "reported nametable base should ignore its own split status-name fragment"
    )
end

function tests.dialogue_filter_skips_live_scrolled_status_name_fragment()
    clear_ppu()
    write_scrolled_base_fragment(2, 0, 6, "Bi")
    write_scrolled_base_fragment(2, 1, 6, "ll")
    write_scrolled_base_fragment(4, 0, 6, "V")
    write_scrolled_base_fragment(6, 0, 6, "P")
    write_scrolled_base_fragment(8, 0, 6, "P")
    write_scrolled_base_fragment(10, 0, 6, "21")
    write_scrolled_base_fragment(4, 1, 6, "15")
    write_scrolled_base_fragment(6, 1, 6, "86")
    write_scrolled_base_fragment(8, 1, 6, "64")
    write_scrolled_base_fragment(10, 1, 6, "489")

    assert_equal(
        text.read_dialogue_window_filtered(6, 1, 0),
        "",
        "live scrolled status fragments should not announce the alternate-base name suffix"
    )
end

function tests.dialogue_filter_skips_scroll_wrapped_status_name_fragment()
    clear_ppu()
    write_scrolled_base_fragment(2, 0, 6, "Bi")
    write_scrolled_base_fragment(2, 1, 6, "ll")
    write_scrolled_base_fragment(4, 0, 6, "V")
    write_scrolled_base_fragment(6, 0, 6, "P")
    write_scrolled_base_fragment(8, 0, 6, "P")
    write_scrolled_base_fragment(4, 1, 6, "15")
    write_scrolled_base_fragment(6, 1, 6, "86")
    write_scrolled_base_fragment(8, 1, 6, "64")

    assert_equal(
        text.read_dialogue_window_filtered(6, 29, 0),
        "",
        "scroll-wrapped status labels should suppress the alternate-base name suffix"
    )
end

function tests.dialogue_filter_skips_cross_base_status_context_name_fragment()
    clear_ppu()
    write_scrolled_base_fragment(2, 0, 6, "Bi")
    write_scrolled_base_fragment(2, 1, 6, "ll")
    write_scrolled_base_fragment(4, 0, 6, "V")
    write_scrolled_base_fragment(6, 0, 6, "P")
    write_scrolled_base_fragment(4, 1, 6, "15")
    write_scrolled_base_fragment(6, 1, 6, "86")

    assert_equal(
        text.read_dialogue_window_filtered(6, 27, 0),
        "",
        "split labels and values across nametable bases should suppress name suffix fragments"
    )
end

function tests.dialogue_filter_skips_scroll_phase_split_name_with_one_status_pair()
    clear_ppu()
    write_scrolled_base_fragment(2, 0, 6, "Bi")
    write_scrolled_base_fragment(2, 1, 6, "ll")
    write_scrolled_base_fragment(4, 0, 6, "V")
    write_scrolled_base_fragment(4, 1, 6, "15")

    assert_equal(
        text.read_dialogue_window_filtered(6, 25, 0),
        "",
        "split name plus a nearby split status label/value should not announce during vertical scroll"
    )
end

function tests.dialogue_filter_skips_clipped_label_value_status_rows()
    clear_ppu()
    write_scrolled_base_fragment(2, 1, 6, "Bill")
    write_scrolled_base_fragment(4, 1, 6, "V  15")
    write_scrolled_base_fragment(6, 1, 6, "P  86")

    assert_equal(
        text.read_dialogue_window_filtered(6, 27, 1),
        "",
        "clipped status label/value rows should suppress nearby name rows"
    )
end

function tests.dialogue_filter_uses_upper_status_context_when_lower_scan_only_has_name()
    clear_ppu()
    write_scrolled_base_fragment(2, 0, 6, "Bi")
    write_scrolled_base_fragment(2, 1, 6, "ll")
    write_scrolled_base_fragment(4, 0, 6, "V")
    write_scrolled_base_fragment(6, 0, 6, "P")
    write_scrolled_base_fragment(8, 0, 6, "P")
    write_scrolled_base_fragment(10, 0, 6, "21")
    write_scrolled_base_fragment(4, 1, 6, "15")
    write_scrolled_base_fragment(6, 1, 6, "86")
    write_scrolled_base_fragment(8, 1, 6, "53")
    write_scrolled_base_fragment(10, 1, 6, "489")

    assert_equal(
        text.read_dialogue_window_filtered(6, 23, 0),
        "",
        "status-name fragments should use upper status rows for context when vertical scroll hides markers from the lower scan"
    )
end

function tests.dialogue_filter_skips_fused_name_suffix_status_value_row()
    clear_ppu()
    write_scrolled_base_fragment(2, 0, 6, "Bi")
    write_scrolled_base_fragment(2, 1, 6, "ll")
    write_scrolled_base_fragment(4, 0, 6, "llHP  86")
    write_scrolled_base_fragment(6, 0, 6, "1MP  54")
    write_scrolled_base_fragment(8, 0, 6, "8G21530")
    write_scrolled_base_fragment(10, 0, 6, "5E12610")
    write_scrolled_base_fragment(12, 0, 6, "530")
    write_scrolled_base_fragment(4, 1, 6, "LV")
    write_scrolled_base_fragment(6, 1, 6, "HP")
    write_scrolled_base_fragment(8, 1, 6, "MP")
    write_scrolled_base_fragment(10, 1, 6, "G21")

    assert_equal(
        text.read_dialogue_window_filtered(6, 3, 0),
        "",
        "status rows with a fused hero-name suffix should not become lower dialogue"
    )
end

function tests.dialogue_filter_strips_inline_status_fragment_from_real_command_result()
    clear_ppu()
    write_scrolled_base_fragment(2, 0, 6, "Bi")
    write_scrolled_base_fragment(2, 1, 6, "ll")
    write_scrolled_base_fragment(4, 0, 6, "llH")
    write_scrolled_base_fragment(6, 0, 6, "1M")
    write_scrolled_base_fragment(8, 0, 6, "8G")
    write_scrolled_base_fragment(10, 0, 6, "5E")
    write_scrolled_base_fragment(4, 1, 6, "LV")
    write_scrolled_base_fragment(6, 1, 6, "HP")
    write_scrolled_base_fragment(8, 1, 6, "MP")
    write_scrolled_base_fragment(10, 1, 6, "G21")
    write_visible_row(27, "'There is no one llH there.", 6, 0)

    assert_equal(
        text.read_dialogue_window_filtered(6, 23, 0),
        "'There is no one there.",
        "inline scrolled status fragments should be stripped from real command results"
    )
end

function tests.dialogue_filter_strips_status_prefix_glued_to_spell_text()
    clear_ppu()
    write_scrolled_base_fragment(2, 0, 6, "Bi")
    write_scrolled_base_fragment(2, 1, 6, "ll")
    write_scrolled_base_fragment(4, 0, 6, "llH")
    write_scrolled_base_fragment(6, 0, 6, "1M")
    write_scrolled_base_fragment(8, 0, 6, "8G")
    write_scrolled_base_fragment(10, 0, 6, "5E")
    write_scrolled_base_fragment(4, 1, 6, "LV")
    write_scrolled_base_fragment(6, 1, 6, "HP")
    write_scrolled_base_fragment(8, 1, 6, "MP")
    write_scrolled_base_fragment(10, 1, 6, "G21")
    write_visible_row(27, "Bill chanted llHof HURT.", 6, 0)
    write_visible_row(28, "1MBut nothing happened.", 6, 0)

    assert_equal(
        text.read_dialogue_window_filtered(6, 23, 0),
        "Bill chanted of HURT. But nothing happened.",
        "status prefixes glued to spell dialogue should be stripped without dropping the real words"
    )
end

function tests.dialogue_filter_strips_split_status_label_values_from_live_npc_text()
    clear_ppu()
    write_visible_row(2, "Bill", 24, 0)
    write_visible_row(4, "LV  15", 24, 0)
    write_visible_row(6, "HP  86", 24, 0)
    write_visible_row(8, "MP  64", 24, 0)
    write_visible_row(10, "G22345", 24, 0)
    write_visible_row(12, "E12981", 24, 0)
    write_visible_row(13, "'It is said that the", 24, 0)
    write_visible_row(14, "P  8 Princess was", 24, 0)
    write_visible_row(15, "kidnapped and taken", 24, 0)
    write_visible_row(16, "P  6 eastward.", 24, 0)

    assert_equal(
        text.read_dialogue_window_filtered(24, 13, 0),
        "'It is said that the Princess was kidnapped and taken eastward.",
        "split status label/value crumbs should not leak into scrolled NPC dialogue"
    )
end

function tests.dialogue_filter_strips_gold_exp_status_tokens_from_live_npc_text()
    clear_ppu()
    write_visible_row(2, "Bill", 8, 0)
    write_visible_row(4, "LV  15", 8, 0)
    write_visible_row(6, "HP  86", 8, 0)
    write_visible_row(8, "MP  64", 8, 0)
    write_visible_row(10, "G22345", 8, 0)
    write_visible_row(12, "E12981", 8, 0)
    write_visible_row(23, "I hate people! G22 Go!", 8, 0)
    write_visible_row(24, "Once there was a town E12", 8, 0)
    write_visible_row(25, "called Hauksness.", 8, 0)

    assert_equal(
        text.read_dialogue_window_filtered(8, 23, 0),
        "I hate people! Go! Once there was a town called Hauksness.",
        "G/E status-value crumbs should be stripped from otherwise real dialogue"
    )
end

function tests.dialogue_filter_strips_split_numeric_status_values_from_live_npc_text()
    clear_ppu()
    write_visible_row(2, "Bill", 8, 0)
    write_visible_row(4, "LV  15", 8, 0)
    write_visible_row(6, "HP  86", 8, 0)
    write_visible_row(8, "MP  64", 8, 0)
    write_visible_row(10, "G22345", 8, 0)
    write_visible_row(12, "E12981", 8, 0)
    write_visible_row(23, "'The harp attracts 4 1", 8, 0)
    write_visible_row(24, "enemies. Stay away from", 8, 0)
    write_visible_row(25, "the grave in Garinham.", 8, 0)

    assert_equal(
        text.read_dialogue_window_filtered(8, 23, 0),
        "'The harp attracts enemies. Stay away from the grave in Garinham.",
        "split numeric status values should not leak into scrolled NPC dialogue"
    )
end

function tests.dialogue_filter_strips_single_numeric_status_slices_from_command_results()
    clear_ppu()
    write_visible_row(2, "Bill", 0, 0)
    write_visible_row(4, "LV  16", 0, 0)
    write_visible_row(6, "HP  92", 0, 0)
    write_visible_row(8, "MP  63", 0, 0)
    write_visible_row(10, "G 1520", 0, 0)
    write_visible_row(12, "E13994", 0, 0)
    write_visible_row(23, "Bill searched the ground", 0, 0)
    write_visible_row(24, "all about. 6", 0, 0)
    write_visible_row(25, "But there found 152 nothing.", 0, 0)

    assert_equal(
        text.read_dialogue_window_filtered(0, 23, 0),
        "Bill searched the ground all about. But there found nothing.",
        "single numeric status slices should not leak into command-result dialogue"
    )
end

function tests.dialogue_filter_strips_middle_numeric_status_slice_from_command_result()
    clear_ppu()
    write_visible_row(2, "Bill", 0, 0)
    write_visible_row(4, "LV  16", 0, 0)
    write_visible_row(6, "HP  92", 0, 0)
    write_visible_row(8, "MP  63", 0, 0)
    write_visible_row(10, "G 1520", 0, 0)
    write_visible_row(12, "E13994", 0, 0)
    write_visible_row(23, "But there found 52 nothing.", 0, 0)

    assert_equal(
        text.read_dialogue_window_filtered(0, 23, 0),
        "But there found nothing.",
        "middle numeric status slices should not leak into command-result dialogue"
    )
end

function tests.dialogue_filter_strips_numeric_slice_with_fused_live_status_context()
    clear_ppu()
    write_visible_row(2, "HP  92LV  16", 0, 0)
    write_visible_row(4, "MP  63HP  92", 0, 0)
    write_visible_row(6, "G 1520 BillL", 0, 0)
    write_visible_row(8, "LV  16 HP  92", 0, 0)
    write_visible_row(10, "MP  63 G 1520", 0, 0)
    write_visible_row(12, "E13994ll", 0, 0)
    write_visible_row(23, "But there found 52 nothing.", 0, 0)

    assert_equal(
        text.read_dialogue_window_filtered(0, 23, 0),
        "But there found nothing.",
        "fused live status rows should activate numeric-slice filtering"
    )
end

function tests.dialogue_filter_strips_live_search_status_fragments_without_exp_context()
    clear_ppu()
    write_visible_row(2, "LV  16 STATUS ITEM", 0, 0)
    write_visible_row(4, "HP  92 STAIRS DOOR", 0, 0)
    write_visible_row(6, "MP  63 SEARCH TAKE", 0, 0)
    write_visible_row(8, "G 1520", 0, 0)
    write_visible_row(23, "Bill searched the ground", 0, 0)
    write_visible_row(24, "all about. 99", 0, 0)
    write_visible_row(25, "LBut there found", 0, 0)
    write_visible_row(26, "nothing.", 0, 0)

    assert_equal(
        text.read_dialogue_window_filtered(0, 23, 0),
        "Bill searched the ground all about. But there found nothing.",
        "live search fragments should be removed when the EXP row is not in status context"
    )
end

function tests.dialogue_filter_keeps_words_beginning_with_status_letters()
    clear_ppu()
    write_visible_row(2, "LV  16", 0, 0)
    write_visible_row(4, "MP  63", 0, 0)
    write_visible_row(6, "G 1520", 0, 0)
    write_visible_row(23, "Lancelot arrived.", 0, 0)

    assert_equal(
        text.read_dialogue_window_filtered(0, 23, 0),
        "Lancelot arrived.",
        "ordinary words beginning with a status letter should remain intact"
    )
end

function tests.dialogue_filter_keeps_semantic_numbers_with_status_context()
    clear_ppu()
    write_visible_row(2, "Bill", 0, 0)
    write_visible_row(4, "LV  16", 0, 0)
    write_visible_row(6, "HP  92", 0, 0)
    write_visible_row(8, "MP  63", 0, 0)
    write_visible_row(10, "G  120", 0, 0)
    write_visible_row(12, "E13994", 0, 0)
    write_visible_row(23, "Of GOLD thou hast gained 12", 0, 0)
    write_visible_row(24, "Thy power increases by 6.", 0, 0)
    write_visible_row(25, "Wilt thou buy it for 52 GOLD?", 0, 0)

    assert_equal(
        text.read_dialogue_window_filtered(0, 23, 0),
        "Of GOLD thou hast gained 12 Thy power increases by 6. Wilt thou buy it for 52 GOLD?",
        "real reward and stat numbers should survive while status rows are visible"
    )
end

function tests.dialogue_filter_skips_live_compact_status_residue_after_menu_clear()
    clear_ppu()
    write_visible_row(2, "HP  86", 28, 0)
    write_visible_row(4, "MP  64", 28, 0)
    write_visible_row(6, "G22345", 28, 0)
    write_visible_row(8, "E12981", 28, 0)
    write_visible_row(14, "E12HP  8", 28, 1)
    write_visible_row(16, "IvyMP  6", 28, 1)
    write_visible_row(18, "IvyG2234", 28, 1)
    write_visible_row(20, "LV  15E1298", 28, 1)
    write_visible_row(22, "HP  86", 28, 1)

    assert_equal(
        text.read_dialogue_window_filtered(28, 13, 0),
        "",
        "compact status residue should not keep lower dialogue active after the menu clears"
    )
end

function tests.dialogue_filter_strips_derived_name_fragment_suffix_from_real_dialogue()
    clear_ppu()
    write_scrolled_base_fragment(2, 0, 6, "Iv")
    write_scrolled_base_fragment(2, 1, 6, "y")
    write_scrolled_base_fragment(4, 0, 6, "V")
    write_scrolled_base_fragment(6, 0, 6, "P")
    write_scrolled_base_fragment(8, 0, 6, "P")
    write_scrolled_base_fragment(10, 0, 6, "21")
    write_scrolled_base_fragment(4, 1, 6, "15")
    write_scrolled_base_fragment(6, 1, 6, "86")
    write_scrolled_base_fragment(8, 1, 6, "53")
    write_scrolled_base_fragment(10, 1, 6, "489")
    write_scrolled_base_fragment(27, 0, 6, "Ivy searched the ground")
    write_scrolled_base_fragment(28, 0, 6, "all about.")

    assert_equal(
        text.read_dialogue_window_filtered(6, 23, 0),
        "Ivy searched the ground all about.",
        "status-derived name fragments should be stripped after real dialogue"
    )
end

function tests.dialogue_filter_strips_derived_split_name_prefix_from_real_dialogue()
    clear_ppu()
    write_scrolled_base_fragment(2, 0, 6, "I")
    write_scrolled_base_fragment(2, 1, 6, "vy")
    write_scrolled_base_fragment(4, 0, 6, "V")
    write_scrolled_base_fragment(6, 0, 6, "P")
    write_scrolled_base_fragment(8, 0, 6, "P")
    write_scrolled_base_fragment(10, 0, 6, "21")
    write_scrolled_base_fragment(4, 1, 6, "15")
    write_scrolled_base_fragment(6, 1, 6, "86")
    write_scrolled_base_fragment(8, 1, 6, "53")
    write_scrolled_base_fragment(10, 1, 6, "489")
    write_scrolled_base_fragment(27, 0, 6, "vy searched the ground")
    write_scrolled_base_fragment(28, 0, 6, "all about.")

    assert_equal(
        text.read_dialogue_window_filtered(6, 23, 0),
        "searched the ground all about.",
        "status-derived split-name prefixes should not contaminate real dialogue"
    )
end

function tests.dialogue_filter_skips_derived_full_name_row_with_status_context()
    clear_ppu()
    write_visible_row(2, "Ivy", 8, 0)
    write_visible_row(4, "V  1", 8, 0)
    write_visible_row(6, "P  8", 8, 0)
    write_visible_row(8, "P  6", 8, 0)
    write_visible_row(10, "LV  15", 8, 0)
    write_visible_row(12, "HP  86", 8, 0)
    write_visible_row(14, "MP  51", 8, 0)
    write_visible_row(16, "G21489", 8, 0)

    assert_equal(
        text.read_dialogue_window_filtered(8, 23, 0),
        "",
        "a visible status-context hero-name row should not announce as dialogue"
    )
end

function tests.dialogue_filter_skips_arbitrary_short_status_name_rows()
    for _, name in ipairs({"Ivy", "Rex", "Ada", "Zed"}) do
        clear_ppu()
        write_visible_row(2, name, 8, 0)
        write_visible_row(4, "V  1", 8, 0)
        write_visible_row(6, "P  8", 8, 0)
        write_visible_row(8, "P  6", 8, 0)
        write_visible_row(10, "LV  15", 8, 0)
        write_visible_row(12, "HP  86", 8, 0)
        write_visible_row(14, "MP  51", 8, 0)
        write_visible_row(16, "G21489", 8, 0)

        assert_equal(
            text.read_dialogue_window_filtered(8, 23, 0),
            "",
            "visible status-context hero-name row should not announce for " .. name
        )
    end
end

function tests.dialogue_filter_skips_standalone_gold_map_noise_with_status_context()
    clear_ppu()
    write_visible_row(2, "Ivy", 8, 0)
    write_visible_row(4, "V  1", 8, 0)
    write_visible_row(6, "P  8", 8, 0)
    write_visible_row(8, "P  6", 8, 0)
    write_visible_row(10, "LV  15", 8, 0)
    write_visible_row(12, "HP  86", 8, 0)
    write_visible_row(14, "MP  51", 8, 0)
    write_visible_row(16, "G21489", 8, 0)
    write_visible_row(23, "Gold", 8, 0)

    assert_equal(
        text.read_dialogue_window_filtered(8, 23, 0),
        "",
        "standalone Gold map/status noise should not announce while status context is visible"
    )
end

function tests.dialogue_filter_keeps_gold_reward_text()
    clear_ppu()
    write_row(19, "Of GOLD thou hast gained 12")

    assert_equal(
        text.read_dialogue_window_filtered(0, 19, 0),
        "Of GOLD thou hast gained 12",
        "gold reward text should stay readable when it is part of a real sentence"
    )
end

function tests.passive_field_status_noise_detects_name_and_gold_tokens()
    for _, fragment in ipairs({"Bill", "Ivy", "Rex", "Ada", "Zed", "Gold"}) do
        assert_equal(
            text.is_passive_field_status_noise(fragment),
            true,
            "passive field scanner should classify standalone status/name artifact " .. fragment
        )
    end
end

function tests.passive_field_status_noise_detects_digit_prefixed_name_tokens()
    for _, fragment in ipairs({"16Bill", "92Ivy", "1520Bill3"}) do
        assert_equal(
            text.is_passive_field_status_noise(fragment),
            true,
            "passive field scanner should classify digit-prefixed status/name artifact " .. fragment
        )
    end
end

function tests.passive_field_status_noise_detects_fused_exp_value_and_name()
    assert_equal(
        text.is_passive_field_status_noise("EE13994Bill"),
        true,
        "passive field scanner should classify the live EXP/name scroll artifact"
    )
end

function tests.passive_field_status_noise_detects_split_name_suffixes()
    for _, fragment in ipairs({"bi", "ll", "vy"}) do
        assert_equal(
            text.is_passive_field_status_noise(fragment),
            true,
            "passive field scanner should classify lowercase split-name suffix artifact " .. fragment
        )
    end
end

function tests.passive_field_status_noise_detects_fused_name_status_label()
    assert_equal(
        text.is_passive_field_status_noise("llE"),
        true,
        "passive field scanner should classify the live fused name/status fragment"
    )
end

function tests.dialogue_filter_strips_wrapped_fused_name_status_suffix_from_real_dialogue()
    clear_ppu()
    write_visible_row(29, "Bill searched the ground", 0, 1)
    write_visible_row(0, "all about.", 0, 1)
    write_visible_row(8, "llE", 0, 1)

    assert_equal(
        text.read_dialogue_window_filtered(0, 29, 1),
        "Bill searched the ground all about.",
        "wrapped fused name/status residue should be removed from real command-result dialogue"
    )
end

function tests.passive_field_status_noise_detects_fused_status_value_rows()
    for _, fragment in ipairs({"llHP  86", "vyMP  54", "rexP  86", "ivyV  15"}) do
        assert_equal(
            text.is_passive_field_status_noise(fragment),
            true,
            "passive field scanner should classify fused status value artifact " .. fragment
        )
    end
end

function tests.passive_field_status_noise_detects_live_spaced_value_suffix()
    for _, fragment in ipairs({"MP 63ll", "MP 63vy", "HP 92ex", "LV 16da"}) do
        assert_equal(
            text.is_passive_field_status_noise(fragment),
            true,
            "passive field scanner should classify status values with arbitrary name tails: " .. fragment
        )
    end
end

function tests.passive_field_status_noise_detects_compact_gold_exp_residue_rows()
    for _, fragment in ipairs({"BillG2234", "IvyE1298", "RexG42"}) do
        assert_equal(
            text.is_passive_field_status_noise(fragment),
            true,
            "passive field scanner should classify compact gold/exp status residue " .. fragment
        )
    end
end

function tests.passive_field_status_noise_detects_spaced_status_residue_rows()
    for _, fragment in ipairs({"Bill 6", "E Bill", "Billll LV  15 1", "MBill GLV  15", "MIvy GLV  15"}) do
        assert_equal(
            text.is_passive_field_status_noise(fragment),
            true,
            "passive field scanner should classify spaced status residue " .. fragment
        )
    end
end

function tests.passive_field_status_noise_detects_multi_token_shop_status_residue()
    for _, fragment in ipairs({
        "G25008 E13994 ll 16 ll 16",
        "MP  63 G25008 llE13994 16 ll 16",
        "G25008 E13994 V  16 Bi LV",
        "BillE13E1399 16Bill",
    }) do
        assert_equal(
            text.is_passive_field_status_noise(fragment),
            true,
            "passive field scanner should classify multi-token shop status residue: " .. fragment
        )
    end
end

function tests.passive_field_status_noise_keeps_real_dialogue()
    for _, line in ipairs({
        "Bill chanted the spell of STOPSPELL.",
        "Of GOLD thou hast gained 12",
        "Welcome.",
        "Low HP",
    }) do
        assert_equal(
            text.is_passive_field_status_noise(line),
            false,
            "passive field scanner should not classify real dialogue as status noise: " .. line
        )
    end
end

function tests.upper_dialogue_marker_prefers_clean_lower_dialogue_when_command_status_overlay_visible()
    local upper = "'There is no one there. COMMAND BillTALK    SPELL LV  16 STATUS  ITEM"
    local lower = "'There is no one there."

    assert_equal(
        text.upper_marker_for_lower_dialogue(upper, lower),
        lower,
        "upper-dialogue guard should remember the clean lower text, not command/status overlay noise"
    )
end

function tests.dialogue_filter_strips_separate_status_name_row_from_real_dialogue()
    clear_ppu()
    write_scrolled_base_fragment(27, 0, 6, "Bill searched the ground")
    write_scrolled_base_fragment(28, 0, 6, "all about.")
    write_scrolled_base_fragment(2, 0, 6, "Bi")
    write_scrolled_base_fragment(2, 1, 6, "ll")
    write_scrolled_base_fragment(4, 0, 6, "V")
    write_scrolled_base_fragment(6, 0, 6, "P")
    write_scrolled_base_fragment(4, 1, 6, "15")
    write_scrolled_base_fragment(6, 1, 6, "86")

    assert_equal(
        text.read_dialogue_window_filtered(6, 27, 0),
        "Bill searched the ground all about.",
        "status-name rows should be filtered even when real dialogue is present"
    )
end

function tests.dialogue_filter_keeps_single_word_dialogue_without_status_context()
    clear_ppu()
    write_visible_row(2, "Bill", 8, 0)

    assert_equal(
        text.read_dialogue_window_filtered(8, 25, 0),
        "Bill",
        "single-word dialogue should remain readable without nearby status markers"
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

function tests.dialogue_filter_strips_padded_status_suffix_from_real_dialogue()
    clear_ppu()
    write_row(19, "'There is no one there.       HP")

    assert_equal(
        text.read_dialogue_window_filtered(0, 19, 0),
        "'There is no one there.",
        "lower dialogue reader should strip padded trailing status fragments"
    )
end

function tests.dialogue_filter_strips_padded_name_suffix_from_real_dialogue()
    clear_ppu()
    write_row(19, "All about.           Bi")

    assert_equal(
        text.read_dialogue_window_filtered(0, 19, 0),
        "All about.",
        "lower dialogue reader should strip padded trailing name fragments"
    )
end

function tests.dialogue_filter_strips_padded_status_infix_from_real_dialogue()
    clear_ppu()
    write_row(19, "But there found       V nothing.")

    assert_equal(
        text.read_dialogue_window_filtered(0, 19, 0),
        "But there found nothing.",
        "lower dialogue reader should strip padded embedded status fragments"
    )
end

function tests.dialogue_filter_keeps_unpadded_status_words_in_dialogue()
    clear_ppu()
    write_row(19, "Low HP")

    assert_equal(
        text.read_dialogue_window_filtered(0, 19, 0),
        "Low HP",
        "ordinary dialogue should keep HP when it is not padded status-bar residue"
    )
end

function tests.dialogue_filter_strips_repeated_inline_single_status_letters()
    clear_ppu()
    write_row(19, "'My Grandfather Wynn M once")
    write_row(20, "had a shop on the east side of G")
    write_row(21, "Hauksness.")

    assert_equal(
        text.read_dialogue_window_filtered(0, 19, 0),
        "'My Grandfather Wynn once had a shop on the east side of Hauksness.",
        "repeated isolated status letters should not corrupt real NPC dialogue"
    )
end

function tests.dialogue_filter_keeps_lone_uppercase_initial_without_status_context()
    clear_ppu()
    write_row(19, "'A man named G lives here.")

    assert_equal(
        text.read_dialogue_window_filtered(0, 19, 0),
        "'A man named G lives here.",
        "a lone uppercase initial should remain when no repeated status noise is present"
    )
end

function tests.dialogue_filter_skips_status_equipment_rows()
    clear_ppu()
    write_row(19, "WEAPON:Club")
    write_row(20, "ARMOR:Leather  Armor")

    assert_equal(
        text.read_dialogue_window_filtered(0, 19),
        "",
        "lower dialogue reader should ignore STATUS menu equipment rows"
    )
end

function tests.status_equipment_detector_requires_status_labels()
    assert_equal(
        text.is_status_equipment_text("The weapon shop is north."),
        false,
        "ordinary dialogue mentioning weapons should not look like the STATUS equipment block"
    )
    assert_equal(
        text.is_status_equipment_text("WEAPON:Club ARMOR:Leather Armor"),
        true,
        "STATUS equipment block should be detectable after row concatenation"
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

function tests.low_row_dialogue_cleaner_preserves_gold_reward_token()
    assert_equal(
        text.clean_low_row_dialogue("Of GOLD thou hast gained 12"),
        "Of GOLD thou hast gained 12",
        "low-row cleaner should not delete meaningful uppercase GOLD reward text"
    )
end

function tests.low_row_dialogue_cleaner_strips_command_labels_not_reward_text()
    assert_equal(
        text.clean_low_row_dialogue("COMMAND TAKE Of GOLD thou hast gained 12"),
        "Of GOLD thou hast gained 12",
        "low-row cleaner should strip command labels while preserving reward text"
    )
end

function tests.low_row_dialogue_cleaner_keeps_key_item_token()
    assert_equal(
        text.clean_low_row_dialogue("Thou hast found the KEY!"),
        "Thou hast found the KEY!",
        "low-row cleaner should preserve uppercase item words beyond command labels"
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

function tests.extract_new_dialogue_keeps_shop_farewell_after_prompt_baseline()
    local old = "'Welcome. We deal in tools. What can I do for thee?' 'What dost thou want?'"
    local new = "'Welcome. We deal in tools. What can I do for thee?' 'What dost thou want?' 'I will be waiting for thy next visit."

    assert_equal(
        text.extract_new_dialogue(old, new),
        "'I will be waiting for thy next visit.",
        "merchant prompt baseline should leave only the farewell dialogue"
    )
end

function tests.extract_new_dialogue_keeps_non_overlapping_text()
    assert_equal(
        text.extract_new_dialogue("'I am greatly pleased", "'Before reaching thy next level"),
        "'Before reaching thy next level",
        "dialogue overlap helper should preserve unrelated new text"
    )
end

function tests.extract_new_dialogue_tolerates_live_page_punctuation_drift()
    local old =
        "by 70. My hope is with thee. .'From where thou art now, my castle lies.. " ..
        ".69 to the north and.. 46 to the west."
    local new =
        "'From where thou art now, my castle lies.. 69 to the north and.. " ..
        ".46 to the west. .'I love thee, Bill."

    assert_equal(
        text.extract_new_dialogue(old, new),
        "'I love thee, Bill.",
        "dialogue overlap should ignore repaint-only punctuation changes before the final Gwaelin page"
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
