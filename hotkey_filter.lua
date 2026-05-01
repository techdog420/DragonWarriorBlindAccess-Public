-- hotkey_filter.lua
-- Keyboard-input policy helpers.
--
-- BizHawk's input.get() can include ordinary Windows/screen-reader key state,
-- so full diagnostic hotkeys are risky there. Keep the default BizHawk path
-- limited to a configurable allowlist of gameplay/QoL shortcut settings.

local M = {}
local key_combo = require "key_combo"

local DEFAULT_BIZHAWK_ALLOWLIST = table.concat({
    "key_object_prev",
    "key_object_current",
    "key_object_next",
    "key_pathfind",
    "key_auto_walk",
    "key_filter",
    "key_freeze_npcs",
    "key_diag_tiles",
}, ",")

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function split_csv(value)
    local entries = {}
    value = tostring(value or "")
    for token in value:gmatch("[^,]+") do
        local cleaned = trim(token)
        if cleaned ~= "" then
            entries[#entries + 1] = cleaned
        end
    end
    return entries
end

local function build_allowed_keys(config, keys)
    local allowlist = config.get("bizhawk_keyboard_hotkey_allowlist")
    if allowlist == nil or trim(allowlist) == "" then
        allowlist = DEFAULT_BIZHAWK_ALLOWLIST
    end

    local allowed = {}
    for _, setting_name in ipairs(split_csv(allowlist)) do
        local key_name = config.get(setting_name)
        if key_name ~= nil then
            key_name = trim(key_name)
            if key_name ~= "" then
                if not key_combo.is_combo(key_name) or key_combo.is_down(keys, key_name) then
                    key_combo.add_aliases(allowed, key_name)
                end
            end
        end
    end
    return allowed
end

function M.filter_bizhawk_keys(keys, config)
    keys = keys or {}
    if config.get("enable_bizhawk_keyboard_hotkeys") == "true" then
        return keys
    end

    local allowed = build_allowed_keys(config, keys)
    local filtered = {}
    for key_name, pressed in pairs(keys) do
        if pressed and allowed[key_name] then
            filtered[key_name] = pressed
        end
    end
    return filtered
end

return M
