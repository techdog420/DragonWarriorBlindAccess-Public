# Handoff: Brecconary Survey Isolation Cleanup

Date: 2026-04-05

## Summary

This session stayed focused on Brecconary (`map 0x08`) survey reliability,
isolated-pocket classification, and separating true hidden blockers from
targets that are merely trapped behind micro-pockets or frozen-NPC geometry.

The big outcome is that `survey_map` is now much better at saying
"this target is isolated" instead of surfacing it as a fresh blocker lead.

Latest clean survey result:

- `SURVEY_COMPLETE run=2 map=0x08 targets=21 successes=13 failures=8`
- `no_route=0`
- `gated_or_isolated=8`
- `suspected_engine_blocked=0`

Anchor:
- `dw_debug.log:2021`

That is the clearest Brecconary survey state we have had so far.

## Code Changes This Session

### 1. Runtime neighbor-block log flood was throttled

`pathfinder.lua` now dedupes `PATH_RUNTIME_BLOCK ... context=neighbor` across
repeated searches for the same map/cell during a Lua session. This was a
logging-only change to reduce late-survey FCEUX lag.

Regression:
- `test_pathfinder.lua`

### 2. Survey no-path clusters now retroactively clean up earlier results

`map_survey.lua` now reclassifies earlier clean `no_route_found` results from
the same unchanged start to `gated_or_isolated_region` once that start later
forms a confirmed isolated cluster.

Effect:
- a pocket like `(28,2)` no longer leaves one arbitrary "first miss" behind
- grouped summaries are much easier to read

Key log shape:
- `SURVEY_RECLASSIFY ... from=no_route_found to=gated_or_isolated_region`

Regression:
- `test_map_survey.lua`

### 3. Endgame continuation-trap reorder loop was fixed

The survey was getting stuck in a live loop:

- `SURVEY_REORDER`
- then `SURVEY_DEFER`
- for the same `Guard 6` target thousands of times

Cause:
- the "paired continuation traps" escape hatch was misfiring when the
  "other target" was just the same deferred target immediately behind the
  current retry

Fix:
- `map_survey.lua` now requires the "other target" to be a different target id

Regression:
- `test_map_survey.lua`

Result:
- the next live survey completed normally instead of spinning

### 4. Brecconary `7,20` was promoted correctly

`map_reader.lua` already had `["7,20"] = {east = true}` from older evidence.

This session added:
- `south = true`

Why:
- repeated live failures hit `(7,21) -> (7,20)` with `approach=south`

Regression:
- `test_map_reader.lua`

### 5. Survey now recognizes single-target adjacent micro-pockets

This is the most important tooling improvement from the latter half of the
session.

`pathfinder.lua` now returns structured adjacent-landing diagnostics:
- `reachable_area`
- `open_exits`
- whether a path existed to each adjacent tile

`route_manager.lua` now passes that metadata through planning.

`map_survey.lua` now classifies an adjacent no-path target as
`gated_or_isolated_region` immediately when:

- every viable adjacent landing has only one exit, and
- at least one viable landing is a tiny micro-pocket

This matches the Guard 1 / ledge cases we reproed live.

New structured log:
- `SURVEY_TARGET_ISOLATED_ADJACENT ... reason=single_exit_micro_landing`

Regression:
- `test_map_survey.lua`

## Important Live Findings

### `7,20` is now a justified permanent blocker

Fresh evidence this session:
- `Woman 2` failed with `suspected_tiles=7,20`
- `Guard 4` failed with `suspected_tiles=7,20`
- `Person 1` later succeeded only after rerouting around `7,20|9,21`

After promoting `7,20.south`, those failures disappeared from later surveys.

Useful anchors:
- `dw_debug.log:287`
- `dw_debug.log:320`
- `dw_debug.log:438`

### Guard 1 was not a hidden-wall case

Guard 1 looked suspicious for a while, but the live repro showed his current
tile geometry is simply awkward:

- current live Guard 1 position was `(20,25)`
- valid adjacent landings were only `(19,25)` and `(21,25)`
- `(20,24)` and `(20,26)` are void / non-walkable

More importantly:
- `(19,25)` is a literal 2-tile dead-end ledge with only one open exit
- `20,25` itself is blocked only by NPC occupancy

Useful anchors:
- current live state:
  - `dw_debug.log:3512`
- pathfind repro:
  - `dw_debug.log:3565`
  - `dw_debug.log:3580`
- local ledge probe:
  - `dw_debug.log:3590`
  - `dw_debug.log:3608`

Interpretation:
- Guard 1 should be treated as isolated/gated by survey logic
- do not promote map data from this branch

### `26,23` is only partially confirmed

This corridor looked promising at first, but live probing narrowed it down:

- `26,23` is confirmed blocked from the east
- north / south / west approaches to `26,23` did not reproduce as blocked
- the broader `y=23` band did not justify promotion

Useful anchors:
- east-side repro:
  - `dw_debug.log:34800`
- seam checks:
  - `dw_debug.log:39480`

Interpretation:
- keep existing `26,23`-style data only where directly reproduced
- do not promote the whole band

### `9,19` is not a hidden passable blocker

The latest fresh reroute-backed signal from `Guard 6` turned out to be a
non-walkable tile, not a decoder miss.

Live probe:
- `9,19` is tile `0`
- all approaches into it are blocked because the tile itself is non-walkable

Useful anchors:
- `dw_debug.log:2028`
- `dw_debug.log:2038`
- `dw_debug.log:2040`
- `dw_debug.log:2042`
- `dw_debug.log:2044`

Interpretation:
- do not promote anything from the `9,19` reroute

## Latest Survey State

Most recent clean survey summary:

- `dw_debug.log:2021`

Grouped failure starts:

- `(13,8)` -> 3 gated/isolated targets
  - `dw_debug.log:2023`
- `(5,28)` -> 3 gated/isolated targets
  - `dw_debug.log:2024`
- `(4,8)` -> 1 gated/isolated target
  - `dw_debug.log:2025`
- `(1,15)` -> 1 gated/isolated target
  - `dw_debug.log:2026`

Notable new targeted classification:

- `Old Man 1` emitted `SURVEY_TARGET_ISOLATED_ADJACENT`
  - `dw_debug.log:931`

This is good news: unresolved cases are now mostly landing in the right
bucket instead of masquerading as blocker candidates.

## Files Changed This Session

- `map_reader.lua`
- `map_survey.lua`
- `pathfinder.lua`
- `route_manager.lua`
- `test_map_reader.lua`
- `test_map_survey.lua`
- `test_pathfinder.lua`

## Verification

Passed during this session:

- `lua test_map_reader.lua`
- `lua test_map_survey.lua`
- `lua test_pathfinder.lua`
- `python3 run_tests.py --allow-missing-speech-dep`

Expected warning in this environment:
- missing `accessible_output2`

## Recommended Next Steps

### If continuing on Brecconary

The map-data side is in pretty good shape now. The most productive next work is
survey tooling that scales to future towns/interiors.

Best next directions:

1. Keep watching for fresh reroute-backed cells that are:
   - directly passable-looking in `inspect_tile`
   - repeatedly hit from the same approach
   - not already explained by non-walkable terrain

2. Improve survey reporting around isolated pockets:
   - surface adjacent-landing diagnostics directly in grouped summaries
   - possibly count "micro-pocket isolated targets" separately from broader
     multi-target isolated regions

3. If a future survey produces a real blocker lead, use the same standard:
   - survey correlation first
   - then direct `inspect_tile` / `inspect_move`
   - only then promote to `map_reader.lua`

### If moving on to other maps

The most reusable pieces from this session are:

- startup isolated-start rejection
- grouped failure-pocket summaries
- retroactive no-path cluster reclassification
- continuation-trap defer/reorder fixes
- micro-landing isolated-adjacent classification
- cross-search runtime-block neighbor-log dedupe

Those are likely to save a lot of time on partially decoded interiors.

## Suggested Commands For The Next Agent

Healthy-start survey flow:

```bash
./dw_commands.sh report_survey_start
./dw_commands.sh --replace clear_runtime_blocks freeze_npcs survey_map
```

Retry-failed preflight:

```bash
./dw_commands.sh report_survey_start:retry_failed
```

Useful inspection primitives:

```bash
./dw_commands.sh current_object
./dw_commands.sh report_position
./dw_commands.sh debug_pathfind_adjacent:X,Y
./dw_commands.sh inspect_tile:X,Y
./dw_commands.sh inspect_move:X,Y,DIR
```

## Worktree Note

The worktree is intentionally dirty and contains many unrelated files. Keep
edits narrow and do not broadly revert anything.
