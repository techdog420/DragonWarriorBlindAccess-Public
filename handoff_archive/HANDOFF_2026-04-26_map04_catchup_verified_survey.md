# Handoff 2026-04-26 - Map 0x04 catch-up verified survey

## Survey result after queued-route catch-up patch

The user reloaded and ran a fresh `survey_objects:park_npcs` survey on map
`0x04` after the queued-route drift catch-up patch.

```text
SURVEY_COMPLETE run=1 map=0x04 targets=28 successes=14 failures=14 no_route=0 gated_or_isolated=14 movement_failed=0 suspected_engine_blocked=0 state_issues=0 adjacency_issues=0
```

Failure starts:

```text
start=(4,29)  failures=7  targets=Guard|Guard|Guard|Guard 5|Old Man|Stairs Down to Throne Room|Stairs Down to Treasure Room
start=(3,8)   failures=5  targets=Chest|Chest|Chest|Chest|Old Man 1
start=(20,19) failures=2  targets=Merchant 3|Woman 2
```

Post-run reports:

```text
SURVEY_FINDINGS map=0x04 run=1 failed_targets=14 failure_starts=3 strong_reroute_candidates=0
SURVEY_CANDIDATES map=0x04 none
SURVEY_STRONG_CANDIDATES map=0x04 none
SURVEY_CANDIDATE_SUGGESTIONS map=0x04 none
PATH_STATE ... runtime_count=0
```

Interpretation: no map-data candidates and no runtime blocked tiles. All
remaining failures are clean no-path/gated-region outcomes from the current
landing positions.

## Catch-up patch verification

The previous false block at `(6,8)` did not recur. The route to Guard 9 now
caught the stale-drift step:

```text
auto_step complete dir=right from=(3,8) to=(4,8) ...
auto_step route catch-up dir=right from=(4,8) to=(5,8) source=route_settle_catchup
auto_step begin_step dir=down from=(5,8) ...
SURVEY_RESULT ... target_id=npc_16 ... blocked_events=0 ... reason=route_completed
```

Focused log search found:

```text
no SEAM_OBSERVATION result=blocked
no auto_step blocked
no blocked_events > 0
```

There were three route catch-up events total in the run:

```text
(10,15)->(9,15) left
(4,8)->(5,8) right
(19,19)->(18,19) left
```

## Current status

The queued-route catch-up patch is behaving as intended on this survey. No code
or map-data patch is indicated by this run.
