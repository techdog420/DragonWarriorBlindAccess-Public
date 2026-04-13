# Pathfinder / Test Hooks Handoff

Date: 2026-03-24

## Purpose

This document is the fastest way to get back into the current `pathfinder`
and `test hooks` workflow without re-reading the whole repo history.

The active work is not generic pathfinding. It is specifically:

- keeping A* routing accurate on interior maps
- validating hidden engine-collision cells that ROM tile data misses
- using remote debug hooks to reproduce those failures in FCEUX
- keeping the test harness stable while runtime blockers and NPC motion change

## Current Focus

The live problem area has been `map 0x04` (`Tantegel Castle main hall`).
Most recent fixes were empirical collision overrides added to
`map_reader.lua` after direct live validation.

The current testing loop depends on:

- `main.lua`: command registration and debug hook entry points
- `path_debug.lua`: search logging, step mode, validation, test scenarios
- `route_manager.lua`: runtime blockers, NPC freeze, shared path blocking
- `auto_step.lua`: injected one-tile walking and blocked-step detection
- `pathfinder.lua`: A* search and direct/adjacent path planning
- `map_reader.lua`: tile walkability plus hardcoded hidden blocked cells
- `dw_commands.sh`: the command queue wrapper used from WSL/shell

## What Is Verified

### Path/test-hook behavior

- `validate_path` now computes expected coordinates from the actual live
  position before each injected step. It no longer drifts after one bad step.
- `validate_path` now aborts on the first real mismatch instead of continuing
  to replay later steps from the wrong position.
- `validate_path` now has a startup delay and a larger post-move settle window
  so multi-step routes do not immediately outrun `auto_step`.
- `validate_path` now allows up to two no-movement retries before declaring a
  mismatch. This reduced turn-latency false positives substantially.
- `stop_validate` cancels the active injected step instead of leaving residue
  in the movement state.
- Validation and step-debug no longer leave behind runtime blockers that
  poison later tests.
- Runtime blockers are pruned if the player is currently standing on that cell.
- `test_path` now snapshots blocking state once per run after clearing runtime
  blockers for the current map, which made repeat runs stable on `map 0x04`.
- Direct-goal pathfinding now refuses exact goals that are blocked or not
  walkable; callers needing interaction targets should use adjacent pathing.

### Hidden collision cells confirmed and patched in `map_reader.lua`

For `MAP_BLOCKED_CELLS[0x04]`:

- `16,16`
- `17,16`
- `18,16`
- `19,16`
- `20,17`
- `21,18`
- `14,19`
- `15,19`
- `20,20`
- `21,19`
- `13,21`
- `16,21`
- `17,21`
- `18,21`
- `19,21`
- `21,21`
- `21,22`
- `21,23`
- `13,22`
- `13,23`
- `13,24`
- `16,24`
- `17,24`
- `18,24`
- `13,25`
- `16,25`
- `12,26`
- `15,26`
- `16,27`
- `14,27`
- `15,28`
- `20,3`
- `22,3`
- `27,2`
- `26,3`
- `19,2`

These were all cases where tile inspection still looked walkable, but
one-step live validation showed the engine refusing the move.

## Important Command Surface

These are the commands that matter for this workflow.

### Core test hooks

- `./dw_commands.sh inspect_tile:X,Y`
- `./dw_commands.sh inspect_move:DIR`
- `./dw_commands.sh inspect_move:X,Y,DIR`
- `./dw_commands.sh pathfind_to:X,Y`
- `./dw_commands.sh pathfind_adjacent:X,Y`
- `./dw_commands.sh report_path_state`
- `./dw_commands.sh report_blockers`
- `./dw_commands.sh report_runtime_blocks`
- `./dw_commands.sh clear_runtime_blocks`
- `./dw_commands.sh clear_runtime_blocks:all`
- `./dw_commands.sh freeze_npcs`
- `./dw_commands.sh unfreeze_npcs`

### Path debug / validation

- `./dw_commands.sh debug_pathfind_to:X,Y`
- `./dw_commands.sh debug_pathfind_adjacent:X,Y`
- `./dw_commands.sh trace_path`
- `./dw_commands.sh dump_search_log`
- `./dw_commands.sh start_step_mode`
- `./dw_commands.sh step_path`
- `./dw_commands.sh stop_step_mode`
- `./dw_commands.sh validate_path`
- `./dw_commands.sh stop_validate`
- `./dw_commands.sh test_path`
- `./dw_commands.sh test_path:NAME`
- `./dw_commands.sh list_tests`
- `./dw_commands.sh dump_path_grid`

### Sweep workflow

- `./dw_commands.sh sweep_map`
- `./dw_commands.sh stop_sweep`
- `./dw_commands.sh export_blocks`

## Recommended Testing Process

Use this order. It is the least noisy process that matched the live fixes.

### 1. Stabilize the map state

Run:

```bash
./dw_commands.sh freeze_npcs
./dw_commands.sh clear_runtime_blocks
```

Why:

- NPC motion creates false blockers.
- old runtime blockers can contaminate pathfinding and validation results.

### 2. Run the deterministic scenario suite

Run:

```bash
./dw_commands.sh list_tests
./dw_commands.sh test_path
```

On `map 0x04`, the expected scenario set is:

- `spawn_to_stairs_up`
- `spawn_to_stairs`
- `center_to_east_guard`
- `north_to_south`
- `east_wing_to_west`

This is a pathfinding-only harness. It does not prove engine movement is
possible for every tile. It proves A* behaves consistently against the current
walkability and blocking model.

### 3. Use direct probes for suspicious cells

When a cell looks suspect, validate it from a stable stopped position:

```bash
./dw_commands.sh inspect_tile:X,Y
./dw_commands.sh inspect_move:DIR
./dw_commands.sh debug_pathfind_to:X,Y
./dw_commands.sh validate_path
```

Interpretation:

- `inspect_tile` tells you whether the model thinks the tile is walkable.
- `inspect_move` tells you whether the immediate move target looks open.
- `debug_pathfind_to` tells you whether A* believes a route exists.
- `validate_path` is the final truth test because it checks real movement.

If `inspect_*` and `debug_pathfind_to` say the tile is open but validation
shows the player staying put, the cell is a candidate for
`MAP_BLOCKED_CELLS[map_id]`.

### 4. Use sweep only to discover candidates

Run:

```bash
./dw_commands.sh freeze_npcs
./dw_commands.sh clear_runtime_blocks
./dw_commands.sh sweep_map
```

Let it run, then:

```bash
./dw_commands.sh stop_sweep
./dw_commands.sh export_blocks
```

Important:

- `sweep_map` is discovery, not proof.
- Do not patch every sweep hit directly into `map_reader.lua`.
- Stop the sweep before direct validation or the teleporting will invalidate
  your position assumptions.

## Promotion Rule For New Hidden Blockers

Only promote a cell into `MAP_BLOCKED_CELLS` when all of this is true:

- the player is in a stable stopped state
- nearby NPCs are frozen or otherwise ruled out
- runtime blockers were cleared first
- `inspect_tile` still shows a walkable-looking destination
- `validate_path` or equivalent one-step live movement proves the move fails

This matters because some sweep-derived cells were promoted too early and
caused `test_path` regressions by breaking legitimate routes.

## Known Unverified Sweep Candidates

These appeared in exports and/or sweep logs but were not directly promoted:

- `20,2`
- `21,2`
- `23,3`
- `24,2`
- `25,2`
- `25,3`
- `9,2`
- `10,2`
- `2,3`

Treat these as leads, not fixes.

## Current Map 0x04 Status

The recent live work focused on the corridor pocket around:

- `(20,23) -> 21,23`
- `(20,22) -> 21,22`
- `(20,21) -> 21,21`

All three currently reproduce as hidden engine blockers:

- `inspect_move` reports the edge open
- `inspect_tile` reports the destination walkable
- direct one-step `validate_path` fails after the full retry budget

The current stopping point is after promoting `["21,21"] = true`.
The emulator was last reloaded and testing was paused intentionally for handoff.

The next session should restart from a stable nearby tile and continue the
same short-loop process:

```bash
./dw_commands.sh freeze_npcs
./dw_commands.sh clear_runtime_blocks
./dw_commands.sh report_position
./dw_commands.sh debug_pathfind_to:17,25
./dw_commands.sh validate_path
```

If the route still goes through the east-side corridor, the next candidate
should be promoted only after:

```bash
./dw_commands.sh inspect_move:X,Y,DIR
./dw_commands.sh inspect_tile:X,Y
./dw_commands.sh debug_pathfind_to:X,Y
./dw_commands.sh validate_path
```

`test_path` had been stable earlier in the session (`5 passed, 0 failed`), but
it was not rerun after the latest corridor-cell additions. That should be one
of the first non-live checks next session after the emulator path work pauses.

## Where To Read Results

- `dw_debug.log`: primary source for hook output and validation logs
- `dw_blocks.log`: persistent blocked-move capture
- `dw_commands.txt`: queued commands awaiting pickup

For this workflow, trust `dw_debug.log` over speech output.

## Local Non-Emulator Checks

Before live testing, the available local smoke test is:

```bash
python3 run_tests.py --allow-missing-speech-dep
```

Current state in this workspace:

- Lua syntax: passes
- Python syntax: passes
- command queue test: passes
- bridge config: fails because `speech_python_cmd` resolves to missing path
  `/mnt/d/modding/dragonwarrior1/python`

That means local tests are still useful for syntax and queue sanity, but they
do not replace FCEUX validation and currently include one known environment
failure unrelated to pathfinding logic.

## First Next-Session Checklist

1. Reload the Lua script in FCEUX if code changed since the last emulator load.
2. Freeze NPCs and clear runtime blockers.
3. Re-verify `19,2` on `map 0x04`.
4. Run `test_path`.
5. If the suite passes, resume sweep-driven candidate discovery.
6. Promote only cells reproduced directly with validation.

## Files Most Likely To Matter For Follow-up Work

- `main.lua`
- `path_debug.lua`
- `route_manager.lua`
- `auto_step.lua`
- `pathfinder.lua`
- `map_reader.lua`
- `dw_commands.sh`
- `debug_hooks.txt`
