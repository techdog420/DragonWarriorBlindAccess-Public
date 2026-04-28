# Handoff — 2026-04-28 Brecconary route drift after transient retry

## Summary

Latest completed Brecconary survey:

`SURVEY_COMPLETE run=1 map=0x08 targets=21 successes=9 failures=12 no_route=0 gated_or_isolated=11 movement_failed=0 suspected_engine_blocked=0 state_issues=1 adjacency_issues=0`

Failure starts:
- `(20,15)`: 5 failures, targets `Guard 2`, `Old Man 2`, `Person 2`, `Person 5`, `Woman 2`
- `(28,2)`: 3 failures, targets `Merchant`, `Merchant`, `Person`
- `(4,8)`: 2 failures, targets `Guard 4`, `Old Man`
- `(14,8)`: 2 failures, targets `Merchant 3`, `Woman 1`

Follow-up survey findings reported:
- `SURVEY_STRONG_CANDIDATES map=0x08 none`
- `SURVEY_CANDIDATE_SUGGESTIONS map=0x08 none`
- `RUNTIME_BLOCKS map=0x08 none`

Live cleanup after analysis:
- Sent `unfreeze_npcs teleport_to:20,15 report_position report_runtime_blocks`
- Confirmed `POSITION: map=0x08(Brecconary) x=20 y=15`
- Confirmed `RUNTIME_BLOCKS map=0x08 none`

No permanent `map_reader.lua` block patch is justified from this run.

## Key Finding

The only actionable failure was not blocker evidence. It was survey harness retry accounting:

`SURVEY_RESULT run=1 map=0x08 target_id=npc_0 target_type=npc target_name="Old Man" start=(4,8) target=(17,22) path_mode=adjacent path_found=true path_length=30 movement_succeeded=false final=(4,10) failure_class=command_timing_or_state_issue blocked_events=0 suspected_tiles=- blocked_tiles=- retry_succeeded=false alternate_mode=direct alternate_path_found=false reason=route_drift_off_path`

Trace:
- Frame `03004`: `Old Man` first got `AUTO_WALK: no path` and was requeued as `transient_no_path retry=1`.
- Frame `20084` onward: the retry found a real adjacent path from `(4,8)` to `(16,22)`, length 30.
- The route stepped from `(4,8)` to `(4,9)`, then drifted to `(4,10)` during settle.
- `auto_step` correctly cancelled the route as `route_drift_off_path` instead of synthesizing blocker evidence.
- `map_survey.lua` did not requeue it as `route_drift_retry` because the single per-target retry slot had already been consumed by `transient_no_path`.

Conclusion: the failed target is a false survey harness blocker/state issue, not a new hidden Brecconary engine block.

## Patch

`map_survey.lua` now tracks retry counts per reason as well as total per target:
- Adds `SURVEY_MAX_TOTAL_RETRIES_PER_TARGET = 2`.
- Adds `survey_state.retry_reason_counts`.
- Keeps `transient_no_path` conservative: at most once, and only before other retries.
- Allows one `route_drift_retry` after a prior `transient_no_path` retry, capped by total retries.
- Keeps `timing_orphaned_route` conservative.

`test_map_survey.lua` adds `route_drift_retry_is_still_allowed_after_transient_no_path_retry`, which simulates:
1. transient no path
2. successful queued route that drifts off path
3. route-drift retry from the live drifted position
4. final success with no failed target

## Validation

Passed:
- `luac -p map_survey.lua test_map_survey.lua`
- `lua test_map_survey.lua` — 40/40 tests
- `git diff --check -- map_survey.lua test_map_survey.lua`

## Best Resume Point

Reload the full Lua script before the next survey; the running emulator will not have this retry-accounting patch until reload.

Then run the usual parked Brecconary survey from the restored central position `(20,15)`. Expected improvement: the `Old Man` case should get a second, reason-specific retry if it repeats the same transient-no-path then route-drift sequence. Continue to require real movement failures, suspected engine-blocked events, or strong candidates before changing permanent map data.
