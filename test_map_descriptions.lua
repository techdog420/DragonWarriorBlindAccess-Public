-- Coverage and visibility policy for the authored artwork overviews.
local descriptions = require "map_descriptions"
local maps = require "maps"
local tests = {}

function tests.every_interior_has_one_named_paragraph()
    local count = 0
    for id, name in pairs(maps.names) do
        if id ~= maps.WORLD_MAP_ID then
            local message, result = descriptions.describe({map_id=id, terrain_offset=0x10}, "field")
            assert(result == "available", name)
            assert(message:sub(1,#name+2) == name .. ". ", name)
            local text = descriptions.entries[id]
            assert(not text:find("[\r\n]"), name)
            local _, words = text:gsub("%S+", "")
            assert(words >= 40 and words <= 100, name .. " paragraph length")
            count = count + 1
        end
    end
    assert(count == 28)
    for id in pairs(descriptions.entries) do
        assert(maps.names[id] and id ~= maps.WORLD_MAP_ID)
    end
end

function tests.physical_darkness_applies_to_every_navigation_mode()
    for _, mode in ipairs({"balanced", "authentic", "unrestricted"}) do
        local current = {map_id=0x1C, terrain_offset=0x20, light_radius=1, navigation_mode=mode}
        local _, result = descriptions.describe(current, "field")
        assert(result == "darkness", mode .. " must not bypass darkness")
        for _, radius in ipairs({3,5,7}) do
            current.light_radius = radius
            local message, lit = descriptions.describe(current, "field")
            assert(lit == "available" and message:find("Erdrick's Cave B1",1,true))
        end
        current.light_radius = 1 -- torch/Radiant expiration
        current.radiant_timer = 1 -- timer alone does not provide visible light
        local _, expired = descriptions.describe(current, "field")
        assert(expired == "darkness")
    end
end

function tests.lit_interiors_ignore_stale_light_bytes_and_unknown_maps_are_safe()
    local _, lit = descriptions.describe({map_id=0x08,terrain_offset=0x10,light_radius=1}, "field")
    assert(lit == "available")
    for _, id in ipairs({0x01,0,0xFF}) do
        local message, result = descriptions.describe({map_id=id,terrain_offset=0x20}, "field")
        assert(result == "no_description" and message ~= "")
    end
    assert(select(2,descriptions.describe({}, "field")) == "no_description")
    for _, state in ipairs({"battle","title"}) do
        assert(select(2,descriptions.describe({map_id=0x08},state)) == "not_field")
    end
    assert(select(2,descriptions.describe(nil,nil)) == "not_field")
end

local count = 0
for name, test in pairs(tests) do test();count=count+1;print("PASS " .. name) end
print("Ran " .. count .. " map description tests")
