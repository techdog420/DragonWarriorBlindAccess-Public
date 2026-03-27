-- test_maps.lua
-- Regression tests for raw RAM map ID naming.

local maps = require "maps"

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local tests = {}

function tests.world_map_uses_raw_id_01()
    assert_equal(maps.WORLD_MAP_ID, 0x01, "world map raw ID should match the RAM map")
    assert_equal(maps.get_name(0x01), "World Map", "0x01 should resolve to the world map")
    assert_equal(maps.is_overworld(0x01), true, "world map ID should be treated as overworld")
end

function tests.early_game_location_ids_match_ram_map()
    assert_equal(maps.get_name(0x04), "Tantegel Castle", "0x04 should resolve to Tantegel Castle")
    assert_equal(maps.get_name(0x08), "Brecconary", "0x08 should resolve to Brecconary")
    assert_equal(maps.get_name(0x09), "Garinham", "0x09 should resolve to Garinham")
    assert_equal(maps.get_name(0x15), "Swamp Cave", "0x15 should resolve to Swamp Cave")
    assert_equal(maps.get_name(0x1C), "Erdrick's Cave B1", "0x1C should resolve to Erdrick's Cave B1")
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
