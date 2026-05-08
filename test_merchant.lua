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
