# Handoff: Brecconary Guard 4 Southwest Follow-up - 2026-04-26

## Trigger

After reloading Lua and restarting a parked Brecconary survey, Guard 4 began
thrashing around the southwest guard pocket. The survey was stopped manually
before continuing so the suspected cells could be split with direct probes.

The relevant survey failure was:

```text
SURVEY_RESULT run=1 map=0x08 target_id=npc_9 target_name="Guard 4" start=(8,25) target=(4,26)
path_found=true path_length=4 movement_succeeded=false final=(7,25)
failure_class=command_timing_or_state_issue blocked_events=19
suspected_tiles=8,26|5,26|5,25|6,27|7,27|8,25
```

The later stopped survey state was:

```text
SURVEY_COMPLETE run=1 map=0x08 targets=4 successes=0 failures=4 no_route=0 gated_or_isolated=1 movement_failed=0 suspected_engine_blocked=1 state_issues=2 adjacency_issues=0
POSITION: map=0x08(Brecconary) x=7 y=25
RUNTIME_BLOCKS map=0x08 count=1 cell=8,25
```

## Direct Probe Results

Confirmed blocked despite open previews:

```text
EDGE_PROBE_RESULT map=0x08 from=(7,25) dir=right dest=(8,25) status=blocked final=(7,25)
SEAM_OBSERVATION map=0x08 cell=(8,25) approach=west result=blocked ... classification=confirmed_blocked

EDGE_PROBE_RESULT map=0x08 from=(7,26) dir=right dest=(8,26) status=blocked final=(7,26)
SEAM_OBSERVATION map=0x08 cell=(8,26) approach=west result=blocked ... classification=confirmed_blocked

EDGE_PROBE_RESULT map=0x08 from=(8,25) dir=down dest=(8,26) status=blocked final=(8,25)
SEAM_OBSERVATION map=0x08 cell=(8,26) approach=north result=blocked ... classification=blocked_only
```

Rejected as noisy because the controlled probe moved:

```text
EDGE_PROBE_RESULT map=0x08 from=(6,25) dir=left dest=(5,25) status=moved final=(5,25)
EDGE_PROBE_RESULT map=0x08 from=(6,26) dir=left dest=(5,26) status=moved final=(5,26)
EDGE_PROBE_RESULT map=0x08 from=(6,26) dir=down dest=(6,27) status=moved final=(6,27)
EDGE_PROBE_RESULT map=0x08 from=(7,26) dir=down dest=(7,27) status=moved final=(7,27)
```

Do not promote `5,25 east`, `5,26 east`, `6,27 north`, or `7,27 north`.

## Patch

`map_reader.lua` now models the confirmed Brecconary southwest guard-pocket
approaches:

```lua
["8,25"] = {east = true, west = true},
["8,26"] = {east = true, north = true, west = true},
```

`test_map_reader.lua` asserts those three newly confirmed approaches.

## Validation

Passed:

```text
luac -p map_reader.lua test_map_reader.lua
git diff --check -- map_reader.lua test_map_reader.lua
```

`lua test_map_reader.lua` still exits nonzero only on the same unrelated map04
assertions:

```text
FAIL tantegel_castle_south_pocket_false_blocks_are_open: (12,19) should stay open from south ... expected nil, got true
FAIL tantegel_castle_upper_chamber_row_16_updates_are_modeled: (16,16) should block the east approach ... expected true, got nil
```

The Brecconary directional-wall test passed with the new assertions.

## Live State Restored

After the probes and patch, the emulator state was restored:

```text
POSITION: map=0x08(Brecconary) x=7 y=25
NPCs unfrozen
RUNTIME_BLOCKS map=0x08 none
PATH_STATE target=nil map=0x08 runtime_count=0
```

## Next Resume Point

Reload Lua before relying on these new `MAP_DIRECTIONAL_BLOCKS[0x08]` entries.
Then rerun a parked Brecconary object survey. Guard 4 should no longer churn on
the `(8,25)/(8,26)` west/north seams, and any remaining failures should be
checked for new direct-probe candidates rather than bulk-promoted from survey
noise.
