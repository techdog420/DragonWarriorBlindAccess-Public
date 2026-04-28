# Handoff: Brecconary Trap Cell Follow-up — 2026-04-26

## Context

After reloading the script with the `(10,27)` north-face correction, a fresh
Brecconary parked-NPC survey was started from `(3,17)`.

Completion:

```text
SURVEY_COMPLETE run=1 map=0x08 targets=21 successes=9 failures=12 no_route=0 gated_or_isolated=6 movement_failed=0 suspected_engine_blocked=0 state_issues=6 adjacency_issues=0
```

This is cleaner than the previous run: no `suspected_engine_blocked` failures
and no strong candidate suggestions. The remaining non-gated failures were
classified as `command_timing_or_state_issue`.

Candidate report:

```text
SURVEY_CANDIDATE map=0x08 x=16 y=22 key=16,22 count=7 targets=5 retry_successes=0 failure_count=0 state_issues=5 confidence=needs_repro approaches=south
SURVEY_CANDIDATE map=0x08 x=15 y=23 key=15,23 count=7 targets=5 retry_successes=0 failure_count=0 state_issues=5 confidence=needs_repro approaches=east
SURVEY_CANDIDATE map=0x08 x=17 y=23 key=17,23 count=7 targets=5 retry_successes=0 failure_count=0 state_issues=5 confidence=needs_repro approaches=west
SURVEY_CANDIDATE map=0x08 x=16 y=24 key=16,24 count=7 targets=5 retry_successes=0 failure_count=0 state_issues=5 confidence=needs_repro approaches=north
SURVEY_CANDIDATE map=0x08 x=10 y=27 key=10,27 count=5 targets=3 retry_successes=1 failure_count=0 state_issues=2 confidence=needs_repro approaches=south
SURVEY_CANDIDATE map=0x08 x=8 y=27 key=8,27 count=4 targets=2 retry_successes=1 failure_count=0 state_issues=1 confidence=needs_repro approaches=south
```

`(10,27) south` and `(8,27) south` remain noisy; previous direct probes moved
through both. They were not promoted.

## Trap Cell Evidence

The main issue was a trap at `(16,23)`. During the survey, the route entered
`(16,23)` and then failed repeatedly trying to leave. Split direct probes with
runtime blocks cleared and NPCs frozen confirmed all four exits block despite
open previews:

```text
(16,23)->RIGHT dest=(17,23) blocked, approach=west
(16,23)->UP    dest=(16,22) blocked, approach=south
(16,23)->LEFT  dest=(15,23) blocked, approach=east
(16,23)->DOWN  dest=(16,24) blocked, approach=north
```

A follow-up entry probe from `(16,24)->UP` into `(16,23)` also blocked in the
controlled run. The earlier survey route had one move into `(16,23)`, so that
entry face is considered noisy/stale rather than a safe route.

## Code Changes

- `map_reader.lua`
  - Added `MAP_BLOCKED_CELLS[0x08]["16,23"] = true`.
  - Updated the Brecconary permanent-block comment to allow pathfinder-forbidden
    one-way/trap cells in addition to cells blocked from all approaches.
- `test_map_reader.lua`
  - Added a regression assertion that `(16,23)` is permanently blocked on
    Brecconary.

## Validation

Passed:

```text
luac -p map_reader.lua test_map_reader.lua
```

`lua test_map_reader.lua` still exits 1 due the two pre-existing unrelated
map04 expectation mismatches, but the Brecconary permanent blocker and
directional tests pass:

```text
PASS brecconary_passthrough_corridor_overrides_false_wall_tiles
PASS brecconary_directional_walls_cover_confirmed_building_bands
PASS brecconary_permanent_blockers_match_current_live_model
```

## Live State After Cleanup

Runtime blocks were cleared, NPCs were unfrozen, and the player was restored to
`map=0x08`, position `(3,17)`.

Reload Lua before the next Brecconary survey so the `(16,23)` permanent blocker
is active.
