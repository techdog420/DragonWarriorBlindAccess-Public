-- test_map_reader.lua
-- Focused regression tests for permanent walkability overrides.

local original_preload = {}
local original_loaded = {}

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

local function make_env(opts)
    opts = opts or {}
    local module_names = {
        "addresses",
        "map_reader",
    }
    for _, name in ipairs(module_names) do
        save_module(name)
        package.loaded[name] = nil
    end

    package.preload["addresses"] = function()
        return {
            ROM_MAP_META_START = opts.rom_map_meta_start or 0,
            ROM_MAP_META_SIZE = opts.rom_map_meta_size or 5,
            DOOR_ARRAY_MAX = opts.door_array_max or 0,
            DOOR_X_POS_START = opts.door_x_pos_start or 0,
            DOOR_Y_POS_START = opts.door_y_pos_start or 0,
            DOOR_ARRAY_STRIDE = opts.door_array_stride or 0,
            TERRAIN_OFFSET = opts.terrain_offset_addr or 0,
        }
    end

    local rom_bytes = opts.rom_bytes or {}
    local memory_bytes = opts.memory_bytes or {}

    _G.rom = _G.rom or {}
    _G.memory = _G.memory or {}
    _G.rom.readbyte = function(address)
        return rom_bytes[address] or 0
    end
    _G.memory.readbyte = function(address)
        return memory_bytes[address] or 0
    end
    _G.AND = _G.AND or function(a, b)
        local result = 0
        local bit = 1
        while a > 0 and b > 0 do
            local a_bit = a % 2
            local b_bit = b % 2
            if a_bit == 1 and b_bit == 1 then
                result = result + bit
            end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            bit = bit * 2
        end
        return result
    end

    local map_reader = require "map_reader"

    return {
        map_reader = map_reader,
        restore = function()
            restore_modules(module_names)
        end,
    }
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local tests = {}

function tests.throne_room_keeps_east_descent_open()
    local env = make_env()

    assert_equal(
        env.map_reader.is_permanently_blocked_override(0x05, 7, 2),
        false,
        "throne room east-side descent at (7,2) should remain open"
    )

    env.restore()
end

function tests.throne_room_trapped_pocket_stays_blocked()
    local env = make_env()

    assert_equal(env.map_reader.is_permanently_blocked_override(0x05, 2, 3), true, "(2,3) should stay blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x05, 4, 3), true, "(4,3) should stay blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x05, 3, 4), false, "(3,4) should remain open for king access")

    env.restore()
end

function tests.throne_room_door_opens_from_door_ram_array()
    local rom_bytes = {
        [25] = 0x00,
        [26] = 0x80,
        [27] = 9,
        [28] = 9,
        [29] = 0,
    }
    for i = 0x10, 0x16 do
        rom_bytes[i] = 0xFF
    end

    local env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = {
            [0] = 0x10,
            [0x600C] = 4,
            [0x600D] = 7,
        },
        door_array_max = 8,
        door_x_pos_start = 0x600C,
        door_y_pos_start = 0x600D,
        door_array_stride = 2,
    })

    local details = env.map_reader.get_walkability_details(0x05, 4, 7)
    assert_equal(details.effective_walkable, true, "opened throne-room door should become walkable")
    assert_equal(details.reason, "door_open", "opened throne-room door should report door_open")
    local snapshot = env.map_reader.get_walkability_snapshot(0x05)
    assert_equal(snapshot[7][4], true, "walkability snapshot should honor opened throne-room door RAM")

    env.restore()
end

function tests.throne_room_directional_candidates_are_promoted_conservatively()
    local env = make_env()

    local dirs = env.map_reader.get_directional_blocks(0x05)
    assert_equal(dirs["7,3"].east, true, "(7,3) should block east approach")
    assert_equal(dirs["7,3"].west, true, "(7,3) should block west approach")
    assert_equal(dirs["7,3"].south, true, "(7,3) should block south approach after direct probe reconfirmation")
    assert_equal(dirs["7,3"].north, nil, "(7,3) should stay open from north until confirmed")
    assert_equal(dirs["7,2"].east, true, "(7,2) should block east approach")
    assert_equal(dirs["7,2"].north, true, "(7,2) should block north approach")
    assert_equal(dirs["7,2"].south, nil, "(7,2) should stay open from south until confirmed")
    assert_equal(dirs["9,3"].west, true, "(9,3) should block west approach")
    assert_equal(dirs["9,4"].west, true, "(9,4) should block west approach")
    assert_equal(dirs["9,5"].west, true, "(9,5) should block west approach")

    env.restore()
end

function tests.metadata_width_height_are_inclusive_coordinates()
    local env = make_env({
        rom_bytes = {
            [0] = 0x00,
            [1] = 0x80,
            [2] = 29,
            [3] = 29,
            [4] = 0,
        },
    })

    local meta = env.map_reader.get_metadata(0)
    assert_equal(meta.width, 30, "map metadata width should include the max X coordinate")
    assert_equal(meta.height, 30, "map metadata height should include the max Y coordinate")

    env.restore()
end

function tests.tantegel_castle_decoder_gap_cells_are_passthrough()
    local env = make_env({
        rom_bytes = {
            [20] = 0x00,
            [21] = 0x80,
            [22] = 29,
            [23] = 29,
            [24] = 0,
        },
    })

    local left = env.map_reader.get_walkability_details(0x04, 13, 16)
    local right = env.map_reader.get_walkability_details(0x04, 14, 16)
    local mid_0 = env.map_reader.get_walkability_details(0x04, 15, 16)
    local mid_a = env.map_reader.get_walkability_details(0x04, 16, 16)
    local mid_b = env.map_reader.get_walkability_details(0x04, 17, 16)

    assert_equal(left.base_walkable, true, "(13,16) should be treated as passable via passthrough override")
    assert_equal(left.effective_walkable, true, "(13,16) should be pathable after the decoder fix")
    assert_equal(left.reason, "passthrough", "(13,16) should record passthrough as its walkability source")

    assert_equal(right.base_walkable, true, "(14,16) should be treated as passable via passthrough override")
    assert_equal(right.effective_walkable, true, "(14,16) should be pathable after the decoder fix")
    assert_equal(right.reason, "passthrough", "(14,16) should record passthrough as its walkability source")

    assert_equal(mid_0.base_walkable, true, "(15,16) should be treated as passable via passthrough override")
    assert_equal(mid_0.effective_walkable, true, "(15,16) should be pathable after the decoder fix")
    assert_equal(mid_0.reason, "passthrough", "(15,16) should record passthrough as its walkability source")

    assert_equal(mid_a.base_walkable, true, "(16,16) should be treated as passable via passthrough override")
    assert_equal(mid_a.effective_walkable, true, "(16,16) should be pathable after the decoder fix")
    assert_equal(mid_a.reason, "passthrough", "(16,16) should record passthrough as its walkability source")

    assert_equal(mid_b.base_walkable, true, "(17,16) should be treated as passable via passthrough override")
    assert_equal(mid_b.effective_walkable, true, "(17,16) should be pathable after the decoder fix")
    assert_equal(mid_b.reason, "passthrough", "(17,16) should record passthrough as its walkability source")

    env.restore()
end

function tests.tantegel_castle_death_tile_is_modeled_as_hazard()
    local data_start = 0x110
    local rom_bytes = {
        [20] = 0x00,
        [21] = 0x81,
        [22] = 29,
        [23] = 29,
        [24] = 0,
    }
    for i = 0, 56 do
        rom_bytes[data_start + i] = 0x4F
    end

    local env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = {
            [0] = 0x10,
        },
    })

    assert_equal(env.map_reader.is_hazard_cell(0x04, 10, 18), "damage", "(10,18) should be tracked as a damage hazard")

    local details = env.map_reader.get_walkability_details(0x04, 10, 18)
    assert_equal(details.base_walkable, true, "(10,18) should remain engine-walkable in the base model")
    assert_equal(details.hazard, "damage", "(10,18) should report the hazard type")
    assert_equal(details.effective_walkable, false, "(10,18) should be forbidden for pathfinding")
    assert_equal(details.reason, "hazard", "(10,18) should report hazard rather than wall/permanent_blocked")
    assert_equal(env.map_reader.is_walkable(0x04, 10, 18), false, "(10,18) should not be pathfinder-walkable")

    local snapshot = env.map_reader.get_walkability_snapshot(0x04)
    assert_equal(snapshot[18][10], false, "walkability snapshot should exclude the death tile")

    env.restore()
end

function tests.tantegel_castle_west_wing_boundary_cell_is_fully_blocked()
    local env = make_env()

    assert_equal(
        env.map_reader.is_permanently_blocked_override(0x04, 6, 9),
        true,
        "(6,9) should be a permanent block after the direct two-sided live retest"
    )

    local dirs = env.map_reader.get_directional_blocks(0x04)
    assert_equal(dirs["6,9"], nil, "(6,9) should no longer remain directional-only")

    env.restore()
end

function tests.tantegel_castle_south_pocket_false_blocks_are_open()
    local env = make_env()

    assert_equal(
        env.map_reader.is_permanently_blocked_override(0x04, 13, 24),
        false,
        "(13,24) should stay open after direct live probe from (12,24)"
    )
    assert_equal(
        env.map_reader.is_permanently_blocked_override(0x04, 14, 20),
        false,
        "(14,20) should remain directional-only rather than permanently blocked"
    )

    local seam_a = env.map_reader.get_walkability_details(0x04, 13, 24)
    local seam_b = env.map_reader.get_walkability_details(0x04, 14, 20)
    assert_equal(seam_a.permanent_blocked, false, "(13,24) should not be marked permanently blocked after stale-block removal")
    assert_equal(seam_b.permanent_blocked, false, "(14,20) should not be marked permanently blocked after stale-block removal")

    local dirs = env.map_reader.get_directional_blocks(0x04)
    assert_equal(dirs["12,19"].south, true, "(12,19) should block south approach after the restored run-4 evidence")
    assert_equal(dirs["12,19"].east, true, "(12,19) should keep its east-side blocker until directly disproved")
    assert_equal(dirs["13,24"].west, true, "(13,24) should block west approach after repeated live repros from (12,24)")
    assert_equal(dirs["14,20"].west, true, "(14,20) should block west approach after repeated live repros")
    assert_equal(dirs["12,16"].east, true, "(12,16) should block east approach after repeated live repros from (13,16)")
    assert_equal(dirs["12,16"].north, true, "(12,16) should keep its north-side blocker")
    assert_equal(dirs["6,13"].east, true, "(6,13) should block east approach after repeated direct seam repros from (7,13)")
    assert_equal(dirs["6,13"].west, true, "(6,13) should block west approach after fresh post-reload direct seam repros from (5,13)")
    assert_equal(dirs["4,13"].east, true, "(4,13) should block east approach after post-reload direct seam repro from (5,13)")
    assert_equal(dirs["3,16"], nil, "(3,16) should stay fully open until a stable directional block repro emerges")
    assert_equal(dirs["4,16"].east, true, "(4,16) should keep its east approach block after direct probe from (5,16)")
    assert_equal(dirs["4,16"].west, true, "(4,16) should block west approach after repeated direct probes from (3,16)")
    assert_equal(dirs["4,16"].south, nil, "(4,16) should stay open from south after repeated direct probes from (4,17)")
    assert_equal(dirs["4,7"].east, true, "(4,7) should block east approach: 3+ consistent survey hits in 2026-04-13 runs")
    assert_equal(dirs["4,7"].west, true, "(4,7) should block west approach after focused post-reload probe from (3,7)")
    assert_equal(dirs["3,6"], nil, "(3,6) should stay open after focused post-reload probe from (3,7)")
    assert_equal(dirs["4,6"], nil, "(4,6) should stay open after focused post-reload probe from (4,5)")
    assert_equal(dirs["6,24"].west, nil, "(6,24) should stay open from west after repeated live probes")
    assert_equal(dirs["6,24"].north, true, "(6,24) should keep its north-side blocker pending a direct repro")

    env.restore()
end

function tests.tantegel_castle_east_connector_raw_confirmed_blocks_are_modeled()
    -- Rechecked 2026-04-26 after the fresh parked-NPC survey and full reload.
    -- A first raw-input pass appeared to split the set, but post-reload
    -- normalized adjacent-start controls stayed in place on all six seams.
    local env = make_env()
    local dirs = env.map_reader.get_directional_blocks(0x04)
    assert_equal(dirs["17,6"].north, true, "(17,6) north approach should block after raw DOWN,90 stayed at (17,5)")
    assert_equal(dirs["18,6"].north, true, "(18,6) north approach should block after raw DOWN,90 stayed at (18,5)")
    assert_equal(dirs["19,6"].north, true, "(19,6) north approach should block after raw DOWN,90 stayed at (19,5)")
    assert_equal(dirs["20,6"].north, true, "(20,6) north approach should block after post-reload raw DOWN,90 stayed at (20,5)")
    assert_equal(dirs["21,4"].west, true, "(21,4) west approach should block after post-reload raw RIGHT,90 stayed at (20,4)")
    assert_equal(dirs["21,5"].west, true, "(21,5) west approach should block after post-reload raw RIGHT,90 stayed at (20,5)")
    env.restore()
end

function tests.tantegel_castle_south_gate_exit_wall_blocks_are_modeled()
    -- Confirmed 2026-04-26 after a restarted parked survey repeatedly hit this
    -- exit-wall band, followed by split direct probes with runtime blocks cleared.
    local env = make_env()
    local dirs = env.map_reader.get_directional_blocks(0x04)
    assert_equal(dirs["16,28"].south, true, "(16,28) should block south approach after direct UP probe from (16,29)")
    assert_equal(dirs["17,28"].south, true, "(17,28) should block south approach after direct UP probe from (17,29)")
    assert_equal(dirs["18,28"].south, true, "(18,28) should block south approach after direct UP probe from (18,29)")
    assert_equal(dirs["19,28"].south, true, "(19,28) should block south approach after direct UP probe from (19,29)")
    assert_equal(dirs["20,29"].west, true, "(20,29) should block west approach after direct RIGHT probe from (19,29)")
    env.restore()
end

function tests.tantegel_castle_x15_east_entries_are_engine_blocked()
    -- Re-confirmed 2026-04-24 via natural walk (no teleport artifacts):
    -- 90-frame LEFT hold from (17,y) stopped at (16,y) for y=1,2,3.
    -- The "moved" probes from the legit-throne-route investigation were
    -- anomalous sub-pixel states from overshoot movement, not normal gameplay.
    local env = make_env()

    local dirs = env.map_reader.get_directional_blocks(0x04)
    assert_equal(dirs["15,1"].east, true, "(15,1) engine-blocks east approach: confirmed by natural walk")
    assert_equal(dirs["15,2"].east, true, "(15,2) engine-blocks east approach: confirmed by natural walk")
    assert_equal(dirs["15,3"].east, true, "(15,3) engine-blocks east approach: confirmed by natural walk")
    assert_equal(dirs["15,3"].south, true, "(15,3) keeps confirmed south-entry blocker from (15,4)")

    env.restore()
end

function tests.tantegel_castle_upper_chamber_row_16_updates_are_modeled()
    local env = make_env()

    assert_equal(
        env.map_reader.is_permanently_blocked_override(0x04, 20, 17),
        false,
        "(20,17) should stay open after repeated live probes from west and south"
    )
    assert_equal(
        env.map_reader.is_permanently_blocked_override(0x04, 19, 16),
        false,
        "(19,16) should stay open after repeated live probes from north, south, east, and west"
    )
    assert_equal(
        env.map_reader.is_permanently_blocked_override(0x04, 18, 16),
        false,
        "(18,16) should no longer remain a full-cell blocker after repeated live entries"
    )
    assert_equal(
        env.map_reader.is_permanently_blocked_override(0x04, 17, 16),
        false,
        "(17,16) should no longer remain a full-cell blocker after repeated live entries from north and east"
    )
    assert_equal(
        env.map_reader.is_permanently_blocked_override(0x04, 16, 16),
        false,
        "(16,16) should no longer remain a full-cell blocker after repeated live entries from north and south"
    )
    assert_equal(
        env.map_reader.is_permanently_blocked_override(0x04, 15, 16),
        false,
        "(15,16) should no longer remain a full-cell blocker after repeated live entries from east and south"
    )

    local chamber_entry = env.map_reader.get_walkability_details(0x04, 20, 17)
    assert_equal(
        chamber_entry.permanent_blocked,
        false,
        "(20,17) should no longer be marked permanently blocked"
    )

    local west_entry = env.map_reader.get_walkability_details(0x04, 19, 16)
    assert_equal(
        west_entry.permanent_blocked,
        false,
        "(19,16) should no longer be marked permanently blocked"
    )

    local dirs = env.map_reader.get_directional_blocks(0x04)
    assert_equal(dirs["16,16"].east, nil, "(16,16) should stay open from east after later direct west-step repros")
    assert_equal(dirs["16,16"].north, nil, "(16,16) should stay open from north after the direct down-step repro")
    assert_equal(dirs["16,16"].south, true, "(16,16) should block the south approach: survey runtime block moving up from (16,17) on 2026-04-13")
    assert_equal(dirs["15,16"].west, true, "(15,16) should block the west approach: survey runtime block moving right from (14,16) on 2026-04-13")
    assert_equal(dirs["17,16"].south, true, "(17,16) should block the south approach after the 2026-04-13 repro")
    assert_equal(dirs["17,16"].north, nil, "(17,16) should stay open from north after the direct down-step repro")
    assert_equal(dirs["17,16"].east, nil, "(17,16) should stay open from east after the direct west-step repro")
    assert_equal(dirs["18,16"].south, true, "(18,16) should block the south approach after the 2026-04-13 repro")
    assert_equal(dirs["18,16"].north, nil, "(18,16) should stay open from north after the direct down-step repro")
    assert_equal(dirs["19,16"].south, true, "(19,16) should block the south approach after the restored one-way y=16 evidence")
    assert_equal(dirs["19,16"].north, nil, "(19,16) should stay open from north after the direct down-step repro")

    env.restore()
end

function tests.brecconary_permanent_blockers_match_current_live_model()
    local env = make_env()

    assert_equal(env.map_reader.is_permanently_blocked_override(0x08, 21, 4), true, "(21,4) should stay permanently blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x08, 11, 26), true, "(11,26) should stay permanently blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x08, 16, 23), true, "(16,23) should be pathfinder-forbidden after direct trap-cell probes")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x08, 18, 17), true, "(18,17) should be pathfinder-forbidden after direct trap-cell probes")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x08, 17, 22), true, "(17,22) should be pathfinder-forbidden after direct trap-cell probes")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x08, 27, 2), false, "(27,2) should remain directional-only")

    env.restore()
end

function tests.brecconary_directional_walls_cover_confirmed_building_bands()
    local env = make_env()

    local dirs = env.map_reader.get_directional_blocks(0x08)
    assert_equal(dirs["3,4"].west, true, "(3,4) should block west approach")
    assert_equal(dirs["3,5"].west, true, "(3,5) should block west approach after post-reload survey and brute-force repros from (2,5)")
    assert_equal(dirs["4,3"].north, true, "(4,3) should block north approach")
    assert_equal(dirs["5,3"].north, true, "(5,3) should block north approach")
    assert_equal(dirs["6,3"].north, true, "(6,3) should block north approach")
    assert_equal(dirs["7,3"].north, true, "(7,3) should block north approach")
    assert_equal(dirs["7,3"].east, true, "(7,3) should block east approach")
    assert_equal(dirs["20,2"].west, true, "(20,2) should block west approach")
    assert_equal(dirs["20,2"].north, true, "(20,2) should block north approach")
    assert_equal(dirs["25,6"].south, true, "(25,6) should block south approach")
    assert_equal(dirs["27,2"].north, true, "(27,2) should block north approach after live probe confirmation")
    assert_equal(dirs["27,2"].east, true, "(27,2) should block east approach after survey confirmation")
    assert_equal(dirs["27,3"].east, true, "(27,3) should block east approach")
    assert_equal(dirs["27,4"].east, true, "(27,4) should block east approach")
    assert_equal(dirs["27,5"].east, true, "(27,5) should block east approach after direct live validation from (28,5)")
    assert_equal(dirs["27,6"].east, true, "(27,6) should block east approach")
    assert_equal(dirs["27,6"].south, true, "(27,6) should keep its south approach block")
    assert_equal(dirs["21,9"].north, true, "(21,9) should block north approach")
    assert_equal(dirs["22,9"].north, true, "(22,9) should block north approach")
    assert_equal(dirs["23,9"].north, true, "(23,9) should block north approach")
    assert_equal(dirs["24,9"].north, true, "(24,9) should block north approach")
    assert_equal(dirs["25,9"].north, true, "(25,9) should block north approach")
    assert_equal(dirs["26,9"].north, true, "(26,9) should block north approach")
    assert_equal(dirs["26,9"].east, true, "(26,9) should block east approach")
    assert_equal(dirs["11,20"].north, true, "(11,20) should keep its north approach block")
    assert_equal(dirs["11,20"].east, true, "(11,20) should block east approach after survey confirmation")
    assert_equal(dirs["11,21"].east, true, "(11,21) should block east approach after repeated reroute evidence")
    assert_equal(dirs["11,22"].east, true, "(11,22) should block east approach after repeated reroute evidence")
    assert_equal(dirs["11,23"].east, true, "(11,23) should block east approach after repeated reroute evidence")
    assert_equal(dirs["11,23"].west, true, "(11,23) should block west approach after repeated reroute evidence")
    assert_equal(dirs["11,24"].east, true, "(11,24) should block east approach after repeated reroute evidence")
    assert_equal(dirs["11,24"].west, true, "(11,24) should block west approach after repeated reroute evidence")
    assert_equal(dirs["11,25"].east, true, "(11,25) should block east approach after repeated reroute evidence")
    assert_equal(dirs["11,25"].west, true, "(11,25) should block west approach after repeated reroute evidence")
    assert_equal(dirs["5,21"].east, true, "(5,21) should block east approach after direct Merchant 1 pocket repro from (6,21)")
    assert_equal(dirs["6,20"].south, true, "(6,20) should block south approach after direct Merchant 1 pocket repro from (6,21)")
    assert_equal(dirs["7,22"].north, true, "(7,22) should block north approach")
    assert_equal(dirs["7,22"].south, true, "(7,22) should block south approach")
    assert_equal(dirs["7,22"].west, true, "(7,22) should block west approach")
    assert_equal(dirs["7,19"].east, true, "(7,19) should block east approach after direct Merchant 1 repro from (8,19)")
    assert_equal(dirs["7,21"].west, true, "(7,21) should block west approach after direct Merchant 1 pocket repro from (6,21)")
    assert_equal(dirs["8,22"].north, true, "(8,22) should block north approach")
    assert_equal(dirs["8,22"].south, true, "(8,22) should block south approach")
    assert_equal(dirs["9,20"].west, true, "(9,20) should block west approach")
    assert_equal(dirs["9,21"].west, true, "(9,21) should block west approach")
    assert_equal(dirs["9,22"].south, true, "(9,22) should block south approach")
    assert_equal(dirs["10,22"].south, true, "(10,22) should block south approach")
    assert_equal(dirs["8,24"].east, true, "(8,24) should block east approach")
    assert_equal(dirs["8,24"].north, true, "(8,24) should block north approach")
    assert_equal(dirs["5,23"].east, true, "(5,23) should block east approach after repeated southwest reroute trap repro")
    assert_equal(dirs["8,25"].east, true, "(8,25) should block east approach after repeated southwest reroute trap repro")
    assert_equal(dirs["8,25"].west, true, "(8,25) should block west approach after Guard 4 direct probe from (7,25)")
    assert_equal(dirs["8,26"].east, true, "(8,26) should block east approach after repeated southwest reroute trap repro")
    assert_equal(dirs["8,26"].west, true, "(8,26) should block west approach after Guard 4 direct probe from (7,26)")
    assert_equal(dirs["8,26"].north, true, "(8,26) should block north approach after Guard 4 direct probe from (8,25)")
    assert_equal(dirs["3,27"].south, true, "(3,27) should block south approach")
    assert_equal(dirs["4,27"].south, true, "(4,27) should block south approach")
    assert_equal(dirs["5,27"].south, true, "(5,27) should block south approach")
    assert_equal(dirs["6,27"].south, true, "(6,27) should block south approach")
    assert_equal(dirs["7,27"].south, true, "(7,27) should block south approach")
    assert_equal(dirs["8,27"].south, true, "(8,27) should block south approach after direct probe and raw hold from (8,28)")
    assert_equal(dirs["8,27"].north, nil, "(8,27) should keep north approach open after reverse probe from (8,27) to (8,28)")
    assert_equal(dirs["9,27"].north, true, "(9,27) should block north approach after repeated southwest reroute trap repro")
    assert_equal(dirs["9,27"].south, true, "(9,27) should block south approach after repeated late-survey failure from (9,28)")
    assert_equal(dirs["10,27"].north, true, "(10,27) should block north approach after Brecconary survey and split probe from (10,26)")
    assert_equal(dirs["10,27"].south, true, "(10,27) should block south approach after route-context probe and raw hold from (10,28)")
    assert_equal(dirs["11,27"].east, true, "(11,27) should block east approach")
    assert_equal(dirs["11,27"].south, true, "(11,27) should block south approach")
    assert_equal(dirs["18,12"].south, true, "(18,12) should block south approach")
    assert_equal(dirs["18,21"].north, true, "(18,21) should block north approach")
    assert_equal(dirs["18,21"].south, true, "(18,21) should block south approach")
    assert_equal(dirs["19,20"].north, true, "(19,20) should block north approach")
    assert_equal(dirs["19,20"].west, true, "(19,20) should block west approach")
    assert_equal(dirs["19,21"].east, true, "(19,21) should block east approach")
    assert_equal(dirs["19,21"].south, true, "(19,21) should block south approach")
    assert_equal(dirs["20,19"].north, true, "(20,19) should block north approach")
    assert_equal(dirs["20,19"].west, true, "(20,19) should block west approach")
    assert_equal(dirs["20,20"].south, true, "(20,20) should block south approach")
    assert_equal(dirs["21,18"].west, true, "(21,18) should block west approach")
    assert_equal(dirs["21,20"].south, true, "(21,20) should block south approach")
    assert_equal(dirs["22,20"].east, true, "(22,20) should block east approach")
    assert_equal(dirs["22,20"].south, true, "(22,20) should block south approach")
    assert_equal(dirs["7,20"].east, true, "(7,20) should block east approach after repeated live failure from (8,20)")
    assert_equal(dirs["7,20"].south, true, "(7,20) should block south approach after repeated live failure from (7,21)")
    assert_equal(dirs["24,17"].north, true, "(24,17) should block north approach")
    assert_equal(dirs["25,16"].west, true, "(25,16) should block west approach")
    assert_equal(dirs["25,12"].south, true, "(25,12) should block south approach")
    assert_equal(dirs["26,11"].east, true, "(26,11) should block east approach")
    assert_equal(dirs["26,12"].east, true, "(26,12) should block east approach")
    assert_equal(dirs["26,12"].south, true, "(26,12) should block south approach")
    assert_equal(dirs["26,16"].north, true, "(26,16) should block north approach")
    assert_equal(dirs["27,16"].east, true, "(27,16) should block east approach")
    assert_equal(dirs["27,16"].north, true, "(27,16) should block north approach")
    assert_equal(dirs["28,17"].east, true, "(28,17) should block east approach")
    assert_equal(dirs["28,17"].north, true, "(28,17) should block north approach")
    assert_equal(dirs["15,28"].north, true, "(15,28) should block north approach")
    assert_equal(dirs["15,28"].west, true, "(15,28) should block west approach")
    assert_equal(dirs["16,27"].north, true, "(16,27) should block north approach")
    assert_equal(dirs["16,27"].west, true, "(16,27) should block west approach")

    env.restore()
end

function tests.brecconary_passthrough_corridor_overrides_false_wall_tiles()
    local base = 8 * 5
    local env = make_env({
        rom_bytes = {
            [base] = 0x00,      -- CPU $8000 -> file offset $0010
            [base + 1] = 0x80,
            [base + 2] = 11,    -- width 12
            [base + 3] = 19,    -- height 20
            [base + 4] = 0,
            [0x10] = 0x0F, [0x11] = 0x0F, [0x12] = 0x0F, [0x13] = 0x0F,
            [0x14] = 0x0F, [0x15] = 0x0F, [0x16] = 0x0F, [0x17] = 0x0F,
            [0x18] = 0x0F, [0x19] = 0x0F, [0x1A] = 0x0F, [0x1B] = 0x0F,
            [0x1C] = 0x0F, [0x1D] = 0x0F, [0x1E] = 0x0F,
        },
        memory_bytes = {
            [0] = 0x10, -- TERRAIN_OFFSET stubbed to 0 in make_env()
        },
    })

    assert_equal(env.map_reader.is_walkable(0x08, 9, 18), true, "(9,18) should be walkable via Brecconary passthrough")
    assert_equal(env.map_reader.is_walkable(0x08, 10, 18), true, "(10,18) should be walkable via Brecconary passthrough")
    assert_equal(env.map_reader.is_walkable(0x08, 11, 18), true, "(11,18) should be walkable via Brecconary passthrough")
    assert_equal(env.map_reader.is_walkable(0x08, 11, 19), true, "(11,19) should be walkable via Brecconary passthrough")
    assert_equal(env.map_reader.is_walkable(0x08, 8, 18), true, "(8,18) should be walkable via Brecconary passthrough")
    assert_equal(env.map_reader.is_walkable(0x08, 8, 19), true, "(8,19) should be walkable via Brecconary passthrough")
    assert_equal(env.map_reader.is_walkable(0x08, 10, 19), false, "(10,19) should remain non-walkable until confirmed")
    local snapshot = env.map_reader.get_walkability_snapshot(0x08)
    assert_equal(snapshot[18][9], true, "walkability snapshot should honor Brecconary passthrough cells")
    assert_equal(snapshot[19][10], false, "walkability snapshot should preserve unconfirmed Brecconary wall cells")

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
