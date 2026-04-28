# Handoff: Route Cleanup, South Gate Door Prune, And West Bisection
Date: 2026-04-12

## What Changed In Code

### 1. Survey-safe route planning no longer ignores real frozen-NPC blockers
`route_manager.lua` now separates two different concepts more cleanly:
- `survey_safe=true` still enables survey-specific retry/classification behavior
- `skip_npcs=true` is now required explicitly before the planner omits NPC cells

Why this matters:
- map survey diagnostics still need NPC-free blocking tables for isolation
  analysis
- actual autowalk route plans should still respect frozen NPC blockers
- otherwise a survey route can plan through a frozen NPC, then fail later for
  the wrong reason

Added regression coverage:
- `test_route_manager.lua` now verifies that `survey_safe` planning still
  reports `No path found` when a frozen NPC blocks the only route

### 2. Blocked-step cleanup is more consistent
`route_manager.lua` also got a small cleanup pass:
- introduced `clear_active_route_context()` helper for consistent route-state
  reset
- non-queued blocked steps still record runtime blocks, but no longer trigger
  reroutes
- queued route settle-frame state now survives reroutes and is cleared on
  completion/cancel/map change

Added regression coverage:
- non-route blocked steps should not trigger reroute pathfinding

### 3. Tantegel Castle now exposes only the reachable south gate door tile
`objects.lua` previously exposed both visual south-gate door halves on
`map 0x04`:
- `(10,30)` west half
- `(11,30)` east half

Latest live pathing evidence shows only the west tile is actionable from
inside the castle. The east half has no reachable adjacent stand tile and only
creates a permanent false survey/object-navigation failure.

So the extra door object was removed:
- kept `door_10_30`
- removed `door_11_30`

Added regression coverage:
- `test_objects.lua` now confirms Tantegel Castle exposes exactly one south
  gate door object

### 4. Removed stale permanent blocker at `(20,17)` on Tantegel Castle
Further live follow-up on the upper chamber boundary found that `(20,17)` no
longer matches the old permanent-block model.

What live testing showed:
- `inspect_tile:20,17` still reported `permanent_blocked=true`
- exact `teleport_to:20,17` was refused for the same reason
- but direct engine movement still succeeded:
  - `(19,17) -> RIGHT` moved to `(20,17)`
  - `(20,18) -> UP` moved to `(20,17)`
  - `(20,17) -> LEFT` moved back to `(19,17)`

Interpretation:
- the hardcoded `MAP_BLOCKED_CELLS[0x04]["20,17"]` entry had gone stale
- nearby blocker `19,16` still held up cleanly, so this should be treated as a
  narrow one-cell correction rather than a broad chamber rewrite

Code change:
- removed `["20,17"] = true` from `map_reader.lua`

Added regression coverage:
- `test_map_reader.lua` now verifies `(20,17)` is no longer a permanent block
  while nearby confirmed blocker `(19,16)` remains blocked

## Verification

Passed locally:
- `lua test_objects.lua`
- `lua test_route_manager.lua`
- `lua test_map_survey.lua`
- `lua test_auto_step.lua`
- `lua test_map_reader.lua`
- `lua test_path_debug.lua`

## Live Follow-up From The Earlier Map 0x04 Bisection Handoff

Using the split-command pattern from
`HANDOFF_2026-04-12_map04_command_timing_and_bisection.md`:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:X,Y report_position
# wait for log confirmation
./dw_commands.sh --replace probe_edge:DIR
```

### Confirmed open seams

Direct probes succeeded:
- `(23,15) -> LEFT` moved to `(22,15)`
- `(23,17) -> LEFT` moved to `(22,17)`

The second repro needed timeout retries but still finished cleanly as:
- `EDGE_PROBE_RESULT ... status=moved ... final=(22,17)`

### First useful westward boundary

The next west-bisection step did **not** behave like an open corridor:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:19,16 report_position
```

Observed:
- exact teleport was refused
- log: `(19,16) not walkable (tile=0x04); use near or force`

Follow-up diagnostics:

```bash
./dw_commands.sh --replace inspect_tile:19,16 inspect_tile:20,16
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:20,16 report_position
./dw_commands.sh --replace probe_edge:LEFT
```

Observed:
- `inspect_tile:19,16`
  - `tile=4`
  - `base_walkable=true`
  - `walkable=false`
  - `permanent_blocked=true`
  - `effective_passable=false`
- `inspect_tile:20,16`
  - `tile=4`
  - `walkable=true`
  - `permanent_blocked=false`
- direct probe from `(20,16)` to the left failed after retries
- final log line:
  - `EDGE_PROBE_RESULT ... status=blocked ... dest=(19,16) ... reason=route_blocked`

Interpretation:
- the east-band seams at `x=20..23` being open does **not** extend farther
  west through `(19,16)`
- this is not fresh blocker evidence requiring a new code change
- `map_reader.lua` still correctly includes `["19,16"] = true`
- the live repro cleanly re-confirms that existing permanent blocker

### Important stale-block correction: `(20,17)` is actually reachable

The old March chamber notes said row `17` stopped at `20,17`, but current live
testing disproved that:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:19,17 report_position
./dw_commands.sh --replace probe_edge:RIGHT report_position

./dw_commands.sh --replace report_position inspect_tile:20,17 probe_edge:LEFT report_position

./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:20,18 report_position
./dw_commands.sh --replace probe_edge:UP report_position
```

Observed:
- `(19,17) -> RIGHT` moved to `(20,17)`
- standing on `(20,17)` was confirmed by `report_position`
- `inspect_tile:20,17` still claimed:
  - `tile=6`
  - `base_walkable=true`
  - `walkable=false`
  - `permanent_blocked=true`
- `(20,17) -> LEFT` moved back to `(19,17)`
- independent south approach `(20,18) -> UP` also moved to `(20,17)`
- exact `teleport_to:20,17` still refused while the stale block was present

Interpretation:
- this is strong repeat evidence that `(20,17)` was a stale permanent blocker
- old chamber notes around that exact stop point should no longer be treated as
  authoritative
- `map_reader.lua` was updated to remove only `20,17`

### Post-reload verification: the fix is live and planner connectivity improved

After reloading the Lua script in FCEUX, the stale-block fix was rechecked.

Clean post-reload repros:
- `teleport_to:19,17` then `probe_edge:RIGHT`
  - `EDGE_PROBE_RESULT ... status=moved final=(20,17)`
- `teleport_to:20,18` then `probe_edge:UP`
  - `EDGE_PROBE_RESULT ... status=moved final=(20,17)`
- `inspect_tile:20,17`
  - `walkable=true`
  - `permanent_blocked=false`
  - `effective_passable=true`

There was one noisy blocked repro during retesting from each approach, but the
latest clean reruns both succeeded and exact `teleport_to:20,17` now works.
Current best interpretation is:
- the old full blocker at `20,17` was definitely stale
- intermittent blocked-edge results here are more likely movement/probe noise
  than stable permanent-wall evidence

Planner impact after reload from `(13,16)`:
- `debug_pathfind_to:23,16` now finds a route
- `debug_pathfind_to:18,22` now finds a route

This is the strongest sign so far that removing stale `20,17` materially
improved the old chamber/isolation problem instead of just cleaning up tile
inspection output.

Survey impact so far:
- `report_survey_start` from `(13,16)` now logs:
  - `status=viable`
  - `reachable_area=128`
  - `open_exits=north|south|east`
- a fresh `freeze_npcs survey_map` from `(13,16)` got materially farther than
  the older isolation runs
- early result:
  - `Guard 3` completed with
    `reason=reroute_succeeded_after_runtime_block`
  - that is much healthier than the earlier isolated/no-path story
- the running survey also surfaced a fresh transient/runtime block candidate at
  `(14,16)` from the west during the first adjacent attempt
- the full survey had not finished yet at handoff time

## Current Best Read Of Map 0x04

- row `y=16` is open across:
  - `(20,16) <-> (21,16)`
  - `(21,16) <-> (22,16)`
  - `(22,16) <-> (23,16)`
- row `y=15` is also open at:
  - `(20,15) -> (19,15)`
- neighboring rows near the east band are also open at:
  - `(23,15) -> (22,15)`
  - `(23,17) -> (22,17)`
- the earlier `20,17` hard-stop is no longer believed
- but the west side of the row-16 band still hard-stops at `(19,16)`

So the open/closed picture is sharper now:
- the remaining isolation is not at the obvious east edge near `x=23`
- `20,17` was stale and has now been removed from permanent blockers
- a real wall strip still exists farther west at least at `19,16`

## Recommended Next Steps

1. Reload the Lua script in FCEUX so the `20,17` map-data fix is live.

2. Re-test the corrected chamber edge with the new script loaded:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:19,17 report_position
./dw_commands.sh --replace probe_edge:RIGHT report_position
./dw_commands.sh --replace inspect_tile:20,17

./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:20,18 report_position
./dw_commands.sh --replace probe_edge:UP report_position
```

3. Continue tracing the still-confirmed west wall strip:

```bash
./dw_commands.sh --replace inspect_tile:19,16 inspect_tile:19,15 inspect_tile:19,17
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:20,16 report_position
./dw_commands.sh --replace probe_edge:LEFT report_position
```

4. Compare the updated live boundary against the older chamber notes:
- `handoff_archive/HANDOFF_2026-03-24_castle_chamber_probe.md`

5. If planner/debug output still shows larger isolation than the confirmed
west wall strip explains, investigate planner-state effects before changing
map data again.

6. Finish reviewing the in-flight `survey_map` results from the `(13,16)`
anchor before promoting any new permanent block around `(14,16)`.

## Files Changed This Session

- `objects.lua`
- `map_reader.lua`
- `route_manager.lua`
- `test_map_reader.lua`
- `test_objects.lua`
- `test_route_manager.lua`
- `session_handoff.md`
- `HANDOFF_2026-04-12_route_cleanup_and_west_bisection.md`
