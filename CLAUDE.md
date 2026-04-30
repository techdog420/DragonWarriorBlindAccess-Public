# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Accessibility mod for Dragon Warrior (NES) that makes the game playable for blind and visually impaired players. Lua scripts now run primarily in BizHawk through the repository's emulator compatibility layer; FCEUX remains supported as an explicit fallback. The scripts read game state from RAM and output speech via the Tolk library or Python speech bridge to screen readers (NVDA, JAWS, Narrator).

This project is modeled after the **pokemon-access** scripts (`D:\games\pokemon-access\`) which accomplish the same goal for Game Boy/GBA Pokemon titles. That codebase serves as the primary architectural reference.

The developer is using this project to learn Lua. Provide well-commented code with explanations of Lua-specific patterns when writing new code.

## Cross-Agent Handoff Contract

When sharing work with Codex:

- Read `session_handoff.md` first for the active handoff set and current state
- Keep concise current truth in `session_handoff.md`
- Put deeper evidence, experiment logs, and detailed investigation notes in dated `HANDOFF_YYYY-MM-DD_*.md` files
- Refresh the active handoff set after substantial work instead of relying on `.claude/agent-memory` alone
- Treat `.claude/agent-memory/` as a supplement to repo handoff files, not the source of truth for project continuity

## Key Paths

- **This project**: `D:\modding\dragonwarrior1\`
- **BizHawk emulator**: `D:\emulation\bizhawk\EmuHawk.exe`
- **FCEUX fallback emulator**: `D:\emulation\fceux\bin\qfceux.exe`
- **ROM**: `D:\emulation\nes\Dragon Warrior (USA) (Rev 1).nes`
- **Pokemon Access reference**: `D:\games\pokemon-access\lua\`
- **DataCrystal RAM map**: https://datacrystal.tcrf.net/wiki/Dragon_Warrior/RAM_map
- **DataCrystal text table**: https://datacrystal.tcrf.net/wiki/Dragon_Warrior/TBL

## Technology Stack

- **Language**: Lua in the active emulator runtime, kept close to Lua 5.1-compatible patterns
- **Emulator**: BizHawk (`EmuHawk.exe`) by default, FCEUX Qt build (`qfceux.exe`) 2.6.6 as fallback
- **Speech**: Tolk wrapper with Python bridge fallback for NVDA, JAWS, or Narrator
- **Game**: Dragon Warrior (USA) (Rev 1) — NES NROM mapper, 32KB PRG, 2KB RAM

## Running the Script

Preferred WSL/bash launch path:
```
./launch_dw.sh
```

Useful launcher variants:
```
./launch_dw.sh --dry-run
./launch_dw.sh --emulator fceux
./launch_bizhawk.sh
./launch_fceux.sh
```

FCEUX-only launcher variants:
```
./launch_dw.sh --emulator fceux --state-slot 0
./launch_dw.sh --emulator fceux --battery-save /mnt/d/path/to/testing_area.sav
```

Direct Windows BizHawk command-line launch is still supported when needed:
```
D:\emulation\bizhawk\EmuHawk.exe --lua=D:\modding\dragonwarrior1\main.lua "D:\emulation\nes\Dragon Warrior (USA) (Rev 1).nes"
```

Direct Windows FCEUX fallback launch:
```
D:\emulation\fceux\bin\qfceux.exe --loadlua=D:\modding\dragonwarrior1\main.lua "D:\emulation\nes\Dragon Warrior (USA) (Rev 1).nes"
```

To reload after editing: in BizHawk, use the Lua Console reload/open-script workflow or restart through `./launch_dw.sh`. In FCEUX, use Script > Reload or close and re-open the script window.

### Current tested environment

- `./launch_dw.sh` is the preferred WSL entrypoint and defaults to BizHawk.
- BizHawk launch should show `Emulator: BizHawk` in `./launch_dw.sh --dry-run`.
- FCEUX remains available through `./launch_dw.sh --emulator fceux`, `./launch_fceux.sh`, or `launch_fceux.ps1`.
- The current tested FCEUX fallback baseline is `D:\emulation\fceux\bin\qfceux.exe` reporting `FCEUX 2.6.6`.
- The FCEUX build accepts startup Lua loading via `--loadlua=<path>`. The spaced form `--loadlua <path>` did not reliably load scripts in local testing.
- `D:\emulation\fceux\bin\fceux.cfg` should have `SDL.AutoResume = 1` so FCEUX advances frames after startup and the mod can poll `dw_commands.txt`.
- A fresh `dw_debug.log` header only proves that startup code ran. Treat the emulator as truly ready only after it consumes a queued command from `dw_commands.txt`.

## Emulator Lua Architecture

Scripts run in a `while true do ... end` main loop. Each iteration calls `FCEU.frameadvance()` to tick the emulator one frame. All game state reading and speech output happens between frame advances. If `FCEU.frameadvance()` is never called, the emulator freezes.

`emulator_compat.lua` supplies the FCEUX-shaped globals used by the rest of the code when running under BizHawk. Keep emulator-specific branching in the compatibility layer or clearly gated on `DW_EMULATOR_COMPAT` instead of scattering runtime checks across gameplay modules.

**Key compatibility APIs:**
- `memory.readbyte(addr)` — read unsigned byte from NES RAM
- `memory.readbyterange(addr, len)` — read byte range as string
- `memory.register(addr, func)` — register write callback on RAM address (slow, use sparingly)
- `rom.readbyte(addr)` — read byte from ROM file (includes 16-byte iNES header)
- `input.get()` — read keyboard state (returns table of pressed keys)
- `joypad.read(player)` — read controller state
- `gui.text(x, y, str)` — draw text overlay (one frame behind unless using `gui.register`)
- `FCEU.frameadvance()` — advance emulator one frame (required in main loop)
- `FCEU.message(str)` — display a status message through the active emulator
- Bitwise: `AND()`, `OR()`, `XOR()`, `BIT()` (global functions, not methods)

## Tolk Speech Integration

Speech output prefers Tolk.dll via FFI when the active emulator runtime exposes it. In local use, the Python bridge fallback is the tested and expected speech path when FFI is unavailable.

**tolk.lua** — tries `Tolk.dll` via FFI first, then falls back to `speech_bridge.py`. The DLLs (`Tolk.dll`, `nvdaControllerClient32.dll`, `SAAPI32.dll`) should still remain alongside the script, but Python 3 plus the bridge dependencies are currently required for the tested runtime.

**Important**: Do not assume every emulator build bundles a working LuaJIT `ffi` module. Verify from the actual installed emulator before depending on FFI-only behavior.

## Dragon Warrior RAM Map

### Player Location
| Address | Description |
|---------|-------------|
| `0x0045` | Map ID (see Map IDs table below) |
| `0x003A` | Player X position (current map) |
| `0x003B` | Player Y position (current map) |
| `0x003E` | Player Y position (overworld) |
| `0x0042` | Player X position (overworld) |

### Player Stats
| Address | Description |
|---------|-------------|
| `0x00BA-BB` | Experience (2 bytes) |
| `0x00BC-BD` | Gold (2 bytes) |
| `0x00BE` | Equipment (compiled sword/armor/shield) |
| `0x00BF` | Magic Keys count |
| `0x00C0` | Herbs count |
| `0x00C1-C4` | Items (8 slots, nybble-encoded) |
| `0x00C5` | Current HP |
| `0x00C6` | Current MP |
| `0x00C7` | Level |
| `0x00C8` | Strength |
| `0x00C9` | Agility |
| `0x00CA` | Max HP |
| `0x00CB` | Max MP |
| `0x00CC` | Attack Power |
| `0x00CD` | Defense Power |
| `0x00CE` | Spells known (bitfield, 8 spells) |
| `0x00CF` | More spells + quest progress flags |

### Combat
| Address | Description |
|---------|-------------|
| `0x00D8` | Menu horizontal cursor position |
| `0x00D9` | Menu vertical cursor position |
| `0x00DF` | Combat/quest flags (princess rescue, death necklace, sleep/stopspell status) |
| `0x00E0` | Enemy type pointer / terrain type |
| `0x00E2` | Enemy HP |
| `0x00E4` | Quest progress (Golem/Dragonlord/Green Dragon defeats) |

### Environment
| Address | Description |
|---------|-------------|
| `0x0015` | Exterior tile type (0=grass, 15=water, 16=caves, 21=throne room) |
| `0x0016` | Terrain offset ($20=caves, $10=towns, $00=world map) |
| `0x00D0` | Light radius in dungeons (01, 03, 05, 07) |
| `0x00DA` | Radiant spell timer |
| `0x00DB` | Repel timer (counts down by 2 from 0xFF) |
| `0x0047` | Button(s) pressed |

### NPCs and Text
| Address | Description |
|---------|-------------|
| `0x0051-008C` | NPC data: 20 entries, 3 bytes each (type, position, direction) |
| `0x009F-00A0` | Text pointer (2 bytes) |
| `0x0400-07BF` | Screen buffer — copy of UI/text layer |

### Map IDs (address 0x0045)
```
0x01 = Charlock Castle B1          0x02 = Charlock Castle B2
0x03 = Charlock Castle B3          0x04 = Charlock Castle B4
0x05 = Charlock Castle B5          0x06 = Charlock Castle B6
0x07 = Charlock Castle B7 (Dragonlord's Throne Room)
0x08 = Tantegel Castle              0x09 = Tantegel Castle Throne Room
0x0A = Charlock Castle              0x0B = Cave (misc)
0x0C = Tantegel Town                0x0D = Kol
0x0E = Brecconary                   0x0F = Garinham
0x10 = Cantlin                      0x11 = Rimuldar
0x12 = Erdrick's Cave B1            0x13 = Erdrick's Cave B2
0x14 = Northern Shrine              0x15 = Southern Shrine
0x16 = Charlock Castle B8           0x17 = Swamp Cave
0x18 = Mountain Cave                0x19 = Mountain Cave B2
0x1A = Garin's Grave B1             0x1B = Garin's Grave B2
0x1C = Garin's Grave B3             0x1D = Garin's Grave B4
0x00 = World Map
```

## Text Encoding

Dragon Warrior uses custom character encoding for on-screen text. Key mappings:
- `0x00-0x09`: digits 0-9
- `0x0A-0x23`: lowercase a-z
- `0x24-0x3D`: uppercase A-Z
- `0x3E-0x3F`: quotation marks
- `0x40`: apostrophe, `0x44`: colon, `0x48`: comma, `0x49`: hyphen
- `0x4B`: question mark, `0x4C`: exclamation mark
- `0x5F`: space
- `0xF5`: gold cost macro (used in shop dialogue)

Text is decoded by reading bytes from the screen buffer (`0x0400-0x07BF`) and mapping them through this table.

## Project Architecture

```
dragonwarrior1/
├── main.lua              -- Entry point, main loop, automatic announcements
├── game_snapshot.lua     -- Centralized per-frame RAM reads (~35 addresses)
├── event_bus.lua         -- Lightweight pub/sub for module decoupling
├── route_manager.lua     -- Pathfinding coordination, NPC freeze, runtime blocks
├── hotkeys.lua           -- Keyboard hotkey handling (on-demand info, diagnostics)
├── tolk.lua              -- Speech output wrapper (Tolk FFI bridge)
├── encoding.lua          -- UTF-8/UTF-16 conversion for Tolk
├── addresses.lua         -- RAM address constants (renamed from memory.lua)
├── chars.lua             -- Text encoding lookup table
├── maps.lua              -- Map ID to name lookup
├── state.lua             -- Game state detection (title, field, battle)
├── text.lua              -- Screen buffer reading and text decoding
├── menu.lua              -- Menu cursor tracking and announcements
├── navigation.lua        -- Player position, map change detection
├── objects.lua           -- Map object detection (NPCs, chests, exits, doors)
├── pathfinder.lua        -- A* pathfinding for interior maps
├── map_reader.lua        -- ROM tile grid decoding
├── auto_step.lua         -- Tap-to-step D-pad extension
├── items.lua             -- Item/equipment/spell lookup tables
├── config.lua            -- User settings (dw_access.ini)
├── debug_tools.lua       -- Debug logging, command file, event hooks
├── path_debug.lua        -- Pathfinding debug/test tools
├── debug_hooks.txt       -- Cheat sheet for debug_tools API
├── Tolk.dll              -- Tolk native library
├── nvdaControllerClient32.dll
├── SAAPI32.dll
└── CLAUDE.md
```

## Main Loop Pattern

```lua
while true do
    snapshot.update()           -- Read all RAM values once per frame
    local keys = input.get()
    hotkeys.update(keys)        -- Process hotkey commands
    detect_state_changes()      -- Compare current frame to previous
    if state_changed then
        announce_changes()      -- Speak relevant information via Tolk
    end
    FCEU.frameadvance()
    route_mgr.apply_npc_freeze()  -- Restore frozen NPC positions if active
end
```

The core pattern is **polling**: every frame, read RAM into `game_snapshot`, compare to previous values, speak differences. Modules read from `snapshot.*` instead of calling `memory.readbyte()` directly. Use previous-frame state variables (e.g., `prev_map_id`, `prev_hp`, `prev_menu_cursor`) to detect transitions.

## Game Structure for Accessibility

Dragon Warrior 1 has these distinct game states that need different handling:

1. **Title Screen / Main Menu** — detect via CHR page (`0x6002` = 0x00 for title, 0x01 for gameplay)
2. **Name Entry** — character creation screen
3. **Overworld** — Map ID 0x00, player walking between towns
4. **Towns** — Map IDs 0x08-0x11, NPC interaction, shops
5. **Dungeons/Caves** — Map IDs 0x01-0x07, 0x0B-0x1D, limited light radius
6. **Dialogue** — text appearing in screen buffer, triggered by TALK command or events
7. **Command Menu** — TALK, STATUS, ITEM, SEARCH, SPELL, etc. (cursor at 0xD8/D9)
8. **Battle** — enemy type at 0xE0, enemy HP at 0xE2, menu cursor for FIGHT/RUN/SPELL/ITEM
9. **Shops** — buy/sell menus with item lists and gold costs
10. **Status/Inventory screens** — player stats display

## Lua Conventions for This Project

- Always use `local` for variables — emulator Lua globals persist across frames and can cause bugs
- Use `memory.readbyte()` for single bytes, combine two bytes for 16-bit values: `memory.readbyte(lo) + memory.readbyte(hi) * 256`
- Tables are 1-indexed in Lua but RAM addresses are 0-indexed — be careful at the boundary
- String concatenation uses `..` operator, not `+`
- Inequality operator is `~=`, not `!=`
- Boolean operators are `not`, `and`, `or` (words, not symbols)
- No `++` operator — use `x = x + 1`
- Bitwise operations use compatibility global functions: `AND(val, mask)`, `OR()`, `XOR()`, `BIT()`

## Debug Tools (debug_tools.lua)

A lightweight debugging and automation framework gated behind `debug_mode=true` in `dw_access.ini`. When disabled (default), all functions are no-ops with negligible overhead — safe in release builds.

### When investigating bugs, USE THESE TOOLS:

1. **Enable logging**: set `debug_mode=true` in `dw_access.ini`, reload script, watch `dw_debug.log`
2. **Capture a state snapshot**: write `log_state` to `dw_commands.txt` from the shell
3. **Simulate input**: write `simulate_input:A` (or UP/DOWN/LEFT/RIGHT/B/START/SELECT) to inject a one-frame button press
4. **Toggle at runtime**: write `toggle_debug` to `dw_commands.txt` to flip debug on/off without reloading

```bash
echo log_state > dw_commands.txt          # capture full snapshot now
echo simulate_input:UP > dw_commands.txt  # inject D-pad up next frame
tail -f dw_debug.log                      # watch log in real time
```

### Wired event hooks (fire automatically when debug_mode=true):
- `on_menu_open()` — command menu opens (3 sites: normal, y≤1 suppressed, STATUS return)
- `on_menu_close()` — command menu closes
- `on_dialogue(text)` — any dialogue text announced (3 sites: lower normal, lower y≤3, upper)
- `on_battle_start()` — battle begins; auto-snapshots full game state
- `on_map_change(new_id)` — player enters a new map
- `tick(frame, state)` — every frame; drives command polling + log flushing

### Log format:
```
[FRAME:00450][INFO][battle] EVENT: battle started
[FRAME:00451][INFO][battle] --- State Snapshot ---
[FRAME:00451][INFO][battle] map_id:    0x08 (Tantegel Castle)
```

### Adding new log calls anywhere in the codebase:
```lua
debug_tools.info("something happened")
debug_tools.debug("verbose detail: " .. value)
debug_tools.error("something broke")
debug_tools.snapshot()  -- full state dump
```

See `debug_hooks.txt` for the full API reference.

## Reference: Pokemon Access Patterns Worth Adapting

- **State change detection**: Compare current frame values to stored previous values, only speak on change
- **Text buffering**: Wait multiple frames after text starts appearing before reading (text renders incrementally)
- **Menu navigation**: Track cursor position and announce the item at that position
- **Hotkey commands**: Use `input.get()` to detect keyboard shortcuts for on-demand information (read coords, read HP, read map name)
- **Object navigation**: Cycle through nearby items/NPCs/exits with hotkeys (J/K/L pattern in pokemon-access)
