# Handoff: Brecconary Fresh Survey 10,27 Follow-up - 2026-04-27

## Survey Result

After the fresh map08/Brecconary survey, the run completed:

```text
SURVEY_COMPLETE run=1 map=0x08 targets=21 successes=12 failures=9 no_route=0 gated_or_isolated=8 movement_failed=0 suspected_engine_blocked=1 state_issues=0 adjacency_issues=0
```

The eight ordinary failures were the known gated/isolated clusters:

```text
start=(28,2): Merchant, Merchant, Old Man, Person
start=(15,25): Merchant 4, Person 1, Person 5, Woman 1
```

The only actionable failure was `Guard 4`:

```text
SURVEY_RESULT run=1 map=0x08 target_id=npc_9 target_name="Guard 4" start=(10,17) target=(4,25) path_mode=adjacent path_found=true path_length=27 movement_succeeded=false final=(10,28) failure_class=suspected_engine_blocked_tile blocked_events=3 suspected_tiles=10,27 blocked_tiles=10,27|10,27|10,27 retry_succeeded=false alternate_mode=direct alternate_path_found=false reason=reroute_no_path
```

During that failure, the survey blocked three times on `(10,28)->UP` into
`(10,27)`, so the exporter briefly suggested:

```text
SURVEY_DIRECTIONAL_EXPORT map=0x08 count=1
    [0x08] = {
        ["10,27"] = {south=true},  -- confidence=high count=3 retry_successes=0
    },
```

## Focused Probes

A split follow-up with NPCs frozen teleported to `(10,28)`, then probed `UP`
separately:

```text
POSITION: map=0x08(Brecconary) x=10 y=28
MOVE map=0x08 from=(10,28) dir=up dest=(10,27) ... approach_blocked=false effective_passable=true
EDGE_PROBE_RESULT map=0x08 from=(10,28) dir=up dest=(10,27) status=moved final=(10,27) ... reason=position_changed
SEAM_OBSERVATION map=0x08 cell=(10,27) approach=south result=moved blocked=3 moved=1 classification=noisy source=auto_hold
```

After that normalized teleport probe, the candidate was correctly downgraded and
no pasteable export remained:

```text
SURVEY_CANDIDATE_SUGGESTIONS map=0x08 none
SURVEY_CANDIDATE map=0x08 x=10 y=27 key=10,27 count=3 targets=1 retry_successes=0 failure_count=1 state_issues=0 confidence=needs_repro approaches=south
SURVEY_DIRECTIONAL_EXPORT map=0x08 count=0
```

However, the reload-and-survey confidence pass reproduced `10,27 south` more
strongly under real route context:

```text
SURVEY_COMPLETE run=1 map=0x08 targets=21 successes=9 failures=12 no_route=0 gated_or_isolated=10 movement_failed=0 suspected_engine_blocked=1 state_issues=1 adjacency_issues=0
SURVEY_STRONG_CANDIDATE map=0x08 x=10 y=27 key=10,27 count=4 targets=2 retry_successes=1 state_issues=0 approaches=south confidence=high
SURVEY_DIRECTIONAL_EXPORT map=0x08 count=1
        ["10,27"] = {south=true},  -- confidence=high count=4 retry_successes=1
```

The key follow-up was route-context, not a normalized teleport:

```text
EDGE_PROBE_RESULT map=0x08 from=(11,28) dir=left dest=(10,28) status=moved final=(10,28)
EDGE_PROBE_RESULT map=0x08 from=(10,28) dir=up dest=(10,27) status=blocked final=(10,28) ... reason=route_blocked
EDGE_PROBE_MODEL_MISMATCH map=0x08 from=(10,28) dir=up dest=(10,27) kind=blocked_despite_open_preview
CMD: simulate_raw_input:UP,120
POSITION: map=0x08(Brecconary) x=10 y=28
```

Interpretation: normalized teleport probes can move through `(10,28)->UP`, but
after a real route step into `(10,28)` from `(11,28)`, both auto-step probing
and a 120-frame raw UP hold stay pinned. For route reliability, model the seam
as blocked from the south.

Current Brecconary truth:

```lua
["10,27"] = {north = true, south = true}
```

## Cleanup

The live runtime/test state was cleared after recording the evidence:

```text
SURVEY: cleared blocked candidates for map 0x08
runtime blocks cleared: map=0x08 count=0
seam memory cleared: map=0x08
NPCs unfrozen
SURVEY_CANDIDATES map=0x08 none
RUNTIME_BLOCKS map=0x08 none
SEAM_SUMMARY map=0x08 total=0 confirmed_blocked=0 noisy=0 blocked_only=0 passable_only=0
POSITION: map=0x08(Brecconary) x=10 y=27
```

After the later route-context probe and patch, live cleanup was repeated:

```text
SURVEY: cleared blocked candidates for map 0x08
runtime blocks cleared: map=0x08 count=0
seam memory cleared: map=0x08
NPCs unfrozen
SURVEY_CANDIDATES map=0x08 none
RUNTIME_BLOCKS map=0x08 none
SEAM_SUMMARY map=0x08 total=0 confirmed_blocked=0 noisy=0 blocked_only=0 passable_only=0
POSITION: map=0x08(Brecconary) x=10 y=28
```

## Code Cleanup

`main.lua` now logs structured output for `report_runtime_blocks`, including the
zero case. Previously the command spoke "No runtime blocked cells" through Tolk
but left only a `CMD: report_runtime_blocks` line in `dw_debug.log`, which made
log-based verification ambiguous.

`map_reader.lua` now models `MAP_DIRECTIONAL_BLOCKS[0x08]["10,27"]` as
`{north = true, south = true}`. `test_map_reader.lua` was updated to cover the
south approach promotion.

Validation:

```text
luac -p map_reader.lua test_map_reader.lua
git diff --check -- map_reader.lua test_map_reader.lua main.lua session_handoff.md HANDOFF_2026-04-27_brecconary_fresh_survey_1027_followup.md
lua test_map_reader.lua  # still has the two known unrelated Tantegel failures
```

## Next Resume Point

Reload Lua so the `10,27 south` map patch is active, then run another fresh
parked Brecconary survey. Expected improvement: routes should no longer try the
unreliable `(10,28)->UP` seam. Watch separately for the one Guard 5
`route_drift_off_path` state issue from this pass; it retried through another
target successfully and did not produce map-data evidence.
