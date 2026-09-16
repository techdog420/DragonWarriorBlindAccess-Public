-- NPC byte 2 ($0053 + 3*slot) is NPCMidPos, a within-tile pixel offset.
-- Mobility comes from the slot: Bank00 UpdateNPCs1 ($B76F) updates slots 0..9;
-- Bank03 ValidateNPC ($D0DC) separates static NPCs at byte offset $1E (slot 10).
local M = {}

function M.for_slot(slot)
    slot = tonumber(slot)
    if slot == nil or slot ~= math.floor(slot) or slot < 0 or slot >= 20 then
        return "unknown"
    end
    return slot < 10 and "mobile" or "stationary"
end

function M.of(npc)
    if type(npc) ~= "table" then return "unknown" end
    local slot = npc.slot
    if M.for_slot(slot) == "unknown" and npc.id then
        slot = tostring(npc.id):match("^npc_(%d+)$")
    end
    return M.for_slot(slot)
end

return M
