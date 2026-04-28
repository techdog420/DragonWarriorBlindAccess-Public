# Handoff 2026-04-26 - Map 0x04 post-catchup survey follow-up

## Latest survey result

The user ran another reloaded parked-object survey on map `0x04`.

```text
SURVEY_COMPLETE run=1 map=0x04 targets=28 successes=13 failures=15 no_route=0 gated_or_isolated=15 movement_failed=0 suspected_engine_blocked=0 state_issues=0 adjacency_issues=0
```

Failure starts:

```text
start=(5,29)  failures=7  targets=Guard|Guard|Guard|Old Man|Old Man|Person|Stairs Down to Treasure Room
start=(3,8)   failures=4  targets=Chest|Chest|Chest|Chest
start=(11,28) failures=3  targets=Guard 5|Merchant 3|Woman 2
start=(10,27) failures=1  targets=Stairs Down to Throne Room
```

Interpretation: the survey failures are still clean gated/isolated regions.
There is no evidence here for a new permanent map-data patch.

Post-run reports:

```text
SURVEY_STRONG_CANDIDATES map=0x04 none
SURVEY_CANDIDATE_SUGGESTIONS map=0x04 none
PATH_STATE ... runtime_count=0
SURVEY_CANDIDATE map=0x04 x=4 y=6 key=4,6 count=1 targets=1 retry_successes=1 failure_count=0 state_issues=0 confidence=needs_repro approaches=north
```

The candidate guard is working: `(4,6) north` remains diagnostic-only
`needs_repro` and is not exported or suggested as pasteable data. This seam was
previously direct-probed as passable with `(4,5)->DOWN`, so do not patch it
unless a fresh focused repro blocks outside the queued-route path.

## Route drift issue found

The latest run still reproduced queued-route drift into known walls. Example:

```text
auto_step complete dir=right from=(3,8) to=(4,8) ... queued_route=true
auto_step begin_step dir=right from=(5,8) ...
auto_step blocked dir=right from=(5,8) ...
SEAM_OBSERVATION map=0x04 cell=(6,8) approach=west result=blocked source=queued_route_block
SURVEY_RESULT ... target_id=npc_16 ... blocked_events=1 blocked_tiles=6,8 retry_succeeded=true
```

The route had advanced physically from `(4,8)` to `(5,8)` during the survey
settle window, but the queued route had not consumed that drifted second step.
It then re-issued the stale second `right` command from `(5,8)`, causing a false
block against `(6,8)`.

The same pattern appeared earlier in a long westward route:

```text
auto_step complete dir=left from=(20,4) to=(19,4)
auto_step begin_step dir=left from=(18,4)
```

## Patch

`auto_step.lua` now tracks the last completed queued-route tile and consumes
small position drift that exactly matches the next queued route step(s). When
catch-up happens it publishes a normal `route_step_completed` event with
`source=route_settle_catchup`, advances `route_index`, and restarts the settle
gap before issuing the next input.

This should prevent the stale-command pattern where a route physically reaches
the next planned tile during settle but the queue replays that step anyway.

`test_auto_step.lua` adds coverage for this case: route
`right, right, down` drifts from `(4,1)` to `(5,1)` during settle, consumes the
second `right`, and resumes with `down` without re-pressing `right`.

## Verification

Passed:

```text
luac -p auto_step.lua test_auto_step.lua map_survey.lua route_manager.lua
lua test_auto_step.lua       # 11/11
lua test_map_survey.lua      # 37/37
lua test_route_manager.lua   # 13/13
```

`lua test_map_reader.lua` still has the same three pre-existing failures:

```text
(12,19) south expected open but modeled blocked
(16,16) east expected blocked but missing
Brecconary 8,27 expected directional entry absent
```

## Next step

Reload Lua and rerun `survey_objects:park_npcs`. Expected improvement: no
queued-route false block at `(6,8)` after the `(3,8)->(4,8)` step, and fewer
same-direction stale-step skips in long corridors. `(4,6) north` may still need
watching as a separate route-timing false block; it should remain
`needs_repro` unless directly confirmed.
