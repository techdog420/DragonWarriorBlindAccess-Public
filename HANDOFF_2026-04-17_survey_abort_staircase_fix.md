# Handoff: Survey Abort on Low Exit Count (Staircase Trap Fix)
Date: 2026-04-17

## Summary

A new survey run on map 0x04 (Tantegel Castle) failed completely because it started
from the staircase tile at (7,7). In Dragon Warrior, stepping onto a staircase
immediately triggers a map transition — the engine blocks outward movement from
staircase tiles in all directions as a side effect. The tile model correctly marks
(8,7) and (7,8) as walkable floor/carpet tiles, but the engine refuses movement off
the staircase onto them. With only 2 tile-model exits (south and east) and both
engine-blocked within the first 2 attempts, the player was fully trapped. All 28
remaining targets failed with `command_timing_or_state_issue` as pathfinder kept
routing through those same two tiles.

The `SURVEY_START_WARNING reason=low_exit_count` fired at survey launch (line 11 of
that session's log) but was only a log message — the survey ran anyway and wasted
~12,000 frames.

## What Changed

**`map_survey.lua`** — `open_exit_count <= 2` is now a hard abort.

Previously: a `SURVEY_START_WARNING` log line was emitted but execution continued.

Now: if the tile model sees only 1 or 2 open exits from the start position, the survey
aborts **before** `survey_state` is initialized and before NPC parking is applied. The
player hears:

```
Survey aborted: start (X,Y) has only N open exits. Move to a more open position and try again.
```

Log tag: `SURVEY_START_ABORT reason=low_exit_count` (matches the existing
`isolated_start` abort format for consistency).

The stale `SURVEY_START_WARNING` block was removed (it was dead code once the abort
precedes it in the same function).

### Where in the code

`start_run()` in `map_survey.lua`, lines ~1731–1752. Two sequential abort guards now
exist before `survey_state = { ... }`:

1. `start_info.isolated_start` — existing guard: fires when reachable area ≤ 16 tiles
   (hard) or ≤ 12 tiles (very hard). Catches truly walled-in starts.
2. `start_info.open_exit_count <= 2` — new guard: fires when tile model sees ≤ 2
   exits regardless of reachable area. Catches corner/niche starts like staircases.

## Why Staircase Tiles Trap the Player

In Dragon Warrior, stepping onto a staircase tile triggers the dungeon
ascent/descent immediately. The engine treats the staircase as a one-way entry
trigger. The player can walk ONTO the staircase (approaching from south/east is fine),
but the engine blocks walking OFF it in any direction. This only matters in our code
because `teleport_to` can place the player directly on the staircase tile, bypassing
normal approach; in normal gameplay you'd be teleported the moment you step on it.

The tiles around (7,7) on map 0x04:
- (7,6) north: tile-blocked (wall) per model ✓
- (6,7) west: tile-blocked (wall) per model ✓
- (8,7) east: tile type 4 (floor), model says walkable — engine blocks from (7,7)
- (7,8) south: tile type 6 (carpet), model says walkable — engine blocks from (7,7)

This is NOT a model bug. (8,7) and (7,8) are genuinely accessible from other
directions and should NOT be added to MAP_BLOCKED_CELLS or MAP_DIRECTIONAL_BLOCKS.
The blocks are specific to movement originating from the staircase tile.

## Current Uncommitted Changes

The working tree has significant changes vs HEAD (194ed37):

```
CLAUDE.md           +10
auto_step.lua       +15 / -2
main.lua            +73 / -1
map_reader.lua      +102 / -7  (row-16 passthrough/directional blocks from 2026-04-13)
map_survey.lua      +35 / -13  (park_npcs cache fix from 2026-04-14 + today's abort fix)
route_manager.lua   +4 / -1
session_handoff.md  (updated)
test_map_reader.lua +61 / -2
```

These have been manually tested by the user and are working. They should be committed
before further survey work. Suggested commit message:

```
Fix survey start trap: abort on low exit count; add row-16 directional blocks and park_npcs cache fix
```

## Open Issues From Previous Sessions

### 1. (12,16) east approach — MONITOR ONLY

The east-side directional blocker at `MAP_DIRECTIONAL_BLOCKS[0x04]["12,16"].east = true`
is kept. EDGE_PROBE_MODEL_MISMATCH fired once (moved through modeled block) then stayed
silent on 5 subsequent probes (all blocked). Decision: keep the block. The engine blocks
83% of the time; the occasional pass-through is tolerable. No targets are cut off by it.

Do NOT remove this block.

### 2. stair_1_1 route length (63 steps) — LOW PRIORITY

The A* route from ~(10,14) to the staircase at (1,1) takes 63 steps via the y=16 east
decoder band. This is because the direct westward/northward route has obstacles. It may
have improved after the row-16 directional block fixes — untested since 2026-04-13.
Worth checking in a future survey pass but not urgent.

## What To Do Next

### Step 1: Commit the working tree

All changes in the working tree are tested and ready. Commit them.

### Step 2: Re-run map 0x04 survey from a good start position

The staircase abort fix means you can't accidentally start from (7,7) anymore. Pick a
central open-floor tile with 3+ exits. Suggested start positions on map 0x04:

- `teleport_to:10,14` — mid-map, open floor area
- `teleport_to:15,12` — central corridor area

Command:
```
echo survey_objects:park_npcs > dw_commands.txt
```

Watch `dw_debug.log` for `SURVEY_START_CONTEXT` — confirm `open_exit_count >= 3`
before leaving it to run.

Key targets to watch:
- Guard 1 (npc_1) at (14,4): had long 57-step path via y=16 band; should be shorter now
- stair_1_1 at (1,1): was 63 steps; check if row-16 fixes shortened it
- Guard 4 (npc_7) and chests at (1-3, 13-15): in a gated west section — these
  consistently show `gated_or_isolated_region`. Verify whether they are truly
  unreachable or a model gap.

### Step 3: Investigate the gated west-side region

Five targets on map 0x04 consistently fail as `gated_or_isolated_region`:
- chest_0 at (1,13)
- chest_2 at (2,14)
- chest_3 at (3,15)
- chest_1 at (1,15)
- Guard 4 (npc_7) at (3,15)

These are in the northwest quadrant of Tantegel Castle. The survey starts from the
east side and cannot find paths to the west side. This may be a genuine game
design (treasure room requires a key) or a model gap where we're missing a
connecting passage. Worth a direct teleport + probe session to understand the
layout there.

### Step 4: Continue surveying remaining maps

Maps not yet surveyed (or minimally surveyed): all dungeon maps (IDs 0x01–0x07,
0x0B–0x1D), towns (0x0C–0x11). After map 04 is clean, start on map 0x0C
(Tantegel Town / Brecconary) which already has some block data from earlier sessions.

## Survey System Quick Reference

### Key survey commands (write to dw_commands.txt)
```bash
echo survey_objects > dw_commands.txt              # survey from current position
echo survey_objects:park_npcs > dw_commands.txt    # park all NPCs except target
echo survey_objects:retry_failed > dw_commands.txt # retry only previous failures
echo stop_survey > dw_commands.txt                 # stop in-progress survey
echo report_viability > dw_commands.txt            # check start position quality
echo teleport_to:X,Y > dw_commands.txt             # move player before surveying
```

### Survey abort conditions (in order of checking)
1. `no_targets` — no survey targets on current map
2. `isolated_start` — reachable area ≤ 16 tiles, OR ≤ 12 tiles regardless
3. `low_exit_count` — ≤ 2 tile-model exits from start position (**new this session**)

### Reading results
- `SURVEY_START_CONTEXT` — shows open/blocked exit directions from start
- `SURVEY_RESULT` lines — one per target, check `failure_class` and `blocked_tiles`
- `SURVEY_ISOLATED_START` — fires mid-run when player gets stuck (clustered failures)
- `SURVEY_FAILURE_STARTS` / `SURVEY_FAILURE_START` — end-of-run summary

### Common failure classes
- `none` — success
- `already_there` — player was already at target
- `gated_or_isolated_region` — pathfinder found no path at all; target may be in
  an unreachable area, or model gap
- `suspected_engine_blocked_tile` — path found + attempted, single engine block
  discovered; tile added to runtime blocks
- `command_timing_or_state_issue` — multiple engine blocks; player often stuck
- `no_route` — path found but movement failed with no clear block candidate

## Map 0x04 (Tantegel Castle) Model Summary

Confirmed data in `map_reader.lua` as of this session:

**MAP_PASSTHROUGH_CELLS** (type-15 wall tiles the engine allows walking on):
- (4,8)–(8,8): y=8 corridor east of the magic-key door
- (15,16), (16,16), (17,16): row-16 decoder gap corridor cells

**MAP_DIRECTIONAL_BLOCKS** (directional movement restrictions):
- (4,7): east=true (x=4 east wall extends north to y=7)
- (12,16): east=true (mixed evidence; keep block)
- (15,16): west=true (approach from east blocks westward exit)
- (16,16): east=true, south=true
- (17,16): south=true
- (18,16): south=true

**MAP_BLOCKED_CELLS** (tiles model marks unwalkable despite tile type):
- (2,2)–(8,2): throne/dais sprite collision in throne room (map 0x05)

**MAP_DOOR_CELLS**:
- map 0x05 (4,7): magic-key door; walkable only when opened-door RAM confirms open

**STAIRS** (confirmed empirically):
- map 0x04: stair at (7,7) goes UP to throne room (map 0x05)
- map 0x04: stair at (29,1) goes DOWN to treasure room
- map 0x05: stair at (8,8) exits throne room (east corridor)

Note: CLAUDE.md map ID table is WRONG for Tantegel. Empirically confirmed:
- 0x04 = Tantegel Castle main hall (NOT Charlock B3 as CLAUDE.md says)
- 0x05 = Tantegel Throne Room (NOT Charlock B4 as CLAUDE.md says)

Do not trust the CLAUDE.md map ID table for IDs above 0x0B without in-game verification.
