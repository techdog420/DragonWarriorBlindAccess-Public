# Handoff: Brecconary Fresh Survey Follow-up — 2026-04-26

## Context

The player moved into Brecconary (`map=0x08`) and ran a fresh parked-NPC
object survey.

Survey start:

```text
SURVEY_START run=2 map=0x08 start=(3,17) targets=21 mode=objects npc_mode=park_npcs runtime_blocks=0
```

Survey completion:

```text
SURVEY_COMPLETE run=2 map=0x08 targets=21 successes=5 failures=16 no_route=0 gated_or_isolated=6 movement_failed=0 suspected_engine_blocked=9 state_issues=1 adjacency_issues=0
```

Post-run candidate report:

```text
SURVEY_CANDIDATE map=0x08 x=10 y=27 key=10,27 count=12 targets=10 retry_successes=0 failure_count=9 state_issues=1 confidence=high approaches=north
SURVEY_CANDIDATE map=0x08 x=8 y=27 key=8,27 count=1 targets=1 retry_successes=0 failure_count=0 state_issues=1 confidence=needs_repro approaches=south
SURVEY_CANDIDATE_SUGGESTION map=0x08 x=10 y=27 key=10,27 kind=directional approaches=north confidence=high count=12 retry_successes=0 state_issues=1 targets=10
```

The nine suspected engine-blocked failures all pointed at `(10,27)` from the
north approach. Six more targets were clean `gated_or_isolated_region`. Guard 4
was classified as `command_timing_or_state_issue` because it mixed `(8,27)` and
`(10,27)` evidence.

## Live Probe Results

Split probes were run with NPCs frozen and runtime blocks cleared between
checks.

`(10,26)->DOWN` into `(10,27)`:

```text
EDGE_PROBE_RESULT map=0x08 from=(10,26) dir=down dest=(10,27) status=blocked final=(10,26) ... blocked_approach=north approach_blocked=false effective_passable=true
EDGE_PROBE_MODEL_MISMATCH ... kind=blocked_despite_open_preview ... static_approach_blocked=false
runtime block: map=0x08 cell=(10,27) approach=north source=seam_confirm:manual_block blocked=13 moved=0
```

`(10,28)->UP` into `(10,27)`:

```text
EDGE_PROBE_RESULT map=0x08 from=(10,28) dir=up dest=(10,27) status=moved final=(10,27) ... blocked_approach=south approach_blocked=true effective_passable=false
EDGE_PROBE_MODEL_MISMATCH ... kind=moved_through_modeled_block ... static_approach_blocked=true
SEAM_OBSERVATION map=0x08 cell=(10,27) approach=south result=moved blocked=0 moved=1 classification=passable_only
```

Conclusion: checked-in `["10,27"] = {south = true}` had the face reversed.
The real current behavior is `north=true`, `south` open.

`(8,28)->UP` into `(8,27)`:

```text
EDGE_PROBE_RESULT map=0x08 from=(8,28) dir=up dest=(8,27) status=moved final=(8,27) ... approach_blocked=false effective_passable=true
SEAM_OBSERVATION map=0x08 cell=(8,27) approach=south result=moved blocked=1 moved=1 classification=noisy
```

Conclusion: the one `(8,27) south` survey hit is noisy for now. Do not promote
it to permanent map data.

## Code Changes

- `map_reader.lua`
  - Changed Brecconary `MAP_DIRECTIONAL_BLOCKS[0x08]["10,27"]` from
    `{south = true}` to `{north = true}`.
  - Updated the stale `(8,27)` comment to say the south approach is currently
    noisy and should remain unmodeled.
- `test_map_reader.lua`
  - Updated Brecconary assertions so `(10,27).north` is required and
    `(10,27).south` is expected open.
  - Updated the stale `(8,27).south` expectation to stay open after the direct
    probe moved through it.

## Validation

Passed:

```text
luac -p map_reader.lua test_map_reader.lua
```

`lua test_map_reader.lua` now passes both Brecconary test cases, but the full
suite still exits 1 due two existing map04 expectation mismatches:

```text
FAIL tantegel_castle_south_pocket_false_blocks_are_open: (12,19) should stay open from south ... got true
FAIL tantegel_castle_upper_chamber_row_16_updates_are_modeled: (16,16) should block the east approach ... got nil
```

These failures are unrelated to the Brecconary patch and predate this town
survey investigation.

## Live State After Cleanup

Runtime blocks were cleared, NPCs were unfrozen, and the player was restored to
`map=0x08`, position `(10,26)`.

Reload Lua before the next Brecconary survey so the corrected `map_reader.lua`
directional entry is active.
