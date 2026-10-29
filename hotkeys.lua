-- hotkeys.lua
-- Keyboard hotkey handling for on-demand information.
--
-- Processes key-down events (rising edge detection) for player-triggered
-- actions like reading position, HP/MP, stats, and navigating objects.
-- Also contains diagnostic dump hotkeys for development.
--
-- Extracted from main.lua to reduce its size and improve modularity.
-- The main loop calls hotkeys.update(keys) once per frame, passing
-- the table from input.get().
-- update(keys, game_state, allow_object_hotkeys, object_hotkey_block_reason)
-- accepts optional trailing arguments so callers can disable object navigation
-- during non-idle interactive states (command/merchant/dialogue/autowalk).
-- If omitted, the legacy behavior applies.

local tolk       = require "tolk"
local addr       = require "addresses"
local chars      = require "chars"
local nav        = require "navigation"
local text       = require "text"
local menu       = require "menu"
local config     = require "config"
local objects    = require "objects"
local items      = require "items"
local map_reader = require "map_reader"
local route_mgr  = require "route_manager"
local auto_step  = require "auto_step"
local overworld_routes = require "overworld_routes"
local debug_tools = require "debug_tools"
local key_combo  = require "key_combo"
local emulator_compat = require "emulator_compat"
local map_descriptions = require "map_descriptions"
local snapshot   = require "game_snapshot"

local M = {}

-- ============================================================
-- Key State Tracking
-- ============================================================
-- We track which keys were pressed last frame to detect fresh presses
-- (key-down events) and avoid repeating while a key is held.

local prev_keys = {}

local pending_object_nav_speech = nil
local pending_object_nav_frames = 0
local object_nav_speech_queued_this_frame = false
local teleport_handler = nil
local route_guidance_key_pressed
local route_guidance_key_down
local pending_auto_walk_after_key_release = false
local OBJECT_HOTKEY_DIRECTION_SUPPRESS_FRAMES = 8
local MOVEMENT_SETTLE_BLOCK_REASON = "Wait for movement to finish"
local DIALOGUE_BLOCK_REASONS = {
    ["Wait for dialogue to finish"] = true,
    ["Wait for the upper window to clear"] = true,
}
local blocked_object_hotkey_message

-- is_key_pressed(keys, key_name): Check if a key was just pressed
-- this frame (wasn't pressed last frame). This prevents the action
-- from firing repeatedly while the key is held down.
local function is_key_pressed(keys, key_name)
    return key_combo.is_pressed(keys, prev_keys, key_name)
end

local function is_teleport_key_pressed(keys, config_key)
    return key_combo.is_trigger_pressed(keys, prev_keys, config.get(config_key))
end

local function allow_field_object_hotkeys(game_state, allow_object_hotkeys)
    if game_state ~= nil and game_state.state ~= "field" then
        return false
    end

    if allow_object_hotkeys == nil then
        return true
    end

    return allow_object_hotkeys
end

local OBJECT_HOTKEY_CONFIG_KEYS = {
    "key_freeze_npcs",
    "key_services",
    "key_object_sort",
    "key_filter_prev",
    "key_filter_all",
    "key_filter_next",
    "key_object_next",
    "key_object_prev",
    "key_object_current",
    "key_pathability_filter",
    "key_route_guidance",
    "key_pathfind",
    "key_auto_walk",
    "key_filter",
    "key_mark_visited",
    "key_teleport_exact",
    "key_teleport_north",
    "key_teleport_south",
    "key_teleport_west",
    "key_teleport_east",
}

local function blocked_object_hotkey_pressed(keys)
    for _, config_key in ipairs(OBJECT_HOTKEY_CONFIG_KEYS) do
        local pressed = false
        if config_key:match("^key_teleport_") then
            pressed = is_teleport_key_pressed(keys, config_key)
        elseif config_key ~= "key_route_guidance" then
            pressed = is_key_pressed(keys, config.get(config_key))
        end
        if pressed then
            return config_key
        end
    end
    if route_guidance_key_pressed and route_guidance_key_pressed(keys) then
        return "key_route_guidance"
    end
    return nil
end

local function blocked_object_hotkey_down(keys)
    for _, config_key in ipairs(OBJECT_HOTKEY_CONFIG_KEYS) do
        if config_key ~= "key_route_guidance" and key_combo.is_down(keys, config.get(config_key)) then
            return config_key
        end
    end
    if route_guidance_key_down and route_guidance_key_down(keys) then
        return "key_route_guidance"
    end
    return nil
end

local function auto_walk_key_down(keys)
    return key_combo.is_down(keys, config.get("key_auto_walk"))
end

local function log_auto_walk_hotkey(message)
    if debug_tools.info then
        debug_tools.info(message)
        if debug_tools.flush then
            debug_tools.flush()
        end
    end
end

local function suppress_object_hotkey_direction_edges()
    if auto_step and type(auto_step.suppress_direction_tracking) == "function" then
        auto_step.suppress_direction_tracking(OBJECT_HOTKEY_DIRECTION_SUPPRESS_FRAMES)
    end
end

local function blocked_hotkey_is_movement_settle_guard(object_hotkey_block_reason)
    return object_hotkey_block_reason == MOVEMENT_SETTLE_BLOCK_REASON
end

local function blocked_hotkey_is_dialogue_guard(object_hotkey_block_reason)
    return DIALOGUE_BLOCK_REASONS[tostring(object_hotkey_block_reason or "")] == true
end

local function blocked_hotkey_should_suppress_direction_edges(config_key, object_hotkey_block_reason)
    if blocked_hotkey_is_movement_settle_guard(object_hotkey_block_reason)
       or blocked_hotkey_is_dialogue_guard(object_hotkey_block_reason) then
        return true
    end
    return config_key == "key_pathfind"
        or config_key == "key_route_guidance"
        or config_key == "key_pathability_filter"
        or config_key == "key_auto_walk"
end

local function blocked_hotkey_should_suppress_game_input(config_key, object_hotkey_block_reason)
    return not blocked_hotkey_should_suppress_direction_edges(config_key, object_hotkey_block_reason)
end

local function suppress_blocked_hotkey_game_input()
    local qol = rawget(_G, "DW_QOL_STATE")
    if qol and qol.suppress_teleport_input then
        local ok, err = pcall(qol.suppress_teleport_input)
        if not ok and debug_tools.error then
            debug_tools.error("blocked hotkey input suppression failed: " .. tostring(err))
        end
    end
end

local function get_object_nav_speech_delay()
    local frames = tonumber(config.get("object_nav_speech_coalesce_frames")) or 0
    if frames < 0 then return 0 end
    return math.floor(frames)
end

local function clear_object_nav_speech()
    pending_object_nav_speech = nil
    pending_object_nav_frames = 0
end

-- Debug commands replace the stateful objects module while keeping hotkeys
-- alive. Rebind its navigation dependencies so selection, speech, and routing
-- share the new list. Preserve held-key edges and the registered handlers.
function M.refresh_navigation_modules()
    objects = require "objects"
    map_reader = require "map_reader"
    overworld_routes = require "overworld_routes"
    clear_object_nav_speech()
    pending_auto_walk_after_key_release = false
    debug_tools.info("HOTKEY_NAVIGATION_MODULES_REFRESHED")
end

local function speak_now(message)
    clear_object_nav_speech()
    local ok, err = pcall(tolk.output_interrupt, message)
    if not ok and debug_tools.error then
        debug_tools.error("hotkey speech output failed: " .. tostring(err))
    end
end

local function speak_info(message)
    clear_object_nav_speech()
    local ok, err = pcall(tolk.output, message)
    if not ok and debug_tools.error then
        debug_tools.error("hotkey speech output failed: " .. tostring(err))
    end
end

local function speak_position()
    local ok, message = pcall(nav.get_position_string)
    if ok and message and message ~= "" then
        speak_info(message)
        return
    end
    if debug_tools.error then
        debug_tools.error("position hotkey failed: " .. tostring(message))
    end
    speak_info("Position unavailable")
end

local function clear_ppu_cache_for_diagnostic()
    if emulator_compat.clear_ppu_cache then
        emulator_compat.clear_ppu_cache()
    end
end

local function refresh_pathability_if_needed()
    if route_mgr.refresh_object_pathability_filter_if_needed then
        route_mgr.refresh_object_pathability_filter_if_needed()
    end
end

local function refresh_live_objects_for_browse(map_id)
    if map_id == nil then
        map_id = select(1, nav.get_position())
    end
    if objects.needs_refresh and objects.needs_refresh(map_id) then
        return
    end
    if objects.update_npcs then
        objects.update_npcs()
    end
end

local function refresh_object_browser_context(opts)
    opts = opts or {}
    local map_id = select(1, nav.get_position())
    if objects.check_refresh then
        objects.check_refresh(map_id)
    end
    if opts.refresh_live_npcs == true then
        if not (objects.needs_refresh and objects.needs_refresh(map_id)) then
            refresh_live_objects_for_browse(map_id)
        end
    end
    refresh_pathability_if_needed()
end

local function start_deferred_auto_walk_if_released(keys, object_hotkeys_allowed, object_hotkey_block_reason)
    if not pending_auto_walk_after_key_release or auto_walk_key_down(keys) then
        return false
    end

    pending_auto_walk_after_key_release = false
    if not object_hotkeys_allowed then
        if debug_tools.debug then
            debug_tools.debug("AUTO_WALK_HOTKEY_CANCELLED reason=" .. tostring(object_hotkey_block_reason or "blocked"))
        end
        speak_info(blocked_object_hotkey_message(object_hotkey_block_reason))
        return false
    end

    clear_object_nav_speech()
    refresh_object_browser_context({refresh_live_npcs = true})
    log_auto_walk_hotkey("AUTO_WALK_HOTKEY_RELEASE_START")
    route_mgr.autowalk_to_current()
    return true
end

local function stop_auto_walk_from_hotkey()
    local had_deferred_start = pending_auto_walk_after_key_release
    pending_auto_walk_after_key_release = false
    clear_object_nav_speech()

    local had_active_route = route_mgr.stop_auto_walk("player hotkey")
    local had_overworld_route = overworld_routes.is_active
        and overworld_routes.is_active()
        or false
    local route_stop_info = overworld_routes.stop()

    if route_stop_info then
        if route_stop_info.refresh and objects.request_refresh then
            objects.request_refresh()
        end
        if debug_tools.info then
            debug_tools.info("OVERWORLD_ROUTE: " .. tostring(route_stop_info.log or route_stop_info.message))
        end
    end

    if (had_deferred_start or had_active_route) and had_overworld_route then
        speak_now("Auto-walk and route guidance stopped")
    elseif had_deferred_start or had_active_route then
        speak_now("Auto-walk stopped")
    elseif had_overworld_route then
        speak_now("Route guidance stopped")
    else
        speak_info("No auto-walk or route guidance is active")
    end
end

local function speak_filter(filter_name)
    refresh_object_browser_context()
    local count = objects.get_count()
    local label = objects.get_filter_summary and objects.get_filter_summary() or filter_name
    if count > 0 then
        speak_now(label .. ". " .. route_mgr.describe_current_object({
            include_reachability = objects.get_filter_name() == "Services",
            include_service_details = objects.get_filter_name() == "Services",
            include_debug_coords = false,
        }))
    else
        speak_now(label .. ". No objects")
    end
end

local function speak_pathability_filter(info)
    info = info or {}
    if info.unavailable then
        speak_now("Reachability filter unavailable here. " .. info.name)
        return
    end
    local label = info.name or (objects.get_filter_summary and objects.get_filter_summary())
        or objects.get_filter_name()
    local count = info.count or objects.get_count()
    if count > 0 then
        speak_now(label .. ". " .. route_mgr.describe_current_object({
            include_reachability = objects.get_filter_name() == "Services",
            include_service_details = objects.get_filter_name() == "Services",
            include_debug_coords = false,
        }))
    else
        speak_now(label .. ". No objects")
    end
end

local function log_route_event(prefix, info)
    if debug_tools.info and info then
        debug_tools.info(prefix .. ": " .. tostring(info.log or info.message))
    end
end

local function request_route_object_refresh(info)
    if info and info.refresh and objects.request_refresh then
        objects.request_refresh()
    end
end

local function speak_route_guidance()
    clear_object_nav_speech()
    local map_id, x, y = nav.get_position()
    local info, err

    info, err = overworld_routes.guidance_for_object(objects.current_object(), map_id, x, y, {
        terrain_offset = snapshot.terrain_offset,
    })

    if not info then
        local message = tostring(err or "No guided route for selected object. Use O for heading.")
        if debug_tools.info then
            debug_tools.info("OVERWORLD_ROUTE: event=no_route message=" .. message)
        end
        speak_info(message)
        return
    end

    request_route_object_refresh(info)
    log_route_event("OVERWORLD_ROUTE", info)
    speak_info(info.message)
end

local function speak_active_route_status()
    clear_object_nav_speech()
    local map_id, x, y = nav.get_position()
    local info = overworld_routes.status(map_id, x, y, {
        terrain_offset = snapshot.terrain_offset,
    })

    request_route_object_refresh(info)
    log_route_event("OVERWORLD_ROUTE", info)
    speak_info(info.message)
end

blocked_object_hotkey_message = function(reason)
    reason = tostring(reason or "")
    if reason ~= "" then
        return reason
    end
    return "Object controls unavailable right now"
end

local function has_modifier_down(keys)
    return key_combo.is_down(keys, "Shift")
        or key_combo.is_down(keys, "Ctrl")
        or key_combo.is_down(keys, "Alt")
end

route_guidance_key_pressed = function(keys)
    local spec = config.get("key_route_guidance")
    if key_combo.is_combo(spec) then
        return is_key_pressed(keys, spec)
    end
    return is_key_pressed(keys, spec) and not has_modifier_down(keys)
end

route_guidance_key_down = function(keys)
    local spec = config.get("key_route_guidance")
    if key_combo.is_combo(spec) then
        return key_combo.is_down(keys, spec)
    end
    return key_combo.is_down(keys, spec) and not has_modifier_down(keys)
end

local function flush_object_nav_speech()
    if not pending_object_nav_speech then return false end

    local message = pending_object_nav_speech
    clear_object_nav_speech()
    tolk.output_interrupt(message)
    debug_tools.debug("object_nav_speech flushed")
    return true
end

local function queue_object_nav_speech(message)
    local delay = get_object_nav_speech_delay()
    if delay <= 0 then
        speak_now(message)
        return
    end

    pending_object_nav_speech = message
    pending_object_nav_frames = delay
    object_nav_speech_queued_this_frame = true
    debug_tools.debug(string.format("object_nav_speech queued delay=%d", delay))
end

local function tick_object_nav_speech()
    if pending_object_nav_frames <= 0 then return end

    pending_object_nav_frames = pending_object_nav_frames - 1
    if pending_object_nav_frames <= 0 then
        flush_object_nav_speech()
    end
end

local function selected_teleport_handler_opts()
    -- FCEUX skips the dangerous immediate joypad.set() neutral pulse inside
    -- suppress_teleport_input(), but still needs the logical trigger-release
    -- latch so pending facing cannot run while Enter/an arrow remains held.
    return {suppress_input = true}
end

-- ============================================================
-- Main Update
-- ============================================================

-- update(keys): Process keyboard hotkeys for on-demand info.
-- keys: table from input.get() with key names as keys, true as values.
-- All key assignments come from config.lua so the user can remap them.
-- Call once per frame from the main loop.
function M.update(keys, game_state, allow_object_hotkeys, object_hotkey_block_reason)
    object_nav_speech_queued_this_frame = false

    -- Cancellation is deliberately available before field/object guards. It
    -- must remain usable while movement itself makes other object controls
    -- unavailable, and while battle, dialogue, or a menu interrupts a route.
    local stop_auto_walk_pressed = is_key_pressed(keys, config.get("key_stop_auto_walk"))
    if stop_auto_walk_pressed then
        stop_auto_walk_from_hotkey()
    end

    -- Shift+R by default: report route status without ever starting,
    -- replacing, or recalculating guidance. Keep this available through
    -- battle/dialogue/menu guards so it is always safe to check progress.
    local route_status_pressed = is_key_pressed(keys, config.get("key_route_status"))
    if route_status_pressed then
        speak_active_route_status()
    end

    -- Position: Read current position (map name + coordinates)
    if is_key_pressed(keys, config.get("key_position")) then
        speak_position()
    end

    if is_key_pressed(keys, config.get("key_map_description")) then
        clear_object_nav_speech()
        map_descriptions.read(snapshot, game_state and game_state.state)
    end

    -- Visible-area report: describe only the terrain and objects inside the
    -- game's current dungeon light. Keep it read-only and available even when
    -- movement/object controls are temporarily gated.
    if is_key_pressed(keys, config.get("key_visible_area")) then
        if game_state ~= nil and game_state.state ~= "field" then
            speak_info("Visible area is unavailable outside field play")
        else
            local map_id = select(1, nav.get_position())
            if objects.check_refresh then
                objects.check_refresh(map_id)
            end
            local ok, message = pcall(route_mgr.describe_visible_area)
            if ok and message and message ~= "" then
                speak_info(message)
            else
                if debug_tools.error then
                    debug_tools.error("visible-area hotkey failed: " .. tostring(message))
                end
                speak_info("Visible area unavailable")
            end
        end
    end

    -- HP/MP: Read current HP and MP
    if is_key_pressed(keys, config.get("key_hp")) then
        local hp = memory.readbyte(addr.CURRENT_HP)
        local max_hp = memory.readbyte(addr.MAX_HP)
        local mp = memory.readbyte(addr.CURRENT_MP)
        local max_mp = memory.readbyte(addr.MAX_MP)
        speak_info("HP " .. hp .. " of " .. max_hp ..
                              ", MP " .. mp .. " of " .. max_mp)
    end

    -- Level: Read player level
    if is_key_pressed(keys, config.get("key_level")) then
        local level = memory.readbyte(addr.LEVEL)
        speak_info("Level " .. level)
    end

    -- Gold: Read gold
    if is_key_pressed(keys, config.get("key_gold")) then
        local gold = memory.readbyte(addr.GOLD_LO) +
                     memory.readbyte(addr.GOLD_HI) * 256
        speak_info(gold .. " gold")
    end

    -- Experience: Read experience
    if is_key_pressed(keys, config.get("key_experience")) then
        local exp = memory.readbyte(addr.EXPERIENCE_LO) +
                    memory.readbyte(addr.EXPERIENCE_HI) * 256
        speak_info(exp .. " experience")
    end

    -- Stats: Read full stats (level, HP/MP, all stats, equipment, spells)
    if not route_status_pressed and is_key_pressed(keys, config.get("key_stats")) then
        speak_info(items.read_status_string())
    end

    -- Screen text: Read all text currently on screen
    if is_key_pressed(keys, config.get("key_screen_text")) then
        local screen_text = text.get_full_screen_text()
        if screen_text ~= "" then
            speak_info(screen_text)
        else
            speak_info("No text on screen")
        end
    end

    -- Diagnostic: raw menu cursor values
    if is_key_pressed(keys, config.get("key_diag_cursor")) then
        speak_info(menu.get_cursor_info())
    end

    -- Diagnostic: dump raw PPU tile bytes and decoded text for both nametables.
    -- Use this while a menu/dialogue bug is visible. It records the full
    -- 30-row NT0/NT1 state plus both horizontal wrap orders so parser bugs can
    -- be compared directly against what the player sees.
    if is_key_pressed(keys, config.get("key_diag_ppu_dump")) then
        clear_ppu_cache_for_diagnostic()
        local BG  = 0x9F   -- background/empty tile in PPU nametable
        local NT0 = 0x2000 -- nametable 0
        local NT1 = 0x2400 -- nametable 1 (potential overflow target)
        local W   = 32     -- nametable width in tiles
        local COMMAND_BYTES = {0x26, 0x32, 0x30, 0x30, 0x24, 0x31, 0x27}
        local YES_BYTES = {0x3C, 0x28, 0x36}
        local NO_BYTES = {0x31, 0x32}
        local CURSOR_TILE = 0x42

        local function read_row(base, row)
            local bytes = {}
            for col = 0, W - 1 do
                bytes[col + 1] = ppu.readbyte(base + row * W + col)
            end
            return bytes
        end

        local function row_hex(bytes)
            local parts = {}
            for i = 1, #bytes do
                local b = bytes[i]
                parts[i] = (b == BG) and "--" or string.format("%02X", b)
            end
            return table.concat(parts, " ")
        end

        local function decode(bytes)
            local decoded = chars.decode_bytes(bytes)
            return decoded:match("^%s*(.-)%s*$") or ""
        end

        local function concat_rows(first, second)
            local out = {}
            for i = 1, #first do out[#out + 1] = first[i] end
            for i = 1, #second do out[#out + 1] = second[i] end
            return out
        end

        local function find_sequence(bytes, sequence)
            for start = 1, #bytes - #sequence + 1 do
                local match = true
                for i = 1, #sequence do
                    if bytes[start + i - 1] ~= sequence[i] then
                        match = false
                        break
                    end
                end
                if match then return start end
            end
            return nil
        end

        local function find_yesno(bytes)
            for col = 1, #bytes do
                if bytes[col] == CURSOR_TILE then
                    for offset = 1, 4 do
                        local i = col + offset
                        local b1 = bytes[i]
                        local b2 = bytes[i + 1] or 0
                        local b3 = bytes[i + 2] or 0
                        if b1 == NO_BYTES[1] and b2 == NO_BYTES[2]
                           and (b3 < 0x0A or b3 > 0x3D) then
                            return "NO", col
                        end
                        local b4 = bytes[i + 3] or 0
                        if b1 == YES_BYTES[1] and b2 == YES_BYTES[2] and b3 == YES_BYTES[3]
                           and (b4 < 0x0A or b4 > 0x3D) then
                            return "YES", col
                        end
                        if b1 ~= 0x5F then break end
                    end
                end
            end
            return nil, nil
        end

        local dump = {}
        local map_id, px, py = nav.get_position()
        local scroll_x = addr.SCROLL_X and memory.readbyte(addr.SCROLL_X) or 0
        local scroll_tiles = math.floor(scroll_x / 8) % W
        local ppu_ctrl = addr.PPU_CTRL and memory.readbyte(addr.PPU_CTRL) or 0
        local base_nt = ppu_ctrl % 2
        local d8 = memory.readbyte(addr.MENU_CURSOR_X)
        local d9 = memory.readbyte(addr.MENU_CURSOR_Y)
        dump[#dump+1] = "=== PPU Nametable Dump ==="
        dump[#dump+1] = string.format(
            "Map: %d (0x%02X)  Player: x=%d, y=%d  scroll_x=0x%02X scroll_tiles=%d ppu_ctrl=0x%02X base_nt=%d cursor_d8=%d cursor_d9=%d menu_open=%s",
            map_id, map_id, px, py, scroll_x, scroll_tiles, ppu_ctrl, base_nt,
            d8, d9, tostring(menu.is_open()))
        dump[#dump+1] = ""
        dump[#dump+1] = "Rows 0-29 from NT0 ($2000) and NT1 ($2400)."
        dump[#dump+1] = "BG tile 0x9F shown as '--'.  Non-BG shown as 2-digit hex."
        dump[#dump+1] = "V01 means decoded NT0->NT1 row order; V10 means decoded NT1->NT0 row order."
        dump[#dump+1] = ""

        for row = 0, 29 do
            local nt0 = read_row(NT0, row)
            local nt1 = read_row(NT1, row)
            local v01 = concat_rows(nt0, nt1)
            local v10 = concat_rows(nt1, nt0)
            local decoded0 = decode(nt0)
            local decoded1 = decode(nt1)
            local decoded01 = decode(v01)
            local decoded10 = decode(v10)
            local cmd01 = find_sequence(v01, COMMAND_BYTES)
            local cmd10 = find_sequence(v10, COMMAND_BYTES)
            local yes01, yes_col01 = find_yesno(v01)
            local yes10, yes_col10 = find_yesno(v10)

            dump[#dump+1] = string.format("Row %02d", row)
            dump[#dump+1] = "  NT0: " .. row_hex(nt0)
            dump[#dump+1] = "  NT1: " .. row_hex(nt1)
            if decoded0 ~= "" then dump[#dump+1] = "  T0:  " .. decoded0 end
            if decoded1 ~= "" then dump[#dump+1] = "  T1:  " .. decoded1 end
            if decoded01 ~= "" then dump[#dump+1] = "  V01: " .. decoded01 end
            if decoded10 ~= "" then dump[#dump+1] = "  V10: " .. decoded10 end
            if cmd01 then
                dump[#dump+1] = string.format("  MATCH: COMMAND V01 col=%d", cmd01 - 1)
            end
            if cmd10 then
                dump[#dump+1] = string.format("  MATCH: COMMAND V10 col=%d", cmd10 - 1)
            end
            if yes01 then
                dump[#dump+1] = string.format("  MATCH: YESNO %s V01 cursor_col=%d", yes01, yes_col01 - 1)
            end
            if yes10 then
                dump[#dump+1] = string.format("  MATCH: YESNO %s V10 cursor_col=%d", yes10, yes_col10 - 1)
            end
        end

        if emulator_compat.get_ppu_source_rows then
            local probe_rows = {}
            for row = 0, 29 do
                probe_rows[#probe_rows + 1] = row
            end
            local sources = emulator_compat.get_ppu_source_rows(probe_rows)
            if sources and #sources > 0 then
                dump[#dump+1] = ""
                dump[#dump+1] = "PPU source comparison (decoded rows/matches only)."
                for _, source in ipairs(sources) do
                    dump[#dump+1] = "Source: " .. tostring(source.name)
                    local any = false
                    for row = 0, 29 do
                        local row_data = source.rows and source.rows[row]
                        if row_data then
                            local v01 = concat_rows(row_data.nt0, row_data.nt1)
                            local v10 = concat_rows(row_data.nt1, row_data.nt0)
                            local decoded01 = decode(v01)
                            local decoded10 = decode(v10)
                            local cmd01 = find_sequence(v01, COMMAND_BYTES)
                            local cmd10 = find_sequence(v10, COMMAND_BYTES)
                            local yes01, yes_col01 = find_yesno(v01)
                            local yes10, yes_col10 = find_yesno(v10)
                            local parts = {}
                            if decoded01 ~= "" then parts[#parts + 1] = "V01=" .. decoded01 end
                            if decoded10 ~= "" then parts[#parts + 1] = "V10=" .. decoded10 end
                            if cmd01 then parts[#parts + 1] = string.format("COMMAND V01 col=%d", cmd01 - 1) end
                            if cmd10 then parts[#parts + 1] = string.format("COMMAND V10 col=%d", cmd10 - 1) end
                            if yes01 then parts[#parts + 1] = string.format("YESNO %s V01 cursor_col=%d", yes01, yes_col01 - 1) end
                            if yes10 then parts[#parts + 1] = string.format("YESNO %s V10 cursor_col=%d", yes10, yes_col10 - 1) end
                            if #parts > 0 then
                                dump[#dump+1] = string.format("  Row %02d: %s", row, table.concat(parts, " | "))
                                any = true
                            end
                        end
                    end
                    if not any then
                        dump[#dump+1] = "  (no decoded text or matches)"
                    end
                end
            end
        end

        local f = io.open("ppu_dump.txt", "w")
        if f then
            f:write(table.concat(dump, "\n"))
            f:close()
            speak_now("PPU dump written to ppu_dump.txt")
        else
            speak_now("Failed to write dump file")
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
            speak_now("Title diagnostic written to title_diag.txt")
        else
            speak_now("Failed to write title_diag.txt")
        end
    end

    -- Diagnostic: tile types at and around the player's position.
    -- Speaks a short summary. The full tile_diag.txt dump is intentionally
    -- disabled by default because the extra memory/ROM scans can hitch BizHawk
    -- audio.
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

        -- Helper: return "typeW" (walkable), "typeDoor" (locked door), or "typeX" (wall)
        local function td(x, y)
            local details = map_reader.get_walkability_details(map_id, x, y)
            if not details or details.tile_type == nil then return "nil" end
            if details.reason == "door_closed" then
                return tostring(details.tile_type) .. "D"  -- D = locked door
            end
            return tostring(details.tile_type) .. (details.effective_walkable and "W" or "X")
        end

        -- Speak a compact summary of tile types at player + 4 neighbors.
        -- Format: "At 5,8. RAM 0. Here 0W. N 2X. S 0W. W 0W. E 1W."
        -- 'W' suffix = walkable, 'X' = wall, RAM = game's own tile type.
        speak_now(
            "At " .. px .. "," .. py ..
            ". RAM " .. ram_tile ..
            ". Here " .. td(px, py) ..
            ". N " .. td(px, py - 1) ..
            ". S " .. td(px, py + 1) ..
            ". W " .. td(px - 1, py) ..
            ". E " .. td(px + 1, py)
        )

        if config.get("tile_diag_dump_on_hotkey") == "true" then
        local meta = map_reader.get_metadata(map_id)

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
    end

    local object_hotkeys_allowed = allow_field_object_hotkeys(game_state, allow_object_hotkeys)

    -- Toggle NPC position freeze on/off.
    -- When frozen, NPC bytes are locked to their snapshotted positions so
    -- pathfinding routes stay valid even if guards wander. Turn off after
    -- reaching your destination so NPCs resume normal movement.
    if object_hotkeys_allowed and is_key_pressed(keys, config.get("key_freeze_npcs")) then
        clear_object_nav_speech()
        route_mgr.toggle_npc_freeze()
    end

    -- Object hotkeys are allowed in field play only. This keeps battle/input
    -- from running route/path/teleport/mark actions while the encounter is active.
    if not object_hotkeys_allowed then
        start_deferred_auto_walk_if_released(keys, false, object_hotkey_block_reason)
        local route_status_handled = false
        if route_guidance_key_pressed(keys)
           and overworld_routes.is_active
           and overworld_routes.is_active() then
            debug_tools.debug("object hotkey read-only while blocked: key_route_guidance")
            suppress_object_hotkey_direction_edges()
            speak_active_route_status()
            route_status_handled = true
        end

        local blocked_key = blocked_object_hotkey_pressed(keys)
        if stop_auto_walk_pressed and blocked_key == "key_auto_walk" then
            blocked_key = nil
        end
        if route_status_handled and blocked_key == "key_route_guidance" then
            blocked_key = nil
        end
        local held_key = blocked_key or blocked_object_hotkey_down(keys)
        if route_status_handled and held_key == "key_route_guidance" then
            held_key = nil
        end
        if held_key and blocked_hotkey_should_suppress_game_input(held_key, object_hotkey_block_reason) then
            suppress_blocked_hotkey_game_input()
        end
        if blocked_key then
            if blocked_hotkey_should_suppress_direction_edges(blocked_key, object_hotkey_block_reason) then
                suppress_object_hotkey_direction_edges()
            end
            if debug_tools.info then
                debug_tools.info("OBJECT_HOTKEY_BLOCKED key=" .. tostring(blocked_key)
                    .. " reason=" .. tostring(object_hotkey_block_reason or "blocked"))
                if debug_tools.flush then
                    debug_tools.flush()
                end
            end
            debug_tools.debug("object hotkey blocked: " .. blocked_key)
            speak_info(blocked_object_hotkey_message(object_hotkey_block_reason))
        end
    else
        if start_deferred_auto_walk_if_released(keys, true) then
            prev_keys = keys
            return
        end

        -- ============================================================
        -- Object Navigation (J/K/L/O/F)
        -- ============================================================
        -- Cycle through map objects (NPCs, stairs, chests, exits) and
        -- hear direction + distance information for each one.
        -- Follows the J/K/L convention from pokemon-access and FF mods.

        if is_key_pressed(keys, config.get("key_services")) then
            clear_object_nav_speech()
            local message = route_mgr.open_services()
            speak_now(message)
            debug_tools.info("QUICK_SERVICES: " .. message)
            prev_keys = keys
            return
        end

        if is_key_pressed(keys, config.get("key_object_sort")) then
            clear_object_nav_speech()
            local _, message = objects.cycle_sort_order()
            speak_now(message)
            debug_tools.info("OBJECT_SORT: " .. message)
            prev_keys = keys
            return
        end

        local filter_nav_handled = false

        if is_key_pressed(keys, config.get("key_filter_prev")) then
            filter_nav_handled = true
            clear_object_nav_speech()
            speak_filter(objects.prev_filter())
        end

        if is_key_pressed(keys, config.get("key_filter_all")) then
            filter_nav_handled = true
            clear_object_nav_speech()
            speak_filter(objects.all_filter())
        end

        if is_key_pressed(keys, config.get("key_filter_next")) then
            filter_nav_handled = true
            clear_object_nav_speech()
            speak_filter(objects.next_filter())
        end

        -- L key (default): Next object in list
        if not filter_nav_handled and is_key_pressed(keys, config.get("key_object_next")) then
            refresh_object_browser_context()
            local obj = objects.next_object()
            if obj then
                queue_object_nav_speech(route_mgr.describe_current_object({
                    include_reachability = objects.get_filter_name() == "Services",
                    include_service_details = objects.get_filter_name() == "Services",
                    include_debug_coords = false,
                }))
            else
                speak_now("No objects found")
            end
        end

        -- J key (default): Previous object in list
        if not filter_nav_handled and is_key_pressed(keys, config.get("key_object_prev")) then
            refresh_object_browser_context()
            local obj = objects.prev_object()
            if obj then
                queue_object_nav_speech(route_mgr.describe_current_object({
                    include_reachability = objects.get_filter_name() == "Services",
                    include_service_details = objects.get_filter_name() == "Services",
                    include_debug_coords = false,
                }))
            else
                speak_now("No objects found")
            end
        end

        -- K key (default): Describe current object (re-read with updated distance)
        if not filter_nav_handled and is_key_pressed(keys, config.get("key_object_current")) then
            refresh_object_browser_context()
            speak_now(route_mgr.describe_current_object({
                include_reachability = objects.get_filter_name() == "Services",
                include_service_details = objects.get_filter_name() == "Services",
                include_debug_coords = false,
            }))
        end

        local pathability_filter_handled = false
        if is_key_pressed(keys, config.get("key_pathability_filter")) then
            pathability_filter_handled = true
            suppress_object_hotkey_direction_edges()
            clear_object_nav_speech()
            refresh_live_objects_for_browse()
            speak_pathability_filter(route_mgr.next_object_pathability_filter())
        end

        -- R key (default): Start or check curated route guidance for the
        -- selected destination. This keeps O as a plain heading/path preview.
        if route_guidance_key_pressed(keys) then
            suppress_object_hotkey_direction_edges()
            refresh_object_browser_context({refresh_live_npcs = true})
            speak_route_guidance()
        end

        -- O key (default): Pathfind to current object.
        -- For NPCs: route to an adjacent tile (player can't walk onto the NPC).
        -- For everything else (stairs, chests, exits): route to the exact tile.
        -- NPC positions are passed so the pathfinder routes around other NPCs
        -- that physically block tiles along the way.
        if not pathability_filter_handled and is_key_pressed(keys, config.get("key_pathfind")) then
            suppress_object_hotkey_direction_edges()
            clear_object_nav_speech()
            refresh_object_browser_context({refresh_live_npcs = true})
            route_mgr.pathfind_to_current()
        end

        -- U key (default): Auto-walk the computed path to the current object.
        -- Uses the same planning logic as O, but queues the route into auto_step
        -- so the player actually walks it on interior maps.
        if not stop_auto_walk_pressed and is_key_pressed(keys, config.get("key_auto_walk")) then
            clear_object_nav_speech()
            pending_auto_walk_after_key_release = true
            log_auto_walk_hotkey("AUTO_WALK_HOTKEY_DEFERRED awaiting_key_release=true")
        end

        -- Q key (default): Cycle object filter (All / NPCs / Services / Treasure / Travel / Doors)
        if is_key_pressed(keys, config.get("key_filter")) then
            clear_object_nav_speech()
            speak_filter(objects.next_filter())
        end

        if is_key_pressed(keys, config.get("key_mark_visited")) then
            clear_object_nav_speech()
            local obj = objects.mark_current_visited()
            if obj then
                speak_now(obj.name .. " marked visited")
            else
                speak_now("No object selected")
            end
        end

        if teleport_handler then
            if is_teleport_key_pressed(keys, "key_teleport_exact") then
                clear_object_nav_speech()
                refresh_object_browser_context({refresh_live_npcs = true})
                teleport_handler("exact", selected_teleport_handler_opts())
            elseif is_teleport_key_pressed(keys, "key_teleport_north") then
                clear_object_nav_speech()
                refresh_object_browser_context({refresh_live_npcs = true})
                teleport_handler("north", selected_teleport_handler_opts())
            elseif is_teleport_key_pressed(keys, "key_teleport_south") then
                clear_object_nav_speech()
                refresh_object_browser_context({refresh_live_npcs = true})
                teleport_handler("south", selected_teleport_handler_opts())
            elseif is_teleport_key_pressed(keys, "key_teleport_west") then
                clear_object_nav_speech()
                refresh_object_browser_context({refresh_live_npcs = true})
                teleport_handler("west", selected_teleport_handler_opts())
            elseif is_teleport_key_pressed(keys, "key_teleport_east") then
                clear_object_nav_speech()
                refresh_object_browser_context({refresh_live_npcs = true})
                teleport_handler("east", selected_teleport_handler_opts())
            end
        end
    end

    if not object_nav_speech_queued_this_frame then
        tick_object_nav_speech()
    end

    -- Save key state for next frame's key-down detection
    prev_keys = keys
end

function M.set_teleport_handler(fn)
    teleport_handler = fn
end

function M._reset_for_tests()
    prev_keys = {}
    object_nav_speech_queued_this_frame = false
    pending_auto_walk_after_key_release = false
    teleport_handler = nil
    clear_object_nav_speech()
end

function M._pending_object_nav_speech_for_tests()
    return pending_object_nav_speech, pending_object_nav_frames
end

-- Keep held menu keys from becoming fresh gameplay hotkeys after closing.
function M.capture_settings_input(keys)
    pending_auto_walk_after_key_release = false
    clear_object_nav_speech()
    prev_keys = {}
    for key, value in pairs(keys or {}) do prev_keys[key] = value end
end

return M
