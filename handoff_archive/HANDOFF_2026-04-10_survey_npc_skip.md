# Handoff: Survey NPC Skip & West Wing Isolation
Date: 2026-04-10 evening session

## What Was Accomplished

### 1. Confirmed directional blocks added to map_reader.lua
- `["6,9"] = {west = true}` — west wing crossing blocks west approach (can enter wing from east, cannot exit east). Confirmed by survey pass 8 runtime block: auto_step:right from (5,9) refused.
- `["6,12"]` updated to `{east = true, west = true}` — west approach confirmed same survey pass.

### 2. Survey NPC skip implemented (route_manager.lua + map_survey.lua)
- `build_path_blocking(map_id, opts)` now accepts `{skip_npcs = true}` to omit NPC positions from the A* blocking table.
- `plan_path_to_object` passes `skip_npcs` when `opts.survey_safe` is set (all survey calls already use `survey_safe = true`).
- 4 diagnostic `build_path_blocking` calls in map_survey.lua updated to skip NPCs.
- Candidate-recording call at line 1145 intentionally left WITH NPC awareness (avoids recording NPC collisions as directional block candidates).
- Normal pathfinding (hotkeys, autowalk) is completely unaffected.

### 3. Analysis: genuine west wing isolation confirmed
Survey results with NPC skip: 6 successes, 24 failures (all gated_or_isolated, 0 suspected_engine_blocked). The failures are from STATIC blocks, not NPCs:

**West wing is one-way entry:**
- x=6 y=9: west approach blocked (new). East approach open (enter wing only).
- x=6 y=11-16: bidirectional (east+west). No crossing.
- x=6 y=6-8,10: full blocks.
- Result: player can enter west wing from the east but CANNOT exit eastward.

**South corridor isolation:**
- x=13 at y=21-27: fully blocked (MAP_BLOCKED_CELLS) — solid wall
- x=14 at y=19-20: fully blocked (MAP_BLOCKED_CELLS) — from 2026-03-23 sweep
- Result: no east-west crossing in the south area below y=19
- The ONLY connection between castle halves is through the antechamber at y=7-9, which is one-way east-to-west at x=6

## Test Results
- **6/6 test_path scenarios pass** throughout all changes
- Survey pass with NPC skip: 6/30 successes, 24 gated_or_isolated

## Failure Clusters (latest survey)
- **(3,8)**: 14 failures — stuck in west wing, can't exit east
- **(6,25)**: 10 failures — stuck in SW merchant area, can't reach east half

## Pending — First Tasks Next Session

### Priority 1: Validate south corridor blocks
The blocks at **(14,19)** and **(14,20)** are from 2026-03-23 sweep data, potentially tainted (pre-NPC-exclusion). If these are false positives, removing them opens x=14 as a crossing from the SW corridor to the y=17 east corridor, connecting the castle halves.

Steps:
1. Walk player to (13,19) or (13,20)
2. Run `inspect_move:14,19` and `inspect_move:14,20` to probe if engine truly blocks
3. If false positives: remove from MAP_BLOCKED_CELLS, re-run survey

### Priority 2: Investigate west wing exit path
In the actual game, how does the player exit the west wing after visiting guards/chests? Options:
1. There may be a valid x=6 crossing we haven't found (check y=17+ on x=6)
2. Player may exit south through SW corridor — but south corridor blocks prevent reaching east
3. Some south corridor blocks may be false positives (see Priority 1)

### Priority 3: Consider south corridor re-sweep
If (14,19)/(14,20) are confirmed false positives, a broader re-validation of the 2026-03-23 sweep data may be warranted. The MEMORY notes: "dw_blocks.log currently has 634 entries from tainted sweeps."

## Files Modified This Session
- `map_reader.lua` — added (6,9) west=true, updated (6,12) to east+west, updated comments
- `route_manager.lua` — added skip_npcs option to build_path_blocking and plan_path_to_object
- `map_survey.lua` — 4 diagnostic calls now pass skip_npcs=true
