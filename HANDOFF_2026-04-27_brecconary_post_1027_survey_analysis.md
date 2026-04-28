# Handoff: Brecconary Post-10,27 Survey Analysis - 2026-04-27

## Survey Result

After reloading the `10,27 south` map patch and running another parked
Brecconary object survey, the latest run completed cleanly from a map-data
perspective:

```text
SURVEY_COMPLETE run=2 map=0x08 targets=21 successes=11 failures=10 no_route=0 gated_or_isolated=9 movement_failed=0 suspected_engine_blocked=0 state_issues=1 adjacency_issues=0
```

This is an improvement over the prior confidence pass (`successes=9`,
`suspected_engine_blocked=1`, `state_issues=1`). The important change is that
there were no movement failures, no suspected engine-blocked tiles, and no
strong survey candidates.

Post-run status checks:

```text
POSITION: map=0x08(Brecconary) x=10 y=25
RUNTIME_BLOCKS map=0x08 none
SURVEY_STRONG_CANDIDATES map=0x08 none
SURVEY_FINDINGS map=0x08 run=2 failed_targets=10 failure_starts=4 strong_reroute_candidates=0
```

The broad `export_blocks` command still prints old accumulated blocked-move
observations across maps. Treat that output as diagnostic only here; it is not
the clean candidate list for this survey.

## Failure Breakdown

The remaining ten failures are nine expected isolated/gated targets plus one
route-execution state issue:

```text
SURVEY_FAILURE_START map=0x08 start=(28,2) failures=5 ... targets=Guard|Merchant|Merchant|Old Man|Person
SURVEY_FAILURE_START map=0x08 start=(13,8) failures=2 ... targets=Person 1|Person 3
SURVEY_FAILURE_START map=0x08 start=(26,14) failures=2 ... targets=Merchant 4|Woman 1
SURVEY_FAILURE_START map=0x08 start=(1,14) failures=1 ... state_issues=1 targets=Woman 3
```

The `(28,2)` Guard initially logged as `no_route_found` but was reclassified to
`gated_or_isolated_region` by the isolated-start cluster logic.

## Woman 3 State Issue

The only non-isolation failure was `Woman 3`:

```text
SURVEY_RESULT run=2 map=0x08 target_id=npc_12 target_name="Woman 3" start=(1,14) target=(4,7) path_mode=adjacent path_found=true path_length=9 movement_succeeded=false final=(1,12) failure_class=command_timing_or_state_issue blocked_events=0 suspected_tiles=- blocked_tiles=- retry_succeeded=false alternate_mode=direct alternate_path_found=false reason=route_drift_off_path
```

Planned route:

```text
pathfind chosen adj=(4,8) path=1 north, 2 east, 2 north, 1 east, 3 north
step 1: (1,13) dir=north
step 2: (2,13) dir=east
```

Observed movement:

```text
auto_step complete dir=up from=(1,14) to=(1,13) frames=8 ... queued_route=true
auto_step route drift not on queued path from=(1,13) current=(1,12) next_index=2
auto_step clear_route: off-path drift from=(1,13) current=(1,12) next_index=2 source=route_settle_catchup
```

Interpretation: this is the same northward overshoot pattern seen before, but
the route-drift guard is now doing the right thing. It cancels the stale route
before bogus blocker evidence can be exported. The survey then continued
successfully from `(1,12)` to later targets, so this is not map data.

## Patch Applied

Do not patch `map_reader.lua` for this run.

`map_survey.lua` now retries a queued route once when it is cancelled with
`reason=route_drift_off_path`, has no blocked/suspected tiles, and stays on
the same map. The target is requeued as `route_drift_retry` and the retry
starts from the current live position.

`test_map_survey.lua` now covers this with
`route_drift_cancellation_is_retried_once_from_live_position`.

Secondary option: add a focused `auto_step.lua` regression test for a queued
route like `{"up", "right"}` where the first `up` completes quickly and live
position drifts one extra tile north during settle. Avoid lowering the global
inject limit until that is tested, because the current 12-frame window is still
helping open-floor turn re-presses complete reliably.

After the retry patch, run one more parked Brecconary survey. Expected healthy
baseline: no suspected engine blockers, no movement failures, no strong
candidates, and only the known gated/isolated clusters unless a route-drift
retry exposes a new execution issue.
