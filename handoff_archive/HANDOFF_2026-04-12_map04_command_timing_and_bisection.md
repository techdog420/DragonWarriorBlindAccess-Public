# Handoff: Map04 Command Timing And East-Band Bisection
Date: 2026-04-12

## What Happened This Session

### 1. The hop-over movement bug stayed fixed in live use
After reloading the script, the old single-press overshoot repro was re-run
multiple times:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks report_position
./dw_commands.sh --replace teleport_to:13,18
./dw_commands.sh --replace simulate_input:DOWN
./dw_commands.sh --replace report_position
```

Observed:
- all three runs ended at `(13,19)`, not `(13,20)`
- user also manually reported normal stepping behavior

This issue is closed for now and the fix was committed earlier as:
- `2defc8e Fix auto-step overshoot and refine castle blockers`

### 2. Frozen-NPC survey failures are now separating cleanly from seam evidence
From `(13,16)`, the most useful long nearby routes were checked again:
- `survey_target:npc_5` (`Guard 2`)
- `survey_target:npc_6` (`Guard 3`)

Observed:
- both now consistently classify as `SURVEY_NPC_BLOCKED_ROUTE`
- both have NPC-free routes when `skip_npcs=true`
- neither produced fresh `route_blocked` / `blocked_step` seam evidence today

This is good news: the newer survey classification is preventing NPC-state
noise from being mistaken for fresh map data.

### 3. The old `tile=11` suspicion at the middle band weakened further
Direct inspection around the earlier `y=13..17` concern:

- `inspect_tile:13,16`
- `inspect_tile:14,16`
- `inspect_move:13,16,RIGHT`
- `probe_edge:RIGHT` from `(13,16)`

Observed:
- `(13,16)` and `(14,16)` both still report `tile=11`
- but both also report:
  - `base_walkable=true`
  - `walkable=true`
  - `effective_passable=true`
- `(13,16) -> RIGHT` into `(14,16)` moved successfully in-engine

Interpretation:
- `tile=11` here is not currently acting like a hidden wall
- this band should be deprioritized as a direct decoder mismatch candidate

### 4. A very important command-entry quirk was isolated
The biggest practical finding from today was not new map data, but a reliable
command-queue/testing rule.

When `teleport_to` is batched in the same command write with stateful follow-up
actions like `survey_target`, `probe_edge`, or similar movement/path commands,
the follow-up action can sometimes read stale or mid-transition player state.

Concrete examples from today:
- `teleport_to:13,16 survey_target:npc_6`
  - log showed `Teleported to (13,16)`
  - but `SURVEY_START` sometimes recorded `start=(15,16)`
- `teleport_to:22,16 probe_edge:RIGHT`
  - log showed `Teleported to (22,16)`
  - but `probe_edge` still started from stale `(13,16)` and timed out

The reliable workaround is:
1. send `freeze_npcs teleport_to:X,Y report_position`
2. wait for log confirmation that position is correct
3. send `probe_edge`, `survey_target`, or debug path command as a separate
   command write

This split-command pattern turned both survey starts and edge probes back into
clean evidence.

### 5. Coordinate-based route stress shifted focus away from the obvious east seam
To remove NPC-target endpoint noise, coordinate debug checks were used:

```bash
./dw_commands.sh --replace debug_pathfind_to:18,22
./dw_commands.sh --replace debug_pathfind_to:23,16
./dw_commands.sh --replace debug_pathfind_adjacent:18,22
./dw_commands.sh --replace debug_pathfind_adjacent:23,16
```

Observed:
- `debug_pathfind_to:18,22` -> `No path found`
- `debug_pathfind_to:23,16` -> `No path found`
- `inspect_tile:18,22` -> walkable
- `inspect_tile:23,16` -> walkable
- `debug_pathfind_adjacent:23,16` still found no path to any adjacent tile

That looked like an east-band isolation boundary at first, but direct live
bisection across row `y=16` showed these seams are actually open:

- `(22,16) <-> (23,16)` open both ways
- `(21,16) <-> (22,16)` open both ways
- `(20,16) <-> (21,16)` open both ways

So the remaining isolation is not on those row-16 seams.

## Most Important Takeaways

1. Do not trust batched `teleport_to + survey_target/probe_edge` results when
   the exact start tile matters.
2. The reliable QA loop is now:

```bash
./dw_commands.sh --replace freeze_npcs teleport_to:X,Y report_position
# wait for log confirmation
./dw_commands.sh --replace probe_edge:DIR
```

or

```bash
./dw_commands.sh --replace freeze_npcs teleport_to:X,Y report_position
# wait for log confirmation
./dw_commands.sh --replace survey_target:TARGET_ID
```

3. The middle/east isolation is still real in planner/debug output, but it is
   not explained by:
   - `(13,16) -> (14,16)`
   - `(20,16) <-> (21,16)`
   - `(21,16) <-> (22,16)`
   - `(22,16) <-> (23,16)`

## Current Best Hypothesis

The unresolved isolation boundary is probably one of:
- a seam on neighboring rows (`y=15` or `y=17`) instead of `y=16`
- a farther-west choke point than `x=20`
- or a remaining planner/state interaction that is not a simple single-edge
  permanent blocker

## Recommended First Steps Next Session

Keep using the split-command pattern.

1. Test the neighboring-row seams near the same corridor:

```bash
./dw_commands.sh --replace freeze_npcs teleport_to:23,15 report_position
./dw_commands.sh --replace probe_edge:LEFT

./dw_commands.sh --replace freeze_npcs teleport_to:23,17 report_position
./dw_commands.sh --replace probe_edge:LEFT
```

2. If those are also open, shift the row-16 bisection west:

```bash
./dw_commands.sh --replace freeze_npcs teleport_to:19,16 report_position
./dw_commands.sh --replace probe_edge:RIGHT

./dw_commands.sh --replace freeze_npcs teleport_to:20,16 report_position
./dw_commands.sh --replace probe_edge:LEFT
```

3. Only promote new map data after two clean direct repros with runtime blocks
   cleared and a separately verified teleport start.

## Commands That Were Most Useful Today

```bash
./dw_commands.sh --replace freeze_npcs teleport_to:X,Y report_position
./dw_commands.sh --replace probe_edge:DIR
./dw_commands.sh --replace inspect_tile:X,Y
./dw_commands.sh --replace inspect_move:X,Y,DIR
./dw_commands.sh --replace debug_pathfind_to:X,Y
./dw_commands.sh --replace debug_pathfind_adjacent:X,Y
./dw_commands.sh --replace report_blockers
./dw_commands.sh --replace unfreeze_npcs
```
