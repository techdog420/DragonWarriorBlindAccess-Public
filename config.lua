-- config.lua
-- Configuration system for Dragon Warrior Accessibility Mod.
--
-- Reads settings from a config file (dw_access.ini) in the mod directory.
-- If the file doesn't exist, creates it with default values on first run.
-- All hotkeys and settings are configurable through this file.
--
-- Config file format: simple key=value pairs, one per line.
-- Lines starting with ; are comments. Blank lines are ignored.
--
-- Usage:
--   local config = require "config"
--   local key = config.get("key_position")  -- returns "P" (or whatever user set)

local M = {}

-- ============================================================
-- Script Directory
-- ============================================================
-- We need to know where the mod lives so we can find the config file.
local source = debug.getinfo(1, "S").source
local script_dir = source:match("@?(.*[\\/])") or ""

-- Config file path — lives next to the Lua scripts
local CONFIG_FILE = script_dir .. "dw_access.ini"

-- ============================================================
-- Default Settings
-- ============================================================
-- These are used when the config file doesn't exist or when a
-- setting is missing from the file. The order here determines
-- the order they appear in a newly generated config file.
--
-- We use an ordered list of {key, value, comment} triples so the
-- generated file has nice section headers and comments.

local DEFAULTS_ORDERED = {
    -- Section: Information hotkeys
    {comment = "; Dragon Warrior Accessibility Mod Configuration"},
    {comment = "; Edit hotkey assignments below. Use FCEUX key names:"},
    {comment = ";   Letters: A-Z (uppercase)"},
    {comment = ";   Numbers: 0-9"},
    {comment = ";   Function keys: F1-F12"},
    {comment = ";   Special: space, enter, tab, backspace"},
    {comment = ""},
    {comment = "; === Information Hotkeys ==="},
    {key = "key_position",      value = "P",  comment = "; Announce map name and coordinates"},
    {key = "key_hp",            value = "H",  comment = "; Announce current HP and MP"},
    {key = "key_level",         value = "I",  comment = "; Announce player level"},
    {key = "key_gold",          value = "G",  comment = "; Announce gold"},
    {key = "key_experience",    value = "E",  comment = "; Announce experience points"},
    {key = "key_stats",         value = "S",  comment = "; Announce full stat summary"},
    {key = "key_screen_text",   value = "T",  comment = "; Read all text on screen"},
    {comment = ""},
    {comment = "; === Object Navigation ==="},
    {comment = "; Cycle through nearby objects (NPCs, stairs, chests, exits)"},
    {key = "key_object_prev",   value = "J",  comment = "; Previous object in list"},
    {key = "key_object_current", value = "K", comment = "; Describe current object"},
    {key = "key_object_next",   value = "L",  comment = "; Next object in list"},
    {key = "key_pathfind",      value = "O",  comment = "; Pathfind to selected object"},
    {key = "key_filter",        value = "F",  comment = "; Cycle object filter (All/NPCs/Exits/Chests)"},
    {comment = ""},
    {comment = "; === Movement ==="},
    {key = "enable_auto_step",  value = "true", comment = "; Auto-complete tile steps from quick D-pad taps"},
    {key = "auto_step_timeout", value = "30",   comment = "; Max frames to hold direction (increase if steps aren't completing)"},
    {comment = ""},
    {comment = "; === Diagnostics ==="},
    {key = "key_diag_cursor",   value = "M",  comment = "; Show raw menu cursor values"},
    {key = "key_diag_ppu_dump", value = "D",  comment = "; Dump PPU data to file"},
}

-- Build a flat key->value lookup from the defaults for quick access
local defaults = {}
for _, entry in ipairs(DEFAULTS_ORDERED) do
    if entry.key then
        defaults[entry.key] = entry.value
    end
end

-- ============================================================
-- Settings Storage
-- ============================================================
-- Loaded settings from the config file (overrides defaults)
local settings = {}

-- ============================================================
-- File Reading
-- ============================================================

-- parse_config(text): Parse config file contents into a key->value table.
-- Handles key=value lines, ignores comments (;) and blank lines.
-- Trims whitespace from both keys and values.
local function parse_config(text)
    local result = {}
    for line in text:gmatch("[^\r\n]+") do
        -- Skip comments and blank lines
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" and trimmed:sub(1, 1) ~= ";" then
            -- Split on first = sign
            local key, value = trimmed:match("^([^=]+)=(.*)$")
            if key and value then
                key = key:match("^%s*(.-)%s*$")     -- trim key
                value = value:match("^%s*(.-)%s*$")  -- trim value
                if key ~= "" then
                    result[key] = value
                end
            end
        end
    end
    return result
end

-- ============================================================
-- File Writing
-- ============================================================

-- write_default_config(): Create a new config file with all default
-- settings and helpful comments. Called on first run when no config
-- file exists.
local function write_default_config()
    local f = io.open(CONFIG_FILE, "w")
    if not f then
        print("WARNING: Could not create config file: " .. CONFIG_FILE)
        return false
    end

    for _, entry in ipairs(DEFAULTS_ORDERED) do
        if entry.key then
            -- Write a setting line, with inline comment if present
            if entry.comment then
                f:write(entry.comment .. "\n")
            end
            f:write(entry.key .. "=" .. entry.value .. "\n")
        else
            -- Write a comment-only or blank line
            f:write((entry.comment or "") .. "\n")
        end
    end

    f:close()
    return true
end

-- ============================================================
-- Public API
-- ============================================================

-- load(): Read the config file and populate settings.
-- If the file doesn't exist, creates it with defaults.
-- Call this once at startup (it's called automatically on require).
function M.load()
    local f = io.open(CONFIG_FILE, "r")
    if f then
        -- Config file exists — parse it
        local text = f:read("*all")
        f:close()
        settings = parse_config(text)
    else
        -- No config file — create one with defaults
        write_default_config()
        -- Use defaults (settings table stays empty, get() falls back)
    end
end

-- get(setting_name): Return the value for a setting.
-- Checks the loaded config first, then falls back to the default.
-- Returns nil if the setting name is completely unknown.
function M.get(setting_name)
    -- Config file value takes priority
    if settings[setting_name] ~= nil then
        return settings[setting_name]
    end
    -- Fall back to default
    return defaults[setting_name]
end

-- get_default(setting_name): Return the default value for a setting,
-- ignoring any config file override. Useful for reset functionality.
function M.get_default(setting_name)
    return defaults[setting_name]
end

-- ============================================================
-- Auto-load on require
-- ============================================================
-- When another module does require("config"), we automatically
-- load the config file. This means settings are available
-- immediately without needing to call config.load() separately.
M.load()

return M
