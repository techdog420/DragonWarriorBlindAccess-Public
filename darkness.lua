-- darkness.lua
-- Accessible visibility policy for Dragon Warrior's dark dungeon maps.
--
-- The game stores the visible window width as an odd byte value (1, 3, 5, 7).
-- Convert that width to the number of tiles visible from the hero in each
-- direction. Physical reports always use that square; player navigation uses
-- the configured balanced, authentic, or unrestricted assistance policy.

local config = require "config"

local M = {}

M.DUNGEON_TERRAIN_OFFSET = 0x20

local function number_or_zero(value)
    return tonumber(value) or 0
end

local function configured_navigation_mode(state)
    local value = state and state.navigation_mode
    if value == nil and state then
        value = state.navigation_limits_enabled
    end
    if value == nil then
        value = config.get("darkness_navigation_limits")
    end
    if type(value) == "boolean" then
        return value and "authentic" or "unrestricted"
    end

    value = tostring(value or "balanced"):lower()
    if value == "true" or value == "1" or value == "on" or value == "yes"
       or value == "authentic" or value == "strict" then
        return "authentic"
    end
    if value == "false" or value == "0" or value == "off" or value == "no"
       or value == "unrestricted" then
        return "unrestricted"
    end
    return "balanced"
end

function M.visible_half_span(light_radius)
    local diameter = math.max(0, math.floor(number_or_zero(light_radius)))
    return math.floor(diameter / 2)
end

function M.context(state)
    state = state or {}
    local terrain_offset = number_or_zero(state.terrain_offset)
    local limited = terrain_offset == M.DUNGEON_TERRAIN_OFFSET
    local light_radius = math.max(0, math.floor(number_or_zero(state.light_radius)))
    local half_span = M.visible_half_span(light_radius)
    local navigation_mode = configured_navigation_mode(state)
    local navigation_limited = limited and (
        navigation_mode == "authentic"
        or (navigation_mode == "balanced" and half_span == 0))
    return {
        limited = limited,
        navigation_mode = navigation_mode,
        navigation_limits_enabled = navigation_mode ~= "unrestricted",
        navigation_limited = navigation_limited,
        terrain_offset = terrain_offset,
        map_id = state.map_id,
        x = number_or_zero(state.x or state.player_x),
        y = number_or_zero(state.y or state.player_y),
        light_radius = light_radius,
        half_span = half_span,
        radiant_timer = math.max(0, math.floor(number_or_zero(state.radiant_timer))),
    }
end

function M.signature(context)
    context = context or {}
    if context.limited ~= true then
        return "unrestricted"
    end
    if context.navigation_limited ~= true then
        return "darkness-navigation-unrestricted"
    end
    return table.concat({
        tostring(context.map_id or "-"),
        tostring(context.x or 0),
        tostring(context.y or 0),
        tostring(context.light_radius or 0),
    }, ":")
end

function M.is_within_light(context, x, y)
    if not context or context.limited ~= true then
        return true
    end
    if x == nil or y == nil then
        return false
    end
    local half_span = math.max(0, number_or_zero(context.half_span))
    return math.abs(x - number_or_zero(context.x)) <= half_span
       and math.abs(y - number_or_zero(context.y)) <= half_span
end

function M.is_visible(context, x, y)
    if not context or context.navigation_limited ~= true then
        return true
    end
    return M.is_within_light(context, x, y)
end

function M.describe(context)
    context = context or {}
    if context.limited ~= true then
        return "Area is fully lit"
    end
    local half_span = math.max(0, number_or_zero(context.half_span))
    local prefix
    if number_or_zero(context.radiant_timer) > 0 then
        prefix = "Radiant light"
    elseif half_span > 0 then
        prefix = "Torchlight"
    else
        prefix = "Dungeon darkness"
    end
    if half_span == 0 then
        return prefix .. ". Only the current tile is visible"
    end
    if half_span == 1 then
        return prefix .. ". One tile is visible in every direction"
    end
    return prefix .. ". " .. half_span .. " tiles are visible in every direction"
end

function M.navigation_description(context)
    context = context or {}
    if context.limited ~= true then
        return nil
    end
    if context.navigation_mode == "unrestricted" then
        return "Navigation assistance is unrestricted by darkness"
    end
    if context.navigation_mode == "balanced" then
        if context.navigation_limited == true then
            return "Balanced navigation is unavailable beyond the current tile until light is restored"
        end
        return "Balanced navigation assistance remains available while the light lasts"
    end
    if context.navigation_mode == "authentic" then
        return "Authentic navigation is limited to the current light"
    end
    return nil
end

function M.describe_with_navigation(context)
    local description = M.describe(context)
    local navigation = M.navigation_description(context)
    if navigation then
        return description .. ". " .. navigation
    end
    return description
end

function M.change_announcement(previous, current)
    current = current or {}
    if current.limited ~= true then
        return nil
    end
    if not previous or previous.limited ~= true then
        return M.describe(current)
    end
    local old_span = number_or_zero(previous.half_span)
    local new_span = number_or_zero(current.half_span)
    if old_span == new_span then
        return nil
    end
    if new_span > old_span then
        local message = "The light expands. " .. M.describe(current)
        if current.navigation_mode == "balanced" and old_span == 0 then
            message = message .. ". Navigation assistance is restored while the light lasts"
        end
        return message
    end
    if new_span == 0 then
        local message = "The light fades. Only the current tile is visible"
        if current.navigation_mode == "balanced" then
            message = message .. ". Navigation beyond the current tile is unavailable until light is restored"
        end
        return message
    end
    return "The light dims. " .. M.describe(current)
end

function M.limit_walkability_snapshot(walkability, context)
    if not walkability or not context or context.navigation_limited ~= true then
        return walkability
    end
    local limited = {}
    for y, row in pairs(walkability) do
        if type(row) == "table" then
            limited[y] = {}
            for x, is_walkable in pairs(row) do
                limited[y][x] = is_walkable == true and M.is_visible(context, x, y)
            end
        end
    end
    return limited
end

local CARDINAL_DIRECTIONS = {
    {name = "north", dx = 0, dy = -1},
    {name = "east", dx = 1, dy = 0},
    {name = "south", dx = 0, dy = 1},
    {name = "west", dx = -1, dy = 0},
}

local function cell_is_open(walkability, x, y)
    return walkability
       and type(walkability[y]) == "table"
       and walkability[y][x] == true
end

local function tile_count(count)
    if count == 1 then
        return "1 tile"
    end
    return tostring(count) .. " tiles"
end

local function describe_ray(context, walkability, direction)
    local open_count = 0
    local half_span = math.max(0, number_or_zero(context.half_span))
    for distance = 1, half_span do
        local x = number_or_zero(context.x) + direction.dx * distance
        local y = number_or_zero(context.y) + direction.dy * distance
        if not cell_is_open(walkability, x, y) then
            if open_count == 0 then
                return direction.name .. " blocked"
            end
            return direction.name .. " open " .. tile_count(open_count) .. ", then blocked"
        end
        open_count = open_count + 1
    end
    return direction.name .. " open " .. tile_count(open_count) .. " to edge of light"
end

local function relative_position(context, x, y)
    local dx = x - number_or_zero(context.x)
    local dy = y - number_or_zero(context.y)
    if dx == 0 and dy == 0 then
        return "here"
    end
    local parts = {}
    if dy < 0 then
        parts[#parts + 1] = tile_count(-dy) .. " north"
    elseif dy > 0 then
        parts[#parts + 1] = tile_count(dy) .. " south"
    end
    if dx < 0 then
        parts[#parts + 1] = tile_count(-dx) .. " west"
    elseif dx > 0 then
        parts[#parts + 1] = tile_count(dx) .. " east"
    end
    return table.concat(parts, " and ")
end

local function visible_topology(context, walkability)
    local start_x = number_or_zero(context.x)
    local start_y = number_or_zero(context.y)
    local half_span = math.max(0, number_or_zero(context.half_span))
    local queue = {{x = start_x, y = start_y}}
    local seen = {[start_x .. "," .. start_y] = true}
    local candidates = {}
    local head = 1

    while head <= #queue do
        local cell = queue[head]
        head = head + 1
        local open_directions = {}
        for _, direction in ipairs(CARDINAL_DIRECTIONS) do
            local nx = cell.x + direction.dx
            local ny = cell.y + direction.dy
            if M.is_within_light(context, nx, ny) and cell_is_open(walkability, nx, ny) then
                open_directions[#open_directions + 1] = direction
                local key = nx .. "," .. ny
                if not seen[key] then
                    seen[key] = true
                    queue[#queue + 1] = {x = nx, y = ny}
                end
            end
        end

        -- Only classify cells whose four neighbors are visible. At the edge
        -- of the light the unseen continuation is intentionally unknown.
        local topology_known = math.abs(cell.x - start_x) < half_span
                           and math.abs(cell.y - start_y) < half_span
        if topology_known and not (cell.x == start_x and cell.y == start_y) then
            local kind = nil
            if #open_directions >= 3 then
                kind = "branch"
            elseif #open_directions == 2 then
                local first = open_directions[1]
                local second = open_directions[2]
                if first.dx + second.dx ~= 0 or first.dy + second.dy ~= 0 then
                    kind = "turn"
                end
            end
            if kind then
                candidates[#candidates + 1] = {
                    kind = kind,
                    x = cell.x,
                    y = cell.y,
                    distance = math.abs(cell.x - start_x) + math.abs(cell.y - start_y),
                }
            end
        end
    end

    table.sort(candidates, function(a, b)
        if a.distance ~= b.distance then return a.distance < b.distance end
        if a.y ~= b.y then return a.y < b.y end
        if a.x ~= b.x then return a.x < b.x end
        return a.kind < b.kind
    end)
    return candidates
end

local function visible_objects(context, objects)
    local visible = {}
    for _, object in ipairs(objects or {}) do
        local x = tonumber(object.x)
        local y = tonumber(object.y)
        if x and y and M.is_within_light(context, x, y) then
            visible[#visible + 1] = {
                name = tostring(object.name or object.type or "Object"),
                x = x,
                y = y,
                distance = math.abs(x - number_or_zero(context.x))
                         + math.abs(y - number_or_zero(context.y)),
            }
        end
    end
    table.sort(visible, function(a, b)
        if a.distance ~= b.distance then return a.distance < b.distance end
        if a.y ~= b.y then return a.y < b.y end
        if a.x ~= b.x then return a.x < b.x end
        return a.name < b.name
    end)
    return visible
end

-- Describe only terrain and objects inside the game's current light square.
-- This remains spoiler-safe even when navigation restrictions are disabled.
function M.describe_visible_area(context, walkability, objects)
    context = context or {}
    if context.limited ~= true then
        return "Area is fully lit. Darkness does not limit navigation here"
    end

    local parts = {M.describe(context)}
    local navigation = M.navigation_description(context)
    if navigation then
        parts[#parts + 1] = navigation
    end

    local half_span = math.max(0, number_or_zero(context.half_span))
    if half_span == 0 then
        parts[#parts + 1] = "No neighboring terrain is visible"
    else
        local rays = {}
        for _, direction in ipairs(CARDINAL_DIRECTIONS) do
            rays[#rays + 1] = describe_ray(context, walkability, direction)
        end
        parts[#parts + 1] = "Local paths: " .. table.concat(rays, "; ")

        local topology = visible_topology(context, walkability)
        local descriptions = {}
        for i = 1, math.min(2, #topology) do
            local cell = topology[i]
            descriptions[#descriptions + 1] = cell.kind .. " "
                .. relative_position(context, cell.x, cell.y)
        end
        if #descriptions > 0 then
            parts[#parts + 1] = "Nearby layout: " .. table.concat(descriptions, "; ")
        end
    end

    local found = visible_objects(context, objects)
    if #found == 0 then
        parts[#parts + 1] = "No objects are visible"
    else
        local descriptions = {}
        for i = 1, math.min(4, #found) do
            local object = found[i]
            descriptions[#descriptions + 1] = object.name .. ", "
                .. relative_position(context, object.x, object.y)
        end
        if #found > 4 then
            descriptions[#descriptions + 1] = tostring(#found - 4) .. " more"
        end
        parts[#parts + 1] = "Visible objects: " .. table.concat(descriptions, "; ")
    end

    return table.concat(parts, ". ")
end

return M
