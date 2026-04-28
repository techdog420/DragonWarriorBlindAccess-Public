# Handoff 2026-04-24 — Map 0x04 post-south-patch reload check

## What happened

After patching the three post-reload-confirmed south-entry seams:

```lua
["8,3"]  = {south = true},
["14,3"] = {south = true},
["15,3"] = {east = true, south = true},
```

the user reloaded the FCEUX Lua script again. Fresh log header:

```text
Started: 2026-04-24 10:15:00
```

Setup:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks clear_seam_cells teleport_to:17,5 report_position
```

Confirmed:

```text
POSITION: map=0x04(Tantegel Castle) x=17 y=5
```

Then ran:

```bash
./dw_commands.sh --replace "survey_target:Stairs Down to Throne Room,park_npcs"
```

## Result

The target no longer attempted movement through the previously bad seams.
Instead, pathfinding now immediately reports no modeled route from `(17,5)` to
an adjacent tile for the throne-room stairs:

```text
SURVEY_RESULT run=1 map=0x04 target_id=stair_1_1 target_name="Stairs Down to Throne Room" start=(17,5) target=(1,1) path_mode=adjacent path_found=false path_length=0 movement_succeeded=false final=(17,5) failure_class=no_route_found blocked_events=0 suspected_tiles=- blocked_tiles=- retry_succeeded=false alternate_mode=direct alternate_path_found=false reason=no_path
```

Follow-up debug command:

```bash
./dw_commands.sh --replace report_position debug_pathfind_adjacent:1,1 dump_path_grid
```

confirmed:

```text
Debug pathfind adjacent to (1,1): No path found [no_path] (visited=587 path=0)
```

## Interpretation

The latest blocker patches changed the focused throne-room target from an
execution/reroute failure into a clean planner `no_route_found`.

This is likely progress: the model no longer claims a path through seams that
the engine rejects. The throne-room stairs at `(1,1)` now appear disconnected
from the `(17,5)` start under the current model.

Open question:

- Is `stair_1_1` truly gated/isolated from main-hall start `(17,5)`, or is
  there still a missing legitimate connector elsewhere?

## Recommended next step

Classify this target carefully before more map patching:

1. Run a broader `survey_objects:park_npcs` after reload to see whether the
   overall target distribution improves.
2. If `stair_1_1` remains `no_route_found`, inspect whether it should be marked
   gated/isolated rather than treated as a pathfinding failure.
3. Avoid reopening the patched seams unless a controlled reverse/alternate probe
   proves a legitimate route exists.
