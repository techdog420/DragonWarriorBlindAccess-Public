# Current Investigation Scratchpad

Updated: 2026-06-22

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
- Promotion target: promote the runtime blocker batch into
  `MAP_DIRECTIONAL_BLOCKS[0x15]` with focused regression assertions. Preserve
  the proven passable route to `(0,29)` and do not model untested neighboring
  faces.

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
