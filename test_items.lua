-- test_items.lua
-- Regression tests for item/equipment/spell lookup helpers.

local original_preload = {}
local original_loaded = {}
local original_AND = _G.AND
local original_BIT = _G.BIT

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

local function make_env(snapshot_fields)
    local module_names = {
        "game_snapshot",
        "items",
    }

    for _, name in ipairs(module_names) do
        save_module(name)
        package.loaded[name] = nil
    end

    _G.AND = function(a, b)
        local result = 0
        local bit = 1
        while a > 0 or b > 0 do
            if (a % 2 == 1) and (b % 2 == 1) then
                result = result + bit
            end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            bit = bit * 2
        end
        return result
    end
    _G.BIT = function(n) return 2 ^ n end

    package.preload["game_snapshot"] = function()
        return snapshot_fields
    end

    local items = require "items"
    return {
        items = items,
        restore = function()
            restore_modules(module_names)
            _G.AND = original_AND
            _G.BIT = original_BIT
        end,
    }
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local function assert_contains(text, pattern, message)
    if not string.find(text, pattern, 1, true) then
        error(string.format("%s: expected %q to contain %q", message, tostring(text), tostring(pattern)), 2)
    end
end

local tests = {}

function tests.item_menu_matches_live_herb_key_and_packed_slot_order()
    local env = make_env({
        herbs = 6,
        keys = 6,
        items = {0x45, 0xC3, 0x2D, 0x18},
    })

    local names = {}
    for _, entry in ipairs(env.items.get_all_items()) do
        names[#names + 1] = entry.name
    end

    assert_equal(
        table.concat(names, ", "),
        "Herb, Magic Key, Fairy Flute, Dragon's Scale, Wings, " ..
            "Stones of Sunlight, Staff of Rain, Fairy Water, Gwaelin's Love, Torch",
        "item order should match the live full-inventory menu"
    )
    assert_equal(
        env.items.get_item_at_d9(2),
        "Fairy Flute",
        "live discard cursor D9=2 should select Fairy Flute"
    )

    env.restore()
end

function tests.spell_menu_helpers_index_known_spells_by_d9()
    local env = make_env({
        spells = 0x05,   -- Heal + Sleep
        flags_cf = 0x01, -- Healmore
    })

    assert_equal(env.items.get_spell_count(), 3, "spell count should include both spell bytes")
    assert_equal(env.items.get_spell_at_d9(0), "Heal", "D9=0 should select first known spell")
    assert_equal(env.items.get_spell_at_d9(1), "Sleep", "D9=1 should skip unknown spell bits")
    assert_equal(env.items.get_spell_at_d9(2), "Healmore", "D9=2 should include 0xCF spell bits")
    assert_equal(env.items.get_spell_at_d9(3), "Empty", "past learned spells should be empty")
    assert_equal(env.items.describe_spell_at_d9(0), "Heal. 4 MP", "spell speech should include Heal cost")
    assert_equal(env.items.describe_spell_at_d9(1), "Sleep. 2 MP", "spell speech should include Sleep cost")
    assert_equal(env.items.describe_spell_at_d9(2), "Healmore. 10 MP", "spell speech should include Healmore cost")

    env.restore()
end

function tests.spell_cost_table_matches_nes_menu_costs()
    local env = make_env({
        spells = 0xFF,
        flags_cf = 0x03,
    })

    local expected = {
        "Heal. 4 MP",
        "Hurt. 2 MP",
        "Sleep. 2 MP",
        "Radiant. 3 MP",
        "Stopspell. 2 MP",
        "Outside. 6 MP",
        "Return. 8 MP",
        "Repel. 2 MP",
        "Healmore. 10 MP",
        "Hurtmore. 5 MP",
    }
    for i, text in ipairs(expected) do
        assert_equal(env.items.describe_spell_at_d9(i - 1), text, "spell cost should match NES table")
    end

    env.restore()
end

function tests.spell_menu_helpers_report_empty_when_no_spells_known()
    local env = make_env({
        spells = 0x00,
        flags_cf = 0x00,
    })

    assert_equal(env.items.get_spell_count(), 0, "no spell bits should produce an empty menu list")
    assert_equal(env.items.get_spell_at_d9(0), "Empty", "empty spell list should read as Empty")
    assert_equal(env.items.describe_spell_at_d9(0), "Empty", "empty spell list should describe as Empty")

    env.restore()
end

function tests.status_readout_reports_princess_escort_flag()
    local env = make_env({
        level = 15,
        hp = 86,
        max_hp = 86,
        mp = 52,
        max_mp = 64,
        strength = 0x44,
        agility = 0x39,
        attack = 0x58,
        defense = 0x40,
        exp = 12964,
        gold = 22294,
        equipment = 0x00,
        spells = 0x00,
        flags_cf = 0x00,
        combat_flags = 0x09,
    })

    assert_contains(
        env.items.read_status_string(),
        "Status: Escorting Princess Gwaelin",
        "status readout should include Princess Gwaelin escort state"
    )

    env.restore()
end

local failures = 0
local count = 0
for name, test in pairs(tests) do
    count = count + 1
    local ok, err = pcall(test)
    if ok then
        print("PASS " .. name)
    else
        failures = failures + 1
        print("FAIL " .. name .. ": " .. err)
    end
end

print(string.format("%d tests, %d failures", count, failures))
if failures > 0 then
    os.exit(1)
end
