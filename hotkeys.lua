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
local debug_tools = require "debug_tools"
local key_combo  = require "key_combo"

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

-- is_key_pressed(keys, key_name): Check if a key was just pressed
-- this frame (wasn't pressed last frame). This prevents the action
-- from firing repeatedly while the key is held down.
local function is_key_pressed(keys, key_name)
    return key_combo.is_pressed(keys, prev_keys, key_name)
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

local function speak_now(message)
    clear_object_nav_speech()
    tolk.output_interrupt(message)
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

-- ============================================================
-- Main Update
-- ============================================================

-- update(keys): Process keyboard hotkeys for on-demand info.
-- keys: table from input.get() with key names as keys, true as values.
-- All key assignments come from config.lua so the user can remap them.
-- Call once per frame from the main loop.
function M.update(keys)
    object_nav_speech_queued_this_frame = false

    -- Position: Read current position (map name + coordinates)
    if is_key_pressed(keys, config.get("key_position")) then
        speak_now(nav.get_position_string())
    end

    -- HP/MP: Read current HP and MP
    if is_key_pressed(keys, config.get("key_hp")) then
        local hp = memory.readbyte(addr.CURRENT_HP)
        local max_hp = memory.readbyte(addr.MAX_HP)
        local mp = memory.readbyte(addr.CURRENT_MP)
        local max_mp = memory.readbyte(addr.MAX_MP)
        speak_now("HP " .. hp .. " of " .. max_hp ..
                              ", MP " .. mp .. " of " .. max_mp)
    end

    -- Level: Read player level
    if is_key_pressed(keys, config.get("key_level")) then
        local level = memory.readbyte(addr.LEVEL)
        speak_now("Level " .. level)
    end

    -- Gold: Read gold
    if is_key_pressed(keys, config.get("key_gold")) then
        local gold = memory.readbyte(addr.GOLD_LO) +
                     memory.readbyte(addr.GOLD_HI) * 256
        speak_now(gold .. " gold")
    end

    -- Experience: Read experience
    if is_key_pressed(keys, config.get("key_experience")) then
        local exp = memory.readbyte(addr.EXPERIENCE_LO) +
                    memory.readbyte(addr.EXPERIENCE_HI) * 256
        speak_now(exp .. " experience")
    end

    -- Stats: Read full stats (level, HP/MP, all stats, equipment, spells)
    if is_key_pressed(keys, config.get("key_stats")) then
        speak_now(items.read_status_string())
    end

    -- Screen text: Read all text currently on screen
    if is_key_pressed(keys, config.get("key_screen_text")) then
        local screen_text = text.get_full_screen_text()
        if screen_text ~= "" then
            speak_now(screen_text)
        else
            speak_now("No text on screen")
        end
    end

    -- Diagnostic: raw menu cursor values
    if is_key_pressed(keys, config.get("key_diag_cursor")) then
        speak_now(menu.get_cursor_info())
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

    -- Toggle NPC position freeze on/off.
    -- When frozen, NPC bytes are locked to their snapshotted positions so
    -- pathfinding routes stay valid even if guards wander. Turn off after
    -- reaching your destination so NPCs resume normal movement.
    if is_key_pressed(keys, config.get("key_freeze_npcs")) then
        clear_object_nav_speech()
        route_mgr.toggle_npc_freeze()
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
            queue_object_nav_speech(route_mgr.describe_current_object({
                include_reachability = false,
                include_debug_coords = false,
            }))
        else
            speak_now("No objects found")
        end
    end

    -- J key (default): Previous object in list
    if is_key_pressed(keys, config.get("key_object_prev")) then
        local obj = objects.prev_object()
        if obj then
            queue_object_nav_speech(route_mgr.describe_current_object({
                include_reachability = false,
                include_debug_coords = false,
            }))
        else
            speak_now("No objects found")
        end
    end

    -- K key (default): Describe current object (re-read with updated distance)
    if is_key_pressed(keys, config.get("key_object_current")) then
        speak_now(route_mgr.describe_current_object({
            include_reachability = false,
            include_debug_coords = false,
        }))
    end

    -- O key (default): Pathfind to current object.
    -- For NPCs: route to an adjacent tile (player can't walk onto the NPC).
    -- For everything else (stairs, chests, exits): route to the exact tile.
    -- NPC positions are passed so the pathfinder routes around other NPCs
    -- that physically block tiles along the way.
    if is_key_pressed(keys, config.get("key_pathfind")) then
        clear_object_nav_speech()
        route_mgr.pathfind_to_current()
    end

    -- U key (default): Auto-walk the computed path to the current object.
    -- Uses the same planning logic as O, but queues the route into auto_step
    -- so the player actually walks it on interior maps.
    if is_key_pressed(keys, config.get("key_auto_walk")) then
        clear_object_nav_speech()
        route_mgr.autowalk_to_current()
    end

    -- Q key (default): Cycle object filter (All / NPCs / Exits / Chests / Stairs)
    if is_key_pressed(keys, config.get("key_filter")) then
        clear_object_nav_speech()
        local filter_name = objects.next_filter()
        -- Announce the new filter and the first object in it
        local count = objects.get_count()
        if count > 0 then
            speak_now(filter_name .. ". " .. route_mgr.describe_current_object({
                include_reachability = false,
                include_debug_coords = false,
            }))
        else
            speak_now(filter_name .. ". No objects")
        end
    end

    if not object_nav_speech_queued_this_frame then
        tick_object_nav_speech()
    end

    -- Save key state for next frame's key-down detection
    prev_keys = keys
end

function M._reset_for_tests()
    prev_keys = {}
    object_nav_speech_queued_this_frame = false
    clear_object_nav_speech()
end

function M._pending_object_nav_speech_for_tests()
    return pending_object_nav_speech, pending_object_nav_frames
end

return M
