# Handoff 2026-04-24 — Map 0x04 post-x15-reopen targeted survey

## What happened

After removing the stale x=15 east-entry static blockers and reloading the
FCEUX Lua script, the targeted throne-room stairs survey was rerun.

Fresh log header:

```text
Started: 2026-04-24 10:44:58
```

Setup:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks clear_seam_cells teleport_to:17,5 report_position
```

Confirmed:

```text
POSITION: map=0x04(Tantegel Castle) x=17 y=5
```

Targeted survey:

```bash
./dw_commands.sh --replace "survey_target:Stairs Down to Throne Room,park_npcs"
```

## Result

The planner now finds a route. This is a clear improvement over the prior
`no_route_found` result:

```text
pathfind chosen adj=(2,1) path=2 north, 2 west, 1 north, 7 west, 1 north, 6 west
AUTO_WALK: queued 19 step(s) for Stairs Down to Throne Room
```

The planned route:

```text
(17,5)->(17,4)->(17,3)->(16,3)->(15,3)->(15,2)->(14,2)->...->(2,1)
```

Movement executed through the first part:

- `(17,5)->UP->(17,4)` moved
- `(17,4)->UP->(17,3)` moved
- `(17,3)->LEFT->(16,3)` moved

Then queued route execution repeatedly blocked on the x=15 east-entry seams:

- `(16,3)->LEFT->(15,3)` blocked and later confirmed after brute-force retry
- `(16,2)->LEFT->(15,2)` blocked repeatedly and runtime-confirmed
- `(16,1)->LEFT->(15,1)` blocked repeatedly and runtime-confirmed

Final survey result:

```text
SURVEY_RESULT run=1 map=0x04 target_id=stair_1_1 target_name="Stairs Down to Throne Room" start=(17,5) target=(1,1) path_mode=adjacent path_found=true path_length=19 movement_succeeded=false final=(16,3) failure_class=command_timing_or_state_issue blocked_events=9 suspected_tiles=15,3|15,2|15,1 blocked_tiles=15,3|15,2|15,1|15,2|15,1|15,2|15,1|15,3|15,3 retry_succeeded=false alternate_mode=direct alternate_path_found=false reason=reroute_no_path
```

Survey summary:

```text
SURVEY_COMPLETE run=1 map=0x04 targets=1 successes=0 failures=1 no_route=0 gated_or_isolated=0 movement_failed=0 suspected_engine_blocked=0 state_issues=1 adjacency_issues=0
```

## Interpretation

The x=15 reopen patch fixed planning: the target is no longer modeled as
isolated.

The remaining issue is a contradiction between:

- fresh-reload direct probes before the patch, where
  `(16,1)/(16,2)/(16,3)->LEFT` moved through x=15, and
- queued route execution after reload, where those same seams blocked
  repeatedly and were classified as a command timing/state issue.

Do not immediately re-promote x=15 `east=true` in static map data from this
targeted survey alone. The survey itself classifies the failure as
`command_timing_or_state_issue`, and direct probes contradicted the queued-route
blocks.

## Recommended next step

Run controlled direct probes in the same loaded session, split into setup and
probe commands:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks clear_seam_cells teleport_to:16,3 report_position
./dw_commands.sh --replace probe_edge:16,3,LEFT

./dw_commands.sh --replace freeze_npcs clear_runtime_blocks clear_seam_cells teleport_to:16,2 report_position
./dw_commands.sh --replace probe_edge:16,2,LEFT

./dw_commands.sh --replace freeze_npcs clear_runtime_blocks clear_seam_cells teleport_to:16,1 report_position
./dw_commands.sh --replace probe_edge:16,1,LEFT
```

If direct probes move while queued route blocks, investigate auto-step timing,
turn-facing, or seam-bruteforce behavior before changing permanent map data.
