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

-- ============================================================
-- Startup
-- ============================================================
-- Announce that the accessibility mod is loaded and ready.
tolk.output("Dragon Warrior Accessibility Mod loaded.")
FCEU.message("DW Access Mod loaded")

-- ============================================================
-- Previous-Frame State
-- ============================================================
-- We track values from the previous frame so we only speak when
-- something actually changes. Without this, we'd repeat the same
-- info 60 times per second.

local prev_hp = nil           -- Previous HP (to detect damage/healing)
local prev_mp = nil           -- Previous MP (to detect spell use)
local prev_level = nil        -- Previous level (to detect level-ups)

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

-- Frame counter for throttling periodic checks
-- Some checks don't need to run every frame; we use this to
-- spread work across frames.
local frame_count = 0

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

    -- Stats: Read full stats
    if is_key_pressed(keys, config.get("key_stats")) then
        local level = memory.readbyte(addr.LEVEL)
        local hp = memory.readbyte(addr.CURRENT_HP)
        local max_hp = memory.readbyte(addr.MAX_HP)
        local mp = memory.readbyte(addr.CURRENT_MP)
        local max_mp = memory.readbyte(addr.MAX_MP)
        local str = memory.readbyte(addr.STRENGTH)
        local agi = memory.readbyte(addr.AGILITY)
        local atk = memory.readbyte(addr.ATTACK)
        local def = memory.readbyte(addr.DEFENSE)
        tolk.output_interrupt(
            "Level " .. level ..
            ", HP " .. hp .. " of " .. max_hp ..
            ", MP " .. mp .. " of " .. max_mp ..
            ", Attack " .. atk ..
            ", Defense " .. def ..
            ", Strength " .. str ..
            ", Agility " .. agi
        )
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

    -- Diagnostic: dump raw PPU tile bytes for rows 10-22
    if is_key_pressed(keys, config.get("key_diag_ppu_dump")) then
        local dump = {}
        for row = 10, 22 do
            local bytes = text.read_ppu_row(row)
            local hex_parts = {}
            for i = 1, #bytes do
                hex_parts[i] = string.format("%02X", bytes[i])
            end
            dump[#dump + 1] = "Row " .. row .. ": " .. table.concat(hex_parts, " ")
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

    -- O key (default): Pathfind to current object
    -- Uses A* for interior maps, direction+distance for overworld
    if is_key_pressed(keys, config.get("key_pathfind")) then
        local obj = objects.current_object()
        if obj then
            local map_id, px, py = nav.get_position()
            local result = pathfinder.pathfind_to(map_id, px, py, obj.x, obj.y)
            tolk.output_interrupt(obj.name .. ". " .. result)
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

-- check_map_change(): Announce when the player enters a new area.
local function check_map_change()
    local changes = nav.check_for_changes()
    if changes.map_changed and changes.map_name then
        tolk.output(changes.map_name)
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

-- check_command_menu(): Announce command menu opening and cursor movement.
-- When the player opens the command menu, we announce "Command menu" and
-- the currently highlighted item. As they move the cursor, we announce
-- each new item they land on.
local function check_command_menu()
    local changes = menu.check_for_changes()

    if changes.menu_opened then
        -- Menu just opened — announce it along with the current item
        local item = changes.item_name or ("Cursor " .. changes.cursor_x .. ", " .. changes.cursor_y)
        tolk.output("Command. " .. item)
    elseif changes.cursor_moved and not changes.menu_closed then
        -- Cursor moved within the open menu — announce the new item
        local item = changes.item_name
        if item then
            tolk.output(item)
        else
            -- Unknown cursor position — announce raw values so the user
            -- can report them for mapping
            tolk.output("Cursor " .. changes.cursor_x .. ", " .. changes.cursor_y)
        end
    end
end

-- check_dialogue(): Read dialogue window and announce when text stabilizes.
-- Dragon Warrior renders text one character at a time, so we wait until
-- the text stops changing for STABLE_THRESHOLD frames before announcing.
-- This prevents reading partial text like "The Dragonl" mid-render.
-- When text does stabilize, we strip any overlap with the previous
-- announcement so we only speak genuinely new text.
local function check_dialogue()
    local dialogue = text.read_dialogue_window()

    if dialogue ~= prev_dialogue then
        -- Text is still changing — reset the stability counter
        stable_frames = 0
        prev_dialogue = dialogue
    else
        -- Text hasn't changed since last check — increment stability counter
        stable_frames = stable_frames + 1
    end

    -- Once text has been stable long enough and differs from what we
    -- already announced, speak only the new portion
    if stable_frames == STABLE_THRESHOLD then
        if dialogue ~= "" and dialogue ~= announced_dialogue then
            local new_text = strip_overlap(announced_dialogue, dialogue)
            if new_text ~= "" then
                tolk.output_interrupt(new_text)
            end
            announced_dialogue = dialogue
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
    -- Skip when the command menu is open — menu text is handled by
    -- check_command_menu(), and reading menu items as dialogue would
    -- produce duplicate/incorrect announcements.
    if menu.is_open() then
        upper_stable_frames = 0
        return
    end

    local upper = text.read_upper_window()

    -- Track changes with stabilization (same approach as lower dialogue)
    if upper ~= prev_upper_dialogue then
        upper_stable_frames = 0
        prev_upper_dialogue = upper
    else
        upper_stable_frames = upper_stable_frames + 1
    end

    -- Only process once text has stabilized
    if upper_stable_frames ~= STABLE_THRESHOLD then return end

    -- Determine if this is just the status display (no dialogue window).
    -- The status display always contains "LV" and "HP" markers and is
    -- relatively short (~35-45 chars). When it's just the status display
    -- with no dialogue overlay, we update our baseline and move on.
    local is_just_status = text.is_status_text(upper) and #upper < 50

    -- Also check for command menu text. After the menu closes, its tiles
    -- may linger in the PPU for several frames. The "COMMAND" header word
    -- is a reliable indicator — it only appears as the menu window title,
    -- never in dialogue (which uses mixed case, not all-caps "COMMAND").
    local has_menu_text = upper:find("COMMAND") ~= nil

    if is_just_status or has_menu_text then
        -- Status display or stale command menu — not dialogue.
        -- Only update the baseline when it's genuinely the status display
        -- (not command menu remnants), so the baseline stays clean.
        if is_just_status then
            upper_baseline = upper
        end
        if upper_dialogue_active then
            upper_dialogue_active = false
            announced_upper_dialogue = ""
        end
        return
    end

    -- Non-status text present in the upper area — it's a dialogue window!
    upper_dialogue_active = true

    -- Skip if we already announced this exact text
    if upper == announced_upper_dialogue then return end

    -- Extract the genuinely new text. Strategy depends on whether the
    -- status display is still visible alongside the dialogue.
    local new_text
    if text.is_status_text(upper) then
        -- Status display still visible + extra dialogue content.
        -- Strip the known status baseline to get just the dialogue.
        new_text = strip_overlap(upper_baseline, upper)
    else
        -- Status display was entirely replaced by the dialogue window.
        -- The entire upper text is dialogue content.
        new_text = upper
    end

    -- If stripping the baseline didn't help (no overlap found, returned
    -- the full text including status), and we have a previous announcement,
    -- try stripping that instead to find just the NEW portion.
    if new_text == upper and announced_upper_dialogue ~= "" then
        new_text = strip_overlap(announced_upper_dialogue, upper)
    end

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
    -- Read keyboard state for hotkeys
    local keys = input.get()

    -- Process on-demand hotkeys (player-initiated)
    handle_hotkeys(keys)

    -- Save key state for next frame's key-down detection
    prev_keys = keys

    -- Get current game state
    local game_state = state.check_for_changes()

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
        nav.check_for_changes()   -- Initialize map/position tracking
        menu.check_for_changes()  -- Initialize menu cursor tracking

        -- On the very last frame of the grace period, announce current
        -- state so the player knows where they are. Without this, the
        -- title screen transition would be missed since it happened
        -- during the grace period.
        if startup_counter == STARTUP_FRAMES then
            -- Initialize the upper dialogue baseline so the status display
            -- text doesn't get announced as "new dialogue" after the grace period.
            upper_baseline = text.read_upper_window()
            prev_upper_dialogue = upper_baseline

            if game_state.state == state.STATE_TITLE then
                tolk.output("Title screen.")
            end
        end
    else
        -- Normal operation: announce state transitions and changes

        -- Announce state transitions
        if game_state.changed then
            if game_state.state == state.STATE_TITLE then
                -- Arrived at title/save screen — read whatever text is on screen.
                -- Use T hotkey to re-read if needed.
                local screen_text = text.get_full_screen_text()
                if screen_text ~= "" then
                    tolk.output("Title screen. " .. screen_text)
                else
                    tolk.output("Title screen.")
                end
            elseif game_state.state == state.STATE_BATTLE then
                tolk.output("Battle!")
            elseif game_state.state == state.STATE_FIELD then
                -- Transitioning from title to field means a game was loaded
                if game_state.prev_state == state.STATE_TITLE then
                    tolk.output("Game started.")
                end
            end
        end

        -- Run automatic checks based on current state.
        -- Skip gameplay checks while on the title screen — the stat
        -- addresses contain garbage/uninitialized data there.
        if game_state.state ~= state.STATE_TITLE then
            check_map_change()
            check_hp_mp_changes()
            check_level_up()
            check_command_menu()

            -- Keep the object list fresh: detect map changes and
            -- periodically re-read NPC positions (they move around).
            local map_id = memory.readbyte(addr.MAP_ID)
            objects.check_refresh(map_id)
        end

        -- Dialogue checks — run every frame to track text changes.
        -- Lower dialogue (rows 19-29): standard dialogue area.
        -- Upper dialogue (rows 1-18): chest messages, shop text, etc.
        -- Both run even on the title screen since text can appear there too.
        check_dialogue()
        check_upper_dialogue()
    end

    -- Increment frame counter (wraps around to avoid overflow)
    frame_count = (frame_count + 1) % 600

    -- Auto-step: extend brief D-pad taps into full tile steps.
    -- Only active when the player is walking on the field (not in
    -- menus, dialogue, battle, or on the title screen).
    local can_walk = game_state.state == state.STATE_FIELD
                     and not menu.is_open()
                     and prev_dialogue == ""
                     and not upper_dialogue_active
    auto_step.update(can_walk)

    -- Advance the emulator by one frame. This is required —
    -- without it, the emulator hangs.
    FCEU.frameadvance()
end
