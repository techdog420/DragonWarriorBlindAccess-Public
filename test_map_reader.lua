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

local MAP_NAMES = {
    [0x04] = "Tantegel Castle",
    [0x08] = "Brecconary",
}

local function map_label(map_id)
    return MAP_NAMES[map_id] or string.format("map 0x%02X", map_id)
end

local function assert_directional_block(env, map_id, cell, approach, message)
    local dirs = env.map_reader.get_directional_blocks(map_id)
    local entry = dirs[cell]
    assert_equal(
        entry and entry[approach] or nil,
        true,
        string.format("%s [%s 0x%02X %s.%s]", message, map_label(map_id), map_id, cell, approach)
    )
end

local function assert_no_directional_entry(env, map_id, cell, message)
    local dirs = env.map_reader.get_directional_blocks(map_id)
    assert_equal(
        dirs[cell],
        nil,
        string.format("%s [%s 0x%02X %s]", message, map_label(map_id), map_id, cell)
    )
end

local function assert_tantegel_dir(env, cell, approach, message)
    assert_directional_block(env, 0x04, cell, approach, message)
end

local function assert_not_brecconary_dir(env, cell, message)
    assert_no_directional_entry(env, 0x08, cell, message)
end

local function path_has_step(path, x, y, direction)
    for _, step in ipairs(path or {}) do
        if step.x == x and step.y == y and step.direction == direction then
            return true
        end
    end
    return false
end

local tests = {}

function tests.directional_block_comments_match_their_map_block()
    local path = "map_reader.lua"
    local fh = assert(io.open(path, "r"))
    local line_no = 0
    local in_directional_blocks = false
    local current_map = nil
    local failures = {}

    for raw_line in fh:lines() do
        line_no = line_no + 1
        if raw_line:match("^local MAP_DIRECTIONAL_BLOCKS%s*=") then
            in_directional_blocks = true
        elseif in_directional_blocks then
            local map_hex = raw_line:match("^%s*%[(0x[%da-fA-F]+)%]%s*=%s*{")
            if map_hex then
                current_map = tonumber(map_hex)
            end

            if current_map and raw_line:match("^%s*%-%-") then
                local lower = raw_line:lower()
                local wrong_for_brecconary = current_map == 0x08 and (
                    lower:find("tantegel", 1, true)
                    or lower:find("sun shrine", 1, true)
                    or lower:find("throne-room route", 1, true)
                    or lower:find("throne room route", 1, true)
                    or lower:find("castle entrance", 1, true)
                )
                local wrong_for_tantegel = current_map == 0x04 and (
                    lower:find("brecconary", 1, true)
                    or lower:find("map 0x08", 1, true)
                )

                if wrong_for_brecconary or wrong_for_tantegel then
                    failures[#failures + 1] = string.format(
                        "%s:%d: map 0x%02X comment looks like it belongs to another map: %s",
                        path,
                        line_no,
                        current_map,
                        raw_line
                    )
                end
            end

            if current_map and raw_line:match("^%s%s%s%s},%s*$") then
                current_map = nil
            elseif raw_line:match("^}%s*$") then
                in_directional_blocks = false
            end
        end
    end
    fh:close()

    assert_equal(#failures, 0, table.concat(failures, "\n"))
end

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

function tests.tantegel_castle_locked_doors_open_from_door_ram_array()
    local base = 4 * 5
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

    local closed_west = closed_env.map_reader.get_walkability_details(0x04, 4, 13)
    assert_equal(closed_west.effective_walkable, false, "closed Tantegel west treasure door should block movement")
    assert_equal(closed_west.reason, "door_closed", "closed Tantegel west treasure door should report door_closed")
    local closed_north = closed_env.map_reader.get_walkability_details(0x04, 18, 6)
    assert_equal(closed_north.effective_walkable, false, "closed Tantegel north magic-key-area door should block movement")
    assert_equal(closed_north.reason, "door_closed", "closed Tantegel north magic-key-area door should report door_closed")
    assert_equal(closed_env.map_reader.get_door_cell_context(0x04, 14, 6), nil, "old Tantegel center y=6 model should not be a door")
    closed_env.restore()

    local open_env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = {
            [0] = 0x10,
            [0x600C] = 4,
            [0x600D] = 13,
            [0x600E] = 18,
            [0x600F] = 6,
        },
        door_array_max = 8,
        door_x_pos_start = 0x600C,
        door_y_pos_start = 0x600D,
        door_array_stride = 2,
    })

    local open_west = open_env.map_reader.get_walkability_details(0x04, 4, 13)
    assert_equal(open_west.effective_walkable, true, "opened Tantegel west treasure door should become walkable")
    assert_equal(open_west.reason, "door_open", "opened Tantegel west treasure door should report door_open")
    local open_north = open_env.map_reader.get_walkability_details(0x04, 18, 6)
    assert_equal(open_north.effective_walkable, true, "opened Tantegel north magic-key-area door should become walkable")
    assert_equal(open_north.reason, "door_open", "opened Tantegel north magic-key-area door should report door_open")
    assert_equal(open_env.map_reader.is_permanently_blocked_override(0x04, 4, 13), false, "(4,13) should not remain a full blocked cell after door proof")
    local dirs = open_env.map_reader.get_directional_blocks(0x04)
    assert_equal(dirs["4,13"], nil, "(4,13) should not keep stale directional blockers after door proof")
    assert_equal(dirs["18,6"], nil, "(18,6) should not keep stale north blocker after door proof")
    local snapshot = open_env.map_reader.get_walkability_snapshot(0x04)
    assert_equal(snapshot[13][4], true, "walkability snapshot should honor opened Tantegel west treasure door")
    assert_equal(snapshot[6][18], true, "walkability snapshot should honor opened Tantegel north magic-key-area door")

    open_env.restore()
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

function tests.garinham_east_locked_door_opens_from_door_ram_array()
    local base = 9 * 5
    local data_start = 0x10
    local rom_bytes = {
        [base] = 0x00,
        [base + 1] = 0x80,
        [base + 2] = 19,
        [base + 3] = 19,
        [base + 4] = 0,
    }
    for i = 0, 200 do
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

    local closed = closed_env.map_reader.get_walkability_details(0x09, 19, 16)
    assert_equal(closed.effective_walkable, false, "closed Garinham east door should block movement")
    assert_equal(closed.reason, "door_closed", "closed Garinham east door should report door_closed")
    closed_env.restore()

    local open_env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = {
            [0] = 0x10,
            [0x600C] = 19,
            [0x600D] = 16,
        },
        door_array_max = 8,
        door_x_pos_start = 0x600C,
        door_y_pos_start = 0x600D,
        door_array_stride = 2,
    })

    local open = open_env.map_reader.get_walkability_details(0x09, 19, 16)
    assert_equal(open.effective_walkable, true, "opened Garinham east door should become walkable")
    assert_equal(open.reason, "door_open", "opened Garinham east door should report door_open")
    local snapshot = open_env.map_reader.get_walkability_snapshot(0x09)
    assert_equal(snapshot[16][19], true, "walkability snapshot should honor opened Garinham east door")

    open_env.restore()
end

function tests.rimuldar_inn_doors_override_walkable_floor_until_open()
    local base = 0x0B * 5
    local data_start = 0x100
    local data_cpu_ptr = 0x8000 + data_start - 0x10
    local rom_bytes = {
        [base] = data_cpu_ptr % 0x100,
        [base + 1] = math.floor(data_cpu_ptr / 0x100),
        [base + 2] = 29,
        [base + 3] = 29,
        [base + 4] = 0,
    }
    for i = 0, 56 do
        rom_bytes[data_start + i] = 0x6F
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

    local outer_closed = closed_env.map_reader.get_walkability_details(0x0B, 21, 21)
    assert_equal(outer_closed.tile_type, 6, "Rimuldar inn outer door ROM tile should decode as floor")
    assert_equal(outer_closed.effective_walkable, false, "closed Rimuldar inn outer door should block movement")
    assert_equal(outer_closed.reason, "door_closed", "closed Rimuldar inn outer door should report door_closed")
    local inner_closed = closed_env.map_reader.get_walkability_details(0x0B, 22, 23)
    assert_equal(inner_closed.tile_type, 6, "Rimuldar Wings chest door ROM tile should decode as floor")
    assert_equal(inner_closed.effective_walkable, false, "closed Rimuldar Wings chest door should block movement")
    assert_equal(inner_closed.reason, "door_closed", "closed Rimuldar Wings chest door should report door_closed")
    closed_env.restore()

    local open_env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = {
            [0] = 0x10,
            [0x600C] = 21,
            [0x600D] = 21,
            [0x600E] = 22,
            [0x600F] = 23,
        },
        door_array_max = 8,
        door_x_pos_start = 0x600C,
        door_y_pos_start = 0x600D,
        door_array_stride = 2,
    })

    local outer_open = open_env.map_reader.get_walkability_details(0x0B, 21, 21)
    assert_equal(outer_open.tile_type, 6, "opened Rimuldar inn outer door should still decode as floor")
    assert_equal(outer_open.effective_walkable, true, "opened Rimuldar inn outer door should become walkable")
    assert_equal(outer_open.reason, "door_open", "opened Rimuldar inn outer door should report door_open")
    local inner_open = open_env.map_reader.get_walkability_details(0x0B, 22, 23)
    assert_equal(inner_open.tile_type, 6, "opened Rimuldar Wings chest door should still decode as floor")
    assert_equal(inner_open.effective_walkable, true, "opened Rimuldar Wings chest door should become walkable")
    assert_equal(inner_open.reason, "door_open", "opened Rimuldar Wings chest door should report door_open")
    local snapshot = open_env.map_reader.get_walkability_snapshot(0x0B)
    assert_equal(snapshot[21][21], true, "walkability snapshot should honor opened Rimuldar inn outer door")
    assert_equal(snapshot[23][22], true, "walkability snapshot should honor opened Rimuldar Wings chest door")

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
    local north_connector = env.map_reader.get_walkability_details(0x04, 14, 6)
    local door_side_connector = env.map_reader.get_walkability_details(0x04, 22, 8)
    local exterior_strip = {
        env.map_reader.get_walkability_details(0x04, 23, 8),
        env.map_reader.get_walkability_details(0x04, 24, 8),
        env.map_reader.get_walkability_details(0x04, 25, 8),
        env.map_reader.get_walkability_details(0x04, 26, 8),
    }
    local x29_hidden_bridge = env.map_reader.get_walkability_details(0x04, 29, 8)
    local x25_descent = env.map_reader.get_walkability_details(0x04, 25, 11)
    local lower_gap = env.map_reader.get_walkability_details(0x04, 14, 14)

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

    assert_equal(north_connector.base_walkable, true, "(14,6) should be treated as passable via passthrough override")
    assert_equal(north_connector.effective_walkable, true, "(14,6) should be pathable after the forward Sun Shrine route verifier")
    assert_equal(north_connector.reason, "passthrough", "(14,6) should record passthrough as its walkability source")

    assert_equal(door_side_connector.base_walkable, true, "(22,8) should be treated as passable via passthrough override")
    assert_equal(door_side_connector.effective_walkable, true, "(22,8) should connect the open key-area door side toward the Sun Shrine route")
    assert_equal(door_side_connector.reason, "passthrough", "(22,8) should record passthrough as its walkability source")
    for index, strip_cell in ipairs(exterior_strip) do
        local x = 22 + index
        assert_equal(strip_cell.base_walkable, true, string.format("(%d,8) should be treated as passable via top exterior-strip passthrough", x))
        assert_equal(strip_cell.effective_walkable, true, string.format("(%d,8) should connect the top exterior strip toward the Sun Shrine route", x))
        assert_equal(strip_cell.reason, "passthrough", string.format("(%d,8) should record passthrough as its walkability source", x))
    end
    assert_equal(x29_hidden_bridge.base_walkable, true, "(29,8) should be treated as passable via hidden-bridge passthrough")
    assert_equal(x29_hidden_bridge.effective_walkable, true, "(29,8) should connect the upper x=29 strip toward the Sun Shrine lane")
    assert_equal(x29_hidden_bridge.reason, "passthrough", "(29,8) should record passthrough as its walkability source")

    assert_equal(x25_descent.base_walkable, true, "(25,11) should be treated as passable via passthrough override")
    assert_equal(x25_descent.effective_walkable, true, "(25,11) should expose the x=25 Sun Shrine descent")
    assert_equal(x25_descent.reason, "passthrough", "(25,11) should record passthrough as its walkability source")

    assert_equal(lower_gap.base_walkable, true, "(14,14) should be treated as passable via passthrough override")
    assert_equal(lower_gap.effective_walkable, true, "(14,14) should be pathable after direct crawler/verifier proof")
    assert_equal(lower_gap.reason, "passthrough", "(14,14) should record passthrough as its walkability source")

    env.restore()
end

function tests.tantegel_castle_damage_tiles_are_modeled_as_hazards()
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

    local expected_hazards = {
        {x = 9, y = 18},
        {x = 10, y = 18},
        {x = 11, y = 18},
        {x = 23, y = 18},
        {x = 23, y = 19},
        {x = 23, y = 20},
        {x = 23, y = 21},
        {x = 25, y = 18},
        {x = 26, y = 18},
        {x = 26, y = 19},
    }
    for _, cell in ipairs(expected_hazards) do
        local label = string.format("(%d,%d)", cell.x, cell.y)
        assert_equal(env.map_reader.is_hazard_cell(0x04, cell.x, cell.y), "damage", label .. " should be tracked as a damage hazard")
        local cell_details = env.map_reader.get_walkability_details(0x04, cell.x, cell.y)
        assert_equal(cell_details.hazard, "damage", label .. " should report the hazard type")
        assert_equal(cell_details.effective_walkable, false, label .. " should be forbidden for pathfinding")
        assert_equal(cell_details.reason, "hazard", label .. " should report hazard rather than wall/permanent_blocked")
        assert_equal(env.map_reader.is_walkable(0x04, cell.x, cell.y), false, label .. " should not be pathfinder-walkable")
    end

    local details = env.map_reader.get_walkability_details(0x04, 10, 18)
    assert_equal(details.base_walkable, true, "(10,18) should remain engine-walkable in the base model")

    local snapshot = env.map_reader.get_walkability_snapshot(0x04)
    assert_equal(snapshot[18][10], false, "walkability snapshot should exclude the death tile")
    assert_equal(snapshot[18][9], false, "walkability snapshot should exclude the west damage tile")
    assert_equal(snapshot[18][11], false, "walkability snapshot should exclude the east damage tile")
    assert_equal(snapshot[19][11], true, "walkability snapshot should keep the south-east cell open after the live non-hazard repro")
    assert_equal(snapshot[18][23], false, "walkability snapshot should exclude the west-lane north damage tile")
    assert_equal(snapshot[19][23], false, "walkability snapshot should exclude the west-lane damage tile")
    assert_equal(snapshot[20][23], false, "walkability snapshot should exclude the west-lane south damage tile")
    assert_equal(snapshot[21][23], false, "walkability snapshot should exclude the west-lane terminal damage tile")
    assert_equal(snapshot[18][25], false, "walkability snapshot should exclude the lower-route west damage tile")
    assert_equal(snapshot[18][26], false, "walkability snapshot should exclude the lower-route east damage tile")
    assert_equal(snapshot[19][26], false, "walkability snapshot should exclude the lower-route north-south damage tile")
    assert_equal(snapshot[20][26], true, "walkability snapshot should keep the lower-route south cell open after the live non-hazard repro")

    local expected_non_hazards = {
        {x = 11, y = 19},
        {x = 25, y = 16},
        {x = 25, y = 17},
        {x = 26, y = 20},
    }
    for _, cell in ipairs(expected_non_hazards) do
        local label = string.format("(%d,%d)", cell.x, cell.y)
        assert_equal(env.map_reader.is_hazard_cell(0x04, cell.x, cell.y), false, label .. " should not be modeled as a hazard")
        local cell_details = env.map_reader.get_walkability_details(0x04, cell.x, cell.y)
        assert_equal(cell_details.hazard, false, label .. " should report no hazard in walkability details")
    end

    local hazard_snapshot = env.map_reader.get_walkability_snapshot(0x04, {allow_hazards = true})
    assert_equal(hazard_snapshot[18][10], true, "hazard-aware snapshot should allow the central damage tile")
    assert_equal(hazard_snapshot[18][9], true, "hazard-aware snapshot should allow the west damage tile")
    assert_equal(hazard_snapshot[18][11], true, "hazard-aware snapshot should allow the east damage tile")
    assert_equal(hazard_snapshot[19][11], true, "hazard-aware snapshot should allow the south-east cell")
    assert_equal(hazard_snapshot[18][23], true, "hazard-aware snapshot should allow the west-lane north damage tile")
    assert_equal(hazard_snapshot[19][23], true, "hazard-aware snapshot should allow the west-lane damage tile")
    assert_equal(hazard_snapshot[20][23], true, "hazard-aware snapshot should allow the west-lane south damage tile")
    assert_equal(hazard_snapshot[21][23], true, "hazard-aware snapshot should allow the west-lane terminal damage tile")
    assert_equal(hazard_snapshot[18][25], true, "hazard-aware snapshot should allow the lower-route west damage tile")
    assert_equal(hazard_snapshot[18][26], true, "hazard-aware snapshot should allow the lower-route east damage tile")
    assert_equal(hazard_snapshot[19][26], true, "hazard-aware snapshot should allow the lower-route north-south damage tile")
    assert_equal(hazard_snapshot[20][26], true, "hazard-aware snapshot should still allow the lower-route south cell")

    env.restore()
end

function tests.tantegel_castle_west_wing_boundary_cell_is_confirmed_open()
    local env = make_env()

    assert_equal(
        env.map_reader.is_permanently_blocked_override(0x04, 6, 9),
        true,
        "(6,9) should be a permanent block after the direct two-sided live retest"
    )
    assert_equal(
        env.map_reader.is_permanently_blocked_override(0x04, 28, 11),
        false,
        "(28,11) should remain walkable in the permanent model (south step from 28,10 can enter it)"
    )
    assert_equal(
        env.map_reader.is_permanently_blocked_override(0x04, 28, 10),
        false,
        "(28,10) should remain unblocked in the permanent map model"
    )

    local dirs = env.map_reader.get_directional_blocks(0x04)
    assert_equal(dirs["6,9"], nil, "(6,9) should no longer remain directional-only")
    assert_equal(dirs["28,11"], nil, "(28,11) should not be directional-only when fully walkable")
    assert_equal(dirs["28,10"], nil, "(28,10) should stay fully open and not have one-way approach blockers")

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
    assert_equal(dirs["21,20"].east, true, "(21,20) should block east approach after the Sage-route verifier from (22,20)")
    assert_equal(dirs["20,20"], nil, "(20,20) should not keep stale directional approach blocks after passable reverse probes")
    assert_equal(dirs["12,16"].east, true, "(12,16) should block east approach after repeated live repros from (13,16)")
    assert_equal(dirs["12,16"].north, true, "(12,16) should keep its north-side blocker")
    assert_equal(dirs["6,13"].east, true, "(6,13) should block east approach after repeated direct seam repros from (7,13)")
    assert_equal(dirs["6,13"].west, true, "(6,13) should block west approach after fresh post-reload direct seam repros from (5,13)")
    for _, y in ipairs({11, 12, 14, 15}) do
        assert_equal(
            env.map_reader.is_permanently_blocked_override(0x04, 4, y),
            true,
            "(4," .. y .. ") should stay a full blocked cell after the 2026-05-22 Tantegel strip recheck"
        )
        assert_equal(
            dirs["4," .. y],
            nil,
            "(4," .. y .. ") should not keep redundant directional shadows over the full blocked cell"
        )
    end
    assert_equal(env.map_reader.is_permanently_blocked_override(0x04, 4, 13), false, "(4,13) is the live-confirmed west door, not a full blocked cell")
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
    assert_equal(dirs["18,6"], nil, "(18,6) is now the live-confirmed magic-key door, not a directional blocker")
    assert_equal(dirs["19,6"].north, true, "(19,6) north approach should block after raw DOWN,90 stayed at (19,5)")
    assert_equal(dirs["20,6"].north, true, "(20,6) north approach should block after post-reload raw DOWN,90 stayed at (20,5)")
    assert_equal(dirs["20,6"].south, true, "(20,6) south approach should block after key-merchant route verifier from (20,7)")
    assert_equal(dirs["21,6"].south, true, "(21,6) south approach should block after key-merchant route verifier from (21,7)")
    assert_equal(dirs["22,6"].south, true, "(22,6) south approach should block after key-merchant route verifier from (22,7)")
    assert_equal(dirs["23,6"].south, true, "(23,6) south approach should block after key-merchant route verifier from (23,7)")
    assert_equal(dirs["19,6"].west, nil, "(19,6) west approach should stay open after repeat verifier from (18,6) moved 5/5")
    assert_equal(dirs["19,6"].south, nil, "(19,6) south approach should stay open after repeat verifier from (19,7) moved 5/5")
    assert_equal(dirs["21,4"].west, true, "(21,4) west approach should block after post-reload raw RIGHT,90 stayed at (20,4)")
    assert_equal(dirs["21,5"].west, true, "(21,5) west approach should block after post-reload raw RIGHT,90 stayed at (20,5)")
    env.restore()
end

function tests.tantegel_castle_key_merchant_counter_blocks_are_modeled()
    local env = make_env()
    local dirs = env.map_reader.get_directional_blocks(0x04)
    assert_equal(dirs["24,2"].south, true, "(24,2) south approach should block after key-merchant counter verifier from (24,3)")
    assert_equal(dirs["25,2"].south, true, "(25,2) south approach should block after key-merchant counter verifier from (25,3)")
    assert_equal(dirs["24,3"], nil, "(24,3) should stay open; entrance-to-merchant route reached the stand from (23,3)")
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
    assert_tantegel_dir(env, "26,28", "east", "(26,28) should block east approach after Sun Shrine pocket verifier from (27,28)")
    assert_tantegel_dir(env, "27,27", "south", "(27,27) should block south approach after Sun Shrine pocket verifier from (27,28)")
    assert_tantegel_dir(env, "27,29", "north", "(27,29) should block north approach after Sun Shrine pocket verifier from (27,28)")
    assert_tantegel_dir(env, "28,28", "west", "(28,28) should block west approach after Sun Shrine pocket verifier from (27,28)")
    assert_tantegel_dir(env, "24,22", "north", "(24,22) should block north approach after fixed-verifier Sun Shrine route retest from (24,21)")
    assert_tantegel_dir(env, "26,22", "north", "(26,22) north approach should block after clean 2026-05-24 verifier from (26,21)")
    local row22_bridge = env.map_reader.get_walkability_details(0x04, 21, 22)
    assert_equal(row22_bridge.permanent_blocked, false, "(21,22) should not remain permanently blocked after 2026-05-24 cold row-22 movement from (23,22) reached and returned through it")
    assert_tantegel_dir(env, "27,21", "west", "(27,21) west approach should block after reloaded 2026-05-24 retests from (26,21) and long raw holds from (25,21)")
    assert_tantegel_dir(env, "29,3", "west", "(29,3) should guard the upper-right world-map transition from ordinary Sun Shrine routing")
    assert_tantegel_dir(env, "29,9", "west", "(29,9) should guard the upper-right world-map transition from ordinary Sun Shrine routing")
    assert_tantegel_dir(env, "29,10", "west", "(29,10) should guard the upper-right world-map transition from ordinary Sun Shrine routing")
    assert_tantegel_dir(env, "29,20", "west", "(29,20) should block west approach after 2026-05-24 east-edge retest showed (28,20)->RIGHT exits to the World Map")
    assert_equal(dirs["29,21"] and dirs["29,21"].west or nil, nil, "(29,21) west approach should stay open after 2026-05-24 retest moved from (28,21) into the x=29 lane")
    assert_equal(dirs["29,22"] and dirs["29,22"].west or nil, nil, "(29,22) west approach should stay open after repeated 2026-05-24 retests moved from (28,22) into the x=29 lane")
    assert_tantegel_dir(env, "29,23", "west", "(29,23) should block west approach after 2026-05-24 east-edge retest showed (28,23)->RIGHT exits to the World Map")
    assert_tantegel_dir(env, "28,29", "east", "(28,29) should block east approach after Sun Shrine stair-tile LEFT verifier from (29,29)")
    assert_equal(dirs["29,28"] and dirs["29,28"].south or nil, nil, "(29,28)->DOWN should remain open after live proof that it reaches the southeast world-map exit")
    assert_equal(dirs["29,29"] and dirs["29,29"].north or nil, nil, "(29,29) north approach should remain open after live southeast exit proof")
    assert_tantegel_dir(env, "29,29", "west", "(29,29) should block west approach after adjacent-entry verifier from (28,29)")
    env.restore()
end

function tests.tantegel_castle_south_gate_exit_tile_is_passthrough()
    local base = 0x04 * 5
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

    local exit_tile = env.map_reader.get_walkability_details(0x04, 11, 29)
    assert_equal(exit_tile.base_walkable, true, "(11,29) should be standable after live south-gate proof")
    assert_equal(exit_tile.reason, "passthrough", "(11,29) should override its decoded tile-0 wall")

    local snapshot = env.map_reader.get_walkability_snapshot(0x04)
    assert_equal(snapshot[29][11], true, "walkability snapshot should include the Tantegel south gate exit tile")

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
    assert_tantegel_dir(env, "15,7", "east", "(15,7) east approach should block after key-merchant route verifier from (16,7)")
    assert_tantegel_dir(env, "15,7", "west", "(15,7) west approach should stay blocked after route-shaped Sun Shrine stalls from (14,7)")
    assert_tantegel_dir(env, "15,8", "east", "(15,8) east approach should block after key-merchant route verifier from (16,8)")
    assert_tantegel_dir(env, "16,9", "north", "(16,9) north approach should block after key-merchant return verifier from (16,8)")
    assert_tantegel_dir(env, "14,5", "north", "(14,5) should block north approach after Sun Shrine route shakedown from (14,4)")
    assert_tantegel_dir(env, "14,5", "south", "(14,5) should block south approach after reloaded route stall from (14,6)")
    assert_tantegel_dir(env, "15,5", "north", "(15,5) should block north approach after Sun Shrine route shakedown from (15,4)")
    assert_equal(dirs["13,9"].west, nil, "(13,9) west approach should stay default-open; restored-state gate blocks are handled route-locally")
    assert_tantegel_dir(env, "13,9", "north", "(13,9) north approach stays closed after mixed north-entry evidence")
    assert_tantegel_dir(env, "13,9", "south", "(13,9) south approach should block after stable south-entry verifier from (13,10)")
    assert_tantegel_dir(env, "14,9", "north", "(14,9) north approach should block after fixed-verifier retest from (14,8)")
    assert_equal(dirs["14,9"].west, nil, "(14,9) west approach should stay open after manual 13,9 east bridge proof")
    assert_tantegel_dir(env, "14,9", "south", "(14,9) south approach should remain blocked")
    assert_tantegel_dir(env, "17,9", "north", "(17,9) should block north approach after entrance-to-Sun-Shrine route verifier from (17,8)")
    assert_tantegel_dir(env, "18,9", "north", "(18,9) should block north approach after entrance-to-Sun-Shrine route verifier from (18,8)")
    assert_tantegel_dir(env, "19,9", "north", "(19,9) should block north approach after entrance-to-Sun-Shrine route verifier from (19,8)")
    assert_tantegel_dir(env, "20,9", "north", "(20,9) should block north approach after Sun Shrine route shakedown from (20,8)")
    assert_tantegel_dir(env, "21,9", "north", "(21,9) should block north approach after Sun Shrine route shakedown from (21,8)")
    assert_tantegel_dir(env, "22,9", "north", "(22,9) should block north approach after top-right Sun Shrine route verifier from (22,8)")
    assert_tantegel_dir(env, "27,9", "west", "(27,9) should block west approach after direct probe_edge_verify:26,9,RIGHT,5")
    assert_tantegel_dir(env, "27,10", "west", "(27,10) should block west approach after direct probe_edge_verify:26,10,RIGHT,5")
    assert_equal(dirs["26,9"] and dirs["26,9"].east, nil, "(26,9) should remain open from east after seam confirmation")
    assert_equal(dirs["26,10"] and dirs["26,10"].west, nil, "(26,10) should remain open from west after one-way seam confirmation")

    for _, cell in ipairs({"14,5", "15,5", "17,9", "18,9", "19,9", "20,9"}) do
        assert_not_brecconary_dir(env, cell, "recent Tantegel Sun Shrine route blocker should not be present on Brecconary")
    end
    assert_not_brecconary_dir(env, "26,10", "new one-way crown-edge blocker should stay on Tantegel")

    env.restore()
end

function tests.tantegel_castle_upper_chamber_row_16_updates_are_modeled()
    local base = 0x04 * 5
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

    local lower_bridge = env.map_reader.get_walkability_details(0x04, 19, 21)
    assert_equal(
        lower_bridge.permanent_blocked,
        false,
        "(19,21) should not be a full-cell blocker after 2026-05-23 crawl/probe evidence"
    )
    local west_entry = env.map_reader.get_walkability_details(0x04, 19, 16)
    assert_equal(
        west_entry.permanent_blocked,
        false,
        "(19,16) should no longer be marked permanently blocked"
    )
    local lower_west_shelf = env.map_reader.get_walkability_details(0x04, 22, 22)
    assert_equal(
        lower_west_shelf.permanent_blocked,
        false,
        "(22,22) should not remain a full-cell blocker after live entry from (23,22)"
    )

    local dirs = env.map_reader.get_directional_blocks(0x04)
    assert_equal(dirs["16,16"].east, nil, "(16,16) should stay open from east after later direct west-step repros")
    assert_equal(dirs["16,16"].north, true, "(16,16) should block the north approach after restored key-merchant route verifier from (16,15)")
    assert_equal(dirs["16,16"].south, true, "(16,16) should block the south approach: survey runtime block moving up from (16,17) on 2026-04-13")
    assert_equal(dirs["15,16"].west, true, "(15,16) west approach should block after 2026-05-23 throne-room-to-Sun-Shrine verifier from (14,16)")
    assert_equal(dirs["17,16"].south, true, "(17,16) should block the south approach after the 2026-04-13 repro")
    assert_equal(dirs["17,16"].north, true, "(17,16) should block the north approach after restored key-merchant route verifier from (17,15)")
    assert_equal(dirs["17,16"].east, nil, "(17,16) should stay open from east after the direct west-step repro")
    assert_equal(dirs["18,16"].south, true, "(18,16) should block the south approach after the 2026-04-13 repro")
    assert_equal(dirs["18,16"].north, nil, "(18,16) should stay open from north after the direct down-step repro")
    assert_equal(dirs["19,16"].south, true, "(19,16) should block the south approach after the restored one-way y=16 evidence")
    assert_equal(dirs["19,16"].north, true, "(19,16) should block the north approach after the 2026-05-24 Sage-route verifier from (19,15)")
    assert_equal(dirs["20,16"].south, true, "(20,16) should block the south approach after the restored one-way y=16 evidence")
    assert_equal(dirs["20,16"].north, true, "(20,16) should block the north approach after the 2026-05-24 Sage-route verifier from (20,15)")
    assert_equal(dirs["19,21"] and dirs["19,21"].north or nil, nil, "(19,21) should stay open from north after probe_edge_verify from (19,20)")
    assert_equal(dirs["19,21"] and dirs["19,21"].south or nil, nil, "(19,21) should stay open from south after probe_edge from (19,22)")
    assert_equal(dirs["19,21"] and dirs["19,21"].east or nil, nil, "(19,21) should stay open from east after probe_edge from (20,21)")
    assert_equal(dirs["24,14"] and dirs["24,14"].east or nil, true, "(24,14) east approach should block after 2026-05-24 rerouted shrine verifier from (25,14)")
    assert_equal(dirs["24,15"] and dirs["24,15"].east or nil, true, "(24,15) east approach should block after 2026-05-24 verifier from (25,15)")
    assert_equal(dirs["21,14"] and dirs["21,14"].north or nil, true, "(21,14) north approach should block after 2026-05-24 rerouted shrine verifier from (21,13)")
    assert_equal(dirs["21,14"] and dirs["21,14"].east or nil, true, "(21,14) east approach should block after 2026-05-24 clean verifier from (22,14)")
    assert_equal(dirs["21,14"] and dirs["21,14"].west or nil, true, "(21,14) west approach should block after 2026-05-24 clean verifier from (20,14)")
    assert_equal(dirs["21,15"] and dirs["21,15"].east or nil, true, "(21,15) east approach should block after 2026-05-24 clean verifier from (22,15)")
    assert_equal(dirs["21,15"] and dirs["21,15"].west or nil, true, "(21,15) west approach should block after 2026-05-24 clean verifier from (20,15)")
    assert_equal(dirs["24,16"] and dirs["24,16"].east or nil, true, "(24,16) east approach should block after 2026-05-24 verifier from (25,16)")
    assert_equal(dirs["23,16"] and dirs["23,16"].south or nil, true, "(23,16) south approach should block after 2026-05-24 clean verifier from (23,17)")
    assert_equal(dirs["23,16"] and dirs["23,16"].north or nil, true, "(23,16) north approach should block after 2026-05-24 clean verifier from (23,15)")
    assert_equal(dirs["24,16"] and dirs["24,16"].south or nil, true, "(24,16) south approach should block after 2026-05-24 clean verifier from (24,17)")
    assert_equal(dirs["24,16"] and dirs["24,16"].north or nil, true, "(24,16) north approach should block after 2026-05-24 clean verifier from (24,15)")
    assert_equal(dirs["18,14"] and dirs["18,14"].east or nil, true, "(18,14) east approach should block after 2026-05-24 clean verifier from (19,14)")
    assert_equal(dirs["18,15"] and dirs["18,15"].east or nil, true, "(18,15) east approach should block after 2026-05-24 west-pocket reroute from (19,15)")
    local hidden_alcove_top = env.map_reader.get_walkability_details(0x04, 16, 13)
    assert_equal(hidden_alcove_top.base_walkable, true, "(16,13) should be modeled passable after the 2026-05-24 west-pocket hidden-alcove probes")
    assert_equal(hidden_alcove_top.reason, "passthrough", "(16,13) should be exposed as a passthrough after the 2026-05-24 west-pocket hidden-alcove probes")
    local hidden_alcove_mid = env.map_reader.get_walkability_details(0x04, 16, 14)
    assert_equal(hidden_alcove_mid.base_walkable, true, "(16,14) should be modeled passable after the 2026-05-24 west-pocket hidden-alcove probes")
    assert_equal(hidden_alcove_mid.reason, "passthrough", "(16,14) should be exposed as a passthrough after the 2026-05-24 west-pocket hidden-alcove probes")
    assert_equal(dirs["21,17"] and dirs["21,17"].east or nil, true, "(21,17) east approach should block after 2026-05-24 post-row-22 autowalk verifier from (22,17)")
    assert_equal(dirs["21,17"].west, true, "(21,17) west approach should block after post-reload fixed-verifier retest from (20,17)")
    assert_equal(dirs["22,16"] and dirs["22,16"].south or nil, true, "(22,16) south approach should block after 2026-05-24 post-row-22 autowalk verifier from (22,17)")
    assert_equal(dirs["22,16"] and dirs["22,16"].north or nil, true, "(22,16) north approach should block after 2026-05-24 clean verifier from (22,15)")
    assert_equal(dirs["24,9"].north, true, "(24,9) should block the north approach after the 2026-05-24 Sage-route verifier from (24,8)")
    assert_equal(dirs["21,23"] and dirs["21,23"].west or nil, true, "(21,23) west approach should block after the 2026-05-24 current-position row-23 probe from (20,23)")
    assert_equal(dirs["22,23"] and dirs["22,23"].west or nil, true, "(22,23) west approach should block after the 2026-05-24 east-side row-23 probe from (21,23)")
    assert_equal(dirs["23,22"] and dirs["23,22"].east or nil, true, "(23,22) east approach should block after the 2026-05-24 current-position row-22 probe from (24,22)")
    assert_equal(dirs["24,22"] and dirs["24,22"].west or nil, true, "(24,22) west approach should block after the 2026-05-24 current-position row-22 probe from (23,22)")
    assert_equal(dirs["24,22"] and dirs["24,22"].east or nil, true, "(24,22) east approach should block after the 2026-05-24 current-position row-22 probe from (25,22)")
    assert_equal(dirs["25,22"] and dirs["25,22"].west or nil, true, "(25,22) west approach should block after the 2026-05-24 current-position row-22 probe from (24,22)")
    assert_equal(dirs["25,22"] and dirs["25,22"].east or nil, true, "(25,22) east approach should block after the 2026-05-24 southeast-pocket shelf probe from (26,22)")
    assert_equal(dirs["25,22"] and dirs["25,22"].south or nil, true, "(25,22) south approach should block after the 2026-05-24 southeast-pocket shelf probe from (25,23)")
    assert_equal(dirs["26,22"] and dirs["26,22"].west or nil, true, "(26,22) west approach should block after the 2026-05-24 southeast-pocket shelf probe from (25,22)")
    assert_equal(dirs["24,23"] and dirs["24,23"].north or nil, true, "(24,23) north approach should block after the 2026-05-24 current-position row-23 probe from (24,22)")
    assert_equal(dirs["25,23"] and dirs["25,23"].north or nil, true, "(25,23) north approach should block after the 2026-05-24 southeast-pocket shelf probe from (25,22)")
    assert_tantegel_dir(env, "26,16", "south", "(26,16) south approach should block after hazard-patched Sun Shrine route verifier from (26,17)")
    assert_tantegel_dir(env, "26,16", "west", "(26,16) west approach should block after frozen-NPC Sun Shrine route verifier from (25,16)")
    assert_tantegel_dir(env, "26,15", "west", "(26,15) west approach should block after live route loop and direct verifier from (25,15)")
    assert_tantegel_dir(env, "26,15", "north", "(26,15) north approach should block after direct probe_edge_verify:26,14,DOWN,5")
    assert_tantegel_dir(env, "27,18", "west", "(27,18).west should block after repeated live hazard-pocket raw probes from (26,18)")
    assert_tantegel_dir(env, "27,19", "west", "(27,19).west should block after repeated live hazard-pocket raw probes from (26,19)")
    assert_equal(dirs["27,17"] and dirs["27,17"].east or nil, nil, "(27,17).east should stay open; reverse checks from (28,17) still move")
    assert_tantegel_dir(env, "27,17", "west", "(27,17).west should block after repeated route stalls at (26,17)->RIGHT")
    assert_tantegel_dir(env, "27,21", "north", "(27,21).north should block after repeated live southward raw probes from (27,20)")
    assert_tantegel_dir(env, "27,12", "west", "(27,12) west approach should block after hazard-patched Sun Shrine route verifier from (26,12)")
    assert_tantegel_dir(env, "27,13", "west", "(27,13) west approach should block after top-strip reload route verifier from (26,13)")
    assert_tantegel_dir(env, "27,14", "west", "(27,14) west approach should block after x=25 descent route verifier from (26,14)")
    assert_tantegel_dir(env, "27,20", "east", "(27,20) should block east approach after throne-room route shakedown from (28,20)")
    assert_tantegel_dir(env, "27,20", "south", "(27,20) south approach should block after the 2026-05-24 direct current-position probe from (27,21)")
    assert_tantegel_dir(env, "27,20", "west", "(27,20) west approach should block after later FCEUX shrine-route verifier from (26,20)")
    assert_tantegel_dir(env, "22,22", "north", "(22,22) north approach should block after 2026-05-24 west-shelf verifier from (22,21)")
    assert_tantegel_dir(env, "23,22", "north", "(23,22) north approach should block after 2026-05-24 shrine-pocket verifier from (23,21)")
    assert_tantegel_dir(env, "21,22", "west", "(21,22) west approach should block after the 2026-05-24 reloaded southeast-pocket bridge retest from (20,22)")
    assert_tantegel_dir(env, "25,22", "north", "(25,22) north approach should block after quiet pinball verifier from (25,21)")
    assert_tantegel_dir(env, "24,23", "south", "(24,23) south approach should block after the 2026-05-24 clean verifier from (24,24)")
    assert_tantegel_dir(env, "24,24", "north", "(24,24) north approach should block after the 2026-05-24 clean verifier from (24,23)")
    assert_tantegel_dir(env, "25,23", "south", "(25,23) south approach should block after the 2026-05-24 clean verifier from (25,24)")
    assert_tantegel_dir(env, "25,24", "north", "(25,24) north approach should block after the 2026-05-24 clean verifier from (25,23)")
    assert_tantegel_dir(env, "26,22", "north", "(26,22) north approach should block after clean 2026-05-24 verifier from (26,21)")
    assert_tantegel_dir(env, "26,22", "east", "(26,22) east approach should block after the 2026-05-24 clean verifier from (27,22)")
    assert_tantegel_dir(env, "26,22", "south", "(26,22) south approach should block after the 2026-05-24 clean verifier from (26,23)")
    assert_tantegel_dir(env, "26,23", "north", "(26,23) north approach should block after the 2026-05-24 clean verifier from (26,22)")
    assert_tantegel_dir(env, "26,23", "south", "(26,23) south approach should block after the 2026-05-24 clean verifier from (26,24)")
    assert_tantegel_dir(env, "26,24", "north", "(26,24) north approach should block after the 2026-05-24 clean verifier from (26,23)")
    assert_tantegel_dir(env, "27,22", "east", "(27,22) east approach should block after the 2026-05-24 post-reload verifier from (28,22)")
    assert_tantegel_dir(env, "27,22", "north", "(27,22) north approach should block after the 2026-05-24 direct current-position probe from (27,21)")
    assert_tantegel_dir(env, "27,22", "west", "(27,22) west approach should block after the 2026-05-24 clean verifier from (26,22)")
    assert_tantegel_dir(env, "27,22", "south", "(27,22) south approach should block after the 2026-05-24 clean verifier from (27,23)")
    assert_tantegel_dir(env, "27,23", "east", "(27,23) east approach should block after the 2026-05-24 clean verifier from (28,23)")
    assert_tantegel_dir(env, "27,23", "south", "(27,23) south approach should block after the 2026-05-24 clean verifier from (27,24)")
    assert_tantegel_dir(env, "27,23", "north", "(27,23) north approach should block after the 2026-05-24 clean verifier from (27,22)")
    assert_tantegel_dir(env, "26,24", "east", "(26,24) east approach should block after the 2026-05-24 clean verifier from (27,24)")
    assert_tantegel_dir(env, "27,24", "west", "(27,24) west approach should block after the 2026-05-24 clean verifier from (26,24)")
    assert_tantegel_dir(env, "27,24", "east", "(27,24) east approach should block after the 2026-05-24 clean verifier from (28,24)")
    assert_tantegel_dir(env, "27,24", "south", "(27,24) south approach should block after the 2026-05-24 clean verifier from (27,25)")
    assert_tantegel_dir(env, "27,24", "north", "(27,24) north approach should block after the 2026-05-24 clean verifier from (27,23)")
    assert_tantegel_dir(env, "28,21", "west", "(28,21) west approach should block after the 2026-05-25 restored row-21 verifier from (27,21)")
    assert_equal(dirs["28,21"] and dirs["28,21"].east or nil, nil, "(28,21) east approach should stay unmodeled because (29,21)->LEFT remains stateful")
    assert_tantegel_dir(env, "28,23", "west", "(28,23) west approach should block after the 2026-05-24 clean verifier from (27,23)")
    assert_tantegel_dir(env, "28,24", "west", "(28,24) west approach should block after the 2026-05-24 clean verifier from (27,24)")
    assert_tantegel_dir(env, "28,22", "east", "(28,22) east approach should block after the 2026-05-24 x=29 lane verifier from (29,22)")
    assert_tantegel_dir(env, "27,25", "north", "(27,25) north approach should block after the 2026-05-24 clean verifier from (27,24)")
    assert_tantegel_dir(env, "28,23", "south", "(28,23) south approach should block after the 2026-05-24 east-pocket verifier from (28,24)")
    assert_tantegel_dir(env, "28,24", "north", "(28,24) north approach should block after the 2026-05-24 east-pocket verifier from (28,23)")
    local row23_bridge = env.map_reader.get_walkability_details(0x04, 21, 23)
    assert_equal(row23_bridge.permanent_blocked, false, "(21,23) should not remain permanently blocked after 2026-05-24 live east-west probes from (20,23) and (22,23) moved through it")
    assert_equal(dirs["25,6"] and dirs["25,6"].north or nil, nil, "(25,6) north approach should stay open after 2026-05-25 verifier from (25,5) moved 6/6")
    assert_equal(dirs["25,6"] and dirs["25,6"].south or nil, nil, "(25,6) south approach should stay open after 2026-05-25 verifier from (25,7) moved 6/6")
    assert_equal(dirs["25,6"] and dirs["25,6"].west or nil, nil, "(25,6) west approach should stay open after probe_edge_verify:24,6,RIGHT,5 moved 6/6")
    assert_equal(dirs["26,6"] and dirs["26,6"].north or nil, nil, "(26,6) north approach should stay open after 2026-05-25 verifier from (26,5) moved 6/6")
    assert_equal(dirs["26,6"] and dirs["26,6"].south or nil, nil, "(26,6) south approach should stay open after 2026-05-25 verifier from (26,7) moved 6/6")
    assert_equal(dirs["27,7"] and dirs["27,7"].west or nil, nil, "(27,7) west approach should stay open after 2026-05-25 verifier from (26,7) moved 6/6")
    assert_not_brecconary_dir(env, "15,16", "recent Tantegel throne-to-shrine blocker should not be present on Brecconary")
    assert_not_brecconary_dir(env, "27,12", "recent Tantegel throne-route blocker should not be present on Brecconary")
    assert_not_brecconary_dir(env, "27,13", "recent Tantegel throne-route blocker should not be present on Brecconary")
    assert_not_brecconary_dir(env, "27,14", "recent Tantegel throne-route blocker should not be present on Brecconary")
    assert_not_brecconary_dir(env, "27,18", "recent Tantegel hazard-pocket blocker should not be present on Brecconary")
    assert_not_brecconary_dir(env, "27,19", "recent Tantegel hazard-pocket blocker should not be present on Brecconary")
    assert_not_brecconary_dir(env, "27,21", "recent Tantegel hazard-pocket blocker should not be present on Brecconary")
    assert_not_brecconary_dir(env, "27,17", "recent Tantegel throne-route blocker should not be present on Brecconary")
    assert_not_brecconary_dir(env, "27,20", "recent Tantegel throne-route blocker should not be present on Brecconary")
    assert_not_brecconary_dir(env, "25,22", "recent Tantegel throne-route blocker should not be present on Brecconary")
    assert_not_brecconary_dir(env, "28,21", "recent Tantegel row-21 blocker should not be present on Brecconary")

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

function tests.garinham_public_shop_route_edges_match_live_checks()
    local base = 9 * 5
    local rom_bytes = {
        [base] = 0x00,
        [base + 1] = 0x80,
        [base + 2] = 19,
        [base + 3] = 19,
        [base + 4] = 0,
    }
    for i = 0x10, 0x28 do
        rom_bytes[i] = 0x2F
    end

    local env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = {
            [0] = 0x10,
        },
    })

    local dirs = env.map_reader.get_directional_blocks(0x09)
    local function assert_open_approach(cell, approach, message)
        local entry = dirs[cell]
        assert_equal(entry and entry[approach] or nil, nil, message)
    end

    assert_equal(dirs["3,12"].north, true, "(3,12) should block north approach after manual check from (3,11)")
    assert_equal(dirs["4,11"].west, true, "(4,11) should block west approach after manual check from (3,11)")
    assert_equal(dirs["3,12"].west, true, "(3,12) should block west approach after probe_edge_verify from (2,12)")
    assert_equal(dirs["4,10"].west, true, "(4,10) should block west approach after probe_edge_verify from (3,10)")
    assert_equal(dirs["3,9"].south, true, "(3,9) should block south approach after probe_edge_verify from (3,10)")
    assert_equal(dirs["2,9"].south, true, "(2,9) should block south approach after probe_edge_verify from (2,10)")
    assert_equal(dirs["1,10"].east, true, "(1,10) should block east approach after probe_edge_verify from (2,10)")
    assert_equal(dirs["1,11"].east, true, "(1,11) should block east approach after probe_edge_verify from (2,11)")
    assert_equal(dirs["1,12"].east, true, "(1,12) should block east approach after probe_edge_verify from (2,12)")
    assert_equal(dirs["6,10"].east, true, "(6,10) should block east approach after entrance-to-Tool-Merchant verifier from (7,10)")
    assert_equal(dirs["6,11"].east, true, "(6,11) should block east approach after entrance-to-Tool-Merchant verifier from (7,11)")
    assert_equal(dirs["6,12"].east, true, "(6,12) should block east approach after entrance-to-Tool-Merchant verifier from (7,12)")
    assert_equal(dirs["11,16"].west, true, "(11,16) should block west approach after Weapons Merchant return verifier from (10,16)")
    assert_equal(dirs["14,14"].west, true, "(14,14) should block west approach after Weapons Merchant return verifier from (13,14)")
    assert_equal(dirs["11,15"].east, true, "(11,15) should block east approach after entrance-to-Weapons-Merchant verifier from (12,15)")
    assert_equal(dirs["11,15"].west, true, "(11,15) should block west approach after successful-route reroute verifier from (10,15)")
    assert_equal(dirs["11,16"].east, true, "(11,16) should block east approach after entrance-to-Weapons-Merchant verifier from (12,16)")
    assert_equal(dirs["12,16"].north, true, "(12,16) should block north approach after entrance-to-Weapons-Merchant verifier from (12,15)")
    assert_equal(dirs["14,14"].north, true, "(14,14) should block north approach after entrance-to-Weapons-Merchant verifier from (14,13)")
    assert_equal(dirs["14,14"].east, true, "(14,14) should block east approach after entrance-to-Weapons-Merchant verifier from (15,14)")
    assert_equal(dirs["14,15"].east, true, "(14,15) should block east approach after entrance-to-Weapons-Merchant verifier from (15,15)")
    assert_equal(dirs["14,15"].west, true, "(14,15) should block west approach after successful-route reroute verifier from (13,15)")
    assert_equal(dirs["14,16"].east, true, "(14,16) should block east approach after entrance-to-Weapons-Merchant verifier from (15,16)")
    assert_open_approach("14,17", "east", "(14,17) should stay open from east after probe_edge_verify from (15,17) moved 5/5")
    assert_open_approach("3,10", "south", "(3,10) should stay open from south; user crossed north from (3,11)")
    assert_open_approach("3,10", "west", "(3,10) should stay open from west; manual movement crossed from (2,10)")
    assert_open_approach("2,10", "east", "(2,10) should stay open from east; manual movement crossed from (3,10)")
    assert_open_approach("2,11", "east", "(2,11) should stay open from east; user crossed west from (3,11)")
    assert_open_approach("3,11", "north", "(3,11) should stay open from north after reverse movement from (3,10)")
    assert_open_approach("3,11", "west", "(3,11) should stay open from west after reverse movement from (2,11)")
    assert_equal(env.map_reader.is_walkable(0x09, 2, 13), true, "(2,13) should be a Garinham passthrough after 5/5 live moves from (2,12)")
    assert_equal(env.map_reader.is_walkable(0x09, 1, 13), false, "nearby type-2 Garinham walls should stay non-walkable without passthrough proof")

    env.restore()
end

function tests.rimuldar_exit_route_avoids_false_north_entry()
    local env = make_env()

    local dirs = env.map_reader.get_directional_blocks(0x0B)
    local function assert_open_approach(cell, approach, message)
        assert_equal(dirs[cell] and dirs[cell][approach] or nil, nil, message)
    end

    assert_equal(dirs["28,13"].south, true, "Rimuldar (28,13) should block entry from the south after exit-route repro from (28,14)")
    assert_equal(dirs["28,13"].east, true, "Rimuldar (28,13).east should block entry from the east after the 2026-05-21 exit-tile verifier from (29,13)")
    assert_equal(dirs["24,12"].south, true, "Rimuldar (24,12) should block entry from the south after key-route verifier from (24,13)")
    assert_equal(dirs["24,12"].north, true, "Rimuldar (24,12) should block entry from the north after latest return-route loop from (24,11)")
    assert_equal(dirs["23,12"].south, true, "Rimuldar (23,12) should block entry from the south after key-route verifier from (23,13)")
    assert_equal(dirs["25,11"].east, true, "Rimuldar (25,11) should block entry from the east after key-route verifier from (26,11)")
    assert_equal(dirs["25,11"].west, true, "Rimuldar (25,11) should block entry from the west after latest return-route loop from (24,11)")
    assert_equal(dirs["25,12"].east, true, "Rimuldar (25,12) should block entry from the east after latest Weapons Merchant route loop from (26,12)")
    assert_equal(dirs["25,12"].south, true, "Rimuldar (25,12) should block entry from the south after latest Weapons Merchant route loop from (25,13)")
    assert_equal(dirs["20,10"].south, true, "Rimuldar (20,10) should block entry from the south after key-route verifier from (20,11)")
    assert_equal(dirs["20,10"].west, true, "Rimuldar (20,10) should block entry from the west after key-route verifier from (19,10)")
    assert_equal(dirs["21,6"].west, true, "Rimuldar (21,6) should block entry from the west after latest Weapons Merchant route loop from (20,6)")
    assert_equal(dirs["21,7"].west, true, "Rimuldar (21,7) should block entry from the west after latest Weapons Merchant route loop from (20,7)")
    assert_equal(dirs["21,8"].west, true, "Rimuldar (21,8) should block entry from the west after latest Weapons Merchant route verifier from (20,8)")
    assert_equal(dirs["21,11"].west, true, "Rimuldar (21,11) should block entry from the west after key-route verifier from (20,11)")
    assert_equal(dirs["21,12"].south, true, "Rimuldar (21,12) should block entry from the south after key-route verifier from (21,13)")
    assert_equal(dirs["21,12"].west, true, "Rimuldar (21,12) should block entry from the west after key-route verifier from (20,12)")
    assert_equal(dirs["24,8"].south, true, "Rimuldar (24,8) should block entry from the south after key-route verifier from (24,9)")
    assert_equal(dirs["13,6"].south, true, "Rimuldar (13,6) should block entry from the south after key-route verifier from (13,7)")
    assert_equal(dirs["13,8"].east, true, "Rimuldar (13,8) should block entry from the east after forced key-route probe from (14,8)")
    assert_equal(dirs["14,6"].south, true, "Rimuldar (14,6) should block entry from the south after key-route verifier from (14,7)")
    assert_equal(dirs["14,6"].east, true, "Rimuldar (14,6) should block entry from the east after key-route verifier from (15,6)")
    assert_equal(dirs["14,6"].north, true, "Rimuldar (14,6) should block entry from the north after latest return-route loop from (14,5)")
    assert_equal(dirs["13,7"].east, true, "Rimuldar (13,7) should block entry from the east after key-route verifier from (14,7)")
    assert_equal(dirs["3,6"].north, true, "Rimuldar (3,6) should block entry from the north after the key-counter maze route hit from (3,5)")
    assert_equal(dirs["3,6"].east, true, "Rimuldar (3,6) should block entry from the east after repeated key-stand loop hits from (4,6)")
    assert_open_approach("3,6", "south", "Rimuldar (3,6).south must stay open for the (3,8)->(3,7)->(3,6) Magic Key bridge")
    assert_equal(dirs["5,6"].west, true, "Rimuldar (5,6) should block entry from the west after repeated key-stand loop hits from (4,6)")
    assert_equal(dirs["5,6"].north, true, "Rimuldar (5,6) should block entry from the north after forced maze probe from (5,5)")
    assert_equal(dirs["5,6"].south, true, "Rimuldar (5,6) should block entry from the south after repeated trap-pocket hits from (5,7)")
    assert_equal(dirs["4,7"].east, true, "Rimuldar (4,7) should block entry from the east after repeated trap-pocket hits from (5,7)")
    assert_equal(dirs["6,7"].west, true, "Rimuldar (6,7) should block entry from the west after repeated trap-pocket hits from (5,7)")
    assert_equal(dirs["5,8"].north, true, "Rimuldar (5,8) should block entry from the north after repeated trap-pocket hits from (5,7)")
    assert_equal(dirs["5,8"].west, true, "Rimuldar (5,8) should block entry from the west after focused verifier from (4,8)")
    assert_equal(dirs["6,3"].east, true, "Rimuldar (6,3) should block entry from the east after repeated reloaded return-route hits from (7,3)")
    assert_equal(dirs["6,4"].east, true, "Rimuldar (6,4) should block entry from the east after key-route verifier from (7,4)")
    assert_equal(dirs["6,4"].north, true, "Rimuldar (6,4) should block entry from the north after forced maze probe from (6,3)")
    assert_equal(dirs["6,5"].east, true, "Rimuldar (6,5) should block entry from the east after key-route verifier from (7,5)")
    assert_equal(dirs["6,5"].north, true, "Rimuldar (6,5) should block entry from the north after verifier from (6,4)")
    assert_equal(dirs["6,5"].west, true, "Rimuldar (6,5) should block entry from the west after forced maze probe from (5,5)")
    assert_equal(dirs["6,6"].east, true, "Rimuldar (6,6) should block entry from the east after key-route verifier from (7,6)")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0B, 6, 6), false, "Rimuldar (6,6) should not be modeled as a full-cell blocker")
    assert_open_approach("6,6", "north", "Rimuldar (6,6).north moved/mixed and should stay open")
    assert_open_approach("6,6", "south", "Rimuldar (6,6).south should stay open; only the east approach is confirmed blocked")
    assert_open_approach("6,6", "west", "Rimuldar (6,6).west moved repeatedly and should stay open")
    assert_equal(dirs["2,6"].west, true, "Rimuldar (2,6) should block entry from the west after key-route verifier from (1,6)")
    assert_equal(dirs["17,6"].east, true, "Rimuldar (17,6) should block entry from the east after key-route verifier from (18,6)")
    assert_equal(dirs["17,7"].east, true, "Rimuldar (17,7) should block entry from the east after key-route verifier from (18,7)")
    assert_equal(dirs["22,12"].south, true, "Rimuldar (22,12) should block entry from the south after repeated entrance-route loop hits from (22,13)")
    assert_equal(dirs["9,12"].east, true, "Rimuldar (9,12) should block entry from the east after repeated entrance-route loop hits from (10,12)")
    assert_equal(dirs["8,14"].east, true, "Rimuldar (8,14) should block entry from the east after repeated entrance-route loop hits from (9,14)")
    assert_equal(dirs["3,12"].north, true, "Rimuldar (3,12) should block entry from the north after repeated return-route loop hits from (3,11)")
    assert_equal(dirs["4,11"].north, true, "Rimuldar (4,11) should block entry from the north after return-route loop from (4,10)")
    assert_equal(dirs["4,11"].west, true, "Rimuldar (4,11) should block entry from the west after repeated return-route loop hits from (3,11)")
    assert_equal(dirs["5,11"].north, true, "Rimuldar (5,11) should block entry from the north after return-route loop from (5,10)")
    assert_equal(dirs["6,11"].north, true, "Rimuldar (6,11) should block entry from the north after return-route loop from (6,10)")
    assert_equal(dirs["7,10"].west, true, "Rimuldar (7,10) should block entry from the west after return-route loop from (6,10)")
    assert_equal(dirs["7,10"].north, true, "Rimuldar (7,10) should block entry from the north after repeated lower-lane return loops from (7,9)")
    assert_equal(dirs["7,11"].south, true, "Rimuldar (7,11) should block entry from the south after latest entrance-route loop from (7,12)")
    assert_equal(dirs["7,15"].south, true, "Rimuldar (7,15) should block entry from the south after repeated entrance-route loops from (7,16)")
    assert_equal(dirs["6,16"].east, true, "Rimuldar (6,16) should block entry from the east after repeated entrance-route loops from (7,16)")
    assert_equal(dirs["6,16"].south, true, "Rimuldar (6,16) should block entry from the south after repeated reloaded entrance-route loops from (6,17)")
    assert_equal(dirs["15,17"].west, true, "Rimuldar (15,17) should block west approach after FCEUX verifier from (14,17)")
    assert_equal(dirs["7,14"].west, true, "Rimuldar (7,14) should block entry from the west after latest entrance-route loop from (6,14)")
    assert_equal(dirs["7,14"].north, true, "Rimuldar (7,14) should block entry from the north after latest key-route loop from (7,13)")
    assert_equal(dirs["6,15"].north, true, "Rimuldar (6,15) should block entry from the north after latest entrance-route loop from (6,14)")
    assert_equal(dirs["5,16"].south, true, "Rimuldar (5,16) should block entry from the south after repeated reloaded entrance-route loops from (5,17)")
    assert_equal(dirs["5,16"].north, true, "Rimuldar (5,16) should block entry from the north after reload autowalk stopped at (5,15)")
    assert_equal(dirs["4,16"].south, true, "Rimuldar (4,16) should block entry from the south after latest entrance-route loop from (4,17)")
    assert_equal(dirs["3,16"].south, true, "Rimuldar (3,16) should block entry from the south after latest entrance-route loop from (3,17)")
    assert_equal(dirs["3,16"].west, true, "Rimuldar (3,16) should block entry from the west after latest entrance-route loop from (2,16)")
    assert_equal(dirs["2,15"].south, true, "Rimuldar (2,15) should block entry from the south after latest entrance-route loop from (2,16)")
    assert_equal(dirs["2,15"].west, true, "Rimuldar (2,15) should block entry from the west after latest entrance-route loop from (1,15)")
    assert_equal(dirs["3,13"].south, true, "Rimuldar (3,13) should block entry from the south after repeated key-route loops from (3,14)")
    assert_equal(dirs["3,13"].east, true, "Rimuldar (3,13) should block entry from the east after latest recovery route loop from (4,13)")
    assert_equal(dirs["3,15"].north, true, "Rimuldar (3,15) should block entry from the north after repeated key-route loops from (3,14)")
    assert_equal(dirs["3,15"].east, true, "Rimuldar (3,15) should block entry from the east after manual projection loop from (4,15)")
    assert_equal(dirs["3,15"].west, true, "Rimuldar (3,15) should block entry from the west after latest entrance-route loop from (2,15)")
    assert_equal(dirs["4,12"].south, true, "Rimuldar (4,12) should block entry from the south after latest recovery route loop from (4,13)")
    assert_equal(dirs["4,12"].east, true, "Rimuldar (4,12) should block entry from the east after latest entrance-route loop from (5,12)")
    assert_equal(dirs["5,11"].south, true, "Rimuldar (5,11) should block entry from the south after latest entrance-route loop from (5,12)")
    assert_equal(dirs["4,8"].south, true, "Rimuldar (4,8) should block entry from the south after latest key-route loop from (4,9)")
    assert_equal(dirs["4,3"].south, true, "Rimuldar (4,3) should block entry from the south after latest northwest-exit route loop from (4,4)")
    assert_equal(dirs["4,4"].south, true, "Rimuldar (4,4) should block entry from the south after latest northwest-exit route loop from (4,5)")
    assert_open_approach("4,6", "north", "Rimuldar (4,6).north must stay open so the key-merchant public stand is reachable from (4,5)")
    assert_equal(dirs["4,2"].south, true, "Rimuldar (4,2) should block entry from the south because (4,3)->UP is a world-map transition")
    assert_equal(dirs["5,2"].south, true, "Rimuldar (5,2) should block entry from the south after latest return-route loop from (5,3)")
    assert_equal(dirs["6,8"].south, true, "Rimuldar (6,8) should block entry from the south after latest key-route loop from (6,9)")
    assert_equal(dirs["6,11"].south, true, "Rimuldar (6,11) should block entry from the south after latest entrance-route loop from (6,12)")
    assert_equal(dirs["6,15"].west, true, "Rimuldar (6,15) should block entry from the west after direct verifier from (5,15)")
    assert_equal(dirs["4,16"].north, true, "Rimuldar (4,16) should block entry from the north after repeated manual projection loops from (4,15)")
    assert_equal(dirs["8,10"].east, true, "Rimuldar (8,10) should block entry from the east after repeated entrance-route loops from (9,10)")
    assert_equal(dirs["8,10"].north, true, "Rimuldar (8,10) should block entry from the north after repeated lower-lane return loops from (8,9)")
    assert_open_approach("9,9", "south", "Rimuldar (9,9).south moved 5/5 from (9,10) and must stay open")
    assert_equal(dirs["8,12"].west, true, "Rimuldar (8,12) should block entry from the west after latest entrance-route loop from (7,12)")
    assert_equal(dirs["9,11"].north, true, "Rimuldar (9,11) should block entry from the north after repeated entrance-route loops from (9,10)")
    assert_equal(dirs["9,12"].south, true, "Rimuldar (9,12) should block entry from the south after repeated route loops from (9,13)")
    assert_equal(dirs["8,13"].east, true, "Rimuldar (8,13) should block entry from the east after repeated route loops from (9,13)")
    assert_equal(dirs["8,13"].west, true, "Rimuldar (8,13) should block entry from the west after latest key-route loop from (7,13)")
    assert_equal(dirs["9,6"].west, true, "Rimuldar (9,6) should block entry from the west after return-route loop from (8,6)")
    assert_equal(dirs["9,6"].north, true, "Rimuldar (9,6) should block entry from the north after return-route loop from (9,5)")
    assert_equal(dirs["10,6"].north, true, "Rimuldar (10,6) should block entry from the north after return-route verifier from (10,5)")
    assert_equal(dirs["10,6"].east, true, "Rimuldar (10,6) should block entry from the east after repeated return-route loops from (11,6)")
    assert_equal(dirs["12,6"].south, true, "Rimuldar (12,6) should block entry from the south after repeated verifier proof from (12,7)")
    assert_equal(dirs["12,6"].west, true, "Rimuldar (12,6) should block entry from the west after return-route loop from (11,6)")
    assert_equal(dirs["12,6"].north, true, "Rimuldar (12,6) should block entry from the north after return-route loop from (12,5)")
    assert_equal(dirs["13,6"].north, true, "Rimuldar (13,6) should block entry from the north after return-route loop from (13,5)")
    assert_equal(dirs["13,7"].west, true, "Rimuldar (13,7) should block entry from the west after repeated verifier proof from (12,7)")
    assert_equal(dirs["13,9"].south, true, "Rimuldar (13,9) should block entry from the south after row-10 loop verifier from (13,10)")
    assert_equal(dirs["14,9"].south, true, "Rimuldar (14,9) should block entry from the south after row-10 loop verifier from (14,10)")
    assert_equal(dirs["14,9"].east, true, "Rimuldar (14,9) should block entry from the east after row-9 verifier from (15,9)")
    assert_equal(dirs["15,9"].south, true, "Rimuldar (15,9) should block entry from the south after 7/7 verifier from (15,10)")
    assert_equal(dirs["16,9"].south, true, "Rimuldar (16,9) should block entry from the south after verifier from (16,10)")
    assert_equal(dirs["17,9"].south, true, "Rimuldar (17,9) should block entry from the south after verifier from (17,10)")
    assert_equal(dirs["17,9"].east, true, "Rimuldar (17,9) should block entry from the east after repeated entrance-route loop from (18,9)")
    assert_open_approach("18,17", "north", "Rimuldar (18,17).north should stay open after direct entrance-to-chest verifier from (18,16)")
    assert_equal(dirs["19,17"].north, true, "Rimuldar (19,17).north should block after entrance-to-chest verifier from (19,16)")
    assert_equal(dirs["20,17"].north, true, "Rimuldar (20,17).north should block after entrance-to-chest verifier from (20,16)")
    assert_equal(dirs["21,17"].north, true, "Rimuldar (21,17).north should block after entrance-to-chest verifier from (21,16)")
    assert_equal(dirs["22,17"].north, true, "Rimuldar (22,17).north should block after entrance-to-chest verifier from (22,16)")
    assert_equal(dirs["23,17"].north, true, "Rimuldar (23,17).north should block after entrance-to-chest verifier from (23,16)")
    assert_equal(dirs["24,17"].north, true, "Rimuldar (24,17).north should block after entrance-to-chest verifier from (24,16)")
    assert_equal(dirs["25,17"].north, true, "Rimuldar (25,17).north should block after entrance-to-chest verifier from (25,16)")
    assert_equal(dirs["0,5"].east, true, "Rimuldar (0,5) should block entry from the east after left-edge verifier from (1,5)")
    assert_equal(dirs["1,4"].south, true, "Rimuldar (1,4) should block entry from the south after upper-left verifier from (1,5)")
    assert_equal(dirs["2,5"].west, true, "Rimuldar (2,5) should block entry from the west after fresh route/probe proof from (1,5)")
    assert_equal(dirs["2,7"].west, true, "Rimuldar (2,7) should block entry from the west after repeated route-shaped failures from (1,7)")
    assert_equal(dirs["2,8"].south, true, "Rimuldar (2,8) should block entry from the south after direct verifier from (2,9)")
    assert_equal(dirs["23,21"].north, true, "Rimuldar (23,21).north should block after chest-return verifier from (23,20)")
    assert_equal(dirs["23,21"].south, true, "Rimuldar (23,21).south should block after return-route verifier from (23,22)")
    assert_equal(dirs["22,22"].east, true, "Rimuldar (22,22).east should block after return-route verifier from (23,22)")
    assert_equal(dirs["24,21"].south, true, "Rimuldar (24,21).south should block after return-route verifier from (24,22)")
    assert_open_approach("23,24", "north", "Rimuldar (23,24).north stayed open on direct probe despite inspect/entry mismatch")
    assert_equal(dirs["15,19"].west, true, "Rimuldar (15,19).west should block after clean verifier from (14,19); reverse from (15,19) moved")
    assert_equal(dirs["16,19"].south, true, "Rimuldar (16,19) should block entry from the south after exit-route verifier from (16,20)")
    assert_equal(dirs["16,19"].west, true, "Rimuldar (16,19).west should block entry from the west after direct seam proof from (15,19)")
    assert_equal(dirs["16,19"].east, true, "Rimuldar (16,19).east should block entry from the east after direct seam proof from (17,19)")
    assert_equal(dirs["16,21"].east, true, "Rimuldar (16,21).east should block after return-route verifier from (17,21)")
    assert_equal(dirs["16,21"].south, true, "Rimuldar (16,21).south should block after return-route verifier from (16,22)")
    assert_equal(dirs["16,21"].north, true, "Rimuldar (16,21).north should block after chest-return verifier from (16,20)")
    assert_equal(dirs["17,19"].south, true, "Rimuldar (17,19) should block entry from the south after exit-route verifier from (17,20)")
    assert_equal(dirs["22,20"].west, true, "Rimuldar (22,20) should block entry from the west after Wings route verifier from (21,20)")
    assert_equal(dirs["22,20"].east, true, "Rimuldar (22,20).east should block after chest-return verifier from (23,20)")
    assert_equal(dirs["22,21"].west, true, "Rimuldar (22,21).west should block after entrance-to-chest verifier from (21,21)")
    assert_open_approach("25,22", "west", "Rimuldar (25,22).west stayed passable in forced probe checks from (24,22)")
    assert_equal(dirs["20,26"].north, true, "Rimuldar (20,26) should block entry from the north after lower-room reroute verifier from (20,25)")
    assert_equal(dirs["21,26"].north, true, "Rimuldar (21,26) should block entry from the north after lower-room reroute verifier from (21,25)")
    assert_equal(dirs["22,26"].north, true, "Rimuldar (22,26) should block entry from the north after lower-room reroute verifier from (22,25)")
    assert_equal(dirs["23,25"].west, true, "Rimuldar (23,25) should block entry from the west after lower-room reroute verifier from (22,25)")
    assert_equal(dirs["20,21"].south, true, "Rimuldar (20,21) should block entry from the south after parked Wings survey and direct verifier from (20,22)")
    assert_equal(dirs["20,21"].north, true, "Rimuldar (20,21).north should block after chest-return verifier from (20,20)")
    assert_equal(dirs["19,21"].north, true, "Rimuldar (19,21).north should block after chest-return verifier from (19,20)")
    assert_equal(dirs["18,21"].north, true, "Rimuldar (18,21).north should block after chest-return verifier from (18,20)")
    assert_equal(dirs["18,21"].west, true, "Rimuldar (18,21).west should block after chest-return verifier from (17,21)")
    assert_equal(dirs["19,22"].east, true, "Rimuldar (19,22) should block entry from the east after parked Wings survey and direct verifier from (20,22)")
    assert_equal(dirs["19,23"].east, true, "Rimuldar (19,23) should block entry from the east after parked Wings survey and 10/10 verifier from (20,23)")
    assert_equal(dirs["20,24"].north, true, "Rimuldar (20,24) should block entry from the north after lower-room verifier from (20,23)")
    assert_equal(dirs["20,24"].south, true, "Rimuldar (20,24) should block entry from the south after lower-room side probe from (20,25)")
    assert_open_approach("22,24", "north", "Rimuldar (22,24).north is open based on forced-origin probes from (22,23)")
    assert_equal(dirs["16,24"].north, true, "Rimuldar (16,24).north should block after return-route verifier from (16,23)")
    assert_equal(dirs["16,24"].south, true, "Rimuldar (16,24) should block entry from the south after lower-strip forced probe from (16,25)")
    assert_open_approach("22,21", "south", "Rimuldar (22,21).south should be open; direct probe from (22,22) moved")
    assert_open_approach("28,17", "north", "Rimuldar (28,17).north should stay open after direct entrance-to-chest verifier from (28,16)")
    assert_equal(dirs["28,17"].east, true, "Rimuldar (28,17).east should block after entrance-to-chest verifier from (29,17)")
    assert_equal(dirs["21,24"].north, true, "Rimuldar (21,24) should block entry from the north after legitimate door-side approaches failed")
    assert_open_approach("25,23", "west", "Rimuldar (25,23).west is open after repeated forced probe checks from (24,23)")
    assert_open_approach("24,24", "north", "Rimuldar (24,24).north is open after repeated forced probe checks from (24,23)")
    assert_open_approach("21,21", "south", "Rimuldar (21,21).south is the confirmed inn outer door, not a permanent wall")
    assert_open_approach("21,21", "north", "Rimuldar (21,21).north stayed mixed and should not be promoted")
    assert_equal(dirs["15,21"].west, true, "Rimuldar (15,21).west should stay blocked after repeated direct probe failure from (14,21)")
    assert_equal(dirs["15,22"].west, true, "Rimuldar (15,22).west should stay blocked after direct probe failure from (14,22)")
    assert_equal(dirs["15,22"].east, true, "Rimuldar (15,22).east should block after return-route verifier from (16,22)")
    assert_equal(dirs["15,23"].west, true, "Rimuldar (15,23).west should block after direct return-route verifier from (14,23)")
    assert_equal(dirs["15,23"].east, true, "Rimuldar (15,23).east should block after return-route verifier from (16,23)")
    assert_equal(dirs["15,24"].west, true, "Rimuldar (15,24).west should block after direct return-route verifier from (14,24)")
    assert_open_approach("17,19", "east", "Rimuldar (17,19).east stayed mixed on direct verifier and should not be promoted")
    assert_equal(dirs["21,24"].south, true, "Rimuldar (21,24).south should block after row-25 fallback verifier from (21,25)")
    assert_equal(dirs["15,24"].south, true, "Rimuldar (15,24).south should block after row-25 fallback verifier from (15,25)")
    assert_equal(dirs["17,27"].west, true, "Rimuldar (17,27).west should block after lower fallback verifier from (16,27)")
    assert_equal(dirs["16,28"].north, true, "Rimuldar (16,28).north should block after lower fallback verifier from (16,27)")
    assert_equal(dirs["15,28"].north, true, "Rimuldar (15,28).north should block after lower fallback verifier from (15,27)")
    assert_equal(dirs["12,21"].east, true, "Rimuldar (12,21).east should block after lower-west verifier from (13,21)")
    assert_equal(dirs["12,22"].east, true, "Rimuldar (12,22).east should block after lower-west verifier from (13,22)")
    assert_equal(dirs["12,23"].east, true, "Rimuldar (12,23).east should block after lower-west verifier from (13,23)")
    assert_equal(dirs["12,24"].east, true, "Rimuldar (12,24).east should block after lower-west verifier from (13,24)")
    assert_equal(dirs["12,26"].east, true, "Rimuldar (12,26).east should block after lower-west verifier from (13,26)")
    assert_equal(dirs["12,25"].east, true, "Rimuldar (12,25).east should block after lower-west verifier from (13,25)")
    assert_open_approach("19,25", "east", "Rimuldar (19,25).east evidence was NPC-contaminated and should not be promoted")
    assert_open_approach("2,8", "west", "Rimuldar (2,8).west moved 5/5 after clean recovery and must stay open")
    assert_open_approach("1,8", "east", "Rimuldar (1,8).east moved on forced-origin reverse probe and must stay open")
    assert_open_approach("1,23", "east", "Rimuldar (1,23).east moved from the Old Man 3 west-side seam and must stay open")
    assert_open_approach("2,23", "west", "Rimuldar (2,23).west moved from the Old Man 3 west-side seam and must stay open")
    assert_equal(dirs["3,8"].east, true, "Rimuldar (3,8) should block entry from the east after focused verifier from (4,8)")
    assert_equal(dirs["3,8"].south, true, "Rimuldar (3,8) should block entry from the south after repeated route/seam failures from (3,9)")
    assert_equal(dirs["5,8"].south, true, "Rimuldar (5,8) should block entry from the south after direct verifier from (5,9)")
    assert_equal(dirs["6,2"].east, true, "Rimuldar (6,2) should block entry from the east after top-pocket direct probe from (7,2)")
    assert_equal(dirs["6,7"].east, true, "Rimuldar (6,7) should block entry from the east after direct probe from (7,7)")
    assert_equal(dirs["6,8"].east, true, "Rimuldar (6,8) should block entry from the east after direct probe from (7,8)")
    assert_equal(dirs["17,17"].east, true, "Rimuldar (17,17) should block entry from the east after repeated south-pocket route loops from (18,17)")
    assert_equal(dirs["6,3"].west, true, "Rimuldar (6,3) should block entry from the west after latest reloaded return-route cluster from (5,3)")
    assert_equal(dirs["6,4"].west, true, "Rimuldar (6,4) should block entry from the west after latest reloaded return-route cluster from (5,4)")

    local cell_29_13 = dirs["29,13"] or {}
    assert_equal(cell_29_13.south, nil, "Rimuldar (29,13) should stay open from the south for the live-confirmed exit route")
    assert_equal(cell_29_13.east, nil, "Rimuldar (29,13) should not gain an east-side block; it is the confirmed world-map exit")
    assert_equal(dirs["29,16"].west, true, "Rimuldar (29,16) should guard the row-16 world-map transition from ordinary in-town routing")
    assert_open_approach("27,15", "west", "Rimuldar (27,15).west was noisy and should stay unmodeled")
    assert_open_approach("23,10", "south", "Rimuldar (23,10).south was passable/noisy and affected by Guard 2 clutter")
    assert_open_approach("14,8", "south", "Rimuldar (14,8) should stay open from the south after 3/3 passable verifier proof")
    assert_open_approach("5,3", "east", "Rimuldar (5,3).east moved 3/3 on direct follow-up and should stay open")
    assert_open_approach("5,3", "south", "Rimuldar (5,3).south moved repeatedly during the latest return route and should stay open")
    assert_open_approach("4,5", "south", "Rimuldar (4,5).south moved on retry during the latest return route and should stay open")
    assert_open_approach("5,5", "west", "Rimuldar (5,5).west moved on retry during the latest return route and should stay open")
    assert_open_approach("4,7", "north", "Rimuldar (4,7).north is not a terrain wall; the Magic Key seller's NPC occupancy blocks that cell during routing")
    assert_open_approach("4,9", "north", "Rimuldar (4,9).north moved from the one-way (4,8)->(4,9) return connector")
    assert_open_approach("4,10", "north", "Rimuldar (4,10).north moved from the lower key-shop lane and should stay open")
    assert_open_approach("5,10", "west", "Rimuldar (5,10).west moved repeatedly during the lower-lane return loop")
    assert_open_approach("6,10", "north", "Rimuldar (6,10).north moved during the latest key-route loop and should stay open")
    assert_open_approach("25,14", "east", "Rimuldar (25,14).east moved on retry during the latest entrance route and should stay open")
    assert_open_approach("26,14", "east", "Rimuldar (26,14).east moved on retry during the latest entrance route and should stay open")
    assert_open_approach("28,14", "east", "Rimuldar (28,14).east moved on retry during the latest entrance route and should stay open")
    assert_open_approach("29,14", "north", "Rimuldar (29,14).north moved repeatedly during the latest entrance route and should stay open")
    assert_open_approach("6,8", "north", "Rimuldar (6,8).north should stay open; only the south/east approaches have fresh blocker evidence")
    assert_open_approach("8,10", "south", "Rimuldar (8,10) should remain available from the row-11 detour")
    assert_open_approach("9,11", "south", "Rimuldar (9,11) should remain available from the row-12 detour")
    assert_open_approach("15,9", "east", "Rimuldar (15,9).east moved 3/3 from (16,9) and should stay open")
    assert_open_approach("16,9", "east", "Rimuldar (16,9).east moved 3/3 from (17,9) and should stay open")
    assert_open_approach("18,9", "south", "Rimuldar (18,9).south moved 3/3 from (18,10) and should stay open")
    assert_open_approach("4,15", "east", "Rimuldar (4,15).east moved during the manual projection loop and should stay open")
    assert_open_approach("5,15", "west", "Rimuldar (5,15).west moved repeatedly during the manual projection loop and should stay open")

    env.restore()
end

function tests.kol_entry_exit_tiles_are_passthrough_false_walls()
    local base = 7 * 5
    local env = make_env({
        rom_bytes = {
            [base] = 0x00,
            [base + 1] = 0x80,
            [base + 2] = 23,
            [base + 3] = 23,
            [base + 4] = 0,
        },
        memory_bytes = {
            [0] = 0x10,
        },
    })

    assert_equal(env.map_reader.is_walkable(0x07, 18, 23), true, "(18,23) should be walkable after live Kol pathability proof")
    assert_equal(env.map_reader.is_walkable(0x07, 19, 23), true, "(19,23) should be walkable after live Kol entry/exit proof")
    assert_equal(env.map_reader.is_walkable(0x07, 20, 23), true, "(20,23) should be walkable after live west-approach proof")
    assert_equal(env.map_reader.is_walkable(0x07, 17, 23), false, "nearby unconfirmed type-0 cells should stay non-walkable")

    local details = env.map_reader.get_walkability_details(0x07, 18, 23)
    assert_equal(details.reason, "passthrough", "(18,23) should report the passthrough override")
    details = env.map_reader.get_walkability_details(0x07, 19, 23)
    assert_equal(details.reason, "passthrough", "(19,23) should report the passthrough override")

    local snapshot = env.map_reader.get_walkability_snapshot(0x07)
    assert_equal(snapshot[23][18], true, "walkability snapshot should include the west Kol entry strip")
    assert_equal(snapshot[23][19], true, "walkability snapshot should include the Kol exit tile")
    assert_equal(snapshot[23][20], true, "walkability snapshot should include the adjacent Kol entry strip")
    assert_equal(snapshot[23][17], false, "walkability snapshot should keep unconfirmed bottom-edge cells closed")

    env.restore()
end

function tests.kol_first_survey_loop_blocks_are_directional_only()
    local env = make_env()
    local dirs = env.map_reader.get_directional_blocks(0x07)

    assert_equal(dirs["10,18"].east, true, "(10,18) should block entry from the east after the Merchant 1 autowalk bounce")
    assert_equal(dirs["10,19"].east, true, "(10,19) should block entry from the east after the Merchant 1 autowalk bounce")
    assert_equal(dirs["10,18"].west, nil, "(10,18) should remain open from unproven approaches")
    assert_equal(dirs["10,19"].west, nil, "(10,19) should remain open from unproven approaches")
    assert_equal(dirs["7,15"].east, true, "(7,15) should block entry from the east after the inner Merchant 1 loop")
    assert_equal(dirs["7,11"].east, true, "(7,11) should block entry from the east after the west NPC route loop")
    assert_equal(dirs["7,12"].east, true, "(7,12) should block entry from the east after the west NPC route loop")
    assert_equal(dirs["8,16"].north, true, "(8,16) should block entry from the north after the inner Merchant 1 loop")
    assert_equal(dirs["9,16"].north, true, "(9,16) should block entry from the north after the Merchant 1 route retry")
    assert_equal(dirs["10,16"].east, true, "(10,16) should block entry from the east after the Merchant 1 route retry")
    assert_equal(dirs["10,16"].north, true, "(10,16) should block entry from the north after the Merchant 1 route retry")
    assert_equal(dirs["11,20"].north, true, "(11,20) should block entry from the north after the Merchant 1 route retry")
    assert_equal(dirs["12,19"].west, true, "(12,19) should block entry from the west after queued-route proof")
    assert_equal(dirs["12,19"].north, true, "(12,19) should block entry from the north after the later Merchant 1 loop")
    assert_equal(dirs["13,19"].north, true, "(13,19) should block entry from the north after the later Merchant 1 loop")
    assert_equal(dirs["14,19"].north, true, "(14,19) should block entry from the north after the later Merchant 1 route retry")
    assert_equal(dirs["15,19"].north, true, "(15,19) should block entry from the north after the later Merchant 1 route retry")
    assert_equal(dirs["16,19"].east, true, "(16,19) should block entry from the east after the Merchant 1 route retry")
    assert_equal(dirs["16,19"].north, true, "(16,19) should block entry from the north after the later Merchant 1 route retry")
    assert_equal(dirs["16,20"].east, true, "(16,20) should block entry from the east after the Merchant 1 route retry")
    assert_equal(dirs["16,21"].east, true, "(16,21) should block entry from the east after the Merchant 1 route retry")
    assert_equal(dirs["16,22"] and dirs["16,22"].east, nil, "(16,22).east was disproved during Merchant 4 path testing")
    assert_equal(dirs["17,22"] and dirs["17,22"].west, nil, "(17,22).west should stay open after Merchant 4 path testing")
    assert_equal(dirs["21,3"].north, true, "(21,3) should block entry from the north after the Inn-to-exit loop")
    assert_equal(dirs["22,3"].north, true, "(22,3) should block entry from the north after the Inn-to-exit loop")
    assert_equal(dirs["21,3"].south, true, "(21,3) should block entry from the south after the return-to-Inn loop")
    assert_equal(dirs["22,3"].south, true, "(22,3) should block entry from the south after the return-to-Inn loop")
    assert_equal(dirs["23,1"].west, true, "(23,1) should block entry from the west after the second Inn-to-exit loop")
    assert_equal(dirs["23,2"].west, true, "(23,2) should block entry from the west after the second Inn-to-exit loop")
    assert_equal(dirs["23,1"].east, nil, "(23,1) should remain open from unproven approaches")
    assert_equal(dirs["23,2"].east, nil, "(23,2) should remain open from unproven approaches")
    assert_equal(dirs["10,4"].north, true, "(10,4) should block entry from the north after the third Inn-to-exit loop")
    assert_equal(dirs["11,3"].west, true, "(11,3) should block entry from the west after the third Inn-to-exit loop")
    assert_equal(dirs["10,4"].south, true, "(10,4) should block entry from the south after noisy Inn round-trip cleanup")
    assert_equal(dirs["11,3"].north, true, "(11,3) should block entry from the north after repeated Inn route reroutes")
    assert_equal(dirs["9,2"].south, true, "(9,2) should block entry from the south after noisy Inn round-trip cleanup")
    assert_equal(dirs["9,2"].east, true, "(9,2) should block entry from the east after the Old Man 4 bath-route loop")
    assert_equal(dirs["2,1"].east, true, "(2,1) should block entry from the east after the Old Man 4 route loop")
    assert_equal(dirs["2,2"].east, true, "(2,2) should block entry from the east after the Old Man 4 route loop")
    assert_equal(dirs["18,13"].east, true, "(18,13) should block entry from the east after the Weapons Merchant-to-exit loop")
    assert_equal(dirs["18,13"].north, true, "(18,13) should block entry from the north after repeated noisy Weapons Merchant return evidence")
    assert_equal(dirs["18,14"].south, true, "(18,14) should block entry from the south after the third entrance-to-Weapons-Merchant loop")
    assert_equal(dirs["18,14"].west, true, "(18,14) should block entry from the west after repeated noisy Weapons Merchant return evidence")
    assert_equal(dirs["19,14"].north, true, "(19,14) should block entry from the north after the Weapons Merchant-to-exit loop")
    assert_equal(dirs["19,14"].south, true, "(19,14) should block entry from the south after the third entrance-to-Weapons-Merchant loop")
    assert_equal(dirs["21,12"].west, true, "(21,12) should block entry from the west at the Weapons Merchant counter edge")
    assert_equal(dirs["21,19"].west, true, "(21,19) should block entry from the west after the entrance-to-Weapons-Merchant loop")
    assert_equal(dirs["21,20"].west, true, "(21,20) should block entry from the west after the entrance-to-Weapons-Merchant loop")
    assert_equal(dirs["20,14"].south, true, "(20,14) should block entry from the south after the second entrance-to-Weapons-Merchant loop")
    assert_equal(dirs["21,14"].south, true, "(21,14) should block entry from the south after the second entrance-to-Weapons-Merchant loop")
    assert_equal(dirs["22,14"].south, true, "(22,14) should block entry from the south after the fourth entrance-to-Weapons-Merchant loop")
    assert_equal(dirs["23,14"].south, true, "(23,14) should block entry from the south after the fourth entrance-to-Weapons-Merchant loop")
    assert_equal(dirs["20,4"].east, true, "(20,4) should block entry from the east after the entrance-to-Inn row-4 loop")
    assert_equal(dirs["23,3"].south, true, "(23,3) should block entry from the south after the entrance-to-Inn row-4 loop")
    assert_equal(dirs["11,4"].east, true, "(11,4) should block entry from the east after the entrance-to-Inn west loop")
    assert_equal(dirs["11,4"].south, true, "(11,4) should block entry from the south after the entrance-to-Inn west loop")
    assert_equal(dirs["18,17"].north, true, "(18,17) should block entry from the north after the fifth Weapons Merchant return loop")
    assert_equal(dirs["18,17"].south, true, "(18,17) should block entry from the south after repeated Inn return reroutes")
    assert_equal(dirs["18,17"].west, true, "(18,17) should block entry from the west after noisy Weapons Merchant return cleanup")
    assert_equal(dirs["19,17"].north, true, "(19,17) should block entry from the north after the fifth Weapons Merchant return loop")
    assert_equal(dirs["19,17"].south, true, "(19,17) should block entry from the south after repeated Inn return reroutes")
    assert_equal(dirs["20,17"].north, true, "(20,17) should block entry from the north after the fifth Weapons Merchant return loop")
    assert_equal(dirs["10,3"] and dirs["10,3"].north, nil, "(10,3).north moved on retry and should stay open")
    assert_equal(dirs["10,3"] and dirs["10,3"].west, nil, "(10,3).west moved on retry and should stay open")
    assert_equal(dirs["9,2"].west, nil, "(9,2) should stay directional-only around the bath tile")
    assert_equal(dirs["2,1"].south, nil, "(2,1) should stay directional-only near Old Man 4")
    assert_equal(dirs["2,2"].north, nil, "(2,2) should stay directional-only near Old Man 4")
    assert_equal(dirs["21,4"] and dirs["21,4"].east, nil, "(21,4).east moved repeatedly during the return-to-Inn loop and should stay open")
    assert_equal(dirs["22,4"] and dirs["22,4"].west, nil, "(22,4).west moved repeatedly during the return-to-Inn loop and should stay open")
    assert_equal(dirs["22,4"] and dirs["22,4"].east, nil, "(22,4).east moved repeatedly during the entrance-to-Inn loop and should stay open")
    assert_equal(dirs["23,4"] and dirs["23,4"].west, nil, "(23,4).west moved repeatedly during the entrance-to-Inn loop and should stay open")
    assert_equal(dirs["12,4"] and dirs["12,4"].south, nil, "(12,4).south moved repeatedly during the entrance-to-Inn west loop and should stay open")
    assert_equal(dirs["12,5"] and dirs["12,5"].north, nil, "(12,5).north moved repeatedly during the entrance-to-Inn west loop and should stay open")
    assert_equal(dirs["12,5"] and dirs["12,5"].west, nil, "(12,5).west moved repeatedly during the entrance-to-Inn west loop and should stay open")
    assert_equal(dirs["11,5"] and dirs["11,5"].east, nil, "(11,5).east moved repeatedly during the entrance-to-Inn west loop and should stay open")
    assert_equal(dirs["20,5"] and dirs["20,5"].east, nil, "(20,5).east had only low-count recovered evidence and should stay open for now")
    assert_equal(dirs["18,18"] and dirs["18,18"].east, nil, "(18,18).east moved on retry and should stay open")
    assert_equal(dirs["19,13"] and dirs["19,13"].north, nil, "(19,13).north moved on retry and should stay open")
    assert_equal(dirs["21,12"].east, nil, "(21,12) should remain open from unproven approaches")
    assert_equal(dirs["18,13"].south, nil, "(18,13) should remain open from unproven approaches")
    assert_equal(dirs["21,19"].east, nil, "(21,19) should remain open from unproven approaches")
    assert_equal(dirs["21,20"].east, nil, "(21,20) should remain open from unproven approaches")
    assert_equal(dirs["21,20"].south, nil, "(21,20).south had only a low-count recovered block and should stay open for now")
    assert_equal(dirs["18,14"].north, nil, "(18,14) should remain open from unproven approaches")
    assert_equal(dirs["18,17"].east, nil, "(18,17) should remain open from unproven approaches")
    assert_equal(dirs["19,16"] and dirs["19,16"].east, nil, "(19,16).east moved repeatedly during the fifth Weapons Merchant return loop and should stay open")
    assert_equal(dirs["20,16"] and dirs["20,16"].west, nil, "(20,16).west moved repeatedly during the fifth Weapons Merchant return loop and should stay open")
    assert_equal(dirs["19,17"].east, nil, "(19,17) should remain open from unproven approaches")
    assert_equal(dirs["20,17"].west, nil, "(20,17) should remain open from unproven approaches")
    assert_equal(dirs["18,15"] and dirs["18,15"].east, nil, "(18,15).east should remain open on Kol; the 2026-05-24 west-pocket reroute/probe follow-up was Tantegel-only")
    assert_equal(dirs["19,15"] and dirs["19,15"].west, nil, "(19,15).west moved repeatedly during the third entrance-to-Weapons-Merchant loop and should stay open")
    assert_equal(dirs["20,14"].north, nil, "(20,14) should remain open from unproven approaches")
    assert_equal(dirs["22,14"].north, nil, "(22,14) should remain open from unproven approaches")
    assert_equal(dirs["23,14"].north, nil, "(23,14) should remain open from unproven approaches")
    assert_equal(dirs["22,15"] and dirs["22,15"].east, nil, "(22,15).east moved repeatedly during the fourth entrance-to-Weapons-Merchant loop and should stay open")
    assert_equal(dirs["23,15"] and dirs["23,15"].west, nil, "(23,15).west moved repeatedly during the fourth entrance-to-Weapons-Merchant loop and should stay open")
    assert_equal(dirs["7,15"].west, nil, "(7,15) should remain open from unproven approaches")
    assert_equal(dirs["7,11"].west, nil, "(7,11) should remain open from unproven approaches")
    assert_equal(dirs["7,12"].west, nil, "(7,12) should remain open from unproven approaches")
    assert_equal(dirs["8,11"] and dirs["8,11"].south, nil, "(8,11).south moved during the west NPC route loop and should stay open")
    assert_equal(dirs["8,12"] and dirs["8,12"].north, nil, "(8,12).north moved during the west NPC route loop and should stay open")
    assert_equal(dirs["8,16"].south, nil, "(8,16) should remain open from unproven approaches")
    assert_equal(dirs["15,16"] and dirs["15,16"].west, nil, "(15,16).west had noisy moved evidence and should stay open")
    assert_equal(dirs["17,21"] and dirs["17,21"].east, nil, "(17,21).east had noisy moved evidence and should stay open")
    assert_equal(dirs["20,17"].south, true, "(20,17) should block entry from the south after the Person 1 survey loop")
    assert_equal(dirs["21,18"].west, true, "(21,18) should block entry from the west after the Person 1 survey loop")
    assert_equal(dirs["20,17"].east, nil, "(20,17) should remain open from unproven approaches")
    assert_equal(dirs["21,18"].east, nil, "(21,18) should remain open from unproven approaches")

    env.restore()
end

function tests.rain_shrine_old_man_hidden_wall_cluster_is_directional()
    local env = make_env()

    local dirs = env.map_reader.get_directional_blocks(0x0D)
    assert_equal(dirs["3,2"].north, true, "Rain Shrine (3,2) should block southward entry from (3,1)")
    assert_equal(dirs["3,2"].east, nil, "Rain Shrine (3,2) should keep unconfirmed east approach open")
    assert_equal(dirs["3,2"].south, nil, "Rain Shrine (3,2) should keep unconfirmed south approach open")
    assert_equal(dirs["3,2"].west, nil, "Rain Shrine (3,2) should keep unconfirmed west approach open")
    assert_equal(dirs["4,2"].north, true, "Rain Shrine (4,2) should block southward entry from (4,1)")
    assert_equal(dirs["4,2"].east, nil, "Rain Shrine (4,2) should keep unconfirmed east approach open")
    assert_equal(dirs["4,2"].south, nil, "Rain Shrine (4,2) should keep unconfirmed south approach open")
    assert_equal(dirs["4,2"].west, nil, "Rain Shrine (4,2) should keep unconfirmed west approach open")
    assert_equal(dirs["5,2"].north, true, "Rain Shrine (5,2) should block southward entry from (5,1)")
    assert_equal(dirs["5,2"].east, nil, "Rain Shrine (5,2) should keep unconfirmed east approach open")
    assert_equal(dirs["5,2"].south, nil, "Rain Shrine (5,2) should keep unconfirmed south approach open")
    assert_equal(dirs["5,2"].west, nil, "Rain Shrine (5,2) should keep unconfirmed west approach open")
    assert_equal(dirs["6,2"].north, true, "Rain Shrine (6,2) should block southward entry from (6,1)")
    assert_equal(dirs["6,2"].east, nil, "Rain Shrine (6,2) should keep unconfirmed east approach open")
    assert_equal(dirs["6,2"].south, nil, "Rain Shrine (6,2) should keep unconfirmed south approach open")
    assert_equal(dirs["6,2"].west, nil, "Rain Shrine (6,2) should keep unconfirmed west approach open")
    assert_equal(dirs["2,3"].west, true, "Rain Shrine (2,3) should block eastward entry from (1,3)")
    assert_equal(dirs["2,3"].north, nil, "Rain Shrine (2,3) should keep unconfirmed north approach open")
    assert_equal(dirs["2,3"].east, nil, "Rain Shrine (2,3) should keep unconfirmed east approach open")
    assert_equal(dirs["2,3"].south, nil, "Rain Shrine (2,3) should keep unconfirmed south approach open")
    assert_equal(dirs["2,4"].west, true, "Rain Shrine (2,4) should block eastward entry from (1,4)")
    assert_equal(dirs["2,4"].north, nil, "Rain Shrine (2,4) should keep unconfirmed north approach open")
    assert_equal(dirs["2,4"].east, nil, "Rain Shrine (2,4) should keep unconfirmed east approach open")
    assert_equal(dirs["2,4"].south, nil, "Rain Shrine (2,4) should keep unconfirmed south approach open")
    assert_equal(dirs["2,5"].west, true, "Rain Shrine (2,5) should block eastward entry from (1,5)")
    assert_equal(dirs["2,5"].north, nil, "Rain Shrine (2,5) should keep unconfirmed north approach open")
    assert_equal(dirs["2,5"].east, nil, "Rain Shrine (2,5) should keep unconfirmed east approach open")
    assert_equal(dirs["2,5"].south, nil, "Rain Shrine (2,5) should keep unconfirmed south approach open")
    assert_equal(dirs["2,6"].south, true, "Rain Shrine (2,6) should block northward entry from (2,7)")
    assert_equal(dirs["2,6"].north, nil, "Rain Shrine (2,6) should keep unconfirmed north approach open")
    assert_equal(dirs["2,6"].east, nil, "Rain Shrine (2,6) should keep unconfirmed east approach open")
    assert_equal(dirs["2,6"].west, true, "Rain Shrine (2,6) should block eastward entry from (1,6)")
    assert_equal(dirs["5,3"].east, true, "Rain Shrine (5,3) should block westward entry from (6,3)")
    assert_equal(dirs["5,3"].south, nil, "Rain Shrine (5,3).south was mixed/passable in raw verification and should stay open")
    assert_equal(dirs["5,3"].north, nil, "Rain Shrine (5,3) should keep unconfirmed north approach open")
    assert_equal(dirs["5,3"].west, nil, "Rain Shrine (5,3) should keep unconfirmed west approach open")
    assert_equal(dirs["3,6"].south, true, "Rain Shrine (3,6) should block northward entry from (3,7)")
    assert_equal(dirs["3,6"].north, nil, "Rain Shrine (3,6) should keep unconfirmed north approach open")
    assert_equal(dirs["3,6"].east, nil, "Rain Shrine (3,6) should keep unconfirmed east approach open")
    assert_equal(dirs["3,6"].west, nil, "Rain Shrine (3,6) should keep unconfirmed west approach open")
    assert_equal(dirs["4,6"].south, true, "Rain Shrine (4,6) should block northward entry from (4,7)")
    assert_equal(dirs["4,6"].north, nil, "Rain Shrine (4,6) should keep unconfirmed north approach open")
    assert_equal(dirs["4,6"].east, nil, "Rain Shrine (4,6) should keep unconfirmed east approach open")
    assert_equal(dirs["4,6"].west, nil, "Rain Shrine (4,6) should keep unconfirmed west approach open")
    assert_equal(dirs["5,5"].north, true, "Rain Shrine (5,5) should block southward entry from (5,4)")
    assert_equal(dirs["5,5"].east, true, "Rain Shrine (5,5) should block westward entry from (6,5)")
    assert_equal(dirs["5,5"].south, nil, "Rain Shrine (5,5) should keep unconfirmed south approach open")
    assert_equal(dirs["5,5"].west, nil, "Rain Shrine (5,5) should keep unconfirmed west approach open")
    assert_equal(dirs["5,6"].south, true, "Rain Shrine (5,6) should block northward entry from (5,7)")
    assert_equal(dirs["5,6"].north, nil, "Rain Shrine (5,6) should keep unconfirmed north approach open")
    assert_equal(dirs["5,6"].east, nil, "Rain Shrine (5,6) should keep unconfirmed east approach open")
    assert_equal(dirs["5,6"].west, nil, "Rain Shrine (5,6) should keep unconfirmed west approach open")
    assert_equal(dirs["6,6"].north, true, "Rain Shrine (6,6) should block southward entry from (6,5)")
    assert_equal(dirs["6,6"].south, true, "Rain Shrine (6,6) should block northward entry from (6,7)")
    assert_equal(dirs["6,6"].east, nil, "Rain Shrine (6,6) should keep unconfirmed east approach open")
    assert_equal(dirs["6,6"].west, nil, "Rain Shrine (6,6) should keep unconfirmed west approach open")
    assert_equal(dirs["7,6"].south, true, "Rain Shrine (7,6) should block northward entry from (7,7)")
    assert_equal(dirs["7,6"].east, true, "Rain Shrine (7,6) should block westward entry from (8,6)")
    assert_equal(dirs["7,6"].north, nil, "Rain Shrine (7,6) should keep unconfirmed north approach open")
    assert_equal(dirs["7,6"].west, nil, "Rain Shrine (7,6) should keep unconfirmed west approach open")
    assert_equal(dirs["7,5"].north, true, "Rain Shrine (7,5) should block southward entry from (7,4)")
    assert_equal(dirs["7,5"].west, true, "Rain Shrine (7,5) should block eastward entry from (6,5)")
    assert_equal(dirs["7,5"].east, true, "Rain Shrine (7,5) should block westward entry from (8,5)")
    assert_equal(dirs["7,5"].south, nil, "Rain Shrine (7,5) should keep unconfirmed south approach open")
    assert_equal(dirs["6,9"].north, true, "Rain Shrine (6,9) should block southward entry from (6,8)")
    assert_equal(dirs["6,9"].east, nil, "Rain Shrine (6,9) should keep unconfirmed east approach open")
    assert_equal(dirs["6,9"].south, nil, "Rain Shrine (6,9) should keep unconfirmed south approach open")
    assert_equal(dirs["6,9"].west, nil, "Rain Shrine (6,9) should keep unconfirmed west approach open")
    assert_equal(dirs["7,9"].north, true, "Rain Shrine (7,9) should block southward entry from (7,8)")
    assert_equal(dirs["7,9"].east, nil, "Rain Shrine (7,9) should keep unconfirmed east approach open")
    assert_equal(dirs["7,9"].south, nil, "Rain Shrine (7,9) should keep unconfirmed south approach open")
    assert_equal(dirs["7,9"].west, nil, "Rain Shrine (7,9) should keep unconfirmed west approach open")
    assert_equal(dirs["8,9"] and dirs["8,9"].north, nil, "Rain Shrine (8,9).north map-changed during raw verification and should stay open")
    assert_equal(dirs["5,1"] and dirs["5,1"].west, nil, "Rain Shrine (5,1).west moved during the manual old-man detour and should stay open")
    assert_equal(dirs["6,1"] and dirs["6,1"].west, nil, "Rain Shrine (6,1).west moved during the manual old-man detour and should stay open")
    assert_equal(dirs["7,1"] and dirs["7,1"].west, nil, "Rain Shrine (7,1).west moved during the manual old-man detour and should stay open")
    assert_equal(dirs["8,2"] and dirs["8,2"].north, nil, "Rain Shrine (8,2).north moved during the manual old-man detour and should stay open")
    assert_equal(dirs["8,4"] and dirs["8,4"].north, nil, "Rain Shrine (8,4).north moved during the manual old-man detour and should stay open")
    assert_equal(dirs["7,4"] and dirs["7,4"].east, nil, "Rain Shrine (7,4).east moved during the manual old-man detour and should stay open")
    assert_equal(dirs["7,4"] and dirs["7,4"].west, nil, "Rain Shrine (7,4).west moved during the exit reroute and should stay open")
    assert_equal(dirs["6,4"] and dirs["6,4"].east, nil, "Rain Shrine (6,4).east moved during the manual old-man detour and should stay open")
    assert_equal(dirs["6,4"] and dirs["6,4"].south, nil, "Rain Shrine (6,4).south moved during the exit reroute and should stay open")
    assert_equal(dirs["6,5"] and dirs["6,5"].north, nil, "Rain Shrine (6,5).north moved during the exit reroute and should stay open")
    assert_equal(dirs["6,7"] and dirs["6,7"].east, nil, "Rain Shrine (6,7).east moved during the old-man route and should stay open")
    assert_equal(dirs["6,7"] and dirs["6,7"].west, nil, "Rain Shrine (6,7).west moved during the old-man route and should stay open")
    assert_equal(dirs["7,7"] and dirs["7,7"].west, nil, "Rain Shrine (7,7).west moved during the old-man route and should stay open")
    assert_equal(dirs["5,4"] and dirs["5,4"].east, nil, "Rain Shrine (5,4).east moved during the manual old-man detour and should stay open")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0D, 3, 2), false, "Rain Shrine (3,2) should not be fully blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0D, 4, 2), false, "Rain Shrine (4,2) should not be fully blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0D, 5, 2), false, "Rain Shrine (5,2) should not be fully blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0D, 6, 2), false, "Rain Shrine (6,2) should not be fully blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0D, 2, 3), false, "Rain Shrine (2,3) should not be fully blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0D, 2, 4), false, "Rain Shrine (2,4) should not be fully blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0D, 2, 5), false, "Rain Shrine (2,5) should not be fully blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0D, 2, 6), false, "Rain Shrine (2,6) should not be fully blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0D, 5, 3), false, "Rain Shrine (5,3) should not be fully blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0D, 3, 6), false, "Rain Shrine (3,6) should not be fully blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0D, 4, 6), false, "Rain Shrine (4,6) should not be fully blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0D, 5, 5), false, "Rain Shrine (5,5) should not be fully blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0D, 5, 6), false, "Rain Shrine (5,6) should not be fully blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0D, 6, 6), false, "Rain Shrine (6,6) should not be fully blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0D, 7, 6), false, "Rain Shrine (7,6) should not be fully blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0D, 7, 5), false, "Rain Shrine (7,5) should not be fully blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0D, 6, 9), false, "Rain Shrine (6,9) should not be fully blocked")
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0D, 7, 9), false, "Rain Shrine (7,9) should not be fully blocked")

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

function tests.rimuldar_magic_key_route_bridge_is_passthrough()
    local base = 0x0B * 5
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

    local bridge = env.map_reader.get_walkability_details(0x0B, 24, 6)
    assert_equal(bridge.base_walkable, true, "Rimuldar (24,6) should be passable via the Magic Key shop approach bridge")
    assert_equal(bridge.effective_walkable, true, "Rimuldar (24,6) should be available to A*")
    assert_equal(bridge.reason, "passthrough", "Rimuldar (24,6) should record passthrough as its walkability source")

    local connector = env.map_reader.get_walkability_details(0x0B, 19, 9)
    assert_equal(connector.base_walkable, true, "Rimuldar (19,9) should be passable via the key-route hidden connector")
    assert_equal(connector.effective_walkable, true, "Rimuldar (19,9) should be available to A*")
    assert_equal(connector.reason, "passthrough", "Rimuldar (19,9) should record passthrough as its walkability source")

    local row8_connector = env.map_reader.get_walkability_details(0x0B, 14, 8)
    assert_equal(row8_connector.base_walkable, true, "Rimuldar (14,8) should be passable via the key-route row-8 connector")
    assert_equal(row8_connector.effective_walkable, true, "Rimuldar (14,8) should be available to A*")
    assert_equal(row8_connector.reason, "passthrough", "Rimuldar (14,8) should record passthrough as its walkability source")

    local key_column_lower = env.map_reader.get_walkability_details(0x0B, 13, 9)
    assert_equal(key_column_lower.base_walkable, true, "Rimuldar (13,9) should be passable via the key-route hidden column")
    assert_equal(key_column_lower.effective_walkable, true, "Rimuldar (13,9) should be available to A*")
    assert_equal(key_column_lower.reason, "passthrough", "Rimuldar (13,9) should record passthrough as its walkability source")

    local key_column_upper = env.map_reader.get_walkability_details(0x0B, 13, 8)
    assert_equal(key_column_upper.base_walkable, true, "Rimuldar (13,8) should be passable via the key-route hidden column")
    assert_equal(key_column_upper.effective_walkable, true, "Rimuldar (13,8) should be available to A*")
    assert_equal(key_column_upper.reason, "passthrough", "Rimuldar (13,8) should record passthrough as its walkability source")

    local row8_upper_turn = env.map_reader.get_walkability_details(0x0B, 16, 8)
    assert_equal(row8_upper_turn.base_walkable, true, "Rimuldar (16,8) should be passable via the key-route upper hidden turn")
    assert_equal(row8_upper_turn.effective_walkable, true, "Rimuldar (16,8) should be available to A*")
    assert_equal(row8_upper_turn.reason, "passthrough", "Rimuldar (16,8) should record passthrough as its walkability source")

    local northwest_strip_a = env.map_reader.get_walkability_details(0x0B, 1, 8)
    assert_equal(northwest_strip_a.base_walkable, true, "Rimuldar (1,8) should be passable via the key-shop northwest hidden strip")
    assert_equal(northwest_strip_a.effective_walkable, true, "Rimuldar (1,8) should be available to A*")
    assert_equal(northwest_strip_a.reason, "passthrough", "Rimuldar (1,8) should record passthrough as its walkability source")

    local northwest_strip_b = env.map_reader.get_walkability_details(0x0B, 1, 7)
    assert_equal(northwest_strip_b.base_walkable, true, "Rimuldar (1,7) should be passable via the key-shop northwest hidden strip")
    assert_equal(northwest_strip_b.effective_walkable, true, "Rimuldar (1,7) should be available to A*")
    assert_equal(northwest_strip_b.reason, "passthrough", "Rimuldar (1,7) should record passthrough as its walkability source")

    local northwest_connector = env.map_reader.get_walkability_details(0x0B, 2, 7)
    assert_equal(northwest_connector.base_walkable, true, "Rimuldar (2,7) should be passable via the key-shop west-strip connector")
    assert_equal(northwest_connector.effective_walkable, true, "Rimuldar (2,7) should be available to A*")
    assert_equal(northwest_connector.reason, "passthrough", "Rimuldar (2,7) should record passthrough as its walkability source")

    local northwest_bridge = env.map_reader.get_walkability_details(0x0B, 2, 8)
    assert_equal(northwest_bridge.base_walkable, true, "Rimuldar (2,8) should be passable after clean (1,8)->RIGHT verifier proof")
    assert_equal(northwest_bridge.effective_walkable, true, "Rimuldar (2,8) should be available to A*")
    assert_equal(northwest_bridge.reason, "passthrough", "Rimuldar (2,8) should record passthrough as its walkability source")

    for _, cell in ipairs({
        {"3,4", 3, 4},
        {"4,3", 4, 3},
        {"6,3", 6, 3},
        {"5,3", 5, 3},
        {"5,5", 5, 5},
        {"4,5", 4, 5},
        {"3,5", 3, 5},
    }) do
        local details = env.map_reader.get_walkability_details(0x0B, cell[2], cell[3])
        assert_equal(details.base_walkable, true, "Rimuldar (" .. cell[1] .. ") should be passable via the final key-counter maze")
        assert_equal(details.effective_walkable, true, "Rimuldar (" .. cell[1] .. ") should be available to A*")
        assert_equal(details.reason, "passthrough", "Rimuldar (" .. cell[1] .. ") should record passthrough as its walkability source")
    end

    for _, cell in ipairs({
        {"4,7", 4, 7},
        {"4,8", 4, 8},
        {"4,9", 4, 9},
    }) do
        local details = env.map_reader.get_walkability_details(0x0B, cell[2], cell[3])
        assert_equal(details.base_walkable, true, "Rimuldar (" .. cell[1] .. ") should be passable via the lower key-shop escape strip")
        assert_equal(details.effective_walkable, true, "Rimuldar (" .. cell[1] .. ") should be available to A*")
        assert_equal(details.reason, "passthrough", "Rimuldar (" .. cell[1] .. ") should record passthrough as its walkability source")
    end

    for _, cell in ipairs({
        {"5,7", 5, 7},
        {"5,9", 5, 9},
        {"6,7", 6, 7},
        {"6,8", 6, 8},
        {"6,9", 6, 9},
        {"7,9", 7, 9},
        {"8,9", 8, 9},
        {"9,9", 9, 9},
    }) do
        local details = env.map_reader.get_walkability_details(0x0B, cell[2], cell[3])
        assert_equal(details.base_walkable, true, "Rimuldar (" .. cell[1] .. ") should be passable via the lower key-shop return lane")
        assert_equal(details.effective_walkable, true, "Rimuldar (" .. cell[1] .. ") should be available to A*")
        assert_equal(details.reason, "passthrough", "Rimuldar (" .. cell[1] .. ") should record passthrough as its walkability source")
    end

    for _, cell in ipairs({
        {"1,5", 1, 5},
        {"1,12", 1, 12},
        {"1,13", 1, 13},
        {"1,14", 1, 14},
        {"2,5", 2, 5},
        {"2,14", 2, 14},
        {"3,7", 3, 7},
        {"3,8", 3, 8},
        {"3,9", 3, 9},
        {"3,14", 3, 14},
        {"4,14", 4, 14},
        {"5,14", 5, 14},
        {"8,7", 8, 7},
        {"8,8", 8, 8},
        {"14,5", 14, 5},
        {"15,5", 15, 5},
    }) do
        local details = env.map_reader.get_walkability_details(0x0B, cell[2], cell[3])
        assert_equal(details.base_walkable, true, "Rimuldar (" .. cell[1] .. ") should be passable after the latest manual false-wall route proof")
        assert_equal(details.effective_walkable, true, "Rimuldar (" .. cell[1] .. ") should be available to A*")
        assert_equal(details.reason, "passthrough", "Rimuldar (" .. cell[1] .. ") should record passthrough as its walkability source")
    end

    for _, cell in ipairs({
        {"1,23", 1, 23},
        {"2,23", 2, 23},
    }) do
        local details = env.map_reader.get_walkability_details(0x0B, cell[2], cell[3])
        assert_equal(details.base_walkable, true, "Rimuldar (" .. cell[1] .. ") should be passable via the Old Man 3 west-side seam")
        assert_equal(details.effective_walkable, true, "Rimuldar (" .. cell[1] .. ") should be available to A*")
        assert_equal(details.reason, "passthrough", "Rimuldar (" .. cell[1] .. ") should record passthrough as its walkability source")
    end

    for _, cell in ipairs({
        {"11,15", 11, 15},
        {"11,16", 11, 16},
        {"12,2", 12, 2},
        {"12,8", 12, 8},
        {"12,9", 12, 9},
        {"12,11", 12, 11},
        {"13,2", 13, 2},
        {"13,4", 13, 4},
        {"13,15", 13, 15},
        {"13,16", 13, 16},
        {"13,18", 13, 18},
        {"13,20", 13, 20},
        {"14,16", 14, 16},
        {"15,16", 15, 16},
        {"18,25", 18, 25},
        {"19,25", 19, 25},
        {"21,22", 21, 22},
        {"21,24", 21, 24},
        {"22,22", 22, 22},
        {"23,18", 23, 18},
    }) do
        local details = env.map_reader.get_walkability_details(0x0B, cell[2], cell[3])
        assert_equal(details.base_walkable, true, "Rimuldar (" .. cell[1] .. ") should be passable via the new x=11 strip, south-side false-wall connector, west-side vertical strip, or locked-room hidden strip")
        assert_equal(details.effective_walkable, true, "Rimuldar (" .. cell[1] .. ") should be available to A*")
        assert_equal(details.reason, "passthrough", "Rimuldar (" .. cell[1] .. ") should record passthrough as its walkability source")
    end

    for _, cell in ipairs({
        {"23,22", 23, 22},
        {"24,22", 24, 22},
    }) do
        local details = env.map_reader.get_walkability_details(0x0B, cell[2], cell[3])
        assert_equal(details.base_walkable, true, "Rimuldar (" .. cell[1] .. ") should be passable via the Wings room row-22 shelf")
        assert_equal(details.effective_walkable, true, "Rimuldar (" .. cell[1] .. ") should be available to A*")
        assert_equal(details.reason, "passthrough", "Rimuldar (" .. cell[1] .. ") should record passthrough as its walkability source")
    end

    for _, cell in ipairs({
        {"12,15", 12, 15},
        {"12,16", 12, 16},
        {"12,18", 12, 18},
    }) do
        local details = env.map_reader.get_walkability_details(0x0B, cell[2], cell[3])
        assert_equal(details.base_walkable, true, "Rimuldar (" .. cell[1] .. ") should be passable via the newer south x=12 false-wall strip")
        assert_equal(details.effective_walkable, true, "Rimuldar (" .. cell[1] .. ") should be available to A*")
        assert_equal(details.reason, "passthrough", "Rimuldar (" .. cell[1] .. ") should record passthrough as its walkability source")
    end

    for _, cell in ipairs({
        {"24,2", 24, 2},
        {"24,3", 24, 3},
        {"24,4", 24, 4},
        {"25,2", 25, 2},
        {"25,3", 25, 3},
        {"26,2", 26, 2},
        {"26,3", 26, 3},
        {"27,2", 27, 2},
        {"27,3", 27, 3},
        {"28,2", 28, 2},
        {"28,3", 28, 3},
        {"28,4", 28, 4},
        {"28,6", 28, 6},
        {"28,7", 28, 7},
        {"29,2", 29, 2},
        {"29,3", 29, 3},
        {"29,4", 29, 4},
        {"29,6", 29, 6},
        {"29,7", 29, 7},
        {"29,9", 29, 9},
        {"29,10", 29, 10},
        {"29,11", 29, 11},
        {"29,12", 29, 12},
    }) do
        local details = env.map_reader.get_walkability_details(0x0B, cell[2], cell[3])
        assert_equal(details.base_walkable, true, "Rimuldar (" .. cell[1] .. ") should be passable via the northeast x=24-x=29 false-wall strip")
        assert_equal(details.effective_walkable, true, "Rimuldar (" .. cell[1] .. ") should be available to A*")
        assert_equal(details.reason, "passthrough", "Rimuldar (" .. cell[1] .. ") should record passthrough as its walkability source")
    end

    local nearby_wall = env.map_reader.get_walkability_details(0x0B, 24, 8)
    assert_equal(nearby_wall.base_walkable, false, "nearby Rimuldar hidden cells outside the promoted x=24 strip should stay closed")
    local npc_connector = env.map_reader.get_walkability_details(0x0B, 15, 8)
    assert_equal(npc_connector.base_walkable, false, "Rimuldar (15,8) should stay unmodeled because Woman 3 occupies that alternate connector")

    local snapshot = env.map_reader.get_walkability_snapshot(0x0B)
    assert_equal(snapshot[15][11], true, "walkability snapshot should include the new upper x=11 false-wall strip cell")
    assert_equal(snapshot[16][11], true, "walkability snapshot should include the new lower x=11 false-wall strip cell")
    assert_equal(snapshot[15][12], true, "walkability snapshot should include the newer south x=12 false-wall strip cell")
    assert_equal(snapshot[16][12], true, "walkability snapshot should include the newer middle south x=12 false-wall strip cell")
    assert_equal(snapshot[18][12], true, "walkability snapshot should include the newer lower south x=12 false-wall strip cell")
    assert_equal(snapshot[6][24], true, "walkability snapshot should include the Magic Key shop approach bridge")
    assert_equal(snapshot[9][19], true, "walkability snapshot should include the Magic Key route hidden connector")
    assert_equal(snapshot[8][14], true, "walkability snapshot should include the clean row-8 Magic Key route connector")
    assert_equal(snapshot[9][13], true, "walkability snapshot should include the lower hidden key-route column")
    assert_equal(snapshot[8][13], true, "walkability snapshot should include the upper hidden key-route column")
    assert_equal(snapshot[8][16], true, "walkability snapshot should include the upper hidden key-route turn")
    assert_equal(snapshot[8][1], true, "walkability snapshot should include the first northwest key-shop strip cell")
    assert_equal(snapshot[7][1], true, "walkability snapshot should include the second northwest key-shop strip cell")
    assert_equal(snapshot[4][3], true, "walkability snapshot should include the northwest key-shop exit false-wall turn")
    assert_equal(snapshot[3][4], true, "walkability snapshot should include the northwest key-shop exit false-wall stand")
    assert_equal(snapshot[3][6], true, "walkability snapshot should include the final key-counter upper connector")
    assert_equal(snapshot[7][3], true, "walkability snapshot should include the real Magic Key counter bridge")
    assert_equal(snapshot[8][3], true, "walkability snapshot should include the alternate one-way key-route bridge")
    assert_equal(snapshot[3][5], true, "walkability snapshot should include the final key-counter upper turn")
    assert_equal(snapshot[5][5], true, "walkability snapshot should include the final key-counter lower turn")
    assert_equal(snapshot[5][4], true, "walkability snapshot should include the final key-counter west turn")
    assert_equal(snapshot[5][3], true, "walkability snapshot should include the final key-counter west dead-end")
    assert_equal(snapshot[7][4], true, "walkability snapshot should include the lower key-shop escape strip start")
    assert_equal(snapshot[8][4], true, "walkability snapshot should include the lower key-shop escape strip middle")
    assert_equal(snapshot[9][4], true, "walkability snapshot should include the lower key-shop escape strip exit")
    assert_equal(snapshot[7][5], true, "walkability snapshot should include the lower key-shop return lane west entry")
    assert_equal(snapshot[7][6], true, "walkability snapshot should include the lower key-shop return lane upper turn")
    assert_equal(snapshot[8][6], true, "walkability snapshot should include the lower key-shop return lane middle")
    assert_equal(snapshot[9][6], true, "walkability snapshot should include the lower key-shop return lane lower turn")
    assert_equal(snapshot[9][7], true, "walkability snapshot should include the lower key-shop return lane exit")
    assert_equal(snapshot[9][8], true, "walkability snapshot should include the lower key-shop return lane east connector")
    assert_equal(snapshot[5][1], true, "walkability snapshot should include the west upper false-wall pocket")
    assert_equal(snapshot[12][1], true, "walkability snapshot should include the west-side key-route bridge")
    assert_equal(snapshot[13][1], true, "walkability snapshot should include the west recovery false-wall pocket")
    assert_equal(snapshot[9][3], true, "walkability snapshot should include the lower west false-wall connector")
    assert_equal(snapshot[14][1], true, "walkability snapshot should include the west pocket false-wall cell")
    assert_equal(snapshot[14][2], true, "walkability snapshot should include the west pocket false-wall connector")
    assert_equal(snapshot[14][3], true, "walkability snapshot should include the west pocket false-wall route point")
    assert_equal(snapshot[14][4], true, "walkability snapshot should include the row-14 false-wall recovery cell")
    assert_equal(snapshot[14][5], true, "walkability snapshot should include the row-14 false-wall recovery connector")
    assert_equal(snapshot[7][8], true, "walkability snapshot should include the upper lower-lane false-wall cell")
    assert_equal(snapshot[8][8], true, "walkability snapshot should include the lower-lane false-wall turn")
    assert_equal(snapshot[5][15], true, "walkability snapshot should include the upper return false-wall bypass")
    assert_equal(snapshot[5][14], true, "walkability snapshot should include the upper return false-wall connector")
    assert_equal(snapshot[15][13], true, "walkability snapshot should include the south-side Magic Key route connector")
    assert_equal(snapshot[16][13], true, "walkability snapshot should include the south-side Magic Key route lower connector")
    assert_equal(snapshot[18][13], true, "walkability snapshot should include the south-side false-wall connector")
    assert_equal(snapshot[25][18], true, "walkability snapshot should include the Wings room lower hidden strip west cell")
    assert_equal(snapshot[25][19], true, "walkability snapshot should include the Wings room lower hidden strip middle cell")
    assert_equal(snapshot[22][21], true, "walkability snapshot should include the Wings room row-22 dead-end branch west cell")
    assert_equal(snapshot[22][22], true, "walkability snapshot should include the Wings room row-22 dead-end branch east cell")
    assert_equal(snapshot[18][23], true, "walkability snapshot should include the clean public-side Wings room bridge")
    assert_equal(snapshot[24][21], true, "walkability snapshot should include the Wings room lower hidden strip entry cell")
    assert_equal(snapshot[22][23], true, "walkability snapshot should include the Wings room row-22 shelf west cell")
    assert_equal(snapshot[22][24], true, "walkability snapshot should include the Wings room row-22 shelf east cell")
    assert_equal(snapshot[23][1], true, "walkability snapshot should include the Old Man 3 west-side seam")
    assert_equal(snapshot[23][2], true, "walkability snapshot should include the Old Man 3 public stand seam")
    assert_equal(snapshot[2][24], true, "walkability snapshot should include the northeast x=24 false-wall strip")
    assert_equal(snapshot[3][24], true, "walkability snapshot should include the northeast x=24 false-wall strip")
    assert_equal(snapshot[4][24], true, "walkability snapshot should include the northeast x=24 false-wall strip")
    assert_equal(snapshot[2][25], true, "walkability snapshot should include the northeast x=25 false-wall strip")
    assert_equal(snapshot[3][25], true, "walkability snapshot should include the northeast x=25 false-wall strip")
    assert_equal(snapshot[2][26], true, "walkability snapshot should include the northeast x=26 false-wall strip")
    assert_equal(snapshot[3][26], true, "walkability snapshot should include the northeast x=26 false-wall strip")
    assert_equal(snapshot[2][27], true, "walkability snapshot should include the northeast x=27 false-wall strip")
    assert_equal(snapshot[3][27], true, "walkability snapshot should include the northeast x=27 false-wall strip")
    assert_equal(snapshot[2][28], true, "walkability snapshot should include the northeast x=28 false-wall strip")
    assert_equal(snapshot[3][28], true, "walkability snapshot should include the northeast x=28 false-wall strip")
    assert_equal(snapshot[4][28], true, "walkability snapshot should include the northeast x=28 false-wall strip")
    assert_equal(snapshot[6][28], true, "walkability snapshot should include the northeast x=28 false-wall strip")
    assert_equal(snapshot[7][28], true, "walkability snapshot should include the northeast x=28 false-wall strip")
    assert_equal(snapshot[2][29], true, "walkability snapshot should include the northeast x=29 false-wall strip")
    assert_equal(snapshot[3][29], true, "walkability snapshot should include the chained x=29 force-probed cell")
    assert_equal(snapshot[4][29], true, "walkability snapshot should include the northeast x=29 false-wall strip")
    assert_equal(snapshot[6][29], true, "walkability snapshot should include the northeast x=29 false-wall strip")
    assert_equal(snapshot[7][29], true, "walkability snapshot should include the northeast x=29 false-wall strip")
    assert_equal(snapshot[9][29], true, "walkability snapshot should include the entrance-to-Weapons x=29 false-wall strip")
    assert_equal(snapshot[10][29], true, "walkability snapshot should include the entrance-to-Weapons x=29 false-wall strip")
    assert_equal(snapshot[11][29], true, "walkability snapshot should include the entrance-to-Weapons x=29 false-wall strip")
    assert_equal(snapshot[12][29], true, "walkability snapshot should include the entrance-to-Weapons x=29 false-wall strip")
    assert_equal(snapshot[8][15], false, "walkability snapshot should keep the Woman 3 alternate connector closed")

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

function tests.swamp_cave_west_edge_corridor_overrides_boundary()
    local base = 0x15 * 5
    local memory_bytes = {
        [0] = 0x20, -- TERRAIN_OFFSET stubbed to 0 in make_env()
    }
    local env = make_env({
        rom_bytes = {
            [base] = 0x00,      -- CPU $8000 -> file offset $0010
            [base + 1] = 0x80,
            [base + 2] = 5,     -- width 6
            [base + 3] = 29,    -- height 30
            [base + 4] = 0,
            [0x10] = 0x00, [0x11] = 0x00, [0x12] = 0x00,
            [0x13] = 0x00, [0x14] = 0x00, [0x15] = 0x00,
            [0x16] = 0x00, [0x17] = 0x00, [0x18] = 0x00,
            [0x19] = 0x00, [0x1A] = 0x00, [0x1B] = 0x00,
        },
        memory_bytes = memory_bytes,
        door_array_max = 8,
        door_x_pos_start = 0x600C,
        door_y_pos_start = 0x600D,
        door_array_stride = 2,
    })

    for _, y in ipairs({0, 1, 10, 16, 24, 25}) do
        local details = env.map_reader.get_walkability_details(0x15, 0, y)
        assert_equal(details.base_walkable, true, "Swamp Cave x=0 corridor should be passable")
        assert_equal(details.reason, "passthrough", "Swamp Cave x=0 corridor should override boundary")
    end

    local south_exit = env.map_reader.get_walkability_details(0x15, 0, 29)
    assert_equal(south_exit.base_walkable, true, "Swamp Cave south-island stairs should be passable")
    assert_equal(south_exit.reason, "passthrough", "Swamp Cave south-island stairs should override boundary")

    local lower_turn = env.map_reader.get_walkability_details(0x15, 0, 28)
    assert_equal(lower_turn.base_walkable, true, "Swamp Cave lower west turn should be passable")
    assert_equal(lower_turn.reason, "passthrough", "Swamp Cave lower west turn should override boundary")

    local closed_gwaelin_door = env.map_reader.get_walkability_details(0x15, 5, 20)
    assert_equal(closed_gwaelin_door.base_walkable, false, "Swamp Cave Gwaelin door should block while closed")
    assert_equal(closed_gwaelin_door.reason, "door_closed", "Swamp Cave Gwaelin door should report door_closed")

    memory_bytes[0x600C] = 5
    memory_bytes[0x600D] = 20
    local open_gwaelin_door = env.map_reader.get_walkability_details(0x15, 5, 20)
    assert_equal(open_gwaelin_door.base_walkable, true, "Swamp Cave Gwaelin door should open from door RAM")
    assert_equal(open_gwaelin_door.reason, "door_open", "Swamp Cave Gwaelin door should report door_open")
    memory_bytes[0x600C] = 0
    memory_bytes[0x600D] = 0

    for _, y in ipairs({26, 27}) do
        local closed_south = env.map_reader.get_walkability_details(0x15, 0, y)
        assert_equal(closed_south.base_walkable, false, "Swamp Cave x=0 corridor should stop south of (0,25)")
        assert_equal(closed_south.reason, "engine_boundary", "Swamp Cave lower west edge should keep the boundary rule")
    end

    local dirs = env.map_reader.get_directional_blocks(0x15)
    assert_equal(dirs["1,24"].south, true, "Swamp Cave should block northward entry from (1,25) into (1,24)")
    assert_equal(dirs["1,27"].north, true, "Swamp Cave should block southward entry from (1,26) into (1,27)")
    assert_equal(dirs["1,27"].south, true, "Swamp Cave should block northward entry from (1,28) into (1,27)")
    assert_equal(dirs["2,27"].north, true, "Swamp Cave should block southward entry from (2,26) into (2,27)")
    assert_equal(dirs["2,28"].south, true, "Swamp Cave should block northward entry from (2,29) into (2,28)")
    assert_equal(dirs["2,28"].east, true, "Swamp Cave should block westward entry from (3,28) into (2,28)")
    assert_equal(dirs["2,28"].west, true, "Swamp Cave should block eastward entry from (1,28) into (2,28)")
    assert_equal(dirs["2,27"].east, true, "Swamp Cave should block westward entry from (3,27) into (2,27)")
    local row8 = dirs["1,8"]
    assert_equal(type(row8) == "table" and row8.west or nil, nil, "Swamp Cave should leave (0,8)->RIGHT open as the first x=0 re-entry")
    for y = 9, 18 do
        assert_equal(dirs["1," .. y].west, true, "Swamp Cave should block eastward entry from x=0 corridor through row 18")
    end
    assert_equal(dirs["1,19"].west, true, "Swamp Cave should block eastward entry from (0,19) into (1,19)")
    assert_equal(dirs["1,20"].west, true, "Swamp Cave should block eastward entry from (0,20) into (1,20)")
    assert_equal(dirs["1,21"].west, true, "Swamp Cave should block eastward entry from (0,21) into (1,21)")
    assert_equal(dirs["1,22"].south, true, "Swamp Cave should block northward entry from (1,23) into (1,22)")
    assert_equal(dirs["1,22"].west, true, "Swamp Cave should block eastward entry from (0,22) into (1,22)")
    assert_equal(dirs["2,22"].south, true, "Swamp Cave should block northward entry from (2,23) into (2,22)")
    assert_equal(dirs["3,22"].south, true, "Swamp Cave should block northward entry from (3,23) into (3,22)")
    assert_equal(dirs["4,23"].west, true, "Swamp Cave should block eastward entry from (3,23) into (4,23)")
    assert_equal(dirs["4,23"].east, true, "Swamp Cave should block westward entry from (5,23) into (4,23)")
    assert_equal(dirs["4,24"].west, true, "Swamp Cave should block eastward entry from (3,24) into (4,24)")
    assert_equal(dirs["4,24"].south, true, "Swamp Cave should block northward entry from (4,25) into (4,24)")
    assert_equal(dirs["4,24"].east, nil, "Swamp Cave should leave mixed (5,24)->LEFT evidence unmodeled")
    assert_equal(dirs["5,22"].south, true, "Swamp Cave should block northward entry from (5,23) into (5,22)")

    local out_of_bounds = env.map_reader.get_walkability_details(0x15, 0, 30)
    assert_equal(out_of_bounds.base_walkable, false, "Swamp Cave y=30 should stay out of bounds")
    assert_equal(out_of_bounds.reason, "out_of_bounds", "Swamp Cave y=30 should not become a corridor cell")

    local snapshot = env.map_reader.get_walkability_snapshot(0x15)
    assert_equal(snapshot[0][0], true, "walkability snapshot should include the north entrance")
    assert_equal(snapshot[25][0], true, "walkability snapshot should include the south end of the x=0 corridor")
    assert_equal(snapshot[26][0], false, "walkability snapshot should keep the lower x=0 wall closed")
    assert_equal(snapshot[28][0], true, "walkability snapshot should include the lower return-route west turn")
    assert_equal(snapshot[29][0], true, "walkability snapshot should include the ROM south-island stairs")

    save_module("pathfinder")
    package.loaded["pathfinder"] = nil
    local pathfinder = require "pathfinder"
    local corridor_path = pathfinder.find_path(0x15, 0, 0, 0, 25, {})
    assert_equal(corridor_path ~= nil, true, "Swamp Cave should pathfind from the north exit to the west-corridor bend")
    assert_equal(#corridor_path, 25, "Swamp Cave north-to-bend route should follow the x=0 corridor")

    local south_stairs_path = pathfinder.find_path(0x15, 0, 0, 0, 29, {})
    assert_equal(south_stairs_path ~= nil, true, "Swamp Cave should pathfind from the north exit to the south-island stairs")
    assert_equal(#south_stairs_path, 35, "Swamp Cave south-stairs route should detour around the lower directional blocks")
    assert_equal(path_has_step(south_stairs_path, 1, 27, "south"), false, "Swamp Cave south-stairs path should not retry the blocked (1,26)->DOWN seam")
    assert_equal(path_has_step(south_stairs_path, 2, 27, "south"), false, "Swamp Cave south-stairs path should not retry the blocked (2,26)->DOWN seam")

    local return_path = pathfinder.find_path(0x15, 0, 29, 0, 0, {})
    assert_equal(return_path ~= nil, true, "Swamp Cave should pathfind from the south-island stairs back to the north exit")
    assert_equal(path_has_step(return_path, 1, 24, "north"), false, "Swamp Cave return path should not retry the blocked (1,25)->UP seam")
    assert_equal(path_has_step(return_path, 1, 27, "north"), false, "Swamp Cave return path should not retry the blocked (1,28)->UP seam")
    assert_equal(path_has_step(return_path, 2, 28, "north"), false, "Swamp Cave return path should not retry the blocked (2,29)->UP seam")
    assert_equal(path_has_step(return_path, 2, 28, "east"), false, "Swamp Cave return path should not retry the blocked (1,28)->RIGHT seam")
    assert_equal(path_has_step(return_path, 2, 28, "west"), false, "Swamp Cave return path should not retry the blocked (3,28)->LEFT seam")
    assert_equal(path_has_step(return_path, 2, 27, "west"), false, "Swamp Cave return path should not retry the blocked (3,27)->LEFT seam")

    local blocked_path = pathfinder.find_path(0x15, 0, 0, 0, 26, {})
    assert_equal(blocked_path, nil, "Swamp Cave pathfinder should not route south past (0,25)")

    local closed_door_path = pathfinder.find_path(0x15, 0, 29, 5, 20, {})
    assert_equal(closed_door_path, nil, "Swamp Cave should not path through the closed Gwaelin door cell")

    local door_stand_path = pathfinder.find_path(0x15, 0, 29, 5, 21, {})
    assert_equal(door_stand_path ~= nil, true, "Swamp Cave should route from south stairs to the Gwaelin door stand")
    assert_equal(path_has_step(door_stand_path, 3, 22, "north"), false, "Swamp Cave door route should not retry the blocked (3,23)->UP seam")
    assert_equal(path_has_step(door_stand_path, 4, 23, "east"), false, "Swamp Cave door route should not retry the blocked (3,23)->RIGHT seam")

    local north_to_door_stand = pathfinder.find_path(0x15, 0, 0, 5, 21, {})
    assert_equal(north_to_door_stand ~= nil, true, "Swamp Cave should route from north exit to the Gwaelin door stand")

    local door_stand_to_south = pathfinder.find_path(0x15, 5, 21, 0, 29, {})
    assert_equal(door_stand_to_south ~= nil, true, "Swamp Cave should route from the Gwaelin door stand to the south-island stairs")

    local door_stand_to_north = pathfinder.find_path(0x15, 5, 21, 0, 0, {})
    assert_equal(door_stand_to_north ~= nil, true, "Swamp Cave should route from the Gwaelin door stand to the north exit")

    local post_battle_to_door = pathfinder.find_path(0x15, 3, 26, 5, 21, {})
    assert_equal(post_battle_to_door ~= nil, true, "Swamp Cave should route from the post-battle lower branch back to the Gwaelin door stand")
    for y = 9, 18 do
        assert_equal(path_has_step(post_battle_to_door, 1, y, "east"), false, "Swamp Cave post-battle door route should not retry blocked x=0 east re-entries")
    end
    assert_equal(path_has_step(post_battle_to_door, 1, 19, "east"), false, "Swamp Cave post-battle door route should not retry the blocked (0,19)->RIGHT seam")
    assert_equal(path_has_step(post_battle_to_door, 1, 20, "east"), false, "Swamp Cave post-battle door route should not retry the blocked (0,20)->RIGHT seam")
    assert_equal(path_has_step(post_battle_to_door, 1, 21, "east"), false, "Swamp Cave post-battle door route should not retry the blocked (0,21)->RIGHT seam")
    assert_equal(path_has_step(post_battle_to_door, 1, 22, "east"), false, "Swamp Cave post-battle door route should not retry the blocked (0,22)->RIGHT seam")
    assert_equal(path_has_step(post_battle_to_door, 4, 24, "east"), false, "Swamp Cave post-battle door route should not retry the blocked (3,24)->RIGHT seam")
    assert_equal(path_has_step(post_battle_to_door, 4, 24, "north"), false, "Swamp Cave post-battle door route should not retry the blocked (4,25)->UP seam")
    assert_equal(path_has_step(post_battle_to_door, 1, 22, "north"), false, "Swamp Cave post-battle door route should not retry the blocked (1,23)->UP seam")
    assert_equal(path_has_step(post_battle_to_door, 2, 22, "north"), false, "Swamp Cave post-battle door route should not retry the blocked (2,23)->UP seam")
    assert_equal(path_has_step(post_battle_to_door, 5, 22, "north"), false, "Swamp Cave post-battle door route should not retry the blocked (5,23)->UP seam")
    assert_equal(path_has_step(post_battle_to_door, 4, 23, "west"), false, "Swamp Cave post-battle door route should not retry the blocked (5,23)->LEFT seam")
    restore_modules({"pathfinder"})

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
