-- test_state.lua
-- Regression tests for title/field/battle state detection.

local original_preload = {}
local original_loaded = {}
local original_memory = _G.memory
local original_ppu = _G.ppu
local original_emulator_compat = _G.DW_EMULATOR_COMPAT

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

local function make_env(options)
    options = options or {}
    local module_names = {
        "addresses",
        "game_snapshot",
        "state",
    }

    for _, name in ipairs(module_names) do
        save_module(name)
        package.loaded[name] = nil
    end

    local sprite_chr_page = options.sprite_chr_page or 0x02
    local ppu_reads = 0
    local memory_reads = 0

    _G.DW_EMULATOR_COMPAT = {
        is_bizhawk = options.is_bizhawk == true,
    }

    _G.memory = {
        readbyte = function(address)
            memory_reads = memory_reads + 1
            if address == 0x6003 then
                return sprite_chr_page
            end
            return 0
        end,
    }

    _G.ppu = {
        readbyte = function(address)
            ppu_reads = ppu_reads + 1
            if options.title_pattern and address then
                return options.title_pattern[address] or 0x9F
            end
            return 0x9F
        end,
    }

    package.preload["addresses"] = function()
        return {
            CHR_PAGE_SPRITES = 0x6003,
        }
    end

    package.preload["game_snapshot"] = function()
        return {
            level = options.level or 1,
            enemy_hp = options.enemy_hp or 0,
            cursor_x = options.cursor_x or 0,
            cursor_y = options.cursor_y or 0,
        }
    end

    local state = require "state"
    return {
        state = state,
        ppu_reads = function()
            return ppu_reads
        end,
        memory_reads = function()
            return memory_reads
        end,
        restore = function()
            restore_modules(module_names)
            _G.memory = original_memory
            _G.ppu = original_ppu
            _G.DW_EMULATOR_COMPAT = original_emulator_compat
        end,
    }
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local function encoded_upper(text)
    local bytes = {}
    for i = 1, #text do
        local c = text:byte(i)
        if c >= 65 and c <= 90 then
            bytes[#bytes + 1] = 0x24 + (c - 65)
        end
    end
    return bytes
end

local function put_text(pattern, row, col, value)
    local bytes = encoded_upper(value)
    local base = 0x2000 + row * 32 + col
    for i, byte in ipairs(bytes) do
        pattern[base + i - 1] = byte
    end
end

local tests = {}

function tests.stale_enemy_hp_on_field_does_not_force_battle()
    local env = make_env({
        sprite_chr_page = 0x02,
        level = 1,
        enemy_hp = 4,
        cursor_x = 0,
        cursor_y = 0,
    })

    assert_equal(env.state.detect(), env.state.STATE_FIELD, "non-battle sprite page should keep stale enemy HP on the field")

    env.restore()
end

function tests.battle_sprite_page_forces_battle_state()
    local env = make_env({
        sprite_chr_page = 0x03,
        level = 1,
        enemy_hp = 0,
    })

    assert_equal(env.state.detect(), env.state.STATE_BATTLE, "battle sprite page should force battle state")

    env.restore()
end

function tests.bizhawk_field_state_reuses_title_scan_between_rescans()
    local env = make_env({
        is_bizhawk = true,
        sprite_chr_page = 0x02,
        level = 1,
        enemy_hp = 0,
    })

    assert_equal(env.state.detect(), env.state.STATE_FIELD, "first detect should reach field")
    local reads_after_first = env.ppu_reads()
    assert_equal(env.state.detect(), env.state.STATE_FIELD, "second detect should keep field")
    assert_equal(env.ppu_reads(), reads_after_first, "BizHawk should skip immediate title PPU rescan after field is confirmed")

    env.restore()
end

function tests.bizhawk_field_state_skips_sprite_chr_read_when_enemy_hp_is_clear()
    local env = make_env({
        is_bizhawk = true,
        sprite_chr_page = 0x02,
        level = 1,
        enemy_hp = 0,
    })

    assert_equal(env.state.detect(), env.state.STATE_FIELD, "clear field state should remain field")
    assert_equal(env.memory_reads(), 0, "BizHawk field state should avoid the slow cartridge work-RAM sprite-page read")

    env.restore()
end

function tests.fceux_field_state_scans_title_content_each_frame()
    local env = make_env({
        is_bizhawk = false,
        sprite_chr_page = 0x02,
        level = 1,
        enemy_hp = 0,
    })

    assert_equal(env.state.detect(), env.state.STATE_FIELD, "first detect should reach field")
    local reads_after_first = env.ppu_reads()
    assert_equal(env.state.detect(), env.state.STATE_FIELD, "second detect should keep field")
    if env.ppu_reads() <= reads_after_first then
        error("FCEUX path should preserve the existing every-frame title PPU scan", 2)
    end

    env.restore()
end

function tests.erase_confirmation_with_loaded_level_remains_title()
    local title_pattern = {}
    put_text(title_pattern, 19, 10, "ERASE")
    put_text(title_pattern, 21, 8, "CHARACTER")

    local env = make_env({
        level = 7,
        title_pattern = title_pattern,
    })

    assert_equal(env.state.detect(), env.state.STATE_TITLE, "erase confirmation should stay in title state")

    env.restore()
end

function tests.name_entry_grid_with_loaded_level_remains_title()
    local title_pattern = {}
    put_text(title_pattern, 22, 18, "BACK")
    put_text(title_pattern, 22, 26, "END")

    local env = make_env({
        level = 7,
        title_pattern = title_pattern,
    })

    assert_equal(env.state.detect(), env.state.STATE_TITLE, "name-entry grid should stay in title state")

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
