# Map04 Exit Walk + South Gate Wall Follow-up — 2026-04-26

## Summary

The user reported that a restarted map04 parked survey walked through the castle
exit. The old partial run had enough evidence to diagnose and patch two issues:

1. The default object survey included the south-gate `Door` at `(10,30)`.
   Targeting it from `(11,27)` routed to `(10,29)` and then sent a down input,
   changing map `0x04 -> 0x01`:

   ```text
   SURVEY_ATTEMPT run=1 map=0x04 ... target_id=door_10_30 ... start=(11,27) target=(10,30) mode=adjacent path_length=3
   EVENT: map change -> 0x01 (World Map)
   SURVEY_RESULT ... target_id=door_10_30 ... movement_succeeded=false final=(43,43) failure_class=command_timing_or_state_issue ... reason=map_changed
   ```

   Patch: `objects.lua` keeps `door_10_30` for explicit navigation, but marks it
   `survey_exclude=true`. `map_survey.lua` now skips `survey_exclude` objects in
   default object surveys. The `Exit to World Map` object remains available; it
   landed at `(11,29)` safely in the restarted run.

2. The restarted survey then got trapped against an unmodeled south-gate wall
   band. It was stopped manually to prevent more noisy candidate churn.

## South Gate Wall Evidence

The stopped partial `run=3` produced repeated candidates:

```text
17,28 south count=6 targets=4 failure_count=1 state_issues=3 confidence=high
18,28 south count=6 targets=4 failure_count=1 state_issues=3 confidence=high
19,28 south count=6 targets=4 failure_count=1 state_issues=3 confidence=high
20,29 west  count=6 targets=4 failure_count=1 state_issues=3 confidence=high
16,28 south count=5 targets=3 failure_count=0 state_issues=3 confidence=needs_repro
```

Runtime blocks were cleared before split direct probes. All five edges then
blocked despite open model previews:

```text
probe_edge:17,29,UP    -> (17,28) south blocked_despite_open_preview
probe_edge:18,29,UP    -> (18,28) south blocked_despite_open_preview
probe_edge:19,29,UP    -> (19,28) south blocked_despite_open_preview
probe_edge:19,29,RIGHT -> (20,29) west  blocked_despite_open_preview
probe_edge:16,29,UP    -> (16,28) south blocked_despite_open_preview
```

Patch applied in `map_reader.lua`:

```lua
["16,28"] = {south = true},
["17,28"] = {south = true},
["18,28"] = {south = true},
["19,28"] = {south = true},
["20,29"] = {west = true},
```

`test_map_reader.lua` now has `tantegel_castle_south_gate_exit_wall_blocks_are_modeled`.

## Validation

Passed:

```text
luac -p objects.lua map_survey.lua map_reader.lua test_map_survey.lua test_map_reader.lua
lua test_map_survey.lua  # 35/35
lua test_auto_step.lua   # 10/10
```

`lua test_map_reader.lua` now runs 14 tests. The new south-gate wall test passes.
The same 3 unrelated pre-existing failures remain:

1. `(12,19)` south expected open but currently modeled blocked.
2. `(16,16)` east expected blocked but currently missing.
3. Brecconary `8,27` test expects a directional entry that is absent.

## Next Resume Point

Reload the Lua script before the next parked survey. A fresh default object survey
should now have 28 targets instead of 29 because `door_10_30` is excluded. If the
run starts near the south gate again, the newly modeled wall band should prevent
the repeated reroute churn around `(16..20,28/29)`.
