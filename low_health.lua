-- low_health.lua: one warning per low-health episode, independent of damage source.
local M = {}
function M.threshold(value)
    local n = tonumber(value)
    if not n or n ~= n or n < 1 or n > 100 then return 25 end
    return math.floor(n)
end
function M.new(speech, log)
    local warned, record, last_text = false, nil, nil
    local self = {}
    local function clear(reason)
        if record and speech.cancel_warning then speech.cancel_warning(record.id) end
        if warned and log then log("LOW_HEALTH_REARM reason=" .. reason) end
        warned, record, last_text = false, nil, nil
    end
    function self.update(snapshot, eligible, enabled, threshold)
        threshold = M.threshold(threshold)
        local hp, maximum, level = snapshot.hp, snapshot.max_hp, snapshot.level
        if enabled == false or enabled == "false" then clear("disabled"); return end
        if not eligible or type(hp) ~= "number" or type(maximum) ~= "number"
            or type(level) ~= "number" or level < 1 or level > 30
            or maximum < 1 or maximum > 255 or hp <= 0 or hp > maximum then
            clear("not_alive_gameplay"); return
        end
        if hp * 100 > maximum * threshold then clear("above_threshold"); return end
        local text = string.format("Low health. HP %d of %d.", hp, maximum)
        if not warned then
            record = speech.output_warning(text)
            warned, last_text = true, text
            if log then log(string.format("LOW_HEALTH_WARNING hp=%d max_hp=%d threshold=%d", hp, maximum, threshold)) end
        elseif record and text ~= last_text then
            if speech.update_warning then speech.update_warning(record.id, text) end
            last_text = text
        end
    end
    function self.reset() clear("reload") end
    return self
end
return M
