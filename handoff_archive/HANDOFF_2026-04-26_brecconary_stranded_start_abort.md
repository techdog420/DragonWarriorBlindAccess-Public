# Handoff: Brecconary Stranded Start Abort - 2026-04-26

## Latest Survey

After reloading the drift-cancellation patch, the next parked Brecconary survey
completed almost entirely as failures:

```text
SURVEY_START run=1 map=0x08 start=(9,24) targets=21 mode=objects npc_mode=park_npcs runtime_blocks=0
SURVEY_COMPLETE run=1 map=0x08 targets=21 successes=1 failures=20 no_route=0 gated_or_isolated=20 movement_failed=0 suspected_engine_blocked=0 state_issues=0 adjacency_issues=0
```

This was not a map-data regression and not caused by the new route-drift
cancellation. The survey started inside the small southwest guard pocket at
`(9,24)`. From there, only the nearby guard target was reachable:

```text
SURVEY_STRANDED_SCAN run=1 map=0x08 start=(9,24) pending_targets=20 reachable_targets=1 skipped_targets=19 reachable_area=13 open_exit_count=3 latest_target_id=npc_16 reason=isolated_start_cluster
```

The one successful target was the local guard at `(10,26)`:

```text
SURVEY_RESULT run=1 map=0x08 target_id=npc_19 target_name="Guard" start=(9,24) target=(10,26) path_found=true path_length=2 movement_succeeded=true final=(10,25)
```

No blocked events, runtime blocks, or candidate exports were produced.

## Patch

`map_survey.lua` now rejects broad object surveys that start in a pocket where
almost none of the targets are reachable. The previous start guard only looked
at reachable area and immediate open-exit count; `(9,24)` had three open exits,
so it slipped through despite reaching only one useful target.

New behavior:

```text
SURVEY_START_ABORT ... reason=isolated_start ... isolation_reason=low_target_coverage reachable_targets=1 unreachable_targets=N
```

The guard is intentionally scoped to larger surveys (`target_count >= 8`) so
small focused/continuation surveys can still run when they have one local
reachable target.

`test_map_survey.lua` covers the Brecconary-like case:

- reachable area above the hard tiny-area threshold
- three open exits
- eight targets total
- only one reachable target
- survey aborts before generating a wall of `stranded_start_unreachable` results

## Validation

Passed:

```text
luac -p map_survey.lua test_map_survey.lua
lua test_map_survey.lua        # 38/38
luac -p auto_step.lua test_auto_step.lua map_survey.lua test_map_survey.lua
lua test_auto_step.lua         # 17/17
git diff --check -- auto_step.lua test_auto_step.lua map_survey.lua test_map_survey.lua session_handoff.md
```

## Live State

The live player was moved out of the guard pocket to a broader town start:

```text
POSITION: map=0x08(Brecconary) x=4 y=17
RUNTIME_BLOCKS map=0x08 none
PATH_STATE target=nil map=0x08 runtime_count=0
SURVEY_START_STATUS map=0x08 mode=objects start=(4,17) targets=21 reachable_area=128 open_exit_count=3 open_exits=north|west|east blocked_exits=south:tile status=viable
```

NPCs were unfrozen and runtime blocks were clear.

## Next Resume Point

Reload Lua before the next parked Brecconary survey so both recent tool guards
are active:

- unmatched queued-route drift cancels with `route_drift_off_path`
- broad surveys from stranded pockets abort with `low_target_coverage`

The next parked survey should be started from `(4,17)` or another open-town
position, not from the southwest guard pocket.
