-- overworld_routes.lua
-- Lightweight manual route guidance for the large Dragon Warrior world map.

local M = {}

local WORLD_MAP_ID = 0x01
local MAX_VISIBLE_ACTIVE_WAYPOINTS = 2

local ROUTES = {
    brecconary = {
        id = "brecconary",
        title = "Brecconary",
        aliases = {"brecconary", "breconary", "town", "first town", "safety", "safe"},
        target_object_ids = {"overworld_brecconary"},
        destination_maps = {0x08},
        waypoints = {
            {x = 2, y = 2, name = "Garinham road", radius = 1},
            {x = 5, y = 4, name = "Garinham outskirts", radius = 1},
            {x = 8, y = 3, name = "Garinham north coast west lane", radius = 1},
            {x = 14, y = 3, name = "Garinham north coast lane", radius = 0},
            {x = 14, y = 4, name = "Garinham mountain shoulder", radius = 0},
            {x = 15, y = 4, name = "Garinham shoulder east step", radius = 0},
            {x = 16, y = 5, name = "Garinham shoulder bend", radius = 0},
            {x = 16, y = 6, name = "Garinham east ridge", radius = 0},
            {x = 19, y = 6, name = "Garinham ridge entry", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 20, y = 7, name = "Garinham field east lane", radius = 0},
            {x = 20, y = 9, name = "Garinham east field", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 21, y = 10, name = "Garinham field road bend", radius = 0},
            {x = 21, y = 11, name = "Cave road north edge", radius = 0},
            {x = 23, y = 11, name = "Cave road west lane", radius = 0},
            {x = 23, y = 13, name = "Cave road south lane", radius = 1},
            {x = 28, y = 13, name = "Erdrick's Cave road", radius = 1},
            {x = 28, y = 20, name = "North trail marker", radius = 1},
            {x = 32, y = 19, name = "North ridge bend", radius = 1},
            {x = 35, y = 24, name = "Eastern mountain lane", radius = 0},
            {x = 35, y = 32, name = "East choke approach", radius = 0},
            {x = 38, y = 32, name = "Upper bridge lane", radius = 0},
            {x = 38, y = 34, name = "Bridge west bend", radius = 0},
            {
                x = 38,
                y = 36,
                name = "Bridge lower west lane",
                radius = 0,
            },
            {
                x = 44,
                y = 38,
                name = "Bridge south bend",
                radius = 1,
                warning = "Bridge crossing. Monsters should become safer beyond this point.",
            },
            {x = 48, y = 41, name = "Brecconary", radius = 0, final = true},
        },
    },
    garinham = {
        id = "garinham",
        title = "Garinham",
        aliases = {"garinham", "garinham town", "garin", "galen", "galenholm"},
        target_object_ids = {"overworld_garinham"},
        destination_maps = {0x09},
        waypoints = {
            {x = 43, y = 43, name = "Tantegel Castle road", radius = 1},
            {x = 48, y = 41, name = "Brecconary road", radius = 1},
            {
                x = 44,
                y = 38,
                name = "Bridge south bend",
                radius = 1,
                warning = "Bridge crossing. Monsters may become more dangerous beyond this point.",
            },
            {x = 38, y = 36, name = "Bridge lower west lane", radius = 0},
            {x = 38, y = 34, name = "Bridge west bend", radius = 0},
            {x = 38, y = 32, name = "Upper bridge lane", radius = 0},
            {x = 35, y = 32, name = "East choke approach", radius = 0},
            {x = 35, y = 24, name = "Eastern mountain lane", radius = 0},
            {x = 32, y = 19, name = "North ridge bend", radius = 1},
            {x = 28, y = 20, name = "North trail marker", radius = 1},
            {x = 28, y = 13, name = "Erdrick's Cave road", radius = 1},
            {x = 23, y = 13, name = "Cave road south lane", radius = 1},
            {x = 23, y = 11, name = "Cave road west lane", radius = 0},
            {x = 21, y = 11, name = "Cave road north edge", radius = 0},
            {x = 21, y = 10, name = "Garinham field road bend", radius = 0},
            {x = 20, y = 9, name = "Garinham east field", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 20, y = 7, name = "Garinham field east lane", radius = 0},
            {x = 19, y = 6, name = "Garinham ridge entry", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 16, y = 6, name = "Garinham east ridge", radius = 0},
            {x = 16, y = 5, name = "Garinham shoulder bend", radius = 0},
            {x = 15, y = 4, name = "Garinham shoulder east step", radius = 0},
            {x = 14, y = 4, name = "Garinham mountain shoulder", radius = 0},
            {x = 14, y = 3, name = "Garinham north coast lane", radius = 0},
            {x = 8, y = 3, name = "Garinham north coast west lane", radius = 1},
            {x = 5, y = 4, name = "Garinham outskirts", radius = 1},
            {x = 2, y = 2, name = "Garinham approach", radius = 0},
            {x = 1, y = 2, name = "Garinham", radius = 0, final = true},
        },
    },
    kol = {
        id = "kol",
        title = "Kol",
        aliases = {"kol", "kol town", "kol village", "fairy flute", "faerie flute", "faeries flute"},
        target_object_ids = {"overworld_kol"},
        destination_maps = {0x07},
        waypoints = {
            {x = 43, y = 43, name = "Tantegel Castle road", radius = 1},
            {x = 48, y = 41, name = "Brecconary road", radius = 1},
            {
                x = 44,
                y = 38,
                name = "Bridge south bend",
                radius = 1,
                warning = "Bridge crossing. Monsters may become more dangerous beyond this point.",
            },
            {x = 38, y = 36, name = "Bridge lower west lane", radius = 0},
            {x = 38, y = 34, name = "Bridge west bend", radius = 0},
            {x = 38, y = 32, name = "Upper bridge lane", radius = 0},
            {x = 35, y = 32, name = "East choke approach", radius = 0},
            {x = 35, y = 24, name = "Eastern mountain lane", radius = 0},
            {x = 32, y = 19, name = "North ridge bend", radius = 1},
            {x = 28, y = 20, name = "North trail marker", radius = 1},
            {x = 28, y = 13, name = "Erdrick's Cave road", radius = 1},
            {x = 35, y = 13, name = "North Alefgard west road", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 45, y = 13, name = "North Alefgard east road", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 54, y = 15, name = "Northeast bridge west approach", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 58, y = 18, name = "Northeast bridge west bend", radius = 0, axis_order = {"vertical", "horizontal"}},
            {x = 59, y = 19, name = "Northeast bridge lower west lane", radius = 0},
            {x = 61, y = 19, name = "Northeast bridge south lane", radius = 0},
            {
                x = 61,
                y = 18,
                name = "Northeast bridge",
                radius = 1,
                axis_order = {"horizontal", "vertical"},
                warning = "Northeast bridge crossing. Monsters may become more dangerous beyond this point.",
            },
            {x = 74, y = 18, name = "North Alefgard bridge road", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 84, y = 26, name = "Kol southwest track", radius = 1, axis_order = {"horizontal", "vertical"}},
            {
                x = 90,
                y = 37,
                name = "Kol southwest bridge",
                radius = 0,
                warning = "Kol southwest bridge crossing. Stronger Kol-area monsters may appear beyond this point.",
            },
            {x = 92, y = 37, name = "Kol bridge east lane", radius = 0},
            {x = 92, y = 36, name = "Kol lower south lane", radius = 0},
            {x = 93, y = 36, name = "Kol south road bend", radius = 0},
            {x = 93, y = 35, name = "Kol south road lower bend", radius = 0},
            {x = 96, y = 35, name = "Kol south road east lane", radius = 0},
            {x = 96, y = 32, name = "Kol south road", radius = 1},
            {x = 96, y = 21, name = "West of Kol north lane", radius = 1},
            {x = 96, y = 13, name = "Kol forest west edge", radius = 1},
            {x = 104, y = 10, name = "Kol", radius = 0, final = true},
        },
    },
    erdrick = {
        id = "erdrick",
        title = "Erdrick's Cave",
        aliases = {"erdrick", "erdricks cave", "erdrick cave", "erdric", "erdric cave", "cave"},
        target_object_ids = {"overworld_erdrick_s_cave"},
        destination_maps = {0x1C, 0x1D},
        waypoints = {
            {x = 43, y = 43, name = "Tantegel Castle road", radius = 1},
            {x = 48, y = 41, name = "Brecconary road", radius = 1},
            {
                x = 44,
                y = 38,
                name = "Bridge south bend",
                radius = 1,
                warning = "Bridge crossing. Monsters may become more dangerous beyond this point.",
            },
            {x = 38, y = 36, name = "Bridge lower west lane", radius = 0},
            {x = 38, y = 34, name = "Bridge west bend", radius = 0},
            {x = 38, y = 32, name = "Upper bridge lane", radius = 0},
            {x = 35, y = 32, name = "East choke approach", radius = 0},
            {x = 35, y = 24, name = "Eastern mountain lane", radius = 0},
            {x = 32, y = 19, name = "North ridge bend", radius = 1},
            {x = 28, y = 20, name = "North trail marker", radius = 1},
            {x = 28, y = 12, name = "Erdrick's Cave", radius = 0, final = true},
        },
    },
    tantegel = {
        id = "tantegel",
        title = "Tantegel Castle",
        aliases = {"tantegel", "tantegel castle", "castle"},
        target_object_ids = {"overworld_tantegel_castle"},
        destination_maps = {0x04, 0x05},
        waypoints = {
            {x = 2, y = 2, name = "Garinham road", radius = 1},
            {x = 5, y = 4, name = "Garinham outskirts", radius = 1},
            {x = 8, y = 3, name = "Garinham north coast west lane", radius = 1},
            {x = 14, y = 3, name = "Garinham north coast lane", radius = 0},
            {x = 14, y = 4, name = "Garinham mountain shoulder", radius = 0},
            {x = 15, y = 4, name = "Garinham shoulder east step", radius = 0},
            {x = 16, y = 5, name = "Garinham shoulder bend", radius = 0},
            {x = 16, y = 6, name = "Garinham east ridge", radius = 0},
            {x = 19, y = 6, name = "Garinham ridge entry", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 20, y = 7, name = "Garinham field east lane", radius = 0},
            {x = 20, y = 9, name = "Garinham east field", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 21, y = 10, name = "Garinham field road bend", radius = 0},
            {x = 21, y = 11, name = "Cave road north edge", radius = 0},
            {x = 23, y = 11, name = "Cave road west lane", radius = 0},
            {x = 23, y = 13, name = "Cave road south lane", radius = 1},
            {x = 28, y = 13, name = "Erdrick's Cave road", radius = 1},
            {x = 28, y = 20, name = "North trail marker", radius = 1},
            {x = 32, y = 19, name = "North ridge bend", radius = 1},
            {x = 35, y = 24, name = "Eastern mountain lane", radius = 0},
            {x = 35, y = 32, name = "East choke approach", radius = 0},
            {x = 38, y = 32, name = "Upper bridge lane", radius = 0},
            {x = 38, y = 34, name = "Bridge west bend", radius = 0},
            {
                x = 38,
                y = 36,
                name = "Bridge lower west lane",
                radius = 0,
            },
            {
                x = 44,
                y = 38,
                name = "Bridge south bend",
                radius = 1,
                warning = "Bridge crossing. Monsters should become safer beyond this point.",
            },
            {x = 43, y = 43, name = "Tantegel Castle", radius = 0, final = true},
        },
    },
}

local alias_to_id = {}
for id, route in pairs(ROUTES) do
    alias_to_id[id] = id
    for _, alias in ipairs(route.aliases or {}) do
        alias_to_id[alias] = id
    end
    local destination_map_lookup = {}
    for _, map_id in ipairs(route.destination_maps or {}) do
        destination_map_lookup[tonumber(map_id)] = true
    end
    route.destination_map_lookup = destination_map_lookup
end

local state = rawget(_G, "DW_OVERWORLD_ROUTE_STATE")
if type(state) ~= "table" then
    state = {
        active_id = nil,
        next_index = nil,
        warned = {},
        last_position_key = nil,
    }
    _G.DW_OVERWORLD_ROUTE_STATE = state
end
if type(state.warned) ~= "table" then
    state.warned = {}
end

local function normalize_route_id(value)
    value = tostring(value or "erdrick"):lower()
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    value = value:gsub("['`]", "")
    if value == "" then
        value = "erdrick"
    end
    return alias_to_id[value]
end

local function normalize_label(value)
    value = tostring(value or ""):lower()
    value = value:gsub("['`]", "")
    value = value:gsub("[^%w]+", " ")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value
end

local function direction_string(px, py, tx, ty)
    if px == tx and py == ty then
        return "here"
    end

    local parts = {}
    if ty < py then
        parts[#parts + 1] = (py - ty) .. " north"
    elseif ty > py then
        parts[#parts + 1] = (ty - py) .. " south"
    end
    if tx > px then
        parts[#parts + 1] = (tx - px) .. " east"
    elseif tx < px then
        parts[#parts + 1] = (px - tx) .. " west"
    end
    return table.concat(parts, ", ")
end

local function append_axis_steps(steps, axis, px, py, tx, ty)
    if axis == "vertical" then
        while py ~= ty do
            if ty < py then
                steps[#steps + 1] = "up"
                py = py - 1
            else
                steps[#steps + 1] = "down"
                py = py + 1
            end
        end
    elseif axis == "horizontal" then
        while px ~= tx do
            if tx < px then
                steps[#steps + 1] = "left"
                px = px - 1
            else
                steps[#steps + 1] = "right"
                px = px + 1
            end
        end
    end

    return px, py
end

local function waypoint_axis_order(route, point, opts)
    opts = opts or {}
    return point and point.axis_order or route and route.axis_order or opts.axis_order or {"vertical", "horizontal"}
end

local function distance(px, py, point)
    return math.abs((px or 0) - point.x) + math.abs((py or 0) - point.y)
end

local function is_overworld(map_id)
    return tonumber(map_id) == WORLD_MAP_ID
end

local function is_destination_map(route, map_id)
    return route and route.destination_map_lookup and route.destination_map_lookup[tonumber(map_id)] == true
end

local function active_route()
    return state.active_id and ROUTES[state.active_id] or nil
end

function M.active_route_id()
    return state.active_id
end

local function clamp_next_index(route)
    if not route then return nil end
    local count = #route.waypoints
    local index = tonumber(state.next_index) or 1
    if index < 1 then index = 1 end
    if index > count then index = count end
    state.next_index = index
    return index
end

local function choose_next_index(route, map_id, px, py)
    if not route or not is_overworld(map_id) or px == nil or py == nil then
        return 1
    end

    local nearest_index = 1
    local nearest_distance = nil
    for i, point in ipairs(route.waypoints) do
        local d = distance(px, py, point)
        if nearest_distance == nil or d < nearest_distance or (d == nearest_distance and i > nearest_index) then
            nearest_index = i
            nearest_distance = d
        end
    end

    local nearest = route.waypoints[nearest_index]
    if nearest_distance <= (nearest.radius or 0) and nearest_index < #route.waypoints then
        return nearest_index + 1
    end
    return nearest_index
end

local function waypoint_status(route, index, px, py)
    if not route or not index then
        return "No overworld route active"
    end
    local point = route.waypoints[index]
    if not point then
        return "Route to " .. route.title .. " complete"
    end

    if px == nil or py == nil then
        return "Route to " .. route.title .. ". Next: " .. point.name
    end

    return string.format(
        "Route to %s. Next: %s, %s",
        route.title,
        point.name,
        direction_string(px, py, point.x, point.y))
end

local function make_log(event, route, point, index)
    return string.format(
        "event=%s route=%s waypoint=%s index=%s",
        tostring(event),
        route and route.id or "-",
        point and point.name or "-",
        tostring(index or state.next_index))
end

local function route_object_id(route, index)
    if not route or not index then
        return nil
    end
    return string.format("route_%s_%02d", route.id, index)
end

local function route_final_waypoint(route)
    if not route or not route.waypoints then
        return nil
    end
    return route.waypoints[#route.waypoints]
end

local function clear_active_route()
    state.active_id = nil
    state.next_index = nil
    state.warned = {}
    state.last_position_key = nil
end

local function finish_route(route, point, event)
    local index = state.next_index
    clear_active_route()
    return {
        route = route,
        waypoint = point,
        message = "Arrived at " .. tostring(point and point.name or route and route.title or "destination"),
        log = make_log(event or "arrived", route, point, index),
        refresh = true,
    }
end

local function object_matches_route(route, obj)
    if not route or not obj then
        return false
    end
    if obj.route_id == route.id then
        return true
    end
    if obj.id then
        for _, object_id in ipairs(route.target_object_ids or {}) do
            if obj.id == object_id then
                return true
            end
        end
    end

    local final = route_final_waypoint(route)
    if final and tonumber(obj.x) == final.x and tonumber(obj.y) == final.y then
        return true
    end

    return normalize_label(obj.name) == normalize_label(route.title)
end

function M.route_id_for_object(obj)
    for id, route in pairs(ROUTES) do
        if object_matches_route(route, obj) then
            return id
        end
    end
    return nil
end

function M.start(route_name, map_id, px, py)
    local id = normalize_route_id(route_name)
    if not id then
        return nil, "Unknown overworld route"
    end

    local route = ROUTES[id]
    local previous_id = state.active_id
    local event = "start"
    if previous_id == id then
        event = "recalculate"
    elseif previous_id ~= nil then
        event = "replace"
    end

    state.active_id = id
    state.warned = {}
    state.last_position_key = nil
    state.next_index = choose_next_index(route, map_id, px, py)

    local message = waypoint_status(route, state.next_index, is_overworld(map_id) and px or nil, is_overworld(map_id) and py or nil)
    if event == "replace" then
        message = "Route changed. " .. message
    elseif event == "recalculate" then
        message = "Route recalculated. " .. message
    end

    return {
        route = route,
        message = message,
        log = make_log(event, route, route.waypoints[state.next_index]),
        object_id = route_object_id(route, state.next_index),
        refresh = true,
    }
end

function M.start_for_object(obj, map_id, px, py)
    if not obj then
        return nil, "No object selected"
    end

    local id = M.route_id_for_object(obj)
    if not id then
        return nil, "No guided route for " .. tostring(obj.name or "selected object") .. ". Use O for heading."
    end

    return M.start(id, map_id, px, py)
end

function M.stop()
    if not state.active_id then
        return {
            message = "No overworld route active",
            log = "event=stop route=none",
            refresh = false,
        }
    end

    local route = active_route()
    clear_active_route()

    return {
        route = route,
        message = "Stopped overworld route",
        log = "event=stop route=" .. tostring(route and route.id or "-"),
        refresh = true,
    }
end

function M.status(map_id, px, py, opts)
    opts = opts or {}
    local route = active_route()
    if not route then
        return {
            message = "No overworld route active",
            log = "event=status route=none",
        }
    end

    local index = clamp_next_index(route)
    local recalculated = false
    if opts.recalculate and is_overworld(map_id) and px ~= nil and py ~= nil then
        local new_index = choose_next_index(route, map_id, px, py)
        if new_index ~= index then
            state.next_index = new_index
            state.last_position_key = nil
            index = new_index
            recalculated = true
        end
    end

    local use_position = is_overworld(map_id)
    local message = waypoint_status(route, index, use_position and px or nil, use_position and py or nil)
    if recalculated or opts.force_recalculate_message then
        message = "Route recalculated. " .. message
    end

    return {
        route = route,
        waypoint = route.waypoints[index],
        message = message,
        log = make_log(recalculated and "recalculate" or "status", route, route.waypoints[index]),
        object_id = route_object_id(route, index),
    }
end

function M.recalculate(map_id, px, py)
    return M.status(map_id, px, py, {
        recalculate = true,
        force_recalculate_message = true,
    })
end

function M.plan_next_segment(map_id, px, py, opts)
    opts = opts or {}
    local route = active_route()
    if not route then
        return nil, "No overworld route active"
    end
    if not is_overworld(map_id) then
        return nil, "Overworld auto-walk is only available on the world map"
    end
    if px == nil or py == nil then
        return nil, "Current world-map position unavailable"
    end

    local index = clamp_next_index(route)
    local point = route.waypoints[index]
    if not point then
        return nil, "No next overworld waypoint"
    end

    local direction = direction_string(px, py, point.x, point.y)
    if distance(px, py, point) <= (point.radius or 0) then
        return {
            route = route,
            waypoint = point,
            index = index,
            steps = {},
            path_length = 0,
            status = "already_at_waypoint",
            message = "Already at " .. point.name,
            log = make_log("autowalk_already", route, point, index),
            object_id = route_object_id(route, index),
            refresh = true,
        }
    end

    local steps = {}
    local cx = px
    local cy = py
    for _, axis in ipairs(waypoint_axis_order(route, point, opts)) do
        cx, cy = append_axis_steps(steps, axis, cx, cy, point.x, point.y)
    end
    if cx ~= point.x then
        cx, cy = append_axis_steps(steps, "horizontal", cx, cy, point.x, point.y)
    end
    if cy ~= point.y then
        cx, cy = append_axis_steps(steps, "vertical", cx, cy, point.x, point.y)
    end

    local max_steps = tonumber(opts.max_steps) or 64
    if #steps > max_steps then
        return nil, string.format("Overworld segment too long: %d steps", #steps)
    end

    return {
        route = route,
        waypoint = point,
        index = index,
        steps = steps,
        path_length = #steps,
        status = "planned",
        direction = direction,
        message = string.format("Auto-walk to %s, %s. %d step(s).", point.name, direction, #steps),
        log = make_log("autowalk_plan", route, point, index),
        object_id = route_object_id(route, index),
    }
end

function M.guidance_for_object(obj, map_id, px, py)
    local route = active_route()
    if route then
        return M.status(map_id, px, py, {recalculate = true})
    end

    return M.start_for_object(obj, map_id, px, py)
end

function M.observe_position(map_id, px, py)
    local route = active_route()
    if not route then
        return nil
    end

    if is_destination_map(route, map_id) then
        return finish_route(route, route_final_waypoint(route), "arrived")
    end

    if not is_overworld(map_id) or px == nil or py == nil then
        return nil
    end

    local position_key = map_id .. ":" .. px .. "," .. py
    if state.last_position_key == position_key then
        return nil
    end
    state.last_position_key = position_key

    local index = clamp_next_index(route)
    local point = route.waypoints[index]
    if not point then
        return nil
    end

    if distance(px, py, point) > (point.radius or 0) then
        return nil
    end

    local messages = {}
    if point.warning and not state.warned[index] then
        messages[#messages + 1] = point.warning
        state.warned[index] = true
    end

    if point.final then
        local event = finish_route(route, point, "arrived")
        if #messages > 0 then
            event.message = table.concat(messages, " ") .. " " .. event.message
        end
        return event
    end

    state.next_index = math.min(index + 1, #route.waypoints)
    local next_point = route.waypoints[state.next_index]
    messages[#messages + 1] = "Reached " .. point.name .. ". Next: " .. next_point.name .. ", " ..
        direction_string(px, py, next_point.x, next_point.y)

    return {
        route = route,
        waypoint = point,
        message = table.concat(messages, " "),
        log = make_log("advance", route, point),
        object_id = route_object_id(route, state.next_index),
        refresh = true,
    }
end

function M.get_active_waypoint_objects()
    local route = active_route()
    if not route then
        return {}
    end

    local index = clamp_next_index(route)
    local result = {}
    local last_visible = math.min(#route.waypoints, index + MAX_VISIBLE_ACTIVE_WAYPOINTS - 1)
    for i = index, last_visible do
        local point = route.waypoints[i]
        local prefix = (i == index) and "Route next: " or "Route later: "
        result[#result + 1] = {
            x = point.x,
            y = point.y,
            name = prefix .. point.name,
            type = "exit",
            id = string.format("route_%s_%02d", route.id, i),
            route_id = route.id,
            route_waypoint = true,
            route_index = i,
            route_final = point.final == true,
        }
    end
    return result
end

function M.get_active_next_object_id()
    local route = active_route()
    if not route then
        return nil
    end
    return route_object_id(route, clamp_next_index(route))
end

function M.is_active()
    return active_route() ~= nil
end

function M.reset_for_tests()
    state.active_id = nil
    state.next_index = nil
    state.warned = {}
    state.last_position_key = nil
end

function M._route_for_tests(id)
    return ROUTES[id]
end

return M
