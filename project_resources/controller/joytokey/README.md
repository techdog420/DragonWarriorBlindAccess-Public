# Controller Hotkeys With JoyToKey

The Dragon Warrior Accessibility Mod can be played normally with a controller
through FCEUX. This optional setup adds extra controller buttons for mod
commands such as object navigation, HP, gold, position, route guidance, and
auto-walk.

This is not required to play the mod. It is a convenience layer for players who
want more of the accessibility controls available from the controller.

## Why A Mapper Is Needed

NES controllers only have a small set of inputs: D-pad, A, B, Start, and
Select. Those buttons need to stay reserved for normal Dragon Warrior gameplay.

Modern controllers usually have extra buttons, such as bumpers, triggers, and
stick clicks. FCEUX does not expose those spare buttons directly to the Lua mod
as extra NES controls in the way this feature needs. A controller-to-keyboard
mapper fills that gap.

A mapper watches for controller button presses and sends keyboard keys to the
focused Windows application. In this setup, the mapper sends high function keys
such as F13 through F20. FCEUX passes those keyboard keys through to the mod,
and the mod treats them as optional alternate hotkeys.

## Mapper Options

Any mapper that can send F13 through F20 may work. The included profile and the
current tested setup use JoyToKey.

Possible options include:

- JoyToKey: tested with this mod on Windows and included as the example setup.
  Official site: https://joytokey.net/en/
- Steam Input: useful if you already launch FCEUX through Steam as a non-Steam
  game, but not the setup currently packaged here.
- AntiMicroX: open-source mapper for Windows and Linux. It may work if it can
  send the needed high function keys, but it has not been validated for this
  mod. Project site: https://github.com/AntiMicroX/antimicrox
- reWASD: commercial controller remapper. It may work if configured to send the
  same keys, but it has not been validated for this mod.
  Official site: https://www.rewasd.com/

For alpha testing, JoyToKey is the recommended path because it is the mapper we
have verified.

## JoyToKey Overview

JoyToKey converts controller input into keyboard or mouse input for Windows
applications. It must be running while you play, and the FCEUX window must have
focus for the mapped keys to reach the emulator.

The official JoyToKey website and download page are:

- https://joytokey.net/en/
- https://joytokey.net/en/download

Download JoyToKey from the official site when possible. The JoyToKey author
warns that unofficial download sites may distribute modified or unsafe copies.

## Install JoyToKey

1. Download the latest JoyToKey release from the official JoyToKey website.
2. Install JoyToKey, or extract the portable package if you chose that version.
3. Connect your controller.
4. Start JoyToKey.
5. Confirm that JoyToKey detects your controller and lists its buttons.

JoyToKey stores user profiles in the user's Documents folder when installed
with the standard installer. On many systems this is:

```text
C:\Users\<your user name>\Documents\JoyToKey
```

If Windows redirects Documents into OneDrive, the path may instead be similar
to:

```text
C:\Users\<your user name>\OneDrive\Documents\JoyToKey
```

## Included Example Profile

This folder includes an example JoyToKey profile:

```text
DragonWarrior1.cfg
```

The profile maps spare controller buttons to the mod's optional high function
key bindings.

Current example mappings:

- Button03 sends F13: previous object
- Button04 sends F15: next object
- Button05 sends F14: current object / target info
- Button06 sends F16: route guidance to selected object
- Button09 sends F19: HP and MP
- Button10 sends F20: gold
- Button11 sends F17: position / where am I
- Button12 sends F18: auto-walk to selected object

Controller button numbers can vary by controller model and driver. Treat this
profile as a tested starting point, not a universal button layout.

## Use The Example Profile Safely

If you do not already use JoyToKey:

1. Close JoyToKey.
2. Open your JoyToKey profile folder in Documents.
3. Copy the included `DragonWarrior1.cfg` into that folder.
4. Start JoyToKey.
5. Select `DragonWarrior1` in JoyToKey.
6. Start FCEUX and load the Dragon Warrior Accessibility Mod.
7. Keep JoyToKey running while playing.
8. Click or Alt+Tab to FCEUX so the FCEUX window has focus.

If you already use JoyToKey:

1. Close JoyToKey.
2. Back up your existing JoyToKey profile folder.
3. Copy the included `DragonWarrior1.cfg` into your JoyToKey folder.
4. If you already have a profile with that exact filename, rename one of the
   files before copying so neither profile is overwritten.
5. Start JoyToKey.
6. Select `DragonWarrior1`.
7. Adjust button assignments if your controller numbers buttons differently.

This keeps your existing JoyToKey profiles intact.

## FCEUX And Mod Settings

The mod's default `dw_access.ini` includes the alternate function-key bindings
used by this profile:

```text
key_position=C|F17
key_hp=H|F19
key_gold=G|F20
key_object_prev=J|F13
key_object_current=K|F14
key_object_next=L|F15
key_pathfind=O|F16
key_auto_walk=U|F18
```

The letters remain available from the keyboard. The F13 through F20 bindings
are for the optional controller mapper setup.

If you edit `dw_access.ini` while the mod is running, use the mod's
`reload_config` command or restart the Lua script before testing the new
bindings.

## Quick Test

1. Start JoyToKey.
2. Select `DragonWarrior1`.
3. Start FCEUX and load the mod.
4. Make sure the FCEUX window has focus.
5. Press the mapped controller buttons.

Expected results:

- Object navigation buttons should move through nearby objects or describe the
  current object.
- Position should speak the current map and coordinates.
- HP should speak current HP and MP.
- Gold should speak current gold.
- Route guidance should describe the path to the selected object.
- Auto-walk should begin walking to the selected object after the button is
  released.

If nothing happens, check that JoyToKey is still running and that FCEUX has
focus.

## Common Pitfalls

- JoyToKey must be running. Closing JoyToKey disables the controller-to-keyboard
  mappings.
- FCEUX must have focus. If another window is focused, the mapped keys may go to
  that window instead.
- Do not map NES gameplay buttons to mod hotkeys. D-pad, A, B, Start, and
  Select should remain normal FCEUX controller input.
- Existing JoyToKey users should still back up their profile folder first. The
  included `DragonWarrior1.cfg` name avoids the default `Profile 1.cfg`
  collision, but any exact filename collision should be resolved before copying.
- Controller button numbers vary. If a button triggers the wrong mod command,
  edit that button in JoyToKey or update the profile file.
- Some keyboards and tools cannot easily enter F13 through F20 directly. Editing
  the JoyToKey profile file can be easier than using the assignment dialog.
- If FCEUX appears to ignore input after Alt+Tab or menu use, refocus FCEUX. In
  the development environment, `recover_fceux_input.sh` can also clear stale
  Alt/menu focus state.

## Notes For Testers

This setup has been verified with FCEUX receiving JoyToKey-generated F13 through
F20 key presses. It should be treated as an optional alpha feature. Please report
the controller model, JoyToKey version, and which button number JoyToKey shows
for any mapping that behaves differently.
