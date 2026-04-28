# Map04 Reloaded Survey Follow-up — 2026-04-26

## Summary

The user ran a fresh parked-object survey after reloading the script. This run
completed quietly from the probe-suite perspective:

```text
SURVEY_COMPLETE run=1 map=0x04 targets=29 successes=14 failures=15 no_route=0 gated_or_isolated=15 movement_failed=0 suspected_engine_blocked=0 state_issues=0 adjacency_issues=0
```

This confirms the earlier garbage-data guards are helping: the east connector
band was not re-suggested, and there were no state/timing or adjacency failures.

## Stranded-start behavior

The prior stranded-start fix worked. The survey deferred trimming whenever the
current start still had reachable continuation targets:

```text
SURVEY_STRANDED_SCAN_DEFER ... start=(3,8) pending_targets=21 reachable_targets=7 ...
SURVEY_STRANDED_SCAN_DEFER ... start=(9,22) pending_targets=18 reachable_targets=6 ...
SURVEY_STRANDED_SCAN_DEFER ... start=(10,27) pending_targets=15 reachable_targets=4 ...
```

The final mass skip happened only after reaching `(5,24)`, where the remaining
pending targets had no reachable continuations:

```text
SURVEY_STRANDED_SCAN run=1 map=0x04 start=(5,24) pending_targets=10 reachable_targets=0 skipped_targets=10 reachable_area=128 open_exit_count=4 latest_target_id=npc_15 reason=isolated_start_cluster
```

## New verified cell

The survey produced one candidate:

```text
SURVEY_CANDIDATE map=0x04 x=6 y=13 key=6,13 count=1 targets=1 retry_successes=1 failure_count=0 state_issues=0 confidence=high approaches=west
```

Direct split-command probes verified it:

1. `freeze_npcs teleport_to:5,13 report_position inspect_move:5,13,RIGHT`
   confirmed the planner still modeled `(5,13)->(6,13)` as open.
2. `probe_edge:5,13,RIGHT` blocked with:
   ```text
   EDGE_PROBE_MODEL_MISMATCH ... kind=blocked_despite_open_preview ... static_approach_blocked=false runtime_approach_blocked=false
   SEAM_OBSERVATION map=0x04 cell=(6,13) approach=west result=blocked blocked=2 moved=0 classification=blocked_only source=manual_block
   ```
3. A second fresh teleport and `probe_edge:5,13,RIGHT` blocked again and promoted:
   ```text
   runtime block: map=0x04 cell=(6,13) approach=west source=seam_confirm:manual_block blocked=3 moved=0
   SEAM_OBSERVATION map=0x04 cell=(6,13) approach=west result=blocked blocked=3 moved=0 classification=confirmed_blocked source=manual_block
   ```

Patch applied:

```lua
["6,13"] = {east = true, west = true}
```

`test_map_reader.lua` now asserts both `east` and `west` approaches for `6,13`.

## Validation

Passed:

```text
luac -p map_reader.lua test_map_reader.lua
```

`lua test_map_reader.lua` still has the same 3 pre-existing unrelated failures:

1. `(12,19)` south expected open but currently modeled blocked.
2. `(16,16)` east expected blocked but currently missing.
3. Brecconary `8,27` test expects a directional entry that is absent.

The new `6,13 west` assertion passes.

## Next resume point

Reload the Lua script before the next parked survey so the new static
`6,13 west=true` model is active. Then rerun `survey_objects:park_npcs` from the
same map04 baseline and compare whether the `6,13` reroute disappears and whether
the 14/15 result changes.
