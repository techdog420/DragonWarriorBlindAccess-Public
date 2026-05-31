# Current Investigation Scratchpad

Updated: 2026-05-30

The long Tantegel Castle map `0x04` shrine/key-merchant investigation and the
Sun Shrine `0x0C` decode pass are parked. Current active work is Garin's Grave
B1 map `0x18`, specifically the forward route from entrance stairs `(6,11)` to
the next-level stairs `(1,18)`.

## Fresh Live State

- 2026-05-30 overnight wrap-up baseline from the still-live script:
  - `report_position` => `POSITION: map=0x18(Garin's Grave B1) x=6 y=11`
  - `report_runtime_blocks` => `RUNTIME_BLOCKS map=0x18 none`
  - `debug_route_frontier:1,18,60` =>
    `reachable=243 target_reachable=false target_side=83 candidates=159 bridge_candidates=57 hidden_bridge_candidates=0`
  - `debug_pathfind_to:1,18` =>
    `No path found [no_path] (visited=291 path=0)`
  - No stored runtime blockers remained to sync into `map_reader.lua` during
    this wrap-up pass.
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

## 2026-05-27 Garin's Grave B1 object decode

- Current live anchor: map `0x18` / Garin's Grave B1 at `(6,11)`.
- User manually disproved the older B1 `Stairs Down` object at `(19,0)`.
- Local ROM table evidence:
  - stair-down entry `18 01 12` at file offset `0xF456`, so B1 down stairs are `(1,18)`.
  - chest entries on map `0x18`: `(11,0)` content `0x02`, `(12,0)` content `0x12`, `(13,0)` content `0x13`.
- Live inspect evidence:
  - `(1,18)` is walkable on map `0x18`.
  - `(11,0)`, `(12,0)`, `(13,0)` are engine-boundary cells.
  - `(11,1)`, `(12,1)`, `(13,1)` are walkable stand tiles for the top-edge chests.
- Code patch direction: preserve ROM chests with `y=0`; route them through north-facing stands on row `1` when available.
- Pending: manual/live content confirmation for B1 chests, southeast door coordinate/opened-door RAM, and STAIRS transition proof from `(1,18)` to map `0x19`.
- Correction after user moved back to the chest area: live object line showed player `(11,1)` with old selected chest modeled at `(11,0)` and stand `(11,1)`. User confirmed moving above row `0` exits the map, so B1 raw ROM row `0` chest entries should be exposed as gameplay row `1`, not as off-map objects with stand tiles.
- Patched B1-specific chest normalization to expose `(11,1)`, `(12,1)`, and `(13,1)`.
- Correction after row-1 probe: row `1`/`2` TAKE attempts around x=11..13 did not open treasure. The early live log showed the hero had actually started on `(11,0)`, and SEARCH at `(11,0)` reported `There is a treasure box.` A forced `(12,0)` probe held stable and SEARCH also reported `There is a treasure box.` Forced `(13,0)` held stable through teleport guard, but the follow-up menu probe selected TALK due cursor reset. Conclusion: keep B1 chest objects at raw ROM row `0`, and add only `(11,0)`, `(12,0)`, `(13,0)` as B1 passthrough cells so pathing can reach them despite the generic dungeon y=0 boundary.
- Chest reward text follow-up: user validated all three B1 chests by walking/teleporting and opening them. `report_upper_dialogue_state` captured `lower="Of GOLD thou hast gained 12"` while `announced_lower="Ofthou hast gained 12"`. Root cause was the y<=3 cleanup stripping every 3+ letter uppercase run, including real reward token `GOLD`. Patch preserves uppercase game words and strips only known command labels plus old A-L map-tile noise.
- User validated the B1 chest dialogue fix in FCEUX; reward text now reads as expected.
- Northeast chest-row trail cutting toward `Stairs to Garinham` produced repeated blocked-only seam evidence and runtime blocks for B1:
  `(13,3).north`, `(10,2).east`, `(11,4).north`, `(10,3).east`, `(12,3).west`, `(10,1).east`, `(12,3).north`, and `(14,2).west`.
- Promoted those clean seams into `MAP_DIRECTIONAL_BLOCKS[0x18]` with a focused `test_map_reader.lua` regression. Do not promote `(11,1).south`: it was initially blocked but later moved and was classified noisy. Do not promote `(14,1).west` yet: it was only observed once before the route was interrupted by battle.
- Runtime-injected the same eight edge blockers with `add_blocked_edge`. `report_runtime_blocks` reported `count=5` because runtime blocks are grouped by source cell: `(11,1).west`, `(11,2).west`, `(11,3).east/south/west`, `(12,2).south`, and `(13,2).east/south`.
- Follow-up successful return route from the chest area to `(6,11)`:
  - New repeated blocked-only seams promoted: `(14,2).north`, `(14,2).east`, `(15,3).north`, `(16,3).north`, `(17,8).north`, `(5,10).north`, `(6,8).north`, and `(7,8).north`.
  - Suspicious/noisy seams not promoted because they later moved: `(14,1).west`, `(15,1).west`, `(17,2).west`, `(14,7).east`, `(6,7).east`, and `(5,7).east`.
  - Route completion evidence: final route from `(5,9)` detoured through `(6,9)`, `(6,10)`, and completed at `(6,11)` with passable-only observations on the final approach.
  - Runtime-injected the new promoted seams; live `report_runtime_blocks` now reports `map=0x18 count=12`, grouped by source cell/direction.
- Follow-up entrance-to-chest route:
  - Fresh repeated blocked-only route evidence appeared on `(15,3).south`, `(16,4).west`, `(14,4).east`, `(16,5).west`, `(14,5).east`, `(16,6).west`, `(14,6).east`, and `(17,1).south`.
  - Direct probes promoted the first seven: each `probe_edge_verify` result was confirmed blocked 5/5 with no drift, map change, or interruption.
  - Do not promote `(17,1).south`: direct `probe_edge_verify:17,2,UP,5` was mixed (`moved=2 blocked=3`).
  - Noisy route-only seams also left unpromoted: `(16,7).west`, `(17,7).west`, `(15,2).east`, `(12,1).east`, and `(11,0).east`.
  - Runtime-injected the seven promoted edges; live `report_runtime_blocks` now reports `map=0x18 count=15`, grouped by source cell/direction.
- Later chest/entrance repeat route, likely combat/NPC-parking detour:
  - Route-only blocked candidates included `(10,1).west`, `(10,2).west`, `(10,3).west`, `(10,4).west`, `(10,4).south`, `(11,4).south`, `(12,5).west/east`, `(12,6).west/south/east`, `(13,3).south`, `(12,4).east`, `(14,4).west`, `(14,5).west`, `(14,6).west/south`, `(16,6).south`, and another `(17,1).south`.
  - Direct probes completed before battle promoted only five clean 5/5 blockers: `(10,3).west`, `(10,4).west`, `(11,4).south`, `(12,5).west`, and `(12,6).west`.
  - Direct probes left these unpromoted: `(10,1).west` mixed (`moved=2 blocked=3`), `(10,4).south` mixed (`moved=4 blocked=1`), `(12,5).east` mixed (`moved=2 blocked=3`), and `(12,6).south` mixed (`moved=1 blocked=4`).
  - Probe interruptions left these unpromoted/pending: `(10,2).west` interrupted by upper dialogue, `(12,6).east` interrupted after battle started, and the remaining unprobed route-only candidates after battle should wait for a clean field state.
  - Runtime-injected the five promoted edges; live `report_runtime_blocks` reported `map=0x18 count=4`, grouped by source cell/direction.
- Fresh near-chest repeat/probe pass:
  - Direct probes promoted seven clean 5/5 blockers: `(12,4).east`, `(14,4).west`, `(12,5).east`, `(14,5).west`, `(12,6).east`, `(14,6).west`, and `(14,6).south`.
  - `(12,5).east` and `(12,6).east` supersede earlier mixed/interrupted notes because this later pass was clean and uninterrupted.
  - Still unpromoted: `(13,3).south` mixed (`moved=1 blocked=4`) and `(12,6).south` mixed (`moved=2 blocked=3`).
  - Runtime-injected the seven promoted edges; live `report_runtime_blocks` now reports `map=0x18 count=8`, grouped by source cell/direction.
- Resumed post-battle verifier pass:
  - Promoted `(12,6).south`, `(10,6).south`, and `(16,6).south`; each direct verifier blocked 5/5 with no drift or map change.
  - Confirmed passable, do not promote: `(10,1).west` moved 6/6 and `(17,3).south` moved 6/6.
  - Follow-up cleanup promoted `(13,3).south`, `(10,4).south`, and `(10,2).west`; each direct verifier blocked 5/5 after the interrupted/mixed earlier observations were retried in clean field state.
  - Confirmed passable, do not promote: `(14,1).west` moved 6/6 with stability recheck after the older interrupted top-row candidate was retried.
  - Runtime-injected the three promoted edges; live `report_runtime_blocks` now reports `map=0x18 count=11`, grouped by source cell/direction.
- Continued route cleanup:
  - Promoted `(8,8).north`, `(6,8).south`, `(17,1).south`, and `(16,6).east`; each direct verifier blocked 5/5 with no drift, map change, or interruption.
  - Left noisy/moved route-only seams unpromoted: row-7 east/west bumps, `(9,11).north`, `(9,1).south`, `(15,2).east`, `(15,1).west`, `(17,2).west`, and chest-adjacent top-row noise.
- Near-finish cleanup:
  - Promoted `(16,5).east`; direct verifier from `(17,5)->LEFT` blocked 5/5 on the clean retry.
  - Left unpromoted at that point: `(16,1).west` mixed (`moved=2 blocked=3`), `(11,8).north` mixed (`moved=2 blocked=3`), and `(16,3).east` confirmed passable 6/6 with stability recheck.
- Follow-up detour cleanup:
  - Promoted `(16,3).east`; this supersedes the earlier passable verifier because the latest clean direct repeats from `(17,3)->LEFT` blocked 5/5 and then 6/6 after an interrupted retry had moved twice.
  - Left unpromoted: `(7,10).south` moved twice before upper-dialogue interruption, `(12,8).north` mixed (`moved=1 blocked=4`), `(16,1).west` rechecked passable 6/6 with stability, and `(10,1).west` stayed mixed (`moved=1 blocked=4`).
- Mixed-edge cleanup:
  - `(12,8).north` stayed mixed on stronger probe (`moved=4 blocked=4`); keep unmodeled.
  - `(10,1).west` stayed mixed on stronger probe (`moved=5 blocked=3`); keep unmodeled.
  - Promoted `(7,10).south`; after one more upper-dialogue interruption with movement, a clean direct retry blocked 8/8.
- User-suspected `(19,1)->east` edge checked directly:
  `probe_edge_verify:19,1,RIGHT,5` blocked 5/5 with no drift, map change,
  refusal, or interruption. `inspect_move:19,1,RIGHT` reports destination
  `(20,1)` as `reason=out_of_bounds` on a `20x20` B1 map, so this is already
  modeled by bounds logic and should not be promoted into `MAP_DIRECTIONAL_BLOCKS[0x18]`.
- Follow-up planner audit:
  current-object/pathfind output from `(9,1)` to chest `(11,0)` was
  `2 east, 1 north`; forced debug pathing from `(19,1)` to `(11,0)` was
  `8 west, 1 north`, with trace `(19,1)->...->(11,0)`. A direct forced route
  to `(20,1)` returned no path. Small diagnostic patch: out-of-bounds debug
  goals now report `goal_out_of_bounds` instead of a bare `No path found`.
- User-suspected `(18,11)->north` edge checked directly:
  `inspect_move:18,11,UP` previewed `(18,10)` as walkable tile `0` with no
  directional block. `probe_edge_verify:18,11,UP,5` then confirmed passable
  with `moved=6 blocked=0`, stability recheck true, and no drift, map change,
  refusal, or interruption. Keep this edge open.
- User manual follow-up exposed the real offender at current live position
  `(8,11)->north`, not `(18,11)->north`. Baseline had
  `POSITION map=0x18 x=8 y=11`, no menu/dialogue, no NPC/runtime blockers, and
  only the benign `LeftAlt` latch. `inspect_move:8,11,UP` initially previewed
  open, but `probe_edge_verify:UP,5` from the live tile blocked 5/5 with
  no drift, map change, refusal, or interruption. Promoted `(8,10).south` into
  `MAP_DIRECTIONAL_BLOCKS[0x18]`; live `inspect_move:8,11,UP` now reports
  `directional_blocked=true`, `approach_blocked=true`, and
  `effective_passable=false`. A fresh debug path to chest `(11,0)` now detours
  `(8,11)->(9,11)->...` instead of using the blocked north edge.
- Follow-up planner bug for `(19,1)->east` into out-of-bounds `(20,1)`:
  live `inspect_move:19,1,RIGHT` correctly reported `reason=out_of_bounds`,
  and direct `debug_pathfind_to:20,1` returned `No path found
  [goal_out_of_bounds]`. The bad surface was adjacent-mode planning:
  before the patch, `debug_pathfind_adjacent:20,1` chose stand `(19,1)`,
  traced `10 east`, and said `Face east` toward invalid `(20,1)`. Patched
  `pathfinder.pathfind_to_adjacent()` / `find_route_to_adjacent()` to reject
  out-of-bounds goals before adjacent-stand selection, and patched
  `route_manager` no-path inference to preserve `goal_out_of_bounds` instead
  of running a quiet adjacent probe that could relabel it as NPC clutter.
  Unit tests now cover both layers. FCEUX needs a full Lua reload/relaunch
  before the `route_manager.lua` diagnostic-message fix is live; plain
  `reload_navigation_modules` is enough only for the `pathfinder.lua` portion.
- Follow-up live audit after the user still heard/saw a bad chest route:
  - Current live planner state from `(9,1)` selected `Chest` at `(11,0)` and
    planned only `(9,1)->(10,1)->(11,1)->(11,0)`.
  - Live `debug_pathfind_adjacent:20,1` now reports `No path found
    [goal_out_of_bounds]` with `visited=0`; the invalid adjacent-goal surface is
    rejected in the running script.

## 2026-05-27 B2-stairs batch loop

- First batched lower-middle B1 pocket cleanup promoted these clean 8/8 direct
  verifier blockers into `MAP_DIRECTIONAL_BLOCKS[0x18]`:
  - `(16,15).south` from `(16,16)->UP`
  - `(17,14).south` from `(17,15)->UP`
  - `(16,15).east` from `(17,15)->LEFT`
  - `(18,15).west` from `(17,15)->RIGHT`
  - `(18,15).south` from `(18,16)->UP`
- `luac5.1 -p map_reader.lua test_map_reader.lua`,
  `lua5.1 test_map_reader.lua`, and `git diff --check -- map_reader.lua test_map_reader.lua`
  all passed after the batch patch.
- After `reload_navigation_modules` and `clear_blocked_tiles`, the previously
  noisy west-approach revisits were retried cleanly:
  - `(17,16).west` is confirmed passable 9/9 from `(16,16)->RIGHT`
  - `(18,16).west` is confirmed passable 9/9 from `(17,16)->RIGHT`
- The interrupted retry on `(18,16).west` was not map evidence; it was caused
  by a leftover submenu after battle/HEAL. Backing out with raw `B` input
  cleared it, and the next direct verifier completed normally.
- Second batch eventually promoted these clean 8/8 direct verifiers into
  `MAP_DIRECTIONAL_BLOCKS[0x18]`:
  - `(18,14).east` from `(19,14)->LEFT`
  - `(18,15).east` from `(19,15)->LEFT`
  - `(19,12).south` from `(19,13)->UP`
  - `(17,12).east` from `(18,12)->LEFT`
  - `(17,11).east` from `(18,11)->LEFT`
- Third batch then followed the live north-hook reroutes and promoted these
  clean 8/8 direct verifiers:
  - `(16,11).north` from `(16,10)->DOWN`
  - `(16,12).south` from `(16,13)->UP`
  - `(14,10).east` from `(15,10)->LEFT`
  - `(10,9).east` from `(11,9)->LEFT`
  - `(11,10).north` from `(11,9)->DOWN`
- Post-batch verification stayed clean: `luac5.1 -p map_reader.lua test_map_reader.lua`,
  `lua5.1 test_map_reader.lua`, and `git diff --check -- map_reader.lua test_map_reader.lua`
  all passed again after fixing a duplicate-key merge on `(10,9)`.
- After `reload_navigation_modules` and `clear_blocked_tiles`, the permanent
  model rerouted from `(11,9)` through `(12,9)` instead of the old dead ends.
  `validate_path` then failed cleanly on `(12,9)->DOWN`, and
  `probe_edge_verify:12,9,DOWN,8` confirmed `(12,10).north` blocked 8/8.
  It is runtime-injected only so far as the first seed for the next batch.
- Fourth batch then climbed the upper hook and promoted these clean 8/8 direct
  verifiers:
  - `(12,10).north` from `(12,9)->DOWN`
  - `(13,10).north` from `(13,9)->DOWN`
  - `(14,10).north` from `(14,9)->DOWN`
  - `(11,8).south` from `(11,9)->UP`
  - `(12,8).south` from `(12,9)->UP`
- Post-batch verification stayed clean again:
  `luac5.1 -p map_reader.lua test_map_reader.lua`,
  `lua5.1 test_map_reader.lua`, and
  `git diff --check -- map_reader.lua test_map_reader.lua` all passed.
- After `reload_navigation_modules` and `clear_blocked_tiles`, the next
  permanent reroute from `(12,9)` now uses the upper lane:
  `(12,9)->(13,9)->(13,8)->(12,8)->(11,8)->(10,8)->(10,9)->(10,10)->...`.
  `validate_path` then failed cleanly on `(13,9)->UP`, and
  `probe_edge_verify:13,9,UP,8` confirmed `(13,8).south` blocked 8/8.
  It is runtime-injected only so far as the first seed for the next batch.
  - A controlled teleport to B1 entrance `(6,11)` plus route previews for all
    five current objects showed no route to `(20,1)`: the three chest routes
    are `3 east, 10 north, 2/3/4 east, 1 north`, return stairs are already
    there, and B2 stairs are `7 south, 5 west`.
  - Controlled `auto_walk` from `(6,11)` toward the first chest reproduced a
    separate execution problem: several route steps timed out once, seam retry
    then moved them, and `(10,1)` west-approach blocked twice before being
    treated as a temporary route block. The reroute then detoured far east via
    row 7 (`(9,7)->...->(17,7)`) before a battle interrupted at `(15,2)`.
    This explains an east-drifting/detour feel, but it is not a planner route
    into out-of-bounds `(20,1)`. Do not promote those noisy/timing seams without
    clean post-battle `probe_edge_verify` evidence.
- Fresh manual-route double-check superseded the older mixed/passable
  `(10,1).west` notes. The offender is `(9,1)->RIGHT` into `(10,1)`, while
  `(19,1)->RIGHT` remains correctly out of bounds. Baseline path debug traced
  `(9,1)->(10,1)->(11,1)->(11,0)`, `inspect_move:9,1,RIGHT` showed the west
  approach into `(10,1)` still open in the model, and
  `probe_edge_verify:9,1,RIGHT,8` blocked 8/8 cleanly with no drift, map
  change, refusal, or interruption. Promote `(10,1).west`.
- Post-patch validation: `reload_navigation_modules` picked up the map-reader
  change, `inspect_move:9,1,RIGHT` now reports `approach_blocked=true` and
  `effective_passable=false`, and `debug_pathfind_to:11,0` no longer uses the
  short bad route. It planned a 27-step detour from `(9,1)` through row 7 and
  back west along row 1; `validate_path` walked the full route to `(11,0)` with
  `VALIDATE COMPLETE: 27/27 steps OK, 0 mismatches`. A few edges logged noisy
  timing observations, but each moved on retry and no new clean blocker was
  produced.
- User run-result audit after the `(10,1).west` patch:
  - Entrance-to-chest completed at `(11,0)`. `(9,11)->RIGHT` into `(10,11)`
    caused the main reroute, but direct `probe_edge_verify:9,11,RIGHT,8`
    stayed mixed (`moved=2 blocked=6`), so keep `(10,11).west` unmodeled.
  - Return-route evidence around `(16,1).west` was stronger: the route logs had
    repeated blocked-only runtime reroutes, and direct
    `probe_edge_verify:15,1,RIGHT,8` blocked 8/8 with no drift, map change,
    refusal, or interruption. Promote `(16,1).west`; this supersedes the older
    mixed/passable notes for that edge.
  - Post-patch live `reload_navigation_modules` made
    `inspect_move:15,1,RIGHT` report `approach_blocked=true` and
    `effective_passable=false`. The previewed chest-to-stairs route now avoids
    `(16,1)` by stepping south to `(15,2)` before crossing east. Validation
    walked 23/28 steps, then a random Warlock battle started at `(9,9)` and
    aborted the validator at step 24; do not treat that abort as map evidence.
- User follow-up run-result analysis after the route started feeling clean:
  - The latest full route completed to `Stairs to Garinham` at `(6,11)` with
    `RUNTIME_BLOCKS map=0x18 none`.
  - Two remaining route-only hotspots had enough clean evidence for direct
    checks: `(9,10)->LEFT` into `(8,10)` and `(9,9)->RIGHT` into `(10,9)`.
  - Direct `probe_edge_verify:9,10,LEFT,8` blocked 8/8 with no drift, map
    change, refusal, or interruption. Promote `(8,10).east`.
  - Direct `probe_edge_verify:9,9,RIGHT,8` blocked 8/8 with no drift, map
    change, refusal, or interruption. Promote `(10,9).west`.
  - Live reload verified both patched edges now inspect as
    `directional_blocked=true`, `approach_blocked=true`, and
    `effective_passable=false`; `RUNTIME_BLOCKS map=0x18 none`.
  - Restored hero to `(6,11)`. From there `debug_pathfind_to:1,18` previews
    the down-stairs route as `7 south, 5 west`, trace
    `(6,11)->(6,18)->(1,18)`, with runtime blocks still none.
- First live push toward `Stairs Down to B2`:
  - Autowalk from `(6,11)` started with the expected `7 south, 5 west` route,
    then route-temp blocked through the lower B1 maze wall band before a
    Warlock battle interrupted at `(11,16)`.
  - The first direct verifier on `(6,12)->DOWN` was contaminated by
    `PREV.upper_active=true` and returned `inconclusive_interrupted`.
    `report_upper_dialogue_state` later showed the upper text had settled to
    the status baseline with `active=false`, so the edge was retried cleanly.
  - Promoted clean direct 5/5 blockers: `(6,13).north`, `(5,12).east`,
    `(7,13).north`, `(8,13).north`, `(9,15).north`, `(6,15).north`,
    `(6,13).south`, `(7,15).north`, `(7,13).south`, `(8,15).north`, and
    `(8,13).south`.
  - Left unpromoted: `(5,14).east` was mixed on direct verifier
    (`moved=3 blocked=2`), despite earlier route-temp evidence.
  - After `reload_navigation_modules`, stale route-temp context still affected
    the first preview until `stop_auto_walk` cleared the active route context.
    The clean post-clear preview from `(8,14)` was `7 west, 4 south`, with no
    runtime blocks.
  - `validate_path` walked the first two west steps to `(7,14)` and `(6,14)`,
    then a Poltergeist battle started while attempting step 3 toward `(5,14)`.
    Treat that validation abort as combat contamination, not map evidence.
  - Source follow-up for the verifier contamination: `main.lua` now refreshes a
    stale cached `PREV.upper_active` inside the autowalk/edge-probe guards when
    the current screen has no lower dialogue/menu/submenu and the upper text is
    baseline/status/noise. This should stop status-only upper-window ghosts from
    blocking probes after teleport, while preserving real upper dialogue blocks.

- Follow-up B2-stairs autowalk/validator pass:
  - User resumed after monster cleanup. Baseline after `stop_auto_walk`:
    `POSITION map=0x18 x=12 y=16`, runtime blocks none, upper state inactive
    with status baseline only.
  - Route-log candidates were reduced before probing. Clean route-only
    evidence included the row-15/17/18 lower maze pocket; noisy/moved-on-retry
    candidates included `(10,14).east`, `(11,14).west`, `(9,16).west`, and
    `(12,16).west`.
  - Direct probes/promotions from the first verification sweep:
    `(5,14).east` blocked 5/5, `(10,15).north/south` blocked 5/5,
    `(11,17).north` blocked 5/5, `(5,18).north` blocked 5/5,
    `(5,16).south` blocked 5/5, `(7,17).north` blocked 5/5,
    `(7,15).south` blocked 5/5, `(8,15).south` blocked 5/5,
    `(7,17).east` blocked 5/5, `(9,17).west` blocked 5/5,
    `(9,17).north` blocked 5/5, `(9,15).south` blocked 5/5,
    `(10,17).north` blocked 5/5, and `(12,17).north` blocked 5/5.
  - Mixed/passable during first sweep: `(8,13).east` moved 6/6 on the first
    direct recheck, `(5,16).east` mixed `moved=4 blocked=1`,
    `(6,18).north` mixed `moved=1 blocked=4`, `(4,17).east` mixed
    `moved=1 blocked=4`, `(7,17).west` mixed `moved=1 blocked=4`, and
    `(8,18).north` mixed `moved=1 blocked=4`.
  - Re-examined acting-out mixed candidates during live `validate_path`.
    Each route-validator abort was followed by a stronger direct verifier:
    `(5,16).east`, `(6,18).north`, `(4,17).east`, `(7,17).west`,
    `(6,15).south`, `(8,18).north`, and `(8,13).east` each blocked 8/8
    cleanly after acting out under validation. All were promoted.
  - Additional validator-discovered blockers promoted after clean 8/8 direct
    checks: `(10,15).east`, `(11,13).south`, and `(5,11).east`.
  - Left unpromoted/noisy: `(10,14).east` blocked once but then moved during
    validation, and `(8,16).south` blocked once but then moved. Keep them open
    unless future direct verifier evidence is clean.
  - Latest live reload/preview after the final patch:
    `POSITION map=0x18 x=6 y=11`, runtime blocks none, upper state inactive
    status baseline only. `debug_pathfind_to:1,18` plans
    `1 north, 5 west, 8 south` via
    `(6,11)->(6,10)->(5,10)->...->(1,18)`. This final preview has not yet
    been live-validated after the `(5,11).east` patch; use it as the next
    autowalk/validation target.
- Follow-up autowalk blocker harvest after user resumed from `(6,11)`:
  - User's autowalk toward `Stairs Down to B2` reached the low-west pocket and
    was interrupted by a Droll/Warlock sequence around `(2,9)`. Baseline after
    dialogue cleanup was `map=0x18 x=2 y=9`, runtime blocks none, upper window
    status baseline only.
  - `(2,9)->DOWN` into `(2,10)` was route-suspicious but not promoted: direct
    `probe_edge_verify:2,9,DOWN,8` moved once, then battle interrupted attempt
    2.
  - `(3,7)->RIGHT` into `(4,7)` confirmed cleanly blocked 8/8, promoted as
    `(4,7).west`.
  - `(3,7)->DOWN` into `(3,8)` was initially mixed (`moved=4 blocked=4`), but
    the live validator then failed that first step three times in a row. A
    stronger direct `probe_edge_verify:3,7,DOWN,15` confirmed blocked 15/15, so
    `(3,8).north` is promoted.
  - Post-patch `reload_navigation_modules` verified both `(3,7)->DOWN` and
    `(3,7)->RIGHT` inspect with `approach_blocked=true` /
    `effective_passable=false`. The fresh preview from `(3,7)` to `(1,18)` is
    `2 west, 11 south`, tracing
    `(3,7)->(2,7)->(1,7)->...->(1,18)`.
  - `validate_path` walked step 1 to `(2,7)`, then a Warlock battle started
    while step 2 toward `(1,7)` was beginning. Treat the validator abort at
    `(2,7)` as combat contamination, not map evidence for `(1,7)`.

## 2026-05-28 Garin's Grave B1 continuation

- Latest probe result reached completion:
  - `probe_edge_verify:11,7,DOWN,15` ended with
    `classification=confirmed_blocked` on frame `63016`.
  - Result: `attempts=15`, `moved=0`, `blocked=15`, `runtime_added=false`,
    `manual_promotion_required=true`.
  - This confirms a live blocker at `(11,7)->DOWN`, equivalent to
    `(11,8).north` in directional-block terms.
- Scratchpad confirmation update:
  - Added `(11,8).north` to the confirmed runtime-pending blocker list.
  - Runtime injection is still needed before full map promotion.
- Runtime blocker status action planned/applied:
  - Added to runtime with `add_blocked_edge:0x18,11,8,north`.
  - Kept in scratchpad only (single blocker so far in this round, below 5-blocker
    patch threshold for direct `map_reader.lua` edits).
- Next loop step captured:
  - Continue from staircase anchor `(6,11)` on `0x18` and re-run
    `debug_pathfind_to:1,18` then `validate_path`.
- Re-audit after the next live validation pass:
  - `validate_path` from `(6,11)` again failed on the upper detour seam at
    `(12,7)->DOWN`, and a fresh `probe_edge_verify:12,7,DOWN,15` reconfirmed
    `classification=confirmed_blocked` with `moved=0 blocked=15`.
  - Confirmed direct-verifier blockers in this seam pocket are currently:
    `(10,8).north`, `(11,8).north`, and `(12,8).north`.
  - Runtime-only mirror edges also in active use for continued exploration are:
    `(10,7).south`, `(11,7).south`, and `(12,7).south`.
  - Keep those south-approach mirrors out of permanent `map_reader.lua` until
    a direct verifier from below confirms them cleanly.
  - After re-injecting the runtime seam set, planner rerouted from `(12,7)` as
    `1 east, 1 south, 3 west, 5 south, 4 east, 5 south, 13 west`.
  - Live validation then exposed the next blocker candidate immediately:
    `(13,7)->DOWN` into `(13,8)` failed three times and aborted at step 2/32.
  - Next direct-check target: `probe_edge_verify:13,7,DOWN,15`.
- Follow-up direct verification and reroute:
  - `probe_edge_verify:13,7,DOWN,15` confirmed `(13,8).north` blocked 15/15
    with no drift, map change, or interruption.
  - After runtime-injecting `(13,8).north`, planner rerouted as
    `2 east, 1 south, 5 west, 5 south, 4 east, 5 south, 13 west`.
  - Live validation advanced through `(14,7)->(15,7)->(15,8)` and then failed
    three times on `(15,8)->LEFT` into `(14,8)`.
  - `probe_edge_verify:15,8,LEFT,15` confirmed `(14,8).east` blocked 15/15
    with no drift, map change, or interruption.
  - This round now has a five-edge permanent batch ready to promote:
    `(10,8).north`, `(11,8).north`, `(12,8).north`, `(13,8).north`, and
    `(14,8).east`.
  - Keep the mirror south-approach seams at `(10,7)`, `(11,7)`, `(12,7)`, and
    `(13,7)` runtime-only until direct probes from below confirm them.
- Permanent promotion and post-patch live continuation:
  - The five-edge entrance-side batch is now promoted into `map_reader.lua`:
    `(10,8).north`, `(11,8).north`, `(12,8).north`, `(13,8).north`, and
    `(14,8).east`.
  - The row-7 south-mirror seams remain runtime-only on purpose:
    `(10,7).south`, `(11,7).south`, `(12,7).south`, and `(13,7).south`.
  - After the code patch, live `validate_path` from `(15,8)` advanced through
    `(15,9)`, `(15,10)`, and `(15,11)`, then failed three times on
    `(15,11)->LEFT` into `(14,11)`.
  - `probe_edge_verify:15,11,LEFT,15` then confirmed `(14,11).east` blocked
    15/15 with no drift, map change, or interruption, and that edge was added
    to runtime for continued exploration.
  - With `(14,11).east` runtime-injected, planner rerouted from `(15,11)` via
    `(15,12)->(14,12)->(13,12)->(13,11)` and then failed three times on
    `(13,11)->UP` into `(13,10)`.
  - `probe_edge_verify:13,11,UP,15` confirmed `(13,10).south` blocked 15/15
    with no drift, map change, or interruption. Runtime injection for the same
    edge used `add_blocked_edge:0x18,13,11,UP`.
  - After injecting `(13,10).south`, planner rerouted from `(13,11)` as
    `1 west, 1 north, 2 west, 3 south, 4 east, 5 south, 13 west`.
  - Live validation advanced to `(12,11)` and then failed three times on
    `(12,11)->UP` into `(12,10)`.
  - `probe_edge_verify:12,11,UP,15` confirmed `(12,10).south` blocked 15/15
    with no drift, map change, or interruption. Runtime injection of this edge
    was queued immediately with `add_blocked_edge:0x18,12,11,UP`.
  - Current next step: continue the reroute from live `(12,11)` and harvest
    the next blocker in the same upper-hook band before considering the next
    permanent `map_reader.lua` batch.
  - Follow-up reroute after injecting `(12,10).south` advanced through
    `(13,11)->(13,12)->(14,12)` and then failed three times on
    `(14,12)->UP` into `(14,11)`.
  - `probe_edge_verify:14,12,UP,15` confirmed `(14,11).south` blocked 15/15
    with no drift, map change, or interruption. Runtime injection used
    `add_blocked_edge:0x18,14,12,UP`.
  - With `(14,11).south` added at runtime, planner rerouted through
    `(15,12)->(15,11)->(15,10)->(15,9)->(14,9)->(13,9)` before failing three
    times on `(13,9)->UP` into `(13,8)`.
  - Strong recheck now in progress:
    `probe_edge_verify:13,9,UP,15` is the current live command. Earlier
    session evidence had already confirmed this same edge as blocked 8/8; the
    current reroute is re-verifying it under the stronger 15-attempt standard
    so it can join the same south-approach promotion batch cleanly.
  - Strong recheck finished cleanly:
    `probe_edge_verify:13,9,UP,15` confirmed `(13,8).south` blocked 15/15
    with no drift, map change, or interruption. Runtime injection used
    `add_blocked_edge:0x18,13,9,UP`.
  - With `(13,8).south` now live at runtime, planner rerouted from `(13,9)` as
    `1 east, 1 north, 4 west, 5 south, 4 east, 5 south, 13 west`.
  - The next direct verifier also finished cleanly:
    `probe_edge_verify:14,9,UP,15` confirmed `(14,8).south` blocked 15/15
    with no drift, map change, or interruption.
  - Follow-up runtime injection was queued with `add_blocked_edge:0x18,14,9,UP`
    so `validate_path` can continue without waiting for a script reload.
  - This completes a clean five-edge south-approach promotion batch for the
    upper-hook pocket:
    `(12,10).south`, `(13,10).south`, `(14,11).south`, `(13,8).south`, and
    `(14,8).south`.
  - With that final runtime edge in place, `debug_pathfind_to:1,18` from
    `(14,9)` collapsed to `No path found [no_path]` after `visited=280`.
    `PATH_RUNTIME_BLOCK` lines showed the live split now hinges on the
    upper-hook seams we just confirmed.
  - `debug_route_frontier:1,18` and `debug_route_frontier_skip_npcs:1,18`
    agreed on the split: `reachable=243`, `target_reachable=false`,
    `target_side=121`, `bridge_candidates=135`, `hidden_bridge_candidates=0`.
    The best-ranked bridges were all already-modeled runtime seams in the
    upper hook; after those, the nearest target-side directional walls were
    `(2,15).north`, `(1,14).east`, `(5,18).north`, and `(4,17).east`.
  - A review-only `crawl_map_frontier:attempts=5,max_edges=300` from live
    `(14,9)` was started to look for any still-unmodeled openings before
    re-auditing older blockers. It reclassified only known local edges before
    battle interrupted it:
    `(14,9)->UP`, `(14,9)->DOWN`, `(13,9)->UP`, `(13,9)->DOWN`, and
    `(12,9)->UP/DOWN` all logged `class=modeled_blocked`, while
    `(14,9)->LEFT`, `(13,9)->LEFT`, and `(12,9)->LEFT` were `class=open_floor`.
  - The crawl ended at `MAP_CRAWL_EDGE index=10` with `class=auto_step_lost`
    when a battle started on the `(11,9)->UP` attempt. Final partial summary:
    `edges=10`, `passthrough_candidates=0`, `directional_candidate_cells=0`,
    `door_frontiers=0`, `transitions=0`.
  - Next manual spot-audit after combat clears:
    `probe_edge_verify:2,14,DOWN,15`,
    `probe_edge_verify:2,14,LEFT,15`,
    `probe_edge_verify:5,17,DOWN,15`, and
    `probe_edge_verify:5,17,LEFT,15`.
  - Post-battle low-west spot-audit finished cleanly on all four queued
    bridge-wall checks. Each direct verifier blocked 15/15 with no drift, map
    change, or interruption, so none of these were stale false positives:
    `(2,15).north` from `(2,14)->DOWN`,
    `(1,14).east` from `(2,14)->LEFT`,
    `(5,18).north` from `(5,17)->DOWN`, and
    `(4,17).east` from `(5,17)->LEFT`.
  - Target-side frontier pivot:
    after teleporting to `(1,18)`, `debug_route_frontier:6,11` reported
    `target_reachable=true`, and `debug_pathfind_to:6,11` found a reverse path:
    `3 east, 2 north, 1 east, 5 north, 1 east`.
  - That reverse route does **not** imply the forward route is solved.
    Teleporting back to entrance stairs `(6,11)` and running
    `debug_pathfind_to:1,18` still returned `No path found [no_path]`.
  - Exact reverse-step audit then exposed a concrete one-way seam right at the
    entrance-side kickoff:
    `probe_edge_verify:6,11,LEFT,15` confirmed `(5,11).east` blocked 15/15
    with no drift, map change, or interruption.
  - Follow-up check showed `(5,11)` is not reachable from `(6,11)` by any
    alternate route in the current live model:
    `debug_pathfind_to:5,11` returned `No path found [no_path]`.
  - Frontier targeting nuance:
    `debug_route_frontier:1,18` from `(6,11)` still ranked the broader
    bridge-to-target seams first and did not surface `(6,11)->LEFT` in the top
    24. But retargeting specifically to `debug_route_frontier:5,11` did
    surface the local one-way barrier pocket, with top local candidates:
    `(6,11)->LEFT` into `(5,11)`,
    `(4,11)->RIGHT` into `(5,11)`,
    `(6,12)->LEFT` into `(5,12)`,
    `(6,10)->LEFT` into `(5,10)`,
    and nearby row-13/14 north/east/west faces around the same `x=5` column.
  - Current live verifier in progress:
    `probe_edge_verify:6,12,LEFT,15` finished cleanly:
    `(5,12).east` is confirmed blocked 15/15 from `(6,12)->LEFT`, again with
    no drift, map change, or mismatch.
  - Local barrier picture so far:
    the east face of the `x=5` reverse-route column is now directly confirmed
    blocked at least at rows `11` and `12` from the entrance-side component:
    `(5,11).east` and `(5,12).east`.
  - New follow-up verifier now in progress:
    `probe_edge_verify:6,14,LEFT,15` is testing `(5,14).east` from the same
    side. Latest observed state before this note update:
    attempts 1 through 8 all blocked cleanly with `mismatch=none`.
- Restart-era hidden-cell hunt follow-up on 2026-05-28:
  - Fresh launcher baseline after the log rollover landed at
    `POSITION map=0x18 x=6 y=14` with `RUNTIME_BLOCKS map=0x18 none`.
    Teleporting back to the entrance stairs `(6,11)` under that clean state
    changed the planner picture substantially: `debug_pathfind_to:5,11` and
    `debug_pathfind_to:1,18` both found full routes again, so the earlier
    entrance-side isolation was at least partly caused by stale/runtime-only
    blockers rather than a permanent split.
  - Current clean forward route from `(6,11)` to B2 `(1,18)` under the cleared
    runtime overlay was:
    `3 east, 4 north, 6 east, 4 south, 1 west, 1 north, 4 west, 3 south,
    4 east, 5 south, 13 west`.
  - `validate_path` needs a stored debug route, not plain `pathfind_to`.
    `pathfind_to:1,18` followed by `validate_path` logged
    `VALIDATE: no path to validate`; `debug_pathfind_to:1,18` followed by
    `validate_path` worked.
  - Fresh live validation from `(6,11)` advanced cleanly through 17 steps to
    `(15,11)`. Only one early suspicious edge stayed noisy rather than
    confirmed blocked:
    `SEAM_OBSERVATION` on `(10,7).west` first logged `blocked_only`, then the
    validator retry moved successfully and downgraded it to `classification=noisy`.
    Keep `(10,7).west` unpromoted.
  - First clean new blocker after the restart:
    live validation from `(15,11)` failed three times on `(15,11)->LEFT`
    into `(14,11)`, aborting at `17/48` steps completed.
  - Strong direct recheck:
    `probe_edge_verify:15,11,LEFT,15` confirmed `(14,11).east` blocked 15/15
    with no drift, map change, or interruption. Summary line:
    `classification=confirmed_blocked`, `moved=0`, `blocked=15`,
    `blocked_model_mismatch=15`, `manual_promotion_required=true`.
  - The model-mismatch detail is important. The verifier preview showed the
    destination cell already had *some* static directional data but not this
    specific east approach:
    `directional_blocked=true`, `blocked_approach=east`,
    `approach_blocked=false`, `effective_passable=true`.
    The current permanent map entry only has `(14,11).west` and `.south`, so
    `(14,11).east` is a clean missing permanent directional block.
  - Runtime injection nuance:
    `add_blocked_edge` is source-and-direction based. The first mistaken
    injection `add_blocked_edge:14,11,east` created the reverse runtime block
    at `cell=(15,11) dirs=west`. After `clear_blocked_tiles`, the corrected
    injection `add_blocked_edge:15,11,left` produced the intended runtime
    block: `RUNTIME_BLOCK map=0x18 x=14 y=11 key=14,11 dirs=east`.
  - With `(14,11).east` correctly injected at runtime, planner from the live
    current-side tile `(15,11)` collapsed back to
    `Debug pathfind_to (1,18): No path found [no_path] (visited=278 path=0)`.
    `PATH_RUNTIME_BLOCK map=0x18 x=14 y=11 context=neighbor` confirmed the
    new runtime edge participates in that split.
  - Current frontier picture from the corrected `(15,11)` no-path state:
    `debug_route_frontier:1,18` and `debug_route_frontier_skip_npcs:1,18`
    agree on `reachable=243`, `target_reachable=false`, `target_side=121`,
    `bridge_candidates=135`, `hidden_bridge_candidates=0`.
    Top-ranked bridge candidates are:
    `(15,11)->LEFT` into `(14,11)` as `blocked_runtime`,
    then the already-known low-west target-side walls
    `(2,15).north`, `(1,14).east`, `(5,18).north`, and `(4,17).east`.
    The next nearby local bridge ranks include `(6,15).north`,
    `(5,14).east`, `(5,14).west`, and `(5,16).east/south`.
  - Current interpretation:
    no new hidden-bridge candidates are surfacing from route frontier after
    correcting `(14,11).east`; the next useful step is a review-only frontier
    crawl from the current `(15,11)`-side component to see whether the local
    `x=5` / lower-left bridge cluster hides any still-unmodeled openings.
- Post-warlock hidden-cell / misclassification follow-up later on 2026-05-28:
  - Review-only crawl from the current-side pocket resumed at `(15,5)` and then
    at `(15,4)`, but both runs were interrupted by combat before any
    candidates/export-worthy seams appeared.
  - Before the second interruption, the crawl tried `(15,4)->LEFT` into
    `(14,4)`. Direct live recheck from the same tile showed the loaded script
    already models that seam correctly:
    `inspect_move:LEFT` reported `directional_blocked=true`,
    `approach_blocked=true`, and `effective_passable=false` for `(14,4)`.
    So the crawl poke there is not evidence of a hidden opening or a stale
    unloaded patch.
  - Route-frontier sanity checks from the current-side component at `(15,4)`,
    including the `allow_hazards` variants, still agree on
    `hidden_bridge_candidates=0`. Allowing hazards does not expose a hidden
    bridge between the entrance-side and B2-side components.
  - Strong target-side falsification probes then reinforced the "real sealed
    split" picture:
    - `(4,15)->RIGHT` into `(5,15)` / `(5,15).west` blocked 15/15 with no
      drift, map change, interruption, or mismatch.
    - `(8,17)->DOWN` into `(8,18)` / `(8,18).north` blocked 15/15 with no
      drift, map change, interruption, or mismatch.
    - `(6,17)->RIGHT` into `(7,17)` / `(7,17).west` blocked 15/15 with no
      drift, map change, interruption, or mismatch.
  - New live suspect from the same lower-west frontier:
    `(8,17)->LEFT` into `(7,17)` / `(7,17).east` did not reconfirm as a clean
    blocker. A fresh 15-attempt verifier came back mixed `moved=1 blocked=14`,
    with attempt `1/15` landing cleanly on `(7,17)` in 22 frames and logging
    `EDGE_PROBE_MODEL_MISMATCH kind=moved_through_modeled_block`. Attempts
    `2..15` all blocked.
  - That mixed east-face result supersedes the older 5/5 blocker confidence
    for `(7,17).east`. Treat `(7,17).east` as suspicious/mixed again for now,
    not durably reconfirmed.
  - Immediate same-tile rerun of `probe_edge_verify:8,17,LEFT,15` started from
    a fresh launcher probe at `(8,17)` to test reproducibility. At this note
    update, the rerun is still in progress and had reached attempt `10/15`,
    with every observed attempt so far previewing
    `approach_blocked=true` / `effective_passable=false`.
  - That immediate rerun later finished cleanly: `(8,17)->LEFT` into
    `(7,17)` / `(7,17).east` blocked 15/15 with no drift, map change, or
    interruption. Treat the earlier `moved=1 blocked=14` result as transient
    verifier noise rather than durable passability evidence.
  - Follow-up north-face recheck also finished cleanly:
    `(7,16)->DOWN` into `(7,17)` / `(7,17).north` blocked 15/15.
  - Fresh target-side re-entry at B2 `(1,18)` exposed a directional split
    rather than a fully disconnected graph:
    `debug_pathfind_to:6,11` and `debug_pathfind_to:15,4` both found reverse
    routes from the B2-side component, while the forward entrance-side planner
    was still collapsing.
  - Reverse `validate_path` from `(1,18)` first advanced cleanly six steps to
    `(7,18)`, then failed three times on `(7,18)->RIGHT` into `(8,18)`.
    Strong direct recheck `probe_edge_verify:RIGHT,15` from `(7,18)` confirmed
    `(8,18).west` blocked 15/15 with
    `blocked_model_mismatch=15` / `manual_promotion_required=true`.
  - Runtime injecting that reverse-side seam with
    `add_blocked_edge:7,18,right` created
    `RUNTIME_BLOCK map=0x18 x=8 y=18 key=8,18 dirs=west` and rerouted the
    reverse planner instead of collapsing it. From `(7,18)`,
    `debug_pathfind_to:15,4` changed to
    `1 south, 7 east, 7 north, 1 east, 8 north`.
  - After combat interruptions on that rerouted branch, repeated resumed
    validations proved a new open lower lane before the next seam:
    `(7,19)`, `(8,19)`, `(9,19)`, `(10,19)`, `(11,19)`, and `(12,19)` all
    logged `classification=passable_only` from west or north approach as the
    reverse route advanced.
  - The next clean reverse-side blocker is now confirmed:
    live validation from `(12,19)` failed three times on `(12,19)->RIGHT`
    into `(13,19)`, and direct `probe_edge_verify:RIGHT,15` from `(12,19)`
    then confirmed `(13,19).west` blocked 15/15 with no drift, map change, or
    interruption. Summary line:
    `classification=confirmed_blocked`, `moved=0`, `blocked=15`,
    `blocked_model_mismatch=15`, `manual_promotion_required=true`.
  - Runtime injection with `add_blocked_edge:12,19,right` created
    `RUNTIME_BLOCK map=0x18 x=13 y=19 key=13,19 dirs=west`. With that live
    overlay plus the older `(8,18).west` and `(14,11).east` runtime seams,
    the reverse planner from `(12,19)` rerouted to:
    `2 north, 2 east, 5 north, 1 east, 8 north`.
  - The rerouted reverse validation immediately proved
    `(12,19)->UP` into `(12,18)` passable, then failed three times on
    `(12,18)->UP` into `(12,17)`.
  - Strong direct recheck `probe_edge_verify:UP,15` from `(12,18)` then
    confirmed `(12,17).south` blocked 15/15 with no drift, map change, or
    interruption. Summary line:
    `classification=confirmed_blocked`, `moved=0`, `blocked=15`,
    `blocked_model_mismatch=15`, `manual_promotion_required=true`.
  - Runtime injection with `add_blocked_edge:12,18,up` created
    `RUNTIME_BLOCK map=0x18 x=12 y=17 key=12,17 dirs=south` and rerouted the
    reverse planner from `(12,18)` to:
    `2 east, 6 north, 1 east, 8 north`.
  - That reroute immediately proved `(13,18).west` passable, then a battle
    interrupted the next east step before it could become seam evidence. After
    combat, the refreshed reverse planner from `(13,18)` rerouted again to:
    `1 north, 1 east, 5 north, 1 east, 8 north`.
  - Fresh resumed validation from `(13,18)` then failed three times on
    `(13,18)->UP` into `(13,17)`.
  - Strong direct recheck `probe_edge_verify:UP,15` from `(13,18)` confirmed
    `(13,17).south` blocked 15/15 with no drift, map change, or interruption.
    Summary line:
    `classification=confirmed_blocked`, `moved=0`, `blocked=15`,
    `blocked_model_mismatch=15`, `manual_promotion_required=true`.
  - Runtime injection with `add_blocked_edge:13,18,up` created
    `RUNTIME_BLOCK map=0x18 x=13 y=17 key=13,17 dirs=south` and rerouted the
    reverse planner from `(13,18)` to:
    `1 east, 6 north, 1 east, 8 north`.
  - Fresh validation from `(13,18)` then proved `(13,18)->RIGHT` into
    `(14,18)` passable, but failed three times on `(14,18)->UP` into
    `(14,17)`.
  - Strong direct recheck `probe_edge_verify:UP,15` from `(14,18)` confirmed
    `(14,17).south` blocked 15/15 with no drift, map change, or interruption.
    Summary line:
    `classification=confirmed_blocked`, `moved=0`, `blocked=15`,
    `blocked_model_mismatch=15`, `manual_promotion_required=true`.
  - Runtime injection with `add_blocked_edge:14,18,up` created
    `RUNTIME_BLOCK map=0x18 x=14 y=17 key=14,17 dirs=south` and rerouted the
    reverse planner from `(14,18)` to:
    `1 east, 1 north, 1 west, 5 north, 1 east, 8 north`.
  - That reroute failed three times immediately on `(14,18)->RIGHT` into
    `(15,18)`.
  - Strong direct recheck `probe_edge_verify:RIGHT,15` from `(14,18)`
    confirmed `(15,18).west` blocked 15/15 with no drift, map change, or
    interruption. Summary line:
    `classification=confirmed_blocked`, `moved=0`, `blocked=15`,
    `blocked_model_mismatch=15`, `manual_promotion_required=true`.
  - Runtime injection with `add_blocked_edge:14,18,right` created
    `RUNTIME_BLOCK map=0x18 x=15 y=18 key=15,18 dirs=west` and rerouted the
    reverse planner from `(14,18)` to:
    `1 south, 1 east, 2 north, 1 west, 5 north, 1 east, 8 north`.
  - That reroute proved `(14,19)` and `(15,19)` passable from the north and
    west respectively, then failed three times on `(15,19)->UP` into
    `(15,18)`.
  - Strong direct recheck `probe_edge_verify:UP,15` from `(15,19)` confirmed
    `(15,18).south` blocked 15/15 with no drift, map change, or interruption.
    Follow-up `report_runtime_blocks` and `inspect_move:15,19,UP` showed the
    live runtime still only had `(15,18).west`; the preview's
    `directional_blocked=true` was cell-level noise, while
    `approach_blocked=false` confirmed the south-approach verifier itself was
    not runtime-blocked. Summary line:
    `classification=confirmed_blocked`, `moved=0`, `blocked=15`,
    `blocked_model_mismatch=15`, `manual_promotion_required=true`.
  - Runtime injection with `add_blocked_edge:15,19,up` created
    `RUNTIME_BLOCK map=0x18 x=15 y=18 key=15,18 dirs=south,west` and rerouted
    the reverse planner from `(15,19)` to:
    `1 east, 2 north, 2 west, 5 north, 1 east, 8 north`.
  - That reroute proved `(16,19)` passable from the west and `(16,18)`
    passable from the south, then failed three times on `(16,18)->UP` into
    `(16,17)`.
  - Strong direct recheck `probe_edge_verify:UP,15` from `(16,18)` confirmed
    `(16,17).south` blocked 15/15 with no drift, map change, or interruption.
    Preview showed `static_directional_blocked=true`, `runtime_directional_blocked=false`,
    and `approach_blocked=false`, so this is another clean one-way south
    approach rather than runtime contamination. Summary line:
    `classification=confirmed_blocked`, `moved=0`, `blocked=15`,
    `blocked_model_mismatch=15`, `manual_promotion_required=true`.
  - Runtime injection with `add_blocked_edge:16,18,up` created
    `RUNTIME_BLOCK map=0x18 x=16 y=17 key=16,17 dirs=south` and rerouted the
    reverse planner from `(16,18)` to:
    `1 west, 1 north, 1 west, 5 north, 1 east, 8 north`.
  - That reroute failed three times immediately on `(16,18)->LEFT` into
    `(15,18)`.
  - Strong direct recheck `probe_edge_verify:LEFT,15` from `(16,18)`
    confirmed `(15,18).east` blocked 15/15 with no drift, map change, or
    interruption. Preview again showed cell-level runtime noise
    (`runtime_directional_blocked=true`) while `approach_blocked=false`
    confirmed the east approach itself was not already runtime-blocked.
    Summary line:
    `classification=confirmed_blocked`, `moved=0`, `blocked=15`,
    `blocked_model_mismatch=15`, `manual_promotion_required=true`.
  - Runtime injection with `add_blocked_edge:16,18,left` created
    `RUNTIME_BLOCK map=0x18 x=15 y=18 key=15,18 dirs=east,south,west` and
    rerouted the reverse planner from `(16,18)` to:
    `1 east, 1 north, 3 west, 5 north, 1 east, 8 north`.
  - That reroute proved `(17,18)` passable from the west, then failed three
    times on `(17,18)->UP` into `(17,17)`.
  - Strong direct recheck `probe_edge_verify:UP,15` from `(17,18)` confirmed
    `(17,17).south` blocked 15/15 with no drift, map change, or interruption.
    Preview showed `static_directional_blocked=true`, `runtime_directional_blocked=false`,
    and `approach_blocked=false`, matching the same clean south-approach
    one-way pattern as `(16,17).south`. Summary line:
    `classification=confirmed_blocked`, `moved=0`, `blocked=15`,
    `blocked_model_mismatch=15`, `manual_promotion_required=true`.
  - Continued reverse-side contour cleanup after the later permanent batch
    confirmed five more 15/15 seams with no drift, map change, or combat
    contamination:
    `(19,17).south` from `(19,18)->UP`,
    `(18,17).south` from `(18,18)->UP`,
    `(13,19).east` from `(14,19)->LEFT`,
    `(11,18).east` from `(12,18)->LEFT`,
    and `(11,18).south` from `(11,19)->UP`.
  - The intervening reroutes also proved the reverse contour remains open at
    `(18,18)`, `(16,18)`, `(16,19)`, `(15,19)`, `(14,19)`, `(14,18)`,
    `(13,18)`, `(12,18)`, `(12,19)`, and `(11,19)` from the logged approaches.
  - `(17,18).east` stayed noisy: the first reroute from `(18,18)->LEFT`
    blocked once and then moved, so it should remain unpromoted.
  - A Drakeema battle interrupted the first `(12,19)->LEFT` reroute. After
    combat, the same step validated cleanly into `(11,19)`, so that earlier
    mismatch was battle contamination only.
  - Runtime injection is now extended through the full five-seam batch,
    including `add_blocked_edge:11,19,up` for `(11,18).south`.
  - Post-batch continuation immediately kept moving: `(10,19)` and `(10,18)`
    both validated cleanly from the east and south respectively.
  - The next new reverse contour blocker seed is now confirmed:
    direct `probe_edge_verify:UP,15` from `(10,18)` confirmed `(10,17).south`
    blocked 15/15 with no drift, map change, or interruption. This is runtime
    only so far and starts the next patch batch.
  - Runtime-injecting `(10,17).south` rerouted the planner back east, where
    fresh validation from `(10,18)` failed three times on `(10,18)->RIGHT`
    into `(11,18)`.
  - Strong direct follow-up `probe_edge_verify:RIGHT,15` then confirmed
    `(11,18).west` blocked 15/15 with no drift, map change, or interruption.
    This is the second seed in the new runtime-only batch and makes `(11,18)`
    confirmed blocked from east, south, and west.
  - Injecting `(11,18).west` then forced the planner back left. Fresh
    validation from `(10,18)` failed three times on `(10,18)->LEFT`
    into `(9,18)`.
  - Strong direct follow-up `probe_edge_verify:LEFT,15` confirmed
    `(9,18).east` blocked 15/15 with no drift, map change, or interruption.
    This is the third confirmed seed in the next runtime-only batch.
  - Injecting `(9,18).east` rerouted cleanly through `(10,19)` and `(9,19)`,
    then failed three times on `(9,19)->UP` into `(9,18)`.
  - Strong direct follow-up `probe_edge_verify:UP,15` confirmed
    `(9,18).south` blocked 15/15 with no drift, map change, or interruption.
    This is the fourth confirmed seed in the next runtime-only batch.
  - Injecting `(9,18).south` rerouted cleanly through `(8,19)`, then failed
    three times on `(8,19)->UP` into `(8,18)`.
  - Strong direct follow-up `probe_edge_verify:UP,15` confirmed
    `(8,18).south` blocked 15/15 with no drift, map change, or interruption.
    This completed a five-seam runtime batch with
    `(10,17).south`, `(11,18).west`, `(9,18).east`, `(9,18).south`, and
    `(8,18).south`.
  - Later entrance-side west-rim continuation found a new north-face seam at
    `(7,19)->UP`. Strong direct `probe_edge_verify:UP,15` confirmed
    `(7,18).south` blocked 15/15 with no drift, map change, or interruption.
    Preview still reported the cell as open (`approach_blocked=false`,
    `effective_passable=true`), so this is another clean engine seam rather
    than modeled blockage. Runtime injection with `add_blocked_edge:7,19,UP`
    rerouted the planner west from `(7,19)` to:
    `3 west, 3 north, 1 east, 9 north, 10 east, 3 north`.
  - That reroute proved `(6,19)`, `(5,19)`, and `(4,19)` passable from the
    east, then failed three times on `(4,19)->UP` into `(4,18)`.
  - Strong direct `probe_edge_verify:UP,15` from `(4,19)` confirmed
    `(4,18).south` blocked 15/15 with no drift, map change, or interruption.
    This matched the same raw-hold timeout / open-preview pattern as
    `(7,18).south`. Runtime injection with `add_blocked_edge:4,19,UP`
    rerouted from `(4,19)` to:
    `1 west, 3 north, 2 east, 9 north, 10 east, 3 north`.
  - That second reroute showed `(3,19).east` is noisy rather than blocked:
    the first `(4,19)->LEFT` attempt blocked once, then the retry moved into
    `(3,19)`. It also proved `(3,18)` and `(3,17)` passable from the south.
    The next hard stop was `(3,17)->UP` into `(3,16)`.
  - Strong direct `probe_edge_verify:UP,15` from `(3,17)` confirmed
    `(3,16).south` blocked 15/15 with no drift, map change, or interruption.
    Runtime injection with `add_blocked_edge:3,17,UP` then rerouted again from
    `(3,17)`.
  - The follow-up reroute did not open northward; instead it immediately
    failed on `(3,17)->RIGHT` into `(4,17)`.
  - Strong direct `probe_edge_verify:RIGHT,15` from `(3,17)` confirmed
    `(4,17).west` blocked 15/15 with no drift, map change, or interruption.
    Runtime injection with `add_blocked_edge:3,17,RIGHT` then forced the
    planner to test the mirrored west exit from the same pocket.
  - That mirrored reroute failed three times on `(3,17)->LEFT` into `(2,17)`.
  - Strong direct `probe_edge_verify:LEFT,15` from `(3,17)` confirmed
    `(2,17).east` blocked 15/15 with no drift, map change, or interruption.
    This completed a five-seam entrance-side west-pocket batch with
    `(7,18).south`, `(4,18).south`, `(3,16).south`, `(4,17).west`, and
    `(2,17).east`.
  - After the next Lua/log restart, baseline recheck resumed from
    `(3,18)` rather than `(3,17)`, so the newly patched five-seam batch was
    active for the planner.
  - Post-reload `debug_pathfind_to:15,4` from `(3,18)` no longer targeted the
    old north face. Instead, it immediately failed on `(3,18)->RIGHT` into
    `(4,18)`, while seam observations marked `(4,18).west` noisy-but-blocked
    (`blocked=5 moved=1`) during validator retries.
  - Strong direct `probe_edge_verify:RIGHT,15` from `(3,18)` then confirmed
    `(4,18).west` blocked 15/15 with no drift, map change, or interruption.
    Runtime injection with `add_blocked_edge:3,18,RIGHT` was queued
    immediately to continue the restarted route search.
  - With `(4,18).west` live at runtime, the restarted route shifted west
    through `(2,18)` and then failed three times on `(2,18)->UP` into
    `(2,17)`.
  - Strong direct `probe_edge_verify:UP,15` from `(2,18)` confirmed
    `(2,17).south` blocked 15/15 with no drift, map change, or interruption.
    Runtime injection with `add_blocked_edge:2,18,UP` rerouted the planner
    farther west.
  - That reroute proved `(1,18)`, `(1,17)`, and `(1,16)` passable from the
    south, then failed three times on `(1,16)->UP` into `(1,15)`.
  - Strong direct `probe_edge_verify:UP,15` from `(1,16)` confirmed
    `(1,15).south` blocked 15/15 with no drift, map change, or interruption.
    Runtime injection with `add_blocked_edge:1,16,UP` was queued immediately.
  - With `(1,15).south` live at runtime, the planner rerouted back east from
    `(1,16)` through `(2,16)` and then failed three times on `(2,16)->RIGHT`
    into `(3,16)`.
  - Strong direct `probe_edge_verify:RIGHT,15` from `(2,16)` confirmed
    `(3,16).west` blocked 15/15 with no drift, map change, or interruption.
    Runtime injection with `add_blocked_edge:2,16,RIGHT` then forced the
    planner to test the remaining north exit from `(2,16)`.
  - That next reroute failed three times on `(2,16)->UP` into `(2,15)`.
  - Strong direct `probe_edge_verify:UP,15` from `(2,16)` confirmed
    `(2,15).south` blocked 15/15 with no drift, map change, or interruption.
    Runtime injection with `add_blocked_edge:2,16,UP` was queued immediately.
    This completed a second post-reload five-seam batch with
    `(4,18).west`, `(2,17).south`, `(1,15).south`, `(3,16).west`, and
    `(2,15).south`.
  - One final night-pass replan after the next reload resumed from `(2,16)`
    with the second west-pocket batch already patched in permanently.
  - That replan no longer wanted north/east first. Instead, it immediately
    failed on `(2,16)->DOWN` into `(2,17)`.
  - Strong direct `probe_edge_verify:DOWN,15` from `(2,16)` confirmed
    `(2,17).north` blocked 15/15 with no drift, map change, or interruption.
    Runtime injection with `add_blocked_edge:2,16,DOWN` rerouted the planner
    again from the same tile.
  - The follow-up reroute no longer wanted south. It immediately failed on
    `(2,16)->LEFT` into `(1,16)`.
  - Strong direct `probe_edge_verify:LEFT,15` from `(2,16)` confirmed
    `(1,16).east` blocked 15/15 with no drift, map change, or interruption.
    These two seams start the next post-reload runtime-only batch.

## 2026-05-29 reverse-side continuation from the deferred runtime batch

- Resumed from the last reverse-side runtime-only batch by recreating the two
  deferred edges on a clean live overlay:
  - `add_blocked_edge:2,16,DOWN` -> `RUNTIME_BLOCK map=0x18 x=2 y=17 dirs=north`
  - `add_blocked_edge:2,16,LEFT` -> `RUNTIME_BLOCK map=0x18 x=1 y=16 dirs=east`
- With only those two runtime seams live, teleporting to B2 stairs `(1,18)`
  restored a reverse path to the entrance stairs `(6,11)`:
  `(1,18)->(2,18)->(3,18)->(3,19)->(4,19)->(5,19)->(5,18)->(4,18)->(4,17)->(4,16)->(5,16)->(5,15)->(5,14)->(5,13)->(5,12)->(5,11)->(6,11)`.
- Reverse validation from `(1,18)` advanced cleanly through 5 steps, but the
  candidate at `(4,19).west` did not hold: the first retry blocked once, then
  the next retry moved into `(4,19)`, downgrading that seam to `classification=noisy`.
  Do not promote `(4,19).west`.
- The first clean new blocker from the resumed branch was `(5,19)->UP` into
  `(5,18)`:
  - Validator failed twice there and then aborted at `5/16` steps OK.
  - Direct `probe_edge_verify:5,19,UP,15` confirmed `(5,18).south`
    blocked `15/15`, with `blocked_model_mismatch=15` and
    `mismatch=blocked_despite_open_preview`.
  - Runtime-injected with `add_blocked_edge:5,19,UP`.
- With `(5,18).south` live, replanning from `(5,19)` rerouted east through
  `(6,19)->(6,18)->(5,18)->...`, then reverse validation failed immediately on
  `(6,19)->UP` into `(6,18)` and aborted at `1/13` steps OK.
- Direct `probe_edge_verify:6,19,UP,15` then confirmed `(6,18).south`
  blocked `15/15`, again with `blocked_model_mismatch=15` and
  `mismatch=blocked_despite_open_preview`.
  Runtime-injected with `add_blocked_edge:6,19,UP`.
- Current live runtime-only overlay now has four seams:
  `(1,16).east`, `(2,17).north`, `(5,18).south`, and `(6,18).south`.
- After injecting those four seams, `debug_pathfind_to:6,11` from live
  `(6,19)` now collapses to `No path found [no_path]` after `visited=40`.
- Local reverse-side frontier from live `(6,19)` now ranks the next bridge
  candidates as:
  - `(3,17)->RIGHT` into `(4,17)` / `(4,17).west`
  - `(3,17)->UP` into `(3,16)` / `(3,16).south`
  - `(2,16)->RIGHT` into `(3,16)` / `(3,16).west`
  - `(4,19)->UP` into `(4,18)` / `(4,18).south`
  - `(3,18)->RIGHT` into `(4,18)` / `(4,18).west`
- Best next live probes from this state:
  `probe_edge_verify:3,17,RIGHT,15`,
  `probe_edge_verify:3,17,UP,15`,
  and, only if needed after those, the `(4,18)` south/west pair.
- Continued reverse-side probing from that frontier produced the following:
  - `probe_edge_verify:3,17,RIGHT,15` came back mixed:
    `moved=6 blocked=9 classification=mixed`. Do not promote `(4,17).west`.
  - `probe_edge_verify:3,17,UP,15` confirmed `(3,16).south` blocked `15/15`.
    Runtime-injected with `add_blocked_edge:3,17,UP`.
  - With `(3,16).south` live, `debug_pathfind_to:6,11` from the local reverse
    component still collapsed to `No path found [no_path]` (`visited=38`).
  - Fresh frontier from live `(3,18)` still pointed at the `(3,16)` / `(4,18)`
    cluster, with the next clean untested bridge at `(2,16)->RIGHT`.
  - `probe_edge_verify:2,16,RIGHT,15` confirmed `(3,16).west` blocked `15/15`.
    Runtime-injected with `add_blocked_edge:2,16,RIGHT`.
  - Starting debug from live `(2,16)` after that injection yielded
    `visited=1`, confirming it behaves like a trapped one-way pocket from that
    side, so further frontier checks were resumed from live `(3,18)`.
  - `probe_edge_verify:3,18,RIGHT,15` confirmed `(4,18).west` blocked `15/15`.
    Runtime-injected with `add_blocked_edge:3,18,RIGHT`.
  - The mirrored seam into the same pocket did not hold cleanly:
    `probe_edge_verify:4,19,UP,15` returned `moved=1 blocked=14 classification=mixed`.
    Do not promote `(4,18).south`.
  - The remaining north exits from the west pocket were both clean blockers:
    - `probe_edge_verify:2,16,UP,15` confirmed `(2,15).south` blocked `15/15`,
      then runtime-injected with `add_blocked_edge:2,16,UP`.
    - `probe_edge_verify:1,16,UP,15` confirmed `(1,15).south` blocked `15/15`,
      then runtime-injected with `add_blocked_edge:1,16,UP`.
- Current live runtime-only overlay is now 8 runtime block cells carrying 9
  blocked approaches:
  `(1,15).south`, `(2,15).south`, `(1,16).east`, `(3,16).south`,
  `(3,16).west`, `(2,17).north`, `(4,18).west`, `(5,18).south`,
  `(6,18).south`.
- Current status after the eight-seam runtime overlay:
  - `debug_pathfind_to:6,11` from live `(3,18)` still returns
    `No path found [no_path]` with `visited=38`.
  - Mixed/noisy seams to leave unmodeled for now:
    `(4,17).west` from `(3,17)->RIGHT` and `(4,18).south` from `(4,19)->UP`.
  - The next clean unexplored frontier candidate from the main reverse
    component is `(7,19)->UP` into `(7,18)` / `(7,18).south`.
- One more frontier cycle after that note:
  - A fresh `launcher_probe:codex_b1_frontier_resume` confirmed the emulator
    was polling again after the log went stale between probes.
  - `probe_edge_verify:7,19,UP,15` confirmed `(7,18).south` blocked `15/15`.
    Runtime-injected with `add_blocked_edge:7,19,UP`.
  - With that seam live, `debug_pathfind_to:6,11` from live `(3,18)` still
    returns `No path found [no_path]` with `visited=38`.
  - The runtime overlay is now 9 block cells, adding `RUNTIME_BLOCK map=0x18
    x=7 y=18 dirs=south` to the prior batch.
  - Mixed/noisy seams remain unchanged:
    `(4,17).west` from `(3,17)->RIGHT` and `(4,18).south` from `(4,19)->UP`.
  - The next clean unexplored frontier candidate from the main reverse
    component is now `(10,18)->UP` into `(10,17)` / `(10,17).south`.
- Continued eastward frontier cleanup after that note:
  - `probe_edge_verify:10,18,UP,15` confirmed `(10,17).south` blocked `15/15`.
    Runtime-injected with `add_blocked_edge:10,18,UP`.
  - `probe_edge_verify:11,19,UP,15` confirmed `(11,18).south` blocked `15/15`.
    Runtime-injected with `add_blocked_edge:11,19,UP`.
  - `probe_edge_verify:10,18,RIGHT,15` into `(11,18)` was mixed:
    `moved=1 blocked=14 classification=mixed`. Do not promote `(11,18).west`.
  - `probe_edge_verify:12,18,LEFT,15` confirmed `(11,18).east` blocked `15/15`.
    Runtime-injected with `add_blocked_edge:12,18,LEFT`, leaving
    `RUNTIME_BLOCK map=0x18 x=11 y=18 dirs=east,south`.
  - `probe_edge_verify:12,18,UP,15` confirmed `(12,17).south` blocked `15/15`.
    Runtime-injected with `add_blocked_edge:12,18,UP`.
  - `probe_edge_verify:8,19,UP,15` confirmed `(8,18).south` blocked `15/15`.
    Runtime-injected with `add_blocked_edge:8,19,UP`.
- Current live runtime-only overlay now has 13 block cells:
  `(1,15).south`, `(2,15).south`, `(1,16).east`, `(3,16).south`,
  `(3,16).west`, `(2,17).north`, `(10,17).south`, `(12,17).south`,
  `(4,18).west`, `(5,18).south`, `(6,18).south`, `(7,18).south`,
  `(8,18).south`, plus `(11,18).east/south`.
- Current status after this batch:
  - `debug_pathfind_to:6,11` from live `(3,18)` still returns
    `No path found [no_path]` with `visited=38`.
  - Mixed/noisy seams to leave unmodeled for now:
    `(4,17).west`, `(4,18).south`, and `(11,18).west`.
  - The next clean unexplored frontier candidate from the main reverse
    component is now `(13,18)->UP` into `(13,17)` / `(13,17).south`.
- Continued reverse-side frontier cleanup after that note:
  - `probe_edge_verify:13,18,UP,15` confirmed `(13,17).south` blocked `15/15`.
    Runtime-injected with `add_blocked_edge:13,18,UP`.
  - With that seam live, `debug_pathfind_to:6,11` from live `(3,18)` still
    returns `No path found [no_path]` with `visited=38`, and
    `debug_route_frontier:6,11` still reports `reachable=35`,
    `target_side=329`, and `bridge_candidates=27`.
  - `probe_edge_verify:9,19,UP,15` confirmed `(9,18).south` blocked `15/15`.
    Runtime-injected with `add_blocked_edge:9,19,UP`.
  - The mirrored entry into that same pocket did not hold:
    `probe_edge_verify:10,18,LEFT,15` returned
    `moved=9 blocked=6 classification=mixed`. Do not promote `(9,18).east`.
  - The next fresh eastern band seam then held cleanly:
    `probe_edge_verify:14,18,UP,15` confirmed `(14,17).south` blocked `15/15`.
    Runtime-injected with `add_blocked_edge:14,18,UP`.
  - That x=14 band also extends east:
    `probe_edge_verify:14,18,RIGHT,15` confirmed `(15,18).west`
    blocked `15/15`, then runtime-injected with `add_blocked_edge:14,18,RIGHT`.
- Current live/runtime state after this follow-up batch:
  - The live runtime overlay is now 17 block cells:
    `(1,15).south`, `(2,15).south`, `(1,16).east`, `(3,16).south`,
    `(3,16).west`, `(2,17).north`, `(10,17).south`, `(12,17).south`,
    `(13,17).south`, `(14,17).south`, `(4,18).west`, `(5,18).south`,
    `(6,18).south`, `(7,18).south`, `(8,18).south`, `(9,18).south`,
    plus `(11,18).east/south` and `(15,18).west`.
  - `debug_pathfind_to:6,11` from live `(3,18)` still returns
    `No path found [no_path]` with `visited=38`.
  - Mixed/noisy seams to leave unmodeled for now:
    `(4,17).west`, `(4,18).south`, `(11,18).west`, and `(9,18).east`.
  - `debug_route_frontier:6,11` still reports `reachable=35`,
    `target_side=329`, and `bridge_candidates=27` after injecting
    `(15,18).west`.
  - The next clean unexplored frontier candidates now appear to be the
    `(15,18)` south/east-side entries:
    `(15,19)->UP` into `(15,18)` / `(15,18).south`, then
    `(16,18)->LEFT` into `(15,18)` / `(15,18).east`, and
    `(16,18)->UP` into `(16,17)` / `(16,17).south`.
- Continued east-pocket follow-up after that note:
  - `probe_edge_verify:15,19,UP,15` confirmed `(15,18).south`
    blocked `15/15`. Runtime-injected with `add_blocked_edge:15,19,UP`,
    merging into existing `RUNTIME_BLOCK map=0x18 x=15 y=18 dirs=south,west`
    without increasing block-cell count.
  - `probe_edge_verify:16,18,LEFT,15` into `(15,18)` stayed mixed:
    `moved=1 blocked=14 classification=mixed`. Do not promote `(15,18).east`.
  - `probe_edge_verify:16,18,UP,15` confirmed `(16,17).south`
    blocked `15/15`. Runtime-injected with `add_blocked_edge:16,18,UP`.
  - After that injection, `debug_pathfind_to:6,11` from live `(3,18)` still
    returns `No path found [no_path]` with `visited=38`, and
    `debug_route_frontier:6,11` still reports `reachable=35`,
    `target_side=329`, and `bridge_candidates=27`.
  - One more eastward probe finally broke the blocker streak:
    `probe_edge_verify:17,19,UP,15` into `(17,18)` reported
    `moved=10 blocked=0 interrupted=1 classification=inconclusive_interrupted`
    after a battle started on attempt 11. The field-side preview before the
    interruption showed `directional_blocked=false` and
    `effective_passable=true`, so this seam looks promising but is not yet
    promotable.
- Current live/runtime state after this follow-up batch:
  - The live runtime overlay is now 18 block cells:
    `(1,15).south`, `(2,15).south`, `(1,16).east`, `(3,16).south`,
    `(3,16).west`, `(2,17).north`, `(10,17).south`, `(12,17).south`,
    `(13,17).south`, `(14,17).south`, `(16,17).south`, `(4,18).west`,
    `(5,18).south`, `(6,18).south`, `(7,18).south`, `(8,18).south`,
    `(9,18).south`, plus `(11,18).east/south` and `(15,18).south/west`.
  - Mixed/noisy seams to leave unmodeled for now:
    `(4,17).west`, `(4,18).south`, `(11,18).west`, `(9,18).east`,
    and `(15,18).east`.
  - Best next resume point after the battle is to recheck field readiness and
    retry `(17,19)->UP` cleanly; if it stays open, continue eastward from the
    `(17,18)` pocket instead of assuming the wall band extends further.

## 2026-05-29 east-pocket retry and entrance-side frontier pivot

- Clean post-battle retry of the suspicious east seam stayed effectively open:
  `probe_edge_verify:17,19,UP,5` reported
  `moved=5 blocked=0 interrupted=1 classification=inconclusive_interrupted`.
  Treat `(17,19)->UP` into `(17,18)` as likely open but not promotable because
  the stability recheck was cut off by combat.
- Local geometry check from that east shelf:
  - `inspect_move` from `(17,18)`, `(18,18)`, and `(19,18)` showed the east
    pocket itself is real, but all three northward entries previewed blocked.
  - Direct verifiers then confirmed `(17,18)->UP`, `(18,18)->UP`, and
    `(19,18)->UP` blocked 5/5, so `(17,17).south`, `(18,17).south`, and
    `(19,17).south` were runtime-injected.
- After those injections, the target-side planner still stayed collapsed:
  - `debug_pathfind_to:6,11` from `(17,18)` remained
    `No path found [no_path] (visited=37)`.
  - `debug_route_frontier:6,11` still reported
    `reachable=35 target_side=329 candidates=31 bridge_candidates=27`.
  - The top-24 log cap meant new leads were being hidden once the latest
    runtime seams filled ranks 20-22.
- Pivoted to the entrance side to rerank the bridge search from `(6,11)`:
  - Fresh `debug_pathfind_to:1,18` stayed
    `No path found [no_path] (visited=291)`.
  - `debug_route_frontier:1,18` from `(6,11)` exposed a much larger frontier:
    `reachable=243 target_side=120 candidates=159 bridge_candidates=135`.
  - This made the next unresolved seams visible from the entrance side instead
    of the tiny B2-side component.
- Entrance-side verifier results:
  - Cleanly confirmed blocked and runtime-injected:
    `(2,14)->LEFT` => `(1,14).east`,
    `(5,17)->DOWN` => `(5,18).north`,
    `(5,17)->LEFT` => `(4,17).east`,
    `(2,14)->DOWN` => `(2,15).north`,
    `(2,13)->LEFT` => `(1,13).east`,
    `(3,14)->DOWN` => `(3,15).north`,
    `(4,15)->DOWN` => `(4,16).north`,
    `(6,17)->DOWN` => `(6,18).north`,
    `(4,15)->LEFT` => `(3,15).east`,
    `(8,17)->DOWN` => `(8,18).north`,
    `(2,12)->LEFT` => `(1,12).east`,
    `(6,16)->LEFT` => `(5,16).east`.
  - Short 5-attempt mixeds on `(2,14)->DOWN`, `(3,14)->DOWN`, and
    `(4,15)->LEFT` each resolved to clean 10/10 blocked on the immediate
    stronger retry. Treat the single-move first passes as noise, not openings.
- Current live runtime overlay after the entrance-side pivot is now 28 block
  cells, including the new entrance-side additions:
  `(1,12).east`, `(1,13).east`, `(1,14).east`, `(2,15).north/south`,
  `(3,15).east/north`, `(4,16).north`, `(5,16).east`, `(4,17).east`,
  `(5,18).north/south`, `(6,18).north/south`, `(8,18).north/south`,
  plus the earlier reverse-side/east-pocket cells.
- Planner status after the entrance-side injections is still unchanged:
  - `debug_pathfind_to:1,18` from `(6,11)` remains
    `No path found [no_path] (visited=291)`.
  - `debug_route_frontier:1,18` still reports
    `reachable=243 target_side=120 candidates=159 bridge_candidates=135`,
    but now ranks the next unresolved blocked-directional seams higher.
- Best next unresolved entrance-side seams, in current frontier order:
  `(5,17)->UP` into `(5,16)` / `(5,16).south`,
  `(2,11)->LEFT` into `(1,11)` / `(1,11).east`,
  `(8,17)->LEFT` into `(7,17)` / `(7,17).east`,
  `(7,16)->DOWN` into `(7,17)` / `(7,17).north`,
  `(4,15)->RIGHT` into `(5,15)` / `(5,15).west`,
  `(6,17)->RIGHT` into `(7,17)` / `(7,17).west`,
  then the `(2,10)` / `(6,14)` / `(4,14)` / `(7,14)` cluster.

## 2026-05-29 provisional `(4,15)->RIGHT` reopening disproved

- Continued entrance-side direct verifiers first confirmed four more clean
  5/5 blockers and runtime-injected them later in the pass:
  - `(5,17)->UP` => `(5,16).south`
  - `(2,11)->LEFT` => `(1,11).east`
  - `(8,17)->LEFT` => `(7,17).east`
  - `(7,16)->DOWN` => `(7,17).north`
- A surprising direct verifier then temporarily contradicted the model:
  `probe_edge_verify:4,15,RIGHT,5` reported
  `moved=6 blocked=0 stability_recheck=true
  classification=suspect_passable_model_mismatch`.
  This made `(4,15)->RIGHT` into `(5,15)` look like the missing bridge, so the
  permanent `(5,15).west` block was briefly removed from `map_reader.lua`,
  the regression test was flipped, tests passed, and `reload_navigation_modules`
  made `debug_pathfind_to:1,18` from `(6,11)` find a 22-step route.
- That reopening did **not** hold under live movement:
  - First `validate_path` from `(6,11)` reached step 13 cleanly, but a battle
    started at step 14 `(4,14)->DOWN`, so the validator aborted due combat
    contamination, not map evidence.
  - After clearing the battle, a second `validate_path` reached `(4,15)` and
    then failed repeatedly on step 15 `(4,15)->RIGHT` into `(5,15)`.
    Auto-step timed out twice with `SEAM_OBSERVATION ... cell=(5,15)
    approach=west result=blocked`.
  - Immediate raw recheck superseded the earlier 6/6 moved result:
    `probe_edge_verify:4,15,RIGHT,5` then blocked 5/5 with
    `classification=confirmed_blocked` and `blocked_model_mismatch=5` even
    though the preview said `directional_blocked=false`.
- Conclusion:
  - `(4,15)->RIGHT` is currently noisy / state-sensitive / not reproducibly
    open. Treat the earlier 6/6 moved result as a false lead.
  - The temporary `map_reader.lua` / `test_map_reader.lua` change for
    `(5,15).west` was reverted immediately after the clean blocked recheck, and
    focused Lua checks passed again.
  - After reload, `debug_pathfind_to:1,18` from `(6,11)` returned to
    `No path found [no_path] (visited=291)`.
- Additional clean entrance-side follow-up after the revert:
  - `probe_edge_verify:6,17,RIGHT,5` confirmed `(7,17).west` blocked 5/5.
    Runtime-injected later in the pass.
  - `probe_edge_verify:2,10,LEFT,5` was mixed `moved=1 blocked=4`, but the
    stronger immediate retry `probe_edge_verify:2,10,LEFT,10` settled
    `blocked=10 moved=0`, so `(1,10).east` is now confirmed blocked and was
    runtime-injected.
- Current live runtime overlay after all clean follow-up injections is now 31
  block cells. New/expanded entrance-side cells since the prior note:
  `(1,10).east`, `(1,11).east`, `(5,16).east/south`, and
  `(7,17).east/north/west`.
- Current route status after the revert and latest injections:
  - `debug_pathfind_to:1,18` from `(6,11)` remains
    `No path found [no_path] (visited=291)`.
  - `debug_route_frontier:1,18` still reports
    `reachable=243 target_side=120 candidates=159 bridge_candidates=135`.
  - The stale `(4,15)->RIGHT` lead should stay modeled/treated as blocked until
    a later clean reproduction says otherwise.
- Best next unresolved clean frontier candidates now:
  `(6,14)->DOWN` into `(6,15)` / `(6,15).north`,
  `(6,14)->LEFT` into `(5,14)` / `(5,14).east`,
  `(4,14)->RIGHT` into `(5,14)` / `(5,14).west`,
  `(6,16)->UP` into `(6,15)` / `(6,15).south`,
  and `(7,14)->DOWN` into `(7,15)` / `(7,15).north`.

## 2026-05-29 provisional west-entry bridge stack experiment (workspace still dirty)

- Rechecked the untouched entrance-side directional cluster before touching the
  static model:
  - `(6,14)->DOWN` first looked open-ish at `moved=4 blocked=1`, but the
    stronger immediate retry `probe_edge_verify:6,14,DOWN,10` settled it back
    to `blocked 10/10`. Treat that seam as noise.
  - `(6,16)->UP` into `(6,15)` confirmed blocked `5/5`.
  - `(6,14)->LEFT` into `(5,14)` confirmed blocked `5/5`.
  - `(7,14)->DOWN` into `(7,15)` confirmed blocked `5/5`.
  - `(4,14)->RIGHT` into `(5,14)` first moved `6/6` with stability recheck,
    then a stronger retry degraded to `moved=1 blocked=9`.
- Teleporting directly into `(5,14)` proved that cell is a real bridge target,
  not a dead pocket:
  - `debug_pathfind_to:1,18` from `(5,14)` found
    `2 south, 2 west, 2 south, 2 west`.
  - `debug_pathfind_to:6,11` from `(5,14)` found `3 north, 1 east`.
- Based on that, I made a temporary experimental map edit only:
  - opened `["5,14"].west` in `map_reader.lua`
  - updated the matching regression in `test_map_reader.lua`
  - focused Lua checks all passed.
- Under that temporary `5,14.west` opening:
  - `debug_pathfind_to:1,18` from entrance `(6,11)` reopened a 22-step route:
    `2 north, 2 west, 2 south, 2 west, 3 south, 3 east, 2 south, 2 west,
    2 south, 2 west`.
  - A full validation from `(6,11)` was interrupted by a Warlock before the
    bridge seam.
  - Focused validation from `(4,14)` crossed step 1 cleanly:
    `(4,14)->RIGHT` into `(5,14)` moved live.
  - The next step failed cleanly:
    `(5,14)->DOWN` into `(5,15)` blocked repeatedly.
  - Direct verifier `probe_edge_verify:5,14,DOWN,5` confirmed
    `(5,15).north` blocked `5/5`, and I injected it at runtime with
    `add_blocked_edge:5,14,DOWN` (`RUNTIME_BLOCK map=0x18 x=5 y=15 dirs=north`).
- Teleporting directly into `(5,15)` then showed this is another real bridge
  cell:
  - `debug_pathfind_to:1,18` from `(5,15)` found
    `1 south, 2 west, 2 south, 2 west`.
  - `debug_pathfind_to:6,11` from `(5,15)` found `4 north, 1 east`.
- Rechecked the old `(4,15)->RIGHT` seam in that context:
  - `probe_edge_verify:4,15,RIGHT,5` moved `6/6` with stability recheck.
- Extended the same temporary experiment one step farther:
  - removed static `["5,15"].west`
  - updated the matching regression in `test_map_reader.lua`
  - focused Lua checks all still passed.
- Under temporary `5,15.west` opening with runtime `(5,15).north` still live:
  - `debug_pathfind_to:1,18` from `(4,15)` found
    `1 east, 1 south, 2 west, 2 south, 2 west`.
  - Focused validation from `(4,15)` crossed step 1 cleanly:
    `(4,15)->RIGHT` into `(5,15)` moved live.
  - The next step failed cleanly:
    `(5,15)->DOWN` into `(5,16)` blocked repeatedly.
  - Direct verifier `probe_edge_verify:5,15,DOWN,5` confirmed
    `(5,16).north` blocked `5/5`, and I injected it at runtime with
    `add_blocked_edge:5,15,DOWN`, merging into
    `RUNTIME_BLOCK map=0x18 x=5 y=16 dirs=east,north,south`.
- With both temporary west-entry openings live plus runtime
  `(5,15).north` and `(5,16).north`, the entrance-side planner still does not
  reach B2:
  - `debug_pathfind_to:1,18` from `(6,11)` returned
    `No path found [no_path] (visited=311)`.
  - `debug_route_frontier:1,18` from `(6,11)` now reports
    `reachable=260 target_side=103 candidates=125 bridge_candidates=101`.
  - From inside `(5,15)`, `debug_pathfind_to:1,18` also returns no path under
    the current runtime block set.
- The nearest new untreated directional seam surfaced by this expanded search
  is `(2,9)->LEFT` into `(1,9)`, but the first direct verifier stayed mixed:
  `probe_edge_verify:2,9,LEFT,5` => `moved=1 blocked=4`.
- Important current-state note:
  - `map_reader.lua` and `test_map_reader.lua` are intentionally left in this
    provisional experimental state for now (`5,14.west` and `5,15.west`
    opened in the static model).
  - The live runtime overlay is currently `count=32`, with experimental
    additions `(5,15).north` and `(5,16).north`.
  - Nothing in this section should be treated as permanent map truth yet.

- Follow-up expanded-frontier cleanup after leaving the provisional west-entry
  openings live:
  - `(2,9)->LEFT` into `(1,9)` first came back mixed
    `moved=1 blocked=4`, but the immediate stronger retry
    `probe_edge_verify:2,9,LEFT,10` settled to `blocked 10/10`.
    Runtime-injected later as `(1,9).east`.
  - `(2,8)->LEFT` into `(1,8)` confirmed blocked `5/5`.
    Runtime-injected as `(1,8).east`.
  - The deeper row-16/rim candidates were then checked in sequence:
    - `(9,16)->DOWN` first looked open at `moved=6 blocked=0` with stability
      recheck, but the immediate stronger retry settled back to
      `blocked 10/10`. Runtime-injected as `(9,17).north`, merging into the
      existing `(9,17).west`.
    - `(8,17)->RIGHT` first looked open-ish at `moved=4 blocked=1`, but the
      stronger retry settled to `blocked 10/10`. This supersedes the earlier
      mixed status and confirms `(9,17).west`, merging into the same runtime
      cell.
    - `(10,16)->DOWN` confirmed blocked `5/5`, merging into
      `RUNTIME_BLOCK map=0x18 x=10 y=17 dirs=north,south`.
    - `(11,16)->DOWN` confirmed blocked `5/5`, creating
      `RUNTIME_BLOCK map=0x18 x=11 y=17 dirs=north`.
    - `(12,16)->DOWN` confirmed blocked `5/5`, merging into
      `RUNTIME_BLOCK map=0x18 x=12 y=17 dirs=north,south`.
    - `(13,16)->DOWN` confirmed blocked `5/5`, merging into
      `RUNTIME_BLOCK map=0x18 x=13 y=17 dirs=north,south`.
- After those additions, the entrance-side planner is still closed even under
  the provisional `5,14.west` / `5,15.west` static openings:
  - `debug_pathfind_to:1,18` from `(6,11)` remains
    `No path found [no_path] (visited=311)`.
  - `debug_route_frontier:1,18` remains
    `reachable=260 target_side=103 candidates=125 bridge_candidates=101`.
  - Live runtime overlay is now `count=36`.
- Practical next target from this state:
  - the highest untreated directional seam visible before the log cap is now
    farther east than this batch, with `(10,16)->DOWN` having just been
    consumed and the next likely row-16 descent candidate being `(11,16)` /
    `(12,16)` / `(13,16)` style continuations already confirmed blocked.
  - The provisional west-entry experiment has widened search, but it still has
    not produced a through route to B2.

- Continued live dig from the same provisional west-entry state:
  - Refreshed the loop with `launcher_probe:codex_b1_continue3`.
  - Confirmed more of the east row-16 descent wall as clean blockers:
    - `(14,16)->DOWN` confirmed blocked `5/5`, merging into
      `RUNTIME_BLOCK map=0x18 x=14 y=17 dirs=north,south`.
    - `(15,16)->DOWN` confirmed blocked `5/5`, creating
      `RUNTIME_BLOCK map=0x18 x=15 y=17 dirs=north`.
    - `(16,16)->DOWN` confirmed blocked `5/5`, merging into
      `RUNTIME_BLOCK map=0x18 x=16 y=17 dirs=north,south`.
    - `(17,16)->DOWN` confirmed blocked `5/5`, merging into
      `RUNTIME_BLOCK map=0x18 x=17 y=17 dirs=north,south`.
    - `(18,16)->DOWN` confirmed blocked `5/5`, merging into
      `RUNTIME_BLOCK map=0x18 x=18 y=17 dirs=north,south`.
    - `(19,16)->DOWN` confirmed blocked `5/5`, merging into
      `RUNTIME_BLOCK map=0x18 x=19 y=17 dirs=north,south`.
  - That first east-band step mattered more than the later ones:
    - before `(14,16)->DOWN` and `(15,16)->DOWN`, entrance-side frontier was
      `reachable=260 target_side=103 candidates=125 bridge_candidates=101`
    - after adding those two, it dropped to
      `reachable=260 target_side=69 candidates=125 bridge_candidates=34`
    - finishing `(16,16)->DOWN` through `(19,16)->DOWN` did not shrink it
      further; the entrance-side planner stayed
      `No path found [no_path] (visited=311)`.
  - Reverse-side frontier recheck from live `(1,18)` then showed the old noisy
    seams had become the best nearby non-wall questions again.
  - Stronger rechecks finally settled both of those:
    - `probe_edge_verify:3,17,RIGHT,10` confirmed `(4,17).west` blocked
      `10/10`, merging into `RUNTIME_BLOCK map=0x18 x=4 y=17 dirs=east,west`.
    - `probe_edge_verify:4,19,UP,10` confirmed `(4,18).south` blocked
      `10/10`, merging into `RUNTIME_BLOCK map=0x18 x=4 y=18 dirs=south,west`.
  - Reverse-side planner still stayed closed after those promotions:
    - `debug_pathfind_to:6,11` from `(1,18)` remained
      `No path found [no_path] (visited=38)`.
    - `debug_route_frontier:6,11` remained
      `reachable=35 target_side=329 candidates=31 bridge_candidates=27`.
  - Live runtime overlay count stayed `37` because most new edges merged into
    existing cells rather than creating many new cells.
  - Current best remaining reverse-side runtime frontiers are now the already
    known cluster around:
    - `(3,17)->UP` / `(3,16).south`
    - `(2,16)->RIGHT` / `(3,16).west`
    - `(2,16)->UP` / `(2,15).south`
    - `(3,18)->RIGHT` / `(4,18).west`
    - `(1,16)->UP` / `(1,15).south`
  - Current practical read:
    - the east descent wall is now convincingly real from `x=14` through
      `x=19`
    - the old `(3,17)->RIGHT` and `(4,19)->UP` ambiguities are no longer good
      reopening candidates
    - the route is still closed under the present provisional
      `5,14.west` / `5,15.west` experiment.

- 2026-05-29 clean-state recheck of the provisional west-entry experiment:
  - The live log restarted during the pass, which implicitly cleared the B1
    runtime overlay. In that clean state, the still-patched static model
    briefly reopened:
    - from `(5,15)`, `debug_pathfind_to:1,18` found
      `1 south, 4 west, 2 south`
    - from entrance `(6,11)`, `debug_pathfind_to:1,18` found a 22-step route:
      `(6,11)->(6,10)->(6,9)->(5,9)->(4,9)->(4,10)->(4,11)->(3,11)->(2,11)->(2,12)->(2,13)->(2,14)->(3,14)->(4,14)->(5,14)->(5,15)->(5,16)->(4,16)->(3,16)->(2,16)->(1,16)->(1,17)->(1,18)`.
  - Live `validate_path` on that stored 22-step route disproved the reopening:
    - steps 1 through 13 completed live
    - step 14 failed on `(4,14)->RIGHT` into `(5,14)`
    - validator aborted at the first mismatch with
      `VALIDATE ABORT: stopping at first mismatch (13/22 steps OK)`.
  - Direct clean-state verifiers then reconfirmed both west-entry seams as
    true blockers:
    - `probe_edge_verify:4,14,RIGHT,5` => `(5,14).west` blocked `5/5`
    - `probe_edge_verify:4,15,RIGHT,5` => `(5,15).west` blocked `5/5`
  - Conclusion:
    - the provisional `5,14.west` / `5,15.west` static openings were false
    - the west-entry reopening experiment is finished and should not be used
      as a live bridge candidate anymore.
  - Source correction applied:
    - re-added `(5,14).west` and `(5,15).west` to
      `MAP_DIRECTIONAL_BLOCKS[0x18]` in `map_reader.lua`
    - updated the matching B1 regression assertions in `test_map_reader.lua`
    - focused checks passed:
      `luac5.1 -p map_reader.lua test_map_reader.lua`,
      `lua5.1 test_map_reader.lua`,
      `git diff --check -- map_reader.lua test_map_reader.lua`
  - Because the running FCEUX script still had the old static model loaded, I
    mirrored the same correction at runtime with:
    - `add_blocked_edge:4,14,RIGHT`
    - `add_blocked_edge:4,15,RIGHT`
  - With only those two live runtime fixes restored, the entrance-side route
    closed again immediately:
    - `debug_pathfind_to:1,18` from `(6,11)` returned
      `No path found [no_path] (visited=291)`
    - `debug_route_frontier:1,18` reported
      `reachable=243 target_side=121 candidates=159 bridge_candidates=135`
    - top bridge candidates returned to the old left-center cluster led by
      `(4,15)->RIGHT`, `(4,14)->RIGHT`, `(2,14)->DOWN`, `(2,14)->LEFT`,
      `(5,17)->DOWN`, and `(5,17)->LEFT`
  - Next practical resume:
    - reload or relaunch FCEUX before trusting static B1 path previews, so the
      running script picks up the corrected `map_reader.lua`
    - continue the corrected frontier from the restored closed state instead of
      reopening the disproved west-entry seam again.

- 2026-05-29 reverse-corridor one-way clarification plus low-west cleanup:
  - Rechecked the suspicious reverse-side seam at `(9,11)->RIGHT` into
    `(10,11)` after the interrupted battle pass. The stronger rerun settled
    cleanly blocked `10/10`, so the earlier movement there was combat/state
    noise rather than a real bridge.
  - Reverse pathing from `(1,18)` to entrance `(6,11)` is still live with the
    same 16-step path through `(3,19)->(5,19)->(5,18)->(4,18)->(4,17)->(4,16)
    ->(5,16)->(5,15)->(5,14)->(5,11)->(6,11)`.
  - The sibling reverse-side seam `(11,11)->LEFT` into `(10,11)` did not settle
    cleanly. It moved through the modeled block `3/10` times and blocked `7/10`
    times, so treat `(10,11).east` as mixed/suspicious and leave it unmodeled.
  - Direct inverse checks on the traced reverse corridor proved the entrance lip
    is a real one-way gate:
    - `(6,11)->LEFT` into `(5,11)` blocked `10/10`.
    - `(5,11)->RIGHT` into `(6,11)` moved `6/6` with stability recheck.
    - Practical consequence: the reverse pocket that reaches `(5,11)` cannot be
      used as the missing forward bridge from entrance to B2 stairs.
  - Entrance-side route state after that clarification is still unchanged:
    `debug_pathfind_to:1,18` from `(6,11)` remains
    `No path found [no_path] (visited=291)`, and
    `debug_route_frontier:1,18` remains
    `reachable=243 target_side=121 candidates=159 bridge_candidates=135`.
  - Old low-west noise is now finally resolved open:
    `probe_edge_verify:2,10,UP,10` confirmed `(2,10)->UP` into `(2,9)`
    passable `11/11` with stability recheck, so keep `(2,9).south` unmodeled.
  - Immediate practical resume:
    - ignore the reverse-route `(5,11)` pocket as a forward bridge lead
    - the current source tree already has a `debug_route_frontier:X,Y[,LIMIT]`
      patch, but the running FCEUX Lua loop has not picked it up yet
    - next productive live step is either a reload/relaunch to use that deeper
      frontier listing, or another targeted untreated candidate beyond the
      current 24-entry frontier cap.

- 2026-05-29 post-reload B1 frontier rebuild plus new reverse-biased seams:
  - After the manual FCEUX script reload, the B1 runtime overlay had been
    cleared, so the entrance-side frontier regressed to already-solved seams.
    I restored the known-clean runtime-only entrance blockers that were still
    absent from source so the frontier could move past the old left-center
    cluster:
    - `add_blocked_edge:2,14,DOWN`
    - `add_blocked_edge:2,14,LEFT`
    - `add_blocked_edge:5,17,DOWN`
    - `add_blocked_edge:5,17,LEFT`
    - `add_blocked_edge:2,13,LEFT`
    - `add_blocked_edge:3,14,DOWN`
    - `add_blocked_edge:4,15,DOWN`
    - `add_blocked_edge:4,15,LEFT`
    - `add_blocked_edge:6,17,DOWN`
    - `add_blocked_edge:2,12,LEFT`
    - `add_blocked_edge:6,16,LEFT`
    - `add_blocked_edge:5,17,UP`
    - `add_blocked_edge:2,11,LEFT`
    - `add_blocked_edge:8,17,DOWN`
    - `add_blocked_edge:8,17,LEFT`
    - `add_blocked_edge:7,16,DOWN`
    - `add_blocked_edge:6,17,RIGHT`
    - `add_blocked_edge:2,10,LEFT`
  - Rebuilt entrance frontier from live `(2,9)` still stayed
    `reachable=243 target_side=121 candidates=159 bridge_candidates=135`, but
    the top unexplained untreated seams shifted back to the old deeper band:
    `(6,14)->DOWN`, `(6,14)->LEFT`, `(6,16)->UP`, `(7,14)->DOWN`,
    `(2,9)->LEFT`, `(2,8)->LEFT`, `(2,7)->LEFT`, `(1,6)->DOWN`,
    `(4,12)->DOWN`, and `(4,12)->RIGHT`.
  - `5,10` pocket classification:
    - From the target-side pocket itself, both exits are now confirmed fully
      passable:
      - `probe_edge_verify:5,10,UP,10` => `(5,10)->(5,9)` moved `11/11`
        with stability recheck.
      - `probe_edge_verify:5,10,RIGHT,10` => `(5,10)->(6,10)` moved `11/11`
        with stability recheck.
    - From the entrance side, the corresponding forward entries remained mixed:
      - `probe_edge_verify:5,9,DOWN,10` => moved `2`, blocked `8`
      - `probe_edge_verify:6,10,LEFT,10` => moved `1`, blocked `9`
    - Practical read: `(5,10)` behaves like another reverse-only target-side
      lip, not a reliable forward bridge.
    - Teleporting into `(5,10)` still proves it is on the B2-stairs side:
      `debug_pathfind_to:1,18` returned `6 south, 4 west, 2 south`.
  - `6,14/6,15` cluster:
    - An interrupted pass briefly looked promising at `(6,14)->DOWN`, moving
      on attempts 1-2 before battle, but the clean full rerun settled it as a
      real blocker: `probe_edge_verify:6,14,DOWN,10` => blocked `10/10`.
      Runtime-injected with `add_blocked_edge:6,14,DOWN`.
    - Sibling seams also settled cleanly blocked and were runtime-injected:
      - `probe_edge_verify:6,14,LEFT,10` => blocked `10/10`
      - `probe_edge_verify:6,16,UP,10` => blocked `10/10`
  - `7,14/7,15` cluster:
    - Forward seam stayed mixed:
      - `probe_edge_verify:7,14,DOWN,10` => moved `1`, blocked `9`
    - Reverse seam is cleanly open:
      - `probe_edge_verify:7,15,UP,10` => moved `11/11` with stability
        recheck.
    - Practical read: likely another reverse-biased seam into the entrance
      component; leave `(7,15).north` unmodeled for now.
  - Low-west strip:
    - Clean blocked reruns were added at runtime:
      - `probe_edge_verify:2,9,LEFT,10` => blocked `10/10`
      - `probe_edge_verify:2,8,LEFT,10` => blocked `10/10`
      - `probe_edge_verify:2,7,LEFT,10` => blocked `10/10`
    - The final north-entry seam into that same left-column pocket is not yet
      stable enough to promote:
      - repeated direct verify on `(1,6)->DOWN` stayed mixed at `moved=7`,
        `blocked=3`
      - a natural-approach seeded probe from `(2,6)` into `(1,6)` then DOWN
        moved once into `(1,7)`, but the immediate repeat blocked
      - from inside the target-side cell, reverse checks on `(1,7)->UP` were
        repeatedly interrupted by battles, but every completed attempt moved
        so far (`7/7`, then `4/4`)
      - `debug_pathfind_to:1,18` from live `(1,7)` returned `11 south`,
        confirming that `(1,7)` is on the stairs-side component
    - Practical read: `(1,6)->DOWN` is the current strongest unresolved
      reverse-biased candidate, but still too mixed to patch.
  - New `4,12` cluster:
    - `probe_edge_verify:4,12,DOWN,10` => blocked `10/10`, runtime-injected
      with `add_blocked_edge:4,12,DOWN`.
    - `probe_edge_verify:4,12,RIGHT,10` => blocked `10/10`.
  - Current best untreated next branches after this batch:
    - revisit the unresolved `(1,6)->DOWN` / `(1,7)->UP` pair after combat
      with another natural-approach or reverse pass if we want to keep
      pressure on the only still-promising seam
    - otherwise pivot to the next untouched entrance-side candidates around
      `(6,12)->DOWN`, `(6,12)->LEFT`, `(8,12)->DOWN`, `(9,13)->LEFT`, and
      `(10,14)->DOWN`.

- 2026-05-29 reverse-side x=10 strip follow-up after the row-16 replay:
  - Re-established live baseline after the script went stale:
    `launcher_probe:codex_resume_b1_dig` and `report_position` landed back on
    live `(1,6)`. Current runtime overlay remained `RUNTIME_BLOCKS map=0x18
    count=37`, matching the rebuilt entrance-side batch.
  - Fresh reverse-side planner context from B2 stairs pocket:
    - `debug_pathfind_to:6,11` from `(1,18)` still succeeds with the same
      16-step reverse corridor:
      `2 east, 1 south, 2 east, 1 north, 1 west, 2 north, 1 east, 5 north, 1 east`
    - `debug_route_frontier:6,11,30` from `(1,18)` still surfaces the
      untreated-looking central x=10 band after the already-modeled row-17
      runtime walls. The most relevant local candidates were:
      `(9,12)->RIGHT`, `(9,10)->RIGHT`, `(9,13)->RIGHT`, and their
      right-side siblings near `(11,10)` / `(11,12)`.
  - `(10,12)` seam behaved like a localized unstable lip, not a clean wall:
    - `probe_edge_verify:9,12,RIGHT,10` => mixed `moved=2 blocked=8`
    - `probe_edge_verify:11,12,LEFT,10` => mixed `moved=3 blocked=7`
    - Practical read: both directions can slip through occasionally, but not
      reliably enough to model open or closed. Keep the `(10,12)` seam
      unmodeled and treat it as a strong suspicious candidate.
  - Nearby x=10 band checks above and below `(10,12)` settled cleanly blocked:
    - `probe_edge_verify:9,10,RIGHT,10` => blocked `10/10`
    - `probe_edge_verify:11,10,LEFT,10` => blocked `10/10`
      - notable mismatch: preview claimed `approach_blocked=false` /
        `effective_passable=true`, but live movement still blocked all
        `10/10`; this is evidence of a preview/model inconsistency, not an
        open seam
    - `probe_edge_verify:9,13,RIGHT,10` => blocked `10/10`
  - Practical read after the strip check:
    - x=10 y=10 and y=13 are real closed seams
    - x=10 y=12 remains the only fresh unstable central-band seam from this
      pass
    - `(10,11)` remains the older sibling suspicious seam: left side was
      previously settled blocked cleanly from `(9,11)->RIGHT`, while right
      side `(11,11)->LEFT` stayed mixed `3/10`
  - Best next resume:
    - keep pressure on the localized unstable pocket around `(10,11)` /
      `(10,12)` with natural-approach or repeat reverse-side checks
    - otherwise revisit the unresolved low-west `(1,6)->DOWN` / `(1,7)->UP`
      seam, which is still the other strong reverse-biased candidate

- 2026-05-29 one-way seam classification pass plus `5,10` pocket revisit:
  - Low-west seam `(1,6)/(1,7)` is now fully settled as a one-way gate:
    - Component check from teleported cells:
      - `(1,6)` reaches entrance `(6,11)` but not stairs `(1,18)`
      - `(1,7)` reaches both entrance `(6,11)` and stairs `(1,18)`
    - Direct seam checks in clean field state:
      - `probe_edge_verify:1,7,UP,10` => moved `11/11` with stability recheck
      - `probe_edge_verify:1,6,DOWN,10` => blocked `10/10`
    - Practical read: this is a real one-way gate into the larger connected
      region, but it is not a usable forward bridge from the entrance side.
  - `7,14/7,15` is another real one-way gate:
    - Component check from teleported cells:
      - `(7,14)` reaches entrance `(6,11)` but not stairs `(1,18)`
      - `(7,15)` reaches both entrance `(6,11)` and stairs `(1,18)`
    - Clean direct seam checks:
      - `probe_edge_verify:7,14,DOWN,10` => blocked `10/10`
      - `probe_edge_verify:7,15,UP,10` => moved `11/11` with stability recheck
    - Practical read: same shape as the low-west seam, so this cluster is
      another one-way trap rather than the missing forward route.
  - Central x=10 strip de-prioritized further:
    - Teleported component checks showed `(10,11)`, `(10,12)`, and `(11,12)`
      all still reach entrance `(6,11)` but not stairs `(1,18)`.
    - This means the mixed `(10,12)` seam is local weirdness inside the
      entrance-side region, not the cross-component bridge.
  - `5,10` pocket classification changed materially and supersedes the older
    "reverse-only target-side lip" read above:
    - Teleported component checks:
      - `(5,10)` reaches entrance `(6,11)` in `1 south, 1 east`
      - `(5,10)` also reaches stairs `(1,18)` in `6 south, 4 west, 2 south`
      - `(6,10)` reaches entrance only and still reports no path to stairs
      - `(5,9)` reaches entrance only and still reports no path to stairs
    - Direct entry seams from the entrance side stayed noisy on clean reruns:
      - `probe_edge_verify:6,10,LEFT,10` => mixed `moved=1 blocked=9`
      - `probe_edge_verify:5,9,DOWN,10` => mixed `moved=2 blocked=8`
    - Practical read: `(5,10)` is inside the connected region and both
      entrance-side entries into it are real bridge candidates, but neither
      seam is stable enough yet to promote.
  - Current best live suspects after this pass:
    - `(5,9)->DOWN` into `(5,10)`
    - `(6,10)->LEFT` into `(5,10)`
    - distant fallback only if those stall again: any remaining untreated
      seam around the older `(10,11)/(10,12)` oddity

- 2026-05-29 `5,10` pocket natural-approach follow-up:
  - Goal for this pass was to stop treating the `5,10` entries as abstract
    mixed direct verifiers and instead test them under more natural entrance-
    side arrivals.
  - `5,9 -> DOWN -> 5,10` is now the strongest live forward-bridge candidate:
    - Seeded from the side:
      - start `(6,9)`, `probe_edge_after_raw_to:LEFT,40,5,9,20,DOWN`
      - first run reached `(5,9)` and then moved into `(5,10)` cleanly
    - Seeded from above:
      - start `(5,8)`, `probe_edge_after_raw_to:DOWN,40,5,9,20,DOWN`
      - again moved into `(5,10)` cleanly
    - After the second natural crossing, live `report_position` confirmed
      current `(5,10)`, and fresh path checks from that non-teleport landing
      still reached both sides:
      - `debug_pathfind_to:6,11` => `1 south, 1 east`
      - `debug_pathfind_to:1,18` => `6 south, 4 west, 2 south`
    - One repeat from `(6,9)` did fail earlier at the seed stage with
      `target_not_reached`, so the approach is still state-sensitive, but the
      actual seam crossing has now succeeded from two different natural
      arrival vectors.
  - `6,10 -> LEFT -> 5,10` looks weaker:
    - Direct verifier remained mixed `moved=1 blocked=9`
    - Seeded natural approach from `(7,10)` into `(6,10)` then LEFT blocked
    - Seeded natural approach from true entrance anchor `(6,11)` via
      `probe_edge_after_raw_to:UP,40,6,10,20,LEFT` also blocked
    - Practical read: keep it on the board, but it is now clearly behind
      `(5,9)->DOWN` as the best forward-entry suspect into `5,10`.
  - Updated best resume:
    - prioritize more work around `(5,9)->DOWN` into `(5,10)`
    - treat `(6,10)->LEFT` as the weaker sibling fallback

- 2026-05-29 target-specific `5,10` frontier plus west-entry recheck:
  - Rechecked the strongest old live suspect from true arrival state:
    - from live `(5,9)`, `probe_edge:DOWN` blocked again cleanly
    - preview still reported `(5,10)` as `directional_blocked=true` with
      `blocked_approach=north`
    - practical read: `(5,9)->DOWN` remains real but highly state-sensitive,
      not reproducibly open from a straightforward entrance-side arrival
  - Entrance-side planner state is still closed regardless of NPC mode:
    - from `(6,11)`, both `debug_pathfind_to:1,18` and
      `debug_pathfind_to_skip_npcs:1,18` returned
      `No path found [no_path] (visited=291 path=0)`
    - current live runtime overlay remained `RUNTIME_BLOCKS map=0x18 count=37`
  - Goal-specific frontier aimed at the mixed pocket was the key new result:
    - from entrance `(6,11)`, `debug_pathfind_to:5,10` returned
      `No path found [no_path] (visited=286 path=0)`
    - but `debug_route_frontier:5,10,20` ranked the nearest bridge candidate
      as `(4,10)->RIGHT` into `(5,10)` with `target_side_dist=0`
    - this exposed a third entrance-side entry into the `5,10` pocket, beyond
      the already-known `(5,9)->DOWN` and `(6,10)->LEFT` seams
  - Direct recheck of the newly surfaced west entry:
    - `probe_edge_verify:4,10,RIGHT,10` => mixed `moved=4 blocked=6`
    - all four moves were `moved_model_mismatch`, so the live movement contradicted
      the current modeled west block each time it slipped through
    - practical read: `(4,10)->RIGHT` into `(5,10)` is now a top-tier suspect
      and materially stronger than the older `(6,10)->LEFT` lead
  - Real-arrival follow-up was started but got battle-contaminated:
    - from `(6,11)`, `debug_pathfind_to:4,10` planned
      `2 north, 2 west, 1 south`
    - live `auto_walk:4,10` did not stay on that clean route; it drifted right
      through `(7,11)` and a Warlock battle started before reaching `(4,10)`
    - treat that autowalk attempt as route/executor noise plus combat
      contamination, not evidence against the seam itself
  - Updated best resume:
    - after battle, re-establish field state and prioritize a natural-arrival
      check on `(4,10)->RIGHT` into `(5,10)`
    - keep `(5,9)->DOWN` as the other strong but state-sensitive bridge lead
    - demote `(6,10)->LEFT` behind the new west entry unless later evidence
      strengthens it

- 2026-05-29 west-entry repeat plus downstream seam classification:
  - Battle cleanup restored field state at live `(7,11)`.
  - Repeated the new west-entry lead with a natural arrival into `(4,10)`:
    - split teleport to `(4,9)` and `report_position`
    - `probe_edge_after_raw_to:DOWN,40,4,10,20,RIGHT`
    - result: clean move into `(5,10)` from a seeded real arrival at `(4,10)`
    - `EDGE_PROBE_MODEL_MISMATCH` logged this as movement through the currently
      modeled/runtime-blocked west approach, so `(4,10)->RIGHT` is a real live
      crossing, not just direct-verifier noise
  - From that natural landing on `(5,10)`, planner still *claimed* both sides:
    - `debug_pathfind_to:1,18` => `6 south, 4 west, 2 south`
    - `debug_pathfind_to:6,11` => `1 south, 1 east`
  - Live autowalk disproved that apparent reopening immediately:
    - `auto_walk:1,18` from live `(5,10)` failed on the first step
    - queued route tried `(5,10)->DOWN` into `(5,11)` three times and each
      attempt blocked
    - reroute then collapsed to `No path found`
  - Direct seam classification behind the reopened west entry:
    - `probe_edge_verify:5,10,DOWN,10` => blocked `10/10`
      - all ten blocks were `blocked_model_mismatch`
      - this is strong new evidence for `(5,11).north`
    - `probe_edge_verify:5,11,UP,10` => mixed `moved=3 blocked=7`
      - blocked attempts logged `blocked_despite_open_preview`
      - treat the reverse seam as noisy/mixed for now; do not promote it
  - Component check after runtime-injecting the clean south block:
    - `add_blocked_edge:5,10,DOWN`
    - from `(5,10)`, `debug_pathfind_to:1,18` then fell to
      `No path found [no_path] (visited=294 path=0)`
    - broad frontier from `(5,10)` to stairs reverted to the same old
      entrance-side runtime wall band, confirming this pocket no longer has any
      viable modeled exit toward B2 once `(5,10)->DOWN` is corrected
  - Stairs-side status of `(5,11)` is still real:
    - teleported `(5,11)` still pathfinds to stairs `(1,18)` in
      `5 south, 4 west, 2 south`
    - it also still pathfinds to entrance `(6,11)` in `1 east`
    - practical read: `(5,10)/(5,11)` is another bad forward gate cluster, not
      the missing entrance-to-B2 reopening
  - Entrance-side baseline after the new runtime block:
    - teleported `(6,11)` still gives
      `debug_pathfind_to:1,18 => No path found [no_path] (visited=291 path=0)`
    - `report_runtime_blocks` is now `count=38`
  - Updated practical read:
    - `(4,10)->RIGHT` into `(5,10)` is genuinely crossable from the entrance
      side
    - but the first continuation seam `(5,10)->DOWN` into `(5,11)` is a clean
      blocker, so the whole `5,10` cluster is now effectively disproved as the
      missing forward route to B2
  - Updated best resume:
    - keep the new runtime blocker `(5,10)->DOWN` live while investigating
    - de-prioritize the `5,9/5,10/5,11` cluster as a forward bridge lead
    - pivot back to the remaining unresolved mixed/non-runtime candidates,
      especially the old central x=10 oddities and any other untreated
      cross-component seam that survives the current runtime wall band

- 2026-05-29 central x=10 oddities follow-up after the `5,10` demotion:
  - Re-established fresh live state with `launcher_probe:codex_x10_live`.
  - Component checks on the central oddity cells all still stay on the
    entrance-side component under the current runtime overlay:
    - teleported `(10,12)`:
      - `debug_pathfind_to:1,18` => `No path found [no_path] (visited=362)`
      - `debug_pathfind_to:6,11` => `4 west, 1 north`
    - teleported `(10,11)`:
      - `debug_pathfind_to:1,18` => `No path found [no_path] (visited=361)`
      - `debug_pathfind_to:6,11` => `4 west`
    - teleported `(11,12)`:
      - `debug_pathfind_to:1,18` => `No path found [no_path] (visited=278)`
      - `debug_pathfind_to:6,11` => long entrance-side loop
        `1 north, 2 east, 1 south, 2 east, 5 north, 6 west, 4 south, 3 west`
    - Practical read: the whole x=10 oddity cluster remains local to the
      entrance side and is no longer a good cross-component bridge lead.
  - Direct seam rechecks inside that local cluster:
    - `probe_edge_verify:11,12,LEFT,10` => mixed `moved=3 blocked=7`
    - `probe_edge_verify:11,11,LEFT,10` => blocked `10/10`
      - this finally settles the old `(11,11)->LEFT` sibling as a real wall
    - `probe_edge_verify:9,12,RIGHT,10` => mixed `moved=2 blocked=8`
  - Updated practical read:
    - `(10,11)` is now effectively settled as entrance-side local geometry, not
      a cross-component bridge
    - the only still-weird x=10 behavior is the localized `(10,12)` seam,
      which remains mixed from both sides but still does not connect to the
      stairs-side component
  - Updated best resume:
    - de-prioritize the central x=10 oddities as a reopening target
    - keep them in mind only as local movement weirdness unless later frontier
      work shows a new component crossing nearby
    - resume hunting for an untreated cross-component seam elsewhere rather than
      spending more loops on `(10,11)/(10,12)`
  - Broad entrance frontier follow-up after this demotion:
    - teleported back to `(6,11)` and ran `debug_route_frontier:1,18,50`
    - ranks `1..42` were still dominated by the existing runtime wall band
    - the first non-runtime/blocked-directional entries after that were all
      already-known or already-disproved seams:
      `(4,15)->RIGHT`, `(4,14)->RIGHT`, `(7,14)->DOWN`, `(7,16)->UP`,
      `(4,14)->UP`, `(6,14)->UP`, `(8,16)->UP`, `(2,13)->RIGHT`
    - practical read: the obvious left-center follow-up cluster is now mostly
      exhausted too; no new clean cross-component seam surfaced in the top-50
      entrance frontier after de-prioritizing x=10

- 2026-05-29 left-center frontier follow-up after the x=10 demotion:
  - Repeated the interrupted `(2,13)/(3,13)` seam and settled it as another
    one-way gate:
    - component checks:
      - `(2,13)` reaches entrance only
      - `(3,13)` reaches both entrance and stairs
    - clean direct verifiers:
      - `probe_edge_verify:2,13,RIGHT,10` => blocked `10/10`
      - `probe_edge_verify:3,13,LEFT,10` => moved `11/11` with stability
        recheck
    - practical read: not the missing forward bridge; another reverse-biased
      lip into the deeper connected pocket
  - Neighbor seam `(3,14)->UP` into `(3,13)` stayed noisy but clearly real:
    - `probe_edge_verify:3,14,UP,10` => mixed `moved=4 blocked=6`
    - reverse `probe_edge_verify:3,13,DOWN,10` moved `10/10`, then battle
      interrupted only the stability recheck
    - practical read: likely another reverse-biased or state-sensitive gate;
      keep unmodeled for now
  - New component check on `(3,12)` was the biggest structural result:
    - teleported `(3,12)`:
      - `debug_pathfind_to:1,18` => `1 south, 2 east, 3 south, 4 west, 2 south`
      - `debug_pathfind_to:6,11` => `1 south, 3 east, 2 north`
    - practical read: `(3,12)` is firmly on the both-sides component
  - Entry seams into `(3,12)` from the entrance side:
    - `probe_edge_verify:3,11,DOWN,10` => blocked `10/10`
    - `probe_edge_verify:2,12,RIGHT,10` => blocked `10/10`
    - `probe_edge_verify:4,12,LEFT,10` => mixed `moved=1 blocked=9`
    - practical read: the whole `(3,12)` pocket matters, but only the west
      entry from `(4,12)` remains alive, and even that one is weak/noisy
  - Another sibling into the known `(5,11)` both-sides pocket also collapsed:
    - `probe_edge_verify:4,11,RIGHT,10` => blocked `10/10`
    - practical read: that older `5,11` pocket now has the known noisy `5,11`
      reverse seam and the confirmed blocked west entry from `(4,11)`
  - Updated best resume:
    - keep treating the route from entrance `(6,11)` to stairs `(1,18)` as
      closed under the current live/runtime model
    - the left-center cluster has mostly collapsed to just two noisy survivors:
      `(3,14)->UP` and `(4,12)->LEFT`
    - after those, pivot to the next untreated frontier candidate outside this
      cluster, especially `(7,12)->DOWN`

- 2026-05-29 survivor-focused follow-up plus next frontier seam:
  - Both old survivors are definitely entrance-side source tiles:
    - teleported `(3,14)`:
      - `debug_pathfind_to:1,18` => `No path found [no_path] (visited=302)`
      - `debug_pathfind_to:6,11` => `1 west, 5 north, 4 east, 2 south`
    - teleported `(4,12)`:
      - `debug_pathfind_to:1,18` => `No path found [no_path] (visited=317)`
      - `debug_pathfind_to:6,11` => `3 north, 2 east, 2 south`
    - practical read: if either seam matters, it must be as a forward lip into
      the connected region rather than because the source tile is already good
  - Reverse sides of both survivors are now settled passable:
    - `probe_edge_verify:3,13,DOWN,5` => moved `6/6` with stability recheck
    - `probe_edge_verify:3,12,RIGHT,5` => moved `6/6` with stability recheck
  - First survivor `(3,14)->UP` is a real forward crossing under a seeded
    entrance-side arrival:
    - start `(3,15)`, `probe_edge_after_raw_to:UP,40,3,14,20,UP`
    - target `(3,14)` was reached naturally, and the follow-up probe moved
      cleanly into `(3,13)`
    - practical read: this is not just direct-verifier noise; the forward lip
      itself is real
  - But that reopening immediately hits the next hidden wall:
    - from natural `(3,13)`, `auto_walk:1,18` planned
      `2 east, 3 south, 4 west, 2 south`
    - live movement failed on the very first step, `(3,13)->RIGHT`
    - direct follow-up `probe_edge_verify:RIGHT,5` from `(3,13)` => blocked
      `5/5`, with all blocks logged as `blocked_despite_open_preview`
    - after `add_blocked_edge:3,13,RIGHT`, `debug_pathfind_to:1,18` from
      `(3,13)` fell to `No path found [no_path] (visited=303 path=0)`
    - practical read: `(3,14)->UP` is a real bridge into the deeper pocket,
      but that pocket still does not connect onward to stairs because
      `(3,13)->RIGHT` is the next clean blocker
  - Second survivor `(4,12)->LEFT` did not hold up under a seeded natural
    arrival:
    - start `(5,12)`, `probe_edge_after_raw_to:LEFT,40,4,12,20,LEFT`
    - target `(4,12)` was reached naturally
    - follow-up probe blocked at `(4,12)->LEFT` with
      `EDGE_PROBE_RESULT ... status=blocked ... reason=raw_hold_timeout`
    - practical read: this seam remains weaker than the first survivor and is
      currently demoted behind it
  - Next untreated frontier seam `(7,12)->DOWN` into `(7,13)` is now also
    classified as another one-way gate:
    - component split:
      - `(7,12)` reaches entrance only
      - `(7,13)` reaches both entrance and stairs
    - clean direct verifiers:
      - `probe_edge_verify:7,12,DOWN,5` => blocked `5/5`
      - `probe_edge_verify:7,13,UP,3` => moved `4/4` with stability recheck
    - practical read: same shape as the other reverse-biased seams, not a new
      forward reopening
  - Fresh entrance frontier after runtime-injecting `(3,13)->RIGHT`:
    - `debug_route_frontier:1,18,70` from `(6,11)` dropped to
      `target_side=84`, `bridge_candidates=60`
    - the old survivor entries now rank as bridge-to-target `false`, which
      matches the new blocker behind `(3,14)->UP`
    - the next likely fresh blocked-directional candidate is `(9,14)->DOWN`,
      with `(9,13)->LEFT` / `(8,14)->UP` nearby in the same band

- 2026-05-29 `9,14/9,15` frontier follow-up:
  - Component split confirmed:
    - teleported `(9,14)`:
      - `debug_pathfind_to:1,18` => `No path found [no_path] (visited=336)`
      - `debug_pathfind_to:6,11` => `3 north, 3 west`
    - teleported `(9,15)`:
      - `debug_pathfind_to:1,18` => `4 west, 1 south, 4 west, 2 south`
      - `debug_pathfind_to:6,11` => `4 north, 3 west`
    - practical read: `(9,14)->DOWN` is another true cross-component seam
  - Direct seam checks then settled it as one-way:
    - `probe_edge_verify:9,14,DOWN,5` => blocked `5/5`
    - `probe_edge_verify:9,15,UP,3` => moved `4/4` with stability recheck
    - practical read: same reverse-open / forward-blocked pattern as
      `(2,13)/(3,13)` and `(7,12)/(7,13)`
  - Updated best resume:
    - keep runtime blocker `(3,13)->RIGHT` live while investigating
    - de-prioritize `(9,14)->DOWN` as another one-way gate rather than a
      likely forward reopening
    - next fresh entrance-side candidates in this same newly exposed band are
      `(9,13)->LEFT` and `(8,14)->UP`

- 2026-05-29 `9,13/8,14/8,13` seam band follow-up:
  - Shared destination pocket `(8,13)` is on the both-sides component:
    - `debug_pathfind_to:1,18` => `3 west, 3 south, 4 west, 2 south`
    - `debug_pathfind_to:6,11` => `2 west, 2 north`
  - Source tiles are both entrance-side only:
    - teleported `(9,13)`:
      - `debug_pathfind_to:1,18` => `No path found [no_path] (visited=337)`
      - `debug_pathfind_to:6,11` => `2 north, 3 west`
    - teleported `(8,14)`:
      - `debug_pathfind_to:1,18` => `No path found [no_path] (visited=336)`
      - `debug_pathfind_to:6,11` => `1 east, 3 north, 3 west`
    - practical read: both seams are true cross-component candidates
  - First suspect `(9,13)->LEFT` settled cleanly blocked:
    - `probe_edge_verify:9,13,LEFT,5` => blocked `5/5`
    - practical read: this one is retired as a forward reopening candidate
  - Second suspect `(8,14)->UP` is real but state-sensitive:
    - direct verifier `probe_edge_verify:8,14,UP,5` => moved `6/6` with
      stability recheck, despite `moved_through_modeled_block`
    - seeded natural arrival from the east did **not** hold:
      start `(9,14)`, `probe_edge_after_raw_to:LEFT,40,8,14,20,UP` reached
      `(8,14)` naturally, but the follow-up probe blocked
    - reverse side looked open before combat:
      `probe_edge_verify:8,13,DOWN,3` moved `2/2`, then battle interrupted the
      third/stability step
    - seeded natural arrival from the west **did** hold:
      start `(7,14)`, `probe_edge_after_raw_to:RIGHT,40,8,14,20,UP` reached
      `(8,14)` naturally and then moved into `(8,13)`
    - practical read: this is a real forward lip under at least one natural
      entrance-side approach, but it appears state/approach-sensitive
  - Just like the `(3,14)->UP` branch, the new lip dead-ends immediately:
    - from natural `(8,13)`, `auto_walk:1,18` planned
      `3 west, 3 south, 4 west, 2 south`
    - live movement failed on the very first step, `(8,13)->LEFT`
    - direct follow-up `probe_edge_verify:8,13,LEFT,5` => blocked `5/5`
      with all blocks logged as `blocked_despite_open_preview`
    - practical read: `(8,14)->UP` opens a second real forward branch into the
      deeper component, but that branch still dies immediately on a clean
      blocker at `(8,13)->LEFT`
  - Updated best resume:
    - keep runtime blocker `(3,13)->RIGHT` live; consider also mirroring the
      newly confirmed `(8,13)->LEFT` blocker at runtime before the next broad
      path/debug pass
    - de-prioritize `(9,13)->LEFT` as settled shut
    - the next useful work is either:
      - confirm whether `(8,13)->LEFT` should be runtime-injected and then
        rerun `debug_route_frontier:1,18`, or
      - continue one tile farther west/north around the `7,13` / `7,14`
        cluster if the user wants to keep harvesting this band

- 2026-05-29 post-`(8,13)->LEFT` frontier rerun and new bridge cleanup:
  - Mirrored the new blocker at runtime:
    - `add_blocked_edge:8,13,LEFT` => `RUNTIME_BLOCK map=0x18 x=7 y=13 dirs=east`
  - Fresh entrance rerun from `(6,11)` stayed closed:
    - `debug_pathfind_to:1,18` => `No path found [no_path] (visited=291)`
    - `debug_route_frontier:1,18,70` => `target_side=83`,
      `bridge_candidates=57`
    - practical read: adding `(8,13)->LEFT` did not reopen anything, but it
      did prune the target-side component a bit further
  - New band around `(4,14)/(4,13)`:
    - direct `probe_edge_verify:4,14,UP,5` stayed mixed at `moved=2 blocked=3`
    - sibling `probe_edge_verify:6,14,UP,5` settled cleanly blocked `5/5`
      and was mirrored at runtime with `add_blocked_edge:6,14,UP`
    - component split:
      - teleported `(4,13)` reaches both entrance and stairs:
        `debug_pathfind_to:6,11` => `2 east, 2 north`
        `debug_pathfind_to:1,18` => `1 east, 3 south, 4 west, 2 south`
      - teleported `(4,14)` remains entrance-side under the current model:
        `debug_pathfind_to:6,11` => `2 west, 5 north, 4 east, 2 south`
        `debug_pathfind_to:1,18` => `No path found [no_path] (visited=302)`
    - reverse side is now cleanly confirmed:
      - repeated battle-interrupted `probe_edge_verify:4,13,DOWN,5`
        runs each moved `5/5` before only the stability step got interrupted
      - shortened `probe_edge_verify:4,13,DOWN,3` then finished cleanly as
        `moved=4 blocked=0` with stability recheck
    - natural-arrival cleanup:
      - direct `probe_edge_verify:3,14,RIGHT,5` settled cleanly passable
        `6/6`
      - a real raw-field step `probe_edge:RIGHT` from `(3,14)` moved into
        `(4,14)`
      - from that actual natural `(4,14)` landing, follow-up `probe_edge:UP`
        cleanly blocked at `(4,14)->(4,13)`
      - practical read: despite the mixed teleported verifier, this branch
        behaves like another reverse-biased gate in live play:
        `(4,13)->DOWN` is open, but the usable forward lip from natural
        entrance-side `(4,14)` still blocks
  - Next untreated bridge-ranked seam after demoting that branch:
    - `probe_edge_verify:8,16,UP,5` => blocked `5/5`
    - mirrored at runtime with `add_blocked_edge:8,16,UP`
  - Fresh entrance rerun after that cleanup:
    - `debug_pathfind_to:1,18` from `(6,11)` still => `No path found`
      `[no_path] (visited=291)`
    - `debug_route_frontier:1,18,60` stayed at `target_side=83`,
      `bridge_candidates=57`
    - practical read: current best untreated blocked-directional candidates
      have shifted farther east to `(11,15)->LEFT` and `(10,16)->UP`

- 2026-05-29 east-pair follow-up around `(11,15)` / `(10,16)`:
  - Clean direct blocker:
    - `probe_edge_verify:10,16,UP,5` => blocked `5/5`
    - mirrored at runtime with `add_blocked_edge:10,16,UP`, merging into
      `RUNTIME_BLOCK map=0x18 x=10 y=15 dirs=north,south`
  - New cross-component seam candidate at `(11,15)->LEFT`:
    - direct verifier `probe_edge_verify:11,15,LEFT,5` stayed mixed at
      `moved=4 blocked=1`
    - component split:
      - teleported `(10,15)` reaches both entrance and stairs:
        `debug_pathfind_to:6,11` => `1 north, 1 west, 3 north, 3 west`
        `debug_pathfind_to:1,18` => `5 west, 1 south, 4 west, 2 south`
      - teleported `(11,15)` reaches entrance only:
        `debug_pathfind_to:6,11` => `1 north, 2 west, 3 north, 3 west`
        `debug_pathfind_to:1,18` => `No path found [no_path] (visited=332)`
      - practical read: this is a true cross-component seam candidate, not
        just local geometry
    - reverse side is cleanly open:
      - `probe_edge_verify:10,15,RIGHT,5` => moved `6/6` with stability
        recheck
    - natural entrance-side arrival also succeeded:
      - from real entrance `(6,11)`, `debug_pathfind_to:11,15` planned
        `3 east, 3 south, 2 east, 1 south`
      - `auto_walk:11,15` completed that route and landed on real field
        `(11,15)` with `AUTO_WALK_NPC_PARK_RESTORE ... reason=autowalk route complete`
    - but the actual forward seam still blocked from that natural landing:
      - first raw `probe_edge:LEFT` from natural `(11,15)` => blocked
      - immediate second raw `probe_edge:LEFT` from the same field landing =>
        blocked again
      - practical read: do **not** promote `(11,15)->LEFT` yet; despite the
        mixed teleported verifier and fully open reverse side, the natural
        entrance-side field evidence currently says blocked
  - Natural arrival to `(11,15)` exposed one fresh nearby noisy seam:
    - while autowalking, `(10,14)->RIGHT` into `(11,14)` first blocked on the
      queued step, then moved on seam retry
    - practical read: this `10,14/11,14` seam is now the next interesting
      local follow-up if we keep pushing this east pocket
  - Fresh entrance rerun after mirroring only `(10,16)->UP`:
    - `debug_pathfind_to:1,18` from `(6,11)` still => `No path found`
      `[no_path] (visited=291)`
    - `debug_route_frontier:1,18,60` stayed at `target_side=83`,
      `bridge_candidates=57`
    - `report_runtime_blocks` stayed at `count=39`
    - practical read: the clean blocker harvest progressed, but the broad
      frontier still does not reopen; keep `(11,15)->LEFT` as unresolved but
      downgraded, and consider `(10,14)->RIGHT` next

- 2026-05-29 focused follow-up on `(10,14)->RIGHT` context:
  - Reconfirmed the nearby downgraded seam context before shifting:
    - the broad entrance rerun still lists `(11,15)->LEFT` as rank 57
      `bridge_to_target=true`, but it remains unmodeled because:
      - direct `probe_edge_verify:11,15,LEFT,5` stayed mixed
        `moved=4 blocked=1`
      - reverse `probe_edge_verify:10,15,RIGHT,5` stayed fully open `6/6`
      - a real entrance-side `auto_walk:11,15` from `(6,11)` completed and
        landed on field `(11,15)`
      - from that actual natural landing, two immediate raw `probe_edge:LEFT`
        attempts both blocked
      - practical read: this seam is now further downgraded toward
        reverse-biased or strongly state-sensitive rather than an immediate
        promotion candidate
  - The natural arrival to `(11,15)` cleanly exposed a new local seam:
    - `auto_walk:11,15` from `(6,11)` used path
      `3 east, 3 south, 2 east, 1 south`
    - along the route, `(10,14)->RIGHT` into `(11,14)` first blocked on the
      queued step, then moved on seam retry
    - resulting evidence:
      - initial queued step logged `SEAM_OBSERVATION ... cell=(11,14)
        approach=west result=blocked blocked=1 moved=0 classification=blocked_only`
      - seam retry then completed into `(11,14)`, downgrading the same seam to
        `classification=noisy`
      - after landing at `(11,14)`, reroute to `(11,15)` was just `1 south`
        and the walk completed normally
    - direct isolation then demoted it:
      - `probe_edge_verify:10,14,RIGHT,5` => moved `6/6` with stability
      - teleported `(11,14)` reaches entrance only:
        `debug_pathfind_to:6,11` => `2 west, 3 north, 3 west`
        `debug_pathfind_to:1,18` => `No path found [no_path] (visited=332)`
      - practical read: `(10,14)->RIGHT` is simply open terrain into another
        entrance-side tile, not a bridge candidate; retire this local pocket
        as a reopening lead

- 2026-05-29 reverse-frontier middle-pocket cleanup after retiring
  `(10,14)->RIGHT`:
  - Clean reverse baseline:
    - `teleport_to:1,18 report_position`
    - `debug_route_frontier:6,11,90` from clean `(1,18)` stayed at
      `reachable=315 target_side=364 candidates=134 bridge_candidates=97`
    - top untreated directional ranks were concentrated in the same middle
      pocket: `(11,12)->LEFT`, `(10,14)->UP`, `(11,14)->UP`, `(12,9)->DOWN`,
      `(12,11)->UP`, `(12,14)->UP`, `(13,14)->UP`
  - Clean new blockers promoted at runtime:
    - `(11,12)->LEFT` => `probe_edge_verify:11,12,LEFT,5` blocked `5/5`
      with no drift/map change/interruption; mirrored with
      `add_blocked_edge:11,12,LEFT`, merging into
      `RUNTIME_BLOCK map=0x18 x=10 y=12 dirs=east,west`
    - `(11,14)->UP` => `probe_edge_verify:11,14,UP,5` blocked `5/5`;
      mirrored into `RUNTIME_BLOCK map=0x18 x=11 y=13 dirs=south`
    - `(12,14)->UP` => `probe_edge_verify:12,14,UP,5` blocked `5/5`;
      mirrored into `RUNTIME_BLOCK map=0x18 x=12 y=13 dirs=south`
    - `(13,14)->UP` => `probe_edge_verify:13,14,UP,5` blocked `5/5`;
      mirrored into `RUNTIME_BLOCK map=0x18 x=13 y=13 dirs=south`
    - `(12,11)->UP` => `probe_edge_verify:12,11,UP,5` blocked `5/5`;
      mirrored into `RUNTIME_BLOCK map=0x18 x=12 y=10 dirs=south`
  - Mixed, keep unmodeled:
    - `(10,14)->UP` => `probe_edge_verify:10,14,UP,5` stayed mixed at
      `moved=1 blocked=4`; the one move was a model mismatch, so treat it as
      suspicious but not promotable
    - `(12,9)->DOWN` => `probe_edge_verify:12,9,DOWN,5` stayed mixed at
      `moved=2 blocked=3`; the two moves were model mismatches, so treat it as
      the stronger remaining x=12 oddity
  - Practical read:
    - a new reverse-side false-front is now emerging across the row-14 north
      lip into `(11,13)`, `(12,13)`, and `(13,13)`
    - the adjacent x=12 pocket is not cleanly solved yet; `(12,11)->UP`
      blocked cleanly while `(12,9)->DOWN` stayed mixed, so this area still
      looks one-way or strongly state-sensitive rather than like a broad open
      corridor
  - Broad verification after the batch:
    - from real entrance `(6,11)`, `debug_pathfind_to:1,18` still returned
      `No path found [no_path] (visited=291 path=0)`
    - `report_runtime_blocks` is now `count=45`
  - Best next reverse-side seams after this batch:
    - `(13,9)->DOWN`
    - `(13,11)->UP`
    - `(14,12)->UP`
    - if those dry up, revisit the two mixed survivors with natural/reverse
      follow-up:
      `(10,14)->UP` and `(12,9)->DOWN`

- 2026-05-29 follow-up on the next reverse-side batch plus mixed-pocket
  classification:
  - Clean new blockers promoted at runtime:
    - `(13,9)->DOWN` => `probe_edge_verify:13,9,DOWN,5` blocked `5/5`;
      mirrored into `RUNTIME_BLOCK map=0x18 x=13 y=10 dirs=north`
    - `(13,11)->UP` => `probe_edge_verify:13,11,UP,5` blocked `5/5`;
      mirrored into the same cell, now
      `RUNTIME_BLOCK map=0x18 x=13 y=10 dirs=north,south`
    - `(14,12)->UP` => `probe_edge_verify:14,12,UP,5` blocked `5/5`;
      mirrored into `RUNTIME_BLOCK map=0x18 x=14 y=11 dirs=south`
  - Immediate contour read:
    - the x=13 strip is now much cleaner: `(13,10)` is fully closed north/south
    - the wider middle-pocket false-front extends at least one cell farther
      east via `(14,11).south`
  - Mixed siblings that should stay unmodeled:
    - `(13,11)->RIGHT` => `moved=1 blocked=4`
    - `(15,11)->LEFT` => `moved=2 blocked=3`
    - `(14,9)->DOWN` => `moved=2 blocked=3`
    - `(15,10)->LEFT` => `moved=3 blocked=2`
  - Destination-cell classification resolved the ambiguity:
    - teleported `(14,10)` pathfinds to entrance but not to stairs:
      - `debug_pathfind_to:6,11` => `5 west, 1 south, 3 west`
      - `debug_pathfind_to:1,18` => `No path found [no_path] (visited=357)`
    - teleported `(14,11)` also pathfinds to entrance but not to stairs:
      - `debug_pathfind_to:6,11` => `1 north, 5 west, 1 south, 3 west`
      - `debug_pathfind_to:1,18` => `No path found [no_path] (visited=363)`
    - practical read: the mixed entries into `(14,10)` / `(14,11)` are not
      viable bridge candidates; they are entrance-side noise or one-way/state-
      sensitive behavior
  - Broad entrance verification after demoting that pocket:
    - `debug_route_frontier:1,18,80` still reports
      `reachable=243 target_side=83 candidates=159 bridge_candidates=57`
    - the newly added reverse-side blockers now show up as
      `bridge_to_target=false` on the entrance frontier
    - `debug_pathfind_to:1,18` from `(6,11)` still returns
      `No path found [no_path] (visited=291 path=0)`
    - `report_runtime_blocks` now reports `count=47`
  - Best next live suspects after this cleanup:
    - stronger older mixed survivors:
      `(12,9)->DOWN` and `(10,14)->UP`
    - fresh farther-north reverse-side contour:
      `(13,7)->DOWN` into `(13,8)` and `(14,9)->UP` into `(14,8)`

- 2026-05-29 repeat on the interrupted x=12 seam plus farther-north contour:
  - Interrupted reverse repeat on `(12,10)->UP` had already hinted open:
    first battle-cut pass finished `moved=5 blocked=0 interrupted=1`
  - Clean repeat settled it:
    - `probe_edge_verify:12,10,UP,5` => moved `6/6` with stability recheck
    - destination `(12,9)` remains suspicious only from the upper side, not as
      a bridge: teleported `(12,10)` reaches entrance via
      `3 west, 1 south, 3 west`, but `debug_pathfind_to:1,18` stays
      `No path found [no_path] (visited=362)`
    - practical read: `(12,9)->DOWN` is now best treated as another one-way or
      state-sensitive trap lip rather than a valid bridge lead
  - Farther-north contour:
    - clean blocker:
      `probe_edge_verify:13,7,DOWN,5` => blocked `5/5`
      mirrored with `add_blocked_edge:13,7,DOWN`, yielding
      `RUNTIME_BLOCK map=0x18 x=13 y=8 dirs=north`
    - sibling stayed mixed:
      `probe_edge_verify:14,9,UP,5` => `moved=2 blocked=3`
    - direct destination classification demoted the whole pocket:
      - teleported `(14,8)` reaches entrance via `8 west, 3 south`
        but not stairs (`visited=322`)
      - teleported `(13,8)` reaches entrance via `7 west, 3 south`
        but not stairs (`visited=327`)
      - practical read: `(13,8)/(14,8)` is another entrance-side-only pocket,
        so the mixed `14,9->UP` seam is not a fresh bridge lead
  - Revisit on the old strongest mixed lead:
    - teleported `(11,15)` still reaches entrance via
      `1 north, 2 west, 3 north, 3 west`
      but not stairs (`visited=332`)
    - stronger direct verifier `probe_edge_verify:11,15,LEFT,10` stayed mixed
      at `moved=3 blocked=7`
    - practical read: `(11,15)->LEFT` is still the highest-value unresolved
      mixed seam, but it is continuing to drift toward reverse-biased or
      state-sensitive rather than a clean forward bridge
  - Broad verification after this whole batch:
    - from real entrance `(6,11)`, `debug_pathfind_to:1,18` still returns
      `No path found [no_path] (visited=291 path=0)`
    - `report_runtime_blocks` now reports `count=48`

- 2026-05-29 source-vs-live sync after the final extra pass:
  - Compared the latest `RUNTIME_BLOCKS map=0x18 count=48` snapshot against
    `map_reader.get_directional_blocks(0x18)` with a repo-local Lua script.
  - Only four live directions were still missing from source:
    - `(4,13).west`
    - `(5,11).north`
    - `(7,13).east`
    - `(14,17).north`
  - Patched those four into `map_reader.lua` and added matching assertions to
    `test_map_reader.lua`.
  - Focused source checks all passed:
    - `luac5.1 -p map_reader.lua test_map_reader.lua`
    - `lua5.1 test_map_reader.lua`
    - `git diff --check -- map_reader.lua test_map_reader.lua`
  - Re-ran the same source-vs-live comparison:
    - result: `all_runtime_dirs_present`
  - Practical read:
    - the current 48-direction B1 runtime overlay is now fully represented in
      source
    - the next real action is restart/manual reload, not more live blocker
      harvesting on this stale session

- 2026-05-29 clean-restart follow-up on the old `(11,15)` mixed lead:
  - Clean baseline after restart/manual reload:
    - `report_runtime_blocks` => `RUNTIME_BLOCKS map=0x18 none`
    - `debug_pathfind_to:1,18` from `(6,11)` => `No path found [no_path] (visited=291 path=0)`
    - `debug_route_frontier:1,18,60` stayed
      `reachable=243 target_side=83 candidates=159 bridge_candidates=57`
  - Initial rerun was contaminated by menu/input state, not map evidence:
    - `auto_walk:11,15` first cancelled with
      `reason=Close the command menu before auto-walking`
    - after `simulate_input:B`, `EVENT: command menu closed`, and
      `report_menu_state` confirmed `raw_open=false`
  - Clean natural-arrival retest of the local branch:
    - `auto_walk:11,15` from `(6,11)` again reached the `(11,14)->(11,15)` lip
      before a Skeleton battle interrupted it
    - after the battle, from live `(11,14)`,
      `probe_edge:DOWN` cleanly moved into `(11,15)`
    - from that true natural `(11,15)` landing:
      - `probe_edge:LEFT` blocked twice in a row on `(11,15)->(10,15)`
      - `debug_pathfind_to:1,18` => `No path found [no_path] (visited=332 path=0)`
      - `debug_pathfind_to:6,11` => `1 north, 2 west, 3 north, 3 west`
      - practical read: this natural `(11,15)` landing is still entrance-side
        only, so the old mixed `(11,15)->LEFT` lead is further demoted
  - New hidden blocker discovered on the same landing:
    - `probe_edge:RIGHT` from natural `(11,15)` blocked twice in a row even
      though preview said `(12,15)` was open
    - stronger verifier settled it cleanly:
      `probe_edge_verify:11,15,RIGHT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
      with `blocked_model_mismatch=5` and repeated
      `EDGE_PROBE_MODEL_MISMATCH ... kind=blocked_despite_open_preview`
    - mirrored live with `add_blocked_edge:11,15,RIGHT`, producing
      `runtime block: map=0x18 cell=(12,15) approach=west source=manual_edge_command`
    - after mirroring just that seam, `report_runtime_blocks` shows
      `count=1`, `debug_pathfind_to:1,18` from `(6,11)` stays closed at
      `visited=292`, and the broad entrance frontier still stays
      `target_side=83 bridge_candidates=57`
  - South extension of the pocket is real:
    - `probe_edge_verify:11,15,DOWN,5` finished with stability recheck at
      `moved=6 blocked=0 classification=confirmed_passable`
    - live landing after that verification is `(11,16)`
    - from live `(11,16)`, `probe_edge:RIGHT` cleanly moved into `(12,16)`
    - but `debug_pathfind_to:1,18` from `(12,16)` still returned
      `No path found [no_path] (visited=332 path=0)`
    - practical read: the local branch extends through `(11,16)` into
      `(12,16)`, but it still appears to be entrance-side terrain rather than
      a reopening to B2
  - Best next local follow-up after this pass:
    - keep the new runtime blocker `(12,15).west` live
    - continue from the open `(11,15)->DOWN->(11,16)->RIGHT->(12,16)` branch
      instead of spending more loops on `(11,15)->LEFT`

## 2026-05-30 B1 southeast locked-door hunt

- Re-centered the search after guide review: B1's locked door is still
  described externally as being in the southeast part of the floor, reached
  from the east-wall branch that also feeds the chest side. This makes the
  old `(9,6)` upper-pocket suspicion a poor primary door lead.
- Pulled the repo-local B1 map assets from
  `project_resources/maps/garins_grave/`. The Mike's RPG Center B1 map image
  places the door icon on the southeast shelf, visually aligning with the
  tiny B2-side/east-pocket component we had already isolated around row `18`.
- Live southeast shelf baseline:
  - `report_door_state` still only showed the already-open Garinham grave-route
    door in slot `0=(17,10)`. No B1 southeast door coordinate has been written
    into door RAM yet.
  - Teleport/read-only checks from the likely south stand squares all produced
    the same profile:
    - `(16,18)->UP` into `(16,17)`
    - `(17,18)->UP` into `(17,17)`
    - `(18,18)->UP` into `(18,17)`
    - `(19,18)->UP` into `(19,17)`
  - For each of those, `inspect_tile` reported the destination as ordinary
    walkable floor (`tile=2`, `base_walkable=true`, `reason=tile_type`) while
    `inspect_move` reported `directional_blocked=true`,
    `blocked_approach=south`, and `effective_passable=false`.
- Practical read:
  - this row-17 south-approach band still looks exactly like the kind of
    "ordinary floor, but blocked from one side" profile a closed, unmodeled
    magic-key door can masquerade as in this project
  - strongest manual OPEN candidates are the south-facing checks from row `18`,
    west-to-east:
    1. stand at `(16,18)`, face north
    2. stand at `(17,18)`, face north
    3. stand at `(18,18)`, face north
    4. stand at `(19,18)`, face north
  - highest-priority starts are `(16,18)` and `(17,18)` because the local map
    icon appears slightly left of the far-right wall rather than pinned to the
    extreme `x=19` corner.
- If one of those OPEN attempts succeeds, immediately re-run
  `report_door_state` and then recheck route/path behavior; the new coordinate
  should appear in door RAM and will give us the exact B1 override to model.
- Validation succeeded immediately after the user retried it:
  - `report_door_state` from live `(17,18)` showed
    `DOOR_STATE keys=4 slots=0=(17,10) 1=(17,17) ...`
  - direct `probe_edge:UP` from `(17,18)` moved into `(17,17)` with
    `EDGE_PROBE_RESULT ... status=moved final=(17,17) reached_dest=true`
    while the old model still logged
    `EDGE_PROBE_MODEL_MISMATCH ... kind=moved_through_modeled_block`
  - `inspect_move:17,17,UP` then showed the north continuation into `(17,16)`
    as open (`effective_passable=true`)
  - follow-up code patch replaced the stale `["17,17"] = {north=true,south=true}`
    directional blocker with a real `MAP_DOOR_CELLS[0x18]["17,17"]`
    override and added the `door_17_17` / `B2 Door` object entry
- Follow-up route quality after the door fix:
  - with the door open, the user completed both entrance -> B2 Door and
    entrance -> B2 stairs live in FCEUX
  - `debug_pathfind_to:1,18` from live entrance `(6,11)` now succeeds under
    open-door RAM with:
    `3 east, 4 north, 10 east, 9 south, 2 west, 1 south, 8 west, 1 south, 8 west`
  - the successful entrance -> stairs run was cleaner than the first
    door-opening pass, but still showed some seam-retry timing chatter
  - strongest cells to keep treated as timing/noise for now because they later
    moved on seam retry:
    `(19,16).north`, `(17,16).east`, `(14,19).east`, `(12,18).east`,
    `(1,19).east`
  - strongest cells that still behaved like durable route-shaping walls on the
    same run:
    `(16,17).east` and `(17,19).north`
  - 2026-05-30 return-route cleanup rechecked those carryover suspects plus the
    fresh stair-to-entrance seam hits:
    - `(16,17).east` from `(17,17)->LEFT` confirmed blocked `5/5`; promote it
    - `(17,19).north` from `(17,18)->DOWN` stayed mixed `moved=1 blocked=4`
    - `(17,19).west` from `(16,19)->RIGHT` stayed mixed `moved=2 blocked=3`
    - `(18,8).south` from `(18,9)->UP` stayed mixed `moved=1 blocked=4`
    - `(16,9).east` from `(17,9)->LEFT` stayed mixed `moved=1 blocked=4`
    - `(14,18).west` from `(13,18)->RIGHT` moved `6/6`
    - `(19,13).south` from `(19,14)->UP` moved `6/6`
    - `(19,16).west` from `(18,16)->RIGHT` moved `6/6`
  - Net: only `(16,17).east` from this return-route audit meets promotion
    threshold; the other fresh suspects should stay unmodeled unless a later
    cleaner natural route proves them blocked.

## 2026-05-30 B2 southwest-stair return-route pre-reload blocker harvest

- User asked for a live blocker grab before reloading after more FCEUX testing
  on the B1 <-> B2 southwest stair route.
- Fresh baseline:
  - `report_position` logged `POSITION: map=0x19(Garin's Grave B2) x=1 y=3`
  - `report_runtime_blocks` initially logged `RUNTIME_BLOCKS map=0x19 none`
- Strong repeated route-shaped seam failures in `dw_debug.log`:
  - `(2,3)` approach `west` climbed to `blocked=6 moved=0`
  - `(1,2)` approach `south` climbed to `blocked=6 moved=0`
  - `(2,4)` approach `west` climbed to `blocked=6 moved=0`
  - `(2,5)` approach `west` climbed to `blocked=8 moved=0`
  - `(2,6)` approach `west` climbed to `blocked=6 moved=0`
  - `(2,7)` approach `west` climbed to `blocked=4 moved=0` in the fresh tail,
    with the same seam already seen earlier in the same route family
  - `(1,9)` approach `north` climbed to `blocked=4 moved=0`
- Noisy/non-promoted neighbors from the same route family:
  - `(1,9)` approach `south` later moved
  - `(1,8)` north-side chatter stayed mixed
  - deeper east-side suspects such as `(13,6)`, `(13,2)`, `(12,11)`,
    and `(13,9)` were not clean enough for a live promotion here
- Because the user specifically wanted the blockers preserved before reload,
  the strongest left-edge cluster was injected directly as explicit map `0x19`
  runtime edge blocks:
  - `add_blocked_edge:0x19,1,3,RIGHT`
  - `add_blocked_edge:0x19,1,4,RIGHT`
  - `add_blocked_edge:0x19,1,5,RIGHT`
  - `add_blocked_edge:0x19,1,6,RIGHT`
  - `add_blocked_edge:0x19,1,7,RIGHT`
  - `add_blocked_edge:0x19,1,3,UP`
  - `add_blocked_edge:0x19,1,8,DOWN`
- Readback at frames `52860` and `53220` confirmed:
  - `RUNTIME_BLOCKS map=0x19 count=7`
  - `RUNTIME_BLOCK map=0x19 x=1 y=2 dirs=south`
  - `RUNTIME_BLOCK map=0x19 x=2 y=3 dirs=west`
  - `RUNTIME_BLOCK map=0x19 x=2 y=4 dirs=west`
  - `RUNTIME_BLOCK map=0x19 x=2 y=5 dirs=west`
  - `RUNTIME_BLOCK map=0x19 x=2 y=6 dirs=west`
  - `RUNTIME_BLOCK map=0x19 x=2 y=7 dirs=west`
  - `RUNTIME_BLOCK map=0x19 x=1 y=9 dirs=north`
- These are still runtime-only. Promote to `map_reader.lua` only after a calmer
  directed verifier pass or after the user confirms they materially clean up
  the return route.

## 2026-05-30 B2 left-edge suspect verifier pass after reload

- Fresh reload baseline:
  - `POSITION: map=0x19(Garin's Grave B2) x=1 y=4`
  - `RUNTIME_BLOCKS map=0x19 none`
  - `log_state` showed clean level-12 stats with `HP 51/63`, `MP 34/52`,
    `spells CE=0x3F`, and no stat-integrity warning.
- Direct verifier results:
  - `probe_edge_verify:1,3,RIGHT,5` into `(2,3)` blocked `5/5`
  - `probe_edge_verify:1,4,RIGHT,5` into `(2,4)` blocked `5/5`
  - `probe_edge_verify:1,5,RIGHT,5` into `(2,5)` blocked `5/5`
  - `probe_edge_verify:1,6,RIGHT,5` into `(2,6)` blocked `5/5`
  - `probe_edge_verify:1,7,RIGHT,5` into `(2,7)` blocked `5/5`
  - `probe_edge_verify:1,3,UP,5` into `(1,2)` was mixed
    (`moved=1 blocked=4`)
  - stronger `probe_edge_verify:1,3,UP,8` was interrupted by combat after
    `moved=2 blocked=0`, so keep `(1,2).south` unmodeled
  - `probe_edge_verify:1,8,DOWN,5` into `(1,9)` was mixed
    (`moved=1 blocked=4`), so keep `(1,9).north` unmodeled
- Combat diagnostic note:
  - battle started during the stronger `(1,3)->UP` retry, but the battle-start
    snapshot stayed clean (`HP 51/63`, `MP 34/52`, `STR=0x30`, `AGI=0x24`,
    `spells CE=0x3F`), with no `PLAYER_STAT_INTEGRITY_WARNING`
  - enemy readout was `A Wolf draws near!`
- Source/live outcome:
  - promoted `(2,3).west`, `(2,4).west`, `(2,5).west`, `(2,6).west`, and
    `(2,7).west` into `MAP_DIRECTIONAL_BLOCKS[0x19]`
  - added `test_map_reader.lua` regression checks for the five promoted edges
    and for keeping `(1,2).south` / `(1,9).north` unmodeled
  - validation passed with `luac5.1 -p map_reader.lua test_map_reader.lua`,
    `lua5.1 test_map_reader.lua`, and `git diff --check`
  - after the fight/script-log restart, re-injected the five confirmed blockers
    live with explicit `add_blocked_edge:0x19,...` commands; readback confirmed
    `RUNTIME_BLOCKS map=0x19 count=5`

## 2026-05-30 follow-up pass from southwest side toward B2 stairs

- The newest autowalk pass eventually reached `POSITION: map=0x19(Garin's
  Grave B2) x=11 y=2`.
- Useful read from the route tail:
  - `(13,5).south` looked blocked once, then moved on retry after the next
    attempt; treat it as noisy
  - `(13,2).south` did the same; blocked once, then moved on retry; treat it
    as noisy
  - `(13,8).south` also blocked once before a battle, then moved on the next
    pass; treat it as noisy
- Stronger row-9/row-10 suspects from the same route family:
  - route evidence repeatedly hit south approaches into `(4,9)`, `(5,9)`,
    `(6,9)`, `(7,9)`, `(8,9)`, `(9,9)`, `(10,9)`, and `(12,9)`
  - direct follow-up verifiers settled only a conservative subset:
    - `probe_edge_verify:4,10,UP,5` => `(4,9).south` blocked `5/5`
    - `probe_edge_verify:10,10,UP,5` => `(10,9).south` blocked `5/5`
    - `probe_edge_verify:12,10,UP,5` => `(12,9).south` blocked `5/5`
    - `probe_edge_verify:7,10,UP,5` stayed mixed at `moved=2 blocked=3`, so
      keep `(7,9).south` unmodeled
- Source/live outcome:
  - promoted `(4,9).south`, `(10,9).south`, and `(12,9).south` into
    `MAP_DIRECTIONAL_BLOCKS[0x19]`
  - added regression checks that keep `(7,9).south` open after the mixed
    verifier
  - validation passed with `luac5.1 -p map_reader.lua test_map_reader.lua`,
    `lua5.1 test_map_reader.lua`, and `git diff --check`
  - live readback after `add_blocked_edge` confirmed
    `RUNTIME_BLOCKS map=0x19 count=3` with `(4,9).south`, `(10,9).south`, and
    `(12,9).south`

## 2026-05-30 lower-combat follow-up pass

- Another return pass to the B2 upstairs route reached the same general
  row-9/row-10 corridor with less battle interruption.
- Direct follow-up verifiers on the remaining middle suspects:
  - `probe_edge_verify:8,10,UP,5` stayed mixed at `moved=2 blocked=3`, so keep
    `(8,9).south` unmodeled
  - `probe_edge_verify:9,10,UP,5` confirmed `(9,9).south` blocked `5/5`
  - `probe_edge_verify:12,10,LEFT,5` into `(11,10)` finished fully passable
    with stability recheck (`moved=6 blocked=0`), so do not model
    `(11,10).east`
- Source/live outcome:
  - promoted `(9,9).south` into `MAP_DIRECTIONAL_BLOCKS[0x19]`
  - extended the regression test to keep `(8,9).south` open after the mixed
    verifier
  - live runtime overlay was refreshed afterward to include the full confirmed
    B2 set for the current session:
    `(2,3).west`, `(2,4).west`, `(2,5).west`, `(2,6).west`, `(2,7).west`,
    `(4,9).south`, `(9,9).south`, `(10,9).south`, and `(12,9).south`
  - readback confirmed `RUNTIME_BLOCKS map=0x19 count=9`

## 2026-05-30 Wolf stat-corruption timing follow-up

- User reported another corrupted combat with a strong Wolf on B2. The Wolf
  attacked first and the fight went badly enough to suggest attack/defense were
  corrupted too, not just spells/MP.
- Log evidence confirms that broader stat collapse:
  - battle-start trace at frame `51905` was already bad in every retained
    field sample from frames `51894..51905`
  - corrupted state at battle start: `HP 52/15`, `MP 30/0`, `STR=0x04`,
    `AGI=0x03`, `ATK=0x18`, `DEF=0x1F`, `spells CE=0x00`, `CF=0x10`
  - corrupted `stat_ram BA-CF=2F 11 F9 0D B5 03 02 45 C3 00 00 34 1E 0C 04 03 0F 00 18 1F 00 10`
  - `A Wolf draws near!` did not log until frame `51965`
  - `The Wolf attacked before Bill was ready. The Wolf attacks!` logged at
    frame `52032`
  - `BATTLE_SPELL: Spells blocked.` logged later at frame `57559`
- Practical read:
  - the Wolf's first strike is probably not the root cause; the retained
    field-ring samples prove corruption existed before the Wolf dialogue and
    before the ambush attack line
  - the trace window was still too short to catch the clean-to-bad flip
- After the user restored the clean save state to the grave, `report_position`
  / `log_state` at frame `77100` confirmed map `0x19` `(1,11)`, level 12,
  `HP 52/63`, `MP 30/52`, `STR=0x30`, `AGI=0x24`, `ATK=0x44`, `DEF=0x30`,
  `spells CE=0x3F`, `CF=0x10`, and
  `stat_ram BA-CF=21 11 D3 0D B5 03 02 45 C3 00 00 34 1E 0C 30 24 3F 34 44 30 3F 10`.
- Disk patch outcome:
  - `debug_tools.lua` now keeps a longer per-frame `BA-CF` ring buffer and
    emits `PLAYER_STAT_INTEGRITY_TRANSITION` as soon as the tick monitor sees
    clean stats become impossible, followed by
    `PLAYER_STAT_TRACE_BEGIN context=stat_transition`
  - if battle-start forensics fire right after that transition dump, they log
    `PLAYER_STAT_TRACE_SKIPPED context=battle_start reason=recent_transition_dump`
    rather than duplicating the same trace
  - FCEUX needs a manual Lua reload before this transition detector is live
- Live overlay housekeeping:
  - after the save-state restore, `report_runtime_blocks` showed
    `RUNTIME_BLOCKS map=0x19 none`
  - re-applied the nine already-confirmed B2 runtime edges for the current
    session; readback at frame `90660` confirmed `RUNTIME_BLOCKS map=0x19 count=9`

## 2026-05-30 Metal Scorpion stat-corruption transition capture

- User reported another corruption event during a Metal Scorpion fight on
  Garin's Grave B2. This is the cleanest timing capture so far because the new
  per-frame transition detector was live.
- Route context before the flip:
  - auto-walk was moving from the B2 return stair area `(11,2)` toward the
    southwest B3 stairs at `(1,10)`
  - frame `51241`: `auto_step complete dir=up from=(11,2) to=(11,1)`
  - frames `51070..51249`: retained trace samples stayed clean at level 12,
    `HP 54/63`, `MP 14/52`, `STR=0x30`, `AGI=0x24`, `ATK=0x44`,
    `DEF=0x30`, `spells CE=0x3F`, with
    `stat_ram BA-CF=A4 11 1C 0F B5 03 02 45 C3 00 00 36 0E 0C 30 24 3F 34 44 30 3F 10`
- Exact transition:
  - frame `51250`: `PLAYER_STAT_INTEGRITY_TRANSITION from=clean to=bad`
    while still in field state on map `0x19` at `(11,1)`
  - corrupted state: `HP 54/15`, `MP 14/0`, level still `12`,
    `STR=0x04`, `AGI=0x03`, `ATK=0x18`, `DEF=0x1F`,
    `spells CE=0x00`, `CF=0x10`
  - changed bytes were only `C8,C9,CA,CB,CC,CD,CE`; current HP `C5`,
    current MP `C6`, and level `C7` did not change at the transition
  - corrupted `stat_ram BA-CF=A4 11 1C 0F B5 03 02 45 C3 00 00 36 0E 0C 04 03 0F 00 18 1F 00 10`
- Battle timing:
  - frame `51300`: battle start fired 50 frames after the stat flip and skipped
    the duplicate battle-start trace because the transition dump was recent
  - frame `51369`: first enemy-name dialogue, `A Metal Scorpion draws near!`
  - frame `51466`: first-strike text, `The Metal Scorpion attacked before Bill
    was ready.`
  - frame `60840`: live `log_state` during the same fight still showed the
    corrupt profile: `HP 28/15`, `MP 14/0`, level `12`, same low stats/spells,
    and enemy HP now `14`
- Practical read:
  - the enemy dialogue and first strike are again too late to be the cause
  - the good frame-`51249` trace sample was captured before that frame's
    `FCEU.frameadvance()`, and the bad frame-`51250` sample was captured on
    the next Lua tick, so the write most likely occurs during the NES frame
    advance / game-engine transition work rather than from a command handler
  - project Lua search still finds no runtime writes to player stat bytes
    `0x00C8..0x00CE`; known Lua writes touch movement, teleport, door, and NPC
    bytes instead
  - the bad values look like level-1 base stats plus equipment-derived attack
    and defense: `STR=4`, `AGI=3`, `MAX_HP=15`, `MAX_MP=0`, `spells=0`,
    `ATK=0x18`, `DEF=0x1F`, while the actual level byte stays `12`
- Source follow-up:
  - `debug_tools.before_frameadvance()` and `debug_tools.after_frameadvance()`
    now wrap the main loop's `FCEU.frameadvance()` call
  - if a clean-to-bad or bad-to-clean stat-integrity transition happens across
    that exact boundary, the log emits `PLAYER_STAT_FRAMEADVANCE_TRANSITION`
    with `pre_frame`, `post_frame`, `changed=...`, `issues=...`, and both
    `before_stat_ram` / `after_stat_ram`
  - this should tell us whether the next corruption is written by the NES frame
    advance itself before the next Lua tick sees it
  - FCEUX needs a manual Lua reload before this boundary sentinel is live

## 2026-05-30 Skeleton frameadvance-boundary stat corruption

- User triggered another corrupted B2 fight after reloading the frame-boundary
  sentinel.
- The new sentinel caught the exact emulator-frame boundary:
  - frame `13342`: `PLAYER_STAT_FRAMEADVANCE_TRANSITION from=clean to=bad`
    logged before the normal per-tick transition line
  - `pre_frame=13342`, `post_frame=13343`, state still `field`, map `0x19`,
    position `(11,2)`
  - before: `HP 43/63`, `MP 42/52`, level `12`,
    `stat_ram BA-CF=FF 11 EE 0F B5 03 02 45 C3 00 00 2B 2A 0C 30 24 3F 34 44 30 3F 10`
  - after: `HP 43/15`, `MP 42/0`, level still `12`,
    `stat_ram BA-CF=FF 11 EE 0F B5 03 02 45 C3 00 00 2B 2A 0C 04 03 0F 00 18 1F 00 10`
  - changed bytes were again exactly `C8,C9,CA,CB,CC,CD,CE`
- Follow-up timing:
  - frame `13343`: normal `PLAYER_STAT_INTEGRITY_TRANSITION from=clean to=bad`
    repeated the same corrupted profile
  - frame `13393`: battle start fired 50 frames after the frameadvance flip
  - frame `13457`: enemy dialogue identified the fight as Skeleton
  - frame `13532`: Skeleton first-strike text appeared
  - frame `27895`: victory text logged `defeating the Skeleton. Thy Experience
    increases by 11. Thy GOLD increases by 27.`
  - frame `27899`: `PLAYER_STAT_FRAMEADVANCE_TRANSITION from=bad to=clean`
    restored the same `C8..CE` range across `FCEU.frameadvance()`
  - frame `27900`: normal integrity transition confirmed clean stats again
  - frame `35220`: current `log_state` in field confirmed `HP 31/63`,
    `MP 42/52`, level `12`, `STR=0x30`, `AGI=0x24`, `ATK=0x44`,
    `DEF=0x30`, `spells CE=0x3F`, and clean
    `stat_ram BA-CF=0A 12 09 10 B5 03 02 45 C3 00 00 1F 2A 0C 30 24 3F 34 44 30 3F 10`
- Practical read:
  - this confirms the corruption is written during `FCEU.frameadvance()` /
    NES-side frame execution before Lua sees the next tick
  - the same engine path restores the stat bytes on victory, so this is not
    persistent stat-RAM damage when the fight is won
  - enemy identity/dialogue/first-strike text are again too late to be causal
  - the bad profile still looks like level-1 base stats plus equipment-derived
    attack/defense while the actual level/current HP/current MP bytes remain
    coherent
  - the strongest current mod-side suspect is movement-state normalization:
    this repro logged `AUTO_STEP_MOVEMENT_STATE_RESET
    reason=queued_route_final_complete` at frame `13334`, then the bad stat
    write at frame `13342`; this does not prove causality, but it is a better
    next A/B target than assuming a corrupt ROM
  - recommended next experiment: set
    `auto_step_reset_movement_on_route_turn_settle=false`, reload config, keep
    the frame-boundary sentinel active, and repeat route/combat testing
- Config-false follow-up after user reload:
  - user reported they had already run `reload_config`, manually reloaded the
    FCEUX Lua script, and taken another B2 pass
  - fresh log on that pass showed no new
    `PLAYER_STAT_FRAMEADVANCE_TRANSITION`,
    `PLAYER_STAT_INTEGRITY_TRANSITION`, or
    `PLAYER_STAT_INTEGRITY_WARNING` lines across the latest Wolf/Metal
    Scorpion encounters
  - the same pass still logged `AUTO_STEP_MOVEMENT_STATE_RESET` on
    `queued_route_final_complete`, so the toggle was not fully respected
  - source audit found the bug: turn-settle resets were gated by
    `auto_step_reset_movement_on_route_turn_settle`, but final-settle
    activation and the final queued-route completion reset bypassed that gate
  - added regression test
    `queued_route_final_settle_skips_movement_reset_when_disabled`, watched it
    fail red, patched `auto_step.lua`, then re-ran
    `lua5.1 test_auto_step.lua`, `luac5.1 -p auto_step.lua test_auto_step.lua`,
    and `git diff --check -- auto_step.lua test_auto_step.lua` clean
  - next live step: manual FCEUX Lua reload, then repeat the same B2 route /
    combat pass with the config still `false`
- Live validation after the manual FCEUX reload:
  - exact search for `PLAYER_STAT_` and queued-route movement-reset reasons was
    empty in the reloaded run
  - the run included five clean battle starts/victories: Skeleton at frame
    `05657`, Metal Scorpion at `07368`, Metal Scorpion at `09980`, Skeleton at
    `11139`, and Wolf at `13243`
  - every battle-start state snapshot kept clean level-12 stats/spells
    (`STR=0x30`, `AGI=0x24`, `ATK=0x44`, `DEF=0x30`, `CE=0x3F`)
  - all movement-state reset logs in this run are `reason=seam_retry_complete`;
    none are `queued_route_final_complete`, `queued_route_final_settle`, or
    `queued_route_turn_settle`
  - read-only probe after the Wolf victory: `POSITION map=0x19 x=1 y=11`,
    `HP 40/63`, `MP 26/52`, clean stat block
    `BA-CF=C5 12 EB 11 B5 03 02 45 C3 00 00 28 1A 0C 30 24 3F 34 44 30 3F 10`,
    `PATH_STATE target=Southwest Stairs Down to B3 x=1 y=10`, and
    `RUNTIME_BLOCKS map=0x19 none`
  - interpretation: the final-settle patch is live and behaving as intended;
    the last Wolf interrupted the route one tile south of the stairs, which is
    normal battle interruption rather than corruption
- Runtime overlay note:
  - route noise was partly explained by a missing B2 live overlay
  - `report_runtime_blocks` during the corrupted Skeleton battle showed
    `RUNTIME_BLOCKS map=0x19 none`
  - re-applied the nine confirmed B2 runtime edges in-battle; readback at frame
    `17880` confirmed `RUNTIME_BLOCKS map=0x19 count=9`

## 2026-05-30 B2 upstairs autowalk bounce follow-up

- User reported another noisy B2 autowalk pass toward the upstairs route. The
  fresh log tail showed the same three recurring route suspects dominating the
  reroutes:
  - `(2,8).west` from `(1,8)->RIGHT`
  - `(1,9).north` from `(1,8)->DOWN`
  - `(1,2).south` from `(1,3)->UP`
- Route-tail evidence alone looked strong:
  - `(2,8).west` climbed to `blocked=31 moved=0`
  - `(1,9).north` climbed to `blocked=16 moved=0`
  - `(1,2).south` climbed to `blocked=20 moved=0`
  - nearby cells such as `(1,5).south`, `(1,8).north`, `(1,4).south`, and
    `(1,5).north` stayed noisy/moved and do not meet any promotion threshold
- Live state check after the pass:
  - `report_position` showed B2 `(0,8)`
  - `report_runtime_blocks` showed `RUNTIME_BLOCKS map=0x19 none`, so the
    current FCEUX Lua session was not carrying the previously confirmed B2
    overlay anymore
- Direct verifier follow-up:
  - `probe_edge_verify:1,8,RIGHT,5` for `(2,8).west` ended
    `classification=mixed` with `moved=1 blocked=4`
  - `probe_edge_verify:1,8,DOWN,5` for `(1,9).north` ended
    `classification=mixed` with `moved=5 blocked=1` after the stability
    recheck added a sixth attempt
  - `probe_edge_verify:1,3,UP,5` for `(1,2).south` ended
    `classification=mixed` with `moved=5 blocked=1` after the stability
    recheck added a sixth attempt
- Practical read:
  - this pass produced ugly autowalk looping, but not clean new permanent map
    evidence
  - do not promote `(2,8).west`, `(1,9).north`, or `(1,2).south` into
    `map_reader.lua` from this batch
  - the strongest immediate cleanup was just restoring the already-confirmed B2
    runtime overlay for the current live session
- Live runtime outcome:
  - re-applied the nine confirmed B2 runtime blockers:
    `(2,3).west`, `(2,4).west`, `(2,5).west`, `(2,6).west`, `(2,7).west`,
    `(4,9).south`, `(9,9).south`, `(10,9).south`, and `(12,9).south`
  - readback at frame `28860` confirmed `RUNTIME_BLOCKS map=0x19 count=9`

## 2026-05-30 B2 out-and-back cleanup after corruption A/B

- User made another B2 run out and back after the clean corruption test and
  asked for blocker cleanup from the fresh route evidence.
- Strongest recurring route candidates from the log:
  - east-approach strip: `(12,9).east`, `(12,7).east`, `(12,5).east`
  - top-right hook: `(11,3).north`, `(10,2).east`, `(10,1).east`
- Direct verifier results:
  - `probe_edge_verify:13,9,LEFT,5` => mixed (`moved=1 blocked=4`), keep
    `(12,9).east` unmodeled
  - `probe_edge_verify:13,7,LEFT,5` => confirmed blocked `5/5`, promote
    `(12,7).east`
  - `probe_edge_verify:13,5,LEFT,5` => confirmed blocked `5/5`, promote
    `(12,5).east`
  - `probe_edge_verify:11,2,DOWN,5` => confirmed passable with stability
    recheck (`moved=6 blocked=0`), keep `(11,3).north` open
  - `probe_edge_verify:11,2,LEFT,5` => confirmed passable with stability
    recheck (`moved=6 blocked=0`), keep `(10,2).east` open
  - `probe_edge_verify:11,1,LEFT,5` => confirmed passable with stability
    recheck (`moved=6 blocked=0`), keep `(10,1).east` open
  - `probe_edge_verify:13,4,LEFT,5` => mixed (`moved=1 blocked=4`), keep
    `(12,4).east` unmodeled
- Source/live outcome:
  - promoted `(12,5).east` and `(12,7).east` into `MAP_DIRECTIONAL_BLOCKS[0x19]`
  - extended `test_map_reader.lua` to cover the two new blockers and to keep
    the disproved/mixed neighbors open on B2
  - focused verification passed:
    `lua5.1 test_map_reader.lua`,
    `luac5.1 -p map_reader.lua test_map_reader.lua`,
    `git diff --check -- map_reader.lua test_map_reader.lua`
  - mirrored the two blockers into the current live session with
    `add_blocked_edge:13,7,LEFT` and `add_blocked_edge:13,5,LEFT`;
    `report_runtime_blocks` then showed `RUNTIME_BLOCKS map=0x19 count=2`
  - moved the hero back to B2 `(1,11)` after the explicit-origin verifier hops

## 2026-05-30 B2 entrance-to-sw-stairs route derail analysis

- User reported that the latest B2 entrance `(11,2)` to southwest stairs
  `(1,10)` autowalk "went off the rails somewhere" and asked for route
  analysis rather than an immediate patch.
- Clean planner start was still fine:
  - `ROUTE_PLAN_SNAPSHOT ... context=autowalk_initial start=(11,2) ... result=Path: 7 south, 10 west, 1 south path_len=18`
- The run then split into two separate problems:
  - likely real top-pocket geometry candidates: `(3,3).south` and `(4,3).south`
    each hit clean `blocked_only` twice from `(3,4)->UP` and `(4,4)->UP`
    without any nearby bridge-input contamination
  - later route-collapse contamination: repeated
    `INPUT_EXTERNAL_BRIDGE_ACTIVE` bursts overrode queued directions with
    `Right`, `Down`, `Left`, and even `A`, causing drift and menu opens
- Key derail frames from the contaminated phase:
  - `125782`: route drifted from `(5,4)` to `(5,5)` during a stale `Down`
    bridge burst, forcing `AUTO_WALK_DRIFT_REROUTE`
  - `126046`: intended `(6,4)->UP` instead landed at `(7,4)` after repeated
    stale `Right` bridge injections:
    `auto_step clear_route: step landed off direction dir=up from=(6,4) expected=(6,3) current=(7,4)`
  - `126096`: stale `F`/`A` bridge input opened the command menu and killed the
    route entirely
- Interpretation:
  - this pass does suggest missing B2 geometry near row `3`, but the part
    where the route truly went off the rails was input contamination, not a
    clean hidden-wall discovery
  - do not promote `(5,3).south` or `(6,3).south` from this run because the
    later probes on those cells were entangled with bridge overrides and
    seam-retry drift
  - no fresh `PLAYER_STAT_*` corruption markers appeared in the latest route
    tail, and no `AUTO_STEP_MOVEMENT_STATE_RESET reason=queued_route...` lines
    reappeared; the only resets still visible were the intentionally retained
    `reason=seam_retry_complete` path

## 2026-05-30 B2 route slowdown with turn/final settle reset disabled

- User reported that the B2 entrance `(11,2)` to southwest stairs `(1,10)`
  route is now taking a very long time to solve with
  `auto_step_reset_movement_on_route_turn_settle=false`, while no stat
  corruption has reappeared.
- Current read:
  - the settle reset really was helping route execution quality
  - but the current slowness is not just a settle-off tax; the route is also
    repeatedly discovering a still-unmodeled north-approach blocker strip on
    row `9`
- Latest long run evidence from the clean post-reload autowalk starting at
  frame `116951`:
  - planner still starts correctly with the direct `18`-step route from
    `(11,2)` to `(1,10)`
  - the route then accumulates reroutes up through `route_temp_blocks=30`
    before the upper-pocket/input-collapse phase seen in the prior note
- Strong real-geometry candidates from repeated route evidence:
  - `(3,9).north` blocked repeatedly with no moved samples:
    `blocked=8 moved=0`
  - `(4,9).north` blocked repeatedly with no moved samples:
    `blocked=8 moved=0`
  - `(5,9).north` blocked repeatedly with no moved samples:
    `blocked=7 moved=0`
  - `(6,9).north` blocked repeatedly with no moved samples:
    `blocked=5 moved=0`
  - `(7,9).north` blocked repeatedly with no moved samples:
    `blocked=4 moved=0`
- Practical interpretation:
  - the route keeps trying to descend from row `8` into the row-`9` strip from
    the north side and paying the same seam-retry/reroute tax over and over
  - this is separate from the settle-off drift problem; even a perfect turn
    handoff would still waste time on these missing blockers
  - the already-modeled south-approach row-9 blockers at `(4,9)`, `(9,9)`,
    `(10,9)`, and `(12,9)` were not enough to stop the planner from probing
    this north-side trap band
- Settle-off execution tax still present in the same route family:
  - no `queued_route` movement-state resets are firing now, only
    `seam_retry_complete`
  - route-settle drift/catch-up still shows up in the latest route family, so
    disabling the reset likely increases route churn even when it is not the
    only problem
- Corruption watch:
  - no fresh `PLAYER_STAT_*` or integrity warning lines showed up in the latest
    route/battle tail around the long run

## 2026-05-30 B2 row-9 north strip verifier cleanup

- User asked to directly check the strongest row-9 north-side suspects and
  patch them if they held up.
- Baseline before probing:
  - live field state at `POSITION: map=0x19(Garin's Grave B2) x=6 y=8`
  - `RUNTIME_BLOCKS map=0x19 none`
  - queued target still `Southwest Stairs Down to B3` at `(1,10)`
- Direct verifier results all came back clean `5/5` blocked:
  - `probe_edge_verify:3,8,DOWN,5` => `(3,9).north` confirmed blocked
  - `probe_edge_verify:4,8,DOWN,5` => `(4,9).north` confirmed blocked
  - `probe_edge_verify:5,8,DOWN,5` => `(5,9).north` confirmed blocked
  - `probe_edge_verify:6,8,DOWN,5` => `(6,9).north` confirmed blocked
  - `probe_edge_verify:7,8,DOWN,5` => `(7,9).north` confirmed blocked
- Verifier nuance:
  - each attempt logged `reason=raw_hold_timeout` and
    `mismatch=blocked_despite_open_preview`, which means the ROM/tile decoder
    still thinks the cells are walkable floor even though the engine blocks the
    move cleanly from the north
  - no drift, map change, interrupt, or moved samples appeared on any of the
    five verifiers
- TDD / source outcome:
  - added failing assertions first in `test_map_reader.lua` for the five new
    north approaches; `lua5.1 test_map_reader.lua` failed first on
    `(3,9).north`
  - promoted the strip into `MAP_DIRECTIONAL_BLOCKS[0x19]`:
    `(3,9).north`, `(4,9).north`, `(5,9).north`, `(6,9).north`,
    `(7,9).north`
  - kept the existing south-approach blockers on `(3,9)` and `(4,9)` intact
- Verification:
  - `lua5.1 test_map_reader.lua` passed after the patch
  - `luac5.1 -p map_reader.lua test_map_reader.lua` passed
  - `git diff --check -- map_reader.lua test_map_reader.lua` passed
- Live runtime outcome:
  - mirrored the five confirmed blockers with
    `add_blocked_edge:3,8,DOWN` through `add_blocked_edge:7,8,DOWN`
  - readback showed `RUNTIME_BLOCKS map=0x19 count=5`
  - moved the hero back to the B2 entrance stairs at `(11,2)` after verifier
    hops; current `PATH_STATE` still targets the southwest stairs with
    `runtime_count=5`

## 2026-05-30 post-strip review after cleaner B2 route

- User reported the entrance-to-southwest-stairs route felt much better after
  the row-9 north-strip patch and also noted that combat corruption still had
  not reappeared.
- Log review confirmed the improvement:
  - the next `B2 (11,2) -> (1,10)` route still started with the same direct
    18-step plan, but now only climbed to `route_temp_blocks=5` before the
    Wolf interruption instead of the earlier 20-30+ blocker spiral
  - after the Wolf fight, the resumed route from `(2,11)` re-planned to the
    target in just two steps and then finished at `(1,10)`
- Corruption watch stayed clean:
  - no fresh `PLAYER_STAT_*`, integrity-warning, or frameadvance-transition
    lines appeared around the latest B2 Wolf fight
- Follow-up direct verifier checks on the two strongest remaining route-log
  suspects did not earn promotion:
  - `probe_edge_verify:12,2,DOWN,5` for `(12,3).north` => mixed
    (`moved=1 blocked=4`), so keep it unmodeled
  - `probe_edge_verify:2,11,UP,5` for `(2,10).south` => mixed
    (`moved=2 blocked=3`), so keep it unmodeled
- Practical read:
  - the row-9 north strip was the high-value cleanup
  - the remaining trouble seen in the latest route is mostly noisy/mixed again,
    not another clean permanent blocker batch

## 2026-05-30 B3 southwest-pocket route check from `(2,17)`

- User descended the corrected B2 southwest stair and pushed into
  `map=0x1A(Garin's Grave B3)`, then set autowalk toward the B4 stairs.
- Important route-state clarification from the live log:
  - the active queued target during the noisy run was
    `PATH_STATE target=Lower Stairs Down to B4 x=10 y=9 map=0x1A`
  - current safe read after the Wolflord fight was
    `POSITION: map=0x1A(Garin's Grave B3) x=2 y=12`
  - `RUNTIME_BLOCKS map=0x1A none` before the verifier pass
- Route-noise read:
  - part of the post-fight chaos was stale FCEUX bridge/menu input, not just
    geometry; the field log repeatedly reopened the command/SPELL menu after
    combat while the target remained `(10,9)`
  - no fresh `PLAYER_STAT_*` corruption markers appeared around the Wolflord
    fight or the follow-up field recovery
- Direct B3 verifier results from the southwest pocket:
  - clean promotions:
    - `probe_edge_verify:2,12,LEFT,5` => `(1,12).east` confirmed blocked
      `5/5`
    - `probe_edge_verify:2,13,LEFT,5` => `(1,13).east` confirmed blocked
      `5/5`
  - mixed / do not promote:
    - `probe_edge_verify:3,14,UP,5` => `(3,13).south` mixed
      `moved=5 blocked=1`
    - `probe_edge_verify:3,15,LEFT,5` => `(2,15).east` mixed
      `moved=1 blocked=4`
    - `probe_edge_verify:4,15,RIGHT,5` => `(5,15).west` mixed
      `moved=1 blocked=4`
- Source/runtime follow-up:
  - added a new `MAP_DIRECTIONAL_BLOCKS[0x1A]` block in `map_reader.lua` with
    only `(1,12).east` and `(1,13).east`
  - mirrored the same seams live with `add_blocked_edge:2,12,LEFT` and
    `add_blocked_edge:2,13,LEFT`
  - live readback after the injection showed
    `RUNTIME_BLOCKS map=0x1A count=2`
- Stair-chain follow-up:
  - user later validated the B4 transfer explicitly:
    - B3 lower stair `(10,9)` -> B4 `(5,4)`
    - teleport to the other B4 stair and return -> B3 `(9,5)`
  - fresh live readback after that check showed
    `POSITION: map=0x1A(Garin's Grave B3) x=9 y=5`
  - practical conclusion: the lower B3 stair branch is the correct route into
    the Silver Harp side, not a dead-end side path

## 2026-05-30 B3 lower-stair approach follow-up from `(7,13)` / `(9,13)`

- After the user resumed from combat recovery, the live field state read
  `POSITION: map=0x1A(Garin's Grave B3) x=7 y=13`,
  `RUNTIME_BLOCKS map=0x1A count=3`, and `PATH_STATE target=nil`.
- Clean direct verifier promotions:
  - `probe_edge_verify:8,13,UP,5` => `(8,12).south` confirmed blocked `5/5`
  - `probe_edge_verify:9,13,UP,5` => `(9,12).south` confirmed blocked `5/5`
- Mixed / keep unmodeled for now:
  - `probe_edge_verify:9,13,RIGHT,5` => `(10,13).west` mixed
    `moved=1 blocked=4`
- Live/runtime follow-up:
  - mirrored `(8,12).south` and `(9,12).south` immediately with
    `add_blocked_edge:8,13,UP` and `add_blocked_edge:9,13,UP`
  - after the second injection, live readback showed
    `POSITION: map=0x1A(Garin's Grave B3) x=9 y=13` and
    `RUNTIME_BLOCKS map=0x1A count=5`
  - `debug_pathfind_to:10,9` then improved to
    `Path: 1 east, 4 north`
- Route-shape read after the two north-lip promotions:
  - the direct lane into the lower B4 stair still collapses immediately on a
    west-facing strip along `x=10`
  - repeated blocked-only evidence now stands at:
    - `(10,13).west` => route log climbed to `blocked=8 moved=0`
    - `(10,14).west` => route log climbed to `blocked=6 moved=0`
    - `(10,15).west` => route log climbed to `blocked=6 moved=0`
  - these are now the best next direct-verifier targets after combat clears
- Interruption point:
  - a Specter battle started during the next autowalk and the explicit stop
    landed in battle state
  - last live readback before pausing the queue was
    `POSITION: map=0x1A(Garin's Grave B3) x=9 y=17`
  - no fresh `PLAYER_STAT_*` corruption markers appeared around this battle;
    the noisy input remains the usual stale FCEUX bridge/menu churn

## 2026-05-30 B3 upper-left pocket retry from `(2,8)` toward lower B4 stair `(10,9)`

- Fresh baseline after the Drollmagi field/menu cleanup:
  - `POSITION: map=0x1A(Garin's Grave B3) x=2 y=8`
  - `PATH_STATE target=Lower Stairs Down to B4 type=stair x=10 y=9 map=0x1A`
  - `RUNTIME_BLOCKS map=0x1A count=18`
- Live route read before the fight:
  - autowalk from `(2,9)` repeatedly collapsed around the west edge of the
    upper-left pocket rather than near the already-modeled `(10,13..17).west`
    strip
  - strongest repeated blocked-only cells were:
    - `(2,8)->UP` into `(2,7)` => candidate `(2,7).south`
    - `(2,8)->LEFT` into `(1,8)` => candidate `(1,8).east`
    - `(2,9)->LEFT` into `(1,9)` => candidate `(1,9).east`
    - `(2,10)->RIGHT` into `(3,10)` => candidate `(3,10).west`
    - `(2,11)->RIGHT` into `(3,11)` => candidate `(3,11).west`
  - noisy south checks such as `(2,9)->DOWN` into `(2,10)` and
    `(2,10)->DOWN` into `(2,11)` still moved on seam retry follow-up and
    should remain unmodeled
- Combat/field notes:
  - a Drollmagi fight interrupted the run; battle speech correctly reported
    `Bill's spell is blocked` and no fresh `PLAYER_STAT_*` corruption markers
    appeared
  - post-fight field recovery again showed the usual stale FCEUX bridge/menu
    churn, including a stray field `HEAL` cast, so the direct verifier pass
    waited for a stable baseline first
- Direct verifier results:
  - `probe_edge_verify:2,8,UP,5` => `(2,7).south` confirmed blocked `5/5`
  - `probe_edge_verify:2,8,LEFT,5` => `(1,8).east` confirmed blocked `5/5`
  - `probe_edge_verify:2,9,LEFT,5` => `(1,9).east` confirmed blocked `5/5`
  - `probe_edge_verify:2,10,RIGHT,5` => `(3,10).west` confirmed blocked `5/5`
  - `probe_edge_verify:2,11,RIGHT,5` => `(3,11).west` confirmed blocked `5/5`
  - all five verifiers logged `blocked_model_mismatch=5`, so the permanent
    model was still treating those edges as open before promotion
- Runtime cleanup / follow-up:
  - a later long route plus stop-and-readback exposed that the live overlay was
    still carrying the old runtime-only `(3,13).south` edge even though source
    left it unmodeled
  - cleared the whole B3 runtime overlay and rebuilt it from the confirmed
    source-backed seam set; live readback dropped from
    `RUNTIME_BLOCKS map=0x1A count=23` to `count=22`
  - post-cleanup rechecks:
    - `probe_edge_verify:3,14,UP,5` => `(3,13).south` confirmed passable on
      stability recheck `moved=6 blocked=0`; keep it unmodeled
    - `probe_edge_verify:9,17,DOWN,5` => `(9,18).north` also confirmed
      passable on stability recheck `moved=6 blocked=0`; keep it unmodeled
    - `probe_edge_verify:9,15,LEFT,5` => `(8,15).east` confirmed blocked `5/5`
    - `probe_edge_verify:9,16,LEFT,5` => `(8,16).east` confirmed blocked `5/5`
    - after those promotions were mirrored live, the next reroute still
      repeatedly failed on `(2,12)->RIGHT`; direct `probe_edge_verify:2,12,RIGHT,5`
      then confirmed `(3,12).west` blocked `5/5`

## 2026-05-30 B3 refreshed resume at `(3,16)`

- After the user refreshed the hero and resumed in Garin's Grave B3, the live
  baseline read:
  - `POSITION: map=0x1A(Garin's Grave B3) x=3 y=16`
  - `PATH_STATE target=Lower Stairs Down to B4 type=stair x=10 y=9 map=0x1A`
  - `RUNTIME_BLOCKS map=0x1A none`
- The user reported that the planner wanted to go east from `(3,16)` but the
  live engine blocked that step.
- Direct verifier result:
  - `probe_edge_verify:3,16,RIGHT,5` => `(4,16).west` confirmed blocked `5/5`
  - verifier summary was clean `moved=0 blocked=5` with
    `blocked_model_mismatch=5`, so the current permanent model was still
    treating that entry as open before promotion
- Follow-up route push from `(1,10)` with only the refreshed `(4,16).west`
  runtime edge active reached the upper pocket and exposed a new family of
  west-entry candidates around `(3,7)`, `(3,6)`, `(3,5)`, and `(5,4)`.
  Immediate follow-up verifier result:
  - `probe_edge_verify:4,4,RIGHT,5` => `(5,4).west` confirmed blocked `5/5`
  - `probe_edge_verify:2,7,RIGHT,5` => `(3,7).west` confirmed blocked `5/5`
  - `probe_edge_verify:2,6,RIGHT,5` => `(3,6).west` confirmed blocked `5/5`
  - `probe_edge_verify:2,5,RIGHT,5` => `(3,5).west` confirmed blocked `5/5`
  - deeper recheck after the band promotion:
    - `probe_edge_verify:4,4,DOWN,5` => `(4,5).north` confirmed blocked `5/5`
    - `probe_edge_verify:4,3,RIGHT,5` => `(5,3).west` confirmed blocked `5/5`
