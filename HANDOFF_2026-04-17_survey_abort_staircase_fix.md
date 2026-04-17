# Handoff: Survey Staircase Trap and Auto-Step Recovery
Date: 2026-04-17

## Summary

Two separate issues were resolved on map `0x04` (Tantegel Castle):

1. Survey runs launched from the staircase tile at `(7,7)` were pointless and
   got trapped immediately because the DW1 engine blocks outward movement from
   staircase tiles even though the surrounding floor/carpet tiles look walkable
   to the map model.
2. A broader `auto_step` regression caused open-floor probes and surveys to fail
   from normal starting squares like `(10,14)` and `(11,11)`, falsely promoting
   passable edges into runtime blocked evidence.

Both are now addressed on disk, and the movement fix is live-verified in FCEUX.

## What Changed

### 1. Survey abort for low-exit starts

`map_survey.lua` now aborts a survey before `survey_state` initialization when
the tile model sees only `1-2` open exits from the start square.

Speech:

```text
Survey aborted: start (X,Y) has only N open exits. Move to a more open position and try again.
```

Log tag:

```text
SURVEY_START_ABORT reason=low_exit_count
```

This specifically prevents wasting a full survey run from staircase/trap-like
starts such as map `0x04` `(7,7)`.

### 2. Auto-step turn-repress recovery fix

The current `auto_step` patch now does all of the following:

- restores `TURN_REPRESS_DELAY = 18`
- makes the 2-frame turn-repress gap actively send neutral input
- allows live D-pad input to cancel active queued route steps again
- upgrades `TURN_REPRESS_INJECT_LIMIT` from the old short 4-frame follow-up
  hold to the full `INJECT_LIMIT` window after a turn-only attempt

Supporting changes:

- `route_manager.lua`
  - stops forwarding autonomous-route suppression into `auto_step`
- `map_survey.lua`
  - stops requesting autonomous route suppression for surveys
- `test_auto_step.lua`
  - covers neutral-gap behavior, manual interrupt behavior, and the full
    follow-up repress window after a turn-only attempt
- `debug_tools.lua`
  - supports multi-frame `simulate_input:BTN,N` and
    `simulate_raw_input:BTN,N` for live isolation
- `debug_hooks.txt`
  - documents the new debug command syntax

## Why the Last Auto-Step Change Worked

Live isolation showed:

- `inspect_move:LEFT` from `(11,11)` reported `(10,11)` as passable
- `simulate_raw_input:LEFT,12` moved cleanly from `(11,11)` to `(10,11)`
- but `probe_edge:LEFT` still failed through `auto_step.inject_step`

That narrowed the remaining bug to the queued/injected `auto_step` path rather
than map data or general controller suppression.

Best current interpretation:

- the 4-frame follow-up repress after a turn-only attempt was too weak on live
  hardware to reliably start movement
- restoring a full follow-up inject window after the turn fixed that path

## Live Verification

After reloading the latest patch in FCEUX, all three previously failing open
floor probes now succeed:

1. `clear_runtime_blocks` + `teleport_to:11,11` + `probe_edge:LEFT`
   - `status=moved final=(10,11)`
2. `clear_runtime_blocks` + `teleport_to:10,14` + `probe_edge:UP`
   - `status=moved final=(10,13)`
3. `clear_runtime_blocks` + `teleport_to:13,14` + `probe_edge:LEFT`
   - `status=moved final=(12,14)`

User-observed side effect after the patch:

- field controller input also feels more reliable again

## Fresh Survey Status

From `(10,14)`:

- `report_survey_start:park_npcs`
  - `reachable_area=128`
  - `open_exit_count=4`
  - `status=viable`
- `survey_objects:park_npcs`
  - left the start square normally
  - produced real movement and early successes instead of immediate
    `command_timing_or_state_issue`

Confirmed successes seen in log:

- `Person 1` (`npc_2`)
  - `movement_succeeded=true`
  - `final=(12,14)`
- `Woman 1` (`npc_0`)
  - `movement_succeeded=true`
  - `final=(13,16)`
- `Guard 7` (`npc_14`)
  - `movement_succeeded=true`
  - `final=(9,9)`

At the last log read, the survey was still active and had reached:

- `Old Man 1` (`npc_3`)
- attempt index `7/29`

Interpretation:

- the broad auto-step regression appears fixed
- new survey failures should now be treated as fresh map/path evidence rather
  than fallout from the earlier broken movement state

## Known Good Repro Set

Use these commands if movement sanity needs re-checking:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks report_upper_dialogue_state
./dw_commands.sh --replace teleport_to:11,11 report_position
./dw_commands.sh --replace probe_edge:LEFT
./dw_commands.sh --replace clear_runtime_blocks teleport_to:10,14 report_position
./dw_commands.sh --replace probe_edge:UP
./dw_commands.sh --replace clear_runtime_blocks teleport_to:13,14 report_position
./dw_commands.sh --replace probe_edge:LEFT
```

Expected:

- all three probes end with `status=moved`

If the first edge ever regresses again, use the raw-input isolation sequence:

```bash
./dw_commands.sh --replace clear_runtime_blocks teleport_to:11,11 report_position
./dw_commands.sh --replace simulate_raw_input:LEFT,12
./dw_commands.sh --replace report_position report_blockers
```

Expected:

- player ends at `(10,11)`
- `runtime_count=0`

## Open Issues

### 1. Survey run still in progress

The current `survey_objects:park_npcs` run may still be active. Read the latest
`dw_debug.log` tail first before sending more commands.

### 2. `(12,16)` east approach — monitor only

Keep `MAP_DIRECTIONAL_BLOCKS[0x04]["12,16"].east = true`.

Do not remove it. Evidence remains mixed, but the block still fires often
enough to be useful and it is not part of the movement regression that was just
fixed.

### 3. West-side/gated region on map `0x04`

These targets still need interpretation once the survey completes:

- `chest_0` at `(1,13)`
- `chest_2` at `(2,14)`
- `chest_3` at `(3,15)`
- `chest_1` at `(1,15)`
- `Guard 4` (`npc_7`) at `(3,15)`

These may be genuinely gated by castle layout / key progression, or they may
still expose a model gap. Re-evaluate them only with the now-fixed movement
state.

## Resume Plan

1. Read the latest `dw_debug.log` tail.
2. If the survey is still active, keep watching `SURVEY_RESULT` lines.
3. If it stopped or needs a rerun:

```bash
./dw_commands.sh --replace clear_runtime_blocks teleport_to:10,14 report_position
./dw_commands.sh --replace report_survey_start:park_npcs
./dw_commands.sh --replace survey_objects:park_npcs
```

4. Focus on remaining west-side / gated targets as fresh evidence.

## Do Not

- Do not survey from staircase tile `(7,7)`.
- Do not remove the `(12,16).east` directional block.
- Do not convert the previously failing open-floor edges near `(11,11)`,
  `(10,14)`, or `(13,14)` into permanent map blockers; they are now verified
  passable.
