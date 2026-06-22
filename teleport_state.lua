-- teleport_state.lua
-- Small RAM-write helpers for debug teleports.

local addr = require "addresses"

local M = {}

local function read_byte(address)
    if not address or not memory or not memory.readbyte then
        return nil
    end
    local ok, value = pcall(memory.readbyte, address)
    if ok then
        return value
    end
    return nil
end

local function write_byte(address, value)
    if not address or value == nil or not memory or not memory.writebyte then
        return false
    end
    local ok = pcall(memory.writebyte, address, value)
    return ok == true
end

local function wrap_byte(value)
    return math.floor(value or 0) % 256
end

local function translate_byte(address, tile_delta)
    if not address or tile_delta == 0 then
        return nil
    end
    local before = read_byte(address)
    if before == nil then
        return nil
    end
    local after = wrap_byte(before + tile_delta * 16)
    write_byte(address, after)
    return {
        address = address,
        before = before,
        after = after,
    }
end

function M.apply_landing(x, y, opts)
    opts = opts or {}
    local old_x = read_byte(addr.PLAYER_X)
    local old_y = read_byte(addr.PLAYER_Y)
    local dx = (old_x ~= nil and x ~= nil) and (x - old_x) or 0
    local dy = (old_y ~= nil and y ~= nil) and (y - old_y) or 0

    write_byte(addr.PLAYER_X, x)
    write_byte(addr.PLAYER_Y, y)

    if opts.is_overworld then
        write_byte(addr.OVERWORLD_X, x)
        write_byte(addr.OVERWORLD_Y, y)
        return {
            old_x = old_x,
            old_y = old_y,
            x = x,
            y = y,
            dx = dx,
            dy = dy,
            screen_synced = false,
        }
    end

    local scroll_x = translate_byte(addr.SCROLL_X, dx)
    local scroll_y = translate_byte(addr.SCROLL_Y, dy)
    local sprite_x = translate_byte(addr.PLAYER_SPRITE_X, dx)
    local sprite_y = translate_byte(addr.PLAYER_SPRITE_Y, dy)

    return {
        old_x = old_x,
        old_y = old_y,
        x = x,
        y = y,
        dx = dx,
        dy = dy,
        screen_synced = true,
        scroll_x = scroll_x,
        scroll_y = scroll_y,
        sprite_x = sprite_x,
        sprite_y = sprite_y,
    }
end

return M
