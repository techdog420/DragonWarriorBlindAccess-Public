# Handoff: Brecconary Post-Guard-Patch Survey Analysis - 2026-04-26

## Survey Result

After the Guard 4 southwest-pocket patch was reloaded, the next parked
Brecconary survey completed:

```text
SURVEY_COMPLETE run=4 map=0x08 targets=21 successes=13 failures=8 no_route=0 gated_or_isolated=6 movement_failed=1 suspected_engine_blocked=1 state_issues=0 adjacency_issues=0
```

The six gated/isolated failures remain the expected isolated clusters:

```text
start=(28,2): Merchant, Merchant, Old Man, Person
start=(23,13): Merchant 4, Woman 1
```

Two failures needed investigation:

- `Woman 3` at `(4,7)`: classified as `route_found_but_movement_failed`,
  final `(4,8)`, blocked tile `4,7`.
- `Guard 4` at `(3,26)`: classified as `suspected_engine_blocked_tile`,
  final `(10,28)`, suspected `10,27`.

## Guard 4 / 10,27 South

The survey initially produced a high-confidence candidate:

```text
SURVEY_CANDIDATE map=0x08 x=10 y=27 key=10,27 count=3 targets=1 retry_successes=0 failure_count=1 state_issues=0 confidence=high approaches=south
SURVEY_DIRECTIONAL_EXPORT map=0x08 count=1
    ["10,27"] = {south=true}
```

Do not patch that cell yet. A focused split probe with runtime blocks cleared
and NPCs frozen moved through the edge:

```text
POSITION: map=0x08(Brecconary) x=10 y=28
MOVE map=0x08 from=(10,28) dir=up dest=(10,27) ... effective_passable=true
EDGE_PROBE_RESULT map=0x08 from=(10,28) dir=up dest=(10,27) status=moved final=(10,27)
SEAM_OBSERVATION map=0x08 cell=(10,27) approach=south result=moved blocked=3 moved=1 classification=noisy
```

After that probe, the survey candidate was correctly downgraded:

```text
SURVEY_CANDIDATE map=0x08 x=10 y=27 key=10,27 ... confidence=needs_repro approaches=south
SURVEY_CANDIDATE_SUGGESTIONS map=0x08 none
SURVEY_DIRECTIONAL_EXPORT map=0x08 count=0
```

Keep `MAP_DIRECTIONAL_BLOCKS[0x08]["10,27"] = {north=true}` only.

## Woman 3 / Route Drift Garbage Data

The `Woman 3` failure was not a real map blocker. The planned adjacent route
from `(1,14)` to stand at `(4,8)` was valid:

```text
pathfind chosen adj=(4,8) path=1 north, 2 east, 2 north, 1 east, 3 north
AUTO_WALK: queued 9 step(s) for Woman 3
```

But after the first step completed, stale movement carried the player off the
planned route:

```text
auto_step complete dir=up from=(1,14) to=(1,13)
auto_step route drift not on queued path from=(1,13) current=(1,12) next_index=2
```

The old auto-step behavior only logged that off-path drift during the survey
settle window, then continued the stale queued route from `(1,12)`. That shifted
the whole route and made it try one extra `UP` into the target NPC tile:

```text
auto_step complete dir=up from=(4,9) to=(4,8)
auto_step begin_step dir=up from=(4,8)
NEW BLOCK: map=0x08 from=(4,8) dir=up dest=(4,7)
```

`auto_step.lua` now cancels queued routes immediately when live position drifts
off the planned path and cannot be consumed as a matching catch-up step. It
publishes:

```text
route_cancelled reason=route_drift_off_path
```

This should turn the same failure into a state/timing issue instead of a bogus
blocked tile and stop the route from generating garbage collision evidence.

## Validation

Passed:

```text
luac -p auto_step.lua test_auto_step.lua
lua test_auto_step.lua        # 17/17
git diff --check -- auto_step.lua test_auto_step.lua map_reader.lua test_map_reader.lua session_handoff.md
```

No `map_reader.lua` change was made for this survey.

## Live State Restored

After the direct probe and reports:

```text
POSITION: map=0x08(Brecconary) x=10 y=25
NPCs unfrozen
RUNTIME_BLOCKS map=0x08 none
PATH_STATE target=nil map=0x08 runtime_count=0
```

## Next Resume Point

Reload Lua before relying on the route-drift cancellation patch. Then rerun a
fresh parked Brecconary survey. Expected improvement:

- `Woman 3` should no longer publish a bogus `(4,7)` block after off-path drift.
- `10,27 south` should remain noisy/unexported unless a future focused probe
  reproduces a clean block again.
- Remaining failures should mostly be the known gated/isolated clusters.
