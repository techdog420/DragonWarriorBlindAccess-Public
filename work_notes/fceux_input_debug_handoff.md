# FCEUX Input Hard-Lock Debug Handoff

Updated: 2026-07-07

## Why this exists

Cantlin surveys exposed a hard-lock mode where the Dragon Warrior Lua script
and FCEUX command polling stay alive, but the game no longer responds to
manual or Lua-injected controller input. This is deeper than the older stale
`LeftAlt` / `$0047` symptom:

- `recover_fceux_input.sh` can clear visible stale Alt state.
- `clear_game_input` and the auto-clear path can clear `$0047`.
- `reset_movement_state` can clear `$003C/$003D`.
- Manual directions and raw Lua `START` / `A` can still reach
  `joypad.read()`.
- The hero still does not move, and neither raw nor physical `A` opens the
  normal field command menu.
- Restoring a save state restores controls.

Current conclusion: the hard lock is no longer explained as an FCEUX input
delivery failure. FCEUX and Lua can deliver input, but the ROM can stop polling
controllers because it is trapped in its sprite-OAM clear loop when `$004E`
contains a non-terminating object-table offset.

## 2026-07-07 update: ROM-side OAM loop identified

After adding `report_cpu_state[:TAG]` and reloading the Lua script, the wedged
Cantlin state reported `PC=$B9F8` / `PC=$B9ED` with `$0047=0x00` and
`$003C/$003D=0x00/0x00`. The mapped ROM bank 0 code at `$B9E9-$B9F8` loads
`Y` from RAM `$004E`, writes `0xF0` to `$0200,Y`, increments `Y` by 4, and
loops until `Y==0`. The captured state had `$004E=0x2A`, which is not a
multiple of 4, so the loop cannot terminate.

This means the hard lock is no longer primarily an FCEUX controller-input
problem. The next target is the writer that corrupts `$004E`. The Dragon
Warrior repo now has narrow Lua diagnostics:

```text
report_oam_offset[:TAG]
watch_oam_offset[:on|off|status|TAG]
```

After the first live arm, save-state restore produced tens of thousands of
normal `$004E` writes, so per-write logging is too noisy for the repro. The
default `watch_oam_offset:repro` command is now quiet: it keeps recent write
context in memory and logs `OAM_OFFSET_STUCK` only if the CPU is actually at
`$B9ED`/`$B9F8` with a non-terminating `$004E`. Per-write output is available
only through `watch_oam_offset_verbose[:TAG]` and should be used for tiny
captures.

Follow-up quiet-watcher repro caught the bad writer as the ROM object-draw
path around `$B970`/`$B972`. The bad `$004E=0x2A` value maps to NPC
object-table slot 14 (`0x2A / 3`), and the mod-side cause was parked NPCs
using low coordinate `(31,31)`. Dragon Warrior skips renderer slots only when
the low x/y coordinate bits are `(0,0)`, so parked NPCs are now written with
low coordinate `(0,0)` in `map_survey.lua` and `route_manager.lua`.

Clean validation after save-state restore passed: `survey_target:Old Man
4,park_npcs` produced no `OAM_OFFSET_STUCK`, `watch_oam_offset:status` stayed
at `stuck_reports=0`, and controls did not hard-lock. The remaining Old Man 4
failure is route geometry/churn.

## Source checkout

Upstream FCEUX tag `v2.6.6` was cloned separately from the Dragon Warrior mod:

- Path: `/mnt/d/modding/fceux-input-debug`
- Windows path: `D:\modding\fceux-input-debug`
- Branch: `codex/input-hardlock-diagnostics`
- Upstream tag used: `v2.6.6`, matching the installed `qfceux` version.

Do not mix these changes into `/mnt/d/modding/dragonwarrior1`; this is an
emulator-source detour.

## Instrumentation patch

The branch adds opt-in trace logging behind environment variables. It is off
unless `FCEUX_DW_INPUT_TRACE` is set.

Changed files in the FCEUX checkout:

- `src/input_trace.h`
- `src/drivers/Qt/input.cpp`
- `src/fceu.cpp`
- `src/input.cpp`
- `src/lua-engine.cpp`
- `src/state.cpp`
- `src/x6502.cpp`

Trace points:

- `QT_KEY`: Qt/SDL keydown and keyup events, including modifier state.
- `QT_GAMEPAD`: computed Qt driver `JSreturn` physical-controller bitfield.
- `LUA_JOYPAD_SET`: Lua `joypad.set` keep/force masks.
- `LUA_READ_JOYPAD`: merge of physical input with Lua-forced input.
- `UPDATE_GP`: core gamepad byte after FCEUX updates controller state.
- `B4016`, `STROBE_GP`, `READ_GP`, `JPREAD`: `$4016` strobe and serial reads.
- `STATE_LOAD_UI_*`, `STATE_LOAD_FP_*`, `LOAD_GP`: savestate-load boundaries.
- `RAM_WRITE`: CPU writes to watched RAM `$0038-$004F`, including direct fast
  RAM writes and normal low/mirrored RAM handlers.
- `LUA_MEM_WRITE`: Lua `memory.writebyte` writes to watched RAM, logged
  separately so cleanup writes can be distinguished from CPU/game writes.

The trace writes one line per event and closes the file immediately so a hang
or crash should still leave the latest evidence on disk.

## Build and verification

The Windows diagnostic build is complete as of 2026-07-06.

Diagnostic runtime folder:

```text
D:\modding\DragonWarrior1\.tools\fceux-build-tools\build-fceux\bin
```

Diagnostic executable:

```text
D:\modding\DragonWarrior1\.tools\fceux-build-tools\build-fceux\bin\qfceux.exe
```

SHA256:

```text
D3AEBB34138EF9FC026FAF8F90BEF9867B3434AAF6B3948474359A1D7B6A520F
```

The deployed folder includes `qfceux.exe`, `SDL2.dll`, `archive.dll`,
`lua51.dll`, `lua5.1.dll`, `Qt5Core.dll`, `Qt5Gui.dll`, `Qt5Widgets.dll`,
`platforms\qwindows.dll`, imageformat plugins, and
`styles\qwindowsvistastyle.dll`.

The built `qfceux.exe` was checked for embedded trace strings including
`QT_KEY`, `LUA_READ_JOYPAD`, `READ_GP`, `RAM_WRITE`, `LUA_MEM_WRITE`,
`BUTTONS_PRESSED`, `source=cpu_fast_ram`, and `source=cpu_handler_low`.

Default RAM-write trace volume was reduced after the first live run made
FCEUX nearly unusable. With only `FCEUX_DW_INPUT_TRACE=1`, RAM tracing now logs
`$0047` / `BUTTONS_PRESSED` only when the old or new byte is nonzero or the
byte changes. The broader `$0038-$004F` RAM stream still exists, but requires
`FCEUX_DW_INPUT_TRACE_VERBOSE=1`.

Earlier source-only checks from `/mnt/d/modding/fceux-input-debug`:

```bash
git diff --check
g++ -std=c++11 -fsyntax-only -DPSS_STYLE=1 -Isrc src/input.cpp
g++ -std=c++11 -fsyntax-only -DPSS_STYLE=1 -Isrc src/state.cpp
g++ -std=c++11 -fsyntax-only src/input_trace.h
```

These applied to the earlier input-only patch. After the RAM-write trace
additions, Windows CMake/MSBuild produced
`.tools\fceux-build-tools\build-fceux\src\Release\fceux.exe`; that executable
was copied to
`.tools\fceux-build-tools\build-fceux\bin\qfceux.exe`. Current `git diff
--check` in the FCEUX checkout is noisy on uncommitted diagnostic whitespace
and should not be treated as a clean signal until the patch is normalized.

## Build notes

- Build helper and downloaded tools are under ignored
  `D:\modding\DragonWarrior1\.tools\fceux-build-tools`.
- Visual Studio 2022 Build Tools and bundled CMake were used instead of the
  upstream VS 2019 script paths.
- Qt was staged with `aqtinstall`: Qt `5.15.2 win64_msvc2019_64`, archives
  `qtbase` and `qttools`.
- SDL2 `2.24.1` was downloaded from the upstream SDL GitHub release.
- The prebuilt libarchive URL in upstream's batch file returned a CloudFront
  `504` page, so libarchive `3.6.2` was built locally from source and installed
  under `.tools\fceux-build-tools\deps\libarchive`.
- The Codex process environment contained both `PATH` and `Path`, which made
  MSBuild fail with `Item has already been added. Key in dictionary: 'PATH'
  Key being added: 'Path'`. The helper launches builds through
  `Start-Process -UseNewEnvironment` with a single `Path`.
- FCEUX's generated `fceux_git_info.cpp` step runs plain `git` from the build
  directory. The helper sets `GIT_DIR=D:\modding\fceux-input-debug\.git` and
  `GIT_WORK_TREE=D:\modding\fceux-input-debug` so it records the FCEUX repo
  instead of the Dragon Warrior repo.
- The final wrapper invocations hit outer Codex command timeouts after the
  logs had already reached completion, but the deployed binary and DLLs are
  present and verified.
- The RAM-write rebuild hit the same duplicate `PATH` / `Path` failure when
  run directly from Codex PowerShell. A clean PowerShell wrapper got through
  compile/link, but its outer command did not return cleanly after the link.
  The useful evidence is in
  `.tools\fceux-build-tools\ramtrace_build_stdout.log`: it reaches
  `fceux.vcxproj -> ...\src\Release\fceux.exe`, stderr is empty, and no
  compiler/build process remains.
- The quiet RAM-trace rebuild behaved the same way: the wrapper timed out, but
  `.tools\fceux-build-tools\quiet_ramtrace_build_stdout.log` reaches
  `fceux.vcxproj -> ...\src\Release\fceux.exe`, stderr is empty, and the
  deployed `qfceux.exe` has SHA256
  `D3AEBB34138EF9FC026FAF8F90BEF9867B3434AAF6B3948474359A1D7B6A520F`.

## Rebuild recipe

The local ignored helper is:

```powershell
D:\modding\DragonWarrior1\.tools\fceux-build-tools\build_diagnostic_fceux.ps1
```

It expects the staged tools already present under `.tools\fceux-build-tools`.
Launch it from a clean child environment with one `Path`; do not run it from a
normal Codex PowerShell environment that contains duplicate `PATH` and `Path`
keys.

Do not overwrite the installed emulator yet. Use this diagnostic binary via a
temporary launch shim or point `launch_dw.ps1` at it only for the trace run.

## Trace run recipe

In PowerShell, before launching the diagnostic `qfceux.exe`:

```powershell
$env:FCEUX_DW_INPUT_TRACE = "1"
$env:FCEUX_DW_INPUT_TRACE_FILE = "D:\modding\fceux-input-debug\dw_fceux_input_trace.log"
```

For very noisy serial/RAM logging, also set:

```powershell
$env:FCEUX_DW_INPUT_TRACE_VERBOSE = "1"
```

Start without verbose first. A raw `A` or `START` injection should already arm
a short serial-read window. Verbose mode now also re-enables the broad
`$0038-$004F` RAM-write firehose and should be used only for short captures.

Important direct-launch caveat:

- The diagnostic binary uses its local
  `.tools\fceux-build-tools\build-fceux\bin\fceux.cfg` when launched directly.
  On 2026-07-07 that config still had native keyboard-backed `GamePad.0`
  enabled, unlike the normal launcher-managed config.
- A quiet-trace Cantlin repro showed Lua forcing `0x10` for movement while
  FCEUX `QT_GAMEPAD` supplied raw `pads=[01,00,00,00]`; `LUA_READ_JOYPAD`
  merged those into `0x11`, opening the in-game command menu. No nearby
  `QT_KEY` event appeared in the trace tail, so this looked like stale native
  GamePad.0 keyboard state being ORed with Lua automation.
- Do not rely on hand-editing that `.tools` config. A later direct restart
  reloaded Cantlin successfully, but FCEUX rewrote/restored the same local
  config to `SDL.Input.GamePad.0.DeviceType = Keyboard`, `SDL.ToggleMenu = 0`,
  `SDL.Hotkeys.MainMenuHide = Alt+/`, and
  `SDL.Hotkeys.FullScreen = Alt+Return`. Use `launch_dw.ps1 -FceuxPath` for the
  diagnostic binary so the launcher applies mitigations immediately before
  startup, or continue with source-level tracing around `DTestButton`.

Recommended capture sequence once the diagnostic binary is running:

1. Launch Dragon Warrior with the normal ROM and `main.lua`, preferably through
   `launch_dw.ps1 -FceuxPath <diagnostic qfceux.exe>` rather than by directly
   starting the `.tools` executable.
2. Confirm Lua polling with `launcher_probe`.
3. Confirm `input_status` shows `$0047 buttons=0x00` and no native joy input.
4. Reproduce the Cantlin survey check with
   `survey_target:Old Man 4,park_npcs`.
5. If `QT_GAMEPAD pads=[01,00,00,00]` is gone, the direct-launch config was the
   immediate raw-A source. If it recurs, instrument `DTestButton`/button names
   next to identify the exact native mapping that remains active.

Interpretation:

- If `QT_GAMEPAD` or `LUA_JOYPAD_SET` shows the button but
  `LUA_READ_JOYPAD` does not, the Lua merge path is suspect.
- If `LUA_READ_JOYPAD` and `UPDATE_GP` show the button but `READ_GP` does not,
  the core controller latch/serial-read path is suspect.
- If `READ_GP` returns the right bit and `JPREAD` reaches `$4016`, FCEUX is
  delivering input and the Dragon Warrior game state/controller-read loop is
  likely wedged.
- If `RAM_WRITE` shows `$0047` / `BUTTONS_PRESSED` changing after valid
  `$4016` reads, the ROM sampled the controller normally and the lock is
  likely downstream in game movement/state. If `$0047` changes without a
  matching `$4016` read, compare nearby `LUA_MEM_WRITE` and cleanup lines for
  stale or redirected RAM writes.
- If save-state restore changes `readbit` / `joy` in the trace and controls
  recover, the restore boundary may identify the stuck state.

Current Dragon Warrior-side conclusion from 2026-07-07:

- The hard lock is now explained one layer above FCEUX input delivery. The ROM
  is trapped in its `$B9ED-$B9F8` sprite-OAM clear loop with `$004E=0x2A`, a
  non-multiple-of-4 offset that can never reach zero when incremented by 4.
- Quiet `watch_oam_offset` captured the recent writer as the ROM object-draw
  path around `$B970`/`$B972`; `$2A / 3 = 14`, pointing at NPC object-table
  slot 14 in the parked-NPC survey.
- Root cause in the mod: parked NPCs used low coordinate `(31,31)`, but the
  Dragon Warrior renderer skips only object slots whose low x/y coordinate
  bits are `(0,0)`. The mod now parks survey and autowalk NPCs with low
  coordinate `(0,0)` while preserving high sprite/direction bits.
- A Lua script reload alone does not unwind the already-wedged ROM state. If
  a baseline still reports Cantlin `(25,23)`, `pc=$B9F6/$B9F8`, and
  `$004E=0x2A`, restore the clean Cantlin save state before retesting.
- Clean live validation after save-state restore matched that expectation: no
  `OAM_OFFSET_STUCK`, `stuck_reports=0`, and no hard control lock from NPC
  parking. Nine follow-up route seams were confirmed with same-origin probes
  and promoted to `MAP_DIRECTIONAL_BLOCKS[0x0A]`: `(21,23).west`,
  `(21,24).west`, `(21,24).east`, `(21,24).south`, `(22,23).south`,
  `(23,24).west`, `(23,25).west`, `(23,25).south`, and `(24,24).south`.

## Dragon Warrior repo state

The mod repo has uncommitted guardrail/debugging changes from the Cantlin
session. Do not revert them unless explicitly asked.

Relevant files include:

- `debug_tools.lua`
- `debug_hooks.txt`
- `map_survey.lua`
- `route_manager.lua`
- `test_debug_tools.lua`
- `test_map_survey.lua`
- `test_route_manager.lua`
- `session_handoff.md`
- `work_notes/current_investigation.md`
- `project_resources/maps/cantlin/`

Older broad Cantlin suspected-tile lists remain contaminated by emulator
hard-locks and route churn. Do not promote Old Man 4 / `(25,23)` broad
suspected blockers; only the nine same-origin-probed seams listed above are
permanent map data.
