# Current Investigation Scratchpad

This is a dated evidence log through the 2026-09-22 map-cleanup pass. Older
"Next Work," branch, frame, and uncommitted-change notes below are historical.
Use `session_handoff.md` and `TASKS.md` for the current resume point and
roadmap; establish fresh FCEUX state before reusing a live observation.

## 2026-09-22 Tantegel Sun Shrine and castle completion

- PLAYER ACCEPTED / MAP0X0C COMPLETE: from entrance stair `(0,4)`, Chest
  `chest_17` at `(4,5)` completed an 11-step approach and 11-step return with
  no retry, replan, or reroute. Old Man `npc_10` at `(4,6)`, using stand
  `(4,7)`, completed 7 steps each way and TALK logged `VISITED_AUTO`.
- TIMING ONLY: the first step of each Old Man leg used one bounded timeout
  retry, then crossed the same seam and completed the original route. No seam
  brute force, drift, runtime block, replan, or reroute occurred.
- AUDIT SCOPE: `audit_town` refused with `Town audit is available in towns and
  Tantegel only`; map0x0C is outside its supported scope. The refusal was a
  no-op. Live round trips already cover both shrine targets.
- FINAL CHECKPOINT: frame 49800 is at `(0,4)`, path target nil, and runtime
  blocks none. No map change is warranted. Main floor, Throne Room, and Sun
  Shrine are all player-accepted, closing the Tantegel Castle pass.

## 2026-09-22 Tantegel Throne Room third chest and floor acceptance

- PLAYER ACCEPTED / FLOOR COMPLETE: after reloading the permanent correction,
  chest 3 completed 19 steps each way. The return used the west-side route in
  its initial plan and had no retry, replan, or reroute. Guard 1, Guard 2,
  Guard 3, and King completed 12/12, 6/6, 6/6, and 9/9-step round trips; each
  TALK logged `VISITED_AUTO`. The King's return retried its first step twice
  for cadence, then crossed it and completed without rerouting. Final frame
  19920: `(8,8)`, door `(4,7)` open, nil route, no runtime blocks. No further
  map0x05 work is indicated.

- POST-RELOAD ACCEPTANCE: the first two chest round trips passed cleanly after
  the earlier south/right-wall correction was loaded.
- CLEAN FAILURE: third chest `chest_6` at `(6,1)` was reached in 19 steps from
  stair `(8,8)`. Its return initially planned east across the top row, then
  exhausted route retries and the full seam retry on `(8,1)->RIGHT` into
  `(9,1)`. The run had no NPC or drift contamination and recovered to `(8,8)`
  by a west-side detour.
- RUNTIME PROOF: explicit `add_blocked_edge:5,8,1,RIGHT` recorded
  `(9,1).west`. The chest approach remained available. The return then planned
  the west-side route immediately (`5 west, 4 south, 3 east, 3 south, 4 east`)
  and completed all 19 steps with no retry, replan, or reroute.
- SOURCE-FIXED / ACCEPTED: map0x05 includes only `(9,1).west`; the
  opposite approach remains unblocked until proven. The regression failed
  before the source edit and passes afterward. Syntax, `git diff --check`, all
  95 map-reader tests, all 22 pathfinder tests, and the full gate of 41 Lua
  suites plus 68 Python tests pass.

## 2026-09-22 Tantegel Throne Room first chest wall correction

- CLEAN FAILURE: starting at stair `(8,8)`, the first chest approach planned
  4 north then4 west. Entry north into `(8,7)` exhausted route and seam retries
  and stayed blocked, forcing an8-step reroute west through open door `(4,7)`.
  The chest at `(4,4)` was reached.
- CLEAN RETURN: the initial 4-east/4-south return again blocked `(8,7)`, this
  time from the north at `(8,6)`. The successive alternatives also blocked
  `(8,6)->RIGHT` into `(9,6)`, `(7,6)->DOWN` into `(7,7)`, and
  `(6,6)->DOWN` into `(6,7)`. The route then recovered through door `(4,7)`
  and reached `(8,8)`. These are the south/right castle walls, not random NPC
  clutter or a grass/stone-table issue.
- RUNTIME PROOF: full-cell test blocks at `(5,7)`, `(6,7)`, `(7,7)`, `(8,7)`
  and `(9,6)` made the planner choose the open door immediately. The outward
  and return routes each completed8 steps with no retry or reroute.
- SOURCE-FIXED / RELOAD PENDING: `map_reader.lua` blocks the complete y7 south
  wall except door `(4,7)`: x1-3 and x5-9. `(9,6).west` extends the existing
  directional right-wall series. `test_map_reader.lua` protects the wall, the
  door exception, and directional-only right-wall entry. All95 map-reader and
  22 pathfinder tests pass; the full gate passes41 Lua suites and68 Python
  tests; syntax and `git diff --check` pass.
- CURRENT CONTAMINATION: frame374340 is at `(8,8)`, door open, nil route, with
  five manual runtime blocks still active from the proof. Reload `main.lua`
  before acceptance; do not count the runtime-assisted run as source acceptance.

## 2026-09-22 Tantegel Throne Room modeled audit

- CLEAN BASELINE: map0x05 at the return stair `(8,8)`, six keys, door `(4,7)`
  open in slot7, nil route/path, and no runtime blocks.
- AUDIT1 `town_audit_05_20260922T175232Z_001`: all9 targets;9 modeled
  reachable,0 NPC-obstructed,0 model-blocked,0 return concerns. It covered the
  King, return stair, three guards, three chests, and door. The stair's map
  transition is not tested by the audit.
- AUDIT2 `town_audit_05_20260922T175352Z_001`: the roaming Guard1 moved from
  `(6,6)` to `(7,1)`, changing its route from5 steps to16 with captured NPCs.
  The result remained9 reachable,0 NPC-obstructed,0 model-blocked,0 return
  concerns; all other modeled target routes stayed available.
- TERRAIN CHECK: this 10x10 castle floor has no raw0 grass. Raw4 is mixed
  castle geometry already covered by map0x05-specific permanent blockers,
  walkable south-corridor overrides, the `(4,7)` door, and directional edges.
  There is no evidence that the main-floor Bank00 grass/stone correction
  belongs here.
- LIVE STATUS: no movement, TALK, chest opening, door use, or transition was
  performed. Live round trips/interactions remain next, followed by a Sun
  Shrine audit if desired. Fresh frame301980 retained `(8,8)`, open door, nil
  path/route, and no runtime blocks.

## 2026-09-22 Tantegel NPC and entrance acceptance

- PLAYER ACCEPTED / MAIN FLOOR COMPLETE: starting each target from the main entrance
  `(11,29)`, all 18 non-service NPCs were talked to and logged `VISITED_AUTO`.
  All returns completed. Guard5 required manual damage-floor crossings on the
  outward and return legs, with ordinary local routing used on each safe side;
  preserve the safe planner's refusal to cross those hazards automatically.
- RECOVERED TRANSIENTS: Merchant1 crossed `(16,18)->(17,18)` after exhausting
  the bounded retries and invoking seam recovery. Old Man1 logged a direct
  `AUTO_WALK_NPC_BLOCK` against the moving target at `(5,8)` and continued
  after it cleared. Person1 logged one `AUTO_WALK_DRIFT_REROUTE`, then later
  passed a clean 8/8-step retest. Woman1 crossed the end seam to `(6,4)`, lost
  the first path after the target moved, then completed the retry and 42-step
  return. None is permanent blocker evidence.
- SECONDARY ENTRANCES ACCEPTED: the Throne Room stairs completed 30 steps each
  way. Sun Shrine Stairs and Southeast Exit completed 94 each way; the planner
  retained its existing risky-final-approach avoidance without changing the
  route length.
- FINAL CHECKPOINT: fresh frame200580 has map0x04 at `(11,29)`, both doors open
  at `(18,6)` and `(4,13)`, six keys, nil path/route, and no runtime blocks.
  This completes the Tantegel main-floor audit/cleanup pass. The Throne Room
  and Sun Shrine floor follow-ups remain separate.

## 2026-09-18 Cantlin terrain/audit start

- TELEPORT-TAINTED BASELINE: hero `(7,23)`, all five known doors open
  (`(14,25)`, `(15,25)`, `(26,9)`, `(8,25)`, `(4,21)`), keys 1, runtime
  blocks none. Pre-correction audit `town_audit_0a_20260918T162410Z_001`
  covered all 29 targets: 26 modeled reachable, 1 NPC-obstructed, 2
  model-blocked, and 0 return concerns. Treat it as a comparison snapshot,
  not final route acceptance, because the terrain table was still reversed.
- CLEAN TERRAIN PROOF: exited Cantlin, walked normally on the World Map from
  `(73,102)` to `(73,100)`, and re-entered at `(15,0)`, clearing teleport
  taint. Normal auto-walk reached `(19,11)`; `probe_edge:LEFT` then entered
  raw0 grass `(18,11)` despite the old model calling it blocked. Continuing
  by normal movement reached `(9,23)`, where repeated west attempts into raw4
  stone `(8,23)` blocked; the same clean route also blocked adjacent x=8
  stone cells. No runtime blocks were present before the probes.
- PATCHED / RELOAD PENDING: `map_reader.lua` now gives Cantlin map `0x0A` the
  verified Bank00 town collision table (raw0 grass walkable, raw4 stone
  blocked) without changing Cantlin's coordinate-scoped damage-barrier model.
  `test_map_reader.lua` adds a full 16-tile Cantlin collision regression and
  cross-map isolation. Syntax and diff checks pass; all 91 map-reader tests
  pass. Navigation refreshes already report `(18,11)` walkable and `(8,23)`
  blocked, but a manual FCEUX Lua reload is still required for acceptance.
- CURRENT LIVE STATE: the clean re-entry reset opened-door RAM. Hero is at
  `(8,20)`, all door slots are closed, HP 149/149, and runtime blocks are
  none. The pre-edit live log is preserved at
  `.test_tmp/cantlin_open_doors_teleport_tainted_baseline_20260918.log`.
- RELOAD VERIFIED: fresh launcher probe `CANTLIN_TABLE_RELOAD` passed. At
  frame3960, raw0 `(18,11)` reported walkable and raw4 `(8,23)` blocked, both
  by `map_tile_type`; hero stayed `(8,20)` and runtime blocks remained empty.
  The first closed-door audit was 21 reachable, 1 NPC-obstructed, 7 blocked,
  with 1 return concern (`town_audit_0a_20260918T173033Z_001`).
- OPEN-DOOR AUDIT: restored the user's intended five-door state with
  `debug_seed_open_doors` for `(14,25)`, `(15,25)`, `(26,9)`, `(8,25)`, and
  `(4,21)`. The first snapshot found 23 reachable, 1 NPC-obstructed, 5 blocked;
  a repeat after mobile NPC movement improved to 24 reachable, 1
  NPC-obstructed, 4 blocked, and 1 return concern
  (`town_audit_0a_20260918T173209Z_001`). The remaining blocked targets are
  Roaming Weapons Merchant `npc_4`, Old Man 4 `npc_18`, Old Man 1 `npc_6`,
  and Merchant 3 `npc_8`; Guard 1 `npc_1` is the transient NPC obstruction.
  Old Man 3 is now reachable. Final frame12000: hero `(8,20)`, all five seeded
  doors open, no active path, and no runtime blocks. Live routes remain to be
  validated; audit status alone is not passability proof.
- FAIRY WATER CLASSIFICATION FIX: live route/TALK evidence identified roaming
  `npc_5` (slot 5, Woman sprite, movement `0xD0`) as the duplicate Services
  target; her dialogue is only "I know nothing." `objects.lua` now pins that
  stable slot to `Woman 2`, explicitly keeps it out of Services, and leaves
  stationary seller `npc_16` at `(22,13)` as `Fairy Water Merchant` with the
  public `(20,13)` east-facing counter stand. The regression was demonstrated
  red before the fix and all 128 object tests pass afterward; Lua syntax and
  diff checks pass. Live navigation modules refreshed at frame24840, but the
  immediate services audit was correctly refused because the prior dialogue
  box was still open.
- SERVICES PLAYER ACCEPTED: after closing the dialogue, the player confirmed
  that `npc_5` is absent from Services and completed the category's usable
  round trips. One Fairy Water leg rerouted after a timing-suspect timeout on
  `(11,19)->RIGHT` into `(12,19)`; the repeat was clean. Do not promote that
  single observation.
- ROAMING WEAPONS MERCHANT EXPECTED NO-ROUTE: fresh frame74700 places `npc_4`
  at `(22,4)`, with all five doors open and no runtime blockers. Frame76200
  normal and skip-NPC adjacent planners both returned `No path found`
  (visited557/587). Frontier analysis found a four-cell target-side component,
  `bridge_candidates=0`, and `hidden_bridge_candidates=0`. This exactly
  reproduces the previously verified sealed x=22, rows3-6 compartment. Leave
  its walls and adjacent-NPC service behavior unchanged; it can be routed only
  when its live position is in the public component.

## 2026-09-18 Rimuldar Woman 4 southwest edge route

- RIM-WOMAN4-EDGE-01 / PLAYER ACCEPTED: stationary `npc_19` is
  correctly located at `(0,26)`. The valid conversation stand is `(0,27)`,
  facing north; live TALK there delivered "Orwick is late again. I'm starving."
  and `VISITED_AUTO` matched `npc_19`.
- The natural route reaches `(1,28)` from the entrance by using the south
  perimeter. The planner stopped there only because its generic west-boundary
  guard hid `(0,28)` and `(0,27)`. Controlled one-tile moves proved
  `(1,28)<->(0,28)<->(0,27)`. A 60-frame held-left probe first entered
  `(0,28)` and then exited town on a second step; that overrun is expected at
  the edge and is not blocker evidence.
- `map_reader.lua` now exposes only `(0,28)` and `(0,27)` for map `0x0B`;
  `(0,26)` remains blocked. `objects.lua` gives Woman 4 the exact `(0,27)`
  north-facing talk stand and keeps her out of Services. Syntax and diff checks
  pass, along with all 90 map-reader and 127 object tests; the full gate passes
  41 host-runnable Lua suites and 68 Python tests.
- PLAYER ROUND-TRIP ACCEPTANCE: after reload, two entrance-to-Woman4 routes
  completed at `(0,27)`, faced north, and TALK matched `npc_19`. The first
  return attempt completed its down step into `(2,29)` at frame687, then
  residual south carry crossed the town exit at frame702 during the planned
  turn to east; this is a timing/transition watch item, not a map blocker. Two
  subsequent returns used the same southwest corridor and completed normally
  at the entrance `(29,13)` (face completions frames5378 and9192), with no
  runtime block. Fresh frame15240 confirms `(29,13)`, target/path nil, and
  runtime blocks none. Acceptance log:
  `.test_tmp/rimuldar_woman4_player_acceptance_20260918.log`.

## 2026-09-17 Rimuldar Old Man 3 counter access

- RIM-COUNTER-01: Old Man3 (stationary npc_17) is correctly located at(3,23).
  Fresh352740: hero(4,21), clear field/guards, no runtime blocks, keys5, both
  inn doors closed. The inaccessible west approach is the house wall(2,23),
  not the public entrance; the three adjacent wall cells and east raw-F
  counter(4,23) prevent ordinary adjacent-NPC routing.
- ROM Bank00 RimuldarDat/RimStatTbl and the saved map image identify the east
  public stand(5,23). No terrain or NPC relocation is needed. Skip-NPC planning
  from(4,21) found (5,21)->(5,22)->(5,23); normal auto-walk reached it at359650
  after one one-cell drift recovery, with no blocked event. West-facing TALK
  at361152 read: "This is a magic place. Hast thou found a magic temple?"
  B answered the hint question, producing "Go to the south."; another B closed.
- objects.lua now assigns stand(5,23), facing west, counter, service=false.
  Regression failed before the fix (interaction_x expected5, gotnil) and all
  126 object tests pass afterward. Navigation refresh loaded the fix at366060;
  Old Man3 now plans directly to(5,23) and faces west. Existing map edits from
  the earlier audit are preserved; only their west-wall comment is clarified.
- Return to the user's original(4,21) finished367501 after another one-cell
  drift recovery, with no blocked event. Fixed named-object route finished
  370349 at(5,23), faced west automatically, and TALK at372312 delivered the
  temple dialogue and VISITED_AUTO matched npc_17. That route also recovered
  one one-cell drift with no blocked event. Final return finished375999;
  fresh376860 confirmed hero(4,21), clear guards, no runtime blocks, keys5,
  doors unchanged/closed. Fixed live capture:
  .test_tmp/rimuldar_oldman3_counter_fixed_live.log.
  Initial full gate found two stale test_pathfinder expectations from the
  earlier Rimuldar town-table correction: weapons corridor now uses19 moves
  rather than21; key route retains52 moves but can turn across raw0 grass
  along row1. Updated tests retain the required outer-bank/bridge approach,
  public counter endpoints, return direction checks, and NPC/counter avoidance.
  Person4 now forces a four-step grass detour instead of splitting the bank.
  All22 pathfinder tests pass. Full gate rerun passes41 Lua suites and68 Python
  tests, with syntax/diff checks passing. Gate log:
  .test_tmp/rimuldar_oldman3_full_gate_after.log.
  Post-gate513420: still(4,21), clear input guards, bridge ready/error none.
  At514560 restored NPCs filter and Old Man3 selection(10/20); description
  reports the correct counter(5,23). Ready for player U/TALK acceptance.
  Initial live evidence saved before tests in
  .test_tmp/rimuldar_oldman3_counter_before_tests.log.

## 2026-09-17 Rimuldar terrain/audit start

- BASELINE: Rimuldar map `0x0B`, exit stand `(29,13)`, both known doors open
  (`(21,21)`, `(22,23)`), runtime blocks none, active path nil. Open-door
  audit `town_audit_0b_20260917T172301Z_001` found 25 targets: 7 modeled
  reachable, 15 NPC-obstructed, 3 model-blocked, and 0 return concerns.
- UNRESOLVED / DO NOT PROMOTE: the current stand behaves as a one-way exit.
  Clean retries after FCEUX input recovery repeatedly blocked
  `(29,13)->DOWN` into `(29,14)`; northward raw probe also did not move. The
  temporary runtime block was cleared after each attempt. This is directional
  transition evidence, not grass/stone proof.
- NEXT CHECK: re-anchor on normal interior floor `(29,14)` (or another
  in-town origin), then raw-probe ordinary raw-0 grass and raw-4 stone before
  replacing Rimuldar's generic town collision model. Current static model has
  the familiar reversed signature: `(20,13)` raw0 is `tile_type` blocked,
  while raw4 cells are walkable.
- CLEAN: player re-entered and normally reached `(29,19)` in a fresh session.
  After FCEUX input recovery, same-origin `probe_edge:DOWN` at frame `14184`
  moved from raw0 `(29,19)` through raw0 `(29,20)` and settled at `(29,21)`.
  Both cells are still modeled `tile_type` blocked, so this is direct grass
  proof. The fresh session reset both opened-door RAM slots; reopen them only
  after the terrain correction/reload, before the final audit.
- NEXT CHECK (revised): from normal floor `(23,20)`, probe LEFT into raw4
  `(22,20)` to establish the matching stone block. Do not promote the table
  until that ordinary edge agrees.
- CLEAN: the player and a direct raw probe both blocked `(23,20)->LEFT` into
  raw4 `(22,20)` at frame `57959`; no NPC, runtime blocker, or timing suspect
  was present. Together with the raw0 grass crossing above, this verifies
  Rimuldar's Bank00 town table. The map-scoped table/hazard patch and updated
  expectations pass `luac -p map_reader.lua test_map_reader.lua` plus all 89
  `lua test_map_reader.lua` cases; manual FCEUX Lua reload remains pending.
- CLEAN / PLAYER-VALIDATED: after reload and opening both doors, service,
  chest, and door outward/return routes completed with no drift reroute or
  runtime block: Inn 16/16, Magic Key Merchant 51/51, Weapons Merchant 20/20,
  Chest 27/27, Rimuldar Inn Outer Door 21/21, and Wings Chest Door 24/24.
  The Wings door initially reported NPC clutter several times, then planned
  and completed once the mobile NPC layout changed; do not promote it as map
  geometry. Final probe frame `47640`: entrance `(29,13)`, both doors open,
  keys 6, nil path, runtime blocks none. NPC validation is next.
- CLEAN / PROMOTED: Old Man 3 has no public approach from the west-side stand;
  the east counter interaction is now identified above. Normal route
  execution from `(1,23)` blocked east into
  `(2,23)` four times, including both seam retries, with no NPC/runtime block;
  after FCEUX input recovery, same-origin `probe_edge:RIGHT` also blocked at
  frame `92339`. The temporary runtime edge `(2,23).west` gives both normal
  and skip-NPC planners no route to an adjacent stand. Map `0x0B` now models
  only this missing west approach, preserving the existing reverse block.
  `luac -p map_reader.lua test_map_reader.lua` and all 89 map-reader tests
  pass. The later navigation refresh loaded this wall model and the counter fix.
- REPRODUCED / INPUT CAVEAT: after the player restored a save, reopened both
  Rimuldar doors, and stood at `(1,23)`, the loaded model reported only the
  east edge `(1,23)->RIGHT` into `(2,23)` closed; south to `(1,24)` remained
  modeled open. `recover_fceux_input.sh` and `isolate_input:60` cleared the
  game-side buttons, but FCEUX retained an ignored stale `D` key and relatched
  `LeftAlt` during the probe. The raw probe nevertheless held RIGHT for 60
  frames (`buttons=0x80`) and ended at frame `265979` with
  `status=blocked`, `final=(1,23)`, and no runtime blocker. This confirms the
  current engine failure from the restored state, but retain the FCEUX
  stale-key caveat and do not broaden the directional patch.

## 2026-09-17 Garinham town correction and NPC pass

- CLEAN: map `0x09` now uses the verified Bank00 town collision table after
  player reload. Fresh `inspect_tile:4,13` at frame `04320` reports raw type
  `0`, `base_walkable=true`, and `reason=map_tile_type`.
- CLEAN: player manually completed Tool Merchant, Inn, Weapons Merchant, and
  all three chest routes with outward and return completion. Each chest had one
  `AUTO_WALK_DRIFT_REROUTE` then recovered and completed; do not promote these
  timing recoveries as blockers. One Weapons Merchant run ended by player
  hotkey before the subsequent successful retry.
- BASELINE: frame `54420`, Garinham entrance `(1,14)`, both doors open
  (`(17,10)`, `(4,6)`), runtime blocks none, active path nil. All named NPC
  targets are in bounds; seven are mobile and should be parked for route-only
  checks.
- CLEAN / PLAYER ACCEPTED: all named NPC/service dialogue targets, chest
  routes, and their outward/return legs were manually validated. The NPC pass
  logged four one-cell drift recoveries (Merchant1, Old Man1, Person1, and the
  Exit return); each reached its target/return afterward, with no durable
  reroute or blocker. Fresh frame `167280`: entrance `(1,14)`, both doors
  open, runtime blocks none, active path nil.

## 2026-09-17 Kol final two NPC findings

- Player acceptance closes the Kol town pass: the user validated Old Man4 and
  Person2, reloaded, and exited/re-entered town a couple of times with Person2
  in bounds each time. No remaining acceptance blocker. KOL-NPC-STATE-01 stays
  an unresolved-cause watch item; the new warning is route-request feedback,
  not continuous NPC monitoring. On recurrence, capture live coordinates/raw
  slots and recent logs before map re-entry resets the state. Documentation
  updated only for acceptance; no additional code change or test rerun.

- Player finished all other outward/return routes successfully. Remaining
  failures: Old Man 4 (npc_10) and Person 2 (npc_1). Fresh34500: Kol(19,23),
  both doors open, keys2, clear field/guards, no runtime blocks. Original
  player log: .test_tmp/kol_final_npc_validation_20260917.log.
- KOL-COUNTER-01 (fixed, player-accepted): Old Man 4 at(1,1) has no
  walkable adjacent tile. Raw-F counter(1,2) blocks the south approach; public
  stand(1,3) is brick surrounded on the public side by raw9 swamp. With hazards
  allowed, the planner finds38 steps from entrance including(1,5)/(1,4).
  Normal auto-walk reached(1,6), then same-origin probes crossed(1,5),(1,4),
  and(1,3) at49943/51743/51938. North-facing TALK at54629 spoke the weapons
  advice, confirming the across-counter interaction. Return probes crossed
  the same swamp south at66267/66446/66625. No map tiles were changed.
- objects.lua now gives this dialogue-only NPC interaction(1,3), north,
  counter; service=false. All125 object tests pass, including a new regression
  that failed before the fix. inspect_tile hot-refreshed the change at63480;
  auto_walk_blocker:1,1 from the stand planned goal(1,3), Already there, at65220.
  From(1,7), the fixed object route queued1 safe step to(1,6) at68040 and
  delivered the existing two-swamp-tile warning/stop at68099. This preserves
  the manual-crossing rule for interior hazards. Survey at the isolated public
  stand was correctly refused by its no-safe-exits preflight; use normal
  object routing and manual hazard crossing for this target.
- KOL-NPC-STATE-01 (recovered; cause remains a watch item): Person 2 is a genuine ROM mobile slot1,
  initially(5,12), Bank00 KolMobTbl $98B6. The failing visit's slot1 was(5,31), outside
  the24x24 map, with raw05,3F,CF at35700 and05,1F,CF at43920. Player failures
  already showed(5,31) at19213/26304/28784. The earlier audit's(0,3) was another
  snapshot position, not fixed map geometry. Slot0 also reached the map's
  northern edge and later returned inside. Root cause of these runtime
  positions is not established; do not remove the NPC or invent passability.
- Ordinary O/U no-path handling missed goal_out_of_bounds without debug stats
  callbacks. route_manager now checks bounds explicitly during failure
  classification and adds NPC-specific leave/re-enter guidance. New regression
  failed before the fix; all164 route-manager tests pass afterward. The player
  subsequently reloaded main.lua to load the retained route_manager module's
  new message. No NPC RAM reset/teleport was used.
- Normal exit/re-entry reset Person 2: left Kol at74558, walked south on the
  world map, then north into Kol at75923. Fresh76020: entrance(19,23), keys2,
  both doors closed by normal map entry; Person 2 at(5,11), raw05,8B,00.
  survey_target:Person 2,park_npcs completed53 steps at79560, blocked_events=0,
  movement_succeeded=true; all16 survey-parked slots restored. Ordinary
  turn-twitch timing recovery occurred, without failed-edge rerouting.
- Follow-up normal approach reached stand(6,14) at81855, faced south toward
  Person 2 at(6,15), and released manual freeze/parking. TALK at82224 read
  "Art thou the descendant of Erdrick? Hast thou any proof?" and marked npc_1
  visited. The56-step return finished86765 with no blocked events; all9 parked
  NPCs restored. Old Man 4's safe-ground return also finished71264 cleanly.
- Final96480: hero Kol(19,23), clear field/input guards, no runtime blocks,
  HP86/86, keys2. Person 2 remains in bounds at(5,13). Both doors are closed
  after the normal re-entry. Existing user config is unchanged. Final live
  capture before tests: .test_tmp/kol_last_two_fixed_live_20260917.log.
  Full gate passes41 Lua suites and68 Python tests, including125 object and164
  route-manager tests; syntax/diff checks pass. Gate log:
  .test_tmp/kol_last_two_full_gate_20260917.log.

## 2026-09-17 Object browser repeats one entity after debug work

- BROWSER-RELOAD-01 (high usability impact, cause confirmed): after navigation
  debug commands, J/L appeared to leave only Bath available. Fresh frame92400
  at Kol entrance(19,23) reported Bath as 1 of 20; the list was intact.
  Debug next_object advanced to Exit to World Map, 2 of 20, at95100. The player
  then pressed L twice and confirmed it repeatedly spoke Exit to World Map.
- main.refresh_navigation_modules replaces objects and refreshes route_manager
  and object_commands, but retained hotkeys still held the old objects module.
  J/L changed the old selection while route_manager narrated the new selection.
  inspect_tile, inspect_move, audit and edge-debug workflows use this reload.
- Fix: main now calls hotkeys.refresh_navigation_modules after rebuilding the
  browser. Rebind objects/map_reader/overworld_routes, discard stale pending
  speech and deferred U, preserve key edges and registered handlers.
- Two regressions exercise main's actual reload coordinator: old code repeats
  Bath and retains stale speech; fixed code passes selection/narration, category,
  visit, routing, pending speech, deferred walk and held-key checks. All 53
  hotkey tests pass. Full gate passes 41 Lua suites and 68 Python tests;
  syntax/diff checks pass.
  Gate: .test_tmp/kol_browser_full_gate_20260917.log.
- Live acceptance: player reloaded main.lua. Fresh480 confirmed Kol(19,23),
  clear field/input guards, Bath 1 of 20. inspect_tile:19,23 at960 triggered
  HOTKEY_NAVIGATION_MODULES_REFRESHED and NAVIGATION_MODULES_REFRESHED.
  Player then confirmed L/J/K browse and reread normally. Fresh2820 reported
  Guard 2, 4 of 20, proving the keyboard changed the shared selection; hero
  remained(19,23), with clear guards and no injected movement. Accepted fixed.
  Post-fix capture: .test_tmp/kol_browser_fixed_live_20260917.log.
- Captures before tests (which truncate the live log):
  .test_tmp/kol_browser_stuck_20260917.log and
  .test_tmp/kol_browser_stuck_confirmed_20260917.log.

## 2026-09-17 Kol player validation and Old Man1 return timing review

- Player reports all three service routes worked perfectly and is about halfway
  through NPC outward/return validation. Log confirms Inn25/25, Tool Merchant
  45/45, and Weapons Merchant16/16-step round trips; no blocked-step reroutes in
  those service routes. Western Building Door was reached from West Side Door
  in44 steps, then its entrance return took22. Both doors are now open.
- KOL-RETURN-01 (low, timing watch): Old Man1 return began at(2,13), frame33619,
  targeting entrance(19,23),39 steps. Its first LEFT into(1,13) exhausted the
  queued-step timing retries at33854; only one temporary route block/reroute.
  No directional-map change was made. The41-step detour went via(2,12)/(1,12),
  entered(1,13) from north at34017, and completed at35476 with all9 parked NPCs
  restored. This is a transient candidate, not proof of a permanent wall.
- Fresh53400:hero(19,23), clear field/guards, nil path, runtime none, keys2,
  opened-door RAM(1,14)/(7,12). Preserved original player log before probes:
  .test_tmp/kol_old_man_return_20260917.log.
- Same-origin raw probes after normal walked arrival at(2,13) passed LEFT into
  (1,13) twice:57110 and60556. Both report raw6 brick, npc_blocked=false,
  directional_blocked=false, status=moved, final(1,13). No teleport/reset used.
  An intervening coordinate auto_walk_blocker resolved an NPC now at(2,13) and
  correctly reported already adjacent; the exact-origin walked verifier was
  used instead. This was not counted as a coordinate movement test.
- Current evidence supports a transient movement/input timing issue. Exact
  cause at33620 is not proved by a later passing probe; do not add permanent
  map data or change global cadence from this isolated event. No new Lua/config
  edits or automated test run in this review.
- Review return from(1,13) to entrance(19,23) completed at62411 without another
  blocked step or reroute;9 NPCs restored. Final64920:hero(19,23), clear field/
  guards, nil path, runtime none, speech bridge ready/error none. Player can
  resume remaining NPC validation. Full review capture:
  .test_tmp/kol_old_man_return_review_live_20260917.log.
- Audit workflow updated in AGENTS.md, work_notes/town_polish_strategy.md,
  and TASKS.md: every remaining town checks raw0 grass/raw4 stone against the
  game's conversion/collision table and normal-arrival live probes, with doors
  and hazards handled separately before per-cell changes.

## 2026-09-15 Kol West Side Door route failure

- KOL-DOOR-01 (high navigation impact): user's26-step West Side Door route
  from(19,23) to(1,15), frame1228, hit nine blocked edges before the user stopped
  at6249. First failures(16,23).east1603, (10,17).east2269, (7,14).east2879
  repeat the September10 Tool Merchant failure sequence. Later failures:
  (8,4).east3662, (7,3).east4089, (8,4).north4507, (5,4).north5131,
  (6,4).north5578, (7,3).west5987. Route used9 mobile-NPC parking slots.
  Raw pre-fix capture:.test_tmp/kol_west_door_before_fix.log.
- Fresh11460:Kol(7,2), clear field/guards, both doors closed, keys4, no runtime
  blocks. inspect_move/down and three first failure cells at13020 all expose
  raw4 as base_walkable=true, confirming the old town-table mismatch.
- Local guide orientation:project_resources/maps/kol/external/vgmaps_kol.png
  shows the west locked building and its outside approach; no hidden treasure
  coordinate is added or exposed. Primary disassembly confirms Kol's town tile
  mapping and Bank00 $9A00 conversion/CheckCollision $B1CC:
  https://github.com/nmikstas/dragon-warrior-disassembly/blob/master/source_files/Bank00.asm
- Normal-arrival raw probe14579:(7,2)->DOWN into(7,3), raw4, blocked,
  npc_blocked=false, reason=raw_hold_timeout. This corroborates multiple route
  attempts against the same stone from east/west and the player's final south
  attempt; not merely auto-step cadence.
- Walked-edge verifier reached(5,1) normally. Raw left probe17139 crossed raw0
  (4,1), ending(3,1), despite effective_passable=false. Reverse right18575 crossed
  the same grass and ended(5,1). No teleport/reset, no key use. NPC freeze was
  explicitly released at19320. Hero left at(5,1) during source/test work.
- Narrow fix:apply the verified16-entry town collision table to map07 alongside
  map08; raw9/A use existing hazard policy. Preserve all per-cell/directional/
  door overrides and other map tables. New Kol regression fails old code and
  passes corrected code; all87 map-reader tests pass. Old passthrough fixture
  now supplies captured stone/sand/tree IDs rather than assuming every zero
  is blocked. Full gate and live route retest results are below.

### Kol correction validation

- All87 map-reader tests,41 Lua suites, and68 Python tests pass. Syntax and
  diff checks pass. Gate:.test_tmp/kol_door_gate.log. New regression failed
  pre-fix; no further source changes after the full gate.
- Idle audit_town refreshed map_reader at35160 (no manual reload needed).
  From(5,1), snapshot005040Z had13 reachable,5 NPC-obstructed,2 model-blocked.
  Subsequent common-entrance snapshot005245Z from(19,23), frame42619, had13
  reachable,4 NPC-obstructed,3 model-blocked. Both doors remain closed. Counts
  vary with roaming NPC positions and now-correct hazard handling; no claim of
  whole-town completion. Final model-blocked:Person2 at(0,3), Old Man4 at(1,1),
  Old Man1 at(1,11). NPC-only flags:Tool Merchant, Guard4, Merchant1, West Side
  Door. These need focused investigation rather than blanket new blockers.
- Actual walks, using the user's enabled mobile-NPC parking setting:
  (5,1)->West Side Door stand(1,15),30 steps, finished37591;
  (1,15)->entrance(19,23),64 steps, finished41354;
  original entrance(19,23)->door stand(1,15),64 steps, finished45944.
  All three completed with no blocked events, reroutes, or drift cancellations;
  ordinary cadence retries recovered. Nine mobile NPCs restored after each.
  The 64-step route is stable but long; review old directional overrides and
  alternate corridors later only with clean live evidence, not wholesale removal.
- Final fresh46860:hero(1,15), field/input guards clear, nil path, runtime none,
  speech bridge ready/error none, zero pending warnings. Doors closed, keys4;
  no key use, teleport, or config change. All freeze/parking released. Final
  capture:.test_tmp/kol_west_door_fixed_live.log. Hero is just south of West
  Side Door, ready for the player's OPEN. Western Building Door approach has
  not been live-validated in this slice.
- KOL-DOOR-01 repeated-wall rerouting is fixed and agent-validated. Next: player
  opens the doors, then repeat audit and investigate remaining target flags.
  Also retest Tool Merchant, whose initial three failed cells were the same
  stone misclassification; its corrected round trip is not yet claimed.

## 2026-09-15 Kol initial audit (map0x07)

- Brecconary/quick-services/town-audit work merged and published to main at
  2be96d4; local main, origin/main, and an independent GitHub query agree.
  Active branch:codex/kol-town-polish, created from that commit. Only new audit
  notes differed from main at this initial audit; the correction above came later.
- Fresh probe63180:hero(19,23), clear field/guards, nil target, runtime_count=0.
  Audit64440..64459 saved town_audit_07_20260916T003731Z_001.json/.txt
  (UTC September16; local September15). Both door slots closed, keys4.
- Result:20 targets,16 modeled reachable,0 NPC-only obstructions,4 model-blocked,
  0 reported return concerns. All actual arrival/TALK/return fields remain
  untested. Services all have plans:Inn25 steps to(19,2), Weapons16 to(20,12),
  Tool Merchant9 to(12,21). A valid plan does not resolve the prior Tool route
  execution failures documented below.
- Model-blocked targets, snapshot positions:
  - Old Man4/npc_10 (1,1):raw0 cells(4,2)/(4,3) rejected by base tile_type;
    frontier suggests these connect his area. Compare with the Brecconary raw0
    grass correction, then verify live before promoting any Kol data.
  - Old Man1/npc_3 (1,11):north approaches into(1..3,10) have directional blocks.
  - Guard4/npc_16 (1,23):ranked frontier(2,16), raw4 with directional blocks.
  - Old Man3/npc_8 (21,8):ranked frontiers(21,12) west and(9,2) east/south.
  These are hypotheses; closed doors and old overrides still need separation.
- Bath currently has object type exit, so its return is transition_not_tested,
  just like the world exit. Zero reported return concerns is not proof of every
  landmark return. Preserve the spoiler-safe Bath waypoint.
- No movement, freeze/parking, door use, or map edits were issued. Fresh final
  probe66120 confirms same position(19,23), clear field/guards, runtime none.
- Next: verify the known Tool Merchant route with normal movement, then compare
  Kol's terrain classification and door gating before fixing the four targets.

## 2026-09-15 Survey recovery fix and open-door retest

- FIXED SURVEY-DRIFT-RETRY-01: defer the survey's raw drift decision until
  route_manager has attempted synchronous recovery. Preserve the active attempt
  during correction; retain immediate completion, terminal failure, and bounded
  retry behavior. Three red/green regressions,56 survey tests,41 Lua suites,
  and68 Python tests pass. Exact drift did not recur in the live retest.
- User opened doors(5,23)/(21,6), keys4. Idle audit_town refreshed map_survey,
  so no extra manual reload was needed. Live target surveys passed: Woman2
  result18802; Fairy Water Merchant20565; Guard4 33958. Freeze released each time.
- Counter(22,4) correctly refused the next survey start with low_exit_count;
  restart from street(21,7) passed. Temporary timing retry at(8,21) west cleared
  after crossing; no geometry change or runtime blocker promotion.
- Guard4 had wandered out, so additionally walked into the inn west room(3,22)
  and back through open door(5,23);21 steps each way, completed39353/42199.
  Fairy-water doorway(21,6) also passed both ways.
- Final audit195938Z from entrance(1,15):23/23 modeled reachable, zero NPC-only
  obstructions, model blockers, or return concerns. Fresh frame45420:hero(1,15),
  nil path, runtime none, clear field/guards, speech ready/error none, keys4.
- Evidence: work_notes/town_decoder_findings.md; local raw capture
  .test_tmp/brecconary_survey_fix_live_20260915.log; gate
  .test_tmp/survey_retry_gate.log. No config change, teleport, purchase, or
  agent key use. Next recommended map: Kol service routes.

## 2026-09-15 Brecconary decoder validation

- PASSED: southern grass normal round trip; tool merchant counter/TALK/return;
  Woman2 ordinary auto-walk/TALK/return; corrected NPC mobility and parking.
- Final frame56460: hero(1,15), nil path, runtime none, clear field, bridge ready.
  Source/config unchanged; no purchase, key use, teleport, or remaining freeze.
- Audit184226Z:21/23 reachable, no return concerns. Audit185118Z:20 reachable,
  Curse Remover NPC-obstructed outward/return, same two closed-door targets.
  NPC-layout variation is distinct from geometry changes or live acceptance.
- SURVEY-DRIFT-RETRY-01 was reproduced at41023..41106 in the earlier session;
  the subsequent fix and open-door retest below supersede its unresolved status.
- Detailed evidence/repro: work_notes/town_decoder_findings.md. Raw local capture:
  .test_tmp/brecconary_live_20260915.log. No geometry candidates to promote.

## 2026-09-10 Kol service-route polishing candidates

- KOL-SERVICE-01 (medium): player-initiated Tool Merchant walk failed to finish.
  Fresh log started 09:37:17. Shift+P announced Services/Distance and Tool Merchant
  1 of 3 at frames 979, 2119, 12124. User confirms quick-services behavior.
- At frame 12300, U planned 9 steps from (19,23) to interaction stand (12,21).
  Failed west approaches: (17,23)->(16,23) frame 12818,
  (11,17)->(10,17) frame 13569, (8,14)->(7,14) frame 14300.
  Each received a temporary route block and reroute; remaining route grew to
  39 steps. These are single-run candidates, not permanent map proof.
- Separate NPC obstruction at (8,12), approached north from (8,13), frame14628.
  Later drift from (9,3) to (8,3) caused a reroute at frame15327. Southward
  entry from (8,3) then retried; player stopped at frame15497 before arrival.
- Fresh read-only launcher_probe:quick_services_verified frame21240 confirms
  Kol (8,3), PATH_STATE target=nil, runtime_count=0. No new script error file.
- Next: reproduce the Tool Merchant route using ordinary walking, distinguish
  timing/NPC effects from directional geometry, verify service approach and
  return paths. Do not promote these cells without repeated clean evidence.

Updated: 2026-09-03

## 2026-09-03 Darkness Parity First Slice

- LIVE DYNAMIC AUTO-WALK PERMITTED ROUTE (`2026-09-06`): after the new source
  was reloaded, the player started at Erdrick's Cave B1 `(9,7)`, selected the
  visible Stairs Down at `(9,9)`, and auto-walk planned the one-step approach
  south to `(9,8)`. The executor injected only south, completed the step at
  frame `1767`, and finished/faced south at frame `1786` without a darkness
  stop, route cancellation, or runtime block. Fresh probe
  `DARKNESS_AUTOWALK_ALLOWED_20260906` at frame `5880` confirmed `(9,8)`, raw
  Radiant radius `7`, half-span `3`, timer `16`, `navigation_limited=true`, nil
  path target, and zero runtime blockers. HIDDEN-REMAINDER ACCEPTANCE: the
  running config was then staged unrestricted while the tracked file remained
  at its default `true`. A watcher detected a newly queued 17-step Exit route
  at frame `36511` and reloaded the restriction at frame `36540`, while the
  first north step was already committed. That step completed at `(9,7)`;
  before step two, frame `36569` identified hidden queued cell `(6,5)`, logged
  both darkness guard events, cleared the route, and delivered the full warning,
  which the player confirmed hearing. Final probe
  `DARKNESS_AUTOWALK_STOPPED_20260906` reported nil path, zero
  runtime blockers, no pending warnings, and `navigation_limited=true`.
- LIVE UNLIT ACCEPTANCE (`2026-09-04`): entering Erdrick's Cave B1 produced
  exactly one `LIGHT_RADIUS_CHANGED` event at frame `2470`. A fresh
  `report_light_state` at frame `36180` confirmed map `0x1C`, terrain `0x20`,
  position `(0,0)`, raw radius `1`, visible half-span `0`, Radiant timer `0`,
  and `limited=true`. Ordinary `current_object` and `next_object` checks at
  frames `37680` and `38040` both exposed only `Exit to World Map: here (1 of
  1)`; distant decoded stairs did not leak into the player-facing browser.
- LIVE TORCH ACCEPTANCE (`2026-09-04`): using a Torch at B1 `(0,0)` produced
  exactly one `LIGHT_RADIUS_CHANGED` event at frame `77591`, changing the raw
  radius from `1` to `3` and the visible half-span from `0` to `1`, with
  Radiant timer still `0`. A fresh report at frame `81480` confirmed the same
  state. `current_object` and `next_object` at frames `82020` and `82440`
  continued to expose only the entrance `(1 of 1)`, which is correct because
  no other modeled B1 object lies in the expanded 3-by-3 window; the distant
  stair remained hidden.
- LIVE RADIANT ACCEPTANCE / TTS BUG (`2026-09-04`): the cast dialogue was
  decoded as `Bill chanted the spell of R NT.` at frame `86560`. Radius then
  expanded in two legitimate steps: raw `5` / half-span `2` / timer `80` at
  frame `86601`, followed by raw `7` / half-span `3` / timer `80` at frame
  `86609`. A stabilized report at frame `93360` confirmed map `0x1C`, position
  `(0,0)`, raw radius `7`, half-span `3`, timer `80`, and `limited=true`.
  Object checks at frames `93660` and `94020` still exposed only the entrance,
  correctly hiding the stair at `(9,9)` outside the seven-by-seven window.
- FIRST FIX INSUFFICIENT / ROOT CAUSE: a clean script restart at `11:32:09`
  still spoke and logged `Bill chanted the spell of R NT.` at frame `482`.
  The filtered reader had preserved `RADIANT`; because the hero was at `y=0`,
  the later low-row cleaner then treated internal `ADIA` as standalone A-L map
  noise and removed it. The earlier phrase-level repair ran before that cleaner
  and could not survive the later transformation.
- CODED / UNIT VERIFIED: `text.clean_low_row_dialogue` now removes A-L-only map
  noise only at complete uppercase-word boundaries. It preserves `RADIANT`
  while retaining the original standalone-noise removal. The symptom-level
  phrase repair was removed. The focused dialogue suite passes `76/76`; Lua
  syntax and `git diff --check` pass. The native gate passes all 34
  host-runnable Lua suites and 68 Python tests after the corrected patch,
  including speech dependency and command-queue checks.
- LIVE NEXT CHECK: walk toward the B1 stair at `(9,9)` and check ordinary
  object browsing before and after it enters the current three-tile visible
  square. Continue normal movement long enough to observe Radiant shrinkage and
  verify one announcement at each meaningful radius change.
- LIVE CORRECTED ACCEPTANCE (`2026-09-04`): after a clean script reload and
  unlit entrance-state restore, frame `832` logged and spoke the complete
  sentence `Bill chanted the spell of RADIANT.` with no `R NT` occurrence.
  Frames `873`, `881`, and `889` then expanded raw light radius `3`, `5`, and
  `7` with half-spans `1`, `2`, and `3`; each carried Radiant timer `80`. A
  fresh report at frame `4560` confirmed B1 `(0,0)`, raw radius `7`, half-span
  `3`, timer `80`, and `limited=true`. The script-error log remains unchanged
  since May. The low-row word-boundary fix is live-accepted.
- LIVE MOVING-WINDOW ACCEPTANCE (`2026-09-04`): after manual exploration from
  `(0,0)`, the decoded stair at `(9,9)` became selectable once it entered the
  three-tile square. Route-preview traces at frames `151611` and `151793`
  targeted `stair_9_9` from `(7,9)` and `(7,8)` without exposing it earlier.
  A fresh report at frame `157260` confirmed B1 `(7,8)`, raw radius `7`,
  half-span `3`, and Radiant timer `61`. `current_object` at frame `157620`
  reported `Stairs Down: 1 south, 2 east (1 of 1)`; the old entrance at `(0,0)`
  was now outside the window and correctly absent. Proximity-based reveal and
  moving object-window updates are live-accepted.
- LIVE SHRINK-BOUNDARY SETUP (`2026-09-04`): one successful step from `(7,8)`
  to `(7,9)` reduced the Radiant timer from `61` to `60`, while the raw light
  radius remained `7` and the visible half-span remained `3`. No shrink speech
  was expected for that step because the visible radius did not change. A
  second successful step to `(6,9)` reduced the timer to `59` with radius `7`
  and half-span `3` still unchanged; no new `LIGHT_RADIUS_CHANGED` event was
  logged. The timer is the remaining count for the current light phase, so the
  first shrink should occur only after the remaining 59 successful steps, not
  at the transition from timer 60 to 59.
  After further manual wandering, a fresh report at B1 `(4,0)` found timer
  `14`, raw radius `7`, and half-span `3`; the countdown correctly remained
  silent because no radius change had occurred. Fourteen successful movements
  remain before the expected first shrink.
- LIVE FIRST RADIANT SHRINK ACCEPTANCE (`2026-09-04`): frame `198101` logged
  exactly one `LIGHT_RADIUS_CHANGED` event from raw radius `7` / half-span `3`
  to raw radius `5` / half-span `2`, with the next phase timer reset to `60`.
  The user heard the light-dims announcement and observed the visible radius
  shrink. A fresh report at B1 `(3,1)` found radius `5`, half-span `2`, and
  timer `58`, confirming two successful movements after the transition.
- LIVE SECOND SHRINK / FADE ACCEPTANCE (`2026-09-04`): frame `209831` logged
  exactly one change from raw radius `5` / half-span `2` to radius `3` /
  half-span `1`, resetting the phase timer to `60`. Frame `274265` then logged
  exactly one change to raw radius `1` / half-span `0`, again with timer `60`.
  The user observed both visible-window reductions and heard at least part of
  each announcement. A fresh report at B1 `(1,0)` found radius `1`, half-span
  `0`, and timer `53`; `current_object` returned `No objects found`, correctly
  hiding the adjacent entrance at `(0,0)`. The remaining timer phase has no
  additional visible-radius change and does not need countdown speech.
- FOLLOW-UP / SPEECH POLISH: held directional input can interrupt important
  light-dimming and fade announcements in JAWS. Address reliable warning
  delivery after the darkness slice rather than expanding this focused patch.
- LIVE SECOND RADIANT SHRINK ACCEPTANCE (`2026-09-04`): frame `209831` logged
  exactly one `LIGHT_RADIUS_CHANGED` event from raw radius `5` / half-span `2`
  to raw radius `3` / half-span `1`, with the final phase timer reset to `60`.
  The user heard part of the light-dims announcement before held-arrow speech
  interrupted it and independently observed the smaller window. A fresh report
  at B1 `(1,1)` found radius `3`, half-span `1`, and timer `56`.
  `current_object` exposed only the entrance at `(0,0)`, exactly one north and
  one west, matching the one-tile visibility window.
- SOURCE MODEL: cave/dungeon terrain offset `0x20` is visibility-limited.
  `LIGHT_RADIUS` values `1`, `3`, `5`, and `7` are treated as visible-window
  diameters, yielding zero through three tiles of visible half-span. This
  interpretation needs direct FCEUX confirmation with no light, Torch, and
  Radiant before promotion to durable project truth.
- SOURCE-COMPLETE: `darkness.lua` centralizes the visible square, player-facing
  light descriptions, radius-change speech, and non-mutating walkability masks.
  Ordinary object browsing now hides modeled objects outside that square and
  updates as the hero or radius changes. Ordinary selected-object previews and
  reachability checks use a light-masked walkability snapshot. Explicit
  developer coordinate planning remains unrestricted.
- DIAGNOSTIC: `report_light_state` logs map, terrain, position, raw radius,
  visible half-span, Radiant timer, and whether darkness limits navigation.
  `log_state` snapshots now include the two light bytes.
- STATIC CHECKPOINT: focused suites pass `6/6` darkness, `116/116` objects,
  `148/148` route-manager, and `41/41` debug-tools tests. The broad native gate
  passes all 34 host-runnable Lua suites plus 68 Python tests; Lua syntax,
  shell syntax, command-queue, speech-dependency, and `git diff --check` checks
  also pass. Live Erdrick's Cave acceptance remains pending.
- NEXT CHECK: reload `main.lua` in Erdrick's Cave B1. Capture
  `report_light_state` unlit, after Torch, and after Radiant; browse Travel and
  Treasure after each state; then move until the radius shrinks and confirm one
  announcement per visible-span change.

## 2026-09-02 Off-Network Drift Recovery Acceptance

- CLEAN / VERIFIED: deliberate manual drift preserved the Eastern Great Swamp
  destination. Recovery started from World Map `(58,109)`, walked five decoded-
  safe steps to network entry `(58,104)`, stopped at the boundary in continuous
  mode, and resumed the guided route only after another auto-walk press.
- TIMING GAP: confirmed poison entry `(66,109)->DOWN` produced the same early
  subpixel twitch without coordinate movement on three attempts, each stopping
  after the 33-frame timing-suspect window. Opening and closing the command menu
  cleared the condition; the next confirmed attempt reached `(66,110)` in 24
  frames and the route completed at `(89,112)`.
- DO NOT PROMOTE: `(66,110)` is noisy but proven passable. This is movement
  timing, not overworld geometry or a permanent blocker.
- LIVE FAILURE / DO NOT PROMOTE: the first recovery draft fired exactly once at
  frame `1566`, but it reset normal idle bytes `0x7F/0x90` to `0x00/0x00` and
  re-injected DOWN in that same frame. The retry twitched `0x00->0x90`, then
  stopped at `(66,109)` after its bounded timeout. This remains timing evidence,
  not a blocker at `(66,110)`.
- CLEAN FOLLOW-UP: after the command menu opened and closed, a newly confirmed
  attempt crossed `(66,109)->(66,110)` in 23 frames. The complete route then
  reached `(89,112)` with no further player-facing failure.
- CODED / UNIT VERIFIED: the revised recovery resets the movement bytes, holds
  a neutral controller for at least 16 frames so the ROM can observe the reset,
  then performs its single bounded retry. All 153 auto-step tests pass.
- NEXT CHECK: reload `main.lua` and repeat `(66,109)->DOWN`. If the early twitch
  recurs, it should settle and cross automatically without another auto-walk
  press, command-menu recovery, or overshoot to `(66,111)`.
- CLEAN LIVE SAMPLE: after reload, the first rerun crossed
  `(66,109)->(66,110)` directly in 24 frames and arrived at Eastern Great Swamp
  `(89,112)` at frame `1825`. A second rerun began the guided swamp leg from
  `(66,110)` and arrived at the same destination at frame `5547`. Neither run
  blocked, drifted, or invoked `AUTO_STEP_CONFIRMED_HAZARD_TIMING_RETRY`, so
  normal behavior is accepted but the revised reset-and-settle branch remains
  covered by regression rather than live activation.
- CLEAN INTERRUPTION RECOVERY: from `(58,108)`, recovery targeted network entry
  `(58,104)` while preserving Eastern Great Swamp. Opening the command menu
  canceled movement at `(58,107)` with `reason=can_walk_false`. After the menu
  closed, the next auto-walk invocation replanned exactly three north steps
  from `(58,107)`, reached `(58,104)`, and logged `handoff_ready` with
  `continuous_requested=true boundary_stop=true`. No runtime blocker or route
  drift was recorded.
- REGRESSION: `off_network_recovery_menu_interrupt_replans_from_current_position`
  reproduces that boundary flow deterministically. It verifies silent
  `can_walk_false` cancellation one tile into recovery, replanning from the live
  interrupted cell with only the remaining steps, one preserved-destination
  handoff, and no continuous auto-chain across the network boundary. Focused
  route-manager tests pass 141/141; the native gate passes all 33 host-runnable
  Lua suites plus 68 Python tests; `git diff --check` passes.
- CLEAN MOUNTAIN-CAVE RECOVERY: from `(24,60)`, the first correctly timed menu
  interruption canceled recovery at `(24,59)` with `reason=can_walk_false`.
  The next auto-walk replanned exactly one north step, reached network entry
  `(24,58)`, preserved Mountain Cave, and logged `handoff_ready` with the
  continuous boundary stop. The first ordinary guided attempt from `(24,58)`
  right to `(25,58)` exhausted two timing retries without moving; the next
  player auto-walk invocation crossed it after one timing-suspect retry. That
  successful traversal changed the seam classification from `blocked_only` to
  `noisy`, so it is timing evidence and not a permanent blocker. The remaining
  route completed and entered Mountain Cave map `0x16` at `(0,7)`. Fresh frame
  10920 reported path target nil and zero runtime/NPC blockers; the script-error
  file remains unchanged since May.
- BATTLE NEAR-MATCH / PARTIAL ACCEPTANCE: Swamp Cave recovery began at
  `(95,38)` and reached intended entry `(95,35)`, but final settle carried one
  extra tile to `(95,34)` and canceled with `route_drift_off_path`. The next
  auto-walk replanned one east step to entry `(96,34)`, preserved
  `swamp_cave_bridge`, and logged `handoff_ready`. A battle began 32 frames
  after that recovery completion, while movement was already stopped at the
  network boundary; it therefore did not exercise battle cancellation during
  active recovery. After combat, auto-walk correctly continued the preserved
  Swamp Cave route from `(96,34)`. Fresh frame 559860 found the hero at
  `(94,40)` with path target nil and zero runtime/NPC blockers. This validates
  post-boundary battle preservation, but the narrower active-recovery battle
  interruption remains untested.
- COVERAGE AUDIT READY: added a read-only destination-specific whole-overworld
  audit that classifies decoded cells as established network, safe recovery
  within the 24-step execution limit, safe recovery beyond the limit,
  hazard-required, unreachable, transition, or non-walkable. It uses reverse
  multi-source traversal from every eligible entry and emits structured counts
  plus representative coordinates without changing route or movement state.
  Two focused regressions pass 143/143 route-manager tests, including the
  24-step split and a poison-separated region. Lua syntax, `git diff --check`,
  and the native full gate pass all 33 host-runnable Lua suites plus 68 Python
  tests. Live ROM-backed counts still require reloading `main.lua`, then running
  `audit_overworld_recovery:ROUTE_ID` for the 16 canonical destinations.
- LIVE COVERAGE RESULT: all 16 canonical destinations completed at frame groups
  3720, 6780, 7440, and 7980. Every candidate passed the route-opening limit
  (`rejected_opening=0`); destination sets contain 714-849 eligible entries.
  The common map partition is 975 network cells, 23 transition cells, and 5530
  non-walkable cells. Depending on destination, 7127-7189 off-network cells are
  safely recoverable within 24 steps and 398-460 are safe but over the limit.
  All destinations share 276 hazard-required cells and 9 unreachable cells.
  Worst safe recovery distance is 117, represented at `(92,110)`, `(91,111)`,
  and `(90,112)`; nearby distance-116 examples are `(85,108)` and `(93,108)`.
  Cantlin and Great Swamp are the largest over-limit sets at 460; Tantegel and
  Brecconary are smallest at 398. Representative unreachable cells cluster by
  automatic entrances: `(105,43)`, `(105,44)`, and `(101,71)` through
  `(103,71)`. Treat these as a focused transition-pocket review before changing
  map or route data. Post-audit frame 10800 remained World Map `(94,40)` with
  path target nil and zero runtime/NPC blockers.
- RECOMMENDATION: implement bounded recovery checkpoints for the 398-460
  decoded-safe over-limit cells rather than raising the 24-step cap. Preserve
  the existing stop-and-reconfirm boundary at each slice. Keep the 276 hazard-
  required cells manual-only, and inspect the nine transition-pocket cells as
  a separate geometry audit rather than folding them into checkpoint work.
- CHECKPOINT / SEARCH OPTIMIZATION SOURCE-COMPLETE: safe recovery paths longer
  than 24 steps now queue only the first 24-step slice, stop at a named safe
  checkpoint, and require another auto-walk press. Intermediate checkpoints do
  not falsely start the destination route; only the actual waypoint-network
  boundary performs the existing explicit handoff. Hazard-required recovery
  remains manual-only.
- STARTUP-LAG REDUCTION: recovery now builds one forward decoded-safe distance
  field from the hero, selects the same nearest eligible entry, and runs A-star
  once to preserve its turn/path tie behavior. If the field and A-star ever
  disagree, it logs `OVERWORLD_RECOVERY_SEARCH_FALLBACK` and repeats the exact
  legacy search. Established corridor membership and destination candidate
  lists are cached; callers receive a fresh candidate array, and repeated
  checkpoint presses retain current runtime-block safety by rebuilding the
  distance field each time. Offline candidate construction dropped from about
  478-1157 ms to 132-191 ms on a cold lookup and approximately 0 ms when
  repeated from cache.
- STATIC VERIFICATION: Lua syntax and `git diff --check` pass. Focused suites
  pass `340/340` overworld-route tests and `143/143` route-manager tests. The
  native `python -u run_tests.py` gate passes all 33 host-runnable Lua suites,
  all 68 Python tests, speech dependency, and command-queue checks.
- LIVE ACCEPTANCE COMPLETE: after reload, Charlock recovery from World Map
  `(92,110)` selected network entry `(23,98)` at the audited distance of 117
  steps. The cold search took 187 ms, including 127 ms to build 849 destination
  candidates. Every later authorization reused that cache: candidate lookup
  took 0-1 ms and total planning took 47-64 ms. Every search used one final
  A-star call and `fallback=false`.
- CHECKPOINT PROOF: after two partial attempts were interrupted, four complete
  24-step checkpoints ended at `(82,84)`, `(63,81)`, `(48,90)`, and `(32,98)`.
  The final nine-step authorization reached the real network boundary
  `(23,98)` and only then handed Charlock to `hauksness_return_staging` toward
  `Hauksness western corridor`. Continuous mode did not cross any checkpoint
  or the network boundary without another press.
- INTERRUPTION / TIMING EVIDENCE: a Wraith battle began two frames after a
  timeout at `(91,110)->LEFT`, so the pre-battle field frame logged a diagnostic
  blocked seam; it added no runtime block. A Starwyvern battle canceled active
  recovery at `(89,101)` with `reason=can_walk_false`. Charlock remained the
  final destination across both. The one player-facing timing stop at
  `(91,105)->UP` crossed on the next authorization and changed its seam record
  from `blocked_only` to `noisy`; do not promote it as map geometry. Internal
  bounded retries at `(63,81)->DOWN` and `(32,98)->LEFT` also recovered without
  manual movement.
- FINAL BASELINE: fresh probe `CHECKPOINT_RECOVERY_ACCEPTANCE` was consumed at
  frame 22140. Frame 22500 reported World Map `(23,98)`, path target nil, zero
  NPC blockers, zero runtime blockers, and no new script error. Long safe
  checkpoint recovery and its startup-lag optimization are accepted live.
- DIAGNOSTIC FIX SOURCE-COMPLETE: timing-suspect ordinary overworld timeouts
  now defer only their blocked-seam observation for three frames. Route
  stopping remains immediate. If `battle_started` arrives during that window,
  the pending observation is discarded with
  `SEAM_OBSERVATION_SUPPRESSED reason=battle_started`; otherwise it is recorded
  normally with `SEAM_OBSERVATION_RELEASED reason=battle_grace_elapsed`.
  Regressions cover both branches and confirm that recovery cancellation is
  not delayed. Lua syntax, `git diff --check`, all 33 host-runnable Lua suites,
  and all 68 Python tests pass.
- DIAGNOSTIC FIX LIVE-ACCEPTED: at frame `23075`, recovery timed out on World
  Map `(48,92)->DOWN` and logged `SEAM_OBSERVATION_DEFERRED`. A Werewolf battle
  appeared exactly two frames later; frame `23077` logged
  `SEAM_OBSERVATION_SUPPRESSED reason=battle_started`, with no blocked seam
  recorded. After combat, the unchanged route crossed that same edge at frame
  `24055` and recorded destination `(48,93)` as `passable_only`. This is the
  exact race the fix targets, and it now leaves no false blocker evidence.
- BATTLE-DIALOGUE POLISH SOURCE-COMPLETE: the Magiwyvern encounter beginning at
  frame `16333` spoke coherent-looking redraw mixtures at frames `16699`,
  `16714`, `17367`, and `17382`. Examples include `Points have been reduced by
  41. Magiwyvern chants the spell of Thou art asleep.` The proper attack,
  `SLEEP`, and sleep-status lines had already been announced. Battle snapshots
  retained stable hero stats, no integrity warning fired, and
  `dw_script_error.log` remains unchanged since May. Treat this as battle
  window overlap/fast-dialogue filtering, not ROM, save, or route corruption.
  The captured pages are now regressions: impossible `spell of Thou art`
  splices and clipped leading damage suffixes are rejected, while clean
  `SLEEP. Thou art asleep.` dialogue remains valid. Fast battle narration now
  advances sentence by sentence and stops before spell/status text rather than
  letting an earlier attack validate the whole mixed page. The focused battle
  suite passes `47/47`; Lua syntax, `git diff --check`, all 33 host-runnable
  Lua suites, and all 68 Python tests pass.
- BATTLE-DIALOGUE POLISH LIVE-ACCEPTED: after reload, the Magiwyvern encounter
  beginning at frame `8591` announced the clean combined action at frame
  `9747`, `Bill chanted the spell of HEAL. Magiwyvern chants the spell of
  SLEEP.` Sleep status followed at frame `9784`, then clean `Thou art asleep`,
  `Thou art still asleep`, attacks, damage, and `Bill awakes` dialogue through
  frame `10395`. Neither `spell of Thou art asleep` nor a dialogue event
  beginning with the clipped `Points have been reduced` / `reduced by` forms
  appeared. The user reported the same run as much improved.

## 2026-08-18 Rimuldar Intermediate-Town Bypass

- CLEAN / VERIFIED: hidden `rimuldar_staging` and
  `rimuldar_magic_temple_staging` legs stop at east doorstep `(103,72)`;
  direct Rimuldar routes retain town entrance `(102,72)`.
- RETURN CHECK: from Magic Temple `(108,109)`, frame `9887` handed off from
  `rimuldar_magic_temple_staging` to `swamp_cave_south_magic_temple` on the
  World Map without entering Rimuldar.
- OUTBOUND CHECK: from accepted approach waypoint `(88,58)`, frame `15485`
  handed off from `rimuldar_staging` to `magic_temple` on the World Map.
- FINAL AUDIT: frame `16080` reported World Map `(110,80)`, path target nil,
  and zero runtime blockers. Both handoffs had no map change, blocked step,
  exhausted retry, or runtime-block injection; autowalk was stopped manually
  after each requested bypass was proven.
- STATIC VERIFICATION: `233/233` overworld-route tests and `123/123`
  route-manager tests pass; the full gate passes all 33 host-runnable Lua
  suites and 68 Python tests; `git diff --check` passes.

## 2026-08-17 Magic Temple to Tantegel

- STATIC IMPLEMENTATION: a Tantegel request outside Magic Temple `(108,109)`
  now composes `rimuldar_magic_temple -> swamp_cave_south_magic_temple ->
  kol_swamp_cave_staging -> tantegel_kol`.
- REUSED GEOMETRY ONLY: the internal southern leg copies the accepted
  Rimuldar-to-Swamp-Cave route and retains the automatic cave-entry wait. No
  waypoint or map geometry changed.
- LIVE ACCEPTANCE: frame `2520` started `rimuldar_magic_temple`; frame `5969`
  entered Rimuldar and handed off to `swamp_cave_south_magic_temple`; frame
  `17805` entered Swamp Cave; frame `20976` exited north; frame `27311`
  bypassed Kol; and frame `34223` entered Tantegel Castle. The known cave-exit
  seam `(104,44)->UP` passed on the first activation. Final frame `35880` found
  Castle `(11,29)`, route/path nil, and zero runtime blockers.
- FUTURE POLISH: passing routes should bypass Rimuldar instead of entering town,
  consistent with the existing Kol and Cantlin exterior staging variants.

## 2026-08-17 Rainbow Bridge to Tantegel

- CLEAN / VERIFIED: a Tantegel request at the Rainbow Bridge unlock point
  `(65,49)` now starts `rainbow_bridge_return`, retains Tantegel as the final
  Travel destination, waits for automatic entry into Swamp Cave map `0x15`,
  then continues through `kol_swamp_cave_staging -> tantegel_kol`.
- REUSED GEOMETRY ONLY: no waypoint or map geometry changed. The connection
  composes the live-validated eastbound bridge return with the accepted
  Swamp Cave/Kol/Tantegel chain.
- LIVE ACCEPTANCE: frame `4980` started `rainbow_bridge_return`; frame `7037`
  entered Swamp Cave and handed off; frame `11410` exited north; frame `20398`
  bypassed Kol; and frame `27310` entered Tantegel Castle. The known
  `(104,44)->UP` cave-exit seam exhausted one activation, then passed unchanged
  on the next; do not promote it as geometry. Final frame `27720` found Castle
  `(11,29)`, route/path nil, and zero runtime blockers.

## 2026-08-17 Charlock Castle to Tantegel

- CLEAN / VERIFIED: a Tantegel request at World Map `(48,48)` now starts
  `charlock_return`, retains Tantegel as the final Travel destination, waits
  for automatic entry into Swamp Cave map `0x15`, then continues through
  `kol_swamp_cave_staging -> tantegel_kol`.
- REUSED GEOMETRY ONLY: this composes the already live-validated Charlock
  return, Swamp Cave/Kol return, and Kol-to-Tantegel legs. No waypoint or map
  geometry changed.
- LIVE ACCEPTANCE: frame `4740` started `charlock_return`; frame `9225`
  entered Swamp Cave and handed off; frame `12765` exited north; frame `24193`
  bypassed Kol; and frame `31105` entered Tantegel Castle. The first Charlock
  south step recovered after two timing retries. The known `(104,44)->UP`
  cave-exit seam exhausted one activation, then passed unchanged on the next;
  do not promote it as geometry. Final frame `31500` found Castle `(11,29)`,
  route/path nil, and zero runtime blockers.

## 2026-08-17 Swamp Cave South to Tantegel

- CLEAN BASELINE: World Map `(104,49)`, route/path nil, zero NPC/runtime
  blockers, fresh loaded probe at frame `12360`.
- LIVE FAILURE: Tantegel correctly selected `swamp_cave_south`, but standing on
  its final automatic-entry tile immediately handed off to
  `kol_swamp_cave_staging`.
  Autowalk then tried the invalid direct edge `(104,49)->UP`, exhausted two
  timing retries, and stopped. This is itinerary state, not map geometry; do
  not promote the blocked observation.
- CLEAN / VERIFIED: connected itineraries now keep `swamp_cave_south` active
  at `(104,49)` and hand off only after Swamp Cave map `0x15` is observed.
  Autowalk at the exterior tile stayed safely in place with
  `already_at_waypoint`. Cave entry is automatic on stepping onto `(104,49)`;
  a hero already standing there must step off and back on. Frame `17087`
  handed off inside the cave, frame `18518` returned from the north exit,
  frame `28989` bypassed Kol, and frame `35901` entered Tantegel Castle.
  Final audit at frame `36180` found Castle `(11,29)`, route/path nil, and zero
  runtime blockers.

## 2026-08-15 Connected Rimuldar Route Implementation

- CURRENT FAILURE: selecting Rimuldar from World Map `(43,43)` starts the
  local `rimuldar` route directly at `South island west ridge lane` and
  synthesizes one unvalidated 51-step segment (`11 south, 40 east`).
- IMPLEMENTED ITINERARY: `kol_staging -> swamp_cave -> rimuldar`. The first two
  legs reuse the live-verified Tantegel-to-Swamp-Cave route. Entering Swamp
  Cave map `0x15` at north interior `(0,0)` hands off to `rimuldar` without
  injecting movement. The player traverses the cave to south stair `(0,29)`;
  exiting to World Map `(104,49)` resumes the existing live-verified Rimuldar
  route and first targets `North Rimuldar west safer route` `(93,49)`.
- MINIMAL SOURCE CHANGE: added a Rimuldar-only staging guard whose fallback is
  `swamp_cave`, with `max_start_distance = 13` and staged continuation enabled.
  Thirteen is the longest established Rimuldar segment. Direct and nearby
  starts at `(104,49)` or along the existing south-cave-to-Rimuldar corridor
  remain local and unchanged.
- HANDOFF CONTRACT: reaching Kol west doorstep `(103,10)` activates
  `swamp_cave`; entering map `0x15` at `(0,0)` activates `rimuldar`; neither
  handoff queues movement. Status and Travel-object matching retain Rimuldar
  as the final destination through both legs and while inside the cave.
- TEST-FIRST VERIFICATION: regressions failed first against the old direct
  Rimuldar selection. Coverage asserts alias and Travel-object starts from `(43,43)`,
  ordered `kol_staging -> swamp_cave -> rimuldar` handoffs, current-leg/final-
  destination speech, guidance refresh, cancellation cleanup, no automatic
  handoff movement, the south-exit first segment of 11 LEFT steps, and the
  unchanged direct `(104,49)` start. It also covers the expected nested effect that
  a far Magic Temple request inherits the new Rimuldar connection without
  claiming it live-accepted in this slice. Focused route tests pass `199/199`;
  the full gate passes all 33 host-runnable Lua suites plus 68 Python tests.
- LIVE ACCEPTANCE PLAN: after source tests and a manual `main.lua` reload,
  start on a clean World Map `(43,43)`. Use continuous overworld auto-walk for
  the exterior legs, manually traverse Swamp Cave north `(0,0)` to south
  `(0,29)`, exit at `(104,49)`, then continue to Rimuldar map `0x0B` `(29,14)`.
  Require clean handoff logs, preserved final destination, no unintended town
  entry, and zero runtime blockers at final arrival.
- LIVE ACCEPTANCE: baseline tag `RIMULDAR_CONNECTED_BASELINE_20260815`
  confirmed World Map `(43,43)`, route none, and zero runtime blockers. The
  route started as `kol_staging`, handed off to `swamp_cave` at Kol west
  `(103,10)` without entering town, and entered Swamp Cave map `0x15` at
  `(0,0)`. The handoff activated `rimuldar` with path nil and no injected cave
  movement. The user then autowalked a perfect cave route to `(0,29)` and
  exited at World Map `(104,49)`. Tag `RIMULDAR_SOUTH_EXIT_20260815` confirmed
  the preserved route targeting `(93,49)`, path nil, and zero runtime blockers.
  Continuous walking completed the established southern route, including
  `(99,69)->south`, and entered Rimuldar map `0x0B` at `(29,14)`. Final tag
  `RIMULDAR_CONNECTED_ARRIVAL_20260815` confirmed route none, path nil, and
  zero runtime blockers. No blocker, cancellation, timing-retry, or
  exhausted-retry event occurred. This slice is live-accepted.
- ACCEPTED RERUN / SPEECH CLEANUP: the user repeated the full
  Tantegel-to-Rimuldar itinerary and accepted its movement. The south cave exit
  exposed the stale warning `Guide-derived Rimuldar route. The west route is
  safer but still needs live validation.` It now warns `Poison swamp ahead
  after leaving the cave. Watch HP while crossing.` A focused regression failed
  against the stale warning, then passed `199/199`; the broad gate again passed
  all 33 host-runnable Lua suites plus 68 Python tests.

## 2026-08-15 Garinham and Erdrick's Cave Brecconary Bypass

- STATIC AUDIT: `garinham` and `erdrick` were the only remaining outbound
  routes that used Brecconary entrance `(48,41)` as an intermediate waypoint.
  Reverse `tantegel` and `tantegel_kol` already go directly from Bridge south
  bend `(44,38)` to Tantegel, while direct `brecconary` intentionally still
  ends at `(48,41)`.
- SOURCE CHANGE: both affected routes now reuse the live-proven Brecconary west
  bypass `(47,41)`, radius 0, before turning north to `(44,38)`. No later
  Garinham, cave, bridge, warning, destination, or blocker data changed.
- TEST-FIRST VERIFICATION: new route regressions failed against the old
  `(48,41)` waypoints. Four drift/warning fixtures were then updated from the
  obsolete Erdrick-route waypoint to `(47,41)`. Focused route tests pass
  `194/194`; the full gate passes all 33 host-runnable Lua suites plus 68
  Python tests.
- GARINHAM LIVE PASS: fresh tag `GARINHAM_BYPASS_BASELINE_20260815`
  confirmed World Map `(43,43)`, route/path nil, and zero NPC/runtime blockers.
  The loaded route completed `(43,43) -> (47,41)`, then continued north to
  `(44,38)` without entering Brecconary map `0x08`. It traversed the unchanged
  corridor and entered Garinham map `0x09` at `(0,14)` with no blocker or
  cancellation event. Final tag `GARINHAM_BYPASS_ARRIVAL_20260815` confirmed
  route/path nil and zero runtime blockers. Garinham is live-verified.
- ERDRICK LIVE PASS: fresh tag `ERDRICK_BYPASS_BASELINE_20260815` confirmed
  World Map `(43,43)`, route/path nil, and zero NPC/runtime blockers. The route
  completed the same `(47,41)` bypass, turned north through `(44,38)`, and did
  not enter Brecconary map `0x08`. It entered Erdrick's Cave map `0x1C` at
  `(0,0)`. Final tag `ERDRICK_BYPASS_ARRIVAL_20260815` confirmed route/path nil
  and zero runtime blockers. Neither loaded route logged a blocker,
  cancellation, or exhausted retry. This polish slice is live-accepted.

## 2026-08-15 Kol/Hauksness Intermediate-Town Bypass

- SOURCE CHANGE: direct `kol` now passes Brecconary via `(47,41)` and turns
  north before reconnecting at `(44,38)`. Connected destinations use hidden
  `kol_staging`, which shares the corrected corridor but ends at Kol west
  doorstep `(103,10)` instead of town entrance `(104,10)`. Direct Kol travel
  still enters Kol, and accidental map-`0x07` entry remains a fallback handoff.
- SOURCE VERIFICATION: the new old-route regressions failed first, then the
  focused route suite passed `191/191`. Lua syntax, `git diff --check`, and the
  native Windows broad gate of all 33 host-runnable Lua suites plus 68 Python
  tests passed.
- LIVE ACCEPTANCE: after the unexpected system restart, fresh tag
  `KOL_STAGING_RESTART_BASELINE_20260815` confirmed World Map `(43,43)`, route
  none, path nil, and zero NPC/runtime blockers. A continuous Hauksness run
  passed Brecconary at `(47,41)` without entering map `0x08`. At `(103,10)` it
  emitted `event=handoff route=hauksness ... from_route=kol_staging`, then
  turned west without entering Kol map `0x07`. The established Hauksness leg
  completed without blocker or exhausted-retry events and entered map `0x03`
  from `(24,89)`. Final tag `KOL_HAUKSNESS_POLISH_FINAL_20260815` confirmed
  Ruins of Hauksness `(0,10)`, route none, path nil, and zero NPC/runtime
  blockers. This polish slice is accepted.
- CANTLIN FOLLOW-UP / SOURCE FIX: the user's next Cantlin run proved the
  ordinary Hauksness intermediate leg still entered the ruins. At frame
  `23131`, continuous walking queued `(24,89)->RIGHT`; frame `23159` entered
  map `0x03` and only then emitted the Cantlin handoff. Fresh tag
  `CANTLIN_HAUKSNESS_ENTRY_VERIFY_20260815` confirmed map `0x03` `(0,10)`,
  active `cantlin_hauksness`, path nil, and zero runtime blockers. Cantlin now
  stages through hidden `hauksness_staging`, copied only through exterior
  `(24,89)`, then hands off west toward `(22,89)`. Direct Hauksness travel and
  accidental-entry fallback remain intact. The two changed regressions failed
  first; focused tests now pass `191/191`, and the full 33-Lua-suite plus
  68-Python-test gate passes. Loaded validation handed off on World Map
  `(24,89)` at frame `15739` with no map change, then queued LEFT toward
  `(22,89)` and arrived there at frame `15836`. The route continued normally
  toward Cantlin, entered map `0x0A` at frame `21307`, and landed at `(15,0)`.
  Fresh tag `CANTLIN_TOWN_BYPASS_FINAL_20260815` confirmed route none, path
  nil, and no runtime blockers. The exterior handoff and final arrival are
  live-accepted.

## 2026-08-14 Connected Hauksness Route and Continuous Auto-Walk

- TEST-FIRST FAILURE: from World Map `(43,43)`, both name and Travel-object
  Hauksness starts selected `hauksness` directly and targeted `North Alefgard
  east road`, synthesizing 30 north plus 2 east instead of following the Kol
  hub. The new staging-start, object-binding, and Kol-handoff regressions failed
  before the source patch; the on-route Garinham control remained direct.
- MINIMAL ROUTE PATCH: `HAUKSNESS_STAGING` uses `kol`, canonical continuation
  `hauksness`, a 24-tile maximum direct-start distance, and automatic staged
  continuation. It is shared by the Kol-side and Cantlin-side Hauksness target
  variants so far starts converge on one canonical destination while direct
  Kol, Garinham, and Cantlin behavior remains covered. No established Hauksness
  waypoint or blocker changed.
- CONTINUOUS FEATURE INTEGRATED: the finished sibling-branch implementation was
  transplanted without creating a commit. `config.lua` and the checked-in
  `dw_access.ini` expose `overworld_auto_walk_continuous=false`, preserving
  waypoint mode as the shipped default. Setting it to `true` enables continuous
  travel for players or debugging: it automatically queues the next guided
  waypoint, keeps warnings and terminal arrival speech, avoids routine
  waypoint/per-segment chatter, stops on battle/menu/dialogue, and preserves
  whole-route `auto_walk_blocker` behavior.
- SOURCE VERIFICATION: `179/179` overworld-route, `123/123` route-manager, and
  `3/3` config tests pass. The full native Windows gate passes every one of 33
  host-runnable Lua suites, all 68 Python tests, Lua/Python/shell syntax, speech
  dependency, command queue, and `git diff --check`. FCEUX needs a manual
  `main.lua` reload before a fresh `(43,43)` live run.
- FULL CONNECTED LIVE VERIFICATION: with continuous mode temporarily enabled,
  from World Map `(43,43)`, selecting
  Hauksness started `kol` at waypoint 2 with `staged_from=hauksness`. Continuous
  auto-walk exposed only the known early-route Brecconary entry; one initial
  `(43,43)->UP` timing retry recovered automatically. After the player exited
  Brecconary, the Kol leg continued without another activation until map `0x07`.
  Entry emitted `event=handoff route=hauksness ... from_route=kol` before town
  handling, preserving the intended destination. After the player exited Kol
  at `(104,10)`, one continuous Hauksness activation traversed every remaining
  waypoint with zero timeout, blocker, or cancellation events and entered map
  `0x03` from doorstep `(24,89)`. Fresh tag `HAUKSNESS_ARRIVAL_20260814`
  confirmed Ruins of Hauksness `(0,10)`, route none, path nil, and zero
  NPC/runtime blockers. The connected slice is live-verified; early-route town
  entry remains a separate polish task.

## 2026-08-13 Connected Magic Temple Route Plan

- RECOMMENDED NEXT TARGET: Magic Temple, using the narrow connected itinerary
  `Swamp Cave South Entrance -> Rimuldar -> Magic Temple`. This is preferable
  to a Kol-to-Hauksness expansion for the next slice because both legs are
  already live-validated, the route advances an important progression target,
  and it avoids introducing new map geometry or a very long Kol detour.
- ESTABLISHED ENDPOINTS: stage on World Map `(104,49)`. The existing
  `rimuldar` route has 33 waypoints and enters Rimuldar at World Map `(102,72)`
  / town map `0x0B` `(29,14)`. The existing `magic_temple` route has 22
  waypoints from `(102,72)` to the temple stand `(108,109)`; STAIRS there enters
  map `0x0E` at `(0,4)`. The longest established segment in either leg is 13
  tiles, so a 13-tile staging threshold cleanly distinguishes the south-cave
  start from the direct Rimuldar start.
- CURRENT FAILURE SHAPE: a static route probe from `(104,49)` currently starts
  `magic_temple` directly, chooses `Rimuldar east doorstep` `(103,72)`, and
  synthesizes one unvalidated 24-step segment. With the proposed staging,
  `(104,49)` instead starts `rimuldar` at waypoint 2, `North Rimuldar west safer
  route` `(93,49)`, keeping every segment on the established corridor.
- MINIMAL SOURCE DESIGN: add a Magic-Temple-only staging config pointing to
  `rimuldar`, with `max_start_distance = 13`,
  `prefer_staging_route_corridor = true`, and staged continuation enabled.
  Attach it only to `magic_temple`; do not change shared staging behavior or
  generalize the route graph in this slice. Starting at `(104,49)` should select
  `rimuldar` waypoint 2 (`North Rimuldar west safer route`) and retain
  `magic_temple` as the requested final destination. Starting at `(102,72)`
  must continue to select the direct Magic Temple route unchanged.
- TEST-FIRST COVERAGE: add focused regressions for name-based and Travel-object
  starts at `(104,49)`, current-leg/final-destination status, active-object
  binding during the Rimuldar leg, and the map-`0x0B` handoff. The handoff must
  activate `magic_temple`, name `Rimuldar east doorstep` as the next waypoint,
  queue no movement, and preserve the first explicit step RIGHT from
  `(102,72)` to `(103,72)`. Retain the existing direct-start, exact-corridor,
  reverse-route, and Magic Temple arrival tests.
- SOURCE CHANGE COMPLETE: the five new regressions first failed against the
  direct 24-step shortcut and missing Rimuldar handoff. `magic_temple` now has
  its own 13-tile Rimuldar staging config with corridor preference and staged
  continuation. From `(104,49)`, it selects `rimuldar` waypoint 2 at `(93,49)`
  and retains Magic Temple as the final destination. Entering Rimuldar map
  `0x0B` hands off to `magic_temple` waypoint 2 without queuing movement; the
  next explicit segment is one step RIGHT from `(102,72)` to `(103,72)`. The
  direct start at `(102,72)` remains unchanged. All `175/175` focused route
  tests, all 33 host-runnable Lua suites, all 68 Python tests, Lua syntax, shell
  syntax, Python syntax, the speech dependency check, the command queue check,
  and `git diff --check` pass. Awaiting manual `main.lua` reload and live
  validation from Swamp Cave South.
- LOADED FIRST LEG / HANDOFF COMPLETE: fresh tag
  `MAGIC_TEMPLE_CONNECTED_RELOAD_20260814` confirmed World Map `(104,49)`,
  path nil, and zero NPC/runtime blockers. Starting Magic Temple emitted
  `event=start route=rimuldar waypoint=North Rimuldar west safer route index=2
  staged_from=magic_temple`; the first 11-step west segment completed at
  `(93,49)`. The old Rimuldar route then reproduced its documented rough area:
  queued movement and a same-origin 60-frame raw hold both blocked
  `(93,52)->DOWN`, and a reversible movement-state reset did not change it.
  Live recovery found the usable north/south opening at `x=86` and retraced the
  already-established return corridor through `(86,54)`, `(83,54)`, `(83,56)`,
  `(85,56)`, `(85,58)`, and `(88,58)`. Keep replacing the outbound `x=93`
  column with that known reverse geometry for a separate route-polish task; no
  source/map blocker was changed here. A second known executor-sensitive edge
  at `(99,69)->UP` completed with one precise 20-frame raw input. All remaining
  Rimuldar segments completed normally. The final LEFT from World Map
  `(103,72)` entered Rimuldar map `0x0B` at `(29,14)` and emitted
  `event=handoff route=magic_temple waypoint=Rimuldar east doorstep index=2
  from_route=rimuldar`. Fresh tag `MAGIC_TEMPLE_RIMULDAR_HANDOFF_20260814`
  confirmed active route `magic_temple`, path nil, and no runtime blockers; no
  automatic second-leg movement occurred. Awaiting the player's manual exit
  through `(29,13)->RIGHT` to World Map `(102,72)` before validating the
  preserved Magic Temple leg.
- FULL CONNECTED LOADED ACCEPTANCE: after the player manually exited Rimuldar,
  fresh tag `MAGIC_TEMPLE_SOUTHBOUND_RESUME_20260814` confirmed World Map
  `(102,72)`, active `magic_temple` waypoint 2, path nil, and no NPC/runtime
  blockers. All 22 established temple waypoints then completed through the
  south ridge, long road, bridge, mountain pocket, and final approach. The
  historical `(110,86)->LEFT` and `(102,107)->LEFT` hotspots passed normally.
  Queued `(103,113)->RIGHT` exhausted retries but an unchanged-origin raw hold
  moved cleanly to `(104,113)`, proving timing-only behavior. The known
  `(104,113)->DOWN` step completed on its second bounded retry. No blocker was
  added. The final two UP steps emitted `event=arrived route=magic_temple` at
  World Map `(108,109)`. Fresh tag
  `MAGIC_TEMPLE_CONNECTED_ARRIVAL_20260814` confirmed route none, path nil,
  and zero NPC/runtime blockers. The connected source slice is ready for the
  user's manual acceptance; STAIRS entry to map `0x0E` remains optional and
  was already validated by the underlying route work.
- MANUAL-ACCEPTANCE BLOCKER PATCH READY: the user's end-to-end pass reproduced
  the same `(93,52)->DOWN` stop. A fresh baseline confirmed World Map
  `(93,52)`, active `rimuldar` waypoint 3, path nil, neutral game input, and
  zero NPC/runtime blockers. The live log now has three queued-route failures
  into `(93,53)`, while a centered same-origin probe at `(86,52)->DOWN` moved
  successfully and settled at `(86,54)`. The outbound `rimuldar` route now
  turns west through the already-validated reverse corridor: `(92,52)`,
  `(86,52)`, `(86,54)`, `(83,54)`, `(83,56)`, `(85,56)`, `(85,58)`, then
  `(88,58)`. A focused regression requires a LEFT step from `(93,52)` and the
  full route fixtures use the replacement chain. All `175/175` focused tests
  and the native Windows broad gate (33 Lua suites plus 68 Python tests) pass.
  After manual reload, tag `MAGIC_TEMPLE_DETOUR_RELOAD_20260814` confirmed a
  clean World Map baseline at `(86,54)`. Starting Magic Temple selected staged
  `rimuldar` waypoint 6 at `(83,54)`. The loaded route then completed every
  remaining replacement waypoint at `(83,54)`, `(83,56)`, `(85,56)`,
  `(85,58)`, and `(88,58)`, followed by the original 13-step continuation to
  `(88,71)`. There were no blocked, canceled, seam-retry, or runtime-block
  events. Fresh tag `MAGIC_TEMPLE_RIMULDAR_DETOUR_LOADED_20260814` confirmed
  World Map `(88,71)`, active `rimuldar` waypoint 12, path nil, neutral game
  input, and zero NPC/runtime blockers. The patch is loaded and ready for the
  user's manual continuation.
- FINAL MANUAL ACCEPTANCE: the connected itinerary completed at Magic Temple
  `(108,109)`. The Rimuldar leg had visible timing stalls at `(97,71)->UP` and
  `(107,71)->DOWN`; the temple leg had stalls at `(103,113)->RIGHT` and
  `(104,113)->DOWN`. In each case, the first route activation exhausted its
  internal retry budget, while the player's next activation completed the
  same segment. No other blocked or canceled route events occurred. Fresh tag
  `MAGIC_TEMPLE_MANUAL_ACCEPTED_20260814` confirmed route none, path nil,
  neutral game input, and zero NPC/runtime blockers. Do not promote these four
  recoverable timing events into map blocker data. The connected Magic Temple
  slice is ready to publish.
- LIVE ACCEPTANCE PLAN: after reload, establish a clean baseline at World Map
  `(104,49)`. Start Magic Temple and confirm `event=start route=rimuldar ...
  staged_from=magic_temple`. Traverse the existing Rimuldar waypoints in short
  checked batches. On entry to map `0x0B` `(29,14)`, require
  `event=handoff route=magic_temple ... from_route=rimuldar`, path nil, and no
  automatic movement. The player then exits Rimuldar to World Map `(102,72)`;
  fresh-probe the preserved handoff before following all 22 temple waypoints to
  `(108,109)`. Finally use STAIRS to reconfirm map `0x0E` `(0,4)` if desired.
- WATCH ITEMS / DO NOT PROMOTE FROM ONE FAILURE: the established outbound
  temple route has timing-only history at `(110,86)->LEFT`,
  `(102,107)->LEFT`, and `(104,113)->DOWN`; each previously passed a same-origin
  raw hold. The Rimuldar leg also has known bounded retries and harmless carry
  behavior. Treat isolated failures as executor timing until unchanged-origin
  evidence says otherwise. Do not add runtime or permanent blockers from a
  single route stall.
- NON-GOALS: do not polish legacy town-entry behavior in this slice. Entering
  Rimuldar and waiting for the player to exit is the same accepted handoff
  model used for Kol. Do not connect the return to Swamp Cave South, add an
  arbitrary-start route graph, or modify Magic Temple interior geometry.

## 2026-08-13 Connected Charlock Route

- CLEAN PRE-RELOAD BASELINE: fresh tag
  `CHARLOCK_CONNECTED_BASELINE_20260813` at frame `461460` confirmed World Map
  `(104,49)`, route none, path nil, and zero NPC/runtime blockers. The hero
  remains at the Swamp Cave South Entrance for the first loaded Charlock leg.
- TEST-FIRST SOURCE CHANGE: the former Charlock staging-stop regression was
  replaced with status and cave-handoff coverage. Both tests failed before the
  source change: status omitted the final Charlock destination, and entering
  Swamp Cave cleared the route. `charlock_castle` now independently opts into
  the existing staging continuation, matching Rainbow Bridge without changing
  the shared staging config. The handoff preserves Charlock Castle as the final
  destination, queues no movement, and leaves the first player-triggered step
  west from `(104,49)` to the safe doorstep `(103,49)`. All `170/170` focused
  route tests, LuaJIT compilation, `git diff --check`, all 33 host-runnable Lua
  suites, and 68 Python tests pass. Awaiting manual `main.lua` reload and loaded
  route verification.
- LOADED SECOND LEG COMPLETE: fresh reload tag
  `CHARLOCK_CONNECTED_RELOAD_20260813` confirmed World Map `(104,49)`, route
  none, path nil, and no runtime blockers. Starting Charlock first selected
  `swamp_cave_south` at its already-satisfied final waypoint, then immediately
  emitted `event=handoff route=charlock_castle ... from_route=swamp_cave_south`
  without moving the hero. The hero remained at `(104,49)` until an explicit
  `auto_walk`, which moved west to the safe doorstep `(103,49)`. Every existing
  Charlock waypoint then completed through the bridge, inlet detour, island
  south road, and castle approach. Both sustained-hold west edges at
  `(58,55)` and `(50,61)` passed on their first loaded attempts. The final
  entrance step needed one bounded timing retry, then changed to Charlock map
  `0x02` at `(10,19)` and logged `event=arrived`. Fresh tag
  `CHARLOCK_CONNECTED_ARRIVAL_20260813` confirmed route none, path nil, and
  zero NPC/runtime blockers. No blocker was added. Full connected acceptance
  from Rimuldar remains for the user-facing pass.
- FULL ROUTE FIRST LEG COMPLETE: fresh tag
  `CHARLOCK_FULL_RIMULDAR_BASELINE_20260813` confirmed World Map `(102,72)`,
  route none, path nil, and no NPC/runtime blockers before selection. Starting
  Charlock selected `swamp_cave_south` with `staged_from=charlock_castle` and
  retained Charlock as the Travel target. Every waypoint reached the south
  cave. The route saw two recoverable timing artifacts: auto-step initially
  exhausted its retry budget at `(99,69)->LEFT`, but an unchanged-origin raw
  `probe_edge:LEFT` moved through `(98,69)` and carried to `(97,69)`, proving
  the edge passable; the route then recovered. The known `(90,72)->UP` carry
  overshot to `(90,70)` and canceled one batch, then normal route recovery
  rejoined the corridor. No blocked-tile data was added. The final Up from
  `(104,50)` entered Swamp Cave map `0x15` at `(0,29)` and logged
  `event=handoff route=charlock_castle ... from_route=swamp_cave_south`.
  Fresh tag `CHARLOCK_FULL_SWAMP_ENTRY_20260813` confirmed the Charlock route
  remains active at waypoint 1, with path nil and no runtime blockers. Awaiting
  the player's manual STAIRS exit through the south entrance before validating
  the preserved second leg from World Map `(104,49)`.
- FULL CONNECTED ROUTE COMPLETE: after the player exited with STAIRS, fresh tag
  `CHARLOCK_FULL_SOUTH_EXIT_20260813` confirmed World Map `(104,49)`, active
  `charlock_castle` waypoint 1, path nil, and zero NPC/runtime blockers. The
  first explicit auto-walk moved west to the safe doorstep `(103,49)`, then
  every bridge, inlet, island, and castle-approach waypoint completed. A noisy
  timing stall at `(51,64)->RIGHT` began movement but did not settle before the
  retry budget; an unchanged-origin `probe_edge:RIGHT` moved through `(52,64)`
  and carried to `(53,64)`, proving the edge passable, and normal route recovery
  continued. The sustained-hold west edges `(58,55)->LEFT` and
  `(50,61)->LEFT` completed in 30 and 28 frames respectively with zero retries.
  The final Up from `(48,49)` entered Charlock map `0x02` at `(10,19)` and
  logged `event=arrived`. Fresh tag
  `CHARLOCK_FULL_CONNECTED_ARRIVAL_20260813` confirmed route none, path nil,
  and zero NPC/runtime blockers. The complete Rimuldar-to-Charlock connected
  itinerary is live-accepted; no blocker was added.
- MANUAL ACCEPTANCE COMPLETE: the user's full hotkey-driven pass started the
  staged itinerary at frame `1891`, preserved the cave handoff, completed every
  outbound waypoint, and entered Charlock at frame `21326`. Several segments
  used bounded cadence retries and several final-step carries advanced through
  already-valid route cells, but the log contains no `event=blocked` or
  `event=cancel`. Fresh tag `CHARLOCK_MANUAL_ACCEPTED_20260813` confirmed
  Charlock map `0x02` `(10,19)`, route none, path nil, and zero NPC/runtime
  blockers. This manual pass independently accepts the connected route.

## 2026-08-13 Connected Rainbow Bridge Route

- CLEAN PRE-RELOAD BASELINE: tag `RIMULDAR_RAINBOW_BASELINE_20260813` at
  frame `28380` confirmed World Map `(102,72)`, path nil, runtime blocks none,
  no active overworld route, and Rimuldar selected as the current Travel
  object.
- SOURCE / TESTS: `rainbow_bridge` now opts into the existing staged handoff
  through `swamp_cave_south`; the shared Charlock staging behavior remains a
  stop at the south cave. Regression coverage checks current/final status,
  handoff speech and logs, no automatic movement, the bounded 11-step first
  bridge segment, and the unchanged Charlock stop. All 166 focused route tests
  pass; the full gate passes all 33 host-runnable Lua suites plus 68 Python
  tests, changed Lua files byte-compile, and `git diff --check` is clean.
- CLEAN / LOADED START: tag `RAINBOW_CONNECTED_RELOAD_20260813` at frame
  `3420` confirmed World Map `(102,72)`, path nil, runtime blocks none, and no
  route active. Starting Rainbow Bridge logged `route=swamp_cave_south
  staged_from=rainbow_bridge`; speech named Swamp Cave South Entrance as the
  current leg and Rainbow Bridge unlock point as the final destination while
  leaving the hero stationary.
- TIMING / DO NOT PROMOTE AS BLOCKER: the first two segments reached
  `(107,72)`. Auto-walk then timed out moving UP, but a same-origin raw probe
  moved through `(107,71)` and carried to `(107,70)`. This disproves a static
  wall; no runtime or permanent blocker was added.
- REPRODUCED TURN DRIFT: diagonal segments toward `(105,68)` and `(101,67)`
  each completed their first UP tile, then the 16-frame turn settle carried one
  extra tile north before LEFT and cancelled safely as `route_drift_off_path`.
  Normal recalculation recovered the first drift and completed onward through
  `(102,68)`.
- SOURCE / TESTS AFTER LIVE FALLOUT: the return route now sustains the initial
  northbound early twitch and resets movement state at the five affected
  Rimuldar-exit turns. Charlock remains disconnected. All 167 focused route
  tests pass; changed Lua files byte-compile and `git diff --check` is clean.
- SECOND LOADED CHECK: tag `RAINBOW_CADENCE_RELOAD_20260813` at frame `5880`
  confirmed the clean `(102,72)` baseline. The first two segments reached
  `(107,72)`. Sustained hold then completed UP to `(107,71)`, proving the
  metadata loaded, but live carry reached `(107,70)` while the old route still
  expected its east detour and safely cancelled as off-path drift.
- SOURCE / TESTS FINAL DIRECT EXIT: the clean carry has now been observed by
  same-origin raw hold and by loaded route execution. `swamp_cave_south`
  removes only the obsolete `(108,71)->(108,70)` detour and expects direct
  north carry `(107,71)->(107,70)`. Later diagonal turns retain movement-reset
  metadata. All 168 focused route tests and the full 33-Lua-suite / 68-Python
  gate pass; syntax and `git diff --check` are clean.
- THIRD LOADED CHECK: the reloaded route began at exact World Map `(107,72)`.
  Its direct UP segment reached `(107,71)`, accepted the expected carry to
  `(107,70)`, and completed without cancellation. Both previously failing
  diagonal turns then completed cleanly at `(105,68)` and `(101,67)`; their
  loaded movement-state resets prevented the former northward drift.
- NORTH WALL SEAM LIVE-PROVEN: at `(98,70)`, route execution and a same-origin
  60-frame raw DOWN probe both failed to enter `(98,71)`. A raw LEFT probe
  passed through `(97,70)`, and a same-origin DOWN probe from `(97,70)` passed
  through `(97,71)` with normal carry to `(97,72)`. This proves the bypass must
  move west before south; no runtime blocker was added.
- LOADED END-TO-END COMPLETE: fresh tag `RAINBOW_BYPASS_RELOAD_20260813`
  confirmed World Map `(97,72)`, no route/path/runtime blockers, and the newly
  loaded source. From exact origin `(98,70)`, the route planned LEFT then DOWN
  and completed the corrected bypass at `(97,71)`. It then completed every
  remaining `swamp_cave_south` waypoint and entered Swamp Cave map `0x15` at
  `(0,29)`, logging `event=handoff route=rainbow_bridge ...
  from_route=swamp_cave_south` with no movement queued. STAIRS returned to
  World Map `(104,49)` while preserving the itinerary. The full bridge road
  and inlet detour completed to `(65,49)`, which logged `event=arrived`.
  Final tag `RAINBOW_CONNECTED_COMPLETE_20260813` confirmed path nil, runtime
  blocks none, and route none. Focused route tests pass `169/169`; the native
  Windows broad gate passes all 33 host-runnable Lua suites plus 68 Python
  tests. No runtime or permanent blocker was added. Running that gate from
  WSL is invalid for release tests because it gives Windows PowerShell Linux
  `/mnt/...` paths; use native `python run_tests.py` on this host.
- MANUAL ACCEPTANCE CADENCE FALLOUT: from `(99,68)`, two player-triggered
  auto-walk attempts exhausted the full retry budget moving DOWN into
  `(99,69)`. Both recorded `blocked_only`, but the user's ordinary sustained
  Down hold then crossed the same edge after about 31 frames and advanced the
  route. Fresh tag `RAINBOW_MANUAL_99_69_20260813` confirmed `(99,69)`, no
  path/runtime blockers, and the correct next waypoint west to `(98,69)`.
  This is passable cadence, not a blocker. `Rimuldar north approach bend` now
  uses the established 60-frame sustained-hold/early-twitch window.
- MANUAL FALLOUT LOADED / CLOSED: fresh reload tag
  `RAINBOW_99_68_RELOAD_20260813` confirmed the new source was polling. From
  exact `(99,68)`, Rainbow Bridge resumed `swamp_cave_south` at index `14`.
  Auto-walk completed DOWN to `(99,69)` in `33` frames with zero timeout
  retries and zero turn represses, recorded the seam as `passable_only`, and
  advanced to index `15`. Final state was `(99,69)`, path nil, with no NPC or
  runtime blockers; the next route waypoint remains west to `(98,69)`. The
  final focused route suite passes `169/169`, and the native broad gate passes
  all 33 host-runnable Lua suites plus 68 Python tests.
- MANUAL ROUND TRIP ACCEPTED: the continued run reached Rainbow Bridge
  `(65,49)` at frame `154166`, then completed `rainbow_bridge_return` into
  Swamp Cave at frame `156934` and exited to World Map `(104,49)`. Timing
  attempts at `(90,72)->UP` and `(67,50)->UP` failed once and then moved,
  making both noisy/passable rather than blocker evidence. Off-path carries to
  `(90,70)` and one tile past the bridge stand to `(64,49)` were recoverable
  and are deferred as non-destructive polish. No `PATH_RUNTIME_BLOCK` was
  inserted. Fresh tag `RAINBOW_MANUAL_COMPLETE_20260813` confirmed route none,
  path nil, and zero NPC/runtime blockers.

## 2026-08-13 Connected Swamp Cave Route

- CLEAN / LOADED: fresh tag `SWAMP_CONNECTED_BASELINE_20260813` confirmed
  World Map `(43,43)`, no active path, no runtime blockers, and the reloaded
  script. Starting `swamp cave` logged `route=kol staged_from=swamp_cave`;
  speech named `Current leg to Kol` and `Final destination: Swamp Cave` while
  the hero remained stationary.
- CLEAN / LOADED HANDOFF: reaching the Kol trigger produced
  `event=handoff route=swamp_cave waypoint=Kol forest west edge index=2
  from_route=kol`. Afterward the hero remained at `(104,10)`,
  `PATH_STATE target=nil`, with no runtime blockers. The handoff does not start
  movement automatically.
- CLEAN / LOADED OBJECT-FOCUS GUARD: with stale Tantegel Castle selection,
  bare `auto_walk` logged `follow_active=true` and started the active
  `swamp_cave` segment toward `Kol forest west edge`; it did not replace the
  destination with Tantegel.
- CONTAMINATED / DO NOT PROMOTE: coarse force-seeded movement at `(96,13)`
  timed out moving UP toward Kol, and force-seeded movement from the
  non-walkable Kol trigger `(104,10)` timed out moving LEFT. Both origins came
  from forced teleports and are unsuitable map or route-geometry evidence.
  No runtime or permanent blocker was added.
- SOURCE / TESTS: Swamp Cave staging now opts into connected handoff and names
  canonical `swamp_cave` as its continuation so far starts cannot retain the
  bridge-only variant. All 164 focused overworld-route tests and the full
  repository gate pass.
- CLEAN / COMPLETE SECOND LEG: after the user entered and exited Kol naturally,
  tag `SWAMP_CLEAN_KOL_EXIT_20260813` confirmed World Map `(104,10)`, path nil,
  and no runtime blockers. A fresh local Swamp Cave start then completed every
  established waypoint through `(104,43)` and entered map `0x15` at `(0,0)`.
  Arrival tag `SWAMP_CONNECTED_ARRIVAL_20260813` confirmed HP `149/149`, path
  nil, runtime blocks none, and no overworld route active.
- MANUAL ACCEPTANCE COMPLETE: the user completed the combined
  Tantegel-to-Swamp-Cave route. Fresh structured events show the staged Kol
  route start at frame `71501`, handoff to Swamp Cave at frame `84046`, and
  arrival at frame `89299`. Probe `SWAMP_MANUAL_ACCEPTANCE_20260813` at frame
  `92640` confirmed map `0x15` `(0,0)`, HP `149/149`, path nil, runtime blocks
  none, and no active overworld route. No further check remains for this slice.

## 2026-07-24 Hauksness Interior Decode

- BASELINE: fresh launcher probe confirmed Ruins of Hauksness map `0x03` at
  `(0,10)`, no active path, and no runtime blocks.
- ENTRANCE MODEL MISMATCH: live player entry is `(0,10)`, but
  `inspect_tile:0,10` reports tile 6, `reason=engine_boundary`, and
  `effective_passable=false`. Treat it as a likely map-specific entrance
  passthrough candidate; verify the west exit and inward edge separately before
  promoting it.
- OBJECTIVE TARGET: `inspect_tile:18,12` reports map dimensions `20x20`,
  tile 8, walkable/effective-passable true. The original 20-step static route
  crossed visually ruined walls; live blocker-hunt is now tracing the real
  route toward that coordinate.
- STALE NPC ROOT CAUSE: `report_path_state` exposed 20 Hauksness NPC blockers,
  including impossible out-of-bounds coordinates such as `(6,27)`, `(25,7)`,
  and `(26,21)`. The known fixed Axe Knight tile `(18,12)` was not among them.
  Hauksness uses town terrain offset `0x10`, causing generic town-NPC parsing to
  accept unrelated RAM even though map `0x03` has no NPCs. Do not park or write
  those phantom slots.
- NPC PATCH LIVE VERIFIED: `objects.lua` now suppresses ordinary NPC RAM on
  map `0x03`. The focused regression failed RED with `expected 0, got 2`, then
  all 100 object tests passed after the one-map guard. After manual reload, a
  fresh probe at `(0,10)` reported `npc_count=0` and no runtime blocks.
- FIRST LIVE CORRIDOR: normal autowalk reached `(4,12)` from the entrance
  before a Werewolf battle. After the field was cleared, route failure, seam
  retry, and same-origin raw probe each confirmed west-approach engine blockers
  at destination cells `(5,12)`, `(5,13)`, and `(5,11)`. All three are
  runtime-only directional blocks pending a focused permanent source/test
  batch.
- UPPER-RUIN BOUNDARY: after the Starwyvern clear, route failure, retry, and
  same-origin raw probe confirmed `(9,7)->DOWN` into `(9,8)`,
  `(7,7)->DOWN` into `(7,8)`, and `(6,7)->DOWN` into `(6,8)`. The opening
  `(5,7)->DOWN` into `(5,8)` is live-passable, but the opening cell is a
  one-cell recess: `(5,8)->DOWN` into `(5,9)` and `(5,8)->RIGHT` into
  `(6,8)` are also confirmed blocked.
- EAST UPPER RECESS: the upper corridor is live-passable east through
  `(16,6)` and south through `(16,7)` into `(16,8)`. From `(16,8)`, both
  RIGHT into `(17,8)` and LEFT into `(15,8)` are confirmed blocked, so this is
  another north-entry recess rather than a crossing.
- CURRENT RUNTIME MODEL: nine destination cells hold eleven verified blocked
  approaches: `(5,11).west`, `(5,12).west`, `(5,13).west`,
  `(9,8).north`, `(17,8).west`, `(15,8).east`, `(7,8).north`,
  `(6,8).north/west`, and `(5,9).north`. All remain runtime-only pending a
  focused permanent source/test batch.
- LOWER-RUIN BOUNDARY: after the Green Dragon clear at `(6,17)`, the planner
  traced the lower approach. Same-origin probes confirmed `(6,15)->UP`,
  `(16,14)->UP`, `(18,14)->UP`, `(17,14)->UP`, `(16,14)->LEFT`,
  `(15,15)->UP`, `(16,16)->RIGHT/DOWN`, `(18,15)->RIGHT`,
  `(19,16)->UP`, `(18,16)->LEFT/DOWN`. Shared destinations now carry multiple
  approaches at `(15,14)`, `(17,16)`, and `(19,15)`.
- OBJECTIVE REACHED / FIXED ENCOUNTER: the live route eventually reached
  `(17,12)`, west of objective tile `(18,12)`. Autowalk initially classified
  RIGHT as blocked, but the untouched same-origin raw probe moved onto
  `(18,12)` and triggered `An Axe Knight draws near!`. This is a scripted fixed
  encounter, not a permanent blocker and not an NPC RAM object; do not add
  `(18,12).west` to map data.
- ARMOR EVENT LIVE VERIFIED: the Axe Knight died to one critical hit. The hero
  remained at `(18,12)`, and manual `SEARCH` announced
  `Bill discovers the Erdrick's Armor.` Equipment byte `$00BE` changed
  `DB->DF`, decoding Magic Armor to Erdrick's Armor; defense changed
  `0x4D->0x51` (`77->81`), while quest flags remained `0x42`.
  The generic object list still reports no object on the tile. The approved
  follow-up is a persistent `Axe Knight Approach` landmark under All and
  Travel only that stops at `(17,12)` facing east; keep the buried armor and
  SEARCH action out of player-facing object data.
- VISUAL BEHAVIOR: local labeled and unlabeled map references show `(18,12)`
  as a lone green tree behind the eastern ruins, not a visible Axe Knight
  sprite. Live tile decoding remains town tile type `8` after the battle and
  search. The encounter and reward change battle/equipment state, not the
  terrain image.
- PRE-RELEASE WATCH ITEM: the user recalls similar phantom NPCs in Garin's
  Grave. Verify that map live before changing its NPC behavior; do not infer a
  second suppression rule solely from Hauksness.
- AXE KNIGHT LANDMARK LIVE VERIFIED: after a manual FCEUX script reload,
  `Axe Knight Approach` appeared under Travel without armor or SEARCH speech.
  Selected-object autowalk moved one cell west from `(18,12)` to `(17,12)`,
  released movement, and faced east. A Werewolf battle interrupted after the
  face release, but the route logged no east movement from `(17,12)`; after the
  user cleared it, a fresh probe confirmed map `0x03`, player `(17,12)`, no
  active path, and the selected landmark still present.
- EXIT LANDMARK LIVE VERIFIED: `Exit to World Map` is selected at `(0,10)`,
  stops on the exit cell, releases movement, and faces west. The route reached
  `(0,10)` from the Axe Knight area with no active path afterward, and
  `current_object` reported `Exit to World Map: here`. The map-specific
  passthrough for `(0,10)` is therefore required and working; neighboring
  boundary cells must not be opened merely because the exit landmark works.
- OBJECTIVE-TO-EXIT GEOMETRY / SOURCE PROMOTED: same-origin raw probes
  confirmed eleven directional blockers across nine destination cells:
  `(11,11).east`, `(11,12).east`, `(5,11).east`, `(5,12).east`,
  `(5,13).east`, `(6,10).south`, `(7,10).south`, `(5,14).south`, and
  `(6,14).north/east/south`. The three east approaches at x=5 complement the
  already verified west approaches on those cells; do not collapse these into
  unrelated whole-tile blockers without reviewing the directional model.
  With those approaches loaded, the final detour ran from `(6,15)` two cells
  south, four west to column 2, seven north to `(2,10)`, then two west to the
  exit. The eleven approaches are now permanent map `0x03` directional data
  with focused regression assertions; the two timing controls below and
  `(6,14).west` remain explicitly open. All 69 map-reader tests and the full
  Lua syntax/unit-test set pass. A manual FCEUX script reload and compact live
  objective-to-exit replay remain pending.
- RETURN TIMING CONTROLS: queued `(6,11)->RIGHT` and `(6,13)->RIGHT` each
  exhausted entry retries and temporarily looked blocked. Same-origin raw
  probes crossed both edges and carried to `(8,11)` and `(8,13)`
  respectively. These are executor timing failures, not map geometry; do not
  promote either rightward edge.
- EXIT TRANSITION CONFIRMED: after route completion at `(0,10)`, the latest
  manual trace first moved north to `(0,9)` and then west. The west step changed
  to World Map `0x01` at `(25,89)`, with no active route or world-map runtime
  blockers. Earlier live evidence separately confirmed west from `(0,10)`;
  the latest trace additionally suggests the western exit boundary spans more
  than one row. Keep `(0,10)` as the player-facing landmark unless route design
  requires a reason to expose the broader boundary.

## 2026-07-22 Hauksness Doorstep Movement-Reset A/B

- TREATMENT UNSAFE / REMOVED: from a normal-walk baseline at world-map
  `(15,89)`, the nine-step route reached `(24,89)` cleanly. The scoped reset
  then logged at frame `23374` with active movement state
  `before_move=0x07 before_sub=0x1A`.
- UNCOMMANDED SETTLE CARRY: no town-entry segment was queued. Fifteen frames
  after the reset, the game changed directly to Hauksness map `0x03` at
  `(0,10)` during final settle, followed by
  `route drift not on queued path ... source=route_settle_catchup`. This fails
  the A/B safety criterion; it is not a clean entry success.
- SAFETY CHECK: the post-event snapshot kept the level-16 stat block intact,
  no `PLAYER_STAT_FRAMEADVANCE_TRANSITION`,
  `PLAYER_STAT_INTEGRITY_TRANSITION`, or `PLAYER_STAT_INTEGRITY_WARNING`
  appeared, and runtime blocks remained empty.
- VERDICT: remove the `(24,89)` waypoint override and retain the global
  `auto_step_reset_movement_on_route_turn_settle=false`. Do not use movement
  RAM reset as the Hauksness entry fix, and do not promote a map blocker.

## 2026-07-17 Rimuldar Magic Key Return And Northwest Exit

- ROOT CAUSE / PROMOTED: the direct `(3,5)->LEFT` shortcut toward east entrance
  `(29,13)` is false geometry, not NPC interference. A natural-arrival probe
  stayed put with `npc_blocked=false`, so `(2,5).east` remains permanent.
- ACTUAL EXIT / LIVE PROOF: the earlier long LEFT probe conflated two moves.
  Reloaded selected Travel autowalk reached `(1,3)` facing west. The first
  normal LEFT reached in-town `(0,3)`; the second exited to World `(102,72)`.
  After normal reentry and another full route to `(4,5)`, LEFT again entered
  `(0,3)`, then UP moved along the boundary strip to `(0,1)` without exit.
- SOURCE / TESTS: `exit_0_3` now uses interaction stand `(0,3)`, facing west,
  and `map_reader.lua` leaves `(0,3).east` open. The selected-exit regression
  requires six steps: `LEFT, UP, UP, LEFT, LEFT, LEFT`. The planner can also
  reverse the x=0/top-bank route to east entrance `(29,13)` while explicitly
  avoiding the false `(3,5)->(2,5)` bridge. Focused totals pass: map 67,
  objects 99, pathfinder 21; the current full seven-check smoke gate passes
  with Git Bash pinned inside Python.
- LIVE VERIFIED 2026-07-20: after reload, entry `(29,14)` to key stand `(4,5)`
  completed in 52 steps. Selected `exit_0_3` then completed its six-step route
  at `(0,3)` facing west without leaving town. After returning six steps to
  `(4,5)`, the east-exit route completed 51 steps at `(29,13)` facing east.
  All temporary timing edges cleared; final `PATH_STATE target=nil` and
  `RUNTIME_BLOCKS map=0x0B none`.
- CHECKPOINT: player is Rimuldar `(29,13)` at the east exit stand. No further
  reload or route correction is pending for this issue.

## 2026-07-17 Rimuldar Wings Return And Weapons Merchant Public Route

- WINGS RETURN / PROMOTED: the opened-door return from the Wings chest pocket
  reached every candidate origin by ordinary movement. Route failures followed
  by same-origin raw probes confirmed the directional-only blocker batch now
  covered by `wings_round_trip_blocks` plus the focused door/row-17/row-18
  assertions in `test_map_reader.lua`. Natural arrivals supersede older
  forced-origin open readings at `(22,24).north`, `(23,24).north`,
  `(24,24).north`, `(25,22).west`, and `(25,23).west`.
- WEAPON ROOT CAUSE: the earlier `(24,7)` weapon-shop prompt was reached only
  by selected teleport into the enclosed upper room. Forensic passthrough cells
  `(22,4)` and `(24,6)` do not form a normal public connector. The valid public
  stand is `(23,9)`, facing north toward Merchant 2 at `(23,7)`, reached by the
  lower west corridor.
- WEAPON BOUNDARY / PROMOTED: normal-arrival route failures and same-origin raw
  probes confirmed 13 approaches: `(21,8).south`, `(22,8).south`,
  `(24,8).south`, `(25,8).east`, `(25,9).east/west`,
  `(21,10).east/north`, `(25,10).east/west`, `(21,11).east`,
  `(22,12).north`, and `(23,12).north`. No route fallback to `(24,7)` remains.
- SOURCE-ONLY RELOAD PROOF: `launcher_probe:rimuldar_weapon_source_reload` was
  consumed at frame `07620`; hero was `(23,9)` and
  `RUNTIME_BLOCKS map=0x0B none`. Coordinate autowalk completed the 21-step
  return to `(29,14)` as `5 west, 5 south, 11 east`. Normal `next_filter`
  selected `Weapons Merchant (stationary)` with `interact 23,9`; `pathfind`
  logged `11 west, 5 north, 5 east`, length 21.
- ROAMING NPC CAVEAT: two selected-object attempts correctly returned
  `No path found` while `Guard 2` occupied `(19,9)`. The diagnostic reported
  `runtime_blocks=0`, `target_walkable=true`, and
  `reason=stationary_npc_blocker`. A same-poll `pathfind auto_walk` retry after
  he moved completed all 21 steps at frame `16192`, faced north, and held the
  merchant without adding a blocker.
- TALK PROOF: A opened the command menu; the second A produced
  `We deal in weapons and armor. Dost thou wish to buy anything today?` and
  `VISITED_AUTO ... target_name=Weapons Merchant`. B cancelled the prompt.
  Final frame `20580`: hero `(23,9)`, menu/dialogue closed, Weapons Merchant
  selected and visited, `RUNTIME_BLOCKS map=0x0B none`.
- VERIFICATION: focused suites pass (`test_map_reader.lua` 67/67,
  `test_objects.lua` 99/99, `test_pathfinder.lua` 20/20,
  `test_route_manager.lua` 110/110, `test_object_commands.lua` 3/3), LuaJIT
  byte-compilation passes, `git diff --check` is clean, and the full
  `run_tests.py --allow-missing-speech-dep` gate passes through explicit Git
  Bash.

## 2026-07-17 Rimuldar Safe NPC Parking Guard

- CLEAN / PROMOTED: with `auto_walk_park_mobile_npcs=true`, proactive parking
  is skipped on map `0x0B` because `(0,0)` is pathfinder-walkable. The
  exact live log is
  `AUTO_WALK_NPC_PARK_SKIP map=0x0B reason=walkable_origin origin=(0,0)`;
  planning remains `npc_mode=live_npcs` and no NPC coordinate parking writes
  occur.
- VERIFIED RUN 1: after the user entered Rimuldar normally at `(29,14)`, the
  52-step route crossed `(1,0)->(0,0)` at frame `9547`, continued south to
  `(0,1)` at frame `9595`, and reached `(4,5)` at frame `9951`.
- VERIFIED RUN 2: after a same-map reset to `(29,14)`, the repeat crossed
  `(1,0)->(0,0)` at frame `31679`, continued south to `(0,1)` at frame
  `31727`, and reached `(4,5)` at frame `32336`. Final snapshot:
  `PATH_STATE target=nil`, `RUNTIME_BLOCKS map=0x0B none`.
- RESOLVED: the earlier isolated stop-at-`(0,0)` exit did not reproduce when
  the real route retained its next south step. Do not change `auto_step.lua`
  for that isolated artifact.
- RESOLVED / PROMOTED: the return planner's direct `(3,5)->LEFT` attempt really
  is blocked. A natural-arrival probe timed out with no NPC on the seam, so
  source closes `(2,5).east`. The corrected route instead enters `(0,3)` from
  the east, then either exits with another LEFT or continues north along x=0
  to reverse the original entrance route.
- VERIFIED: the full `run_tests.py --allow-missing-speech-dep` gate passed
  all seven top-level checks when Git Bash was injected inside the Python
  process; `git diff --check` was clean before this documentation update.

## 2026-07-15 Rimuldar Magic Key Route Reopen

- CLEAN BASELINE: current FCEUX script consumed
  `launcher_probe:rimuldar_baseline`; hero is Rimuldar `0x0B` at `(1,8)`,
  six keys, all opened-door RAM slots `(0,0)`, `PATH_STATE target=nil`, and
  `RUNTIME_BLOCKS map=0x0B none`.
- NORMAL ROUTE FAILURE: immediately before that baseline, the source-planned
  Magic Key Merchant route walked normally from `(29,14)` to `(1,8)`. The
  queued RIGHT step and seam retry both failed into `(2,8).west`; the log
  recorded `AUTO_WALK_BLOCKER_FOUND`, `npc_blocked=false`, and
  `timing_suspect=false`.
- INPUT NOTE: idle FCEUX reports `LeftAlt`, but bridge input is neutral and
  game-side buttons are `0x00`; per the current FCEUX rules this latch is
  benign unless movement evidence shows other contamination.
- RESOLVED ROUTE: `(1,8)->RIGHT` was the wrong access point. From the normal
  east entry `(29,14)`, walk north along `x=29` to `(29,2)`, west along row 2
  to `(21,2)`, north to `(21,0)`, west along `y=0` to `(0,0)`, south along
  `x=0` to `(0,3)`, then east across the real bridge `(1,3)->(2,3)`. At the
  northwest corner, enter `(0,0)` from `(1,0)` and turn
  DOWN; entering `x=0` horizontally below `y=0` changes to the World Map.
- TOP-ROW GUARD: a normal-movement design self-review crossed `y=0` east to
  `(26,0)`, then `(26,0)->RIGHT` blocked with `npc_blocked=true` because fixed
  `Person 4` occupies `(27,0)`. Do not route directly from `(29,0)` across the
  full top row; the row-2 / x=21 jog above is required with live NPCs.
- SHOP APPROACH: fixed `Merchant 1` occupies `(2,4)`, so bypass him via
  `(2,3)->(3,3)->(4,3)->(5,3)->(5,4)->(5,5)->(4,5)`.
- LIVE SERVICE PROOF: `(4,5)->DOWN` correctly blocks because `(4,6)` is the
  counter, not a player stand. TALK from `(4,5)` facing south opened:
  `Magic keys! They will unlock any door. Dost thou wish to purchase one for
  53 GOLD?` The prompt was cancelled with B. After the route audit, final live
  state is Rimuldar entry `(29,14)`, menu/dialogue closed, six keys, and
  `RUNTIME_BLOCKS map=0x0B none`.
- SOURCE GAPS: `objects.lua` still targets stale stand `(4,6)`; the local map
  decoder still treats packed nibbles as RLE; and blanket `engine_boundary`
  handling rejects the valid `y=0` / `x=0` outer-bank route. Preserve the live
  evidence above before changing source, and add red/green route regressions
  before implementing those fixes.

## 2026-07-15 Cantlin Final Checkpoint

- MANUAL ROUTES: Town Entrance to Magic Key Merchant and return both passed
  with eastern door `(26,9)` open. With doors closed, `No path found` is the
  expected and user-confirmed result.
- GOLEM / SAVE: Golem defeated. Fresh live state is Cantlin `(15,0)`,
  `quest=0x42`, six keys, all door RAM slots `(0,0)`, and no runtime blockers.
  The user created a new save state with doors closed.

## 2026-07-14 Cantlin NPC Status And Magic Key Merchant

- NAVIGATOR: NPC descriptions now append live `stationary`, `roaming`, or
  `movement unknown` status. Reload validation reported
  `Magic Key Merchant (stationary)` and tracked roaming slot 4 independently.
- LIVE TALK PROOF: fixed `npc_11` / Old Man 2 occupies `(27,6)`. TALK opened
  the 98 G Magic Key shop from public stand `(27,8)`, facing north across
  blocked counter cell `(27,7)`. `(27,4)` facing south and `(25,6)` facing
  east both returned `There is no one there`.
- SOURCE-ONLY ROUTES: stand-to-Town-Entrance completed in 20 steps at `(16,0)`.
  Selected-service autowalk returned in 21 steps to `(27,8)`, faced north, and
  left `RUNTIME_BLOCKS map=0x0A none`.
- CLOSED-DOOR CLEANUP: after town reentry, the key-shop route repeatedly tried
  false openings `(27,5).north`, `(27,1).south`, and `(28,2).west`. Each route
  failure was confirmed by a same-origin raw probe with no NPC contamination,
  then promoted to permanent Cantlin directional data.
- LIVE REROUTE: with runtime mirrors for those three edges, the return from
  `(27,2)` detoured west through `(24,2)`, climbed at `(24,1)`, and completed
  cleanly at Town Entrance `(16,0)`.
- EXPECTED LOCK: the Magic Key shop route crosses door `(26,9)` and therefore
  correctly has no path while that door is relocked. Open it from `(25,9)`,
  facing east, before routing to stand `(27,8)`.
- SOURCE-ONLY VERIFIED: after `clear_runtime_blocks`, all three approaches
  remained blocked by permanent data and the runtime overlay reported none.
  Closed-door `debug_pathfind_to:27,8` now returns a clean `No path found`.
- VERIFIED: 99 object, 61 map-reader, and 104 route-manager tests pass. Current
  hero is `(16,0)` with doors closed, six keys, and no runtime blockers.

## 2026-07-13 Cantlin Tool Merchant 2

- LIVE SHOP PROOF: fixed `npc_12` / Person 2 at `(2,7)` opened Buy/Sell from
  `(4,7)` facing west. Offers are Herb 24 G and Torch 8 G.
- SERVICE PATCH: source labels `npc_12` as `Tool Merchant 2`, service=true,
  with counter stand `(4,7)` facing west. Live module reload reports that label.
- CLEAN / PROMOTED: `(3,7).east` blocked during the stand route and again under
  same-origin `probe_edge:LEFT` from `(4,7)`; no NPC or model block caused it.
- CLEAN / PROMOTED: `(3,8).south` blocked during the first stand route and
  again under same-origin `probe_edge:UP` from normally reached `(3,9)`.
- ROUTES: after reload and clearing all runtime blocks, source-only routes
  completed `(3,9)->(4,7)`, Tool Merchant 2 `(4,7)->` Town Entrance `(16,0)`,
  and `(16,0)->(4,7)` with no new blockers.
- VERIFIED: 61 map-reader tests and 98 object tests pass. Current hero `(4,7)`,
  facing west, menu/dialogue closed, RUNTIME_BLOCKS none.

## 2026-07-13 Cantlin Command-Result Dialogue Fragments

- LIVE TRACE: failed SEARCH stabilized as `Bill searched the ground all about.
  99 LBut there found nothing.`; after menu clear, `MP 63ll` also spoke.
- ROOT CAUSES: the transient scan omitted the full `E13994` row, leaving `99`
  outside the derived numeric candidates; a lone status `L` fused to `But`;
  and `ll` was the current hero-name tail fused after the MP value.
- SOURCE FIX: unmatched bare numbers are removed only after a completed
  sentence under strong status context; single fused status letters are
  removed only before a second capital; status-value/name-tail residue accepts
  any one- or two-letter lowercase tail, independent of hero name.
- GUARDS: `52 GOLD`, reward/stat numbers, and `Lancelot arrived.` remain
  unchanged. Trace output now waits for terminal punctuation.
- STATIC VERIFIED: 70 text tests, 7 field-action-guard tests, LuaJIT bytecode
  checks for `text.lua`, `main.lua`, and `test_text.lua`, and
  `git diff --check` pass. Full Lua reload and live SEARCH/menu-clear retest are
  still required.

## 2026-07-12 Cantlin Premium Shop And Inventory

- BASIC INVENTORY VERIFIED: roaming slot 4 speaks Bamboo Pole 10, Club 60,
  Copper Sword 180, Leather Armor 70, Chain Mail 300, Large Shield 800.
- UPGRADE INVENTORY VERIFIED: fixed slot 19 speaks Hand Axe 560, Broad Sword
  1500, Full Plate 3000, Magic Armor 7700.
- PREMIUM SHOP LIVE PROOF: TALK from `(24,13)` facing north toward fixed
  Guard 4 `(24,12)` opened the shop. It offers Flame Sword 9800 and Silver
  Shield 14800. Six stands around `x=25..27, y=11/13` were negative.
- PREMIUM SERVICE PATCH: `objects.lua` labels `(24,12)` as `Premium Weapons
  Merchant`, service=true, stand `(24,13)`, facing north.
- CURSOR FIX: the split `Silver` row decoded as `Silver Harp`; the 14800-G
  shop price now disambiguates it as `Silver Shield` in `merchant.lua`.
- LORE NPC: moving Merchant 3 near `(4,25)` only gives the grandfather Wynn /
  east Hauksness dialogue and remains outside Services.
- FAIRY WATER LIVE PROOF: from `(20,13)` facing east toward Woman 2 `(22,13)`,
  TALK opened the 38-GOLD prompt. Source now labels her `Fairy Water Merchant`
  and routes to `(20,13)` facing east.
- DIALOGUE NOISE: the user live-validated all command-menu options after the
  multi-token post-shop residue fix. The lore sentence then arrived as
  `Wynn M ... G Hauksness`; source now strips repeated isolated status
  letters from assembled dialogue while preserving one legitimate initial.
- TESTS: `luajit test_text.lua` 62, `luajit test_merchant.lua` 19, and
  `luajit test_objects.lua` 96 passed; `git diff --check` clean.
- CURRENT: hero stand `(24,13)`, premium shop menu recently active, all five
  doors open, one key. Reload full Lua, then validate Services lists six
  entries, the second premium choice speaks `Silver Shield. 14800 gold`, and
  the Wynn/Hauksness lore line is clean.

## 2026-07-12 Cantlin Roaming Weapons Merchant

- CLARIFIED: fixed Weapons Merchant slot 19 is stationary at `(27,26)`, uses
  stand `(25,26)`, and was already user-validated both ways. Nearby mobile
  slot 4 is now labeled `Roaming Weapons Merchant`.
- SEALED STATE: slot 4 remained on x=22, rows 3 through 6. Normal and skip-NPC
  adjacent planners returned `No path found`; route-frontier analysis found 34
  already modeled boundary candidates and `hidden_bridge_candidates=0`.
- NO COUNTER: four two-away TALK checks all returned `There is no one there`:
  north `(22,1)->(22,3)`, south `(22,8)->(22,6)`, west
  `(20,5)->(22,5)`, and east `(24,4)->(22,4)`.
- DECISION: keep adjacent-NPC routing for slot 4 when it enters the reachable
  component; do not patch geometry or assign a static stand.
- VERIFIED LIVE: after `reload_navigation_modules`, Services announced
  `Roaming Weapons Merchant ... Not currently reachable`. NPC freeze is off;
  hero remains at `(22,1)`.

## 2026-07-11 Cantlin Tool Merchant And Inn Validation

- USER VALIDATED: Tool Merchant route and Inn forward route/interactions.
- CLEAN / PROMOTED: Inn return stopped at normal origin `(16,2)->UP` into
  `(16,1).south`; direct raw probe blocked, then the 3/3 verifier returned
  `moved=0 blocked=3` with no NPC, drift, map change, interruption, or
  teleport-artifact flag. `(16,1)` is now fully blocked in source/tests.
- ROUTE: with `(16,1).south` mirrored at runtime, Town Entrance return planned
  `1 east, 2 north, 1 west` through x=17 and completed at `(16,0)`.
- CURRENT: Cantlin `(16,0)`, all five doors open, runtime block count 1. Reload
  Lua before clearing the overlay and starting the next service route.

## 2026-07-11 Cantlin North Lane And Initial-Settle Carry

- CLEAN / PROMOTED: normal movement crossed `(1,0)..(29,0)`;
  `(1,0)->LEFT` blocked and east beyond `(29,0)` changed to the World Map.
- OBJECTS: Travel has Town Entrance `(16,0)`, north exit `(23,0)` via safe
  stand `(23,1)`, northeast exit `(29,0)` via `(28,0)`, and southeast exit
  `(20,29)`.
- TOOL FIX: `sweep_walk` now continues after boundary edges from trusted
  modeled origins while preserving false-wall instability checks; 51 tests pass.
- CLEAN / PASSABLE: `(4,0)` and `(5,0)` descend; later normal probes moved at
  `x=17..25`. Prior evidence keeps `x=14` open.
- CLEAN / PROMOTED: normal-origin probes and 3/3 raw verifiers blocked DOWN at
  `x=1..3` and `x=7..13`. Source models destination approaches
  `(1..3,1).north` and `(7..13,1).north`.
- CLEAN / PROMOTED: after source reload and normal walking to `(6,0)`, DOWN
  blocked directly and 3/3 with no drift, NPC, map change, interruption, or
  teleport-artifact flag. Source/runtime now model `(6,1).north`; the lone
  earlier move is treated as contaminated.
- CLEAN / PROMOTED: route failure plus same-origin 3/3 raw verification added
  `(3,1).east` for `(4,1)->LEFT`, with no NPC or state contamination.
- LIVE FIX: the exact `(4,1)->UP`, seam retry, `initial_settle=16`, then west
  route stayed in Cantlin and completed at `(1,0)` after reload.
- CONTAMINATED / DISPROVED: teleport-seeded `(17,0)->RIGHT` failed. Normal
  reacquisition through `(16,0)->(17,0)` then moved RIGHT and carried to
  `(19,0)`, so no horizontal blocker was added.
- EXIT / MODELED: the route from `(23,1)` walked UP to `(23,0)`, then changed
  to World Map `(73,102)` during the follow-up settle before its east step.
  Travel exposes `North Exit to World Map` via safe stand `(23,1)` facing
  north, and `(23,0).south` guards ordinary routes. Tests pass: 94 objects,
  60 map-reader.
- CLEAN / PROMOTED: normal-origin DOWN probes at `x=26..28` each blocked, then
  same-origin 3/3 verifiers returned `moved=0 blocked=3` with no drift, NPC,
  map change, interruption, or teleport-artifact flag. Source and runtime
  mirrors now model `(26..28,1).north`.
- ROUTE: with all three runtime mirrors active, `auto_walk_blocker:16,0`
  completed 12 west from `(28,0)` through the guarded north lane without an
  exit transition.
- SOURCE-ONLY VALIDATION: with no runtime blocks, `(16,0)->(25,2)` completed
  `9 east, 2 south` through open x=25 and avoided the x=26..28 blocked band.
- CLEAN / PASSABLE: normally reached `(18,0)->DOWN` moved to `(18,1)`.
- ROUTE: with only `(6,1).north` mirrored at runtime, `(6,0)->(5,2)` chose
  `1 west, 2 south` through open x=5 and completed.
- CURRENT: Cantlin `(5,2)`, all five doors open, runtime block count 1 for
  `(6,1).north`. Reload Lua before clearing the overlay and beginning the next
  interior route pass.


## 2026-07-10 Cantlin Essential-Service Route Cleanup

- Travel-exit correction: `objects.lua` had Cantlin's only Travel object pinned
  to old placeholder `(14,29)`, behind the lower striped damage barrier. Live
  movement had already proved `(20,29)` immediately transitions to the World
  Map. The object now targets `(20,29)` via safe stand `(20,28)` facing south;
  `exit_14_29` is removed and `exit_20_29` is covered by an object regression.
- The corrected selected-object route from `(24,27)` exposed four clean
  approaches on three cells: `(23,27).east/west`, `(24,28).north`, and
  `(22,28).north`. Each same-origin verifier blocked 3/3 without contamination.
  With those source/runtime mirrors active, Travel autowalk completed at
  `(20,28)`, faced south, and remained stable across immediate and four-second
  checks. Current live state is `(20,28)`, all five doors open, and three
  runtime cells mirror the newest source-only edges.
- The user-observed return blocker after the first Weapons Merchant was from
  fixed slot 19 at `(27,26)`, not roaming slot 4. Return autowalk stopped at
  `(23,26)->DOWN`; logs reported `npc_blocked=false`, and same-origin
  verification confirmed `(23,27).north` blocked 3/3 without contamination.
  After source/test promotion and live injection, the replanned route reached
  exit stand `(20,28)` and faced south. The first `(23,26)->LEFT` attempt
  needed one successful seam timing retry, which cleared itself and is not map
  evidence.

- Baseline: all five doors open, hero at the practical entrance `(15,1)`,
  menu/dialogue closed, and no pre-existing runtime blocks.
- The return from `(22,27)` toward `(15,1)` stopped on
  `(22,27)->LEFT` into `(21,27)`. Same-origin
  `probe_edge_verify:LEFT,3` returned `moved=0 blocked=3`, with no NPC,
  timeout, drift, map change, interruption, or teleport artifact. Source and
  focused tests now model `(21,27).east`; its live runtime mirror is active.
  The retried 33-step return then completed to `(15,1)`.
- Inn public stand `(8,5)`: the 19-step entrance route and reverse route both
  completed in blocker mode with no additional blocker.
- Tool Merchant public stand `(5,12)`: the 21-step entrance route and reverse
  route both completed in blocker mode with no additional blocker.
- Fixed Weapons Merchant public stand `(25,26)`: the 35-step entrance route
  and reverse route both completed in blocker mode with no additional blocker.
- Mobile Weapons Merchant 2 is state-dependent. In this save it remained in
  the sealed upper-east compartment, most recently slot 4 at `(22,6)` with
  `move=0x0A`. Normal and skip-NPC planners both correctly returned `No path
  found`; frontier analysis reported `hidden_bridge_candidates=0`. Do not
  remove any of the 34 already modeled compartment boundaries. Prior same-day
  live evidence remains valid: when Merchant 2 wandered to reachable `(17,4)`,
  object-selected blocker mode reached `(17,3)`, faced south, and held the
  target; separate routes between reachable stands and `(15,1)` were clean.
- Follow-up after the user's bouncing route: the active object was the south
  `Exit to World Map` at `(14,29)`, not practical entrance `(15,1)`. Its
  reroutes and the subsequent coordinate route to `(15,1)` exposed seven clean
  approaches: `(19,28).east`, `(19,25).north`, `(17,24).east/north`,
  `(17,21).east/south`, and `(18,20).south`. Every approach blocked 3/3 under
  a same-origin verifier with no timeout, drift, map change, interruption, or
  teleport artifact, and each is now in source/tests plus the live overlay.
- One seam-retry follow-up reported arrival at `(17,23)` before the hero later
  appeared at `(16,23)`. A controlled normal one-step route back to `(17,23)`
  remained stable across immediate and four-second samples. Keep the seam-
  retry post-completion carry as a timing watch item; it did not reproduce on
  the final entrance route.
- End state: after all seven approaches were mirrored live, blocker mode
  completed to `(15,1)` and stayed there across immediate and four-second
  checks. All five doors remain open; the runtime overlay contains five cells
  mirroring the newest source entries.

## 2026-07-04 Cantlin Town First Survey

- Baseline: fresh command polling verified with
  `launcher_probe:codex_cantlin_survey`; `report_position` confirmed
  Cantlin `map=0x0A` at `(20,24)`, `DOOR_STATE keys=6`, and
  `RUNTIME_BLOCKS map=0x0A none`.
- Parked-NPC survey preflight from `(20,24)` was viable:
  `targets=20`, `reachable_area=128`, `reachable_targets=20`,
  `unreachable_targets=0`, and `open_exits=north|south|west|east`.
- `survey_objects:park_npcs` run 1 started at `(20,24)` with 20 targets.
  It completed `Merchant 1` at `(21,25)` and `Guard 2` at `(20,21)`, then
  stalled on `Old Man 4` at `(22,22)`. The run was manually stopped after
  target 3; summary: `targets=3 successes=2 failures=1`, with Old Man 4
  classified as `suspected_engine_blocked_tile`.
- Old Man 4 failure details: survey ended at `(25,23)` and reported suspected
  cells around `21,22|21,21|22,21|23,21|24,22|25,22|26,22|23,23|24,24|25,24|26,23|24,23`.
  `SURVEY_STRONG_CANDIDATES map=0x0A none`, so do not promote a broad block
  batch from this run.
- Read-only follow-up from `(25,23)` showed `debug_pathfind_adjacent:22,22`
  expects a simple stand route to `(22,23)` via `3 west`, and tile inspection
  says `(24,23)`, `(25,23)`, `(25,22)`, `(21,22)`, and `(20,22)` are statically
  walkable. The failed route is therefore a live engine/state issue, not an
  obvious static wall.
- Contamination/recovery boundary: after the first direct `auto_walk_blocker`
  and same-origin `probe_edge:LEFT`, `report_movement_state` still showed a
  stuck left/movement state. `recover_fceux_input.sh` cleared the FCEUX
  `LeftAlt` latch (`INPUT_STATUS tag=fceux_recovery keys=- joy1=- bridge=-
  left_alt=false`), then `reset_movement_state` zeroed the movement/subpixel
  bytes. Treat evidence before this cleanup as noisy unless rechecked after the
  reset.
- Clean same-origin probes after input/movement cleanup from `(25,23)`:
  `(25,23)->LEFT`, `(25,23)->DOWN`, `(25,23)->UP`, and `(25,23)->RIGHT` all
  timed out with `EDGE_PROBE_MODEL_MISMATCH ... kind=blocked_despite_open_preview`.
  Runtime blocks for LEFT and DOWN were injected only long enough to retest the
  route and were cleared afterward (`RUNTIME_BLOCKS map=0x0A none`).
- Current live state after cleanup: hero remains at Cantlin `(25,23)`, no
  runtime blocks. Because all four exits from `(25,23)` blocked cleanly, this
  looks like a standable but boxed engine pocket reached during the survey.
  Do not promote it directly to `map_reader.lua` until either the entry edge is
  reconstructed from clean walking or the pocket is deliberately modeled as an
  isolated/non-routeable tile.
- Hard-lock follow-up: the user's controller lock was not a Lua crash or total
  emulator hang. `qfceux` was OS-responsive, `launcher_probe` and later
  `trace_input:180` were consumed, and `dw_keyboard_input.txt` was neutral.
  Windows did not report Alt or any direction physically held, but FCEUX/Lua
  continued to see stable `keys=LeftAlt joy1=- bridge=-`; the game input byte
  remained `buttons=0x20`. Treat all movement evidence from this live state as
  contaminated until recovery/relaunch plus a fresh baseline clears or explains
  that stale game-side button byte.
- Recovery attempts: `recover_fceux_input.sh` foregrounded FCEUX, reset the
  bridge, and briefly cleared the stale Alt report
  (`INPUT_STATUS tag=fceux_recovery keys=- joy1=- bridge=- left_alt=false`).
  It did not clear the game-side `buttons=0x20`, and FCEUX later relatched
  `LeftAlt`. `clear_input` and a raw `START`/`B` pulse did not open the menu or
  clear `buttons=0x20`; the raw `START` did reach Lua as `joy1=start`. No
  scripted relaunch was attempted because `SDL.AutoResume = 0` and there was no
  obvious current Cantlin quickslot, so relaunching from Codex risked landing
  in unrelated state.
- Source guardrail added after restart: direct `probe_edge`,
  `probe_edge_verify`, and seeded edge probes now check for the contamination
  signature before starting. If Lua joy and the bridge are idle while
  `$0047`/`BUTTONS_PRESSED` remains nonzero, the command refuses and logs
  `EDGE_PROBE_ABORT reason=input_contaminated ...` instead of producing new
  movement evidence. This needs a Lua reload before it affects the live
  emulator session.
- Reload replay / DO NOT PROMOTE: after user reloaded Lua, focused unit tests
  passed (`luac -p`, `lua test_debug_tools.lua`, and `git diff --check`), and
  `launcher_probe:codex_guard_reload` confirmed command polling. Fresh baseline
  was Cantlin `map=0x0A` at `(20,22)`, `keys=6`, no runtime blocks, stale
  FCEUX `LeftAlt` only, and `buttons=0x00`.
- The repeat `report_survey_start:park_npcs` was viable from `(20,22)` with
  `targets=21`, `reachable_area=128`, `reachable_targets=21`, and
  `open_exits=north|south|west|east`. The follow-up
  `survey_objects:park_npcs` immediately looped on `Old Man 4` at `(22,22)`
  with route-timeout reroutes from `(20,22)`.
- Contaminated replay details: survey logs showed repeated
  `movement_started=true` twitch timeouts for LEFT, RIGHT, UP, and DOWN from
  `(20,22)`, with temporary suspected cells `(19,22)`, `(21,22)`, `(20,21)`,
  and `(20,23)`. Manual `stop_survey` produced `SURVEY_COMPLETE targets=1
  successes=0 failures=1 suspected_engine_blocked=1`; treat this whole replay
  as movement-state evidence, not Cantlin geometry.
- Read-only `inspect_move:20,22,UP/DOWN/LEFT/RIGHT` says all four adjacent
  destinations are `effective_passable=true`. `recover_fceux_input.sh` cleared
  the stale Alt latch (`keys=- joy1=- bridge=- left_alt=false`), but a small
  post-recovery `simulate_input:RIGHT` still only twitched and left the hero at
  `(20,22)`. Current recommendation: do not continue Cantlin surveys from this
  emulator state; re-establish a known-clean walked position or restart/load a
  clean state before collecting map evidence.
- Manual recovery replay: after the user verified the emulator manually and
  reloaded Lua, `launcher_probe:codex_cantlin_reverify` confirmed the command
  loop. Baseline was Cantlin `(18,24)`, `keys=6`, no runtime blocks, stale
  LeftAlt only, and `buttons=0x00`. `auto_walk_blocker:19,24` proved queued
  route movement was viable by moving east to `(19,24)` via seam retry.
- The next `survey_objects:park_npcs` again drove toward `Old Man 4`, walked
  around the target area, then returned to the suspect `(25,23)` pocket. At
  `codex_survey_timeout_state`, Lua/bridge input were idle but
  `buttons=0x20` was stuck again. `stop_survey` completed with
  `targets=1 successes=0 failures=1 suspected_engine_blocked=1`.
- Live guard proof: in the reproduced contaminated state, `probe_edge:LEFT`
  refused with
  `EDGE_PROBE_ABORT reason=input_contaminated command=probe_edge keys=LeftAlt joy=- bridge=- buttons=0x20`.
  `recover_fceux_input.sh` did not clear the game-side byte; the post-recovery
  state remained Cantlin `(25,23)` with `buttons=0x20`. Do not continue surveys
  or edge probing from this state without a fresh manual recovery/reload.
- Source guardrail follow-up: the shared contamination detector now also stops
  survey and auto-walk work. `survey_objects` refuses contaminated startup,
  aborts active runs from tick/route events without recording candidates, and
  clears route context; auto-walk refuses before planning and aborts in-flight
  route blocks before reroute planning or seam-observation recording. Verified
  with `lua test_map_survey.lua`, `lua test_route_manager.lua`,
  `lua test_debug_tools.lua`, `luac -p ...`, `git diff --check`, and
  `python3 run_tests.py --allow-missing-speech-dep`. FCEUX still needs a
  manual Lua reload before the new live behavior is active.
- Post-save-state retest found a guardrail false positive, not new Cantlin
  geometry. After the user restored a save state, fresh baseline was clean at
  Cantlin `(20,22)` with `buttons=0x00`, no menu, and no runtime blocks.
  Broad `survey_objects:park_npcs` and targeted
  `survey_target:Guard 2,park_npcs` both started movement normally, but
  `map_survey.tick` saw the expected active auto-step game button byte
  (`buttons=0x10`) while joy/bridge were idle and aborted as
  `reason=input_contaminated`. Source fix: skip the tick-time contamination
  check while `auto_step.get_active_step_state()` is non-nil, leaving startup,
  route-event, and route-manager block guards intact. Verified with
  `lua test_map_survey.lua`, `lua test_route_manager.lua`,
  `lua test_debug_tools.lua`, `luac -p ...`, `git diff --check`, and
  `python3 run_tests.py --allow-missing-speech-dep`. FCEUX needs another manual
  Lua reload before continuing live survey.
- Reload after the tick-guard refinement: command polling verified with
  `launcher_probe:codex_after_tick_guard_reload`. Fresh baseline was Cantlin
  `(20,21)`, `buttons=0x00`, no menu/guard, and no runtime blocks. Preflight
  `report_survey_start:park_npcs` was viable (`targets=21`,
  `reachable_targets=20`, `unreachable_targets=1`, `open_exits=north|south|west|east`).
  `survey_objects:park_npcs` started and the refined tick guard allowed normal
  active movement/rerouting to proceed through many Old Man 4 seam-retry steps.
  The run eventually aborted on a real stuck-input signature at `(23,26)`:
  after a seam retry right from `(23,26)` blocked, Lua joy/bridge were idle but
  game input RAM remained `buttons=0x80`; both survey and auto-walk guards
  refused with `reason=input_contaminated`. A post-abort snapshot still showed
  Cantlin `(23,26)`, `buttons=0x80`, no runtime blocks. Standard
  `recover_fceux_input.sh` did not clear it; follow-up snapshot remained
  `(23,26)`, `buttons=0x80`. Treat this as emulator/input contamination, not
  promotable Cantlin map evidence.
- After another save-state restore, fresh baseline was Cantlin `(20,22)`,
  `buttons=0x00`, no menu/guard, and no runtime blocks. Targeted
  `survey_target:Guard 2,park_npcs` avoided the Old Man 4 opener and made real
  route progress north to `(20,8)`, then rerouted around `(20,8)->UP` and
  completed a step right into `(21,8)`. The survey then aborted on tick with
  `buttons=0x80`; follow-up snapshot had progressed to `(22,8)` and was clean
  again (`buttons=0x00`, no runtime blocks). This was another guard timing
  false positive: route-settle / between-step time can briefly leave the game
  button byte nonzero after a queued step completed. Source fix: skip tick-time
  contamination checks while `auto_step.is_route_active()` is true as well as
  while `get_active_step_state()` is non-nil. Verified with
  `lua test_map_survey.lua`, `lua test_route_manager.lua`,
  `lua test_debug_tools.lua`, `luac -p ...`, `git diff --check`, and
  `python3 run_tests.py --allow-missing-speech-dep`. FCEUX needs another
  manual Lua reload before continuing live survey from the clean `(22,8)` area
  or after a fresh save-state restore.
- Reload validation after the route-active tick fix: command polling verified
  with `launcher_probe:codex_after_reload_20260705`; baseline was Cantlin
  `(20,22)`, `buttons=0x00`, no runtime blocks. Retrying
  `survey_target:Guard 2,park_npcs` no longer aborted from the route-active
  contamination guard, confirming the tick false positive fix live.
- The same `Guard 2` run exposed a separate survey safety problem: it rerouted
  repeatedly around the top-wall approach and accumulated 69 blocked events /
  43 temporary route blocks before manual `stop_survey`. Final survey result:
  `movement_succeeded=false`, `failure_class=suspected_engine_blocked_tile`,
  `reason=manual_stop`, `final=(12,5)`. Post-stop snapshot was healthy:
  Cantlin `(12,5)`, `buttons=0x00`, `RUNTIME_BLOCKS map=0x0A none`, and
  `PATH_STATE target=nil`. DO NOT PROMOTE the broad suspected-tile list from
  this run; it is route-churn diagnostic noise until focused same-origin
  evidence isolates real geometry.
- Source guardrail added: `map_survey.lua` now stops a target after more than
  32 route-block events, logs `SURVEY_ROUTE_CHURN_ABORT`, cancels active route
  state, finishes the run, and classifies the target as
  `command_timing_or_state_issue` instead of clean engine-blocker evidence.
  Regression coverage: `route_churn_cap_stops_target_as_state_issue`.
  Verification passed: `lua test_map_survey.lua`, `lua test_route_manager.lua`,
  `lua test_debug_tools.lua`, `luac -p ...`, `git diff --check`, and
  `python3 run_tests.py --allow-missing-speech-dep`. FCEUX needs another
  manual Lua reload before this cap is active live.
- Reload validation for the route-churn cap: after the user reloaded Lua,
  `launcher_probe:codex_churn_reload_20260705` confirmed polling and the
  baseline was clean at Cantlin `(20,22)`, `buttons=0x00`, no runtime blocks.
  A focused `survey_target:Guard 2,park_npcs` matched the currently moving
  `npc_9` at `(24,10)` and succeeded, ending adjacent at `(23,10)`. It logged
  one reroute-only suspect `(21,11)` and `reason=reroute_succeeded_after_runtime_block`;
  do not promote that single target-route observation without focused
  same-origin proof.
- A broad `survey_objects:park_npcs` from `(23,10)` did not produce survey
  attempts because the command menu/dialogue was open (`menu_active=true`,
  `dialogue_len=23`). `stop_survey` restored all 19 parked NPCs with zero
  targets attempted, and `simulate_input:B` closed the command menu. Treat this
  as workflow contamination, not map survey data.
- Focused `survey_target:Old Man 4,park_npcs` then reproduced the hard
  input-contamination signature before the new route-churn cap could fire:
  at `(23,26)`, after 14 temporary route blocks and while under the cap,
  survey and auto-walk refused with `reason=input_contaminated`,
  `keys=LeftAlt joy=- bridge=- buttons=0x80`. Cleanup worked: the survey
  restored all 19 NPC slots, recorded no targets/results, and left no runtime
  blocks or active path. Standard `recover_fceux_input.sh` cleared/restarted
  the bridge but did not clear the game-side byte; the live snapshot remained
  Cantlin `(23,26)`, `buttons=0x80`. Stop condition: do not continue Cantlin
  movement/survey/probe work from this state.
- Reload/hypothesis check after suspecting the overworld auto-walk timing
  refinements: `launcher_probe:codex_ram_hypothesis_reload_20260705` confirmed
  polling, and baseline was clean at Cantlin `(18,23)`, `buttons=0x00`, no
  menu, no runtime blocks, and no active path. A 180-frame `trace_input` idle
  sample showed only benign stale `LeftAlt`; `dw_keyboard_input.txt` was
  neutral. Code inspection found the recent timing helpers can write movement
  engine bytes `$003C/$003D`, but not `$0047` / `BUTTONS_PRESSED`.
- Focused repro with `survey_target:npc_18,park_npcs` started run 4 cleanly
  from `(18,23)` and reproduced contamination at frame `137384`. The final
  triggering event was a queued-route `DOWN` attempt from `(25,23)`:
  `movement_started=true`, `movement_start_frame=4`, blocked after 36 frames,
  then survey/auto-walk refused with `keys=LeftAlt joy=- bridge=- buttons=0x20`.
  The guard restored all 20 parked NPC slots, recorded no target results, and
  left no runtime blocks or active path.
- Diagnostic recovery checks from the contaminated `(25,23)` state:
  `reset_movement_state` cleared `$003C/$003D` from `0x08/0x08` to `0x00/0x00`
  but left `$0047` stuck at `0x20`. `clear_input` also left `$0047=0x20`.
  This suggests the timing code may be leaving the game in a stale input-byte
  state indirectly, but the current movement reset/neutral joypad hooks are not
  enough to recover it. Next diagnostic should be an explicit, guarded
  debug-only `$0047` clear to see whether the game immediately relatches the
  byte or stays recovered.
- Source diagnostic added: `debug_tools.lua` now supports `clear_game_input`,
  which reads `BUTTONS_PRESSED` (`$0047`), writes `0x00`, re-reads it, and logs
  `GAME_INPUT_CLEAR before=... after=... addr=0x0047`. `debug_hooks.txt`
  documents it, and `test_debug_tools.lua` pins the exact one-byte write/log
  behavior. Verified with `lua test_debug_tools.lua`, `luac -p debug_tools.lua
  test_debug_tools.lua`, and `git diff --check`. FCEUX needs a manual Lua
  reload before the command is available live.
- Live validation after fresh emulator/script reload: command polling was
  confirmed with `launcher_probe:codex_clear_game_input_live_20260706`.
  Baseline was Cantlin `(20,22)`, `buttons=0x00`, no runtime blocks, and no
  active path. Running `clear_game_input` logged
  `GAME_INPUT_CLEAR before=0x00 after=0x00 addr=0x0047`, so the command is live
  and harmless against a clean byte. Repeating the bad
  `survey_target:npc_18,park_npcs` run did not reproduce stuck `$0047`; it hit
  `SURVEY_ROUTE_CHURN_ABORT` after 33 blocked events / 4 suspected tiles at
  `(20,22)`, restored all 20 parked NPCs, classified the target as
  `command_timing_or_state_issue`, and recorded no promotable map evidence.
  Post-abort state remained clean: Cantlin `(20,22)`, `buttons=0x00`, no
  runtime blocks, no active path, and 20 NPC blockers restored. Recovery from a
  genuinely contaminated `$0047` byte remains unproven until the stuck state
  recurs or is reproduced under controlled conditions.
- Follow-up survey repro after the user noted yesterday's failures were quick:
  `launcher_probe:codex_survey_repro_20260706_a` confirmed polling, baseline
  was again Cantlin `(20,22)` with `buttons=0x00`, and `lua
  test_debug_tools.lua` still passed 23 tests. A focused
  `survey_target:npc_18,park_npcs` run reproduced route churn but not input
  contamination; it hit `SURVEY_ROUTE_CHURN_ABORT` at 33 blocked events,
  restored all 20 parked NPCs, and left the state clean. A broader
  `survey_objects:park_npcs` run also routed immediately to `npc_18` and churned
  around `(20,22)` for 28 timing-block events without sticking `$0047`; it was
  manually stopped before the cap, restored all 20 NPCs, and left Cantlin
  `(20,22)`, `buttons=0x00`, no runtime blocks, and no active path. Because
  the manual stop recorded `failure_class=suspected_engine_blocked_tile`, treat
  run 3 as diagnostic churn noise and DO NOT PROMOTE its
  `21,22|20,21|20,23|19,22` suspected tiles. A post-survey `clear_game_input`
  check logged `before=0x00 after=0x00`, so recovery from a real stuck byte
  remains unproven.
- Source follow-up before the next targeted survey reload: the shared
  `debug_tools.input_contamination_refusal` path now captures and auto-clears
  idle-input/nonzero-`$0047` cases. The next real stuck-byte event should log
  `INPUT_CONTAMINATION_CAPTURE`, `GAME_INPUT_AUTO_CLEAR`, and a delayed
  `GAME_INPUT_AUTO_CLEAR_CHECK` sample while still refusing/aborting the
  contaminated command based on the pre-clear state. `map_survey.lua` now also
  classifies manual-stop route/churn evidence as `command_timing_or_state_issue`
  instead of `suspected_engine_blocked_tile`, so a manual survey stop cannot
  promote timing churn into Cantlin geometry. Verified with focused TDD
  regressions in `lua test_debug_tools.lua` and `lua test_map_survey.lua`.
- Bridge-off A/B / recovery boundary: after reload, `set_input_bridge:off`
  persisted through save-state restore and a focused Old Man 4 survey ran much
  longer, but it still reproduced the stuck input byte at `(25,23)` on a
  queued-route `DOWN` attempt: `INPUT_CONTAMINATION_CAPTURE ... buttons=0x20`,
  `GAME_INPUT_AUTO_CLEAR ... after=0x00`, and delayed
  `GAME_INPUT_AUTO_CLEAR_CHECK ... buttons=0x00`. Manual controls nevertheless
  stayed dead until the user restored a save state. Post-restore baseline at
  `(25,23)` had `buttons=0x00`, `bridge_enabled=false`, no runtime blocks, no
  active path, and `report_survey_start:park_npcs` still considered all four
  exits open/reachable; read-only `inspect_move:25,23,UP/DOWN/LEFT/RIGHT`
  also reported every edge `effective_passable=true`. Treat this as evidence
  that `$0047` is a tripwire/symptom rather than the whole root cause.
- Source mitigation after that boundary: contamination auto-clear now also
  opens a 30-frame raw-neutral `GAME_INPUT_AUTO_NEUTRAL` window via the existing
  isolation machinery. This is a mitigation/evidence cleanup step, not proven
  emulator recovery. Verified with a red/green update to
  `test_debug_tools.lua`, plus `lua test_debug_tools.lua`,
  `lua test_map_survey.lua`, `lua test_route_manager.lua`,
  `luac -p debug_tools.lua test_debug_tools.lua main.lua map_survey.lua
  route_manager.lua`, and `git diff --check`. FCEUX needs a manual Lua reload
  before live testing this behavior.
- Strong hard-lock signature after reload: command polling still worked and
  `isolate_input:180` completed, but manual controls stayed dead. The visible
  input layers were clean or recoverable: `$0047=0x00`, bridge disabled during
  the test, and `recover_fceux_input.sh` cleared the stale Alt report to
  `keys=- joy1=- bridge=- buttons=0x00`. Manual direction presses and
  Lua-injected raw `START`/`A` reached `joypad.read()` (`joy1=right`,
  `joy1=start`, `joy1=A`), but the hero did not move and raw `A` did not open
  the normal field command menu. `reset_movement_state` cleared `$003C/$003D`
  from `0x08/0x08`, but raw `A` still did not open the menu afterward. The
  user also confirmed physical controller `A` cannot open the command menu in
  this state. This is stronger evidence of a FCEUX/game-core input consumption
  wedge below the mod's visible input surfaces; restore save state or emulator
  investigation is the next honest recovery path.
- FCEUX source detour: upstream `TASEmulators/fceux` tag `v2.6.6` was cloned to
  `/mnt/d/modding/fceux-input-debug` on branch
  `codex/input-hardlock-diagnostics`. Diagnostic-only instrumentation was added
  behind `FCEUX_DW_INPUT_TRACE=1` with optional
  `FCEUX_DW_INPUT_TRACE_FILE=...`; it logs Qt key/gamepad events, Lua
  `joypad.set` / `FCEU_LuaReadJoypad` masks, core `UpdateGP`, `$4016` strobe
  and serial reads, and savestate load boundaries. Verification so far:
  `git diff --check`, `g++ -std=c++11 -fsyntax-only -DPSS_STYLE=1 -Isrc
  src/input.cpp`, `g++ -std=c++11 -fsyntax-only -DPSS_STYLE=1 -Isrc
  src/state.cpp`, and standalone syntax for `src/input_trace.h`. Full FCEUX
  build was not run because WSL and Windows both lack `cmake`; Windows also
  lacks the expected MSBuild/Qt 5.15 paths from upstream's `qwin64_build.bat`.

## 2026-07-03 Cantlin Overworld Trail

- Baseline after user relocation: `report_position` confirmed World Map
  `(15,93)` and `report_runtime_blocks` showed no runtime blocks on map `0x01`.
- `debug_pathfind_to:73,102` reported the direct coordinate guess
  `9 south, 58 east`, but `trace_path` showed this coordinate plan does not
  store an A* path (`path_length=0`), so it is guide-orientation only.
- `auto_walk_blocker:15,102` is not usable for overworld coordinate trail
  cutting in the currently running script: before cleanup it correctly refused
  because the command menu was open; after closing the menu with
  `simulate_input:B`, it reached the overworld-route branch and reported
  `No overworld route active`.
- Live movement evidence: same-origin `probe_edge:DOWN` moved from `(15,93)`
  to `(15,94)`, then another `probe_edge:DOWN` moved from `(15,94)` to
  `(15,95)`.
- Follow-up after the user healed: southbound probes confirmed the guide's
  southwest descent from `(15,95)` through `(15,97)`, `(15,99)`,
  `(15,101)`, and the southwest corner at `(15,103)`. Raw `probe_edge`
  carries often landed two tiles away, so keep the route waypoints coarse
  rather than treating every destination cell as a precise single-step proof.
- The guide-shaped east crossing is live-confirmed from `(15,103)` through
  `(17,103)`, `(19,103)`, `(21,103)`, `(23,103)`, `(25,103)`, `(27,103)`,
  `(29,103)`, `(31,103)`, and `(32,103)`.
- After the `(32,103)` battle, live route checks confirmed the first bend:
  `(32,103)->UP` carried to `(32,101)` and `(32,101)->UP` carried to
  `(32,99)`. East from `(32,103)` and east from `(32,101)` both blocked.
- Contamination boundary: user reported the emulator/controller became
  unresponsive after the later battle sequence and explicitly asked that the
  last-battle evidence be discarded and retried. Treat row-99 exploration
  after reaching `(32,99)`, including `(32,99)->RIGHT`, the `(37,99)` /
  `(35,99)` spurs, isolated-looking `(33,99)`, forced teleports to `(32,99)` /
  `(32,103)`, and all post-force blocker results as tainted route evidence.
- Read-only input diagnostics while left in the bad state: command polling and
  Lua were alive, `report_position` still showed World Map `(32,103)`,
  `report_menu_state` showed no active command menu/dialogue, and
  `report_input_guard_state` showed no suppress/teleport/menu guard. At rest
  Lua saw only stale `LeftAlt` (`joy=-`, bridge buttons `0x00`). A passive
  `trace_input:300` also saw no joypad/bridge input. Earlier manual presses did
  reach Lua as rapidly changing directions, but `auto_step` canceled each
  attempted step from the contaminated movement state.
- Recovery observation: user pressed Start; log showed
  `INPUT_STUCK_ALT_CLEAR ... joy1=start`, then command menu opened and closed.
  Normal manual movement immediately resumed: down completed from `(32,103)` to
  `(32,104)`, up returned to `(32,103)`, and another up completed to
  `(32,102)`. Fresh read-only snapshot at `(32,102)` showed no active menu, no
  input guard, no active path, and no runtime blocks. `LeftAlt` is still latched
  at idle, but the code treats LeftAlt-only FCEUX idle state as benign latch
  noise rather than synthetic input.
- Clean reprobe after Start recovery: from `(32,102)`, raw `probe_edge:UP`
  moved through `(32,101)` and carried to `(32,100)`. A second
  `probe_edge:UP` from `(32,100)` reached `(32,99)` and carried to `(32,98)`.
  After calibrating a short raw `UP,20` hold to settle exactly on `(32,99)`,
  `probe_edge:RIGHT` cleanly moved from `(32,99)` through `(33,99)` and carried
  to `(34,99)`. Further clean right probes reached `(36,99)` and then
  `(37,99)`. From `(37,99)`, `probe_edge:UP` cleanly moved through `(37,98)`
  and carried to `(37,97)`.
- Current live interruption: immediately after reaching `(37,97)`, a Wraith
  Knight battle started. The queued follow-up `probe_edge:RIGHT` was refused
  because edge probes are only available while walking on the field. Resume
  after battle from the live position if still on/near `(37,97)`, and re-run
  the east/north/south spur checks from clean field state.
- Post-Wraith clean continuation: after battle, fresh baseline confirmed field
  state at `(37,97)` with no menu/input guard/runtime blocks. Same-origin
  `probe_edge:RIGHT` moved cleanly into `(38,97)`, then immediately triggered a
  Demon Knight battle. Treat `(37,97)->RIGHT` as passable; resume after the
  Demon Knight from the live field position, likely `(38,97)`, and continue
  checking exits from that spur.
- Post-Demon clean continuation: after battle and user HEAL, fresh baseline
  confirmed field state at `(38,97)` with no menu/input guard/runtime blocks.
  Clean probes found `(38,97)->RIGHT` blocked, `(38,97)->UP` blocked, and
  `(38,97)->DOWN` open to `(38,98)`.
- The clean trail from `(38,98)` then continued east/north/east/north:
  `(38,98)->RIGHT` carried to `(40,98)`, `(40,98)->RIGHT` moved to `(41,98)`
  and triggered a Metal Slime encounter that ran away, then fresh baseline at
  `(41,98)` was clean. Continuing from there: `(41,98)->RIGHT` reached
  `(42,98)`, `(42,98)->RIGHT` blocked, `(42,98)->UP` reached `(42,97)`,
  `(42,97)->UP` blocked, `(42,97)->RIGHT` carried to `(44,97)`,
  `(44,97)->RIGHT` blocked, `(44,97)->UP` carried to `(44,95)`, and
  `(44,95)->UP` reached `(44,94)`.
- Current live interruption: a Metal Slime battle started immediately after
  reaching `(44,94)` and did not clear during the short watch window. Resume
  only after battle from a clean field baseline at/near `(44,94)`.
- Post-Metal-Slime continuation: fresh field baseline confirmed World Map
  `(44,94)` with no menu/input guard/runtime blocks. Clean probes found
  `(44,94)->UP` blocked and `(44,94)->RIGHT` open, carrying to `(46,94)`.
  The east leg continued through `(48,94)`, `(49,94)`, and `(50,94)`;
  `(50,94)->RIGHT` blocked. The route then bent north: `(50,94)->UP` reached
  `(50,93)`, and `(50,93)->UP` reached `(50,92)` before a Knight battle
  started.
- Post-Knight continuation: after battle and user HEAL, fresh field baseline
  confirmed World Map `(50,92)` with no menu/input guard/runtime blocks. Clean
  north probes moved through `(50,91)`, `(50,90)`, carried to `(50,88)`, then
  carried to `(50,86)`. `(50,86)->UP` blocked, and `(50,86)->RIGHT` carried to
  `(52,86)`. `(52,86)->RIGHT` then moved to `(53,86)` before another Knight
  battle started.
- Post-second-Knight continuation: fresh field baseline confirmed World Map
  `(53,86)` with no menu/input guard/runtime blocks. Clean east probes moved
  through `(54,86)`, `(55,86)`, `(56,86)`, `(57,86)`, `(58,86)`, and
  `(59,86)`. From the tip, `(59,86)->RIGHT`, `(59,86)->UP`, and
  `(59,86)->DOWN` all blocked, so the route backed west to `(58,86)`.
  `(58,86)->UP` reached `(58,85)`, and `(58,85)->UP` reached `(58,84)` before
  a Werewolf battle started.
- Post-Werewolf continuation: fresh field baseline confirmed World Map
  `(58,84)` with no menu/input guard/runtime blocks. From there,
  `(58,84)->UP` blocked, while right carried to `(60,84)` and `(62,84)`,
  with `(62,84)->RIGHT` blocked. The south/east side pocket from `(62,84)`
  was explored through `(62,85)`, `(63,85)`, `(63,86)`, `(65,86)`, and
  `(67,86)`; its right, up, and down exits at the tip all blocked, and the
  branch was a dead end. Backtracking exposed the real continuation:
  `(62,85)->UP` carried to `(62,83)`, then the clean route moved north to
  `(62,82)`, east to `(63,82)`, north to `(63,81)`, east to `(64,81)`, north
  to `(64,80)`, and east via carries through `(66,80)`, `(68,80)`, and
  `(70,80)`.
- Post-Magiwyvern continuation: after battle and user HEALs, fresh field
  baseline confirmed World Map `(71,80)` with no menu/input guard/runtime
  blocks. The clean route continued east through `(73,80)`, `(75,80)`, and
  `(77,80)`, where right and up blocked and south opened to `(77,81)`.
  From there, down blocked, east reached `(78,81)`, east/up blocked, and south
  carried to `(78,83)`. The route then bent east to `(79,83)`, south to
  `(79,84)`, east via `(81,84)` to `(82,84)`, with `(82,84)->RIGHT` blocked.
  South from `(82,84)` carried through `(82,86)` and `(82,88)`.
- Post-Demon-Knight continuation: after battle and user HEALs, fresh field
  baseline confirmed World Map `(82,89)` with no menu/input guard/runtime
  blocks. The clean route moved south to `(82,90)`, where south blocked and
  east reached `(83,90)`. From there, east blocked, south carried to
  `(83,92)`, south blocked, east reached `(84,92)`, and south carried through
  `(84,94)` to `(84,96)`. From `(84,96)`, south blocked, east carried to
  `(86,96)`, east blocked, south reached `(86,97)`, south blocked, east reached
  `(87,97)`, east blocked, and south carried through `(87,99)` to `(87,100)`.
  From `(87,100)`, south blocked and east carried to `(89,100)`, where east
  blocked and south continued through `(89,102)`, `(89,103)`, `(89,104)`, and
  `(89,105)`.
- Post-Knight-at-89106 continuation: after battle and user HEAL, fresh field
  baseline confirmed World Map `(89,106)` with no menu/input guard/runtime
  blocks. The clean route continued straight south through `(89,107)`,
  `(89,108)`, and `(89,109)`.
- Post-Knight-at-89110 continuation: after battle, user HEAL, and some
  transient FCEUX input-bridge chatter, a fresh baseline confirmed World Map
  `(89,110)` with menu closed, no dialogue/input guard, no runtime blocks, and
  only the known idle `LeftAlt` latch. Clean probes continued south through
  `(89,111)`, `(89,112)`, and `(89,113)`. From `(89,113)`, south and east
  blocked, while west opened to `(88,113)`.
- The clean trail then snaked southwest through the lower forest corridor:
  `(88,113)->DOWN` to `(88,114)`, south blocked, west to `(87,114)`, south to
  `(87,115)`, south blocked, west to `(86,115)`, south blocked, west to
  `(85,115)`, south to `(85,116)`, south blocked, west to `(84,116)`, south
  blocked, west to `(83,116)`, south blocked, west to `(82,116)`. At
  `(82,116)`, south and west blocked; north opened to `(82,115)`, then west
  continued through `(81,115)`, `(80,115)`, and `(79,115)`. At `(79,115)`,
  south and west blocked; north opened to `(79,114)`. The trail then went west
  to `(78,114)`, where west and south blocked; north opened to `(78,113)`,
  west continued through `(77,113)` and `(76,113)`, south at `(76,113)`
  blocked, west continued through `(75,113)` to `(74,113)`, then south opened
  through `(74,114)` to `(74,115)`.
- Current live interruption: moving down from `(74,114)` reached `(74,115)` and
  triggered a regular `Starwyvern` battle (`A Starwyvern draws near!`), not the
  Golem. Resume only after battle from a clean field baseline at/near
  `(74,115)`.
- Starwyvern death/reposition boundary: the user reported the hero lost the
  Starwyvern RNG battle, refreshed, teleported back, and walked around to clear
  taint. Treat the battle/death/teleport sequence as a hard contamination
  boundary, but the fresh post-teleport baseline is clean: after closing a
  leftover command menu, `report_position` confirmed World Map `(73,115)` with
  menu closed, no dialogue/input guard/runtime blocks, no active path, HP
  `85/92`, MP `85/85`, and only the known idle `LeftAlt` latch.
- Post-reposition continuation: clean same-origin probes found
  `(73,115)->DOWN` to `(73,116)`, where south and east blocked; west opened to
  `(72,116)`. The route then continued south/west through `(72,117)`,
  `(71,117)`, `(71,118)`, and west through `(70,118)` to `(69,118)`. South
  from `(72,117)` and south from `(71,118)` both blocked. Moving west from
  `(70,118)` reached `(69,118)` and triggered a regular `Werewolf` battle
  (`A Werewolf draws near!`), not the Golem. Resume only after battle from a
  clean field baseline at/near `(69,118)`.
- Post-Werewolf-at-69118 continuation: after battle, fresh baseline confirmed
  World Map `(69,118)`, menu closed, no dialogue/input guard/runtime blocks,
  no active path, HP `72/92`, MP `85/85`, and only the known idle `LeftAlt`
  latch. The clean route continued west through `(68,118)` and `(67,118)`,
  then south to `(67,119)`, west through `(66,119)`, `(65,119)`, `(64,119)`,
  and `(63,119)`. From there north opened to `(63,118)`, west continued through
  `(62,118)`, `(61,118)`, and `(60,118)`, and north opened to `(60,117)`.
  West from `(60,117)` carried to `(58,117)`; west from `(58,117)` carried to
  `(56,117)`. At `(56,117)`, HP was still `52/92`; west reached `(55,117)`,
  where west blocked and north carried to `(55,115)`. West from `(55,115)`
  carried through `(53,115)` to `(51,115)`, where west blocked and north
  carried to `(51,113)`. West from `(51,113)` reached `(50,113)` and triggered
  another regular `Werewolf` battle (`A Werewolf draws near!`), not the Golem.
  Resume only after battle from a clean field baseline at/near `(50,113)`.
- Post-Werewolf-at-50113 continuation: after battle, user HEALs, and manual
  movement, a fresh baseline confirmed World Map `(52,113)` with menu closed,
  no dialogue/input guard/runtime blocks, HP `81/92`, MP `69/85`, and only the
  known idle `LeftAlt` latch. Same-origin east probes then carried
  `(52,113)->RIGHT` to `(54,113)` and `(54,113)->RIGHT` to `(56,113)`. The
  latter move immediately triggered a regular `Starwyvern` battle (`A
  Starwyvern draws near!`), not the Golem. Resume only after battle from a
  clean field baseline at/near `(56,113)`.
- Post-Starwyvern-at-56113 continuation: after battle and user HEALs, fresh
  baseline confirmed World Map `(56,113)`, menu closed, no dialogue/input
  guard/runtime blocks, no active path, HP `91/92`, MP `57/85`, and only the
  known idle `LeftAlt` latch. The route continued east through `(58,113)`,
  `(60,113)`, `(62,113)`, `(64,113)`, `(65,113)`, and `(66,113)`, then north
  through `(66,112)`, `(66,111)`, `(66,110)`, carried to `(66,108)`, and
  reached `(66,107)`. From `(66,107)`, north and east blocked; west carried to
  `(64,107)`. From there north reached `(64,106)`, where north and east
  blocked; west carried to `(62,106)`. North reached `(62,105)`, where north
  blocked and east reached `(63,105)`. From `(63,105)`, east and north blocked;
  south reached `(63,106)` and triggered another regular `Starwyvern` battle
  (`A Starwyvern draws near!`), not the Golem. Resume only after battle from a
  clean field baseline at/near `(63,106)`.
- Post-Starwyvern-at-63106 continuation: after battle and user HEALs, fresh
  baseline confirmed World Map `(63,106)`, menu closed, no dialogue/input
  guard/runtime blocks, no active path, HP `84/92`, MP `45/85`, and only the
  known idle `LeftAlt` latch. Clean probes found `(63,106)->RIGHT` open to
  `(64,106)`, `(64,106)->DOWN` carrying to `(64,108)`, then east through
  `(66,108)` to `(67,108)`. From `(67,108)`, east and north blocked while
  south opened to `(67,109)`. The route then bent east/south/east through
  `(68,109)`, `(69,109)`, `(69,110)`, `(70,110)`, `(71,110)`, `(72,110)`,
  `(72,111)`, `(73,111)`, `(73,112)`, `(74,112)`, and `(74,113)`, with
  north/east blockers at the tested tips. Read-only `debug_pathfind_to:73,102`
  from `(74,113)` only produced compass fallback (`path_len=0`) because the
  overworld is not A*-decoded; `teleport_to:89,102` was refused by missing
  model walkability and should not be treated as live map proof.
- Post-heal continuation near Cantlin maze: from `(74,113)`, clean probes found
  a live loop back through `(73,113)`, `(73,112)`, `(72,112)`, `(72,111)`,
  `(71,111)`, and `(71,110)`, with north from `(71,110)` blocked. After the
  user took a healing break, fresh baseline confirmed World Map `(70,110)`,
  menu closed, no dialogue/input guard/runtime blocks, no active path,
  HP `91/92`, MP `33/85`, and only the known idle `LeftAlt` latch. From there,
  north blocked; west reached `(69,110)`, north reached `(69,109)`, west
  reached `(68,109)`, north blocked, west reached `(67,109)`, west carried to
  `(65,109)`, north carried to `(65,107)`, north blocked, west carried to
  `(63,107)`, north carried to `(63,105)`, and west carried to `(61,105)`.
  Immediately after reaching `(61,105)`, a regular `Starwyvern` battle started
  (`A Starwyvern draws near!`), not the Golem. A queued `probe_edge:UP` was
  refused during battle. The log later reported `Thou art dead.` Treat the
  death/refresh/reposition sequence as the next hard contamination boundary;
  resume only after a fresh field baseline.
- Post-death restore at `(61,105)`: the user restored from death and returned
  to the field at/near `(61,105)`. Fresh baseline confirmed World Map
  `(61,105)`, menu closed, no dialogue/input guard/runtime blocks, no active
  path, HP `87/92`, MP `85/85`, and only the known idle `LeftAlt` latch.
  Clean probes found `(61,105)->UP` blocked, `(61,105)->LEFT` carrying to
  `(59,105)`, `(59,105)->UP` open to `(59,104)`, and `(59,104)->UP` blocked.
  West from `(59,104)` reached `(58,104)` and immediately triggered another
  regular `Starwyvern` battle (`A Starwyvern draws near!`), not the Golem.
  Resume only after battle from a clean field baseline at/near `(58,104)`.
- Post-Starwyvern-at-58104 continuation: after battle and user HEALs, fresh
  baseline confirmed World Map `(58,104)`, menu closed, no dialogue/input
  guard/runtime blocks, no active path, HP `84/92`, MP `69/85`, and only the
  known idle `LeftAlt` latch. Clean probes found north blocked at `(58,104)`;
  west then carried through `(56,104)` and `(54,104)`. From `(54,104)`, north
  opened to `(54,103)` but north from there blocked, so the trail bent west
  through `(52,103)` to `(51,103)`, where north and west blocked. South from
  `(51,103)` carried to `(51,105)`, then west/north/west/north/west/north
  traced `(50,105)`, `(50,104)`, `(48,104)`, `(48,102)`, `(48,100)`,
  `(48,98)`, and `(48,97)`, with north at `(48,97)` blocked. East from
  `(48,97)` carried to `(50,97)`, and north from `(50,97)` reached `(50,96)`
  immediately before a regular `Werewolf` battle started (`A Werewolf draws
  near!`), not the Golem. Resume only after battle from a clean field baseline
  at/near `(50,96)`.
- Post-Werewolf-at-50096 continuation: after battle and user HEALs, fresh
  baseline confirmed World Map `(50,96)`, menu closed, no dialogue/input
  guard/runtime blocks, no active path, HP `84/92`, MP `57/85`, and only the
  known idle `LeftAlt` latch. Clean probes found north blocked at `(50,96)`,
  east carrying to `(52,96)`, north opening to `(52,95)`, north from there
  blocked, east carrying to `(54,95)`, and north carrying to `(54,93)`.
  Immediately after reaching `(54,93)`, a regular `Magiwyvern` battle started
  (`A Magiwyvern draws near!`), not the Golem. A queued follow-up
  `probe_edge:UP` was refused during battle; resume only after battle from a
  clean field baseline at/near `(54,93)`.
- Post-Magiwyvern-at-54093 continuation: after battle, user HEALs, and a brief
  FCEUX input-bridge recovery sequence, fresh baseline confirmed World Map
  `(54,93)`, menu closed, no dialogue/input guard/runtime blocks, no active
  path, HP `88/92`, MP `43/85`, and only the known idle `LeftAlt` latch.
  Clean probes found north blocked at `(54,93)`, east carrying to `(56,93)`,
  north opening to `(56,92)`, north from there blocked, east carrying to
  `(58,92)`, and north from `(58,92)` blocked. East from `(58,92)` reached
  `(59,92)` and immediately triggered a regular `Demon Knight` battle (`A
  Demon Knight draws near!`), not the Golem. Resume only after battle from a
  clean field baseline at/near `(59,92)`.
- Post-Demon-Knight-at-59092 continuation: after battle, user HEALs, and an
  interrupted probe recovery, fresh baseline confirmed World Map `(83,102)`
  with menu closed, no dialogue/input guard/runtime blocks, no active path, HP
  `85/92`, MP `39/85`, and only the known idle `LeftAlt` latch. Clean route
  evidence from `(59,92)` continued north to `(59,91)`, then east to
  `(61,91)`, north to `(61,89)`, east through `(63,89)`, `(65,89)`, and
  `(67,89)`, north to `(67,88)`, and a dead-end check at `(68,88)` where
  north/east/south blocked. Backtracking exposed the lower continuation:
  `(66,88)` south to `(66,90)`, east through `(68,90)` and `(69,90)`, south to
  `(69,91)`, east through `(71,91)`, `(72,91)`, and `(73,91)`, north to
  `(73,90)`, then east through `(74,90)`, `(75,90)`, `(76,90)`, and `(77,90)`.
  East blocked there, so the route bent south/east through `(77,92)`,
  `(79,92)`, `(79,91)`, back south to `(79,93)`, west to `(77,93)`, south to
  `(77,95)`, east through `(79,95)` and `(80,95)`, south to `(80,97)`, east to
  `(82,97)`, south to `(82,99)`, east to `(83,99)`, north/east dead-end checks
  through `(83,98)` and `(84,98)`, then back through `(82,98)`, south to
  `(82,100)`, south to `(82,102)`, and east to `(83,102)`. The interrupted
  `(83,102)->UP` probe later logged cleanly blocked; after closing the
  accidental command menu and re-baselining, `(83,102)->RIGHT` also blocked,
  while south carried to `(83,104)` and east from `(83,104)` reached
  `(84,104)`. That last move immediately triggered a regular `Wizard` battle
  (`A Wizard draws near!`), not the Golem. A fresh read-only baseline during
  the pause confirmed battle state at `(84,104)`, HP `74/92`, MP `39/85`,
  enemy HP `65`, and no runtime blocks. Resume only after battle from a clean
  field baseline at/near `(84,104)`.
- Post-Wizard-at-84104 continuation: after battle and user HEALs, fresh
  baseline confirmed World Map `(84,104)`, menu closed, no dialogue/input
  guard/runtime blocks, no active path, HP `83/92`, MP `23/85`, and only the
  known idle `LeftAlt` latch. Clean probes found `(84,104)->DOWN` and
  `(84,104)->RIGHT` blocked, while north opened to `(84,103)`. From
  `(84,103)`, north blocked and east opened to `(85,103)`, but `(85,103)` was
  a dead-end tip with east, south, and north all blocked. Backtracking west
  from `(85,103)` carried through `(84,103)` to `(83,103)`, then west carried
  cleanly through `(81,103)`, `(79,103)`, and `(77,103)`. West from
  `(77,103)` reached `(76,103)` and immediately triggered a regular
  `Starwyvern` battle (`A Starwyvern draws near!`), not the Golem. Resume only
  after battle from a clean field baseline at/near `(76,103)`.
- Quick-load contamination/config boundary: after the Starwyvern interruption,
  the user accidentally hit FCEUX quick load on `P` while recovering. Treat the
  resulting restored state as a hard contamination boundary until the user
  returns to position and a fresh field baseline is captured. Local FCEUX config
  `D:\emulation\fceux\bin\fceux.cfg` was backed up to
  `fceux.cfg.pre_unbind_savestate_20260704`, and the general
  `SDL.Hotkeys.LoadState` / `SDL.Hotkeys.SaveState` bindings were blanked.
  Slot-specific F-key savestate bindings remain unchanged.
- Post-quick-load continuation: after FCEUX restart/reposition, fresh baseline
  confirmed World Map `(78,103)`, menu initially open, no runtime blocks, HP
  `92/92`, MP `85/85`, and only idle `LeftAlt`; the command menu was closed
  and stale `Cantlin` auto-walk target cleared before probing. Treat this as a
  new clean route evidence segment after the quick-load contamination boundary.
  West from `(78,103)` carried to `(76,103)`, then continued west through
  `(74,103)`, `(72,103)`, `(70,103)`, `(68,103)`, `(66,103)`, `(64,103)`, and
  `(62,103)`. South from `(62,103)` opened and carried down the vertical lane
  through `(62,105)`, `(62,107)`, `(62,109)`, `(62,111)`, `(62,113)`,
  `(62,114)`, `(62,116)`, `(62,117)`, `(62,118)`, and finally `(62,119)`.
  The move into `(62,119)` triggered a regular `Starwyvern` battle (`A
  Starwyvern draws near!`), not the Golem. Resume only after battle from a
  clean field baseline at/near `(62,119)`.
- Post-Starwyvern-at-62119 continuation: after battle, fresh baseline confirmed
  World Map `(62,119)`, menu closed, no dialogue/input guard/runtime blocks,
  no active path, HP `91/92`, MP `73/85`, and only the known idle `LeftAlt`
  latch. South from `(62,119)` blocked at the map edge/bottom lane, while east
  opened and continued along row 119 through `(63,119)`, `(64,119)`,
  `(65,119)`, `(66,119)`, `(67,119)`, `(68,119)`, and `(69,119)`. East from
  `(69,119)` blocked, and north opened through `(69,118)`, `(69,117)`, and
  `(69,116)` to `(69,115)`. The move into `(69,115)` triggered another regular
  `Starwyvern` battle (`A Starwyvern draws near!`), not the Golem. Resume only
  after battle from a clean field baseline at/near `(69,115)`.
- Post-Starwyvern-death/reposition boundary: the hero lost the Starwyvern fight
  and the user restored, manually walked back, and healed. Treat the
  death/restore/manual-walk sequence as a hard contamination boundary. Fresh
  baseline confirmed World Map `(69,115)`, menu closed, no dialogue/input
  guard/runtime blocks, no active path, HP `92/92`, MP `69/85`, and only the
  known idle `LeftAlt` latch. Clean probes confirmed the north lane from
  `(69,115)` through `(69,114)`, `(69,113)`, `(69,112)`, `(69,111)`,
  `(69,110)`, and `(69,109)`. East and north from `(69,109)` both blocked.
  West then opened through `(68,109)` and `(67,109)`, with the next west hold
  carrying to `(65,109)`. North from `(65,109)` reached `(65,108)` and
  immediately triggered a regular `Wizard` battle (`A Wizard draws near!`),
  not the Golem. Resume only after battle from a clean field baseline at/near
  `(65,108)`.
- Post-Wizard-at-65108 continuation: after battle and user HEALs, fresh
  baseline confirmed World Map `(65,108)`, menu closed, no dialogue/input
  guard/runtime blocks, no active path, HP `80/92`, MP `55/85`, and only the
  known idle `LeftAlt` latch. North opened to `(65,107)`. East opened to
  `(66,107)`, but east and north from `(66,107)` both blocked, making that a
  short spur. West back to `(65,107)` moved cleanly and immediately triggered a
  regular `Starwyvern` battle (`A Starwyvern draws near!`), not the Golem.
  Resume only after battle from a clean field baseline at/near `(65,107)`.
- Post-Starwyvern-death-at-65107 restore: after the Starwyvern killed the hero,
  the user restored to `(65,108)`. Treat the death/restore as a hard evidence
  boundary. Fresh baseline confirmed World Map `(65,108)`, menu closed, no
  dialogue/input guard/runtime blocks, no active path, HP `80/92`, MP `55/85`,
  and only idle `LeftAlt`. Clean probes found north to `(65,107)`, north from
  `(65,107)` blocked, west carrying to `(63,107)`, north carrying to
  `(63,105)`, and then a regular `Green Dragon` battle, not the Golem. The
  queued `(63,105)->UP` probe was refused during battle and is not evidence.
  After the Green Dragon was defeated and HEALs were cast, fresh baseline at
  `(63,105)` was clean: HP `83/92`, MP `43/85`, no runtime blocks or active
  path. From there, north blocked, west carried to `(61,105)`, south carried to
  `(61,107)`, east carried back through `(63,107)`, and south/east traced a
  lower connector through `(63,109)`, `(65,109)`, `(65,110)`, `(66,110)`,
  `(67,110)`, `(68,110)`, `(69,110)`, `(70,110)`, `(71,110)`, and `(72,110)`.
  North and east from `(72,110)` blocked; the route curled through `(72,111)`,
  `(73,111)`, `(73,112)`, `(74,112)`, and `(74,113)`, with north/east blocks
  at the tested tips. East from `(74,113)` opened into a new lane:
  `(75,113)`, `(76,113)`, `(77,113)`, `(78,113)`, north to `(78,112)`, east
  to `(79,112)`, north to `(79,111)`, east to `(80,111)`, north to `(80,110)`,
  east to `(81,110)`, north to `(81,109)`, then east through `(82,109)`,
  `(83,109)`, `(84,109)`, `(85,109)`, north to `(85,108)`, east to `(86,108)`.
  A transient `dw_commands.txt` write hiccup occurred before the first
  `(86,108)->UP` attempt; it produced no consumed command and no map evidence.
  After a clean re-anchor at `(86,108)`, north opened to `(86,107)`, north from
  `(86,107)` blocked, and east reached `(87,107)` immediately before a regular
  `Werewolf` battle (`A Werewolf draws near!`), not the Golem. Resume only
  after battle from a clean field baseline at/near `(87,107)`.
- Post-Werewolf-death-at-87107 restore: after the Werewolf killed the hero, the
  user restored and relocated to `(87,107)`. Treat the death/restore/relocation
  as a hard evidence boundary. Fresh baseline confirmed World Map `(87,107)`,
  menu closed, no dialogue/input guard/runtime blocks, no active path,
  HP `92/92`, MP `85/85`, and only idle `LeftAlt`. Clean probes found north to
  `(87,106)`, north to `(87,105)`, north carrying to `(87,103)`, north carrying
  to `(87,101)`, west carrying to `(85,101)`, then west to `(84,101)`. The move
  into `(84,101)` immediately triggered a regular `Wizard` battle (`A Wizard
  draws near!`), not the Golem. Resume only after battle from a clean field
  baseline at/near `(84,101)`.
- Post-Wizard-at-84101 continuation: after battle and user HEALs, fresh field
  baseline confirmed World Map `(84,101)`, menu closed, no dialogue/input
  guard/runtime blocks, no active path, HP `92/92`, MP `75/85`, and only idle
  `LeftAlt`. Clean west probes found `(84,101)->LEFT` carrying to `(82,101)`,
  then `(82,101)->LEFT` carrying to `(80,101)`. The next west step moved into
  `(79,101)` and immediately triggered a regular `Green Dragon` battle (`A
  Green Dragon draws near!`), not the Golem. Resume only after battle from a
  clean field baseline at/near `(79,101)`.
- Cantlin entry completion: after the Green Dragon, fresh baseline confirmed
  World Map `(79,101)`, menu closed, no dialogue/input guard/runtime blocks,
  no active path, HP `82/92`, MP `63/85`, and only idle `LeftAlt`. West from
  `(79,101)` reached `(77,101)` and a regular `Werewolf` encounter fired a few
  frames after the probe result; the log then showed `RUN` and returned to
  field. Because there was no post-battle baseline before the next movement,
  treat that Werewolf/run sequence as a battle boundary, not clean route-state
  evidence. Subsequent west movement reached `(75,101)`, and west into
  `(74,101)` triggered another regular `Werewolf` encounter, again not the
  Golem; the log again returned to field after `RUN`. A clean read-only
  re-baseline at `(74,101)` then confirmed menu closed, no input guard/runtime
  blocks, no active path, HP `84/92`, MP `63/85`. From that clean baseline:
  `(74,101)->LEFT` carried through `(73,101)` to `(72,101)`;
  `(72,101)->DOWN` carried through `(72,102)` to `(72,103)`;
  `(72,103)->RIGHT` carried through `(73,103)` to `(74,103)`.
  `simulate_raw_input:LEFT,12` corrected precisely back to `(73,103)`.
  Two short `UP,12` nudges from `(73,103)` did not move, but same-origin
  `probe_edge:UP` from `(73,103)` produced `map change -> 0x0A (Cantlin)`,
  landing at in-town `(15,0)`. No Golem encounter fired during this approach;
  either the Golem is already cleared in the current save/state, is at a
  different approach square, or the guide's forced encounter condition was not
  active for this run. Final confirmed state: Cantlin `(15,0)`, menu closed,
  no input guard/runtime blocks, no active path.

## 2026-06-29 Kol Speech/Menu Regression Follow-Up

- User manual pass from the Kol entrance confirmed command-menu open/close,
  SPELL menu entry, and ITEM menu browsing no longer speak stale `Bill` / `ll`
  fragments or bogus merchant prices.
- Follow-up Kol service pass confirmed the Weapons Merchant buy flow and Tool
  Merchant buy screen read correctly. The Tool Merchant sell list exposed a
  lower-row regression: after the cursor reached `Gwaelin's Love` / `Torch`,
  `speech_bridge.log` repeatedly spoke the full merchant summary (`Merchant.
  Gold 22041. Offered: ...`) between item names.
- Source fix in `main.lua`: after a merchant offer selection is already known,
  changed cursor selections still speak, but the fallback full-offer summary is
  suppressed on cursor-blink/split-row redraw frames. Verification passed with
  `luac -p main.lua test_sweep_walk_command_surface.lua merchant.lua
  test_merchant.lua`, `lua test_sweep_walk_command_surface.lua`, `lua
  test_merchant.lua`, and `git diff --check`. POST-RELOAD LIVE VERIFIED:
  fresh `speech_bridge.log` session at `2026-06-29 20:01:20` read the sell
  list as `Herb. 6 gold`, then item names only (`Fairy Flute`, `Dragon's
  Scale`, `Wings`, `Stones of Sunlight`, `Staff of Rain`, `Cursed Belt`,
  `Gwaelin's Love`, `Torch`) without repeated full merchant summaries. The
  game only rendered the Herb sell-list price; later confirmation dialogue read
  `Cursed Belt` as 180 GOLD.
- Two follow-up speech issues were captured from `speech_bridge.log`: field
  spell casts only spoke MP deltas (`Used 4 MP. MP 60`, `Used 3 MP. MP 57`)
  with no result dialogue, and ITEM menu entry spoke the first item twice
  (`Items. Dragon's Scale` followed by `Dragon's Scale`).
- Source fix in `main.lua`: ITEM entry now remembers the item name already
  spoken on submenu entry and suppresses the delayed first cursor update only
  when it matches that name; different immediate cursor movement still speaks.
- Source fix in `main.lua`: STATUS and ITEM lower-window rows remain absorbed
  as memory-spoken submenu UI, but SPELL only absorbs uppercase/no-lowercase
  spell-list rows. Lowercase field spell-result dialogue can now stabilize and
  speak even if it appears before `submenu_mode` clears.
- Verification: `luac -p main.lua test_sweep_walk_command_surface.lua`,
  `lua test_sweep_walk_command_surface.lua`, `lua test_items.lua`,
  `lua test_text.lua`, `lua test_menu.lua`, `lua test_merchant.lua`,
  `lua test_hotkeys.lua`, and `git diff --check` passed.
- POST-RELOAD LIVE VERIFIED: fresh `speech_bridge.log` session at
  `2026-06-29 19:38:55` showed RADIANT cast speech as `Used 3 MP. MP 54`,
  then `Bill chanted the spell of RADIANT.`, then `But nothing happened.` The
  ITEM retest spoke `Items. Dragon's Scale` and then the next movement spoke
  `Fairy Flute`, with no immediate duplicate `Dragon's Scale`.

## 2026-06-29 Kol West Side Door Route Cleanup

### PROMOTED THIS PASS

- Live baseline: map `0x07` / Kol. `report_door_state` showed only the
  western-building door `(7,12)` open; the West Side Door `(1,14)` remained
  closed. Runtime blockers were initially clear.
- The entrance-to-door-stand route originally stalled at `(3,18)->LEFT` into
  `(2,18)`. Same-origin `probe_edge:LEFT` from `(3,18)` raw-hold timed out
  with no NPC and no existing approach block, so `(2,18).east` was promoted.
- Frontier analysis then found the real lower connector: from `(3,17)`,
  `probe_edge:LEFT` entered decoded type-0 `(2,17)` and carried through to
  the already modeled `(1,17)` throat. `map_reader.lua` now models `(2,17)`
  as a Kol passthrough.
- Follow-up route/probe work proved the apparent door-side lane is sealed:
  `(2,15).west`, `(2,16).west`, `(2,16).south`, and `(2,18).west` all blocked
  from same-origin live probes. The upper bridge candidates into decoded
  type-0 `(4,14)` also blocked from `(4,15)->UP` and `(5,14)->LEFT`, so
  `(4,14).south` and `(4,14).east` are modeled as closed approaches.

### LIVE STATUS / NEXT

- Follow-up manual movement proved the route target was wrong, not unreachable:
  the user reached `(1,15)`, pressed north, and the next `report_door_state`
  showed keys `0` with opened-door slot `1=(1,14)`. `objects.lua` now models
  the West Side Door public stand as `(1,15)` facing north.
- Opened-door return route to the Kol exit is now validated. From the
  West-Side-Door area, route retries plus same-origin `probe_edge` checks
  confirmed `(2,10).south`, `(3,10).south`, `(4,11).west`, `(4,12).west`,
  `(4,13).west`, `(2,14).north/west`, and `(3,14).north`. After injecting that
  runtime overlay, `auto_walk_blocker:19,23` reached `(19,23)` and faced south.
- User validation pass then exercised all current Kol door/service routes both
  directions: `West Side Door`, `Western Building Door`, `Tool Merchant`,
  `Weapons Merchant`, and `Inn`, each with a clean return to `Exit to World Map`
  at `(19,23)`. Follow-up log scan found only route-complete markers for the
  validation sequence and no blocker/no-path/interrupt lines.

## 2026-06-29 Kol Closed-Door Tool Merchant Cleanup

### PROMOTED THIS PASS

- Live baseline: map `0x07` / Kol, player at the north-west building lip,
  `report_door_state` showed keys `2` and all opened-door slots `(0,0)`, so
  both known Kol magic-key doors were closed.
- The closed-door route to Tool Merchant stand `(12,21)` repeatedly tried
  false cuts around the western building instead of collapsing at the locked
  boundary. Runtime blockers added and promoted:
  `(7,10).east`, `(7,9).east`, `(7,8).east`, `(6,8).north`,
  `(7,8).north`, `(5,7).east`, `(5,6).east`, `(5,5).east`,
  `(6,4).south`, `(7,4).south`, and `(8,4).south`.
- Most entries were confirmed by route/seam-retry plus same-origin
  `probe_edge`; `(7,8).north` had route evidence only but matches the same
  closed lip and was needed for the no-path collapse.
- With the first five runtime edges active, `auto_walk_blocker:12,21`
  reported `AUTO_WALK: no path` with no opened-door RAM. The follow-up frontier
  still listed row-7 hidden-bridge candidates, so the pass continued by probing
  their reachable approaches and exposed the x=5 east lip / north cap above.

### LIVE STATUS / NEXT

- Current live runtime overlay has ten destination entries:
  `6,4(south)`, `7,4(south)`, `8,4(south)`, `5,5(east)`,
  `5,6(east)`, `5,7(east)`, `6,8(north)`, `7,8(east,north)`,
  `7,9(east)`, and `7,10(east)`.
- FCEUX still needs a manual `main.lua` reload before the permanent source
  blockers affect live pathfinding. After reload, rerun the closed-door
  `auto_walk_blocker:12,21` and `debug_route_frontier_skip_npcs:12,21,80`
  from a clean Kol entrance or the current north-west lip.

## 2026-06-26 Rimuldar Inn / Wings Door Route Cleanup

### PROMOTED THIS PASS

- Live route cleanup started from the user-reported blocker `(29,16)->WEST`.
  Source already modeled that as the row-16 transition guard, so no new
  permanent change was needed for `(29,16).west`.
- Promoted the hidden passthrough `(18,18)`: same-origin `probe_edge:DOWN`
  from `(18,17)` moved through decoded wall tile `(18,18)` and settled at
  `(18,19)`, then later live routing traversed `(18,19)->(18,18)->(18,17)`
  while returning to the entrance.
- Promoted route/probe-confirmed Rimuldar directional blockers:
  `(19,17).west`, `(25,17).east`, `(19,22).west`, `(18,21).south`,
  `(19,23).west`, `(22,20).north`, `(24,21).north`, `(25,20).west`,
  `(25,19).west`, `(23,17).south`, `(22,22).west`, and `(28,16).east`.
- Added explicit interaction points for `Rimuldar Inn Outer Door`:
  public side `(21,20)` facing south, plus the previously proven inside stand
  `(21,22)` facing north. The public side is the primary stand so route-to-door
  from the entrance no longer chooses the unreachable inside stand.
- Added explicit interaction points for `Wings Chest Door`: approach side
  `(21,23)` facing east is now primary, with the previously pinned chest-side
  stand `(23,23)` facing west preserved as an alternate.
- Focused checks passed after the updates:
  `luac -p map_reader.lua objects.lua test_map_reader.lua test_objects.lua`,
  `lua test_map_reader.lua`, `lua test_objects.lua`, and `git diff --check`.

### LIVE STATUS / NEXT

- With the current runtime overlay active, route from the entrance `(29,13)`
  to the public outer-door stand `(21,20)` completed cleanly, and later route
  from `(21,22)` to the inner-door approach stand `(21,23)` completed after a
  timing retry that resolved as passable.
- Door RAM was closed (`slots all (0,0)`) before debug seeding; after real
  manual opens, `report_door_state` showed keys `2` and slots
  `0=(21,21) 1=(22,23)`.
- `debug_seed_open_doors:21,21` was used only for planner inspection, not real
  gameplay. With the outer door seeded, planner paths from `(21,20)` exist to
  `(21,22)`, `(23,23)`, and chest `(24,23)`.
- Real post-door validation is now clean:
  `(21,23)->(24,23)` reached `chest_7` through opened door `(22,23)`, return
  route from chest `(24,23)` to town exit `(29,13)` reached the exit, and full
  town-exit-to-chest route reached `(24,23)`. A later polish pass found the
  remaining row-16 false cut: `(29,16)->LEFT` into `(28,16)` blocked during
  autowalk and same-origin `probe_edge:LEFT`, so `(28,16).east` is promoted.

## 2026-06-27 Rimuldar Weapons Merchant Route Polish

> Historical investigation only: the `(24,7)` and `(22,4)` public-route
> hypotheses are superseded by the 2026-07-17 normal-movement validation above.

### PROMOTED THIS PASS

- SUPERSEDED: the earlier `(27,8).east` blocker was wrong. After a FCEUX Lua
  reload, the user manually crossed `(28,8)->LEFT` into `(27,8)` and reported
  `(27,8)->RIGHT` also open. A fresh same-origin probe from `(27,8)->RIGHT`
  moved through `(28,8)` and carried to `(29,8)`. Since crossing from
  `(28,8)` into `(27,8)` immediately restores the Weapons Merchant path,
  `map_reader.lua` now keeps `(27,8).east` open.
- Follow-up route hit `(27,5)->LEFT` into `(26,5)`; same-origin
  `probe_edge:LEFT` timed out from `(27,5)`. Promoted `(26,5).east`.
- Follow-up route hit `(24,3)->DOWN` into `(24,4)`; same-origin
  `probe_edge:DOWN` timed out from `(24,3)`. Promoted `(24,4).north`.
- After those three closures, the public stand `(24,7)` became a separate
  target-side component. Frontier analysis listed four hidden bridge
  candidates; same-origin probes from normally reached `(25,3)->DOWN`,
  `(26,3)->DOWN`, and `(28,7)->LEFT` all timed out. The remaining
  `(22,3)->DOWN` candidate was checked from a teleport-seeded forensic origin:
  it moved into hidden `(22,4)`, then `(22,4)->DOWN` moved to `(22,5)`.
  From `(22,5)`, live-NPC pathing reaches the Weapons Merchant stand via
  `2 east, 2 south` without crossing the occupied merchant cell. Promoted
  `(22,4)` as the likely missing passthrough; revalidate entrance/return
  routes after script reload because the bridge proof started from teleport.
- Post-reload validation from `(19,3)` found the next false shortcut:
  autowalk to `Weapons Merchant` tried `(19,3)->RIGHT` into `(20,3)`, seam
  retries blocked twice, and same-origin `probe_edge:RIGHT` from `(19,3)`
  timed out. Promoted `(20,3).west` and injected
  `add_blocked_edge:19,3,RIGHT` at runtime. With this closed, frontier search
  shows the next candidate bridge is likely around `(24,3)->LEFT` into
  hidden `(23,3)` or `(22,1)->DOWN` into hidden `(22,2)`.
- Attempting to walk the long lower route to `(24,3)` exposed and verified
  four more lower-loop false exits: `(10,7)->UP` into `(10,6)`,
  `(12,8)->DOWN` into `(12,9)`, `(12,8)->RIGHT` into `(13,8)`, and
  `(15,6)->RIGHT` into `(16,6)`. Each blocked during route/seam retry and
  also timed out from a same-origin probe, so `(10,6).south`,
  `(12,9).north`, `(13,8).west`, and `(16,6).west` are promoted.
  The route later suspected `(8,9)->RIGHT` into `(9,9)`, but that edge was
  not same-origin probed in this pass and remains unpromoted.
- Later target-side forensic routing exposed the actual weapon-shop throat:
  from the stand `(24,7)`, `debug_pathfind_to:29,13` planned
  `1 south, 5 east, 5 south`; live probes moved `(24,7)->DOWN` through
  `(24,8)` to `(24,9)` and then `(24,9)->UP` back through `(24,8)` to the
  stand. This supersedes the older `(24,8).south` blocker, which was removed
  so the entrance can route through the real counter aisle. A manual FCEUX Lua
  reload is required before live route validation.

## 2026-06-24 Brecconary Fairy Water Route / Input Lock Capture

### CLOSEOUT

- User verified routes to and from the Fairy Water merchant are clean.
- Brecconary Magic Key revisit is complete for the current alpha-prep pass.
- Remaining caveat is source reload only: FCEUX must reload `main.lua` before
  the fixed Fairy Water target hold and exit-tile pathability behavior are live
  in the emulator script.

### CLEAN / PROMOTED

- Map `0x08` Fairy Water route pocket evidence was fresh route/manual evidence,
  not old broad survey noise. The route repeatedly tried to enter the NE shop
  counter cells from the public west-side aisle:
  `(21,3)->LEFT` into `(20,3).east`, `(21,5)->LEFT` into `(20,5).east`,
  `(21,3)->UP` into `(21,2).south`, `(22,3)->UP` into `(22,2).south`,
  and `(22,3/4/5)->RIGHT` into `(23,3/4/5).west`.
- Promoted those approach blockers in `map_reader.lua`.
- `Fairy Water Merchant` is a moving Woman sprite behind the NE counter.
  `objects.lua` now labels live rows `(24,3)`, `(24,4)`, and `(24,5)` and
  routes each to the fixed public counter stand `(22,4)` facing east.
- Live prompt evidence at frame `02209` proved the trigger when the player was
  at `(22,4)` facing east and the target NPC was held at `(24,4)`.
- Later failed access after returning was explained by the same-row route model:
  the route targeted `(22,3)` when the merchant was on `(24,3)` and held the
  target at `(24,3)`, then TALK reported `There is no one there.` Controlled
  raw/TALK probes from `(22,3)`, `(22,4)`, `(22,5)`, and `(25,4)` did not open
  the prompt when the target was not held on `(24,4)`.
- Focused tests now cover the Fairy Water directional blockers and all three
  moving-row service records, the fixed counter stand, and explicit target
  hold coordinates.

### EARLIER INPUT LOCK CAPTURE

- During Fairy Water TALK testing, the emulator entered a funky state where
  Lua command polling stayed alive and `joy1=A` was visible for controlled
  12-frame `simulate_sequence:A` presses, but the game never opened the field
  command menu.
- Captured state showed no active command menu, submenu, dialogue, merchant
  screen, route, runtime blocks, or script error. `dw_script_error.log` had no
  fresh entry.
- `report_movement_state` showed `buttons=0x00` after failed `A` presses.
  Movement bytes around `0x003C/0x003D` varied during the bad state, but
  `reset_movement_state:funky_input_fix` did not restore `A` menu behavior.
- `recover_fceux_input.sh` briefly produced a clean `left_alt=false` marker,
  but FCEUX rel latched `LeftAlt`; controlled `A` still did not open the menu.
- `freeze_npcs` was released with `unfreeze_npcs`; the issue persisted.
- Added read-only diagnostic command `report_input_guard_state`, but FCEUX must
  manually reload `main.lua` before that command exists in the live script.
- Current merchant access failure is explained by the fixed-row trigger above;
  return to this input-lock thread only if `(22,4)` facing east with the target
  held at `(24,4)` still fails after reload.

### RESOLVED NEXT CHECK

- If Brecconary is revisited after reload, only spot-check the Fairy Water
  route and the `(0,15)` reachable-filter boundary behavior. Do not reopen
  broad blocker hunting unless a new gameplay route failure appears.

## 2026-06-22 Swamp Cave Door / Princess Route

### CLEAN / CURRENT LIVE STATE

- Started from Swamp Cave `0x15` at `(2,17)` after script liveness was
  confirmed with `launcher_probe:codex_swamp_start`.
- Runtime blockers were clear: `RUNTIME_BLOCKS map=0x15 none`.
- Current object was `Gwaelin Door`, door cell `(5,20)`, interaction stand
  `(5,21)` facing north.
- `debug_pathfind_to:5,21` planned `Path: 4 south, 3 east`.
- `auto_walk` reached the door stand `(5,21)` and faced north. The only route
  hiccup was `(2,20)->DOWN` timing retry, which immediately moved on seam
  retry and cleared itself. Do not promote that as a blocker.
- `OPEN` was executed through the command menu. `report_door_state` confirmed
  keys dropped to `5` and opened-door slot `0=(5,20)`.
- After the door opened, `debug_pathfind_to:4,14` planned `Path: 7 north,
  1 west`, proving the opened-door branch routes toward the logged Green
  Dragon / Princess area.
- The route through the opened door moved cleanly from `(5,21)` to `(5,20)`
  and `(5,19)`.

### RESOLVED / LIVE FINDINGS

- After the user defeated the random Scorpion and later the Green Dragon,
  field control resumed cleanly in Swamp Cave. Fresh state showed opened-door
  slot `0=(5,20)`, keys `5`, and no runtime blocks.
- The Green Dragon remains a fixed event encounter at `(4,14)`; after it is
  defeated, `(4,14)->DOWN` to `(4,15)` is passable again.
- Realm of Darkness' map clarified that Gwaelin is by the door-side room, not
  at the northern dragon pocket. The successful rescue route ended at
  `(5,19)`, the first tile north of the opened door cell `(5,20)`.
- From `(5,19)`, raw face north and `TALK` reaches Princess Gwaelin at
  `(5,18)`. Dialogue confirmed:
  `Thou art brave indeed to rescue me, Bill.`, then
  `I am Gwaelin, daughter of Lorik.`, then
  `Will thou take me to the castle?`
- Accepted the YES prompt. Follow-up dialogue included
  `Princess Gwaelin embraces thee.` and `I'm so happy!`; final state returned
  to field at `(5,19)` with `combat=0x09` and `quest=0x40`.
- Runtime blockers were clear after rescue. Several route-only blocked seams
  were observed while chasing the wrong northern pocket and returning to
  `(5,19)`; keep them as scratch evidence until same-origin verification is
  needed for a future route patch.

### 2026-06-22 Restored Route Blocker Cleanup

- User restored from the pre-rescue state and manually reloaded with the
  Princess special object live. Baseline at `map=0x15`, `(4,15)`, had
  `combat=0x08`, door slots empty, runtime blocks clear, and current object
  `Princess Gwaelin` with talk stand `(5,19)`.
- Direct planner route from `(4,15)` to Princess stand `(5,19)` initially
  tried `4 south, 1 east`, but walked autowalk proved the direct lower-right
  pocket is blocked until the door branch is used. Random encounters interrupted
  twice; combat cleared normally and field control resumed without script
  reload.
- Runtime-only blockers injected from walked route evidence:
  `add_blocked_edge:4,15,DOWN`,
  `add_blocked_edge:3,15,DOWN`,
  `add_blocked_edge:2,16,RIGHT`,
  `add_blocked_edge:2,17,RIGHT`,
  `add_blocked_edge:2,18,RIGHT`,
  `add_blocked_edge:2,19,RIGHT`,
  `add_blocked_edge:2,20,RIGHT`,
  `add_blocked_edge:3,21,UP`,
  `add_blocked_edge:4,21,UP`,
  `add_blocked_edge:5,15,DOWN`.
  `list_blocked_tiles` collapsed these to eight effective runtime cells:
  `(3,16)` dirs north/west, `(4,16)` north, `(5,16)` north, `(3,17)` west,
  `(3,18)` west, `(3,19)` west, `(3,20)` south/west, `(4,20)` south.
- With those runtime blockers active and the door still closed,
  `debug_pathfind_to:5,19` correctly returned `No path found`, while
  `debug_pathfind_to:5,21` planned `Path: 2 south, 3 east` from `(2,19)` to
  the Gwaelin Door stand.
- After the user manually opened the door, `DOOR_STATE keys=5 slots=0=(5,20)`
  at `(5,21)`. From there, `auto_walk:5,19` planned and walked `Path: 2 north`
  through opened door cell `(5,20)` to the Princess talk stand `(5,19)`.
  Final object readout: `Princess Gwaelin: 1 north, talk here`.
- Promotion status: keep these as runtime/live-evidence blockers for now.
  Permanent `map_reader.lua` promotion should be test-first and scoped to map
  `0x15`, with regression coverage that the closed-door side cannot route to
  `(5,19)` through the false lower pocket while the opened-door path
  `(5,21)->(5,20)->(5,19)` stays available when the door is open.

### 2026-06-22 South-Stairs Route Polish

- With the pre-rescue save restored, the Gwaelin door manually opened, and the
  Princess object still present at `(5,18)`, targeted `auto_walk_blocker:0,29`
  was used instead of a broad sweep.
- Baseline before the polish pass: `map=0x15`, field state, selected object
  `South Stairs Up` at `(0,29)`, and the restored-route runtime blockers from
  the Princess route cleanup active.
- Clean `AUTO_WALK_BLOCKER_FOUND` edges added as runtime blockers while
  pruning false routes toward `South Stairs Up`:
  `add_blocked_edge:4,21,DOWN`,
  `add_blocked_edge:3,21,DOWN`,
  `add_blocked_edge:2,21,DOWN`,
  `add_blocked_edge:2,21,LEFT`,
  `add_blocked_edge:5,21,DOWN`,
  `add_blocked_edge:2,20,LEFT`,
  `add_blocked_edge:2,19,LEFT`,
  `add_blocked_edge:2,18,LEFT`,
  `add_blocked_edge:2,17,LEFT`,
  `add_blocked_edge:2,16,LEFT`,
  `add_blocked_edge:2,15,LEFT`,
  `add_blocked_edge:2,15,UP`,
  `add_blocked_edge:3,15,UP`,
  `add_blocked_edge:4,14,LEFT`,
  `add_blocked_edge:2,13,LEFT`,
  `add_blocked_edge:3,13,DOWN`,
  `add_blocked_edge:2,12,LEFT`,
  `add_blocked_edge:2,11,LEFT`,
  `add_blocked_edge:2,10,LEFT`,
  `add_blocked_edge:2,9,LEFT`,
  `add_blocked_edge:1,8,DOWN`,
  `add_blocked_edge:1,25,RIGHT`.
- Contaminated/no-promote note: one `(3,21)->LEFT` retry was interrupted by a
  Ghost battle and was discarded. A later clean rerun moved through
  `(3,21)->(2,21)`, proving that edge passable.
- Clean route result: after the blockers above were active,
  `auto_walk_blocker:0,29` walked from `(1,25)` through `(1,26)`,
  `(2,26)`, `(3,26)`, `(3,27)`, `(3,28)`, `(3,29)`, `(2,29)`, `(1,29)` to
  `(0,29)`. Final readout: `OBJECT: South Stairs Up: here`, runtime block
  count `27`.
- Reverse-route polish from `(0,29)` back to Gwaelin door stand `(5,21)`
  found additional clean blockers:
  `add_blocked_edge:3,29,RIGHT`,
  `add_blocked_edge:3,26,RIGHT`,
  `add_blocked_edge:5,24,LEFT`, and
  `add_blocked_edge:3,25,LEFT`.
  The old mixed `(5,24)->LEFT` evidence is now clean enough to promote. A
  Scorpion interrupted one `(3,26)->UP` timing retry, so that edge was not
  promoted. After the reverse blockers were active, `auto_walk_blocker:5,21`
  reached `(5,21)` cleanly. That successful route also walked the standable
  middle strip `(2,16)`, `(2,17)`, and `(2,18)`, which should be modeled as
  passthroughs rather than blocked decode cells.
- Forward route after returning to the door stand stayed available when the
  Gwaelin door was open: live `debug_pathfind_to:0,29` from `(5,21)` planned
  `Path: 2 north, 1 west, 11 north, 4 west, 16 south, 3 east, 5 south, 3 west`.
- Promotion complete for the south-stairs / door-stand batch in
  `MAP_DIRECTIONAL_BLOCKS[0x15]` with focused regression assertions. Preserve
  the proven passable route to `(0,29)` and do not model untested neighboring
  faces.

## 2026-06-23 Swamp Cave North Exit Return Polish

- Started from the opened-door / Gwaelin branch side on map `0x15`, working the
  return route toward `North Exit to World Map` at `(0,0)`.
- Direct `probe_edge` checks confirmed these blocked approaches before
  promotion: `(4,17)->UP` into `(4,16).south`, `(5,17)->UP` into
  `(5,16).south`, `(4,17)->LEFT` into `(3,17).east`, `(4,18)->LEFT` into
  `(3,18).east`, `(4,19)->LEFT` into `(3,19).east`, `(4,19)->DOWN` into
  `(4,20).north`, `(5,20)->LEFT` into `(4,20).east`, `(4,13)->UP` into
  `(4,12).south`, and `(2,8)->UP` into `(2,7).south`.
- With the runtime overlay applied, `auto_walk_blocker:0,0` routed around the
  false shortcuts, crossed west at row 21, climbed through `(2,13)..(2,8)`,
  moved into the x=0 corridor at `(0,8)`, and reached `(0,0)`.
- Two Scorpion battles interrupted route execution; both cleared and were not
  treated as blocker evidence.
- Promoted the confirmed approach-only blockers into `map_reader.lua` and added
  focused `test_map_reader.lua` assertions. `lua test_map_reader.lua`,
  `lua test_pathfinder.lua`, and `git diff --check` pass.

## 2026-06-23 Swamp Cave Princess-to-South-Stairs Polish

- Manual route from the Princess side toward `South Stairs Up` reached
  `(0,24)`, where planner output wanted `(0,24)->RIGHT`.
- Same-origin `probe_edge:RIGHT` from `(0,24)` confirmed the open-preview seam
  blocked into `(1,24).west`. With runtime `add_blocked_edge:0,24,RIGHT`,
  `auto_walk_blocker:0,29` rerouted through `(0,25)`, `(1,25)`, `(1,26)`,
  `(2,26)`, `(3,26)`, `(3,29)`, and reached `(0,29)`.
- Promoted `(1,24).west` into `map_reader.lua` with a focused
  `test_map_reader.lua` assertion. No new combat interruption occurred during
  this route continuation.

## 2026-06-23 Swamp Cave South-Stairs-to-Princess Return Polish

- Working back toward Princess Gwaelin from the south-stairs/x=0 return side,
  manual walking reached `(2,12)`. Planner output wanted `(2,12)->RIGHT`
  toward the Princess stand `(5,19)`, but close-timed manual route readouts
  created early-twitch cancels rather than clean movement proof.
- Fresh baseline confirmed `POSITION: map=0x15(Swamp Cave) x=2 y=12`.
  Same-origin `probe_edge:RIGHT` from `(2,12)` reported `status=blocked`,
  `dest=(3,12)`, `reason=raw_hold_timeout`, with no permanent directional
  block, runtime block, or NPC block involved.
- Runtime `add_blocked_edge:2,12,RIGHT` added `(3,12).west`. With that single
  runtime block, `auto_walk_blocker:5,19` walked through `(2,13)`, `(4,13)`,
  `(4,15)`, `(2,15)..(2,21)`, `(5,21)`, opened door cell `(5,20)`, and reached
  the Princess talk stand `(5,19)`. Timing retries at `(3,13)->RIGHT`,
  `(4,14)->DOWN`, `(3,15)->LEFT`, `(2,20)->DOWN`, and `(4,21)->RIGHT` all
  subsequently moved and were not promoted.
- Promoted `(3,12).west` into `map_reader.lua` with a focused
  `test_map_reader.lua` assertion and a route guard that the post-battle door
  route does not retry `(2,12)->RIGHT`.
- Follow-up north-exit route work reached `(3,13)` and exposed `(3,13)->UP`.
  Same-origin `probe_edge:UP` reported `status=blocked`, `dest=(3,12)`,
  `reason=raw_hold_timeout`, with no NPC or approach-specific blocker active.
  Runtime `add_blocked_edge:3,13,UP` merged `(3,12).south` with the existing
  `(3,12).west` overlay, and `auto_walk_blocker:0,0` then reached the north
  exit `(0,0)`. Timing retries at `(3,13)->LEFT`, `(2,9)->UP`, and
  `(1,8)->LEFT` all subsequently moved and were not promoted.
  Promoted `(3,12).south` into `map_reader.lua` with a focused assertion and a
  route guard that the door-to-north route does not retry `(3,13)->UP`.
- Follow-up top-corridor return-to-Princess work from `(0,2)` exposed
  `(0,2)->RIGHT`. Same-origin `probe_edge:RIGHT` reported `status=blocked`,
  `dest=(1,2)`, `reason=raw_hold_timeout`, with no permanent/runtime/NPC
  blocker active. Runtime `add_blocked_edge:0,2,RIGHT` added `(1,2).west`.
  `auto_walk_blocker:5,19` then found `(0,7)->RIGHT`; same-origin
  `probe_edge:RIGHT` from `(0,7)` likewise blocked into `(1,7).west`.
  With both runtime blockers active, the route used `(0,8)->RIGHT` as the
  first open re-entry and reached the Princess stand `(5,19)`. A Scorpion
  battle interrupted once at `(2,16)`, then cleared; timing retries around
  `(0,6)->DOWN`, `(1,8)->RIGHT`, `(2,12)->DOWN`, `(3,13)->RIGHT`,
  `(4,14)->DOWN`, `(3,15)->LEFT`, `(2,16)->DOWN`, `(2,20)->DOWN`, and
  `(4,21)->RIGHT` all moved on retry and were not promoted.
  Promoted `(1,2).west` and `(1,7).west` with assertions and a
  north-exit-to-Princess route guard.
- Follow-up top-corridor return-to-Princess work from `(0,5)` exposed a tight
  three-sided pocket around `(1,6)`. Same-origin probes confirmed
  `(0,5)->RIGHT` into `(1,5).west`, `(1,6)->RIGHT` into `(2,6).west`,
  `(1,6)->DOWN` into `(1,7).north`, and `(1,6)->UP` into `(1,5).south` as
  blocked-despite-open-preview seams with no NPC or approach-runtime blocker
  contamination. With all four runtime blockers active, `auto_walk_blocker:5,19`
  escaped through `(0,8)->RIGHT`, climbed/descended the known `(2,8)..(2,21)`
  route, and reached `(5,19)` after one Druin battle interrupted at `(5,21)`
  and cleared. Timing retries at `(2,12)->DOWN`, `(3,13)->RIGHT`,
  `(4,14)->DOWN`, `(3,15)->LEFT`, `(2,20)->DOWN`, and `(4,21)->RIGHT` all
  moved on retry and were not promoted. Promoted `(1,5).west/south`,
  `(2,6).west`, and `(1,7).north` with assertions and north-exit-to-Princess
  route guards.
- Follow-up noisy-route work from `(3,4)` started with the user's
  `(3,4)->DOWN` report. Same-origin probes confirmed `(3,4)->DOWN` into
  `(3,5).north`, `(3,4)->RIGHT` into `(4,4).west`, `(2,5)->DOWN` into
  `(2,6).north`, `(2,5)->RIGHT` into `(3,5).west`, `(2,4)->UP` into
  `(2,3).south`, `(4,3)->DOWN` into `(4,4).north`, and `(5,13)->DOWN` into
  `(5,14).north`. With those runtime blockers active, `auto_walk_blocker:5,19`
  escaped through `(3,3)`, `(4,3)`, `(5,3)`, the east column, then back through
  the known middle strip and reached `(5,19)`. Magician/Druin battles
  interrupted at `(2,17)`, `(2,18)`, and `(5,20)` and cleared under the
  30-second combat-watch rule. Interrupted down/up steps at those battle starts
  moved after combat and were not promoted. Promoted the seven confirmed
  blockers with assertions and a `(3,4)`-to-Princess route guard.

## 2026-06-23 Swamp Cave Entrance-to-Entrance Pass Polish

- Started from `POSITION: map=0x15(Swamp Cave) x=1 y=23` with target
  `South Stairs Up` `(0,29)` and no runtime blockers active.
- Same-origin `probe_edge:DOWN` from `(1,23)` reported `status=blocked`,
  `dest=(1,24)`, `reason=raw_hold_timeout`, final position `(1,23)`, no NPC
  block, no runtime block, and no approach-specific static block. The
  pre-existing `(1,24)` entry already had other blocked faces, so this promotes
  only `(1,24).north`.
- Runtime `add_blocked_edge:1,23,DOWN` added `(1,24).north`.
  `auto_walk_blocker:0,29` then planned `2 east, 6 south, 3 west`, moved
  through `(2,23)`, `(3,23)..(3,29)`, and reached `(0,29)` after resuming from
  a Ghost battle at `(1,29)`.
- Timing retries at `(2,23)->RIGHT`, `(3,28)->DOWN`, and the battle-interrupted
  `(1,29)->LEFT` were not promoted. The final `(1,29)->LEFT` moved cleanly
  after combat cleared.
- Promoted `(1,24).north` into `map_reader.lua` with a focused assertion and a
  north-exit-to-south-stairs route guard.

### NEXT CHECK

- The immediate gameplay next step is escorting Gwaelin back to Tantegel
  Castle. Object navigation now exposes `Princess Gwaelin` as a Swamp Cave-only
  NPC at `(5,18)` with interaction stand `(5,19)` facing north, and hides that
  target once the rescue/carry bit is set (`combat` changed from `0x08` to
  `0x09` after rescue).

The 2026-06-19 through 2026-06-21 `sweep_walk` break-in and hostile-area
validation has wrapped. Detailed live evidence was archived here:

- `handoff_archive/HANDOFF_2026-06-21_sweep_walk_break_in_scratchpad.md`
- `handoff_archive/HANDOFF_2026-06-19_sweep_walk_break_in_handoff.md`

Use `session_handoff.md`, `PLAYTESTING.md`, and `PROJECT_MEMORY.md` for
durable current state.

## Sweep Walk Break-In Summary

- `sweep_walk` is now the preferred normal-movement sweep command. It writes
  `sweep_status.txt` while active and final `sweep_walk_MM_runNNN.json`,
  `sweep_walk_MM_runNNN_summary.txt`, and `dw_crawl_MM.txt` review output on
  finish. The generated status/JSON/summary files are ignored.
- Garinham and Tantegel live runs covered larger safe areas without trusted
  teleport-backed blocker exports. Remaining noisy observations were kept in
  review-only timing-suspect, unstable-origin, door-frontier, boundary, or
  dynamic buckets unless same-origin walked verification supported a map patch.
- Swamp Cave hostile validation proved the battle-interruption exit path:
  random encounters stop the active sweep with `reason=battle_interrupted` and
  `source_classification=battle_interrupted`. For now, resume manually by
  starting a new sweep after combat returns to field control.
- Resume-from-JSON support is intentionally deferred. Field use should prove a
  real need before adding pause/resume complexity.
- User-observed `stop_sweep` behavior is good enough for this cleanup pass; the
  final live check was not repeated.

## Durable Bugs Fixed During Break-In

- Debug teleports now synchronize logical player coordinates with screen and
  sprite-position RAM through `teleport_state.lua`, reducing split-state
  failures after `teleport_to`.
- `speech_bridge.py` dispatches speech on a worker so a blocking screen reader
  call cannot stop command-file polling.
- Field/menu/dialogue scanning now suppresses scrolling status/name artifacts
  without relying on hard-coded hero names such as Bill or Ivy.
- `auto_step.lua` force-releases script-owned D-pad state on live-direction
  cancellation and map-crawl step cleanup paths, reducing sticky-input hangs.
- `map_crawler.lua` no longer resets movement RAM during sweep step completion
  or settle cleanup. Hostile Swamp Cave reruns after this change kept player
  stats clean across encounter interruptions.

## Next Work

- Local verification and CodeRabbit review passed on the cleaned diff.
- Resume normal gameplay/playtesting from the current save.
- Treat future sweep JSON as review evidence only. Promote map data only after
  walked same-origin confirmation or similarly strong live evidence.

For the next live map task, start a new dated section here with:

- current map id, floor, and player position
- exact target/object being investigated
- runtime blockers injected during the session
- evidence that is still uncertain or should not be promoted
- evidence that has been promoted to permanent map data

## 2026-06-24 Garinham Door / Route Triage

- Baseline resumed on Garinham `0x09`, with door RAM empty and
  `RUNTIME_BLOCKS map=0x09 none`.
- Door filter exposes exactly the two confirmed town doors:
  `Locked Building Door` at door cell `(4,6)`, interaction stand `(4,7)`
  facing north, and `Grave Route Door` at door cell `(17,10)`, interaction
  stand `(17,9)` facing south. `pathability_filter:reachable` reported no
  door objects; `pathability_filter:unreachable` reported those two.
- Skipping NPCs from the entrance and from the lower east corridor still
  produced no path to `(17,9)`, `(4,7)`, or the grave stairs `(19,0)`.
- The two lower hidden-bridge candidates were rechecked with walked origins:
  `verify_walked_edge:18,11,UP` blocked into `(18,10)` and
  `verify_walked_edge:19,11,UP` blocked into `(19,10)`, both with
  `reason=raw_hold_timeout`, no NPC block, no runtime block, and no existing
  directional block. Do not promote either cell as a passthrough from this
  evidence.
- Public-route polish:
  - From lower east corridor `(19,11)`, planner and live autowalk reached the
    exit stand `(1,14)`.
  - From `(1,14)`, live object browsing showed the Tool Merchant interaction
    stand is `(3,11)` for the current NPC position; the earlier coordinate
    probe to `(4,10)` was the wrong stand for this live object. Planner and
    `auto_walk_blocker:3,11` reached the Tool Merchant stand cleanly.
  - From Tool Merchant `(3,11)`, planner routes existed to Weapons `(10,16)`,
    Inn `(15,15)`, and exit `(1,14)`. `auto_walk_blocker:10,16` reached the
    Weapons stand cleanly.
  - First `auto_walk_blocker:15,15` from Weapons hit a live NPC at
    `(15,13)` from `(14,13)->RIGHT`; log marked `npc_blocked=true` and emitted
    no patch command. Retrying after the NPC moved reached the Inn stand.
  - `auto_walk_blocker:1,14` from the Inn stand reached the exit stand cleanly.
- Inn clutter follow-up:
  - User-reported blocker at `(13,16)->RIGHT`: two same-origin `probe_edge`
    checks blocked into `(14,16).west` with raw-hold timeouts and no NPC or
    runtime contamination. Runtime `add_blocked_edge:13,16,RIGHT` changed the
    planner away from that edge.
  - The reroute then exposed `(13,17)->RIGHT`: `auto_walk_blocker:15,15`
    reported a real seam-retry block, and same-origin `probe_edge:RIGHT`
    confirmed `(14,17).west` with no NPC or runtime contamination.
  - With runtime blockers active for `(14,16).west` and `(14,17).west`,
    `auto_walk_blocker:15,15` reached the Inn stand. Both edges were promoted
    to `map_reader.lua` with regression assertions in `test_map_reader.lua`.
- Grave Route Door follow-up:
  - Current object routing from public-side `(14,10)` targeted interaction
    stand `(17,9)` and reported `No path found` even with NPCs skipped.
    Inspection showed `(17,10)` is the closed door cell, `(17,9)` is walkable
    but unreachable from the public side, and `(17,11)` is walkable/reachable.
  - `verify_door_stand:17,11,UP` routed from `(14,10)` through `(14,11)` and
    row 11 to `(17,11)`, then logged `DOOR_VERIFY_READY` with
    `expected_door=(17,10)`, `keys_before=5`, and `baseline_slots=none`. The
    pending verifier was cancelled without spending a key.
  - Root cause: `objects.lua` preserved only the north-side grave-route OPEN
    stand `(17,9)` facing south. It now keeps that primary stand and adds the
    public-side stand `(17,11)` facing north via `interaction_points`, so the
    existing route-manager alternate-interaction logic can select the reachable
    side after a full script reload.
- Actual grave entrance follow-up:
  - User verified the Grave Route Door route now opens the door and leads to
    the appropriate stand. With the door open, the target pocket around
    `(18,0)`, `(18,1)`, `(19,0)`, and `(19,1)` inspected as internally
    walkable/passable, but both normal and skip-NPC pathfinding still reported
    no route from the door-side component.
  - `debug_route_frontier_skip_npcs:18,1,32` from `(18,7)` showed the same
    bridge family separating the target side: hidden candidates
    `(13,1)->DOWN` and `(19,11)->UP`, plus row-7/right-side directional gates
    such as `(13,1)->RIGHT`, `(18,7)->UP`, `(18,7)->RIGHT`,
    `(18,8)->RIGHT`, and `(18,9)->RIGHT`.
  - Fresh walked-origin checks confirmed blocked edges for `(13,1)->DOWN`,
    `(13,1)->RIGHT`, `(18,7)->RIGHT`, and `(18,7)->UP`. These agree with the
    existing model and do not identify a new promotable passthrough.
  - Closeout probe: script alive at position `(18,7)`, with
    `RUNTIME_BLOCKS map=0x09 none`, `PATH_STATE target=nil`, and runtime count
    0.
  - UNRESOLVED: no clean route to the actual grave entrance/stairs was found
    from the public/door side. Remaining useful checks are the nearby frontier
    gates `(18,8)->RIGHT`, `(18,9)->RIGHT`, `(17,7)->UP`, `(16,7)->UP`, and
    the lower hidden candidate `(19,11)->UP` if this path should continue.
  - User follow-up probed the four nearby frontier gates and reported all were
    blockers. The log confirmed clean blocks for `(18,9)->RIGHT`,
    `(17,7)->UP`, and `(16,7)->UP`; `(18,8)->RIGHT` was already refused by the
    model as directional-blocked.
  - Fresh frontier from live `(19,11)` to the stairs `(19,0)`, skipping NPCs,
    still reported `No path found` and only one bridge-to-target candidate:
    hidden bridge `(19,11)->UP` through `(19,10)`.
  - `(19,11)->UP` remains blocked under proper `probe_edge:up` evidence. A
    preceding manual-tap log briefly marked `(19,10)` passable immediately
    after `teleport_to:19,11`; treat that as teleport-seeded/movement-state
    fallout and DO NOT PROMOTE it as a passthrough.
  - Follow-up user/manual route check found the real bypass on the top edge:
    `(12,0)->RIGHT` entered `(13,0)`, `(13,0)->RIGHT` entered `(14,0)`, and
    `(14,0)->LEFT` returned to `(13,0)`. Fresh inspection showed the live
    source still treated `(13,0)` and `(14,0)` as `engine_boundary`, so
    `debug_pathfind_to_skip_npcs:19,0` from `(13,0)` stayed `No path found`
    despite the walked route.
  - Promoted `(13,0)` and `(14,0)` as Garinham `MAP_PASSTHROUGH_CELLS[0x09]`.
    Regression coverage now asserts both cells report `passthrough` and that
    pathfinder can route from `(13,0)` across `(14,0)` toward `(19,0)`. Leave
    the row-1 `(14,1).east/west` directional blockers in place; the valid route
    bypasses them along row 0. Reload `main.lua` in FCEUX before judging the
    live planner against this source fix.
  - Follow-up grave-stairs polishing after reload started with the
    user-reported `(9,3)->UP` blocker. `auto_walk_blocker:19,0` plus
    same-origin `probe_edge` confirmed `(8,3)->UP`, `(9,3)->UP`,
    `(10,3)->UP`, `(7,3)->UP`, `(6,3)->UP`, `(6,3)->DOWN`,
    `(7,4)->LEFT`, `(7,5)->LEFT`, `(7,6)->LEFT`, `(2,7)->UP`, and
    `(14,0)->DOWN` as real raw-hold timeouts with no NPC contamination.
  - With those false shortcuts closed at runtime, the route revealed the actual
    top-lane descent: `(14,0)->RIGHT` moved into `(15,0)` despite the model's
    `engine_boundary`, `(15,0)->RIGHT` into `(16,0)` blocked, and
    `(15,0)->DOWN` moved into `(15,1)`. From `(15,1)`, live
    `auto_walk_blocker:19,0` reached `(19,0)` through row 1. Promoted `(15,0)`
    as a Garinham passthrough, added the corresponding approach-only blockers,
    and extended regression coverage to require the
    `(13,0)->(14,0)->(15,0)->(15,1)` route shape.
  - After source reload, the user verified the route to stairs and found one
    remaining noisy upper-entry cut at `(6,7)->UP`. Same-origin
    `probe_edge:UP` confirmed `(6,6).south` blocked with raw-hold timeout and
    no NPC/runtime contamination. With runtime `add_blocked_edge:6,7,UP`, the
    route advanced to `(3,7)->UP`; same-origin raw probe confirmed
    `(3,6).south` blocked. With both runtime blocks active,
    `auto_walk_blocker:19,0` reached `(19,0)` through the top-lane descent.
    Promoted `(6,6).south` and `(3,6).south` with focused assertions.
  - Next user report named `(3,2)->WEST`, but live inspection showed that exact
    edge was already modeled as `(2,2).east`. The current live position and
    previous probe evidence were for adjacent `(3,1)->LEFT` into `(2,1).east`:
    route retry plus same-origin `probe_edge:left` both blocked with no
    NPC/runtime contamination. Runtime `add_blocked_edge:3,1,LEFT` preserved
    the route from `(3,1)` to the grave stairs, which reached `(19,0)`, but
    collapsed the return route from `(3,1)` to the world-map exit into a
    `No path found` with the stationary grave-door guard boundary. Promoted
    `(2,1).east`; continue return-side cleanup from fresh live evidence.
  - Return route from the grave stairs `(19,0)` to the world-map exit `(1,14)`
    can appear and disappear under live NPC planning. Fresh post-reload log
    samples alternated between 66-step routes and `No path found` with
    `npc_mode=live_npcs`, `npc_blocks=14`, and no runtime blocks. Controlled
    same-frame comparison at frame `14760` confirmed the cause: normal
    `debug_pathfind_to:1,14` returned `No path found [no_path]`, while
    `debug_pathfind_to_park_npcs:1,14` parked 15 slots and immediately found
    the stable 66-step route. Treat this as moving/stale NPC contamination,
    not permanent map geometry.
  - Follow-up return-route blocker from `(17,10)->LEFT` is clean geometry:
    `auto_walk_blocker` found `(16,10).east`, then same-origin `probe_edge:LEFT`
    from `(17,10)` blocked with `reason=raw_hold_timeout`, no NPC/runtime
    blocker, and open-looking floor. Promoted `(16,10).east` in
    `map_reader.lua` with a focused map-reader assertion. With runtime
    `add_blocked_edge:17,10,LEFT`, the route detoured down to row 14 and
    reached the exit stand `(1,14)`. Intervening stops around `(10,13)` /
    `(1,14)` were NPC timing/occupancy and should not be promoted.
  - Next grave-stairs pass started at `(5,7)->UP`: `auto_walk_blocker`
    seam retry found `(5,6).south`, then same-origin `probe_edge:UP` blocked
    with `reason=raw_hold_timeout`, no NPC/runtime/static blocker, and an
    open-looking floor preview. Runtime `add_blocked_edge:5,7,UP` rerouted west
    to the x=1 column, climbed back to row 1/top lane, and reached the grave
    stairs `(19,0)`. Promoted `(5,6).south` with a focused assertion.
  - Grave-stairs-to-Inn route cleanup started with `(1,4)->RIGHT`.
    `auto_walk_blocker` found `(2,4).west`, and same-origin
    `probe_edge:RIGHT` from `(1,4)` confirmed `reason=raw_hold_timeout`, no
    NPC/runtime blocker, and an open-looking tile preview. Runtime
    `add_blocked_edge:1,4,RIGHT` rerouted down the x=1 corridor, crossed row 8,
    descended through the grave-door/Inn approach, and reached the Inn stand
    `(15,15)`. Promoted `(2,4).west` with a focused assertion.

## 2026-06-25 Tantegel Sun Shrine Return Route

- Working from Sun Shrine stairs back to `Stairs Up to Tantegel Castle Throne
  Room` on map `0x04`.
- CLEAN / PROMOTED CANDIDATES: route plus same-origin `probe_edge:left`
  confirmed `(28,9)->LEFT`, `(28,10)->LEFT`, `(28,12)->LEFT`,
  `(28,13)->LEFT`, `(28,14)->LEFT`, `(28,15)->LEFT`, and `(28,16)->LEFT`
  as blocked with raw-hold timeout and no NPC/runtime contamination. These are
  east-approach blocks into `(27,9)`, `(27,10)`, `(27,12)`, `(27,13)`,
  `(27,14)`, `(27,15)`, and `(27,16)`. Follow-up continued the same pattern
  through `(28,17)->LEFT`, `(28,18)->LEFT`, and `(28,19)->LEFT`, confirming
  east-approach blocks into `(27,17)`, `(27,18)`, and `(27,19)`.
- DO NOT PROMOTE: intervening vertical moves down the x=28 lane repeatedly
  looked sticky on first hold but moved on seam retry; keep those vertical
  seams open.
- LIVE RESULT: with runtime east-approach blockers active for `(27,9)`,
  `(27,10)`, and `(27,12)..(27,19)`, `auto_walk_blocker:7,7` reached the
  throne-room stairs from `(28,19)`, and `auto_walk_blocker:28,19` returned to
  the Sun Shrine-side stand. `(6,17)` east/west twitches recovered on seam
  retry in both directions and remain timing noise, not map blockers.

## 2026-06-25 Sun Shrine Chest / Old Man Cleanup

- Map `0x0C` live baseline: started at `Stairs to Tantegel Castle` `(0,4)`
  with no runtime blockers. Object browsing only exposed the stairs from the
  west-edge tile, so cleanup used direct coordinate routing to chest `(4,5)`
  and old-man stand `(4,7)`.
- CLEAN / PROMOTED CANDIDATES: route retries plus same-origin probes confirmed
  `(2,4)->RIGHT`, `(2,5)->RIGHT`, and `(2,6)->RIGHT` block into
  `(3,4).west`, `(3,5).west`, and `(3,6).west`; route/probe also confirmed
  `(3,7)->UP` blocks into `(3,6).south`.
- DO NOT PROMOTE: `(2,4)->DOWN`, `(2,5)->DOWN`, `(2,6)->DOWN`, and
  `(4,5)->RIGHT` were retry-passable and should stay open.
- LIVE RESULT: with runtime blockers active, `auto_walk_blocker:4,5` reached
  the chest, `auto_walk_blocker:4,7` reached the old-man stand from the stairs,
  and `auto_walk_blocker:0,4` returned to the Tantegel stairs. Final position
  was map `0x0C` at `(0,4)`.

## 2026-06-25 Sun Shrine Follow-Up Route Polish

- Follow-up route from the stairs was still bouncy after the first geometry
  change. Fresh route retries plus same-origin probes confirmed additional
  false cuts: `(2,3)->RIGHT` into `(3,3).west`, `(3,2)->DOWN` into
  `(3,3).north`, `(4,2)->DOWN` into `(4,3).north`, `(5,2)->DOWN` into
  `(5,3).north`, `(6,2)->DOWN` into `(6,3).north`, and the right-wall
  entries `(7,3..6)->LEFT` into `(6,3..6).east`.
- DO NOT PROMOTE: `(2,2)->DOWN` was rechecked from a normal-walked origin and
  moved through `(2,3)`, ending at `(2,4)` during the probe hold. The x=2
  vertical lane and row-7 bypass remain the intended open route.
- LIVE RESULT: with the runtime overlay active, fresh
  `auto_walk_blocker:4,7` from `(0,4)` reached the old-man stand through
  `(2,4)->(2,7)->(4,7)`, and `auto_walk_blocker:0,4` returned to the stairs.

## 2026-06-25 Sun Shrine Chest Return Polish

- CLEAN / PROMOTED CANDIDATES: starting from chest cell `(4,5)`, the return
  route to `Stairs to Tantegel Castle` first tried `(4,5)->LEFT`; route failure
  plus same-origin `probe_edge:left` confirmed `(3,5).east` with raw-hold
  timeout and no NPC/runtime contamination. Follow-up reroutes confirmed
  `(3,4).east` from `(4,4)->LEFT`, `(4,3).south` from `(4,4)->UP`,
  `(5,3).south` from `(5,4)->UP`, `(6,4).west` from `(5,4)->RIGHT`, and
  `(6,5).west` from `(5,5)->RIGHT` using the same route-plus-probe pattern.
- DO NOT PROMOTE: `(4,5)->UP` into `(4,4).south` and `(4,4)->RIGHT` into
  `(5,4).west` both moved on seam retry and should stay open.
- LIVE RESULT: with runtime blockers for `(3,5).east`, `(3,4).east`,
  `(4,3).south`, `(5,3).south`, `(6,4).west`, and `(6,5).west`,
  `auto_walk_blocker:0,4` returned from the chest-side pocket to the stairs
  via `(5,5)->(5,7)->(1,7)->(1,4)->(0,4)`.

## 2026-06-26 Rain Shrine Staff Return Route

- CLEAN / PROMOTED CANDIDATES: starting from the Staff of Rain side on map
  `0x0D`, route failure plus same-origin `probe_edge:up` from `(5,4)`
  confirmed `(5,3).south`. After runtime patching that edge, the reroute found
  `(8,8)->DOWN`; same-origin `probe_edge:down` confirmed `(8,9).north`. Both
  blocked with raw-hold timeout, no NPC blocker, and no pre-existing runtime
  blocker.
- DO NOT PROMOTE: the route successfully walked down the x=8 lane through
  `(8,5)..(8,8)`, then after the second patch walked west across row 8 through
  `(7,8)`, `(6,8)`, `(5,8)`, `(4,8)` and down through `(4,9).north`. Keep
  those seams open.
- LIVE RESULT: with runtime blockers for `(5,3).south` and `(8,9).north`,
  `auto_walk_blocker:4,9` reached the exit tile at `(4,9)`.

## 2026-06-26 Kol Tool Merchant Trigger Hunt

- LIVE BASELINE: map `0x07` / Kol, both known magic-key doors already open:
  `(7,12)` and `(1,14)`. Tool Merchant NPC remained at `(14,21)`. The
  selected-teleport stand `(12,21)` is still a valid shop trigger but not
  reachable from the public route graph.
- CLEAN / CONFIRMED EXISTING GEOMETRY: direct same-origin probes confirmed the
  frontier bridges into the tool-counter component are sealed in live play:
  `(12,18)->DOWN`, `(11,19)->DOWN`, `(11,19)->RIGHT`, `(13,18)->DOWN`,
  `(14,18)->DOWN`, `(15,18)->DOWN`, `(16,18)->DOWN`, `(11,18)->LEFT`,
  `(11,19)->LEFT`, `(17,19)->LEFT`, and `(17,20)->LEFT` all blocked with
  raw-hold timeout. Earlier same-state route work had already confirmed
  `(17,21)->LEFT` and `(17,22)->LEFT`.
- DOOR THEORY CHECKED: `verify_door_stand:17,21,LEFT` plus manual DOOR logged
  "There is no door here"; `verify_door_after` reported expected door
  `(16,21)` absent, keys `4 -> 4`, door slots unchanged. Repeated from
  `(17,22)` facing left for expected door `(16,22)` with the same no-door,
  no-key-delta result.
- TALK CHECKED: `(17,20)` facing west returned "There is no one there" and did
  not activate the merchant detector.
- LIVE RESULT: `debug_route_frontier_skip_npcs:12,21` still reports
  `hidden_bridge_candidates=0`; all direct bridge-to-target candidates are
  accounted for. No new permanent map data was discovered in this pass. The
  current open question is whether Kol's item shop has a different public
  trigger than the selected-teleport stand, or whether this service should stay
  unrouteable/flagged until a manual trigger is found.

### Follow-Up: West-Side Throat Found

- LIVE PROOF: the user found that walking `(1,16)->DOWN` reaches `(1,17)` and
  immediately revives the known Tool Merchant route. Fresh logs showed
  `(1,16)` itself is ordinary walkable floor, while `(1,17)` ROM-decodes as
  tile-0/non-walkable. Manual movement repeatedly crossed `(1,16)<->(1,17)`,
  and route planning from `(1,17)` found the Tool Merchant route again.
- CLEAN / PROMOTED: `map_reader.lua` now models only `(1,17)` as a Kol
  passthrough. `(1,18)` inspected as ordinary walkable floor; no nearby
  directional blockers were removed.
- RELOAD NEEDED: FCEUX needs a manual `main.lua` reload before live
  `debug_pathfind_to_skip_npcs:12,21` or Tool Merchant autowalk will reflect
  the source fix from `(1,16)`.

### Follow-Up: `(1,19)` Pocket Closed

- LIVE PROOF: after the script reload picked up the `(1,17)` passthrough, the
  Tool Merchant route next tried the standable pocket at `(1,19)`. Route
  failure plus same-origin probes confirmed `(1,19)->RIGHT` into `(2,19).west`,
  `(1,19)->DOWN` into `(1,20).north`, and `(1,19)->UP` into `(1,18).south`
  all block with raw-hold timeout and no NPC involvement. `(1,19)->LEFT`
  already fails as the west engine boundary.
- CLEAN / PROMOTED: `map_reader.lua` now models only those three false exits
  as Kol directional blockers. The destination cells remain open from
  unproven/opposite approaches.
- RELOAD NEEDED: FCEUX needs another manual `main.lua` reload before the live
  planner reflects the new pocket blockers.
- DO NOT PROMOTE: after teleporting back to `(1,16)` only to escape the
  confirmed `(1,19)` dead pocket, `auto_walk_blocker:12,21` reported
  `(1,16)->DOWN` into `(1,17).north` as blocked. Follow-up raw/sequence input
  from the same seed also failed to move, and a one-step autowalk to ordinary
  open floor `(2,16)` falsely reported `(2,16).west` blocked. Treat those
  `(1,16)` failures as contaminated post-teleport/input-state evidence. Next
  clean route check should start after a manual reload/restore or after the
  player has manually re-established normal movement at the west-side throat.

### Follow-Up: Entrance-Side Connector Found

- LIVE BASELINE: after a clean script/game restore at Kol `(19,23)`, both
  known Magic Key doors were open in RAM: door slots `(7,12)` and `(1,14)`.
  Runtime blockers were empty. Normal and skip-NPC pathfinding from the town
  entrance could not reach `(1,16)` or Tool Merchant stand `(12,21)`.
- LIVE PROOF: `debug_route_frontier_skip_npcs:1,16,20` and
  `debug_route_frontier_skip_npcs:12,21,30` both reported three hidden bridge
  candidates: `(5,13)->DOWN` into `(5,14)`, `(6,13)->DOWN` into `(6,14)`, and
  `(7,13)->DOWN` into `(7,14)`. All three candidate cells decode as tile-0.
  A normal autowalk from `(19,23)` reached `(5,13)`, and same-origin
  `probe_edge:DOWN` moved through `(5,14)` and settled at `(5,15)`, logging
  `moved_through_modeled_block`. From `(5,15)`, skip-NPC paths exist to
  `(1,16)` and `(12,21)`.
- CLEAN / PROMOTED: `map_reader.lua` now models only `(5,14)` as the
  entrance-side Kol passthrough. `(6,14)` and `(7,14)` remain unmodeled until
  they get their own live movement proof.
- RELOAD NEEDED: FCEUX needs a manual `main.lua` reload before entrance-side
  Tool Merchant autowalk can use `(5,14)`.

### Dialogue Filter Detour

- LIVE BUG: Kol's scrolling/status layout exposed a stale lower-window fragment
  `ll` while the field UI was otherwise clear. Diagnostics showed
  `MENU_STATE lower_len=2`, `UPPER_STATE lower="ll"`, and
  `INPUT_GUARD_STATE dialogue_len=0 unavailable_reason=nil`. Starting an edge
  probe then let the fragment re-enter `PREV.dialogue`, causing
  `EDGE_PROBE_RESULT status=interrupted reason=Wait for dialogue to finish`.
  The same shared guard can block object/readout hotkeys such as `J/K/L/O`
  until the stale fragment clears.
- SOURCE FIX: `lower_status_noise_suppression_active()` now suppresses known
  passive status/name fragments whenever the game is in field play and no
  modal field UI is active, instead of limiting that suppression to passive
  idle, autowalk, or map-crawl windows.
- FOLLOW-UP SOURCE FIX: the command-menu lower-dialogue gate now applies the
  same passive status/name fragment filter before deciding whether lower
  dialogue should block menu speech. Live bad state had raw/cached command menu
  open with `lower="ll"`, `active_block=false`, and `cmd_confirmed=false`,
  which cleared the live command-menu session and made SPELL/`J/K/L/O` style
  controls behave as though dialogue were still active.
- FOLLOW-UP SOURCE FIX: after a restore to the Kol entrance, opening the
  command menu still announced standalone `Bill`. Logs showed
  `EVENT: command menu opened`, then `PREV.dialogue_len=4` and
  `EVENT: dialogue: Bill` while `menu_active=true`. The status/name fragment
  suppression now also runs during the field command menu; it still skips
  submenus, Yes/No prompts, merchants, battle, and non-field states. Real
  command responses are preserved because they do not match
  `text.is_passive_field_status_noise()`.
- FOLLOW-UP SOURCE FIX: after that source reload, the command menu stopped
  speaking the hero name, but the same standalone `Bill` fragment could migrate
  to the SPELL submenu. The suppression guard now also runs while
  `submenu_mode == "SPELL"` because spell-list speech comes from cursor/RAM
  state; STATUS, ITEM, Yes/No, merchant, battle, and non-field screens remain
  excluded from this passive-fragment suppression.
- FOLLOW-UP SOURCE FIX: held ITEM menu browsing then exposed the merchant
  parser claiming the inventory list. Recent logs showed `MERCHANT_SELECT`
  lines for held inventory entries such as `Fairy Flute`, `Wings`,
  `Gwaelin's Love`, and bogus prices like `Magic Armor. 4 gold.` before ITEM
  submenu ownership could stabilize. `merchant.lua` now rejects offer-list
  detection when a full field-command backdrop is visible behind the item list,
  and when only status rows plus unpriced inventory entries are visible after
  scroll/base context selection, while preserving actual shop offer screens and
  Buy/Sell prompts.
- FOLLOW-UP SOURCE FIX: after another reload/test, the log still showed
  `MERCHANT_SELECT` at frames `01488`, `01643`, and `01712`, but no
  `CMD_ITEM_FIRE`/`ITEM_CURSOR` ownership. Root cause is order as well as
  parser shape: `check_command_menu()` let merchant detection return before a
  confirmed command-ITEM-to-item-list cursor jump could set
  `submenu_mode = "ITEM"`. Confirmed ITEM entry now runs before merchant
  override and clears stale merchant state.
- FOLLOW-UP SOURCE FIX: after a full emulator restart, held ITEM browsing still
  spoke as merchant. Fresh logs showed command-menu input reaching ITEM, then
  `MERCHANT_SELECT` at frame `00913` with no `CMD_ITEM_FIRE`; a live
  `report_menu_state` while the item list was open showed `submenu=nil` and
  `merchant_active=true`. The cursor-jump detector is too late for this screen,
  so `check_command_menu()` now handles the direct A press on confirmed
  ITEM(1,1) before merchant detection, sets `submenu_mode = "ITEM"`, and keeps
  the older cursor-jump detector as a fallback.
- FOLLOW-UP SOURCE FIX: after the direct ITEM ownership fix, merchant speech was
  gone but the generic lower dialogue reader still announced visible inventory
  rows such as `Silver Harp Cursed Belt Gwaelin's Love Torch`. Live state while
  the menu was open showed `submenu=ITEM`, `merchant_active=false`, and
  `PREV.dialogue_len=25`. `check_dialogue()` now absorbs STATUS, ITEM, and
  SPELL submenu windows because those screens are spoken from cursor/RAM state,
  not generic dialogue.
- LIVE VERIFICATION: after the ITEM/menu fixes were manually reloaded, the user
  verified command responses and submenus were reading normally. Fresh logs
  showed no new `MERCHANT_SELECT` pollution while browsing command responses.
- FOLLOW-UP SOURCE FIX: during Kol wrap-up, the user attempted `U` autowalk
  while the field command menu was open. Logs showed
  `AUTO_WALK_HOTKEY_RELEASE_START` at frame `01195`, but
  `EVENT: command menu closed` did not occur until frame `01860`, so the
  route queued before the menu guard caught up. Root cause: the main loop runs
  `hotkeys.update()` before `check_command_menu()`, and
  `DW_QOL_STATE.command_menu_blocks_field_movement()` only trusted
  `CMD.menu_live`; a fresh visible command menu could therefore slip through
  for that early frame. `main.lua` now also blocks raw `menu.is_open()` when a
  visible cursor tile is present, preserving the older stale-COMMAND protection
  because raw text alone is still ignored. `hotkeys.lua` now speaks the current
  guard reason if a deferred `U` release is cancelled. Focused checks passed:
  `luac -p main.lua hotkeys.lua test_hotkeys.lua
  test_sweep_walk_command_surface.lua`, `lua test_hotkeys.lua`, and
  `lua test_sweep_walk_command_surface.lua`.

### Follow-Up: Lower Tool Merchant Bridge Found

- LIVE PROOF: continuing from the entrance-to-Tool-Merchant route, autowalk
  reached `(5,15)` through the existing `(5,14)` passthrough. Same-origin
  probes confirmed the false route exits `(5,15)->DOWN`,
  `(3,15)->LEFT`, `(3,16)->LEFT`, and `(3,15)->UP` all raw-hold-timeout
  blocked without menu/dialogue/NPC contamination.
- FRONTIER LEAD: with those runtime blockers active, `debug_route_frontier_skip_npcs:12,21,40`
  reported row-17 hidden bridge candidates. The nearest live candidate was
  `(3,16)->DOWN` into tile-0 `(3,17)`, with target-side exit down to `(3,18)`.
- LIVE PROOF: from normally walked `(3,15)`, `probe_edge:DOWN` moved through
  `(3,16)` and settled on tile-0 `(3,17)`. `inspect_tile:3,17` reported
  tile-0/non-walkable in the current model while the hero stood there.
  `probe_edge:DOWN` from `(3,17)` then moved through `(3,18)` and settled at
  `(3,19)`, where skip-NPC pathfinding found `7 east, 2 south, 2 east` to
  `(12,21)`.
- LIVE PROOF: final autowalk from `(3,19)` found one more false shortcut,
  `(9,19)->RIGHT` into `(10,19).west`, confirmed by same-origin
  `probe_edge:RIGHT`. After runtime `add_blocked_edge:9,19,RIGHT`,
  `auto_walk_blocker:12,21` reached `(12,21)`.
- CLEAN / PROMOTED: `map_reader.lua` now adds Kol passthrough `(3,17)` and
  directional blockers `(5,16).north`, `(2,15).east`, `(2,16).east`,
  `(3,14).south`, and `(10,19).west`. Focused `test_map_reader.lua`
  assertions cover the new passthrough, keep adjacent row-17 siblings closed,
  and verify the promoted edge blockers.
- RELOAD NEEDED: FCEUX needs a manual `main.lua` reload before validating the
  full entrance-to-Tool-Merchant route against source instead of runtime
  blockers.

### Follow-Up: Tool Merchant Return Route Cleaned

- LIVE PROOF: continuing from the Tool Merchant stand `(12,21)`, repeated
  `auto_walk_blocker:19,23` route failures plus same-origin `probe_edge`
  checks closed the false return-route shortcuts. The promoted destination
  blockers are `(7,15).west`, `(4,16).west/north`, `(4,18).east`,
  `(6,16).north`, `(10,18).west`, `(2,19).east/south`, `(4,20).east/north/west`,
  `(10,20).south/west`, `(11,20).south`, `(12,20).south`,
  `(3,21).north/south/west`, `(4,21).east`, `(13,21).west`,
  `(4,22).east/west`, `(10,22).north/west`, `(11,22).north`,
  `(12,22).north`, `(4,23).west`, and `(5..9,23).north`.
- LIVE RESULT: with the runtime overlay active, `auto_walk_blocker:19,23`
  reached the town exit `(19,23)`. The reverse check
  `auto_walk_blocker:12,21` then walked from the exit back to the Tool
  Merchant stand, completing at `(12,21)`.
- CLEAN / PROMOTED: `map_reader.lua` now carries the return-route blockers in
  Kol `MAP_DIRECTIONAL_BLOCKS[0x07]`; `test_map_reader.lua` covers the
  promoted edges. Focused checks passed: `luac -p map_reader.lua
  test_map_reader.lua`, `lua test_map_reader.lua`, and `git diff --check`.
- RELOAD NEEDED: FCEUX still has the runtime overlay from this investigation.
  Manual `main.lua` reload is needed before validating the route against source
  alone.

### Follow-Up: Inn Route Final Edge

- LIVE PROOF: while cleaning the entrance-to-Inn route, autowalk stopped at
  `(9,4)->RIGHT` into `(10,4).west`. The same-origin `probe_edge:right` from
  `(9,4)` also raw-hold-timeout blocked with no NPC involvement. Runtime
  `add_blocked_edge:9,4,RIGHT` then planned around the edge and
  `auto_walk_blocker:19,2` reached the confirmed Inn stand at `(19,2)`.
- CLEAN / PROMOTED: `map_reader.lua` now adds `(10,4).west` to Kol
  `MAP_DIRECTIONAL_BLOCKS[0x07]`, and `test_map_reader.lua` asserts it beside
  the existing Kol inn-route blockers. Focused checks passed: `luac -p
  map_reader.lua test_map_reader.lua`, `lua test_map_reader.lua`,
  `lua test_pathfinder.lua`, and `git diff --check`.
- RELOAD NEEDED: FCEUX still has the runtime overlay for this edge. Manual
  `main.lua` reload is needed before validating the route against source alone.

## 2026-06-27 Rimuldar Inn Route Recheck

- LIVE PROOF: entrance-to-Inn route planning targeted the stored public stand
  `(16,17)` for `Merchant 3` / `Inn` at `(16,18)`, then failed at
  `(15,16)->DOWN`. Same-origin `probe_edge:DOWN` from normally walked
  `(15,16)` raw-hold-timeout blocked with no NPC involvement, so
  `(15,17).north` is promoted.
- LIVE PROOF: after runtime `add_blocked_edge:15,16,DOWN`, the next lower
  route reached `(18,19)` and failed `(18,19)->LEFT`. Same-origin
  `probe_edge:LEFT` from normally walked `(18,19)` raw-hold-timeout blocked
  with no NPC involvement, superseding the older mixed `(17,19).east` note.
- LIVE RESULT: with runtime blockers for `(15,17).north` and `(17,19).east`,
  `debug_route_frontier_skip_npcs:16,17,60` reports no remaining untested
  bridge into the stored stand. The hidden bridge candidates
  `(16,15)->DOWN`, `(15,16)->RIGHT`, `(18,18)->LEFT`, `(18,16)->LEFT`, and
  `(17,15)->DOWN` were already checked from walked origins and blocked.
- LIVE RESULT: `debug_pathfind_adjacent_skip_npcs:16,18` shows no route to any
  innkeeper-adjacent stand. `(16,17)` and `(16,19)` are walkable but
  unreachable; `(15,18)` and `(17,18)` are not walkable. A focused
  `debug_route_frontier_skip_npcs:16,19,40` found only the already-modeled
  `(16,20)->UP` south approach as a bridge to the south stand.
- CLEAN / PROMOTED: `map_reader.lua` now adds Rimuldar blockers
  `(15,17).north` and `(17,19).east`; `test_map_reader.lua` covers both.
- REOPENED / DO NOT PROMOTE: the apparent `(17,17)`/`(18,17)` connector was not
  bidirectional. The command-side `probe_edge:RIGHT` from `(17,17)` moved
  through `(18,17)`, but the clean entrance-to-Inn route from `(29,13)` reached
  `(18,17)` and repeatedly blocked on `(18,17)->LEFT` into `(17,17)`. Seam
  retries logged `blocked=6 moved=0`, added runtime block `(17,17)` with
  `approach=east`, and then the route collapsed with `No path found`.
- CLEAN / PROMOTED: restored `(17,17).east` in `map_reader.lua` and updated
  `test_map_reader.lua` to guard the entrance-to-Inn regression. Keep the
  reverse movement clue as one-way evidence only; this seam is not the missing
  public connector to the inn stand.
- CLEAN / PROMOTED: user found the actual reachable Inn stand. From `(18,18)`,
  TALK opened the `Welcome to the traveler's Inn. Room and board is 55 GOLD per
  night` prompt; `report_position` confirmed `(18,18)`, `report_npcs` confirmed
  `npc_16` / `Inn` remains at `(16,18)`, and path debug from `(18,18)` to the
  town exit `(29,13)` found routes in both skip-NPC and live-NPC modes. Updated
  `objects.lua` so the Inn routes primarily to `(18,18)` facing west, while
  preserving `(16,17)` facing south as an alternate prompt stand.

### Follow-Up: Magic Key Merchant Route Cleanup

- LIVE PROOF / PROMOTED: entrance-to-Magic-Key route stopped at
  `(9,10)->UP` into `(9,9).south`; route seam retry and same-origin
  `probe_edge:UP` both raw-hold-timeout blocked with no NPC involvement.
  Runtime `add_blocked_edge:9,10,UP` opened the next route stage.
- LIVE PROOF / PROMOTED: the next stage stopped at `(12,10)->UP` into
  `(12,9).south`; same-origin `probe_edge:UP` also blocked. Runtime
  `add_blocked_edge:12,10,UP` opened the west-side route stage.
- UNRESOLVED: the west-side stage then stopped at `(1,8)->RIGHT` into
  `(2,8).west`. Same-origin `probe_edge:RIGHT` and forensic
  `probe_edge_verify:1,8,RIGHT,5` both blocked. However, adding that runtime
  edge makes the route to the Magic Key Merchant no-path. `debug_route_frontier`
  reported 12 one-step bridge candidates into the merchant-side component; the
  reachable candidates checked from normal origins all blocked:
  `(1,6)->RIGHT`, `(1,7)->RIGHT`, `(4,9)->UP`, `(3,9)->UP`, `(2,9)->UP`,
  `(6,9)->UP`, `(7,6)->LEFT`, `(7,5)->LEFT`, `(7,4)->LEFT`,
  `(7,3)->LEFT`, and `(1,5)->RIGHT`. A focused
  `crawl_map_frontier:attempts=2,max_edges=80` was manually stopped after 41
  edges and found no passthrough or directional candidates.
- Fresh tainted-verifier audit rechecked `(6,9)->UP` with
  `verify_walked_edge:6,9,UP`: the route reached `(6,9)` through normal
  movement, then the up probe into `(6,8)` raw-hold-timeout blocked with no
  NPC/runtime blocker involved. Keep `(6,8).south` closed unless contradicted
  by later live movement from a cleaner state.
- Fresh tainted-verifier audit also rechecked the disputed bridge
  `(1,8)->RIGHT` after FCEUX input recovery. The walked verifier reached
  `(1,8)` and raw-hold-timeout blocked into `(2,8)` even though current source
  still treats `(2,8).west` as passable. This strongly suggests the old
  passable verifier proof was tainted or state-dependent.
- With temporary runtime `add_blocked_edge:1,8,RIGHT`, `debug_route_frontier`
  from the town entrance still reported only the same 12 one-step bridge
  candidates into the Magic Key Merchant component. Fresh audit rechecked
  `(7,6)->LEFT`, `(4,9)->UP`, `(1,6)->RIGHT`, `(1,7)->RIGHT`, and
  `(1,5)->RIGHT`; all reached their origins through normal movement and then
  raw-hold-timeout blocked. That leaves no known single-edge reopen candidate.
- UNRESOLVED / TRANSITION CHECK: the apparent alternate-overworld-entry theory
  did not hold up in live FCEUX. Leaving Rimuldar through the east edge changed
  to the world map at `(102,72)`. Re-entering the town tile from all four
  adjacent overworld sides landed at the same interior coordinate `(29,14)`:
  `(103,72)->LEFT`, `(101,72)->RIGHT`, `(102,71)->DOWN`, and
  `(102,73)->UP`. A normally reached `(4,3)->UP` probe stayed blocked. Later
  live proof established `(1,3)->LEFT` reaches in-town stand `(0,3)` and a
  second LEFT takes the actual west exit; overworld re-entry still returns to
  the east-side interior at `(29,14)`.
- CLEAN / PROMOTED: `map_reader.lua` now models `(9,9).south` and
  `(12,9).south`; `test_map_reader.lua` covers both and flips the stale
  `(9,9).south must stay open` assertion. Do not promote `(2,8).west` yet; it
  needs either a missing alternate bridge or a state-condition explanation.
- FRESH AUDIT / DO NOT PROMOTE: after clearing the temporary `(2,8).west`
  runtime close, a source-planned route from the normally reached row-2/top
  strip walked to `(1,8)` and again blocked on `(1,8)->RIGHT` into
  `(2,8).west`. Seam retry logged `blocked=3 moved=0`, no runtime blocks were
  active, and `auto_walk_blocker` reported `patch_command=add_blocked_edge:1,8,RIGHT`.
  This reinforces that the old 5/5 open verifier was tainted or state-dependent.
- FRESH AUDIT / REVIEW ONLY: with `(2,8).west` closed at runtime, local
  ROM-backed reranking found only row-1/top-strip hypotheses. Walked-origin
  probes proved `(9,2)`, `(10,2)`, and `(11,2)` are real hidden row-2 strip
  cells, and row-2 movement also crossed through `(12,2)->RIGHT` to `(14,2)`.
  However, north entries into row 1 from `(9,2)`, `(10,2)`, `(11,2)`,
  `(12,2)`, `(13,2)`, and cleanly reached `(14,2)` all raw-hold-timeout
  blocked. Do not promote the row-2 cells as a route fix yet; they did not
  reconnect the Magic Key Merchant component.
- FRESH AUDIT / UNRESOLVED: with temporary runtime
  `add_blocked_edge:1,8,RIGHT` active, `debug_route_frontier_skip_npcs:4,6,80`
  from the cleanly reached `(14,2)` strip still reported the same 12
  bridge-to-target candidates and no hidden bridge candidates. The top-ranked
  candidate remained the runtime-blocked `(1,8)->RIGHT`; all other high-value
  bridge candidates match already-rejected edges from this cleanup pass.
- FRESH CRAWL / UNRESOLVED: after FCEUX input recovery, with runtime
  `(2,8).west` still closed and no bridge input active, a normal-movement
  `crawl_map_frontier:attempts=2,max_edges=80,park_mobile_npcs=true` from the
  key-shop-side component hit the edge cap at 80 edges. It exported
  `passthrough=0`, `directional=0`, `stationary_npc=0`, and
  `door_frontier=0`; only x=1 boundary/timing cells plus `(2,12)` were marked
  unstable. A read-only frontier comparison from `(3,10)` likewise found no
  hidden bridges and ranked the temporary runtime-closed `(1,8)->RIGHT` edge
  first. This pass did not find an alternate bridge into the Magic Key
  Merchant component.
- GUIDE-ALIGNED REGION AUDIT / UNRESOLVED: external guide/map data points to
  the northwest water-hugging route, so the upper x=7 bridge candidates were
  rechecked from walked origins. `verify_walked_edge:7,3,LEFT`,
  `verify_walked_edge:7,4,LEFT`, `verify_walked_edge:7,5,LEFT`, and
  `verify_walked_edge:7,6,LEFT` all reached their origins normally and then
  raw-hold-timeout blocked into `(6,3)..(6,6)`. A stateful carry test on the
  x=1 strip did not prove `(1,8)->RIGHT`: entering `(1,8)` from `(1,7)` with
  raw Down and a short wait drifted to `(1,9)`, while entering from `(1,9)`
  with raw Up and a longer wait overshot to `(1,7)` and then blocked
  `(1,7)->RIGHT`. Treat these seed-flow runs as evidence that the x=1 strip
  has carry/scroll timing quirks, not as passability proof for `(2,8).west`.
- USER SCREENSHOT FOLLOW-UP / BLOCKED: user positioned the hero at `(1,8)`.
  Fresh `report_position` confirmed map `0x0B` at `(1,8)`. Direct same-origin
  `probe_edge:RIGHT` into `(2,8)` first blocked with runtime `(2,8).west`
  active, then blocked again after `clear_runtime_blocks:0x0B`, with
  `reason=raw_hold_timeout`, no NPC or permanent blocker, and source preview
  still effectively passable. Runtime `(2,8).west` was restored afterward as
  a live-only blocker. This is clean evidence that `(1,8)->RIGHT` is currently
  not the missing bridge, but the alternate bridge into the key-shop component
  remains unresolved.
- TOOLING BUG / PATCHED, NEEDS RELOAD: FCEUX repeatedly latched
  `LeftAlt+Return`; the external bridge ignored stale Alt, but the native
  stuck-Alt fallback in `debug_tools.lua` translated Return into repeated
  Start. Added regression coverage in `test_debug_tools.lua` and changed the
  native fallback to ignore Return/Enter while stale Alt is active. The
  explicit sidecar bridge can still send `start`. `recover_fceux_input.ps1`
  and `launch_dw.ps1` now release Return in the same key-up pulse as Alt.
  FCEUX must reload `main.lua` before further live route probing benefits
  from this fix.
- POST-RELOAD FRONTIER SWEEP / STILL UNRESOLVED: after the script reload and
  stale-Alt hardening, the player stood at `(1,8)` with the command menu
  closed. A local normal-movement crawl from `(1,8)` with runtime
  `add_blocked_edge:1,8,RIGHT` completed 69 edges and exported
  `passthrough=0`, `directional=0`, `stationary_npc=0`, and
  `door_frontier=0`; the only notable excluded cell was the already-known
  dead pocket `(1,19)`. Fresh walked-origin checks then revalidated all
  twelve `debug_route_frontier_skip_npcs:4,6` bridge-to-target candidates:
  `(1,8)->RIGHT` is the runtime-blocked edge; `(1,6)->RIGHT`,
  `(1,7)->RIGHT`, `(1,5)->RIGHT`, `(2,9)->UP`, `(3,9)->UP`,
  `(4,9)->UP`, `(6,9)->UP`, and `(7,3..7,6)->LEFT` all reached their
  origins by normal walking and raw-hold-timeout blocked with no NPC cause.
  A fresh frontier snapshot from `(7,3)` still reported exactly those twelve
  bridge-to-target entries and no `hidden_bridge=true` candidates. With the
  runtime block briefly cleared for read-only comparison, the source model's
  route from `(7,3)` to `(4,6)` was
  `3 south, 1 east, 3 south, 7 west, 1 north, 3 east, 2 north`, confirming
  the permanent model still relies on the contested `(1,8)->RIGHT` bridge.
  The runtime `(2,8).west` block was restored immediately. Do not promote the
  permanent block until either the missing state condition / bridge is found
  or the key-merchant route is intentionally marked unresolved.
- FORENSIC NORTHWEST EXIT CHECK / REVIEW ONLY: explicit `teleport_to:4,3`
  followed by `probe_edge:UP` moved to `(4,2)` and logged a
  `moved_through_modeled_block` mismatch for `(4,2).south`; this was
  teleport-seeded and is not valid route proof. Follow-up `probe_edge:UP` from
  `(4,2)` blocked into `(4,1)` and did not transition to the world map. The
  player was returned to `(7,3)` afterward. This does not solve the missing
  public route; keep the earlier alternate-overworld-entry theory unresolved /
  unproven.
- FORENSIC Y=0 CHECK / REVIEW ONLY: after clearing stale FCEUX Alt input, the
  source model rejected `(13,0)` / `(4,0)` as `engine_boundary` and rejected
  `(13,1)` / `(4,1)` as non-walkable tile type, while `(13,2)` remained a
  modeled passthrough. A forced `teleport_to:13,0,force` then proved the user's
  top-row observation is real in a forced seed: `probe_edge:RIGHT` moved through
  modeled boundary `(14,0)` and carried to `(15,0)`, and a second right probe
  carried from `(15,0)` to `(17,0)`. Descent samples from `(15,0)->DOWN` and
  `(17,0)->DOWN` both raw-hold-timeout blocked into row 1. This is not
  promotable map evidence yet; look for a normal-walk entry into y=0 or a
  descent back into the trusted map before exposing any row-0 Rimuldar cells.
  The player was restored to `(1,8)` afterward.
- SECOND GUIDE-ALIGNED PASS / STILL UNRESOLVED: after input recovery, the user
  / live state had the player at `(7,2)`, near the upper water-hugging strip.
  With temporary runtime `(2,8).west` closed, `debug_route_frontier_skip_npcs`
  from `(7,2)` to the key stand reported `target_reachable=false`,
  `bridge_candidates=13`, and `hidden_bridge_candidates=0`. The 13th
  bridge-to-target candidate not covered by the prior 12-edge sweep was
  `(7,2)->LEFT` into `(6,2)`; same-origin `probe_edge:LEFT` from the live
  `(7,2)` origin raw-hold-timeout blocked with the permanent `(6,2).east`
  directional blocker active. Alternate adjacent talk stands around Old Man 1
  were also no-path while `(2,8).west` was closed: `(4,6)`, `(4,8)`, `(3,7)`,
  and `(5,7)` all stayed unreachable, so there is no obvious alternate stand
  workaround. Carry/timing tests from normally reached `(1,7)` and `(1,9)`
  did not prove `(1,8)->RIGHT`: down-seeded and up-seeded targeted probes to
  `(1,8)` drifted vertically to `(1,9)` / `(1,7)` before the right probe could
  enter `(2,8)`. A short wait (`wait_frames=8`) still drifted. The seeded
  helper's trace shows the vertical seed/carry can remain visible at arm time,
  so these runs are diagnostic rather than passability proof. Runtime blocks
  were cleared afterward; final state was map `0x0B` at `(2,9)`.
- ORDER / STATE FOLLOW-UP / STILL BLOCKED: a normal route from `(2,9)` to the
  Magic Key stand approached `(1,8)` from the south and then tried
  `(1,8)->RIGHT`; queued route, timeout retry, and seam retry all blocked, and
  `AUTO_WALK_BLOCKER_FOUND` again reported `add_blocked_edge:1,8,RIGHT` with
  no runtime block active. A north-side setup then routed to `(1,7)`, stepped
  down to a settled `(1,8)`, and direct `probe_edge:RIGHT` again
  raw-hold-timeout blocked into `(2,8)`. This reduces the odds that the
  missing path is simply "enter `(1,8)` from the right prior direction."
- TOOLING FOLLOW-UP / PATCHED, NEEDS RELOAD: `main.lua` now makes edge-probe
  input switching/release explicit by sending false for all D-pad directions
  instead of `joypad.set(1, {})`, matching the safer FCEUX patterns used by
  `auto_step.lua`, `route_manager.lua`, and `debug_tools.lua`. The targeted
  seeded probe also now aborts with `target_drifted` if the hero continues
  moving off the requested target tile during the neutral wait, so future
  stateful probe logs do not accidentally report an edge from the wrong origin.
- POST-RELOAD GUARD TEST / WORKING: after manual FCEUX Lua reload,
  `probe_edge_after_raw_to:DOWN,120,1,8,16,RIGHT` reached `(1,8)` but then
  drifted to `(1,9)` during the neutral wait. The new guard ended the run as
  `reason=target_drifted`, preventing a wrong-origin right probe from being
  logged as evidence for `(1,8)->RIGHT`.
- POST-GUARD MAGIC KEY HUNT / STILL UNRESOLVED: mid-carry raw tests from
  `(1,6)` with Down holds of 28, 32, 35, 36, 37, and 43 frames did not cross
  east into `(2,8)`. With live-only `(2,8).west` closed, route-frontier
  snapshots still show the same twelve bridge-to-target candidates and no
  hidden bridge candidates. A read-only source route still depends on the
  disputed `(1,8)->RIGHT` edge, while a true entrance-to-merchant autowalk
  again blocked there. Do not promote `(2,8).west` until the missing bridge or
  state condition is understood.
- CLEAN / PROMOTED: the return/reset route back toward the entrance found five
  ordinary false shortcuts with route failure plus same-origin probe evidence:
  `(8,9)->RIGHT` into `(9,9).west`, `(16,7)->RIGHT` into `(17,7).west`,
  `(16,8)->DOWN` into `(16,9).north`, `(16,7)->UP` into `(16,6).south`, and
  `(14,8)->DOWN` into `(14,9).north`. These are now in `map_reader.lua` with
  regression assertions in `test_map_reader.lua`.
- POST-RESTORE BRIDGE AUDIT / STILL UNRESOLVED: after the user restored a clean
  save state, fresh baseline was Rimuldar `(29,13)` with command/menu state
  clear. Clearing only the live-only `(2,8).west` edge let the source route walk
  from the town entrance to `(1,8)`, where it again blocked on
  `(1,8)->RIGHT`; same-origin `probe_edge:RIGHT` from `(1,8)` also timed out,
  so runtime `(2,8).west` was restored as review-only route protection. With
  that edge closed, `debug_route_frontier_skip_npcs:4,6` reported exactly the
  same twelve bridge-to-target candidates and no hidden bridge candidates.
  Eleven were already covered, and the remaining NPC-contaminated
  `(1,7)->RIGHT` candidate was later rechecked after Woman 2 moved away:
  `probe_edge:RIGHT` from cleanly reached `(1,7)` raw-hold-timeout blocked into
  `(2,7)`. The apparent `(1,5)->DOWN` blocker during an NPC-adjacent autowalk
  was invalid timing/NPC noise; a later direct `probe_edge:DOWN` from `(1,5)`
  moved through to `(1,7)`. Net: every known one-edge bridge into the Magic Key
  Merchant component is currently blocked from walked origins, so the remaining
  explanation is likely a transition/state/modeling issue rather than another
  obvious local false-wall bridge.
- FOLLOW-UP / RUNTIME ONLY: while checking the user's current screenshot
  position, the hero was standing at `(23,2)` even though source still decodes
  it as non-walkable. Neighbor inspection showed `(24,2)` and `(24,3)` are the
  already-modeled northeast strip passthroughs. Same-origin `probe_edge:RIGHT`
  from `(23,2)` moved through `(24,2)` and carried to `(25,2)`, confirming a
  real hidden upper-east pocket, but `debug_pathfind_to_skip_npcs:4,6` from
  `(25,2)` still found no path to the Magic Key stand while runtime
  `(2,8).west` was closed. `debug_route_frontier_skip_npcs:4,6` reported the
  same twelve bridge-to-target candidates and no hidden bridge candidates, so
  this pocket is not the missing key-shop connector.
- CONTROLLED REOPEN / STILL BLOCKED: clearing only the review-only
  `(2,8).west` runtime block and keeping the other reset-route blockers let the
  planner create a 53-step path from `(25,2)` to `(4,6)`. The first live run
  stopped at `(28,8)->LEFT` into `(27,8).east`; same-origin `probe_edge:LEFT`
  also blocked. Do not promote this edge yet: earlier reloaded manual evidence
  crossed `(28,8)<->(27,8)` and source/test comments intentionally keep
  `(27,8).east` open, so today's result is state-dependent route evidence only.
  With runtime `(27,8).east` added for the current pass, the route continued to
  `(1,8)` and again blocked on `(1,8)->RIGHT` into `(2,8).west` under queued
  route, timeout retry, and seam retry. Runtime `(2,8).west` was restored.
  Current conservative runtime overlay has seven entries, including the
  review-only `(27,8).east`; current position after the pass was `(1,8)`.

## 2026-06-29 Clean Rimuldar Magic Key Baseline

- CHECKPOINT / PUSHED: before the clean baseline, committed and pushed
  `f980728` (`Checkpoint Rimuldar route investigation`) with the existing
  route/map/tooling changes and handoff cleanup. Verification before that
  checkpoint passed: `luac -p main.lua map_reader.lua objects.lua
  debug_tools.lua test_debug_tools.lua test_map_reader.lua test_objects.lua`,
  `git diff --check`, `lua test_debug_tools.lua` (19 tests),
  `lua test_map_reader.lua` (55 tests), and `lua test_objects.lua` (85 tests).
  The debug-tools test race was fixed by letting tests override the command
  file path, so live FCEUX command polling no longer steals test commands from
  the real `dw_commands.txt`.
- CLEAN BASELINE / STILL BLOCKED: after the user reloaded save state, reloaded
  the Lua script, walked out of Rimuldar, and walked back in, the first fresh
  probe found the hero on the World Map at `(102,71)` with no runtime blocks.
  A single `simulate_raw_input:DOWN,30` entered Rimuldar at `(29,14)`, again
  with no runtime blocks and no active path target.
- STATIC PLANNER CHECK: from `(29,14)`, both `debug_pathfind_to:4,6` with live
  NPCs and `debug_pathfind_to_skip_npcs:4,6` found a 45-step route to the Magic
  Key stand `(4,6)`. Before adding any runtime closure,
  `debug_route_frontier_skip_npcs:4,6,80` reported `target_reachable=true`.
- LIVE MOVEMENT CHECK: `auto_walk_blocker:4,6` walked the route normally to
  `(1,8)`, then the next step `(1,8)->RIGHT` into `(2,8).west` failed under
  queued movement, timeout retry, and seam retry. The log emitted
  `AUTO_WALK_BLOCKER_FOUND` with `patch_command=add_blocked_edge:1,8,RIGHT`,
  `npc_blocked=false`, and `timing_suspect=false`.
- RUNTIME CLOSURE CHECK: adding runtime `add_blocked_edge:1,8,RIGHT` from the
  stopped `(1,8)` state made `debug_route_frontier_skip_npcs:4,6,80` report
  `target_reachable=false`, `bridge_candidates=12`, and
  `hidden_bridge_candidates=0`. The twelve bridge candidates were the same
  local blocked-directional set already reviewed; the only runtime candidate
  was the disputed `(1,8)->RIGHT` / `(2,8).west` edge.
- CLEANUP / NEXT: the runtime block was cleared after the check. Final live
  state was Rimuldar `(1,8)`, no active path, no runtime blocks. Do not promote
  `(2,8).west` into permanent map data yet: closing it isolates the known
  merchant-side component, while leaving it open produces a route that fails
  live. The best next move is no longer broad local candidate hunting; pivot to
  a manual route trace, a transition/state investigation, or explicitly mark
  the Magic Key merchant route unresolved until new state evidence appears.

## 2026-07-06 Cantlin FCEUX Input Trace Repro

- REPRO: with the diagnostic qfceux binary at
  `D:\modding\DragonWarrior1\.tools\fceux-build-tools\build-fceux\bin\qfceux.exe`,
  `survey_target:Old Man 4,park_npcs` reproduced input contamination in
  Cantlin at `(25,23)` on a queued-route `DOWN` attempt. Lua logged
  `INPUT_CONTAMINATION_CAPTURE command=survey_objects keys=LeftAlt joy=- bridge=- buttons=0x20`,
  immediately followed by `GAME_INPUT_AUTO_CLEAR ... before=0x20 after=0x00`
  and `GAME_INPUT_AUTO_NEUTRAL ... frames=30`.
- TRACE RESULT: `D:\modding\fceux-input-debug\dw_fceux_input_trace.log`
  showed raw host/gamepad input was `0x00` while Lua was issuing
  `joypad.set` Down. The key diagnostic window had `LUA_JOYPAD_SET
  frame=6655686 ... force_mask=0x20`, `UPDATE_GP ... raw=[00,00,00,00]
  before=[00,00,00,00] after=[20,00,00,00]`, then neutralization at
  `frame=6655699` with `force_mask=0x00` and `after=[00,00,00,00]`.
  A second Down burst began at `frame=6655707` and neutralized at
  `frame=6655720`. No nearby `QT_KEY`/`QT_GAMEPAD` event produced Down.
- LOW-LEVEL CONFIRMATION: when FCEUX internal `joy0=0x20`, the `$4016` trace
  serializes Down as `READ_GP ... bit_before=5 ... ret=0x01` / `JPREAD
  ... ret=0x41`. When Lua neutralizes, `UPDATE_INPUT` returns to
  `joy=[00,00,00,00]`. This points at Lua automation/retry input reaching
  the NES input port normally, not a physical controller or keyboard source.
- AFTER-STATE: the survey aborted cleanly, restored parked NPCs, and command
  polling remained alive. Follow-up `stop_survey stop_auto_walk report_position
  report_runtime_blocks report_path_state input_status:after_repro
  report_input_guard_state` reported Cantlin `(25,23)`, no runtime blocks,
  no active path, `$0047=0x00`, and only the known benign stale `LeftAlt`.

## 2026-07-06 FCEUX RAM Trace Build

- SOURCE PATCH: extended the diagnostic FCEUX tree at
  `D:\modding\fceux-input-debug` with watched CPU/Lua RAM-write tracing for
  canonical RAM `$0038-$004F`, named `$003C` as `MOVEMENT_STATE`, `$003D` as
  `MOVEMENT_SUBPIXEL`, and `$0047` as `BUTTONS_PRESSED`. The patch also adds
  `pc=0x%04X` to the existing `$4016`/gamepad serial trace lines.
- BUILD FIX: the first compile failed in `src\x6502.cpp` because the new
  `WrRAM` trace used `currFrameCounter` without a local declaration. Added
  `extern int currFrameCounter;` in that file.
- BUILD RESULT: direct CMake/MSBuild still fails from the Codex environment
  with duplicate `PATH` / `Path`, so the compile was run through a clean
  PowerShell wrapper. The wrapper did not return cleanly, but the build log
  shows `fceux.vcxproj -> ...\src\Release\fceux.exe`, stderr stayed empty,
  and no `cmake`, `MSBuild`, `cl`, or `link` process remained afterward.
- DEPLOYED BINARY: copied the new
  `.tools\fceux-build-tools\build-fceux\src\Release\fceux.exe` over
  `.tools\fceux-build-tools\build-fceux\bin\qfceux.exe`. The deployed binary
  is 3,864,576 bytes, SHA256
  `ECFB2571C8260750C1A3CA73590CDF97BCCE5F8AE759E49F8184660294679ADE`, and
  contains `RAM_WRITE`, `LUA_MEM_WRITE`, `BUTTONS_PRESSED`,
  `source=cpu_fast_ram`, `source=cpu_handler_low`, and `pc=0x%04X`.
- NEXT REPRO: launch the deployed diagnostic `qfceux.exe` with
  `FCEUX_DW_INPUT_TRACE=1`, load the Cantlin state and `main.lua`, then rerun
  the narrow repro (`survey_target:Old Man 4,park_npcs`) so the new trace can
  distinguish CPU/game RAM writes from Lua `memory.writebyte` cleanup.

## 2026-07-06 RAM Trace Live Repro Attempt

- BASELINE: diagnostic `qfceux.exe` was running from
  `.tools\fceux-build-tools\build-fceux\bin\qfceux.exe`. Command polling was
  alive but slowed; `launcher_probe:codex_lag_baseline` took about 8 seconds
  to match. Baseline state was Cantlin `(20,22)`, `$0047 buttons=0x00`, no
  runtime blocks, no active path, and only benign stale `LeftAlt`.
- TRACE LOAD: `D:\modding\fceux-input-debug\dw_fceux_input_trace.log` grew by
  about `1.3-1.6 MB` per 2 seconds while idle/near-idle. The tail was dominated
  by `RAM_WRITE` lines for watched RAM, including repeated `$0047`
  `old=0x00 new=0x00`. Treat the current trace build as too noisy for long
  live repro loops.
- PREFLIGHT: `report_survey_start:park_npcs` from `(20,22)` reported
  `status=viable`, `targets=21`, `reachable_area=128`, `open_exit_count=4`,
  `reachable_targets=21`, and `npc_mode=park_npcs`.
- REPRO ATTEMPT: `survey_target:Old Man 4,park_npcs` started cleanly but did
  not produce `INPUT_CONTAMINATION_CAPTURE` within a 240-second wait. It
  churned through timing-sensitive movement and route retries toward Old Man 4.
  Manual stop at frame `5280` produced `SURVEY_RESULT ... failure_class=
  command_timing_or_state_issue ... blocked_events=16 ... reason=manual_stop`;
  do not promote the suspected tiles from this run.
- RECOVERY: after `stop_survey stop_auto_walk`, state was Cantlin `(27,21)`,
  no runtime blocks, no active path, but visible input was still
  `joy1=down buttons=0x20`. `isolate_input:180` cleared the condition; final
  check at frame `5700` was Cantlin `(27,22)`, no runtime blocks, no active
  path, `joy1=-`, bridge `-`, and `$0047 buttons=0x00`.
- NEXT: quiet/rebuild the RAM trace before the next long repro. A better
  default is to log `$0047` only on changed or nonzero writes and put the broad
  `$0038-$004F` firehose behind `FCEUX_DW_INPUT_TRACE_VERBOSE=1`.

## 2026-07-06 Quiet RAM Trace Build

- SOURCE PATCH: updated `D:\modding\fceux-input-debug\src\input_trace.h` so
  default RAM-write tracing still watches `$0038-$004F`, but only logs
  `$0047` / `BUTTONS_PRESSED` when the old or new byte is nonzero or the byte
  changes. `FCEUX_DW_INPUT_TRACE_VERBOSE=1` still logs all watched RAM writes,
  including `$003C/$003D` movement state.
- BUILD RESULT: direct CMake/MSBuild remains unsuitable from the Codex
  environment because of duplicate `PATH` / `Path`. The clean wrapper again
  timed out externally, but
  `.tools\fceux-build-tools\quiet_ramtrace_build_stdout.log` shows
  `fceux.vcxproj -> ...\src\Release\fceux.exe`, stderr is empty, and no
  compiler/build process remained afterward.
- DEPLOYED BINARY: copied the rebuilt
  `.tools\fceux-build-tools\build-fceux\src\Release\fceux.exe` over
  `.tools\fceux-build-tools\build-fceux\bin\qfceux.exe`. SHA256 is
  `D3AEBB34138EF9FC026FAF8F90BEF9867B3434AAF6B3948474359A1D7B6A520F`.
- NEXT REPRO: launch the deployed diagnostic with only
  `FCEUX_DW_INPUT_TRACE=1` and without
  `FCEUX_DW_INPUT_TRACE_VERBOSE=1`; then rerun
  `survey_target:Old Man 4,park_npcs`.

## 2026-07-07 Quiet Trace Cantlin Repro

- BASELINE: diagnostic `.tools\fceux-build-tools\build-fceux\bin\qfceux.exe`
  was running with SHA256
  `D3AEBB34138EF9FC026FAF8F90BEF9867B3434AAF6B3948474359A1D7B6A520F`.
  `launcher_probe:codex_quiet_baseline` confirmed command polling. Cantlin
  baseline was `(20,22)`, `$0047 buttons=0x00`, no runtime blocks, no active
  path, and only benign stale `LeftAlt`.
- PREFLIGHT: `report_survey_start:park_npcs` reported `status=viable`,
  `targets=21`, `reachable_area=128`, and `reachable_targets=21`.
- REPRO: `survey_target:Old Man 4,park_npcs` reproduced the contamination at
  frame `20166` while probing from `(24,23)` toward `UP`. The mod log reported
  `INPUT_CONTAMINATION_CAPTURE command=survey_objects keys=LeftAlt joy=-
  bridge=- buttons=0x11`, followed by `GAME_INPUT_AUTO_CLEAR before=0x11
  after=0x00` and `GAME_INPUT_AUTO_CLEAR_CHECK ... buttons=0x00`.
- TRACE RESULT: `D:\modding\fceux-input-debug\dw_fceux_input_trace.log`
  showed Lua forcing `force_mask=0x10` for the movement direction. At FCEUX
  frame `6642700`, `QT_GAMEPAD ... pads=[01,00,00,00]` appeared and
  `LUA_READ_JOYPAD ... input=0x01 ... output=0x11` merged the raw native A
  bit with Lua's direction. There was no nearby `QT_KEY` event in the tail,
  so the raw A bit was probably stale native keyboard-backed GamePad.0 state.
- CONFIG FINDING: direct `.tools` launch was using
  `.tools\fceux-build-tools\build-fceux\bin\fceux.cfg`, which still had
  `SDL.Input.GamePad.0.DeviceType = Keyboard`, `SDL.ToggleMenu = 0`,
  `SDL.Hotkeys.MainMenuHide = Alt+/`, and
  `SDL.Hotkeys.FullScreen = Alt+Return`. This bypassed the normal launcher
  mitigations documented in `launch_dw.ps1`.
- MITIGATION APPLIED: patched the `.tools` `fceux.cfg` so
  `SDL.Input.GamePad.0.DeviceType = None`, `SDL.ToggleMenu = 1`, and both
  Alt hotkeys are blank. This affects the next FCEUX start; the currently
  running emulator had already loaded the old config.
- RELOAD FOLLOW-UP: after the user reloaded back to the Cantlin save state,
  `launcher_probe:codex_after_config_reload` confirmed command polling and
  Cantlin `(20,22)` with `$0047 buttons=0x00`, but the `.tools` config had
  reverted/restored to `SDL.Input.GamePad.0.DeviceType = Keyboard`,
  `SDL.ToggleMenu = 0`, `SDL.Hotkeys.MainMenuHide = Alt+/`, and
  `SDL.Hotkeys.FullScreen = Alt+Return`. Conditions are good for reproducing
  the old path, but not for judging the config mitigation. Next clean test
  should launch the diagnostic binary via `launch_dw.ps1 -FceuxPath` or add
  source-level `DTestButton` source tracing/suppression.
- AFTER-STATE: `simulate_input:B` closed the command menu. Final live check
  was Cantlin `(24,23)`, `$0047 buttons=0x00`, no runtime blocks, no active
  path, and `menu_active=false`.

## 2026-07-07 Launcher Config And Self-Input Guard

- VERIFY: user launched through `launch_dw.ps1`; live process was the
  diagnostic `.tools\fceux-build-tools\build-fceux\bin\qfceux.exe`. The
  `.tools` runtime config still showed `SDL.Input.GamePad.0.DeviceType = None`,
  `SDL.ToggleMenu = 1`, and blank Alt menu/fullscreen hotkeys while FCEUX was
  running. This supports using the launcher as the durable pre-start mitigation
  because direct FCEUX exits/restarts can rewrite the local config.
- LIVE REPRO: `survey_target:Old Man 4,park_npcs` no longer reproduced the
  direct-launch raw `A` merge. It eventually aborted at Cantlin `(25,23)` on a
  queued-route `DOWN` timeout: `INPUT_CONTAMINATION_CAPTURE ... buttons=0x20`,
  then `GAME_INPUT_AUTO_CLEAR ... after=0x00`.
- TRACE RESULT: `D:\modding\fceux-input-debug\dw_fceux_input_trace.log` showed
  raw host/gamepad input stayed `0x00`; Lua forced `Down` (`force_mask=0x20`),
  FCEUX delivered it through `$4016`, the ROM wrote `$0047`, and Lua later
  neutralized. The remaining `$0047=0x20` was therefore self-injected route
  input sampled during route-block cleanup, not a physical/controller redirect.
- CODE FIX: `debug_tools.input_contamination_refusal` now accepts contextual
  route-block options and ignores only timing-suspect `route_blocked` samples
  where `$0047` exactly matches the direction just injected. `map_survey.lua`
  and `route_manager.lua` pass that context; startup, idle/tick, wrong-button,
  raw `A`, and raw `Start` contamination paths still refuse/abort.
- VERIFY: `luajit -b debug_tools.lua NUL`, `luajit -b route_manager.lua NUL`,
  and `luajit -b map_survey.lua NUL` passed. `luajit test_route_manager.lua`
  passed 103 tests. `luajit test_map_survey.lua` passed 53 tests.
  `luajit test_debug_tools.lua` passed 27 tests when run with
  `DW_TEST_TMPDIR` pointed at a workspace-local temp directory; a filtered run
  also passed `input_guard_allows_timing_suspect_route_blocked_self_direction`.
- NEXT: manually reload `main.lua` in FCEUX, then re-run the narrow
  `survey_target:Old Man 4,park_npcs` from a clean Cantlin save state. Expect
  `INPUT_CONTAMINATION_IGNORED ... reason=route_blocked_self_input` instead of
  `SURVEY_ABORT reason=input_contaminated` for the self-injected `DOWN`
  timing sample; any raw `A`/wrong-button recurrence should still abort and be
  treated as a separate input-source bug.
- POST-RELOAD HARD-LOCK: after the user manually reloaded `main.lua`, command
  polling stayed live at Cantlin `(25,23)` and visible input was clean
  (`joy1=-`, bridge `-`, `$0047=0x00`). The pre-recovery movement snapshot
  still had `$003C/$003D = 0x08/0x08`; `reset_movement_state` cleared those to
  `0x00/0x00`, and `clear_game_input` / `isolate_input:30` left `$0047=0x00`.
  A corrected quoted `simulate_raw_input:A,12` reached Lua/FCEUX
  (`Queued raw joypad: A for 12 frames`, `joy1=A`), but the normal field
  command menu still did not open (`menu_active=false`). This confirms the
  deeper hard-lock persists below the mod-visible input layers; save-state
  restore is the right recovery before further Cantlin surveying.

## 2026-07-07 Post-Restore Self-Input Filter And Controller-Poll Wedge

- BASELINE: after save-state restore, `launcher_probe:post_restore_cantlin_baseline`
  confirmed command polling. Cantlin was `map=0x0A` at `(20,22)`, `$0047
  buttons=0x00`, no menu/dialogue, no runtime blocks, and no active path.
  `report_survey_start:park_npcs` was viable with `targets=21`,
  `reachable_area=128`, and all four exits open.
- FOCUSED REPRO: `survey_target:Old Man 4,park_npcs` started from `(20,22)`.
  It churned through multiple route retries and reached the familiar `(25,23)`
  pocket. At frame `26108`, queued-route `DOWN` produced `$0047=0x20`; the new
  guard correctly logged `INPUT_CONTAMINATION_IGNORED ... reason=route_blocked_self_input`
  for both `survey_objects` and `auto_walk`, then continued instead of
  aborting.
- SECOND-STAGE WEDGE: the follow-up seam retry from `(25,23)` toward `DOWN`
  timed out with `movement_started=false`. At frame `26251`, the guard captured
  `keys=LeftAlt joy=- bridge=- buttons=0x20`, with movement bytes
  `$003C/$003D = 0x08/0x08`, logged `GAME_INPUT_AUTO_CLEAR ... before=0x20
  after=0x00`, and the delayed `GAME_INPUT_AUTO_CLEAR_CHECK` still showed
  `$0047 buttons=0x00`.
- RECOVERY TEST: despite `$0047=0x00`, a raw `simulate_raw_input:A,12` at
  frame `28260` reached Lua/FCEUX but did not open the field command menu.
  `reset_movement_state:post_auto_clear_raw_a_failed` then cleared
  `$003C/$003D` from `0x08/0x08` to `0x00/0x00`; a second raw
  `simulate_raw_input:A,12` at frame `30780` still did not open the menu.
  Final snapshot at frame `32160` was internally clean from Lua's view:
  `(25,23)`, `$0047=0x00`, `$003C/$003D=0x00/0x00`, no runtime blocks, no
  active path.
- FCEUX TRACE RESULT: `D:\modding\fceux-input-debug\dw_fceux_input_trace.log`
  showed the raw `A` injections were present in FCEUX (`LUA_READ_JOYPAD ...
  output=0x01`, `UPDATE_INPUT joy=[01,00,00,00]`) for frames
  `6638765..6638777` and `6641285..6641297`, but the tail segment showed no
  `B4016`, `STROBE_GP`, `READ_GP`, or `JPREAD` during those raw-A windows.
  This means the input is not being lost in the FCEUX/Lua merge path; the ROM
  appears to have stopped polling `$4016` in the wedged state.
- CPU TOOLING: `report_cpu_state[:TAG]` was implemented to capture the wedged
  ROM PC/register/opcode state without disturbing gameplay.
- CPU CAPTURE: after reload while still wedged, `report_cpu_state:fceux_wedged`
  and `report_cpu_state:fceux_wedged_2` caught the ROM at `$B9F8` and `$B9ED`.
  Live opcode bytes were `$B9F8: 4C ED B9` (`JMP $B9ED`) and
  `$B9ED: C0 00 F0` (`CPY #$00; BEQ ...`). The relevant RAM window showed
  `$004E=0x2A`, `$004F=0x81`, `$0047=0x00`, and `$003C/$003D=0x00/0x00`.
- ROOT-CAUSE SHAPE: ROM bank 0 at `$B9E9-$B9F8` loads `Y` from `$004E`,
  writes `0xF0` to `$0200,Y`, increments `Y` by 4, and loops until `Y==0`.
  Starting at `$004E=0x2A` is impossible to terminate because `0x2A mod 4`
  stays 2 forever. This explains why FCEUX/Lua can deliver input while the
  ROM never polls `$4016`: the game is trapped in its sprite-OAM clear loop.
- SOURCE FOLLOW-UP: `report_oam_offset[:TAG]` and
  `watch_oam_offset[:on|off|status|TAG]` are implemented in
  `debug_tools.lua`. A first live arm proved the hook survived save-state
  restore, but `$004E` is a normal hot scratch/OAM cursor byte: it logged
  79,902 writes before being disarmed, including many temporary misaligned
  values that were later corrected. Do not use verbose logging for the repro.
- QUIET WATCHER UPDATE: `watch_oam_offset[:TAG]` now keeps a recent-write ring
  buffer silently and logs only `OAM_OFFSET_STUCK` if the CPU is actually at
  `$B9ED`/`$B9F8` with a non-terminating `$004E` value. Verbose per-write
  logging moved to `watch_oam_offset_verbose[:TAG]` for tiny captures only.
  Verification passed: `luajit -b debug_tools.lua NUL`, focused
  `DW_TEST_FILTER=oam_offset luajit test_debug_tools.lua`, full
  `luajit test_debug_tools.lua` with 32 tests, and `git diff --check`.
- NEXT: manually reload `main.lua`, restore the clean Cantlin save state if
  the reload disturbs it, then arm quiet `watch_oam_offset:repro` before
  reproducing `survey_target:Old Man 4,park_npcs`. The target evidence line is
  `OAM_OFFSET_STUCK tag=repro ... value=0x2A ... recent=...`; runtime PC/write
  context should decide which normal `$004E` writer leaves the final bad value.

## 2026-07-07 OAM Root Cause And Parking Fix

- CLEAN REPRO CAPTURE: after the user restored the Cantlin save state, quiet
  `watch_oam_offset:repro` was armed from a clean `(20,22)` baseline and
  `survey_target:Old Man 4,park_npcs` reproduced the hard lock at frame
  `10601`. The key log line was
  `OAM_OFFSET_STUCK tag=repro ... value=0x2A ... pc=0xB9F8 ...
  diagnosis=misaligned_offset_will_never_exit_B9ED_B9F8`.
- WRITER CONTEXT: the recent write ring ended with the ROM object-draw writer
  logged as `pc=0xB972 value=0x2A` after the `STX $4E` at `$B970`. Since
  `$2A / 3 = 14`, the bad offset maps to NPC object-table slot 14. A later
  `report_npcs` after restore showed slot 14 is `Merchant 6`; the slot had
  already been restored by then, so this names the table slot, not the live
  parked bytes during the lock.
- ROOT CAUSE: parked-NPC survey used low coordinate `(31,31)` for non-target
  NPCs. The Dragon Warrior renderer does not treat that as inactive; it skips
  only slots whose low x/y coordinate bits are both zero. During parked-NPC
  survey, those offscreen-but-rendered slots can drive the object draw loop and
  leave `$004E` as a non-multiple-of-4 object-table offset. The subsequent
  `$B9ED-$B9F8` OAM clear loop increments by 4 until `Y==0`, so `$004E=0x2A`
  can never terminate.
- SOURCE FIX: `map_survey.lua` now parks non-target NPCs at low coordinate
  `(0,0)`, and `route_manager.lua` does the same for proactive and reactive
  autowalk NPC parking while preserving each raw byte's high bits. Tests were
  updated in `test_map_survey.lua` and `test_route_manager.lua`.
- VERIFY: `git diff --check`, `luajit -b map_survey.lua NUL`,
  `luajit -b route_manager.lua NUL`, `luajit test_map_survey.lua`, and
  `luajit test_route_manager.lua` passed. `luajit test_debug_tools.lua` also
  passed 32 tests when run with `DW_TEST_TMPDIR` pointed at `.tmp-tests`; on
  this Windows LuaJIT path the default `/tmp` fallback is not writable.
- CONTAMINATED FOLLOW-UP: after the user reloaded `main.lua`, a baseline probe
  still reported Cantlin `(25,23)`, `pc=$B9F6/$B9F8`, and `$004E=0x2A`. That
  proves the script reload alone did not reset the ROM out of the prior OAM
  loop. `watch_oam_offset:off` disarmed the stale watcher.
- LIVE VALIDATION: after the user restored the clean Cantlin save state,
  `launcher_probe:parking_fix_clean` confirmed a clean `(20,22)` baseline with
  `$0047 buttons=0x00`. `report_oam_offset:parking_fix_clean` reported
  `$004E=0x60`, `aligned=true`, `reaches_zero=true`, and the quiet watcher
  armed with `stuck_reports=0`. Re-running
  `survey_target:Old Man 4,park_npcs` did not produce `OAM_OFFSET_STUCK` and
  did not hard-lock controls; the survey failed as a normal route issue with
  `state_issues=1`.
- ROUTE FOLLOW-UP: after the parking fix held, nine Cantlin Old Man 4
  lower-pocket seams reproduced as route failures and were confirmed with
  same-origin `probe_edge` checks:
  `(20,23)->RIGHT` into `(21,23).west`,
  `(20,24)->RIGHT` into `(21,24).west`,
  `(22,24)->LEFT` into `(21,24).east`,
  `(21,25)->UP` into `(21,24).south`,
  `(22,24)->UP` into `(22,23).south`,
  `(22,24)->RIGHT` into `(23,24).west`,
  `(22,25)->RIGHT` into `(23,25).west`, and
  `(23,26)->UP` into `(23,25).south`, and
  `(24,25)->UP` into `(24,24).south`. These were promoted to
  `MAP_DIRECTIONAL_BLOCKS[0x0A]` in `map_reader.lua` with regression coverage
  in `test_map_reader.lua`.
- POST-RELOAD CHECK: after the user reloaded `main.lua`, command polling was
  live at Cantlin `(23,26)`, `RUNTIME_BLOCKS map=0x0A none`, and
  `$0047 buttons=0x00`. The static model routed around the eight existing
  seams, then same-origin probing confirmed `(24,25)->UP` into
  `(24,24).south` as the ninth seam. Because that ninth seam was patched after
  the reload, FCEUX needs one more manual `main.lua` reload before the current
  source model is fully live.
- NEXT: manually reload `main.lua` again so FCEUX picks up the ninth
  `map_reader.lua` seam, confirm `report_runtime_blocks` is clear, then retry
  the narrow `survey_target:Old Man 4,park_npcs` or a direct route to the Old
  Man 4 stand.

## 2026-07-08 Cantlin Locked Door Pinning

- RESUME RECOVERY: after the Codex app restart, the pending manual OPEN at
  `(4,20)` was recovered with `verify_door_after`. The armed verifier had
  `stand=(4,20) dir=down expected_door=(4,21)`, and the result confirmed
  `expected_present=true`, keys `3 -> 2`, and door RAM slot `3=(4,21)`.
- FINAL DOOR: the remaining guide-backed icon door was not the north stand
  `(8,24)` facing down; that verifier churned and was stopped cleanly. The
  valid stand was `(7,25)` facing east toward `(8,25)`. Manual OPEN played the
  door sound, and `verify_door_after` confirmed `expected_present=true`,
  keys `2 -> 1`, and door RAM slot `4=(8,25)`.
- PROMOTED: `map_reader.lua` now models all five Cantlin door cells:
  `(26,9)`, `(15,25)`, `(14,25)`, `(4,21)`, and `(8,25)`. `objects.lua`
  exposes matching door objects, including `Western Shop North Door` and
  `Western Shop East Door`.
- FINAL LIVE STATE: Cantlin `(7,25)`, keys `1`, door RAM
  `0=(26,9) 1=(15,25) 2=(14,25) 3=(4,21) 4=(8,25)`,
  `RUNTIME_BLOCKS map=0x0A none`, and `buttons=0x00`.
- NEXT: manually reload `main.lua` in FCEUX before judging the latest door
  object/path data live.

## 2026-07-08 Cantlin Service Route Start

- User restored an all-doors-open Cantlin save state. Fresh baseline:
  `POSITION map=0x0A(Cantlin) x=8 y=25`, door RAM
  `0=(26,9) 1=(15,25) 2=(14,25) 3=(4,21) 4=(8,25)`, and
  `RUNTIME_BLOCKS map=0x0A none`.
- Practical town-entry origin is `(15,1)`. Forced `(15,0)` remains a boundary
  start artifact and should not be used as the route origin until separately
  decoded.
- COMPLETED SERVICE ROUTE: entrance `(15,1)` to `Merchant 4` interaction tile
  `(8,5)`. TALK from `(8,5)` facing north opened:
  `Welcome to the traveler's Inn. Room and board is 100 GOLD per night.`
- PROMOTED after same-origin `probe_edge_verify:...,3` results:
  `(13,1).east`, `(13,2).east`, `(13,3).east`, `(13,4).east`,
  `(13,5).east`, `(13,6).east`, `(13,7).east`, `(13,8).east`,
  `(20,2).north`, `(21,2).north`, `(22,2).north`, `(18,2).west`,
  and `(18,6).west`.
- NOT PROMOTED: `(15,2).north` became noisy and moved during full-route
  attempts. Merchant 2 survey suspects near `(21,5)`, `(21,6)`, `(22,7)`,
  `(23,5)`, and `(23,6)` came from a timed-out/manual-stop survey and need
  direct same-origin verification before any source patch.
- Source patch: `map_reader.lua` `MAP_DIRECTIONAL_BLOCKS[0x0A]` plus
  `test_map_reader.lua` regression coverage. `luajit.exe test_map_reader.lua`
  passes after the patch. Reload `main.lua` in FCEUX before live retest.

## 2026-07-08 Cantlin Merchant 2 Route Continuation

- LABEL FIX: `objects.lua` now labels Cantlin `Merchant 4` as `Inn` with
  counter stand `(8,5)` facing north, matching the service-label format used by
  other towns' inns. `report_npcs` confirmed the live object name as `Inn`.
- MERCHANT 2 PROMPT PROOF: while adjacent to `Merchant 2`, raw TALK opened:
  `We deal in weapons and armor. Dost thou wish to buy anything today?`
  `objects.lua` now labels this moving service NPC as `Weapons Merchant` while
  keeping adjacent-NPC routing. The durable route is not finished yet.
- PROMOTED MERCHANT 2 ROUTE EDGES: same-origin
  `probe_edge_verify:...,3` checks confirmed all of these blocked-only seams:
  `(16,1).west`, `(19,2).north/south`, `(20,2).south`,
  `(23,2).north`, `(21,3).west`, `(21,4).west`, `(21,5).west`,
  `(21,6).west`, `(20,7).north`, `(19,7).north`,
  `(18,3).east/south/west`, and `(18,6).east/north`.
  These extend the earlier service-route blockers `(13,1..8).east`,
  `(20,2).north`, `(21,2).north`, `(22,2).north`, `(18,2).west`, and
  `(18,6).west`.
- POST-RELOAD FOLLOW-UP: after the user reloaded `main.lua`, live route hunts
  continued from the post-source baseline and promoted these additional
  same-origin `probe_edge_verify:...,3` blockers:
  `(23,4).east`, `(23,5).east`, `(23,6).east`, `(23,7).east/south`,
  `(22,7).south`, `(21,7).south`, `(20,7).south`, `(19,7).south`,
  `(18,7).south/west`, `(18,2).north`, `(23,3).east`, and
  `(23,2).east`. Each was mirrored into runtime with `add_blocked_edge`
  because source edits after the reload are not live until the next manual
  script reload.
- MERCHANT 2 COMPONENT CHECK: with runtime blockers active, Merchant 2 at
  `(22,5)` produced `Debug pathfind adjacent ... No path found`. A follow-up
  `debug_route_frontier_skip_npcs:22,5,80` from `(24,2)` reported
  `target_reachable=false`, `bridge_candidates=34`, and
  `hidden_bridge_candidates=0`; the top bridge candidates were already
  confirmed runtime/source blockers such as `(24,5)->LEFT`, `(24,4)->LEFT`,
  `(24,6)->LEFT`, and `(22,8)->UP`.
- COUNTER-STAND NEGATIVE PROOF: route to public-side `(24,5)` succeeded, then
  raw alignment held Merchant 2 at `(22,4)` while the hero stood at `(24,4)`.
  Raw `LEFT`, command-menu `TALK` returned `There is no one there`, so do not
  promote `(24,4)` facing west as a fixed Weapons Merchant counter stand.
- CURRENT LIVE CHECKPOINT: FCEUX is at Cantlin `(24,4)`, menu closed,
  Merchant 2 / `Weapons Merchant` frozen at `(22,4)`, and
  `RUNTIME_BLOCKS map=0x0A count=12` mirrors the post-reload source blockers.
  Reload `main.lua` before relying on source-only map data, or continue by
  testing another Cantlin service route rather than forcing a fixed Merchant 2
  counter stand.

## 2026-07-09 Cantlin Service Route Reload Follow-Up

- User reloaded `main.lua`; fresh baseline from `(24,4)` had all five Cantlin
  doors open and `RUNTIME_BLOCKS map=0x0A none`.
- Merchant 2 / `Weapons Merchant` at `(22,6)` still had no adjacent path from
  the public component. Frontier check reported `hidden_bridge_candidates=0`,
  so no new bridge candidate was promoted.
- Entrance return from `(24,4)` toward `(15,1)` found and verified
  `(16,1).east` from `(17,1)->LEFT`.
- Merchant 1 route work then promoted these same-origin verified blockers:
  `(8,4).south`, `(11,4).south`, `(11,8).south`, `(12,8).south`,
  `(10,8).south/west`, `(10,7).west`, `(9,6).south`, `(6,5).east`,
  `(7,6).north`, and `(9,6).north`.
- With the runtime overlay active, the route chain completed to `(4,9)`, then
  reached Merchant 1 stand probes `(8,7)` and `(8,6)`. No prompt proof was
  collected: Merchant 1 moved from `(8,6)` to `(8,5)` and then to `(12,5)`
  before a stable TALK attempt.
- CURRENT LIVE CHECKPOINT: Cantlin `(8,6)`, NPCs frozen, menu closed, runtime
  overlay `RUNTIME_BLOCKS map=0x0A count=10` cells. `(9,6)` now has both
  `north` and `south` runtime directions. Reload `main.lua` to absorb source
  blockers if runtime is cleared.
- NEXT: use object-selected autowalk / targeted survey for moving Merchant 1,
  or pivot to more static service NPCs (`Merchant 5`, `Merchant 6`,
  `Merchant 7`, `Merchant 3`).

## 2026-07-09 Cantlin Merchant 5 Route Pass

- Reload baseline after user reloaded `main.lua`: `POSITION map=0x0A(Cantlin)
  x=8 y=6`, door RAM `0=(26,9) 1=(15,25) 2=(14,25) 3=(4,21) 4=(8,25)`,
  `RUNTIME_BLOCKS map=0x0A none`, menu closed.
- Target: Merchant 5 at `(2,12)`. Initial adjacent plan from `(8,6)` was
  `5 south, 6 west` to north stand `(2,11)`, facing south.
- CLEAN / PROMOTED with same-origin `probe_edge_verify:...,3`:
  `(8,11).north`, `(2,11).north`, `(3,11).east`, `(3,12).east`,
  `(3,13).east`, `(3,14).east`, `(3,15).east`, `(2,15).south`, and
  `(3,15).south`.
- RUNTIME: mirrored with `add_blocked_edge`; final runtime overlay is
  `RUNTIME_BLOCKS map=0x0A count=8`, with `(3,15)` carrying both `east` and
  `south`.
- CURRENT LIVE CHECKPOINT: Cantlin `(3,16)`, NPCs frozen, menu closed. Latest
  non-moving planner for Merchant 5 reports `Approach: 2 west, 3 north, 1
  east`, face north, targeting stand `(2,13)` beside Merchant 5 `(2,12)`.
- NEXT: after reload/runtime sync, retry `auto_walk_blocker:2,13` from
  `(3,16)` or use the adjacent planner again if the live position changes.

## 2026-07-09 Cantlin Merchant 5 Route Continuation

- Continued from `(3,16)` using `auto_walk_blocker:2,13` and mirrored each
  newly verified source-only edge into runtime with `add_blocked_edge`.
- CLEAN / PROMOTED with same-origin `probe_edge_verify:...,3`:
  `(1,16).east` from `(2,16)->LEFT`, `(1,17).east` from `(2,17)->LEFT`,
  `(2,18).north` from `(2,17)->DOWN`, `(3,18).north` from `(3,17)->DOWN`,
  `(4,18).north` from `(4,17)->DOWN`, `(3,11).north` from `(3,10)->DOWN`,
  `(1,11).north` from `(1,10)->DOWN`, `(5,15).north` from `(5,14)->DOWN`,
  `(6,15).north` from `(6,14)->DOWN`, and `(7,15).north` from
  `(7,14)->DOWN`.
- Each verifier result was `classification=confirmed_blocked`, `moved=0
  blocked=3`, with no drift, map change, interruption, or teleport artifact
  suspicion.
- CURRENT LIVE CHECKPOINT: Cantlin `(7,14)`, NPCs frozen, menu closed, runtime
  overlay `RUNTIME_BLOCKS map=0x0A count=10` for the continuation edges.
- NEXT: reload `main.lua` to absorb this source batch, then retry
  `auto_walk_blocker:2,13` from `(7,14)`. If continuing without reload, the
  runtime overlay already includes the continuation edges.

## 2026-07-09 Cantlin Merchant 5 Second Reload Continuation

- User reloaded `main.lua`; baseline confirmed Cantlin `(7,14)`, all five
  door slots still open, menu closed, and `RUNTIME_BLOCKS map=0x0A none`.
- Continued `auto_walk_blocker:2,13` and mirrored each newly verified
  source-only edge into runtime with `add_blocked_edge`.
- CLEAN / PROMOTED with same-origin `probe_edge_verify:...,3`:
  `(8,15).north` from `(8,14)->DOWN`, `(8,18).east` from `(9,18)->LEFT`,
  `(1,18).south` from `(1,19)->UP`, `(2,18).south` from `(2,19)->UP`,
  `(3,18).south` from `(3,19)->UP`, `(5,18).south` from `(5,19)->UP`, and
  `(4,18).south` from `(4,19)->UP`.
- Each verifier result was `classification=confirmed_blocked`, `moved=0
  blocked=3`, with no drift, map change, interruption, or teleport artifact
  suspicion. The `(5,19)->UP` route had an earlier settle drift before reroute,
  but the same-origin verifier itself was clean.
- CURRENT LIVE CHECKPOINT: Cantlin `(4,19)`, NPCs frozen, menu closed, runtime
  overlay `RUNTIME_BLOCKS map=0x0A count=7` for the newest edges.
- Latest parked-NPC planner to Merchant 5 `(2,12)` still reports a route to
  stand `(2,13)`: `2 east, 1 north, 5 west, 5 north, 1 east`, face north.
- NEXT: reload `main.lua` to absorb this source batch, then retry
  `auto_walk_blocker:2,13` from `(4,19)`. If continuing without reload, the
  runtime overlay already includes the newest edges.

## 2026-07-09 Cantlin Merchant 5/6 Follow-Up

- Started from the user's next reload with the hero at Cantlin `(4,19)`.
  The command menu was open on `TALK`; `simulate_raw_sequence:B,24,60` closed
  it without using `clear_input`.
- Merchant 5 `(2,12)` follow-up:
  - Promoted same-origin `probe_edge_verify:...,3` blockers:
    `(6,18).south`, `(7,18).south`, `(8,18).south`, `(8,17).east`,
    `(8,16).east`, `(8,15).east`, `(5,18).north`, `(6,18).north`,
    `(7,18).north`, `(8,17).west`, `(8,16).west`, `(7,15).south`,
    `(6,15).south`, `(5,16).east`, `(5,16).south`, `(5,15).west`,
    and `(5,16).west`.
  - `debug_pathfind_adjacent_skip_npcs:2,12` found no adjacent public route,
    and `debug_route_frontier_skip_npcs:2,13,30` had
    `hidden_bridge_candidates=0`.
  - TALK from `(4,12)` facing west produced only:
    `Come buy my radishes! They are fresh and cheap. Buy thy radishes today!`
    Promoted object override: cell `(2,12)` is `Radish Merchant`,
    `service=false`.
- Merchant 6 `(7,12)` route follow-up from practical entrance `(15,1)`:
  - Promoted same-origin `probe_edge_verify:...,3` blockers
    `(14,11).east` from `(15,11)->LEFT`, `(7,11).north` from
    `(7,10)->DOWN`, `(15,12).north` from `(15,11)->DOWN`,
    `(8,12).east` from `(9,12)->LEFT`, `(8,11).east` from
    `(9,11)->LEFT`, and `(7,11).west` from `(6,11)->RIGHT`.
  - After runtime injection, `debug_pathfind_adjacent_skip_npcs:7,12` chose
    stand `(8,12)` via `9 south, 6 west, 3 south, 1 west, 1 north`, facing
    west.
- Live stop condition:
  - Current live position: Cantlin `(15,1)`.
  - NPCs frozen; command menu closed.
  - Runtime overlay: `RUNTIME_BLOCKS map=0x0A count=16`, including
    `7,11(north,west)`, `8,11(east)`, `8,12(east)`, `14,11(east)`,
    and `15,12(north)`.
  - Auto-walk is blocked before planning because `PREV.dialogue="16Bill"`
    remains cached even though no real menu/dialogue is active.
- Source fix made this pass:
  - `field_action_guard.lua` ignores active dialogue when `dialogue_text` is a
    passive status/name fragment.
  - `main.lua` passes `dialogue_text = PREV.dialogue` into the field-action
    guard state.
  - `text.lua` classifies short digit-prefixed name fragments such as
    `16Bill` as passive field status noise.
  - Regression tests added to `test_field_action_guard.lua` and
    `test_text.lua`.
- Next pickup after manual FCEUX `main.lua` reload:
  1. Confirm baseline:
     `bash ./dw_commands.sh --replace --timeout 25 --wait "UPPER_STATE" report_upper_dialogue_state report_menu_state report_position report_runtime_blocks`
  2. Re-check Merchant 6 adjacency:
     `bash ./dw_commands.sh --replace --timeout 25 --wait "Debug pathfind adjacent" freeze_npcs 'debug_pathfind_adjacent_skip_npcs:7,12' report_position report_runtime_blocks`
  3. If it still chooses `(8,12)`, route/probe:
     `bash ./dw_commands.sh --replace freeze_npcs 'auto_walk_blocker:8,12' report_position report_path_state report_runtime_blocks`

## 2026-07-09 Cantlin Merchant 6 Counter Resolution

- User reloaded `main.lua`; fresh baseline from Cantlin `(15,1)` had menu
  closed, no lower dialogue, and `RUNTIME_BLOCKS map=0x0A none`.
- Merchant 6 `(7,12)` adjacent-route blockers promoted with same-origin
  `probe_edge_verify:...,3`, each `classification=confirmed_blocked`,
  `moved=0 blocked=3`, no NPC clutter:
  `(8,13).east` from `(9,13)->LEFT`, `(6,11).north` from `(6,10)->DOWN`,
  `(8,13).south` from `(8,14)->UP`, `(7,13).south` from `(7,14)->UP`,
  `(6,12).west` from `(5,12)->RIGHT`, `(6,11).west` from `(5,11)->RIGHT`,
  `(6,13).west` from `(5,13)->RIGHT`, and `(6,13).south` from
  `(6,14)->UP`.
- After runtime injection, `debug_pathfind_adjacent_skip_npcs:7,12` returned
  `No path found`; `debug_route_frontier_skip_npcs:7,12,40` reported
  `target_reachable=false`, `bridge_candidates=12`,
  `hidden_bridge_candidates=0`. The top bridge entries were the newly
  confirmed runtime blockers plus prior modeled directional blockers.
- Counter-stand tests:
  `(9,12)` facing west -> `There is no one there`.
  `(7,14)` facing north -> `There is no one there`.
  `(5,12)` facing east -> `Welcome. We deal in tools. What can I do for thee?`
  with merchant state `mode=action`, selection `Buy`.
- Source updates: `objects.lua` labels `Merchant 6` as `Tool Merchant` and
  routes the service to `(5,12)` facing east. `main.lua` / `text.lua` now avoid
  storing lower-dialogue plus stale command/status overlays as the processed
  upper marker; live evidence included
  `COMMAND BillTALK ... LV 16 STATUS ITEM`.
- Current live checkpoint after closing the shop/farewell: Cantlin `(5,12)`,
  NPCs frozen, command menu closed, no lower dialogue, merchant inactive,
  runtime overlay count 5:
  `6,11(north,west)`, `6,12(west)`, `6,13(south,west)`,
  `7,13(south)`, `8,13(east,south)`.
- NEXT: manually reload `main.lua`, then route to Services -> `Tool Merchant`;
  expected public stand is `(5,12)` facing east. Continue remaining Cantlin
  service discovery after that reload.

## 2026-07-09 Cantlin Tool Merchant Return-To-Entrance Pass

- User reloaded `main.lua`; fresh baseline confirmed the previous Tool Merchant
  source changes were live. Services filter reported `Tool Merchant` at object
  `(7,12)` with interaction stand `(5,12)` facing east.
- Active target: return route from the Tool Merchant/public-stand side toward
  the practical Cantlin entrance `(15,1)`.
- CLEAN / PROMOTED with same-origin `probe_edge_verify:...,3`; every verifier
  had `classification=confirmed_blocked`, `moved=0 blocked=3`, no drift,
  no map change, no interruption, and no teleport-artifact suspicion:
  `(6,1).west`, `(6,2).west`, `(6,3).west`, `(6,4).west`,
  `(6,5).west`, `(6,6).west`, `(7,7).west`, `(6,6).south`,
  `(7,7).south`, `(13,5).west`, `(12,4).south`, `(13,6).west`,
  `(13,7).west`, `(12,8).north`, `(10,1).south`, `(13,2).west`,
  `(12,1).south`, `(13,3).west`, `(12,4).north`, `(11,1).south`,
  `(11,4).north`, `(11,4).west`, `(9,2).east`, `(9,3).east`,
  `(9,4).east`, `(9,4).south`, `(7,4).south`, `(11,8).north`,
  `(10,7).east`, `(10,6).east`, and `(10,6).north`.
- Open / not promoted from this pass: route movement cleanly entered
  `(5,2..7)`, `(6,7)`, `(6,8)`, `(7,8)`, `(8,5..8)`, `(9,5)`,
  `(10,5)`, `(11,5)`, `(12,5)`, `(12,6)`, `(11,2)`, and `(12,2)`
  through adjacent route steps before later false-wall retries.
- Runtime mirrors were injected with `add_blocked_edge` after each source patch.
  Final runtime checkpoint: Cantlin `(10,5)`, NPCs frozen, menu closed, no
  lower dialogue or merchant state, `RUNTIME_BLOCKS map=0x0A count=25`.
  Current-pass runtime cells include `6,1(west)`, `10,1(south)`,
  `11,1(south)`, `12,1(south)`, `6,2(west)`, `9,2(east)`,
  `13,2(west)`, `6,3(west)`, `9,3(east)`, `13,3(west)`,
  `6,4(west)`, `7,4(south)`, `9,4(east,south)`,
  `11,4(north,west)`, `12,4(north,south)`, `6,5(west)`,
  `13,5(west)`, `6,6(south,west)`, `10,6(east,north)`,
  `13,6(west)`, `7,7(south,west)`, `10,7(east)`, `13,7(west)`,
  `11,8(north)`, and `12,8(north)`.
- Verification during the pass: each promoted edge followed TDD red/green
  updates in `test_map_reader.lua` and `map_reader.lua`; final
  `luajit.exe test_map_reader.lua` passed 58 tests.
- NEXT: manually reload `main.lua` before judging these new source blockers
  without the runtime overlay. Then retry:
  `.\dw_commands.ps1 --replace --timeout 60 --wait "AUTO_WALK_BLOCKER" freeze_npcs "auto_walk_blocker:15,1" report_position report_runtime_blocks report_menu_state`
  If continuing before reload, the current runtime overlay already mirrors this
  batch.

## 2026-07-09 Cantlin Tool Merchant Completion / Merchant 7 Pass

- CLEAN reload baseline: Cantlin `(10,5)`, five opened door slots,
  `RUNTIME_BLOCKS none`, NPCs frozen, menu/dialogue closed.
- CLEAN / PROMOTED by same-origin `probe_edge_verify:...,3`; each result was
  `classification=confirmed_blocked`, `moved=0 blocked=3`, with no drift,
  map change, interruption, NPC block, timing suspicion, or teleport artifact:
  `(7,6).east` from `(8,6)->LEFT`, `(9,6).west` from
  `(8,6)->RIGHT`, `(23,21).east` from `(24,21)->LEFT`,
  `(24,22).north` from `(24,21)->DOWN`, `(25,22).north` from
  `(25,21)->DOWN`, `(26,22).north` from `(26,21)->DOWN`, and
  `(27,24).north` from `(27,23)->DOWN`.
- With the first two edges mirrored live, `auto_walk_blocker:15,1` completed
  from the Tool Merchant side and `auto_walk_blocker:5,12` completed from the
  entrance, proving the Tool Merchant stand route in both directions.
- Merchant 3 targeted parked-NPC survey reached target `(12,23)` from
  `(5,12)`, but the restored NPC was mobile (`move=0xEE`) and wandered to
  `(13,18)` before TALK. No Merchant 3 role or stand was promoted.
- Merchant 7 is stationary at `(27,26)` (`move=0x00`). The broad targeted
  survey hit its route-churn cap with 33 blocked events and was downgraded to
  `command_timing_or_state_issue`; `SURVEY_STRONG_CANDIDATES none`. DO NOT
  PROMOTE that broad suspect list. The five Merchant 7 edges above were later
  isolated and direct-verified from normal walked origins.
- The focused `auto_walk_blocker:25,26` route completed after those runtime
  mirrors. From stand `(25,26)` facing east, TALK opened:
  `We deal in weapons and armor. Dost thou wish to buy anything today?`
  `objects.lua` now labels Merchant 7 as `Weapons Merchant` and stores the
  fixed public counter stand `(25,26)` facing east.
- Current live checkpoint: Cantlin `(25,26)`, NPCs frozen, command menu and
  dialogue closed, `RUNTIME_BLOCKS map=0x0A count=7`. Source changes require
  a manual `main.lua` reload before the seven blockers and Merchant 7 label
  are live without the overlay.
- NEXT after reload: route from Merchant 7 stand back to entrance `(15,1)`;
  then validate the full entrance-to-Merchant 7 stand route.

## 2026-07-09 Cantlin Merchant 7 Return And Reverse Pass

- Reload baseline: Cantlin public stand `(25,26)`, stationary Merchant 7 at
  `(27,26)` labeled `Weapons Merchant`, all five doors open, menu/dialogue
  closed, and `RUNTIME_BLOCKS none`.
- CLEAN / PROMOTED during stand-to-entrance routing, each with same-origin
  `probe_edge_verify:DIR,3`, `moved=0 blocked=3`,
  `classification=confirmed_blocked`, and no NPC block, timing suspicion,
  timeout, drift, map change, interruption, or teleport artifact:
  `(25,22).south`, `(23,23).east`, `(24,22).south`, `(24,24).north`,
  `(26,22).south`, `(27,20).south`, `(24,14).south`, `(15,13).south`,
  `(16,14).west`, `(16,14).south`, `(14,14).south`, `(13,14).south`,
  `(12,14).south`, `(11,13).south`, and `(12,14).west`.
- RESULT: after runtime mirroring, `auto_walk_blocker:15,1` completed at the
  practical entrance `(15,1)`.
- CLEAN / PROMOTED during full reverse validation toward `(25,26)`:
  `(21,11).west` from `(20,11)->RIGHT`, `(21,26).west` from
  `(20,26)->RIGHT`, `(21,27).west` from `(20,27)->RIGHT`, and
  `(21,28).west` from `(20,28)->RIGHT`; each verifier was again clean 3/3.
- TRANSITION EVIDENCE: after those lower-wall mirrors, A* planned through
  `(20,28)->DOWN` into `(20,29)`. Movement succeeded, then immediately logged
  `EVENT: map change -> 0x01 (World Map)` at `(73,102)`. This is not an engine
  wall. Source now models `(20,29).north` as a pathfinding transition guard so
  ordinary in-town routes do not select it.
- RECOVERY: `(73,102)->DOWN` reached `(73,103)` and triggered a Starwyvern.
  The first RUN attempt failed; the second succeeded. `probe_edge:UP` from
  `(73,103)` re-entered Cantlin at `(15,0)`. A subsequent DOWN probe carried
  to `(15,2)`.
- STATE BOUNDARY: re-entering Cantlin cleared the current-pass runtime overlay
  and all five opened-door RAM slots. Current live checkpoint is Cantlin
  `(15,2)`, `RUNTIME_BLOCKS none`, all doors closed, one key. Source tests pass,
  but current-pass source blockers and the transition guard require a manual
  `main.lua` reload.
- NPC PARK NOTE: Merchant 3's restored position was `(15,14)`. While the hero
  occupied that cell, restore was deferred and the absent slot temporarily
  shifted generic labels. Moving the hero to `(15,15)` restored slot 8 and
  normalized `Radish Merchant`, `Tool Merchant`, and `Weapons Merchant`; this
  was temporary runtime state, not label-source corruption.
- NEXT: reload the all-doors-open save state, reload `main.lua`, and retry
  `auto_walk_blocker:25,26` from practical entrance `(15,1)`. If A* selects a
  different south-edge transition, record it and stop rather than leaving town.

## 2026-07-09 Cantlin Merchant 7 Bidirectional Completion

- Initial restored baseline: Cantlin `(8,25)`, all five door RAM slots open,
  menu/dialogue closed, and `RUNTIME_BLOCKS none`; `(20,29).north` was live.
- CLEAN / PROMOTED before the mid-pass emulator restart, each via same-origin
  `probe_edge_verify:DIR,3`, `moved=0 blocked=3`,
  `classification=confirmed_blocked`, and no NPC/timing/drift/transition
  contamination: `(8,24).south`, `(10,25).west`, `(23,11).north`,
  `(22,11).north`, `(21,11).north`, `(21,21).west`, `(21,26).east`.
- The first route reached Merchant 7 stand `(25,26)`. A return run exposed
  `(21,26).east`, then the user restarted the laggy emulator and restored the
  same all-doors-open save.
- Post-restart baseline: Cantlin `(8,25)`, all five doors open, menu closed,
  `RUNTIME_BLOCKS none`. `inspect_move:22,26,LEFT` confirmed `(21,26).east`
  was active after navigation module refresh.
- CLEAN / PROMOTED after restart with the same verifier guarantees:
  `(13,8).south`, `(17,14).north`, `(21,13).west`, `(23,21).north`,
  `(22,21).north`, `(21,21).north`, `(24,24).east`, `(23,25).east`,
  and `(19,25).east`.
- LIVE COMPLETION: with nine post-restart runtime mirrors, uninterrupted
  `auto_walk_blocker:25,26` completed from entrance `(15,1)`,
  `auto_walk_blocker:15,1` completed from stand `(25,26)`, and a final
  uninterrupted `auto_walk_blocker:25,26` completed again from `(15,1)`.
- Current live checkpoint: Cantlin `(25,26)`, all five doors open, menu and
  dialogue closed, runtime overlay count 9. The nine post-restart source
  directions require manual `main.lua` reload before overlay-free validation.
- NEXT: reload `main.lua`, then continue the next unclassified Cantlin service;
  mobile Merchant 3 remains the strongest targeted follow-up.

## 2026-07-10 Cantlin Dialogue-Merchant Classification

- Reload baseline was Cantlin `(25,26)`, all five doors open, menu closed,
  `RUNTIME_BLOCKS none`, and the restored-state `(13,8).south` source blocker
  active.
- A frozen single-target survey toward Merchant 3 initially planned 22 steps
  from `(25,26)` toward target `(3,27)`. It reached `(3,29)` after extensive
  rerouting, then stopped at `route_churn_cap` with 33 blocked events and
  `failure_class=command_timing_or_state_issue`.
- SCRATCH ONLY / DO NOT PROMOTE: the broad suspect cells were
  `22,27|21,27|22,28|20,26|19,26|19,27|19,28|17,24|18,25|15,23|16,25|`
  `12,24|13,25|10,25|8,24|8,26|8,27|8,28|3,28`.
  Do not patch any of these without isolated same-origin verification.
- Merchant 3 was subsequently frozen at `(4,27)`. Debug landing `(5,27)`
  facing west and live TALK read: `My Grandfather Wynn once had a shop on the
  east side of Hauksness.`
- Merchant 1 was frozen at `(1,0)`. After resetting the blocked-facing
  movement residue with a same-cell `(1,1)` re-land, live TALK facing north
  read: `Grandfather used to say that his friend, Wynn, had buried something
  of great value at the foot of a tree behind his shop.`
- RESULT: both are dialogue-only hint NPCs. `objects.lua` keeps their generic
  NPC labels but adds `Merchant 1` and `Merchant 3` to Cantlin's
  `SERVICE_EXCLUSIONS`. `luajit test_objects.lua` passes all 92 tests.
- STATE NOTE: a one-frame blocked facing tap can leave movement bytes at
  `move=0x10 sub=0x10`, causing delayed field actions. A same-cell debug
  re-land reset both to `0x00`; the delayed dialogue was genuine Merchant 1
  proof, not route evidence.
- Current checkpoint: Cantlin `(1,1)`, all five doors open, menu/dialogue
  closed, NPCs frozen, and `RUNTIME_BLOCKS none`. Reload `main.lua`, confirm
  the cleaned Services list, then continue only the confirmed shop routes.

## 2026-07-10 Cantlin Isolated Pocket And `llE` Route Cancellation

- Reload baseline: Cantlin `(1,1)`, all five doors open, menu/dialogue closed,
  `RUNTIME_BLOCKS none`; Merchant 1 and Merchant 3 both reported `service=false`.
- CLEAN / PROMOTED: entrance-route blocker hunt stopped at normal origin
  `(1,1)` on `(1,1)->RIGHT` and `(1,1)->DOWN`. Same-origin
  `probe_edge_verify:RIGHT,3` and `probe_edge_verify:DOWN,3` each returned
  `attempts=3 moved=0 blocked=3 classification=confirmed_blocked`, with no
  timeout, NPC block, drift, map change, interruption, or teleport artifact.
- Runtime mirrors were destination/approach pairs `(2,1).west` and
  `(1,2).north`. With both active, normal and skip-NPC planners each visited
  one tile and returned `No path found`; `(1,1)` is an isolated debug pocket.
- Repositioned to practical entrance `(15,1)` after clearing runtime mirrors.
- Mobile Weapons Merchant 2 was first frozen at `(5,10)`. Explicit target
  `(5,11)` was occupied by Guard 2, so `auto_walk_blocker:5,11` resolved the
  guard object rather than a coordinate target. Do not reuse occupied stands.
- That first route reached `(15,4)` and canceled with `PREV.dialogue_len=3`.
  After the residue cleared, Weapons Merchant 2 was frozen at `(8,10)` and an
  unoccupied north stand `(8,9)` produced the same immediate cancellation.
- BUG / LIVE REPRO: frame 51306 logged `CAN_WALK false ... PREV.dialogue_len=3`
  with no menu, submenu, merchant UI, or upper dialogue. Frame 51335 then
  decoded the exact phantom dialogue as `llE`. This is the hero-name suffix
  fused to the uppercase Experience/status label, not real game dialogue.
- FIX: `text.is_passive_field_status_noise("llE")` now uses the existing fused
  status-label token detector. `field_action_guard.dialogue_blocks_movement`
  centralizes passive-versus-real dialogue classification, and `main.lua`'s
  per-frame `can_walk` gate uses it instead of requiring empty dialogue text.
- TESTS: 58 map tests, 58 text tests, and 7 field-action-guard tests pass.
- CURRENT: Cantlin `(15,4)`, all five doors open, menu/dialogue closed,
  `RUNTIME_BLOCKS none`. NPC freeze released after route cancellation; mobile
  Weapons Merchant 2 was last seen at `(0,3)` and will move before reload.
- NEXT: reload `main.lua`, report and freeze NPCs, choose a currently unoccupied
  adjacent coordinate for Weapons Merchant 2, and retry the route.

## 2026-07-10 Cantlin Command-Menu `llE` Suffix

- LIVE REPRO after reload: SEARCH and TALK results were announced as
  `Bill searched the ground all about. llE`, `But there found nothing. llE`,
  and `'There is no one there. llE`.
- `report_upper_dialogue_state` isolated the residue to wrapped lower-dialogue
  base nametable 1, scan index 10, row 8: `text="llE"`.
- ROOT CAUSE: standalone passive-noise filtering did not help when that row was
  concatenated with valid command-result rows. The per-row filter recognized
  status values and context-derived name fragments, but did not reject the
  already-known fused name/status-label token class.
- FIX / TEST: `filtered_dialogue_from_rows` now excludes fused status-label
  rows before concatenation. The exact wrapped PPU regression first failed with
  the unwanted suffix, then passed; all 59 focused text tests pass.
- CURRENT: Cantlin `(15,4)`, all five doors open, one key, menu/dialogue closed,
  `RUNTIME_BLOCKS none`. Reload `main.lua`, then retry SEARCH and empty-space
  TALK before resuming the Merchant 2 route.

## 2026-07-10 Merchant 2 Route And Stale Services Selection

- USER LIVE VALIDATION: all command-menu actions, Merchant 2, SPELL, and ITEM
  spoke correctly after reload; clean log results no longer contained `llE`.
- Baseline: Cantlin `(15,5)`, mobile Weapons Merchant 2 at `(15,4)`, all five
  doors open, one key, menu/dialogue closed, `RUNTIME_BLOCKS none`.
- CLEAN ROUTE: `(15,5)` to entrance `(15,1)` completed `4 north`; every seam
  moved and no blocker or dialogue cancellation occurred.
- CLEAN REVERSE ROUTE: after waiting for an interior patrol position, Merchant
  2 was frozen at `(14,4)`. Normal and skip-NPC adjacent planners both chose
  stand `(14,3)` with `2 south, 1 west` from entrance. The actual blocker-mode
  route completed with no runtime patch or speech residue.
- BUG / LIVE REPRO: after `debug_pathfind_adjacent` triggered
  `NAVIGATION_MODULES_REFRESHED`, two `next_filter` commands announced
  `Services`, but `current_object` and `next_object` remained
  `Eastern Building Door (10 of 25)`.
- ROOT CAUSE: `main.lua` replaced `package.loaded["objects"]` and re-registered
  object commands, but route manager retained its pre-reload local `objects`
  table. Filter label/count and route description therefore read different
  module instances.
- FIX / TDD: `route_manager.refresh_navigation_modules()` now rebinds
  `objects = require "objects"`. The new regression failed with stale `Chest`
  and passed with replacement `Weapons Merchant`; all 104 route-manager tests
  pass.
- CURRENT: Cantlin `(14,3)`, all five doors open, one key, menu/dialogue closed,
  `RUNTIME_BLOCKS none`, NPC freeze released; Merchant 2 last reported `(16,3)`.
- NEXT: reload `main.lua`; switch from All to Services, verify four entries and
  no stale door selection, then run object-selected `auto_walk_blocker` to the
  mobile Weapons Merchant.

## 2026-07-10 Services Fix Validation And Category Audit

- LIVE FIX VALIDATED: after explicit `NAVIGATION_MODULES_REFRESHED`, Services
  reported `Inn (1 of 4)` and `current_object` matched. The stale door/25-item
  selection did not recur.
- Four Services entries: mobile Weapons Merchant, Inn, Tool Merchant, fixed
  Weapons Merchant. Object-selected `auto_walk_blocker` refreshed Merchant 2 to
  `(17,4)`, walked three east from `(14,3)` to `(17,3)`, faced south, and held
  the target. No blocker, runtime patch, menu, or dialogue residue occurred.
- TIMING ONLY / NO PATCH: batching `reload_navigation_modules next_filter` in
  one emulator frame produced `NPCs. No objects`; issuing reload alone, waiting
  two seconds, then filtering produced `NPCs ... (1 of 19)`. Normal player
  filter timing is unaffected.
- REACHABILITY AUDIT: Services `4 reachable / 0 unreachable`; Travel `1 / 0`;
  Doors `5 / 0`; NPCs `18 / 1`. The sole unreachable NPC was Radish Merchant
  `(2,12)`.
- PRIOR PROOF: TALK from `(4,12)` facing west produced the radish dialogue.
  Fresh blocker-mode routing from `(17,3)` planned 22 steps and reached `(4,12)`
  cleanly with every seam moved and `RUNTIME_BLOCKS none`.
- ROOT CAUSE: the role override labeled Radish Merchant and set `service=false`
  but could not store a non-service interaction stand, so NPC pathability tried
  the sealed adjacent pocket.
- FIX / TDD: explicit role overrides may now copy `interaction_x/y`, facing,
  and label before the non-service return. Cantlin `(2,12)` uses interaction
  `(4,12)`, facing west, label `counter`. The focused test failed on nil
  interaction X and now passes; all 92 object tests pass.
- CURRENT: Cantlin `(4,12)`, all five doors open, one key, menu/dialogue closed,
  `RUNTIME_BLOCKS none`.
- NEXT: reload `main.lua`, rerun NPC reachability, and expect all 19 reachable.

## 2026-07-10 Cantlin Damage Barrier And Object-Reload Timing

- LIVE HAZARD EVIDENCE: autowalk from Radish Merchant stand `(4,12)` toward
  Travel exit `(14,29)` entered the lower-center striped barrier. The route
  walked across `(15,26)` through `(11,26)`, and the next status read showed
  4 HP. Source previously had no Cantlin hazard cells, so normal and
  hazard-allowed planners initially produced the same route with `hazards=0`.
- MAP ORIENTATION: the 30x30 Cantlin reference map places the striped barrier
  at `y=26: x=11..18`, `y=27: x=11,18`, and
  `y=28: x=11..13,16..18`. These 16 cells are now damage hazards in
  `MAP_HAZARD_CELLS[0x0A]`; focused map tests cover every cell and a nearby
  safe negative.
- CLEAN BLOCKER: from live origin `(12,26)`, `probe_edge_verify:DOWN,3`
  returned `moved=0 blocked=3 classification=confirmed_blocked` for
  `(12,27).north`, which is now directional source data.
- LIVE PATCH CHECK: from `(12,26)`, normal exit planning detoured while
  hazard-allowed planning took the short route through `(13,26)` and `(14,26)`
  with `hazards=2`. North escape then hit `(12,25).south`; a verifier became
  inconclusive because the patched hazard origin is intentionally no longer a
  valid verifier landing, so that second seam was not promoted.
- RECOVERY / ROUTE: debug teleport moved the 4-HP hero to known-safe `(9,25)`.
  Normal and hazard-allowed entrance plans agreed on 30 steps with `hazards=0`,
  and `auto_walk_blocker:15,1` completed the route without a blocker or hazard.
- TIMING BUG REPRO: same-frame `reload_navigation_modules next_filter`
  produced `FILTER: NPCs. No objects`; splitting the commands had previously
  shown all 19 NPCs. Root cause was a newly required `objects` module with no
  current-map list until a later `check_refresh` frame.
- FIX / TDD: `object_commands.refresh_after_module_reload()` synchronously
  refreshes the live map, and `register()` invokes it only when the new object
  module reports a refresh is needed. `main.refresh_navigation_modules()` also
  primes explicitly before registration. The focused regression failed on the
  missing prime and now passes all 3 object-command tests.
- LIVE TIMING VALIDATION: the exact same-frame batch now reports
  `NPCs. Merchant 1 ... (1 of 19)` and `current_object` agrees.
- CURRENT: Cantlin practical entrance `(15,1)`, all five doors open, one key,
  menu/dialogue closed, `RUNTIME_BLOCKS none`; NPC filter is selected.

## 2026-07-12 Cantlin Premium Weapons Merchant Route, Eastern Wall

- CLEAN / PROMOTED: same-origin route failures plus direct raw probes confirmed
  `(28,10).west`, `(28,9).west`, `(26,8).south`, `(26,7).west`,
  `(26,8).west`, `(26,6).west`, `(28,5).north`, `(27,5).north`,
  `(26,5).north`, and `(26,5).west`.
- Existing runtime overlay reached 25 unique cells after these additions; all
  61 focused map-reader tests pass after each permanent promotion.
- CLEAN OPEN: normal autowalk crossed row 4 from `(25,4)` through `(26,4)`,
  `(27,4)`, and `(28,4)`. Keep those west/east approaches open.
- NOT A PASSTHROUGH: frontier rank 3 suggested `(28,4)->RIGHT` into type-12
  `(29,4)` with a hidden exit down. The same-origin probe entered `(29,4)` and
  immediately changed to World Map at `(73,102)`. Do not add `(29,4)` to
  Cantlin passthrough data.
- CURRENT: hero is outside Cantlin on World Map `(73,102)` after that boundary
  probe. Town route work requires restoring the user's all-doors-open state.
- ALREADY BLOCKED: earlier same-origin probing from normally reached `(27,12)`
  failed RIGHT into type-15 `(28,12)`, so frontier rank 2 is not a bridge.
- NEXT: after restore/reload, confirm Cantlin position and runtime overlay, then
  normally route to `(29,13)` and test frontier rank 1: probe UP into type-15
  `(29,12)`, followed by UP toward `(29,11)` only if entry succeeds.

## 2026-07-12 Cantlin Premium Merchant Pocket And Outer East Wall

- RESTORED BASELINE: hero at the TALK-proven Premium Weapons Merchant stand
  `(24,13)`, all five doors open, one key, and no runtime blocks.
- ISOLATED SERVICE STAND: normal source-only attempts and same-origin raw
  probes confirmed `(25,13).west`, `(24,14).north`, and `(23,13).east`
  blocked. With those three runtime mirrors, both normal and skip-NPC planners
  return `No path found`; the stationary merchant at `(24,12)` occupies the
  fourth side. Keep `(24,13)` as interaction proof, but do not yet claim it is
  a viable two-way service-route endpoint.
- DISPROVED TELEPORT ARTIFACT: `(25,6).north` appeared blocked immediately
  after `teleport_to:25,5`. After reacquiring `(25,5)` by normal movement, a
  clean DOWN probe crossed `(25,6)` and continued to `(25,7)`. Do not patch
  that approach.
- CLEAN HIDDEN BRIDGE: a normal 24-step route reached `(29,13)`. Raw UP crossed
  type-15 `(29,12)` to `(29,11)`, and reverse DOWN crossed it back to
  `(29,13)`. `(29,12)` is now a Cantlin passthrough cell with an A* regression.
- TYPE-15 `(28,12)` remains closed from both horizontal sides: earlier
  `(27,12)->RIGHT` and this pass's `(29,12)->LEFT` probes both blocked. Its
  north approach from `(28,11)->DOWN` remains the useful unresolved test.
- CLEAN / PROMOTED OUTER WALL: blocker-mode routes plus same-origin raw probes
  confirmed `(28,11).east`, `(28,10).east`, `(28,9).east`, `(28,8).east`,
  `(28,7).east`, and `(28,6).east`. Each edge has a focused map regression;
  all 61 map-reader tests pass.
- DIALOGUE BUG / FIX: normal movement completed `(29,6)->UP` to `(29,5)`, but
  a scrolling PPU sample cached `EE13994Bill` as dialogue and canceled the
  route. `13994` exactly matched the hero's current EXP. `text.lua` now treats
  an uppercase status-label cluster plus numeric value plus short capitalized
  name as passive field status noise. The exact live string no longer blocks
  movement; all 63 text tests and 7 field-action-guard tests pass.
- CURRENT: live FCEUX remains at Cantlin `(29,5)` with the pre-fix script and
  stale `PREV.dialogue="EE13994Bill"`; runtime overlay count is 9. The old
  script correctly refused a direct probe while that residue was cached.
- NEXT: manually reload `main.lua`, confirm `(29,5)`, then run
  `probe_edge:LEFT`. If `(29,5)->LEFT` blocks, promote `(28,5).east`; if it
  moves, continue normally down column 28 toward `(28,11)` and probe DOWN into
  `(28,12)`.

## 2026-07-12 Cantlin Premium Merchant Public Route Resolution

- CONFIRMED WALL COMPLETION: clean `(29,5)->LEFT` blocked, so
  `(28,5).east` joins the verified outer wall. The focused regression failed
  before source promotion and all 61 map-reader tests passed afterward.
- GUIDE / MAP ORIENTATION: NES guidance identifies the Flame Sword/Silver
  Shield seller as the locked weapon shop. The 30x30 reference map places
  Guard 4 `(24,12)` west of counter cell `(25,12)` and hidden corridor cells
  `(26,12)` / `(27,12)` reached through opened door `(26,9)`.
- DISPROVED STANDS: normal routes plus raw probes reconfirmed
  `(24,15)->UP` into `(24,14)`, `(26,13)->LEFT` into `(25,13)`, and
  `(24,10)->DOWN` into `(24,11)` blocked. TALK from `(24,10)` facing south
  returned `There is no one there`.
- PUBLIC STAND FOUND: from normally reached `(27,12)`, raw LEFT entered
  type-15 `(26,12)`. A second LEFT toward type-15 counter `(25,12)` blocked.
  TALK from `(26,12)` facing west opened the premium weapons/armor prompt.
- SOURCE / TDD: `MAP_PASSTHROUGH_CELLS[0x0A]` now includes `(26,12)` while
  `(25,12)` stays closed. `Premium Weapons Merchant` now uses interaction
  stand `(26,12)`, facing west. Synthetic map tests cover all three type-15
  cells `(25..27,12)`, keep the counter closed, and require A* to finish on
  `(26,12)`. All 61 map and 96 object tests pass.
- LIVE ROUTE VALIDATION: after `reload_navigation_modules`, blocker-mode
  autowalk completed premium stand `(26,12)` -> practical entrance `(15,1)`
  and the reverse route, each in 24 steps. Selected-object autowalk from the
  stand reported `Already there`, faced west, and held Guard 4 at `(24,12)`.
- CURRENT: hero `(26,12)`, all five doors open, one key, runtime overlay only
  `(28,5).east`. Reload `main.lua` before the user's final Services-selected
  route check; source already contains that mirrored edge.
## 2026-07-12 Cantlin Fairy Water Service Route

- USER VERIFIED: Premium Weapons Merchant Services route and both Flame Sword /
  Silver Shield cursor rows passed manually after full reload.
- CLEAN RELOAD BASELINE: hero `(26,12)`, all five doors open, one key, and no
  runtime blocks.
- PREMIUM RETURN: source-only blocker-mode route completed from `(26,12)` to
  practical entrance `(15,1)`.
- DYNAMIC NPC, NOT MAP DATA: an explicit `(20,13)` coordinate route initially
  treated roaming Merchant 1 on that cell as its target and stopped adjacent
  at `(20,12)`. Services-selected Fairy Water Merchant routing then correctly
  entered fixed stand `(20,13)` and faced east toward Woman 2 `(22,13)`.
- CLEAN / PROMOTED: the return planned 17 steps but repeatedly blocked
  `(17,13)->LEFT` into `(16,13).east`. The route executor exhausted normal
  and seam retries with `npc_blocked=false` and `timing_suspect=false`; a
  separate same-origin `probe_edge:LEFT` also raw-held blocked from `(17,13)`.
- LIVE REROUTE: after `add_blocked_edge:17,13,LEFT`, return completed at
  `(15,1)`. A fresh Services-selected forward route then completed at
  `(20,13)` facing east.
- TDD: focused assertion failed with expected true / got nil before source.
  `MAP_DIRECTIONAL_BLOCKS[0x0A]["16,13"].east` now carries the verified
  edge; all 61 map-reader tests pass.
- CURRENT: hero `(20,13)`, all five doors open, one key, runtime overlay only
  `(16,13).east`. Reload `main.lua` before continuing.
## 2026-07-12 Cantlin Stable Service Slot Identities

- SOURCE-ONLY FAIRY RETURN: after full reload, baseline at (20,13) had all
  five doors open and no runtime blocks. Return completed at practical entrance
  (15,1), proving the new (16,13).east source edge.
- LIVE IDENTITY BUG: report_npcs showed inactive slot 5. Duplicate Merchant
  ordinals shifted: stable slot 10 at (8,3) became generic Merchant 3,
  service=false, while stable slot 13 at (2,12) inherited Inn, service=true,
  with inferred stand (4,12).
- ROOT CAUSE: parse_npcs() numbers only active duplicate sprites, while Cantlin
  role overrides depended on Merchant N display names. The names are therefore
  not stable when an earlier RAM slot is inactive.
- TDD / FIX: a 20-slot regression reproduces the live gap and failed because
  slot 10 was Merchant 3. apply_service_role_override() now checks optional
  stable object IDs first. Cantlin maps confirmed roles for slots 4, 10, 13,
  14, 15, 16, and 19, while retaining name fallbacks for compact older tests.
  The older Radish fixture now uses its real stable slot 13. All 97 object tests
  pass and objects.lua byte-compiles.
- LIVE MODULE VALIDATION: after reload_navigation_modules, slot 10 reports Inn,
  service=true, at (8,3); slot 13 reports Radish Merchant, service=false, at
  (2,12). Services exposes the Inn stand (8,5).
- CLEAN ROUTES: source-only entrance (15,1) <-> Inn (8,5) and entrance (15,1)
  <-> Tool Merchant (5,12) round trips completed with no blockers.
- CURRENT: hero (15,1), all five doors open, one key, RUNTIME_BLOCKS none.
  Reload main.lua before continuing.
## 2026-07-12 Cantlin Fixed-Service Circuit Completion

- FULL-RELOAD BASELINE: hero (15,1), all five doors open, one key, no runtime
  blockers. Stable service slots reported the intended labels and roles.
- FIXED WEAPONS: selected Services route completed entrance (15,1) -> stand
  (25,26), then returned source-only to (15,1).
- PREMIUM WEAPONS: selected Services route completed entrance (15,1) -> hidden
  stand (26,12), then returned source-only to (15,1).
- FAIRY WATER FORWARD: selected Services route completed entrance (15,1) ->
  fixed stand (20,13), facing east.
- CLEAN / PROMOTED: Fairy return initially planned 17 steps but stopped at
  (16,12)->LEFT into (15,12).east. Normal/seam retries ended blocked with
  npc_blocked=false and timing_suspect=false. A same-origin probe_edge:LEFT
  also raw-held blocked at (16,12). Runtime mirroring via
  add_blocked_edge:16,12,LEFT produced a clean return to (15,1).
- TDD: (15,12).east assertion failed expected true / got nil before source.
  The Cantlin directional entry now combines east=true with its existing
  north=true; all 61 map-reader tests pass.
- STATUS: all fixed essential service routes now complete in both directions.
  Roaming Weapons Merchant remains position-dependent by design.
- CURRENT: hero (15,1), all five doors open, one key, runtime overlay only
  (15,12).east. Reload main.lua before continuing.
## 2026-07-12 Cantlin NPC Clues And 27,6 Dialogue Lock

- USER NPC FINDINGS: Old Man 1 gives an important clue; Merchant 1 appears to
  give an armor-location clue; Person 2 may be another tool merchant.
- LIVE SLOT SNAPSHOT: Old Man 1 is npc_6 at (14,28), Merchant 1 is npc_2 at
  (9,7), Person 2 is npc_12 at (2,7), and the current (27,6) NPC is fixed
  Old Man 2 / npc_11.
- GUIDE ORIENTATION: NES script/layout references list two Cantlin tool shops.
  This supports testing Person 2 as the missing seller but is not live proof.
- REPRO: SEARCH at (27,6) first spoke normal search text, then lower dialogue
  stabilized as 1520Bill3. Object current/next/previous hotkeys all refused
  with Wait for dialogue to finish.
- DIAGNOSTIC: MENU_STATE had raw_open=false, cached_open=false, yesno=false,
  merchant_active=false, lower_len=9, scroll_tiles=24, base_nt=0. UPPER_STATE
  had PREV.dialogue, announced dialogue, lower, and previous lower all equal to
  1520Bill3. Raw lower rows included G 1520Bill3 and E13994LV 160.
- ROOT CAUSE / TDD: current Gold 1520 wrapped the capitalized hero name Bill
  and a trailing status digit. Exact passive-status and movement-guard tests
  failed before source. text.is_passive_field_status_noise now accepts a short
  capitalized name between leading and trailing numeric status fragments.
  All 63 text and 7 field-action-guard tests pass; text.lua byte-compiles.
- CURRENT: hero (27,6), no runtime blocks, old script still caches 1520Bill3.
  Reload main.lua. First validate command/object controls here, then route to
  Person 2 at (2,7) and TALK; promote a second Tool Merchant label only if the
  tool transaction prompt opens.
## 2026-07-12 Person 2 Approach And Overlap Contamination

- BASELINE: script functions recovered at (27,6); Person 2 is fixed npc_12 at
  (2,7), service=false.
- CONTAMINATED ORIGIN: report_npcs also placed fixed Old Man 2 / npc_11 on the
  hero's exact (27,6) cell. Person 2 routing then tested all four exits from
  that overlap. Route retries plus raw probes blocked west into (26,6).east,
  south into (27,7).north, north into (27,5).south, and east into
  (28,6).west. Do not promote any of these; normal movement could not have
  created the overlapping origin.
- RECOVERY: clear_runtime_blocks removed all three injected edges before the
  fourth could be mirrored. teleport_to:15,1 restored the known-safe practical
  entrance, confirmed with RUNTIME_BLOCKS none.
- SECOND DIALOGUE ARTIFACT: teleport/status redraw stabilized lower dialogue as
  BillE13E1399 16Bill. The old script refused Person 2 auto-walk before
  planning with Wait for dialogue to finish.
- TDD / FIX: exact passive-status and movement-guard tests failed before source.
  A narrow numeric/status pattern now recognizes a capitalized name fused to
  two G/E numeric fields followed by a digit-prefixed capitalized name.
  All 63 text tests and 7 field-action-guard tests pass; text.lua byte-compiles.
- CURRENT: hero (15,1), no runtime blocks, old script caches the second
  fragment. Reload main.lua, then retry auto_walk_blocker:2,7. TALK must open
  the tool transaction prompt before labeling Person 2 as the second Tool
  Merchant.

## 2026-07-12 Command-Result Numeric Status Slices

- LIVE ARTIFACTS: SEARCH/TAKE speech included trailing 6 and embedded 152:
  "Bill searched the ground all about. 6", "But there found 152 nothing.",
  "'There is no one there. 6", and "There is nothing to take here, Bill. 6".
  After the first fix/reload, SEARCH page one was clean but page two spoke the
  newly isolated middle slice "But there found 52 nothing."
- ROOT CAUSE: with the command menu closed, report_upper_dialogue_state showed
  lower numeric-only rows 6, 52, and 99 while the status window contained
  LV 16, G 1520, and E 13994. Horizontal redraw slices were being retained as
  ordinary numeric dialogue tokens.
- TDD / FIX: exact command-result regressions failed before source. text.lua now
  derives every contiguous slice from visible status values, then removes those
  unpunctuated slices only in suspicious redraw positions. Preservation tests
  keep genuine gold-reward, level-up, and "for 52 GOLD" price values. All 66
  text tests and 7
  field-action-guard tests pass; LuaJIT byte-compilation and diff check pass.
- CURRENT: hero (15,1), no runtime blocks, running script is pre-fix. Reload
  main.lua and retest command results before routing to Person 2 at (2,7).

## 2026-07-13 SEARCH 52 Deep Trace

- REPRO AFTER FULL RELOAD: page one spoke cleanly at frame 321; page two still
  spoke "But there found 52 nothing." at frame 381.
- DISPROVED HYPOTHESIS: a regression using fused live-style status rows passes,
  so fused status text alone does not explain why live filtering retains 52.
  The decisive transient arrangement disappears before a later state dump.
- DIAGNOSTIC CHANGE: text.describe_dialogue_filter_state reports primary and
  alternate lower rows, upper context rows, status decision, numeric candidates,
  and per-base filtered output. check_dialogue emits DIALOGUE_FILTER_TRACE once
  when a sentence contains an internal numeric token.
- VALIDATION: 67 text tests pass; text.lua and main.lua byte-compile; diff check
  passes.
- CURRENT: debug input accidentally invoked TALK once but caused no movement.
  Hero remains (15,1), RUNTIME_BLOCKS none. Reload main.lua and repeat failed
  SEARCH once, then inspect the automatic DIALOGUE_FILTER_TRACE before editing
  filtering behavior again.

## 2026-07-13 Golem Trigger And Closed-Door Service Pass

- GOLEM LIVE PROOF: World Map `(73,101)->UP` completed at `(73,100)`, followed
  by `EVENT: battle started` and `A Golem draws near!`. The battle snapshot had
  quest flags `0x40`; after victory `log_state` reported `0x42`. Fairy Flute
  sleep and the Golem victory dialogue were both captured. This is the fixed,
  one-time Cantlin boss cell, not an ordinary random encounter.
- TOWN RETURN: `probe_edge:DOWN` from `(73,100)` changed to map `0x0A` and
  landed at `(15,0)`. Baseline then showed every door slot `(0,0)` and
  `RUNTIME_BLOCKS map=0x0A none`.
- CLOSED-DOOR ROUTES: with `freeze_npcs` issued separately before each leg,
  entrance `(16,0)` round trips completed for Tool Merchant 2 `(4,7)`, Inn
  `(8,5)`, Tool Merchant `(5,12)`, Fairy Water Merchant `(20,13)`, and Weapons
  Merchant `(25,26)`. Premium Weapons Merchant `(26,12)` returned immediate
  `No path found` with `reason=closed_door`, which is expected while Eastern
  Building Door `(26,9)` remains closed. No map blocker was promoted.
- TIMING-ONLY SEAM: Fairy Water's final `(19,13)->RIGHT` step first timed out
  after movement began, but seam brute force crossed to `(20,13)` and recorded
  it passable from the west. Do not promote that edge.
- MOBILE NPC ROOT CAUSE: an unfrozen Tool Merchant 2 attempt stopped at
  `(4,4)->DOWN` because `npc_1` entered `(4,5)` while movement was `0x00`.
  An unfrozen return stopped at `(11,0)->RIGHT` because `npc_5` entered
  `(12,0)`, also with movement `0x00`. A later `report_npcs` at the entrance
  showed those same slots moving with bytes `0xA3` and `0x0B`, alongside six
  other nonzero roaming slots. `start_autowalk_npc_parking` currently decides
  mobility from the movement byte at one instant; idle roaming NPCs can
  therefore escape parking and walk into a queued path. Keep this separate
  from map blocker data. A durable fix should remember that a slot has ever
  shown nonzero movement during the current map visit.
- CURRENT: hero Cantlin `(16,0)`, all door slots closed, one key,
  `RUNTIME_BLOCKS map=0x0A none`.

## 2026-07-13 Unfrozen Cantlin Service Route Validation

- BASELINE: after the full-NPC-parking reload, hero started at Cantlin entrance
  `(16,0)` with all door slots closed and no runtime blockers. NPCs remained
  unfrozen throughout this pass.
- FIXED SERVICES: round trips completed for Tool Merchant 2 `(4,7)`, Inn
  `(8,5)`, Tool Merchant `(5,12)`, Fairy Water Merchant `(20,13)`, and Weapons
  Merchant `(25,26)`. Each leg parked six to eight roaming slots. The fresh log
  contains no `AUTO_WALK_NPC_BLOCK` or `AUTO_WALK_BLOCKER_FOUND` event.
- MENU INTERRUPTION: Tool Merchant 2 return reached `(15,0)` and cancelled
  because TALK was genuinely open (`menu_raw=true`, `menu_active=true`). After
  `simulate_input:B`, the retry crossed `(15,0)->(16,0)` successfully. This was
  command-menu state, not NPC occupancy or map geometry.
- EXPECTED DOOR GATE: Premium Weapons Merchant `(26,12)` returned immediate
  `No path found` with `reason=closed_door` and zero runtime blockers.
- ROAMING MERCHANT: selected-object navigation tracked `npc_4` from `(22,4)`
  to `(22,5)`. All adjacent goals were unreachable from its current pocket, so
  it correctly reported `Not currently reachable` and did not move the hero.
- CURRENT: hero is back at `(16,0)`, all doors closed, menu and dialogue closed,
  and `RUNTIME_BLOCKS map=0x0A none`.

## 2026-07-21 Hauksness Overworld Route Validation

- BASELINE: after manual `main.lua` reload, World Map `(48,41)`, no runtime
  blockers, and no active local path. `start_overworld_route:hauksness`
  selected waypoint 20, North Alefgard east road.
- CLEAN SEGMENTS: normal overworld autowalk completed `(48,41)->(45,13)`
  (31 steps), `(45,13)->(35,13)` (10), `(35,13)->(28,13)` (7),
  `(28,13)->(23,13)` (5), `(23,13)->(23,11)` (2), and
  `(23,11)->(21,11)` (2). No runtime blockers were added.
- PASSABLE TIMING / DO NOT PROMOTE: the one-step segment `(21,11)->UP`
  initially logged `blocked_only`. A same-origin `probe_edge:UP` then crossed
  `(21,10)` and carried to `(21,9)`, advancing the route to waypoint 28.
  Treat the autowalk result as a timing false positive, not map geometry.
- PAUSED FOR COMBAT: a Drakee battle started at World Map `(21,9)` after the
  probe. The newest dialogue says the Drakee is running away, but field control
  has not returned. Resume only after the user dismisses the battle.
- EXECUTOR FIX LIVE CHECK: after the guarded queued-route twitch-recovery
  reload, Hauksness segments from `(19,7)` through `(7,4)` repeatedly logged
  `AUTO_STEP_GUARDED_TWITCH_REPRESS` and completed. This covered immediate-turn
  and final-step shapes. A Ghost battle interrupted the north-coast segment but
  did not create a runtime block. One final-settle overshoot moved `(8,3)` to
  `(7,3)` and cancelled as `route_drift_off_path`; keep that as a separate
  executor watch item.
- CLEAN GEOMETRY: normal route execution and same-origin raw probes both
  confirmed `(7,6)->DOWN` and `(6,6)->DOWN` as blocked. The western probes
  proved `(7,6)->(6,6)->(5,6)->(5,7)->(4,7)` open, then confirmed
  `(5,7)->DOWN` and `(4,7)->DOWN` blocked. No runtime blocker was injected or
  promoted.
- ORIENTATION PLUS LIVE MATCH: the unlabeled NESMaps overworld image uses a
  64-pixel border followed by 16-pixel tiles, so its tile coordinates align
  with the game's 120x120 overworld coordinates. The map's mountain diagonal
  exactly matches every live pass/block above and shows the missing opening at
  `(3,7)->(3,8)`. The shortest passable crossing is
  `(7,4)->(7,6)->(5,6)->(5,7)->(3,7)->(3,12)->(4,12)->(4,13)->`
  `(5,13)->(5,14)->(7,14)`.
- SOURCE PATCH READY FOR RELOAD: `overworld_routes.lua` now expresses that
  crossing as explicit zero-radius waypoints. A focused regression verifies
  each waypoint name and first direction, the existing Hauksness progression
  test includes the new points, all 91 route tests pass, LuaJIT bytecode
  compilation passes, and `git diff --check` is clean.
- CURRENT: running FCEUX still has the pre-patch waypoint list and the hero is
  at World Map `(8,5)`, with the Lua Script Control window open. Manually
  restart `main.lua`, then re-establish Hauksness guidance and validate the new
  ridge crossing with normal `auto_walk`.

## 2026-07-22 Hauksness Drift and Western Desert Continuation

- RELOAD BASELINE: fresh launcher probe succeeded at World Map `(10,30)`, with
  no active local path and `RUNTIME_BLOCKS map=0x01 none`. Travel focus had
  reset to Erdrick's Cave; `auto_walk` follows the selected Travel object and
  can replace separately started route guidance, so Hauksness must be selected
  before resuming.
- FINAL-CARRY FIX LIVE VERIFIED: the Hauksness west-wall segment reached its
  requested endpoint `(2,54)`, carried exactly one additional cell west to
  `(1,54)`, logged `auto_step route final drift accepted`, and completed
  without `route_drift_off_path`. No movement-state RAM reset was enabled.
- GOLD PLACEHOLDER FIX LIVE VERIFIED: after REPEL expired, raw upper PPU text
  contained multiple literal `[GOLD]` tiles while filtered lower dialogue and
  speech remained `REPEL has lost its effect.` with no placeholder leakage.
- SOUTH-ROAD ROUTE BUG / PATCHED SOURCE: from carry landing `(1,54)`, the old
  vertical-first segment walked to `(1,63)` and cleanly blocked on
  `(1,63)->DOWN`; a same-origin raw probe also blocked. Normal rightward
  movement reached `(3,63)`, `(3,63)->DOWN` moved to `(3,64)`, and auto-walk
  then completed left to waypoint `(2,64)`. `Western desert south road` now
  uses horizontal-first ordering, with a regression proving recovery from
  `(1,54)` begins right. All 92 overworld-route tests pass. FCEUX has not yet
  reloaded this newest route-data patch.
- CLEAN CONTINUATION: route segments completed from `(8,31)` through
  `(8,34)`, `(8,51)`, `(6,51)`, `(6,52)`, `(4,52)`, `(4,54)`, `(2,54)`,
  `(2,64)`, `(18,64)`, and `(18,69)`. A REPEL message and random battles
  cancelled safely without runtime blockers.
- LATER PROGRESS: after the Wolflord was defeated, waypoint 67 completed at
  `(29,82)` and the northwest bend completed at `(31,81)`. The western-ridge
  segment then moved cleanly west through `(27,81)`.
- UNRESOLVED DIALOGUE TUNING: random battles in the scrolling overworld near
  `(20,88)` and `(21,88)` repeatedly emitted overlapping combat-text windows.
  The Wraith log progressed from the complete `Bill attacks! ... reduced by
  23.` sentence into shifted variants containing the same attack plus the
  enemy response, then fragments such as `Points have been reduced by 23 ...`
  and `reduced by 23 ...`. The preceding Goldman battle showed the same
  sliding-window repetition. A subsequent Wyvern battle at `(23,88)` repeated
  the pattern with overlapping `reduced by 32`, enemy-attack, `A miss!`, and
  `No damage hath been scored!` fragments. Two subsequent Rogue Scorpion
  battles at `(20,93)` and `(15,92)` behaved normally, without the overlapping
  sliding-window emissions. This nearby negative control strengthens a
  coordinate/scroll-origin hypothesis but does not yet establish root cause.
  Compare equivalent combat sequences at controlled overworld scroll positions
  during the later dialogue-tuning pass. Do not patch during route validation.
- ADDITIONAL REPRO: a later Wyvern battle started at World Map `(20,89)` on
  frame `53339`. The opening enemy turn was emitted as overlapping redraws on
  frames `53472`, `53541`, `53548`, `53566`, and `53578`, repeatedly combining
  `attacked before Bill was ready`, `The Wyvern attacks!`, and the same
  4-point damage result. Bill's attack likewise appeared as a complete
  32-point sentence at frame `53735`, then shifted punctuation/partial-window
  variants at frames `53761` and `53792`. The victory page itself was coherent.
  This independently reproduces the problem one row south of the earlier
  `(20,88)` / `(21,88)` cluster and strengthens the scroll-position hypothesis;
  it still does not isolate the underlying reader/overlap failure. Preserve for
  a controlled dialogue-tuning comparison after route validation.
- NEGATIVE CONTROLS: the user reported normal battle speech at World Map
  `(10,77)`, `(9,75)`, and `(12,74)`. The log agrees: the Wyvern at `(10,77)`
  emitted one clean event per attack, damage, victory, experience, and gold
  line; the Knight at `(9,75)` and Magician at `(12,74)` likewise produced no
  repeated sliding-window variants. These controls are substantially north of
  the y=88/89 repro band and support a scroll-position-dependent trigger rather
  than an enemy-specific failure. They do not yet identify the exact scroll
  offset or text-reader state that causes the overlap.
- X-DEPENDENT REPRO: a Wyvern battle at World Map `(18,77)` started on frame
  `90501` and reproduced the sliding-window failure despite sharing y=77 with
  the clean Wyvern control at `(10,77)`. Frames `90704` through `90839` emitted
  six overlapping variants of Bill's 28-point attack, the Wyvern response, and
  the same 7-point damage result. Frames `90991`, `91017`, and `91090` then
  repeated/shifted Bill's 19-point attack around the victory transition. The
  same-enemy, same-y clean/repro pair rules out a simple enemy-specific or
  y-threshold explanation and makes horizontal scroll/nametable alignment the
  stronger current hypothesis. A nearby Goldman battle logged at `(16,77)`
  did not show the same repeated variants, giving a useful candidate boundary
  for a later controlled x-position sweep. Root cause remains unproven; do not
  patch during the route-validation run.
- 2026-07-23 RETURN-APPROACH REPRO: a Goldman battle started at World Map
  `(17,89)` on frame `281291`. Frame `281606` emitted one combined redraw
  containing Bill's 27-point attack, the Goldman's counterattack, and Bill's
  6-point damage result. Frames `281629` and `281643` then repeated stale
  partial windows (`Points have been reduced by 27.` and the Goldman attack
  plus damage). Bill's second attack split again across frames `281964` and
  `282046`, and the victory text contained a stray punctuation break before
  `increases`. This reproduces the same sliding-window behavior while
  approaching Hauksness from the west and strengthens the horizontal
  scroll/nametable-alignment hypothesis. Root cause remains unproven; preserve
  this evidence for the later dialogue-tuning pass and do not patch it during
  route validation.
- ADJACENT NEGATIVE CONTROL: the next Goldman battle started one cell east at
  `(18,89)` on frame `288020`, and the user confirmed normal spoken text.
  The log advanced once through Bill's 23-point attack plus the Goldman
  counterattack, Bill's 33-point attack, and victory; unlike `(17,89)`, it
  emitted no stale partial repeats of either attack/counterattack window. This
  same-enemy, same-y, adjacent-x contrast narrows the trigger to horizontal
  scroll/nametable alignment rather than enemy behavior or y-position alone.
- EXIT-AREA REPRO: a Wyvern battle started at World Map `(24,90)` on frame
  `510266`. The surprise round was emitted as overlapping windows on frames
  `510399`, `510468`, and `510505`; `DIALOGUE_FILTER_TRACE` at frame `510456`
  captured the assembled enemy approach, surprise attack, normal attack, and
  6-point damage page before the shifted partial re-emissions. The first normal
  exchange repeated the pattern on frames `606804`, `606878`, and `606915`,
  combining Bill's 34-point attack, the Wyvern counterattack, and Bill's
  9-point damage. This farther-east repro means the `(17,89)` repro /
  `(18,89)` control is not a simple one-way x threshold. It remains consistent
  with particular horizontal scroll or nametable alignments; preserve it for
  dialogue tuning and do not treat it as route geometry.
- LOWER-POCKET REPRO: a Demon Knight battle started at World Map `(24,93)` on
  frame `31377`. The approach line repeated on frames `31444` and `31496`.
  Bill's first attack then expanded through overlapping windows on frames
  `31605`, `31626`, `31640`, and `31694`, followed by shifted attack/damage
  fragments through frame `31839`. Bill's second attack and the victory
  transition similarly repeated or shifted on frames `31890`, `31916`,
  `31941`, `31960`, `31979`, and `32038`. This confirms the dialogue defect
  remains reproducible in the lower Hauksness pocket, independently of clean
  route movement into the cell; preserve it for dialogue tuning and do not
  treat it as route geometry.
- ADJACENT LOWER-POCKET REPRO: another Demon Knight battle started at World Map
  `(24,91)` on frame `41196`, interrupting an east turn after clean movement
  from `(24,90)`. Its first attack/counterattack page emitted split and shifted
  windows from frames `41444` through `41856`; the second attack split again on
  frames `41907`, `41933`, and `41958`, followed by a fused victory/reward
  window at frame `42055`. The adjacent `(24,93)` and `(24,91)` repros further
  support a shared horizontal scroll/nametable alignment trigger.
- RETURN SOUTH-ROAD SEAM: at route waypoint 28, queued execution twice failed
  `(2,54)->RIGHT` and logged `(3,54)` as `blocked_only`. Same-origin
  `probe_edge:RIGHT` then moved through `(3,54)`, carried to `(4,54)`, and
  advanced `kol_hauksness` to waypoint 29. This disproves a permanent blocker
  and confirms a reverse-direction executor timing false positive; do not add
  map data for the seam.
- RETURN WESTERN-RIDGE SEAM: normal `kol_hauksness` execution moved
  `(3,8)->UP` into `(3,7)` and advanced to waypoint 49 without a retry, raw
  probe, or runtime blocker. This live-validates the patched ridge crossing in
  the reverse direction.
- RETURN VARIANT HIJACK / LIVE VERIFIED: after `kol_hauksness` advanced
  through waypoint 54 to `(8,3)`, the next ordinary Kol `auto_walk` replaced
  the active return with route `kol` at waypoint 11 and attempted south. Root
  cause was `route_manager.lua` comparing literal variant IDs even though
  `overworld_routes.lua` already models their shared destination. The focused
  fix keeps an active route when the selected object still matches that
  route's destination. After a full Stop/Run, ordinary Kol remained selected
  and `AUTO_WALK_TRACE ... active_route=kol_hauksness active_matches=true`
  preserved the return at the `(8,3)` cutoff and throughout the remaining
  journey. Regression totals now pass: overworld routes 104/104 and route
  manager 111/111; LuaJIT syntax validation and `git diff --check` pass.
- RETURN NORTH-COAST TIMING: before the hijack, queued `(5,4)->UP` timed out,
  while same-origin `probe_edge:UP` crossed `(5,3)` and carried to `(5,2)`.
  Replanning then reached `(5,3)` southbound but the 16-frame turn settle
  carried back to `(5,4)` and cancelled `route_drift_off_path`. A raw RIGHT
  probe to `(6,4)` let normal auto-walk complete `(6,4)->(8,3)`. This is
  executor timing evidence, not permanent geometry; movement-state reset
  remains disabled after its earlier unsafe A/B result.
- FINAL APPROACH: normal route execution reached `(15,90)` but timed out on
  `(15,90)->UP`; a same-origin raw probe moved to `(15,89)` and advanced the
  route, proving a timing/executor false positive rather than geometry. The
  doorstep lane then completed normally to `(24,89)`. Auto-walk similarly
  timed out on final `(24,89)->RIGHT`, while a same-origin raw probe immediately
  changed maps and logged `OVERWORLD_ROUTE: event=arrived`.
- CURRENT / OVERWORLD GEOMETRY COMPLETE: hero is in Ruins of Hauksness map
  `0x03` at `(0,10)`, `OVERWORLD_ROUTE: event=status route=none`, and
  `RUNTIME_BLOCKS map=0x03 none`. The Hauksness overworld geometry is validated
  end-to-end. Auto-walk is not fully clean because the two final edges above
  required probes. The horizontal-first south-road source patch also remains
  pending a future FCEUX reload/retest.

## 2026-07-24 Hauksness Return Route Completion

- BRIDGE WEST-BEND GEOMETRY: queued `(56,15)->RIGHT` into `(57,15)` timed out,
  and same-origin `probe_edge:RIGHT` also returned `status=blocked`, with no
  NPC or modeled directional blocker. Same-origin south probes crossed cleanly
  through `(56,16)`, `(56,17)`, `(56,18)`, and `(56,19)`, followed by the
  lower bridge lane to exact waypoint `(58,18)`. `kol_hauksness` now uses
  vertical-first order for `Northeast bridge west bend`; the focused test
  failed RED with `expected down, got right` before the one-field correction.
- KOL SOUTHWEST-TRACK GEOMETRY: queued `(77,18)->RIGHT` into `(78,18)` and its
  same-origin raw probe both blocked. South probes crossed cleanly to
  `(77,26)`, and the row-26 east lane then continued toward `(84,26)`.
  `kol_hauksness` now uses vertical-first order for `Kol southwest track`;
  its focused regression likewise failed RED before the correction.
- TIMING-ONLY CONTROLS: `(54,15)->RIGHT`, `(93,36)->UP`, and
  `(93,35)->RIGHT` failed queued execution but passed same-origin raw probes.
  Do not promote these as map blockers. Repel expiration canceled one route
  segment at `(80,26)` through ordinary dialogue state; it resumed normally
  after the user recast Repel.
- COMPLETE: the route crossed the northeast bridge, followed the Kol south
  road, and entered Kol. Live arrival was
  `OVERWORLD_ROUTE: event=arrived route=kol_hauksness waypoint=Kol index=88`.
  Final state is Kol map `0x07` at `(19,23)`, route inactive, menu closed, and
  no runtime blocks. The two axis-order edits were not loaded into this live
  Lua process; manual probes traversed the proven lanes. Full Stop/Run is
  required before a focused live planner recheck of those source corrections.
- LOWER-POCKET FINAL-CARRY RECOVERY: after the route reached lower-west-drop
  waypoint `(24,93)`, final settle carried to `(25,93)`. Four queued UP
  attempts and a same-origin raw UP probe all blocked into `(25,92)`, while
  same-origin LEFT crossed `(24,93)` and UP from `(24,93)` reached `(24,91)`.
  The return-only `Hauksness lower west pocket` waypoint now uses
  horizontal-first order. Its regression reproduces planning from `(25,93)`
  and requires `left, up, up`; the existing exact `(24,93)` progression
  remains UP-first. At that checkpoint, the later Hauksness-to-Kol pass was
  active at `(24,91)`, targeting `Hauksness lower pocket` at waypoint index 7.
  The subsequent reload cleared that route state before generic Kol testing.
  LIVE VERIFIED after a later script reload and fresh Hauksness entry/exit:
  the natural lower-west-drop segment ended at exact `(24,93)`, so a
  same-origin RIGHT probe recreated the carry landing at `(25,93)`. With
  `kol_hauksness` still active and no NPC or runtime blockers, the loaded route
  executed `left, up, up`, completed at `(24,91)`, and advanced to `Hauksness
  lower pocket`.
- GENERIC KOL SOUTHWEST-TRACK GAP: after reload cleared route state, selecting
  Kol at `(54,15)` chose generic `kol`. Its bridge correction moved DOWN first
  and reached `(58,18)`, then the shared corridor reached `(74,18)`. Generic
  `Kol southwest track` still planned horizontal-first, moved east to
  `(77,18)`, and blocked on the already-proven `(77,18)->RIGHT` edge. A fresh
  clean baseline at `(77,18)` had no path, NPC, menu, battle, or runtime
  blocks; same-origin DOWN crossed `(77,19)` and carried to `(77,20)`. Generic
  `kol` now uses vertical-first ordering at this waypoint. Its regression
  requires eight DOWN steps before the first RIGHT step. Reverse routes remain
  horizontal-first. LIVE VERIFIED after script restart: a fresh clean baseline
  at `(54,15)` selected generic `kol` and Kol, the bridge approach reached
  `(74,18)`, and `Kol southwest track` completed all 18 steps to `(84,26)`.
  The log showed eight DOWN moves to row 26 before ten RIGHT moves; it never
  attempted `(77,18)->RIGHT`. The next waypoint was `Kol southwest bridge`.
  Two earlier bridge segments each needed one retry after movement-started
  timing stalls; neither stall was promoted to permanent blocker data.

## 2026-07-24 Object Selection Reset After Battle

- REPRODUCED: in Hauksness, auto-walk targeted `Axe Knight Approach` before
  three separate battles, but the next auto-walk targeted `Exit to World Map`
  without a map transition. The full refresh had reset selection to object 1.
- ROOT CAUSE: `objects.check_refresh()` compared the complete
  `COMBAT_FLAGS` byte, which also carries transient battle-status bits, and
  treated those changes like a map or object-state change.
- PATCHED / LIVE VERIFIED: object refresh detection now compares only
  the `0x01` Gwaelin escort bit that can actually change object visibility.
  Map changes, terrain changes, and Gwaelin visibility updates still force the
  intended rebuild. The new regression preserves the Axe Knight selection
  across a battle-only `0x0A -> 0x0E` change; all 103 object tests pass.
  After reload, the Axe Knight and Exit selections each survived battles.
  The strongest live control was the Wizard battle: Stopspell changed the
  full combat byte from `0x0A` to `0x2A`, but Exit remained selected.

## 2026-07-24 Hauksness Axe Knight-to-Exit Reverse Route

- START / DESTINATION: began at the defeated Axe Knight square `(18,12)`,
  selected `Exit to World Map`, and completed at `(0,10)` facing west.
- NEW DIRECTIONAL BLOCKS: the reverse route found seven blocked approaches
  across six destination cells:
  - `(14,11).south`
  - `(9,12).south`
  - `(10,10).south`
  - `(9,10).south`
  - `(11,11).west`
  - `(11,12).west`
  - `(11,12).south`
- RAW CONFIRMATION: `(10,11)->UP`, `(10,11)->RIGHT`,
  `(10,12)->RIGHT`, and `(11,13)->UP` each remained at the origin under a
  fresh 60-frame raw hold. The other three independently failed both queued
  movement and the same-origin seam retry before runtime injection.
- RUNTIME VALIDATION: the six-cell directional runtime model produced the
  final clean segment from `(9,13)`: 1 west, 4 south, 6 west, 7 north,
  2 west. It reached `(0,10)` without another blocker; the hero's armor healed
  him from 72 to 92 HP during the segment.
- SOURCE PROMOTED / LIVE RELOAD PENDING: `map_reader.lua` now contains the
  seven approaches above, and the focused Hauksness regression covers them.
  All 69 map-reader tests pass. A full reload and clean planner preview remain
  before declaring the source-only route model complete.

## 2026-07-24 Hauksness Exit-to-Axe Knight Source Validation

- SOURCE-ONLY BASELINE: after a full script reload at the Hauksness exit
  `(0,10)`, runtime blocks were empty and all seven reverse-route additions
  above loaded as effective directional blockers. The source-only planner
  selected `Axe Knight Approach` and initially found a route of 3 east,
  3 south, 10 east, 1 north, and 4 east.
- NEW RAW-CONFIRMED DIRECTIONS: live route failures were followed by
  same-origin 60-frame raw probes which remained at their origins:
  - `(15,13).north`, from `(15,12)->DOWN`
  - `(16,13).north`, from `(16,12)->DOWN`
  - `(16,13).south`, from `(16,14)->UP`
  - `(17,13).north`, from `(17,12)->DOWN`
  - `(17,13).south`, from `(17,14)->UP`
  - `(18,13).north`, from `(18,12)->DOWN`
  - `(19,12).west`, from `(18,12)->RIGHT`
- SOURCE PROMOTED / LIVE RELOAD PENDING: `map_reader.lua` now contains those
  seven destination-side approaches, and the focused Hauksness test failed
  RED on the first missing direction before passing all 69 map-reader tests
  after the minimal data patch.
- UNCONFIRMED CANDIDATES: keep `(5,11).west`, `(5,12).west`,
  `(5,13).west`, `(18,13).south`, `(19,14).west`, `(15,14).east`, and
  `(15,14).south` out of permanent data until a same-origin raw probe confirms
  each one. Their current evidence is route execution and seam-retry failure
  only, except `(15,14).east`, which has only one queued block.
- RUNTIME COMMAND NOTE: `add_blocked_edge:X,Y,DIR` takes the movement origin
  and direction, not destination-cell approach notation. The two mistaken
  reverse-direction injections were caught before movement, map `0x03`
  runtime data was cleared, and only the correct origin-direction forms were
  re-added. Permanent source data was never affected.
- CURRENT CHECKPOINT: hero remains in Hauksness at `(15,12)`, field clear.
  A full script reload is required before source-only inspection and continued
  route validation.

## 2026-07-24 Hauksness Stat-Corruption Reproduction

- CORRUPTED STATE / DO NOT SAVE: source-only autowalk started clean at
  Hauksness `(15,12)` with level 17, `HP 100/100`, `MP 43/90`, and
  `BA-CF=E7 3E EE 20 DF 06 05 45 C3 2D 18 64 2B 11 48 46 64 5A 64 55 FF 11`.
  The raw log is preserved at
  `work_notes/hauksness_stat_corruption_20260724.log`.
- EXACT TRANSITION: the two-step route reached intended safe stand `(17,12)`
  at frame 6041, but the 16-frame final settle carried one extra cell east to
  the fixed encounter square `(18,12)`. Frame 6057 was still clean. Between
  frames 6057 and 6058, bytes `C8,C9,CA,CB,CC,CD,CE` changed to
  `04 03 0F 00 20 33 00`, yielding `HP 100/15`, `MP 43/0`, Strength 4,
  Agility 3, and no spells. Battle detection did not occur until frame 6108.
- ROOT CAUSE: drift recovery at frame 6057 replanned one step west and called
  `auto_step.start_route()` with `initial_settle_frames=16`. The initial-settle
  branch unconditionally calls
  `reset_movement_engine_state("queued_route_initial_settle")`, writing zero
  to `$003C/$003D`, even though
  `auto_step_reset_movement_on_route_turn_settle=false`. The corruption
  appeared on the immediately following frame. This is the same unsafe
  movement-reset mechanism implicated by the Grave A/B test, exposed through
  a separate configuration-bypassing initial-settle path.
- NPC PARKING CONTROL: proactive parking was active for five mobile NPC slots,
  but guarded NPC writes are confined to `$0051-$008C`; they cannot directly
  overwrite `$00C8-$00CE`. Parking restoration occurred at frame 6109, after
  both the frame-6058 stat collapse and frame-6108 battle detection. Keep NPC
  parking as a possible environmental precondition only; current evidence
  identifies the immediate trigger as the initial-settle movement reset.
- CURRENT STATE: the live battle remains corrupted at Hauksness `(18,12)`.
  Latest snapshot was `HP 4/15`, `MP 43/0`; do not finish or save this fight.
  Restore the known-good save state before any further live testing.
- FIX NOT YET IMPLEMENTED: first add a focused `auto_step` regression proving
  an initial settle waits without writing `$003C/$003D` when movement-reset
  configuration is disabled. Then remove or gate only the unsafe reset and
  rerun the focused route from the restored `(15,12)` state.
- FIX IMPLEMENTED / LIVE VERIFIED: commit `dba1b19` gates the initial-settle
  movement reset with `auto_step_reset_movement_on_route_turn_settle`. The
  regression failed RED with two unexpected movement-RAM writes while disabled,
  then all 136 `auto_step` and 112 route-manager tests passed after the gate.
  After a full FCEUX Stop/Run, reroutes executed 16-frame initial settles at
  frames `13362`, `13607`, and `14009`. Snapshots at frames `13980` and `14135`
  retained level 17, max HP 100, max MP 90, and stat bytes
  `48 46 64 5A 64 55 FF`; HP changes were normal armor healing. No stat
  integrity warning appeared, and battle interruption restored all five parked
  NPC slots.
- RUNTIME-ONLY FOLLOW-UP: route failure, seam retry, and a same-origin raw UP
  probe all confirmed `(18,14)->UP` blocked. A deliberate runtime edge at
  destination `(18,13).south` was added so validation could continue. Later
  failures at `(18,14)->RIGHT` and `(15,15)->UP` caused safe reroutes and
  exercised the patched initial-settle path, but remain temporary route
  evidence pending same-origin probes.
- `(18,13).south` PROMOTED: the focused Hauksness assertion failed RED with
  `expected true, got nil`; `map_reader.lua` now adds the one confirmed
  approach beside the existing `(18,13).north` entry. All 69 map-reader tests
  pass and both changed Lua files byte-compile.
- SAFE APPROACH REACHED: after the Starwyvern battle, source plus the one
  runtime edge routed from `(12,15)` through `(12,12)` and east along row 12.
  It completed at `(17,12)`, faced east, released movement, and did not
  overshoot onto `(18,12)`. Final snapshot retained clean level-17 stats,
  `HP 100/100`, `MP 57/90`, no active path, and one runtime block.

## 2026-07-24 Hauksness Updated Axe Knight-to-Exit Validation

- NEW RAW-CONFIRMED DIRECTIONS: the updated reverse route stopped on each
  approach, the built-in seam retry stayed blocked where applicable, and a
  same-origin 60-frame raw probe then remained at its origin:
  - `(17,8).south`, from `(17,9)->UP`
  - `(18,9).west`, from `(17,9)->RIGHT`
  - `(18,10).west`, from `(17,10)->RIGHT`
  - `(17,11).north`, from `(17,10)->DOWN`
  - `(17,11).west`, from `(16,11)->RIGHT`
  - `(18,11).south`, from `(18,12)->UP`
- TIMING FALSE POSITIVE KEPT OPEN: queued movement from `(17,10)->LEFT`
  reported `(16,10).east` blocked, but the same-origin raw probe moved cleanly
  into `(16,10)`. The move triggered a Starwyvern battle, but it is valid
  movement evidence and no map entry was added.
- SOURCE AND TESTS: each new approach first failed the focused Hauksness
  regression with `expected true, got nil`, then passed after the minimal
  `map_reader.lua` change. The final source model passes all 69 map-reader
  tests; `map_reader.lua` and `test_map_reader.lua` byte-compile and
  `git diff --check` is clean.
- LIVE ROUTE COMPLETED: runtime mirrors for the newly promoted edges produced
  a clean route from `(18,12)` west through row 12, then around the southern
  lane. Battles interrupted at `(9,15)` and `(6,17)`, but the final 13-step
  segment from `(6,17)` moved 4 west, 7 north, and 2 west without a blocker.
  Autowalk completed at exit stand `(0,10)`, faced west, restored all five
  parked NPC slots, and retained clean level-17 stats. Final snapshot:
  `HP 70/100`, `MP 43/90`.
- SOURCE-ONLY RELOAD PENDING: the source additions made during this pass still
  require a full FCEUX Stop/Run followed by a clean route preview or replay
  with no runtime overlay before declaring the updated reverse route model
  fully source-validated.

## 2026-07-24 Hauksness Exit-to-Axe Knight Discovery Completion

- SOURCE-ONLY START / RUNTIME-ASSISTED FINISH: the pass began after a full
  reload at exit `(0,10)` with no runtime blockers. Each new route failure was
  tested with a same-origin 60-frame raw probe before its exact destination
  approach was promoted and mirrored into the still-running session.
- NEW RAW-CONFIRMED DIRECTIONS:
  - `(5,11).west`, `(5,12).west`, and `(5,13).west`
  - `(9,8).north`
  - `(17,8).west` and `(15,8).east`
  - `(7,8).north`
  - `(6,8).north` and `(6,8).west`
  - `(5,9).north`
  - `(15,14).south` and `(15,14).east`
  - `(19,14).west`
  - `(19,15).west` and `(19,15).south`
  - `(17,16).east`
  - `(18,17).north`
- LIVE COMPLETION: after the final blocker was mirrored, the last segment from
  `(12,15)` moved 3 north and 5 east without another failure. Autowalk reached
  safe stand `(17,12)`, faced east toward the fixed Axe Knight square, restored
  all five parked NPC slots, and retained clean level-17 stats. Final snapshot:
  `HP 100/100`, `MP 1/90`, runtime blocker count 14.
- TEST STATUS: every new approach first failed the focused Hauksness assertion
  before its source patch. The final model passes all 69 map-reader tests;
  both Lua files byte-compile and `git diff --check` is clean.
- NEXT CHECK: perform a full FCEUX Stop/Run at `(17,12)` to clear the runtime
  overlay. Validate the source-only route back to exit, then return to exit and
  replay exit-to-Axe Knight source-only before declaring both directions
  complete.

## 2026-07-24 Hauksness Bidirectional Source Validation Complete

- FINAL REVERSE DISCOVERY: the pre-reload Axe Knight-to-exit pass found
  `(12,14)->LEFT` blocked. A same-origin 60-frame raw probe remained at
  `(12,14)` with `npc_blocked=false` and `reason=raw_hold_timeout`, confirming
  destination approach `(11,14).east`. The focused Hauksness regression failed
  RED before `map_reader.lua` added that direction, then all 69 map-reader
  tests passed.
- SOURCE-ONLY FORWARD: after a full Stop/Run at exit `(0,10)`,
  `RUNTIME_BLOCKS map=0x03 none`. The planner used 3 east, 7 south, 5 east,
  4 north, 5 east, 1 north, and 4 east. A Starwyvern interrupted at `(1,10)`;
  after combat, guidance resumed and completed at safe stand `(17,12)`, faced
  east toward the fixed encounter, restored all four parked NPC slots with
  zero deferred, and still reported no runtime blockers. The completion
  snapshot retained full HP/MP and clean level-17 stats.
- SOURCE-ONLY REVERSE: without another reload or runtime injection, the
  planner used 5 west, 3 south, 6 west, 2 south, 4 west, 7 north, and 2 west.
  Starwyvern and Werewolf battles interrupted at `(10,15)` and `(2,12)`;
  each resumed from a clean field state. Guidance completed at exit `(0,10)`,
  faced west, restored all four parked NPC slots with zero deferred, and kept
  `RUNTIME_BLOCKS map=0x03 none`. Final snapshot: `HP 89/100`, `MP 78/90`,
  level-17 stats `STR=0x48 AGI=0x46 ATK=0x64 DEF=0x55`.
- DIALOGUE FOLLOW-UP: the Starwyvern battle at `(10,15)` produced another
  overlapping spell-text sample, including fragments of STOPSPELL, REPEL,
  HEALMORE, and recovery text in one announcement. Preserve this as evidence
  for the later coordinate-sensitive battle-dialogue tuning pass; it did not
  affect route or stat validation.
- RESULT: the Hauksness entrance-to-Axe Knight objective route and its return
  are live-validated in both directions from loaded source with no runtime
  blocker overlay. The exit and safe-approach landmarks, directional map
  model, NPC parking/restoration, and movement-reset corruption fix all held
  through combat interruptions.

## 2026-07-26 Cantlin / Eastern Great Swamp Route Discovery

- BASELINE: normal Cantlin World Map landing `(73,102)`, no active path or
  runtime blockers.
- SAFE PIN ACCEPTED: `(89,112)` is reachable from the south, remains on World
  Map `0x01`, has no fixed-object conflict, held HP steady for 660 frames, and
  passed both departure `(89,112)->(89,113)` and re-entry
  `(89,113)->(89,112)`.
- OUTBOUND NEW CORRIDOR: from the shared Cantlin/Hauksness anchor `(48,104)`,
  normal movement proved `(59,104)`, `(59,105)`, `(63,105)`, `(63,106)`,
  `(64,106)`, `(64,108)`, `(66,108)`, `(66,110)`, `(72,110)`, `(72,112)`,
  `(74,112)`, `(74,113)`, `(89,113)`, and `(89,112)`.
- NARROW APPROACH: `(74,112)->(75,112)` and `(75,114)->(76,114)` remained
  blocked under raw holds. The live-proven east corridor is row 113. Guidance
  may traverse the clue square but must not name it, target it as a waypoint,
  issue Search, or mention the Token.
- INDEPENDENT RETURN CORRIDOR: `(89,112)`, `(89,113)`, `(75,113)`,
  `(73,113)`, `(73,111)`, `(71,111)`, `(71,110)`, `(65,110)`, `(65,108)`,
  `(63,108)`, `(63,106)`, `(63,105)`, `(59,105)`, `(59,104)`, then the
  established Cantlin return chain at `(48,104)`.
- ARMOUR OBSERVATION: with Erdrick's Armour equipped, HP remained 100 through
  the suspected swamp corridor before later battle damage. Keep route speech
  equipment-neutral; do not change hazard mechanics from this observation.
- TIMING-ONLY FAILURES: queued movement reported blocks at
  `(68,91)->(68,92)`, `(54,95)->(54,96)`, `(52,97)->(52,98)`, and
  `(47,104)->(48,104)`. Each same-origin raw probe moved through the claimed
  edge; the final probe carried from `(47,104)` through `(48,104)` to
  `(49,104)`. No runtime or permanent blocker was added.

## 2026-07-26 Full-Inventory Discard Screen Speech

- LIVE REPRO: searching at World Map `(83,113)` with a full inventory opened
  the Erdrick's Token discard prompt. The screen remained active throughout
  diagnostics.
- FALSE MERCHANT: the detector reported `active=true`, `mode=offers`,
  `buy_prompt=false`, five status markers, and repeatedly interrupted with
  `Merchant. Gold 17089. Offered: ...`. The discard prompt and held-item list
  share status rows, satisfying the shop-layout fallback without a buy prompt.
- STUCK SELECTION: the merchant cursor reader announced `Dragon's Scale` once,
  then stopped following Up/Down. A later snapshot had `D8=0 D9=2`; the live
  list shows D9 order Herb, Magic Key, Fairy Flute, Dragon's Scale, Wings,
  Stones of Sunlight, Staff of Rain, Fairy Water, Gwaelin's Love, Torch, so
  D9=2 should announce Fairy Flute.
- ITEM MODEL BUG: `herbs=6`, `keys=6`, and packed item bytes are
  `45 C3 2D 18`. The game displays the separate Herb counter first, Magic Key
  second, then each packed byte's low nibble before its high nibble.
  `items.lua` currently omits the Herb counter, prepends Magic Key, and decodes
  high nibble first.
- LIVE FIX VERIFIED: after reload on the preserved screen, speech opened with
  `D9=2 Fairy Flute`, then followed Down, Down, Up as
  `D9=3 Dragon's Scale`, `D9=4 Wings`, `D9=3 Dragon's Scale`. No `MERCHANT`
  event or merchant speech occurred. Source now rejects discard layouts from
  merchant mode, owns the prompt/cursor through a dedicated reader, and uses
  the corrected Herb, Magic Key, then low/high packed-slot order.

## 2026-07-29 Mountain Cave Route and Decoding Start

- STATIC ORIENTATION: Mountain Cave is World Map `(29,57)`, with interior maps
  `0x16` and `0x17`. The closest existing route pin by traversable map distance
  is `Western desert east road` `(18,64)`.
- PROVISIONAL BIDIRECTIONAL SPUR:
  - Outbound: `(18,64)->(16,64)->(16,58)->(25,58)->(25,57)->(29,57)`.
  - Return: the exact reverse, ending at `(18,64)`.
- LIVE CLEAN: `(18,64)->LEFT->(17,64)->LEFT->(16,64)` moved. A Ghost battle
  began after the second edge and ended without damage. REPEL was recast;
  baseline after combat was HP `115/115`, MP `93/97`, no active route/path,
  and no runtime blocks.
- LIVE CARRY / DO NOT MODEL AS BLOCKER: north probing moved
  `(16,64)->(16,63)`, then reached `(16,62)` and carried to `(16,61)`.
  A one-frame simulated manual tap entered the early-twitch cancellation path
  and did not move. This is executor evidence, not World Map blocker data.
- ROUTE SOURCE LOADED: `overworld_routes.lua` now defines `mountain_cave`
  and `mountain_cave_return`; focused regressions cover object start,
  `(16,61)` carry recovery, exact turns, entry completion, and reverse
  completion. All 146 route tests, Lua syntax, and `git diff --check` pass.
- OUTBOUND LIVE VALIDATED: loaded-source route movement stopped exactly at
  `(16,58)`, `(25,58)`, and `(25,57)`, then entered Mountain Cave map `0x16`
  at `(0,7)`. No runtime blocker overlay, battle, or final-turn carry occurred.
- F1 CRAWL RUN 1: from `(1,7)`, normal movement classified 36 edges before a
  Magician battle interrupted at `(2,2)`. The Magician ran; fresh field state
  remained HP `115/115`, MP `93/97`, EXP `20019`, with no runtime blockers.
- F1 TILE DECODING: every live corridor edge in the crawl landed on raw tile
  type `2`; repeated three-attempt wall probes landed against raw tile type
  `0`. Same-origin raw probes also blocked `(2,2)->(1,2)` and
  `(2,2)->(3,2)`. `map_reader.lua` now applies `type 0 = blocked` only on
  map `0x16`, and marks the live-proven world-entry landing `(0,7)` as a
  passthrough. Floor `0x17` deliberately retains the shared dungeon rule
  pending live evidence. All 71 map-reader tests and Lua syntax pass.
- F1 SOURCE-ONLY RETURN: after reload, the corrected planner produced the
  crawl-matching 11-step route `(2,2)->(0,7)`. A Ghost interrupted at `(4,4)`;
  fresh state showed no damage or EXP change. Queued `(4,4)->DOWN` later
  exhausted both timing retries, but a same-origin raw probe moved cleanly
  into `(4,5)`. Treat this as executor timing evidence, not map data. The
  remaining six-step source-only route reached `(0,7)` without blockers.
- LIVE EXIT: moving LEFT from `(0,7)` is blocked. The user used the STAIRS
  command on `(0,7)`, which changed to World Map `(29,57)`. `objects.lua` now
  models the world exit at `(0,7)`, replacing stale unreachable `(0,0)`.
- RETURN ROUTE LIVE VALIDATED: `mountain_cave_return` reached the existing pin
  `(18,64)` and emitted `event=arrived` at index 6. The live geometry was
  `(29,57)->(25,57)->(25,58)->(16,58)->(16,64)->(18,64)`, with no runtime
  blockers and unchanged HP `115`, MP `93`, EXP `20019`, and level-18 stats.
- 2026-07-30 POST-RELOAD OUTBOUND: from the restored `(18,64)` baseline, the
  physical Mountain Cave object retained the active `mountain_cave` route.
  All five segments completed to `(16,64)`, `(16,58)`, `(25,58)`, `(25,57)`,
  and map `0x16` `(0,7)`. The loaded Travel exit correctly reported
  `Exit to World Map: here`; a controlled STAIRS command returned to World Map
  `(29,57)`. No runtime blocker was added.
- RETURN SELECTION BUG FIXED LIVE: Travel-object refresh near the cave could
  select physical `Mountain Cave` and replace the active return route with
  outbound. The first compatibility patch covered `guidance_for_object()` but
  not route manager's direct `active_route_matches_object()` check. After the
  second fix and reload, the exact `(29,57)` reproduction logged
  `active_route=mountain_cave_return active_matches=true` while the physical
  cave remained selected. The return then completed every segment through
  `(25,57)`, `(25,58)`, `(16,58)`, and `(16,64)`, and emitted
  `event=arrived` at `(18,64)`. Fresh probe
  `MCAVE_BIDIRECTIONAL_VALIDATED_20260730` confirms `route=none`, no path,
  no runtime blockers, HP `115/115`, MP `93/97`, EXP `20019`, and intact
  level-18 stats. Focused totals remain 147 route, 107 object, and 71
  map-reader tests plus Lua syntax and `git diff --check`.
- ROM AND LIVE STAIR PAIRS: the ROM tables identify three coordinate-matched
  pairs, and each FCEUX STAIRS transition was verified live in both directions:
  northwest A `(0,0)<->(0,0)`, central B `(6,5)<->(6,5)`, and southeast C
  `(12,12)<->(12,12)`. `objects.lua` now exposes all three with distinct
  northwest, central, and southeast labels on both floors.
- F1 NORTHWEST / UPPER ROUTE: same-origin probes moved through the west
  boundary `(1,3)->(0,3)->(0,2)->(0,1)->(0,0)`, then through top-row cells
  `(1,0)..(3,0)`. The interior turn runs `(3,0)->(3,1)->...->(8,1)`, then the
  second top strip is `(8,0)->(9,0)->(10,0)`. From `(10,0)`, the central-stair
  route moves five south to `(10,5)`, three west to `(7,5)`, and onto B
  `(6,5)`. Only these live-proven boundary cells were promoted as
  `MAP_PASSTHROUGH_CELLS`.
- F1 ONE-WAY SEAM: autowalk repeatedly failed `(8,3)->UP` into `(8,2)`, and
  a same-origin raw probe also remained at `(8,3)`. Source now blocks only
  `(8,2).south`; timing retries adjacent to battles elsewhere were not
  promoted.
- B2 NORTHWEST POCKET A: `(0,0)->(0,1)->(1,1)` and the full reverse moved.
  Same-origin probes from `(1,1)` into raw type-0 `(2,1)` and `(1,2)` both
  blocked, proving the pocket is isolated.
- B2 SOUTHEAST POCKET C: the live region includes the stair `(12,12)`, north
  corridor through `(12,11),(11,11),(10,11)`, tip `(11,10)`, south/bottom
  loop through `(10,12),(10,13)..(13,13)`, and east edge through `(13,12)` to
  `(13,11)`. Raw type-A `(10,13)` moved normally. From `(11,10)`, all three
  outward raw type-0 probes into `(11,9)`, `(10,10)`, and `(12,10)` blocked,
  proving this region is also isolated.
- B2 TILE RULE: repeated normal-origin probes in both isolated pockets prove
  raw type `0` is blocked on map `0x17`; type `2` and type `A` are walkable.
  The northwest boundary cells `(0,0)` and `(0,1)` are passthroughs.
- SOURCE / TEST CHECKPOINT: the focused tests first failed on missing
  passthroughs and missing stair objects, then passed after the narrow source
  changes. Current totals are `71` map-reader tests and `107` object tests;
  `luac -p map_reader.lua objects.lua test_map_reader.lua test_objects.lua`
  also passes.
- CURRENT LIVE CHECKPOINT: hero is on B2 central stair B `(6,5)`, field clear,
  no active path or runtime blockers, HP `115/115`, MP `89/97`, EXP `20069`,
  gold `20842`, and intact level-18 stats. The current FCEUX script predates
  the latest `map_reader.lua` / `objects.lua` edits.
- NEXT CHECK: manually reload the FCEUX Lua script, fresh-probe B2 `(6,5)`,
  verify the loaded three-stair object set and type-0 wall model, then decode
  the central B2 treasure area and four chests.

## 2026-07-30 Mountain Cave B2 Main-Area Decode

- POST-RELOAD BASELINE: map `0x17` central stair B `(6,5)`, field clear,
  HP `115/115`, MP `89/97`, level 18 stats intact, and no runtime blockers.
  The loaded object registry exposes central B `(6,5)`, northwest A `(0,0)`,
  southeast C `(12,12)`, and chests `(1,6)`, `(2,2)`, `(3,2)`, `(10,9)`.
- TYPE-8 WALL RULE: normal autowalk plus same-origin raw probes independently
  blocked entry into five raw type-8 cells: `(4,9)` from north and south,
  `(5,9)` from north, south, and east, `(3,7)` from east, `(1,5)` from north,
  and `(2,5)` from north. No probe has moved onto type 8. The published NES
  floor map renders every type-8 cell as the same solid gray rock class.
  A runtime-only model that fully blocks all 16 type-8 cells produces the
  intended main region plus isolated A and C stair pockets. Source now sets
  map `0x17` type 8 false; this edit is not yet loaded in FCEUX.
- WESTERN BOUNDARY ROUTE: from the main area, raw probes moved
  `(1,13)->(0,13)->(0,12)->(0,11)->(0,10)->(0,9)->(1,9)`.
  Reverse probes later moved `(1,9)->(0,9)->(0,10)->(0,11)->(0,12)->(0,13)`.
  Source now marks `(0,9)..(0,13)` as B2 passthrough cells; this edit is not
  yet loaded in FCEUX.
- SPECIAL-CHEST BRANCH: after the western boundary route re-entered at
  `(1,9)`, autowalk moved north through `(1,8),(1,7)` and stood on chest
  `(1,6)` without opening it.
- SOURCE CHECKPOINT: the type-8 rule and five new boundary passthroughs have
  focused regression assertions. All `71` map-reader tests, Lua syntax, and
  `git diff --check` pass.
- CURRENT LIVE CHECKPOINT: a Droll battle began immediately after the reverse
  probe reached `(0,13)`. The Droll was defeated for `10 EXP` and `24 gold`,
  but the victory dialogue remains open (`state=battle`, lower dialogue length
  `101`). Position is B2 `(0,13)`, HP `115/115`, MP `87/97`, EXP `20095`,
  gold `20895`. The attempted RIGHT probe was refused during battle and is not
  geometry evidence.
- NEXT CHECK: dismiss the Droll victory dialogue, fresh-probe field state at
  `(0,13)`, move RIGHT to `(1,13)`, route through the interior to `(5,1)`,
  then raw-probe the top boundary strip `(5,0)->(4,0)->(3,0)` and descend to
  the two northwestern chests `(3,2)` and `(2,2)`.
- POST-DROLL CONTINUATION: field control returned at `(0,13)` and the
  previously refused RIGHT probe moved cleanly to `(1,13)`, completing the
  western boundary route in both directions.
- NORTHWESTERN CHESTS: the interior route reached `(5,1)`. Raw probes moved
  `(5,1)->(5,0)->(4,0)->(3,0)->(3,1)->(3,2)->(2,2)`, then retraced every
  edge to `(5,1)`. Both chest tiles are standable; neither chest was opened.
- FULL TOP BOUNDARY: a continued raw-probe pass moved from `(5,0)` east
  through every cell `(6,0)..(13,0)`, then south to the modeled interior
  `(13,1)`. Source now marks the complete B2 top corridor `(3,0)..(13,0)` as
  passthrough cells.
- BATTLE / TIMING NOTE: a Poltergeist interrupted the first eastbound attempt
  at `(2,13)` after an executor timing retry. After battle, a fresh same-origin
  probe moved `(2,13)->(3,13)`. This is timing/combat evidence, not a blocker.
- UPDATED SOURCE CHECKPOINT: map `0x17` now applies `type 0 = false` and
  `type 8 = false`, with live-proven passthroughs `(0,0),(0,1)`,
  `(0,9)..(0,13)`, and `(3,0)..(13,0)`. All `71` map-reader tests, Lua syntax,
  and `git diff --check` pass.
- CURRENT LIVE CHECKPOINT: B2 `(13,1)`, field clear, HP `115/115`, MP `87/97`,
  EXP `20103`, gold `20910`, with the runtime-only set of 16 type-8 walls
  still active. FCEUX has not loaded the latest source.
- NEXT CHECK: manually reload the FCEUX Lua script, fresh-probe `(13,1)`,
  clear map-`0x17` runtime blocks, and validate source-only routes to all four
  chests plus central stair B. Then finish the remaining unmodeled boundary
  cells `(0,3),(0,4)`, `(0,6),(0,7)`, and northwest-pocket `(1,0)`.

## 2026-07-31 Mountain Cave B2 Completion

- SOURCE-ONLY TREASURE REGION: after reload with zero runtime blockers, the
  planner and live movement reached all four chest tiles `(1,6)`, `(2,2)`,
  `(3,2)`, and `(10,9)`. None was deliberately opened. The route from special
  chest `(1,6)` to central stair B initially exposed raw type-1 stair tiles as
  non-walkable; live-verified passthroughs now cover B `(6,5)` and C `(12,12)`.
  A loaded-source route then reached `(8,5)`, and post-battle same-origin
  probes completed `(8,5)->(7,5)->(6,5)` with no runtime blockers.
- WESTERN BOUNDARY POCKETS: normal-route origins plus same-origin probes moved
  bidirectionally through `(1,4)<->(0,4)<->(0,3)` and
  `(1,6)<->(0,6)<->(0,7)`. All four boundary cells are permanent
  passthroughs. Battle, Repel-expiry, and executor retries during repositioning
  were kept separate from geometry evidence.
- NORTHWEST FINAL CELL: after normal STAIRS transitions through central B and
  northwest A, same-origin probes moved B2 `(0,0)->(1,0)->(0,0)`. Cell `(1,0)`
  is raw type 2 and is now a passthrough. After the final reload,
  `inspect_tile:1,0` reported `reason=passthrough`, `base_walkable=true`, and
  `effective_passable=true`; source-only autowalk repeated the full round trip.
- COMPLETE STATUS: Mountain Cave F1 `0x16` and B2 `0x17` are decoded for
  navigation, including all boundary corridors, type-0/type-8 walls, four B2
  chests, and three distinct stair pairs. A and C are isolated B2 pockets;
  central B connects to the treasure region. Current state is B2 stair A
  `(0,0)`, field clear, no active path/runtime blockers, HP `115/115`, MP
  `83/97`, EXP `20170`, gold `21036`, and intact level-18 stats.
- VERIFICATION: `71` map-reader, `107` object, and `147` overworld-route tests
  pass; changed Lua files parse and `git diff --check` passes.

## 2026-07-31 Mountain Cave F1 Northeast Chest Correction

- USER FINDING / CLEAN REPRODUCTION: teleport suggested F1 `(12,0)` could move
  east and west toward the otherwise unreachable chest `(13,5)`. After a floor
  transition refreshed state, the hero reached `(10,0)` by ordinary movement.
  Same-origin raw probes then moved through `(10,0)..(13,0)` eastbound and
  cleanly back through `(12,0)->(11,0)->(10,0)` after separating one Scorpion
  interruption. A second eastbound pass also moved across all three seams.
- CHEST ROUTE: from normally reached `(13,0)`, ordinary autowalk completed five
  south to chest `(13,5)`. This confirms cells `(11,0)`, `(12,0)`, and `(13,0)`
  are genuine passthroughs rather than teleport-tainted evidence.
- TEST-FIRST PATCH: the Mountain Cave packed fixture now preserves the live raw
  type-A values at `(11,0)..(13,0)` and asserts all three are passthroughs. The
  focused map-reader suite failed at `(11,0)` before the source change and all
  71 tests passed after the three-cell `MAP_PASSTHROUGH_CELLS[0x16]` addition.
- POST-RELOAD VALIDATION: with no runtime blocks, all three patched cells
  reported `reason=passthrough`, `base_walkable=true`, and
  `effective_passable=true`. Loaded-source routing crossed from chest `(13,5)`
  west through `(13,0)..(10,0)` and entered ordinary interior `(10,1)` after a
  fresh post-Magician probe. The full reverse route then completed
  `(10,1)->(10,0)->(11,0)->(12,0)->(13,0)->(13,5)` without reroute or runtime
  blocker.
- FINAL LIVE CHECKPOINT: tag `MCAVE_F1_CHEST_ROUTE_VALIDATED_20260731`, F1
  `(13,5)`, field clear, no active path/runtime blockers, HP `115/115`, MP
  `77/97`, EXP `20275`, gold `21401`, and intact level-18 stats.

## 2026-07-31 Mountain Cave F1 Return-Route Barrier Correction

- REPEATED ROUTE EVIDENCE: both manual returns from the northeast chest reached
  `(8,1)`, attempted `DOWN` into `(8,2)`, and logged `blocked_only` before a
  successful 24-step reroute. The existing source blocked only the opposite
  `(8,3)->UP` approach.
- NORMAL-ORIGIN PROBE: from exit `(0,7)`, ordinary routing reached `(8,1)` with
  no teleport or runtime blocks. A same-origin `probe_edge:DOWN` remained at
  `(8,1)` and reported `status=blocked`, `reason=raw_hold_timeout`, plus
  `blocked_despite_open_preview` because `(8,2).north` was absent from source.
- RUNTIME REVIEW: temporary edge `(8,2).north` made the planner choose the safe
  detour immediately. The route reached exit `(0,7)` after separating battle
  and input-contamination interruptions; the overlay was then cleared.
- TEST-FIRST PROMOTION: a focused assertion for `(8,2).north` failed before the
  source edit and all 71 map-reader tests passed after changing the permanent
  entry to `{north = true, south = true}`. East and west remain unblocked
  because they were not tested.
- POST-RELOAD SOURCE VALIDATION: with zero runtime blocks, explicit inspection
  reported `(8,1)->DOWN` as `approach_blocked=true` and
  `effective_passable=false`. A full source-only route repositioned from exit
  `(0,7)` to chest `(13,5)`, then returned to `(0,7)` without attempting the
  blocked shortcut, rerouting, or adding a runtime block. Magician, Druin, and
  Scorpion interruptions were resumed from fresh field baselines and were not
  treated as geometry.
- FINAL LIVE CHECKPOINT: tag `MCAVE_F1_RETURN_BLOCK_SOURCE_VALIDATED_20260731`,
  F1 exit `(0,7)`, field clear, no active path/runtime blockers, HP `115/115`,
  MP `75/97`, EXP `20341`, gold `21537`, and intact level-18 stats.

## 2026-08-03 Rainbow Bridge Route Orientation

- BRANCH: `codex/charlock-rainbow-bridge-route`, created from commit `b5af486`.
- READ-ONLY LIVE BASELINE: fresh probe `RAINBOW_ROUTE_BASELINE` found the hero
  on World Map `(43,43)` at Tantegel Castle, with no active overworld route,
  local path, or runtime blocks. No movement command was issued.
- EXTERNAL ORIENTATION ONLY: NESMaps' 120-by-120 background map and two guide
  descriptions place the Rainbow Drop use point on the western desert tip
  northwest of Rimuldar. Translating the map with the repo's live coordinate
  anchor identifies the use stand as `(65,49)`, the one-tile bridge channel as
  `(64,49)`, and the Charlock-side desert landing as `(63,49)`.
- RECOMMENDED STAGING POINT: Swamp Cave South Entrance `(104,49)`. This is a
  physical Travel landmark and the live-corrected endpoint shared with the
  existing Rimuldar routes. The decoded background map shows a direct
  westbound corridor from `(104,49)` to `(65,49)`; static shortest-path shape
  is `LEFT 39`, with `RIGHT 39` as the tentative return. Reuse existing
  waypoint `(93,49)` when splitting the route for bounded live validation.
- STATIC / DO NOT PROMOTE YET: coordinates and route shape still require
  ordinary-movement validation from a fresh `(104,49)` baseline. Do not treat
  the background-map corridor as runtime seam proof.
- NEXT CHECK: after the user places the hero at World Map `(104,49)`, fresh
  probe position/state, validate westbound segments toward `(65,49)`, confirm
  the Rainbow Drop interaction, then validate the eastbound return.
- FRESH LIVE BASELINE: tag `RAINBOW_BRIDGE_STAGE_104_49` confirmed World Map
  `(104,49)`, field state, no active route/path/runtime blocks, and neutral
  controller input. The idle FCEUX `LeftAlt` latch was present but had no
  bridge buttons and was not treated as route evidence.
- CLEAN LIVE CYCLE 1: explicit `auto_walk:93,49` completed `(104,49)->(93,49)`
  in 11 `LEFT` steps. Every seam reported `passable_only`; there were zero
  retries, battles, drift events, or runtime blocks.
- SELECTION HAZARD: bare `auto_walk` while the physical Swamp Cave South
  landmark was selected replaced `rimuldar` with `swamp_cave_south` and
  immediately reported arrival without moving. This was command-selection
  behavior, not geometry evidence. The new route definitions preserve their
  established physical-landmark bindings so target refreshes do not replace
  an outbound or return route mid-run.
- SOURCE READY FOR RELOAD: `objects.lua` adds the Rainbow Bridge unlock
  landmark at `(65,49)`. `overworld_routes.lua` adds bounded outbound
  `rainbow_bridge` waypoints `(104,49),(93,49),(83,49),(73,49),(65,49)` and
  exact reverse `rainbow_bridge_return` waypoints. Focused tests pass:
  `150/150` overworld-route and `108/108` object tests; changed Lua files parse
  under the pinned LuaJIT runtime and `git diff --check` passes.
- PRE-RELOAD LIVE CHECKPOINT: World Map `(93,49)`, route stopped, local path
  nil, and runtime blocks none. FCEUX is still running the old source.
- NEXT CHECK: manually reload `main.lua`, fresh-probe `(93,49)`, then select
  and run `rainbow_bridge` through `(83,49)`, `(73,49)`, and `(65,49)` before
  validating the Rainbow Drop interaction and eastbound return.
- POST-RELOAD OUTBOUND: fresh tag `RAINBOW_BRIDGE_RELOAD_93_49` confirmed
  `(93,49)`, field control, route/path/runtime blocks none, and neutral game
  input. `start_overworld_route:rainbow_bridge` selected `(83,49)` as waypoint
  index 3. Bare `auto_walk` retained the active bridge route even though the
  physical Swamp Cave South object was selected.
- CLEAN LOADED-SOURCE SEGMENTS: `(93,49)->(83,49)` and
  `(83,49)->(73,49)` completed with all seams `passable_only`, no battle,
  reroute, or runtime blocker. The second segment settled at `(72,49)` and
  logged `AUTO_STEP_FINAL_CARRY_ACCEPTED`; treat that as bounded executor
  timing, not geometry.
- REJECTED STRAIGHT FINAL LEG: the next route reached `(70,49)` but exhausted
  both timing retries on `LEFT` into `(69,49)`, logging `blocked_only`.
  Correctly mapping the external 128-by-128 image canvas to the game's
  120-by-120 coordinates showed `(68,49)` and `(69,49)` are the two water
  cells of an inlet. This is route-shape evidence, not a hidden directional
  blocker, and no runtime/permanent blocker was added.
- CLEAN INLET DETOUR: normal raw probes, bounded by the surrounding water and
  mountains, reached the unlock stand without teleporting:
  `(70,49)->(70,51)->(69,51)->(69,50)->(67,50)->(67,49)->(65,49)`.
  The raw south probe carried across `(70,50)` to `(70,51)`; the intended
  shortest waypoint route is `(70,49)->(70,50)->(67,50)->(67,49)->(65,49)`.
  Every detour probe reported `status=moved` and no runtime blocker was added.
- WAYPOINT CONFIRMED: fresh tag `RAINBOW_BRIDGE_UNLOCK_STAND_65_49` reports
  World Map `(65,49)`, field control, route/path/runtime blocks none, and
  `OBJECT: Rainbow Bridge unlock point: here`. Inventory byte `C2=0xE3`
  confirms the Rainbow Drop is still held at this checkpoint.
- CORRECTED SOURCE READY FOR RELOAD: outbound and return routes now include
  exact reverse inlet waypoints `(70,49),(70,50),(67,50),(67,49)` between the
  row-49 road and `(65,49)`. Focused verification passes `150/150` route and
  `108/108` object tests, LuaJIT syntax, and `git diff --check`.
- NEXT CHECK: user uses the Rainbow Drop manually at `(65,49)` and closes any
  resulting dialogue, then manually reloads `main.lua`. Fresh-probe bridge
  state, start `rainbow_bridge_return`, and live-validate the corrected inlet
  detour plus the full eastbound return to `(104,49)`.
- RAINBOW DROP ACTIVATION CONFIRMED: after the user's item-use message and
  reload, fresh tag `RAINBOW_BRIDGE_POST_DROP_RELOAD` remained at `(65,49)`.
  Progress byte `CF` changed from `0x11` to `0x19`, setting the bridge-state
  bit. Normal same-origin probes then crossed the new bridge in both
  directions: `(65,49)->LEFT` traversed `(64,49)` and settled `(63,49)`;
  `(63,49)->RIGHT` traversed `(64,49)` and settled `(65,49)`.
- LOADED-SOURCE RETURN DETOUR: `rainbow_bridge_return` started at `(65,49)`
  with `(67,49)` as waypoint index 2. Segments to `(67,49)` and `(67,50)`
  completed. The queued `(67,50)->RIGHT` step stopped once, but a clean
  same-origin raw probe moved through `(68,50)` to `(69,50)`, proving the stop
  was executor timing; no blocker was added. Loaded-source routing then
  completed `(69,50)->(70,50)->(70,49)->(73,49)->(83,49)->(93,49)`.
- RETURN CAVE ENTRY: the final 11-step segment passed every row-49 seam and
  stepping east from `(103,49)` entered Swamp Cave map `0x15` at `(0,29)`.
  Geometry is therefore live-proven end to end. The route remained active at
  index 9 because the new return definition did not yet declare map `0x15` as
  its destination; it was stopped manually after fresh tag
  `RAINBOW_BRIDGE_RETURN_CAVE_ENTRY` confirmed route/path cleanup and zero
  runtime blockers.
- TEST-FIRST ARRIVAL FIX: the return regression now requires entry into map
  `0x15` to emit arrival and clear the route. It failed with a nil arrival
  before source added `destination_maps = {0x15}`. Verification is green at
  `150/150` route tests, `108/108` object tests, LuaJIT syntax, and
  `git diff --check`.
- CURRENT LIVE CHECKPOINT: Swamp Cave map `0x15` `(0,29)`, field clear, route
  none, local path nil, runtime blocks none. FCEUX still needs a manual reload
  for the destination-map cleanup fix.
- NEXT CHECK: reload `main.lua`, use `STAIRS` to exit at World Map `(104,49)`,
  move west to `(103,49)`, start `rainbow_bridge_return`, and take the final
  east step back into map `0x15`. Confirm `event=arrived`, route none, and no
  active path/runtime blockers.
- FINAL DESTINATION CLEANUP VALIDATED: post-reload tag
  `RAINBOW_RETURN_DESTINATION_RELOAD` confirmed the new source was polling.
  From World Map `(103,49)`, `rainbow_bridge_return` started at final waypoint
  index 9. A one-frame simulated manual tap only produced an early movement
  twitch and did not leave `(103,49)`; it is not route evidence. The loaded
  one-step autowalk then entered Swamp Cave `0x15` at `(0,29)` and emitted
  `OVERWORLD_ROUTE: event=arrived route=rainbow_bridge_return`.
- FINAL CLEAN STATE: Swamp Cave `(0,29)`, route `none`, path target `nil`, and
  no runtime blockers. The entry used one guarded twitch re-press and both
  bounded timing retries before succeeding; no permanent or runtime blocker
  was added. Rainbow Bridge waypoint, activation, bidirectional crossing, and
  both travel directions are now live-validated.

## 2026-08-03 Charlock Castle Overworld Route

- EXTERNAL ORIENTATION: NESMaps and guide descriptions placed Charlock Castle
  five tiles south and five tiles east of Tantegel, matching the repo's
  existing World Map landmark `(48,48)`. External material was used only to
  seed the candidate; every retained turn below was exercised live.
- LIVE ISLAND ENTRY: from the formed bridge's west landing `(63,49)`, normal
  probes established this passable corridor:
  `(63,49)->(61,49)->(61,50)->(58,50)->(58,55)->(57,55)->(57,56)->(56,56)->(56,64)->(51,64)->(51,62)->(50,62)->(50,61)->(49,61)->(49,57)->(51,57)->(51,49)`.
  The final approach reaches `(48,49)` and steps north onto `(48,48)`.
- CASTLE TRANSITION CONFIRMED: a clean raw step onto World Map `(48,48)`
  emitted `EVENT: map change -> 0x02 (Charlock Castle)` and landed at
  `(10,19)`. Leaving south from `(10,19)` returned to World Map `(48,48)`.
  No runtime or permanent blocker was added during the island investigation.
- SOURCE READY FOR RELOAD: `overworld_routes.lua` adds full
  `charlock_castle` and `charlock_return` routes between the Swamp Cave south
  doorstep and Charlock Castle, sharing the proven Rainbow Bridge inlet
  detour. The route starts at `(103,49)` after cave exit so it cannot steer the
  hero back into the cave. The island waypoints are strict and the return is
  their exact reverse. Focused verification passes `153/153` route tests.
- CURRENT LIVE CHECKPOINT: World Map `(48,48)` immediately outside Charlock
  Castle. FCEUX still runs the pre-change Lua source.
- NEXT CHECK: manually reload `main.lua`, fresh-probe `(48,48)`, start
  `charlock_return`, and live-validate at least the island return through
  `(63,49)`. Then return to `(103,49)` and run `charlock_castle` end to end,
  confirming arrival on map `0x02` and route cleanup.
- FIRST LOADED RETURN PASS: `charlock_return` loaded and completed
  `(48,48)->(48,49)->(51,49)->(51,57)->(49,57)->(49,61)->(50,61)`.
  The next one-step south segment reached `(50,62)` but its settle carried to
  `(50,63)`, producing `route_drift_off_path`. Clean recovery probes established
  `(50,63)->(52,63)->(52,64)->(51,64)`; no blocker was added.
- STATEFUL NORTHEAST TRAP: the loaded return later reached `(61,50)` from the
  west. Route retries and same-origin raw probes blocked north, east, and then
  west despite the earlier inbound route entering from `(61,49)` and leaving
  west. Input guards were clear, buttons were `0x00`, and OAM was aligned with
  a finite sprite-clear loop. Treat `(61,50)` as a stateful arrival trap, not
  static terrain and not a permanent map blocker.
- SECOND SOURCE FIX READY FOR RELOAD: outbound and return no longer stop at
  `(61,50)`; each now performs the south/west or east/north turn as one
  continuous segment. The southwest turn now uses the live recovery chain
  `(50,61)<->(50,63)<->(52,63)<->(52,64)<->(51,64)` instead of the unstable
  one-tile `(50,62)` stop. Focused route tests remain green at `153/153`, Lua
  syntax passes, and `git diff --check` passes.
- CURRENT LIVE CHECKPOINT: guidance stopped; a force teleport extracted the
  hero from the stateful trap to World Map `(58,50)`. This teleport is only
  recovery/staging evidence. FCEUX still needs a manual reload for the second
  route fix.
- NEXT CHECK: reload `main.lua`, fresh-probe `(58,50)`, start
  `charlock_return`, and verify one continuous four-step segment
  `RIGHT,RIGHT,RIGHT,UP` reaches `(61,49)`, then continue to bridge landing
  `(63,49)`.
- POST-RELOAD BINDING FAILURE: starting `charlock_return` at `(58,50)` chose
  the correct `(61,49)` waypoint, but bare `auto_walk` refreshed the nearer
  Rainbow Bridge object and replaced the active route with `rainbow_bridge`.
  That wrong route moved to `(58,49)` and canceled; this run did not exercise
  the revised stateful turn. REPEL expired immediately afterward.
- COMPATIBILITY FIX READY FOR RELOAD: `charlock_return` now treats
  `overworld_rainbow_bridge` as a compatible selected object, matching its
  existing Charlock Castle compatibility. A focused regression proves the
  nearby bridge selection cannot replace the active return. Route tests remain
  `153/153`; Lua syntax and `git diff --check` pass.
- CURRENT LIVE CHECKPOINT: guidance stopped and recovery-only teleport restored
  World Map `(58,50)`. FCEUX needs another manual reload before the continuous
  turn can be tested. REPEL is no longer active.
- LOADED CONTINUOUS-TURN PROOF: after the compatibility reload,
  `charlock_return` stayed active while the selected object refreshed to
  Rainbow Bridge (`active_matches=true`). The four-step
  `(58,50)->RIGHT,RIGHT,RIGHT,UP->(61,49)` segment completed, then the route
  reached bridge landing `(63,49)`, accepted expected final carry onto bridge
  tile `(64,49)`, and continued through the unlock point `(65,49)` to
  peninsula edge `(67,49)`.
- STATEFUL INLET TRAP: after arriving eastbound and settling at `(67,49)`, the
  next DOWN exhausted both bounded retries and blocked. The already proven
  outbound route enters `(67,49)` from the south and leaves west, so this is
  approach/state dependent rather than static terrain evidence. No blocker was
  added. Source now makes the return cross `(67,49)` inside one continuous
  east-then-south segment from `(65,49)` to `(67,50)`.
- CURRENT LIVE CHECKPOINT: World Map `(67,49)` with `charlock_return` active
  after the blocked DOWN. FCEUX needs a manual reload for the inlet-turn fix;
  recovery staging should return to `(65,49)` before retesting the three-step
  `RIGHT,RIGHT,DOWN` segment.
- ROUTE-ALTERNATE RELOAD FINDING: after recovery staging and reload at
  `(65,49)`, explicitly requesting `charlock_return` selected the intended
  shorter `rainbow_bridge_return` alternate. That route duplicated the same
  unsafe `(67,49)` stop, so the continuous east-then-south fix now applies to
  both eastbound return variants. This preserves the normal near-bridge route
  optimization while removing the known stateful stop.
- CONTROL CONTAMINATION: the recovery-only force-teleported `(65,49)` state
  blocked previously proven RIGHT movement, and another force restage at
  `(61,49)` initially did the same. Subpixels changed without a coordinate
  commit; a manual game command-menu open/close restored ordinary control.
  These failures are timing/control contamination and must not become map
  blockers.
- SLOW BRIDGE-EDGE CADENCE: after normal movement reacquired `(65,49)`, the
  three-step return segment still timed out after detecting motion on the first
  RIGHT. A same-origin raw hold proved the edge passable and naturally carried
  `(65,49)->(67,49)`; the next DOWN completed at `(67,50)`. Both return variants
  now attach a 60-frame sustained-hold/early-twitch window to the continuous
  inlet turn and preserve movement state across its south turn.
- END-TO-END RETURN PROOF: from naturally reacquired bridge-side positions,
  loaded `charlock_return` completed the remainder through
  `(67,50)->(70,50)->(70,49)->(73,49)->(83,49)->(93,49)` and entered Swamp Cave
  map `0x15` at `(0,29)`. It emitted `event=arrived`, cleared route/path state,
  and left no runtime blockers. No battle interrupted the run.
- CURRENT LIVE CHECKPOINT: Swamp Cave `0x15` `(0,29)`, route none, path nil,
  no runtime blockers, neutral input. FCEUX needs a manual reload for the
  bridge-edge cadence metadata before the outbound Charlock route is run from
  World Map `(103,49)`.
- END-TO-END OUTBOUND PROOF: after reload at World Map `(104,49)`, loaded
  `charlock_castle` started from the safe doorstep `(103,49)`, retained the
  active route while the Rainbow Bridge object remained selected, crossed the
  formed bridge, and traversed the corrected southwest recovery chain. It
  entered Charlock Castle map `0x02` at `(10,19)`, emitted `event=arrived`,
  cleared route/path state, and left no runtime blockers. REPEL expiration
  caused one player-cleared dialogue/menu pause; route state remained intact.
- OUTBOUND TIMING EVIDENCE: autowalk stopped at `(58,55)->LEFT` and
  `(50,61)->LEFT`, but clean unchanged-origin `probe_edge:LEFT` holds moved to
  `(57,55)` and `(49,61)` and advanced the active route. These are cadence
  failures, not blocked tiles. Both outbound target waypoints now use a
  60-frame sustained-hold/early-twitch window. No runtime or permanent blocker
  was added.
- CURRENT LIVE CHECKPOINT: Charlock Castle map `0x02` `(10,19)`, route none,
  path nil, no runtime blockers, and controller buttons neutral. FCEUX needs a
  manual reload before the new outbound timing metadata can be live-checked.

## 2026-08-04 Charlock Ground Floor Decode Start

- FRESH BASELINE: `CHARLOCK_F1_BASELINE` and `CHARLOCK_F1_STATE` were consumed
  live. Position was Charlock Castle map `0x02` `(10,19)`, with no runtime
  blockers and no previous map-crawl report.
- STATIC PLAN: `debug_pathfind_to:10,3` found an 18-step route to the throne
  clue tile: `5 north, 1 west, 10 north, 1 east, 1 north`. With mobile NPCs
  parked, `auto_walk:10,3` replanned to `16 north`.
- CONTAMINATED / DO NOT PROMOTE: autowalk never committed the first tile from
  `(10,19)`. UP, LEFT, and RIGHT all produced subpixel/twitch evidence followed
  by timeouts; the route executor temporarily avoided `(10,18)`, `(9,19)`, and
  `(11,19)`, but `stop_auto_walk` cleared route state and no runtime or
  permanent blocker was added.
- CONTROL DIAGNOSTICS: field state was neutral; menu/dialogue guards were
  inactive; `$004E=0x50` was aligned with a finite sprite-clear loop; NPCs were
  frozen for the direct check and restored afterward. A clean same-origin
  `probe_edge:UP` still returned `raw_hold_timeout` even though tile type 6,
  map decoding, and static directional data all marked `(10,18)` passable.
- RECOVERY ATTEMPT / DO NOT PROMOTE: `reset_movement_state:CHARLOCK_F1_RECOVERY`
  changed movement/subpixel bytes from `0x7F/0x90` to `0x00/0x00`, but a second
  same-origin UP probe still timed out at `(10,19)`. This confirms entrance
  control contamination, not map geometry.
- PAUSED FOR USER: live checkpoint remains map `0x02` `(10,19)`, route none,
  runtime blocks none, NPCs unfrozen, and controller buttons neutral at fresh
  tag `CHARLOCK_F1_PAUSE`. Open and close the in-game command menu once (the
  established control recovery), then reload `main.lua` because the pending
  outbound timing metadata also needs loading. Fresh-probe before continuing
  with a normal UP step, then start `sweep_walk` only after movement is proven.
- POST-RELOAD RECOVERY: reload plus command-menu recovery restored ordinary
  control. A same-origin UP hold moved `(10,19)->(10,17)`, disproving the
  contaminated entrance blocks. `sweep_walk` run 1 then proved three north
  edges through `(10,14)` before a Starwyvern battle interrupted the next
  probe. Run 2 recorded 13 open edges, one timing-only unknown, and zero
  confirmed blockers before another battle returned the crawler to `(10,19)`.
- LIVE NPC EXPLANATION: after normal raw movement back to `(10,14)`, direct UP
  reported `npc_blocked=true`. `report_npcs` identified mobile slot 2,
  `Person 1`, at `(10,13)` with movement byte `0xBD`; this is not map data.
- CLEAN MAP-TYPE PROOF / SOURCE READY FOR RELOAD: the west detour normally
  reached `(8,14)` and then `(9,14)`. Repeated same-origin UP probes from
  `(8,14)` and a fresh same-origin UP probe from `(9,14)` all blocked entry
  into adjacent type-4 cells with no NPC, static directional block, or input
  contamination. The staged 20x20 guide image renders the same type-4 cells as
  grey stone and surrounding live-passable type-6 cells as red corridor.
  `map_reader.lua` now applies `[0x02][4] = false` through the existing
  map-scoped tile-walkability override. The focused regression first failed
  `71 pass / 1 fail`, then passed all `72/72`; `luac -p map_reader.lua
  test_map_reader.lua` and `git diff --check` are clean.
- CURRENT LIVE CHECKPOINT: Charlock ground floor `(9,14)`, NPCs unfrozen,
  route none. One pre-source runtime directional overlay remains at type-4
  cell `(8,13).south`; clear it after reload, then fresh-plan to `(10,3)`.
  Three Starwyvern battles were player-cleared during this pass.
- LOADED GROUND-FLOOR ROUTE PROOF: after reload, `(9,13)` correctly reported
  type 4 as `base_walkable=false` with no runtime block. The replanned western
  route from `(9,14)` to throne `(10,3)` then completed every movement segment
  cleanly across battle-resume cycles. Axe Knight, Wizard, Axe Knight,
  Werewolf, and another Axe Knight encounters interrupted navigation without
  producing geometry failures. A field HEAL at `(10,9)` was also driven and
  verified, raising HP before the last encounters.
- THRONE / HIDDEN STAIR PROOF: SEARCH at `(10,3)` produced `Feel the wind
  blowing from behind the throne.` Direct `(10,3)->UP` into type-15 `(10,2)`
  blocked with a clean `raw_hold_timeout`; the correct route goes around the
  west side to `(9,1)`. A same-origin RIGHT probe from `(9,1)` crossed hidden
  type-7 `(10,1)` to `(11,1)`, and a controlled LEFT step stopped on `(10,1)`.
  SEARCH there produced `Bill discovers the Secret Passage.` STAIRS then
  changed map `0x02` to Dragonlord B1 `0x0F`, arriving at `(9,0)`.
- SOURCE READY FOR RELOAD: `MAP_PASSTHROUGH_CELLS[0x02]["10,1"] = true` now
  models the live-passable hidden stair without changing type 7 globally.
  The focused regression failed `71 pass / 1 fail` before the source entry and
  passes in the full `72/72` map-reader suite afterward. `luac -p
  map_reader.lua test_map_reader.lua` and `git diff --check` are clean.
- CURRENT LIVE CHECKPOINT: Dragonlord B1 map `0x0F` `(9,0)`, field state,
  110/115 HP and 57/97 MP. FCEUX needs a manual `main.lua` reload before
  returning upstairs and proving the loaded ground-floor route to hidden stair
  `(10,1)` without raw input.
- LOADED FINAL PROOF: after reload, B1 `(9,0)` was clean. The existing B1
  stair object at `(10,1)` routed there normally, but STAIRS produced `There
  are no stairs here.` Returning to live arrival stand `(9,0)` and selecting
  STAIRS changed back to Charlock map `0x02` at `(10,1)`. This proves the B1
  return object belongs at `(9,0)`, not `(10,1)`.
- GROUND FLOOR COMPLETE: the loaded Charlock patch reports hidden type-7
  `(10,1)` as `base_walkable=true reason=passthrough`. From `(9,1)`, the planner
  produced `Path: 1 east`; ordinary autowalk reached `(10,1)`, completed route
  state, and left zero runtime blocks. A Werewolf battle began immediately
  afterward at `(10,1)` with 115/115 HP, after the route proof was complete.
- OBJECT SOURCE READY FOR RELOAD: Dragonlord B1 `North Stairs Up` now uses
  live-proven `(9,0)` and the regression rejects old `(10,1)`. The test failed
  before source, then passed all `108/108`; map tests remain `72/72`, Lua syntax
  and `git diff --check` are clean. Reload before beginning B1 decode so the
  corrected object coordinate is live.
- B1 INITIAL LIVE DECODE: after reload and scoped FCEUX input recovery, STAIRS
  changed ground map `0x02 (10,1)` to B1 map `0x0F (9,0)`. The corrected
  `North Stairs Up` object reported `here`. Normal autowalk stepped south onto
  type-2 `(9,1)`, then repeated route and seam retries blocked on type-0 cells
  `(9,2)`, `(10,2)`, `(11,2)`, `(8,1)`, and `(12,1)`. Horizontal movement
  within type-2 `(9..11,1)` succeeded. This matches the staged Mike's RPG
  Center B1 entrance chamber. A Green Dragon encounter at `(9,1)` was cleared
  by the user; no runtime blocks remained after stopping autowalk.
- B1 SOURCE READY FOR RELOAD: map `0x0F` now overrides dungeon tile type 0 as
  nonwalkable and treats live-proven boundary return stair `(9,0)` as a
  passthrough. The pinned ROM stair graph replaces provisional B1 descent
  `(7,7)` with the main-spine coordinate `(8,19)`. Both regressions failed
  before source, then passed all `73/73` map-reader and `108/108` object tests;
  Lua syntax and `git diff --check` are clean. CURRENT LIVE CHECKPOINT is B1
  `(9,1)` after the Green Dragon battle. Reload before verifying the corrected
  grid and continuing the entrance-chamber special-passage investigation.
- B1 HIDDEN TOP PASSAGE FOUND: after reload, the corrected type-0 wall rule and
  `(9,0)` return-stair passthrough were live. From `(9,1)`, clean same-origin
  probes moved east through `(10,1)` and `(11,1)`, then north into modeled
  boundary cell `(11,0)`. Further probes moved east through `(12,0)` and
  `(13,0)`, then south to ordinary floor `(13,1)`. This is the missing exit
  from the apparently isolated entrance chamber and matches the staged B1 map.
- B1 SECOND SOURCE PATCH READY FOR RELOAD: the complete 20x20 raw grid has
  exactly three type-1 cells, matching all ROM-listed return stairs, and seven
  type-3 cells, matching all ROM-listed B2 descents. Map `0x0F` now treats
  types 1 and 3 as stairs and adds only live-proven top-row passthrough cells
  `(11,0)`, `(12,0)`, and `(13,0)`. The focused regression failed before the
  patch, then passed all `73/73`; Lua syntax and `git diff --check` are clean.
  CURRENT LIVE CHECKPOINT is B1 `(13,1)`, field clear. Reload, then select the
  corrected main descent `(8,19)` and run ordinary autowalk.
- B1 HIDDEN PERIMETER CORRIDOR PROOF: loaded-source routing reached `(7,1)`.
  Clean same-origin probes moved north to `(7,0)`, west through every top-row
  cell to `(0,0)`, and south through `(0,6)`. Ordinary interior routing then
  reached `(1,9)`; a same-origin LEFT probe entered `(0,9)`, UP reached
  `(0,8)`, and a second UP cleanly blocked against real type-0 wall `(0,7)`.
  After a player-cleared Starwyvern battle at `(0,9)`, repeated normal-origin
  probes moved south through every boundary cell `(0,10)..(0,19)`. DOWN from
  `(0,19)` correctly blocked outside the 20x20 map. No runtime blocker was
  present or added.
- B1 MAIN DESCENT ARRIVAL: from bottom-left `(0,19)`, RIGHT reached ordinary
  floor `(1,19)`. The loaded planner then found `7 east` to the ROM-backed
  stair `(8,19)`, and ordinary autowalk completed all seven steps without
  battle, drift, or blocker. The hero is now standing on B1 `(8,19)`; the
  STAIRS command still needs a manual live transition check.
- B1 THIRD SOURCE PATCH READY FOR RELOAD: `MAP_PASSTHROUGH_CELLS[0x0F]` now
  contains the complete live-proven hidden perimeter cells `(0..7,0)`,
  `(0,1..6)`, and `(0,8..19)`, while preserving real wall `(0,7)` and top wall
  `(8,0)`. Focused assertions cover every promoted cell plus both separators.
  Verification passes all `73/73` map-reader tests, Lua syntax, and
  `git diff --check`. Reload at `(8,19)`, then use STAIRS and fresh-report the
  destination map and coordinate.
- B1 TO B2 TRANSITION CONFIRMED: STAIRS at B1 `(8,19)` entered Dragonlord B2
  map `0x10` at `(5,0)`. The first live branch traveled east and south through
  `(6,0),(6,1),(6,2),(7,2),(7,3),(8,3),(9,3)..(9,6),(7,6),(7,7),(6,7),(5,7)`.
  Clean probes proved the apparent exits at `(5,1)`, `(4,7)`, `(5,6)`, and
  `(5,8)` closed. A bounded `sweep_walk` restored its start and stopped safely
  on battle without adding runtime blocks.
- B2 MAIN ROUTE LIVE PROOF: after backtracking, ordinary movement continued
  `(6,7)->(6,8)->(6,9)->(3,9)->(3,8)->(3,7)->(2,7)->(2,6)->(1,6)`. From there,
  same-origin probes entered boundary corridor `(0,6)->(0,5)->(0,4)->(0,3)`;
  UP into type-0 `(0,2)` cleanly blocked. The corridor then reached the main
  B3 stair through `(1,3),(2,3),(2,2),(3,2),(3,1),(3,0)`, with type-0 `(3,3)`
  also cleanly blocked. Other repeated walls included type-0 `(5,2),(5,6),
  (5,8),(6,6)` and type-8 `(5,1),(4,7)`. Type-A corridor cells moved normally.
- B2 SOURCE READY FOR RELOAD: map `0x10` now applies map-scoped type-0/type-8
  wall rules, stair rules for types 1, 3, and ROM-paired type 9, and live
  boundary passthroughs `(3,0),(5,0),(6,0),(0,3..6)`. `objects.lua` replaces
  stale B2 placeholders `(7,7)` and `(3,3)` with the live main stairs `(5,0)`
  up and `(3,0)` down. The new tests failed before source, then passed all
  `74/74` map-reader and `108/108` object tests. CURRENT LIVE CHECKPOINT is B2
  `(3,0)`, field clear, HP `90/130`, MP `15/103`. Reload, fresh-probe, then use
  STAIRS to verify the expected B3 transition to map `0x11` at `(7,0)`.

## 2026-08-05 Charlock B3 Main Route Decode

- TRANSITIONS CONFIRMED: B2 `(3,0)` entered B3 `(7,0)`; B3 false stair `(0,9)`
  returned to B2 `(1,9)`; B2 branch stair `(0,8)` entered B3 `(5,4)`.
- CLEAN MAIN ROUTE: the `(5,4)` component moved through
  `(6,4)->(6,3)->(6,2)->(5,2)->(4,2)->(4,1)->(4,0)`, west across top boundary
  to `(0,0)`, then south through `(0,1..6)` and east to B4 stair `(1,6)`.
- CLEAN WALLS: repeated same-origin probes rejected type-0 cells around the
  `(7,4)/(7,5)` alcove and type-8 cells around `(6,3)`. Boundary separators
  `(6,0)` type 8 and `(0,7)` type 0 remain closed. No runtime block was added.
- MODEL PATCH: B2 gains branch passthroughs `(0,8),(0,9)`. B3 gains map-scoped
  type-0/type-8 wall rules, type-1/type-3 stair rules, the proven upper-left and
  lower-left boundary cells, and all six ROM-backed stair objects. Focused
  tests intentionally failed before source, then passed `75/75` map-reader and
  `108/108` object tests; Lua syntax and `git diff --check` are clean.
- CONTAMINATED / DO NOT PROMOTE: an earlier settled B3 `(4,9)` temporarily
  rejected previously crossed exits, and recovery teleport caused the known
  FCEUX control lock until Start. Later normal-route movement crossed those
  cells cleanly; do not model the temporary failures as geometry.
- CURRENT LIVE CHECKPOINT: B3 `(1,6)`, HP `59/130`, MP `101/103`, field clear.
  Reload `main.lua`, fresh-check the loaded model and `West Stairs Down`, then
  use STAIRS; expected destination is B4 map `0x12` `(0,9)`.

## 2026-08-06 Charlock B4 Main Route Decode

- TRANSITIONS CONFIRMED: B3 `(1,6)` entered B4 `(0,9)`; B4 `(2,2)` entered B5
  `(9,0)` and returned to B4 `(2,2)`. B4 `(7,7)` is the ROM-backed return to
  the separate B3 sword branch.
- CLEAN MAIN ROUTE: ordinary movement connected descent `(2,2)` through the
  east and south corridors to `(9,2)->(9,9)->(5,9)->(5,6)->(2,6)`, then the
  entrance-side route reached `(2,7)->(2,8)->(1,8)->(0,8)->(0,9)`.
- CLEAN WALLS: same-origin probes blocked type-0 `(2,5)` 2/2 from `(2,6)` and
  type-8 `(2,9)` 2/2 from `(1,9)`. The earlier loaded planner's direct cuts
  through those cells were false.
- MODEL PATCH READY FOR RELOAD: map `0x12` now applies type-0/type-8 wall rules,
  type-3/type-9 stair rules, and west-boundary passthroughs `(0,8),(0,9)`.
  `objects.lua` exposes all four ROM-backed B4 stairs at `(0,9)`, `(7,7)`,
  `(2,2)`, and `(8,1)`. Verification passes `76/76` map-reader and `108/108`
  object tests, Lua syntax, and `git diff --check`.
- CONTAMINATED / DO NOT PROMOTE: all reroutes and seam results from the
  post-teleport control lock at B4 `(2,2)` are invalid. Seam memory was cleared
  before clean normal movement resumed; later proof moved `(2,2)->(3,2)`.
- CURRENT LIVE CHECKPOINT: B4 `(1,9)`, field clear. Reload `main.lua`, then
  verify the source-only route to main descent `(2,2)`.

## 2026-08-06 Charlock B5 Main Route Decode

- TRANSITION CONFIRMED: B4 main descent `(2,2)` entered B5 `(9,0)`.
- CLEAN MAIN ROUTE: ordinary movement followed the east boundary south to
  `(9,9)`, crossed the bottom corridor west to `(0,9)`, then same-origin raw
  probes moved north through every west-boundary cell `(0,8)..(0,0)` to the
  ROM-backed B6 descent. Battles at `(3,9)`, `(0,4)`, and `(0,3)` happened
  after arrival on those cells and were not treated as wall evidence.
- CLEAN WALLS: `(9,0)->LEFT` blocked on type-8 `(8,0)`. A mistaken loaded
  reroute also cleanly blocked `(2,9)->UP` into type-8 `(2,8)` before a later
  battle contaminated the attempted alternate at `(3,9)`.
- MODEL PATCH READY FOR RELOAD: map `0x13` now treats type 8 as wall and types
  9/B as stairs, and exposes the live main boundary cells `(9,0)` and
  `(0,0..9)` as passthroughs. `objects.lua` exposes all four ROM-backed B5
  stairs at `(9,0)`, `(4,0)`, `(0,0)`, and `(5,5)`. Focused regressions failed
  before source, then passed `77/77` map-reader and `108/108` object tests;
  Lua syntax and `git diff --check` are clean.
- CURRENT LIVE CHECKPOINT: B5 `(0,0)`, field clear. Reload `main.lua`, verify
  the loaded main route and `Northwest Stairs Down`, then use STAIRS; expected
  destination is B6 map `0x14` `(0,6)`.

## 2026-08-06 Charlock B6 Main Route Decode

- TRANSITION CONFIRMED: B5 main descent `(0,0)` entered B6 `(0,6)` after the
  B5 source reload.
- CLEAN MAIN ROUTE: `(0,6)->RIGHT` entered the type-2 lower component, ordinary
  autowalk crossed row 6 to `(8,6)`, and a same-origin probe moved right onto
  the ROM-backed final descent `(9,6)`. Type-2 `(8,5)` also moved bidirectionally
  from `(8,6)`, so the lower component is wider than only the visible row.
- CLEAN WALLS: `(0,6)->UP` blocked on type-0 `(0,5)`, and `(9,6)->UP` blocked
  on type-0 `(9,5)` even though the loaded generic model predicted the latter
  open. Type 8 belongs to the separate upper false-loop component and remains
  UNRESOLVED until reached through normal play.
- MODEL PATCH READY FOR RELOAD: map `0x14` now treats type 0 as wall and types
  1/3 as ROM-backed stairs, with live west-boundary passthrough `(0,6)`.
  `objects.lua` exposes all four ROM-backed B6 stairs at `(0,6)`, `(0,0)`,
  `(9,0)`, and `(9,6)`, including a non-directional label for the same-floor
  loop stair. Focused regressions failed before source, then passed `78/78`
  map-reader and `108/108` object tests; Lua syntax and `git diff --check` are
  clean.
- CURRENT LIVE CHECKPOINT: B6 `(9,6)`, field clear, standing on the final
  descent. Reload `main.lua`, verify `East Stairs Down`, then use STAIRS;
  expected destination is Dragonlord's Lair map `0x06` `(10,29)`.

## 2026-08-06 Dragonlord's Lair Decode

- TRANSITION CONFIRMED: B6 `(9,6)` entered Dragonlord's Lair map `0x06` at
  `(10,29)`. The arrival initially had the known post-teleport/stair control
  lock; Start restored normal movement before route evidence was collected.
- CLEAN TILE RULE: ordinary coordinate autowalk traced the winding corridor
  through type-6 cells while repeatedly rejecting adjacent type-4 cells.
  From the naturally reached corridor end `(16,17)`, inspection showed type 6
  behind at `(16,16)` and type 4 on the other three sides; a same-origin raw
  probe cleanly blocked `(16,17)->LEFT` into type-4 `(15,17)`.
- MODEL PATCH READY FOR RELOAD: map `0x06` now treats type 4 as wall while
  preserving type 6 as walkable. The focused regression failed before source,
  then passed all `79/79` map-reader tests; Lua syntax and `git diff --check`
  are clean.
- RUNTIME-ONLY CONFIRMED EDGES: the pre-patch model retained explicit blocks
  for `(10,25)->EAST` and `(11,24)->EAST`. Both destinations are type-4 walls,
  so clear map `0x06` runtime blocks after reload and verify the source-only
  route instead of promoting redundant directional entries.
- CLEAN FINAL-APPROACH PASSAGES: normal-route movement reached `(28,12)`.
  Same-origin probes moved south through raw type-0 `(28,13)` and carried to
  `(28,14)`, moved through raw type-0 `(25,16)` and carried to `(25,17)`, and
  moved through raw type-0 `(25,21)` and carried to `(25,22)`. Each probe began
  with zero runtime blocks and continued onto an already modeled corridor.
- MODEL PATCH READY FOR RELOAD: map `0x06` now has coordinate-scoped
  passthroughs for `(28,13)`, `(28,14)`, `(25,16)`, and `(25,21)`. Other raw
  type-0 cells deliberately remain blocked pending live proof.
- LOADED ROUTE VERIFIED: after reloading `main.lua`, all four raw type-0 route
  cells reported `walkable=true reason=passthrough`. Source-only autowalk then
  completed the eight westward steps from `(25,24)` to `(17,24)` without a
  reroute or runtime block.
- FINAL NPC CONFIRMED: from `(17,24)`, inspection reports the type-6 destination
  `(16,24)` as walkable terrain occupied by one blocking NPC. Earlier object
  survey identified the generic RAM sprite as `Old Man`; the coordinate-scoped
  object role now labels this final-encounter NPC `Dragonlord` while keeping him
  out of Services.
- CURRENT LIVE CHECKPOINT: Dragonlord's Lair `(17,24)`, HP `69/130`, MP
  `7/103`, field clear, one tile east of Dragonlord.
- FINAL ENCOUNTER VERIFIED: the user initiated TALK from `(17,24)`, and the
  speech bridge captured `Welcome, Bill. I am the Dragonlord--King of Kings.`
  This confirms that the blocking NPC at `(16,24)` is Dragonlord and that the
  decoded main route reaches the intended final encounter. No dialogue was
  advanced by the verification probe; restoring the pre-encounter save state
  is safe.
- LOADED OBJECT LABEL VERIFIED: after restoring the pre-dialogue save state and
  reloading `main.lua`, the NPC filter reported
  `Dragonlord (stationary): 1 west` for object `(16,24)` from hero `(17,24)`.
  The field remained clear with zero runtime blocks and zero injected buttons.

## 2026-08-06 Charlock Erdrick's Sword Branch

- B3 RETURN COMPONENT: normal autowalk moved from B3 `(7,7)` to stair
  `(2,2)` without blockers; STAIRS then entered B2 `(9,1)` as predicted by
  the ROM stair graph.
- B2 NORTHEAST HIDDEN CORRIDOR: from the natural stair arrival at `(9,1)`, a
  same-origin DOWN probe into raw type-0 `(9,2)` blocked. A same-origin UP
  probe moved into boundary tile `(9,0)`, then a LEFT probe moved onto stair
  `(8,0)`. The clean route is therefore `(9,1)->(9,0)->(8,0)`; do not promote
  `(9,2)`.
- B1 NORTHEAST DEAD END: B2 stair `(8,0)` entered B1 `(15,1)`. Same-origin
  probes blocked DOWN `(15,2)`, LEFT `(14,1)`, and RIGHT `(16,1)`; only UP
  moved to `(15,0)`. The boundary arm then ran east through
  `(16,0)..(19,0)` and south through `(19,1)..(19,3)`. Same-origin probes at
  `(19,3)` blocked both DOWN `(19,4)` and LEFT `(18,3)`, proving this branch
  is a deliberate dead end. A Wizard encounter at `(19,0)` was combat-only.
- NEXT CHECK: return through B1 stair `(15,1)` to B2 `(8,0)`, retrace through
  `(9,0)` to B2 `(9,1)`, and test the still-untried LEFT edge `(8,1)` toward
  the sword network. Do not promote the B1 dead-end arm as the sword route.
- B2 `(9,1)` COMPONENT CLOSED: after returning from the B1 dead end, the
  reverse route `(8,0)->(9,0)->(9,1)` moved cleanly. A same-origin LEFT probe
  into `(8,1)` blocked, joining the earlier blocked DOWN `(9,2)` result. Thus
  B2 `(9,1)` connects only north through `(9,0)` to the B1 dead end and back
  through its B3 stair; it does not directly reach the sword chest.
- B3 FALSE-LINK CHECK / DO NOT PROMOTE: after returning normally to B3, the
  modeled route reached `(6,7)`. A same-origin UP probe from `(6,7)` into raw
  type-0 `(6,6)` blocked cleanly. The earlier hypothesis that the `(7,7)` /
  `(2,2)` component directly connects to stair `(5,4)` was wrong.
- CORRECTED SWORD LINK: the external walkthrough says the B3 path from `(7,7)`
  to `(2,2)` is the intended unbranched sword path. B2 then places its B1 stair
  immediately beside the B3 stair. The missed onward route is therefore on B1
  after stair `(15,1)`: head east, then southwest to another B2 stair. Recheck
  side exits from the previously traversed B1 boundary arm instead of probing
  for an interior B3 connection.
- B1 SWORD CORRIDOR FOUND: from the natural B1 stair arrival `(15,1)`, clean
  same-origin movement followed `(15,1)->(15,0)->(16,0)->(17,0)->(18,0)->
  (19,0)->(19,1)->(19,2)`. SOUTH from top-row `(16,0)`, `(17,0)`, and `(18,0)`
  blocked, as did LEFT from `(19,1)`. The previously missed LEFT edge from
  `(19,2)` moved to `(18,2)`, opening the modeled southwest zigzag to B1 stair
  `(13,7)`. Autowalk then reached `(13,7)` cleanly. ROM pairing predicts B2
  `(4,4)` after STAIRS.
- SWORD ROOM REACHED: B1 stair `(13,7)` entered B2 `(4,4)` as predicted. The
  loaded object system identified `Chest` at `(5,5)`, and clean autowalk moved
  `(4,4)->(4,5)->(5,5)`. The hero is standing on the chest tile, ready for the
  player to use TAKE and verify Erdrick's Sword/equipment state.
- ERDRICK'S SWORD VERIFIED: TAKE produced `Fortune smiles upon thee, Bill. Thou
  hast found the Erdrick's Sword.` Equipment byte `$00BE` changed to `0xFF`,
  and Attack rose from `0x73` (115) to `0x7F` (127), the expected +12. A return
  autowalk to B2 stair `(4,4)` was refused because a submenu remained open;
  clear the menu before resuming the return route.

## 2026-08-06 Charlock False Branch And B6 Loop

- TRANSITIONS CONFIRMED: B4 `(8,1)` entered B5 `(4,0)`; B5 `(5,5)` entered
  B6 `(0,0)`; B6 loop stair `(9,0)` returned to B6 `(0,0)` on the same map.
- CLEAN B5 ROUTE: same-origin probes moved east from `(4,0)` through hidden
  top-boundary cells `(5,0)..(7,0)`. From `(7,0)`, the loaded tile model
  planned `7 south, 5 west, 5 north, 3 east, 3 south` to `(5,5)`, and ordinary
  autowalk traversed the full inner corridor. An Armored Knight interruption
  at `(7,3)` and a Stoneman at the destination were combat-only.
- CLEAN B6 LOOP CORRIDOR: same-origin movement crossed the complete hidden top
  row `(0,0)..(9,0)`. The hero reached loop stair `(9,0)`, and normal STAIRS
  returned to `(0,0)` without changing map `0x14`.
- CONTAMINATED / DO NOT PROMOTE: two `(3,0)->RIGHT` raw holds timed out while
  the user confirmed controls were locked. After Start restored control, the
  same edge moved cleanly to `(4,0)`, followed by clean movement through every
  remaining top-row cell. The timeouts are input-state evidence, not blockers.
- MODEL PATCH LOADED AND VERIFIED: map `0x13` adds boundary passthroughs
  `(4,0)..(7,0)`; map `0x14` adds `(0,0)..(9,0)`. Verification passes `79/79`
  map-reader and `109/109` object tests, Lua syntax, and `git diff --check`.
  After reload, source-only planning produced exactly `9 east` from B6 `(0,0)`
  and ordinary autowalk completed at `(9,0)` with no runtime blockers. STAIRS
  returned to B6 `(0,0)`, completing loaded validation of the loop.

## 2026-08-06 Charlock Ground-Floor Phantom NPCs

- FRESH BASELINE: map `0x02` at entrance `(10,19)`, field clear, HP/MP full,
  no runtime blockers, and selected target `Stairs Down` at `(10,1)`.
- PHANTOM NPC ROOT CAUSE: the normal planner found no path after accepting 20
  blocking NPC RAM slots, including a full guard/merchant/townsfolk roster and
  many coordinates outside Charlock's 20x20 bounds. The skip-NPC planner found
  a 60-step route to `(10,1)`, isolating the failure from map geometry.
  Charlock uses town terrain offset `0x10` but has no ordinary NPC table, the
  same special case already handled for Hauksness map `0x03`.
- SOURCE READY FOR RELOAD: `objects.lua` now adds Charlock map `0x02` to
  `MAPS_WITHOUT_NPCS`. The focused regression first failed with two stale NPC
  blockers in the compact fixture, then the full object suite passed `110/110`;
  Lua syntax and `git diff --check` are clean. Reload `main.lua`, fresh-check
  `npc_count=0`, then compare the loaded normal planner to `(10,1)`.
- LOADED FIX VERIFIED: after reload at entrance `(10,19)`, the fresh blocker
  report showed `npc_count=0` and no runtime blocks. Normal live-NPC planning
  now found the same 60-step route to hidden stair `(10,1)` as skip-NPC mode.
  Ordinary autowalk moved cleanly through `(10,18)`, `(10,17)`, `(10,16)`,
  `(9,16)`, and `(8,16)` before a Wizard battle interrupted the next west
  step. The interruption restored the harmless empty NPC-parking snapshot and
  left no runtime blocker.
- FULL LOADED ROUTE VERIFIED: after two player-cleared Wizard interruptions,
  ordinary autowalk resumed from `(8,16)` and `(6,4)` and completed at hidden
  stair `(10,1)`. Every segment used the normal live-NPC planner; the final
  state had `npc_count=0`, no runtime blocks, and no active path.
- VISIBLE STAIR POCKETS / EARLIER HYPOTHESIS DISPROVEN: ground-floor type-7
  stair cells `(4,14)` and `(15,14)` are separated from the central route by
  locked side-room doors, not unreachable walking components. West door
  `(4,8)` was live-opened from `(4,7)` facing down: keys changed `6 -> 5`, door
  RAM slot 0 became `(4,8)`, and a same-origin raw hold crossed normally after
  OPEN. The west room route reached `(4,13)`; STAIRS there correctly said no
  stairs, while a clean DOWN raw hold entered the real type-7 stair cell
  `(4,14)`. Add the two doors and stair passthroughs only after the paired east
  doorway/stair check. Expected west transition remains B1 `(8,13)`.
- WEST DECOY POCKET LIVE-PROVEN: STAIRS at ground `(4,14)` entered B1
  `(8,13)`. Loaded skip-NPC planning found no route from this arrival component
  to B1 stairs `(2,4)`, `(2,14)`, `(13,7)`, `(17,15)`, or `(8,19)`; frontier
  analysis reported 28 reachable cells with no bridge or hidden-bridge
  candidate. A normal-movement frontier crawl covered 38 directed edges before
  a Werewolf interruption and found zero passthroughs, directional candidates,
  door frontiers, or transitions. It flagged `(8,8)` as a stationary-occupant
  cell even though the fresh post-battle baseline had `npc_count=0`; keep that
  occupant result diagnostic-only. Ordinary routing then returned to `(8,13)`.
  This west branch is an intentional dead-end pocket whose only transition is
  back to ground `(4,14)`.

## 2026-08-06 Charlock Upper-Floor Loaded Component Audit

- CLEAN B3 MAIN ROUTE: from natural B2 arrival B3 `(7,0)`, loaded planning
  found the false stair `(0,9)`, branch stair `(5,4)`, and true descent `(1,6)`
  reachable. Ordinary autowalk reached `(1,6)` directly, proving the B2/B3
  false-return loop is optional rather than part of the required spine.
- CLEAN B4 COMPONENT: loaded planning from B4 arrival `(0,9)` found main
  descent `(2,2)`, false-inner stair `(8,1)`, and sword-return stair `(7,7)`
  in the same walking component. The route to `(2,2)` completed through combat
  interruptions. An initial `(5,7)->DOWN` retry was timing-only; after combat,
  a same-origin probe moved cleanly to `(5,8)`.
- CLEAN B5 SPLIT: from main arrival `(9,0)`, only main descent `(0,0)` is
  reachable. False-inner arrival `(4,0)` and its descent `(5,5)` form a separate
  component. The loaded perimeter route completed to `(0,0)` through several
  player-cleared battles.
- CONTAMINATED / DO NOT PROMOTE: B5 `(9,1)->DOWN` initially blocked and was
  provisionally injected as a runtime edge. A known-open opposite-direction
  probe also blocked, proving a global control lock. The provisional edge was
  cleared; after Start recovery, ordinary movement crossed the seam normally.
- CLEAN B6 SPLIT: from main arrival `(0,6)`, final descent `(9,6)` is reachable,
  while false-loop endpoints `(0,0)` and `(9,0)` are not. The loaded route
  completed across row 6 with no runtime blockers.
- FINAL BASELINE: STAIRS at B6 `(9,6)` entered Dragonlord's Lair map `0x06` at
  `(10,29)`. Fresh reports show `RUNTIME_BLOCKS map=0x06 none`, no active path,
  and only the expected Dragonlord NPC blocker at `(16,24)`.
- RETURN TRAVEL OBJECT FIX: object navigation had seven lair objects but no
  Travel entry because `objects.lua` omitted the lair-side stair. Manual STAIRS
  at `(10,29)` returned cleanly to B6 `(9,6)`. Source now exposes map `0x06`
  `(10,29)` as `South Stairs Up`; the focused regression failed before source,
  then all 110 object tests, Lua syntax, and `git diff --check` passed. After
  reload and re-entry, Travel reported `South Stairs Up: here (1 of 1)` at
  `(10,29)`, completing live verification.
- TREASURE DOOR CONFIRMED / SOURCE READY FOR RELOAD: the Doors filter falsely
  reported raw type-5 return stair `(10,29)` as a door. The staged guide instead
  pinned `(17,12)`, where live inspection found raw type 11 with walkable
  type-6 stands `(18,12)` and `(16,12)`. A clean 25-step natural route reached
  east stand `(18,12)` from lair entry, and a same-origin LEFT probe proved the
  closed cell without NPC, runtime, permanent, or directional contamination.
  OPEN from `(18,12)` facing west consumed one key (`6 -> 5`) and wrote opened-
  door RAM slot 0 `(17,12)`. `objects.lua` now disables the unsafe generic
  dungeon type-5 scan and exposes only confirmed `Treasure Room Door` `(17,12)`
  with both interaction stands. `map_reader.lua` now gates `(17,12)` on opened-
  door RAM so the planner can cross it after OPEN. The object regression failed
  on false `door_10_29` before its fix, and the map regression failed with
  `reason=tile_type` before its fix; all `111/111` object and `80/80` map-reader
  tests, Lua syntax, and `git diff --check` now pass. Current live checkpoint is
  `(18,12)` with the door already open; reload `main.lua`, then inspect or route
  through `(17,12)` to verify `reason=door_open` in the loaded runtime.
- TREASURE ROOM LOADED / ALL CHESTS REACHED: after reload, `(17,12)` reported
  `reason=door_open`; normal movement crossed from `(18,12)` through the door
  to `(16,12)`. The six chest results are `(11,11)` Herb, `(11,12)` 680 gold,
  `(12,12)` Magic Key, `(11,13)` Wings, `(12,13)` Cursed Belt, and `(13,13)`
  Herb. The Cursed Belt was given up because inventory was full.
- FULL-HERB CHEST QUIRK / FIX LIVE-VERIFIED: TAKE at `(13,13)` while Herbs were
  `6` produced `Unfortunately, it is empty.` The chest was consumed and the
  reward lost; after using an Herb, the retry produced `There is nothing to
  take here` while Herbs remained `5`. Inventory-only chest tracking therefore
  left the object falsely unopened. A focused regression failed before adding
  definitive empty-dialogue tracking and passed afterward (`112/112` object
  tests). After reload, the retry logged
  `CHEST_OPENED_DIALOGUE map=0x06 chest_id=chest_16 x=13 y=13`; a fresh probe
  reported `Chest (opened): here` at `(13,13)`.
- TREASURE RETURN ROUTE COMPLETE: ordinary autowalk crossed east through the
  open door from the chest room to `(18,12)`, then followed the modeled
  25-step outer route back to `South Stairs Up` `(10,29)`. Armored Knight
  interruptions at `(13,12)` and `(15,16)`, plus a Red Dragon at `(11,17)`,
  were combat-only. After each fresh resume, runtime blockers remained empty;
  final state at `(10,29)` had `target=nil` and `runtime_count=0`.
- CHARLOCK B1 BATTLE DIALOGUE CORRUPTION: a Starwyvern encounter at B1
  `(9,1)` alternated the complete STOPSPELL sentence with the truncated token
  `STOPSP ` five times at seven-frame intervals (`1729478..1729506`). A live
  `report_upper_dialogue_state` later showed the visible lower window as
  `The Starwyvern is breathing fire. Thy Hit Points decreased by 12. Command?`
  while `PREV.announced_dialogue` still began with the shifted fragment
  `Points have been reduced by 28.` Treat this as the existing overlapping
  battle-window/dialogue-cache defect, not route or passability evidence.

## 2026-08-07 Charlock B1 Alternate-Branch Crawl

- CLEAN EASTERN COMPONENT ROUTE: ordinary source-only movement connected the
  east-pocket B1 arrival area through `(17,17)` to the northern/southern
  corridor near `(2,14)`. Repeated route segments completed with no runtime
  blocker; battles were the only interruptions.
- CRAWL NPC CONTAMINATION / SOURCE READY FOR RELOAD: B1 terrain offset `0x20`
  retained 20 stale town NPC RAM slots. Run 4 therefore misclassified stale
  slot 6 at wall `(18,18)` as a stationary NPC and parked another stale mobile
  slot. `map_crawler.lua` now mirrors object navigation's terrain gate: dungeon
  and cave contexts neither park nor classify stale NPC RAM, while town/castle
  terrain keeps normal NPC handling. The focused regression failed before the
  fix and now passes with the full crawler suite (`52/52`); Lua syntax and
  `git diff --check` are clean. Reload `main.lua`, then restart the crawl from
  B1 `(19,16)` and verify `parked_slots=0` plus no stationary NPC at `(18,18)`.
- LOADED CRAWLER NPC FIX VERIFIED: after reload, the B1 crawl reported
  `parked_slots=0`. A 50-edge run reached stale-slot coordinate `(18,18)`,
  tested it twice as the modeled type-0 wall, and ended with
  `stationary_npc_cells=0`, zero passability/directional/transition candidates,
  and zero restored NPC slots. The stale dungeon NPC RAM no longer affects
  crawler geometry or parking.
- EASTERN COMPONENT CLOSED: targeted skip-NPC topology checks from B1
  `(18,15)` found the main return `(9,0)`, main descent `(8,19)`, and sword
  branch `(13,7)` unreachable. Each check reported `bridge_candidates=0` and
  `hidden_bridge_candidates=0`, confirming this is a deliberate isolated
  decoy component rather than an unfinished passage.
- EAST DECOY RETURN LIVE-PROVEN: STAIRS at B1 `(17,15)` returned to Charlock
  ground `(15,14)`. Together with the earlier west return and sword-room
  round trip, six omitted Travel objects are now proven in both directions:
  ground `(4,14)` / B1 `(8,13)`, ground `(15,14)` / B1 `(17,15)`, and B1
  `(13,7)` / B2 `(4,4)`.
- STAIR OBJECTS READY FOR RELOAD: `objects.lua` now exposes those six stairs
  with compass-based, destination-neutral spoken labels. The focused object
  regression failed on the first missing stair before the source change, then
  all `112/112` object tests, Lua syntax, and `git diff --check` passed. Current
  live checkpoint is Charlock ground `(15,14)`; reload `main.lua`, then verify
  Travel reports `East Stairs Down: here`.
- LOADED EAST STAIR VERIFIED: fresh reload tag `CHARLOCK_STAIR_NAME` confirmed
  the Lua loop at Charlock ground `(15,14)` with no runtime blockers. Exact
  lookup by both `stair_15_14` and spoken name `East Stairs Down` resolved one
  loaded object. The survey safety guard refused to start because the stair
  pocket has only one open walking exit; no movement or blocker change occurred.
- LOADED B1 STAIR OBJECTS VERIFIED: re-entering the east decoy placed the hero
  at B1 `(17,15)` with no runtime blockers. Exact loaded lookups resolved one
  object each for `East Stairs Up`, `West Stairs Up`, and
  `Northeast Stairs Down`. The survey safety guard refused each attempt from
  the two-exit arrival cell, so the hero remained at `(17,15)`.
- REMAINING SWORD CONNECTORS READY FOR RELOAD: audit of the completed forward
  and reverse sword-route evidence found three more omitted Travel entries:
  B1 `(15,1)` / B2 `(8,0)`, plus B2 `(9,1)` returning toward B3 `(2,2)`.
  `objects.lua` now labels them `North Stairs Down`, `Northeast Stairs Up`,
  and `Northeast Stairs Down`. The focused regression failed on B1 `(15,1)`
  before implementation; afterward all `112/112` object tests, Lua syntax, and
  `git diff --check` passed. FCEUX needs another manual `main.lua` reload.
- LOADED B1 SWORD CONNECTOR VERIFIED: fresh tag
  `CHARLOCK_SWORD_CONNECTOR_RELOAD` confirmed B1 `(17,15)` with no runtime
  blockers. Exact lookup of `North Stairs Down` resolved one loaded object for
  the newly exposed B1 `(15,1)` connector. The two-exit safety guard prevented
  survey movement, leaving the hero at the east decoy return stair.
- CHARLOCK SIDE-DOOR MODEL GAP / READY FOR RELOAD: after returning to ground
  `(15,14)`, door RAM still held west `(4,8)` and east `(15,8)` with four keys
  remaining, but source-only planning could reach the inside stand `(15,9)`
  and not the public stand `(15,7)`. Inspection identified the open east door
  cell as raw type 11 with `walkable=false reason=tile_type`. The permanent
  door model and Doors navigation had omitted both live-opened coordinates.
  `map_reader.lua` now gates `(4,8)` and `(15,8)` on opened-door RAM;
  `objects.lua` exposes `West Side Room Door` and `East Side Room Door` with
  public and room-side interaction stands. Both regressions failed before the
  source fix. Afterward all `81/81` map-reader and `113/113` object tests, Lua
  syntax, and `git diff --check` passed. Reload `main.lua`, inspect `(15,8)`
  for `reason=door_open`, then route from `(15,14)` to `(15,7)`.
- LOADED SIDE-DOOR FIX VERIFIED: fresh tag `CHARLOCK_SIDE_DOOR_LOADED` found
  both door RAM slots intact and no runtime blockers. East door `(15,8)` now
  reports `walkable=true reason=door_open`; the source planner found a
  nine-step path from stair `(15,14)` to public stand `(15,7)`. Ordinary
  autowalk crossed the door south-to-north, completed at `(15,7)`, and left
  `target=nil` with zero runtime blockers. The subsequent route toward hidden
  main stair `(10,1)` was interrupted by a Wizard battle at `(18,14)`; no
  route seam or blocker was promoted.
- CHARLOCK GROUND `(1,5)->UP` CONTROL-LOCK CONTAMINATION / DO NOT PROMOTE:
  autowalk plus two seam retries and an initial same-origin raw probe remained
  at `(1,5)`, but the user then reported controls locked. A provisional failing
  regression was removed without changing source. After Start recovery, a
  fresh same-origin 60-frame UP probe moved through `(1,4)` and settled at
  `(1,3)`, proving the cell passable and the earlier failures contaminated.
- CHARLOCK B1 `(7,19)->RIGHT` CONTROL-LOCK CONTAMINATION / DO NOT PROMOTE:
  the final autowalk step and both bounded seam retries remained at `(7,19)`
  and logged `(8,19)` as `blocked_only`. The user then confirmed the controller
  was locked and restored it with Start. A fresh same-origin 60-frame RIGHT
  probe moved normally to main descent `(8,19)`, proving the earlier apparent
  block was input contamination. No runtime or permanent blocker was added.
- REMAINING B1/B2 CONNECTORS LIVE-PROVEN / LOADED VERIFIED: ordinary
  B1 movement from east-decoy arrival `(17,15)` reached all four omitted
  stairs. B1 `(14,9)` entered B2 `(8,9)`; the adjacent B2 stair `(9,8)`
  returned to B1 `(19,7)`. B1 `(2,14)` entered B2 `(0,1)`; a direct north
  step moved normally onto boundary stair `(0,0)`, which returned to B1
  `(2,4)`. Battles interrupted long B1 routes, but every resume began from a
  clean baseline and no runtime blocker was promoted. `objects.lua` now
  exposes all eight endpoints. `map_reader.lua` adds only live-proven boundary
  stair cells `(0,0)` and `(0,1)`; the earlier guide hypothesis requiring
  `(1,0)` was unnecessary and was not added. Regressions failed first on the
  missing object and `(0,0)` boundary rejection, then passed `113/113` object
  tests, `81/81` map-reader tests, Lua syntax, and `git diff --check`. After
  restart/reload, exact non-moving lookups resolved all four new B1 and
  all four new B2 Travel names with `targets=1`. STAIRS at B1 `(2,4)` entered
  B2 `(0,0)`, and loaded inspection reported `reason=passthrough` for both
  `(0,0)` and `(0,1)`. The final baseline remained at `(0,0)` with no runtime
  or NPC blockers, no active path, and a clean input guard.

## 2026-08-09 Battle Spell-Name Filtering

- LIVE BUG CONFIRMED: during a Wizard battle on B1 `(0,1)`, narration twice
  produced `Wizard chants the spell of But that spell hath been blocked.` A
  fresh `report_upper_dialogue_state` showed the raw PPU row `HURTMORE.` between
  `chants the spell of` and `But that spell hath`, while the filtered lower
  dialogue omitted only that row. The original game displays the spell name;
  this is an accessibility filter bug, not intentional concealment.
- LOADED FIX VERIFIED: `text.lua` now preserves a standalone all-caps row
  only when the preceding accepted dialogue ends with `chants the spell of`.
  The focused regression failed with the exact missing-name sentence before
  the fix, then all `74/74` text tests passed. After manual reload, a fresh
  Starwyvern battle logged `Starwyvern chants the spell of HEALMORE.` at frame
  `1129`, followed by `The Starwyvern hath recovered.` at frame `1221`. The
  complete spell name reached the loaded speech path without repetition or
  status-row contamination.

## 2026-08-09 Dragonlord YES Ending

- ALTERNATE ENDING ACCESSIBILITY VERIFIED: TALK at Dragonlord approach `(17,24)`
  and YES produced the complete offer/acceptance sequence. Every page reached
  the dialogue event log. The terminal screen's filtered, previous, and
  announced lower-dialogue caches all matched the same 96-character text,
  ending with `Thy journey is over. Take now a long, long rest. Hahahaha....`
- TERMINAL STATE CONFIRMED: the game remains in field state on map `0x06` at
  `(17,24)` but holds the raw menu state and refuses movement. Gold, experience,
  keys, herbs, inventory/progress bytes, and quest flags were zeroed. This is
  intentional original-game behavior and requires restoring the pre-dialogue
  save state or resetting; it is not an accessibility input lock.

## 2026-08-09 Dragonlord Victory Speech

- LIVE BUG CONFIRMED: immediately after defeating the Dragonlord at lair
  `(17,24)`, the screen displayed `Points have been reduced by 17. Thou hast
  done well in defeating the Dragonlord.`, but JAWS announced nothing. A fresh
  snapshot found the exact 80-character line in the filtered, previous, and
  announced dialogue caches; speech backend status was bridge/ready/available.
- DELIVERY EVIDENCE: `speech_bridge.log` recorded
  `speak:Thou hast done well in defeating the Dragonlord.` at `10:38:27`.
  Therefore detection and bridge delivery succeeded, but the terminal message
  used ordinary queued speech after a speech-heavy fight and was not heard.
- SOURCE FIX READY: `battle.is_terminal_victory_dialogue()` recognizes only
  the Dragonlord terminal victory. Both stable lower-dialogue paths pass
  interrupt priority for that message, while ordinary battle victories retain
  queue behavior. The regression failed on the absent helper before the fix;
  afterward battle tests pass `44/44`, text tests pass `74/74`, and all touched
  Lua files byte-compile.
- LOADED FIX VERIFIED: after manual script reload on the completed victory
  page, frame `132` logged the Dragonlord line and `speech_bridge.log` recorded
  it as `interrupt:Thou hast done well in defeating the Dragonlord.` JAWS read
  it successfully, then read `Thou hast found the Ball of Light.` and both
  radiance/restoration pages. Frame `1314` changed to World Map `0x01`. Fresh
  tag `DRAGONLORD_VICTORY_RETURN` at frame `10440` confirmed World Map
  `(48,48)`, HP `149/149`, MP `121/121`, field state, empty dialogue, no menu or
  input guard, and speech bridge ready/available with no error. Final-victory
  speech and the postgame return transition are closed end to end.

## 2026-08-09 Full-Game Ending

- COMPLETE RUN VERIFIED: the hero returned to Tantegel, finished King Lorik's
  ending sequence, and reached the original `The End` screen. Dialogue events
  covered the full story sequence through `And thus the tale comes to an
  end.... unless the dragons return again.` `speech_bridge.log` then recorded
  the congratulations page and every staff-credit page through the copyright
  line; the user confirmed that the credits were automatically read.
- TERMINAL STATE CONFIRMED: fresh tag `GAME_END_TERMINAL` at frame `50580`
  reported state `title`, level byte `255`, map `0x04`, stale final coordinates
  `(10,8)`, no active menu/dialogue or mod suppression/teleport guard, and a
  healthy JAWS bridge. The log observed an A-button state during the terminal
  sequence without leaving `The End`, distinguishing the intended ROM ending
  loop from the mod's recoverable control-lock cases.
- MINOR FOLLOW-UP: the generic state transition spoke `Title screen.` before
  the credits, then the upper-text reader spoke two decorative-glyph fragments
  (`ghi jklm nopq rstu vwxy` and punctuation) after the real copyright line.
  Preserve the successful credits narration while filtering those artifacts
  and announcing `The End.` once in a future endgame-polish pass.

## 2026-08-15 Connected Cantlin Itinerary

- OLD BEHAVIOR REPRODUCED: selecting Cantlin from World Map `(43,43)` chose
  `cantlin_hauksness` directly and synthesized a 62-step shortcut to waypoint
  41. The plain `cantlin` alias did not resolve, and route state could retain
  only one staged continuation.
- SOURCE FIX: Cantlin routes now use a 14-tile staging threshold. Far starts
  compose `kol -> hauksness -> cantlin_hauksness` through a bounded ordered
  continuation list; Hauksness `(25,89)` and Great Swamp `(89,112)` starts stay
  direct. Intermediate speech names both the current leg and Cantlin, and
  handoffs never inject movement.
- REGRESSION COVERAGE: Travel-object and plain-alias starts, both waypoint
  handoffs, both town-entry handoffs, guidance refresh, object binding, local
  route selection, and cancel cleanup pass. Focused route tests are `184/184`.
  The native Windows `python run_tests.py` gate passes all 33 host-runnable Lua
  suites plus 68 Python tests; the WSL-only broad run is not authoritative for
  Windows package tests because it passes Linux paths to PowerShell.
- LIVE VERIFIED: from a clean World Map `(43,43)` baseline, the loaded route
  entered Kol and emitted `kol -> hauksness`, then entered Hauksness and emitted
  `hauksness -> cantlin_hauksness`. After each manual town exit, blocker-aware
  continuous walking resumed without a blocker, cancellation, or exhausted
  retry. The final leg entered Cantlin at `(15,0)`; fresh tag
  `CANTLIN_CONNECTED_ARRIVAL_20260815` reported route none, path target nil,
  and zero runtime blockers. Known early-route town entry remains separate
  polish.

## 2026-08-15 Connected Mountain Cave Itinerary

- OLD BEHAVIOR REPRODUCED: selecting Mountain Cave from Kol `(104,10)` or
  Tantegel `(43,43)` started the six-waypoint local spur directly and could
  synthesize a huge shortcut toward `(18,64)`.
- SOURCE FIX: `mountain_cave_connector` is derived at load time from the
  validated Hauksness route prefix from Kol through `Western desert east road`
  `(18,64)`. Mountain Cave stages through that connector when off its local
  corridor; the connector itself stages through Kol when needed. This yields
  `kol -> mountain_cave_connector -> mountain_cave` from Tantegel without a
  second manually maintained waypoint list.
- REGRESSION COVERAGE: Kol and Tantegel starts, both handoffs, final-object
  binding, guidance refresh, cancellation, direct local starts, exact prefix
  identity, and protection against mutating the Hauksness midpoint all pass.
  Focused route tests are `189/189`; the native Windows `python run_tests.py`
  gate passes all 33 host-runnable Lua suites plus 68 Python tests. Lua syntax
  and `git diff --check` pass.
- LIVE VERIFIED FROM KOL: fresh tag `MCAVE_CONNECTOR_BASELINE_20260815`
  confirmed World Map `(104,10)`, route/path nil, and zero NPC/runtime blockers.
  Starting Mountain Cave selected `mountain_cave_connector` with
  `staged_from=mountain_cave`. Blocker-aware continuous walking traversed the
  shared corridor, handed off at `(18,64)`, continued through the local spur,
  and entered Mountain Cave map `0x16` at `(0,7)`. Ordinary guarded
  twitch/repress retries all moved on their first retry; there was no failed
  edge, cancellation, or runtime-block injection. Fresh arrival tag
  `MCAVE_CONNECTED_ARRIVAL_20260815` reported route none, path target nil, and
  zero NPC/runtime blockers.
- MANUAL ACCEPTANCE VERIFIED: the user's independent pass also entered Mountain
  Cave map `0x16` at `(0,7)`. Fresh tag `MCAVE_MANUAL_ACCEPTANCE_20260815`
  confirmed route none, path target nil, and zero NPC/runtime blockers. The only
  later input diagnostic was the known benign FCEUX `LeftAlt` latch; no route or
  map patch is warranted.
- FULL TANTEGEL ACCEPTANCE VERIFIED: the user's manual run from `(43,43)` began
  `kol` with `staged_from=mountain_cave`, entered and exited Brecconary, entered
  Kol and emitted `kol -> mountain_cave_connector`, then emitted
  `mountain_cave_connector -> mountain_cave` at `(18,64)` and entered Mountain
  Cave map `0x16` at `(0,7)`. One timeout retry at `(43,43) -> UP` recovered;
  the interval contained no blocker, cancellation, or exhausted retry. The hero
  was repositioned afterward, so fresh tag
  `MCAVE_TANTEGEL_ACCEPTANCE_AUDIT_20260815` confirmed the current World Map
  `(43,43)` state clean rather than re-probing the earlier cave arrival: route
  none, path target nil, and zero NPC/runtime blockers. This slice is accepted.
  Brecconary/Kol entry remains separate early-route polish.

## 2026-08-15 Kol and Hauksness Town-Entry Polish

- ROOT CAUSE: the direct `kol` route explicitly targeted Brecconary entrance
  `(48,41)`, and every far connected destination staged through the same route
  all the way to Kol entrance `(104,10)`. Therefore Brecconary and Kol map
  transitions interrupted otherwise valid connected itineraries.
- RED REGRESSIONS: the focused route suite passed its prior 189 tests and failed
  only the two new requirements: Kol still used x48 instead of x47, and far
  Hauksness still activated `kol` instead of a non-entry staging leg.
- SOURCE FIX: direct Kol travel now targets live-proven Brecconary west doorstep
  `(47,41)` and turns north to Bridge south bend `(44,38)`. Hidden
  `kol_staging` copies that corrected route but moves only its final waypoint
  to Kol west doorstep `(103,10)`. Northern Cave, Swamp Cave, Hauksness/Cantlin,
  and Mountain Cave staging use the hidden route. Direct Kol travel preserves
  final entrance `(104,10)`, while `destination_maps={0x07}` keeps accidental
  Kol entry as a fallback itinerary handoff.
- STATIC VERIFICATION: focused overworld-route tests pass `191/191`; WSL `luac
  -p` passes for source and test; native Windows `python run_tests.py` passes all
  33 host-runnable Lua suites plus 68 Python tests; `git diff --check` passes.
- NEXT LIVE CHECK: current loaded FCEUX remains on the pre-change source at World
  Map `(43,43)`. Reload `main.lua`, select Hauksness, and confirm the route
  reaches `(47,41)` then turns north without entering Brecconary, later reaches
  `(103,10)`, emits `kol_staging -> hauksness`, and continues west without
  entering Kol. Use a fresh baseline and blocker report after reload.

## 2026-09-03 Off-Network Transition-Pocket Audit

- Fresh `audit_overworld_recovery:charlock_castle` reported nine unreachable
  cells: Swamp Cave north `(105,43)`, `(105,44)` and the seven-cell Rimuldar
  entrance ring `(101..103,71)`, `(101,72)`, `(101..103,73)`.
- Live `inspect_tile` and `inspect_move` evidence showed valid exits through
  Swamp Cave's poison re-entry stand `(104,43)` and Rimuldar's grass east
  doorstep `(103,72)`. The former pocket should be `hazard_required`; the
  latter should be decoded-safe recovery. Neither exit is an automatic map
  transition.
- Root cause: internal staging routes set `final=true` on these ordinary
  exterior endpoints, and `network_transition_lookup()` classified every
  final waypoint as a transition. Added `recovery_network_endpoint=true` to
  both endpoint families and excluded marked finals from the transition set.
- STATIC VERIFIED: all 340 focused overworld-route tests pass; actual entrances
  `(104,44)` and `(102,72)` remain transitions; both staging endpoints are
  network cells. Native `python run_tests.py` passes 33 host-runnable Lua
  suites and 68 Python tests; `git diff --check` passes.
- LIVE VERIFIED: after manually reloading `main.lua`, fresh frame `4260`
  reported `unreachable=0`, `safe_within_limit=7178` (up seven),
  `hazard_required=278` (up two), `network=977` (up two), and
  `transition=21` (down two). `safe_over_limit=416` and
  `nonwalkable=5530` were unchanged. Fresh frame `7500` confirmed World Map
  `(23,98)`, nil path target, and zero NPC/runtime blockers after the read-only
  audit. All nine false pockets are closed without changing terrain data.


## 2026-09-10 Brecconary Tool Merchant public route

- Baseline frame14580: normal entrance (0,15), map08, keys6, all door slots
  closed, no runtime blockers, no menu/dialogue/movement guard. Tool Merchant
  npc_18 stands at (25,25), public TALK stand (23,25) facing east.
- Cycle 1: skip-NPC plan to (23,25) failed (449 visited, frame16800).
  Local reference project_resources/maps/brecconary/mikesrpgcenter_brecconary.png
  shows bridge (18,22), grass east to the shop doorway at (22,23).
  Ordinary auto-walk reached bridge (18,22), frame19891.
- Cycle 2: raw probes from normal arrivals proved false modeled walls:
  frame21877 (18,22)->RIGHT crossed (19,22), settled (20,22);
  frame29191 (20,22)->LEFT crossed (19,22), settled (18,22);
  frame29912 repeated east crossing to (20,22);
  frame30745 (20,22)->RIGHT crossed (21,22), settled (22,22);
  frame31418 (22,22)->DOWN crossed (22,23), settled (22,24).
  No teleport/reset-backed passability evidence was used. Grass cells
  (19..22,22) are raw type0 and currently rejected by the shared tile model.
- Cycle 3: ordinary auto-walk reached (23,25), facing east, frame34411.
  TALK opened MERCHANT_ACTION: Merchant. Buy. at frame37806. B cancelled;
  goodbye appeared frame38776; nothing was purchased. Public target is correct.
  Return auto-walk reached (22,24), frame40894; raw UP reached (22,23),
  frame41426; another UP crossed (22,22) and carried to (22,21), frame41853.
- Narrow source patch: four map08 passthroughs (19..22,22). New regression
  fails before this patch and passes afterward; all 83 map-reader tests pass.
  Counter (24,25).west stays blocked; no shared tile-type rule changed.
  Debug refresh frame46560 loaded the patch and found 5 steps from (22,21)
  to (18,22). Full route validation/audit comparison still pending.
- Broader candidate: the local visual map's grass appears as raw0 and building
  walls as raw4, while shared WALKABLE_TOWN treats those as blocked/open.
  Several old overrides may mask a shared classification issue. Investigate
  tileset/context and controls separately before any global reclassification.

- Automated gate after patch: 41 host Lua suites and 68 Python tests pass;
  .test_tmp/tool_merchant_gate.log. Gate tests truncate dw_debug.log, so earlier
  raw-probe evidence above is retained from tool output rather than that file.
- Normal-NPC acceptance (parking temporarily off; original INI backed up in
  .test_tmp/tool_merchant_original.ini): bridge-to-entrance finished (1,15),
  frame53518. Services selected npc_18 and planned 32 steps, frame55320:
  14 east, 7 south, 7 east, 3 south, 1 east. Arrived (23,25), frame56279,
  auto-faced east frame56298. Fresh frame56940: nil target, zero runtime blocks.
  TALK opened Merchant. Buy. again, frame57486; cancelled without purchase.

- Return exposed two missing wall approaches before recovering to (1,15),
  frame61996: (23,24)->UP into (23,23) failed queued retries and the extra
  seam retry, frames60123/60279; (22,24)->LEFT into (21,24) likewise failed,
  frames60662/60818. Both raw4 tiles were incorrectly open in these directions.
- Reached the merchant again normally, frame64259. Walked to each origin:
  frame65399 raw UP from (23,24) blocked at (23,23), NPC false, no runtime block;
  frame66059 raw LEFT from (22,24) blocked at (21,24), NPC false, no runtime block.
  Promoted only (23,23).south and (21,24).east, map08. Doorway remains open.
  Full pre-patch evidence saved in .test_tmp/tool_merchant_wall_proofs.log.

- Final verification after both wall patches: gate passes 41 Lua suites and
  68 Python tests (.test_tmp/tool_merchant_final_gate.log); map-reader suite84.
  Debug module refresh frame70740 loaded the corrected data. Normal return
  from (23,25) to (1,15), frames71640..72884: 32 steps, no blocked steps,
  no reroutes, two recovered timing retries. Fresh frame73620 confirms nil
  target, zero runtime blocks, all menu/dialogue/guard state clear.
- Updated audit frame73762, town_audit_08_20260910T163517Z_001: 20 modeled
  reachable, 1 NPC-obstructed (Person1 at24,28), 2 model-blocked (Person2 at3,1;
  Woman2 at12,28). Curse Remover return remains NPC-obstructed. Tool Merchant
  and Person5 at20,23 have outward/return plans; Person5 interaction untested.
  NPC positions differ from baseline, so counts are not a controlled comparison.
- Restored auto_walk_park_mobile_npcs=true; INI matches the saved pre-test bytes
  exactly. reload_config consumed frame75660. No purchase, key use, teleport,
  permanent player-state write, or global tile classification change.


## 2026-09-10 Woman 2 audit follow-up

- Verified local HEAD and live GitHub refs/heads/codex/town-audit both equal
  6deef9272d630ac18dd9068a9a91ce25c0c14cae; working tree initially clean.
  This includes the audit and player-accepted Tool Merchant fixes.
- Target: stationary Woman 2 npc_7 at (12,28). Audit snapshot163517Z marks
  every normal adjacent stand unavailable. Highest candidate is grass (13,28)
  south of reachable (13,27), raw0 modeled blocked. Local Brecconary reference
  supports a grass approach; this is orientation, not movement proof.
- Fresh frame960: map08, hero23,25, keys6, doors closed, runtime none.
  A player-started exit route and command-menu inputs overlapped this baseline;
  exclude those early route failures from permanent map evidence. Frame3480
  showed nil route and command menu open; closed with B, frame4140.
- Frame4920 clear-field planning: skip-NPC adjacent route to12,28 fails;
  route to13,27 exists (40steps from23,25). Started stop-on-first-blocker walk
  frame5580, using the current configured NPC-parking behavior.

- Cycle1 first failure: from9,18 DOWN into9,19, frame7055 stop-on-blocker
  (NPC false, timing_suspect false). Raw DOWN frame8819 also blocked with
  tile4/base walkable true/NPC false. Added runtime edge9,19.north only.
  Planner then proposes entering the same roof from its west, so do not
  chase wall detours. The reference has a grass connection from15,22 west
  across14,22 to the modeled tree column13,22..27. Check that normal approach.

- Cycle2 grass connection: raw LEFT15,22->14,22->13,22 passed frame13655;
  reverse RIGHT passed frame14906; repeat LEFT frame15145. Normal five-step
  walk reached13,27 frame15468; raw DOWN reached13,28 frame16233.
- Cycle3 TALK revealed the target was no longer there: raw LEFT8 entered12,28,
  then TALK reported no one. Same-session NPC records prove Woman2/slot7 moves
  while movement remains0: audit20062 at11,16; report22620 at9,11 rawC9,AB,00;
  report25260 at13,9 rawCD,A9,00. Byte2 is a pixel offset, not mobility.
  Disassembly confirms slots0..9 mobile,10..19 static. No label/code fix yet.
- Returned along the same grass/tree passage (UP25166 to13,26, normal walk to
  13,22, RIGHT27997 to15,22), then normally to1,15 frame37248. Runtime diagnostic
  blocker cleared; frame42240 clear field/runtime none. No config/source edits.
- Full findings and the source-backed correction plan are in
  work_notes/town_decoder_findings.md. Audit165251Z atframe42382 has22 reachable,
  one model-blocked, two return concerns; Woman2 at20,7 is reachable. Count
  improvement is NPC-layout variation, not a fix. Prioritize shared NPC mobility
  correction, then a Brecconary pilot of the base town tile table.


## 2026-09-19 Cantlin Central Right Door final-step timing seam

- Repeated routes to Central Right Door from the town exit failed only on the
  final step, `(16,24)->LEFT` into `(15,24)`. The same edge had already crossed
  successfully twice when it was the penultimate step of a route to Central
  Left Door.
- Fresh raw probes crossed both directions with no NPC or runtime blocker:
  LEFT from `(16,24)` reached `(15,24)` and carried to `(14,24)`; RIGHT from
  `(14,24)` reached `(15,24)` and settled at `(16,24)`. The terrain model also
  reports tile6/base-walkable. Do not add a permanent or directional block.
- Failure signature: movement starts at frame2 (`subpixel 0x04->0x00`), then
  `AUTO_STEP_GUARDED_TWITCH_REPRESS` releases the final-step twitch for 16
  neutral frames. The fresh press times out and the route reroutes. Successful
  penultimate crossings retain the twitch because another west step follows.
- CLEAN / PROMOTED: map0A destination `(15,24)` approached from the east now
  pre-arms the existing prime1/settle16 entry cadence. Regression coverage
  keeps the reverse side, neighbor, and other maps unchanged. Live frame54120
  queued the exact one-step route from `(16,24)`; frame54163 reached `(15,24)`
  with zero retries, and frame54182 faced Central Right Door south. No reroute
  or block was logged. All92 map-reader tests and the full41-Lua-suite/
  68-Python-test gate pass. This is a timing change only, not passability.
- PLAYER ACCEPTED — DOORS: all five door round trips passed. The retained
  post-gate log confirms Central Right, Eastern Building, Western Shop North,
  and Western Shop East outward/return routes with no reroutes; bounded timing
  retries recovered in place. Western Shop East became reachable as expected
  after Western Shop North was opened. Central Left's full-run evidence was
  overwritten by the gate, so its category acceptance also relies on the
  player's report plus the earlier successful agent approach. Frame87840:
  hero `(20,28)`, all five door slots open, nil route, runtime blocks none.


## 2026-09-19 Cantlin NPC route follow-up

- PERSON1 — TRANSIENT: the first route recorded one blocked-step reroute and
  immediately replanned one cell east. The second full approach, TALK, visited
  update, and release succeeded. Do not promote a blocker for a mobile target.
- WOMAN1 — TRANSIENT EDGE POSITION: no route existed while she occupied
  `(0,26)` and `(0,28)`. Once she moved to `(1,29)`, a 31-step approach,
  facing, TALK, and visited update succeeded. This is target-position
  availability, not NPC clutter or a stable bad edge; no source change.
- WOMAN2 — TIMING FIX: three return attempts failed identically on
  `(19,13)->RIGHT` into `(20,13)` after bounded retries. From the same origin,
  raw `probe_edge:RIGHT` moved to `(20,13)` at frame204083; the destination
  was tile6 and no NPC occupied it. Map0A `(20,13).west` now uses prime1 and
  settle16 only. The post-fix guided step logged the cadence at frames238020/
  238056, moved at238083, arrived at238099, and completed at238118 with no
  reroute. Passability and directional blocks are unchanged.
- OLD MAN4 — FIXED COUNTER STAND: `npc_18` remains stationary at `(22,22)`.
  TALK from west `(20,22)` across two tiles and from north `(22,20)` both
  reported no one. Normal movement to `(22,24)`, facing north across raw-F
  counter `(22,23)`, delivered the Erdrick's Sword clue. The object now uses
  that explicit dialogue-only stand; selected-object routing and visited
  tracking passed live at frames234804/235535.
- MERCHANT3 — FIXED COUNTER STAND: `npc_8` roams inside the sealed
  `x=2..4,y=25..27` room. Normal, skip-NPC, parked-NPC, and frontier searches
  found no public bridge. The object now routes to `(6,26)`, faces west across
  counter `(5,26)`, and temporarily holds the target at `(4,26)` on TALK.
  Live TALK delivered the Wynn/Hauksness clue and marked `npc_8` visited at
  frame231233.
- HOLD RESTORATION: the old explicit target-hold path wrote the trigger
  coordinates without restoring them, which displaced Merchant3 to `(2,23)`
  in this live session after release. `route_manager.lua` now snapshots all
  three NPC bytes plus map ID and restores them when the hold ends on the same
  map. It skips stale restoration after a map transition. A full `main.lua`
  reload is required because navigation hot reload does not reload the route
  manager; reload also resets the contaminated live NPC placement.
- STATIC GATE: `luac -p` passes the six changed source/test files;
  `git diff --check` passes. Focused suites pass 93 map-reader, 130 objects,
  and 165 route-manager tests. `python -u run_tests.py` passes 41
  host-runnable Lua suites, 68 Python tests, syntax checks, shell checks,
  bridge configuration, speech dependency, and command-queue checks.
- PLAYER ACCEPTED — NPC FIXES: after reload, Merchant3 reached `(6,26)` at
  frame3105, set visited and restored its original NPC coordinates at3474,
  then returned to `(20,28)` at4807. Old Man4 reached `(22,24)` at5985, set
  visited/restored at6281, and returned at7384. Woman2 reached its live
  approach at11933, set visited/restored at12054, and returned at13175.
- PLAYER ACCEPTED — ROAMING WEAPONS MERCHANT: after it moved into the public
  component at `(16,8)`, its 23-step approach completed at frame17531,
  TALK/visited plus coordinate restoration completed at17706, and the 23-step
  return reached `(20,28)` at19103. This confirms the earlier no-path state at
  `(22,4)` was position-dependent and the sealed compartment remains correct.
- The validation log contains no `PATH_RUNTIME_BLOCK`, blocked-step reroute,
  autowalk reroute, no-path, or route-failed record. Fresh read-only frame24960
  reports Cantlin `(20,28)` with `RUNTIME_BLOCKS map=0x0A none`. Cantlin NPC
  validation is complete.


## 2026-09-19 Tantegel Castle terrain check and initial audit

- CLEAN BASELINE: map0x04 at `(5,13)`, both real doors open in RAM at
  `(18,6)` and `(4,13)`, three keys, nil active route, and no runtime blocks.
  The read-only audit captured this state before terrain movement.
- AUDIT: `town_audit_04_20260919T200358Z_001` completed all29 targets from
  `(5,13)`:23 modeled reachable,4 NPC-obstructed,2 model-blocked, and5 return
  concerns. The two outward model failures are Magic Key Merchant `npc_10`
  and Sun Shrine Stairs `(29,29)`. Guard5 has the non-NPC return concern; the
  other four concern rows are the treasure-room chests obstructed by current
  NPC placement. Live arrival/interaction remains untested by audit design.
- TERRAIN TABLE — VERIFIED WRONG FOR MAP04: raw4 is currently treated as
  castle floor, but three normally reached entries blocked in the engine:
  `(5,6)->LEFT` into `(4,6)`, `(6,4)->UP` into `(6,3)`, and
  `(10,3)->LEFT` into `(9,3)`. Each destination is raw4, modeled walkable,
  and lacked the blocking approach needed to explain the live failure.
- The converse raw0 proof is clean. A normal route reached `(10,3)`; the
  current model described `(10,2)` as raw0/non-walkable with no NPC,
  permanent block, or directional approach block. Same-origin `probe_edge:UP`
  at frame85713 entered `(10,2)` and carried to `(10,1)`, logging
  `moved_through_modeled_block`. Tantegel therefore uses the same Bank00
  raw0-grass/raw4-stone collision meanings as the audited towns.
- AUDIT IMPACT: Magic Key Merchant's two bridge frontiers `(22,1)` and
  `(22,2)` are raw0, so its no-route result is direct terrain-table fallout.
  The Sun Shrine stair and Guard5 return need reassessment only after the
  table correction; their current frontier candidates include raw4 and old
  directional data. Treasure-room chests are NPC-clutter cases, not terrain
  evidence.
- CONTAMINATED EXPLORATORY ROUTE / DO NOT PROMOTE INDIVIDUALLY: the attempted
  route toward `(6,2)` rerouted around the raw4 failures and was manually
  stopped at `(8,4)`. Its temporary route blocks were cleared. No individual
  blocker was added because the shared raw-tile classification explains the
  failures more directly.
- FINAL PRE-FIX CHECKPOINT: frame89700 at `(10,1)`, both doors still open, nil
  route, and `RUNTIME_BLOCKS map=0x04 none`.
- PROMOTED / RELOAD PENDING: `map_reader.lua` now gives map0x04 the verified
  Bank00 town table (raw0 grass open, raw4 stone blocked) and the shared raw9
  poison-swamp/rawA damage-floor hazard handling. Existing door, passthrough,
  directional, boundary, and coordinate-hazard data still layer on top.
  `test_map_reader.lua` checks the full16-tile row, the live-proven raw0/raw4
  cells, both hazard kinds, and safe-hazard exclusion. All94 focused tests pass;
  `luac -p` and `git diff --check` are clean; `python -u run_tests.py` passes41
  host-runnable Lua suites and68 Python tests. No live post-fix claim yet.
- NEXT: reload `main.lua`, establish a fresh map0x04 baseline, then rerun
  `audit_town` before beginning live target validation.

## 2026-09-21 Tantegel post-reload audit

- Fresh command polling at frame12360: map0x04, hero `(5,13)`, doors `(18,6)`
  and `(4,13)` open, keys2, nil route, runtime blocks none. Repeated baseline
  at frame24720 still had the same hero/door/route/block state.
- Reloaded terrain inspection at frame13740: raw0 `(10,2)` now reports
  `base_walkable=true`, `reason=map_tile_type`; raw4 `(4,6)`, `(6,3)`, and
  `(9,3)` report `base_walkable=false`. Earlier normal-movement terrain proof
  remains in the preceding section. No new movement probe was required.
- Audit1 `town_audit_04_20260921T182014Z_001.txt`, frame14728: all29 targets;
  28 modeled reachable,0 NPC-obstructed,1 model-blocked,0 return concerns.
  Magic Key Merchant, Sun Shrine stairs, both doors, four chests, and Sage all
  have modeled outward routes. Only Guard5 `npc_9` at `(24,21)` is no-route
  with or without captured NPCs. No live arrival/interaction/return was tested.
- Audit2 `town_audit_04_20260921T182058Z_001.txt`, frame17368:27 reachable,
  0 NPC-obstructed,2 model-blocked,0 return concerns. Mobile Old Man1 moved to
  `(17,10)` and became the second no-route target; Guard5 stayed `(24,21)`.
- Audit3 `town_audit_04_20260921T182208Z_001.txt`, frame21568:16 reachable,
  12 NPC-obstructed,1 model-blocked,10 return concerns. Guard5 at `(24,20)`
  remained the sole model block; Old Man1 at `(16,11)` was routable again.
  This was a fresh captured-NPC snapshot, not route execution evidence. Do not
  promote its transient NPC obstructions to permanent terrain data.
- GUARD5 / UNRESOLVED SAFE ACCESS: `inspect_tile` reports Guard5's raw6 cell
  walkable except NPC occupancy, `(24,20)` and `(25,21)` raw6 open, `(24,22)`
  raw4 stone blocked, and `(23,21)` raw6 but known damage hazard. No safe
  modeled adjacent route from `(5,13)` in three audit snapshots. A read-only
  skip-NPC/allow-hazards route to `(25,21)` exists in48 steps but crosses three
  rawA damage cells `(25,18)`, `(26,18)`, `(26,19)`. Keep hazard protection;
  no map edit or movement performed. Investigate only if player needs Guard5.

## 2026-09-30 Ending narration investigation (complete)

- Fresh `ending_baseline` probe at frame 42960: map0x04 `(11,8)`, level21,
  lower dialogue `The legends have proven true.`, speech bridge ready, no error.
- Advanced ending pages individually with `simulate_input:A,12`; bridge log
  contains the king/hero/princess pages and final story line. Gwaelin YES selected.
- Reproduced premature `Title screen.` at 20:49:42, before congratulations
  and staff credits. Credits/final screen use level255; detector labels this title.
- Credits reached copyright at 20:51:27. Artwork decoded as
  `ghi jklm nopq rstu vwxy` at 20:51:34 and punctuation at 20:51:41.
  No `The End.` announcement. Terminal probe frame57120 consumed successfully.
- Added read-only `report_ending_screen` command to main.lua, syntax passed.
- CAPTURED after manual reload: frame4320, level255, terminal rows13/14,
  columns10..21 (zero-based) are ascending tiles3E..49 and4A..55; every other
  tile is5F. The artwork shares tile IDs with normal punctuation.
- IMPLEMENTED: ending.lua handles stable credits and terminal artwork, main.lua
  suppresses the title announcement only in the ending context. Added read-only
  report_ending_screen documentation and included ending.lua in package-layout.json.
- VERIFIED SOURCE: focused ending regression, Lua syntax, diff whitespace,
  full python -u run_tests.py:42 Lua suites and68 Python tests passed.
  Gate log: .tmp-tests/ending-gate-2026-09-30.log (ignored local evidence).
- PLAYER ACCEPTED: after the second manual reload, user heard The End.
  NVDA bridge log records one `speak:The End.` at20:58:46, with no Title screen
  or decorative fragments. Fresh ending_accepted probe consumed at frame2640.
- REPLAY: patched story/congratulations/full staff/copyright narration preserved;
  no premature Title screen. Final The End logged once at21:04:26. Replay found
  the earlier illustration still spoke `ghi jklm nopq rstu vwxy` at21:04:19.
- CORRECTED: the first artwork fixture incorrectly modeled one long row. ROM
  offset0x5912 writes separate runs to PPU$218F,$21AE,$21CE,$21EE,$220E,
  tiles10..12,13..16,17..1A,1B..1E,1F..22. Added exact row filters and corrected
  the regression fixture. Focused tests/syntax and full gate passed again:
  42 Lua suites,68 Python tests, speech dependency and queue checks.
- VERIFIED FINAL REPLAY: reloaded corrected source, story and all staff credits
  preserved. Copyright at21:10:22 followed by silence for illustration and
  The End once at21:10:35 (frame12171). No premature title or either artwork
  fragment. ending_clean_finish consumed at frame12660; level255, map0x04.
  Initial reload The End and subsequent replay The End are separate sessions.
  No ending verification remains pending. Unrelated edits preserved.
