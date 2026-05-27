# Session Handoff - Active Resume

Updated: 2026-05-26

This file is the short current resume point. Detailed Tantegel Castle and Sun
Shrine evidence from the prior wrap is archived at:

- `handoff_archive/HANDOFF_2026-05-25_tantegel_map04_wrapup_session_handoff_full.md`
- `handoff_archive/HANDOFF_2026-05-25_tantegel_investigation_scratchpad.md`
- `handoff_archive/HANDOFF_2026-05-22_pre_cleanup_session_handoff_full.md`

## Current Direction

- Player-facing gameplay is FCEUX-first.
- BizHawk remains the explicit automation/debug/reload-heavy runtime.
- Active gameplay location is Garinham map `0x09`.
- Latest fresh probe after reverse-route analysis restored the hero to
  `POSITION: map=0x09(Garinham) x=19 y=11`, with `RUNTIME_BLOCKS map=0x09
  none`. Final cleanup command `reset_movement_state:after_reverse_analysis_restore`
  cleared movement state at that position.
- `INPUT_STATUS` may still show the benign FCEUX `LeftAlt` latch with no bridge
  direction; do not treat that as movement evidence.
- The Garin's Grave entrance is now confirmed: STAIRS from Garinham `(19,0)`
  changes to map `0x18` / Garin's Grave B1. User manual follow-up confirmed
  B1 arrival at `(6,1)` and return stairs back to Garinham `(19,0)`.
- The map-data changes can be picked up by `reload_navigation_modules`, but
  the queued-route executor fix in `auto_step.lua` needs a full Lua script
  reload or relaunch before live autowalk testing can exercise it.
- Live verification now shows both-grave-route ends are reachable: from
  `(17,9)` to `(19,0)` and from `(19,0)` back to `(17,9)` with route
  completion and no runtime blockers added.
- Autowalk drift tuning pass: a config-only trial of
  `auto_step_route_turn_settle_frames=8` still drifted, and `0` reached
  `(19,0)` but continued into the world map. `dw_access.ini` is restored to
  `auto_step_route_turn_settle_frames=16`. After manual FCEUX reload, the
  `auto_step.lua` queued-route early-twitch hold cap looked better: the first
  route to grave stairs still overshot from `(19,14)` out to world map, but the
  next attempt completed at `(19,0)` with only one route-drift reroute and no
  temporary block/brute-force retries on the final north lane.
- Follow-up pre-turn tuning is live-tested and looks good:
  `auto_step_route_pre_turn_inject_limit=10` shortens the last same-direction
  queued step before a turn, and early-twitch turn repress now only re-presses
  the old direction when the next queued step is also that direction. After
  manual FCEUX reload, repeated grave-route runs had no observed drift on the
  grave legs. One remaining route-manager glitch happened after a timing retry
  at `(2,13)->down`: the seam follow-up reached `(2,14)` but reported
  `No path found`, while a fresh `auto_walk` immediately planned `1 west` to
  the exit. Treat this as a follow-up planner/replan bug, not map evidence.
  `route_manager.lua` now gives that exact no-temp-blocks seam-followup
  false negative one refreshed replanning attempt
  (`seam_retry_followup_refreshed`) before cancelling; this needs a full Lua
  reload in FCEUX. Follow-up live routes did not hit this exact refreshed
  fallback branch: one exit route from `(15,15)` cancelled early with
  `can_walk_false`, the next recovered a one-tile overshoot from `(0,14)` back
  to `(1,14)`, and the route from the west exit to `(19,0)` completed cleanly.
  Treat that as no new map-block evidence. A focused regression test now covers
  the cleared-temp-block seam-followup false negative.
  `luac5.1 -p auto_step.lua test_auto_step.lua config.lua`,
  `lua5.1 test_auto_step.lua`,
  `luac5.1 -p route_manager.lua test_route_manager.lua`, and
  `lua5.1 test_route_manager.lua` pass.

## Garinham Status

- Public Garinham services are usable: west-side `Exit to World Map`,
  `Tool Merchant`, `Inn`, and `Weapons Merchant`.
- Garinham `Merchant 1` is a dialogue-only hint NPC. Live TALK from adjacent
  stand `(9,5)` facing south produced the darkness/map hint, so Services now
  excludes him while NPC browsing still exposes him.
- The old public east-door guess at `(19,16)` is disproved. OPEN from
  `(19,17)` facing north reported `There is no door here.`
  `objects.lua` no longer exposes `door_19_16`, and `map_reader.lua` no longer
  lists `(19,16)` in `MAP_DOOR_CELLS[0x09]`.
- The grey-building grave-route door is now modeled as door cell `(17,10)`,
  exposed as `Grave Route Door` / `door_17_10`, with route interaction stand
  `(17,9)` facing south. Evidence came from the user's Magic Key/manual OPEN
  pass plus fresh `DOOR_STATE keys=5 slots=0=(17,10)` after opening from
  `(17,9)` facing south. The earlier `(18,9)` estimate is not a door override.
- Door-RAM seed tests did not open route-shaped candidates `(13,4)`,
  `(19,7)`, or `(19,9)`. Keep those as wall/route geometry until exact OPEN
  or door-RAM proof says otherwise.
- Old Man 3 at `(14,1)` appears in the object list but is not an NPC blocker.
  Trail-blazing later proved the west approach into that cell is still an
  engine seam: `probe_edge_verify:RIGHT,5` from `(13,1)` blocked 5/5 with no
  NPC at `(14,1)`. The reverse grave-stairs-to-door run also confirmed
  `(15,1)->LEFT` into `(14,1)` blocks 5/5, so both east and west approaches
  are now modeled.

## Grave-Route Evidence

- Guide/image orientation points to the grey-building back-wall / "wall of
  darkness" path, but guide data is only orientation; live map transitions are
  the source of truth.
- `MAP_PASSTHROUGH_CELLS[0x09]["3,3"]` is confirmed: live
  `probe_edge_verify` from `(3,4)->UP` moved into this ROM-wall tile 6/6 after
  a stability recheck.
- `MAP_PASSTHROUGH_CELLS[0x09]["19,10"]` is confirmed: after the top lane at
  `(13,1)->RIGHT` proved blocked, route frontier found the lower bridge, and
  `probe_edge_verify:19,11,UP,5` moved into `(19,10)` 6/6 including stability
  recheck.
- After the map patch, `debug_pathfind_to:19,0` found a live route from
  `(13,1)`: `2 west, 10 south, 8 east, 11 north`. A pre-reload autowalk using
  the old loaded `auto_step.lua` reached `(19,11)` but timed out on the turn
  upward into `(19,10)` with stale movement bytes (`move=0x40 sub=0x90`).
  `auto_step.lua` now clears movement state during queued route turn/final
  settle frames; retest after a full Lua reload.
- A post-reload route reached `(18,1)`.
- Direct probing then proved `(18,1)->UP` moves into standable `(18,0)`.
- Direct probing from `(18,0)->UP` changed the map to `0x01` / World Map and
  landed near Garinham on the overworld. This is not Garin's Grave B1.
- ROM stair-down table entry `09 13 00` at file offset `0xF411` points to
  Garinham `(19,0)`.
- Live STAIRS from `(19,0)` while the command menu was on STAIRS produced
  `EVENT: map change -> 0x18 (Garin's Grave B1)`.
- User manual follow-up confirmed the B1 arrival tile is `(6,1)` and the return
  stairs come back to Garinham `(19,0)`.
- Therefore `(18,0)` stays a passthrough/world-exit edge cell, while `(19,0)`
  is the exposed `Stairs to Garin's Grave` object.
- Reloaded reverse autowalk from `(19,0)` toward `Grave Route Door` did not
  find a new door. It drifted through a town/world exit after moving right into
  `(19,1)`: `EVENT: map change -> 0x01 (World Map)` at frame `08396`, followed
  by route drift at world-map `(2,2)`.
- Clean reverse-route verifiers promoted `(18,2).north`, `(17,2).north`,
  `(16,2).north`, `(15,2).north`, and `(14,1).east`. The suspicious
  `(19,1)->DOWN` into `(19,2)` verifier was mixed (`moved=2 blocked=3`), so
  keep `(19,2).north` unmodeled for now.
- With those clean blockers runtime-injected, `debug_pathfind_to:17,9` from
  `(19,0)` can now resolve in this state and execution follows with route
  drift or timing retries, but no newly promoted persistent blockers.

## New Map Data In This Working Tree

- `MAP_PASSTHROUGH_CELLS[0x09]`: adds `(3,3)`, `(18,0)`, and `(19,0)` for the
  hidden back-wall/top-edge route and true grave stairs, plus `(19,10)` for
  the live-confirmed lower grave-route bridge.
- `objects.lua`: exposes Garinham `stair_19_0` as `Stairs to Garin's Grave`.
- `MAP_DOOR_CELLS[0x09]` / `objects.lua`: adds `(17,10)` as the
  grey-building `Grave Route Door`, closed until opened-door RAM includes
  `(17,10)`, and routes interaction to `(17,9)` facing south.
- `MAP_DIRECTIONAL_BLOCKS[0x09]`: adds verified approach-specific blockers for
  the grave-route survey, including row-9 south approaches, the `(13,3)` to
  `(13,6)` west wall, row-6 south approaches, `(19,7..9).west`,
  `(18,14).east`, `(14,1).east/west`, the latest clean `(15,10).south` /
  `(16,10).south`, and reverse top-row blockers `(15..18,2).north`.
- Explicit open assertions keep `(15,10).west` and `(4,12).south` open after
  clean live movement proof.
- `NONBLOCKING_NPC_CELLS[0x09]["14,1"]` keeps the browseable false Old Man
  from blocking the hidden route.
- `auto_step.lua`: queued autowalk turn/final settle frames now clear stale
  movement state/subpixel bytes, controlled by
  `auto_step_reset_movement_on_route_turn_settle` in `config.lua`.

## Suggested Next Step

Reverse route checks are still useful while the door is open:

- Pre-turn inject-limit tuning is active after manual reload; keep it unless a
  regression appears.
- `auto_walk:19,0` from `(17,9)` and `auto_walk:17,9` from `(19,0)` both
  complete with route completion logs.
- If the player exits Garinham, the door closes; restore/re-open from
  `(17,9)` before attempting reverse route checks again.
- After reloading Lua, repeat a route that crosses the `(2,13)->down` seam
  toward the west exit and watch for `AUTO_WALK_SEAM_FOLLOWUP_RETRY` followed
  by a successful `seam_retry_followup_refreshed` route instead of immediate
  cancellation. The latest manual routes did not reproduce that exact
  false-negative branch.
- Continue Grave B1 decode from confirmed stairs arrival `(6,1)` now that the
  grave-side link is stable.

## Verification To Run Before Commit

- `luac5.1 -p auto_step.lua test_auto_step.lua config.lua debug_tools.lua map_reader.lua test_map_reader.lua objects.lua test_objects.lua`
- `luac5.1 -p route_manager.lua test_route_manager.lua`
- `lua5.1 test_route_manager.lua`
- `lua5.1 test_auto_step.lua`
- `lua5.1 test_map_reader.lua`
- `lua5.1 test_objects.lua`
- `lua5.1 test_debug_tools.lua`
- `git diff --check`
