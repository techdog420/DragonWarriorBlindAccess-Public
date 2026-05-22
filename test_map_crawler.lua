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
    local cancellations = {}
    local record_block_calls = 0
    local active_step_state = nil
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
            inject_step = function(dir)
                injects[#injects + 1] = dir
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
        cancellations = cancellations,
        record_block_calls = function() return record_block_calls end,
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
        tick = function(can_walk)
            crawler.tick(can_walk ~= false)
        end,
        publish_blocked = function(dir, from_x, from_y)
            route_active = false
            active_step_state = nil
            bus.publish("route_blocked", {
                from_x = from_x or nav_x,
                from_y = from_y or nav_y,
                dir = dir,
                source = "inject_step",
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

    env.tick(true)
    assert_equal(env.injects[2], "down", "known parent edge should be probed from child")
    env.publish_step("down", 5, 4, 5, 5)

    env.tick(true)
    assert_equal(env.injects[3], "up", "crawler should return to the child frontier")
    env.publish_step("up", 5, 5, 5, 4)

    env.tick(true)
    local joined = table.concat(env.logs, "\n")
    assert_equal(count_occurrences(joined, "kind=return_to_frontier"), 1,
        "completed frontier return should not schedule a ping-pong return")
    assert_contains(joined, "kind=backtrack", "crawler should resume DFS backtracking after frontier return")

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
    env.tick(true)
    env.publish_step("down", 5, 4, 5, 5)
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
    env.tick(true)
    assert_equal(env.injects[2], "up", "next probe from (5,4) goes up")
    env.publish_blocked("up", 5, 4)

    env.tick(true)
    assert_equal(env.injects[3], "down", "next probe from (5,4) revisits the parent")
    env.publish_step("down", 5, 4, 5, 5)

    -- pending_return walks the player back to the frontier cell.
    env.tick(true)
    assert_equal(env.injects[4], "up", "pending_return restores the frontier position")
    env.publish_step("up", 5, 5, 5, 4)

    env.tick(true)
    assert_equal(env.injects[5], "left", "next probe from (5,4) goes left")
    env.publish_blocked("left", 5, 4)

    env.tick(true)
    assert_equal(env.injects[6], "right", "next probe from (5,4) goes right")
    env.publish_blocked("right", 5, 4)

    -- All four directions exhausted at (5,4). Crawler issues a backtrack down
    -- to the parent (5,5). Make that backtrack itself fail.
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
    env.tick(true)
    assert_equal(env.injects[#env.injects], "up", "depth 2 probe goes up")
    env.publish_step("up", 5, 4, 5, 3)
    env.tick(true)
    assert_equal(env.injects[#env.injects], "up", "depth 3 probe goes up")
    env.publish_step("up", 5, 3, 5, 2)

    -- Exhaust (5,2): north blocks, south revisits (5,3) via pending_return,
    -- west and east block.
    env.tick(true)
    env.publish_blocked("up", 5, 2)
    env.tick(true)
    assert_equal(env.injects[#env.injects], "down", "(5,2) tries down toward already-visited (5,3)")
    env.publish_step("down", 5, 2, 5, 3)
    env.tick(true)
    assert_equal(env.injects[#env.injects], "up", "pending_return takes player back to the frontier")
    env.publish_step("up", 5, 3, 5, 2)
    env.tick(true)
    env.publish_blocked("left", 5, 2)
    env.tick(true)
    env.publish_blocked("right", 5, 2)

    -- Backtrack: (5,2) frame exhausted, crawler injects "down" toward (5,3).
    env.tick(true)
    assert_equal(env.injects[#env.injects], "down", "backtrack from depth 3 to depth 2 injects down")
    env.publish_step("down", 5, 2, 5, 3)

    -- (5,3) resumes with next_dir=2 (down). (5,4) is already visited.
    env.tick(true)
    assert_equal(env.injects[#env.injects], "down", "(5,3) next probe revisits (5,4)")
    env.publish_step("down", 5, 3, 5, 4)
    env.tick(true)
    env.publish_step("up", 5, 4, 5, 3)
    env.tick(true)
    env.publish_blocked("left", 5, 3)
    env.tick(true)
    env.publish_blocked("right", 5, 3)

    -- Backtrack from depth 2 to depth 1.
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

    env.tick(true)
    env.publish_blocked("down", 5, 5)

    -- Third tick should hit the max_edges cap before injecting again.
    env.tick(true)
    assert_equal(env.crawler.is_active(), false, "crawler should finish at the max_edges cap")
    local joined = table.concat(env.logs, "\n")
    assert_contains(joined, "reason=max_edges",
        "max_edges exhaustion should finish with reason=max_edges")
    assert_contains(joined, "completed=false",
        "max_edges exhaustion is not a clean completion")

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

function tests.complete_finish_writes_export_file_with_lua_snippets()
    local env = make_env({
        details = {
            ["5,4"] = {effective_walkable = false, permanent_blocked = false, reason = "tile_type", tile_type = 0},
        },
    })

    assert_equal(env.crawler.start("attempts=1,max_edges=20"), true, "crawler should start")

    -- Walk into a false-wall cell (passthrough candidate at (5,4)).
    env.tick(true); env.publish_step("up", 5, 5, 5, 4)

    -- Block up from (5,4) -> directional candidate at (5,3).
    env.tick(true); env.publish_blocked("up", 5, 4)

    -- Down from (5,4) is a pending_return to the visited (5,5), then back up.
    env.tick(true); env.publish_step("down", 5, 4, 5, 5)
    env.tick(true); env.publish_step("up", 5, 5, 5, 4)

    -- Block remaining cardinal directions at (5,4).
    env.tick(true); env.publish_blocked("left", 5, 4)
    env.tick(true); env.publish_blocked("right", 5, 4)

    -- Backtrack to (5,5), then exhaust the root frame.
    env.tick(true); env.publish_step("down", 5, 4, 5, 5)
    env.tick(true); env.publish_blocked("down", 5, 5)
    env.tick(true); env.publish_blocked("left", 5, 5)
    env.tick(true); env.publish_blocked("right", 5, 5)
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
    env.tick(true); env.publish_blocked("down", 5, 5)
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
