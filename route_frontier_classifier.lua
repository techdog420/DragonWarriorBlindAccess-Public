-- route_frontier_classifier.lua
-- Shared classification rules for route-frontier candidate reporting.

local M = {}

function M.classify_candidate(candidate)
    local is_walkable = candidate and candidate.is_walkable == true
    local blocked_reason = candidate and candidate.blocked_reason or nil

    if is_walkable then
        return {
            reason = blocked_reason or "unknown_unreached",
            allow_hidden_bridge = false,
        }
    end

    if blocked_reason then
        return {
            reason = blocked_reason,
            allow_hidden_bridge = false,
        }
    end

    return {
        reason = "not_walkable",
        allow_hidden_bridge = true,
    }
end

return M
