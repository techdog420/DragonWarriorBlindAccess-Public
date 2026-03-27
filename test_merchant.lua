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

    package.preload["text"] = function()
        return {}
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
