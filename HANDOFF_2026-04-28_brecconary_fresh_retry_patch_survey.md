# Handoff - 2026-04-28 Brecconary fresh retry-patch survey

## Summary

Latest fresh parked Brecconary survey after reloading the route-drift retry
patch completed:

`SURVEY_COMPLETE run=1 map=0x08 targets=21 successes=12 failures=9 no_route=0 gated_or_isolated=9 movement_failed=0 suspected_engine_blocked=0 state_issues=0 adjacency_issues=0`

This run produced no permanent map-blocker evidence.

Follow-up status commands:

`report_position report_runtime_blocks report_survey_findings report_survey_start:retry_failed,park_npcs`

Confirmed:
- `POSITION: map=0x08(Brecconary) x=10 y=25`
- `RUNTIME_BLOCKS map=0x08 none`
- `SURVEY_STRONG_CANDIDATES map=0x08 none`
- `SURVEY_FINDINGS map=0x08 run=1 failed_targets=9 failure_starts=4 strong_reroute_candidates=0`
- `SURVEY_START_STATUS map=0x08 mode=retry_failed start=(10,25) targets=9 ... status=isolated_start ... reachable_targets=0 unreachable_targets=9 isolation_reason=low_target_coverage`

NPC parking was restored at survey completion:

`SURVEY_NPC_PARK_RESTORE run=1 map=0x08 restored=true restored_slots=20 reason=complete`

## Live Retry-Patch Validation

The previous retry-accounting patch behaved as intended in live survey output.

Route-drift retries fired:
- `npc_8` at frame `24104`, later succeeded as `Guard` from `(10,2)` to `(22,14)`.
- `npc_6` at frame `24152`, later succeeded as `Guard` from `(22,13)` to `(28,15)`.
- `npc_0` at frame `39730`, later succeeded as `Old Man` from `(4,8)` to `(10,3)`.

The old "transient no path consumes the only retry slot, then route drift fails
without retry" problem did not recur in this run.

## Failure Starts

Current failed targets are all clean gated/isolated failures:

- `(28,14)`: 5 failures, targets `Guard`, `Old Man`, `Person`, `Person`, `Woman`
- `(13,10)`: 2 failures, targets `Merchant 3`, `Merchant 4`
- `(4,8)`: 1 failure, target `Merchant 2`
- `(20,13)`: 1 failure, target `Person 5`

The final live position is `(10,25)`, but this is a poor retry start. The
failed-target preflight from `(10,25)` reports `reachable_targets=0/9` and
`isolation_reason=low_target_coverage`.

## Conclusion

No `map_reader.lua` patch is justified from this survey.

Best next step:
- Do not run `retry_failed` from `(10,25)`.
- If continuing Brecconary blocker hunting, relocate deliberately to a useful
  failed-cluster start and use focused preflight/path debug commands before any
  movement probes.
- Continue requiring direct evidence before permanent map-data changes:
  `movement_failed`, `suspected_engine_blocked`, or strong candidate output.
