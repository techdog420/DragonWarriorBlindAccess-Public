# Brecconary Failed-Cluster Audit — 2026-04-27

## Summary

Implemented the focused audit plan for the latest Brecconary parked survey
failures. The eight remaining failed targets still look blocked by existing
map design/model data, not by a new false blocker or a live movement failure.

Latest survey findings remained:

```text
SURVEY_FINDINGS map=0x08 run=1 failed_targets=8 failure_starts=4 strong_reroute_candidates=0
RUNTIME_BLOCKS map=0x08 none
```

All eight failures are `gated_or_isolated_region`; there are still zero
movement failures, zero suspected engine-blocked tiles, zero state issues, and
no strong reroute candidates.

## Live State

After the audit, the emulator was restored to:

```text
POSITION: map=0x08(Brecconary) x=20 y=15
RUNTIME_BLOCKS map=0x08 none
NPCs unfrozen
```

## Failure Starts Audited

### Start `(28,15)`

Targets from the latest survey:

- `Person` at `(20,10)`
- `Old Man` at `(24,10)`
- `Merchant` at `(25,25)`
- `Merchant` at `(5,4)`

Representative path diagnostics:

- `debug_pathfind_adjacent:20,10` from `(28,15)` returned no path.
- `debug_pathfind_adjacent:25,25` from `(28,15)` returned no path.
- The `(20,10)` search frontier dies on already-modeled center-east/NE
  blockers, including existing Brecconary entries around `(18,10)`,
  `(18,11)`, `(18,12)`, `(19,12)`, and `(25,12)`.
- `map_reader.lua` already documents this area as building wall/barrier data,
  and `test_map_reader.lua` already asserts key faces such as
  `(18,12) south` and `(25,12) south`.
- The `(25,25)` route had only `(24,25)` as nominally adjacent-walkable; the
  search still could not reach that region and hit the known center/southeast
  barrier bands.

No new blocker candidate was produced.

### Start `(9,15)`

Targets from the latest survey:

- `Woman 1` at `(24,4)` in the latest findings report; a later live preflight
  saw the same object at `(24,5)`.
- `Merchant 3` at `(10,21)`

Audit command:

```text
report_survey_start:retry_failed,park_npcs
debug_pathfind_adjacent:24,5
```

Result:

```text
SURVEY_START_STATUS map=0x08 mode=retry_failed start=(9,15) targets=8
reachable_area=128 open_exit_count=4 open_exits=north|south|west|east
status=isolated_start reachable_targets=0 unreachable_targets=8
isolation_reason=low_target_coverage npc_mode=park_npcs
```

The individual path check to `(24,5)` also returned no path. The preflight
checked all eight failed targets from this start and found none reachable.

### Start `(4,8)`

Target from the latest survey:

- `Guard 4` at `(4,26)`

Audit command:

```text
report_survey_start:retry_failed,park_npcs
debug_pathfind_adjacent:4,26
```

Result:

```text
SURVEY_START_STATUS map=0x08 mode=retry_failed start=(4,8) targets=8
reachable_area=128 open_exit_count=3 open_exits=south|west|east
blocked_exits=north:tile status=isolated_start reachable_targets=0
unreachable_targets=8 isolation_reason=low_target_coverage npc_mode=park_npcs
```

The direct path diagnostic to `(4,26)` returned no path, with adjacent probes
showing no movement failure or suspected engine-blocked tile.

### Start `(20,13)`

Target from the latest survey:

- `Person 5` at `(20,23)`

Audit command:

```text
report_survey_start:retry_failed,park_npcs
debug_pathfind_adjacent:20,23
```

Result:

```text
SURVEY_START_STATUS map=0x08 mode=retry_failed start=(20,13) targets=8
reachable_area=128 open_exit_count=3 open_exits=south|west|east
blocked_exits=north:tile status=isolated_start reachable_targets=0
unreachable_targets=8 isolation_reason=low_target_coverage npc_mode=park_npcs
```

The individual check to `(20,23)` returned no path. Earlier search-log review
showed the route frontier dying on already-modeled center/southeast barriers,
including the `18,21`, `19,20`, `19,21`, `20,19`, `20,20`, `21,18`, `21,20`,
and `22,20` cluster already asserted in `test_map_reader.lua`.

## Conclusion

The current evidence does not justify a `map_reader.lua` patch. The remaining
targets are clean gated/isolated regions under existing Brecconary map data.
There is no runtime block, no survey candidate, and no suspicious seam that
needs immediate direct probing.

Best next steps:

- Stop Brecconary blocker hunting for now unless a future survey produces
  `movement_failed`, `suspected_engine_blocked`, or a strong candidate.
- If the goal is simply to keep measuring survey stability, reload Lua and run
  another parked survey from the restored central position `(20,15)`.
- Avoid using aggregate `retry_failed` as blocker evidence from any isolated
  pocket; use it only as a preflight signal, then inspect specific clusters if
  a new failure class appears.
