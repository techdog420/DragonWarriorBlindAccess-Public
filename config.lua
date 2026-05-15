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
--   local key = config.get("key_position")  -- returns "Shift+W" (or whatever user set)

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
    {comment = "; Edit hotkey assignments below. Keys are normalized by the emulator adapter:"},
    {comment = ";   Letters: A-Z (uppercase)"},
    {comment = ";   Combos: Ctrl+N, Shift+F"},
    {comment = ";   Numbers: 0-9"},
    {comment = ";   Function keys: F1-F12"},
    {comment = ";   Special: space, enter, tab, backspace, up, down, left, right"},
    {comment = "; BizHawk NES controls use X=A, Z=B, Enter=Start, Space=Select; avoid those for mod hotkeys."},
    {comment = "; BizHawk's S and A keys are NES autofire by default, so avoid those too."},
    {comment = ""},
    {comment = "; === Information Hotkeys (Shift+key) ==="},
    {key = "key_position",      value = "Shift+W",  comment = "; Announce map name and coordinates"},
    {key = "key_hp",            value = "Shift+H",  comment = "; Announce current HP and MP"},
    {key = "key_level",         value = "Shift+I",  comment = "; Announce player level"},
    {key = "key_gold",          value = "Shift+G",  comment = "; Announce gold"},
    {key = "key_experience",    value = "Shift+E",  comment = "; Announce experience points"},
    {key = "key_stats",         value = "Shift+R",  comment = "; Announce full stat summary"},
    {key = "key_screen_text",   value = "Shift+T",  comment = "; Read all text on screen"},
    {comment = ""},
    {comment = "; === Object Navigation ==="},
    {comment = "; Cycle through nearby objects (NPCs, stairs, chests, exits)"},
    {key = "key_object_prev",   value = "J",  comment = "; Previous object in list"},
    {key = "key_object_current", value = "K", comment = "; Describe current object"},
    {key = "key_object_next",   value = "L",  comment = "; Next object in list"},
    {key = "key_pathfind",      value = "O",  comment = "; Pathfind to selected object"},
    {key = "key_route_guidance", value = "R", comment = "; Start or check guided route for selected Travel object"},
    {key = "key_auto_walk",     value = "U",  comment = "; Auto-walk to selected object using pathfinder"},
    {key = "key_freeze_npcs",   value = "Shift+F",  comment = "; Toggle NPC position freeze (locks NPCs in place for reliable pathfinding)"},
    {key = "key_filter",        value = "Q",  comment = "; Cycle object filter (All/NPCs/Services/Treasure/Travel/Doors)"},
    {key = "key_filter_prev",   value = "Shift+J", comment = "; Previous object filter"},
    {key = "key_filter_all",    value = "Shift+K", comment = "; Return object filter to All"},
    {key = "key_filter_next",   value = "Shift+L", comment = "; Next object filter"},
    {key = "key_pathability_filter", value = "Shift+O", comment = "; Cycle object reachability filter (All/Reachable/Unreachable)"},
    {key = "key_mark_visited",  value = "Shift+V", comment = "; Mark the current object as visited"},
    {key = "key_teleport_exact", value = "Shift+Enter", comment = "; Teleport to the selected object; NPCs use an adjacent interaction cell"},
    {key = "key_teleport_north", value = "Shift+Up", comment = "; Teleport to the cell north of the selected object"},
    {key = "key_teleport_south", value = "Shift+Down", comment = "; Teleport to the cell south of the selected object"},
    {key = "key_teleport_west", value = "Shift+Left", comment = "; Teleport to the cell west of the selected object"},
    {key = "key_teleport_east", value = "Shift+Right", comment = "; Teleport to the cell east of the selected object"},
    {key = "object_nav_speech_coalesce_frames", value = "18", comment = "; Wait this many frames before speaking rapid previous/next object taps (0 = immediate)"},
    {comment = ""},
    {comment = "; === Movement ==="},
    {key = "enable_auto_step",  value = "true", comment = "; Auto-complete tile steps from quick D-pad taps"},
    {key = "auto_step_timeout", value = "45",   comment = "; Max frames to wait for step to complete (increase if steps aren't finishing)"},
    {key = "edge_probe_raw_hold_frames", value = "60", comment = "; Frames to hold raw D-pad input for probe_edge/probe_edge_verify collision checks"},
    {key = "auto_step_inject_limit", value = "12", comment = "; Frames to hold each auto-step press before waiting for movement"},
    {key = "auto_step_turn_repress_delay", value = "18", comment = "; Frames before re-pressing after a turn-only attempt"},
    {key = "auto_step_turn_repress_limit", value = "1", comment = "; Number of quick turn-only re-press attempts before timeout retries"},
    {key = "auto_step_turn_repress_release_frames", value = "2", comment = "; Neutral frames between turn-only press and re-press"},
    {key = "auto_step_block_retry_limit", value = "1", comment = "; Internal retries before reporting a blocked step (lower reduces blocked-route audio hitches)"},
    {key = "auto_step_manual_block_retry_limit", value = "0", comment = "; Internal retries for player tap-to-step collisions (0 keeps wall bumps responsive)"},
    {key = "auto_step_route_turn_settle_frames", value = "16", comment = "; Extra neutral frames before queued auto-walk changes direction"},
    {key = "auto_step_route_early_release_grace_frames", value = "10", comment = "; Subpixel twitches at/before this frame keep holding input"},
    {key = "auto_step_manual_early_hold_frames", value = "8", comment = "; Extra frames to hold released manual taps after an early movement twitch"},
    {key = "auto_step_route_turn_repress_timeout_frames", value = "24", comment = "; Short timeout for queued-route turn re-presses that only twitch"},
    {key = "auto_step_route_early_twitch_timeout_frames", value = "32", comment = "; Short timeout for early queued-route movement twitches before seam retry"},
    {key = "auto_step_release_on_movement_start", value = "true", comment = "; Release injected D-pad once movement subpixel changes to reduce cell overshoot"},
    {key = "auto_walk_progress_interval", value = "6", comment = "; Speak auto-walk progress every N completed queued steps on longer routes (0 = off)"},
    {key = "auto_walk_npc_hold_frames", value = "1200", comment = "; Frames to hold a target NPC in place after auto-walk arrival (0 = off)"},
    {key = "auto_walk_face_target_frames", value = "8", comment = "; Frames to press toward an auto-walk interaction target after arrival (0 = off)"},
    {key = "enable_keyboard_input_bridge", value = "true", comment = "; FCEUX only: mirror keyboard controls when menu focus leaves joypad input idle"},
    {key = "enable_bizhawk_keyboard_hotkeys", value = "false", comment = "; BizHawk only: enable mod hotkeys from input.get() (off by default to avoid stray screen-reader/typing keys)"},
    {key = "enable_bizhawk_diagnostic_hotkeys", value = "false", comment = "; BizHawk only: enable developer diagnostic dump/cursor hotkeys while full keyboard hotkeys are off"},
    {key = "bizhawk_keyboard_hotkey_allowlist", value = "key_position,key_hp,key_level,key_gold,key_experience,key_stats,key_screen_text,key_object_prev,key_object_current,key_object_next,key_pathfind,key_route_guidance,key_auto_walk,key_filter,key_filter_prev,key_filter_all,key_filter_next,key_pathability_filter,key_mark_visited,key_teleport_exact,key_teleport_north,key_teleport_south,key_teleport_west,key_teleport_east,key_freeze_npcs,key_diag_tiles", comment = "; BizHawk only: comma-separated config key names allowed when full keyboard hotkeys are off (player-safe readouts/object keys; diagnostic flag adds developer diagnostics)"},
    {key = "bizhawk_object_reachability_descriptions", value = "false", comment = "; BizHawk only: include reachability/path checks in object descriptions (slower; pathfind still works)"},
    {key = "bizhawk_periodic_npc_refresh", value = "false", comment = "; BizHawk only: refresh moving NPC objects in the background (off avoids periodic audio hitches)"},
    {key = "bizhawk_map_entry_prewarm_path_grid", value = "false", comment = "; BizHawk only: prebuild pathfinding tile grids on map entry (faster first route, slower transitions)"},
    {key = "bizhawk_route_refresh_npcs", value = "false", comment = "; BizHawk only: refresh live NPC blockers before O/U path planning (slower)"},
    {key = "bizhawk_autowalk_freeze_npcs", value = "false", comment = "; BizHawk only: freeze NPC RAM during auto-walk routes (slower)"},
    {key = "bizhawk_route_cleanup_refresh_objects", value = "false", comment = "; BizHawk only: refresh object/NPC list immediately after route completion/cancel (slower)"},
    {comment = ""},
    {comment = "; === Dialogue ==="},
    {comment = "; (yesno_dismiss_frames setting removed — prompt now uses label-presence detection)"},
    {key = "speech_python_cmd", value = "python", comment = "; Python executable for speech_bridge.py (set to .venv\\Scripts\\python.exe to use a local venv)"},
    {key = "speech_debounce_ms", value = "1000", comment = "; Suppress duplicate queued speech within this many milliseconds (0 to disable)"},
    {comment = ""},
    {comment = "; === Debug / Automation ==="},
    {key = "debug_mode",        value = "false", comment = "; Set true to enable dw_debug.log and dw_commands.txt processing"},
    {key = "debug_log_level",   value = "DEBUG",  comment = "; Log verbosity when debug_mode=true: ERROR, INFO, or DEBUG"},
    {key = "pathfind_log_steps", value = "false", comment = "; Set true to log every tile in chosen paths (slow; debugging only)"},
    {key = "auto_step_record_debug_blocks", value = "false", comment = "; Debug only: automatically append timed-out auto-step blocks to dw_blocks.log (off avoids noisy map data)"},
    {comment = ""},
    {comment = "; === Diagnostics (Ctrl+key) ==="},
    {key = "key_diag_cursor",   value = "Ctrl+M",  comment = "; Show raw menu cursor values"},
    {key = "key_diag_ppu_dump", value = "Ctrl+D",  comment = "; Dump PPU data to file"},
    {key = "key_diag_tiles",    value = "Ctrl+N",  comment = "; Speak tile types at player position"},
    {key = "tile_diag_dump_on_hotkey", value = "false", comment = "; Also write full tile_diag.txt when pressing Ctrl+N (slow; debugging only)"},
    {key = "key_diag_title",    value = "Ctrl+Y",  comment = "; Dump title screen cursor/RAM state to title_diag.txt (use on adventure log or message speed screens)"},
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
-- File Updating
-- ============================================================

-- append_missing_settings(): After loading an existing config file,
-- check whether any keys from DEFAULTS_ORDERED are absent and
-- append them to the file. This ensures users see new settings
-- added by script updates without having to delete and regenerate
-- their config.
local function append_missing_settings()
    -- Collect entries whose keys are not yet in the parsed settings
    local missing = {}
    for _, entry in ipairs(DEFAULTS_ORDERED) do
        if entry.key and settings[entry.key] == nil then
            missing[#missing + 1] = entry
        end
    end
    if #missing == 0 then return end

    -- Append the missing entries to the existing file
    local f = io.open(CONFIG_FILE, "a")
    if not f then
        print("WARNING: Could not append new settings to config file: " .. CONFIG_FILE)
        return
    end

    f:write("\n; === Settings added by script update ===\n")
    for _, entry in ipairs(missing) do
        if entry.comment then
            f:write(entry.comment .. "\n")
        end
        if entry.key then
            f:write(entry.key .. "=" .. entry.value .. "\n")
        end
    end
    f:close()
end

-- ============================================================
-- Public API
-- ============================================================

-- load(): Read the config file and populate settings.
-- If the file doesn't exist, creates it with defaults.
-- If the file exists but is missing newer settings, appends them.
-- Call this once at startup (it's called automatically on require).
function M.load()
    local f = io.open(CONFIG_FILE, "r")
    if f then
        -- Config file exists — parse it
        local text = f:read("*all")
        f:close()
        settings = parse_config(text)
        -- Add any settings introduced by newer script versions
        append_missing_settings()
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
