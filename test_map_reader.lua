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

function tests.brecconary_locked_doors_open_from_door_ram_array()
    local base = 8 * 5
    local data_start = 0x10
    local rom_bytes = {
        [base] = 0x00,
        [base + 1] = 0x80,
        [base + 2] = 29,
        [base + 3] = 29,
        [base + 4] = 0,
    }
    for i = 0, 56 do
        rom_bytes[data_start + i] = 0xFF
    end

    local closed_env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = {
            [0] = 0x10,
        },
        door_array_max = 8,
        door_x_pos_start = 0x600C,
        door_y_pos_start = 0x600D,
        door_array_stride = 2,
    })

    local closed_ne = closed_env.map_reader.get_walkability_details(0x08, 21, 6)
    assert_equal(closed_ne.effective_walkable, false, "closed Brecconary northeast door should block movement")
    assert_equal(closed_ne.reason, "door_closed", "closed Brecconary northeast door should report door_closed")
    local closed_inn = closed_env.map_reader.get_walkability_details(0x08, 5, 22)
    assert_equal(closed_inn.effective_walkable, false, "closed Brecconary inn west-room door should block movement")
    assert_equal(closed_inn.reason, "door_closed", "closed Brecconary inn west-room door should report door_closed")
    closed_env.restore()

    local open_env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = {
            [0] = 0x10,
            [0x600C] = 21,
            [0x600D] = 6,
            [0x600E] = 5,
            [0x600F] = 22,
        },
        door_array_max = 8,
        door_x_pos_start = 0x600C,
        door_y_pos_start = 0x600D,
        door_array_stride = 2,
    })

    local open_ne = open_env.map_reader.get_walkability_details(0x08, 21, 6)
    assert_equal(open_ne.effective_walkable, true, "opened Brecconary northeast door should become walkable")
    assert_equal(open_ne.reason, "door_open", "opened Brecconary northeast door should report door_open")
    local open_inn = open_env.map_reader.get_walkability_details(0x08, 5, 22)
    assert_equal(open_inn.effective_walkable, true, "opened Brecconary inn west-room door should become walkable")
    assert_equal(open_inn.reason, "door_open", "opened Brecconary inn west-room door should report door_open")
    local snapshot = open_env.map_reader.get_walkability_snapshot(0x08)
    assert_equal(snapshot[6][21], true, "walkability snapshot should honor opened Brecconary northeast door")
    assert_equal(snapshot[22][5], true, "walkability snapshot should honor opened Brecconary inn west-room door")

    open_env.restore()
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

function tests.raw_block_reader_uses_high_and_low_nibbles_by_coordinate()
    local data_start = 0x110
    local env = make_env({
        rom_bytes = {
            [0] = 0x00,
            [1] = 0x81,
            [2] = 3,
            [3] = 1,
            [4] = 0,
            [data_start + 0] = 0x4F,
            [data_start + 1] = 0xC0,
            [data_start + 2] = 0x9A,
            [data_start + 3] = 0x12,
        },
    })

    assert_equal(env.map_reader.get_raw_block_id(0, 0, 0), 0x04, "even X should read the high nibble")
    assert_equal(env.map_reader.get_raw_block_id(0, 1, 0), 0x0F, "odd X should read the low nibble")
    assert_equal(env.map_reader.get_raw_block_id(0, 2, 0), 0x0C, "next byte high nibble should read the next even X")
    assert_equal(env.map_reader.get_raw_block_id(0, 3, 0), 0x00, "next byte low nibble should read the next odd X")
    assert_equal(env.map_reader.get_raw_block_id(0, 0, 1), 0x09, "Y should advance by ceil(width / 2) bytes")
    assert_equal(env.map_reader.get_raw_block_id(0, 4, 0), nil, "out-of-bounds X should return nil")

    env.restore()
end

function tests.large_tile_detection_uses_raw_block_f()
    local data_start = 0x110
    local env = make_env({
        rom_bytes = {
            [0] = 0x00,
            [1] = 0x81,
            [2] = 3,
            [3] = 0,
            [4] = 0,
            [data_start + 0] = 0x4F,
            [data_start + 1] = 0xC0,
        },
    })

    assert_equal(env.map_reader.is_large_tile(0, 0, 0), false, "raw block 4 is not a large tile")
    assert_equal(env.map_reader.is_large_tile(0, 1, 0), true, "raw block F should be a large tile")
    assert_equal(env.map_reader.is_large_tile(0, 2, 0), false, "raw block C is not a large tile")

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
    assert_equal(
        env.map_reader.is_permanently_blocked_override(0x04, 20, 20),
        false,
        "(20,20) should remain standable after raw probes crossed it from multiple sides"
    )

    local seam_a = env.map_reader.get_walkability_details(0x04, 13, 24)
    local seam_b = env.map_reader.get_walkability_details(0x04, 14, 20)
    local seam_c = env.map_reader.get_walkability_details(0x04, 20, 20)
    assert_equal(seam_a.permanent_blocked, false, "(13,24) should not be marked permanently blocked after stale-block removal")
    assert_equal(seam_b.permanent_blocked, false, "(14,20) should not be marked permanently blocked after stale-block removal")
    assert_equal(seam_c.permanent_blocked, false, "(20,20) should not be marked permanently blocked after 2026-05-14 retest")

    local dirs = env.map_reader.get_directional_blocks(0x04)
    assert_equal(dirs["12,19"].south, true, "(12,19) should block south approach after the restored run-4 evidence")
    assert_equal(dirs["12,19"].east, true, "(12,19) should keep its east-side blocker until directly disproved")
    assert_equal(dirs["13,24"].west, true, "(13,24) should block west approach after repeated live repros from (12,24)")
    assert_equal(dirs["13,24"].east, true, "(13,24) should block east approach after raw verifier proof from (14,24)")
    assert_equal(dirs["14,20"].west, true, "(14,20) should block west approach after repeated live repros")
    assert_equal(dirs["21,20"].west, true, "(21,20) should block west approach after raw probe from (20,20)")
    assert_equal(dirs["20,20"], nil, "(20,20) should not keep stale directional approach blocks after passable reverse probes")
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
    assert_equal(dirs["17,28"].north, true, "(17,28) should block north approach after raw DOWN verifier from (17,27)")
    assert_equal(dirs["18,28"].south, true, "(18,28) should block south approach after direct UP probe from (18,29)")
    assert_equal(dirs["18,28"].north, true, "(18,28) should block north approach after raw DOWN verifier from (18,27)")
    assert_equal(dirs["19,25"].west, true, "(19,25) should block west approach after clean-state raw RIGHT verifier from (18,25)")
    assert_equal(dirs["19,26"].west, true, "(19,26) should block west approach after clean-state raw RIGHT verifier from (18,26)")
    assert_equal(dirs["19,27"].west, true, "(19,27) should block west approach after clean-state raw RIGHT verifier from (18,27)")
    assert_equal(dirs["19,28"].south, true, "(19,28) should block south approach after direct UP probe from (19,29)")
    assert_equal(dirs["20,29"].west, true, "(20,29) should block west approach after direct RIGHT probe from (19,29)")
    assert_equal(dirs["12,28"].south, true, "(12,28) should block south approach after raw UP verifier from (12,29)")
    assert_equal(dirs["13,28"].south, true, "(13,28) should block south approach after raw UP verifier from (13,29)")
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
    assert_equal(env.map_reader.is_permanently_blocked_override(0x08, 17, 22), false, "(17,22) should stay open after raw verifier proof from both east-west corridor approaches")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x08, 4, 4), true, "(4,4) should be pathfinder-forbidden after Merchant 2 west pocket trap repro")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x08, 4, 5), true, "(4,5) should be pathfinder-forbidden after Merchant 2 west pocket trap repro")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x08, 4, 6), true, "(4,6) should be pathfinder-forbidden after stationary Woman 3 sealed the west pocket")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x08, 5, 5), true, "(5,5) should be pathfinder-forbidden after Merchant 2 south pocket trap repro")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x08, 6, 4), true, "(6,4) should be pathfinder-forbidden after Merchant 2 pocket trap repro")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x08, 6, 5), true, "(6,5) should be pathfinder-forbidden after Merchant 2 pocket trap repro")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x08, 27, 2), false, "(27,2) should remain directional-only")

    env.restore()
end

function tests.brecconary_directional_walls_cover_confirmed_building_bands()
    local env = make_env()

    local dirs = env.map_reader.get_directional_blocks(0x08)
    local function assert_open_approach(cell, approach, message)
        local entry = dirs[cell]
        assert_equal(entry and entry[approach] or nil, nil, message)
    end

    assert_equal(dirs["3,4"].west, true, "(3,4) should block west approach")
    assert_equal(dirs["3,4"].east, true, "(3,4) should block east approach after Merchant 2 west pocket exit repro")
    assert_equal(dirs["3,5"].west, true, "(3,5) should block west approach after post-reload survey and brute-force repros from (2,5)")
    assert_equal(dirs["3,5"].east, true, "(3,5) should block east approach after Merchant 2 west pocket exit repro")
    assert_equal(dirs["4,3"].north, true, "(4,3) should block north approach")
    assert_equal(dirs["4,3"].south, true, "(4,3) should block south approach after Merchant 2 west pocket exit repro")
    assert_equal(dirs["5,3"].north, true, "(5,3) should block north approach after 5/5 probe_edge_verify from (5,2)")
    assert_equal(dirs["5,3"].south, nil, "(5,3) should stay directional-only; Merchant 2 uses the counter at (5,6)")
    assert_equal(dirs["6,3"].north, true, "(6,3) should block north approach")
    assert_equal(dirs["6,3"].south, true, "(6,3) should block south approach after Merchant 2 pocket exit repro")
    assert_equal(dirs["7,3"].north, true, "(7,3) should block north approach")
    assert_equal(dirs["7,3"].east, true, "(7,3) should block east approach")
    assert_equal(dirs["7,4"].east, true, "(7,4) should block east approach after repeated Merchant 2 route failures from (8,4)")
    assert_equal(dirs["7,4"].west, true, "(7,4) should block west approach after Merchant 2 pocket exit repro")
    assert_equal(dirs["5,5"].east, true, "(5,5) should block east approach after Merchant 2 pocket exit repro")
    assert_equal(dirs["7,5"].west, true, "(7,5) should block west approach after Merchant 2 pocket exit repro")
    assert_equal(dirs["7,5"].east, true, "(7,5) should block east approach after controlled public-side route repro from (8,5)")
    assert_equal(dirs["5,6"], nil, "(5,6) should stay open; manual/live movement crossed between (5,7) and (5,6) both ways")
    assert_equal(dirs["5,8"], nil, "(5,8) should stay open; manual movement crossed between (5,7) and (5,8) both ways")
    assert_equal(dirs["6,7"].west, true, "(6,7) should block west approach after selected-NPC teleport trap repro from (5,7)")
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
    assert_equal(dirs["23,9"].east, true, "(23,9) should block east approach after Old Man 2 landing trap proof from (24,9)")
    assert_equal(dirs["23,9"].south, true, "(23,9) should block south approach after Old Man 2 landing trap proof from (23,10)")
    assert_equal(dirs["24,8"].south, true, "(24,8) should block south approach after Old Man 2 north-landing trap proof")
    assert_equal(dirs["23,10"].north, true, "(23,10) should block north approach; (23,9) and (23,10) are not mutually reachable")
    assert_equal(dirs["23,10"].west, true, "(23,10) should block west approach after manual validation")
    assert_equal(dirs["24,9"].north, true, "(24,9) should block north approach")
    assert_equal(dirs["25,9"].north, true, "(25,9) should block north approach")
    assert_equal(dirs["25,9"].west, true, "(25,9) should block west approach after Old Man 2 north-landing trap proof")
    assert_equal(dirs["26,9"].north, true, "(26,9) should block north approach")
    assert_equal(dirs["26,9"].east, true, "(26,9) should block east approach")
    assert_equal(dirs["22,10"].east, true, "(22,10) should block east approach after Old Man 2 west-landing trap proof")
    local cell_24_11 = dirs["24,11"] or {}
    local cell_24_12 = dirs["24,12"] or {}
    assert_equal(cell_24_11.south, nil, "(24,11) should stay open from the south; manual validation crossed (24,12)->(24,11)")
    assert_equal(cell_24_12.north, nil, "(24,12) should stay open from the north; manual validation crossed (24,11)->(24,12)")
    assert_equal(dirs["4,13"].east, true, "(4,13) should block east approach after Merchant 2 exit-route timeout from (5,13)")
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
    assert_equal(dirs["8,17"].west, true, "(8,17) should block west approach after inn route timeout from (7,17)")
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
    assert_open_approach("17,22", "west", "(17,22) should stay open from west after raw verifier proof from (16,22)")
    assert_open_approach("17,22", "east", "(17,22) should stay open from east after raw verifier proof from (18,22)")
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
    assert_equal(dirs["17,25"].west, true, "(17,25) should block west approach after raw verifier proof from (16,25)")
    assert_equal(dirs["23,25"].east, true, "(23,25) should block east movement into Merchant 4's counter trigger while still serving as the public TALK stand")
    assert_equal(dirs["24,25"].west, true, "(24,25) should block west movement out of Merchant 4's counter trigger")
    assert_equal(dirs["24,26"].west, true, "(24,26) should block west approach after Merchant 4 false-wall check failed from (23,26)")
    assert_equal(dirs["25,27"].north, true, "(25,27) should block south exit from Merchant 4's interaction tile")
    assert_equal(dirs["24,27"].east, true, "(24,27) should block west exit from Merchant 4's southeast pocket")
    assert_equal(dirs["24,27"].south, true, "(24,27) should block south approach after Merchant 4 row-28 route validation failed from (24,28)")
    assert_equal(dirs["25,28"].north, true, "(25,28) should block south exit from Merchant 4's southeast pocket")
    assert_equal(dirs["25,28"].west, true, "(25,28) should block west approach after Merchant 4 row-28 route validation failed from (24,28)")
    assert_equal(dirs["24,29"].north, true, "(24,29) should block north approach after Merchant 4 bottom-row route validation failed from (24,28)")
    assert_equal(dirs["23,29"].north, true, "(23,29) should block north approach after Merchant 4 bottom-row route validation failed from (23,28)")
    assert_equal(dirs["22,29"].north, true, "(22,29) should block north approach after Merchant 4 bottom-row route validation failed from (22,28)")
    assert_equal(dirs["28,28"].north, true, "(28,28) should block north approach after Merchant 4 lower-right validation failed from (28,27)")
    assert_equal(dirs["28,28"].west, true, "(28,28) should block west approach after manual Merchant 4 route check from (27,28)")
    assert_open_approach("22,21", "south", "(22,21) should stay open from south after manual Merchant 4 cluster check")
    assert_open_approach("22,22", "north", "(22,22) should stay open from north after manual Merchant 4 cluster check")
    assert_open_approach("22,23", "north", "(22,23) should stay open from north after manual Merchant 4 cluster check")
    assert_open_approach("22,24", "north", "(22,24) should stay open from north after manual Merchant 4 cluster check")
    assert_open_approach("22,25", "north", "(22,25) should stay open from north after manual Merchant 4 cluster check")
    assert_open_approach("22,26", "north", "(22,26) should stay open from north after manual Merchant 4 cluster check")
    assert_equal(dirs["22,27"].north, true, "(22,27) should block north approach toward Merchant 4's southeast pocket")
    assert_equal(dirs["21,26"].east, true, "(21,26) should block east approach after repeated live/manual blocks from (22,26)")
    assert_equal(dirs["21,25"].east, true, "(21,25) should block east approach after manual Merchant 4 route check from (22,25)")
    assert_equal(dirs["23,23"].north, true, "(23,23) should block north approach after manual Merchant 4 route check from (23,22)")
    assert_open_approach("25,23", "north", "(25,23) should stay open from north after manual Merchant 4 route check from (25,22)")
    assert_equal(dirs["26,28"].east, true, "(26,28) should block east approach after manual Merchant 4 route check from (27,28)")
    assert_equal(dirs["27,29"].north, true, "(27,29) should block north approach after manual Merchant 4 route check from (27,28)")
    assert_equal(dirs["21,27"].west, true, "(21,27) should block west approach after Merchant 4 route validation failed from (20,27)")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x08, 24, 25), false, "(24,25) should not be fully blocked; only its verified west seam is closed")

    env.restore()
end

function tests.brecconary_passthrough_corridor_overrides_false_wall_tiles()
    local base = 8 * 5
    local env = make_env({
        rom_bytes = {
            [base] = 0x00,      -- CPU $8000 -> file offset $0010
            [base + 1] = 0x80,
            [base + 2] = 29,    -- width 30
            [base + 3] = 29,    -- height 30
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
    assert_equal(env.map_reader.is_walkable(0x08, 3, 7), true, "(3,7) should be walkable via the west-wing throat passthrough")
    assert_equal(env.map_reader.is_walkable(0x08, 2, 9), true, "(2,9) should be walkable via the west-wing throat passthrough")
    assert_equal(env.map_reader.is_walkable(0x08, 3, 9), true, "(3,9) should be walkable via the west-wing throat passthrough")
    assert_equal(env.map_reader.is_walkable(0x08, 3, 6), false, "(3,6) should remain closed after repeated blocked movement from the south")
    assert_equal(env.map_reader.is_walkable(0x08, 22, 24), true, "(22,24) should be walkable via the east-wing throat passthrough")
    assert_equal(env.map_reader.is_walkable(0x08, 4, 7), true, "(4,7) should be walkable via the Merchant 2 west-side passthrough")
    assert_equal(env.map_reader.is_walkable(0x08, 4, 6), false, "(4,6) should be pathfinder-forbidden after Merchant 2 west-side trap repro")
    assert_equal(env.map_reader.is_walkable(0x08, 5, 6), true, "(5,6) should be walkable via the Merchant 2 counter interaction passthrough")
    assert_equal(env.map_reader.is_walkable(0x08, 5, 7), true, "(5,7) should be walkable via the Merchant 2 doorway throat passthrough")
    assert_equal(env.map_reader.is_walkable(0x08, 20, 26), true, "(20,26) should be walkable via the Merchant 4 lower approach passthrough")
    assert_equal(env.map_reader.is_walkable(0x08, 17, 22), true, "(17,22) should be walkable in the long east-west corridor")
    assert_equal(env.map_reader.is_walkable(0x08, 17, 25), true, "(17,25) should remain standable via the Merchant 4 lower-west bridge passthrough")
    assert_equal(env.map_reader.is_walkable(0x08, 21, 26), true, "(21,26) should remain standable despite its blocked east approach")
    assert_equal(env.map_reader.is_walkable(0x08, 23, 26), true, "(23,26) should be walkable via the Merchant 4 public-side false-wall passthrough")
    assert_equal(env.map_reader.is_walkable(0x08, 27, 26), true, "(27,26) should be walkable via the Merchant 4 east-side false-wall passthrough")
    assert_equal(env.map_reader.is_walkable(0x08, 24, 12), true, "(24,12) should be walkable via the Curse Remover public-approach passthrough")
    assert_equal(env.map_reader.is_walkable(0x08, 10, 19), false, "(10,19) should remain non-walkable until confirmed")
    local snapshot = env.map_reader.get_walkability_snapshot(0x08)
    assert_equal(snapshot[18][9], true, "walkability snapshot should honor Brecconary passthrough cells")
    assert_equal(snapshot[7][3], true, "walkability snapshot should include the west-wing north throat")
    assert_equal(snapshot[9][2], true, "walkability snapshot should include the west-wing west throat")
    assert_equal(snapshot[9][3], true, "walkability snapshot should include the west-wing south throat")
    assert_equal(snapshot[6][3], false, "walkability snapshot should keep the blocked northern cap closed")
    assert_equal(snapshot[24][22], true, "walkability snapshot should include the east-wing throat")
    assert_equal(snapshot[22][17], true, "walkability snapshot should include the row-22 east-west corridor")
    assert_equal(snapshot[12][24], true, "walkability snapshot should include the Curse Remover public-approach passthrough")
    assert_equal(snapshot[6][4], false, "walkability snapshot should keep the Merchant 2 west-side trap out of A*")
    assert_equal(snapshot[6][5], true, "walkability snapshot should include the Merchant 2 counter interaction square")
    assert_equal(snapshot[7][5], true, "walkability snapshot should include the Merchant 2 doorway throat")
    assert_equal(snapshot[26][20], true, "walkability snapshot should include the Merchant 4 lower approach cell")
    assert_equal(snapshot[25][17], true, "walkability snapshot should include the Merchant 4 lower-west bridge")
    assert_equal(snapshot[26][23], true, "walkability snapshot should include the Merchant 4 public-side false-wall cell")
    assert_equal(snapshot[26][27], true, "walkability snapshot should include the Merchant 4 east-side false-wall cell")
    assert_equal(snapshot[19][10], false, "walkability snapshot should preserve unconfirmed Brecconary wall cells")

    env.restore()
end

function tests.brecconary_tool_shop_public_stand_is_passthrough()
    local base = 8 * 5
    local env = make_env({
        rom_bytes = {
            [base] = 0x00,
            [base + 1] = 0x80,
            [base + 2] = 29,
            [base + 3] = 29,
            [base + 4] = 0,
        },
        memory_bytes = {
            [0] = 0x10,
        },
    })

    local stand = env.map_reader.get_walkability_details(0x08, 25, 26)
    assert_equal(stand.base_walkable, true, "(25,26) should be treated as passable via the Merchant 4 passthrough")
    assert_equal(stand.effective_walkable, true, "(25,26) should be pathable as the tool-shop interaction tile")
    assert_equal(stand.reason, "passthrough", "(25,26) should record passthrough as its walkability source")

    local snapshot = env.map_reader.get_walkability_snapshot(0x08)
    assert_equal(snapshot[26][25], true, "walkability snapshot should include the Merchant 4 interaction tile")

    env.restore()
end

function tests.erdricks_cave_b1_entrance_passthrough_overrides_edge_boundary()
    local base = 0x1C * 5
    local env = make_env({
        rom_bytes = {
            [base] = 0x00,      -- CPU $8000 -> file offset $0010
            [base + 1] = 0x80,
            [base + 2] = 9,     -- width 10
            [base + 3] = 9,     -- height 10
            [base + 4] = 0,
            [0x10] = 0x99,      -- row 0: ten type-9 edge/wall tiles
            [0x11] = 0x90,      -- row 1 x=0: type-9 boundary tile
            [0x12] = 0x88,      -- row 1 x=1-9: type-8 floor/stair strip
            [0x13] = 0x0F, [0x14] = 0x0F, [0x15] = 0x0F,
            [0x16] = 0x0F, [0x17] = 0x0F, -- remaining 80 floor tiles
        },
        memory_bytes = {
            [0] = 0x20, -- TERRAIN_OFFSET stubbed to 0 in make_env()
        },
    })

    local exit = env.map_reader.get_walkability_details(0x1C, 0, 0)
    assert_equal(exit.base_walkable, true, "Erdrick B1 entrance exit tile should be passable")
    assert_equal(exit.reason, "passthrough", "Erdrick B1 entrance exit should override edge boundary")

    local strip = env.map_reader.get_walkability_details(0x1C, 1, 0)
    assert_equal(strip.base_walkable, true, "Erdrick B1 entrance strip should be passable")
    assert_equal(strip.reason, "passthrough", "Erdrick B1 entrance strip should override edge boundary")

    local west_wall = env.map_reader.get_walkability_details(0x1C, 0, 1)
    assert_equal(west_wall.base_walkable, false, "unconfirmed Erdrick B1 west edge should remain blocked")
    assert_equal(west_wall.reason, "engine_boundary", "unconfirmed Erdrick B1 west edge should keep boundary reason")

    local entrance_floor = env.map_reader.get_walkability_details(0x1C, 1, 1)
    assert_equal(entrance_floor.base_walkable, true, "Erdrick B1 entrance floor should stay tile-walkable")
    assert_equal(entrance_floor.reason, "tile_type", "Erdrick B1 entrance floor should not need passthrough")

    local snapshot = env.map_reader.get_walkability_snapshot(0x1C)
    assert_equal(snapshot[0][0], true, "walkability snapshot should include the Erdrick B1 exit tile")
    assert_equal(snapshot[0][1], true, "walkability snapshot should include the Erdrick B1 entrance strip")
    assert_equal(snapshot[1][0], false, "walkability snapshot should keep the unconfirmed west edge blocked")
    assert_equal(snapshot[1][1], true, "walkability snapshot should include the Erdrick B1 entrance floor")

    env.restore()
end

function tests.erdricks_cave_b2_left_edge_loop_passthrough_overrides_boundary()
    local base = 0x1D * 5
    local env = make_env({
        rom_bytes = {
            [base] = 0x00,      -- CPU $8000 -> file offset $0010
            [base + 1] = 0x80,
            [base + 2] = 9,     -- width 10
            [base + 3] = 9,     -- height 10
            [base + 4] = 0,
            [0x10] = 0xAF, [0x11] = 0xAF, [0x12] = 0xAF,
            [0x13] = 0xAF, [0x14] = 0xAF, [0x15] = 0xAF,
            [0x16] = 0xA3,      -- 100 type-A cave-floor cells
        },
        memory_bytes = {
            [0] = 0x20, -- TERRAIN_OFFSET stubbed to 0 in make_env()
        },
    })

    for x = 0, 6 do
        local details = env.map_reader.get_walkability_details(0x1D, x, 0)
        assert_equal(details.base_walkable, true, "Erdrick B2 top-edge route cell should be passable")
        assert_equal(details.reason, "passthrough", "Erdrick B2 top-edge route cell should override boundary")
    end

    for _, y in ipairs({1, 2, 4, 5, 6, 7}) do
        local details = env.map_reader.get_walkability_details(0x1D, 0, y)
        assert_equal(details.base_walkable, true, "Erdrick B2 left-edge route cell should be passable")
        assert_equal(details.reason, "passthrough", "Erdrick B2 left-edge route cell should override boundary")
    end

    local unconfirmed_top_edge = env.map_reader.get_walkability_details(0x1D, 7, 0)
    assert_equal(unconfirmed_top_edge.base_walkable, false, "unconfirmed Erdrick B2 top edge past x=6 should stay unmodeled")
    assert_equal(unconfirmed_top_edge.reason, "engine_boundary", "unconfirmed Erdrick B2 top edge should keep boundary reason")

    local south_pocket = env.map_reader.get_walkability_details(0x1D, 0, 9)
    assert_equal(south_pocket.base_walkable, false, "mixed Erdrick B2 (0,9) edge pocket should stay unmodeled")
    assert_equal(south_pocket.reason, "engine_boundary", "mixed Erdrick B2 (0,9) should keep boundary reason")

    local north_wall = env.map_reader.get_walkability_details(0x1D, 0, 3)
    assert_equal(north_wall.base_walkable, false, "blocked Erdrick B2 (0,3) edge should stay unmodeled")
    assert_equal(north_wall.reason, "engine_boundary", "blocked Erdrick B2 (0,3) should keep boundary reason")

    local blocked_gap = env.map_reader.get_walkability_details(0x1D, 0, 8)
    assert_equal(blocked_gap.base_walkable, false, "blocked Erdrick B2 (0,8) edge should stay unmodeled")
    assert_equal(blocked_gap.reason, "engine_boundary", "blocked Erdrick B2 (0,8) should keep boundary reason")

    local snapshot = env.map_reader.get_walkability_snapshot(0x1D)
    assert_equal(snapshot[0][0], true, "walkability snapshot should include B2 upper-left corner route")
    assert_equal(snapshot[0][6], true, "walkability snapshot should include B2 top-edge route through x=6")
    assert_equal(snapshot[0][7], false, "walkability snapshot should keep unconfirmed B2 top-edge x=7 blocked")
    assert_equal(snapshot[1][0], true, "walkability snapshot should include B2 upper-left route y=1")
    assert_equal(snapshot[2][0], true, "walkability snapshot should include B2 upper-left route y=2")
    assert_equal(snapshot[4][0], true, "walkability snapshot should include B2 left-edge route y=4")
    assert_equal(snapshot[7][0], true, "walkability snapshot should include B2 left-edge route y=7")
    assert_equal(snapshot[8][0], false, "walkability snapshot should keep B2 left-edge gap y=8 blocked")
    assert_equal(snapshot[9][0], false, "walkability snapshot should keep mixed B2 left-edge pocket y=9 blocked")

    env.restore()
end

function tests.erdricks_cave_b1_stair_to_entrance_seams_are_directional()
    local env = make_env()

    local dirs = env.map_reader.get_directional_blocks(0x1C)
    assert_equal(dirs["2,1"].west, true, "Erdrick B1 (2,1) should block entry from the west after 5/5 verifier consensus")
    assert_equal(dirs["2,1"].south, true, "Erdrick B1 (2,1) should block entry from the south after route failure and 5/5 verifier consensus")
    assert_equal(dirs["2,1"].east, true, "Erdrick B1 (2,1) should block entry from the east after route failure and 5/5 verifier consensus")
    assert_equal(dirs["2,1"].north, nil, "Erdrick B1 (2,1) should keep unconfirmed approaches open")
    assert_equal(dirs["2,3"].west, true, "Erdrick B1 (2,3) should block entry from the west after 5/5 verifier consensus")
    assert_equal(dirs["2,3"].north, true, "Erdrick B1 (2,3) should block entry from the north after fresh 5/5 verifier consensus")
    assert_equal(dirs["2,3"].east, nil, "Erdrick B1 (2,3) should keep unconfirmed approaches open")
    assert_equal(dirs["3,3"].south, true, "Erdrick B1 (3,3) should block entry from the south")
    assert_equal(dirs["3,3"].north, true, "Erdrick B1 (3,3) should block entry from the north")
    assert_equal(dirs["3,3"].east, nil, "Erdrick B1 (3,3) should keep unconfirmed approaches open")
    assert_equal(dirs["4,3"].south, true, "Erdrick B1 (4,3) should block entry from the south")
    assert_equal(dirs["4,3"].north, true, "Erdrick B1 (4,3) should block entry from the north")
    assert_equal(dirs["4,3"].east, true, "Erdrick B1 (4,3) should block entry from the east after route failure and 5/5 verifier consensus")
    assert_equal(dirs["4,3"].west, nil, "Erdrick B1 (4,3) should keep unconfirmed approaches open")
    assert_equal(dirs["2,4"].east, true, "Erdrick B1 (2,4) should block entry from the east")
    assert_equal(dirs["2,4"].west, true, "Erdrick B1 (2,4) should block entry from the west")
    assert_equal(dirs["2,4"].north, nil, "Erdrick B1 (2,4) should keep unconfirmed approaches open")
    assert_equal(dirs["3,5"].north, true, "Erdrick B1 (3,5) should block entry from the north")
    assert_equal(dirs["3,5"].south, true, "Erdrick B1 (3,5) should block entry from the south after route failure and 5/5 verifier consensus")
    assert_equal(dirs["4,1"].south, true, "Erdrick B1 (4,1) should block entry from the south after 5/5 verifier consensus")
    assert_equal(dirs["4,1"].north, nil, "Erdrick B1 (4,1) should keep unconfirmed approaches open")
    assert_equal(dirs["5,1"].south, true, "Erdrick B1 (5,1) should block entry from the south after 5/5 verifier consensus")
    assert_equal(dirs["5,1"].east, true, "Erdrick B1 (5,1) should block entry from the east after 5/5 verifier consensus")
    assert_equal(dirs["5,1"].north, nil, "Erdrick B1 (5,1) should keep unconfirmed approaches open")
    assert_equal(dirs["5,1"].west, nil, "Erdrick B1 (5,1) should keep unconfirmed approaches open")
    assert_equal(dirs["4,5"].north, true, "Erdrick B1 (4,5) should block entry from the north after 5/5 verifier consensus")
    assert_equal(dirs["4,5"].east, true, "Erdrick B1 (4,5) should block entry from the east after 5/5 verifier consensus")
    assert_equal(dirs["4,5"].south, true, "Erdrick B1 (4,5) should block entry from the south after route failure and 5/5 verifier consensus")
    assert_equal(dirs["4,5"].west, nil, "Erdrick B1 (4,5) should keep unconfirmed approaches open")
    assert_equal(dirs["7,2"].west, true, "Erdrick B1 (7,2) should block entry from the west")
    assert_equal(dirs["7,2"].north, true, "Erdrick B1 (7,2) should block entry from the north after route failure and 5/5 verifier consensus")
    assert_equal(dirs["7,2"].east, nil, "Erdrick B1 (7,2) should not be fully blocked")
    assert_equal(dirs["8,2"].south, true, "Erdrick B1 (8,2) should block entry from the south after route failure and 5/5 verifier consensus")
    assert_equal(dirs["8,2"].east, true, "Erdrick B1 (8,2) should block entry from the east after route failure and 5/5 verifier consensus")
    assert_equal(dirs["8,2"].north, nil, "Erdrick B1 (8,2) should keep mixed verifier approaches open")
    assert_equal(dirs["7,3"].south, true, "Erdrick B1 (7,3) should block entry from the south after route failure and 5/5 verifier consensus")
    assert_equal(dirs["7,3"].east, true, "Erdrick B1 (7,3) should block entry from the east after route failure and 5/5 verifier consensus")
    assert_equal(dirs["7,3"].west, nil, "Erdrick B1 (7,3) should keep unconfirmed approaches open")
    assert_equal(dirs["6,3"].north, true, "Erdrick B1 (6,3) should block entry from the north")
    assert_equal(dirs["6,3"].west, nil, "Erdrick B1 (6,3) should keep noisy west approach open until repeated verification")
    assert_equal(dirs["6,3"].south, nil, "Erdrick B1 (6,3) should not be fully blocked")
    assert_equal(dirs["6,4"].west, true, "Erdrick B1 (6,4) should block entry from the west after 5/5 verifier consensus")
    assert_equal(dirs["6,4"].south, true, "Erdrick B1 (6,4) should block entry from the south after 5/5 verifier consensus")
    assert_equal(dirs["6,4"].east, true, "Erdrick B1 (6,4) should block entry from the east after route failure and 5/5 verifier consensus")
    assert_equal(dirs["1,5"].north, true, "Erdrick B1 (1,5) should block entry from the north")
    assert_equal(dirs["1,5"].south, true, "Erdrick B1 (1,5) should block entry from the south after route failure and 5/5 verifier consensus")
    assert_equal(dirs["1,5"].east, nil, "Erdrick B1 (1,5) should keep unconfirmed approaches open")
    assert_equal(dirs["2,5"].south, true, "Erdrick B1 (2,5) should block entry from the south after route failure and 5/5 verifier consensus")
    assert_equal(dirs["2,5"].north, nil, "Erdrick B1 (2,5) should keep unconfirmed approaches open")
    assert_equal(dirs["6,6"].west, true, "Erdrick B1 (6,6) should block entry from the west")
    assert_equal(dirs["6,6"].north, true, "Erdrick B1 (6,6) should block entry from the north after fresh 5/5 verifier consensus")
    assert_equal(dirs["6,6"].east, true, "Erdrick B1 (6,6) should block entry from the east after route failure and 5/5 verifier consensus")
    assert_equal(dirs["6,7"].east, true, "Erdrick B1 (6,7) should block entry from the east after route failure and 5/5 verifier consensus")
    assert_equal(dirs["6,7"].west, nil, "Erdrick B1 (6,7) should keep unconfirmed approaches open")
    assert_equal(dirs["8,5"].west, true, "Erdrick B1 (8,5) should block entry from the west after 5/5 verifier consensus")
    assert_equal(dirs["8,5"].east, nil, "Erdrick B1 (8,5) should keep unconfirmed approaches open")
    assert_equal(dirs["9,5"].south, true, "Erdrick B1 (9,5) should block entry from the south after route failure and 5/5 verifier consensus")
    assert_equal(dirs["9,5"].north, nil, "Erdrick B1 (9,5) should keep unconfirmed approaches open")
    assert_equal(dirs["8,6"].west, true, "Erdrick B1 (8,6) should block entry from the west after 5/5 verifier consensus")
    assert_equal(dirs["8,6"].south, true, "Erdrick B1 (8,6) should block entry from the south after 5/5 verifier consensus")
    assert_equal(dirs["8,6"].east, true, "Erdrick B1 (8,6) should block entry from the east after route failure and 5/5 verifier consensus")
    assert_equal(dirs["5,7"].north, true, "Erdrick B1 (5,7) should block entry from the north")
    assert_equal(dirs["5,7"].south, true, "Erdrick B1 (5,7) should block entry from the south after route failure and 5/5 verifier consensus")
    assert_equal(dirs["5,7"].west, true, "Erdrick B1 (5,7) should block entry from the west after route failure and 5/5 verifier consensus")
    assert_equal(dirs["5,7"].east, nil, "Erdrick B1 (5,7) should keep unconfirmed approaches open")
    assert_equal(dirs["8,8"].west, true, "Erdrick B1 (8,8) should block entry from the west")
    assert_equal(dirs["8,8"].north, true, "Erdrick B1 (8,8) should block entry from the north")
    assert_equal(dirs["8,8"].east, true, "Erdrick B1 (8,8) should block entry from the east after 5/5 verifier consensus")
    assert_equal(dirs["8,8"].south, nil, "Erdrick B1 (8,8) should keep unconfirmed approaches open")
    assert_equal(dirs["8,9"].west, true, "Erdrick B1 (8,9) should block entry from the west")
    assert_equal(dirs["8,9"].east, true, "Erdrick B1 (8,9) should block entry from the east after 5/5 verifier consensus")
    assert_equal(dirs["8,9"].north, nil, "Erdrick B1 (8,9) should keep unconfirmed approaches open")
    assert_equal(dirs["8,9"].south, nil, "Erdrick B1 (8,9) should keep unconfirmed approaches open")

    env.restore()
end

function tests.erdricks_cave_b2_chest_route_seams_are_directional()
    local env = make_env()

    local dirs = env.map_reader.get_directional_blocks(0x1D)
    assert_equal(dirs["1,1"].south, true, "Erdrick B2 (1,1) should block entry from the south after 15/15 verifier consensus")
    assert_equal(dirs["1,1"].west, true, "Erdrick B2 (1,1) should block entry from the west after 15/15 verifier consensus")
    assert_equal(dirs["1,1"].north, true, "Erdrick B2 (1,1) should block entry from the north after top-edge probe")
    assert_equal(dirs["1,1"].east, nil, "Erdrick B2 (1,1) should keep unconfirmed east approach open")
    assert_equal(dirs["2,1"].south, true, "Erdrick B2 (2,1) should block entry from the south after repeated route evidence")
    assert_equal(dirs["2,1"].north, true, "Erdrick B2 (2,1) should block entry from the north after top-edge probe")
    assert_equal(dirs["3,1"].south, true, "Erdrick B2 (3,1) should block entry from the south after repeated route evidence")
    assert_equal(dirs["3,1"].north, true, "Erdrick B2 (3,1) should block entry from the north after top-edge probe")
    assert_equal(dirs["4,1"].south, true, "Erdrick B2 (4,1) should block entry from the south after repeated route evidence")
    assert_equal(dirs["4,1"].north, true, "Erdrick B2 (4,1) should block entry from the north after top-edge probe")
    assert_equal(dirs["1,3"].south, true, "Erdrick B2 (1,3) should block entry from the south after 5/5 verifier consensus")
    assert_equal(dirs["1,3"].north, nil, "Erdrick B2 (1,3) should keep unconfirmed approaches open")
    assert_equal(dirs["2,3"].south, true, "Erdrick B2 (2,3) should block entry from the south after 5/5 verifier consensus")
    assert_equal(dirs["2,3"].east, true, "Erdrick B2 (2,3) should block entry from the east after repeated route evidence")
    assert_equal(dirs["2,3"].north, nil, "Erdrick B2 (2,3) should keep unconfirmed approaches open")
    assert_equal(dirs["4,3"].west, true, "Erdrick B2 (4,3) should block entry from the west after 5/5 verifier consensus")
    assert_equal(dirs["4,3"].north, true, "Erdrick B2 (4,3) should block entry from the north after repeated route evidence")
    assert_equal(dirs["4,3"].east, nil, "Erdrick B2 (4,3) should keep unconfirmed approaches open")
    assert_equal(dirs["4,4"].east, true, "Erdrick B2 (4,4) should block entry from the east after 5/5 verifier consensus")
    assert_equal(dirs["4,4"].west, true, "Erdrick B2 (4,4) should block entry from the west after repeated route evidence")
    assert_equal(dirs["5,3"].south, true, "Erdrick B2 (5,3) should block entry from the south after 5/5 verifier consensus")
    assert_equal(dirs["5,3"].north, nil, "Erdrick B2 (5,3) should keep unconfirmed approaches open")
    assert_equal(dirs["3,5"].south, true, "Erdrick B2 (3,5) should block entry from the south after 5/5 verifier consensus")
    assert_equal(dirs["3,5"].north, true, "Erdrick B2 (3,5) should block entry from the north after repeated route evidence")
    assert_equal(dirs["3,5"].west, true, "Erdrick B2 (3,5) should block entry from the west after repeated route evidence")
    assert_equal(dirs["4,5"].east, true, "Erdrick B2 (4,5) should block entry from the east after 5/5 verifier consensus")
    assert_equal(dirs["4,5"].west, nil, "Erdrick B2 (4,5) should keep unconfirmed approaches open")
    assert_equal(dirs["5,1"].east, true, "Erdrick B2 (5,1) should block entry from the east after reverse-route 10/10 verifier consensus")
    assert_equal(dirs["5,1"].north, true, "Erdrick B2 (5,1) should block entry from the north after top-edge probe")
    assert_equal(dirs["5,1"].west, nil, "Erdrick B2 (5,1) should keep unconfirmed approaches open")
    assert_equal(dirs["5,2"].east, true, "Erdrick B2 (5,2) should block entry from the east after reverse-route 10/10 verifier consensus")
    assert_equal(dirs["5,2"].west, true, "Erdrick B2 (5,2) should block entry from the west after repeated route evidence")
    assert_equal(dirs["1,5"].west, true, "Erdrick B2 (1,5) should block entry from the west after repeated route evidence")
    assert_equal(dirs["6,4"].west, true, "Erdrick B2 (6,4) should block entry from the west after 5/5 verifier consensus")
    assert_equal(dirs["6,4"].north, true, "Erdrick B2 (6,4) should block entry from the north after reverse-route 10/10 verifier consensus")
    assert_equal(dirs["6,4"].east, nil, "Erdrick B2 (6,4) should keep unconfirmed approaches open")
    assert_equal(dirs["6,5"].east, true, "Erdrick B2 (6,5) should block entry from the east after 5/5 verifier consensus")
    assert_equal(dirs["6,5"].south, true, "Erdrick B2 (6,5) should block entry from the south after repeated 5/5 verifier consensus")
    assert_equal(dirs["6,5"].west, true, "Erdrick B2 (6,5) should block entry from the west after fresh 5/5 verifier consensus")
    assert_equal(dirs["4,6"].east, true, "Erdrick B2 (4,6) should block entry from the east after 5/5 verifier consensus")
    assert_equal(dirs["4,6"].west, true, "Erdrick B2 (4,6) should block entry from the west after 5/5 verifier consensus")
    assert_equal(dirs["4,6"].north, nil, "Erdrick B2 (4,6) should keep unconfirmed approaches open")
    assert_equal(dirs["4,7"].south, true, "Erdrick B2 (4,7) should block entry from the south after fresh 5/5 verifier consensus")
    assert_equal(dirs["4,7"].west, true, "Erdrick B2 (4,7) should block entry from the west after fresh 5/5 verifier consensus")
    assert_equal(dirs["4,7"].north, nil, "Erdrick B2 (4,7) should keep unconfirmed approaches open")
    assert_equal(dirs["4,7"].east, nil, "Erdrick B2 (4,7) should keep unconfirmed approaches open")
    assert_equal(dirs["5,7"].north, true, "Erdrick B2 (5,7) should block entry from the north after 5/5 verifier consensus")
    assert_equal(dirs["5,7"].east, true, "Erdrick B2 (5,7) should block entry from the east after 5/5 verifier consensus")
    assert_equal(dirs["5,7"].west, nil, "Erdrick B2 (5,7) should keep unconfirmed approaches open")
    assert_equal(dirs["7,4"].south, true, "Erdrick B2 (7,4) should block entry from the south after 5/5 verifier consensus")
    assert_equal(dirs["7,4"].north, true, "Erdrick B2 (7,4) should block entry from the north after reverse-route 10/10 verifier consensus")
    assert_equal(dirs["7,4"].east, true, "Erdrick B2 (7,4) should block entry from the east after fresh 15/15 verifier consensus from (8,4)")
    assert_equal(dirs["7,4"].west, nil, "Erdrick B2 (7,4) should keep unconfirmed approaches open")
    assert_equal(dirs["7,7"].north, true, "Erdrick B2 (7,7) should block entry from the north after fresh 5/5 verifier consensus")
    assert_equal(dirs["7,7"].south, nil, "Erdrick B2 (7,7) should keep unconfirmed approaches open")
    assert_equal(dirs["8,5"].west, true, "Erdrick B2 (8,5) should block entry from the west after 5/5 verifier consensus")
    assert_equal(dirs["8,5"].south, true, "Erdrick B2 (8,5) should block entry from the south after 5/5 verifier consensus")
    assert_equal(dirs["8,5"].north, true, "Erdrick B2 (8,5) should block entry from the north after fresh 15/15 verifier consensus from (8,4)")
    assert_equal(dirs["8,5"].east, nil, "Erdrick B2 (8,5) should keep unconfirmed approaches open")
    assert_equal(dirs["9,5"].south, true, "Erdrick B2 (9,5) should block entry from the south after raw-hold repro from (9,6)")
    assert_equal(dirs["9,5"].north, true, "Erdrick B2 (9,5) should block entry from the north after reverse-route 10/10 verifier consensus")
    assert_equal(dirs["1,6"].south, true, "Erdrick B2 (1,6) should block entry from the south after 5/5 verifier consensus")
    assert_equal(dirs["1,6"].east, nil, "Erdrick B2 (1,6) should keep unconfirmed approaches open")
    assert_equal(dirs["2,6"].south, true, "Erdrick B2 (2,6) should block entry from the south after 5/5 verifier consensus")
    assert_equal(dirs["2,6"].east, true, "Erdrick B2 (2,6) should block entry from the east after real-reload 10/10 verifier consensus")
    assert_equal(dirs["2,6"].north, nil, "Erdrick B2 (2,6) should keep unconfirmed approaches open")
    assert_equal(dirs["8,7"].south, true, "Erdrick B2 (8,7) should block entry from the south after 5/5 verifier consensus")
    assert_equal(dirs["8,7"].north, true, "Erdrick B2 (8,7) should block entry from the north after fresh 5/5 verifier consensus")
    assert_equal(dirs["8,7"].east, true, "Erdrick B2 (8,7) should block entry from the east after fresh 5/5 verifier consensus")
    assert_equal(dirs["8,7"].west, nil, "Erdrick B2 (8,7) should keep unconfirmed approaches open")
    assert_equal(dirs["5,8"].south, true, "Erdrick B2 (5,8) should block entry from the south after 5/5 verifier consensus")
    assert_equal(dirs["5,8"].east, true, "Erdrick B2 (5,8) should block entry from the east after 5/5 verifier consensus")
    assert_equal(dirs["5,8"].west, true, "Erdrick B2 (5,8) should block entry from the west after 5/5 verifier consensus")
    assert_equal(dirs["5,8"].north, nil, "Erdrick B2 (5,8) should keep unconfirmed approaches open")
    assert_equal(dirs["7,8"].west, true, "Erdrick B2 (7,8) should block entry from the west after 5/5 verifier consensus")
    assert_equal(dirs["7,8"].east, true, "Erdrick B2 (7,8) should block entry from the east after 5/5 verifier consensus")
    assert_equal(dirs["7,8"].north, nil, "Erdrick B2 (7,8) should keep unconfirmed approaches open")
    assert_equal(dirs["7,9"].east, true, "Erdrick B2 (7,9) should block entry from the east after route-shaped raw walk and fresh 15/15 verifier")
    assert_equal(dirs["7,9"].west, nil, "Erdrick B2 (7,9) should keep unconfirmed approaches open")
    assert_equal(dirs["7,5"], nil, "Erdrick B2 route evidence should not globally block the origin cell (7,5)")

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
