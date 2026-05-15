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

function tests.unmatched_object_reports_no_guided_route()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_rimuldar",
        name = "Rimuldar",
        x = 102,
        y = 72,
    }, 0x01, 43, 43)

    assert_equal(info, nil, "unknown destination should not start a route")
    assert_contains(err, "No guided route for Rimuldar", "missing route should name the selected object")
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

function tests.selected_destination_does_not_replace_active_route()
    routes.reset_for_tests()
    routes.start("cave", 0x01, 30, 32)

    local info, err = routes.guidance_for_object({
        id = "overworld_brecconary",
        name = "Brecconary",
        x = 48,
        y = 41,
    }, 0x01, 28, 12)

    assert_equal(err, nil, "active route guidance should ignore unrelated selected destinations")
    assert_contains(info.message, "Route to Erdrick's Cave", "R should keep reporting the active route")
    assert_contains(info.log, "route=erdrick", "status should remain attached to the active route")
    assert_equal(routes.active_route_id(), "erdrick", "selected object drift should not replace the active route")

    local replacement = routes.start("brecconary", 0x01, 28, 12)
    assert_contains(replacement.message, "Route changed. Route to Brecconary", "explicit route start should still replace the active route")
    assert_equal(routes.active_route_id(), "brecconary", "explicit command replacement should remain available")

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
