# Dragon Warrior Accessibility Mod — Codex Agent Guide

## Project overview

This repository contains a Lua-based accessibility mod for the NES game Dragon Warrior. BizHawk is the default emulator path; FCEUX remains a supported fallback while compatibility work settles.

Primary project goals:
- Add reliable screen reader narration for gameplay systems
- Add navigation and object assistance for blind players
- Build robust debugging and automated testing tools
- Decode map behavior accurately, including hidden engine-blocked tiles
- Improve pathfinding until it is reliable enough for broad autonomous testing

## Current priorities

When working in this repository, prioritize these areas in order:

1. Gameplay accessibility and screen reader usability
2. Pathfinding correctness during real play
3. Test harness reliability
4. Logging quality and debug visibility
5. Map decoding and passability accuracy when gameplay exposes a problem
6. Discovery and handling of engine-blocked but visually passable tiles

Avoid broad unrelated refactors unless explicitly requested.

## Working style

Preferred style:
- Make minimally invasive changes
- Reuse existing helpers and command infrastructure
- Preserve current behavior unless the task explicitly changes it
- Inspect the relevant code paths before editing
- Keep implementations readable and easy to debug
- Favor deterministic behavior over cleverness
- Keep runtime/testing data separate from permanent map data unless explicitly asked to merge them

Do not:
- Redesign major systems without a strong reason
- Refactor unrelated modules while implementing focused changes
- Change command semantics casually
- Remove debug logging unless replacing it with something better

## Environment and command model

The project uses a command queue file and emulator polling loop.

Important behavior:
- Current default emulator path is `D:\emulation\bizhawk\EmuHawk.exe`
- FCEUX fallback path is `D:\emulation\fceux\bin\qfceux.exe` 2.6.6
- FCEUX command-line Lua loading on this build works with `--loadlua=PATH`
- `D:\emulation\fceux\bin\fceux.cfg` should keep `SDL.AutoResume = 1` so startup launches advance frames and poll commands
- Preferred WSL startup path is `./launch_dw.sh`; it defaults to BizHawk, loads the ROM plus `main.lua`, and supports `--emulator fceux` for the older FCEUX workflow
- `./launch_fceux.sh` and `launch_fceux.ps1` are convenience aliases for the explicit FCEUX fallback
- Commands are sent through `./dw_commands.ps1` from PowerShell/Codex, or `./dw_commands.sh` from bash
- Commands are written to `dw_commands.txt`
- The mod polls the command file roughly once per second
- Commands append by default
- Use `--replace` for state-sensitive command batches so stale queued work does
  not contaminate the next observation
- Append mode is fine for independent read-only queries, but avoid it for
  movement, teleport, survey, reload, or path-debug work
- Debug/test output is written to `dw_debug.log`

This means:
- Do not blast large command batches unless the task explicitly benefits from queueing
- Prefer short command batches followed by log verification
- For state-sensitive workflows, wait for log confirmation before sending the next command
- Use `--wait PATTERN` or `--wait-ready TAG` when the next step depends on emulator state
- Use `--require-live SECONDS` before live checks when stale logs would make the result misleading
- Treat queue timing and stale commands as possible causes of test failure
- A fresh `dw_debug.log` header alone does not prove the emulator is unpaused and polling commands; verify that queued commands are actually consumed

Reload/restart rules:
- Use `reload_config` only for `dw_access.ini` changes
- For Lua source changes, BizHawk file-change reload can be triggered by
  touching `main.lua` while the Lua loop is alive; follow it with
  `launcher_probe:TAG`, `--wait-ready TAG`, or another fresh probe
- If the log is stale, the script crashed, or commands are not consumed,
  relaunch with `./launch_dw.sh` instead of queueing more commands
- Do not patch BizHawk `config.ini` while EmuHawk is running

## Core testing principle

For testing and debugging tasks, operate as a disciplined QA/debugging agent.

Preferred loop:
1. Read relevant recent log output
2. Send the next smallest useful command or command batch
3. Observe resulting log changes
4. Compare expected vs actual behavior
5. Record findings clearly
6. Repeat

Prefer automated test/debug hooks over manual exploration whenever possible.

## Important commands

### State / debug
- `log_state`
- `report_position`
- `toggle_debug`
- `reload_config`
- `speech_status`

### Map / blocker discovery
- `sweep_map`
- `stop_sweep`
- `report_blockers`
- `report_runtime_blocks`
- `export_blocks`
- `survey_map`
- `probe_edge`
- `survey_target`

### Runtime blocked tile controls
- `add_blocked_tile:X,Y`
- `add_blocked_tile:MAP_ID,X,Y`
- `list_blocked_tiles`
- `list_blocked_tiles:MAP_ID`
- `clear_blocked_tiles`
- `clear_blocked_tiles:MAP_ID`
- `clear_blocked_tiles:all`
- `is_blocked_tile:X,Y`
- `is_blocked_tile:MAP_ID,X,Y`
- `dump_blocked_tiles`
- `dump_blocked_tiles:MAP_ID`

### Tile / movement inspection
- `inspect_tile:X,Y`
- `inspect_move:DIR`
- `inspect_move:X,Y,DIR`

### Pathfinding and movement
- `pathfind`
- `pathfind_to:X,Y`
- `pathfind_adjacent:X,Y`
- `auto_walk`
- `report_path_state`

### Path debug
- `debug_pathfind_to:X,Y`
- `debug_pathfind_adjacent:X,Y`
- `trace_path`
- `dump_search_log`
- `validate_path`
- `test_path`
- `test_path:NAME`
- `list_tests`
- `dump_path_grid`

### Object navigation
- `next_object`
- `prev_object`
- `current_object`
- `next_filter`
- `route_guidance`
- `pathability_filter`
- `freeze_npcs`
- `unfreeze_npcs`

## Rules for pathfinding work

When debugging pathfinding:
- Distinguish between planner errors, movement execution errors, state/timing issues, and actual engine-blocked tiles
- Do not assume every failed route means a newly blocked tile
- Use repeated evidence when possible
- Keep suspected/runtime-injected blocked tiles separate from permanent blocked map data
- Scope blocked-tile data by map
- If a route fails after path planning succeeded, inspect the failure point before changing permanent data
- Prefer runtime blocked-tile injection during iterative testing
- Only recommend permanent map-data patching after evidence is reasonably strong

## Rules for map-decoding work

When working on unstarted or partially decoded maps:
- Before starting a new map or major new floor, look up external map or
  walkthrough guidance for intended layout, route shape, relevant objects, and
  special conditions such as required light/items. Prefer an actual visual or
  decoded map image when available, then translate its useful route/object
  clues into text notes in the handoff. Treat guide data as orientation, not
  proof; still verify movement live before changing permanent `map_reader.lua`
  data.
- Prefer tooling and automation that scale across many maps
- Improve survey, sweep, export, reporting, and retry workflows when possible
- Favor structured logging that an AI agent can analyze repeatedly
- Preserve resumability and repeatability

## Rules for logging and debugging

Logging is a first-class system in this repository.

When changing code:
- Preserve or improve structured log output
- Log command entry, important state changes, pathfinding decisions, and detected anomalies
- Make failure reasons explicit where possible
- Keep debug output useful for both humans and AI agents
- Avoid noisy logs unless behind a debug-specific command or mode

## Rules for speech-related work

Speech is important, but current top priority is still pathfinding, map decoding, and testing reliability.

For speech fixes:
- Prefer targeted fixes
- Preserve accessibility behavior
- Add logging around backend readiness and error states where helpful
- Avoid destabilizing unrelated systems

## How to approach implementation tasks

Unless explicitly told otherwise:
1. Inspect relevant files first
2. Identify the narrowest safe integration point
3. Make the smallest effective change
4. Re-run or recommend the most relevant checks
5. Summarize:
   - what changed
   - why
   - any caveats
   - exact commands/tests to use next

## How to approach testing tasks

Unless explicitly told otherwise:
1. Start with baseline state verification
2. Use the most specific existing debug/test hook first
3. Validate results through logs and state reports
4. Reproduce suspicious failures before concluding
5. Keep a structured bug list when the task is exploratory

Bug format:
- ID
- Severity
- Description
- Reproduction steps
- Observed behavior
- Expected behavior
- Evidence

## Safety rails for edits

Before making code changes:
- Check whether a runtime/test-only solution is better than a permanent data change
- Preserve backward compatibility for current commands if possible
- Avoid speculative cleanup
- Do not remove useful comments or command documentation without replacing them

## Project memory contract

Repo files are the source of truth:
- Treat `session_handoff.md` as the concise current-state entry point
- Treat `PROJECT_MEMORY.md` as the durable architecture and lessons file
- Treat `PLAYTESTING.md` as the active gameplay/playability notes file
- Treat `handoff_archive/` as historical evidence, not active context
- Treat `~/.codex/memories/` and `.claude/agent-memory/` as assistant-local aids, not the source of truth for project state
- Treat project-local `.agents/skills/` as the documented repo-skill location
  when it is writable; older `.codex/skills/` content is legacy compatibility
  only

After substantial work:
- Update `session_handoff.md` with current state and best next step
- Update `PROJECT_MEMORY.md` only for durable facts
- Update `PLAYTESTING.md` for player-facing findings and gameplay priorities
- Avoid creating new dated handoff files unless a large investigation needs a detailed evidence packet

Codex memory access notes:
- The project-local `.codex/` directory may be mounted read-only inside Codex even when the surrounding repo is writable
- Put durable project memory in repo files, especially `session_handoff.md`, `PROJECT_MEMORY.md`, `AGENTS.md`, and focused docs such as `debug_hooks.txt`
- Put assistant-local reminders in `~/.codex/memories/`, but keep them subordinate to repo memory files
- Allowed assistant-memory content: stable workflow lessons, project
  preferences, and repeated pitfalls that are already reflected in repo docs
- Do not rely on assistant memory for secrets, temporary bug state, one-off live
  map findings, or rules that must always apply before the agent inspects the
  repo

## Preferred output style from Codex

When responding after code work:
- Be concise
- List files changed
- Explain the design briefly
- Call out any commands the user should run to verify behavior
- Note any unresolved uncertainty clearly
