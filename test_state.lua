-- test_state.lua
-- Regression tests for title/field/battle state detection.

local original_preload = {}
local original_loaded = {}
local original_memory = _G.memory
local original_ppu = _G.ppu

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

    _G.memory = {
        readbyte = function(address)
            if address == 0x6003 then
                return sprite_chr_page
            end
            return 0
        end,
    }

    _G.ppu = {
        readbyte = function()
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
        restore = function()
            restore_modules(module_names)
            _G.memory = original_memory
            _G.ppu = original_ppu
        end,
    }
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
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
