# Current Investigation Scratchpad

Updated: 2026-05-26

The long Tantegel Castle map `0x04` shrine/key-merchant investigation and the
Sun Shrine `0x0C` decode pass are parked. Current active work is Garinham /
Garin's Grave entrance discovery on map `0x09`.

## Fresh Live State

- Latest baseline:
  - `POSITION: map=0x09(Garinham) x=19 y=11`
  - `RUNTIME_BLOCKS map=0x09 none`
- Final cleanup ran `reset_movement_state:after_reverse_analysis_restore` at
  `(19,11)` after clearing temporary runtime blockers from the verifier pass.
- Treat the idle `LeftAlt` as the known benign FCEUX latch unless bridge input
  or actual movement evidence says otherwise.

## Verified Garinham Facts

- Old `(19,16)` east-door object is false. Selected-object teleport to
  `(19,17)` facing north followed by OPEN reported `There is no door here`.
- Door-RAM seed tests did not open `(13,4)`, `(19,7)`, or `(19,9)`.
- The grey-building grave-route door is now modeled as door cell `(17,10)`,
  opened from stand `(17,9)` facing south. Evidence is the user's manual
  Magic Key/OPEN pass while working backward from the confirmed grave stairs,
  plus fresh `DOOR_STATE keys=5 slots=0=(17,10)` after that OPEN. The earlier
  `(18,9)` estimate is not a door override.
- `(3,4)->UP` into `(3,3)` moved 6/6 after stability recheck. `(3,3)` is now a
  Garinham passthrough.
- Old Man 3 at `(14,1)` is browseable but not an NPC blocker. Earlier movement
  evidence around that cell was superseded by the door-to-grave trail-blazing
  run: with no NPC at `(14,1)`, `probe_edge_verify:RIGHT,5` from `(13,1)`
  blocked 5/5. The reverse grave-stairs-to-door run later confirmed
  `(15,1)->LEFT` into `(14,1)` blocks 5/5 too, so both east and west approaches
  into `(14,1)` are directional engine seams.
- The same trail-blazing run found and verified the lower hidden bridge:
  route frontier proposed `(19,11)->UP` into `(19,10)`, and
  `probe_edge_verify:19,11,UP,5` moved 6/6 including stability recheck.
- The alternate hidden-bridge candidate `(13,1)->DOWN` into `(13,2)` was
  checked and blocked 5/5; the model already treated `(13,2)` as not walkable.
- Direct top-edge proof:
  - `(18,1)->UP` moved into standable `(18,0)`.
  - `(18,0)->UP` changed to `0x01` / World Map and landed near Garinham.
  - This is a world-map exit edge, not the grave stairs.
- True Grave of Garinham entrance proof:
  - ROM stair-down table entry `09 13 00` at file offset `0xF411` points to
    Garinham `(19,0)`.
  - Live command-menu STAIRS from `(19,0)` produced
    `EVENT: map change -> 0x18 (Garin's Grave B1)`.
  - User manual follow-up confirmed B1 arrival at `(6,1)` and return stairs
    back to Garinham `(19,0)`.

## Verified Blockers And Opens

- Permanent directional blockers added for confirmed grave-route geometry:
  `(6,12).east/south`, `(5,12).south`, row-9 south approaches from `x=7..14`,
  `(13,3).west`, `(13,4).west`, `(13,5).west`, `(13,6).west/south`, row-6
  south approaches from `x=14..18`, `(19,7).west`, `(19,8).west`,
  `(19,9).west`, `(18,14).east`, `(14,1).east/west`, `(15,10).south`,
  `(16,10).south`, and reverse top-row blockers `(15..18,2).north`.
- `MAP_PASSTHROUGH_CELLS[0x09]["19,10"]` is now added for the lower bridge
  from `(19,11)->UP`.
- Keep `(15,10).west` open: `(14,10)->RIGHT` moved 6/6.
- Keep `(4,12).south` open: `(4,13)->UP` moved 6/6.
- Keep `(19,2).north` unpromoted for now: direct verifier from
  `(19,1)->DOWN` was mixed (`moved=2 blocked=3`), not clean blocker evidence.

## Executor Follow-Up

- After the map patch, `reload_navigation_modules` made the model see both
  `(14,1).west` and `(19,10)`, and `debug_pathfind_to:19,0` found a route from
  `(13,1)`: `2 west, 10 south, 8 east, 11 north`.
- A pre-reload autowalk using the already-loaded `auto_step.lua` reached
  `(19,11)` and then timed out going up into `(19,10)`. A direct probe at the
  same live position logged stale movement bytes (`move=0x40 sub=0x90`) while
  the model correctly reported `(19,10)` as passable.
- Source patch: `auto_step.lua` now clears movement state/subpixel bytes during
  queued route turn/final settle frames, with default-on config key
  `auto_step_reset_movement_on_route_turn_settle`.
- This needs a full Lua script reload or relaunch before live autowalk can
  prove the executor fix; `reload_navigation_modules` does not reload
  `auto_step.lua`.
- Reloaded reverse autowalk from Garinham `(19,0)` toward `Grave Route Door`
  drifted through a town/world exit, not a new door: after moving right into
  `(19,1)`, the log recorded `EVENT: map change -> 0x01 (World Map)` at frame
  `08396`, then route drift at world-map `(2,2)`.
- Clean reverse verifiers promoted `(18,2).north`, `(17,2).north`,
  `(16,2).north`, `(15,2).north`, and `(14,1).east`. Runtime-injecting those
  clean blockers made `debug_pathfind_to:17,9` from `(19,0)` report no path,
  so the grave-stairs-to-door reverse route is currently unresolved/one-way.

## Next Investigation Loop

- Do not keep retrying the reverse route from `(19,0)` to the door as if it
  were one missing wall. The next useful validation is the forward route from
  opened `Grave Route Door` to `Stairs to Garin's Grave`, or Grave B1 decode
  from confirmed arrival `(6,1)`.
- `DOOR_STATE` already confirmed slot `0=(17,10)` after the door open; rerun
  `report_door_state` only if live behavior looks stale after reload.
- Begin a focused Grave B1 decode from confirmed arrival `(6,1)` if the route
  succeeds.
- Use short command batches:
  - `report_position`
  - direct `teleport_to:X,Y` followed by `report_position`
  - one `probe_edge:DIR`
  - immediate `report_position`
- Avoid long raw movement or queued movement batches while FCEUX stale input is
  noisy.
- The town-side entrance search is complete; stop re-testing `(18,0)` and
  `(19,0)` unless a regression appears.
