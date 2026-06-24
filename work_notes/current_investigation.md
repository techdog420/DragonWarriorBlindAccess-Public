# Current Investigation Scratchpad

Updated: 2026-06-24

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
