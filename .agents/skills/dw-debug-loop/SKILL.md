---
name: "dw-debug-loop"
description: "Use for live Dragon Warrior accessibility-mod debugging/testing through BizHawk or FCEUX, dw_commands.sh/ps1, dw_debug.log, remote Lua reload, pathfinding, auto_walk, map survey, probe_edge, teleport_to, runtime blocked tiles, or any state-sensitive emulator QA. Do not use for ordinary static code edits unless emulator logs or command timing matter."
---

# Dragon Warrior Debug Loop

Use this skill when live emulator state, command timing, logs, or pathfinding evidence matter.
Do not use it for pure static code edits unless the task asks for live Dragon Warrior emulator validation.

## Context Order

1. Read `AGENTS.md` first.
2. Read the current sections of `session_handoff.md`, especially Current Focus, Current Baseline, Recommended Next Work, and validation/watch items.
3. Read `PROJECT_MEMORY.md` only when durable architecture, map, or command-contract context matters.
4. Read `PLAYTESTING.md` for player-facing gameplay findings.
5. Use `debug_hooks.txt` or `dw_commands.sh` for exact command names and argument shapes.
6. Read recent `dw_debug.log` lines before sending new live commands.
7. Check `dw_script_error.log` when the emulator script may have crashed.

Avoid archived handoffs unless investigating old map-data decisions.

## Runtime Baseline

- BizHawk is the primary emulator path.
- FCEUX is an explicit fallback.
- Use `./launch_dw.sh` for normal launch.
- Use `./launch_dw.sh --emulator fceux` only when testing fallback behavior.
- Quick-slot loops may use `./launch_dw.sh --state-slot N --no-wait`.

## Preferred Live Loop

1. Read recent log state.
2. Send the smallest useful command or command batch.
3. Wait for fresh log confirmation.
4. Compare expected versus actual behavior.
5. Record the finding.
6. Repeat.

Prefer short, evidence-driven loops over large queued command batches.

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
- For Lua source changes, BizHawk file-change reload can pick up `touch main.lua` while the Lua loop is alive.
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

## Handoff Discipline

- Put current shared truth in `session_handoff.md`.
- Put durable project facts in `PROJECT_MEMORY.md`.
- Put gameplay findings in `PLAYTESTING.md`.
- Treat `handoff_archive/` as historical evidence.
- Do not rely on assistant-private memory as the only record of live findings.
