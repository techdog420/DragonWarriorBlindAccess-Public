# Map04 Post-Exit-Reload West Boundary Follow-up — 2026-04-26

## Summary

After the south-gate door exclusion and south-gate wall patch were reloaded, the
fresh parked object survey completed cleanly:

```text
SURVEY_START run=1 map=0x04 start=(10,10) targets=28 mode=objects npc_mode=park_npcs runtime_blocks=0
SURVEY_COMPLETE run=1 map=0x04 targets=28 successes=14 failures=14 no_route=0 gated_or_isolated=14 movement_failed=0 suspected_engine_blocked=0 state_issues=0 adjacency_issues=0
```

Important confirmations:

- `door_10_30` no longer appears in the default survey target set.
- `exit_11_29` still runs safely and completed from `(11,27)` to final `(11,28)`.
- The south-gate wall churn disappeared; no `(16..20,28/29)` state issue cluster
  appeared in this run.

The remaining failures are clean gated/isolated regions:

- From `(5,26)`: 11 gated targets.
- From `(14,4)`: 3 gated chest targets.

## Candidate Follow-up

Post-survey reports showed three reroute candidates:

```text
3,6 south count=3 retry_successes=1 confidence=high
4,7 west  count=3 retry_successes=1 confidence=high
4,6 north count=1 retry_successes=1 confidence=high
```

Split direct probes with runtime blocks cleared and NPCs frozen produced:

```text
probe_edge:3,7,UP    -> moved   final=(3,6)
probe_edge:3,7,RIGHT -> blocked final=(3,7) blocked_despite_open_preview
probe_edge:4,5,DOWN  -> moved   final=(4,6)
```

Only `(4,7)` approached from the west is a verified new static map-data hole.
`(3,6) south` and `(4,6) north` were reroute-only false positives and should
not be modeled.

Patch applied:

```lua
["4,7"] = {east = true, west = true, south = true},
```

## Garbage-Data Guard

Root issue: survey candidate reporting treated successful reroute evidence as
`high` and pasteable even when the route eventually succeeded and no focused
repro had confirmed the implicated seam. That allowed `(3,6)` and `(4,6)` to
look like map-data candidates.

Code changes:

- `route_manager.get_seam_observation(map_id, x, y, approach)` now exposes seam
  counts and last source/result.
- `map_survey.lua` downgrades candidates with mixed moved/blocked seam evidence
  to `needs_repro`.
- Reroute-only candidates with no terminal failure no longer appear in strong
  reports or directional exports unless a direct/manual probe confirms the
  approach.
- For reroute-only candidates with one direct-confirmed approach, directional
  export includes only the confirmed approach.

## Validation

Passed:

```text
luac -p route_manager.lua map_survey.lua map_reader.lua test_map_survey.lua test_map_reader.lua
lua test_map_survey.lua  # 37/37
lua test_route_manager.lua  # 13/13
lua -e direct map04 assertions  # 4,7 west true; 3,6 and 4,6 unmodeled
```

`lua test_map_reader.lua` still has the same three unrelated pre-existing
failures:

1. `(12,19)` south expected open but currently modeled blocked.
2. `(16,16)` east expected blocked but currently missing.
3. Brecconary `8,27` test expects a directional entry that is absent.

## Next Resume Point

Reload Lua before the next survey so the new `(4,7) west=true` block and
reroute-only candidate guard are active. A follow-up `report_candidate_suggestions`
after reload/direct repro should no longer offer `(3,6)` or `(4,6)` as
pasteable map-data suggestions.
