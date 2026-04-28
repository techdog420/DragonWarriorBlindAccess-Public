# Handoff: Brecconary 8,27 South and Survey Cleanup - 2026-04-26

## Latest Survey

The fresh parked Brecconary survey completed cleanly enough to analyze:

```text
SURVEY_COMPLETE run=1 map=0x08 targets=21 successes=13 failures=8 no_route=0 gated_or_isolated=6 movement_failed=0 suspected_engine_blocked=0 state_issues=2 adjacency_issues=0
SURVEY_STRONG_CANDIDATES map=0x08 none
SURVEY_CANDIDATE_SUGGESTIONS map=0x08 none
SURVEY_CANDIDATE_EXPORT map=0x08 count=0 skipped_diagnostics=2
RUNTIME_BLOCKS map=0x08 none
```

Six failures are still clean `gated_or_isolated_region` targets. The remaining
two state issues were:

- `Guard 4` from `(14,16)` to `(4,26)`, with repeated `10,27|8,27` south hits.
- `Old Man 1` from `(13,25)` to `(13,1)`, with no blocked events and reason
  `route_inactive_without_completion`.

## Direct Probe Findings

`10,27 south` remains noisy/open:

```text
EDGE_PROBE_RESULT map=0x08 from=(10,28) dir=up dest=(10,27) status=moved
SEAM_OBSERVATION map=0x08 cell=(10,27) approach=south result=moved ... classification=noisy
```

Do not add a `south` blocker to `10,27`; the existing model remains
`["10,27"] = {north = true}`.

`8,27 south` is now confirmed blocked:

```text
EDGE_PROBE_RESULT map=0x08 from=(8,28) dir=up dest=(8,27) status=blocked ... effective_passable=true
EDGE_PROBE_MODEL_MISMATCH map=0x08 from=(8,28) dir=up dest=(8,27) kind=blocked_despite_open_preview
POSITION after simulate_raw_input:UP,90: map=0x08 x=8 y=28
EDGE_PROBE_RESULT map=0x08 from=(8,27) dir=down dest=(8,28) status=moved
```

`map_reader.lua` now models:

```lua
["8,27"] = {south = true}
```

This is directional only. The reverse `(8,27)->DOWN` remains open.

## Survey Tooling Fixes

The `Old Man 1` route exposed a remaining queued-route cleanup bug:

```text
auto_step complete dir=up from=(5,10) to=(5,9)
auto_step route drift not on queued path from=(5,9) current=(5,10) next_index=29
auto_step clear_route: live direction input interrupted queued route
SURVEY_RESULT ... reason=route_inactive_without_completion
```

`auto_step.lua` now treats the short post-step release window as route-owned
when a queued route is active. It sends neutral frames for that window even if
`joypad.read()` still reports a direction, so a stale route-owned direction
cannot orphan the route. Physical/manual direction input can still cancel after
that tiny release window.

`debug_tools.lua` also now marks the neutral release frame after
`simulate_raw_input` as raw. This keeps auto-step from observing the synthetic
raw-input release edge and creating bogus manual-block evidence after a raw
probe.

## Validation

Passed:

```text
luac -p auto_step.lua test_auto_step.lua debug_tools.lua map_reader.lua test_map_reader.lua
lua test_auto_step.lua        # 16/16
git diff --check -- auto_step.lua test_auto_step.lua debug_tools.lua map_reader.lua test_map_reader.lua
```

Full `lua test_map_reader.lua` still has the same two unrelated map04 failures:

```text
(12,19) should stay open from south ... expected nil, got true
(16,16) should block the east approach ... expected true, got nil
```

## Live State Restored

After direct probes, live state was restored:

```text
POSITION: map=0x08(Brecconary) x=10 y=25
RUNTIME_BLOCKS map=0x08 none
NPCs unfrozen
PATH_STATE target=nil map=0x08 runtime_count=0
```

## Next Resume Point

Reload Lua before relying on:

- `MAP_DIRECTIONAL_BLOCKS[0x08]["8,27"] = {south = true}`
- queued-route post-step stale-direction cleanup
- raw debug-input release suppression

Recommended next check after reload: run `survey_objects:retry_failed,park_npcs`
or a fresh parked Brecconary survey. Expected improvement is that `Guard 4`
should no longer churn on `(8,27) south`, and `Old Man 1` should not fail with
`route_inactive_without_completion` from the `(5,9)/(5,10)` release blip.
