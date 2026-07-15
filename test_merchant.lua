-- test_merchant.lua
-- Focused regression tests for merchant/shop screen detection.

local original_preload = {}
local original_loaded = {}

local function save_module(name)
    original_preload[name] = package.preload[name]
    original_loaded[name] = package.loaded[name]
end

local function restore_modules(names)
    for _, name in ipairs(names) do
        package.preload[name] = original_preload[name]
        package.loaded[name] = original_loaded[name]
    end
end

local function make_env()
    local module_names = {
        "game_snapshot",
        "items",
        "merchant",
        "text",
    }

    for _, name in ipairs(module_names) do
        save_module(name)
        package.loaded[name] = nil
    end

    package.preload["game_snapshot"] = function()
        return {
            gold = 122,
        }
    end

    _G.ppu = _G.ppu or {}
    _G.ppu.readbyte = function()
        return 0x9F
    end

    local merchant = require "merchant"

    return {
        merchant = merchant,
        restore = function()
            restore_modules(module_names)
        end,
    }
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local function encode_char(ch)
    local byte = string.byte(ch)
    if ch >= "0" and ch <= "9" then
        return byte - string.byte("0")
    end
    if ch >= "a" and ch <= "z" then
        return 0x0A + byte - string.byte("a")
    end
    if ch >= "A" and ch <= "Z" then
        return 0x24 + byte - string.byte("A")
    end
    if ch == " " then return 0x5F end
    if ch == "'" then return 0x40 end
    if ch == "." then return 0x52 end
    if ch == "?" then return 0x4B end
    if ch == "," then return 0x48 end
    return 0x9F
end

local function write_visible_text(bytes, ctx, visible_row, start_col, value)
    local NT0 = 0x2000
    local NT1 = 0x2400
    local nametable_row = (visible_row + (ctx.vertical_scroll_tiles or 0)) % 30
    for i = 1, #value do
        local screen_col = start_col + i - 1
        local virtual_col = (ctx.scroll_tiles or 0) + screen_col
        local nt_col = virtual_col % 32
        local nt_index = ((ctx.base_nametable or 0) + math.floor(virtual_col / 32)) % 2
        local nt_base = (nt_index == 0) and NT0 or NT1
        bytes[nt_base + nametable_row * 32 + nt_col] = encode_char(value:sub(i, i))
    end
end

local function build_scrolled_shop_screen()
    local ctx = {
        scroll_tiles = 26,
        base_nametable = 1,
        vertical_scroll_tiles = 20,
    }
    local bytes = {}

    write_visible_text(bytes, ctx, 1, 3, "BILL")
    write_visible_text(bytes, ctx, 3, 3, "LV   1")
    write_visible_text(bytes, ctx, 5, 3, "HP  15")
    write_visible_text(bytes, ctx, 7, 3, "MP   0")
    write_visible_text(bytes, ctx, 9, 3, "G   60")
    write_visible_text(bytes, ctx, 11, 3, "E    0")

    write_visible_text(bytes, ctx, 4, 14, "Bamboo      10")
    write_visible_text(bytes, ctx, 5, 16, "Pole")
    write_visible_text(bytes, ctx, 6, 14, "Club        60")
    write_visible_text(bytes, ctx, 8, 14, "Copper     180")
    write_visible_text(bytes, ctx, 9, 16, "Sword")
    write_visible_text(bytes, ctx, 10, 14, "Clothes     20")
    write_visible_text(bytes, ctx, 12, 14, "Leather     70")
    write_visible_text(bytes, ctx, 13, 16, "Armor")
    write_visible_text(bytes, ctx, 14, 14, "Small       90")
    write_visible_text(bytes, ctx, 15, 16, "Shield")

    local cursor_row = (10 + ctx.vertical_scroll_tiles) % 30
    local cursor_virtual_col = ctx.scroll_tiles + 13
    local cursor_nt_col = cursor_virtual_col % 32
    local cursor_nt_index = (ctx.base_nametable + math.floor(cursor_virtual_col / 32)) % 2
    local cursor_base = (cursor_nt_index == 0) and 0x2000 or 0x2400
    bytes[cursor_base + cursor_row * 32 + cursor_nt_col] = 0x42

    return bytes, ctx
end

local function build_fixed_shop_screen()
    local ctx = {
        scroll_tiles = 0,
        base_nametable = 0,
        vertical_scroll_tiles = 0,
    }
    local bytes = {}

    write_visible_text(bytes, ctx, 16, 0, "Bill")
    write_visible_text(bytes, ctx, 17, 0, "Bamboo")
    write_visible_text(bytes, ctx, 18, 0, "LV   2  Pole")
    write_visible_text(bytes, ctx, 19, 0, "Club")
    write_visible_text(bytes, ctx, 20, 0, "HP   7")
    write_visible_text(bytes, ctx, 21, 0, "Copper")
    write_visible_text(bytes, ctx, 22, 0, "MP   0  Sword")
    write_visible_text(bytes, ctx, 23, 0, "Clothes")
    write_visible_text(bytes, ctx, 24, 0, "G   13")
    write_visible_text(bytes, ctx, 25, 0, "Leather")
    write_visible_text(bytes, ctx, 26, 0, "E   12  Armor")

    return bytes
end

local tests = {}

function tests.detects_weapon_shop_layout_and_extracts_offers()
    local env = make_env()

    local rows = {
        [16] = "BILL",
        [17] = "Bamboo",
        [18] = "LV   1  Pole",
        [19] = "Club",
        [20] = "HP   6",
        [21] = "Copper",
        [22] = "MP   0  Sword",
        [23] = "Clothes",
        [24] = "G  122",
        [25] = "Leather",
        [26] = "E    1  Armor",
        [27] = "Small",
        [28] = "Shield",
    }

    local info = env.merchant.analyze_rows(rows, {gold = 122})
    assert_equal(info.active, true, "merchant screen should be detected")
    assert_equal(
        table.concat(info.offers, ", "),
        "Bamboo Pole, Club, Copper Sword, Clothes, Leather Armor, Small Shield",
        "merchant offers should be normalized from split rows"
    )
    assert_equal(
        info.summary,
        "Merchant. Gold 122. Offered: Bamboo Pole, Club, Copper Sword, Clothes, Leather Armor, Small Shield.",
        "merchant summary should include gold and offers"
    )

    env.restore()
end

function tests.detects_brecconary_tool_shop_layout_and_extracts_items()
    local env = make_env()

    local rows = {
        [2] = "COMMAND",
        [4] = "Bill",
        [5] = "Herb         24",
        [6] = "LV   5",
        [7] = "Torch         8",
        [8] = "HP  35",
        [9] = "Dragon's     20",
        [10] = "MP  18  Scale",
        [12] = "G   42",
        [14] = "E  111",
        [19] = "'Welcome.",
        [20] = "We deal in tools.",
        [21] = "What can I do for",
        [22] = "thee?'",
        [24] = "'What dost thou want?'",
    }

    local info = env.merchant.analyze_rows(rows, {gold = 42})
    assert_equal(info.active, true, "Brecconary tool shop should be detected")
    assert_equal(
        table.concat(info.offers, ", "),
        "Herb, Torch, Dragon's Scale",
        "tool-shop offers should include item catalog entries"
    )
    assert_equal(
        info.summary,
        "Merchant. Gold 42. Offered: Herb, Torch, Dragon's Scale.",
        "tool-shop summary should include gold and item offers"
    )

    env.restore()
end

function tests.detects_kol_weapon_shop_layout_and_extracts_live_offers()
    local env = make_env()

    local rows = {
        [2] = "COMMAND",
        [4] = "Bill",
        [5] = "Copper     180",
        [6] = "LV   6  Sword",
        [7] = "Hand       560",
        [8] = "HP  38  Axe",
        [9] = "Half      1000",
        [10] = "MP  21  Plate",
        [11] = "Full      3000",
        [12] = "G  155  Plate",
        [13] = "Small       90",
        [14] = "E  425  Shield",
        [21] = "What dost thou wish to buy",
        [22] = "anything today?",
        [24] = "What dost thou wish",
        [25] = "to buy?",
    }

    local info = env.merchant.analyze_rows(rows, {gold = 155})
    assert_equal(info.active, true, "Kol weapon shop should be detected")
    assert_equal(
        table.concat(info.offers, ", "),
        "Copper Sword, Hand Axe, Half Plate, Full Plate, Small Shield",
        "Kol weapon shop offers should match the live menu"
    )
    assert_equal(
        info.summary,
        "Merchant. Gold 155. Offered: Copper Sword, Hand Axe, Half Plate, Full Plate, Small Shield.",
        "Kol weapon shop summary should include the live offers"
    )

    env.restore()
end

function tests.detects_kol_tool_shop_layout_and_extracts_live_offers()
    local env = make_env()

    local rows = {
        [2] = "COMMAND",
        [4] = "Bill",
        [5] = "Herb         24",
        [6] = "LV   6",
        [7] = "Torch         8",
        [8] = "HP  38",
        [9] = "Dragon's     20",
        [10] = "MP  21  Scale",
        [11] = "Wings        70",
        [12] = "G  155",
        [14] = "E  425",
        [21] = "What dost thou wish to buy",
        [22] = "anything today?",
        [24] = "What dost thou wish",
        [25] = "to buy?",
    }

    local info = env.merchant.analyze_rows(rows, {gold = 155})
    assert_equal(info.active, true, "Kol tool shop should be detected")
    assert_equal(
        table.concat(info.offers, ", "),
        "Herb, Torch, Dragon's Scale, Wings",
        "Kol tool shop offers should match the live menu"
    )
    assert_equal(
        info.summary,
        "Merchant. Gold 155. Offered: Herb, Torch, Dragon's Scale, Wings.",
        "Kol tool shop summary should include the live offers"
    )

    env.restore()
end

function tests.held_item_menu_backdrop_is_not_merchant_offer_list()
    local env = make_env()

    local rows = {
        [2] = "COMMAND",
        [4] = "Bill  TALK    SPELL",
        [6] = "LV  15 STATUS  ITEM",
        [8] = "HP  86 STAIRS  DOOR",
        [10] = "MP  64 SEARCH  TAKE",
        [12] = "G22044",
        [14] = "E12982",
        [17] = "Herb",
        [18] = "Magic",
        [19] = "Armor",
        [20] = "Fairy",
        [21] = "Flute",
        [22] = "Dragon's",
        [23] = "Scale",
        [24] = "Wings",
        [25] = "Stones of",
        [26] = "Sunlight",
        [27] = "Silver Harp",
        [28] = "Cursed Belt",
    }

    local info = env.merchant.analyze_rows(rows, {gold = 22044})
    assert_equal(info.active, false, "held ITEM menu should not trigger merchant mode")

    env.restore()
end

function tests.held_item_menu_without_command_backdrop_is_not_merchant_offer_list()
    local env = make_env()

    local rows = {
        [4] = "Bill",
        [6] = "LV  15",
        [8] = "HP  86llE",
        [10] = "MP  64 1",
        [12] = "G22044 86",
        [14] = "E12982 64",
        [17] = "Herb",
        [18] = "Magic",
        [19] = "Armor",
        [20] = "Fairy",
        [21] = "Flute",
        [22] = "Dragon's",
        [23] = "Scale",
        [24] = "Wings",
        [25] = "Stones of",
        [26] = "Sunlight",
        [27] = "Silver Harp",
        [28] = "Cursed Belt",
    }

    local info = env.merchant.analyze_rows(rows, {gold = 22044})
    assert_equal(info.active, false, "held ITEM menu without visible command words should not trigger merchant mode")

    env.restore()
end

function tests.detects_brecconary_buy_sell_action_prompt()
    local env = make_env()

    local rows = {
        [2] = "COMMAND",
        [4] = "Bill    SPELL",
        [6] = "LV   5 BUY  US  ITEM",
        [8] = "HP  35 SELL RS  DOOR",
        [10] = "MP  18 SEARCH  TAKE",
        [12] = "G   42",
        [14] = "E  111",
        [19] = "'Welcome.",
        [20] = "We deal in tools.",
        [21] = "What can I do for",
        [22] = "thee?'",
    }

    local buy = env.merchant.analyze_rows(rows, {gold = 42, cursor_y = 0})
    assert_equal(buy.active, true, "Buy/Sell prompt should count as merchant UI")
    assert_equal(buy.mode, "action", "Buy/Sell prompt should use action mode")
    assert_equal(buy.action_prompt, true, "Buy/Sell prompt should be identified")
    assert_equal(buy.action_selection, "Buy", "D9=0 should select Buy")
    assert_equal(buy.summary, "Merchant. Buy or Sell. Buy.", "action summary should name selected option")

    local sell = env.merchant.analyze_rows(rows, {gold = 42, cursor_y = 1})
    assert_equal(sell.action_selection, "Sell", "D9=1 should select Sell")

    env.restore()
end

function tests.ignores_regular_dialogue_rows()
    local env = make_env()

    local rows = {
        [19] = "Thou hast found a key.",
        [20] = "Will thou take it?",
    }

    local info = env.merchant.analyze_rows(rows, {gold = 122})
    assert_equal(info.active, false, "regular dialogue should not trigger merchant mode")

    env.restore()
end

function tests.buy_prompt_with_partial_offer_list_is_active()
    local env = make_env()

    local rows = {
        [11] = "Clothes      20",
        [12] = "G   60",
        [13] = "Leather      70",
        [14] = "E    0  Armor",
        [15] = "Small        90",
        [16] = "Shield",
        [20] = "'Dost thou wish to buy",
        [21] = "anything more?'",
        [23] = "'What dost thou wish",
        [24] = "to buy?'",
    }

    local info = env.merchant.analyze_rows(rows, {gold = 60})
    assert_equal(info.active, true, "buy prompt plus partial shop list should stay in merchant mode")
    assert_equal(info.buy_prompt, true, "merchant parser should recognize the active buy prompt")
    assert_equal(
        table.concat(info.offers, ", "),
        "Clothes, Leather Armor, Small Shield",
        "partial visible offers should still be extracted"
    )

    env.restore()
end

function tests.buy_more_yesno_without_buy_prompt_is_not_item_list()
    local env = make_env()

    local rows = {
        [20] = "'Dost thou wish to buy",
        [21] = "anything more?'",
        [23] = "YES        NO",
    }

    local info = env.merchant.analyze_rows(rows, {gold = 60})
    assert_equal(info.active, false, "buy-more yes/no prompt alone should not become item-list mode")

    env.restore()
end

function tests.item_confirmation_with_stale_buy_prompt_is_not_item_list()
    local env = make_env()

    local rows = {
        [4] = "Bill TALK    SPELL",
        [6] = "LV   1 STATUS  ITEM",
        [8] = "HP  15 STAIRS  DOOR",
        [10] = "MP   0 SEARCH  TAKE",
        [12] = "G   60",
        [14] = "E    0",
        [19] = "'Dost thou wish to buy",
        [20] = "anything more?'",
        [22] = "'What dost thou wish",
        [23] = "to buy?'",
        [25] = "'The Copper Sword?'",
    }

    local info = env.merchant.analyze_rows(rows, {gold = 60})
    assert_equal(info.active, false, "item confirmation dialogue should not be merchant item-list mode")

    env.restore()
end

function tests.cursor_selection_reads_current_offer()
    local env = make_env()

    local NT0 = 0x2000
    local NT1 = 0x2400
    local bytes = {}
    local row = 19
    local row_base = NT0 + row * 32
    bytes[row_base + 21] = 0x42  -- cursor
    bytes[row_base + 22] = 0x26  -- C
    bytes[row_base + 23] = 0x15  -- l
    bytes[row_base + 24] = 0x1E  -- u
    bytes[row_base + 25] = 0x0B  -- b
    bytes[NT1 + row * 32 + 3] = 0x06
    bytes[NT1 + row * 32 + 4] = 0x00

    _G.ppu.readbyte = function(address)
        return bytes[address] or 0x9F
    end

    local offer = env.merchant.get_cursor_offer()
    assert_equal(offer.name, "Club", "merchant cursor should resolve the selected item")
    assert_equal(offer.price, 60, "merchant cursor should resolve the selected item price")

    env.restore()
end

function tests.detects_scrolled_weapon_shop_layout()
    local env = make_env()
    local bytes, ctx = build_scrolled_shop_screen()

    _G.ppu.readbyte = function(address)
        return bytes[address] or 0x9F
    end

    local info = env.merchant.analyze_rows(env.merchant.read_rows(ctx), {gold = 60})
    assert_equal(info.active, true, "scrolled merchant screen should be detected")
    assert_equal(
        table.concat(info.offers, ", "),
        "Bamboo Pole, Club, Copper Sword, Clothes, Leather Armor, Small Shield",
        "scrolled merchant offers should be normalized"
    )

    env.restore()
end

function tests.cursor_selection_disambiguates_silver_shield_by_shop_price()
    local env = make_env()

    local NT0 = 0x2000
    local bytes = {}
    local ctx = {
        scroll_tiles = 0,
        base_nametable = 0,
        vertical_scroll_tiles = 0,
    }

    write_visible_text(bytes, ctx, 19, 1, "Silver     14800")
    bytes[NT0 + 19 * 32] = 0x42 -- cursor immediately before the offer
    write_visible_text(bytes, ctx, 20, 3, "Shield")

    _G.ppu.readbyte = function(address)
        return bytes[address] or 0x9F
    end

    local offer = env.merchant.get_cursor_offer()
    assert_equal(offer.name, "Silver Shield", "14800-gold Silver offer should not be confused with the quest item Silver Harp")
    assert_equal(offer.price, 14800, "Silver Shield cursor offer should preserve its price")

    env.restore()
end

function tests.default_shop_reader_ignores_field_scroll_registers()
    local env = make_env()
    local bytes = build_fixed_shop_screen()

    _G.memory = {
        readbyte = function()
            return 0xFF
        end,
    }
    _G.ppu.readbyte = function(address)
        return bytes[address] or 0x9F
    end

    local info = env.merchant.analyze_rows(env.merchant.read_rows(), {gold = 13})
    assert_equal(info.active, true, "merchant default reader should use fixed screen rows")
    assert_equal(
        table.concat(info.offers, ", "),
        "Bamboo Pole, Club, Copper Sword, Clothes, Leather Armor",
        "merchant default reader should ignore stale field scroll registers"
    )

    env.restore()
end

function tests.current_screen_uses_scrolled_context_when_fixed_rows_are_empty()
    local env = make_env()
    local bytes, ctx = build_scrolled_shop_screen()

    _G.ppu.readbyte = function(address)
        return bytes[address] or 0x9F
    end

    local info = env.merchant.analyze_current_screen({
        contexts = {
            {label = "fixed", scroll_tiles = 0, base_nametable = 0, vertical_scroll_tiles = 0},
            {
                label = "live",
                scroll_tiles = ctx.scroll_tiles,
                base_nametable = ctx.base_nametable,
                vertical_scroll_tiles = ctx.vertical_scroll_tiles,
            },
        },
    })

    assert_equal(info.active, true, "merchant screen should fall back to live scroll context")
    assert_equal(info.context_label, "live", "active context should identify the live scroll reader")
    assert_equal(
        table.concat(info.offers, ", "),
        "Bamboo Pole, Club, Copper Sword, Clothes, Leather Armor, Small Shield",
        "fallback context should recover scrolled merchant offers"
    )

    env.restore()
end

function tests.current_screen_can_fall_back_to_alternate_live_base()
    local env = make_env()
    local bytes, ctx = build_scrolled_shop_screen()

    _G.ppu.readbyte = function(address)
        return bytes[address] or 0x9F
    end

    local reported_base = (ctx.base_nametable + 1) % 2
    local info = env.merchant.analyze_current_screen({
        contexts = {
            {label = "fixed", scroll_tiles = 0, base_nametable = 0, vertical_scroll_tiles = 0},
            {
                label = "live",
                scroll_tiles = ctx.scroll_tiles,
                base_nametable = reported_base,
                vertical_scroll_tiles = ctx.vertical_scroll_tiles,
            },
            {
                label = "live_alt_base",
                scroll_tiles = ctx.scroll_tiles,
                base_nametable = ctx.base_nametable,
                vertical_scroll_tiles = ctx.vertical_scroll_tiles,
            },
        },
    })

    assert_equal(info.active, true, "alternate live base should recover the merchant screen")
    assert_equal(info.context_label, "live_alt_base", "alternate base context should be identified")
    assert_equal(
        table.concat(info.offers, ", "),
        "Bamboo Pole, Club, Copper Sword, Clothes, Leather Armor, Small Shield",
        "alternate base fallback should recover scrolled merchant offers"
    )

    env.restore()
end

function tests.current_screen_keeps_fixed_context_when_it_is_active()
    local env = make_env()
    local bytes = build_fixed_shop_screen()

    _G.ppu.readbyte = function(address)
        return bytes[address] or 0x9F
    end

    local info = env.merchant.analyze_current_screen({
        contexts = {
            {label = "fixed", scroll_tiles = 0, base_nametable = 0, vertical_scroll_tiles = 0},
            {label = "live", scroll_tiles = 26, base_nametable = 1, vertical_scroll_tiles = 20},
        },
    })

    assert_equal(info.active, true, "fixed merchant rows should still be detected first")
    assert_equal(info.context_label, "fixed", "fixed context should win when it is already active")
    assert_equal(
        table.concat(info.offers, ", "),
        "Bamboo Pole, Club, Copper Sword, Clothes, Leather Armor",
        "fixed context should preserve the old no-scroll merchant behavior"
    )

    env.restore()
end

function tests.cursor_selection_reads_scrolled_visible_offer()
    local env = make_env()
    local bytes, ctx = build_scrolled_shop_screen()

    _G.ppu.readbyte = function(address)
        return bytes[address] or 0x9F
    end

    local offer = env.merchant.get_cursor_offer(ctx)
    assert_equal(offer.name, "Clothes", "scrolled merchant cursor should resolve selected item")
    assert_equal(offer.price, 20, "scrolled merchant cursor should resolve selected price")

    env.restore()
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

if failures > 0 then
    os.exit(1)
end
