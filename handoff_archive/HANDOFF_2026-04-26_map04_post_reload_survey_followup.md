# Handoff 2026-04-26 - Map 0x04 post-reload survey follow-up

## Fresh survey result after reload

After full script reload, the user ran another `survey_objects:park_npcs` on
map `0x04`.

Result:

```text
SURVEY_COMPLETE run=1 map=0x04 targets=29 successes=14 failures=15 no_route=0 gated_or_isolated=7 movement_failed=0 suspected_engine_blocked=0 state_issues=8 adjacency_issues=0
```

The active repeated state/timing blockers were:

```text
20,6(north)
21,4(west)
21,5(west)
```

The `17,6/18,6/19,6 north=true` patch loaded correctly; those cells did not
remain the active bottleneck.

## Candidate guardrail status

The survey candidate filter behaved as intended for the three remaining east
connector cells:

```text
SURVEY_CANDIDATE ... key=21,4 ... state_issues=8 confidence=needs_repro
SURVEY_CANDIDATE ... key=21,5 ... state_issues=8 confidence=needs_repro
SURVEY_CANDIDATE ... key=20,6 ... state_issues=8 confidence=needs_repro
```

They were visible diagnostically but did not appear in
`SURVEY_STRONG_CANDIDATES`.

## Direct controls

Codex then reran normalized adjacent-start controls after the reload:

```text
teleport_to:20,5 + simulate_input:DOWN       -> stayed at (20,5)
teleport_to:20,5 + simulate_raw_input:DOWN,90 -> stayed at (20,5)
teleport_to:20,4 + simulate_raw_input:RIGHT,90 -> stayed at (20,4)
teleport_to:20,5 + simulate_raw_input:RIGHT,90 -> stayed at (20,5)
```

Temporarily raising `auto_step_inject_limit` from 12 to 24 did not change the
`simulate_input:DOWN` result; it still timed out at `(20,5)`.

Interpretation:

- The earlier raw-input "moved through" evidence for `20,6 north`,
  `21,4 west`, and `21,5 west` was contaminated by stale movement/subtile state.
- The post-reload normalized raw controls support promoting all three seams.
- `dw_access.ini` was restored to `auto_step_inject_limit=12` after the test.

## Patch applied

`map_reader.lua` now models the complete east-connector wall band:

```lua
["17,6"] = {north = true},
["18,6"] = {north = true},
["19,6"] = {north = true},
["20,6"] = {north = true},
["21,4"] = {west = true},
["21,5"] = {west = true},
```

`test_map_reader.lua` was updated so the east-connector regression expects all
six confirmed seams.

## Next step

Reload the full Lua script in FCEUX, then rerun a focused east-side target or
another parked-NPC survey. The expected improvement is that the repeated
state/timing failures from starts `(20,4)` and `(20,5)` should no longer produce
runtime blocks at `20,6`, `21,4`, or `21,5`.
