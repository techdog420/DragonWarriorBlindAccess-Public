-- test_map_crawler.lua
-- Focused unit tests for the review-only frontier crawler.

local original_preload = {}
local original_loaded = {}
local original_memory = _G.memory
local original_and = _G.AND
local original_io_open = io.open

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

local function shallow_copy(tbl)
    local copy = {}
    for k, v in pairs(tbl or {}) do
        copy[k] = v
    end
    return copy
end

local function make_env(options)
    options = options or {}
    local logs = {}
    local outputs = {}
    local subscribers = {}
    local route_active = false
    local injects = {}
    local inject_options = {}
    local cancellations = {}
    local record_block_calls = 0
    local active_step_state = nil
    local movement_resets = {}
    local write_calls = {}
    local seam_observations = shallow_copy(options.seam_observations or {})
    local nav_map_id = options.map_id or 0x0B
    local nav_x = options.x or 5
    local nav_y = options.y or 5
    local npc_bytes = {
        [0x00C5] = options.hp or 30,
        [0x0016] = options.terrain or 0x10,
    }
    local module_names = {
        "addresses",
        "auto_step",
        "debug_tools",
        "event_bus",
        "map_crawler",
        "map_reader",
        "maps",
        "navigation",
        "route_manager",
        "tolk",
    }

    for _, name in ipairs(module_names) do
        save_module(name)
        package.loaded[name] = nil
    end

    if options.npc_bytes then
        for address, value in pairs(options.npc_bytes) do
            npc_bytes[address] = value
        end
    end

    _G.AND = function(a, b)
        local result = 0
        local bit = 1
        a = tonumber(a) or 0
        b = tonumber(b) or 0
        while a > 0 and b > 0 do
            if (a % 2 == 1) and (b % 2 == 1) then
                result = result + bit
            end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            bit = bit * 2
        end
        return result
    end

    _G.memory = {
        readbyte = function(address)
            return npc_bytes[address] or 0
        end,
        writebyte = function(address, value)
            write_calls[#write_calls + 1] = {address = address, value = value}
            npc_bytes[address] = value
        end,
    }

    -- Intercept write-mode io.open so the crawler's export-file writer can
    -- run in tests without touching disk. Read-mode opens still pass through
    -- to the real io.open so package loading is unaffected.
    local captured_writes = {}
    io.open = function(path, mode)
        if mode == "w" or mode == "wb" then
            local buffer = {}
            captured_writes[path] = buffer
            return {
                write = function(self, str)
                    buffer[#buffer + 1] = tostring(str)
                    return self
                end,
                close = function() return true end,
            }
        end
        return original_io_open(path, mode)
    end

    package.preload["addresses"] = function()
        return {
            NPC_COUNT = 20,
            NPC_DATA_START = 0x0051,
            NPC_ENTRY_SIZE = 3,
            CURRENT_HP = 0x00C5,
            TERRAIN_OFFSET = 0x0016,
            PLAYER_X = 0x003A,
            PLAYER_Y = 0x003B,
        }
    end

    package.preload["debug_tools"] = function()
        return {
            DEBUG_MODE = true,
            info = function(msg) logs[#logs + 1] = tostring(msg) end,
            debug = function(msg) logs[#logs + 1] = tostring(msg) end,
            error = function(msg) logs[#logs + 1] = tostring(msg) end,
            record_block = function()
                record_block_calls = record_block_calls + 1
            end,
        }
    end

    package.preload["tolk"] = function()
        return {
            output_interrupt = function(msg)
                outputs[#outputs + 1] = tostring(msg)
            end,
        }
    end

    package.preload["event_bus"] = function()
        return {
            subscribe = function(event_name, fn)
                if not subscribers[event_name] then
                    subscribers[event_name] = {}
                end
                subscribers[event_name][#subscribers[event_name] + 1] = fn
                return #subscribers[event_name]
            end,
            publish = function(event_name, data)
                for _, fn in ipairs(subscribers[event_name] or {}) do
                    fn(data)
                end
            end,
        }
    end

    package.preload["navigation"] = function()
        return {
            get_position = function()
                return nav_map_id, nav_x, nav_y
            end,
        }
    end

    package.preload["maps"] = function()
        return {
            WORLD_MAP_ID = 0x01,
            is_overworld = function(map_id, terrain)
                return options.overworld == true or map_id == 0x01 or terrain == 0x00
            end,
        }
    end

    package.preload["route_manager"] = function()
        return {
            get_seam_observation = function(_, x, y, approach)
                local entry = seam_observations[x .. "," .. y .. ":" .. tostring(approach)]
                if not entry then
                    return nil
                end
                return shallow_copy(entry)
            end,
        }
    end

    package.preload["auto_step"] = function()
        return {
            inject_step = function(dir, opts)
                injects[#injects + 1] = dir
                inject_options[#inject_options + 1] = shallow_copy(opts or {})
                if options.active_step_state then
                    if type(options.active_step_state) == "function" then
                        active_step_state = options.active_step_state(dir, nav_x, nav_y)
                    else
                        active_step_state = shallow_copy(options.active_step_state)
                    end
                else
                    active_step_state = {
                        dir = dir,
                        start_x = nav_x,
                        start_y = nav_y,
                        movement_started = false,
                        source = "inject_step",
                    }
                end
                if active_step_state then
                    active_step_state.dir = active_step_state.dir or dir
                    active_step_state.start_x = active_step_state.start_x or nav_x
                    active_step_state.start_y = active_step_state.start_y or nav_y
                end
                if options.inject_refuse then
                    return false
                end
                route_active = true
                return true
            end,
            get_active_step_state = function()
                return active_step_state and shallow_copy(active_step_state) or nil
            end,
            is_route_active = function()
                return route_active
            end,
            cancel_active_step = function(clear_queued_route, force_release)
                cancellations[#cancellations + 1] = {
                    clear_queued_route = clear_queued_route,
                    force_release = force_release,
                }
                route_active = false
                active_step_state = nil
            end,
            reset_movement_engine_state = function(reason, opts)
                movement_resets[#movement_resets + 1] = {
                    reason = reason,
                    log = opts and opts.log,
                }
                return true
            end,
        }
    end

    package.preload["map_reader"] = function()
        local width = options.width or 10
        local height = options.height or 10
        local details = options.details or {}
        local hazards = options.hazards or {}
        local doors = options.doors or {}
        local directional_blocks = options.directional_blocks or {}
        local default_walkable = options.default_walkable
        if default_walkable == nil then default_walkable = true end
        return {
            get_tile_grid = function()
                return {}
            end,
            get_map_dimensions = function()
                return width, height
            end,
            get_directional_blocks = function()
                return directional_blocks
            end,
            is_hazard_cell = function(_, x, y)
                return hazards[x .. "," .. y] == true
            end,
            get_door_cell_context = function(_, x, y)
                local door = doors[x .. "," .. y]
                if not door then return nil end
                local copy = shallow_copy(door)
                copy.is_door = true
                copy.x = x
                copy.y = y
                copy.door_x = copy.door_x or x
                copy.door_y = copy.door_y or y
                return copy
            end,
            get_walkability_details = function(_, x, y)
                if x < 0 or y < 0 or x >= width or y >= height then
                    return {
                        effective_walkable = false,
                        permanent_blocked = false,
                        reason = "out_of_bounds",
                    }
                end
                local door = doors[x .. "," .. y]
                if door then
                    return {
                        effective_walkable = door.open == true,
                        permanent_blocked = false,
                        reason = door.open and "door_open" or "door_closed",
                        tile_type = door.tile_type or 6,
                    }
                end
                local detail = details[x .. "," .. y]
                if detail then
                    local copy = shallow_copy(detail)
                    if copy.effective_walkable == nil then
                        copy.effective_walkable = copy.permanent_blocked ~= true
                    end
                    if copy.permanent_blocked == nil then
                        copy.permanent_blocked = false
                    end
                    return copy
                end
                return {
                    effective_walkable = default_walkable,
                    permanent_blocked = default_walkable ~= true,
                    reason = "tile_type",
                    tile_type = 1,
                }
            end,
        }
    end

    local crawler = require "map_crawler"
    local bus = require "event_bus"

    return {
        crawler = crawler,
        logs = logs,
        outputs = outputs,
        injects = injects,
        inject_options = inject_options,
        cancellations = cancellations,
        movement_resets = movement_resets,
        record_block_calls = function() return record_block_calls end,
        write_calls = write_calls,
        set_hp = function(value) npc_bytes[0x00C5] = value end,
        set_position = function(map_id, x, y)
            nav_map_id = map_id or nav_map_id
            nav_x = x or nav_x
            nav_y = y or nav_y
        end,
        set_seam_observation = function(x, y, approach, classification)
            local key = x .. "," .. y .. ":" .. tostring(approach)
            if not classification then
                seam_observations[key] = nil
                return
            end
            seam_observations[key] = {classification = classification}
        end,
        tick = function(can_walk, context)
            crawler.tick(can_walk ~= false, context)
        end,
        publish_blocked = function(dir, from_x, from_y, extra)
            route_active = false
            active_step_state = nil
            extra = extra or {}
            bus.publish("route_blocked", {
                from_x = from_x or nav_x,
                from_y = from_y or nav_y,
                dir = dir,
                source = extra.source or "inject_step",
                movement_started = extra.movement_started,
                movement_start_frame = extra.movement_start_frame,
                timeout_retries = extra.timeout_retries,
                turn_represses = extra.turn_represses,
                inject_limit = extra.inject_limit,
                timeout = extra.timeout,
                timing_suspect = extra.timing_suspect,
            })
        end,
        publish_step = function(dir, from_x, from_y, to_x, to_y, new_map_id, extra)
            route_active = false
            active_step_state = nil
            nav_map_id = new_map_id or nav_map_id
            nav_x = to_x
            nav_y = to_y
            extra = extra or {}
            bus.publish("route_step_completed", {
                from_x = from_x,
                from_y = from_y,
                dir = dir,
                to_x = to_x,
                to_y = to_y,
                source = extra.source or "inject_step",
                timeout_retries = extra.timeout_retries,
                turn_represses = extra.turn_represses,
                frames = extra.frames,
                inject_limit = extra.inject_limit,
            })
        end,
        read_npc_slot = function(slot)
            local base = 0x0051 + slot * 3
            return npc_bytes[base] or 0, npc_bytes[base + 1] or 0, npc_bytes[base + 2] or 0
        end,
        clear_auto_step_state = function()
            active_step_state = nil
            route_active = false
        end,
        list_captured_paths = function()
            local paths = {}
            for path in pairs(captured_writes) do
                paths[#paths + 1] = path
            end
            table.sort(paths)
            return paths
        end,
        get_captured_file = function(path)
            local buffer = captured_writes[path]
            if not buffer then return nil end
            return table.concat(buffer)
        end,
        restore = function()
            restore_modules(module_names)
            _G.memory = original_memory
            _G.AND = original_and
            io.open = original_io_open
        end,
    }
end

local function assert_equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local function assert_contains(haystack, needle, message)
    if not string.find(haystack, needle, 1, true) then
        error(string.format("%s: missing %s in %s", message, needle, haystack), 2)
    end
end

local function assert_not_contains(haystack, needle, message)
    if string.find(haystack, needle, 1, true) then
        error(string.format("%s: unexpected %s in %s", message, needle, haystack), 2)
    end
end

local function count_occurrences(haystack, needle)
    local count = 0
    local pos = 1
    while true do
        local found = string.find(haystack, needle, pos, true)
        if not found then
            return count
        end
        count = count + 1
        pos = found + #needle
    end
end

local STEP_SETTLE_TEST_FRAMES = 16

local function settle_completed_step(env)
    for _ = 1, STEP_SETTLE_TEST_FRAMES do
        env.tick(true)
    end
end

local function find_captured_path(env, suffix)
    for _, path in ipairs(env.list_captured_paths()) do
        if path:sub(-#suffix) == suffix then
            return path
        end
    end
    return nil
end

local tests = {}

function tests.mobile_npcs_are_parked_and_restored_while_stationary_npcs_stay()
    local env = make_env({
        npc_bytes = {
            [0x0051] = 10, [0x0052] = 10, [0x0053] = 2,
            [0x0054] = 7,  [0x0055] = 5,  [0x0056] = 0,
        },
    })

    assert_equal(env.crawler.start("max_edges=1"), true, "crawler should start")
    local mob0, mob1, mob2 = env.read_npc_slot(0)
    local stat0, stat1, stat2 = env.read_npc_slot(1)
    assert_equal(mob0 % 32, 31, "mobile NPC x should be parked")
    assert_equal(mob1 % 32, 31, "mobile NPC y should be parked")
    assert_equal(mob2, 2, "mobile movement byte should be preserved")
    assert_equal(stat0, 7, "stationary NPC x byte should stay in place")
    assert_equal(stat1, 5, "stationary NPC y byte should stay in place")
    assert_equal(stat2, 0, "stationary NPC movement byte should stay zero")

    env.crawler.stop()
    mob0, mob1, mob2 = env.read_npc_slot(0)
    assert_equal(mob0, 10, "mobile NPC x should restore")
    assert_equal(mob1, 10, "mobile NPC y should restore")
    assert_equal(mob2, 2, "mobile movement byte should restore")

    env.restore()
end

function tests.abort_on_low_hp_restores_parked_npcs()
    local env = make_env({
        npc_bytes = {
            [0x0051] = 10, [0x0052] = 10, [0x0053] = 2,
        },
    })

    assert_equal(env.crawler.start("max_edges=1"), true, "crawler should start")
    env.tick(true)
    assert_equal(env.injects[1], "up", "low HP test should have an active probe before abort")
    env.set_hp(8)
    env.tick(true)
    local b0, b1, b2 = env.read_npc_slot(0)
    assert_equal(#env.cancellations, 1, "low HP abort should cancel the active step")
    assert_equal(env.cancellations[1].force_release, true, "low HP abort should force input release")
    assert_equal(b0, 10, "low HP abort should restore mobile NPC x")
    assert_equal(b1, 10, "low HP abort should restore mobile NPC y")
    assert_equal(b2, 2, "low HP abort should restore mobile NPC movement")
    assert_equal(env.crawler.is_active(), false, "crawler should stop after low HP abort")

    env.restore()
end

function tests.manual_stop_force_releases_active_step()
    local env = make_env()

    assert_equal(env.crawler.start("max_edges=1"), true, "crawler should start")
    env.tick(true)
    assert_equal(env.injects[1], "up", "first probe should be active")
    env.crawler.stop()
    assert_equal(#env.cancellations, 1, "manual stop should cancel auto_step")
    assert_equal(env.cancellations[1].clear_queued_route, true, "manual stop should clear queued route")
    assert_equal(env.cancellations[1].force_release, true, "manual stop should force input release")

    env.restore()
end

function tests.manual_stop_waits_for_committed_step_to_settle()
    local env = make_env({
        npc_bytes = {
            [0x0051] = 10, [0x0052] = 10, [0x0053] = 2,
        },
        active_step_state = {
            movement_started = true,
            movement_start_frame = 1,
            source = "inject_step",
        },
    })

    assert_equal(env.crawler.start("max_edges=1"), true, "crawler should start")
    env.tick(true)
    local ok, msg = env.crawler.stop()
    assert_equal(ok, true, "manual stop should succeed")
    assert_equal(msg, "Stopping map crawl on map 0B", "committed stop should stay active until movement settles")
    assert_equal(env.crawler.is_active(), true, "crawler should remain active while the committed step settles")
    assert_equal(#env.cancellations, 1, "manual stop should cancel auto_step")
    local parked0, parked1, parked2 = env.read_npc_slot(0)
    assert_equal(parked0 % 32, 31, "mobile NPC x should stay parked until stop settling completes")
    assert_equal(parked1 % 32, 31, "mobile NPC y should stay parked until stop settling completes")
    assert_equal(parked2, 2, "mobile NPC movement byte should stay preserved while settling")

    env.tick(true)
    assert_equal(env.crawler.is_active(), true, "crawler should still wait while the player remains on the stop origin tile")

    env.set_position(0x0B, 5, 4)
    env.tick(true)
    assert_equal(env.crawler.is_active(), false, "crawler should finish once the committed stop step lands")
    local b0, b1, b2 = env.read_npc_slot(0)
    assert_equal(b0, 10, "mobile NPC x should restore after stop settling finishes")
    assert_equal(b1, 10, "mobile NPC y should restore after stop settling finishes")
    assert_equal(b2, 2, "mobile NPC movement byte should restore after stop settling finishes")

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "MAP_CRAWL_STOP_WAIT", "manual stop should log the deferred settle state")
    assert_contains(joined, "MAP_CRAWL_STOP_SETTLED", "manual stop should log the final settled position")
    assert_contains(joined, "MAP_CRAWL_FINISH run=1 map=0x0B completed=false reason=manual_stop",
        "manual stop should finish only after settle completes")

    env.restore()
end

function tests.false_wall_movement_exports_passthrough_candidate()
    local env = make_env({
        details = {
            ["5,4"] = {effective_walkable = false, permanent_blocked = false, reason = "tile_type", tile_type = 0},
        },
    })

    assert_equal(env.crawler.start("attempts=1,max_edges=1"), true, "crawler should start")
    env.tick(true)
    assert_equal(env.injects[1], "up", "first probe should go north")
    env.publish_step("up", 5, 5, 5, 4)
    env.crawler.export_candidates(0x0B)
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=false_wall_candidate", "false wall movement should be classified")
    assert_contains(joined, "MAP_CRAWL_EXPORT_PASSTHROUGH map=0x0B line='[\"5,4\"] = true,'",
        "false wall movement should export passthrough")
    assert_equal(env.record_block_calls(), 0, "crawler should not write legacy block records")

    env.restore()
end

function tests.modeled_floor_block_exports_directional_candidate()
    local env = make_env()

    assert_equal(env.crawler.start("attempts=2,max_edges=1"), true, "crawler should start")
    env.tick(true)
    env.publish_blocked("up", 5, 5)
    settle_completed_step(env)
    env.tick(true)
    env.publish_blocked("up", 5, 5)
    env.crawler.export_candidates(0x0B)
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=directional_block_candidate", "open modeled floor block should be classified")
    assert_contains(joined, "MAP_CRAWL_EXPORT_DIRECTIONAL map=0x0B line='[\"5,4\"] = {south = true},'",
        "open modeled floor block should export directional approach")
    assert_equal(env.record_block_calls(), 0, "crawler should not write legacy block records")

    env.restore()
end

function tests.already_modeled_directional_block_is_not_reexported()
    local env = make_env({
        directional_blocks = {
            ["5,4"] = {south = true},
        },
    })

    assert_equal(env.crawler.start("attempts=2,max_edges=1"), true, "crawler should start")
    env.tick(true)
    env.publish_blocked("up", 5, 5)
    settle_completed_step(env)
    env.tick(true)
    env.publish_blocked("up", 5, 5)
    env.crawler.export_candidates(0x0B)
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=modeled_blocked", "existing directional block should stay modeled")
    assert_contains(joined, "note=approach_already_modeled", "existing directional block should explain why it was skipped")
    assert_not_contains(joined, "MAP_CRAWL_EXPORT_DIRECTIONAL", "existing directional block should not export again")
    assert_equal(env.record_block_calls(), 0, "crawler should not write legacy block records")

    env.restore()
end

function tests.mixed_probe_stays_diagnostic_and_exports_nothing()
    local env = make_env({
        details = {
            ["5,4"] = {effective_walkable = false, permanent_blocked = false, reason = "tile_type", tile_type = 0},
        },
    })

    assert_equal(env.crawler.start("attempts=2,max_edges=1"), true, "crawler should start")
    env.tick(true)
    env.publish_blocked("up", 5, 5)
    settle_completed_step(env)
    env.tick(true)
    env.publish_step("up", 5, 5, 5, 4)
    env.crawler.export_candidates(0x0B)
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=mixed_probe", "blocked then moved edge should stay mixed")
    assert_contains(joined, "no_review_candidates=true", "mixed probe should not export candidates")
    assert_not_contains(joined, "MAP_CRAWL_EXPORT_PASSTHROUGH", "mixed probe should not export passthrough")
    assert_not_contains(joined, "MAP_CRAWL_EXPORT_DIRECTIONAL", "mixed probe should not export directional block")

    env.restore()
end

function tests.blocked_edge_from_mixed_false_wall_origin_stays_diagnostic()
    local env = make_env({
        details = {
            ["5,4"] = {effective_walkable = false, permanent_blocked = false, reason = "tile_type", tile_type = 0},
            ["5,3"] = {effective_walkable = true, permanent_blocked = false, reason = "tile_type", tile_type = 1},
        },
    })

    assert_equal(env.crawler.start("attempts=2,max_edges=2"), true, "crawler should start")
    env.tick(true)
    assert_equal(env.injects[1], "up", "first probe should enter the hidden cell")
    env.publish_blocked("up", 5, 5)
    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[2], "up", "retry should still target the hidden cell")
    env.publish_step("up", 5, 5, 5, 4)

    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[3], "down", "crawler should backtrack instead of exploring from the untrusted hidden cell")
    env.publish_step("down", 5, 4, 5, 5)

    env.crawler.export_candidates(0x0B)
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=mixed_probe", "entry into the hidden cell should stay mixed")
    assert_contains(joined, "MAP_CRAWL_UNSTABLE_CANDIDATE map=0x0B cell=(5,4) reason=mixed_false_wall_origin",
        "mixed false-wall entries should mark the origin untrusted")
    assert_not_contains(joined, "class=directional_block_candidate",
        "untrusted-origin blocks should not look like clean directional candidates")
    assert_not_contains(joined, "MAP_CRAWL_EXPORT_DIRECTIONAL map=0x0B line='[\"5,3\"] = {south = true},'",
        "untrusted-origin blocks should not export directional candidates")

    env.restore()
end

function tests.modeled_floor_mixed_probe_origin_is_not_explored()
    local env = make_env()

    assert_equal(env.crawler.start("attempts=2,max_edges=2"), true, "crawler should start")
    env.tick(true)
    assert_equal(env.injects[1], "up", "first probe should target the modeled floor cell")
    env.publish_blocked("up", 5, 5)
    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[2], "up", "retry should still target the modeled floor cell")
    env.publish_step("up", 5, 5, 5, 4)

    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[3], "down", "crawler should backtrack instead of exploring from a mixed-entry floor cell")
    env.publish_step("down", 5, 4, 5, 5)

    env.crawler.export_candidates(0x0B)
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=mixed_probe", "mixed modeled-floor entry should stay diagnostic")
    assert_contains(joined, "MAP_CRAWL_UNSTABLE_CANDIDATE map=0x0B cell=(5,4) reason=mixed_probe_origin",
        "mixed modeled-floor entries should mark the origin untrusted")
    assert_not_contains(joined, "MAP_CRAWL_PROBE run=1 map=0x0B from=(5,4) dir=up",
        "crawler should not probe outward from a mixed-entry floor cell")
    assert_not_contains(joined, "MAP_CRAWL_EXPORT_DIRECTIONAL",
        "mixed-entry floor cells should not lead to downstream directional exports")

    env.restore()
end

function tests.timing_suspect_block_then_move_keeps_modeled_floor_explorable()
    local env = make_env()

    assert_equal(env.crawler.start("attempts=2,max_edges=2"), true, "crawler should start")
    env.tick(true)
    assert_equal(env.injects[1], "up", "first probe should target the modeled floor cell")
    env.publish_blocked("up", 5, 5, {
        movement_started = true,
        movement_start_frame = 1,
        timeout_retries = 1,
        inject_limit = 10,
        timeout = 60,
    })
    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[2], "up", "timing-suspect block should still retry the edge")
    env.publish_step("up", 5, 5, 5, 4)

    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[3], "up",
        "timing-suspect block followed by movement should not poison a modeled-floor origin")

    env.crawler.export_candidates(0x0B)
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=open_floor", "eventual movement after timing-suspect block should stay passable")
    assert_contains(joined, "note=timing_suspect_retry",
        "timing-suspect movement should remain visible in logs")
    assert_not_contains(joined, "MAP_CRAWL_UNSTABLE_CANDIDATE map=0x0B cell=(5,4) reason=mixed_probe_origin",
        "timing-suspect block should not mark the modeled-floor origin unstable")
    assert_not_contains(joined, "class=mixed_probe",
        "timing-suspect block should not become a clean blocked/moved mixed probe")

    env.restore()
end

function tests.timing_suspect_blocked_floor_stays_review_only()
    local env = make_env()

    assert_equal(env.crawler.start("attempts=1,max_edges=1"), true, "crawler should start")
    env.tick(true)
    env.publish_blocked("up", 5, 5, {
        movement_started = true,
        movement_start_frame = 1,
        timeout_retries = 1,
        inject_limit = 10,
        timeout = 60,
    })
    env.crawler.export_candidates(0x0B)
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=timing_suspect_blocked",
        "movement-start timeout should stay diagnostic when it never resolves")
    assert_contains(joined, "note=movement_started_timeout",
        "timing-suspect block should explain why it was not promoted")
    assert_not_contains(joined, "MAP_CRAWL_EXPORT_DIRECTIONAL",
        "timing-suspect block should not export a directional candidate")

    env.restore()
end

function tests.pending_repress_false_wall_stays_diagnostic_and_exports_nothing()
    local env = make_env({
        details = {
            ["5,4"] = {effective_walkable = false, permanent_blocked = false, reason = "tile_type", tile_type = 0},
        },
    })

    assert_equal(env.crawler.start("attempts=1,max_edges=1"), true, "crawler should start")
    env.tick(true)
    env.publish_step("up", 5, 5, 5, 4, nil, {
        source = "pending_repress",
        timeout_retries = 1,
        turn_represses = 1,
        frames = 38,
        inject_limit = 12,
    })
    env.crawler.export_candidates(0x0B)
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=timing_suspect_false_wall",
        "pending-repress false wall should stay timing-suspect")
    assert_contains(joined, "MAP_CRAWL_UNSTABLE_CANDIDATE map=0x0B cell=(5,4) reason=timing_suspect_false_wall",
        "timing-suspect false wall should be marked unstable for the rest of the run")
    assert_contains(joined, "no_review_candidates=true",
        "pending-repress false wall should not export as a normal candidate")
    assert_not_contains(joined, "MAP_CRAWL_EXPORT_PASSTHROUGH",
        "pending-repress false wall should not export passthrough")

    env.restore()
end

function tests.noisy_seam_prunes_stale_passthrough_candidate_from_report_and_export()
    local env = make_env({
        details = {
            ["5,4"] = {effective_walkable = false, permanent_blocked = false, reason = "tile_type", tile_type = 0},
        },
    })

    assert_equal(env.crawler.start("attempts=1,max_edges=1"), true, "crawler should start")
    env.tick(true)
    env.publish_step("up", 5, 5, 5, 4)
    env.set_seam_observation(5, 4, "south", "noisy")
    env.crawler.report(0x0B)
    env.crawler.export_candidates(0x0B)
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined,
        "MAP_CRAWL_SUMMARY map=0x0B edges=1 passthrough_candidates=0 directional_candidate_cells=0",
        "noisy seam updates should prune stale passthrough candidates from the summary")
    assert_not_contains(joined, "MAP_CRAWL_EXPORT_PASSTHROUGH map=0x0B line='[\"5,4\"] = true,'",
        "noisy seam updates should prune stale passthrough exports")

    env.restore()
end

function tests.noisy_seam_prunes_stale_directional_candidate_from_report_and_export()
    local env = make_env()

    assert_equal(env.crawler.start("attempts=1,max_edges=1"), true, "crawler should start")
    env.tick(true)
    env.publish_blocked("up", 5, 5)
    env.set_seam_observation(5, 4, "south", "noisy")
    env.crawler.report(0x0B)
    env.crawler.export_candidates(0x0B)
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined,
        "MAP_CRAWL_SUMMARY map=0x0B edges=1 passthrough_candidates=0 directional_candidate_cells=0",
        "noisy seam updates should prune stale directional candidates from the summary")
    assert_not_contains(joined, "MAP_CRAWL_EXPORT_DIRECTIONAL map=0x0B line='[\"5,4\"] = {south = true},'",
        "noisy seam updates should prune stale directional exports")

    env.restore()
end

function tests.hazard_destination_is_skipped_without_injection()
    local env = make_env({
        hazards = {["5,4"] = true},
    })

    assert_equal(env.crawler.start("max_edges=1"), true, "crawler should start")
    env.tick(true)
    local joined = table.concat(env.logs, "\n")
    assert_equal(#env.injects, 0, "hazard destination should not be probed")
    assert_contains(joined, "class=hazard_skipped", "hazard skip should be logged")

    env.restore()
end

function tests.boundary_destination_is_logged_without_leaving_map()
    local env = make_env({
        y = 1,
        details = {
            ["5,0"] = {effective_walkable = false, permanent_blocked = false, reason = "engine_boundary", tile_type = 2},
        },
    })

    assert_equal(env.crawler.start("max_edges=1"), true, "crawler should start")
    env.tick(true)
    local joined = table.concat(env.logs, "\n")
    assert_equal(#env.injects, 0, "engine boundary destination should not be probed")
    assert_contains(joined,
        "MAP_CRAWL_EDGE run=1 map=0x0B index=1 from=(5,1) dir=up dest=(5,0) class=boundary_frontier",
        "boundary should be logged against the active crawl run and map")
    assert_contains(joined, "note=destination_boundary", "boundary log should explain the skip")

    env.restore()
end

function tests.boundary_from_false_wall_origin_removes_passthrough_candidate()
    local env = make_env({
        details = {
            ["5,4"] = {effective_walkable = false, permanent_blocked = false, reason = "tile_type", tile_type = 0},
            ["5,3"] = {effective_walkable = false, permanent_blocked = false, reason = "engine_boundary", tile_type = 0},
        },
    })

    assert_equal(env.crawler.start("attempts=1,max_edges=10"), true, "crawler should start")
    env.tick(true)
    assert_equal(env.injects[1], "up", "first probe should discover false wall")
    env.publish_step("up", 5, 5, 5, 4)
    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[2], "down", "unstable boundary-origin cell should backtrack instead of probing sideways")
    env.crawler.export_candidates(0x0B)
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=false_wall_candidate", "false wall movement should first be classified")
    assert_contains(joined, "class=boundary_frontier", "boundary from the false-wall cell should be classified")
    assert_contains(joined, "MAP_CRAWL_UNSTABLE_CANDIDATE map=0x0B cell=(5,4) reason=origin_boundary_frontier",
        "boundary-frontier origin should mark the prior passthrough candidate unstable")
    assert_not_contains(joined, "MAP_CRAWL_EXPORT_PASSTHROUGH map=0x0B line='[\"5,4\"] = true,'",
        "unstable boundary-adjacent false-wall cell should not export as a normal passthrough")

    env.restore()
end

function tests.return_to_frontier_completion_does_not_ping_pong()
    local env = make_env({
        doors = {
            ["5,3"] = {open = false, door_x = 5, door_y = 3},
            ["4,4"] = {open = false, door_x = 4, door_y = 4},
            ["6,4"] = {open = false, door_x = 6, door_y = 4},
        },
    })

    assert_equal(env.crawler.start("attempts=1,max_edges=10"), true, "crawler should start")
    env.tick(true)
    assert_equal(env.injects[1], "up", "first probe should discover the northern cell")
    env.publish_step("up", 5, 5, 5, 4)

    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[2], "down", "known parent edge should be probed from child")
    env.publish_step("down", 5, 4, 5, 5)

    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[3], "up", "crawler should return to the child frontier")
    env.publish_step("up", 5, 5, 5, 4)

    settle_completed_step(env)
    env.tick(true)
    local joined = table.concat(env.logs, "\n")
    assert_equal(count_occurrences(joined, "kind=return_to_frontier"), 1,
        "completed frontier return should not schedule a ping-pong return")
    assert_contains(joined, "kind=backtrack", "crawler should resume DFS backtracking after frontier return")

    env.restore()
end

function tests.failed_return_to_frontier_finishes_without_promoting_candidate()
    local env = make_env()

    assert_equal(env.crawler.start("attempts=1,max_edges=10"), true, "crawler should start")

    env.tick(true)
    assert_equal(env.injects[1], "up", "first probe should discover the northern cell")
    env.publish_step("up", 5, 5, 5, 4)

    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[2], "up", "next probe from the child goes north")
    env.publish_blocked("up", 5, 4)

    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[3], "down", "child should probe the already visited parent")
    env.publish_step("down", 5, 4, 5, 5)

    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[4], "up", "pending return should try to restore the child frontier")
    env.publish_blocked("up", 5, 5)

    assert_equal(env.crawler.is_active(), false,
        "failed return_to_frontier should stop before later position drift")

    env.crawler.export_candidates(0x0B)
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=return_to_frontier_blocked",
        "failed frontier return should be classified diagnostically")
    assert_contains(joined, "reason=return_to_frontier_blocked",
        "finish_run should record the frontier-return failure reason")
    assert_not_contains(joined, "MAP_CRAWL_EXPORT_DIRECTIONAL map=0x0B line='[\"5,4\"] = ",
        "failed frontier return must not promote the already visited child as a directional candidate")

    env.restore()
end

function tests.walk_sweep_failed_return_to_frontier_exports_as_unsafe_abort()
    local env = make_env()

    assert_equal(env.crawler.start_walk_sweep("attempts=1,max_edges=10,park_mobile_npcs=false"),
        true, "walk sweep should start")

    env.tick(true)
    assert_equal(env.injects[1], "up", "first probe should discover the northern cell")
    env.publish_step("up", 5, 5, 5, 4)

    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[2], "up", "child should probe north")
    env.publish_blocked("up", 5, 4)

    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[3], "down", "child should probe the visited parent")
    env.publish_step("down", 5, 4, 5, 5)

    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[4], "up", "frontier return should try to restore child position")
    env.publish_blocked("up", 5, 5)

    assert_equal(env.crawler.is_active(), false,
        "failed return_to_frontier should finish the walk sweep")

    local json_path = find_captured_path(env, "sweep_walk_0b_run001.json")
    local json = env.get_captured_file(json_path)
    assert_contains(json, '"reason": "return_to_frontier_blocked"',
        "walk sweep JSON should preserve the recovery failure reason")
    assert_contains(json, '"status": "unsafe_abort"',
        "frontier-return recovery failure should export as an unsafe abort")
    assert_contains(json, '"source_classification": "return_to_frontier_blocked"',
        "unsafe abort bucket should preserve the diagnostic class")
    assert_contains(json, '"unknown_edges": 0',
        "diagnostic recovery failures should not inflate unknown geometry review count")
    assert_contains(json, '"unsafe_aborts": 1',
        "diagnostic recovery failure should increment unsafe abort count")

    env.restore()
end

function tests.unexpected_landing_aborts_without_promoting_candidate()
    local env = make_env({
        details = {
            ["5,4"] = {effective_walkable = false, permanent_blocked = false, reason = "tile_type", tile_type = 0},
        },
    })

    assert_equal(env.crawler.start("attempts=1,max_edges=10"), true, "crawler should start")
    env.tick(true)
    assert_equal(env.injects[1], "up", "first probe should start")
    env.publish_step("up", 5, 5, 5, 6)
    assert_equal(env.crawler.is_active(), false, "unexpected landing should stop crawler")
    env.crawler.export_candidates(0x0B)
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=movement_drift", "unexpected landing should be diagnostic")
    assert_contains(joined, "reason=movement_drift", "unexpected landing should finish as movement drift")
    assert_contains(joined, "no_review_candidates=true", "movement drift should not export passthroughs")

    env.restore()
end

function tests.pending_return_origin_drift_aborts_before_injection()
    local env = make_env({
        doors = {
            ["5,3"] = {open = false, door_x = 5, door_y = 3},
        },
    })

    assert_equal(env.crawler.start("attempts=1,max_edges=10"), true, "crawler should start")
    env.tick(true)
    env.publish_step("up", 5, 5, 5, 4)
    settle_completed_step(env)
    env.tick(true)
    env.publish_step("down", 5, 4, 5, 5)
    settle_completed_step(env)
    env.set_position(0x0B, 5, 6)
    local before = #env.injects
    env.tick(true)
    assert_equal(env.crawler.is_active(), false, "pending return origin drift should stop crawler")
    assert_equal(#env.injects, before, "origin drift should abort before injecting another step")
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=position_drift", "pending return origin drift should be logged")
    assert_contains(joined, "note=start_edge_position_mismatch", "position drift should explain start-edge mismatch")

    env.restore()
end

function tests.map_change_records_transition_and_stops()
    local env = make_env()

    assert_equal(env.crawler.start("attempts=1,max_edges=10"), true, "crawler should start")
    env.tick(true)
    env.publish_step("up", 5, 5, 102, 72, 0x01)
    assert_equal(env.crawler.is_active(), false, "map transition should stop crawler")
    assert_equal(env.crawler.report(), 1, "default report should use latest crawl map after transition")
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=transition_candidate", "map change should record transition")
    assert_contains(joined, "reason=map_change", "map change should finish crawl")
    assert_contains(joined, "MAP_CRAWL_SUMMARY map=0x0B edges=1", "post-transition report should not default to world map")

    env.restore()
end

function tests.tick_detected_map_change_records_active_transition_before_finish()
    local env = make_env()

    assert_equal(env.crawler.start("attempts=1,max_edges=10"), true, "crawler should start")
    env.tick(true)
    assert_equal(env.injects[1], "up", "first probe should start")
    env.set_position(0x01, 102, 72)
    env.tick(true)
    assert_equal(env.crawler.is_active(), false, "tick-detected map transition should stop crawler")
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=transition_candidate", "tick-detected map change should record active edge")
    assert_contains(joined, "reason=map_change edges=1", "map-change finish should retain transition edge")

    env.restore()
end

function tests.closed_door_is_reported_without_probe()
    local env = make_env({
        doors = {
            ["5,4"] = {open = false, door_x = 5, door_y = 4, open_slots = {"0:1,1"}},
        },
    })

    assert_equal(env.crawler.start("max_edges=1"), true, "crawler should start")
    env.tick(true)
    local joined = table.concat(env.logs, "\n")
    assert_equal(#env.injects, 0, "closed door should not be probed")
    assert_contains(joined, "class=door_frontier", "closed door should be a frontier")
    assert_contains(joined, "door=(5,4) open=false", "closed door log should include RAM/open-state context")

    env.restore()
end

function tests.open_door_is_crawled_with_door_context()
    local env = make_env({
        doors = {
            ["5,4"] = {open = true, door_x = 5, door_y = 4, open_slots = {"0:5,4"}},
        },
    })

    assert_equal(env.crawler.start("attempts=1,max_edges=1"), true, "crawler should start")
    env.tick(true)
    assert_equal(env.injects[1], "up", "open door should be probed")
    env.publish_step("up", 5, 5, 5, 4)
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=open_door_passage", "open door movement should be classified")
    assert_contains(joined, "door=(5,4) open=true", "open door log should include RAM/open-state context")

    env.restore()
end

function tests.stationary_npc_blocks_cell_without_geometry_candidate()
    local env = make_env({
        npc_bytes = {
            [0x0051] = 5, [0x0052] = 4, [0x0053] = 0,
        },
    })

    assert_equal(env.crawler.start("max_edges=1"), true, "crawler should start")
    env.tick(true)
    env.crawler.export_candidates(0x0B)
    local joined = table.concat(env.logs, "\n")
    assert_equal(#env.injects, 0, "stationary NPC destination should not be probed")
    assert_contains(joined, "class=stationary_npc_blocked", "stationary NPC block should be logged")
    assert_contains(joined, "no_review_candidates=true", "stationary NPC block should not export geometry")

    env.restore()
end

function tests.overworld_crawl_is_refused()
    local env = make_env({overworld = true})

    local ok, err = env.crawler.start()
    assert_equal(ok, false, "overworld crawl should be refused")
    assert_contains(err, "overworld", "overworld refusal should explain why")

    env.restore()
end

function tests.failed_backtrack_finishes_without_promoting_parent_candidate()
    local env = make_env()

    assert_equal(env.crawler.start("attempts=1,max_edges=20"), true, "crawler should start")

    -- DFS into (5,4) so a backtrack frame is queued behind it.
    env.tick(true)
    assert_equal(env.injects[1], "up", "first probe goes up into the child cell")
    env.publish_step("up", 5, 5, 5, 4)

    -- Exhaust the child's directions: up blocks, down returns to parent, then
    -- left and right both block.
    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[2], "up", "next probe from (5,4) goes up")
    env.publish_blocked("up", 5, 4)

    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[3], "down", "next probe from (5,4) revisits the parent")
    env.publish_step("down", 5, 4, 5, 5)

    -- pending_return walks the player back to the frontier cell.
    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[4], "up", "pending_return restores the frontier position")
    env.publish_step("up", 5, 5, 5, 4)

    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[5], "left", "next probe from (5,4) goes left")
    env.publish_blocked("left", 5, 4)

    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[6], "right", "next probe from (5,4) goes right")
    env.publish_blocked("right", 5, 4)

    -- All four directions exhausted at (5,4). Crawler issues a backtrack down
    -- to the parent (5,5). Make that backtrack itself fail.
    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[7], "down", "exhausted child triggers a backtrack down")
    env.publish_blocked("down", 5, 4)

    assert_equal(env.crawler.is_active(), false, "failed backtrack should finish the crawler")

    env.crawler.export_candidates(0x0B)
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=backtrack_blocked",
        "failed backtrack should be classified diagnostically")
    assert_contains(joined, "reason=backtrack_blocked",
        "finish_run should record the backtrack_blocked reason")
    assert_not_contains(joined, "MAP_CRAWL_EXPORT_DIRECTIONAL map=0x0B line='[\"5,5\"] = ",
        "failed backtrack must not promote the parent cell as a directional candidate")
    assert_contains(joined, "MAP_CRAWL_EXPORT_DIRECTIONAL map=0x0B line='[\"5,3\"] = {south = true},'",
        "legitimate directional candidates collected before the backtrack should still export")

    env.restore()
end

function tests.deep_dfs_backtracks_through_multiple_frames()
    local env = make_env()
    assert_equal(env.crawler.start("attempts=1,max_edges=50"), true, "crawler should start")

    -- DFS straight up: (5,5) -> (5,4) -> (5,3) -> (5,2).
    env.tick(true)
    assert_equal(env.injects[#env.injects], "up", "depth 1 probe goes up")
    env.publish_step("up", 5, 5, 5, 4)
    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[#env.injects], "up", "depth 2 probe goes up")
    env.publish_step("up", 5, 4, 5, 3)
    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[#env.injects], "up", "depth 3 probe goes up")
    env.publish_step("up", 5, 3, 5, 2)

    -- Exhaust (5,2): north blocks, south revisits (5,3) via pending_return,
    -- west and east block.
    settle_completed_step(env)
    env.tick(true)
    env.publish_blocked("up", 5, 2)
    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[#env.injects], "down", "(5,2) tries down toward already-visited (5,3)")
    env.publish_step("down", 5, 2, 5, 3)
    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[#env.injects], "up", "pending_return takes player back to the frontier")
    env.publish_step("up", 5, 3, 5, 2)
    settle_completed_step(env)
    env.tick(true)
    env.publish_blocked("left", 5, 2)
    settle_completed_step(env)
    env.tick(true)
    env.publish_blocked("right", 5, 2)

    -- Backtrack: (5,2) frame exhausted, crawler injects "down" toward (5,3).
    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[#env.injects], "down", "backtrack from depth 3 to depth 2 injects down")
    env.publish_step("down", 5, 2, 5, 3)

    -- (5,3) resumes with next_dir=2 (down). (5,4) is already visited.
    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[#env.injects], "down", "(5,3) next probe revisits (5,4)")
    env.publish_step("down", 5, 3, 5, 4)
    settle_completed_step(env)
    env.tick(true)
    env.publish_step("up", 5, 4, 5, 3)
    settle_completed_step(env)
    env.tick(true)
    env.publish_blocked("left", 5, 3)
    settle_completed_step(env)
    env.tick(true)
    env.publish_blocked("right", 5, 3)

    -- Backtrack from depth 2 to depth 1.
    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[#env.injects], "down", "backtrack from depth 2 to depth 1 injects down")
    env.publish_step("down", 5, 3, 5, 4)

    local joined = table.concat(env.logs, "\n")
    assert_equal(count_occurrences(joined, "kind=backtrack"), 2,
        "two backtrack edges should fire as the DFS pops back through depths 3 and 2")
    assert_equal(env.crawler.is_active(), true,
        "crawler should still be active while root frame (5,5) has unexplored directions")

    env.restore()
end

function tests.max_edges_limit_finishes_with_max_edges_reason()
    local env = make_env()
    assert_equal(env.crawler.start("attempts=1,max_edges=2"), true, "crawler should start")

    env.tick(true)
    env.publish_blocked("up", 5, 5)

    settle_completed_step(env)
    env.tick(true)
    env.publish_blocked("down", 5, 5)

    -- Third tick should hit the max_edges cap before injecting again.
    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.crawler.is_active(), false, "crawler should finish at the max_edges cap")
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "reason=max_edges",
        "max_edges exhaustion should finish with reason=max_edges")
    assert_contains(joined, "completed=false",
        "max_edges exhaustion is not a clean completion")

    env.restore()
end

function tests.max_edges_limit_stops_before_pending_return_edge()
    local env = make_env({x = 5, y = 1, height = 2})
    assert_equal(env.crawler.start("attempts=1,max_edges=3"), true, "crawler should start")

    env.tick(true)
    assert_equal(env.injects[#env.injects], "up", "first probe should enter the top row")
    env.publish_step("up", 5, 1, 5, 0)

    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[#env.injects], "down",
        "crawler should skip top boundary and probe the visited parent")
    env.publish_step("down", 5, 0, 5, 1)

    local inject_count_at_cap = #env.injects
    settle_completed_step(env)
    env.tick(true)

    assert_equal(env.crawler.is_active(), false,
        "crawler should finish at max_edges before starting a pending return edge")
    assert_equal(#env.injects, inject_count_at_cap,
        "max_edges should not allow an extra return_to_frontier injection")
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "reason=max_edges edges=3",
        "finish should report the requested edge cap, not an overrun")

    env.restore()
end

function tests.pending_repress_into_open_floor_stays_open_floor()
    -- The existing pending_repress test exercises a model-walkable=false
    -- destination (timing_suspect_false_wall). Guard the other branch too:
    -- when the model says the destination IS walkable, a pending_repress
    -- source must NOT escalate the classification to timing_suspect.
    local env = make_env()

    assert_equal(env.crawler.start("attempts=1,max_edges=1"), true, "crawler should start")
    env.tick(true)
    env.publish_step("up", 5, 5, 5, 4, nil, {
        source = "pending_repress",
        timeout_retries = 1,
        turn_represses = 1,
        frames = 40,
        inject_limit = 12,
    })

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=open_floor",
        "pending_repress into a model-walkable destination should classify as open_floor")
    assert_not_contains(joined, "class=timing_suspect_false_wall",
        "open destinations should never escalate to timing_suspect")
    assert_not_contains(joined, "MAP_CRAWL_UNSTABLE_CANDIDATE",
        "open destinations from pending_repress should not be marked unstable")

    env.restore()
end

function tests.open_door_pushes_dfs_frame_for_further_exploration()
    local env = make_env({
        doors = {
            ["5,4"] = {open = true, door_x = 5, door_y = 4, open_slots = {"0:5,4"}},
        },
    })

    assert_equal(env.crawler.start("attempts=1,max_edges=5"), true, "crawler should start")

    env.tick(true)
    assert_equal(env.injects[1], "up", "first probe walks into the open door")
    env.publish_step("up", 5, 5, 5, 4)

    -- DFS should push (5,4) onto the stack and continue probing from there.
    settle_completed_step(env)
    env.tick(true)
    assert_equal(env.injects[2], "up", "DFS continues probing past the open door")
    env.publish_blocked("up", 5, 4)

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=open_door_passage",
        "walking through an open door should be classified as open_door_passage")
    assert_contains(joined, "door=(5,4) open=true",
        "door context should accompany the open-door log line")
    assert_contains(joined,
        "MAP_CRAWL_PROBE run=1 map=0x0B from=(5,4) dir=up dest=(5,3) attempt=1/1 kind=probe",
        "next probe should originate from inside the door cell")

    env.restore()
end

function tests.crawler_waits_for_step_settle_after_completed_probe()
    local env = make_env()

    assert_equal(env.crawler.start("attempts=1,max_edges=5"), true, "crawler should start")

    env.tick(true)
    assert_equal(env.injects[1], "up", "first probe should start north")
    env.publish_step("up", 5, 5, 5, 4)

    for _ = 1, STEP_SETTLE_TEST_FRAMES do
        env.tick(true)
        assert_equal(#env.injects, 1,
            "crawler should not start the next probe while the completed step settles")
    end

    env.tick(true)
    assert_equal(env.injects[2], "up",
        "crawler should continue once the completed step is settled")

    env.restore()
end

function tests.crawler_uses_map_crawl_auto_step_profile()
    local env = make_env()

    assert_equal(env.crawler.start("attempts=1,max_edges=5"), true, "crawler should start")

    env.tick(true)
    assert_equal(env.injects[1], "up", "first probe should start north")
    assert_equal(env.inject_options[1].source, "map_crawl",
        "crawler-owned probes should use the map_crawl auto-step source")
    assert_equal(env.inject_options[1].release_after_inject_limit, true,
        "crawler-owned probes should release after their inject window")

    env.restore()
end

function tests.crawler_does_not_reset_movement_state_after_completed_probe()
    local env = make_env()

    assert_equal(env.crawler.start("attempts=1,max_edges=5"), true, "crawler should start")

    env.tick(true)
    env.publish_step("up", 5, 5, 5, 4)

    assert_equal(#env.movement_resets, 0,
        "completed crawler probes should not write movement RAM during hostile-area encounter windows")

    env.restore()
end

function tests.crawler_force_releases_during_completed_step_settle()
    local env = make_env()

    assert_equal(env.crawler.start("attempts=1,max_edges=5"), true, "crawler should start")

    env.tick(true)
    env.publish_step("up", 5, 5, 5, 4)
    local cancellations_after_event = #env.cancellations
    local resets_after_event = #env.movement_resets

    env.tick(true)
    assert_equal(#env.injects, 1,
        "crawler should not start the next edge during completed-step stabilization")
    assert_equal(#env.cancellations, cancellations_after_event + 1,
        "crawler should keep force-releasing input while a completed step settles")
    assert_equal(#env.movement_resets, resets_after_event,
        "crawler should not write movement RAM while a completed step settles")

    env.restore()
end

function tests.crawler_force_releases_after_completed_probe()
    local env = make_env()

    assert_equal(env.crawler.start("attempts=1,max_edges=5"), true, "crawler should start")

    env.tick(true)
    env.publish_step("up", 5, 5, 5, 4)

    assert_equal(#env.cancellations, 1,
        "completed crawler probes should cancel any held auto_step input")
    assert_equal(env.cancellations[1].clear_queued_route, true,
        "completed crawler probes should clear stale queued route state")
    assert_equal(env.cancellations[1].force_release, true,
        "completed crawler probes should force input release before settling")

    env.restore()
end

function tests.crawler_force_releases_before_blocked_retry()
    local env = make_env()

    assert_equal(env.crawler.start("attempts=2,max_edges=5"), true, "crawler should start")

    env.tick(true)
    env.publish_blocked("up", 5, 5)

    assert_equal(#env.cancellations, 1,
        "blocked crawler probes should cancel any held auto_step input before retrying")
    assert_equal(env.cancellations[1].clear_queued_route, true,
        "blocked crawler probes should clear stale queued route state")
    assert_equal(env.cancellations[1].force_release, true,
        "blocked crawler probes should force input release before retrying")

    env.restore()
end

function tests.crawler_waits_for_step_settle_after_blocked_probe()
    local env = make_env()

    assert_equal(env.crawler.start("attempts=2,max_edges=5"), true, "crawler should start")

    env.tick(true)
    assert_equal(env.injects[1], "up", "first probe should start north")
    env.publish_blocked("up", 5, 5)

    for _ = 1, STEP_SETTLE_TEST_FRAMES do
        env.tick(true)
        assert_equal(#env.injects, 1,
            "crawler should not retry a blocked edge while the forced release settles")
    end

    env.tick(true)
    assert_equal(env.injects[2], "up",
        "crawler should retry the same blocked edge once the release is settled")
    env.publish_blocked("up", 5, 5)

    for _ = 1, STEP_SETTLE_TEST_FRAMES do
        env.tick(true)
        assert_equal(#env.injects, 2,
            "crawler should not start the next edge while the final blocked attempt settles")
    end

    env.tick(true)
    assert_equal(env.injects[3], "down",
        "crawler should continue with the next direction once the blocked edge is settled")

    env.restore()
end

function tests.complete_finish_writes_export_file_with_lua_snippets()
    local env = make_env({
        details = {
            ["5,4"] = {effective_walkable = false, permanent_blocked = false, reason = "tile_type", tile_type = 0},
        },
    })

    assert_equal(env.crawler.start("attempts=1,max_edges=20"), true, "crawler should start")

    -- Walk into a false-wall cell (passthrough candidate at (5,4)).
    env.tick(true); env.publish_step("up", 5, 5, 5, 4)
    settle_completed_step(env)

    -- Block up from (5,4) -> directional candidate at (5,3).
    env.tick(true); env.publish_blocked("up", 5, 4)
    settle_completed_step(env)

    -- Down from (5,4) is a pending_return to the visited (5,5), then back up.
    env.tick(true); env.publish_step("down", 5, 4, 5, 5)
    settle_completed_step(env)
    env.tick(true); env.publish_step("up", 5, 5, 5, 4)
    settle_completed_step(env)

    -- Block remaining cardinal directions at (5,4).
    env.tick(true); env.publish_blocked("left", 5, 4)
    settle_completed_step(env)
    env.tick(true); env.publish_blocked("right", 5, 4)
    settle_completed_step(env)

    -- Backtrack to (5,5), then exhaust the root frame.
    env.tick(true); env.publish_step("down", 5, 4, 5, 5)
    settle_completed_step(env)
    env.tick(true); env.publish_blocked("down", 5, 5)
    settle_completed_step(env)
    env.tick(true); env.publish_blocked("left", 5, 5)
    settle_completed_step(env)
    env.tick(true); env.publish_blocked("right", 5, 5)
    settle_completed_step(env)
    env.tick(true)

    assert_equal(env.crawler.is_active(), false, "DFS should finish cleanly")

    local paths = env.list_captured_paths()
    assert_equal(#paths, 1, "exactly one export file should be written")
    assert_contains(paths[1], "dw_crawl_0b.txt",
        "export filename should include the lowercase hex map id")

    local content = env.get_captured_file(paths[1])
    assert_contains(content, "-- Map crawler export", "header line present")
    assert_contains(content, "-- map: 0x0B", "header includes map id")
    assert_contains(content, "-- completed: true", "header reports completion")
    assert_contains(content, "-- reason: complete", "header reports reason")
    assert_contains(content, "-- MAP_PASSTHROUGH_CELLS additions",
        "passthrough section header present")
    assert_contains(content, '["5,4"] = true,', "false-wall cell exported as passthrough")
    assert_contains(content, "-- MAP_DIRECTIONAL_BLOCKS additions",
        "directional section header present")
    assert_contains(content, '["5,3"] = {south = true},',
        "blocked direction exported as directional candidate")

    local joined_logs = table.concat(env.logs, "\n")
    assert_contains(joined_logs, "MAP_CRAWL_EXPORT_FILE",
        "export path should be logged for grepping")

    -- Speech announcement: exactly one "complete" line after the start banner.
    local last_output = env.outputs[#env.outputs]
    assert_contains(last_output, "Map crawl complete",
        "finish speech should announce completion")
    assert_contains(last_output, "1 passthrough",
        "finish speech should include passthrough count")
    -- 6 directional candidates were recorded: (5,3) south, (4,4) east,
    -- (6,4) west from probes at (5,4); plus (5,6) north, (4,5) east,
    -- (6,5) west from probes at the root (5,5).
    assert_contains(last_output, "6 directional",
        "finish speech should include directional count")

    env.restore()
end

function tests.aborted_finish_still_writes_export_file_with_failure_reason()
    local env = make_env()

    assert_equal(env.crawler.start("attempts=1,max_edges=2"), true, "crawler should start")
    env.tick(true); env.publish_blocked("up", 5, 5)
    settle_completed_step(env)
    env.tick(true); env.publish_blocked("down", 5, 5)
    settle_completed_step(env)
    env.tick(true)  -- hits max_edges

    assert_equal(env.crawler.is_active(), false, "max_edges abort finishes the run")

    local paths = env.list_captured_paths()
    assert_equal(#paths, 1, "abort still writes the export file")

    local content = env.get_captured_file(paths[1])
    assert_contains(content, "-- completed: false", "abort flagged in header")
    assert_contains(content, "-- reason: max_edges", "abort reason in header")
    assert_contains(content, '["5,4"] = {south = true},',
        "directional candidate from before the abort survives the export")

    local last_output = env.outputs[#env.outputs]
    assert_contains(last_output, "Map crawl ended: max_edges",
        "finish speech should announce the abort reason")

    env.restore()
end

function tests.manual_immediate_stop_speaks_finish_summary_only_once()
    local env = make_env()

    assert_equal(env.crawler.start("max_edges=1"), true, "crawler should start")
    local outputs_before = #env.outputs

    -- Stop before any probe injects so the stop path takes the immediate
    -- finish_run branch (no active_edge to settle around).
    local ok, msg = env.crawler.stop()
    assert_equal(ok, true, "stop should succeed")
    assert_equal(msg, nil,
        "immediate stop should return nil msg so the command does not double-speak")

    assert_equal(#env.outputs - outputs_before, 1,
        "immediate stop should emit exactly one tolk announcement")
    local finish_text = env.outputs[#env.outputs]
    assert_contains(finish_text, "Map crawl stopped",
        "finish speech should use 'stopped' phrasing for manual stop")

    env.restore()
end

function tests.auto_step_silently_cleared_aborts_without_hanging()
    local env = make_env()

    assert_equal(env.crawler.start("max_edges=1"), true, "crawler should start")
    env.tick(true)
    assert_equal(env.injects[1], "up", "first probe should start")

    -- Simulate auto_step silently dropping the in-flight step (can_walk fell,
    -- a different live direction interrupted, config toggled, ...). No
    -- route_step_completed or route_blocked event will arrive.
    env.clear_auto_step_state()

    env.tick(true)
    assert_equal(env.crawler.is_active(), false, "orphaned step should abort the crawler")

    env.crawler.export_candidates(0x0B)
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=auto_step_lost",
        "orphan abort should be classified diagnostically")
    assert_contains(joined, "reason=auto_step_lost",
        "finish_run should record the auto_step_lost reason")
    assert_contains(joined, "note=active_step_cleared_without_event",
        "orphan log should explain the silent clear")
    assert_contains(joined, "no_review_candidates=true",
        "orphan abort should not promote any review candidates")

    env.restore()
end

function tests.battle_interrupt_during_walk_sweep_exports_explicit_unsafe_abort()
    local env = make_env()

    assert_equal(env.crawler.start_walk_sweep("attempts=1,max_edges=10,park_mobile_npcs=false"),
        true, "walk sweep should start")
    env.tick(true)
    assert_equal(env.injects[1], "up", "first probe should start")

    env.clear_auto_step_state()
    env.tick(false, {state = "battle"})

    assert_equal(env.crawler.is_active(), false,
        "battle interruption should stop the sweep instead of hanging")

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "class=battle_interrupted",
        "battle abort should preserve the combat cause")
    assert_contains(joined, "reason=battle_interrupted",
        "finish_run should record the battle interruption reason")
    assert_contains(joined, "note=battle_started_during_probe",
        "battle abort log should explain the interrupted probe")

    local json_path = find_captured_path(env, "sweep_walk_0b_run001.json")
    local summary_path = find_captured_path(env, "sweep_walk_0b_run001_summary.txt")
    local status_path = find_captured_path(env, "sweep_status.txt")
    local json = env.get_captured_file(json_path)
    local summary = env.get_captured_file(summary_path)
    local status = env.get_captured_file(status_path)

    assert_contains(json, '"status": "unsafe_abort"',
        "battle interruption should export in the unsafe-abort bucket")
    assert_contains(json, '"source_classification": "battle_interrupted"',
        "JSON should preserve the battle interruption source class")
    assert_contains(summary, "Reason: battle_interrupted",
        "summary should expose the hostile-area graceful exit reason")
    assert_contains(status, "last_event=finished:battle_interrupted",
        "heartbeat should expose the hostile-area graceful exit reason")

    env.restore()
end

function tests.walk_sweep_start_uses_normal_movement_metadata_without_teleport_writes()
    local env = make_env()

    local ok, err = env.crawler.start_walk_sweep("max_edges=1,park_mobile_npcs=false")
    assert_equal(ok, true, "walk sweep should start through the map crawler")
    assert_equal(err, nil, "walk sweep start should not return an error")
    assert_equal(env.crawler.is_active(), true, "walk sweep should leave the crawler active")

    local joined = table.concat(env.logs, "\n")
    assert_contains(joined,
        "SWEEP_WALK_START run=1 map=0x0B method=normal_movement teleport_used=false",
        "walk sweep should log normal-movement metadata")

    for _, call in ipairs(env.write_calls) do
        if call.address == 0x003A or call.address == 0x003B then
            error("walk sweep must not teleport by writing PLAYER_X or PLAYER_Y", 2)
        end
    end

    env.restore()
end

function tests.walk_sweep_writes_json_summary_and_heartbeat_outputs()
    local env = make_env()

    local ok, err = env.crawler.start_walk_sweep("attempts=1,max_edges=1,park_mobile_npcs=false")
    assert_equal(ok, true, "walk sweep should start")
    assert_equal(err, nil, "walk sweep start should not fail")

    local status_path = find_captured_path(env, "sweep_status.txt")
    assert_contains(status_path or "", "sweep_status.txt",
        "walk sweep should write an initial heartbeat status file")
    local start_status = env.get_captured_file(status_path)
    assert_contains(start_status, "active=true", "initial heartbeat should mark sweep active")
    assert_contains(start_status, "method=normal_movement", "heartbeat should record movement method")
    assert_contains(start_status, "teleport_used=false", "heartbeat should record teleport safety")
    assert_contains(start_status, "phase=starting", "initial heartbeat should expose the phase")
    assert_contains(start_status, "cell=5,5", "initial heartbeat should record start/current cell")

    env.tick(true)
    env.publish_blocked("up", 5, 5)
    settle_completed_step(env)
    env.tick(true)

    assert_equal(env.crawler.is_active(), false, "max_edges should finish the one-edge walk sweep")

    local json_path = find_captured_path(env, "sweep_walk_0b_run001.json")
    local summary_path = find_captured_path(env, "sweep_walk_0b_run001_summary.txt")
    status_path = find_captured_path(env, "sweep_status.txt")
    assert_contains(json_path or "", "sweep_walk_0b_run001.json",
        "walk sweep should write machine-readable JSON output")
    assert_contains(summary_path or "", "sweep_walk_0b_run001_summary.txt",
        "walk sweep should write a human-readable summary output")

    local json = env.get_captured_file(json_path)
    assert_contains(json, '"method": "normal_movement"', "JSON should record movement method")
    assert_contains(json, '"teleport_used": false', "JSON should record teleport safety")
    assert_contains(json, '"command": "sweep_walk"', "JSON should identify the walk sweep command")
    assert_contains(json, '"start": {"x": 5, "y": 5}', "JSON should record start cell")
    assert_contains(json, '"cells_visited": 1', "JSON stats should count reached cells")
    assert_contains(json, '"edges_tested": 1', "JSON stats should count tested edges")
    assert_contains(json, '"status": "blocked"', "blocked movement should be represented in JSON")
    assert_contains(json, '"confidence": "candidate"', "single blocked attempt should stay review-only")
    assert_contains(json, '"source_classification": "directional_block_candidate"',
        "JSON should preserve the crawler's source classification")

    local summary = env.get_captured_file(summary_path)
    assert_contains(summary, "SWEEP_WALK ended.", "summary should name the sweep result")
    assert_contains(summary, "Map: 0B", "summary should include map id")
    assert_contains(summary, "Method: normal movement", "summary should be human-readable")
    assert_contains(summary, "Teleport used: no", "summary should state teleport safety")
    assert_contains(summary, "Reason: max_edges", "summary should include finish reason")
    assert_contains(summary, "Visited cells: 1", "summary should include visited count")
    assert_contains(summary, "Tested edges: 1", "summary should include edge count")
    assert_contains(summary, "Blocked review edges: 1", "summary should keep blockers review-only")
    assert_contains(summary, "Do not blindly patch unknown/dynamic edges.",
        "summary should include conservative confidence guidance")

    local final_status = env.get_captured_file(status_path)
    assert_contains(final_status, "active=false", "final heartbeat should mark sweep inactive")
    assert_contains(final_status, "phase=finished", "final heartbeat should mark finished phase")
    assert_contains(final_status, "last_event=finished:max_edges",
        "final heartbeat should include the final event")
    assert_contains(final_status, "visited=1", "final heartbeat should include visited count")
    assert_contains(final_status, "edges=1", "final heartbeat should include edge count")
    assert_contains(final_status, "blocked=1", "final heartbeat should include blocked count")

    env.restore()
end

function tests.walk_sweep_json_groups_single_edge_results_by_conservative_taxonomy()
    local unknown_env = make_env()
    assert_equal(unknown_env.crawler.start_walk_sweep("attempts=2,max_edges=1,park_mobile_npcs=false"),
        true, "mixed probe sweep should start")
    unknown_env.tick(true)
    unknown_env.publish_blocked("up", 5, 5)
    settle_completed_step(unknown_env)
    unknown_env.tick(true)
    unknown_env.publish_step("up", 5, 5, 5, 4)
    settle_completed_step(unknown_env)
    unknown_env.tick(true)
    local unknown_json_path = find_captured_path(unknown_env, "sweep_walk_0b_run001.json")
    local unknown_json = unknown_env.get_captured_file(unknown_json_path)
    assert_contains(unknown_json, '"unknowns": [',
        "ambiguous single-edge results should have an explicit unknowns bucket")
    assert_contains(unknown_json, '"status": "unknown"',
        "mixed blocked-then-moved result should export as unknown")
    assert_contains(unknown_json, '"source_classification": "mixed_probe"',
        "unknown bucket should preserve the crawler source class")
    unknown_env.restore()

    local dynamic_env = make_env({
        npc_bytes = {
            [0x0051] = 5, [0x0052] = 4, [0x0053] = 0,
        },
    })
    assert_equal(dynamic_env.crawler.start_walk_sweep("attempts=1,max_edges=1,park_mobile_npcs=false"),
        true, "dynamic-blocked sweep should start")
    dynamic_env.tick(true)
    local dynamic_json_path = find_captured_path(dynamic_env, "sweep_walk_0b_run001.json")
    local dynamic_json = dynamic_env.get_captured_file(dynamic_json_path)
    assert_contains(dynamic_json, '"dynamic_blockers": [',
        "NPC/object results should have an explicit dynamic blockers bucket")
    assert_contains(dynamic_json, '"status": "dynamic_blocked"',
        "stationary NPC skip should export as dynamic_blocked")
    assert_contains(dynamic_json, '"source_classification": "stationary_npc_blocked"',
        "dynamic bucket should preserve the crawler source class")
    dynamic_env.restore()

    local transition_env = make_env()
    assert_equal(transition_env.crawler.start_walk_sweep("attempts=1,max_edges=10,park_mobile_npcs=false"),
        true, "transition sweep should start")
    transition_env.tick(true)
    transition_env.publish_step("up", 5, 5, 102, 72, 0x01)
    local transition_json_path = find_captured_path(transition_env, "sweep_walk_0b_run001.json")
    local transition_json = transition_env.get_captured_file(transition_json_path)
    assert_contains(transition_json, '"transitions": [',
        "map-changing edges should have an explicit transitions bucket")
    assert_contains(transition_json, '"status": "transition"',
        "map-changing edge should export as transition")
    assert_contains(transition_json, '"source_classification": "transition_candidate"',
        "transition bucket should preserve the crawler source class")
    transition_env.restore()

    local boundary_env = make_env({
        y = 1,
        details = {
            ["5,0"] = {effective_walkable = false, permanent_blocked = false, reason = "engine_boundary", tile_type = 2},
        },
    })
    assert_equal(boundary_env.crawler.start_walk_sweep("attempts=1,max_edges=1,park_mobile_npcs=false"),
        true, "boundary-frontier sweep should start")
    boundary_env.tick(true)
    local boundary_json_path = find_captured_path(boundary_env, "sweep_walk_0b_run001.json")
    local boundary_summary_path = find_captured_path(boundary_env, "sweep_walk_0b_run001_summary.txt")
    local boundary_json = boundary_env.get_captured_file(boundary_json_path)
    local boundary_summary = boundary_env.get_captured_file(boundary_summary_path)
    assert_contains(boundary_json, '"source_classification": "boundary_frontier"',
        "boundary frontier should remain visible in JSON for review")
    assert_contains(boundary_json, '"status": "unknown"',
        "boundary frontier should export as unknown, not as an observed transition")
    assert_contains(boundary_json, '"transitions": [\n  ],',
        "boundary frontier should stay out of the transitions bucket")
    assert_contains(boundary_json, '"unknown_edges": 1',
        "boundary frontier should count as an unknown review edge")
    assert_contains(boundary_summary, "Unknown edges: 1",
        "summary should count boundary frontier as an unknown edge")
    assert_contains(boundary_summary, "Map transitions found: 0",
        "summary should not call a boundary frontier a map transition")
    boundary_env.restore()

    local unsafe_env = make_env()
    assert_equal(unsafe_env.crawler.start_walk_sweep("attempts=1,max_edges=10,park_mobile_npcs=false"),
        true, "unsafe-abort sweep should start")
    unsafe_env.tick(true)
    unsafe_env.publish_step("up", 5, 5, 5, 6)
    local unsafe_json_path = find_captured_path(unsafe_env, "sweep_walk_0b_run001.json")
    local unsafe_json = unsafe_env.get_captured_file(unsafe_json_path)
    assert_contains(unsafe_json, '"unsafe_aborts": [',
        "drift aborts should have an explicit unsafe abort bucket")
    assert_contains(unsafe_json, '"status": "unsafe_abort"',
        "unexpected landing should export as unsafe_abort")
    assert_contains(unsafe_json, '"source_classification": "movement_drift"',
        "unsafe bucket should preserve the crawler source class")
    unsafe_env.restore()
end

local names = {}
for name in pairs(tests) do
    names[#names + 1] = name
end
table.sort(names)

local passed = 0
for _, name in ipairs(names) do
    tests[name]()
    passed = passed + 1
    print("PASS " .. name)
end

print(string.format("test_map_crawler.lua: %d tests passed", passed))
