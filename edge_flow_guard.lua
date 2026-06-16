-- edge_flow_guard.lua
-- Shared guard logic for mutually exclusive edge-probe command flows.

local M = {}

local FLOW_ORDER = {
    {field = "probe_state", label = "edge probe"},
    {field = "verify_state", label = "edge verification"},
    {field = "seeded_probe_state", label = "seeded edge probe"},
}

function M.active_flow(states)
    if type(states) ~= "table" then
        return nil
    end
    for _, flow in ipairs(FLOW_ORDER) do
        if states[flow.field] ~= nil then
            return flow.label, flow.field
        end
    end
    return nil
end

function M.refusal_message(command_name, states)
    local label = M.active_flow(states)
    if not label then
        return nil
    end
    return string.format("%s: wait for the active %s to finish", tostring(command_name), label)
end

return M
