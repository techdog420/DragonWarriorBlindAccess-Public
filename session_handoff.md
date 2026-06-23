# Session Handoff - Active Resume

Updated: 2026-06-23

## Current State

- Garin's Grave / Grave of Garinham route decoding is complete for current
  playtesting needs.
- The detailed final Garin's Grave wrap-up was archived to
  `handoff_archive/HANDOFF_2026-06-17_garins_grave_final_wrapup_full.md`.
- The detailed scratchpad evidence was archived to
  `handoff_archive/HANDOFF_2026-06-17_garins_grave_final_scratchpad.md`.
- Garinham grave-return stairs now have a verified escape to the inn by
  leaving town and re-entering from the world map, but no clean return route
  from the inn back to the grave stairs. The old `(19,10)` lower bridge was
  verifier/teleport fallout and is no longer modeled as a passthrough.
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
  door / Princess route and south-stairs route now include the walked
  directional blockers found by `auto_walk_blocker`, the live middle strip
  `(2,16)..(2,18)` is modeled as passthrough, and static tests cover the
  south-stairs route, reverse route to the door stand, and opened-door return
  route. FCEUX must reload `main.lua` before live planning reflects these
  source edits; the current live runtime overlay already contained the
  equivalent blockers during validation.
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
  manual early-twitch cancel cleanup, and rapid-retap dampening.

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
   or the hotkey / manual early-twitch fixes; the latest live script loop
   stopped after blocked `L` spoke `Wait for movement to finish` during an
   active auto-walk, with the breadcrumb confirming `key_object_next`.
   The stale command probe has been cleared. After reload, stress `O`, `U`,
   `J/K/L`, and movement timing, then resume escorting Gwaelin back to
   Tantegel Castle if stable.
2. Pick the next practical playability/QoL issue or the next gameplay-exposed
   route failure instead of continuing broad Garin's Grave blocker hunting.
3. If revisiting Garinham's inn-to-grave-stairs return, ignore old verifier
   proof for `(19,10)` and start from walked same-origin evidence. Current
   notes are in `work_notes/current_investigation.md` and `PLAYTESTING.md`.
4. If future work touches live FCEUX after source edits, manually reload
   `main.lua` before judging live behavior.
5. If a new dungeon/floor becomes the active target, start with external map
   orientation, then use live movement evidence before permanent map edits.
6. For more `sweep_walk` validation, move to a new play space and treat the
   generated JSON as review-only until walked evidence supports a patch.
