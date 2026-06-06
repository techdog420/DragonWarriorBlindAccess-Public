-- edge_verify_classifier.lua
-- Shared classification rules for probe_edge_verify results.

local M = {}

local function count(value)
    local num = tonumber(value) or 0
    if num < 0 then
        return 0
    end
    return math.floor(num)
end

function M.teleport_artifact_suspected(results, meta)
    results = results or {}
    meta = meta or {}

    local moved = count(results.moved)
    local blocked = count(results.blocked)
    if moved == 0 or blocked == 0 then
        return false
    end

    if count(results.blocked_model_mismatch) ~= blocked then
        return false
    end
    if meta.first_attempt_status ~= "moved" then
        return false
    end
    if count(meta.blocked_after_move_count) ~= blocked then
        return false
    end
    if count(meta.blocked_after_move_mismatch_count) ~= blocked then
        return false
    end
    if count(meta.moved_after_blocked_count) > 0 then
        return false
    end

    return true
end

function M.classify(final_status, results, meta)
    results = results or {}
    meta = meta or {}

    local attempts = count(meta.attempts)
    local moved = count(results.moved)
    local blocked = count(results.blocked)

    if final_status == "cancelled" then
        return "cancelled"
    end
    if count(results.map_changed) > 0 then
        return "inconclusive_map_changed"
    end
    if count(results.interrupted) > 0 then
        return "inconclusive_interrupted"
    end
    if count(results.refused) > 0 or count(results.drifted) > 0 then
        return "inconclusive_control"
    end
    if count(results.timed_out) > 0 then
        return "inconclusive_timeout"
    end
    if blocked == attempts and moved == 0 then
        return "confirmed_blocked"
    end
    if moved == attempts and blocked == 0 then
        if count(results.moved_model_mismatch) > 0 then
            return "suspect_passable_model_mismatch"
        end
        return "confirmed_passable"
    end
    if moved > 0 and blocked > 0 then
        if M.teleport_artifact_suspected(results, meta) then
            return "inconclusive_teleport_artifact"
        end
        return "mixed"
    end
    return "inconclusive"
end

return M
