# Session Handoff - Active Resume

Updated: 2026-06-15

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
- Current unresolved gameplay target is the west chest / likely Cursed Belt on
  B3 at `(1,1)`.

## Current Durable Finding

- User manually found a real B3 false blocker at `10,0 west`.
- Root cause was generic dungeon-edge walkability, not a directional blocker:
  B3 top-row cells `(9,0)` and `(10,0)` are standable and bidirectionally
  passable.
- `map_reader.lua` now scopes B3 passthroughs for `(9,0)` and `(10,0)`.
- Static coverage confirms both cells report passthrough walkability and that
  pathfinding from `(10,0)` to west chest `(1,1)` succeeds.
- This supersedes the earlier "B3 Northwest Stairs Up pocket is local stair
  only" conclusion for the Cursed Belt question.

## Route Status

- B2 from `Stairs Up` `(11,2)`:
  - reachable: `Stairs Up`, `Northeast Stairs Down`, `Southeast Stairs Down`,
    `Southwest Stairs Down`
  - closed by current permanent model: `Northwest Stairs Down` `(1,1)` and
    `Central Stairs Down` `(5,6)`
- B3 southeast-stair component:
  - west chest `(1,1)` remains closed from this component
  - reachable-object filter reports only local `Southeast Stairs Up`
- B3 northeast-stair and southeast/up pockets:
  - false remote-object routes are pruned; each reports only the local return
    stair after reload checks
- B3 lower-stair / Silver Harp side:
  - route to Silver Harp chest `(13,6)` and return to `Lower Stairs Down`
    `(10,9)` are stable under live FCEUX movement
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

## Next Live Steps

1. Manually reload Lua in FCEUX.
2. From the B3 NW/top-row side, verify the final passthrough patch live:
   - `debug_pathfind_to:1,1`
   - `pathability_filter:reachable`
   - `current_object`
3. If the path to `(1,1)` opens, follow it and confirm whether the chest is the
   Cursed Belt.
4. If live movement exposes another blocker, continue the normal-walked
   same-origin evidence loop before promoting permanent map data.
