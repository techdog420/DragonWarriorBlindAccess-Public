# Dragon Warrior Blind Accessibility Mod

> **Getting ready for open beta**
>
> This project has come a long way since its original game-jam alpha. Navigation is more reliable, narration has improved, and a lot of the rough edges have been worked out.
>
> Most importantly, a blind player has now completed the game using the mod as their primary interface, all the way through to the original `The End` screen.
>
> The next step is getting the mod into the hands of more players and finding out how well it works across different Windows setups.

A quick heads-up before downloading: this README describes the version I'm preparing for open beta. The existing `v0.1.0-alpha` release is older and doesn't include many of the improvements described here.

You can find available downloads and release notes on the [Releases page](https://github.com/techdog420/DragonWarriorBlindAccess-Public/releases). The open beta hasn't been published yet.

If you run into a bug or have feedback from playing, please use the [GitHub issue tracker](https://github.com/techdog420/DragonWarriorBlindAccess-Public/issues). If you're unfamiliar with GitHub, I've included instructions in the [Reporting Problems](#reporting-problems) section below.

## About the Project

The goal of this project is to make the original NES version of **Dragon Warrior** playable without sight.

The mod is written in Lua and runs alongside the game in an NES emulator. It adds screen-reader narration, information about your surroundings, object browsing, navigation assistance, and optional automatic movement.

I want players to be able to explore the world, talk to people, fight monsters, discover things, and experience Dragon Warrior for themselves. The accessibility tools are there to help you play the game, not necessarily to play it for you.

The mod doesn't modify or distribute the original Dragon Warrior ROM.

## What's Changed Since the Alpha?

Quite a bit has changed since the original game-jam release.

- **More reliable navigation around towns and other locations.** I've worked through problems with collision data, moving NPCs, interaction positions, doors, and narrow passages. Focused player testing has covered Brecconary, Kol, Garinham, Rimuldar, Cantlin, and all three floors of Tantegel Castle. Navigation through Charlock and the return trip after victory have also been completed.
- **Connected overworld routes.** Travel routes can now connect supported towns, caves, and landmarks through multiple legs. You can optionally auto-walk through successive waypoints. If you wander away from an established route, the mod can also try to guide you back, stopping at recovery checkpoints so you can decide whether to continue.
- **Better handling of dungeon lighting.** Torch and Radiant now affect navigation assistance according to your chosen settings. You can ask the mod to describe your surroundings within the available light. I've also addressed problems with light-change announcements and leaving dungeons.
- **Easier access to settings and commands.** There are now spoken Mod Settings and Key Reference menus, object sorting options, a quick shortcut to local services, and configurable warnings for low health and Travel.
- **Map descriptions and improved narration.** You can press Shift+D to hear a short description of the artwork for any of the game's 28 interior maps. Battle and spell narration have improved, and the ending narration now includes the credits and `The End`.
- **A more reliable Windows setup.** I've improved keyboard-input recovery, speech-bridge error handling, and installation-path handling. Package testing has included separate NVDA and JAWS gameplay and save/reload sessions, as well as installation under a Windows account with a non-ASCII username.

All of this gives us a much better starting point for the beta. It doesn't mean every possible route, gameplay situation, controller, or computer configuration has been tested.

That's where community testing comes in. If something doesn't work as expected during normal play, I'd like to hear about it.

## Features

Here's what the mod currently offers:

- Screen-reader narration for the title screen, save screens, name entry, dialogue, Yes/No prompts, command menus, shops, inns, item and spell menus, battles, status changes, and other gameplay text.
- Configurable low-health warnings. By default, the mod warns you when your HP reaches 25 percent of your maximum. Warnings are deferred while input is held.
- On-demand announcements of your map, coordinates, HP, MP, level, gold, experience, statistics, and visible screen text.
- Short, spoiler-safe artwork descriptions for all 28 interior maps using Shift+D. Dark dungeons require Torch or Radiant light.
- An object browser that lets you find nearby NPCs, services, treasure, doors, stairs, exits, and travel destinations.
- Object category and reachability filters, Distance or Alphabetical sorting, and a shortcut to services on your current map.
- Spoken path previews and route guidance to selected objects.
- Tap-to-step movement for moving precisely one tile at a time.
- Auto-walk to selected objects and along supported travel routes.
- Connected overworld routes between supported towns, caves, and landmarks, with optional continuous auto-walk and assistance getting back to the route network.
- Configurable dungeon navigation modes and light-aware descriptions of your surroundings.
- Teleport controls for testing, recovering from navigation problems, or bypassing a route that isn't working yet.
- Pathfinding that avoids known damage and death tiles.
- The ability to mark NPCs and objects as visited during your current play session.
- A spoken Mod Settings menu (Shift+F11), with contextual help (Shift+F12), staged changes, and Control+Enter to save.
- A spoken Key Reference (Shift+F12 outside settings) that organizes commands into groups and reads your currently configured mod shortcuts.
- Customizable keyboard shortcuts through `dw_access.ini`.
- Optional controller access to additional mod commands through a JoyToKey example available in the project repository.
- Logging and diagnostic tools to help track down bugs and improve the mod.

## What You'll Need

- Windows.
- Your own legally obtained copy of the supported Dragon Warrior ROM.
- NVDA, JAWS, or an installed Windows SAPI5 voice for fallback speech.

If you're just looking to play, I recommend using the automatic installer. It takes care of the emulator, speech bridge, and other supporting components.

If you'd rather set everything up yourself, you'll also need a supported emulator. FCEUX users doing a manual installation will need Python 3 and the `accessible_output2` package.

I'll cover both installation methods below.

## Emulator Support

### FCEUX: My Recommendation for Playing

FCEUX is the emulator I recommend for normal gameplay.

When comparing both emulators using the same save on my development machine, FCEUX provided smooth movement, object navigation, dialogue, auto-walk, and combat without noticeable emulator lag.

The player package includes a patched version of FCEUX 2.6.6, `qfceux.exe`, with a fix for Lua startup. I recommend sticking with the bundled version unless you have a particular reason to use another build.

FCEUX does still have a few keyboard-focus quirks, which I've described under [Current Limitations](#current-limitations).

### BizHawk: Supported, but Performance May Vary

The mod includes a compatibility layer for BizHawk and should work in both emulators.

I find BizHawk particularly useful for development. Starting the ROM and Lua script, reloading scripts, profiling, and running automated tests tend to be more reliable there.

Unfortunately, Lua memory access in BizHawk has caused noticeable lag on my development machine. This sometimes includes audio cutting out during more demanding operations, such as pathfinding, seam recovery, changing reachability filters, moving between maps, and certain spell-menu actions.

Several rounds of optimization helped, but I still don't find the experience comfortable enough to recommend BizHawk over FCEUX for everyday play.

Your experience may be different depending on your hardware.

## The ROM

The ROM I've been developing and testing against is:

```
Dragon Warrior (USA) (Rev 1).nes
```

The supported ROM is 81,936 bytes and has the following SHA-256 checksum:

```
676B89D76CF9E83EED76C0A67F81DA906916F0BCE321CF3A9A39AC78BC9C0845
```

The revision matters because the mod relies on specific memory addresses and ROM data to understand what's happening in the game.

Other regional releases, revisions, translations, and ROM hacks haven't been validated. They may behave differently or not work at all.

The ROM is copyrighted and is **not included** with the project. You'll need to provide your own legally obtained copy.

The automatic installer checks the ROM's size and SHA-256 checksum before copying it.

If your ROM doesn't match, the installer will show you both the expected and actual fingerprints. It'll also warn you that narration, navigation, game behavior, and save compatibility may be affected.

For advanced users who deliberately want to experiment with a ROM hack or another unsupported ROM, typing `I ACCEPT` allows you to install that exact ROM at your own risk.

I can't guarantee compatibility or support for those ROMs.

The installer never modifies your original ROM file.

## Installation

### Automatic Installation (Recommended)

If you just want to get the game running and start playing, this is the easiest option.

The installer sets up the tested FCEUX environment and the components the accessibility mod needs.

There are two separate command files. You'll run the installer once, then use `Play Dragon Warrior.cmd` whenever you want to play.

1. Head over to the project's [Releases page](https://github.com/techdog420/DragonWarriorBlindAccess-Public/releases) and read the notes for the version you want to download.

   Once the beta is published, choose the beta player ZIP. You may need to expand the **Assets** section to find it.

   Make sure you're downloading the player package, not `Corresponding-Source.zip` or one of GitHub's automatically generated source-code archives.

   Remember that the existing `v0.1.0-alpha` download doesn't contain the beta improvements described in this README.

2. Extract the entire ZIP file to a folder you can write to. Don't try to run the installer directly from inside the ZIP.

3. From the extracted folder, run **`Install Dragon Warrior.cmd`**.

4. Follow the spoken or on-screen instructions. When prompted, select your legally obtained copy of `Dragon Warrior (USA) (Rev 1).nes`.

5. Once installation finishes, run **`Play Dragon Warrior.cmd`** from the extracted folder.

   This is the file you'll use whenever you want to play. You don't need to run the installer again each time.

You'll also find **`Keyboard Commands.txt`** in the extracted folder. I've included this as a quick screen-reader-friendly shortcut reference that you can keep handy while playing.

#### If Something Goes Wrong

Keep all the extracted release files together.

If the installer says it can't find `install_player.ps1`, try extracting the complete release ZIP again.

If installation doesn't finish successfully, check the messages in the command window or open:

```
user\install.log
```

If the play command reports that `play_player.ps1` is missing, re-extract the complete release ZIP.

For other problems starting the game, check the command window or:

```
user\launch.log
```

Your ROM stays yours. It isn't included with the installer, uploaded anywhere by the installer, or distributed through it.

### Manual Installation

You probably won't need this section if you're using the automatic installer.

I've included manual setup instructions for BizHawk users, developers, people who already have their own FCEUX setup, and anyone who prefers to manage the individual components themselves.

#### FCEUX

1. Download or clone the project and keep all its files together in a writable folder.

2. Download [FCEUX 2.6.6](https://fceux.com/web/download.html).

   The main version I've tested is the 64-bit Qt/SDL build containing `qfceux.exe`.

   Regular FCEUX builds don't contain the project's Lua startup fix, which is why I recommend the bundled player runtime for normal play.

3. Install Python 3 and check that the `python` command works in PowerShell.

4. Install the speech bridge dependency:

   ```powershell
   python -m pip install accessible_output2
   ```

5. Put your legally obtained ROM wherever you'd like. It doesn't need to be in the emulator or mod folder.

6. From the mod folder, run the FCEUX launcher, providing the paths to your emulator and ROM:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\launch_dw.ps1 `
     -FceuxPath "C:\Emulators\FCEUX\qfceux.exe" `
     -RomPath "C:\ROMs\Dragon Warrior (USA) (Rev 1).nes" `
     -LuaPath ".\main.lua"
   ```

The launcher sets up the tested keyboard bridge and FCEUX input-safety settings before attempting to load the ROM and `main.lua`.

I recommend using it even if you've installed everything else manually.

FCEUX doesn't always handle command-line loading reliably. If the emulator opens but the ROM or script doesn't load, leave that emulator session running.

Load the ROM through FCEUX's File menu, then open its Lua script window and load `main.lua` manually.

Keep the emulator focused while playing.

If the mod isn't speaking, check that Python works from PowerShell, try reinstalling `accessible_output2`, and check these files in the mod folder:

- `speech_backend.log`
- `speech_bridge.log`

#### BizHawk

1. Download or clone the project into a writable folder.
2. Download and extract [BizHawk](https://github.com/TASEmulators/BizHawk/releases). The version currently tested is BizHawk 2.11.1.
3. Put your legally obtained ROM wherever you'd like.
4. From the mod folder, run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\launch_bizhawk.ps1 `
     -BizhawkPath "C:\Emulators\BizHawk\EmuHawk.exe" `
     -LuaPath ".\main.lua" `
     -RomPath "C:\ROMs\Dragon Warrior (USA) (Rev 1).nes"
   ```

The BizHawk launcher loads the ROM and Lua script together.

Alternatively, you can open the ROM in BizHawk yourself, open its Lua Console, and load `main.lua`.

For safety, general BizHawk keyboard hotkeys are disabled in the configuration included with the source.

If you'd like to enable all the keyboard commands listed in this README, set:

```ini
enable_bizhawk_keyboard_hotkeys=true
```

in `dw_access.ini`.

BizHawk's default NES keyboard controls are different from the FCEUX controls listed below. You'll want to review or remap those before playing.

#### Developer and WSL Launchers

For anyone working on the project from WSL, `./launch_dw.sh` uses FCEUX by default.

If the verified patched runtime exists under `.tools/fceux-release-runtime-verified`, the development launcher selects it automatically.

You can still override that selection with `--fceux-path` or `DW_FCEUX_PATH`.

Use `./launch_dw.sh --emulator bizhawk` when you specifically want to work with BizHawk.

These launchers are mainly intended for development and testing. Most players will be better off using the automatic installer or one of the Windows launchers above.

## Movement and Navigation

There are three main ways to get around with the mod: manual movement and guided routes, auto-walk, and teleporting.

Each serves a different purpose, and you're free to switch between them depending on what you're doing.

### Manual Movement and Guided Routes

You can move around normally using the arrow keys.

With tap-to-step enabled, a quick press of an arrow key completes one tile of movement. This makes it easier to move precisely without accidentally going too far.

Holding down a direction still gives you normal continuous movement.

If you want directions to a nearby object, select it in the object browser and press `O`. The mod will read a path preview.

For supported destinations on the world map, select a Travel object and press `R` to start or check a guided route.

The mod announces directions and landmarks as you move. You're still controlling the character yourself.

Some routes take you through another location along the way. For example, if you're near Tantegel and choose Northern Cave or Swamp Cave, you'll initially follow the established route to Kol.

The route status will identify Kol as your current leg while keeping the cave as your final destination.

When you reach or enter Kol, guidance switches to the next leg of the cave route and waits for your next movement command.

Manual movement and guided routes are good options if you enjoy exploring, want to stay in control of the character, and want to experience the game's normal random encounters and progression.

### Auto-Walk

If you'd rather have the mod handle some of the walking, select an object, then press and release `U`.

The mod calculates a path and starts moving your character toward the selected object. For longer routes, it announces progress along the way and lets you know when you've arrived.

You can press `Shift+U` at any time to stop active or pending auto-walk and cancel guided Travel immediately.

This releases automatic movement, clears the current movement and route state, and removes the active route marker. Your selected object stays selected.

When you're following a guided overworld route, auto-walk uses established waypoints to move toward your destination.

You can choose how this works by opening Mod Settings, selecting **Movement**, and finding **Overworld auto-walk**.

There are two options:

- **One waypoint:** The mod stops at each waypoint. Press and release `U` again whenever you're ready to continue.
- **Continuous:** The mod continues through successive overworld waypoints until you reach your destination or something interrupts movement.

If a route handoff or map transition stops movement, press and release `U` again when you're ready.

Even in Continuous mode, auto-walk won't automatically resume after a battle, menu, dialogue, or recovery checkpoint.

Guided Travel uses an established network of routes. It doesn't currently support full pathfinding from every possible starting point on the world map.

#### Getting Back on Track

If you've wandered away from the route network, Travel can try to find a safe way back without forgetting your original destination.

Recovery stops at checkpoints and when you reach the route network again.

Press and release `U` to continue from each of these stops, even if you're using Continuous mode.

If the mod can't find a safe recovery path, it'll explain the problem. You may need to move manually before trying again.

#### Hazardous Terrain

Auto-walk stops before entering poison swamp and warns you about it.

If you're willing to take the damage, press and release `U` or `F18` again within ten seconds to confirm the crossing.

This confirmation only applies to that particular contiguous stretch of poison swamp.

It's cleared when you reach safe terrain, change routes or maps, encounter an interruption, or press `Shift+U`.

Confirming a swamp crossing doesn't authorize auto-walk to enter other hazardous terrain.

Auto-walk is particularly handy when you're crossing familiar areas, heading to a shop or staircase, or simply want to cut down on repetitive directional input.

Keep in mind that things like battles, dialogue, menus, locked doors, moving NPCs, and map edges that haven't been fully modeled can interrupt the route.

### Dungeon Lighting and Surroundings

I wanted players to have a choice in how much navigation assistance they receive in dark dungeons.

The default mode is **Balanced**. With this setting, you have full navigation assistance while Torch or Radiant provides light. Once the light runs out, assistance beyond your current tile stops.

You'll find two additional options under **Navigation**, then **Dungeon navigation**, in Mod Settings:

- **Authentic:** Object browsing, path previews, and auto-walk are restricted to the area covered by your current light. If the light fades and the remaining auto-walk route falls outside that boundary, movement stops.
- **Unrestricted:** Navigation assistance remains available even without light.

You can press `Shift+N` or `F21` to hear about nearby walls, paths, branches, and objects within your current light.

This surroundings report always respects the physical light boundary, regardless of which navigation mode you're using.

Pressing `Shift+D` gives you a more general description of the artwork on your current interior map. In dark dungeons, you'll need Torch or Radiant light to use this command, even in Unrestricted mode.

### Teleport

Teleport is a more direct way of reaching a selected object.

- `Shift+Enter` teleports you to the selected object. For NPCs, the mod tries to use a nearby interaction cell when possible.
- `Shift+Arrow` teleports you to the cell on that side of the selected object.

I've included teleporting as a recovery and testing tool, and as another option if you encounter a route that isn't usable yet.

It can also skip terrain, encounters, locked areas, and parts of the game's intended progression. For ordinary play, I'd recommend manual movement or auto-walk instead.

**Important warning:** Teleport changes the live game state without going through every normal movement, transition, door, hazard, encounter, or progression check.

The mod refuses known unsafe teleport states, but I can't account for every possible situation.

Misusing teleport could leave your current session in an inconsistent state, cause problems later in the game, or result in unusable save data.

Save normally before experimenting with it.

If the game starts behaving strangely after teleporting, close it without saving and restart from a known-good save.

Teleporting does not modify your original ROM file.

**If your controls stop responding after teleporting:** Try pressing `Start` once. Occasionally, this is needed to restore normal controls.

If that doesn't help, reloading the accessibility script may restore control.

The simplest recovery is usually to close the emulator without saving, run `Play Dragon Warrior.cmd` again, and continue from a known-good save.

## Controls

You don't need to memorize everything in this section before you start playing.

The mod includes a spoken Key Reference, and the player package comes with a separate `Keyboard Commands.txt` file for quick lookup.

All mod shortcuts can be customized through `dw_access.ini`. The commands listed here reflect the current configuration supplied with the project.

### Spoken Settings and Key Help

- `Shift+F11`: Open Mod Settings during normal field play.
  - Left and Right switch between settings groups.
  - Up and Down select an option.
  - Enter begins editing the selected option.
  - Use the arrow keys to change its value.
  - Press Enter again to accept that edit.
  - Press `Control+Enter` to save accepted changes and close settings.
  - Escape cancels an active edit or discards changes from the main settings list.
- `Shift+F12`: Open Key Reference during normal field play.
  - Left and Right switch between command groups.
  - Up and Down select a command.
  - Enter explains the selected command without actually running it.
  - If you're already in Mod Settings, `Shift+F12` explains the current setting instead.
- Escape closes Key Reference. Release any held controls before returning to the game.

Both spoken menus stop automatic movement and capture game input, although the emulator itself continues running.

Available settings include movement, dungeon navigation, object sorting, browsing speech delay, auto-walk progress announcements, and warnings.

Turning Travel warnings off doesn't disable hazard confirmation or movement safeguards.

Low-health warnings have their own setting and default to 25 percent of maximum HP.

### Normal NES Controls in FCEUX

These are the controls used in the tested FCEUX setup:

- Arrow keys: D-pad movement and menu navigation.
- `F`: NES A button. Use this to confirm or interact.
- `D`: NES B button. Use this to cancel or go back.
- `Enter`: Start.
- `S`: Select.

### Information Commands

- `C` or `F17`: Hear your current map and coordinates.
- `H` or `F19`: Hear your HP and MP.
- `I`: Hear your level.
- `G` or `F20`: Hear how much gold you have.
- `E`: Hear your experience.
- `Shift+B`: Hear your full statistics summary.
- `Shift+T`: Read all detected text on the screen.
- `Shift+D`: Hear a short description of the current interior map's artwork.
- `Shift+N` or `F21`: Hear about your dungeon surroundings within the current light.

Artwork descriptions are available for all 28 interior maps and are intended to be spoiler-safe.

They don't change your movement or game state. They use the existing speech queue, so gameplay announcements may interrupt them.

Dark dungeons require Torch or Radiant light for artwork descriptions.

### Objects and Maps

- `J` or `F13`: Previous object.
- `K` or `F14`: Describe the selected object.
- `L` or `F15`: Next object.
- `Q`: Cycle through object categories: All, NPCs, Services, Treasure, Travel, and Doors.
- `Shift+P`: Jump directly to Services on your current map. Your existing sorting and reachability filters are preserved. Use J/K/L to browse and U to approach a selected service. The mod announces reachability and known blockers. Opening Services doesn't move your character.
- `Shift+Q`: Switch between Distance and Alphabetical sorting. This setting is saved immediately.
- `Shift+J`: Previous object category.
- `Shift+K`: Return to the All object category.
- `Shift+L`: Next object category.
- `Shift+O`: Cycle through reachability filters: All, Reachable, and Unreachable.
- `Shift+V`: Mark the selected object as visited for your current session.
- `Shift+F`: Freeze or unfreeze NPC positions for more predictable navigation.

### Movement and Navigation

- `O` or `F16`: Hear a path preview to the selected object.
- `R`: Start or check guided route information for a selected Travel object.
- `Shift+R`: Hear your current route status without starting, replacing, or recalculating the route.
- `U` or `F18`: Auto-walk to the selected object after releasing the key. If guided overworld travel stops before poison swamp, press and release the same key again within ten seconds to confirm that particular contiguous swamp crossing.
- `Shift+U`: Immediately stop active or pending auto-walk and cancel guided Travel.
- `Shift+Enter`: Teleport to the selected object.
- `Shift+Arrow`: Teleport to the adjacent cell on the chosen side of the selected object.

### Debugging Commands

These commands are mainly intended for developers and testers who are trying to track down a problem:

- `Ctrl+M`: Report raw menu cursor information.
- `Ctrl+D`: Dump PPU text and screen data to a diagnostic file.
- `Ctrl+N`: Speak tile information at your current position.
- `Ctrl+Y`: Dump title-screen cursor and memory information.

Setting:

```ini
debug_mode=true
```

in `dw_access.ini` enables `dw_debug.log` and the `dw_commands.txt` automation interface.

Debug mode can be helpful when reporting a problem, but you don't need it enabled for normal play.

## Optional Controller Setup

If you prefer playing with a controller, you can use one for the game's normal controls through FCEUX.

I've also made a tested [JoyToKey example](https://github.com/techdog420/DragonWarriorBlindAccess-Public/tree/main/project_resources/controller/joytokey) available in the project repository.

It lets you assign some of the extra buttons on a modern controller to accessibility commands, such as object browsing, position, HP, gold, path previews, and auto-walk.

JoyToKey isn't bundled with the player release ZIP.

It's completely optional. You can play using the keyboard without setting it up.

Controller button numbering can vary depending on the controller and driver you're using, so consider the example a starting point rather than a layout that's guaranteed to work with every controller.

The README in the linked controller folder contains setup and safety instructions.

## Current Limitations

Although the mod has come a long way, there's still plenty of room for improvement.

I'd rather be upfront about what has and hasn't been tested so you know what to expect.

- **The open beta is still being prepared.** One complete blind-player run has reached the original `The End` screen, which is an important milestone. We still need more players testing different hardware and controller setups, and bugs may interrupt individual playthroughs.
- **ROM compatibility is limited.** Only `Dragon Warrior (USA) (Rev 1)` is currently supported and tested.
- **FCEUX startup can be inconsistent with stock builds.** If you're using an ordinary FCEUX build and the ROM or Lua script doesn't load automatically, you may need to load them manually in the session started by the project launcher. The automatic player package includes the patched and tested runtime.
- **FCEUX sometimes gets stuck in Alt or menu focus.** This can happen after switching windows. Try refocusing the emulator if the game controls or mod shortcuts stop responding.
- **BizHawk can be laggy.** Pathfinding and other memory-intensive operations may cause noticeable delays and audio cut-outs.
- **Navigation testing isn't exhaustive.** Focused testing and cleanup of the towns, castles, and dungeons are complete, with player acceptance of the recorded routes. That doesn't mean every walkable tile, optional interaction, or quest state has been covered. If you find a new navigation problem, please report the map, coordinates, and selected target when possible.
- **Object reachability can change.** A locked door or an NPC standing in a narrow passage may prevent you from reaching an object.
- **Overworld Travel has limited coverage.** Guided routes follow established waypoint segments between supported destinations rather than dynamically finding paths across the entire world map.
- **Auto-walk can be interrupted.** Battles, dialogue, menus, route uncertainty, and unmodeled collisions can stop movement. Wait for NPCs to move or dismiss the interruption, then press and release `U` to try again. You may need to move manually to rejoin a route. Recovery can't safely handle every possible starting position.
- **Teleport bypasses normal movement.** It can also bypass encounters, terrain, and progression barriers. Please read the teleport warning before using it.
- **Visited markers aren't persistent.** They only last for your current play session.
- **Controller layouts may need adjustments.** The optional JoyToKey example may need remapping for your particular controller.
- **NVDA responsiveness is still being investigated.** I'm looking into differences in responsiveness between NVDA and JAWS during object browsing and dialogue. If you experience delayed speech, please mention your screen reader and what you were doing.
- **More Windows and screen-reader testing is needed.** There are many possible setups beyond the development system, and community feedback will be particularly helpful here.

## Where the Project Goes Next

My immediate focus is getting the open beta published, hearing from players, and fixing reproducible gameplay and accessibility problems.

Representative Travel recovery and interruption checks are complete.

Local package testing has included installation, gameplay with NVDA and JAWS, normal saving and reloading, and testing under a Windows account with a non-ASCII username.

The latest package containing the artwork descriptions has passed automated archive and installation checks. Gameplay testing of that exact package and acceptance testing on alternate hardware still need to be completed before publication.

Beyond the beta, there are several ideas I'd like to explore:

- Optional, clue-aware guidance for searching for hidden treasures.
- More speech settings.
- Looking up services in other towns.
- Player-created bookmarks.

These are plans for future development, not features that are already available.

If you're interested in the development side of things, you can find more details in the [project backlog](https://github.com/techdog420/DragonWarriorBlindAccess-Public/blob/main/TASKS.md).

For gameplay bugs and accessibility problems, please use the issue tracker.

## Reporting Problems

Feedback from players is going to be a big part of improving this mod.

If something isn't working, please don't feel that you need to understand the code or figure out why it's happening before reporting it.

Knowing what you were trying to do and what actually happened is already useful.

The best place to report bugs is the project's [GitHub issue tracker](https://github.com/techdog420/DragonWarriorBlindAccess-Public/issues).

If you're new to GitHub, here's a quick explanation:

- **Releases** is where you'll find downloads and release notes.
- **Issues** is where bugs are reported, discussed, and tracked.

GitHub calls individual reports **issues**. You don't need any programming experience to create one.

### Finding or Creating an Issue

1. Open the issue tracker linked above, or select **Issues** from the project's GitHub page. You'll need a free GitHub account to post or comment.

2. Search for a few words describing your problem.

   Check both **Open** and **Closed** issues. Someone may have already reported the same problem, and a closed issue might explain how it was fixed or which version contains the fix.

   If you find a matching issue, feel free to add your experience there.

3. If you're reporting a different problem, sign in and select **New issue**, or follow the [new issue link](https://github.com/techdog420/DragonWarriorBlindAccess-Public/issues/new/choose).

   Choose an appropriate template if one is available, or open a blank issue.

4. Give your report a short, descriptive title and explain the problem.

   Something like "Auto-walk stops before the inn in Brecconary" makes it easier to tell what the report is about.

5. Select **Submit new issue** or **Create**, depending on what the form shows.

   Keep the link to your issue so you can return to it, read replies, and answer any follow-up questions.

If an issue link displays **404** or **Not Found**, open the project's main GitHub page and select **Issues**. You only need to sign in when you want to post or comment.

GitHub also has its own [guide to creating an issue](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/creating-an-issue) if you need more help.

### What to Include in a Bug Report

Include as much of the following information as you can.

Don't worry if you can't provide everything. I'd much rather receive a useful description of the problem than have you decide not to report it because you don't have logs or every technical detail.

- The mod release version you're using, or the source commit if you're running from a checkout.
- Your Windows version, emulator name and version, and screen reader name and version.
- Whether you're using the bundled player package or a manual installation.
- Whether you're playing with a keyboard or controller.
- Your Dragon Warrior ROM revision, particularly whether it's the supported Rev 1 ROM.
- What you were trying to do, which steps or keys led to the problem, what happened, and what you expected to happen. If you remember the spoken message, please include it.
- For navigation problems, your map and coordinates (`C`), selected object (`K`), route status (`Shift+R`), and whether you were moving manually or using auto-walk. Mention dungeon lighting, locked doors, or moving NPCs if they seem relevant.
- Whether the problem happens repeatedly and whether anything you tried restored normal gameplay.

### Installation and Speech Logs

If you're having trouble installing or starting the player package, include any relevant lines from these files in the extracted folder:

```
user\install.log
user\launch.log
```

If you're experiencing speech problems, these logs may also be useful when present:

```
app\speech_backend.log
app\speech_bridge.log
```

For manual installations, the speech logs are located in the mod folder.

### Debug Logging

Debug logging is optional, but it can be especially useful if you've found a gameplay problem that you can reproduce.

To enable it:

1. Close the game.
2. Open `app\dw_access.ini` if you're using the player package, or `dw_access.ini` in a manual installation.
3. Set:

   ```ini
   debug_mode=true
   ```

4. Relaunch the game and reproduce the problem.
5. Include the relevant portion of `app\dw_debug.log`, or `dw_debug.log` for a manual installation, in your report.

You can turn debug mode off again afterward.

A written report is perfectly fine. Screenshots and recordings are optional, not requirements.

Please create one issue per distinct problem when possible. It makes individual bugs much easier to track.

Before posting logs, take a moment to check for personal file paths or other private information.

Please don't upload or attach the copyrighted Dragon Warrior ROM.

## Development and AI Use

I also want to be transparent about how this project is being developed.

This is a human-directed, human-tested, and human-playtested accessibility project. AI coding tools have been part of my development workflow, helping with implementation, code review, documentation, log analysis, and automated testing.

Gameplay behavior and accessibility decisions are validated through human-directed testing in the emulator.

Ultimately, what matters is whether the mod works for the people who are actually playing the game.

## Licenses and Third-Party Notices

Licenses and third-party notices can be found in the `licenses` folder.

Matching source code for bundled copyleft components is available in the same-version `Corresponding-Source.zip` release asset.

## Legal Notice

This is an unofficial, fan-made accessibility project.

It isn't affiliated with or endorsed by Square Enix, Nintendo, or the original game's developers or publishers.

Dragon Warrior and its related names and assets belong to their respective owners.