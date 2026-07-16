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

local function fill_packed_map(rom_bytes, data_start, width, height, block_id)
    local packed = (block_id % 16) * 0x11
    for offset = 0, math.ceil(width * height / 2) - 1 do
        rom_bytes[data_start + offset] = packed
    end
end

local function set_packed_block(rom_bytes, data_start, width, x, y, block_id)
    local tile_index = y * width + x
    local offset = data_start + math.floor(tile_index / 2)
    local byte = rom_bytes[offset] or 0
    block_id = block_id % 16
    if tile_index % 2 == 0 then
        rom_bytes[offset] = block_id * 16 + byte % 16
    else
        rom_bytes[offset] = math.floor(byte / 16) * 16 + block_id
    end
end

local MAP_NAMES = {
    [0x04] = "Tantegel Castle",
    [0x0C] = "Sun Shrine",
    [0x08] = "Brecconary",
    [0x0A] = "Cantlin",
    [0x0B] = "Rimuldar",
    [0x18] = "Garin's Grave B1",
    [0x19] = "Garin's Grave B2",
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

local function assert_sun_shrine_dir(env, cell, approach, message)
    assert_directional_block(env, 0x0C, cell, approach, message)
end

local function assert_cantlin_dir(env, cell, approach, message)
    assert_directional_block(env, 0x0A, cell, approach, message)
end

local function assert_garins_grave_b1_dir(env, cell, approach, message)
    assert_directional_block(env, 0x18, cell, approach, message)
end

local function assert_garins_grave_b2_dir(env, cell, approach, message)
    assert_directional_block(env, 0x19, cell, approach, message)
end

local function assert_garins_grave_b3_dir(env, cell, approach, message)
    assert_directional_block(env, 0x1A, cell, approach, message)
end

local function assert_garins_grave_b4_dir(env, cell, approach, message)
    assert_directional_block(env, 0x1B, cell, approach, message)
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

local function path_to_string(path)
    local parts = {}
    for _, step in ipairs(path or {}) do
        parts[#parts + 1] = string.format("%s->%d,%d", step.direction or "?", step.x or -1, step.y or -1)
    end
    return table.concat(parts, " ")
end

local function with_cleanup(body, cleanup)
    local ok, err = pcall(body)
    local cleanup_ok, cleanup_err = pcall(cleanup)

    if not ok then
        if not cleanup_ok then
            error(string.format("%s (cleanup failed: %s)", tostring(err), tostring(cleanup_err)), 0)
        end
        error(err, 0)
    end

    if not cleanup_ok then
        error(cleanup_err, 0)
    end
end

local tests = {}

function tests.with_cleanup_runs_cleanup_after_body_failure()
    local cleaned = false
    local ok, err = pcall(function()
        with_cleanup(
            function()
                error("forced body failure", 0)
            end,
            function()
                cleaned = true
            end
        )
    end)

    assert_equal(ok, false, "with_cleanup should rethrow the body failure")
    assert_equal(cleaned, true, "with_cleanup should run cleanup even when the body fails")
    assert_equal(string.find(tostring(err), "forced body failure", 1, true) ~= nil, true, "with_cleanup should preserve the body failure")
end

function tests.interior_decoder_reads_even_width_packed_nibbles()
    local map_id = 0x04
    local base = map_id * 5
    local data_start = 0x120
    local rom_bytes = {
        [base] = 0x10,      -- CPU $8110 -> file offset $0120
        [base + 1] = 0x81,
        [base + 2] = 3,     -- width 4
        [base + 3] = 1,     -- height 2
        [base + 4] = 0,
        [data_start + 0] = 0x4F,
        [data_start + 1] = 0xC0,
        [data_start + 2] = 0x9A,
        [data_start + 3] = 0x12,
    }
    local expected = {
        [0] = {[0] = 0x4, [1] = 0xF, [2] = 0xC, [3] = 0x0},
        [1] = {[0] = 0x9, [1] = 0xA, [2] = 0x1, [3] = 0x2},
    }
    local env = make_env({rom_bytes = rom_bytes})
    local grid = env.map_reader.decompress_map(map_id)

    for y = 0, 1 do
        for x = 0, 3 do
            local message = string.format("packed 4x2 coordinate (%d,%d)", x, y)
            assert_equal(grid[y][x], expected[y][x], message .. " grid value")
            assert_equal(env.map_reader.get_raw_block_id(map_id, x, y), expected[y][x], message .. " raw value")
        end
    end

    env.restore()
end

function tests.interior_decoder_keeps_odd_width_rows_byte_contiguous()
    local map_id = 0x08
    local base = map_id * 5
    local data_start = 0x220
    local rom_bytes = {
        [base] = 0x10,      -- CPU $8210 -> file offset $0220
        [base + 1] = 0x82,
        [base + 2] = 2,     -- width 3
        [base + 3] = 1,     -- height 2
        [base + 4] = 0,
        [data_start + 0] = 0x12,
        [data_start + 1] = 0x34,
        [data_start + 2] = 0x56,
    }
    local expected = {
        [0] = {[0] = 0x1, [1] = 0x2, [2] = 0x3},
        [1] = {[0] = 0x4, [1] = 0x5, [2] = 0x6},
    }
    local env = make_env({rom_bytes = rom_bytes})
    local grid = env.map_reader.decompress_map(map_id)

    for y = 0, 1 do
        for x = 0, 2 do
            local message = string.format("packed 3x2 coordinate (%d,%d)", x, y)
            assert_equal(grid[y][x], expected[y][x], message .. " grid value")
            assert_equal(env.map_reader.get_raw_block_id(map_id, x, y), expected[y][x], message .. " raw value")
        end
    end

    env.restore()
end

function tests.rimuldar_packed_fixture_keeps_raw_and_grid_values_aligned()
    local map_id = 0x0B
    local base = map_id * 5
    local data_start = 0x320
    local rom_bytes = {
        [base] = 0x10,      -- CPU $8310 -> file offset $0320
        [base + 1] = 0x83,
        [base + 2] = 29,    -- width 30
        [base + 3] = 29,    -- height 30
        [base + 4] = 0,
    }
    fill_packed_map(rom_bytes, data_start, 30, 30, 0x0)
    set_packed_block(rom_bytes, data_start, 30, 1, 3, 0xE)
    set_packed_block(rom_bytes, data_start, 30, 4, 5, 0x6)
    set_packed_block(rom_bytes, data_start, 30, 4, 6, 0xF)

    local env = make_env({rom_bytes = rom_bytes})
    local grid = env.map_reader.decompress_map(map_id)
    local checks = {
        {x = 1, y = 3, expected = 0xE, label = "bridge"},
        {x = 4, y = 5, expected = 0x6, label = "merchant stand"},
        {x = 4, y = 6, expected = 0xF, label = "counter"},
    }
    for _, check in ipairs(checks) do
        local message = string.format("Rimuldar %s (%d,%d)", check.label, check.x, check.y)
        assert_equal(grid[check.y][check.x], check.expected, message .. " grid value")
        assert_equal(env.map_reader.get_raw_block_id(map_id, check.x, check.y), check.expected, message .. " raw value")
    end

    env.restore()
end

function tests.rimuldar_live_magic_key_route_is_walkable_and_exit_seams_are_guarded()
    local map_id = 0x0B
    local base = map_id * 5
    local data_start = 0x420
    local rom_bytes = {
        [base] = 0x10,      -- CPU $8410 -> file offset $0420
        [base + 1] = 0x84,
        [base + 2] = 29,    -- width 30
        [base + 3] = 29,    -- height 30
        [base + 4] = 0,
    }
    fill_packed_map(rom_bytes, data_start, 30, 30, 0x0)

    -- Ordinary terrain along the live route; all other route cells intentionally
    -- remain raw type 0 so the test exercises map-scoped passthrough data.
    for _, cell in ipairs({
        {29, 14, 0x6},
        {1, 3, 0xE},
        {4, 3, 0x6},
        {5, 3, 0x6},
        {5, 4, 0x6},
        {5, 5, 0x6},
        {4, 5, 0x6},
        {4, 6, 0xF},
    }) do
        set_packed_block(rom_bytes, data_start, 30, cell[1], cell[2], cell[3])
    end

    local env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = {[0] = 0x10},
    })

    with_cleanup(function()
        local route = {}
        local function add_route_cell(x, y)
            route[#route + 1] = {x = x, y = y}
        end

        for y = 14, 2, -1 do add_route_cell(29, y) end
        for x = 28, 21, -1 do add_route_cell(x, 2) end
        add_route_cell(21, 1)
        add_route_cell(21, 0)
        for x = 20, 0, -1 do add_route_cell(x, 0) end
        for y = 1, 3 do add_route_cell(0, y) end
        for _, cell in ipairs({
            {1, 3}, {2, 3}, {3, 3}, {4, 3}, {5, 3},
            {5, 4}, {5, 5}, {4, 5},
        }) do
            add_route_cell(cell[1], cell[2])
        end

        for _, cell in ipairs(route) do
            local details = env.map_reader.get_walkability_details(map_id, cell.x, cell.y)
            assert_equal(
                details and details.effective_walkable or nil,
                true,
                string.format("Rimuldar live Magic Key route cell (%d,%d) should be walkable", cell.x, cell.y)
            )
        end

        local counter = env.map_reader.get_walkability_details(map_id, 4, 6)
        assert_equal(counter.tile_type, 0xF, "Rimuldar counter (4,6) should retain raw type 15")
        assert_equal(counter.base_walkable, false, "Rimuldar counter (4,6) should not be a passthrough")
        assert_equal(counter.effective_walkable, false, "Rimuldar counter (4,6) should remain globally non-walkable")
        assert_equal(counter.reason, "tile_type", "Rimuldar counter (4,6) should be blocked by corrected tile decoding")

        local dirs = env.map_reader.get_directional_blocks(map_id)
        for y = 1, 3 do
            local cell = "0," .. y
            local guard = dirs[cell] or {}
            assert_equal(guard.east, true, cell .. " should block entry from the east to prevent a world-map transition")
            assert_equal(guard.north, nil, cell .. " should keep northward travel open along the x=0 strip")
            assert_equal(guard.south, nil, cell .. " should keep southward travel open along the x=0 strip")
        end
    end, env.restore)
end

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
    local closed_inn = closed_env.map_reader.get_walkability_details(0x08, 5, 23)
    assert_equal(closed_inn.effective_walkable, false, "closed Brecconary inn west-room door should block movement")
    assert_equal(closed_inn.reason, "door_closed", "closed Brecconary inn west-room door should report door_closed")
    local old_inn_guess = closed_env.map_reader.get_walkability_details(0x08, 5, 22)
    assert_equal(old_inn_guess.reason == "door_closed", false, "old Brecconary inn west-room guess should no longer be a door override")
    closed_env.restore()

    local open_env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = {
            [0] = 0x10,
            [0x600C] = 21,
            [0x600D] = 6,
            [0x600E] = 5,
            [0x600F] = 23,
        },
        door_array_max = 8,
        door_x_pos_start = 0x600C,
        door_y_pos_start = 0x600D,
        door_array_stride = 2,
    })

    local open_ne = open_env.map_reader.get_walkability_details(0x08, 21, 6)
    assert_equal(open_ne.effective_walkable, true, "opened Brecconary northeast door should become walkable")
    assert_equal(open_ne.reason, "door_open", "opened Brecconary northeast door should report door_open")
    local open_inn = open_env.map_reader.get_walkability_details(0x08, 5, 23)
    assert_equal(open_inn.effective_walkable, true, "opened Brecconary inn west-room door should become walkable")
    assert_equal(open_inn.reason, "door_open", "opened Brecconary inn west-room door should report door_open")
    local snapshot = open_env.map_reader.get_walkability_snapshot(0x08)
    assert_equal(snapshot[6][21], true, "walkability snapshot should honor opened Brecconary northeast door")
    assert_equal(snapshot[23][5], true, "walkability snapshot should honor opened Brecconary inn west-room door")

    open_env.restore()
end


function tests.cantlin_confirmed_locked_doors_open_from_door_ram_array()
    local base = 0x0A * 5
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

    local context = closed_env.map_reader.get_door_cell_context(0x0A, 26, 9)
    assert_equal(context ~= nil, true, "Cantlin eastern locked door should be modeled")
    assert_equal(context.open, false, "Cantlin eastern door should start closed without door RAM")
    local central_right_context = closed_env.map_reader.get_door_cell_context(0x0A, 15, 25)
    assert_equal(central_right_context ~= nil, true, "Cantlin central right locked door should be modeled")
    assert_equal(central_right_context.open, false, "Cantlin central right door should start closed without door RAM")
    local central_left_context = closed_env.map_reader.get_door_cell_context(0x0A, 14, 25)
    assert_equal(central_left_context ~= nil, true, "Cantlin central left locked door should be modeled")
    assert_equal(central_left_context.open, false, "Cantlin central left door should start closed without door RAM")
    local western_north_context = closed_env.map_reader.get_door_cell_context(0x0A, 4, 21)
    assert_equal(western_north_context ~= nil, true, "Cantlin western shop north locked door should be modeled")
    assert_equal(western_north_context.open, false, "Cantlin western shop north door should start closed without door RAM")
    local western_east_context = closed_env.map_reader.get_door_cell_context(0x0A, 8, 25)
    assert_equal(western_east_context ~= nil, true, "Cantlin western shop east locked door should be modeled")
    assert_equal(western_east_context.open, false, "Cantlin western shop east door should start closed without door RAM")
    local closed = closed_env.map_reader.get_walkability_details(0x0A, 26, 9)
    assert_equal(closed.effective_walkable, false, "closed Cantlin eastern door should block movement")
    assert_equal(closed.reason, "door_closed", "closed Cantlin eastern door should report door_closed")
    local central_right_closed = closed_env.map_reader.get_walkability_details(0x0A, 15, 25)
    assert_equal(central_right_closed.effective_walkable, false, "closed Cantlin central right door should block movement")
    assert_equal(central_right_closed.reason, "door_closed", "closed Cantlin central right door should report door_closed")
    local central_left_closed = closed_env.map_reader.get_walkability_details(0x0A, 14, 25)
    assert_equal(central_left_closed.effective_walkable, false, "closed Cantlin central left door should block movement")
    assert_equal(central_left_closed.reason, "door_closed", "closed Cantlin central left door should report door_closed")
    local western_north_closed = closed_env.map_reader.get_walkability_details(0x0A, 4, 21)
    assert_equal(western_north_closed.effective_walkable, false, "closed Cantlin western shop north door should block movement")
    assert_equal(western_north_closed.reason, "door_closed", "closed Cantlin western shop north door should report door_closed")
    local western_east_closed = closed_env.map_reader.get_walkability_details(0x0A, 8, 25)
    assert_equal(western_east_closed.effective_walkable, false, "closed Cantlin western shop east door should block movement")
    assert_equal(western_east_closed.reason, "door_closed", "closed Cantlin western shop east door should report door_closed")
    local false_wall_band = closed_env.map_reader.get_door_cell_context(0x0A, 25, 12)
    assert_equal(false_wall_band, nil, "disproved Cantlin facade candidate (25,12) should not be modeled as a door")
    closed_env.restore()

    local open_env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = {
            [0] = 0x10,
            [0x600C] = 26,
            [0x600D] = 9,
            [0x600E] = 15,
            [0x600F] = 25,
            [0x6010] = 14,
            [0x6011] = 25,
            [0x6012] = 4,
            [0x6013] = 21,
            [0x6014] = 8,
            [0x6015] = 25,
        },
        door_array_max = 8,
        door_x_pos_start = 0x600C,
        door_y_pos_start = 0x600D,
        door_array_stride = 2,
    })

    context = open_env.map_reader.get_door_cell_context(0x0A, 26, 9)
    assert_equal(context.open, true, "Cantlin eastern door should open from door RAM at (26,9)")
    local opened = open_env.map_reader.get_walkability_details(0x0A, 26, 9)
    assert_equal(opened.effective_walkable, true, "opened Cantlin eastern door should become walkable")
    assert_equal(opened.reason, "door_open", "opened Cantlin eastern door should report door_open")
    central_right_context = open_env.map_reader.get_door_cell_context(0x0A, 15, 25)
    assert_equal(central_right_context.open, true, "Cantlin central right door should open from door RAM at (15,25)")
    local central_right_opened = open_env.map_reader.get_walkability_details(0x0A, 15, 25)
    assert_equal(central_right_opened.effective_walkable, true, "opened Cantlin central right door should become walkable")
    assert_equal(central_right_opened.reason, "door_open", "opened Cantlin central right door should report door_open")
    central_left_context = open_env.map_reader.get_door_cell_context(0x0A, 14, 25)
    assert_equal(central_left_context.open, true, "Cantlin central left door should open from door RAM at (14,25)")
    local central_left_opened = open_env.map_reader.get_walkability_details(0x0A, 14, 25)
    assert_equal(central_left_opened.effective_walkable, true, "opened Cantlin central left door should become walkable")
    assert_equal(central_left_opened.reason, "door_open", "opened Cantlin central left door should report door_open")
    western_north_context = open_env.map_reader.get_door_cell_context(0x0A, 4, 21)
    assert_equal(western_north_context.open, true, "Cantlin western shop north door should open from door RAM at (4,21)")
    local western_north_opened = open_env.map_reader.get_walkability_details(0x0A, 4, 21)
    assert_equal(western_north_opened.effective_walkable, true, "opened Cantlin western shop north door should become walkable")
    assert_equal(western_north_opened.reason, "door_open", "opened Cantlin western shop north door should report door_open")
    western_east_context = open_env.map_reader.get_door_cell_context(0x0A, 8, 25)
    assert_equal(western_east_context.open, true, "Cantlin western shop east door should open from door RAM at (8,25)")
    local western_east_opened = open_env.map_reader.get_walkability_details(0x0A, 8, 25)
    assert_equal(western_east_opened.effective_walkable, true, "opened Cantlin western shop east door should become walkable")
    assert_equal(western_east_opened.reason, "door_open", "opened Cantlin western shop east door should report door_open")
    local snapshot = open_env.map_reader.get_walkability_snapshot(0x0A)
    assert_equal(snapshot[9][26], true, "walkability snapshot should honor opened Cantlin eastern door")
    assert_equal(snapshot[25][15], true, "walkability snapshot should honor opened Cantlin central right door")
    assert_equal(snapshot[25][14], true, "walkability snapshot should honor opened Cantlin central left door")
    assert_equal(snapshot[21][4], true, "walkability snapshot should honor opened Cantlin western shop north door")
    assert_equal(snapshot[25][8], true, "walkability snapshot should honor opened Cantlin western shop east door")

    open_env.restore()
end

function tests.garinham_old_east_door_guess_is_not_a_door_override()
    local memory_bytes = {
        [0x600C] = 19,
        [0x600D] = 16,
    }
    local env = make_env({
        memory_bytes = memory_bytes,
        door_array_max = 8,
        door_x_pos_start = 0x600C,
        door_y_pos_start = 0x600D,
        door_array_stride = 2,
    })

    local context = env.map_reader.get_door_cell_context(0x09, 19, 16)
    assert_equal(context, nil, "disproved Garinham east-door guess should not be a door override")
    local old_grey_guess_context = env.map_reader.get_door_cell_context(0x09, 18, 9)
    assert_equal(old_grey_guess_context, nil, "old Garinham grey-building door guess should not be a door override")
    local grey_door_context = env.map_reader.get_door_cell_context(0x09, 17, 10)
    assert_equal(grey_door_context ~= nil, true, "Garinham grey-building grave-route door should be modeled")
    assert_equal(grey_door_context.open, false, "wrong opened-door RAM coordinate should not open Garinham grey-building door")
    local inner_door_context = env.map_reader.get_door_cell_context(0x09, 4, 6)
    assert_equal(inner_door_context ~= nil, true, "Garinham inner locked-building door should be modeled")
    assert_equal(inner_door_context.open, false, "wrong opened-door RAM coordinate should not open Garinham inner door")
    memory_bytes[0x600C] = 18
    memory_bytes[0x600D] = 9
    grey_door_context = env.map_reader.get_door_cell_context(0x09, 17, 10)
    assert_equal(grey_door_context.open, false, "old 18,9 door-RAM guess should not open Garinham grey-building door")
    memory_bytes[0x600C] = 4
    memory_bytes[0x600D] = 6
    inner_door_context = env.map_reader.get_door_cell_context(0x09, 4, 6)
    assert_equal(inner_door_context.open, true, "Garinham inner door should open from door RAM at (4,6)")
    local hidden_wall_context = env.map_reader.get_door_cell_context(0x09, 13, 4)
    assert_equal(hidden_wall_context, nil, "Garinham hidden-wall seam should not be modeled as a door")

    env.restore()
end

function tests.garinham_grey_building_door_opens_from_door_ram_array()
    local base = 0x09 * 5
    local data_start = 0x120
    local data_cpu_ptr = 0x8000 + data_start - 0x10
    local rom_bytes = {
        [base] = data_cpu_ptr % 0x100,
        [base + 1] = math.floor(data_cpu_ptr / 0x100),
        [base + 2] = 19,
        [base + 3] = 19,
        [base + 4] = 0,
    }
    fill_packed_map(rom_bytes, data_start, 20, 20, 0x2)

    local memory_bytes = {
        [0] = 0x10,
    }
    local env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = memory_bytes,
        door_array_max = 8,
        door_x_pos_start = 0x600C,
        door_y_pos_start = 0x600D,
        door_array_stride = 2,
    })

    local closed = env.map_reader.get_walkability_details(0x09, 17, 10)
    assert_equal(closed.effective_walkable, false, "closed Garinham grave-route door should block movement")
    assert_equal(closed.reason, "door_closed", "closed Garinham grave-route door should report door_closed")
    local inner_closed = env.map_reader.get_walkability_details(0x09, 4, 6)
    assert_equal(inner_closed.effective_walkable, false, "closed Garinham inner door should block movement")
    assert_equal(inner_closed.reason, "door_closed", "closed Garinham inner door should report door_closed")

    memory_bytes[0x600C] = 17
    memory_bytes[0x600D] = 10
    local open = env.map_reader.get_walkability_details(0x09, 17, 10)
    assert_equal(open.effective_walkable, true, "opened Garinham grave-route door should become walkable")
    assert_equal(open.reason, "door_open", "opened Garinham grave-route door should report door_open")
    memory_bytes[0x600C] = 4
    memory_bytes[0x600D] = 6
    local inner_open = env.map_reader.get_walkability_details(0x09, 4, 6)
    assert_equal(inner_open.effective_walkable, true, "opened Garinham inner door should become walkable")
    assert_equal(inner_open.reason, "door_open", "opened Garinham inner door should report door_open")
    local snapshot = env.map_reader.get_walkability_snapshot(0x09)
    assert_equal(snapshot[10][17], false, "walkability snapshot should treat unopened Garinham grave-route door as closed")
    assert_equal(snapshot[6][4], true, "walkability snapshot should honor opened Garinham inner door")

    env.restore()
end

function tests.garins_grave_b1_southeast_door_opens_from_door_ram_array()
    local base = 0x18 * 5
    local data_start = 0x180
    local data_cpu_ptr = 0x8000 + data_start - 0x10
    local rom_bytes = {
        [base] = data_cpu_ptr % 0x100,
        [base + 1] = math.floor(data_cpu_ptr / 0x100),
        [base + 2] = 19,
        [base + 3] = 19,
        [base + 4] = 0,
    }
    fill_packed_map(rom_bytes, data_start, 20, 20, 0x2)

    local memory_bytes = {
        [0] = 0x20,
    }
    local env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = memory_bytes,
        door_array_max = 8,
        door_x_pos_start = 0x600C,
        door_y_pos_start = 0x600D,
        door_array_stride = 2,
    })

    local closed = env.map_reader.get_walkability_details(0x18, 17, 17)
    assert_equal(closed.effective_walkable, false, "closed Garin's Grave B1 southeast door should block movement")
    assert_equal(closed.reason, "door_closed", "closed Garin's Grave B1 southeast door should report door_closed")
    local ctx = env.map_reader.get_door_cell_context(0x18, 17, 17)
    assert_equal(ctx ~= nil, true, "Garin's Grave B1 southeast door should be modeled as a door cell")
    assert_equal(ctx.open, false, "closed Garin's Grave B1 southeast door should report closed door context")

    memory_bytes[0x600C] = 17
    memory_bytes[0x600D] = 17
    local open = env.map_reader.get_walkability_details(0x18, 17, 17)
    assert_equal(open.effective_walkable, true, "opened Garin's Grave B1 southeast door should become walkable")
    assert_equal(open.reason, "door_open", "opened Garin's Grave B1 southeast door should report door_open")
    local snapshot = env.map_reader.get_walkability_snapshot(0x18)
    assert_equal(snapshot[17][17], true, "walkability snapshot should honor the opened Garin's Grave B1 southeast door")

    local false_neighbor = env.map_reader.get_door_cell_context(0x18, 18, 17)
    assert_equal(false_neighbor, nil, "adjacent southeast wall cells should not be promoted into B1 door overrides")

    env.restore()
end

function tests.garinham_grave_dark_wall_entry_is_passthrough()
    local base = 0x09 * 5
    local data_start = 0x120
    local data_cpu_ptr = 0x8000 + data_start - 0x10
    local rom_bytes = {
        [base] = data_cpu_ptr % 0x100,
        [base + 1] = math.floor(data_cpu_ptr / 0x100),
        [base + 2] = 19,
        [base + 3] = 19,
        [base + 4] = 0,
    }
    fill_packed_map(rom_bytes, data_start, 20, 20, 0x6)
    set_packed_block(rom_bytes, data_start, 20, 19, 10, 0x2)
    set_packed_block(rom_bytes, data_start, 20, 3, 13, 0x2)
    set_packed_block(rom_bytes, data_start, 20, 3, 17, 0xB)

    local env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = {
            [0] = 0x10,
        },
        door_array_max = 8,
        door_x_pos_start = 0x600C,
        door_y_pos_start = 0x600D,
        door_array_stride = 2,
    })

    local entry = env.map_reader.get_walkability_details(0x09, 3, 3)
    assert_equal(entry.tile_type, 6, "mocked Garinham dark-wall entry tile should decode as floor")
    assert_equal(entry.effective_walkable, true, "Garinham dark-wall entry should be walkable through passthrough data")
    assert_equal(entry.reason, "passthrough", "Garinham dark-wall entry should report passthrough")
    local top_edge = env.map_reader.get_walkability_details(0x09, 18, 0)
    assert_equal(top_edge.tile_type, 6, "mocked Garinham top-edge tile should decode as wall")
    assert_equal(top_edge.effective_walkable, true, "Garinham (18,0) should be walkable after live edge proof from (18,1)")
    assert_equal(top_edge.reason, "passthrough", "Garinham (18,0) should report passthrough")
    local top_lane_west = env.map_reader.get_walkability_details(0x09, 13, 0)
    assert_equal(top_lane_west.tile_type, 6, "mocked Garinham (13,0) top-lane tile should decode as wall")
    assert_equal(top_lane_west.effective_walkable, true, "Garinham (13,0) should be walkable after live east/west proof")
    assert_equal(top_lane_west.reason, "passthrough", "Garinham (13,0) should report passthrough")
    local top_lane_east = env.map_reader.get_walkability_details(0x09, 14, 0)
    assert_equal(top_lane_east.tile_type, 6, "mocked Garinham (14,0) top-lane tile should decode as wall")
    assert_equal(top_lane_east.effective_walkable, true, "Garinham (14,0) should be walkable after live east/west proof")
    assert_equal(top_lane_east.reason, "passthrough", "Garinham (14,0) should report passthrough")
    local top_lane_descent = env.map_reader.get_walkability_details(0x09, 15, 0)
    assert_equal(top_lane_descent.tile_type, 6, "mocked Garinham (15,0) top-lane descent tile should decode as wall")
    assert_equal(top_lane_descent.effective_walkable, true, "Garinham (15,0) should be walkable after live proof from (14,0)->RIGHT")
    assert_equal(top_lane_descent.reason, "passthrough", "Garinham (15,0) should report passthrough")
    local grave_stairs = env.map_reader.get_walkability_details(0x09, 19, 0)
    assert_equal(grave_stairs.tile_type, 6, "mocked Garinham grave stairs tile should decode as wall")
    assert_equal(grave_stairs.effective_walkable, true, "Garinham (19,0) should be walkable for the live-confirmed grave stairs")
    assert_equal(grave_stairs.reason, "passthrough", "Garinham (19,0) should report passthrough")
    local lower_bridge = env.map_reader.get_walkability_details(0x09, 19, 10)
    assert_equal(lower_bridge.tile_type, 2, "mocked Garinham lower bridge tile should match live wall type")
    assert_equal(lower_bridge.effective_walkable, false, "Garinham (19,10) should stay blocked after same-origin route/probe proof")
    assert_equal(lower_bridge.reason, "tile_type", "Garinham (19,10) should no longer report passthrough")
    local tool_pocket_passage = env.map_reader.get_walkability_details(0x09, 3, 13)
    assert_equal(tool_pocket_passage.tile_type, 2, "mocked Garinham tool-pocket passage should match live type-2 wall")
    assert_equal(tool_pocket_passage.effective_walkable, true, "Garinham (3,13) should be walkable after same-origin sweep/probe proof")
    assert_equal(tool_pocket_passage.reason, "passthrough", "Garinham (3,13) should report passthrough")
    local hidden_passage = env.map_reader.get_walkability_details(0x09, 3, 17)
    assert_equal(hidden_passage.tile_type, 11, "mocked Garinham lower passage should match live type-11 wall")
    assert_equal(hidden_passage.effective_walkable, true, "Garinham (3,17) should be walkable after same-origin sweep/probe proof")
    assert_equal(hidden_passage.reason, "passthrough", "Garinham (3,17) should report passthrough")
    local snapshot = env.map_reader.get_walkability_snapshot(0x09)
    assert_equal(snapshot[3][3], true, "walkability snapshot should honor Garinham dark-wall passthrough")
    assert_equal(snapshot[0][13], true, "walkability snapshot should honor Garinham (13,0) top-lane passthrough")
    assert_equal(snapshot[0][14], true, "walkability snapshot should honor Garinham (14,0) top-lane passthrough")
    assert_equal(snapshot[0][15], true, "walkability snapshot should honor Garinham (15,0) top-lane descent passthrough")
    assert_equal(snapshot[0][18], true, "walkability snapshot should honor Garinham top-edge passthrough")
    assert_equal(snapshot[0][19], true, "walkability snapshot should honor Garinham grave-stairs passthrough")
    assert_equal(snapshot[10][19], false, "walkability snapshot should keep stale Garinham lower bridge blocked")
    assert_equal(snapshot[13][3], true, "walkability snapshot should honor Garinham tool-pocket passthrough")
    assert_equal(snapshot[17][3], true, "walkability snapshot should honor Garinham lower-passage passthrough")

    save_module("pathfinder")
    package.loaded["pathfinder"] = nil
    local pathfinder = require "pathfinder"
    local top_lane_path = pathfinder.find_path(0x09, 13, 0, 19, 0, {})
    assert_equal(top_lane_path ~= nil, true, "Garinham should route from live-confirmed (13,0) to the grave stairs")
    assert_equal(path_has_step(top_lane_path, 14, 0, "east"), true, "Garinham top-lane path should cross live-confirmed (13,0)->(14,0); path=" .. path_to_string(top_lane_path))
    assert_equal(path_has_step(top_lane_path, 15, 0, "east"), true, "Garinham top-lane path should cross live-confirmed (14,0)->(15,0); path=" .. path_to_string(top_lane_path))
    assert_equal(path_has_step(top_lane_path, 15, 1, "south"), true, "Garinham top-lane path should descend through live-confirmed (15,0)->(15,1); path=" .. path_to_string(top_lane_path))
    restore_modules({"pathfinder"})

    env.restore()
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
    fill_packed_map(rom_bytes, data_start, 30, 30, 0x6)

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

function tests.cantlin_old_man_4_route_edges_are_modeled()
    local env = make_env()

    assert_cantlin_dir(env, "21,23", "west", "(21,23).west should block after Old Man 4 route failure and same-origin probe from (20,23)->RIGHT")
    assert_cantlin_dir(env, "21,24", "west", "(21,24).west should block after Old Man 4 route failure and same-origin probe from (20,24)->RIGHT")
    assert_cantlin_dir(env, "21,24", "east", "(21,24).east should block after follow-up route failure and same-origin probe from (22,24)->LEFT")
    assert_cantlin_dir(env, "21,24", "south", "(21,24).south should block after follow-up route failure and same-origin probe from (21,25)->UP")
    assert_cantlin_dir(env, "22,23", "south", "(22,23).south should block after Old Man 4 route failure and same-origin probe from (22,24)->UP")
    assert_cantlin_dir(env, "23,24", "west", "(23,24).west should block after Old Man 4 route failure and same-origin probe from (22,24)->RIGHT")
    assert_cantlin_dir(env, "23,25", "west", "(23,25).west should block after follow-up route failure and same-origin probe from (22,25)->RIGHT")
    assert_cantlin_dir(env, "23,25", "south", "(23,25).south should block after follow-up route failure and same-origin probe from (23,26)->UP")
    assert_cantlin_dir(env, "24,24", "south", "(24,24).south should block after post-reload route failure and same-origin probe from (24,25)->UP")

    env.restore()
end
function tests.cantlin_north_lane_routes_through_west_descent()
    local base = 0x0A * 5
    local data_start = 0x1010
    local rom_bytes = {
        [base] = 0x00,
        [base + 1] = 0x90,
        [base + 2] = 29,
        [base + 3] = 29,
        [base + 4] = 0,
    }
    fill_packed_map(rom_bytes, data_start, 30, 30, 0x6)
    local env = make_env({rom_bytes = rom_bytes})

    for x = 1, 29 do
        local details = env.map_reader.get_walkability_details(0x0A, x, 0)
        assert_equal(details.effective_walkable, true, string.format("Cantlin (%d,0) should be pathable after live north-lane proof", x))
        assert_equal(details.reason, "passthrough", string.format("Cantlin (%d,0) should override the generic engine boundary", x))
    end
    assert_equal(env.map_reader.get_walkability_details(0x0A, 0, 0).effective_walkable, false, "Cantlin (0,0) should remain blocked after the west-boundary probe")

    assert_cantlin_dir(env, "15,1", "north", "(15,1).north should block after live arrival-shelf probe from (15,0)->DOWN")
    assert_cantlin_dir(env, "16,1", "north", "(16,1).north should block after live arrival-shelf probe from (16,0)->DOWN")
    assert_cantlin_dir(env, "23,0", "south", "(23,0).south should guard the north world-map transition from ordinary routing")
    assert_cantlin_dir(env, "26,1", "north", "(26,1).north should block after normal probe and 3/3 verifier from (26,0)->DOWN")
    assert_cantlin_dir(env, "27,1", "north", "(27,1).north should block after normal probe and 3/3 verifier from (27,0)->DOWN")
    assert_cantlin_dir(env, "28,1", "north", "(28,1).north should block after normal probe and 3/3 verifier from (28,0)->DOWN")
    assert_cantlin_dir(env, "29,0", "west", "(29,0).west should guard the northeast world-map transition from ordinary routing")

    save_module("pathfinder")
    package.loaded["pathfinder"] = nil
    local pathfinder = require "pathfinder"
    local north_lane_path = pathfinder.find_path(0x0A, 1, 0, 28, 0, {})
    assert_equal(north_lane_path ~= nil, true, "Cantlin should route across the confirmed north lane")
    assert_equal(path_has_step(north_lane_path, 28, 0, "east"), true, "Cantlin north-lane path should reach the safe northeast-exit stand; path=" .. path_to_string(north_lane_path))
    local path = pathfinder.find_path(0x0A, 16, 0, 14, 2, {})
    assert_equal(path ~= nil, true, "Cantlin should route from the player-facing entrance through the west descent")
    assert_equal(path_has_step(path, 15, 0, "west"), true, "Cantlin entrance path should cross (16,0)->(15,0); path=" .. path_to_string(path))
    assert_equal(path_has_step(path, 14, 0, "west"), true, "Cantlin entrance path should cross (15,0)->(14,0); path=" .. path_to_string(path))
    assert_equal(path_has_step(path, 14, 1, "south"), true, "Cantlin entrance path should descend only at (14,0)->(14,1); path=" .. path_to_string(path))
    local key_merchant_path = pathfinder.find_path(0x0A, 16, 0, 27, 5, {})
    assert_equal(key_merchant_path ~= nil, true, "Cantlin should route from the town entrance to the verified Magic Key Merchant stand")
    restore_modules({"pathfinder"})

    env.restore()
end

function tests.cantlin_premium_merchant_hidden_bridge_is_passthrough()
    local base = 0x0A * 5
    local data_start = 0x120
    local rom_bytes = {
        [base] = 0x10,
        [base + 1] = 0x81,
        [base + 2] = 29,
        [base + 3] = 29,
        [base + 4] = 0,
    }

    fill_packed_map(rom_bytes, data_start, 30, 30, 0x6)
    set_packed_block(rom_bytes, data_start, 30, 25, 12, 0xF)
    set_packed_block(rom_bytes, data_start, 30, 26, 12, 0xF)
    set_packed_block(rom_bytes, data_start, 30, 27, 12, 0xF)
    set_packed_block(rom_bytes, data_start, 30, 29, 12, 0xF)

    local env = make_env({rom_bytes = rom_bytes})
    local counter = env.map_reader.get_walkability_details(0x0A, 25, 12)
    assert_equal(counter.tile_type, 15, "Cantlin premium merchant counter should decode as type 15")
    assert_equal(counter.effective_walkable, false, "Cantlin (25,12) should stay closed after the same-origin probe from (26,12)->LEFT blocked")

    local inner_bridge = env.map_reader.get_walkability_details(0x0A, 26, 12)
    assert_equal(inner_bridge.tile_type, 15, "Cantlin premium merchant stand should decode as type 15")
    assert_equal(inner_bridge.effective_walkable, true, "Cantlin (26,12) should be walkable after normal-route entry from (27,12)->LEFT")
    assert_equal(inner_bridge.reason, "passthrough", "Cantlin (26,12) should report passthrough")

    local bridge = env.map_reader.get_walkability_details(0x0A, 27, 12)
    assert_equal(bridge.tile_type, 15, "Cantlin premium merchant bridge should decode as type 15")
    assert_equal(bridge.effective_walkable, true, "Cantlin (27,12) should be walkable after live two-sided bridge proof")
    assert_equal(bridge.reason, "passthrough", "Cantlin (27,12) should report passthrough")

    local outer_bridge = env.map_reader.get_walkability_details(0x0A, 29, 12)
    assert_equal(outer_bridge.tile_type, 15, "Cantlin outer premium merchant bridge should decode as type 15")
    assert_equal(outer_bridge.effective_walkable, true, "Cantlin (29,12) should be walkable after live carry-through proof")
    assert_equal(outer_bridge.reason, "passthrough", "Cantlin (29,12) should report passthrough")

    save_module("pathfinder")
    package.loaded["pathfinder"] = nil
    local pathfinder = require "pathfinder"
    local path = pathfinder.find_path(0x0A, 27, 10, 26, 12, {})
    assert_equal(path ~= nil, true, "Cantlin should route to the reachable premium merchant stand")
    assert_equal(path_has_step(path, 27, 12, "south"), true, "Cantlin premium merchant path should cross the outer hidden bridge; path=" .. path_to_string(path))
    assert_equal(path_has_step(path, 26, 12, "west"), true, "Cantlin premium merchant path should finish on the inner hidden stand; path=" .. path_to_string(path))
    local outer_path = pathfinder.find_path(0x0A, 29, 13, 29, 11, {})
    assert_equal(outer_path ~= nil, true, "Cantlin should route through the outer hidden bridge")
    assert_equal(path_has_step(outer_path, 29, 12, "north"), true, "Cantlin outer premium path should cross (29,12); path=" .. path_to_string(outer_path))
    restore_modules({"pathfinder"})

    env.restore()
end



function tests.cantlin_service_route_edges_are_modeled()
    local env = make_env()

    assert_cantlin_dir(env, "1,1", "north", "(1,1).north should block after north-lane verifier from (1,0)->DOWN")
    assert_cantlin_dir(env, "2,1", "north", "(2,1).north should block after north-lane verifier from (2,0)->DOWN")
    assert_cantlin_dir(env, "3,1", "north", "(3,1).north should block after north-lane verifier from (3,0)->DOWN")
    assert_cantlin_dir(env, "6,1", "north", "(6,1).north should block after post-reload normal probe and 3/3 verifier from (6,0)->DOWN")
    assert_cantlin_dir(env, "7,1", "north", "(7,1).north should block after normal probe and north-lane verifier from (7,0)->DOWN")
    assert_cantlin_dir(env, "8,1", "north", "(8,1).north should block after normal probe and north-lane verifier from (8,0)->DOWN")
    assert_cantlin_dir(env, "9,1", "north", "(9,1).north should block after normal probe and north-lane verifier from (9,0)->DOWN")
    assert_cantlin_dir(env, "10,1", "north", "(10,1).north should block after normal probe and north-lane verifier from (10,0)->DOWN")
    assert_cantlin_dir(env, "11,1", "north", "(11,1).north should block after normal probe and north-lane verifier from (11,0)->DOWN")
    assert_cantlin_dir(env, "12,1", "north", "(12,1).north should block after normal probe and north-lane verifier from (12,0)->DOWN")
    assert_cantlin_dir(env, "13,1", "north", "(13,1).north should block after normal probe and north-lane verifier from (13,0)->DOWN")
    assert_cantlin_dir(env, "1,2", "north", "(1,2).north should block after isolated-pocket verifier from (1,1)->DOWN")
    assert_cantlin_dir(env, "2,1", "west", "(2,1).west should block after isolated-pocket verifier from (1,1)->RIGHT")
    assert_cantlin_dir(env, "3,1", "east", "(3,1).east should block after west-descent return failure and raw verifier from (4,1)->LEFT")
    assert_cantlin_dir(env, "3,7", "east", "(3,7).east should block after Tool Merchant 2 route failure and same-origin raw probe from (4,7)->LEFT")
    assert_cantlin_dir(env, "3,8", "south", "(3,8).south should block after Tool Merchant 2 route failure and same-origin raw probe from (3,9)->UP")
    assert_cantlin_dir(env, "1,11", "north", "(1,11).north should block after Merchant 5 route verifier from (1,10)->DOWN")
    assert_cantlin_dir(env, "1,16", "east", "(1,16).east should block after Merchant 5 route verifier from (2,16)->LEFT")
    assert_cantlin_dir(env, "1,17", "east", "(1,17).east should block after Merchant 5 route verifier from (2,17)->LEFT")
    assert_cantlin_dir(env, "1,18", "south", "(1,18).south should block after Merchant 5 route verifier from (1,19)->UP")
    assert_cantlin_dir(env, "2,11", "north", "(2,11).north should block after Merchant 5 route verifier from (2,10)->DOWN")
    assert_cantlin_dir(env, "2,15", "south", "(2,15).south should block after Merchant 5 route verifier from (2,16)->UP")
    assert_cantlin_dir(env, "2,18", "north", "(2,18).north should block after Merchant 5 route verifier from (2,17)->DOWN")
    assert_cantlin_dir(env, "2,18", "south", "(2,18).south should block after Merchant 5 route verifier from (2,19)->UP")
    assert_cantlin_dir(env, "3,11", "east", "(3,11).east should block after Merchant 5 route verifier from (4,11)->LEFT")
    assert_cantlin_dir(env, "3,11", "north", "(3,11).north should block after Merchant 5 route verifier from (3,10)->DOWN")
    assert_cantlin_dir(env, "3,12", "east", "(3,12).east should block after Merchant 5 route verifier from (4,12)->LEFT")
    assert_cantlin_dir(env, "3,13", "east", "(3,13).east should block after Merchant 5 route verifier from (4,13)->LEFT")
    assert_cantlin_dir(env, "3,14", "east", "(3,14).east should block after Merchant 5 route verifier from (4,14)->LEFT")
    assert_cantlin_dir(env, "3,15", "east", "(3,15).east should block after Merchant 5 route verifier from (4,15)->LEFT")
    assert_cantlin_dir(env, "3,15", "south", "(3,15).south should block after Merchant 5 route verifier from (3,16)->UP")
    assert_cantlin_dir(env, "3,18", "north", "(3,18).north should block after Merchant 5 route verifier from (3,17)->DOWN")
    assert_cantlin_dir(env, "3,18", "south", "(3,18).south should block after Merchant 5 route verifier from (3,19)->UP")
    assert_cantlin_dir(env, "4,18", "north", "(4,18).north should block after Merchant 5 route verifier from (4,17)->DOWN")
    assert_cantlin_dir(env, "4,18", "south", "(4,18).south should block after Merchant 5 route verifier from (4,19)->UP")
    assert_cantlin_dir(env, "5,16", "east", "(5,16).east should block after Merchant 5 route verifier from (6,16)->LEFT")
    assert_cantlin_dir(env, "5,16", "south", "(5,16).south should block after Merchant 5 route verifier from (5,17)->UP")
    assert_cantlin_dir(env, "5,16", "west", "(5,16).west should block after Merchant 5 route verifier from (4,16)->RIGHT")
    assert_cantlin_dir(env, "5,18", "north", "(5,18).north should block after Merchant 5 route verifier from (5,17)->DOWN")
    assert_cantlin_dir(env, "5,18", "south", "(5,18).south should block after Merchant 5 route verifier from (5,19)->UP")
    assert_cantlin_dir(env, "5,15", "north", "(5,15).north should block after Merchant 5 route verifier from (5,14)->DOWN")
    assert_cantlin_dir(env, "5,15", "west", "(5,15).west should block after Merchant 5 route verifier from (4,15)->RIGHT")
    assert_cantlin_dir(env, "6,1", "west", "(6,1).west should block after Tool Merchant return-to-entrance verifier from (5,1)->RIGHT")
    assert_cantlin_dir(env, "6,2", "west", "(6,2).west should block after Tool Merchant return-to-entrance verifier from (5,2)->RIGHT")
    assert_cantlin_dir(env, "6,3", "west", "(6,3).west should block after Tool Merchant return-to-entrance verifier from (5,3)->RIGHT")
    assert_cantlin_dir(env, "6,4", "west", "(6,4).west should block after Tool Merchant return-to-entrance verifier from (5,4)->RIGHT")
    assert_cantlin_dir(env, "6,5", "west", "(6,5).west should block after Tool Merchant return-to-entrance verifier from (5,5)->RIGHT")
    assert_cantlin_dir(env, "6,6", "west", "(6,6).west should block after Tool Merchant return-to-entrance verifier from (5,6)->RIGHT")
    assert_cantlin_dir(env, "6,6", "south", "(6,6).south should block after Tool Merchant return-to-entrance verifier from (6,7)->UP")
    assert_cantlin_dir(env, "6,15", "north", "(6,15).north should block after Merchant 5 route verifier from (6,14)->DOWN")
    assert_cantlin_dir(env, "6,15", "south", "(6,15).south should block after Merchant 5 route verifier from (6,16)->UP")
    assert_cantlin_dir(env, "7,7", "west", "(7,7).west should block after Tool Merchant return-to-entrance verifier from (6,7)->RIGHT")
    assert_cantlin_dir(env, "7,7", "south", "(7,7).south should block after Tool Merchant return-to-entrance verifier from (7,8)->UP")
    assert_cantlin_dir(env, "6,18", "north", "(6,18).north should block after Merchant 5 route verifier from (6,17)->DOWN")
    assert_cantlin_dir(env, "6,18", "south", "(6,18).south should block after Merchant 5 route verifier from (6,19)->UP")
    assert_cantlin_dir(env, "6,5", "east", "(6,5).east should block after current Merchant 1 route verifier from (7,5)->LEFT")
    assert_cantlin_dir(env, "6,11", "north", "(6,11).north should block after Merchant 6 route verifier from (6,10)->DOWN")
    assert_cantlin_dir(env, "6,11", "west", "(6,11).west should block after Merchant 6 route verifier from (5,11)->RIGHT")
    assert_cantlin_dir(env, "6,12", "west", "(6,12).west should block after Merchant 6 route verifier from (5,12)->RIGHT")
    assert_cantlin_dir(env, "6,13", "west", "(6,13).west should block after Merchant 6 route verifier from (5,13)->RIGHT")
    assert_cantlin_dir(env, "6,13", "south", "(6,13).south should block after Merchant 6 route verifier from (6,14)->UP")
    assert_cantlin_dir(env, "7,4", "south", "(7,4).south should block after Tool Merchant return-to-entrance verifier from (7,5)->UP")
    assert_cantlin_dir(env, "7,15", "north", "(7,15).north should block after Merchant 5 route verifier from (7,14)->DOWN")
    assert_cantlin_dir(env, "7,15", "south", "(7,15).south should block after Merchant 5 route verifier from (7,16)->UP")
    assert_cantlin_dir(env, "7,18", "north", "(7,18).north should block after Merchant 5 route verifier from (7,17)->DOWN")
    assert_cantlin_dir(env, "7,18", "south", "(7,18).south should block after Merchant 5 route verifier from (7,19)->UP")
    assert_cantlin_dir(env, "7,6", "east", "(7,6).east should block after Tool Merchant return-to-entrance verifier from (8,6)->LEFT")
    assert_cantlin_dir(env, "7,6", "north", "(7,6).north should block after current Merchant 1 route verifier from (7,5)->DOWN")
    assert_cantlin_dir(env, "7,11", "north", "(7,11).north should block after Merchant 6 route verifier from (7,10)->DOWN")
    assert_cantlin_dir(env, "7,11", "west", "(7,11).west should block after Merchant 6 route verifier from (6,11)->RIGHT")
    assert_cantlin_dir(env, "7,13", "south", "(7,13).south should block after Merchant 6 route verifier from (7,14)->UP")
    assert_cantlin_dir(env, "8,4", "south", "(8,4).south should block after Merchant 1 reroute verifier from (8,5)->UP")
    assert_cantlin_dir(env, "8,11", "east", "(8,11).east should block after Merchant 6 route verifier from (9,11)->LEFT")
    assert_cantlin_dir(env, "8,11", "north", "(8,11).north should block after Merchant 5 route verifier from (8,10)->DOWN")
    assert_cantlin_dir(env, "8,12", "east", "(8,12).east should block after Merchant 6 route verifier from (9,12)->LEFT")
    assert_cantlin_dir(env, "8,13", "east", "(8,13).east should block after Merchant 6 route verifier from (9,13)->LEFT")
    assert_cantlin_dir(env, "8,13", "south", "(8,13).south should block after Merchant 6 route verifier from (8,14)->UP")
    assert_cantlin_dir(env, "8,15", "east", "(8,15).east should block after Merchant 5 route verifier from (9,15)->LEFT")
    assert_cantlin_dir(env, "8,15", "north", "(8,15).north should block after Merchant 5 route verifier from (8,14)->DOWN")
    assert_cantlin_dir(env, "8,16", "east", "(8,16).east should block after Merchant 5 route verifier from (9,16)->LEFT")
    assert_cantlin_dir(env, "8,16", "west", "(8,16).west should block after Merchant 5 route verifier from (7,16)->RIGHT")
    assert_cantlin_dir(env, "8,17", "east", "(8,17).east should block after Merchant 5 route verifier from (9,17)->LEFT")
    assert_cantlin_dir(env, "8,17", "west", "(8,17).west should block after Merchant 5 route verifier from (7,17)->RIGHT")
    assert_cantlin_dir(env, "8,18", "east", "(8,18).east should block after Merchant 5 route verifier from (9,18)->LEFT")
    assert_cantlin_dir(env, "8,18", "south", "(8,18).south should block after Merchant 5 route verifier from (8,19)->UP")
    assert_cantlin_dir(env, "8,24", "south", "(8,24).south should block after open-door return verifier from (8,25)->UP")
    assert_cantlin_dir(env, "10,25", "west", "(10,25).west should block after open-door return verifier from (9,25)->RIGHT")
    assert_cantlin_dir(env, "9,2", "east", "(9,2).east should block after Tool Merchant return-to-entrance verifier from (10,2)->LEFT")
    assert_cantlin_dir(env, "9,3", "east", "(9,3).east should block after Tool Merchant return-to-entrance verifier from (10,3)->LEFT")
    assert_cantlin_dir(env, "9,4", "east", "(9,4).east should block after Tool Merchant return-to-entrance verifier from (10,4)->LEFT")
    assert_cantlin_dir(env, "9,4", "south", "(9,4).south should block after Tool Merchant return-to-entrance verifier from (9,5)->UP")
    assert_cantlin_dir(env, "9,6", "north", "(9,6).north should block after Merchant 1 route verifier from (9,5)->DOWN")
    assert_cantlin_dir(env, "9,6", "south", "(9,6).south should block after Merchant 1 reroute verifier from (9,7)->UP")
    assert_cantlin_dir(env, "9,6", "west", "(9,6).west should block after Tool Merchant return-to-entrance verifier from (8,6)->RIGHT")
    assert_cantlin_dir(env, "10,1", "south", "(10,1).south should block after Tool Merchant return-to-entrance verifier from (10,2)->UP")
    assert_cantlin_dir(env, "10,6", "east", "(10,6).east should block after Tool Merchant return-to-entrance verifier from (11,6)->LEFT")
    assert_cantlin_dir(env, "10,6", "north", "(10,6).north should block after Tool Merchant return-to-entrance verifier from (10,5)->DOWN")
    assert_cantlin_dir(env, "10,7", "east", "(10,7).east should block after Tool Merchant return-to-entrance verifier from (11,7)->LEFT")
    assert_cantlin_dir(env, "10,7", "west", "(10,7).west should block after Merchant 1 reroute verifier from (9,7)->RIGHT")
    assert_cantlin_dir(env, "10,8", "south", "(10,8).south should block after Merchant 1 reroute verifier from (10,9)->UP")
    assert_cantlin_dir(env, "10,8", "west", "(10,8).west should block after Merchant 1 reroute verifier from (9,8)->RIGHT")
    assert_cantlin_dir(env, "11,1", "south", "(11,1).south should block after Tool Merchant return-to-entrance verifier from (11,2)->UP")
    assert_cantlin_dir(env, "11,4", "north", "(11,4).north should block after Tool Merchant return-to-entrance verifier from (11,3)->DOWN")
    assert_cantlin_dir(env, "11,4", "south", "(11,4).south should block after Merchant 1 stand verifier from (11,5)->UP")
    assert_cantlin_dir(env, "11,4", "west", "(11,4).west should block after Tool Merchant return-to-entrance verifier from (10,4)->RIGHT")
    assert_cantlin_dir(env, "11,8", "north", "(11,8).north should block after Tool Merchant return-to-entrance verifier from (11,7)->DOWN")
    assert_cantlin_dir(env, "11,8", "south", "(11,8).south should block after Merchant 1 route verifier from (11,9)->UP")
    assert_cantlin_dir(env, "11,13", "south", "(11,13).south should block after Merchant 7 return verifier from (11,14)->UP")
    assert_cantlin_dir(env, "12,1", "south", "(12,1).south should block after Tool Merchant return-to-entrance verifier from (12,2)->UP")
    assert_cantlin_dir(env, "12,4", "north", "(12,4).north should block after Tool Merchant return-to-entrance verifier from (12,3)->DOWN")
    assert_cantlin_dir(env, "12,4", "south", "(12,4).south should block after Tool Merchant return-to-entrance verifier from (12,5)->UP")
    assert_cantlin_dir(env, "12,8", "north", "(12,8).north should block after Tool Merchant return-to-entrance verifier from (12,7)->DOWN")
    assert_cantlin_dir(env, "12,8", "south", "(12,8).south should block after Merchant 1 reroute verifier from (12,9)->UP")
    assert_cantlin_dir(env, "12,14", "south", "(12,14).south should block after Merchant 7 return verifier from (12,15)->UP")
    assert_cantlin_dir(env, "12,14", "west", "(12,14).west should block after Merchant 7 return verifier from (11,14)->RIGHT")
    assert_cantlin_dir(env, "12,27", "north", "(12,27).north should block after the lower barrier route verifier from (12,26)->DOWN")
    assert_cantlin_dir(env, "13,1", "east", "(13,1).east should block after entrance-to-Inn verifier from (14,1)->LEFT")
    assert_cantlin_dir(env, "13,2", "east", "(13,2).east should block after entrance-to-Inn verifier from (14,2)->LEFT")
    assert_cantlin_dir(env, "13,2", "west", "(13,2).west should block after Tool Merchant return-to-entrance verifier from (12,2)->RIGHT")
    assert_cantlin_dir(env, "13,3", "east", "(13,3).east should block after entrance-to-Inn verifier from (14,3)->LEFT")
    assert_cantlin_dir(env, "13,3", "west", "(13,3).west should block after Tool Merchant return-to-entrance verifier from (12,3)->RIGHT")
    assert_cantlin_dir(env, "13,4", "east", "(13,4).east should block after entrance-to-Inn verifier from (14,4)->LEFT")
    assert_cantlin_dir(env, "13,5", "east", "(13,5).east should block after entrance-to-Inn verifier from (14,5)->LEFT")
    assert_cantlin_dir(env, "13,5", "west", "(13,5).west should block after Tool Merchant return-to-entrance verifier from (12,5)->RIGHT")
    assert_cantlin_dir(env, "13,6", "east", "(13,6).east should block after entrance-to-Inn verifier from (14,6)->LEFT")
    assert_cantlin_dir(env, "13,6", "west", "(13,6).west should block after Tool Merchant return-to-entrance verifier from (12,6)->RIGHT")
    assert_cantlin_dir(env, "13,7", "east", "(13,7).east should block after entrance-to-Inn verifier from (14,7)->LEFT")
    assert_cantlin_dir(env, "13,7", "west", "(13,7).west should block after Tool Merchant return-to-entrance verifier from (12,7)->RIGHT")
    assert_cantlin_dir(env, "13,8", "east", "(13,8).east should block after entrance-to-Inn verifier from (14,8)->LEFT")
    assert_cantlin_dir(env, "13,8", "south", "(13,8).south should block after restored-state entrance verifier from (13,9)->UP")
    assert_cantlin_dir(env, "13,14", "south", "(13,14).south should block after Merchant 7 return verifier from (13,15)->UP")
    assert_cantlin_dir(env, "14,11", "east", "(14,11).east should block after Merchant 6 route verifier from (15,11)->LEFT")
    assert_cantlin_dir(env, "14,14", "south", "(14,14).south should block after Merchant 7 return verifier from (14,15)->UP")
    assert_cantlin_dir(env, "15,12", "north", "(15,12).north should block after Merchant 6 route verifier from (15,11)->DOWN")
    assert_cantlin_dir(env, "15,12", "east", "(15,12).east should block after Fairy Water return route and same-origin raw probe from (16,12)->LEFT")
    assert_cantlin_dir(env, "15,13", "south", "(15,13).south should block after Merchant 7 return verifier from (15,14)->UP")
    assert_cantlin_dir(env, "16,13", "east", "(16,13).east should block after Fairy Water Merchant return route and same-origin raw probe from (17,13)->LEFT")
    assert_cantlin_dir(env, "16,1", "west", "(16,1).west should block after Merchant 2 route verifier from (15,1)->RIGHT")
    assert_cantlin_dir(env, "16,1", "east", "(16,1).east should block after entrance return verifier from (17,1)->LEFT")
    assert_cantlin_dir(env, "16,1", "south", "(16,1).south should block after Inn return failure and same-origin verifier from (16,2)->UP")
    assert_cantlin_dir(env, "16,14", "west", "(16,14).west should block after Merchant 7 return verifier from (15,14)->RIGHT")
    assert_cantlin_dir(env, "17,14", "north", "(17,14).north should block after Merchant 7 forward verifier from (17,13)->DOWN")
    assert_cantlin_dir(env, "17,24", "east", "(17,24).east should block after exit-route verifier from (18,24)->LEFT")
    assert_cantlin_dir(env, "17,24", "north", "(17,24).north should block after exit-route verifier from (17,23)->DOWN")
    assert_cantlin_dir(env, "17,21", "south", "(17,21).south should block after entrance-route verifier from (17,22)->UP")
    assert_cantlin_dir(env, "17,21", "east", "(17,21).east should block after entrance-route verifier from (18,21)->LEFT")
    assert_cantlin_dir(env, "18,20", "south", "(18,20).south should block after entrance-route verifier from (18,21)->UP")
    assert_cantlin_dir(env, "19,25", "east", "(19,25).east should block after Merchant 7 return verifier from (20,25)->LEFT")
    assert_cantlin_dir(env, "19,25", "north", "(19,25).north should block after exit-route verifier from (19,24)->DOWN")
    assert_cantlin_dir(env, "19,28", "east", "(19,28).east should block after exit-route verifier from (20,28)->LEFT")
    assert_cantlin_dir(env, "16,14", "south", "(16,14).south should block after Merchant 7 return verifier from (16,15)->UP")
    assert_cantlin_dir(env, "20,2", "north", "(20,2).north should block after Merchant 2 route verifier from (20,1)->DOWN")
    assert_cantlin_dir(env, "20,2", "south", "(20,2).south should block after Merchant 2 route verifier from (20,3)->UP")
    assert_cantlin_dir(env, "19,2", "north", "(19,2).north should block after Merchant 2 route verifier from (19,1)->DOWN")
    assert_cantlin_dir(env, "19,2", "south", "(19,2).south should block after Merchant 2 route verifier from (19,3)->UP")
    assert_cantlin_dir(env, "21,2", "north", "(21,2).north should block after Merchant 2 route verifier from (21,1)->DOWN")
    assert_cantlin_dir(env, "22,2", "north", "(22,2).north should block after Merchant 2 route verifier from (22,1)->DOWN")
    assert_cantlin_dir(env, "23,2", "north", "(23,2).north should block after Merchant 2 route verifier from (23,1)->DOWN")
    assert_cantlin_dir(env, "23,2", "east", "(23,2).east should block after Merchant 2 route verifier from (24,2)->LEFT")
    assert_cantlin_dir(env, "23,3", "east", "(23,3).east should block after Merchant 2 route verifier from (24,3)->LEFT")
    assert_cantlin_dir(env, "20,29", "north", "(20,29).north should guard the south-edge world-map transition from ordinary in-town routing")
    assert_cantlin_dir(env, "21,3", "west", "(21,3).west should block after Merchant 2 route verifier from (20,3)->RIGHT")
    assert_cantlin_dir(env, "21,4", "west", "(21,4).west should block after Merchant 2 route verifier from (20,4)->RIGHT")
    assert_cantlin_dir(env, "21,5", "west", "(21,5).west should block after Merchant 2 route verifier from (20,5)->RIGHT")
    assert_cantlin_dir(env, "21,11", "west", "(21,11).west should block after Merchant 7 reverse verifier from (20,11)->RIGHT")
    assert_cantlin_dir(env, "21,11", "north", "(21,11).north should block after Merchant 7 reverse verifier from (21,10)->DOWN")
    assert_cantlin_dir(env, "21,12", "west", "(21,12).west should block after premium merchant forward failure and same-origin probe from (20,12)->RIGHT")
    assert_cantlin_dir(env, "21,21", "west", "(21,21).west should block after Merchant 7 reverse verifier from (20,21)->RIGHT")
    assert_cantlin_dir(env, "21,21", "north", "(21,21).north should block after Merchant 7 forward verifier from (21,20)->DOWN")
    assert_cantlin_dir(env, "21,13", "west", "(21,13).west should block after Merchant 7 forward verifier from (20,13)->RIGHT")
    assert_cantlin_dir(env, "21,14", "west", "(21,14).west should block after premium merchant forward failure and same-origin probe from (20,14)->RIGHT")
    assert_cantlin_dir(env, "21,26", "west", "(21,26).west should block after Merchant 7 reverse verifier from (20,26)->RIGHT")
    assert_cantlin_dir(env, "21,26", "east", "(21,26).east should block after Merchant 7 return verifier from (22,26)->LEFT")
    assert_cantlin_dir(env, "21,27", "west", "(21,27).west should block after Merchant 7 reverse verifier from (20,27)->RIGHT")
    assert_cantlin_dir(env, "21,27", "east", "(21,27).east should block after service return verifier from (22,27)->LEFT")
    assert_cantlin_dir(env, "21,28", "west", "(21,28).west should block after Merchant 7 reverse verifier from (20,28)->RIGHT")
    assert_cantlin_dir(env, "21,6", "west", "(21,6).west should block after Merchant 2 route verifier from (20,6)->RIGHT")
    assert_cantlin_dir(env, "23,4", "east", "(23,4).east should block after Merchant 2 route verifier from (24,4)->LEFT")
    assert_cantlin_dir(env, "23,5", "east", "(23,5).east should block after Merchant 2 route verifier from (24,5)->LEFT")
    assert_cantlin_dir(env, "23,6", "east", "(23,6).east should block after Merchant 2 route verifier from (24,6)->LEFT")
    assert_cantlin_dir(env, "23,7", "east", "(23,7).east should block after Merchant 2 route verifier from (24,7)->LEFT")
    assert_cantlin_dir(env, "22,7", "south", "(22,7).south should block after Merchant 2 route verifier from (22,8)->UP")
    assert_cantlin_dir(env, "23,7", "south", "(23,7).south should block after Merchant 2 route verifier from (23,8)->UP")
    assert_cantlin_dir(env, "23,11", "north", "(23,11).north should block after Merchant 7 reverse verifier from (23,10)->DOWN")
    assert_cantlin_dir(env, "23,14", "south", "(23,14).south should block after premium merchant forward failure and same-origin probe from (23,15)->UP")
    assert_cantlin_dir(env, "22,11", "north", "(22,11).north should block after Merchant 7 reverse verifier from (22,10)->DOWN")
    assert_cantlin_dir(env, "22,21", "north", "(22,21).north should block after Merchant 7 forward verifier from (22,20)->DOWN")
    assert_cantlin_dir(env, "23,21", "east", "(23,21).east should block after Merchant 7 route verifier from (24,21)->LEFT")
    assert_cantlin_dir(env, "23,21", "north", "(23,21).north should block after Merchant 7 forward verifier from (23,20)->DOWN")
    assert_cantlin_dir(env, "23,25", "east", "(23,25).east should block after Merchant 7 return verifier from (24,25)->LEFT")
    assert_cantlin_dir(env, "23,27", "east", "(23,27).east should block after corrected exit-route verifier from (24,27)->LEFT")
    assert_cantlin_dir(env, "23,27", "west", "(23,27).west should block after corrected exit-route verifier from (22,27)->RIGHT")
    assert_cantlin_dir(env, "23,27", "north", "(23,27).north should block after fixed Weapons Merchant return verifier from (23,26)->DOWN")
    assert_cantlin_dir(env, "24,28", "north", "(24,28).north should block after corrected exit-route verifier from (24,27)->DOWN")
    assert_cantlin_dir(env, "22,28", "north", "(22,28).north should block after corrected exit-route verifier from (22,27)->DOWN")
    assert_cantlin_dir(env, "23,23", "east", "(23,23).east should block after Merchant 7 return verifier from (24,23)->LEFT")
    assert_cantlin_dir(env, "23,13", "east", "(23,13).east should block after premium merchant stand egress failure and same-origin probe from (24,13)->LEFT")
    assert_cantlin_dir(env, "24,14", "north", "(24,14).north should block after premium merchant outer-route failure and same-origin probe from (24,13)->DOWN")
    assert_cantlin_dir(env, "24,14", "south", "(24,14).south should block after Merchant 7 return verifier from (24,15)->UP")
    assert_cantlin_dir(env, "24,11", "north", "(24,11).north should block after premium merchant forward failure and same-origin probe from (24,10)->DOWN")
    assert_cantlin_dir(env, "21,14", "south", "(21,14).south should block after premium merchant forward failure and same-origin probe from (21,15)->UP")
    assert_cantlin_dir(env, "22,14", "south", "(22,14).south should block after premium merchant forward failure and same-origin probe from (22,15)->UP")
    assert_cantlin_dir(env, "25,14", "south", "(25,14).south should block after premium merchant forward failure and same-origin probe from (25,15)->UP")
    assert_cantlin_dir(env, "26,14", "north", "(26,14).north should block after premium merchant stand failure and same-origin probe from (26,13)->DOWN")
    assert_cantlin_dir(env, "26,14", "south", "(26,14).south should block after premium merchant forward failure and same-origin probe from (26,15)->UP")
    assert_cantlin_dir(env, "25,10", "north", "(25,10).north should block after premium merchant forward failure and same-origin probe from (25,9)->DOWN")
    assert_cantlin_dir(env, "25,10", "west", "(25,10).west should block after premium merchant forward failure and same-origin probe from (24,10)->RIGHT")
    assert_cantlin_dir(env, "25,13", "east", "(25,13).east should block after premium merchant stand failure and same-origin probe from (26,13)->LEFT")
    assert_cantlin_dir(env, "25,13", "west", "(25,13).west should block after premium merchant outer-route failure and same-origin probe from (24,13)->RIGHT")
    assert_cantlin_dir(env, "25,11", "east", "(25,11).east should block after premium merchant return failure and same-origin probe from (26,11)->LEFT")
    assert_cantlin_dir(env, "26,2", "east", "(26,2).east should block after the key-merchant return failure and same-origin raw probe from (27,2)->LEFT")
    assert_cantlin_dir(env, "26,3", "east", "(26,3).east should block after the key-merchant return failure and same-origin raw probe from (27,3)->LEFT")
    assert_cantlin_dir(env, "26,5", "north", "(26,5).north should block after premium merchant east-lane descent failure and same-origin probe from (26,4)->DOWN")
    assert_cantlin_dir(env, "26,5", "west", "(26,5).west should block after premium merchant outer-route failure and same-origin probe from (25,5)->RIGHT")
    assert_cantlin_dir(env, "26,6", "west", "(26,6).west should block after premium merchant outer-route failure and same-origin probe from (25,6)->RIGHT")
    assert_cantlin_dir(env, "26,7", "west", "(26,7).west should block after premium merchant outer-route failure and same-origin probe from (25,7)->RIGHT")
    assert_cantlin_dir(env, "26,8", "east", "(26,8).east should block after premium merchant return failure and same-origin probe from (27,8)->LEFT")
    assert_cantlin_dir(env, "26,8", "south", "(26,8).south should block after premium merchant outer-route failure and same-origin probe from (26,9)->UP")
    assert_cantlin_dir(env, "26,8", "west", "(26,8).west should block after premium merchant outer-route failure and same-origin probe from (25,8)->RIGHT")
    assert_cantlin_dir(env, "26,10", "east", "(26,10).east should block after premium merchant forward failure and same-origin probe from (27,10)->LEFT")
    assert_cantlin_dir(env, "26,10", "north", "(26,10).north should block after premium merchant forward failure and same-origin probe from (26,9)->DOWN")
    assert_cantlin_dir(env, "26,10", "south", "(26,10).south should block after premium merchant return failure and same-origin probe from (26,11)->UP")
    assert_cantlin_dir(env, "27,1", "south", "(27,1).south should block after the closed-door key-merchant return and same-origin raw probe from (27,2)->UP")
    assert_cantlin_dir(env, "27,5", "north", "(27,5).north should block after the closed-door key-merchant route and same-origin raw probe from (27,4)->DOWN")
    assert_cantlin_dir(env, "27,14", "north", "(27,14).north should block after premium merchant stand failure and same-origin probe from (27,13)->DOWN")
    assert_cantlin_dir(env, "27,7", "south", "(27,7).south should block after premium merchant return failure and same-origin probe from (27,8)->UP")
    assert_cantlin_dir(env, "27,14", "south", "(27,14).south should block after premium merchant forward failure and same-origin probe from (27,15)->UP")
    assert_cantlin_dir(env, "28,2", "west", "(28,2).west should block after the closed-door key-merchant return and same-origin raw probe from (27,2)->RIGHT")
    assert_cantlin_dir(env, "28,5", "north", "(28,5).north should block after premium merchant east-lane descent failure and same-origin probe from (28,4)->DOWN")
    assert_cantlin_dir(env, "28,5", "east", "(28,5).east should block after premium merchant outer-lane failure and same-origin probe from (29,5)->LEFT")
    assert_cantlin_dir(env, "28,6", "east", "(28,6).east should block after premium merchant outer-lane failure and same-origin probe from (29,6)->LEFT")
    assert_cantlin_dir(env, "28,7", "east", "(28,7).east should block after premium merchant outer-lane failure and same-origin probe from (29,7)->LEFT")
    assert_cantlin_dir(env, "28,8", "east", "(28,8).east should block after premium merchant outer-lane failure and same-origin probe from (29,8)->LEFT")
    assert_cantlin_dir(env, "28,8", "west", "(28,8).west should block after premium merchant return failure and same-origin probe from (27,8)->RIGHT")
    assert_cantlin_dir(env, "28,9", "east", "(28,9).east should block after premium merchant outer-lane failure and same-origin probe from (29,9)->LEFT")
    assert_cantlin_dir(env, "28,9", "west", "(28,9).west should block after premium merchant outer-route failure and same-origin probe from (27,9)->RIGHT")
    assert_cantlin_dir(env, "28,10", "east", "(28,10).east should block after premium merchant outer-lane failure and same-origin probe from (29,10)->LEFT")
    assert_cantlin_dir(env, "28,10", "west", "(28,10).west should block after premium merchant outer-route failure and same-origin probe from (27,10)->RIGHT")
    assert_cantlin_dir(env, "28,11", "east", "(28,11).east should block after premium merchant outer-lane failure and same-origin probe from (29,11)->LEFT")
    assert_cantlin_dir(env, "28,11", "west", "(28,11).west should block after premium merchant bridge failure and same-origin probe from (27,11)->RIGHT")
    assert_cantlin_dir(env, "28,13", "east", "(28,13).east should block after premium merchant forward failure and same-origin probe from (29,13)->LEFT")
    assert_cantlin_dir(env, "28,13", "west", "(28,13).west should block after premium merchant stand failure and same-origin probe from (27,13)->RIGHT")
    assert_cantlin_dir(env, "28,14", "south", "(28,14).south should block after premium merchant forward failure and same-origin probe from (28,15)->UP")
    assert_cantlin_dir(env, "28,14", "east", "(28,14).east should block after premium merchant forward failure and same-origin probe from (29,14)->LEFT")
    assert_cantlin_dir(env, "24,22", "north", "(24,22).north should block after Merchant 7 route verifier from (24,21)->DOWN")
    assert_cantlin_dir(env, "24,22", "south", "(24,22).south should block after Merchant 7 return verifier from (24,23)->UP")
    assert_cantlin_dir(env, "24,24", "north", "(24,24).north should block after Merchant 7 return verifier from (24,23)->DOWN")
    assert_cantlin_dir(env, "24,24", "east", "(24,24).east should block after Merchant 7 return verifier from (25,24)->LEFT")
    assert_cantlin_dir(env, "25,22", "north", "(25,22).north should block after Merchant 7 route verifier from (25,21)->DOWN")
    assert_cantlin_dir(env, "25,22", "south", "(25,22).south should block after Merchant 7 return verifier from (25,23)->UP")
    assert_cantlin_dir(env, "26,22", "north", "(26,22).north should block after Merchant 7 route verifier from (26,21)->DOWN")
    assert_cantlin_dir(env, "26,22", "south", "(26,22).south should block after Merchant 7 return verifier from (26,23)->UP")
    assert_cantlin_dir(env, "27,20", "south", "(27,20).south should block after Merchant 7 return verifier from (27,21)->UP")
    assert_cantlin_dir(env, "27,24", "north", "(27,24).north should block after Merchant 7 route verifier from (27,23)->DOWN")
    assert_cantlin_dir(env, "21,7", "south", "(21,7).south should block after Merchant 2 route verifier from (21,8)->UP")
    assert_cantlin_dir(env, "20,7", "south", "(20,7).south should block after Merchant 2 route verifier from (20,8)->UP")
    assert_cantlin_dir(env, "19,7", "north", "(19,7).north should block after Merchant 2 route verifier from (19,6)->DOWN")
    assert_cantlin_dir(env, "19,7", "south", "(19,7).south should block after Merchant 2 route verifier from (19,8)->UP")
    assert_cantlin_dir(env, "18,7", "south", "(18,7).south should block after Merchant 2 route verifier from (18,8)->UP")
    assert_cantlin_dir(env, "18,7", "west", "(18,7).west should block after Merchant 2 route verifier from (17,7)->RIGHT")
    assert_cantlin_dir(env, "20,7", "north", "(20,7).north should block after Merchant 2 route verifier from (20,6)->DOWN")
    assert_cantlin_dir(env, "18,2", "west", "(18,2).west should block after Merchant 2 route verifier from (17,2)->RIGHT")
    assert_cantlin_dir(env, "18,2", "north", "(18,2).north should block after Merchant 2 route verifier from (18,1)->DOWN")
    assert_cantlin_dir(env, "18,3", "east", "(18,3).east should block after Merchant 2 route verifier from (19,3)->LEFT")
    assert_cantlin_dir(env, "18,3", "south", "(18,3).south should block after Merchant 2 route verifier from (18,4)->UP")
    assert_cantlin_dir(env, "18,3", "west", "(18,3).west should block after Merchant 2 route verifier from (17,3)->RIGHT")
    assert_cantlin_dir(env, "18,6", "east", "(18,6).east should block after Merchant 2 route verifier from (19,6)->LEFT")
    assert_cantlin_dir(env, "18,6", "north", "(18,6).north should block after Merchant 2 route verifier from (18,5)->DOWN")
    assert_cantlin_dir(env, "18,6", "west", "(18,6).west should block after Merchant 2 route verifier from (17,6)->RIGHT")

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
    assert_equal(env.map_reader.get_raw_block_id(0, 0, 1), 0x09, "the next row should continue at the next linear packed tile")
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
    fill_packed_map(rom_bytes, data_start, 30, 30, 0x4)

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

function tests.cantlin_barrier_tiles_are_modeled_as_hazards()
    local env = make_env()
    local expected_hazards = {
        {x = 11, y = 26}, {x = 12, y = 26}, {x = 13, y = 26}, {x = 14, y = 26},
        {x = 15, y = 26}, {x = 16, y = 26}, {x = 17, y = 26}, {x = 18, y = 26},
        {x = 11, y = 27}, {x = 18, y = 27},
        {x = 11, y = 28}, {x = 12, y = 28}, {x = 13, y = 28},
        {x = 16, y = 28}, {x = 17, y = 28}, {x = 18, y = 28},
    }

    for _, cell in ipairs(expected_hazards) do
        local label = string.format("Cantlin (%d,%d)", cell.x, cell.y)
        assert_equal(env.map_reader.is_hazard_cell(0x0A, cell.x, cell.y), "damage", label .. " should be tracked as a damage hazard")
        local details = env.map_reader.get_walkability_details(0x0A, cell.x, cell.y)
        assert_equal(details.hazard, "damage", label .. " should report the hazard type")
        assert_equal(details.effective_walkable, false, label .. " should be forbidden for normal pathfinding")
        assert_equal(details.reason, "hazard", label .. " should report hazard rather than a wall")
    end

    assert_equal(env.map_reader.is_hazard_cell(0x0A, 12, 25), false, "the safe tile north of the barrier should remain non-hazardous")

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
    assert_tantegel_dir(env, "19,6", "west", "(19,6) west approach should block after 2026-06-25 throne-stairs-to-merchant route plus same-origin probe from (18,6)->RIGHT")
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

function tests.tantegel_castle_magic_key_merchant_to_throne_stairs_false_cuts_are_modeled()
    -- Confirmed 2026-06-25 while routing from the downstairs Magic Key
    -- merchant back to the throne-room stairs. With this runtime overlay,
    -- auto_walk_blocker reached the stairs at (7,7) through the long west detour.
    local env = make_env()
    assert_tantegel_dir(env, "22,6", "north", "(22,6).north should block after same-origin probe from (22,5)->DOWN")
    assert_tantegel_dir(env, "21,5", "east", "(21,5).east should block after route failure from (22,5)->LEFT")
    assert_tantegel_dir(env, "21,4", "east", "(21,4).east should block after route failure from (22,4)->LEFT")
    assert_tantegel_dir(env, "23,6", "north", "(23,6).north should block after route failure from (23,5)->DOWN")
    assert_tantegel_dir(env, "23,9", "north", "(23,9).north should block after route failure from (23,8)->DOWN")
    assert_tantegel_dir(env, "24,9", "east", "(24,9).east should block after route failure from (25,9)->LEFT")
    assert_tantegel_dir(env, "24,10", "east", "(24,10).east should block after route failure from (25,10)->LEFT")
    assert_tantegel_dir(env, "25,6", "south", "(25,6).south should block after route failure from (25,7)->UP")
    assert_tantegel_dir(env, "17,6", "south", "(17,6).south should block after route failure from (17,7)->UP")
    assert_tantegel_dir(env, "15,5", "east", "(15,5).east should block after route failure from (16,5)->LEFT")
    env.restore()
end

function tests.tantegel_castle_throne_stairs_to_magic_key_merchant_false_cuts_are_modeled()
    -- Confirmed 2026-06-25 while returning from the throne-room stairs to the
    -- downstairs Magic Key merchant. With both runtime blocks active,
    -- auto_walk_blocker reached the merchant stand at (24,3).
    local env = make_env()
    assert_tantegel_dir(env, "13,9", "west", "(13,9).west should block after route failure and same-origin probe from (12,9)->RIGHT")
    assert_tantegel_dir(env, "19,6", "west", "(19,6).west should block after route failure and same-origin probe from (18,6)->RIGHT")
    env.restore()
end

function tests.tantegel_castle_magic_key_merchant_to_main_entrance_false_cuts_are_modeled()
    -- Confirmed 2026-06-25 while routing between the downstairs Magic Key
    -- merchant and the main castle entrance. With this runtime overlay,
    -- auto_walk_blocker reached the exit stand at (11,29) and returned to
    -- the merchant stand at (24,3).
    local env = make_env()
    assert_tantegel_dir(env, "18,14", "north", "(18,14).north should block after route failure and same-origin probes from (18,13)->DOWN")
    assert_tantegel_dir(env, "18,15", "west", "(18,15).west should block after route failure and same-origin probe from (17,15)->RIGHT")
    assert_tantegel_dir(env, "23,6", "east", "(23,6).east should block after route failure and same-origin probe from (24,6)->LEFT")
    assert_tantegel_dir(env, "25,6", "north", "(25,6).north should block after route failure and same-origin probe from (25,5)->DOWN")
    assert_tantegel_dir(env, "25,6", "west", "(25,6).west should block after route failure and same-origin probe from (24,6)->RIGHT")
    assert_tantegel_dir(env, "26,6", "north", "(26,6).north should block after route failure and same-origin probe from (26,5)->DOWN")
    assert_tantegel_dir(env, "26,6", "south", "(26,6).south should block after route failure and same-origin probe from (26,7)->UP")
    assert_tantegel_dir(env, "27,6", "east", "(27,6).east should block after route failure and same-origin probe from (28,6)->LEFT")
    assert_tantegel_dir(env, "27,7", "east", "(27,7).east should block after route failure and same-origin probe from (28,7)->LEFT")
    assert_tantegel_dir(env, "27,7", "west", "(27,7).west should block after route failure and same-origin probe from (26,7)->RIGHT")
    assert_tantegel_dir(env, "28,24", "east", "(28,24).east should block after route failure and same-origin probe from (29,24)->LEFT")
    assert_tantegel_dir(env, "28,25", "east", "(28,25).east should block after route failure and same-origin probe from (29,25)->LEFT")
    assert_tantegel_dir(env, "28,26", "east", "(28,26).east should block after route failure and same-origin probe from (29,26)->LEFT")
    assert_tantegel_dir(env, "28,27", "east", "(28,27).east should block after route failure and same-origin probe from (29,27)->LEFT")
    assert_tantegel_dir(env, "28,28", "east", "(28,28).east should block after route failure and same-origin probe from (29,28)->LEFT")
    assert_tantegel_dir(env, "23,2", "south", "(23,2).south should block after route churn and same-origin probe from (23,3)->UP")
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
    assert_tantegel_dir(env, "13,9", "west", "(13,9) west approach should block after 2026-06-25 route and same-origin probe from (12,9)->RIGHT")
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
    for _, cell in ipairs({"27,9", "27,10", "27,12", "27,13", "27,14", "27,15", "27,16", "27,17", "27,18", "27,19"}) do
        assert_tantegel_dir(env, cell, "east", cell .. " east approach should block after Sun Shrine stairs return-route same-origin LEFT probes from x=28")
    end
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
    assert_tantegel_dir(env, "27,17", "east", "(27,17).east should block after 2026-06-25 Sun Shrine return-route same-origin probe from (28,17)->LEFT")
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
    assert_tantegel_dir(env, "25,6", "north", "(25,6) north approach should now block after the 2026-06-25 merchant-to-main-entrance route failed from (25,5)->DOWN")
    assert_tantegel_dir(env, "25,6", "south", "(25,6) south approach should now block after the 2026-06-25 merchant-to-stairs route failed from (25,7)->UP")
    assert_tantegel_dir(env, "25,6", "west", "(25,6) west approach should now block after the 2026-06-25 merchant-to-main-entrance route failed from (24,6)->RIGHT")
    assert_tantegel_dir(env, "26,6", "north", "(26,6) north approach should now block after the 2026-06-25 merchant-to-main-entrance route failed from (26,5)->DOWN")
    assert_tantegel_dir(env, "26,6", "south", "(26,6) south approach should now block after the 2026-06-25 merchant-to-main-entrance route failed from (26,7)->UP")
    assert_tantegel_dir(env, "27,7", "west", "(27,7) west approach should now block after the 2026-06-25 merchant-to-main-entrance route failed from (26,7)->RIGHT")
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
    assert_equal(dirs["20,3"].east, true, "(20,3) should block east approach after Fairy Water route/manual blocks from (21,3)")
    assert_equal(dirs["20,5"].east, true, "(20,5) should block east approach after Fairy Water route blocks from (21,5)")
    assert_equal(dirs["21,2"].south, true, "(21,2) should block south approach after Fairy Water route blocks from (21,3)")
    assert_equal(dirs["22,2"].south, true, "(22,2) should block south approach after Fairy Water route blocks from (22,3)")
    assert_equal(dirs["23,3"].west, true, "(23,3) should block west approach after repeated Fairy Water pocket blocks from (22,3)")
    assert_equal(dirs["23,4"].west, true, "(23,4) should block west approach after Fairy Water route blocks from (22,4)")
    assert_equal(dirs["23,5"].west, true, "(23,5) should block west approach after repeated Fairy Water pocket blocks from (22,5)")
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
    assert_equal(dirs["7,21"] and dirs["7,21"].west or nil, nil, "(7,21).west should stay open after walked same-origin probe from (6,21)->RIGHT")
    assert_equal(dirs["8,17"].west, true, "(8,17) should block west approach after inn route timeout from (7,17)")
    assert_equal(dirs["8,22"].north, true, "(8,22) should block north approach")
    assert_equal(dirs["8,22"].south, true, "(8,22) should block south approach after restored-route autowalk and same-origin probe from (8,23)->UP")
    assert_equal(dirs["9,20"].west, true, "(9,20) should block west approach")
    assert_equal(dirs["9,21"].west, true, "(9,21) should block west approach")
    assert_equal(dirs["9,22"].south, true, "(9,22) should block south approach")
    assert_equal(dirs["10,22"].south, true, "(10,22) should block south approach")
    assert_equal(dirs["8,24"].east, true, "(8,24) should block east approach")
    assert_equal(dirs["8,24"].north, true, "(8,24) should block north approach")
    assert_equal(dirs["2,23"] and dirs["2,23"].east or nil, true, "(2,23) should block east approach after same-origin probe from (3,23) west")
    assert_equal(dirs["5,23"] and dirs["5,23"].east or nil, nil, "(5,23).east is the opened Brecconary inn door approach, not a permanent wall")
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
    local data_start = 0x1010
    local rom_bytes = {
        [base] = 0x00,
        [base + 1] = 0x90,
        [base + 2] = 19,
        [base + 3] = 19,
        [base + 4] = 0,
    }
    fill_packed_map(rom_bytes, data_start, 20, 20, 0x2)

    local env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = {
            [0] = 0x10,
        },
    })

    local dirs = env.map_reader.get_directional_blocks(0x09)
    local function assert_blocked_approach(cell, approach, message)
        assert_equal(dirs[cell] and dirs[cell][approach], true, message)
    end
    local function assert_open_approach(cell, approach, message)
        local entry = dirs[cell]
        assert_equal(entry and entry[approach] or nil, nil, message)
    end

    assert_equal(dirs["3,12"].north, true, "(3,12) should block north approach after manual check from (3,11)")
    assert_equal(dirs["4,11"].west, true, "(4,11) should block west approach after manual check from (3,11)")
    assert_equal(dirs["3,12"].west, true, "(3,12) should block west approach after probe_edge_verify from (2,12)")
    assert_equal(dirs["3,12"].south, true, "(3,12).south should block after walked verifier from (3,13)->UP")
    assert_equal(dirs["4,12"].south, true, "(4,12).south should block after walked verifier from (4,13)->UP")
    assert_equal(dirs["4,10"].west, true, "(4,10) should block west approach after probe_edge_verify from (3,10)")
    assert_equal(dirs["3,9"].south, true, "(3,9) should block south approach after probe_edge_verify from (3,10)")
    assert_equal(dirs["2,9"].south, true, "(2,9) should block south approach after probe_edge_verify from (2,10)")
    assert_equal(dirs["1,10"].east, true, "(1,10) should block east approach after probe_edge_verify from (2,10)")
    assert_equal(dirs["1,11"].east, true, "(1,11) should block east approach after probe_edge_verify from (2,11)")
    assert_equal(dirs["1,12"].east, true, "(1,12) should block east approach after probe_edge_verify from (2,12)")
    assert_equal(dirs["6,10"].east, true, "(6,10) should block east approach after entrance-to-Tool-Merchant verifier from (7,10)")
    assert_equal(dirs["6,11"].east, true, "(6,11) should block east approach after entrance-to-Tool-Merchant verifier from (7,11)")
    assert_equal(dirs["6,12"].east, true, "(6,12) should block east approach after entrance-to-Tool-Merchant verifier from (7,12)")
    assert_equal(dirs["6,12"].south, true, "(6,12) should block south approach after Garin's Grave route verifier from (6,13)")
    assert_equal(dirs["5,12"].south, true, "(5,12) should block south approach after Garin's Grave route verifier from (5,13)")
    for x = 7, 14 do
        assert_equal(dirs[x .. ",9"].south, true, string.format("(%d,9) should block south approach after Garin's Grave route verifier", x))
    end
    assert_equal(dirs["13,3"].west, true, "(13,3) should block west approach after Garin's Grave route verifier from (12,3)")
    assert_equal(dirs["13,5"].west, true, "(13,5) should block west approach after Garin's Grave route verifier from (12,5)")
    assert_equal(dirs["13,6"].west, true, "(13,6) should block west approach after Garin's Grave route verifier from (12,6)")
    assert_equal(dirs["13,6"].south, true, "(13,6) should block south approach after Garin's Grave route verifier from (13,7)")
    for x = 14, 18 do
        assert_equal(dirs[x .. ",6"].south, true, string.format("(%d,6) should block south approach after Garin's Grave route verifier", x))
    end
    assert_equal(dirs["15,10"].west, true, "(15,10).west should block after full-NPC-parked same-origin verifier from (14,10)->RIGHT")
    assert_equal(dirs["19,8"].west, true, "(19,8) should block west approach after Garin's Grave route verifier from (18,8)")
    assert_equal(dirs["19,7"].west, true, "(19,7) should block west approach after post-reload Garin's Grave route verifier from (18,7)")
    assert_equal(dirs["19,9"].west, true, "(19,9) should block west approach after post-reload Garin's Grave route verifier from (18,9)")
    assert_equal(dirs["13,4"].west, true, "(13,4) should block west approach after post-reload Garin's Grave route verifier from (12,4)")
    assert_equal(dirs["15,10"].south, true, "(15,10) should block south approach after post-reload Garin's Grave route verifier from (15,11)")
    assert_equal(dirs["16,10"].south, true, "(16,10) should block south approach after post-reload Garin's Grave route verifier from (16,11)")
    assert_equal(dirs["18,14"].east, true, "(18,14) should block east approach after Garin's Grave route verifier from (19,14)")
    assert_equal(dirs["4,4"].south, true, "(4,4).south should block after live raw probe from (4,5)->UP")
    assert_equal(dirs["1,2"].south, true, "(1,2).south should block after walked verifier from (1,3)->UP")
    assert_equal(dirs["2,2"].south, true, "(2,2).south should block after walked verifier from (2,3)->UP")
    assert_equal(dirs["2,2"].east, true, "(2,2).east should block after walked verifier from (3,2)->LEFT")
    assert_blocked_approach("2,1", "east", "(2,1).east should block after same-origin grave-stairs route probe from (3,1)->LEFT")
    assert_equal(dirs["14,1"].west, true, "(14,1) should block west approach after door-to-grave trail verifier from (13,1)")
    assert_equal(dirs["14,1"].east, true, "(14,1).east should block after same-origin keyless return probes from (15,1)->LEFT")
    for x = 15, 18 do
        assert_equal(dirs[x .. ",2"].north, true, string.format("(%d,2) should block north approach after reverse grave-route verifier", x))
    end
    for x = 4, 11 do
        assert_equal(dirs[x .. ",2"].north, true, string.format("(%d,2).north should block after 2026-06-17 grave-return row-1 probe from (%d,1)->DOWN", x, x))
    end
    assert_equal(dirs["4,2"].west, true, "(4,2).west should block after same-origin grave-return probes from (3,2)->RIGHT")
    assert_equal(dirs["11,2"].south, true, "(11,2).south should block after 2026-06-17 reverse route probe from (11,3)->UP")
    for x = 6, 10 do
        assert_blocked_approach(x .. ",2", "south", string.format("(%d,2).south should block after 2026-06-24 grave-stairs route probe from (%d,3)->UP", x, x))
    end
    assert_blocked_approach("6,4", "north", "(6,4).north should block after 2026-06-24 grave-stairs route probe from (6,3)->DOWN")
    assert_blocked_approach("6,4", "east", "(6,4).east should block after 2026-06-24 grave-stairs route probe from (7,4)->LEFT")
    assert_blocked_approach("6,5", "east", "(6,5).east should block after 2026-06-24 grave-stairs route probe from (7,5)->LEFT")
    assert_blocked_approach("6,6", "east", "(6,6).east should block after 2026-06-24 grave-stairs route probe from (7,6)->LEFT")
    assert_blocked_approach("6,6", "south", "(6,6).south should block after 2026-06-24 grave-stairs route probe from (6,7)->UP")
    assert_blocked_approach("5,6", "south", "(5,6).south should block after 2026-06-24 grave-stairs route probe from (5,7)->UP")
    assert_blocked_approach("3,6", "south", "(3,6).south should block after 2026-06-24 grave-stairs route probe from (3,7)->UP")
    assert_blocked_approach("2,6", "south", "(2,6).south should block after 2026-06-24 grave-stairs route probe from (2,7)->UP")
    assert_blocked_approach("14,1", "north", "(14,1).north should block after 2026-06-24 top-lane probe from (14,0)->DOWN")
    assert_equal(dirs["3,4"].north, true, "(3,4).north should block after 2026-06-17 dark-wall return probe from (3,3)->DOWN")
    assert_equal(dirs["2,4"].north, true, "(2,4).north should block after 2026-06-17 dark-wall return probe from (2,3)->DOWN")
    assert_blocked_approach("2,4", "west", "(2,4).west should block after same-origin grave-stairs-to-Inn probe from (1,4)->RIGHT")
    for x = 1, 15 do
        assert_equal(dirs[x .. ",9"].north, true, string.format("(%d,9).north should block after 2026-06-17 grave-return row-8 probe from (%d,8)->DOWN", x, x))
    end
    assert_equal(dirs["15,9"].east, true, "(15,9).east should block after 2026-06-17 grave-return probe from (16,9)->LEFT")
    assert_equal(dirs["16,10"].north, true, "(16,10).north should block after 2026-06-17 grave-return probe from (16,9)->DOWN")
    assert_blocked_approach("16,10", "east", "(16,10).east should block after same-origin grave-stairs return probe from (17,10)->LEFT")
    assert_equal(dirs["17,14"].north, true, "(17,14).north should block after same-origin opened-door inn-route probes from (17,13)->DOWN")
    assert_equal(dirs["18,0"].east, true, "(18,0) should block east approach after 2026-06-05 Silver Harp return verifier from (19,0) blocked 5/5")
    assert_open_approach("18,0", "south", "(18,0) south approach should stay open after direct verifier from (18,1) moved before the world-map transition")
    assert_equal(dirs["19,2"].north, true, "(19,2).north should block after 2026-06-17 grave-return probes from (19,1)->DOWN")
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
    assert_equal(dirs["14,16"].west, true, "(14,16).west should block after same-origin inn route probes from (13,16)->RIGHT")
    assert_equal(dirs["14,17"].west, true, "(14,17).west should block after same-origin inn route probe from (13,17)->RIGHT")
    assert_open_approach("14,17", "east", "(14,17) should stay open from east after probe_edge_verify from (15,17) moved 5/5")
    assert_open_approach("3,10", "south", "(3,10) should stay open from south; user crossed north from (3,11)")
    assert_open_approach("3,10", "west", "(3,10) should stay open from west; manual movement crossed from (2,10)")
    assert_open_approach("2,10", "east", "(2,10) should stay open from east; manual movement crossed from (3,10)")
    assert_open_approach("2,11", "east", "(2,11) should stay open from east; user crossed west from (3,11)")
    assert_open_approach("3,11", "north", "(3,11) should stay open from north after reverse movement from (3,10)")
    assert_open_approach("3,11", "west", "(3,11) should stay open from west after reverse movement from (2,11)")
    assert_equal(dirs["1,12"].south, true, "(1,12).south should block after walked probe from hidden (1,13)->UP")
    assert_equal(dirs["6,17"].east, true, "(6,17).east should block after sweep_walk plus walked verifier from (7,17)->LEFT")
    assert_equal(dirs["7,18"].north, true, "(7,18).north should block after sweep_walk plus walked verifier from (7,17)->DOWN")
    assert_equal(dirs["8,17"].west, true, "(8,17).west should block after sweep_walk plus walked verifier from (7,17)->RIGHT")
    assert_open_approach("7,17", "north", "(7,17).north should stay open after walked route entered from (7,16)")
    assert_equal(dirs["8,16"].north, true, "(8,16).north should block after sweep_walk plus walked verifier from (8,15)->DOWN")
    assert_equal(dirs["9,16"].east, true, "(9,16).east should block after sweep_walk plus walked verifier from (10,16)->LEFT")
    assert_equal(dirs["9,16"].north, true, "(9,16).north should block after sweep_walk plus walked verifier from (9,15)->DOWN")
    assert_equal(dirs["10,17"].north, true, "(10,17).north should block after sweep_walk plus walked verifier from (10,16)->DOWN")
    assert_open_approach("8,15", "north", "(8,15).north should stay open after walked route entered from (8,14)")
    assert_open_approach("9,15", "west", "(9,15).west should stay open after walked route entered from (8,15)")
    assert_open_approach("10,16", "north", "(10,16).north should stay open after walked route entered from (10,15)")
    assert_equal(env.map_reader.is_walkable(0x09, 2, 13), true, "(2,13) should be a Garinham passthrough after 5/5 live moves from (2,12)")
    assert_equal(env.map_reader.is_walkable(0x09, 1, 13), true, "(1,13) should be a Garinham passthrough after walked probes from east, west, and south")

    env.restore()
end

function tests.rimuldar_marks_only_verified_entry_settle()
    local env = make_env()

    assert_equal(
        env.map_reader.get_entry_settle_frames(0x0B, 0, 0, "east"),
        16,
        "Rimuldar (0,0) east entry should require a 16-frame neutral settle"
    )
    assert_equal(
        env.map_reader.get_entry_settle_frames(0x0B, 0, 0, "west"),
        0,
        "Rimuldar reverse entry should retain ordinary cadence"
    )
    assert_equal(
        env.map_reader.get_entry_settle_frames(0x0B, 1, 0, "east"),
        0,
        "neighboring top-bank cells should not become cadence entries"
    )
    assert_equal(
        env.map_reader.get_entry_settle_frames(0x0A, 0, 0, "east"),
        0,
        "entry-settle metadata should remain map-scoped"
    )

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
    assert_equal(dirs["24,4"].north, true, "Rimuldar (24,4).north should block after Weapons Merchant route/probe proof from (24,3)")
    assert_equal(dirs["25,12"].east, true, "Rimuldar (25,12) should block entry from the east after latest Weapons Merchant route loop from (26,12)")
    assert_equal(dirs["25,12"].south, true, "Rimuldar (25,12) should block entry from the south after latest Weapons Merchant route loop from (25,13)")
    assert_equal(dirs["26,5"].east, true, "Rimuldar (26,5).east should block after Weapons Merchant route/probe proof from (27,5)")
    assert_open_approach("27,8", "east", "Rimuldar (27,8).east must stay open; reloaded live movement crossed (28,8)->LEFT and restored the Weapons Merchant path")
    assert_equal(dirs["20,3"].west, true, "Rimuldar (20,3).west should block after Weapons Merchant route/probe proof from (19,3)")
    assert_equal(dirs["10,6"].south, true, "Rimuldar (10,6).south should block after Weapons Merchant lower-loop verifier from (10,7)")
    assert_equal(dirs["9,9"] and dirs["9,9"].south, true, "Rimuldar (9,9).south should block after Magic Key Merchant route/probe proof from (9,10)")
    assert_equal(dirs["12,9"].north, true, "Rimuldar (12,9).north should block after Weapons Merchant lower-loop verifier from (12,8)")
    assert_equal(dirs["12,9"].south, true, "Rimuldar (12,9).south should block after Magic Key Merchant route/probe proof from (12,10)")
    assert_equal(dirs["13,8"].west, true, "Rimuldar (13,8).west should block after Weapons Merchant lower-loop verifier from (12,8)")
    assert_equal(dirs["16,6"].west, true, "Rimuldar (16,6).west should block after Weapons Merchant lower-loop verifier from (15,6)")
    assert_equal(dirs["16,6"].south, true, "Rimuldar (16,6).south should block after reset-route probe proof from (16,7)")
    assert_equal(dirs["20,10"].south, true, "Rimuldar (20,10) should block entry from the south after key-route verifier from (20,11)")
    assert_equal(dirs["20,10"].west, true, "Rimuldar (20,10) should block entry from the west after key-route verifier from (19,10)")
    assert_equal(dirs["21,6"].west, true, "Rimuldar (21,6) should block entry from the west after latest Weapons Merchant route loop from (20,6)")
    assert_equal(dirs["21,7"].west, true, "Rimuldar (21,7) should block entry from the west after latest Weapons Merchant route loop from (20,7)")
    assert_equal(dirs["21,8"].west, true, "Rimuldar (21,8) should block entry from the west after latest Weapons Merchant route verifier from (20,8)")
    assert_equal(dirs["21,11"].west, true, "Rimuldar (21,11) should block entry from the west after key-route verifier from (20,11)")
    assert_equal(dirs["21,12"].south, true, "Rimuldar (21,12) should block entry from the south after key-route verifier from (21,13)")
    assert_equal(dirs["21,12"].west, true, "Rimuldar (21,12) should block entry from the west after key-route verifier from (20,12)")
    assert_open_approach("24,8", "south", "Rimuldar (24,8).south must stay open; live weapon-shop probe from (24,9)->UP reached the stand")
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
    assert_equal(dirs["17,7"].west, true, "Rimuldar (17,7).west should block after reset-route proof from (16,7)")
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
    assert_equal(dirs["15,17"].north, true, "Rimuldar (15,17).north should block after inn-route proof from (15,16)")
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
    assert_open_approach("4,6", "north", "Rimuldar (4,6).north should stay unmodeled; corrected decoding makes the counter itself non-walkable")
    assert_equal(dirs["4,2"].south, true, "Rimuldar (4,2) should block entry from the south because (4,3)->UP is a world-map transition")
    assert_equal(dirs["5,2"].south, true, "Rimuldar (5,2) should block entry from the south after latest return-route loop from (5,3)")
    assert_equal(dirs["6,8"].south, true, "Rimuldar (6,8) should block entry from the south after latest key-route loop from (6,9)")
    assert_equal(dirs["6,11"].south, true, "Rimuldar (6,11) should block entry from the south after latest entrance-route loop from (6,12)")
    assert_equal(dirs["6,15"].west, true, "Rimuldar (6,15) should block entry from the west after direct verifier from (5,15)")
    assert_equal(dirs["4,16"].north, true, "Rimuldar (4,16) should block entry from the north after repeated manual projection loops from (4,15)")
    assert_equal(dirs["8,10"].east, true, "Rimuldar (8,10) should block entry from the east after repeated entrance-route loops from (9,10)")
    assert_equal(dirs["8,10"].north, true, "Rimuldar (8,10) should block entry from the north after repeated lower-lane return loops from (8,9)")
    assert_equal(dirs["9,9"].south, true, "Rimuldar (9,9).south should block after current Magic Key Merchant route/probe proof from (9,10)")
    assert_equal(dirs["9,9"].west, true, "Rimuldar (9,9).west should block after reset-route proof from (8,9)")
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
    assert_equal(dirs["14,9"].north, true, "Rimuldar (14,9).north should block after reset-route proof from (14,8)")
    assert_equal(dirs["15,9"].south, true, "Rimuldar (15,9) should block entry from the south after 7/7 verifier from (15,10)")
    assert_equal(dirs["16,9"].south, true, "Rimuldar (16,9) should block entry from the south after verifier from (16,10)")
    assert_equal(dirs["16,9"].north, true, "Rimuldar (16,9).north should block after reset-route proof from (16,8)")
    assert_equal(dirs["17,9"].south, true, "Rimuldar (17,9) should block entry from the south after verifier from (17,10)")
    assert_equal(dirs["17,9"].east, true, "Rimuldar (17,9) should block entry from the east after repeated entrance-route loop from (18,9)")
    assert_open_approach("18,17", "north", "Rimuldar (18,17).north should stay open after direct entrance-to-chest verifier from (18,16)")
    assert_equal(dirs["19,17"].north, true, "Rimuldar (19,17).north should block after entrance-to-chest verifier from (19,16)")
    assert_equal(dirs["19,17"].west, true, "Rimuldar (19,17).west should block after route/probe proof from (18,17)")
    assert_equal(dirs["20,17"].north, true, "Rimuldar (20,17).north should block after entrance-to-chest verifier from (20,16)")
    assert_equal(dirs["21,17"].north, true, "Rimuldar (21,17).north should block after entrance-to-chest verifier from (21,16)")
    assert_equal(dirs["22,17"].north, true, "Rimuldar (22,17).north should block after entrance-to-chest verifier from (22,16)")
    assert_equal(dirs["23,17"].north, true, "Rimuldar (23,17).north should block after entrance-to-chest verifier from (23,16)")
    assert_equal(dirs["23,17"].south, true, "Rimuldar (23,17).south should block after return-to-entrance route/probe proof from (23,18)")
    assert_equal(dirs["24,17"].north, true, "Rimuldar (24,17).north should block after entrance-to-chest verifier from (24,16)")
    assert_equal(dirs["25,17"].north, true, "Rimuldar (25,17).north should block after entrance-to-chest verifier from (25,16)")
    assert_equal(dirs["25,17"].east, true, "Rimuldar (25,17).east should block after route/probe proof from (26,17)")
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
    assert_equal(dirs["22,20"].north, true, "Rimuldar (22,20).north should block after outer-door stand route/probe proof from (22,19)")
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
    assert_equal(dirs["18,21"].south, true, "Rimuldar (18,21).south should block after outer-door stand route/probe proof from (18,22)")
    assert_equal(dirs["19,22"].east, true, "Rimuldar (19,22) should block entry from the east after parked Wings survey and direct verifier from (20,22)")
    assert_equal(dirs["19,22"].west, true, "Rimuldar (19,22).west should block after outer-door stand route/probe proof from (18,22)")
    assert_equal(dirs["19,23"].east, true, "Rimuldar (19,23) should block entry from the east after parked Wings survey and 10/10 verifier from (20,23)")
    assert_equal(dirs["19,23"].west, true, "Rimuldar (19,23).west should block after outer-door stand route/probe proof from (18,23)")
    assert_equal(dirs["20,24"].north, true, "Rimuldar (20,24) should block entry from the north after lower-room verifier from (20,23)")
    assert_equal(dirs["20,24"].south, true, "Rimuldar (20,24) should block entry from the south after lower-room side probe from (20,25)")
    assert_open_approach("22,24", "north", "Rimuldar (22,24).north is open based on forced-origin probes from (22,23)")
    assert_equal(dirs["16,24"].north, true, "Rimuldar (16,24).north should block after return-route verifier from (16,23)")
    assert_equal(dirs["16,24"].south, true, "Rimuldar (16,24) should block entry from the south after lower-strip forced probe from (16,25)")
    assert_open_approach("22,21", "south", "Rimuldar (22,21).south should be open; direct probe from (22,22) moved")
    assert_open_approach("28,17", "north", "Rimuldar (28,17).north should stay open after direct entrance-to-chest verifier from (28,16)")
    assert_equal(dirs["28,17"].east, true, "Rimuldar (28,17).east should block after entrance-to-chest verifier from (29,17)")
    assert_equal(dirs["21,24"].north, true, "Rimuldar (21,24) should block entry from the north after legitimate door-side approaches failed")
    assert_equal(dirs["24,21"].north, true, "Rimuldar (24,21).north should block after outer-door stand route/probe proof from (24,20)")
    assert_equal(dirs["25,19"].west, true, "Rimuldar (25,19).west should block after outer-door stand route/probe proof from (24,19)")
    assert_equal(dirs["25,20"].west, true, "Rimuldar (25,20).west should block after outer-door stand route/probe proof from (24,20)")
    assert_equal(dirs["22,22"].west, true, "Rimuldar (22,22).west should block after opened outer-door route/probe proof from (21,22)")
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
    assert_equal(dirs["17,19"].east, true, "Rimuldar (17,19).east should block after inn-route proof from (18,19)")
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
    assert_open_approach("2,8", "west", "Rimuldar (2,8).west should stay unpromoted until the Magic Key route has an alternate bridge or state explanation")
    assert_open_approach("1,8", "east", "Rimuldar (1,8).east should stay unpromoted with the unresolved (2,8).west route-model decision")
    assert_open_approach("1,23", "east", "Rimuldar (1,23).east moved from the Old Man 3 west-side seam and must stay open")
    assert_open_approach("2,23", "west", "Rimuldar (2,23).west moved from the Old Man 3 west-side seam and must stay open")
    assert_equal(dirs["3,8"].east, true, "Rimuldar (3,8) should block entry from the east after focused verifier from (4,8)")
    assert_equal(dirs["3,8"].south, true, "Rimuldar (3,8) should block entry from the south after repeated route/seam failures from (3,9)")
    assert_equal(dirs["5,8"].south, true, "Rimuldar (5,8) should block entry from the south after direct verifier from (5,9)")
    assert_equal(dirs["6,2"].east, true, "Rimuldar (6,2) should block entry from the east after top-pocket direct probe from (7,2)")
    assert_equal(dirs["6,7"].east, true, "Rimuldar (6,7) should block entry from the east after direct probe from (7,7)")
    assert_equal(dirs["6,8"].east, true, "Rimuldar (6,8) should block entry from the east after direct probe from (7,8)")
    assert_equal((dirs["17,17"] or {}).east, true, "Rimuldar (17,17).east should block after entrance-to-Inn route proof from (18,17)->LEFT")
    assert_equal(dirs["6,3"].west, true, "Rimuldar (6,3) should block entry from the west after latest reloaded return-route cluster from (5,3)")
    assert_equal(dirs["6,4"].west, true, "Rimuldar (6,4) should block entry from the west after latest reloaded return-route cluster from (5,4)")

    local cell_29_13 = dirs["29,13"] or {}
    assert_equal(cell_29_13.south, nil, "Rimuldar (29,13) should stay open from the south for the live-confirmed exit route")
    assert_equal(cell_29_13.east, nil, "Rimuldar (29,13) should not gain an east-side block; it is the confirmed world-map exit")
    assert_equal(dirs["28,16"].east, true, "Rimuldar (28,16).east should block after route/probe proof from (29,16)")
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

    assert_equal(env.map_reader.is_walkable(0x07, 1, 17), true, "(1,17) should be walkable after live west-side throat proof")
    assert_equal(env.map_reader.is_walkable(0x07, 5, 14), true, "(5,14) should be walkable after live public-route hidden-throat proof")
    assert_equal(env.map_reader.is_walkable(0x07, 3, 17), true, "(3,17) should be walkable after live Tool Merchant hidden-bridge proof")
    assert_equal(env.map_reader.is_walkable(0x07, 2, 17), true, "(2,17) should be walkable after live West Side Door hidden-bridge proof")
    assert_equal(env.map_reader.is_walkable(0x07, 18, 23), true, "(18,23) should be walkable after live Kol pathability proof")
    assert_equal(env.map_reader.is_walkable(0x07, 19, 23), true, "(19,23) should be walkable after live Kol entry/exit proof")
    assert_equal(env.map_reader.is_walkable(0x07, 20, 23), true, "(20,23) should be walkable after live west-approach proof")
    assert_equal(env.map_reader.is_walkable(0x07, 0, 17), false, "nearby unconfirmed west-edge cells should stay non-walkable")
    assert_equal(env.map_reader.is_walkable(0x07, 4, 14), false, "(4,14) should stay non-walkable after failed West Side Door bridge probes")
    assert_equal(env.map_reader.is_walkable(0x07, 4, 17), false, "unproven Tool Merchant hidden-bridge sibling (4,17) should stay non-walkable")
    assert_equal(env.map_reader.is_walkable(0x07, 6, 14), false, "unproven Kol hidden-throat sibling (6,14) should stay non-walkable")
    assert_equal(env.map_reader.is_walkable(0x07, 7, 14), false, "unproven Kol hidden-throat sibling (7,14) should stay non-walkable")
    assert_equal(env.map_reader.is_walkable(0x07, 17, 23), false, "nearby unconfirmed type-0 cells should stay non-walkable")

    local details = env.map_reader.get_walkability_details(0x07, 1, 17)
    assert_equal(details.reason, "passthrough", "(1,17) should report the passthrough override")
    details = env.map_reader.get_walkability_details(0x07, 5, 14)
    assert_equal(details.reason, "passthrough", "(5,14) should report the passthrough override")
    details = env.map_reader.get_walkability_details(0x07, 3, 17)
    assert_equal(details.reason, "passthrough", "(3,17) should report the passthrough override")
    details = env.map_reader.get_walkability_details(0x07, 2, 17)
    assert_equal(details.reason, "passthrough", "(2,17) should report the passthrough override")
    details = env.map_reader.get_walkability_details(0x07, 18, 23)
    assert_equal(details.reason, "passthrough", "(18,23) should report the passthrough override")
    details = env.map_reader.get_walkability_details(0x07, 19, 23)
    assert_equal(details.reason, "passthrough", "(19,23) should report the passthrough override")

    local snapshot = env.map_reader.get_walkability_snapshot(0x07)
    assert_equal(snapshot[17][1], true, "walkability snapshot should include the Kol west-side throat")
    assert_equal(snapshot[14][5], true, "walkability snapshot should include the Kol public-route hidden throat")
    assert_equal(snapshot[17][3], true, "walkability snapshot should include the Tool Merchant hidden bridge")
    assert_equal(snapshot[17][2], true, "walkability snapshot should include the West Side Door hidden bridge")
    assert_equal(snapshot[17][4], false, "walkability snapshot should keep unproven Tool Merchant bridge siblings closed")
    assert_equal(snapshot[14][6], false, "walkability snapshot should keep unproven Kol hidden-throat siblings closed")
    assert_equal(snapshot[14][7], false, "walkability snapshot should keep unproven Kol hidden-throat siblings closed")
    assert_equal(snapshot[17][0], false, "walkability snapshot should keep unconfirmed west-edge cells closed")
    assert_equal(snapshot[23][18], true, "walkability snapshot should include the west Kol entry strip")
    assert_equal(snapshot[23][19], true, "walkability snapshot should include the Kol exit tile")
    assert_equal(snapshot[23][20], true, "walkability snapshot should include the adjacent Kol entry strip")
    assert_equal(snapshot[23][17], false, "walkability snapshot should keep unconfirmed bottom-edge cells closed")

    env.restore()
end

function tests.kol_locked_doors_open_from_door_ram_array()
    local base = 7 * 5
    local memory_bytes = {}
    local env = make_env({
        rom_bytes = {
            [base] = 0x00,
            [base + 1] = 0x80,
            [base + 2] = 23,
            [base + 3] = 23,
            [base + 4] = 0,
        },
        memory_bytes = memory_bytes,
        door_array_max = 8,
        door_x_pos_start = 0x600C,
        door_y_pos_start = 0x600D,
        door_array_stride = 2,
    })

    local context = env.map_reader.get_door_cell_context(0x07, 7, 12)
    assert_equal(context ~= nil, true, "Kol western-building locked door should be modeled")
    assert_equal(context.open, false, "Kol western-building door should start closed without door RAM")
    local west_side_context = env.map_reader.get_door_cell_context(0x07, 1, 14)
    assert_equal(west_side_context ~= nil, true, "Kol west-side locked door should be modeled")
    assert_equal(west_side_context.open, false, "Kol west-side door should start closed without door RAM")

    local closed = env.map_reader.get_walkability_details(0x07, 7, 12)
    assert_equal(closed.effective_walkable, false, "closed Kol western-building door should block movement")
    assert_equal(closed.reason, "door_closed", "closed Kol western-building door should report door_closed")
    local west_side_closed = env.map_reader.get_walkability_details(0x07, 1, 14)
    assert_equal(west_side_closed.effective_walkable, false, "closed Kol west-side door should block movement")
    assert_equal(west_side_closed.reason, "door_closed", "closed Kol west-side door should report door_closed")

    local dirs = env.map_reader.get_directional_blocks(0x07)
    assert_equal(dirs["7,12"] and dirs["7,12"].east or nil, nil, "(7,12).east is the confirmed Kol door approach, not a permanent wall")

    memory_bytes[0x600C] = 7
    memory_bytes[0x600D] = 12
    context = env.map_reader.get_door_cell_context(0x07, 7, 12)
    assert_equal(context.open, true, "Kol western-building door should open from door RAM at (7,12)")
    local open = env.map_reader.get_walkability_details(0x07, 7, 12)
    assert_equal(open.effective_walkable, true, "opened Kol western-building door should become walkable")
    assert_equal(open.reason, "door_open", "opened Kol western-building door should report door_open")

    memory_bytes[0x600E] = 1
    memory_bytes[0x600F] = 14
    west_side_context = env.map_reader.get_door_cell_context(0x07, 1, 14)
    assert_equal(west_side_context.open, true, "Kol west-side door should open from door RAM at (1,14)")
    local west_side_open = env.map_reader.get_walkability_details(0x07, 1, 14)
    assert_equal(west_side_open.effective_walkable, true, "opened Kol west-side door should become walkable")
    assert_equal(west_side_open.reason, "door_open", "opened Kol west-side door should report door_open")

    env.restore()
end

function tests.kol_first_survey_loop_blocks_are_directional_only()
    local env = make_env()
    local dirs = env.map_reader.get_directional_blocks(0x07)

    assert_equal(dirs["10,18"].east, true, "(10,18) should block entry from the east after the Merchant 1 autowalk bounce")
    assert_equal(dirs["10,19"].east, true, "(10,19) should block entry from the east after the Merchant 1 autowalk bounce")
    assert_equal(dirs["10,18"].west, true, "(10,18) should block entry from the west after the Tool Merchant return-route probe")
    assert_equal(dirs["10,19"].west, true, "(10,19) should block entry from the west after the Tool Merchant final-segment probe")
    assert_equal(dirs["7,15"].east, true, "(7,15) should block entry from the east after the inner Merchant 1 loop")
    assert_equal(dirs["7,11"].east, true, "(7,11) should block entry from the east after the west NPC route loop")
    assert_equal(dirs["7,12"] and dirs["7,12"].east or nil, nil, "(7,12).east is the confirmed Kol door approach, not a permanent wall")
    assert_equal(dirs["8,16"].north, true, "(8,16) should block entry from the north after the inner Merchant 1 loop")
    assert_equal(dirs["9,16"].north, true, "(9,16) should block entry from the north after the Merchant 1 route retry")
    assert_equal(dirs["10,16"].east, true, "(10,16) should block entry from the east after the Merchant 1 route retry")
    assert_equal(dirs["10,16"].north, true, "(10,16) should block entry from the north after the Merchant 1 route retry")
    assert_equal(dirs["5,16"].north, true, "(5,16) should block entry from the north after the Tool Merchant route probe from (5,15)")
    assert_equal(dirs["2,15"].east, true, "(2,15) should block entry from the east after the Tool Merchant route probe from (3,15)")
    assert_equal(dirs["2,15"].west, true, "(2,15) should block entry from the west after the West Side Door route probe from (1,15)")
    assert_equal(dirs["2,16"].east, true, "(2,16) should block entry from the east after the Tool Merchant route probe from (3,16)")
    assert_equal(dirs["2,16"].south, true, "(2,16) should block entry from the south after the West Side Door route probe from (2,17)")
    assert_equal(dirs["2,16"].west, true, "(2,16) should block entry from the west after the West Side Door route probe from (1,16)")
    assert_equal(dirs["2,18"].east, true, "(2,18) should block entry from the east after the West Side Door route probe from (3,18)")
    assert_equal(dirs["2,18"].west, true, "(2,18) should block entry from the west after the West Side Door route probe from (1,18)")
    assert_equal(dirs["2,14"].north, true, "(2,14) should block entry from the north after the opened West Side Door return probe from (2,13)")
    assert_equal(dirs["2,14"].west, true, "(2,14) should block entry from the west after the opened West Side Door return probe from (1,14)")
    assert_equal(dirs["2,10"].south, true, "(2,10) should block entry from the south after the opened West Side Door return probe from (2,11)")
    assert_equal(dirs["3,10"].south, true, "(3,10) should block entry from the south after the opened West Side Door return probe from (3,11)")
    assert_equal(dirs["3,14"].north, true, "(3,14) should block entry from the north after the opened West Side Door return probe from (3,13)")
    assert_equal(dirs["3,14"].south, true, "(3,14) should block entry from the south after the Tool Merchant route probe from (3,15)")
    assert_equal(dirs["4,14"].east, true, "(4,14) should block entry from the east after the West Side Door bridge probe from (5,14)")
    assert_equal(dirs["4,14"].south, true, "(4,14) should block entry from the south after the West Side Door bridge probe from (4,15)")
    assert_equal(dirs["11,20"].north, true, "(11,20) should block entry from the north after the Merchant 1 route retry")
    assert_equal(dirs["11,20"].south, true, "(11,20) should block entry from the south after the Tool Merchant return-route probe")
    assert_equal(dirs["12,19"].west, true, "(12,19) should block entry from the west after queued-route proof")
    assert_equal(dirs["12,19"].north, true, "(12,19) should block entry from the north after the later Merchant 1 loop")
    assert_equal(dirs["13,19"].north, true, "(13,19) should block entry from the north after the later Merchant 1 loop")
    assert_equal(dirs["14,19"].north, true, "(14,19) should block entry from the north after the later Merchant 1 route retry")
    assert_equal(dirs["15,19"].north, true, "(15,19) should block entry from the north after the later Merchant 1 route retry")
    assert_equal(dirs["16,19"].east, true, "(16,19) should block entry from the east after the Merchant 1 route retry")
    assert_equal(dirs["16,19"].north, true, "(16,19) should block entry from the north after the later Merchant 1 route retry")
    assert_equal(dirs["16,20"].east, true, "(16,20) should block entry from the east after the Merchant 1 route retry")
    assert_equal(dirs["16,21"].east, true, "(16,21) should block entry from the east after the Merchant 1 route retry")
    assert_equal(dirs["16,22"].east, true, "(16,22).east should block after 2026-06-26 Tool Merchant route probe from (17,22)->LEFT")
    assert_equal(dirs["17,22"] and dirs["17,22"].west, nil, "(17,22).west should stay open; the blocked approach is modeled on destination (16,22).east")
    for x = 1, 4 do
        assert_equal(dirs[x .. ",10"].north, true, string.format("(%d,10).north should block after Tool Merchant route probe from (%d,9)->DOWN", x, x))
    end
    for y = 10, 13 do
        assert_equal(dirs["4," .. y].east, true, string.format("(4,%d).east should block after Tool Merchant route probe from (5,%d)->LEFT", y, y))
    end
    for y = 11, 13 do
        assert_equal(dirs["4," .. y].west, true, string.format("(4,%d).west should block after opened West Side Door return probe from (3,%d)->RIGHT", y, y))
    end
    assert_equal(dirs["7,9"].west, true, "(7,9).west should block after Tool Merchant route probe from (6,9)->RIGHT")
    assert_equal(dirs["6,4"].south, true, "(6,4).south should block after closed-door Tool Merchant probe from (6,5)->UP")
    assert_equal(dirs["7,4"].south, true, "(7,4).south should block after closed-door Tool Merchant probe from (7,5)->UP")
    assert_equal(dirs["8,4"].south, true, "(8,4).south should block after closed-door Tool Merchant probe from (8,5)->UP")
    assert_equal(dirs["5,5"].east, true, "(5,5).east should block after closed-door Tool Merchant probe from (6,5)->LEFT")
    assert_equal(dirs["5,6"].east, true, "(5,6).east should block after closed-door Tool Merchant probe from (6,6)->LEFT")
    assert_equal(dirs["5,7"].east, true, "(5,7).east should block after closed-door Tool Merchant probe from (6,7)->LEFT")
    assert_equal(dirs["6,8"].north, true, "(6,8).north should block after closed-door Tool Merchant route probe from (6,7)->DOWN")
    assert_equal(dirs["7,8"].east, true, "(7,8).east should block after closed-door Tool Merchant route probe from (8,8)->LEFT")
    assert_equal(dirs["7,8"].north, true, "(7,8).north should block after closed-door Tool Merchant route probe from (7,7)->DOWN")
    assert_equal(dirs["7,9"].east, true, "(7,9).east should block after closed-door Tool Merchant route probe from (8,9)->LEFT")
    assert_equal(dirs["7,10"].east, true, "(7,10).east should block after closed-door Tool Merchant route probe from (8,10)->LEFT")
    assert_equal(dirs["7,13"].west, true, "(7,13).west should block after Tool Merchant route probe from (6,13)->RIGHT")
    assert_equal(dirs["7,13"].east, true, "(7,13).east should block after Tool Merchant route probe from (8,13)->LEFT")
    assert_equal(dirs["2,19"].west, true, "(2,19).west should block after Tool Merchant route probe from the (1,19) pocket")
    assert_equal(dirs["2,19"].south, true, "(2,19).south should block after Tool Merchant return-route probe from (2,20)->UP")
    assert_equal(dirs["2,19"].east, true, "(2,19).east should block after Tool Merchant return-route probe from (3,19)->LEFT")
    assert_equal(dirs["1,20"].north, true, "(1,20).north should block after Tool Merchant route probe from the (1,19) pocket")
    assert_equal(dirs["1,18"].south, true, "(1,18).south should block after Tool Merchant route probe from the (1,19) pocket")
    assert_equal(dirs["1,20"].south, nil, "(1,20) should stay open from unproven approaches")
    assert_equal(dirs["1,18"].north, nil, "(1,18) should stay open from unproven approaches")
    assert_equal(dirs["4,16"].west, true, "(4,16).west should block after Tool Merchant return-route probe from (3,16)->RIGHT")
    assert_equal(dirs["4,16"].north, true, "(4,16).north should block after Tool Merchant return-route probe from (4,15)->DOWN")
    assert_equal(dirs["4,18"].east, true, "(4,18).east should block after Tool Merchant return-route probe from (5,18)->LEFT")
    assert_equal(dirs["6,16"].north, true, "(6,16).north should block after Tool Merchant return-route probe from (6,15)->DOWN")
    assert_equal(dirs["12,20"].south, true, "(12,20).south should block after Tool Merchant return-route probe from (12,21)->UP")
    assert_equal(dirs["10,20"].west, true, "(10,20).west should block after Tool Merchant return-route probe from (9,20)->RIGHT")
    assert_equal(dirs["10,20"].south, true, "(10,20).south should block after Tool Merchant return-route probe from (10,21)->UP")
    assert_equal(dirs["3,21"].north, true, "(3,21).north should block after Tool Merchant return-route probe from (3,20)->DOWN")
    assert_equal(dirs["3,21"].south, true, "(3,21).south should block after Tool Merchant return-route probe from (3,22)->UP")
    assert_equal(dirs["3,21"].west, true, "(3,21).west should block after Tool Merchant return-route probe from (2,21)->RIGHT")
    assert_equal(dirs["4,20"].east, true, "(4,20).east should block after Tool Merchant return-route probe from (5,20)->LEFT")
    assert_equal(dirs["4,20"].north, true, "(4,20).north should block after Tool Merchant return-route probe from (4,19)->DOWN")
    assert_equal(dirs["4,20"].west, true, "(4,20).west should block after Tool Merchant return-route probe from (3,20)->RIGHT")
    assert_equal(dirs["4,21"].east, true, "(4,21).east should block after Tool Merchant return-route probe from (5,21)->LEFT")
    assert_equal(dirs["13,21"].west, true, "(13,21).west should block after Tool Merchant return-route probe from (12,21)->RIGHT")
    assert_equal(dirs["4,22"].east, true, "(4,22).east should block after Tool Merchant return-route probe from (5,22)->LEFT")
    assert_equal(dirs["4,22"].west, true, "(4,22).west should block after Tool Merchant return-route probe from (3,22)->RIGHT")
    assert_equal(dirs["10,22"].north, true, "(10,22).north should block after Tool Merchant return-route probe from (10,21)->DOWN")
    assert_equal(dirs["10,22"].west, true, "(10,22).west should block after Tool Merchant return-route probe from (9,22)->RIGHT")
    assert_equal(dirs["11,22"].north, true, "(11,22).north should block after Tool Merchant return-route probe from (11,21)->DOWN")
    assert_equal(dirs["12,22"].north, true, "(12,22).north should block after Tool Merchant return-route probe from (12,21)->DOWN")
    assert_equal(dirs["4,23"].west, true, "(4,23).west should block after Tool Merchant return-route probe from (3,23)->RIGHT")
    for x = 5, 9 do
        assert_equal(dirs[x .. ",23"].north, true, string.format("(%d,23).north should block after Tool Merchant return-route probe from (%d,22)->DOWN", x, x))
    end
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
    assert_equal(dirs["10,4"].west, true, "(10,4) should block entry from the west after the 2026-06-26 route/probe check from (9,4)->RIGHT")
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
    assert_equal(dirs["7,15"].west, true, "(7,15).west should block after Tool Merchant return-route probe from (6,15)->RIGHT")
    assert_equal(dirs["7,11"].west, nil, "(7,11) should remain open from unproven approaches")
    assert_equal(dirs["7,12"] and dirs["7,12"].west or nil, nil, "(7,12) should remain open from unproven approaches")
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
    assert_equal(dirs["5,3"].south, true, "Rain Shrine (5,3) should block northward entry from (5,4) after same-origin return-route probe")
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
    assert_equal(dirs["8,9"].north, true, "Rain Shrine (8,9) should block southward entry from (8,8) after same-origin return-route probe")
    assert_equal(dirs["8,9"].east, nil, "Rain Shrine (8,9) should keep unconfirmed east approach open")
    assert_equal(dirs["8,9"].south, nil, "Rain Shrine (8,9) should keep unconfirmed south approach open")
    assert_equal(dirs["8,9"].west, nil, "Rain Shrine (8,9) should keep unconfirmed west approach open")
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
    assert_equal(env.map_reader.is_permanently_blocked_override(0x0D, 8, 9), false, "Rain Shrine (8,9) should not be fully blocked")

    env.restore()
end

function tests.brecconary_passthrough_corridor_overrides_false_wall_tiles()
    local base = 8 * 5
    local data_start = 0x1010
    local rom_bytes = {
        [base] = 0x00,      -- CPU $9000 -> file offset $1010
        [base + 1] = 0x90,
        [base + 2] = 29,    -- width 30
        [base + 3] = 29,    -- height 30
        [base + 4] = 0,
    }
    fill_packed_map(rom_bytes, data_start, 30, 30, 0x0)
    local env = make_env({
        rom_bytes = rom_bytes,
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
    assert_equal(env.map_reader.is_walkable(0x08, 3, 23), true, "(3,23) should be walkable via the inn west-room escape passthrough")
    assert_equal(env.map_reader.is_walkable(0x08, 8, 10), true, "(8,10) should be walkable via the inn west-room north escape passthrough")
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
    assert_equal(snapshot[23][3], true, "walkability snapshot should include the inn west-room escape passthrough")
    assert_equal(snapshot[10][8], true, "walkability snapshot should include the inn west-room north escape passthrough")
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

    local outer_door_bridge = env.map_reader.get_walkability_details(0x0B, 18, 18)
    assert_equal(outer_door_bridge.base_walkable, true, "Rimuldar (18,18) should be passable after live movement from (18,17) carried through it")
    assert_equal(outer_door_bridge.effective_walkable, true, "Rimuldar (18,18) should be available to A*")
    assert_equal(outer_door_bridge.reason, "passthrough", "Rimuldar (18,18) should record passthrough as its walkability source")

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
        {"22,4", 22, 4},
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
    local data_start = 0x1010
    local rom_bytes = {
        [base] = 0x00,      -- CPU $9000 -> file offset $1010
        [base + 1] = 0x90,
        [base + 2] = 9,     -- width 10
        [base + 3] = 9,     -- height 10
        [base + 4] = 0,
    }
    fill_packed_map(rom_bytes, data_start, 10, 10, 0x0)
    for x = 0, 9 do
        set_packed_block(rom_bytes, data_start, 10, x, 0, 0x9)
    end
    set_packed_block(rom_bytes, data_start, 10, 0, 1, 0x9)
    for x = 1, 9 do
        set_packed_block(rom_bytes, data_start, 10, x, 1, 0x8)
    end
    local env = make_env({
        rom_bytes = rom_bytes,
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

function tests.garins_grave_b1_treasure_row_overrides_top_edge_boundary()
    local base = 0x18 * 5
    local data_start = 0x1010
    local rom_bytes = {
        [base] = 0x00,      -- CPU $9000 -> file offset $1010
        [base + 1] = 0x90,
        [base + 2] = 19,    -- width 20
        [base + 3] = 19,    -- height 20
        [base + 4] = 0,
    }
    fill_packed_map(rom_bytes, data_start, 20, 20, 0x2)
    local env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = {
            [0] = 0x20,
        },
    })

    for _, x in ipairs({11, 12, 13}) do
        local details = env.map_reader.get_walkability_details(0x18, x, 0)
        assert_equal(details.base_walkable, true, "Garin's Grave B1 treasure row should be passable")
        assert_equal(details.reason, "passthrough", "Garin's Grave B1 treasure row should override top-edge boundary")
    end

    local unconfirmed = env.map_reader.get_walkability_details(0x18, 14, 0)
    assert_equal(unconfirmed.base_walkable, false, "nearby unconfirmed B1 top-edge cells should remain blocked")
    assert_equal(unconfirmed.reason, "engine_boundary", "nearby unconfirmed B1 top-edge cells should keep boundary reason")

    env.restore()
end

function tests.garins_grave_b2_northwest_escape_strip_overrides_left_edge_boundary()
    local base = 0x19 * 5
    local data_offset = 0x1010
    local rom_bytes = {
        [base] = 0x00,      -- CPU $9000 -> file offset $1010
        [base + 1] = 0x90,
        [base + 2] = 13,    -- width 14
        [base + 3] = 11,    -- height 12
        [base + 4] = 0,
    }
    fill_packed_map(rom_bytes, data_offset, 14, 12, 0x0)
    for y = 3, 10 do
        set_packed_block(rom_bytes, data_offset, 14, 1, y, 0x1)
    end

    local env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = {
            [0] = 0x20,
        },
    })

    local pathfinder_saved = false
    with_cleanup(
        function()
            for y = 1, 11 do
                local details = env.map_reader.get_walkability_details(0x19, 0, y)
                assert_equal(details.effective_walkable, true, "B2 left-edge escape strip should be walkable at x=0")
                assert_equal(details.reason, "passthrough", "B2 left-edge escape strip should override engine_boundary")
            end

            local unconfirmed_north = env.map_reader.get_walkability_details(0x19, 0, 0)
            assert_equal(unconfirmed_north.effective_walkable, false, "B2 unconfirmed left-edge cell above the escape strip should stay blocked")
            assert_equal(unconfirmed_north.reason, "engine_boundary", "B2 unconfirmed left-edge cell should keep boundary reason")

            local south_oob = env.map_reader.get_walkability_details(0x19, 0, 12)
            assert_equal(south_oob.effective_walkable, false, "B2 escape strip should not continue below live-confirmed (0,11)")
            assert_equal(south_oob.reason, "out_of_bounds", "B2 (0,12) should stay out of bounds in the 14x12 model")

            local normal_exit = env.map_reader.get_walkability_details(0x19, 1, 11)
            assert_equal(normal_exit.effective_walkable, true, "B2 (1,11) should stay ordinary walkable floor for the strip exit")
            assert_equal(normal_exit.reason, "tile_type", "B2 (1,11) should not need a passthrough override")

            local snapshot = env.map_reader.get_walkability_snapshot(0x19)
            assert_equal(snapshot[1][0], true, "B2 snapshot should include live-confirmed (0,1)")
            assert_equal(snapshot[2][0], true, "B2 snapshot should include live-confirmed (0,2)")
            assert_equal(snapshot[11][0], true, "B2 snapshot should include live-confirmed (0,11)")
            assert_equal(snapshot[0][0], false, "B2 snapshot should keep unconfirmed (0,0) blocked")

            save_module("pathfinder")
            pathfinder_saved = true
            package.loaded["pathfinder"] = nil
            local pathfinder = require "pathfinder"

            local strip_path = pathfinder.find_path(0x19, 1, 2, 0, 11, {})
            assert_equal(strip_path ~= nil, true, "B2 northwest landing should route down the live-confirmed left-edge strip")
            assert_equal(path_has_step(strip_path, 0, 2, "west"), true, "B2 strip route should enter (0,2) from the NW landing; path=" .. path_to_string(strip_path))
            assert_equal(path_has_step(strip_path, 0, 11, "south"), true, "B2 strip route should continue down to live-confirmed (0,11); path=" .. path_to_string(strip_path))

            local stairs_up_path = pathfinder.find_path(0x19, 1, 2, 11, 2, {})
            assert_equal(stairs_up_path ~= nil, true, "B2 NW landing should have a modeled escape route back to Stairs Up")
            assert_equal(path_has_step(stairs_up_path, 0, 2, "west"), true, "B2 Stairs Up route should enter the live-confirmed left-edge strip; path=" .. path_to_string(stairs_up_path))
            assert_equal(path_has_step(stairs_up_path, 0, 11, "south"), true, "B2 Stairs Up route should follow the strip to its live-confirmed bottom; path=" .. path_to_string(stairs_up_path))
            assert_equal(path_has_step(stairs_up_path, 1, 11, "east"), true, "B2 Stairs Up route should exit the strip through live-confirmed (0,11)->RIGHT; path=" .. path_to_string(stairs_up_path))

            local nw_stair_to_up_path = pathfinder.find_path(0x19, 1, 1, 11, 2, {})
            assert_equal(nw_stair_to_up_path ~= nil, true, "B2 Northwest Stairs Down should now have the live-confirmed escape route back to Stairs Up")
            assert_equal(path_has_step(nw_stair_to_up_path, 0, 1, "west"), true, "B2 Northwest Stairs route should enter live-confirmed (0,1); path=" .. path_to_string(nw_stair_to_up_path))
            assert_equal(path_has_step(nw_stair_to_up_path, 0, 2, "south"), true, "B2 Northwest Stairs route should descend from (0,1) to (0,2); path=" .. path_to_string(nw_stair_to_up_path))
            assert_equal(path_has_step(nw_stair_to_up_path, 0, 11, "south"), true, "B2 Northwest Stairs route should continue down to live-confirmed (0,11); path=" .. path_to_string(nw_stair_to_up_path))
            assert_equal(path_has_step(nw_stair_to_up_path, 1, 11, "east"), true, "B2 Northwest Stairs route should exit the strip through live-confirmed (0,11)->RIGHT; path=" .. path_to_string(nw_stair_to_up_path))

        end,
        function()
            if pathfinder_saved then
                restore_modules({"pathfinder"})
            end
            env.restore()
        end
    )
end

function tests.garins_grave_b4_west_return_stairs_override_boundary()
    local base = 0x1B * 5
    local data_offset = 0x1010
    local rom_bytes = {
        [base] = 0x00,      -- CPU $9000 -> file offset $1010
        [base + 1] = 0x90,
        [base + 2] = 19,    -- width 20
        [base + 3] = 19,    -- height 20
        [base + 4] = 0,
    }
    fill_packed_map(rom_bytes, data_offset, 20, 20, 0x0)
    local env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = {
            [0] = 0x20,
        },
    })

    local west_return = env.map_reader.get_walkability_details(0x1B, 0, 4)
    assert_equal(west_return.base_walkable, true, "Garin's Grave B4 west return stairs should be passable")
    assert_equal(west_return.reason, "passthrough", "B4 (0,4) should override the west-edge boundary after live 6/6 entry from (1,4)")

    local unconfirmed_edge = env.map_reader.get_walkability_details(0x1B, 0, 5)
    assert_equal(unconfirmed_edge.base_walkable, false, "nearby unconfirmed B4 west-edge cells should remain blocked")
    assert_equal(unconfirmed_edge.reason, "engine_boundary", "nearby unconfirmed B4 west-edge cells should keep boundary reason")

    local floor = env.map_reader.get_walkability_details(0x1B, 1, 4)
    assert_equal(floor.base_walkable, true, "B4 interior approach tile should stay tile-walkable")
    assert_equal(floor.reason, "tile_type", "B4 interior approach tile should not need passthrough")

    env.restore()
end

function tests.garins_grave_b4_east_stair_route_seams_are_directional()
    local env = make_env({
        memory_bytes = {
            [0] = 0x20,
        },
    })

    assert_garins_grave_b4_dir(env, "3,4", "west", "B4 (3,4).west should block after two same-origin probe_edge:RIGHT checks from normally reached (2,4)")
    assert_garins_grave_b4_dir(env, "3,4", "south", "B4 (3,4).south should block after two same-origin probe_edge:UP checks from normally reached (3,5)")
    assert_garins_grave_b4_dir(env, "4,5", "south", "B4 (4,5).south should block after two same-origin probe_edge:UP checks from normalized live (4,6)")
    assert_garins_grave_b4_dir(env, "4,5", "west", "B4 (4,5).west should block after two same-origin probe_edge:RIGHT checks from normally reached (3,5)")
    assert_garins_grave_b4_dir(env, "5,6", "west", "B4 (5,6).west should block after two same-origin probe_edge:RIGHT checks from normalized live (4,6)")
    assert_garins_grave_b4_dir(env, "5,6", "south", "B4 (5,6).south should block after two same-origin probe_edge:UP checks from normally reached (5,7)")
    assert_garins_grave_b4_dir(env, "5,6", "east", "B4 (5,6).east should block after two same-origin probe_edge:LEFT checks from normally reached (6,6)")
    assert_garins_grave_b4_dir(env, "3,7", "north", "B4 (3,7).north should block after two same-origin probe_edge:DOWN checks from normally reached (3,6)")
    assert_garins_grave_b4_dir(env, "6,5", "south", "B4 (6,5).south should block after two same-origin probe_edge:UP checks from normally reached (6,6)")
    assert_garins_grave_b4_dir(env, "1,3", "south", "B4 (1,3).south should block after two same-origin probe_edge:UP checks from normally reached (1,4)")
    assert_garins_grave_b4_dir(env, "5,3", "south", "B4 (5,3).south should block after two same-origin probe_edge:UP checks from East Stairs Up")
    assert_garins_grave_b4_dir(env, "6,3", "south", "B4 (6,3).south should block after two same-origin probe_edge:UP checks from normally reached (6,4)")
    assert_garins_grave_b4_dir(env, "4,4", "east", "B4 (4,4).east should block after two same-origin probe_edge:LEFT checks from East Stairs Up")
    assert_garins_grave_b4_dir(env, "1,5", "east", "B4 (1,5).east should block after two same-origin probe_edge:LEFT checks from normally reached (2,5)")
    assert_garins_grave_b4_dir(env, "1,5", "north", "B4 (1,5).north should block after two same-origin probe_edge:DOWN checks from normally reached (1,4)")
    assert_garins_grave_b4_dir(env, "5,5", "north", "B4 (5,5).north should block after two same-origin probe_edge:DOWN checks from East Stairs Up")
    assert_garins_grave_b4_dir(env, "6,5", "east", "B4 (6,5).east should block after two same-origin probe_edge:LEFT checks from normally reached (7,5)")
    assert_garins_grave_b4_dir(env, "6,5", "north", "B4 (6,5).north should block after two same-origin probe_edge:DOWN checks from normally reached (6,4)")
    assert_garins_grave_b4_dir(env, "2,6", "east", "B4 (2,6).east should block after two same-origin probe_edge:LEFT checks from normally reached (3,6)")
    assert_garins_grave_b4_dir(env, "2,6", "north", "B4 (2,6).north should block after two same-origin probe_edge:DOWN checks from normally reached (2,5)")
    assert_garins_grave_b4_dir(env, "3,7", "east", "B4 (3,7).east should block after two same-origin probe_edge:LEFT checks from normally reached (4,7)")
    assert_garins_grave_b4_dir(env, "7,7", "north", "B4 (7,7).north should block after two same-origin probe_edge:DOWN checks from normally reached (7,6)")
    assert_garins_grave_b4_dir(env, "7,7", "west", "B4 (7,7).west should block after two same-origin probe_edge:RIGHT checks from normally reached (6,7)")
    assert_garins_grave_b4_dir(env, "5,2", "east", "B4 (5,2).east should block after two same-origin probe_edge:LEFT checks from normally reached (6,2)")
    assert_garins_grave_b4_dir(env, "3,1", "east", "B4 (3,1).east should block after two same-origin probe_edge:LEFT checks from normally reached (4,1)")
    assert_garins_grave_b4_dir(env, "3,1", "south", "B4 (3,1).south should block after two same-origin probe_edge:UP checks from normally reached (3,2)")
    assert_garins_grave_b4_dir(env, "2,2", "east", "B4 (2,2).east should block after two same-origin probe_edge:LEFT checks from normally reached (3,2)")

    local dirs = env.map_reader.get_directional_blocks(0x1B)
    assert_equal((dirs["4,7"] or {}).north, nil, "B4 (4,7).north should stay open after later live movement from (4,6)->DOWN succeeded")
    assert_equal((dirs["5,2"] or {}).west, nil, "B4 (5,2).west should stay unmodeled because the only block evidence was autowalk retry noise")
    assert_equal((dirs["7,1"] or {}).west, nil, "B4 (7,1).west should stay unmodeled because it only appeared during autowalk reroute evidence")
    assert_equal((dirs["6,3"] or {}).north, nil, "B4 (6,3).north should stay unmodeled because the down probe was interrupted by route retry noise")

    env.restore()
end

function tests.garins_grave_b3_hidden_bridge_to_southwest_exit_is_passthrough()
    local base = 0x1A * 5
    local data_offset = 0x1010
    local rom_bytes = {
        [base] = 0x00,      -- CPU $9000 -> file offset $1010
        [base + 1] = 0x90,
        [base + 2] = 19,    -- width 20
        [base + 3] = 19,    -- height 20
        [base + 4] = 0,
    }
    fill_packed_map(rom_bytes, data_offset, 20, 20, 0x0)
    set_packed_block(rom_bytes, data_offset, 20, 1, 2, 0x1)
    set_packed_block(rom_bytes, data_offset, 20, 2, 2, 0x1)
    set_packed_block(rom_bytes, data_offset, 20, 3, 2, 0x1)
    set_packed_block(rom_bytes, data_offset, 20, 4, 14, 0xF)

    local env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = {
            [0] = 0x20,
        },
    })

    assert_equal(env.map_reader.get_raw_block_id(0x1A, 4, 14), 0x0F, "test fixture should mark B3 (4,14) as the explicit bridge tile")

    local bridge = env.map_reader.get_walkability_details(0x1A, 4, 14)
    assert_equal(bridge.base_walkable, true, "B3 (4,14) should be passable after live 6/6 entry from (4,13)")
    assert_equal(bridge.reason, "passthrough", "B3 (4,14) should record passthrough as its walkability source")

    local continuation = env.map_reader.get_walkability_details(0x1A, 4, 15)
    assert_equal(continuation.base_walkable, true, "B3 (4,15) should remain ordinary walkable floor")
    assert_equal(continuation.reason, "tile_type", "B3 (4,15) should not need a passthrough override")

    local left_edge_entry = env.map_reader.get_walkability_details(0x1A, 0, 2)
    assert_equal(left_edge_entry.effective_walkable, true, "B3 (0,2) should be walkable after the chest-side return-route dig")
    assert_equal(left_edge_entry.reason, "passthrough", "B3 (0,2) should record passthrough instead of generic engine_boundary")

    local left_edge_escape = env.map_reader.get_walkability_details(0x1A, 0, 3)
    assert_equal(left_edge_escape.effective_walkable, true, "B3 (0,3) should be walkable after repeated live movement from (0,2)->DOWN")
    assert_equal(left_edge_escape.reason, "passthrough", "B3 (0,3) should record passthrough instead of generic engine_boundary")

    local left_edge_lower = env.map_reader.get_walkability_details(0x1A, 0, 4)
    assert_equal(left_edge_lower.effective_walkable, true, "B3 (0,4) should be walkable after live return-route position snapshots")
    assert_equal(left_edge_lower.reason, "passthrough", "B3 (0,4) should record passthrough instead of generic engine_boundary")

    local left_edge_bottom = env.map_reader.get_walkability_details(0x1A, 0, 5)
    assert_equal(left_edge_bottom.effective_walkable, true, "B3 (0,5) should be walkable after live return-route position snapshots")
    assert_equal(left_edge_bottom.reason, "passthrough", "B3 (0,5) should record passthrough instead of generic engine_boundary")

    local left_edge_turn = env.map_reader.get_walkability_details(0x1A, 0, 6)
    assert_equal(left_edge_turn.effective_walkable, true, "B3 (0,6) should be walkable after same-origin return-route probe from (0,5)->DOWN")
    assert_equal(left_edge_turn.reason, "passthrough", "B3 (0,6) should record passthrough instead of generic engine_boundary")

    local chest_south = env.map_reader.get_walkability_details(0x1A, 1, 2)
    assert_equal(chest_south.effective_walkable, true, "B3 (1,2) should be walkable after live movement from the west chest")
    assert_equal(chest_south.reason, "passthrough", "B3 (1,2) should record passthrough as its walkability source")

    local chest_southeast = env.map_reader.get_walkability_details(0x1A, 2, 2)
    assert_equal(chest_southeast.effective_walkable, true, "B3 (2,2) should be walkable after live movement from (1,2)->RIGHT")
    assert_equal(chest_southeast.reason, "passthrough", "B3 (2,2) should record passthrough as its walkability source")

    local blocked_east_wall = env.map_reader.get_walkability_details(0x1A, 3, 2)
    assert_equal(blocked_east_wall.effective_walkable, false, "B3 (3,2) should stay blocked; live (2,2)->RIGHT did not move")

    local top_entry = env.map_reader.get_walkability_details(0x1A, 8, 0)
    assert_equal(top_entry.effective_walkable, true, "B3 (8,0) should be walkable after same-origin return-route probe from (8,1)->UP")
    assert_equal(top_entry.reason, "passthrough", "B3 (8,0) should record passthrough instead of generic engine_boundary")

    local top_west = env.map_reader.get_walkability_details(0x1A, 9, 0)
    assert_equal(top_west.effective_walkable, true, "B3 (9,0) should be walkable after live west-chest return movement from (10,0)->LEFT")
    assert_equal(top_west.reason, "passthrough", "B3 (9,0) should record passthrough as its walkability source")

    local top_east = env.map_reader.get_walkability_details(0x1A, 10, 0)
    assert_equal(top_east.effective_walkable, true, "B3 (10,0) should be walkable after repeated live movement across the top-row seam")
    assert_equal(top_east.reason, "passthrough", "B3 (10,0) should record passthrough as its walkability source")

    save_module("pathfinder")
    package.loaded["pathfinder"] = nil
    local pathfinder = require "pathfinder"
    local top_seam_path = pathfinder.find_path(0x1A, 10, 0, 9, 0, {})
    assert_equal(top_seam_path ~= nil, true, "B3 should still route across the live-confirmed top-row seam from (10,0) to (9,0)")
    local top_entry_path = pathfinder.find_path(0x1A, 8, 1, 8, 0, {})
    assert_equal(top_entry_path ~= nil, true, "B3 should route from (8,1) into the live-confirmed (8,0) top-edge entry")
    assert_equal(path_has_step(top_entry_path, 8, 0, "north"), true, "B3 top return path should step north into live-confirmed (8,0); path=" .. path_to_string(top_entry_path))
    local chest_to_south_cell_path = pathfinder.find_path(0x1A, 1, 1, 1, 2, {})
    assert_equal(chest_to_south_cell_path ~= nil, true, "B3 west chest should route into live-confirmed false-wall cell (1,2)")
    assert_equal(path_has_step(chest_to_south_cell_path, 1, 2, "south"), true, "B3 west chest direct route should step down into live-confirmed (1,2)")
    local false_wall_pocket_path = pathfinder.find_path(0x1A, 1, 2, 2, 2, {})
    assert_equal(false_wall_pocket_path ~= nil, true, "B3 false-wall pocket should route from (1,2) to live-confirmed (2,2)")
    assert_equal(path_has_step(false_wall_pocket_path, 2, 2, "east"), true, "B3 false-wall pocket should step east into live-confirmed (2,2)")
    local left_edge_seam_path = pathfinder.find_path(0x1A, 0, 2, 0, 3, {})
    assert_equal(left_edge_seam_path ~= nil, true, "B3 left edge should route across the live-confirmed (0,2)->DOWN seam")
    assert_equal(path_has_step(left_edge_seam_path, 0, 3, "south"), true, "B3 left edge direct route should step down into live-confirmed (0,3)")
    local chest_escape_path = pathfinder.find_path(0x1A, 1, 1, 14, 1, {})
    assert_equal(chest_escape_path ~= nil, true, "B3 west chest should now have the live-confirmed one-way escape route back to Northwest Stairs Up")
    assert_equal(path_has_step(chest_escape_path, 0, 2, "west"), true, "B3 chest escape should enter the live-confirmed left-edge strip; path=" .. path_to_string(chest_escape_path))
    assert_equal(path_has_step(chest_escape_path, 0, 6, "south"), true, "B3 chest escape should continue through live-confirmed (0,6); path=" .. path_to_string(chest_escape_path))
    restore_modules({"pathfinder"})

    env.restore()
end

function tests.garins_grave_b2_southwest_stair_route_edges_are_directional()
    local env = make_env({
        memory_bytes = {
            [0] = 0x20,
        },
    })

    assert_garins_grave_b2_dir(env, "2,10", "east", "B2 (2,10) should block east approach after 5/5 verifier from (3,10)")
    assert_garins_grave_b2_dir(env, "2,10", "west", "B2 (2,10).west should block after normal-route Northwest Stairs Down attempt plus same-origin probe_edge:RIGHT from (1,10)")
    assert_garins_grave_b2_dir(env, "3,9", "south", "B2 (3,9) should block south approach after 5/5 verifier from (3,10)")
    assert_garins_grave_b2_dir(env, "2,3", "west", "B2 (2,3) should block west approach after 5/5 verifier from (1,3)")
    assert_garins_grave_b2_dir(env, "2,3", "north", "B2 (2,3) should block north approach after three fresh-start probe_edge:DOWN checks from (2,2) all blocked while reverse probe_edge_verify:UP,5 from (2,3) blocked 5/5")
    assert_garins_grave_b2_dir(env, "2,1", "east", "B2 (2,1) should block east approach after three fresh-start probe_edge:LEFT checks from (3,1) all blocked while reverse probe_edge_verify:RIGHT,5 from (2,1) moved 6/6")
    assert_garins_grave_b2_dir(env, "2,1", "south", "B2 (2,1) should block south approach after same-origin probe_edge_verify:UP,5 from (2,2)")
    assert_garins_grave_b2_dir(env, "2,1", "west", "B2 (2,1).west should block after same-origin probe_edge:RIGHT from (1,1) during the B2 west-chest escape cleanup")
    assert_garins_grave_b2_dir(env, "2,2", "east", "B2 (2,2) should block east approach after same-origin probe_edge_verify:LEFT,5 from (3,2)")
    assert_garins_grave_b2_dir(env, "2,2", "west", "B2 (2,2).west should block after same-origin probe_edge:RIGHT from the NW landing (1,2)")
    assert_garins_grave_b2_dir(env, "1,2", "east", "B2 (1,2) should block east approach after three fresh-start probe_edge:LEFT checks from (2,2) all blocked while reverse probe_edge_verify:RIGHT,5 from (1,2) moved 6/6")
    assert_garins_grave_b2_dir(env, "1,2", "north", "B2 (1,2).north should block after same-origin probe_edge:DOWN from (1,1) during the B2 west-chest escape cleanup")
    assert_garins_grave_b2_dir(env, "1,2", "south", "B2 (1,2).south should block after same-origin probe_edge:UP from (1,3) during the B2 west-chest escape cleanup")
    assert_garins_grave_b2_dir(env, "2,4", "west", "B2 (2,4) should block west approach after 5/5 verifier from (1,4)")
    assert_garins_grave_b2_dir(env, "2,4", "east", "B2 (2,4) should block east approach after clean same-origin probe_edge_verify:LEFT,5 from (3,4)")
    assert_garins_grave_b2_dir(env, "2,5", "west", "B2 (2,5) should block west approach after 5/5 verifier from (1,5)")
    assert_garins_grave_b2_dir(env, "2,5", "east", "B2 (2,5) should block east approach after same-origin probe_edge_verify:LEFT,5 from (3,5)")
    assert_garins_grave_b2_dir(env, "2,6", "west", "B2 (2,6) should block west approach after 5/5 verifier from (1,6)")
    assert_garins_grave_b2_dir(env, "2,6", "east", "B2 (2,6) should block east approach after same-origin probe_edge_verify:LEFT,5 from (3,6)")
    assert_garins_grave_b2_dir(env, "2,7", "west", "B2 (2,7) should block west approach after 5/5 verifier from (1,7)")
    assert_garins_grave_b2_dir(env, "2,7", "east", "B2 (2,7) should block east approach after clean same-origin probe_edge_verify:LEFT,5 from (3,7)")
    assert_garins_grave_b2_dir(env, "4,1", "south", "B2 (4,1) should block south approach after same-origin probe_edge_verify:UP,5 from (4,2)")
    assert_garins_grave_b2_dir(env, "4,1", "west", "B2 (4,1) should block west approach after same-origin probe_edge_verify:RIGHT,5 from (3,1)")
    assert_garins_grave_b2_dir(env, "5,1", "south", "B2 (5,1) should block south approach after three fresh-start probe_edge:UP checks from (5,2) all blocked while reverse probe_edge_verify:DOWN,5 from (5,1) moved 6/6")
    assert_garins_grave_b2_dir(env, "3,3", "north", "B2 (3,3) should block north approach after same-origin probe_edge_verify:DOWN,5 from (3,2)")
    assert_garins_grave_b2_dir(env, "3,3", "south", "B2 (3,3) should block south approach after same-origin probe_edge_verify:UP,5 from (3,4)")
    assert_garins_grave_b2_dir(env, "4,3", "north", "B2 (4,3) should block north approach after same-origin probe_edge_verify:DOWN,5 from (4,2)")
    assert_garins_grave_b2_dir(env, "4,3", "south", "B2 (4,3) should block south approach after same-origin probe_edge_verify:UP,5 from (4,4)")
    assert_garins_grave_b2_dir(env, "5,3", "north", "B2 (5,3) should block north approach after same-origin probe_edge_verify:DOWN,5 from (5,2)")
    assert_garins_grave_b2_dir(env, "5,3", "south", "B2 (5,3) should block south approach after same-origin probe_edge_verify:UP,5 from (5,4)")
    assert_garins_grave_b2_dir(env, "6,3", "south", "B2 (6,3) should block south approach after same-origin probe_edge_verify:UP,5 from (6,4)")
    assert_garins_grave_b2_dir(env, "7,3", "south", "B2 (7,3) should block south approach after same-origin probe_edge_verify:UP,5 from (7,4)")
    assert_garins_grave_b2_dir(env, "2,8", "east", "B2 (2,8) should block east approach after clean same-origin probe_edge_verify:LEFT,5 from (3,8)")
    assert_garins_grave_b2_dir(env, "3,9", "north", "B2 (3,9) should block north approach after 5/5 verifier from (3,8)")
    assert_garins_grave_b2_dir(env, "4,9", "north", "B2 (4,9) should block north approach after 5/5 verifier from (4,8)")
    assert_garins_grave_b2_dir(env, "4,9", "south", "B2 (4,9) should block south approach after 5/5 verifier from (4,10)")
    assert_garins_grave_b2_dir(env, "5,9", "north", "B2 (5,9) should block north approach after 5/5 verifier from (5,8)")
    assert_garins_grave_b2_dir(env, "5,9", "south", "B2 (5,9).south should block after normal-route Northwest Stairs Down attempts plus same-origin probe_edge:UP from (5,10)")
    assert_garins_grave_b2_dir(env, "6,9", "north", "B2 (6,9) should block north approach after 5/5 verifier from (6,8)")
    assert_garins_grave_b2_dir(env, "6,7", "south", "B2 (6,7) should block south approach after repeated fresh-start probe_edge:UP checks from (6,8) while reverse probe_edge_verify:DOWN,5 from (6,7) stayed passable")
    assert_garins_grave_b2_dir(env, "7,9", "north", "B2 (7,9) should block north approach after 5/5 verifier from (7,8)")
    assert_garins_grave_b2_dir(env, "8,3", "south", "B2 (8,3) should block south approach after same-origin probe_edge_verify:UP,5 from (8,4)")
    assert_garins_grave_b2_dir(env, "8,5", "east", "B2 (8,5) should block east approach after same-origin probe_edge_verify:LEFT,5 from (9,5)")
    assert_garins_grave_b2_dir(env, "8,5", "west", "B2 (8,5) should block west approach after same-origin probe_edge_verify:RIGHT,5 from (7,5)")
    assert_garins_grave_b2_dir(env, "8,5", "north", "B2 (8,5) should block north approach after same-origin probe_edge_verify:DOWN,8 from (8,4)")
    assert_garins_grave_b2_dir(env, "8,6", "east", "B2 (8,6) should block east approach after fresh same-origin probe_edge_verify:LEFT,5 from (9,6) while the reverse face stayed passable 6/6 from (8,6)")
    assert_garins_grave_b2_dir(env, "8,6", "west", "B2 (8,6) should block west approach after same-origin probe_edge_verify:RIGHT,5 from (7,6)")
    assert_garins_grave_b2_dir(env, "8,7", "west", "B2 (8,7) should block west approach after same-origin probe_edge_verify:RIGHT,5 from (7,7)")
    assert_garins_grave_b2_dir(env, "8,8", "east", "B2 (8,8).east should block after Central Stairs Down route retry plus same-origin probe_edge:LEFT from (9,8)")
    assert_garins_grave_b2_dir(env, "8,8", "south", "B2 (8,8) should block south approach after reverse same-origin probe_edge_verify:UP,5 from (8,9) confirmed the lower face 5/5")
    assert_garins_grave_b2_dir(env, "8,8", "west", "B2 (8,8) should block west approach after repeated fresh-start probe_edge:RIGHT checks from (7,8) while reverse probe_edge_verify:LEFT,5 from (8,8) stayed passable")
    assert_garins_grave_b2_dir(env, "8,9", "north", "B2 (8,9) should block north approach after three fresh-start probe_edge:DOWN checks from (8,8) all blocked while repeated verifier stayed mixed")
    assert_garins_grave_b2_dir(env, "8,9", "west", "B2 (8,9) should block west approach after reverse same-origin probe_edge_verify:RIGHT,5 from (7,9) confirmed the lower face 5/5")
    assert_garins_grave_b2_dir(env, "7,9", "west", "B2 (7,9) should block west approach after reverse same-origin probe_edge_verify:RIGHT,5 from (6,9) confirmed the lower face 5/5")
    assert_garins_grave_b2_dir(env, "6,9", "west", "B2 (6,9) should block west approach after reverse same-origin probe_edge_verify:RIGHT,5 from (5,9) confirmed the lower face 5/5")
    assert_garins_grave_b2_dir(env, "9,7", "north", "B2 (9,7) should block north approach after same-origin probe_edge_verify:DOWN,5 from (9,6)")
    assert_garins_grave_b2_dir(env, "9,7", "south", "B2 (9,7) should block south approach after same-origin probe_edge_verify:UP,5 from (9,8)")
    assert_garins_grave_b2_dir(env, "9,9", "north", "B2 (9,9) should block north approach after same-origin probe_edge_verify:DOWN,5 from (9,8)")
    assert_garins_grave_b2_dir(env, "10,5", "east", "B2 (10,5) should block east approach after same-origin probe_edge_verify:LEFT,5 from (11,5)")
    assert_garins_grave_b2_dir(env, "10,5", "north", "B2 (10,5) should block north approach after repeated fresh-start probe_edge:DOWN checks from (10,4)")
    assert_garins_grave_b2_dir(env, "10,7", "south", "B2 (10,7) should block south approach after same-origin probe_edge_verify:UP,5 from live (10,8) while reverse probe_edge_verify:DOWN,5 from (10,7) stayed passable")
    assert_garins_grave_b2_dir(env, "9,9", "south", "B2 (9,9) should block south approach after 5/5 verifier from (9,10)")
    assert_garins_grave_b2_dir(env, "10,5", "west", "B2 (10,5) should block west approach after same-origin probe_edge_verify:RIGHT,5 from (9,5)")
    assert_garins_grave_b2_dir(env, "10,6", "east", "B2 (10,6) should block east approach after same-origin probe_edge_verify:LEFT,5 from (11,6)")
    assert_garins_grave_b2_dir(env, "10,9", "north", "B2 (10,9) should block north approach after same-origin probe_edge_verify:DOWN,5 from live (10,8)")
    assert_garins_grave_b2_dir(env, "10,9", "south", "B2 (10,9) should block south approach after 5/5 verifier from (10,10)")
    assert_garins_grave_b2_dir(env, "11,7", "south", "B2 (11,7) should block south approach after same-origin probe_edge_verify:UP,5 from (11,8)")
    assert_garins_grave_b2_dir(env, "12,5", "east", "B2 (12,5) should block east approach after 5/5 verifier from (13,5)")
    assert_garins_grave_b2_dir(env, "12,5", "west", "B2 (12,5) should block west approach after same-origin probe_edge_verify:RIGHT,5 from (11,5)")
    assert_garins_grave_b2_dir(env, "12,6", "east", "B2 (12,6).east should block after Central Stairs Down route retry plus same-origin probe_edge:LEFT from (13,6)")
    assert_garins_grave_b2_dir(env, "12,6", "west", "B2 (12,6) should block west approach after same-origin probe_edge_verify:RIGHT,5 from (11,6)")
    assert_garins_grave_b2_dir(env, "12,7", "north", "B2 (12,7) should block north approach after same-origin probe_edge_verify:DOWN,5 from (12,6) blocked 5/5")
    assert_garins_grave_b2_dir(env, "11,9", "north", "B2 (11,9) should block north approach after same-origin probe_edge_verify:DOWN,5 from (11,8)")
    assert_garins_grave_b2_dir(env, "12,7", "east", "B2 (12,7) should block east approach after 5/5 verifier from (13,7)")
    assert_garins_grave_b2_dir(env, "12,7", "south", "B2 (12,7) should block south approach after same-origin probe_edge_verify:UP,5 from (12,8)")
    assert_garins_grave_b2_dir(env, "12,9", "north", "B2 (12,9) should block north approach after same-origin probe_edge_verify:DOWN,5 from (12,8)")
    assert_garins_grave_b2_dir(env, "12,9", "east", "B2 (12,9) should block east approach after clean same-origin probe_edge_verify:LEFT,5 from (13,9)")
    assert_garins_grave_b2_dir(env, "12,9", "south", "B2 (12,9) should block south approach after 5/5 verifier from (12,10)")
    assert_garins_grave_b2_dir(env, "11,7", "north", "B2 (11,7) should block north approach after same-origin probe_edge_verify:DOWN,5 from (11,6)")
    assert_garins_grave_b2_dir(env, "7,9", "east", "B2 (7,9) should block east approach after three fresh-start probe_edge:LEFT checks from (8,9) all blocked while repeated verifier stayed mixed")
    assert_garins_grave_b2_dir(env, "6,9", "east", "B2 (6,9) should block east approach after three fresh-start probe_edge:LEFT checks from (7,9) all blocked while repeated verifier stayed mixed")
    assert_garins_grave_b2_dir(env, "5,9", "east", "B2 (5,9) should block east approach after three fresh-start probe_edge:LEFT checks from (6,9) all blocked while repeated verifier stayed mixed")

    local dirs = env.map_reader.get_directional_blocks(0x19)
    assert_garins_grave_b2_dir(env, "2,8", "west", "B2 (2,8).west should block after same-origin probe_edge:RIGHT from (1,8) during the B2 west-chest escape cleanup")
    assert_garins_grave_b2_dir(env, "1,9", "north", "B2 (1,9).north should block after same-origin probe_edge:DOWN from (1,8) during the B2 west-chest escape cleanup")
    assert_garins_grave_b2_dir(env, "1,9", "south", "B2 (1,9) should block south approach after same-origin probe_edge_verify:UP,5 from (1,10) blocked 5/5")
    assert_garins_grave_b2_dir(env, "1,9", "west", "B2 (1,9).west should block after same-origin probe_edge:RIGHT from (0,9) during the B2 northwest-stair escape cleanup")
    assert_garins_grave_b2_dir(env, "2,10", "south", "B2 (2,10) should block south approach after same-origin probe_edge_verify:UP,5 from (2,11) blocked 5/5")
    assert_garins_grave_b2_dir(env, "6,9", "south", "B2 (6,9) should block south approach after same-origin probe_edge_verify:UP,5 from (6,10) blocked 5/5")
    assert_garins_grave_b2_dir(env, "7,9", "south", "B2 (7,9) should block south approach after same-origin probe_edge_verify:UP,5 from (7,10) blocked 5/5")
    assert_garins_grave_b2_dir(env, "8,9", "south", "B2 (8,9) should block south approach after same-origin probe_edge_verify:UP,5 from (8,10) blocked 5/5")
    assert_garins_grave_b2_dir(env, "8,3", "east", "B2 (8,3).east should block after same-origin probe_edge_verify:LEFT,5 from (9,3) blocked 5/5 while reverse probe_edge_verify:8,3,RIGHT,5 moved 6/6")
    assert_equal((dirs["9,3"] or {}).south, nil, "B2 (9,3).south should stay open after same-origin probe_edge_verify:UP,5 from (9,4) moved 6/6")
    assert_garins_grave_b2_dir(env, "10,1", "east", "B2 (10,1).east should block after three fresh-start probe_edge:LEFT checks from real (11,1) all blocked while reverse probe_edge_verify:10,1,RIGHT,5 moved 6/6")
    assert_garins_grave_b2_dir(env, "10,2", "east", "B2 (10,2).east should block after same-origin probe_edge_verify:LEFT,5 from (11,2) blocked 5/5 while reverse probe_edge_verify:10,2,RIGHT,5 moved 6/6")
    assert_garins_grave_b2_dir(env, "11,3", "north", "B2 (11,3).north should block after same-origin probe_edge_verify:DOWN,5 from (11,2) blocked 5/5")
    assert_garins_grave_b2_dir(env, "11,3", "east", "B2 (11,3).east should block after same-origin probe_edge_verify:LEFT,5 from (12,3) blocked 5/5")
    assert_garins_grave_b2_dir(env, "11,10", "east", "B2 (11,10).east should block after three fresh-start probe_edge:LEFT checks from (12,10) all blocked while reverse probe_edge_verify:11,10,RIGHT,5 moved 6/6")
    assert_equal((dirs["10,6"] or {}).west, nil, "B2 (10,6).west should stay open after same-origin probe_edge_verify:RIGHT,5 from (9,6) moved 6/6")
    assert_garins_grave_b2_dir(env, "12,3", "north", "B2 (12,3).north should block after normal-route Central Stairs Down attempt plus two same-origin probe_edge:DOWN checks from (12,2)")
    assert_garins_grave_b2_dir(env, "12,3", "east", "B2 (12,3).east should block after same-origin probe_edge_verify:LEFT,5 from (13,3) blocked 5/5")
    assert_garins_grave_b2_dir(env, "12,3", "west", "B2 (12,3).west should block after three fresh-start probe_edge:RIGHT checks from real (11,3) all blocked while repeated verifier stayed teleport-artifact mixed")
    assert_garins_grave_b2_dir(env, "12,4", "east", "B2 (12,4).east should block after normal-route Central Stairs Down attempt plus same-origin probe_edge:LEFT from (13,4)")

    env.restore()
end

function tests.garins_grave_b3_southwest_pocket_seams_are_directional()
    local env = make_env({
        memory_bytes = {
            [0] = 0x20,
        },
    })

    assert_garins_grave_b3_dir(env, "5,2", "west", "B3 (5,2) should block west approach after the live dig's clean 5/5 verifier from (4,2)")
    assert_garins_grave_b3_dir(env, "6,2", "north", "B3 (6,2) should block north approach after the live dig's clean 5/5 verifier from (6,1)")
    assert_garins_grave_b3_dir(env, "2,7", "south", "B3 (2,7) should block south approach after the upper-left verifier settled at a clean 5/5 from (2,8)")
    assert_garins_grave_b3_dir(env, "2,7", "north", "B3 (2,7) should block north approach after the live dig's clean 5/5 verifier from (2,6)")
    assert_garins_grave_b3_dir(env, "3,5", "north", "B3 (3,5) should block north approach after the live dig's clean 5/5 verifier from (3,4)")
    assert_garins_grave_b3_dir(env, "3,5", "west", "B3 (3,5) should block west approach after the upper-pocket verifier settled at a clean 5/5 from (2,5)")
    assert_garins_grave_b3_dir(env, "3,6", "west", "B3 (3,6) should block west approach after the upper-pocket verifier settled at a clean 5/5 from (2,6)")
    assert_garins_grave_b3_dir(env, "3,7", "west", "B3 (3,7) should block west approach after the upper-pocket verifier settled at a clean 5/5 from (2,7)")
    assert_garins_grave_b3_dir(env, "1,8", "east", "B3 (1,8) should block east approach after the upper-left verifier settled at a clean 5/5 from (2,8)")
    assert_garins_grave_b3_dir(env, "1,9", "east", "B3 (1,9) should block east approach after the upper-left verifier settled at a clean 5/5 from (2,9)")
    assert_garins_grave_b3_dir(env, "1,10", "east", "B3 (1,10) should block east approach after the live dig's clean 5/5 verifier from (2,10)")
    assert_garins_grave_b3_dir(env, "1,11", "east", "B3 (1,11) should block east approach after the live dig's clean 5/5 verifier from (2,11)")
    assert_garins_grave_b3_dir(env, "1,12", "east", "B3 (1,12) should block east approach after 5/5 verifier from (2,12)")
    assert_garins_grave_b3_dir(env, "1,13", "east", "B3 (1,13) should block east approach after 5/5 verifier from (2,13)")
    assert_garins_grave_b3_dir(env, "1,14", "east", "B3 (1,14) should block east approach after the live dig's strict 8/8 verifier from (2,14)")
    assert_garins_grave_b3_dir(env, "1,16", "east", "B3 (1,16) should block east approach after the later left-pocket reroute settled at a clean 5/5 verifier from (2,16)")
    assert_garins_grave_b3_dir(env, "1,17", "east", "B3 (1,17) should block east approach after the live dig's clean 5/5 verifier from (2,17)")
    assert_garins_grave_b3_dir(env, "2,15", "north", "B3 (2,15) should block north approach after the live dig's clean 5/5 verifier from (2,14)")
    assert_garins_grave_b3_dir(env, "2,15", "south", "B3 (2,15) should block south approach after the later left-pocket reroute settled at a clean 5/5 verifier from (2,16)")
    assert_garins_grave_b3_dir(env, "2,15", "east", "B3 (2,15) should block east approach after the later left-pocket reroute settled at a clean 5/5 verifier from (3,15)")
    assert_garins_grave_b3_dir(env, "2,18", "north", "B3 (2,18) should block north approach after the live dig's clean 5/5 verifier from (2,17)")
    assert_garins_grave_b3_dir(env, "8,12", "south", "B3 (8,12) should block south approach after 5/5 verifier from (8,13)")
    assert_garins_grave_b3_dir(env, "9,12", "south", "B3 (9,12) should block south approach after 5/5 verifier from (9,13)")
    assert_garins_grave_b3_dir(env, "6,12", "south", "B3 (6,12) should block south approach after a clean 5/5 verifier from (6,13)")
    assert_garins_grave_b3_dir(env, "7,12", "south", "B3 (7,12) should block south approach after a clean 5/5 verifier from (7,13)")
    assert_garins_grave_b3_dir(env, "3,13", "south", "B3 (3,13) should block south approach after the live dig's strict 8/8 verifier from (3,14)")
    assert_garins_grave_b3_dir(env, "3,13", "west", "B3 (3,13) should block west approach after the live dig's clean 5/5 verifier from (2,13)")
    assert_garins_grave_b3_dir(env, "3,8", "west", "B3 (3,8) should block west approach after the upper-route verifier settled at a clean 5/5 from (2,8)")
    assert_garins_grave_b3_dir(env, "3,9", "west", "B3 (3,9) should block west approach after the upper-route verifier settled at a clean 5/5 from (2,9)")
    assert_garins_grave_b3_dir(env, "3,10", "west", "B3 (3,10) should block west approach after the lower-lip verifier settled at a clean 5/5 from (2,10)")
    assert_garins_grave_b3_dir(env, "3,11", "west", "B3 (3,11) should block west approach after the lower-lip verifier settled at a clean 5/5 from (2,11)")
    assert_garins_grave_b3_dir(env, "3,12", "west", "B3 (3,12) should block west approach after the cleaned reroute verifier settled at a clean 5/5 from (2,12)")
    assert_garins_grave_b3_dir(env, "3,18", "north", "B3 (3,18) should block north approach after the live dig's clean 5/5 verifier from (3,17)")
    assert_garins_grave_b3_dir(env, "4,18", "north", "B3 (4,18) should block north approach after the live dig's clean 5/5 verifier from (4,17)")
    assert_garins_grave_b3_dir(env, "5,3", "west", "B3 (5,3) should block west approach after the upper-pocket verifier settled at a clean 5/5 from (4,3)")
    assert_garins_grave_b3_dir(env, "5,4", "west", "B3 (5,4) should block west approach after the upper-pocket verifier settled at a clean 5/5 from (4,4)")
    assert_garins_grave_b3_dir(env, "5,4", "east", "B3 (5,4) should block east approach after the 2026-06-05 direct 5/5 verifier from (6,4)")
    assert_garins_grave_b3_dir(env, "4,5", "north", "B3 (4,5) should block north approach after the upper-pocket verifier settled at a clean 5/5 from (4,4)")
    assert_garins_grave_b3_dir(env, "4,16", "west", "B3 (4,16) should block west approach after the refreshed resume verifier settled at a clean 5/5 from (3,16)")
    assert_garins_grave_b3_dir(env, "10,13", "west", "B3 (10,13) should block west approach after the repeated route lane finally settled at a clean 5/5 verifier from (9,13)")
    assert_garins_grave_b3_dir(env, "5,13", "east", "B3 (5,13) should block east approach after a clean 5/5 verifier from (6,13)")
    assert_garins_grave_b3_dir(env, "5,13", "west", "B3 (5,13) should block west approach after the 2026-06-05 direct 5/5 verifier from (4,13)")
    assert_garins_grave_b3_dir(env, "8,15", "east", "B3 (8,15) should block east approach after the south-loop verifier settled at a clean 5/5 from (9,15)")
    assert_garins_grave_b3_dir(env, "8,16", "east", "B3 (8,16) should block east approach after the south-loop verifier settled at a clean 5/5 from (9,16)")
    assert_garins_grave_b3_dir(env, "10,14", "west", "B3 (10,14) should block west approach after a clean 5/5 verifier from (9,14)")
    assert_garins_grave_b3_dir(env, "10,15", "west", "B3 (10,15) should block west approach after a clean 5/5 verifier from (9,15)")
    assert_garins_grave_b3_dir(env, "10,16", "west", "B3 (10,16) should block west approach after a clean 5/5 verifier from (9,16)")
    assert_garins_grave_b3_dir(env, "10,17", "west", "B3 (10,17) should block west approach after a clean 5/5 verifier from (9,17)")
    assert_garins_grave_b3_dir(env, "9,18", "north", "B3 (9,18) should block north approach after the live dig's clean 5/5 verifier from (9,17)")
    assert_garins_grave_b3_dir(env, "5,18", "north", "B3 (5,18) should block north approach after a clean 5/5 verifier from (5,17)")
    assert_garins_grave_b3_dir(env, "6,2", "south", "B3 (6,2) should block south approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "8,2", "south", "B3 (8,2) should block south approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "5,3", "east", "B3 (5,3) should block east approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "7,3", "south", "B3 (7,3) should block south approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "7,3", "east", "B3 (7,3) should block east approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "7,3", "west", "B3 (7,3) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "9,3", "south", "B3 (9,3) should block south approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "9,3", "west", "B3 (9,3) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "12,3", "south", "B3 (12,3).south should block after lower-stair object-pruning probes from (12,4)->UP")
    assert_garins_grave_b3_dir(env, "13,3", "south", "B3 (13,3).south should block after lower-stair object-pruning probes from (13,4)->UP")
    assert_garins_grave_b3_dir(env, "14,3", "south", "B3 (14,3).south should block after lower-stair object-pruning probes from (14,4)->UP")
    assert_garins_grave_b3_dir(env, "3,1", "east", "B3 (3,1).east should block after post-reload Cursed Belt route probe from (4,1)->LEFT")
    assert_garins_grave_b3_dir(env, "9,1", "east", "B3 (9,1).east should block after Northwest Stairs Up pocket same-origin probe from (10,1)->LEFT")
    assert_garins_grave_b3_dir(env, "9,1", "north", "B3 (9,1).north should block after 2026-06-16 top-row same-origin probes from (9,0)->DOWN")
    assert_garins_grave_b3_dir(env, "9,1", "west", "B3 (9,1).west should block after return-route same-origin probe from (8,1)->RIGHT")
    assert_garins_grave_b3_dir(env, "11,1", "west", "B3 (11,1).west should block after post-reload return-route probe from (10,1)->RIGHT")
    assert_garins_grave_b3_dir(env, "13,1", "east", "B3 (13,1).east should block after 2026-06-16 Northwest Stairs Up probes from (14,1)->LEFT")
    assert_garins_grave_b3_dir(env, "5,2", "north", "B3 (5,2).north should block after same-origin object-pruning probe from (5,1)->DOWN")
    assert_garins_grave_b3_dir(env, "9,2", "east", "B3 (9,2).east should block after 2026-06-16 hidden-candidate probe from (10,2)->LEFT")
    assert_garins_grave_b3_dir(env, "1,3", "north", "B3 (1,3).north should block after 2026-06-16 chest-side probe from (1,2)->DOWN")
    assert_garins_grave_b3_dir(env, "1,3", "west", "B3 (1,3).west should block after return-route same-origin probe from (0,3)->RIGHT")
    assert_garins_grave_b3_dir(env, "2,3", "south", "B3 (2,3).south should block after post-reload Cursed Belt route probe from (2,4)->UP")
    assert_garins_grave_b3_dir(env, "3,3", "east", "B3 (3,3).east should block after post-reload Cursed Belt route probe from (4,3)->LEFT")
    assert_garins_grave_b3_dir(env, "1,4", "east", "B3 (1,4).east should block after post-reload Cursed Belt route probe from (2,4)->LEFT")
    assert_garins_grave_b3_dir(env, "1,4", "west", "B3 (1,4).west should block after return-route same-origin probe from (0,4)->RIGHT")
    assert_garins_grave_b3_dir(env, "1,5", "east", "B3 (1,5).east should block after post-reload Cursed Belt route probe from (2,5)->LEFT")
    assert_garins_grave_b3_dir(env, "1,5", "south", "B3 (1,5).south should block after post-reload Cursed Belt route probe from (1,6)->UP")
    assert_garins_grave_b3_dir(env, "1,5", "west", "B3 (1,5).west should block after return-route same-origin probe from (0,5)->RIGHT")
    assert_garins_grave_b3_dir(env, "1,7", "north", "B3 (1,7).north should block after same-origin object-pruning probe from (1,6)->DOWN")
    assert_garins_grave_b3_dir(env, "2,3", "north", "B3 (2,3).north should block after 2026-06-16 chest-side probe from (2,2)->DOWN")
    assert_garins_grave_b3_dir(env, "16,1", "east", "B3 (16,1).east should block after Northeast Stairs Up pocket probe from (17,1)->LEFT")
    assert_garins_grave_b3_dir(env, "16,1", "west", "B3 (16,1).west should block after Northwest Stairs Up pocket same-origin probe from (15,1)->RIGHT")
    assert_garins_grave_b3_dir(env, "16,2", "east", "B3 (16,2).east should block after Northeast Stairs Up pocket probe from (17,2)->LEFT")
    assert_garins_grave_b3_dir(env, "16,2", "west", "B3 (16,2).west should block after Northwest Stairs Up pocket same-origin probe from (15,2)->RIGHT")
    assert_garins_grave_b3_dir(env, "10,3", "north", "B3 (10,3).north should block after Northwest Stairs Up pocket same-origin probe from (10,2)->DOWN")
    assert_garins_grave_b3_dir(env, "11,3", "north", "B3 (11,3).north should block after Northwest Stairs Up pocket same-origin probe from (11,2)->DOWN")
    assert_garins_grave_b3_dir(env, "12,3", "north", "B3 (12,3).north should block after Northwest Stairs Up pocket same-origin probe from (12,2)->DOWN")
    assert_garins_grave_b3_dir(env, "13,3", "north", "B3 (13,3).north should block after Northwest Stairs Up pocket same-origin probe from (13,2)->DOWN")
    assert_garins_grave_b3_dir(env, "14,3", "north", "B3 (14,3).north should block after Northwest Stairs Up pocket same-origin probe from (14,2)->DOWN")
    assert_garins_grave_b3_dir(env, "15,3", "north", "B3 (15,3).north should block after Northwest Stairs Up pocket same-origin probe from (15,2)->DOWN")
    assert_garins_grave_b3_dir(env, "17,3", "north", "B3 (17,3).north should block after Northeast Stairs Up pocket probe from (17,2)->DOWN")
    assert_garins_grave_b3_dir(env, "18,3", "north", "B3 (18,3).north should block after Northeast Stairs Up pocket probe from (18,2)->DOWN")
    assert_garins_grave_b3_dir(env, "19,3", "north", "B3 (19,3).north should block after Northeast Stairs Up pocket probe from (19,2)->DOWN")
    assert_garins_grave_b3_dir(env, "10,4", "west", "B3 (10,4) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "11,4", "east", "B3 (11,4).east should block after lower-stair object-pruning probes from (12,4)->LEFT")
    assert_garins_grave_b3_dir(env, "11,4", "south", "B3 (11,4).south should block after lower-stair object-pruning probes from (11,5)->UP")
    assert_garins_grave_b3_dir(env, "15,4", "west", "B3 (15,4).west should block after lower-stair object-pruning probes from (14,4)->RIGHT")
    assert_garins_grave_b3_dir(env, "15,4", "south", "B3 (15,4).south should block after lower-stair object-pruning probes from (15,5)->UP")
    assert_garins_grave_b3_dir(env, "4,5", "south", "B3 (4,5) should block south approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "5,5", "south", "B3 (5,5) should block south approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "5,5", "east", "B3 (5,5) should block east approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "7,5", "north", "B3 (7,5) should block north approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "7,5", "east", "B3 (7,5) should block east approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "7,5", "west", "B3 (7,5) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "10,5", "west", "B3 (10,5) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "10,5", "east", "B3 (10,5).east should block after lower-stair object-pruning probes from (11,5)->LEFT")
    assert_garins_grave_b3_dir(env, "16,5", "west", "B3 (16,5).west should block after lower-stair object-pruning probes from (15,5)->RIGHT")
    assert_garins_grave_b3_dir(env, "16,6", "west", "B3 (16,6).west should block after lower-stair object-pruning probes from (15,6)->RIGHT")
    assert_garins_grave_b3_dir(env, "3,6", "east", "B3 (3,6) should block east approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "7,6", "west", "B3 (7,6) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "8,6", "north", "B3 (8,6) should block north approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "8,6", "south", "B3 (8,6) should block south approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "8,6", "east", "B3 (8,6) should block east approach after the 2026-06-05 direct 5/5 verifier from (9,6)")
    assert_garins_grave_b3_dir(env, "9,6", "north", "B3 (9,6) should block north approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "10,6", "west", "B3 (10,6) should block west approach after the 2026-06-05 direct 5/5 verifier from (9,6)")
    assert_garins_grave_b3_dir(env, "10,6", "east", "B3 (10,6) should block east approach after the 2026-06-05 direct 5/5 verifier from (11,6)")
    assert_garins_grave_b3_dir(env, "3,7", "east", "B3 (3,7) should block east approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "5,7", "north", "B3 (5,7) should block north approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "5,7", "west", "B3 (5,7) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "7,7", "east", "B3 (7,7) should block east approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "7,7", "west", "B3 (7,7) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "9,7", "north", "B3 (9,7) should block north approach after the 2026-06-05 direct 5/5 verifier from (9,6)")
    assert_garins_grave_b3_dir(env, "9,7", "west", "B3 (9,7) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "10,7", "east", "B3 (10,7).east should block after lower-stair object-pruning probes from (11,7)->LEFT")
    assert_garins_grave_b3_dir(env, "10,7", "south", "B3 (10,7).south should block after the lower-stair harp route twice blocked same-origin probe_edge:UP from (10,8)")
    assert_garins_grave_b3_dir(env, "16,7", "west", "B3 (16,7).west should block after lower-stair object-pruning probes from (15,7)->RIGHT")
    assert_garins_grave_b3_dir(env, "3,8", "east", "B3 (3,8) should block east approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "7,8", "east", "B3 (7,8) should block east approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "7,8", "west", "B3 (7,8) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "9,8", "east", "B3 (9,8).east should block after lower-stair object-pruning probes from (10,8)->LEFT")
    assert_garins_grave_b3_dir(env, "9,8", "west", "B3 (9,8) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "15,8", "north", "B3 (15,8).north should block after lower-stair object-pruning probes from (15,7)->DOWN")
    assert_garins_grave_b3_dir(env, "15,8", "west", "B3 (15,8).west should block after lower-stair object-pruning probes from (14,8)->RIGHT")
    assert_garins_grave_b3_dir(env, "3,9", "east", "B3 (3,9) should block east approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "7,9", "east", "B3 (7,9) should block east approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "7,9", "west", "B3 (7,9) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "9,9", "east", "B3 (9,9).east should block after lower-stair object-pruning probes from (10,9)->LEFT")
    assert_garins_grave_b3_dir(env, "9,9", "west", "B3 (9,9) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "12,9", "north", "B3 (12,9).north should block after lower-stair object-pruning probes from (12,8)->DOWN")
    assert_garins_grave_b3_dir(env, "12,9", "west", "B3 (12,9).west should block after lower-stair object-pruning probes from (11,9)->RIGHT")
    assert_garins_grave_b3_dir(env, "13,9", "north", "B3 (13,9).north should block after the harp-chest return route twice blocked same-origin probe_edge:DOWN from (13,8)")
    assert_garins_grave_b3_dir(env, "13,9", "south", "B3 (13,9) should block south approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "14,9", "north", "B3 (14,9).north should block after lower-stair object-pruning probes from (14,8)->DOWN")
    assert_garins_grave_b3_dir(env, "3,10", "east", "B3 (3,10) should block east approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "5,10", "north", "B3 (5,10) should block north approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "5,10", "west", "B3 (5,10) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "6,10", "north", "B3 (6,10) should block north approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "6,10", "south", "B3 (6,10) should block south approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "6,10", "west", "B3 (6,10) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "7,10", "south", "B3 (7,10) should block south approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "7,10", "east", "B3 (7,10) should block east approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "9,10", "south", "B3 (9,10) should block south approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "9,10", "west", "B3 (9,10) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "10,10", "north", "B3 (10,10).north should block after lower-stair object-pruning probes from (10,9)->DOWN")
    assert_garins_grave_b3_dir(env, "10,10", "south", "B3 (10,10) should block south approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "11,10", "north", "B3 (11,10).north should block after lower-stair object-pruning probes from (11,9)->DOWN")
    assert_garins_grave_b3_dir(env, "11,10", "south", "B3 (11,10) should block south approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "12,10", "south", "B3 (12,10) should block south approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "12,10", "east", "B3 (12,10) should block east approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "14,10", "west", "B3 (14,10) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "3,11", "east", "B3 (3,11) should block east approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "5,11", "east", "B3 (5,11) should block east approach after repeated live central-stair route retries and same-origin probes from (6,11)")
    assert_garins_grave_b3_dir(env, "5,11", "north", "B3 (5,11) should block north approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "5,11", "west", "B3 (5,11) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "14,11", "west", "B3 (14,11) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "3,12", "east", "B3 (3,12) should block east approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "5,12", "west", "B3 (5,12) should block west approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "6,12", "north", "B3 (6,12) should block north approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "7,12", "north", "B3 (7,12) should block north approach after repeated live central-stair route retries and same-origin probes from (7,11)")
    assert_garins_grave_b3_dir(env, "8,12", "north", "B3 (8,12) should block north approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "9,12", "north", "B3 (9,12) should block north approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "10,12", "north", "B3 (10,12) should block north approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "11,12", "north", "B3 (11,12) should block north approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "12,12", "north", "B3 (12,12) should block north approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "13,12", "north", "B3 (13,12) should block north approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "3,13", "east", "B3 (3,13) should block east approach after the stable 49-edge live reseed/model-consistency pass")
    assert_garins_grave_b3_dir(env, "3,1", "west", "B3 (3,1).west should block after same-origin Cursed Belt search probe from (2,1)->RIGHT")
    assert_garins_grave_b3_dir(env, "5,14", "west", "B3 (5,14).west should block after same-origin hidden-bridge probe from (4,14)->RIGHT")
    assert_garins_grave_b3_dir(env, "5,15", "east", "B3 (5,15).east should block after same-origin probe from (6,15)->LEFT")
    assert_garins_grave_b3_dir(env, "5,15", "west", "B3 (5,15).west should block after same-origin Cursed Belt search probe from (4,15)->RIGHT")
    assert_garins_grave_b3_dir(env, "8,14", "east", "B3 (8,14).east should block after same-origin probe from (9,14)->LEFT")
    assert_garins_grave_b3_dir(env, "8,14", "north", "B3 (8,14).north should block after same-origin probe from (8,13)->DOWN")
    assert_garins_grave_b3_dir(env, "8,14", "west", "B3 (8,14).west should block after same-origin probe from (7,14)->RIGHT")
    assert_garins_grave_b3_dir(env, "8,15", "west", "B3 (8,15).west should block after same-origin probe from (7,15)->RIGHT")
    assert_garins_grave_b3_dir(env, "4,16", "north", "B3 (4,16).north should block after same-origin probe from (4,15)->DOWN")
    assert_garins_grave_b3_dir(env, "4,16", "south", "B3 (4,16).south should block after same-origin probe from (4,17)->UP")
    assert_garins_grave_b3_dir(env, "5,16", "south", "B3 (5,16).south should block after same-origin probe from (5,17)->UP")
    assert_garins_grave_b3_dir(env, "6,16", "north", "B3 (6,16).north should block after same-origin probe from (6,15)->DOWN")
    assert_garins_grave_b3_dir(env, "6,16", "south", "B3 (6,16).south should block after same-origin probe from (6,17)->UP")
    assert_garins_grave_b3_dir(env, "7,16", "north", "B3 (7,16).north should block after same-origin probe from (7,15)->DOWN")
    assert_garins_grave_b3_dir(env, "7,16", "south", "B3 (7,16).south should block after same-origin probe from (7,17)->UP")
    assert_garins_grave_b3_dir(env, "8,16", "south", "B3 (8,16).south should block after same-origin probe from (8,17)->UP")
    assert_garins_grave_b3_dir(env, "6,18", "north", "B3 (6,18).north should block after same-origin probe from (6,17)->DOWN")
    assert_garins_grave_b3_dir(env, "8,18", "north", "B3 (8,18).north should block after same-origin probe from (8,17)->DOWN")

    env.restore()
end

function tests.garins_grave_b3_southeast_stair_pocket_seams_are_directional()
    local env = make_env()

    assert_garins_grave_b3_dir(env, "17,3", "south", "B3 (17,3).south should block after SE-stair probe from (17,4)->UP")
    assert_garins_grave_b3_dir(env, "18,3", "south", "B3 (18,3).south should block after SE-stair probe from (18,4)->UP")
    assert_garins_grave_b3_dir(env, "19,3", "south", "B3 (19,3).south should block after SE-stair probe from (19,4)->UP")
    assert_garins_grave_b3_dir(env, "16,4", "east", "B3 (16,4).east should block after SE-stair probe from (17,4)->LEFT")
    assert_garins_grave_b3_dir(env, "17,5", "north", "B3 (17,5).north should block after SE-stair probe from (17,4)->DOWN")
    assert_garins_grave_b3_dir(env, "17,5", "south", "B3 (17,5).south should block after SE-stair probe from (17,6)->UP")
    assert_garins_grave_b3_dir(env, "18,5", "east", "B3 (18,5).east should block after SE-stair probe from (19,5)->LEFT")
    assert_garins_grave_b3_dir(env, "18,5", "north", "B3 (18,5).north should block after SE-stair probe from (18,4)->DOWN")
    assert_garins_grave_b3_dir(env, "16,6", "east", "B3 (16,6).east should block after SE-stair probe from (17,6)->LEFT")
    assert_garins_grave_b3_dir(env, "18,6", "east", "B3 (18,6).east should block after SE-stair probe from (19,6)->LEFT")
    assert_garins_grave_b3_dir(env, "18,6", "west", "B3 (18,6).west should block after SE-stair probe from (17,6)->RIGHT")
    assert_garins_grave_b3_dir(env, "16,7", "east", "B3 (16,7).east should block after SE-stair probe from (17,7)->LEFT")
    assert_garins_grave_b3_dir(env, "18,7", "east", "B3 (18,7).east should block after SE-stair probe from (19,7)->LEFT")
    assert_garins_grave_b3_dir(env, "18,7", "south", "B3 (18,7).south should block after SE-stair probe from (18,8)->UP")
    assert_garins_grave_b3_dir(env, "18,7", "west", "B3 (18,7).west should block after SE-stair probe from (17,7)->RIGHT")
    assert_garins_grave_b3_dir(env, "16,8", "east", "B3 (16,8).east should block after SE-stair probe from (17,8)->LEFT")
    assert_garins_grave_b3_dir(env, "15,9", "south", "B3 (15,9).south should block after SE-stair probe from (15,10)->UP")
    assert_garins_grave_b3_dir(env, "16,9", "east", "B3 (16,9).east should block after SE-stair probe from (17,9)->LEFT")
    assert_garins_grave_b3_dir(env, "16,9", "south", "B3 (16,9).south should block after SE-stair probe from (16,10)->UP")
    assert_garins_grave_b3_dir(env, "14,10", "east", "B3 (14,10).east should block after SE-stair probe from (15,10)->LEFT")
    assert_garins_grave_b3_dir(env, "18,10", "west", "B3 (18,10).west should block after SE-stair probe from (17,10)->RIGHT")
    assert_garins_grave_b3_dir(env, "14,11", "east", "B3 (14,11).east should block after SE-stair probe from (15,11)->LEFT")
    assert_garins_grave_b3_dir(env, "11,12", "south", "B3 (11,12).south should block after SE-stair probe from (11,13)->UP")
    assert_garins_grave_b3_dir(env, "12,12", "south", "B3 (12,12).south should block after SE-stair probe from (12,13)->UP")
    assert_garins_grave_b3_dir(env, "13,12", "south", "B3 (13,12).south should block after SE-stair probe from (13,13)->UP")
    assert_garins_grave_b3_dir(env, "14,12", "south", "B3 (14,12).south should block after SE-stair probe from (14,13)->UP")
    assert_garins_grave_b3_dir(env, "15,12", "east", "B3 (15,12).east should block after SE-stair probe from (16,12)->LEFT")
    assert_garins_grave_b3_dir(env, "15,12", "north", "B3 (15,12).north should block after SE-stair probe from (15,11)->DOWN")
    assert_garins_grave_b3_dir(env, "15,12", "south", "B3 (15,12).south should block after SE-stair probe from (15,13)->UP")
    assert_garins_grave_b3_dir(env, "17,12", "east", "B3 (17,12).east should block after SE-stair probe from (18,12)->LEFT")
    assert_garins_grave_b3_dir(env, "10,13", "east", "B3 (10,13).east should block after SE-stair probe from (11,13)->LEFT")
    assert_garins_grave_b3_dir(env, "17,13", "east", "B3 (17,13).east should block after SE-stair probe from (18,13)->LEFT")
    assert_garins_grave_b3_dir(env, "10,14", "east", "B3 (10,14).east should block after SE-stair probe from (11,14)->LEFT")
    assert_garins_grave_b3_dir(env, "17,14", "south", "B3 (17,14).south should block after SE-stair probe from (17,15)->UP")
    assert_garins_grave_b3_dir(env, "18,14", "east", "B3 (18,14).east should block after SE-stair probe from (19,14)->LEFT")
    assert_garins_grave_b3_dir(env, "18,14", "south", "B3 (18,14).south should block after SE-stair probe from (18,15)->UP")
    assert_garins_grave_b3_dir(env, "10,15", "east", "B3 (10,15).east should block after SE-stair probe from (11,15)->LEFT")
    assert_garins_grave_b3_dir(env, "16,15", "east", "B3 (16,15).east should block after SE-stair probe from (17,15)->LEFT")
    assert_garins_grave_b3_dir(env, "11,16", "north", "B3 (11,16).north should block after SE-stair probe from (11,15)->DOWN")
    assert_garins_grave_b3_dir(env, "11,16", "south", "B3 (11,16).south should block after SE-stair probe from (11,17)->UP")
    assert_garins_grave_b3_dir(env, "12,16", "north", "B3 (12,16).north should block after SE-stair probe from (12,15)->DOWN")
    assert_garins_grave_b3_dir(env, "12,16", "south", "B3 (12,16).south should block after SE-stair probe from (12,17)->UP")
    assert_garins_grave_b3_dir(env, "13,16", "north", "B3 (13,16).north should block after SE-stair probe from (13,15)->DOWN")
    assert_garins_grave_b3_dir(env, "13,16", "south", "B3 (13,16).south should block after SE-stair probe from (13,17)->UP")
    assert_garins_grave_b3_dir(env, "14,16", "east", "B3 (14,16).east should block after SE-stair probe from (15,16)->LEFT")
    assert_garins_grave_b3_dir(env, "14,16", "north", "B3 (14,16).north should block after SE-stair probe from (14,15)->DOWN")
    assert_garins_grave_b3_dir(env, "14,16", "south", "B3 (14,16).south should block after SE-stair probe from (14,17)->UP")
    assert_garins_grave_b3_dir(env, "16,16", "east", "B3 (16,16).east should block after SE-stair probe from (17,16)->LEFT")
    assert_garins_grave_b3_dir(env, "18,16", "east", "B3 (18,16).east should block after SE-stair probe from (19,16)->LEFT")
    assert_garins_grave_b3_dir(env, "18,16", "west", "B3 (18,16).west should block after SE-stair probe from (17,16)->RIGHT")
    assert_garins_grave_b3_dir(env, "10,17", "east", "B3 (10,17).east should block after SE-stair probe from (11,17)->LEFT")
    assert_garins_grave_b3_dir(env, "16,17", "east", "B3 (16,17).east should block after SE-stair probe from (17,17)->LEFT")
    assert_garins_grave_b3_dir(env, "18,17", "west", "B3 (18,17).west should block after SE-stair probe from (17,17)->RIGHT")
    assert_garins_grave_b3_dir(env, "1,18", "south", "B3 (1,18).south should block after bottom-row direct probe from (1,19)->UP")
    assert_garins_grave_b3_dir(env, "2,18", "south", "B3 (2,18).south should block after bottom-row direct probe from (2,19)->UP")
    assert_garins_grave_b3_dir(env, "3,18", "south", "B3 (3,18).south should block after bottom-row direct probe from (3,19)->UP")
    assert_garins_grave_b3_dir(env, "4,18", "south", "B3 (4,18).south should block after bottom-row direct probe from (4,19)->UP")
    assert_garins_grave_b3_dir(env, "5,18", "south", "B3 (5,18).south should block after bottom-row direct probe from (5,19)->UP")
    assert_garins_grave_b3_dir(env, "6,18", "south", "B3 (6,18).south should block after bottom-row direct probe from (6,19)->UP")
    assert_garins_grave_b3_dir(env, "8,18", "south", "B3 (8,18).south should block after bottom-row direct probe from (8,19)->UP")
    assert_garins_grave_b3_dir(env, "9,18", "south", "B3 (9,18).south should block after bottom-row direct probe from (9,19)->UP")
    assert_garins_grave_b3_dir(env, "10,18", "south", "B3 (10,18).south should block after SE-stair probe from (10,19)->UP")
    assert_garins_grave_b3_dir(env, "11,18", "north", "B3 (11,18).north should block after SE-stair probe from (11,17)->DOWN")
    assert_garins_grave_b3_dir(env, "11,18", "south", "B3 (11,18).south should block after SE-stair probe from (11,19)->UP")
    assert_garins_grave_b3_dir(env, "12,18", "north", "B3 (12,18).north should block after SE-stair probe from (12,17)->DOWN")
    assert_garins_grave_b3_dir(env, "12,18", "south", "B3 (12,18).south should block after bottom-row direct probe from (12,19)->UP")
    assert_garins_grave_b3_dir(env, "13,18", "north", "B3 (13,18).north should block after SE-stair probe from (13,17)->DOWN")
    assert_garins_grave_b3_dir(env, "13,18", "south", "B3 (13,18).south should block after SE-stair probe from (13,19)->UP")
    assert_garins_grave_b3_dir(env, "14,18", "east", "B3 (14,18).east should block after SE-stair probe from (15,18)->LEFT")
    assert_garins_grave_b3_dir(env, "14,18", "north", "B3 (14,18).north should block after SE-stair probe from (14,17)->DOWN")
    assert_garins_grave_b3_dir(env, "14,18", "south", "B3 (14,18).south should block after SE-stair probe from (14,19)->UP")
    assert_garins_grave_b3_dir(env, "17,18", "north", "B3 (17,18).north should block after SE-stair probe from (17,17)->DOWN")
    assert_garins_grave_b3_dir(env, "18,18", "east", "B3 (18,18).east should block after SE-stair probe from (19,18)->LEFT")

    env.restore()
end

function tests.garins_grave_b1_chest_route_seams_are_directional()
    local env = make_env({
        memory_bytes = {
            [0] = 0x10,
        },
    })

    assert_garins_grave_b1_dir(env, "10,1", "east", "(10,1) should block east approach after chest-route seam retry")
    assert_garins_grave_b1_dir(env, "10,1", "west", "(10,1) should block west approach after fresh manual-route 8/8 verifier")
    assert_garins_grave_b1_dir(env, "10,2", "east", "(10,2) should block east approach after chest-route seam retry")
    assert_garins_grave_b1_dir(env, "10,2", "west", "(10,2) should block west approach after interrupted candidate recheck")
    assert_garins_grave_b1_dir(env, "10,3", "east", "(10,3) should block east approach after chest-route seam retry")
    assert_garins_grave_b1_dir(env, "10,3", "west", "(10,3) should block west approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "10,4", "west", "(10,4) should block west approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "10,4", "south", "(10,4) should block south approach after repeated mixed candidate recheck")
    assert_garins_grave_b1_dir(env, "10,6", "south", "(10,6) should block south approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "10,9", "east", "(10,9) should block east approach after the B2-stairs north-hook verifier from (11,9)")
    assert_garins_grave_b1_dir(env, "10,9", "west", "(10,9) should block west approach after route-polish 8/8 verifier")
    assert_garins_grave_b1_dir(env, "11,8", "south", "(11,8) should block south approach after the B2-stairs upper-hook verifier from (11,9)")
    assert_garins_grave_b1_dir(env, "11,4", "north", "(11,4) should block north approach after chest-route seam retry")
    assert_garins_grave_b1_dir(env, "11,4", "south", "(11,4) should block south approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "12,4", "east", "(12,4) should block east approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "12,5", "west", "(12,5) should block west approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "12,5", "east", "(12,5) should block east approach after repeat direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "12,6", "west", "(12,6) should block west approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "12,6", "east", "(12,6) should block east approach after repeat direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "12,6", "south", "(12,6) should block south approach after repeat direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "12,3", "north", "(12,3) should block north approach after chest-route seam retry")
    assert_garins_grave_b1_dir(env, "12,3", "west", "(12,3) should block west approach after chest-route seam retry")
    assert_garins_grave_b1_dir(env, "13,3", "north", "(13,3) should block north approach after chest-route seam retry")
    assert_garins_grave_b1_dir(env, "13,3", "south", "(13,3) should block south approach after interrupted candidate recheck")
    assert_garins_grave_b1_dir(env, "14,2", "west", "(14,2) should block west approach after chest-route seam retry")
    assert_garins_grave_b1_dir(env, "14,2", "north", "(14,2) should block north approach after return-route seam retry")
    assert_garins_grave_b1_dir(env, "14,2", "east", "(14,2) should block east approach after return-route seam retry")
    assert_garins_grave_b1_dir(env, "15,3", "north", "(15,3) should block north approach after return-route seam retry")
    assert_garins_grave_b1_dir(env, "16,1", "west", "(16,1) should block west approach after return-route 8/8 verifier")
    assert_garins_grave_b1_dir(env, "16,3", "north", "(16,3) should block north approach after return-route seam retry")
    assert_garins_grave_b1_dir(env, "16,3", "east", "(16,3) should block east approach after repeated clean direct probes")
    assert_garins_grave_b1_dir(env, "16,8", "north", "(16,8).north should block after route-local evidence plus two same-origin probes from (16,7)->DOWN")
    assert_garins_grave_b1_dir(env, "16,9", "east", "(16,9).east should block after two clean same-origin probes from (17,9)->LEFT")
    assert_garins_grave_b1_dir(env, "17,8", "north", "(17,8) should block north approach after return-route seam retry")
    assert_garins_grave_b1_dir(env, "17,8", "south", "(17,8).south should block after the 2026-06-16 route-polish runtime overlay from (17,9)->UP")
    assert_garins_grave_b1_dir(env, "18,8", "north", "(18,8).north should block after two same-origin probes from (18,7)->DOWN and the pulled runtime overlay")
    assert_garins_grave_b1_dir(env, "5,10", "north", "(5,10) should block north approach after return-route seam retry")
    assert_garins_grave_b1_dir(env, "5,10", "east", "(5,10) should block east approach after clean lower-west B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "5,10", "west", "(5,10) should block west approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "5,11", "east", "(5,11) should block east approach after B2-stairs route-validator abort and 8/8 verifier")
    assert_garins_grave_b1_dir(env, "5,11", "west", "(5,11) should block west approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "6,8", "north", "(6,8) should block north approach after return-route seam retry")
    assert_garins_grave_b1_dir(env, "6,8", "south", "(6,8) should block south approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "7,10", "north", "(7,10).north should block after the 2026-06-16 route-polish runtime overlay from (7,9)->DOWN")
    assert_garins_grave_b1_dir(env, "7,10", "south", "(7,10) should block south approach after direct 8/8 probe")
    assert_garins_grave_b1_dir(env, "7,8", "north", "(7,8) should block north approach after return-route seam retry")
    assert_garins_grave_b1_dir(env, "8,8", "north", "(8,8) should block north approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "8,10", "south", "(8,10) should block south approach after live manual/current-position 5/5 probe")
    assert_garins_grave_b1_dir(env, "8,10", "east", "(8,10) should block east approach after route-polish 8/8 verifier")
    assert_garins_grave_b1_dir(env, "8,18", "south", "(8,18) should block south approach after reverse-side contour 15/15 verifier from (8,19)")
    assert_garins_grave_b1_dir(env, "8,18", "west", "(8,18) should block west approach after reverse-lane 15/15 verifier from (7,18)")
    assert_garins_grave_b1_dir(env, "9,18", "east", "(9,18) should block east approach after reverse-side contour 15/15 verifier from (10,18)")
    assert_garins_grave_b1_dir(env, "9,18", "south", "(9,18) should block south approach after reverse-side contour 15/15 verifier from (9,19)")
    assert_garins_grave_b1_dir(env, "15,3", "south", "(15,3) should block south approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "16,4", "west", "(16,4) should block west approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "14,4", "east", "(14,4) should block east approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "16,5", "west", "(16,5) should block west approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "16,5", "east", "(16,5) should block east approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "14,5", "east", "(14,5) should block east approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "16,6", "west", "(16,6) should block west approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "16,6", "south", "(16,6) should block south approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "16,6", "east", "(16,6) should block east approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "17,1", "south", "(17,1) should block south approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "3,5", "south", "(3,5) should block south approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "3,8", "north", "(3,8) should block north approach after validator abort and clean 15/15 verifier")
    assert_garins_grave_b1_dir(env, "3,9", "east", "(3,9) should block east approach after clean lower-west B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "3,10", "south", "(3,10) should block south approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "4,7", "west", "(4,7) should block west approach after B2-stairs route-temp evidence and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "4,6", "west", "(4,6) should block west approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "1,7", "east", "(1,7) should block east approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "1,7", "north", "(1,7) should block north approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "1,8", "east", "(1,8) should block east approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "1,9", "east", "(1,9) should block east approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "1,10", "east", "(1,10) should block east approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "1,11", "east", "(1,11) should block east approach after clean lower-west B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "1,12", "east", "(1,12) should block east approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "1,13", "east", "(1,13) should block east approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "1,14", "east", "(1,14) should block east approach after clean lower-west B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "1,15", "south", "(1,15) should block south approach after restarted west-pocket 15/15 verifier from (1,16)")
    assert_garins_grave_b1_dir(env, "2,15", "north", "(2,15) should block north approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "2,15", "south", "(2,15) should block south approach after restarted west-pocket 15/15 verifier from (2,16)")
    assert_garins_grave_b1_dir(env, "2,17", "east", "(2,17) should block east approach after entrance-side west-pocket 15/15 verifier from (3,17)")
    assert_garins_grave_b1_dir(env, "2,17", "south", "(2,17) should block south approach after restarted west-pocket 15/15 verifier from (2,18)")
    assert_garins_grave_b1_dir(env, "3,12", "north", "(3,12) should block north approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "3,12", "east", "(3,12) should block east approach after clean lower-west B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "3,12", "west", "(3,12) should block west approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "3,13", "south", "(3,13) should block south approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "3,13", "west", "(3,13) should block west approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "3,15", "north", "(3,15) should block north approach after clean lower-west B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "3,15", "east", "(3,15) should block east approach after clean lower-west B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "3,16", "south", "(3,16) should block south approach after entrance-side west-pocket 15/15 verifier from (3,17)")
    assert_garins_grave_b1_dir(env, "3,16", "west", "(3,16) should block west approach after restarted west-pocket 15/15 verifier from (2,16)")
    assert_garins_grave_b1_dir(env, "4,13", "north", "(4,13) should block north approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "4,13", "south", "(4,13) should block south approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "4,13", "west", "(4,13) should block west approach after the natural `(3,14)->UP` bridge dead-ended on a clean 5/5 `(3,13)->RIGHT` verifier")
    assert_garins_grave_b1_dir(env, "4,16", "north", "(4,16) should block north approach after clean lower-west B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "5,15", "west",
        "(5,15) should block west approach after the clean-state 2026-05-29 verifier from (4,15)")
    assert_garins_grave_b1_dir(env, "14,6", "east", "(14,6) should block east approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "14,4", "west", "(14,4) should block west approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "14,5", "west", "(14,5) should block west approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "14,6", "west", "(14,6) should block west approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "14,6", "south", "(14,6) should block south approach after direct 5/5 probe")
    assert_garins_grave_b1_dir(env, "4,17", "east", "(4,17) should block east approach after follow-up route-validator abort and 8/8 verifier")
    assert_garins_grave_b1_dir(env, "4,17", "west", "(4,17) should block west approach after 2026-06-16 entrance/stair route cleanup from (3,17)->RIGHT")
    local b1_dirs = env.map_reader.get_directional_blocks(0x18)
    assert_garins_grave_b1_dir(env, "4,18", "south", "(4,18) should block south approach after entrance-side west-pocket 15/15 verifier from (4,19)")
    assert_garins_grave_b1_dir(env, "4,18", "west", "(4,18) should block west approach after restarted west-pocket 15/15 verifier from (3,18)")
    assert_garins_grave_b1_dir(env, "5,11", "north", "(5,11) should block north approach after the `5,10` pocket repeat dead-ended on a clean 10/10 `(5,10)->DOWN` verifier")
    assert_garins_grave_b1_dir(env, "5,12", "east", "(5,12) should block east approach after first B2-stairs route probe")
    assert_garins_grave_b1_dir(env, "5,12", "west", "(5,12) should block west approach after clean lower-west B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "5,14", "east", "(5,14) should block east approach after follow-up B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "5,14", "west",
        "(5,14) should block west approach after the clean-state 2026-05-29 validator abort and direct verifier from (4,14)")
    assert_garins_grave_b1_dir(env, "5,16", "south", "(5,16) should block south approach after follow-up B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "5,16", "east", "(5,16) should block east approach after follow-up route-validator abort and 8/8 verifier")
    assert_garins_grave_b1_dir(env, "5,18", "north", "(5,18) should block north approach after follow-up B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "5,18", "south", "(5,18) should block south approach after 2026-06-05 Silver Harp escape verifier from (5,19) blocked 5/5")
    assert_garins_grave_b1_dir(env, "6,13", "north", "(6,13) should block north approach after first B2-stairs route probe")
    assert_garins_grave_b1_dir(env, "6,13", "south", "(6,13) should block south approach after first B2-stairs route probe")
    assert_garins_grave_b1_dir(env, "6,15", "north", "(6,15) should block north approach after first B2-stairs route probe")
    assert_garins_grave_b1_dir(env, "6,15", "south", "(6,15) should block south approach after follow-up route-validator abort and 8/8 verifier")
    assert_garins_grave_b1_dir(env, "6,18", "north", "(6,18) should block north approach after follow-up route-validator abort and 8/8 verifier")
    assert_garins_grave_b1_dir(env, "6,18", "south", "(6,18) should block south approach after 2026-06-05 Silver Harp escape verifier from (6,19) blocked 5/5")
    assert_garins_grave_b1_dir(env, "7,13", "east", "(7,13) should block east approach after the `8,14` forward lip dead-ended on a clean 5/5 `(8,13)->LEFT` verifier")
    assert_garins_grave_b1_dir(env, "7,13", "north", "(7,13) should block north approach after first B2-stairs route probe")
    assert_garins_grave_b1_dir(env, "7,13", "south", "(7,13) should block south approach after first B2-stairs route probe")
    assert_garins_grave_b1_dir(env, "7,15", "north", "(7,15) should block north approach after first B2-stairs route probe")
    assert_garins_grave_b1_dir(env, "7,15", "south", "(7,15) should block south approach after follow-up B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "7,17", "north", "(7,17) should block north approach after follow-up B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "7,17", "east", "(7,17) should block east approach after follow-up B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "7,17", "west", "(7,17) should block west approach after follow-up route-validator abort and 8/8 verifier")
    assert_garins_grave_b1_dir(env, "7,18", "south", "(7,18) should block south approach after entrance-side west-pocket 15/15 verifier from (7,19)")
    assert_garins_grave_b1_dir(env, "8,13", "north", "(8,13) should block north approach after first B2-stairs route probe")
    assert_garins_grave_b1_dir(env, "8,13", "south", "(8,13) should block south approach after first B2-stairs route probe")
    assert_garins_grave_b1_dir(env, "8,13", "east", "(8,13) should block east approach after follow-up route-validator abort and 8/8 verifier")
    assert_garins_grave_b1_dir(env, "8,15", "north", "(8,15) should block north approach after first B2-stairs route probe")
    assert_garins_grave_b1_dir(env, "8,15", "south", "(8,15) should block south approach after follow-up B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "8,18", "north", "(8,18) should block north approach after follow-up route-validator abort and 8/8 verifier")
    assert_garins_grave_b1_dir(env, "9,15", "north", "(9,15) should block north approach after first B2-stairs route probe")
    assert_garins_grave_b1_dir(env, "9,15", "south", "(9,15) should block south approach after follow-up B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "9,17", "north", "(9,17) should block north approach after follow-up B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "9,17", "west", "(9,17) should block west approach after follow-up B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "10,15", "north", "(10,15) should block north approach after follow-up B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "10,15", "south", "(10,15) should block south approach after follow-up B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "10,15", "east", "(10,15) should block east approach after follow-up route-validator abort and 8/8 verifier")
    assert_garins_grave_b1_dir(env, "10,17", "north", "(10,17) should block north approach after follow-up B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "10,17", "south", "(10,17) should block south approach after reverse-side contour 15/15 verifier from (10,18)")
    assert_garins_grave_b1_dir(env, "10,8", "north", "(10,8) should block north approach after the B2-stairs entrance-side 8/8 verifier from (10,7)")
    assert_garins_grave_b1_dir(env, "10,8", "west", "(10,8) should block west approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "10,10", "west", "(10,10) should block west approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "10,11", "east", "(10,11) should block east approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "10,11", "west", "(10,11) should block west approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "10,12", "east", "(10,12) should block east approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "10,12", "west", "(10,12) should block west approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "10,13", "south", "(10,13) should block south approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "10,13", "west", "(10,13) should block west approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "11,10", "north", "(11,10) should block north approach after the B2-stairs north-hook verifier from (11,9)")
    assert_garins_grave_b1_dir(env, "11,10", "south", "(11,10) should block south approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "11,13", "north", "(11,13) should block north approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "11,13", "south", "(11,13) should block south approach after follow-up route-validator abort and 8/8 verifier")
    assert_garins_grave_b1_dir(env, "11,8", "north", "(11,8) should block north approach after the B2-stairs entrance-side 15/15 verifier from (11,7)")
    assert_garins_grave_b1_dir(env, "11,17", "north", "(11,17) should block north approach after follow-up B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "11,18", "east", "(11,18) should block east approach after reverse-side contour 15/15 verifier from (12,18)")
    assert_garins_grave_b1_dir(env, "11,18", "south", "(11,18) should block south approach after reverse-side contour 15/15 verifier from (11,19)")
    assert_garins_grave_b1_dir(env, "11,18", "west", "(11,18) should block west approach after reverse-side contour 15/15 verifier from (10,18)")
    assert_garins_grave_b1_dir(env, "12,8", "north", "(12,8) should block north approach after the B2-stairs entrance-side 15/15 verifier from (12,7)")
    assert_garins_grave_b1_dir(env, "12,8", "south", "(12,8) should block south approach after the B2-stairs upper-hook verifier from (12,9)")
    assert_garins_grave_b1_dir(env, "12,10", "north", "(12,10) should block north approach after the B2-stairs upper-hook verifier from (12,9)")
    assert_garins_grave_b1_dir(env, "12,10", "south", "(12,10) should block south approach after the mirrored upper-hook 15/15 verifier from (12,11)")
    assert_garins_grave_b1_dir(env, "12,12", "east", "(12,12) should block east approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "12,12", "north", "(12,12) should block north approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "12,12", "west", "(12,12) should block west approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "12,13", "south", "(12,13) should block south approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "12,17", "north", "(12,17) should block north approach after follow-up B2-stairs verifier")
    assert_garins_grave_b1_dir(env, "12,17", "south", "(12,17) should block south approach after reverse-lane 15/15 verifier from (12,18)")
    assert_garins_grave_b1_dir(env, "13,8", "north", "(13,8) should block north approach after the B2-stairs entrance-side 15/15 verifier from (13,7)")
    assert_garins_grave_b1_dir(env, "13,8", "south", "(13,8) should block south approach after the stronger mirrored 15/15 verifier from (13,9)")
    assert_garins_grave_b1_dir(env, "13,10", "north", "(13,10) should block north approach after the B2-stairs upper-hook verifier from (13,9)")
    assert_garins_grave_b1_dir(env, "13,10", "south", "(13,10) should block south approach after the mirrored upper-hook 15/15 verifier from (13,11)")
    assert_garins_grave_b1_dir(env, "13,13", "north", "(13,13) should block north approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "13,13", "south", "(13,13) should block south approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "13,17", "north", "(13,17) should block north approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "13,17", "south", "(13,17) should block south approach after reverse-lane 15/15 verifier from (13,18)")
    assert_garins_grave_b1_dir(env, "13,19", "east", "(13,19) should block east approach after reverse-side contour 15/15 verifier from (14,19)")
    assert_garins_grave_b1_dir(env, "13,19", "west", "(13,19) should block west approach after reverse-lane 15/15 verifier from (12,19)")
    assert_garins_grave_b1_dir(env, "14,10", "east", "(14,10) should block east approach after the B2-stairs north-hook verifier from (15,10)")
    assert_garins_grave_b1_dir(env, "14,10", "north", "(14,10) should block north approach after the B2-stairs upper-hook verifier from (14,9)")
    assert_garins_grave_b1_dir(env, "14,11", "east", "(14,11) should block east approach after reverse recheck 15/15 verifier from (15,11)")
    assert_garins_grave_b1_dir(env, "14,11", "west", "(14,11) should block west approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "14,11", "south", "(14,11) should block south approach after the mirrored upper-hook 15/15 verifier from (14,12)")
    assert_garins_grave_b1_dir(env, "14,13", "east", "(14,13) should block east approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "14,13", "north", "(14,13) should block north approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "14,14", "west", "(14,14) should block west approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "14,15", "east", "(14,15) should block east approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "14,15", "west", "(14,15) should block west approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "14,16", "east", "(14,16) should block east approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "14,16", "west", "(14,16) should block west approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "14,17", "north", "(14,17) should block north approach after reverse-side contour continuation cleanly confirmed the `14,16->DOWN` false entry")
    assert_garins_grave_b1_dir(env, "14,17", "south", "(14,17) should block south approach after reverse-lane 15/15 verifier from (14,18)")
    assert_garins_grave_b1_dir(env, "14,8", "east", "(14,8) should block east approach after the B2-stairs entrance-side 15/15 verifier from (15,8)")
    assert_garins_grave_b1_dir(env, "14,8", "north", "(14,8) should block north approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "14,8", "south", "(14,8) should block south approach after the mirrored upper-hook 15/15 verifier from (14,9)")
    assert_garins_grave_b1_dir(env, "15,14", "north", "(15,14) should block north approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "15,14", "south", "(15,14) should block south approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "15,17", "north", "(15,17) should block north approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "15,18", "east", "(15,18) should block east approach after reverse-lane 15/15 verifier from (16,18)")
    assert_garins_grave_b1_dir(env, "15,18", "south", "(15,18) should block south approach after reverse-lane 15/15 verifier from (15,19)")
    assert_garins_grave_b1_dir(env, "15,18", "west", "(15,18) should block west approach after reverse-lane 15/15 verifier from (14,18)")
    assert_garins_grave_b1_dir(env, "16,11", "north", "(16,11) should block north approach after the B2-stairs north-hook verifier from (16,10)")
    assert_garins_grave_b1_dir(env, "16,11", "west", "(16,11) should block west approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "16,12", "south", "(16,12) should block south approach after the B2-stairs north-hook verifier from (16,13)")
    assert_garins_grave_b1_dir(env, "16,12", "west", "(16,12) should block west approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "16,14", "north", "(16,14) should block north approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "16,15", "east", "(16,15) should block east approach after the B2-stairs batch pocket verifier from (17,15)")
    assert_garins_grave_b1_dir(env, "16,15", "south", "(16,15) should block south approach after the B2-stairs batch pocket verifier from (16,16)")
    assert_garins_grave_b1_dir(env, "16,15", "west", "(16,15) should block west approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "16,17", "east", "(16,17) should block east approach after the door-open return-route verifier from (17,17)")
    assert_garins_grave_b1_dir(env, "16,17", "north", "(16,17) should block north approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "16,17", "south", "(16,17) should block south approach after reverse-lane 15/15 verifier from (16,18)")
    assert_garins_grave_b1_dir(env, "17,11", "east", "(17,11) should block east approach after the north-hook batch verifier from (18,11)")
    assert_garins_grave_b1_dir(env, "17,11", "north", "(17,11) should block north approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "17,12", "east", "(17,12) should block east approach after the north-hook batch verifier from (18,12)")
    assert_garins_grave_b1_dir(env, "17,13", "east", "(17,13) should block east approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "17,13", "west", "(17,13) should block west approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "17,14", "south", "(17,14) should block south approach after the B2-stairs batch pocket verifier from (17,15)")
    assert_garins_grave_b1_dir(env, "17,19", "east", "(17,19).east should block after auto_walk_blocker found (18,19)->LEFT and same-origin probes confirmed it")
    assert_garins_grave_b1_dir(env, "17,19", "north", "(17,19).north should block after fresh same-origin probes from normally reached (17,18)->DOWN")
    assert_garins_grave_b1_dir(env, "17,19", "west", "(17,19).west should block after auto_walk_blocker found (16,19)->RIGHT and same-origin probes confirmed it")
    assert_no_directional_entry(env, 0x18, "17,17", "(17,17) should be handled by the confirmed B1 door override, not a permanent directional seam")
    assert_garins_grave_b1_dir(env, "18,14", "east", "(18,14) should block east approach after the north-pocket batch verifier from (19,14)")
    assert_garins_grave_b1_dir(env, "18,14", "north", "(18,14) should block north approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "18,15", "east", "(18,15) should block east approach after the north-pocket batch verifier from (19,15)")
    assert_garins_grave_b1_dir(env, "18,15", "south", "(18,15) should block south approach after the B2-stairs batch pocket verifier from (18,16)")
    assert_garins_grave_b1_dir(env, "18,15", "west", "(18,15) should block west approach after the B2-stairs batch pocket verifier from (17,15)")
    assert_garins_grave_b1_dir(env, "18,17", "north", "(18,17) should block north approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "18,17", "south", "(18,17) should block south approach after reverse-side contour 15/15 verifier from (18,18)")
    assert_garins_grave_b1_dir(env, "19,12", "north", "(19,12).north should block after the 2026-06-16 route-polish runtime overlay from (19,11)->DOWN")
    assert_garins_grave_b1_dir(env, "19,12", "south", "(19,12) should block south approach after the north-pocket batch verifier from (19,13)")
    assert_garins_grave_b1_dir(env, "19,17", "north", "(19,17) should block north approach after validator abort and clean 8/8 verifier")
    assert_garins_grave_b1_dir(env, "19,17", "south", "(19,17) should block south approach after reverse-side contour 15/15 verifier from (19,18)")

    local dirs = env.map_reader.get_directional_blocks(0x18)
    assert_equal(dirs["11,1"], nil, "(11,1) should not become directional after the noisy south-approach seam moved")
    assert_equal((dirs["2,10"] or {}).north, nil, "(2,10).north should stay unmodeled after battle-interrupted verifier")
    assert_equal((dirs["10,7"] or {}).south, nil, "(10,7).south should stay runtime-only until a direct verifier from below confirms it")
    assert_equal((dirs["11,7"] or {}).south, nil, "(11,7).south should stay runtime-only until a direct verifier from below confirms it")
    assert_equal((dirs["12,7"] or {}).south, nil, "(12,7).south should stay runtime-only until a direct verifier from below confirms it")
    assert_equal((dirs["13,7"] or {}).south, nil, "(13,7).south should stay runtime-only until a direct verifier from below confirms it")
    assert_equal(dirs["14,1"], nil, "(14,1) should stay unpromoted after direct confirmed-passable west-approach probe")
    assert_equal(dirs["15,1"], nil, "(15,1) should not become directional after the noisy west-approach seam moved")
    assert_equal(dirs["17,2"], nil, "(17,2) should not become directional after the noisy west-approach seam moved")
    assert_equal((dirs["17,3"] or {}).south, nil, "(17,3).south should stay unmodeled after direct confirmed-passable probe")
    assert_equal((dirs["3,19"] or {}).east, nil, "(3,19).east should stay unmodeled after blocked-then-moved entrance-side retry")
    assert_equal((dirs["7,19"] or {}).east, nil, "(7,19).east should stay unmodeled after blocked-then-moved entrance-side retry")
    assert_equal(dirs["14,7"], nil, "(14,7) should not become directional after the noisy east-approach seam moved")
    assert_equal((dirs["14,18"] or {}).west, nil, "(14,18).west moved 6/6 on direct return-route recheck and should stay open")
    assert_equal(dirs["6,7"], nil, "(6,7) should not become directional after the noisy east-approach seam moved")
    assert_equal(dirs["5,7"], nil, "(5,7) should not become directional after the noisy east-approach seam moved")
    assert_equal((dirs["18,8"] or {}).south, nil, "(18,8).south stayed mixed on direct return-route recheck and should stay unmodeled")
    assert_equal((dirs["19,13"] or {}).south, nil, "(19,13).south moved 6/6 on direct return-route recheck and should stay open")
    assert_equal((dirs["19,16"] or {}).west, nil, "(19,16).west moved 6/6 on direct return-route recheck and should stay open")

    env.restore()
end

function tests.sun_shrine_west_edge_entry_and_return_stairs_override_boundary()
    local base = 0x0C * 5
    local data_offset = 0x1010
    local rom_bytes = {
        [base] = 0x00,      -- CPU $9000 -> file offset $1010
        [base + 1] = 0x90,
        [base + 2] = 9,     -- width 10
        [base + 3] = 9,     -- height 10
        [base + 4] = 0,
    }
    fill_packed_map(rom_bytes, data_offset, 10, 10, 0x6)
    local env = make_env({
        rom_bytes = rom_bytes,
        memory_bytes = {
            [0] = 0x10,
        },
    })

    local entry = env.map_reader.get_walkability_details(0x0C, 0, 2)
    assert_equal(entry.base_walkable, true, "Sun Shrine entry tile should be passable")
    assert_equal(entry.reason, "passthrough", "Sun Shrine entry tile should override west-edge boundary")

    local return_stairs = env.map_reader.get_walkability_details(0x0C, 0, 4)
    assert_equal(return_stairs.base_walkable, true, "Sun Shrine return stairs should be passable")
    assert_equal(return_stairs.reason, "passthrough", "Sun Shrine return stairs should override west-edge boundary")

    local west_edge_corridor = env.map_reader.get_walkability_details(0x0C, 0, 7)
    assert_equal(west_edge_corridor.base_walkable, true, "Sun Shrine west-edge corridor should be passable")
    assert_equal(west_edge_corridor.reason, "passthrough", "Sun Shrine west-edge corridor should override west-edge boundary")

    local unconfirmed_edge = env.map_reader.get_walkability_details(0x0C, 0, 3)
    assert_equal(unconfirmed_edge.base_walkable, false, "unconfirmed Sun Shrine west edge should stay blocked")
    assert_equal(unconfirmed_edge.reason, "engine_boundary", "unconfirmed Sun Shrine west edge should keep boundary reason")

    local floor = env.map_reader.get_walkability_details(0x0C, 1, 2)
    assert_equal(floor.base_walkable, true, "Sun Shrine interior floor should stay tile-walkable")
    assert_equal(floor.reason, "tile_type", "Sun Shrine interior floor should not need passthrough")

    local dirs = env.map_reader.get_directional_blocks(0x0C)
    assert_sun_shrine_dir(env, "3,3", "west", "(3,3).west should block after top shortcut probe from (2,3)->RIGHT")
    assert_sun_shrine_dir(env, "3,3", "north", "(3,3).north should block after top shortcut probe from (3,2)->DOWN")
    assert_sun_shrine_dir(env, "3,4", "west", "(3,4).west should block after entrance-to-chest route probe from (2,4)->RIGHT")
    assert_sun_shrine_dir(env, "3,4", "east", "(3,4).east should block after chest-return route probe from (4,4)->LEFT")
    assert_sun_shrine_dir(env, "3,5", "west", "(3,5).west should block after entrance-to-chest route probe from (2,5)->RIGHT")
    assert_sun_shrine_dir(env, "3,5", "east", "(3,5).east should block after chest-return route probe from (4,5)->LEFT")
    assert_sun_shrine_dir(env, "3,6", "west", "(3,6).west should block after entrance-to-chest route probe from (2,6)->RIGHT")
    assert_sun_shrine_dir(env, "3,6", "south", "(3,6).south should block after chest route probe from (3,7)->UP")
    assert_sun_shrine_dir(env, "4,3", "north", "(4,3).north should block after top shortcut probe from (4,2)->DOWN")
    assert_sun_shrine_dir(env, "4,3", "south", "(4,3).south should block after chest-return route probe from (4,4)->UP")
    assert_sun_shrine_dir(env, "5,3", "north", "(5,3).north should block after top shortcut probe from (5,2)->DOWN")
    assert_sun_shrine_dir(env, "5,3", "south", "(5,3).south should block after chest-return route probe from (5,4)->UP")
    assert_sun_shrine_dir(env, "6,3", "north", "(6,3).north should block after top shortcut probe from (6,2)->DOWN")
    assert_sun_shrine_dir(env, "6,3", "east", "(6,3).east should block after right-wall probe from (7,3)->LEFT")
    assert_sun_shrine_dir(env, "6,4", "east", "(6,4).east should block after right-wall probe from (7,4)->LEFT")
    assert_sun_shrine_dir(env, "6,4", "west", "(6,4).west should block after chest-return route probe from (5,4)->RIGHT")
    assert_sun_shrine_dir(env, "6,5", "east", "(6,5).east should block after right-wall probe from (7,5)->LEFT")
    assert_sun_shrine_dir(env, "6,5", "west", "(6,5).west should block after chest-return route probe from (5,5)->RIGHT")
    assert_sun_shrine_dir(env, "6,6", "east", "(6,6).east should block after right-wall probe from (7,6)->LEFT")

    assert_equal(dirs["2,3"], nil, "(2,3) should stay open after same-origin probe from (2,2)->DOWN moved")
    assert_equal(dirs["3,7"], nil, "(3,7) should stay open for the live row-7 old-man/chest bypass")
    assert_equal(dirs["6,7"], nil, "(6,7) should stay open for the live row-7 old-man/chest bypass")

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

    for _, y in ipairs({16, 17, 18}) do
        local middle_strip = env.map_reader.get_walkability_details(0x15, 2, y)
        assert_equal(middle_strip.base_walkable, true, "Swamp Cave route-cleanup middle strip should be passable")
        assert_equal(middle_strip.reason, "passthrough", "Swamp Cave route-cleanup middle strip should override blocked decode")
    end

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
    assert_equal(dirs["2,14"].north, true, "Swamp Cave should block southward entry from (2,13) into (2,14)")
    assert_equal(dirs["3,9"].north, true, "Swamp Cave should block southward entry from (3,8) into (3,9)")
    assert_equal(dirs["4,8"].west, true, "Swamp Cave should block eastward entry from (3,8) into (4,8)")
    assert_equal(dirs["1,24"].north, true, "Swamp Cave should block southward entry from (1,23) into (1,24)")
    assert_equal(dirs["1,24"].south, true, "Swamp Cave should block northward entry from (1,25) into (1,24)")
    assert_equal(dirs["1,24"].west, true, "Swamp Cave should block eastward entry from (0,24) into (1,24)")
    assert_equal(dirs["1,27"].north, true, "Swamp Cave should block southward entry from (1,26) into (1,27)")
    assert_equal(dirs["1,27"].south, true, "Swamp Cave should block northward entry from (1,28) into (1,27)")
    assert_equal(dirs["2,27"].north, true, "Swamp Cave should block southward entry from (2,26) into (2,27)")
    assert_equal(dirs["2,28"].south, true, "Swamp Cave should block northward entry from (2,29) into (2,28)")
    assert_equal(dirs["2,28"].east, true, "Swamp Cave should block westward entry from (3,28) into (2,28)")
    assert_equal(dirs["2,28"].west, true, "Swamp Cave should block eastward entry from (1,28) into (2,28)")
    assert_equal(dirs["2,27"].east, true, "Swamp Cave should block westward entry from (3,27) into (2,27)")
    assert_equal(dirs["1,2"].west, true, "Swamp Cave should block eastward entry from (0,2) into (1,2)")
    assert_equal(dirs["1,5"].west, true, "Swamp Cave should block eastward entry from (0,5) into (1,5)")
    assert_equal(dirs["1,5"].south, true, "Swamp Cave should block northward entry from (1,6) into (1,5)")
    assert_equal(dirs["2,6"].west, true, "Swamp Cave should block eastward entry from (1,6) into (2,6)")
    assert_equal(dirs["1,7"].north, true, "Swamp Cave should block southward entry from (1,6) into (1,7)")
    assert_equal(dirs["1,7"].west, true, "Swamp Cave should block eastward entry from (0,7) into (1,7)")
    assert_equal(dirs["2,3"].south, true, "Swamp Cave should block northward entry from (2,4) into (2,3)")
    assert_equal(dirs["3,5"].north, true, "Swamp Cave should block southward entry from (3,4) into (3,5)")
    assert_equal(dirs["4,4"].west, true, "Swamp Cave should block eastward entry from (3,4) into (4,4)")
    assert_equal(dirs["2,6"].north, true, "Swamp Cave should block southward entry from (2,5) into (2,6)")
    assert_equal(dirs["3,5"].west, true, "Swamp Cave should block eastward entry from (2,5) into (3,5)")
    assert_equal(dirs["4,4"].north, true, "Swamp Cave should block southward entry from (4,3) into (4,4)")
    assert_equal(dirs["5,14"].north, true, "Swamp Cave should block southward entry from (5,13) into (5,14)")
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
    assert_equal(dirs["4,24"].east, true, "Swamp Cave should block westward entry from (5,24) into (4,24) after reverse-route polish")
    assert_equal(dirs["5,22"].south, true, "Swamp Cave should block northward entry from (5,23) into (5,22)")
    for _, y in ipairs({9, 10, 11, 12, 13, 15, 16, 17, 18, 19, 20, 21}) do
        assert_equal(dirs["1," .. y].east, true, "Swamp Cave south-stairs polish should block westward entry from x=2 into row " .. y)
    end
    assert_equal(dirs["1,9"].north, true, "Swamp Cave should block southward entry from (1,8) into (1,9)")
    assert_equal(dirs["2,14"].south, true, "Swamp Cave should block northward entry from (2,15) into (2,14)")
    assert_equal(dirs["3,14"].north, true, "Swamp Cave should block southward entry from (3,13) into (3,14)")
    assert_equal(dirs["3,14"].east, true, "Swamp Cave should block westward entry from (4,14) into (3,14)")
    assert_equal(dirs["3,14"].south, true, "Swamp Cave should block northward entry from (3,15) into (3,14)")
    assert_equal(dirs["3,16"].north, true, "Swamp Cave should block southward entry from (3,15) into (3,16)")
    assert_equal(dirs["3,16"].west, true, "Swamp Cave should block eastward entry from (2,16) into (3,16)")
    assert_equal(dirs["4,16"].north, true, "Swamp Cave should block southward entry from (4,15) into (4,16)")
    assert_equal(dirs["4,16"].south, true, "Swamp Cave should block northward entry from (4,17) into (4,16)")
    assert_equal(dirs["5,16"].north, true, "Swamp Cave should block southward entry from (5,15) into (5,16)")
    assert_equal(dirs["5,16"].south, true, "Swamp Cave should block northward entry from (5,17) into (5,16)")
    assert_equal(dirs["3,17"].west, true, "Swamp Cave should block eastward entry from (2,17) into (3,17)")
    assert_equal(dirs["3,17"].east, true, "Swamp Cave should block westward entry from (4,17) into (3,17)")
    assert_equal(dirs["3,18"].west, true, "Swamp Cave should block eastward entry from (2,18) into (3,18)")
    assert_equal(dirs["3,18"].east, true, "Swamp Cave should block westward entry from (4,18) into (3,18)")
    assert_equal(dirs["3,19"].west, true, "Swamp Cave should block eastward entry from (2,19) into (3,19)")
    assert_equal(dirs["3,19"].east, true, "Swamp Cave should block westward entry from (4,19) into (3,19)")
    assert_equal(dirs["3,20"].south, true, "Swamp Cave should block northward entry from (3,21) into (3,20)")
    assert_equal(dirs["3,20"].west, true, "Swamp Cave should block eastward entry from (2,20) into (3,20)")
    assert_equal(dirs["3,12"].west, true, "Swamp Cave should block eastward entry from (2,12) into (3,12)")
    assert_equal(dirs["3,12"].south, true, "Swamp Cave should block northward entry from (3,13) into (3,12)")
    assert_equal(dirs["4,12"].south, true, "Swamp Cave should block northward entry from (4,13) into (4,12)")
    assert_equal(dirs["2,7"].south, true, "Swamp Cave should block northward entry from (2,8) into (2,7)")
    assert_equal(dirs["4,20"].south, true, "Swamp Cave should block northward entry from (4,21) into (4,20)")
    assert_equal(dirs["4,20"].north, true, "Swamp Cave should block southward entry from (4,19) into (4,20)")
    assert_equal(dirs["4,20"].east, true, "Swamp Cave should block westward entry from (5,20) into (4,20)")
    assert_equal(dirs["2,22"].north, true, "Swamp Cave should block southward entry from (2,21) into (2,22)")
    assert_equal(dirs["3,22"].north, true, "Swamp Cave should block southward entry from (3,21) into (3,22)")
    assert_equal(dirs["4,22"].north, true, "Swamp Cave should block southward entry from (4,21) into (4,22)")
    assert_equal(dirs["5,22"].north, true, "Swamp Cave should block southward entry from (5,21) into (5,22)")
    assert_equal(dirs["2,25"].west, true, "Swamp Cave should block eastward entry from (1,25) into (2,25)")
    assert_equal(dirs["2,25"].east, true, "Swamp Cave should block westward entry from (3,25) into (2,25)")
    assert_equal(dirs["4,26"].west, true, "Swamp Cave should block eastward entry from (3,26) into (4,26)")
    assert_equal(dirs["4,29"].west, true, "Swamp Cave should block eastward entry from (3,29) into (4,29)")

    local out_of_bounds = env.map_reader.get_walkability_details(0x15, 0, 30)
    assert_equal(out_of_bounds.base_walkable, false, "Swamp Cave y=30 should stay out of bounds")
    assert_equal(out_of_bounds.reason, "out_of_bounds", "Swamp Cave y=30 should not become a corridor cell")

    local snapshot = env.map_reader.get_walkability_snapshot(0x15)
    assert_equal(snapshot[0][0], true, "walkability snapshot should include the north entrance")
    assert_equal(snapshot[25][0], true, "walkability snapshot should include the south end of the x=0 corridor")
    assert_equal(snapshot[26][0], false, "walkability snapshot should keep the lower x=0 wall closed")
    assert_equal(snapshot[28][0], true, "walkability snapshot should include the lower return-route west turn")
    assert_equal(snapshot[29][0], true, "walkability snapshot should include the ROM south-island stairs")
    assert_equal(snapshot[16][2], true, "walkability snapshot should include the live middle strip at (2,16)")
    assert_equal(snapshot[17][2], true, "walkability snapshot should include the live middle strip at (2,17)")
    assert_equal(snapshot[18][2], true, "walkability snapshot should include the live middle strip at (2,18)")

    save_module("pathfinder")
    package.loaded["pathfinder"] = nil
    local pathfinder = require "pathfinder"
    local corridor_path = pathfinder.find_path(0x15, 0, 0, 0, 25, {})
    assert_equal(corridor_path ~= nil, true, "Swamp Cave should pathfind from the north exit to the west-corridor bend")
    assert_equal(#corridor_path, 25, "Swamp Cave north-to-bend route should follow the x=0 corridor")

    local south_stairs_path = pathfinder.find_path(0x15, 0, 0, 0, 29, {})
    assert_equal(south_stairs_path ~= nil, true, "Swamp Cave should pathfind from the north exit to the south-island stairs")
    assert_equal(#south_stairs_path, 35, "Swamp Cave south-stairs route should detour around the lower directional blocks")
    assert_equal(path_has_step(south_stairs_path, 1, 24, "south"), false, "Swamp Cave south-stairs path should not retry the blocked (1,23)->DOWN seam")
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

    memory_bytes[0x600C] = 5
    memory_bytes[0x600D] = 20
    local door_stand_to_south = pathfinder.find_path(0x15, 5, 21, 0, 29, {})
    assert_equal(door_stand_to_south ~= nil, true, "Swamp Cave should route from the Gwaelin door stand to the south-island stairs")
    assert_equal(path_has_step(door_stand_to_south, 5, 22, "south"), false, "Swamp Cave door-to-south route should not retry the blocked (5,21)->DOWN seam")
    assert_equal(path_has_step(door_stand_to_south, 4, 22, "south"), false, "Swamp Cave door-to-south route should not retry the blocked (4,21)->DOWN seam")
    assert_equal(path_has_step(door_stand_to_south, 2, 25, "east"), false, "Swamp Cave door-to-south route should not retry the blocked (1,25)->RIGHT seam")

    local door_stand_to_north = pathfinder.find_path(0x15, 5, 21, 0, 0, {})
    assert_equal(door_stand_to_north ~= nil, true, "Swamp Cave should route from the Gwaelin door stand to the north exit")
    assert_equal(path_has_step(door_stand_to_north, 3, 12, "north"), false, "Swamp Cave door-to-north route should not retry the blocked (3,13)->UP seam")

    local south_stairs_to_princess = pathfinder.find_path(0x15, 0, 29, 5, 19, {})
    assert_equal(south_stairs_to_princess ~= nil, true, "Swamp Cave should route from the south-island stairs to the Princess stand when the door is open")
    assert_equal(path_has_step(south_stairs_to_princess, 3, 12, "east"), false, "Swamp Cave south-to-Princess route should not retry the blocked (2,12)->RIGHT seam")

    local north_exit_to_princess = pathfinder.find_path(0x15, 0, 0, 5, 19, {})
    assert_equal(north_exit_to_princess ~= nil, true, "Swamp Cave should route from the north exit to the Princess stand when the door is open")
    assert_equal(path_has_step(north_exit_to_princess, 1, 2, "east"), false, "Swamp Cave north-to-Princess route should not retry the blocked (0,2)->RIGHT seam")
    assert_equal(path_has_step(north_exit_to_princess, 1, 5, "east"), false, "Swamp Cave north-to-Princess route should not retry the blocked (0,5)->RIGHT seam")
    assert_equal(path_has_step(north_exit_to_princess, 1, 5, "north"), false, "Swamp Cave north-to-Princess route should not retry the blocked (1,6)->UP seam")
    assert_equal(path_has_step(north_exit_to_princess, 2, 6, "east"), false, "Swamp Cave north-to-Princess route should not retry the blocked (1,6)->RIGHT seam")
    assert_equal(path_has_step(north_exit_to_princess, 1, 7, "south"), false, "Swamp Cave north-to-Princess route should not retry the blocked (1,6)->DOWN seam")
    assert_equal(path_has_step(north_exit_to_princess, 1, 7, "east"), false, "Swamp Cave north-to-Princess route should not retry the blocked (0,7)->RIGHT seam")

    local noisy_top_to_princess = pathfinder.find_path(0x15, 3, 4, 5, 19, {})
    assert_equal(noisy_top_to_princess ~= nil, true, "Swamp Cave should route from the noisy top pocket to the Princess stand when the door is open")
    assert_equal(path_has_step(noisy_top_to_princess, 3, 5, "south"), false, "Swamp Cave top-pocket route should not retry the blocked (3,4)->DOWN seam")
    assert_equal(path_has_step(noisy_top_to_princess, 4, 4, "east"), false, "Swamp Cave top-pocket route should not retry the blocked (3,4)->RIGHT seam")
    assert_equal(path_has_step(noisy_top_to_princess, 2, 6, "south"), false, "Swamp Cave top-pocket route should not retry the blocked (2,5)->DOWN seam")
    assert_equal(path_has_step(noisy_top_to_princess, 3, 5, "east"), false, "Swamp Cave top-pocket route should not retry the blocked (2,5)->RIGHT seam")
    assert_equal(path_has_step(noisy_top_to_princess, 2, 3, "north"), false, "Swamp Cave top-pocket route should not retry the blocked (2,4)->UP seam")
    assert_equal(path_has_step(noisy_top_to_princess, 4, 4, "south"), false, "Swamp Cave top-pocket route should not retry the blocked (4,3)->DOWN seam")
    assert_equal(path_has_step(noisy_top_to_princess, 5, 14, "south"), false, "Swamp Cave top-pocket route should not retry the blocked (5,13)->DOWN seam")
    memory_bytes[0x600C] = 0
    memory_bytes[0x600D] = 0

    local post_battle_to_door = pathfinder.find_path(0x15, 3, 26, 5, 21, {})
    assert_equal(post_battle_to_door ~= nil, true, "Swamp Cave should route from the post-battle lower branch back to the Gwaelin door stand")
    for y = 9, 18 do
        assert_equal(path_has_step(post_battle_to_door, 1, y, "east"), false, "Swamp Cave post-battle door route should not retry blocked x=0 east re-entries")
    end
    assert_equal(path_has_step(post_battle_to_door, 1, 19, "east"), false, "Swamp Cave post-battle door route should not retry the blocked (0,19)->RIGHT seam")
    assert_equal(path_has_step(post_battle_to_door, 1, 20, "east"), false, "Swamp Cave post-battle door route should not retry the blocked (0,20)->RIGHT seam")
    assert_equal(path_has_step(post_battle_to_door, 1, 21, "east"), false, "Swamp Cave post-battle door route should not retry the blocked (0,21)->RIGHT seam")
    assert_equal(path_has_step(post_battle_to_door, 1, 22, "east"), false, "Swamp Cave post-battle door route should not retry the blocked (0,22)->RIGHT seam")
    assert_equal(path_has_step(post_battle_to_door, 3, 12, "east"), false, "Swamp Cave post-battle door route should not retry the blocked (2,12)->RIGHT seam")
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
    local data_start = 0x1010
    local rom_bytes = {
        [base] = 0x00,      -- CPU $9000 -> file offset $1010
        [base + 1] = 0x90,
        [base + 2] = 9,     -- width 10
        [base + 3] = 9,     -- height 10
        [base + 4] = 0,
    }
    fill_packed_map(rom_bytes, data_start, 10, 10, 0xA)
    local env = make_env({
        rom_bytes = rom_bytes,
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
