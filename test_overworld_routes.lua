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

local function assert_not_contains(value, needle, message)
    if tostring(value):find(needle, 1, true) then
        error(string.format("%s: expected %q not to contain %q", message, tostring(value), needle), 2)
    end
end

local function find_waypoint(route_id, name)
    local route = routes._route_for_tests(route_id)
    if not route then return nil end
    for _, waypoint in ipairs(route.waypoints or {}) do
        if waypoint.name == name then
            return waypoint
        end
    end
    return nil
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
    assert_equal(event.warning_message, nil, "routine waypoint should not expose warning speech")
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

function tests.north_trail_to_ridge_goes_horizontal_first_on_forward_routes()
    local forward_routes = {"brecconary", "tantegel", "tantegel_kol"}

    for _, route_id in ipairs(forward_routes) do
        routes.reset_for_tests()
        routes.start(route_id, 0x01, 28, 20)

        local segment = assert(routes.plan_next_segment(0x01, 28, 20))

        assert_equal(segment.waypoint.name, "North ridge bend", route_id .. " should still target the ridge bend")
        assert_equal(segment.steps[1], "right", route_id .. " should avoid the live-blocked north edge from the trail marker")
    end

    local reverse_routes = {"garinham", "kol", "erdrick"}
    for _, route_id in ipairs(reverse_routes) do
        routes.reset_for_tests()
        routes.start(route_id, 0x01, 35, 24)

        local segment = assert(routes.plan_next_segment(0x01, 35, 24))

        assert_equal(segment.waypoint.name, "North ridge bend", route_id .. " should still target the ridge bend")
        assert_equal(segment.steps[1], "up", route_id .. " should keep the mountain-lane approach unchanged")
    end

    routes.reset_for_tests()
end

function tests.final_carry_preview_uses_next_waypoint_axis_order_and_strictness()
    local horizontal_route = {
        waypoints = {
            {x = 10, y = 10, name = "Current"},
            {
                x = 13,
                y = 12,
                name = "Horizontal next",
                axis_order = {"horizontal", "vertical"},
            },
        },
    }
    local vertical_route = {
        waypoints = {
            {x = 10, y = 10, name = "Current"},
            {
                x = 13,
                y = 12,
                name = "Vertical next",
                axis_order = {"vertical", "horizontal"},
            },
        },
    }

    local hx, hy = routes._preview_final_carry_for_tests(horizontal_route, 1)
    assert_equal(hx, 11, "horizontal-first lookahead should move east")
    assert_equal(hy, 10, "horizontal-first lookahead should preserve the row")

    local vx, vy = routes._preview_final_carry_for_tests(vertical_route, 1)
    assert_equal(vx, 10, "vertical-first lookahead should preserve the column")
    assert_equal(vy, 11, "vertical-first lookahead should move south")

    local final_x, final_y =
        routes._preview_final_carry_for_tests(vertical_route, 2)
    assert_equal(final_x, nil, "final waypoint should have no carry target")
    assert_equal(final_y, nil, "final waypoint should have no carry target")

    horizontal_route.waypoints[1].route_accept_final_drift_completion = false
    local strict_x, strict_y =
        routes._preview_final_carry_for_tests(horizontal_route, 1)
    assert_equal(strict_x, nil, "explicitly strict waypoint should reject carry")
    assert_equal(strict_y, nil, "explicitly strict waypoint should reject carry")
end

function tests.plan_next_segment_includes_route_aware_final_carry()
    routes.reset_for_tests()
    routes.start("erdrick", 0x01, 30, 32)

    local segment = assert(routes.plan_next_segment(0x01, 30, 32))

    assert_equal(
        segment.waypoint.name,
        "East choke approach",
        "fixture should target the east choke"
    )
    assert_equal(
        segment.route_final_carry_x,
        35,
        "next segment should remain on the eastern mountain column"
    )
    assert_equal(
        segment.route_final_carry_y,
        31,
        "next segment should begin one tile north toward the mountain lane"
    )

    routes.reset_for_tests()
end

function tests.bridge_west_bend_recovers_horizontally_after_upper_lane_drift()
    local forward_routes = {"brecconary", "tantegel", "tantegel_kol"}

    for _, route_id in ipairs(forward_routes) do
        routes.reset_for_tests()
        routes.start(route_id, 0x01, 35, 32)
        routes.observe_position(0x01, 38, 32)

        local segment = assert(routes.plan_next_segment(0x01, 39, 32))

        assert_equal(segment.waypoint.name, "Bridge west bend", route_id .. " should still target the bridge bend after upper-lane drift")
        assert_equal(segment.steps[1], "left", route_id .. " should recover horizontally before descending from the drifted east lane")
    end

    routes.reset_for_tests()
end

function tests.bridge_warning_is_spoken_once_when_crossing_marker()
    routes.reset_for_tests()
    routes.start("erdrick", 0x01, 47, 41)

    local event = routes.observe_position(0x01, 44, 38)
    local repeat_event = routes.observe_position(0x01, 44, 38)

    assert_contains(event.message, "Bridge crossing", "bridge marker should warn about danger")
    assert_contains(event.message, "Monsters may become more dangerous", "bridge warning should mention stronger monsters")
    assert_contains(event.message, "Next: Bridge lower west lane", "bridge marker should route through the detour")
    assert_contains(event.warning_message, "Bridge crossing", "bridge event should expose warning-only speech")
    assert_contains(event.warning_message, "Monsters may become more dangerous", "warning-only speech should preserve the safety detail")
    assert_not_contains(event.warning_message, "Next:", "warning-only speech should omit routine waypoint guidance")
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
    assert_equal(info.object_id, "route_brecconary_17", "route should skip the cave-road anchor when already there")
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
    assert_equal(info.object_id, "route_tantegel_17", "route should skip the cave-road anchor when already there")
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
    assert_equal(info.object_id, "route_brecconary_20", "pinch area should point east before the bridge detour")
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
    assert_equal(info.object_id, "route_tantegel_20", "castle return should share the east-choke recovery")
    assert_contains(info.message, "East choke approach", "castle route should avoid the old west-then-east reversal")

    routes.reset_for_tests()
end

function tests.garinham_object_starts_route_from_tantegel_road()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_garinham",
        name = "Garinham",
        x = 1,
        y = 2,
    }, 0x01, 43, 43)

    assert_equal(err, nil, "Garinham Travel object should start a route")
    assert_equal(info.object_id, "route_garinham_02", "route should skip the current Tantegel road anchor")
    assert_contains(info.message, "Route to Garinham", "started route should name Garinham")
    assert_contains(info.message, "Brecconary west bypass",
        "route should leave Tantegel without entering Brecconary")

    routes.reset_for_tests()
end

function tests.garinham_route_bypasses_brecconary_west_doorstep()
    routes.reset_for_tests()

    local route = assert(routes._route_for_tests("garinham"))
    local bypass = assert(route.waypoints[2])

    assert_equal(bypass.x, 47,
        "Garinham route should stop west of Brecconary instead of targeting its entrance")
    assert_equal(bypass.y, 41, "Garinham Brecconary bypass row")
    assert_equal(bypass.name, "Brecconary west bypass",
        "Garinham should name the non-entry path")

    routes.start("garinham", 0x01, 43, 43)
    local segment = assert(routes.plan_next_segment(0x01, 43, 43))
    assert_equal(segment.waypoint.name, "Brecconary west bypass",
        "Garinham travel should use the bypass")
    assert_equal(segment.path_length, 6,
        "the Garinham bypass should move two north and four east")

    routes.observe_position(0x01, 47, 41)
    segment = assert(routes.plan_next_segment(0x01, 47, 41))
    assert_equal(segment.waypoint.name, "Bridge south bend",
        "Garinham bypass should reconnect to the existing bridge route")
    assert_equal(segment.steps[1], "up",
        "Garinham bypass should turn north instead of entering Brecconary")

    routes.reset_for_tests()
end

function tests.erdrick_route_bypasses_brecconary_west_doorstep()
    routes.reset_for_tests()

    local route = assert(routes._route_for_tests("erdrick"))
    local bypass = assert(route.waypoints[2])

    assert_equal(bypass.x, 47,
        "Erdrick route should stop west of Brecconary instead of targeting its entrance")
    assert_equal(bypass.y, 41, "Erdrick Brecconary bypass row")
    assert_equal(bypass.name, "Brecconary west bypass",
        "Erdrick should name the non-entry path")

    routes.start("erdrick", 0x01, 43, 43)
    local segment = assert(routes.plan_next_segment(0x01, 43, 43))
    assert_equal(segment.waypoint.name, "Brecconary west bypass",
        "Erdrick travel should use the bypass")

    routes.observe_position(0x01, 47, 41)
    segment = assert(routes.plan_next_segment(0x01, 47, 41))
    assert_equal(segment.waypoint.name, "Bridge south bend",
        "Erdrick bypass should reconnect to the existing bridge route")
    assert_equal(segment.steps[1], "up",
        "Erdrick bypass should turn north instead of entering Brecconary")

    routes.reset_for_tests()
end

function tests.direct_brecconary_route_still_targets_town_entrance()
    local route = assert(routes._route_for_tests("brecconary"))
    local final = assert(route.waypoints[#route.waypoints])

    assert_equal(final.x, 48, "direct Brecconary travel should keep the town entrance column")
    assert_equal(final.y, 41, "direct Brecconary travel should keep the town entrance row")
    assert_equal(final.name, "Brecconary", "direct Brecconary travel should still name the town")
    assert_equal(final.final, true, "direct Brecconary travel should still finish at the town")
end

function tests.garinham_corridor_points_west_to_town()
    routes.reset_for_tests()

    local info, err = routes.start("garinham", 0x01, 2, 2)

    assert_equal(err, nil, "Garinham route should recalculate from the approach corridor")
    assert_equal(info.object_id, "route_garinham_27", "corridor should point to the corrected town tile")
    assert_contains(info.message, "Garinham", "route should keep naming the final town")
    assert_contains(info.message, "1 west", "route should guide west from the north-south corridor")

    routes.reset_for_tests()
end

function tests.garinham_route_extends_from_cave_to_town()
    routes.reset_for_tests()

    local info, err = routes.start("galenholm", 0x01, 28, 12)

    assert_equal(err, nil, "alternate Garinham name should resolve")
    assert_equal(info.object_id, "route_garinham_12", "route should skip the cave-road anchor when already there")
    assert_contains(info.message, "Cave road south lane", "route should begin with the verified cave-road jog")

    local south_lane = routes.observe_position(0x01, 23, 13)
    assert_contains(south_lane.message, "Reached Cave road south lane", "cave road jog should advance from the south lane")
    assert_contains(south_lane.message, "Next: Cave road west lane", "south lane should point north before turning west")

    local west_lane = routes.observe_position(0x01, 23, 11)
    assert_contains(west_lane.message, "Reached Cave road west lane", "west lane should advance on the return path")
    assert_contains(west_lane.message, "Next: Cave road north edge", "west lane should point west before the field bend")

    routes.observe_position(0x01, 21, 11)
    routes.observe_position(0x01, 21, 10)

    local east_field = routes.observe_position(0x01, 20, 9)
    assert_contains(east_field.message, "Reached Garinham east field", "northwest leg should advance from the field marker")
    assert_contains(east_field.message, "Next: Garinham field east lane", "field marker should route through the live east-field lane")

    routes.reset_for_tests()
end

function tests.garinham_route_from_mountain_shoulder_points_north()
    routes.reset_for_tests()

    local info, err = routes.start("garinham", 0x01, 14, 4)

    assert_equal(err, nil, "Garinham route should recalculate from the obstacle pocket")
    assert_equal(info.object_id, "route_garinham_23", "mountain shoulder should skip to the north coast lane")
    assert_contains(info.message, "Garinham north coast lane", "route should point out of the pocket before going west")
    assert_contains(info.message, "1 north", "route should tell the player to leave the obstacle pocket north")

    routes.reset_for_tests()
end

function tests.kol_object_starts_route_from_tantegel()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_kol",
        name = "Kol",
        x = 104,
        y = 10,
    }, 0x01, 43, 43)

    assert_equal(err, nil, "Kol Travel object should start a route")
    assert_equal(info.object_id, "route_kol_02", "route should skip the current Tantegel road anchor")
    assert_contains(info.message, "Route to Kol", "started route should name Kol")
    assert_contains(info.message, "Brecconary west bypass",
        "route should first leave Tantegel without entering Brecconary")

    routes.reset_for_tests()
end

function tests.kol_alias_starts_from_tantegel()
    routes.reset_for_tests()

    local info, err = routes.start("kol", 0x01, 43, 43)

    assert_equal(err, nil, "Kol route alias should resolve")
    assert_equal(info.object_id, "route_kol_02", "route should start from the Tantegel road")
    assert_contains(info.message, "Route to Kol", "start should name the route")

    routes.reset_for_tests()
end

function tests.kol_route_uses_garinham_road_and_north_bridges()
    routes.reset_for_tests()
    routes.start("kol", 0x01, 43, 43)

    routes.observe_position(0x01, 47, 41)
    local south_bend = routes.observe_position(0x01, 44, 38)
    assert_contains(south_bend.message, "Reached Bridge south bend", "Kol route should reuse the proven western bridge road")
    assert_contains(south_bend.message, "Next: Bridge lower west lane", "route should turn onto the lower bridge lane")

    routes.observe_position(0x01, 38, 36)
    routes.observe_position(0x01, 38, 34)
    routes.observe_position(0x01, 38, 32)
    routes.observe_position(0x01, 35, 32)
    routes.observe_position(0x01, 35, 24)
    routes.observe_position(0x01, 32, 19)
    routes.observe_position(0x01, 28, 20)
    local cave_road = routes.observe_position(0x01, 28, 13)
    assert_contains(cave_road.message, "Reached Erdrick's Cave road", "route should reach the Galenholm-to-Kol road")
    assert_contains(cave_road.message, "Next: North Alefgard west road", "route should continue east instead of returning toward Tantegel")

    routes.observe_position(0x01, 35, 13)
    routes.observe_position(0x01, 45, 13)
    routes.observe_position(0x01, 54, 15)
    local west_bend = routes.observe_position(0x01, 58, 18)
    assert_contains(west_bend.message, "Next: Northeast bridge lower west lane", "route should step down before the north bridge pinch")
    routes.observe_position(0x01, 59, 19)
    routes.observe_position(0x01, 61, 19)
    local northeast_bridge = routes.observe_position(0x01, 61, 18)
    assert_contains(northeast_bridge.message, "Northeast bridge crossing", "north bridge should warn about stronger monsters")
    assert_contains(northeast_bridge.message, "Next: North Alefgard bridge road", "north bridge should lead east across Alefgard")

    routes.observe_position(0x01, 74, 18)
    routes.observe_position(0x01, 84, 26)
    local kol_bridge = routes.observe_position(0x01, 90, 37)
    assert_contains(kol_bridge.message, "Kol southwest bridge crossing", "southwest bridge should call out the Kol-area danger bump")
    assert_contains(kol_bridge.message, "Next: Kol bridge east lane", "southwest bridge should route east toward the live south-road lane")
    routes.observe_position(0x01, 92, 37)
    routes.observe_position(0x01, 92, 36)
    routes.observe_position(0x01, 93, 36)
    routes.observe_position(0x01, 93, 35)
    routes.observe_position(0x01, 96, 35)
    local south_road = routes.observe_position(0x01, 96, 32)
    assert_contains(south_road.message, "Reached Kol south road", "route should use the live x=96 south-road lane")
    assert_contains(south_road.message, "Next: Kol south road lower east lane",
        "south road should detour east around the blocked x96 north seam")

    routes.reset_for_tests()
end

function tests.kol_route_uses_lower_northeast_bridge_lane()
    routes.reset_for_tests()
    routes.start("kol", 0x01, 58, 18)

    local drop = assert(routes.plan_next_segment(0x01, 58, 18))
    assert_equal(drop.waypoint.name, "Northeast bridge lower west lane", "west bend should drop to the lower bridge lane")
    assert_equal(drop.steps[1], "down", "west bend should move down instead of east into the row-18 pinch")

    routes.reset_for_tests()
    routes.start("kol", 0x01, 59, 19)

    local lane = assert(routes.plan_next_segment(0x01, 59, 19))
    assert_equal(lane.waypoint.name, "Northeast bridge south lane", "lower lane should continue east across the bridge")
    assert_equal(lane.steps[1], "right", "lower lane should continue east instead of moving up into the pinch")

    routes.reset_for_tests()
    routes.start("kol", 0x01, 61, 18)

    local east = assert(routes.plan_next_segment(0x01, 61, 18))
    assert_equal(east.waypoint.name, "North Alefgard bridge road", "east side of the bridge should not route back west")
    assert_equal(east.steps[1], "right", "east side should continue toward Kol")

    routes.reset_for_tests()
    routes.start("kol", 0x01, 60, 17)

    local north = assert(routes.plan_next_segment(0x01, 60, 17))
    assert_equal(north.waypoint.name, "Northeast bridge", "north side should still target the crossing marker")
    assert_equal(north.steps[1], "right", "north side should avoid the blocked north approach into 60,18")

    routes.reset_for_tests()
end

function tests.kol_route_heads_north_from_southwest_bridge()
    routes.reset_for_tests()
    routes.start("kol", 0x01, 90, 37)

    local segment = assert(routes.plan_next_segment(0x01, 90, 37))

    assert_equal(segment.waypoint.name, "Kol bridge east lane", "southwest bridge should target the east lane first")
    assert_equal(segment.steps[1], "right", "route should head east from the southwest bridge")
    assert_contains(segment.message, "Kol bridge east lane", "segment message should name the lane")

    routes.reset_for_tests()
end

function tests.kol_route_descends_before_southwest_track()
    routes.reset_for_tests()

    local start = assert(routes.start("kol", 0x01, 54, 15))
    assert_equal(start.route.id, "kol", "north bridge start should use the generic Kol route")

    local bridge_waypoints = {
        {x = 58, y = 18},
        {x = 59, y = 19},
        {x = 61, y = 19},
        {x = 61, y = 18},
        {x = 74, y = 18},
    }
    for _, waypoint in ipairs(bridge_waypoints) do
        routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    local segment = assert(routes.plan_next_segment(0x01, 77, 18))

    assert_equal(segment.waypoint.name, "Kol southwest track", "generic Kol route should retain the southwest-track target")
    assert_equal(segment.steps[1], "down", "generic Kol route should descend before the blocked east edge")
    assert_equal(segment.steps[8], "down", "generic Kol route should finish descending to row 26")
    assert_equal(segment.steps[9], "right", "generic Kol route should turn east only after reaching row 26")

    routes.reset_for_tests()
end

function tests.kol_route_follows_live_south_road_jog()
    routes.reset_for_tests()
    routes.start("kol", 0x01, 92, 37)

    local lower = assert(routes.plan_next_segment(0x01, 92, 37))
    assert_equal(lower.waypoint.name, "Kol lower south lane", "east bridge lane should step northbound through the live jog")
    assert_equal(lower.steps[1], "up", "east bridge lane should move up to the south-road jog")

    routes.reset_for_tests()
    routes.start("kol", 0x01, 93, 35)

    local east_lane = assert(routes.plan_next_segment(0x01, 93, 35))
    assert_equal(east_lane.waypoint.name, "Kol south road east lane", "lower bend should head east toward the live road")
    assert_equal(east_lane.steps[1], "right", "lower bend should move east instead of pulling west")

    routes.reset_for_tests()
    routes.start("kol", 0x01, 96, 33)

    local north_lane = assert(routes.plan_next_segment(0x01, 96, 33))
    assert_equal(north_lane.waypoint.name, "Kol south road lower east lane",
        "the original Kol route should reuse the newer live-proven x98 detour")
    assert_equal(north_lane.steps[1], "up",
        "one tile below the road marker should first recover north")

    routes.observe_position(0x01, 96, 32)
    local east_detour = assert(routes.plan_next_segment(0x01, 96, 32))
    assert_equal(east_detour.waypoint.name, "Kol south road lower east lane",
        "the route should step east before the blocked x96 north seam")
    assert_equal(east_detour.steps[1], "right",
        "the live-proven detour should leave x96 eastbound")

    routes.observe_position(0x01, 98, 32)
    local north_detour = assert(routes.plan_next_segment(0x01, 98, 32))
    assert_equal(north_detour.waypoint.name, "Kol south road east detour",
        "the route should climb the proven x98 lane")
    assert_equal(north_detour.steps[1], "up",
        "the x98 detour should continue north")

    routes.reset_for_tests()
end

function tests.kol_route_backs_out_of_dead_east_bridge_pocket()
    routes.reset_for_tests()

    local info, err = routes.start("kol", 0x01, 57, 38)

    assert_equal(err, nil, "Kol route should still start from the disproved east pocket")
    assert_equal(info.object_id, "route_kol_03", "dead pocket should backtrack toward the bridge south bend")
    assert_contains(info.message, "Bridge south bend",
        "route should not target the blocked 57,38 to 58,38 bridge edge")

    routes.reset_for_tests()
end

function tests.northern_cave_object_starts_route_from_kol()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_northern_cave",
        name = "Northern Cave",
        x = 81,
        y = 1,
    }, 0x01, 104, 10)

    assert_equal(err, nil, "Northern Cave Travel object should start a route")
    assert_equal(info.object_id, "route_northern_cave_02", "route should leave Kol toward the west forest edge")
    assert_contains(info.message, "Route to Northern Cave", "started route should name Northern Cave")
    assert_contains(info.message, "Kol forest west edge", "route should begin with the known west edge from Kol")

    routes.reset_for_tests()
end

function tests.northern_cave_aliases_use_kol_side_route()
    routes.reset_for_tests()

    local info, err = routes.start("staff of rain", 0x01, 104, 10)

    assert_equal(err, nil, "Staff of Rain alias should resolve to the northern cave route")
    assert_equal(info.object_id, "route_northern_cave_02", "route should start by leaving Kol")
    assert_contains(info.message, "Kol forest west edge", "route should avoid a direct diagonal to the shrine")

    local segment = assert(routes.plan_next_segment(0x01, 104, 10))
    assert_equal(segment.waypoint.name, "Kol forest west edge", "first segment should target the west forest edge")
    assert_equal(segment.steps[1], "left", "first segment should retrace the Kol forest lane west before turning south")

    routes.reset_for_tests()
end

function tests.northern_cave_from_tantegel_starts_kol_staging_route()
    routes.reset_for_tests()

    local info, err = routes.start("rain shrine", 0x01, 43, 43)

    assert_equal(err, nil, "Rain Shrine alias should resolve from Tantegel")
    assert_equal(info.route.id, "kol_staging", "far Northern Cave requests should stage outside Kol")
    assert_equal(info.object_id, "route_kol_staging_02", "staging route should leave Tantegel on the safe Kol leg")
    assert_contains(info.message, "Northern Cave route starts from Kol", "staging should explain the required hub")
    assert_contains(info.message, "Starting route to Kol first", "staging should say which route actually started")
    assert_contains(info.message, "Route to Kol", "staging should include normal route guidance")
    assert_contains(info.log, "staged_from=northern_cave", "staged starts should be visible in logs")

    local segment = assert(routes.plan_next_segment(0x01, 43, 43))
    assert_equal(segment.waypoint.name, "Brecconary west bypass", "Kol staging should avoid the town entrance")
    assert_equal(segment.steps[1], "up", "Tantegel-to-Kol staging should leave toward the west bypass")

    routes.reset_for_tests()
end

function tests.northern_cave_object_from_tantegel_starts_kol_staging_route()
    routes.reset_for_tests()

    local target = {
        id = "overworld_northern_cave",
        name = "Northern Cave",
        x = 81,
        y = 1,
    }
    local info, err = routes.start_for_object(target, 0x01, 43, 43)

    assert_equal(err, nil, "Northern Cave Travel object should resolve from Tantegel")
    assert_equal(info.route.id, "kol_staging", "Travel-object starts should use the safe Kol staging guard")
    assert_equal(info.object_id, "route_kol_staging_02", "Travel-object staging should start the non-entry Kol route")
    assert_contains(info.message, "Northern Cave route starts from Kol", "Travel-object staging should explain the hub route")
    assert_equal(routes.active_route_matches_object(target), true,
        "the selected Northern Cave object should remain bound during the Kol leg")

    routes.reset_for_tests()
end

function tests.northern_cave_staging_status_names_current_leg_and_final_destination()
    routes.reset_for_tests()
    routes.start("rain shrine", 0x01, 43, 43)

    local info = routes.status(0x01, 43, 43)

    assert_contains(info.message, "Current leg to Kol",
        "staging status should identify the route currently being followed")
    assert_contains(info.message, "Final destination: Northern Cave",
        "staging status should retain the player's requested destination")

    routes.reset_for_tests()
end

function tests.northern_cave_guidance_refresh_keeps_the_active_itinerary()
    routes.reset_for_tests()
    local target = {
        id = "overworld_northern_cave",
        name = "Northern Cave",
        x = 81,
        y = 1,
    }
    routes.start_for_object(target, 0x01, 43, 43)

    local info = routes.guidance_for_object(target, 0x01, 43, 43)

    assert_equal(info.route.id, "kol_staging",
        "re-reading guidance should keep the current Kol leg active")
    assert_contains(info.message, "Current leg to Kol",
        "re-reading guidance should report the active leg instead of restarting it")
    assert_contains(info.message, "Final destination: Northern Cave",
        "re-reading guidance should retain the requested destination")

    routes.reset_for_tests()
end

function tests.northern_cave_staging_hands_off_at_kol_without_starting_movement()
    routes.reset_for_tests()
    routes.start("rain shrine", 0x01, 43, 43)
    local kol = assert(routes._route_for_tests("kol_staging"))
    local event

    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    assert_equal(routes.active_route_id(), "northern_cave",
        "reaching Kol should activate the requested second leg")
    assert_equal(event.status, "handoff",
        "the route event should distinguish a leg handoff from final arrival")
    assert_contains(event.message, "Reached Kol west doorstep. Continuing to Northern Cave.",
        "handoff speech should name the completed hub and final destination")
    assert_contains(event.message, "Next: Kol forest west edge",
        "handoff speech should identify the next Northern Cave waypoint")
    assert_contains(event.log, "event=handoff",
        "handoff should be explicit in structured logs")
    assert_contains(event.log, "from_route=kol_staging",
        "handoff logs should identify the completed leg")
    assert_equal(event.object_id, "route_northern_cave_02",
        "route markers should refresh to the first Northern Cave movement waypoint")
    assert_equal(event.steps, nil,
        "handoff must wait for another player auto-walk command instead of moving immediately")

    local segment = assert(routes.plan_next_segment(0x01, 103, 10))
    assert_equal(segment.waypoint.name, "Kol forest west edge",
        "the next player-triggered segment should leave Kol toward the cave")
    assert_equal(segment.steps[1], "left",
        "the second leg should use the live-validated westbound Kol exit")

    routes.reset_for_tests()
end

function tests.northern_cave_staging_hands_off_when_kol_is_entered()
    routes.reset_for_tests()
    routes.start("rain shrine", 0x01, 43, 43)

    local event = routes.observe_position(0x07, 8, 8)

    assert_equal(routes.active_route_id(), "northern_cave",
        "entering Kol should preserve the requested Northern Cave itinerary")
    assert_equal(event.status, "handoff",
        "entering the staging destination should produce the same leg handoff")
    assert_contains(event.message, "Reached Kol west doorstep. Continuing to Northern Cave.",
        "interior handoff speech should name the completed hub and final destination")
    assert_equal(event.object_id, "route_northern_cave_02",
        "interior handoff should keep the next exterior route marker ready")
    assert_equal(event.steps, nil,
        "entering Kol must not start the second leg automatically")

    routes.reset_for_tests()
end

function tests.northern_cave_interior_handoff_ignores_stale_overworld_terrain_offset()
    routes.reset_for_tests()
    routes.start("rain shrine", 0x01, 43, 43)

    local event = routes.observe_position(0x07, 19, 23, 0x00)

    assert_equal(routes.active_route_id(), "northern_cave",
        "Kol entry should still activate the requested route during terrain-offset lag")
    assert_equal(event.status, "handoff",
        "the map transition should remain a staged-route handoff")
    assert_equal(event.object_id, "route_northern_cave_02",
        "interior coordinates must not select a distant overworld waypoint")
    assert_contains(event.message, "Next: Kol forest west edge",
        "handoff guidance should anchor the second leg at exterior Kol")

    routes.reset_for_tests()
end

function tests.stopping_northern_cave_staging_clears_the_whole_itinerary()
    routes.reset_for_tests()
    routes.start("rain shrine", 0x01, 43, 43)

    local event = routes.stop()

    assert_contains(event.message, "Stopped overworld route",
        "explicit route stop should acknowledge the cancellation")
    assert_equal(routes.is_active(), false,
        "explicit route stop should clear the current staging leg")
    assert_equal(routes.observe_position(0x01, 104, 10), nil,
        "a stopped itinerary must not resume or hand off when Kol is later reached")

    routes.reset_for_tests()
end

function tests.charlock_staging_status_names_current_leg_and_final_destination()
    routes.reset_for_tests()
    routes.start("charlock", 0x01, 102, 72)

    local info = routes.status(0x01, 102, 72)

    assert_contains(info.message, "Current leg to Swamp Cave South Entrance",
        "Charlock staging status should identify the route currently being followed")
    assert_contains(info.message, "Final destination: Charlock Castle",
        "Charlock staging status should retain the player's requested destination")

    routes.reset_for_tests()
end

function tests.charlock_staging_hands_off_at_south_cave_without_starting_movement()
    routes.reset_for_tests()
    local info = assert(routes.start("charlock", 0x01, 102, 72))

    assert_equal(info.route.id, "swamp_cave_south",
        "far Charlock requests should stage through the south cave route")
    assert_contains(info.log, "staged_from=charlock_castle",
        "the later progression destination should remain recorded during staging")

    local event = routes.observe_position(0x15, 0, 29)

    assert_equal(routes.active_route_id(), "charlock_castle",
        "entering the south cave should activate the requested Charlock leg")
    assert_equal(event.status, "handoff",
        "the Charlock itinerary should distinguish a leg handoff from final arrival")
    assert_contains(event.message,
        "Reached Swamp Cave South Entrance. Continuing to Charlock Castle.",
        "handoff speech should name the completed hub and final destination")
    assert_contains(event.message, "Next: Swamp Cave south doorstep",
        "handoff speech should identify the first exterior Charlock waypoint")
    assert_contains(event.log, "event=handoff",
        "Charlock handoff should be explicit in structured logs")
    assert_contains(event.log, "from_route=swamp_cave_south",
        "Charlock handoff logs should identify the completed leg")
    assert_equal(event.object_id, "route_charlock_castle_01",
        "route markers should refresh to the first Charlock movement waypoint")
    assert_equal(event.steps, nil,
        "Charlock handoff must wait for another player auto-walk command")

    local segment = assert(routes.plan_next_segment(0x01, 104, 49))
    assert_equal(segment.waypoint.name, "Swamp Cave south doorstep",
        "the next player-triggered segment should leave the cave entrance toward Charlock")
    assert_equal(#segment.steps, 1,
        "the first Charlock segment should move to the established safe doorstep")
    assert_equal(segment.steps[1], "left",
        "the second leg should leave the cave entrance westbound")

    routes.reset_for_tests()
end

function tests.rainbow_bridge_staging_status_names_current_leg_and_final_destination()
    routes.reset_for_tests()
    routes.start("rainbow bridge", 0x01, 102, 72)

    local info = routes.status(0x01, 102, 72)

    assert_contains(info.message, "Current leg to Swamp Cave South Entrance",
        "Rainbow Bridge staging status should identify the route currently being followed")
    assert_contains(info.message, "Final destination: Rainbow Bridge unlock point",
        "Rainbow Bridge staging status should retain the player's requested destination")

    routes.reset_for_tests()
end

function tests.rainbow_bridge_staging_hands_off_at_south_cave_without_starting_movement()
    routes.reset_for_tests()
    routes.start("rainbow bridge", 0x01, 102, 72)

    local event = routes.observe_position(0x15, 0, 29)

    assert_equal(routes.active_route_id(), "rainbow_bridge",
        "entering the south cave should activate the requested Rainbow Bridge leg")
    assert_equal(event.status, "handoff",
        "the Rainbow Bridge itinerary should distinguish a leg handoff from final arrival")
    assert_contains(event.message,
        "Reached Swamp Cave South Entrance. Continuing to Rainbow Bridge unlock point.",
        "handoff speech should name the completed hub and final destination")
    assert_contains(event.message, "Next: Rainbow Bridge east road",
        "handoff speech should identify the first westbound bridge waypoint")
    assert_contains(event.log, "event=handoff",
        "Rainbow Bridge handoff should be explicit in structured logs")
    assert_contains(event.log, "from_route=swamp_cave_south",
        "Rainbow Bridge handoff logs should identify the completed leg")
    assert_equal(event.object_id, "route_rainbow_bridge_02",
        "route markers should refresh to the first Rainbow Bridge movement waypoint")
    assert_equal(event.steps, nil,
        "Rainbow Bridge handoff must wait for another player auto-walk command")

    local segment = assert(routes.plan_next_segment(0x01, 104, 49))
    assert_equal(segment.waypoint.name, "Rainbow Bridge east road",
        "the next player-triggered segment should leave the south cave toward the bridge")
    assert_equal(#segment.steps, 11,
        "the first Rainbow Bridge segment should preserve the validated bounded distance")
    assert_equal(segment.steps[1], "left",
        "the second leg should leave the south cave westbound")

    routes.reset_for_tests()
end

function tests.northern_cave_near_entrance_does_not_stage_to_kol()
    routes.reset_for_tests()

    local info, err = routes.start("rain shrine", 0x01, 81, 1)

    assert_equal(err, nil, "Rain Shrine route should start near the entrance")
    assert_equal(info.route.id, "northern_cave", "local Rain Shrine starts should keep the destination route")
    assert_equal(info.object_id, "route_northern_cave_27", "entrance starts should target the cave itself")
    assert_contains(info.message, "Route to Northern Cave", "local start should speak normal destination guidance")

    routes.reset_for_tests()
end

function tests.nearby_destination_starts_snap_to_local_waypoints_before_staging()
    local cases = {
        {
            target = {
                id = "overworld_rainbow_bridge",
                name = "Rainbow Bridge unlock point",
                x = 65,
                y = 49,
            },
            start_x = 63,
            start_y = 49,
            route_id = "rainbow_bridge",
            waypoint_x = 65,
            waypoint_y = 49,
        },
        {
            target = {
                id = "overworld_charlock_castle",
                name = "Charlock Castle",
                x = 48,
                y = 48,
            },
            start_x = 48,
            start_y = 53,
            route_id = "charlock_castle",
            waypoint_x = 48,
            waypoint_y = 49,
        },
        {
            target = {
                id = "overworld_mountain_cave",
                name = "Mountain Cave",
                x = 29,
                y = 57,
            },
            start_x = 29,
            start_y = 55,
            route_id = "mountain_cave",
            waypoint_x = 29,
            waypoint_y = 57,
        },
        {
            target = {
                id = "overworld_eastern_great_swamp_search_area",
                name = "Eastern Great Swamp Search Area",
                x = 89,
                y = 112,
            },
            start_x = 87,
            start_y = 112,
            route_id = "great_swamp_cantlin",
            waypoint_x = 89,
            waypoint_y = 112,
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        local info, err = routes.start_for_object(
            case.target, 0x01, case.start_x, case.start_y)

        assert_equal(err, nil,
            case.target.name .. " should start near its destination")
        assert_equal(info.route.id, case.route_id,
            case.target.name .. " should not backtrack through a staging route")
        assert_not_contains(info.log, "staged_from=",
            case.target.name .. " should use ordinary nearest-waypoint guidance")

        local segment = assert(routes.plan_next_segment(
            0x01, case.start_x, case.start_y))
        assert_equal(segment.waypoint.x, case.waypoint_x,
            case.target.name .. " should snap to the local waypoint x")
        assert_equal(segment.waypoint.y, case.waypoint_y,
            case.target.name .. " should snap to the local waypoint y")
    end

    routes.reset_for_tests()
end

function tests.nearby_impassable_destination_separation_still_uses_staging()
    routes.reset_for_tests()
    local south_entrance = {
        id = "overworld_swamp_cave_south_entrance",
        name = "Swamp Cave South Entrance",
        x = 104,
        y = 49,
    }

    local info, err = routes.start_for_object(
        south_entrance, 0x01, 104, 44)

    assert_equal(err, nil,
        "south cave Travel should resolve from the nearby north entrance")
    assert_equal(info.route.id, "swamp_cave_north_entry_staging",
        "impassable overworld separation must retain the manual cave crossing")
    assert_contains(info.log, "staged_from=swamp_cave_south_swamp_cave_north",
        "the south entrance should remain the final destination")

    routes.reset_for_tests()
end

function tests.mountain_cave_object_starts_from_western_desert_route_pin()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_mountain_cave",
        name = "Mountain Cave",
        x = 29,
        y = 57,
    }, 0x01, 18, 64)

    assert_equal(err, nil, "Mountain Cave Travel object should start the route")
    assert_equal(info.route.id, "mountain_cave", "Mountain Cave object should use the local spur")
    assert_equal(info.object_id, "route_mountain_cave_02", "route should leave the existing pin toward the forest turn")
    assert_contains(info.message, "Mountain Cave forest turn", "route should begin with the two-tile west segment")

    routes.reset_for_tests()
end

function tests.mountain_cave_object_from_kol_starts_hauksness_prefix_connector()
    routes.reset_for_tests()
    local target = {
        id = "overworld_mountain_cave",
        name = "Mountain Cave",
        x = 29,
        y = 57,
    }

    local info, err = routes.start_for_object(target, 0x01, 104, 10)

    assert_equal(err, nil, "Mountain Cave Travel object should resolve from Kol")
    assert_equal(info.route.id, "mountain_cave_connector",
        "Kol-side Mountain Cave requests should start the validated Hauksness prefix")
    assert_equal(info.object_id, "route_mountain_cave_connector_02",
        "the connector should leave Kol through the first Hauksness waypoint")
    assert_contains(info.message, "Mountain Cave route starts from Western desert east road",
        "staging speech should retain Mountain Cave as the final destination")
    assert_equal(routes.active_route_matches_object(target), true,
        "Mountain Cave should remain selected during the connector leg")

    routes.reset_for_tests()
end

function tests.mountain_cave_from_tantegel_starts_kol_then_connector_itinerary()
    routes.reset_for_tests()

    local info, err = routes.start("mountain cave", 0x01, 43, 43)

    assert_equal(err, nil, "Mountain Cave alias should resolve from Tantegel")
    assert_equal(info.route.id, "kol_staging",
        "far Mountain Cave requests should begin on the established Kol route")
    assert_equal(info.object_id, "route_kol_staging_02",
        "the nested itinerary should leave Tantegel through the Kol route")
    assert_contains(info.message, "Mountain Cave route starts from Kol",
        "nested staging speech should retain Mountain Cave")
    assert_contains(info.log, "staged_from=mountain_cave",
        "structured logs should retain the final Mountain Cave destination")

    routes.reset_for_tests()
end

function tests.mountain_cave_staging_hands_off_at_kol_and_western_desert_pin()
    routes.reset_for_tests()
    local target = {
        id = "overworld_mountain_cave",
        name = "Mountain Cave",
        x = 29,
        y = 57,
    }
    assert(routes.start_for_object(target, 0x01, 43, 43))

    local kol_entry = assert(routes.observe_position(0x07, 19, 23))
    assert_equal(kol_entry.status, "handoff",
        "entering Kol should hand off to the western connector")
    assert_equal(routes.active_route_id(), "mountain_cave_connector",
        "Kol arrival should activate the Hauksness-prefix connector")
    assert_contains(kol_entry.message, "Continuing toward Mountain Cave",
        "the intermediate handoff should retain the final destination")
    assert_contains(kol_entry.message, "Current leg to Western desert east road",
        "the intermediate handoff should name the connector endpoint")
    assert_equal(kol_entry.steps, nil,
        "the Kol handoff must not inject movement")

    local connector = assert(routes._route_for_tests("mountain_cave_connector"))
    local event
    for index = 2, #connector.waypoints do
        local waypoint = connector.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    assert_equal(event.status, "handoff",
        "the western desert pin should hand off to the local cave spur")
    assert_equal(routes.active_route_id(), "mountain_cave",
        "the connector endpoint should activate the existing Mountain Cave route")
    assert_contains(event.message,
        "Reached Western desert east road. Continuing to Mountain Cave",
        "the final handoff should name the shared route pin and cave")
    assert_equal(event.object_id, "route_mountain_cave_02",
        "the local cave spur should begin at its first movement waypoint")
    assert_equal(event.steps, nil,
        "the local-spur handoff must wait for the next auto-walk request")
    assert_equal(routes.active_route_matches_object(target), true,
        "Mountain Cave should remain selected after the local spur activates")

    routes.reset_for_tests()
end

function tests.mountain_cave_connector_reuses_hauksness_prefix_without_mutation()
    local hauksness = assert(routes._route_for_tests("hauksness"))
    local connector = assert(routes._route_for_tests("mountain_cave_connector"))
    local shared_pin_index
    for index, waypoint in ipairs(hauksness.waypoints) do
        if waypoint.x == 18 and waypoint.y == 64 then
            shared_pin_index = index
            break
        end
    end

    assert_equal(shared_pin_index ~= nil, true,
        "Hauksness route should contain the western desert shared pin")
    assert_equal(#connector.waypoints, shared_pin_index,
        "connector should end exactly at the shared pin")
    for index = 1, shared_pin_index do
        local source = hauksness.waypoints[index]
        local derived = connector.waypoints[index]
        assert_equal(derived ~= source, true,
            "connector waypoints should be copies rather than mutable aliases")
        assert_equal(derived.x, source.x, "connector x at waypoint " .. index)
        assert_equal(derived.y, source.y, "connector y at waypoint " .. index)
        assert_equal(derived.name, source.name, "connector name at waypoint " .. index)
        assert_equal(derived.radius, source.radius, "connector radius at waypoint " .. index)
        assert_equal(derived.axis_order, source.axis_order,
            "connector axis order at waypoint " .. index)
        assert_equal(derived.warning, source.warning,
            "connector warning at waypoint " .. index)
    end
    assert_equal(connector.waypoints[#connector.waypoints].final, true,
        "connector endpoint should be final")
    assert_equal(hauksness.waypoints[shared_pin_index].final, nil,
        "deriving the connector must not mark the Hauksness midpoint final")
end

function tests.mountain_cave_guidance_refresh_and_cancel_preserve_itinerary()
    routes.reset_for_tests()
    local target = {
        id = "overworld_mountain_cave",
        name = "Mountain Cave",
        x = 29,
        y = 57,
    }
    assert(routes.start_for_object(target, 0x01, 43, 43))

    local refreshed = routes.guidance_for_object(target, 0x01, 43, 43)
    assert_equal(refreshed.route.id, "kol_staging",
        "guidance refresh should keep the first itinerary leg active")
    assert_contains(refreshed.message, "Final destination: Mountain Cave",
        "guidance refresh should retain Mountain Cave")

    routes.observe_position(0x07, 19, 23)
    refreshed = routes.guidance_for_object(target, 0x01, 104, 10)
    assert_equal(refreshed.route.id, "mountain_cave_connector",
        "guidance refresh should keep the connector active after Kol")
    assert_contains(refreshed.message, "Final destination: Mountain Cave",
        "connector guidance should retain Mountain Cave")

    routes.stop()
    assert_equal(routes.is_active(), false,
        "stopping should clear the connector leg")
    assert_equal(routes.active_route_matches_object(target), false,
        "stopping should also clear the queued Mountain Cave destination")

    routes.reset_for_tests()
end

function tests.mountain_cave_route_recovers_from_live_north_carry_position()
    routes.reset_for_tests()
    routes.start("mountain cave", 0x01, 16, 61)

    local segment = assert(routes.plan_next_segment(0x01, 16, 61))

    assert_equal(segment.waypoint.name, "Mountain Cave west forest lane", "mid-corridor start should keep the north target")
    assert_equal(#segment.steps, 3, "live carry position should be three steps south of the turn")
    assert_equal(segment.steps[1], "up", "carry recovery should continue north")
    assert_equal(segment.steps[3], "up", "carry recovery should finish the north segment")
    assert_equal(segment.route_final_carry_x, 17, "turn lookahead should allow only eastward carry")
    assert_equal(segment.route_final_carry_y, 58, "turn lookahead should stay on the target row")

    routes.reset_for_tests()
end

function tests.mountain_cave_route_uses_exact_turns_and_finishes_on_entry()
    routes.reset_for_tests()
    routes.start("mountain cave", 0x01, 18, 64)

    local forest_turn = routes.observe_position(0x01, 16, 64)
    assert_contains(forest_turn.message, "Mountain Cave forest turn", "route should reach the forest turn")
    assert_contains(forest_turn.message, "Next: Mountain Cave west forest lane", "forest turn should point north")

    routes.observe_position(0x01, 16, 58)
    routes.observe_position(0x01, 25, 58)
    routes.observe_position(0x01, 25, 57)
    local arrival = routes.observe_position(0x16, 0, 0)

    assert_contains(arrival.message, "Arrived at Mountain Cave", "map entry should complete the route")
    assert_equal(routes.is_active(), false, "Mountain Cave route should stop after entry")

    routes.reset_for_tests()
end

function tests.mountain_cave_return_reverses_to_western_desert_pin()
    routes.reset_for_tests()
    local info, err = routes.start("mountain cave return", 0x01, 29, 57)

    assert_equal(err, nil, "Mountain Cave return alias should resolve")
    assert_equal(info.route.id, "mountain_cave_return", "return alias should use the reverse spur")
    assert_equal(info.object_id, "route_mountain_cave_return_02", "return should first head west")

    local first = assert(routes.plan_next_segment(0x01, 29, 57))
    assert_equal(first.waypoint.name, "Mountain Cave west approach", "return should target the west approach")
    assert_equal(first.steps[1], "left", "return should leave the cave westbound")

    routes.observe_position(0x01, 25, 57)
    routes.observe_position(0x01, 25, 58)
    routes.observe_position(0x01, 16, 58)
    routes.observe_position(0x01, 16, 64)
    local arrival = routes.observe_position(0x01, 18, 64)

    assert_contains(arrival.message, "Arrived at Western desert east road", "return should finish at the existing route pin")
    assert_equal(routes.is_active(), false, "return route should stop at the route pin")

    routes.reset_for_tests()
end

function tests.mountain_cave_return_keeps_physical_cave_selection_bound_to_active_route()
    routes.reset_for_tests()
    routes.start("mountain cave return", 0x01, 29, 57)

    local cave = {
        id = "overworld_mountain_cave",
        name = "Mountain Cave",
        x = 29,
        y = 57,
    }

    assert_equal(
        routes.active_route_matches_object(cave),
        true,
        "route-manager matching should keep the physical cave bound to the active return route")

    local info, err = routes.guidance_for_object(cave, 0x01, 29, 57)

    assert_equal(err, nil, "physical Mountain Cave selection should remain valid during the active return route")
    assert_equal(routes.active_route_id(), "mountain_cave_return", "physical cave selection must not replace the active return route")
    assert_equal(info.route.id, "mountain_cave_return", "guidance should continue using the return route")
    assert_equal(info.object_id, "route_mountain_cave_return_02", "return guidance should keep the west-approach waypoint selected")

    routes.reset_for_tests()
end

function tests.rainbow_bridge_route_uses_bounded_westbound_segments()
    routes.reset_for_tests()

    local info, err = routes.start("rainbow bridge", 0x01, 104, 49)

    assert_equal(err, nil, "Rainbow Bridge route alias should resolve")
    assert_equal(info.route.id, "rainbow_bridge", "route should target the Rainbow Bridge unlock stand")
    assert_equal(info.object_id, "route_rainbow_bridge_02", "route should reuse the proven row-49 waypoint first")
    assert_equal(
        routes.active_route_matches_object({
            id = "overworld_swamp_cave_south_entrance",
            name = "Swamp Cave South Entrance",
            x = 104,
            y = 49,
        }),
        true,
        "physical cave selection should not replace the manually started bridge route")

    local first = assert(routes.plan_next_segment(0x01, 104, 49))
    assert_equal(first.waypoint.x, 93, "first segment should reuse the validated westbound corridor")
    assert_equal(first.waypoint.y, 49, "first segment should stay on row 49")
    assert_equal(#first.steps, 11, "first segment should remain bounded to eleven steps")
    assert_equal(first.steps[1], "left", "first segment should move west")
    assert_equal(first.steps[11], "left", "first segment should remain straight west")

    routes.observe_position(0x01, 93, 49)
    routes.observe_position(0x01, 83, 49)
    routes.observe_position(0x01, 73, 49)
    local shore_turn = assert(routes.plan_next_segment(0x01, 73, 49))
    assert_equal(shore_turn.waypoint.x, 70, "route should stop before the two-tile water inlet")
    assert_equal(shore_turn.waypoint.y, 49, "shore turn should remain on the north road")

    routes.observe_position(0x01, 70, 49)
    local south = assert(routes.plan_next_segment(0x01, 70, 49))
    assert_equal(south.waypoint.x, 70, "inlet detour should begin from the live-proven shore column")
    assert_equal(south.waypoint.y, 50, "inlet detour should step one tile south")
    assert_equal(south.steps[1], "down", "inlet detour should turn south before the water")

    routes.observe_position(0x01, 70, 50)
    local crossing = assert(routes.plan_next_segment(0x01, 70, 50))
    assert_equal(crossing.waypoint.x, 67, "row-50 crossing should end at the peninsula")
    assert_equal(crossing.waypoint.y, 50, "row-50 crossing should avoid the water on row 49")
    assert_equal(#crossing.steps, 3, "row-50 crossing should be three west steps")

    routes.observe_position(0x01, 67, 50)
    routes.observe_position(0x01, 67, 49)
    local arrival = routes.observe_position(0x01, 65, 49)

    assert_contains(arrival.message, "Arrived at Rainbow Bridge unlock point", "route should finish on the Rainbow Drop use stand")
    assert_equal(routes.is_active(), false, "Rainbow Bridge route should stop at the unlock stand")

    routes.reset_for_tests()
end

function tests.rainbow_bridge_return_reverses_to_swamp_cave_south_entrance()
    routes.reset_for_tests()

    local info, err = routes.start("rainbow bridge return", 0x01, 65, 49)

    assert_equal(err, nil, "Rainbow Bridge return alias should resolve")
    assert_equal(info.route.id, "rainbow_bridge_return", "return alias should use the eastbound route")
    assert_equal(info.object_id, "route_rainbow_bridge_return_02", "return should first target the nearest east-road waypoint")
    assert_equal(
        routes.active_route_matches_object({
            id = "overworld_rainbow_bridge",
            name = "Rainbow Bridge unlock point",
            x = 65,
            y = 49,
        }),
        true,
        "physical bridge selection should not replace the manually started return route")

    local first = assert(routes.plan_next_segment(0x01, 65, 49))
    assert_equal(first.waypoint.x, 67, "return should first reach the peninsula turn")
    assert_equal(first.waypoint.y, 50, "return should cross the stateful corner without stopping on row 49")
    assert_equal(#first.steps, 3, "return first segment should make the east-then-south turn continuously")
    assert_equal(first.steps[1], "right", "return should move east")
    assert_equal(first.steps[3], "down", "return should turn south without settling at (67,49)")
    assert_equal(first.waypoint.route_hold_after_movement_start_frames, 60,
        "return inlet should sustain the slow formed-bridge departure")
    assert_equal(first.waypoint.route_early_twitch_timeout_frames, 60,
        "return inlet should allow the observed late eastbound tile completion")
    assert_equal(first.waypoint.route_reset_movement_on_turn_settle, false,
        "return inlet should preserve movement state across the south turn")

    routes.observe_position(0x01, 67, 50)
    routes.observe_position(0x01, 70, 50)
    routes.observe_position(0x01, 70, 49)
    routes.observe_position(0x01, 73, 49)
    routes.observe_position(0x01, 83, 49)
    routes.observe_position(0x01, 93, 49)
    local arrival = routes.observe_position(0x15, 0, 29)

    assert_contains(arrival.message, "Arrived at Swamp Cave South Entrance", "return should finish when the cave entrance changes maps")
    assert_equal(routes.is_active(), false, "Rainbow Bridge return should stop after entering Swamp Cave")

    routes.reset_for_tests()
end

function tests.charlock_route_continues_across_bridge_to_live_castle_entry()
    routes.reset_for_tests()

    local info, err = routes.start("charlock", 0x01, 103, 49)

    assert_equal(err, nil, "Charlock route alias should resolve")
    assert_equal(info.route.id, "charlock_castle", "route should target Charlock Castle")
    assert_equal(info.object_id, "route_charlock_castle_02", "cave-exit start should head west instead of re-entering the cave")

    local first = assert(routes.plan_next_segment(0x01, 103, 49))
    assert_equal(first.waypoint.x, 93, "first Charlock segment should use the Rainbow Bridge east road")
    assert_equal(first.waypoint.y, 49, "first Charlock segment should stay on row 49")
    assert_equal(#first.steps, 10, "cave-exit segment should be ten west steps")
    assert_equal(first.steps[1], "left", "Charlock route should leave the cave area westbound")

    local route = routes._route_for_tests("charlock_castle")
    local expected_island = {
        {63, 49}, {61, 49}, {58, 50}, {58, 55},
        {57, 55}, {57, 56}, {56, 56}, {56, 64}, {51, 64},
        {52, 64}, {52, 63}, {50, 63}, {50, 61}, {49, 61}, {49, 57},
        {51, 57}, {51, 49}, {48, 49}, {48, 48},
    }
    for index, coordinate in ipairs(expected_island) do
        local waypoint = route.waypoints[index + 9]
        assert_equal(waypoint.x, coordinate[1], "Charlock island waypoint " .. index .. " x")
        assert_equal(waypoint.y, coordinate[2], "Charlock island waypoint " .. index .. " y")
        assert_equal(waypoint.radius, 0, "Charlock island waypoint " .. index .. " should be strict")
        if (coordinate[1] == 57 and coordinate[2] == 55)
                or (coordinate[1] == 49 and coordinate[2] == 61) then
            assert_equal(waypoint.route_hold_after_movement_start_frames, 60,
                "Charlock slow-entry waypoint " .. index .. " should sustain the outbound press")
            assert_equal(waypoint.route_early_twitch_timeout_frames, 60,
                "Charlock slow-entry waypoint " .. index .. " should retain the late-completion window")
        end
    end

    routes.observe_position(0x01, 93, 49)
    routes.observe_position(0x01, 83, 49)
    routes.observe_position(0x01, 73, 49)
    routes.observe_position(0x01, 70, 49)
    routes.observe_position(0x01, 70, 50)
    routes.observe_position(0x01, 67, 50)
    routes.observe_position(0x01, 67, 49)
    routes.observe_position(0x01, 65, 49)
    local crossing = assert(routes.plan_next_segment(0x01, 65, 49))
    assert_equal(crossing.waypoint.x, 63, "Charlock route should cross to the island landing")
    assert_equal(#crossing.steps, 2, "Rainbow Bridge crossing should be two west steps")
    assert_equal(crossing.steps[1], "left", "Rainbow Bridge crossing should move west")

    routes.observe_position(0x01, 63, 49)
    routes.observe_position(0x01, 61, 49)
    local inbound_turn = assert(routes.plan_next_segment(0x01, 61, 49))
    assert_equal(inbound_turn.waypoint.x, 58, "inbound northeast turn should finish west of the stateful seam")
    assert_equal(inbound_turn.waypoint.y, 50, "inbound northeast turn should descend before moving west")
    assert_equal(#inbound_turn.steps, 4, "inbound northeast turn should stay continuous")
    assert_equal(inbound_turn.steps[1], "down", "inbound northeast turn should descend first")
    assert_equal(inbound_turn.steps[4], "left", "inbound northeast turn should finish westbound")

    for _, coordinate in ipairs(expected_island) do
        if coordinate[1] ~= 48 or coordinate[2] ~= 48 then
            routes.observe_position(0x01, coordinate[1], coordinate[2])
        end
    end
    local arrival = routes.observe_position(0x02, 10, 19)

    assert_contains(arrival.message, "Arrived at Charlock Castle", "entering map 0x02 should complete the route")
    assert_equal(routes.is_active(), false, "Charlock route should stop after entering the castle")

    routes.reset_for_tests()
end

function tests.final_progression_routes_stage_through_swamp_cave_south()
    local targets = {
        {
            id = "overworld_rainbow_bridge",
            name = "Rainbow Bridge unlock point",
            x = 65,
            y = 49,
            route_name = "rainbow bridge",
            staged_id = "rainbow_bridge",
            direct_x = 104,
            direct_y = 49,
        },
        {
            id = "overworld_charlock_castle",
            name = "Charlock Castle",
            x = 48,
            y = 48,
            route_name = "charlock",
            staged_id = "charlock_castle",
            direct_x = 103,
            direct_y = 49,
        },
    }
    local staging_route = assert(routes._route_for_tests("swamp_cave_south"))

    for _, target in ipairs(targets) do
        routes.reset_for_tests()
        local info = assert(routes.start_for_object(target, 0x01, 102, 72))
        assert_equal(info.route.id, "swamp_cave_south",
            target.name .. " should begin on the south-cave staging route")
        assert_equal(info.object_id, "route_swamp_cave_south_02",
            target.name .. " staging should leave Rimuldar through the proven east doorstep")
        assert_contains(info.message,
            target.name .. " route starts from Swamp Cave South Entrance",
            target.name .. " staging should explain the required intermediate route")
        assert_contains(info.log, "staged_from=" .. target.staged_id,
            target.name .. " staged start should be visible in logs")
        assert_equal(routes.active_route_matches_object(target), true,
            target.name .. " should remain bound to its active staging route")

        local initial_segment = assert(routes.plan_next_segment(0x01, 102, 72))
        assert_equal(initial_segment.waypoint.x, 103,
            target.name .. " staging should target Rimuldar's east doorstep x")
        assert_equal(initial_segment.waypoint.y, 72,
            target.name .. " staging should target Rimuldar's east doorstep y")
        assert_equal(#initial_segment.steps, 1,
            target.name .. " staging should queue only the proven first step")
        assert_equal(initial_segment.steps[1], "right",
            target.name .. " staging should leave Rimuldar east")

        for index = 2, #staging_route.waypoints do
            local waypoint = staging_route.waypoints[index]
            routes.observe_position(0x01, waypoint.x, waypoint.y)
            if waypoint.x == 83 and waypoint.y == 54 then
                break
            end
        end

        assert_equal(routes.active_route_matches_object(target), true,
            target.name .. " should not restart its direct route inside the west-pocket detour")
        assert_equal(routes.active_route_id(), "swamp_cave_south",
            target.name .. " should keep the south-cave route active through the detour")

        local segment = assert(routes.plan_next_segment(0x01, 83, 54))
        assert_equal(segment.waypoint.x, 86,
            target.name .. " should continue east on the proven west-ridge route")
        assert_equal(segment.waypoint.y, 54,
            target.name .. " should stay on the proven west-ridge row")
        assert_equal(segment.steps[1], "right",
            target.name .. " should not synthesize a northbound shortcut to row 49")

        routes.reset_for_tests()
        local restarted = assert(routes.start_for_object(target, 0x01, 83, 54))
        assert_equal(restarted.route.id, "swamp_cave_south",
            target.name .. " should restage when restarted outside its validated corridor")
        local restarted_segment = assert(routes.plan_next_segment(0x01, 83, 54))
        assert_equal(restarted_segment.waypoint.x, 86,
            target.name .. " restart should rejoin the proven west-ridge route")
        assert_equal(restarted_segment.waypoint.y, 54,
            target.name .. " restart should remain on the proven west-ridge row")
        assert_equal(restarted_segment.steps[1], "right",
            target.name .. " restart should not head north through craggy terrain")

        routes.reset_for_tests()
        local recovery = assert(routes.start_for_object(target, 0x01, 92, 57))
        assert_equal(recovery.route.id, "swamp_cave_south_recovery",
            target.name .. " should use the established recovery route at the blocked notch")
        assert_equal(routes.active_route_matches_object(target), true,
            target.name .. " should remain bound to the active notch-recovery route")
        local recovery_segment = assert(routes.plan_next_segment(0x01, 92, 57))
        assert_equal(recovery_segment.waypoint.x, 90,
            target.name .. " recovery should target the safe west lane")
        assert_equal(recovery_segment.waypoint.y, 57,
            target.name .. " recovery should stay south of the blocked notch")
        assert_equal(recovery_segment.steps[1], "left",
            target.name .. " recovery should not retry the engine-blocked north edge")

        routes.reset_for_tests()
        local upper_ridge = assert(routes.start_for_object(target, 0x01, 92, 48))
        assert_equal(upper_ridge.route.id, "swamp_cave_south",
            target.name .. " should retain the established cave approach from the upper ridge")
        local upper_ridge_segment = assert(routes.plan_next_segment(0x01, 92, 48))
        assert_equal(upper_ridge_segment.waypoint.x, 100,
            target.name .. " upper-ridge staging should target the proven east end")
        assert_equal(upper_ridge_segment.waypoint.y, 48,
            target.name .. " upper-ridge staging should remain on row 48")
        assert_equal(upper_ridge_segment.steps[1], "right",
            target.name .. " upper-ridge staging should not cut down to an unvalidated row")

        local refreshed = assert(routes.guidance_for_object(target, 0x01, 92, 48))
        assert_equal(refreshed.route.id, "swamp_cave_south",
            target.name .. " guidance refresh should preserve the active staging route")
        local refreshed_segment = assert(routes.plan_next_segment(0x01, 92, 48))
        assert_equal(refreshed_segment.waypoint.x, 100,
            target.name .. " refreshed staging should retain the proven upper-ridge target")
        assert_equal(refreshed_segment.steps[1], "right",
            target.name .. " refreshed staging should not switch to a nearby reverse route")

        routes.reset_for_tests()
        assert(routes.start(target.route_name, 0x01, target.direct_x, target.direct_y))
        local recalculated = assert(routes.recalculate(0x01, 102, 72))
        assert_equal(recalculated.route.id, "swamp_cave_south",
            target.name .. " should restage if an active route returns to Rimuldar")
        local recalculated_segment = assert(routes.plan_next_segment(0x01, 102, 72))
        assert_equal(recalculated_segment.waypoint.x, 103,
            target.name .. " recalculation should target Rimuldar's east doorstep")
        assert_equal(recalculated_segment.steps[1], "right",
            target.name .. " recalculation should avoid the old northbound shortcut")
    end

    routes.reset_for_tests()
end

function tests.charlock_return_reverses_island_route_to_swamp_cave()
    routes.reset_for_tests()

    local info, err = routes.start("return from charlock", 0x01, 48, 48)

    assert_equal(err, nil, "Charlock return alias should resolve")
    assert_equal(info.route.id, "charlock_return", "return alias should use the eastbound route")
    assert_equal(info.object_id, "route_charlock_return_02", "castle exit should first step to the south approach")

    local outbound = routes._route_for_tests("charlock_castle")
    local inbound = routes._route_for_tests("charlock_return")
    for outbound_index = 10, #outbound.waypoints do
        local return_index = #outbound.waypoints - outbound_index + 1
        local outbound_point = outbound.waypoints[outbound_index]
        local return_point = inbound.waypoints[return_index]
        assert_equal(return_point.x, outbound_point.x, "Charlock return island waypoint x should reverse outbound")
        assert_equal(return_point.y, outbound_point.y, "Charlock return island waypoint y should reverse outbound")
    end

    local first = assert(routes.plan_next_segment(0x01, 48, 48))
    assert_equal(first.waypoint.x, 48, "Charlock return should leave the castle on column 48")
    assert_equal(first.waypoint.y, 49, "Charlock return should step south from the castle tile")
    assert_equal(first.steps[1], "down", "Charlock return should initially move south")

    routes.reset_for_tests()
    routes.start("return from charlock", 0x01, 58, 50)
    assert_equal(
        routes.active_route_matches_object({
            id = "overworld_rainbow_bridge",
            name = "Rainbow Bridge unlock point",
            x = 65,
            y = 49,
        }),
        true,
        "nearby Rainbow Bridge selection should not replace the active Charlock return")
    local northeast_turn = assert(routes.plan_next_segment(0x01, 58, 50))
    assert_equal(northeast_turn.waypoint.x, 61, "return should target the northeast shore without stopping in the trap")
    assert_equal(northeast_turn.waypoint.y, 49, "return should finish north of the stateful seam")
    assert_equal(#northeast_turn.steps, 4, "return northeast turn should stay in one segment")
    assert_equal(northeast_turn.steps[1], "right", "return northeast turn should move east first")
    assert_equal(northeast_turn.steps[4], "up", "return northeast turn should turn north without settling at (61,50)")

    routes.observe_position(0x01, 61, 49)
    routes.observe_position(0x01, 63, 49)
    routes.observe_position(0x01, 65, 49)
    local inlet_turn = assert(routes.plan_next_segment(0x01, 65, 49))
    assert_equal(inlet_turn.waypoint.x, 67, "return inlet turn should finish on column 67")
    assert_equal(inlet_turn.waypoint.y, 50, "return inlet turn should finish south of the stateful seam")
    assert_equal(#inlet_turn.steps, 3, "return inlet turn should stay in one segment")
    assert_equal(inlet_turn.steps[1], "right", "return inlet turn should move east first")
    assert_equal(inlet_turn.steps[3], "down", "return inlet turn should turn south without settling at (67,49)")
    assert_equal(inlet_turn.waypoint.route_hold_after_movement_start_frames, 60,
        "Charlock return should sustain the slow formed-bridge departure")
    assert_equal(inlet_turn.waypoint.route_early_twitch_timeout_frames, 60,
        "Charlock return should allow the observed late eastbound tile completion")
    assert_equal(inlet_turn.waypoint.route_reset_movement_on_turn_settle, false,
        "Charlock return should preserve movement state across the south turn")

    local arrival = routes.observe_position(0x15, 0, 29)
    assert_contains(arrival.message, "Arrived at Swamp Cave South Entrance", "entering the cave should complete the Charlock return")
    assert_equal(routes.is_active(), false, "Charlock return should stop after entering the cave")

    routes.reset_for_tests()
end

function tests.swamp_cave_south_object_selects_charlock_return_near_castle()
    routes.reset_for_tests()

    local south = {
        id = "overworld_swamp_cave_south_entrance",
        name = "Swamp Cave South Entrance",
        x = 104,
        y = 49,
    }

    local route_id = routes.route_id_for_object(south, 0x01, 48, 48, 0x00)
    assert_equal(route_id, "charlock_return", "castle-side cave selection should choose the full island return")

    routes.reset_for_tests()
end

function tests.swamp_cave_south_object_selects_rainbow_bridge_return_only_near_bridge()
    routes.reset_for_tests()

    local south = {
        id = "overworld_swamp_cave_south_entrance",
        name = "Swamp Cave South Entrance",
        x = 104,
        y = 49,
    }

    local near_bridge = routes.route_id_for_object(south, 0x01, 65, 49, 0x00)
    assert_equal(near_bridge, "rainbow_bridge_return", "bridge-side selection should choose the direct eastbound return")

    local at_rimuldar = routes.route_id_for_object(south, 0x01, 102, 72, 0x00)
    assert_equal(at_rimuldar, "swamp_cave_south", "Rimuldar selection should keep the established cave return")

    routes.reset_for_tests()
end

function tests.northern_cave_route_steps_through_rain_shrine_approach()
    routes.reset_for_tests()
    routes.start("rain shrine", 0x01, 104, 10)

    local forest = routes.observe_position(0x01, 96, 13)
    assert_contains(forest.message, "Reached Kol forest west edge", "route should advance at the known west edge")
    assert_contains(forest.message, "Next: West of Kol forest bend", "west edge should point toward the northern shrine trail")

    local bend = routes.observe_position(0x01, 92, 10)
    assert_contains(bend.message, "Reached West of Kol forest bend", "route should use an intermediate bend west of Kol")
    assert_contains(bend.message, "Next: Rain shrine east-shore detour", "bend should route south around the bay")

    routes.observe_position(0x01, 92, 17)
    routes.observe_position(0x01, 90, 17)
    routes.observe_position(0x01, 90, 18)
    routes.observe_position(0x01, 89, 18)
    routes.observe_position(0x01, 89, 19)
    routes.observe_position(0x01, 83, 19)
    routes.observe_position(0x01, 83, 18)
    routes.observe_position(0x01, 82, 18)
    routes.observe_position(0x01, 82, 17)
    routes.observe_position(0x01, 80, 17)
    routes.observe_position(0x01, 80, 16)
    routes.observe_position(0x01, 79, 16)
    routes.observe_position(0x01, 79, 15)
    routes.observe_position(0x01, 76, 15)
    routes.observe_position(0x01, 76, 14)
    routes.observe_position(0x01, 75, 14)
    routes.observe_position(0x01, 75, 5)
    routes.observe_position(0x01, 76, 5)
    routes.observe_position(0x01, 76, 4)
    routes.observe_position(0x01, 77, 4)
    routes.observe_position(0x01, 77, 3)
    local island = routes.observe_position(0x01, 78, 3)
    assert_contains(island.message, "Reached Rain shrine island approach", "route should reach the shrine-side landmass")
    assert_contains(island.message, "Next: Rain shrine entrance approach", "island approach should stage near the entrance")

    local approach = routes.observe_position(0x01, 80, 1)
    assert_contains(approach.message, "Reached Rain shrine entrance approach", "route should stage near the shrine entrance")
    assert_contains(approach.message, "Next: Northern Cave", "last approach should point to the cave")

    local arrival = routes.observe_position(0x01, 81, 1)
    assert_contains(arrival.message, "Arrived at Northern Cave", "final waypoint should complete the route")
    assert_equal(routes.is_active(), false, "route should stop after reaching the cave")

    routes.reset_for_tests()
end

function tests.kol_route_from_rain_shrine_uses_shrine_return_variant()
    routes.reset_for_tests()

    local info, err = routes.start("kol", 0x01, 81, 1)

    assert_equal(err, nil, "Kol alias should resolve outside the Rain Shrine")
    assert_equal(info.route.id, "kol_rain_shrine", "route should use the Rain Shrine return variant")
    assert_equal(info.object_id, "route_kol_rain_shrine_02", "route should not skip to the south Kol chain")
    assert_contains(info.message, "Rain shrine entrance approach", "route should begin by backing out of the shrine approach")

    local segment = assert(routes.plan_next_segment(0x01, 81, 1))
    assert_equal(segment.waypoint.name, "Rain shrine entrance approach", "first segment should target the shrine entrance approach")
    assert_equal(segment.steps[1], "left", "first step from the shrine should move west, not far south")

    routes.reset_for_tests()
end

function tests.kol_object_from_rain_shrine_uses_shrine_return_variant()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_kol",
        name = "Kol",
        x = 104,
        y = 10,
    }, 0x01, 81, 2)

    assert_equal(err, nil, "Kol Travel object should start from the Rain Shrine")
    assert_equal(info.route.id, "kol_rain_shrine", "Kol object should choose the shrine return route")
    assert_equal(info.object_id, "route_kol_rain_shrine_02", "exit-adjacent shrine starts should target the local return waypoint")

    routes.reset_for_tests()
end

function tests.kol_recalculate_switches_to_rain_shrine_variant_after_drift()
    routes.reset_for_tests()

    routes.start("kol", 0x01, 74, 7)
    local info = routes.recalculate(0x01, 90, 20)

    assert_equal(info.route.id, "kol_rain_shrine", "legacy active Kol route should switch to shrine return variant")
    assert_contains(info.message, "Rain shrine", "recalculated route should use the local shrine approach chain")
    assert_equal(info.waypoint.name ~= "North Alefgard bridge road", true, "recalculation should not keep the far south bridge road")

    routes.reset_for_tests()
end

function tests.northern_cave_live_snag_routes_around_east_shore()
    routes.reset_for_tests()

    local info, err = routes.start("rain shrine", 0x01, 91, 5)

    assert_equal(err, nil, "route should recalculate from the live snag position")
    assert_equal(info.route.id, "northern_cave", "live east-shore pocket should keep the Northern Cave route")
    assert_equal(info.object_id, "route_northern_cave_03", "live east-shore pocket should recover toward the forest bend")
    assert_contains(info.message, "West of Kol forest bend", "route should not target the old water-gap approach")

    local segment = assert(routes.plan_next_segment(0x01, 91, 5))
    assert_equal(segment.waypoint.name, "West of Kol forest bend", "live snag should back out to the detour route")
    assert_equal(segment.steps[1], "down", "live snag recovery should head south, not west into the mountain/water gap")

    routes.reset_for_tests()
end

function tests.swamp_cave_object_starts_route_from_kol()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_swamp_cave",
        name = "Swamp Cave",
        x = 104,
        y = 44,
    }, 0x01, 104, 10)

    assert_equal(err, nil, "Swamp Cave Travel object should start a route")
    assert_equal(info.route.id, "swamp_cave", "Kol starts should use the Kol-side route")
    assert_equal(info.object_id, "route_swamp_cave_02", "route should leave Kol toward the west forest edge")
    assert_contains(info.message, "Route to Swamp Cave", "started route should name Swamp Cave")
    assert_contains(info.message, "Kol forest west edge", "route should begin with the known west edge from Kol")

    local segment = assert(routes.plan_next_segment(0x01, 104, 10))
    assert_equal(segment.waypoint.name, "Kol forest west edge", "first segment should target the west forest edge")
    assert_equal(segment.steps[1], "left", "first step from Kol should move west, not south into an untested lane")

    routes.reset_for_tests()
end

function tests.swamp_cave_bridge_start_uses_bridge_variant()
    routes.reset_for_tests()

    local info, err = routes.start("swamp cave", 0x01, 90, 37)

    assert_equal(err, nil, "Swamp Cave alias should resolve from the southwest bridge")
    assert_equal(info.route.id, "swamp_cave_bridge", "bridge starts should use the local bridge variant")
    assert_equal(info.object_id, "route_swamp_cave_bridge_02", "bridge start should advance to the east lane")
    assert_contains(info.message, "Kol bridge east lane", "bridge variant should reuse the proven Kol south-road jog")

    local segment = assert(routes.plan_next_segment(0x01, 90, 37))
    assert_equal(segment.waypoint.name, "Kol bridge east lane", "bridge segment should target the east lane")
    assert_equal(segment.steps[1], "right", "bridge segment should move east instead of pulling north at x=90")

    routes.reset_for_tests()
end

function tests.swamp_cave_from_tantegel_starts_kol_staging_route()
    routes.reset_for_tests()

    local info, err = routes.start("quagmire cave", 0x01, 43, 43)

    assert_equal(err, nil, "Swamp Cave alias should resolve from Tantegel")
    assert_equal(info.route.id, "kol_staging", "far Swamp Cave requests should stage outside Kol")
    assert_equal(info.object_id, "route_kol_staging_02", "staging route should leave Tantegel on the safe Kol route")
    assert_contains(info.message, "Swamp Cave route starts from Kol", "staging should explain the required hub")
    assert_contains(info.message, "Starting route to Kol first", "staging should say which route actually started")
    assert_contains(info.message, "Route to Kol", "staging should include normal route guidance")
    assert_contains(info.log, "staged_from=swamp_cave", "staged starts should be visible in logs")

    routes.reset_for_tests()
end

function tests.swamp_cave_object_from_tantegel_retains_final_destination()
    routes.reset_for_tests()

    local target = {
        id = "overworld_swamp_cave",
        name = "Swamp Cave",
        x = 104,
        y = 44,
    }
    local info, err = routes.start_for_object(target, 0x01, 43, 43)

    assert_equal(err, nil, "Swamp Cave Travel object should resolve from Tantegel")
    assert_equal(info.route.id, "kol_staging", "Travel-object starts should use the safe Kol staging route")
    assert_equal(info.object_id, "route_kol_staging_02", "Travel-object staging should leave Tantegel on the non-entry route")
    assert_equal(routes.active_route_matches_object(target), true,
        "the selected Swamp Cave object should remain bound during the Kol leg")

    routes.reset_for_tests()
end

function tests.swamp_cave_staging_status_names_current_leg_and_final_destination()
    routes.reset_for_tests()
    routes.start("swamp cave", 0x01, 43, 43)

    local info = routes.status(0x01, 43, 43)

    assert_contains(info.message, "Current leg to Kol",
        "Swamp Cave staging status should identify the route currently being followed")
    assert_contains(info.message, "Final destination: Swamp Cave",
        "Swamp Cave staging status should retain the player's requested destination")

    routes.reset_for_tests()
end

function tests.swamp_cave_staging_hands_off_at_kol_without_starting_movement()
    routes.reset_for_tests()
    routes.start("swamp cave", 0x01, 43, 43)
    local kol = assert(routes._route_for_tests("kol_staging"))
    local event

    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    assert_equal(routes.active_route_id(), "swamp_cave",
        "reaching Kol should activate the requested Swamp Cave leg")
    assert_equal(event.status, "handoff",
        "the Swamp Cave itinerary should distinguish a leg handoff from final arrival")
    assert_contains(event.message, "Reached Kol west doorstep. Continuing to Swamp Cave.",
        "handoff speech should name the completed hub and final destination")
    assert_contains(event.message, "Next: Kol forest west edge",
        "handoff speech should identify the first Swamp Cave waypoint")
    assert_contains(event.log, "event=handoff",
        "Swamp Cave handoff should be explicit in structured logs")
    assert_contains(event.log, "from_route=kol_staging",
        "Swamp Cave handoff logs should identify the completed leg")
    assert_equal(event.object_id, "route_swamp_cave_02",
        "route markers should refresh to the first Swamp Cave movement waypoint")
    assert_equal(event.steps, nil,
        "Swamp Cave handoff must wait for another player auto-walk command")

    local segment = assert(routes.plan_next_segment(0x01, 103, 10))
    assert_equal(segment.waypoint.name, "Kol forest west edge",
        "the next player-triggered segment should leave Kol toward Swamp Cave")
    assert_equal(segment.steps[1], "left",
        "the second leg should use the live-validated westbound Kol exit")

    routes.reset_for_tests()
end

function tests.swamp_cave_route_uses_lower_bridge_swamp_approach()
    routes.reset_for_tests()
    routes.start("swamp", 0x01, 104, 10)

    routes.observe_position(0x01, 96, 13)
    routes.observe_position(0x01, 96, 21)
    local detour = assert(routes.plan_next_segment(0x01, 96, 26))
    assert_equal(detour.waypoint.name, "Kol south road east detour", "southbound route should avoid the blocked x96 lower seam")
    assert_equal(detour.steps[1], "right", "southbound route should step east from the blocked x96 seam")
    routes.observe_position(0x01, 98, 26)
    routes.observe_position(0x01, 98, 32)
    routes.observe_position(0x01, 96, 32)
    local south_road = routes.observe_position(0x01, 96, 35)

    assert_contains(south_road.message, "Reached Kol south road east lane", "route should reuse the proven Kol south-road lane")
    assert_contains(south_road.message, "Next: Kol south road lower bend", "south-road lane should back toward the bridge jog")

    local spur = assert(routes.plan_next_segment(0x01, 96, 35))
    assert_equal(spur.waypoint.name, "Kol south road lower bend", "new spur should start by backing out through the bridge jog")
    assert_equal(spur.steps[1], "left", "cave spur should not head east into the dead north pocket")

    routes.observe_position(0x01, 93, 35)
    routes.observe_position(0x01, 93, 36)
    routes.observe_position(0x01, 92, 36)
    local bridge_lane = routes.observe_position(0x01, 92, 37)
    assert_contains(bridge_lane.message, "Reached Kol bridge east lane", "route should reuse the bridge-side lane before the swamp")
    assert_contains(bridge_lane.message, "Next: Swamp Cave lower west approach", "bridge lane should descend to the lower swamp approach")

    local lower_approach_segment = assert(routes.plan_next_segment(0x01, 92, 37))
    assert_equal(lower_approach_segment.waypoint.name, "Swamp Cave lower west approach", "bridge lane should target the x94 approach")
    assert_equal(lower_approach_segment.steps[#lower_approach_segment.steps], "right", "route should cross east at y=40 before dropping onto row 41")

    local lower_approach = routes.observe_position(0x01, 94, 40)
    assert_contains(lower_approach.message, "Poison swamp ahead", "route should warn before the poison swamp steps")
    assert_contains(lower_approach.message, "Next: Swamp Cave lower swamp drop", "lower approach should use the x94 drop instead of the blocked x92 seam")

    routes.observe_position(0x01, 94, 41)
    routes.observe_position(0x01, 97, 41)
    routes.observe_position(0x01, 97, 42)
    routes.observe_position(0x01, 102, 42)
    routes.observe_position(0x01, 102, 43)
    routes.observe_position(0x01, 104, 43)
    local arrival = routes.observe_position(0x01, 104, 44)
    assert_contains(arrival.message, "Arrived at Swamp Cave", "final waypoint should complete the route")
    assert_equal(routes.is_active(), false, "route should stop after reaching the cave")

    routes.reset_for_tests()
end

function tests.kol_route_from_swamp_cave_uses_swamp_return_variant()
    routes.reset_for_tests()

    local info, err = routes.start("kol", 0x01, 104, 44)

    assert_equal(err, nil, "Kol alias should resolve outside Swamp Cave")
    assert_equal(info.route.id, "kol_swamp_cave", "route should use the Swamp Cave return variant")
    assert_equal(info.object_id, "route_kol_swamp_cave_02", "cave start should back out from the doorstep")
    assert_contains(info.message, "Swamp Cave doorstep", "return route should begin at the cave doorstep")

    local segment = assert(routes.plan_next_segment(0x01, 104, 44))
    assert_equal(segment.waypoint.name, "Swamp Cave doorstep", "first return segment should target the doorstep")
    assert_equal(segment.steps[1], "up", "first return step should leave the cave trigger row")

    routes.reset_for_tests()
end

function tests.kol_object_from_swamp_cave_uses_swamp_return_variant()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_kol",
        name = "Kol",
        x = 104,
        y = 10,
    }, 0x01, 104, 43)

    assert_equal(err, nil, "Kol Travel object should start from Swamp Cave")
    assert_equal(info.route.id, "kol_swamp_cave", "Kol object should choose the cave return route")
    assert_equal(info.object_id, "route_kol_swamp_cave_03", "doorstep starts should advance to the entrance row")

    routes.reset_for_tests()
end

function tests.kol_swamp_cave_return_uses_x94_drop_and_bridge_jog()
    routes.reset_for_tests()
    routes.start("swamp cave to kol", 0x01, 104, 44)

    local doorstep = routes.observe_position(0x01, 104, 43)
    assert_contains(doorstep.message, "Poison swamp return to Kol", "return route should warn before poison swamp")
    assert_contains(doorstep.message, "Next: Swamp Cave entrance row", "return route should continue along the entrance row")

    routes.observe_position(0x01, 102, 43)
    routes.observe_position(0x01, 102, 42)
    routes.observe_position(0x01, 97, 42)
    routes.observe_position(0x01, 97, 41)
    routes.observe_position(0x01, 94, 41)
    local lower_approach = routes.observe_position(0x01, 94, 40)
    assert_contains(lower_approach.message, "Reached Swamp Cave lower west approach", "return route should use the x94 row-40 tile")
    assert_contains(lower_approach.message, "Next: Kol bridge east lane", "x94 approach should route back to the bridge lane")

    local bridge_segment = assert(routes.plan_next_segment(0x01, 94, 40))
    assert_equal(bridge_segment.waypoint.name, "Kol bridge east lane", "route should target the bridge lane after the x94 approach")
    assert_equal(bridge_segment.steps[1], "left", "route should cross west at y=40 before going north")
    assert_equal(bridge_segment.steps[#bridge_segment.steps], "up", "route should finish by climbing to the bridge lane")

    routes.observe_position(0x01, 92, 37)
    routes.observe_position(0x01, 92, 36)
    routes.observe_position(0x01, 93, 36)
    routes.observe_position(0x01, 93, 35)
    routes.observe_position(0x01, 96, 35)
    routes.observe_position(0x01, 96, 32)
    local east_detour = assert(routes.plan_next_segment(0x01, 96, 32))
    assert_equal(east_detour.waypoint.name, "Kol south road lower east lane",
        "Swamp Cave return should leave x96 before the blocked north edge")
    assert_equal(east_detour.steps[1], "right",
        "Swamp Cave return should start the proven x98 detour eastbound")

    routes.observe_position(0x01, 98, 32)
    local north_detour = assert(routes.plan_next_segment(0x01, 98, 32))
    assert_equal(north_detour.waypoint.name, "Kol south road east detour",
        "Swamp Cave return should climb the proven x98 lane")
    assert_equal(north_detour.steps[1], "up",
        "Swamp Cave return x98 detour should continue north")

    routes.observe_position(0x01, 98, 26)
    routes.observe_position(0x01, 96, 21)
    routes.observe_position(0x01, 96, 13)
    local arrival = routes.observe_position(0x01, 104, 10)
    assert_contains(arrival.message, "Arrived at Kol", "final waypoint should complete the return route")
    assert_equal(routes.is_active(), false, "route should stop after reaching Kol")

    routes.reset_for_tests()
end

function tests.rimuldar_from_tantegel_starts_three_leg_itinerary()
    routes.reset_for_tests()

    local info, err = routes.start("rimuldar", 0x01, 43, 43)

    assert_equal(err, nil, "Rimuldar alias should resolve from Tantegel")
    assert_equal(info.route.id, "kol_staging",
        "far Rimuldar requests should begin on the established Kol route")
    assert_equal(info.object_id, "route_kol_staging_02",
        "Rimuldar staging should leave Tantegel through the first Kol movement waypoint")
    assert_contains(info.message, "Rimuldar route starts from Kol",
        "staging speech should retain Rimuldar as the final destination")
    assert_contains(info.message, "Starting route to Kol first",
        "staging speech should identify the route that actually started")
    assert_contains(info.log, "staged_from=rimuldar",
        "structured logs should retain the final Rimuldar destination")

    local segment = assert(routes.plan_next_segment(0x01, 43, 43))
    assert_equal(segment.waypoint.name, "Brecconary west bypass",
        "connected Rimuldar travel should reuse the validated Kol route")
    assert_equal(segment.steps[1], "up",
        "the first leg should leave Tantegel toward the Brecconary bypass")

    routes.reset_for_tests()
end

function tests.rimuldar_object_and_guidance_retain_final_destination()
    routes.reset_for_tests()
    local target = {
        id = "overworld_rimuldar",
        name = "Rimuldar",
        x = 102,
        y = 72,
    }

    local info, err = routes.start_for_object(target, 0x01, 43, 43)

    assert_equal(err, nil, "Rimuldar Travel object should resolve from Tantegel")
    assert_equal(info.route.id, "kol_staging",
        "Travel-object starts should use the non-entry Kol staging route")
    assert_equal(routes.active_route_matches_object(target), true,
        "the selected Rimuldar object should remain bound during the Kol leg")

    local refreshed = routes.guidance_for_object(target, 0x01, 43, 43)
    assert_equal(refreshed.route.id, "kol_staging",
        "guidance refresh should keep the first itinerary leg active")
    assert_contains(refreshed.message, "Current leg to Kol",
        "guidance should identify the active Kol leg")
    assert_contains(refreshed.message, "Final destination: Rimuldar",
        "guidance should retain Rimuldar as the final destination")

    routes.reset_for_tests()
end

function tests.rimuldar_itinerary_hands_off_at_kol_and_swamp_cave()
    routes.reset_for_tests()
    local target = {
        id = "overworld_rimuldar",
        name = "Rimuldar",
        x = 102,
        y = 72,
    }
    assert(routes.start_for_object(target, 0x01, 43, 43))

    local kol = assert(routes._route_for_tests("kol_staging"))
    local event
    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    assert_equal(event.status, "handoff",
        "Kol west doorstep should hand off to the Swamp Cave leg")
    assert_equal(routes.active_route_id(), "swamp_cave",
        "the first handoff should activate the established Swamp Cave route")
    assert_contains(event.message, "Reached Kol west doorstep. Continuing toward Rimuldar.",
        "the Kol handoff should retain the final destination")
    assert_contains(event.message, "Current leg to Swamp Cave",
        "the Kol handoff should name the cave leg")
    assert_contains(event.message, "Final destination: Rimuldar",
        "the Kol handoff should keep naming Rimuldar")
    assert_equal(event.object_id, "route_swamp_cave_02",
        "the cave leg should begin at its first movement waypoint")
    assert_equal(event.steps, nil,
        "the Kol handoff must not inject movement")

    event = routes.observe_position(0x15, 0, 0)

    assert_equal(event.status, "handoff",
        "entering Swamp Cave north should hand off to the Rimuldar leg")
    assert_equal(routes.active_route_id(), "rimuldar",
        "the cave handoff should activate the existing Rimuldar route")
    assert_contains(event.message, "Reached Swamp Cave. Continuing to Rimuldar.",
        "the cave handoff should name the completed and final legs")
    assert_contains(event.message, "Next: Swamp Cave South Entrance",
        "the dormant Rimuldar leg should point to the south cave exit")
    assert_contains(event.log, "from_route=swamp_cave",
        "the cave handoff log should identify the completed leg")
    assert_equal(event.object_id, "route_rimuldar_01",
        "Rimuldar guidance should wait on the south cave entrance anchor")
    assert_equal(event.steps, nil,
        "the cave handoff must not inject overworld movement inside the cave")
    assert_equal(routes.active_route_matches_object(target), true,
        "Rimuldar should remain selected while the player traverses the cave")

    local south_exit = routes.observe_position(0x01, 104, 49)
    assert_contains(south_exit.message, "Poison swamp ahead",
        "the south cave exit should warn the player about damaging terrain")
    assert_not_contains(south_exit.message, "live validation",
        "live-accepted Rimuldar guidance must not expose stale developer language")
    local segment = assert(routes.plan_next_segment(0x01, 104, 49))
    assert_equal(segment.waypoint.name, "North Rimuldar west safer route",
        "the south cave exit should resume the proven Rimuldar corridor")
    assert_equal(#segment.steps, 11,
        "the first resumed segment should preserve the bounded westbound route")
    assert_equal(segment.steps[1], "left",
        "the Rimuldar leg should leave the south cave westbound")

    routes.reset_for_tests()
end

function tests.stopping_connected_rimuldar_clears_all_remaining_legs()
    routes.reset_for_tests()
    routes.start("rimuldar", 0x01, 43, 43)

    local event = routes.stop()

    assert_contains(event.message, "Stopped overworld route",
        "explicit stop should acknowledge connected Rimuldar cancellation")
    assert_equal(routes.is_active(), false,
        "stopping should clear the active Kol leg")
    assert_equal(routes.observe_position(0x15, 0, 0), nil,
        "a stopped itinerary must not resume inside Swamp Cave")

    routes.reset_for_tests()
end

function tests.magic_temple_from_tantegel_inherits_connected_rimuldar_route()
    routes.reset_for_tests()

    local info, err = routes.start("magic temple", 0x01, 43, 43)

    assert_equal(err, nil, "Magic Temple alias should still resolve from Tantegel")
    assert_equal(info.route.id, "kol_staging",
        "far Magic Temple travel should inherit the connected Rimuldar itinerary")
    assert_equal(info.object_id, "route_kol_staging_02",
        "the inherited itinerary should leave Tantegel on the safe Kol route")
    assert_contains(info.message, "Magic Temple route starts from Kol",
        "nested staging speech should retain Magic Temple")
    assert_contains(info.log, "staged_from=magic_temple",
        "nested staging logs should retain Magic Temple as the final destination")

    routes.reset_for_tests()
end

function tests.rimuldar_object_from_south_swamp_cave_starts_candidate_route()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_rimuldar",
        name = "Rimuldar",
        x = 102,
        y = 72,
    }, 0x01, 104, 49)

    assert_equal(err, nil, "Rimuldar Travel object should start guidance from the south cave landing")
    assert_equal(info.route.id, "rimuldar", "Rimuldar object should choose the Rimuldar candidate route")
    assert_equal(info.object_id, "route_rimuldar_02", "south cave start should skip the current entrance anchor")
    assert_contains(info.message, "North Rimuldar west safer route", "route should begin with the guide-recommended west approach")

    local segment = assert(routes.plan_next_segment(0x01, 104, 49))
    assert_equal(segment.waypoint.name, "North Rimuldar west safer route", "first candidate segment should target the west approach")
    assert_equal(segment.steps[1], "left", "candidate route should initially try the west side")
    assert_equal(#segment.steps, 11, "candidate route should queue the westbound cave-landing test segment")

    routes.reset_for_tests()
end

function tests.rimuldar_candidate_route_follows_guide_west_side()
    routes.reset_for_tests()
    routes.start("rimuldar", 0x01, 104, 49)

    local west_route = routes.observe_position(0x01, 93, 49)
    assert_contains(west_route.message, "Reached North Rimuldar west safer route", "route should confirm the initial west-side approach")
    assert_contains(west_route.message, "Next: South cave west ridge road", "route should turn west before the blocked mountain column")

    routes.observe_position(0x01, 92, 52)
    routes.observe_position(0x01, 86, 52)
    routes.observe_position(0x01, 86, 54)
    routes.observe_position(0x01, 83, 54)
    routes.observe_position(0x01, 83, 56)
    routes.observe_position(0x01, 85, 56)
    routes.observe_position(0x01, 85, 58)
    routes.observe_position(0x01, 88, 58)
    local lake = routes.observe_position(0x01, 88, 71)
    assert_contains(lake.message, "Rimuldar-area monsters are dangerous", "route should warn before the final Rimuldar-area push")
    assert_contains(lake.message, "Next: Rimuldar west lake bend", "route should proceed around the lake approach")

    routes.observe_position(0x01, 90, 71)
    routes.observe_position(0x01, 90, 72)
    routes.observe_position(0x01, 97, 72)
    routes.observe_position(0x01, 97, 71)
    routes.observe_position(0x01, 98, 70)
    routes.observe_position(0x01, 98, 69)
    routes.observe_position(0x01, 99, 69)
    routes.observe_position(0x01, 99, 68)
    routes.observe_position(0x01, 100, 67)
    routes.observe_position(0x01, 101, 67)
    routes.observe_position(0x01, 102, 68)
    routes.observe_position(0x01, 103, 68)
    routes.observe_position(0x01, 105, 68)
    routes.observe_position(0x01, 106, 69)
    routes.observe_position(0x01, 106, 70)
    routes.observe_position(0x01, 107, 70)
    routes.observe_position(0x01, 108, 70)
    routes.observe_position(0x01, 108, 71)
    routes.observe_position(0x01, 107, 71)
    routes.observe_position(0x01, 107, 72)
    routes.observe_position(0x01, 103, 72)
    local arrival = routes.observe_position(0x01, 102, 72)
    assert_contains(arrival.message, "Arrived at Rimuldar", "final waypoint should complete the Rimuldar route")
    assert_equal(routes.is_active(), false, "route should stop at Rimuldar")

    routes.reset_for_tests()
end

function tests.rimuldar_route_avoids_north_town_wall()
    routes.reset_for_tests()
    routes.start("rimuldar", 0x01, 97, 72)

    local segment = assert(routes.plan_next_segment(0x01, 97, 72))
    assert_equal(segment.waypoint.name, "Rimuldar north wall bypass", "route should bypass the blocked north town wall")
    assert_equal(segment.steps[1], "up", "route should not retry east from the blocked row-72 wall")

    routes.reset_for_tests()
end

function tests.rimuldar_route_avoids_noisy_west_lake_up_step()
    routes.reset_for_tests()
    routes.start("rimuldar", 0x01, 104, 49)

    routes.observe_position(0x01, 93, 49)
    routes.observe_position(0x01, 92, 52)
    routes.observe_position(0x01, 86, 52)
    routes.observe_position(0x01, 86, 54)
    routes.observe_position(0x01, 83, 54)
    routes.observe_position(0x01, 83, 56)
    routes.observe_position(0x01, 85, 56)
    routes.observe_position(0x01, 85, 58)
    routes.observe_position(0x01, 88, 58)
    routes.observe_position(0x01, 88, 71)

    local segment = assert(routes.plan_next_segment(0x01, 89, 72))
    assert_equal(segment.waypoint.name, "Rimuldar west lake bend", "route should still target the lake bend")
    assert_equal(segment.steps[1], "right", "route should avoid retrying the noisy north step from 89,72")

    routes.reset_for_tests()
end

function tests.rimuldar_route_avoids_north_wall_corner_block()
    routes.reset_for_tests()
    routes.start("rimuldar", 0x01, 104, 49)

    routes.observe_position(0x01, 93, 49)
    routes.observe_position(0x01, 92, 52)
    routes.observe_position(0x01, 86, 52)
    routes.observe_position(0x01, 86, 54)
    routes.observe_position(0x01, 83, 54)
    routes.observe_position(0x01, 83, 56)
    routes.observe_position(0x01, 85, 56)
    routes.observe_position(0x01, 85, 58)
    routes.observe_position(0x01, 88, 58)
    routes.observe_position(0x01, 88, 71)
    routes.observe_position(0x01, 90, 71)
    routes.observe_position(0x01, 90, 72)
    routes.observe_position(0x01, 97, 72)
    routes.observe_position(0x01, 97, 71)

    local segment = assert(routes.plan_next_segment(0x01, 97, 71))
    assert_equal(segment.waypoint.name, "Rimuldar north wall corner", "route should still target the north wall corner")
    assert_equal(segment.steps[1], "up", "route should avoid blocked 97,71 east into 98,71")

    routes.reset_for_tests()
end

function tests.rimuldar_route_turns_west_at_confirmed_93_52_block()
    routes.reset_for_tests()
    routes.start("rimuldar", 0x01, 104, 49)
    routes.observe_position(0x01, 93, 49)

    local segment = assert(routes.plan_next_segment(0x01, 93, 52))
    assert_equal(segment.waypoint.name, "South cave west ridge road", "route should target the proven west detour from the blocked column")
    assert_equal(segment.steps[1], "left", "route should not retry the confirmed blocked south edge at 93,52")

    routes.reset_for_tests()
end

function tests.swamp_cave_south_object_from_rimuldar_starts_return_route()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_swamp_cave_south_entrance",
        name = "Swamp Cave South Entrance",
        x = 104,
        y = 49,
    }, 0x01, 102, 72)

    assert_equal(err, nil, "south Swamp Cave Travel object should start from Rimuldar")
    assert_equal(info.route.id, "swamp_cave_south", "south entrance object should choose the Rimuldar return route")
    assert_equal(info.object_id, "route_swamp_cave_south_02", "Rimuldar start should skip the current town anchor")
    assert_contains(info.message, "Rimuldar east doorstep", "return route should leave town by the live east approach")

    local segment = assert(routes.plan_next_segment(0x01, 102, 72))
    assert_equal(segment.waypoint.name, "Rimuldar east doorstep", "first return segment should target the live east doorstep")
    assert_equal(segment.steps[1], "right", "return route should step back out along the live entry approach")

    routes.reset_for_tests()
end

function tests.swamp_cave_south_return_reverses_candidate_rimuldar_path()
    routes.reset_for_tests()
    routes.start("rimuldar to cave", 0x01, 102, 72)

    routes.observe_position(0x01, 103, 72)
    routes.observe_position(0x01, 107, 72)
    routes.observe_position(0x01, 107, 71)
    routes.observe_position(0x01, 108, 71)
    routes.observe_position(0x01, 108, 70)
    routes.observe_position(0x01, 107, 70)
    routes.observe_position(0x01, 106, 70)
    routes.observe_position(0x01, 106, 69)
    routes.observe_position(0x01, 105, 68)
    routes.observe_position(0x01, 103, 68)
    routes.observe_position(0x01, 102, 68)
    routes.observe_position(0x01, 101, 67)
    routes.observe_position(0x01, 100, 67)
    routes.observe_position(0x01, 99, 68)
    routes.observe_position(0x01, 99, 69)
    routes.observe_position(0x01, 98, 69)
    routes.observe_position(0x01, 98, 70)
    routes.observe_position(0x01, 97, 71)
    routes.observe_position(0x01, 97, 72)
    routes.observe_position(0x01, 90, 72)
    routes.observe_position(0x01, 90, 71)
    local lake = routes.observe_position(0x01, 88, 71)
    assert_contains(lake.message, "Leaving Rimuldar by the guide's safer west route", "return route should warn on the west-side exit")

    routes.observe_position(0x01, 88, 58)
    routes.observe_position(0x01, 85, 58)
    routes.observe_position(0x01, 85, 56)
    routes.observe_position(0x01, 83, 56)
    routes.observe_position(0x01, 83, 54)
    routes.observe_position(0x01, 86, 54)
    routes.observe_position(0x01, 86, 52)
    routes.observe_position(0x01, 92, 52)
    routes.observe_position(0x01, 92, 48)
    routes.observe_position(0x01, 100, 48)
    routes.observe_position(0x01, 100, 50)
    routes.observe_position(0x01, 104, 50)
    local arrival = routes.observe_position(0x01, 104, 49)
    assert_contains(arrival.message, "Arrived at Swamp Cave South Entrance", "final waypoint should complete the cave return")
    assert_equal(routes.is_active(), false, "return route should stop at the south cave entrance")

    routes.reset_for_tests()
end

function tests.swamp_cave_south_rimuldar_exit_hardens_live_turn_cadence()
    local east_bend = assert(find_waypoint("swamp_cave_south", "Rimuldar east bend"))
    assert_equal(east_bend.route_hold_after_movement_start_frames, 60,
        "the first northbound Rimuldar exit step should sustain its early movement twitch")
    assert_equal(east_bend.route_early_twitch_timeout_frames, 60,
        "the first northbound Rimuldar exit step should allow the observed late completion")

    local north_approach_bend = assert(find_waypoint(
        "swamp_cave_south", "Rimuldar north approach bend"))
    assert_equal(north_approach_bend.route_hold_after_movement_start_frames, 60,
        "the southbound north-approach step should sustain its early movement twitch")
    assert_equal(north_approach_bend.route_early_twitch_timeout_frames, 60,
        "the southbound north-approach step should allow the observed manual-hold cadence")

    local turn_names = {
        "Rimuldar northeast lane",
        "Rimuldar north ridge east lane",
        "Rimuldar north ridge lane",
        "Rimuldar north wall bypass",
    }
    for _, name in ipairs(turn_names) do
        local waypoint = assert(find_waypoint("swamp_cave_south", name))
        assert_equal(waypoint.route_reset_movement_on_turn_settle, true,
            name .. " should clear live directional carry before changing axes")
    end

    local wall_bypass = assert(find_waypoint("swamp_cave_south", "Rimuldar north wall bypass"))
    assert_equal(wall_bypass.axis_order[1], "horizontal",
        "the north wall bypass should move west before the blocked south edge")
    assert_equal(wall_bypass.axis_order[2], "vertical",
        "the north wall bypass should turn south only after reaching column 97")
end

function tests.swamp_cave_south_uses_passable_north_wall_bypass_order()
    routes.reset_for_tests()
    routes.start("rimuldar to cave", 0x01, 98, 70)

    local segment = assert(routes.plan_next_segment(0x01, 98, 70))

    assert_equal(segment.waypoint.name, "Rimuldar north wall bypass",
        "the return route should retain the established north wall waypoint")
    assert_equal(segment.steps[1], "left",
        "the bypass should avoid the blocked down edge from 98,70")
    assert_equal(segment.steps[2], "down",
        "the bypass should turn south from the passable column 97")

    routes.reset_for_tests()
end

function tests.swamp_cave_south_uses_live_direct_north_exit_from_rimuldar()
    routes.reset_for_tests()
    routes.start("rimuldar to cave", 0x01, 107, 72)

    local segment = assert(routes.plan_next_segment(0x01, 107, 72))

    assert_equal(segment.waypoint.name, "Rimuldar east bend",
        "the return route should begin with the proven northbound exit step")
    assert_equal(segment.steps[1], "up",
        "the Rimuldar exit should move directly north")
    assert_equal(segment.route_final_carry_x, 107,
        "the live northbound carry should remain on the same column")
    assert_equal(segment.route_final_carry_y, 70,
        "the live northbound carry should continue directly to the east road")
    assert_equal(find_waypoint("swamp_cave_south", "Rimuldar east approach"), nil,
        "the return route should not retain the obsolete east detour")
    assert_equal(find_waypoint("swamp_cave_south", "Rimuldar east approach upper lane"), nil,
        "the return route should not retain the obsolete upper detour")

    routes.reset_for_tests()
end

function tests.swamp_cave_south_return_avoids_blocked_mountain_notch()
    routes.reset_for_tests()
    routes.start("rimuldar to cave", 0x01, 88, 58)

    local segment = assert(routes.plan_next_segment(0x01, 88, 58))
    assert_equal(segment.waypoint.name, "South island west pocket lower lane", "return should use the west-pocket detour")
    assert_equal(segment.steps[1], "left", "return route should not head east toward the blocked mountain notch")

    routes.reset_for_tests()
end

function tests.swamp_cave_south_recovery_routes_stuck_notch_west()
    routes.reset_for_tests()
    local info = assert(routes.start("rimuldar to cave", 0x01, 92, 57))

    assert_equal(info.route.id, "swamp_cave_south_recovery", "stuck notch starts should choose the recovery variant")
    assert_contains(info.message, "Safer west route north lane", "recovery should target the west escape lane")

    local segment = assert(routes.plan_next_segment(0x01, 92, 57))
    assert_equal(segment.waypoint.name, "Safer west route north lane", "recovery should not retry the blocked north edge")
    assert_equal(segment.steps[1], "left", "recovery should step west away from the blocked notch")

    routes.reset_for_tests()
end

function tests.magic_temple_object_from_rimuldar_starts_candidate_route()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_southern_cave",
        name = "Magic Temple",
        x = 108,
        y = 109,
    }, 0x01, 102, 72)

    assert_equal(err, nil, "Magic Temple Travel object should start from Rimuldar")
    assert_equal(info.route.id, "magic_temple", "Magic Temple object should choose the Magic Temple route")
    assert_equal(info.object_id, "route_magic_temple_02", "Rimuldar start should skip the current town anchor")
    assert_contains(info.message, "Rimuldar east doorstep", "temple route should leave by the proven east causeway")

    local segment = assert(routes.plan_next_segment(0x01, 102, 72))
    assert_equal(segment.waypoint.name, "Rimuldar east doorstep", "first segment should target the proven doorstep")
    assert_equal(segment.steps[1], "right", "temple route should leave Rimuldar to the east")

    routes.reset_for_tests()
end

function tests.magic_temple_from_south_cave_starts_rimuldar_staging_route()
    routes.reset_for_tests()

    local info, err = routes.start("magic temple", 0x01, 104, 49)

    assert_equal(err, nil, "Magic Temple alias should resolve from Swamp Cave South")
    assert_equal(info.route.id, "rimuldar_staging",
        "far Magic Temple requests should use the exterior Rimuldar staging route")
    assert_equal(info.object_id, "route_rimuldar_staging_02",
        "staging should start on the proven Rimuldar approach")
    assert_contains(info.message, "Magic Temple route starts from Rimuldar",
        "staging should explain the required hub")
    assert_contains(info.message, "Starting route to Rimuldar first",
        "staging should say which route actually started")
    assert_contains(info.message, "North Rimuldar west safer route",
        "staging should include normal Rimuldar route guidance")
    assert_contains(info.log, "staged_from=magic_temple", "staged starts should be visible in logs")

    local segment = assert(routes.plan_next_segment(0x01, 104, 49))
    assert_equal(segment.waypoint.name, "North Rimuldar west safer route",
        "the first segment should use the validated west-side Rimuldar route")
    assert_equal(#segment.steps, 11, "the staging leg should stay within the validated segment limit")
    assert_equal(segment.steps[1], "left", "the staging route should leave Swamp Cave South to the west")

    routes.reset_for_tests()
end

function tests.magic_temple_object_from_south_cave_retains_final_destination()
    routes.reset_for_tests()
    local target = {
        id = "overworld_southern_cave",
        name = "Magic Temple",
        x = 108,
        y = 109,
    }

    local info, err = routes.start_for_object(target, 0x01, 104, 49)

    assert_equal(err, nil, "Magic Temple Travel object should resolve from Swamp Cave South")
    assert_equal(info.route.id, "rimuldar_staging",
        "Travel-object starts should use the exterior Rimuldar staging guard")
    assert_equal(routes.active_route_matches_object(target), true,
        "the selected Magic Temple object should remain bound during the Rimuldar leg")

    routes.reset_for_tests()
end

function tests.magic_temple_staging_status_names_current_leg_and_final_destination()
    routes.reset_for_tests()
    routes.start("magic temple", 0x01, 104, 49)

    local info = routes.status(0x01, 104, 49)

    assert_contains(info.message, "Current leg to Rimuldar",
        "staging status should identify the route currently being followed")
    assert_contains(info.message, "Final destination: Magic Temple",
        "staging status should retain the player's requested destination")

    routes.reset_for_tests()
end

function tests.magic_temple_guidance_refresh_keeps_the_active_itinerary()
    routes.reset_for_tests()
    local target = {
        id = "overworld_southern_cave",
        name = "Magic Temple",
        x = 108,
        y = 109,
    }
    routes.start_for_object(target, 0x01, 104, 49)

    local info = routes.guidance_for_object(target, 0x01, 104, 49)

    assert_equal(info.route.id, "rimuldar_staging",
        "re-reading guidance should keep the exterior Rimuldar leg active")
    assert_contains(info.message, "Current leg to Rimuldar",
        "re-reading guidance should report the active leg instead of restarting it")
    assert_contains(info.message, "Final destination: Magic Temple",
        "re-reading guidance should retain the requested destination")

    routes.reset_for_tests()
end

function tests.magic_temple_staging_hands_off_outside_rimuldar_without_starting_movement()
    routes.reset_for_tests()
    routes.start("magic temple", 0x01, 104, 49)

    local staging = assert(routes._route_for_tests("rimuldar_staging"))
    for index = 2, #staging.waypoints - 1 do
        local point = staging.waypoints[index]
        assert(routes.observe_position(0x01, point.x, point.y))
    end
    local event = routes.observe_position(0x01, 103, 72)

    assert_equal(routes.active_route_id(), "magic_temple",
        "reaching Rimuldar's doorstep should activate the requested Magic Temple leg")
    assert_equal(event.status, "handoff",
        "the route event should distinguish a leg handoff from final arrival")
    assert_contains(event.message, "Reached Rimuldar east doorstep. Continuing to Magic Temple.",
        "handoff speech should name the exterior hub and final destination")
    assert_contains(event.message, "Next: Rimuldar east gate lane",
        "handoff speech should identify the next Magic Temple waypoint")
    assert_contains(event.log, "event=handoff", "handoff should be explicit in structured logs")
    assert_contains(event.log, "from_route=rimuldar_staging",
        "handoff logs should identify the completed exterior leg")
    assert_equal(event.object_id, "route_magic_temple_03",
        "route markers should refresh to the first Magic Temple movement waypoint")
    assert_equal(event.steps, nil,
        "handoff must wait for another player auto-walk command instead of moving immediately")

    local segment = assert(routes.plan_next_segment(0x01, 103, 72))
    assert_equal(segment.waypoint.name, "Rimuldar east gate lane",
        "the next player-triggered segment should leave the doorstep toward the temple")
    assert_equal(#segment.steps, 4, "the first Magic Temple segment should leave the town approach")
    assert_equal(segment.steps[1], "right", "the second leg should leave Rimuldar to the east")

    routes.reset_for_tests()
end

function tests.magic_temple_route_follows_map_derived_corridor()
    local route = assert(routes._route_for_tests("magic_temple"))
    local expected = {
        {102, 72},
        {103, 72},
        {107, 72},
        {107, 76},
        {110, 76},
        {110, 86},
        {106, 86},
        {106, 99},
        {102, 99},
        {102, 107},
        {101, 107},
        {101, 110},
        {102, 110},
        {102, 111},
        {103, 111},
        {103, 113},
        {104, 113},
        {104, 114},
        {107, 114},
        {107, 111},
        {108, 111},
        {108, 109},
    }

    assert_equal(#route.waypoints, #expected, "Magic Temple route should preserve every terrain-safe turn")
    for i, point in ipairs(expected) do
        assert_equal(route.waypoints[i].x, point[1], "Magic Temple waypoint " .. i .. " x")
        assert_equal(route.waypoints[i].y, point[2], "Magic Temple waypoint " .. i .. " y")
    end
    assert_contains(
        route.waypoints[#route.waypoints].warning,
        "STAIRS",
        "Magic Temple arrival should explain the required stairs command"
    )
end

function tests.magic_temple_route_crosses_southern_bridge_westward()
    routes.reset_for_tests()
    routes.start("magic temple", 0x01, 106, 99)

    local segment = assert(routes.plan_next_segment(0x01, 106, 99))
    assert_equal(segment.waypoint.name, "Southern bridge west landing", "bridge approach should target the western landing")
    assert_equal(segment.steps[1], "left", "temple route should cross the southern bridge westward")

    routes.reset_for_tests()
end

function tests.rimuldar_object_from_magic_temple_uses_return_variant()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_rimuldar",
        name = "Rimuldar",
        x = 102,
        y = 72,
    }, 0x01, 108, 109)

    assert_equal(err, nil, "Rimuldar Travel object should start outside the Magic Temple")
    assert_equal(info.route.id, "rimuldar_magic_temple", "Rimuldar object should choose the temple return route")
    assert_equal(info.object_id, "route_rimuldar_magic_temple_02", "temple start should skip the current entrance anchor")

    local segment = assert(routes.plan_next_segment(0x01, 108, 109))
    assert_equal(segment.waypoint.name, "Temple inner east lane", "return route should first leave the temple pocket")
    assert_equal(segment.steps[1], "down", "return route should leave the temple entrance to the south")

    routes.reset_for_tests()
end

function tests.magic_temple_return_exactly_reverses_candidate_route()
    local outbound = assert(routes._route_for_tests("magic_temple"))
    local inbound = assert(routes._route_for_tests("rimuldar_magic_temple"))

    assert_equal(#inbound.waypoints, #outbound.waypoints, "temple return should preserve every outbound turn")
    for i, point in ipairs(outbound.waypoints) do
        local reverse = inbound.waypoints[#inbound.waypoints - i + 1]
        assert_equal(reverse.x, point.x, "temple reverse waypoint " .. i .. " x")
        assert_equal(reverse.y, point.y, "temple reverse waypoint " .. i .. " y")
    end
end

function tests.rimuldar_staging_variants_stop_at_east_doorstep()
    local inbound = assert(routes._route_for_tests("rimuldar_staging"))
    local temple_return = assert(routes._route_for_tests(
        "rimuldar_magic_temple_staging"))

    assert_equal(inbound.waypoints[#inbound.waypoints].x, 103,
        "south-cave staging should stop east of Rimuldar")
    assert_equal(inbound.waypoints[#inbound.waypoints].y, 72,
        "south-cave staging should stay on Rimuldar's entrance row")
    assert_equal(temple_return.waypoints[#temple_return.waypoints].x, 103,
        "temple-return staging should stop east of Rimuldar")
    assert_equal(temple_return.waypoints[#temple_return.waypoints].y, 72,
        "temple-return staging should stay on Rimuldar's entrance row")

    local direct = assert(routes._route_for_tests("rimuldar"))
    local direct_return = assert(routes._route_for_tests(
        "rimuldar_magic_temple"))
    assert_equal(direct.waypoints[#direct.waypoints].x, 102,
        "direct south-cave travel should still enter Rimuldar")
    assert_equal(direct_return.waypoints[#direct_return.waypoints].x, 102,
        "direct temple travel should still enter Rimuldar")
end

function tests.entering_magic_temple_stops_outbound_route()
    routes.reset_for_tests()
    routes.start("magic temple", 0x01, 102, 72)

    local arrival = routes.observe_position(0x0E, 0, 4)

    assert_contains(arrival.message, "Arrived at Magic Temple", "entering map 0x0E should complete the route")
    assert_equal(routes.is_active(), false, "temple route should stop after the map transition")

    routes.reset_for_tests()
end

function tests.tantegel_object_from_kol_uses_kol_return_variant()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_tantegel_castle",
        name = "Tantegel Castle",
        x = 43,
        y = 43,
    }, 0x01, 104, 10)

    assert_equal(err, nil, "Tantegel Castle Travel object should start from Kol")
    assert_equal(info.object_id, "route_tantegel_kol_02", "Kol-side return should leave town through the forest edge")
    assert_contains(info.message, "Route to Tantegel Castle", "variant should still speak the castle destination")
    assert_contains(info.message, "Kol forest west edge", "Kol start should not snap to the distant cave-road route")

    local segment = assert(routes.plan_next_segment(0x01, 104, 10))
    assert_equal(segment.waypoint.name, "Kol forest west edge", "first Kol return segment should target the west forest edge")
    assert_equal(segment.steps[1], "left", "Kol return should start west instead of making a long cave-road push")

    routes.reset_for_tests()
end

function tests.early_destinations_from_kol_start_bridge_junction_staging()
    local cases = {
        {
            id = "overworld_garinham",
            name = "Garinham",
            x = 1,
            y = 2,
            continuation = "garinham_kol",
        },
        {
            id = "overworld_erdrick_s_cave",
            name = "Erdrick's Cave",
            x = 28,
            y = 12,
            continuation = "erdrick_kol",
        },
        {
            id = "overworld_brecconary",
            name = "Brecconary",
            x = 48,
            y = 41,
            continuation = "brecconary_kol",
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        local info, err = routes.start_for_object(case, 0x01, 104, 10)

        assert_equal(err, nil,
            case.name .. " Travel should resolve from Kol")
        assert_equal(info.route.id, "tantegel_bridge_staging",
            case.name .. " should first use the shared bridge-junction return")
        assert_equal(info.object_id, "route_tantegel_bridge_staging_02",
            case.name .. " staging should leave Kol through the forest edge")
        assert_contains(info.message, case.name .. " route starts from Tantegel bridge junction",
            "staging speech should retain " .. case.name)
        assert_equal(routes.active_route_matches_object(case), true,
            case.name .. " should remain selected during staging")

        local segment = assert(routes.plan_next_segment(0x01, 104, 10))
        assert_equal(segment.waypoint.name, "Kol forest west edge",
            case.name .. " staging should reuse the validated Kol return")
        assert_equal(segment.steps[1], "left",
            case.name .. " staging should leave Kol westward")

        local staging = assert(
            routes._route_for_tests("tantegel_bridge_staging"))
        local event
        for index = 2, #staging.waypoints do
            local waypoint = staging.waypoints[index]
            event = routes.observe_position(0x01, waypoint.x, waypoint.y)
        end
        assert_equal(event.status, "handoff",
            case.name .. " should hand off at the exterior bridge junction")
        assert_equal(routes.active_route_id(), case.continuation,
            case.name .. " should activate its Kol-origin continuation")
        assert_equal(routes.active_route_matches_object(case), true,
            case.name .. " should remain selected after the handoff")
    end

    routes.reset_for_tests()
end

function tests.early_destinations_from_northern_cave_start_shrine_return_staging()
    local cases = {
        {
            id = "overworld_garinham",
            name = "Garinham",
        },
        {
            id = "overworld_erdrick_s_cave",
            name = "Erdrick's Cave",
        },
        {
            id = "overworld_brecconary",
            name = "Brecconary",
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        local info, err = routes.start_for_object(case, 0x01, 81, 1)

        assert_equal(err, nil,
            case.name .. " Travel should resolve outside Northern Cave")
        assert_equal(info.route.id, "kol_rain_shrine_staging",
            case.name .. " should first use the proven shrine return")
        assert_equal(info.object_id, "route_kol_rain_shrine_staging_02",
            case.name .. " should first target the shrine entrance approach")
        assert_contains(info.message, case.name .. " route starts from Kol",
            "shrine staging speech should retain " .. case.name)
        assert_equal(routes.active_route_matches_object(case), true,
            case.name .. " should remain selected during the shrine return")

        local segment = assert(routes.plan_next_segment(0x01, 81, 1))
        assert_equal(segment.waypoint.name, "Rain shrine entrance approach",
            case.name .. " should reuse the validated Northern Cave departure")
        assert_equal(segment.steps[1], "left",
            case.name .. " should leave Northern Cave westward")

        local shrine = assert(
            routes._route_for_tests("kol_rain_shrine_staging"))
        local event
        for index = 2, #shrine.waypoints do
            local waypoint = shrine.waypoints[index]
            event = routes.observe_position(0x01, waypoint.x, waypoint.y)
        end
        assert_equal(event.status, "handoff",
            case.name .. " should hand off outside Kol")
        assert_equal(routes.active_route_id(), "tantegel_bridge_staging",
            case.name .. " should next activate the bridge-junction return")
        assert_equal(event.object_id, "route_tantegel_bridge_staging_02",
            case.name .. " should leave Kol through the forest edge")
        assert_contains(event.log, "from_route=kol_rain_shrine_staging",
            "the first handoff should identify the shrine-return leg")
        assert_equal(event.steps, nil,
            "the exterior Kol handoff must not inject movement")
        assert_equal(routes.active_route_matches_object(case), true,
            case.name .. " should remain selected after the Kol handoff")

        segment = assert(routes.plan_next_segment(0x01, 103, 10))
        assert_equal(segment.waypoint.name, "Kol forest west edge",
            case.name .. " should continue on the established bridge return")
        assert_equal(segment.steps[1], "left",
            case.name .. " should bypass Kol westward")
    end

    routes.reset_for_tests()
end

function tests.brecconary_from_northern_cave_hands_off_at_bridge_junction()
    routes.reset_for_tests()
    local target = {
        id = "overworld_brecconary",
        name = "Brecconary",
        x = 48,
        y = 41,
    }
    assert(routes.start_for_object(target, 0x01, 81, 1))

    local shrine = assert(routes._route_for_tests("kol_rain_shrine_staging"))
    for index = 2, #shrine.waypoints do
        local waypoint = shrine.waypoints[index]
        routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(routes.active_route_id(), "tantegel_bridge_staging",
        "the Kol bypass should activate the shared bridge-junction return")

    local bridge = assert(routes._route_for_tests("tantegel_bridge_staging"))
    local event
    for index = 2, #bridge.waypoints do
        local waypoint = bridge.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    assert_equal(event.status, "handoff",
        "the bridge junction should hand off without entering Tantegel")
    assert_equal(routes.active_route_id(), "brecconary_kol",
        "the junction should activate the Brecconary continuation")
    assert_equal(event.object_id, "route_brecconary_kol_25",
        "the continuation should target Brecconary directly")
    assert_contains(event.log, "from_route=tantegel_bridge_staging",
        "the second handoff should identify the bridge-junction leg")
    assert_equal(event.steps, nil,
        "the exterior bridge handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "Brecconary should remain selected after both handoffs")

    local segment = assert(routes.plan_next_segment(0x01, 44, 38))
    assert_equal(segment.waypoint.name, "Brecconary",
        "the final continuation should target the town entrance")
    assert_equal(segment.path_length, 7,
        "the final Brecconary leg should remain the short proven segment")

    routes.reset_for_tests()
end

function tests.early_destinations_from_swamp_cave_north_start_kol_return_staging()
    local cases = {
        {
            id = "overworld_garinham",
            name = "Garinham",
            alias = "garinham",
        },
        {
            id = "overworld_erdrick_s_cave",
            name = "Erdrick's Cave",
            alias = "erdrick",
        },
        {
            id = "overworld_brecconary",
            name = "Brecconary",
            alias = "brecconary",
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        local info, err = routes.start_for_object(case, 0x01, 104, 44)

        assert_equal(err, nil,
            case.name .. " Travel should resolve outside Swamp Cave north")
        assert_equal(info.route.id, "kol_swamp_cave_staging",
            case.name .. " should first use the proven cave-to-Kol return")
        assert_equal(info.object_id, "route_kol_swamp_cave_staging_02",
            case.name .. " should first target the poison-swamp doorstep")
        assert_contains(info.message, case.name .. " route starts from Kol",
            "cave staging speech should retain " .. case.name)
        assert_equal(routes.active_route_matches_object(case), true,
            case.name .. " should remain selected during the Kol return")

        local segment = assert(routes.plan_next_segment(0x01, 104, 44))
        assert_equal(segment.waypoint.name, "Swamp Cave doorstep",
            case.name .. " should reuse the validated north-exit departure")
        assert_equal(segment.steps[1], "up",
            case.name .. " should leave Swamp Cave northward")

        routes.reset_for_tests()
        local alias_info, alias_err = routes.start(
            case.alias, 0x01, 104, 44)
        assert_equal(alias_err, nil,
            case.name .. " alias should resolve outside Swamp Cave north")
        assert_equal(alias_info.route.id, "kol_swamp_cave_staging",
            case.name .. " alias should use the same connected itinerary")
    end

    routes.reset_for_tests()
end

function tests.brecconary_from_swamp_cave_north_hands_off_at_bridge_junction()
    routes.reset_for_tests()
    local target = {
        id = "overworld_brecconary",
        name = "Brecconary",
        x = 48,
        y = 41,
    }
    assert(routes.start_for_object(target, 0x01, 104, 44))

    local kol = assert(routes._route_for_tests("kol_swamp_cave_staging"))
    local event
    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "the Kol west doorstep should hand off without entering town")
    assert_equal(routes.active_route_id(),
        "tantegel_bridge_swamp_cave_staging",
        "the Kol bypass should activate the bridge-junction return")
    assert_equal(event.object_id,
        "route_tantegel_bridge_swamp_cave_staging_02",
        "the bridge return should leave Kol through the forest edge")
    assert_equal(event.steps, nil,
        "the exterior Kol handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "Brecconary should remain selected after the Kol handoff")

    local bridge = assert(routes._route_for_tests(
        "tantegel_bridge_swamp_cave_staging"))
    for index = 2, #bridge.waypoints do
        local waypoint = bridge.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    assert_equal(event.status, "handoff",
        "the bridge junction should hand off without entering Tantegel")
    assert_equal(routes.active_route_id(),
        "brecconary_swamp_cave_north",
        "the junction should activate the Brecconary continuation")
    assert_equal(event.object_id,
        "route_brecconary_swamp_cave_north_25",
        "the continuation should target Brecconary directly")
    assert_contains(event.log,
        "from_route=tantegel_bridge_swamp_cave_staging",
        "the second handoff should identify the bridge-junction leg")
    assert_equal(event.steps, nil,
        "the exterior bridge handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "Brecconary should remain selected after both handoffs")

    local segment = assert(routes.plan_next_segment(0x01, 44, 38))
    assert_equal(segment.waypoint.name, "Brecconary",
        "the final continuation should target the town entrance")
    assert_equal(segment.path_length, 7,
        "the final Brecconary leg should remain the short proven segment")

    routes.reset_for_tests()
end

function tests.brecconary_from_swamp_cave_south_crosses_cave_then_uses_shared_return()
    routes.reset_for_tests()
    local target = {
        id = "overworld_brecconary",
        name = "Brecconary",
        x = 48,
        y = 41,
    }

    local info, err = routes.start_for_object(target, 0x01, 104, 49)

    assert_equal(err, nil,
        "Brecconary Travel should start outside Swamp Cave south")
    assert_equal(info.route.id, "swamp_cave_south",
        "south-exit travel should begin on the proven cave-entry route")
    assert_equal(info.object_id, "route_swamp_cave_south_34",
        "south-exit start should target the adjacent cave entrance")
    assert_contains(info.message,
        "Brecconary route starts from Swamp Cave South Entrance",
        "south-exit staging speech should retain Brecconary")
    assert_equal(routes.active_route_matches_object(target), true,
        "Brecconary should remain selected before cave traversal")

    local wait_event = routes.observe_position(0x01, 104, 49)
    assert_equal(wait_event.status, "await_transition",
        "standing on the south entrance should wait for automatic cave entry")
    assert_equal(routes.active_route_id(), "swamp_cave_south",
        "the itinerary must not advance before map 0x15 is observed")

    local wait_segment = assert(routes.plan_next_segment(0x01, 104, 49, {
        advance_if_at_waypoint = true,
    }))
    assert_equal(wait_segment.status, "already_at_waypoint",
        "autowalk should remain safely on the automatic-entry tile")
    assert_equal(#wait_segment.steps, 0,
        "autowalk must not synthesize movement through Swamp Cave")

    local cave_handoff = routes.observe_position(0x15, 0, 29)
    assert_equal(cave_handoff.status, "handoff",
        "entering Swamp Cave should advance the Brecconary itinerary")
    assert_equal(routes.active_route_id(), "kol_swamp_cave_staging",
        "cave entry should activate the established north-exit return")
    assert_equal(cave_handoff.object_id, "route_kol_swamp_cave_staging_01",
        "the cave handoff should wait for the north exterior landing")
    assert_equal(cave_handoff.steps, nil,
        "the cave handoff must not inject interior movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "Brecconary should remain selected during cave traversal")

    local north_exit = routes.observe_position(0x01, 104, 44)
    assert_equal(north_exit.object_id, "route_kol_swamp_cave_staging_02",
        "north exit should advance to the poison-swamp doorstep")

    local north_cave = {
        id = "overworld_swamp_cave",
        name = "Swamp Cave",
        x = 104,
        y = 44,
    }
    local refreshed = routes.guidance_for_object(
        north_cave, 0x01, 104, 44)
    assert_equal(refreshed.route.id, "kol_swamp_cave_staging",
        "north-exit guidance should retain the Brecconary itinerary")
    assert_contains(refreshed.message, "Final destination: Brecconary",
        "north-exit guidance should still name Brecconary")
    assert_equal(routes.active_route_matches_object(target), true,
        "Brecconary should remain selected after the cave-object refresh")

    local kol = assert(routes._route_for_tests("kol_swamp_cave_staging"))
    local event
    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "the Kol west doorstep should hand off without entering town")
    assert_equal(routes.active_route_id(),
        "tantegel_bridge_swamp_cave_staging",
        "the Kol bypass should activate the bridge-junction return")

    local bridge = assert(routes._route_for_tests(
        "tantegel_bridge_swamp_cave_staging"))
    for index = 2, #bridge.waypoints do
        local waypoint = bridge.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "the bridge junction should hand off without entering Tantegel")
    assert_equal(routes.active_route_id(),
        "brecconary_swamp_cave_south",
        "the junction should activate the south-origin continuation")
    assert_equal(event.steps, nil,
        "the bridge handoff must not inject exterior movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "Brecconary should remain selected after every handoff")

    local segment = assert(routes.plan_next_segment(0x01, 44, 38))
    assert_equal(segment.waypoint.name, "Brecconary",
        "the final continuation should target the town entrance")
    assert_equal(segment.path_length, 7,
        "the final Brecconary leg should remain the short proven segment")

    routes.reset_for_tests()
    local alias_info, alias_err = routes.start(
        "brecconary", 0x01, 104, 49)
    assert_equal(alias_err, nil,
        "Brecconary alias should start outside Swamp Cave south")
    assert_equal(alias_info.route.id, "swamp_cave_south",
        "the alias should use the same connected itinerary")

    routes.reset_for_tests()
end

function tests.erdrick_from_swamp_cave_south_crosses_cave_then_uses_shared_return()
    routes.reset_for_tests()
    local target = {
        id = "overworld_erdrick_s_cave",
        name = "Erdrick's Cave",
        x = 28,
        y = 12,
    }

    local info, err = routes.start_for_object(target, 0x01, 104, 49)

    assert_equal(err, nil,
        "Erdrick Travel should start outside Swamp Cave south")
    assert_equal(info.route.id, "swamp_cave_south",
        "south-exit travel should begin on the proven cave-entry route")
    assert_contains(info.message,
        "Erdrick's Cave route starts from Swamp Cave South Entrance",
        "south-exit staging speech should retain Erdrick's Cave")
    assert_equal(routes.active_route_matches_object(target), true,
        "Erdrick's Cave should remain selected before cave traversal")

    local wait_event = routes.observe_position(0x01, 104, 49)
    assert_equal(wait_event.status, "await_transition",
        "standing on the south entrance should wait for automatic cave entry")
    assert_equal(routes.active_route_id(), "swamp_cave_south",
        "the itinerary must not advance before map 0x15 is observed")

    local cave_handoff = routes.observe_position(0x15, 0, 29)
    assert_equal(cave_handoff.status, "handoff",
        "entering Swamp Cave should advance the Erdrick itinerary")
    assert_equal(routes.active_route_id(), "kol_swamp_cave_staging",
        "cave entry should activate the established north-exit return")
    assert_equal(cave_handoff.steps, nil,
        "the cave handoff must not inject interior movement")

    routes.observe_position(0x01, 104, 44)
    local north_cave = {
        id = "overworld_swamp_cave",
        name = "Swamp Cave",
        x = 104,
        y = 44,
    }
    local refreshed = routes.guidance_for_object(
        north_cave, 0x01, 104, 44)
    assert_equal(refreshed.route.id, "kol_swamp_cave_staging",
        "north-exit guidance should retain the Erdrick itinerary")
    assert_contains(refreshed.message,
        "Final destination: Erdrick's Cave",
        "north-exit guidance should still name Erdrick's Cave")

    local kol = assert(routes._route_for_tests("kol_swamp_cave_staging"))
    local event
    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "the Kol west doorstep should hand off without entering town")
    assert_equal(routes.active_route_id(),
        "tantegel_bridge_swamp_cave_staging",
        "the Kol bypass should activate the bridge-junction return")

    local bridge = assert(routes._route_for_tests(
        "tantegel_bridge_swamp_cave_staging"))
    for index = 2, #bridge.waypoints do
        local waypoint = bridge.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "the bridge junction should hand off without entering Tantegel")
    assert_equal(routes.active_route_id(),
        "erdrick_swamp_cave_south",
        "the junction should activate the south-origin Erdrick continuation")
    assert_equal(event.steps, nil,
        "the bridge handoff must not inject exterior movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "Erdrick's Cave should remain selected after every handoff")

    local segment = assert(routes.plan_next_segment(0x01, 44, 38))
    assert_equal(segment.waypoint.name, "Bridge lower west lane",
        "the final continuation should use the established Erdrick corridor")
    assert_equal(segment.path_length, 8,
        "the first Erdrick segment should remain bounded")
    assert_equal(segment.steps[1], "up",
        "the Erdrick continuation should leave the junction northward")

    routes.reset_for_tests()
    local alias_info, alias_err = routes.start(
        "erdrick", 0x01, 104, 49)
    assert_equal(alias_err, nil,
        "Erdrick alias should start outside Swamp Cave south")
    assert_equal(alias_info.route.id, "swamp_cave_south",
        "the alias should use the same connected itinerary")

    routes.reset_for_tests()
end

function tests.garinham_from_swamp_cave_south_crosses_cave_then_uses_shared_return()
    routes.reset_for_tests()
    local target = {
        id = "overworld_garinham",
        name = "Garinham",
        x = 1,
        y = 2,
    }

    local info, err = routes.start_for_object(target, 0x01, 104, 49)

    assert_equal(err, nil,
        "Garinham Travel should start outside Swamp Cave south")
    assert_equal(info.route.id, "swamp_cave_south",
        "south-exit travel should begin on the proven cave-entry route")
    assert_contains(info.message,
        "Garinham route starts from Swamp Cave South Entrance",
        "south-exit staging speech should retain Garinham")
    assert_equal(routes.active_route_matches_object(target), true,
        "Garinham should remain selected before cave traversal")

    local wait_event = routes.observe_position(0x01, 104, 49)
    assert_equal(wait_event.status, "await_transition",
        "standing on the south entrance should wait for automatic cave entry")
    assert_equal(routes.active_route_id(), "swamp_cave_south",
        "the itinerary must not advance before map 0x15 is observed")

    local cave_handoff = routes.observe_position(0x15, 0, 29)
    assert_equal(cave_handoff.status, "handoff",
        "entering Swamp Cave should advance the Garinham itinerary")
    assert_equal(routes.active_route_id(), "kol_swamp_cave_staging",
        "cave entry should activate the established north-exit return")
    assert_equal(cave_handoff.steps, nil,
        "the cave handoff must not inject interior movement")

    routes.observe_position(0x01, 104, 44)
    local north_cave = {
        id = "overworld_swamp_cave",
        name = "Swamp Cave",
        x = 104,
        y = 44,
    }
    local refreshed = routes.guidance_for_object(
        north_cave, 0x01, 104, 44)
    assert_equal(refreshed.route.id, "kol_swamp_cave_staging",
        "north-exit guidance should retain the Garinham itinerary")
    assert_contains(refreshed.message, "Final destination: Garinham",
        "north-exit guidance should still name Garinham")

    local kol = assert(routes._route_for_tests("kol_swamp_cave_staging"))
    local event
    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "the Kol west doorstep should hand off without entering town")
    assert_equal(routes.active_route_id(),
        "tantegel_bridge_swamp_cave_staging",
        "the Kol bypass should activate the bridge-junction return")

    local bridge = assert(routes._route_for_tests(
        "tantegel_bridge_swamp_cave_staging"))
    for index = 2, #bridge.waypoints do
        local waypoint = bridge.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "the bridge junction should hand off without entering Tantegel")
    assert_equal(routes.active_route_id(),
        "garinham_swamp_cave_south",
        "the junction should activate the south-origin Garinham continuation")
    assert_equal(event.steps, nil,
        "the bridge handoff must not inject exterior movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "Garinham should remain selected after every handoff")

    local segment = assert(routes.plan_next_segment(0x01, 44, 38))
    assert_equal(segment.waypoint.name, "Bridge lower west lane",
        "the final continuation should use the established Garinham corridor")
    assert_equal(segment.path_length, 8,
        "the first Garinham segment should remain bounded")
    assert_equal(segment.steps[1], "up",
        "the Garinham continuation should leave the junction northward")

    routes.reset_for_tests()
    local alias_info, alias_err = routes.start(
        "garinham", 0x01, 104, 49)
    assert_equal(alias_err, nil,
        "Garinham alias should start outside Swamp Cave south")
    assert_equal(alias_info.route.id, "swamp_cave_south",
        "the alias should use the same connected itinerary")

    routes.reset_for_tests()
end

function tests.early_destinations_from_rimuldar_start_south_cave_return()
    local cases = {
        {
            target = {id = "overworld_brecconary", name = "Brecconary"},
            alias = "brecconary",
        },
        {
            target = {
                id = "overworld_erdrick_s_cave",
                name = "Erdrick's Cave",
            },
            alias = "erdrick",
        },
        {
            target = {id = "overworld_garinham", name = "Garinham"},
            alias = "garinham",
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        local info, err = routes.start_for_object(
            case.target, 0x01, 102, 72)

        assert_equal(err, nil,
            case.target.name .. " Travel should resolve outside Rimuldar")
        assert_equal(info.route.id, "swamp_cave_south",
            case.target.name .. " should first use the proven cave return")
        assert_equal(info.object_id, "route_swamp_cave_south_02",
            case.target.name .. " should first target Rimuldar's east doorstep")
        assert_contains(info.message,
            case.target.name .. " route starts from Swamp Cave South Entrance",
            "Rimuldar staging speech should retain " .. case.target.name)
        assert_equal(routes.active_route_matches_object(case.target), true,
            case.target.name .. " should remain selected on the southern leg")

        local segment = assert(routes.plan_next_segment(0x01, 102, 72))
        assert_equal(segment.waypoint.name, "Rimuldar east doorstep",
            case.target.name .. " should reuse the established town departure")
        assert_equal(segment.path_length, 1,
            case.target.name .. " should begin with the short safe east step")
        assert_equal(segment.steps[1], "right",
            case.target.name .. " should leave Rimuldar eastward")

        local swamp_return = assert(routes._route_for_tests(
            "swamp_cave_south"))
        local event
        for index = 2, #swamp_return.waypoints do
            local waypoint = swamp_return.waypoints[index]
            event = routes.observe_position(0x01, waypoint.x, waypoint.y)
        end
        assert_equal(event.status, "await_transition",
            case.target.name .. " should wait for automatic cave entry")
        assert_equal(routes.active_route_id(), "swamp_cave_south",
            case.target.name .. " must not advance before map 0x15")

        local cave_handoff = routes.observe_position(0x15, 0, 29)
        assert_equal(cave_handoff.status, "handoff",
            "cave entry should advance the " .. case.target.name .. " route")
        assert_equal(routes.active_route_id(), "kol_swamp_cave_staging",
            case.target.name .. " should resume on the proven north return")
        assert_equal(cave_handoff.steps, nil,
            case.target.name .. " must not inject cave movement")
        assert_equal(routes.active_route_matches_object(case.target), true,
            case.target.name .. " should stay selected through cave entry")

        routes.reset_for_tests()
        local alias_info, alias_err = routes.start(
            case.alias, 0x01, 102, 72)
        assert_equal(alias_err, nil,
            case.target.name .. " alias should resolve outside Rimuldar")
        assert_equal(alias_info.route.id, "swamp_cave_south",
            case.target.name .. " alias should use the same itinerary")
    end

    routes.reset_for_tests()
end

function tests.early_destinations_from_magic_temple_start_temple_return()
    local cases = {
        {
            target = {id = "overworld_brecconary", name = "Brecconary"},
            alias = "brecconary",
        },
        {
            target = {
                id = "overworld_erdrick_s_cave",
                name = "Erdrick's Cave",
            },
            alias = "erdrick",
        },
        {
            target = {id = "overworld_garinham", name = "Garinham"},
            alias = "garinham",
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        local info, err = routes.start_for_object(
            case.target, 0x01, 108, 109)

        assert_equal(err, nil,
            case.target.name .. " Travel should resolve outside Magic Temple")
        assert_equal(info.route.id, "rimuldar_magic_temple_staging",
            case.target.name .. " should first use the proven temple return")
        assert_equal(info.object_id,
            "route_rimuldar_magic_temple_staging_02",
            case.target.name .. " should leave the temple through its south opening")
        assert_contains(info.message,
            case.target.name .. " route starts from Rimuldar",
            "temple staging speech should retain " .. case.target.name)
        assert_equal(routes.active_route_matches_object(case.target), true,
            case.target.name .. " should remain selected on the temple return")

        local segment = assert(routes.plan_next_segment(0x01, 108, 109))
        assert_equal(segment.waypoint.name, "Temple inner east lane",
            case.target.name .. " should reuse the established temple departure")
        assert_equal(segment.path_length, 2,
            case.target.name .. " should begin with the short safe south segment")
        assert_equal(segment.steps[1], "down",
            case.target.name .. " should leave Magic Temple southward")

        routes.reset_for_tests()
        local alias_info, alias_err = routes.start(
            case.alias, 0x01, 108, 109)
        assert_equal(alias_err, nil,
            case.target.name .. " alias should resolve outside Magic Temple")
        assert_equal(alias_info.route.id, "rimuldar_magic_temple_staging",
            case.target.name .. " alias should use the same itinerary")
    end

    routes.reset_for_tests()
end

function tests.magic_temple_early_itinerary_hands_off_to_shared_cave_return()
    routes.reset_for_tests()
    local target = {
        id = "overworld_brecconary",
        name = "Brecconary",
    }
    assert(routes.start_for_object(target, 0x01, 108, 109))

    local temple_return = assert(routes._route_for_tests(
        "rimuldar_magic_temple_staging"))
    local event
    for index = 2, #temple_return.waypoints do
        local waypoint = temple_return.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    assert_equal(event.status, "handoff",
        "Rimuldar east doorstep should hand off without entering town")
    assert_equal(routes.active_route_id(),
        "swamp_cave_south_magic_temple",
        "the temple return should activate the established cave approach")
    assert_equal(event.object_id,
        "route_swamp_cave_south_magic_temple_03",
        "the cave approach should continue east from Rimuldar's doorstep")
    assert_contains(event.message, "Final destination: Brecconary",
        "the Rimuldar handoff should retain the selected destination")
    assert_equal(event.steps, nil,
        "the exterior Rimuldar handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "Brecconary should remain selected after the Rimuldar handoff")

    local cave_return = assert(routes._route_for_tests(
        "swamp_cave_south_magic_temple"))
    for index = 3, #cave_return.waypoints do
        local waypoint = cave_return.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "await_transition",
        "the south entrance should wait for automatic cave entry")
    assert_equal(routes.active_route_id(), "swamp_cave_south_magic_temple",
        "the itinerary must not advance before map 0x15 is observed")

    local cave_handoff = routes.observe_position(0x15, 0, 29)
    assert_equal(cave_handoff.status, "handoff",
        "cave entry should advance the Brecconary itinerary")
    assert_equal(routes.active_route_id(), "kol_swamp_cave_staging",
        "the cave handoff should reuse the proven north-exit return")
    assert_equal(cave_handoff.steps, nil,
        "the cave handoff must not inject interior movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "Brecconary should remain selected through cave entry")

    routes.reset_for_tests()
end

function tests.swamp_cave_north_early_variants_preserve_other_origins()
    local cases = {
        {
            target = {id = "overworld_garinham", name = "Garinham"},
            kol_route = "garinham_kol",
            direct_route = "garinham",
            south_route = "swamp_cave_south",
        },
        {
            target = {
                id = "overworld_erdrick_s_cave",
                name = "Erdrick's Cave",
            },
            kol_route = "erdrick_kol",
            direct_route = "erdrick",
            south_route = "swamp_cave_south",
        },
        {
            target = {id = "overworld_brecconary", name = "Brecconary"},
            kol_route = "brecconary_kol",
            direct_route = "brecconary",
            south_route = "swamp_cave_south",
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        local kol = assert(routes.start_for_object(
            case.target, 0x01, 104, 10))
        assert_equal(kol.route.id, "tantegel_bridge_staging",
            case.target.name .. " should retain its Kol-origin itinerary")

        routes.reset_for_tests()
        local northern = assert(routes.start_for_object(
            case.target, 0x01, 81, 1))
        assert_equal(northern.route.id, "kol_rain_shrine_staging",
            case.target.name .. " should retain its Northern Cave itinerary")

        routes.reset_for_tests()
        local southern = assert(routes.start_for_object(
            case.target, 0x01, 104, 49))
        assert_equal(southern.route.id, case.south_route,
            case.target.name .. " should keep its intended south-cave behavior")
    end

    routes.reset_for_tests()
end

function tests.northwestern_destinations_from_swamp_cave_north_start_kol_return()
    local cases = {
        {
            id = "overworld_northern_cave",
            name = "Northern Cave",
            alias = "northern cave",
        },
        {
            id = "overworld_hauksness",
            name = "Hauksness",
            alias = "hauksness",
        },
        {
            id = "overworld_mountain_cave",
            name = "Mountain Cave",
            alias = "mountain cave",
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        local info, err = routes.start_for_object(case, 0x01, 104, 44)

        assert_equal(err, nil,
            case.name .. " Travel should resolve outside Swamp Cave north")
        assert_equal(info.route.id, "kol_swamp_cave_staging",
            case.name .. " should first use the proven cave-to-Kol return")
        assert_equal(info.object_id, "route_kol_swamp_cave_staging_02",
            case.name .. " should first target the poison-swamp doorstep")
        assert_contains(info.message, case.name .. " route starts from Kol",
            "cave staging speech should retain " .. case.name)
        assert_equal(routes.active_route_matches_object(case), true,
            case.name .. " should remain selected during the Kol return")

        local segment = assert(routes.plan_next_segment(0x01, 104, 44))
        assert_equal(segment.waypoint.name, "Swamp Cave doorstep",
            case.name .. " should reuse the validated north-exit departure")
        assert_equal(segment.path_length, 1,
            case.name .. " should replace the synthetic seventeen-step start")
        assert_equal(segment.steps[1], "up",
            case.name .. " should leave Swamp Cave northward")

        routes.reset_for_tests()
        local alias_info, alias_err = routes.start(
            case.alias, 0x01, 104, 44)
        assert_equal(alias_err, nil,
            case.name .. " alias should resolve outside Swamp Cave north")
        assert_equal(alias_info.route.id, "kol_swamp_cave_staging",
            case.name .. " alias should use the same connected itinerary")
    end

    routes.reset_for_tests()
end

function tests.northwestern_destinations_from_swamp_cave_south_cross_cave_first()
    local cases = {
        {
            id = "overworld_northern_cave",
            name = "Northern Cave",
            alias = "northern cave",
        },
        {
            id = "overworld_hauksness",
            name = "Hauksness",
            alias = "hauksness",
        },
        {
            id = "overworld_mountain_cave",
            name = "Mountain Cave",
            alias = "mountain cave",
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        local info, err = routes.start_for_object(case, 0x01, 104, 49)

        assert_equal(err, nil,
            case.name .. " Travel should resolve outside Swamp Cave south")
        assert_equal(info.route.id, "swamp_cave_south",
            case.name .. " should first wait for automatic cave entry")
        assert_equal(info.object_id, "route_swamp_cave_south_34",
            case.name .. " should target the adjacent south entrance")
        assert_contains(info.message,
            case.name .. " route starts from Swamp Cave South Entrance",
            "south-cave staging speech should retain " .. case.name)
        assert_equal(routes.active_route_matches_object(case), true,
            case.name .. " should remain selected before cave traversal")

        local wait_event = routes.observe_position(0x01, 104, 49)
        assert_equal(wait_event.status, "await_transition",
            case.name .. " should wait on the automatic-entry tile")
        assert_equal(routes.active_route_id(), "swamp_cave_south",
            case.name .. " must not advance before map 0x15 is observed")

        local wait_segment = assert(routes.plan_next_segment(
            0x01, 104, 49, {advance_if_at_waypoint = true}))
        assert_equal(wait_segment.status, "already_at_waypoint",
            case.name .. " autowalk should remain on the cave entrance")
        assert_equal(#wait_segment.steps, 0,
            case.name .. " must not synthesize movement through the cave")

        local cave_handoff = routes.observe_position(0x15, 0, 29)
        assert_equal(cave_handoff.status, "handoff",
            "entering Swamp Cave should advance the " .. case.name .. " itinerary")
        assert_equal(routes.active_route_id(), "kol_swamp_cave_staging",
            case.name .. " should wait for the established north-exit return")
        assert_equal(cave_handoff.object_id,
            "route_kol_swamp_cave_staging_01",
            case.name .. " should wait for the north exterior landing")
        assert_equal(cave_handoff.steps, nil,
            case.name .. " cave handoff must not inject interior movement")
        assert_equal(routes.active_route_matches_object(case), true,
            case.name .. " should remain selected during cave traversal")

        local north_exit = routes.observe_position(0x01, 104, 44)
        assert_equal(north_exit.object_id,
            "route_kol_swamp_cave_staging_02",
            case.name .. " should advance to the poison-swamp doorstep")

        local segment = assert(routes.plan_next_segment(0x01, 104, 44))
        assert_equal(segment.waypoint.name, "Swamp Cave doorstep",
            case.name .. " should reuse the validated north-exit departure")
        assert_equal(segment.path_length, 1,
            case.name .. " should leave the cave through the short safe leg")
        assert_equal(segment.steps[1], "up",
            case.name .. " should leave Swamp Cave northward")

        routes.reset_for_tests()
        local alias_info, alias_err = routes.start(
            case.alias, 0x01, 104, 49)
        assert_equal(alias_err, nil,
            case.name .. " alias should resolve outside Swamp Cave south")
        assert_equal(alias_info.route.id, "swamp_cave_south",
            case.name .. " alias should use the same connected itinerary")
    end

    routes.reset_for_tests()
end

function tests.northwestern_destinations_from_rimuldar_start_south_cave_return()
    local cases = {
        {
            id = "overworld_northern_cave",
            name = "Northern Cave",
            alias = "northern cave",
        },
        {
            id = "overworld_hauksness",
            name = "Hauksness",
            alias = "hauksness",
        },
        {
            id = "overworld_mountain_cave",
            name = "Mountain Cave",
            alias = "mountain cave",
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        local info, err = routes.start_for_object(case, 0x01, 102, 72)

        assert_equal(err, nil,
            case.name .. " Travel should resolve outside Rimuldar")
        assert_equal(info.route.id, "swamp_cave_south",
            case.name .. " should first use the proven cave return")
        assert_equal(info.object_id, "route_swamp_cave_south_02",
            case.name .. " should first target Rimuldar's east doorstep")
        assert_contains(info.message,
            case.name .. " route starts from Swamp Cave South Entrance",
            "Rimuldar staging speech should retain " .. case.name)
        assert_equal(routes.active_route_matches_object(case), true,
            case.name .. " should remain selected on the southern leg")

        local segment = assert(routes.plan_next_segment(0x01, 102, 72))
        assert_equal(segment.waypoint.name, "Rimuldar east doorstep",
            case.name .. " should reuse the established town departure")
        assert_equal(segment.path_length, 1,
            case.name .. " should begin with the short safe east step")
        assert_equal(segment.steps[1], "right",
            case.name .. " should leave Rimuldar eastward")

        local swamp_return = assert(routes._route_for_tests(
            "swamp_cave_south"))
        local event
        for index = 2, #swamp_return.waypoints do
            local waypoint = swamp_return.waypoints[index]
            event = routes.observe_position(0x01, waypoint.x, waypoint.y)
        end
        assert_equal(event.status, "await_transition",
            case.name .. " should wait for automatic cave entry")
        assert_equal(routes.active_route_id(), "swamp_cave_south",
            case.name .. " must not advance before map 0x15")

        local cave_handoff = routes.observe_position(0x15, 0, 29)
        assert_equal(cave_handoff.status, "handoff",
            "cave entry should advance the " .. case.name .. " itinerary")
        assert_equal(routes.active_route_id(), "kol_swamp_cave_staging",
            case.name .. " should resume on the proven north return")
        assert_equal(cave_handoff.steps, nil,
            case.name .. " must not inject cave movement")
        assert_equal(routes.active_route_matches_object(case), true,
            case.name .. " should stay selected through cave entry")

        routes.reset_for_tests()
        local alias_info, alias_err = routes.start(
            case.alias, 0x01, 102, 72)
        assert_equal(alias_err, nil,
            case.name .. " alias should resolve outside Rimuldar")
        assert_equal(alias_info.route.id, "swamp_cave_south",
            case.name .. " alias should use the same itinerary")
    end

    routes.reset_for_tests()
end

function tests.northwestern_destinations_from_magic_temple_start_temple_return()
    local cases = {
        {
            id = "overworld_northern_cave",
            name = "Northern Cave",
            alias = "northern cave",
        },
        {
            id = "overworld_hauksness",
            name = "Hauksness",
            alias = "hauksness",
        },
        {
            id = "overworld_mountain_cave",
            name = "Mountain Cave",
            alias = "mountain cave",
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        local info, err = routes.start_for_object(case, 0x01, 108, 109)

        assert_equal(err, nil,
            case.name .. " Travel should resolve outside Magic Temple")
        assert_equal(info.route.id, "rimuldar_magic_temple_staging",
            case.name .. " should first use the proven temple return")
        assert_equal(info.object_id,
            "route_rimuldar_magic_temple_staging_02",
            case.name .. " should leave the temple through its south opening")
        assert_contains(info.message, case.name .. " route starts from Rimuldar",
            "temple staging speech should retain " .. case.name)
        assert_equal(routes.active_route_matches_object(case), true,
            case.name .. " should remain selected on the temple return")

        local segment = assert(routes.plan_next_segment(0x01, 108, 109))
        assert_equal(segment.waypoint.name, "Temple inner east lane",
            case.name .. " should reuse the established temple departure")
        assert_equal(segment.path_length, 2,
            case.name .. " should begin with the short safe south segment")
        assert_equal(segment.steps[1], "down",
            case.name .. " should leave Magic Temple southward")

        routes.reset_for_tests()
        local alias_info, alias_err = routes.start(
            case.alias, 0x01, 108, 109)
        assert_equal(alias_err, nil,
            case.name .. " alias should resolve outside Magic Temple")
        assert_equal(alias_info.route.id, "rimuldar_magic_temple_staging",
            case.name .. " alias should use the same connected itinerary")
    end

    routes.reset_for_tests()
end

function tests.swamp_cave_south_northwestern_routes_handoff_outside_kol()
    local cases = {
        {
            target = {id = "overworld_northern_cave", name = "Northern Cave"},
            route_id = "northern_cave_swamp_cave_south",
        },
        {
            target = {id = "overworld_hauksness", name = "Hauksness"},
            route_id = "hauksness_swamp_cave_south",
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        assert(routes.start_for_object(case.target, 0x01, 104, 49))
        routes.observe_position(0x15, 0, 29)
        routes.observe_position(0x01, 104, 44)

        local kol = assert(routes._route_for_tests(
            "kol_swamp_cave_staging"))
        local event
        for index = 2, #kol.waypoints do
            local waypoint = kol.waypoints[index]
            event = routes.observe_position(0x01, waypoint.x, waypoint.y)
        end

        assert_equal(event.status, "handoff",
            case.target.name .. " should hand off outside Kol")
        assert_equal(routes.active_route_id(), case.route_id,
            case.target.name .. " should activate its south-origin continuation")
        assert_equal(event.object_id, "route_" .. case.route_id .. "_02",
            case.target.name .. " should leave Kol through the forest edge")
        assert_equal(event.steps, nil,
            "the exterior Kol handoff must not inject movement")
        assert_equal(routes.active_route_matches_object(case.target), true,
            case.target.name .. " should remain selected after the handoff")

        local segment = assert(routes.plan_next_segment(0x01, 103, 10))
        assert_equal(segment.waypoint.name, "Kol forest west edge",
            case.target.name .. " should continue on its proven route")
        assert_equal(segment.steps[1], "left",
            case.target.name .. " should bypass Kol westward")
    end

    routes.reset_for_tests()
    local mountain = {
        id = "overworld_mountain_cave",
        name = "Mountain Cave",
    }
    assert(routes.start_for_object(mountain, 0x01, 104, 49))
    routes.observe_position(0x15, 0, 29)
    routes.observe_position(0x01, 104, 44)

    local kol = assert(routes._route_for_tests("kol_swamp_cave_staging"))
    local event
    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "Mountain Cave should first hand off outside Kol")
    assert_equal(routes.active_route_id(),
        "mountain_cave_swamp_cave_north_connector",
        "Mountain Cave should reuse the proven western connector")

    local connector = assert(routes._route_for_tests(
        "mountain_cave_swamp_cave_north_connector"))
    for index = 2, #connector.waypoints do
        local waypoint = connector.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "the western-desert pin should hand off to the cave spur")
    assert_equal(routes.active_route_id(),
        "mountain_cave_swamp_cave_south",
        "the connector should activate the south-origin Mountain Cave route")
    assert_equal(event.object_id,
        "route_mountain_cave_swamp_cave_south_02",
        "the cave continuation should leave the shared pin westward")
    assert_equal(event.steps, nil,
        "the western-desert handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(mountain), true,
        "Mountain Cave should remain selected through every handoff")

    routes.reset_for_tests()
end

function tests.swamp_cave_north_northwestern_routes_handoff_outside_kol()
    local cases = {
        {
            target = {id = "overworld_northern_cave", name = "Northern Cave"},
            route_id = "northern_cave_swamp_cave_north",
        },
        {
            target = {id = "overworld_hauksness", name = "Hauksness"},
            route_id = "hauksness_swamp_cave_north",
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        assert(routes.start_for_object(case.target, 0x01, 104, 44))

        local kol = assert(routes._route_for_tests(
            "kol_swamp_cave_staging"))
        local event
        for index = 2, #kol.waypoints do
            local waypoint = kol.waypoints[index]
            event = routes.observe_position(0x01, waypoint.x, waypoint.y)
        end

        assert_equal(event.status, "handoff",
            case.target.name .. " should hand off outside Kol")
        assert_equal(routes.active_route_id(), case.route_id,
            case.target.name .. " should activate its Kol-bypass continuation")
        assert_equal(event.object_id, "route_" .. case.route_id .. "_02",
            case.target.name .. " should leave Kol through the forest edge")
        assert_equal(event.steps, nil,
            "the exterior Kol handoff must not inject movement")
        assert_equal(routes.active_route_matches_object(case.target), true,
            case.target.name .. " should remain selected after the handoff")

        local segment = assert(routes.plan_next_segment(0x01, 103, 10))
        assert_equal(segment.waypoint.name, "Kol forest west edge",
            case.target.name .. " should continue on its proven route")
        assert_equal(segment.steps[1], "left",
            case.target.name .. " should bypass Kol westward")
    end

    routes.reset_for_tests()
    local mountain = {
        id = "overworld_mountain_cave",
        name = "Mountain Cave",
    }
    assert(routes.start_for_object(mountain, 0x01, 104, 44))

    local kol = assert(routes._route_for_tests("kol_swamp_cave_staging"))
    local event
    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "Mountain Cave should first hand off outside Kol")
    assert_equal(routes.active_route_id(),
        "mountain_cave_swamp_cave_north_connector",
        "Mountain Cave should activate the western connector")
    assert_equal(event.object_id,
        "route_mountain_cave_swamp_cave_north_connector_02",
        "the connector should leave Kol through the forest edge")

    local connector = assert(routes._route_for_tests(
        "mountain_cave_swamp_cave_north_connector"))
    for index = 2, #connector.waypoints do
        local waypoint = connector.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "the western-desert pin should hand off to the cave spur")
    assert_equal(routes.active_route_id(),
        "mountain_cave_swamp_cave_north",
        "the connector should activate the Mountain Cave continuation")
    assert_equal(event.object_id,
        "route_mountain_cave_swamp_cave_north_02",
        "the cave continuation should leave the shared route pin westward")
    assert_equal(event.steps, nil,
        "the western-desert handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(mountain), true,
        "Mountain Cave should remain selected through both handoffs")

    local segment = assert(routes.plan_next_segment(0x01, 18, 64))
    assert_equal(segment.waypoint.name, "Mountain Cave forest turn",
        "the final continuation should reuse the proven cave spur")
    assert_equal(segment.steps[1], "left",
        "the cave spur should leave the shared pin westward")

    routes.reset_for_tests()
end

function tests.swamp_cave_north_northwestern_variants_do_not_steal_other_origins()
    local cases = {
        {
            target = {id = "overworld_northern_cave", name = "Northern Cave"},
            kol_route = "northern_cave",
            south_route = "swamp_cave_south",
        },
        {
            target = {id = "overworld_hauksness", name = "Hauksness"},
            kol_route = "hauksness",
            south_route = "swamp_cave_south",
        },
        {
            target = {id = "overworld_mountain_cave", name = "Mountain Cave"},
            kol_route = "mountain_cave_connector",
            south_route = "swamp_cave_south",
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        local kol = assert(routes.start_for_object(
            case.target, 0x01, 104, 10))
        assert_equal(kol.route.id, case.kol_route,
            case.target.name .. " should retain its Kol-origin itinerary")

        routes.reset_for_tests()
        local southern = assert(routes.start_for_object(
            case.target, 0x01, 104, 49))
        assert_equal(southern.route.id, case.south_route,
            case.target.name .. " south-cave travel should remain unchanged")
    end

    routes.reset_for_tests()
end

function tests.southern_destinations_from_swamp_cave_north_start_kol_return()
    local cases = {
        {
            id = "overworld_cantlin",
            name = "Cantlin",
            alias = "cantlin",
        },
        {
            id = "overworld_eastern_great_swamp_search_area",
            name = "Eastern Great Swamp Search Area",
            alias = "great swamp search area",
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        local info, err = routes.start_for_object(case, 0x01, 104, 44)

        assert_equal(err, nil,
            case.name .. " Travel should resolve outside Swamp Cave north")
        assert_equal(info.route.id, "kol_swamp_cave_staging",
            case.name .. " should first use the proven cave-to-Kol return")
        assert_equal(info.object_id, "route_kol_swamp_cave_staging_02",
            case.name .. " should first target the poison-swamp doorstep")
        assert_contains(info.message, case.name .. " route starts from Kol",
            "cave staging speech should retain " .. case.name)
        assert_equal(routes.active_route_matches_object(case), true,
            case.name .. " should remain selected during the Kol return")

        local segment = assert(routes.plan_next_segment(0x01, 104, 44))
        assert_equal(segment.waypoint.name, "Swamp Cave doorstep",
            case.name .. " should reuse the validated north-exit departure")
        assert_equal(segment.path_length, 1,
            case.name .. " should replace the synthetic seventeen-step start")
        assert_equal(segment.steps[1], "up",
            case.name .. " should leave Swamp Cave northward")

        routes.reset_for_tests()
        local alias_info, alias_err = routes.start(
            case.alias, 0x01, 104, 44)
        assert_equal(alias_err, nil,
            case.name .. " alias should resolve outside Swamp Cave north")
        assert_equal(alias_info.route.id, "kol_swamp_cave_staging",
            case.name .. " alias should use the same connected itinerary")
    end

    routes.reset_for_tests()
end

function tests.southern_destinations_from_swamp_cave_south_cross_cave_first()
    local cases = {
        {
            id = "overworld_cantlin",
            name = "Cantlin",
            alias = "cantlin",
        },
        {
            id = "overworld_eastern_great_swamp_search_area",
            name = "Eastern Great Swamp Search Area",
            alias = "great swamp search area",
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        local info, err = routes.start_for_object(case, 0x01, 104, 49)

        assert_equal(err, nil,
            case.name .. " Travel should resolve outside Swamp Cave south")
        assert_equal(info.route.id, "swamp_cave_south",
            case.name .. " should first wait for automatic cave entry")
        assert_equal(info.object_id, "route_swamp_cave_south_34",
            case.name .. " should target the adjacent south entrance")
        assert_contains(info.message,
            case.name .. " route starts from Swamp Cave South Entrance",
            "south-cave staging speech should retain " .. case.name)
        assert_equal(routes.active_route_matches_object(case), true,
            case.name .. " should remain selected before cave traversal")

        local wait_event = routes.observe_position(0x01, 104, 49)
        assert_equal(wait_event.status, "await_transition",
            case.name .. " should wait on the automatic-entry tile")
        assert_equal(routes.active_route_id(), "swamp_cave_south",
            case.name .. " must not advance before map 0x15 is observed")

        local wait_segment = assert(routes.plan_next_segment(
            0x01, 104, 49, {advance_if_at_waypoint = true}))
        assert_equal(wait_segment.status, "already_at_waypoint",
            case.name .. " autowalk should remain on the cave entrance")
        assert_equal(#wait_segment.steps, 0,
            case.name .. " must not synthesize movement through the cave")

        local cave_handoff = routes.observe_position(0x15, 0, 29)
        assert_equal(cave_handoff.status, "handoff",
            "entering Swamp Cave should advance the " .. case.name .. " itinerary")
        assert_equal(routes.active_route_id(), "kol_swamp_cave_staging",
            case.name .. " should wait for the established north-exit return")
        assert_equal(cave_handoff.object_id,
            "route_kol_swamp_cave_staging_01",
            case.name .. " should wait for the north exterior landing")
        assert_equal(cave_handoff.steps, nil,
            case.name .. " cave handoff must not inject interior movement")
        assert_equal(routes.active_route_matches_object(case), true,
            case.name .. " should remain selected during cave traversal")

        local north_exit = routes.observe_position(0x01, 104, 44)
        assert_equal(north_exit.object_id,
            "route_kol_swamp_cave_staging_02",
            case.name .. " should advance to the poison-swamp doorstep")

        local segment = assert(routes.plan_next_segment(0x01, 104, 44))
        assert_equal(segment.waypoint.name, "Swamp Cave doorstep",
            case.name .. " should reuse the validated north-exit departure")
        assert_equal(segment.path_length, 1,
            case.name .. " should leave the cave through the short safe leg")
        assert_equal(segment.steps[1], "up",
            case.name .. " should leave Swamp Cave northward")

        routes.reset_for_tests()
        local alias_info, alias_err = routes.start(
            case.alias, 0x01, 104, 49)
        assert_equal(alias_err, nil,
            case.name .. " alias should resolve outside Swamp Cave south")
        assert_equal(alias_info.route.id, "swamp_cave_south",
            case.name .. " alias should use the same connected itinerary")
    end

    routes.reset_for_tests()
end

function tests.southern_destinations_from_rimuldar_start_south_cave_return()
    local cases = {
        {
            id = "overworld_cantlin",
            name = "Cantlin",
            alias = "cantlin",
        },
        {
            id = "overworld_eastern_great_swamp_search_area",
            name = "Eastern Great Swamp Search Area",
            alias = "great swamp search area",
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        local info, err = routes.start_for_object(case, 0x01, 102, 72)

        assert_equal(err, nil,
            case.name .. " Travel should resolve outside Rimuldar")
        assert_equal(info.route.id, "swamp_cave_south",
            case.name .. " should first use the proven cave return")
        assert_equal(info.object_id, "route_swamp_cave_south_02",
            case.name .. " should first target Rimuldar's east doorstep")
        assert_contains(info.message,
            case.name .. " route starts from Swamp Cave South Entrance",
            "Rimuldar staging speech should retain " .. case.name)
        assert_equal(routes.active_route_matches_object(case), true,
            case.name .. " should remain selected on the southern leg")

        local segment = assert(routes.plan_next_segment(0x01, 102, 72))
        assert_equal(segment.waypoint.name, "Rimuldar east doorstep",
            case.name .. " should reuse the established town departure")
        assert_equal(segment.path_length, 1,
            case.name .. " should begin with the short safe east step")
        assert_equal(segment.steps[1], "right",
            case.name .. " should leave Rimuldar eastward")

        local swamp_return = assert(routes._route_for_tests(
            "swamp_cave_south"))
        local event
        for index = 2, #swamp_return.waypoints do
            local waypoint = swamp_return.waypoints[index]
            event = routes.observe_position(0x01, waypoint.x, waypoint.y)
        end
        assert_equal(event.status, "await_transition",
            case.name .. " should wait for automatic cave entry")
        assert_equal(routes.active_route_id(), "swamp_cave_south",
            case.name .. " must not advance before map 0x15")

        local cave_handoff = routes.observe_position(0x15, 0, 29)
        assert_equal(cave_handoff.status, "handoff",
            "cave entry should advance the " .. case.name .. " itinerary")
        assert_equal(routes.active_route_id(), "kol_swamp_cave_staging",
            case.name .. " should resume on the proven north return")
        assert_equal(cave_handoff.steps, nil,
            case.name .. " must not inject cave movement")
        assert_equal(routes.active_route_matches_object(case), true,
            case.name .. " should stay selected through cave entry")

        routes.reset_for_tests()
        local alias_info, alias_err = routes.start(
            case.alias, 0x01, 102, 72)
        assert_equal(alias_err, nil,
            case.name .. " alias should resolve outside Rimuldar")
        assert_equal(alias_info.route.id, "swamp_cave_south",
            case.name .. " alias should use the same itinerary")
    end

    routes.reset_for_tests()
end

function tests.kol_from_rimuldar_crosses_swamp_cave_before_north_route()
    routes.reset_for_tests()
    local target = {
        id = "overworld_kol",
        name = "Kol",
        x = 104,
        y = 10,
    }

    local info, err = routes.start_for_object(target, 0x01, 102, 72)

    assert_equal(err, nil, "Kol Travel should resolve outside Rimuldar")
    assert_equal(info.route.id, "swamp_cave_south",
        "Kol should first use the proven south-cave return")
    assert_equal(info.object_id, "route_swamp_cave_south_02",
        "Kol should first target Rimuldar's east doorstep")
    assert_contains(info.message, "Kol route starts from Swamp Cave South Entrance",
        "staging speech should retain Kol as the final destination")
    assert_equal(routes.active_route_matches_object(target), true,
        "Kol should remain selected on the southern leg")

    local cave_handoff = routes.observe_position(0x15, 0, 29)
    assert_equal(cave_handoff.status, "handoff",
        "south-cave entry should advance the Kol itinerary")
    assert_equal(routes.active_route_id(), "kol_swamp_cave_south",
        "cave entry should activate the direct north-exit-to-Kol route")
    assert_equal(cave_handoff.object_id,
        "route_kol_swamp_cave_south_01",
        "the Kol itinerary should wait for the north exterior landing")
    assert_equal(cave_handoff.steps, nil,
        "the Kol itinerary must not inject cave movement")

    local north_exit = routes.observe_position(0x01, 104, 44)
    assert_contains(north_exit.message, "Reached Swamp Cave",
        "the Kol route should resume after the north exit")
    assert_equal(routes.active_route_matches_object(target), true,
        "Kol should remain selected after crossing the cave")

    local arrival = routes.observe_position(0x07, 15, 14)
    assert_contains(arrival.message, "Arrived at Kol",
        "entering Kol should complete the connected itinerary")
    assert_equal(routes.is_active(), false,
        "the connected Kol route should clear on arrival")

    routes.reset_for_tests()
end

function tests.swamp_cave_north_from_rimuldar_waits_for_manual_crossing()
    routes.reset_for_tests()
    local target = {
        id = "overworld_swamp_cave",
        name = "Swamp Cave",
        x = 104,
        y = 44,
    }

    local info, err = routes.start_for_object(target, 0x01, 102, 72)

    assert_equal(err, nil,
        "Swamp Cave north Travel should resolve outside Rimuldar")
    assert_equal(info.route.id, "swamp_cave_south",
        "north-cave travel should first use the proven south entrance route")
    assert_equal(info.object_id, "route_swamp_cave_south_02",
        "north-cave travel should first leave Rimuldar eastward")
    assert_contains(info.message, "Swamp Cave North Entrance route starts from Swamp Cave South Entrance",
        "staging speech should distinguish the requested north entrance")
    assert_equal(routes.active_route_matches_object(target), true,
        "the north entrance should remain selected on the southern leg")

    local cave_handoff = routes.observe_position(0x15, 0, 29)
    assert_equal(cave_handoff.status, "handoff",
        "south-cave entry should advance the north-entrance itinerary")
    assert_equal(routes.active_route_id(),
        "swamp_cave_north_swamp_cave_south",
        "the route should wait for the north exterior landing")
    assert_equal(cave_handoff.object_id,
        "route_swamp_cave_north_swamp_cave_south_01",
        "the cave handoff should expose the north entrance waypoint")
    assert_equal(cave_handoff.steps, nil,
        "the north-entrance itinerary must not inject cave movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "the north entrance should remain selected inside the cave")

    local arrival = routes.observe_position(0x01, 104, 44)
    assert_contains(arrival.message, "Arrived at Swamp Cave North Entrance",
        "emerging north should complete the route")
    assert_equal(routes.is_active(), false,
        "the north-entrance route should clear after emergence")

    routes.reset_for_tests()
end

function tests.northern_access_from_magic_temple_uses_temple_and_cave_returns()
    local cases = {
        {
            target = {id = "overworld_kol", name = "Kol"},
            alias = "kol",
            cave_route = "kol_swamp_cave_south",
        },
        {
            target = {
                id = "overworld_swamp_cave",
                name = "Swamp Cave North Entrance",
            },
            alias = "swamp cave",
            cave_route = "swamp_cave_north_swamp_cave_south",
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        local info, err = routes.start_for_object(
            case.target, 0x01, 108, 109)

        assert_equal(err, nil,
            case.target.name .. " Travel should resolve outside Magic Temple")
        assert_equal(info.route.id, "rimuldar_magic_temple_staging",
            case.target.name .. " should first use the proven temple return")
        assert_equal(info.object_id,
            "route_rimuldar_magic_temple_staging_02",
            case.target.name .. " should leave through the temple's south opening")
        assert_contains(info.message,
            case.target.name .. " route starts from Rimuldar",
            "temple staging speech should retain " .. case.target.name)
        assert_equal(routes.active_route_matches_object(case.target), true,
            case.target.name .. " should remain selected on the temple return")

        local segment = assert(routes.plan_next_segment(0x01, 108, 109))
        assert_equal(segment.waypoint.name, "Temple inner east lane",
            case.target.name .. " should reuse the established departure")
        assert_equal(segment.path_length, 2,
            case.target.name .. " should begin with the short safe segment")
        assert_equal(segment.steps[1], "down",
            case.target.name .. " should leave Magic Temple southward")

        local temple_return = assert(routes._route_for_tests(
            "rimuldar_magic_temple_staging"))
        local event
        for index = 2, #temple_return.waypoints do
            local waypoint = temple_return.waypoints[index]
            event = routes.observe_position(0x01, waypoint.x, waypoint.y)
        end
        assert_equal(event.status, "handoff",
            case.target.name .. " should hand off outside Rimuldar")
        assert_equal(routes.active_route_id(),
            "swamp_cave_south_magic_temple",
            case.target.name .. " should activate the proven cave approach")
        assert_equal(event.steps, nil,
            "the Rimuldar handoff must not inject movement")

        local cave_return = assert(routes._route_for_tests(
            "swamp_cave_south_magic_temple"))
        for index = 3, #cave_return.waypoints do
            local waypoint = cave_return.waypoints[index]
            event = routes.observe_position(0x01, waypoint.x, waypoint.y)
        end
        assert_equal(event.status, "await_transition",
            case.target.name .. " should wait for automatic cave entry")

        local cave_handoff = routes.observe_position(0x15, 0, 29)
        assert_equal(cave_handoff.status, "handoff",
            "cave entry should advance the " .. case.target.name .. " route")
        assert_equal(routes.active_route_id(), case.cave_route,
            case.target.name .. " should activate its north-exit route")
        assert_equal(cave_handoff.object_id,
            "route_" .. case.cave_route .. "_01",
            case.target.name .. " should wait for the north exterior landing")
        assert_equal(cave_handoff.steps, nil,
            case.target.name .. " must not inject cave movement")
        assert_equal(routes.active_route_matches_object(case.target), true,
            case.target.name .. " should remain selected inside the cave")

        routes.reset_for_tests()
        local alias_info, alias_err = routes.start(
            case.alias, 0x01, 108, 109)
        assert_equal(alias_err, nil,
            case.target.name .. " alias should resolve outside Magic Temple")
        assert_equal(alias_info.route.id, "rimuldar_magic_temple_staging",
            case.target.name .. " alias should use the same itinerary")
    end

    routes.reset_for_tests()
end

function tests.rimuldar_local_cave_variants_do_not_steal_north_exit_starts()
    routes.reset_for_tests()

    local kol = assert(routes.start_for_object({
        id = "overworld_kol",
        name = "Kol",
        x = 104,
        y = 10,
    }, 0x01, 104, 44))
    assert_equal(kol.route.id, "kol_swamp_cave",
        "Kol should retain its direct north-exit route")

    routes.reset_for_tests()
    local cave = assert(routes.start_for_object({
        id = "overworld_swamp_cave",
        name = "Swamp Cave",
        x = 104,
        y = 44,
    }, 0x01, 104, 43))
    assert_equal(cave.route.id, "swamp_cave_bridge",
        "nearby north-cave travel should retain its existing bridge variant")

    routes.reset_for_tests()
end

function tests.swamp_cave_south_southern_routes_handoff_outside_towns()
    local cantlin = {
        id = "overworld_cantlin",
        name = "Cantlin",
    }
    routes.reset_for_tests()
    assert(routes.start_for_object(cantlin, 0x01, 104, 49))
    routes.observe_position(0x15, 0, 29)
    routes.observe_position(0x01, 104, 44)

    local kol = assert(routes._route_for_tests("kol_swamp_cave_staging"))
    local event
    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "Cantlin travel should hand off outside Kol")
    assert_equal(routes.active_route_id(),
        "hauksness_swamp_cave_north_staging",
        "Kol should activate the non-entry Hauksness leg")
    assert_equal(event.steps, nil,
        "the exterior Kol handoff must not inject movement")

    local hauksness = assert(routes._route_for_tests(
        "hauksness_swamp_cave_north_staging"))
    for index = 2, #hauksness.waypoints do
        local waypoint = hauksness.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "Cantlin travel should hand off outside Hauksness")
    assert_equal(routes.active_route_id(), "cantlin_swamp_cave_south",
        "Hauksness should activate the south-origin Cantlin leg")
    assert_equal(event.object_id, "route_cantlin_swamp_cave_south_03",
        "the Cantlin leg should continue west of Hauksness")
    assert_equal(event.steps, nil,
        "the exterior Hauksness handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(cantlin), true,
        "Cantlin should remain selected after every exterior handoff")

    local segment = assert(routes.plan_next_segment(0x01, 24, 89))
    assert_equal(segment.waypoint.name, "Hauksness west approach",
        "the final Cantlin leg should leave the ruins westward")
    assert_equal(segment.steps[1], "left",
        "the final Cantlin leg should bypass Hauksness")

    routes.reset_for_tests()
    local great_swamp = {
        id = "overworld_eastern_great_swamp_search_area",
        name = "Eastern Great Swamp Search Area",
    }
    assert(routes.start_for_object(great_swamp, 0x01, 104, 49))
    routes.observe_position(0x15, 0, 29)
    routes.observe_position(0x01, 104, 44)

    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    for index = 2, #hauksness.waypoints do
        local waypoint = hauksness.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "Great Swamp travel should hand off outside Hauksness")
    assert_equal(routes.active_route_id(),
        "cantlin_swamp_cave_north_staging",
        "Hauksness should activate the non-entry Cantlin leg")

    local cantlin_staging = assert(routes._route_for_tests(
        "cantlin_swamp_cave_north_staging"))
    for index = 3, #cantlin_staging.waypoints do
        local waypoint = cantlin_staging.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "Great Swamp travel should hand off northwest of Cantlin")
    assert_equal(routes.active_route_id(),
        "great_swamp_swamp_cave_south",
        "the Cantlin bypass should activate the south-origin Great Swamp leg")
    assert_equal(event.object_id,
        "route_great_swamp_swamp_cave_south_04",
        "the Great Swamp leg should descend from the shared turn")
    assert_equal(event.steps, nil,
        "the exterior Cantlin handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(great_swamp), true,
        "Great Swamp should remain selected after every exterior handoff")

    segment = assert(routes.plan_next_segment(0x01, 68, 91))
    assert_equal(segment.waypoint.name, "Upper forest south notch",
        "the final Great Swamp leg should reuse the validated departure")
    assert_equal(segment.steps[1], "down",
        "the Great Swamp continuation should leave Cantlin southward")

    routes.reset_for_tests()
end

function tests.swamp_cave_north_southern_routes_handoff_outside_towns()
    local cantlin = {
        id = "overworld_cantlin",
        name = "Cantlin",
    }
    routes.reset_for_tests()
    assert(routes.start_for_object(cantlin, 0x01, 104, 44))

    local kol = assert(routes._route_for_tests("kol_swamp_cave_staging"))
    local event
    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "Cantlin travel should hand off outside Kol")
    assert_equal(routes.active_route_id(),
        "hauksness_swamp_cave_north_staging",
        "Kol should activate the non-entry Hauksness leg")
    assert_equal(event.object_id,
        "route_hauksness_swamp_cave_north_staging_02",
        "the Hauksness leg should leave Kol through the forest edge")
    assert_equal(event.steps, nil,
        "the exterior Kol handoff must not inject movement")

    local hauksness = assert(routes._route_for_tests(
        "hauksness_swamp_cave_north_staging"))
    for index = 2, #hauksness.waypoints do
        local waypoint = hauksness.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "Cantlin travel should hand off outside Hauksness")
    assert_equal(routes.active_route_id(), "cantlin_swamp_cave_north",
        "Hauksness should activate the final Cantlin leg")
    assert_equal(event.object_id, "route_cantlin_swamp_cave_north_03",
        "the Cantlin leg should continue west of Hauksness")
    assert_equal(event.steps, nil,
        "the exterior Hauksness handoff must not inject movement")
    assert_equal(hauksness.waypoints[#hauksness.waypoints].x, 24,
        "the connected Hauksness leg should stop west of the ruins")
    assert_equal(hauksness.waypoints[#hauksness.waypoints].y, 89,
        "the connected Hauksness staging row")
    assert_equal(routes.active_route_matches_object(cantlin), true,
        "Cantlin should remain selected after both exterior handoffs")

    local segment = assert(routes.plan_next_segment(0x01, 24, 89))
    assert_equal(segment.waypoint.name, "Hauksness west approach",
        "the final Cantlin leg should leave the ruins westward")
    assert_equal(segment.steps[1], "left",
        "the final Cantlin leg should bypass Hauksness")

    routes.reset_for_tests()
    local great_swamp = {
        id = "overworld_eastern_great_swamp_search_area",
        name = "Eastern Great Swamp Search Area",
    }
    assert(routes.start_for_object(great_swamp, 0x01, 104, 44))

    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    for index = 2, #hauksness.waypoints do
        local waypoint = hauksness.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "Great Swamp travel should hand off outside Hauksness")
    assert_equal(routes.active_route_id(),
        "cantlin_swamp_cave_north_staging",
        "Hauksness should activate the non-entry Cantlin leg")
    assert_equal(event.object_id,
        "route_cantlin_swamp_cave_north_staging_03",
        "the Cantlin staging leg should leave Hauksness westward")

    local cantlin_staging = assert(routes._route_for_tests(
        "cantlin_swamp_cave_north_staging"))
    for index = 3, #cantlin_staging.waypoints do
        local waypoint = cantlin_staging.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "Great Swamp travel should hand off northwest of Cantlin")
    assert_equal(routes.active_route_id(),
        "great_swamp_swamp_cave_north",
        "the Cantlin bypass should activate the final Great Swamp leg")
    assert_equal(event.object_id,
        "route_great_swamp_swamp_cave_north_04",
        "the Great Swamp leg should descend from the shared turn")
    assert_equal(event.steps, nil,
        "the exterior Cantlin handoff must not inject movement")
    assert_equal(cantlin_staging.waypoints[#cantlin_staging.waypoints].x,
        68, "the Cantlin staging leg should stop at the northwest turn")
    assert_equal(cantlin_staging.waypoints[#cantlin_staging.waypoints].y,
        91, "the Cantlin staging turn row")
    assert_equal(routes.active_route_matches_object(great_swamp), true,
        "Great Swamp should remain selected after all exterior handoffs")

    segment = assert(routes.plan_next_segment(0x01, 68, 91))
    assert_equal(segment.waypoint.name, "Upper forest south notch",
        "the final Great Swamp leg should reuse the validated departure")
    assert_equal(segment.steps[1], "down",
        "the Great Swamp continuation should leave Cantlin southward")

    routes.reset_for_tests()
end

function tests.swamp_cave_north_southern_variants_do_not_steal_other_origins()
    local cases = {
        {id = "overworld_cantlin", name = "Cantlin"},
        {
            id = "overworld_eastern_great_swamp_search_area",
            name = "Eastern Great Swamp Search Area",
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        local kol = assert(routes.start_for_object(
            case, 0x01, 104, 10))
        assert_equal(kol.route.id, "hauksness_staging",
            case.name .. " should retain its Kol-origin itinerary")

        routes.reset_for_tests()
        local tantegel = assert(routes.start_for_object(
            case, 0x01, 43, 43))
        assert_equal(tantegel.route.id, "kol_staging",
            case.name .. " should retain its Tantegel-origin itinerary")

        routes.reset_for_tests()
        local southern = assert(routes.start_for_object(
            case, 0x01, 104, 49))
        assert_equal(southern.route.id, "swamp_cave_south",
            case.name .. " south-cave travel should cross the cave first")
    end

    routes.reset_for_tests()
end

function tests.swamp_cave_south_from_north_starts_with_safe_reentry_stand()
    routes.reset_for_tests()
    local target = {
        id = "overworld_swamp_cave_south_entrance",
        name = "Swamp Cave South Entrance",
    }

    local info, err = routes.start_for_object(target, 0x01, 104, 44)

    assert_equal(err, nil,
        "south entrance Travel should resolve outside Swamp Cave north")
    assert_equal(info.route.id, "swamp_cave_north_entry_staging",
        "north-exit travel should first prepare a safe cave re-entry")
    assert_equal(info.object_id,
        "route_swamp_cave_north_entry_staging_01",
        "the first target should be the north re-entry stand")
    assert_contains(info.message,
        "Swamp Cave South Entrance route starts from Swamp Cave north re-entry stand",
        "staging speech should retain the selected south entrance")
    assert_equal(routes.active_route_matches_object(target), true,
        "the south entrance should remain selected during re-entry staging")

    local segment = assert(routes.plan_next_segment(0x01, 104, 44))
    assert_equal(segment.waypoint.name, "Swamp Cave north re-entry stand",
        "the route should step off the automatic entrance tile first")
    assert_equal(segment.path_length, 1,
        "the safe re-entry stand should be one tile away")
    assert_equal(segment.steps[1], "up",
        "the north entrance should be retriggered from its north doorstep")

    routes.reset_for_tests()
    local alias_info, alias_err = routes.start(
        "swamp cave south", 0x01, 104, 44)
    assert_equal(alias_err, nil,
        "south entrance alias should resolve outside Swamp Cave north")
    assert_equal(alias_info.route.id, "swamp_cave_north_entry_staging",
        "the alias should use the same safe re-entry itinerary")

    routes.reset_for_tests()
end

function tests.swamp_cave_north_to_south_waits_for_manual_cave_crossing()
    routes.reset_for_tests()
    local target = {
        id = "overworld_swamp_cave_south_entrance",
        name = "Swamp Cave South Entrance",
    }
    assert(routes.start_for_object(target, 0x01, 104, 44))

    local wait_event = routes.observe_position(0x01, 104, 43)
    assert_equal(wait_event.status, "await_transition",
        "the north re-entry stand should wait for automatic cave entry")
    assert_contains(wait_event.message, "Step south",
        "transition guidance should name the required re-entry step")
    assert_contains(wait_event.message, "cross to the south exit",
        "transition guidance should explain the manual cave traversal")
    assert_equal(routes.active_route_id(),
        "swamp_cave_north_entry_staging",
        "the staging leg should remain active outside the cave")

    local wait_segment = assert(routes.plan_next_segment(0x01, 104, 43, {
        advance_if_at_waypoint = true,
    }))
    assert_equal(wait_segment.status, "already_at_waypoint",
        "autowalk should wait safely at the re-entry stand")
    assert_equal(#wait_segment.steps, 0,
        "autowalk must not inject the manual cave-entry step")

    local cave_handoff = routes.observe_position(0x15, 0, 0)
    assert_equal(cave_handoff.status, "handoff",
        "north-cave entry should activate the south-exit wait leg")
    assert_equal(routes.active_route_id(),
        "swamp_cave_south_swamp_cave_north",
        "cave traversal should retain the south entrance destination")
    assert_equal(cave_handoff.object_id,
        "route_swamp_cave_south_swamp_cave_north_01",
        "the cave handoff should wait for the south exterior landing")
    assert_equal(cave_handoff.steps, nil,
        "the interior handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "the selected south entrance should remain bound inside the cave")

    assert_equal(routes.observe_position(0x15, 0, 29), nil,
        "the route should not finish merely by reaching the interior south stair")
    local arrival = routes.observe_position(0x01, 104, 49)
    assert_equal(arrival ~= nil, true,
        "the route should report only after emerging at the south entrance")
    assert_contains(arrival.message, "Arrived at Swamp Cave South Entrance",
        "arrival speech should name the selected exterior destination")
    assert_equal(routes.is_active(), false,
        "south-exit arrival should clear the itinerary")

    routes.reset_for_tests()
end

function tests.swamp_cave_north_to_south_variant_does_not_steal_southern_starts()
    local target = {
        id = "overworld_swamp_cave_south_entrance",
        name = "Swamp Cave South Entrance",
    }

    routes.reset_for_tests()
    local south = assert(routes.start_for_object(target, 0x01, 104, 49))
    assert_equal(south.route.id, "swamp_cave_south",
        "standing at the south entrance should retain the canonical route")

    routes.reset_for_tests()
    local rimuldar = assert(routes.start_for_object(target, 0x01, 102, 72))
    assert_equal(rimuldar.route.id, "swamp_cave_south",
        "Rimuldar-side travel should retain its validated return route")

    routes.reset_for_tests()
end

function tests.rimuldar_from_swamp_cave_north_starts_safe_reentry_staging()
    routes.reset_for_tests()
    local target = {
        id = "overworld_rimuldar",
        name = "Rimuldar",
    }

    local info, err = routes.start_for_object(target, 0x01, 104, 44)

    assert_equal(err, nil,
        "Rimuldar Travel should resolve outside Swamp Cave north")
    assert_equal(info.route.id, "swamp_cave_north_entry_staging",
        "north-exit Rimuldar travel should first prepare safe cave re-entry")
    assert_equal(info.object_id,
        "route_swamp_cave_north_entry_staging_01",
        "the first target should be the north re-entry stand")
    assert_contains(info.message,
        "Rimuldar route starts from Swamp Cave north re-entry stand",
        "staging speech should retain Rimuldar as the final destination")
    assert_equal(routes.active_route_matches_object(target), true,
        "Rimuldar should remain selected during re-entry staging")

    local segment = assert(routes.plan_next_segment(0x01, 104, 44))
    assert_equal(segment.waypoint.name, "Swamp Cave north re-entry stand",
        "Rimuldar should reuse the proven cave re-entry stand")
    assert_equal(segment.path_length, 1,
        "the re-entry stand should remain one tile north")
    assert_equal(segment.steps[1], "up",
        "the north entrance should be retriggered from its north doorstep")

    routes.reset_for_tests()
    local alias_info, alias_err = routes.start("rimuldar", 0x01, 104, 44)
    assert_equal(alias_err, nil,
        "Rimuldar alias should resolve outside Swamp Cave north")
    assert_equal(alias_info.route.id, "swamp_cave_north_entry_staging",
        "the alias should use the same connected itinerary")

    routes.reset_for_tests()
end

function tests.rimuldar_from_swamp_cave_north_waits_in_cave_then_resumes()
    routes.reset_for_tests()
    local target = {
        id = "overworld_rimuldar",
        name = "Rimuldar",
    }
    assert(routes.start_for_object(target, 0x01, 104, 44))

    local wait_event = routes.observe_position(0x01, 104, 43)
    assert_equal(wait_event.status, "await_transition",
        "the re-entry stand should wait for manual cave entry")

    local cave_handoff = routes.observe_position(0x15, 0, 0)
    assert_equal(cave_handoff.status, "handoff",
        "north-cave entry should activate the connected Rimuldar leg")
    assert_equal(routes.active_route_id(),
        "rimuldar_swamp_cave_north",
        "the cave crossing should retain the north-origin Rimuldar route")
    assert_equal(cave_handoff.object_id,
        "route_rimuldar_swamp_cave_north_01",
        "the cave handoff should wait for the south exterior landing")
    assert_equal(cave_handoff.steps, nil,
        "the interior handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "Rimuldar should remain selected inside the cave")

    assert_equal(routes.observe_position(0x15, 0, 29), nil,
        "the route should not advance at the interior south stair")
    local south_exit = assert(routes.observe_position(0x01, 104, 49))
    assert_contains(south_exit.message, "Poison swamp ahead",
        "the south exit should retain the validated Rimuldar warning")
    assert_equal(routes.active_route_id(),
        "rimuldar_swamp_cave_north",
        "the connected Rimuldar leg should remain active after cave exit")
    assert_equal(south_exit.object_id,
        "route_rimuldar_swamp_cave_north_02",
        "the south exit should advance to the proven westbound route")

    local segment = assert(routes.plan_next_segment(0x01, 104, 49))
    assert_equal(segment.waypoint.name, "North Rimuldar west safer route",
        "the south exit should resume the existing Rimuldar corridor")
    assert_equal(segment.path_length, 11,
        "the first resumed segment should preserve the bounded westbound route")
    assert_equal(segment.steps[1], "left",
        "the Rimuldar leg should leave the south cave westbound")

    local arrival = assert(routes.observe_position(0x0B, 29, 14))
    assert_contains(arrival.message, "Arrived at Rimuldar",
        "the connected itinerary should finish only after entering town")
    assert_equal(routes.is_active(), false,
        "Rimuldar arrival should clear the complete itinerary")

    routes.reset_for_tests()
end

function tests.rimuldar_swamp_cave_north_variant_does_not_steal_other_origins()
    local target = {
        id = "overworld_rimuldar",
        name = "Rimuldar",
    }

    routes.reset_for_tests()
    local south = assert(routes.start_for_object(target, 0x01, 104, 49))
    assert_equal(south.route.id, "rimuldar",
        "south-entrance travel should retain the canonical Rimuldar route")

    routes.reset_for_tests()
    local tantegel = assert(routes.start_for_object(target, 0x01, 43, 43))
    assert_equal(tantegel.route.id, "kol_staging",
        "Tantegel travel should retain its established three-leg itinerary")

    routes.reset_for_tests()
    local temple = assert(routes.start_for_object(target, 0x01, 108, 109))
    assert_equal(temple.route.id, "rimuldar_magic_temple",
        "Magic Temple travel should retain its validated return route")

    routes.reset_for_tests()
end

function tests.magic_temple_from_swamp_cave_north_uses_cave_and_rimuldar_staging()
    routes.reset_for_tests()
    local target = {
        id = "overworld_southern_cave",
        name = "Magic Temple",
    }

    local info, err = routes.start_for_object(target, 0x01, 104, 44)

    assert_equal(err, nil,
        "Magic Temple Travel should resolve outside Swamp Cave north")
    assert_equal(info.route.id, "swamp_cave_north_entry_staging",
        "north-exit temple travel should first prepare safe cave re-entry")
    assert_equal(info.object_id,
        "route_swamp_cave_north_entry_staging_01",
        "the first target should be the north re-entry stand")
    assert_contains(info.message,
        "Magic Temple route starts from Swamp Cave north re-entry stand",
        "staging speech should retain Magic Temple as the final destination")
    assert_equal(routes.active_route_matches_object(target), true,
        "Magic Temple should remain selected during re-entry staging")

    routes.reset_for_tests()
    local alias_info, alias_err = routes.start(
        "magic temple", 0x01, 104, 44)
    assert_equal(alias_err, nil,
        "Magic Temple alias should resolve outside Swamp Cave north")
    assert_equal(alias_info.route.id, "swamp_cave_north_entry_staging",
        "the alias should use the same connected itinerary")

    routes.reset_for_tests()
end

function tests.magic_temple_from_swamp_cave_north_waits_then_bypasses_rimuldar()
    routes.reset_for_tests()
    local target = {
        id = "overworld_southern_cave",
        name = "Magic Temple",
    }
    assert(routes.start_for_object(target, 0x01, 104, 44))

    local wait_event = routes.observe_position(0x01, 104, 43)
    assert_equal(wait_event.status, "await_transition",
        "the re-entry stand should wait for manual cave entry")

    local cave_handoff = routes.observe_position(0x15, 0, 0)
    assert_equal(cave_handoff.status, "handoff",
        "north-cave entry should activate the exterior Rimuldar staging leg")
    assert_equal(routes.active_route_id(),
        "rimuldar_swamp_cave_north_staging",
        "the cave crossing should retain the connected temple itinerary")
    assert_equal(cave_handoff.object_id,
        "route_rimuldar_swamp_cave_north_staging_01",
        "the cave handoff should wait for the south exterior landing")
    assert_equal(cave_handoff.steps, nil,
        "the interior handoff must not inject movement")

    assert_equal(routes.observe_position(0x15, 0, 29), nil,
        "the route should not advance at the interior south stair")
    local south_exit = assert(routes.observe_position(0x01, 104, 49))
    assert_contains(south_exit.message, "Poison swamp ahead",
        "the south exit should retain the validated Rimuldar warning")
    assert_equal(routes.active_route_id(),
        "rimuldar_swamp_cave_north_staging",
        "the Rimuldar bypass should remain active after cave exit")

    local segment = assert(routes.plan_next_segment(0x01, 104, 49))
    assert_equal(segment.waypoint.name, "North Rimuldar west safer route",
        "the south exit should resume the proven Rimuldar corridor")
    assert_equal(segment.path_length, 11,
        "the first resumed segment should preserve the bounded westbound route")
    assert_equal(segment.steps[1], "left",
        "the Rimuldar leg should leave the south cave westbound")

    local staging = assert(routes._route_for_tests(
        "rimuldar_swamp_cave_north_staging"))
    local handoff
    for index = 2, #staging.waypoints do
        local waypoint = staging.waypoints[index]
        handoff = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(handoff.status, "handoff",
        "Rimuldar's east doorstep should hand off without entering town")
    assert_equal(routes.active_route_id(),
        "magic_temple_swamp_cave_north",
        "the doorstep should activate the selected Magic Temple leg")
    assert_contains(handoff.message,
        "Reached Rimuldar east doorstep. Continuing to Magic Temple.",
        "handoff speech should name the bypass and final destination")
    assert_equal(handoff.object_id,
        "route_magic_temple_swamp_cave_north_03",
        "the continuation should leave Rimuldar eastward")
    assert_equal(handoff.steps, nil,
        "the exterior handoff must wait for the next auto-walk activation")

    segment = assert(routes.plan_next_segment(0x01, 103, 72))
    assert_equal(segment.waypoint.name, "Rimuldar east gate lane",
        "the final leg should reuse the proven temple departure")
    assert_equal(segment.path_length, 4,
        "the first temple segment should remain bounded")
    assert_equal(segment.steps[1], "right",
        "the temple continuation should leave Rimuldar eastward")

    local arrival = assert(routes.observe_position(0x0E, 0, 4))
    assert_contains(arrival.message, "Arrived at Magic Temple",
        "the connected itinerary should finish only after temple entry")
    assert_equal(routes.is_active(), false,
        "Magic Temple arrival should clear the complete itinerary")

    routes.reset_for_tests()
end

function tests.magic_temple_north_itinerary_survives_south_cave_guidance_refresh()
    routes.reset_for_tests()
    local temple = {
        id = "overworld_southern_cave",
        name = "Magic Temple",
    }
    local south_cave = {
        id = "overworld_swamp_cave_south_entrance",
        name = "Swamp Cave South Entrance",
        x = 104,
        y = 49,
    }
    assert(routes.start_for_object(temple, 0x01, 104, 44))
    routes.observe_position(0x01, 104, 43)
    routes.observe_position(0x15, 0, 0)
    routes.observe_position(0x01, 104, 49)

    assert_equal(routes.active_route_matches_object(south_cave), true,
        "the physical south entrance should remain bound to the active temple itinerary")
    local info, err = routes.guidance_for_object(
        south_cave, 0x01, 104, 49)

    assert_equal(err, nil,
        "south-entrance guidance refresh should preserve the active itinerary")
    assert_equal(routes.active_route_id(),
        "rimuldar_swamp_cave_north_staging",
        "route guidance must not replace the temple itinerary with the cave route")
    assert_equal(info.route.id,
        "rimuldar_swamp_cave_north_staging",
        "guidance should continue reporting the exterior Rimuldar leg")
    assert_contains(info.message, "Final destination: Magic Temple",
        "guidance should retain Magic Temple after the cave refresh")

    routes.reset_for_tests()
    assert(routes.start_for_object(temple, 0x01, 104, 49))
    assert_equal(routes.active_route_id(), "rimuldar_staging",
        "a south-exit restart should use the canonical Rimuldar staging leg")
    assert_equal(routes.active_route_matches_object(south_cave), true,
        "the canonical staging leg should also retain the physical cave object")

    info, err = routes.guidance_for_object(south_cave, 0x01, 104, 49)
    assert_equal(err, nil,
        "canonical south-exit guidance refresh should preserve the itinerary")
    assert_equal(routes.active_route_id(), "rimuldar_staging",
        "route guidance must not replace a restarted temple itinerary")
    assert_contains(info.message, "Final destination: Magic Temple",
        "restarted guidance should retain Magic Temple")

    routes.reset_for_tests()
end

function tests.magic_temple_swamp_cave_north_variant_does_not_steal_other_origins()
    local target = {
        id = "overworld_southern_cave",
        name = "Magic Temple",
    }

    routes.reset_for_tests()
    local south = assert(routes.start_for_object(target, 0x01, 104, 49))
    assert_equal(south.route.id, "rimuldar_staging",
        "south-entrance travel should retain its established staging route")

    routes.reset_for_tests()
    local rimuldar = assert(routes.start_for_object(target, 0x01, 102, 72))
    assert_equal(rimuldar.route.id, "magic_temple",
        "Rimuldar travel should retain the canonical temple route")

    routes.reset_for_tests()
    local tantegel = assert(routes.start_for_object(target, 0x01, 43, 43))
    assert_equal(tantegel.route.id, "kol_staging",
        "Tantegel travel should retain its established connected itinerary")

    routes.reset_for_tests()
end

function tests.final_progression_from_swamp_cave_north_reuses_shared_crossing()
    local cases = {
        {
            target = {
                id = "overworld_rainbow_bridge",
                name = "Rainbow Bridge unlock point",
            },
            final_route_id = "rainbow_bridge",
            exit_object_id = "route_rainbow_bridge_02",
            first_waypoint = "Rainbow Bridge east road",
            first_path_length = 11,
        },
        {
            target = {
                id = "overworld_charlock_castle",
                name = "Charlock Castle",
            },
            final_route_id = "charlock_castle",
            exit_object_id = "route_charlock_castle_01",
            first_waypoint = "Swamp Cave south doorstep",
            first_path_length = 1,
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        local info, err = routes.start_for_object(
            case.target, 0x01, 104, 44)

        assert_equal(err, nil,
            case.target.name .. " should resolve outside Swamp Cave north")
        assert_equal(info.route.id, "swamp_cave_north_entry_staging",
            case.target.name .. " should first prepare safe cave re-entry")
        assert_equal(info.object_id,
            "route_swamp_cave_north_entry_staging_01",
            "the first target should be the north re-entry stand")
        assert_equal(routes.active_route_matches_object(case.target), true,
            case.target.name .. " should remain selected during re-entry staging")

        local wait_event = assert(routes.observe_position(0x01, 104, 43))
        assert_equal(wait_event.status, "await_transition",
            "the re-entry stand should wait for manual cave entry")

        local cave_handoff = assert(routes.observe_position(0x15, 0, 0))
        assert_equal(cave_handoff.status, "handoff",
            "north-cave entry should activate the south-exit wait leg")
        assert_equal(routes.active_route_id(),
            "swamp_cave_south_swamp_cave_north",
            "the manual crossing should retain the final progression itinerary")
        assert_equal(cave_handoff.steps, nil,
            "the interior handoff must not inject movement")
        assert_equal(routes.active_route_matches_object(case.target), true,
            case.target.name .. " should remain selected inside the cave")

        assert_equal(routes.observe_position(0x15, 0, 29), nil,
            "the route should not advance at the interior south stair")
        local south_exit = assert(routes.observe_position(0x01, 104, 49))
        assert_equal(south_exit.status, "handoff",
            "the south exterior should hand off to the final route")
        assert_equal(routes.active_route_id(), case.final_route_id,
            "the cave crossing should activate " .. case.target.name)
        assert_equal(south_exit.object_id, case.exit_object_id,
            "the final route should select its established first segment")

        local segment = assert(routes.plan_next_segment(0x01, 104, 49))
        assert_equal(segment.waypoint.name, case.first_waypoint,
            "the final route should reuse its established first waypoint")
        assert_equal(segment.path_length, case.first_path_length,
            "the final route should preserve its bounded first segment")
        assert_equal(segment.steps[1], "left",
            "the final route should leave Swamp Cave westbound")
    end

    routes.reset_for_tests()
end

function tests.final_progression_north_itineraries_survive_south_cave_guidance_refresh()
    local south_cave = {
        id = "overworld_swamp_cave_south_entrance",
        name = "Swamp Cave South Entrance",
        x = 104,
        y = 49,
    }
    local cases = {
        {
            target = {
                id = "overworld_rainbow_bridge",
                name = "Rainbow Bridge unlock point",
            },
            final_route_id = "rainbow_bridge",
        },
        {
            target = {
                id = "overworld_charlock_castle",
                name = "Charlock Castle",
            },
            final_route_id = "charlock_castle",
        },
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        assert(routes.start_for_object(case.target, 0x01, 104, 44))
        routes.observe_position(0x01, 104, 43)
        routes.observe_position(0x15, 0, 0)
        routes.observe_position(0x01, 104, 49)

        assert_equal(routes.active_route_matches_object(south_cave), true,
            "the physical south entrance should remain compatible with " ..
                case.target.name)
        local info, err = routes.guidance_for_object(
            south_cave, 0x01, 104, 49)

        assert_equal(err, nil,
            "south-entrance guidance should preserve " .. case.target.name)
        assert_equal(routes.active_route_id(), case.final_route_id,
            "route guidance must not replace " .. case.target.name)
        assert_equal(info.route.id, case.final_route_id,
            "guidance should continue reporting " .. case.target.name)
        assert_contains(info.message, "Route to " .. case.target.name,
            "guidance should retain the requested final destination")
    end

    routes.reset_for_tests()
end

function tests.garinham_from_kol_hands_off_at_tantegel_bridge_junction()
    routes.reset_for_tests()
    local target = {
        id = "overworld_garinham",
        name = "Garinham",
        x = 1,
        y = 2,
    }
    assert(routes.start_for_object(target, 0x01, 104, 10))

    local staging = assert(routes._route_for_tests("tantegel_bridge_staging"))
    local event
    for index = 2, #staging.waypoints do
        local waypoint = staging.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    assert_equal(event.status, "handoff",
        "the bridge junction should hand off without entering Tantegel")
    assert_equal(routes.active_route_id(), "garinham_kol",
        "the junction should activate the Kol-origin Garinham continuation")
    assert_equal(event.object_id, "route_garinham_kol_04",
        "the continuation should leave the shared bridge pin northward")
    assert_contains(event.log, "from_route=tantegel_bridge_staging",
        "handoff logs should identify the hidden junction leg")
    assert_equal(event.steps, nil,
        "the exterior junction handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "Garinham should remain selected after the junction handoff")

    local segment = assert(routes.plan_next_segment(0x01, 44, 38))
    assert_equal(segment.waypoint.name, "Bridge lower west lane",
        "the continuation should follow the validated Garinham corridor")
    assert_equal(segment.steps[1], "up",
        "the Garinham continuation should leave the junction northward")

    routes.reset_for_tests()
end

function tests.kol_early_destination_variants_preserve_direct_tantegel_starts()
    local cases = {
        {id = "overworld_garinham", name = "Garinham", x = 1, y = 2,
            direct_route = "garinham"},
        {id = "overworld_erdrick_s_cave", name = "Erdrick's Cave", x = 28, y = 12,
            direct_route = "erdrick"},
        {id = "overworld_brecconary", name = "Brecconary", x = 48, y = 41,
            direct_route = "brecconary"},
    }

    for _, case in ipairs(cases) do
        routes.reset_for_tests()
        local info, err = routes.start_for_object(case, 0x01, 43, 43)
        assert_equal(err, nil,
            case.name .. " Travel should still resolve from Tantegel")
        assert_equal(info.route.id, case.direct_route,
            case.name .. " should retain its direct Tantegel-side route")
    end

    routes.reset_for_tests()
end

function tests.hauksness_from_tantegel_starts_kol_staging_route()
    routes.reset_for_tests()

    local info, err = routes.start("hauksness", 0x01, 43, 43)

    assert_equal(err, nil, "Hauksness alias should resolve from Tantegel")
    assert_equal(info.route.id, "kol_staging", "far Hauksness requests should stage outside Kol")
    assert_equal(info.object_id, "route_kol_staging_02", "staging route should leave Tantegel on the safe Kol route")
    assert_contains(info.message, "Hauksness route starts from Kol", "staging should explain the required hub")
    assert_contains(info.message, "Starting route to Kol first", "staging should say which route actually started")
    assert_contains(info.log, "staged_from=hauksness", "staged starts should be visible in logs")

    local segment = assert(routes.plan_next_segment(0x01, 43, 43))
    assert_equal(segment.waypoint.name, "Brecconary west bypass", "Kol staging should avoid the town entrance")
    assert_equal(segment.steps[1], "up", "Tantegel-to-Kol staging should leave toward the west bypass")

    routes.reset_for_tests()
end

function tests.kol_route_bypasses_brecconary_west_doorstep()
    routes.reset_for_tests()

    local route = assert(routes._route_for_tests("kol"))
    local bypass = assert(route.waypoints[2])

    assert_equal(bypass.x, 47,
        "Kol route should stop west of Brecconary instead of targeting its entrance")
    assert_equal(bypass.y, 41, "Brecconary bypass row")
    assert_equal(bypass.name, "Brecconary west bypass",
        "the waypoint should describe the non-entry path")
    local final = assert(route.waypoints[#route.waypoints])
    assert_equal(final.x, 104, "direct Kol travel should still target the town entrance")
    assert_equal(final.y, 10, "direct Kol entrance row")

    routes.start("kol", 0x01, 43, 43)
    local segment = assert(routes.plan_next_segment(0x01, 43, 43))
    assert_equal(segment.waypoint.name, "Brecconary west bypass",
        "direct Kol travel should use the bypass")
    assert_equal(segment.path_length, 6,
        "the bypass should move two north and four east without touching (48,41)")

    routes.observe_position(0x01, 47, 41)
    segment = assert(routes.plan_next_segment(0x01, 47, 41))
    assert_equal(segment.waypoint.name, "Bridge south bend",
        "the bypass should reconnect to the existing bridge route")
    assert_equal(segment.steps[1], "up",
        "the bypass should turn north instead of stepping east into Brecconary")

    routes.reset_for_tests()
end

function tests.hauksness_staging_hands_off_outside_kol()
    routes.reset_for_tests()

    local info = assert(routes.start("hauksness", 0x01, 43, 43))
    assert_equal(info.route.id, "kol_staging",
        "far Hauksness travel should use the non-entry Kol staging route")

    local staging = assert(routes._route_for_tests("kol_staging"))
    local final = assert(staging.waypoints[#staging.waypoints])
    assert_equal(final.x, 103, "Kol staging should finish west of the town entrance")
    assert_equal(final.y, 10, "Kol west doorstep row")
    assert_equal(final.name, "Kol west doorstep",
        "the staging endpoint should distinguish the safe handoff from town entry")

    local event
    for index = 2, #staging.waypoints do
        local waypoint = staging.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    assert_equal(event.status, "handoff",
        "the west doorstep should hand off without entering Kol")
    assert_equal(routes.active_route_id(), "hauksness",
        "the safe Kol handoff should activate Hauksness")
    assert_contains(event.log, "from_route=kol_staging",
        "the handoff log should identify the internal non-entry leg")

    local segment = assert(routes.plan_next_segment(0x01, 103, 10))
    assert_equal(segment.waypoint.name, "Kol forest west edge",
        "Hauksness should continue directly from the west doorstep")
    assert_equal(segment.steps[1], "left",
        "the continuation should move away from Kol instead of entering it")

    routes.reset_for_tests()
end

function tests.hauksness_object_from_tantegel_retains_final_destination()
    routes.reset_for_tests()
    local target = {
        id = "overworld_hauksness",
        name = "Hauksness",
        x = 25,
        y = 89,
    }

    local info, err = routes.start_for_object(target, 0x01, 43, 43)

    assert_equal(err, nil, "Hauksness Travel object should resolve from Tantegel")
    assert_equal(info.route.id, "kol_staging", "Travel-object starts should use the safe Kol staging route")
    assert_equal(info.object_id, "route_kol_staging_02", "Travel-object staging should leave Tantegel on the non-entry route")
    assert_equal(routes.active_route_matches_object(target), true,
        "the selected Hauksness object should remain bound during the Kol leg")

    routes.reset_for_tests()
end

function tests.hauksness_staging_hands_off_at_kol_without_starting_movement()
    routes.reset_for_tests()
    routes.start("hauksness", 0x01, 43, 43)
    local kol = assert(routes._route_for_tests("kol_staging"))
    local event

    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    assert_equal(routes.active_route_id(), "hauksness",
        "reaching Kol should activate the requested Hauksness leg")
    assert_equal(event.status, "handoff",
        "the Hauksness itinerary should distinguish a leg handoff from final arrival")
    assert_contains(event.message, "Reached Kol west doorstep. Continuing to Hauksness.",
        "handoff speech should name the completed hub and final destination")
    assert_contains(event.message, "Next: Kol forest west edge",
        "handoff speech should identify the first Hauksness waypoint")
    assert_contains(event.log, "event=handoff", "handoff should be explicit in structured logs")
    assert_contains(event.log, "from_route=kol_staging", "handoff logs should identify the completed leg")
    assert_equal(event.object_id, "route_hauksness_02",
        "route markers should refresh to the first Hauksness movement waypoint")
    assert_equal(event.steps, nil, "handoff must not inject movement by itself")

    local segment = assert(routes.plan_next_segment(0x01, 103, 10))
    assert_equal(segment.waypoint.name, "Kol forest west edge",
        "the next segment should leave Kol along the validated Hauksness route")
    assert_equal(segment.steps[1], "left", "the Hauksness leg should leave Kol west")

    routes.reset_for_tests()
end

function tests.hauksness_on_route_garinham_start_does_not_stage_to_kol()
    routes.reset_for_tests()

    local info, err = routes.start("hauksness", 0x01, 20, 9)

    assert_equal(err, nil, "Hauksness route should resolve from its Garinham corridor")
    assert_equal(info.route.id, "hauksness", "an established western-corridor start should remain direct")
    assert_equal(string.find(info.log, "staged_from=", 1, true), nil,
        "an on-route start should not detour east through Kol")

    routes.reset_for_tests()
end

function tests.hauksness_object_from_kol_starts_conservative_route()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_hauksness",
        name = "Hauksness",
        x = 25,
        y = 89,
    }, 0x01, 104, 10)

    assert_equal(err, nil, "Hauksness Travel object should start guidance from Kol")
    assert_equal(info.route.id, "hauksness", "Hauksness object should choose the Hauksness route")
    assert_equal(info.object_id, "route_hauksness_02", "Kol start should skip the current Kol anchor")
    assert_contains(info.message, "Route to Hauksness", "started route should name Hauksness")
    assert_contains(info.message, "Kol forest west edge", "route should begin on the proven Kol return road")

    local segment = assert(routes.plan_next_segment(0x01, 104, 10))
    assert_equal(segment.waypoint.name, "Kol forest west edge", "first segment should target the Kol forest edge")
    assert_equal(segment.steps[1], "left", "Hauksness route should leave Kol westward")

    routes.reset_for_tests()
end

function tests.hauksness_route_turns_through_garinham_before_southwest_leg()
    routes.reset_for_tests()
    routes.start("damdara", 0x01, 104, 10)

    routes.observe_position(0x01, 96, 13)
    routes.observe_position(0x01, 96, 21)
    local detour = assert(routes.plan_next_segment(0x01, 96, 26))
    assert_equal(detour.waypoint.name, "Kol south road east detour", "Hauksness should detour around the blocked x96 seam")
    assert_equal(detour.steps[1], "right", "Hauksness should step east at the live-confirmed seam")
    routes.observe_position(0x01, 98, 26)
    routes.observe_position(0x01, 98, 32)
    routes.observe_position(0x01, 96, 32)
    routes.observe_position(0x01, 96, 35)
    routes.observe_position(0x01, 93, 35)
    routes.observe_position(0x01, 93, 36)
    routes.observe_position(0x01, 92, 36)
    routes.observe_position(0x01, 92, 37)
    routes.observe_position(0x01, 90, 37)
    routes.observe_position(0x01, 84, 26)
    routes.observe_position(0x01, 74, 18)
    routes.observe_position(0x01, 61, 18)
    routes.observe_position(0x01, 61, 19)
    routes.observe_position(0x01, 59, 19)
    routes.observe_position(0x01, 58, 18)
    routes.observe_position(0x01, 54, 15)
    routes.observe_position(0x01, 45, 13)
    routes.observe_position(0x01, 35, 13)
    local erdrick_road = routes.observe_position(0x01, 28, 13)
    assert_contains(erdrick_road.message, "Next: Cave road south lane", "Hauksness should turn back toward Garinham instead of the central bridge route")

    local cave_south = assert(routes.plan_next_segment(0x01, 28, 13))
    assert_equal(cave_south.waypoint.name, "Cave road south lane", "route should reuse the Garinham-side connector")
    assert_equal(cave_south.steps[1], "left", "Garinham connector should leave Erdrick's Cave road westward")

    routes.observe_position(0x01, 23, 13)
    routes.observe_position(0x01, 23, 11)
    routes.observe_position(0x01, 21, 11)
    routes.observe_position(0x01, 21, 10)
    routes.observe_position(0x01, 20, 9)
    routes.observe_position(0x01, 20, 7)
    routes.observe_position(0x01, 19, 6)
    routes.observe_position(0x01, 16, 6)
    routes.observe_position(0x01, 16, 5)
    routes.observe_position(0x01, 15, 4)
    routes.observe_position(0x01, 14, 4)
    routes.observe_position(0x01, 14, 3)
    routes.observe_position(0x01, 8, 3)
    local garinham_outskirts = routes.observe_position(0x01, 5, 4)
    assert_contains(garinham_outskirts.message, "Next: Hauksness north road", "route should start the live-proven west-continent leg from Garinham outskirts")

    routes.observe_position(0x01, 7, 4)
    routes.observe_position(0x01, 7, 6)
    routes.observe_position(0x01, 5, 6)
    routes.observe_position(0x01, 5, 7)
    routes.observe_position(0x01, 3, 7)
    routes.observe_position(0x01, 3, 12)
    routes.observe_position(0x01, 4, 12)
    routes.observe_position(0x01, 4, 13)
    routes.observe_position(0x01, 5, 13)
    routes.observe_position(0x01, 5, 14)
    routes.observe_position(0x01, 7, 14)
    routes.observe_position(0x01, 15, 14)
    local shelf = routes.observe_position(0x01, 15, 28)
    assert_contains(shelf.message, "Next: Western desert west detour", "route should detour west at the live-blocked south edge")

    local west_detour = assert(routes.plan_next_segment(0x01, 15, 28))
    assert_equal(west_detour.waypoint.name, "Western desert west detour", "first desert detour should be explicit")
    assert_equal(west_detour.steps[1], "left", "route should not descend from the blocked shelf")

    routes.reset_for_tests()
end

function tests.hauksness_western_leg_uses_validated_desert_detours()
    routes.reset_for_tests()
    routes.start("hauksness", 0x01, 29, 82)

    local ridge = assert(routes.plan_next_segment(0x01, 29, 82))
    assert_equal(ridge.waypoint.name, "Hauksness northwest bend", "route should leave the north ridge through the east/up bend")
    assert_equal(ridge.steps[1], "right", "north ridge recovery should move east before turning north")

    routes.observe_position(0x01, 31, 81)
    routes.observe_position(0x01, 26, 81)
    routes.observe_position(0x01, 26, 79)
    routes.observe_position(0x01, 22, 79)
    routes.observe_position(0x01, 22, 83)
    routes.observe_position(0x01, 20, 83)
    routes.observe_position(0x01, 20, 85)
    routes.observe_position(0x01, 18, 85)
    routes.observe_position(0x01, 16, 85)
    routes.observe_position(0x01, 16, 86)
    routes.observe_position(0x01, 15, 86)
    routes.observe_position(0x01, 15, 88)
    routes.observe_position(0x01, 26, 88)
    routes.observe_position(0x01, 26, 90)
    routes.observe_position(0x01, 26, 91)
    routes.observe_position(0x01, 24, 91)
    routes.observe_position(0x01, 24, 93)
    local lower_lane = routes.observe_position(0x01, 15, 93)
    assert_contains(lower_lane.message, "Next: Hauksness west approach", "lower lane should turn north for the final town entry")

    local final_approach = assert(routes.plan_next_segment(0x01, 15, 93))
    assert_equal(final_approach.waypoint.name, "Hauksness west approach", "final approach should use the live-proven row-89 lane")
    assert_equal(final_approach.steps[1], "up", "final approach should climb from the lower lane before heading east")

    routes.reset_for_tests()
end

function tests.hauksness_south_road_moves_east_before_blocked_x1_descent()
    routes.reset_for_tests()
    routes.start("hauksness", 0x01, 2, 54)

    local segment = assert(routes.plan_next_segment(0x01, 1, 54))
    assert_equal(segment.waypoint.name, "Western desert south road", "west-wall carry should retain the south-road waypoint")
    assert_equal(segment.steps[1], "right", "south-road recovery should leave x1 before descending")

    routes.reset_for_tests()
end

function tests.hauksness_south_shelf_corrects_west_before_blocked_x16_descent()
    routes.reset_for_tests()
    routes.start("hauksness", 0x01, 16, 27)

    local segment = assert(routes.plan_next_segment(0x01, 16, 27))
    assert_equal(segment.waypoint.name, "Western desert south shelf", "blocked x16 approach should retain the south-shelf waypoint")
    assert_equal(segment.steps[1], "left", "south-shelf approach should correct west before descending")
    assert_equal(segment.steps[2], "down", "south-shelf approach should descend only after reaching x15")

    routes.reset_for_tests()
end

function tests.hauksness_desert_seam_waypoints_remain_horizontal_first()
    local east_shelf = assert(find_waypoint("hauksness", "Western desert east shelf"))
    local south_shelf = assert(find_waypoint("hauksness", "Western desert south shelf"))

    assert_equal(east_shelf.axis_order and east_shelf.axis_order[1], "horizontal", "east shelf should keep horizontal-first reverse-seam protection")
    assert_equal(east_shelf.axis_order and east_shelf.axis_order[2], "vertical", "east shelf should turn vertical after correcting its column")
    assert_equal(south_shelf.axis_order and south_shelf.axis_order[1], "horizontal", "south shelf should use horizontal-first forward-seam protection")
    assert_equal(south_shelf.axis_order and south_shelf.axis_order[2], "vertical", "south shelf should descend after correcting its column")
end

function tests.hauksness_northern_ridge_uses_live_proven_western_gap()
    routes.reset_for_tests()
    routes.start("hauksness", 0x01, 7, 4)

    local expected = {
        {x = 7, y = 6, name = "Hauksness ridge upper lip", first = "down"},
        {x = 5, y = 6, name = "Hauksness ridge west turn", first = "left"},
        {x = 5, y = 7, name = "Hauksness ridge west notch", first = "down"},
        {x = 3, y = 7, name = "Hauksness ridge west gap", first = "left"},
        {x = 3, y = 12, name = "Hauksness ridge lower coast", first = "down"},
        {x = 4, y = 12, name = "Hauksness coast east step", first = "right"},
        {x = 4, y = 13, name = "Hauksness coast south step", first = "down"},
        {x = 5, y = 13, name = "Hauksness coast lower east step", first = "right"},
        {x = 5, y = 14, name = "Hauksness coast lower bend", first = "down"},
        {x = 7, y = 14, name = "Hauksness northern descent", first = "right"},
    }

    local x, y = 7, 4
    for _, waypoint in ipairs(expected) do
        local segment = assert(routes.plan_next_segment(0x01, x, y))
        assert_equal(segment.waypoint.name, waypoint.name, "Hauksness ridge should follow the live-proven western gap")
        assert_equal(segment.steps[1], waypoint.first, waypoint.name .. " should begin in the proven direction")
        routes.observe_position(0x01, waypoint.x, waypoint.y)
        x, y = waypoint.x, waypoint.y
    end

    local shelf = assert(routes.plan_next_segment(0x01, 7, 14))
    assert_equal(shelf.waypoint.name, "Western desert east shelf", "ridge exit should resume the validated desert route")
    assert_equal(shelf.steps[1], "right", "ridge exit should continue east along row 14")

    routes.reset_for_tests()
end

function tests.hauksness_final_entry_steps_east_from_west_doorstep()
    routes.reset_for_tests()
    routes.start("hauksness", 0x01, 15, 93)

    local west_approach = assert(routes.plan_next_segment(0x01, 15, 93))
    assert_equal(west_approach.waypoint.name, "Hauksness west approach", "route should recover from the lower lane")
    assert_equal(west_approach.path_length, 4, "live route climbs four tiles to row 89 before crossing east")

    routes.observe_position(0x01, 15, 89)
    local doorstep = assert(routes.plan_next_segment(0x01, 15, 89))
    assert_equal(doorstep.waypoint.name, "Hauksness doorstep west", "route should stop at the live-confirmed west doorstep")
    assert_equal(doorstep.path_length, 9, "doorstep run should cross row 89 from x15 to x24")
    assert_equal(doorstep.steps[1], "right", "doorstep run should head east along row 89")

    routes.observe_position(0x01, 24, 89)
    local entry = assert(routes.plan_next_segment(0x01, 24, 89))
    assert_equal(entry.waypoint.name, "Hauksness", "final waypoint should be the town transition tile")
    assert_equal(entry.path_length, 1, "town entry is the single east step from (24,89)")
    assert_equal(entry.steps[1], "right", "town entry should step east into Hauksness")

    routes.reset_for_tests()
end

function tests.entering_hauksness_stops_route()
    routes.reset_for_tests()
    routes.start("hauksness", 0x01, 25, 88)

    local event = routes.observe_position(0x03, 0, 0)

    assert_contains(event.message, "Arrived at Hauksness", "entering Hauksness should complete the route")
    assert_equal(event.refresh, true, "destination map arrival should refresh Travel objects")
    assert_equal(routes.is_active(), false, "route should stop after entering Hauksness")

    routes.reset_for_tests()
end

function tests.kol_route_from_hauksness_uses_hauksness_return_variant()
    routes.reset_for_tests()

    local info, err = routes.start("kol", 0x01, 25, 89)

    assert_equal(err, nil, "Kol alias should resolve outside Hauksness")
    assert_equal(info.route.id, "kol_hauksness", "route should use the Hauksness return variant")
    assert_equal(info.object_id, "route_kol_hauksness_02", "Hauksness exit should target the west doorstep")
    assert_contains(info.message, "Hauksness doorstep west", "route should begin by leaving the ruins westward")

    local segment = assert(routes.plan_next_segment(0x01, 25, 89))
    assert_equal(segment.waypoint.name, "Hauksness doorstep west", "first segment should target the west doorstep")
    assert_equal(segment.steps[1], "left", "first return step should move west away from Hauksness")

    routes.reset_for_tests()
end

function tests.kol_object_from_hauksness_uses_hauksness_return_variant()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_kol",
        name = "Kol",
        x = 104,
        y = 10,
    }, 0x01, 25, 89)

    assert_equal(err, nil, "Kol Travel object should start from Hauksness")
    assert_equal(info.route.id, "kol_hauksness", "ordinary Kol object should choose the Hauksness return route")
    assert_equal(info.object_id, "route_kol_hauksness_02", "Kol object should target the local west doorstep")

    routes.reset_for_tests()
end

function tests.active_hauksness_return_matches_ordinary_kol_object()
    routes.reset_for_tests()
    routes.start("hauksness to kol", 0x01, 25, 89)

    local matches = routes.active_route_matches_object({
        id = "overworld_kol",
        name = "Kol",
        x = 104,
        y = 10,
    })

    assert_equal(matches, true, "active Hauksness return should retain the ordinary Kol destination")

    routes.reset_for_tests()
end

function tests.kol_hauksness_return_preserves_lower_pocket_recovery()
    routes.reset_for_tests()
    routes.start("hauksness to kol", 0x01, 25, 89)

    local expected = {
        {x = 24, y = 89, name = "Hauksness doorstep west", first = "left"},
        {x = 15, y = 89, name = "Hauksness west approach", first = "left"},
        {x = 15, y = 93, name = "Hauksness lower west lane", first = "down"},
        {x = 24, y = 93, name = "Hauksness lower west drop", first = "right"},
        {x = 24, y = 91, name = "Hauksness lower west pocket", first = "up"},
        {x = 26, y = 91, name = "Hauksness lower pocket", first = "right"},
        {x = 26, y = 90, name = "Hauksness lower south bend", first = "up"},
        {x = 26, y = 88, name = "Hauksness lower east lane", first = "up"},
        {x = 15, y = 88, name = "Hauksness west approach lower lane", first = "left"},
    }

    local x, y = 25, 89
    for _, waypoint in ipairs(expected) do
        local segment = assert(routes.plan_next_segment(0x01, x, y))
        assert_equal(segment.waypoint.name, waypoint.name, "return route should preserve the lower-pocket recovery chain")
        assert_equal(segment.steps[1], waypoint.first, waypoint.name .. " should begin in the proven direction")
        routes.observe_position(0x01, waypoint.x, waypoint.y)
        x, y = waypoint.x, waypoint.y
    end

    routes.reset_for_tests()
end

function tests.kol_hauksness_return_recovers_west_after_lower_drop_carry()
    routes.reset_for_tests()
    routes.start("hauksness to kol", 0x01, 25, 89)

    routes.observe_position(0x01, 24, 89)
    routes.observe_position(0x01, 15, 89)
    routes.observe_position(0x01, 15, 93)
    routes.observe_position(0x01, 24, 93)

    local segment = assert(routes.plan_next_segment(0x01, 25, 93))

    assert_equal(segment.waypoint.name, "Hauksness lower west pocket", "carry recovery should retain the next return waypoint")
    assert_equal(segment.steps[1], "left", "carry recovery should return to column 24 before climbing")
    assert_equal(segment.steps[2], "up", "carry recovery should climb after returning to column 24")
    assert_equal(segment.steps[3], "up", "carry recovery should reach the lower west pocket")

    routes.reset_for_tests()
end

function tests.kol_hauksness_return_uses_reverse_desert_shelf_guard()
    routes.reset_for_tests()
    routes.start("hauksness to kol", 0x01, 15, 28)

    local segment = assert(routes.plan_next_segment(0x01, 16, 28))

    assert_equal(segment.waypoint.name, "Western desert east shelf", "return route should target the validated north shelf")
    assert_equal(segment.steps[1], "left", "x16 return approach should correct west before moving north")
    assert_equal(segment.steps[2], "up", "return route should move north only after reaching x15")

    routes.reset_for_tests()
end

function tests.kol_hauksness_return_uses_live_proven_ridge_gap()
    routes.reset_for_tests()
    routes.start("hauksness to kol", 0x01, 7, 14)

    local expected = {
        {x = 5, y = 14, name = "Hauksness coast lower bend", first = "left"},
        {x = 5, y = 13, name = "Hauksness coast lower east step", first = "up"},
        {x = 4, y = 13, name = "Hauksness coast south step", first = "left"},
        {x = 4, y = 12, name = "Hauksness coast east step", first = "up"},
        {x = 3, y = 12, name = "Hauksness ridge lower coast", first = "left"},
        {x = 3, y = 7, name = "Hauksness ridge west gap", first = "up"},
        {x = 5, y = 7, name = "Hauksness ridge west notch", first = "right"},
        {x = 5, y = 6, name = "Hauksness ridge west turn", first = "up"},
        {x = 7, y = 6, name = "Hauksness ridge upper lip", first = "right"},
        {x = 7, y = 4, name = "Hauksness north road", first = "up"},
    }

    local x, y = 7, 14
    for _, waypoint in ipairs(expected) do
        local segment = assert(routes.plan_next_segment(0x01, x, y))
        assert_equal(segment.waypoint.name, waypoint.name, "return ridge should use the live-proven western gap")
        assert_equal(segment.steps[1], waypoint.first, waypoint.name .. " should begin in the proven direction")
        routes.observe_position(0x01, waypoint.x, waypoint.y)
        x, y = waypoint.x, waypoint.y
    end

    routes.reset_for_tests()
end

function tests.kol_hauksness_return_uses_south_first_northeast_bridge_approach()
    routes.reset_for_tests()
    routes.start("hauksness to kol", 0x01, 6, 4)

    local route = routes._route_for_tests("kol_hauksness")
    for index = 54, 70 do
        local waypoint = route.waypoints[index]
        routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    local segment = assert(routes.plan_next_segment(0x01, 56, 15))

    assert_equal(segment.waypoint.name, "Northeast bridge west bend", "return route should target the west bridge bend")
    assert_equal(segment.steps[1], "down", "west bridge approach should move south before the blocked east edge")

    routes.reset_for_tests()
end

function tests.kol_hauksness_return_descends_before_kol_southwest_track()
    routes.reset_for_tests()
    routes.start("hauksness to kol", 0x01, 6, 4)

    local route = routes._route_for_tests("kol_hauksness")
    for index = 54, 75 do
        local waypoint = route.waypoints[index]
        routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    local segment = assert(routes.plan_next_segment(0x01, 77, 18))

    assert_equal(segment.waypoint.name, "Kol southwest track", "return route should target the southwest track")
    assert_equal(segment.steps[1], "down", "west approach should descend before the blocked east edge at 77,18")

    routes.reset_for_tests()
end

function tests.kol_variants_recalculate_to_and_from_hauksness()
    local starts = {
        {alias = "kol", x = 43, y = 43},
        {alias = "kol from rain shrine", x = 81, y = 1},
        {alias = "kol from swamp cave", x = 104, y = 44},
    }

    for _, start in ipairs(starts) do
        routes.reset_for_tests()
        routes.start(start.alias, 0x01, start.x, start.y)

        local info = routes.recalculate(0x01, 25, 89)

        assert_equal(info.route.id, "kol_hauksness", start.alias .. " should recalculate to the Hauksness return variant")
        assert_equal(info.object_id, "route_kol_hauksness_02", "recalculation should target the local west doorstep")
    end

    routes.reset_for_tests()
    routes.start("hauksness to kol", 0x01, 25, 89)

    local swamp = routes.recalculate(0x01, 104, 44)

    assert_equal(swamp.route.id, "kol_swamp_cave", "Hauksness variant should recalculate to the nearer Swamp Cave return")

    routes.reset_for_tests()
end

function tests.entering_kol_stops_hauksness_return_route()
    routes.reset_for_tests()
    routes.start("hauksness to kol", 0x01, 25, 89)

    local event = routes.observe_position(0x07, 0, 0)

    assert_contains(event.message, "Arrived at Kol", "entering Kol should complete the Hauksness return route")
    assert_equal(event.refresh, true, "Kol arrival should refresh Travel objects")
    assert_equal(routes.is_active(), false, "route should stop after entering Kol")

    routes.reset_for_tests()
end

local function assert_cantlin_route_group(start_x, start_y, expected, label)
    routes.reset_for_tests()
    routes.start("cantlin to hauksness", 0x01, start_x, start_y)

    local x, y = start_x, start_y
    for _, waypoint in ipairs(expected) do
        local segment = assert(routes.plan_next_segment(0x01, x, y))
        assert_equal(segment.waypoint.x, waypoint.x, label .. " x")
        assert_equal(segment.waypoint.y, waypoint.y, label .. " y")

        local expected_first
        if waypoint.x > x then
            expected_first = "right"
        elseif waypoint.x < x then
            expected_first = "left"
        elseif waypoint.y > y then
            expected_first = "down"
        else
            expected_first = "up"
        end
        assert_equal(segment.steps[1], expected_first, label .. " first direction")

        if waypoint.final then
            assert_equal(segment.path_length, 1, label .. " final entry length")
        else
            routes.observe_position(0x01, waypoint.x, waypoint.y)
            x, y = waypoint.x, waypoint.y
        end
    end

    routes.reset_for_tests()
end

function tests.hauksness_alias_from_cantlin_uses_cantlin_variant()
    routes.reset_for_tests()

    local info, err = routes.start("hauksness", 0x01, 73, 102)

    assert_equal(err, nil, "Hauksness alias should resolve outside Cantlin")
    assert_equal(info.route.id, "hauksness_cantlin", "Cantlin start should use the local Hauksness variant")
    assert_equal(info.object_id, "route_hauksness_cantlin_02", "Cantlin start should skip the current entrance anchor")
    assert_contains(info.message, "Cantlin north road", "route should begin north from Cantlin")

    local segment = assert(routes.plan_next_segment(0x01, 73, 102))
    assert_equal(segment.waypoint.name, "Cantlin north road", "first segment should target the northern turn")
    assert_equal(segment.steps[1], "up", "first return step should move north away from Cantlin")

    routes.reset_for_tests()
end

function tests.hauksness_object_from_cantlin_uses_cantlin_variant()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_hauksness",
        name = "Hauksness",
        x = 25,
        y = 89,
    }, 0x01, 73, 102)

    assert_equal(err, nil, "Hauksness Travel object should start outside Cantlin")
    assert_equal(info.route.id, "hauksness_cantlin", "ordinary Hauksness object should choose the Cantlin variant")
    assert_equal(info.object_id, "route_hauksness_cantlin_02", "Hauksness object should target the northern road")

    routes.reset_for_tests()
end

function tests.active_cantlin_hauksness_route_matches_ordinary_object()
    routes.reset_for_tests()
    routes.start("cantlin to hauksness", 0x01, 73, 102)

    local matches = routes.active_route_matches_object({
        id = "overworld_hauksness",
        name = "Hauksness",
        x = 25,
        y = 89,
    })

    assert_equal(matches, true, "active Cantlin variant should retain the ordinary Hauksness destination")

    routes.reset_for_tests()
end

function tests.cantlin_hauksness_departure_preserves_entry_seam()
    assert_cantlin_route_group(73, 102, {
        {x = 73, y = 91},
        {x = 68, y = 91},
    }, "Cantlin northern departure")
end

function tests.cantlin_hauksness_preserves_northern_westbound_route()
    assert_cantlin_route_group(68, 91, {
        {x = 68, y = 92},
        {x = 64, y = 92},
        {x = 64, y = 93},
        {x = 60, y = 93},
        {x = 60, y = 94},
        {x = 56, y = 94},
        {x = 56, y = 95},
        {x = 54, y = 95},
        {x = 54, y = 96},
        {x = 53, y = 96},
        {x = 53, y = 97},
        {x = 52, y = 97},
        {x = 52, y = 98},
        {x = 51, y = 98},
    }, "northern westbound route")
end

function tests.cantlin_hauksness_preserves_western_forest_switchbacks()
    assert_cantlin_route_group(51, 98, {
        {x = 51, y = 99},
        {x = 50, y = 99},
        {x = 50, y = 100},
        {x = 49, y = 100},
        {x = 49, y = 102},
        {x = 48, y = 102},
        {x = 48, y = 104},
        {x = 47, y = 104},
        {x = 47, y = 105},
        {x = 45, y = 105},
        {x = 45, y = 106},
        {x = 44, y = 106},
        {x = 44, y = 107},
        {x = 43, y = 107},
        {x = 43, y = 108},
        {x = 42, y = 108},
    }, "western forest switchback")
end

function tests.cantlin_hauksness_preserves_southern_forest_maze()
    assert_cantlin_route_group(42, 108, {
        {x = 42, y = 111},
        {x = 41, y = 111},
        {x = 41, y = 112},
        {x = 40, y = 112},
        {x = 40, y = 113},
        {x = 39, y = 113},
        {x = 39, y = 114},
        {x = 38, y = 114},
        {x = 38, y = 115},
        {x = 36, y = 115},
        {x = 36, y = 116},
        {x = 33, y = 116},
        {x = 33, y = 117},
        {x = 21, y = 117},
        {x = 21, y = 116},
        {x = 20, y = 116},
    }, "southern forest maze")
end

function tests.cantlin_hauksness_joins_validated_final_approach()
    assert_cantlin_route_group(20, 116, {
        {x = 20, y = 108},
        {x = 22, y = 108},
        {x = 22, y = 107},
        {x = 23, y = 107},
        {x = 23, y = 95},
        {x = 22, y = 95},
        {x = 22, y = 89},
        {x = 24, y = 89},
        {x = 25, y = 89, final = true},
    }, "Hauksness final approach")
end

function tests.cantlin_hauksness_variant_does_not_steal_shared_approach()
    routes.reset_for_tests()

    local info, err = routes.start("hauksness", 0x01, 15, 93)

    assert_equal(err, nil, "ordinary Hauksness route should start at the established lower lane")
    assert_equal(info.route.id, "hauksness", "Cantlin variant should not steal the shared Hauksness approach")
    assert_equal(info.object_id, "route_hauksness_86", "existing Hauksness route should retain its west-approach target")

    routes.reset_for_tests()
end

function tests.entering_hauksness_stops_cantlin_variant()
    routes.reset_for_tests()
    local info, err = routes.start("cantlin to hauksness", 0x01, 73, 102)

    assert_equal(err, nil, "Cantlin Hauksness alias should start before destination arrival")
    assert_equal(info.route.id, "hauksness_cantlin", "Cantlin Hauksness alias should select the local variant")

    local event = routes.observe_position(0x03, 0, 0)

    assert_contains(event.message, "Arrived at Hauksness", "entering Hauksness should complete the Cantlin variant")
    assert_equal(event.refresh, true, "Hauksness arrival should refresh Travel objects")
    assert_equal(routes.is_active(), false, "Cantlin variant should stop after entering Hauksness")

    routes.reset_for_tests()
end

function tests.cantlin_object_from_hauksness_uses_reverse_variant()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_cantlin",
        name = "Cantlin",
        x = 73,
        y = 102,
    }, 0x01, 25, 89)

    assert_equal(err, nil, "Cantlin Travel object should start at Hauksness")
    assert_equal(info.route.id, "cantlin_hauksness", "Cantlin object should choose the Hauksness variant")
    assert_equal(info.object_id, "route_cantlin_hauksness_02", "Hauksness start should skip the current entrance anchor")
    assert_contains(info.message, "Hauksness doorstep west", "route should begin west from Hauksness")

    local segment = assert(routes.plan_next_segment(0x01, 25, 89))
    assert_equal(segment.waypoint.x, 24, "first reverse target x")
    assert_equal(segment.waypoint.y, 89, "first reverse target y")
    assert_equal(segment.steps[1], "left", "first reverse step should leave Hauksness to the west")

    routes.reset_for_tests()
end

function tests.cantlin_object_from_tantegel_starts_three_leg_itinerary()
    routes.reset_for_tests()
    local target = {
        id = "overworld_cantlin",
        name = "Cantlin",
        x = 73,
        y = 102,
    }

    local info, err = routes.start_for_object(target, 0x01, 43, 43)

    assert_equal(err, nil, "Cantlin Travel object should resolve from Tantegel")
    assert_equal(info.route.id, "kol_staging",
        "far Cantlin requests should start on the established Kol route")
    assert_equal(info.object_id, "route_kol_staging_02",
        "Cantlin staging should leave Tantegel through the first Kol movement waypoint")
    assert_contains(info.message, "Cantlin route starts from Kol",
        "staging speech should retain Cantlin as the final destination")
    assert_contains(info.message, "Starting route to Kol first",
        "staging speech should identify the route that actually started")
    assert_contains(info.log, "staged_from=cantlin_hauksness",
        "structured logs should retain the final Cantlin route")
    assert_equal(routes.active_route_matches_object(target), true,
        "the selected Cantlin object should remain bound during the Kol leg")

    local segment = assert(routes.plan_next_segment(0x01, 43, 43))
    assert_equal(segment.waypoint.name, "Brecconary west bypass",
        "the first Cantlin leg should reuse the validated Kol route")
    assert_equal(segment.steps[1], "up",
        "the staged Cantlin itinerary should leave Tantegel toward the Brecconary bypass")

    routes.reset_for_tests()
end

function tests.cantlin_alias_from_tantegel_starts_three_leg_itinerary()
    routes.reset_for_tests()

    local info, err = routes.start("cantlin", 0x01, 43, 43)

    assert_equal(err, nil, "plain Cantlin alias should resolve")
    assert_equal(info.route.id, "kol_staging",
        "plain Cantlin alias should use the same staged itinerary as the Travel object")
    assert_equal(info.object_id, "route_kol_staging_02",
        "plain Cantlin alias should start at the first Kol movement waypoint")

    routes.reset_for_tests()
    info, err = routes.start("cantlin", 0x01, 25, 89)
    assert_equal(err, nil, "plain Cantlin alias should resolve at Hauksness")
    assert_equal(info.route.id, "cantlin_hauksness",
        "Hauksness-side plain alias should remain on the local validated route")

    routes.reset_for_tests()
    info, err = routes.start("cantlin", 0x01, 89, 112)
    assert_equal(err, nil, "plain Cantlin alias should resolve at the Great Swamp")
    assert_equal(info.route.id, "cantlin_great_swamp",
        "Great-Swamp-side plain alias should remain on the local validated route")

    routes.reset_for_tests()
end

function tests.cantlin_staging_hands_off_through_kol_and_hauksness()
    routes.reset_for_tests()
    local target = {
        id = "overworld_cantlin",
        name = "Cantlin",
        x = 73,
        y = 102,
    }
    assert(routes.start_for_object(target, 0x01, 43, 43))

    local kol = assert(routes._route_for_tests("kol_staging"))
    local event
    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    assert_equal(event.status, "handoff",
        "Kol arrival should be an itinerary handoff")
    assert_equal(routes.active_route_id(), "hauksness_staging",
        "Kol arrival should activate the non-entry Hauksness staging leg")
    assert_contains(event.message, "Reached Kol west doorstep. Continuing toward Cantlin.",
        "the intermediate handoff should retain the final destination")
    assert_contains(event.message, "Current leg to Hauksness. Final destination: Cantlin.",
        "the intermediate handoff should name both remaining legs")
    assert_equal(event.object_id, "route_hauksness_staging_02",
        "the Hauksness leg should begin west of Kol")
    assert_equal(event.steps, nil,
        "an intermediate handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "Cantlin should remain the selected Travel object during the Hauksness leg")

    local hauksness = assert(routes._route_for_tests("hauksness_staging"))
    local final = assert(hauksness.waypoints[#hauksness.waypoints])
    assert_equal(final.x, 24,
        "Cantlin staging should stop west of the Hauksness entrance")
    assert_equal(final.y, 89,
        "Hauksness staging should remain on the doorstep row")
    for index = 2, #hauksness.waypoints do
        local waypoint = hauksness.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    assert_equal(event.status, "handoff",
        "Hauksness arrival should hand off to the final Cantlin leg")
    assert_equal(routes.active_route_id(), "cantlin_hauksness",
        "Hauksness arrival should activate the validated Cantlin route")
    assert_contains(event.message, "Reached Hauksness doorstep west. Continuing to Cantlin.",
        "the final handoff should retain the existing two-leg wording")
    assert_equal(event.object_id, "route_cantlin_hauksness_03",
        "the Cantlin leg should advance west from the already-reached doorstep")
    local segment = assert(routes.plan_next_segment(0x01, 24, 89))
    assert_equal(segment.waypoint.x, 22,
        "the post-handoff Cantlin target should be the west approach")
    assert_equal(segment.waypoint.y, 89,
        "the post-handoff Cantlin target should stay on the doorway row")
    assert_equal(segment.steps[1], "left",
        "the post-handoff Cantlin leg should move away from Hauksness")
    assert_equal(event.steps, nil,
        "the final handoff must wait for the next auto-walk request")
    assert_equal(routes.active_route_matches_object(target), true,
        "Cantlin should remain bound after its final leg becomes active")

    routes.reset_for_tests()
end

function tests.cantlin_itinerary_survives_guidance_refresh_and_town_entries()
    routes.reset_for_tests()
    local target = {
        id = "overworld_cantlin",
        name = "Cantlin",
        x = 73,
        y = 102,
    }
    assert(routes.start_for_object(target, 0x01, 43, 43))

    local refreshed = routes.guidance_for_object(target, 0x01, 43, 43)
    assert_equal(refreshed.route.id, "kol_staging",
        "guidance refresh should keep the first itinerary leg active")
    assert_contains(refreshed.message, "Current leg to Kol",
        "refreshed guidance should identify the active Kol leg")
    assert_contains(refreshed.message, "Final destination: Cantlin",
        "refreshed guidance should retain Cantlin")

    local kol_entry = routes.observe_position(0x07, 15, 14)
    assert_equal(kol_entry.status, "handoff",
        "entering Kol should hand off without requiring an overworld arrival frame")
    assert_equal(routes.active_route_id(), "hauksness_staging",
        "Kol entry should activate the non-entry Hauksness staging leg")

    refreshed = routes.guidance_for_object(target, 0x01, 104, 10)
    assert_equal(refreshed.route.id, "hauksness_staging",
        "guidance refresh should keep the intermediate Hauksness leg active")
    assert_contains(refreshed.message, "Current leg to Hauksness",
        "intermediate guidance should identify Hauksness")
    assert_contains(refreshed.message, "Final destination: Cantlin",
        "intermediate guidance should still retain Cantlin")

    local hauksness_entry = routes.observe_position(0x03, 0, 0)
    assert_equal(hauksness_entry.status, "handoff",
        "entering Hauksness should hand off to the final leg")
    assert_equal(routes.active_route_id(), "cantlin_hauksness",
        "Hauksness entry should activate the final Cantlin route")
    assert_equal(hauksness_entry.object_id, "route_cantlin_hauksness_03",
        "town-entry fallback should target the west approach toward Cantlin")

    routes.reset_for_tests()
end

function tests.stopping_cantlin_itinerary_clears_remaining_legs()
    routes.reset_for_tests()
    local target = {
        id = "overworld_cantlin",
        name = "Cantlin",
        x = 73,
        y = 102,
    }
    assert(routes.start_for_object(target, 0x01, 43, 43))

    local stopped = routes.stop()

    assert_contains(stopped.message, "Stopped overworld route",
        "the staged itinerary should stop normally")
    assert_equal(routes.is_active(), false,
        "stopping should clear the active Kol leg")
    assert_equal(routes.active_route_matches_object(target), false,
        "stopping should also clear the queued Cantlin destination")

    routes.reset_for_tests()
end

function tests.cantlin_hauksness_aliases_are_unambiguous()
    local aliases = {
        "cantlin from hauksness",
        "hauksness to cantlin",
        "return to cantlin",
    }

    for _, alias in ipairs(aliases) do
        routes.reset_for_tests()
        local info, err = routes.start(alias, 0x01, 25, 89)
        assert_equal(err, nil, alias .. " should resolve")
        assert_equal(info.route.id, "cantlin_hauksness", alias .. " should select the Cantlin route")
    end

    routes.reset_for_tests()
    local kol_info, kol_err = routes.start("return from hauksness", 0x01, 25, 89)
    assert_equal(kol_err, nil, "existing Kol return alias should still resolve")
    assert_equal(kol_info.route.id, "kol_hauksness", "Cantlin route must not steal the Kol return alias")

    routes.reset_for_tests()
end

function tests.cantlin_hauksness_reverses_validated_route_with_live_carry_splices()
    local outbound = assert(routes._route_for_tests("hauksness_cantlin"))
    local inbound = assert(routes._route_for_tests("cantlin_hauksness"))
    local reversed = {}

    for index = #outbound.waypoints, 1, -1 do
        reversed[#reversed + 1] = outbound.waypoints[index]
    end

    assert_equal(#inbound.waypoints, 57, "Cantlin reverse route waypoint count")
    for index = 1, 40 do
        assert_equal(inbound.waypoints[index].x, reversed[index].x, "reverse waypoint " .. index .. " x")
        assert_equal(inbound.waypoints[index].y, reversed[index].y, "reverse waypoint " .. index .. " y")
    end

    assert_equal(inbound.waypoints[41].x, 50, "live carry splice x")
    assert_equal(inbound.waypoints[41].y, 98, "live carry splice y")

    for index = 42, 53 do
        local expected = reversed[index + 1]
        assert_equal(inbound.waypoints[index].x, expected.x, "post-splice waypoint " .. index .. " x")
        assert_equal(inbound.waypoints[index].y, expected.y, "post-splice waypoint " .. index .. " y")
    end

    assert_equal(inbound.waypoints[54].x, 64, "upper-lane carry splice x")
    assert_equal(inbound.waypoints[54].y, 91, "upper-lane carry splice y")

    for index = 55, #inbound.waypoints do
        local expected = reversed[index + 1]
        assert_equal(inbound.waypoints[index].x, expected.x, "post-upper-splice waypoint " .. index .. " x")
        assert_equal(inbound.waypoints[index].y, expected.y, "post-upper-splice waypoint " .. index .. " y")
    end

    assert_equal(inbound.waypoints[1].radius, 0, "Hauksness start anchor should be strict")
    assert_equal(inbound.waypoints[57].radius, 0, "Cantlin final anchor should be strict")
    assert_equal(inbound.waypoints[57].final, true, "Cantlin final anchor should finish the route")
end

function tests.cantlin_hauksness_marks_unstable_north_entry_for_sustained_hold()
    local route = assert(routes._route_for_tests("cantlin_hauksness"))
    local waypoint = assert(route.waypoints[40])

    assert_equal(waypoint.x, 50, "timing marker waypoint x")
    assert_equal(waypoint.y, 99, "timing marker waypoint y")
    assert_equal(
        waypoint.route_hold_after_movement_start_frames,
        60,
        "reverse route should sustain the north press through the early movement twitch"
    )
    assert_equal(
        waypoint.route_early_twitch_timeout_frames,
        60,
        "reverse route should wait through the observed late tile completion"
    )
    assert_equal(
        waypoint.route_reset_movement_on_turn_settle,
        false,
        "reverse route should preserve the observed north carry during final settle"
    )
    assert_equal(route.waypoints[41].x, 50, "north carry target x")
    assert_equal(route.waypoints[41].y, 98, "north carry target y")
end

function tests.cantlin_hauksness_north_entry_previews_observed_carry()
    routes.reset_for_tests()
    local info, err = routes.start("hauksness to cantlin", 0x01, 50, 100)

    assert_equal(err, nil, "Cantlin reverse route should start at the north-entry seam")
    assert_equal(info.route.id, "cantlin_hauksness", "north-entry seam should retain the reverse route")

    local segment = assert(routes.plan_next_segment(0x01, 50, 100))
    assert_equal(segment.waypoint.x, 50, "north-entry target x")
    assert_equal(segment.waypoint.y, 99, "north-entry target y")
    assert_equal(segment.route_final_carry_x, 50, "north-entry carry x")
    assert_equal(segment.route_final_carry_y, 98, "north-entry carry y")

    routes.reset_for_tests()
end

function tests.cantlin_hauksness_upper_lane_previews_observed_carry()
    local route = assert(routes._route_for_tests("cantlin_hauksness"))
    local waypoint = assert(route.waypoints[53])

    assert_equal(waypoint.x, 64, "upper-lane timing marker x")
    assert_equal(waypoint.y, 92, "upper-lane timing marker y")
    assert_equal(waypoint.route_hold_after_movement_start_frames, 60, "upper-lane sustained hold")
    assert_equal(waypoint.route_early_twitch_timeout_frames, 60, "upper-lane twitch window")
    assert_equal(waypoint.route_reset_movement_on_turn_settle, false, "upper-lane carry preservation")
    assert_equal(route.waypoints[54].x, 64, "upper-lane carry target x")
    assert_equal(route.waypoints[54].y, 91, "upper-lane carry target y")

    routes.reset_for_tests()
    local info, err = routes.start("hauksness to cantlin", 0x01, 64, 93)
    assert_equal(err, nil, "Cantlin reverse route should start at the upper-lane seam")
    assert_equal(info.route.id, "cantlin_hauksness", "upper-lane seam should retain the reverse route")

    local segment = assert(routes.plan_next_segment(0x01, 64, 93))
    assert_equal(segment.waypoint.x, 64, "upper-lane target x")
    assert_equal(segment.waypoint.y, 92, "upper-lane target y")
    assert_equal(segment.route_final_carry_x, 64, "upper-lane carry x")
    assert_equal(segment.route_final_carry_y, 91, "upper-lane carry y")

    routes.reset_for_tests()
end

function tests.cantlin_hauksness_final_recovery_corrects_column_before_descent()
    local route = assert(routes._route_for_tests("cantlin_hauksness"))
    local cantlin = assert(route.waypoints[57])

    assert_equal(cantlin.x, 73, "Cantlin final waypoint x")
    assert_equal(cantlin.y, 102, "Cantlin final waypoint y")
    assert_equal(cantlin.axis_order and cantlin.axis_order[1], "horizontal", "Cantlin recovery first axis")
    assert_equal(cantlin.axis_order and cantlin.axis_order[2], "vertical", "Cantlin recovery second axis")

    routes.reset_for_tests()
    local info, err = routes.start("hauksness to cantlin", 0x01, 74, 99)
    assert_equal(err, nil, "Cantlin reverse route should recover from the east column")
    assert_equal(info.route.id, "cantlin_hauksness", "east-column recovery should retain the reverse route")

    local segment = assert(routes.plan_next_segment(0x01, 74, 99))
    assert_equal(segment.waypoint.x, 73, "Cantlin recovery target x")
    assert_equal(segment.waypoint.y, 102, "Cantlin recovery target y")
    assert_equal(segment.steps[1], "left", "Cantlin recovery should correct west before descending")

    routes.reset_for_tests()
end

function tests.active_hauksness_cantlin_route_matches_ordinary_cantlin_object()
    routes.reset_for_tests()
    routes.start("hauksness to cantlin", 0x01, 25, 89)

    local matches = routes.active_route_matches_object({
        id = "overworld_cantlin",
        name = "Cantlin",
        x = 73,
        y = 102,
    })

    assert_equal(matches, true, "active reverse route should retain the ordinary Cantlin destination")
    routes.reset_for_tests()
end

function tests.entering_cantlin_stops_hauksness_variant()
    routes.reset_for_tests()
    local info, err = routes.start("hauksness to cantlin", 0x01, 25, 89)

    assert_equal(err, nil, "Hauksness Cantlin alias should start")
    assert_equal(info.route.id, "cantlin_hauksness", "alias should select the reverse route")

    local event = routes.observe_position(0x0A, 15, 0)

    assert_contains(event.message, "Arrived at Cantlin", "entering Cantlin should complete the reverse route")
    assert_equal(event.refresh, true, "Cantlin arrival should refresh Travel objects")
    assert_equal(routes.is_active(), false, "reverse route should stop after entering Cantlin")

    routes.reset_for_tests()
end

function tests.great_swamp_from_tantegel_starts_connected_cantlin_itinerary()
    routes.reset_for_tests()
    local target = {
        id = "overworld_eastern_great_swamp_search_area",
        name = "Eastern Great Swamp Search Area",
        x = 89,
        y = 112,
    }

    local info, err = routes.start_for_object(target, 0x01, 43, 43)

    assert_equal(err, nil,
        "Great Swamp Travel object should resolve from Tantegel")
    assert_equal(info.route.id, "kol_staging",
        "far Great Swamp requests should start on the established Kol route")
    assert_equal(info.object_id, "route_kol_staging_02",
        "Great Swamp staging should leave Tantegel through the first Kol movement waypoint")
    assert_contains(info.message,
        "Eastern Great Swamp Search Area route starts from Kol",
        "staging speech should retain the search area as the final destination")
    assert_contains(info.log, "staged_from=great_swamp_cantlin",
        "structured logs should retain the final Great Swamp route")
    assert_equal(routes.active_route_matches_object(target), true,
        "the selected search-area object should remain bound during the Kol leg")

    local segment = assert(routes.plan_next_segment(0x01, 43, 43))
    assert_equal(segment.waypoint.name, "Brecconary west bypass",
        "the first Great Swamp leg should reuse the validated Kol route")

    routes.reset_for_tests()
end

function tests.great_swamp_connected_itinerary_hands_off_at_cantlin()
    routes.reset_for_tests()
    local target = {
        id = "overworld_eastern_great_swamp_search_area",
        name = "Eastern Great Swamp Search Area",
        x = 89,
        y = 112,
    }
    assert(routes.start_for_object(target, 0x01, 43, 43))

    local kol = assert(routes._route_for_tests("kol_staging"))
    local event
    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "Kol arrival should hand off within the Great Swamp itinerary")
    assert_equal(routes.active_route_id(), "hauksness_staging",
        "Kol arrival should activate the non-entry Hauksness leg")

    local hauksness = assert(routes._route_for_tests("hauksness_staging"))
    for index = 2, #hauksness.waypoints do
        local waypoint = hauksness.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "Hauksness arrival should hand off within the Great Swamp itinerary")
    assert_equal(routes.active_route_id(), "cantlin_staging",
        "Hauksness arrival should activate the non-entry Cantlin staging leg")

    local cantlin = assert(routes._route_for_tests("cantlin_staging"))
    local final = assert(cantlin.waypoints[#cantlin.waypoints])
    assert_equal(final.x, 68,
        "Cantlin staging should finish at the northwest turn")
    assert_equal(final.y, 91,
        "Cantlin staging should stop before the town entrance")
    assert_equal(final.name, "Cantlin northwest turn",
        "the staging endpoint should identify the safe pass-through handoff")
    for index = 3, #cantlin.waypoints do
        local waypoint = cantlin.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    assert_equal(event.status, "handoff",
        "reaching Cantlin northwest turn should hand off to the Great Swamp leg")
    assert_equal(routes.active_route_id(), "great_swamp_cantlin",
        "the exterior Cantlin handoff should activate the Great Swamp destination")
    assert_equal(event.object_id, "route_great_swamp_cantlin_04",
        "the exterior handoff should target the southbound forest notch")
    assert_equal(event.steps, nil,
        "the exterior Cantlin handoff must not inject movement")
    assert_contains(event.message,
        "Reached Cantlin northwest turn. Continuing to Eastern Great Swamp Search Area.",
        "the final handoff should retain the search-area destination")
    assert_equal(routes.active_route_matches_object(target), true,
        "the search-area object should remain bound after the Cantlin handoff")

    local segment = assert(routes.plan_next_segment(0x01, 68, 91))
    assert_equal(segment.waypoint.x, 68,
        "the post-Cantlin target should remain on the forest-notch column")
    assert_equal(segment.waypoint.y, 92,
        "the post-Cantlin target should enter the upper forest")
    assert_equal(segment.steps[1], "down",
        "the final Great Swamp leg should avoid the Cantlin entrance")

    routes.reset_for_tests()
end

function tests.great_swamp_cantlin_staging_preserves_accidental_entry_fallback()
    routes.reset_for_tests()
    assert(routes.start(
        "great swamp search area", 0x01, 25, 89))

    assert_equal(routes.active_route_id(), "cantlin_staging",
        "Hauksness-side Great Swamp travel should use Cantlin staging")

    local event = routes.observe_position(0x0A, 15, 0)

    assert_equal(event.status, "handoff",
        "accidental Cantlin entry should still hand off to the Great Swamp leg")
    assert_equal(routes.active_route_id(), "great_swamp_cantlin",
        "town-entry fallback should preserve the Great Swamp destination")
    assert_equal(event.steps, nil,
        "town-entry fallback must not inject movement inside Cantlin")

    routes.reset_for_tests()
end

function tests.great_swamp_direct_cantlin_start_stays_local()
    routes.reset_for_tests()

    local info, err = routes.start(
        "great swamp search area", 0x01, 73, 102)

    assert_equal(err, nil, "Great Swamp alias should resolve at Cantlin")
    assert_equal(info.route.id, "great_swamp_cantlin",
        "Cantlin starts should remain on the local live-validated route")
    assert_equal(info.object_id, "route_great_swamp_cantlin_02",
        "Cantlin starts should skip the current entrance anchor")

    routes.reset_for_tests()
end

function tests.great_swamp_search_area_alias_and_object_start_cantlin_route()
    routes.reset_for_tests()

    local info, err = routes.start(
        "great swamp search area", 0x01, 73, 102)

    assert_equal(err, nil, "Great Swamp search-area alias should resolve")
    assert_equal(info.route.id, "great_swamp_cantlin",
        "Cantlin start should use the Great Swamp route")
    assert_equal(info.object_id, "route_great_swamp_cantlin_02",
        "Cantlin start should skip the current entrance anchor")
    assert_contains(info.message, "Cantlin north road",
        "Great Swamp route should reuse the live Cantlin departure")

    routes.reset_for_tests()
    local object_info, object_err = routes.start_for_object({
        id = "overworld_eastern_great_swamp_search_area",
        name = "Eastern Great Swamp Search Area",
        x = 89,
        y = 112,
    }, 0x01, 73, 102)

    assert_equal(object_err, nil,
        "search-area Travel object should start guidance from Cantlin")
    assert_equal(object_info.route.id, "great_swamp_cantlin",
        "search-area object should select the Cantlin route")

    routes.reset_for_tests()
end

function tests.great_swamp_cantlin_preserves_live_outbound_geometry()
    local route = assert(routes._route_for_tests("great_swamp_cantlin"))
    local expected = {
        {73, 102}, {73, 91}, {68, 91}, {68, 92}, {64, 92}, {64, 93},
        {60, 93}, {60, 94}, {56, 94}, {56, 95}, {54, 95}, {54, 96},
        {53, 96}, {53, 97}, {52, 97}, {52, 98}, {51, 98}, {51, 99},
        {50, 99}, {50, 100}, {49, 100}, {49, 102}, {48, 102},
        {48, 104}, {59, 104}, {59, 105}, {63, 105}, {63, 106},
        {64, 106}, {64, 108}, {66, 108}, {66, 110}, {72, 110},
        {72, 112}, {74, 112}, {74, 113}, {89, 113}, {89, 112},
    }

    assert_equal(#route.waypoints, #expected,
        "outbound route should contain only live-proven anchors")
    for index, coordinate in ipairs(expected) do
        local waypoint = route.waypoints[index]
        assert_equal(waypoint.x, coordinate[1],
            "outbound waypoint " .. index .. " x")
        assert_equal(waypoint.y, coordinate[2],
            "outbound waypoint " .. index .. " y")
        assert_equal(waypoint.radius, 0,
            "outbound waypoint " .. index .. " should be strict")
    end

    routes.reset_for_tests()
    routes.start("great swamp search area", 0x01, 73, 102)
    local x, y = 73, 102
    for index = 2, #expected do
        local coordinate = expected[index]
        local segment = assert(routes.plan_next_segment(0x01, x, y))
        local expected_first
        if coordinate[1] > x then
            expected_first = "right"
        elseif coordinate[1] < x then
            expected_first = "left"
        elseif coordinate[2] > y then
            expected_first = "down"
        else
            expected_first = "up"
        end
        assert_equal(segment.steps[1], expected_first,
            "outbound segment " .. index .. " first direction")
        if index < #expected then
            routes.observe_position(0x01, coordinate[1], coordinate[2])
            x, y = coordinate[1], coordinate[2]
        else
            assert_equal(segment.path_length, 1,
                "safe-pin entry should be one strict north step")
        end
    end

    routes.reset_for_tests()
end

function tests.great_swamp_cantlin_arrival_preserves_clue_boundary()
    local route = assert(routes._route_for_tests("great_swamp_cantlin"))
    local final = route.waypoints[#route.waypoints]

    assert_equal(final.x, 89, "outbound safe pin x")
    assert_equal(final.y, 112, "outbound safe pin y")
    assert_equal(final.final, true, "safe pin should finish the route")
    assert_contains(final.warning, "Gwaelin's Love",
        "arrival should preserve the intended coordinate tool")
    assert_contains(final.warning, "Search",
        "arrival should preserve the intended interaction")

    for _, alias in ipairs(route.aliases or {}) do
        local normalized = alias:lower()
        assert_equal(normalized:find("token", 1, true), nil,
            "route aliases should not name the token")
        assert_equal(normalized:find("erdrick", 1, true), nil,
            "route aliases should not name Erdrick")
    end
    for _, waypoint in ipairs(route.waypoints) do
        assert_equal(waypoint.x == 83 and waypoint.y == 113, false,
            "outbound route must not target the buried square")
        local normalized = waypoint.name:lower()
        assert_equal(normalized:find("token", 1, true), nil,
            "waypoint names should not name the token")
        assert_equal(normalized:find("erdrick", 1, true), nil,
            "waypoint names should not name Erdrick")
    end

    routes.reset_for_tests()
    routes.start("great swamp search area", 0x01, 73, 102)
    local event
    for index = 2, #route.waypoints do
        local waypoint = route.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    assert_contains(event.message,
        "Arrived at Eastern Great Swamp Search Area",
        "safe-pin arrival should name only the search area")
    assert_contains(event.message,
        "Use Gwaelin's Love and Search to continue",
        "safe-pin arrival should preserve clue-driven discovery")
    assert_equal(routes.is_active(), false,
        "safe-pin arrival should stop route guidance")

    routes.reset_for_tests()
end

function tests.cantlin_object_from_great_swamp_uses_return_variant()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_cantlin",
        name = "Cantlin",
        x = 73,
        y = 102,
    }, 0x01, 89, 112)

    assert_equal(err, nil,
        "Cantlin Travel object should start at the Great Swamp safe pin")
    assert_equal(info.route.id, "cantlin_great_swamp",
        "Cantlin object should choose the Great Swamp return variant")
    assert_equal(info.object_id, "route_cantlin_great_swamp_02",
        "safe-pin start should target the live south departure")

    local segment = assert(routes.plan_next_segment(0x01, 89, 112))
    assert_equal(segment.waypoint.x, 89, "first return target x")
    assert_equal(segment.waypoint.y, 113, "first return target y")
    assert_equal(segment.steps[1], "down",
        "first return step should leave the safe pin southward")

    routes.reset_for_tests()
end

function tests.cantlin_great_swamp_aliases_are_unambiguous()
    local aliases = {
        "great swamp to cantlin",
        "cantlin from great swamp",
        "return to cantlin from great swamp",
    }

    for _, alias in ipairs(aliases) do
        routes.reset_for_tests()
        local info, err = routes.start(alias, 0x01, 89, 112)
        assert_equal(err, nil, alias .. " should resolve")
        assert_equal(info.route.id, "cantlin_great_swamp",
            alias .. " should select the Cantlin return route")
    end

    routes.reset_for_tests()
end

function tests.cantlin_great_swamp_preserves_live_return_geometry()
    local route = assert(routes._route_for_tests("cantlin_great_swamp"))
    local expected = {
        {89, 112}, {89, 113}, {75, 113}, {73, 113}, {73, 111},
        {71, 111}, {71, 110}, {65, 110}, {65, 108}, {63, 108},
        {63, 106}, {63, 105}, {59, 105}, {59, 104}, {48, 104},
        {48, 102}, {49, 102}, {49, 100}, {50, 100}, {50, 99},
        {50, 98}, {52, 98}, {52, 97}, {53, 97}, {53, 96}, {54, 96},
        {54, 95}, {56, 95}, {56, 94}, {60, 94}, {60, 93}, {64, 93},
        {64, 92}, {64, 91}, {68, 91}, {73, 91}, {73, 102},
    }

    assert_equal(#route.waypoints, #expected,
        "return route should contain only live-proven anchors")
    for index, coordinate in ipairs(expected) do
        local waypoint = route.waypoints[index]
        assert_equal(waypoint.x, coordinate[1],
            "return waypoint " .. index .. " x")
        assert_equal(waypoint.y, coordinate[2],
            "return waypoint " .. index .. " y")
        assert_equal(waypoint.radius, 0,
            "return waypoint " .. index .. " should be strict")
        assert_equal(waypoint.x == 83 and waypoint.y == 113, false,
            "return route must not target the buried square")
    end

    routes.reset_for_tests()
    routes.start("great swamp to cantlin", 0x01, 89, 112)
    local x, y = 89, 112
    for index = 2, #expected do
        local coordinate = expected[index]
        local segment = assert(routes.plan_next_segment(0x01, x, y))
        local expected_first
        if coordinate[1] > x then
            expected_first = "right"
        elseif coordinate[1] < x then
            expected_first = "left"
        elseif coordinate[2] > y then
            expected_first = "down"
        else
            expected_first = "up"
        end
        assert_equal(segment.steps[1], expected_first,
            "return segment " .. index .. " first direction")
        routes.observe_position(0x01, coordinate[1], coordinate[2])
        x, y = coordinate[1], coordinate[2]
    end

    assert_equal(routes.is_active(), false,
        "Cantlin arrival should stop the return route")
    routes.reset_for_tests()
end

function tests.cantlin_great_swamp_retains_shared_carry_metadata()
    local route = assert(routes._route_for_tests("cantlin_great_swamp"))
    local north_entry = route.waypoints[20]
    local upper_lane = route.waypoints[33]

    assert_equal(north_entry.x, 50, "north-entry timing marker x")
    assert_equal(north_entry.y, 99, "north-entry timing marker y")
    assert_equal(north_entry.route_hold_after_movement_start_frames, 60,
        "north-entry route should sustain the live-confirmed press")
    assert_equal(north_entry.route_early_twitch_timeout_frames, 60,
        "north-entry route should retain the late-completion window")
    assert_equal(north_entry.route_reset_movement_on_turn_settle, false,
        "north-entry route should preserve observed carry")
    assert_equal(route.waypoints[21].x, 50, "north-entry carry target x")
    assert_equal(route.waypoints[21].y, 98, "north-entry carry target y")

    assert_equal(upper_lane.x, 64, "upper-lane timing marker x")
    assert_equal(upper_lane.y, 92, "upper-lane timing marker y")
    assert_equal(upper_lane.route_hold_after_movement_start_frames, 60,
        "upper-lane route should sustain the live-confirmed press")
    assert_equal(upper_lane.route_early_twitch_timeout_frames, 60,
        "upper-lane route should retain the late-completion window")
    assert_equal(upper_lane.route_reset_movement_on_turn_settle, false,
        "upper-lane route should preserve observed carry")
    assert_equal(route.waypoints[34].x, 64, "upper-lane carry target x")
    assert_equal(route.waypoints[34].y, 91, "upper-lane carry target y")
end

function tests.great_swamp_return_does_not_steal_hauksness_cantlin_route()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_cantlin",
        name = "Cantlin",
        x = 73,
        y = 102,
    }, 0x01, 25, 89)

    assert_equal(err, nil, "Cantlin Travel object should still start at Hauksness")
    assert_equal(info.route.id, "cantlin_hauksness",
        "Great Swamp variant must not steal the Hauksness return")

    routes.reset_for_tests()
end

function tests.arriving_at_cantlin_stops_great_swamp_return()
    local route = assert(routes._route_for_tests("cantlin_great_swamp"))
    routes.reset_for_tests()
    routes.start("great swamp to cantlin", 0x01, 89, 112)

    local event
    for index = 2, #route.waypoints do
        local waypoint = route.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    assert_contains(event.message, "Arrived at Cantlin",
        "return arrival should name Cantlin")
    assert_equal(event.refresh, true,
        "Cantlin arrival should refresh Travel objects")
    assert_equal(routes.is_active(), false,
        "Cantlin arrival should stop guidance")

    routes.reset_for_tests()
end

function tests.tantegel_object_from_great_swamp_starts_reverse_connected_itinerary()
    routes.reset_for_tests()
    local target = {
        id = "overworld_tantegel_castle",
        name = "Tantegel Castle",
        x = 43,
        y = 43,
    }

    local info, err = routes.start_for_object(target, 0x01, 89, 112)

    assert_equal(err, nil,
        "Tantegel Travel object should start at the Great Swamp safe pin")
    assert_equal(info.route.id, "cantlin_return_staging",
        "Great Swamp return should begin on the exterior Cantlin leg")
    assert_equal(info.object_id, "route_cantlin_return_staging_02",
        "the first reverse target should leave the search-area safe pin")
    assert_contains(info.message, "Tantegel Castle route starts from Cantlin northwest turn",
        "reverse staging speech should retain the final castle destination")
    assert_equal(routes.active_route_matches_object(target), true,
        "the Tantegel Travel object should remain bound during the reverse itinerary")

    local segment = assert(routes.plan_next_segment(0x01, 89, 112))
    assert_equal(segment.waypoint.name, "Great Swamp east lane",
        "the reverse itinerary should reuse the validated Great Swamp departure")
    assert_equal(segment.steps[1], "down",
        "the reverse itinerary should leave the safe pin southward")

    routes.reset_for_tests()
end

function tests.great_swamp_tantegel_itinerary_hands_off_outside_each_town()
    routes.reset_for_tests()
    local target = {
        id = "overworld_tantegel_castle",
        name = "Tantegel Castle",
        x = 43,
        y = 43,
    }
    assert(routes.start_for_object(target, 0x01, 89, 112))

    local cantlin = assert(routes._route_for_tests("cantlin_return_staging"))
    local event
    for index = 2, #cantlin.waypoints do
        local waypoint = cantlin.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "Cantlin northwest arrival should hand off within the reverse itinerary")
    assert_equal(routes.active_route_id(), "hauksness_return_staging",
        "Cantlin should hand off to the non-entry Hauksness return leg")
    assert_equal(event.object_id, "route_hauksness_return_staging_04",
        "Cantlin handoff should continue south of the northwest turn")
    assert_equal(event.steps, nil,
        "Cantlin exterior handoff must not inject movement")
    assert_equal(cantlin.waypoints[#cantlin.waypoints].x, 68,
        "Cantlin return staging x")
    assert_equal(cantlin.waypoints[#cantlin.waypoints].y, 91,
        "Cantlin return staging y")

    local hauksness = assert(routes._route_for_tests("hauksness_return_staging"))
    for index = 4, #hauksness.waypoints do
        local waypoint = hauksness.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "Hauksness doorstep arrival should hand off within the reverse itinerary")
    assert_equal(routes.active_route_id(), "kol_return_staging",
        "Hauksness should hand off to the non-entry Kol return leg")
    assert_equal(event.object_id, "route_kol_return_staging_03",
        "Hauksness handoff should continue west of the ruins")
    assert_equal(event.steps, nil,
        "Hauksness exterior handoff must not inject movement")
    assert_equal(hauksness.waypoints[#hauksness.waypoints].x, 24,
        "Hauksness return staging x")
    assert_equal(hauksness.waypoints[#hauksness.waypoints].y, 89,
        "Hauksness return staging y")

    local kol = assert(routes._route_for_tests("kol_return_staging"))
    for index = 3, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "Kol doorstep arrival should hand off to the final castle leg")
    assert_equal(routes.active_route_id(), "tantegel_kol",
        "Kol should activate the established return route to Tantegel")
    assert_equal(event.object_id, "route_tantegel_kol_02",
        "Kol exterior handoff should depart through the forest west edge")
    assert_equal(event.steps, nil,
        "Kol exterior handoff must not inject movement")
    assert_equal(kol.waypoints[#kol.waypoints].x, 103,
        "Kol return staging should stop west of town")
    assert_equal(kol.waypoints[#kol.waypoints].y, 10,
        "Kol return staging y")
    assert_equal(routes.active_route_matches_object(target), true,
        "the Tantegel Travel object should remain bound after every handoff")

    local segment = assert(routes.plan_next_segment(0x01, 103, 10))
    assert_equal(segment.waypoint.name, "Kol forest west edge",
        "the final leg should bypass Kol and head toward Tantegel")
    assert_equal(segment.steps[1], "left",
        "the final leg should leave Kol westward")

    routes.reset_for_tests()
end

function tests.stopping_great_swamp_tantegel_itinerary_clears_remaining_legs()
    routes.reset_for_tests()
    assert(routes.start("tantegel", 0x01, 89, 112))

    local event = routes.stop()

    assert_contains(event.message, "Stopped overworld route",
        "explicit stop should acknowledge reverse-itinerary cancellation")
    assert_equal(routes.is_active(), false,
        "stopping should clear the active Great Swamp return leg")
    assert_equal(routes.observe_position(0x01, 68, 91), nil,
        "a stopped reverse itinerary must not resume at Cantlin")

    routes.reset_for_tests()
end

function tests.tantegel_object_from_hauksness_starts_kol_return_itinerary()
    routes.reset_for_tests()
    local target = {
        id = "overworld_tantegel_castle",
        name = "Tantegel Castle",
        x = 43,
        y = 43,
    }

    local info, err = routes.start_for_object(target, 0x01, 25, 89)

    assert_equal(err, nil,
        "Tantegel Travel object should start outside Hauksness")
    assert_equal(info.route.id, "kol_return_staging",
        "Hauksness return should begin on the proven Kol leg")
    assert_equal(info.object_id, "route_kol_return_staging_02",
        "Hauksness start should target the west doorstep")
    assert_contains(info.message, "Tantegel Castle route starts from Kol",
        "Hauksness staging speech should retain the final castle destination")
    assert_equal(routes.active_route_matches_object(target), true,
        "the Tantegel Travel object should remain bound during the Kol leg")

    local segment = assert(routes.plan_next_segment(0x01, 25, 89))
    assert_equal(segment.waypoint.name, "Hauksness doorstep west",
        "the return should leave the ruins through the validated west doorstep")
    assert_equal(segment.steps[1], "left",
        "the first return step should leave Hauksness westward")

    routes.reset_for_tests()
    local alias_info, alias_err = routes.start("tantegel", 0x01, 25, 89)
    assert_equal(alias_err, nil, "Tantegel alias should start outside Hauksness")
    assert_equal(alias_info.route.id, "kol_return_staging",
        "the plain alias should use the same connected return itinerary")

    routes.reset_for_tests()
end

function tests.hauksness_tantegel_itinerary_hands_off_outside_kol()
    routes.reset_for_tests()
    local target = {
        id = "overworld_tantegel_castle",
        name = "Tantegel Castle",
        x = 43,
        y = 43,
    }
    assert(routes.start_for_object(target, 0x01, 25, 89))

    local kol = assert(routes._route_for_tests("kol_return_staging"))
    local event
    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    assert_equal(event.status, "handoff",
        "Kol west-doorstep arrival should hand off to the final castle leg")
    assert_equal(routes.active_route_id(), "tantegel_kol",
        "Kol handoff should activate the established Tantegel return")
    assert_equal(event.object_id, "route_tantegel_kol_02",
        "the final leg should leave through Kol forest west edge")
    assert_equal(event.steps, nil,
        "the exterior Kol handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "the castle Travel object should remain bound after the handoff")

    routes.reset_for_tests()
end

function tests.tantegel_object_from_mountain_cave_starts_connected_return()
    routes.reset_for_tests()
    local target = {
        id = "overworld_tantegel_castle",
        name = "Tantegel Castle",
        x = 43,
        y = 43,
    }

    local info, err = routes.start_for_object(target, 0x01, 29, 57)

    assert_equal(err, nil,
        "Tantegel Travel object should start outside Mountain Cave")
    assert_equal(info.route.id, "mountain_cave_return",
        "Mountain Cave return should begin on the proven local reverse spur")
    assert_equal(info.object_id, "route_mountain_cave_return_02",
        "Mountain Cave return should first target the west approach")
    assert_contains(info.message, "Tantegel Castle route starts from Western desert east road",
        "Mountain Cave staging speech should retain the final castle destination")
    assert_equal(routes.active_route_matches_object(target), true,
        "the Tantegel Travel object should remain bound during the cave return")

    local segment = assert(routes.plan_next_segment(0x01, 29, 57))
    assert_equal(segment.waypoint.name, "Mountain Cave west approach",
        "the return itinerary should leave through the proven west approach")
    assert_equal(segment.steps[1], "left",
        "the first Mountain Cave return step should head west")

    routes.reset_for_tests()
    local alias_info, alias_err = routes.start("tantegel", 0x01, 29, 57)
    assert_equal(alias_err, nil,
        "Tantegel alias should start outside Mountain Cave")
    assert_equal(alias_info.route.id, "mountain_cave_return",
        "the plain alias should use the same connected return itinerary")

    routes.reset_for_tests()
end

function tests.mountain_cave_tantegel_itinerary_hands_off_to_kol_return()
    routes.reset_for_tests()
    local target = {
        id = "overworld_tantegel_castle",
        name = "Tantegel Castle",
        x = 43,
        y = 43,
    }
    assert(routes.start_for_object(target, 0x01, 29, 57))

    local cave_return = assert(routes._route_for_tests("mountain_cave_return"))
    local event
    for index = 2, #cave_return.waypoints do
        local waypoint = cave_return.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    assert_equal(event.status, "handoff",
        "western desert pin should hand off within the Tantegel itinerary")
    assert_equal(routes.active_route_id(), "kol_return_staging",
        "the local reverse spur should activate the exterior Kol return")
    assert_equal(event.steps, nil,
        "the Mountain Cave handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "the castle Travel object should remain bound after the cave handoff")

    local kol = assert(routes._route_for_tests("kol_return_staging"))
    local shared_pin_index
    for index, waypoint in ipairs(kol.waypoints) do
        if waypoint.x == 18 and waypoint.y == 64 then
            shared_pin_index = index
            break
        end
    end
    assert_equal(shared_pin_index ~= nil, true,
        "Kol return should contain the shared western desert pin")
    assert_equal(event.object_id,
        string.format("route_kol_return_staging_%02d", shared_pin_index + 1),
        "the handoff should continue beyond the already-reached shared pin")

    for index = shared_pin_index + 1, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "Kol west doorstep should hand off to the final castle leg")
    assert_equal(routes.active_route_id(), "tantegel_kol",
        "the second handoff should activate the established Tantegel return")
    assert_equal(event.object_id, "route_tantegel_kol_02",
        "the final leg should leave through Kol forest west edge")
    assert_equal(event.steps, nil,
        "the exterior Kol handoff must not inject movement")

    routes.reset_for_tests()
end

function tests.stopping_mountain_cave_tantegel_itinerary_clears_remaining_legs()
    routes.reset_for_tests()
    assert(routes.start("tantegel", 0x01, 29, 57))

    local event = routes.stop()

    assert_contains(event.message, "Stopped overworld route",
        "explicit stop should acknowledge Mountain Cave return cancellation")
    assert_equal(routes.is_active(), false,
        "stopping should clear the active Mountain Cave return leg")
    assert_equal(routes.observe_position(0x01, 18, 64), nil,
        "a stopped Mountain Cave itinerary must not resume at the shared pin")

    routes.reset_for_tests()
end

function tests.tantegel_object_from_northern_cave_starts_shrine_return_itinerary()
    routes.reset_for_tests()
    local target = {
        id = "overworld_tantegel_castle",
        name = "Tantegel Castle",
        x = 43,
        y = 43,
    }

    local info, err = routes.start_for_object(target, 0x01, 81, 1)

    assert_equal(err, nil,
        "Tantegel Travel object should start outside Northern Cave")
    assert_equal(info.route.id, "kol_rain_shrine_staging",
        "Northern Cave return should begin on the proven shrine route")
    assert_equal(info.object_id, "route_kol_rain_shrine_staging_02",
        "Northern Cave start should first target the entrance approach")
    assert_contains(info.message,
        "Tantegel Castle route starts from Kol",
        "shrine staging speech should retain the final castle destination")
    assert_equal(routes.active_route_matches_object(target), true,
        "the Tantegel Travel object should remain bound during the shrine leg")

    local segment = assert(routes.plan_next_segment(0x01, 81, 1))
    assert_equal(segment.waypoint.name, "Rain shrine entrance approach",
        "the connected return should use the established cave departure")
    assert_equal(segment.steps[1], "left",
        "the first Northern Cave return step should head west")

    routes.reset_for_tests()
    local alias_info, alias_err = routes.start("tantegel", 0x01, 81, 1)
    assert_equal(alias_err, nil,
        "Tantegel alias should start outside Northern Cave")
    assert_equal(alias_info.route.id, "kol_rain_shrine_staging",
        "the plain alias should use the same connected return itinerary")

    routes.reset_for_tests()
end

function tests.northern_cave_tantegel_itinerary_bypasses_kol()
    routes.reset_for_tests()
    local target = {
        id = "overworld_tantegel_castle",
        name = "Tantegel Castle",
        x = 43,
        y = 43,
    }
    assert(routes.start_for_object(target, 0x01, 81, 1))

    local kol = assert(routes._route_for_tests("kol_rain_shrine_staging"))
    local event
    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "Kol west doorstep should hand off to the final castle leg")
    assert_equal(routes.active_route_id(), "tantegel_kol",
        "the Kol bypass should activate the established Tantegel return")
    assert_equal(event.object_id, "route_tantegel_kol_02",
        "the final leg should leave through Kol forest west edge")
    assert_equal(event.steps, nil,
        "the exterior Kol handoff must not inject movement")
    assert_equal(kol.waypoints[#kol.waypoints].x, 103,
        "the connected return must stop west of Kol")
    assert_equal(kol.waypoints[#kol.waypoints].y, 10,
        "the connected return should preserve Kol's entrance row")
    assert_equal(routes.active_route_matches_object(target), true,
        "the castle Travel object should remain bound after the Kol handoff")

    local segment = assert(routes.plan_next_segment(0x01, 103, 10))
    assert_equal(segment.waypoint.name, "Kol forest west edge",
        "the final leg should bypass Kol and head toward Tantegel")
    assert_equal(segment.steps[1], "left",
        "the final leg should leave Kol westward")

    routes.reset_for_tests()
end

function tests.northern_cave_return_moves_west_before_blocked_x80_descent()
    routes.reset_for_tests()
    assert(routes.start("tantegel", 0x01, 81, 1))
    routes.observe_position(0x01, 80, 1)

    local segment = assert(routes.plan_next_segment(0x01, 80, 2))

    assert_equal(segment.waypoint.name, "Rain shrine island approach",
        "the return should retain the established island approach")
    assert_equal(segment.steps[1], "left",
        "the return should leave column 80 before descending")
    assert_equal(segment.steps[2], "left",
        "the return should reach column 78 before descending")
    assert_equal(segment.steps[3], "down",
        "the return should descend on the live-proven column 78 edge")

    routes.reset_for_tests()
end

function tests.northern_cave_return_reaches_west_coast_before_long_descent()
    routes.reset_for_tests()

    local info, err = routes.start("kol", 0x01, 76, 5)

    assert_equal(err, nil,
        "Kol return should resume at the shrine northwest coast")
    assert_equal(info.route.id, "kol_rain_shrine",
        "the local start should use the established shrine return")

    local segment = assert(routes.plan_next_segment(
        0x01, 76, 5, {advance_if_at_waypoint = true}))
    assert_equal(segment.waypoint.name, "Rain shrine west coast turn",
        "the return should retain the established west-coast turn")
    assert_equal(segment.steps[1], "left",
        "the return should reach column 75 before the long descent")
    assert_equal(segment.steps[2], "down",
        "the return should descend only after reaching the west coast")

    routes.reset_for_tests()
end

function tests.northern_cave_tantegel_staging_copies_shrine_return_without_mutation()
    local direct = assert(routes._route_for_tests("kol_rain_shrine"))
    local staging = assert(routes._route_for_tests("kol_rain_shrine_staging"))

    assert_equal(#staging.waypoints, #direct.waypoints,
        "the non-entry staging route should retain every proven waypoint")
    for index = 1, #direct.waypoints do
        local source = direct.waypoints[index]
        local derived = staging.waypoints[index]
        assert_equal(derived ~= source, true,
            "staging waypoints should be copies rather than mutable aliases")
        if index < #direct.waypoints then
            assert_equal(derived.x, source.x, "staging x at waypoint " .. index)
            assert_equal(derived.y, source.y, "staging y at waypoint " .. index)
            assert_equal(derived.name, source.name,
                "staging name at waypoint " .. index)
        end
    end
    assert_equal(direct.waypoints[#direct.waypoints].x, 104,
        "deriving the bypass must not move direct Kol's entrance")
    assert_equal(direct.waypoints[#direct.waypoints].name, "Kol",
        "deriving the bypass must not rename direct Kol")
end

function tests.northern_cave_tantegel_variant_does_not_steal_other_origins()
    local starts = {
        {name = "Cantlin", x = 73, y = 102, route = "hauksness_return_staging"},
        {name = "Great Swamp", x = 89, y = 112, route = "cantlin_return_staging"},
        {name = "Hauksness", x = 25, y = 89, route = "kol_return_staging"},
        {name = "Mountain Cave", x = 29, y = 57, route = "mountain_cave_return"},
        {name = "Kol", x = 104, y = 10, route = "tantegel_kol"},
        {name = "Rimuldar", x = 102, y = 72, route = "swamp_cave_south"},
    }

    for _, start in ipairs(starts) do
        routes.reset_for_tests()
        local info, err = routes.start("tantegel", 0x01, start.x, start.y)
        assert_equal(err, nil, start.name .. " Tantegel route should still start")
        assert_equal(info.route.id, start.route,
            "Northern Cave variant must not steal " .. start.name)
    end

    routes.reset_for_tests()
end

function tests.stopping_northern_cave_tantegel_itinerary_clears_remaining_legs()
    routes.reset_for_tests()
    assert(routes.start("tantegel", 0x01, 81, 1))

    local event = routes.stop()

    assert_contains(event.message, "Stopped overworld route",
        "explicit stop should acknowledge Northern Cave return cancellation")
    assert_equal(routes.is_active(), false,
        "stopping should clear the active shrine return leg")
    assert_equal(routes.observe_position(0x01, 103, 10), nil,
        "a stopped Northern Cave itinerary must not resume outside Kol")

    routes.reset_for_tests()
end

function tests.tantegel_object_from_swamp_cave_north_starts_kol_return_itinerary()
    routes.reset_for_tests()
    local target = {
        id = "overworld_tantegel_castle",
        name = "Tantegel Castle",
        x = 43,
        y = 43,
    }

    local info, err = routes.start_for_object(target, 0x01, 104, 44)

    assert_equal(err, nil,
        "Tantegel Travel object should start outside Swamp Cave north")
    assert_equal(info.route.id, "kol_swamp_cave_staging",
        "north-cave return should begin on the proven cave-to-Kol route")
    assert_equal(info.object_id, "route_kol_swamp_cave_staging_02",
        "north-exit start should first target the poison-swamp doorstep")
    assert_contains(info.message,
        "Tantegel Castle route starts from Kol",
        "north-cave staging speech should retain the castle destination")
    assert_equal(routes.active_route_matches_object(target), true,
        "the castle Travel object should remain bound during the cave return")

    local segment = assert(routes.plan_next_segment(0x01, 104, 44))
    assert_equal(segment.waypoint.name, "Swamp Cave doorstep",
        "the connected return should use the established north-exit departure")
    assert_equal(segment.steps[1], "up",
        "the first north-exit return step should head north")

    routes.reset_for_tests()
    local alias_info, alias_err = routes.start("tantegel", 0x01, 104, 44)
    assert_equal(alias_err, nil,
        "Tantegel alias should start outside Swamp Cave north")
    assert_equal(alias_info.route.id, "kol_swamp_cave_staging",
        "the plain alias should use the same connected return itinerary")

    routes.reset_for_tests()
end

function tests.swamp_cave_north_tantegel_itinerary_bypasses_kol()
    routes.reset_for_tests()
    local target = {
        id = "overworld_tantegel_castle",
        name = "Tantegel Castle",
        x = 43,
        y = 43,
    }
    assert(routes.start_for_object(target, 0x01, 104, 44))

    local kol = assert(routes._route_for_tests("kol_swamp_cave_staging"))
    local event
    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "Kol west doorstep should hand off to the final castle leg")
    assert_equal(routes.active_route_id(), "tantegel_kol",
        "the Kol bypass should activate the established Tantegel return")
    assert_equal(event.object_id, "route_tantegel_kol_02",
        "the final leg should leave through Kol forest west edge")
    assert_equal(event.steps, nil,
        "the exterior Kol handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "the castle Travel object should remain bound after the Kol handoff")

    local segment = assert(routes.plan_next_segment(0x01, 103, 10))
    assert_equal(segment.waypoint.name, "Kol forest west edge",
        "the final leg should bypass Kol and head toward Tantegel")
    assert_equal(segment.steps[1], "left",
        "the final leg should leave Kol westward")

    routes.reset_for_tests()
end

function tests.swamp_cave_north_tantegel_variant_does_not_steal_other_origins()
    local starts = {
        {name = "Northern Cave", x = 81, y = 1,
            route = "kol_rain_shrine_staging"},
        {name = "Rimuldar", x = 102, y = 72,
            route = "swamp_cave_south"},
        {name = "Mountain Cave", x = 29, y = 57,
            route = "mountain_cave_return"},
        {name = "Kol", x = 104, y = 10, route = "tantegel_kol"},
    }

    for _, start in ipairs(starts) do
        routes.reset_for_tests()
        local info, err = routes.start("tantegel", 0x01, start.x, start.y)
        assert_equal(err, nil, start.name .. " Tantegel route should still start")
        assert_equal(info.route.id, start.route,
            "Swamp Cave north variant must not steal " .. start.name)
    end

    routes.reset_for_tests()
end

function tests.stopping_swamp_cave_north_tantegel_itinerary_clears_remaining_leg()
    routes.reset_for_tests()
    assert(routes.start("tantegel", 0x01, 104, 44))

    local event = routes.stop()

    assert_contains(event.message, "Stopped overworld route",
        "explicit stop should acknowledge north-cave return cancellation")
    assert_equal(routes.is_active(), false,
        "stopping should clear the active cave-to-Kol return leg")
    assert_equal(routes.observe_position(0x01, 103, 10), nil,
        "a stopped north-cave itinerary must not resume outside Kol")

    routes.reset_for_tests()
end

function tests.tantegel_object_from_rimuldar_starts_swamp_cave_return_itinerary()
    routes.reset_for_tests()
    local target = {
        id = "overworld_tantegel_castle",
        name = "Tantegel Castle",
        x = 43,
        y = 43,
    }

    local info, err = routes.start_for_object(target, 0x01, 102, 72)

    assert_equal(err, nil,
        "Tantegel Travel object should start outside Rimuldar")
    assert_equal(info.route.id, "swamp_cave_south",
        "Rimuldar return should begin on the proven south-cave route")
    assert_equal(info.object_id, "route_swamp_cave_south_02",
        "Rimuldar start should first target the east doorstep")
    assert_contains(info.message,
        "Tantegel Castle route starts from Swamp Cave South Entrance",
        "Rimuldar staging speech should retain the final castle destination")
    assert_equal(routes.active_route_matches_object(target), true,
        "the Tantegel Travel object should remain bound during the southern leg")

    local segment = assert(routes.plan_next_segment(0x01, 102, 72))
    assert_equal(segment.waypoint.name, "Rimuldar east doorstep",
        "the connected return should use the established Rimuldar departure")
    assert_equal(segment.steps[1], "right",
        "the first Rimuldar return step should head east")

    routes.reset_for_tests()
    local alias_info, alias_err = routes.start("tantegel", 0x01, 102, 72)
    assert_equal(alias_err, nil,
        "Tantegel alias should start outside Rimuldar")
    assert_equal(alias_info.route.id, "swamp_cave_south",
        "the plain alias should use the same connected return itinerary")

    routes.reset_for_tests()
end

function tests.tantegel_object_from_swamp_cave_south_starts_cave_return_itinerary()
    routes.reset_for_tests()
    local target = {
        id = "overworld_tantegel_castle",
        name = "Tantegel Castle",
        x = 43,
        y = 43,
    }

    local info, err = routes.start_for_object(target, 0x01, 104, 49)

    assert_equal(err, nil,
        "Tantegel Travel object should start outside Swamp Cave south")
    assert_equal(info.route.id, "swamp_cave_south",
        "south-exit return should begin on the proven cave-entry route")
    assert_equal(info.object_id, "route_swamp_cave_south_34",
        "south-exit start should target the adjacent cave entrance")
    assert_contains(info.message,
        "Tantegel Castle route starts from Swamp Cave South Entrance",
        "south-exit staging speech should retain the castle destination")
    assert_equal(routes.active_route_matches_object(target), true,
        "the castle Travel object should remain bound before cave traversal")

    routes.reset_for_tests()
    local alias_info, alias_err = routes.start("tantegel", 0x01, 104, 49)
    assert_equal(alias_err, nil,
        "Tantegel alias should start outside Swamp Cave south")
    assert_equal(alias_info.route.id, "swamp_cave_south",
        "the plain alias should use the same southern return itinerary")

    routes.reset_for_tests()
end

function tests.tantegel_object_from_charlock_starts_connected_return()
    routes.reset_for_tests()
    local target = {
        id = "overworld_tantegel_castle",
        name = "Tantegel Castle",
        x = 43,
        y = 43,
    }

    local info, err = routes.start_for_object(target, 0x01, 48, 48)

    assert_equal(err, nil,
        "Tantegel Travel object should start outside Charlock Castle")
    assert_equal(info.route.id, "charlock_return",
        "Charlock start should first use the proven island return")
    assert_equal(info.object_id, "route_charlock_return_02",
        "Charlock return should first step south from the castle")
    assert_contains(info.message,
        "Tantegel Castle route starts from Swamp Cave South Entrance",
        "Charlock staging speech should retain the castle destination")
    assert_equal(routes.active_route_matches_object(target), true,
        "the Tantegel Travel object should remain bound on Charlock island")

    local charlock_return = assert(routes._route_for_tests("charlock_return"))
    for index = 2, #charlock_return.waypoints - 1 do
        local point = charlock_return.waypoints[index]
        assert(routes.observe_position(0x01, point.x, point.y))
    end

    local cave_wait = routes.observe_position(0x01, 104, 49)
    assert_equal(cave_wait.status, "await_transition",
        "Charlock return should wait for automatic Swamp Cave entry")
    assert_equal(routes.active_route_id(), "charlock_return",
        "the Charlock leg should remain active outside Swamp Cave")

    local cave_handoff = routes.observe_position(0x15, 0, 29)
    assert_equal(cave_handoff.status, "handoff",
        "entering Swamp Cave should advance the Tantegel itinerary")
    assert_equal(routes.active_route_id(), "kol_swamp_cave_staging",
        "cave entry should activate the established north-exit return")
    assert_equal(cave_handoff.steps, nil,
        "the cave handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "the Tantegel Travel object should remain bound in Swamp Cave")

    routes.reset_for_tests()
end

function tests.tantegel_object_from_rainbow_bridge_starts_connected_return()
    routes.reset_for_tests()
    local target = {
        id = "overworld_tantegel_castle",
        name = "Tantegel Castle",
        x = 43,
        y = 43,
    }

    local info, err = routes.start_for_object(target, 0x01, 65, 49)

    assert_equal(err, nil,
        "Tantegel Travel object should start at the Rainbow Bridge unlock point")
    assert_equal(info.route.id, "rainbow_bridge_return",
        "bridge start should first use the proven eastbound return")
    assert_equal(info.object_id, "route_rainbow_bridge_return_02",
        "bridge return should first target the inlet detour")
    assert_equal(routes.active_route_matches_object(target), true,
        "the Tantegel Travel object should remain bound at Rainbow Bridge")

    local bridge_return = assert(routes._route_for_tests("rainbow_bridge_return"))
    for index = 2, #bridge_return.waypoints - 1 do
        local point = bridge_return.waypoints[index]
        assert(routes.observe_position(0x01, point.x, point.y))
    end

    local cave_wait = routes.observe_position(0x01, 104, 49)
    assert_equal(cave_wait.status, "await_transition",
        "Rainbow Bridge return should wait for automatic Swamp Cave entry")
    assert_equal(routes.active_route_id(), "rainbow_bridge_return",
        "the bridge leg should remain active outside Swamp Cave")

    local cave_handoff = routes.observe_position(0x15, 0, 29)
    assert_equal(cave_handoff.status, "handoff",
        "entering Swamp Cave should advance the Tantegel itinerary")
    assert_equal(routes.active_route_id(), "kol_swamp_cave_staging",
        "cave entry should activate the established north-exit return")
    assert_equal(cave_handoff.steps, nil,
        "the cave handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "the Tantegel Travel object should remain bound in Swamp Cave")

    routes.reset_for_tests()
end

function tests.tantegel_object_from_magic_temple_starts_connected_return()
    routes.reset_for_tests()
    local target = {
        id = "overworld_tantegel_castle",
        name = "Tantegel Castle",
        x = 43,
        y = 43,
    }

    local info, err = routes.start_for_object(target, 0x01, 108, 109)

    assert_equal(err, nil,
        "Tantegel Travel object should start outside Magic Temple")
    assert_equal(info.route.id, "rimuldar_magic_temple_staging",
        "temple start should first use the exterior Rimuldar return")
    assert_equal(info.object_id, "route_rimuldar_magic_temple_staging_02",
        "temple return should first leave the entrance pocket")
    assert_equal(routes.active_route_matches_object(target), true,
        "the Tantegel Travel object should remain bound on the temple leg")

    local temple_return = assert(routes._route_for_tests(
        "rimuldar_magic_temple_staging"))
    for index = 2, #temple_return.waypoints - 1 do
        local point = temple_return.waypoints[index]
        assert(routes.observe_position(0x01, point.x, point.y))
    end

    local rimuldar_handoff = routes.observe_position(0x01, 103, 72)
    assert_equal(rimuldar_handoff.status, "handoff",
        "reaching Rimuldar's doorstep should advance the Tantegel itinerary")
    assert_equal(routes.active_route_id(), "swamp_cave_south_magic_temple",
        "Rimuldar arrival should activate the established south-cave return")
    assert_equal(rimuldar_handoff.object_id,
        "route_swamp_cave_south_magic_temple_03",
        "the next leg should leave the doorstep through Rimuldar's east gate lane")
    assert_equal(rimuldar_handoff.steps, nil,
        "the Rimuldar handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "the Tantegel Travel object should remain bound after Rimuldar")

    local south_return = assert(
        routes._route_for_tests("swamp_cave_south_magic_temple"))
    for index = 3, #south_return.waypoints - 1 do
        local point = south_return.waypoints[index]
        assert(routes.observe_position(0x01, point.x, point.y))
    end

    local cave_wait = routes.observe_position(0x01, 104, 49)
    assert_equal(cave_wait.status, "await_transition",
        "temple return should wait for automatic Swamp Cave entry")
    assert_equal(routes.active_route_id(), "swamp_cave_south_magic_temple",
        "the southern leg should remain active outside Swamp Cave")

    local cave_handoff = routes.observe_position(0x15, 0, 29)
    assert_equal(cave_handoff.status, "handoff",
        "entering Swamp Cave should advance the temple itinerary")
    assert_equal(routes.active_route_id(), "kol_swamp_cave_staging",
        "cave entry should activate the established north-exit return")
    assert_equal(cave_handoff.steps, nil,
        "the cave handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "the Tantegel Travel object should remain bound in Swamp Cave")

    routes.reset_for_tests()
end

function tests.swamp_cave_south_tantegel_itinerary_waits_for_north_exit()
    routes.reset_for_tests()
    local target = {
        id = "overworld_tantegel_castle",
        name = "Tantegel Castle",
        x = 43,
        y = 43,
    }
    assert(routes.start_for_object(target, 0x01, 104, 49))

    local wait_event = routes.observe_position(0x01, 104, 49)
    assert_equal(wait_event.status, "await_transition",
        "standing on the south entrance should wait for automatic cave entry")
    assert_equal(routes.active_route_id(), "swamp_cave_south",
        "the itinerary must not activate the north-exit leg before cave entry")
    assert_contains(wait_event.message, "opens automatically",
        "the transition wait should explain automatic cave entry")
    assert_contains(wait_event.message, "step off and back on",
        "the transition wait should explain how to retrigger entry")

    local wait_segment = assert(routes.plan_next_segment(0x01, 104, 49, {
        advance_if_at_waypoint = true,
    }))
    assert_equal(wait_segment.status, "already_at_waypoint",
        "autowalk at the automatic-entry tile should remain safely in place")
    assert_equal(#wait_segment.steps, 0,
        "autowalk must not synthesize a northbound shortcut across the cave")

    local cave_handoff = routes.observe_position(0x15, 0, 29)

    assert_equal(cave_handoff.status, "handoff",
        "south-cave entry should hand off within the castle itinerary")
    assert_equal(routes.active_route_id(), "kol_swamp_cave_staging",
        "cave entry should activate the north-exit-to-Kol return")
    assert_equal(cave_handoff.object_id, "route_kol_swamp_cave_staging_01",
        "the cave handoff should wait for the north exterior landing")
    assert_equal(cave_handoff.steps, nil,
        "the interior cave handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "the castle Travel object should remain bound during cave traversal")

    routes.reset_for_tests()
end

function tests.rimuldar_tantegel_itinerary_pauses_in_cave_then_bypasses_kol()
    routes.reset_for_tests()
    local target = {
        id = "overworld_tantegel_castle",
        name = "Tantegel Castle",
        x = 43,
        y = 43,
    }
    assert(routes.start_for_object(target, 0x01, 102, 72))

    local cave_handoff = routes.observe_position(0x15, 0, 29)
    assert_equal(cave_handoff.status, "handoff",
        "south-cave entry should hand off within the Tantegel itinerary")
    assert_equal(routes.active_route_id(), "kol_swamp_cave_staging",
        "cave entry should activate the north-exit-to-Kol return")
    assert_equal(cave_handoff.object_id, "route_kol_swamp_cave_staging_01",
        "the cave handoff should wait for the north exterior landing")
    assert_equal(cave_handoff.steps, nil,
        "the interior cave handoff must not inject movement")
    assert_equal(routes.active_route_matches_object(target), true,
        "the castle Travel object should remain bound during cave traversal")

    local north_exit = routes.observe_position(0x01, 104, 44)
    assert_contains(north_exit.message, "Reached Swamp Cave",
        "the route should resume after the player exits the north stair")
    assert_equal(north_exit.object_id, "route_kol_swamp_cave_staging_02",
        "north exit should advance to the poison-swamp doorstep")

    local kol = assert(routes._route_for_tests("kol_swamp_cave_staging"))
    local event
    for index = 2, #kol.waypoints do
        local waypoint = kol.waypoints[index]
        event = routes.observe_position(0x01, waypoint.x, waypoint.y)
    end
    assert_equal(event.status, "handoff",
        "Kol west doorstep should hand off to the final castle leg")
    assert_equal(routes.active_route_id(), "tantegel_kol",
        "the Kol bypass should activate the established Tantegel return")
    assert_equal(event.object_id, "route_tantegel_kol_02",
        "the final leg should leave through Kol forest west edge")
    assert_equal(event.steps, nil,
        "the exterior Kol handoff must not inject movement")
    assert_equal(kol.waypoints[#kol.waypoints].x, 103,
        "the connected return must stop west of Kol")
    assert_equal(kol.waypoints[#kol.waypoints].y, 10,
        "the connected return should preserve Kol's entrance row")

    local segment = assert(routes.plan_next_segment(0x01, 103, 10))
    assert_equal(segment.waypoint.name, "Kol forest west edge",
        "the final leg should bypass Kol and head toward Tantegel")
    assert_equal(segment.steps[1], "left",
        "the final leg should leave Kol westward")

    routes.reset_for_tests()
end

function tests.rimuldar_tantegel_staging_copies_swamp_return_without_mutation()
    local direct = assert(routes._route_for_tests("kol_swamp_cave"))
    local staging = assert(routes._route_for_tests("kol_swamp_cave_staging"))

    assert_equal(#staging.waypoints, #direct.waypoints,
        "the non-entry staging route should retain every proven waypoint")
    for index = 1, #direct.waypoints do
        local source = direct.waypoints[index]
        local derived = staging.waypoints[index]
        assert_equal(derived ~= source, true,
            "staging waypoints should be copies rather than mutable aliases")
        if index < #direct.waypoints then
            assert_equal(derived.x, source.x, "staging x at waypoint " .. index)
            assert_equal(derived.y, source.y, "staging y at waypoint " .. index)
            assert_equal(derived.name, source.name,
                "staging name at waypoint " .. index)
        end
    end
    assert_equal(direct.waypoints[#direct.waypoints].x, 104,
        "deriving the bypass must not move direct Kol's entrance")
    assert_equal(direct.waypoints[#direct.waypoints].name, "Kol",
        "deriving the bypass must not rename direct Kol")
end

function tests.rimuldar_tantegel_variant_does_not_steal_other_origins()
    local starts = {
        {name = "Cantlin", x = 73, y = 102, route = "hauksness_return_staging"},
        {name = "Great Swamp", x = 89, y = 112, route = "cantlin_return_staging"},
        {name = "Hauksness", x = 25, y = 89, route = "kol_return_staging"},
        {name = "Mountain Cave", x = 29, y = 57, route = "mountain_cave_return"},
        {name = "Kol", x = 104, y = 10, route = "tantegel_kol"},
    }

    for _, start in ipairs(starts) do
        routes.reset_for_tests()
        local info, err = routes.start("tantegel", 0x01, start.x, start.y)
        assert_equal(err, nil, start.name .. " Tantegel route should still start")
        assert_equal(info.route.id, start.route,
            "Rimuldar variant must not steal " .. start.name)
    end

    routes.reset_for_tests()
end

function tests.stopping_rimuldar_tantegel_itinerary_clears_remaining_legs()
    routes.reset_for_tests()
    assert(routes.start("tantegel", 0x01, 102, 72))

    local event = routes.stop()

    assert_contains(event.message, "Stopped overworld route",
        "explicit stop should acknowledge Rimuldar return cancellation")
    assert_equal(routes.is_active(), false,
        "stopping should clear the active Rimuldar return leg")
    assert_equal(routes.observe_position(0x15, 0, 29), nil,
        "a stopped Rimuldar itinerary must not resume inside Swamp Cave")

    routes.reset_for_tests()
end

function tests.tantegel_alias_from_kol_uses_kol_return_variant()
    routes.reset_for_tests()

    local info, err = routes.start("castle", 0x01, 104, 10)

    assert_equal(err, nil, "generic castle alias should start near Kol")
    assert_equal(info.object_id, "route_tantegel_kol_02", "castle alias should choose the Kol-side route variant by position")
    assert_contains(info.message, "Kol forest west edge", "castle alias should not aim at Erdrick's Cave road from Kol")

    routes.reset_for_tests()
end

function tests.tantegel_kol_return_reconnects_to_cave_road_route()
    routes.reset_for_tests()
    routes.start("castle", 0x01, 104, 10)

    routes.observe_position(0x01, 96, 13)
    routes.observe_position(0x01, 96, 21)
    local detour = assert(routes.plan_next_segment(0x01, 96, 26))
    assert_equal(detour.waypoint.name, "Kol south road east detour", "Kol return should detour around the blocked x96 seam")
    assert_equal(detour.steps[1], "right", "Kol return should step east at the live-confirmed seam")
    routes.observe_position(0x01, 98, 26)
    routes.observe_position(0x01, 98, 32)
    routes.observe_position(0x01, 96, 32)
    routes.observe_position(0x01, 96, 35)
    routes.observe_position(0x01, 93, 35)
    routes.observe_position(0x01, 93, 36)
    routes.observe_position(0x01, 92, 36)
    routes.observe_position(0x01, 92, 37)
    routes.observe_position(0x01, 90, 37)
    routes.observe_position(0x01, 84, 26)
    routes.observe_position(0x01, 74, 18)
    routes.observe_position(0x01, 61, 18)
    routes.observe_position(0x01, 61, 19)
    routes.observe_position(0x01, 59, 19)
    routes.observe_position(0x01, 58, 18)
    routes.observe_position(0x01, 54, 15)
    routes.observe_position(0x01, 45, 13)
    routes.observe_position(0x01, 35, 13)
    local cave_road = routes.observe_position(0x01, 28, 13)

    assert_contains(cave_road.message, "Reached Erdrick's Cave road", "Kol return should reconnect to the known cave road")
    assert_contains(cave_road.message, "Next: North trail marker", "Kol return should continue down the existing castle route")

    routes.reset_for_tests()
end

function tests.safety_route_uses_live_east_field_lane()
    routes.reset_for_tests()

    local info, err = routes.start("castle", 0x01, 19, 7)

    assert_equal(err, nil, "castle safety route should calculate near the east field")
    assert_equal(info.object_id, "route_tantegel_10", "route should aim at the live east-field lane before going south")
    assert_contains(info.message, "Garinham field east lane", "route should not aim directly south through the blocked field edge")

    local segment, seg_err = routes.plan_next_segment(0x01, 19, 7)
    assert_equal(seg_err, nil, "east-field lane should be plannable")
    assert_equal(segment.waypoint.name, "Garinham field east lane", "segment should target the live lane")
    assert_equal(segment.steps[1], "right", "segment should move east from the blocked south-turn area")

    routes.reset_for_tests()
end

function tests.safety_route_avoids_blocked_cave_road_south_step()
    routes.reset_for_tests()

    local info, err = routes.start("castle", 0x01, 21, 11)

    assert_equal(err, nil, "castle safety route should calculate near cave road")
    assert_equal(info.object_id, "route_tantegel_14", "route should point at the west lane before the cave-road south lane")
    assert_contains(info.message, "Cave road west lane", "route should avoid the blocked south step from 21,11")

    local segment, seg_err = routes.plan_next_segment(0x01, 21, 11)
    assert_equal(seg_err, nil, "cave-road west lane should be plannable")
    assert_equal(segment.waypoint.name, "Cave road west lane", "segment should target the eastward lane")
    assert_equal(segment.steps[1], "right", "segment should move east, not south into 21,12")
    assert_equal(segment.steps[2], "right", "segment should stay on the safe west lane")

    routes.reset_for_tests()
end

function tests.garinham_route_returns_through_field_bend()
    routes.reset_for_tests()

    local info, err = routes.start("garinham", 0x01, 21, 10)

    assert_equal(err, nil, "Garinham route should calculate from the field bend")
    assert_equal(info.object_id, "route_garinham_16", "route should aim at Garinham east field from the bend")
    assert_contains(info.message, "Garinham east field", "route should point back through the field marker")

    local segment, seg_err = routes.plan_next_segment(0x01, 21, 10)
    assert_equal(seg_err, nil, "field-bend segment should be plannable")
    assert_equal(segment.waypoint.name, "Garinham east field", "segment should target the field marker")
    assert_equal(segment.steps[1], "left", "reverse route should use the verified west step before going north")
    assert_equal(segment.steps[2], "up", "reverse route should then return to the field marker")

    routes.reset_for_tests()
end

function tests.plan_next_segment_queues_steps_to_active_waypoint()
    routes.reset_for_tests()
    routes.start("garinham", 0x01, 19, 7)

    local segment, err = routes.plan_next_segment(0x01, 19, 7)

    assert_equal(err, nil, "active route should plan a next overworld segment")
    assert_equal(segment.status, "planned", "segment should report a planned route")
    assert_equal(segment.waypoint.name, "Garinham east ridge", "segment should target the active next waypoint")
    assert_equal(#segment.steps, 4, "segment should include one step per world-map tile")
    assert_equal(segment.steps[1], "up", "segment should move vertically first by default")
    assert_equal(segment.steps[2], "left", "segment should then move horizontally")
    assert_contains(segment.message, "Garinham east ridge", "segment message should name the waypoint")

    routes.reset_for_tests()
end

function tests.plan_next_segment_reports_no_active_route()
    routes.reset_for_tests()

    local segment, err = routes.plan_next_segment(0x01, 19, 7)

    assert_equal(segment, nil, "inactive route should not plan a segment")
    assert_contains(err, "No overworld route active", "missing active route should be explicit")

    routes.reset_for_tests()
end

function tests.plan_next_segment_refuses_non_world_map()
    routes.reset_for_tests()
    routes.start("garinham", 0x01, 19, 7)

    local segment, err = routes.plan_next_segment(0x09, 19, 7)

    assert_equal(segment, nil, "interior maps should not plan overworld segments")
    assert_contains(err, "world map", "wrong-map refusal should name the world map requirement")

    routes.reset_for_tests()
end

function tests.safety_route_starts_from_garinham()
    routes.reset_for_tests()

    local info, err = routes.start("castle", 0x01, 1, 2)

    assert_equal(err, nil, "castle safety route should start from Garinham")
    assert_equal(info.object_id, "route_tantegel_02", "route should skip the current Garinham anchor")
    assert_contains(info.message, "Garinham outskirts", "safety route should first leave town toward the cave road")

    routes.reset_for_tests()
end

function tests.safe_alias_is_contextual_near_brecconary()
    routes.reset_for_tests()

    local info, err = routes.start("safe", 0x01, 48, 41)

    assert_equal(err, nil, "safe alias should resolve")
    assert_equal(info.route.id, "brecconary", "safe should still mean Brecconary when that is the nearest safety destination")
    assert_contains(info.message, "Route to Brecconary", "safe route should name the selected safety destination")

    routes.reset_for_tests()
end

function tests.safe_alias_is_contextual_after_bridge()
    routes.reset_for_tests()

    local info, err = routes.start("safety", 0x01, 44, 38)

    assert_equal(err, nil, "safety alias should resolve")
    assert_equal(info.route.id, "tantegel", "safety should route to Tantegel after crossing the bridge toward the castle")
    assert_contains(info.message, "Route to Tantegel Castle", "safety route should name the contextual destination")

    routes.reset_for_tests()
end

function tests.unmatched_object_reports_no_guided_route()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_unknown_shrine",
        name = "Unknown Shrine",
        x = 10,
        y = 10,
    }, 0x01, 43, 43)

    assert_equal(info, nil, "unknown destination should not start a route")
    assert_contains(err, "No guided route for Unknown Shrine", "missing route should name the selected object")
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

function tests.entering_garinham_stops_route()
    routes.reset_for_tests()
    routes.start("garinham", 0x01, 2, 3)

    local event = routes.observe_position(0x09, 15, 14)

    assert_contains(event.message, "Arrived at Garinham", "entering town should complete the Garinham route")
    assert_equal(event.refresh, true, "destination map arrival should refresh Travel objects")
    assert_equal(routes.is_active(), false, "route should stop after entering Garinham")

    routes.reset_for_tests()
end

function tests.entering_kol_stops_route()
    routes.reset_for_tests()
    routes.start("kol", 0x01, 104, 11)

    local event = routes.observe_position(0x07, 15, 14)

    assert_contains(event.message, "Arrived at Kol", "entering town should complete the Kol route")
    assert_equal(event.refresh, true, "destination map arrival should refresh Travel objects")
    assert_equal(routes.is_active(), false, "route should stop after entering Kol")

    routes.reset_for_tests()
end

function tests.entering_rain_shrine_stops_northern_cave_route()
    routes.reset_for_tests()
    routes.start("rain shrine", 0x01, 81, 2)

    local event = routes.observe_position(0x0D, 4, 4)

    assert_contains(event.message, "Arrived at Northern Cave", "entering Rain Shrine should complete the northern cave route")
    assert_equal(event.refresh, true, "destination map arrival should refresh Travel objects")
    assert_equal(routes.is_active(), false, "route should stop after entering Rain Shrine")

    routes.reset_for_tests()
end

function tests.entering_swamp_cave_stops_swamp_cave_route()
    routes.reset_for_tests()
    routes.start("swamp cave", 0x01, 104, 42)

    local event = routes.observe_position(0x15, 0, 0)

    assert_contains(event.message, "Arrived at Swamp Cave", "entering Swamp Cave should complete the route")
    assert_equal(event.refresh, true, "destination map arrival should refresh Travel objects")
    assert_equal(routes.is_active(), false, "route should stop after entering Swamp Cave")

    routes.reset_for_tests()
end

function tests.entering_rimuldar_stops_rimuldar_route()
    routes.reset_for_tests()
    routes.start("rimuldar", 0x01, 90, 72)

    local event = routes.observe_position(0x0B, 15, 14)

    assert_contains(event.message, "Arrived at Rimuldar", "entering Rimuldar should complete the route")
    assert_equal(event.refresh, true, "destination map arrival should refresh Travel objects")
    assert_equal(routes.is_active(), false, "route should stop after entering Rimuldar")

    routes.reset_for_tests()
end

function tests.entering_swamp_cave_stops_south_entrance_return_route()
    routes.reset_for_tests()
    routes.start("swamp cave south", 0x01, 93, 49)

    local event = routes.observe_position(0x15, 0, 29)

    assert_contains(event.message, "Arrived at Swamp Cave South Entrance", "entering Swamp Cave should complete the south-entrance route")
    assert_equal(event.refresh, true, "destination map arrival should refresh Travel objects")
    assert_equal(routes.is_active(), false, "return route should stop after entering Swamp Cave")

    routes.reset_for_tests()
end

function tests.selected_different_destination_replaces_active_route()
    routes.reset_for_tests()
    routes.start("cave", 0x01, 30, 32)

    local info, err = routes.guidance_for_object({
        id = "overworld_brecconary",
        name = "Brecconary",
        x = 48,
        y = 41,
    }, 0x01, 28, 12)

    assert_equal(err, nil, "active route guidance should accept a different Travel destination")
    assert_contains(info.message, "Route changed. Route to Brecconary", "R should replace the active route")
    assert_contains(info.log, "event=replace route=brecconary", "route replacement should be visible in logs")
    assert_equal(routes.active_route_id(), "brecconary", "selected destination should replace the active route")

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
    }, 0x01, 47, 41)

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
    }, 0x01, 47, 41)

    assert_contains(info.message, "Route recalculated. Route to Erdrick's Cave", "same destination should explicitly recalculate")
    assert_equal(info.object_id, "route_erdrick_03", "same-destination recalculation should use current position")
    assert_contains(info.log, "event=recalculate route=erdrick", "same-destination recalc should be logged")

    routes.reset_for_tests()
end

function tests.terrain_offset_zero_satisfies_overworld_predicate_when_map_id_lags()
    -- During the single-frame transition out of a town, snapshot.map_id can
    -- still report the town while terrain_offset has already flipped to 0.
    -- plan_next_segment must accept that as overworld so callers don't get
    -- a spurious "only available on the world map" error.
    routes.reset_for_tests()
    routes.start("brecconary", 0x01, 50, 40)

    local segment, err = routes.plan_next_segment(0x08, 50, 40, {terrain_offset = 0x00})

    assert_equal(err, nil, "terrain_offset=0 should satisfy the overworld predicate")
    assert_equal(segment ~= nil, true, "segment should plan when terrain_offset proves overworld")

    routes.reset_for_tests()
end

function tests.route_start_uses_terrain_offset_when_map_id_lags()
    -- Route selection should use the canonical overworld predicate too, not
    -- only autowalk segment planning.
    routes.reset_for_tests()

    local info, err = routes.start("kol", 0x08, 81, 1, {terrain_offset = 0x00})

    assert_equal(err, nil, "terrain_offset=0 should let route start treat the frame as overworld")
    assert_equal(info.route.id, "kol_rain_shrine", "lagging map_id should still choose the nearest Kol variant")

    routes.reset_for_tests()
end

function tests.route_status_uses_terrain_offset_when_map_id_lags()
    routes.reset_for_tests()

    routes.start("kol", 0x01, 74, 7)
    local info = routes.recalculate(0x08, 90, 20, {terrain_offset = 0x00})

    assert_equal(info.route.id, "kol_rain_shrine", "recalculate should honor terrain_offset while map_id lags")
    assert_contains(info.message, "Rain shrine", "recalculate should choose the local shrine return path")

    routes.reset_for_tests()
end

function tests.route_guidance_uses_terrain_offset_when_map_id_lags()
    routes.reset_for_tests()
    routes.start("cave", 0x01, 30, 32)

    local info = routes.guidance_for_object({
        id = "overworld_erdrick_s_cave",
        name = "Erdrick's Cave",
        x = 28,
        y = 12,
    }, 0x08, 47, 41, {terrain_offset = 0x00})

    assert_contains(info.message, "Route recalculated", "route guidance should recalculate on terrain-backed overworld frames")
    assert_equal(info.object_id, "route_erdrick_03", "same-destination guidance should use current position despite lagging map_id")

    routes.reset_for_tests()
end

function tests.autowalk_advances_past_already_at_waypoint_with_opt_in()
    -- When the player is sitting exactly on a waypoint, plan_next_segment
    -- without advance_if_at_waypoint returns a status record so observe_position
    -- can drive arrival. autowalk callers pass advance_if_at_waypoint=true so
    -- a single press never stalls when the player is on a waypoint tile.
    routes.reset_for_tests()

    -- Start from a position near (but outside the radius of) the first
    -- waypoint so choose_next_index lands on it without auto-advancing.
    local start = routes.start("cave", 0x01, 45, 45)
    assert_equal(start ~= nil, true, "route should start")

    local route = routes._route_for_tests("erdrick")
    local wp1 = route.waypoints[1]
    local wp2 = route.waypoints[2]

    -- Status-only plan reports "already at waypoint" without advancing.
    local status_only = routes.plan_next_segment(0x01, wp1.x, wp1.y)
    assert_equal(status_only.status, "already_at_waypoint", "default plan should report status when at waypoint")
    assert_equal(#status_only.steps, 0, "status-only plan should not emit steps")

    -- Opt-in plan advances state.next_index and returns a planned segment.
    local advanced = routes.plan_next_segment(0x01, wp1.x, wp1.y, {advance_if_at_waypoint = true})
    assert_equal(advanced.status, "planned", "advance_if_at_waypoint should produce a planned segment")
    assert_equal(#advanced.steps > 0, true, "advanced plan should emit at least one step toward the next waypoint")
    assert_equal(advanced.waypoint.x, wp2.x, "advanced plan should target the next waypoint")
    assert_equal(advanced.waypoint.y, wp2.y, "advanced plan should target the next waypoint")

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
