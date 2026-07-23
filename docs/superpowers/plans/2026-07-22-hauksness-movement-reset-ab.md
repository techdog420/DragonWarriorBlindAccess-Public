# Hauksness Movement-Reset A/B Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Test whether a waypoint-scoped movement reset at Hauksness doorstep `(24,89)` makes the following one-step RIGHT town entry reliable without re-enabling movement resets globally.

**Architecture:** Reuse the existing `route_reset_movement_on_turn_settle` waypoint option. Attach it only to the segment ending at `Hauksness doorstep west`, verify the metadata through the existing route regression, and compare the treatment run against the recorded reset-disabled control before either retaining or removing the override.

**Tech Stack:** LuaJIT-compatible Lua, local Lua test harness, FCEUX 2.6.6, PowerShell command queue, and `dw_debug.log`.

## Global Constraints

- Keep `auto_step_reset_movement_on_route_turn_settle=false` in `dw_access.ini`.
- Apply `route_reset_movement_on_turn_settle=true` only to `Hauksness doorstep west` at `(24,89)`.
- Do not change `auto_step.lua`, `route_manager.lua`, configuration defaults, map passability, or runtime blockers for this experiment.
- Treat `(15,90)->UP` as outside this A/B because it failed during a same-direction segment.
- Use the existing reset-disabled `(24,89)->RIGHT` timeout and same-origin successful probe as the control observation.
- Pause for the user whenever combat begins.
- Stop on a player-stat integrity transition, control hard lock, unexpected map change, or persistent new movement anomaly.
- Do not stage or commit unrelated dirty-tree changes. Because both target files already contain Hauksness work, commit only after a live success and only after reviewing the staged diff hunk by hunk.
- FCEUX requires the user to reload `main.lua` after the source change.

---

### Task 1: Add the scoped waypoint override with a regression

**Files:**
- Modify: `test_overworld_routes.lua:1344-1364`
- Modify: `overworld_routes.lua:641-643`

**Interfaces:**
- Consumes: `routes.plan_next_segment(map_id, x, y) -> segment`, where `segment.waypoint` exposes the selected waypoint table.
- Produces: `segment.waypoint.route_reset_movement_on_turn_settle == true` only for the segment ending at `(24,89)`.
- Preserves: adjacent Hauksness waypoints return `nil` for the override and therefore continue using the global `false` setting.

- [ ] **Step 1: Add the failing metadata assertions.**

In `tests.hauksness_final_entry_steps_east_from_west_doorstep()`, add this
assertion after the existing `west_approach.path_length` assertion:

```lua
    assert_equal(west_approach.waypoint.route_reset_movement_on_turn_settle, nil,
        "west approach should retain the global movement-reset setting")
```

Add this assertion after the existing `doorstep.steps[1]` assertion:

```lua
    assert_equal(doorstep.waypoint.route_reset_movement_on_turn_settle, true,
        "doorstep final settle should reset movement before the town-entry segment")
```

Add this assertion after the existing `entry.steps[1]` assertion:

```lua
    assert_equal(entry.waypoint.route_reset_movement_on_turn_settle, nil,
        "town transition waypoint should not broaden the scoped reset")
```

- [ ] **Step 2: Run the route suite and verify RED.**

Run:

```powershell
luajit test_overworld_routes.lua
```

Expected: one failure in
`hauksness_final_entry_steps_east_from_west_doorstep` because the doorstep
waypoint returns `nil` instead of `true`. The current baseline is 92 passing
tests before this assertion is added.

- [ ] **Step 3: Add the minimal waypoint override.**

Replace the one-line `(24,89)` waypoint in `overworld_routes.lua` with:

```lua
            {
                x = 24,
                y = 89,
                name = "Hauksness doorstep west",
                radius = 0,
                route_reset_movement_on_turn_settle = true,
            },
```

Do not add the property to `(15,89)`, `(25,89)`, or any other waypoint.

- [ ] **Step 4: Run focused tests and verify GREEN.**

Run:

```powershell
luajit test_overworld_routes.lua
luajit test_route_manager.lua
luajit test_auto_step.lua
```

Expected:

- `test_overworld_routes.lua`: 92 tests pass.
- `test_route_manager.lua`: 110 tests pass, including waypoint-option forwarding.
- `test_auto_step.lua`: 135 tests pass, including reset override and globally disabled reset coverage.

- [ ] **Step 5: Run syntax, config, and whitespace checks.**

Run:

```powershell
luajit -b overworld_routes.lua NUL
luajit -b test_overworld_routes.lua NUL
Select-String -LiteralPath dw_access.ini -Pattern '^auto_step_reset_movement_on_route_turn_settle=false$'
git diff --check -- overworld_routes.lua test_overworld_routes.lua
```

Expected: both bytecode checks exit zero; `Select-String` prints the unchanged
global `false` setting; `git diff --check` prints nothing.

- [ ] **Step 6: Review the experimental diff without staging it.**

Run:

```powershell
git diff -- overworld_routes.lua test_overworld_routes.lua
```

Expected: the new A/B changes are limited to the `(24,89)` property and three
assertions. Existing Hauksness ridge and south-road edits remain present but
unstaged. Do not commit until the live treatment has a verdict.

---

### Task 2: Run the FCEUX treatment from a clean final-approach state

**Files:**
- Read: `dw_debug.log`
- Read only unless a script failure occurs: `dw_script_error.log`

**Interfaces:**
- Consumes command queue: `launcher_probe`, `report_position`, `route_status`, `report_path_state`, `report_runtime_blocks`, `log_state`, `start_overworld_route:hauksness`, `route_recalculate`, and `auto_walk`.
- Consumes log evidence: `AUTO_STEP_MOVEMENT_STATE_RESET`, `OVERWORLD_AUTO_WALK`, `OVERWORLD_ROUTE`, `POSITION`, and `PLAYER_STAT_*` markers.
- Produces: a clean pass, clean failure, or explicitly inconclusive verdict for the `(24,89)` settle followed by `(24,89)->RIGHT`.

- [ ] **Step 1: Ask the user to reload `main.lua` in FCEUX.**

Wait for explicit confirmation. Do not use `reload_config`; the global INI
setting did not change.

- [ ] **Step 2: Confirm the reloaded script and current state.**

Run:

```powershell
./dw_commands.ps1 --replace --timeout 15 --wait-ready hauksness_reset_ab report_position route_status report_path_state report_runtime_blocks log_state
```

Expected: `LAUNCHER_PROBE: hauksness_reset_ab` appears freshly, commands are
consumed, and the state snapshot contains no player-stat integrity warning.
If the probe times out or `dw_script_error.log` changed, stop and repair the
reload before testing movement.

- [ ] **Step 3: Restore a repeatable pre-doorstep world-map state.**

Ask the user to load a clean save state at `(15,93)`, `(15,89)`, or another
normally reached point immediately before the doorstep run. Do not use
`teleport_to` for this timing experiment. After the user confirms, run:

```powershell
./dw_commands.ps1 --replace --timeout 15 --wait-ready hauksness_reset_start report_position report_path_state report_runtime_blocks log_state
```

Expected: map `0x01`, no runtime blocks on the final approach, and clean player
stats. If route guidance is inactive, run:

```powershell
./dw_commands.ps1 --replace start_overworld_route:hauksness route_recalculate route_status
```

- [ ] **Step 4: Reach `(15,89)` by normal route execution if necessary.**

From `(15,93)`, run:

```powershell
./dw_commands.ps1 --replace --timeout 30 --wait "OVERWORLD_AUTO_WALK: event=complete" auto_walk
```

Then run:

```powershell
./dw_commands.ps1 --replace --wait "POSITION:" report_position report_path_state
```

Expected: world map `(15,89)`. If combat starts, let the command wait expire,
pause, and resume only after the user confirms the field is clear and a fresh
`report_position` again shows the expected route state.

- [ ] **Step 5: Run the treatment segment ending at `(24,89)`.**

Run:

```powershell
./dw_commands.ps1 --replace --timeout 45 --wait "OVERWORLD_AUTO_WALK: event=complete route=hauksness waypoint=Hauksness doorstep west" auto_walk
```

Then run:

```powershell
./dw_commands.ps1 --replace --wait "POSITION:" report_position report_path_state report_runtime_blocks log_state
```

Expected evidence:

- Position is world map `(24,89)`.
- The segment completes without a runtime blocker.
- A fresh line records
  `AUTO_STEP_MOVEMENT_STATE_RESET reason=queued_route_final_complete map=0x01 player=(24,89)`.
- No fresh `PLAYER_STAT_FRAMEADVANCE_TRANSITION`,
  `PLAYER_STAT_INTEGRITY_TRANSITION`, or `PLAYER_STAT_INTEGRITY_WARNING`
  indicates a clean-to-bad change.

If the expected reset line is absent, stop: the source reload or option
forwarding is not proven, so the entry step would not be a valid treatment.

- [ ] **Step 6: Test the one-step Hauksness entry.**

Run:

```powershell
./dw_commands.ps1 --replace --timeout 45 --wait "Arrived at Hauksness" auto_walk
```

If combat interrupts, pause for the user, then fresh-probe before deciding the
result. After arrival or a clean timeout, run:

```powershell
./dw_commands.ps1 --replace --wait "POSITION:" report_position report_path_state report_runtime_blocks log_state
```

Pass: the route changes from map `0x01` at `(24,89)` to Hauksness map `0x03`
without `probe_edge`, manual movement, a route timeout, or stat-integrity
markers.

Fail: normal auto-walk remains at `(24,89)` or reports a timing failure while a
fresh same-origin `probe_edge:RIGHT` would still be required. Do not run the
probe merely to improve the treatment outcome; the prior control already
proved the edge passable.

Inconclusive: combat, stale input, failed reload, wrong start state, unexpected
map state, or command-polling failure prevents a clean comparison.

---

### Task 3: Apply the treatment verdict and record the evidence

**Files:**
- Modify: `work_notes/current_investigation.md`
- Retain or restore: `overworld_routes.lua:641-649`
- Retain or restore: `test_overworld_routes.lua:1344-1370`
- Modify only if active resume guidance materially changes: `session_handoff.md`

**Interfaces:**
- Consumes: the Task 2 pass, fail, or inconclusive verdict.
- Produces: source state consistent with that verdict and a concise evidence record.

- [ ] **Step 1: Record the live result in the scratchpad.**

For a pass, append this result under a dated heading in
`work_notes/current_investigation.md`:

```markdown
## 2026-07-22 Hauksness Doorstep Movement-Reset A/B

- TREATMENT PASS: the waypoint-scoped reset fired at world-map `(24,89)`, and
  the following one-step RIGHT segment entered Hauksness map `0x03` through
  normal auto-walk. No runtime blocker, manual movement, probe rescue, or
  player-stat integrity transition occurred. Keep the override local to
  `Hauksness doorstep west`; this does not justify the global reset setting or
  address the separate `(15,90)->UP` timeout.
```

For a clean failure, append instead:

```markdown
## 2026-07-22 Hauksness Doorstep Movement-Reset A/B

- TREATMENT FAIL: the waypoint-scoped reset fired at world-map `(24,89)`, but
  the following one-step RIGHT segment still failed to enter Hauksness through
  normal auto-walk. Remove the local override and investigate entry-step
  timing independently. Do not promote a map blocker; prior same-origin proof
  established that the edge is passable.
```

For an inconclusive run, append instead:

```markdown
## 2026-07-22 Hauksness Doorstep Movement-Reset A/B

- INCONCLUSIVE: the scoped treatment could not be judged from a clean
  pre-doorstep state because live execution was contaminated by combat,
  input, reload, map-state, or command-polling conditions. Keep the experiment
  uncommitted and repeat without changing another variable.
```

- [ ] **Step 2: Retain or remove the experiment according to the verdict.**

On pass, retain the `(24,89)` property and all three assertions from Task 1.

On fail, restore the `(24,89)` waypoint to:

```lua
            {x = 24, y = 89, name = "Hauksness doorstep west", radius = 0},
```

and remove only the three Task 1 assertions. Run
`luajit test_overworld_routes.lua`; expected result is 92 passing tests.

On inconclusive, leave the experiment uncommitted and do not alter adjacent
waypoints or timing controls.

- [ ] **Step 3: Run final verification for a retained treatment.**

For a pass, run:

```powershell
luajit test_overworld_routes.lua
luajit test_route_manager.lua
luajit test_auto_step.lua
luajit -b overworld_routes.lua NUL
luajit -b test_overworld_routes.lua NUL
Select-String -LiteralPath dw_access.ini -Pattern '^auto_step_reset_movement_on_route_turn_settle=false$'
git diff --check
```

Expected: 92, 110, and 135 tests pass; syntax checks exit zero; the global
setting remains false; and no whitespace error is reported.

- [ ] **Step 4: Stage only the successful A/B changes if they can be isolated safely.**

Run:

```powershell
git add -p overworld_routes.lua test_overworld_routes.lua work_notes/current_investigation.md
git diff --cached --check
git diff --cached --name-status
git diff --cached
```

Stage only the `(24,89)` property, its three assertions, and the treatment-pass
scratchpad entry. If the interactive hunks cannot be separated from pre-existing
dirty work, stop without committing and leave them for the broader Hauksness
route checkpoint.

- [ ] **Step 5: Commit only after the staged diff is clean and scoped.**

If Step 4 isolated exactly the successful experiment, run:

```powershell
git commit -m "fix: reset movement before Hauksness entry"
```

Expected: the commit contains only the local waypoint override, regression
assertions, and live evidence. Do not commit on a failed or inconclusive run.
