# Session Handoff - Active Resume

Updated: 2026-06-07

## Current State

- Active work is Garin's Grave / Grave of Garinham route decoding in FCEUX.
- User is wrapping for the night. FCEUX source changes from the final top-edge
  passthrough patch still need a manual Lua reload before live verification.
- The Silver Harp route is already stable enough for current playtesting, and
  the save already had the Silver Harp in inventory when the chest was opened.
- The unresolved gameplay target is the west chest / likely Cursed Belt at B3
  `(1,1)`.

## Latest Finding

- User manually found a real B3 false blocker at `10,0 west`.
- Root cause was the generic dungeon-edge walkability rule, not a missing
  directional blocker:
  - B3 top-row cells are normally treated as edge boundary cells.
  - Live movement proved `(9,0)<->(10,0)` is standable and bidirectionally
    passable.
  - `map_reader.lua` now scopes B3 passthroughs for `(9,0)` and `(10,0)`.
- Static regression coverage now verifies both cells report passthrough
  walkability and that pathfinding from `(10,0)` to the west chest `(1,1)`
  succeeds.
- This supersedes the earlier "B3 Northwest Stairs Up pocket is local stair
  only" conclusion for the Cursed Belt question.

## Garin's Grave Route Status

- B2 route hub from `Stairs Up` `(11,2)`:
  - permanent model reaches `Stairs Up`, `Northeast Stairs Down`,
    `Southeast Stairs Down`, and `Southwest Stairs Down`
  - permanent model returns `No path found` for `Northwest Stairs Down`
    `(1,1)` and `Central Stairs Down` `(5,6)`
- B3 southeast-stair component:
  - rechecked from B2's reachable southeast stair
  - path to west chest `(1,1)` remains closed
  - reachable-object filter reported only local `Southeast Stairs Up`
- B3 northeast-stair and southeast/up pockets:
  - false remote-object routes were pruned with same-origin live blocker
    evidence
  - after reload checks, each reduced to only the local return stair
- B3 lower-stair / Silver Harp side:
  - route to the Silver Harp chest `(13,6)` and return to `Lower Stairs Down`
    `(10,9)` are stable under live FCEUX movement
- B4 connector:
  - west/east stair connector remains stable both directions from earlier live
    testing

## Code And Data Changed

- `map_reader.lua`
  - promoted confirmed Garin's Grave B2/B3 directional blockers from live
    same-origin probes
  - added B3 passthroughs for `(9,0)` and `(10,0)`
- `test_map_reader.lua`
  - expanded B2/B3 Garin's Grave regression assertions
  - added B3 passthrough/pathfinding coverage for the top-row west-chest route
- Docs updated:
  - `PLAYTESTING.md`
  - `project_resources/maps/garins_grave/README.md`
  - `work_notes/current_investigation.md`
  - archived full detailed handoff at
    `handoff_archive/HANDOFF_2026-06-07_garins_grave_b2_b3_wrapup_full.md`

## Verification

- `lua5.1 test_map_reader.lua`: passed 49 tests
- `luac5.1 -p map_reader.lua test_map_reader.lua`: passed
- `git diff --check -- map_reader.lua test_map_reader.lua session_handoff.md PLAYTESTING.md work_notes/current_investigation.md project_resources/maps/garins_grave/README.md`: passed

## Next Session

1. Manually reload Lua in FCEUX.
2. From the B3 NW/top-row side, verify the final patch live:
   - `debug_pathfind_to:1,1`
   - `pathability_filter:reachable`
   - `current_object`
3. If the path to `(1,1)` opens, follow it and confirm whether the chest is the
   Cursed Belt.
4. If live movement exposes another blocker, continue the same normal-walked
   same-origin evidence loop before promoting anything else.
