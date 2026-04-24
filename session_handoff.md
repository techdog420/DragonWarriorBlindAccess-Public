# Session Handoff — 2026-04-23

## Active Handoff Set

Start here:
- `HANDOFF_2026-04-23_loadlua_failure_matrix.md` ← **most recent**
- `HANDOFF_2026-04-23_launch_probe.md` ← **most recent**
- `HANDOFF_2026-04-22_east_wing_y4_fix.md` ← **most recent**

Historical notes:
- `HANDOFF_2026-04-17_survey_abort_staircase_fix.md`
- `handoff_archive/`

## Current State

### Changes made this session (2026-04-23)

**Startup Lua failure matrix** (`HANDOFF_2026-04-23_loadlua_failure_matrix.md`):

The user reran `./launch_dw.sh` and it failed waiting for `dw_debug.log`.
Fresh testing then showed that startup Lua is failing before any Lua-side files
refresh, even though the live `qfceux.exe` process receives `--loadlua=...`.

`frame_probe.lua` was used to isolate startup-Lua behavior from `main.lua`.
It failed to start under all tested variants:
- default `--loadlua ... ROM` order
- ROM-first order
- no-space ROM path (`dw1_cli_test.nes`)
- direct PowerShell `Start-Process`
- temporary `SDL.LuaScript = frame_probe.lua`

No visible Lua error dialog was present. File-based PowerShell automation can
activate the FCEUX window, but tested `Ctrl+L`, `Shift+L`, and `Alt+S` → `R`
did not revive the script.

Temporary cleanup completed:
- restored `SDL.LuaScript =` blank
- closed the final probe-launched `qfceux.exe`

Immediate next step:
- manual UI verification inside FCEUX on a fresh launch to confirm whether ROM
  loading and Lua reload work by hand in this build

**Manual-load path hardening** (`main.lua`):

User follow-up evidence showed that launcher-started emulator instances also
failed when manually loading the accessibility script, with output pointing near
`main.lua` line `18` (`require "tolk"`).

`main.lua` now prepends its own directory to `package.path` before the first
`require(...)`, so sibling modules like `tolk.lua` no longer depend on FCEUX's
current working directory.

Immediate retest after this patch:
- launch through the project launcher
- manually load `main.lua` in FCEUX
- if it now starts, the manual-load branch is fixed even if startup autoload
  remains broken

Result:
- user confirmed manual loading now works in a launcher-started emulator
- this fixes the manual-load/module-search-path branch
- remaining launcher issue is startup autoload only

### Changes made this session (2026-04-23)

**Launcher readiness probe cleanup** (`launch_dw.ps1`, `debug_tools.lua`,
`debug_hooks.txt`):

Launch debugging found that the old readiness probe used `speech_status`, which
is not a pure command-polling test because it routes through the speech backend.

Three changes applied:
- `debug_tools.lua` added `launcher_probe[:TAG]`, which writes
  `LAUNCHER_PROBE: TAG` to `dw_debug.log`
- `launch_dw.ps1` now queues a GUID-tagged `launcher_probe:<tag>` and waits for
  that exact log line instead of using `speech_status`
- `debug_hooks.txt` documents the new launcher probe command

Evidence gathered this session:
- `speech_bridge.log` showed the bridge launched and startup speech fired on
  2026-04-23, so the unresolved issue is more likely command polling / launcher
  readiness than basic `--loadlua` failure
- stale launch-diagnostic leftovers from ad-hoc experiments should not be
  treated as a clean repro baseline

Immediate next step for launcher work:
```
./launch_dw.sh
```
If it still fails, the error will now name the exact `LAUNCHER_PROBE: <tag>`
marker it was waiting for.

### Changes made this session (2026-04-22)

**Map 0x04 east-wing connectivity — y=4 corridor fully modeled** (`map_reader.lua`):

Survey run 2 from `(10,8)` completed `29/29` targets with only 7 successes and 15
east-wing `state_issues`. All 15 failed from `final=(5,1)` with `suspected_tiles=6,2|6,1`.

Root cause: `(8,4)` was missing from `MAP_PASSTHROUGH_CELLS`, so A* couldn't bridge
from `(7,4)` east to the open corridor at `(9,4)+`. Combined with an unmodeled
`(7,3) south=true` block that made A* plan a false route through `(7,4)→N→(7,3)`.

Probe campaign (`probe_east_wing.sh`, 18 probes) confirmed:
- `(7,4)→UP→(7,3)` BLOCK — (7,3) south=true real
- `(7,4)→RIGHT→(8,4)` PASS moved_through_modeled_block — (8,4) is decoder gap
- `(5,1)→RIGHT→(6,1)`, `(5,2)→RIGHT→(6,2)` BLOCK — x=6 north corridor walls real

Three changes applied to `map_reader.lua`:
- `MAP_PASSTHROUGH_CELLS[0x04]["8,4"] = true` — bridges y=4 corridor to east wing
- `MAP_DIRECTIONAL_BLOCKS[0x04]["7,3"] = {south=true}` — blocks northward entry from (7,4)
- `MAP_DIRECTIONAL_BLOCKS[0x04]["6,1"] = {west=true}` — x=6 north corridor walls
- `MAP_DIRECTIONAL_BLOCKS[0x04]["6,2"] = {west=true}`
- `MAP_DIRECTIONAL_BLOCKS[0x04]["6,3"] = {west=true}` (inferred; not directly probed)

Post-fix pathfind verification (all from `(10,8)`) confirmed paths found to:
- Guard 1 (13,2), Guard 2 adj (23,10), Guard 9 adj (16,20), Stairs Down adj (24,2), (20,4) direct

The y=4 corridor is now fully modeled:
```
(4,4)→(5,4)→(6,4)→(7,4)→(8,4)[new]→(9,4)→...→(13,4)→(14,4)→east wing
```

### Uncommitted changes in working tree

All changes from this session AND prior sessions remain uncommitted:
```
map_reader.lua      — (8,4) passthrough, (7,3) south=true, (6,1-3) west=true, comment fixes
probe_east_wing.sh  — new: 18-probe east-wing connectivity campaign
auto_step.lua       — restore 18-frame re-press timing; neutral gap; manual input cancels routes
route_manager.lua   — stop forwarding autonomous route suppression to auto_step
map_survey.lua      — stop requesting autonomous route suppression; survey-logic improvements
test_auto_step.lua  — neutral-gap + manual-override coverage
debug_tools.lua     — multi-frame simulate_input holds
debug_hooks.txt     — document multi-frame syntax
dw_commands.ps1     — PowerShell command sender
codex.ps1           — LuaJIT + luarocks PATH setup for Codex
AGENTS.md           — prefer dw_commands.ps1 in PowerShell
.codex/             — hooks and skill updates for Codex/PowerShell
```

### Open issues

1. **Immediate next step**: Re-run the survey from `(10,8)`:
   ```
   ./dw_commands.sh survey_objects:park_npcs
   ```
   Expected: ~22–24 successes (up from 7), 6 gated_or_isolated (west magic-key targets).

2. **Guard 1 (13,2) not execution-tested**: A* plans a path via y=4 corridor + x=8
   north column, but auto_step hasn't walked it. Route: `(8,4)→2N→(8,2)→5E→(13,2)`.

3. **`(9,1)` decoder gap unmodeled**: `(8,1)→RIGHT→(9,1)` moves through modeled block.
   Not urgent — y=4 corridor is primary, y=1 route not used by A*.

4. **`(6,3)` not directly probed**: teleport to (5,3) missed during probe campaign;
   added as inferred west=true from consistent x=6 barrier pattern.

5. **West-wing targets still gated** (magic-key door) — unchanged, expected.

6. **Open issues from prior handoff still apply** (survey-logic, (3,16)/(4,15) noisy
   seams, (6,11) west-wing seam, Guard 4 internal west-pocket failures).

## Best Resume Points

**First action next session:**
1. Reload Lua script in FCEUX (Script > Reload)
2. Teleport to a good open start: `./dw_commands.sh teleport_to:10,8`
3. Run the survey: `./dw_commands.sh survey_objects:park_npcs`
4. Read `HANDOFF_2026-04-22_east_wing_y4_fix.md` for full detail on what was done

**PowerShell users** (Codex): use `./dw_commands.ps1` instead of `./dw_commands.sh`.
Quote comma-bearing arguments: `./dw_commands.ps1 "teleport_to:10,8"`.

**Do not:**
- Survey from staircase tile (7,7) — still triggers low-exit-count abort
- Remove (12,16) east=true block
- Remove (20,16) south=true or (21,17) west=true — both real engine blocks
- Treat (3,16)/(4,15) as stable — they are noisy seam cells, monitor only
