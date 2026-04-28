# Map04 New Survey + Auto-Step Overshoot Follow-up — 2026-04-26

## Survey Result

The latest reloaded parked survey completed:

```text
SURVEY_START run=1 map=0x04 start=(10,10) targets=28 mode=objects npc_mode=park_npcs runtime_blocks=0
SURVEY_COMPLETE run=1 map=0x04 targets=28 successes=13 failures=15 no_route=0 gated_or_isolated=15 movement_failed=0 suspected_engine_blocked=0 state_issues=0 adjacency_issues=0
```

Post-survey report:

```text
SURVEY_STRONG_CANDIDATES map=0x04 none
SURVEY_CANDIDATES map=0x04 none
SURVEY_CANDIDATE_SUGGESTIONS map=0x04 none
PATH_STATE ... runtime_count=0
```

Interpretation: no new map-data candidates. The candidate guard added in the
previous follow-up worked: route repairs against known/static blocks did not
produce pasteable survey garbage.

## Failure Buckets

The failures are all clean `gated_or_isolated_region`:

```text
start=(7,29) failures=11 targets=Guard|Guard|Guard|Guard|Guard 5|Merchant|Old Man|Old Man 2|Stairs Down to Throne Room|Stairs Down to Treasure Room|Woman
start=(3,8) failures=3 targets=Chest|Chest|Chest
start=(9,20) failures=1 target=Chest
```

This differs from the previous 14/14 run by one extra gated chest failure
(`chest_1` at `(1,15)`, failed from `(9,20)`). It is still a planner no-path,
not a movement/state failure.

## Overshoot Evidence

The run exposed route execution overshoot. During the route from `(3,8)` to
Person 1, auto-step completed a right step:

```text
auto_step complete dir=right from=(3,8) to=(4,8) ... queued_route=true
```

The next queued step then began from `(5,8)` instead of `(4,8)`:

```text
auto_step begin_step dir=right from=(5,8)
auto_step blocked dir=right from=(5,8)
SEAM_OBSERVATION map=0x04 cell=(6,8) approach=west result=blocked
```

That means the engine had already committed a second tile before the route queue
advanced. Similar successful-reroute blocks against known/static seams appeared
at `(13,21)` and `(12,19)`, but no survey candidates were emitted.

## Patch

`auto_step.lua` now sends a neutral D-pad frame on the same update where it
observes step completion, before the existing post-step neutral window. This
closes the gap where a previous injected direction could commit the next tile
before queued-route settle frames begin.

Touched:

- `auto_step.lua`
- `test_auto_step.lua`

## Validation

Passed:

```text
luac -p auto_step.lua test_auto_step.lua map_survey.lua route_manager.lua
lua test_auto_step.lua      # 10/10
lua test_map_survey.lua     # 37/37
lua test_route_manager.lua  # 13/13
```

## Next Resume Point

Reload Lua before the next survey. Expected improvement: fewer successful-route
reroutes into already-known static blocks such as `(6,8)`, `(13,21)`, and
`(12,19)`. If those still recur after reload, inspect route queue advancement
and auto-step position reconciliation rather than adding map-data blocks.
