# Handoff 2026-04-24 — Map 0x04 legitimate throne-route investigation

## What happened

After the post-south-patch reload check made `Stairs Down to Throne Room`
report clean `no_route_found` from `(17,5)`, we investigated whether the
target was truly isolated or whether a legitimate connector was still being
masked by stale directional data.

The script reloaded again during the investigation:

```text
Started: 2026-04-24 10:23:16
```

Baseline from the main-hall side:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks clear_seam_cells teleport_to:17,5 report_position
./dw_commands.sh --replace debug_pathfind_to:6,1 debug_pathfind_to:5,1 debug_pathfind_adjacent:1,1
```

confirmed that the loaded static model still reported no path:

```text
Debug pathfind to (6,1): No path found [no_path] (visited=587 path=0)
Debug pathfind to (5,1): No path found [no_path] (visited=587 path=0)
Debug pathfind adjacent to (1,1): No path found [no_path] (visited=587 path=0)
```

## Key probe evidence

From inside the stairs-side pocket, direct probes found old x=6 directional
entries are suspicious/stale:

```text
(5,1)->RIGHT->(6,1): moved_through_modeled_block
(5,2)->RIGHT->(6,2): moved_through_modeled_block
```

More importantly for the main-hall-to-stairs route, fresh-reload direct probes
showed the x=15 east-entry blocks were false positives:

```text
(16,1)->LEFT->(15,1): moved_through_modeled_block
(16,2)->LEFT->(15,2): moved_through_modeled_block
(16,2)->LEFT->(15,2): moved_through_modeled_block  # repeat
(16,3)->LEFT->(15,3): moved_through_modeled_block
```

Each used separated setup/probe commands with NPCs frozen and runtime/seam
memory cleared before probing.

Interpretation:

- There is a legitimate route through the north corridor, but the static model
  was blocking it at x=15.
- The previous x=15 `east=true` patch should be reverted.
- Keep `(15,3) south=true`, because the south-entry block from `(15,4)->UP`
  was independently confirmed post-reload.
- The x=6 findings are useful follow-up evidence, but they are not necessary
  for the main-hall-to-throne target route because the route crosses x=6 from
  east to west, which those `west=true` entries do not block.

## Patch applied

`map_reader.lua`:

- removed `["15,1"] = {east = true}`
- removed `["15,2"] = {east = true}`
- changed `["15,3"] = {east = true, south = true}` to
  `["15,3"] = {south = true}`

`test_map_reader.lua`:

- added `tantegel_castle_throne_x15_east_entries_stay_open`

Validation:

```text
luac -p map_reader.lua
```

passed.

The focused `lua test_map_reader.lua` run still has three unrelated existing
failures, but the new x=15 regression test passed.

## Immediate next step

Reload the full FCEUX Lua script, then rerun:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks clear_seam_cells teleport_to:17,5 report_position
./dw_commands.sh --replace "survey_target:Stairs Down to Throne Room,park_npcs"
```

Expected effect:

- the planner should no longer fail immediately at x=15
- if the route is now modeled correctly, the target should path through the
  north corridor instead of reporting `no_route_found`
