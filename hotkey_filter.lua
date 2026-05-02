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

-- Memoized parsed allowlist. filter_bizhawk_keys runs every frame, so the
-- raw form (CSV split + per-key config.get + key_combo.parse) is rebuilt
-- only when the allowlist itself or one of the referenced key bindings
-- changes. M.reload_config() invalidates the cache; callers wire that to
-- the __config_reloaded hook. The cache is also keyed on the config object
-- identity so callers (notably tests) can pass alternate configs without
-- seeing stale entries from a prior call.
local cache = nil
local cache_config = nil

local function rebuild_cache(config)
    local allowlist = config.get("bizhawk_keyboard_hotkey_allowlist")
    if allowlist == nil or trim(allowlist) == "" then
        allowlist = DEFAULT_BIZHAWK_ALLOWLIST
    end

    -- entries: list of { spec=string, parts=table, is_combo=bool, aliases=table }
    -- non_combo_aliases: precomputed merged alias set for all non-combo entries,
    --                    so the per-frame fast path is a single union.
    local entries = {}
    local non_combo_aliases = {}
    for _, setting_name in ipairs(split_csv(allowlist)) do
        local key_name = config.get(setting_name)
        if key_name ~= nil then
            key_name = trim(key_name)
            if key_name ~= "" then
                local parts = key_combo.parse(key_name)
                local is_combo = #parts > 1
                local entry_aliases = {}
                key_combo.add_aliases(entry_aliases, key_name)
                entries[#entries + 1] = {
                    spec = key_name,
                    parts = parts,
                    is_combo = is_combo,
                    aliases = entry_aliases,
                }
                if not is_combo then
                    for alias in pairs(entry_aliases) do
                        non_combo_aliases[alias] = true
                    end
                end
            end
        end
    end

    cache = {
        entries = entries,
        non_combo_aliases = non_combo_aliases,
    }
    cache_config = config
    return cache
end

local function get_cache(config)
    if cache and cache_config == config then
        return cache
    end
    return rebuild_cache(config)
end

local function build_allowed_keys(config, keys)
    local c = get_cache(config)
    -- Start with the precomputed non-combo aliases and union in combos that
    -- are currently held. Combos must be evaluated per frame because their
    -- modifier state changes; the parsed `parts` table is reused.
    local allowed = {}
    for alias in pairs(c.non_combo_aliases) do
        allowed[alias] = true
    end
    for _, entry in ipairs(c.entries) do
        if entry.is_combo and key_combo.is_down_parsed(keys, entry.parts) then
            for alias in pairs(entry.aliases) do
                allowed[alias] = true
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

-- Drop the memoized parse so the next filter_bizhawk_keys call sees fresh
-- allowlist + key binding values. Wired from the __config_reloaded hook.
function M.reload_config()
    cache = nil
    cache_config = nil
end

return M
