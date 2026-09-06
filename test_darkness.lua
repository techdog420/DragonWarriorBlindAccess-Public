-- test_darkness.lua
-- Deterministic tests for dungeon visibility and speech policy.

package.loaded["darkness"] = nil
local darkness = require "darkness"

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end


local function assert_contains(text, fragment, message)
    if not tostring(text):find(fragment, 1, true) then
        error(string.format("%s: expected %q in %q", message, fragment, tostring(text)), 2)
    end
end


local function assert_not_contains(text, fragment, message)
    if tostring(text):find(fragment, 1, true) then
        error(string.format("%s: did not expect %q in %q", message, fragment, tostring(text)), 2)
    end
end

local tests = {}

function tests.light_radius_byte_is_a_visible_window_diameter()
    assert_equal(darkness.visible_half_span(1), 0, "radius byte 1 should reveal only the current tile")
    assert_equal(darkness.visible_half_span(3), 1, "radius byte 3 should reveal one tile around the hero")
    assert_equal(darkness.visible_half_span(5), 2, "radius byte 5 should reveal two tiles around the hero")
    assert_equal(darkness.visible_half_span(7), 3, "radius byte 7 should reveal three tiles around the hero")
end

function tests.non_dungeon_context_is_unrestricted()
    local context = darkness.context({terrain_offset = 0x10, x = 5, y = 5, light_radius = 1})
    assert_equal(context.limited, false, "town terrain should not use dungeon visibility")
    assert_equal(darkness.is_visible(context, 30, 30), true, "lit maps should expose all modeled cells")
end

function tests.dungeon_visibility_uses_the_square_shown_by_the_game()
    local context = darkness.context({terrain_offset = 0x20, x = 5, y = 5, light_radius = 3})
    assert_equal(darkness.is_visible(context, 4, 4), true, "diagonal corner inside the 3 by 3 square should be visible")
    assert_equal(darkness.is_visible(context, 6, 6), true, "opposite diagonal corner should be visible")
    assert_equal(darkness.is_visible(context, 7, 5), false, "cell beyond the visible half-span should be hidden")
end

function tests.description_distinguishes_darkness_and_radiant_light()
    local dark = darkness.context({terrain_offset = 0x20, light_radius = 1, radiant_timer = 0})
    local torch = darkness.context({terrain_offset = 0x20, light_radius = 3, radiant_timer = 0})
    local radiant = darkness.context({terrain_offset = 0x20, light_radius = 7, radiant_timer = 30})
    assert_equal(darkness.describe(dark), "Dungeon darkness. Only the current tile is visible", "unlit description")
    assert_equal(darkness.describe(torch), "Torchlight. One tile is visible in every direction", "Torch description")
    assert_equal(darkness.describe(radiant), "Radiant light. 3 tiles are visible in every direction", "Radiant description")
end

function tests.announcements_ignore_timer_ticks_but_report_radius_changes()
    local wide = darkness.context({terrain_offset = 0x20, light_radius = 7, radiant_timer = 30})
    local timer_tick = darkness.context({terrain_offset = 0x20, light_radius = 7, radiant_timer = 29})
    local dimmer = darkness.context({terrain_offset = 0x20, light_radius = 5, radiant_timer = 20})
    local dark = darkness.context({terrain_offset = 0x20, light_radius = 1, radiant_timer = 0})
    assert_equal(darkness.change_announcement(wide, timer_tick), nil, "timer-only changes should stay quiet")
    assert_equal(
        darkness.change_announcement(wide, dimmer),
        "The light dims. Radiant light. 2 tiles are visible in every direction",
        "radius shrink should be announced")
    assert_equal(
        darkness.change_announcement(dimmer, dark),
        "The light fades. Only the current tile is visible",
        "final light loss should be explicit")
end

function tests.walkability_mask_hides_cells_outside_the_visible_square()
    local source = {
        [4] = {[4] = true, [5] = true, [6] = true, [7] = true},
        [5] = {[4] = true, [5] = true, [6] = false, [7] = true},
        [6] = {[4] = true, [5] = true, [6] = true, [7] = true},
    }
    local context = darkness.context({terrain_offset = 0x20, x = 5, y = 5, light_radius = 3})
    local masked = darkness.limit_walkability_snapshot(source, context)
    assert_equal(masked[4][4], true, "visible walkable corner should remain walkable")
    assert_equal(masked[5][6], false, "visible wall should remain blocked")
    assert_equal(masked[5][7], false, "walkable cell outside the light should be masked")
    assert_equal(source[5][7], true, "masking must not mutate decoded map data")
end

function tests.navigation_limit_can_be_disabled_without_changing_physical_light()
    local source = {
        [5] = {[5] = true, [6] = true, [7] = true},
    }
    local context = darkness.context({
        terrain_offset = 0x20,
        x = 5,
        y = 5,
        light_radius = 1,
        navigation_limits_enabled = false,
    })
    assert_equal(context.limited, true, "the dungeon should remain physically dark")
    assert_equal(context.navigation_limited, false, "the accessibility restriction should be disabled")
    assert_equal(darkness.is_within_light(context, 7, 5), false, "the physical light test should remain honest")
    assert_equal(darkness.is_visible(context, 7, 5), true, "navigation should expose decoded cells when opted out")
    assert_equal(
        darkness.limit_walkability_snapshot(source, context),
        source,
        "disabled navigation limits should preserve the original decoded snapshot")
end

function tests.visible_area_report_summarizes_only_lit_paths_layout_and_objects()
    local source = {}
    for y = 0, 4 do
        source[y] = {}
        for x = 0, 4 do
            source[y][x] = false
        end
    end
    source[2][0] = true
    source[2][1] = true
    source[2][2] = true
    source[2][3] = true
    source[2][4] = true
    source[1][2] = true
    source[1][3] = true
    source[3][3] = true

    local context = darkness.context({terrain_offset = 0x20, x = 2, y = 2, light_radius = 5})
    local report = darkness.describe_visible_area(context, source, {
        {name = "Stairs", x = 4, y = 2},
        {name = "Hidden chest", x = 5, y = 2},
    })

    assert_contains(report, "north open 1 tile, then blocked", "north wall distance should be reported")
    assert_contains(report, "east open 2 tiles to edge of light", "open path to the light boundary should be reported")
    assert_contains(report, "south blocked", "an immediate wall should be reported")
    assert_contains(report, "branch 1 tile east", "a visible junction should be reported")
    assert_contains(report, "Stairs, 2 tiles east", "a visible object should be reported")
    assert_not_contains(report, "Hidden chest", "an object beyond the light must not leak")
end

function tests.unlit_report_does_not_invent_neighboring_information()
    local context = darkness.context({terrain_offset = 0x20, x = 2, y = 2, light_radius = 1})
    local report = darkness.describe_visible_area(context, {[2] = {[2] = true}}, {
        {name = "Entrance", x = 2, y = 2},
        {name = "Chest", x = 3, y = 2},
    })
    assert_contains(report, "No neighboring terrain is visible", "unlit report should state the hard limit")
    assert_contains(report, "Entrance, here", "an object on the hero's tile should be reported")
    assert_not_contains(report, "Chest", "an adjacent object should remain hidden without light")
end

function tests.visible_area_report_stays_light_bounded_when_navigation_is_unrestricted()
    local context = darkness.context({
        terrain_offset = 0x20,
        x = 2,
        y = 2,
        light_radius = 1,
        navigation_limits_enabled = false,
    })
    local report = darkness.describe_visible_area(context, {[2] = {[2] = true}}, {
        {name = "Hidden stairs", x = 3, y = 2},
    })
    assert_contains(report, "Navigation assistance is unrestricted by darkness", "opt-out state should be explicit")
    assert_not_contains(report, "Hidden stairs", "the local report should never become a full-map reveal")
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
