# Dragon Warrior Blind Accessibility Mod

> **Alpha / work in progress**
>
> This mod is approaching its first public release, but it has not yet been
> validated through the entire game. Expect rough edges, incomplete route
> coverage, and occasional troubleshooting.

## Purpose

Dragon Warrior Blind Accessibility Mod is a Lua-based accessibility layer for
the original NES release of **Dragon Warrior**. It is designed to make the game
playable without sight by adding screen-reader narration, location and object
information, navigation assistance, and optional automated movement.

The mod runs alongside the game in a supported NES emulator. It does not modify
or distribute the Dragon Warrior ROM.

## Features

Current features include:

- Screen-reader narration for title and save screens, name entry, dialogue,
  Yes/No prompts, command menus, shops, inns, item and spell menus, battles,
  status changes, and other gameplay text.
- Spoken map names, coordinates, HP and MP, level, gold, experience, statistics,
  and visible screen text.
- An object browser for nearby NPCs, services, treasure, doors, stairs, exits,
  and travel destinations.
- Object category and reachability filters.
- Path previews and spoken route guidance to selected objects.
- Tap-to-step movement for precise one-tile navigation.
- Auto-walk to selected objects and along supported route segments.
- Guided overworld routes between a growing set of important towns, caves, and
  landmarks.
- Selected-object teleport controls for recovery, testing, or bypassing a route
  that is not yet usable.
- Hazard-aware pathfinding that avoids known damage and death tiles.
- Session-based visited markers for NPCs and objects.
- Configurable keyboard hotkeys in `dw_access.ini`.
- Optional controller access to extra mod commands through the included
  JoyToKey profile.
- Extensive logging and testing tools for bug reports and development.

## Requirements

- Windows.
- A legally obtained copy of the supported Dragon Warrior ROM.
- A supported Windows screen reader or speech output, such as NVDA, JAWS, or
  Narrator.

The recommended automatic installer handles the emulator, speech bridge, and
other required setup. If you choose manual installation, you will also need one
of the supported emulators and, for FCEUX, Python 3 and the
`accessible_output2` package as described below.

## Emulator Support

### FCEUX: recommended for normal play

FCEUX is the primary gameplay emulator. In same-save testing on the development
machine, it provided smooth movement, object navigation, dialogue, auto-walk,
and combat without noticeable emulator lag.

The project is mainly developed and tested with FCEUX 2.6.6 using
`qfceux.exe`. FCEUX has a few setup and input-focus quirks, but it currently
provides the most comfortable playing experience.

### BizHawk: compatible, but performance may vary

The script includes a compatibility layer for BizHawk and should function in
both emulators. BizHawk is useful for development because ROM and Lua startup,
script reloading, profiling, and automation are more reliable.

On the development machine, however, BizHawk's Lua memory access causes
player-facing lag and occasional audio cut-outs during heavier work such as
pathfinding, seam recovery, reachability-filter changes, map transitions, and
some spell-menu activity. Multiple optimization passes reduced the lag but did
not make it comfortable enough for normal play. Your results may vary.

## The ROM

Development and testing use:

```text
Dragon Warrior (USA) (Rev 1).nes
```

Including the revision is important because the mod reads the game's memory and
ROM data at known addresses. Other regional releases, revisions, translations,
and ROM hacks have not been validated and may not work correctly.

The ROM is copyrighted material and is **not included** with this project. You
must provide your own legally obtained copy.

## Installation

### Automatic installation: recommended

The automatic installer is the easiest way to get started. It sets up the
tested FCEUX environment and the mod's supporting components for you.

The release uses two separate command files: run the installer once to set up
the mod, then use `Play Dragon Warrior.cmd` whenever you want to play.

1. Download the latest release archive from the project's
   [Releases page](https://github.com/techdog420/DragonWarriorBlindAccess-Public/releases).
   Do not download the source-code archive unless you intend to install the mod
   manually.
2. Extract the entire release archive to a writable folder. Do not run the
   installer from inside the ZIP file.
3. Run **`Install Dragon Warrior.cmd`** from the extracted folder.
4. Follow the spoken or on-screen prompts. When asked, select your legally
   obtained `Dragon Warrior (USA) (Rev 1).nes` ROM.
5. When installation finishes, run **`Play Dragon Warrior.cmd`** from the
   extracted folder to start the game with the accessibility mod. Use this same
   file for future play sessions; you do not need to run the installer again.

Keep the extracted release files together. If the installer reports that
`install_player.ps1` is missing, extract the complete release ZIP again. If
setup does not complete, review the messages in the command window or open
`user\install.log` for more information.

If the play command later reports that `play_player.ps1` is missing, re-extract
the complete release ZIP. For other launch failures, review the messages in the
command window or open `user\launch.log`.

The ROM remains your property and is not included with, uploaded by, or
distributed through the installer.

### Manual installation

Manual installation is intended for BizHawk users, people who already maintain
their own FCEUX setup, developers, and anyone who wants control over where each
component is installed.

#### FCEUX

1. Download or clone the project and keep all project files together in one
   writable folder.
2. Download [FCEUX 2.6.6](https://fceux.com/web/download.html). The main tested
   version is the 64-bit Qt/SDL build containing `qfceux.exe`. If you already
   use this build, you may keep your existing copy.
3. Install Python 3 and make sure the `python` command works in PowerShell.
4. Install the speech bridge dependency:

   ```powershell
   python -m pip install accessible_output2
   ```

5. Place your legally obtained ROM wherever you prefer. It does not need to be
   inside either the mod or emulator folder.
6. From the mod folder, run the FCEUX launcher with the paths to your emulator
   and ROM:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\launch_dw.ps1 `
     -FceuxPath "C:\Emulators\FCEUX\qfceux.exe" `
     -RomPath "C:\ROMs\Dragon Warrior (USA) (Rev 1).nes" `
     -LuaPath ".\main.lua"
   ```

The launcher configures the project's tested keyboard bridge and FCEUX input
safety settings, then attempts to load the ROM and `main.lua`. Using it is
recommended even when you install the other components manually.

FCEUX command-line loading is unreliable on some systems. If FCEUX opens but
the game or script does not load, leave that launched session open, load the
ROM through FCEUX's File menu, then open the Lua script window and load
`main.lua` manually. Keep the emulator focused during play.

If the mod does not speak, confirm that Python runs from PowerShell, reinstall
`accessible_output2`, and inspect `speech_backend.log` and
`speech_bridge.log` in the mod folder.

#### BizHawk

1. Download or clone the project into a writable folder.
2. Download and extract [BizHawk](https://github.com/TASEmulators/BizHawk/releases).
   BizHawk 2.11.1 is the currently tested version.
3. Place your legally obtained ROM wherever you prefer.
4. From the mod folder, launch BizHawk with:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\launch_bizhawk.ps1 `
     -BizhawkPath "C:\Emulators\BizHawk\EmuHawk.exe" `
     -LuaPath ".\main.lua" `
     -RomPath "C:\ROMs\Dragon Warrior (USA) (Rev 1).nes"
   ```

The BizHawk launcher loads the ROM and Lua script together. If you prefer, you
can instead open the ROM in BizHawk, open its Lua Console, and load `main.lua`
manually.

For safety, general BizHawk keyboard hotkeys are disabled in the checked-in
configuration. Set `enable_bizhawk_keyboard_hotkeys=true` in `dw_access.ini`
if you want to use all of the keyboard commands listed below. BizHawk's default
NES keyboard controls differ from the FCEUX controls in this README, so review
or remap them in BizHawk before playing.

#### Developer and WSL launchers

From WSL, `./launch_dw.sh` defaults to FCEUX. Use
`./launch_dw.sh --emulator bizhawk` only when you intentionally want the
BizHawk path. These helpers are primarily for development and testing; most
players should use the automatic installer or the Windows launchers above.

## Movement and Navigation

The mod offers three main ways to get around. They are meant to complement one
another rather than replace normal gameplay.

### Manual movement and guided routes

Use the arrow keys to move normally. With tap-to-step enabled, a quick press
finishes one tile of movement, which makes precise navigation easier. Holding a
direction still allows ordinary continuous movement.

For local navigation, select an object and press `O` to hear a path preview.
For supported overworld destinations, select a Travel object and press `R` to
start or check a guided route. The mod announces route landmarks and directions
while you move the character yourself.

Choose manual movement or route guidance when you want to explore, retain
control, fight normal random encounters, and follow the intended game flow.

### Auto-walk

Select an object and press, then release, `U`. The mod calculates a path and
moves the character toward the target. It announces progress on longer routes
and speaks when the route completes.

When an overworld guided route is active, auto-walk follows the current route
segment to its next waypoint. It is not yet unrestricted whole-world
pathfinding.

Auto-walk is useful for crossing known areas, reaching shops or stairs, and
reducing repetitive directional input. It can stop when combat, dialogue,
menus, locked doors, moving NPCs, or an unmodeled map edge interrupt the route.

### Teleport

Teleport moves the character directly to or beside the selected object:

- `Shift+Enter` teleports to the selected object. NPCs use a nearby interaction
  cell when possible.
- `Shift+Arrow` teleports to the cell on that side of the selected object.

Teleport is useful for recovering from an inaccessible position, testing, or
bypassing incomplete route data. It can skip terrain, encounters, locked
areas, and intended progression, so manual movement or auto-walk is recommended
for ordinary play.

## Controls

All mod hotkeys can be changed in `dw_access.ini`. The controls below describe
the current checked-in alpha configuration.

### Normal NES controls in the tested FCEUX setup

- Arrow keys: D-pad movement and menu navigation.
- `F`: NES A button; confirm or interact.
- `D`: NES B button; cancel or go back.
- `Enter`: Start.
- `S`: Select.

### Information

- `C` or `F17`: announce the current map and coordinates.
- `H` or `F19`: announce HP and MP.
- `I`: announce level.
- `G` or `F20`: announce gold.
- `E`: announce experience.
- `Shift+R`: announce the full statistics summary.
- `Shift+T`: read all detected text on the screen.

### Objects and map

- `J` or `F13`: previous object.
- `K` or `F14`: describe the current object.
- `L` or `F15`: next object.
- `Q`: cycle object categories: All, NPCs, Services, Treasure, Travel, and
  Doors.
- `Shift+J`: previous object category.
- `Shift+K`: return the object category to All.
- `Shift+L`: next object category.
- `Shift+O`: cycle reachability: All, Reachable, and Unreachable.
- `Shift+V`: mark the selected object as visited for the current session.
- `Shift+F`: freeze or unfreeze NPC positions for more predictable navigation.

### Movement and navigation

- `O` or `F16`: preview a path to the selected object.
- `R`: start or check guided route information for a selected Travel object.
- `U` or `F18`: auto-walk to the selected object after the key is released.
- `Shift+Enter`: teleport to the selected object.
- `Shift+Arrow`: teleport to the adjacent cell on the chosen side of the
  selected object.

### Debugging controls

These are intended for testers and developers:

- `Ctrl+M`: report raw menu cursor information.
- `Ctrl+D`: dump PPU text and screen data to a diagnostic file.
- `Ctrl+N`: speak tile information at the player's position.
- `Ctrl+Y`: dump title-screen cursor and memory information.

Set `debug_mode=true` in `dw_access.ini` to enable `dw_debug.log` and the
`dw_commands.txt` automation interface. Debug mode is useful when reporting a
problem but is not required for ordinary play.

## Optional Controller Setup

The game itself can be played with a controller through FCEUX. The repository
also includes a tested JoyToKey example under
`project_resources/controller/joytokey/` for assigning spare modern-controller
buttons to mod hotkeys such as object navigation, position, HP, gold, path
preview, and auto-walk.

JoyToKey is optional. Controller button numbers vary by model and driver, so the
included profile should be treated as a starting point rather than a universal
layout. See the controller folder's README for setup and safety instructions.

## Current Limitations

- This is an alpha release and has not been validated from beginning to end.
- Only `Dragon Warrior (USA) (Rev 1)` is currently supported and tested.
- FCEUX is the main tested emulator. Its automatic ROM/Lua startup can fail, in
  which case the ROM and `main.lua` must be loaded manually in the session
  started by the project launcher.
- FCEUX can occasionally retain Alt/menu focus after switching windows. Refocus
  the emulator if game or mod keys stop responding.
- BizHawk is functionally compatible but may produce noticeable lag and audio
  cut-outs during pathfinding and other memory-heavy features.
- Map and route coverage is incomplete. Development favors reliable routes to
  essential services, exits, stairs, doors, treasure, and progression targets
  over perfect coverage of every walkable tile or optional NPC.
- Object reachability can change when doors are locked or moving NPCs block
  narrow passages.
- Guided overworld routes cover selected destinations and follow planned
  waypoint segments. They are not full dynamic world-map pathfinding.
- Auto-walk may stop for battles, dialogue, menus, route uncertainty, or an
  unmodeled collision. Manual movement or teleport may be needed to recover.
- Teleport intentionally bypasses normal movement and can also bypass intended
  encounters, terrain, or progression barriers.
- Visited-object markers currently last only for the running session.
- The optional JoyToKey controller layout is an alpha feature and may need
  remapping for different controllers.
- Screen-reader and Windows setup combinations beyond the development system
  need broader community testing.

## Future Roadmap

Near-term work toward the first public alpha:

- Continue normal gameplay testing using the mod as the primary interface.
- Improve and validate narration for shops, inns, items, spells, battles, and
  remaining menu or dialogue edge cases.
- Decode and validate the final dungeon.
- Finish essential map coverage for progression locations, services, stairs,
  exits, doors, and treasure.
- Expand guided routes and improve recovery wherever normal gameplay exposes a
  real route failure.
- Add a convenient player-facing way to cancel an active auto-walk immediately.
- Validate the automatic installer on clean Windows systems and add a dedicated
  troubleshooting section.
- Broaden testing across screen readers, controllers, Windows systems, and both
  supported emulators.
- Collect feedback from blind players and use real playability problems to
  prioritize fixes.

Longer-term goals:

- Validate a complete playthrough.
- Turn the existing overworld waypoint routes into a connected travel network
  that can route from any supported overworld location to any destination,
  using intermediate waypoints when needed.
- Add a recovery command that guides a player who has wandered off route back
  to the nearest safe point on the overworld waypoint network.
- Preserve the game's intended darkness mechanic in an accessible form. Route,
  object, and map information should respect the character's usable light
  radius rather than allowing a blind player to bypass darkness entirely.
- Review hidden, clue-dependent treasures so navigation supports the clue
  without revealing the answer automatically. For example, expose the bath or
  another appropriate landmark in Kol rather than routing directly to the
  hidden Fairy Flute.
- Add an in-game configuration interface for settings such as tap-to-step,
  speech output and verbosity, and diagnostic logging.
- Expand the object navigator with sortable views such as distance and
  alphabetical order, search or quick access to common services, and player
  bookmarks for places such as a favorite grinding area.
- Make opened-chest status reliable across map changes and script reloads by
  deriving or persisting it beyond the current temporary in-memory tracking.
- Expand route and map coverage across the full game.
- Reduce reliance on emergency teleport as route coverage improves.
- Keep the reusable speech, navigation, logging, and automated-testing systems
  suitable for future NES accessibility projects.

## Reporting Problems

When reporting a problem, please include:

- Emulator name and version.
- Screen reader and version.
- Dragon Warrior ROM revision.
- Current map or location, if known.
- What you were trying to do.
- What happened and what you expected.
- Relevant lines from `dw_debug.log`, if debug mode was enabled.

Please do not upload or attach the copyrighted ROM.

## Development and AI Use

This project is directed, tested, and playtested by a human developer. AI coding
tools have assisted with implementation, code review, documentation, log
analysis, and automated testing. Gameplay behavior and accessibility decisions
are validated through human-directed testing in the emulator.

## Licenses and Third-Party Notices

Licenses and third-party notices are included in the `licenses` folder.
Matching source code for bundled copyleft components is provided as the
same-version `Corresponding-Source.zip` release asset.

## Legal Notice

This is an unofficial, fan-made accessibility project. It is not affiliated
with or endorsed by Square Enix, Nintendo, or the original game's developers
or publishers. Dragon Warrior and related names and assets belong to their
respective owners.
