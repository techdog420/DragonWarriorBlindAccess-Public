# Session Handoff - Active Resume

Updated: 2026-06-16

## Current Emulator Note

- FCEUX is the normal gameplay and agent-driven runtime again. BizHawk is
  opt-in for explicit automation/debug/reload/profiling tasks only.
- Use `./launch_dw.sh` for normal work. Use `./launch_dw.sh --emulator bizhawk`
  only when the task specifically benefits from BizHawk's reload/debug tooling.
- FCEUX source changes still require a manual Lua reload before live
  verification.

## Active Work

- Active map task is Garin's Grave / Grave of Garinham route decoding.
- The Silver Harp route is stable enough for current playtesting.
- The B3 west chest has been opened and confirmed as the Cursed Belt.
- B1 entrance/down-stair routing is now live-validated both directions; current
  cleanup focus is final reload/recheck of patched Garin's Grave route data.
- `auto_walk_blocker` now keeps the manual blocker workflow but runs the normal
  seam retry before reporting timing-suspect movement-start timeouts as
  patchable blockers. FCEUX needs a manual Lua reload before live retesting this
  behavior.

## Current Durable Finding

- Latest B3 Cursed Belt search (`2026-06-16`) found the route from
  `Northwest Stairs Up` `(14,1)` to west chest `(1,1)`. After manual FCEUX
  reload cleared runtime blockers, `auto_walk:1,1` reached the chest and
  `auto_walk:14,1` returned to the NW stair with no persistent runtime overlay.
- The working route combines the top-edge false-boundary seam
  `(8,0)->(9,0)->(10,0)`, the left-edge strip `(0,2)` through `(0,6)`, and
  the chest-side false-wall cells `(1,2)` and `(2,2)`.
- The prior southwest/current component blockers remain promoted:
  - `(3,1).west`
  - `(5,14).west`
  - `(5,15).east/west`
  - `(8,14).east/north/west`
  - `(8,15).west`
  - `(4,16).north/south`
  - `(5,16).south`
  - `(6,16).north/south`
  - `(7,16).north/south`
  - `(8,16).south`
  - `(6,18).north`
  - `(8,18).north`
- With the equivalent runtime overlay active, `debug_route_frontier:1,1,100`
  reported `target_reachable=false` and `hidden_bridge_candidates=0` from the
  current B3 component. The remaining false-candidate edges checked during the
  pass matched blockers already in the permanent model.
- The old conclusion that the top edge alone was not enough is superseded by
  the full left-edge/top-edge route. `(0,2)->DOWN` into `(0,3)` is a real
  bidirectional left-edge seam, live probes proved the lower left-edge turn at
  `(0,6)`, and the top-row return requires the false-boundary cell `(8,0)`.
  `map_reader.lua` now scopes B3 passthroughs for `(0,2)` through `(0,6)`,
  `(8,0)`, `(9,0)`, and `(10,0)`.
- Same-origin probes also closed false shortcuts exposed while validating the
  route:
  - `(3,1).east` from `(4,1)->LEFT`
  - `(1,3).west` from `(0,3)->RIGHT`
  - `(2,3).south` from `(2,4)->UP`
  - `(3,3).east` from `(4,3)->LEFT`
  - `(1,4).east` from `(2,4)->LEFT`
  - `(1,4).west` from `(0,4)->RIGHT`
  - `(1,5).east` from `(2,5)->LEFT`
  - `(1,5).south` from `(1,6)->UP`
  - `(1,5).west` from `(0,5)->RIGHT`
  - `(9,1).west` from `(8,1)->RIGHT`
  - `(11,1).west` from `(10,1)->RIGHT`
- These latest shortcut closures are patched in `map_reader.lua` and covered
  in `test_map_reader.lua`; FCEUX needs another manual Lua reload before the
  live planner can use this cleaner permanent model.
- After the Cursed Belt was claimed, the B3 `Northwest Stairs Up` component
  still over-reported `Upper Stairs Down` `(9,5)`, `Southeast Stairs Up`
  `(18,13)`, and `Southwest Stairs Up` `(2,17)` as reachable. Live FCEUX
  auto-walk plus same-origin probes confirmed two blockers:
  `(5,1)->DOWN` into `(5,2)` and `(1,6)->DOWN` into `(1,7)`. With runtime
  equivalents active, `debug_pathfind_to` for all three stair targets returned
  `No path found`, and `pathability_filter:reachable` reported only the opened
  chest and local `Northwest Stairs Up`. These are now patched as
  `(5,2).north` and `(1,7).north` in `map_reader.lua` with test coverage.
- Follow-up B2 escape hunts from the west-chest return side found a live route
  from `Northwest Stairs Down` `(1,1)` / the northwest landing `(1,2)` back to
  `Stairs Up` `(11,2)`: enter the left-edge false-boundary strip at `(0,1)` or
  `(0,2)`, follow it down through `(0,11)`, exit right to `(1,11)`, then take
  the bottom/right corridor back to `(11,2)`.
- Same-origin B2 probes promoted the new scoped left-edge passthrough cells
  `(0,1)` through `(0,11)` and closed false shortcuts at
  `(1,2).north/south`, `(2,1).west`, `(2,2).west`, `(2,8).west`,
  `(1,9).north`, and `(1,9).west`. FCEUX needs a manual Lua reload before
  this B2 cleanup affects live planning.

## Route Status

- B1 entrance / first down stairs:
  - live FCEUX round-trip between `Stairs to Garinham` `(6,11)` and
    `Stairs Down` `(1,18)` succeeded on 2026-06-16.
  - same-origin probes from normally walked `(3,17)` blocked
    `(3,17)->RIGHT` into `(4,17)` twice, closing the false short return route;
    this is patched as `(4,17).west`.
  - follow-up same-origin probes from normally reached `(17,9)` blocked
    `(17,9)->LEFT` into `(16,9)` twice, superseding older mixed evidence; this
    is patched as `(16,9).east`.
  - before the next reload, the current live runtime overlay was pulled and
    promoted as `(17,8).south`, `(18,8).north`, `(7,10).north`, and
    `(19,12).north`.
  - follow-up `auto_walk_blocker` cleanup confirmed `(16,7)->DOWN` into
    `(16,8)`, normally reached `(17,18)->DOWN` into `(17,19)`, and the
    follow-up east/west entries `(18,19)->LEFT` and `(16,19)->RIGHT` into
    `(17,19)` as blocked with repeated same-origin probes; these are patched as
    `(16,8).north` and `(17,19).north/east/west`. Noisy `(18,8).south`
    remains unpromoted.
- B2 from `Stairs Up` `(11,2)`:
  - reachable: `Stairs Up`, `Northeast Stairs Down`, `Southeast Stairs Down`,
    `Southwest Stairs Down`
  - closed by prior permanent model: `Northwest Stairs Down` `(1,1)` and
    `Central Stairs Down` `(5,6)`
  - after the new B2 left-edge passthrough patch reloads, recheck any reverse
    route from `Stairs Up` to `Northwest Stairs Down` before treating it as a
    player-facing two-way route
- B2 west-chest return side:
  - route from `Northwest Stairs Down` `(1,1)` / northwest landing `(1,2)` to
    `Stairs Up` `(11,2)` is live-verified via the left-edge false-boundary
    strip and bottom/right corridor
- B3 southeast-stair component:
  - west chest `(1,1)` remains closed from this component
  - reachable-object filter reports only local `Southeast Stairs Up`
- B3 northeast-stair and southeast/up pockets:
  - false remote-object routes are pruned; each reports only the local return
    stair after reload checks
- B3 northwest/top-row pocket:
  - `(9,0)<->(10,0)` remains a valid top-row seam
  - west chest `(1,1)` is now reachable from `Northwest Stairs Up` through the
    validated top-edge and left-edge route
  - after the new object-pruning blockers reload, expected reachable objects
    from this pocket are only the opened chest and `Northwest Stairs Up`
- B3 west chest return side:
  - return from chest `(1,1)` back to `Northwest Stairs Up` is live-verified
    via the left-edge false-boundary strip and top-row false-boundary return
- B3 lower-stair / Silver Harp side:
  - route to Silver Harp chest `(13,6)` and return to `Lower Stairs Down`
    `(10,9)` are stable under live FCEUX movement
- B3 current southwest-side/Cursed Belt search component:
  - tonight's probe-verified blockers are now permanent map data
  - prior runtime overlay equivalent had 12 entries and found no hidden bridge
    candidates to west chest `(1,1)`
  - live stop point in the scratchpad was B3 `(8,3)` after direct verification
    of already-modeled blockers
- B4 connector:
  - west/east stair connector remains stable both directions

## Recent Cleanup

- `edge_flow_guard.lua` now centralizes mutually-exclusive edge-flow command
  guards.
- `probe_edge`, `probe_edge_verify`, `probe_edge_after_raw`, and
  `probe_edge_after_raw_to` refuse while any edge probe/verifier/seeded probe
  state is active.
- Regression coverage: `test_edge_flow_guard.lua`; registered in
  `run_tests.py`.
- `field_action_guard.lua` now centralizes field-action refusal reasons for
  auto-walk, teleport, and object hotkey gating.
- Movement-changing actions refuse instead of auto-closing UI while command
  menu, submenu, Yes/No prompt, merchant UI, dialogue, upper dialogue,
  survey/crawl/edge flows, or an active route can consume input. Survey-safe
  internal auto-walks keep their explicit escape hatch.
- Manual FCEUX verification was confirmed in `dw_debug.log`: command-menu and
  dialogue states blocked auto-walk and teleport hotkeys, and normal actions
  resumed after the UI cleared.
- Regression coverage: `test_field_action_guard.lua` plus
  `test_route_manager.lua` guard-option coverage; registered in
  `run_tests.py`.
- Verification from the cleanup pass:
  - `lua5.1 test_edge_flow_guard.lua`: passed 4 tests
  - `lua5.1 test_field_action_guard.lua`: passed 5 tests
  - `lua5.1 test_route_manager.lua`: passed 96 tests
  - `lua5.1 test_hotkeys.lua`: passed 27 tests
  - `luac5.1 -p main.lua route_manager.lua field_action_guard.lua
    test_field_action_guard.lua`: passed
  - `python3 run_tests.py --allow-missing-speech-dep`: passed with the known
    WSL speech-dependency warning
- `auto_walk_blocker` / `auto_walk_blocker:X,Y` now run normal local-map
  autowalk in first-blocker mode: on the first blocked queued step they stop,
  log `AUTO_WALK_BLOCKER_FOUND`, speak the failed edge, and print the matching
  `add_blocked_edge:X,Y,DIR` runtime-patch suggestion. The command reports
  only; it does not inject runtime blockers automatically, and NPC blockers are
  called out separately to avoid accidental geometry patches.

## Next Live Steps

1. Manually reload Lua in FCEUX so the latest B2/B3 2026-06-16 cleanup is
   active without runtime overlays; this now also includes the B1 `(4,17).west`
   and `(16,9).east` route-cleanup patches.
2. From B1 `Stairs Down` `(1,18)`, rerun the return route to
   `Stairs to Garinham` `(6,11)` after reload and confirm it avoids the old
   `(3,17)->RIGHT` and `(17,9)->LEFT` false shortcuts.
3. From B3 `Northwest Stairs Up`, rerun `pathability_filter:reachable` and
   confirm the permanent model now reports only the opened chest plus local
   return stair with `RUNTIME_BLOCKS none`.
4. If checking the B2 escape model, start from `Northwest Stairs Down` `(1,1)`
   or the northwest landing `(1,2)` and verify the planner route back to
   `Stairs Up` `(11,2)` without runtime blockers.
5. If a future object route from B2 `Stairs Up` to `Northwest Stairs Down`
   appears, live-verify that reverse direction before calling it durable.
