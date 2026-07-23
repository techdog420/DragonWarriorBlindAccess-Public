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
    assert_contains(info.message, "Brecconary road", "route should first guide toward the known road")

    routes.reset_for_tests()
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
    assert_contains(info.message, "Brecconary road", "route should first leave Tantegel toward the western bridge road")

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

    routes.observe_position(0x01, 48, 41)
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
    assert_contains(south_road.message, "Next: West of Kol north lane", "south road should continue north toward Kol")

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
    assert_equal(north_lane.waypoint.name, "West of Kol north lane", "near the live south road should skip the stale west target")
    assert_equal(north_lane.steps[1], "up", "south-road lane should continue north")

    routes.reset_for_tests()
end

function tests.kol_route_backs_out_of_dead_east_bridge_pocket()
    routes.reset_for_tests()

    local info, err = routes.start("kol", 0x01, 57, 38)

    assert_equal(err, nil, "Kol route should still start from the disproved east pocket")
    assert_equal(info.object_id, "route_kol_02", "dead pocket should backtrack toward Brecconary road")
    assert_contains(info.message, "Brecconary road", "route should not target the blocked 57,38 to 58,38 bridge edge")

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
    assert_equal(info.route.id, "kol", "far Northern Cave requests should stage through Kol")
    assert_equal(info.object_id, "route_kol_02", "staging route should leave Tantegel on the Kol route")
    assert_contains(info.message, "Northern Cave route starts from Kol", "staging should explain the required hub")
    assert_contains(info.message, "Starting route to Kol first", "staging should say which route actually started")
    assert_contains(info.message, "Route to Kol", "staging should include normal route guidance")
    assert_contains(info.log, "staged_from=northern_cave", "staged starts should be visible in logs")

    local segment = assert(routes.plan_next_segment(0x01, 43, 43))
    assert_equal(segment.waypoint.name, "Brecconary road", "Kol staging should use the proven Kol route")
    assert_equal(segment.steps[1], "up", "Tantegel-to-Kol staging should leave toward Brecconary road")

    routes.reset_for_tests()
end

function tests.northern_cave_object_from_tantegel_starts_kol_staging_route()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_northern_cave",
        name = "Northern Cave",
        x = 81,
        y = 1,
    }, 0x01, 43, 43)

    assert_equal(err, nil, "Northern Cave Travel object should resolve from Tantegel")
    assert_equal(info.route.id, "kol", "Travel-object starts should use the same Kol staging guard")
    assert_equal(info.object_id, "route_kol_02", "Travel-object staging should start the Kol route")
    assert_contains(info.message, "Northern Cave route starts from Kol", "Travel-object staging should explain the hub route")

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
    assert_equal(info.route.id, "kol", "far Swamp Cave requests should stage through Kol")
    assert_equal(info.object_id, "route_kol_02", "staging route should leave Tantegel on the Kol route")
    assert_contains(info.message, "Swamp Cave route starts from Kol", "staging should explain the required hub")
    assert_contains(info.message, "Starting route to Kol first", "staging should say which route actually started")
    assert_contains(info.message, "Route to Kol", "staging should include normal route guidance")
    assert_contains(info.log, "staged_from=swamp_cave", "staged starts should be visible in logs")

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
    routes.observe_position(0x01, 96, 21)
    routes.observe_position(0x01, 96, 13)
    local arrival = routes.observe_position(0x01, 104, 10)
    assert_contains(arrival.message, "Arrived at Kol", "final waypoint should complete the return route")
    assert_equal(routes.is_active(), false, "route should stop after reaching Kol")

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
    assert_contains(west_route.message, "Next: Craggy mountain west wall", "route should continue south along the western mountain route")

    routes.observe_position(0x01, 93, 56)
    routes.observe_position(0x01, 93, 57)
    routes.observe_position(0x01, 90, 57)
    routes.observe_position(0x01, 90, 58)
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
    routes.observe_position(0x01, 93, 56)
    routes.observe_position(0x01, 93, 57)
    routes.observe_position(0x01, 90, 57)
    routes.observe_position(0x01, 90, 58)
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
    routes.observe_position(0x01, 93, 56)
    routes.observe_position(0x01, 93, 57)
    routes.observe_position(0x01, 90, 57)
    routes.observe_position(0x01, 90, 58)
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

function tests.rimuldar_route_avoids_craggy_notch_up_block()
    routes.reset_for_tests()
    routes.start("rimuldar", 0x01, 93, 57)

    local segment = assert(routes.plan_next_segment(0x01, 93, 57))
    assert_equal(segment.waypoint.name, "Safer west route north lane", "route should skip the bad upper notch waypoint")
    assert_equal(segment.steps[1], "left", "route should not retry north from the blocked craggy notch")

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
    }, 0x08, 48, 41, {terrain_offset = 0x00})

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
