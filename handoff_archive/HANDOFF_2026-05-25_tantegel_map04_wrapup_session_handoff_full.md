# Session Handoff - Active Resume

Updated: 2026-05-25

This file is intentionally short. It is the current resume point, not the
historical evidence archive. The previous long handoff was preserved at
`handoff_archive/HANDOFF_2026-05-22_pre_cleanup_session_handoff_full.md`.

## Current Direction

- Player-facing gameplay is currently FCEUX-first.
- BizHawk remains the preferred automation/debug/reload-heavy runtime.
- Keep both emulator paths supported. Do not remove the FCEUX player-facing
  path or BizHawk automation affordances unless explicitly asked.
- Current branch focus: finish the remaining Tantegel Castle cleanup around the
  Sage route and stair-area drift before moving on to the next normal gameplay
  pass.
- Avoid broad new map-decoding passes unless gameplay exposes a blocker.
- Latest shrine-route work shifted from "find the missing bridge" to
  "separate real geometry blockers from hazard-route behavior" on the final
  Sun Shrine approach.
- Codex is the primary implementation/debugging agent. Claude is now mainly a
  limited-bandwidth second-eyes reviewer, so do not rely on Claude memory as an
  active project-state source.

## Latest Route Resolution

- Fresh 2026-05-25 Magic Key Merchant-to-exit churn follow-up found two real
  row-16 entry blockers and one bridge-release bug.
  - Route evidence:
    - The route from Magic Key Merchant `(24,3)` to `Exit to World Map`
      `(11,29)` used `npc_mode=park_mobile_npcs`, parked 4 mobile NPC slots,
      and had no persistent runtime blockers after stop.
    - Clean post-restore verifiers confirmed `(16,15)->DOWN` into `(16,16)`
      and `(17,15)->DOWN` into `(17,16)` each blocked 5/5 with no drift,
      map change, or interruption.
  - Permanent model fix:
    - `MAP_DIRECTIONAL_BLOCKS[0x04]` now closes the north approaches into
      `(16,16)` and `(17,16)` while leaving both passthrough cells standable.
    - Pre-restore `18,13->DOWN` and mixed `25,9->LEFT` evidence was not
      promoted.
  - Tooling/input fix:
    - After the `17,15` verifier, Lua stayed alive and state remained `field`
      at `(17,15)`, but bridge inputs were seen without visible game reaction.
    - A live `clear_input` neutral pulse recovered input enough for a selected
      teleport to fire, supporting sticky scripted joypad state as the cause.
    - `debug_tools.lua` now emits one raw neutral joypad frame when the internal
      or external keyboard bridge transitions from active to clear, preventing
      sticky scripted button state after FCEUX focus/menu weirdness.
  - Validation:
    - `luac5.1 -p debug_tools.lua test_debug_tools.lua map_reader.lua test_map_reader.lua`
    - `lua5.1 test_debug_tools.lua` passed 8 tests
    - `lua5.1 test_map_reader.lua` passed 37 tests
    - `lua5.1 test_route_manager.lua` passed 90 tests
    - `git diff --check -- debug_tools.lua test_debug_tools.lua map_reader.lua test_map_reader.lua`
  - Next live step:
    - User reloaded and confirmed the Magic Key Merchant to entrance/exit
      route is noisy but working again.
    - Log/readback confirmed final `(11,29)`, `PATH_STATE target=nil`, and
      `RUNTIME_BLOCKS map=0x04 none`.
    - Remaining noise is route-local temp reroutes around cells such as
      `(23,9)`, `(24,9)`, `(18,14)`, `(18,15)`, `(24,10)`, `(25,6)`,
      `(17,6)`, and `(15,5)`. Do not promote those without clean post-reload
      verifier evidence.

- Fresh 2026-05-25 live validation confirmed the new shrine final-approach
  guard fixed the throne-stairs-to-shrine town-exit overrun.
  - Symptom:
    - One manual throne-room-to-shrine route reached `(29,29)` and then walked
      out to the World Map during final settle.
  - Cause:
    - The bad route drift-rerouted from `(29,3)` into a direct `26 south`
      descent on x=29. That route shape armed a delayed exit transition even
      though final movement RAM had already been reset.
  - Code fix:
    - `route_manager.lua` detects autowalk execution plans to map `0x04`
      goal `(29,29)` whose final suffix is a long high x=29 south descent.
    - It retries planning with a temporary planning-only directional block on
      the first risky x=29 south edge, leaving permanent map data unchanged.
    - New log marker: `AUTO_WALK_FINAL_APPROACH_AVOID`.
  - Validation:
    - After FCEUX Lua reload, the old `(29,3)` repro appeared and was reshaped:
      `AUTO_WALK_FINAL_APPROACH_AVOID ... context=route_drift_reroute ...
      blocked_dest=(29,4) ... old_path_len=26 new_path_len=28`.
    - The replacement route was `1 west, 4 south, 1 east, 22 south`.
    - Final state remained `map=0x04(Tantegel Castle) x=29 y=29`,
      `PATH_STATE target=nil`, and `RUNTIME_BLOCKS map=0x04 none`.
  - Watch item:
    - The northeast/top approach is still noisy with route-local timing temp
      blocks, but no runtime blockers persisted and no map-change event
      occurred after arrival.

- Fresh 2026-05-25 southeast-stairs detour follow-up reopened the upper
  row-6/row-7 connector after the first cleanup proved too aggressive.
  - Symptom:
    - A successful route to `Sun Shrine Stairs and Southeast Exit` was still
      noisy around the upper/east side, and a recovery bridge tap showed
      `(26,7)->UP` could move into `(26,6)` despite the new model block.
  - Corrected live verifier evidence:
    - `probe_edge_verify:25,5,DOWN,5`, `probe_edge_verify:26,5,DOWN,5`,
      `probe_edge_verify:25,7,UP,5`, `probe_edge_verify:26,7,UP,5`, and
      `probe_edge_verify:26,7,RIGHT,5` each moved 6/6 with stability recheck.
    - Earlier blocked-only evidence for `(25,6)`, `(26,6)`, and `(27,7).west`
      was state/timing contamination, not durable geometry.
    - The same follow-up cleared route-noise suspects `(13,9).west`,
      `(19,6).west`, and `(25,6).west` as passable 6/6.
  - Permanent model fix:
    - `MAP_DIRECTIONAL_BLOCKS[0x04]` no longer seals `(25,6)`, `(26,6)`, or
      `(27,7).west`.
    - `test_map_reader.lua` asserts those approaches stay open so noisy route
      observations do not re-promote them.
  - Validation:
    - `luac5.1 -p map_reader.lua test_map_reader.lua`
    - `lua5.1 test_map_reader.lua` passed 37 tests
    - `git diff --check -- map_reader.lua test_map_reader.lua`
    - `git diff --check -- session_handoff.md work_notes/current_investigation.md`
    - After `reload_navigation_modules` and `clear_runtime_blocks:0x04`,
      `debug_pathfind_to_allow_hazards:29,29` from `(26,6)` planned
      `3 east, 22 south` with zero hazards.
    - `auto_walk:29,29` then completed cleanly to `(29,29)` with no runtime
      blockers.
  - Current live note:
    - Final quiet check: `POSITION ... x=29 y=29`,
      `PATH_STATE target=nil map=0x04 runtime_count=0`,
      `RUNTIME_BLOCKS map=0x04 none`, and stale `LeftAlt` only.
      Do not run recovery on the southeast exit tile unless needed; the bridge
      recovery taps can move the hero.

- Fresh 2026-05-25 final Tantegel object-list cleanup:
  - Tantegel Throne Room King on map `0x05` now appears in the Services filter
    for save-game visits while keeping ordinary adjacent-NPC routing.
  - Tantegel Castle map `0x04` no longer exposes duplicate Travel objects for
    the shared southeast tile. The single object is now
    `Sun Shrine Stairs and Southeast Exit` at `(29,29)` with id
    `stair_29_29`.
  - Validation:
    - `luac5.1 -p objects.lua test_objects.lua`
    - `lua5.1 test_objects.lua` passed 68 tests

- Fresh 2026-05-25 FCEUX movement-control lock investigation points to the
  keyboard bridge sidecar, not map/pathfinding.
  - Symptom:
    - After live route testing, manual movement appeared locked.
  - Evidence:
    - Lua command polling was alive and no autowalk route was active:
      `PATH_STATE target=nil map=0x05 runtime_count=0`.
    - Player was in the throne room at `(8,8)`.
    - Input showed stale Alt only:
      `INPUT_STATUS tag=manual keys=LeftAlt joy1=- left_alt=true`.
    - `./recover_fceux_input.sh` cleared Alt to
      `keys=- joy1=- left_alt=false`.
    - Windows process inspection found no persistent `keyboard_bridge.ps1`
      sidecar even though FCEUX native keyboard gamepad input is disabled by
      the launcher.
  - Code/tooling fix:
    - `recover_fceux_input.ps1` now restarts `keyboard_bridge.ps1` if the
      sidecar is missing.
    - `input_status` now logs the bridge-file state as `bridge=...` after the
      next Lua reload.
  - Live validation:
    - patched recovery started `keyboard_bridge.ps1` PID `9060`.
    - a later live log showed manual input flowing through the restarted bridge:
      `INPUT_EXTERNAL_BRIDGE_APPLY ... native_joy1=up bridge=up`.
    - Existing loaded Lua still used the old `input_status` format, so reload
      Lua before expecting the new `bridge=` field in logs.

- Fresh 2026-05-25 manual route-validation log analysis fixed the transient
  Sage-to-throne-stairs no-path.
  - Symptom:
    - After reaching Sage at `(18,26)`, the first autowalk attempt to
      `Stairs Up to Tantegel Castle Throne Room` `(7,7)` failed to generate a
      route, then a second attempt shortly afterward succeeded.
  - Cause:
    - The completed Sage route left one parked NPC in deferred restore because
      the hero occupied that NPC's original tile.
    - A new autowalk started while `pending_restore` was still active, so fresh
      mobile NPC parking was skipped.
    - The failed route snapshot was therefore `npc_mode=park_mobile_npcs` but
      only `parked_slots=1` with `npc_blocks=17`, and it failed as
      `reason=goal_blocked_npc`.
  - Code fix:
    - `start_autowalk_npc_parking` now merges pending deferred-restore slots
      into a fresh parking state and still parks the rest of the mobile
      non-target NPCs before planning.
    - New log marker:
      `AUTO_WALK_NPC_PARK_START merged_pending_restore slots=N`.
  - Validation:
    - `luac5.1 -p route_manager.lua test_route_manager.lua`
    - `lua5.1 test_route_manager.lua` passed 81 tests
    - `git diff --check -- route_manager.lua test_route_manager.lua`

- Fresh 2026-05-25 Magic Key Merchant route regression was reopened without
  changing the south-gate wall blockers.
  - Symptom:
    - From `(14,29)`, routes to the Magic Key Merchant `(24,3)` and Magic Key
      Area Door `(18,6)` had collapsed to `No path found`, even with NPCs
      skipped and hazards allowed.
    - Runtime blocks were empty and both map `0x04` doors were open:
      `(4,13)` and `(18,6)`.
  - Cause:
    - The bottom-row component could not cross the decoded tile-0 south-gate
      exit cell `(11,29)`.
    - Live FCEUX movement proved `(11,29)` is standable, and pathfinding from
      live `(11,29)` immediately reconnected to the old Magic Key route via
      `(11,28)`.
  - Permanent model fix:
    - `MAP_PASSTHROUGH_CELLS[0x04]["11,29"] = true`.
    - Focused `test_map_reader.lua` coverage keeps `(11,29)` in the
      walkability snapshot.
  - Validation:
    - After `reload_navigation_modules`, `debug_pathfind_to_skip_npcs:24,3`
      from `(14,29)` found the restored route.
    - `debug_pathfind_adjacent_skip_npcs:18,6` also found the Magic Key Area
      Door route.
    - Live `auto_walk:24,3` from `(14,29)` completed at `(24,3)` with no
      runtime blocks.
  - Watch item:
    - The successful route still drift-recovered around `(11,29)/(10,29)` and
      `(10,22)`. Treat that as executor/settle noise unless it starts causing
      cancellations; it is not current blocker evidence.

- Fresh 2026-05-25 x=29 lane retest after script reload refined the remaining
  row-21 mystery without changing permanent map data.
  - New targeted helper evidence:
    - natural descent toward `(29,21)` with waits `0`, `5`, and `10` after
      reaching `(29,20)` still arms too early at `(29,20)` and drifts south
    - waits `15` and `20` arm cleanly at `(29,21)`, but `(29,21)->LEFT`
      blocks with `EDGE_PROBE_MODEL_MISMATCH kind=blocked_despite_open_preview`
  - Runtime-only check:
    - injecting `add_blocked_edge:29,21,LEFT` records `(28,21).east` and does
      not break the straight x=29 route; `debug_pathfind_to_allow_hazards:29,29`
      from `(29,21)` still reports `Path: 8 south`
  - Live validation:
    - `auto_walk:29,29` from `(29,21)` completed the x=29 descent and the
      final `(29,28)->DOWN` step transitioned to the World Map at `(43,43)`
  - Current interpretation:
    - the x=29 south lane to the Sun Shrine / southeast transition remains
      live and should stay planner-open
    - natural descent does not reproduce the earlier half-open `(29,21)->LEFT`
      family; keep `(29,21)->LEFT` / `(28,21).east` as stateful runtime-only
      evidence, not a permanent blocker
    - current live state after validation is World Map `(43,43)`; restore to
      Tanticle is needed before continuing castle-side probing

- Fresh 2026-05-24 east-pocket throat cleanup replaced another batch of
  planner-only shelf exits with verified geometry.
  - Permanent model fixes now in repo:
    - `(26,22).east = true`
    - `(26,22).south = true`
    - `(26,23).north = true`
    - `(27,22).west = true`
    - `(27,22).south = true`
    - `(27,23).north = true`
    - `(27,23).south = true`
    - `(27,24).north = true`
  - Clean live evidence:
    - `probe_edge_verify` confirmed all eight faces above as blocked `5/5`
      with `classification=confirmed_blocked`
    - forced `(26,22)->auto_walk:29,29` had planned
      `5 south, 3 east, 2 south` but never left `(26,22)`, which is what led
      to the x=26 throat recheck
  - Live planner effect after `reload_navigation_modules`:
    - from forced `(26,22)`, the planner no longer tries the disproved south
      exit and reroutes east instead
    - from forced `(27,23)`, it still claims `4 south, 2 east, 2 south`, but
      the first south step is now also disproved
  - Current interpretation:
    - the southeast pocket cleanup is still uncovering real closed seams, not
      an executor-only issue
    - the next likely bridge candidate has shifted to the row-24 / x=27->x=28
      shelf rather than the already-closed x=26/x=27 north-south throats

- Fresh same-day continuation cleaned up that row-24 shelf too.
  - Permanent model fixes now in repo:
    - `(25,23).south = true`
    - `(25,24).north = true`
    - `(26,23).south = true`
    - `(26,24).north = true`
    - `(26,24).east = true`
    - `(27,24).west = true`
    - `(27,24).east = true`
    - `(27,24).south = true`
    - `(27,25).north = true`
    - `(28,24).west = true`
  - Clean live evidence:
    - all ten faces above were verified `5/5` blocked with
      `classification=confirmed_blocked`
    - forced `(27,24)` is now honestly boxed:
      `debug_pathfind_to_allow_hazards:29,29` from `(27,24)` is
      `No path found`
  - Live planner effect after the additional south closures:
    - forced `(26,23)` no longer routes into the boxed row-24 west shelf
    - current forced remainder from `(26,23)` is now
      `2 east, 1 north, 1 east, 7 south`
  - Current interpretation:
    - the next likely bridge candidate has shifted back to the x=28/x=29
      handoff rather than the row-24 west shelf

- Fresh same-day continuation then cleaned up the next forced reroutes and
  sharpened the remaining mystery.
  - Permanent model fixes now in repo:
    - `(24,23).south = true`
    - `(24,24).north = true`
    - `(27,23).east = true`
    - `(28,23).west = true`
  - Clean live evidence:
    - all four faces above were verified `5/5` blocked with
      `classification=confirmed_blocked`
    - forced `(27,23)` is now `No path found` to `(29,29)`
  - Important live forced-state bracket:
    - forced `(27,21)` still plans `2 east, 8 south`
    - forced `(27,22)` still plans `2 east, 7 south`
    - forced `(28,22)` still plans `1 east, 7 south`
    - but interrupted-turn follow-up resolved that direct
      `(28,22)->probe_edge:RIGHT` reaches `(29,22)` and then settles on the
      World Map at `(43,43)`, so the x=29 lane remains real-but-weird
  - Key row-21 retest:
    - from forced `(25,21)`, even skip-NPC planning cannot reach `(27,21)`,
      `(27,22)`, or `(29,29)`
    - forced `(27,21)->LEFT` still settles all the way back to `(25,21)`
    - from that landed state, `probe_edge:RIGHT` from `(25,21)` can carry to
      `(27,21)`, but a cold/stopped long raw `RIGHT` only reaches `(26,21)`
      and a fresh `probe_edge:RIGHT` from `(27,21)` still blocks
  - Current interpretation:
    - the remaining bridge, if one exists, is now concentrated around the
      stateful row-21 carry into `(27,21)` rather than ordinary static map
      geometry on the row-24 shelf or the x=27/x=28 row-23 handoff

- Fresh row-21 retest made that stateful carry much crisper.
  - Clean live movement sequence:
    - `(24,21)->RIGHT` settles at `(25,21)`
    - `(25,21)->RIGHT` settles at `(26,21)`
    - `(26,21)->RIGHT` blocks cleanly into `(27,21)`
  - But the reverse-seeded carry is now repeatable:
    - forced `(27,21)->LEFT` settles all the way back at `(25,21)`
    - immediately after that reverse move, `probe_edge:RIGHT` from `(25,21)`
      carries and settles back at `(27,21)` in one step
    - a fresh `RIGHT` from the landed `(27,21)` state still blocks into
      `(28,21)`
  - Current interpretation:
    - the remaining bridge behavior on row 21 is not a simple static open/closed
      seam
    - the x=27 shelf is planner-reachable from forced states, but the west
      entry into it now looks like a repeatable stateful carry/refusal pattern
      rather than an ordinary map-data miss

- Fresh same-day executor isolation pass used new manual NPC parking controls to
  remove row-21 NPC clutter from the equation.
  - New debug hooks now available:
    - `park_npcs` / `park_npcs:all`
    - `park_npcs:mobile`
    - `restore_parked_npcs`
  - Local regression coverage was added in `test_route_manager.lua`.
  - Clean parked-NPC live findings:
    - from real `(25,21)`, `probe_edge:RIGHT` still settles only at `(26,21)`
    - from real `(26,21)`, `probe_edge:RIGHT` cleanly blocks into `(27,21)`
      with `reason=raw_hold_timeout`
    - forced `(27,21)->LEFT` still settles at `(25,21)`
    - immediate `probe_edge:RIGHT` from that landed `(25,21)` state still
      carries back to `(27,21)`
    - a fresh current-position `probe_edge:RIGHT` from the carried `(27,21)`
      state can still block into `(28,21)`
  - Important executor conclusion:
    - the reverse-seeded row-21 carry survives even with NPCs parked, so it is
      not Guard-occupancy noise
    - but simple west-side macros are not enough to reproduce it from normal
      reachable starts:
      - cold raw `RIGHT,40` from `(25,21)` ends at `(26,21)`
      - raw `LEFT,40;RIGHT,40` from forced `(26,21)` ends back at `(26,21)`
    - this means the odd carry currently depends on special arrival/start
      state, not a simple executor jiggle that autowalk can safely use from the
      west side
  - Additional caution:
    - `probe_edge_verify:27,21,RIGHT,5` from fresh forced `(27,21)` was
      `confirmed_passable` (`moved=6 blocked=0`) and ended at `(29,21)`
    - so `27,21->RIGHT` is not stable map geometry either; the block only
      appears after specific carry-arrival states
  - Current interpretation:
    - do not promote new row-21 or `(28,21).west` map data from this pass
    - the next useful work is executor/state investigation around how that
      carried arrival toggles the east-step behavior, not more static blocker
      archaeology on row 21

- Fresh same-day first pass with enhanced edge-motion instrumentation refined
  the row-21 executor picture again.
  - `main.lua` edge probes now log:
    - `EDGE_MOTION_STATE` at probe start/result
    - `EDGE_PROBE_CARRY` when a one-step probe settles past its nominal
      destination
  - Clean parked-NPC live sequence from reload:
    - cold forced `(27,21)->RIGHT` started with `move=0x0C sub=0x90` and
      carried to `(29,21)`
    - forced `(27,21)->LEFT` also started with `move=0x0C sub=0x90` and
      carried to `(25,21)`
    - immediate `(25,21)->RIGHT` started with `move=0x00 sub=0x00` and
      carried to `(27,21)`
    - fresh `(27,21)->RIGHT` after that carry started with `move=0x09 sub=0x90`
      and still carried to `(29,21)`
  - Current interpretation:
    - the post-carry state at `(27,21)` really is different (`0x09` instead of
      `0x0C`), so the new instrumentation is paying off
    - but that state difference alone did not recreate the older blocked
      `(27,21)->RIGHT` behavior on this reload
    - keep treating the row-21 anomaly as a richer hidden-state/timing issue,
      not yet a single-byte explanation or new static blocker

- Fresh same-day second pass with settle-window tracing gave the clearest
  timing picture yet.
  - `EDGE_PROBE_SETTLE_TRACE` is now live and captures change-only samples
    across the 60-frame post-destination settle window.
  - This reload's row-21 family:
    - cold forced `(27,21)->RIGHT` started at `move=0x08` and still carried to
      `(29,21)`
    - forced `(27,21)->LEFT` started at `move=0x07` and carried to `(25,21)`
    - immediate `(25,21)->RIGHT` also started at `move=0x07` and carried to
      `(27,21)`
    - fresh `(27,21)->RIGHT` after that carry again started at `move=0x07` and
      still carried to `(29,21)`
  - Useful settle-trace pattern:
    - east carries spend many settle frames at `(28,21)` with `move=0x05`
      while scroll and overworld bytes churn, then land at `(29,21)` and later
      pass through `0x00`, `0x50`, and stable `0x07/0x08`
    - west carries mirror that with many settle frames at `(26,21)` using
      `move=0x02`, then landing at `(25,21)` and later passing through `0x04`,
      `0x00`, `0x50`, and stable `0x07`
  - Current interpretation:
    - the row-21 anomaly looks more like a multi-frame conveyor/settle state
      than a simple one-byte latch
    - immediate follow-up probes are inheriting transitional state from the
      prior carry, but on this reload that transitional state did not recreate
      the older blocked east step

- Fresh same-day restored-state retest finally preserved a blocked row-21
  branch that differs from the earlier carry-friendly reloads.
  - Clean restored baseline:
    - `POSITION: (27,21)`
    - upper dialogue inactive, menu closed
    - `report_movement_state:restored` showed a new harsher row-21 family:
      `... 00 08 1B 15 10 10 D7 FF 50 01 08 14 ...`
  - Clean east rejection from that restore:
    - direct current-position `probe_edge:RIGHT` started at
      `move=0x10 sub=0x10`
    - it blocked in place and collapsed to the older rejection family
      `move=0x0F sub=0x90`
    - this is now the best preserved "heard the engine reject that one"
      branch captured in logs
  - Important asymmetry:
    - from that blocked `(27,21)` state, `probe_edge:LEFT` still carried and
      settled at `(25,21)`
    - but immediate `probe_edge:RIGHT` from landed `(25,21)` no longer carried
      back to `(27,21)` on this restore; it only settled at `(26,21)`
    - that return leg started from a new intermediate family
      `move=0x0B sub=0x90`
    - immediate `probe_edge:RIGHT` from `(26,21)` then blocked cleanly into
      `(27,21)` with ordinary directional refusal
  - Current interpretation:
    - the row-21 anomaly is now best modeled as a small hidden state machine
      rather than a single carry trick
    - the user-restored save preserved a real east-rejection family at
      `(27,21)`
    - leftward escape from that family still works, but the old seeded return
      carry to `(27,21)` did not survive this restore
    - next useful work is executor/state instrumentation or controlled
      state-seeding around the `0x10 -> 0x0F -> 0x0B` branch transitions, not
      more static map-data edits on row 21

- Fresh same-day directional state-seeding retest found the first clean
  "unlock condition" for the row-21 shelf.
  - North/south arrivals do not unlock the seam:
    - forced `(26,20)->DOWN` settled at `(26,21)` with a fresh
      `move=0x10 sub=0x90` row-21 family, but immediate `RIGHT` still blocked
    - forced `(26,22)->UP` carried through to `(26,20)`; cycling back down to
      `(26,21)` produced another fresh family `move=0x30 sub=0x90`, and
      immediate `RIGHT` still blocked
  - East-lane arrival does unlock it:
    - forced `(29,21)->LEFT` settles at `(27,21)`, not `(28,21)`
    - landed east-seeded `(27,21)` states used the east-shelf family
      (`scroll_x=0x90`) with captured movement states including
      `0x50/0x90`, `0x10/0x90`, and later cooled `0x08/0x90`
    - from that east-entered `(27,21)` state, `probe_edge:RIGHT` carries
      cleanly back to `(29,21)`
    - the opening survives at least a short cooldown/report interval; it is
      not just a one-frame blip
  - Current interpretation:
    - the row-21 mystery now looks like a directional conveyor state seeded by
      east-lane entry rather than a generic hidden wall or ordinary one-way
      seam
    - do not promote new static map data from this behavior
    - next useful work is to see whether route/executor logic can deliberately
      recognize or exploit the east-lane seeded shelf state, or whether a
      reproducible west-to-east seeding path exists elsewhere in live play

- Fresh same-day blocker cleanup around the row-21 throat removed two more fake
  reroute escapes and made the west-side shelf much more honest.
  - Permanent model fixes now in repo:
    - `(27,22).north = true`
    - `(27,20).south = true`
  - Clean live evidence:
    - direct current-position `probe_edge:DOWN` from `(27,21)` into `(27,22)`
      blocked cleanly with `reason=raw_hold_timeout`
    - direct current-position `probe_edge:UP` from `(27,21)` into `(27,20)`
      also blocked cleanly with `reason=raw_hold_timeout`
  - Live route effect after `reload_navigation_modules`:
    - from restored west-side `(27,21)`, the base planner still proposes
      `2 east, 8 south`, because the shelf remains statefully usable from
      certain east-seeded arrivals
    - but once the first east step `(27,21)->RIGHT` fails from the restored
      family, reroutes no longer hallucinate fake south or north escapes
    - after the first failed east seam, reroute now honestly collapses to
      `No path found`
  - East-side route validation still works:
    - forced `(29,21)` with hazards allowed plans `8 south`
    - live `auto_walk:29,29` from `(29,21)` completed down the x=29 lane and
      exited to the World Map at `(43,43)`
    - first `(29,21)->DOWN` needed one seam brute-force retry, then the
      follow-up replanned cleanly from `(29,22)` as `7 south`
  - Remaining uncertainty:
    - a fresh direct teleported `(29,21)->LEFT` later blocked instead of
      re-seeding `(27,21)`, so even the east-lane shelf entry is stateful
    - current route status is therefore:
      - west-side restored `(27,21)`: route now fails honestly after the
        first east seam
      - east-side seeded / arrived `(29,21)`: route to the exit sings
    - next useful work is executor/state characterization around what arrival
      families make `(29,21)->LEFT` and `(27,21)->RIGHT` reproducibly passable

- Fresh same-day x=29 lane timing bracket sharpened the east-entry story again.
  - Direct teleported idle `(29,21)` remains blocked left:
    - `probe_edge:LEFT` from teleported `(29,21)` blocks with the harsher
      teleported family (`move=0x10 sub=0x10`, `scroll_x=0xC0`,
      `scroll_y=0xE0`, `... D7 FF 50 01 08 14 ...`)
  - But raw timed descent from `(29,20)` can seed different `(29,21)` families:
    - `simulate_raw_sequence:DOWN,24,0` -> settles at `(29,21)` but `LEFT`
      still blocks
    - `simulate_raw_sequence:DOWN,25,0` -> settles at `(29,21)` and immediate
      `LEFT` moves to `(28,21)`
    - `simulate_raw_sequence:DOWN,26,0` -> no longer settles at `(29,21)`; it
      overshoots to `(29,22)`
  - The `DOWN,25` family is only half-open:
    - first `LEFT` reaches `(28,21)`
    - immediate second `LEFT` from `(28,21)` blocks into `(27,21)`
    - after a short wait, the same family cools into a different settled
      `(29,21)` signature (`scroll_x=0xB0`, `scroll_y=0x60`,
      `... 10 10 E7 FF D0 01 D8 05 ...`) and then `LEFT` blocks again
  - Current interpretation:
    - `(29,21)->LEFT` now has at least three distinct arrival families:
      blocked idle teleport, half-open one-step lane arrival, and the earlier
      fully open family that carried to `(27,21)`
    - the timing edge between `DOWN,24` and `DOWN,25` is strong evidence that
      x=29 lane entry is controlled by a precise hidden movement-state window
    - next useful work is likely executor-side if we want to intentionally hit
      the half-open or fully open family, not more static blocker promotion

- Fresh 2026-05-24 west-pocket continuation materially improved the restored
  shrine route investigation.
  - Permanent model fixes now in repo:
    - removed stale `MAP_BLOCKED_CELLS[0x04]["21,23"]`
    - added passthrough `MAP_PASSTHROUGH_CELLS[0x04]["16,13"]`
    - added passthrough `MAP_PASSTHROUGH_CELLS[0x04]["16,14"]`
    - added directional seam `MAP_DIRECTIONAL_BLOCKS[0x04]["18,15"].east = true`
    - added directional seam `MAP_DIRECTIONAL_BLOCKS[0x04]["21,23"].west = true`
    - added directional seam `MAP_DIRECTIONAL_BLOCKS[0x04]["22,23"].west = true`
    - added closed row-22 seam
      `MAP_DIRECTIONAL_BLOCKS[0x04]["23,22"].east = true`
      and `MAP_DIRECTIONAL_BLOCKS[0x04]["24,22"].west = true`
  - Live planner effect:
    - from `(16,15)` with west-pocket runtime helpers, hazards-allowed
      planning to `(29,29)` revived to `2 north, 2 east, 7 south, 2 east,
      3 south, 2 east, 1 north, 7 east, 7 south`
    - autowalk then advanced as far as `(25,13)` during the latest pass
  - Important stateful seam note:
    - `(19,15)->LEFT` into `(18,15)` blocked cleanly on a natural route arrival
      while forced `(18,15)->RIGHT` moved back through, justifying the
      permanent `.east` closure
    - the sibling `(17,15)->RIGHT` into `(18,15)` is still mixed/stateful:
      direct teleported probes moved, but natural routed arrivals blocked
      repeatedly, so keep `(18,15).west` runtime-only when needed and do not
      promote it yet
  - Current strongest next candidate:
    - `18,13->DOWN` looked strong in route context but a direct current-position
      probe from clean `(18,13)` actually moved through and settled at
      `(18,15)`, so do not promote that seam from the earlier route evidence
    - the live frontier has now shifted into the restored southeast pocket:
      - `21,23->UP` into `(21,22)` blocks directly from current position
      - `23,22->RIGHT` into `(24,22)` blocks directly, and reverse
        `(24,22)->LEFT` also blocks
      - from forced `(24,22)`, autowalk next exposes route-shaped blocked-only
        candidates at `(24,23)` approach=north and `(25,22)` approach=west
  - Current live state at the end of this pass:
    - player at `(24,22)` in Tantegel
    - runtime helpers active:
      `(16,16).north`, `(17,16).north`, `(18,15).west`, `(21,22).west`

- Fresh 2026-05-24 deeper southeast-pocket shelf dig corrected the next
  over-open throat just upstream of that restored pocket.
  - Permanent model fixes now in repo:
    - `(25,22).east = true`
    - `(25,22).south = true`
    - `(26,22).west = true`
    - `(25,23).north = true`
  - Live evidence chain:
    - direct current-position `(25,22)->RIGHT` blocked
    - forced `(26,22)->LEFT` blocked
    - direct current-position `(25,22)->DOWN` blocked
    - forced `(25,23)->UP` blocked
  - Deeper teleported shelf cells around `(25,24)` / `(26,24)` / `(27,24)`
    also behaved boxed-in despite open previews, but those remain scratch-only
    for now instead of permanent model data.
  - Runtime collapse check:
    - after mirroring scratch seams `(26,23).west` and `(25,24).north` plus
      the new `(25,22)` east/south throat closures, forced
      `debug_pathfind_to_allow_hazards:29,29` from `(25,22)` finally reported
      `No path found`
  - Current interpretation:
    - the restored southeast pocket itself is not the missing bridge
    - the remaining planner-visible route still depends on an upstream false
      bridge before `(25,22)`

- Fresh 2026-05-24 post-reload retest superseded the brief "Y=21 corridor
  restored" conclusion around `(26,21)->RIGHT`.
  - Live `auto_walk:29,29` from `(26,21)` still plans `3 east, 8 south`, but
    the first east step now blocks even after the new longer seam-retry holds.
  - Direct follow-up agrees with the live route failure:
    - `simulate_raw_sequence:RIGHT,40,0` from `(26,21)` stays at `(26,21)`,
    - `probe_edge:RIGHT` from `(26,21)` blocks with `raw_hold_timeout`,
    - long raw `RIGHT,80` from forced `(25,21)` still settles at `(26,21)`,
    - forced `(26,20)` then raw `DOWN,40;RIGHT,40` ends at `(26,21)`.
  - Runtime reblocking `(27,21).west` collapses
    `debug_pathfind_to_allow_hazards:29,29` to `No path found` from both
    checked entrances:
    - forced `(7,7)` -> `No path found`
    - forced `(11,28)` -> `No path found`
  - Permanent correction reapplied: `MAP_DIRECTIONAL_BLOCKS[0x04]["27,21"].west = true`.
  - Current interpretation: the shrine bridge is unresolved again. The earlier
    "restored from both entrances" route was relying on a bad `(26,21)->RIGHT`
    assumption, and there is no known alternate planner-visible bridge yet.

- Fresh FCEUX shrine retest from the lower west pocket found one more real
  geometry miss on the final approach: entering `(27,20)` from the west is a
  clean blocker, while leaving `(27,20)` back to the west remains passable.
- Permanent patch applied: `MAP_DIRECTIONAL_BLOCKS[0x04]["27,20"].west = true`
  (keeping the older `.east = true` evidence intact).
- After that patch, live autowalk toward `Stairs Down to Sun Shrine` no longer
  explains its failure with another hidden wall in the southeast pocket:
  - from `(22,18)` it advanced to `(22,21)` under hazard fallback,
  - `debug_pathfind_to_allow_hazards:29,29` from `(22,21)` reports
    `1 east, 1 south, 6 east, 7 south`,
  - and from forced-safe `(23,22)`, `debug_pathfind_to_park_npcs:29,29`
    again finds a clean remainder route: `6 east, 7 south`.
- A follow-up lower-shelf retest corrected the row-22 pocket model too:
  - `(23,21)->DOWN` into `(23,22)` is a real one-way refusal,
  - `(23,22)->UP` moves back into `(23,21)`,
  - `(23,22)->LEFT` moves into `(22,22)`,
  - but `(22,21)->DOWN` into `(22,22)` also blocks.
- Permanent patch applied: remove the stale full-cell blocker at `(22,22)` and
  replace it with directional north-entry seams at `(22,22)` and `(23,22)`.
- Post-reload, the planner now tells the truth about this branch:
  - from forced `(23,21)`, `debug_pathfind_to_allow_hazards:29,29` is
    `No path found`,
  - from forced `(23,22)`, parked planning still finds `6 east, 7 south`,
  - from forced upstream `(22,18)`, hazards-allowed planning is also
    `No path found`.
- A same-day reload retest then exposed one more overclosed seam earlier in the
  corridor: `(26,22).north`.
  - Live bracketing from `(7,7)` still found routes to `(25,17)`, `(25,18)`,
    `(25,20)`, `(25,21)`, and `(24,21)`, but targets on the next row such as
    `(24,22)`, `(25,22)`, and `(29,22)` were all `No path found`.
  - Forced current-position probing at `(26,21)` found the contradiction:
    `inspect_move:DOWN` claimed `(26,22)` was directionally blocked, but raw
    `probe_edge:DOWN` moved into `(26,22)` cleanly.
  - Permanent fix applied: remove `MAP_DIRECTIONAL_BLOCKS[0x04]["26,22"].north`.
- Post-reload revalidation after that fix:
  - from `(7,7)`, `debug_pathfind_to_allow_hazards:29,29` finds a 48-step
    route,
  - from `(11,28)`, `debug_pathfind_to_allow_hazards:29,29` finds a 63-step
    route,
  - both routes use the same hazard set:
    `(25,18)`, `(23,18)`, `(23,19)`, `(23,20)`, `(23,21)`.
- Later live edge recheck at `(26,21)` kept the south seam closed:
  - `probe_edge_verify:26,21,DOWN,5` blocked 5/5,
  - `probe_edge_verify:26,22,UP,5` moved 6/6 including the stability recheck.
- A follow-up settled-probe pass corrected the Y=21 corridor model:
  - `probe_edge` now waits for movement to settle before logging final
    position, after it was caught reporting the first coordinate change as the
    final stop.
  - Settled `(27,21)->LEFT` reached/passed `(26,21)` and stopped at `(25,21)`.
  - Settled `(25,21)->RIGHT` reached/passed `(26,21)` and stopped at `(27,21)`.
  - A cold verifier from a teleported/stopped `(26,21)->RIGHT` can still bump,
    so treat that as start-state/runtime weirdness, not a permanent corridor
    closure.
- Permanent fixes applied: keep `MAP_DIRECTIONAL_BLOCKS[0x04]["26,22"].north`,
  but remove the stale `MAP_DIRECTIONAL_BLOCKS[0x04]["27,21"].west` guard.
- This corridor-restored interpretation has since been superseded by the later
  reloaded retest at the top of this file. Keep the older evidence only as the
  history of why `(27,21).west` was temporarily removed.
- Post-shrine cleanup is still uncovering stale castle geometry on the Sage side:
  `11,19` has been cleared as a false hazard, while new Sage-route directional
  blockers were confirmed at `(21,20).east`, `(24,9).north`, `(19,16).north`,
  and `(20,16).north`.

- Cleanup follow-up before floor closure:
  - Removed the stale `objects.lua` stairs artifact at `Tantegel` `(1,1)` and
    kept the Sun Shrine route stair as the live-only destination.
  - Removed the stale south-gate door artifact object at `(10,30)` from
    `EXTRA_DOORS`; entrance travel is modeled through the actual exit.
  - Added regression coverage in `test_objects.lua` and `test_map_reader.lua` to
    ensure the stale markers stay absent and `(25,16)/(25,17)` stay non-hazard.

## Runtime Baseline

- Normal launch: `./launch_dw.sh`
- Explicit FCEUX launch: `./launch_dw.sh --emulator fceux` or
  `./launch_fceux.sh`
- Explicit BizHawk launch: `./launch_dw.sh --emulator bizhawk` or
  `./launch_bizhawk.sh`
- Commands go through `./dw_commands.sh` from bash or `./dw_commands.ps1` from
  PowerShell/Codex.
- Use `--replace` for state-sensitive command batches and verify
  `dw_debug.log` between live steps.
- Use `--require-live SECONDS` when stale logs would mislead the result.
- Do not batch `teleport_to` with `probe_edge`, `survey_target`,
  `report_survey_start`, or path-debug follow-up commands when exact start
  state matters.

## Latest Accepted Work

### Tantegel Post-Sun-Shrine Cleanup

- `11,19` is no longer modeled hazardous on `0x04`: live HP snapshots stayed
  `54/54` before and after crossing it from `(12,19)`.
- Sage-route cleanup promoted one clean east-approach blocker directly:
  `probe_edge_verify:22,20,LEFT,5` blocked `5/5`, so `(21,20).east` is now
  modeled.
- The mixed `(22,17)->LEFT` seam was not promoted, but blocking it at runtime
  exposed a row-16 alternate path that revealed three more real castle seams:
  - `probe_edge_verify:24,8,DOWN,5` blocked `5/5`, so `(24,9).north`.
  - `probe_edge_verify:19,15,DOWN,5` blocked `5/5`, so `(19,16)` is closed
    from both north and south.
  - `probe_edge_verify:20,15,DOWN,5` blocked `5/5`, so `(20,16)` is closed
    from both north and south.
- Do not promote `(21,17).east`, `(22,17).south`, or the row-15 lateral
  `(19,15)<->(20,15)` noise from this pass; those stayed mixed/noisy.

### Tantegel Sun Shrine Forward Route Correction

Follow-up live FCEUX route testing on 2026-05-23 corrected the earlier
"horizontal row-9 bridge" interpretation and kept the forward route to
`(29,29)` under active investigation:
- User play proved the Sun Shrine stairs back to the entrance/throne-room side
  are clean, but the return direction from the throne side toward `(29,29)`
  failed at `(14,16)->RIGHT`.
- Direct verifier evidence confirmed the old row-16 forward route is invalid:
  `probe_edge_verify:14,16,RIGHT,5` blocked 5/5 with no drift, map change, or
  NPC contamination. `MAP_DIRECTIONAL_BLOCKS[0x04]["15,16"].west` is now
  modeled.
- User then found row-9 reversal behavior around `(12,9)` / `(13,9)`, but a
  fresh 2026-05-24 FCEUX recheck superseded the earlier closure:
  `probe_edge_verify:12,9,RIGHT,5` moved 6/6 including the delayed stability
  recheck, and neighboring `11,9<->12,9` plus `13,9->12,9` also moved cleanly.
  `MAP_DIRECTIONAL_BLOCKS[0x04]["13,9"].west` has been removed again; only the
  north/south approaches on `(13,9)` remain modeled.
- A fixed-verifier retest later showed `(14,8)->DOWN` was also stale latch
  evidence: it blocked 5/5 with `blocked_model_mismatch=5`, so
  `["14,9"].north` is closed. `["14,9"].south` remains blocked and
  `["14,9"].west` remains open.
- The apparent `(20,17)->RIGHT` bridge was a stale/contaminated verifier result.
  After a manual FCEUX Lua reload and live autowalk failure at the same edge,
  fresh hardened `probe_edge_verify:20,17,RIGHT,5` blocked 5/5 with
  `blocked_model_mismatch=5`. Reverse `probe_edge_verify:21,17,LEFT,5`
  still confirmed passable 6/6 with the delayed stability recheck, so this is
  modeled again as a one-way seam: `MAP_DIRECTIONAL_BLOCKS[0x04]["21,17"].west`.
- A temporary/open-model pass did expose southeast-pocket false exits, each
  confirmed 5/5 with no drift, map change, or interruption:
  `(26,22).north` and `(24,22).north`. The earlier `(27,21).west` promotion
  was later superseded by settled Y=21 corridor probes and has been removed.
- Later pinball near the stairs superseded the earlier mixed
  `(25,22).north` result: quiet direct `probe_edge_verify:25,21,DOWN,5`
  blocked 5/5 with no drift, map change, or interruption, so
  `(25,22).north` is now modeled. Do not promote `(27,20).west`: quiet direct
  `probe_edge_verify:26,20,RIGHT,5` again confirmed passable 6/6 including
  the delayed stability recheck, despite noisy route-shaped blocked counts.
- The older "enter the southeast x=29 lane from `(28,20)` / `(28,23)`"
  interpretation has been superseded by fresh 2026-05-24 east-edge retests:
  - `(28,20)->RIGHT` changes to the World Map immediately.
  - `(28,21)->RIGHT` enters the castle-side x=29 lane at `(29,21)`.
  - `(28,22)->RIGHT` enters the castle-side x=29 lane at `(29,22)`.
  - `(28,23)->RIGHT` changes to the World Map immediately.
  - Forced `(29,21)->RIGHT` and `(29,22)->RIGHT` also exit to the World Map.
  - Permanent guard update: `MAP_DIRECTIONAL_BLOCKS[0x04]["29,20"].west = true`
    and `["29,23"].west = true`.
  - Current interpretation: the planner should only consider westward entry
    into the southeast x=29 lane at y=21-22. The remaining live question is
    whether that narrower lane entry fully restores the shrine route from
    normal play space after reload.
  - Fresh post-reload validation says no: from the normal castle restore at
    `(26,5)`, even hazards-allowed and skip-NPC planning still report
    `No path found` for `(29,21)`, `(29,22)`, and `(29,29)`.
  - Forced-side split check is now clear:
    - from forced `(26,21)`, `debug_pathfind_to_allow_hazards:29,29` is
      `No path found`, and even `(26,22)` is `No path found`;
    - from forced `(29,22)`, `debug_pathfind_to_allow_hazards:29,29` is
      `Path: 7 south`.
  - Current interpretation: the southeast x=29 lane and world-exit behavior
    are modeled more honestly now, but the normal castle component is still
    disconnected west of that lane, with the current live frontier ending at
    `(26,20)/(26,21)`.
  - Fresh same-day follow-up materially changed that status:
    - `inspect_tile:21,22` exposed a stale permanent blocker on the restored
      row-22 bridge corridor.
    - Cold forced movement proved `(21,22)` is traversable from `(23,22)` and
      back again, so `MAP_BLOCKED_CELLS[0x04]["21,22"]` has been removed.
    - Post-reload planner checks from forced `(20,22)` now see the corridor
      directly:
      - `(21,22)` -> `Path: 1 east`
      - `(22,22)` -> `Path: 2 east`
      - `(23,22)` -> `Path: 3 east`
      - `(29,29)` -> `Path: 9 east, 7 south`
    - Post-reload planner checks from the normal castle restore `(26,5)` also
      now find a clean no-hazard route to `(29,29)`.
    - Live autowalk still does not finish end to end, but for a better reason:
      it now reaches farther upstream and exposes the next missing blockers
      before row 22, not a disconnected southeast lane.
    - Two of those newly exposed blockers were directly verified and promoted:
      - `(22,17)->LEFT` blocked 5/5, so `(21,17).east = true`
      - `(22,17)->UP` blocked 5/5, so `(22,16).south = true`
  - Current interpretation: the row-22 corridor is now validated and
    planner-visible; remaining shrine-route work has shifted upstream again.
    Follow-up direct verifier from forced `(25,15)` then confirmed the sibling
    west-face blocker `(24,15).east`, while the already-modeled `(24,16).east`
    still needs a clean non-interrupted reconfirmation if we revisit that row.
  - Fresh continuation after promoting `(24,15).east` moved the frontier again:
    autowalk now reaches `(24,17)` / `(23,17)` and repeatedly bumps on the
    row-16 north faces into `(24,16)` and `(23,16)`.
  - Caveat: `probe_edge_verify` is currently unreliable on those exact north
    faces, returning `inconclusive_interrupted ... Wait for the upper dialogue window to clear`
    even when adjacent `report_upper_dialogue_state` says the upper window is
    inactive.
  - Current-position `probe_edge:UP` from both `(24,17)` and `(23,17)` still
    reproduced `blocked_despite_open_preview`, so these are strong blocker
    candidates.
  - Correct runtime edge injection uses source cell + direction:
    `add_blocked_edge:24,17,UP` and `add_blocked_edge:23,17,UP` become
    runtime `(24,16).south` and `(23,16).south`.
  - With those two runtime edges injected correctly, live
    `debug_pathfind_to_allow_hazards:29,29` from `(24,17)` collapses to
    `No path found`.
  - Current interpretation: either one/both of those row-16 north faces are
    true blockers and the remaining route needs a different bridge nearby, or
    there is still a stateful carry seam in this pocket that simple probes are
    not capturing. Next work is a stateful/raw-sequence A/B around
    `(23,17)/(24,17)->UP` before permanently promoting both south faces.
  - Fresh same-day FCEUX continuation superseded that remaining uncertainty:
    after recovering a hidden FCEUX menu/input latch with
    `recover_fceux_input.sh`, repeated clean verifiers promoted the row-16/17
    pocket blockers directly:
    - `(25,14)->LEFT` blocked 5/5, so `(24,14).east = true`
    - `(24,17)->UP` blocked 5/5, so `(24,16).south = true`
    - `(23,17)->UP` blocked 5/5, so `(23,16).south = true`
    - `(22,15)->DOWN` blocked 5/5, so `(22,16).north = true`
    - `(22,15)->LEFT` blocked 5/5, so `(21,15).east = true`
    - `(23,15)->DOWN` blocked 5/5, so `(23,16).north = true`
  - Runtime mirroring of those edges did **not** collapse the shrine route.
    The planner kept finding detours:
    - from `(23,17)` with `(23,16).south` and `(24,16).south` mirrored:
      `2 east, 4 north, 3 west, 3 south, 2 west, 6 south, 9 east, 7 south`
    - from `(22,15)` after also mirroring `(22,16).north` and `(21,15).east`:
      `1 east, 1 south, 3 west, 6 south, 9 east, 7 south`
    - from `(23,15)` after also mirroring `(23,16).north`:
      `1 east, 1 south, 4 west, 6 south, 9 east, 7 south`
  - Current interpretation:
    - the route is healthier than it looked; each promotion is peeling back to
      the next real blocker instead of exposing a dead component.
    - the next frontier is north/west of `(23,15)` rather than back in the
      southeast lane or row-17 pocket.
    - The running FCEUX script still needs a full Lua reload to pick up the
      permanent `map_reader.lua` changes; until then, use runtime
      `add_blocked_edge` injections for live continuity.
  - Fresh same-day continuation after reload dug farther into the west pocket:
    - clean verifiers promoted two more faces:
      - `(22,14)->LEFT` blocked 5/5, so `(21,14).east = true`
      - `(24,15)->DOWN` blocked 5/5, so `(24,16).north = true`
    - several neighboring seams stayed mixed and should remain runtime-only:
      - `(23,14)->RIGHT` into `(24,14)` was mixed `2 moved / 3 blocked`, while
        reverse `(24,14)->LEFT` was passable `6/6`
      - `(20,15)->RIGHT` into `(21,15)` was mixed `2 moved / 3 blocked`
      - `(19,15)->LEFT` into `(18,15)` was mixed `2 moved / 3 blocked`
      - `(23,15)->RIGHT` into `(24,15)` looked blocked in natural route
        context but verified passable `6/6`, so do not promote `(24,15).west`
    - even with clean `(21,14).east` + `(24,16).north` mirrored, plus a
      runtime-only helper block on mixed `(24,14).west`, the planner still
      found a live detour from `(24,15)`:
      `2 north, 4 west, 2 south, 1 east, 2 south, 1 west, 5 south, 9 east, 7 south`
    - that detour reaches a higher-west pocket but turns noisy again around
      `(22,13)/(22,14)` with drift and mixed seam retries, not another clean
      permanent blocker yet
  - Fresh suspect-first retest after a later full reload clarified the two
    remaining west-pocket faces:
    - `(19,15)->LEFT` blocked repeatedly from live current-position probes,
      while reverse `probe_edge_verify:18,15,RIGHT,5` was passable `6/6`
      including the stability recheck
    - `(20,15)->RIGHT` moved cleanly on a current-position probe, and reverse
      `(21,15)->LEFT` also moved back through the seam
  - Current interpretation:
    - treat `(18,15).east` as the best runtime-only one-way-seam helper in
      this pocket for now
    - do **not** promote `(21,15).west`; current natural probes contradict the
      route-shaped blocked counts there
    - with only runtime `(18,15).east` mirrored, the planner still finds a
      live detour from `(19,15)` and continues into a deeper west branch rather
      than collapsing
  - Follow-up stateful raw-sequence A/B did not open either face:
    - `(24,17)` with carried `LEFT;UP` still stopped at `(23,17)`
    - long `UP,80` from `(24,18)` stopped at `(24,17)`
    - long `UP,80` from `(23,18)` stopped at `(23,17)`
  - A bounded crawler from `(23,17)` then reinforced the same result instead of
    finding a hidden bridge. It exported no passthrough candidates, reproduced
    `(23,17)->UP` as a directional candidate, re-confirmed existing
    `(22,17)->UP -> (22,16).south`, then aborted on low HP after walking south
    into the hazard lane.
  - Current interpretation: the row-16 pocket is looking more like genuine
    blocker geometry than a stateful hidden passage. The main remaining live
    candidate is promoting `(23,16).south`, but doing so will need a fresh
    route search from a clean restored state because temporary runtime injection
    of both `(23,16).south` and `(24,16).south` collapses the route component.
  - Fresh clean-restore retest then changed that conclusion:
    - forced `(23,17)` plus current-position `probe_edge:UP` moved cleanly and
      settled at `(23,15)`, so `(23,16).south` is not ready for promotion as a
      blocker.
    - injecting only `add_blocked_edge:23,17,UP` from clean restore `(26,5)`
      did not kill the route; hazards-allowed planning still found a 41-step
      path and live autowalk rerouted around it.
    - that rerouted autowalk then exposed a new clean blocker at
      `(21,13)->DOWN` into `(21,14)`.
    - direct `probe_edge_verify:21,13,DOWN,5` confirmed `blocked=5/5` with
      `blocked_model_mismatch=5`, so `MAP_DIRECTIONAL_BLOCKS[0x04]["21,14"].north`
      is now promoted.
    - mirroring only `(21,14).north` at runtime from clean restore still leaves
      a route to `(29,29)`; live autowalk progressed to `(24,13)` and the next
      likely blocker is now `(25,14)->LEFT` into `(24,14)`.
- Current interpretation: the shrine-to-throne/entrance direction remains
  clean. The throne/entrance-side forward route is not yet clean: with the
  fresh `(21,17).west` runtime block injected, live `debug_pathfind_to:29,29`
  and `debug_pathfind_to_skip_npcs:29,29` both report no path from the
  `(19,17)/(20,17)` side. Next work is to bracket the missing forward bridge
  without reopening `(20,17)->RIGHT`.
- 2026-05-24 autowalk follow-up:
  - User reported another stall with doors open in Tantegel, looping around the
    `29,10` corridor and collecting seam blockers near `26,9`/`26,10`.
  - Direct `probe_edge_verify` confirmed both `26,9->27,9` and `26,10->27,10` are
    blocked when approached from the west, while the reverse approach stays open.
  - Permanent patch corrected in `map_reader.lua` to match destination-side blocking:
    `MAP_DIRECTIONAL_BLOCKS[0x04]["27,9"].west=true` and
    `MAP_DIRECTIONAL_BLOCKS[0x04]["27,10"].west=true`.
  - Matching assertions were added in `test_map_reader.lua` (`27,9 west` and
    `27,10 west`). Reload and re-run `debug_pathfind_to:29,29` from throne/entrance
    routes before closing this loop.
- 2026-05-24 lower hazard-pocket continuation:
  - Fresh live baseline at `(26,18)` had no open menu/dialogue state and no runtime
    blockers.
  - `probe_edge_verify:26,18,RIGHT,5` was unusable there because the verifier's
    internal teleport reset refuses hazard tiles. Current-position raw probes were
    used instead.
  - From live current positions, `probe_edge:RIGHT` blocked 3/3 at both
    `(26,18)->(27,18)` and `(26,19)->(27,19)`, each with
    `EDGE_PROBE_MODEL_MISMATCH ... blocked_despite_open_preview`.
  - Permanent patch: `MAP_DIRECTIONAL_BLOCKS[0x04]["27,18"].west=true` and
    `MAP_DIRECTIONAL_BLOCKS[0x04]["27,19"].west=true`.
  - With both runtime edges injected, `debug_pathfind_to_allow_hazards:29,29`
    rerouted away from the x=26 east exits and back through the x=23 damage lane,
    so the next live continuation should start from that reroute rather than retrying
    the old `(26,18)/(26,19)` east edges.
- 2026-05-24 restored-save continuation from `(26,5)`:
  - The unreloaded live planner still traced the old lower route through
    `(25,18)->(26,18)->(26,19)->(26,20)->(27,20)->(27,21)->...->(29,29)`.
  - Re-injecting runtime `(27,18).west` and `(27,19).west` did not change that
    particular route because it does not use the two patched east exits.
  - Direct current-position `probe_edge:DOWN` from `(27,20)` then blocked 3/3
    into `(27,21)` with `EDGE_PROBE_MODEL_MISMATCH ... blocked_despite_open_preview`.
  - Permanent patch: `MAP_DIRECTIONAL_BLOCKS[0x04]["27,21"].north=true`.
  - With runtime `(27,21).north` injected, the same live branch rerouted to the
    healthier southeast lane: `(27,20)->(28,20)->(28,21)->(28,22)->(29,22)->...`.
  - Current-position raw probing confirmed the opening bridge
    `(27,20)->(28,20)` moved cleanly.
- 2026-05-23 follow-up on the southeast connector:
  `probe_edge` from forced `(28,10)` moved to `(28,11)` despite `MAP_BLOCKED_CELLS`
  reporting it as blocked (model-mismatch), and forced `(28,11)->UP` moved back.
  A clean `probe_edge:RIGHT` from forced `(28,11)` moved to `(29,11)` and then
  the engine transitioned to `map=0x01 (World Map)`, confirming the eastward
  seam at x=28 is a functional bridge rather than a hard block.
- 2026-05-23 follow-up from user play disproved the apparent `(14,7)->RIGHT`
  bridge as verifier-only contamination. Natural FCEUX autowalk attempts from
  `(14,7)` into `(15,7)` accumulated blocked-only evidence up to
  blocked `9` / moved `0`, so `MAP_DIRECTIONAL_BLOCKS[0x04]["15,7"].west`
  remains modeled.
- Route-shaped/current-position probes also kept these candidate bridges
  closed: `(14,8)->RIGHT`, `(14,8)->DOWN`, `(18,25)->RIGHT`,
  `(18,26)->RIGHT`, `(18,27)->RIGHT`, `(18,27)->DOWN`, `(17,27)->DOWN`,
  `(20,20)->RIGHT`, `(20,17)->RIGHT`, `(14,16)->RIGHT`, and northward entries
  from row 17 into row 16 at x=15,16,17,18,19,20.
- A capped review-only `crawl_map_frontier:attempts=3,max_edges=80` pass was
  manually stopped at 101 edges. It found passthrough candidates `(10,20)`,
  `(11,21)`, and `(13,13)`, but local ROM-backed route simulation showed those
  three do not connect the throne-side component to `(29,29)`. Keep them as
  review-only, not promoted route fixes.
- Follow-up after the user's `(14,7)` stall report confirmed the stall is real:
  `(14,7)->RIGHT` into `(15,7)` remains engine-blocked, and the earlier
  verifier-only passable result is contaminated evidence.
- External guide orientation agrees the Stones/Sunlight route requires a Magic
  Key, exits near the top/top-right of the castle, and hugs the outside wall to
  the lower-right stairs. Live door RAM during this pass already had both
  relevant map `0x04` doors open: `(4,13)` and `(18,6)`.
- Additional live checks kept the obvious single-bridge candidates closed:
  `(15,27)->DOWN`, `(15,27)->RIGHT`, `(19,23)->DOWN`,
  `(20,23)->DOWN`, `(20,18)->RIGHT`, `(20,19)->RIGHT`,
  `(20,21)->RIGHT`, `(14,6)->RIGHT`, `(14,15)->RIGHT`,
  `(14,13)->RIGHT`, `(14,12)->RIGHT`, and `(14,10)->RIGHT`.
- A second door-open frontier crawl was manually stopped at 236 edges. It
  exported review-only passthroughs `(9,6)`, `(10,6)`, `(11,6)`, `(12,6)`,
  `(13,13)`, `(7,12)`, `(8,12)` plus directional candidates `(3,6).north` and
  `(4,6).north`; local ROM-backed simulation with those opened still found no
  route from `(7,7)` to `(29,29)`. Do not promote those as the route fix.
- Top-right door-side route follow-up found the hidden exterior connector:
  `probe_edge_verify:21,8,RIGHT,5` entered `(22,8)` 6/6 despite tile `0`, and
  follow-up from `(22,8)` moved down into `(22,9)`. `MAP_PASSTHROUGH_CELLS`
  now includes `0x04["22,8"]`; this was the missing key-area/top-right
  connector, not a lower-boundary bridge.
- Reloaded route testing then stalled at `(14,6)->UP`. Direct verifier
  `probe_edge_verify:14,6,UP,5` blocked 5/5 with no drift, map change, or
  interruption, so `MAP_DIRECTIONAL_BLOCKS[0x04]["14,5"].south` is now modeled
  alongside the older `north` face.
- With `(14,5).south` injected at runtime, live planner still found a route
  from `(14,6)` / `(7,7)` to `(29,29)`. The next live autowalk attempt pinballed
  near `(25,21)` / `(26,20)`: promote only the quiet-confirmed
  `(25,22).north` blocker, keep `(27,20).west` open after a clean passable
  verifier, and continue live route verification after a script reload.
- Post-reload follow-up found the real x=25 descent the user had walked:
  `(25,10)->DOWN` entered `(25,11)` 6/6 despite tile `0`, and forced follow-up
  from `(25,11)->DOWN` entered normal floor `(25,12)`. `MAP_PASSTHROUGH_CELLS`
  now includes `0x04["25,11"]`.
- After `(25,11)` was reloaded, planner output from `(25,13)` changed to the
  desired lower descent route instead of the bad upper x=29 world-exit lane.
  Live autowalk then confirmed another false east exit:
  `probe_edge_verify:26,14,RIGHT,5` blocked 5/5, so `(27,14).west` is now
  modeled.
- Follow-up after revive/reload resolved the contradictory `(22,8)->DOWN`
  report: clean `probe_edge_verify:22,8,DOWN,5` blocked 5/5, so
  `(22,9).north` is now modeled. The missing connector was east along the
  top exterior strip instead: `(22,8)->RIGHT` moved 6/6 into `(23,8)`, and
  force-position/raw probes proved continuation through `(24,8)`, `(25,8)`,
  `(26,8)`, then down into normal floor `(26,9)`. `MAP_PASSTHROUGH_CELLS`
  now includes `0x04["23,8"]` through `["26,8"]`.
- Clean retry after a strange FCEUX input state reversed several apparent
  blockers: `(7,7)->RIGHT`, `(26,5)->LEFT`, and `(26,5)->UP` each moved 6/6
  with the verifier stability recheck. Do not promote the earlier blocked
  results for those edges.
- The upper x=29 exit lane is now guarded permanently: clean route testing
  showed west entries into `(29,9)` / `(29,10)` can leave Tantegel for the
  World Map instead of progressing toward the Sun Shrine. `MAP_DIRECTIONAL_BLOCKS`
  now includes `["29,9"].west` and `["29,10"].west` on map `0x04`.
- With only those two exit-lane guards injected at runtime, FCEUX autowalk from
  the throne-room stair tile `(7,7)` crossed the west side, the open `(18,6)`
  door, the top exterior strip, and the x=25 descent. It reached the lower
  corridor before dying: HP was `54/54` earlier in the run, `9/54` at
  `(26,20)`, then `Thou art dead.` at `(26,19)`.
- Current live blocker batch is paused for revive/reload plus lower-route
  hazard work. The lower x=25/x=26 route is walkable enough to reach the
  southeast corridor, but it crosses unmodeled damage cells. Candidate hazard
  cells from the death route originally included `(25,16)`, `(25,17)`,
  `(25,18)`, `(26,18)`, `(26,19)`, and `(26,20)`. Follow-up live north/south
  traversals plus the completed route cleared `(26,20)` specifically, so keep
  the modeled lower-route hazards at `(25,18)`, `(26,18)`, and `(26,19)`.
  Keep noisy route evidence for `(27,19).west` / `(27,20).west` unpromoted;
  prior quiet verifiers kept them open.
- Additional clean evidence confirmed the remaining forward bridge seam at the
  lower descent is one-way: `probe_edge_verify:26,14,DOWN,5` blocked
  `5/5` with no drift or interruption, while `probe_edge_verify:26,15,UP,5`
  confirmed passable. `MAP_DIRECTIONAL_BLOCKS[0x04]["26,15"].north` is now
  modeled to match this confirmed one-way behavior.
- Note: `(29,29)` is the shared Sun Shrine stair and southeast world-exit tile.
  The object navigator now exposes it as one Travel object:
  `Sun Shrine Stairs and Southeast Exit`.

### Map-Patch Guardrails Added

Safety follow-up on 2026-05-22 after repeated wrong-map paste mistakes:
- `test_map_reader.lua` now has map-specific directional assertion helpers,
  including `assert_tantegel_dir(...)`, so future live Tantegel blockers can be
  asserted without manually retyping the map id in every assertion.
- Recent Tantegel route blockers now also have focused "not Brecconary"
  absence assertions where those coordinates should not legitimately exist on
  map `0x08`.
- `test_map_reader.lua` includes a narrow lint test for
  `MAP_DIRECTIONAL_BLOCKS` comments that obviously mention the wrong map, such
  as Tantegel/Sun Shrine/throne-route comments inside Brecconary blocks or
  Brecconary comments inside Tantegel blocks.
- `AGENTS.md` now tells future agents to use those helpers and to add focused
  wrong-map absence checks only when the coordinate is not legitimately shared.

Validation passed:
- `luac5.1 -p test_map_reader.lua map_reader.lua`
- `lua5.1 test_map_reader.lua` (36 tests)
- `git diff --check`

### Edge Verifier Tightened For One-Way Latches

Follow-up on 2026-05-23 after the `(12,9)` / `(13,9)` row-9 latch behavior:
- `probe_edge_verify` no longer publishes per-attempt `verified_probe_move`
  seam observations. It records passable seam history only after the final
  verifier classification is cleanly `confirmed_passable`.
- If all requested attempts move, the verifier waits an extra stability window
  (`edge_verify_stability_recheck_frames`, default 240) and performs one more
  raw-hold attempt before reporting `confirmed_passable`.
- Moves through a currently modeled blocked approach are logged with
  `moved_model_mismatch` and classify as `suspect_passable_model_mismatch`
  instead of clean passable evidence. Treat these as manual-review candidates,
  not automatic map-data proof.
- Final `EDGE_VERIFY_RESULT` now includes `moved_model_mismatch`,
  `blocked_model_mismatch`, and `stability_recheck` fields.

### Tantegel Sun Shrine Stairs Corrected

Live FCEUX investigation on 2026-05-22 corrected the bad Tantegel Castle
treasure/Sun Shrine stair marker:
- The old object at `(29,1)` was reachable ordinary floor; using STAIRS there
  produced "There are no stairs here."
- ROM down-stair candidates for map `0x04` included `(14,2)` and `(29,29)`.
- `auto_walk:29,29` reached `(29,29)` cleanly, and selecting STAIRS from that
  tile produced `EVENT: map change -> 0x0C (Sun Shrine)`.
- The live landing was `map=0x0C(Sun Shrine) x=0 y=4`.

Code/data updates:
- `objects.lua` now exposes the Sun Shrine stair as
  `Stairs Down to Sun Shrine` at `(29,29)` instead of the stale `(29,1)`
  treasure-room marker.
- The Sun Shrine return/exit marker on map `0x0C` is now `Exit to World Map`
  at `(0,4)`, matching the live stair landing, instead of the stale `(4,4)`.
- The route-crossed damage pocket near the southwest Tantegel barrier now marks
  `(9,18)`, `(10,18)`, and `(11,18)` as `damage` hazards so pathfinding and
  auto-step avoid them without misreporting them as walls. `(11,19)` was later
  cleared by live HP-safe traversal.
- `test_objects.lua` rejects the stale `stair_29_1` object and requires
  `stair_29_29`, and also covers `exit_0_4`.
- `test_map_reader.lua` covers the expanded Tantegel damage hazard set.

Validation passed:
- `luac5.1 -p objects.lua map_reader.lua test_objects.lua test_map_reader.lua`
- `lua5.1 test_map_reader.lua` (35 tests)
- `lua5.1 test_objects.lua` (66 tests)

Current reload boundary:
- FCEUX needs a manual Lua reload before object navigation advertises the new
  `(29,29)` stair marker, the corrected Sun Shrine exit marker, and the new
  hazard avoidance data.
- Current live position after the stair proof was `map=0x0C(Sun Shrine) x=0
  y=4`.
- Follow-up log check live-disproved the other ROM map `0x04` down-stair
  candidate at `(14,2)`: STAIRS there produced "There are no stairs here."

### Tantegel 1F Door Locations Corrected

Live FCEUX investigation on 2026-05-22 found the two real locked doors on
Tantegel Castle `map=0x04`:
- West treasure-room door: stand at `(3,13)`, face east, OPEN records door RAM
  slot `(4,13)` and consumes one Magic Key.
- North/key-shop-area door: stand at `(18,5)`, face south, OPEN records door
  RAM slot `(18,6)` and consumes one Magic Key.
- The old y=6 "center door" band was disproved. OPEN returned
  "There is no door here" for the tested cells, and several y=6 cells allowed
  live movement without key consumption or door RAM writes.

Code/data updates:
- `MAP_DOOR_CELLS[0x04]` now contains only `(4,13)` and `(18,6)`.
- `(4,13)` was removed from `MAP_BLOCKED_CELLS[0x04]`; `(18,6).north` was
  removed from `MAP_DIRECTIONAL_BLOCKS[0x04]`.
- `objects.lua` now exposes `Treasure Room Door` and `Magic Key Area Door`
  instead of the bogus `Center Door`.

Validation passed:
- `luac5.1 -p map_reader.lua objects.lua test_map_reader.lua test_objects.lua debug_tools.lua`
- `lua5.1 test_map_reader.lua` (34 tests)
- `lua5.1 test_objects.lua` (64 tests)
- `git diff --check`

Current reload boundary:
- FCEUX still has the pre-patch Lua model loaded for any source changes below.
  Ask the player to reload `main.lua`, then verify that opened `(18,6)`
  remains traversable and that object browsing lists the two corrected doors.

### Tantegel Key-Merchant Route Cleanup

User play on 2026-05-22 found minor route hiccups around the unlocked chest
door and stair routes, but more trouble to/from the Magic Key Merchant. Log
review plus direct FCEUX verifiers split the suspects:
- Promoted `MAP_DIRECTIONAL_BLOCKS[0x04]["15,7"].east` after
  `probe_edge_verify:16,7,LEFT,5` blocked 5/5.
- Promoted `MAP_DIRECTIONAL_BLOCKS[0x04]["15,8"].east` after
  `probe_edge_verify:16,8,LEFT,5` blocked 5/5.
- Promoted `MAP_DIRECTIONAL_BLOCKS[0x04]["16,9"].north` after
  `probe_edge_verify:16,8,DOWN,5` blocked 5/5.
- Did not promote `(14,5).north`: `probe_edge_verify:14,4,DOWN,5` moved 5/5,
  so that earlier route hiccup was timing/noise, not map data.

Follow-up from the entrance route:
- Promoted the south approaches into `(20,6)`, `(21,6)`, `(22,6)`, and
  `(23,6)` after direct `probe_edge_verify` checks from row 7 each blocked
  5/5.
- Promoted `(24,2).south` and `(25,2).south` after direct counter-pocket
  verifiers from `(24,3)` and `(25,3)` blocked 5/5.
- Kept `(19,6).west` and `(19,6).south` open: after FCEUX input recovery,
  direct verifiers from `(18,6)` and `(19,7)` moved 5/5, and the successful
  route crossed `(19,6)` horizontally.
- The actual Magic Key Merchant stand is `(24,3)` facing north; `(24,2)` is
  the blocked counter/wall tile, not the route target.
- Live validation with the confirmed runtime blockers injected:
  `auto_walk:24,3` from the entrance `(11,28)` completed at `(24,3)`.

Validation passed:
- `luac5.1 -p map_reader.lua test_map_reader.lua`
- `lua5.1 test_map_reader.lua` (35 tests)
- `git diff --check`

Current live state:
- Last observed FCEUX position after the later route-loop investigation was
  `(28,17)` on Tantegel Castle `map=0x04`.
- The running FCEUX Lua script is stale versus source. Source already modeled
  `(27,16).east`, but live `inspect_move:28,16,LEFT` still reported it open.
  Ask the player to reload `main.lua` before judging any patched route below.

### Tantegel Sun Shrine / Throne Route Loop Cleanup

After the damage-hazard patch, the entrance-to-Sun-Shrine-stairs route and an
accidental throne-room-stairs route exposed more hidden Tantegel edges:
- Promoted `(14,5).north` and `(15,5).north` after the Sun Shrine route
  repeatedly failed entries from row 4.
- Promoted `(17,9).north`, `(18,9).north`, `(19,9).north`, `(20,9).north`,
  and `(21,9).north` after the Sun Shrine route repeatedly failed entries
  from row 8. The first four route blockers were found from route logs; the
  `(17,9)`, `(18,9)`, and `(19,9)` follow-ups were direct
  `probe_edge_verify` checks that each blocked 5/5.
- Promoted `(27,17).east` and `(27,20).east` from the accidental throne-room
  route; `(27,16).east` was already modeled in source and helped prove the
  live FCEUX script was stale. A post-reload check found those two new entries
  were initially misplaced in the Brecconary `0x08` block; they have been
  moved into Tantegel `0x04`.
- Did not promote retry-success/noisy observations around `(11,27)`,
  `(12,24)`, `(16,4)`, or horizontal movement around `(20,8)/(21,8)`.
- Live route status after runtime injection:
  - From `(28,16)`, `auto_walk:29,29` reached the Sun Shrine stairs cleanly.
  - From the entrance `(11,28)`, the route no longer loops but reports no path
    once the verified row-9 north-wall band is blocked.
  - Bracketing checks showed `(22,8)`, `(23,8)`, and `(24,8)` are wall tiles,
    so the east-wing detour cannot bridge around the row-9 wall band.
  - Superseded by the 2026-05-23 route proof above: the old row-16 route is
    invalid after `(15,16).west` was confirmed blocked, but the throne-side
    route reaches `(29,29)` via the reopened row-9 bridge. Treat the older "no
    safe route" interpretation as historical partial bracketing only.

Validation passed:
- `luac5.1 -p objects.lua map_reader.lua test_objects.lua test_map_reader.lua`
- `lua5.1 test_map_reader.lua` (35 tests)
- `lua5.1 test_objects.lua` (66 tests)
- `git diff --check`

Current reload boundary:
- FCEUX has runtime overlays for the post-reload edits in the current session:
  `(17,9).north`, `(18,9).north`, `(19,9).north`, `(27,17).east`, and
  `(27,20).east`.
- A future manual `main.lua` reload will clear those runtime overlays and load
  the same data permanently from `map_reader.lua`.
- After reload, a focused read-only check should show `approach_blocked=true`
  for `inspect_move:14,4,DOWN`, `inspect_move:15,4,DOWN`,
  `inspect_move:17,8,DOWN`, `inspect_move:18,8,DOWN`,
  `inspect_move:19,8,DOWN`, `inspect_move:20,8,DOWN`,
  `inspect_move:21,8,DOWN`, `inspect_move:28,17,LEFT`, and
  `inspect_move:28,20,LEFT`.

### Tantegel `4,11-4,15` Evidence Conflict Resolved

Open review item resolved on 2026-05-22:
- Live FCEUX recheck on map `0x04` kept most of the strip full-blocked:
  `(3,11..15)->RIGHT`, `(5,12..15)->LEFT`, and `(4,16)->UP` all verified
  blocked 5/5; `(5,11)->LEFT` repeated as blocked 10/10.
- `(4,10)->DOWN` into `(4,11)` stayed mixed and should not become a
  directional blocker by itself. A follow-up single probe blocked, and
  forced-origin checks from `(4,11)` could not move back out or continue down.
- The later door investigation split out `(4,13)` as the west treasure-room
  Magic Key door. `map_reader.lua` now keeps full blocks for `(4,11)`,
  `(4,12)`, `(4,14)`, and `(4,15)` while modeling `(4,13)` in
  `MAP_DOOR_CELLS[0x04]`.
- Validation: `luac5.1 -p map_reader.lua test_map_reader.lua`,
  `lua5.1 test_map_reader.lua`, and `git diff --check` passed.

### Tantegel West-Pocket Continuation

- Fresh 2026-05-24 continuation after FCEUX recovered from the menu/input
  lock kept the west-pocket route productive instead of collapsing it.
- Clean permanent one-way seam promotions from direct verifier plus reverse
  natural movement:
  - `(20,14)->RIGHT` blocked `5/5`, while forced `(21,14)->LEFT` moved back
    through; `MAP_DIRECTIONAL_BLOCKS[0x04]["21,14"].west = true`.
  - `(20,15)->RIGHT` blocked `5/5`, while forced `(21,15)->LEFT` moved back
    through; `MAP_DIRECTIONAL_BLOCKS[0x04]["21,15"].west = true`.
  - `(19,14)->LEFT` blocked `5/5`, while forced `(18,14)->RIGHT` moved back
    through and settled east; `MAP_DIRECTIONAL_BLOCKS[0x04]["18,14"].east = true`.
- Do not promote `(18,14).north` yet:
  - `probe_edge_verify:18,13,DOWN,5` was mixed (`moved=1 blocked=4`), so that
    face still looks stateful / route-context-sensitive.
- Runtime continuation with the new west-pocket helpers mirrored remained
  healthy:
  - hazards-allowed planning from `(20,14)` still found a detour,
  - short autowalk continuation reached `(25,12)` before manual stop.
- Fresh same-day reload continuation shifted that frontier again:
  - `probe_edge_verify:18,14,DOWN,5` moved on all five main attempts.
  - The stability recheck hit the verifier's bogus upper-window interruption,
    so the final classification was not clean, but this is still strong open
    evidence for `(18,14)->(18,15)`.
  - Current-position `probe_edge:DOWN` from live `(18,14)` still blocked
    twice, so this seam is stateful/start-state-sensitive rather than a clean
    permanent wall.
  - Current-position `probe_edge:LEFT` from live `(19,15)` also moved through
    and settled at `(17,15)`, so the older runtime-only `(18,15).east` helper
    did not stay durable on this reload.
  - From that reopened west branch, `debug_pathfind_to_allow_hazards:29,29`
    found `5 south, 3 east, 2 south, 9 east, 7 south`, and short autowalk
    progressed cleanly to `(20,22)`.
  - The new live bottleneck is the east bridge into the southeast pocket:
    - current-position `probe_edge:RIGHT` from live `(20,22)` blocked,
    - forced `(21,22)->LEFT` moved back through and settled at `(19,22)`,
    - `probe_edge_verify:20,22,RIGHT,5` is mixed (`moved=1 blocked=4`),
    - forced `(21,22)` still has a clean remainder route: `8 east, 7 south`.
  - Forced `(20,21)->RIGHT` into `(21,21)` blocks, and `(21,21)` is
    permanently blocked, so `(20,22)->RIGHT` is currently the only known
    west-side bridge into the working southeast route.
  - Follow-up after a fresh reload plus user manual run-up tightened the call:
    - manual right attempts at `(20,22)` again showed movement starting and
      then canceling in the early-twitch wait,
    - current-position `probe_edge:RIGHT` from live `(20,22)` blocked again,
    - forced `(21,22)->LEFT` still moved back through and settled west,
    - runtime `add_blocked_edge:20,22,RIGHT` collapsed west-side
      hazards-allowed planning from `(17,15)` to `No path found`.
  - Permanent promotion applied:
    `MAP_DIRECTIONAL_BLOCKS[0x04]["21,22"].west = true`.
  - Caveat: the teleported verifier stayed mixed (`moved=1 blocked=4`), so
    treat this as a stateful one-way seam whose permanent promotion was driven
    by stronger natural/manual/runtime-route evidence than by the forced
    repeated-start verifier alone.

### Map Crawler Review + Hardening

Detailed handoff: `HANDOFF_2026-05-22_map_crawler_review.md`

Commit: `9076d3a Harden map crawler and add per-map export file`

Accepted review outcome:
- Keep the commit.
- `auto_step_lost` orphan-step detection is the right crawler-local fix.
- Failed backtracks now classify as `backtrack_blocked` diagnostic evidence and
  no longer pollute directional candidates.
- `crawl_map_frontier` now refuses to start outside field state or while menus
  or dialogue are active.
- Every crawler finish writes `dw_crawl_<mapid_hex>.txt` next to
  `dw_debug.log` with Lua-snippet candidates for review.
- Finish speech now emits exactly one summary message.

Validation already run:
- `lua5.1 test_map_crawler.lua` passed: 32 tests.
- `luac5.1 -p map_crawler.lua main.lua test_map_crawler.lua` passed.
- `git diff --check HEAD~1..HEAD` passed.
- `python3 run_tests.py --allow-missing-speech-dep` passed with only the known
  WSL speech dependency warning for missing `accessible_output2`.

Optional follow-ups once the emulator is running:
- Live smoke test: run a tiny `crawl_map_frontier` with a low `max_edges`, stop
  it, then confirm `MAP_CRAWL_EXPORT_FILE` and the generated
  `dw_crawl_*.txt`.
- Harden export writes around `file:write` / `file:close`, not just `io.open`.
- Make `test_map_crawler.lua` restore global `io.open` through a per-test
  cleanup wrapper even when an assertion fails.

## Current Gameplay State

- Rimuldar is clean enough to leave for now.
- Rimuldar player-facing services and important routes had passed the latest
  route sweep before the handoff cleanup:
  - Weapons Merchant
  - Inn
  - Magic Key Merchant
  - Chest
  - Exit routes
- Do not continue broad Rimuldar blocker harvesting unless normal gameplay
  exposes a fresh failure.
- Next route/map work should move to another town, cave, or gameplay target.

## Open Review Items

- Decide whether overworld route waypoint validation needs a real overworld
  passability source before changing radius-0 behavior.

## Documentation Cleanup Notes

- Canonical current docs are:
  - `AGENTS.md`
  - `session_handoff.md`
  - `PROJECT_MEMORY.md`
  - `PLAYTESTING.md`
  - `debug_hooks.txt`
- `handoff_archive/` is historical evidence only. Do not read the whole archive
  by default.
- Assistant-local memories and `.claude/agent-memory/` are subordinate to repo
  docs when they disagree.
- Review packets for Claude should point to the current diff, focused tests,
  and this handoff instead of expecting Claude to reconstruct context from
  old archive files.

## Best Next Steps

1. Reproduce the mixed bridge at `(20,22)->RIGHT` from a clean reload and keep
   testing for a reliable execution recipe or a cleaner one-way verdict.
2. Treat `(21,22).west` as runtime-investigation territory only for now; do not
   promote permanent map data unless the mixed `1 moved / 4 blocked` shape
   resolves.
3. Once this southeast bridge behavior is understood, return to player-facing
   QoL or the next normal gameplay pass under FCEUX unless the task
   specifically needs BizHawk automation/debug behavior.
