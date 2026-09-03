-- darkness.lua
-- Accessible visibility policy for Dragon Warrior's dark dungeon maps.
--
-- The game stores the visible window width as an odd byte value (1, 3, 5, 7).
-- Convert that width to the number of tiles visible from the hero in each
-- direction, then use the same square for speech, object browsing, and path
-- previews.

local M = {}

M.DUNGEON_TERRAIN_OFFSET = 0x20

local function number_or_zero(value)
    return tonumber(value) or 0
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
    return {
        limited = limited,
        terrain_offset = terrain_offset,
        map_id = state.map_id,
        x = number_or_zero(state.x or state.player_x),
        y = number_or_zero(state.y or state.player_y),
        light_radius = light_radius,
        half_span = M.visible_half_span(light_radius),
        radiant_timer = math.max(0, math.floor(number_or_zero(state.radiant_timer))),
    }
end

function M.signature(context)
    context = context or {}
    if context.limited ~= true then
        return "unrestricted"
    end
    return table.concat({
        tostring(context.map_id or "-"),
        tostring(context.x or 0),
        tostring(context.y or 0),
        tostring(context.light_radius or 0),
    }, ":")
end

function M.is_visible(context, x, y)
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
        return "The light expands. " .. M.describe(current)
    end
    if new_span == 0 then
        return "The light fades. Only the current tile is visible"
    end
    return "The light dims. " .. M.describe(current)
end

function M.limit_walkability_snapshot(walkability, context)
    if not walkability or not context or context.limited ~= true then
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

return M
