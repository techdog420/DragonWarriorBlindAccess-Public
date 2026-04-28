# Handoff 2026-04-23 — LoadLua Failure Matrix

## What happened this session

The user re-ran `./launch_dw.sh` and it failed at the launcher's
`Wait-ForDebugLog` stage.

Fresh evidence now shows the failure happens before any Lua-side startup files
refresh on the failing runs.

## Key findings

### 1. `qfceux.exe` receives `--loadlua=...`, but the script still does not start

Verified by querying live Windows process command lines after launch.

Observed on multiple fresh processes:
- `qfceux.exe --loadlua=D:\modding\dragonwarrior1\main.lua "Dragon Warrior...nes"`
- `qfceux.exe --loadlua=D:\modding\dragonwarrior1\frame_probe.lua "Dragon Warrior...nes"`
- `qfceux.exe "Dragon Warrior...nes" --loadlua=D:\modding\dragonwarrior1\frame_probe.lua`
- `qfceux.exe --loadlua=D:\modding\dragonwarrior1\frame_probe.lua D:\emulation\nes\dw1_cli_test.nes`

So the launcher is successfully passing the Lua argument; the issue is that
FCEUX is silently not running the script.

### 2. This is not a `main.lua`-specific failure

Used `frame_probe.lua` as a minimal probe script.

Expected if it loaded:
- `frame_probe.txt` should be deleted/recreated immediately
- it should then append `frame=60`, `frame=120`, etc.

Actual result across all tested launch variants:
- `frame_probe.txt` remained unchanged at the old timestamp
- contents stayed:
  - `frame_probe started`
  - `source=@D:/modding/dragonwarrior1/frame_probe.lua`

That rules out `main.lua` and points to a general startup-Lua failure.

### 3. Tested launch variants that all failed

All of the following started a fresh `qfceux.exe` process but did **not** start
Lua:

1. Existing launcher default order:
   - `--loadlua=<script>` then ROM
2. Existing launcher ROM-first order:
   - ROM then `--loadlua=<script>`
3. Simpler ROM path:
   - `D:\emulation\nes\dw1_cli_test.nes`
4. Direct PowerShell `Start-Process` launch:
   - bypassed `launch_dw.cmd`
5. Temporary config autoload attempt:
   - set `SDL.LuaScript = D:/modding/dragonwarrior1/frame_probe.lua`

Result: no variant caused `frame_probe.lua` to run.

### 4. No hidden/modal error dialog was found

Used a small PowerShell/user32 window enumerator against the live FCEUX PID.

Observed:
- one visible main Qt window: title `FCEUX 2.6.6`
- no visible error/message dialog related to Lua loading

### 5. Keyboard automation is partially available, but no tested reload path succeeded

Useful discovery:
- a PowerShell **file** can use `WScript.Shell.AppActivate(...)` successfully
- inline `powershell.exe -Command` + COM frequently hit WSL interop errors, but
  `-File` worked

Tested key paths against failing probe windows:
- `Ctrl+L`
- `Shift+L`
- `Alt+S`, then `R`

None of them caused `frame_probe.txt` to refresh.

### 6. Relevant config observations

From `D:\emulation\fceux\bin\fceux.cfg`:
- `SDL.AutoResume = 1`
- `SDL.Hotkeys.LoadLua = Ctrl+L`
- `SDL.LastLoadLua = D:/modding/dragonwarrior1/main.lua`
- `SDL.LuaScript =` was originally blank

`SDL.LuaScript` was temporarily set to `frame_probe.lua` for testing, then
restored to blank at the end of the session.

## Supporting files added for debugging

These were added as diagnostics and may still be useful next session:
- `appactivate_probe.ps1` — activate FCEUX and send test key chords
- `list_windows.ps1` — enumerate top-level windows for a given PID

## Current best understanding

The current local `qfceux.exe 2.6.6` on this machine is intermittently or
silently refusing to start Lua scripts from startup mechanisms that should work:
- command-line `--loadlua=...`
- ROM-first command-line order
- config-based `SDL.LuaScript`

This is now broader than a launcher quoting bug.

## Addendum: manual UI load clue from the user

After the matrix above, the user manually investigated further and found:
- when FCEUX is launched through the project launcher, manually starting the
  accessibility script from the UI also fails
- JAWS/output suggested an error around `main.lua` line `18`
- when FCEUX is launched manually through the GUI, the script starts correctly

That points to a second likely issue: launcher-started emulator instances may
be using a different current working directory or module search path, causing
`require "tolk"` at `main.lua:18` to fail even for manual UI loads.

To harden against that, `main.lua` was updated to prepend its own directory to
`package.path` before the first `require(...)`.

Implication:
- if startup `--loadlua` is still broken after this patch, the project may have
  **two** separate problems:
  1. startup Lua not running automatically
  2. manual UI load in launcher-started instances failing due to module lookup

Immediate retest after this patch:
- launch FCEUX through the project launcher
- then manually load `main.lua` from the FCEUX UI
- if that now works, the `package.path` hardening fixed the manual-load branch
  even if startup autoload still needs a separate workaround

### Result

Confirmed by the user:
- after the `package.path` bootstrap was added to `main.lua`
- a launcher-started FCEUX instance could manually load `main.lua`
- the accessibility script started successfully

That confirms the manual-load failure was a module lookup / working-directory
problem, and that this branch is now fixed.

Remaining issue:
- automatic startup Lua loading via launcher / `--loadlua` still appears broken

## Best next steps

Recommended next investigation order:

1. Inspect the FCEUX UI path manually on a fresh launch:
   - verify whether the ROM itself actually opens
   - verify whether `Load Lua Script` / `Reload current Lua script` works by hand
   - note the exact menu names visible in this Qt build

2. If manual UI reload works:
   - use the new PowerShell file-based activation helpers to build a launcher
     fallback around the exact working UI path

3. If manual UI reload also fails:
   - this likely points to a local FCEUX/runtime problem rather than launcher
     code
   - likely next checks: newer interim build, config reset, or emulator-side
     environment drift

## Cleanup performed

- Restored `SDL.LuaScript =` blank in `fceux.cfg`
- Closed the final probe-launched `qfceux.exe` instance
