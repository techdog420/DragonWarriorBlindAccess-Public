-- main.lua
-- Dragon Warrior Accessibility Mod — Entry Point
--
-- This is the main script loaded by FCEUX. It runs the core polling loop:
-- every frame we read game state from RAM, compare to the previous frame,
-- and speak any changes through Tolk (screen reader bridge).
--
-- Load in FCEUX: File > Load Lua Script > select this file.
-- Or from command line:
--   qfceux.exe --loadlua=main.lua "Dragon Warrior (USA) (Rev 1).nes"

-- ============================================================
-- Module Loading
-- ============================================================
-- Some launch paths leave FCEUX's current working directory somewhere other
-- than the mod folder. Resolve this script's directory explicitly and prepend
-- it to package.path before the first require() so sibling modules load
-- reliably whether the script is started by command line or through the UI.
local main_source = debug.getinfo(1, "S").source
local main_script_dir = main_source:match("@?(.*[\\/])") or ""
if main_script_dir ~= "" then
    local script_package_path = table.concat({
        main_script_dir .. "?.lua",
        main_script_dir .. "?/init.lua",
    }, ";")
    if not package.path:find(main_script_dir, 1, true) then
        package.path = script_package_path .. ";" .. package.path
    end
end

local tolk = require "tolk"         -- Speech output (Python bridge to screen reader)
local addr = require "addresses"    -- RAM address constants
local battle = require "battle"     -- Battle command menu helpers
local chars = require "chars"       -- Text encoding table
local text = require "text"         -- Screen buffer reading
local nav = require "navigation"    -- Position and map tracking
local state = require "state"       -- Game state detection
local menu = require "menu"         -- Command menu cursor tracking
local config = require "config"     -- User-configurable settings
local objects = require "objects"   -- Map object detection and navigation
local pathfinder = require "pathfinder" -- A* pathfinding for interior maps
local map_reader = require "map_reader" -- ROM map data (tile grids)
local auto_step = require "auto_step"  -- Tap-to-step D-pad extension
local items = require "items"          -- Item/equipment/spell lookup tables
local merchant = require "merchant"    -- Dedicated merchant/shop UI detection
local debug_tools = require "debug_tools"  -- Debug logging and automation (no-op when debug_mode=false)
local path_debug = require "path_debug"    -- Pathfinding debug/test tools (no-op when debug_mode=false)
local map_survey = require "map_survey"    -- Autonomous map/object survey workflow
local snapshot = require "game_snapshot"   -- Centralized per-frame RAM reads
local event_bus = require "event_bus"      -- Pub/sub event system for module decoupling
local route_mgr = require "route_manager" -- Pathfinding coordination, NPC freeze, runtime blocks
local hotkeys   = require "hotkeys"        -- Keyboard hotkey handling

-- Direction constants (kept here for debug diagnostic functions).
local DIR_TO_DELTA = route_mgr.get_dir_to_delta()

local function parse_int_arg(token)
    if not token then return nil end
    token = token:match("^%s*(.-)%s*$")
    if token == "" then return nil end
    if token:match("^[-+]?0[xX][%da-fA-F]+$") then
        return tonumber(token)
    end
    if token:match("^[-+]?%d+$") then
        return tonumber(token)
    end
    return nil
end

local function parse_xy_arg(arg)
    if not arg then return nil end
    local x_s, y_s = arg:match("^%s*([^,]+)%s*,%s*([^,]+)%s*$")
    if not x_s then return nil end
    local x = parse_int_arg(x_s)
    local y = parse_int_arg(y_s)
    if x == nil or y == nil then return nil end
    return x, y
end

local function parse_map_xy_arg(arg, default_map_id)
    if not arg then return nil end
    local a, b, c = arg:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*$")
    if a and b and c then
        local map_id = parse_int_arg(a)
        local x = parse_int_arg(b)
        local y = parse_int_arg(c)
        if map_id == nil or x == nil or y == nil then return nil end
        return map_id, x, y
    end
    local x, y = parse_xy_arg(arg)
    if x == nil then return nil end
    return default_map_id, x, y
end

local function has_directional_block(entry)
    return type(entry) == "table" and next(entry) ~= nil
end

local function blocks_all_approaches(entry)
    return type(entry) == "table"
        and entry.north and entry.south and entry.east and entry.west
end

local function get_block_flags(blocking, x, y, approach)
    -- blocking is the merged table from route_mgr.build_path_blocking(),
    -- which already contains NPC positions ("npc"), static directional
    -- blocks (table), and runtime directional blocks (merged into tables).
    local key = x .. "," .. y
    local entry = blocking and blocking[key] or nil
    local npc_blocked = (entry == "npc")
    local directional_blocked = has_directional_block(entry)
    local approach_blocked = false

    if approach and type(entry) == "table" then
        approach_blocked = (entry[approach] == true)
    end

    return {
        npc_blocked = npc_blocked,
        directional_blocked = directional_blocked,
        approach = approach,
        approach_blocked = approach_blocked,
        fully_blocked = blocks_all_approaches(entry),
    }
end

-- Cardinal names accepted as aliases for joypad keys.
local CARDINAL_TO_KEY = {north = "up", south = "down", east = "right", west = "left"}
local MOVE_DIR_TO_APPROACH = {up = "south", down = "north", left = "east", right = "west"}

local function parse_move_arg(arg, default_x, default_y)
    if not arg then return nil end
    local dir = arg:match("^%s*([%a]+)%s*$")
    if dir then
        dir = dir:lower()
        dir = CARDINAL_TO_KEY[dir] or dir
        if DIR_TO_DELTA[dir] then
            return default_x, default_y, dir
        end
    end
    local x, y, dir2 = arg:match("^%s*(%-?%d+)%s*,%s*(%-?%d+)%s*,%s*([%a]+)%s*$")
    if not x then return nil end
    dir2 = dir2:lower()
    dir2 = CARDINAL_TO_KEY[dir2] or dir2
    if not DIR_TO_DELTA[dir2] then return nil end
    return tonumber(x), tonumber(y), dir2
end

local function build_tile_report(map_id, x, y, blocking, approach)
    local details = map_reader.get_walkability_details(map_id, x, y)
    local tile_type = map_reader.get_tile_type(map_id, x, y)
    local flags = get_block_flags(blocking, x, y, approach)
    local base_walkable = details and details.base_walkable
    local walkable = details and details.effective_walkable
    local permanent_blocked = details and details.permanent_blocked
    local effective_passable = (walkable == true) and not flags.npc_blocked and not flags.approach_blocked
    if approach == nil and flags.fully_blocked then
        effective_passable = false
    end
    return {
        tile_type = tile_type,
        base_walkable = base_walkable,
        walkable = walkable,
        permanent_blocked = permanent_blocked,
        npc_blocked = flags.npc_blocked,
        directional_blocked = flags.directional_blocked,
        blocked_approach = flags.approach,
        approach_blocked = flags.approach_blocked,
        effective_passable = effective_passable,
    }
end

local function log_tile_report(map_id, x, y)
    local blocking = route_mgr.build_path_blocking(map_id)
    local report = build_tile_report(map_id, x, y, blocking)
    local msg = string.format(
        "TILE map=0x%02X x=%d y=%d tile=%s base_walkable=%s walkable=%s permanent_blocked=%s npc_blocked=%s directional_blocked=%s effective_passable=%s",
        map_id, x, y, tostring(report.tile_type), tostring(report.base_walkable),
        tostring(report.walkable), tostring(report.permanent_blocked),
        tostring(report.npc_blocked), tostring(report.directional_blocked),
        tostring(report.effective_passable))
    debug_tools.info(msg)
    return msg
end

local function log_move_report(from_x, from_y, dir)
    local map_id = snapshot.map_id
    local meta = DIR_TO_DELTA[dir]
    if not meta then
        debug_tools.error("MOVE invalid dir: " .. tostring(dir))
        return nil
    end
    local dest_x = from_x + meta.dx
    local dest_y = from_y + meta.dy
    local blocking = route_mgr.build_path_blocking(map_id)
    local approach = MOVE_DIR_TO_APPROACH[dir]
    local report = build_tile_report(map_id, dest_x, dest_y, blocking, approach)
    local msg = string.format(
        "MOVE map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d) tile=%s base_walkable=%s walkable=%s permanent_blocked=%s npc_blocked=%s directional_blocked=%s blocked_approach=%s approach_blocked=%s effective_passable=%s",
        map_id, from_x, from_y, dir, dest_x, dest_y, tostring(report.tile_type),
        tostring(report.base_walkable), tostring(report.walkable),
        tostring(report.permanent_blocked), tostring(report.npc_blocked),
        tostring(report.directional_blocked),
        tostring(report.blocked_approach), tostring(report.approach_blocked),
        tostring(report.effective_passable))
    debug_tools.info(msg)
    return msg, report
end

local edge_probe_state = nil

local function get_edge_probe_source_flags(map_id, x, y, approach)
    local key = x .. "," .. y
    local static_entry = map_reader.get_directional_blocks(map_id)[key]
    local runtime_entry = route_mgr.is_cell_runtime_blocked(map_id, x, y)
    local static_directional_blocked = has_directional_block(static_entry)
    local runtime_directional_blocked = has_directional_block(runtime_entry)
    local static_approach_blocked = false
    local runtime_approach_blocked = false

    if approach and type(static_entry) == "table" then
        static_approach_blocked = (static_entry[approach] == true)
    end
    if approach and type(runtime_entry) == "table" then
        runtime_approach_blocked = (runtime_entry[approach] == true)
    end

    return {
        static_directional_blocked = static_directional_blocked,
        static_approach_blocked = static_approach_blocked,
        runtime_directional_blocked = runtime_directional_blocked,
        runtime_approach_blocked = runtime_approach_blocked,
    }
end

local function log_edge_probe_mismatch(probe, final_report, status)
    if not probe or not probe.start_report then
        return
    end

    local start_report = probe.start_report
    local kind = nil

    if status == "moved" and (start_report.approach_blocked or start_report.effective_passable == false) then
        kind = "moved_through_modeled_block"
    elseif status == "blocked"
        and start_report.permanent_blocked ~= true
        and start_report.npc_blocked ~= true
        and start_report.approach_blocked ~= true
        and start_report.effective_passable == true then
        kind = "blocked_despite_open_preview"
    end

    if not kind then
        return
    end

    local approach = MOVE_DIR_TO_APPROACH[probe.dir]
    local source_flags = get_edge_probe_source_flags(probe.map_id, probe.dest_x, probe.dest_y, approach)
    debug_tools.info(string.format(
        "EDGE_PROBE_MODEL_MISMATCH map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d) kind=%s start_approach_blocked=%s start_effective_passable=%s final_approach_blocked=%s final_effective_passable=%s static_approach_blocked=%s runtime_approach_blocked=%s static_directional_blocked=%s runtime_directional_blocked=%s",
        probe.map_id,
        probe.from_x,
        probe.from_y,
        probe.dir,
        probe.dest_x,
        probe.dest_y,
        kind,
        tostring(start_report.approach_blocked),
        tostring(start_report.effective_passable),
        tostring(final_report.approach_blocked),
        tostring(final_report.effective_passable),
        tostring(source_flags.static_approach_blocked),
        tostring(source_flags.runtime_approach_blocked),
        tostring(source_flags.static_directional_blocked),
        tostring(source_flags.runtime_directional_blocked)))
end

local function edge_probe_timeout_frames()
    local base = tonumber(config.get("auto_step_timeout")) or 45
    -- Probes must outlast auto_step's full blocked-move lifecycle:
    -- the initial attempt, turn re-press, and the internal timeout retries
    -- before auto_step finally publishes route_blocked.
    return (base * 5)
end

local function finish_edge_probe(status, reason)
    local probe = edge_probe_state
    if not probe then
        return
    end
    local map_id, px, py = nav.get_position()
    local blocking = route_mgr.build_path_blocking(probe.map_id)
    local approach = MOVE_DIR_TO_APPROACH[probe.dir]
    local report = build_tile_report(probe.map_id, probe.dest_x, probe.dest_y, blocking, approach)
    local msg = string.format(
        "EDGE_PROBE_RESULT map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d) status=%s final=(%d,%d) tile=%s base_walkable=%s walkable=%s permanent_blocked=%s npc_blocked=%s directional_blocked=%s blocked_approach=%s approach_blocked=%s effective_passable=%s reason=%s",
        probe.map_id,
        probe.from_x,
        probe.from_y,
        probe.dir,
        probe.dest_x,
        probe.dest_y,
        tostring(status),
        px or -1,
        py or -1,
        tostring(report.tile_type),
        tostring(report.base_walkable),
        tostring(report.walkable),
        tostring(report.permanent_blocked),
        tostring(report.npc_blocked),
        tostring(report.directional_blocked),
        tostring(report.blocked_approach),
        tostring(report.approach_blocked),
        tostring(report.effective_passable),
        tostring(reason or ""))
    debug_tools.info(msg)
    log_edge_probe_mismatch(probe, report, status)
    tolk.output_interrupt(string.format(
        "Edge probe %s from %d,%d to %d,%d.",
        tostring(status), probe.from_x, probe.from_y, probe.dest_x, probe.dest_y))
    edge_probe_state = nil
end

local function tick_edge_probe()
    local probe = edge_probe_state
    if not probe then
        return
    end
    local map_id, px, py = nav.get_position()
    probe.frames = probe.frames + 1
    if map_id ~= probe.map_id then
        finish_edge_probe("map_changed", "map_changed")
        return
    end
    if px == probe.dest_x and py == probe.dest_y then
        finish_edge_probe("moved", "position_changed")
        return
    end
    if probe.frames >= edge_probe_timeout_frames() then
        finish_edge_probe("timed_out", "timeout")
    end
end

event_bus.subscribe("route_blocked", function(data)
    local probe = edge_probe_state
    if not probe or not data then
        return
    end
    if data.from_x == probe.from_x and data.from_y == probe.from_y and data.dir == probe.dir then
        finish_edge_probe("blocked", "route_blocked")
    end
end)

local function report_blockers_for_current_map()
    local map_id = snapshot.map_id
    local blocking = objects.get_blocking_positions()
    local runtime = route_mgr.format_runtime_blocks(map_id)
    debug_tools.info(string.format(
        "BLOCKERS map=0x%02X npc_count=%d runtime_count=%d",
        map_id, #blocking, #runtime))
    for _, pos in ipairs(blocking) do
        debug_tools.info(string.format("BLOCKER_NPC map=0x%02X x=%d y=%d", map_id, pos.x, pos.y))
    end
    for _, cell_key in ipairs(runtime) do
        debug_tools.info(string.format("BLOCKER_RUNTIME map=0x%02X cell=%s", map_id, cell_key))
    end
end


-- ============================================================
-- Startup
-- ============================================================
-- Announce that the accessibility mod is loaded and ready.
tolk.output("Dragon Warrior Accessibility Mod loaded.")
FCEU.message("DW Access Mod loaded")

-- NOTE: auto_step.on_blocked and auto_step.on_route_complete callbacks
-- are now set in route_manager.lua (loaded above). They handle re-routing,
-- NPC freeze lifecycle, and runtime block recording.

-- ============================================================
-- Previous-Frame State
-- ============================================================
-- We track values from the previous frame so we only speak when
-- something actually changes. Without this, we'd repeat the same
-- info 60 times per second.

local prev_hp = nil           -- Previous HP (to detect damage/healing)
local prev_mp = nil           -- Previous MP (to detect spell use)
local prev_level = nil        -- Previous level (to detect level-ups)

-- Inventory tracking for chest collection detection.
-- When gold, keys, herbs, or items increase while the player is
-- in field state adjacent to a chest, we mark that chest as opened.
-- Note: "prev_keys" lives in hotkeys.lua. Use distinct names here.
local prev_gold        = nil
local prev_magic_keys  = nil  -- Magic Keys count (addr.KEYS = 0x00BF)
local prev_herbs       = nil
local prev_items       = nil  -- Table of 4 raw item bytes (0x00C1-0x00C4)

-- Startup grace period: skip all change-detection announcements for the
-- first STARTUP_FRAMES frames. This lets all the "previous" values
-- initialize from whatever garbage is in RAM at boot without triggering
-- a flood of false announcements (level-up to 255, lost 255 HP, etc.).
local STARTUP_FRAMES = 120    -- 2 seconds at 60fps
local startup_counter = 0     -- Counts up to STARTUP_FRAMES

-- Dialogue stabilization tracking
-- Dragon Warrior renders text character by character, so we can't read
-- dialogue the instant it changes. Instead, we wait for the text to
-- stop changing (stabilize) before announcing it.
local prev_dialogue = ""        -- Last dialogue text we checked
local announced_dialogue = ""   -- Last dialogue text we actually spoke
local stable_frames = 0         -- How many consecutive checks the text hasn't changed
local STABLE_THRESHOLD = 30     -- Frames of no change before we consider text "done"
                                -- At 60fps, 30 frames = 0.5 seconds of stability
local BATTLE_DIALOGUE_STABLE_THRESHOLD = 14
local BATTLE_DIALOGUE_GRACE_THRESHOLD = 6
local BATTLE_DIALOGUE_GRACE = 120

-- Upper dialogue uses the same stability threshold as lower dialogue.
local UPPER_STABLE_THRESHOLD = 30

-- Upper dialogue tracking (chest messages, shop text, etc.)
-- Some dialogue windows appear in the upper screen area (rows 1-18)
-- instead of the lower area. We track these separately because the
-- status display (name/LV/HP/MP/G/E) is always present in the upper
-- area and must be filtered out.
local prev_upper_dialogue = ""        -- Last upper text we checked
local announced_upper_dialogue = ""   -- Last upper text we actually spoke
local upper_stable_frames = 0         -- Stability counter for upper text
local upper_baseline = ""             -- Status display text when no dialogue active
local upper_dialogue_active = false   -- Is a dialogue window open in the upper region?
local merchant_screen_active = false  -- Dedicated shop/merchant interface mode
local prev_merchant_text = ""         -- Last merchant screen text snapshot
local announced_merchant_text = ""    -- Last merchant screen text we spoke
local prev_merchant_selection = nil   -- Last merchant item selection seen
local prev_merchant_price = nil       -- Last merchant item price seen
local merchant_intro_pending = false  -- Speak "Merchant" prefix on first selection
local merchant_stable_frames = 0      -- Stability counter for merchant screen changes
local MERCHANT_STABLE_THRESHOLD = 12
local submenu_mode = nil              -- nil (normal), "STATUS", or "ITEM"
local game_state = {state = nil}      -- updated once per frame by state.check_for_changes()
local prev_battle_menu_open = false   -- Was the battle command menu open last frame?
local prev_battle_cursor_x = nil      -- Previous battle cursor X
local prev_battle_cursor_y = nil      -- Previous battle cursor Y
local battle_dialogue_grace_frames = 0

-- y≤3 cleaned-text stability tracking.
-- The raw dialogue may oscillate every 8–12 frames due to command-menu cursor
-- blink (tile 0x42 adjacent to uppercase labels). clean_stable_frames tracks
-- how long the UPPERCASE-STRIPPED version has been unchanged. Once stable for
-- STABLE_THRESHOLD frames, announce exactly once — same as the normal path.
local prev_clean_y1       = ""  -- Previous cleaned text at y≤3
local clean_stable_frames = 0   -- How many frames prev_clean_y1 hasn't changed

-- y=1 movement tracking (interior maps only).
-- At map y=1, NES scroll displaces the status bar so our LV/HP checks
-- sometimes can't classify the upper text correctly. The reliable signal
-- is player MOVEMENT: when the player moves at y=1 (or just arrives there),
-- the next stable upper text is background noise/status, not dialogue.
-- NPC dialogue appears while the player is frozen (no x/y movement), so
-- it bypasses baseline absorption and gets announced normally.
local y1_baseline_pending = false  -- true when next stable y=1 text is a baseline
local y1_prev_player_x    = nil    -- player X on the previous frame while at y=1

-- Post-start grace period: after a title→field transition (game load),
-- silently re-initialize change-detection baselines for FIELD_GRACE frames.
-- The game's load sequence takes several frames during which HP may briefly
-- read 0 and map IDs cycle through intermediate values. Without this, those
-- transient values trigger false "Lost 15 HP" / "Charlock Castle" announcements.
local FIELD_GRACE = 90       -- 1.5 seconds at 60fps to let loading complete
local post_start_grace = 0   -- Counts down from FIELD_GRACE when a game starts
local skip_first_hp_check = false  -- Skip one HP/MP check after grace ends

-- Debounce for TITLE→FIELD transition.
-- When backing out of a title sub-menu the screen fades briefly, which clears
-- QUEST/ADVENTUR tiles from the PPU for a few frames. That momentarily makes
-- ppu_shows_title_content() return false while level RAM still holds a value
-- 1-30, causing a false STATE_FIELD for ~5-10 frames. We suppress the "Game
-- started." announcement until FIELD has been stable for FIELD_DEBOUNCE frames.
local FIELD_DEBOUNCE      = 30   -- ~0.5 s; real game loads stay FIELD much longer
local field_from_title_ct = 0    -- counts up while FIELD follows TITLE

-- True when in actual gameplay (STATE_FIELD or STATE_BATTLE).
-- False on STATE_TITLE. Used to gate interior-map guards in
-- check_dialogue() and check_upper_dialogue() so they don't
-- misfire on garbage/uninitialized RAM during the title screen.
local in_gameplay = false

-- Title screen cursor tracker.
-- Tracks which menu item or sub-menu slot the cursor is on and announces
-- it when the cursor settles. Uses a hold-timer (not debounce) to survive
-- cursor blink gaps without letting a stale second cursor take over.
local prev_title_cursor_row = nil  -- last announced cursor row
local prev_title_cursor_col = nil  -- last announced cursor col
local title_stable          = 0
local TITLE_STABLE          = 8    -- frames of stability after cursor_just_moved before announcing

local function get_autowalk_unavailable_reason()
    if game_state.state ~= state.STATE_FIELD then
        return "Auto-walk is only available while walking on the field"
    end
    if debug_tools.is_sweep_active() then
        return "Auto-walk is unavailable during map sweep"
    end
    if path_debug.is_step_mode() then
        return "Finish step mode before auto-walking"
    end
    if menu.is_open() then
        return "Close the command menu before auto-walking"
    end
    if submenu_mode ~= nil then
        return "Close the submenu before auto-walking"
    end
    if merchant_screen_active then
        return "Close the merchant interface before auto-walking"
    end
    if prev_dialogue ~= "" then
        return "Wait for dialogue to finish before auto-walking"
    end
    if upper_dialogue_active then
        return "Wait for the upper dialogue window to clear before auto-walking"
    end
    return nil
end

route_mgr.set_autowalk_guard(function()
    local reason = get_autowalk_unavailable_reason()
    return reason == nil, reason
end)

-- prev_is_name_entry: true when the name-entry alphabet grid is on screen.
-- Tracks transitions so we announce "Name entry." exactly once.
local prev_is_name_entry    = false

-- name_entry_active: sticky flag — once name entry is detected (BACK+END on
-- row 22), stays true until the screen changes (save-slot/speed screen opens,
-- or state leaves TITLE). Prevents the race condition where the cursor settles
-- before row 22 finishes rendering.
local name_entry_active     = false

-- D8/D9 tracking for name entry cursor (bypasses the slow challenger model).
local prev_name_d8          = nil
local prev_name_d9          = nil

-- Name entry symbol lookup: grid positions (D8, D9) that correspond to
-- punctuation symbols need human-readable spoken names.
-- D9=2, D8>=4 are the symbols on the uppercase keyboard row 16.
-- D9=5, D8>=4 are , . and then BACK/END on the lowercase keyboard row 22.
local NAME_ENTRY_SYMBOLS = {
    -- Uppercase row symbols (D9=2, D8=4-9)
    ["4,2"] = "hyphen",
    ["5,2"] = "apostrophe",
    ["6,2"] = "exclamation",
    ["7,2"] = "question mark",
    ["8,2"] = "open paren",
    ["9,2"] = "close paren",
    -- Lowercase row symbols and controls (D9=5, D8=4-7)
    ["4,5"] = "comma",
    ["5,5"] = "period",
    ["6,5"] = "BACK",
    ["9,5"] = "END",
}

-- Text seen on the last no-cursor title frame. Used to announce screens
-- that have no cursor tile (e.g. "PRESS START BUTTON" splash screen).
local prev_title_no_cursor_text = ""
-- Stability counter for no-cursor text (same threshold as cursor path).
local title_no_cursor_stable    = 0

-- Save-slot screen state tracking (BEGIN / CONTINUE / COPY / ERASE paths).
-- All four sub-screens share the same inner-box layout (slots at rows 20/22/24,
-- digit at col 26) and are handled by a single unified handler.
-- Detected by the inner sub-menu box top-left corner tile (0x64) at row 18, col 10.
local save_slot_was_open    = false  -- was save-slot screen open last frame?
local prev_save_slot_d9     = nil    -- D9 value on previous frame (nil = not tracking)

-- Message speed selection state tracking.
-- D9 tracks which speed is selected: 0=FAST (row 22), 1=NORMAL (row 24), 2=SLOW (row 26).
-- Detected by "FAST" bytes at PPU row 22, cols 15-18.
local msg_speed_was_open     = false
local prev_msg_speed_d9      = nil

-- Cursor hold state.
-- Once a cursor is confirmed, we hold that position through blink-off gaps.
-- A different cursor is only accepted after the held cursor has been absent
-- for CURSOR_HOLD consecutive frames, preventing sub-menu cursor blink-off
-- from letting the stale main-menu cursor "steal" the held position.
-- DW1 cursor blink-off is ~12-15 frames; CURSOR_HOLD = 20 provides margin.
--
-- Title-screen cursor tracking uses a "challenger" model:
--
--   cursor_held_row/col: the last accepted cursor position.
--   challenger_row/col/frames: a competing cursor we are watching.
--
--   A challenger must be seen CONSECUTIVELY for CHALLENGER_ACCEPT frames
--   before it displaces the held cursor. Key rule: when the HELD cursor tile
--   is physically on screen, the challenger streak resets to zero. This
--   prevents two independently blinking cursors from oscillating — the held
--   cursor's ~20-frame blink-on period resets any challenger whose streak
--   has not yet reached the threshold.
--
--   CHALLENGER_ACCEPT must satisfy:
--     > blink-off duration (~12-15 frames) — stale cursors never accumulate
--     < blink-on duration  (~20-48 frames) — genuine cursors always succeed
--   18 frames satisfies both constraints with comfortable margin.
local cursor_held_row    = nil
local cursor_held_col    = nil
local cursor_hold_timer  = 0
local CURSOR_HOLD        = 20   -- frames before cursor_present expires on blink-off
local challenger_row     = nil
local challenger_col     = nil
local challenger_frames  = 0    -- consecutive frames challenger has been last-wins
local CHALLENGER_ACCEPT  = 18   -- acceptance threshold (must be > blink-off, < blink-on)

-- Frame counter for throttling periodic checks
-- Some checks don't need to run every frame; we use this to
-- spread work across frames.
local frame_count = 0

-- Sub-menu tracking: STATUS and ITEM screens opened from the command menu.
-- When the player selects STATUS or ITEM, the game opens a sub-menu that
-- reuses the D8/D9 cursor RAM for a different purpose. Without tracking,
-- the command menu handler interprets item cursor positions as command menu
-- items (D9=0 → "TALK", D9=1 → "STATUS", etc.).
--
-- submenu_mode: nil (normal), "STATUS", or "ITEM"
-- prev_cmd_x/y: cursor position on the previous frame, used to detect
--   the single-frame jump from a command menu item to a sub-menu cursor.
-- pending_status_check: if the STATUS PPU signature isn't visible on the
--   exact frame the command menu closes, retry on the next frame.
local prev_cmd_x = nil
local prev_cmd_y = nil

-- Sub-menu tracking state.
local prev_joy_b_status  = false  -- B button tracking for STATUS exit
local prev_joy_a_cmd     = false  -- A button tracking inside check_command_menu
local cmd_menu_confirmed = false  -- true after we announce "Command." (genuine open)
local yesno_status_block_frames = 0  -- brief cooldown after Yes/No dismissal
local cmd_cursor_hold_frames = 0  -- recent visible command-menu cursor
local cmd_last_live_x = nil
local cmd_last_live_y = nil
local cmd_menu_live = false  -- true once a fresh field-menu session is re-armed
local cmd_rearm_required = false  -- blocks stale row-1 menu residue after TALK/YES-NO
local movement_dialogue_hold_frames = 0
local MOVEMENT_DIALOGUE_HOLD = 360
local menu_upper_absorb_frames = 0
local MENU_UPPER_ABSORB = 45
local current_joy = {}
local current_joy_any = false
local recent_field_action_frames = 0
local RECENT_FIELD_ACTION_HOLD = 180

-- Hidden row-1 command diagnostics.
-- Writes compact transition lines to row1_menu_diag.txt so row-1 menu/guard
-- bugs can be inspected without adding spoken noise during play.
local ROW1_TRACE_ENABLED = true
local ROW1_TRACE_FILE = "row1_menu_diag.txt"
local row1_trace_frame = 0
local prev_row1_lower_dialogue_active = false

-- Startup loop diagnostics.
-- When debug_mode=true, capture a few immediate loop markers in a separate
-- file so launcher/debug issues can distinguish "script loaded" from
-- "FCEU.frameadvance() returned and the loop continued".
local STARTUP_LOOP_TRACE_ENABLED = debug_tools.DEBUG_MODE
local STARTUP_LOOP_TRACE_FILE = "startup_loop_diag.txt"

local function should_trace_startup_loop()
    return frame_count <= 3 or frame_count == 60 or frame_count == 120 or frame_count == 180
end

local function trace_startup_loop(event)
    if not STARTUP_LOOP_TRACE_ENABLED or not should_trace_startup_loop() then return end
    local f = io.open(STARTUP_LOOP_TRACE_FILE, "a")
    if f then
        f:write(string.format(
            "frame=%d startup=%d event=%s\n",
            frame_count,
            startup_counter,
            tostring(event)
        ))
        f:close()
    end
end

-- NOTE: Hotkey handling (handle_hotkeys, is_key_pressed, prev_keys) has been
-- extracted to hotkeys.lua. The main loop calls hotkeys.update(keys).


-- ============================================================
-- Automatic Announcements
-- ============================================================
-- These fire automatically when game state changes, without
-- the player pressing any hotkeys.

-- get_scroll_tiles(): Read the NES horizontal scroll offset in NES tile units.
--
-- addr.SCROLL_X holds the PPU $2005 shadow register in PIXELS (0-255).
-- Dividing by 8 converts to NES tile units (0-31) as expected by read_ppu_row.
--
-- Example: at interior map x=8, value = 88 pixels = 11 NES tiles.
-- Dialogue text at screen col 5 + 11 = NT col 16, with chars 17+ overflowing
-- into NT1 ($2400) — the root cause of truncated text at east map edges.
local function get_scroll_tiles()
    if addr.SCROLL_X == nil then return 0 end
    return math.floor(memory.readbyte(addr.SCROLL_X) / 8)
end

-- get_dialogue_start_row(): Compute the nametable row where the dialogue window begins.
--
-- DW1's dialogue window always appears at VISUAL row 19. The NES vertical scroll
-- register (addr.SCROLL_Y = 0x0007) shifts which NAMETABLE row that maps to:
--   nametable_row = (19 + scroll_tiles) % 30
--
-- Empirically confirmed from title_diag data:
--   player y=8:  scroll_px=16,  scroll_tiles=2,  nametable row (19+2)%30 = 21
--   player y=15: scroll_px=128, scroll_tiles=16, first dialogue line at row (19+16)%30 = 5
--               second line at row 6 (matching "there." in the y=15 title_diag)
--   scroll=0:    nametable row 19 (confirmed by guard dump — text at rows 19-21)
--
-- Bug threshold: at player y >= 12, scroll_tiles >= 10, first dialogue row < 19 —
-- outside the old hardcoded 19-29 range, causing silent command menu responses.
local function get_dialogue_start_row()
    local scroll_y_px = snapshot.scroll_y
    return (19 + math.floor(scroll_y_px / 8)) % 30
end

-- check_hp_mp_changes(): Announce HP/MP changes (damage, healing, spell use).
local function check_hp_mp_changes()
    local hp = snapshot.hp
    local mp = snapshot.mp

    -- Battle log already narrates damage/spell results. Suppress the generic
    -- HP/MP delta announcer during battle and the immediate post-battle grace
    -- window so it does not talk over combat dialogue.
    if game_state.state == state.STATE_BATTLE or battle_dialogue_grace_frames > 0 then
        prev_hp = hp
        prev_mp = mp
        return
    end

    -- Only announce after we have a baseline (skip the very first frame)
    if prev_hp ~= nil then
        -- HP decreased: player took damage
        if hp < prev_hp then
            local damage = prev_hp - hp
            tolk.output("Lost " .. damage .. " HP. HP " .. hp)
        -- HP increased: player healed
        elseif hp > prev_hp then
            local healed = hp - prev_hp
            tolk.output("Recovered " .. healed .. " HP. HP " .. hp)
        end
    end

    if prev_mp ~= nil then
        -- MP decreased: spell was cast
        if mp < prev_mp then
            local cost = prev_mp - mp
            tolk.output("Used " .. cost .. " MP. MP " .. mp)
        -- MP increased: MP restored (inn, item)
        elseif mp > prev_mp then
            local restored = mp - prev_mp
            tolk.output("Recovered " .. restored .. " MP. MP " .. mp)
        end
    end

    prev_hp = hp
    prev_mp = mp
end

-- check_level_up(): Announce level-ups.
local function check_level_up()
    local level = snapshot.level
    if prev_level ~= nil and level > prev_level then
        tolk.output("Level up! Now level " .. level)
    end
    prev_level = level
end

-- check_chest_collection(): Detect when the player collects a chest's
-- contents and mark it as opened in the object list.
--
-- Detection: if gold, keys, herbs, or items increase while in field
-- state (not battle) and a chest is within 1 tile of the player,
-- that chest is marked opened. Battle rewards are excluded because
-- they happen in STATE_BATTLE, not STATE_FIELD.
local function check_chest_collection()
    local gold       = snapshot.gold
    local magic_keys = snapshot.keys
    local herbs      = snapshot.herbs
    local cur_items = {
        snapshot.items[1],
        snapshot.items[2],
        snapshot.items[3],
        snapshot.items[4],
    }

    local gained = false
    if prev_gold       ~= nil and gold       > prev_gold       then gained = true end
    if prev_magic_keys ~= nil and magic_keys > prev_magic_keys then gained = true end
    if prev_herbs      ~= nil and herbs      > prev_herbs      then gained = true end
    if prev_items ~= nil then
        for i = 1, 4 do
            if cur_items[i] ~= prev_items[i] then gained = true; break end
        end
    end

    if gained then
        local _, px, py = nav.get_position()
        local nearby = objects.get_nearby_chests(px, py, 1)
        if nearby[1] then
            objects.mark_chest_opened(nearby[1].obj.id)
        end
    end

    prev_gold       = gold
    prev_magic_keys = magic_keys
    prev_herbs      = herbs
    prev_items      = cur_items
end

-- check_map_change(): Announce when the player enters a new area.
local function check_map_change()
    local changes = nav.check_for_changes()
    if changes.position_changed and not changes.map_changed then
        movement_dialogue_hold_frames = MOVEMENT_DIALOGUE_HOLD
    elseif movement_dialogue_hold_frames > 0 then
        movement_dialogue_hold_frames = movement_dialogue_hold_frames - 1
    end

    if changes.map_changed and changes.map_name then
        tolk.output(changes.map_name)
        debug_tools.on_map_change(snapshot.map_id)
        event_bus.publish("map_changed", {map_id = snapshot.map_id})
        -- Clear pathfinding state (target, runtime blocks, NPC freeze).
        route_mgr.on_map_change()
        -- Reset y=1 tracking so the new map establishes a fresh baseline.
        -- Without this, if the player was at y=1 on the previous map with the
        -- same X coordinate as the new map's y=1 position, the arrival check
        -- (player_x ~= y1_prev_player_x) would not fire and the baseline would
        -- never be re-established for the new map's different tile layout.
        y1_prev_player_x    = nil
        y1_baseline_pending = false
    end
end

-- strip_overlap(old, new): Find where new text diverges from old text.
-- Dragon Warrior scrolls the dialogue window, so the new window contents
-- often start with the tail end of the previous page. This function finds
-- that overlap and returns only the genuinely new portion.
--
-- Example:
--   old = "the precious globe and hid it in the darkness."
--   new = "darkness. 'Now, AAAAAAAA, thou must help us..."
--   returns "'Now, AAAAAAAA, thou must help us..."
local function strip_overlap(old, new)
    if old == "" then return new end

    -- Try progressively shorter suffixes of the old text.
    -- If a suffix matches the start of the new text, everything
    -- after that suffix in the new text is genuinely new.
    local found_overlap = false
    for start = 1, #old do
        local suffix = old:sub(start)
        if new:sub(1, #suffix) == suffix then
            found_overlap = true
            local remainder = new:sub(#suffix + 1)
            -- Trim leading spaces from the new portion
            remainder = remainder:match("^%s*(.-)$") or remainder
            if remainder ~= "" then
                return remainder
            end
        end
    end

    -- If a suffix matched but the remainder was always empty, the
    -- entire new text is old content that scrolled within the window.
    -- Nothing genuinely new to announce.
    if found_overlap then
        return ""
    end

    -- No overlap found — the entire new text is new
    return new
end

if ROW1_TRACE_ENABLED then
    local f = io.open(ROW1_TRACE_FILE, "w")
    if f then
        f:write("=== Row 1 command trace ===\n")
        f:close()
    end
end

if STARTUP_LOOP_TRACE_ENABLED then
    local f = io.open(STARTUP_LOOP_TRACE_FILE, "w")
    if f then
        f:write("=== Startup loop trace ===\n")
        f:close()
    end
end

local function is_row1_interior_context()
    if not in_gameplay then return false end
    local py = snapshot.player_y
    return not snapshot.is_overworld and py <= 1
end

local function trace_row1(event, changes, extra)
    if not ROW1_TRACE_ENABLED or not is_row1_interior_context() then return end

    local fields = {
        string.format("f=%d", row1_trace_frame),
        event,
        "open=" .. tostring(menu.is_open()),
        "opened=" .. tostring(changes and changes.menu_opened or false),
        "closed=" .. tostring(changes and changes.menu_closed or false),
        "move=" .. tostring(changes and changes.cursor_moved or false),
        "xy=" .. tostring(changes and changes.cursor_x or "nil") .. "," .. tostring(changes and changes.cursor_y or "nil"),
        "confirmed=" .. tostring(cmd_menu_confirmed),
        "live=" .. tostring(cmd_menu_live),
        "rearm=" .. tostring(cmd_rearm_required),
        "hold=" .. tostring(cmd_cursor_hold_frames),
        "yesno=" .. tostring(menu.is_yesno_active()),
        "yesseen=" .. tostring(menu.yesno_cursor_seen()),
        "block=" .. tostring(yesno_status_block_frames),
        "submenu=" .. tostring(submenu_mode),
    }

    if extra then
        for _, part in ipairs(extra) do
            fields[#fields + 1] = part
        end
    end

    local f = io.open(ROW1_TRACE_FILE, "a")
    if f then
        f:write(table.concat(fields, " | ") .. "\n")
        f:close()
    end
end

local function joypad_has_input(joy)
    return joy.A or joy.B or joy.up or joy.down or joy.left or joy.right
        or joy.start or joy.select
end

local function has_blocking_live_input()
    if not current_joy_any then
        return false
    end
    if auto_step.is_auto_active and auto_step.is_auto_active() then
        return false
    end
    return true
end

local function field_dialogue_guard_active()
    -- This guard is only for passive field play. Post-battle result/status
    -- screens still run under STATE_BATTLE and should be allowed through the
    -- normal dialogue readers when no menu is active.
    if game_state.state ~= state.STATE_FIELD then return false end
    if not in_gameplay then return false end
    if has_blocking_live_input() then return false end
    if menu.is_open() or submenu_mode ~= nil or menu.is_yesno_active() then return false end
    if merchant_screen_active then return false end
    return recent_field_action_frames == 0
end

local function lower_dialogue_stable_threshold(dialogue)
    if dialogue == "" then
        return STABLE_THRESHOLD
    end

    if battle_dialogue_grace_frames > 0 then
        -- Enemy HP drops to 0 before the final combat line fully resolves,
        -- so the game can leave STATE_BATTLE while that line is still on
        -- screen. Once the text looks complete, announce it quickly before
        -- the victory page replaces it.
        if dialogue:find("[a-z]") and dialogue:match("[%.!?]$") then
            return BATTLE_DIALOGUE_GRACE_THRESHOLD
        end
        return BATTLE_DIALOGUE_STABLE_THRESHOLD
    end

    if game_state.state == state.STATE_BATTLE then
        return BATTLE_DIALOGUE_STABLE_THRESHOLD
    end

    return STABLE_THRESHOLD
end

local function reset_merchant_state(sync_dialogue_baselines)
    merchant_screen_active = false
    prev_merchant_text = ""
    announced_merchant_text = ""
    prev_merchant_selection = nil
    prev_merchant_price = nil
    merchant_intro_pending = false
    merchant_stable_frames = 0

    if not sync_dialogue_baselines then
        return
    end

    prev_dialogue = text.read_dialogue_window_filtered(get_scroll_tiles(), get_dialogue_start_row())
    stable_frames = 0

    upper_baseline = text.read_upper_window(get_scroll_tiles())
    prev_upper_dialogue = upper_baseline
    announced_upper_dialogue = upper_baseline
    upper_stable_frames = 0
    upper_dialogue_active = false
end

local function reset_battle_menu_state()
    prev_battle_menu_open = false
    prev_battle_cursor_x = nil
    prev_battle_cursor_y = nil
end

local function check_merchant_screen()
    if not in_gameplay or submenu_mode ~= nil or menu.is_yesno_active() then
        if merchant_screen_active then
            reset_merchant_state(true)
        end
        return false
    end

    local info = merchant.analyze_current_screen()
    if not info.active then
        if merchant_screen_active then
            reset_merchant_state(true)
        end
        return false
    end

    local was_active = merchant_screen_active
    merchant_screen_active = true
    if not was_active then
        merchant_intro_pending = true
    end

    local offer = merchant.get_cursor_offer()
    local selection = offer and offer.name or nil
    local price = offer and offer.price or nil
    if selection and (selection ~= prev_merchant_selection or price ~= prev_merchant_price) then
        prev_merchant_selection = selection
        prev_merchant_price = price
        local msg
        local price_text = price and string.format("%d gold.", price) or nil
        if merchant_intro_pending then
            if price_text then
                msg = string.format("Merchant. Gold %d. %s. %s", snapshot.gold, selection, price_text)
            else
                msg = string.format("Merchant. Gold %d. %s.", snapshot.gold, selection)
            end
            merchant_intro_pending = false
        else
            if price_text then
                msg = string.format("%s. %s", selection, price_text)
            else
                msg = selection
            end
        end
        debug_tools.info("MERCHANT_SELECT: " .. msg)
        tolk.output_interrupt(msg)
        announced_merchant_text = info.raw_text
        merchant_stable_frames = 0
        prev_merchant_text = info.raw_text
        return true
    end

    if info.raw_text ~= prev_merchant_text then
        prev_merchant_text = info.raw_text
        merchant_stable_frames = 0
    else
        merchant_stable_frames = merchant_stable_frames + 1
    end

    if merchant_stable_frames == MERCHANT_STABLE_THRESHOLD
       and info.raw_text ~= announced_merchant_text then
        debug_tools.info("MERCHANT: " .. info.summary)
        tolk.output_interrupt(info.summary)
        announced_merchant_text = info.raw_text
        merchant_intro_pending = false
    end

    return true
end

local function check_battle_menu()
    local changes = menu.check_for_changes()
    local menu_open = menu.is_open()

    if not menu_open then
        prev_battle_menu_open = false
        return
    end

    local cursor_x = changes.cursor_x
    local cursor_y = changes.cursor_y
    local item = battle.get_menu_item(cursor_x, cursor_y)
    local announce = false

    if not prev_battle_menu_open then
        announce = true
    elseif cursor_x ~= prev_battle_cursor_x or cursor_y ~= prev_battle_cursor_y then
        announce = true
    end

    prev_battle_menu_open = true
    prev_battle_cursor_x = cursor_x
    prev_battle_cursor_y = cursor_y

    if not announce then
        return
    end

    if item then
        debug_tools.info("BATTLE_MENU: " .. item)
        tolk.output(item)
    else
        debug_tools.info(string.format("BATTLE_MENU_RAW: x=%s y=%s", tostring(cursor_x), tostring(cursor_y)))
        tolk.output("Battle cursor " .. tostring(cursor_x) .. ", " .. tostring(cursor_y))
    end
end

local function has_visible_cursor_tile()
    for row = 0, 29 do
        local row_start = 0x2000 + row * 32
        for col = 0, 31 do
            local tile = ppu.readbyte(row_start + col)
            if tile == 0x42 or tile == 0x43 then
                return true
            end
        end
    end
    return false
end

-- check_command_menu(): Announce command menu opening, cursor movement,
-- and handle STATUS/ITEM sub-menu transitions.
--
-- Sub-menu detection:
--   STATUS: A is pressed while a confirmed field command menu is open and
--           the cursor is on STATUS(0,1). Suppressed during a Yes/No prompt
--           and for a few frames after it dismisses, because guard 1 reuses
--           the same window and cursor RAM while asking about Princess Gwaelin.
--
--   ITEM:   While the menu is open, cursor jumps from ITEM(1,1) to (0,*)
--           in a single frame with D9 also changing. This can't happen from
--           normal cursor movement since DW1 menus only move one axis per
--           frame. In ITEM mode, D9 tracks the item cursor and we announce
--           item names from the nybble-encoded RAM slots. Exits when D8
--           returns to 1 (back to command menu) or menu closes entirely.
--
-- Guard: When a Yes/No prompt is active, the game reuses the command menu
-- window (same "COMMAND" header, same cursor RAM). Suppress command menu
-- announcements during yes/no prompts.
local function check_command_menu()
    local changes = menu.check_for_changes()

    -- Field command-menu speech must never run outside actual field state.
    -- Battle screens can reuse cursor RAM and window/header patterns that
    -- superficially resemble the field command menu, but they need their own
    -- dedicated reader. Keep menu.check_for_changes() above so menu.lua's
    -- cached state stays fresh, then bail out silently here.
    if game_state.state ~= state.STATE_FIELD then
        cmd_menu_confirmed = false
        cmd_menu_live = false
        cmd_cursor_hold_frames = 0
        return
    end

    -- Merchant/shop layouts can coexist with the same cursor RAM and some of
    -- the same window/header signals the command-menu logic watches. When the
    -- merchant screen is present, it must fully override command-menu speech.
    local merchant_present = merchant_screen_active or merchant.analyze_current_screen().active
    if merchant_present then
        cmd_menu_confirmed = false
        cmd_menu_live = false
        cmd_cursor_hold_frames = 0
        if submenu_mode == "ITEM" or submenu_mode == "STATUS" then
            submenu_mode = nil
        end
        return
    end

    -- Save previous cursor position for transition detection, then update.
    local was_x = prev_cmd_x
    local was_y = prev_cmd_y
    prev_cmd_x = changes.cursor_x
    prev_cmd_y = changes.cursor_y

    -- === STATUS sub-menu mode ===
    -- Stay in STATUS until the command menu re-opens (player pressed B to
    -- return to the command menu) or B is pressed (in case pressing B from
    -- STATUS goes directly to the field on some game versions).
    if submenu_mode == "STATUS" then
        local joy = joypad.read(1)
        local b_just = joy.B and not prev_joy_b_status
        prev_joy_b_status = joy.B
        if changes.menu_opened or b_just then
            submenu_mode = nil
            -- Reset cursor tracking so the first frame back in the command
            -- menu sees a cursor_moved and announces the current position.
            -- Without this, prev_cmd_x/y can match the post-STATUS cursor
            -- values, making the entire next menu session silent.
            prev_cmd_x = nil
            prev_cmd_y = nil
            if changes.menu_opened then
                menu_upper_absorb_frames = MENU_UPPER_ABSORB
                cmd_menu_live = true
                cmd_rearm_required = false
                trace_row1("CMD_OPEN_FROM_STATUS", changes, {})
                tolk.output("Command.")
                debug_tools.on_menu_open()
                event_bus.publish("menu_opened")
            end
        end
        return
    end

    -- === ITEM sub-menu mode ===
    if submenu_mode == "ITEM" then
        if changes.menu_closed then
            -- Entire menu closed (item was used, or player backed out
            -- past the command menu). Exit sub-menu.
            submenu_mode = nil
            menu_upper_absorb_frames = MENU_UPPER_ABSORB
            cmd_menu_live = false
            trace_row1("CMD_CLOSE_FROM_ITEM", changes, {})
            return
        end
        if changes.cursor_moved and changes.cursor_x == 1 then
            -- D8 jumped back to right column → returned to command menu.
            -- Announce the command menu item the cursor landed on.
            submenu_mode = nil
            cmd_menu_live = true
            cmd_rearm_required = false
            local cmd_item = menu.get_menu_item(changes.cursor_x, changes.cursor_y)
            if cmd_item then
                trace_row1("CMD_CURSOR_FROM_ITEM", changes, {
                    "item=" .. cmd_item,
                })
                tolk.output(cmd_item)
            end
            return
        end
        -- Item cursor moved within the list — announce the new item name.
        if changes.cursor_moved then
            trace_row1("ITEM_CURSOR", changes, {
                "item=" .. tostring(items.get_item_at_d9(changes.cursor_y)),
            })
            tolk.output(items.get_item_at_d9(changes.cursor_y))
        end
        return
    end

    -- === Normal command menu handling ===

    -- If a real command menu just opened while the Yes/No hold timer was still
    -- counting down from a blink gap or prior false positive, clear that stale
    -- Yes/No state so the menu can announce normally. Only do this when the
    -- cursor was NOT physically seen before YES/NO on this frame.
    if changes.menu_opened and not menu.yesno_cursor_seen() then
        menu.reset_yesno()
    end

    -- Track A button EVERY frame (even during yes/no) so prev_joy_a_cmd
    -- stays fresh. If we only tracked after the yesno guard, prev_joy_a_cmd
    -- would go stale and produce a false rising-edge when yesno dismisses.
    local joy_a_now = joypad.read(1).A or false
    local a_just = joy_a_now and not prev_joy_a_cmd
    prev_joy_a_cmd = joy_a_now

    -- Yes/No prompt reuses the command menu UI — suppress command menu
    -- announcements while it is active (check_yesno_prompt handles them).
    if menu.is_yesno_active() then
        -- A yes/no prompt is not a real field command menu. Clear the
        -- confirmation flag so the prompt-confirm A press cannot be
        -- misinterpreted as selecting STATUS on the dismissal edge.
        cmd_menu_confirmed = false
        cmd_menu_live = false
        cmd_cursor_hold_frames = 0
        trace_row1("CMD_BLOCK_YESNO", changes, {})
        return
    end

    local lower_dialogue_active = text.read_dialogue_window_filtered(get_scroll_tiles(), get_dialogue_start_row()) ~= ""
    local cursor_visible = has_visible_cursor_tile()

    if is_row1_interior_context() then
        if lower_dialogue_active ~= prev_row1_lower_dialogue_active then
            trace_row1("DIALOGUE_LOWER_" .. (lower_dialogue_active and "ON" or "OFF"), changes, {
                "cursor=" .. tostring(cursor_visible),
            })
        end
        prev_row1_lower_dialogue_active = lower_dialogue_active
    else
        prev_row1_lower_dialogue_active = false
    end

    -- COMMAND text can linger in PPU after the real menu has closed. A visible
    -- cursor tile is the reliable signal that the player is actually in a live
    -- command menu session, so keep a short hold timer to bridge cursor blink.
    if menu.is_open() and cursor_visible then
        cmd_cursor_hold_frames = 12
    elseif cmd_cursor_hold_frames > 0 then
        cmd_cursor_hold_frames = cmd_cursor_hold_frames - 1
    end

    -- STATUS uses the same COMMAND header and cursor coordinates as the field
    -- menu, so only accept it from a confirmed live command-menu session.
    -- Row-1 interiors can produce noisy COMMAND-header matches, so rely on
    -- either a real menu-open A press or a subsequent cursor movement to mark
    -- the session confirmed instead of allowing any bare A press on STATUS.
    local live_x = cmd_last_live_x or changes.cursor_x
    local live_y = cmd_last_live_y or changes.cursor_y
    if a_just and cmd_menu_confirmed and cmd_menu_live
       and yesno_status_block_frames == 0
       and not cmd_rearm_required
       and live_x == 0 and live_y == 1 then
        submenu_mode = "STATUS"
        cmd_menu_confirmed = false
        cmd_menu_live = false
        cmd_cursor_hold_frames = 0
        prev_joy_b_status = false
        menu_upper_absorb_frames = MENU_UPPER_ABSORB
        trace_row1("CMD_STATUS_FIRE", changes, {
            "live_xy=" .. tostring(live_x) .. "," .. tostring(live_y),
            "lower=" .. tostring(lower_dialogue_active),
            "cursor=" .. tostring(cursor_visible),
        })
        tolk.output("Status. " .. items.read_status_string())
        return
    elseif a_just and live_x == 0 and live_y == 1 and cmd_rearm_required then
        trace_row1("CMD_STATUS_GATE_BLOCK", changes, {
            "live_xy=" .. tostring(live_x) .. "," .. tostring(live_y),
            "lower=" .. tostring(lower_dialogue_active),
            "cursor=" .. tostring(cursor_visible),
        })
    end

    -- After TALK or YES/NO, row-1 interiors can leave stale COMMAND/cursor
    -- residue in RAM and the PPU. Require a fresh menu re-arm before treating
    -- any of that state as a live field menu again.
    if cmd_rearm_required and not changes.menu_opened and not changes.cursor_moved then
        trace_row1("CMD_WAIT_REARM", changes, {
            "lower=" .. tostring(lower_dialogue_active),
            "cursor=" .. tostring(cursor_visible),
            "a=" .. tostring(a_just),
        })
        return
    end

    if changes.menu_closed then
        cmd_menu_confirmed = false
        cmd_menu_live = false
        cmd_cursor_hold_frames = 0
        menu_upper_absorb_frames = MENU_UPPER_ABSORB
        trace_row1("CMD_CLOSE", changes, {})
        debug_tools.on_menu_close()
        event_bus.publish("menu_closed")
        return
    end

    -- Detect ITEM sub-menu entry via cursor jump.
    -- Cursor was on ITEM(1,1) and jumped to (0,*) in one frame while menu
    -- stays open. Both D8 and D9 change simultaneously — impossible from
    -- D-pad input (which changes one axis per frame).
    if changes.cursor_moved and was_x == 1 and was_y == 1
       and changes.cursor_x == 0 and changes.cursor_y ~= was_y then
        local count = items.get_item_count()
        if count == 0 then
            -- No items: game will show an error message and return to the
            -- command menu. Don't enter ITEM mode (exit conditions won't
            -- fire because the item list never actually opens).
            trace_row1("CMD_ITEM_EMPTY", changes, {})
            tolk.output("Items. Empty.")
        else
            submenu_mode = "ITEM"
            cmd_menu_live = false
            trace_row1("CMD_ITEM_FIRE", changes, {
                "item=" .. tostring(items.get_item_at_d9(changes.cursor_y)),
            })
            tolk.output("Items. " .. items.get_item_at_d9(changes.cursor_y))
        end
        return
    end

    -- Normal menu opening and cursor movement.
    if changes.menu_opened then
        -- At y<=1 on interior maps, map tile noise in the scrolling nametable
        -- area (rows 6-17) can accidentally contain the "COMMAN" byte sequence
        -- that is_command_menu_open() searches for, producing a spurious
        -- menu-opened event. Suppress the opening announcement; cursor_moved
        -- events still work correctly once the player actually navigates.
        local py  = snapshot.player_y
        if not (not snapshot.is_overworld and py <= 1) then
            -- Menu just opened. Announce "Command." only — DW1 remembers
            -- the last-used cursor position, so the current item is wherever
            -- the cursor was left, not necessarily TALK. The player can press
            -- any direction to hear the current selection via cursor_moved.
            menu_upper_absorb_frames = MENU_UPPER_ABSORB
            cmd_menu_confirmed = true
            cmd_menu_live = true
            cmd_rearm_required = false
            cmd_cursor_hold_frames = math.max(cmd_cursor_hold_frames, 12)
            cmd_last_live_x = changes.cursor_x
            cmd_last_live_y = changes.cursor_y
            trace_row1("CMD_OPEN", changes, {
                "cursor=" .. tostring(cursor_visible),
            })
            tolk.output("Command.")
            debug_tools.on_menu_open()
            event_bus.publish("menu_opened")
        elseif a_just then
            -- North-edge suppression avoids false spoken openings from map-tile
            -- noise, but a real command-menu open confirmed by an A press still
            -- deserves the "Command." announcement so the player knows the menu
            -- is open. False-positive map-tile triggers have a_just=false (no
            -- physical button) so they stay silent; only genuine A presses speak.
            menu_upper_absorb_frames = MENU_UPPER_ABSORB
            cmd_menu_confirmed = true
            cmd_menu_live = true
            cmd_rearm_required = false
            cmd_cursor_hold_frames = 12
            cmd_last_live_x = changes.cursor_x
            cmd_last_live_y = changes.cursor_y
            trace_row1("CMD_OPEN_Y1", changes, {
                "cursor=" .. tostring(cursor_visible),
            })
            tolk.output("Command.")
            debug_tools.on_menu_open()
            event_bus.publish("menu_opened")
        end
    elseif changes.cursor_moved and not changes.menu_closed then
        -- Cursor moved within the open menu — announce the new item.
        -- A real D-pad move inside the menu confirms this is a live menu
        -- session, even in row-1 scroll cases where the opening line itself
        -- was intentionally suppressed.
        cmd_menu_confirmed = true
        cmd_menu_live = true
        cmd_rearm_required = false
        cmd_last_live_x = changes.cursor_x
        cmd_last_live_y = changes.cursor_y
        local item = changes.item_name
        if item then
            trace_row1("CMD_CURSOR", changes, {
                "item=" .. item,
                "lower=" .. tostring(lower_dialogue_active),
                "cursor=" .. tostring(cursor_visible),
            })
            tolk.output(item)
        else
            -- Unknown cursor position — announce raw values so the user
            -- can report them for mapping.
            trace_row1("CMD_CURSOR_RAW", changes, {
                "lower=" .. tostring(lower_dialogue_active),
                "cursor=" .. tostring(cursor_visible),
            })
            tolk.output("Cursor " .. changes.cursor_x .. ", " .. changes.cursor_y)
        end
    end

    -- Selecting TALK consumes the current field-menu session. Row-1 dialogue
    -- and yes/no follow-ups must re-open or move the cursor again before any
    -- later STATUS-like residue is allowed to act as a live menu.
    if a_just and not changes.menu_opened
       and changes.cursor_x == 0 and changes.cursor_y == 0
       and cmd_menu_confirmed then
        cmd_menu_live = false
        cmd_rearm_required = true
        trace_row1("CMD_TALK_FIRE", changes, {
            "cursor=" .. tostring(cursor_visible),
        })
    end
end

-- check_yesno_prompt(): Announce Yes/No prompt appearance and cursor movement.
--
-- Dragon Warrior NPCs sometimes ask yes/no questions ("Dost thou need
-- guidance? YES NO"). The player moves the cursor between YES and NO with
-- the D-pad and confirms with A. Without this function, the cursor change
-- is completely silent since the cursor tile decodes to "" in our text system.
--
-- We call menu.check_yesno_changes() (which also caches the result for
-- check_dialogue()'s guard) and announce:
--   - "YES NO prompt. YES" when the window first appears
--   - "YES" or "NO" when the cursor moves between options
local function check_yesno_prompt()
    local changes = menu.check_yesno_changes()
    if changes.active then
        yesno_status_block_frames = 10
        cmd_menu_live = false
        cmd_rearm_required = true
        trace_row1("YESNO_ACTIVE", nil, {
            "sel=" .. tostring(changes.selection),
        })
    elseif yesno_status_block_frames > 0 then
        yesno_status_block_frames = yesno_status_block_frames - 1
    end

    if changes.just_dismissed then
        cmd_menu_confirmed = false
        cmd_menu_live = false
        cmd_cursor_hold_frames = 0
        cmd_rearm_required = true
        trace_row1("YESNO_DISMISS", nil, {})
    end

    if changes.just_appeared then
        -- On the title screen (e.g. erase-quest confirmation), rows 19-29
        -- contain title menu text, not dialogue. Skip question reading there.
        if in_gameplay then
            -- The guard's question may not have completed its 30-frame
            -- stabilization before the Yes/No window appeared. Read the
            -- lower dialogue area right now and announce any text that
            -- hasn't been spoken yet, so the player hears the question
            -- before the Yes/No prompt. Update announced_dialogue so the
            -- normal dialogue system doesn't repeat it.
            local question = text.read_dialogue_window_filtered(get_scroll_tiles(), get_dialogue_start_row())
            -- Only announce the question if it contains real dialogue text
            -- (at least one lowercase letter). Purely-uppercase strings are either
            -- command menu tiles that haven't been overwritten yet, or the player's
            -- name partially rendered before the rest of the sentence appeared.
            -- The normal dialogue stability path will catch the full text once it
            -- finishes rendering.
            if question ~= "" and question ~= announced_dialogue and question:find("[a-z]") then
                debug_tools.on_dialogue(question)
                event_bus.publish("dialogue_new", {text = question})
                tolk.output(question)
                announced_dialogue = question
            end
        end
        trace_row1("YESNO_APPEAR", nil, {
            "sel=" .. tostring(changes.selection),
        })
        -- Queue the prompt announcement after the question text
        tolk.output("YES NO prompt. " .. (changes.selection or ""))
    elseif changes.selection_changed then
        -- Cursor moved — announce the newly highlighted option.
        trace_row1("YESNO_CURSOR", nil, {
            "sel=" .. tostring(changes.selection),
        })
        tolk.output(changes.selection)
    end
end

-- read_y1_dialogue(): Read the dialogue text rows for player y≤3.
--
-- At y≤3 on interior maps, the NES vertical scroll shifts the dialogue window
-- upward by 2 nametable rows per player y unit below y=4. The response text
-- that normally sits at nametable rows 19-20 (y=4) is instead at:
--   y=3 → rows 17-18       y=2 → rows 15-16       y=1 → rows 13-14
-- Formula: text_row = 11 + 2 * py   (verified from PPU dumps)
--
-- Some messages use a taller window with 4+ text lines, or two stacked
-- sub-windows. At y=1 the guard's final page spans rows 15-19 (text_row=13),
-- so text_row+5 misses row 19. We scan 9 rows (text_row through text_row+8)
-- to cover the full depth of any window variant. The lowercase filter keeps
-- only rows with real text — border tiles and map tiles decode to "" or
-- uppercase and are silently dropped.
local function read_y1_dialogue()
    local py = snapshot.player_y
    -- Clamp so row numbers stay in valid nametable range (0-29).
    local text_row = math.max(0, 11 + 2 * py)
    local lines = {}
    for row = text_row, math.min(29, text_row + 8) do
        local decoded = text.decode_row(row)
        if decoded:find("[a-z]") then
            lines[#lines + 1] = decoded
        end
    end
    return table.concat(lines, " ")
end

-- strip_noise(str): Remove runs of 4+ consecutive zero characters that
-- result from PPU background tiles (CHR index 0x00 → digit "0" in DW1
-- encoding). These appear in large groups on the title screen wherever
-- the nametable is "empty". Actual digit text never has runs that long.
local function strip_noise(str)
    return (str:gsub("0000+", ""):match("^%s*(.-)%s*$") or "")
end


-- decode_row_from_col(row, start_col): Decode PPU nametable tiles on a row
-- starting at start_col, reading through NT0 then NT1. Returns trimmed string.
-- Used to read the item text that follows a cursor tile without including
-- the (empty-decoded) cursor tile itself.
local function decode_row_from_col(row, start_col)
    local bytes = {}
    for col = start_col, 31 do
        bytes[#bytes + 1] = ppu.readbyte(0x2000 + row * 32 + col)
    end
    -- Also read NT1 for text that overflows past column 31.
    for col = 0, 31 do
        bytes[#bytes + 1] = ppu.readbyte(0x2400 + row * 32 + col)
    end
    local t = chars.decode_bytes(bytes)
    return t:match("^%s*(.-)%s*$") or ""
end

-- Title-screen sub-menu detection helpers.
-- Each returns true when its specific screen overlay is visible in the PPU.
--
-- Detection strategy: check a small fixed byte sequence that is unique to
-- each screen and stable (always rendered at the same position).

-- Save-slot sub-screen detection.
-- Save-slot sub-screens come in two layouts depending on the menu option chosen:
--
--   BEGIN A NEW QUEST:
--     Inner box top-left (0x64) at row 18, col 10.
--     Three empty slots displayed at rows 20 / 22 / 24; digit at col 26.
--     D9 (0-2) selects which slot row.
--
--   CONTINUE / COPY / ERASE A QUEST:
--     Inner box top-left (0x64) at row 12, col 6.
--     One slot displayed at row 14; digit at col 22.
--     D9 changes if multiple saves exist; slot row stays 14 (single row in box).
--
-- Returns "begin" or "continue" when a slot screen is open, nil otherwise.
local function save_slot_screen_type()
    -- Require BOTH the box corner tile (0x64) AND a valid slot digit (1-9)
    -- at the expected position. This prevents false positives when other
    -- sub-menus (message speed, etc.) happen to have 0x64 border tiles at
    -- the same positions. Check "continue" first since its box at (12,6)
    -- can overlap with other sub-menu borders.
    if ppu.readbyte(0x2000 + 12 * 32 + 6) == 0x64 then
        local digit = ppu.readbyte(0x2000 + 14 * 32 + 22)
        if digit >= 1 and digit <= 9 then return "continue" end
    end
    if ppu.readbyte(0x2000 + 18 * 32 + 10) == 0x64 then
        local digit = ppu.readbyte(0x2000 + 20 * 32 + 26)
        if digit >= 1 and digit <= 9 then return "begin" end
    end
    return nil
end

-- Message speed screen: options FAST/NORMAL/SLOW at PPU rows 22/24/26.
-- Detect by "FAST" at row 22 cols 15-18.
-- "FAST" = F=0x29 A=0x24 S=0x36 T=0x37.
local FAST_BYTES = {0x29, 0x24, 0x36, 0x37}
local function is_message_speed_open()
    local base = 0x2000 + 22 * 32 + 15
    for i = 1, 4 do
        if ppu.readbyte(base + i - 1) ~= FAST_BYTES[i] then return false end
    end
    return true
end

-- Speed names indexed by D9 value (0=FAST, 1=NORMAL, 2=SLOW).
local SPEED_NAMES = {[0] = "FAST", [1] = "NORMAL", [2] = "SLOW"}

-- announce_adventure_slot(): Read and speak the selected save slot.
-- slot_row: the PPU row containing the slot entry.
-- digit_col: column of the slot-number digit byte (raw DW1 digit 0x01-0x09).
-- Returns false if the slot isn't rendered yet (digit out of range 1-9).
local function announce_adventure_slot(slot_row, digit_col)
    local slot_digit = ppu.readbyte(0x2000 + slot_row * 32 + digit_col)
    -- Guard: 0x5F (space, value 95) appears before the PPU finishes rendering.
    -- Only proceed when the digit byte is a valid slot number (1-9 in DW1).
    if slot_digit < 1 or slot_digit > 9 then return false end
    local row_text = text.decode_row(slot_row)
    -- "ADVENTURE LOG N" is the empty-slot label. If present, just say "Slot N".
    -- Otherwise the row has character info (name, level) — include it.
    if row_text:find("ADVENTURE") then
        tolk.output("Slot " .. slot_digit)
    else
        tolk.output("Slot " .. slot_digit .. ": " .. row_text)
    end
    return true
end

-- check_title_screen(): Title-screen announcer.
--
-- Handles four distinct title-screen contexts in priority order:
--   1. Message speed screen  — D9 tracks FAST/NORMAL/SLOW selection.
--   2. "CONTINUE" adventure log — D9 tracks slot; slots at rows 14/16.
--   3. "BEGIN" adventure log    — D9 tracks slot; slots at rows 20/22.
--   4. Name-entry screen       — first-token of letter under cursor.
--   5. All other title screens — cursor-tile scan with hold-timer.
local function check_title_screen()
    -- Guard: when a Yes/No prompt is active (e.g. erase-quest confirmation),
    -- let check_yesno_prompt() handle it — don't compete with cursor scanning.
    if menu.is_yesno_active() then return end

    -- ---- Message Speed: D9-based speed selection ----
    -- The message speed screen shows FAST/NORMAL/SLOW at PPU rows 22/24/26.
    -- D9 tracks which is selected: 0=FAST, 1=NORMAL, 2=SLOW.
    -- The cursor-tile approach fails (two simultaneous cursors: title menu +
    -- speed option); D9 is instant and reliable.
    local spd_open = is_message_speed_open()
    if spd_open then
        local d9 = snapshot.cursor_y
        if not msg_speed_was_open then
            -- First frame the screen is open: record current selection as baseline
            -- without announcing it. The speed is already selected; the player only
            -- needs to hear it when they actively change it.
            prev_msg_speed_d9 = d9
        elseif d9 ~= prev_msg_speed_d9 then
            prev_msg_speed_d9 = d9
            local speed_name = SPEED_NAMES[d9]
            if speed_name then
                tolk.output(speed_name)
            else
                -- Unexpected D9: read the PPU row directly as fallback.
                local speed_row = 22 + d9 * 2
                local row_text  = text.decode_row(speed_row)
                if row_text ~= "" then tolk.output(row_text) end
            end
        end
        msg_speed_was_open = true
        return
    else
        if msg_speed_was_open then prev_msg_speed_d9 = nil end
        msg_speed_was_open = false
    end

    -- ---- Save-slot screen: unified handler for BEGIN / CONTINUE / COPY / ERASE ----
    -- BEGIN uses the bottom inner box (row 18, col 10); slots at rows 20/22/24, digit col 26.
    -- CONTINUE/COPY/ERASE use the top inner box (row 12, col 6); slot at row 14, digit col 22.
    local slot_type = save_slot_screen_type()
    local slot_open = (slot_type ~= nil)
    if slot_open then
        local d9 = snapshot.cursor_y
        if d9 ~= prev_save_slot_d9 then
            local slot_row, digit_col
            if slot_type == "begin" then
                slot_row  = 20 + d9 * 2
                digit_col = 26
            else
                -- CONTINUE / COPY / ERASE: inner box has slot rows at 14 and 16.
                -- D9 selects which slot: D9=0 → row 14, D9=1 → row 16.
                slot_row  = 14 + d9 * 2
                digit_col = 22
            end
            -- Only announce when the slot digit is valid (1-9). If the PPU
            -- hasn't rendered it yet, prev_save_slot_d9 stays nil and we
            -- retry next frame. No fallback to raw row text — that reads
            -- stale main-menu text before the slot content renders.
            if announce_adventure_slot(slot_row, digit_col) then
                prev_save_slot_d9 = d9
            end
        end
        save_slot_was_open = true
        return
    else
        if save_slot_was_open then prev_save_slot_d9 = nil end
        save_slot_was_open = false
    end

    -- Detect name-entry screen: row 22 uniquely contains BACK and END.
    -- We only need a small region for this; avoid reading all 30 rows.
    local row22 = text.decode_row(22)
    local is_name_entry = (row22:find("BACK") ~= nil and row22:find("END") ~= nil)

    -- Sticky name_entry_active: once detected, stays true until the screen
    -- changes. This prevents the race condition where the cursor settles
    -- before row 22 finishes rendering (BACK/END not yet present).
    if is_name_entry then
        name_entry_active = true
    end

    -- Announce name-entry context once on transition into it.
    if is_name_entry and not prev_is_name_entry then
        tolk.output("Name entry. Arrow keys to select letter, BACK to delete, END to finish.")
        -- Initialize D8/D9 tracking so the first cursor position is announced.
        prev_name_d8 = nil
        prev_name_d9 = nil
    end
    prev_is_name_entry = is_name_entry

    -- ---- Name entry: D8/D9-based cursor (instant, no challenger delay) ----
    -- When name_entry_active, read cursor position directly from D8/D9 RAM.
    -- This bypasses the 26-frame challenger model entirely, giving instant
    -- response to arrow key presses.
    if name_entry_active then
        local d8 = snapshot.cursor_x
        local d9 = snapshot.cursor_y
        if d8 ~= prev_name_d8 or d9 ~= prev_name_d9 then
            prev_name_d8 = d8
            prev_name_d9 = d9

            -- Check symbol lookup first (symbols need spoken names)
            local sym_key = d8 .. "," .. d9
            local sym_name = NAME_ENTRY_SYMBOLS[sym_key]
            if sym_name then
                tolk.output(sym_name)
            else
                -- Read the letter/text from the PPU grid.
                -- Grid layout: PPU row = 12 + d9 * 2, column = 6 + d8 * 2.
                local ppu_row = 12 + d9 * 2
                local ppu_col = 6 + d8 * 2
                local byte_val = ppu.readbyte(0x2000 + ppu_row * 32 + ppu_col)
                local ch = chars.decode_byte(byte_val)

                if ch and ch ~= "" and ch ~= " " then
                    -- Single letter: add "cap " prefix for uppercase keyboard
                    if d9 <= 2 then
                        tolk.output("cap " .. ch)
                    else
                        tolk.output(ch)
                    end
                else
                    -- Cursor tile or unmapped byte at position: read the text
                    -- after cursor using the PPU row decode (for BACK/END etc.)
                    local row_text = decode_row_from_col(ppu_row, ppu_col + 1)
                    local token = row_text:match("^%s*(%S+)") or row_text
                    if token ~= "" then
                        tolk.output(token)
                    end
                end
            end
        end
        return  -- Skip the challenger model entirely during name entry
    end

    -- Scan all PPU rows for cursor tiles (0x42 or 0x43).
    -- Last-wins: bottom-most cursor is treated as the active one.
    -- When a sub-menu is open, the main-menu cursor (higher on screen)
    -- and the sub-menu cursor (lower) are both visible; we want the lower.
    local cursor_row, cursor_col = nil, nil
    for row = 0, 29 do
        for col = 0, 31 do
            local tile = ppu.readbyte(0x2000 + row * 32 + col)
            if tile == 0x42 or tile == 0x43 then
                cursor_row, cursor_col = row, col
                break
            end
        end
    end

    -- Cursor acceptance: consecutive challenger model.
    --
    -- When the held cursor tile is physically on screen: refresh the hold
    -- timer and reset the challenger streak to 0.
    -- When a different cursor is on screen: increment its consecutive streak.
    -- If the streak reaches the acceptance threshold, that cursor becomes the
    -- new held cursor.
    -- During blink-off (no cursor visible): count down the hold timer but
    -- leave the challenger streak unchanged (blink gaps don't reset progress).
    --
    -- Acceptance threshold: when cursor_held_row is nil (no held cursor, fresh
    -- menu open), use a reduced threshold (3 frames) since there's no competing
    -- cursor to protect against. When displacing an existing held cursor, use
    -- the full CHALLENGER_ACCEPT (18 frames) for anti-oscillation.
    local accept_threshold = (cursor_held_row == nil) and 3 or CHALLENGER_ACCEPT
    if cursor_row ~= nil then
        if cursor_row == cursor_held_row and cursor_col == cursor_held_col then
            -- Held cursor tile physically present: refresh timer, reset challenger.
            cursor_hold_timer = CURSOR_HOLD
            challenger_row    = nil
            challenger_col    = nil
            challenger_frames = 0
        else
            -- A different cursor is visible: advance consecutive streak.
            if cursor_row == challenger_row and cursor_col == challenger_col then
                challenger_frames = challenger_frames + 1
            else
                -- New position: start a fresh streak.
                challenger_row    = cursor_row
                challenger_col    = cursor_col
                challenger_frames = 1
            end
            if challenger_frames >= accept_threshold then
                cursor_held_row   = challenger_row
                cursor_held_col   = challenger_col
                cursor_hold_timer = CURSOR_HOLD
                challenger_row    = nil
                challenger_col    = nil
                challenger_frames = 0
            end
            -- Keep cursor_present alive while challenger accumulates.
            if cursor_hold_timer > 0 then
                cursor_hold_timer = cursor_hold_timer - 1
            end
        end
    else
        -- Blink-off: pause challenger streak, count down timer.
        if cursor_hold_timer > 0 then
            cursor_hold_timer = cursor_hold_timer - 1
        end
    end

    -- cursor_just_moved: held cursor settled at a new position.
    -- Update prev immediately so this only fires once per move.
    local cursor_present    = (cursor_hold_timer > 0)
    local cursor_just_moved = cursor_present
                              and (cursor_held_row ~= prev_title_cursor_row
                                   or cursor_held_col ~= prev_title_cursor_col)

    if cursor_just_moved then
        title_stable          = 0
        prev_title_cursor_row = cursor_held_row
        prev_title_cursor_col = cursor_held_col
    else
        title_stable = title_stable + 1
    end

    -- Announce after a brief stability wait to let the cursor row finish rendering.
    if title_stable == TITLE_STABLE and prev_title_cursor_row then
        local item = decode_row_from_col(prev_title_cursor_row, prev_title_cursor_col + 1)
        -- Fall back to the full row when the post-cursor text has no letters
        -- (e.g. cursor sits between "ADVENTURE LOG " and "1").
        if not item:find("[a-zA-Z]") then
            item = text.decode_row(prev_title_cursor_row)
        end
        if item ~= "" then
            tolk.output(item)
        end
    end

    -- No-cursor fallback: announce screens that have no cursor tile at all
    -- (e.g. "PRESS START BUTTON" splash). Only fires when:
    --   • no cursor is held (cursor_hold_timer expired)
    --   • no cursor is being tracked as a challenger (challenger_frames == 0)
    --   • not in name entry (handled separately)
    -- The challenger_frames guard prevents this from firing during the normal
    -- cursor acceptance window (18 frames) when a menu first opens — without
    -- it, the fallback reads all screen text as a block announcement before
    -- the cursor is officially accepted.
    if not cursor_present and cursor_held_row == nil
       and challenger_frames == 0 and not is_name_entry then
        -- Collect rows that contain at least one letter (upper or lower).
        -- Apply strip_noise to remove runs of zeros from empty PPU tiles
        -- (CHR tile 0x00 = digit '0') before checking for letter content.
        local lines = {}
        for row = 0, 29 do
            local line = strip_noise(text.decode_row(row)):match("^%s*(.-)%s*$")
            if line ~= "" and line:find("[a-zA-Z]") then
                lines[#lines + 1] = line
            end
        end
        local full_text = table.concat(lines, " ")
        if full_text == prev_title_no_cursor_text then
            title_no_cursor_stable = title_no_cursor_stable + 1
        else
            prev_title_no_cursor_text = full_text
            title_no_cursor_stable    = 0
        end
        if title_no_cursor_stable == TITLE_STABLE and full_text ~= "" then
            tolk.output(full_text)
            -- Reset so we don't re-announce the same static screen every frame.
            title_no_cursor_stable = title_no_cursor_stable + 1
        end
    else
        -- Cursor is present (or name-entry): reset no-cursor tracking.
        prev_title_no_cursor_text = ""
        title_no_cursor_stable    = 0
    end

end

-- check_dialogue(): Read dialogue window and announce when text changes.
-- Dragon Warrior renders text one character at a time, so we wait until
-- the text stops changing for STABLE_THRESHOLD frames before announcing.
-- This prevents reading partial text like "The Dragonl" mid-render.
-- When text does stabilize, we strip any overlap with the previous
-- announcement so we only speak genuinely new text.
--
-- At low Y positions on interior maps, the command-menu window overlaps rows
-- 19-29 due to NES vertical scroll. The cursor tile blinks between 0x42
-- (empty) and 0x5F (space) adjacent to uppercase border tiles, producing a
-- 1-space frame-to-frame difference that prevents raw stability from ever
-- being reached. Empirically this affects player rows 1-3; row 4 and below
-- are unaffected (scroll pushes the menu window clear of rows 19-29).
-- Fix: strip runs of 3+ consecutive uppercase letters (and adjacent spaces)
-- before comparing. This normalizes both cursor-blink states to the same
-- string. We then apply the SAME STABLE_THRESHOLD to the cleaned text —
-- the cleaned text IS stable even during cursor blink, so the threshold is
-- reached and the announcement fires exactly once. This prevents the
-- per-character "ki…kid…kidnap…" chatter from the old per-change approach.
local function check_dialogue()
    local py  = snapshot.player_y
    local at_y1 = in_gameplay and not snapshot.is_overworld and py <= 3

    -- Use the filtered reader for ALL y positions: it applies a per-row
    -- lowercase filter to exclude status bar fragments (uppercase "E", "G",
    -- digits) that bleed into rows 19-29 at certain NES scroll positions.
    local dialogue = text.read_dialogue_window_filtered(get_scroll_tiles(), get_dialogue_start_row())
    local battle_dialogue_mode = (game_state.state == state.STATE_BATTLE or battle_dialogue_grace_frames > 0)
    if battle_dialogue_mode then
        dialogue = battle.normalize_dialogue(dialogue)
    end
    local lower_dialogue_visible = (dialogue ~= "")
    local stable_threshold = lower_dialogue_stable_threshold(dialogue)

    if (field_dialogue_guard_active() and not lower_dialogue_visible) or
       (movement_dialogue_hold_frames > 0 and not has_blocking_live_input() and not menu.is_open()
        and submenu_mode == nil and not menu.is_yesno_active()) then
        prev_dialogue = dialogue
        stable_frames = 0
        if at_y1 then
            local y1_dialogue = read_y1_dialogue()
            local clean = y1_dialogue:gsub("[%s]*[A-Z][A-Z][A-Z]+[%s]*", "")
            prev_clean_y1 = clean:match("^%s*(.-)%s*$") or ""
            clean_stable_frames = 0
        end
        return
    end

    if at_y1 then
        -- Use the lowercase-only row filter so command-menu tiles and NT1 noise
        -- are excluded before computing clean. read_y1_dialogue() keeps only
        -- rows with at least one lowercase letter — these are the rows with real
        -- response text. Then strip any remaining uppercase runs (e.g., if a row
        -- mixes a command label with part of the response on the same line).
        local y1_dialogue = read_y1_dialogue()
        local clean = y1_dialogue:gsub("[%s]*[A-Z][A-Z][A-Z]+[%s]*", "")
        clean = clean:match("^%s*(.-)%s*$") or ""

        -- Track stability of the cleaned text.
        -- The raw dialogue oscillates (cursor blink), but clean is stable.
        if clean ~= prev_clean_y1 then
            clean_stable_frames = 0
            prev_clean_y1 = clean
        else
            clean_stable_frames = clean_stable_frames + 1
        end

        -- Announce once after the cleaned text has been stable for STABLE_THRESHOLD
        -- frames. This prevents the per-character "ki … kid … kidnap …" chatter.
        if clean_stable_frames >= stable_threshold then
            if clean:find("[a-z]") and clean ~= announced_dialogue then
                -- Real response text or NPC dialogue — announce only the new portion.
                -- DW1 scrolls the dialogue window so successive windows share a
                -- tail/prefix boundary. strip_overlap prevents re-announcing the
                -- question that already appeared at the top of the next window.
                local new_text
                if battle_dialogue_mode then
                    new_text = battle.extract_new_text(announced_dialogue, clean)
                else
                    new_text = strip_overlap(announced_dialogue, clean)
                end
                if new_text ~= "" then
                    if not battle_dialogue_mode or battle.is_coherent_dialogue(new_text) then
                        debug_tools.on_dialogue(new_text)
                        event_bus.publish("dialogue_new", {text = new_text})
                        -- Battle pages should always queue in order. Field/NPC
                        -- dialogue keeps the old first-page interrupt behavior so
                        -- menu speech is cleared immediately when talk text opens.
                        if battle_dialogue_mode then
                            tolk.output(new_text)
                        elseif announced_dialogue == "" then
                            tolk.output_interrupt(new_text)
                        else
                            tolk.output(new_text)
                        end
                        announced_dialogue = clean
                    end
                end
            elseif not clean:find("[a-z]") and announced_dialogue ~= "" then
                -- No lowercase: command menu noise — reset for next real text.
                announced_dialogue = ""
            end
        end

        -- Keep raw stable_frames/prev_dialogue in sync so the normal path
        -- picks up cleanly when the player moves from y≤3 to y>3.
        if dialogue ~= prev_dialogue then
            stable_frames = 0
            prev_dialogue = dialogue
        else
            stable_frames = stable_frames + 1
        end
        return
    end

    -- Normal path (y>1): wait for STABLE_THRESHOLD frames of no change.
    if dialogue ~= prev_dialogue then
        -- Text is still changing — reset the stability counter
        stable_frames = 0
        prev_dialogue = dialogue
    else
        -- Text hasn't changed since last check — increment stability counter
        stable_frames = stable_frames + 1
    end

    -- Once text has been stable long enough and differs from what we
    -- already announced, speak only the new portion.
    if stable_frames >= stable_threshold then
        if dialogue ~= "" and dialogue ~= announced_dialogue then
            -- Absorb purely-uppercase text (command menu tiles, map tiles)
            -- without announcing — same principle as the at_y1 uppercase filter.
            -- Real NPC dialogue always contains at least one lowercase letter.
            if not dialogue:find("[a-z]") then
                announced_dialogue = dialogue
            else
                local new_text
                if battle_dialogue_mode then
                    new_text = battle.extract_new_text(announced_dialogue, dialogue)
                else
                    new_text = strip_overlap(announced_dialogue, dialogue)
                end
                if new_text ~= "" then
                    if not battle_dialogue_mode or battle.is_coherent_dialogue(new_text) then
                        debug_tools.on_dialogue(new_text)
                        event_bus.publish("dialogue_new", {text = new_text})
                        if battle_dialogue_mode then
                            tolk.output(new_text)
                        elseif announced_dialogue == "" then
                            tolk.output_interrupt(new_text)
                        else
                            tolk.output(new_text)
                        end
                        announced_dialogue = dialogue
                    end
                end
            end
        elseif dialogue == "" and announced_dialogue ~= "" then
            -- Keep the last announced battle page through the short
            -- post-battle grace window so stale lower-window leftovers do not
            -- re-announce as a fresh reward fragment after the window clears.
            if not battle_dialogue_mode then
                announced_dialogue = ""
            end
        end
    end
end

-- check_upper_dialogue(): Detect and announce dialogue windows that
-- appear in the upper screen area (rows 1-18).
--
-- The upper screen normally shows the status display (name, LV, HP,
-- MP, G, E) which is always present during field gameplay. When a
-- dialogue window opens (chest message, shop text, etc.), it either:
--   (a) Replaces the status display (the NES overwrites those PPU tiles)
--   (b) Appears alongside/below the status display (additional content)
--
-- We distinguish between status display and dialogue by:
--   - Checking for "LV" and "HP" markers that the status display contains
--   - Checking if the text length exceeds what's expected for just stats
-- When the status display is replaced by dialogue, those markers vanish.
-- When dialogue appears alongside, the total text length exceeds ~50 chars.
local function check_upper_dialogue()
    -- Command-menu open/close redraws can leave the status bar or menu text in
    -- transitional states that look like fresh upper dialogue. Absorb the
    -- current upper text into the baseline for a short window around those
    -- transitions so normal status text is never announced as dialogue.
    if menu.is_open() or menu_upper_absorb_frames > 0 then
        local upper = text.read_upper_window(get_scroll_tiles())
        upper_baseline = upper
        prev_upper_dialogue = upper
        announced_upper_dialogue = upper
        upper_stable_frames = 0
        upper_dialogue_active = false
        if menu_upper_absorb_frames > 0 then
            menu_upper_absorb_frames = menu_upper_absorb_frames - 1
        end
        return
    end

    -- Auto-walk drives directional input across many frames. In the throne room
    -- this can make the upper PPU rows flicker through transient status/map
    -- redraw states that are not real dialogue, but can still satisfy the upper
    -- dialogue classifier for a frame and cancel the route. While an auto-walk
    -- route is active, treat upper-window changes as baseline-only noise.
    if auto_step.is_route_active and auto_step.is_route_active() then
        local upper = text.read_upper_window(get_scroll_tiles())
        upper_baseline = upper
        prev_upper_dialogue = upper
        announced_upper_dialogue = upper
        upper_stable_frames = 0
        upper_dialogue_active = false
        return
    end

    if field_dialogue_guard_active() or
       (movement_dialogue_hold_frames > 0 and not has_blocking_live_input() and submenu_mode == nil
        and not menu.is_yesno_active()) then
        local upper = text.read_upper_window(get_scroll_tiles())
        upper_baseline = upper
        prev_upper_dialogue = upper
        upper_stable_frames = 0
        upper_dialogue_active = false
        return
    end

    -- y=1 movement tracking for interior maps.
    -- Update the pending-baseline flag every frame so it reflects current
    -- player movement even during the upper-text stability wait period.
    if in_gameplay and not snapshot.is_overworld then
        local player_y = snapshot.player_y
        if player_y <= 1 then
            local player_x = snapshot.player_x
            if player_x ~= y1_prev_player_x then
                -- Player moved (or just arrived at y=1). The next stable upper
                -- text is status bar noise, not dialogue — mark for absorption.
                y1_baseline_pending = true
            end
            y1_prev_player_x = player_x
        else
            -- Player moved above y=1; reset y=1 tracking state.
            y1_baseline_pending = false
            y1_prev_player_x    = nil
        end
    end

    local upper = text.read_upper_window(get_scroll_tiles())

    -- Guard 1's post-Yes/No reply continues in the LOWER dialogue window while
    -- the status bar remains visible above it. In that state, the upper scan can
    -- misclassify the status bar as fresh upper-window dialogue and speak the
    -- full stats. When real lower dialogue text is present, prefer it and treat
    -- the current upper text as baseline-only content.
    local lower_dialogue = text.read_dialogue_window_filtered(get_scroll_tiles(), get_dialogue_start_row())
    if lower_dialogue ~= "" then
        upper_baseline = upper
        prev_upper_dialogue = upper
        announced_upper_dialogue = upper
        upper_stable_frames = 0
        upper_dialogue_active = false
        return
    end

    -- Track changes with stabilization (same approach as lower dialogue)
    if upper ~= prev_upper_dialogue then
        upper_stable_frames = 0
        prev_upper_dialogue = upper
    else
        upper_stable_frames = upper_stable_frames + 1
    end

    -- Only process once text has stabilized for the upper-window threshold.
    -- This is longer than the lower-dialogue threshold to allow the status
    -- bar (which redraws incrementally after player stops moving) to fully
    -- render before we inspect it. See UPPER_STABLE_THRESHOLD above.
    if upper_stable_frames ~= UPPER_STABLE_THRESHOLD then return end

    -- y=1 baseline absorption: if the player moved while at y=1, absorb this
    -- stable text as the new baseline without announcing it. The player is
    -- frozen during NPC dialogue, so dialogue text reaches here with
    -- y1_baseline_pending = false and gets announced normally.
    --
    -- IMPORTANT: set announced_upper_dialogue = upper (not ""). If we used "",
    -- the command menu's upper_stable_frames reset would cause the SAME noise
    -- to be re-processed 30 frames after the menu closes and look "new" (since
    -- announced is "" but upper is non-empty). Marking it as already-processed
    -- prevents that re-announcement. NPC dialogue is different text, so it still
    -- triggers normally when the player is stationary and upper text changes.
    if y1_baseline_pending then
        upper_baseline = upper
        upper_dialogue_active = false
        announced_upper_dialogue = upper  -- mark as processed, not ""
        y1_baseline_pending = false
        return
    end

    -- At y<=1 on interior maps, nametable rows 1-18 contain ONLY:
    --   - Status bar rows (rows 0-5, some may be within 1-18)
    --   - The NES map area (rows 6-17): north-wall tiles that have CHR
    --     indices in the text character range (0x00-0x5F) and decode as
    --     letters. Stone/wall tiles often use 0x24-0x2C which decode as
    --     uppercase A-L. These look identical to text but are not dialogue.
    --   - Possibly command menu item columns (rows 1-5, right side) but NOT
    --     the "COMMAND" header, which is at nametable rows 27-28 (outside
    --     rows 1-18 at y=1 with scroll=0).
    -- Real NPC dialogue in DW1 ALWAYS renders in the lower window (rows
    -- 18-27) and is handled by check_lower_dialogue. Nothing in rows 1-18
    -- at y=1 is ever genuine dialogue — absorb unconditionally.
    if in_gameplay and not snapshot.is_overworld and snapshot.player_y <= 1 then
        upper_baseline = upper
        announced_upper_dialogue = upper
        upper_dialogue_active = false
        return
    end

    -- If the current text exactly matches the known baseline (e.g., after NPC
    -- dialogue ends and the screen returns to its pre-dialogue state), treat it
    -- as baseline content. Reset dialogue tracking so the next real change is
    -- caught cleanly, without announcing the return-to-baseline itself.
    if upper == upper_baseline then
        if upper_dialogue_active then
            upper_dialogue_active = false
            announced_upper_dialogue = upper
        end
        return
    end

    -- Also check for command menu text. After the menu closes, its tiles
    -- may linger in the PPU for several frames. We search for "COMMAN"
    -- (6-char prefix) rather than "COMMAND" because near the east map edge
    -- (player at x=8) the trailing 'D' wraps to the next nametable row and
    -- is absent from the decoded text. "COMMAN" matches both the full and
    -- truncated form. It only appears as the menu window title.
    local has_menu_text = upper:find("COMMAN") ~= nil

    if has_menu_text then
        -- Stale command menu — not dialogue.
        if upper_dialogue_active then
            upper_dialogue_active = false
            -- Use `upper` (not "") so the same NPC dialogue text does not look
            -- "new" when the menu disappears and the text reverts to just
            -- the dialogue portion. If we used "" here, the dialogue would
            -- re-announce itself after every command menu open/close cycle.
            announced_upper_dialogue = upper
        end
        return
    end

    -- Extract the genuinely new text. Strategy depends on whether the
    -- status display is still visible alongside the dialogue.
    local has_status_markers = text.is_status_text(upper)
    local new_text
    if has_status_markers then
        -- Status display still visible + extra dialogue content.
        -- Strip the known status baseline to get just the dialogue.
        new_text = strip_overlap(upper_baseline, upper)
    else
        -- Status display was entirely replaced by the dialogue window.
        -- The entire upper text is dialogue content.
        new_text = upper
    end

    -- Status-only content with no new text after removing the baseline.
    -- This keeps the baseline fresh without suppressing real upper-window
    -- dialogue that happens to include the status bar markers.
    if has_status_markers and new_text == "" then
        upper_baseline = upper
        if upper_dialogue_active then
            upper_dialogue_active = false
            announced_upper_dialogue = upper
        end
        return
    end

    -- If stripping the baseline didn't help (no overlap found, returned
    -- the full text including status), and we have a previous announcement,
    -- try stripping that instead to find just the NEW portion.
    if new_text == upper and announced_upper_dialogue ~= "" then
        new_text = strip_overlap(announced_upper_dialogue, upper)
    end

    -- Filter: suppress announcements that contain no lowercase letters.
    --
    -- Real DW1 dialogue always uses mixed case — lowercase body text with
    -- uppercase proper nouns/labels (e.g. "Thou hast found the KEY!").
    -- Uppercase-only strings are one of three false-positive sources:
    --   1. Map tile noise: CHR tile indices for wall/floor graphics near the
    --      north map edge (player at y=1) fall in the text character range
    --      and decode as letters like 'A' (tile index 0x24). These tiles
    --      appear in PPU rows 1-18 and look like text to read_upper_window().
    --   2. Lingering command menu text: after the menu closes, tiles for
    --      TALK, STATUS, STAIRS, SEARCH, etc. may persist in the PPU for
    --      a frame or two before the game clears them.
    --   3. Status bar labels: HP, MP, LV, G, E — always uppercase, never
    --      counted as dialogue (already filtered by is_just_status above,
    --      but belt-and-suspenders here).
    -- If new_text is non-empty but has zero lowercase letters, treat it as
    -- noise and absorb it into the baseline so it doesn't re-trigger.
    if new_text ~= "" and not new_text:find("[a-z]") then
        if has_status_markers then
            upper_baseline = upper
        end
        -- Mark as processed (not "") so the next stabilization with the same
        -- text is caught by the "upper == announced_upper_dialogue" check and
        -- skips the full classification pipeline, rather than re-running all
        -- filters on identical content.
        announced_upper_dialogue = upper
        upper_dialogue_active = false
        return
    end

    -- Skip if we already announced this exact text
    if upper == announced_upper_dialogue then
        upper_dialogue_active = false
        return
    end

    -- Real dialogue detected — mark the window as active.
    upper_dialogue_active = true

    if new_text ~= "" then
        debug_tools.on_dialogue(new_text)
        event_bus.publish("dialogue_new", {text = new_text})
        tolk.output_interrupt(new_text)
    end
    announced_upper_dialogue = upper
end

-- NOTE: Pathfinding functions (build_pathfind_message, plan_path_to_object,
-- queue_path_steps, pathfind_to_current, autowalk_to_current) have been
-- extracted to route_manager.lua.

-- ============================================================
-- Remote Command Registrations
-- ============================================================
-- These commands can be triggered by writing to dw_commands.txt,
-- e.g.:  echo next_object > dw_commands.txt
-- or via the wrapper script:  ./dw_commands.sh next_object
--
-- Requires debug_mode=true in dw_access.ini.
-- For a full script restart, use Script > Reload in FCEUX's script window.
-- To pick up config file changes without restart, use: reload_config

debug_tools.register_command("next_object", function()
    local obj = objects.next_object()
    if obj then
        local desc = route_mgr.describe_current_object()
        debug_tools.info("OBJECT: " .. desc)
        tolk.output_interrupt(desc)
    else
        debug_tools.info("OBJECT: No objects found")
        tolk.output_interrupt("No objects found")
    end
end)

debug_tools.register_command("prev_object", function()
    local obj = objects.prev_object()
    if obj then
        local desc = route_mgr.describe_current_object()
        debug_tools.info("OBJECT: " .. desc)
        tolk.output_interrupt(desc)
    else
        debug_tools.info("OBJECT: No objects found")
        tolk.output_interrupt("No objects found")
    end
end)

debug_tools.register_command("current_object", function()
    local desc = route_mgr.describe_current_object()
    debug_tools.info("OBJECT: " .. desc)
    tolk.output_interrupt(desc)
end)

debug_tools.register_command("next_filter", function()
    local filter_name = objects.next_filter()
    local count = objects.get_count()
    if count > 0 then
        local desc = filter_name .. ". " .. route_mgr.describe_current_object()
        debug_tools.info("FILTER: " .. desc)
        tolk.output_interrupt(desc)
    else
        local desc = filter_name .. ". No objects"
        debug_tools.info("FILTER: " .. desc)
        tolk.output_interrupt(desc)
    end
end)

debug_tools.register_command("pathfind", function()
    route_mgr.pathfind_to_current()
end)

debug_tools.register_command("auto_walk", function()
    route_mgr.autowalk_to_current()
end)

-- speak:TEXT — test that TTS is working, e.g.: echo speak:Hello world > dw_commands.txt
debug_tools.register_command("speak", function(arg)
    if arg and arg ~= "" then
        tolk.output_interrupt(arg)
    end
end)

debug_tools.register_command("speech_status", function()
    local backend = tolk.get_backend and tolk.get_backend() or "unknown"
    local ready = tolk.is_ready and tolk.is_ready()
    local available = tolk.is_available and tolk.is_available()
    local err = tolk.get_last_error and tolk.get_last_error() or "none"
    local status = string.format(
        "Speech status. backend=%s. ready=%s. available=%s. error=%s",
        tostring(backend), tostring(ready), tostring(available), tostring(err))
    debug_tools.info(status)
    tolk.output_interrupt(status)
end)

debug_tools.register_command("report_blockers", function()
    objects.update_npcs()
    report_blockers_for_current_map()
    local map_id = snapshot.map_id
    tolk.output_interrupt(string.format(
        "Blockers reported. %d runtime blocks on map %02X",
        route_mgr.count_runtime_blocks(map_id), map_id))
end)

debug_tools.register_command("report_runtime_blocks", function()
    local map_id = snapshot.map_id
    local count = route_mgr.count_runtime_blocks(map_id)
    if count == 0 then
        debug_tools.info(string.format("RUNTIME_BLOCKS map=0x%02X none", map_id))
        tolk.output_interrupt("No runtime blocked cells")
        return
    end
    debug_tools.info(string.format("RUNTIME_BLOCKS map=0x%02X count=%d", map_id, count))
    for _, entry in ipairs(route_mgr.get_runtime_block_entries(map_id)) do
        debug_tools.info(string.format(
            "RUNTIME_BLOCK map=0x%02X x=%d y=%d key=%s dirs=%s",
            map_id,
            entry.x,
            entry.y,
            entry.key,
            table.concat(entry.dir_list, ",")))
    end
    tolk.output_interrupt(string.format("%d runtime blocked cells on map %02X", count, map_id))
end)

debug_tools.register_command("report_upper_dialogue_state", function()
    local upper = text.read_upper_window(get_scroll_tiles())
    local lower = text.read_dialogue_window_filtered(get_scroll_tiles(), get_dialogue_start_row())
    local msg = string.format(
        "UPPER_STATE active=%s menu=%s submenu=%s prev_dialogue_len=%d upper_len=%d baseline_len=%d announced_len=%d lower_len=%d upper=%q baseline=%q announced=%q",
        tostring(upper_dialogue_active),
        tostring(menu.is_open()),
        tostring(submenu_mode),
        #(prev_dialogue or ""),
        #(upper or ""),
        #(upper_baseline or ""),
        #(announced_upper_dialogue or ""),
        #(lower or ""),
        tostring(upper or ""),
        tostring(upper_baseline or ""),
        tostring(announced_upper_dialogue or "")
    )
    debug_tools.info(msg)
    tolk.output_interrupt("Upper dialogue state reported")
end)

debug_tools.register_command("clear_runtime_blocks", function(arg)
    if arg and arg:match("^%s*all%s*$") then
        route_mgr.clear_runtime_blocks("all")
        tolk.output_interrupt("Cleared runtime blocks for all maps")
        return
    end
    local map_id = snapshot.map_id
    if arg and arg ~= "" then
        map_id = parse_int_arg(arg)
        if map_id == nil then
            debug_tools.error("clear_runtime_blocks usage: clear_runtime_blocks, clear_runtime_blocks:MAP_ID, or clear_runtime_blocks:all")
            return
        end
    end
    route_mgr.clear_runtime_blocks(map_id)
    tolk.output_interrupt(string.format("Cleared runtime blocks for map %02X", map_id))
end)

-- Runtime block debug commands are registered via route_manager
route_mgr.register_debug_commands(function() return snapshot.map_id end)

debug_tools.register_command("inspect_tile", function(arg)
    local x, y = parse_xy_arg(arg)
    if not x then
        debug_tools.error("inspect_tile usage: inspect_tile:X,Y")
        return
    end
    objects.update_npcs()
    local map_id = snapshot.map_id
    local msg = log_tile_report(map_id, x, y)
    tolk.output_interrupt(msg)
end)

debug_tools.register_command("inspect_move", function(arg)
    local _, px, py = nav.get_position()
    local from_x, from_y, dir = parse_move_arg(arg, px, py)
    if not from_x then
        debug_tools.error("inspect_move usage: inspect_move:DIR or inspect_move:X,Y,DIR")
        return
    end
    objects.update_npcs()
    local msg = log_move_report(from_x, from_y, dir)
    if msg then
        tolk.output_interrupt(msg)
    end
end)

debug_tools.register_command("probe_edge", function(arg)
    local _, px, py = nav.get_position()
    local from_x, from_y, dir = parse_move_arg(arg, px, py)
    if not from_x then
        debug_tools.error("probe_edge usage: probe_edge:DIR or probe_edge:X,Y,DIR")
        return
    end
    if edge_probe_state then
        debug_tools.error("probe_edge: a probe is already active")
        return
    end
    if from_x ~= px or from_y ~= py then
        debug_tools.error(string.format(
            "probe_edge: stand on (%d,%d) first; current position is (%d,%d)",
            from_x, from_y, px, py))
        return
    end
    if map_survey.is_active() then
        debug_tools.error("probe_edge: stop the active survey first")
        return
    end
    if auto_step.is_route_active() then
        debug_tools.error("probe_edge: wait for the current auto-walk step/route to finish")
        return
    end
    objects.update_npcs()
    local msg, start_report = log_move_report(from_x, from_y, dir)
    local delta = DIR_TO_DELTA[dir]
    edge_probe_state = {
        map_id = snapshot.map_id,
        from_x = from_x,
        from_y = from_y,
        dir = dir,
        dest_x = from_x + delta.dx,
        dest_y = from_y + delta.dy,
        start_report = start_report,
        frames = 0,
    }
    debug_tools.info(string.format(
        "EDGE_PROBE_START map=0x%02X from=(%d,%d) dir=%s dest=(%d,%d)",
        snapshot.map_id,
        from_x,
        from_y,
        dir,
        edge_probe_state.dest_x,
        edge_probe_state.dest_y))
    auto_step.inject_step(dir)
    if msg then
        tolk.output_interrupt("Edge probe started. " .. msg)
    else
        tolk.output_interrupt("Edge probe started")
    end
end)

debug_tools.register_command("stop_probe_edge", function()
    if not edge_probe_state then
        debug_tools.error("stop_probe_edge: no active probe")
        return
    end
    auto_step.cancel_active_step(true)
    finish_edge_probe("cancelled", "manual_stop")
end)

debug_tools.register_command("pathfind_to", function(arg)
    local goal_x, goal_y = parse_xy_arg(arg)
    if goal_x == nil then
        debug_tools.error("pathfind_to usage: pathfind_to:X,Y")
        return
    end
    local map_id, px, py = nav.get_position()
    objects.update_npcs()
    local blocking = route_mgr.build_path_blocking(map_id)
    local opts = path_debug.build_find_path_opts()
    local result = pathfinder.pathfind_to(map_id, px, py, goal_x, goal_y, blocking, opts)
    local stats = opts and opts._get_stats() or {}
    local reason = stats and stats.reason
    local msg = string.format("Pathfind to %d,%d. %s%s",
        goal_x, goal_y, result,
        reason and (" [" .. reason .. "]") or "")
    debug_tools.info(msg)
    tolk.output_interrupt(msg)
end)

debug_tools.register_command("pathfind_adjacent", function(arg)
    local goal_x, goal_y = parse_xy_arg(arg)
    if goal_x == nil then
        debug_tools.error("pathfind_adjacent usage: pathfind_adjacent:X,Y")
        return
    end
    local map_id, px, py = nav.get_position()
    objects.update_npcs()
    local blocking = route_mgr.build_path_blocking(map_id)
    local result, face_dir = pathfinder.pathfind_to_adjacent(map_id, px, py, goal_x, goal_y, blocking)
    local msg = string.format("Pathfind adjacent to %d,%d. %s", goal_x, goal_y, result)
    if face_dir then
        msg = msg .. ". Face " .. face_dir
    end
    debug_tools.info(msg)
    tolk.output_interrupt(msg)
end)

debug_tools.register_command("report_path_state", function()
    local map_id = snapshot.map_id
    objects.update_npcs()
    local target = route_mgr.get_last_pathfind_obj()
    if target then
        debug_tools.info(string.format(
            "PATH_STATE target=%s type=%s x=%d y=%d map=0x%02X runtime_count=%d",
            tostring(target.name), tostring(target.type),
            target.x, target.y, map_id, route_mgr.count_runtime_blocks(map_id)))
    else
        debug_tools.info(string.format(
            "PATH_STATE target=nil map=0x%02X runtime_count=%d",
            map_id, route_mgr.count_runtime_blocks(map_id)))
    end
    report_blockers_for_current_map()
    tolk.output_interrupt("Path state reported")
end)

debug_tools.register_command("__config_reloaded", function()
    if tolk.reload_config then
        tolk.reload_config()
    end
end)

debug_tools.register_command("freeze_npcs", function()
    route_mgr.freeze_npcs()
    debug_tools.info("NPCs frozen")
    tolk.output_interrupt("NPCs frozen")
end)

debug_tools.register_command("unfreeze_npcs", function()
    route_mgr.unfreeze_npcs()
    debug_tools.info("NPCs unfrozen")
    tolk.output_interrupt("NPCs unfrozen")
end)

-- Neighbor search order for teleport_to :near mode. Cardinals first, then
-- diagonals. First walkable cell wins.
local TELEPORT_NEAR_OFFSETS = {
    {dx = 0,  dy = -1, name = "north"},
    {dx = 1,  dy = 0,  name = "east"},
    {dx = 0,  dy = 1,  name = "south"},
    {dx = -1, dy = 0,  name = "west"},
    {dx = 1,  dy = -1, name = "northeast"},
    {dx = 1,  dy = 1,  name = "southeast"},
    {dx = -1, dy = 1,  name = "southwest"},
    {dx = -1, dy = -1, name = "northwest"},
}

-- Parse teleport_to argument: "X,Y" or "X,Y,FLAG" where FLAG is near|force.
local function parse_teleport_arg(arg)
    if not arg then return nil end
    local x_s, y_s, flag = arg:match("^%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([%a]+)%s*$")
    if x_s then
        local x = parse_int_arg(x_s)
        local y = parse_int_arg(y_s)
        if x ~= nil and y ~= nil then
            return x, y, flag:lower()
        end
        return nil
    end
    local x, y = parse_xy_arg(arg)
    if x ~= nil then
        return x, y, nil
    end
    return nil
end

-- teleport_to:X,Y[,near|force]
--   (default) exact: refuse if target not walkable
--   near:     fall back to first walkable cardinal/diagonal neighbor
--   force:    skip walkability check entirely (debug/unstick; may strand in wall)
--
-- Always refuses during menus, dialogue, battle, sweeps, active routes, and
-- edge probes. Writes RAM 0x003A/0x003B for the new position; for the overworld
-- also updates 0x0042/0x003E shadow bytes. Clears any pending auto_step state.
debug_tools.register_command("teleport_to", function(arg)
    local tx, ty, flag = parse_teleport_arg(arg)
    if tx == nil then
        debug_tools.error("teleport_to usage: teleport_to:X,Y[,near|force]")
        tolk.output_interrupt("Teleport: invalid arguments")
        return
    end
    if flag ~= nil and flag ~= "near" and flag ~= "force" then
        debug_tools.error("teleport_to: unknown flag '" .. flag .. "' (use near or force)")
        tolk.output_interrupt("Teleport: unknown flag " .. flag)
        return
    end

    local reason = get_autowalk_unavailable_reason()
    if reason then
        debug_tools.error("teleport_to refused: " .. reason)
        tolk.output_interrupt("Teleport refused. " .. reason)
        return
    end
    if auto_step.is_route_active() then
        debug_tools.error("teleport_to refused: auto-walk route active")
        tolk.output_interrupt("Teleport refused. Wait for auto-walk to finish")
        return
    end
    if edge_probe_state ~= nil then
        debug_tools.error("teleport_to refused: edge probe active")
        tolk.output_interrupt("Teleport refused. Edge probe active")
        return
    end
    if map_survey.is_active() then
        debug_tools.error("teleport_to refused: map survey active")
        tolk.output_interrupt("Teleport refused. Survey active")
        return
    end

    local map_id = snapshot.map_id
    local width, height = map_reader.get_map_dimensions(map_id)
    local function in_bounds(x, y)
        if width == nil or height == nil then return true end
        return x >= 0 and y >= 0 and x < width and y < height
    end

    if not in_bounds(tx, ty) then
        debug_tools.error(string.format(
            "teleport_to refused: (%d,%d) out of bounds (map %dx%d)",
            tx, ty, width or -1, height or -1))
        tolk.output_interrupt("Teleport refused. Target out of bounds")
        return
    end

    local landing_x, landing_y = tx, ty
    local landing_note = nil

    if flag ~= "force" then
        local walkable = map_reader.is_walkable(map_id, tx, ty)
        if walkable ~= true then
            if flag == "near" then
                for _, off in ipairs(TELEPORT_NEAR_OFFSETS) do
                    local nx, ny = tx + off.dx, ty + off.dy
                    if in_bounds(nx, ny) and map_reader.is_walkable(map_id, nx, ny) == true then
                        landing_x, landing_y = nx, ny
                        landing_note = off.name
                        break
                    end
                end
                if landing_note == nil then
                    debug_tools.error(string.format(
                        "teleport_to refused: (%d,%d) not walkable and no walkable neighbor",
                        tx, ty))
                    tolk.output_interrupt("Teleport refused. No walkable cell near target")
                    return
                end
            else
                local tile_type = map_reader.get_tile_type(map_id, tx, ty)
                local tile_str = tile_type and string.format("0x%02X", tile_type) or "?"
                debug_tools.error(string.format(
                    "teleport_to refused: (%d,%d) not walkable (tile=%s); use near or force",
                    tx, ty, tile_str))
                tolk.output_interrupt(string.format(
                    "Teleport refused. %d, %d not walkable. Use near or force flag",
                    tx, ty))
                return
            end
        end
    end

    -- Cancel any in-flight step/repress so the engine doesn't re-inject motion
    -- from the old position after the RAM write.
    auto_step.cancel_active_step(true)

    -- Log the full 0x0030-0x004F range before and after the write so we can
    -- compare movement-state bytes (0x003C, 0x003E, 0x0042 etc.) across probe
    -- sessions. The post-write dump shows exactly which bytes teleport changes.
    if debug_tools.DEBUG_MODE then
        local bytes = {}
        for a = 0x0030, 0x004F do bytes[#bytes+1] = string.format("%02X", memory.readbyte(a)) end
        debug_tools.info(string.format(
            "TELEPORT_PRE to=(%d,%d) map=0x%02X ram0030_004F=%s",
            landing_x, landing_y, map_id, table.concat(bytes, " ")))
    end

    memory.writebyte(addr.PLAYER_X, landing_x)
    memory.writebyte(addr.PLAYER_Y, landing_y)
    if map_id == 0x00 then
        memory.writebyte(addr.OVERWORLD_X, landing_x)
        memory.writebyte(addr.OVERWORLD_Y, landing_y)
    end
    -- Normalize movement-engine state so probes from this position get
    -- reproducible results. Without this, stale 0x003C (e.g. 0x08 "leftward
    -- arrival") causes the engine to turn-in-place on the first press and then
    -- block on retry, making the same open edge appear engine-blocked.
    memory.writebyte(addr.MOVEMENT_STATE,    0x00)
    memory.writebyte(addr.MOVEMENT_SUBPIXEL, 0x00)
    -- Keep later commands in the same command poll from reading the pre-teleport
    -- cached position via navigation/game_snapshot.
    snapshot.update()

    if debug_tools.DEBUG_MODE then
        local bytes = {}
        for a = 0x0030, 0x004F do bytes[#bytes+1] = string.format("%02X", memory.readbyte(a)) end
        debug_tools.info(string.format(
            "TELEPORT_POST to=(%d,%d) map=0x%02X ram0030_004F=%s",
            landing_x, landing_y, map_id, table.concat(bytes, " ")))
    end

    local msg
    if landing_note then
        msg = string.format("Teleported to (%d,%d), %s of (%d,%d)",
            landing_x, landing_y, landing_note, tx, ty)
    elseif flag == "force" then
        msg = string.format("Teleported to (%d,%d) (forced)", landing_x, landing_y)
    else
        msg = string.format("Teleported to (%d,%d)", landing_x, landing_y)
    end
    debug_tools.info(msg)
    tolk.output_interrupt(msg)
end)

-- ============================================================
-- Path Debug Commands
-- ============================================================
-- These commands provide detailed pathfinding diagnostics.
-- All output goes to dw_debug.log. Requires debug_mode=true.

debug_tools.register_command("debug_pathfind_to", function(arg)
    local goal_x, goal_y = parse_xy_arg(arg)
    if not goal_x then
        debug_tools.error("debug_pathfind_to usage: debug_pathfind_to:X,Y")
        return
    end
    local map_id, px, py = nav.get_position()
    objects.update_npcs()
    local blocking = route_mgr.build_path_blocking(map_id)
    local opts = path_debug.build_find_path_opts()
    local result, face_dir, path = pathfinder.pathfind_to(
        map_id, px, py, goal_x, goal_y, blocking, opts)
    path_debug.store_path(map_id, px, py, goal_x, goal_y, path, opts)
    local stats = opts and opts._get_stats() or {}
    local reason = stats and stats.reason
    local msg = string.format("Debug pathfind to (%d,%d): %s%s (visited=%d path=%d)",
        goal_x, goal_y, result,
        reason and (" [" .. reason .. "]") or "",
        stats.nodes_visited or 0, path and #path or 0)
    debug_tools.info(msg)
    tolk.output_interrupt(msg)
end)

debug_tools.register_command("debug_pathfind_adjacent", function(arg)
    local goal_x, goal_y = parse_xy_arg(arg)
    if not goal_x then
        debug_tools.error("debug_pathfind_adjacent usage: debug_pathfind_adjacent:X,Y")
        return
    end
    local map_id, px, py = nav.get_position()
    objects.update_npcs()
    local blocking = route_mgr.build_path_blocking(map_id)
    local opts = path_debug.build_find_path_opts()
    local result, face_dir, path = pathfinder.pathfind_to_adjacent(
        map_id, px, py, goal_x, goal_y, blocking, opts)
    path_debug.store_path(map_id, px, py, goal_x, goal_y, path, opts)
    local stats = opts and opts._get_stats() or {}
    local reason = stats and stats.reason
    local msg = string.format("Debug pathfind adjacent to (%d,%d): %s%s (visited=%d path=%d)",
        goal_x, goal_y, result,
        reason and (" [" .. reason .. "]") or "",
        stats.nodes_visited or 0, path and #path or 0)
    if face_dir then msg = msg .. ". Face " .. face_dir end
    debug_tools.info(msg)
    tolk.output_interrupt(msg)
end)

debug_tools.register_command("trace_path", function()
    path_debug.trace_path()
    tolk.output_interrupt("Path trace logged")
end)

debug_tools.register_command("dump_search_log", function()
    path_debug.dump_search_log()
    tolk.output_interrupt("Search log dumped")
end)

debug_tools.register_command("start_step_mode", function()
    path_debug.start_step_mode()
    tolk.output_interrupt("Step mode started")
end)

debug_tools.register_command("stop_step_mode", function()
    path_debug.stop_step_mode()
    tolk.output_interrupt("Step mode stopped")
end)

debug_tools.register_command("step_path", function()
    local stepped = path_debug.step_path(auto_step)
    if not stepped then
        tolk.output_interrupt("No more steps")
    else
        tolk.output_interrupt("Step")
    end
end)

debug_tools.register_command("validate_path", function()
    path_debug.start_validate(auto_step)
    tolk.output_interrupt("Path validation started")
end)

debug_tools.register_command("stop_validate", function()
    path_debug.stop_validate()
    tolk.output_interrupt("Validation stopped")
end)

debug_tools.register_command("test_path", function(arg)
    local map_id = nav.get_position()
    route_mgr.clear_runtime_blocks(map_id)
    -- Keep deterministic fixture tests independent of live NPC movement.
    -- The suite already clears runtime blocks above, so use an empty snapshot.
    local blocking_snapshot = {}
    path_debug.run_test(arg, auto_step, function()
        return blocking_snapshot
    end)
    tolk.output_interrupt("Test scenarios logged")
end)

debug_tools.register_command("list_tests", function()
    path_debug.list_tests()
    tolk.output_interrupt("Test list logged")
end)

debug_tools.register_command("dump_path_grid", function()
    path_debug.dump_path_grid()
    tolk.output_interrupt("Path grid dumped")
end)

debug_tools.register_command("survey_map", function(arg)
    local ok, err = map_survey.start_object_survey(arg)
    if not ok then
        debug_tools.error("survey_map: " .. tostring(err))
        tolk.output_interrupt(tostring(err))
    end
end)

debug_tools.register_command("report_survey_start", function(arg)
    local ok, info = map_survey.report_start_viability(arg)
    if not ok then
        debug_tools.error("report_survey_start: " .. tostring(info))
        tolk.output_interrupt(tostring(info))
        return
    end

    local status = info.isolated_start and "isolated" or "viable"
    tolk.output_interrupt(string.format(
        "Survey start %s on map %02X at (%d,%d). Reachable area %d with %d open exits for %d targets.",
        status,
        info.map_id,
        info.start_x,
        info.start_y,
        info.reachable_area,
        info.open_exit_count,
        info.target_count))
end)

debug_tools.register_command("survey_objects", function(arg)
    local ok, err = map_survey.start_object_survey(arg)
    if not ok then
        debug_tools.error("survey_objects: " .. tostring(err))
        tolk.output_interrupt(tostring(err))
    end
end)

debug_tools.register_command("survey_target", function(arg)
    local ok, err = map_survey.start_target_survey(arg)
    if not ok then
        debug_tools.error("survey_target: " .. tostring(err))
        tolk.output_interrupt(tostring(err))
    end
end)

debug_tools.register_command("stop_survey", function()
    local ok, msg = map_survey.stop_survey()
    if not ok then
        debug_tools.error("stop_survey: " .. tostring(msg))
        tolk.output_interrupt(tostring(msg))
        return
    end
    tolk.output_interrupt(msg)
end)

debug_tools.register_command("report_failed_targets", function(arg)
    local map_id = parse_int_arg(arg) or snapshot.map_id
    local count = map_survey.report_failed_targets(map_id)
    if count == 0 then
        tolk.output_interrupt(string.format("No failed survey targets on map %02X", map_id))
    else
        tolk.output_interrupt(string.format("Reported %d failed survey targets on map %02X", count, map_id))
    end
end)

debug_tools.register_command("report_strong_candidates", function(arg)
    local map_id = parse_int_arg(arg) or snapshot.map_id
    local count = map_survey.report_strong_candidates(map_id)
    if count == 0 then
        tolk.output_interrupt(string.format("No strong reroute candidates on map %02X", map_id))
    else
        tolk.output_interrupt(string.format("Reported %d strong reroute candidates on map %02X", count, map_id))
    end
end)

debug_tools.register_command("report_survey_findings", function(arg)
    local map_id = parse_int_arg(arg) or snapshot.map_id
    local findings = map_survey.report_findings(map_id)
    if not findings or ((findings.failed_targets or 0) == 0 and (findings.strong_candidates or 0) == 0) then
        tolk.output_interrupt(string.format("No survey findings for map %02X", map_id))
    else
        tolk.output_interrupt(string.format(
            "Survey findings for map %02X. %d failed targets, %d strong reroute candidates.",
            map_id,
            findings.failed_targets or 0,
            findings.strong_candidates or 0))
    end
end)

debug_tools.register_command("report_candidate_suggestions", function(arg)
    local map_id = parse_int_arg(arg) or snapshot.map_id
    local count = map_survey.report_candidate_suggestions(map_id)
    if count == 0 then
        tolk.output_interrupt(string.format("No candidate suggestions for map %02X", map_id))
    else
        tolk.output_interrupt(string.format("Reported %d candidate suggestions for map %02X", count, map_id))
    end
end)

debug_tools.register_command("list_blocked_candidates", function(arg)
    local map_id = parse_int_arg(arg) or snapshot.map_id
    local count = map_survey.list_blocked_candidates(map_id)
    if count == 0 then
        tolk.output_interrupt(string.format("No blocked candidates on map %02X", map_id))
    else
        tolk.output_interrupt(string.format("Listed %d blocked candidates on map %02X", count, map_id))
    end
end)

debug_tools.register_command("dump_survey_report", function(arg)
    local map_id = parse_int_arg(arg) or snapshot.map_id
    local count = map_survey.dump_survey_report(map_id)
    if count == 0 then
        tolk.output_interrupt(string.format("No survey report for map %02X", map_id))
    else
        tolk.output_interrupt(string.format("Dumped survey report with %d targets for map %02X", count, map_id))
    end
end)

debug_tools.register_command("export_blocked_candidates", function(arg)
    local map_id = parse_int_arg(arg) or snapshot.map_id
    local count = map_survey.export_blocked_candidates(map_id)
    if count == 0 then
        tolk.output_interrupt(string.format("No blocked candidates to export for map %02X", map_id))
    else
        tolk.output_interrupt(string.format("Exported %d blocked candidates for map %02X", count, map_id))
    end
end)

debug_tools.register_command("export_directional_candidates", function(arg)
    local map_id = parse_int_arg(arg) or snapshot.map_id
    local count = map_survey.export_directional_candidates(map_id)
    if count == 0 then
        tolk.output_interrupt(string.format("No directional candidate exports for map %02X", map_id))
    else
        tolk.output_interrupt(string.format("Exported %d directional candidate entries for map %02X", count, map_id))
    end
end)

debug_tools.register_command("reset_survey_candidates", function(arg)
    local map_id = parse_int_arg(arg) or snapshot.map_id
    map_survey.reset_candidates(map_id)
    tolk.output_interrupt(string.format("Cleared survey candidates for map %02X", map_id))
end)

-- ============================================================
-- Main Loop
-- ============================================================
-- This is the core of the FCEUX Lua script. It runs forever,
-- advancing the emulator one frame at a time. Between frames,
-- we read game state, detect changes, and speak updates.
--
-- The loop MUST call FCEU.frameadvance() exactly once per
-- iteration — without it, the emulator freezes.

while true do
    trace_startup_loop("loop_top")
    row1_trace_frame = frame_count

    -- Read all tracked RAM values into the snapshot table.
    -- This MUST happen before any module reads from the snapshot this frame.
    snapshot.update()

    -- Read keyboard state for hotkeys
    local keys = input.get()
    current_joy = joypad.read(1)
    current_joy_any = joypad_has_input(current_joy)

    -- Process on-demand hotkeys (player-initiated).
    -- hotkeys.update() also saves prev_keys internally for key-down detection.
    hotkeys.update(keys)

    -- Get current game state
    game_state = state.check_for_changes()
    in_gameplay = (game_state.state ~= state.STATE_TITLE)

    -- Startup grace period: during the first STARTUP_FRAMES frames,
    -- let all the "previous" tracking values initialize silently.
    -- We still run the detection functions (so prev_ values get set),
    -- but we suppress their announcements by skipping the output block.
    if startup_counter < STARTUP_FRAMES then
        startup_counter = startup_counter + 1

        -- Silently initialize previous-frame values so they don't
        -- trigger false change detections after the grace period ends.
        prev_hp = snapshot.hp
        prev_mp = snapshot.mp
        prev_level = snapshot.level
        prev_gold       = snapshot.gold
        prev_magic_keys = snapshot.keys
        prev_herbs      = snapshot.herbs
        prev_items = {
            snapshot.items[1],
            snapshot.items[2],
            snapshot.items[3],
            snapshot.items[4],
        }
        nav.check_for_changes()   -- Initialize map/position tracking
        menu.check_for_changes()  -- Initialize menu cursor tracking

        -- On the very last frame of the grace period, announce current
        -- state so the player knows where they are. Without this, the
        -- title screen transition would be missed since it happened
        -- during the grace period.
        if startup_counter == STARTUP_FRAMES then
            -- Initialize the upper dialogue baseline so the status display
            -- text doesn't get announced as "new dialogue" after the grace period.
            upper_baseline = text.read_upper_window(get_scroll_tiles())
            prev_upper_dialogue = upper_baseline
            reset_merchant_state(false)
            reset_battle_menu_state()

            if game_state.state == state.STATE_TITLE then
                prev_title_cursor_row       = nil
                prev_title_cursor_col       = nil
                prev_is_name_entry          = false
                name_entry_active           = false
                prev_name_d8                = nil
                prev_name_d9                = nil
                title_stable                = 0
                cursor_held_row             = nil
                cursor_held_col             = nil
                cursor_hold_timer           = 0
                challenger_row              = nil
                challenger_col              = nil
                challenger_frames           = 0
                prev_title_no_cursor_text   = ""
                title_no_cursor_stable      = 0
                save_slot_was_open          = false
                prev_save_slot_d9           = nil
                msg_speed_was_open          = false
                prev_msg_speed_d9           = nil
                field_from_title_ct         = 0
                reset_merchant_state(false)
                reset_battle_menu_state()
                tolk.output("Title screen.")
            end
        end
    else
        -- Normal operation: announce state transitions and changes

        -- Announce state transitions
        if game_state.changed then
            if game_state.state == state.STATE_TITLE then
                prev_title_cursor_row       = nil
                prev_title_cursor_col       = nil
                prev_is_name_entry          = false
                name_entry_active           = false
                prev_name_d8                = nil
                prev_name_d9                = nil
                title_stable                = 0
                cursor_held_row             = nil
                cursor_held_col             = nil
                cursor_hold_timer           = 0
                challenger_row              = nil
                challenger_col              = nil
                challenger_frames           = 0
                prev_title_no_cursor_text   = ""
                title_no_cursor_stable      = 0
                save_slot_was_open          = false
                prev_save_slot_d9           = nil
                msg_speed_was_open          = false
                prev_msg_speed_d9           = nil
                field_from_title_ct         = 0
                reset_merchant_state(false)
                reset_battle_menu_state()
                tolk.output("Title screen.")
            elseif game_state.state == state.STATE_BATTLE then
                reset_merchant_state(false)
                reset_battle_menu_state()
                tolk.output("Battle!")
                debug_tools.on_battle_start()
                event_bus.publish("battle_started")
            elseif game_state.state == state.STATE_FIELD then
                reset_battle_menu_state()
                -- Transitioning from title to field: start or continue debounce.
                if game_state.prev_state == state.STATE_TITLE then
                    field_from_title_ct = 1
                end
            end
        end

        -- Debounce: count consecutive FIELD frames that follow a TITLE state.
        -- Only announce "Game started." once the count reaches the threshold.
        -- If the state dips back to TITLE (sub-menu backing out), reset the counter.
        if field_from_title_ct > 0 then
            if game_state.state == state.STATE_FIELD then
                field_from_title_ct = field_from_title_ct + 1
                if field_from_title_ct == FIELD_DEBOUNCE then
                    tolk.output("Game started.")
                    post_start_grace = FIELD_GRACE
                end
            else
                -- State left FIELD (back to TITLE or into BATTLE) — false alarm.
                field_from_title_ct = 0
            end
        end

        -- Run Yes/No detection first so the rest of the frame sees current
        -- prompt state. Guard 1 reuses the command-menu window and cursor RAM,
        -- so stale prompt state here can leak into false STATUS handling.
        check_yesno_prompt()

        if game_state.state == state.STATE_FIELD then
            if current_joy_any or menu.is_open() or submenu_mode ~= nil or menu.is_yesno_active() then
                recent_field_action_frames = RECENT_FIELD_ACTION_HOLD
            elseif recent_field_action_frames > 0 then
                recent_field_action_frames = recent_field_action_frames - 1
            end
        else
            recent_field_action_frames = 0
        end

        if game_state.state == state.STATE_BATTLE then
            battle_dialogue_grace_frames = BATTLE_DIALOGUE_GRACE
        elseif battle_dialogue_grace_frames > 0 then
            battle_dialogue_grace_frames = battle_dialogue_grace_frames - 1
        end

        -- Run automatic checks based on current state.
        -- Skip gameplay checks while on the title screen — the stat
        -- addresses contain garbage/uninitialized data there.
        if game_state.state ~= state.STATE_TITLE then
            if post_start_grace > 0 or field_from_title_ct > 0 then
                -- Silently re-initialize change-detection baselines during
                -- post-start grace OR title-to-field debounce so transient
                -- load-sequence RAM values don't fire false HP/map announcements.
                -- The debounce period (field_from_title_ct > 0) covers the first
                -- ~30 frames before grace officially starts; without this, HP
                -- changes during loading trigger false "Gained X HP" announcements.
                prev_hp         = snapshot.hp
                prev_mp         = snapshot.mp
                prev_level      = snapshot.level
                prev_gold       = snapshot.gold
                prev_magic_keys = snapshot.keys
                prev_herbs      = snapshot.herbs
                prev_items = {
                    snapshot.items[1],
                    snapshot.items[2],
                    snapshot.items[3],
                    snapshot.items[4],
                }
                if post_start_grace > 0 then
                    post_start_grace = post_start_grace - 1
                    nav.check_for_changes()  -- Initialize map tracking silently
                    if post_start_grace == 0 then
                        -- Grace period just ended. Announce the now-stable
                        -- starting location so the player knows where they are.
                        local map_name = nav.get_map_name()
                        if map_name then tolk.output(map_name) end
                        -- Skip one HP/MP check so the first real frame doesn't
                        -- compare a potentially stale last-grace-frame value
                        -- against a just-updated current value.
                        skip_first_hp_check = true
                    end
                end
            else
                check_map_change()
                if skip_first_hp_check then
                    -- Re-initialize baselines instead of checking for changes.
                    prev_hp    = snapshot.hp
                    prev_mp    = snapshot.mp
                    prev_level = snapshot.level
                    skip_first_hp_check = false
                else
                    check_hp_mp_changes()
                    check_level_up()
                end
            end
            if game_state.state == state.STATE_BATTLE then
                check_battle_menu()
            else
                check_command_menu()
            end

            -- Keep the object list fresh: detect map changes and
            -- periodically re-read NPC positions (they move around).
            local map_id = snapshot.map_id
            objects.check_refresh(map_id)

            -- Detect chest collection (only meaningful during field movement,
            -- but safe to run any time we're not on the title screen).
            if game_state.state == state.STATE_FIELD then
                check_chest_collection()
            end
        end

        -- Dialogue checks — run every frame to track text changes.
        -- Both lower (rows 19-29) and upper (rows 1-18) dialogue are only
        -- meaningful during gameplay. On the title screen, graphic tiles in
        -- those rows decode as spurious digits/uppercase and produce false
        -- announcements. check_title_screen() handles all title-screen text.
        if in_gameplay then
            if not check_merchant_screen() then
                check_dialogue()
                check_upper_dialogue()
            end
        else
            reset_merchant_state(false)
            check_title_screen()
        end
    end

    -- Increment frame counter monotonically so debug log frame prefixes stay
    -- ordered across long sessions. Lua numbers can represent this safely.
    frame_count = frame_count + 1

    -- Debug tools: process command file, flush logs, apply simulated input.
    -- All of this is a no-op when debug_mode=false in dw_access.ini.
    local sim_input = debug_tools.tick(frame_count, game_state.state)
    path_debug.tick()  -- Drive validation state machine (no-op when debug_mode=false)
    local raw_debug_input_this_frame = sim_input and sim_input._raw
    if sim_input then
        -- sweep_map returns input tagged with _sweep=true. report/debug probes
        -- can also request a one-frame raw injection via _raw=true.
        -- These should go directly to joypad.set() — NOT through
        -- auto_step.inject_step(), which would start a competing auto-hold.
        --
        -- Normal simulate_input directions DO go through inject_step so the
        -- full tap-to-step hold sequence fires (auto_step reads joypad.read(),
        -- not joypad.set() output, so a bare joypad.set() of a direction would
        -- only turn the character without moving).
        if sim_input._sweep or sim_input._raw then
            joypad.set(1, sim_input)
        else
            local dir_sim = sim_input.up or sim_input.down or sim_input.left or sim_input.right
            if dir_sim then
                local dir = sim_input.up and "up"
                         or sim_input.down and "down"
                         or sim_input.left and "left"
                         or sim_input.right and "right"
                auto_step.inject_step(dir)
            else
                joypad.set(1, sim_input)
            end
        end
    end

    -- Auto-step: extend brief D-pad taps into full tile steps.
    -- Only active when the player is walking on the field (not in
    -- menus, dialogue, battle, or on the title screen).
    local can_walk = game_state.state == state.STATE_FIELD
                     and not debug_tools.is_sweep_active()  -- suspend during map sweep
                     and not path_debug.is_step_mode()      -- suspend during step-by-step mode
                     and (
                         path_debug.is_validating()
                         or (
                             not menu.is_open()
                             and submenu_mode == nil
                             and not merchant_screen_active
                             and prev_dialogue == ""
                             and not upper_dialogue_active
                         )
                     )
    if debug_tools.DEBUG_MODE and not can_walk then
        local active_target = route_mgr.get_last_pathfind_obj and route_mgr.get_last_pathfind_obj()
        if active_target or (path_debug.is_validating and path_debug.is_validating()) then
            debug_tools.debug(string.format(
                "CAN_WALK false: state=%s sweep=%s step_mode=%s validating=%s menu=%s submenu=%s prev_dialogue_len=%d upper_dialogue_active=%s target=%s",
                tostring(game_state.state),
                tostring(debug_tools.is_sweep_active()),
                tostring(path_debug.is_step_mode()),
                tostring(path_debug.is_validating()),
                tostring(menu.is_open()),
                tostring(submenu_mode),
                #(prev_dialogue or ""),
                tostring(upper_dialogue_active),
                active_target and tostring(active_target.name) or "nil"))
        end
    end
    tick_edge_probe()
    map_survey.tick(can_walk)
    -- Raw debug input is meant to exercise the game engine directly. Do not let
    -- auto_step observe the simulated press/release edge, or it can synthesize
    -- a blocked auto-step after the raw hold and pollute probe/survey evidence.
    if not raw_debug_input_this_frame then
        auto_step.update(can_walk)
    end

    -- Advance the emulator by one frame. This is required —
    -- without it, the emulator hangs.
    trace_startup_loop("before_frameadvance")
    FCEU.frameadvance()
    trace_startup_loop("after_frameadvance")

    -- If NPC freeze is active, restore NPC position bytes to their snapshot.
    -- The NES game's NPC movement routines ran during frameadvance and may
    -- have written new positions; we undo that here so our code sees stable
    -- NPC coordinates on the next frame.
    route_mgr.apply_npc_freeze()
    map_survey.apply_npc_parking()
end
