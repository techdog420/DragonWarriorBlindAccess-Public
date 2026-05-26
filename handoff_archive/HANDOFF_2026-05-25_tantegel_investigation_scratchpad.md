## Findings

### TANTEGEL KEY MERCHANT TO EXIT CHURN / BRIDGE RELEASE FIX - 2026-05-25

- User reported `Magic Key Merchant` to entrance/exit was churning during
  route validation.
- Log analysis before stopping autowalk:
  - route started from `(24,3)` to `Exit to World Map` `(11,29)`
  - NPC parking was correct:
    `AUTO_WALK_NPC_PARK_START map=0x04 parked_slots=4`
  - no `AUTO_WALK_NPC_BLOCK` occurred and final `RUNTIME_BLOCKS` were empty
  - the route accumulated route-local temp blocks and repeatedly hit the
    row-15/16 barrier
- Clean post-restore verifier evidence:
  - `probe_edge_verify:16,15,DOWN,5`:
    `moved=0 blocked=5 interrupted=0 classification=confirmed_blocked`
  - `probe_edge_verify:17,15,DOWN,5`:
    `moved=0 blocked=5 interrupted=0 classification=confirmed_blocked`
  - Both contradicted the previous model, which kept the north approaches into
    passthrough cells `(16,16)` and `(17,16)` open.
- Permanent model patch:
  - `MAP_DIRECTIONAL_BLOCKS[0x04]["16,16"].north = true`
  - `MAP_DIRECTIONAL_BLOCKS[0x04]["17,16"].north = true`
  - Cells remain standable via `MAP_PASSTHROUGH_CELLS`; only the north entries
    from row 15 are closed.
- Contaminated/suspect evidence not promoted:
  - pre-restore `18,13->DOWN` and mixed `25,9->LEFT` results
  - post-verifier softlock/control symptoms after the `17,15->DOWN` check
- Softlock/control investigation:
  - Lua kept polling and the state snapshot stayed coherent:
    `state=field`, `map=0x04`, `pos=(17,15)`, movement RAM idle
  - after the verifier, bridge inputs were logged as applied but the game did
    not visibly respond
  - a later `clear_input` neutral pulse cleared `keys=- joy1=- bridge=-` and
    controls resumed strongly enough for a selected-object teleport to fire,
    supporting the stale scripted-input theory
  - likely instrumentation bug: external bridge clear paths logged
    `INPUT_EXTERNAL_BRIDGE_CLEAR` but returned no neutral `joypad.set` frame,
    leaving FCEUX vulnerable to stale scripted button state
- Tooling patch:
  - `debug_tools.lua` now emits one raw neutral joypad frame when the internal
    or external keyboard bridge transitions from active to clear
  - regression coverage proves stale-Alt and focus-recovery bridge releases
    produce exactly one neutral raw frame
- Verification:
  - `luac5.1 -p debug_tools.lua test_debug_tools.lua map_reader.lua test_map_reader.lua`
  - `lua5.1 test_debug_tools.lua` passed 8 tests
  - `lua5.1 test_map_reader.lua` passed 37 tests
  - `lua5.1 test_route_manager.lua` passed 90 tests
  - `git diff --check -- debug_tools.lua test_debug_tools.lua map_reader.lua test_map_reader.lua`
- Live validation after reload:
  - user reported the Magic Key Merchant to entrance route is noisy but working
    again
  - log confirms completion at `Exit to World Map` `(11,29)`:
    `AUTO_WALK_NPC_PARK_RESTORE ... restored=true restored_slots=5`
  - readback at frame `12240` confirmed:
    `POSITION ... x=11 y=29`,
    `PATH_STATE target=nil map=0x04 runtime_count=0`,
    and `RUNTIME_BLOCKS map=0x04 none`
  - noise remained route-local: temp reroutes around `(23,9).north`,
    `(24,9).east`, `(18,14).north`, `(18,15).west`, `(24,10).east`,
    `(25,6).south`, `(17,6).south`, and `(15,5).east`; do not promote these
    without clean post-reload verifier evidence

### TANTEGEL SHRINE FINAL APPROACH / HIGH X=29 EXIT-LATCH GUARD - 2026-05-25

- User manually validated both shrine routes out-and-back after the final
  settle patch:
  - one throne-stairs-to-shrine route walked out of town
  - two later shrine routes, including a second throne-room attempt, stopped on
    the correct `(29,29)` tile
- Log analysis:
  - the bad run drift-rerouted at frame `6375` from `(29,3)` and planned
    `Path: 26 south` to `Sun Shrine Stairs and Southeast Exit`
  - from `(29,4)` through `(29,29)` the route completed each south step in
    `12` frames with no ordinary `movement started` logging
  - final settle began at `(29,29)` with
    `AUTO_STEP_MOVEMENT_STATE_RESET ... before_move=0x00 before_sub=0x00`
  - the map changed to World Map 15 frames later, before route-complete
    cleanup ran
  - clean later routes either reached the lower x=29 lane after a fresh turn
    near row 7/22 and logged normal `27`/`28` frame south steps, or reset final
    arrival from `before_move=0x05`
- Interpretation:
  - `(29,29)` and the x=29 lane remain real/open; this is not a permanent
    map blocker.
  - the failure shape is a high x=29 "fast descent" / delayed transition latch
    reached by drift from the top-right route, not ordinary final held-input
    overrun.
- Patch:
  - `route_manager.lua` now detects autowalk execution plans to map `0x04`
    goal `(29,29)` whose final suffix is a long south descent on x=29 starting
    at y <= 7.
  - For those plans only, it retries planning with a temporary planning-only
    directional block on the first risky x=29 south entry (for the observed
    repro, `(29,4).north`).
  - If the replacement path avoids the risky suffix, it queues the replacement
    and logs `AUTO_WALK_FINAL_APPROACH_AVOID`.
  - The lower x=29 descent remains available; no permanent map data changed.
- Regression coverage:
  - `tantegel_shrine_autowalk_avoids_high_x29_final_descent`
  - `tantegel_shrine_lower_x29_descent_stays_available`
  - `tantegel_shrine_drift_reroute_avoids_high_x29_final_descent`
- Verification:
  - `luac5.1 -p route_manager.lua test_route_manager.lua`
  - `lua5.1 test_route_manager.lua` passed 90 tests
  - `git diff --check -- route_manager.lua test_route_manager.lua`
- Live validation after FCEUX Lua reload:
  - user ran the throne-stairs-to-shrine route and the hero stayed in town
  - the old bad repro recurred at frame `6404` from `(29,3)`, but the new guard
    logged:
    `AUTO_WALK_FINAL_APPROACH_AVOID ... context=route_drift_reroute ...
    blocked_dest=(29,4) ... old_path_len=26 new_path_len=28`
  - the replacement route changed the unsafe `26 south` descent into
    `1 west, 4 south, 1 east, 22 south`
  - final route settle at frame `7380` reached `(29,29)` with
    `before_move=0x05 before_sub=0x00`
  - fresh report at frame `10800` confirmed:
    `POSITION ... map=0x04(Tantegel Castle) x=29 y=29`,
    `PATH_STATE target=nil map=0x04 runtime_count=0`,
    and `RUNTIME_BLOCKS map=0x04 none`
  - no map-change event occurred after arrival; stale `LeftAlt` only
  - route remains noisy in the northeast/top approach with several route-local
    timing temp blocks, but none persisted as runtime blockers

### FINAL TANTEGEL OBJECT-LIST CLEANUP - 2026-05-25

- User requested two final map-cleanup tasks:
  - add the throne-room King to Services because players visit him to save
  - reduce Travel filter spam by combining map `0x04` Sun Shrine stairs and the
    southeast exit into one object
- Patch:
  - map `0x05` King is now service-tagged via `SERVICE_ROLE_OVERRIDES` but uses
    ordinary adjacent-NPC routing
  - map `0x04` no longer emits `exit_29_29`; the shared tile is represented by
    `stair_29_29` named `Sun Shrine Stairs and Southeast Exit`
- Regression coverage:
  - `tantegel_throne_room_king_appears_in_services`
  - `tantegel_castle_southeast_corner_combines_shrine_stairs_and_exit`
- Verification:
  - `luac5.1 -p objects.lua test_objects.lua`
  - `lua5.1 test_objects.lua` passed 68 tests

### FCEUX MOVEMENT CONTROL LOCK / KEYBOARD BRIDGE SIDECAR - 2026-05-25

- User reported movement controls had locked again immediately after the
  latest live route testing.
- Fresh probe:
  - command polling was alive:
    `LAUNCHER_PROBE: codex_input_lock_probe`
  - `PATH_STATE target=nil map=0x05 runtime_count=0`
  - player was in the throne room at `(8,8)`
  - live input showed the stale FCEUX Alt latch:
    `INPUT_STATUS tag=manual keys=LeftAlt joy1=- left_alt=true`
- Recovery:
  - running `./recover_fceux_input.sh` cleared the latch:
    `INPUT_STATUS tag=after_recovery_probe keys=- joy1=- left_alt=false`
  - process inspection found no persistent `keyboard_bridge.ps1` sidecar; the
    only match was the process-check command itself.
- Interpretation:
  - This was not an autowalk/NPC parking/map blocker issue. Lua was alive, no
    route was active, and runtime blockers were empty.
  - Because the launcher disables FCEUX native keyboard gamepad input and relies
    on `keyboard_bridge.ps1`, a missing bridge sidecar can make manual movement
    feel locked even after the stale Alt state is cleared.
- Patch:
  - `recover_fceux_input.ps1` now restarts `keyboard_bridge.ps1` for the current
    `dw_keyboard_input.txt` if the sidecar is missing.
  - `input_status` now includes the bridge-file state after the next Lua reload:
    `bridge=-`, `bridge=up`, `bridge=(missing)`, etc.
- Live follow-up:
  - patched recovery started `keyboard_bridge.ps1` PID `9060`.
  - a later live log showed the restarted sidecar feeding manual input:
    `INPUT_EXTERNAL_BRIDGE_APPLY ... native_joy1=up bridge=up`.
  - current loaded Lua had not yet been reloaded, so the live
    `input_status:bridge_after_patch` line still used the old format; reload
    Lua before expecting the new `bridge=` field.

### TANTEGEL SAGE-TO-STAIRS TRANSIENT NO-PATH / PENDING NPC RESTORE - 2026-05-25

- User manually validated the planned travel/service routes and reported one
  transient route-generation failure after a teleport/route sequence. The log
  identifies it as:
  - start `(18,26)` near Sage
  - target `Stairs Up to Tantegel Castle Throne Room` at `(7,7)`
  - first autowalk attempt at frame `12681`
  - second attempt at frame `13022`
- First attempt evidence:
  - previous Sage route completed and started an NPC target hold:
    `NPC target hold started: target=Sage slot=17 frames=1200 at=(20,26)`
  - one parked NPC could not be restored because the hero occupied its original
    tile: repeated `AUTO_WALK_NPC_PARK_RESTORE ... deferred_slots=1`
  - the new autowalk released the target hold, then logged:
    `AUTO_WALK_NPC_PARK_START skipped: pending restore still active`
  - the route snapshot used `npc_mode=park_mobile_npcs` but only
    `parked_slots=1` and `npc_blocks=17`, then failed with
    `reason=goal_blocked_npc`
- Interpretation:
  - This was not static map geometry and not just route-settle drift.
  - The planner was briefly seeing mostly live NPC blockers because a pending
    deferred restore prevented the fresh mobile-NPC parking pass.
  - The second attempt succeeded once the live NPC situation changed enough,
    which matches the user's observation that retrying worked.
- Patch:
  - `start_autowalk_npc_parking` now merges pending deferred-restore slots into
    a fresh parking state, then parks the rest of the mobile non-target NPCs
    normally before planning.
  - New log marker: `AUTO_WALK_NPC_PARK_START merged_pending_restore slots=N`.
  - Regression test:
    `autowalk_parking_merges_pending_deferred_restore_with_new_mobile_parking`.
- Verification:
  - `luac5.1 -p route_manager.lua test_route_manager.lua`
  - `lua5.1 test_route_manager.lua` passed 81 tests
  - `git diff --check -- route_manager.lua test_route_manager.lua`

### TANTEGEL SOUTH GATE / MAGIC KEY MERCHANT ROUTE REOPENED - 2026-05-25

- User reported that the pre-existing route to the Magic Key Merchant vanished
  after the latest route changes.
- Fresh baseline:
  - `POSITION: map=0x04(Tantegel Castle) x=14 y=29`
  - `DOOR_STATE keys=6 slots=0=(4,13) 1=(18,6)`
  - `RUNTIME_BLOCKS map=0x04 none`
- Before the patch, pathfinding from `(14,29)` to the merchant stand `(24,3)`
  failed even with NPCs skipped and hazards allowed:
  - `Debug pathfind_to skip NPCs allow hazards (24,3): No path found`
  - `ROUTE_FRONTIER` showed the start component had only 8 cells.
  - Rank 1 frontier bridge was `(12,29)->LEFT` into tile-0 `(11,29)`, with
    `hidden_exit=up:(11,28)`.
- Live evidence:
  - `inspect_move:12,29,LEFT` showed `(11,29)` was model-blocked only because
    tile 0 decoded as non-walkable.
  - A short `auto_walk:12,29` from `(14,29)` completed the modeled route and
    then the live engine settled the hero on `(11,29)`, proving the exit cell
    is standable despite the decoder.
  - From live `(11,29)`, pathfinding to `(24,3)` immediately succeeded through
    `(11,28)` and the old Magic Key route.
- Patch:
  - Added `MAP_PASSTHROUGH_CELLS[0x04]["11,29"] = true`.
  - Added `test_map_reader.lua` coverage asserting `(11,29)` is a passthrough
    and appears in the walkability snapshot.
- Live validation after `reload_navigation_modules`:
  - From restored `(14,29)`, `debug_pathfind_to_skip_npcs:24,3` found
    `Path: 3 west, 7 north, 1 east, 2 north, 1 east, 6 north, 1 west, 5 north, 12 east, 6 north`.
  - `debug_pathfind_adjacent_skip_npcs:18,6` also found a path to the open
    Magic Key Area Door.
  - `auto_walk:24,3` from `(14,29)` completed at `(24,3)`.
  - Runtime blocks remained empty.
- Executor note:
  - The live route still drift-recovered after the new bridge:
    `(11,29)` settled west to `(10,29)`, then later `(10,22)` settled to
    `(10,21)` before a seam retry recovered.
  - Because the route completed cleanly and no runtime blocks were added, treat
    this as executor/settle noise to watch, not as blocker evidence.

### TANTEGEL X=29 LANE TIMING BRACKET / HALF-OPEN 29,21 FAMILY - 2026-05-24

- Fresh post-restore shelf investigation focused on what makes
  `(29,21)->LEFT` reproducibly open or blocked.
- Direct teleported idle `(29,21)` remains the blocked family:
  - `probe_edge:LEFT` from teleported `(29,21)` blocked 5/5 shape with:
    - `move=0x10 sub=0x10`
    - `scroll_x=0xC0`
    - `scroll_y=0xE0`
    - `... D7 FF 50 01 08 14 ...`
- Raw lane entry from below exposed a much sharper timing window than the
  earlier coarse probe-based tests:
  - from forced `(29,20)`, raw `DOWN,24` settled at `(29,21)`, but immediate
    `LEFT` still blocked
  - from forced `(29,20)`, raw `DOWN,25` settled at `(29,21)` and immediate
    `LEFT` moved to `(28,21)`
  - from forced `(29,20)`, raw `DOWN,26` no longer settled at `(29,21)`; it
    overshot to `(29,22)`
- So the x=29 lane has at least three neighboring arrival families:
  - `DOWN,24` -> blocked `(29,21)`
  - `DOWN,25` -> half-open `(29,21)` where `LEFT` reaches `(28,21)`
  - `DOWN,26+` -> misses `(29,21)` entirely and settles at `(29,22)`
- The `DOWN,25` family is not the same as the older fully open east-seeded
  shelf:
  - immediate `LEFT` from the landed `(29,21)` state reached only `(28,21)`,
    not `(27,21)`
  - immediate second `LEFT` from `(28,21)` then blocked into `(27,21)`
  - after a short wait, that same `DOWN,25` family cooled into a different
    `(29,21)` settled signature:
    - `scroll_x=0xB0`
    - `scroll_y=0x60`
    - `... 10 10 E7 FF D0 01 D8 05 ...`
  - and from that cooled state, `LEFT` blocked again
- Current interpretation:
  - `(29,21)->LEFT` is not just open or closed; it has at least:
    - blocked idle teleported family
    - half-open one-step family from raw `DOWN,25`
    - earlier fully open family that carried all the way to `(27,21)`
  - the timing edge between `DOWN,24` and `DOWN,25` is especially strong
    evidence that x=29 lane entry is governed by a precise hidden movement
    state, not static geometry

### TANTEGEL ROW-21 BLOCKER CLEANUP / EAST-LANE ROUTE VALIDATION - 2026-05-24

- Fresh restored shelf pass from live `(27,21)` exposed two missing permanent
  blockers around the row-21 throat:
  - direct current-position `probe_edge:DOWN` from `(27,21)` into `(27,22)`
    blocked cleanly with `reason=raw_hold_timeout`
  - direct current-position `probe_edge:UP` from `(27,21)` into `(27,20)`
    also blocked cleanly with `reason=raw_hold_timeout`
- Permanent promotions from those direct probes:
  - `(27,22).north = true`
  - `(27,20).south = true`
- Effect on live reroutes after `reload_navigation_modules`:
  - before the promotions, after `(27,21)->RIGHT` failed, autowalk kept
    hallucinating fake reroutes through:
    - `(27,21)->DOWN`
    - then later `(27,21)->UP`
  - after both promotions are live, the west-side shelf is much more honest:
    - base planner from `(27,21)` still proposes `2 east, 8 south`
      because the east-seeded route exists in some states
    - but once the first east step `(27,21)->RIGHT` fails from the restored
      west-side family, the reroute now collapses to `No path found` instead
      of inventing fake north/south escapes
- This is the behavior we wanted from blocker cleanup:
  - the west-side shelf no longer burns time on disproved row-20/row-22 detours
  - the remaining problem from restored `(27,21)` is now cleanly isolated to
    the stateful east shelf itself
- East-side validation still sings:
  - forced `(29,21)` with hazards allowed still plans `8 south`
  - live `auto_walk:29,29` from `(29,21)` completed successfully:
    - first `(29,21)->DOWN` looked noisy and triggered one seam brute-force retry
    - follow-up from `(29,22)` replanned `7 south`
    - auto-walk then completed down the x=29 lane to `(29,29)` and stepped out
      to the World Map at `(43,43)`
  - the x=29 descent cells `(29,23)` through `(29,29)` all logged as moved
    / passable in seam observations during that run
- One unresolved same-session wrinkle:
  - a fresh direct teleported `(29,21)->LEFT` later blocked instead of seeding
    `(27,21)` again
  - so the east-lane entry itself is also stateful; teleported idle `(29,21)`
    is not guaranteed to reproduce the same leftward carry as the earlier
    live-arrival family

### TANTEGEL ROW-21 EAST-LANE SEED / RIGHTWARD UNLOCK RETEST - 2026-05-24

- Follow-up hypothesis tested: maybe the row-21 shelf opens only after the
  engine carries through a specific predecessor cell rather than from ordinary
  west/north/south arrivals.
- North-entry check did not unlock the seam:
  - forced `(26,20)` was a clean neutral-ish baseline with `move=0x00`
  - `probe_edge:DOWN` settled at `(26,21)`
  - landed state at `(26,21)` was new but still ordinary:
    - `move=0x10 sub=0x90`
    - `scroll_y=0x00`
  - immediate `probe_edge:RIGHT` from that state still blocked into `(27,21)`
- South-entry check also failed to unlock the seam directly:
  - forced `(26,22)->UP` did not settle at `(26,21)`; it carried through to
    `(26,20)`
  - immediate `probe_edge:RIGHT` from that `(26,20)` state still blocked into
    `(27,20)`
  - cycling back down `(26,20)->DOWN` then settling at `(26,21)` produced a
    fresh row-21 arrival family:
    - `move=0x30 sub=0x90`
  - immediate `probe_edge:RIGHT` from that `0x30` branch still blocked into
    `(27,21)`
- East-lane entry finally produced the first clean "unlock" behavior:
  - forced `(29,21)->LEFT` settled at `(27,21)`, not `(28,21)`
  - the landed `(27,21)` state was from a distinctly east-seeded family:
    - first capture: `move=0x50 sub=0x90`, `scroll_x=0x90`,
      `overworld=(31,55)`
    - second capture after another clean east-entry pass:
      `move=0x10 sub=0x90`, same `scroll_x=0x90` east-shelf family
  - immediate `probe_edge:RIGHT` from that east-entered `(27,21)` state
    carried cleanly back to `(29,21)`
  - this is not just a one-frame blip:
    - after a short idle/report window, `report_movement_state:wait1` at
      `(27,21)` had cooled to `move=0x08 sub=0x90`
    - even after that wait, a fresh `probe_edge:RIGHT` still carried cleanly
      back to `(29,21)`
- Carry shape from the east-seeded shelf:
  - `29,21->LEFT` settle traces show a long conveyor phase at `(28,21)` using
    `move=0x50`
  - `27,21->RIGHT` settle traces show the reverse conveyor through `(28,21)`
    and a final settle at `(29,21)`
- Current interpretation:
  - yes, a path-opening condition appears to exist
  - ordinary west-side, north-side, and south-side arrivals do not satisfy it
  - entering `(27,21)` from the east lane does satisfy it, and the unlocked
    rightward carry survives at least a short cooldown/report interval
  - the row-21 mystery now looks like a directional conveyor state seeded by
    east-lane entry rather than a generic hidden wall

### TANTEGEL ROW-21 RESTORED REJECTION FAMILY / ASYMMETRIC LEFT-CARRY RETEST - 2026-05-24

- Fresh user-restored save state came back directly on the suspicious shelf:
  - `POSITION: map=0x04(Tantegel Castle) x=27 y=21`
  - upper dialogue inactive, menu closed
- The restored state is not a plain idle baseline:
  - `report_movement_state:restored` showed raw row-21 bytes in a different
    family than the earlier carry-friendly reloads:
    - `player=(27,21)`
    - `ram0030_004F ... 00 08 1B 15 10 10 D7 FF 50 01 08 14 ...`
  - direct `probe_edge:RIGHT` from that restored baseline started at
    `move=0x10 sub=0x10` and cleanly blocked in place
  - it settled into the older rejection family rather than a carry:
    - final `player=(27,21)`
    - `overworld=(30,7)`
    - `move=0x0F sub=0x90`
    - `EDGE_PROBE_MODEL_MISMATCH kind=blocked_despite_open_preview`
- That means the save restore preserved a third useful row-21 branch:
  - earlier carry-friendly reloads started around `0x07/0x08`
  - older blocked branch started around `0x0F`
  - this restore starts even earlier in a harsher-looking `0x10/0x10` family
    that immediately collapses into the `0x0F` blocked branch on east input
- Leftward behavior from this poisoned restore is asymmetric rather than fully
  dead:
  - from the post-blocked `(27,21)` state, `probe_edge:LEFT` still carried and
    settled at `(25,21)`
  - start state there was already the `0x0F/0x90` family
  - the settle trace again showed the familiar conveyor phase at `(26,21)` with
    repeated `move=0x05`
- But the return leg changed shape compared with the earlier seeded-carry runs:
  - immediate `probe_edge:RIGHT` from the landed `(25,21)` state no longer
    carried back to `(27,21)`
  - instead it only settled at `(26,21)`
  - `report_movement_state:pre_return_right` from `(25,21)` showed a new
    intermediate family:
    - `move=0x0B sub=0x90`
  - the settle trace into `(26,21)` later passed through `0x50`, `0x0F`,
    and even a brief `0x82`, before stabilizing back at `0x0B`
- Final confirmation from that branch:
  - immediate `probe_edge:RIGHT` from `(26,21)` then blocked cleanly into
    `(27,21)`
  - this was ordinary model-backed row-21 refusal:
    - `directional_blocked=true`
    - `blocked_approach=west`
    - `effective_passable=false`
- Current interpretation:
  - the user-restored state preserved a real east-rejection family on row 21
  - leftward carry out of `(27,21)` still works from that family
  - but the old seeded return carry `(25,21)->(27,21)` did not survive this
    restore; it degraded into a one-step move `(25,21)->(26,21)`
  - the row-21 anomaly is now best described as a small state machine, not
    just "carry or block"

### TANTEGEL ROW-21 WEST-ENTRY RETEST / REPEATABLE SEEDED CARRY - 2026-05-24

- Fresh live baseline after reload landed at `(26,21)`, then manual evidence
  from the user suggested:
  - `(24,21)->RIGHT` into `(25,21)` feels open
  - eastward continuation from `(25,21)` feels blocked
- Live log and follow-up probes refined that into a cleaner split:
  - manual `LEFT` from `(25,21)` completed cleanly to `(24,21)`
  - manual `RIGHT` from `(25,21)` only twitched and canceled in one pass
  - direct `probe_edge:RIGHT` from live `(24,21)` moved and settled at
    `(25,21)`
  - direct `probe_edge:RIGHT` from that live `(25,21)` moved and settled at
    `(26,21)`
  - direct `probe_edge:RIGHT` from live `(26,21)` then blocked cleanly:
    `directional_blocked=true`, `blocked_approach=west`,
    `approach_blocked=true`, `effective_passable=false`
- So the ordinary settled row-21 story is now:
  - `(24,21)->RIGHT` open
  - `(25,21)->RIGHT` open into `(26,21)`
  - `(26,21)->RIGHT` blocked into `(27,21)`
- But the old carry weirdness is also real and now repeatable:
  - forced `(27,21)->LEFT` again settled all the way back at `(25,21)`
  - immediately after that reverse move, `probe_edge:RIGHT` from `(25,21)`
    again carried and settled at `(27,21)` in one step
  - a fresh `probe_edge:RIGHT` from that landed `(27,21)` state still blocked
    into `(28,21)`
- Interpretation:
  - the remaining row-21 bridge behavior is genuinely stateful
  - it is not a simple static open edge at `(26,21)->(27,21)`
  - the repeatable pattern is:
    1. start at `(27,21)`
    2. move left and settle at `(25,21)`
    3. immediate `probe_edge:RIGHT` carries back to `(27,21)`
    4. another `RIGHT` from `(27,21)` blocks
  - this is the strongest current evidence that any surviving bridge depends on
    a carry/state mechanism rather than ordinary planner geometry

### TANTEGEL X=27/X=28 HANDOFF COLLAPSE AND ROW-21 CARRY RETEST - 2026-05-24

- Fresh live baseline after restore/reload returned to normal castle start:
  - `POSITION: map=0x04(Tantegel Castle) x=26 y=5`
  - no runtime blocks
- True-start reachability after the latest east-pocket cleanup:
  - reachable with hazards:
    - `(23,21)`
    - `(24,21)`
    - `(25,21)`
  - not reachable:
    - `(23,22)`
    - `(24,22)`
    - `(25,22)` (`goal_blocked`)
    - `(26,23)`
    - `(29,29)`
- Forced frontier bracket around the upper east shelf:
  - `(27,21)` still has planner remainder `2 east, 8 south`
  - `(27,22)` still has planner remainder `2 east, 7 south`
  - `(28,22)` still has planner remainder `1 east, 7 south`
  - forced `(27,23)` originally still had a planner remainder
    `1 east, 1 north, 1 east, 7 south`
- Clean verifier promotions this pass:
  - `probe_edge_verify:27,23,RIGHT,5` -> `confirmed_blocked`, `blocked=5`
  - `probe_edge_verify:28,23,LEFT,5` -> `confirmed_blocked`, `blocked=5`
  - `probe_edge_verify:24,23,DOWN,5` -> `confirmed_blocked`, `blocked=5`
  - `probe_edge_verify:24,24,UP,5` -> `confirmed_blocked`, `blocked=5`
- Permanent promotions from those checks:
  - `(27,23).east`
  - `(28,23).west`
  - `(24,23).south`
  - `(24,24).north`
- Live planner effect after those promotions:
  - forced `(27,23)` is now `No path found` to `(29,29)`
  - from forced `(28,22)`, the planner still claims `1 east, 7 south`
  - forced `(28,22)->probe_edge:RIGHT` later resolved the interrupted turn:
    it reached destination `(29,22)` but settled on the World Map at `(43,43)`
  - current interpretation: the x=29 lane is still real-but-weird; the missing
    bridge is earlier than `(28,22)`
- Strong row-21 stateful carry retest:
  - from forced `(25,21)`, skip-NPC planning to `(27,21)`, `(27,22)`, and
    `(29,29)` is still `No path found`, so the west entry problem is not just
    NPC occupancy
  - cold long raw `simulate_raw_sequence:RIGHT,160,0` from `(25,21)` settled at
    `(26,21)`
  - forced `(27,21)->LEFT` moved and settled all the way back at `(25,21)`
  - from that live landed state, a direct `probe_edge:RIGHT` from `(25,21)`
    moved and settled at `(27,21)` in one step
  - but a fresh `probe_edge:RIGHT` from live `(27,21)` then blocked again
  - an even longer raw `simulate_raw_sequence:RIGHT,240,0` from the recreated
    `(25,21)` state only settled at `(26,21)`
- Current interpretation:
  - the old west-entry problem at `(27,21).west` still behaves like a genuine
    stateful one-way refusal
  - `probe_edge` can sometimes carry `(25,21)` through to `(27,21)` after the
    reverse move from `(27,21)->LEFT`, but generic long raw input does not
    reproduce that carry
  - the remaining bridge, if it exists at all, is likely tied to this row-21
    stateful carry rather than ordinary planner geometry

### TANTEGEL EAST-POCKET ROW-24 BOX CLEANUP / X=29 HANDOFF SHIFT - 2026-05-24

- Fresh live pass after script reload started from forced `(27,24)`.
- Clean verifier promotions this pass:
  - `probe_edge_verify:27,24,RIGHT,5` -> `confirmed_blocked`, `blocked=5`
  - `probe_edge_verify:28,24,LEFT,5` -> `confirmed_blocked`, `blocked=5`
  - `probe_edge_verify:27,24,DOWN,5` -> `confirmed_blocked`, `blocked=5`
  - `probe_edge_verify:27,25,UP,5` -> `confirmed_blocked`, `blocked=5`
  - `probe_edge_verify:27,24,LEFT,5` -> `confirmed_blocked`, `blocked=5`
  - `probe_edge_verify:26,24,RIGHT,5` -> `confirmed_blocked`, `blocked=5`
  - `probe_edge_verify:26,23,DOWN,5` -> `confirmed_blocked`, `blocked=5`
  - `probe_edge_verify:26,24,UP,5` -> `confirmed_blocked`, `blocked=5`
  - `probe_edge_verify:25,23,DOWN,5` -> `confirmed_blocked`, `blocked=5`
  - `probe_edge_verify:25,24,UP,5` -> `confirmed_blocked`, `blocked=5`
- Permanent promotions from those checks:
  - `(27,24).east`
  - `(28,24).west`
  - `(27,24).south`
  - `(27,25).north`
  - `(27,24).west`
  - `(26,24).east`
  - `(26,23).south`
  - `(26,24).north`
  - `(25,23).south`
  - `(25,24).north`
- Live planner effect:
  - after the `(27,24)` west/east/south cleanup, forced
    `debug_pathfind_to_allow_hazards:29,29` from `(27,24)` became
    `No path found`
  - after the `(26,23)/(26,24)` and `(25,23)/(25,24)` south cleanups, forced
    `debug_pathfind_to_allow_hazards:29,29` from `(26,23)` no longer tried the
    boxed row-24 west shelf
  - current forced `(26,23)` remainder route is now:
    `2 east, 1 north, 1 east, 7 south`
- Current interpretation:
  - the row-24 shelf and its western lead-in are now substantially cleaned up
  - the next likely bridge candidate has shifted back to the x=28/x=29 handoff:
    `(27,23)->RIGHT`, `(28,23)->UP`, and/or `(28,22)->RIGHT` into the x=29 lane

### TANTEGEL EAST-POCKET X=26/X=27 THROAT CLEANUP - 2026-05-24

- Fresh live continuation from a normal castle restore at `(26,5)`:
  - `debug_pathfind_to_allow_hazards:29,29` was still `No path found`
  - even `debug_pathfind_to_allow_hazards:25,21` collapsed because live-NPC
    planning saw a stationary blocker at `(25,11)`, so the next checks used
    forced-state bracketing instead of normal planner routes
- Old row-21 conveyor theory did not hold up cleanly on this reload:
  - forced `(27,21)->RIGHT` blocked on direct `probe_edge`
  - long raw `RIGHT,160` from forced `(25,21)` only settled at `(26,21)`
  - treat the older `(27,21)->(29,21)` carry evidence as stale or
    state-contaminated, not durable geometry
- Stronger durable contradiction came one row lower at forced `(26,22)`:
  - before patching, planner from `(26,22)` still claimed
    `Path: 5 south, 3 east, 2 south`
  - live `auto_walk:29,29` from the same cell never left `(26,22)` and stalled
    immediately on the first south step
- Clean verifier promotions from that throat:
  - `probe_edge_verify:26,22,DOWN,5` -> `confirmed_blocked`, `blocked=5`
  - `probe_edge_verify:26,23,UP,5` -> `confirmed_blocked`, `blocked=5`
  - `probe_edge_verify:26,22,RIGHT,5` -> `confirmed_blocked`, `blocked=5`
  - `probe_edge_verify:27,22,LEFT,5` -> `confirmed_blocked`, `blocked=5`
  - promoted permanent:
    - `(26,22).south`
    - `(26,23).north`
    - `(26,22).east`
    - `(27,22).west`
- After `reload_navigation_modules`, planner no longer used the disproved south
  exit from `(26,22)`; the live frontier shifted east instead.
- The same cleanup repeated one cell farther east/south:
  - `probe_edge_verify:27,22,DOWN,5` -> `confirmed_blocked`, `blocked=5`
  - `probe_edge_verify:27,23,UP,5` -> `confirmed_blocked`, `blocked=5`
  - `probe_edge_verify:27,23,DOWN,5` -> `confirmed_blocked`, `blocked=5`
  - `probe_edge_verify:27,24,UP,5` -> `confirmed_blocked`, `blocked=5`
  - promoted permanent:
    - `(27,22).south`
    - `(27,23).north`
    - `(27,23).south`
    - `(27,24).north`
- Live frontier at the end of this pass:
  - current forced position reached `(27,23)` / `(27,24)` during verifier work
  - after reloading navigation modules from live `(27,23)`, planner still
    claims a remainder `Path: 4 south, 2 east, 2 south`
  - the first south step of that remainder is now disproved, so the next
    likely candidate is the row-24 / x=27 to x=28 shelf rather than another
    x=26/x=27 north-south throat
  - no runtime blocks were needed for this pass; all promotions came from clean
    verifier evidence

### TANTEGEL SOUTHEAST POCKET DEEPER SHELF / 25,22 THROAT COLLAPSE - 2026-05-24

- Fresh live resume after pocket continuation:
  - baseline came back at `(25,24)` with runtime helpers still active:
    - `(18,15).west`
    - `(16,16).north`
    - `(17,16).north`
    - `(21,22).west`
- Direct current-position shelf checks from `(25,24)`:
  - `inspect_move:RIGHT` previewed `(26,24)` open, but `probe_edge:RIGHT`
    blocked on `raw_hold_timeout`
  - `inspect_move:DOWN` previewed `(25,25)` open, but `probe_edge:DOWN`
    also blocked
  - reverse forced probes agreed:
    - `(26,24)->LEFT` blocked
    - `(25,25)->UP` blocked
- One cell farther east behaved the same:
  - forced `(26,24)` previewed both `(27,24)` and `(26,25)` open
  - `probe_edge:RIGHT` from `(26,24)` blocked
  - `probe_edge:DOWN` from `(26,24)` blocked
  - reverse forced probes also blocked:
    - `(27,24)->LEFT`
    - `(26,25)->UP`
  - forced `(27,24)` then planned `No path found` to `(29,29)` and both
    current-position `RIGHT` / `DOWN` probes blocked too
- Interpretation of the deeper shelf:
  - the teleported cells around `(25,24)` / `(26,24)` / `(27,24)` look boxed
    in live engine behavior despite open previews
  - keep that deeper boxed-cell family as scratch evidence for now; it is
    strong enough to distrust the planner there, but not yet necessary to
    promote all of it permanently in one pass
- Stronger durable result came one step upstream at `(25,22)`:
  - with runtime mirrors only for the earlier route-discovered seams
    `(26,23).west` and `(25,24).north`, hazards-allowed planning from
    `(25,22)` rerouted to `3 east, 6 south, 1 east, 1 south`
  - live autowalk on that reroute never left `(25,22)` and cleanly exposed the
    next blocked shelf faces:
    - repeated blocked-only `(25,22)->RIGHT` into `(26,22)`
    - repeated blocked/noisy `(25,22)->DOWN` into `(25,23)`
- Direct bracketing on the `(25,22)` throat:
  - current-position `probe_edge:RIGHT` from `(25,22)` blocked
  - forced `(26,22)->LEFT` blocked
  - current-position `probe_edge:DOWN` from `(25,22)` blocked
  - forced `(25,23)->UP` blocked
- Promotion outcome:
  - permanent:
    - `(25,22).east`
    - `(25,22).south`
    - `(26,22).west`
    - `(25,23).north`
  - still scratch/runtime-only:
    - `(26,23).west`
    - `(25,24).north`
    - deeper boxed shelf cells beyond `(25,24)` / `(26,24)`
- Runtime collapse check:
  - after mirroring only `(25,22)->RIGHT` and `(25,22)->DOWN` in addition to
    the earlier scratch runtime seams `(26,23).west` and `(25,24).north`,
    `debug_pathfind_to_allow_hazards:29,29` from forced `(25,22)` finally
    returned `No path found`
  - this is the cleanest current evidence that the remaining southeast route
    is still missing an upstream bridge rather than hiding inside the deeper
    `(25,24)` pocket itself

### TANTEGEL WEST-POCKET CONTINUATION / HIDDEN ALCOVE BRIDGE - 2026-05-24

- Validation first:
  - The new hidden-alcove passthrough patch itself was fine, but the first
    regression failed because `tantegel_castle_upper_chamber_row_16_updates_are_modeled`
    was still using the default 1x1 fake map metadata.
  - Fixed the test harness to stub real Tantegel-sized metadata before checking
    `(16,13)` / `(16,14)`.
- Fresh live baseline after reload:
  - `POSITION: map=0x04(Tantegel Castle) x=16 y=15`
  - runtime helpers already active:
    - `(16,16).north`
    - `(17,16).north`
    - stale-at-the-time `(18,15).west`
    - `(21,22).west`
- Permanent model correction from the west pocket:
  - `inspect_tile:16,13` now reports `reason=passthrough`,
    `effective_passable=true`
  - `inspect_tile:16,14` now reports `reason=passthrough`,
    `effective_passable=true`
  - `debug_pathfind_to_allow_hazards:16,13` from `(16,15)` found
    `Path: 2 north`
  - `debug_pathfind_to_allow_hazards:29,29` from `(16,15)` revived to
    `Path: 2 north, 2 east, 7 south, 2 east, 3 south, 2 east, 1 north,
    7 east, 7 south`
- The stale full blocker at `(21,23)` was also part of the missing bridge:
  - direct probes crossed it both directions
  - removing `MAP_BLOCKED_CELLS[0x04]["21,23"]` restored west-side planning
    before the hidden-alcove follow-up
- Live seam split at `(18,15)`:
  - natural route arrival `(19,15)->LEFT` blocked cleanly with
    `raw_hold_timeout`
  - forced `(18,15)->RIGHT` moved back through to `(19,15)`
  - direct forced `(17,15)->RIGHT` also moved into `(18,15)`, disproving the
    older west-approach runtime helper as a permanent truth
  - Result:
    - promoted permanent `MAP_DIRECTIONAL_BLOCKS[0x04]["18,15"].east = true`
    - keep `(18,15).west` runtime-only when a natural routed arrival keeps
      stalling there; do not promote it yet
- Runtime helper reset after the permanent promotion:
  - cleared all runtime blocks
  - re-added only:
    - `(16,16).north`
    - `(17,16).north`
    - `(21,22).west`
  - With only those helpers, `debug_pathfind_to_allow_hazards:29,29` from
    `(22,13)` still found a route:
    `4 west, 5 south, 2 east, 5 south, 2 east, 1 north, 7 east, 7 south`
- Natural-route-only seam behavior still matters:
  - once `(18,15).west` runtime was removed, autowalk from `(22,13)` looped
    back and hit repeated blocked-only failures on natural `(17,15)->RIGHT`
    into `(18,15)`:
    - `SEAM_OBSERVATION map=0x04 cell=(18,15) approach=west ... blocked=8 moved=0 classification=blocked_only`
  - Re-adding runtime `(18,15).west` let the route continue again.
- Latest frontier after re-adding runtime `(18,15).west`:
  - autowalk progressed to `(25,13)`
  - the next strongest candidate is now natural `(18,13)->DOWN` into `(18,14)`
  - route evidence there is strong but still route-shaped:
    - `SEAM_OBSERVATION map=0x04 cell=(18,14) approach=north ... blocked=8 moved=0 classification=blocked_only`
    - reroute from `(18,13)` escaped with a long detour
      `7 east, 4 north, 11 west, 9 south, 6 east, 5 south, 2 east, 1 north, 7 east, 7 south`
  - Needs a direct current-position or verifier pass before promotion.

### TANTEGEL SOUTHEAST POCKET CONTINUATION / ROW-23 AND ROW-22 SEAMS - 2026-05-24

- Follow-up direct check on the old `(18,13)->DOWN` suspect:
  - clean current-position `probe_edge:DOWN` from forced `(18,13)` did **not**
    confirm a blocker
  - it moved through `(18,14)` and settled at `(18,15)`
  - so the ugly route evidence there stays unpromoted
- From forced/current `(18,15)` with runtime `(18,15).west`,
  `debug_pathfind_to_allow_hazards:29,29` still found a live remainder route:
  `5 south, 1 east, 3 south, 3 east, 1 north, 7 east, 7 south`
- Autowalk then pushed into the restored southeast pocket and exposed a new
  chain of west-entry seams:
  - `(20,23)->RIGHT` into `(21,23)` blocked on current-position probe
  - forced `(21,23)->LEFT` moved back through
  - promoted permanent `(21,23).west`
  - `(21,23)->RIGHT` into `(22,23)` blocked on current-position probe
  - forced `(22,23)->LEFT` moved back through and settled at `(20,23)`
  - promoted permanent `(22,23).west`
- After reload, forced `(22,23)` still had a clean planner remainder:
  - `Path: 1 north, 7 east, 7 south`
  - but autowalk from `(22,23)` only got into `(22,22)` and then drifted off
    the expected east step into the dead shelf
- Direct current-position row-22 checks then exposed a closed east-west seam:
  - `(22,22)->RIGHT` into `(23,22)` blocked
  - `(23,22)->LEFT` into `(22,22)` also blocked
  - promoted permanent closed seam:
    - `(23,22).east = true`
    - `(24,22).west = true`
- After that patch, forced `(24,22)` still had a planner remainder:
  - `Path: 5 east, 7 south`
  - but autowalk from `(24,22)` now exposes the next blocked-only pair:
    - `(24,22)->RIGHT` into `(25,22)`:
      `blocked_only`, blocked count reached 5
    - `(24,22)->DOWN` into `(24,23)`:
      `blocked_only`, blocked count reached 4
- Current interpretation:
  - the restored southeast pocket is real, but the model is still missing more
    one-way or closed seams in the row-22 / row-23 band
  - the latest unpromoted frontier is:
    - `(25,22)` west approach
    - `(24,23)` north approach
  - both need direct reverse/current-position bracketing before promotion

### TANTEGEL 26,21 EAST RECHECK / SHRINE ROUTE COLLAPSE - 2026-05-24

- User reported live autowalk still engine-blocking at `(26,21)->RIGHT` after
  the seam-retry executor patch.
- Fresh FCEUX retest after manual Lua reload:
  - `auto_walk:29,29` from live `(26,21)` still planned
    `Path: 3 east, 8 south`.
  - The queued step `(26,21)->RIGHT` twitched immediately, then blocked at the
    short route timeout.
  - New seam retries did hold much longer than before, proving the executor
    patch landed, but both retries still failed:
    - first seam retry blocked after a full `timeout=60`,
    - second seam retry also blocked after a full `timeout=60`,
    - both logged `movement_started=true` with repeated early twitch holds.
- Direct input follow-up from the same live state also failed:
  - `simulate_raw_sequence:RIGHT,40,0` from `(26,21)` stayed at `(26,21)`.
  - `probe_edge:RIGHT` from `(26,21)` now also blocks with
    `reason=raw_hold_timeout`.
  - From forced `(25,21)`, `probe_edge:RIGHT` only reaches `(26,21)`.
  - Long `simulate_raw_input:RIGHT,80` from forced `(25,21)` still settles at
    `(26,21)`, disproving the old "carry through to `(27,21)`" route idea.
  - Forced `(26,20)` then raw `DOWN,40;RIGHT,40` ends at `(26,21)`, so the
    corner carry hypothesis also fails.
- Runtime truth check:
  - Re-injecting `add_blocked_edge:26,21,RIGHT` collapses
    `debug_pathfind_to_allow_hazards:29,29` to `No path found` from both
    checked entrances:
    - forced `(7,7)` -> `No path found`
    - forced `(11,28)` -> `No path found`
- Interpretation:
  - Restore `MAP_DIRECTIONAL_BLOCKS[0x04]["27,21"].west = true`.
  - The previous "Y=21 corridor restored" conclusion is superseded.
  - The Sun Shrine bridge is unresolved again: current geometry/data offers no
    planner-visible route to `(29,29)` once `(26,21)->RIGHT` is modeled
    honestly.

### TANTEGEL SUN SHRINE ROUTE CONTINUATION - 2026-05-24

- Fresh FCEUX baseline after reload/revive:
  - `POSITION: map=0x04(Tantegel Castle) x=26 y=21`
  - `PATH_STATE target=Stairs Down to Sun Shrine ... runtime_count=0`
- Live repro from the active shrine-stairs target:
  - `auto_walk` from `(26,21)` planned `1 north, 3 east, 9 south`.
  - The first step `(26,21)->UP` only looked blocked on the queued step;
    seam brute force then moved cleanly into `(26,20)`, so do not patch
    `(26,20).south`.
  - The next step `(26,20)->RIGHT` failed repeatedly on the queued route and
    both seam-retry injections.
  - Both reroute snapshots from `(26,20)` collapsed to `No path found` with
    `PATH_RUNTIME_BLOCK map=0x04 x=27 y=20 context=neighbor`.
- Direct verifier follow-up:
  - `probe_edge_verify:26,20,RIGHT,5` ->
    `classification=confirmed_blocked moved=0 blocked=5 blocked_model_mismatch=5`
  - `probe_edge_verify:27,20,LEFT,5` ->
    `classification=confirmed_passable moved=6 blocked=0 stability_recheck=true`
- Interpretation:
  - Promote a destination-side one-way seam at `MAP_DIRECTIONAL_BLOCKS[0x04]["27,20"].west=true`.
  - Keep the older `["27,20"].east=true` evidence; this cell is now modeled as
    blocked from both horizontal approaches while the north/south evidence
    remains unchanged.
  - Post-patch live retest from `(22,18)` no longer exposed another clean
    southeast-pocket wall:
    - `auto_walk` advanced to `(22,21)` under the hazards-allowed fallback.
    - `debug_pathfind_to_allow_hazards:29,29` from `(22,21)` found
      `1 east, 1 south, 6 east, 7 south`.
    - Forced-safe bracketing from `(23,22)` let
      `debug_pathfind_to_park_npcs:29,29` find `6 east, 7 south`.
  - Conclusion: the blocker patch restored southeast-pocket geometry again.
    The remaining shrine-route issue is hazard-crossing continuity across the
    `(23,21)` damage approach, not another missing directional wall.
  - 2026-05-24 lower-shelf retest refined that further:
    - `inspect_move:DOWN` from `(23,21)` previewed `(23,22)` as open, but
      raw `probe_edge:DOWN` from the live position blocked on
      `reason=raw_hold_timeout`.
    - Forced `(23,22)->UP` moved back into `(23,21)`, so this is a one-way
      north-entry seam into `(23,22)`, not a full block on either cell.
    - Forced `(23,22)->LEFT` also moved into `(22,22)`, disproving the old
      full-cell blocker at `(22,22)`.
    - Direct `probe_edge:DOWN` from forced `(22,21)` then blocked into
      `(22,22)`, so the west shelf is another north-entry seam rather than a
      globally open row-22 lane.
  - Permanent model follow-up:
    - Removed `MAP_BLOCKED_CELLS[0x04]["22,22"]`.
    - Added `MAP_DIRECTIONAL_BLOCKS[0x04]["22,22"].north = true`.
    - Added `MAP_DIRECTIONAL_BLOCKS[0x04]["23,22"].north = true`.
  - Post-reload planner behavior now matches the live pocket:
    - From forced `(23,21)`, `debug_pathfind_to_allow_hazards:29,29` reports
      `No path found`.
    - From forced `(23,22)`, parked planning still finds `6 east, 7 south`.
    - From forced upstream `(22,18)`, hazards-allowed planning also reports
      `No path found`, so the previous x=23 descent was a false bridge.

### TANTEGEL SHIRNE ROUTE RESTORED AFTER RELOAD - 2026-05-24

- User report after Lua reload: the shrine route disappeared from both
  entrances.
- Live bracketing from `(7,7)` showed the route still existed to the upper
  corridor and lower x=25 pocket:
  - `debug_pathfind_to_allow_hazards:25,17` found a clean no-hazard route.
  - `debug_pathfind_to_allow_hazards:25,18`, `25,20`, `25,21`, and `24,21`
    also found routes.
  - The first dead target was the row-22 descent itself; `(24,22)`,
    `(25,22)`, `(28,20)`, and `(29,22)` all reported `No path found`.
- Forced live repro at the upper pocket found the bad promoted seam:
  - `inspect_move:DOWN` from `(26,21)` previewed `(26,22)` as blocked by
    `directional_blocked=true blocked_approach=north`.
  - Direct `probe_edge:DOWN` from the same live position moved into `(26,22)`,
    proving `(26,22).north` was a false blocker.
  - From live `(26,22)`, `debug_pathfind_to_allow_hazards:29,29` immediately
    found `4 south, 3 east, 2 south`.
- Permanent fix:
  - Removed `MAP_DIRECTIONAL_BLOCKS[0x04]["26,22"].north`.
- Post-reload revalidation:
  - From `(7,7)`, `debug_pathfind_to_allow_hazards:29,29` found a 48-step
    route with hazard cells
    `(25,18)`, `(23,18)`, `(23,19)`, `(23,20)`, `(23,21)`.
  - From `(11,28)`, `debug_pathfind_to_allow_hazards:29,29` found a 63-step
    route with the same hazard set.
  - So the planner-visible shrine route is restored from both entrances after
    reload. Remaining work is still the hazard/autowalk behavior, not a
    missing bridge.

### TANTEGEL 26,21 EXIT RECHECK - 2026-05-24

- User reported that live `(26,21)` still seemed engine-blocked exiting south
  and east.
- Clean recheck after `recover_fceux_input.sh` confirmed the report:
  - `probe_edge_verify:26,21,DOWN,5` ->
    `classification=confirmed_blocked moved=0 blocked=5 blocked_model_mismatch=5`
  - `probe_edge_verify:26,22,UP,5` ->
    `classification=confirmed_passable moved=6 blocked=0 stability_recheck=true`
  - `probe_edge_verify:26,21,RIGHT,5` ->
    `classification=confirmed_blocked moved=0 blocked=5`
- Interpretation:
  - East was already modeled correctly as `(27,21).west = true`.
  - South is also a one-way seam after all: `(26,21)->DOWN` blocks, while
    `(26,22)->UP` moves.
- Permanent fix:
  - Restored `MAP_DIRECTIONAL_BLOCKS[0x04]["26,22"].north = true`.
- Post-reload spot check:
  - `inspect_move:DOWN` from `(26,21)` now reports
    `directional_blocked=true blocked_approach=north`.
  - `inspect_move:RIGHT` from `(26,21)` still reports
    `directional_blocked=true blocked_approach=west`.

### TANTEGEL Y21 CORRIDOR / VERIFIER FOLLOW-UP - 2026-05-24

- User suspected the Y=21 corridor might be open east-west and that the
  verifier was lying again.
- Fixed two verifier/input bugs before changing map data:
  - `get_edge_probe_unavailable_reason()` now refuses probes while
    `PREV.upper_active` is true, matching the autowalk guard. Earlier raw
    holds could time out under an upper dialogue window and look like geometry.
  - Raw debug release frames are now treated as raw too, so `auto_step` does
    not wake up on the neutral release after `simulate_raw_input`.
- Post-reload cold verifier still found a real bump:
  - `probe_edge_verify:26,21,RIGHT,5` -> `confirmed_blocked`, `moved=0`,
    `blocked=5`, no drift, map change, or interruption.
- The follow-up sequence exposed a third verifier/logging issue:
  - `probe_edge:LEFT` from `(27,21)` logged `status=moved final=(26,21)`, but
    by the next command the player had continued to `(25,21)`.
  - `probe_edge:RIGHT` then logged `(25,21)->(26,21)`, but a delayed
    `report_position` found `(27,21)`.
  - So `probe_edge` was reporting final position at first coordinate change,
    not after movement settled.
- Controlled raw holds after the reload:
  - From forced `(25,21)`, RIGHT for 15 or 25 frames stayed at `(25,21)`.
  - RIGHT for 40 frames reached `(26,21)`.
  - A settled follow-up RIGHT for 40 frames from `(26,21)` stayed at `(26,21)`.
  - RIGHT for 80 frames from forced `(25,21)` also settled at `(26,21)`.
  - From forced `(27,21)`, LEFT for 40 frames settled at `(25,21)`.
- After the settled-probe patch and script reload:
  - `probe_edge:RIGHT` from `(26,21)` reached and settled at `(27,21)`, logging
    `moved_through_modeled_block` against the stale `(27,21).west` model.
  - `probe_edge_verify:26,21,RIGHT,5` still blocked 5/5 from its repeated
    teleport/stopped-origin setup, confirming this is start-state sensitive.
  - Settled `probe_edge:LEFT` from `(27,21)` reached `(26,21)` and stopped at
    `(25,21)`.
  - Settled `probe_edge:RIGHT` from `(25,21)` reached `(26,21)` and stopped at
    `(27,21)`.
- Current interpretation:
  - The Y=21 corridor is traversable east-west for route connectivity.
  - The cold stopped edge `(26,21)->RIGHT` can still bump, so keep treating it
    as runtime/start-state weirdness rather than permanent static geometry.
  - Removed `MAP_DIRECTIONAL_BLOCKS[0x04]["27,21"].west`; kept
    `MAP_DIRECTIONAL_BLOCKS[0x04]["27,21"].north`.
  - `probe_edge` has been patched to wait `edge_probe_moved_settle_frames`
    before logging `final=(x,y)`, with `reached_dest` and `settle_frames`
    fields. `debug_tools` also now has `simulate_raw_sequence` for future
    stateful movement tests without auto_step interference.
  - The first live `simulate_raw_sequence` check exposed one more release-frame
    bug: sequence neutral release frames also need `_raw=true`, or `auto_step`
    wakes on release. Patched in `debug_tools.lua` with a unit regression.
  - After reloading `map_reader.lua`, `debug_pathfind_to_allow_hazards:29,29`
    finds routes from `(7,7)` and `(11,28)` again, both through
    `(25,18)`, `(26,18)`, and `(26,19)`.

### TANTEGEL SUN SHRINE HAZARD FALLBACK - 2026-05-24

- Fresh post-reload planner bracketing showed the route was not geometry-closed
  at the top strip anymore; it was safety-closed by hazard policy:
  - From `(11,28)`, both `debug_pathfind_to:29,29` and
    `debug_pathfind_to_skip_npcs:29,29` returned `No path found`.
  - From `(7,7)`, both normal and skip-NPC debug pathfinding to `(29,29)`
    also returned `No path found`.
  - Bracketing from `(7,7)` still reached `(22,8)`, `(25,10)`, `(26,10)`,
    `(25,11)`, `(25,17)`, and `(22,17)`, but failed for `(27,10)`,
    `(24,22)`, `(25,23)`, and `(29,29)`.
- `debug_pathfind_to_allow_hazards:29,29` from `(7,7)` did find a route.
  The reported hazard cells were exactly:
  - `(25,18)`
  - `(26,18)`
  - `(26,19)`
  - `(26,20)`
- Interpretation: with the current live directional model, the game-critical
  `(29,29)` tile remains reachable only through the lower damage pocket, so the
  route "closed" because safe autowalk forbids those hazard cells.
- Source patch:
  - `route_manager.lua` now allows a narrow unsafe autowalk fallback only for
    the Tantegel shared travel tile at `(29,29)` on map `0x04`.
  - The fallback re-plans with `allow_hazards=true`, marks the spoken route as
    `Unsafe route`, and carries that hazard allowance through reroutes/drift
    replans for the active route.
  - This does not broaden hazard autowalk for other targets.
- Test coverage:
  - Added a focused `test_route_manager.lua` regression confirming generic
    unsafe routes still do not queue automatically, while the Tantegel
    `(29,29)` shared travel tile does queue the hazards-allowed fallback.
  - `luac5.1 -p route_manager.lua test_route_manager.lua`
  - `lua5.1 test_route_manager.lua` -> 72 tests pass

### TANTEGEL EAST-SEAM PATCH - 2026-05-24

- Continued from the previous loop report: fresh `probe_edge_verify` and auto-walk
  evidence again showed `(26,17)->RIGHT` stalled repeatedly with `raw_hold_timeout`
  and no forward movement.
- This matches a confirmed hard wall on the west approach into `(27,17)`:
  - `SEAM_OBSERVATION (27,17) approach=west` repeatedly `blocked`
  - `EDGE_VERIFY_RESULT` classified `confirmed_blocked` with `manual_promotion_required=true`.
- Patch applied:
  - `MAP_DIRECTIONAL_BLOCKS[0x04]["27,17"] = {west = true}`
  - `test_map_reader.lua` updated to assert `(27,17).west` as blocked while
    keeping `(27,17).east` open.
- Verification run:
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `lua5.1 test_map_reader.lua` (36 tests pass)

### TANTEGEL SUN SHRINE BRIDGE LOOP - 2026-05-24 (post-patch)
- User reloaded into map 0x04 with doors open; auto-walk to `29,29` stalled again with loopy seam behavior near the row-9/10 east approach.
- Direct live probes were reported from the last pass as repeatedly blocked on:
  - `26,9->RIGHT`
  - `26,10->RIGHT`
  with the reverse westward movement staying open, i.e., confirmed one-way seams.
- To prevent planner/controller churn, corrected `MAP_DIRECTIONAL_BLOCKS` with
  destination-side entries:
  - `MAP_DIRECTIONAL_BLOCKS[0x04]["27,9"].west = true`
  - `MAP_DIRECTIONAL_BLOCKS[0x04]["27,10"].west = true`
- `test_map_reader.lua` assertions were updated to `27,9 west` and `27,10 west`.
- **Need to verify live:** reload `main.lua` and rerun `debug_pathfind_to:29,29` from throne and entrance starts.

### TANTEGEL EXIT CORRIDOR 28,10/28,11 - 2026-05-23 (verifier run)
- Sanity baseline before checks remained map `0x04(Tantegel Castle)` with no runtime
  blockers.
- From forced start `(28,10)` on map `0x04`, `probe_edge:DOWN` returned
  `status=moved final=(28,11)` and logged `EDGE_PROBE_MODEL_MISMATCH`
  with `kind=moved_through_modeled_block`. This confirms tile `(28,11)` is
  physically walkable despite the old permanent-block model.
- `inspect` evidence from that move shows `(28,11)` currently has
  `tile=8`, `base_walkable=true`, `permanent_blocked=true`, `walkable=false`
  in static `inspect` terms.
- For confirmation of return flow, `teleport_to:28,11,force` and `probe_edge:UP`
  reported `status=moved` back to `(28,10)` with no model mismatch.
- A clean explicit probe was then completed from forced `(28,11)`:
  `probe_edge:RIGHT` moved to `(29,11)` and immediately triggered
  `EVENT: map change -> 0x01 (World Map)`.
- Action: keep `(28,11)` unmodeled as a full or directional block (`MAP_BLOCKED_CELLS`
  and `MAP_DIRECTIONAL_BLOCKS` entries remain absent); this supports the interpretation
  that stepping south into `(28,11)` opens the bridge to the eastward exit area.

### TANTEGEL ENTRANCE/THRONE TO SUN SHRINE STAIRS - 2026-05-23
- Goal: find a working route between the castle entrance / throne-room side
  and the live Sun Shrine stair tile `(29,29)`.
- 2026-05-23 FCEUX reload / fixed-verifier follow-up:
  - Reload confirmed command polling with `LAUNCHER_PROBE: codex_reload`;
    baseline was map `0x04` at `(7,6)` with no runtime blocks.
  - Fixed `probe_edge_verify:14,8,DOWN,5` no longer crashed, but the result
    was mixed: moved `1`, blocked `4`, `moved_model_mismatch=1`, so do not
    reopen `(14,9).north`.
  - Component bracketing identified nearest modeled bridges into the Sun
    Shrine component. `probe_edge_verify:13,8,DOWN,5` confirmed blocked `5/5`.
  - `probe_edge_verify:14,7,RIGHT,5` initially moved `6/6` including the
    stability recheck, with `moved_model_mismatch=6`, but user play and
    route-shaped autowalk disproved it. Treat that verifier result as
    contaminated/subtile-only evidence.
  - Natural route evidence for `(14,7)->RIGHT` is blocked-only: repeated
    autowalk attempts accumulated `(15,7).west` blocked `9` / moved `0`, with
    runtime blocks injected and no successful crossing.
  - Permanent correction: keep `MAP_DIRECTIONAL_BLOCKS[0x04]["15,7"]` as
    `{west=true, east=true}`; `test_map_reader.lua` asserts both horizontal
    approaches remain blocked.
  - Natural/current-position probes after the correction:
    - From route-shaped `(14,8)`, `probe_edge:RIGHT` into `(15,8)` blocked and
      `probe_edge:DOWN` into `(14,9)` blocked.
    - Southern/perimeter candidates `(18,25)->RIGHT`, `(18,26)->RIGHT`,
      `(18,27)->RIGHT`, `(18,27)->DOWN`, and `(17,27)->DOWN` all blocked from
      natural starts.
    - Mid/southeast candidates `(20,20)->RIGHT`, `(20,17)->RIGHT`, and
      `(14,16)->RIGHT` all blocked from natural starts.
    - Row-17 north entries into row 16 blocked from x=15,16,17,18,19,20.
  - A capped `crawl_map_frontier:attempts=3,max_edges=80` pass was stopped at
    101 edges. It exported review-only passthrough candidates `(10,20)`,
    `(11,21)`, and `(13,13)`, but local ROM-backed route simulation with those
    three opened still found no route from `(7,7)` to `(29,29)`. Do not promote
    them as Sun Shrine route fixes.
  - Still unresolved: find the actual throne-side bridge to the `(29,29)`
    Sun Shrine stairs component.
- Follow-up correction after user play:
  - User proved the Sun Shrine stairs back to the entrance/throne-room side are
    clean, but autowalk from the throne-room side back toward the shrine failed
    at `(14,16)->RIGHT` and then reported no alternate path.
  - The earlier forward-route proof was stale/incomplete because the planner
    path crossed `(14,16)->(15,16)`, which was not yet modeled as blocked.
  - `probe_edge_verify:14,16,RIGHT,5` blocked 5/5 with no drift, no map
    change, and no NPC contamination. Added `(15,16).west`.
  - Manually injecting the same edge with `add_blocked_edge:14,16,RIGHT` made
    `debug_pathfind_to:29,29` report no path from `(14,16)`, from the
    throne-room-side stair tile `(7,7)`, and from the entrance `(11,28)`.
  - `debug_pathfind_to_allow_hazards:29,29` also reported no path from
    `(7,7)` and `(11,28)`, so the current failure is not just hazard policy.
  - Reverse trace from `(29,29)` to `(7,7)` remains valid:
    `(29,29)->(29,28)->(29,27)->(29,26)->(29,25)->(29,24)->(29,23)->(29,22)->(29,21)->(29,20)->(29,19)->(29,18)->(29,17)->(29,16)->(29,15)->(29,14)->(29,13)->(29,12)->(29,11)->(29,10)->(28,10)->(27,10)->(26,10)->(25,10)->(25,9)->(24,9)->(23,9)->(22,9)->(21,9)->(20,9)->(19,9)->(18,9)->(17,9)->(16,9)->(15,9)->(15,8)->(14,8)->(13,8)->(12,8)->(12,7)->(11,7)->(10,7)->(9,7)->(8,7)->(7,7)`.
  - Bracketing the forward version of that reverse route showed `(7,7)` can
    reach `(12,8)`, `(13,8)`, and `(14,8)`, but not `(15,8)`, `(15,9)`,
    `(16,9)`, `(22,9)`, `(25,10)`, or `(29,10)`.
  - Nearby direct verifiers all stayed blocked:
    `probe_edge_verify:14,8,RIGHT,5`, `probe_edge_verify:14,8,DOWN,5`,
    `probe_edge_verify:13,9,RIGHT,5`,
    `probe_edge_verify:12,9,RIGHT,5`, and
    `probe_edge_verify:14,7,RIGHT,5` each blocked 5/5.
  - Added the newly missing `(14,9).west` blocker from the
    `13,9,RIGHT` verifier. The others were already modeled.
  - Current live overlay after the check has `(15,16).west` and `(14,9).west`
    runtime blocks; source reload will pick them up from `map_reader.lua`.
  - Current interpretation: reverse shrine-to-throne/entrance routing is clean,
    but no safe/planned forward route from entrance or throne side to `(29,29)`
    is currently known.
  - Additional verification after latest reload (post-interrupt):
    - Baseline remained `map=0x04` and command polling stayed healthy after `recover_fceux_input.sh`.
    - Confirmed blocker checks:
      - `probe_edge_verify:14,8,DOWN,5` -> `confirmed_blocked` (`5/5`).
      - `probe_edge_verify:14,8,RIGHT,5` -> `confirmed_blocked` (`5/5`).
      - `probe_edge_verify:14,6,UP,5` -> `suspect_passable_model_mismatch` (`6/6` moved).
      - `probe_edge_verify:22,8,DOWN,5` -> `suspect_passable_model_mismatch` (`6/6` moved).
      - `probe_edge_verify:14,7,RIGHT,5` -> `confirmed_blocked` (`5/5`).
      - `probe_edge_verify:29,10,LEFT,5` -> `confirmed_passable` (`6/6` moved).
      - `probe_edge_verify:29,10,RIGHT,5` -> `inconclusive_map_changed` (map transition).
    - Route planning checks:
      - `pathfind_to:29,29` from `(14,7)` -> `No path found`.
      - `pathfind_to:29,10` from `(14,7)` / `(26,5)` -> `No path found`.
      - `debug_pathfind_to:29,10` from `(26,5)` -> `No path found` (visited 473, no path).
    - `pathfind_to:29,29` from `(29,10)` still returns a clean route (`19 south`), indicating a connectivity break before entering the lower stair component.
- Later live continuation (FCEUX, doors open, fresh runtime checks):
  - `auto_walk:29,29` from `(25,15)` repeatedly stalls at `(26,14)->DOWN`;
    `SEAM_OBSERVATION` stayed `blocked_only` with `blocked=6` and `PATH_RUNTIME_BLOCK`
    on `(26,15)`.
  - `probe_edge_verify:26,14,DOWN,5` confirmed `confirmed_blocked` with
    `classification=confirmed_blocked`, `moved=0`, `blocked=5`, `manual_promotion_required=true`.
  - `probe_edge_verify:26,15,UP,5` confirmed `confirmed_passable` from the
    lower side (`moved=6`, `blocked=0`, stability recheck true).
  - `probe_edge_verify:25,16,RIGHT,5` blocked `5/5`; this plus the seam confirms
    the only clean way into `(26,16)`/`(26,15)` is blocked at this northward
    seam.
  - `map_reader` updated to add `("26,15").north = true` with matching
    `test_map_reader.lua` assertion and tests still pass.
- Follow-up correction after user found the missing row-9 bridge segment:
  - Fresh log/manual evidence disproved the `(14,9).west` promotion and the
    older `(13,9).west` block.
  - Manual movement crossed `(13,9)->RIGHT` into `(14,9)`, then
    `(14,9)->LEFT` back into `(13,9)`.
  - Direct verifier `probe_edge_verify:12,9,RIGHT,5` moved 5/5 into `(13,9)`.
  - Patched `MAP_DIRECTIONAL_BLOCKS[0x04]["13,9"]` and `["14,9"]` to keep only
    their north/south entry blockers.
  - With the bridge open, `debug_pathfind_to:29,29` from `(7,7)` found a
    44-step route:
    `(7,7)->(8,7)->(9,7)->(9,8)->(10,8)->(11,8)->(12,8)->(12,9)->(13,9)->(14,9)->(15,9)->(16,9)->(17,9)->(18,9)->(19,9)->(20,9)->(20,10)->(21,10)->(22,10)->(23,10)->(24,10)->(25,10)->(26,10)->(27,10)->(28,10)->(29,10)->(29,11)->(29,12)->(29,13)->(29,14)->(29,15)->(29,16)->(29,17)->(29,18)->(29,19)->(29,20)->(29,21)->(29,22)->(29,23)->(29,24)->(29,25)->(29,26)->(29,27)->(29,28)->(29,29)`.
  - Live `auto_walk:29,29` from `(7,7)` completed at `(29,29)` with no
    runtime blockers. Post-arrival facing stepped south through the shared
    southeast exit, changing to `map=0x01(World Map) x=43 y=43`.
  - Current interpretation: the old row-16 route is still invalid, but the
    throne-side forward route to the Sun Shrine / southeast tile is live-proven
    again via the row-9 bridge.
- Fresh baseline after FCEUX reload:
  - `report_position` first showed map `0x04` at `(26,5)`.
  - `report_runtime_blocks` showed none.
  - From `(26,5)`, `debug_pathfind_to_allow_hazards:29,29` still found no
    path, so that upper pocket is not the useful bridge.
- Entrance-side route proof:
  - From `(11,28)`, `debug_pathfind_to:29,29` found a 43-step normal route.
  - `trace_path` route:
    `(11,28)->(11,27)->(11,26)->(11,25)->(12,25)->(12,24)->(12,23)->(12,22)->(12,21)->(12,20)->(13,20)->(13,19)->(13,18)->(14,18)->(14,17)->(14,16)->(15,16)->(16,16)->(17,16)->(18,16)->(19,16)->(20,16)->(21,16)->(21,17)->(22,17)->(22,18)->(23,18)->(23,19)->(23,20)->(24,20)->(25,20)->(26,20)->(26,21)->(27,21)->(27,22)->(27,23)->(27,24)->(27,25)->(27,26)->(27,27)->(28,27)->(28,28)->(29,28)->(29,29)`.
  - Live `auto_walk:29,29` from `(11,28)` reached `(29,29)` with no runtime
    blockers. One noisy drift/retry occurred near `(28,16)->(29,16)->(29,17)`,
    then the route recovered and completed.
- Throne-room-side route proof:
  - From the castle-side throne-room stair tile `(7,7)`,
    `debug_pathfind_to:29,29` found a 44-step route.
  - `trace_path` route:
    `(7,7)->(8,7)->(9,7)->(9,8)->(9,9)->(9,10)->(10,10)->(10,11)->(10,12)->(10,13)->(11,13)->(11,14)->(11,15)->(12,15)->(13,15)->(14,15)->(14,16)->(15,16)->(16,16)->(17,16)->(18,16)->(19,16)->(20,16)->(21,16)->(21,17)->(22,17)->(22,18)->(22,19)->(23,19)->(23,20)->(23,21)->(23,22)->(24,22)->(24,23)->(25,23)->(25,24)->(25,25)->(25,26)->(26,26)->(27,26)->(28,26)->(28,27)->(29,27)->(29,28)->(29,29)`.
  - Live `auto_walk:29,29` from `(7,7)` reached `(29,29)` with no runtime
    blockers.
- Object-label note:
  - `(29,29)` is the shared Sun Shrine stair and southeast world-exit tile. The
    object navigator now exposes it as one Travel object:
    `Sun Shrine Stairs and Southeast Exit`.
- 2026-05-23 follow-up after user re-checked row-9 coordinates:
  - User reported that the row-9 bridge appeared to collapse again at
    `(12,9)->RIGHT`.
  - Fresh position baseline showed `map=0x04 x=12 y=9`, no runtime blocks, and
    current target `(29,29)`.
  - Read-only `inspect_move:12,9,RIGHT` still reported the static model as
    effectively passable into `(13,9)`; the printed `directional_blocked=true`
    came from other approaches on `(13,9)`, while `approach_blocked=false`.
  - Live autowalk/manual evidence from the currently loaded FCEUX script did
    repeatedly time out at `(12,9)->RIGHT`, and
    `probe_edge_verify:12,9,RIGHT,5` reported blocked 5/5.
  - However, the loaded verifier is stale: `EDGE_VERIFY_START` logged
    `settle_frames=18`, and `EDGE_VERIFY_ATTEMPT_START` did not include the
    new per-attempt `settle_frames` field from the verifier hardening patch.
    This means the raw-hold evidence was collected before the post-teleport
    scan-grace fix was actually running.
  - After actual reload, the log matched the user's observation: entering
    `(12,9)` from the east allowed short-window reversal back to `(13,9)`, but
    later stable east taps from `(12,9)` only twitched and cancelled.
  - Hardened direct verifier `probe_edge_verify:12,9,RIGHT,5` showed
    `EDGE_VERIFY_ATTEMPT_START ... settle_frames=49 ...` and then blocked 5/5,
    confirming stable `(13,9).west` is closed.
  - With `add_blocked_edge:12,9,RIGHT`, normal, allow-hazards, skip-NPC, and
    parked-NPC `debug_pathfind_to:29,29` all reported no path, so a different
    bridge was still needed.
  - Component analysis pointed at the nearest candidates into row 9:
    `(13,8)->DOWN`, `(13,10)->UP`, `(14,8)->DOWN`, and `(14,10)->UP`.
  - `probe_edge_verify:13,8,DOWN,5` was mixed 3 moved / 2 blocked; do not use
    it as permanent passability evidence yet.
  - `probe_edge_verify:13,10,UP,5` blocked 5/5, confirming `(13,9).south`.
  - `probe_edge_verify:14,8,DOWN,5` moved 5/5. This is the stable forward
    connector into the row-9 bridge.
  - Permanent patch: `MAP_DIRECTIONAL_BLOCKS[0x04]["13,9"].west` is restored,
    and `["14,9"].north` is removed while `["14,9"].south` remains blocked.
  - Local ROM-backed route sanity with this model finds a 39-step route from
    stable `(12,9)`:
    `(12,9)->(12,8)->(13,8)->(14,8)->(14,9)->(15,9)->...->(29,10)->...->(29,29)`.
  - 2026-05-24 fresh same-session FCEUX recheck superseded that restored west
    block: `probe_edge_verify:13,9,LEFT,5` confirmed `(13,9)->(12,9)` 6/6,
    `probe_edge_verify:11,9,RIGHT,5` confirmed `(11,9)->(12,9)` 6/6, and
    direct `probe_edge_verify:12,9,RIGHT,5` moved into `(13,9)` 6/6 including
    the delayed stability recheck. Treat the earlier "stable blocked" result
    as stale verifier state; `MAP_DIRECTIONAL_BLOCKS[0x04]["13,9"].west`
    should stay open again.
  - 2026-05-24 lower hazard-pocket continuation from revived FCEUX state:
    - Fresh baseline at `(26,18)` showed `MENU_STATE raw_open=false ... submenu=nil`
      and no runtime blockers.
    - `probe_edge_verify:26,18,RIGHT,5` was inconclusive there because its
      internal teleport reset refused the hazard tile: `teleport_to refused:
      (26,18) not walkable`.
    - Live current-position `probe_edge:RIGHT` from `(26,18)` blocked 3/3 with
      `EDGE_PROBE_MODEL_MISMATCH ... blocked_despite_open_preview`. Promote
      `(27,18).west`.
    - Injecting runtime `(27,18).west` made `debug_pathfind_to_allow_hazards:29,29`
      find a new 14-step route through `(26,19)->(27,19)->(28,19)->(28,20)->...`.
    - `validate_path` could not exercise that route because the validator uses
      `auto_step`, which still refuses the first hazard step `(26,18)->(26,19)`.
    - Raw `probe_edge:DOWN` from `(26,18)` moved into hazard tile `(26,19)`.
    - Live current-position `probe_edge:RIGHT` from `(26,19)` then blocked 3/3
      with the same `blocked_despite_open_preview` mismatch. Promote
      `(27,19).west`.
    - With runtime `(27,18).west` and `(27,19).west` both injected,
      `debug_pathfind_to_allow_hazards:29,29` rerouted backward through the
      x=23 hazard lane instead of continuing to hammer the x=26 east exits.
  - 2026-05-24 restored-save continuation after user revive:
    - Fresh baseline after save-state restore was `map=0x04 x=26 y=5`,
      runtime blockers none.
    - The unreloaded live planner still traced the old lower route through
      `(25,18)->(26,18)->(26,19)->(26,20)->(27,20)->(27,21)->...->(29,29)`.
      Re-injecting runtime `(27,18).west` and `(27,19).west` did not affect
      that route because this branch never uses those east exits.
    - Forced teleport to `(27,20)` let us probe the live branch directly.
    - Current-position `probe_edge:DOWN` from `(27,20)` blocked 3/3 into
      `(27,21)` with `EDGE_PROBE_MODEL_MISMATCH ... blocked_despite_open_preview`.
      Promote `(27,21).north`.
    - Injecting runtime `(27,21).north` immediately rerouted the live branch to
      `(27,20)->(28,20)->(28,21)->(28,22)->(29,22)->...->(29,29)`.
    - Current-position `probe_edge:RIGHT` from `(27,20)` then moved cleanly
      into `(28,20)`, bridging the restored-save route back onto the healthier
      southeast lane.
  - Tooling hardening from this investigation:
    - `probe_edge_verify` now withholds seam-history `verified_probe_move`
      records until the final result is cleanly `confirmed_passable`, so mixed
      one-way latch evidence cannot pre-poison route history.
    - All-moved verifier runs now get one delayed stability recheck before
      they can classify as `confirmed_passable`.
    - Moves through a currently modeled blocked approach classify as
      `suspect_passable_model_mismatch`, not clean passable proof.
  - Follow-up user route attempt after reload:
    - Autowalk reached `(14,8)` and then failed on the planned
      `(14,8)->DOWN` step into `(14,9)`. Queued route plus both seam retries
      all stayed at `(14,8)`, recording `blocked_only` seam observations.
    - The loaded script had the map patch but not the final verifier-hardening
      patch; `EDGE_VERIFY_RESULT` was still old-format. Its attempt starts did
      show `settle_frames=49`.
    - `probe_edge_verify:14,8,DOWN,5` under that partially current script
      blocked 5/5, but the first run after loading the new verifier hardening
      crashed before writing a result because `log_edge_probe_mismatch` still
      referenced a refactored-away local `start_report`.
    - Fixed that crash in `main.lua` by restoring the local
      `start_report = probe.start_report` inside `log_edge_probe_mismatch`.
      `luac5.1 -p main.lua` and the full `python3 run_tests.py
      --allow-missing-speech-dep` suite passed with only known local speech
      dependency noise.
    - Pending: reload FCEUX `main.lua` again and rerun
      `probe_edge_verify:14,8,DOWN,5`. A valid fixed-verifier result should
      include `moved_model_mismatch`, `blocked_model_mismatch`, and
      `stability_recheck` fields.

### TANTEGEL TREASURE / SUN SHRINE STAIRS - 2026-05-22
- User report:
  - Autowalk reached the marked treasure-room stairs object, but using STAIRS
    at the marked spot returned the in-game error text.
- Disproved marker:
  - The stale object coordinate was `(29,1)` on Tantegel Castle `map=0x04`.
  - `inspect_tile:29,1` showed reachable ordinary floor.
  - Manual STAIRS at `(29,1)` produced: "There are no stairs here."
- ROM/live candidate review:
  - ROM down-stair table entries include map `0x04` candidates `(14,2)` and
    `(29,29)`.
  - `inspect_tile:29,29` showed a reachable tile.
  - `debug_pathfind_to:29,29` from `(29,1)` produced a valid route.
- Live proof:
  - `auto_walk:29,29` reached `(29,29)` cleanly.
  - After FCEUX input recovery, selecting STAIRS from `(29,29)` produced
    `EVENT: map change -> 0x0C (Sun Shrine)`.
  - Follow-up position report landed at `map=0x0C(Sun Shrine) x=0 y=4`.
- Permanent patch:
  - Changed the Tantegel Castle Sun Shrine stair object from `(29,1)` to
    `(29,29)` in `objects.lua`.
  - Added `test_objects.lua` coverage rejecting stale `stair_29_1` and
    requiring `stair_29_29` / `Stairs Down to Sun Shrine`.
- Still separate / unverified:
  - The other ROM map `0x04` down-stair candidate `(14,2)` was later
    live-tested and produced "There are no stairs here."

### SUN SHRINE EXIT + TANTEGEL HAZARDS - 2026-05-22
- User report:
  - The stairs back out of Sun Shrine are mismarked: the Sun Shrine transition
    deposits the player at `(0,4)`, but the map exposed the exit object at
    `(4,4)`.
  - The entrance-to-Sun-Shrine-stairs route also crossed a couple of hazard
    cells.
- Exit patch:
  - Updated the Sun Shrine exit object on map `0x0C` from `(4,4)` to `(0,4)`.
  - Added `test_objects.lua` coverage for `exit_0_4`.
- Hazard evidence:
  - The route from `(11,28)` to `Stairs Down to Sun Shrine` queued 87 steps
    and crossed the west/south-west barrier pocket.
  - After the route and shrine transition, the status line showed HP down to
    `9`, matching damage-terrain exposure.
  - The route crossed passable tile-6 cells `(11,19)`, `(11,18)`, and
    `(9,18)` while only the neighboring `(10,18)` damage tile had previously
    been modeled as a hazard.
  - Read-only `inspect_tile` confirmed those cells decode as walkable/passable
    in the current model, which is why the planner used them.
- Hazard patch:
  - Added `MAP_HAZARD_CELLS[0x04]` damage entries for `(9,18)`, `(11,18)`,
    and `(11,19)`, keeping them separate from wall/block data.
  - Expanded `test_map_reader.lua` coverage so the hazard cells stay
    engine-walkable in the base model but pathfinder-forbidden.
- Validation:
  - `luac5.1 -p objects.lua map_reader.lua test_objects.lua test_map_reader.lua`
  - `lua5.1 test_map_reader.lua` passed 35 tests.
  - `lua5.1 test_objects.lua` passed 66 tests.

### POST-HAZARD SUN SHRINE / THRONE ROUTE LOOPS - 2026-05-22
- User correction:
  - The later "second route" was accidentally aimed at the throne-room stairs,
    not the Sun Shrine stairs. It is still useful Tantegel geometry evidence,
    but it should not be counted as a Sun Shrine return failure.
- Reload boundary discovered:
  - Source `map_reader.lua` already modeled `(27,16).east`, but live
    `inspect_move:28,16,LEFT` still reported `approach_blocked=false`.
  - The same read-only inspect batch reported `(27,17).east` and
    `(27,20).east` open before the permanent patch below.
  - Conclusion: FCEUX is running a stale Lua model and needs a manual
    `main.lua` reload before these source changes can be verified live.
- Sun Shrine route blockers promoted from the entrance-to-`(29,29)` route:
  - `(14,5).north`: route step from `(14,4)->DOWN` queued, seam retry stayed
    blocked, and repeated observations stayed blocked.
  - `(15,5).north`: route step from `(15,4)->DOWN` queued, seam retry stayed
    blocked, and repeated observations stayed blocked.
  - `(20,9).north`: route step from `(20,8)->DOWN` repeated as blocked-only.
  - `(21,9).north`: route step from `(21,8)->DOWN` repeated as blocked-only.
- Accidental throne-room route blockers promoted:
  - `(27,17).east`: route looped at `(28,16)/(28,17)` and repeatedly failed
    the westward entry from `(28,17)`.
  - `(27,20).east`: initial westward entry from `(28,20)` blocked on queued
    route plus seam retry.
  - `(27,16).east` was already modeled in source; live disagreement was part
    of the stale-reload evidence.
- Noisy / not promoted from this batch:
  - `(11,27).south`, `(12,24).west`, and `(16,4).west` moved after retry and
    looked like route timing/subtile noise.
  - Horizontal noise around `(20,8)/(21,8)` was not promoted.
- Permanent patch:
  - Added `north=true` for `(14,5)`, `(15,5)`, `(20,9)`, and `(21,9)` on
    Tantegel Castle map `0x04`.
  - Added `east=true` for `(27,17)` and `(27,20)` on map `0x04`.
  - Added focused `test_map_reader.lua` assertions.
- Post-reload correction:
  - Live reload confirmed the four Sun Shrine route blockers above, but
    `(27,17).east` and `(27,20).east` still inspected open.
  - Cause: those two entries and their tests had accidentally landed in the
    Brecconary `0x08` block. Moved them into Tantegel `0x04`; injected them as
    runtime edges for the live session.
- Entrance route follow-up:
  - With `(27,17).east` / `(27,20).east` injected, `auto_walk:29,29` from
    `(28,16)` reached the Sun Shrine stairs cleanly.
  - Full entrance route from `(11,28)` still found the row-8 east-wing detour
    and exposed more confirmed blockers:
    - `(18,9).north`: `probe_edge_verify:18,8,DOWN,5` blocked 5/5.
    - `(19,9).north`: `probe_edge_verify:19,8,DOWN,5` blocked 5/5.
    - `(17,9).north`: `probe_edge_verify:17,8,DOWN,5` blocked 5/5.
  - After injecting those three runtime edges, the route no longer looped; the
    planner reported no path from `(17,8)` and from the entrance to `(29,29)`.
  - Bracketing checks showed `(22,8)`, `(23,8)`, and `(24,8)` are wall tiles,
    so the row-8 corridor cannot bridge farther east around the verified
    `(17,9)..(21,9)` north-wall band.
  - Historical interpretation, superseded by the 2026-05-23 route proof above:
    the old row-16 bridge is invalid after `(15,16).west` was confirmed
    blocked, but the throne-side route can reach `(29,29)` via the reopened
    row-9 bridge. Treat this older "no safe route" conclusion as partial
    bracketing from a stale/intermediate route model.
- Validation:
  - `luac5.1 -p objects.lua map_reader.lua test_objects.lua test_map_reader.lua`
  - `lua5.1 test_map_reader.lua` passed 35 tests.
  - `lua5.1 test_objects.lua` passed 66 tests.
  - `git diff --check` passed.

### TANTEGEL 1F LOCKED DOOR INVESTIGATION - 2026-05-22
- Goal: replace the bogus y=6 Tantegel Castle door model with live-confirmed
  door coordinates.
- External guide orientation:
  - Gamer Corner / Realm of Darkness / Mike's RPG Center agree Tantegel Castle
    has two 1F locked-door targets plus the already-modeled throne-room door on
    map `0x05`.
  - The useful 1F targets are the west treasure room and the north/key-shop
    area, not the old center y=6 band.
- Disproved old y=6 model:
  - Manual OPEN at `(14,6)` produced "There is no door here"; keys and door RAM
    were unchanged.
  - Live movement/probes showed several y=6 cells were passable without door
    RAM writes, including `(10,6)`, `(11,6)`, `(12,6)`, `(14,6)`, and later
    `(20,6)/(21,6)` area movement.
- Found west treasure-room door:
  - From `(3,13)` facing east, OPEN consumed one Magic Key and wrote door RAM
    slot `0=(4,13)`.
  - Failed neighboring door checks included `(2,15)->SOUTH`, `(1,15)->SOUTH`,
    `(3,15)->SOUTH`, and `(3,14)->EAST`.
- Found north/key-shop-area door:
  - From `(18,5)` facing south, OPEN consumed one Magic Key and wrote door RAM
    slot `1=(18,6)`.
  - Failed/no-door checks included `(22,2)->DOWN` into `(22,3)`,
    `(24,1)->DOWN` into `(24,2)`, `(25,1)->DOWN`, `(26,2)->DOWN`,
    `(27,1)->DOWN`, `(28,1)->DOWN`, and many earlier top-right candidates.
  - After opening `(18,6)`, the old static model still blocked movement via
    `MAP_DIRECTIONAL_BLOCKS[0x04]["18,6"].north`; this was patched out.
- Permanent patch:
  - `MAP_DOOR_CELLS[0x04]` now contains `["4,13"]` and `["18,6"]`.
  - Removed `(4,13)` from `MAP_BLOCKED_CELLS[0x04]`.
  - Removed `(18,6).north` from `MAP_DIRECTIONAL_BLOCKS[0x04]`.
  - `objects.lua` exposes `Treasure Room Door` and `Magic Key Area Door`
    instead of the old `Center Door`.
  - Added focused `test_map_reader.lua` and `test_objects.lua` coverage.
- Validation:
  - `luac5.1 -p map_reader.lua objects.lua test_map_reader.lua test_objects.lua debug_tools.lua`
  - `lua5.1 test_map_reader.lua` passed 34 tests.
  - `lua5.1 test_objects.lua` passed 64 tests.
  - `git diff --check` passed.
- Reload boundary:
  - FCEUX still needs a manual Lua reload before live movement/pathing sees the
    corrected door model.

### TANTEGEL KEY-MERCHANT ROUTE RAMBLE FOLLOW-UP - 2026-05-22
- User play notes:
  - Routes to/from chest door and both staircases had minor hiccups but were
    generally clean.
  - Routes to/from the Magic Key Merchant struggled more.
- Log review:
  - Noisy / non-promoted route artifacts included `(8,7).west`, `(9,8).north`,
    `(16,8).north`, `(16,7).south`, and `(15,4).west`.
  - Strong repeated route blockers were concentrated near the east side of the
    x=15 wall and the `(16,8)->DOWN` exit attempt.
- Direct verifier results:
  - `probe_edge_verify:16,8,DOWN,5` blocked 5/5, confirming `(16,9).north`.
  - `probe_edge_verify:16,8,LEFT,5` blocked 5/5, confirming `(15,8).east`.
  - `probe_edge_verify:16,7,LEFT,5` blocked 5/5, confirming `(15,7).east`.
  - `probe_edge_verify:14,4,DOWN,5` moved 5/5, so do not promote
    `(14,5).north`; it was a route timing/noise artifact.
- Permanent patch:
  - Added `east=true` to `MAP_DIRECTIONAL_BLOCKS[0x04]["15,7"]`.
  - Added `east=true` to `MAP_DIRECTIONAL_BLOCKS[0x04]["15,8"]`.
  - Added `["16,9"] = {north = true}` to `MAP_DIRECTIONAL_BLOCKS[0x04]`.
  - Added focused `test_map_reader.lua` assertions.
- Validation:
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `lua5.1 test_map_reader.lua` passed 34 tests.
  - `git diff --check` passed.
- Reload boundary:
  - FCEUX needs a manual Lua reload before live route planning uses these
    permanent edge fixes.

### TANTEGEL KEY-MERCHANT ENTRANCE ROUTE FOLLOW-UP - 2026-05-22
- User reported the route from the castle entrance to the key merchant almost
  made it, then started bouncing; manual play along the planner's northern
  path exposed more cranky row-6/merchant-pocket cells.
- Baseline:
  - FCEUX was live on `map=0x04`.
  - Door RAM showed both relevant doors still open: `(4,13)` and `(18,6)`.
  - No runtime blocks were present before this follow-up.
- Log review:
  - The route got cleanly through the opened `(18,6)` door.
  - It repeatedly tried row-6 entries from row 7: `(22,7)->UP`,
    `(23,7)->UP`, and later `(20,7)->UP`, `(21,7)->UP`.
  - `(18,6)->RIGHT` and `(19,7)->UP` into `(19,6)` were noisy during route
    execution, but after FCEUX input recovery both repeated as passable 5/5 and
    the successful entrance route crossed `(18,6)->(19,6)` cleanly.
- Promoted blockers:
  - `probe_edge_verify:20,7,UP,5` blocked 5/5: `(20,6).south`.
  - `probe_edge_verify:21,7,UP,5` blocked 5/5: `(21,6).south`.
  - `probe_edge_verify:22,7,UP,5` blocked 5/5: `(22,6).south`.
  - `probe_edge_verify:23,7,UP,5` blocked 5/5: `(23,6).south`.
  - `probe_edge_verify:24,3,UP,5` blocked 5/5: `(24,2).south`.
  - `probe_edge_verify:25,3,UP,5` blocked 5/5: `(25,2).south`.
- Non-promoted / kept open:
  - `(19,6).west` and `(19,6).south`: later direct verifiers moved 5/5, and
    the successful entrance-to-merchant route crossed `(19,6)` horizontally.
  - `(24,3)` itself remains the correct key-merchant stand; `(24,2)` is the
    blocked counter/wall tile, not the route target.
- Live validation:
  - Injected the six confirmed runtime blockers and ran `auto_walk:24,3` from
    the entrance `(11,28)`.
  - Route completed at `(24,3)` after cleanly crossing row 6 horizontally:
    `(18,6)->(19,6)->(20,6)->(21,6)->(22,6)->(23,6)`, then north to `(23,3)`
    and east to the stand.
- Validation:
  - `luac5.1 -p map_reader.lua test_map_reader.lua`
  - `lua5.1 test_map_reader.lua` passed 35 tests.
  - `git diff --check` passed.
- Current live state:
  - Last observed FCEUX position after input recovery was `(24,4)` on
    Tantegel Castle `map=0x04`; the route validation itself completed at the
    merchant stand `(24,3)`.
  - Runtime blocks for the six promoted edges are currently injected; source
    reload will clear them and pick up the permanent map data.

### TANTEGEL 4,11-4,15 EVIDENCE CONFLICT - 2026-05-22
- Goal: resolve the open handoff item about map `0x04` / Tantegel Castle
  cells `(4,11)..(4,15)`, where `MAP_BLOCKED_CELLS` fully blocked the strip
  but old directional entries/comments made it look unresolved.
- Baseline:
  - FCEUX script was polling commands.
  - Player started and was restored to `map=0x04(Tantegel Castle) (18,26)`.
  - `DOOR_STATE keys=6`, opened-door slots empty.
  - `RUNTIME_BLOCKS map=0x04 none`.
  - NPCs were frozen during probes and unfrozen afterward.
- Clean blocked verifier results:
  - `(3,11)->RIGHT`, `(3,12)->RIGHT`, `(3,13)->RIGHT`, `(3,14)->RIGHT`,
    and `(3,15)->RIGHT` each blocked `5/5`.
  - `(5,12)->LEFT`, `(5,13)->LEFT`, `(5,14)->LEFT`, and `(5,15)->LEFT`
    each blocked `5/5`.
  - `(5,11)->LEFT` was mixed on the first 5-attempt check, then blocked
    `10/10` on repeat.
  - `(4,16)->UP` into `(4,15)` blocked `5/5`.
- Remaining mixed/non-promoted edge:
  - `(4,10)->DOWN` into `(4,11)` stayed mixed (`2 moved / 3 blocked`, then
    `4 moved / 6 blocked` on repeat). Do not promote a directional blocker
    for this north edge from the mixed verifier alone.
  - A follow-up single `probe_edge:DOWN` from `(4,10)` blocked.
  - Forced-origin checks from `(4,11)` then blocked both `DOWN` into `(4,12)`
    and `UP` back to `(4,10)`, showing that even when forced onto the strip,
    the cell behaves like a stranding/sealed wall pocket.
- Code cleanup:
  - Keep `MAP_BLOCKED_CELLS[0x04]["4,11"]..["4,15"]`.
  - Remove the redundant `MAP_DIRECTIONAL_BLOCKS[0x04]` shadows for the same
    cells and delete the stale "y=13 reopened" directional note.
  - Add a focused test that the strip remains fully blocked and has no
    directional shadows.

### RIMULDAR IMPORTANT-TARGET ROUTE LOG REVIEW - 2026-05-21
- User reload/test pass after the Weapons Merchant geometry patch looked strong:
  all route attempts in the fresh log ended with
  `AUTO_WALK_NPC_PARK_RESTORE ... reason=autowalk route complete`.
- Completed route set in the log:
  - Weapons Merchant <-> Exit
  - Inn -> Exit
  - Exit -> Magic Key Merchant
  - Magic Key Merchant -> Exit
  - Exit -> Chest
  - Chest -> Exit
- The one visible Magic Key route hiccup was near the end of the inbound route:
  - `(2,8)->UP` into `(2,7)` blocked during the queued route and seam retry,
    so the runtime planner marked `(2,7)` temporarily blocked.
  - The route then tried `(2,8)->RIGHT` into `(3,8)`, first saw a transient
    block, brute-forced it, classified it noisy, and finished cleanly at the
    Magic Key Merchant stand `(4,6)` facing south.
- Direct follow-up verifiers showed these were not permanent geometry fixes:
  - `probe_edge_verify:2,8,UP,5` moved 5/5 into `(2,7)`.
  - `probe_edge_verify:16,17,RIGHT,5` moved 5/5 into `(17,17)`.
  - `probe_edge_verify:4,9,RIGHT,5` moved 5/5 into `(5,9)`.
- Conclusion:
  - no new `map_reader.lua` patch is indicated from this route sweep
  - the remaining artifacts are transient route-step timing recoveries, not
    durable blockers
  - the crawler-opened hidden paths also produced a working route from the
    Magic Key Merchant back to the main entrance
  - Rimuldar's important-target route sweep is complete enough to leave town
  - player was restored to Rimuldar `(29,13)` afterward

### RIMULDAR ENTRANCE-TO-WEAPONS MERCHANT FOLLOW-UP - 2026-05-21
- Goal: keep the town-entrance route to the Weapons Merchant service stand
  `(24,7)` reachable after the latest chest-route geometry corrections.
- Confirmed new blocker:
  - autowalk reached `(20,8)` and repeatedly tried `RIGHT` into `(21,8)`
  - `probe_edge_verify:20,8,RIGHT,5` blocked `5/5` with no drift, map change,
    refusal, or interruption
  - promoted `MAP_DIRECTIONAL_BLOCKS[0x0B]["21,8"].west`
- Route-collapse follow-up:
  - with that edge runtime-blocked, the planner no longer found the old
    entrance-to-merchant path
  - the missing bridge was the east x=29 hidden north strip below the already
    modeled x=29 upper cells
- Confirmed hidden strip:
  - `probe_edge_verify:29,13,UP,5` moved into `(29,12)` `5/5`
  - forced-origin raw probes moved `(29,12)->UP`, `(29,11)->UP`,
    `(29,10)->UP`, and `(29,9)->UP` cleanly `5/5` each
  - `(29,8)` is ordinary walkable floor, and `(29,7)` was already modeled
- Permanent patch:
  - added passthrough cells `(29,9)`, `(29,10)`, `(29,11)`, and `(29,12)`
    to `MAP_PASSTHROUGH_CELLS[0x0B]`
  - added focused `test_map_reader.lua` assertions for the new strip and
    blocker
- Reload note:
  - FCEUX needs a Lua reload before the live route planner sees these new
    permanent passthroughs.

### RIMULDAR ENTRANCE-TO-CHEST PLANNER ROUTE VIA `(23,18)` - 2026-05-21
- Goal: find a clean open route from the town entrance `(29,14)` to the Wings
  chest at `(23,23)` with both inn doors open.
- Lower/middle frontier candidates stayed unsuitable for permanent promotion:
  - `(22,25)->UP` into `(22,24)` first looked open, then blocked on a fresh
    verifier; the temporary passthrough was backed out.
  - `(21,19)->UP` into `(21,18)`, `(20,19)->UP` into `(20,18)`,
    `(22,25)->RIGHT` into `(23,25)`, and `(14,22)->RIGHT` into `(15,22)` were
    mixed/noisy and remain unpromoted.
  - `(21,25)->UP`, `(20,25)->UP`, `(14,23)->RIGHT`, and `(14,24)->RIGHT`
    verified blocked 5/5 and should stay modeled as blockers.
- Chest-side crawling exposed the useful bridge candidate `(23,18)`:
  - crawler evidence showed `(23,19)->UP` reaching `(23,18)` and `(23,18)->UP`
    continuing to `(23,17)`.
  - direct verifier from `(23,19)->UP` stayed mixed (`8 moved / 7 blocked` over
    the larger retry), so do not model that approach as clean.
  - direct verifier from the public-side approach `(23,17)->DOWN` into
    `(23,18)` moved 5/5 with no drift, refusal, map change, or interruption.
- Permanent patch:
  - added `(23,18)` to `MAP_PASSTHROUGH_CELLS[0x0B]`
  - added matching `test_map_reader.lua` assertions and snapshot coverage
- Planning result after reload:
  - `debug_pathfind_to:23,23` from `(29,14)` now finds 17-step routes through
    `(23,18)` to the chest.
  - Representative trace:
    `(29,14)->(29,15)->(28,15)->(27,15)->(26,15)->(26,16)->(26,17)->(25,17)->(24,17)->(23,17)->(23,18)->(23,19)->(23,20)->(24,20)->(24,21)->(24,22)->(24,23)->(23,23)`.
- Remaining executor issue:
  - `auto_walk:23,23` from `(29,14)` deviated into the lower exit strip and
    looped on blocked `(28,16)/(28,17)` instead of following the traced route.
  - exact `validate_path` reached `(28,15)` on retry, then overshot to
    `(27,15)` during settle and aborted after 1/17 steps.
  - Next work should focus on route queue / auto-step timing from
    `(29,15)->WEST` and why `auto_walk` deviates from the planner route, rather
    than promoting more permanent blockers.
- Tooling sync follow-up:
  - `debug_pathfind_to` / `debug_pathfind_adjacent` now use the route-manager
    coordinate planning path, so route-mode policy and debug traces come from
    the same planning layer as object/autowalk routes.
  - Use `debug_pathfind_to_park_npcs:23,23` from the entrance when comparing
    against parked-NPC autowalk behavior.
- Live validation after reload:
  - `debug_pathfind_to_park_npcs:23,23` from `(29,13)` produced an 18-step
    route through `(23,18)`:
    `(29,13)->(29,14)->(29,15)->(28,15)->(27,15)->(26,15)->(25,15)->(25,16)->(25,17)->(24,17)->(23,17)->(23,18)->(23,19)->(23,20)->(24,20)->(24,21)->(24,22)->(23,22)->(23,23)`.
  - `validate_path` reproduced the executor bug cleanly: steps 1 and 2
    completed, step 3 reached expected `(28,15)`, then the hero slid to
    `(27,15)` during the confirm window. This was post-step input carryover
    after a successful synthetic west step, not a blocked seam.
  - Patch: synthetic `inject_step` and queued-route completions/blocks now force
    the post-step neutral release path, while ordinary manual holds still keep
    the older softer behavior.
  - After live reload, this helped: the old step-3 overshoot no longer
    reproduced. Step 3 `(29,15)->WEST` reached `(28,15)` and stayed stable.
  - The next failure moved to step 4: `(28,15)->WEST` first reported a
    movement-start timeout/block, then the retry reached `(27,15)` and overshot
    to `(26,15)` during confirmation. The log shows the retry saw an early
    subpixel movement start and then scheduled a turn re-press for synthetic
    `inject_step`; that re-press likely landed while movement was already
    completing and committed the extra west tile.
  - Follow-up patch: `inject_step` no longer uses the queued-route-only
    "movement-start twitch, then turn re-press anyway" path after a retry.
    Queued routes keep that special timing behavior; debug/probe injected steps
    should now wait for completion/block instead of re-pressing into an already
    moving tile.
  - Reload follow-up:
    - The overshoot class quieted down; `validate_path` no longer slid past the
      expected tile during confirmation in the repeated checks below.
    - Direct raw verifier confirmed these runtime blockers, each with
      `moved=0 blocked=5` and no drift/map change/interruption:
      `(25,16)->DOWN`, `(24,16)->DOWN`, `(23,16)->DOWN`, `(22,16)->DOWN`,
      `(21,16)->DOWN`, `(20,16)->DOWN`, `(19,16)->DOWN`, `(21,21)->RIGHT`,
      and `(29,17)->LEFT`.
    - `probe_edge_verify:18,16,DOWN,5` and
      `probe_edge_verify:28,16,DOWN,5` both moved 5/5, so those two row-17
      entries are confirmed open crossings.
    - With the runtime blockers active, the full parked-NPC entrance-to-chest
      route from `(29,13)` validated cleanly:
      `(29,13)->(29,14)->(29,15)->(28,15)->(27,15)->(27,16)->(27,17)->(26,17)->(25,17)->(24,17)->(23,17)->(23,18)->(23,19)->(23,20)->(24,20)->(24,21)->(23,21)->(23,22)->(23,23)`.
      `VALIDATE COMPLETE: 18/18 steps OK, 0 mismatches`.
    - Permanent patch follow-up: the confirmed blockers above were promoted to
      `MAP_DIRECTIONAL_BLOCKS[0x0B]` with focused `test_map_reader.lua`
      assertions. The two 5/5 open crossings remain unblocked.

### RIMULDAR CRAWLER STALE-CANDIDATE FILTERING AND X=11 STRIP - 2026-05-21
- Live `Rimuldar (0x0B)` north-edge regression rerun from `(13,20)` no longer re-exported `(12,20)`, so the earlier timing-suspect false-wall fix held.
- That same crawl still exported three directional review candidates and two passthrough candidates:
  - passthrough: `["11,15"] = true`, `["11,16"] = true`
  - directional: `["12,19"] = {north = true}`, `["12,9"] = {south = true}`, `["9,9"] = {south = true}`
- Direct verifier follow-up split the batch:
  - `probe_edge_verify:12,18,DOWN,5` moved `5/5`, so `(12,19).north` is **not** a real blocker
  - `probe_edge_verify:12,10,UP,5` moved `5/5`, so `(12,9).south` is **not** a real blocker
  - `probe_edge_verify:9,10,UP,5` blocked `5/5`, while reverse `probe_edge_verify:9,9,DOWN,5` stayed mixed `moved=3 blocked=2`; leave `(9,9).south` review-only for now
  - `probe_edge_verify:11,17,UP,5` moved `5/5` into `(11,16)`
  - `probe_edge_verify:11,16,UP,5` could not restart there because the cell was not yet live in the running model, so five forced raw `probe_edge:UP` checks from `teleport_to:11,16,force` were used instead; all five moved into `(11,15)`
- Newly confirmed permanent map data:
  - promote `(11,15)` and `(11,16)` into `MAP_PASSTHROUGH_CELLS[0x0B]`
- New crawler bookkeeping bug and fix:
  - after the direct verifiers changed `(12,19).north` and `(12,9).south` from blocked-only to noisy/passable, `report_map_crawl` and `export_map_crawl_candidates` still emitted the old stored candidate set
  - patched `map_crawler.lua` so report/export/count paths re-check current seam classifications through `route_manager.get_seam_observation(...)`
  - directional candidates now export only while their recorded approaches are still `blocked_only` or `confirmed_blocked`
  - passthrough candidates now retain their source approaches and export only while at least one recorded approach still classifies as `passable_only`
- Focused static validation after this follow-up patch:
  - `test_map_crawler.lua`: 23 tests passed
  - `test_map_reader.lua`: 33 tests passed
  - `git diff --check`: clean

### RIMULDAR LAST CRAWLER REVIEW CANDIDATE DISPROVED - 2026-05-21
- Final live follow-up on the remaining crawler export `["9,9"] = {south = true}`:
  - `inspect_move:9,10,UP` and `inspect_move:9,9,DOWN` both reported `effective_passable=true`
  - `probe_edge_verify:UP,5` from `(9,10)` moved into `(9,9)` `5/5`
  - `probe_edge_verify:DOWN,5` from `(9,9)` moved into `(9,10)` `5/5`
- Conclusion:
  - `(9,9).south` is not a blocker and should stay open in the permanent model
  - after those verifier moves updated seam memory, `report_map_crawl` / `export_map_crawl_candidates` reported `no_review_candidates=true`
- Practical result:
  - the current Rimuldar crawler report is clean; there are no remaining review candidates from this pass

### RIMULDAR CHEST-RETURN LOOP AT (16,20) - 2026-05-21
- User-reported live chest-return autowalk loop reproduced at `Rimuldar (0x0B) (16,20)`.
- Recent route evidence before manual stop:
  - queued autowalk repeatedly tried `(16,20)->DOWN` into `(16,21)` and logged `blocked_only` again and again
  - the paired fallback `(16,20)->RIGHT` into `(17,20)` stayed noisy, not cleanly blocked
- Fresh direct follow-up from the stopped loop:
  - `inspect_move:16,20,DOWN` still previewed `effective_passable=true` despite the route failures
  - `probe_edge_verify:16,20,DOWN,5` then blocked `5/5` with no drift or map change
  - promote `(16,21).north` as a confirmed blocker now; the earlier mixed/passable notes are superseded
- Live planning consequence:
  - after temporary `add_blocked_edge:16,20,DOWN`, `debug_pathfind_to:29,13` from `(16,20)` reported `no_path`
  - the planner had been depending on that seam, so the honest new state is that the current permanent model does not yet contain an alternate bridge from this lower chest-return pocket back toward the entrance
- Lower-pocket follow-up around `(17,20)` / `(17,21)` / `(17,22)`:
  - bounded crawls from `(16,20)` and `(17,22)` found no new exportable candidates
  - both runs repeatedly hit an execution anomaly on the `return_to_frontier` step `(17,21)->UP`, once landing at `(17,22)` and aborting as `movement_drift`
  - direct `probe_edge_verify:17,21,UP,5` came back mixed `moved=3 blocked=2`, so do not promote anything there yet
  - `inspect_move` from `(17,22)` shows `UP`, `DOWN`, and `LEFT` modeled open; only `RIGHT` is currently blocked by NPC occupancy
- Practical next state:
  - patch the confirmed blocker `(16,21).north`
  - treat the remaining lower-pocket issue as “missing bridge or execution anomaly still unresolved,” not as another confirmed blocker yet

### CRAWLER FALSE-POSITIVE FILTER TIGHTENING - 2026-05-21
- Root cause of the remaining crawler false-positive path:
  - `mixed_probe` already suppressed cases like `Rimuldar (0x0B) (24,6).south` where a false-wall edge first blocked and then moved on a later crawler attempt.
  - The unresolved bad export path was different: a false-wall move that completed only after the `auto_step` timeout/turn-repress recovery path could still land on the destination and be recorded as a normal `false_wall_candidate`.
  - That is what happened on the earlier `Rimuldar (0x0B) (12,20)` crawl export: the move into `(12,20)` was timing-suspect, not a clean first-pass false-wall crossing.
- Permanent patch:
  - `auto_step.lua` now includes step-completion timing metadata (`timeout_retries`, `turn_represses`, `frames`, `inject_limit`) on `route_step_completed` events.
  - `map_crawler.lua` now classifies false-wall moves completed through `pending_repress` or any timeout/repress retry path as `timing_suspect_false_wall` instead of a normal `false_wall_candidate`.
  - Those timing-suspect cells are marked `MAP_CRAWL_UNSTABLE_CANDIDATE` for the rest of the run, so later same-run re-entries do not get re-exported as ordinary passthroughs.
- Focused tests added and passed:
  - `pending_repress_false_wall_stays_diagnostic_and_exports_nothing` in `test_map_crawler.lua`
  - full focused validation after the patch:
    - `test_map_crawler.lua`: 21 tests passed
    - `test_map_reader.lua`: 33 tests passed
    - `test_auto_step.lua`: 51 tests passed
    - `git diff --check`: clean

### RIMULDAR POST-RELOAD LIVE VALIDATION - 2026-05-21
- Reload validation of the new `stop_map_crawl` behavior succeeded live on `Rimuldar (0x0B)`:
  - A long crawl from `(24,7)` was manually stopped while an in-flight `down` step from `(23,2)` was active.
  - The running script logged `MAP_CRAWL_STOP_WAIT`, then `MAP_CRAWL_STOP_SETTLED ... final=(23,2) expected=(23,3) reason=no_post_stop_movement`, then `MAP_CRAWL_FINISH ... reason=manual_stop`.
  - A delayed `report_position` still showed the hero stable at `(23,2)`, so the earlier “finish now, drift later” bug is fixed live.
- Reload follow-up on the unresolved `x=12` south candidate disproved it:
  - Fresh `probe_edge_verify:12,19,DOWN,5` blocked `5/5` into `(12,20)` with `classification=confirmed_blocked`.
  - Do **not** promote `(12,20)`; leave it closed and treat the earlier crawl export as a false positive.
- Cleanup after reload validation:
  - no new code changes were needed beyond the already-patched stop fix and earlier passthrough promotions
  - restore hero to safe `Rimuldar (0x0B)` baseline before the next crawl

### RIMULDAR CRAWLER FOLLOW-UP AND STOP SAFETY - 2026-05-21
- Live continuation test from `Rimuldar (0x0B) (24,7)` did **not** extend the hidden strip westward. Instead, the bounded crawl exported one directional candidate:
  - `["24,6"] = {south = true}`
- Direct verifier disproved that candidate immediately:
  - `probe_edge_verify:24,7,UP,5` moved into `(24,6)` `5/5` with `classification=confirmed_passable`, no drift, no timeout, and no map change.
  - Treat `["24,6"] = {south = true}` as a crawler false positive, not map data.
- North-edge regression retest from `Rimuldar (0x0B) (13,20)` still behaved correctly at the unstable frontier:
  - `(13,1)` again logged `MAP_CRAWL_UNSTABLE_CANDIDATE` and backtracked instead of wandering sideways.
  - The same run continued down the adjacent `x=12` strip and exported four new passthrough candidates:
    - `["12,15"] = true`
    - `["12,16"] = true`
    - `["12,18"] = true`
    - `["12,20"] = true`
- Direct verifier follow-up:
  - `probe_edge_verify:12,14,DOWN,5` confirmed `(12,15)` passable `5/5`
  - `probe_edge_verify:12,17,UP,5` confirmed `(12,16)` passable `5/5`
  - `probe_edge_verify:12,17,DOWN,5` confirmed `(12,18)` passable `5/5`
  - `probe_edge_verify:12,19,DOWN,5` for `(12,20)` came back mixed: `moved=4 blocked=1`
- Permanent patch:
  - Added `(12,15)`, `(12,16)`, and `(12,18)` to `MAP_PASSTHROUGH_CELLS[0x0B]` in `map_reader.lua`
  - Left `(12,20)` review-only because the verifier was mixed
- Stop-safety harness result:
  - `stop_map_crawl` during an in-flight backtrack at `(22,1)->DOWN` reported `manual_stop`, but the hero later settled at `(22,2)`.
  - Root cause: `map_crawler.stop()` finished immediately after canceling `auto_step`, so the crawler stopped tracking before a committed tile could settle.
  - Fix: `map_crawler.lua` now defers `manual_stop` cleanup when `auto_step` reports `movement_started=true`, waits up to a short settle window for the player to land or remain still, then restores parked NPCs and finishes the run.
  - Added `auto_step.get_active_step_state()` plus a focused crawler regression test covering the deferred-stop path.
- Focused static validation passed after the patch:
  - `test_map_crawler.lua`: 20 tests passed
  - `test_map_reader.lua`: 33 tests passed
  - `git diff --check`: clean
- Cleanup after the live pass:
  - restored normal play state with `unfreeze_npcs`
  - teleported hero back to `Rimuldar (0x0B) (29,14)`
  - confirmed both door slots `(21,21)` and `(22,23)` stayed open

### RIMULDAR X=24 FRONTIER ADVANCE - 2026-05-21
- The latest user-run bounded crawl started from `Rimuldar (0x0B) (25,3)` after reload and exported three new passthrough candidates:
  - `["24,2"] = true`
  - `["24,3"] = true`
  - `["24,4"] = true`
- The crawl evidence was strong enough to promote directly without a separate verifier loop:
  - `(25,2)->LEFT` moved into `(24,2)`, then `(24,1)->DOWN` and `(24,3)->UP` both returned into `(24,2)`.
  - `(24,2)->DOWN` moved into `(24,3)`, and `(24,3)->UP` returned into `(24,2)`.
  - `(24,3)->DOWN` moved into `(24,4)`, `(24,4)->UP` returned into `(24,3)`, and `(24,4)->DOWN` kept moving onward into normal floor at `(24,5)`.
  - The same crawl then continued through existing hidden-strip bridge `(24,6)` and onward into `(24,7)`, which confirms these new cells are part of the same live route rather than isolated noise.
- Important non-promotion from the same pass:
  - `(26,3)->DOWN` into `(26,4)` stayed `class=modeled_blocked`, so `(26,4)` remains a normal wall, not a passthrough candidate.
- Permanent patch:
  - Added `(24,2)`, `(24,3)`, and `(24,4)` to `MAP_PASSTHROUGH_CELLS[0x0B]` in `map_reader.lua`
  - Added matching assertions and snapshot checks to `test_map_reader.lua`

### RIMULDAR X=25/X=26 FRONTIER ADVANCE - 2026-05-21
- The latest user-run bounded crawl started from `Rimuldar (0x0B) (27,3)` after reload and exported four new passthrough candidates:
  - `["26,2"] = true`
  - `["26,3"] = true`
  - `["25,3"] = true`
  - `["25,2"] = true`
- The same crawl also showed `MAP_CRAWL_EDGE ... from=(26,3) dir=down dest=(26,4) class=modeled_blocked blocked_attempts=1`, so `(26,4)` remains a normal modeled wall, not a passthrough target.
- Direct confirmation:
  - `probe_edge_verify:LEFT,5` from `(27,2)` -> `(26,2)` moved `5/5` with `classification=confirmed_passable`, no drift, timeout, or map change.
  - Five forced raw `probe_edge:DOWN` checks from `(26,2)` all moved into `(26,3)`.
  - Five forced raw `probe_edge:LEFT` checks from `(26,3)` all moved into `(25,3)`.
  - Five forced raw `probe_edge:UP` checks from `(25,3)` all moved into `(25,2)`.
- Permanent patch:
  - Added `(26,2)`, `(26,3)`, `(25,3)`, and `(25,2)` to `MAP_PASSTHROUGH_CELLS[0x0B]` in `map_reader.lua`
  - Added matching assertions to `test_map_reader.lua`
- Focused static validation passed:
  - `test_map_reader.lua`: 33 tests passed
  - `git diff --check`: clean
- Cleanup after the pass:
  - restored normal state with `unfreeze_npcs`
  - teleported hero back to `(29,14)`
  - confirmed both Rimuldar door slots `(21,21)` and `(22,23)` stayed open

### RIMULDAR X=27 FRONTIER ADVANCE - 2026-05-21
- After reloading the newly promoted `(28,7)` passthrough, the next bounded crawler test started from `Rimuldar (0x0B) (28,7)`:
  - `reset_map_crawl`
  - `freeze_npcs teleport_to:28,7 report_position`
  - `crawl_map_frontier:attempts=1,max_edges=12`
  - `report_map_crawl export_map_crawl_candidates`
- Result:
  - `MAP_CRAWL_FINISH run=1 map=0x0B completed=false reason=max_edges edges=15 passthrough_candidates=2 directional_candidates=0 stationary_npc_cells=0 transitions=2`
  - Exported candidates: `["27,2"] = true`, `["27,3"] = true`
- Direct confirmation:
  - `probe_edge_verify:LEFT,5` from `(28,2)` -> `(27,2)` moved `5/5` with `classification=confirmed_passable`, no drift, timeout, or map change.
  - Repeated verifier still could not normalize origin `(27,2)` because it was not yet modeled live, so `(27,3)` was checked with forced raw probes instead:
    - five separate cycles of `freeze_npcs teleport_to:27,2,force report_position` plus `probe_edge:DOWN`
    - every attempt logged `EDGE_PROBE_RESULT ... status=moved final=(27,3) ... reason=position_changed`
- Permanent patch:
  - Added `(27,2)` and `(27,3)` to `MAP_PASSTHROUGH_CELLS[0x0B]` in `map_reader.lua`
  - Added matching assertions to `test_map_reader.lua`
- Focused static validation passed:
  - `test_map_reader.lua`: 33 tests passed
  - `git diff --check`: clean
- Cleanup after the pass:
  - restored normal state with `unfreeze_npcs`
  - teleported hero back to `(29,14)`
  - confirmed both Rimuldar door slots `(21,21)` and `(22,23)` stayed open

### RIMULDAR UPPER-STRIP FOLLOW-UP AFTER `(28,2)` RELOAD - 2026-05-21
- After the user reloaded FCEUX Lua with `(28,2)` live, a repeat forced-start crawl from `(29,9)` on Rimuldar `(0x0B)` no longer exported any new review candidates:
  - `MAP_CRAWL_FINISH run=1 map=0x0B completed=false reason=max_edges edges=14 passthrough_candidates=0 directional_candidates=0 stationary_npc_cells=0 transitions=1`
  - `report_map_crawl export_map_crawl_candidates` returned `no_review_candidates=true`.
- Interpretation: this was the expected “frontier absorbed” result. The earlier `(28,2)` candidate is now modeled correctly enough that the same upper-strip crawl no longer rediscovers it.

### RIMULDAR X=28 FRONTIER ADVANCE - 2026-05-21
- Next bounded crawler test started from live passthrough `(28,2)` on Rimuldar `(0x0B)`:
  - `reset_map_crawl`
  - `freeze_npcs teleport_to:28,2 report_position`
  - `crawl_map_frontier:attempts=1,max_edges=12`
  - `report_map_crawl export_map_crawl_candidates`
- Result:
  - `MAP_CRAWL_FINISH run=2 map=0x0B completed=false reason=max_edges edges=18 passthrough_candidates=4 directional_candidates=0 stationary_npc_cells=0 transitions=1`
  - Exported candidates: `["28,3"] = true`, `["28,4"] = true`, `["28,6"] = true`, `["28,7"] = true`
- Clean direct verifier follow-up:
  - `probe_edge_verify:DOWN,5` from `(28,2)` -> `(28,3)` moved `5/5`, `classification=confirmed_passable`
  - `probe_edge_verify:UP,5` from `(28,5)` -> `(28,4)` moved `5/5`, `classification=confirmed_passable`
  - `probe_edge_verify:DOWN,5` from `(28,5)` -> `(28,6)` moved `5/5`, `classification=confirmed_passable`
- Remaining holdout:
  - Initial forced `probe_edge_verify:DOWN,5` from `(28,6)` failed as `classification=inconclusive_control reason=teleport_failed:not walkable`
  - After reloading the newly promoted `(28,6)` passthrough, the same verifier completed cleanly:
    - `EDGE_VERIFY_RESULT map=0x0B from=(28,6) dir=down dest=(28,7) attempts=5 moved=5 blocked=0 timed_out=0 refused=0 drifted=0 map_changed=0 interrupted=0 classification=confirmed_passable`
  - `(28,7)` is now promoted too.
- Permanent patch:
  - Added `(28,3)`, `(28,4)`, `(28,6)`, and `(28,7)` to `MAP_PASSTHROUGH_CELLS[0x0B]` in `map_reader.lua`
  - Added matching assertions to `test_map_reader.lua`
- Focused static validation passed:
  - `test_map_reader.lua`: 33 tests passed
  - `git diff --check`: clean
- Cleanup after the pass:
  - restored normal state with `unfreeze_npcs`
  - teleported hero back to `(29,14)`
  - confirmed both Rimuldar door slots `(21,21)` and `(22,23)` stayed open

### RIMULDAR UPPER X=29 STRIP CRAWLER FOLLOW-UP - 2026-05-21
- Goal: resume the next crawler test from above the earlier `(29,10)` choke so the north-edge behavior could be observed without the lower-strip contamination.
- Baseline before test: `POSITION map=0x0B(Rimuldar) x=29 y=14`, both doors still open, `RUNTIME_BLOCKS map=0x0B none`.
- `teleport_to:29,9` was refused because `(29,9)` is still modeled non-walkable (`tile=0x00`), so the focused test used `teleport_to:29,9,force`.
- Bounded crawler result from forced start `(29,9)`:
  - `MAP_CRAWL_FINISH run=1 map=0x0B completed=false reason=max_edges edges=14 passthrough_candidates=1 directional_candidates=0 stationary_npc_cells=0 transitions=1`
  - The `transitions=1` count is expected here because `boundary_frontier` shares the transitions bucket; there was no world-map change.
  - Boundary behavior stayed correct: `(29,1)->UP dest=(29,0)` logged `class=boundary_frontier note=destination_boundary`, and the crawl backtracked to `(29,2)` instead of leaving town.
  - New review-only export from this pass: `MAP_CRAWL_EXPORT_PASSTHROUGH map=0x0B line='["28,2"] = true,'`
- Direct verifier follow-up:
  - `probe_edge_verify:29,2,LEFT,5` moved into `(28,2)` `5/5` with `classification=confirmed_passable`, no drift, no timeout, no map change, and no runtime block injection.
  - The crawl itself had already shown onward route evidence by moving `(28,2)->UP` into `(28,1)`.
- Permanent patch:
  - Added `(28,2)` to `MAP_PASSTHROUGH_CELLS[0x0B]` in `map_reader.lua`.
  - Added `(28,2)` to the northeast false-wall strip assertion list in `test_map_reader.lua`.
- Focused static validation passed:
  - `test_map_reader.lua`: 33 tests passed.
  - `git diff --check`: clean.
- Cleanup after the test: restored normal state with `unfreeze_npcs`, teleported back to `(29,14)`, and confirmed both door slots `(21,21)` and `(22,23)` were still open.

### RIMULDAR EXIT-SEAM CLASSIFIER FOLLOW-UP - 2026-05-21
- Direct live verifier recheck on the restored two-door state confirmed `(29,13)->LEFT` into `(28,13)` is a real one-way seam, not a noisy candidate:
  - `probe_edge_verify:29,13,LEFT,5` blocked `5/5` with `classification=confirmed_blocked`.
  - Reverse `probe_edge_verify:28,13,RIGHT,5` stepped onto `(29,13)` and immediately map-changed to `0x01`, so treat `(29,13)` as the live exit tile rather than a symmetric blocker.
- Permanent map patch: `map_reader.lua` now models `["28,13"] = {south = true, east = true}` and `test_map_reader.lua` pins the new `east` approach block.
- Root cause of the duplicate crawler export: `map_crawler.classify_blocked()` was only checking whether the destination tile was generally walkable. It did not suppress probes whose specific blocked approach was already present in `map_reader.get_directional_blocks(map_id)`.
- Permanent crawler patch: `map_crawler.lua` now classifies an already-modeled approach as `modeled_blocked note=approach_already_modeled` instead of re-exporting it as a fresh `directional_block_candidate`.
- Static validation on Windows LuaJIT passed after the fix:
  - `test_map_crawler.lua`: 19 tests passed, including new `already_modeled_directional_block_is_not_reexported`.
  - `test_map_reader.lua`: 33 tests passed.
  - `git diff --check`: clean.
- Live state after the user's latest restore/probe: `POSITION map=0x0B(Rimuldar) x=29 y=16`, `DOOR_STATE` still shows both open door slots `(21,21)` and `(22,23)`.
- Remaining live step: FCEUX must reload Lua before rerunning the bounded Rimuldar crawl, otherwise the active script will still use the old crawler classifier.

### RIMULDAR 29,14 BOUNDED RERUN AFTER RELOAD - 2026-05-21
- After manual FCEUX Lua reload, live baseline was clean: `POSITION map=0x0B(Rimuldar) x=29 y=16`, both doors still open, and `RUNTIME_BLOCKS map=0x0B none`.
- Rerun command sequence:
  - `reset_map_crawl`
  - `freeze_npcs teleport_to:29,14 report_position`
  - `crawl_map_frontier:attempts=1,max_edges=12`
  - `report_map_crawl export_map_crawl_candidates`
- Result: the rerun finished cleanly with `MAP_CRAWL_FINISH run=1 map=0x0B completed=false reason=max_edges edges=12 passthrough_candidates=4 directional_candidates=0 stationary_npc_cells=0 transitions=0`.
- Most important regression check: the old export `["28,13"] = {east = true}` did **not** reappear. `directional_candidates=0` confirms the running crawler respected the new already-modeled-approach suppression.
- New review-only exports from this run were passthrough candidates on the same north-side strip:
  - `["29,9"] = true`
  - `["29,10"] = true`
  - `["29,11"] = true`
  - `["29,12"] = true`
- Interpretation: this was a successful live proof for the classifier fix. The next useful investigation is no longer the `(28,13).east` seam; it is whether the remaining north-strip cells `(29,9)` through `(29,12)` should join the earlier `MAP_PASSTHROUGH_CELLS[0x0B]` entries on that same column.
- Cleanup after rerun: restored normal play state with `unfreeze_npcs`, teleported hero back to safe `(29,14)`, and rechecked that both doors were still open.

### RIMULDAR 29,14 BOUNDED CRAWLER RETEST - 2026-05-21
- Test command: `reset_map_crawl freeze_npcs teleport_to:29,14 report_position`, then `crawl_map_frontier:attempts=1,max_edges=12`, followed by `report_map_crawl` and `export_map_crawl_candidates`.
- Result: the crawl stayed stable and restored parked NPCs, but it did **not** reproduce the old north-edge boundary case because a stationary NPC blocked the vertical strip at `(29,10)`. The run stopped at `max_edges` with `MAP_CRAWL_FINISH ... reason=max_edges edges=17 passthrough_candidates=0 directional_candidates=1 stationary_npc_cells=1 transitions=2`.
- Safety/behavior checks that passed:
  - no map transition or movement drift occurred;
  - `boundary_frontier` still prevented probing past the east boundary at `(30,11)` / `(30,12)`;
  - unstable boundary-origin cells `(29,11)` and `(29,12)` backtracked instead of probing sideways;
  - `MAP_CRAWL_NPC_PARK_RESTORE ... restored=true restored_slots=5 reason=max_edges`.
- New review candidate from this run: `MAP_CRAWL_EXPORT_DIRECTIONAL map=0x0B line='["28,13"] = {east = true},'`, coming from `(29,13)->LEFT` blocking once while the model thought `(28,13)` was open.
- Follow-up interpretation: this was a useful stability test, but not a clean north-edge regression test. For the actual north-edge case, start above the `(29,10)` stationary NPC (for example the earlier proven `(29,9)` strip) or use a nearby column with a clear route to `y=1`.

### CRAWLER SHAKEDOWN - 2026-05-21
- First live `crawl_map_frontier:attempts=2,max_edges=40` started at Rimuldar `(29,13)`, not the safer `(29,14)` suggested in chat. It parked 10 mobile NPC slots.
- The crawler walked north on x=29 through cells `(29,12)` down to `(29,0)`, then probed `(29,0)->UP` toward out-of-bounds `(29,-1)`. That triggered `EVENT: map change -> 0x01 (World Map)` and landed at world `(102,72)`.
- Bug 1: `tick()` saw the map change before the `route_step_completed` callback classified the active edge, so the report finished with `transitions=0` instead of recording the edge as a transition candidate.
- Bug 2: boundary/engine-boundary destinations were treated like ordinary false-wall candidates, so the crawler could walk onto/probe the north boundary and physically leave town.
- Patch applied: `map_crawler` now preflight-skips out-of-bounds and `engine_boundary` destinations as `boundary_frontier`, records active-edge `transition_candidate` when `tick()` sees a map change first, and bare `report_map_crawl` uses the latest crawl map after a transition instead of defaulting to the current world map.
- Validation after patch: `luac -p map_crawler.lua main.lua test_map_crawler.lua`, `lua test_map_crawler.lua` (13 tests), `lua test_map_reader.lua` (33), `lua test_map_survey.lua` (45), `lua test_debug_tools.lua` (5), and `git diff --check` passed; only the known `dw_access.ini` CRLF warning appeared.
- Live state check after the user's manual re-entry: `report_position` returned `map=0x0B(Rimuldar) x=29 y=9`. Patched Lua still needs FCEUX script reload before another live crawler run.

### CRAWLER SHAKEDOWN 2 - 2026-05-21
- The next live `crawl_map_frontier:attempts=2,max_edges=40` started at Rimuldar `(29,13)` after the user reloaded Lua.
- Boundary preflight worked: the crawler logged `(29,1)->UP dest=(29,0)` as `boundary_frontier` instead of walking the player out of town.
- Bug 3: the preflight boundary record had `run=0 map=0x00` because skipped edges were recorded before inheriting the active crawl run/map IDs.
- Bug 4: after probing a known neighbor, the `return_to_frontier` completion was handled like a normal discovery. That scheduled the reverse return again, producing a live ping-pong between `(29,1)` and `(29,2)` and growing the report to 324 edges before manual stop.
- Live stop: `stop_map_crawl` restored parked NPCs (`restored_slots=2`) and finished with `reason=manual_stop`.
- Patch applied: preflight records now fall back to the active crawler run/map, and completed `return_to_frontier` moves return immediately like backtracks.
- Patched Lua needs FCEUX script reload before another live crawler run.

### POST-STOP TOWN EXIT - 2026-05-21
- The later town exit was not logged as a crawler probe. After the stopped crawl left the hero near the north edge, FCEUX logged an external bridge/manual-tap `Up` from `(29,1)` to `(29,0)`, followed by `EVENT: map change -> 0x01 (World Map)`.
- The user manually returned to Rimuldar; live `report_position` confirmed `map=0x0B(Rimuldar) x=29 y=14`.
- `report_map_crawl` still showed the old contaminated 324-edge report, so `reset_map_crawl` was queued and confirmed with `MAP_CRAWL_RESET map=0x0B`.
- FCEUX input recovery logged `INPUT_STATUS tag=fceux_recovery keys=- joy1=- left_alt=false`, but a later held/stale `Up` moved the hero from `(29,14)` to `(29,13)`. Avoid live crawler movement until input is quiet and the patched Lua is reloaded.
- Patch applied: crawler manual stop, low-HP abort, and script-error abort now call `auto_step.cancel_active_step(true, true)` to force-release injected auto-step input.

### LIVE PATCHED CRAWLER TEST - 2026-05-21
- After user-confirmed script reload/menu clear, live baseline was Rimuldar `(29,9)` with only the known `LeftAlt` latch and no joypad direction. `reset_map_crawl` confirmed.
- Test command: `crawl_map_frontier:attempts=1,max_edges=12`.
- Result: finished cleanly with `MAP_CRAWL_FINISH run=1 map=0x0B completed=false reason=max_edges edges=13 passthrough_candidates=5 directional_candidates=0 stationary_npc_cells=0 transitions=2`.
- Boundary behavior verified live: `(29,1)->UP dest=(29,0)` and `(28,1)->UP dest=(28,0)` logged as `boundary_frontier` with active `run=1 map=0x0B`; no world-map transition occurred.
- Return behavior verified live: after probing `(29,1)->DOWN` into known `(29,2)`, exactly one `return_to_frontier` moved back to `(29,1)`, then the crawler continued with `(29,1)->LEFT` instead of ping-ponging.
- NPC parking restored at finish: `MAP_CRAWL_NPC_PARK_RESTORE ... restored=true restored_slots=2 reason=max_edges`.
- Review-only export from this small run produced passthrough candidates `29,2`, `29,3`, `29,4`, `29,6`, and `29,7`; treat them as candidates for review, not permanent map edits.
- After the crawl left the hero near the north edge at `(28,1)`, Codex teleported back to safer `(29,14)` and confirmed `POSITION: map=0x0B(Rimuldar) x=29 y=14`.

### CRAWLER SHAKEDOWN 3 - 2026-05-21
- Test command: from Rimuldar `(13,20)`, `crawl_map_frontier:attempts=2,max_edges=60`.
- Result: stopped manually after a live movement-drift bug. The crawler walked north through the south-side connector to `(13,1)`, preflight-skipped `(13,1)->UP dest=(13,0)` as `boundary_frontier`, then probed `(13,1)->DOWN dest=(13,2)`.
- Bug: auto_step reported `dir=down from=(13,1)` but completed at `(13,0)`, while the crawler accepted the edge as if it had landed at `(13,2)`. It then tried a `return_to_frontier` from `(13,2)` while the live hero was actually at `(13,0)`.
- Safety response: `stop_map_crawl` restored 4 parked NPC slots, and Codex moved the hero back to `(29,14)`.
- Patch applied: crawler now records `movement_drift` and aborts if a completed step lands anywhere other than the expected destination, and records `position_drift`/aborts before injecting an edge if the live position does not match the edge origin. These drift records are diagnostic only and do not export map candidates.

### X=29 CRAWLER CANDIDATE FOLLOW-UP - 2026-05-21
- The lack of blocker sounds is consistent with the crawler output: these were `false_wall_candidate` records, meaning movement succeeded into cells the current model marks non-walkable. They are not blocker candidates.
- Direct verifier results:
  - `(29,8)->UP` into `(29,7)`: moved 5/5, `classification=confirmed_passable`.
  - `(29,5)->DOWN` into `(29,6)`: moved 5/5, `classification=confirmed_passable`.
  - `(29,5)->UP` into `(29,4)`: moved 5/5, `classification=confirmed_passable`.
  - `(29,1)->DOWN` into `(29,2)`: moved 5/5, `classification=confirmed_passable`.
- Chained hidden-origin follow-up:
  - Explicit `probe_edge_verify:29,7,UP,5` was inconclusive because relocation to `(29,7)` is refused while the model still marks it non-walkable.
  - Force-origin raw probe from `(29,2)->DOWN` moved into `(29,3)`.
  - Force-origin raw probe from `(29,4)->UP` moved into `(29,3)`.
- Current interpretation: `29,2`, `29,4`, `29,6`, and `29,7` are clean passthrough candidates; `29,3` is very likely part of the same vertical hidden strip but needs a post-model-update verifier if promoted.
- Hero restored to safer Rimuldar entrance-side tile `(29,14)` after testing.
- Permanent patch: added `MAP_PASSTHROUGH_CELLS[0x0B]` entries for `29,2`, `29,3`, `29,4`, `29,6`, and `29,7`, plus `test_map_reader.lua` assertions. `29,3` is documented as the chained force-origin raw-probe cell; optional follow-up after reload is `probe_edge_verify:29,2,DOWN,5` or `probe_edge_verify:29,4,UP,5`.
- Post-patch reload follow-up: after the user manually reloaded FCEUX Lua, `probe_edge_verify:29,2,DOWN,5` and `probe_edge_verify:29,4,UP,5` both moved into `(29,3)` 5/5 with no refused attempts, drift, map change, timeout, or interruption. `29,3` is now cleanly confirmed passable from both sides. Hero restored to `(29,14)`.

### CRAWLER SHAKEDOWN 3 - 2026-05-21
- After script reload, bounded crawl from `(13,20)` with `crawl_map_frontier:attempts=2,max_edges=60` parked 1 mobile NPC and walked the west-side vertical strip north. It stopped safely on the old edge case: `(13,1)->DOWN` intended `(13,2)` but landed at `(13,0)`, now classified as `movement_drift`; parked NPCs were restored.
- Initial export listed passthrough candidates `(13,1)`, `(13,2)`, and `(13,4)`. Direct verifier follow-up promoted only the clean cells:
  - `probe_edge_verify:13,5,UP,5` moved into `(13,4)` 5/5 with no drift/map change/refusal.
  - `probe_edge_verify:13,3,UP,5` moved into `(13,2)` 5/5 with no drift/map change/refusal.
  - `probe_edge_verify:13,2,UP,5` was inconclusive because the verifier reset refused origin `(13,2)` before the passthrough patch was loaded.
- Force-origin raw probes from `(13,2)->UP` moved into `(13,1)` 3/3, but the hero later settled at `(13,0)` before a reverse probe could start. Treat `(13,1)` as an unstable north-edge frontier, not a normal passthrough candidate, until a post-patch verifier or dedicated exit model can classify it.
- Permanent patch: added `MAP_PASSTHROUGH_CELLS[0x0B]` entries for `(13,2)` and `(13,4)` only, plus `test_map_reader.lua` assertions. Also tightened `map_crawler.lua` so a false-wall candidate is removed from export if that same cell later acts as the origin of a boundary, transition, position-drift, or movement-drift edge.
- Post-reload live retest from `(13,20)` confirmed `(13,4)` and `(13,2)` now classify as `open_floor` / `model_reason=passthrough`, and `(13,1)` logs `MAP_CRAWL_UNSTABLE_CANDIDATE` instead of exporting. New issue found: because `(13,1)->DOWN` now returns cleanly to `(13,2)`, the old runtime kept exploring sideways from unstable `(13,1)` and exported `(12,2)` after crawling through `(12,1)`. Treat that `(12,2)` export as frontier-contaminated evidence, not a map patch.
- Follow-up patch: unstable cells are now backtrack-only during the same crawl. Once a cell becomes a boundary/transition/drift origin, the crawler will backtrack instead of probing its remaining directions. This should suppress the `(13,1)->(12,1)->(12,2)` artifact after the next script reload.
- Post-backtrack-only reload: bounded crawl from `(13,20)` proved the fix live. `(13,1)` logged `MAP_CRAWL_UNSTABLE_CANDIDATE`, immediately backtracked down to `(13,2)`, and did not probe `(13,1)->LEFT` / `(12,1)`. The crawl then legitimately entered x=12 from stable origins and exported `(12,2)`, `(12,8)`, `(12,9)`, and `(12,11)`.
- Direct verifier follow-up confirmed all four 5/5 passable with no drift/map change/refusal/timeout:
  - `probe_edge_verify:13,2,LEFT,5` -> `(12,2)` moved 5/5.
  - `probe_edge_verify:12,7,DOWN,5` -> `(12,8)` moved 5/5.
  - `probe_edge_verify:12,10,UP,5` -> `(12,9)` moved 5/5.
  - `probe_edge_verify:12,10,DOWN,5` -> `(12,11)` moved 5/5.
- Permanent patch: added `MAP_PASSTHROUGH_CELLS[0x0B]` entries for `(12,2)`, `(12,8)`, `(12,9)`, and `(12,11)`, plus test assertions.

### CLEAN / PROMOTED
- Map 0x0B `(23,20)->LEFT`: after reload/menu-clear, return autowalk looped on this shelf entry; direct `probe_edge_verify:23,20,LEFT,5` blocked 5/5 with no drift/map change. Promoted `(22,20).east`.
- Map 0x0B `(20,20)->DOWN`: return reroute repeatedly tried row-20 south exit; direct `probe_edge_verify:20,20,DOWN,5` blocked 5/5. Promoted `(20,21).north`.
- Map 0x0B `(19,20)->DOWN`: next row-20 fallback; direct `probe_edge_verify:19,20,DOWN,5` blocked 5/5. Promoted `(19,21).north`.
- Map 0x0B `(18,20)->DOWN`: next row-20 fallback; direct `probe_edge_verify:18,20,DOWN,5` blocked 5/5. Promoted `(18,21).north`.
- Map 0x0B `(17,21)->RIGHT`: after the row-20 south exits were runtime-injected, return route tried entering `(18,21)` from the west; direct `probe_edge_verify:17,21,RIGHT,5` blocked 5/5. Promoted `(18,21).west`.
- Map 0x0B `(14,19)->RIGHT`: after closing the command menu, `probe_edge_verify:RIGHT,3` blocked 3/3 while `(15,19)->LEFT` moved 3/3. Promoted `(15,19).west`.
- Map 0x0B `(13,20)`: `probe_edge_verify:13,21,UP,5` moved 5/5 into `(13,20)`, and a force-origin raw `probe_edge:UP` from `(13,20)` moved into `(13,19)`. Promoted `(13,20)` as a passthrough cell.
- Map 0x0B `(14,23)->RIGHT`: return-route planner tried entering `(15,23)` from the west; direct verifier blocked 5/5. Promoted `(15,23).west`.
- Map 0x0B `(14,24)->RIGHT`: likely fallback after `(15,23).west`; direct verifier blocked 5/5. Promoted `(15,24).west`.
- Map 0x0B `(21,25)->UP`: autowalk looped on the row-25 fallback; direct `probe_edge_verify:21,25,UP,5` blocked 5/5 with no drift/map change. Promoted `(21,24).south`.
- Map 0x0B `(15,25)->UP`: same lower-row fallback loop; direct `probe_edge_verify:15,25,UP,5` blocked 5/5 with no drift/map change. Promoted `(15,24).south`.
- Map 0x0B `(16,27)->RIGHT`: next entrance-to-chest autowalk reroute reached `(16,27)`; direct `probe_edge_verify:16,27,RIGHT,5` blocked 5/5 with no drift/map change. Promoted `(17,27).west`.
- Map 0x0B `(16,27)->DOWN`: same reroute; direct `probe_edge_verify:16,27,DOWN,5` blocked 5/5 with no drift/map change. Promoted `(16,28).north`.
- Map 0x0B `(15,27)->DOWN`: coordinate autowalk reroute reached `(15,27)`; direct `probe_edge_verify:15,27,DOWN,5` blocked 5/5 with no drift/map change. Promoted `(15,28).north`.
- Map 0x0B `(13,26)->LEFT`: parked-NPC entrance-to-chest route tried the lower west branch; direct `probe_edge_verify:13,26,LEFT,5` blocked 5/5. Promoted `(12,26).east`.
- Map 0x0B `(13,25)->LEFT`: fallback from the same branch; direct `probe_edge_verify:13,25,LEFT,5` blocked 5/5. Promoted `(12,25).east`.
- Map 0x0B `(13,23)->LEFT`: next west-branch reroute; direct `probe_edge_verify:13,23,LEFT,5` blocked 5/5. Promoted `(12,23).east`.
- Map 0x0B `(13,24)->LEFT`: paired west-branch reroute; direct `probe_edge_verify:13,24,LEFT,5` blocked 5/5. Promoted `(12,24).east`.
- Map 0x0B `(13,22)->LEFT`: west-branch entry shifted upward again; direct `probe_edge_verify:13,22,LEFT,5` blocked 5/5. Promoted `(12,22).east`.
- Map 0x0B `(13,21)->LEFT`: final upper west-branch entry; direct `probe_edge_verify:13,21,LEFT,5` blocked 5/5. Promoted `(12,21).east`.
- Map 0x0B `(23,20)->DOWN`: chest-return planner looped on the upper shelf; direct `probe_edge_verify:23,20,DOWN,5` blocked 5/5. Promoted `(23,21).north`.
- Map 0x0B `(23,22)->UP`: return autowalk from the chest-side stand repeatedly failed into `(23,21)`; direct verifier blocked 5/5. Promoted `(23,21).south`.
- Map 0x0B `(23,22)->LEFT`: paired row-22 shelf fallback; direct verifier blocked 5/5. Promoted `(22,22).east`.
- Map 0x0B `(24,22)->UP`: next return fallback tried `(24,21)`; direct verifier blocked 5/5. Promoted `(24,21).south`.
- Map 0x0B `(17,21)->LEFT`: return route reached `(17,21)` and failed into `(16,21)`; direct verifier blocked 5/5. Promoted `(16,21).east`.
- Map 0x0B `(16,22)->UP`: lower return fallback failed into `(16,21)`; direct verifier blocked 5/5. Promoted `(16,21).south`.
- Map 0x0B `(16,22)->LEFT`: paired fallback from `(16,22)` into `(15,22)`; direct verifier blocked 5/5. Promoted `(15,22).east`.
- Map 0x0B `(16,23)->DOWN`: next lower fallback failed into `(16,24)`; direct verifier blocked 5/5. Promoted `(16,24).north`.
- Map 0x0B `(16,23)->LEFT`: paired fallback from `(16,23)` into `(15,23)`; direct verifier blocked 5/5. Promoted `(15,23).east`.

### VERIFIED STILL CLOSED
- `(17,19)->LEFT` into `(16,19)` had one mixed 3-attempt run, then a clean 10/10 blocked verifier. Keep `(16,19).east`.
- `(16,20)->UP` into `(16,19)` blocked 5/5. Keep `(16,19).south`.

### DO NOT PROMOTE
- `(23,21)->LEFT` into `(22,21)` is mixed, 2 moved / 3 blocked, despite blocked-only autowalk evidence. Leave open for now.
- `(15,16)->DOWN` into `(15,17)` is mixed, 2 moved / 3 blocked. Leave open.
- `(23,20)->LEFT` into `(22,20)` directly moved 5/5; the autowalk blocked-only evidence was false/timing-contaminated.
- `(23,20)->DOWN` into `(23,21)` was later rechecked cleanly and promoted; older mixed note is superseded.
- `validate_path` from entrance to chest aborted early on row 14 due overshoot after retries, not a map blocker.
- `(14,21)->RIGHT` into `(15,21)` produced one mixed 1 moved / 4 blocked run, then a clean 15/15 blocked verifier. Keep `(15,21).west`.
- `(14,22)->RIGHT` into `(15,22)` rechecked as blocked 5/5. Keep `(15,22).west`.
- `(14,19)->RIGHT` into `(15,19)` rechecked as blocked 5/5. Keep `(15,19).west`.
- `(13,20)->RIGHT` into `(14,20)` moved 3/5 and `(14,21)->UP` moved 5/5, proving `(14,20)` is a hidden passable spur, but `(14,20)->RIGHT` stayed blocked by raw `probe_edge`. Do not add it as a route bridge yet.
- `(16,20)->DOWN` into `(16,21)` was mixed 1 moved / 4 blocked. Leave the north approach into `(16,21)` open.
- Reload follow-up rechecked `(16,20)->DOWN` with `probe_edge_verify:16,20,DOWN,5`; it moved 5/5. Even though autowalk still often times out here, keep `(16,21).north` open and treat this as route execution/timing noise unless future direct probes reverse it.
- 2026-05-21 narrow stop-test: the live autowalk target was `Exit to World Map`, not stairs, and it drove `(16,21).north` to `blocked=76 moved=0` before manual stop at `(16,20)`. Fresh frozen-NPC follow-up immediately downgraded that seam again: `inspect_move:16,20,DOWN` still reports `effective_passable=true`, `probe_edge_verify:16,20,DOWN,5` came back mixed `moved=3 blocked=2 reason=raw_hold_timeout`, and the seam log flipped from `blocked_only` back to `noisy`. The paired `(16,20)->RIGHT` seam also self-disproved again with `probe_edge_verify:16,20,RIGHT,5` moving 5/5. Do not promote either edge from this pass.
- `(22,25)->UP` into `(22,24)` is mixed and should not be promoted yet. The first verifier moved 5/5, but after input recovery/config reload and a fresh teleport, `probe_edge_verify:22,25,UP,3` blocked 3/3. A temporary `(22,24)` passthrough made the planner route through this throat, but live autowalk still failed there, so that passthrough was backed out.

### LOCAL ROUTE PROOF
- With patched files, the ROM-backed local BFS and opened doors `(21,21)` and `(22,23)` finds both:
- `23,23 -> 29,13`, length 36, via `(13,21)->(13,20)->(13,19)->(13,18)` then east to the entrance.
- `29,13 -> 23,23`, length 36, returning through `(13,20)` and the door-side/chest-side pocket.
- After adding runtime blockers for `(15,23).west` and `(15,24).west`, live FCEUX still finds:
- `29,13 -> 23,23`, length 40, routed through `(14,25)` and row 25.
- `23,23 -> 29,13`, length 36, routed through `(13,20)` and row 14/13.
- Row-25 fallback then looped on `(21,25)->UP` and `(15,25)->UP`; both are now confirmed/patched as south-approach blocks and need a fresh live planner/autowalk pass.
- Entrance-to-chest autowalk then looped from `(16,27)` into `(17,27)`/`(16,28)`; both are now confirmed/patched and need a fresh live planner/autowalk pass.
- The next reroute looped from `(15,27)` down into `(15,28)`; that north-approach block is now confirmed/patched and needs another planner/autowalk pass.
- Parked-NPC forward route later reached the lower west branch and looped on `(13,26)->LEFT` / `(13,25)->LEFT`; both are now confirmed/patched and need another skip-NPC planner/autowalk pass.
- The next lower west reroute looped on `(13,23)->LEFT` / `(13,24)->LEFT`; both are now confirmed/patched and need another skip-NPC planner/autowalk pass.
- The following skip-NPC route shifted to `(13,22)->LEFT`; this is now confirmed/patched and needs another planner pass.
- The route then shifted to `(13,21)->LEFT`; this is now confirmed/patched and needs another planner pass.
- With runtime blockers for `(23,21).north/south`, `(22,22).east`, `(24,21).south`, `(16,21).east/south`, `(15,22).east`, `(16,24).north`, and `(15,23).east`, live planner still finds a return route from the current lower fallback area to `(29,13)`, but the most recent autowalk had not yet reached the entrance before stopping.
- After injecting `(22,20).east`, `(20,21).north`, `(19,21).north`, `(18,21).north`, and `(18,21).west`, live `debug_pathfind_to:29,13` from `(17,21)` finds a 30-step return route through `(16,20)->(16,21)->(15,21)->(14,21)->(13,21)->(13,20)->...->(29,13)`.
- Live `debug_pathfind_to_skip_npcs:23,23` from the entrance `(29,13)` still reports no path with both doors open. The search reaches the west-side frontier `(13,20)->(13,21)->(14,21)` and rejects `(15,21)` as `blocked_directional`, so the missing entrance-to-chest bridge remains east of that west-side component.
- Temporary modeling of `(22,24)` as a passthrough made both `debug_pathfind_to_skip_npcs:23,23` and `debug_pathfind_adjacent_skip_npcs:24,23` plan through `(22,25)->(22,24)->(22,23)->(23,23)`, but the fresh direct verifier blocked that edge 3/3. Treat this as a disproved/mixed bridge until a clean normalized movement run proves otherwise.
- `auto_step_timeout` was raised from 45 to 60 because several passable-looking route steps were completing or failing just past the old threshold. This is an executor-tolerance change, not blocker evidence.

### NEXT CHECK
- Reload FCEUX Lua so the new `(13,20)` passthrough and `(15,19)/(15,23)/(15,24)` west closures are live.
- Reopen Rimuldar inn doors if the reload/map-state reset closed them.
- Run `teleport_to:23,23,force`, `report_door_state`, `debug_pathfind_to:29,13`, and `trace_path`.
- Then test reverse from entrance side with `teleport_to:29,13,force`, `debug_pathfind_to:23,23`, and `trace_path`.

## 2026-05-23 Tantegel Sun Shrine Forward Route Retest

- Fixed-verifier/static-model correction:
  - Initial `probe_edge_verify:20,17,RIGHT,5` moved `6/6` including the delayed stability recheck, but this was later disproved after a manual FCEUX Lua reload.
  - Fresh post-reload autowalk from `(7,7)` failed at `(20,17)->RIGHT`; queued route plus both seam retries blocked.
  - Fresh hardened `probe_edge_verify:20,17,RIGHT,5` then blocked `5/5` with `blocked_model_mismatch=5`.
  - Reverse `probe_edge_verify:21,17,LEFT,5` confirmed passable `6/6`.
  - Restored `MAP_DIRECTIONAL_BLOCKS[0x04]["21,17"].west` as a one-way block and updated the map-reader regression assertion.
- With `(20,17)->RIGHT` injected as a runtime edge, live `debug_pathfind_to:29,29` and `debug_pathfind_to_skip_npcs:29,29` both report no path from the `(19,17)/(20,17)` side.
- The temporary open-model live planner found a route from `(19,17)` to `(29,29)` and autowalk crossed `(20,17)->(21,17)`, but that route is now treated as stale/contaminated evidence.
- Confirmed/patched new southeast-pocket false exits:
  - `probe_edge_verify:26,21,RIGHT,5` blocked `5/5`: promoted `(27,21).west`.
  - `probe_edge_verify:26,21,DOWN,5` blocked `5/5`: promoted `(26,22).north`.
  - `probe_edge_verify:24,21,DOWN,5` blocked `5/5`: promoted `(24,22).north`.
- Do not promote from this pass:
  - `probe_edge_verify:25,21,DOWN,5` was mixed `moved=1 blocked=4`.
  - `probe_edge_verify:26,20,RIGHT,5` confirmed passable `6/6` with stability recheck; route-block evidence there was timing/noisy.
- Live proof after runtime blockers:
  - From `(28,20)`, `debug_pathfind_to:29,29` found a 10-step route.
  - `auto_walk:29,29` reached `(29,29)` cleanly and faced south.
  - The final successful leg went `(28,20)->(28,21)->(28,22)->(28,23)->(29,23)->(29,24)->...->(29,29)`.
  - This proves the southeast finish is usable once reached; it does not prove a clean entrance/throne-side bridge into that component.
- Follow-up after user reported route stalling at `(14,7)`:
  - User was right: natural/route-shaped evidence keeps `(14,7)->RIGHT` into
    `(15,7)` engine-blocked. The earlier verifier-only move result is treated
    as contaminated/subtile-only evidence, and `(15,7).west` remains closed.
  - External route orientation says the Stones/Sunlight route needs at least
    one Magic Key, goes outside near the top/top-right of Tantegel Castle, then
    hugs the outside wall to the lower-right stairs.
  - Live door RAM already had both relevant map `0x04` doors open:
    slots `0=(4,13)` and `1=(18,6)`.
  - Current loaded source model still reports no path from `(20,17)` to
    `(29,29)` with those doors open.
  - Direct/live checks kept these single-bridge candidates closed 5/5:
    `(15,27)->DOWN`, `(15,27)->RIGHT`, `(19,23)->DOWN`,
    `(20,23)->DOWN`, `(20,18)->RIGHT`, `(20,19)->RIGHT`,
    `(20,21)->RIGHT`, `(14,6)->RIGHT`, `(14,15)->RIGHT`,
    `(14,13)->RIGHT`, `(14,12)->RIGHT`, and `(14,10)->RIGHT`.
  - A door-open focused `crawl_map_frontier:attempts=3,max_edges=220` was
    manually stopped at 236 edges after it drifted into broad west-side
    exploration. It exported review-only passthroughs `(9,6)`, `(10,6)`,
    `(11,6)`, `(12,6)`, `(13,13)`, `(7,12)`, `(8,12)`, and directional
    candidates `(3,6).north`, `(4,6).north`.
  - Local ROM-backed simulation with those crawl passthroughs opened still
    found no route from `(7,7)` to `(29,29)`, so do not promote them as the
    Sun Shrine route fix.
  - Remaining likely bridge family is still the lower exterior/right-side
    component boundary. Local one-edge simulation says opening any of
    `(19,25).west`, `(19,26).west`, `(19,27).west`, `(18,28).north`,
    `(17,28).north`, or `(21,20).west` would reconnect, but prior natural
    probes have kept those exact edges blocked. A future pass should either
    prove a world-map transition route is required or find a not-yet-modeled
    multi-step exterior connector.
  - Door-side follow-up found the missing connector at the top-right exterior
    strip, superseding the lower-boundary hypothesis:
    - `probe_edge_verify:21,8,RIGHT,5` entered `(22,8)` `6/6` including the
      stability recheck, but classified as `suspect_passable_model_mismatch`
      because `(22,8)` decodes as tile `0` and was not yet a passthrough.
    - Forced-origin follow-up from `(22,8)` proved `(22,8)->DOWN` into
      `(22,9)` moved. Reverse `(22,9)->UP` also moved into `(22,8)`.
    - `(23,8)->DOWN` blocked from an in-strip current position, so the row-8
      strip has one-way/approach-sensitive behavior; do not broad-open the
      whole strip from this evidence.
    - Local ROM-backed A* with only `(22,8)` added as a passthrough finds a
      complete path from `(7,7)` to `(29,29)` with both Tantegel doors open.
    - Patched only `MAP_PASSTHROUGH_CELLS[0x04]["22,8"] = true` plus a
      focused regression assertion. Awaiting FCEUX Lua reload for live full
      route verification from the throne-side stair landing.
  - Reloaded route follow-up after user reported a stall at `(14,6)->NORTH`:
    - Route/autowalk evidence repeatedly blocked `(14,6)->UP` into `(14,5)`.
      Seam observations reached `(14,5)` approach `south` blocked `19` /
      moved `0` during the loop.
    - Direct `probe_edge_verify:14,6,UP,5` confirmed blocked `5/5` with no
      drift, map change, or interruption. This is the south approach into
      `(14,5)`, distinct from the older modeled north approach.
	  - Patched `MAP_DIRECTIONAL_BLOCKS[0x04]["14,5"].south = true` and added a
	    focused regression assertion.
	  - Injected runtime `14,5(south)` and live planner still found a route to
	    `(29,29)`, but follow-up autowalk was contaminated by active/stale
	    external input and menu/dialogue state. Do not promote the later
	    `(26,20)->RIGHT` noise until a quiet verifier can run.
	  - Follow-up after the user reported pinball near the stairs:
	    - Autowalk was stopped at `(25,21)`. Runtime blocks were empty and the
	      only held input was the known benign FCEUX LeftAlt latch.
	    - The pinball loop repeatedly tried `(26,20)->RIGHT` into `(27,20)` and
	      `(25,21)->DOWN` into `(25,22)`.
	    - Quiet direct `probe_edge_verify:25,21,DOWN,5` confirmed blocked `5/5`
	      with no drift, map change, or interruption. This supersedes the
	      earlier mixed `(25,22).north` result; promoted `(25,22).north` and
	      injected runtime `add_blocked_edge:25,21,DOWN`.
	    - Quiet direct `probe_edge_verify:26,20,RIGHT,5` confirmed passable
	      `6/6` including the stability recheck, so keep `(27,20).west` open
	      despite the noisy route-shaped blocked-only seam counts.
	    - Direct `probe_edge_verify:22,8,DOWN,5` confirmed passable `6/6`
	      including the stability recheck after the current reload state. Treat
	      the user's natural blocked report as unresolved/possibly stale-state
	      until it reproduces again.
	  - Follow-up after save-state/script reload exposed why the planner chose
	    the bad upper x=29 lane:
	    - From `(26,5)`, the model could route to corridor targets like
	      `(25,18)`, `(25,21)`, `(26,20)`, and `(28,20)`, but those paths were
	      all using the upper x=29 strip around `(29,10)` and then coming back
	      west.
	    - Live `auto_walk:29,29` from `(22,10)` reached `(29,10)` and
	      immediately transitioned to the World Map before the planned south
	      turn, so the upper x=29 strip is exit-sensitive and unsuitable as an
	      interior Sun Shrine route.
	    - Direct `probe_edge_verify:25,10,DOWN,5` entered `(25,11)` `6/6`
	      despite tile `0`, classifying as a passable model mismatch.
	    - After force-positioning on `(25,11)`, raw `probe_edge:DOWN` moved into
	      normal floor `(25,12)`.
	    - Patched `MAP_PASSTHROUGH_CELLS[0x04]["25,11"] = true` and added a
	      focused regression assertion. Awaiting FCEUX script reload for live
	      route verification from the both-doors-open save state.
	    - Post-reload planner from `(25,13)` with both doors open found a short
	      x=25/x=26 descent route instead of the bad upper x=29 exit-sensitive
	      lane.
	    - First clean autowalk attempt was blocked by an open command menu; after
	      focusing FCEUX and tapping keyboard `D`/NES `B`, the command menu
	      closed and route testing resumed.
	    - Direct `probe_edge_verify:26,14,RIGHT,5` confirmed `(27,14).west`
	      blocked `5/5` with no drift or interruption. Patched and injected it.
	    - With `(27,14).west` injected, route progressed farther down the
	      x=25/x=26 corridor. It produced blocked-only route evidence for
	      `(27,13).west`, `(27,18).west`, `(27,19).west`, and again
	      `(27,20).west`, but those still need clean direct verification because
	      the hero died during the follow-up verifier.
	    - The corridor route killed the hero: dialogue became `Thou art dead.`
	      at `(26,19)`. Need revive/reload before more live verifier work.
	    - After user revive/reload, baseline was still `(22,8)` with only the
	      temporary upper-x29 west-entry guards active. Clean
	      `probe_edge_verify:22,8,DOWN,5` confirmed `(22,9).north` blocked
	      `5/5` with no drift, map change, or interruption; this supersedes the
	      earlier passable verifier and matches the user's live blocked report.
	    - Injecting `add_blocked_edge:22,8,DOWN` made the planner report no
	      path, so the missing connector was not a south descent from `(22,8)`.
	    - Probing east from the same strip found the real continuation:
	      `probe_edge_verify:22,8,RIGHT,5` moved into `(23,8)` `6/6` including
	      stability recheck, all as `moved_model_mismatch` because tile `0` was
	      still modeled unwalkable.
	    - Forced-origin/raw follow-ups moved `(23,8)->RIGHT` into `(24,8)` and
	      `(25,8)->RIGHT` into `(26,8)`. Earlier raw probing from `(24,8)`
	      moved into `(25,8)`, and current-position probing from `(26,8)->DOWN`
	      entered normal floor `(26,9)`.
	    - Permanent patch: close `(22,9).north`, and add top exterior-strip
	      passthrough cells `(23,8)`, `(24,8)`, `(25,8)`, and `(26,8)`.
	    - Local ROM-backed simulation with the upper x=29 exit-lane runtime
	      guards now finds a path from `(22,8)` to `(29,29)` via
	      `(22,8)->(23,8)->(23,9)->...->(25,10)->(25,11)->...->(29,29)`.
	      Awaiting FCEUX Lua reload before live autowalk verification.
	    - Without reload, stepping down from the live strip to `(26,9)` let the
	      loaded planner test the lower leg. `debug_pathfind_to:29,29` from
	      `(26,10)` found a 24-step route and autowalk crossed
	      `(25,10)->(25,11)->(25,12)->(25,13)` cleanly, proving the x=25
	      descent works live.
	    - The same lower-leg run accumulated blocked-only route evidence for
	      `(27,13).west`, `(26,16).west`, `(27,18).west`, `(27,19).west`, and
	      again `(27,20).west`, but the run ended with `Thou art dead.` at
	      `(26,19)`. These still need clean direct verification after revive;
	      do not promote from the death-contaminated route evidence alone.
	  - Follow-up after a later FCEUX strange-input state:
	    - Treat the apparent blocked verifiers from that stretch as suspect.
	      Clean retry after `recover_fceux_input.sh`, runtime block clear, and
	      `INPUT_STATUS ... keys=- joy1=-` flipped these results to passable:
	      `probe_edge_verify:7,7,RIGHT,5`, `probe_edge_verify:26,5,LEFT,5`,
	      and `probe_edge_verify:26,5,UP,5` all moved `6/6` with the delayed
	      stability recheck.
	    - The upper-right exit lane survived clean retest as a route guard:
	      `(28,10)->RIGHT` into `(29,10)` produced `map_changed=1`, so it is
	      not a safe interior Sun Shrine route edge. Earlier `(28,9)->RIGHT`
	      showed the same map-change behavior. Permanently guard
	      `(29,9).west` and `(29,10).west` so A* does not send the hero out to
	      the World Map while trying to reach `(29,29)`.
	    - With only those two runtime exit guards, parked-NPC planning from the
	      throne-room stair tile `(7,7)` found a coherent 78-step route through
	      the west side, the open `(18,6)` door, the top strip
	      `(22,8)->(23,8)->(24,8)->(25,8)`, the x=25 descent, and the lower
	      right corridor.
	    - Live autowalk from `(7,7)` with the two exit guards made substantial
	      progress: it crossed the top strip and x=25 descent, reaching at least
	      `(26,20)`. It then hit noisy blocked route evidence around
	      `(27,20).west`, `(26,20).north`, and `(27,19).west`; keep these as
	      route-context noise until quiet direct verifiers reproduce them.
	      Prior quiet verifiers kept `(27,19).west` and `(27,20).west` open.
	    - The same route is currently unsafe: HP went from `54/54` earlier in
	      the run to `9/54` at `(26,20)`, then the hero died at `(26,19)`.
	      Missing hazard cells in the lower x=25/x=26 route must be identified
	      before another full autowalk. Candidate live path cells include
	      `(25,16)`, `(25,17)`, `(25,18)`, `(26,18)`, `(26,19)`, and `(26,20)`.
	    - Later live repros plus the completed route cleared `(26,20)`:
	      north/south traversals succeeded there without immediate HP loss, and
	      the route later continued `(26,20)->(27,20)` to the finish. Keep only
	      `(25,18)`, `(26,18)`, and `(26,19)` modeled hazardous for now.
      Read-only `inspect_tile` shows these are tile-4/tile-6 cells currently
      modeled walkable and non-hazard.

### 2026-05-23 Menu-State Sanity / Target Recheck

- Latest live check from `(7,7)` confirmed:
  - `report_menu_state` -> `raw_open=false`, `cached_open=false`, `active_block=false`,
    `cursor_visible=false` (command menu appears closed, not active).
  - `input_status` still reports `LeftAlt+P` (`left_alt=true`) as a stale modifier.
    This matches earlier stale-input recovery patterns and should be handled with
    `recover_fceux_input.sh` when movement appears blocked.
- Route verification still shows:
  - `debug_pathfind_to:29,29` can fail with `NO_PATH_STATIONARY_NPC` depending on
    live NPC positions.
  - `debug_pathfind_to_skip_npcs:29,29` returns a valid route.
  - `debug_pathfind_to_park_npcs:29,29` also returns a valid route.
- Interpretation: current unexpected no-paths are now more consistent with NPC/runtime
  state than a newly opened command menu or fresh directional blocker evidence.

### 2026-05-24 Throne-Room Stair Drift Tightening

- Latest FCEUX route logs around the throne-room stair cluster show repeated
  `route_settle_catchup` drift signatures that are movement/executor noise, not
  new blocker evidence:
  - `(10,8) -> current (9,8)` after a planned turn from `left` to `up`
  - `(20,9) -> current (21,9)` after a planned turn from `right` to `down`
  - `(25,10) -> current (26,10)` after a planned turn from `right` to `down`
- Pattern: the planner often chose "turn now" and "keep going straight, turn one
  tile later" as equal shortest routes. The executor then naturally overran one
  extra tile in the old direction near the stair cluster, forcing a drift reroute.
- Patch applied in `pathfinder.lua`:
  - Added a tiny shortest-path tie-break penalty for changing direction
    (`TURN_TIEBREAK_PENALTY = 0.001`).
  - Path length remains primary; the penalty only breaks equal-cost ties so
    routes prefer to keep the current heading longer before turning.
  - Goal is to reduce stair-area pinball by aligning planned turns with the
    executor's natural overshoot tendency instead of fighting it.
- Regression added in `test_pathfinder.lua`:
  - A forced-west corridor case now asserts that equal-length ties keep moving
    west before turning north.
- Local validation passed:
  - `luac5.1 -p pathfinder.lua test_pathfinder.lua test_route_manager.lua`
  - `lua5.1 test_pathfinder.lua`
  - `lua5.1 test_route_manager.lua`
  - `git diff --check`
- Needs live FCEUX Lua reload plus stair-route retest to judge whether the
  throne-room drift frequency actually improves.

### 2026-05-24 Hazard / Sage Follow-up

- `11,19` no longer looks like a real damage tile on Tantegel `0x04`:
  - Raw `probe_edge:LEFT` from `(12,19)` moved into `(11,19)` and logged
    `EDGE_PROBE_MODEL_MISMATCH ... kind=moved_through_modeled_block`.
  - Immediate snapshots stayed `hp: 54 / 54` before and after the crossing.
  - Keep `(11,18)` hazardous for now; this pass only cleared `(11,19)`.
- Sage-route seam checks from the exact failing approaches:
  - `probe_edge_verify:22,17,LEFT,5` was mixed `moved=1 blocked=4`, so do not
    promote `(21,17).east`.
  - `probe_edge_verify:22,20,LEFT,5` was clean `blocked=5 moved=0` with
    `blocked_model_mismatch=5`, so promote `(21,20).east`.
  - `probe_edge_verify:22,18,UP,5` plus the stability recheck moved `6/6`, so
    do not promote `(22,17).south`.
  - With only the known Sage-route blockers injected at runtime
    (`(21,17).east` temporary, `(21,20).east` confirmed), `debug_pathfind_to`
    for the true public stand `(18,26)` still found a planner route by
    dropping through row 16 instead of the mixed `(22,17)->LEFT` seam.
  - Live `auto_walk:18,26` on that alternate path immediately found more
    castle-geometry misses:
    - route-shaped `(24,8)->DOWN` into `(24,9)` blocked repeatedly, then clean
      `probe_edge_verify:24,8,DOWN,5` blocked `5/5` with
      `blocked_model_mismatch=5`.
    - route-shaped `(19,15)->DOWN` into `(19,16)` blocked repeatedly, then
      clean `probe_edge_verify:19,15,DOWN,5` blocked `5/5` with
      `blocked_model_mismatch=5`.
    - route-shaped `(20,15)->DOWN` into `(20,16)` blocked repeatedly, then
      clean `probe_edge_verify:20,15,DOWN,5` blocked `5/5` with
      `blocked_model_mismatch=5`.
  - Do not promote lateral row-15 noise from the same run:
    `(19,15)<->(20,15)` flipped between blocked and moved and stayed
    classification=`noisy`.

### 2026-05-24 Southeast East-Edge Bracket

- Fresh restored-state FCEUX bracketing from Tantegel `0x04` east edge:
  - Baseline restore was stable at `(26,5)`, no upper dialogue, no runtime
    blockers.
  - Forced `(28,20)->RIGHT` changed to the World Map at `(43,43)`.
  - Forced `(28,21)->RIGHT` stayed in castle and settled at `(29,21)`.
  - Forced `(28,22)->RIGHT` stayed in castle and settled at `(29,22)`.
  - Forced `(28,23)->RIGHT` changed to the World Map at `(43,43)`.
  - Forced `(29,22)->UP` settled at `(29,18)` and forced `(29,22)->DOWN`
    settled at `(29,24)`, confirming a real north/south x=29 lane there.
  - Forced `(29,21)->RIGHT` changed to the World Map at `(43,43)`.
  - Earlier same-day retest already confirmed forced `(29,22)->RIGHT` also
    changes to the World Map at `(43,43)`.
- Interpretation:
  - The southeast x=29 boundary is mixed, not a uniform corridor and not a
    uniform exit wall.
  - Westward entry into the castle-side x=29 lane is real at y=21-22 only.
  - Westward "entries" at y=20 and y=23 are exterior exit seams instead and
    should be blocked for path planning.
- Permanent map-data update promoted from this bracket:
  - `MAP_DIRECTIONAL_BLOCKS[0x04]["29,20"].west = true`
  - `MAP_DIRECTIONAL_BLOCKS[0x04]["29,23"].west = true`
- Follow-up still needed after reload:
  - Re-run `debug_pathfind_to_allow_hazards:29,29` from normal castle play
    space and see whether the planner now prefers the narrower y=21-22 entry
    into the southeast lane.

### 2026-05-24 Post-Reload East-Edge Validation

- After manual Lua reload plus `reload_navigation_modules`, fresh planner
  checks from the normal castle restore at `(26,5)` confirmed the new east-edge
  guards are loaded but do not by themselves restore the shrine route.
- From live `(26,5)`:
  - `debug_pathfind_to_allow_hazards:29,29` -> `No path found`
  - `debug_pathfind_to_allow_hazards:29,22` -> `No path found`
  - `debug_pathfind_to_allow_hazards:29,21` -> `No path found`
  - `debug_pathfind_to_skip_npcs:29,22` -> `No path found`
  - `debug_pathfind_to_skip_npcs:29,21` -> `No path found`
- Frontier bracket from the same restore:
  - reachable:
    - `(25,18)` via only `25,18:damage`
    - `(25,20)` via `23,18/23,19/23,20:damage`
    - `(25,21)` via `23,18/23,19/23,20:damage`
    - `(26,20)` via `25,18/26,18/26,19:damage`
    - `(26,21)` via `25,18/26,18/26,19:damage`
  - not reachable:
    - `(27,20)`, `(27,21)`
    - `(23,22)`, `(24,22)`, `(25,22)`, `(26,22)`, `(27,22)`
    - `(28,20)`, `(28,21)`, `(28,22)`, `(28,23)`
    - `(29,21)`, `(29,22)`, `(29,29)`
- Forced-side sanity check cleanly separates the two components:
  - From forced `(26,21)`, `debug_pathfind_to_allow_hazards:29,29` is still
    `No path found`.
  - From forced `(26,21)`, `debug_pathfind_to_allow_hazards:26,22` is also
    `No path found`.
  - From forced `(29,22)`, `debug_pathfind_to_allow_hazards:29,29` is
    `Path: 7 south`.
- Interpretation:
  - The east-edge correction is good: the southeast x=29 lane remains a real
    component, and the final lane-to-exit route is intact.
  - The remaining missing bridge is still west of that lane; current live data
    says the normal castle component stops at `(26,20)/(26,21)`.

### 2026-05-24 Crawler / Row-22 Stateful Follow-up

- User suggested dropping crawlers near the west/east split.
- First west-side crawl from forced `(26,21)` needed a cleanup step because the
  reload restore had `menu_raw=true` with no visible upper text. A one-frame
  raw `B` press later logged `EVENT: command menu closed`, and a follow-up
  `report_upper_dialogue_state` showed `menu_raw=false`.
- West-side crawl from `(26,21)`:
  - `crawl_map_frontier:attempts=5,max_edges=120`
  - advanced cleanly to `(26,20)`,
  - then the backtrack probe from `(26,20)` with `dir=down` drifted into
    `(26,19)` instead of returning to `(26,21)`,
  - finishing `completed=false reason=movement_drift edges=3`.
  - This looks like a crawler/executor hazard interaction, not new geometry.
- East-side crawl from forced `(29,22)`:
  - ran north up the x=29 lane again,
  - exported only the older passthrough candidate `["29,8"] = true`,
  - and again ended with a backtrack drift at the top boundary:
    `(29,1)->DOWN` landed at `(29,0)` instead of `(29,2)`.
  - So the crawler still does not harvest the west-boundary behavior we care
    about here; it prefers the north lane and then dies on movement drift.
- Direct raw row-22 probing from forced `(29,22)` finally exposed stronger
  live behavior than the planner model:
  - successive `LEFT,40` holds settled:
    - `(29,22) -> (28,22)`
    - `(28,22) -> (25,22)`
    - `(25,22) -> (23,22)`
    - `(23,22) -> (20,22)`
  - successive `RIGHT,40` holds then settled:
    - `(20,22) -> (23,22)`
    - `(23,22) -> (25,22)`
    - `(25,22) -> (28,22)`
  - but the next `RIGHT,40` from that live `(28,22)` state changed to the
    World Map at `(43,43)` instead of settling at `(29,22)`.
- Important caution:
  - This is not yet clean proof that row 22 is statically open end-to-end for
    normal pathfinding. The 40-frame raw holds carry across multiple tiles, and
    the final `(28,22)->RIGHT` behavior is explicitly state-dependent:
    earlier cold forced tests at `(28,22)` had settled at `(29,22)` first.
  - Treat this as strong evidence of a stateful / traversal-history-sensitive
    bridge on row 22, not a permanent map-data promotion yet.
- One more planner contradiction from the same live chain:
  - from live `(20,22)`, `debug_pathfind_to_allow_hazards:23,22` still said
    `No path found`, despite the direct raw `RIGHT,40` carry back to `(23,22)`.
  - from that same live `(20,22)`, `debug_pathfind_to_allow_hazards:26,21`
    did find a long 47-step route back through the normal interior/hazard
    component.
- Best next validation after restore:
  - use short/split `probe_edge` or shorter raw holds on row 22 cells,
    especially `(20,22)`, `(23,22)`, `(25,22)`, `(28,22)`,
  - determine whether the bridge is one-step open, carry-open only, or opened
    by prior traversal history.

### 2026-05-24 Row-22 Corridor Validation / Follow-on Blockers

- Fresh interior-side validation from the clean castle restore:
  - `inspect_tile:21,22` exposed the first stale model bug directly:
    `base_walkable=true` but `walkable=false reason=permanent_blocked`.
  - Cold forced row-22 movement then confirmed `(21,22)` is not a real full
    blocker:
    - forced `(23,22)` then raw `LEFT,40` settled at `(21,22)`
    - raw `RIGHT,40` from live `(21,22)` settled back at `(23,22)`
- Permanent model fix promoted:
  - removed the stale `MAP_BLOCKED_CELLS[0x04]["21,22"]`
- Post-reload planner validation from forced `(20,22)`:
  - `debug_pathfind_to_allow_hazards:21,22` -> `Path: 1 east`
  - `debug_pathfind_to_allow_hazards:22,22` -> `Path: 2 east`
  - `debug_pathfind_to_allow_hazards:23,22` -> `Path: 3 east`
  - `debug_pathfind_to_allow_hazards:29,29` -> `Path: 9 east, 7 south`
  - So the row-22 corridor is now planner-visible end to end with no hazards.
- Post-reload planner validation from the normal castle restore `(26,5)`:
  - normal, hazards-allowed, and skip-NPC planning all found the same clean
    route to `(29,29)`:
    `2 west, 3 south, 1 east, 9 south, 5 west, 5 south, 9 east, 7 south`
  - after promoting the next two live blockers below, the route updated to:
    `2 west, 3 south, 1 east, 8 south, 5 west, 6 south, 9 east, 7 south`
- Live autowalk status:
  - The restored corridor fix is real: live autowalk no longer died because the
    southeast x=29 lane was disconnected.
  - The route now progresses far enough to expose the next missing castle seams
    upstream, before it ever reaches row 22:
    - `(22,17)->LEFT` into `(21,17)` blocked repeatedly
    - `(22,17)->UP` into `(22,16)` blocked repeatedly
  - Clean direct verifier follow-up:
    - `probe_edge_verify:22,17,LEFT,5` -> `confirmed_blocked`
    - `probe_edge_verify:22,17,UP,5` -> `confirmed_blocked`
- Permanent model fixes promoted from that follow-up:
  - `MAP_DIRECTIONAL_BLOCKS[0x04]["21,17"].east = true`
  - `MAP_DIRECTIONAL_BLOCKS[0x04]["22,16"].south = true`
- Next live autowalk after those promotions got farther again and started
  exposing the west face of the row-15/16 pocket.
  - Later direct `probe_edge_verify:25,15,LEFT,5` cleanly confirmed
    `(24,15).east` blocked `5/5` with `blocked_model_mismatch=5`, so that
    sibling row is now ready for permanent modeling.
  - A follow-up `probe_edge_verify:25,16,LEFT,5` in the same area was
    interrupted by temporary upper-dialogue state, so treat `(24,16).east` as
    "already modeled, recheck later if needed" rather than fresh new evidence
    from that interrupted sample.
- 2026-05-24 continued row-16 bracket from live `(24,17)`:
  - After promoting `(24,15).east`, autowalk progressed through `(25,17)`,
    `(24,17)`, and `(23,17)` before repeatedly failing on the next north faces:
    - `(24,17)->UP` into `(24,16)`
    - `(23,17)->UP` into `(23,16)`
  - Repeated autowalk evidence was strong on both:
    `SEAM_OBSERVATION ... classification=blocked_only` kept climbing with no
    moved results on the upward attempts.
  - `probe_edge_verify` is currently flaky on these row-16 north-face checks:
    both `(24,17)->UP` and `(23,17)->UP` hit
    `classification=inconclusive_interrupted reason=Wait for the upper dialogue window to clear before probing an edge`
    even while `report_upper_dialogue_state` immediately before/after said
    `active=false menu_raw=false menu_active=false`.
  - Current-position `probe_edge:UP` did still reproduce the bumps cleanly:
    - `(23,17)->UP` -> `EDGE_PROBE_RESULT ... status=blocked ... kind=blocked_despite_open_preview`
    - `(24,17)->UP` -> same blocked-despite-open-preview result
  - Important runtime-planning result:
    - `add_blocked_edge` expects source-cell plus direction, not destination
      plus blocked approach.
    - Correct runtime injections are:
      - `add_blocked_edge:23,17,UP` -> runtime block `(23,16).south`
      - `add_blocked_edge:24,17,UP` -> runtime block `(24,16).south`
    - With those two runtime edges injected correctly, `debug_pathfind_to_allow_hazards:29,29`
      from `(24,17)` becomes `No path found`.
  - Interpretation:
    - The route now appears to hinge on one of these row-16 north faces or on a
      still-undiscovered alternate bridge nearby.
    - Before permanently promoting `(23,16).south` and `(24,16).south`, the
      next best check is a stateful/raw-sequence pass to rule out carry-open
      seam behavior, because promoting both collapses the route component.
- 2026-05-24 follow-up stateful seam and crawler pass:
  - Stateful raw-sequence checks did not rescue the row-16 north faces:
    - from forced `(24,17)`, `simulate_raw_sequence:LEFT,20,30;UP,40,0`
      finished at `(23,17)` rather than entering `(23,16)`
    - from forced `(24,18)`, `simulate_raw_sequence:UP,80,0` finished at
      `(24,17)`
    - from forced `(23,18)`, `simulate_raw_sequence:UP,80,0` finished at
      `(23,17)`
  - Interpretation: these do not currently behave like carry-open seams from a
    one-tile-south run-up.
  - A bounded local crawler from live `(23,17)` (`crawl_map_frontier:attempts=3,max_edges=80`)
    also failed to find a hidden bridge:
    - it immediately reproduced `(23,17)->UP` into `(23,16)` as a
      `directional_block_candidate`
    - then reproduced the already-modeled `(22,17)->UP` into `(22,16)` the
      same way
    - afterwards it walked south through open floor toward the hazard lane,
      hit `MAP_CRAWL_ABORT ... reason=low_hp hp=8 threshold=8`, then `Thou art dead.`
  - Crawl summary:
    - `MAP_CRAWL_FINISH run=3 map=0x04 completed=false reason=low_hp edges=8 passthrough_candidates=0 directional_candidates=2 stationary_npc_cells=0 transitions=0`
  - So this pass did not uncover any new hidden passages around the row-16
    pocket; it only strengthened `(23,16).south` as the remaining unmodeled
    blocker candidate and re-confirmed the existing `(22,16).south` geometry.
- 2026-05-24 clean restore retest of the remaining `(23,16).south` candidate:
  - Fresh current-position `probe_edge:UP` from forced `(23,17)` moved cleanly
    and settled at `(23,15)`, so `(23,16).south` is **not** ready for
    promotion as a blocker.
  - Injecting only `add_blocked_edge:23,17,UP` from the clean restore at
    `(26,5)` did not collapse the route. `debug_pathfind_to_allow_hazards:29,29`
    still found a 41-step path, just rerouted.
  - Live autowalk on that rerouted path then exposed the next real blocker
    farther upstream: `(21,13)->DOWN` into `(21,14)`.
  - Direct `probe_edge:DOWN` from forced `(21,13)` blocked cleanly, and
    `probe_edge_verify:21,13,DOWN,5` confirmed:
    `classification=confirmed_blocked moved=0 blocked=5 blocked_model_mismatch=5`.
  - Permanent model fix promoted:
    - `MAP_DIRECTIONAL_BLOCKS[0x04]["21,14"].north = true`
  - After mirroring only that runtime blocker from the clean restore,
    `debug_pathfind_to_allow_hazards:29,29` still found a route (now a longer
    west detour), and live autowalk progressed to `(24,13)` before surfacing
    the next likely blocker at `(25,14)->LEFT` into `(24,14)`.

- 2026-05-24 continued live FCEUX dig after script reload:
  - Baseline at `(25,14)` initially failed for a silly reason:
    `UPPER_STATE active=false menu_raw=true`, and `auto_walk:29,29` cancelled
    immediately with `can_walk=false`.
  - `simulate_input:B` closed the command menu, but the cleaner fix was
    `recover_fceux_input.sh`, which:
    - cleared the stale FCEUX Alt/menu latch,
    - briefly surfaced a stale external Down bridge,
    - then left the script healthy at `(25,15)` with
      `menu_raw=false menu_active=false`.
  - From that recovered baseline:
    - `debug_pathfind_to_allow_hazards:29,29` from `(25,15)` found
      `2 south, 2 west, 1 north, 3 west, 6 south, 9 east, 7 south`
    - live autowalk reached `(24,17)` / `(23,17)` again and this time the
      direct verifier path was clean.
  - Clean verifier promotions:
    - `probe_edge_verify:24,17,UP,5` -> confirmed_blocked, so `(24,16).south`
    - `probe_edge_verify:23,17,UP,5` -> confirmed_blocked, so `(23,16).south`
    - `probe_edge_verify:25,14,LEFT,5` -> confirmed_blocked, so `(24,14).east`
  - Runtime mirror check from live `(23,17)` with
    `add_blocked_edge:23,17,UP` and `add_blocked_edge:24,17,UP`:
    - planner still found a route:
      `2 east, 4 north, 3 west, 3 south, 2 west, 6 south, 9 east, 7 south`
    - live autowalk exposed a new north-pocket frontier instead of collapsing.
  - New frontier at `(22,15)`:
    - autowalk repeatedly blocked on `(22,15)->DOWN` into `(22,16)`
    - autowalk repeatedly blocked on `(22,15)->LEFT` into `(21,15)`
    - fresh direct verifiers both confirmed 5/5:
      - `probe_edge_verify:22,15,DOWN,5` -> `(22,16).north`
      - `probe_edge_verify:22,15,LEFT,5` -> `(21,15).east`
  - Runtime mirror check from live `(22,15)` with those added too:
    - planner still found a route:
      `1 east, 1 south, 3 west, 6 south, 9 east, 7 south`
  - New frontier at `(23,15)`:
    - route first showed a noisy seam on `(22,15)->RIGHT` into `(23,15)`:
      initial queued block, then seam retry moved; do **not** promote
      `(23,15).west` from that alone.
    - after settling at `(23,15)`, autowalk repeatedly blocked on
      `(23,15)->DOWN` into `(23,16)`.
    - first verifier pass was another false `upper dialogue` interruption, but
      a second pass after `report_upper_dialogue_state` confirmed 5/5:
      - `probe_edge_verify:23,15,DOWN,5` -> `(23,16).north`
  - Runtime mirror check with `(23,16).north` added as well:
    - from live `(23,15)`, planner still found
      `1 east, 1 south, 4 west, 6 south, 9 east, 7 south`
  - Current interpretation:
    - this is behaving like a real archaeological dig: each promoted blocker
      reveals another detour, not a dead end.
    - The route is still alive west/north of `(23,15)`.
    - The running FCEUX Lua script has **not** picked up the permanent
      `map_reader.lua` edits yet; all live continuation after the reload used
      runtime `add_blocked_edge` mirrors for the new blockers.

- 2026-05-24 continued west-pocket branch after the above promotions:
  - Fresh reroute from `(23,15)` exposed the lateral row-14 faces.
  - Clean verifier:
    - `probe_edge_verify:22,14,LEFT,5` -> confirmed_blocked, so `(21,14).east`
  - Mixed / runtime-only seam:
    - `probe_edge_verify:23,14,RIGHT,5` -> moved `2`, blocked `3`
    - reverse `probe_edge_verify:24,14,LEFT,5` -> confirmed_passable `6/6`
    - interpretation: treat `(24,14).west` as a one-way/stateful trouble seam
      for runtime experiments only, not permanent map data yet
  - Runtime-only mirror of `(24,14).west` plus clean `(21,14).east` pushed the
    planner into a deeper west branch instead of collapsing the route.
  - That branch briefly made `(23,15)->RIGHT` into `(24,15)` look blocked-only
    in natural route context, but the direct verifier overturned it:
    - `probe_edge_verify:23,15,RIGHT,5` -> confirmed_passable `6/6`
    - interpretation: `(24,15).west` is route-context noise, not geometry
  - One more clean verifier from the same pocket:
    - `probe_edge_verify:24,15,DOWN,5` -> confirmed_blocked, so `(24,16).north`
  - Farther-west branch after mirroring `(24,16).north`:
    - `probe_edge_verify:20,15,RIGHT,5` -> moved `2`, blocked `3`
    - `probe_edge_verify:19,15,LEFT,5` -> moved `2`, blocked `3`
    - interpretation: both remain mixed/runtime-only, not ready for promotion
  - Final live route status from runtime mirrors:
    - with clean `(21,14).east` + `(24,16).north` mirrored and speculative
      `(24,14).west` mirrored, the planner still finds
      `2 north, 4 west, 2 south, 1 east, 2 south, 1 west, 5 south, 9 east, 7 south`
      from `(24,15)`
    - autowalk can follow that branch but then gets noisy again around the
      higher-west pocket `(22,13)/(22,14)` with drift and mixed seam retries,
      not another clean blocker yet
  - Current interpretation:
    - new permanent promotions from this sub-pass are `(21,14).east` and
      `(24,16).north`
    - `(24,14).west`, `(21,15).west`, and `(18,15).east` should stay runtime-only
      suspects until a future pass gets cleaner evidence

- 2026-05-24 suspect-first recheck after full reload at `(19,15)`:
  - Reload came up with the command menu open again:
    - `UPPER_STATE ... menu_raw=true`
    - `INPUT_STATUS ... left_alt=true`
  - `simulate_input:B` logged `EVENT: command menu closed` but the clean fix was
    still `recover_fceux_input.sh`, which restored
    `menu_raw=false menu_active=false left_alt=false`.
  - West suspect `(19,15)->LEFT` into `(18,15)`:
    - current-position `probe_edge:LEFT` from live `(19,15)` blocked
    - reverse `probe_edge_verify:18,15,RIGHT,5` confirmed passable `6/6`
    - teleporting back to `(19,15)` and repeating current-position
      `probe_edge:LEFT` blocked again
    - interpretation: strong runtime evidence for a one-way seam with
      `(18,15).east` closed, but the earlier stopped-origin verifier on the
      blocked side stayed mixed, so keep this runtime-only for now
  - East suspect `(20,15)->RIGHT` into `(21,15)` resolved the opposite way:
    - current-position `probe_edge:RIGHT` from live `(20,15)` moved cleanly
      into `(21,15)`
    - immediate reverse `probe_edge:LEFT` from live `(21,15)` moved back
      through `(20,15)` and settled at `(19,15)`
    - interpretation: this seam is noisy in route context but not a permanent
      geometry blocker
  - Runtime-only mirror of the likely one-way seam:
    - `add_blocked_edge:19,15,LEFT` changed planner output from `(19,15)` to
      `2 east, 2 south, 1 west, 5 south, 9 east, 7 south`
    - live autowalk with only that runtime block pushed into a deeper branch
      instead of collapsing the route
  - New west-pocket route-context findings from that branch:
    - `(21,15).west` kept blocking in routed play, but because current-position
      probes already showed `(20,15)<->(21,15)` open, keep this as route noise
      for now
    - the route drifted/noised around `(20,14)` / `(20,15)` rather than
      exposing a fresh clean permanent blocker
  - Current interpretation:
    - best current runtime helper for the west pocket is still `(18,15).east`
    - `(21,15).west` should not be promoted unless a future clean verifier or
      repeated natural blocked probes overturn the current passable evidence

- 2026-05-24 west-pocket continuation after emulator recovery:
  - Quiet rebaseline at `(20,14)` kept runtime-only `(18,15).east` active and
    reproduced the row-14 / row-15 west-face trouble without route drift.
  - New clean one-way seam promotions:
    - `probe_edge_verify:20,14,RIGHT,5` blocked `5/5`, while current-position
      `probe_edge:LEFT` from forced `(21,14)` moved back through to `(20,14)`;
      promote `(21,14).west`.
    - `probe_edge_verify:20,15,RIGHT,5` blocked `5/5`, while current-position
      `probe_edge:LEFT` from forced `(21,15)` moved back through to `(20,15)`;
      promote `(21,15).west`.
    - `probe_edge_verify:19,14,LEFT,5` blocked `5/5`, while current-position
      `probe_edge:RIGHT` from forced `(18,14)` carried through to `(20,14)`;
      promote `(18,14).east`.
  - Mixed / keep unpromoted:
    - `probe_edge_verify:18,13,DOWN,5` on `(18,14).north` came back mixed
      (`moved=1 blocked=4`), so keep that face out of permanent data.
  - Runtime continuation with `(18,15).east`, `(18,14).east`, `(21,14).west`,
    and `(21,15).west` mirrored stayed productive:
    - hazards-allowed planning from `(20,14)` found
      `1 west, 1 north, 1 west, 7 south, 2 east, 2 south, 9 east, 7 south`
    - short autowalk samples progressed through the higher-west detour and then
      up to `(25,12)` before manual stop
  - Next likely dig site:
    - routed play hit `(18,14)->DOWN` into `(18,15)` as blocked-only `2/0`,
      but that is still route-context evidence and should be verified directly
      before any permanent promotion.

- 2026-05-24 post-reload continuation from the new west-pocket frontier:
  - Clean reload baseline at `(25,12)` had no runtime overlays.
  - `(18,14)->DOWN` / `(18,15).north` is **not** a permanent blocker:
    - `probe_edge_verify:18,14,DOWN,5` moved on all five main attempts
    - stability recheck hit the verifier's bogus upper-window interruption, but
      this is still strong open-seam evidence
    - direct current-position `probe_edge:DOWN` from live `(18,14)` blocked
      twice, so this face is stateful/start-state-sensitive rather than a clean
      static wall
  - `(18,15).east` also failed as a durable runtime-helper theory on this reload:
    - current-position `probe_edge:LEFT` from live `(19,15)` moved through and
      settled at `(17,15)`
    - from `(17,15)`, `debug_pathfind_to_allow_hazards:29,29` found
      `5 south, 3 east, 2 south, 9 east, 7 south`
  - Short live autowalk from `(17,15)` progressed cleanly to `(20,22)` and then
    stalled on the next east step:
    - route path: `5 south, 3 east, 2 south, 9 east, 7 south`
    - repeated blocked-only seam observations at `(21,22)` approach `west`
    - reroute from `(20,22)` collapsed to `No path found`
  - New critical mixed bridge:
    - current-position `probe_edge:RIGHT` from live `(20,22)` blocked
    - forced `(21,22)->LEFT` moved back through and settled at `(19,22)`
    - `probe_edge_verify:20,22,RIGHT,5` came back mixed (`moved=1 blocked=4`)
    - interpretation: `(21,22).west` is the live bridge into the southeast
      pocket, but it is still too mixed/stateful for permanent map data
  - East-side bracket:
    - forced `(21,22)` -> `debug_pathfind_to_allow_hazards:29,29` found
      `8 east, 7 south`
    - forced `(20,21)->RIGHT` into `(21,21)` blocked, and the preview shows
      `(21,21)` is permanently blocked, so `(20,22)->RIGHT` is the only known
      west-side entry into the working southeast route
  - Carry test notes:
    - raw `DOWN,40` from `(20,21)` carried through to `(20,23)`
    - raw `DOWN,20;RIGHT,40` stayed at `(20,21)`
    - raw `DOWN,30;RIGHT,40` ended at `(20,23)`
    - this did not expose a simple corner-carry recipe into `(21,22)`

- 2026-05-24 follow-up after user manual run-up report at `(20,22)`:
  - User manual movement still could not cross `(20,22)->RIGHT`, even taking a
    run at it, after a fresh reload.
  - Fresh log baseline from the reload captured two manual right attempts at
    `(20,22)`:
    - `auto_step movement started ... source=manual_tap`
    - immediate `early movement twitch held`
    - then `cancel manual_tap early-twitch wait`
  - Clean live repros on the same reload:
    - current-position `probe_edge:RIGHT` from live `(20,22)` blocked again
    - forced `(21,22)->LEFT` moved back through and settled at `(19,22)`
    - runtime `add_blocked_edge:20,22,RIGHT` then collapsed
      `debug_pathfind_to_allow_hazards:29,29` from forced `(17,15)` to
      `No path found`
    - forced `(21,22)` still had the clean remainder route `8 east, 7 south`
  - Forced verifier at `(20,22)->RIGHT` stayed mixed (`moved=1 blocked=4`), but
    the combined manual/current-position/runtime evidence is now strong enough
    to promote `(21,22).west` as a one-way seam.

- 2026-05-24 parked-NPC executor isolation on row 21:
  - Added manual debug hooks in `route_manager.lua`:
    - `park_npcs` / `park_npcs:all`
    - `park_npcs:mobile`
    - `restore_parked_npcs`
  - Local checks passed:
    - `luac5.1 -p route_manager.lua test_route_manager.lua`
    - `lua5.1 test_route_manager.lua`
    - `git diff --check -- route_manager.lua test_route_manager.lua`
  - Live baseline cleanup:
    - `park_npcs` parked all 20 NPC slots
    - command-menu contamination recurred once; `simulate_raw_input:B,8`
      cleanly closed it (`EVENT: command menu closed`)
  - Clean parked-NPC row-21 evidence:
    - `probe_edge:RIGHT` from real `(25,21)` settled at `(26,21)`
    - `probe_edge:RIGHT` from real `(26,21)` cleanly blocked into `(27,21)`
      with `reason=raw_hold_timeout`
    - forced `(27,21)->LEFT` again settled all the way to `(25,21)`
    - immediate `probe_edge:RIGHT` from that landed `(25,21)` again carried to
      `(27,21)`
    - fresh `probe_edge:RIGHT` from the carried `(27,21)` state then blocked
      into `(28,21)` with `EDGE_PROBE_MODEL_MISMATCH kind=blocked_despite_open_preview`
  - Raw-sequence checks from west-side starts:
    - cold `simulate_raw_sequence:RIGHT,40,0` from `(25,21)` ended at `(26,21)`
    - `simulate_raw_sequence:LEFT,40,0;RIGHT,40,0` from forced `(26,21)` ended
      back at `(26,21)`
    - so a simple west-side jiggle does not recreate the carry
  - Extra stateful oddities:
    - cold raw `LEFT,40` from forced `(25,21)` ended at `(23,21)`
    - cold forced `probe_edge_verify:27,21,RIGHT,5` was
      `classification=confirmed_passable moved=6 blocked=0` and finished at
      `(29,21)`
    - therefore `27,21->RIGHT` is not stable blocker geometry; the blocked
      behavior appears to depend on the specific carried-arrival state
  - Working interpretation:
    - the row-21 carry is real and survives with NPCs parked, so it is not
      guard/NPC noise
    - but it is not currently reachable from the west side through a simple
      executor macro
    - do not promote new row-21 static map data from this pass
    - next useful check is deeper state instrumentation around the
      post-carry arrival at `(27,21)` rather than more blocker archaeology

- 2026-05-24 first live pass with enhanced edge-motion instrumentation:
  - New `main.lua` probe logging now emits:
    - `EDGE_MOTION_STATE ...` at probe start and result
    - `EDGE_PROBE_CARRY ...` when a one-step probe settles past its nominal
      destination
  - Clean parked-NPC row-21 sequence from reload:
    - cold forced `(27,21)->RIGHT`:
      - `EDGE_MOTION_STATE context=probe_start ... move=0x0C sub=0x90`
      - settled at `(29,21)` via `EDGE_PROBE_CARRY`
    - forced `(27,21)->LEFT`:
      - `EDGE_MOTION_STATE context=probe_start ... move=0x0C sub=0x90`
      - settled at `(25,21)` via `EDGE_PROBE_CARRY`
    - immediate `(25,21)->RIGHT` from that landed state:
      - `EDGE_MOTION_STATE context=probe_start ... move=0x00 sub=0x00`
      - settled at `(27,21)` via `EDGE_PROBE_CARRY`
    - fresh `(27,21)->RIGHT` after the carry:
      - `EDGE_MOTION_STATE context=probe_start ... move=0x09 sub=0x90`
      - also settled at `(29,21)` via `EDGE_PROBE_CARRY`
  - Important first comparison:
    - the carried arrival does change the next probe-start fingerprint at
      `(27,21)` from `move=0x0C` to `move=0x09`
    - but on this reload that changed state did **not** recreate the old bump;
      it still passed east and carried to `(29,21)`
  - Working interpretation:
    - movement-state instrumentation is catching a real state difference after
      the carry
    - `move=0x09` vs `0x0C` alone is not sufficient to explain the previously
      blocked `(27,21)->RIGHT` result
    - the stale/hidden condition is likely a richer state combination or timing
      issue, not just one movement byte

- 2026-05-24 second live pass with settle-window tracing:
  - New `EDGE_PROBE_SETTLE_TRACE` lines are working and capture the 60-frame
    post-destination settle window with change-only samples.
  - This reload produced a different cold-state family from the prior pass:
    - cold forced `(27,21)->RIGHT` started with `move=0x08 sub=0x90`
    - forced `(27,21)->LEFT` then started with `move=0x07 sub=0x90`
    - immediate `(25,21)->RIGHT` also started with `move=0x07 sub=0x90`
    - fresh `(27,21)->RIGHT` after that carry again started with
      `move=0x07 sub=0x90`
  - All four probes still carried cleanly:
    - `(27,21)->RIGHT` finished at `(29,21)`
    - `(27,21)->LEFT` finished at `(25,21)`
    - `(25,21)->RIGHT` finished at `(27,21)`
    - fresh `(27,21)->RIGHT` after the carry again finished at `(29,21)`
  - Settle-trace pattern worth keeping:
    - east carries show destination `(28,21)` first, then a long run of
      `move=0x05 sub=0x90` while scroll increments and overworld Y walks, then
      arrival at `(29,21)` followed by `0x00`, `0x50`, and finally stable
      `0x07`/`0x08`
    - west carries show mirror behavior from `(26,21)` with a long
      `move=0x02 sub=0x90` phase before landing at `(25,21)`, then `0x04`,
      `0x00`, `0x50`, and finally stable `0x07`
    - immediate `(25,21)->RIGHT` no longer has a neutral start state on this
      reload; it inherited `move=0x07 sub=0x90` from the prior west carry and
      still carried forward
  - Working interpretation:
    - the interesting state is broader than a single final `move` byte
    - the settle-window trace strongly suggests the carry involves a multi-frame
      conveyor-like transitional state (`0x05` east / `0x02` west) plus
      overworld/scroll churn before the final landing state stabilizes

- 2026-05-25 targeted x=29 lane retest after script reload:
  - Fresh command-poll proof:
    - `LAUNCHER_PROBE: resume_probe_0525a`
    - `POSITION: map=0x04(Tantegel Castle) x=29 y=21`
    - stable movement family: `scroll_x=0xC0`, `scroll_y=0x10`, `buttons=0x00`
  - Targeted seeded helper bracket from natural north/south traversal:
    - reset to `(29,18)` / `(29,19)` with raw `UP` sequences
    - `probe_edge_after_raw_to:DOWN,140,29,20,0,LEFT` armed at `(29,20)` and
      drifted to `(29,21)`
    - wait `5` also armed at `(29,20)` and drifted to `(29,21)`
    - wait `10` still armed at `(29,20)` and drifted to `(29,21)`
    - wait `15` armed cleanly at `(29,21)` and blocked left into `(28,21)`
      with `EDGE_PROBE_MODEL_MISMATCH kind=blocked_despite_open_preview`
    - previous wait `20` result from the same helper family also armed at
      `(29,21)` and blocked left
  - Runtime-only planning check:
    - `add_blocked_edge:29,21,LEFT` recorded runtime `(28,21).east`
    - hazards-allowed planning from `(29,21)` to `(29,29)` still returned
      `Path: 8 south`
  - Live execution check:
    - `auto_walk:29,29` from `(29,21)` completed the x=29 descent
    - final step `(29,28)->DOWN` reached `(29,29)` and transitioned to
      `map=0x01(World Map) x=43 y=43`
  - Working interpretation:
    - natural x=29 descent does not recreate the earlier half-open
      `DOWN,25` family; the clean wait window from natural starts blocks left
      at `(29,21)`
    - the straight south lane to `(29,29)` remains live and should stay open
    - keep `(29,21)->LEFT` as stateful/runtime-only evidence for now rather
      than promoting a permanent `(28,21).east` blocker
    - next castle-side work needs a restored Tanticle state; current live state
      after validation is the World Map at `(43,43)`

- 2026-05-25 route executor validation after teleport/input fixes:
  - `auto_walk:29,29` no longer reproduced the old row-9 loop and advanced
    from the northwest castle area through row 9 to `(28,23)` before a manual
    stop.
  - The route did expose an executor bug after a seam retry:
    - follow-up plan was built from `(27,10)` with an initial settle window
    - during settle the engine drifted to `(27,11)`
    - because queued routes were not anchored to their planned start until
      first `begin_step`, the first follow-up step began from `(27,11)` rather
      than consuming/cancelling the drift first
  - Patch in progress:
    - `route_manager.queue_path_steps` now passes a derived planned start to
      `auto_step.start_route`
    - `auto_step.start_route` seeds `route_last_x/y` from that start, so
      initial-settle drift uses the same catch-up/off-path guard as later
      route settle windows
  - Local verification after patch:
    - `luac5.1 -p main.lua route_manager.lua auto_step.lua test_auto_step.lua test_route_manager.lua config.lua`
    - `lua5.1 test_auto_step.lua` passed 60 tests
    - `lua5.1 test_route_manager.lua` passed 80 tests
    - targeted `git diff --check` passed
  - Needs FCEUX Lua reload before live route validation can prove the new
    initial-settle anchor behavior.

- 2026-05-25 live validation after route-start anchor reload:
  - Command-loop proof succeeded:
    - `LAUNCHER_PROBE: validate_anchor_reload`
    - `POSITION: map=0x04(Tantegel Castle) x=28 y=23`
  - Teleported to `(7,8)` for the full southeast-route repro:
    - `MOVEMENT_STATE_RESET reason=teleport_to ... before_move=0x0D before_sub=0x90`
    - `TELEPORT_STATE_GUARD_END ... resets=12 ... last_move=0x01 last_sub=0x90`
  - `auto_walk:29,29` proved the anchor patch is active:
    - `auto_step route initial settle frames=16 ... start=(7,7)`
    - initial-settle drift is now explicitly caught as
      `route_drift not on queued path` and rerouted instead of silently
      beginning the first follow-up step from the wrong tile
  - New executor problem exposed:
    - the forced-teleport route bounced between `(7,3)`, `(7,4)`, and `(7,5)`
    - every seam retry moved, then stale direction/momentum carried one tile
      off the follow-up path during the initial settle window
    - repeated seam-retry completions were also resetting the drift-reroute
      guard, so the oscillation could continue indefinitely
  - Patch added after the live stop:
    - seam retries now use the same forced neutral post-step release as
      debug/probe injected steps
    - route drift reroute count now resets only on queued-route progress, not
      on standalone seam-retry completions
  - Local verification after patch:
    - `luac5.1 -p main.lua route_manager.lua auto_step.lua test_auto_step.lua test_route_manager.lua config.lua`
    - `lua5.1 test_auto_step.lua` passed 61 tests
    - `lua5.1 test_route_manager.lua` passed 81 tests
    - targeted `git diff --check` passed
  - Needs another FCEUX Lua reload before live validation can confirm the
    seam-retry neutral release stops the `(7,3)`/`(7,5)` oscillation.

- 2026-05-25 live validation after seam-retry neutral-release reload:
  - Command-loop proof succeeded:
    - `LAUNCHER_PROBE: seam_release_reload`
    - `POSITION: map=0x04(Tantegel Castle) x=7 y=3`
  - Starting from the live oscillation pocket, `auto_walk:29,29` still bounced
    around `(7,3)` / `(7,4)` / `(7,5)`.
  - Good result:
    - the drift-reroute guard no longer resets on standalone seam-retry
      completions
    - after 7 drift reroutes it logged
      `AUTO_WALK_DRIFT_REROUTE_LIMIT ... current=(7,5)` and restored parked
      NPCs cleanly
  - Remaining issue:
    - forced neutral release alone did not stop the engine from committing the
      extra tile after a seam retry
    - post-cancel movement snapshot at `(7,5)` still showed
      `MOVEMENT_STATE tag=after_limit ... ram0030_004F ... 07 05 E0 90 ...`
      with no buttons held
  - Patch added after this validation:
    - successful `seam_retry` completion now zeros `MOVEMENT_STATE` and
      `MOVEMENT_SUBPIXEL` before route-manager follow-up planning
    - new log line: `AUTO_STEP_MOVEMENT_STATE_RESET reason=seam_retry_complete`
  - Local verification after patch:
    - `luac5.1 -p main.lua route_manager.lua auto_step.lua test_auto_step.lua test_route_manager.lua config.lua`
    - `lua5.1 test_auto_step.lua` passed 62 tests
    - `lua5.1 test_route_manager.lua` passed 81 tests
    - targeted `git diff --check` passed
  - Needs FCEUX Lua reload before live validation can confirm movement-state
    reset stops the `(7,3)`/`(7,5)` seam-retry overshoot.

- 2026-05-25 live validation after seam-retry movement-state reset reload:
  - Command-loop proof succeeded:
    - `LAUNCHER_PROBE: seam_state_reset_reload`
    - `POSITION: map=0x04(Tantegel Castle) x=7 y=5`
    - baseline movement bytes were stale-ish:
      `MOVEMENT_STATE tag=before_retry ... 07 05 90 90 ...`
  - `auto_walk:29,29` from `(7,5)` proved the reset hook was loaded:
    - repeated `AUTO_STEP_MOVEMENT_STATE_RESET reason=seam_retry_complete`
      lines appeared after seam-retry completions
  - But the route still bounced:
    - `(7,5)->UP` seam retry reached `(7,4)` and then drifted to `(7,3)`
    - `(7,3)->DOWN` seam retry reached `(7,4)` and then drifted to `(7,5)`
    - after 7 reroutes the guard cancelled cleanly:
      `AUTO_WALK_DRIFT_REROUTE_LIMIT ... current=(7,3)`
  - New interpretation:
    - zeroing movement state at tile-completion is too late; the next tile is
      already latched because seam retry holds direction until completion
    - the fix should bound seam retry's post-movement-start hold, not hold all
      the way to tile arrival
  - Patch added after this validation:
    - `auto_step` now supports `hold_after_movement_start_frames`
    - seam retries default to
      `auto_step_seam_retry_hold_after_start_frames=12`
    - `dw_access.ini` and `config.lua` include the new knob
    - regression:
      `seam_retry_bounded_hold_releases_before_tile_completion`
  - Local verification after patch:
    - `luac5.1 -p main.lua route_manager.lua auto_step.lua test_auto_step.lua test_route_manager.lua config.lua`
    - `lua5.1 test_auto_step.lua` passed 63 tests
    - `lua5.1 test_route_manager.lua` passed 81 tests
    - targeted `git diff --check` passed
    - `git diff --check -- dw_access.ini` passes but repeats the existing CRLF
      warning
  - Current live state after the guard trip:
    - `POSITION: map=0x04(Tantegel Castle) x=7 y=3`
    - `PATH_STATE target=nil map=0x04 runtime_count=0`
    - `RUNTIME_BLOCKS map=0x04 none`
  - Needs FCEUX Lua reload before live validation can confirm the bounded
    seam-retry hold stops the overshoot.

- 2026-05-25 live validation after bounded seam-retry hold reload:
  - Command-loop proof succeeded:
    - `LAUNCHER_PROBE: bounded_seam_reload`
    - `POSITION: map=0x04(Tantegel Castle) x=7 y=3`
    - baseline movement state still showed a non-idle pocket fingerprint:
      `MOVEMENT_STATE tag=bounded_before ... 07 03 01 90 ...`
  - `auto_walk:29,29` from `(7,3)` no longer bounced between `(7,3)` and
    `(7,5)`.
  - First step `(7,3)->DOWN` still needed one internal timeout retry, but then
    completed as a queued-route step rather than seam-retry overshoot:
    - `auto_step timeout retry 1/1 from=(7,3) dir=down`
    - `auto_step complete dir=down from=(7,3) to=(7,4) ... queued_route=true`
  - The route then proceeded east across row 4, down to row 7, east to x=29,
    and south down the x=29 lane to `(29,29)`.
  - Completion evidence:
    - `AUTO_WALK_NPC_PARK_RESTORE ... reason=autowalk route complete`
    - final state:
      `POSITION: map=0x04(Tantegel Castle) x=29 y=29`
      `PATH_STATE target=nil map=0x04 runtime_count=0`
      `RUNTIME_BLOCKS map=0x04 none`
  - Remaining observation:
    - the coordinate route ends on the southeast exit tile and faces south; it
      did not transition to the world map during this validation pass. Treat
      that separately from the executor pocket fix unless it repeats as a
      player-facing route issue.

- 2026-05-25 southeast-stairs detour blocker pass from `(26,7)`:
  - User-observed autowalk chose an upper/eastern route to the southeast
    stairs/exit and stalled at `(26,7)`.
  - Fresh log baseline:
    - `POSITION: map=0x04(Tantegel Castle) x=26 y=7`
    - `PATH_STATE target=nil map=0x04 runtime_count=0`
    - the prior route had repeated `SEAM_OBSERVATION` blockers at
      `(27,7).west` and `(26,6).south`
  - Clean verifier promotions:
    - `probe_edge_verify:26,7,RIGHT,5` -> `(27,7).west` blocked 5/5
    - `probe_edge_verify:26,7,UP,5` -> `(26,6).south` blocked 5/5
    - runtime-injected those two and reran; the next route hit
      `(25,7)->UP`
    - `probe_edge_verify:25,7,UP,5` -> `(25,6).south` blocked 5/5
  - Non-promotion:
    - the route briefly showed `(24,6)->RIGHT` into `(25,6)` as blocked/noisy,
      but direct `probe_edge_verify:24,6,RIGHT,5` moved 6/6 including the
      stability recheck, so `(25,6).west` stays open.
  - Permanent patch:
    - `map_reader.lua` now has `(25,6).south`, `(26,6).south`, and
      `(27,7).west` for map `0x04`
    - `test_map_reader.lua` asserts those three faces plus the open
      `(25,6).west` guard
  - Verification:
    - `luac5.1 -p map_reader.lua test_map_reader.lua`
    - `lua5.1 test_map_reader.lua` passed 37 tests
    - `git diff --check -- map_reader.lua test_map_reader.lua`
  - Live validation after `reload_navigation_modules` and
    `clear_runtime_blocks:0x04`:
    - `debug_pathfind_to_allow_hazards:29,29` from `(26,7)` planned
      `2 west, 1 north, 5 east, 23 south`
    - `auto_walk:29,29` completed to `(29,29)` with no runtime blockers
    - the route had one drift reroute around `(24,7)` but recovered and then
      crossed `(24,6)->(25,6)->...->(29,6)` cleanly
  - Post-validation input note:
    - `./recover_fceux_input.sh` cleared stale Alt, but the bridge later
      delivered short `Up` taps and moved the hero from `(29,29)` to `(29,26)`;
      final quiet check showed `POSITION ... x=29 y=26`,
      `PATH_STATE ... runtime_count=0`, and stale `LeftAlt` only.

- 2026-05-25 follow-up successful but noisy route from `(7,7)` to `(29,29)`:
  - The route completed, but temporarily routed around three apparent blockers:
    `(13,9).west`, `(19,6).west`, and `(25,6).west`.
  - Direct verifier follow-up cleared all three as passable:
    `probe_edge_verify:12,9,RIGHT,5`, `probe_edge_verify:18,6,RIGHT,5`,
    and `probe_edge_verify:24,6,RIGHT,5` each moved 6/6 with stability
    recheck.
  - Existing `test_map_reader.lua` assertions already keep those approaches
    open. Treat this as executor/turn-settle/seam-retry noise, not permanent
    map data.

- 2026-05-25 correction after the same noisy-route follow-up:
  - The post-verifier recovery bridge taps moved `(26,6)->DOWN` and then
    `(26,7)->UP`, contradicting the just-promoted `(26,6).south` block.
  - Clean direct rechecks then showed the whole small patch cluster was open:
    - `probe_edge_verify:25,5,DOWN,5` -> `(25,6).north` moved 6/6
    - `probe_edge_verify:26,5,DOWN,5` -> `(26,6).north` moved 6/6
    - `probe_edge_verify:25,7,UP,5` -> `(25,6).south` moved 6/6
    - `probe_edge_verify:26,7,UP,5` -> `(26,6).south` moved 6/6
    - `probe_edge_verify:26,7,RIGHT,5` -> `(27,7).west` moved 6/6
  - Permanent correction:
    - removed the map `0x04` directional blocks for `(25,6)`, `(26,6)`, and
      `(27,7).west`
    - updated `test_map_reader.lua` to guard those approaches open
  - Live validation after `reload_navigation_modules`:
    - `debug_pathfind_to_allow_hazards:29,29` from `(26,6)` planned
      `3 east, 22 south` with zero hazards
    - `auto_walk:29,29` completed to `(29,29)` with no runtime blockers
  - Leave stale `LeftAlt` alone near the southeast exit unless recovery is
    actually needed; `./recover_fceux_input.sh` can send bridge taps that move
    the hero.

- 2026-05-25 route-temp validation after reload from `(23,7)`:
  - Fresh probe:
    - `POSITION: map=0x04(Tantegel Castle) x=23 y=7`
    - `RUNTIME_BLOCKS map=0x04 none`
    - `PATH_STATE target=nil map=0x04 runtime_count=0`
  - `debug_pathfind_to_allow_hazards:29,29` planned `6 east, 22 south`.
  - Live `auto_walk:29,29` still hit `AUTO_WALK_DRIFT_REROUTE_LIMIT` at
    `(23,7)` with no runtime blocks.
  - Log pattern:
    - repeated timing-suspect route blocks through `(24,7)` from both
      `(23,7)->RIGHT` and `(25,7)->LEFT`
    - seam retry then moved through `(24,7)`, but the initial follow-up settle
      saw off-path carry to `(23,7)` or `(25,7)`
  - Runtime-only planner check:
    - adding temporary `add_blocked_edge:23,7,RIGHT` still allowed a route:
      `1 south, 3 east, 1 north, 3 east, 22 south`
    - this supports active-route-local avoidance for noisy timing seams rather
      than permanent map blockers.
  - Code patch awaiting live reload:
    - `auto_step.lua` preserves the original injected source on completion and
      measures route timing-suspect timeouts from the movement-start frame
    - `route_manager.lua` now records timing-suspect seam retries as
      active-route-local temp blocks and retains them through seam-retry
      follow-up planning
    - tests: `lua5.1 test_auto_step.lua` passed 65, `lua5.1
      test_route_manager.lua` passed 83, syntax and `git diff --check` passed
      aside from the existing `dw_access.ini` CRLF warning
  - Need manual FCEUX Lua reload before live validation of this patch.
  - Live validation after reload from `(7,8)`:
    - route avoided the old `(24,7)` drift loop but stopped at `(7,17)` with
      `reason=no path found after seam brute force`
    - retained active-route temp blocks were too broad:
      `(7,8)->UP`, `(12,9)->RIGHT`, and `(7,16)->DOWN`
    - reproducing the planner state showed temporary `(12,9)->RIGHT` alone
      makes the planner from `(7,17)` report `No path found`, while clearing
      temp blocks restores a route
  - Follow-up code patch awaiting live reload:
    - seam-retry follow-up planning now relaxes active-route temp blocks and
      replans when those temp avoids eliminate all paths
    - regression test
      `seam_retry_followup_relaxes_route_temp_blocks_when_they_eliminate_all_paths`
      covers the fallback
    - tests: `lua5.1 test_route_manager.lua` passed 84, `lua5.1
      test_auto_step.lua` passed 65, syntax and `git diff --check` passed
      aside from the existing `dw_access.ini` CRLF warning
  - Need another manual FCEUX Lua reload before retrying from the current
    live position `(7,17)`.
  - Follow-up after user restored/reloaded to `(7,8)`:
    - full route reached `(12,9)` and stopped with
      `reason=no path found on reroute`
    - direct verifier from the stopped state proved `(12,9)->RIGHT` into
      `(13,9).west` blocked 5/5 with no drift/NPC/map-change contamination
    - reverse verifier proved `(13,9)->LEFT` back to `(12,9)` moved 6/6
      including stability recheck
    - runtime planner check with only `add_blocked_edge:12,9,RIGHT` from
      `(12,9)` found a 77-step detour, so the no-path was older temp avoids
      plus the current gate, not a disconnected castle
  - Code/data patch awaiting live reload:
    - `MAP_DIRECTIONAL_BLOCKS[0x04]["13,9"].west = true` again, documented as
      a default-closed state/order-sensitive west-to-east gate while reverse
      remains open
    - blocked-step reroute now relaxes older active-route temp blocks when
      they eliminate all paths, while keeping the current failed edge blocked
    - tests: `lua5.1 test_route_manager.lua` passed 85, `lua5.1
      test_map_reader.lua` passed 37, syntax and `git diff --check` passed
  - Need another manual FCEUX Lua reload before live validation.

- 2026-05-25 follow-up correction after entrance-side planner collapse:
  - Backed out the permanent `(13,9).west` closure; keeping that edge
    default-closed made the restored entrance-side planner no-path because
    stationary Guard 7 at `(8,8)` blocked the long detour's first step.
  - Current model interpretation:
    - `(12,9)->RIGHT` can still be engine-blocked in some live states.
    - Treat it as route-local/state-order evidence, not permanent map data.
    - Blocked-step reroute should keep the current failed edge blocked but
      relax older route-local temp blocks if they eliminate all paths.
  - Live validation after reload/restored `(7,8)`:
    - `debug_pathfind_to_allow_hazards:29,29` found the normal 49-step route.
    - `auto_walk:29,29` completed to `(29,29)` and transitioned to World Map
      `(43,43)`.
    - The route was still noisy: passable upper-east seams accumulated
      timing-suspect route temp blocks before recovery reached the x=29 lane.
    - After route completion, external bridge input (`A`, repeated
      `down`/`up`, `start`) opened/closed menus and walked back into
      Tantegel; treat that as post-route input contamination, not map evidence.
  - Follow-up code patch awaiting live reload:
    - successful seam-retry movement now clears its matching active-route temp
      block before the follow-up plan
    - older temp blocks still relax if they make the graph impossible
    - tests: `luac5.1 -p route_manager.lua test_route_manager.lua
      map_reader.lua test_map_reader.lua auto_step.lua`, `lua5.1
      test_route_manager.lua` passed 85, `lua5.1 test_map_reader.lua`
      passed 37, and targeted `git diff --check` passed
  - Need another manual FCEUX Lua reload before live validation from restored
    Tanticle.
  - Live validation after reload:
    - Route completed to `(29,29)` and transitioned to World Map `(43,43)`.
    - The temp-block clear patch worked: successful seam retries emitted
      `AUTO_WALK_TEMP_BLOCK_CLEAR`, so noisy passable seams no longer stayed
      behind as avoids.
    - Remaining noisy blocks around `(25,6)`, `(26,6)`, and `(27,7)` stayed
      route-local and did not prevent completion.
    - Problem: the final step into `(29,29)` came from the north, and the
      engine transitioned south to World Map 11 frames after route completion.
      The special tile supports STAIRS while south/east movement exits, so
      this looks like a final held-direction overrun rather than passive tile
      warp.
  - Follow-up code patch awaiting live reload:
    - queued routes now use a configurable final neutral settle
      (`auto_step_route_final_settle_frames`, default 16) before publishing
      route completion
    - new regression test
      `queued_route_final_step_neutralizes_before_route_complete`
    - tests: `lua5.1 test_auto_step.lua` passed 66, `lua5.1
      test_route_manager.lua` passed 85, `lua5.1 test_map_reader.lua`
      passed 37, syntax and targeted `git diff --check` passed
  - Live follow-up after reload:
    - one-step route from `(29,28)` to `(29,29)` stayed on map `0x04` after a
      2-second wait, but it completed through the seam-retry path, which
      already resets movement state.
    - two-step route from `(29,27)` to `(29,29)` reproduced the old bug:
      `auto_step route final settle prev=down frames=16` started at final
      arrival, but `EVENT: map change -> 0x01` fired 15 frames later and
      autowalk cancelled with `reason=map change`.
    - Conclusion: final neutral settle alone is not enough; the ordinary
      queued final step also needs the movement-engine reset that made the
      seam-retry case safe.
  - Follow-up code patch awaiting live reload:
    - queued-route final-step completion now calls
      `reset_movement_engine_state("queued_route_final_complete")`
    - new regression test `queued_route_final_step_resets_movement_state`
    - tests: `lua5.1 test_auto_step.lua` passed 67, `lua5.1
      test_route_manager.lua` passed 85, `lua5.1 test_map_reader.lua`
      passed 37, syntax and targeted `git diff --check` passed
  - Live validation after reload:
    - Focused two-step repro from `(29,27)` to `(29,29)` stayed on map `0x04`
      after a long wait.
    - The first `(29,27)->DOWN` was still timing-noisy and crossed via
      seam-retry, but the final `(29,28)->DOWN` completed as a queued route
      step and logged
      `AUTO_STEP_MOVEMENT_STATE_RESET reason=queued_route_final_complete`.
    - Later state check:
      `POSITION: map=0x04(Tantegel Castle) x=29 y=29`,
      `RUNTIME_BLOCKS map=0x04 none`, `PATH_STATE target=nil map=0x04
      runtime_count=0`, and stale `LeftAlt` only.
    - This validates the prior World Map overrun fix for the normal queued
      final step path.
  - Later full-route user report:
    - Full route eventually completed but still walked out of town.
    - Log showed the one-shot final reset fired at `(29,29)`, then
      `EVENT: map change -> 0x01` occurred 15 frames later during the final
      settle window. Diagnosis: the engine can re-arm the exit movement after
      the first reset, so the guard must keep clearing movement state through
      the neutral settle and forced post-step release.
    - Same full route produced
      `AUTO_WALK_NPC_BLOCK map=0x04 from=(14,4) dir=right npc=(15,4)` while
      `npc_mode=park_mobile_npcs`. The old log lacked slot/movement details,
      so it could not prove whether parking missed a mobile NPC or the
      cancellation message was using generic NPC wording.
    - Fresh `report_npcs` after the user-side return to `(7,8)` showed all
      current map `0x04` NPC slots with `move=0x00` and no NPC at `(15,4)`;
      this makes the earlier blocker likely transient/stale, but not enough to
      promote map geometry.
  - Follow-up code patch awaiting live reload:
    - `objects.get_blocking_positions()` now carries NPC id/name/slot/movement
      metadata for route diagnostics.
    - `AUTO_WALK_NPC_BLOCK` logs now include `id`, `slot`, `name`, `kind`,
      `movement`, `parked`, and active `npc_mode`.
    - Parked autowalk can reactively park a newly observed mobile NPC blocker
      and reroute instead of cancelling immediately.
    - Stationary reroute blockers now use the cautious stationary/out-of-date
      NPC message instead of always claiming roaming NPC movement.
    - Final queued-route settle now silently resets movement state throughout
      the final neutral/post-step release window.
    - Tests: `luac5.1 -p auto_step.lua test_auto_step.lua route_manager.lua
      test_route_manager.lua objects.lua test_objects.lua`, `lua5.1
      test_auto_step.lua` passed 68, `lua5.1 test_route_manager.lua` passed
      87, `lua5.1 test_objects.lua` passed 68, and targeted
      `git diff --check` passed.
  - Live validation after reload from restored `(7,8)`:
    - Initial route planned in the intended mode:
      `npc_mode=park_mobile_npcs parked_slots=1 npc_blocks=18`, with mobile
      Merchant 1 parked.
    - The earlier `(14,4)->RIGHT` NPC block did not reproduce; route moved
      through `(15,4)` after a turn repress and produced no
      `AUTO_WALK_NPC_BLOCK` / `AUTO_WALK_NPC_REACTIVE_PARK` event.
    - Upper row-6/row-7 remained noisy and rerouted several times, but all
      blocks stayed route-local; runtime blocks were empty after completion.
    - Full route completed at `(29,29)` and did not transition to the World
      Map. Final step logged
      `AUTO_STEP_MOVEMENT_STATE_RESET reason=queued_route_final_complete
      map=0x04 player=(29,29) before_move=0x05 before_sub=0x00`, and a later
      state check confirmed `POSITION map=0x04 x=29 y=29`,
      `RUNTIME_BLOCKS map=0x04 none`, `PATH_STATE target=nil`, and stale
      `LeftAlt` only.
    - This validates the final-settle movement reset guard for the full
      shrine-stairs route.
