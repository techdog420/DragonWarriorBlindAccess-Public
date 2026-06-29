# Session Handoff - Active Resume

Updated: 2026-06-29

## Current State

- Rimuldar / Remuldar Magic Key merchant is the active route target. The service
  identity is solid: `Old Man 1` at `(4,7)`, public stand `(4,6)` facing south,
  and TALK from that stand opens the 53 G Magic Key prompt. The route model is
  not solid: newer live FCEUX evidence repeatedly blocks `(1,8)->RIGHT` into
  `(2,8).west`, but permanently closing that edge currently isolates the known
  merchant-side component. Keep `(2,8).west` unpromoted until a missing bridge,
  transition/state condition, or manual route trace explains the route. Current
  best next step after the user's clean save-state/script reload and town
  leave/re-enter reset is a bounded baseline: confirm position/runtime blocks,
  compare `debug_pathfind_to_skip_npcs:4,6` and
  `debug_route_frontier_skip_npcs:4,6,80`, try one `auto_walk_blocker:4,6`,
  then repeat the frontier with only runtime `add_blocked_edge:1,8,RIGHT` if
  the route still depends on the disputed bridge.
- Garin's Grave / Grave of Garinham route decoding is complete for current
  playtesting needs.
- The detailed final Garin's Grave wrap-up was archived to
  `handoff_archive/HANDOFF_2026-06-17_garins_grave_final_wrapup_full.md`.
- The detailed scratchpad evidence was archived to
  `handoff_archive/HANDOFF_2026-06-17_garins_grave_final_scratchpad.md`.
- Garinham grave-return stairs now have a verified escape to the inn by
  leaving town and re-entering from the world map. The old `(19,10)` lower
  bridge was verifier/teleport fallout and is no longer modeled as a
  passthrough. A later manual route check found the return-side top-edge bypass:
  `(12,0)->RIGHT` enters `(13,0)`, `(13,0)->RIGHT` enters `(14,0)`, and
  `(14,0)->LEFT` returns to `(13,0)`. Follow-up grave-stairs route polishing
  proved the row-0 bypass continues one step farther via `(14,0)->RIGHT` into
  `(15,0)`, then descends through `(15,1)` and reaches the grave stairs at
  `(19,0)` along row 1. `map_reader.lua` now models `(13,0)`, `(14,0)`, and
  `(15,0)` as Garinham passthrough cells, preserves `(14,1)` as blocked from
  north/east/west, and closes the false shortcut edges exposed from `(9,3)`
  onward, including the post-reload `(6,7)->UP` and `(3,7)->UP` cleanup. Reload
  `main.lua` in FCEUX before judging the live planner against this source fix.
- Garinham `Grave Route Door` now preserves both verified interaction sides:
  north-side `(17,9)` facing south from the grave-route component, and
  public-side `(17,11)` facing north toward closed door cell `(17,10)`.
  `objects.lua` exposes them through `interaction_points` so the existing
  alternate-stand route planner can choose the reachable side after a full
  FCEUX Lua reload. This fixes object routing to the door stand, but does not
  prove a clean route onward to the grave stairs.
- Garinham's inner locked-building door is now modeled at `(4,6)` with object
  stand `(4,7)` facing north. It leads to a one-cell guard pocket at `(4,5)`;
  `(4,5)->UP` is blocked as `(4,4).south`, and the side exits are stationary
  guards, so do not treat it as a grave-route shortcut without new event proof.
- FCEUX remains the normal gameplay and agent-driven runtime for this repo.
  BizHawk is still useful for explicit automation/debug/reload/profiling work,
  but it is not the default route-testing runtime.
- Brecconary Magic Key cleanup is complete for current alpha-prep playtesting.
  The inn west-room door is now
  live-confirmed at door cell `(5,23)`, opened from `(6,23)` facing west; the
  old `(5,22)` model is a ghost. The opened-door side uses passthrough
  `(3,23)`, blocks false west exit `(3,23)->WEST` as `(2,23).east`, and keeps
  `(8,23)->UP` blocked as `(8,22).south` after restored-route autowalk plus a
  same-origin raw probe timed out. The old `(7,21).west` one-way block was
  stale: `verify_walked_edge:6,21,right` crossed `(6,21)->RIGHT`, and
  `auto_walk_blocker:1,15` then reached the entrance-side stand `(1,15)` from
  `(8,21)` via `4 north, 7 west, 2 north` with no runtime blocks left.
- Brecconary exit-tile object browsing needs the latest `route_manager.lua`
  reload before judging `reachable` pathability from `(0,15)`. Live state on
  map `0x08` showed `(0,15)` is a non-walkable engine-boundary tile even while
  the hero is standing there; old pathability flood-fill treated that as a
  one-tile component and exposed only `Exit to World Map`. The patch seeds the
  reachable set from adjacent walkable cells in that boundary-start case.
  Live workaround already applied: `pathability_filter:all` restored the full
  object list (`Exit to World Map: here (1 of 23)`).
- Brecconary Fairy Water routing is verified clean to and from the merchant.
  The seller
  is a moving Woman behind the northeast counter at `(24,3)..(24,5)`, but the
  live-confirmed trigger is fixed: route to `(22,4)` facing east and hold the
  target NPC briefly at `(24,4)`, not into the blocked pocket at `(23,row)` or
  to a same-row `(22,row)` stand.
  `map_reader.lua` now closes the fresh route/manual blockers around that
  counter: `(20,3).east`, `(20,5).east`, `(21,2).south`, `(22,2).south`, and
  `(23,3..5).west`. An earlier TALK test also captured a possible FCEUX input-lock
  state where Lua saw controlled `A` presses and command polling stayed alive,
  but the ROM did not open the field command menu. Treat that as a secondary
  diagnostic path only if the fixed `(22,4)` stand plus `(24,4)` target hold
  still fails after reload; `report_input_guard_state` is staged for that case.
- Kol Magic Key door discovery is now pinned in source. `Western Building Door`
  is door cell `(7,12)`, opened from `(8,12)` facing west; `West Side Door` is
  door cell `(1,14)`, opened from `(2,14)` facing west. The stale
  `(7,12).east` wall is removed because it was the closed door, while
  `(7,11).east` remains a real directional blocker. False checked candidates:
  `(1,13)` from `(1,14)` facing up, `(1,3)` from `(1,4)` facing up, and
  `(1,4)` from `(2,4)` facing left all produced no-door/no-key-delta results.
  FCEUX needs a manual Lua reload before object browsing and pathfinding use
  the new Kol door objects.
- Kol Tool Merchant route polish promoted the current blocker batch in
  `map_reader.lua`: `(16,22).east`, `(1..4,10).north`, `(4,10..13).east`,
  `(7,9).west`, and `(7,13).east/west`. The current Tool Merchant identity is
  still valid from selected-teleport TALK proof at `(12,21)` facing east. A
  later manual route check found the missing public throat: `(1,16)->DOWN`
  enters `(1,17)`, even though `(1,17)` ROM-decodes as tile-0/non-walkable;
  once standing on `(1,17)`, the planner finds the Tool Merchant route again.
  The missing entrance-side connector to that throat is `(5,14)`: after a clean
  restore from the town entrance, `debug_route_frontier_skip_npcs` flagged
  `(5,14)/(6,14)/(7,14)` as wall-looking one-cell bridge candidates, and a
  normal walk to `(5,13)` plus same-origin `probe_edge:DOWN` moved through
  tile-0 `(5,14)` and settled at `(5,15)`. `map_reader.lua` now models only
  proven `(1,17)` and `(5,14)` as Kol passthroughs. The earlier post-`(1,17)`
  reload route also tried the standable `(1,19)` pocket; same-origin probes
  proved its east, south, and north exits blocked, so `(2,19).west`,
  `(1,20).north`, and `(1,18).south` are now directional blockers. Final
  entrance-to-stand cleanup found the lower public bridge: from normally walked
  `(3,15)`, `probe_edge:DOWN` carried through `(3,16)` onto tile-0 `(3,17)`,
  then `(3,17)->DOWN` exited to the target-side lane. `map_reader.lua` now
  models `(3,17)` as the narrow Tool Merchant bridge and closes the route
  false exits `(5,16).north`, `(2,15).east`, `(2,16).east`, `(3,14).south`,
  and `(10,19).west`; with those runtime blockers active,
  `auto_walk_blocker:12,21` reached the stand. Reload `main.lua` again before
  judging the live planner against these source fixes, then retest route
  guidance/autowalk to Tool Merchant from the town entrance. Do
  not promote the later post-teleport `(1,16)->DOWN` or `(1,16)->RIGHT`
  failures: even the ordinary east step to `(2,16)` falsely blocked from that
  seed, so the live movement state was contaminated. Kol also exposed stale
  lower-window status residue (`ll` / `Bill`) after movement, probe, and
  command-menu activity; `main.lua` now suppresses known passive status/name
  fragments during field play, command menu, and SPELL submenu while still
  respecting STATUS/ITEM submenus, prompts, and merchants, so `J/K/L/O`, edge
  probes, command-menu speech, and spell-list speech should not remain stuck
  behind those fragments. Reload `main.lua` before live-testing that dialogue
  guard fix. A follow-up held-ITEM menu bug was also fixed in `merchant.lua`:
  the merchant parser no longer treats full command-menu backdrop plus
  inventory entries, or status rows plus unpriced inventory entries, as a shop
  offer list, preventing `MERCHANT_SELECT` speech such as item names with bogus
  prices while browsing items. A later live attempt still produced
  `MERCHANT_SELECT` before any `CMD_ITEM_FIRE`; `check_command_menu()` now lets
  ITEM ownership run before merchant detection. After a full emulator restart,
  the remaining root cause was that the cursor-jump detector never fired before
  merchant ownership; the direct A press on confirmed ITEM(1,1) now sets
  `submenu_mode = "ITEM"` first, with the older cursor-jump detector retained as
  a fallback. A final follow-up fixed the remaining bulk inventory speech:
  after ITEM ownership worked, `check_dialogue()` still announced visible item
  rows as lower dialogue (`Silver Harp Cursed Belt Gwaelin's Love Torch`).
  STATUS, ITEM, and SPELL submenu windows are now absorbed by the generic lower
  dialogue reader because those screens are spoken from cursor/RAM state.
  A later Kol wrap-up test found deferred `U` autowalk could start while the
  field command menu was visibly open because hotkeys ran before
  `check_command_menu()` armed `CMD.menu_live` for that frame. `main.lua` now
  blocks field movement on raw COMMAND text only when a visible cursor tile is
  present, and `hotkeys.lua` speaks the current guard reason when a deferred
  autowalk release is cancelled. Reload `main.lua` before live-testing these
  menu/parser/guard fixes.
- Tantegel Castle downstairs Magic Key merchant return polish is promoted in
  `map_reader.lua`: the merchant-to-throne-room-stairs route closed the false
  east/northeast cuts at `(22,6).north`, `(21,5).east`, `(21,4).east`,
  `(23,6).north`, `(23,9).north`, `(24,9).east`, `(24,10).east`,
  `(25,6).south`, `(17,6).south`, and `(15,5).east`. With those runtime blocks
  active, `auto_walk_blocker` reached `Stairs Up to Tantegel Castle Throne Room`
  at `(7,7)` via the west detour. Reload `main.lua` in FCEUX before judging the
  live planner against this source fix. The reverse route back to the Magic Key
  merchant then confirmed `(13,9).west` from `(12,9)->RIGHT` and `(19,6).west`
  from `(18,6)->RIGHT`; with both runtime edges active, `auto_walk_blocker`
  reached the merchant stand at `(24,3)`. The `(18,6)->DOWN` retry moved on seam
  retry and should stay open. The Magic Key merchant <-> main entrance route is
  also promoted: same-origin route/probe evidence closed `(18,14).north`,
  `(18,15).west`, `(23,2).south`, `(23,6).east`, `(25,6).north/west`,
  `(26,6).north/south`, `(27,6).east`, `(27,7).east/west`, and
  `(28,24..28).east`; with that runtime overlay, `auto_walk_blocker` reached
  the exit stand at `(11,29)` and returned to the merchant stand at `(24,3)`;
  the follow-up `(23,2).south` edge came from same-origin `probe_edge:up` at
  `(23,3)`.
  Reload `main.lua` before judging the live planner without those runtime
  blocks.
- Tantegel Castle downstairs Sun Shrine stairs route polish is promoted in
  `map_reader.lua`: same-origin route/probe evidence from the Sun Shrine-side
  lane confirmed the east approaches into `(27,9)`, `(27,10)`, and
  `(27,12)..(27,19)` are blocked from x=28. With those runtime edges active,
  `auto_walk_blocker:7,7` reached `Stairs Up to Tantegel Castle Throne Room`
  from `(28,19)`, and the reverse route `auto_walk_blocker:28,19` reached the
  Sun Shrine-side stand again. The x=28 vertical moves and the `(6,17)` west/east
  crossings moved on seam retry and should stay open. Reload `main.lua` before
  judging live planning without the runtime overlay.
- Sun Shrine map `0x0C` chest / old-man cleanup is promoted in `map_reader.lua`:
  route retries plus same-origin probes closed `(3,3).north/west`,
  `(3,4).east/west`, `(3,5).east/west`, `(3,6).west/south`,
  `(4,3).north/south`, `(5,3).north/south`, `(6,3).north/east`,
  `(6,4).east/west`, `(6,5).east/west`, and `(6,6).east`. With those runtime
  blockers active, a fresh `auto_walk_blocker:4,7` from the Tantegel stairs
  `(0,4)` reached the old-man stand through the x=2 lane, row 7 bypass, and
  east-side pocket, and `auto_walk_blocker:0,4` returned to the stairs through
  the lower bypass. The explicit `(2,2)->DOWN` recheck moved through `(2,3)`,
  `(4,5)->RIGHT` moved on route retry, and the x=2 vertical moves plus row-7
  bypass should stay open. Reload `main.lua` before judging live planning
  without the runtime overlay.
- Rain Shrine / Northern Cave map `0x0D` Staff of Rain return-route cleanup is
  promoted in `map_reader.lua`: same-origin route/probe evidence closed
  `(5,4)->UP` as `(5,3).south` and `(8,8)->DOWN` as `(8,9).north`. With those
  runtime edges active, `auto_walk_blocker:4,9` reached the exit at `(4,9)` via
  the row-8 bypass. The x=8 descent lane above row 9, the row-8 westbound lane,
  and `(4,9).north` moved and should stay open. Reload `main.lua` before
  judging live planning without the runtime overlay.
- Rain Shrine old-man object population is patched in `objects.lua`: re-entering
  from the world map, flipping from map-entry terrain into NPC terrain, or
  reloading the script while already inside Rain Shrine no longer treats the
  old man's already-known NPC signature as stale previous-map residue. He
  should appear after the normal one-frame deferred NPC refresh instead of
  waiting roughly 10-15 seconds. Reload `main.lua` before judging the live
  object browser against this source fix.
- Swamp Cave rescue branch is now live-confirmed through Gwaelin. Door cell
  `(5,20)` is open in slot `0`, Gwaelin is reached from `(5,19)` facing north
  toward `(5,18)`, the escort prompt was accepted, and final field state was
  map `0x15` at `(5,19)` with `combat=0x09`, `quest=0x40`, runtime blocks none.
  Object navigation now exposes Princess Gwaelin as a Swamp Cave NPC target
  before the escort bit, then hides her once `combat` bit `0x01` is set. Next
  gameplay step is escorting her back to Tantegel Castle.
- Swamp Cave known-route polish is promoted in `map_reader.lua`: the Gwaelin
  door / Princess route, south-stairs route, and return route to the North Exit
  now include the walked directional blockers found by `auto_walk_blocker` plus
  direct `probe_edge` checks. The live middle strip `(2,16)..(2,18)` is modeled
  as passthrough, and the latest return overlay reached `(0,0)` through row 21,
  `(2,13)..(2,8)`, and the x=0 corridor. Follow-up route polish from the x=0
  corridor back to the Princess stand confirmed `(2,12)->RIGHT` blocked into
  `(3,12).west`, then a north-exit route check confirmed `(3,13)->UP` blocked
  into `(3,12).south`; runtime-patched routes reached both `(5,19)` and
  `(0,0)`. Follow-up top-corridor polish confirmed `(0,2)->RIGHT` into
  `(1,2).west`, `(0,5)->RIGHT` into `(1,5).west`, the walked `(1,6)` pocket
  exits into `(1,5).south`, `(2,6).west`, and `(1,7).north`, plus
  `(0,7)->RIGHT` into `(1,7).west`. The next noisy route from `(3,4)` then
  confirmed `(3,5).north`, `(4,4).west`, `(2,6).north`, `(3,5).west`,
  `(2,3).south`, `(4,4).north`, and `(5,14).north`, while preserving
  `(0,8)->RIGHT` as the first open east re-entry; after combat cleared, the
  route reached `(5,19)`. Entrance-to-entrance polish then confirmed
  `(1,23)->DOWN` blocked into `(1,24).north`; with that runtime edge active,
  the north-exit-to-south-stairs route detoured through row 23, descended at
  x=3, and reached `(0,29)`.
  Static tests cover the south-stairs route, reverse route to the door stand,
  opened-door return route, and latest return blockers. FCEUX must reload
  `main.lua` before live planning reflects these source edits; the current live
  runtime overlay already contained the equivalent blockers during validation.
- A live FCEUX hang after `O` path preview plus close-timed D-pad taps left
  command polling stopped with no fresh `dw_script_error.log` entry. The fix
  debounces `O`, `R`, `U`, and `Shift+O` object/path route hotkeys by suppressing
  `auto_step` direction-edge tracking for 8 frames before planning/speech.
  A post-reload repro showed the ROM still accepted controller input while the
  Lua loop stopped, with the final repeated log line in
  `auto_step cancel manual_tap early-twitch wait`. `auto_step.lua` now avoids
  reissuing neutral `joypad.set` frames in that physical-tap cancel branch and
  applies a short direction-edge dampening window after the cancel, so rapid
  retaps are not converted into another synthetic manual step immediately.
  Later repros spoke `Wait for movement to finish`, which proved blocked
  object hotkeys were hitting the guarded object-control path during active
  movement. That path now suppresses nearby direction edges for any object
  hotkey blocked by the movement-settle guard, including blocked `O`, `U`, and
  `J/K/L`, but does not use the teleport-style controller suppression that
  pauses `auto_step.update` during active movement. It also logs/flushed
  `OBJECT_HOTKEY_BLOCKED` breadcrumbs if this still recurs. `test_hotkeys.lua`
  and `test_auto_step.lua` cover the allowed hotkey debounce, blocked-`O`,
  blocked-`U`, and blocked-`J/K/L` debounce without teleport suppression,
  manual early-twitch cancel cleanup, and rapid-retap dampening. A later
  dialogue repro stopped the Lua loop after blocked `K` spoke `Wait for dialogue
  to finish`, with no new `dw_script_error.log` entry and a timed-out
  `launcher_probe`. `hotkeys.lua` now also treats dialogue / upper-dialogue
  blocked object controls as lightweight direction-edge debounce only, avoiding
  teleport-style neutral `joypad.set` suppression during dialogue. The new
  `test_hotkeys.lua` regression covers blocked `K` during active dialogue. A
  follow-up live state capture showed the command menu was fully clear
  (`raw_open=false`, `active_block=false`) while lower dialogue remained stuck
  on compact status residue (`PREV.dialogue="BillG2234"`). `text.lua` now
  treats generic short-name-plus-`G`/`E` numeric fragments such as `BillG2234`,
  `IvyE1298`, and `RexG42` as passive status noise, so that residue cannot keep
  object controls blocked after dialogue/menu cleanup. A later post-dialogue
  upper-window repro spoke `MBill GLV  15` just before
  `UPPER_DIALOGUE_STALE_CLEAR`; the passive status classifier now also catches
  generic status-letter/name fragments followed by uppercase status-label
  clusters and numeric residue, e.g. `MBill GLV  15` and `MIvy GLV  15`.
  A dialogue timing pass then found north-edge NPC lines reaching final visible
  length roughly 4 seconds before speech; the row-1 lower dialogue reader now
  filters low-row passive status/name crumbs before they can reset the stable
  text timer. A later selected-teleport repro in Garinham stopped command
  polling after object browsing / selected teleport plus TALK, again with no
  fresh `dw_script_error.log` entry. FCEUX selected-object teleport hotkeys now
  pass `suppress_input=false`, and the shared teleport input suppressor skips
  immediate neutral `joypad.set` on FCEUX while preserving BizHawk behavior.
  Post-reload validation reached Guard 2 at `(3,4)`, completed the teleport
  guard, survived command-menu TALK attempts, and answered fresh launcher
  probes afterward. The user then manually verified selected teleport to Guard
  2 without a crash; this is one of Brecconary's key trap guards, so keep this
  as the important end-to-end FCEUX confirmation. FCEUX needs a manual Lua
  reload before these timing / teleport-input fixes are live.

## Garin's Grave Result

- The Silver Harp route is stable both directions from the lower-stair side.
- The Cursed Belt route is solved: from B3 `Northwest Stairs Up`, the route to
  the west chest uses the top-edge false-boundary cells, left-edge strip, and
  chest-side false-wall cells; the return/escape route is also modeled.
- The player has opened the west chest and confirmed the Cursed Belt.
- The B1 entrance-to-down-stairs route and return route have been manually
  validated after the final blocker patches.
- The B2 northwest-side escape back to `Stairs Up` has been live-validated via
  the left-edge false-boundary strip and bottom/right corridor.
- The false reachable-object routes from the B3 northwest component are pruned;
  the expected reachable objects there are the opened chest and local
  `Northwest Stairs Up`.
- B3 lower-stair / Silver Harp side, B3 northeast and southeast pockets, and
  the B4 connector are closed enough for normal play.

## Final Tooling / Cleanup Notes

- New non-teleport verifier helpers were added after the Garinham door/route
  fallout: use `verify_walked_edge:DIR` or `verify_walked_edge:X,Y,DIR` to
  route to an origin without teleport, then run the normal raw `probe_edge`
  logic from the reached tile. Keep legacy `probe_edge_verify` as
  forensic/review-only when teleport artifacts are plausible. For doors, use
  `verify_door_stand:X,Y,DIR`, manually OPEN after `DOOR_VERIFY_READY`, then
  run `verify_door_after` to compare keys/opened-door RAM. Reload `main.lua`
  in FCEUX before live-testing these new source changes.
- `auto_walk_blocker` / `auto_walk_blocker:X,Y` now run normal local-map
  autowalk in first-blocker mode. They stop at the first confirmed blocked
  queued step, log `AUTO_WALK_BLOCKER_FOUND`, speak/report the failed edge, and
  print the matching `add_blocked_edge:X,Y,DIR` runtime-patch suggestion.
- Timing-suspect movement-start timeouts run the normal seam retry before
  being reported as patchable blockers, which keeps timing noise out of
  permanent map data.
- Movement-changing field actions now refuse while command menus, prompts,
  dialogue, active routes, or probe/survey/crawl flows can consume input.
- `sweep_walk` now writes `sweep_status.txt` while active and, on finish,
  `sweep_walk_MM_runNNN.json`, `sweep_walk_MM_runNNN_summary.txt`, and the
  existing `dw_crawl_MM.txt` review snippet. Its JSON includes explicit
  `unknowns`, `dynamic_blockers`, `transitions`, and `unsafe_aborts` buckets
  for single-edge probe outcomes. Reload `main.lua` in FCEUX before
  live-testing newly edited sweep code.
- Post-reload Garinham validation hammered the timing-suspect split with four
  normal-movement 120-edge `sweep_walk` runs from the central/lower-left
  component. All four hit `reason=max_edges` with zero passthrough exports,
  zero directional exports, and zero unsafe aborts; remaining observations
  stayed in timing-suspect unknown/unstable or informational door buckets.
- Tantegel and Swamp Cave follow-up runs gave `sweep_walk` broader coverage,
  including hostile-map interruptions. Random encounters now stop the active
  sweep with `reason=battle_interrupted` /
  `source_classification=battle_interrupted`; start a new sweep manually after
  combat returns to field control.
- Resume-from-JSON support is intentionally deferred. The current field design
  is simpler and safer: battle interruption is a terminal graceful exit, not a
  pause that waits through combat.
- The crawler no longer writes movement RAM during sweep step cleanup. Hostile
  Swamp Cave reruns after that change kept player stats clean across battle
  interruptions, so this should stay a hard rule unless fresh evidence proves
  otherwise.
- The long sweep break-in scratchpad was archived; the active scratchpad is
  concise again.
- A local CodeRabbit review of the cleaned uncommitted diff completed with
  zero findings.
- A CodeRabbit review found one test-harness cleanup issue in
  `test_map_reader.lua`; the B2 pathfinder test now restores module/env state
  through a finally-style helper even if an assertion fails.

## Durable References

- Current gameplay notes: `PLAYTESTING.md`
- Durable project lessons: `PROJECT_MEMORY.md`
- Garin's Grave map reference: `project_resources/maps/garins_grave/README.md`
- Archived full handoff:
  `handoff_archive/HANDOFF_2026-06-17_garins_grave_final_wrapup_full.md`
- Archived scratchpad:
  `handoff_archive/HANDOFF_2026-06-17_garins_grave_final_scratchpad.md`
- Sweep break-in archive:
  `handoff_archive/HANDOFF_2026-06-21_sweep_walk_break_in_scratchpad.md`

## Next Work

1. Reload `main.lua` in FCEUX before judging source-level changes from the
   latest Brecconary closeout, selected-teleport/input fixes, or Swamp Cave
   route planning. Brecconary itself is complete for the current alpha town
   pass; after reload, only spot-check the exit-tile reachable filter and Fairy
   Water route if needed.
2. Continue the Magic Key alpha-prep pass in the next early town, or pick the
   next practical playability/QoL issue or the next gameplay-exposed
   route failure instead of continuing broad Garin's Grave blocker hunting.
3. If revisiting Garinham's inn-to-grave-stairs return, ignore old verifier
   proof for `(19,10)` and use the current top-lane route evidence:
   `(13,0)->(14,0)->(15,0)->(15,1)->...->(19,0)`. Current notes are in
   `work_notes/current_investigation.md` and `PLAYTESTING.md`.
4. If future work touches live FCEUX after source edits, manually reload
   `main.lua` before judging live behavior.
5. If a new dungeon/floor becomes the active target, start with external map
   orientation, then use live movement evidence before permanent map edits.
6. For more `sweep_walk` validation, move to a new play space and treat the
   generated JSON as review-only until walked evidence supports a patch.
