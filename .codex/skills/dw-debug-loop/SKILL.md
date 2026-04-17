---
name: "dw-debug-loop"
description: "Use when debugging or testing the Dragon Warrior Lua mod through ./dw_commands.sh, dw_commands.txt, and dw_debug.log, especially for pathfinding, map survey, probe_edge, teleport_to, runtime blocked tiles, or other state-sensitive FCEUX workflows."
---

# Dragon Warrior Debug Loop

Use this skill for live debug and QA work in this repository when command timing and log evidence matter.

## Start Here

1. Read `session_handoff.md` first.
2. Open the active dated handoff file(s) named there if the task continues existing investigation.
3. Read `debug_hooks.txt` if you need a command name, argument shape, or expected log output.
4. Read the relevant recent lines from `dw_debug.log` before sending new commands.

## Preferred Loop

1. Read the current state from logs.
2. Send the smallest useful command or command batch with `./dw_commands.sh`.
3. Wait for log confirmation before the next state-sensitive step.
4. Compare expected versus actual behavior.
5. Record findings clearly.
6. Repeat.

Prefer short, evidence-driven loops over large queued command batches.

## Command Rules

- Use `./dw_commands.sh --replace ...` when you need a clean, state-sensitive batch.
- Do not batch `teleport_to` with `probe_edge`, `survey_target`, `report_survey_start`, or path-debug follow-up commands when exact start state matters.
- Preferred split pattern:
  1. `./dw_commands.sh --replace freeze_npcs teleport_to:X,Y report_position`
  2. wait for `dw_debug.log` to confirm the position
  3. send `probe_edge`, `survey_target`, `debug_pathfind_to`, or similar commands separately
- Treat stale queued commands and one-second polling delays as real failure causes.

## Interpretation Rules

- Distinguish planner failure, movement failure, queue timing issues, and actual engine-blocked tiles.
- Do not treat one failed route as proof that permanent map data is wrong.
- Prefer runtime blocked-tile injection and repeated evidence before changing `map_reader.lua`.
- When a plan succeeds but movement fails, inspect the failure point before promoting any permanent blocker.
- Preserve or improve structured debug logging when changing code.

## Useful Files

- `session_handoff.md`
- `debug_hooks.txt`
- `dw_debug.log`
- `dw_commands.sh`
- `AGENTS.md`

## Handoff Discipline

- Put current shared truth in `session_handoff.md`.
- Put detailed evidence in dated `HANDOFF_YYYY-MM-DD_*.md` files.
- Do not rely on assistant-private memory as the only record of live findings.
