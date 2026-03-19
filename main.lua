-- main.lua
-- Dragon Warrior Accessibility Mod — Entry Point
--
-- This is the main script loaded by FCEUX. It runs the core polling loop:
-- every frame we read game state from RAM, compare to the previous frame,
-- and speak any changes through Tolk (screen reader bridge).
--
-- Load in FCEUX: File > Load Lua Script > select this file.
-- Or from command line:
--   fceux.exe "Dragon Warrior (USA) (Rev 1).nes" --loadlua "main.lua"

-- ============================================================
-- Module Loading
-- ============================================================
-- FCEUX runs scripts from the script's directory, so require() finds
-- our sibling .lua files automatically.

local tolk = require "tolk"         -- Speech output (Python bridge to screen reader)
local addr = require "addresses"    -- RAM address constants
local chars = require "chars"       -- Text encoding table
local maps = require "maps"         -- Map ID to name lookup
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

-- Forward declarations for state referenced by early callbacks.
local last_pathfind_obj = nil
local npc_freeze_active = false
local frozen_npc_snapshot = {}  -- Array [0..19] of {b0, b1, b2}
local capture_npc_snapshot

-- ============================================================
-- Startup
-- ============================================================
-- Announce that the accessibility mod is loaded and ready.
tolk.output("Dragon Warrior Accessibility Mod loaded.")
FCEU.message("DW Access Mod loaded")

-- Auto re-routing: when auto_step times out (step blocked), re-compute
-- the path to the last pathfind target using fresh NPC positions.
-- This handles the case where a roaming NPC blocks a step mid-path.
auto_step.on_blocked = function()
    if not last_pathfind_obj then return end
    local map_id, px, py = nav.get_position()
    objects.update_npcs()
    -- Re-freeze only if the target is an NPC (same logic as initial pathfind)
    if last_pathfind_obj.type == objects.TYPE_NPC then
        capture_npc_snapshot()
        npc_freeze_active = true
    end
    local blocking = objects.get_blocking_positions()
    local result, face_dir
    local target_walkable = map_reader.is_walkable(map_id, last_pathfind_obj.x, last_pathfind_obj.y)
    if last_pathfind_obj.type == objects.TYPE_NPC
    or last_pathfind_obj.type == objects.TYPE_DOOR
    or not target_walkable then
        result, face_dir = pathfinder.pathfind_to_adjacent(
            map_id, px, py,
            last_pathfind_obj.x, last_pathfind_obj.y, blocking)
    else
        result = pathfinder.pathfind_to(
            map_id, px, py,
            last_pathfind_obj.x, last_pathfind_obj.y, blocking)
    end
    local msg = "Re-routing. " .. last_pathfind_obj.name .. ". " .. result
    if face_dir then
        msg = msg .. ". Face " .. face_dir
    end
    tolk.output_interrupt(msg)
end

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
-- Note: "prev_keys" is already taken (keyboard state). Use distinct names.
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

-- Last object the player pathfound to. Kept so auto_step.on_blocked
-- can re-route to the same target when a moving NPC blocks a step.
-- Cleared on map change.
last_pathfind_obj = nil

-- NPC freeze: lock NPC positions in RAM for reliable pathfinding.
-- When active, we restore NPC bytes to their snapshot values after
-- every FCEU.frameadvance(), undoing any movement the game's AI did.
-- The blind user doesn't need NPCs to visually wander, so this is safe.
npc_freeze_active = false
frozen_npc_snapshot = {}  -- Array [0..19] of {b0, b1, b2}

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
local submenu_mode = nil
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

-- ============================================================
-- Hotkey Handling
-- ============================================================
-- Keyboard hotkeys let the player request info on demand.
-- We track which keys were pressed last frame to detect fresh presses
-- (key-down events) and avoid repeating while a key is held.

local prev_keys = {}

-- is_key_pressed(keys, key_name): Check if a key was just pressed
-- this frame (wasn't pressed last frame). This prevents the action
-- from firing repeatedly while the key is held down.
local function is_key_pressed(keys, key_name)
    return keys[key_name] and not prev_keys[key_name]
end

-- capture_npc_snapshot(): Read all 20 NPC entries (3 bytes each) from RAM
-- and save them into frozen_npc_snapshot. Called when freeze is activated.
-- Byte 0: sprite type (bits 7-5) + X position (bits 4-0).
-- Byte 1: animation frame (bit 7) + direction (bits 6-5) + Y position (bits 4-0).
-- Byte 2: movement behavior code.
capture_npc_snapshot = function()
    frozen_npc_snapshot = {}
    for i = 0, addr.NPC_COUNT - 1 do
        local base = addr.NPC_DATA_START + i * addr.NPC_ENTRY_SIZE
        frozen_npc_snapshot[i] = {
            memory.readbyte(base),
            memory.readbyte(base + 1),
            memory.readbyte(base + 2),
        }
    end
end

-- apply_npc_freeze(): Restore snapshotted NPC bytes to RAM.
-- Call once per frame immediately after FCEU.frameadvance().
-- The NES NPC AI runs during frameadvance and may write new positions;
-- this undoes those writes so our code sees stable NPC coordinates next frame.
-- No-op when npc_freeze_active is false, so it's safe to call every frame.
local function apply_npc_freeze()
    if not npc_freeze_active then return end
    for i = 0, addr.NPC_COUNT - 1 do
        local base = addr.NPC_DATA_START + i * addr.NPC_ENTRY_SIZE
        local snap = frozen_npc_snapshot[i]
        memory.writebyte(base,     snap[1])
        memory.writebyte(base + 1, snap[2])
        memory.writebyte(base + 2, snap[3])
    end
end

-- handle_hotkeys(keys): Process keyboard hotkeys for on-demand info.
-- keys: table from input.get() with key names as keys, true as values.
-- All key assignments come from config.lua so the user can remap them.
local function handle_hotkeys(keys)
    -- Position: Read current position (map name + coordinates)
    if is_key_pressed(keys, config.get("key_position")) then
        tolk.output_interrupt(nav.get_position_string())
    end

    -- HP/MP: Read current HP and MP
    if is_key_pressed(keys, config.get("key_hp")) then
        local hp = memory.readbyte(addr.CURRENT_HP)
        local max_hp = memory.readbyte(addr.MAX_HP)
        local mp = memory.readbyte(addr.CURRENT_MP)
        local max_mp = memory.readbyte(addr.MAX_MP)
        tolk.output_interrupt("HP " .. hp .. " of " .. max_hp ..
                              ", MP " .. mp .. " of " .. max_mp)
    end

    -- Level: Read player level (default I, moved from L to free it for navigation)
    if is_key_pressed(keys, config.get("key_level")) then
        local level = memory.readbyte(addr.LEVEL)
        tolk.output_interrupt("Level " .. level)
    end

    -- Gold: Read gold
    if is_key_pressed(keys, config.get("key_gold")) then
        local gold = memory.readbyte(addr.GOLD_LO) +
                     memory.readbyte(addr.GOLD_HI) * 256
        tolk.output_interrupt(gold .. " gold")
    end

    -- Experience: Read experience
    if is_key_pressed(keys, config.get("key_experience")) then
        local exp = memory.readbyte(addr.EXPERIENCE_LO) +
                    memory.readbyte(addr.EXPERIENCE_HI) * 256
        tolk.output_interrupt(exp .. " experience")
    end

    -- Stats: Read full stats (level, HP/MP, all stats, equipment, spells)
    if is_key_pressed(keys, config.get("key_stats")) then
        tolk.output_interrupt(items.read_status_string())
    end

    -- Screen text: Read all text currently on screen
    if is_key_pressed(keys, config.get("key_screen_text")) then
        local screen_text = text.get_full_screen_text()
        if screen_text ~= "" then
            tolk.output_interrupt(screen_text)
        else
            tolk.output_interrupt("No text on screen")
        end
    end

    -- Diagnostic: raw menu cursor values
    if is_key_pressed(keys, config.get("key_diag_cursor")) then
        tolk.output_interrupt(menu.get_cursor_info())
    end

    -- Diagnostic: dump raw PPU tile bytes for rows 15-29.
    -- Shows first/last non-BG column, decoded text, and any NT1 ($2400) tiles.
    -- Use this at x=8 with truncated dialogue visible to locate where text tiles
    -- are written in the nametable and whether any overflow into NT1.
    if is_key_pressed(keys, config.get("key_diag_ppu_dump")) then
        local BG  = 0x9F   -- background/empty tile in PPU nametable
        local NT0 = 0x2000 -- nametable 0
        local NT1 = 0x2400 -- nametable 1 (potential overflow target)
        local W   = 32     -- nametable width in tiles

        local dump = {}
        local map_id, px, py = nav.get_position()
        dump[#dump+1] = "=== PPU Nametable Dump ==="
        dump[#dump+1] = string.format("Map: %d (0x%02X)  Player: x=%d, y=%d", map_id, map_id, px, py)
        dump[#dump+1] = ""
        dump[#dump+1] = "Rows 15-29 from NT0 ($2000) and NT1 ($2400)."
        dump[#dump+1] = "BG tile 0x9F shown as '--'.  Non-BG shown as 2-digit hex."
        dump[#dump+1] = ""

        for row = 15, 29 do
            -- Read all 32 bytes from NT0 for this row.
            local nt0 = {}
            local first_col = -1
            local last_col  = -1
            for col = 0, W - 1 do
                local b = ppu.readbyte(NT0 + row * W + col)
                nt0[col] = b
                if b ~= BG then
                    if first_col == -1 then first_col = col end
                    last_col = col
                end
            end

            -- Read NT1 for this row — collect any non-BG entries.
            local nt1_parts = {}
            for col = 0, W - 1 do
                local b = ppu.readbyte(NT1 + row * W + col)
                if b ~= BG then
                    nt1_parts[#nt1_parts+1] = string.format("c%d=%02X", col, b)
                end
            end

            -- Build hex display of NT0 row (BG as "--").
            local hex_parts = {}
            for col = 0, W - 1 do
                local b = nt0[col]
                hex_parts[col+1] = (b == BG) and "--" or string.format("%02X", b)
            end

            -- Decode NT0 bytes to text.
            local row_bytes = {}
            for col = 0, W - 1 do row_bytes[col+1] = nt0[col] end
            local decoded = chars.decode_bytes(row_bytes)
            decoded = decoded:match("^%s*(.-)%s*$") or ""

            -- Assemble line header.
            local col_info
            if first_col == -1 then
                col_info = "(all BG)"
            else
                col_info = string.format("cols %d-%d", first_col, last_col)
            end

            local nt1_info = ""
            if #nt1_parts > 0 then
                nt1_info = "  NT1: " .. table.concat(nt1_parts, " ")
            end

            dump[#dump+1] = string.format("Row %2d [%s]%s", row, col_info, nt1_info)
            dump[#dump+1] = "  NT0: " .. table.concat(hex_parts, " ")
            if decoded ~= "" then
                dump[#dump+1] = "  TXT: " .. decoded
            end
        end

        local f = io.open("ppu_dump.txt", "w")
        if f then
            f:write(table.concat(dump, "\n"))
            f:close()
            tolk.output_interrupt("PPU dump written to ppu_dump.txt")
        else
            tolk.output_interrupt("Failed to write dump file")
        end
    end

    -- Diagnostic: title screen cursor and RAM state dump.
    -- Use this while on the Adventure Log slot-selection screen or message speed
    -- screen to determine how the game signals which item is selected.
    -- Output goes to title_diag.txt.
    --
    -- Key things to look for in the output:
    --   D8/D9 changes as you move cursor → use RAM-based detection (cleanest)
    --   Cursor tile (0x42) found at col 11 of slot row → cursor tile approach works
    --   No cursor tile found → selection is palette-based; need joypad tracking
    if is_key_pressed(keys, config.get("key_diag_title")) then
        local d8 = memory.readbyte(addr.MENU_CURSOR_X)
        local d9 = memory.readbyte(addr.MENU_CURSOR_Y)
        local dump = {}
        dump[#dump+1] = string.format("=== Title Screen Diagnostic ===")
        dump[#dump+1] = string.format("D8 (cursor X) = %d (0x%02X)", d8, d8)
        dump[#dump+1] = string.format("D9 (cursor Y) = %d (0x%02X)", d9, d9)
        dump[#dump+1] = ""

        -- Find all cursor tiles (0x42 or 0x43) in the full PPU nametable.
        dump[#dump+1] = "--- Cursor tiles (0x42/0x43) found in NT0 (0x2000) ---"
        local found_any = false
        for row = 0, 29 do
            for col = 0, 31 do
                local tile = ppu.readbyte(0x2000 + row * 32 + col)
                if tile == 0x42 or tile == 0x43 then
                    dump[#dump+1] = string.format("  Row %2d Col %2d: tile=0x%02X", row, col, tile)
                    found_any = true
                end
            end
        end
        if not found_any then
            dump[#dump+1] = "  (none found)"
        end
        dump[#dump+1] = ""

        -- Decode PPU rows 6-26 (covers both high-screen and low-screen sub-menus).
        -- Each line shows raw hex bytes and decoded text side by side.
        dump[#dump+1] = "--- PPU rows 6-26 (raw bytes and decoded text) ---"
        for row = 6, 26 do
            local hex_parts = {}
            local raw_bytes = {}
            for col = 0, 31 do
                local b = ppu.readbyte(0x2000 + row * 32 + col)
                hex_parts[#hex_parts+1] = string.format("%02X", b)
                raw_bytes[#raw_bytes+1] = b
            end
            local decoded = text.decode_row(row)
            dump[#dump+1] = string.format("Row %2d: %s  |  [%s]",
                row,
                table.concat(hex_parts, " "),
                decoded)
        end

        local f = io.open("title_diag.txt", "w")
        if f then
            f:write(table.concat(dump, "\n"))
            f:close()
            tolk.output_interrupt("Title diagnostic written to title_diag.txt")
        else
            tolk.output_interrupt("Failed to write title_diag.txt")
        end
    end

    -- Diagnostic: tile types at and around the player's position.
    -- Speaks a short summary and writes tile_diag.txt for detailed inspection.
    --
    -- Key output to verify in the file:
    --   rom.readbyte(0): if 0x4E ('N'), the iNES header IS included in offsets.
    --                    If it's something else (e.g. 0x78 = NES SEI opcode),
    --                    the header is NOT included (offsets are PRG-ROM relative).
    --   Map metadata width/height: should be reasonable (8-32 for a castle room).
    --   Tile types at player: type 0 = floor guess, 2 = wall guess in WALKABLE_TOWN.
    --   If ALL tiles show type 0 regardless of floor/wall, the data_ptr is wrong
    --   (out-of-bounds rom.readbyte calls returning 0).
    if is_key_pressed(keys, config.get("key_diag_tiles")) then
        local map_id = memory.readbyte(addr.MAP_ID)
        local px = memory.readbyte(addr.PLAYER_X)
        local py = memory.readbyte(addr.PLAYER_Y)
        local ram_tile = memory.readbyte(addr.TILE_TYPE)
        local meta = map_reader.get_metadata(map_id)

        -- Helper: return "typeW" (walkable), "typeDoor" (locked door), or "typeX" (wall)
        local function td(x, y)
            local t = map_reader.get_tile_type(map_id, x, y)
            if t == nil then return "nil" end
            local w = map_reader.is_walkable(map_id, x, y)
            local terrain = memory.readbyte(addr.TERRAIN_OFFSET)
            local is_door = (terrain == 0x10 and t == 11) or (terrain == 0x20 and t == 5)
            if is_door then
                return tostring(t) .. "D"  -- D = locked door
            end
            return tostring(t) .. (w and "W" or "X")
        end

        -- Speak a compact summary of tile types at player + 4 neighbors.
        -- Format: "At 5,8. RAM 0. Here 0W. N 2X. S 0W. W 0W. E 1W."
        -- 'W' suffix = walkable, 'X' = wall, RAM = game's own tile type.
        tolk.output_interrupt(
            "At " .. px .. "," .. py ..
            ". RAM " .. ram_tile ..
            ". Here " .. td(px, py) ..
            ". N " .. td(px, py - 1) ..
            ". S " .. td(px, py + 1) ..
            ". W " .. td(px - 1, py) ..
            ". E " .. td(px + 1, py)
        )

        -- Write detailed diagnostic to file
        local lines = {}
        lines[#lines+1] = "=== Tile Diagnostic ==="
        lines[#lines+1] = string.format("Map ID: %d (0x%02X)", map_id, map_id)
        lines[#lines+1] = string.format("Player: x=%d, y=%d", px, py)
        lines[#lines+1] = string.format("RAM TILE_TYPE (0x0015): %d", ram_tile)
        lines[#lines+1] = string.format("TERRAIN_OFFSET (0x0016): 0x%02X",
            memory.readbyte(addr.TERRAIN_OFFSET))

        -- Horizontal scroll finder: scan zero-page addresses 0x0000-0x0060.
        -- Previous scan (0x0036-0x0050) missed the real range. The PPU scroll
        -- shadow is typically in the very low zero page (0x00-0x35). Compare
        -- two captures — at x=8 (truncated text) and x=1 (full text) on the
        -- same map — and look for an address whose value is ~11*8=88 at x=8
        -- and ~0 at x=1. That address is addr.SCROLL_X. Value is in PIXELS; the
        -- caller divides by 8 to get NES tile scroll. 0x0042 was a false match.
        lines[#lines+1] = ""
        lines[#lines+1] = "--- Horizontal Scroll Finder (zero-page 0x0000-0x0060) ---"
        lines[#lines+1] = string.format("Player x=%d y=%d  (need: ~88 at x=8, ~0 at x=1)", px, py)
        lines[#lines+1] = "Range 0x0000-0x001F:"
        local zp_lo = {}
        for a = 0x0000, 0x001F do
            zp_lo[#zp_lo+1] = string.format("0x%04X=%02X", a, memory.readbyte(a))
        end
        lines[#lines+1] = table.concat(zp_lo, "  ")
        lines[#lines+1] = "Range 0x0020-0x003F:"
        local zp_mid = {}
        for a = 0x0020, 0x003F do
            zp_mid[#zp_mid+1] = string.format("0x%04X=%02X", a, memory.readbyte(a))
        end
        lines[#lines+1] = table.concat(zp_mid, "  ")
        lines[#lines+1] = "Range 0x0040-0x0060:"
        local zp_hi = {}
        for a = 0x0040, 0x0060 do
            zp_hi[#zp_hi+1] = string.format("0x%04X=%02X", a, memory.readbyte(a))
        end
        lines[#lines+1] = table.concat(zp_hi, "  ")

        -- Critical: check whether rom.readbyte(0) is the iNES header or PRG-ROM.
        -- iNES magic: 4E 45 53 1A ('N','E','S',ctrl-Z)
        -- If byte 0 = 0x4E, offsets include the 16-byte header.
        -- If byte 0 = 0x78 (SEI) or another NES opcode, offsets are PRG-ROM-relative.
        lines[#lines+1] = ""
        lines[#lines+1] = "--- ROM addressing check ---"
        lines[#lines+1] = string.format(
            "rom.readbyte(0..3) = %02X %02X %02X %02X",
            rom.readbyte(0), rom.readbyte(1), rom.readbyte(2), rom.readbyte(3))
        lines[#lines+1] = "(0x4E 0x45 0x53 0x1A = iNES header included in offsets)"
        lines[#lines+1] = "(other = PRG-ROM offsets, no header)"

        -- Map metadata
        lines[#lines+1] = ""
        lines[#lines+1] = "--- Map Metadata ---"
        if meta then
            lines[#lines+1] = string.format("data_ptr = 0x%04X (%d)", meta.data_ptr, meta.data_ptr)
            lines[#lines+1] = string.format("width = %d, height = %d", meta.width, meta.height)
            lines[#lines+1] = string.format("border_tile = %d", meta.border_tile)
            -- First 16 RLE bytes at data_ptr.
            -- Valid RLE: each byte encodes tile_type (hi nibble, 0-15) + count-1 (lo nibble).
            -- If all zeros: data_ptr is out of bounds (rom.readbyte returning 0).
            local hex_parts = {}
            for i = 0, 15 do
                hex_parts[#hex_parts+1] = string.format("%02X", rom.readbyte(meta.data_ptr + i))
            end
            lines[#lines+1] = "First 16 bytes at data_ptr: " .. table.concat(hex_parts, " ")
        else
            lines[#lines+1] = "(no metadata — overworld or invalid map)"
        end

        -- 7x7 tile grid centered on player.
        -- Each cell: "NN(W|X)" where NN=tile type, W=walkable, X=wall, @=player.
        lines[#lines+1] = ""
        lines[#lines+1] = "--- 7x7 tile grid (W=walkable X=wall D=door @=player ?=nil) ---"
        for dy = -3, 3 do
            local row_parts = {}
            for dx = -3, 3 do
                local tx, ty = px + dx, py + dy
                local cell
                if tx == px and ty == py then
                    cell = " @ "
                else
                    local t = map_reader.get_tile_type(map_id, tx, ty)
                    if t == nil then
                        cell = " ? "
                    else
                        local w = map_reader.is_walkable(map_id, tx, ty)
                        cell = string.format("%2dX", t)
                        if w then cell = string.format("%2dW", t) end
                    end
                end
                row_parts[#row_parts+1] = cell
            end
            local label
            if dy < 0 then label = "N" .. (-dy)
            elseif dy > 0 then label = "S" .. dy
            else label = "=="
            end
            lines[#lines+1] = table.concat(row_parts, "|") .. "  (" .. label .. ")"
        end

        -- NPC positions: raw RAM bytes vs. what blocking_positions contains.
        -- This lets us diagnose coordinate mismatches between where NPCs
        -- appear on screen and what coordinates the pathfinder sees.
        lines[#lines+1] = ""
        lines[#lines+1] = "--- NPC Positions (raw from RAM 0x0051+) ---"
        lines[#lines+1] = "(Only active slots shown — skips x=0,y=0 and x=31,y=31)"
        for i = 0, addr.NPC_COUNT - 1 do
            local base = addr.NPC_DATA_START + (i * addr.NPC_ENTRY_SIZE)
            local byte0 = memory.readbyte(base)
            local byte1 = memory.readbyte(base + 1)
            local sprite_type = AND(byte0, 0xE0) / 32
            local npc_x = AND(byte0, 0x1F)
            local npc_y = AND(byte1, 0x1F)
            -- Show active entries only
            if not (npc_x == 0 and npc_y == 0)
            and not (npc_x == 31 and npc_y == 31) then
                -- Calculate offset from player to help spot the match
                local dx = npc_x - px
                local dy = npc_y - py
                lines[#lines+1] = string.format(
                    "  Slot %2d: byte0=0x%02X byte1=0x%02X -> x=%d, y=%d  sprite=%d  (player offset: dx=%+d dy=%+d)",
                    i, byte0, byte1, npc_x, npc_y, sprite_type, dx, dy)
            end
        end

        -- Show what get_blocking_positions() returns.
        -- If this list is wrong, pathfinding won't avoid those tiles.
        lines[#lines+1] = ""
        lines[#lines+1] = "--- Blocking Positions (what pathfinder avoids) ---"
        local blocking = objects.get_blocking_positions()
        if #blocking == 0 then
            lines[#lines+1] = "  (none — either no NPCs/chests, or object list not built yet)"
        else
            for _, pos in ipairs(blocking) do
                local dx = pos.x - px
                local dy = pos.y - py
                lines[#lines+1] = string.format(
                    "  Blocked x=%d, y=%d  (player offset: dx=%+d dy=%+d)",
                    pos.x, pos.y, dx, dy)
            end
        end

        -- Full ROM chest table dump — shows ALL chest entries across all maps.
        -- This helps diagnose cases where chests are stored under a different
        -- map ID than what RAM shows (e.g., throne room shows RAM map 5 but
        -- chest table might use map 9 for some entries).
        lines[#lines+1] = ""
        lines[#lines+1] = "--- Full ROM Chest Table (all maps) ---"
        local num_total = math.floor(
            (addr.ROM_CHEST_END - addr.ROM_CHEST_START + 1) / addr.ROM_CHEST_SIZE)
        for i = 0, num_total - 1 do
            local base = addr.ROM_CHEST_START + (i * addr.ROM_CHEST_SIZE)
            local cm = rom.readbyte(base)
            local cx = rom.readbyte(base + 1)
            local cy_raw = rom.readbyte(base + 2)
            local cc = rom.readbyte(base + 3)
            local cy_vis = cy_raw        -- game_y = ROM_y directly (no offset)
            local marker = (cm == map_id) and "  <== THIS MAP" or ""
            lines[#lines+1] = string.format(
                "  [%2d] map=%2d  x=%2d  ROM_y=%2d (visual_y=%2d)  content=0x%02X%s",
                i, cm, cx, cy_raw, cy_vis, cc, marker)
        end

        local f = io.open("tile_diag.txt", "w")
        if f then
            f:write(table.concat(lines, "\n"))
            f:close()
        end
    end

    -- X key (default): Toggle NPC position freeze on/off.
    -- When frozen, NPC bytes are locked to their snapshotted positions so
    -- pathfinding routes stay valid even if guards wander. Turn off after
    -- reaching your destination so NPCs resume normal movement.
    if is_key_pressed(keys, config.get("key_freeze_npcs")) then
        if npc_freeze_active then
            npc_freeze_active = false
            frozen_npc_snapshot = {}
            tolk.output_interrupt("NPCs unfrozen.")
        else
            capture_npc_snapshot()
            npc_freeze_active = true
            tolk.output_interrupt("NPCs frozen.")
        end
    end

    -- ============================================================
    -- Object Navigation (J/K/L/O/F)
    -- ============================================================
    -- Cycle through map objects (NPCs, stairs, chests, exits) and
    -- hear direction + distance information for each one.
    -- Follows the J/K/L convention from pokemon-access and FF mods.

    -- L key (default): Next object in list
    if is_key_pressed(keys, config.get("key_object_next")) then
        local obj = objects.next_object()
        if obj then
            tolk.output_interrupt(objects.describe_current())
        else
            tolk.output_interrupt("No objects found")
        end
    end

    -- J key (default): Previous object in list
    if is_key_pressed(keys, config.get("key_object_prev")) then
        local obj = objects.prev_object()
        if obj then
            tolk.output_interrupt(objects.describe_current())
        else
            tolk.output_interrupt("No objects found")
        end
    end

    -- K key (default): Describe current object (re-read with updated distance)
    if is_key_pressed(keys, config.get("key_object_current")) then
        tolk.output_interrupt(objects.describe_current())
    end

    -- O key (default): Pathfind to current object.
    -- For NPCs: route to an adjacent tile (player can't walk onto the NPC).
    -- For everything else (stairs, chests, exits): route to the exact tile.
    -- NPC positions are passed so the pathfinder routes around other NPCs
    -- that physically block tiles along the way.
    if is_key_pressed(keys, config.get("key_pathfind")) then
        local obj = objects.current_object()
        if obj then
            last_pathfind_obj = obj  -- Remember for auto re-routing on block
            local map_id, px, py = nav.get_position()
            -- Force-refresh NPC positions right now so blocking reflects
            -- current NPC locations, not wherever they were up to 20 frames ago.
            objects.update_npcs()
            -- Only freeze NPCs when the TARGET is an NPC. Freezing is needed
            -- so the target NPC stays in place while the player walks to it.
            -- For exits, stairs, chests, and doors the target is a fixed tile,
            -- so freezing just locks guards into positions that may block the
            -- route — especially bad when guards permanently flank an exit.
            if obj.type == objects.TYPE_NPC then
                capture_npc_snapshot()
                npc_freeze_active = true
            end
            local blocking = objects.get_blocking_positions()
            local result
            -- Use adjacent pathfinding when:
            --   TYPE_NPC  — player stands next to NPCs (can't walk onto them)
            --   TYPE_DOOR — locked door tile, player interacts from adjacent
            --   Any non-walkable tile — e.g. exits where the warp fires at a wall
            --                           (like the throne room south arch at type-15)
            -- Chests use direct pathfinding: the player walks ONTO the chest tile
            -- to open it, so distance-0 (not distance-1) is the goal.
            local target_walkable = map_reader.is_walkable(map_id, obj.x, obj.y)
            local face_dir
            if obj.type == objects.TYPE_NPC
            or obj.type == objects.TYPE_DOOR
            or not target_walkable then
                result, face_dir = pathfinder.pathfind_to_adjacent(map_id, px, py, obj.x, obj.y, blocking)
            else
                result = pathfinder.pathfind_to(map_id, px, py, obj.x, obj.y, blocking)
            end
            local msg = obj.name .. ". " .. result
            if face_dir then
                msg = msg .. ". Face " .. face_dir
            end
            tolk.output_interrupt(msg)
        else
            tolk.output_interrupt("No object selected")
        end
    end

    -- F key (default): Cycle object filter (All / NPCs / Exits / Chests / Stairs)
    if is_key_pressed(keys, config.get("key_filter")) then
        local filter_name = objects.next_filter()
        -- Announce the new filter and the first object in it
        local count = objects.get_count()
        if count > 0 then
            tolk.output_interrupt(filter_name .. ". " .. objects.describe_current())
        else
            tolk.output_interrupt(filter_name .. ". No objects")
        end
    end
end

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

-- check_hp_mp_changes(): Announce HP/MP changes (damage, healing, spell use).
local function check_hp_mp_changes()
    local hp = memory.readbyte(addr.CURRENT_HP)
    local mp = memory.readbyte(addr.CURRENT_MP)

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
    local level = memory.readbyte(addr.LEVEL)
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
    local gold       = memory.readbyte(addr.GOLD_LO) + memory.readbyte(addr.GOLD_HI) * 256
    local magic_keys = memory.readbyte(addr.KEYS)
    local herbs      = memory.readbyte(addr.HERBS)
    local items = {
        memory.readbyte(addr.ITEMS_START),
        memory.readbyte(addr.ITEMS_START + 1),
        memory.readbyte(addr.ITEMS_START + 2),
        memory.readbyte(addr.ITEMS_START + 3),
    }

    local gained = false
    if prev_gold       ~= nil and gold       > prev_gold       then gained = true end
    if prev_magic_keys ~= nil and magic_keys > prev_magic_keys then gained = true end
    if prev_herbs      ~= nil and herbs      > prev_herbs      then gained = true end
    if prev_items ~= nil then
        for i = 1, 4 do
            if items[i] ~= prev_items[i] then gained = true; break end
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
    prev_items      = items
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
        -- Clear the pathfind target so auto re-routing doesn't try to reach
        -- an object from the previous map.
        last_pathfind_obj = nil
        -- Clear NPC freeze — NPCs on the new map start fresh and their
        -- previous positions are irrelevant.
        npc_freeze_active = false
        frozen_npc_snapshot = {}
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

local function is_row1_interior_context()
    if not in_gameplay then return false end
    local map_id = memory.readbyte(addr.MAP_ID)
    local py = memory.readbyte(addr.PLAYER_Y)
    return map_id ~= 0x00 and py <= 1
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

local function field_dialogue_guard_active()
    if not in_gameplay then return false end
    if current_joy_any then return false end
    if menu.is_open() or submenu_mode ~= nil or menu.is_yesno_active() then return false end
    return recent_field_action_frames == 0
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

    local lower_dialogue_active = text.read_dialogue_window_filtered(get_scroll_tiles()) ~= ""
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
        local mid = memory.readbyte(addr.MAP_ID)
        local py  = memory.readbyte(addr.PLAYER_Y)
        if not (mid ~= 0x00 and py <= 1) then
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
        elseif a_just then
            -- North-edge suppression avoids false spoken openings from map-tile
            -- noise, but a real command-menu open still comes from an A press.
            -- Mark it confirmed silently so selecting STATUS without first
            -- moving the cursor still works at y<=1.
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
            local question = text.read_dialogue_window_filtered(get_scroll_tiles())
            -- Only announce the question if it contains real dialogue text
            -- (at least one lowercase letter). Purely-uppercase strings are either
            -- command menu tiles that haven't been overwritten yet, or the player's
            -- name partially rendered before the rest of the sentence appeared.
            -- The normal dialogue stability path will catch the full text once it
            -- finishes rendering.
            if question ~= "" and question ~= announced_dialogue and question:find("[a-z]") then
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
    local py = memory.readbyte(addr.PLAYER_Y)
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
        local d9 = memory.readbyte(addr.MENU_CURSOR_Y)
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
        local d9 = memory.readbyte(addr.MENU_CURSOR_Y)
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
        local d8 = memory.readbyte(addr.MENU_CURSOR_X)
        local d9 = memory.readbyte(addr.MENU_CURSOR_Y)
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
    local mid = memory.readbyte(addr.MAP_ID)
    local py  = memory.readbyte(addr.PLAYER_Y)
    local at_y1 = in_gameplay and mid ~= 0x00 and py <= 3

    -- Use the filtered reader for ALL y positions: it applies a per-row
    -- lowercase filter to exclude status bar fragments (uppercase "E", "G",
    -- digits) that bleed into rows 19-29 at certain NES scroll positions.
    local dialogue = text.read_dialogue_window_filtered(get_scroll_tiles())

    if field_dialogue_guard_active() or
       (movement_dialogue_hold_frames > 0 and not current_joy_any and not menu.is_open()
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
        if clean_stable_frames == STABLE_THRESHOLD then
            if clean:find("[a-z]") and clean ~= announced_dialogue then
                -- Real response text or NPC dialogue — announce only the new portion.
                -- DW1 scrolls the dialogue window so successive windows share a
                -- tail/prefix boundary. strip_overlap prevents re-announcing the
                -- question that already appeared at the top of the next window.
                local new_text = strip_overlap(announced_dialogue, clean)
                if new_text ~= "" then
                    -- First page: interrupt to clear any prior menu speech.
                    -- Continuation pages: queue so the speech flows without
                    -- each scroll step cutting off the one before it.
                    if announced_dialogue == "" then
                        tolk.output_interrupt(new_text)
                    else
                        tolk.output(new_text)
                    end
                end
                announced_dialogue = clean
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
    if stable_frames == STABLE_THRESHOLD then
        if dialogue ~= "" and dialogue ~= announced_dialogue then
            -- Absorb purely-uppercase text (command menu tiles, map tiles)
            -- without announcing — same principle as the at_y1 uppercase filter.
            -- Real NPC dialogue always contains at least one lowercase letter.
            if not dialogue:find("[a-z]") then
                announced_dialogue = dialogue
            else
                local new_text = strip_overlap(announced_dialogue, dialogue)
                if new_text ~= "" then
                    if announced_dialogue == "" then
                        tolk.output_interrupt(new_text)
                    else
                        tolk.output(new_text)
                    end
                end
                announced_dialogue = dialogue
            end
        elseif dialogue == "" and announced_dialogue ~= "" then
            -- Dialogue window closed — reset so we catch the next one
            announced_dialogue = ""
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

    if field_dialogue_guard_active() or
       (movement_dialogue_hold_frames > 0 and not current_joy_any and submenu_mode == nil
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
    local map_id = memory.readbyte(addr.MAP_ID)
    if in_gameplay and map_id ~= 0x00 then
        local player_y = memory.readbyte(addr.PLAYER_Y)
        if player_y <= 1 then
            local player_x = memory.readbyte(addr.PLAYER_X)
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
    local lower_dialogue = text.read_dialogue_window_filtered(get_scroll_tiles())
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
    if in_gameplay and map_id ~= 0x00 and memory.readbyte(addr.PLAYER_Y) <= 1 then
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

    -- Real dialogue detected — mark the window as active.
    upper_dialogue_active = true

    -- Skip if we already announced this exact text
    if upper == announced_upper_dialogue then return end

    if new_text ~= "" then
        tolk.output_interrupt(new_text)
    end
    announced_upper_dialogue = upper
end

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
    row1_trace_frame = frame_count

    -- Read keyboard state for hotkeys
    local keys = input.get()
    current_joy = joypad.read(1)
    current_joy_any = joypad_has_input(current_joy)

    -- Process on-demand hotkeys (player-initiated)
    handle_hotkeys(keys)

    -- Save key state for next frame's key-down detection
    prev_keys = keys

    -- Get current game state
    local game_state = state.check_for_changes()
    in_gameplay = (game_state.state ~= state.STATE_TITLE)

    -- Startup grace period: during the first STARTUP_FRAMES frames,
    -- let all the "previous" tracking values initialize silently.
    -- We still run the detection functions (so prev_ values get set),
    -- but we suppress their announcements by skipping the output block.
    if startup_counter < STARTUP_FRAMES then
        startup_counter = startup_counter + 1

        -- Silently initialize previous-frame values so they don't
        -- trigger false change detections after the grace period ends.
        prev_hp = memory.readbyte(addr.CURRENT_HP)
        prev_mp = memory.readbyte(addr.CURRENT_MP)
        prev_level = memory.readbyte(addr.LEVEL)
        prev_gold       = memory.readbyte(addr.GOLD_LO) + memory.readbyte(addr.GOLD_HI) * 256
        prev_magic_keys = memory.readbyte(addr.KEYS)
        prev_herbs      = memory.readbyte(addr.HERBS)
        prev_items = {
            memory.readbyte(addr.ITEMS_START),
            memory.readbyte(addr.ITEMS_START + 1),
            memory.readbyte(addr.ITEMS_START + 2),
            memory.readbyte(addr.ITEMS_START + 3),
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
                tolk.output("Title screen.")
            elseif game_state.state == state.STATE_BATTLE then
                tolk.output("Battle!")
            elseif game_state.state == state.STATE_FIELD then
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
                prev_hp         = memory.readbyte(addr.CURRENT_HP)
                prev_mp         = memory.readbyte(addr.CURRENT_MP)
                prev_level      = memory.readbyte(addr.LEVEL)
                prev_gold       = memory.readbyte(addr.GOLD_LO) + memory.readbyte(addr.GOLD_HI) * 256
                prev_magic_keys = memory.readbyte(addr.KEYS)
                prev_herbs      = memory.readbyte(addr.HERBS)
                prev_items = {
                    memory.readbyte(addr.ITEMS_START),
                    memory.readbyte(addr.ITEMS_START + 1),
                    memory.readbyte(addr.ITEMS_START + 2),
                    memory.readbyte(addr.ITEMS_START + 3),
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
                    prev_hp    = memory.readbyte(addr.CURRENT_HP)
                    prev_mp    = memory.readbyte(addr.CURRENT_MP)
                    prev_level = memory.readbyte(addr.LEVEL)
                    skip_first_hp_check = false
                else
                    check_hp_mp_changes()
                    check_level_up()
                end
            end
            check_command_menu()

            -- Keep the object list fresh: detect map changes and
            -- periodically re-read NPC positions (they move around).
            local map_id = memory.readbyte(addr.MAP_ID)
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
            check_dialogue()
            check_upper_dialogue()
        else
            check_title_screen()
        end
    end

    -- Increment frame counter (wraps around to avoid overflow)
    frame_count = (frame_count + 1) % 600

    -- Auto-step: extend brief D-pad taps into full tile steps.
    -- Only active when the player is walking on the field (not in
    -- menus, dialogue, battle, or on the title screen).
    local can_walk = game_state.state == state.STATE_FIELD
                     and not menu.is_open()
                     and submenu_mode == nil
                     and prev_dialogue == ""
                     and not upper_dialogue_active
    auto_step.update(can_walk)

    -- Advance the emulator by one frame. This is required —
    -- without it, the emulator hangs.
    FCEU.frameadvance()

    -- If NPC freeze is active, restore NPC position bytes to their snapshot.
    -- The NES game's NPC movement routines ran during frameadvance and may
    -- have written new positions; we undo that here so our code sees stable
    -- NPC coordinates on the next frame.
    apply_npc_freeze()
end
