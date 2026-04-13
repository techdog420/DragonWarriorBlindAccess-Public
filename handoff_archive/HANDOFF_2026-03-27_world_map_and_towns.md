# Handoff: World Map And Town Entry Work

Date: 2026-03-27

## What Was Investigated

The user shifted focus away from battle text and onto town/world-map usability,
so the session centered on two issues:

1. On the world map, the object scanner was still surfacing objects from a
   previous interior map.
2. Brecconary's town exit/entrance coordinates were wrong in the hard-coded
   object table, which made the world-map handoff inaccurate.

The user later live-tested the new build and reported they were able to walk
around town and talk to several NPCs, but pathfinding still hits many blocked
cells / collision mismatches on that map.

## Key Live Facts Confirmed This Session

- Raw live map IDs are the newer RAM-aligned values already used by `maps.lua`:
  - `0x01` = World Map
  - `0x08` = Brecconary
  - `0x04` = Tantegel Castle
- Current live PPU dump (`ppu_dump.txt`) showed:
  - `Map: 8 (0x08)`
  - `Player: x=0, y=15`
- That Brecconary probe position is the verified town/world-map handoff cell
  to anchor the exit object against.

## Changes Made

### 1. Stale interior NPC/object carryover on overworld

`objects.lua` now treats overworld terrain context as having no NPC table.
This prevents lingering town/castle NPC RAM bytes from being interpreted as
 real world-map objects after a map transition.

Relevant behavior:
- stale interior NPCs should no longer appear on the world map
- stale interior NPCs should no longer be returned as blockers on the world map
- when terrain flips to overworld, the object list refresh path now clears the
  interior NPC view instead of preserving it

Regression coverage in `test_objects.lua`:
- `world_map_refresh_drops_stale_interior_npcs`
- `terrain_flip_forces_refresh_even_when_map_id_sticks`

### 2. Brecconary exit coordinate fix

`objects.lua` exit data for Brecconary was updated from the old south-edge
placeholder to the live west-edge entrance:

- `map 0x08`
- exit object at `(0,15)`

Regression coverage in `test_objects.lua`:
- `brecconary_exit_matches_live_west_edge_probe`

## Existing Related Coverage Worth Knowing About

- `test_maps.lua`
  - `world_map_uses_raw_id_01`
  - `early_game_location_ids_match_ram_map`
- `test_game_snapshot.lua`
  - `overworld_effective_position_uses_player_bytes`
- `test_objects.lua`
  - `world_map_anchor_places_tantegel_nearest_to_live_probe_position`

These are useful guardrails if Claude continues adjusting overworld/town logic.

## What The User Verified Live After The Fixes

- The user was able to walk around Brecconary.
- The user was able to talk to several NPCs.
- The user reported town navigation is better enough to continue progress.

## What Is Still Not Solved

The main remaining issue is town pathfinding fidelity, especially in Brecconary.

User report:
- pathfinding is finding many blocks and collisions there
- the map will need "a lot of work"

Most likely next area of effort:
- inspect runtime blocked tiles and repeated reroute failures in town
- compare object blockers / permanent blocked cells / walkability table against
  live movement on Brecconary
- verify whether the west-edge exit is a single trigger tile or a wider exit
  band on column `0`

Important nuance:
- The current Brecconary exit model uses the confirmed anchor cell `(0,15)`.
- It does NOT yet model a multi-tile edge band, even though the user observed
  that going west from several coordinates on column `0` may exit town.

## Suggested Next Steps For Claude

1. Use the current Brecconary live state as the starting probe map.

2. Gather blocker evidence on `0x08`:
   - `report_blockers`
   - `list_blocked_tiles`
   - `dump_blocked_tiles`
   - `inspect_tile:X,Y`
   - `inspect_move:DIR`

3. Focus on mismatches between:
   - `map_reader.is_walkable()`
   - runtime collision marks from `route_manager.lua`
   - NPC blockers from `objects.lua`
   - actual player movement in emulator

4. If town exits still feel wrong, model Brecconary's west edge as either:
   - multiple explicit exit objects
   - or a special-case edge-band abstraction for towns

5. Avoid "fixing" map IDs back to the older synthetic numbering. The codebase
   is already partly migrated to the real RAM IDs and `maps.lua` is the source
   of truth here.

## Verification Performed

Local verification after the latest changes:

- `lua test_objects.lua`
- `python3 run_tests.py`

Both passed.

## Files Most Relevant To This Handoff

- `objects.lua`
- `test_objects.lua`
- `maps.lua`
- `game_snapshot.lua`
- `route_manager.lua`
- `map_reader.lua`
- `ppu_dump.txt`

## Worktree Note

The git worktree is already dirty across many files from previous sessions.
Do not assume only today's changes are present, and do not clean or revert the
tree broadly. Work carefully with the existing in-progress state.
