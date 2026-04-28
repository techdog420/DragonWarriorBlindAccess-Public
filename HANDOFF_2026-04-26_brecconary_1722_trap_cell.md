# Handoff - 2026-04-26 - Brecconary 17,22 Trap Cell

## Summary

The latest reloaded Brecconary parked survey started cleanly from `(4,17)` but
later entered `(17,22)` and became stranded there. The survey completed:

`SURVEY_COMPLETE run=1 map=0x08 targets=21 successes=7 failures=14 no_route=0 gated_or_isolated=7 movement_failed=0 suspected_engine_blocked=3 state_issues=4 adjacency_issues=0`

This is not the prior bad-start problem at `(9,24)`. The low-target-coverage
preflight did its job; the run started from the broad town region.

## Evidence

- Survey start:
  - `SURVEY_START run=1 map=0x08 start=(4,17) targets=21 mode=objects npc_mode=park_npcs runtime_blocks=0`
- The route to Person 5 entered `(17,22)` from the west:
  - `auto_step complete dir=right from=(16,22) to=(17,22)`
  - `SEAM_OBSERVATION map=0x08 cell=(17,22) approach=west result=moved`
- Once standing on `(17,22)`, queued movement repeatedly failed to leave:
  - RIGHT into `(18,22)` blocked repeatedly.
  - DOWN into `(17,23)` blocked repeatedly.
  - LEFT into `(16,22)` blocked repeatedly.
  - NORTH is already a wall/tile-blocked exit.
- Split direct probes with runtime blocks cleared and NPCs frozen confirmed:
  - `probe_edge:17,22,LEFT` -> `status=blocked final=(17,22)` with `kind=blocked_despite_open_preview`
  - `probe_edge:17,22,RIGHT` -> `status=blocked final=(17,22)` with `kind=blocked_despite_open_preview`
  - `probe_edge:17,22,DOWN` -> `status=blocked final=(17,22)` with `kind=blocked_despite_open_preview`
- Independent raw-input confirmation:
  - After `teleport_to:17,22`, `simulate_raw_input:LEFT,120` left the player at `(17,22)`.

## Patch

`map_reader.lua` now adds `MAP_BLOCKED_CELLS[0x08]["17,22"] = true`, treating
the cell as pathfinder-forbidden. This matches the existing Brecconary trap-cell
treatment for `(16,23)` and `(18,17)`: even if the engine can enter the cell
from one side, A* should not route into a one-way cell that strands the player.

`test_map_reader.lua` now asserts that `(17,22)` is a permanent override for
Brecconary.

## Validation

- `luac -p map_reader.lua test_map_reader.lua` passed.
- `git diff --check -- map_reader.lua test_map_reader.lua` passed.
- `lua test_map_reader.lua` still has the two pre-existing unrelated Tantegel
  failures:
  - `(12,19) should stay open from south ... expected nil, got true`
  - `(16,16) should block the east approach ... expected true, got nil`
  The new Brecconary permanent-blocker assertion passed.

## Next Steps

Reload Lua before the next Brecconary survey so the `(17,22)` trap-cell patch is
active. A fresh parked survey should no longer route into `(17,22)`; remaining
failures should become either clean gated/isolated targets or expose the next
real hidden wall.
