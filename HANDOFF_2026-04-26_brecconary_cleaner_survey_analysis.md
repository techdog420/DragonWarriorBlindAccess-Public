# Handoff: Brecconary Cleaner Survey Analysis — 2026-04-26

## Context

After the controller-input regression was backed out and Lua was reloaded, the
user ran a fresh parked-NPC Brecconary survey. Controller input was verified
before and after the survey.

## Survey Summary

Latest completed run:

```text
SURVEY_COMPLETE run=1 map=0x08 targets=21 successes=14 failures=7 no_route=0 gated_or_isolated=6 movement_failed=0 suspected_engine_blocked=0 state_issues=1 adjacency_issues=0
```

Post-run state:

```text
POSITION: map=0x08(Brecconary) x=9 y=25
PATH_STATE target=nil map=0x08 runtime_count=0
RUNTIME_BLOCKS map=0x08 none
SURVEY_STRONG_CANDIDATES map=0x08 none
SURVEY_CANDIDATE_SUGGESTIONS map=0x08 none
```

Failure grouping:

```text
SURVEY_FAILURE_START map=0x08 start=(28,2) failures=5 distinct_targets=5 gated_or_isolated=5 targets=Merchant|Merchant|Old Man|Person|Woman
SURVEY_FAILURE_START map=0x08 start=(13,15) failures=1 distinct_targets=1 state_issues=1 targets=Guard 4
SURVEY_FAILURE_START map=0x08 start=(24,22) failures=1 distinct_targets=1 gated_or_isolated=1 targets=Merchant 4
```

## Candidate Review

The only candidate cells were diagnostic `needs_repro` entries:

```text
SURVEY_CANDIDATE map=0x08 x=8 y=27 key=8,27 count=4 targets=2 retry_successes=1 failure_count=0 state_issues=1 confidence=needs_repro approaches=south
SURVEY_CANDIDATE map=0x08 x=10 y=27 key=10,27 count=3 targets=1 retry_successes=0 failure_count=0 state_issues=1 confidence=needs_repro approaches=south
```

Focused split-command probes confirmed both south approaches are passable:

```text
EDGE_PROBE_RESULT map=0x08 from=(10,28) dir=up dest=(10,27) status=moved final=(10,27)
EDGE_PROBE_RESULT map=0x08 from=(8,28) dir=up dest=(8,27) status=moved final=(8,27)
```

Do not patch `8,27 south` or `10,27 south` from this survey. They are route
execution/state noise, and the current candidate filters correctly keep them out
of strong candidates and directional suggestions.

## Tooling Finding

During follow-up, batching `teleport_to:10,28 report_position inspect_move:UP`
showed:

```text
POSITION: map=0x08(Brecconary) x=10 y=28
MOVE map=0x08 from=(9,25) dir=up dest=(9,24) ...
```

The RAM position changed immediately, but `inspect_move` read the old cached
`game_snapshot` coordinates because all commands were processed in one poll.
`main.lua` now calls `snapshot.update()` after `teleport_to` writes the player
coordinates and normalizes movement state, so later commands in the same poll do
not inspect the pre-teleport position.

Validation:

```text
luac -p main.lua
git diff --check -- main.lua
```

Reload Lua before relying on the snapshot-refresh patch.

## Live State Restored

After probes:

```text
teleport_to:9,25
clear_blocked_tiles:0x08
unfreeze_npcs
report_position
list_blocked_tiles:0x08
```

Confirmed:

```text
POSITION: map=0x08(Brecconary) x=9 y=25
RUNTIME_BLOCKS map=0x08 none
```

## Recommendation

No permanent Brecconary map-data patch is warranted from this run. The survey is
substantially cleaner than the prior 9/12 run. The remaining non-state failures
look like gated or isolated target pockets, while the lone state issue is the
known south-approach churn near y=27.
