# Current Investigation Scratchpad

Updated: 2026-06-07

## 2026-06-07 Garin's Grave B3 top-edge false boundary to west chest

- User finding:
  - a real false blocker was found on B3 at `10,0 west`; clearing it reopens
    the route to the west chest / likely Cursed Belt.
- Supporting log evidence:
  - from `(10,0)`, `debug_pathfind_to:1,1` returned `No path found`.
  - from `(9,0)`, `debug_pathfind_to:1,1` returned `Path: 1 south, 8 west`.
  - live movement moved `(9,0)->RIGHT` into `(10,0)` twice.
  - live movement moved `(10,0)->LEFT` back into `(9,0)` once.
- Root cause:
  - this was a false top-edge boundary from the generic dungeon walkability
    rule, not a `MAP_DIRECTIONAL_BLOCKS` directional seam.
  - B3 needed scoped passthrough overrides for `(9,0)` and `(10,0)`.
- Permanent sync:
  - `map_reader.lua` adds B3 passthrough cells `(9,0)` and `(10,0)`.
  - `test_map_reader.lua` verifies both cells report `reason="passthrough"`
    and that pathfinding from `(10,0)` to the west chest `(1,1)` succeeds.
  - `lua5.1 test_map_reader.lua` passed 49 tests after the patch.
  - `luac5.1 -p map_reader.lua test_map_reader.lua` passed.
  - `git diff --check -- map_reader.lua test_map_reader.lua` passed.
- Follow-up:
  - after manual FCEUX Lua reload, recheck `debug_pathfind_to:1,1` from the
    NW/top-row side and refresh the reachable-object filter.

## 2026-06-07 Garin's Grave B3 west chest / likely Cursed Belt check from SE side

- Goal:
  - from the B3 southeast/lower component, test whether the west chest at
    `(1,1)` is reachable through a hidden bridge or missing seam.
- Clean blockers promoted:
  - `(6,19)->UP` blocked into `(6,18)` with same-origin `probe_edge:UP`;
    promoted as `(6,18).south`.
  - `(8,19)->UP` blocked into `(8,18)` with same-origin `probe_edge:UP`;
    promoted as `(8,18).south`.
- Broad live confirmation:
  - `debug_route_frontier:1,1,60` from the southeast side reported
    `target_reachable=false` and `hidden_bridge_candidates=0`.
  - final `debug_pathfind_to:1,1` from `(14,15)` returned
    `No path found [no_path] (visited=98 path=0)`.
  - runtime overlay at that final check contained only `(6,18).south` and
    `(8,18).south`.
- Reverified model-consistent directional cuts:
  - bottom/low rows: `(12,19)->UP`, `(13,19)->UP`, `(14,19)->UP`,
    `(15,18)->LEFT`, `(15,16)->LEFT`, `(11..14,17)->UP/DOWN` as applicable.
  - mid band: `(12..14,13)->UP`, `(15,13)->UP`, `(16,12)->LEFT`,
    `(15,11)->LEFT/DOWN`, `(11,13)->UP/LEFT`, `(11,14)->LEFT`,
    `(11,15)->LEFT/DOWN`, and `(12..14,15)->DOWN`.
- Route-only/no-promote notes:
  - the long walk toward `(15,11)` exposed temporary route-only suspected
    blocks around `(17,12)`, `(17,13)`, `(16,14..18)`, `(18,9)`,
    `(18,10)`, and `(18,14)`.
  - treat those as reroute noise unless a future same-origin probe confirms
    them from normal walking state.
- Permanent sync:
  - `map_reader.lua` and `test_map_reader.lua` now include B3
    `(6,18).south` and `(8,18).south`.
  - red `lua5.1 test_map_reader.lua` failed first on missing
    `B3 (6,18).south`.
  - green `lua5.1 test_map_reader.lua` passed 49 tests.
  - `luac5.1 -p map_reader.lua test_map_reader.lua` passed.
  - `git diff --check -- map_reader.lua test_map_reader.lua` passed.

## 2026-06-07 Garin's Grave B3 Southeast Stairs Up pocket cleanup

- Goal:
  - from the B3 `Southeast Stairs Up` landing, close false object routes,
    especially the false route back to the Silver Harp chest at `(13,6)`.
- Method:
  - followed live `auto_walk:13,6` reroutes, paused for battles, and promoted
    only normally reached same-origin `probe_edge` blockers.
  - did not use teleport or explicit-origin verifier output as proof.
- Important passable evidence:
  - `(14,19)->RIGHT` moved to `(15,19)` after a battle-interrupted route
    retry, so that east/west bottom-row seam stayed open.
  - `(15,19)->UP` moved to `(15,18)`, so the y=18 barrier is section-limited.
  - bottom-row lateral movement through `(1..15,19)` repeatedly moved; the
    promoted blockers are the north/up approaches from that row, not the row
    itself.
- Confirmed blockers added during the final pass:
  - `(15,18)->LEFT` -> `(14,18).east`
  - `(13,15)->DOWN` -> `(13,16).north`
  - bottom-row direct probes: `(1,19)->UP`, `(2,19)->UP`, `(3,19)->UP`,
    `(4,19)->UP`, `(5,19)->UP`, `(9,19)->UP`, and `(12,19)->UP`, modeled as
    `(1,18).south`, `(2,18).south`, `(3,18).south`, `(4,18).south`,
    `(5,18).south`, `(9,18).south`, and `(12,18).south`.
- Permanent sync:
  - `map_reader.lua` now models the full confirmed SE-stair runtime overlay
    accumulated during this pass, including the southeast rows 12-18 and the
    bottom-row north/up blockers.
  - `test_map_reader.lua` adds
    `garins_grave_b3_southeast_stair_pocket_seams_are_directional`.
- Verification:
  - red `lua5.1 test_map_reader.lua` failed first on missing
    `B3 (17,3).south`.
  - green `lua5.1 test_map_reader.lua` passed 49 tests.
  - `luac5.1 -p map_reader.lua test_map_reader.lua` passed.
  - `git diff --check -- map_reader.lua test_map_reader.lua` passed.
- Final live status before source reload:
  - after runtime injections, `auto_walk:13,6` from `(12,19)` returned
    `No path found`.
  - later combat/repositioning left the hero at approximately `(10,19)` on B3
    with runtime count 51; FCEUX still needs a manual Lua reload before the
    permanent model replaces the runtime overlay.

## 2026-06-07 Garin's Grave B3 Northeast Stairs Up pocket cleanup

- Goal:
  - from B2 `Northeast Stairs Down` arrival on B3 `(18,1)`, prune false
    reachable objects in the same style as the lower-stair crowded zone.
- Starting live baseline:
  - `POSITION map=0x1A(Garin's Grave B3) x=18 y=1`
  - `RUNTIME_BLOCKS map=0x1A none`
  - reachable filter showed 9 objects:
    `Northeast Stairs Up`, `Northwest Stairs Up`, Silver Harp chest `(13,6)`,
    `Southeast Stairs Up`, `Upper Stairs Down`, `Lower Stairs Down`,
    west chest `(1,1)`, `Central Stairs Up`, and `Southwest Stairs Up`.
  - idle controller check showed `joy1=-`; only the known benign FCEUX
    `LeftAlt` latch was present.
- Confirmed live blockers:
  - `(17,1)->LEFT` blocked under route retry, then same-origin
    `probe_edge:LEFT` blocked with `raw_hold_timeout`; model `(16,1).east`.
  - `(17,2)->LEFT` was first interrupted by a Drollmagi battle, then retried
    after combat from the same tile and blocked with `raw_hold_timeout`;
    model `(16,2).east`.
  - `(17,2)->DOWN` blocked with `raw_hold_timeout`; model `(17,3).north`.
  - `(18,2)->DOWN` blocked with `raw_hold_timeout`; model `(18,3).north`.
  - `(19,2)->DOWN` blocked with `raw_hold_timeout`; model `(19,3).north`.
- Final live status:
  - runtime overlay had five B3 edges:
    `(16,1).east`, `(16,2).east`, `(17,3).north`, `(18,3).north`,
    `(19,3).north`.
  - `debug_pathfind_to:14,1` returned `No path found`.
  - reachable filter dropped to 1 object:
    `Northeast Stairs Up: 1 north, 1 west`.
- Permanent sync:
  - `map_reader.lua` models the confirmed NE-pocket seams.
  - `test_map_reader.lua` adds focused B3 assertions for the five promoted
    edges.

## 2026-06-06 Garin's Grave B3 lower-stair object-pruning pass

- Goal:
  - from the lower-stair / Silver Harp side of B3, close false reachable
    object routes without using teleport or verifier evidence as proof.
- Starting live baseline:
  - `POSITION map=0x1A(Garin's Grave B3) x=13 y=6`
  - reachable object filter showed 9 objects from the harp chest area,
    including top-side stairs and far chest objects that should not be
    reachable from this component.
  - active B3 runtime blocks at start: `(10,7).south`, `(13,9).north`.
- Method:
  - followed planner reroutes manually with same-origin `probe_edge` checks.
  - promoted only repeated same-origin blocked probes with no teleport-backed
    proof.
  - battle interruptions were treated as contamination; the interrupted
    `(12,8)->DOWN` probe was retried from field state after combat.
- New B3 directional blockers promoted from this object-pruning pass:
  - `(12,3).south`, `(13,3).south`, `(14,3).south`
  - `(11,4).east`, `(11,4).south`
  - `(15,4).west`, `(15,4).south`
  - `(10,5).east`, `(16,5).west`, `(16,6).west`, `(16,7).west`
  - `(10,7).east`
  - `(9,8).east`, `(15,8).north`, `(15,8).west`
  - `(9,9).east`, `(12,9).north`, `(12,9).west`, `(14,9).north`
  - `(10,10).north`, `(11,10).north`
- Final live status before reload:
  - `POSITION map=0x1A x=10 y=9`
  - reachable object filter dropped to 2 objects:
    `Lower Stairs Down: here` and `Chest: 3 north, 3 east` at `(13,6)`.
  - `debug_pathfind_to:14,1`, `debug_pathfind_to:18,1`,
    `debug_pathfind_to:1,1`, and `debug_pathfind_to:9,5` all returned
    `No path found`.
- Post-reload observation:
  - after source reload / resumed play, the user exercised the local route:
    autowalk reached the chest at `(13,6)`, autowalk returned to
    `Lower Stairs Down` `(10,9)`, and using the stairs changed to B4
    (`map=0x1B`).
  - only timing retries were logged on open seams; no new permanent blockers
    were promoted from that post-reload autowalk.
- User follow-up verification:
  - after script reload, user confirmed the B3 lower-stair side reachable list
    contains only the local chest and stairs.
  - user walked the player through the route a couple of times successfully.
- Fresh Codex verification from the branch entrance:
  - `POSITION map=0x19(Garin's Grave B2) x=1 y=10`
  - `PATHABILITY_FILTER: All, reachable. Southwest Stairs Down: here (1 of 6)`
  - `OBJECT: Southwest Stairs Down: here (1 of 6)`
  - `RUNTIME_BLOCKS map=0x19 none`
- Branch conclusion:
  - the B2 southwest-stairs branch is complete for current mapping/playability
    purposes.
  - no further blocker hunting is needed here unless later route-polish testing
    exposes new noise.
- Permanent sync:
  - `map_reader.lua` models the confirmed B3 lower-side object-pruning seams.
  - `test_map_reader.lua` adds focused assertions for the promoted B3 edges.
- Verification:
  - red `lua5.1 test_map_reader.lua` failed first on missing
    `B3 (10,5).east` for the first batch.
  - red `lua5.1 test_map_reader.lua` failed first on missing
    `B3 (10,7).east` for the second batch.
  - green `lua5.1 test_map_reader.lua` passed 48 tests.
  - `luac5.1 -p map_reader.lua test_map_reader.lua` passed.
  - `git diff --check -- map_reader.lua test_map_reader.lua` passed.
- Next:
  - move on from the B2 southwest branch to the next dungeon branch or main
    progression target.

## 2026-06-06 Garin's Grave B3 lower-stair Silver Harp route

- Goal:
  - from B3 `Lower Stairs Down` `(10,9)`, stabilize the route to the likely
    Silver Harp chest and back without verifier/teleport passability proof.
- Fresh baseline after returning from B4:
  - `POSITION map=0x1A(Garin's Grave B3) x=10 y=9`
  - `OBJECT: Lower Stairs Down: here (1 of 9) [player 10,9 obj 10,9]`
  - `RUNTIME_BLOCKS map=0x1A none`
  - object list showed `Chest` at `(13,6)` and another `Chest` at `(1,1)`.
- Initial planner to `(13,6)`:
  - normal and skip-NPC both gave `Path: 3 north, 3 east`.
- Confirmed live blocker on the forward route:
  - `(10,9)->UP` into `(10,8)` moved.
  - `(10,8)->UP` into `(10,7)` blocked twice with `raw_hold_timeout`.
  - runtime-injected `add_blocked_edge:10,8,UP`, model `(10,7).south`.
- Clean forward route after replan:
  - planner from `(10,8)` to `(13,6)`: `3 east, 2 north`.
  - proved by same-origin `probe_edge`:
    `(10,8)->RIGHT`, `(11,8)->RIGHT`, `(12,8)->RIGHT`,
    `(13,8)->UP`, `(13,7)->UP`.
  - final `POSITION map=0x1A x=13 y=6`.
  - object cycle confirmed `OBJECT: Chest: here (1 of 9)`.
- Chest/inventory result:
  - carefully opened command menu and selected `TAKE` by cursor state:
    `TALK (0,0)` -> `STATUS (0,1)` -> `STAIRS (0,2)` ->
    `SEARCH (0,3)` -> `TAKE (1,3)`.
  - chest dialogue: `Unfortunately, it is empty.`
  - `log_state` item bytes: `C1..C4 = 45 C3 0A 00`; item nybble `0xA` is
    `Silver Harp`, so the hero already has the harp in this save.
  - dismissed dialogue; menu/dialogue state clear afterward.
- Confirmed live blocker on the return route:
  - initial planner from `(13,6)` to `(10,9)`: `3 south, 3 west`.
  - `(13,6)->DOWN` and `(13,7)->DOWN` moved.
  - `(13,8)->DOWN` into `(13,9)` blocked twice with `raw_hold_timeout`.
  - runtime-injected `add_blocked_edge:13,8,DOWN`, model `(13,9).north`.
- Clean return route after replan:
  - planner from `(13,8)` to `(10,9)`: `3 west, 1 south`.
  - proved by same-origin `probe_edge`:
    `(13,8)->LEFT`, `(12,8)->LEFT`, `(11,8)->LEFT`, `(10,8)->DOWN`.
  - final `POSITION map=0x1A x=10 y=9`.
  - runtime blocks at end: `(10,7).south`, `(13,9).north`.
- Permanent sync:
  - `map_reader.lua` now models B3 `(10,7).south` and `(13,9).north`.
  - `test_map_reader.lua` adds focused assertions for both.
- Verification:
  - red `lua5.1 test_map_reader.lua` failed first on missing
    `B3 (10,7).south`.
  - red `lua5.1 test_map_reader.lua` then failed on missing
    `B3 (13,9).north`.
  - green `lua5.1 test_map_reader.lua` passed 48 tests.
  - `luac5.1 -p map_reader.lua test_map_reader.lua` passed.
  - `git diff --check -- map_reader.lua test_map_reader.lua` passed.
- Next:
  - user should manually reload Lua in FCEUX when ready.
  - continue B3 lower-side object/stair exploration or route outward now that
    Silver Harp is confirmed in inventory.

## 2026-06-06 Garin's Grave B4 west/east stair stabilization

- Goal:
  - stabilize routes between `West Stairs Up` `(0,4)` and `East Stairs Up`
    `(5,4)` before continuing toward the Silver Harp.
  - start by checking the suspected blocker at `(1,4)->UP`.
- Teleport was not used as direct passability proof.
- New confirmed live blockers from same-origin `probe_edge` checks and runtime
  injections:
  - `(1,4)->UP` blocked twice; model `(1,3).south`.
  - `(2,5)->DOWN` blocked twice; model `(2,6).north`.
  - `(6,7)->RIGHT` blocked twice; model `(7,7).west`.
  - `(5,4)->LEFT` blocked twice; model `(4,4).east`.
  - `(5,4)->DOWN` blocked twice; model `(5,5).north`.
  - `(5,4)->UP` blocked twice; model `(5,3).south`.
  - `(6,4)->DOWN` blocked twice; model `(6,5).north`.
  - `(6,4)->UP` blocked twice; model `(6,3).south`.
  - `(7,5)->LEFT` blocked twice; model `(6,5).east`.
  - `(7,6)->DOWN` blocked twice; model `(7,7).north`.
  - `(4,7)->LEFT` blocked twice; model `(3,7).east`.
  - `(3,6)->LEFT` blocked twice; model `(2,6).east`.
  - `(2,5)->LEFT` blocked twice; model `(1,5).east`.
  - `(1,4)->DOWN` blocked twice; model `(1,5).north`.
  - `(6,2)->LEFT` blocked twice; model `(5,2).east`.
  - `(4,1)->LEFT` blocked twice; model `(3,1).east`.
  - `(3,2)->LEFT` blocked twice; model `(2,2).east`.
  - `(3,2)->UP` blocked twice; model `(3,1).south`.
- End-to-end route checks:
  - west-to-east `auto_walk:5,4` completed to `East Stairs Up`.
  - east-to-west `auto_walk:0,4` completed to `West Stairs Up`.
  - final live state after return:
    `POSITION map=0x1B(Garin's Grave B4) x=0 y=4`.
- Runtime block snapshot before permanent sync:
  - `(3,1).east/south`
  - `(2,2).east`
  - `(5,2).east`
  - `(1,3).south`
  - `(5,3).south`
  - `(6,3).south`
  - `(4,4).east`
  - `(1,5).east/north`
  - `(5,5).north`
  - `(6,5).east/north`
  - `(2,6).east/north`
  - `(3,7).east`
  - `(7,7).north/west`
- Deliberately unpromoted candidates:
  - `(5,2).west`: appeared during autowalk retry from `(4,2)->RIGHT`, but did
    not receive direct same-origin confirmation.
  - `(7,1).west`: appeared during autowalk reroute evidence only.
  - `(6,3).north`: appeared during autowalk route retry from `(6,2)->DOWN`,
    but direct work later used `(7,2)->DOWN` and the lower route cleanly.
  - `(4,7).north` remains open; earlier direct movement proved
    `(4,6)->DOWN` reaches `(4,7)`.
- Permanent sync:
  - `map_reader.lua` now models the confirmed B4 west/east connector seams.
  - `test_map_reader.lua` expands B4 assertions and keeps absence assertions
    for unpromoted candidates.
- Verification:
  - red `lua5.1 test_map_reader.lua` failed first on missing
    `B4 (1,3).south`.
  - green `lua5.1 test_map_reader.lua` passed 48 tests.
  - `luac5.1 -p map_reader.lua test_map_reader.lua` passed.
  - `git diff --check -- map_reader.lua test_map_reader.lua` passed.
- Next:
  - user should manually reload Lua in FCEUX when ready.
  - after reload, verify B4 route from current `West Stairs Up` to
    `East Stairs Up`, then use the east stairs and verify B3 lower-stair /
    Silver Harp side arrival.

## 2026-06-06 Garin's Grave B4 connector to East Stairs Up

- User took the hero out for an inn rest, then returned to Garin's Grave B4
  around the prior investigation point.
- Live resumed on map `0x1B` from the west-side connector route toward
  `East Stairs Up` `(5,4)`.
- Teleport note:
  - user used teleport only to coarse-drop near the prior work area after the
    inn trip.
  - route evidence was normalized by walking before same-origin probes; do not
    treat teleport as direct seam proof.
- Confirmed live blockers and runtime injections:
  - `(2,4)->RIGHT` blocked twice; model representation `(3,4).west`.
  - `(4,6)->UP` blocked twice; model representation `(4,5).south`.
  - `(4,6)->RIGHT` blocked twice; model representation `(5,6).west`.
  - `(3,5)->UP` blocked twice; model representation `(3,4).south`.
  - `(3,5)->RIGHT` blocked twice; model representation `(4,5).west`.
  - `(3,6)->DOWN` blocked twice; model representation `(3,7).north`.
  - `(5,7)->UP` blocked twice; model representation `(5,6).south`.
  - `(6,6)->UP` blocked twice; model representation `(6,5).south`.
  - `(6,6)->LEFT` blocked twice; model representation `(5,6).east`.
- Disproved/no-promote candidate:
  - `(4,7).north` should stay open; after route replanning, live
    `probe_edge:DOWN` from `(4,6)` moved into `(4,7)`.
- With the runtime blockers active, the final clean route from `(6,6)` was:
  - `(6,6)->RIGHT` to `(7,6)` moved.
  - `(7,6)->UP` to `(7,5)` moved.
  - `(7,5)->UP` to `(7,4)` moved, then a Drollmagi battle started.
  - post-battle route refreshed at `(7,4)` as `2 west`.
  - `(7,4)->LEFT` to `(6,4)` moved.
  - `(6,4)->LEFT` to `(5,4)` moved, then another Drollmagi battle started.
- Final confirmed state after combat:
  - `POSITION: map=0x1B(Garin's Grave B4) x=5 y=4`
  - `OBJECT: East Stairs Up: here (1 of 2) [player 5,4 obj 5,4]`
  - runtime block list: `(3,4).south/west`, `(4,5).south/west`,
    `(5,6).east/south/west`, `(3,7).north`, `(6,5).south`.
- Permanent sync:
  - `map_reader.lua` now includes `MAP_DIRECTIONAL_BLOCKS[0x1B]` for the
    confirmed B4 connector seams.
  - `test_map_reader.lua` adds `assert_garins_grave_b4_dir` and focused B4
    assertions, including a negative assertion for `(4,7).north`.
- Verification:
  - red `lua5.1 test_map_reader.lua` failed first on missing `B4 (3,4).west`
  - green `lua5.1 test_map_reader.lua` passed 48 tests
  - `luac5.1 -p map_reader.lua test_map_reader.lua` passed
  - `git diff --check -- map_reader.lua test_map_reader.lua` passed
- Next:
  - from current live `(5,4)`, user should manually use STAIRS to move to the
    B3 lower-stair/harp side, then we should verify the B3 arrival and continue
    toward the harp route.

## 2026-06-06 Garin's Grave B3 central-stair pocket lockdown

- User clarified they were not back at the southwest B3 stairs; they had been
  trying to work backward from the lower-stair side and find a mismarked
  opening.
- Fresh live baseline:
  - `POSITION map=0x1A(Garin's Grave B3) x=7 y=11`
  - no B3 runtime blocks before this pass
  - nearby route context led into the `Central Stairs Up` pocket around
    `(6,11)`, not the southwest B3 stair landing `(2,17)`.
- Route/autowalk evidence toward `Southwest Stairs Up` exposed two false
  openings:
  - `(7,11)->DOWN` into `(7,12)` repeatedly blocked; seam evidence rose to
    `blocked=5 moved=0`.
  - same-origin `probe_edge:DOWN` from `(7,11)` blocked twice with
    `raw_hold_timeout`.
  - `(6,11)->LEFT` into `(5,11)` repeatedly blocked; seam evidence rose to
    `blocked=5 moved=0`.
  - same-origin `probe_edge:LEFT` from normally reached `(6,11)` blocked twice
    with `raw_hold_timeout`.
- Runtime investigation overlay:
  - injected `add_blocked_edge:7,11,DOWN`, represented as `(7,12).north`
  - injected `add_blocked_edge:6,11,LEFT`, represented as `(5,11).east`
  - with both runtime edges present, planner from `(6,11)` returned
    `No path found` to `(2,17)`, `(10,9)`, `(9,5)`, and the harp chest
    coordinate `(13,6)`.
- Permanent model/test sync:
  - `map_reader.lua` now models B3 `(5,11).east` and `(7,12).north`.
  - `test_map_reader.lua` adds focused B3 assertions for both approaches.
- Route conclusion:
  - Do not try to open this central-stair pocket toward the lower B3 stair; it
    is sealed by live-confirmed blockers.
  - The Silver Harp route remains the counterintuitive stair chain: from B2
    southwest stairs to B3 `(2,17)`, go to `Upper Stairs Down` `(9,5)`, cross
    B4 from `West Stairs Up` `(0,4)` to `East Stairs Up` `(5,4)`, then return
    to the B3 lower-stair side and the harp area.
- Follow-up after source reload:
  - Live `POSITION map=0x1A x=6 y=11`, `current_object` reported
    `Central Stairs Up: here`, and `RUNTIME_BLOCKS map=0x1A none`.
  - Live `debug_pathfind_to:9,5` and skip-NPC variant both returned
    `No path found` from `(6,11)`, which is expected for the sealed central
    return pocket.
  - Offline ROM-backed A* with the current map model still finds the real
    southwest-landing route from `(2,17)` to `Upper Stairs Down` `(9,5)`:
    `2 east, 11 north, 2 east, 2 north, 3 east, 1 south`.
  - Offline ROM-backed A* from `(2,17)` to `Lower Stairs Down` `(10,9)` remains
    `nil`; the route to lower side is through B4, not directly across B3.

## 2026-06-06 Garin's Grave B2 stair-route cleanup

- Live baseline:
  - Reached `Stairs Up` / B2 entrance `(11,2)` by normal walking from
    `Southwest Stairs Down` `(1,10)`.
  - No teleport was used as passability proof in this pass.
  - Latest live readback before patching:
    `POSITION map=0x19 x=11 y=2`, `RUNTIME_BLOCKS count=12`.
- Southwest route status:
  - From `(1,10)` to `(11,2)`, planner gave
    `1 south, 12 east, 9 north, 2 west`.
  - `auto_walk:11,2` completed live.
  - Timing retries at `(1,10)->DOWN`, `(12,11)->RIGHT`, and `(13,3)->UP`
    all moved on retry; do not treat them as blockers.
- Northeast route status:
  - From `(11,2)`, `auto_walk:12,1` completed live via
    `1 north, 1 east`.
  - Return `auto_walk:11,2` completed live via `1 south, 1 west`.
  - Timing retries at `(11,2)->UP` and `(12,1)->DOWN` moved on retry; do not
    treat them as blockers.
- Central route status:
  - From entrance side, `auto_walk:5,6` failed at `(12,2)->DOWN` into
    `(12,3)` with route evidence `blocked=7 moved=0`.
  - Same-origin live probes from normally reached `(12,2)`:
    - `probe_edge:DOWN` blocked with `raw_hold_timeout`.
    - repeat `probe_edge:DOWN` blocked with `raw_hold_timeout`.
  - Runtime-injected `add_blocked_edge:12,2,DOWN`, represented as
    `(12,3).north`.
  - After runtime injection, `debug_pathfind_to:5,6` returned `No path found`.
  - This supersedes the older teleport-backed mixed verifier note for this
    edge only; permanent model/test now promote `(12,3).north`.
- Southeast route status:
  - From `(12,2)`, planner to `(12,10)` gave `1 east, 8 south, 1 west`.
  - `auto_walk:12,10` completed live.
  - Return planner from `(12,10)` to `(11,2)` gave
    `1 east, 8 north, 2 west`.
  - `auto_walk:11,2` completed live.
  - Timing retries at `(12,2)->RIGHT`, `(13,9)->DOWN`,
    `(12,10)->RIGHT`, and `(13,3)->UP` all moved on retry; do not promote.
- Northwest route status:
  - After the live southwest route reached `(1,10)`, `(1,10)->RIGHT` into
    `(2,10)` blocked twice under same-origin `probe_edge:RIGHT`.
  - Runtime-injected `(2,10).west`; this remains state-sensitive and
    unresolved for permanent promotion because a teleport-seeded check moved.
  - From normally reached entrance `(11,2)`, `debug_pathfind_to:1,1` returned
    `No path found`.
- Final B2 entrance-side planner snapshot under the current live runtime seams:
  - `Northeast Stairs Down` `(12,1)`: `1 north, 1 east`
  - `Southeast Stairs Down` `(12,10)`: `2 east, 8 south, 1 west`
  - `Central Stairs Down` `(5,6)`: `No path found`
  - `Northwest Stairs Down` `(1,1)`: `No path found`
  - `Southwest Stairs Down` `(1,10)`: `2 east, 9 south, 12 west, 1 north`

## 2026-06-06 Garin's Grave B2 central-stair verifier artifact

- Context:
  - While route-cleaning from B2 entry-side stair `(11,2)` toward `Central
    Stairs Down` `(5,6)`, `probe_edge_verify:X,Y,DIR,5` repeatedly produced
    a misleading pattern on several B2 seams.
  - Pattern: first explicit-origin verifier attempt moved, later attempts
    blocked with `blocked_despite_open_preview`, and the classifier returned
    `inconclusive_teleport_artifact`.
- Concrete mixed examples, do not promote from these:
  - `(12,2)->DOWN` into `(12,3)`: `moved=4 blocked=1`
  - `(13,4)->LEFT` into `(12,4)`: `moved=1 blocked=4`
  - `(9,8)->LEFT` into `(8,8)`: `moved=1 blocked=4`
  - `(5,10)->UP` into `(5,9)`: `moved=1 blocked=4`
  - `(11,11)->UP` into `(11,10)`: `moved=1 blocked=4`
  - `(10,10)->RIGHT` into `(11,10)`: `moved=2 blocked=3`
- Clean positive control:
  - `(13,6)->LEFT` into `(12,6)` verified `moved=0 blocked=5`,
    `classification=confirmed_blocked`, no teleport-artifact suspicion.
  - Runtime-injected with `add_blocked_edge:13,6,LEFT`, represented as
    `(12,6).east`.
- Working interpretation:
  - The verifier can still be useful as forensic/review material, especially
    when every attempt agrees, but teleport-backed origin setup is not direct
    proof of live route passability on stateful B2 seams.
  - Concrete false-passable warning:
    - after `teleport_to:1,10`, `(1,10)->RIGHT` moved into `(2,10)` even while
      the model/runtime preview treated `(2,10).west` as blocked.
    - after reaching `(1,10)` by normal southwest-stair route movement, the same
      `(1,10)->RIGHT` edge blocked twice with `raw_hold_timeout`.
    - treat this as state-sensitive evidence, not as stable map truth.
  - For B2 seams that show `first_attempt_status=moved` followed by
    `blocked_despite_open_preview`, explicit-origin repeated teleport attempts
    are not equivalent to reaching the seam through normal route movement.
  - Do not use this mixed pattern as blocker proof. Prefer live route evidence,
    same-origin `probe_edge:DIR` from a normally reached edge origin, and
    reverse/alternate route bracketing before permanent map promotion.

## 2026-06-05 Garin's Grave B1 B2 Door north-side route

- User context:
  - User descended into Garin's Grave B1 and selected `B2 Door`.
  - They noted the previous confirmed door approach came from the downward/lower
    side of the maze.
- Live baseline after menu/input noise settled:
  - `POSITION: map=0x18(Garin's Grave B1) x=13 y=15`
  - `PATH_STATE target=B2 Door type=door x=17 y=17 map=0x18 runtime_count=0`
  - `RUNTIME_BLOCKS map=0x18 none`
  - `current_object` in the live FCEUX script still used the old stand:
    `interact 17,18` and `Not currently reachable`.
- Root cause evidence:
  - Direct route to the old lower/south stand `(17,18)` returned `No path found`
    in both normal and skip-NPC modes.
  - Adjacent route to the door cell found the north-side stand `(17,16)`:
    `2 west, 1 north, 2 west, 7 north, 10 east, 9 south, 2 west`, then
    `Face south`.
  - This is an object interaction-side problem, not a new permanent blocker.
- Code patch:
  - `objects.lua` keeps primary `interaction_x/y=(17,18)` facing north and
    adds `interaction_points` with `(17,18)` north plus `(17,16)` south.
  - `route_manager.lua` tries alternate interaction points only after the
    primary interaction route fails, records the selected interaction on the
    plan/reachability result, and passes it into `objects.describe_current`.
  - `objects.lua` readout supports a caller-provided interaction override so
    object speech/debug suffixes describe the selected reachable stand.
- Verification:
  - Red tests failed as expected before code changes:
    `test_objects.lua` had missing `interaction_points`; `test_route_manager.lua`
    got `No path found` instead of the north-side route.
  - Green checks:
    `lua5.1 test_objects.lua`,
    `lua5.1 test_route_manager.lua`,
    `luac5.1 -p objects.lua route_manager.lua test_objects.lua test_route_manager.lua`,
    `git diff --check -- objects.lua route_manager.lua test_objects.lua test_route_manager.lua`,
    and `python3 run_tests.py --allow-missing-speech-dep`.
- Live workaround before FCEUX reload:
  - Live `current_object`/`pathfind` still showed old code after the patch, so
    used coordinate route `auto_walk:17,16`.
  - First route queued 33 steps, rerouted around timing-suspect movement noise,
    then a Droll battle interrupted at `(9,14)`.
  - Resumed `auto_walk:17,16`; it completed to
    `POSITION map=0x18 x=17 y=16`, with `runtime_count=0` and
    `RUNTIME_BLOCKS map=0x18 none`.
  - Do not promote route-only/timing-suspect seams from this workaround pass:
    examples include `(19,12).north`, `(18,13).north`, and `(19,16).north`.
    They were part of timing retry/reroute behavior, and no direct verifier was
    run.
- Immediate next manual action:
  - From `(17,16)`, face south and use `OPEN`.
  - After Lua reload/relaunch, selected `B2 Door` should automatically choose
    the reachable `(17,16)` stand when approached from this component.

## 2026-06-05 Garinham top-edge and object browser follow-up

- Town-edge blocker follow-up:
  - `probe_edge_verify:19,0,LEFT,5` confirmed `(19,0)->LEFT` into `(18,0)`
    blocked 5/5 with no drift, map change, or interruptions. Promoted as
    Garinham `0x09` directional block `(18,0).east`.
  - `probe_edge_verify:18,1,UP,5` did not confirm a blocker. It moved onto
    `(18,0)` and then hit a world-map transition, so `(18,0).south` stays
    open.
- Object browser bug:
  - Reproduced live before the patch:
    `OBJECT: Center Return Stairs to B2 ... [player 19,0 obj 6,11]` while the
    player was in Garinham.
  - Root cause was command-layer browsing using the stale object cache without
    first asking `objects.check_refresh(current_map)` whether the map/terrain
    context changed.
  - `object_commands.lua` now refreshes object cache context before describing
    or browsing. It avoids forced NPC rebuilds while map-entry refresh remains
    pending.
  - Live sanity after patch/settle: `current_object` reported Garinham town
    objects instead of stale grave-floor stairs.
- Final live baseline:
  - `POSITION map=0x09(Garinham) x=0 y=14`
  - `PATH_STATE target=nil map=0x09 runtime_count=0`
  - `RUNTIME_BLOCKS map=0x09 none`
- Verification:
  - `lua5.1 test_map_reader.lua`
  - `lua5.1 test_object_commands.lua`
  - `luac5.1 -p map_reader.lua test_map_reader.lua object_commands.lua test_object_commands.lua`
  - `python3 -m py_compile run_tests.py`
  - `python3 run_tests.py --allow-missing-speech-dep` passed with known
    `accessible_output2` warning
  - `git diff --check -- map_reader.lua test_map_reader.lua object_commands.lua test_object_commands.lua run_tests.py`

## 2026-06-05 Silver Harp route completion

- Live route outcome:
  - Reached Garin's Grave B3 lower section via the B4 chain.
  - Opened the B3 chest at `(13,6)` and confirmed dialogue:
    `Fortune smiles upon thee, Bill. Thou hast found the Silver Harp.`
  - Returned through the B4/B3/B2/B1 stair chain and reached Garinham
    `map=0x09 x=19 y=0`.
  - Final live baseline after stopping a separate Garinham top-edge route loop:
    `POSITION map=0x09(Garinham) x=19 y=0`,
    `PATH_STATE target=nil map=0x09 runtime_count=0`, and
    `RUNTIME_BLOCKS map=0x09 none`.
- Permanent map/data corrections from this pass:
  - B3 `0x1A`: confirmed `(5,13).west`, `(5,4).east`, `(8,6).east`,
    `(10,6).west`, `(9,7).north`, and `(10,6).east`; added hidden bridge
    passthrough `(4,14)` after live entry from `(4,13)->DOWN` moved 6/6 and
    onward movement to `(4,15)` succeeded.
  - B4 `0x1B`: added west return stair passthrough `(0,4)` after
    `(1,4)->LEFT` moved 6/6.
  - B1 `0x18`: confirmed `(5,18).south` and `(6,18).south` from clean
    `(5,19)->UP` / `(6,19)->UP` 5/5 blockers; removed stale
    `(4,17).west` after `(3,17)->RIGHT` moved 6/6 and unlocked the path to the
    B1 return stairs.
- Follow-up caveats:
  - Garinham `auto_walk:18,0` looped around `(19,0)/(19,1)/(18,1)` and
    repeatedly failed entering `(18,0)` from the east/south. Follow-up direct
    verification promoted only `(18,0).east`; `(18,0).south` moved into the
    world-map transition and stays open.
  - Object browsing labels became stale across some map transitions during the
    live run, e.g. B4/B2/B1 object names still referring to B3 stairs. The
    command layer now refreshes object cache context before reporting objects.
  - FCEUX menu/input bridge funk around the B3 southwest stairs caused DOWN
    menu inputs to be treated as field movement; user manually got back to B2.
    Later stair menus on B2/B1 behaved normally.
- Verification after map/test updates:
  - `lua5.1 test_map_reader.lua` => 47/47 pass
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `git diff --check -- map_reader.lua test_map_reader.lua`

## 2026-05-31 Garin's Grave B3 lower-stair dig

- Active target: B3 lower stairs down to B4 at `(10,9)` from southwest-pocket
  chain `B2 (1,10) -> B3 (2,17)`.
- Confirmed runtime blockers restored/promoted during the live FCEUX dig:
  - `(5,2).west`
  - `(6,2).north`
  - `(3,5).north`
  - `(2,7).north`
  - `(3,13).west` from clean direct verifier
    `probe_edge_verify:2,13,RIGHT,5` => blocked 5/5
  - `(4,18).north` from clean direct verifier
    `probe_edge_verify:4,17,DOWN,5` => blocked 5/5
  - `(3,18).north` from clean direct verifier
    `probe_edge_verify:3,17,DOWN,5` => blocked 5/5
- Clean negative verifier worth preserving:
  - `(5,17)->RIGHT` into `(6,17)` moved 6/6, confirmed passable
- Mixed/noisy verifiers, do not promote from these alone:
  - `(8,1)->RIGHT` mixed
  - `(1,6)->DOWN` mixed
  - `(3,14)->UP` into `(3,13)` mixed on direct verifier (`moved=5 blocked=1`)
- Fresh route evidence after restoring the five runtime blockers:
  - Baseline before rerun: `POSITION map=0x1A x=2 y=14`,
    `RUNTIME_BLOCKS count=5`, target still latched to lower B4 stair.
  - `auto_walk:10,9` immediately treated `(3,13).west` as blocked and routed
    through `(3,14)`.
  - `(2,14)->RIGHT` into `(3,14)` looked noisy on first contact but collapsed
    to moved on seam retry; keep open.
  - `(3,14)->UP` into `(3,13)` reappeared as very strong route-only evidence:
    `SEAM_OBSERVATION ... blocked=14 moved=0 classification=blocked_only`
    across queued route plus seam retry.
  - After that south-approach failure, reroute from `(3,14)` became:
    `3 south, 6 east, 1 south, 1 east, 9 north`.
- Latest interruption state:
  - Route advanced to `(3,15)` and then a Wolflord battle interrupted the run.
  - Fresh read-only probes during the fight:
    - `POSITION: map=0x1A(Garin's Grave B3) x=3 y=15`
    - target still `Lower Stairs Down to B4`
- Best next clean-field check:
  - finish/restore the battle, then directly verify south approach
    `probe_edge_verify:3,14,UP,5` again; route-only evidence is now much
    stronger than the earlier mixed direct pass.
- Follow-up direct verification on that south approach still stayed mixed:
  - `probe_edge_verify:3,14,UP,5` => `moved=1 blocked=4 classification=mixed`
  - This remains suspicious, but still not clean enough to promote.
- Lower-lip route cleanup after that:
  - `(4,17)->DOWN` into `(4,18)` reached route-only `blocked=6 moved=0`,
    then direct verifier confirmed blocked 5/5; promoted as `(4,18).north`.
  - `(3,17)->DOWN` into `(3,18)` reached route-only `blocked=7 moved=0`,
    then direct verifier confirmed blocked 5/5; promoted as `(3,18).north`.
  - `(9,17)->DOWN` into `(9,18)` remained strong route-only evidence
    (`blocked=6 moved=0`) but was not directly rechecked in this pass because
    the west-lip/lower-lip cluster became even stronger.
- Current live frontier after the 7-block runtime set:
  - `auto_walk:10,9` now starts with `Path: 8 north, 7 east`.
  - Even with `(3,18).north` and `(4,18).north` promoted, the route still
    collapses back into `(3,14)->UP` as the dominant upper-pocket choke:
    route evidence is now `blocked=20 moved=0 classification=blocked_only`.
  - Newer route-only candidate from the last reroute:
    `(4,17)->UP` into `(4,16)` reached `blocked=4 moved=0`, not yet directly
    verified.
  - Latest live probe state captured mid-route:
    `POSITION map=0x1A x=3 y=16`, target still `Lower Stairs Down to B4`,
    `RUNTIME_BLOCKS count=7`.
- Post-refresh confirmation:
  - Refresh cleared runtime blockers completely; re-seeded all seven confirmed
    blockers before resuming the dig from `POSITION map=0x1A x=2 y=17`.
  - The restored route matched the prior shape:
    `1 north, 1 east, 7 north, 7 east`.
  - `(2,17)->UP` into `(2,16)` stayed noisy and passable after seam retry.
  - The run again climbed to `(3,14)` and re-hit the same south approach into
    `(3,13)`:
    `blocked=21 moved=0 classification=blocked_only`.
  - A Specter battle interrupted the run at `POSITION map=0x1A x=3 y=14`.
  - Battle-start stat snapshot was still clean:
    `HP 70/70 MP 57/57 LV 13 STR=0x34 AGI=0x2B ATK=0x48 DEF=0x33 spells CE=0x7F CF=0x10`.
- Frontier breakthrough:
  - A stricter raw recheck from the same `(3,14)` frontier finally confirmed
    the south approach into `(3,13)` cleanly:
    `probe_edge_verify:3,14,UP,8` => `moved=0 blocked=8 classification=confirmed_blocked`.
  - Promoted that as `(3,13).south`; runtime entry is now
    `(3,13) dirs=south,west`.
  - With that promotion in place, `auto_walk:10,9` stopped treating the upper
    pocket as a live frontier and immediately rerouted:
    `3 south, 6 east, 1 south, 1 east, 9 north`.
  - The route again reached the lower-east lip and landed at `(9,17)`, then
    began testing the south step toward `(9,18)`.
  - Before the result on `(9,17)->DOWN` settled, a Drollmagi battle
    interrupted the run; post-stop battle probe showed
    `POSITION map=0x1A x=8 y=17`, `runtime_count=7`.
- Lower-lip confirmations and current frontier:
  - Direct verifier later confirmed `(9,17)->DOWN` into `(9,18)` cleanly:
    `probe_edge_verify:9,17,DOWN,5` => `moved=0 blocked=5 classification=confirmed_blocked`.
    Promoted as `(9,18).north`.
  - Direct verifier also confirmed `(2,17)->LEFT` into `(1,17)` cleanly:
    `probe_edge_verify:2,17,LEFT,5` => `moved=0 blocked=5 classification=confirmed_blocked`.
    Promoted as `(1,17).east`.
  - The upper-left family stayed mixed at first:
    `probe_edge_verify:2,14,LEFT,5` => `moved=1 blocked=4 classification=mixed`.
    Keep `(1,14).east` suspicious but unpromoted even though route evidence
    continued to rediscover it as `blocked_only`.
  - The sibling south seam finally promoted cleanly:
    `probe_edge_verify:2,14,DOWN,5` => `moved=0 blocked=5 classification=confirmed_blocked`.
    Promoted as `(2,15).north`; runtime set is now 10 confirmed seams.
  - After adding `(2,15).north`, autowalk immediately treated that cell as
    blocked and rerouted from `(2,14)` through `(3,14) -> (3,15)`.
  - `(3,15)->DOWN` into `(3,16)` and `(3,16)->DOWN` into `(3,17)` both stayed
    noisy but passable after seam retry; do not promote either.
  - The route then reached `(2,17)` and made the lower-left lip the new best
    lead: `(2,17)->DOWN` into `(2,18)` is now
    `blocked=10 moved=0 classification=blocked_only` across queued route plus
    seam retry.
  - Latest interruption state:
    - Drollmagi battle interrupted while the route was re-testing
      `(2,14)->LEFT`; post-stop battle probe showed
      `POSITION map=0x1A x=2 y=14`, `runtime_count=10`.
    - Battle-start snapshot stayed clean:
      `HP 70/70 MP 43/57 LV 13 STR=0x34 AGI=0x2B ATK=0x48 DEF=0x33 spells CE=0x7F CF=0x10`.
  - Best next clean-field check:
    - finish/restore the battle, then directly verify
      `probe_edge_verify:2,17,DOWN,5`.
    - If that confirms, promote `(2,18).north` and re-run `auto_walk:10,9`.
- Planner-wall and hidden-bridge follow-up:
  - Direct verifier confirmed `(2,17)->DOWN` into `(2,18)` cleanly:
    `probe_edge_verify:2,17,DOWN,5` => `moved=0 blocked=5 classification=confirmed_blocked`.
    Promoted as `(2,18).north`.
  - A stricter recheck finally promoted the long-suspicious west seam:
    `probe_edge_verify:2,14,LEFT,8` => `moved=0 blocked=8 classification=confirmed_blocked`.
    Promoted as `(1,14).east`.
  - Upper-left continuation then confirmed cleanly:
    `probe_edge_verify:2,11,LEFT,5` => `moved=0 blocked=5 classification=confirmed_blocked`.
    Promoted as `(1,11).east`.
  - The next west seam also confirmed cleanly:
    `probe_edge_verify:2,10,LEFT,5` => `moved=0 blocked=5 classification=confirmed_blocked`.
    Promoted as `(1,10).east`.
  - With those four additions, the runtime set reached 14 confirmed seams and
    `auto_walk:10,9` from `POSITION map=0x1A x=2 y=10` now returns immediate
    `No path found`.
  - `debug_route_frontier:10,9,60` from `(2,10)` is the new key planner read:
    `reachable=38 target_reachable=false candidates=44 bridge_candidates=41 hidden_bridge_candidates=6`.
    Highest-ranked remaining candidates are hidden-bridge style entries into
    modeled wall tiles, led by `(5,15)->UP` into `(5,14)` and the `(4,14)`
    pocket from south/west.
  - Hidden-bridge evidence gathered so far:
    - `probe_edge_verify:5,15,UP,5` => `moved=2 blocked=3 classification=mixed`
      on `(5,14)`; not promotable yet.
    - `probe_edge_verify:4,15,UP,5` escalated to a stability recheck and
      finished `moved=6 blocked=0 classification=suspect_passable_model_mismatch`.
      `(4,14)` is now a strong hidden-passable candidate even though the model
      still marks tile `1` not walkable.
    - Direct exit test `probe_edge_verify:4,14,UP,5` was
      `classification=inconclusive_control reason=teleport_failed:not walkable`,
      so the hidden cell cannot yet be staged directly by the verifier.
    - Alternate approach `probe_edge_verify:3,14,RIGHT,5` was interrupted by
      combat after three moved-through-modeled-block attempts:
      `classification=inconclusive_interrupted`.
  - Latest interruption state:
    - Battle interrupted the alternate `(3,14)->RIGHT` hidden-bridge check.
    - Best next clean-field resume is to finish/restore the fight, then rerun
      `probe_edge_verify:3,14,RIGHT,5` to strengthen the `(4,14)` evidence.
- Post-reload hidden-bridge breakthrough and upper-pocket dig:
  - After permanently patching the confirmed B3 blockers into `map_reader.lua`
    and manually reloading FCEUX, the live baseline reset cleanly to
    `POSITION map=0x1A x=3 y=14`, `RUNTIME_BLOCKS none`.
  - Hidden bridge into `(4,14)` is now strongly confirmed from two sides:
    - `probe_edge_verify:3,14,RIGHT,5` =>
      `moved=6 blocked=0 classification=suspect_passable_model_mismatch`
    - `probe_edge_verify:4,15,UP,5` previously gave the same modeled-wall pass
      result from the south.
    - Direct exit check `probe_edge:UP` from the bridged tile moved cleanly to
      `(4,13)`, proving the hidden cell actually connects onward.
  - From `(4,13)`, `auto_walk:10,9` became live and exposed a new upper-pocket
    blocker family. Clean direct verifiers promoted these runtime seams:
    - `(7,7).west` via `probe_edge_verify:6,7,RIGHT,5`
    - `(7,8).west` via `probe_edge_verify:6,8,RIGHT,5`
    - `(7,9).west` via `probe_edge_verify:6,9,RIGHT,5`
  - Repeated direct verifiers that remain mixed and should stay unpromoted:
    - `(6,10).north`:
      `probe_edge_verify:6,9,DOWN,8` => `moved=4 blocked=4 classification=mixed`
    - `(5,10).north`:
      `probe_edge_verify:5,9,DOWN,5` => `moved=3 blocked=2 classification=mixed`
    - `(5,10).west`:
      `probe_edge_verify:4,10,RIGHT,5` => `moved=1 blocked=4 classification=mixed`
    - `(5,11).west`:
      `probe_edge_verify:4,11,RIGHT,5` => `moved=1 blocked=4 classification=mixed`
  - Route-only evidence above the bridge is now very strong even where the raw
    verifier still twitches:
    - `(6,10).north` reached `blocked=12 moved=0 classification=blocked_only`
    - `(5,10).north` reached `blocked=6 moved=0 classification=blocked_only`
    - `(5,10).west` reached `blocked=8 moved=0 classification=blocked_only`
    - `(5,11).west` reached `blocked=7 moved=0 classification=blocked_only`
    - Newer `(5,12).west` is emerging but still shallow:
      `blocked=2 moved=0 classification=blocked_only`
  - Best route shape seen so far on the bridged side:
    - With live runtime seams at `(7,7..9).west`, autowalk rerouted through
      `(4,10) -> (4,11) -> (4,12)` instead of forcing the `x=7` strip.
    - A later reroute from `(4,12)` became:
      `3 north, 2 east, 1 south, 4 east, 1 north`.
  - Latest interruption state:
    - Drollmagi battle interrupted the longer bridged-side harvest at
      `POSITION map=0x1A x=4 y=10`.
    - Runtime set still active in the live session:
      `(7,7).west`, `(7,8).west`, `(7,9).west`.
    - Battle-start snapshot stayed clean for suspect-2 tracking:
      `HP 70/70 MP 57/57 LV 13 STR=0x34 AGI=0x2B ATK=0x48 DEF=0x33 CE=0x7F CF=0x10`.
  - Best next clean-field resume:
    - let the battle finish or restore, then continue `auto_walk:10,9` from
      the bridged side with the three `x=7` runtime seams already seeded.
    - If the route immediately re-hits the west family, prioritize
      `(5,11).west` or `(5,12).west` as the next direct rechecks because they
      are now the freshest upper-pocket leads.
  - Fresh reload / armor-up continuation:
    - Fresh FCEUX reload reset runtime blockers and landed at
      `POSITION map=0x1A x=2 y=17`, `RUNTIME_BLOCKS none`.
    - Hidden bridge reconfirmed again from the southwest side:
      `probe_edge_verify:3,14,RIGHT,5` =>
      `moved=6 blocked=0 classification=suspect_passable_model_mismatch`
      with stability recheck.
    - Direct follow-up `probe_edge:UP` from `(4,14)` again moved cleanly to
      `(4,13)`, so the hidden bridge is still the live route into the upper
      pocket.
    - Reconfirmed and re-seeded the three known strip blockers live:
      - `(7,9).west` via `probe_edge_verify:6,9,RIGHT,5`
      - `(7,8).west` via `probe_edge_verify:6,8,RIGHT,5`
      - `(7,7).west` via `probe_edge_verify:6,7,RIGHT,5`
      All three were `moved=0 blocked=5 classification=confirmed_blocked`.
    - With those live again, autowalk returned to the upper west-wall family
      and one more seam finally promoted cleanly:
      - `(5,12).west` via `probe_edge_verify:4,12,RIGHT,5`
        => `moved=0 blocked=5 classification=confirmed_blocked`
      - `(5,11).west` via `probe_edge_verify:4,11,RIGHT,5`
        => `moved=0 blocked=5 classification=confirmed_blocked`
    - Current live runtime set is now 5:
      `(7,7).west`, `(7,8).west`, `(7,9).west`, `(5,12).west`, `(5,11).west`
    - Fresh route-only frontier after those promotions:
      - `(6,10).north` has climbed back to
        `blocked=8 moved=0 classification=blocked_only`
      - `(5,10).west` is up to
        `blocked=6 moved=0 classification=blocked_only`
      - `(5,10).north` is up to
        `blocked=5 moved=0 classification=blocked_only`
      - `(6,9).west` and `(5,9).east` remain noisy, not promotable.
    - Latest interruption state:
      - Drollmagi battle interrupted during another `(5,9)->DOWN` seam-retry
        branch; post-stop battle probe showed
        `POSITION map=0x1A x=5 y=9`, `runtime_count=5`.
      - Battle-start stat snapshot stayed clean after the equipment upgrade:
        `STR=0x34 AGI=0x2B ATK=0x48 DEF=0x39 CE=0x7F CF=0x10`.
    - Best next clean-field checks:
      - finish/restore the battle, then directly recheck
        `probe_edge_verify:6,9,DOWN,5` for `(6,10).north`
      - if that still stays mixed, fall through to
        `probe_edge_verify:4,10,RIGHT,5` for `(5,10).west`
        or `probe_edge_verify:5,9,DOWN,5` for `(5,10).north`

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

## 2026-06-01 Hook-fix dig smoke test

- Hook cleanup held during live work; no fresh `unsupported suppressOutput`
  spam appeared while running the bridged-side dig.
- Fresh live baseline after the restart:
  - `POSITION map=0x1A x=3 y=14`
  - `RUNTIME_BLOCKS map=0x1A none`
  - `PATH_STATE target=nil map=0x1A runtime_count=0`
- Hidden bridge remained live from the southwest side:
  - `probe_edge_verify:3,14,RIGHT,5` =>
    `moved=6 blocked=0 classification=suspect_passable_model_mismatch`
  - follow-up `probe_edge:UP` from `(4,14)` moved to `(4,13)`
- Current clean bridged-side runtime blockers reconfirmed this session:
  - `(7,7).west`, `(7,8).west`, `(7,9).west`
- Mixed direct verifier, still unpromoted:
  - `(6,10).north` via `probe_edge_verify:6,9,DOWN,5` =>
    `moved=3 blocked=2 classification=mixed`
- Short harvest with the `x=7` trio active reached the next west-wall family:
  - `(5,10).west` hit `blocked=2 moved=0 classification=blocked_only`
  - `(5,11).west` hit `blocked=1 moved=0 classification=blocked_only`
  - `(4,11).north` stayed noisy after seam retry; do not promote
- Latest interruption state:
  - Druinlord battle started at `POSITION map=0x1A x=4 y=11`
  - runtime blockers still active in-session:
    `(7,7).west`, `(7,8).west`, `(7,9).west`
  - by log inspection only, the fight resolved normally:
    Druinlord defeated for `+20 EXP` and `+64 GOLD`, then field logging resumed
  - per user instruction, no further route commands were queued after combat
- Follow-up live continuation after the user-cleared fight:
  - user-ran direct verifier confirmed `(5,11).west` cleanly:
    `probe_edge_verify:4,11,RIGHT,5` =>
    `moved=0 blocked=5 classification=confirmed_blocked`
  - after runtime injection, planner from `(4,11)` rerouted to
    `1 north, 6 east, 1 north`
  - the tempting sibling `(5,10).west` was disproved as a clean blocker:
    `probe_edge_verify:4,10,RIGHT,5` was interrupted by battle, but its first
    attempt moved cleanly into `(5,10)` before the encounter
  - stronger direct confirmations from the same cluster:
    - `(6,10).west` via `probe_edge_verify:5,10,RIGHT,5`
      => `moved=0 blocked=5 classification=confirmed_blocked`
    - `(5,11).north` via `probe_edge_verify:5,10,DOWN,5`
      => `moved=0 blocked=5 classification=confirmed_blocked`
    - `(6,10).north` via `probe_edge_verify:6,9,DOWN,5`
      => `moved=0 blocked=5 classification=confirmed_blocked`
  - current clean runtime set after those promotions:
    - `(7,7).west`, `(7,8).west`, `(7,9).west`
    - `(6,10).north,west`
    - `(5,11).north,west`
  - once the `5,10/5,11/6,10` cluster was sealed, planner from `(6,9)` shifted
    to a new route family:
    `Path: 3 north, 4 east, 3 south`
  - short harvest on that new route reached much farther east/up than before:
    - moved through `(6,8)`, `(6,7)`, `(6,6)`, `(6,5)`, `(6,4)`,
      `(7,4)`, `(8,4)`, `(9,4)`
    - new route-only blocked candidates emerged:
      - `(7,5).west` reached `blocked=2 moved=0 classification=blocked_only`
      - `(10,4).west` reached `blocked=1 moved=0 classification=blocked_only`
  - latest interruption state:
    - Wolflord battle started at `POSITION map=0x1A x=9 y=4`
    - runtime blockers remained the five-cell set above
    - best next clean resume after combat is to continue from `(9,4)` and
      prioritize direct rechecks of `(10,4).west` and then `(7,5).west`
- Lower-right bypass continuation after `(10,4).west`:
  - direct verifier confirmed `(10,4).west` cleanly:
    `probe_edge_verify:9,4,RIGHT,5` =>
    `moved=0 blocked=5 classification=confirmed_blocked`
  - after promoting that, the route successively exposed and confirmed:
    - `(9,6).north` via `probe_edge_verify:9,5,DOWN,5`
    - `(10,5).west` via `probe_edge_verify:9,5,RIGHT,5`
    - `(8,6).north` via `probe_edge_verify:8,5,DOWN,5`
    - `(7,5).east` via `probe_edge_verify:8,5,LEFT,5`
    - `(9,10).west` via `probe_edge_verify:8,10,RIGHT,5`
    - `(9,9).west` via `probe_edge_verify:8,9,RIGHT,5`
    - `(13,9).south` via `probe_edge_verify:13,10,UP,5`
    - `(12,10).east` via `probe_edge_verify:13,10,LEFT,5`
  - already-confirmed siblings reused in this same family:
    - `(10,10).south`
    - `(12,10).south`
  - current larger runtime set around the lower-right bypass is now:
    - `(10,4).west`
    - `(10,5).west`
    - `(9,6).north`
    - `(8,6).north`
    - `(7,5).east`
    - `(9,8).west`
    - `(9,9).west`
    - `(9,10).west`
    - `(10,10).south`
    - `(12,10).east,south`
    - `(13,9).south`
    - plus the earlier bridge-side set:
      `(7,7).west`, `(7,8).west`, `(7,9).west`,
      `(6,10).north,west`, `(5,11).north,west`
  - important negative / mixed signals in this family:
    - `(8,4).south` stayed noisy and should remain unmodeled
    - `(10,11).west`, `(11,11).west`, `(12,11).west`, `(13,11).west` all
      looked noisy/passable after seam retry; do not promote
    - direct `probe_edge_verify:11,11,UP,5` was interrupted by battle, but
      attempts 3 and 4 moved cleanly into `(11,10)` before combat:
      treat `(11,10).south` as likely passable, not blocked, until rechecked
  - strongest remaining unverified live blocker:
    - `(9,10).south` from `probe_edge_verify`-equivalent route evidence is now
      up to `blocked=10 moved=0 classification=blocked_only`
  - latest interruption state:
    - Specter battle started at `POSITION map=0x1A x=11 y=11`
    - stats remained stable at battle start:
      `HP 64/70 MP 49/57 LV 13 STR=0x34 AGI=0x2B ATK=0x48 DEF=0x39`
    - best next clean resume after combat is:
      `probe_edge_verify:9,11,UP,5`
      and only then re-evaluate the `11,11 -> UP` branch if needed
- Post-combat continuation from the Specter stop:
  - user-ran direct verifier cleanly confirmed `(9,10).south`:
    - `probe_edge_verify:9,11,UP,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - runtime promotion added the second blocked approach on the same cell:
      `RUNTIME_BLOCK map=0x1A x=9 y=10 key=9,10 dirs=south,west`
  - fresh planner from the live verifier origin still had a route:
    - `debug_pathfind_to:10,9` from `(9,11)` =>
      `Path: 2 east, 2 north, 1 west`
  - short autowalk harvest on that reroute clarified the next branch:
    - `(10,11)->RIGHT` into `(11,11)` again stayed noisy/passable after
      seam retry; do not promote `(11,11).west`
    - `(11,11)->UP` into `(11,10)` now built much stronger route evidence:
      `blocked=10 moved=0 classification=blocked_only`
    - with that temporary reroute pressure active, planner from `(11,11)`
      swung to `Path: 3 east, 2 north, 4 west`
    - right-side detour findings from that new path:
      - `(13,11)->RIGHT` into `(14,11)` reached
        `blocked=2 moved=0 classification=blocked_only`
      - `(13,11)->UP` into `(13,10)` moved cleanly
      - `(13,10)->RIGHT` into `(14,10)` reached
        `blocked=1 moved=0 classification=blocked_only`
  - latest interruption state:
    - battle started at `POSITION map=0x1A x=13 y=10`
    - strongest next clean direct recheck is now `probe_edge_verify:11,11,UP,5`
    - if staying local to the stop point, the immediate sibling lead is
      `probe_edge_verify:13,10,RIGHT,5`
- Post-battle continuation from the `(13,10)` stop:
  - user-ran direct verifier cleanly confirmed `(11,10).south`:
    - `probe_edge_verify:11,11,UP,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - runtime promotion added:
      `RUNTIME_BLOCK map=0x1A x=11 y=10 key=11,10 dirs=south`
  - user-ran sibling verifier stayed genuinely mixed:
    - `probe_edge_verify:13,10,RIGHT,5` =>
      `moved=2 blocked=3 classification=mixed`
    - keep `(14,10).west` unpromoted despite the blocked-majority split
  - with `(11,10).south` active, fresh planner from `(13,10)` still found a
    detour:
    - `debug_pathfind_to:10,9` =>
      `Path: 2 south, 1 east, 3 north, 4 west`
  - live autowalk from `(13,10)` adapted around the new blocker and yielded:
    - initial stair-target plan snapshot:
      `Path: 1 east, 1 north, 4 west`
    - immediate first step `(13,10)->RIGHT` hit
      `SEAM_OBSERVATION cell=(14,10) approach=west result=blocked`
      and forced a reroute; treat this as stronger route pressure, but not as
      enough to override the mixed direct verifier
    - rerouted branch moved cleanly `(13,10)->DOWN` to `(13,11)`
    - next step `(13,11)->RIGHT` into `(14,11)` reached
      `blocked=3 moved=0 classification=blocked_only`
      before a battle interrupted the seam-retry finish
  - latest interruption state:
    - Drollmagi battle started at `POSITION map=0x1A x=13 y=11`
    - best next clean direct recheck is now `probe_edge_verify:13,11,RIGHT,5`
    - `(14,10).west` remains secondary until it stops coming back mixed
- Post-battle continuation from the `(13,11)` stop:
  - user-ran direct verifier cleanly confirmed `(14,11).west`:
    - `probe_edge_verify:13,11,RIGHT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
  - user then reran the older mixed sibling and it also cleaned up:
    - `probe_edge_verify:13,10,RIGHT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - so `(14,10).west` is now promotable after all; the earlier mixed result
      should be treated as stale/contaminated, not authoritative
  - after injecting both right-side walls, planner from `(13,10)` still had a
    live loop:
    - `debug_pathfind_to:10,9` =>
      `Path: 2 south, 1 east, 3 north, 4 west`
  - the follow-up autowalk eventually swung back through the upper-left and
    produced one more clean direct confirmation:
    - `probe_edge_verify:8,7,RIGHT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
      for `(9,7).west`
  - current larger runtime set now includes these three additions:
    - `(14,11).west`
    - `(14,10).west`
    - `(9,7).west`
  - fresh autowalk from the verifier side `(8,7)` still did not die:
    - planner before harvest:
      `debug_pathfind_to:10,9` => `Path: 1 north, 2 east, 3 south`
    - strongest new route-only blocker after that harvest:
      - `(8,7)->UP` into `(8,6)` reached
        `blocked=8 moved=0 classification=blocked_only`
        suggesting `(8,6).south`
    - next-best siblings from the same loop:
      - `(8,7)->LEFT` into `(7,7)` reached
        `blocked=4 moved=0 classification=blocked_only`
      - `(8,8)->LEFT` into `(7,8)` reached
        `blocked=4 moved=0 classification=blocked_only`
    - weaker/newer south-side clutter from the same run:
      - `(13,12).north` reached `blocked=2 moved=0`
      - `(12,12).north` reached `blocked=2 moved=0`
      - `(7,9).east` only reached `blocked=1 moved=0` before battle
  - latest interruption state:
    - battle started at `POSITION map=0x1A x=8 y=9`
    - best next clean direct recheck is now `probe_edge_verify:8,7,UP,5`
    - if that confirms, follow with `probe_edge_verify:8,7,LEFT,5` and then
      `probe_edge_verify:8,8,LEFT,5`
- Post-battle continuation from the `(8,9)` stop:
  - fresh baseline survived exactly:
    - `POSITION map=0x1A x=8 y=9`
    - `RUNTIME_BLOCKS map=0x1A count=20`
  - direct verifier on the old strongest lead did not clean up:
    - `probe_edge_verify:8,7,UP,5` =>
      `moved=2 blocked=3 classification=mixed`
    - treat `(8,6).south` as a real unresolved anomaly, not promotable data
  - the two stronger east-side siblings did clean up immediately:
    - `probe_edge_verify:8,7,LEFT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
      for `(7,7).east`
    - `probe_edge_verify:8,8,LEFT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
      for `(7,8).east`
    - follow-up planner from `(8,8)` still stayed alive:
      `debug_pathfind_to:10,9` =>
      `Path: 2 south, 1 west, 4 north, 3 east, 3 south`
  - short autowalk from that cleaner state then strengthened the remaining
    upper-left seam and exposed the next sibling:
    - `(8,6).south` climbed from route-only `blocked=10 moved=0`
    - `(7,9).east` strengthened to `blocked=3 moved=0`
  - the third east-side sibling also cleaned up on direct retry:
    - `probe_edge_verify:8,9,LEFT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
      for `(7,9).east`
    - after injecting it, planner from `(8,9)` still stayed alive:
      `debug_pathfind_to:10,9` => `Path: 3 north, 2 east, 3 south`
  - a second fresh autowalk from `(8,9)` still refused to die:
    - `(8,6).south` climbed further to
      `blocked=12 moved=0 classification=blocked_only`
    - lower-left detour `(8,10)->LEFT` into `(7,10)` appeared as a new seam:
      `blocked=2 moved=0 classification=blocked_only`
    - deeper reroute moved cleanly `(8,11)->LEFT` to `(7,11)`:
      `SEAM_OBSERVATION cell=(7,11) approach=east result=moved`
  - direct verifier on the new lower-left seam stayed mixed:
    - `probe_edge_verify:8,10,LEFT,5` =>
      `moved=1 blocked=4 classification=mixed`
    - important nuance: this seam has no static or runtime directional block,
      so the block half is engine behavior, not map-model support
  - the follow-up direct test from the newly opened lower tile looked
    promising before combat:
    - `probe_edge_verify:7,11,UP,5` moved on attempts 1 and 2 into `(7,10)`
    - attempt 3 was cut off by battle start, so result is only
      `classification=inconclusive_interrupted`
  - latest interruption state:
    - Druinlord battle started at `POSITION map=0x1A x=7 y=11`
    - battle later appears to have resolved by log inspection
      (`+20 EXP`, `+66 GOLD`), but no post-battle field probe or movement was
      queued after that
    - best next clean rerun is now `probe_edge_verify:7,11,UP,5`
    - keep `(7,10).east` secondary and `(8,6).south` flagged as the bigger
      unresolved anomaly
- 2026-06-01 teleport/verifier code dig:
  - reruns of `probe_edge_verify:7,11,UP,5` and `probe_edge_verify:8,10,LEFT,5`
    both repeated the same pattern: attempt 1 moved from the live start tile,
    then teleported retries blocked on `raw_hold_timeout` with
    `mismatch=blocked_despite_open_preview`
  - comparison against clean repeated-start passes showed the issue is not just
    odd overworld shadow bytes; healthy open seams can also teleport back with
    weird shadow state and still move 5/5 or 6/6
  - working hypothesis: internal repeated-start teleport does not fully
    reconstruct the natural arrival context for some stateful seams, so later
    verifier attempts can self-contaminate even when the first live attempt
    moved cleanly
  - code patch landed:
    - new `edge_verify_classifier.lua`
    - `probe_edge_verify` now promotes this exact signature to
      `classification=inconclusive_teleport_artifact` instead of ordinary
      `mixed`
    - `EDGE_VERIFY_RESULT` now logs
      `teleport_artifact_suspected`, `first_attempt_status`,
      `blocked_after_move`, `blocked_after_move_mismatch`, and
      `moved_after_blocked`
  - validation:
    - new `test_edge_verify_classifier.lua` passes
    - `python3 run_tests.py --allow-missing-speech-dep` kept all Lua unit tests
      green; the only runner red remains the longstanding standalone `luac`
      refusal on `main.lua` (`main function has more than 200 local variables`)
- 2026-06-01 post-fix B3 continuation from the clean reset baseline:
  - fresh field heartbeat survived after the Lua 5.1 local-limit fix:
    - `POSITION map=0x1A x=8 y=10`
    - `RUNTIME_BLOCKS map=0x1A none`
    - `PATH_STATE target=nil map=0x1A runtime_count=0`
  - direct recheck on the old lower-left mixed seam cleaned up immediately:
    - `probe_edge_verify:8,10,LEFT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - this is now clean engine-block evidence for `(7,10).east`, not teleport
      contamination
  - direct rerun on the old likely-passable seam did exactly what the new
    classifier was built to expose:
    - `probe_edge_verify:7,11,UP,5` =>
      `moved=3 blocked=2 classification=inconclusive_teleport_artifact`
    - attempts 1-3 moved from the live start tile into `(7,10)`
    - attempts 4-5 only blocked after teleport resets with
      `mismatch=blocked_despite_open_preview`
    - treat `(7,10).south` as likely passable/harness-noise, not as a blocker
  - restored the current B3 runtime edge set after the reset and added the new
    mirror for `(7,10).east`:
    - `add_blocked_edge:8,10,LEFT`
    - `report_runtime_blocks` then read back `count=20`
  - with that live blocker set, the planner from real `(7,11)` stayed alive:
    - `debug_pathfind_to:10,9` =>
      `Path: 3 north, 3 east, 1 south`
  - live `auto_walk:10,9` from `(7,11)` immediately treated `(7,10).south` as
    a temporary blocked step, then rerouted around it instead of dying:
    - first blocked step:
      `SEAM_OBSERVATION map=0x1A cell=(7,10) approach=south result=blocked`
    - temp route block:
      `AUTO_WALK_TEMP_BLOCK map=0x1A from=(7,11) dir=up dest=(7,10)`
    - reroute snapshot:
      `Path: 1 east, 3 north, 2 east, 1 south`
  - the rerouted walk made real forward progress before combat:
    - `(8,11)` west approach moved cleanly
    - `(8,10)` south approach moved cleanly
    - `(8,9)` south approach moved cleanly
  - the next fresh suspect seam is now one tile north of the battle stop:
    - from `(8,9)`, queued-route `(8,9)->UP` into `(8,8)` blocked once
    - `SEAM_OBSERVATION map=0x1A cell=(8,8) approach=south result=blocked`
    - a seam retry had started, but a battle interrupted before the retry
      finished, so `(8,8).south` is not promotable yet
  - latest interruption state:
    - Specter battle started at `POSITION map=0x1A x=8 y=9`
    - `PATH_STATE` target remained `Lower Stairs Down to B4`
    - best next direct check after combat is `probe_edge_verify:8,9,UP,5`
- 2026-06-01 post-Specter follow-up around `(8,9)/(8,11)`:
  - user follow-up probe was not the planned `(8,9)->UP` seam check; instead it
    directly tested the reverse nearby edge:
    - `probe_edge_verify:8,10,DOWN,5` into `(8,11)` escalated to a stability
      recheck and finished
      `moved=6 blocked=0 classification=confirmed_passable`
    - this cleanly confirms `(8,11).north` open and leaves the hero on field
      at `(8,11)`
  - fresh baseline after that probe:
    - `POSITION map=0x1A x=8 y=11`
    - `RUNTIME_BLOCKS map=0x1A count=20`
    - `PATH_STATE target=Lower Stairs Down to B4 type=stair x=10 y=9 map=0x1A`
  - planner from real `(8,11)` stayed alive, but only by honoring two
    lingering temporary route blocks from the interrupted autowalk:
    - `debug_pathfind_to:10,9` =>
      `Path: 2 west, 1 north, 1 east, 2 north, 3 east, 1 south`
    - `ROUTE_PLAN_SNAPSHOT ... route_temp_blocks=2`
    - one of those temp constraints is the old `(7,10).south` reroute memory;
      another is the `(8,8).south` suspect from the interrupted climb
  - direct rerun on the actual fresh seam then repeated the “looks open before
    combat” pattern:
    - `probe_edge_verify:8,9,UP,5` moved into `(8,8)` on attempts 1-3
    - a Specter battle started at `POSITION map=0x1A x=8 y=9` before attempts
      4-5 settled
    - final result:
      `moved=3 blocked=0 interrupted=1 classification=inconclusive_interrupted`
    - this is not evidence to promote `(8,8).south` as blocked
  - latest interruption state:
    - Specter battle in progress at `POSITION map=0x1A x=8 y=9`
    - best next clean recheck after combat remains `probe_edge_verify:8,9,UP,5`
    - if it still moves or stays interrupted/mixed, continue route harvest
      instead of injecting a blocker there
- 2026-06-01 noisy-probe cleanup plus HP observation:
  - the user noted two small HP increases while probing and suspected a hidden
    healing-cell mechanic
  - repo-side decode of the live equipment byte from `stat_ram` / `snapshot`
    shows:
    - weapon = `Broad Sword`
    - armor = `Magic Armor`
    - shield = `Large Shield`
  - this fits vanilla DW1 behavior better than terrain healing:
    - Magic Armor restores 1 HP every 4 steps on the field
    - treat the observed `53 -> 55` during repeated probe movement as expected
      armor regen, not map evidence
  - the noisy `probe_edge_verify:8,9,UP,5` eventually cleaned up fully:
    - first resumed attempt after a prior Specter interruption moved 3/5 before
      another battle
    - later full rerun at frames `793860-794738` escalated to stability recheck
      and finished
      `moved=6 blocked=0 classification=confirmed_passable`
    - `(8,8).south` is now confirmed passable; the lingering `classification=noisy`
      seam observation only reflects one older blocked sample before the clean
      rerun
  - fresh baseline after that cleanup:
    - `POSITION map=0x1A x=8 y=8`
    - `RUNTIME_BLOCKS map=0x1A count=20`
    - `PATH_STATE target=Lower Stairs Down to B4 type=stair x=10 y=9 map=0x1A`
  - shortest planner route from that confirmed-open tile:
    - `debug_pathfind_to:10,9` =>
      `Path: 2 east, 1 south`
  - important execution nuance:
    - live `auto_walk:10,9` from `(8,8)` started with the same short route
    - first step `(8,8)->RIGHT` into `(9,8)` hit a timing-retry temp block:
      `AUTO_WALK_TEMP_BLOCK ... from=(8,8) dir=right dest=(9,8)`
    - reroute then got sucked back into the old upper-left family:
      `(8,7)->UP` temp-blocked, then `(8,10)->DOWN` noisy/moved, then
      `(7,11)->UP` blocked again, finally drifting all the way to `(6,11)`
  - latest interruption state:
    - Druinlord battle started at `POSITION map=0x1A x=6 y=11`
    - HP at battle start was `57 / 70`
    - best next clean direct check is now `probe_edge_verify:8,8,RIGHT,5`
      because that is the first unresolved failure on the shortest route to
      the stair
    - if staying local to the battle stop is preferred, immediate sibling
      follow-up is `probe_edge_verify:6,11,UP,5`
- 2026-06-01 short-route timing-retry cleanup:
  - user follow-up probes settled the two outstanding direct checks exactly as
    hoped:
    - `probe_edge_verify:8,8,RIGHT,5` =>
      `moved=6 blocked=0 classification=confirmed_passable`
    - `probe_edge_verify:6,11,UP,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
  - fresh baseline after those probes:
    - `POSITION map=0x1A x=6 y=11`
    - `RUNTIME_BLOCKS map=0x1A count=20`
    - `PATH_STATE target=nil map=0x1A runtime_count=20`
  - planner from the real `(6,11)` stop still had a live route:
    - `debug_pathfind_to:10,9` =>
      `Path: 2 east, 3 north, 2 east, 1 south`
  - live autowalk then exposed the current harness issue more cleanly than the
    earlier `(8,8)->RIGHT` run:
    - `(7,11)->RIGHT` first published a blocked/noisy seam observation plus
      `AUTO_WALK_TEMP_BLOCK ... source=timing_retry`, then the immediate
      `seam_retry` moved into `(8,11)` and cleared the temp block
    - seam-retry follow-up from `(8,11)` shortened to
      `Path: 3 north, 2 east, 1 south`
    - `(8,11)->UP` then produced the same timing-retry temp-block pattern
      before a Wolflord battle interrupted at `POSITION map=0x1A x=8 y=11`
  - root cause in code:
    - `route_manager.on_blocked` was calling `observe_seam_result(...,"blocked")`
      before it decided a queued-route timeout was just a timing-suspect seam
      retry
    - when the retry then succeeded, seam memory kept one fake blocked count
      plus one moved count, downgrading good edges to `classification=noisy`
  - code patch:
    - delay the blocked seam observation for timing-suspect queued-route
      timeouts until after `start_seam_bruteforce(...)` declines/fails
    - successful timing retries now only contribute the later `moved`
      observation and still keep their route-local temp block behavior
  - regression added in `test_route_manager.lua`:
    - after a successful timing retry, seam observation stays
      `blocked_count=0 moved_count=1`
      and seam summary stays `passable_only`, not `noisy`
- verification:
  - `lua5.1 test_route_manager.lua` passed after the patch
  - `luac5.1 -p route_manager.lua test_route_manager.lua` passed
  - `git diff --check` passed
  - `python3 run_tests.py --allow-missing-speech-dep` passed aside from the
    expected speech dependency warning for `accessible_output2`
- next live step after the user clears the Wolflord and reloads `main.lua`
  in FCEUX:
  - re-baseline at `(8,11)`
  - rerun `debug_pathfind_to:10,9` and `auto_walk:10,9`
  - keep `probe_edge_verify:8,11,UP,5` as the local fallback if the route
    still misbehaves before the stair

- 2026-06-01 combat-interrupted seam-retry stale-temp-block bug:
  - root-cause hypothesis confirmed live:
    - after the Drollmagi resolved, fresh baseline came back at
      `POSITION map=0x1A x=8 y=9`,
      `RUNTIME_BLOCKS map=0x1A count=20`,
      `PATH_STATE target=Lower Stairs Down to B4 ... runtime_count=20`
    - from that exact live tile, both
      `debug_pathfind_to:10,9` and `debug_pathfind_to_skip_npcs:10,9`
      returned `No path found` with `route_temp_blocks=3`
    - this was not an NPC issue and not fresh blocker evidence
  - minimal live falsification test:
    - sent manual `stop_auto_walk`
    - `PATH_STATE` immediately cleared to nil
    - reran `debug_pathfind_to:10,9`
    - same live tile recovered to
      `Path: 1 north, 2 east, 1 south`
      with `route_temp_blocks=0`
    - conclusion: stale route temp blocks from the interrupted autowalk were
      poisoning later planner/debug calls
  - code trace:
    - `auto_step.update(false)` only treated `route_steps ~= nil` as a route
      worth cancelling on `can_walk=false`
    - during live autowalk, combat can hit while the active step source is
      `seam_retry` after `clear_route()` already emptied `route_steps`
    - that leaves `route_manager` holding temp-block/target context because it
      never receives `route_cancelled`
  - fix:
    - added `queued_route_cancel_source()` in `auto_step.lua`
    - `can_walk=false` now emits `route_cancelled` for queued-route-derived
      contexts even when `route_steps` is already nil:
      `queued_route`, `seam_retry`, queued-route pending repress, and
      route-settle windows
  - regression:
    - added `can_walk_false_cancels_seam_retry_route_context` to
      `test_auto_step.lua`
    - verified red first:
      `FAIL ... can_walk=false should cancel an active seam-retry step so route managers can clear stale temp blocks`
    - green after patch:
      `lua5.1 test_auto_step.lua` passed
  - additional verification:
    - `lua5.1 test_route_manager.lua` passed
    - `luac5.1 -p auto_step.lua test_auto_step.lua route_manager.lua` passed
    - `git diff --check` passed
    - `python3 run_tests.py --allow-missing-speech-dep` passed aside from the
      expected `accessible_output2` warning
  - live status after code patch:
    - FCEUX had not yet reloaded `main.lua`, so the fix was not active in the
      running emulator during this session
    - attempted follow-up `auto_walk:10,9` did not get fresh command
      consumption before the log went idle, so no new map evidence was taken
      from that point
    - until reload, use `stop_auto_walk` as the manual workaround after any
      combat-interrupted seam-retry/autowalk before trusting `debug_pathfind_*`
      or `auto_walk`
- 2026-06-01 post-patch live continuation after the user let autowalk run to combat:
  - old resumed Specter battle resolved cleanly by log inspection:
    - `+18 EXP`, `+61 GOLD`
    - field heartbeat later confirmed the live script was still polling
  - surprising state change after that battle:
    - baseline came back at `POSITION map=0x1A x=10 y=11`
    - `RUNTIME_BLOCKS map=0x1A none`
    - `PATH_STATE target=Lower Stairs Down to B4 ... runtime_count=0`
    - so the current FCEUX/script session had lost the in-memory B3 runtime
      blocker set even though the route target survived
  - reseeded the current B3 runtime set from handoff plus the user-confirmed
    `add_blocked_edge:6,11,UP`:
    - `report_runtime_blocks` returned `count=20`
    - note: `count` stayed 20 because `(6,10).south` merged into the existing
      `cell=(6,10)` entry rather than creating a new cell
  - fresh planner after reseed:
    - `debug_pathfind_to:10,9` from live `(10,11)` =>
      `Path: 3 west, 5 north, 3 east, 3 south`
    - live `auto_walk:10,9` from the same stop planned slightly cleaner under
      parked-NPC mode:
      `Path: 2 west, 3 north, 2 east, 1 south`
  - live route progress under restored blockers:
    - `(10,11)->LEFT` was timing-suspect on the queued step but the seam retry
      moved cleanly into `(9,11)`; `(9,11).east` remains `passable_only`
    - autowalk then moved cleanly `(9,11)->LEFT` to `(8,11)`,
      `(8,11)->UP` to `(8,10)`, `(8,10)->UP` to `(8,9)`, and seam-retry from
      `(8,9)->UP` again moved into `(8,8)`
    - seam-retry follow-up from `(8,8)` again shortened to
      `Path: 2 east, 1 south`
  - key contradiction strengthened:
    - the older direct verifier still says
      `probe_edge_verify:8,8,RIGHT,5` => `moved=6 blocked=0`
    - but the natural route-context seam now failed there again:
      - current run added a third live blocked seam-retry at `(8,8)->RIGHT`
        into `(9,8)`
      - seam memory is now
        `SEAM_OBSERVATION map=0x1A cell=(9,8) approach=west result=blocked blocked=3 moved=0 classification=blocked_only source=seam_retry_block`
    - this is no longer ordinary timing noise; it looks like a genuine
      route-context / arrival-context contradiction between teleported verify
      and natural live movement
    - do not promote `(9,8).west` either way yet
  - additional live-only blocked siblings strengthened during the same run:
    - `(5,11).east` reached `blocked=2 moved=0 classification=blocked_only`
    - `(6,12).north` reached `blocked=2 moved=0 classification=blocked_only`
    - both are still route-context evidence only, not direct-verifier cleanups
  - later reroute wandered east across row 11 before the next stop:
    - clean moved seams observed through `(7,11)`, `(8,11)`, `(9,11)`,
      `(10,11)`, `(11,11)`, and `(12,11)` from the west
    - next fresh timing-suspect seam at the far side was `(12,11)->RIGHT`
      into `(13,11)`, but battle interrupted before the seam-retry result
      settled
  - current stop condition:
    - new Specter battle started at `POSITION map=0x1A x=11 y=11`
    - HP at battle start was `69 / 70`
    - I manually sent `stop_auto_walk` during battle to avoid queueing further
      route work
    - `report_runtime_blocks` during battle still showed `count=20`
    - `report_path_state` during battle now shows `target=nil` because
      `stop_auto_walk` cleared the active route target
  - best next live step after the user clears the battle:
    - re-baseline with `report_position`, `report_runtime_blocks`,
      `report_path_state`
    - if runtime blocks are empty again, reseed the B3 set plus
      `add_blocked_edge:6,11,UP`
    - because target is now nil, rerun `debug_pathfind_to:10,9` from the live
      `(11,11)` stop before deciding whether to launch another `auto_walk`
    - if the route naturally reaches `(8,8)` again, prefer a live/manual
      bracket on `RIGHT` over another teleport-based verifier rerun

- 2026-06-02 morning reload continuation on B3:
  - fresh live baseline after the script reload:
    - `launcher_probe:codex_b3_resume` consumed cleanly
    - `POSITION map=0x1A x=8 y=7`
    - `RUNTIME_BLOCKS map=0x1A none`
    - `PATH_STATE target=nil map=0x1A runtime_count=0`
  - clean seam confirmations from the same reload:
    - earlier fresh verifier already had
      `probe_edge_verify:8,7,RIGHT,5` =>
      `EDGE_VERIFY_RESULT ... moved=0 blocked=5 classification=confirmed_blocked`
      for `(9,7).west`
    - same reload also now cleanly confirmed
      `probe_edge_verify:8,7,UP,5` =>
      `EDGE_VERIFY_RESULT ... moved=0 blocked=5 classification=confirmed_blocked`
      for `(8,6).south`
  - reseed action:
    - injected the standing B3 runtime set from handoff plus
      `add_blocked_edge:6,11,UP` and the newly promoted
      `add_blocked_edge:8,7,UP`
    - `report_runtime_blocks` still came back `count=20`
    - important nuance: count stayed 20 because `(6,11).UP` merged into
      existing cell `(6,10)` and `(8,7).UP` merged into existing cell `(8,6)`
      instead of adding brand-new cells
  - fresh planner after reseed:
    - `debug_pathfind_to:10,9` from live `(8,7)` =>
      `Path: 1 south, 2 east, 1 south`
  - live `auto_walk:10,9` harvest under the reseeded set:
    - queued-route `(8,7)->DOWN` timing-blocked, but seam retry moved into
      `(8,8)` and cleared the temp block
    - follow-up from `(8,8)` again hit the known contradiction:
      `(8,8)->RIGHT` into `(9,8)` failed on seam retry with
      `SEAM_OBSERVATION ... cell=(9,8) approach=west result=blocked blocked=2 moved=0 classification=blocked_only`
    - treat `(9,8).west` as still contradictory between natural arrival and
      the older teleported verifier; do not promote either state yet
  - new route-context-only blocker pressure from the same run:
    - `(7,10).south` logged
      `SEAM_OBSERVATION ... cell=(7,10) approach=south result=blocked blocked=1 moved=0 classification=blocked_only`
    - `(5,11).east` logged
      `SEAM_OBSERVATION ... cell=(5,11) approach=east result=blocked blocked=1 moved=0 classification=blocked_only`
    - `(6,12).north` logged
      `SEAM_OBSERVATION ... cell=(6,12) approach=north result=blocked blocked=1 moved=0 classification=blocked_only`
    - all three remain route-context evidence only for now
  - route progress after those detours:
    - reroute crossed row 11 cleanly through
      `(7,11) -> (8,11) -> (9,11) -> (10,11) -> (11,11)`
    - next fresh frontier became `(11,11)->RIGHT` into `(12,11)`
    - battle interrupted that seam before the retry result settled
  - stop condition:
    - Drollmagi battle started at `POSITION map=0x1A x=11 y=11`
    - HP at battle start was `70 / 70`
    - no further route commands were queued into combat
  - best next live step:
    - after the battle, re-baseline with
      `report_position report_runtime_blocks report_path_state`
    - if runtime blocks somehow fell out again, reseed from the updated
      handoff list
    - then run `probe_edge_verify:11,11,RIGHT,5`
    - if it moves, go back to `debug_pathfind_to:10,9` and `auto_walk:10,9`

- 2026-06-02 post-Drollmagi continuation:
  - fresh direct confirmation:
    - `probe_edge_verify:11,11,RIGHT,5` finished
      `attempts=6 moved=6 blocked=0 classification=confirmed_passable
      stability_recheck=true`
    - treat `(12,11).west` as cleanly open
  - route effect of that passable seam:
    - from live `(12,11)`, `debug_pathfind_to:10,9` still preferred
      `Path: 4 west, 3 north, 2 east, 1 south`
    - live `auto_walk:10,9` followed that and again got pulled back into the
      old center loop rather than opening a direct east-side finish
    - no new code bug showed up in that bounce; it behaved like route evidence,
      not harness corruption
  - west/lower pocket cleanup after that bounce:
    - `probe_edge_verify:7,11,UP,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
      for `(7,10).south`
    - promoted with `add_blocked_edge:7,11,UP`
      (merged into existing cell `(7,10)`, so runtime cell count did not rise)
    - `probe_edge_verify:6,11,LEFT,5` =>
      `moved=1 blocked=4 classification=inconclusive_teleport_artifact`
      with `teleport_artifact_suspected=true`
    - interpret `(5,11).east` as likely passable / not safe to promote blocked
    - `probe_edge_verify:6,11,DOWN,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
      for `(6,12).north`
    - promoted with `add_blocked_edge:6,11,DOWN`
  - runtime-set consequence:
    - after adding `(6,12).north`, `report_runtime_blocks` rose to
      `RUNTIME_BLOCKS map=0x1A count=21`
    - important live rows now include:
      - `(7,10)` with `dirs=east,south`
      - new cell `(6,12)` with `dirs=north`
  - planner shift after the two clean promotions:
    - from live `(6,11)`, `debug_pathfind_to:10,9` changed to
      `Path: 2 east, 3 north, 2 east, 1 south`
    - this is the first clean route family change from that lower-left stop in
      a while, so the blocker promotions were actually useful
  - live continuation under the 21-edge set:
    - `auto_walk:10,9` moved cleanly `(6,11)->(7,11)->(8,11)->(8,10)`
    - it was then attempting `(8,10)->UP` into `(8,9)` when combat fired
    - because `(8,10)->UP` has already moved repeatedly across many runs, do
      not treat the interruption itself as new seam evidence
  - stop condition:
    - Wraith Knight battle started at `POSITION map=0x1A x=8 y=10`
    - HP at battle start was `63 / 70`
    - no further route commands were queued into combat
  - best next live step:
    - after the battle, re-baseline with
      `report_position report_runtime_blocks report_path_state`
    - if the 21-edge runtime set is still present, rerun
      `debug_pathfind_to:10,9` and then `auto_walk:10,9`
    - if runtime blocks have dropped, reseed from the updated handoff list

- 2026-06-02 late-morning natural-probe breakthrough on `(9,8).west`:
  - battle after the row-12 sweep resolved cleanly:
    - Druinlord defeated for `+20 EXP`, `+73 GOLD`
    - fresh baseline came back at
      `POSITION map=0x1A x=9 y=11`,
      `RUNTIME_BLOCKS map=0x1A count=21`,
      `PATH_STATE target=nil map=0x1A runtime_count=21`
  - row-12 strip cleanup:
    - `probe_edge_verify:9,11,DOWN,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
      for `(9,12).north`
    - promoted with `add_blocked_edge:9,11,DOWN`
    - runtime set rose to `count=22`
    - planner from live `(9,11)` still wanted the center family:
      `debug_pathfind_to:10,9` => `Path: 1 west, 3 north, 2 east, 1 south`
  - contradiction-resolution test design:
    - instead of another teleport-based verifier on `(8,8)->RIGHT`, used a
      natural route:
      - `auto_walk:8,8` from live `(9,11)` reached `(8,8)` cleanly via
        `(8,11) -> (8,10) -> (8,9) -> (8,8)`
      - then issued a single-step live `probe_edge:RIGHT`
  - key result:
    - live non-teleport `probe_edge:RIGHT` from `(8,8)` blocked on the seam
      into `(9,8)`
    - log:
      `EDGE_PROBE_RESULT map=0x1A from=(8,8) dir=right dest=(9,8) status=blocked ... reason=raw_hold_timeout`
    - this matched the repeated natural autowalk seam-retry failures and broke
      the old tie with the teleported direct verifier result
  - promotion:
    - promoted `add_blocked_edge:8,8,RIGHT`
    - runtime set rose to `RUNTIME_BLOCKS map=0x1A count=23`
  - planner effect:
    - from live `(8,8)`, `debug_pathfind_to:10,9` changed sharply from the old
      short center route to:
      `Path: 4 south, 6 east, 3 north, 4 west`
    - this is the strongest evidence yet that the center knot was genuinely
      depending on the `(9,8).west` contradiction
  - live continuation under the 23-edge set:
    - `auto_walk:10,9` followed the new long family and did not immediately
      fall back into the old short contradiction
    - it strengthened the row-12 south strip instead:
      - `(13,12).north` => `blocked=3 moved=0 classification=blocked_only`
      - `(12,12).north` => `blocked=3 moved=0 classification=blocked_only`
      - `(11,12).north` => `blocked=2 moved=0 classification=blocked_only`
      - `(10,12).north` was in progress when combat fired
  - stop condition:
    - battle started at `POSITION map=0x1A x=10 y=11`
    - HP at battle start was `65 / 70`
    - no further route commands were queued into combat
  - best next live step:
    - after the battle, re-baseline with
      `report_position report_runtime_blocks report_path_state`
    - if the 23-edge set is still present, run
      `probe_edge_verify:10,11,DOWN,5`
    - if that confirms, continue marching west/east across the row-12 strip as
      needed: `11,11->DOWN`, then `12,11->DOWN`, then `13,11->DOWN`

- 2026-06-02 noon row-12 strip closure and upper-left reroute:
  - fresh baseline after the user-cleared fight:
    - `POSITION map=0x1A(Garin's Grave B3) x=10 y=11`
    - `RUNTIME_BLOCKS map=0x1A count=23`
    - `PATH_STATE target=nil map=0x1A runtime_count=23`
  - direct strip cleanup:
    - `probe_edge_verify:10,11,DOWN,5` =>
      `EDGE_VERIFY_RESULT ... moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:10,11,DOWN`
    - runtime set rose to `count=24`
    - planner from live `(10,11)` changed to
      `Path: 3 east, 1 south, 1 east, 3 north, 4 west`
    - `auto_walk:10,9` under the 24-edge set:
      - moved cleanly `(10,11)->(11,11)->(12,11)->(13,11)`
      - `(13,11)->DOWN` strengthened to
        `blocked=4 moved=0 classification=blocked_only`
      - `(12,11)->DOWN` strengthened to
        `blocked=4 moved=0 classification=blocked_only`
      - `(11,11)->DOWN` strengthened to
        `blocked=3 moved=0 classification=blocked_only`
      - `(8,11)->DOWN` later strengthened to
        `blocked=4 moved=0 classification=blocked_only`
      - route then cycled enough that it was better to stop autowalk and turn
        those into direct verifier checks
  - follow-up direct verifier chain:
    - `probe_edge_verify:11,11,DOWN,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:11,11,DOWN`
    - runtime set rose to `count=25`
    - planner from live `(11,11)` changed to
      `Path: 2 east, 1 south, 1 east, 3 north, 4 west`
    - `probe_edge_verify:13,11,DOWN,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:13,11,DOWN`
    - runtime set rose to `count=26`
    - planner from live `(13,11)` changed to
      `Path: 1 west, 1 south, 2 east, 3 north, 4 west`
    - `probe_edge_verify:12,11,DOWN,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:12,11,DOWN`
    - runtime set rose to `count=27`
    - planner from live `(12,11)` changed to
      `Path: 4 west, 1 south, 6 east, 3 north, 4 west`
    - `probe_edge_verify:8,11,DOWN,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:8,11,DOWN`
    - runtime set rose to `count=28`
    - planner from live `(8,11)` changed to
      `Path: 3 west, 5 north, 5 east, 3 south`
  - interpretation:
    - row 12 is now heavily closed from the north side:
      - existing: `(6,12).north`, `(9,12).north`
      - newly promoted: `(8,12).north`, `(10,12).north`,
        `(11,12).north`, `(12,12).north`, `(13,12).north`
    - the lower/right south strip no longer looks like the main bridge
    - the new route family now points back toward the upper-left pocket
  - unresolved contradiction to validate live later:
    - `debug_pathfind_to:10,9` from live `(8,11)` now says
      `Path: 3 west, 5 north, 5 east, 3 south`
    - this appears to route through the upper-left branch even though the
      runtime set already includes `(5,11).north`
    - do not patch code or promote more blockers from that alone; validate the
      live branch after combat with another planner run and/or autowalk
  - live continuation under the 28-edge set:
    - `auto_walk:10,9` from live `(8,11)` started the new branch
    - moved cleanly `(8,11)->(7,11)`
    - then hit a timing retry on `(7,11)->LEFT` into `(6,11)`, but that seam
      has already moved repeatedly from natural arrival and should still be
      treated as passable, not blocker evidence
    - battle fired before the route reached the upper-left turn point
  - stop condition:
    - `EVENT: battle started`
    - battle snapshot shows `pos: x=7, y=11`
    - enemy was a Druinlord
    - HP at battle start was `66 / 70`
    - no further route commands were queued into combat
  - best next live step:
    - after combat, re-baseline with
      `report_position report_runtime_blocks report_path_state`
    - if the `count=28` runtime set survived, rerun
      `debug_pathfind_to:10,9` and `auto_walk:10,9`
    - if the same `3 west, 5 north, 5 east, 3 south` planner family still
      shows up, validate whether the route actually tries `(5,11)->UP` or
      reroutes earlier before promoting anything else

- 2026-06-02 afternoon fresh-reset bridge recross and top-strip cleanup:
  - fresh return after user refresh:
    - `LAUNCHER_PROBE: codex_b3_resume_0602` matched cleanly
    - baseline came back at
      `POSITION map=0x1A(Garin's Grave B3) x=2 y=17`
      with `RUNTIME_BLOCKS map=0x1A none`
    - re-seeded the full proven B3 runtime set from handoff
    - `report_runtime_blocks` returned `count=28`
    - `debug_pathfind_to:10,9` from that southwest-side start still said
      `No path found`
  - bridge recross sequence:
    - `debug_pathfind_to:3,14` => `Path: 1 north, 1 east, 2 north`
    - `auto_walk:3,14` reached `(3,14)` cleanly
    - `probe_edge_verify:3,14,RIGHT,5` =>
      `moved=6 blocked=0 classification=suspect_passable_model_mismatch`
    - immediate `probe_edge:UP` from `(4,14)` =>
      `status=moved final=(4,13)`
    - this reconfirms the southwest hidden bridge as the working bridged-side
      entry after a fresh reset
  - planner after recross:
    - from live `(4,13)`, `debug_pathfind_to:10,9` changed to
      `Path: 7 north, 6 east, 3 south`
    - this supersedes the earlier southwest-side `No path found` result; the
      route is alive again once the bridge is crossed
  - live autowalk harvest on the bridged-side family:
    - clean natural movement advanced through
      `(4,13)->(4,12)->(4,11)->(4,10)->(4,9)->(4,8)->(4,7)->(4,6)`
    - reroute then climbed across the top strip through
      `(5,6)->(6,6)->(6,5)->(6,4)->(7,4)->(8,4)->(9,4)->(8,4)->(8,3)->(6,4)->(6,3)`
    - route-context-only blocked seams that emerged during that run:
      - `(7,6).west` from `(6,6)->RIGHT`
      - `(7,5).north` from `(7,4)->DOWN`
      - `(9,3).south` from `(9,4)->UP`
      - `(9,3).west` from `(8,3)->RIGHT`
      - `(6,2).south` from `(6,3)->UP`
      - `(5,3).east` from `(6,3)->LEFT`
    - note:
      - `(7,4)->LEFT` into `(6,4)` self-disproved and moved on seam retry
      - `(6,5)->DOWN` into `(6,6)` was interrupted by combat much later and
        should not be treated as blocker evidence because earlier route motion
        already crossed `(6,6)` cleanly
  - direct verifier cleanup on the strongest top-left pair:
    - `probe_edge_verify:6,3,LEFT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:6,3,LEFT`
    - `probe_edge_verify:6,3,UP,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:6,3,UP`
    - runtime set rose to `RUNTIME_BLOCKS map=0x1A count=30`
  - route effect of those promotions:
    - from live `(6,3)`, `debug_pathfind_to:10,9` shortened sharply to
      `Path: 3 south, 4 east, 3 south`
    - this is the strongest route simplification since the row-12 strip closed
  - live continuation under the 30-edge set:
    - `auto_walk:10,9` followed the shorter family cleanly
    - moved `(6,3) -> (6,4) -> (6,5)`
    - battle interrupted during the seam retry for `(6,5)->DOWN` into `(6,6)`
  - stop condition:
    - Specter battle started at `POSITION map=0x1A x=6 y=5`
    - HP at battle start was `70 / 70`
    - no further route commands were queued into combat
  - best next live step:
    - after combat, re-baseline with
      `report_position report_runtime_blocks report_path_state`
    - if the `count=30` runtime set survived, rerun
      `debug_pathfind_to:10,9` and then `auto_walk:10,9`
    - if the route still says `3 south, 4 east, 3 south`, let it run before
      promoting anything else
    - if it stalls again, the strongest unresolved top-strip candidates are
      `(7,6).west`, `(7,5).north`, and the two-sided `(9,3)` seam

- 2026-06-02 later-afternoon cleanup around `(4,6)` and `(6,5)`:
  - resumed while autowalk was still running and collecting route-context
    blocker evidence
  - first diagnostic conclusion:
    - no code/harness bug showed up in this batch
    - `AUTO_WALK_TEMP_BLOCK` entries kept clearing when seams moved, so this
      behaved like legitimate map evidence, not stale temp-block contamination
  - direct checks on the strongest `(4,6)` pair:
    - `probe_edge_verify:4,6,UP,5` =>
      `moved=6 blocked=0 classification=confirmed_passable`
    - this disproves `(4,5).south` as a blocker; earlier route-context
      `blocked_only` there was a false lead
    - `probe_edge_verify:4,6,LEFT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:4,6,LEFT`
    - runtime set rose to `count=31`
    - from live `(4,6)`, planner tightened to
      `Path: 6 east, 3 south`
  - live continuation under the 31-edge set:
    - autowalk cleanly moved through `(5,6)` and `(6,6)`
    - strongest route-context candidates then became:
      - `(7,6).west` from `(6,6)->RIGHT`, climbing to
        `blocked=6 moved=0 classification=blocked_only`
      - `(7,5).north` from `(7,4)->DOWN`, climbing to
        `blocked=8 moved=0 classification=blocked_only`
      - the upper `(9,3)` seam remained suspicious from both south and west,
        but was weaker than the `x=7` pair for immediate cleanup
  - direct checks on the `(6,5)/(6,6)` pair:
    - `probe_edge_verify:6,6,RIGHT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:6,6,RIGHT`
    - `probe_edge_verify:6,5,RIGHT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:6,5,RIGHT`
    - runtime set rose to `RUNTIME_BLOCKS map=0x1A count=32`
  - route effect of the two new west-side blockers:
    - from live `(6,5)`, `debug_pathfind_to:10,9` became
      `Path: 1 north, 1 east, 2 south, 3 east, 3 south`
    - follow-up autowalk held that route family
    - it re-entered the upper corner around `(7,4) -> (8,4) -> (9,4)` rather
      than collapsing outright, which means the route is still alive
  - what remains unresolved after this pass:
    - `(7,5).north` is still only route-context evidence; it now has the
      strongest repeated blocked-only count in the batch
    - `(9,3)` still has route-context blocked evidence from both south and west
      but has not yet had a direct verifier rerun in this pass
  - stop condition:
    - combat interrupted while the route was alive
    - `EVENT: battle started` at `POSITION map=0x1A x=8 y=3`
    - enemy was a Drollmagi
    - no further route commands were queued into combat
  - best next live step:
    - after combat, re-baseline with
      `report_position report_runtime_blocks report_path_state`
    - if the `count=32` runtime set survived, rerun
      `debug_pathfind_to:10,9` and `auto_walk:10,9`
    - strongest direct cleanup after that is
      `probe_edge_verify:7,4,DOWN,5`
    - secondary follow-up is `probe_edge_verify:9,4,UP,5`

- 2026-06-02 late-afternoon normalized retest overturns old `(4,6)->UP` passable result:
  - current question:
    - was the older `probe_edge_verify:4,6,UP,5 => confirmed_passable` result
      real map truth, or stale movement/camera state contamination?
  - fresh live/raw A/B from normalized `(4,6)`:
    - baseline:
      - `teleport_to:4,6 report_position` =>
        `POSITION map=0x1A(Garin's Grave B3) x=4 y=6`
    - direct single probe:
      - `probe_edge:UP` =>
        `EDGE_PROBE_RESULT ... status=blocked final=(4,6) ... reason=raw_hold_timeout`
      - mismatch was again
        `EDGE_PROBE_MODEL_MISMATCH ... kind=blocked_despite_open_preview`
    - direct verifier rerun:
      - `probe_edge_verify:4,6,UP,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - all five attempts were `reason=raw_hold_timeout`
      - all five attempts logged the same mismatch
        `blocked_despite_open_preview`
    - raw-controls arbiter:
      - `teleport_to:4,6 report_position`
      - `simulate_raw_input:UP,90`
      - `report_position report_coords`
      - result stayed at `(4,6)` with
        `COORDS ... effective=(4,6) player=(4,6) overworld=(4,4) raw003C_0043=7F 90 04 CB 96 91 04 05`
  - interpretation:
    - this matches the older archived hidden-state family where a seam once
      appeared passable under stale state, but normalized raw controls showed
      the true blocked behavior
    - treat the old `confirmed_passable` read on `(4,6)->UP` / `(4,5).south`
      as contaminated, not durable
    - under the current fully normalized raw-control evidence,
      `(4,5).south` is a real blocker
  - promotion and route effect:
    - `add_blocked_edge:4,6,UP report_runtime_blocks` =>
      `RUNTIME_BLOCKS map=0x1A count=33`
    - `debug_pathfind_to:10,9` from live `(4,6)` changed to
      `Path: 2 east, 2 north, 1 east, 2 south, 3 east, 3 south`
    - `auto_walk:10,9` then moved cleanly:
      - `(4,6) -> (5,6) -> (6,6)`
      - `(5,6)->RIGHT` hit a timing retry but seam-retry moved through `(6,6)`,
        so `(6,6).west` is still open
      - next step `(6,6)->UP` into `(6,5)` hit a timing retry and battle
        interrupted before the seam retry could resolve
  - current stop condition:
    - `EVENT: battle started`
    - battle snapshot:
      - `map_id: 0x1A (Garin's Grave B3)`
      - `pos: x=6, y=6`
      - enemy was a Wolflord
      - HP at battle start was `66 / 70`
    - no follow-up commands were queued into combat
  - best next live step after combat:
    - `report_position report_runtime_blocks report_path_state`
    - if the `count=33` runtime set survived, rerun
      `debug_pathfind_to:10,9` and `auto_walk:10,9`
    - if it stalls immediately, first local direct cleanup is
      `probe_edge_verify:6,6,UP,5`

- 2026-06-02 late-afternoon lower-left continuation from live `(4,11)`:
  - fresh post-combat baseline:
    - `report_position` =>
      `POSITION map=0x1A(Garin's Grave B3) x=4 y=11`
    - `report_runtime_blocks report_path_state` =>
      `RUNTIME_BLOCKS map=0x1A count=33`
      `PATH_STATE target=nil map=0x1A runtime_count=33`
  - fresh planner from the battle-stop side:
    - `debug_pathfind_to:10,9` =>
      `Path: 1 south, 10 east, 3 north, 4 west`
    - this was the first clean sign that the lower-left pocket might still be
      usable even with the 33-edge set in place
  - live autowalk harvest:
    - `auto_walk:10,9`
    - first seam:
      - `(4,11)->DOWN` into `(4,12)` timed out once as a queued step
      - seam retry completed cleanly
      - `SEAM_OBSERVATION map=0x1A cell=(4,12) approach=north result=moved blocked=0 moved=6 classification=passable_only`
    - second seam:
      - `(4,12)->RIGHT` into `(5,12)` failed on seam retry
      - `SEAM_OBSERVATION map=0x1A cell=(5,12) approach=west result=blocked blocked=3 moved=0 classification=blocked_only`
      - this is new strong route-context evidence, but not yet direct-verifier proof
    - third seam:
      - reroute tried `(4,12)->DOWN` into `(4,13)`
      - seam retry completed cleanly
      - `SEAM_OBSERVATION map=0x1A cell=(4,13) approach=north result=moved blocked=0 moved=4 classification=passable_only`
    - fourth seam:
      - `(4,13)->RIGHT` into `(5,13)` failed on seam retry
      - `SEAM_OBSERVATION map=0x1A cell=(5,13) approach=west result=blocked blocked=3 moved=0 classification=blocked_only`
  - route evolution:
    - after `(5,12).west`, planner rerouted through
      `Path: 1 south, 1 east, 1 north, 9 east, 3 north, 4 west`
    - after `(5,13).west`, planner pivoted harder to
      `Path: 7 north, 2 east, 2 north, 1 east, 2 south, 3 east, 3 south`
    - that new family then walked cleanly back up the left side:
      - `(4,13)->(4,12)->(4,11)->(4,10)->(4,9)->(4,8)->(4,7)->(4,6)`
    - from live `(4,6)`, seam-retry followup recovered the old short family:
      - `Path: 2 east, 2 north, 1 east, 2 south, 3 east, 3 south`
      - so the lower-left detour did not replace the shorter `(4,6)` route; it
        just exposed two new left-strip suspects on the way
  - interpretation:
    - treat `(4,12)` and `(4,13)` as newly re-confirmed passable cells
    - strongest new unresolved candidates are:
      - `(5,12).west` from `(4,12)->RIGHT`
      - `(5,13).west` from `(4,13)->RIGHT`
    - both are now worth direct verification before returning to wider
      planner-driven harvesting
  - stop condition:
    - battle interrupted during the resumed short-family attempt from `(4,6)`
    - `EVENT: battle started`
    - snapshot:
      - `map_id: 0x1A (Garin's Grave B3)`
      - `pos: x=4, y=6`
      - enemy was a Specter
      - HP at battle start was `70 / 70`
    - no further commands were queued into combat
  - best next live step after the Specter:
    - `report_position report_runtime_blocks report_path_state`
    - if `count=33` survived, first direct cleanup is
      `probe_edge_verify:4,12,RIGHT,5`
    - second direct cleanup is `probe_edge_verify:4,13,RIGHT,5`
    - if either confirms, inject it and rerun `debug_pathfind_to:10,9`
    - if both fail to confirm, fall back to `debug_pathfind_to:10,9` and
      `auto_walk:10,9` from live `(4,6)`

- 2026-06-02 late-afternoon direct verifier cleanup of the top-strip false leads:
  - lower-left seam cleanup results:
    - `probe_edge_verify:4,12,RIGHT,5` =>
      `moved=2 blocked=3 classification=inconclusive_teleport_artifact`
    - attempts 1 and 2 moved cleanly into `(5,12)`, then later teleported
      retries blocked with `blocked_despite_open_preview`
    - keep `(5,12).west` out of the runtime set for now
    - `probe_edge_verify:4,13,RIGHT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:4,13,RIGHT`
    - runtime set rose to `count=34`
  - strongest old route-context blockers were then checked directly:
    - `probe_edge_verify:7,4,DOWN,5` =>
      `moved=6 blocked=0 classification=confirmed_passable`
    - this fully disproves `(7,5).north` as a blocker
    - route-context `blocked_only` counts there were harness/noise, not map truth
    - `probe_edge_verify:9,4,UP,5` =>
      `moved=6 blocked=0 classification=confirmed_passable`
    - this fully disproves `(9,3).south` as a blocker too
    - the natural blocked counts on `(9,3)` from south and west were again
      route-context false leads
  - sibling west/east seams were more trustworthy:
    - `probe_edge_verify:6,4,LEFT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:6,4,LEFT`
    - runtime set rose to `count=35`
    - `probe_edge_verify:6,5,LEFT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:6,5,LEFT`
    - runtime set rose to `count=36`
  - route effects after the real promotions:
    - after `(5,4).east` was added:
      - `debug_pathfind_to:10,9` from live `(6,4)` =>
        `Path: 1 east, 2 south, 3 east, 3 south`
      - this is the cleanest short family seen so far on the bridged side
    - after `(5,5).east` was added:
      - `debug_pathfind_to:10,9` from live `(6,5)` =>
        `Path: 1 north, 1 east, 2 south, 3 east, 3 south`
      - live autowalk seam-retried through `(6,4)` and recovered the shorter
        9-step family again
  - live continuation under the 36-edge set:
    - `auto_walk:10,9` from `(6,5)`:
      - `(6,5)->UP` seam-retry moved cleanly into `(6,4)`
      - route at `(6,4)` re-tightened to
        `Path: 1 east, 2 south, 3 east, 3 south`
      - battle interrupted during the next queued right step retry into `(7,4)`
  - interpretation:
    - current durable result is not "top strip fully blocked"
    - instead:
      - `(7,5).north` is passable under direct verify
      - `(9,3).south` is passable under direct verify
      - `(5,4).east` is blocked
      - `(5,5).east` is blocked
    - the route-context seam harvester was useful for finding the neighborhood,
      but not for deciding which top-strip seams were actually real blockers
  - stop condition:
    - `EVENT: battle started`
    - battle snapshot:
      - `map_id: 0x1A (Garin's Grave B3)`
      - `pos: x=6, y=4`
      - enemy was a Drollmagi
      - HP at battle start was `70 / 70`
    - no follow-up commands were queued into combat
  - best next live step after the Drollmagi:
    - `report_position report_runtime_blocks report_path_state`
    - if `count=36` survived, rerun `debug_pathfind_to:10,9`
    - then `auto_walk:10,9` from live `(6,4)`
    - keep `(5,12).west` unpromoted unless a non-teleport/live check settles it

- 2026-06-02 evening live seam reversals and new B3 promotions:
  - stale-log safety check first:
    - `--require-live 10` refused because `dw_debug.log` had gone idle for
      about 70 seconds
    - plain `report_position` then matched cleanly, so the script was alive and
      simply idle on field rather than crashed
    - baseline after that check:
      - `POSITION: map=0x1A(Garin's Grave B3) x=8 y=4`
      - `RUNTIME_BLOCKS map=0x1A count=37`
      - `PATH_STATE target=nil map=0x1A runtime_count=37`
  - first resumed route under the 37-edge set:
    - `debug_pathfind_to:10,9` from `(8,4)` =>
      `Path: 1 west, 2 south, 3 east, 3 south`
    - natural autowalk re-entered `(7,4)` cleanly from the east, then a
      Wolflord interrupted the first fresh south attempt
  - local cleanup around `(7,4)->DOWN`:
    - after battle, live `probe_edge:DOWN` from `(7,4)` blocked:
      - `status=blocked`
      - `directional_blocked=true`
      - `blocked_approach=north`
      - `effective_passable=true`
      - `reason=raw_hold_timeout`
    - the important nuance there was:
      - `runtime_approach_blocked=false`
      - the cell had unrelated runtime directions, not a stale south temp block
    - `simulate_raw_input:DOWN,90` from live `(7,4)` also stayed at `(7,4)`
    - fresh verifier rerun then settled the seam cleanly:
      - `probe_edge_verify:7,4,DOWN,5`
      - `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:7,4,DOWN`
    - runtime count stayed `37` because `(7,5)` already existed with
      `east,west`
    - this overturns the earlier stale passable read on `(7,5).north`
  - route effect after `(7,5).north` promotion:
    - from live `(7,4)`, planner changed to
      `Path: 2 east, 1 north, 1 east, 6 south`
    - autowalk then bounced through `(9,4)` and exposed two stronger frontiers:
      - `(5,12).west` from the lower-left loop
      - `(9,3).west` from the top strip
  - confirming `(4,10)->DOWN` was not a blocker:
    - after a Druinlord interruption at `(4,10)`, live `probe_edge:DOWN`
      moved cleanly into `(4,11)`
    - treat that seam as passable even if route retries there look ugly later
  - lower-left seam finally settled:
    - natural autowalk hit `(4,12)->RIGHT` into `(5,12)` twice as clean
      `blocked_only` seam-retry evidence
    - fresh direct verifier:
      - `probe_edge_verify:4,12,RIGHT,5`
      - `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:4,12,RIGHT`
    - runtime set rose to `count=38`
    - planner from `(4,12)` changed to
      `Path: 6 north, 2 east, 3 north, 4 east, 6 south`
  - top-strip west-side seam also settled:
    - natural autowalk under the count-38 set hit `(8,3)->RIGHT` into `(9,3)`
      as clean `blocked_only`
    - direct verifier:
      - `probe_edge_verify:8,3,RIGHT,5`
      - `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:8,3,RIGHT`
    - runtime set rose to `RUNTIME_BLOCKS map=0x1A count=39`
  - strongest route change after count 39:
    - current live stop before the last battle was actually `(8,3)`
      after `stop_auto_walk`
    - `debug_pathfind_to:10,9` from live `(8,3)` =>
      `Path: 1 south, 1 east, 1 north, 1 east, 6 south`
    - this is the shortest family seen after the upper-strip promotions
  - what still refuses to settle:
    - despite confirmed `(9,3).west`, the route from `(8,3)` still reaches
      `(9,4)->UP` and keeps returning
      `SEAM_OBSERVATION cell=(9,3) approach=south result=blocked blocked=15 moved=1 classification=noisy`
    - so `(9,3)` is now asymmetric in the evidence:
      - west approach is confirmed blocked
      - south approach is still noisy and unresolved
  - latest clean-field baseline:
    - after the Drollmagi, a fresh read-only batch landed:
      - `POSITION: map=0x1A(Garin's Grave B3) x=8 y=4`
      - `RUNTIME_BLOCKS map=0x1A count=39`
      - `PATH_STATE target=nil map=0x1A runtime_count=39`
    - no follow-up movement was queued after that baseline
  - best next clean-field resume:
    - `report_position report_runtime_blocks report_path_state`
    - if `count=39` survived:
      - `debug_pathfind_to:10,9`
      - `auto_walk:10,9`
      - then, if the route again stalls at `(9,4)->UP`, run
        `probe_edge_verify:9,4,UP,5`

- 2026-06-02 late-evening natural re-approach after mixed `(9,4)->UP` verifier:
  - exact mixed verifier result:
    - `probe_edge_verify:9,4,UP,5`
    - `moved=1 blocked=4 classification=inconclusive_teleport_artifact`
    - this is not safe blocker evidence for `(9,3).south`
  - stopping the bouncing route showed the detour was temporary:
    - `stop_auto_walk report_position report_runtime_blocks report_path_state`
      landed at:
      - `POSITION: map=0x1A(Garin's Grave B3) x=4 y=12`
      - `RUNTIME_BLOCKS map=0x1A count=39`
      - `PATH_STATE target=nil map=0x1A runtime_count=39`
    - the temporary left-column seam spam did not survive into the runtime set
  - stable planner after the stop:
    - `debug_pathfind_to:10,9` from live `(4,12)` =>
      `Path: 6 north, 2 east, 2 north, 3 east, 1 north, 1 east, 6 south`
    - this confirmed the earlier swirl was route-temp contamination, not a new
      permanent collapse
  - most useful new live validation:
    - natural path to `(9,4)` is now fully proven from the lower-left stop
    - `debug_pathfind_to:9,4` from `(4,12)` =>
      `Path: 6 north, 2 east, 2 north, 3 east`
    - `auto_walk:9,4` then advanced cleanly through:
      - `(4,12) -> (4,11) -> (4,10) -> (4,9) -> (4,8) -> (4,7) -> (4,6)`
      - `(5,6) -> (6,6) -> (6,5) -> (6,4) -> (7,4) -> (8,4)`
      - seam-retry reached live `(9,4)` from `(8,4)`
    - every one of those seam retries cleared behind itself; no new durable
      blocker emerged on the re-approach
  - latest stop condition:
    - immediately after arrival at `(9,4)`, a Specter battle started:
      - `POSITION map=0x1A(Garin's Grave B3) x=9 y=4`
      - HP `66 / 70`
      - MP `27 / 57`
    - autowalk target was only `Tile 9,4`
    - no raw `UP` probe was sent before combat
  - best next clean-field resume:
    - clear the Specter
    - `report_position report_runtime_blocks report_path_state`
    - if still at live `(9,4)`:
      - `probe_edge:UP report_position`
      - then `simulate_raw_input:UP,90 report_position`
    - only if those natural checks are still ambiguous:
      - rerun `probe_edge_verify:9,4,UP,5`

- 2026-06-02 late-evening natural south-approach resolution plus left-column
  runtime promotions:
  - after the Specter, the old mixed `(9,4)->UP` story was resolved with
    natural movement instead of another teleport-heavy verifier:
    - live `probe_edge:UP report_position` from `(9,4)` blocked in place
    - follow-up `simulate_raw_input:UP,90 report_position` also stayed at
      `(9,4)`
    - this is stronger than the older stale direct-passable read and lines up
      with the newer asymmetry around `(9,3)`
    - promoted with `add_blocked_edge:9,4,UP`
    - runtime set stayed at `count=39` because `(9,3)` already existed with
      `west`; the new durable truth is `(9,3).south,west`
  - route effect after adding `(9,3).south`:
    - `debug_pathfind_to:10,9` from live `(9,4)` rerouted through a left-side
      family instead of the old short center/top loop
    - strongest new knot was around `(5,6)`
  - natural cleanup of the `(5,6)` vertical pair:
    - route evidence had already strengthened:
      - `(5,6)->UP` into `(5,5)` to `blocked=13 moved=0`
      - `(5,6)->DOWN` into `(5,7)` to `blocked=9 moved=0`
    - live controls from actual `(5,6)` then settled both:
      - `probe_edge:UP` blocked
      - `simulate_raw_input:UP,90` stayed at `(5,6)`
      - promoted with `add_blocked_edge:5,6,UP`
      - `probe_edge:DOWN` blocked
      - `simulate_raw_input:DOWN,90` stayed at `(5,6)`
      - promoted with `add_blocked_edge:5,6,DOWN`
    - runtime set still stayed at `count=39` because both additions merged into
      already-known blocker cells:
      - `(5,5)` gained `south`
      - `(5,7)` gained `north`
  - new left-column family exposed under the stronger `(5,6)` model:
    - natural autowalk then strengthened:
      - `(4,8)->LEFT` into `(3,8)` to clean `blocked_only`
      - `(4,7)->LEFT` into `(3,7)` to clean `blocked_only`
    - exact direct cleanup:
      - `probe_edge_verify:4,8,LEFT,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:4,8,LEFT`
      - runtime set rose to `count=40`
      - `probe_edge_verify:4,7,LEFT,5` =>
        `moved=0 blocked=5 classification=confirmed_blocked`
      - promoted with `add_blocked_edge:4,7,LEFT`
      - runtime set rose to `count=41`
  - latest clean baseline after the left-column promotions:
    - `POSITION: map=0x1A(Garin's Grave B3) x=4 y=7`
    - `RUNTIME_BLOCKS map=0x1A count=41`
    - `PATH_STATE target=nil map=0x1A runtime_count=41`
  - latest planner snapshot:
    - `debug_pathfind_to:10,9` from live `(4,7)` =>
      `Path: 2 south, 1 west, 4 north, 2 east, 4 north, 5 east, 8 south`
    - `visited=135 path=26`
  - working interpretation:
    - the earlier mixed teleported verifier on `(9,4)->UP` was real noise, but
      the natural raw south-approach check was enough to settle the seam
    - the current active frontier has shifted to the left column around
      `(3,7..10)`, not the old upper-right ambiguity
    - strongest next sibling is `(4,9)->LEFT` into `(3,9)`

- 2026-06-02 late-evening left-column strip closure and hidden-bridge pivot:
  - direct left-column sibling cleanup kept confirming one row at a time:
    - `probe_edge_verify:4,9,LEFT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:4,9,LEFT`
    - runtime set rose to `count=42`
    - planner from live `(4,9)` became
      `Path: 1 south, 1 west, 5 north, 2 east, 4 north, 5 east, 8 south`
    - `probe_edge_verify:4,10,LEFT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:4,10,LEFT`
    - runtime set rose to `count=43`
    - planner from live `(4,10)` became
      `Path: 1 south, 1 west, 6 north, 2 east, 4 north, 5 east, 8 south`
    - `probe_edge_verify:4,11,LEFT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:4,11,LEFT`
    - runtime set rose to `count=44`
    - planner from live `(4,11)` became
      `Path: 1 south, 1 west, 7 north, 2 east, 4 north, 5 east, 8 south`
    - `probe_edge_verify:4,12,LEFT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:4,12,LEFT`
    - runtime set rose to `count=45`
    - planner from live `(4,12)` became
      `Path: 1 south, 1 west, 8 north, 2 east, 4 north, 5 east, 8 south`
    - `probe_edge_verify:4,13,LEFT,5` =>
      `moved=0 blocked=5 classification=confirmed_blocked`
    - promoted with `add_blocked_edge:4,13,LEFT`
    - runtime set rose to `count=46`
  - the important collapse happened exactly there:
    - from live `(4,13)`, `debug_pathfind_to:10,9` =>
      `No path found [no_path] (visited=33 path=0)`
    - `debug_pathfind_to_skip_npcs:10,9` matched exactly:
      `No path found [no_path] (visited=33 path=0)`
    - `npc_count=0`, so this is not a live-NPC or planner-mode mismatch
  - frontier analysis after the collapse:
    - `debug_route_frontier_skip_npcs:10,9` still found a rich boundary:
      - `reachable=27`
      - `target_reachable=false`
      - `bridge_candidates=35`
      - `hidden_bridge_candidates=2`
    - best candidates:
      - rank 1:
        `(8,3)->UP` with `hidden_bridge=true hidden_exit=up:(8,1)`
      - rank 2:
        `(7,3)->UP` with `hidden_bridge=true hidden_exit=up:(7,1)`
    - top non-hidden blocked-runtime frontier still includes:
      - `(9,5)->DOWN`
      - `(9,5)->RIGHT`
      - `(8,5)->DOWN`
      - `(9,4)->RIGHT`
      - `(6,6..9)->RIGHT`
      - but the hidden-bridge pair is the cleaner next pivot
  - live attempt to pivot toward rank 1 candidate:
    - `debug_pathfind_to:8,3` from live `(4,13)` =>
      `Path: 7 north, 2 east, 3 north, 2 east`
    - `auto_walk:8,3` started following that route cleanly:
      - `(4,13) -> (4,12) -> (4,11) -> (4,10) -> (4,9) -> (4,8) -> (4,7)`
    - the next step `(4,7)->UP` into `(4,6)` hit a timing retry and was then
      interrupted by battle before seam retry resolved
  - current stop condition:
    - Wolflord battle started at
      `POSITION: map=0x1A(Garin's Grave B3) x=4 y=7`
    - HP `70 / 70`
    - MP `23 / 57`
    - queued autowalk target was `Tile 8,3`
  - updated interpretation:
    - the x=3 east-facing strip is effectively sealed from `(3,7)` through
      `(3,13)` under direct verifier evidence
    - the current 46-edge model makes the lower B4 stair unreachable from the
      present component by ordinary planning
    - the strongest next live test is now a natural hidden-bridge probe at
      `(8,3)->UP`, with `(7,3)->UP` as immediate fallback

- 2026-06-02 night pass after the hidden-bridge pivot:
  - first hidden-bridge candidate settled hard-blocked:
    - from live `(8,3)`, natural `probe_edge:UP` into `(8,2)` blocked
      immediately
    - the model already said `tile=1 base_walkable=false`, and the raw probe
      agreed
    - `simulate_raw_input:UP,90 report_position` also left the hero at `(8,3)`
  - second hidden-bridge family also failed under natural live checks:
    - `probe_edge:LEFT` from `(8,3)` into `(7,3)` blocked despite an
      open-preview model (`blocked_despite_open_preview`)
    - `simulate_raw_input:LEFT,90` also stayed at `(8,3)`
    - route to `(7,4)` was clean:
      - `debug_pathfind_to:7,4` => `Path: 1 south, 1 west`
      - `auto_walk:7,4` reached live `(7,4)`
    - from `(7,4)`, natural `probe_edge:UP` into `(7,3)` blocked with the same
      open-preview mismatch
    - `simulate_raw_input:UP,90` from `(7,4)` also stayed at `(7,4)`
    - promoted runtime edges:
      - `add_blocked_edge:8,3,UP`
      - `add_blocked_edge:8,3,LEFT`
      - `add_blocked_edge:7,4,UP`
    - runtime set rose to `count=48`
  - important frontier nuance:
    - even after those promotions, `debug_route_frontier_skip_npcs:10,9`
      continues to rank:
      - `(8,3)->UP`
      - `(7,3)->UP`
    - cause is frontier scoring on hidden/not-walkable bridge candidates, not
      ordinary runtime-block suppression
    - practical conclusion: ignore those two as dead for current live reasoning
  - upper-right pocket sanity checks all agreed with the runtime set:
    - route to `(9,5)` remained clean
    - `probe_edge:DOWN` from `(9,5)` into `(9,6)` blocked with
      `directional_blocked=true approach_blocked=true effective_passable=false`
    - `probe_edge:RIGHT` from `(9,5)` into `(10,5)` blocked with the same
      clean runtime-backed shape
    - route to `(8,5)` remained clean
    - `probe_edge:DOWN` from `(8,5)` into `(8,6)` also blocked exactly as
      modeled
  - near-target left-family sanity checks also agreed with runtime:
    - route to `(6,6)` remained clean
    - `probe_edge:RIGHT` from `(6,6)` into `(7,6)` blocked exactly as modeled
    - route to `(6,9)` remained clean
    - `probe_edge:RIGHT` from `(6,9)` into `(7,9)` blocked exactly as modeled
    - `probe_edge:DOWN` from `(6,9)` into `(6,10)` blocked exactly as modeled
  - newest unresolved local lead surfaced while complement-checking `6,10`:
    - `debug_pathfind_to:5,10` from `(6,9)` =>
      `Path: 1 west, 1 south`
    - `auto_walk:5,10` reached `(5,9)` cleanly
    - the seam retry into `(5,10)` from the north did not resolve:
      - `SEAM_OBSERVATION map=0x1A cell=(5,10) approach=north result=blocked blocked=1 moved=0 classification=blocked_only`
    - reroute started to swing through `(4,9)->DOWN`, but battle interrupted
      before that seam resolved
  - current stop:
    - battle started at `POSITION: map=0x1A(Garin's Grave B3) x=4 y=9`
    - HP `70 / 70`
    - MP `23 / 57`
    - queued autowalk target was `Tile 5,10`
  - working interpretation:
    - the x=3 strip is sealed, the hidden-bridge pair appears dead under
      natural controls, and the upper-right pocket is consistent with runtime
    - the best remaining cheap challenge to the current model is
      `(5,10).north` via natural checks from live `(5,9)`

- 2026-06-02 late-night continuation after the `5,10` chase:
  - natural cleanup confirmed the north side of `(5,10)` is a real blocker:
    - `probe_edge:DOWN` from `(5,9)` into `(5,10)` blocked with
      `tile=2 base_walkable=true walkable=true directional_blocked=false`
      and `EDGE_PROBE_MODEL_MISMATCH kind=blocked_despite_open_preview`
    - `simulate_raw_input:DOWN,90 report_position` stayed at `(5,9)`
    - promoted with `add_blocked_edge:5,9,DOWN`
    - `report_runtime_blocks` then showed
      `RUNTIME_BLOCKS map=0x1A count=49`
      because `(5,10).north` merged into an existing blocker cell
    - local planner check after promotion:
      - `debug_pathfind_to:5,10` from `(5,9)` =>
        `Path: 1 west, 1 south, 1 east`
  - west-side reroute then resolved the sibling seam cleanly:
    - `auto_walk:5,10` moved `(5,9)->LEFT` and `(4,9)->DOWN` cleanly:
      - `SEAM_OBSERVATION cell=(4,9) approach=east result=moved`
      - `SEAM_OBSERVATION cell=(4,10) approach=north result=moved`
    - the final step `(4,10)->RIGHT` into `(5,10)` failed twice on seam retry:
      - `SEAM_OBSERVATION cell=(5,10) approach=west result=blocked blocked=2 moved=0 classification=blocked_only`
    - direct natural cleanup from `(4,10)`:
      - `probe_edge:RIGHT` blocked with
        `directional_blocked=true`
        `runtime_directional_blocked=true`
        `kind=blocked_despite_open_preview`
      - `simulate_raw_input:RIGHT,90 report_position` stayed at `(4,10)`
    - promoted with `add_blocked_edge:4,10,RIGHT`
    - runtime set still stayed at `count=49` because `(5,10).west` merged into
      the same blocker cell
    - planner after the west-side promotion:
      - `debug_pathfind_to:10,9` from `(4,10)` =>
        `No path found [no_path] (visited=31 path=0)`
      - frontier still over-reported hidden bridges, which made the tooling bug
        reproducible enough to patch
  - resumed the frontier challenge from the Wraith Knight stop:
    - post-battle baseline:
      - `POSITION: map=0x1A(Garin's Grave B3) x=5 y=6`
      - `PATH_STATE target=nil map=0x1A runtime_count=49`
    - `debug_pathfind_to:7,3` from `(5,6)` =>
      `Path: 1 east, 3 north, 1 east`
    - autowalk reached `(6,3)` cleanly through
      `(6,6) -> (6,5) -> (6,4) -> (6,3)`
    - the final step `(6,3)->RIGHT` into `(7,3)` failed repeatedly:
      - first seam-reroute pass raised it to
        `blocked=4 moved=0 classification=blocked_only`
      - second seam-reroute pass raised it to
        `blocked=5 moved=0 classification=blocked_only`
    - direct natural cleanup from `(6,3)`:
      - `probe_edge:RIGHT` blocked with
        `tile=0 base_walkable=true walkable=true directional_blocked=true`
        and `EDGE_PROBE_MODEL_MISMATCH kind=blocked_despite_open_preview`
      - `simulate_raw_input:RIGHT,90 report_position` stayed at `(6,3)`
    - promoted with `add_blocked_edge:6,3,RIGHT`
    - runtime set still stayed at `count=49` because `(7,3).west` merged into
      existing blocker cell `(7,3)` which already had `east,south`
  - planner/frontier state after the top-strip promotion:
    - `debug_pathfind_to:10,9` from live `(6,3)` =>
      `No path found [no_path] (visited=25 path=0)`
    - `debug_route_frontier_skip_npcs:10,9` =>
      `reachable=25 target_reachable=false bridge_candidates=32 hidden_bridge_candidates=1`
    - the only remaining hidden-bridge candidate is
      `(8,3)->UP` even though that exact edge is already runtime-blocked and
      experimentally dead
  - tooling bug and patch:
    - root cause:
      - `run_debug_route_frontier` classified non-walkable frontier cells as
        plain `not_walkable` before consulting exact runtime/directional edge
        blockers, so already-dead hidden-wall edges could still bubble up as
        `hidden_bridge=true`
    - fix:
      - added `route_frontier_classifier.lua`
      - added `test_route_frontier_classifier.lua`
      - changed `main.lua` so frontier candidates now preserve an exact
        `blocked_runtime` or `blocked_directional` reason even when the
        destination cell itself is not walkable
      - hidden-bridge probing now only runs when the candidate is truly
        `not_walkable` without an exact edge blocker
    - focused validation:
      - `lua5.1 test_route_frontier_classifier.lua` => pass
      - `luac5.1 -p route_frontier_classifier.lua test_route_frontier_classifier.lua main.lua` => pass
    - live follow-up still pending:
      - FCEUX needs a manual `main.lua` reload before the patched
        `debug_route_frontier_skip_npcs` output can be trusted

- 2026-06-02 post-reload live verification of the frontier fix:
  - manual FCEUX reload succeeded and the field resumed on `map=0x1A`
  - first post-reload baseline from live `(6,3)` came back with
    `RUNTIME_BLOCKS map=0x1A none`, so the runtime seam set had to be reseeded
  - first reseed attempt exposed a handoff-list omission:
    - the documented reseed batch rebuilt only `runtime_count=47`
    - under that incomplete set, `debug_pathfind_to:10,9` reopened to
      `Path: 2 south, 1 west, 4 north, 5 east, 8 south`
    - `debug_route_frontier_skip_npcs:10,9` also reopened to
      `reachable=345 target_reachable=true hidden_bridge_candidates=2`
      with fake hidden-bridge entries around `(7,2)`
    - exact missing directions on existing cells were:
      - `(5,5).east` via `add_blocked_edge:6,5,LEFT`
      - `(5,7).west` via `add_blocked_edge:4,7,RIGHT`
  - after adding those two missing reseed commands:
    - `RUNTIME_BLOCKS map=0x1A count=49`
    - `PATH_STATE target=nil map=0x1A runtime_count=49`
    - `debug_pathfind_to:10,9` from `(6,3)` returned to
      `No path found [no_path] (visited=25 path=0)`
    - `debug_route_frontier_skip_npcs:10,9` settled to
      `reachable=25 target_reachable=false bridge_candidates=31 hidden_bridge_candidates=0`
  - key live verification of the code patch:
    - the old ghost hidden bridge `(8,3)->UP` no longer appears as a
      `hidden_bridge=true` candidate after reload
    - the top-ranked frontier entries are now plain runtime blockers:
      - rank 1 `(9,5)->DOWN`
      - rank 2 `(9,5)->RIGHT`
      - rank 3 `(8,5)->DOWN`
  - fresh live challenge on that top-ranked family after reload:
    - baseline survived manual walk to `(9,5)` with `runtime_count=49`
    - natural `probe_edge:DOWN` from `(9,5)` into `(9,6)` blocked cleanly:
      - `directional_blocked=true`
      - `approach_blocked=true`
      - `effective_passable=false`
      - no open-preview mismatch
    - natural `probe_edge:RIGHT` from `(9,5)` into `(10,5)` also blocked
      cleanly with the same runtime-backed shape
    - `debug_pathfind_to:8,5` from `(9,5)` found `Path: 1 west`
    - `auto_walk:8,5` reached `(8,5)` cleanly
    - natural `probe_edge:DOWN` from `(8,5)` into `(8,6)` then blocked
      cleanly with `directional_blocked=true`
  - present interpretation:
    - the frontier-report hidden-bridge bug is fixed live, not just in unit
      tests
    - the full 49-edge runtime set now reconstructs the intended sealed B3
      state
    - the current top frontier family is already cleanly confirmed blocked, so
      there is no obvious next local seam to promote from this component

- 2026-06-02 code/data sync pass after the frontier fix:
  - clarified the B4 stair names in `objects.lua` without changing the actual
    pairing:
    - `(0,4)` -> `West Return Stairs to B3`
    - `(5,4)` -> `East Return Stairs to B3`
    - B3 `(9,5)` and `(10,9)` keep the established `Upper` / `Lower Stairs
      Down to B4` names
  - promoted the stable 49-edge B3 runtime reseed into the permanent
    `map_reader.lua` directional block table
    - this adds the later proven bridge-strip, top-pocket, and lower-stair
      approach blockers that had still been living only in the reseed batch
    - mixed/unresolved seams like `(5,15).west` remain deliberately unmodeled
  - focused verification:
    - `lua5.1 test_objects.lua`
    - `lua5.1 test_map_reader.lua`
    - `luac5.1 -p objects.lua map_reader.lua test_objects.lua test_map_reader.lua`
    - `python3 run_tests.py --allow-missing-speech-dep`
    - `git diff --check -- objects.lua map_reader.lua test_objects.lua test_map_reader.lua`

- 2026-06-02 late-night live pass after the permanent B3 sync:
  - fresh reload baseline:
    - `POSITION: map=0x1A(Garin's Grave B3) x=4 y=13`
    - `RUNTIME_BLOCKS map=0x1A none`
    - `PATH_STATE target=nil map=0x1A runtime_count=0`
  - the user's `(4,13).south` observation is fully consistent with live logs:
    - earlier natural move `(4,14)->UP` had already entered `(4,13)` from the
      south
    - this pass later natural-rerouted back into `(4,13)` from the north
      during autowalk, so `(4,13)` is now evidenced as a two-way passable hinge
  - planner effect from live `(4,13)` with only permanent blockers active:
    - `debug_pathfind_to:10,9` =>
      `Path: 1 east, 1 north, 9 east, 3 north, 4 west`
    - `debug_pathfind_to:2,17` =>
      `Path: 3 east, 4 south, 5 west`
    - this means the new hinge does both:
      - reopen a live route toward the lower B4 stair
      - reopen a return route toward the B2 southwest stair
  - first autowalk harvest toward `(10,9)` from `(4,13)`:
    - the direct east exit failed first:
      - `SEAM_OBSERVATION map=0x1A cell=(5,13) approach=west result=blocked`
      - later strengthened to `blocked=2 moved=0 classification=blocked_only`
    - reroute then moved cleanly up the entire column:
      - `(4,13)->(4,12)->(4,11)->(4,10)->(4,9)->(4,8)->(4,7)->(4,6)`
      - continued through `(5,6)->(6,6)->(6,5)->(6,4)`
    - second local candidate appeared at the top strip:
      - `SEAM_OBSERVATION map=0x1A cell=(5,4) approach=east result=blocked`
      - currently only `blocked=1 moved=0 classification=blocked_only`
    - relaxing that top-strip temp block sent the route back through the lower
      loop, confirming more open travel through `(6,9)`, `(5,9)`, `(4,9)`, and
      back down to `(4,13)`
    - the route then re-hit `(5,13).west` and again settled blocked-only,
      pushing it to `blocked=2 moved=0`
  - latest interruption:
    - while re-walking back to `(4,13)` for the next direct seam check,
      `auto_walk:4,13` was interrupted by a Wraith Knight at:
      - `POSITION: map=0x1A(Garin's Grave B3) x=4 y=10`
      - HP `67 / 70`
      - MP `47 / 57`
    - no further movement was queued after battle start
  - current best next step after combat:
    - `report_position report_runtime_blocks report_path_state`
    - `auto_walk:4,13`
    - once live at `(4,13)`, run `probe_edge_verify:4,13,RIGHT,5`
  - secondary follow-up if `(5,13).west` confirms:
    - rerun `debug_pathfind_to:10,9` / `auto_walk:10,9`
  - alternate direct cleanup if the route stalls near the top strip instead:
    - `probe_edge_verify:6,4,LEFT,5` for `(5,4).east`

## 2026-06-05 B3 lower-B4 continuation from SW B2 stairs

- Fresh continuation target stayed B3 lower stairs down to B4 at `(10,9)`.
- Initial live baseline had no B3 runtime blockers, and the planner still
  found a route from `(4,10)`:
  `3 south, 1 east, 1 north, 9 east, 3 north, 4 west`.
- Live autowalk exposed two clean missing opposite approaches:
  - `(4,13)->RIGHT` into `(5,13)` blocked naturally, then
    `probe_edge_verify:4,13,RIGHT,5` confirmed blocked 5/5.
    Promoted permanently as `(5,13).west`.
  - `(6,4)->LEFT` into `(5,4)` blocked naturally, then
    `probe_edge_verify:6,4,LEFT,5` confirmed blocked 5/5.
    Promoted permanently as `(5,4).east`.
- After adding both as runtime blocks, from `(6,4)`:
  - `debug_pathfind_to:10,9` and skip-NPC variant both returned `No path found`
  - frontier report was `reachable=25 target_reachable=false
    hidden_bridge_candidates=0`
  - top bridge candidates were the two new runtime blocks plus existing static
    blockers around `(9,5)`.
- Sanity rechecks of the highest static frontier exits:
  - first `probe_edge_verify:9,5,DOWN,5` was mixed
    (`moved=5 blocked=1`) after stale input/Alt noise; treated as
    contaminated, not as opening evidence.
  - after `./recover_fceux_input.sh`, `probe_edge_verify:9,5,DOWN,8`
    confirmed blocked 8/8.
  - `probe_edge_verify:9,5,RIGHT,5` confirmed blocked 5/5.
- Current live state after final baseline:
  - `POSITION map=0x1A x=9 y=5`
  - `RUNTIME_BLOCKS map=0x1A count=2`: `(5,4).east`, `(5,13).west`
  - `PATH_STATE target=nil map=0x1A runtime_count=2`
- Important reload note:
  - `map_reader.lua` is patched, but the running FCEUX Lua instance has not
    reloaded it; keep the two runtime blocks seeded until reload/relaunch.
- Current conclusion:
  - local seam hunting from this component is at a stop condition. The newly
    exposed route is sealed by two direct-confirmed missing blockers, and the
    nearest existing top exits from `(9,5)` reconfirm blocked under clean input.

## 2026-06-05 B2 southwest stair route follow-up

- User-completed route reached the correct object:
  - `POSITION map=0x19 x=1 y=10`
  - `OBJECT: Southwest Stairs Down to B3: here`
- Route noise focused on `(13,9)->LEFT` into `(12,9)`:
  - explicit-origin verifier from the stair was mixed:
    `moved=1 blocked=4 classification=inconclusive_teleport_artifact`
  - same-origin raw `probe_edge:LEFT` from live `(13,9)` blocked
  - same-origin `probe_edge_verify:LEFT,5` from live `(13,9)` confirmed blocked
    5/5 with no drift, map change, interruption, or teleport-artifact flag
- Promoted permanent B2 data:
  - `(12,9).east=true` in `MAP_DIRECTIONAL_BLOCKS[0x19]`
  - regression added to `garins_grave_b2_southwest_stair_route_edges_are_directional`
- Runtime also seeded for current FCEUX session:
  - `add_blocked_edge:25,13,9,LEFT`
  - `RUNTIME_BLOCK map=0x19 x=12 y=9 dirs=east`
- Hero restored to the target stair after investigation:
  - `POSITION map=0x19 x=1 y=10`
  - `OBJECT: Southwest Stairs Down to B3: here`

## 2026-06-05 route-turn movement reset stat-corruption repro

- User intentionally set `auto_step_reset_movement_on_route_turn_settle=true`
  after the Silver Harp route to test the old suspect.
- The next B2 autowalk pass reproduced the stat corruption quickly:
  - `PLAYER_STAT_FRAMEADVANCE_TRANSITION from=clean to=bad`
  - `pre_frame=72173 post_frame=72174`
  - map `0x19`, position `(7,4)`
  - changed bytes: `C8,C9,CA,CB,CC,CD,CE`
  - clean stats `70/70 HP`, `55/57 MP`, STR/AGI/ATK/DEF `34/2B/48/39`
  - corrupt stats `70/15 HP`, `55/0 MP`, STR/AGI/ATK/DEF `04/03/18/25`
- The transition landed immediately after queued route turn settle:
  - `auto_step route turn settle prev=up next=right frames=16`
- User won the battle, set the option back to false, and reloaded the script.
- Post-reload baseline with false was clean:
  - `POSITION map=0x19 x=7 y=4`
  - `RUNTIME_BLOCKS map=0x19 none`
  - `hp=70/70`, `mp=39/57`, stats `34/2B/48/39`, spells `CE=0x7F CF=0x10`
- Code safety patch made the risky behavior opt-in only:
  - `config.lua` generated default is now false
  - `auto_step.lua` missing-setting fallback is now false
  - `dw_access.ini` warning says true reproduced stat corruption in FCEUX
  - `test_config.lua` covers the config default
  - `test_auto_step.lua` covers the safe absent-setting fallback and explicit
    true opt-in behavior
- Cautious route pass after the false reload:
  - `auto_walk:1,10` queued from `(7,4)` toward the southwest B3 stair
  - no new stat-integrity warning appeared before battle
  - Wolf battle interrupted at `(3,6)` with clean stats
- Follow-up direct verifiers after combat:
  - `probe_edge_verify:3,4,LEFT,5` => `(2,4).east` confirmed blocked `5/5`
  - `probe_edge_verify:3,8,LEFT,5` => `(2,8).east` confirmed blocked `5/5`
  - `probe_edge_verify:3,7,LEFT,5` => `(2,7).east` confirmed blocked `5/5`
- Permanent B2 patch:
  - `MAP_DIRECTIONAL_BLOCKS[0x19]` now also closes `(2,4).east`,
    `(2,7).east`, and `(2,8).east`
  - `test_map_reader.lua` regression extended before patch, then passed after
    the map-data update
- Runtime reinjection for the current FCEUX session:
  - `add_blocked_edge:25,3,4,LEFT`
  - `add_blocked_edge:25,3,8,LEFT`
  - `add_blocked_edge:25,3,7,LEFT`
  - `RUNTIME_BLOCKS map=0x19 count=3`
  - `RUNTIME_BLOCK map=0x19 x=2 y=4 key=2,4 dirs=east`
  - `RUNTIME_BLOCK map=0x19 x=2 y=7 key=2,7 dirs=east`
  - `RUNTIME_BLOCK map=0x19 x=2 y=8 key=2,8 dirs=east`
- Hero restored after verifier pass:
  - `POSITION map=0x19(Garin's Grave B2) x=3 y=6`

## 2026-06-05 B2 mid-pocket loop cleanup near `(9,4)` / `(9,5)` / `(9,6)`

- User reported autowalk had collected another batch of blockers and was
  bouncing/looping on Garin's Grave B2.
- Fresh loop tail from `dw_debug.log` centered on:
  - `(9,6)->DOWN` into `(9,7)`
  - `(9,6)->LEFT` into `(8,6)`
  - `(9,6)->RIGHT` into `(10,6)`
  - `(9,5)->LEFT` into `(8,5)`
  - `(9,5)->RIGHT` into `(10,5)`
  - interrupted attempt `(9,4)->UP` into `(9,3)`
- Static/source check showed the current repo already blocked several of those
  approaches on B2, but live `inspect_move` on the running FCEUX Lua still
  previewed them all as open. That meant we needed live verifier proof instead
  of assuming the route loop was all geometry.
- Direct verifier results:
  - explicit-origin `probe_edge_verify:9,6,LEFT,5`
    => `moved=6 blocked=0 classification=confirmed_passable`
  - explicit-origin `probe_edge_verify:9,6,RIGHT,5`
    => `moved=6 blocked=0 classification=confirmed_passable`
  - explicit-origin `probe_edge_verify:9,6,DOWN,5`
    => mixed / `classification=inconclusive_teleport_artifact`
  - split `teleport_to:9,6` then same-origin `probe_edge_verify:DOWN,5`
    => `moved=0 blocked=5 classification=confirmed_blocked`
  - split `teleport_to:9,5` then same-origin `probe_edge_verify:LEFT,5`
    => `moved=0 blocked=5 classification=confirmed_blocked`
  - split `teleport_to:9,5` then same-origin `probe_edge_verify:RIGHT,5`
    => `moved=0 blocked=5 classification=confirmed_blocked`
  - split `teleport_to:9,4` then same-origin `probe_edge_verify:UP,5`
    => `moved=6 blocked=0 classification=confirmed_passable`
- Interpretation:
  - real B2 blockers:
    - `(8,5).east`
    - `(9,7).north`
    - `(10,5).west`
  - false-positive loop edges that must stay open:
    - `(8,6).east`
    - `(10,6).west`
    - `(9,3).south`
- TDD:
  - extended `garins_grave_b2_southwest_stair_route_edges_are_directional`
    with the three real blockers plus explicit nil assertions for the three
    reopened approaches
  - red run failed first on missing `(8,5).east`
  - corrected the B2 `0x19` map table only after that red failure
  - first green attempt accidentally touched the B3 table with overlapping
    coordinates; restored B3 and moved the fix to B2
  - final green run passed cleanly
- Permanent B2 patch:
  - added `(8,5).east`, `(9,7).north`, `(10,5).west`
  - kept `(8,6).east`, `(10,6).west`, `(9,3).south` open
- Runtime reinjection for current live FCEUX session:
  - `add_blocked_edge:25,9,6,DOWN`
  - `add_blocked_edge:25,9,5,LEFT`
  - `add_blocked_edge:25,9,5,RIGHT`
  - `RUNTIME_BLOCKS map=0x19 count=6`
  - runtime entries now include:
    - `(2,4).east`
    - `(2,7).east`
    - `(2,8).east`
    - `(8,5).east`
    - `(10,5).west`
    - `(9,7).north`
- Post-sync live planner sanity:
  - restored hero to `POSITION map=0x19(Garin's Grave B2) x=9 y=4`
  - `debug_pathfind_to:1,10`
    => `Path: 6 west, 2 south, 2 west, 4 south`

## 2026-06-05 B2 west-pocket and top-lip strip follow-up

- Starting point for this pass:
  - prior runtime set already included `(2,4).east`, `(2,7).east`,
    `(2,8).east`, `(8,5).east`, `(10,5).west`, and `(9,7).north`
  - live planner from `(8,4)` had tightened to:
    `Path: 5 west, 2 south, 2 west, 4 south`
- New west/top pocket verifier results:
  - `teleport_to:7,5` then same-origin `probe_edge_verify:RIGHT,5`
    => `(8,5).west` confirmed blocked `5/5`
  - `teleport_to:8,4` then same-origin `probe_edge_verify:DOWN,5`
    first stayed mixed with `teleport_artifact_suspected=true`
  - extra settle at live `(8,4)` then `probe_edge_verify:DOWN,8`
    => `(8,5).north` confirmed blocked `8/8`
  - `teleport_to:8,4` then same-origin `probe_edge_verify:UP,5`
    => `(8,3).south` confirmed blocked `5/5`
- Autowalk continuation after runtime injection:
  - route from `(8,4)` reached `(3,5)` before a Wolf battle
  - clean new route-shaped blocker at `(3,6)->LEFT` into `(2,6)` reached
    `blocked=4 moved=0`
  - direct follow-up `teleport_to:3,6` then `probe_edge_verify:LEFT,5`
    => `(2,6).east` confirmed blocked `5/5`
- Next autowalk pass with `(2,6).east` seeded exposed the upper-left band:
  - route-shaped failures:
    - `(3,5)->LEFT` into `(2,5)` => `blocked=4 moved=0`
    - `(3,4)->UP` into `(3,3)` => `blocked=4 moved=0`
    - `(4,4)->UP` into `(4,3)` => `blocked=4 moved=0`
    - `(5,4)->UP` into `(5,3)` => `blocked=4 moved=0`
    - `(6,4)->UP` into `(6,3)` => `blocked=3 moved=0`
    - `(7,4)->UP` into `(7,3)` had the same reroute pattern before stop
  - direct follow-up verifiers:
    - `teleport_to:3,5` then `probe_edge_verify:LEFT,5`
      => `(2,5).east` confirmed blocked `5/5`
    - `teleport_to:3,4` then `probe_edge_verify:UP,5`
      => `(3,3).south` confirmed blocked `5/5`
    - `teleport_to:4,4` then `probe_edge_verify:UP,5`
      => `(4,3).south` confirmed blocked `5/5`
    - `teleport_to:5,4` then `probe_edge_verify:UP,5`
      => `(5,3).south` confirmed blocked `5/5`
    - `teleport_to:6,4` then `probe_edge_verify:UP,5`
      => `(6,3).south` confirmed blocked `5/5`
    - live `(7,4)` then `probe_edge_verify:UP,5`
      => `(7,3).south` confirmed blocked `5/5`
- TDD / permanent model updates:
  - red assertions added first for:
    - `(8,5).west`, `(8,5).north`, `(8,3).south`
    - `(2,6).east`
    - `(2,5).east`
    - `(3,3).south` through `(7,3).south`
  - green update added those B2 `0x19` directional blocks to `map_reader.lua`
  - `test_map_reader.lua`, `luac5.1 -p`, and `git diff --check` all passed
- Runtime reinjection for current FCEUX session:
  - added:
    - `add_blocked_edge:25,7,5,RIGHT`
    - `add_blocked_edge:25,8,4,DOWN`
    - `add_blocked_edge:25,8,4,UP`
    - `add_blocked_edge:25,3,6,LEFT`
    - `add_blocked_edge:25,3,5,LEFT`
    - `add_blocked_edge:25,3,4,UP`
    - `add_blocked_edge:25,4,4,UP`
    - `add_blocked_edge:25,5,4,UP`
    - `add_blocked_edge:25,6,4,UP`
    - `add_blocked_edge:25,7,4,UP`
  - current runtime set:
    - `RUNTIME_BLOCKS map=0x19 count=14`
- Current live baseline after this pass:
  - `POSITION map=0x19(Garin's Grave B2) x=3 y=5`
  - `debug_pathfind_to:1,10`
    => `Path: 3 south, 5 east, 1 south, 7 west, 1 south`

## 2026-06-05 B2 east-pocket cleanup around `(10,4)` to `(12,6)`

- Starting point for this pass:
  - current live runtime set was still `RUNTIME_BLOCKS map=0x19 count=14`
  - field baseline recovered cleanly at `POSITION map=0x19 x=9 y=6`
  - fresh route-shaped seam hits from the latest autowalk cluster included:
    - `(11,6)->RIGHT` into `(12,6)` => blocked-only
    - `(11,6)->LEFT` into `(10,6)` => blocked-only
    - `(11,6)->DOWN` into `(11,7)` => blocked-only
    - `(11,5)->LEFT` into `(10,5)` => blocked-only
    - `(11,5)->RIGHT` into `(12,5)` => blocked-only
    - `(10,4)->DOWN` into `(10,5)` => blocked-only in route context
- Split direct verifier results:
  - `teleport_to:11,6` then same-origin `probe_edge_verify:RIGHT,5`
    => `EDGE_VERIFY_RESULT ... moved=0 blocked=5 classification=confirmed_blocked`
    so model `(12,6).west`
  - `teleport_to:11,6` then same-origin `probe_edge_verify:LEFT,5`
    => `EDGE_VERIFY_RESULT ... moved=0 blocked=5 classification=confirmed_blocked`
    so model `(10,6).east`
  - `teleport_to:11,6` then same-origin `probe_edge_verify:DOWN,5`
    => `EDGE_VERIFY_RESULT ... moved=0 blocked=5 classification=confirmed_blocked`
    so model `(11,7).north`
  - `teleport_to:11,5` then same-origin `probe_edge_verify:LEFT,5`
    => `EDGE_VERIFY_RESULT ... moved=0 blocked=5 classification=confirmed_blocked`
    so model `(10,5).east`
  - `teleport_to:11,5` then same-origin `probe_edge_verify:RIGHT,5`
    => `EDGE_VERIFY_RESULT ... moved=0 blocked=5 classification=confirmed_blocked`
    so model `(12,5).west`
  - `teleport_to:10,4` then same-origin `probe_edge_verify:DOWN,5`
    => `EDGE_VERIFY_RESULT ... moved=1 blocked=4 classification=inconclusive_teleport_artifact`
    with `first_attempt_status=moved` and `blocked_after_move=4`
- Fresh-start one-shot follow-up for the contaminated north face:
  - repeated three times:
    - `teleport_to:10,4` then `probe_edge:DOWN`
    - `teleport_to:10,4` then `probe_edge:DOWN`
    - `teleport_to:10,4` then `probe_edge:DOWN`
  - all three ended:
    - `EDGE_PROBE_RESULT map=0x19 from=(10,4) dir=down dest=(10,5) status=blocked final=(10,4) reached_dest=false ... reason=raw_hold_timeout`
  - treat `(10,5).north` as real engine blocking despite the repeated-verifier
    teleport artifact
- TDD / permanent model updates:
  - red assertions added first for:
    - `(10,5).east`
    - `(10,5).north`
    - `(10,6).east`
    - `(11,7).north`
    - `(12,5).west`
    - `(12,6).west`
  - green update added those six B2 `0x19` directional blocks to
    `map_reader.lua`
  - `lua5.1 test_map_reader.lua` and `luac5.1 -p map_reader.lua test_map_reader.lua`
    passed afterward
- Runtime reinjection for the current FCEUX session:
  - added:
    - `add_blocked_edge:25,11,6,RIGHT`
    - `add_blocked_edge:25,11,6,LEFT`
    - `add_blocked_edge:25,11,6,DOWN`
    - `add_blocked_edge:25,11,5,LEFT`
    - `add_blocked_edge:25,11,5,RIGHT`
    - `add_blocked_edge:25,10,4,DOWN`
  - resulting live runtime snapshot:
    - `RUNTIME_BLOCKS map=0x19 count=18`
    - `(10,5) dirs=east,north,west`
    - `(12,5) dirs=west`
    - `(10,6) dirs=east`
    - `(12,6) dirs=west`
    - `(11,7) dirs=north`
  - current hero location after sync:
    - `POSITION map=0x19(Garin's Grave B2) x=10 y=4`

## 2026-06-05 B2 west-strip cleanup from `(9,6)` through `(6,8)`

- Recheck of the user-reported manual blocker:
  - old note had treated `(9,6)->LEFT` into `(8,6)` as open from an earlier
    same-origin verifier, but the fresh live state contradicted it hard
  - fresh `probe_edge:LEFT` from `(9,6)` => blocked
  - same-origin `probe_edge_verify:LEFT,5` from live `(9,6)`
    => `moved=0 blocked=5 classification=confirmed_blocked`
  - split `teleport_to:9,6` then same-origin `probe_edge_verify:LEFT,5`
    => `moved=0 blocked=5 classification=confirmed_blocked`
  - reverse `teleport_to:8,6` then `probe_edge_verify:RIGHT,5`
    => `moved=6 blocked=0 classification=confirmed_passable`
  - promote `(8,6).east`; old open result is no longer trustworthy
- Runtime reinjection after that first promotion:
  - added `add_blocked_edge:25,9,6,LEFT`
  - live runtime count became `19`
  - planner from `(9,6)` rerouted to:
    `Path: 1 east, 3 south, 9 west, 1 south`
- Autowalk follow-up from `(7,8)` produced a west strip on the `x=8` column:
  - route-shaped candidates:
    - `(7,8)->RIGHT` into `(8,8)` => `blocked_only` in route context
    - `(7,7)->RIGHT` into `(8,7)` => `blocked_only`
    - `(7,6)->RIGHT` into `(8,6)` => `blocked_only`
  - direct checks:
    - `teleport_to:7,7` then `probe_edge_verify:RIGHT,5`
      => `(8,7).west` confirmed blocked `5/5`
    - `teleport_to:7,6` then `probe_edge_verify:RIGHT,5`
      => `(8,6).west` confirmed blocked `5/5`
    - `teleport_to:7,8` then `probe_edge_verify:RIGHT,5`
      => `moved=4 blocked=1 classification=inconclusive_teleport_artifact`
    - three fresh-start `teleport_to:7,8` then `probe_edge:RIGHT`
      => blocked all three times
    - reverse `teleport_to:8,8` then `probe_edge_verify:LEFT,5`
      => `moved=6 blocked=0 classification=confirmed_passable`
  - treat `(8,8).west` as real despite the mixed repeated verifier
- Another reroute higher up then exposed `(6,8)->UP` into `(6,7)`:
  - route-shaped read:
    - `SEAM_OBSERVATION map=0x19 cell=(6,7) approach=south result=blocked blocked=1 moved=0 classification=blocked_only`
  - repeated verifier:
    - `teleport_to:6,8` then `probe_edge_verify:UP,5`
      => `moved=4 blocked=1 classification=inconclusive_teleport_artifact`
  - fresh-start one-shot follow-up:
    - three separate `teleport_to:6,8` then `probe_edge:UP`
      => blocked all three times
    - reverse `teleport_to:6,7` then `probe_edge_verify:DOWN,5`
      => `moved=6 blocked=0 classification=confirmed_passable`
  - treat `(6,7).south` as real engine blocking
- Non-promoted / disproven neighbors from the same live passes:
  - `(10,6).west` stayed timing noise; do not promote
  - `(7,8).north` verified passable `6/6`; do not promote
  - `(7,7).south` was noisy (`blocked=1 moved=5`); do not promote
- TDD / permanent model updates:
  - red assertions added first for:
    - `(8,6).east`
    - `(8,6).west`
    - `(8,7).west`
    - `(8,8).west`
    - `(6,7).south`
  - green update added those five B2 `0x19` directional blocks to
    `map_reader.lua`
  - `lua5.1 test_map_reader.lua`, `luac5.1 -p map_reader.lua test_map_reader.lua`,
    and `git diff --check -- map_reader.lua test_map_reader.lua` all passed
- Runtime reinjection for the current FCEUX session:
  - added:
    - `add_blocked_edge:25,9,6,LEFT`
    - `add_blocked_edge:25,7,6,RIGHT`
    - `add_blocked_edge:25,7,7,RIGHT`
    - `add_blocked_edge:25,7,8,RIGHT`
    - `add_blocked_edge:25,6,8,UP`
  - resulting live runtime snapshot:
    - `RUNTIME_BLOCKS map=0x19 count=22`
    - `(6,7) dirs=south`
    - `(8,6) dirs=east,west`
    - `(8,7) dirs=west`
    - `(8,8) dirs=west`
  - current hero location after sync:
    - `POSITION map=0x19(Garin's Grave B2) x=6 y=8`
  - current planner state:
    - `debug_pathfind_to:1,10`
      => `Path: 1 east, 4 north, 2 east, 1 north, 8 west, 7 south`

## 2026-06-05 B2 final southwest-stair completion pass

- Important baseline change before the final pass:
  - after the most recent battle/reload cycle, live `report_runtime_blocks`
    came back `RUNTIME_BLOCKS map=0x19 none`
  - that means the next route checks were exercising the permanent B2 model
    without relying on the temporary runtime edge set
- Battle-interrupted false alarm cleanup:
  - route-shaped suspicion at `(6,11)->LEFT` into `(5,11)` did not hold up
  - same-origin `probe_edge_verify:LEFT,5` from live `(6,11)`
    => `moved=6 blocked=0 classification=confirmed_passable`
  - keep `(5,11).east` open
- Planner tightened dramatically after that check:
  - from live `(5,11)`, `debug_pathfind_to:1,10`
    => `Path: 4 west, 1 north`
- Final autowalk outcome:
  - `auto_walk:1,10` from `(5,11)` completed without finding a new blocker
  - logged moved seams on:
    - `(4,11)` approach east
    - `(3,11)` approach east
    - `(2,11)` approach east
    - `(1,11)` approach east
    - `(1,10)` approach south
  - completion marker:
    - `AUTO_WALK_NPC_PARK_RESTORE ... reason=autowalk route complete`
  - final live state:
    - `POSITION map=0x19(Garin's Grave B2) x=1 y=10`
    - `RUNTIME_BLOCKS map=0x19 none`
- Residual stale candidate from an earlier interrupted reroute:
  - `UNRESOLVED / DO NOT PROMOTE without fresh direct proof`
  - `(12,10)->LEFT` into `(11,10)` logged one `blocked_only` route hit during
    the stale `(13,10)` detour, but the route later completed without needing
    it and there is no direct verifier evidence yet

## 2026-06-05 B2 center-right strip cleanup from live `(10,8)` and `(8,8)`

- Fresh baseline after the user-reported blocker batch:
  - `report_position` => `POSITION map=0x19(Garin's Grave B2) x=10 y=8`
  - `report_path_state` / `report_runtime_blocks` => `runtime_count=0`
- Direct verifier batch from the row-8 center-right strip:
  - `probe_edge_verify:UP,5` from live `(10,8)`
    => `EDGE_VERIFY_RESULT ... dest=(10,7) moved=0 blocked=5 classification=confirmed_blocked`
  - `teleport_to:10,7` then `probe_edge_verify:DOWN,5`
    => `moved=6 blocked=0 classification=confirmed_passable`
    so model `(10,7).south`
  - `teleport_to:10,8` then `probe_edge_verify:DOWN,5`
    => `dest=(10,9) moved=0 blocked=5 classification=confirmed_blocked`
    so model `(10,9).north`
  - `teleport_to:9,8` then `probe_edge_verify:DOWN,5`
    => `dest=(9,9) moved=0 blocked=5 classification=confirmed_blocked`
    so model `(9,9).north`
  - `teleport_to:11,8` then `probe_edge_verify:DOWN,5`
    => `dest=(11,9) moved=0 blocked=5 classification=confirmed_blocked`
    so model `(11,9).north`
  - `teleport_to:12,8` then `probe_edge_verify:DOWN,5`
    => `dest=(12,9) moved=0 blocked=5 classification=confirmed_blocked`
    so model `(12,9).north`
  - `teleport_to:9,8` then `probe_edge_verify:UP,5`
    => `dest=(9,7) moved=0 blocked=5 classification=confirmed_blocked`
    so model `(9,7).south`
  - `teleport_to:11,8` then `probe_edge_verify:UP,5`
    => `dest=(11,7) moved=0 blocked=5 classification=confirmed_blocked`
    so model `(11,7).south`
  - `teleport_to:12,8` then `probe_edge_verify:UP,5`
    => `dest=(12,7) moved=0 blocked=5 classification=confirmed_blocked`
    so model `(12,7).south`
- Promoted into permanent B2 `0x19` data:
  - `(9,7).south`
  - `(10,7).south`
  - `(11,7).south`
  - `(12,7).south`
  - `(9,9).north`
  - `(10,9).north`
  - `(11,9).north`
  - `(12,9).north`
- Runtime reinjection for the current FCEUX session:
  - added:
    - `add_blocked_edge:25,9,8,UP`
    - `add_blocked_edge:25,10,8,UP`
    - `add_blocked_edge:25,11,8,UP`
    - `add_blocked_edge:25,12,8,UP`
    - `add_blocked_edge:25,9,8,DOWN`
    - `add_blocked_edge:25,10,8,DOWN`
    - `add_blocked_edge:25,11,8,DOWN`
    - `add_blocked_edge:25,12,8,DOWN`
  - `report_runtime_blocks` => `RUNTIME_BLOCKS map=0x19 count=8`
- Live planner sanity after reinjection:
  - from `(12,8)`, `debug_pathfind_to:1,10`
    => `Path: 4 west, 1 south, 7 west, 1 south`
- Follow-up autowalk / cleanup:
  - initial reroute noise made `(9,8)->LEFT` into `(8,8)` look suspicious, but
    direct same-origin `probe_edge_verify:LEFT,5` from `(9,8)` then moved `6/6`
    with stability recheck:
    - `EDGE_VERIFY_RESULT ... dest=(8,8) moved=6 blocked=0 classification=confirmed_passable`
    - keep `(8,8).east` open
    - log downgraded it to `SEAM_OBSERVATION ... cell=(8,8) approach=east ... classification=noisy`
  - from live `(8,8)`, `debug_pathfind_to:1,10`
    => `Path: 1 south, 7 west, 1 south`
  - next live `auto_walk:1,10` from `(8,8)` exposed one fresh candidate before
    rerouting away:
    - `(8,8)->DOWN` into `(8,9)` logged
      `SEAM_OBSERVATION ... cell=(8,9) approach=north result=blocked blocked=1 moved=0 classification=blocked_only`
    - later in that same reroute, a battle started at `(13,9)` and cancelled
      the autowalk
    - `UNRESOLVED / DO NOT PROMOTE without fresh direct proof`
    - next best verifier once back in field: `teleport_to:8,8` then
      `probe_edge_verify:DOWN,5`

## 2026-06-05 B2 `(8,8)<->(8,9)` seam settled; next candidate `(7,9).east`

- Requested direct follow-up from the earlier scratchpad candidate:
  - `teleport_to:8,8` then `probe_edge_verify:DOWN,5`
    => `EDGE_VERIFY_RESULT ... dest=(8,9) moved=2 blocked=3 classification=inconclusive_teleport_artifact`
  - attempt pattern from the log:
    - attempts 1 and 2 moved into `(8,9)`
    - attempts 3, 4, and 5 blocked at `raw_hold_timeout`
    - so the repeated verifier alone was still not enough to promote
- Fresh one-shot tiebreaker from the upper side:
  - three separate cycles of:
    - `teleport_to:8,8 report_position`
    - `probe_edge:DOWN`
  - all three ended:
    - `EDGE_PROBE_RESULT map=0x19 from=(8,8) dir=down dest=(8,9) status=blocked final=(8,8) reason=raw_hold_timeout`
- Reverse face check from the lower side:
  - `teleport_to:8,9` then `probe_edge_verify:UP,5`
    => `EDGE_VERIFY_RESULT ... dest=(8,8) moved=0 blocked=5 classification=confirmed_blocked`
- Promoted into permanent B2 `0x19` data:
  - `(8,8).south`
  - `(8,9).north`
- Runtime reinjection for the current FCEUX session:
  - added:
    - `add_blocked_edge:25,8,8,DOWN`
    - `add_blocked_edge:25,8,9,UP`
  - `report_runtime_blocks` => `RUNTIME_BLOCKS map=0x19 count=10`
  - live runtime now includes:
    - `(8,8) dirs=south`
    - `(8,9) dirs=north`
    - `(9,7) dirs=south`
    - `(10,7) dirs=south`
    - `(11,7) dirs=south`
    - `(12,7) dirs=south`
    - `(9,9) dirs=north`
    - `(10,9) dirs=north`
    - `(11,9) dirs=north`
    - `(12,9) dirs=north`
- Planner/autowalk follow-up after the patch:
  - from live `(8,9)`, `debug_pathfind_to:1,10`
    => `Path: 7 west, 1 south`
  - `auto_walk:1,10` then progressed cleanly:
    - `(8,10)` approach north moved
    - `(8,11)` approach north moved
    - `(7,11)` approach east moved
    - `(6,11)` approach east moved
    - `(5,11)` approach east moved
    - `(4,11)` approach east moved
    - `(3,11)` approach east moved
  - new route-shaped candidate before the battle interruption:
    - `(8,9)->LEFT` into `(7,9)` logged
      `SEAM_OBSERVATION ... cell=(7,9) approach=east result=blocked blocked=1 moved=0 classification=blocked_only`
    - later autowalk rerouted down through `(8,10)` / `(8,11)` and a battle
      started at `(3,11)`
    - `UNRESOLVED / DO NOT PROMOTE without fresh direct proof`
    - next best direct verifier after battle: `teleport_to:8,9` then
      `probe_edge_verify:LEFT,5`

## 2026-06-05 B2 west-strip continuation through `(5,9)<->(8,9)`

- Returned to the earlier unresolved `(8,9)->LEFT` seam after the battle:
  - `teleport_to:8,9` then `probe_edge_verify:LEFT,5`
    => `moved=3 blocked=2 classification=inconclusive_teleport_artifact`
  - attempt pattern from the log:
    - attempts 1-3 moved into `(7,9)`
    - attempts 4-5 blocked at `raw_hold_timeout`
  - fresh one-shot tiebreaker from the east side:
    - three separate cycles of `teleport_to:8,9` then `probe_edge:LEFT`
      all ended `EDGE_PROBE_RESULT ... status=blocked ... reason=raw_hold_timeout`
  - reverse face:
    - `teleport_to:7,9` then `probe_edge_verify:RIGHT,5`
      => `moved=0 blocked=5 classification=confirmed_blocked`
- Promoted into permanent B2 `0x19` data:
  - `(7,9).east`
  - `(8,9).west`
- TDD/implementation note:
  - initial regression-first patch surfaced a duplicate-key overwrite bug:
    a later `(7,9)` table entry shadowed the earlier `(7,9).north`
  - fixed by merging faces into one final `(7,9)` directional record instead
    of adding a separate later one
- Runtime reinjection after that pair:
  - added:
    - `add_blocked_edge:25,8,9,LEFT`
    - `add_blocked_edge:25,7,9,RIGHT`
  - `report_runtime_blocks` => `RUNTIME_BLOCKS map=0x19 count=11`
- Planner/autowalk follow-up:
  - from live `(7,9)`, `debug_pathfind_to:1,10`
    => `Path: 6 west, 1 south`
  - `auto_walk:1,10` then still completed to `(1,10)`, but it exposed the
    next west-strip seam:
    - `(7,9)->LEFT` into `(6,9)` logged
      `SEAM_OBSERVATION ... cell=(6,9) approach=east result=blocked blocked=1 moved=0 classification=blocked_only`
- Direct follow-up on `(7,9)->LEFT` into `(6,9)`:
  - repeated verifier:
    - `teleport_to:7,9` then `probe_edge_verify:LEFT,5`
      => `moved=1 blocked=4 classification=inconclusive_teleport_artifact`
  - fresh one-shot tiebreaker:
    - three separate `teleport_to:7,9` then `probe_edge:LEFT`
      all ended `EDGE_PROBE_RESULT ... status=blocked ... reason=raw_hold_timeout`
  - reverse face:
    - `teleport_to:6,9` then `probe_edge_verify:RIGHT,5`
      => `moved=0 blocked=5 classification=confirmed_blocked`
- Promoted into permanent B2 `0x19` data:
  - `(6,9).east`
  - `(7,9).west`
- Runtime reinjection after that pair:
  - added:
    - `add_blocked_edge:25,7,9,LEFT`
    - `add_blocked_edge:25,6,9,RIGHT`
  - `report_runtime_blocks` => `RUNTIME_BLOCKS map=0x19 count=12`
- Planner/autowalk follow-up:
  - from live `(6,9)`, `debug_pathfind_to:1,10`
    => `Path: 5 west, 1 south`
  - next `auto_walk:1,10` again completed to `(1,10)` and exposed the next
    west-strip seam:
    - `(6,9)->LEFT` into `(5,9)` logged
      `SEAM_OBSERVATION ... cell=(5,9) approach=east result=blocked blocked=1 moved=0 classification=blocked_only`
- Direct follow-up on `(6,9)->LEFT` into `(5,9)`:
  - repeated verifier:
    - `teleport_to:6,9` then `probe_edge_verify:LEFT,5`
      => `moved=1 blocked=4 classification=inconclusive_teleport_artifact`
  - fresh one-shot tiebreaker:
    - three separate `teleport_to:6,9` then `probe_edge:LEFT`
      all ended `EDGE_PROBE_RESULT ... status=blocked ... reason=raw_hold_timeout`
  - reverse face:
    - `teleport_to:5,9` then `probe_edge_verify:RIGHT,5`
      => `moved=0 blocked=5 classification=confirmed_blocked`
- Promoted into permanent B2 `0x19` data:
  - `(5,9).east`
  - `(6,9).west`
- Runtime reinjection after that pair:
  - added:
    - `add_blocked_edge:25,6,9,LEFT`
    - `add_blocked_edge:25,5,9,RIGHT`
  - `report_runtime_blocks` => `RUNTIME_BLOCKS map=0x19 count=13`
  - live runtime west strip now includes:
    - `(5,9) dirs=east`
    - `(6,9) dirs=east,west`
    - `(7,9) dirs=east,west`
    - `(8,9) dirs=north,west`
- Current stop after the last reseed:
  - `POSITION map=0x19(Garin's Grave B2) x=5 y=9`
  - `debug_pathfind_to:1,10`
    => `Path: 4 west, 1 south`
- Final repeat-autowalk sanity after the west-strip promotions:
  - another live `auto_walk:1,10` completed cleanly back to
    `POSITION map=0x19(Garin's Grave B2) x=1 y=10`
  - two intermediate left-step stalls looked suspicious but did not hold up as
    blocker evidence:
    - `(4,10)->LEFT` into `(3,10)` timed out on the first pass, then seam
      retry moved into `(3,10)`
    - `(2,11)->LEFT` into `(1,11)` timed out on the first pass, then seam
      retry moved into `(1,11)`
  - treat `(3,10).east` and `(1,11).east` as timing noise, not blockers

## 2026-06-05 B2 top-hook cleanup and northwest-pocket continuation

- User asked to review another stopped B2 autowalk that had bounced near the
  upper rows before battle noise was allowed to accumulate.
- First pass was the top-hook pocket around `(10..11,1..3)`:
  - route-shaped candidates from the stopped log:
    - `(10,2)->LEFT` into `(9,2)` => candidate `(9,2).east`
    - `(10,2)->DOWN` into `(10,3)` => candidate `(10,3).north`
    - `(11,2)->DOWN` into `(11,3)` => candidate `(11,3).north`
    - `(10,2)->UP` into `(10,1)` => candidate `(10,1).south`
    - `(11,1)->LEFT` into `(10,1)` => candidate `(10,1).east`
  - direct/live follow-up:
    - `teleport_to:10,2` then `probe_edge_verify:LEFT,5`
      => `(9,2).east` cleared cleanly; moved `6/6`
    - `teleport_to:10,2` then `probe_edge_verify:DOWN,5`
      was interrupted by battle after moving `3/3`
    - split one-shots on the same seam stayed contradictory:
      - from `(10,2)->DOWN`: one moved, then two blocked
      - reverse from `(10,3)->UP`: three blocked
      - leave `(10,3).north` / `(10,2).south` unmodeled for now
    - `teleport_to:11,2` then `probe_edge:DOWN`
      => moved into `(11,3)`; keep `(11,3).north` open
    - `teleport_to:11,1` then `probe_edge:LEFT`
      => moved into `(10,1)`; keep `(10,1).east` open
    - `teleport_to:10,2` then `probe_edge:UP`
      moved twice into `(10,1)`; keep `(10,1).south` open
- Because the planner from live `(10,1)` no longer depended on the
  contradictory `(10,2)<->(10,3)` seam, resumed route work from there:
  - `debug_pathfind_to:1,10`
    => `Path: 9 west, 9 south`
- The resumed northwest autowalk exposed a much cleaner B2 band:
  - route-shaped candidates:
    - `(3,1)->LEFT` into `(2,1)` => candidate `(2,1).east`
    - `(3,2)->LEFT` into `(2,2)` => candidate `(2,2).east`
    - `(3,2)->DOWN` into `(3,3)` => candidate `(3,3).north`
    - `(4,2)->DOWN` into `(4,3)` => candidate `(4,3).north`
    - `(5,2)->DOWN` into `(5,3)` => candidate `(5,3).north`
    - `(5,2)->UP` into `(5,1)` => candidate `(5,1).south`
    - `(4,2)->UP` into `(4,1)` was still in-flight when the route was halted,
      but the next resumed route immediately reproduced it
  - direct follow-up verifiers:
    - `teleport_to:3,2` then `probe_edge_verify:DOWN,5`
      => `(3,3).north` confirmed blocked `5/5`
    - `teleport_to:4,2` then `probe_edge_verify:DOWN,5`
      => `(4,3).north` confirmed blocked `5/5`
    - `teleport_to:5,2` then `probe_edge_verify:DOWN,5`
      => `(5,3).north` confirmed blocked `5/5`
    - `teleport_to:4,2` then `probe_edge_verify:UP,5`
      => `(4,1).south` confirmed blocked `5/5`
    - `teleport_to:5,2` then `probe_edge_verify:UP,5`
      => mixed (`moved=1 blocked=4 classification=inconclusive_teleport_artifact`)
    - stronger tiebreaker for `(5,1).south`:
      - three separate `teleport_to:5,2` then `probe_edge:UP`
        all blocked at `raw_hold_timeout`
      - reverse `teleport_to:5,1` then `probe_edge_verify:DOWN,5`
        moved `6/6`
      - promote only `(5,1).south`
    - `teleport_to:3,1` then `probe_edge_verify:LEFT,5`
      => mixed (`moved=1 blocked=4 classification=inconclusive_teleport_artifact`)
    - stronger tiebreaker for `(2,1).east`:
      - three separate `teleport_to:3,1` then `probe_edge:LEFT`
        all blocked at `raw_hold_timeout`
      - reverse `teleport_to:2,1` then `probe_edge_verify:RIGHT,5`
        moved `6/6`
      - promote only `(2,1).east`
    - `teleport_to:3,2` then `probe_edge_verify:LEFT,5`
      => `(2,2).east` confirmed blocked `5/5`
- TDD / permanent model updates:
  - red phase 1:
    - added failing B2 assertions for `(3,3).north`, `(4,3).north`,
      `(5,3).north`
    - `lua5.1 test_map_reader.lua` failed on `(3,3).north`
  - green phase 1:
    - added those three north faces to `MAP_DIRECTIONAL_BLOCKS[0x19]`
    - `lua5.1 test_map_reader.lua`, `luac5.1 -p`, and `git diff --check`
      passed
  - red phase 2:
    - added failing B2 assertions for `(2,1).east`, `(2,2).east`,
      `(4,1).south`, and `(5,1).south`
    - `lua5.1 test_map_reader.lua` failed on `(2,1).east`
  - green phase 2:
    - added those four faces to `MAP_DIRECTIONAL_BLOCKS[0x19]`
    - `lua5.1 test_map_reader.lua`, `luac5.1 -p`, and `git diff --check`
      passed again
- Runtime sync:
  - first reseed for the new north lip:
    - `add_blocked_edge:25,3,2,DOWN`
    - `add_blocked_edge:25,4,2,DOWN`
    - `add_blocked_edge:25,5,2,DOWN`
  - later reseed for the upper-row / west-pocket additions:
    - `add_blocked_edge:25,3,1,LEFT`
    - `add_blocked_edge:25,3,2,LEFT`
    - `add_blocked_edge:25,4,2,UP`
    - `add_blocked_edge:25,5,2,UP`
  - live readback after the second reseed:
    - `RUNTIME_BLOCKS map=0x19 count=7`
    - `(3,3).north`, `(4,3).north`, `(5,3).north`
    - `(2,1).east`, `(2,2).east`
    - `(4,1).south`, `(5,1).south`
- Live route follow-up after the second reseed:
  - `report_position`
    => `POSITION map=0x19(Garin's Grave B2) x=2 y=2`
  - `debug_pathfind_to:1,10`
    => `Path: 8 south, 1 west`
  - short follow-up `auto_walk:1,10` with the new runtime edges exposed the
    next unresolved route-shaped trio:
    - `(2,2)->DOWN` into `(2,3)` => candidate `(2,3).north`
    - `(2,2)->LEFT` into `(1,2)` => candidate `(1,2).east`
    - `(2,2)->UP` into `(2,1)` => candidate `(2,1).south`
  - current live stop after manual halt:
    - `POSITION map=0x19(Garin's Grave B2) x=3 y=1`
- One more resumed reroute check after that halt:
  - with the seven-edge runtime reseed active, the next reroute from `(3,1)`
    repeatedly stalled on `(3,1)->RIGHT` into `(4,1)`
  - direct follow-up:
    - same-origin `probe_edge_verify:RIGHT,5` from `(3,1)`
      => `(4,1).west` confirmed blocked `5/5`
  - TDD / permanent model update:
    - added failing B2 assertion for `(4,1).west`
    - `lua5.1 test_map_reader.lua` failed on `(4,1).west`
    - added `(4,1).west` to `MAP_DIRECTIONAL_BLOCKS[0x19]`
    - `lua5.1 test_map_reader.lua`, `luac5.1 -p`, and `git diff --check`
      all passed again
  - runtime sync:
    - `add_blocked_edge:25,3,1,RIGHT`
    - `report_runtime_blocks` still showed `count=7` because `(4,1)` now
      carries both `south` and `west` on the same runtime cell key
  - final planner status from the live stop:
    - `report_position`
      => `POSITION map=0x19(Garin's Grave B2) x=3 y=1`
    - `debug_pathfind_to:1,10`
      => `No path found [no_path] (visited=4 path=0)`
    - next best direct verifiers when resuming:
      - `teleport_to:2,2` then `probe_edge_verify:DOWN,5`
        for candidate `(2,3).north`
      - `teleport_to:2,2` then `probe_edge_verify:LEFT,5`
        for candidate `(1,2).east`
      - `teleport_to:2,2` then `probe_edge_verify:UP,5`
        for candidate `(2,1).south`

## 2026-06-05 B2 northwest bridge trio from `(2,2)` settled

- Resumed directly on the three unresolved bridge candidates from the latest
  northwest-pocket handoff.
- Candidate 1: `(2,2)->DOWN` into `(2,3)` => `(2,3).north`
  - `teleport_to:2,2` then `probe_edge_verify:DOWN,5`
    => mixed (`moved=1 blocked=4 classification=inconclusive_teleport_artifact`)
  - stronger tiebreaker:
    - three separate `teleport_to:2,2` then `probe_edge:DOWN`
      all blocked at `raw_hold_timeout`
  - reverse face:
    - `teleport_to:2,3` then `probe_edge_verify:UP,5`
      => `(2,3).north` confirmed blocked `5/5`
- Candidate 2: `(2,2)->LEFT` into `(1,2)` => `(1,2).east`
  - `teleport_to:2,2` then `probe_edge_verify:LEFT,5`
    => mixed (`moved=2 blocked=3 classification=inconclusive_teleport_artifact`)
  - stronger tiebreaker:
    - three separate `teleport_to:2,2` then `probe_edge:LEFT`
      all blocked at `raw_hold_timeout`
  - reverse face:
    - `teleport_to:1,2` then `probe_edge_verify:RIGHT,5`
      => moved `6/6`
  - promote only `(1,2).east`
- Candidate 3: `(2,2)->UP` into `(2,1)` => `(2,1).south`
  - `teleport_to:2,2` then `probe_edge_verify:UP,5`
    => `(2,1).south` confirmed blocked `5/5`
- TDD / permanent model updates:
  - red phase:
    - added failing B2 assertions for `(2,3).north`, `(1,2).east`, and
      `(2,1).south`
    - `lua5.1 test_map_reader.lua` failed on `(2,3).north`
  - green phase:
    - added:
      - `["1,2"] = {east = true}`
      - `["2,1"] = {east = true, south = true}`
      - `["2,3"] = {north = true, west = true}`
    - `lua5.1 test_map_reader.lua`, `luac5.1 -p`, and `git diff --check`
      all passed
- Runtime sync:
  - injected:
    - `add_blocked_edge:25,2,2,DOWN`
    - `add_blocked_edge:25,2,2,LEFT`
    - `add_blocked_edge:25,2,2,UP`
  - readback:
    - `POSITION map=0x19(Garin's Grave B2) x=2 y=2`
    - `RUNTIME_BLOCKS map=0x19 count=9`
    - `(2,1) dirs=east,south`
    - `(4,1) dirs=south,west`
    - `(5,1) dirs=south`
    - `(1,2) dirs=east`
    - `(2,2) dirs=east`
    - `(2,3) dirs=north`
    - `(3,3) dirs=north`
    - `(4,3) dirs=north`
    - `(5,3) dirs=north`
- Planner follow-up:
  - `debug_pathfind_to:1,10` from `(2,2)`
    => `No path found [no_path] (visited=5 path=0)`
  - structural bracket:
    - `debug_pathfind_to:6,2`
      => `No path found [goal_not_walkable]`
    - `debug_pathfind_to:5,2`
      => `Path: 3 east`
  - `teleport_to:5,2` then `debug_pathfind_to:1,10`
    => `No path found [no_path] (visited=4 path=0)`
  - interpretation:
    - this northwest/top-row pocket now behaves as a dead-end component
    - the next resume point should move outward from the reachable east lip
      rather than retesting the `(2,2)` bridge trio
- Current live stop:
  - `POSITION map=0x19(Garin's Grave B2) x=5 y=2`

## 2026-06-05 selected-object teleport focused-object drift on B2

- User reported selected teleport occasionally failing to teleport to the
  focused object and left the emulator in the broken state while trying to
  target `Stairs Up to B1`.
- Broken-state log evidence from `dw_debug.log`:
  - `ROUTE_PLAN_SNAPSHOT map=0x19 ... start=(5,6) target_id=stair_11_2 target_name=Stairs Up to B1 goal=(11,2)`
  - later in the same stop:
    - `TELEPORT_SELECTED mode=exact target_id=stair_5_6 target_name=Center Stairs Down to B3 target=(5,6) landing=(5,6)`
  - this proved the selected-teleport hotkey was reading the wrong selected
    object, not merely choosing a bad landing cell for the right target
- Fresh command-side confirmation after probing the idle loop:
  - `launcher_probe:codex_tp_path` then `pathfind`
    => `ROUTE_PLAN_SNAPSHOT ... target_id=stair_11_2 ... goal=(11,2)`
  - `launcher_probe:codex_tp_obj` then `current_object`
    => `OBJECT: Stairs Up to B1: 4 north, 6 east (4 of 6) [player 5,6 obj 11,2]`
  - `launcher_probe:codex_tp_pos` then `report_position`
    => `POSITION: map=0x19(Garin's Grave B2) x=5 y=6`
- Code read:
  - `main.lua` selected teleport reads `objects.current_object()` directly
  - `object_commands.lua` current-object command already refreshes current-map
    object cache before describing
  - `hotkeys.lua` object browse/pathfind/autowalk used a lighter browse refresh
    that skipped `objects.check_refresh(map_id)`, and teleport hotkeys skipped
    browse refresh entirely before invoking the teleport handler
- Root-cause conclusion:
  - this is stale hotkey-side object-cache state / selection drift, not a bad
    teleport landing resolver
  - likely related to the earlier object navigator map-change stale-cache issue
- TDD / fix:
  - red:
    - extended `test_hotkeys.lua` to require hotkey-side current-map cache
      refresh for K/J/L browse, O/U route actions, and selected teleport
    - failing assertions showed cache refresh count stayed `0`
  - green:
    - `hotkeys.lua` now calls `objects.check_refresh(map_id)` before hotkey-side
      object browse context reads
    - selected teleport hotkeys now also refresh live object positions before
      invoking the handler
  - verification:
    - `lua5.1 test_hotkeys.lua`
    - `lua5.1 test_object_commands.lua`
    - `luac5.1 -p hotkeys.lua test_hotkeys.lua`
    - `git diff --check -- hotkeys.lua test_hotkeys.lua`
- Live caveat:
  - FCEUX has not reloaded this Lua patch yet; live confirmation still needs a
    manual script reload before retrying `Shift+Enter` on `Stairs Up to B1`

## 2026-06-05 noisy front-half reroute to southwest B3 stairs

- User reported the latest B2 route to the southwest B3 stairs was noisy in
  the first part but still completed.
- Route-log review identified three top-right/front-half candidates:
  - `(11,1)->LEFT` into `(10,1)` => candidate `(10,1).east`
  - `(12,2)->DOWN` into `(12,3)` => candidate `(12,3).north`
  - `(13,3)->LEFT` into `(12,3)` => candidate `(12,3).east`
- First direct repeated verifiers for all three matched the same bad shape:
  - `probe_edge_verify:11,1,LEFT,5`
    => `moved=1 blocked=4 classification=inconclusive_teleport_artifact`
  - `probe_edge_verify:12,2,DOWN,5`
    => `moved=1 blocked=4 classification=inconclusive_teleport_artifact`
  - `probe_edge_verify:13,3,LEFT,5`
    => `moved=1 blocked=4 classification=inconclusive_teleport_artifact`
  - practical read:
    - do not promote any of them from repeated verifier alone
- Stronger fresh-start one-shot tiebreakers:
  - `(11,1)->LEFT`
    - cycle 1:
      - `teleport_to:11,1`
      - `report_position` => `(11,1)`
      - `probe_edge:LEFT` => blocked `raw_hold_timeout`
    - cycle 2:
      - `teleport_to:11,1`
      - `report_position` => `(11,1)`
      - `probe_edge:LEFT` => blocked `raw_hold_timeout`
    - cycle 3:
      - `teleport_to:11,1`
      - `report_position` => `(11,1)`
      - `probe_edge:LEFT` => blocked `raw_hold_timeout`
    - reverse:
      - `probe_edge_verify:10,1,RIGHT,5`
        => `moved=6 blocked=0 classification=confirmed_passable`
    - promote `(10,1).east`
  - `(12,2)->DOWN`
    - cycle 1 moved into `(12,3)`
    - cycles 2 and 3 blocked at `raw_hold_timeout`
    - reverse `probe_edge_verify:12,3,UP,5` was interrupted by battle after
      two moved attempts
    - keep `(12,3).north` unmodeled
  - `(13,3)->LEFT`
    - cycle 1 moved into `(12,3)`
    - cycles 2 and 3 blocked at `raw_hold_timeout`
    - reverse:
      - `probe_edge_verify:12,3,RIGHT,5`
        => `moved=6 blocked=0 classification=confirmed_passable`
    - keep `(12,3).east` unmodeled
- TDD / permanent model updates:
  - flipped the old B2 regression that kept `(10,1).east` open
  - added explicit absence assertions for `(12,3).north` and `(12,3).east`
    so this mixed pocket does not get silently promoted
  - added `(10,1).east` to B2 `MAP_DIRECTIONAL_BLOCKS[0x19]`
  - verification:
    - `lua5.1 test_map_reader.lua`
    - `luac5.1 -p map_reader.lua test_map_reader.lua`
    - `git diff --check -- map_reader.lua test_map_reader.lua`
- Runtime sync:
  - injected:
    - `add_blocked_edge:11,1,LEFT`
  - `report_runtime_blocks` =>
    - `RUNTIME_BLOCKS map=0x19 count=1`
    - `RUNTIME_BLOCK map=0x19 x=10 y=1 key=10,1 dirs=east`
- Current live stop:
  - `POSITION map=0x19(Garin's Grave B2) x=13 y=3`

## 2026-06-05 lower southwest-stair reroute polish: `(12,10)->LEFT` is real; remaining noise is timing-only

- Baseline after the user's better combat-interrupted pass:
  - `launcher_probe:codex_route_pass_20260605a` confirmed the Lua loop was
    still polling even though `dw_debug.log` had gone stale
  - `report_position` => `POSITION map=0x19(Garin's Grave B2) x=1 y=10`
  - `report_runtime_blocks` => `RUNTIME_BLOCKS map=0x19 none`
- Route-log review on the latest successful run isolated the lower detour
  candidate:
  - `(12,10)->LEFT` into `(11,10)` with the reroute dropping to `(12,11)`
    afterward
- Direct repeated verifier first:
  - `probe_edge_verify:12,10,LEFT,5`
    => `moved=1 blocked=4 classification=inconclusive_teleport_artifact`
  - not good enough to promote by itself
- Stronger fresh-start tiebreaker from the same origin:
  - cycle 1:
    - `teleport_to:12,10`, `report_position`, `probe_edge:LEFT`
      => blocked at `raw_hold_timeout`
  - cycle 2:
    - `teleport_to:12,10`, `report_position`, `probe_edge:LEFT`
      => blocked at `raw_hold_timeout`
  - cycle 3:
    - `teleport_to:12,10`, `report_position`, `probe_edge:LEFT`
      => blocked at `raw_hold_timeout`
  - reverse:
    - `probe_edge_verify:11,10,RIGHT,5`
      => `moved=6 blocked=0 classification=confirmed_passable`
  - decision:
    - promote only `(11,10).east`
- Runtime sync before the follow-up route:
  - injected:
    - `add_blocked_edge:12,10,LEFT`
  - readback:
    - `RUNTIME_BLOCKS map=0x19 count=1`
    - `RUNTIME_BLOCK map=0x19 x=11 y=10 key=11,10 dirs=east`
- Follow-up live route with the injected seam:
  - `auto_walk:1,10` from live `(12,10)` completed all the way back to the
    southwest B3 stairs
  - remaining noisy spots were timing-only:
    - `(12,10)->DOWN` first blocked at the queued-route timeout, then the
      seam retry moved immediately into `(12,11)` and cleared the temp block
    - `(2,11)->LEFT` again needed the known seam-retry/repress cycle, then
      completed into `(1,11)` and cleared the temp block
  - no new durable geometry candidates came out of the follow-up pass
- TDD / permanent model updates:
  - added a new B2 regression for `(11,10).east` first
  - confirmed it failed red against the existing model
  - added `(11,10).east` to B2 `MAP_DIRECTIONAL_BLOCKS[0x19]`
  - verification:
    - `lua5.1 test_map_reader.lua`
    - `luac5.1 -p map_reader.lua test_map_reader.lua`
    - `git diff --check -- map_reader.lua test_map_reader.lua session_handoff.md work_notes/current_investigation.md`
- Current live stop:
  - `POSITION map=0x19(Garin's Grave B2) x=1 y=10`

## 2026-06-05 B2 entry-side route polish from `Stairs Up to B1`: `(11,2)->LEFT` is real

- User report:
  - southwest-stair routes now basically work both ways
  - remaining complaint is the entry-side planner from `(11,2)` wanting
    `1 west`, with that first west step feeling engine-blocked
- Baseline:
  - `launcher_probe:codex_b2_entry_20260605a` confirmed the loop was live
  - `report_position` => `POSITION map=0x19(Garin's Grave B2) x=11 y=2`
  - `report_runtime_blocks` before the new check =>
    - `RUNTIME_BLOCKS map=0x19 count=1`
    - `RUNTIME_BLOCK map=0x19 x=11 y=10 key=11,10 dirs=east`
  - planner from the live stair still said:
    - `ROUTE_PLAN_SNAPSHOT ... start=(11,2) ... result=Path: 2 west, 1 south, 8 west, 7 south`
  - the only directly relevant pre-investigation movement log at `(11,2)` was
    a canceled `manual_tap` early-twitch wait, not proof either way
- Direct verification of the complained-about first step:
  - `probe_edge_verify:11,2,LEFT,5`
    => `moved=0 blocked=5 classification=confirmed_blocked`
  - reverse:
    - `probe_edge_verify:10,2,RIGHT,5`
      => `moved=6 blocked=0 classification=confirmed_passable`
  - decision:
    - promote only `(10,2).east`
- Runtime sync:
  - injected:
    - `add_blocked_edge:11,2,LEFT`
  - readback:
    - `RUNTIME_BLOCKS map=0x19 count=2`
    - `(10,2) dirs=east`
    - `(11,10) dirs=east`
- Follow-up live reroute from the entry stair:
  - `auto_walk:1,10` from `(11,2)` replanned as:
    - `1 south, 10 west, 7 south`
  - first new route-only candidate after the injected seam:
    - `(11,2)->DOWN` into `(11,3)`
    - blocked again on seam retry:
      - `SEAM_OBSERVATION map=0x19 cell=(11,3) approach=north result=blocked`
      - counts now blocked `3`, moved `0`
    - do not promote yet; needs direct verifier after combat
  - next repeated route-only candidates after that were the familiar top-right
    pocket faces:
    - `(12,2)->DOWN` into `(12,3)`
    - `(13,3)->LEFT` into `(12,3)`
    - still not directly re-verified on this pass
  - the live route was then interrupted by a `Warlock` battle at `(7,11)`
- TDD / permanent model updates:
  - added a new B2 regression for `(10,2).east` first
  - confirmed it failed red against the old permanent model
  - added `(10,2).east` to B2 `MAP_DIRECTIONAL_BLOCKS[0x19]`
  - updated the old `(11,3).north` absence assertion wording so it stays
    explicitly unmodeled until it gets a direct verifier
  - verification:
    - `lua5.1 test_map_reader.lua`
    - `luac5.1 -p map_reader.lua test_map_reader.lua`
    - `git diff --check -- map_reader.lua test_map_reader.lua`
- Current live stop:
  - battle started at `map=0x19(Garin's Grave B2) x=7 y=11`
  - next best direct check after the fight:
    - `probe_edge_verify:11,2,DOWN,5`

## 2026-06-05 B2 entry-side north lip: `(11,3).north` confirmed

- User returned after another route to the stairs and asked to start the pass
  with the previously suspected entry seam from `(11,2)` into `(11,3)`.
- Fresh route evidence before the direct probe:
  - from a new route started at `Stairs Up to B1`, the planner again said:
    - `Path: 1 south, 10 west, 7 south`
  - the route-only seam observation on the first step rose further:
    - `SEAM_OBSERVATION map=0x19 cell=(11,3) approach=north result=blocked`
      now blocked `5` / moved `0`
- One detour during setup:
  - first `probe_edge_verify:11,2,DOWN,5` was refused because the in-game
    command menu was still open
  - `simulate_input:START` did not close it
  - `simulate_input:B` did close it:
    - `EVENT: command menu closed`
- Direct verifier after the menu cleanup:
  - `probe_edge_verify:11,2,DOWN,5`
    => `moved=0 blocked=5 classification=confirmed_blocked`
  - decision:
    - promote `(11,3).north`
- Reverse-face follow-up:
  - first `probe_edge_verify:11,3,UP,5`
    - attempt 1 moved into `(11,2)`
    - attempt 2 was interrupted by a `Metal Scorpion` battle
    - result:
      - `classification=inconclusive_interrupted`
  - after the fight, second `probe_edge_verify:11,3,UP,5`
    - attempt 1 again moved into `(11,2)`
    - attempt 2 again got interrupted by another `Metal Scorpion` battle
    - result:
      - still `classification=inconclusive_interrupted`
  - interpretation:
    - the reverse face probably stays open, but the evidence is still too
      battle-contaminated to promote that direction
    - only `(11,3).north` should be modeled for now
- TDD / permanent model updates:
  - added a new B2 regression for `(11,3).north` first
  - confirmed it failed red against the current permanent model
  - added `(11,3).north` to B2 `MAP_DIRECTIONAL_BLOCKS[0x19]`
  - verification:
    - `lua5.1 test_map_reader.lua`
    - `luac5.1 -p map_reader.lua test_map_reader.lua`
    - `git diff --check -- map_reader.lua test_map_reader.lua`
- Runtime sync:
  - before the new injection:
    - `RUNTIME_BLOCKS map=0x19 count=2`
    - `(10,2) dirs=east`
    - `(11,10) dirs=east`
  - injected during battle:
    - `add_blocked_edge:11,2,DOWN`
  - after injection:
    - `RUNTIME_BLOCKS map=0x19 count=3`
    - `(10,2) dirs=east`
    - `(11,3) dirs=north`
    - `(11,10) dirs=east`
- Current live stop:
  - battle state at `POSITION map=0x19(Garin's Grave B2) x=11 y=3`
  - next best live check after the user clears the fight:
    - rerun `probe_edge_verify:11,3,UP,5`
    - then revisit `(12,3).north` / `(12,3).east` only if the route still
      wants to peel through that same top-right pocket

## 2026-06-05 B2 top-right pocket follow-up: `(12,3).east` real, `(12,3).north` open

- User asked to verify and patch the remaining suspect `(12,3)` faces.
- Baseline:
  - `launcher_probe:codex_b2_topright_20260605a` matched
  - `report_position` => `POSITION map=0x19(Garin's Grave B2) x=11 y=2`
  - `report_runtime_blocks` =>
    - `(10,2) dirs=east`
    - `(11,3) dirs=north`
    - `(11,10) dirs=east`
- One bad setup detour:
  - I mistakenly launched `teleport_to:12,2` and `teleport_to:13,3` in
    parallel; they collided and only the later `(13,3)` landing was usable
  - ignored those results and restarted the live checks in serialized order
- East face direct verifier:
  - `teleport_to:13,3`, `report_position`
  - `probe_edge_verify:LEFT,5`
    => `moved=0 blocked=5 classification=confirmed_blocked`
  - decision:
    - promote `(12,3).east`
- North face direct verifier, pass 1:
  - `teleport_to:12,2`, `report_position`
  - `probe_edge_verify:DOWN,5`
    => `moved=3 blocked=0 interrupted=1 classification=inconclusive_interrupted`
  - battle:
    - `Metal Scorpion`
- North face direct verifier, pass 2 after battle:
  - `report_position` => back in field at `(12,2)`
  - `probe_edge_verify:DOWN,5`
    => `moved=5 blocked=1 classification=inconclusive_teleport_artifact`
  - important detail:
    - attempts 1-5 all moved into `(12,3)`
    - only stability recheck attempt 6 blocked at `raw_hold_timeout`
    - do not promote `(12,3).north`
- Reverse-face tiebreaker:
  - `teleport_to:12,3`, `report_position`
  - `probe_edge_verify:UP,5`
    => `moved=6 blocked=0 classification=confirmed_passable`
  - decision:
    - `(12,3).north` stays open
- TDD / permanent model updates:
  - flipped the old absence assertion for `(12,3).east` into a positive
    regression
  - kept `(12,3).north` explicitly nil/open with updated wording
  - red:
    - `lua5.1 test_map_reader.lua` failed on `(12,3).east`
  - green:
    - added `(12,3).east` to B2 `MAP_DIRECTIONAL_BLOCKS[0x19]`
- Runtime sync:
  - injected:
    - `add_blocked_edge:13,3,LEFT`
  - readback:
    - `RUNTIME_BLOCKS map=0x19 count=4`
    - `(10,2) dirs=east`
    - `(11,3) dirs=north`
    - `(12,3) dirs=east`
    - `(11,10) dirs=east`
  - current live stop:
    - `POSITION map=0x19(Garin's Grave B2) x=12 y=2`

## 2026-06-05 B2 `(12,3)<->(11,3)` west seam: both faces block

- User report:
  - from live `(12,3)`, the planner still wanted to go west but the engine
    said no
- Fresh log context before re-probing:
  - `ROUTE_PLAN_SNAPSHOT ... start=(12,3) ... result=Path: 11 west, 7 south`
  - a live west attempt at `(12,3)` only had:
    - `auto_step cancel manual_tap early-twitch wait dir=left from=(12,3)`
  - that movement twitch alone was not enough to patch
- Baseline:
  - `report_position` => `POSITION map=0x19(Garin's Grave B2) x=12 y=3`
  - `report_runtime_blocks` =>
    - `(10,2) dirs=east`
    - `(11,3) dirs=north`
    - `(12,3) dirs=east`
    - `(11,10) dirs=east`
- Forward direct verifier from the complained-about side:
  - `probe_edge_verify:LEFT,5` from `(12,3)`
    => `moved=0 blocked=5 classification=confirmed_blocked`
  - decision:
    - promote `(11,3).east`
- Reverse verifier from the destination side:
  - `teleport_to:11,3`, `report_position`
  - `probe_edge_verify:RIGHT,5`
    => `moved=1 blocked=4 classification=inconclusive_teleport_artifact`
  - not good enough by itself
- Stronger reverse-face tiebreaker:
  - cycle 1:
    - `teleport_to:11,3`, `report_position`, `probe_edge:RIGHT`
      => `EDGE_PROBE_RESULT ... status=blocked ... reason=raw_hold_timeout`
  - cycle 2:
    - `teleport_to:11,3`, `report_position`, `probe_edge:RIGHT`
      => blocked `raw_hold_timeout`
  - cycle 3:
    - `teleport_to:11,3`, `report_position`, `probe_edge:RIGHT`
      => blocked `raw_hold_timeout`
  - decision:
    - promote `(12,3).west`
- TDD / permanent model updates:
  - added new B2 regressions for:
    - `(11,3).east`
    - `(12,3).west`
  - red:
    - `lua5.1 test_map_reader.lua` failed first on `(11,3).east`
  - green:
    - added both faces to B2 `MAP_DIRECTIONAL_BLOCKS[0x19]`
- Runtime sync:
  - injected:
    - `add_blocked_edge:12,3,LEFT`
    - `add_blocked_edge:11,3,RIGHT`
  - readback:
    - `RUNTIME_BLOCKS map=0x19 count=4`
    - `(10,2) dirs=east`
    - `(11,3) dirs=east,north`
    - `(12,3) dirs=east,west`
    - `(11,10) dirs=east`
- Planner sanity after runtime injection:
  - `teleport_to:12,3`, `report_position`
  - `debug_pathfind_to:1,10`
    => `Path: 1 south, 3 west, 1 north, 8 west, 7 south`
  - interpretation:
    - planner no longer tries to go straight west through the sealed seam

## 2026-06-05 B2 top-row / east-side follow-up: `(8,3).east` real; next candidate `(12,7).north`

- User asked to start with `(9,3)->LEFT`, then continue.
- Direct verification of the requested seam:
  - `teleport_to:9,3`, `report_position`
  - `probe_edge_verify:LEFT,5`
    => `moved=0 blocked=5 classification=confirmed_blocked`
  - decision:
    - promote `(8,3).east`
- Reverse face:
  - `teleport_to:8,3`, `report_position`
  - `probe_edge_verify:RIGHT,5`
    => `moved=6 blocked=0 classification=confirmed_passable`
  - decision:
    - keep reverse face open; this is another one-way seam
- Runtime sync:
  - injected:
    - `add_blocked_edge:9,3,LEFT`
  - readback:
    - `RUNTIME_BLOCKS map=0x19 count=5`
    - `(8,3) dirs=east`
    - `(10,2) dirs=east`
    - `(11,3) dirs=east,north`
    - `(12,3) dirs=east,west`
    - `(11,10) dirs=east`
- Planner follow-up from top-right start:
  - `teleport_to:12,3`, `report_position`
  - `debug_pathfind_to:1,10`
    => `Path: 5 south, 1 east, 3 south, 12 west, 1 north`
- Route continuation with runtime seam injected:
  - `auto_walk:1,10`
  - clean moved sequence before the first new blocker:
    - `(12,4)`, `(12,5)`, `(12,6)`
  - first new route-shaped blocker:
    - `(12,6)->DOWN` into `(12,7)`
    - queued route blocked, then seam retry blocked:
      - `SEAM_OBSERVATION map=0x19 cell=(12,7) approach=north result=blocked`
      - counts now blocked `1` / moved `0`
    - still only route evidence; do not promote yet
  - reroute after the temp block:
    - `Path: 1 east, 5 south, 12 west, 1 north`
  - east-column continuation then moved through:
    - `(13,6)`, `(13,7)`, `(13,8)`, `(13,9)`, `(13,10)`, `(13,11)`
  - later lower-lane noise:
    - `(12,11)->LEFT` hit queued-route block and entered seam retry, but a
      battle started before it could settle
    - lower confidence than `(12,7).north`
- Battle interruption:
  - `Wolf`
  - live stop:
    - `POSITION map=0x19(Garin's Grave B2) x=12 y=11`
- TDD / permanent model updates:
  - added a new B2 regression for `(8,3).east`
  - red:
    - `lua5.1 test_map_reader.lua` failed on `(8,3).east`
  - green:
    - extended existing B2 `(8,3)` entry from `{south = true}` to
      `{south = true, east = true}`

## 2026-06-05 follow-up: southwest return cleanup from `(12,6)->DOWN` through route back to `(11,2)`

- Clean direct verifier:
  - `probe_edge_verify:12,6,DOWN,5`
    - `EDGE_VERIFY_RESULT ... from=(12,6) dir=down dest=(12,7) attempts=5 moved=0 blocked=5 classification=confirmed_blocked`
    - promote `(12,7).north`
- Wolf interruption near the southwest B3 stairs was not a real seam:
  - `probe_edge_verify:1,11,UP,5`
    - `moved=6 blocked=0 classification=confirmed_passable`
    - keep `(1,10)` open from the south
- New real seam just above the southwest B3 stair:
  - `probe_edge_verify:1,10,UP,5`
    - `EDGE_VERIFY_RESULT ... from=(1,10) dir=up dest=(1,9) attempts=5 moved=0 blocked=5 classification=confirmed_blocked`
    - promote `(1,9).south`
  - runtime seed:
    - `add_blocked_edge:1,10,UP`
  - planner change from `(1,10)` to `(11,2)`:
    - `Path: 1 east, 7 north, 9 east, 1 north`
- `auto_walk:11,2` with `(1,9).south` injected completed all the way back to
  `POSITION map=0x19(Garin's Grave B2) x=11 y=2`, but it exposed several
  cleanup candidates on the way:
  - cleanest:
    - `(2,11)->UP` into `(2,10)` blocked repeatedly in-route
  - mixed row-9 south-edge band:
    - `(5,10)->UP`, `(6,10)->UP`, `(7,10)->UP`, `(8,10)->UP`
- Direct verification of the strongest candidates:
  - `probe_edge_verify:5,10,UP,5`
    - `moved=2 blocked=3 classification=inconclusive_teleport_artifact`
    - do not promote
  - `probe_edge_verify:2,11,UP,5`
    - `EDGE_VERIFY_RESULT ... from=(2,11) dir=up dest=(2,10) attempts=5 moved=0 blocked=5 classification=confirmed_blocked`
    - promote `(2,10).south`
  - runtime seed:
    - `add_blocked_edge:2,11,UP`
    - readback:
      - `POSITION: map=0x19(Garin's Grave B2) x=2 y=11`
      - `RUNTIME_BLOCKS map=0x19 count=8`
      - includes `(1,9) dirs=south` and `(2,10) dirs=south`
- Permanent patch set from this follow-up:
  - `map_reader.lua`
    - `(12,7).north`
    - `(1,9).south`
    - `(2,10).south`
  - `test_map_reader.lua`
    - matching regressions for all three seams
- Recommended next live checks:
  - `probe_edge_verify:6,10,UP,5`
  - `probe_edge_verify:7,10,UP,5`
  - `probe_edge_verify:8,10,UP,5`

## 2026-06-05 row-9 south-edge cleanup: `(6,9).south`, `(7,9).south`, `(8,9).south` confirmed; `(5,10)->UP` stays mixed

- User asked to check and patch the remaining south-edge row-9 candidates.
- Direct verification of the remaining strip:
  - `probe_edge_verify:6,10,UP,5`
    - `EDGE_VERIFY_RESULT ... from=(6,10) dir=up dest=(6,9) attempts=5 moved=0 blocked=5 classification=confirmed_blocked`
    - promote `(6,9).south`
  - `probe_edge_verify:7,10,UP,5`
    - `EDGE_VERIFY_RESULT ... from=(7,10) dir=up dest=(7,9) attempts=5 moved=0 blocked=5 classification=confirmed_blocked`
    - promote `(7,9).south`
  - `probe_edge_verify:8,10,UP,5`
    - `EDGE_VERIFY_RESULT ... from=(8,10) dir=up dest=(8,9) attempts=5 moved=0 blocked=5 classification=confirmed_blocked`
    - promote `(8,9).south`
  - control from the earlier same pass remains:
    - `probe_edge_verify:5,10,UP,5`
      - `moved=2 blocked=3 classification=inconclusive_teleport_artifact`
      - keep `(5,9).south` unmodeled
- Permanent patch set:
  - `map_reader.lua`
    - add `(6,9).south`
    - add `(7,9).south`
    - add `(8,9).south`
  - `test_map_reader.lua`
    - flip the old open/mixed assumptions for `(7,9).south` and `(8,9).south`
    - add positive regressions for `(6,9).south`, `(7,9).south`, `(8,9).south`
- Runtime sync:
  - injected:
    - `add_blocked_edge:6,10,UP`
    - `add_blocked_edge:7,10,UP`
    - `add_blocked_edge:8,10,UP`
  - readback:
    - `POSITION map=0x19(Garin's Grave B2) x=8 y=10`
    - `RUNTIME_BLOCKS map=0x19 count=11`
    - includes `(1,9).south`, `(2,10).south`, `(6,9).south`, `(7,9).south`,
      `(8,9).south`, plus the earlier top-right seams
- Planner / live sanity:
  - from `(8,10)`, `debug_pathfind_to:11,2`
    - `Path: 5 east, 8 north, 2 west`
  - `auto_walk:11,2` followed that reroute cleanly up the east side to
    `(13,2)`
  - a `Wolf` battle then interrupted the final seam retry at
    `(12,2)->LEFT` into `(11,2)`
  - treat that last step as battle-contaminated noise for now because an
    earlier route already completed back to `Stairs Up to B1`

## 2026-06-05 polish pass from `Stairs Up to B1`: no new durable B2 blockers yet

- Fresh live baseline after log rollover:
  - `launcher_probe:codex_polish_20260605a`
  - `report_position`
    - `POSITION: map=0x19(Garin's Grave B2) x=11 y=2`
  - `report_runtime_blocks`
    - `RUNTIME_BLOCKS map=0x19 count=11`
    - includes the current entry-side, top-right, row-9 south-edge, and
      southwest return seams
- Planner from the live stair:
  - `debug_pathfind_to:1,10`
    - `Path: 2 east, 9 south, 12 west, 1 north`
- Live route pass:
  - `auto_walk:1,10`
  - route followed the expected east-column detour and lower westward lane
    without finding a new confirmed geometry break
- Remaining noisy spots from this pass:
  - `(12,2)->RIGHT` into `(13,2)`
    - queued-route step timed out once after movement started
    - seam retry then moved cleanly
    - temp block cleared immediately
    - treat as timing noise, not geometry
  - `(13,10)->DOWN` into `(13,11)`
    - same pattern: one queued-route timeout, then seam retry moved cleanly
    - temp block cleared immediately
    - treat as timing noise, not geometry
  - `(2,11)->LEFT` into `(1,11)`
    - queued-route step timed out once and entered seam retry
    - a `Warlock` battle started before the retry could settle
    - leave unmodeled; current evidence is battle-contaminated
- Current live stop:
  - battle state at `POSITION map=0x19(Garin's Grave B2) x=2 y=11`
  - enemy:
    - `Warlock`
- Practical read:
  - this pass did not produce a new permanent blocker to patch
  - if we do one more cleanup check after the fight, the only worthwhile
    follow-up from this pass is a direct verifier on `(2,11)->LEFT`, and even
    that currently looks more like the old seam-retry timing noise than map
    geometry

## 2026-06-05 user-completed return route: late reroute at `(13,3)->UP` is confirmed passable

- User ran the remaining route and reported one little reroute near the end.
- Recovered live evidence from the completed autowalk after the earlier
  `Warlock` battle:
  - route from `(2,11)` to `Stairs Up to B1` completed successfully at
    `(11,2)`
  - known/runtime-backed reroute points behaved as expected:
    - `(5,10)->UP` into `(5,9)` blocked again and rerouted around the still
      mixed row-9 holdout
    - `(10,10)->RIGHT` into `(11,10)` blocked again and rerouted around the
      confirmed `(11,10).east` seam
  - pure timing/noise retries that self-cleared:
    - `(4,11)->RIGHT` into `(5,11)`
    - `(12,11)->RIGHT` into `(13,11)`
  - late-route retry worth checking directly:
    - `(13,3)->UP` into `(13,2)`
    - queued-route attempt timed out once, seam retry then moved and the route
      completed through `(12,2)` to `(11,2)`
- Direct follow-up on the late reroute:
  - `teleport_to:13,3`, `report_position`
  - `probe_edge_verify:UP,5`
    - `EDGE_VERIFY_RESULT ... from=(13,3) dir=up dest=(13,2) attempts=6 moved=6 blocked=0 classification=confirmed_passable`
    - keep this edge open; no patch
- Practical read:
  - no new durable blocker from the user's completed return route
  - the late reroute was movement/timing noise, not hidden geometry
  - the only remaining map-shaped holdout touched during this run is still
    `(5,10)->UP`, which remains mixed and unmodeled

## 2026-06-05 B2 stair-hub audit from `Stairs Up to B1`: all six stair objects belong to the reachable hub

- User asked whether the extra B2 stair objects currently marked reachable
  should really be accessible from the current side of the floor, or whether
  some should be sealed off by finding more true blockers.
- Live stair roster from `(11,2)`:
  - `Stairs Up to B1` at `(11,2)`
  - `Northeast Stairs Down to B3` at `(12,1)`
  - `Southeast Stairs Down to B3` at `(12,10)`
  - `Center Stairs Down to B3` at `(5,6)`
  - `Northwest Stairs Down to B3` at `(1,1)`
  - `Southwest Stairs Down to B3` at `(1,10)`
- Object-browser / planner checks:
  - `pathability_filter:reachable`
    - still shows all six stair objects under `Travel, reachable`
  - `pathability_filter:unreachable`
    - `PATHABILITY_FILTER: Travel, unreachable. No objects`
    - `current_object` / `next_object` then report `No objects found`
  - restored browser state afterward with:
    - `pathability_filter:all`
    - `current_object`
      - `OBJECT: Stairs Up to B1: here (1 of 6)`
- Direct planner routes from live `(11,2)`:
  - `debug_pathfind_to:12,1`
    - `Path: 1 north, 1 east`
  - `debug_pathfind_to:12,10`
    - `Path: 2 east, 8 south, 1 west`
  - `debug_pathfind_to:5,6`
    - `Path: 1 east, 2 south, 7 west, 2 south`
  - `debug_pathfind_to:1,1`
    - `Path: 2 east, 9 south, 8 west, 2 north, 4 west, 8 north`
  - `debug_pathfind_to:1,10`
    - `Path: 2 east, 9 south, 12 west, 1 north`
- Map-reference cross-check:
  - `project_resources/maps/garins_grave/README.md`
    - B2 is a stair hub with the same six stair cells
    - guide bias recorded there:
      - nearby return-side stair and center stair are dead-end/trap leads
      - northwest and southeast stairs lead toward the Cursed Belt branch
      - southwest stair is the main progression route
  - the bundled `realm_grave_garinham.png` composite matches that
    interpretation visually
- Conclusion:
  - do not try to "fix" B2 by sealing off the extra stair objects
  - the extra B2 stair routes appear to be intended connectivity, not planner
    leakage
  - any future issue on one of those stair routes should be treated as a
    specific route/seam verification task, not as evidence that the stair
    should be globally unreachable

## 2026-06-06 B2 central-stair return-side one-way seam evidence

- Live target: Garin's Grave B2 `0x19`, central stair `(5,6)` versus B2
  entrance stair `(11,2)`.
- Important verifier/tooling lesson:
  - B2 `probe_edge_verify` with explicit origins produced mixed
    `inconclusive_teleport_artifact` results on several edges.
  - Do not promote those mixed verifier results; prefer live route evidence and
    same-origin `probe_edge:DIR` while standing on the edge origin after normal
    route movement.
  - Teleport-seeded checks can be useful for repositioning or forensic
    comparison, but should not decide passability.
- Confirmed live route facts:
  - Forward movement to central stair `(5,6)` succeeded and ended at
    `POSITION map=0x19 x=5 y=6`.
  - Teleport-seeded probe initially appeared to disprove the temporary
    `(2,10).west` guard: after `teleport_to:1,10`, `(1,10)->RIGHT` moved to
    `(2,10)`.
  - Later normal-route arrival contradicted that: after reaching southwest
    stairs `(1,10)` by walking, `(1,10)->RIGHT` blocked twice. Keep this edge
    runtime-only/unresolved and do not promote either direction as stable map
    truth from teleport evidence alone.
  - Return from the central-side component to entrance stair `(11,2)` collapsed
    only after direct same-origin probes, not route-only guesses.
- Runtime-only B2 guards added during the central return investigation:
  - `(11,3).south` from `(11,4)->UP` blocked.
  - `(10,2).west` from `(9,2)->RIGHT` blocked.
  - `(9,1).south` from `(9,2)->UP` blocked.
  - `(10,3).west` from `(9,3)->RIGHT` blocked.
  - `(10,3).south` from `(10,4)->UP` blocked.
  - `(12,4).west` from `(11,4)->RIGHT` blocked.
  - `(10,6).west` from `(9,6)->RIGHT` blocked.
  - `(2,10).west` from live-walked `(1,10)->RIGHT` blocked twice, but conflicts
    with the earlier teleport-seeded pass and needs special care.
- Existing runtime guards still active from the same B2 staircase pass:
  - `(12,6).east`
  - `(12,4).east`
  - `(8,8).east`
  - `(5,9).south`
  - `(11,10).south,west`
- Planner result after adding the direct-probe guards:
  - from `POSITION map=0x19 x=9 y=6`,
    `debug_pathfind_to:11,2` => `No path found`.
  - from the same side, `debug_pathfind_to:5,6` still found
    `Path: 2 north, 4 west, 2 south`.
  - live autowalk/probe returned to the central stair; final direct probe
    `(5,5)->DOWN` moved to `(5,6)`.
- Current interpretation:
  - central stair `(5,6)` is reachable from the B2 entrance side, but the
    central-side return back to the B2 entrance stair `(11,2)` appears sealed by
    one-way/hidden seams.
  - Keep these as runtime-only until a later focused promotion pass adds
    regression tests and checks for older B2 map-data assumptions.

## 2026-06-07 B3 southeast-stair pocket live pruning, paused in combat

- Starting live state:
  - User relocated the hero to Garin's Grave B3 `0x1A` at the bottom of the
    southeast stairs.
  - Baseline position: `(18,13)`.
  - Runtime blocked tiles were empty at the start of this southeast pass.
  - Reachable object filter initially listed nine objects, including the local
    `Southeast Stairs Up`, the Silver Harp chest `(13,6)`, lower/upper stair
    objects, the northwest/west branch, and the west chest `(1,1)`.
- Investigation target:
  - First pruning target is the apparent Silver Harp chest route `(13,6)`,
    because the southeast landing should not be assumed to connect to that
    branch unless live movement proves it.
- Clean same-origin blockers injected during this pass:
  - `(18,13)->LEFT` blocked, modeled as `(17,13).east`.
  - `(18,12)->LEFT` blocked, modeled as `(17,12).east`.
  - `(19,6)->LEFT` blocked, modeled as `(18,6).east`.
  - `(19,5)->LEFT` blocked, modeled as `(18,5).east`.
  - `(19,7)->LEFT` blocked, modeled as `(18,7).east`.
  - `(17,8)->LEFT` blocked, modeled as `(16,8).east`.
  - `(17,6)->LEFT` blocked, modeled as `(16,6).east`.
  - `(17,6)->UP` blocked, modeled as `(17,5).south`.
  - `(17,7)->LEFT` blocked, modeled as `(16,7).east`.
  - `(17,9)->LEFT` blocked, modeled as `(16,9).east`.
  - `(16,10)->UP` blocked, modeled as `(16,9).south`.
  - `(15,10)->LEFT` blocked, modeled as `(14,10).east`.
  - `(15,10)->UP` blocked, modeled as `(15,9).south`.
  - `(15,11)->LEFT` blocked, modeled as `(14,11).east`.
  - `(15,11)->DOWN` blocked, modeled as `(15,12).north`.
  - `(17,10)->RIGHT` blocked, modeled as `(18,10).west`.
  - `(17,6)->RIGHT` blocked, modeled as `(18,6).west`.
  - `(17,7)->RIGHT` blocked, modeled as `(18,7).west`.
  - `(18,8)->UP` blocked, modeled as `(18,7).south`.
  - `(17,4)->LEFT` blocked, modeled as `(16,4).east`.
  - `(17,4)->DOWN` blocked, modeled as `(17,5).north`.
  - `(17,4)->UP` blocked, modeled as `(17,3).south`.
  - `(18,4)->DOWN` blocked, modeled as `(18,5).north`.
  - `(18,4)->UP` blocked, modeled as `(18,3).south`.
  - `(19,4)->UP` blocked, modeled as `(19,3).south`.
- Clean passable evidence gathered while chasing the Silver Harp false route:
  - `(19,7)->DOWN` moved to `(19,8)` on a post-combat same-origin
    `probe_edge:DOWN`.
  - Autowalk then moved cleanly down the east column through `(19,9)`,
    `(19,10)`, `(19,11)`, and `(19,12)`.
- Contaminated / still-open evidence:
  - Autowalk first tested `(19,7)->DOWN`, but a Wolflord battle interrupted the
    seam retry; post-combat same-origin probing proved that edge passable.
  - Autowalk later tested `(19,12)->DOWN`; a Wolflord battle interrupted the
    seam retry at `(19,12)`.
  - Do not promote `(19,12)->DOWN` yet. Next live step after combat is a
    same-origin `probe_edge:DOWN` while still standing at `(19,12)`.
- Paused state:
  - Commands reported `POSITION map=0x1A x=19 y=12` while in battle.
  - `report_runtime_blocks` count was 19 after the clean blocker injections.

### 2026-06-07 continuation after the `(19,12)` battle

- Post-combat direct probe:
  - `(19,12)->DOWN` moved to `(19,13)`.
  - The earlier autowalk hiccup at that edge was battle/timing contamination,
    not a wall.
- Additional clean same-origin blockers injected while pruning the Silver Harp
  false route:
  - `(17,15)->LEFT` blocked, modeled as `(16,15).east`.
  - `(17,15)->UP` blocked, modeled as `(17,14).south`.
  - `(18,15)->UP` blocked, modeled as `(18,14).south`.
  - `(17,17)->LEFT` blocked, modeled as `(16,17).east`.
  - `(17,17)->DOWN` blocked, modeled as `(17,18).north`.
  - `(19,18)->LEFT` blocked, modeled as `(18,18).east`.
- Clean passable movement used to keep probes same-origin:
  - `(18,15)->RIGHT` moved to `(19,15)`.
  - `(19,15)->DOWN` moved to `(19,16)`.
  - `(17,15)->DOWN` moved to `(17,16)`.
  - `(17,16)->DOWN` moved to `(17,17)`.
- Contaminated / still-open evidence:
  - Autowalk suggested `(19,16)->LEFT` may be blocked, but a Drollmagi battle
    started immediately after reaching `(19,16)`.
  - The queued direct `probe_edge:LEFT` was refused in battle; do not promote
    `(19,16)->LEFT` yet.
  - Autowalk also suggested possible blockers at `(19,14)->LEFT` and
    `(18,13)->DOWN` around cell `(18,14)`, but these still need direct
    same-origin probes if the route remains relevant.
- Current paused state:
  - Still in battle at `POSITION map=0x1A x=19 y=16`.
  - Runtime block count was 25 before the battle pause.
  - Next live step after combat clears: same-origin `probe_edge:LEFT` from
    `(19,16)`.

### 2026-06-07 continuation after the `(19,16)` battle

- Additional clean same-origin blockers injected while continuing to prune the
  false Silver Harp route from the B3 southeast-stair component:
  - `(19,16)->LEFT` blocked, modeled as `(18,16).east`.
  - `(19,14)->LEFT` blocked, modeled as `(18,14).east`.
  - `(17,16)->LEFT` blocked, modeled as `(16,16).east`.
  - `(17,17)->RIGHT` blocked, modeled as `(18,17).west`.
  - `(17,16)->RIGHT` blocked, modeled as `(18,16).west`.
  - `(13,19)->UP` blocked, modeled as `(13,18).south`.
  - `(14,19)->UP` blocked, modeled as `(14,18).south`.
  - `(15,13)->UP` blocked, modeled as `(15,12).south`.
  - `(14,13)->UP` blocked, modeled as `(14,12).south`.
  - `(13,13)->UP` blocked, modeled as `(13,12).south`.
  - `(12,13)->UP` blocked, modeled as `(12,12).south`.
  - `(11,13)->UP` blocked, modeled as `(11,12).south`.
  - `(11,13)->LEFT` blocked, modeled as `(10,13).east`.
  - `(16,12)->LEFT` blocked, modeled as `(15,12).east`.
  - `(12,15)->DOWN` blocked, modeled as `(12,16).north`.
  - `(11,15)->LEFT` blocked, modeled as `(10,15).east`.
  - `(11,15)->DOWN` blocked, modeled as `(11,16).north`.
  - `(11,14)->LEFT` blocked, modeled as `(10,14).east`.
  - `(15,16)->LEFT` blocked, modeled as `(14,16).east`.
  - `(14,15)->DOWN` blocked, modeled as `(14,16).north`.
- Clean passable evidence / no-promote results:
  - `(19,15)->UP` moved to `(19,14)`.
  - `(19,14)->UP` moved to `(19,13)`.
  - `(19,13)->LEFT` moved to `(18,13)`.
  - `(16,13)->UP` moved to `(16,12)`.
  - `(12,17)->LEFT` moved to `(11,17)` before a new battle started; this
    disproves the route-only `(11,17).east` wall candidate.
- Contaminated / still-open evidence:
  - `(13,15)->DOWN` into `(13,16)` has repeated route-only blocked evidence
    and needs same-origin `probe_edge:DOWN` from `(13,15)`.
  - `(18,13)->DOWN` into `(18,14)` still has older autowalk-only blocked
    evidence and should not be promoted unless the route returns there and a
    same-origin direct probe agrees.
- Current paused state:
  - A Druinlord battle started immediately after the clean passable
    `(12,17)->LEFT` movement.
  - Current live position is `map=0x1A x=11 y=17`, in battle.
  - Runtime block count was 40 before the battle-starting probe.
  - Next live step after combat clears: re-establish field state with
    `report_position`, then continue `auto_walk:13,6` or route normally to
    `(13,15)` for the direct `(13,15)->DOWN` check.

### 2026-06-07 continuation after the `(11,17)` battle

- Post-combat baseline:
  - `POSITION map=0x1A x=11 y=17`
  - runtime overlay still active.
- Attempted to route to the nearby direct-probe origin `(13,15)`.
  The route exposed more one-way-looking north edges in the open lower pocket.
- Additional clean same-origin blockers injected:
  - `(12,17)->UP` blocked, modeled as `(12,16).south`.
  - `(13,17)->UP` blocked, modeled as `(13,16).south`.
  - `(14,17)->UP` blocked, modeled as `(14,16).south`.
- Clean passable / no-promote evidence:
  - `(12,17)->RIGHT` moved to `(13,17)`.
  - `(13,17)->RIGHT` moved to `(14,17)`.
  - `(14,17)->LEFT` moved to `(13,17)`.
  - `(13,17)->LEFT` moved to `(12,17)`, then a new battle started.
- Contaminated / still-open evidence:
  - `(11,17)->UP` into `(11,16)` has route-only blocked evidence and still
    needs a direct same-origin probe from `(11,17)` after combat.
  - `(13,15)->DOWN` into `(13,16)` still needs same-origin direct probing from
    `(13,15)` if a clean route to that origin remains available.
- Current paused state:
  - A Druinlord battle started immediately after `(13,17)->LEFT` moved to
    `(12,17)`.
  - Current live position is `map=0x1A x=12 y=17`, in battle.
  - Runtime block count is 41.
  - Next live step after combat clears: re-establish field state with
    `report_position`, move to `(11,17)` if possible, and directly probe
    `(11,17)->UP`.

### 2026-06-07 post-patch/reload confirmation

- Later SE-pocket pruning collapsed the false Silver Harp route from the B3
  southeast-stair component; with the runtime overlay injected,
  `auto_walk:13,6` from `(12,19)` returned `No path found`.
- The confirmed overlay was promoted to `map_reader.lua` and covered by
  `test_map_reader.lua`.
- User manually reloaded Lua in FCEUX and confirmed only the local
  `Northeast Stairs Up` return stair is reachable from this component.
- Conclusion: this B3 component is a dead-end/trap pocket for object
  navigation; the false Silver Harp and remote-stair routes are closed off in
  the permanent model.

## 2026-06-07 Garin's Grave B2 Northwest Stairs false route cleanup

- Live target: B2 `Northwest Stairs Down` at `(1,1)`.
- Starting state:
  - user had worked back to Garin's Grave B2 and the planner was trying to use
    the old southwest-side route through the `(5,10)` knot
  - fresh baseline confirmed `POSITION map=0x19 x=5 y=10`
  - `RUNTIME_BLOCKS map=0x19 none`
- Evidence for `(5,9).south`:
  - normal-route movement from `(5,11)->UP` reached `(5,10)`
  - repeated route attempts from `(5,10)->UP` only twitched/cancelled
  - same-origin `probe_edge:UP` from `(5,10)` blocked into `(5,9)`:
    `EDGE_PROBE_RESULT ... status=blocked ... reason=raw_hold_timeout`
  - injected runtime edge with `add_blocked_edge:25,5,10,UP`
  - readback: `RUNTIME_BLOCK map=0x19 x=5 y=9 key=5,9 dirs=south`
- Evidence for `(2,10).west`:
  - after `(5,9).south` was injected, `debug_pathfind_to:1,1` rerouted:
    `2 west, 1 south, 2 west, 1 north, 1 east, 7 north, 1 west, 2 north`
  - autowalk reached `(1,10)` and then `(1,10)->RIGHT` into `(2,10)` blocked
    twice under seam retry with `blocked=9 moved=0`
  - same-origin `probe_edge:RIGHT` from `(1,10)` also blocked
  - injected runtime edge with `add_blocked_edge:25,1,10,RIGHT`
  - readback: `RUNTIME_BLOCK map=0x19 x=2 y=10 key=2,10 dirs=west`
- Route bracketing:
  - from `(1,10)`, `debug_pathfind_to:1,1` returned `No path found`
  - from `(1,10)`, planner could still route to `(11,2)`, `(12,1)`, and
    `(12,10)`, so the new blockers did not isolate the whole southwest side
  - autowalk returned to `(11,2)` after one Wolf battle at `(4,11)` and one
    Skeleton/REPEL interruption around `(13,10)`; battle-contaminated seam
    attempts were not promoted
  - clean `probe_edge:RIGHT` from `(4,11)` moved into `(5,11)`
  - clean `probe_edge:UP` from `(13,10)` moved into `(13,9)`
  - autowalk then completed to `Stairs Up` `(11,2)`
  - from `(11,2)`, `debug_pathfind_to:1,1` returned `No path found`
- Permanent sync:
  - added B2 `(5,9).south` and `(2,10).west` to `map_reader.lua`
  - added focused assertions to
    `garins_grave_b2_southwest_stair_route_edges_are_directional`
  - red `lua5.1 test_map_reader.lua` failed first on missing
    `B2 (2,10).west`
  - green `lua5.1 test_map_reader.lua` passed 49 tests
- Current live anchor:
  - B2 `(11,2)` / `Stairs Up`
  - runtime overlay contains `(5,9).south` and `(2,10).west`
  - reload FCEUX Lua before judging the permanent source patch without runtime
    injections

## 2026-06-07 Garin's Grave B2 Central Stairs cleanup

- Live target: B2 `Central Stairs Down` at `(5,6)`.
- Starting request: examine B2 `(13,4)->WEST`.
- Baseline:
  - fresh `report_position` confirmed `POSITION map=0x19 x=13 y=4`
  - current runtime overlay was empty before the new central-stair pass
- Confirmed same-origin blocker:
  - repeated manual west attempts from `(13,4)` twitched/cancelled
  - same-origin `probe_edge:LEFT` from `(13,4)` blocked into `(12,4)`
  - injected with `add_blocked_edge:25,13,4,LEFT`
  - readback: `RUNTIME_BLOCKS map=0x19 count=1`
  - model target for promotion: `(12,4).east`
- Reroute after `(12,4).east`:
  - `debug_pathfind_to:5,6` from `(13,4)` rerouted to
    `4 south, 8 west, 2 north`
  - autowalk followed the southern route and exposed route-only blocked seams:
    - `(9,8)->LEFT` into `(8,8)` blocked under route retry, then rerouted
      around it; needs same-origin probe before promotion if still relevant
    - `(13,6)->LEFT` into `(12,6)` blocked under route retry after the reroute;
      needs same-origin probe before promotion if still relevant
  - passable cleanup/no-promote evidence during reroutes:
    - `(12,8)->RIGHT` into `(13,8)` moved after seam retry
    - `(13,7)->UP` into `(13,6)` moved after seam retry
    - `(13,7)->DOWN` into `(13,8)` moved after seam retry
- Current paused state:
  - battle started immediately after a route retry at `(11,8)->LEFT`
  - current live position in the battle snapshot: `map=0x19 x=11 y=8`
  - do not promote `(11,8)->LEFT`; it is battle-contaminated
  - next step after combat clears: `report_position`, then either direct-probe
    `(11,8)->LEFT` if still at `(11,8)`, or resume `auto_walk:5,6` and probe
    the next clean same-origin blocker it exposes
- Continuation after that battle:
  - fresh post-combat `report_position` confirmed `map=0x19 x=11 y=8`
  - same-origin `probe_edge:LEFT` moved into `(10,8)`, so
    `(11,8)->LEFT` is passable/no-promote
  - a new Wolf battle started immediately after the probe landed at
    `map=0x19 x=10 y=8`
  - next step after this battle clears: `report_position`, then resume
    `auto_walk:5,6`; if route returns to the older route-only candidates,
    prioritize same-origin probes for `(13,6)->LEFT` into `(12,6)` or
    `(9,8)->LEFT` into `(8,8)` only when standing on those exact origins
- Continuation after the second Wolf battle:
  - fresh baseline: `POSITION map=0x19 x=10 y=8`
  - runtime overlay still contained only `(12,4).east`
  - resumed `auto_walk:5,6`; route reached `(9,8)` and again blocked
    `(9,8)->LEFT` into `(8,8)` under route retry:
    `SEAM_OBSERVATION ... cell=(8,8) approach=east result=blocked`
  - a later same-origin `probe_edge:LEFT` from normally reached `(9,8)`
    also blocked with `raw_hold_timeout`
  - injected `add_blocked_edge:25,9,8,LEFT`; readback:
    `RUNTIME_BLOCK map=0x19 x=8 y=8 key=8,8 dirs=east`
- Continuation after the `(11,8)` retry/battle:
  - route retry at `(11,8)->RIGHT` was interrupted by a Metal Scorpion battle
  - post-combat same-origin `probe_edge:RIGHT` from `(11,8)` moved into
    `(12,8)`, so `(11,8)->RIGHT` is passable/no-promote
  - resumed `auto_walk:5,6` from `(12,8)`; route moved to `(13,8)`,
    then `(13,7)`, then `(13,6)` after a timing retry on `(13,7)->UP`
  - route then repeatedly blocked `(13,6)->LEFT` into `(12,6)`, and reroute
    collapsed to `No path found`
  - same-origin `probe_edge:LEFT` from normally reached `(13,6)` also blocked
    with `raw_hold_timeout`
  - injected `add_blocked_edge:25,13,6,LEFT`; readback:
    `RUNTIME_BLOCK map=0x19 x=12 y=6 key=12,6 dirs=east`
  - with `(12,4).east`, `(8,8).east`, and `(12,6).east` active,
    `debug_pathfind_to:5,6` from `(13,6)` returned
    `No path found [no_path] (visited=52 path=0)`
- Permanent sync:
  - promoted B2 `(12,4).east`, `(8,8).east`, and `(12,6).east` to
    `map_reader.lua`
  - extended `test_map_reader.lua` assertions in
    `garins_grave_b2_southwest_stair_route_edges_are_directional`
  - red `lua5.1 test_map_reader.lua` failed first on missing
    `B2 (8,8).east`
  - green `lua5.1 test_map_reader.lua` passed 49 tests
  - `luac5.1 -p map_reader.lua test_map_reader.lua` passed
  - `git diff --check -- map_reader.lua test_map_reader.lua session_handoff.md PLAYTESTING.md work_notes/current_investigation.md`
    passed
- Post-reload verification:
  - FCEUX log restarted at `2026-06-07 13:16:29`
  - current anchor: `POSITION map=0x19 x=11 y=2`
  - `RUNTIME_BLOCKS map=0x19 none`
  - from that clean source-loaded state,
    `debug_pathfind_to:5,6` returned
    `No path found [no_path] (visited=50 path=0)`
  - the same batch also checked the prior Northwest target:
    `debug_pathfind_to:1,1` returned
    `No path found [no_path] (visited=48 path=0)`

## 2026-06-07 Garin's Grave B3 Northwest Stairs Up pocket cleanup

- Starting anchor:
  - user used the B2 Northwest stairs and arrived on B3 at
    `Northwest Stairs Up` `(14,1)`
  - target was the west chest / likely Cursed Belt at `(1,1)`
- Clean same-origin blockers:
  - `(10,1)->LEFT` blocked into `(9,1)`; runtime/model target `(9,1).east`
  - `(12,2)->DOWN`, `(11,2)->DOWN`, `(10,2)->DOWN`, `(15,2)->DOWN`,
    `(13,2)->DOWN`, and `(14,2)->DOWN` all blocked into row 3; runtime/model
    target `(10..15,3).north`
  - `(15,1)->RIGHT` blocked into `(16,1)`; runtime/model target `(16,1).west`
  - `(15,2)->RIGHT` blocked into `(16,2)`; runtime/model target `(16,2).west`
- Hidden-wall candidates:
  - `(10,2)->LEFT` into `(9,2)` blocked under same-origin `probe_edge:LEFT`
    and stayed a non-walkable wall, so no passthrough was added
  - `(9,3)->UP` became unreachable after the row-3 north wall and `(16,1/2)`
    closures; leave it as an untested hidden sibling rather than modeling a
    passthrough
- Final live state before source reload:
  - hero at B3 `(15,2)`
  - `RUNTIME_BLOCKS map=0x1A count=9`:
    `(9,1).east`, `(16,1).west`, `(16,2).west`, and `(10..15,3).north`
  - `debug_pathfind_to:1,1` returned `No path found`
  - `debug_pathfind_to:9,3` returned `No path found`
  - `debug_route_frontier:1,1,60` reported `reachable=12`,
    `target_reachable=false`, and only one hidden bridge candidate left:
    the already-tested `(10,2)->LEFT` non-walkable wall candidate
  - `pathability_filter:reachable` reported exactly one object:
    `Northwest Stairs Up`
- Permanent sync:
  - patched `map_reader.lua` with the nine B3 NW-pocket blockers
  - extended B3 assertions in `test_map_reader.lua`
  - `lua5.1 test_map_reader.lua` passed 49 tests
  - `luac5.1 -p map_reader.lua test_map_reader.lua` passed
  - `git diff --check -- map_reader.lua test_map_reader.lua` passed
- Next check after manual FCEUX Lua reload:
  - done after user reload:
    - user verified `debug_pathfind_to:1,1` still returned `No path found`
    - fresh log showed `RUNTIME_BLOCKS map=0x1A none`
    - from B3 `(15,2)`, `pathability_filter:reachable` and `current_object`
      both reported only `Northwest Stairs Up`

## 2026-06-07 B2 Northwest Stairs regression recheck from live `(11,2)`

- User returned to B2 and reported the path to `Northwest Stairs Down` `(1,1)`
  was closed again, although we had earlier believed the stair hub route was
  open.
- Fresh baseline:
  - `POSITION map=0x19(Garin's Grave B2) x=11 y=2`
  - `RUNTIME_BLOCKS map=0x19 none`
  - `debug_pathfind_to:1,1` and `debug_pathfind_to_skip_npcs:1,1` both
    returned `No path found`
  - `pathability_filter:reachable` listed exactly four objects:
    `Stairs Up`, `Northeast Stairs Down`, `Southeast Stairs Down`, and
    `Southwest Stairs Down`
- `debug_route_frontier:1,1,80` and
  `debug_route_frontier_skip_npcs:1,1,80` agreed:
  - `reachable=47`, `target_reachable=false`, `target_side=27`
  - `bridge_candidates=7`, `hidden_bridge_candidates=0`
  - all seven bridge candidates were modeled directional blockers
- Fresh same-origin probes from normally walked origins confirmed all seven
  bridge candidates still block with `reason=raw_hold_timeout`:
  - `(1,10)->UP` into `(1,9)`
  - `(1,10)->RIGHT` into `(2,10)`
  - `(2,11)->UP` into `(2,10)`
  - `(3,10)->LEFT` into `(2,10)`
  - `(3,10)->UP` into `(3,9)`
  - `(4,10)->UP` into `(4,9)`
  - `(5,10)->UP` into `(5,9)`
- Battle contamination:
  - first `(1,10)->UP` probe was refused because a Skeleton battle had just
    started; after the fight cleared, the clean retry from the same coordinate
    blocked normally
- Final check from B2 `(4,10)`:
  - `RUNTIME_BLOCKS map=0x19 none`
  - normal and skip-NPC pathfinds to `(1,1)` still returned `No path found`
  - frontier remained at the same seven bridge candidates with no hidden
    bridges
- Conclusion:
  - the current B2 no-route to `Northwest Stairs Down` is caused by permanent
    directional geometry, not runtime overlays, NPCs, or stale combat state
  - the older 2026-06-05 "all six B2 stairs reachable" route was false planner
    geometry through row 9 / `(2,10)`, and is superseded by the later live
    probes
  - keep the current B2 Northwest route closed unless new normal-walked live
    evidence from another branch contradicts it

## 2026-06-07 B3 Southeast Stairs Up belt-route recheck

- User repositioned to the bottom of the B2 southeast staircase, landing on B3
  at `Southeast Stairs Up` `(18,13)`.
- Baseline:
  - `POSITION map=0x1A(Garin's Grave B3) x=18 y=13`
  - `RUNTIME_BLOCKS map=0x1A none`
  - `debug_pathfind_to:1,1` and `debug_pathfind_to_skip_npcs:1,1` both
    returned `No path found`
  - `pathability_filter:reachable` reported exactly one object:
    `Southeast Stairs Up`
- Frontier:
  - `debug_route_frontier:1,1,100` and skip-NPC variant agreed:
    `reachable=90`, `target_reachable=false`, `target_side=55`,
    `bridge_candidates=5`, `hidden_bridge_candidates=0`
  - the only bridges into the west chest / likely Cursed Belt component were
    bottom-row north edges:
    `(1,19)->UP`, `(2,19)->UP`, `(3,19)->UP`, `(4,19)->UP`, and `(5,19)->UP`
- Fresh walked-origin probes:
  - a Druinlord interrupted the first walk toward `(1,19)` at `(6,19)`; after
    combat cleared, movement resumed from the live field position
  - `(5,19)->UP` into `(5,18)` blocked with `raw_hold_timeout`
  - `(4,19)->UP` into `(4,18)` blocked with `raw_hold_timeout`
  - `(3,19)->UP` into `(3,18)` blocked with `raw_hold_timeout`
  - `(2,19)->UP` into `(2,18)` blocked with `raw_hold_timeout`
  - `(1,19)->UP` into `(1,18)` blocked with `raw_hold_timeout`
- Final check from `(1,19)`:
  - `RUNTIME_BLOCKS map=0x1A none`
  - normal and skip-NPC pathfinds to `(1,1)` still returned `No path found`
  - frontier remained the same five bridge candidates with
    `hidden_bridge_candidates=0`
  - reachable-object filter still reported only `Southeast Stairs Up`
- Hazard policy check:
  - `debug_pathfind_to_allow_hazards:1,1` and
    `debug_pathfind_to_skip_npcs_allow_hazards:1,1` also returned
    `No path found` with `hazards=0`
  - allow-hazard frontiers matched the normal five bridge candidates with
    `hidden_bridge_candidates=0`
- Conclusion:
  - the B3 southeast-stair component is not a live route to the west chest /
    likely Cursed Belt
  - this confirms the earlier SE-side closure after a fresh normal-entry pass
    from B2's reachable southeast stair
  - current live position after this pass: B3 `(1,19)`

## 2026-06-07 B3 possible west-chest-to-NW-stair return route recheck

- User manually explored back from the west chest / likely Cursed Belt side and
  reported being able to walk back to the B3 `Northwest Stairs Up`, suggesting
  the NW stair may be a return-only exit with a one-way seam preventing reentry.
- Fresh baseline after that report:
  - `POSITION map=0x1A(Garin's Grave B3) x=16 y=11`
  - `RUNTIME_BLOCKS map=0x1A none`
  - `pathability_filter:reachable` reported `No objects`
  - normal and skip-NPC `debug_pathfind_to` checks to `(1,1)`, `(14,1)`, and
    `(9,5)` all returned `No path found`
- Frontier from the `(16,11)` / east-side component toward NW stair `(14,1)`
  listed many modeled directional blockers but no hidden bridge candidates.
  Same-origin probes confirmed the nearest modeled bridges from this side:
  - `(16,10)->UP` into `(16,9)` blocked
  - `(17,9)->LEFT` into `(16,9)` blocked
  - `(15,10)->UP` into `(15,9)` blocked
  - `(15,10)->LEFT` into `(14,10)` blocked
  - `(15,11)->LEFT` into `(14,11)` blocked
  - `(15,11)->DOWN` into `(15,12)` blocked
- Autowalk toward candidate origin `(17,4)` showed normal movement through the
  east-side loop and was interrupted once by a Specter battle at `(19,5)`.
  After combat cleared, same-origin probes continued:
  - `(19,5)->UP` into `(19,4)` moved
  - `(19,4)->UP` into `(19,3)` blocked
  - `(18,4)->UP` into `(18,3)` blocked
  - `(17,4)->LEFT` into `(16,4)` blocked
  - `(17,4)->UP` into `(17,3)` blocked
  - `(17,4)->DOWN` into `(17,5)` blocked
- Current interpretation:
  - live evidence supports the user's one-way/return-only read in principle,
    but the currently occupied east-side component is not the return seam
  - do not remove the B3 top/east directional blockers from this evidence;
    they matched live probes from the tested side
  - next useful step is to reposition to the actual manual return seam or to
    the NW stair after arriving from the chest-side route, then capture the
    reverse/forward pair from that exact location
