-- Ending credits use the title reader's font, then replace it with artwork.
-- Live FCEUX capture 2026-09-30: The End is tiles 3E..55 at rows 13/14.
local M = {}
local previous, stable, announced_end = nil, 0, false

function M.is_active(snapshot)
    -- The ROM's ending routine writes FF to level ($C7). Keep uninitialized
    -- title RAM out: the ending retains Tantegel and valid player HP.
    return snapshot.level == 0xFF and snapshot.map_id == 0x04
        and (snapshot.max_hp or 0) > 0 and snapshot.max_hp < 0xFF
        and (snapshot.hp or 0) > 0 and snapshot.hp <= snapshot.max_hp
end

local function art_row(bytes, first, count, column)
    column = column or 11
    for col = 1, 32 do
        local expected = (col >= column and col < column + count)
            and (first + col - column) or 0x5F
        if bytes[col] ~= expected then return false end
    end
    return true
end

local function decorative_row(bytes)
    -- ROM offset 0x5912 writes the preceding illustration to $218F,
    -- $21AE, $21CE, $21EE, $220E: five separate rows, not one long run.
    if art_row(bytes, 0x10, 3, 16) or art_row(bytes, 0x13, 4, 15)
        or art_row(bytes, 0x17, 4, 15) or art_row(bytes, 0x1B, 4, 15)
        or art_row(bytes, 0x1F, 4, 15) then return true end
    -- Ignore partially drawn final artwork without decoding punctuation.
    local first, last, count = nil, nil, 0
    for _, byte in ipairs(bytes) do
        if byte ~= 0x5F then
            if last and byte ~= last + 1 then return false end
            first, last, count = first or byte, byte, count + 1
        end
    end
    return count >= 4 and ((first == 0x3E and last <= 0x49)
        or (first == 0x4A and last <= 0x55))
end

function M.classify(rows, decode)
    local terminal = art_row(rows[14], 0x3E, 12) and art_row(rows[15], 0x4A, 12)
    local lines = {}
    for row = 1, 30 do
        if terminal and row ~= 14 and row ~= 15 then
            for _, byte in ipairs(rows[row]) do
                if byte ~= 0x5F then terminal = false; break end
            end
        end
        if not decorative_row(rows[row]) then
            local line = decode(rows[row]):match("^%s*(.-)%s*$")
            if line ~= "" and line:find("[a-zA-Z]") then lines[#lines + 1] = line end
        end
    end
    if terminal then return "terminal", "The End." end
    return "credits", table.concat(lines, " ")
end

function M.update(kind, value, threshold)
    local key = kind .. ":" .. value
    if key == previous then stable = stable + 1 else previous, stable = key, 0 end
    if stable ~= threshold or value == "" then return nil end
    if kind == "terminal" then
        if announced_end then return nil end
        announced_end = true
    end
    return value
end

function M.reset()
    previous, stable, announced_end = nil, 0, false
end

return M
