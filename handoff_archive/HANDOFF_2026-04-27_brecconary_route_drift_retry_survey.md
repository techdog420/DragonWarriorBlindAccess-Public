# Handoff: Brecconary Route-Drift Retry Survey - 2026-04-27

## Survey Result

After reloading the `route_drift_retry` survey patch, the next parked
Brecconary object survey improved again:

```text
SURVEY_COMPLETE run=2 map=0x08 targets=21 successes=13 failures=8 no_route=0 gated_or_isolated=8 movement_failed=0 suspected_engine_blocked=0 state_issues=0 adjacency_issues=0
```

Post-run status:

```text
POSITION: map=0x08(Brecconary) x=10 y=25
RUNTIME_BLOCKS map=0x08 none
SURVEY_STRONG_CANDIDATES map=0x08 none
SURVEY_FINDINGS map=0x08 run=2 failed_targets=8 failure_starts=2 strong_reroute_candidates=0
```

There was an earlier `run=1` start abort from `(6,21)`:

```text
SURVEY_START_ABORT run=1 map=0x08 reason=isolated_start start=(6,21) targets=21 reachable_area=13 open_exit_count=1 ... isolation_reason=small_reachable_area reachable_targets=1 unreachable_targets=20
```

That abort is expected and is the stranded-start guard doing its job, not a
map-data regression.

## Retry Patch Behavior

The new route-drift retry rail fired twice, and both targets later succeeded:

```text
SURVEY_REQUEUE run=2 map=0x08 target_id=npc_0 reason=route_drift_retry retry=1
SURVEY_RESULT run=2 map=0x08 target_id=npc_0 target_name="Old Man" ... movement_succeeded=true final=(9,15)

SURVEY_REQUEUE run=2 map=0x08 target_id=npc_8 reason=route_drift_retry retry=1
SURVEY_RESULT run=2 map=0x08 target_id=npc_8 target_name="Guard" ... movement_succeeded=true final=(14,5)
```

The first drift was `(10,17)->(10,16)` after a quick north step. The second was
`(16,10)->(16,9)` after a quick north step. In both cases the target was
retried from the live drifted position later in the run and completed without
blocked evidence.

`Woman 3`, the prior state issue, also succeeded:

```text
SURVEY_RESULT run=2 map=0x08 target_id=npc_12 target_name="Woman 3" start=(16,9) target=(4,7) path_found=true path_length=17 movement_succeeded=true final=(4,8)
```

## Remaining Failures

All eight remaining failures are clean gated/isolated regions with no blocked
events or suspected tiles:

```text
SURVEY_FAILURE_START map=0x08 start=(4,8) failures=4 distinct_targets=4 gated_or_isolated=4 ... targets=Merchant 2|Merchant 4|Old Man 2|Woman 1
SURVEY_FAILURE_START map=0x08 start=(9,15) failures=4 distinct_targets=4 gated_or_isolated=4 ... targets=Guard|Merchant|Person|Person
```

Failed targets from post-run findings:

```text
start/final=(4,8): Merchant 2, Old Man 2, Merchant 4, Woman 1
start/final=(9,15): Merchant, Guard, Person, Person
```

## Current Start Caveat

The player is currently at `(10,25)`, which is a small pocket for the remaining
failed-target set. A retry-failed preflight from there reports:

```text
SURVEY_START_STATUS map=0x08 mode=retry_failed start=(10,25) targets=8 reachable_area=13 open_exit_count=3 ... status=isolated_start reachable_targets=0 unreachable_targets=8 isolation_reason=low_target_coverage npc_mode=park_npcs
```

Do not run `survey_objects:retry_failed,park_npcs` from `(10,25)` unless the
goal is to verify that it aborts. Move or teleport to a broader start before
retrying failed targets.

## Recommendation

No `map_reader.lua` patch is justified by this run.

Best next step is either:

- Stop broad Brecconary blocker hunting for now and treat map `0x08` as clean
  enough: no runtime blocks, no strong candidates, no suspected engine
  blockers, and no state issues remain.
- Or, if squeezing the last eight targets matters, relocate to a broader start
  and run `report_survey_start:retry_failed,park_npcs` first. Only run the
  retry-failed survey if the preflight shows useful target coverage.
