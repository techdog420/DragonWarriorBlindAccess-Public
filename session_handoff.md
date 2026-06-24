# Session Handoff - Active Resume

Updated: 2026-06-24

## Current State

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
  text timer. FCEUX needs a manual Lua reload before this timing fix is live.

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

1. Reload `main.lua` in FCEUX before judging Swamp Cave live route planning
   or the hotkey / manual early-twitch fixes. The latest hang repro stopped
   after blocked `K` spoke `Wait for dialogue to finish` while NPC dialogue was
   active, with the breadcrumb confirming `key_object_current`; after the crash
   fix, the script stayed alive but cached compact status residue as lower
   dialogue after the command menu cleared, then exposed an upper residue shape
   like `MBill GLV  15`. After reload, stress object readout/browse keys during
   active NPC dialogue and after the menu clears, then recheck `O`, `U`,
   `J/K/L`, and movement timing before resuming escorting Gwaelin back to
   Tantegel Castle.
2. Pick the next practical playability/QoL issue or the next gameplay-exposed
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
