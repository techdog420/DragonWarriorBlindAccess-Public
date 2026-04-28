# Handoff: Brecconary Clean Post-`(3,5)` Survey - 2026-04-27

## Summary

After reloading with `(3,5) west` restored as a static directional block, a new
parked Brecconary object survey completed cleanly:

```text
SURVEY_START run=1 map=0x08 start=(20,15) targets=21 mode=objects
npc_mode=park_npcs runtime_blocks=0
SURVEY_COMPLETE run=1 map=0x08 targets=21 successes=13 failures=8
no_route=0 gated_or_isolated=8 movement_failed=0 suspected_engine_blocked=0
state_issues=0 adjacency_issues=0
```

Follow-up reporting confirmed:

```text
POSITION: map=0x08(Brecconary) x=10 y=25
RUNTIME_BLOCKS map=0x08 none
SURVEY_STRONG_CANDIDATES map=0x08 none
SURVEY_FINDINGS map=0x08 run=1 failed_targets=8 failure_starts=4
strong_reroute_candidates=0
```

## Interpretation

No map-data patch is justified from this run.

The prior `(3,5)` candidate no longer appears as a suspected engine blocker
because the route model already avoids it. The remaining failures are all
planner-level gated/isolated regions with no blocked movement evidence.

The `route_drift_retry` rail fired during the run and appears useful:

```text
SURVEY_REQUEUE ... target_id=npc_7 reason=route_drift_retry retry=1
SURVEY_REQUEUE ... target_id=npc_2 reason=route_drift_retry retry=1
SURVEY_REQUEUE ... target_id=npc_11 reason=route_drift_retry retry=1
```

All three later succeeded after reachable-priority reorder:

```text
target_id=npc_2 target_name="Merchant" ... movement_succeeded=true final=(7,8)
target_id=npc_11 target_name="Guard" ... movement_succeeded=true final=(28,2)
target_id=npc_7 target_name="Woman" ... movement_succeeded=true final=(28,15)
```

## Failed Targets

All eight failed targets are `gated_or_isolated_region`:

```text
Person 5   target=(20,23) final=(20,13)
Woman 1    target=(24,4)  final=(9,15)
Merchant 3 target=(10,21) final=(9,15)
Guard 4    target=(4,26)  final=(4,8)
Person     target=(20,10) final=(28,15)
Old Man    target=(24,10) final=(28,15)
Merchant   target=(25,25) final=(28,15)
Merchant   target=(5,4)   final=(28,15)
```

Failure starts:

```text
start=(28,15) failures=4 targets=Merchant|Merchant|Old Man|Person
start=(9,15)  failures=2 targets=Merchant 3|Woman 1
start=(4,8)   failures=1 targets=Guard 4
start=(20,13) failures=1 targets=Person 5
```

## Current Live State

Current live position after the survey and follow-up report:

```text
POSITION: map=0x08(Brecconary) x=10 y=25
RUNTIME_BLOCKS map=0x08 none
```

Retry-failed preflight from that current position is not useful:

```text
SURVEY_START_STATUS map=0x08 mode=retry_failed start=(10,25) targets=8
reachable_area=13 open_exit_count=3 open_exits=north|south|west
blocked_exits=east:directional(west) status=isolated_start
reachable_targets=0 unreachable_targets=8 isolation_reason=low_target_coverage
```

## Next Step

Best next step is to treat Brecconary blocker discovery as clean for now and
move on to another map or workflow.

If more Brecconary work is desired, do not run `retry_failed` from `(10,25)`.
Relocate to a viable central start such as `(20,15)` before another broad
survey, or pick one failed target/cluster and inspect it directly with
`debug_pathfind_to`/`report_survey_start` from a deliberately chosen location.
