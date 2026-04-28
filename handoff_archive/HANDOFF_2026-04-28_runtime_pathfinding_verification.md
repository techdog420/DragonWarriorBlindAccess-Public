# 2026-04-28 Runtime Verification After Reload

## Scope
- Manual live verification of route-planning robustness after the directional-block hardening and script reload.
- Confirmed current runtime command pipeline and unit tests are still healthy.

## Live Session Evidence
- `dw_debug.log` confirmed script activity on start:
  - `CMD: freeze_npcs`
  - `CMD: report_position` => `POSITION: map=0x04(Tantegel Castle) x=11 y=12`
- Controlled positioning:
  - `teleport_to:5,13` then `teleport_to:5,14` and repeated report_position both took cleanly and updated live position.
- Targeted path-debug probes in `map=0x04`:
  - `debug_pathfind_to:6,13` -> `No path found [no_path]`
  - `debug_pathfind_to:4,13` -> `No path found [goal_not_walkable]`
  - `debug_pathfind_to:6,14` -> `No path found [no_path]`
  - `debug_pathfind_to:4,10` -> `No path found [no_path]`
- Tile probes confirmed directional-block modeling is visible in engine-facing inspect output:
  - `inspect_tile:4,13` => `walkable=true permanent_blocked=true directional_blocked=true effective_passable=false` (goal intentionally non-traversable as expected)
  - `inspect_tile:6,14` => `walkable=true permanent_blocked=false directional_blocked=true effective_passable=true`
  - `inspect_tile:4,10` => `walkable=true permanent_blocked=false directional_blocked=true effective_passable=true`
  - `inspect_tile:6,12/13/15/16` all reported directional-blocked behavior with otherwise walkable tiles.
- `PATH_RUNTIME_BLOCK` log entries are emitted during path checks, indicating directional blockers are being considered.

## Unit verification
- `luac -p pathfinder.lua test_pathfinder.lua map_survey.lua test_map_survey.lua path_debug.lua` passed.
- `lua test_pathfinder.lua` passed (9/9).
- `lua test_map_survey.lua` passed (40/40).

## Follow-up / potential cleanup
- `blocked_directional` reject reason is not appearing in `dump_search_log` output. This appears to be a logging-tagging issue: `route_manager.build_path_blocking` stores static and runtime directional blocks in the same table shape, and `pathfinder.get_block_reason` treats any directional match as runtime. This is report fidelity, not path outcome.
