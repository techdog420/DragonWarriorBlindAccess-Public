-- field_action_guard.lua
-- Shared refusal reasons for field actions that can move or steer the player.

local M = {}
local ok_text, text = pcall(require, "text")

local MESSAGES = {
    auto_walk = {
        not_field = "Auto-walk is only available while walking on the field",
        sweep_active = "Auto-walk is unavailable during map sweep",
        step_mode = "Finish step mode before auto-walking",
        command_menu_active = "Close the command menu before auto-walking",
        submenu_active = "Close the submenu before auto-walking",
        yesno_active = "Answer or close the prompt before auto-walking",
        merchant_active = "Close the merchant interface before auto-walking",
        dialogue_active = "Wait for dialogue to finish before auto-walking",
        upper_dialogue_active = "Wait for the upper dialogue window to clear before auto-walking",
        survey_active = "Stop the active survey before auto-walking",
        map_crawl_active = "Stop the active map crawl before auto-walking",
        edge_probe_active = "Wait for the active edge probe to finish before auto-walking",
        edge_verify_active = "Wait for the active edge verification to finish before auto-walking",
        seeded_edge_probe_active = "Wait for the active seeded edge probe to finish before auto-walking",
        route_active = "Wait for the current auto-walk to finish before auto-walking",
    },
    teleport = {
        not_field = "Teleport is only available while walking on the field",
        sweep_active = "Teleport is unavailable during map sweep",
        step_mode = "Finish step mode before teleporting",
        command_menu_active = "Close the command menu before teleporting",
        submenu_active = "Close the submenu before teleporting",
        yesno_active = "Answer or close the prompt before teleporting",
        merchant_active = "Close the merchant interface before teleporting",
        dialogue_active = "Wait for dialogue to finish before teleporting",
        upper_dialogue_active = "Wait for the upper dialogue window to clear before teleporting",
        survey_active = "Stop the active survey before teleporting",
        map_crawl_active = "Stop the active map crawl before teleporting",
        edge_probe_active = "Wait for the active edge probe to finish before teleporting",
        edge_verify_active = "Wait for the active edge verification to finish before teleporting",
        seeded_edge_probe_active = "Wait for the active seeded edge probe to finish before teleporting",
        route_active = "Wait for the current auto-walk to finish before teleporting",
    },
    object_controls = {
        not_field = "Object controls unavailable right now",
        sweep_active = "Object controls unavailable during map sweep",
        step_mode = "Finish step mode before using object controls",
        command_menu_active = "Close the command menu first",
        submenu_active = "Close the submenu first",
        yesno_active = "Answer or close the prompt first",
        merchant_active = "Close the merchant interface first",
        dialogue_active = "Wait for dialogue to finish",
        upper_dialogue_active = "Wait for the upper window to clear",
        survey_active = "Wait for survey to finish",
        map_crawl_active = "Wait for map crawl to finish",
        edge_probe_active = "Wait for edge probe to finish",
        edge_verify_active = "Wait for edge verification to finish",
        seeded_edge_probe_active = "Wait for seeded edge probe to finish",
        route_active = "Wait for movement to finish",
    },
}

local CHECK_ORDER = {
    "not_field",
    "sweep_active",
    "step_mode",
    "command_menu_active",
    "submenu_active",
    "yesno_active",
    "merchant_active",
    "dialogue_active",
    "upper_dialogue_active",
    "survey_active",
    "map_crawl_active",
    "edge_probe_active",
    "edge_verify_active",
    "seeded_edge_probe_active",
    "route_active",
}

function M.dialogue_blocks_movement(dialogue_text)
    if dialogue_text == nil or dialogue_text == "" then
        return false
    end
    if ok_text and text.is_passive_field_status_noise(dialogue_text) then
        return false
    end
    return true
end

local function check_active(check, states)
    if check == "not_field" then
        return states.is_field == false
    end
    if check == "dialogue_active" then
        if states.dialogue_active ~= true then
            return false
        end
        if states.dialogue_text == nil then
            return true
        end
        return M.dialogue_blocks_movement(states.dialogue_text)
    end
    return states[check] == true
end

function M.reason(action, states)
    local messages = MESSAGES[action]
    if not messages then
        return nil
    end
    states = states or {}
    for _, check in ipairs(CHECK_ORDER) do
        if check_active(check, states) then
            return messages[check]
        end
    end
    return nil
end

return M
