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

    -- Announce state transitions
    if game_state.changed then
        if game_state.state == state.STATE_BATTLE then
            tolk.output("Battle!")
        end
    end

    -- Run automatic checks based on current state
    -- These detect changes by comparing to previous-frame values.
    check_map_change()
    check_hp_mp_changes()
    check_level_up()

    -- Dialogue check — runs every frame to track text changes.
    -- The stabilization logic inside check_dialogue() waits for text
    -- to stop changing before announcing, so running every frame is
    -- safe and gives us accurate timing.
    check_dialogue()

    -- Increment frame counter (wraps around to avoid overflow)
    frame_count = (frame_count + 1) % 600

    -- Advance the emulator by one frame. This is required —
    -- without it, the emulator hangs.
    FCEU.frameadvance()
end
