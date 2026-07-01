-- bridge_hotkeys.lua
-- FCEUX-only mod hotkeys supplied by the external keyboard bridge sidecar.
--
-- The sidecar writes reserved aliases (Bridge1..Bridge12) to a small state
-- file. This module merges only those aliases into input.get() key state so
-- mod hotkeys can use them without exposing arbitrary keyboard names.

local config = require "config"

local emulator_compat = rawget(_G, "DW_EMULATOR_COMPAT")
if not emulator_compat then
    local ok, compat = pcall(require, "emulator_compat")
    if ok then
        emulator_compat = compat
    else
        emulator_compat = {is_fceux = false, is_bizhawk = false}
    end
end

local M = {}

local source = debug.getinfo(1, "S").source
local script_dir = source:match("@?(.*[\\/])") or ""
local BRIDGE_HOTKEY_FILE = rawget(_G, "DW_BRIDGE_HOTKEY_FILE_OVERRIDE")
    or (script_dir .. "dw_bridge_hotkeys.txt")

local allowed_aliases = {}
for index = 1, 12 do
    allowed_aliases["Bridge" .. tostring(index)] = true
end

local last_line = nil
local cached_aliases = nil

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function enabled()
    return emulator_compat.is_fceux == true
        and config.get("enable_fceux_bridge_hotkeys") ~= "false"
end

local function read_first_line()
    local f = io.open(BRIDGE_HOTKEY_FILE, "r")
    if not f then
        return nil
    end
    local line = f:read("*l")
    f:close()
    return trim(line or "")
end

local function shallow_copy(source_table)
    local copy = {}
    for key, value in pairs(source_table or {}) do
        copy[key] = value
    end
    return copy
end

function M.parse_line(line)
    local aliases = {}
    line = trim(line)
    if line == "" or line == "-" then
        return aliases
    end
    for token in line:gmatch("[^,]+") do
        local alias = trim(token)
        if allowed_aliases[alias] then
            aliases[alias] = true
        end
    end
    return aliases
end

local function current_aliases()
    local line = read_first_line()
    if not line then
        last_line = nil
        cached_aliases = nil
        return {}
    end
    if line == last_line and cached_aliases then
        return shallow_copy(cached_aliases)
    end
    local aliases = M.parse_line(line)
    last_line = line
    cached_aliases = aliases
    return shallow_copy(aliases)
end

function M.merge_keys(keys)
    keys = keys or {}
    if not enabled() then
        return keys
    end
    for alias in pairs(current_aliases()) do
        keys[alias] = true
    end
    return keys
end

function M.read_state_line()
    local line = read_first_line()
    if not line then
        return "(missing)"
    end
    if line == "" then
        return "-"
    end
    return line
end

function M.reload_config()
    last_line = nil
    cached_aliases = nil
end

return M
