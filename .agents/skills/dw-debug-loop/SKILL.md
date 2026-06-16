---
name: "dw-debug-loop"
description: "Use for live Dragon Warrior accessibility-mod debugging/testing through BizHawk or FCEUX, dw_commands.sh/ps1, dw_debug.log, remote Lua reload, pathfinding, auto_walk, map survey, probe_edge, teleport_to, runtime blocked tiles, or any state-sensitive emulator QA. Do not use for ordinary static code edits unless emulator logs or command timing matter."
---

# Dragon Warrior Debug Loop

Use this skill when live emulator state, command timing, logs, or pathfinding evidence matter.
Do not use it for pure static code edits unless the task asks for live Dragon Warrior emulator validation.

## Context Order

1. Read `AGENTS.md` first.
2. Read only the top active-resume sections of `session_handoff.md`: usually Latest Code Review, Current Emulator Note, and Active Resume. If headings changed, skim only until the active state, watch items, and best next work are clear.
3. Do not read the entire handoff or archived evidence unless the current task specifically depends on old map decisions.
4. Read `PLAYTESTING.md` for player-facing gameplay findings.
5. Use `debug_hooks.txt` or `dw_commands.sh` for exact command names and argument shapes.
6. Read recent `dw_debug.log` lines before sending new live commands.
7. Check `dw_script_error.log` when the emulator script may have crashed.

Avoid archived handoffs unless investigating old map-data decisions.

## Runtime Baseline

- FCEUX is the primary gameplay and agent-driven emulator path.
- BizHawk is the explicit automation/debug path, especially for script reloads
  and profiling. Do not switch normal route/seam work to BizHawk just for
  agent convenience; the lag slows evidence gathering.
- Use `./launch_dw.sh` for normal launch.
- Use `./launch_dw.sh --emulator bizhawk` or `./launch_bizhawk.sh` when
  testing automation/debug behavior.
- Quick-slot loops may use `./launch_dw.sh --state-slot N --no-wait`.

## Preferred Live Loop

1. Read recent log state.
2. Send the smallest useful command or command batch.
3. Wait for fresh log confirmation.
4. Compare expected versus actual behavior.
5. Record the finding.
6. Repeat.

Prefer short, evidence-driven loops over large queued command batches.

## Target Blocker Harvest Loop

Use this pattern when the user asks to make a specific target reachable, when
autowalk loops near a target, or when a planner route exists but live movement
keeps discovering hidden blockers.

Inputs:
- Current map/position, confirmed with `report_position`.
- Target coordinate or current selected object.
- Any state assumptions such as doors open, NPCs parked, or manual reload done.

Loop:
1. Confirm baseline with `report_position`, `report_door_state` if doors matter,
   and `report_runtime_blocks`.
2. Try the route:
   - Coordinate target: `auto_walk:X,Y`.
   - Selected object: `pathfind` or `auto_walk`.
   - If NPC occupancy may hide the route, compare `debug_pathfind_to:X,Y` with
     `debug_pathfind_to_skip_npcs:X,Y`.
3. Let autowalk run long enough to accumulate seam evidence, then stop with
   `stop_auto_walk report_position report_runtime_blocks`.
4. Read recent `dw_debug.log` and extract candidates from repeated
   `SEAM_OBSERVATION ... classification=blocked_only`,
   `SEAM_BRUTE_FORCE`, and `PATH_RUNTIME_BLOCK`.
5. Verify candidates from normal play state whenever possible:
   - Prefer live route evidence plus same-origin `probe_edge:DIR` while already
     standing on the suspect edge origin through normal walking.
   - Do not use `teleport_to`, explicit-origin `probe_edge:X,Y,DIR`, or
     explicit-origin `probe_edge_verify:X,Y,DIR,N` as direct passability proof
     for stateful dungeon seams. Teleport can change movement/passability state
     and may create false passable or false blocked results.
   - Use teleport only for coarse repositioning, then reacquire evidence by
     walking to the edge origin through the route being tested.
6. Promote only clean live-state results:
   - repeated route evidence plus same-origin probe agreement,
   - no drift, map change, interrupt, teleport seed, or NPC/state contamination.
   - Treat `probe_edge_verify` results as forensic/review-only if the verifier
     teleported or reset between attempts. Do not promote
     `inconclusive_teleport_artifact` results. In Garin's Grave B2 especially,
     repeated explicit-origin verifier attempts can show `first_attempt_status`
     mismatches followed by `blocked_despite_open_preview` raw-hold timeouts.
     Treat those as verifier-method artifacts, not map truth.
7. Immediately inject confirmed blockers with `add_blocked_edge:X,Y,DIR`, then
   re-run planner/autowalk from the same side.
8. Record confirmed, mixed, and contaminated findings in
   `work_notes/current_investigation.md`.

When the route collapses:
- Run both normal and skip-NPC path debug from each side.
- Bracket the reachable component by querying intermediate targets along the
  last known route.
- Look for one-way seams: if reverse succeeds but forward fails, inspect the
  reverse path and test the corresponding forward entries.
- Treat hidden passthrough candidates separately: live movement into a decoded
  wall can justify a passthrough only when repeated movement and onward route
  evidence are clean enough. Leave mixed hidden-cell evidence as suspicious,
  not promoted.

Stop when:
- the target is reached,
- planner and skip-NPC planner both collapse with no clear next bridge,
- emulator/script state is stale or contaminated,
- the user asks to stop,
- about an hour has elapsed,
- or a good batch of verified blockers has been collected and should be
  patched/tested before continuing.

## Investigation versus Wrap-up

When this skill is invoked for exploratory route/pathfinding work, stay in investigation mode until a stop condition is reached.

Do not switch to wrap-up mode merely because:
- one or two blocked tiles were found,
- a small patch was applied,
- local tests passed,
- or a handoff file exists.

Prefer another focused live check over documentation when the next check is obvious and safe.

## Command Rules

Use bash:

```bash
./dw_commands.sh --replace --wait "POSITION:" report_position
```

Use PowerShell when working from that side:

```powershell
./dw_commands.ps1 --replace --wait "POSITION:" report_position
```

Rules:

- Use `--replace` for state-sensitive commands.
- Use append mode only for independent read-only commands.
- Use `--require-live SECONDS` before live checks when stale logs would mislead the result.
- Use `--wait-ready TAG` to queue `launcher_probe:TAG` and wait for the fresh marker.
- Do not write directly to `dw_commands.txt` unless intentionally debugging the harness.
- Do not batch `teleport_to` with `probe_edge`, `survey_target`, `report_survey_start`, `debug_pathfind_*`, or path follow-up commands when exact start state matters.
- After teleporting, wait for `report_position` before probing or surveying.
- Treat stale queued commands and one-second polling delays as real failure causes.

Preferred split pattern:

```bash
./dw_commands.sh --replace freeze_npcs teleport_to:X,Y report_position
./dw_commands.sh --replace --wait "POSITION:" report_position
./dw_commands.sh --replace --wait "PROBE_EDGE" probe_edge:DIR
```

## Script Reload / Restart

- For `dw_access.ini` changes only, use `reload_config`.
- For Lua source changes, BizHawk file-change reload can pick up `touch main.lua` while the Lua loop is alive.  FCEUX currently requires a manual script reload from the user.
- After source reload, verify the running script with `launcher_probe:TAG`, `--wait-ready TAG`, or another fresh state probe before judging behavior.
- If the probe times out, `dw_debug.log` is stale, or `dw_script_error.log` changed, assume the Lua loop is not polling and relaunch with `./launch_dw.sh`.

Suggested verification pattern:

```bash
touch main.lua
./dw_commands.sh --replace --timeout 15 --wait "LAUNCHER_PROBE: codex_reload" launcher_probe:codex_reload
```

## Interpretation Rules

- Distinguish planner failure, route executor failure, queue timing, live NPC clutter, and actual engine-blocked tiles.
- Do not treat one failed route as proof that permanent map data is wrong.
- Prefer runtime blocked-tile injection and repeated evidence before editing `map_reader.lua`.
- When planning succeeds but movement fails, inspect the failure point before promoting any blocker.
- Live NPC movement blocks should not become permanent map blockers.
- Preserve or improve structured debug logging when changing code.

## Performance Rules

- Avoid routine use of heavy debug commands during player-facing tests.
- Use `report_scan_stats`, `CMD_TIMING`, and `ROUTE_PLAN_TIMING` evidence before blaming emulator lag.
- If route or object navigation lags, compare object refresh, route planning, and auto-step timings separately.

## Validation

For source changes, run the smallest relevant checks first:

```bash
luac -p <changed-files-and-tests>
lua test_<area>.lua
git diff --check
```

For broader validation:

```bash
python3 run_tests.py --allow-missing-speech-dep
```

Known local noise:

- WSL may warn about missing `accessible_output2`.
- Speech bridge may print `cmd: not found`.
- `dw_access.ini` may have known CRLF warnings.

For live behavior changes, validate with reload/relaunch, fresh log/probe confirmation, one focused live repro, and a concise handoff update.

## Investigation Scratchpad

During live pathfinding, map decoding, route debugging, blocker discovery, or other exploratory QA, use a scratchpad before updating durable handoff files.

Preferred scratchpad path:

`work_notes/current_investigation.md`

Use the scratchpad for:
- raw command sequences,
- suspected blocked edges,
- uncertain or contaminated findings,
- temporary route hypotheses,
- log tags worth checking later,
- NPC/stale-input/timing contamination notes,
- evidence that has not yet met the threshold for permanent map data.

Do not put routine exploratory findings directly into `session_handoff.md`.

At the end of the session:
1. Promote only durable, verified facts into permanent code/data or concise project docs.
2. Summarize unresolved scratchpad findings in the final response.
3. Update `session_handoff.md` only if active route status, map status, emulator/tooling assumptions, or recommended next work materially changed.
4. Leave detailed evidence in a focused evidence file only when it would be expensive to reconstruct.

Scratchpad notes are working memory, not project truth. They should not become another large handoff file.

## Scratchpad Cleanup

Before wrapping a long investigation:
- Delete or condense resolved scratchpad items.
- Mark unresolved items as `UNRESOLVED`.
- Mark contaminated findings as `DO NOT PROMOTE`.
- If the scratchpad grows beyond a few screens, summarize it and move detailed historical evidence to a focused file under `handoff_archive/` or `project_resources/evidence/`.

## Scratchpad Template Example

Use a structure like this inside `work_notes/current_investigation.md`.
The entries below are examples only; do not treat them as current project evidence.

```markdown
## Findings

### CLEAN / PROMOTED
- Map 0x0B `(5,15)->DOWN`: blocked 3/3 after reload; promoted to map data.

### RUNTIME ONLY
- `(6,15).west`: suspected from route failure; needs direct verifier.

### CONTAMINATED / DO NOT PROMOTE
- `(29,14).north`: observed during stale Alt / queued-input contamination.

### NEXT CHECK
- Verify route from entrance to Magic Key seller after reload.
```

## Handoff Discipline

- Put current shared truth in `session_handoff.md`.
- Put durable project facts in `PROJECT_MEMORY.md`.
- Put gameplay findings in `PLAYTESTING.md`.
- Treat `handoff_archive/` as historical evidence.
- Do not rely on assistant-private memory as the only record of live findings.
- Keep handoff updates short. For minor live findings, summarize in the final response instead of editing durable docs.  Update `session_handoff.md` only when active resume state or next recommended work changes.
