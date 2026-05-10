-- test_overworld_routes.lua
-- Regression tests for manual overworld route guidance.

local original_loaded = package.loaded["overworld_routes"]
package.loaded["overworld_routes"] = nil

local routes = require "overworld_routes"

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local function assert_contains(value, needle, message)
    if not tostring(value):find(needle, 1, true) then
        error(string.format("%s: expected %q to contain %q", message, tostring(value), needle), 2)
    end
end

local tests = {}

function tests.erdric_alias_starts_erdrick_route_from_current_progress()
    routes.reset_for_tests()

    local info, err = routes.start("erdric", 0x01, 30, 32)

    assert_equal(err, nil, "route alias should resolve")
    assert_contains(info.message, "Route to Erdrick's Cave", "start should name the route")
    assert_contains(info.message, "East choke approach", "starting at the pinch should point east before north")
    assert_equal(info.object_id, "route_erdrick_07", "start should expose the active waypoint object id")

    routes.reset_for_tests()
end

function tests.reaching_waypoint_advances_to_next_waypoint()
    routes.reset_for_tests()
    routes.start("cave", 0x01, 30, 32)

    local event = routes.observe_position(0x01, 35, 32)

    assert_contains(event.message, "Reached East choke approach", "arrival should announce reached waypoint")
    assert_contains(event.message, "Next: Eastern mountain lane", "arrival should announce the next waypoint")
    assert_equal(event.refresh, true, "object list should refresh after route advance")

    routes.reset_for_tests()
end

function tests.east_choke_requires_exact_lane_tile()
    routes.reset_for_tests()
    routes.start("cave", 0x01, 30, 32)

    local early = routes.observe_position(0x01, 34, 32)
    local status = routes.status(0x01, 34, 32)
    local event = routes.observe_position(0x01, 35, 32)

    assert_equal(early, nil, "east choke should not advance from one tile west")
    assert_contains(status.message, "East choke approach, 1 east", "route should still guide onto the choke lane")
    assert_contains(event.message, "Reached East choke approach", "exact choke lane should advance")
    assert_contains(event.message, "Next: Eastern mountain lane", "exact choke lane should point north afterward")

    routes.reset_for_tests()
end

function tests.eastern_mountain_lane_requires_exact_column()
    routes.reset_for_tests()
    routes.start("cave", 0x01, 30, 32)
    routes.observe_position(0x01, 35, 32)

    local early = routes.observe_position(0x01, 34, 24)
    local status = routes.status(0x01, 34, 24)
    local event = routes.observe_position(0x01, 35, 24)

    assert_equal(early, nil, "eastern mountain lane should not advance from one tile west")
    assert_contains(status.message, "Eastern mountain lane, 1 east", "route should finish the lane before the next bend")
    assert_contains(event.message, "Reached Eastern mountain lane", "exact mountain lane should advance")
    assert_contains(event.message, "Next: North ridge bend", "exact mountain lane should point to the ridge bend")

    routes.reset_for_tests()
end

function tests.north_trail_marker_advances_to_cave_after_pinch_markers()
    routes.reset_for_tests()
    routes.start("cave", 0x01, 30, 32)

    routes.observe_position(0x01, 35, 32)
    routes.observe_position(0x01, 35, 24)
    routes.observe_position(0x01, 32, 19)
    local event = routes.observe_position(0x01, 28, 20)

    assert_contains(event.message, "Reached North trail marker", "north trail should still be a route step")
    assert_contains(event.message, "Next: Erdrick's Cave", "north trail should point to the cave after pinch markers")

    routes.reset_for_tests()
end

function tests.bridge_warning_is_spoken_once_when_crossing_marker()
    routes.reset_for_tests()
    routes.start("erdrick", 0x01, 48, 41)

    local event = routes.observe_position(0x01, 44, 38)
    local repeat_event = routes.observe_position(0x01, 44, 38)

    assert_contains(event.message, "Bridge crossing", "bridge marker should warn about danger")
    assert_contains(event.message, "Monsters may become more dangerous", "bridge warning should mention stronger monsters")
    assert_contains(event.message, "Next: Bridge lower west lane", "bridge marker should route through the detour")
    assert_equal(repeat_event, nil, "same position should not repeat route speech")

    routes.reset_for_tests()
end

function tests.active_waypoints_are_exposed_as_travel_objects()
    routes.reset_for_tests()
    routes.start("erdrick", 0x01, 30, 32)

    local objects = routes.get_active_waypoint_objects()

    assert_equal(objects[1].id, "route_erdrick_07", "first exposed object should be the active next waypoint")
    assert_equal(objects[2].id, "route_erdrick_08", "second exposed object should be the next context waypoint")
    assert_equal(objects[3], nil, "active route should not flood Travel with every remaining waypoint")
    assert_equal(objects[1].type, "exit", "route waypoints should appear in the Travel filter")
    assert_equal(objects[1].route_waypoint, true, "route object should be identifiable")

    routes.reset_for_tests()
end

function tests.route_can_start_from_matching_travel_object()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_erdrick_s_cave",
        name = "Erdrick's Cave",
        x = 28,
        y = 12,
    }, 0x01, 30, 32)

    assert_equal(err, nil, "matching Travel object should start a route")
    assert_equal(info.object_id, "route_erdrick_07", "route should focus the next useful waypoint")
    assert_contains(info.message, "East choke approach", "started route should speak the next waypoint")

    routes.reset_for_tests()
end

function tests.brecconary_object_starts_safety_route_from_cave()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_brecconary",
        name = "Brecconary",
        x = 48,
        y = 41,
    }, 0x01, 28, 12)

    assert_equal(err, nil, "Brecconary Travel object should start a safety route")
    assert_equal(info.object_id, "route_brecconary_02", "route should skip the cave anchor when already there")
    assert_contains(info.message, "Route to Brecconary", "start should name the safety route")
    assert_contains(info.message, "North trail marker", "safety route should first guide back down the cave road")

    routes.reset_for_tests()
end

function tests.tantegel_object_starts_safety_route_from_cave()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_tantegel_castle",
        name = "Tantegel Castle",
        x = 43,
        y = 43,
    }, 0x01, 28, 12)

    assert_equal(err, nil, "Tantegel Castle Travel object should start a safety route")
    assert_equal(info.object_id, "route_tantegel_02", "route should skip the cave anchor when already there")
    assert_contains(info.message, "Route to Tantegel Castle", "start should name the castle route")
    assert_contains(info.message, "North trail marker", "castle route should first guide back down the cave road")

    routes.reset_for_tests()
end

function tests.breconary_alias_accepts_common_single_c_spelling()
    routes.reset_for_tests()

    local info, err = routes.start("breconary", 0x01, 28, 12)

    assert_equal(err, nil, "alternate Brecconary spelling should resolve")
    assert_contains(info.message, "Route to Brecconary", "alias should start the Brecconary route")

    routes.reset_for_tests()
end

function tests.erdrick_route_uses_upper_bridge_lane_before_east_choke()
    routes.reset_for_tests()

    local info, err = routes.start("erdrick", 0x01, 45, 34)

    assert_equal(err, nil, "Erdrick route should start from the first bridge")
    assert_equal(info.object_id, "route_erdrick_03", "first bridge should point to the south detour")
    assert_contains(info.message, "Bridge south bend", "route should avoid the blocked direct north-west approach")

    local south_bend = routes.observe_position(0x01, 44, 38)
    assert_contains(south_bend.message, "Reached Bridge south bend", "bridge south bend should be an explicit step")
    assert_contains(south_bend.message, "Next: Bridge lower west lane", "south bend should route around the blocked row")

    local lower_lane = routes.observe_position(0x01, 38, 36)
    assert_contains(lower_lane.message, "Reached Bridge lower west lane", "lower lane should prevent early north turns")
    assert_contains(lower_lane.message, "Next: Bridge west bend", "lower lane should route up on the passable column")

    local west_bend = routes.observe_position(0x01, 38, 34)
    assert_contains(west_bend.message, "Reached Bridge west bend", "bridge west bend should be an explicit step")
    assert_contains(west_bend.message, "Next: Upper bridge lane", "west bend should route up before turning west")

    local upper_lane = routes.observe_position(0x01, 38, 32)
    assert_contains(upper_lane.message, "Reached Upper bridge lane", "upper bridge lane should be an explicit step")
    assert_contains(upper_lane.message, "Next: East choke approach", "upper lane should point west to the choke")

    routes.reset_for_tests()
end

function tests.brecconary_safety_route_uses_upper_bridge_lane_after_choke()
    routes.reset_for_tests()

    local info, err = routes.start("brecconary", 0x01, 30, 32)

    assert_equal(err, nil, "Brecconary route should start from the mountain-pinch area")
    assert_equal(info.object_id, "route_brecconary_05", "pinch area should point east before the bridge detour")
    assert_contains(info.message, "East choke approach", "route should avoid the old west-then-east reversal")

    local east_choke = routes.observe_position(0x01, 35, 32)
    assert_contains(east_choke.message, "Reached East choke approach", "east choke should be an explicit return step")
    assert_contains(east_choke.message, "Next: Upper bridge lane", "east choke should point east toward the bridge lane")

    local upper_lane = routes.observe_position(0x01, 38, 32)
    assert_contains(upper_lane.message, "Reached Upper bridge lane", "upper bridge lane should be an explicit return step")
    assert_contains(upper_lane.message, "Next: Bridge west bend", "upper lane should turn south to the bridge bend")

    local west_bend = routes.observe_position(0x01, 38, 34)
    assert_contains(west_bend.message, "Reached Bridge west bend", "bridge detour should be an explicit step")
    assert_contains(west_bend.message, "Next: Bridge lower west lane", "west bend should route down before going east")

    local lower_lane = routes.observe_position(0x01, 38, 36)
    assert_contains(lower_lane.message, "Reached Bridge lower west lane", "lower lane should be an explicit return step")
    assert_contains(lower_lane.message, "Next: Bridge south bend", "lower lane should route east on the lower road")

    local south_bend = routes.observe_position(0x01, 44, 38)
    assert_contains(south_bend.message, "Reached Bridge south bend", "lower bridge bend should be an explicit step")
    assert_contains(south_bend.message, "Next: Brecconary", "lower bend should stop the old north-then-south backtrack")

    routes.reset_for_tests()
end

function tests.tantegel_safety_route_uses_upper_bridge_lane_after_choke()
    routes.reset_for_tests()

    local info, err = routes.start("castle", 0x01, 30, 32)

    assert_equal(err, nil, "Tantegel route should start from the mountain-pinch area")
    assert_equal(info.object_id, "route_tantegel_05", "castle return should share the east-choke recovery")
    assert_contains(info.message, "East choke approach", "castle route should avoid the old west-then-east reversal")

    routes.reset_for_tests()
end

function tests.unmatched_object_reports_no_guided_route()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_garinham",
        name = "Garinham",
        x = 6,
        y = 6,
    }, 0x01, 43, 43)

    assert_equal(info, nil, "unknown destination should not start a route")
    assert_contains(err, "No guided route for Garinham", "missing route should name the selected object")
    assert_contains(err, "Use O for heading", "missing route should preserve the plain heading workflow")

    routes.reset_for_tests()
end

function tests.final_waypoint_arrival_stops_route()
    routes.reset_for_tests()
    routes.start("erdrick", 0x01, 28, 20)

    local event = routes.observe_position(0x01, 28, 12)

    assert_contains(event.message, "Arrived at Erdrick's Cave", "final waypoint should announce arrival")
    assert_equal(routes.is_active(), false, "route should stop after final arrival")

    routes.reset_for_tests()
end

function tests.entering_destination_map_stops_route()
    routes.reset_for_tests()
    routes.start("erdrick", 0x01, 28, 13)

    local event = routes.observe_position(0x1C, 0, 0)

    assert_contains(event.message, "Arrived at Erdrick's Cave", "entering cave map should complete the route")
    assert_equal(event.refresh, true, "destination map arrival should refresh Travel objects")
    assert_equal(routes.is_active(), false, "route should stop after entering the destination map")

    routes.reset_for_tests()
end

function tests.entering_brecconary_stops_safety_route()
    routes.reset_for_tests()
    routes.start("brecconary", 0x01, 48, 40)

    local event = routes.observe_position(0x08, 0, 15)

    assert_contains(event.message, "Arrived at Brecconary", "entering town should complete the safety route")
    assert_equal(event.refresh, true, "destination map arrival should refresh Travel objects")
    assert_equal(routes.is_active(), false, "route should stop after entering Brecconary")

    routes.reset_for_tests()
end

function tests.entering_tantegel_stops_safety_route()
    routes.reset_for_tests()
    routes.start("castle", 0x01, 43, 42)

    local event = routes.observe_position(0x04, 0, 0)

    assert_contains(event.message, "Arrived at Tantegel Castle", "entering castle should complete the safety route")
    assert_equal(event.refresh, true, "destination map arrival should refresh Travel objects")
    assert_equal(routes.is_active(), false, "route should stop after entering Tantegel")

    routes.reset_for_tests()
end

function tests.selected_destination_replaces_active_route()
    routes.reset_for_tests()
    routes.start("cave", 0x01, 30, 32)

    local info, err = routes.guidance_for_object({
        id = "overworld_brecconary",
        name = "Brecconary",
        x = 48,
        y = 41,
    }, 0x01, 28, 12)

    assert_equal(err, nil, "selecting another guided destination should replace the active route")
    assert_contains(info.message, "Route changed. Route to Brecconary", "replacement should be audible")
    assert_equal(info.object_id, "route_brecconary_02", "replacement should calculate from the current position")
    assert_contains(info.log, "event=replace route=brecconary", "replacement should be logged distinctly")
    assert_equal(routes.active_route_id(), "brecconary", "new destination should become active")

    routes.reset_for_tests()
end

function tests.active_route_status_recalculates_after_drift()
    routes.reset_for_tests()
    routes.start("cave", 0x01, 30, 32)

    local info = routes.guidance_for_object({
        id = "route_erdrick_07",
        name = "Route next: East choke approach",
        route_id = "erdrick",
        route_waypoint = true,
        x = 35,
        y = 32,
    }, 0x01, 48, 41)

    assert_contains(info.message, "Route recalculated", "active route status should recover from large drift")
    assert_contains(info.message, "Bridge south bend", "recalculation should choose the best waypoint for the new position")
    assert_equal(info.object_id, "route_erdrick_03", "route waypoint focus should move to the recalculated waypoint")
    assert_contains(info.log, "event=recalculate route=erdrick", "drift recovery should be visible in logs")

    routes.reset_for_tests()
end

function tests.selected_same_destination_recalculates_active_route()
    routes.reset_for_tests()
    routes.start("cave", 0x01, 30, 32)

    local info = routes.guidance_for_object({
        id = "overworld_erdrick_s_cave",
        name = "Erdrick's Cave",
        x = 28,
        y = 12,
    }, 0x01, 48, 41)

    assert_contains(info.message, "Route recalculated. Route to Erdrick's Cave", "same destination should explicitly recalculate")
    assert_equal(info.object_id, "route_erdrick_03", "same-destination recalculation should use current position")
    assert_contains(info.log, "event=recalculate route=erdrick", "same-destination recalc should be logged")

    routes.reset_for_tests()
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

package.loaded["overworld_routes"] = original_loaded

if failures > 0 then
    os.exit(1)
end
