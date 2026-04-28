# Handoff 2026-04-26 - Map 0x04 quiet survey stranded-skip fix

## Fresh survey after full east-connector patch

The user reloaded and ran another parked-NPC survey on map `0x04`.

Result:

```text
SURVEY_COMPLETE run=1 map=0x04 targets=29 successes=15 failures=14 no_route=0 gated_or_isolated=14 movement_failed=0 suspected_engine_blocked=0 state_issues=0 adjacency_issues=0
```

This is quieter and cleaner than the previous runs:

- no `suspected_engine_blocked`
- no `state_issues`
- no repeated `20,6/21,4/21,5` runtime-block churn
- all failures came from one start, `(3,8)`

## Actual issue found

The survey harness prematurely fired the stranded-start shortcut:

```text
SURVEY_ISOLATED_START ... start=(3,8) no_path_events=2 distinct_targets=2 reachable_area=128 open_exit_count=2 ...
```

It then marked 14 pending targets as `gated_or_isolated_region` from `(3,8)`.
But immediately afterward, the same scan found reachable continuation targets
from `(3,8)`, and the survey successfully walked out through one of them:

```text
pathfind_to_adjacent ... start=(3,8) goal=(4,18)
pathfind chosen adj=(4,17) path=2 east, 9 south, 1 west
SURVEY_RESULT ... target_id=npc_4 ... movement_succeeded=true final=(4,17)
```

Interpretation:

- this is not new map data
- this is not an auto-step blocker
- it is a survey classification/queue-trimming bug

## Patch applied

`map_survey.lua` now makes `skip_stranded_start_remainder()` conservative for
large connected areas. If any reachable continuation target remains, it logs:

```text
SURVEY_STRANDED_SCAN_DEFER ... reason=reachable_continuations_pending
```

and does not trim pending targets yet.

The old trimming behavior still applies once no reachable continuations remain.

`test_map_survey.lua` was updated so the stranded-start test covers this safer
behavior: reachable continuations get a chance to move the survey before
unreachable targets are skipped.

## Validation

Passed:

```text
luac -p map_survey.lua test_map_survey.lua
lua test_map_survey.lua    # 34/34
lua test_auto_step.lua     # 10/10
```

`lua test_map_reader.lua` still has the same three unrelated pre-existing
failures, and the east-connector regression still passes.

## Next step

Reload the full Lua script in FCEUX and rerun `survey_objects:park_npcs`.
Expected change: the survey should no longer mass-fail the 14 targets from
`(3,8)` while reachable continuation targets remain.
