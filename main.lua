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
local function handle_hotkeys(keys)
    -- P key: Read current position (map name + coordinates)
    if is_key_pressed(keys, "P") then
        tolk.output_interrupt(nav.get_position_string())
    end

    -- H key: Read current HP and MP
    if is_key_pressed(keys, "H") then
        local hp = memory.readbyte(addr.CURRENT_HP)
        local max_hp = memory.readbyte(addr.MAX_HP)
        local mp = memory.readbyte(addr.CURRENT_MP)
        local max_mp = memory.readbyte(addr.MAX_MP)
        tolk.output_interrupt("HP " .. hp .. " of " .. max_hp ..
                              ", MP " .. mp .. " of " .. max_mp)
    end

    -- L key: Read player level
    if is_key_pressed(keys, "L") then
        local level = memory.readbyte(addr.LEVEL)
        tolk.output_interrupt("Level " .. level)
    end

    -- G key: Read gold
    if is_key_pressed(keys, "G") then
        local gold = memory.readbyte(addr.GOLD_LO) +
                     memory.readbyte(addr.GOLD_HI) * 256
        tolk.output_interrupt(gold .. " gold")
    end

    -- E key: Read experience
    if is_key_pressed(keys, "E") then
        local exp = memory.readbyte(addr.EXPERIENCE_LO) +
                    memory.readbyte(addr.EXPERIENCE_HI) * 256
        tolk.output_interrupt(exp .. " experience")
    end

    -- S key: Read full stats
    if is_key_pressed(keys, "S") then
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

    -- T key: Read all text currently on screen (debug/exploration)
    if is_key_pressed(keys, "T") then
        local screen_text = text.get_full_screen_text()
        if screen_text ~= "" then
            tolk.output_interrupt(screen_text)
        else
            tolk.output_interrupt("No text on screen")
        end
    end

    -- M key: Diagnostic — read raw menu cursor values.
    -- Use this while navigating the command menu to discover
    -- what X/Y values the game uses for each option.
    -- Once we've mapped all 6 items, this hotkey can be removed
    -- or repurposed.
    if is_key_pressed(keys, "M") then
        tolk.output_interrupt(menu.get_cursor_info())
    end

    -- D key: Diagnostic — dump raw PPU tile bytes for rows 10-22.
    -- This helps discover what tile values the game uses for text
    -- that our character table doesn't decode yet.
    -- Remove this hotkey once debugging is done.
    if is_key_pressed(keys, "D") then
        local dump = {}
        for row = 10, 22 do
            local bytes = text.read_ppu_row(row)
            local hex_parts = {}
            for i = 1, #bytes do
                -- Format each byte as 2-digit hex
                hex_parts[i] = string.format("%02X", bytes[i])
            end
            dump[#dump + 1] = "Row " .. row .. ": " .. table.concat(hex_parts, " ")
        end
        -- Write to a file since this is too much for speech
        local f = io.open("ppu_dump.txt", "w")
        if f then
            f:write(table.concat(dump, "\n"))
            f:close()
            tolk.output_interrupt("PPU dump written to ppu_dump.txt")
        else
            tolk.output_interrupt("Failed to write dump file")
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
    for start = 1, #old do
        local suffix = old:sub(start)
        if new:sub(1, #suffix) == suffix then
            local remainder = new:sub(#suffix + 1)
            -- Trim leading spaces from the new portion
            remainder = remainder:match("^%s*(.-)$") or remainder
            if remainder ~= "" then
                return remainder
            end
        end
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
                tolk.output(new_text)
            end
            announced_dialogue = dialogue
        elseif dialogue == "" and announced_dialogue ~= "" then
            -- Dialogue window closed — reset so we catch the next one
            announced_dialogue = ""
        end
    end
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
        end

        -- Dialogue check — runs every frame to track text changes.
        -- This runs even on the title screen since text can appear there too.
        check_dialogue()
    end

    -- Increment frame counter (wraps around to avoid overflow)
    frame_count = (frame_count + 1) % 600

    -- Advance the emulator by one frame. This is required —
    -- without it, the emulator hangs.
    FCEU.frameadvance()
end
