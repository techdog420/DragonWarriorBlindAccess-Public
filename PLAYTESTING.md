# Playtesting Notes

Updated: 2026-05-17

This file tracks the shift from map decoding toward actual blind-player gameplay.

## Latest Notes

- Emulator A/B note: keep BizHawk as the default launcher until a short
  same-save bakeoff is complete. FCEUX should pass if `input_status` starts
  clean or `./recover_fceux_input.sh` makes `left_alt=false`, no unrecoverable
  menu-focus state interrupts play, object browsing works, one route/autowalk
  action works, one menu/dialogue interaction works, and any manual ROM/Lua
  loading friction is acceptable for the fallback workflow. BizHawk should pass
  if the same loop has no recurring audio glitching or obvious lag; if lag
  appears, capture `reset_scan_stats` / `report_scan_stats` around the repro
  before tuning. If both pass, prefer FCEUX for player feel; if FCEUX still
  interrupts normal play or remains too awkward to launch reliably, keep BizHawk
  primary.

- Rimuldar is now the next guide target after exiting Swamp Cave to the south
  island. External orientation from Gamer Corner: Rimuldar entrance is
  `(29S,59E)`, which is local world coordinate `(102,72)` from the current
  Tantegel anchor; inn is 55 G; there are 2 locked doors; treasure is Wings;
  shops are Weapons/Armor and Magic Keys. Magic Keys cost 53 G in Rimuldar and
  this is the first key shop that does not itself require a key. Mike's RPG
  Center agrees on the key-shop price and lists the weapon/armor stock as
  Copper Sword, Hand Axe, Broad Sword, Half Plate, Full Plate, and Magic Armor.
  Gamer Corner recommends the west route around the craggy mountains from the
  Swamp Cave south side because it is safer, and warns that the Rimuldar area
  is dangerous for a level 8-9 hero; SLEEP is useful against the stronger
  monsters. `overworld_routes.lua` now has live-corrected guidance:
  `rimuldar` from `Swamp Cave South Entrance` `(104,49)` to `Rimuldar`
  `(102,72)`, plus `swamp_cave_south` for the return. The first guide-derived
  run worked well overall, but the live log corrected two bad turns: the
  craggy-notch segment must not retry blocked `(93,57)->UP`, and the town
  approach must not push east from `(97,72)` into the north-side wall. The
  route now drops through `(93,57)` on the west side and uses the manually
  proven east approach, entering Rimuldar from `(103,72)->LEFT`. First service
  proof: Rimuldar `Merchant 2` is the weapon/armor merchant at `(23,7)`, opened
  first from the stale south counter stand `(23,9)` facing north. Follow-up
  selected-teleport and TALK proof found the planner-safe public stand at
  `(24,7)` facing west, which fixes the inbound route from the town entrance.
  Live merchant rows list Copper Sword 180 G, Hand Axe 560 G, Broad Sword
  1500 G, Half Plate 1000 G, Full Plate 3000 G, and Magic Armor 7700 G. The
  old town exit object at `(15,14)` is invalid: teleporting there and walking
  around showed it is just an ordinary interior tile. Live `probe_edge:RIGHT`
  from `(29,13)` triggered
  `EVENT: map change -> 0x01 (World Map)` and landed at `(102,72)`, so Rimuldar
  now uses `(29,13)` facing east as its `Exit to World Map`. Follow-up user
  check confirmed the new exit object lines up correctly from the town side.
  Return-route follow-up found that the mountain notch is not reversible:
  `(92,57)->UP` is engine-blocked, and the old return route looped there. The
  cave return now uses the live-probed west-pocket detour through `(85,58)`,
  `(85,56)`, `(83,56)`, `(83,54)`, `(86,54)`, `(86,52)`, `(92,52)`,
  `(92,48)`, `(100,48)`, `(100,50)`, and `(104,50)` before stepping `UP` into
  the south cave entrance. A recovery variant catches recalculations from
  `(92,57)` and sends the player west instead of retrying the blocked notch.
  The next user pass from Swamp Cave South Entrance to Rimuldar succeeded.
  Polishing review adjusted two route-shape annoyances: the west-lake bend now
  steps right from `(89,72)` before going north, and the north-wall corner now
  goes up from `(97,71)` before going east, avoiding the repeatedly blocked
  `(97,71)->RIGHT` edge into `(98,71)`. Other blocked-looking entries in that
  run later moved and remain timing/noisy seam observations, not permanent map
  blockers. The first in-town walkabout to the weapon/armor merchant produced
  one real Rimuldar town seam worth modeling: `(28,14)->UP` into `(28,13)`
  blocked on both the queued route and seam retry, no NPC occupied either tile,
  and the valid exit route moved through `(29,14)->(29,13)` instead. The noisy
  `(27,15).west` seam self-disproved with a moved retry and stays open. Keep
  the weapon/armor route target on `(24,7)` facing west; `(23,9)` can open the
  shop in some stale/live contexts, but is not the planner-safe entrance-side
  target. Rimuldar `Merchant 3` is now live-confirmed as the inn keeper at
  `(16,18)`: autowalk from the east entrance routed cleanly to `(16,17)`,
  faced south, and TALK opened the 55 GOLD inn prompt. No additional town
  blockers were needed for either direction of that route. Rimuldar's Magic Key
  seller is now live-confirmed too: it is `Old Man 1` at `(4,7)`, not
  `Merchant 1`. TALK from `(4,6)` facing south opened the 53 GOLD Magic Key
  prompt, while probes around `Merchant 1` only produced the short `Welcome!`
  greeting. `objects.lua` now labels Old Man 1 as `Magic Key Merchant`, keeps
  `Merchant 1` out of Services, and routes the key seller through `(4,6)`
  facing south. The entrance-side route needs hidden north/water-edge
  connectors: live `(24,7)->UP` moved into `(24,6)` even though the ROM tile
  decodes as blocked, and the later key-route shakedown proved `(19,9)` is the
  real bridge around the false `(24,9)` north pocket. Further probing added
  the hidden row-8/column-13 connectors `(14,8)`, `(13,9)`, and `(13,8)`,
  the upper hidden turn `(16,8)`, plus the northwest strip `(1,8)` and
  `(1,7)`. A later live verifier found the missing west-strip connector:
  `(1,7)->RIGHT` into false-wall `(2,7)` moved 5/5, so `(2,7)` is now a
  passthrough. The same shakedown promoted confirmed directional-only blocks at
  `(24,12).south`, `(23,12).south`, `(25,11).east`, `(20,10).south/west`,
  `(21,11).west`, `(21,12).south/west`, `(24,8).south`, `(13,6).south`,
  `(13,8).east`, `(14,6).east/south`, `(13,7).east`, `(6,4).east`,
  `(6,5).east`, `(6,6).east`, `(2,6).west`, `(17,6).east`, and
  `(17,7).east`; the later weapon-route loop superseded the older
  `(25,12).south/east` uncertainty, but keep mixed or NPC-tainted seams such
  as `(23,10).south` and `(14,8).south` open. A live
  check after restart clarified that `(6,6)` itself is still standable:
  `(5,6)->RIGHT` moved manually and was mixed/passable under raw verifier, but
  `(7,6)->LEFT` into `(6,6)` confirmed 3/3 blocked. The guide was right that
  the key seller is trapped behind a small maze. Follow-up live/raw work added
  final maze passthroughs `(6,3)`, `(5,3)`, `(5,5)`, `(4,5)`, and `(3,5)`.
  It also sealed false exits `(3,6).north/east`, `(5,6).north/west`,
  `(6,4).north`, and `(6,5).north/west`. The latest loop investigation added real blockers at
  `(10,6).north`, `(12,6).south`, `(13,7).west`, `(13,9).south`,
  `(14,9).east/south`, `(15,9).south`, `(16,9).south`, and
  `(17,9).south`. The `(12,7)->RIGHT` and `(12,7)->UP` exits blocked 5/5,
  then reconfirmed 3/3 after a script restart. The next clean route pass added
  `(28,13).east`, `(17,9).east`, `(9,6).north/west`,
  `(12,6).north/west`, and `(13,6).north`, superseding the earlier
  mixed/unmodeled notes for `(9,6)` and `(17,9).east`. The return-side
  lower-lane loop then cleanly reached `(6,10)` and repeatedly proved two false
  exits before stale Alt resumed: `(6,10)->DOWN` into `(6,11)` and
  `(6,10)->RIGHT` into `(7,10)`, so `(6,11).north` and `(7,10).west` are now
  modeled. A follow-up manual pass discovered the one-way lower connector
  `(4,8)->DOWN` into `(4,9)`, and autowalk from `(4,10)` then proved two more
  bad-pocket exits: `(4,10)->DOWN` into `(4,11)` and `(5,10)->DOWN` into
  `(5,11)`, so `(4,11).north` and `(5,11).north` are now modeled. The next
  entrance-side route pass cleanly looped before stale Alt returned on
  `(9,10)->LEFT` into `(8,10)`, `(9,10)->DOWN` into `(9,11)`,
  `(9,13)->UP` into `(9,12)`, and `(9,13)->LEFT` into `(8,13)`, so those four
  directional approaches are now modeled too. The next both-direction pass
  sealed `(22,12).south`, `(9,12).east`, and `(8,14).east` on the inbound
  route, then showed the visible return pocket below `(3,11)` is a dead end:
  `(3,12).north` and `(4,11).west` are now modeled. Keep `(5,3).east` open for
  now. The route-back no-path was an NPC/model issue in the other direction:
  fresh attempts to leave `(4,6)` by walking south into Old Man 1 at `(4,7)`
  repeatedly blocked, while TALK from `(4,6)` facing south still opened the
  Magic Key shop. The seller now blocks movement again; the valid service stand
  remains `(4,6)`. The lower false-wall area around `(4,8)` and `(4,9)` is
  passthrough, but the seller's occupied `(4,7)` cell is not a return corridor.
  Follow-up testing showed `(5,7)` is only a one-way trap east of the seller: exits into
  `(5,6)`, `(4,7)`, `(6,7)`, and `(5,8)` all repeatedly blocked, so
  `(5,6).south`, `(4,7).east`, `(6,7).west`, and `(5,8).north` are modeled.
  The same route batch closed `(17,17).east`; the replacement entrance-side
  connector is the live-walked south turn `(13,15)` and `(13,16)`. The latest
  blocker batch added `(7,15).south`, `(6,16).east`, and `(7,10).north`. Manual
  movement also proved `(7,9)<->(8,9)`, so `(8,9)` is now the return connector
  around the blocked `(7,10)` drop. The next pass added `(6,16).south`,
  `(5,16).south`, `(3,13).south`, `(3,15).north`, `(8,10).north`,
  `(10,6).east`, and `(6,3).east`, while manual walking proved the false-wall
  passthroughs `(1,14)`, `(2,14)`, `(3,14)`, `(8,7)`, `(8,8)`, and `(14,5)`.
  The newest clean pre-Alt batch adds blockers at `(4,16).south`,
  `(3,16).south`, `(7,11).south`, `(4,8).south`, `(6,8).south`,
  `(6,4).west`, and `(6,3).west`, and adds the live-walked false-wall cells
  `(4,14)` and `(5,14)`. The suspicious `(6,8)` behavior is still hidden
  passability, not a full-cell blocker; only the south approach is modeled.
  The latest route/manual pass adds blockers `(2,15).south`, `(3,16).west`,
  `(4,12).south`, `(3,13).east`, and `(5,2).south`, plus false-wall cells
  `(3,4)` and `(4,3)`. A later check reopened `(4,6).north` because the
  Magic Key stand must be reachable from `(4,5)->DOWN`. `(4,3)->UP` is a live northwest
  world-map exit, now exposed as `Northwest Exit to World Map`; `(4,2).south`
  is blocked so pathfinding treats that edge as an exit transition instead of
  an in-town corridor.
  Follow-up route/manual evidence adds
  false-wall cells `(1,5)`, `(1,13)`, `(3,9)`, and `(15,5)`, plus blockers
  `(3,15).west`, `(4,12).east`, `(5,11).south`, `(14,6).north`,
  `(24,12).north`, and `(25,11).west`. The newest clean log promotes
  `(2,15).west`, `(6,11).south`, `(8,12).west`, `(4,4).south`, and
  `(4,3).south`. The latest route-to-merchant loop then added `(7,14).west`
  and `(6,15).north` after repeated clean blocks from `(6,14)` before stale
  Alt returned. The next weapon/key-route pass promoted `(25,12).east/south`,
  `(21,6).west`, `(21,7).west`, `(8,13).west`, and `(7,14).north`; the
  initial no-path in that batch was likely `Old Man 2` occupying `(6,13)`,
  not terrain. Later route-shaped evidence superseded the old noisy/open
  `(1,7)->RIGHT` probe: repeated movement into `(2,7)` from the west failed and
  reached `blocked=18 moved=0`, so `(2,7).west` is now modeled as blocked while
  `(2,7)` stays a passable hidden cell. With that west approach closed, the
  current model needed an alternate bridge into the key-counter lane. Key-to-east-exit
  remains no-path when NPC occupancy is modeled because the geometry-only route
  walks through the seller. Follow-up probing found `(5,9)` is a real lower-lane
  false-wall tile from `(4,9)->RIGHT` 5/5, but `(5,9)->UP` into `(5,8)` blocked
  from a forced origin. The upper-left candidate through `(1,4)/(0,5)` also
  failed: `(1,5)->UP` and `(1,5)->LEFT` each blocked 5/5. `(1,6)->LEFT` moved
  into `(0,6)` and then changed to the world map, so that is an exit-transition
  clue, not the Magic Key counter route. The later `(2,5)` lead was also
  stale/noisy: fresh route and direct verifier evidence block
  `(1,5)->RIGHT` into `(2,5)`, so `(2,5).west` is now modeled while the cell
  stays standable for other approaches. The `(3,7)` counter-lane lead is not
  solved after all: live route/seam retries proved `(3,9)->UP` into `(3,8)`
  blocked 9/9, so `(3,8).south` is now modeled. Follow-up frontier probes also
  close `(2,8).south`, `(5,8).south`, `(6,8).east`, `(6,7).east`, and
  `(6,2).east`. Local routing currently reports no entrance-to-key-stand path;
  the remaining one-cell lead is noisy `(1,8)->RIGHT` into `(2,8)`, which needs
  a clean post-reload verifier before exposing `(2,8)`.

- Swamp Cave interior first-pass orientation is now recorded. External guides
  agree it is a one-floor north/south tunnel to the Rimuldar island, with no
  treasure chests, one locked door, and Princess Gwaelin guarded by a Green
  Dragon as the side objective. The local grid is 6x30. The user tested the
  `x=0` corridor from both directions and found it open through `(0,25)`, where
  south access ends. Follow-up live evidence showed `(0,25)` is the west bend,
  not the exit stairs: STAIRS there says no stairs. The bottom-right alcove
  `(5,29)` is also not stairs. The ROM up-stair table points to the south-island
  stairs at `(0,29)`, reached from row 29. `map_reader.lua` now models
  `x=0,y=0..25` plus `(0,28)` and `(0,29)` as Swamp Cave passthrough cells, and
  leaves `(0,26)..(0,27)` closed. The south-exit return route also now has
  directional-only blockers for the lower-cave seams into `(1,24)`, `(1,27)`,
  `(2,28)`, and `(2,27)` that the route-shaped log showed as failed approaches.
  A follow-up auto-walk loop to `Stairs Up to South Island` was stopped after
  strongly reconfirming north-approach blocks into `(1,27)` from `(1,26)` and
  `(2,27)` from `(2,26)`, so those cells now block both the earlier upper
  approach and the looped lower approach where proven.
  Object browsing should no longer show both `Exit` and `Stairs Up` at `(0,0)`;
  it should show distinct `North Exit to World Map` and `Stairs Up to South
  Island` Travel objects. The south-exit stairs path
  from the row-29 exit area lands on the world map at `(104,49)`, exactly five
  tiles south of the known north entrance `(104,44)`, matching the guide offset
  from `(1S,61E)` to `(6S,61E)`. World-map Travel now exposes this as `Swamp
  Cave South Entrance` at `(104,49)`, while plain `Swamp Cave` remains the
  north entrance at `(104,44)`. Follow-up live route looping now has working
  auto-walk routes between `North Exit to World Map` and `Stairs Up to South
  Island` in both directions. Latest scary seam logs on the lower path are
  timing noise rather than permanent blocker evidence: several queued-route
  timeouts immediately moved on seam retry, and one pass was battle-interrupted.
  Runtime blocks and seam memory for map `0x15` were cleared afterward, with
  `RUNTIME_BLOCKS map=0x15 none` and `SEAM_SUMMARY map=0x15 total=0`. Next live
  priority was finding the real locked-door coordinate. Realm of Darkness'
  Swamp Cave map places Gwaelin and the Green Dragon behind a lower-right branch
  door, but the first local coordinate model was wrong: from `(5,23)`, OPEN
  reported "There is no door here." Follow-up live probes found the real cell:
  OPEN from both `(5,21)` and `(5,19)` reported "Thou hast not a key to use."
  Because the DW1 engine checks only the four adjacent tiles for OPEN, the
  shared adjacent coordinate is `(5,20)`. `Gwaelin Door` is now modeled at
  `(5,20)`, with the normal route stand at `(5,21)` facing north. The first
  south-stairs-to-door auto-walk then looped at `(3,23)`, repeatedly trying
  north into `(3,22)` and east into `(4,23)`. Direct probes confirmed both
  false edges blocked, so the map now models `(3,22).south` and `(4,23).west`
  as directional blockers. After reload, runtime blocks are clear and the live
  planner routes door stand `(5,21)` to the south stairs `(0,29)` in 13 steps,
  door stand to the north exit `(0,0)` in 26 steps, south stairs back to the
  door stand in 13 steps, and north exit back to the door stand in 26 steps.
  A final auto-walk retest was interrupted by a random Magician before the old
  loop site; Bill won the fight. Follow-up looping from `(3,26)` exposed one
  more real seam: `(3,24)->RIGHT` into `(4,24)` verified 3/3 blocked and is now
  modeled as `(4,24).west`. The nearby `(2,23)->UP` into `(2,22)` had mixed
  verify results, so it remains unmodeled. After reload, the post-battle route
  to `Gwaelin Door` now traces cleanly through `(4,26)->(5,26)->(5,25)`.
  A later auto-walk loop at `(5,23)` confirmed two more bad approaches:
  `(5,23)->UP` into `(5,22)` and `(5,23)->LEFT` into `(4,23)` both verified
  3/3 blocked. Disk now models `(5,22).south` and `(4,23).east` as additional
  directional seams. Static tests still find a route from the lower branch to
  the door stand; in the current live session, matching runtime edges were
  injected because the touch-plus-probe reload did not pick up the latest disk
  patch. The active detour from `(5,23)` to the door stand is
  `(5,24)->(4,24)->(4,23)->(4,22)->(4,21)->(5,21)`.
  The next loop confirmed `(4,25)->UP` into `(4,24)` as blocked 3/3, so disk
  now models `(4,24).south`. The adjacent `(5,24)->LEFT` edge had strong loop
  evidence but mixed verifier results, so it is runtime-only in the current
  session as `(4,24).east`, not permanent data. With both runtime guards
  active, the planner detours from `(5,24)` through
  `(5,25)->(4,25)->(3,25)->(3,24)->(3,23)->(2,23)->(2,22)`. A validation pass
  was interrupted by a Druin after 2 successful steps, so the remaining detour
  still needs a clean hostile-dungeon run.
  The next live loop/validation pass confirmed the lower-left detour has more
  one-way cave seams: `(2,23)->UP`, `(1,23)->UP`, `(0,21)->RIGHT`,
  `(0,20)->RIGHT`, `(0,22)->RIGHT`, and `(0,19)->RIGHT` all verified 3/3
  blocked and are now permanent directional blockers. With matching runtime
  guards, the live planner currently reaches for the row-18 re-entry:
  `(0,19)->(0,18)->(1,18)->(1,19)->(1,20)->(2,20)->(3,20)->(3,21)->(4,21)->(5,21)`.
  Validation of `(0,18)->RIGHT` was interrupted by a Magician, but later manual
  validation confirmed `(0,18)->RIGHT` and the rest of the x=0 corridor
  eastward through `(0,9)->RIGHT` are engine-blocked. `(0,8)` is the first
  eastward opening, so disk now models `(1,9).west` through `(1,18).west` and
  leaves `(1,8).west` open. With matching runtime guards active, the live
  planner from the current `(3,8)` position routes down the interior column:
  `(3,8)->(3,9)->(3,10)->(4,10)->...->(4,21)->(5,21)`.
  Green Dragon location is log-confirmed at map `0x15` position `(4,14)`.
  The first clean dragon start was frame `04027`: after reaching `(4,14)`,
  auto-walk attempted `DOWN` toward `(4,15)`, battle started at `(4,14)`, and
  frame `04095` reported "A Green Dragon draws near!" Later restarts/manual
  checks also produced Green Dragon snapshots at `(4,14)`. Treat the door route
  as a rescue-branch hazard, not a player-safe objective for the current level 9
  hero.

- Fresh overworld-route grinding notes: Tantegel to Kol now works rather well.
  A few points still needed manual navigation, but side-stepping a couple of
  tiles was enough to get back on course, so this is polish rather than a
  blocker. The reverse route from Kol back toward Tantegel also solved the
  major navigation problems and only needed minor manual adjustments. Kol to
  Northern Cave worked perfectly; the reverse had a few minor hiccups but
  worked well. A later Tantegel-to-Northern-Cave request exposed an unsupported
  far start: it tried to begin the Kol-side route near Rain Shrine and gave an
  unfeasible long segment. The route system now stages that request through
  Kol first, with speech explaining that Northern Cave starts from Kol. A
  follow-up route-guidance bug is also patched: with a route already active,
  selecting a different supported Travel destination and pressing route
  guidance should replace the active route instead of only rereading the old
  route.

- Swamp Cave overworld routing has been corrected after live probes showed the
  first cave spur was a dead pocket. The earlier north approach through
  `(100,35)`, `(104,39)`, and `(104,42)` can lure the route into x104/x107
  pockets where southward movement blocks before the entrance row. The current
  route backs out through the Kol south-road jog to `Kol bridge east lane`,
  descends to `Swamp Cave lower west approach` at `(94,40)`, drops onto the
  lower swamp lane at `(94,41)`, crosses the freshly rechecked row-41 lane to
  `(97,41)`, then uses `(97,42)`, `(102,42)`, `(102,43)`, and `(104,43)` before
  stepping down into the cave trigger at `(104,44)`. Live testing found the
  x92 entry was still blocked: `(92,40)->DOWN` and `(93,40)->DOWN` blocked,
  while `(94,40)->DOWN`, `(95,40)->DOWN`, `(96,40)->DOWN`, and
  `(97,40)->DOWN` moved. The row-41 connector from `(94,41)` eastward was
  rechecked after the emulator lockup and moved cleanly. After this patch, the
  user reached Swamp Cave live: the log recorded map change to `0x15` and
  `OVERWORLD_ROUTE: event=arrived route=swamp_cave_bridge waypoint=Swamp Cave`.

- Swamp Cave remains a Kol-side route for the next push toward
  Rimuldar. External orientation: Gamer Corner lists the Swamp Cave entrance
  as `(1S,61E)`, matching the existing `overworld_swamp_cave` landmark at
  `(104,44)`; Mike's RPG Center places the cave far south of Kol near the
  bridge; Gamer Corner's Rimuldar walkthrough confirms the cave is south of
  Kol and warns that the approach crosses poison swamp. The route is staged
  as a Kol-side destination rather than a full all-map route. From far starts,
  selecting `Swamp Cave` should start the Kol route first. From Kol it reuses
  the known `Kol forest west edge` / `West of Kol north lane` / `Kol south
  road` chain, then uses the lower bridge/swamp approach above. A bridge-side
  variant starts from `Kol southwest bridge` and joins at `Kol bridge east
  lane`. Return routing is now wired as `kol_swamp_cave`: from the cave exit it
  backs out through `(104,43)`, `(102,43)`, `(102,42)`, `(97,42)`, `(97,41)`,
  `(94,41)`, `(94,40)`, crosses west at row 40 before climbing to
  `Kol bridge east lane`, then follows the Kol south-road and forest return to
  `(104,10)`. It warns about the poison swamp on the return. The user tested
  both directions live after wiring the return; there are a few polish-level
  rough edges, but no major blocker remains before entering Swamp Cave.

- Dialogue polish from the Garinham/grinding session is working in live play.
  The STATUS command now reads the full status line from memory and no longer
  gets interrupted by the lower visual equipment rows. After combat, object
  navigation no longer remains stuck behind the stale "Wait for dialogue to
  finish" guard once rewards are cleared; a Ghost fight with a level-up logged
  `dialogue cache cleared: lower window empty`, then object navigation worked
  normally. Current wrap-up position check: world map `(21,10)`.

- Combat fast-action speech is now queued instead of interrupting. The
  previous fast path still detects complete attack/damage sentences quickly,
  but normal round messages no longer call interrupting speech, so closely
  spaced lines such as `Bill attacks`, enemy attacks, and HP loss should stop
  cutting one another off. Battle start/opening lines still interrupt so a new
  encounter is announced promptly.

- Overworld safety-route waypoints around Garinham east field and Erdrick's
  Cave road have been tightened from live grinding evidence. The old route
  aimed too coarsely from `Garinham ridge entry` to `Garinham east field`, and
  then from `(21,11)` straight south toward `Erdrick's Cave road`; logs showed
  those south moves timing out while the player successfully used an east-first
  jog through `(20,7)`, `(21,10)`, `(23,11)`, and `(23,13)`. The safety routes
  now use explicit `Garinham field east lane`, `Garinham field road bend`, and
  cave-road lane markers, with regression coverage proving auto-walk starts
  east rather than south from `(19,7)` and `(21,11)`. Live reload/retest is
  still needed because the command log was stale when this patch was made.

- Route guidance should no longer steal object focus. Starting or checking an
  active overworld route was explicitly selecting the current `route_*`
  waypoint object, so normal route progress could appear to change the focused
  destination automatically. Guidance now requests a deferred route-marker
  refresh without selecting the marker; the original Travel destination should
  remain focused while `auto_walk` still follows the active route.

- Kol is now available as an overworld guided route. Select the `Kol` Travel
  landmark or run `start_overworld_route:kol`; aliases also include `kol town`,
  `kol village`, `fairy flute`, `faerie flute`, and `faeries flute`. Live
  shakedown disproved the earlier direct east-pocket lane: raw probes from
  `(57,38)` blocked east into `(58,38)` and also blocked north/south from that
  tile. The route now follows the Galenholm/Garinham-style path: western bridge
  road, cave road, east across the northeast bridge, southeast to the bridge
  southwest of Kol, then north and east into Kol's forest. The northeast bridge
  route now uses a lower-lane jog through `(58,18)`, `(59,19)`, `(61,19)`, and
  `(61,18)` after logs showed row-18 pullbacks near `(60,18)`. Static tests
  expect the north-side approach from `(60,17)` to start `right`, not `down`.
  The final reload did pick up the source change: live movement from `(60,17)`
  still showed `down` into `(60,18)` as bad, while `right` to `(61,17)` and
  then `down` to `(61,18)` moved cleanly. A Red Slime battle interrupted before
  a clean queued `auto_walk` retest, so retry that command near the bridge.
  The later south-road issue was also patched from live movement: after
  `Kol southwest bridge`, the route should now go east through `(92,37)`,
  jog through `(92,36)`, `(93,36)`, `(93,35)`, and `(96,35)`, then treat
  `(96,32)` as `Kol south road` before continuing north to `(96,21)`. This
  avoids the stale `(90,30)` south-road pullback. After reload, the user reached
  Kol; the fresh current-state probe reports `map=0x07(Kol) x=19 y=23`.

- Kol service decoding is staged. Local reference images and a text
  transcription are now in `project_resources/maps/kol/`: Mike's map page,
  Realm/VGMaps town map, Gamer Corner, StrategyWiki, and related guide facts
  agree on the important first services. The inn is 20 G and appears in the
  northeast building; the item/tool shop sells Herb, Torch, Dragon's Scale, and
  Wings; the weapon/armor shop sells Copper Sword, Hand Axe, Half Plate, Full
  Plate, and Small Shield; the Fairy Flute is hidden four steps south of the
  bath. The bath/search clue is now decoded: Woman 2 at `(12,1)` talks about
  the bath, the local map image has the bath/water tile at `(9,2)`, and the
  modeled hidden search tile is `(9,6)` in the Treasure filter as `Disturbed
  Earth Near Bath`. Old Man 1 has a current pathable flute-clue route at
  `(2,13)`, and Old Man 4 has a current pathable better-weapons clue route at
  `(1,1)`.

- A Kol-side route to the harp/Staff of Rain shrine is staged as `Northern
  Cave`. Select the `Northern Cave` Travel object or run
  `start_overworld_route:rain shrine`; aliases also include `staff of rain`,
  `harp shrine`, `silver harp`, `cave west of kol`, and `shrine west of kol`.
  From world-map Kol `(104,10)`, the route should leave through `Kol forest
  west edge` `(96,13)`, then `West of Kol forest bend` `(92,10)`, then take a
  long south-and-west detour around the water/mountain gap before approaching
  `Northern Cave` `(81,1)`. Live testing exposed the old bad pocket: from
  `(91,5)`, the route was trying to pull west/north toward `(83,3)`, but that
  side is separated by water and mountains. After reload, a route recalculation
  from `(91,5)` should target `West of Kol forest bend` and head south toward
  the new detour, not west into the gap. The user later reached the cave live.
  The return to Kol now has a `kol_rain_shrine` variant that reverses the Rain
  Shrine approach from `(81,1)` back to Kol; selecting Kol or recalculating
  near the shrine should start west toward `Rain shrine entrance approach`
  instead of far south toward the old Kol chain.

- Rain Shrine / Northern Cave first interior pass: map `0x0D` is a 10x10
  shrine with the wise man / old man at `(4,4)` and the live bottom
  entrance/exit at `(4,9)`. Route evidence toward the old man repeatedly
  bounced between `(4,7)` and `(5,7)` while trying to move north into `(4,6)`
  and `(5,6)`. Both target cells decode as tile `14` and model-walkable, but
  live movement proved the south approaches blocked-only: `(4,6).south`
  reached 20 blocked / 0 moved and `(5,6).south` reached 18 blocked / 0 moved.
  The next live pass found the same pattern farther west: `(3,6).south`
  reached 6 blocked / 0 moved and `(2,6).south` reached 4 blocked / 0 moved,
  while `(3,7)` and `(2,7)` had horizontal moved evidence. The follow-up route
  exposed the west face of the same hidden wall cluster: `(2,3).west` reached
  36 blocked / 0 moved and `(2,4).west` reached 37 blocked / 0 moved, with
  route-context hits also on `(2,5).west` and `(2,6).west`. Movement along
  column `x=1` stayed open, including repeated `(1,3)<->(1,4)` movement. These
  are now modeled as directional-only blockers. After the script reloaded,
  `report_runtime_blocks` was empty, confirming the permanent map patch is the
  active source of truth; `debug_pathfind_adjacent:4,4` from current `(4,1)`
  initially planned `2 south`, landing at `(4,3)` facing south, but live
  auto-walk proved that top approach wrong: `(4,2).north` reached 4 blocked /
  0 moved and the reroute also found `(3,2).north` at 3 blocked / 0 moved. The
  successful manual route went east along row 1, descended on the far east
  side, then came back west along row 4; those moved seams stay open. The
  current model treats `(3,2).north`, `(4,2).north`, `(5,2).north`, and
  `(6,2).north` as directional-only top-wall blocks. The return route toward
  the exit then exposed a mid-wall loop around `(6,5)`: raw
  `probe_edge_verify` confirmed `(5,5).east`, `(6,6).north`, and
  `(5,5).north` as blocked 5/5 each. After those were injected live, the next
  reroute also confirmed `(7,5).west` and `(7,5).north` as blocked 5/5 each.
  The next entrance-to-old-man route from `(4,9)` then confirmed
  `(6,6).south` and `(7,6).south` as blocked 5/5 each. These are all
  directional-only; the earlier `(6,4).west`, `(6,4).south`, `(6,5).north`,
  `(6,7).east/west`, `(7,4).west/east`, and `(7,7).west` moved seams stay
  open. Final noisy-cleanup verifiers promoted `(7,6).east`, `(5,3).east`,
  `(7,5).east`, `(7,9).north`, and `(6,9).north` after each confirmed blocked
  5/5. `(5,3).south` was checked but mixed 3 moved / 2 blocked, so it stays
  open. `(8,9).north` stays open because its raw verifier hit a map-change
  case instead of a stable block. Follow-up live testing reported both routes
  to and from the old man finishing smoothly. The return route still had one
  recovered reroute, which is polish-level rather than a blocker. The chest is
  progression-gated until the old man receives what he is waiting for.

- The reverse route from Kol back to Tantegel now has its own connected
  variant. Before this patch, selecting the `Tantegel Castle` Travel landmark
  from near Kol could bind to the old Garinham/cave-road safety route and
  produce a huge direct west segment toward the cave road. Route starts now
  choose the closest matching castle variant from the current world-map
  position. From Kol, the castle route should first target `Kol forest west
  edge` `(96,13)`, then retrace the known Kol south-road and northeast-bridge
  waypoints before reconnecting at `Erdrick's Cave road` `(28,13)`.

- First Kol service-survey patch: the town exit is now the live south entry
  tile `(19,23)`, not the stale `(15,14)`. The decoder saw `(19,23)` and
  adjacent `(20,23)` as type-0 walls, but live movement proved them as
  passable entry/exit strip cells. A later pathability-filter repro from live
  `(18,23)` showed every object as unreachable until that west strip tile was
  also marked as a passthrough. The stopped parked survey also found a real
  loop near `Person 1`: from `(20,18)`, north into `(20,17)` blocked
  repeatedly and east into `(21,18)` blocked repeatedly. These are modeled as
  directional blocks only, preserving nearby passable seams. Reload Lua before
  rerunning the Kol survey; the automatic touch/probe did not appear to reload
  the active FCEUX script.

- Kol west-side NPC browsing is opening up after the service pass. The route to
  `Old Man 1` at object `(2,13)` looped between `(8,11)` and `(8,12)` while
  trying to enter `(7,11)` and `(7,12)` from the east. Both are now modeled as
  narrow directional blockers; the vertical connector between `(8,11)` and
  `(8,12)` stays open because it moved repeatedly.

- Kol Merchant 1 autowalk keeps exposing narrow service-route wall bands, and
  the current model has been tightened from two live runs. The first run proved
  `(10,18).east` and `(10,19).east`. After a clean reload, the route advanced
  deeper, then proved `(11,20).north`, `(12,19).west`, `(16,21).east`,
  `(16,20).east`, `(16,19).east`, `(10,16).east`, `(10,16).north`,
  `(9,16).north`, `(8,16).north`, and `(7,15).east`. The final loop at
  `(8,15)` reached 45+ blocked observations on the last two seams before a
  small right tap broke the route and moved the hero to `(9,15)`. Reload Lua
  before retesting Merchant 1; the touch/probe path was consumed but did not
  refresh the log header. The next manual-reload retest confirmed the
  `stop_auto_walk` command works and exposed the next south-entry band toward
  adjacent goal `(11,21)`: `(12,19).north` and `(13,19).north` are the strong
  blockers, with lower-count directional evidence at `(15,19).north`,
  `(14,19).north`, and `(16,19).north`. Merchant 4 path testing later
  disproved the stale `(16,22).east` candidate, so the
  `(16,22)<->(17,22)` seam should stay open both ways.
  The follow-up touch/probe reload succeeded with a fresh `Started:
  2026-05-15 13:29:38` log header and position `(12,18)`, so this blocker
  batch is live. A read-only path preview from `(12,18)` to the current
  Merchant 1 target at `(11,21)` now returns no path even with NPCs skipped,
  so this likely needs service/interaction-tile decoding rather than another
  blind autowalk retry to that live target. The user then selected/teleported
  to `npc_7` / `Merchant 1`, and TALK proved he is a dialogue-only
  southern-island/Rimuldar hint NPC. He now stays in NPC browsing but is
  excluded from Services. `report_door_state` at position `(12,21)` showed
  `keys=0` and no opened-door RAM slots, so do not claim a confirmed door
  coordinate for him yet.

- Kol Merchant 2 is the Inn. Selected teleport placed the hero at `(19,2)`
  facing south toward Merchant 2 at `(19,4)`, and TALK opened the 20 GOLD inn
  prompt. The route back from that Inn stand toward the town entrance looped
  between `(21,2)` and `(22,2)`, repeatedly trying to go south into row 3.
  `map_reader.lua` now blocks only the proven north approaches into `(21,3)`
  and `(22,3)`; row-2 movement stays open. After reload, the next loop advanced
  to the east wall and repeatedly tried to enter `(23,1)` and `(23,2)` from the
  west. Those west approaches are now blocked directionally too. The next pass
  drifted one tile west, recovered, then found `(10,4).north` and
  `(11,3).west`; `(10,3).north` moved on retry and stays open. After another
  reload, Inn-to-exit completed. The reverse route from town entrance back to
  Inn then got close and looped between `(21,4)` and `(22,4)`, repeatedly
  trying to enter `(21,3)` and `(22,3)` from the south. Those south approaches
  are now blocked directionally too; the side seams on row 4 moved repeatedly
  and stay open. The next entrance-to-Inn retest looped across row 4 and proved
  `(23,3).south` plus `(20,4).east`, both `blocked=36 moved=0`. Those are now
  directional blockers; row-4 movement through `(21,4)`, `(22,4)`, and
  `(23,4)` stays open. The next retest routed farther west and looped around
  `(11,5)`, `(12,5)`, and `(12,4)`, proving `(11,4).south` and `(11,4).east`.
  Those are now directional blockers; nearby connector seams moved repeatedly
  and low-count row-5 hits remain diagnostic. A later working round trip still
  rerouted noisily. Cleanup now also models `(10,4).south` and `(9,2).south`
  from the success log, plus repeated low-count reroute seams `(11,3).north`,
  `(19,17).south`, and `(18,17).south`. Noisy/moved seams such as
  `(10,3).west` and `(18,18).east` stay open. Retest entrance-to-Inn after Lua
  reload.

- Kol Merchant 3 is live-confirmed as the weapon/armor shop. Selected teleport
  to `npc_13` / `Merchant 3` held the target at `(22,12)`, landed at `(20,12)`,
  and faced east. TALK opened the buy list, and the merchant reader spoke the
  live inventory: Copper Sword 180 G, Hand Axe 560 G, Half Plate 1000 G, Full
  Plate 3000 G, and Small Shield 90 G. `objects.lua` now labels him
  `Weapons Merchant` and routes through `(20,12)` facing east.

- Kol Merchant 4 is live-confirmed as the item/tool shop. Selected teleport to
  `npc_15` / `Merchant 4` held the target at `(14,21)`, landed at `(12,21)`,
  and faced east. TALK opened the buy list, and the merchant reader spoke Herb
  24 G, Torch 8 G, Dragon's Scale 20 G, and Wings 70 G. `objects.lua` now
  labels him `Tool Merchant` and routes through `(12,21)` facing east.

- FCEUX stale-Alt remains a polishing issue, separate from dialogue state.
  Logs show `keys=LeftAlt`, `joy1=-`, and an empty external bridge while idle;
  movement or a real key clears it temporarily, then idle can re-trigger the
  warning. Treat this as an input-bridge/focus quirk, not a route or dialogue
  blocker.

- Overworld landmarks are now hooked into the same-map teleport system in the
  worktree. On the world map, selected Travel landmarks can use exact
  selected-object teleport, and debug builds also accept
  `teleport_landmark:NAME` / `teleport_overworld:NAME` for named destinations
  such as `Garinham`, `Brecconary`, or `Tantegel Castle`. The command refuses
  off-map use and uses the normal teleport guards. Live validation after the
  user's Garinham error: named teleport to `Garinham` landed on world-map
  `(1,2)`, and selected-object `teleport_selected` on the `Garinham` Travel
  object logged `landing_reason=overworld_travel` / `ok=true`.

- Selected-object teleport is safer for talking to hard-to-reach NPCs. The
  live Garinham repro landed beside `Woman 2`, but the NPC wandered before
  TALK, so the old one-frame face tap still produced `There is no one there.`
  Teleport now briefly pins the selected NPC's live target tile, faces the
  target for 4 frames, and skips heavy text/menu scans for 45 frames after the
  RAM jump. The selected-NPC hold now has its own shorter 600-frame window,
  uses diff-only RAM writes, and releases as soon as TALK dialogue opens or
  misses. Validation used `teleport_selected` on Garinham `Woman 2`, then TALK
  reached `Welcome to Garinham. May thy stay be a peaceful one.` Follow-up
  profiling showed the target hold itself is cheap; the remaining lag was
  mainly steady text/menu scanning, so idle scanner cadence was throttled while
  preserving faster checks during input/menu/dialogue. Final player state after
  cleanup: `map=0x09(Garinham) x=15 y=14`, menu closed.

- Garinham public-service pass is done for now. Public routing is good enough
  for normal play to continue: Tool Merchant, Inn, Weapons Merchant, town
  exit/entrance, and the public east locked door are modeled. The town-side
  exit object no longer targets the `(15,14)` corridor; it now uses the west
  entry boundary `(0,14)` with interaction stand `(1,14)` facing west. The
  overworld Garinham landmark also moved west from `(2,2)` to `(1,2)`, leaving
  `(2,2)` as the approach corridor that points `1 west` to town. Circle back
  after Magic Keys for the internal grey-building door, locked chests, hidden
  grave/back-building path, and any remaining hidden/dialogue-only NPCs.

- Garinham has been reached in live play. Current confirmed entry state:
  `map=0x09(Garinham) x=0 y=14`. The guide/image pass is staged at
  `project_resources/maps/garinham/`: local image
  `realmofdarkness_garinham.png`, with a text transcription in `README.md`.
  Early public-service priorities are the exit, inn, item shop, and
  weapon/armor shop. Guide data says the inn costs 25 G; the item shop sells
  Herb, Torch, and Dragon's Scale; the weapon/armor shop sells Club, Copper
  Sword, Hand Axe / Iron Axe, Leather Armor, Chain Mail, Half Plate, and Large
  Shield / Iron Shield. The large grey/north building is Magic-Key/later
  content. Its visible chests are 10-17 G, Torch, and Herb; Garin's Grave
  entrance is hidden through the building's dark back-wall path. The internal
  locked-door guards are not progression-critical according to StrategyWiki.
  First service pass: Garinham `Merchant 2` is live-confirmed as the item/tool
  shop via the Herb, Torch, and Dragon's Scale menu, and is now labeled `Tool
  Merchant` in Services. The attempted autowalk back from that shop stalled at
  `(3,11)`, repeatedly testing `(3,12)` and `(4,11)`. A reload stopped the loop
  cleanly; current live checks show no runtime blocks and no active path. The
  user manually checked `(3,11)`: north and west are open, while south and east
  are engine-blocked. `map_reader.lua` now closes `(3,12).north` and
  `(4,11).west` directionally. Post-reload `inspect_move` confirmed down/right
  are now modeled blocked and up/left remain passable. Retry the return route
  from the Tool Merchant next. The next exit autowalk no longer hit those two
  exact edges, but wandered around the same building pocket. Raw verifiers now
  confirm three more blocked seams from that loop: `(2,12)->RIGHT` into
  `(3,12)`, `(3,10)->RIGHT` into `(4,10)`, and `(3,10)->UP` into `(3,9)` each
  blocked 5/5 with `classification=confirmed_blocked`. Those are now modeled
  as `(3,12).west`, `(4,10).west`, and `(3,9).south`. A fresh debug path from
  `(3,10)` to the exit now starts west/north instead of cycling through the
  blocked east entries. The follow-up route then found a second loop from
  `(2,10)`: `(3,10)->LEFT` was noisy but passable after seam retry, while
  `(2,10)->UP` into `(2,9)` and `(2,10)->LEFT` into `(1,10)` both verified
  blocked 5/5. These are now modeled as `(2,9).south` and `(1,10).east`.
  Another live loop confirmed the user's note that `(2,10)<->(3,10)` remains
  passable despite the bump sound, then verified `(2,11)->LEFT` and
  `(2,12)->LEFT` blocked 5/5; these are now `(1,11).east` and
  `(1,12).east`. The planner's resulting no-path state exposed a decoder gap:
  `(2,13)` is type-2/non-walkable in the static grid, but
  `probe_edge_verify:2,12,DOWN,5` moved into it 5/5. It is now a Garinham
  passthrough cell, and the live planner from `(2,13)` reaches the exit target
  with `1 south, 13 east`.
  The reverse trip from entrance back to the Tool Merchant then bounced near
  the x=7 lane. Clean verifiers promoted `(6,10).east`, `(6,11).east`, and
  `(6,12).east` after `(7,10)->LEFT`, `(7,11)->LEFT`, and `(7,12)->LEFT` each
  blocked 5/5. After reload, the entrance/exit tile `(15,14)` plans to
  Merchant 2's stand with `1 north, 9 west, 3 north, 2 west`, facing west from
  `(4,10)`. The replacement route's critical seams through `(6,13)`,
  `(6,12)`, `(6,11)`, `(6,10)`, `(5,10)`, and `(4,10)` all moved 5/5 in raw
  verification.
  Drift follow-up showed the remaining reroutes on both successful Tool
  Merchant routes were execution overshoot rather than new map geometry. The
  exit route drifted one extra tile during turn settle at `(10,10)->(11,10)`,
  `(12,11)->(12,12)`, and `(13,13)->(13,14)`; the entrance-to-tool route did
  the same at `(7,13)->(6,13)`. Suspect seams were timing-noisy but passable
  after brute-force retry, so no new Garinham blockers were promoted from that
  evidence. `auto_step.lua` now releases queued early-twitch movement before a
  route turn while keeping straightaway early-twitch holding. User retest says
  both Tool Merchant routes are usable now, each with one remaining drift
  reroute; defer that drift to polishing unless it begins causing route
  failures.
  Next service pass: Garinham `Merchant 4` is live-confirmed as the
  weapon/armor shop. Selection landed at public stand `(10,16)`, facing south
  toward target `(10,18)`, and TALK opened the shop menu: Club 60 G, Copper
  Sword 180 G, Hand Axe 560 G, Leather Armor 70 G, Chain Mail 300 G, Half
  Plate 1000 G, and Large Shield 800 G. `objects.lua` now labels him
  `Weapons Merchant` and uses `(10,16)` facing south as the interaction stand.
  Return-route noise from the Weapons Merchant stand exposed two more
  Garinham engine blockers: `(10,16)->RIGHT` into `(11,16)` and
  `(13,14)->RIGHT` into `(14,14)`. Both verified blocked 5/5 with raw holds and
  are now modeled as `(11,16).west` and `(14,14).west`. After reload, the
  planner chose `1 north, 4 east, 1 north, 1 east` from `(10,16)` to the exit,
  and `validate_path` walked all 7 steps with 0 mismatches.
  The return-to-merchant direction then exposed the other side of the same
  counter throat. Raw verifiers blocked 5/5 on `(12,15)->LEFT`,
  `(12,16)->LEFT`, `(12,15)->DOWN`, `(15,14)->LEFT`, `(15,16)->LEFT`,
  `(15,15)->LEFT`, and `(14,13)->DOWN`, now modeled as directional blockers.
  The mixed `(15,13)->LEFT` seam stays open because validation crossed it on
  retry. The current validated entrance-to-Weapons-Merchant route from
  `(15,14)` is `1 north, 3 west, 1 south, 2 west, 2 south`, and
  `validate_path` walked all 9 steps with 0 mismatches.
  Follow-up on the viable round trip found no drift-reroute log entries, but
  raw verifiers confirmed two remaining seam bumps as real blockers:
  `(10,15)->RIGHT` into `(11,15)` and `(13,15)->RIGHT` into `(14,15)` both
  blocked 5/5, now modeled as `(11,15).west` and `(14,15).west`. A suspicious
  `(15,17)->LEFT` bump was only timing noise; the raw verifier moved into
  `(14,17)` 5/5, so keep that seam open.
  The inn is now confirmed too: Garinham `Merchant 3` at `(17,15)` opens
  `Welcome to the traveler's Inn. Room and board is 25 GOLD per night...` from
  public stand `(15,15)` facing east. `objects.lua` now labels him `Inn` and
  keeps him in Services.
  The first Garinham locked door is now exposed too. Guide data points to an
  east-end town door, and a live no-key probe from `(19,17)->UP` blocked into
  `(19,16)`. `map_reader.lua` now models `(19,16)` as a door that can open from
  opened-door RAM, and `objects.lua` exposes it as `East Door`. Post-reload
  `inspect_move:19,17,UP` reports `reason=door_closed` with no runtime blocks.
  Leave the guide-mentioned internal grey-building door for the Magic Key
  revisit, since its exact coordinate still needs live confirmation from
  inside.
  Manual movement may share the same timing root: the user reported some
  ordinary taps do not move while others overshoot. The manual wall-bump fixes
  were probably too eager to release physical tap-to-step input on open floor,
  so released `manual_tap` now gets a short extra hold after an early movement
  twitch (`auto_step_manual_early_hold_frames=8`) before it releases and, if no
  tile move follows, silently cancels as before. User retest says manual
  movement is working better; try it on the overworld next, but Garinham's Tool
  Merchant is no longer an active blocker.

- Tantegel Castle Sage service: the user manually confirmed Old Man 2 restores
  MP, and external guide/map notes agree that the castle wise man restores MP.
  `objects.lua` now labels the NPC at `(20,26)` as `Sage` and includes him in
  Services. The usable interaction stand is not adjacent to the NPC: live TALK
  proof from `(18,26)` facing east opened Sage dialogue, and post-reload
  Services output now says `Sage: 2 east, counter here ... obj 20,26 interact
  18,26`. From `(12,29)`, the locator describes that stand as `counter 3
  north, 6 east`. The route is NPC-sensitive but now good enough for play: after
  the `(20,20)` correction below, the user confirmed a successful
  entrance-to-Sage route, and the return route can also open when live NPCs are
  not in the way. The stale full-block override was corrected after raw probes
  showed
  `(20,20)` is standable and open north/south/west, while `(20,20)->RIGHT`
  into `(21,20)` is blocked one-way. After reload, `(20,20)` inspects as
  passable, `(20,20)->RIGHT` inspects as directionally blocked, and
  `(21,20)->LEFT` remains passable. From the Sage stand,
  `debug_pathfind_adjacent:11,29` now finds a 37-step route to the
  exit-adjacent tile; skip-NPC path debug finds a 29-step route.
  Raw verifier proof still supports keeping the south-gate blockers
  `(16,29)->UP`,
  `(17,29)->UP`, `(18,29)->UP`, `(19,29)->UP`, and `(19,29)->RIGHT` closed. Do
  not reopen those confirmed south-gate seams just to force shorter routes.
  Guide cross-checks point away from the Sage being locked-door-gated: the
  locked-door notes are for the Magic Key shop and Stones of Sunlight route,
  while the MP-restoring old man is described as a main-floor service. The user
  also found `(18,27)->DOWN` blocked; `probe_edge_verify:18,27,DOWN,5`
  confirmed 5/5 blocked into `(18,28)`, so that north approach is now modeled
  as a directional blocker. This was part of the Sage-route cleanup rather than
  a locked-door-gating issue.
  Additional verifier checks found `(17,27)->DOWN` blocked 5/5 and it is now
  modeled as `(17,28).north`; `(17,27)->LEFT` blocked 5/5 but was already
  covered by `(16,27)` being a full blocked-cell override. A first
  `(18,27)->RIGHT` verifier had looked passable, but the later clean-state
  recheck matched the user's manual observation: two fresh verifier runs stayed
  blocked 5/5, so `(19,27).west` is now modeled too. After reload,
  `inspect_move:17,27,DOWN` and `inspect_move:18,27,RIGHT` both report their
  new directional blockers as effective.
  The same follow-up confirmed `(18,26)->RIGHT` into `(19,26)` blocked 5/5 twice
  with clean menu/input state, so `(19,26).west` is now modeled; after reload,
  `inspect_move:18,26,RIGHT` reports the blocker as effective.
  The next reroute exposed `(18,25)->RIGHT` into `(19,25)`, which also verified
  blocked 5/5 twice. `(19,25).west` is now modeled; after reload,
  `inspect_move:18,25,RIGHT` reports the blocker as effective. The later
  `(20,20)` correction supersedes the old Sage-stand-to-exit no-path result,
  and the user later confirmed the entrance-side Sage route can succeed when
  live NPC traffic cooperates.
  Castle entrance to `Stairs Up to Tantegel Castle Throne Room` was noisy
  because the planner tried false north entries from `(12,29)` and `(13,29)`;
  both verified blocked 5/5 and are now modeled as `(12,28).south` and
  `(13,28).south`. Current evidence does not show a working public route from
  the south entrance side to that return stair; after the false entries are
  closed, post-reload path debug from `(12,29)` reports clean `No path found`
  instead of a noisy autowalk failure.
  Merchant cleanup: the user confirmed Tantegel Castle Merchants 1 and 2 only
  offer dialogue, so they remain browsable as NPCs but are removed from
  Services. Merchant 3 sells Magic Keys and is now labeled `Magic Key Merchant`
  in Services. Follow-up research confirmed Merchant 3 cannot be accessed yet,
  likely because the route is locked-door gated; wait until keys/doors are in
  play before treating a failed route to him as missing map data. With the Sage
  and public services handled, Tantegel Castle is clean enough to leave for now
  and the next playtest focus is the next town.

- Strategic map-completion pivot after Merchant 4: stop treating perfect map
  truth as the immediate bar. For the next maps, first establish reliable
  routes to merchants, inns, exits, stairs, locked doors, chests, and other
  essential services. Defer unreachable dialogue-only NPCs to the polishing
  phase unless they offer a progression clue or required gameplay hint.

- Brecconary is service-complete for now. The user manually tested all
  essential services, and routes both to and from the town entrance pass in
  normal play. The remaining unreachable NPCs were manually checked; a couple
  give clues, but none are required for progression. Keep them for the
  polishing phase unless later game logic proves one of those clues is required.
  Next playtest focus is the first castle / Tantegel area, specifically the
  guide-mentioned sage who may restore MP.

- Brecconary service cleanup: Merchant 1 is dialogue-only and has been removed
  from the Services filter while staying available as a normal NPC. The current
  confirmed services are `Weapons Merchant`, `Inn`, `Tool Merchant`,
  `Fairy Water Merchant`, and `Curse Remover`. Woman 1 is the Fairy Water
  merchant behind the northeast door. Old Man 2 claims to remove curses; accept
  that service label for now, with a later polish check when the hero is
  actually cursed. The Old Man 2 route is now solved: manual movement and live
  logs proved `(24,13)->UP` into `(24,12)`, `(24,12)->UP` into `(24,11)`, and
  `(24,11)->DOWN` back into `(24,12)`. `map_reader.lua` promotes `(24,12)` as a
  passthrough and leaves the `(24,11)<->(24,12)` seam open. After reload,
  `debug_pathfind_adjacent:24,10` from the entrance `(1,15)` routes to
  `(24,11)` in 29 steps and faces north; `debug_pathfind_to:1,15` from
  `(24,11)` also returns in 29 steps. Runtime blockers stayed empty. This
  solves Curse Remover. Tool Merchant route testing then found two stale route
  edges: `(16,25)->RIGHT` into `(17,25)` blocks, and `(22,26)->LEFT` into
  `(21,26)` blocks. The replacement bridge is the long row-22 corridor:
  `(17,22)` is now confirmed passable from both east and west, so the entrance
  routes to the Tool Merchant public stand again, and the stand routes back to
  the entrance after live NPC clutter clears.

- Autowalk no-path speech should stay cautious around stationary NPCs. Current
  Brecconary logs show `NO_PATH_STATIONARY_NPC` for the exit route, followed a
  few seconds later by a tryable route after NPC state changed. The
  player-facing hint now says the route may be blocked by a stationary or
  out-of-date NPC position and suggests retrying, instead of claiming waiting
  cannot clear the route.

- Object browsing now avoids full NPC-list rebuilds on plain browse/readout
  keys under BizHawk. The first moving-NPC fix made Person 1 and other moving
  NPCs track again, but calling `objects.update_npcs()` on `J`/`K`/`L` brought
  back a 1.5-2 second emulator/audio freeze between object-browser presses.
  `objects.describe_current()` now reads only the selected NPC slot live for
  spoken direction/distance, while `J`/`K`/`L`, filter readouts, and
  command-file object browsing skip the full rebuild. Route/planning actions
  (`R`, `O`, `U`, `pathfind`, `auto_walk`) and explicit pathability refreshes
  still refresh the full NPC list before planning. Live command-file browse
  proof after reload produced object descriptions with no `CMD_TIMING` warning;
  the user's focused physical `J`/`L` retest confirmed this brought the delay
  down to a fraction of a second between hops. Treat this as a successful first
  tuning pass unless the remaining small pause becomes a normal-play problem.

- Player-facing selected-object teleport should no longer refuse common
  non-NPC targets just because the object tile itself is not standable. The
  latest log showed `Shift+Enter` on Brecconary's `Exit to World Map` trying to
  land on `(0,15)` and refusing as not walkable. Exact selected-object teleport
  now asks the object resolver for all object types: walkable objects such as
  stairs still land exactly, while blocked exits/doors/chests land on a nearby
  usable cell and face back toward the object.

- Brecconary Merchant 4 public access update: the user found a small walkable
  pocket at `(22,25)`/`(23,25)`. Fresh live evidence at `map=0x08` confirmed
  the player at `(23,25)` with no runtime blockers, `(22,25)<->(23,25)` as
  passable, `(23,25)->RIGHT` into `(24,25)` as directionally blocked, and TALK
  from `(23,25)` facing east opening the tool shop (`MERCHANT_ACTION:
  Merchant. Buy.`). This supersedes the earlier conclusion that Merchant 4 was
  isolated: route the service to `(23,25)` facing east, but keep the movement
  seam into `(24,25)` blocked.

- Brecconary Merchant 4 public route recovery: the older `(17,25)` bridge is
  no longer trusted as an entrance route. Fresh live route testing repeatedly
  blocked `(16,25)->RIGHT` into `(17,25)`, and a raw
  `probe_edge_verify:RIGHT,3` from `(16,25)` confirmed `moved=0 blocked=3`
  with `reason=raw_hold_timeout`. `map_reader.lua` still treats `(17,25)` as a
  standable passthrough for other approach checks, but now blocks its west
  approach. The replacement bridge is `(17,22)`: manual movement and raw
  verifier proof crossed `(16,22)->RIGHT` and `(18,22)->LEFT` into `(17,22)`
  3/3 times from each side. After reload, `debug_pathfind_to:23,25` from
  `(1,15)` reports a 38-step path to the Tool Merchant public stand.

- Brecconary Merchant 4 return route regression: the older `(21,26)`
  passthrough evidence is now stale for the east approach. Current live route
  execution from `(22,26)->LEFT`, seam retries, and manual taps all blocked
  into `(21,26)`, ending with `blocked=13 moved=0` for `cell=(21,26)
  approach=east`. `map_reader.lua` still treats `(21,26)` as standable for
  other approach checks, but now blocks `(21,26).east`. Live reload proof:
  `inspect_move:22,26,LEFT` reports `directional_blocked=true` and
  `effective_passable=false`. The row-22 bridge now supplies the return route:
  from `(23,25)`, the first reverse debug path was blocked by live NPC clutter
  at `(12,20)`/`(20,23)`, and a retry after unfreezing NPCs found a 36-step
  route back to `(1,15)`.

- Merchant 4 route drift follow-up: the latest manual drifts were route-settle
  overshoots, not missing passability data. The auto-walk reached open-floor
  turn transitions, then slid one tile off the queued path before the next
  planned direction started. `route_manager.lua` now catches
  `route_drift_off_path`, replans from the drifted tile to the same selected
  object, and logs `AUTO_WALK_DRIFT_REROUTE`. Live proof showed the recovery
  surviving several drifts on a Guard 2 route and still reaching the target.
  User testing later confirmed the entrance-to-Merchant 4 route can succeed
  after reroutes in that older map state; current Tool Merchant routing now
  uses the `(17,22)` row-22 bridge instead of the stale `(17,25)` or `(21,26)`
  seams.

- Brecconary Merchant 4 noise-hardening pass: the current live map is
  confirmed as `map=0x08(Brecconary)`, not castle data. `(27,25)->DOWN` into
  `(27,26)` is a confirmed false-wall passthrough: verifier movement succeeded
  3/3, with six moved observations total, and post-reload
  `inspect_move:27,25,DOWN` reports `effective_passable=true`. The lower-right
  bypass that A* invented after this was false: validation failed at
  `(28,27)->DOWN`, and a direct check blocked the same edge, so `(28,28).north`
  is now modeled as a directional block. The remaining clean no-path from
  `(27,25)` to Merchant 4's stand `(25,26)` is currently caused by live NPC
  occupancy around `(27,27)/(27,28)`, not by a new map blocker. A parked-NPC
  survey then reproduced the timing-noise problem by treating the confirmed
  passable `(27,26)` edge as blocked during auto-step retries, so
  `route_manager.lua` now keeps blocked-only seam memory diagnostic-only; only
  explicit manual commands such as `add_blocked_edge` promote runtime blockers.
  Follow-up manual testing found another public-route frontier seam:
  `(22,25)->LEFT` into `(21,25)` is hard engine-blocked. Pre-patch
  `inspect_move:22,25,LEFT` said `effective_passable=true`, so
  `map_reader.lua` now models `(21,25).east` directionally for Brecconary.
  The next planned route from live `(23,22)` exposed `(23,22)->DOWN` into
  `(23,23)`: validation could not move through it, and the user manually
  confirmed the engine definitely blocks it. `map_reader.lua` now models
  `(23,23).north` directionally. The validation tool itself was hardened to
  stop duplicate injected steps and to cancel active auto-step state on abort,
  which prevents post-abort seam noise from being written. It also uses a
  validation-only forced D-pad release after injected validation arrivals, so
  normal manual-cancel behavior stays intact. Final live reload from `(25,22)`
  reported no path to `(25,26)` with runtime blockers still empty.
  Follow-up manual cluster check found the vertical x=22 approach open through
  `(22,26)`'s north edge: `(22,21)` is open from the south, `(22,22)` through
  `(22,25)` are open north-to-south, and only the south exit from `(22,26)` is
  closed. East/west on those cells was not checked. The live model already
  matches this, so this pass added regression coverage rather than new blocker
  data. A validation pass then reached `(25,22)` cleanly and failed on
  `(25,22)->DOWN` into `(25,23)`; the user manually confirmed that edge is
  actually open from north to south, so that failure is treated as validation
  noise and `(25,23).north` is pinned open. A follow-up validation then reached
  `(27,28)` and failed on `(27,28)->LEFT` into `(26,28)`; live inspect still
  said that edge was passable, but repeated manual taps also blocked there and
  the user confirmed it is engine-blocked. `map_reader.lua` now models
  `(26,28).east` directionally, leaving other approaches to `(26,28)` open for
  future checks. Reload proof showed `inspect_move:27,28,LEFT` now blocked by
  the model with runtime blockers empty. The next generated detour failed
  immediately on `(27,28)->DOWN` into `(27,29)` even though static inspect still
  said that down edge is passable. Repeated manual down taps also blocked
  there, and the user confirmed the south exit is engine-blocked. `map_reader.lua`
  now models `(27,29).north` directionally too. Reload proof showed
  `inspect_move:27,28,DOWN` now blocked by the model with runtime blockers
  empty. The next generated detour failed immediately on `(27,28)->RIGHT` into
  `(28,28)` while static inspect still said that right edge was passable.
  Repeated manual right taps also blocked there, and the user confirmed the
  east exit is engine-blocked. `map_reader.lua` now models `(28,28).west`
  alongside the existing `(28,28).north` block. Reload proof showed
  `inspect_move:27,28,RIGHT` now blocked by the model with runtime blockers
  empty, and from live `(27,28)` the route to Merchant 4's interaction tile
  `(25,26)` now reports clean no-path (`visited=52`).
- Manual wall-bump responsiveness follow-up: Brecconary logs showed physical
  wall bumps producing `manual_tap` auto-step timeouts after 45 frames, which
  can make real collisions feel much worse than a normal held-key bump. The fix
  keeps manual movement from adding a synthetic tap-to-step hold when the target
  edge is already a known static permanent or directional blocker. The player
  can still deliberately hold a direction into a wall, and debug/probe injected
  steps can still test known blockers, but quick released taps into known walls
  now stop at `AUTO_STEP_REFUSED_STATIC_BLOCK` instead of writing another seam
  observation. Live reload proof: `LAUNCHER_PROBE:
  codex_static_wall_refusal_reload` at `map=0x08(Brecconary) x=24 y=25`.
  Follow-up logs showed the same post-release hang still happened on unmodeled
  wall/NPC collisions from `(24,25)`, so physical `manual_tap` now releases the
  synthetic D-pad as soon as the movement subpixel twitches instead of holding
  into the obstruction until timeout. Debug/probe injected steps and queued
  route verification still keep the more conservative early-twitch behavior.
  Reload proof: `LAUNCHER_PROBE: codex_manual_tap_release_reload` at
  `map=0x08(Brecconary) x=24 y=25`.
  One more log pass showed why this still felt bad: the turn-repress recovery
  rearmed the same direction after the release, then held it into the wall/NPC
  until timeout. Physical `manual_tap` now also suppresses that re-press after
  any movement-subpixel twitch; debug/probe injection and queued routes keep
  their conservative re-press behavior. Reload proof:
  `LAUNCHER_PROBE: codex_manual_repress_suppressed_reload` at
  `map=0x08(Brecconary) x=24 y=25`.
  The user's half-second timing clue then matched the remaining log path:
  released physical bumps were still reaching the normal 45-frame blocked-step
  publication, which writes seam/NPC block evidence. Physical `manual_tap` now
  silently cancels about 20 frames after a twitch if the tile has not changed,
  so normal released wall bumps do not publish blocked seam events. Reload
  proof: `LAUNCHER_PROBE: codex_manual_twitch_silent_cancel_reload` at
  `map=0x08(Brecconary) x=24 y=25`.
- Brecconary weapon-shop throat and blocker-policy follow-up: manual movement
  proved `(5,7)<->(5,6)` is open both ways, matching the earlier manual
  proof that `(5,7)<->(5,8)` is open. `map_reader.lua` no longer models
  `(5,6).south` or `(5,8).north`; the remaining local modeled wall is the
  east edge into `(6,7)`. Fresh live reload
  `LAUNCHER_PROBE: codex_manual_promotion_reload` plus `inspect_move:5,7,UP`
  reported `effective_passable=true` with no directional blocker. A hostile
  verifier repro still reported `probe_edge_verify:5,7,UP,3` as
  `confirmed_blocked`, but the new policy correctly kept
  `runtime_added=false`, logged `manual_promotion_required=true`, and left
  `RUNTIME_BLOCKS map=0x08 none`. Treat verifier consensus as suspect
  evidence only; use `add_blocked_edge:X,Y,DIR` or `add_blocked_tile:X,Y`
  only after manual review.
- Previous Brecconary Merchant 4 alternate-pocket check: the user manually verified
  `Merchant 4` is the normal tool merchant. The raw trigger at `(24,25)`
  opens the tool shop while facing east, but it is not public floor:
  `(24,25)->LEFT` and `(23,25)->RIGHT` both blocked 5/5. The then-confirmed
  alternate interaction tile is
  `(25,26)` facing north: `(25,27)->UP` moved into `(25,26)` 3/3 despite a type-0
  decode, and TALK there opened the tool shop/item list. `map_reader.lua` still
  treats `(25,26)` as a passthrough, but later manual/live evidence superseded
  this as the normal service target: `objects.lua` now routes Merchant 4's
  service interaction to `(23,25)` facing east. The route from public origin
  `(1,15)` is still blocked, though: after reload, `debug_pathfind_to:25,26`
  and `debug_pathfind_to:25,27` both returned no path, and the remaining lower
  southeast frontier seams `(14,28)->RIGHT`, `(15,27)->DOWN`,
  `(15,27)->RIGHT`, and `(16,26)->DOWN` are all live-blocked. The boundary is
  one-way in places: `(16,27)->UP` and `(15,28)->LEFT` moved cleanly, and
  `(25,26)->DOWN` blocked 5/5 despite `(25,27)->UP` entering the stand. A later
  inside-out validation from `(25,27)` exposed two more false exits:
  `(25,27)->LEFT` into `(24,27)` and `(25,27)->DOWN` into `(25,28)` both
  blocked 5/5. With those modeled, `(25,27)` can no longer path back to public
  space (`visited=2`), and public origin `(1,15)` still cannot path to the
  tool-shop interaction tile `(25,26)` (`visited=406`) with no runtime blocks.
  A later public-route attempt reached `(22,26)`, but the user manually
  verified `(22,26)->DOWN` into `(22,27)` is hard engine-blocked; model that as
  `(22,27).north`, not a full-cell blocker. This no longer means Merchant 4 is
  globally isolated; it only means the older `(25,26)` alternate pocket has no
  public route. A
  follow-up suspect-cell pass found no safe route-opening patch: `(26,25)` and
  `(26,27)` blocked 5/5, `(23,27)` blocked from `(23,26)`, and the potential
  false-wall cells `(23,26)`, `(24,26)`, and `(27,26)` produced passable or
  mixed evidence without forming a reliable connector to `(25,26)`. Runtime
  blocks stayed empty, so leave these as manual-check candidates for now.
- Brecconary Merchant 4 tool-shop item-list speech is fixed. The open list
  showed `Herb 24`, `Torch 8`, and split `Dragon's 20` / `Scale`, but the
  merchant detector reported `offers=""` because its catalog only included
  equipment names. The shop catalog now includes normal item-shop goods, so the
  live open list reports `offers="Herb, Torch, Dragon's Scale"` and speaks
  `Herb. 24 gold.`, `Torch. 8 gold.`, and `Dragon's Scale. 20 gold.` as the
  cursor moves.
- Brecconary Merchant 4 Buy/Sell prompt speech is fixed. The first shop prompt
  shows `BUY` and `SELL` over stale command-menu rows, so the field command
  reader mislabels D9 `0`/`1` as `TALK`/`STATUS`. The merchant reader now has
  an action mode for `What can I do for thee?`: D9 `0` speaks `Buy`, D9 `1`
  speaks `Sell`, and cursor-blink row churn does not repeat the prompt.
- Brecconary Merchant 4 close-out dialogue overlap is fixed. While the merchant
  reader owns a shop prompt/list, `main.lua` now keeps the lower-dialogue
  baseline synchronized with the visible prompt. Closing the item list now
  speaks only `I will be waiting for thy next visit.` instead of dragging the
  prior welcome / `What dost thou want?` text back into the farewell.
- Brecconary current door-attribution check: from the public origin `(1,15)`,
  with NPC blockers skipped and door RAM simulated, the known doors split the
  current live NPC table cleanly. `Northeast Door` `(21,6)` unlocks `Woman 1`;
  the user manually verified that `Woman 1` is the Fairy Water merchant, so
  this target is expected to be locked behind that door. `Inn West Room Door`
  `(5,22)` unlocks `Old Man 1` at his current `(1,20)` position and `Guard 4`.
  Opening both doors still does not route to
  `Weapons Merchant` stand `(5,6)`, the center-east room (`Person 3`,
  `Old Man 2`, `Guard 2`), the southeast room (`Person 1`, `Person 5`),
  `Guard 3`'s lower-left room, or `Merchant 4`'s southeast tool-shop region.
  Treat those as route/seam follow-ups rather than known-door-gated NPCs.
- Brecconary door/classification pass: Mike's RPG Center labels the services as
  inn, weapon/armor shop, item shop, Fairy Water/special item shop, and curse
  remover; Realm of Darkness and Gamer Corner note the Fairy Water shop needs a
  Magic Key, and Gamer Corner lists two Brecconary locked doors: northeast
  building and west room in the inn. The object locator previously exposed no
  doors on map `0x08`; it now exposes `Northeast Door` `(21,6)` and
  `Inn West Room Door` `(5,22)`, and `map_reader.lua` checks both through the
  opened-door RAM array. With both doors synthetically open in RAM, the
  earlier static pass made only `Guard 4` and `Woman 1` reachable; the current
  live-NPC refinement also puts `Old Man 1` behind the inn west-room door.
  `Weapons Merchant`, `Person 3`, `Person 5`, `Old Man 2`, `Merchant 4`, and
  `Person 1` remain no-path, with current live additions `Guard 2` and
  `Guard 3`, so they are missing route/blocker-data follow-ups rather than
  known door-gated targets. Older direct verifier evidence that said
  `(5,7)->(5,6)` was blocked is now considered timing-noise evidence, not a
  map fact; manual movement and static inspect show the weapon-shop stand seam
  is open.
  Closed-door no-path hints are now target-aware: opening the reachable door
  frontier must actually make the selected object reachable before the player
  hears the magic-key/door advice.
- Brecconary false-blocker poke-around: a follow-up topology pass showed that
  opening one of `(20,12)/(21,12)/(22,12)/(24,12)` would connect the
  Person 3 / Old Man 2 room in the model, while southeast bridge candidates
  would connect `Person 5`, `Person 1`, or `Merchant 4`. Live verifier probes
  blocked all checked candidates, including `(24,13)->UP`, `(21,8)->DOWN`,
  `(17,10)->RIGHT`, `(21,16)->DOWN`, `(25,14)->DOWN`, `(17,20)->DOWN`,
  `(16,25)->RIGHT`, `(16,26)->RIGHT`, `(14,28)->RIGHT`,
  `(15,27)->DOWN`, `(15,27)->RIGHT`, `(22,13)->UP`, `(21,13)->UP`,
  `(20,13)->UP`, `(19,13)->UP`, and `(16,22)->RIGHT`. Runtime blocks were
  cleared after each verifier pass, and the player was restored to `(1,15)`.
  This was later resolved in two places: `(24,12)` is the intended passthrough
  into the Old Man 2 room, and the old `(16,22)->RIGHT` block was superseded
  by raw verifier proof that `(17,22)` is passable from both east and west.
- Selected-object NPC teleport follow-up: while checking Brecconary NPCs before
  leaving town, `Shift+Enter` was found to teleport onto the selected NPC's
  occupied tile. The hotkey now resolves an NPC landing first: service NPCs use
  their interaction stand when one is modeled, otherwise the first open
  cardinal adjacent cell is used. The resolver reads the selected NPC slot's
  live RAM position without forcing a full object-list rebuild, skips occupied
  adjacent cells, and logs `TELEPORT_SELECTED` with the target and landing.
  Follow-up logs showed the Weapons Merchant counter landed correctly at
  `(5,6)` but TALK still missed because the hero was not facing north, so
  selected NPC teleports now queue one raw post-teleport facing tap after the
  normal input-suppression window, neutralize input afterward, and log
  `TELEPORT_FACE`. A later retest showed `Shift+Enter` could leak through as
  Start if the hotkey was still physically held after the fixed suppression
  window, leaving the game in a menu/control-stuck-feeling state until Enter
  was pressed again. Teleport suppression now watches the non-modifier trigger
  key (`Enter` or an arrow), keeps Start/D-pad neutral until release, and only
  then runs the facing tap. A second live repro of the "hung" state showed
  input was actually neutral and the menu was closed; the selected Woman 3
  teleport had landed at `(5,7)`, where the first read treated UP/DOWN/RIGHT as
  blocked while LEFT was the NPC. The DOWN edge was later manually disproved
  and removed from the model; Brecconary still records the confirmed UP and
  RIGHT seams, and selected NPC teleport skips adjacent landings that have no
  non-target escape.
  Post-restore live testing also fixed the auto-visited marker for counter
  services when another object is selected: TALK from the weapon-shop stand
  `(5,6)` with `Exit to World Map` selected now marks `Weapons Merchant`
  visited instead of logging a no-adjacent-NPC skip.
  Next manual check: select a Brecconary NPC and press `Shift+Enter`; the hero
  should land next to or at the interaction stand for that NPC, face the target,
  and then TALK should reach the NPC/counter. Woman 3 at `(4,7)` should land at
  `(4,8)`, facing north, not at the trapped `(5,7)` stand.
- Brecconary west-wing throat follow-up: manual movement proved the pocket near
  `(3,7)` was artificially pathability-empty because live-passable type-0
  cells were missing passthrough entries. `(3,7)`, `(2,9)`, and `(3,9)` are now
  modeled as passthrough cells. Repeated `(3,7)->UP` attempts into `(3,6)`
  blocked 5/5 with no NPC or runtime block, so `(3,6)` remains closed. After
  reload, live inspect reports the throat cells as `reason=passthrough`, and
  the reachable-object filter from `(3,7)` now exposes 16 reachable objects
  instead of leaving the pocket empty.
- Brecconary east-wing throat follow-up: manual movement proved `(22,24)` is
  another live-passable type-0 false wall. `(22,24)->UP` into `(22,23)` and
  `(22,23)->DOWN` back into `(22,24)` both moved repeatedly. Before the patch,
  live inspect reported `(22,24)` as `reason=tile_type` with no permanent,
  runtime, NPC, or directional block, so this snuck in through the base town
  tile decoder rather than a learned runtime blocker. `map_reader.lua` now
  models `(22,24)` as a passthrough; after reload, the reachable-object filter
  from `(22,24)` reports 18 reachable objects.
- Brecconary weapon-shop throat bad-blocker bucket: manual movement proved the
  `(5,7)<->(5,8)` and `(5,7)<->(5,6)` edges are open both ways. These were not
  ROM tile false walls; they were stale directional blocks promoted from noisy
  selected-NPC/verifier timing evidence. Before the fixes,
  `inspect_move:5,7,DOWN` and later `inspect_move:5,7,UP` showed the model
  alone was blocking the move while tile, permanent, NPC, and runtime blockers
  were clear. `map_reader.lua` now removes both vertical directional blocks
  while keeping the still-modeled east seam into `(6,7)`.
- Combat spell-list narration first pass: after exiting Erdrick's Cave, a world
  map fight with a Red Slime exposed that battle spell menus were not being
  read. Live capture showed the SPELL submenu with cursor `D8=0 D9=0` and upper
  text containing `HEAL` / `HURT`, but the old battle parser treated cursor
  `(0,0)` as top-level `FIGHT`. `battle.lua` now recognizes visible known spell
  names on the battle spell-list screen, and `main.lua` keeps a battle spell
  submenu mode that announces the selected spell with MP cost. Live reload proof
  logged `BATTLE_SPELL: Spells. Heal. 4 MP` on the parked first spell. Next
  combat checks: move within the spell list, back out to the top-level battle
  menu, and cast a spell to verify result narration.
- Combat spell-list lag follow-up: the first spell-reader patch was too eager
  and decoded the upper battle window every battle-menu poll, which lagged out
  combat. The spell-screen detector is now only a one-time recovery probe for
  reload/attach into an unknown battle menu state; normal SPELL entry is tracked
  from the A press and should not continuously rescan upper PPU rows.
- Combat spell-list polish follow-up: live grinding confirmed most lag was gone
  but some glitching remained at battle start, SPELL menu entry, and Heal/Hurt
  cursor movement. The current disk patch removes the routine battle-start
  recovery scan, detects an A-held top-level SPELL -> `(0,0)` transition without
  an upper-window scan, and makes spell-list speech interrupt stale queued spell
  names. This patch is statically validated, but the last BizHawk auto-reload
  stopped polling after writing only a fresh log header, so it still needs a
  manual reload/restart before live judgment.
- Combat spell-list polish follow-up 2: the user's next live test confirmed
  combat-start lag is gone, with remaining glitching isolated to SPELL menu
  entry and Heal/Hurt cursor movement. `main.lua` now avoids the generic
  field-menu `COMMAND` PPU scanner in battle entirely; battle menu and spell
  list tracking read the already-cached D8/D9 cursor RAM instead, while keeping
  the expensive upper-window spell-list detector only for reload-directly-into-
  battle recovery. The script reloaded cleanly afterward; next fight should
  judge SPELL entry/cursor feel.
- Combat opening dialogue follow-up: live logs showed battle-state detection
  and menu speech were now prompt, but `A Red Slime draws near!` did not log
  until roughly 216-246 frames after battle start. Because menu/spell speech
  can queue ahead of that late stable-dialogue announcement, the latest patch
  resets lower-dialogue baselines on battle start, interrupts immediately with
  `Battle!`, and lets the first coherent `draws near` line interrupt queued
  menu speech as soon as it is complete. Next fight should confirm opening
  announcements are not delayed or skipped.
- Combat action-dialogue speed follow-up: after the opening fix, the user
  confirmed battle starts announce properly but action/damage lines were still
  arriving late in the round. Battle dialogue now has a narrowly-scoped fast
  path for complete action/damage sentence prefixes (`attacks`, HP
  reduced/decreased, misses/dodges) after a short 6-frame confirmation. This
  path originally used interrupting speech to avoid stale menu chatter, but the
  latest audio tuning queues fast action speech instead so close combat lines
  do not cut one another off. Victory and reward pages intentionally stay on
  the normal stable reader, and leaked gold macro artifacts such as `GOLD Gold
  increases` are normalized. Next fight should judge whether attacks and damage
  land soon enough without making combat speech too chattery.
- Combat action-line miss follow-up: fresh logs showed a quick Slime fight at
  frame 7800 going from `A Slime draws near!` directly to reward text, while
  longer Red Slime rounds spoke attacks and damage. This pointed at one-hit
  kills where the text window briefly contained a complete `Bill attacks!`
  prefix followed by an incomplete `reduced by` fragment and then reward text.
  The normalizer now preserves complete action prefixes before dropping
  truncated damage fragments, and the fast path extracts the eligible action
  prefix before reward text begins. Next one-shot Slime should still speak at
  least `Bill attacks!`.
- Combat action-line repeat follow-up: the user heard `Bill attacks` repeat in
  one later fight. Logs showed one Red Slime damage line announced three times
  as the PPU rendered equivalent dot-artifact variants: `Hit . Points`,
  `been . reduced`, and trailing `5. .`. `battle.normalize_dialogue()` now
  removes isolated dot tiles between words and duplicate punctuation-dot
  artifacts before overlap/fast-path comparison. Stronger-enemy testing should
  verify that each round's action/damage line speaks once without losing the
  next round.
- Erdrick's Cave B2 first chest-route pass: the new B2 map `0x1D` had no
  permanent directional seam model, so auto-walk toward the chest at `(9,3)`
  kept learning hidden one-way maze walls during play and eventually gave up.
  Direct `probe_edge_verify` checks promoted only 5/5 blocked approaches:
  `(5,3).south`, `(6,4).west`, `(6,5).east/south`, `(7,4).south`,
  `(8,5).west/south`, `(9,5).south`, `(5,8).south/east`, and `(7,8).west`.
  A second pass from the stairs/chest route added `(1,6).south` and
  `(2,6).south`; route-observed `(4,7).west` and `(2,6).east` were directly
  mixed, so they intentionally stay out of permanent data. A final focused
  verifier pass added `(3,5).south`, `(4,4).east`, `(4,5).east`,
  `(4,6).east/west`, `(5,7).north/east`, `(5,8).west`, `(7,8).east`, and
  `(8,7).south`. A morning follow-up after a normal stairs-to-chest route
  promoted `(6,5).west`, `(7,9).east`, `(7,7).north`, `(8,7).north`,
  `(4,7).south`, and `(4,7).west` after fresh 5/5 verifiers. After enabling
  BizHawk auto-reload and reloading for real, validation exposed `(8,7).east`
  as blocked 5/5 and `(2,6).east` as blocked 10/10; both are now modeled. With
  runtime blocks cleared, `debug_pathfind_adjacent:9,3` from B2 stairs now
  reports no path to any chest-adjacent tile. Additional bridge spot checks
  reconfirmed `(5,3).south`, `(6,4).west`, `(9,5).south`, and `(7,4).south`
  blocked 10/10. A reverse pass from chest-side `(8,3)` toward stairs added
  `(9,5).north`, `(7,4).north`, `(6,4).north`, `(5,3).east`, `(5,2).east`, and
  `(5,1).east` after clean 10/10 direct verifiers. A later chest-to-stairs
  route naturally failed at `(8,4)->DOWN` and `(8,4)->LEFT`; fresh direct
  repeats promoted `(8,5).north` and `(7,4).east` after both verified blocked
  15/15. Walkthrough context confirmed B2 should be a normal loop to the tablet
  rather than a special-gated puzzle. A later route-shaped raw pass and fresh
  `probe_edge_verify:8,9,LEFT,15` restored `(7,9).east` after 15/15 blocked
  evidence; the earlier raw crossing evidence was timing-confounded. A
  walkthrough-guided left-edge pass found the missing route shape: the intended
  loop uses B2 edge passthrough cells `(0,4)` through `(0,7)`, then returns into
  the interior. `(0,8)`, `(0,9)`, and `(0,3)` were blocked or mixed and remain
  unmodeled. That pass also promoted `(1,3).south`, `(2,3).south`, and
  `(4,3).west` after clean 5/5 verifiers. A follow-up stairs-to-chest reroute
  got deeper, then exposed an upper-left choke. Newly modeled route blockers
  are `(1,5).west`, `(4,4).west`, `(4,3).north`, `(5,2).west`,
  `(4,1).south`, `(3,1).south`, `(3,5).north/west`, `(2,3).east`,
  `(2,1).south`, and `(1,1).south`; `(1,1).south` also verified blocked 15/15
  directly. The graph then needed one more narrow edge opening:
  `(1,2)->LEFT` moved into `(0,2)` 15/15, and forced-origin `(0,2)->UP` moved
  into `(0,1)`. The next autowalk reached `(0,1)` and failed into `(1,1)`;
  `(0,1)->RIGHT` verified blocked 15/15. Follow-up graph checks and live probes
  proved the top-edge continuation: `(0,1)->UP` into `(0,0)` passed 15/15,
  probes moved right through `(1,0)`..`(6,0)`, row-1 downward entries from
  x=1..5 blocked, and `(6,0)->DOWN` moved into `(6,1)`. Static tests pass, the
  running script reports `(0,0)` and `(6,0)` as `reason=passthrough`, and
  `debug_pathfind_adjacent:9,3` from stairs `(8,9)` chooses chest-adjacent
  `(8,3)` with a 42-step route and `Face east`. Live auto-walk is now
  two-way playable: stairs-to-chest reached the chest after one reroute bounce
  near `(7,2)`, and chest-to-stairs bounced through several return-trip dead
  branches before reaching B2 stairs `(8,9)`. Runtime blocks cleared afterward,
  leaving `RUNTIME_BLOCKS map=0x1D none`. The B2 maze is done enough for now:
  avoid spending more time perfecting optional return-trip bounces unless
  normal gameplay exposes a fresh blocker. Next preferred playtesting focus is
  away from pathfinding, likely combat dialogue tuning while exiting the
  dungeon.
- Brecconary autowalk stress survey: from the town entrance, `(0,15)` proved to
  be the isolated transition tile and `(1,15)` correctly hit the
  `low_exit_count` survey-start guardrail, so the parked-NPC survey ran from
  open tile `(15,15)`. It completed with `targets=21`, `successes=7`,
  `gated_or_isolated=8`, `state_issues=6`, and zero suspected engine blockers.
  Follow-up state showed `RUNTIME_BLOCKS map=0x08 none` and no strong survey
  candidates. The state issues were false interruptions caused by normal
  post-arrival `AUTO_WALK_FACE` / NPC-hold behavior between survey targets;
  `survey_safe` autowalk now suppresses those actions while normal player
  autowalk keeps them.
- Fresh Brecconary rerun after that fix improved to `12` successes and `0`
  state issues. The remaining two suspect blockers were checked directly:
  `(5,2)->DOWN` into `(5,3)` is a real engine block and is now modeled as
  `(5,3).north`; `(19,14)->RIGHT` into `(20,14)` is passable 5/5 and is now
  covered by a survey-classifier guard for orphaned routes that actually landed
  on the suspected tile.
- Next Brecconary survey exposed route drift rather than new blockers. Two
  queued routes overshot by one tile after timeout retry/settle handling, and
  the old survey queue appended those retries after later targets. That made
  several later targets fail from a stranded `(7,10)` start. The retry ordering
  is now fixed so drift retries run immediately, and queued auto-step no longer
  holds early subpixel twitches after a timeout retry.
- Autostep timing follow-up: queued routes now keep holding through early
  movement-subpixel twitches, but timing-suspect turn re-press twitches report
  early to the route manager as direct retry opportunities instead of waiting
  for a full wall timeout. Survey ignores those timing-suspect route blocks as
  map candidates. Live Brecconary proof from `(15,15)` to the world-map exit:
  the route reached `(1,15)` with `movement_succeeded=true`,
  `blocked_events=0`, `suspected_engine_blocked=0`, and
  `RUNTIME_BLOCKS map=0x08 none`.
- BizHawk 2.11.1 side-install check: user transferred save data and reloaded
  in Brecconary under `/mnt/d/emulation/bizhawk-2.11.1/EmuHawk.exe`. Current
  live state reported `POSITION: map=0x08(Brecconary) x=0 y=15`; speech bridge
  was ready with `error=none`; `dw_script_error.log` had no entries newer than
  the earlier `MER` refactor crash.
- Short scan profile on 2.11.1 while idle in Brecconary showed no large
  frame-loop spikes. Biggest steady costs were PPU text/menu scanners:
  `check_yesno_prompt avg_ms=3.566 max_ms=10`, `check_merchant_screen
  avg_ms=1.823 max_ms=6`, and `check_command_menu avg_ms=1.499 max_ms=5`.
  `state.check_for_changes avg_ms=0.009 max_ms=1`, confirming the old `$6003`
  cartridge-work-RAM lag is not present in this run.
- Aggregate PPU stats are still high (`reads=65493755`, `cache_hits=45887003`,
  `cache_misses=19606752`), so the next emulator-API experiment should focus
  on whether BizHawk 2.11.1's bulk/string byte-reading support can reduce
  contiguous menu/dialogue/nametable scans rather than expecting individual
  `readbyte` calls to become free.
- Bulk-read experiment live result: after enabling BizHawk's automatic script
  reload and reloading the patched script, `PPU_STATS` reported nonzero
  `bulk_reads` and `bulk_bytes`. A 2,280-frame Brecconary sample used
  `bulk_reads=46482`, `bulk_bytes=1290432`. Compared with the prior 2.11.1
  idle sample, average scanner costs improved substantially:
  `check_yesno_prompt 3.566ms -> 1.246ms`, `check_merchant_screen 1.823ms ->
  0.302ms`, `check_dialogue 1.119ms -> 0.337ms`, and `check_upper_dialogue
  0.790ms -> 0.254ms`. `check_command_menu` improved more modestly from
  `1.499ms -> 1.126ms`.
- Follow-up route-lag sample in Brecconary: from `(1,15)`, forced
  `pathability_filter:refresh` over 21 objects took `59ms` and logged
  `CMD_TIMING command=pathability_filter:refresh ms=59.000`. Scan profiling
  attributed the spike to `debug_tools.tick max_ms=60`, while
  `objects.check_refresh` stayed `0ms`; this points at reachability/pathability
  computation, not PPU scanning or object refresh.
- Same sample selected `Guard 2` at `(4,8)`. Plain `pathfind` planned a 9-step
  route to `(4,9)` without crossing the 25ms `ROUTE_PLAN_TIMING` threshold.
  `auto_walk` then completed all 9 steps from `(1,15)` to `(4,9)` with each
  movement finishing in 23-28 frames, no timeout/retry reroute, and normal
  post-arrival facing/hold. Current player position after the test is `(4,9)`.
- Object pathability refresh follow-up: the refresh now uses one map-wide
  reachable-cell pass rather than one A* search per object. After a live reload
  probe, `pathability_filter:refresh` from Brecconary `(4,9)` over 21 objects
  returned normally and produced no `OBJECT_PATHABILITY_TIMING` or `CMD_TIMING`
  warning, so the command stayed below the existing 25ms timing threshold. The
  earlier 59ms sample was from `(1,15)`, so keep watching this during normal
  browsing, but the direct per-object pathfinding cost has been removed.
- Reroute-lag follow-up: the spike during Merchant 2-to-exit travel was a real
  auto-step timeout on the unmodeled Brecconary edge `(5,13)->LEFT` into
  `(4,13)`, not a scan-loop or crash issue. The map now blocks `(4,13)` from
  the east approach. After reload, a path-only probe from `(5,6)` to the
  world-map exit chose the detour through `(5,9)->(4,9)` and avoided the old
  timeout edge. Player position was restored to Brecconary `(1,15)`.
- Inn route/name follow-up: `Merchant 2` is now named `Weapons Merchant` and
  `Merchant 3` is now named `Inn` in the Services object list. The inn service
  routes to the public stand tile `(8,21)` facing east; live TALK from there
  opened `Welcome to the traveler's Inn... Room and board is 6 GOLD per night.`
  A first retest exposed a timeout on `(7,17)->RIGHT` into `(8,17)`, so that
  west approach is now modeled as blocked. After reload, auto-walk from
  Brecconary `(1,15)` queued 17 steps for `Inn`, reached `(8,21)`, and faced
  east with no new blocked edge. Player position was restored to `(1,15)`.
- Weapons merchant item-list follow-up: after the clean route to the Brecconary
  weapon counter, TALK/YES reached `What dost thou wish to buy?` but the item
  list was silent. This was not a speech backend failure; `report_merchant_state`
  was reading the wrong screen rows. `merchant.lua`/`main.lua` now try the old
  fixed shop reader first, then live scrolled contexts including the alternate
  nametable base. Live proof recovered all six offers and spoke the selected
  item; a down/up cursor pulse spoke `Copper Sword. 180 gold.` then
  `Club. 60 gold.`
- Spell menu follow-up: after the player reached level 3 and learned Heal, the
  SPELL list opened but did not speak its contents. Live state showed the
  command menu header was still detected, speech was ready, and no dialogue or
  upper-window text was available; the missing piece was a SPELL submenu reader.
  `main.lua` now tracks `submenu=SPELL` and `items.lua` maps D9 to known
  spells. The visible field list only shows `>HEAL` and does not show a
  per-spell MP cost, so accessibility speech adds NES spell costs from metadata.
  Live reload/re-entry proof under BizHawk now speaks exactly
  `Spells. Heal. 4 MP`, then `report_menu_state` shows `submenu=SPELL` with
  speech ready and no backend error.
- Erdrick's Cave B1 first-floor cleanup: after entering the cave, object
  browsing initially showed Brecconary-style NPC ghosts. `objects.lua` now
  limits live NPC parsing to town/castle terrain contexts, so dungeon/cave
  maps keep only their static objects. Live reload proof on `map=0x1C` showed
  exactly `Exit to World Map` at `(0,0)` and the old hard-coded
  `Stairs Down to B2` at `(1,1)`; the NPC filter reported no objects. Probes
  also confirmed the entrance path `(0,0)->(1,0)->(1,1)` and reverse, so
  `map_reader.lua` models `(0,0)` and `(1,0)` as Erdrick B1 passthrough cells.
  After reload, `pathfind_to:1,1` from the entrance returned
  `Path: 1 east, 1 south`, and
  `report_survey_start` was viable with `targets=2` and `reachable_area=83`.
- Survey battle safety: autonomous surveys now pause on `battle_started`
  instead of recording the interrupted target as a map failure. The active route
  is cancelled, route context is cleared, and the same target is retried when
  field movement is safe again. This should make dungeon surveys tolerable once
  random encounters start appearing; low HP still aborts the survey before
  resuming movement.
- Erdrick's Cave B1 targeted survey pass: starting from the entrance `(0,0)`
  correctly tripped the survey `low_exit_count` guardrail, so the first-floor
  survey seed is `(2,2)`. From that seed, `Exit to World Map` surveyed
  successfully. The earlier `Stairs Down to B2` survey only proved reachability
  to the old modeled coordinate; using STAIRS at `(1,1)` produced
  `'There are no stairs here.`
- Erdrick's Cave stair-coordinate correction: the ROM stair-down table has
  `1C 09 09`, and live STAIRS from B1 `(9,9)` moves to B2 `(8,9)`. Live STAIRS
  from B2 `(8,9)` returns to B1 `(9,9)`. `objects.lua` now uses those paired
  coordinates instead of the old `(1,1)` guesses. After reload,
  `current_object` at B1 `(9,9)` reports `Stairs Down to B2: here`.
- Route execution briefly produced noisy blocked-move observations at `(2,1)`
  and `(1,2)`, but direct edge probes from `(2,2)` moved north and west
  successfully; treat those as route timing noise, not map data.
- Erdrick's Cave B1 route-block follow-up: a live route from the corrected B1
  stairs `(9,9)` back to the entrance completed at `(0,0)` and had no battle
  events in the log. It did expose real hidden maze seams around `(3,4)`.
  Direct probes after clearing runtime blocks confirmed `(3,4)->UP`,
  `(4,4)->UP`, `(3,4)->LEFT`, and `(3,4)->DOWN` block in-engine despite
  walkable decoded tiles. `map_reader.lua` now models those as directional
  blocks only; after reload, `pathfind_to:0,0` from `(9,9)` chose a route
  around that central cluster.
- Erdrick's Cave B1 entrance-to-stairs follow-up: another live pass exposed
  additional real directional seams at `(2,4)` from the west, `(1,5)` from the
  north, `(7,2)` from the west, `(6,3)` from the north, `(5,7)` from the
  north, `(6,6)` from the west, `(8,8)` from the north/west, and `(8,9)` from
  the west. After reload, auto-walk from entrance `(0,0)` to
  `Stairs Down to B2` reached `(9,9)` and ended with no runtime blocks.
  One-off route observations at `(6,4)` from the west were not promoted because
  direct probes moved successfully. No battle or encounter markers appeared in
  the latest B1 log.
- Erdrick's Cave B1 probe-hardening follow-up: a later route got worse after
  four newest one-probe additions and produced many reroutes plus contaminated
  runtime blocks. Rolled back `(4,3)` from the east, `(4,1)` from the south,
  `(6,3)` from the west, and `(6,6)` from the north until repeated
  `probe_edge_verify` consensus reconfirms them. Route-only blocked
  observations now stay as soft seam evidence instead of hard runtime map
  blockers.

## Current Goal

Run the early game as a player would, using the accessibility mod as the primary interface. Capture friction, missing narration, confusing commands, pathfinding recovery problems, and quality-of-life improvements.

## Focus Areas

Location awareness:
- Announce current map, coordinates when useful, facing, exits, nearby objects, and hazards
- Make it easy to recover orientation after movement or teleport/debug commands

Object interaction:
- Verify NPC, chest, door, stair, shop, and inn workflows
- Ensure object navigation explains whether a target is reachable
- Prefer actionable failure reasons over generic no-path messages

Menus and combat:
- Confirm menu cursor narration is reliable
- Confirm combat narration exposes HP, enemy state, results, and turn outcomes clearly
- Identify missing item/spell/shop narration needed for normal play

Movement and routing:
- Prefer routes that feel stable during actual play, not only during survey loops
- Log route failures with enough context to reproduce
- Avoid permanent map-data changes without direct blocker evidence

QoL feature check:
- `auto_walk` should now speak progress on longer routes and speak completion.
- After auto-walking to an NPC, the target should be held briefly so the player
  has time to use TALK. The route should also face the target after arrival so
  TALK does not fail with "There is no one there." For moving NPCs, the hold
  should pin the selected NPC slot to the planned object coordinates rather
  than a stale live position.
- Object filters are All, NPCs, Services, Treasure, Travel, and Doors; `Q`
  cycles forward, `Shift+J` and `Shift+L` move filter categories without
  scrolling objects, and `Shift+K` jumps back to All.
- Location readout is `Shift+W` now. Do not use the old `Shift+P` habit in
  BizHawk; this machine's BizHawk global hotkeys bind `P` to Quick Load.
- `Shift+O` cycles the separate pathability filter: All, Reachable, and
  Unreachable. This stacks with the object category filter, ignores moving NPC
  occupancy, and is intended for sanity-checking larger maps without making
  rapid J/K/L browsing run pathfinding every tap.
- Overworld route guidance exists for the first dungeon, Garinham, and the
  early safety returns. Select the `Erdrick's Cave`, `Garinham`, `Brecconary`,
  or `Tantegel Castle` Travel object and press `R`, or use `route_guidance`,
  `start_overworld_route:cave`, `start_overworld_route:garinham`,
  `start_overworld_route:brecconary`, or `start_overworld_route:castle` from
  the command file. Press `R` again, run
  `route_status`, or browse the Travel filter to hear the next route waypoint.
  If a route is active and another guided Travel destination is selected,
  pressing `R` replaces the old route with a route to the new destination. If
  the player has drifted far off the expected waypoint, pressing `R` on the
  active route waypoint recalculates the next marker from the current position;
  `route_recalculate` / `recalculate_overworld_route` do the same from the
  command file. `stop_overworld_route` cancels the active route.
  First-phase overworld auto-walk is available while a route is active: press
  the normal auto-walk command or send `auto_walk` to queue one straight segment
  to the next waypoint. It stops at that waypoint, on a movement blocker, or
  when battle/menu/dialogue state interrupts field movement; it does not yet do
  full world-map A* or automatic rerouting around terrain.
  FCEUX live smoke proved the command path can begin a queued route segment:
  from `(28,13)`, `auto_walk` toward Erdrick's Cave started `source=queued_route`
  and then stopped on a blocker entering `(28,12)` from the south. Treat that
  cave approach as a route-data follow-up, not an auto-walk executor failure.
  After starting the route, `current_object` should report a `Route next`
  waypoint rather than the plain landmark. `O` remains the plain heading/path
  preview for the selected object, and `U` drives the one-segment auto-walk
  behavior.
- The Erdrick's Cave route includes a one-time bridge warning about stronger
  monsters beyond the crossing. During live testing, check whether this is
  helpful and quiet enough. The route now uses additional mountain-pinch
  markers after live evidence showed the old long heading from `(30,32)` led
  into blocked terrain: `East choke approach`, `Eastern mountain lane`,
  `North ridge bend`, then `North trail marker`. `East choke approach` at
  `(35,32)` and `Eastern mountain lane` at `(35,24)` are exact markers now;
  this prevents the route from advancing one tile early and telling the player
  to turn before the choke lane has really been cleared.
- The Erdrick's Cave route also uses the lower bridge detour after live
  evidence showed the direct first-bridge-to-pinch leg could block: from
  `Brecconary road`, it now routes to `Bridge south bend`, `Bridge lower west
  lane`, `Bridge west bend`, `Upper bridge lane`, and `East choke approach`.
  The immediate repro was a blocked north move from `(45,34)` into `(45,33)`,
  followed by blocked north attempts from `(41,35)`, `(40,35)`, and `(39,35)`
  when the detour was still too diagonal. A later log showed the old
  `Mountain pinch turn` marker caused a short west-then-east reversal, so it
  is no longer a mandatory step on this bridge/east-choke segment.
- The Brecconary and Tantegel Castle safety routes reverse the cave route's
  mountain-lane and bridge markers, using `East choke approach`, `Upper bridge
  lane`, `Bridge west bend`, `Bridge lower west lane`, and `Bridge south bend`
  before heading directly to safety. Live return evidence showed blocked
  direct moves into `(39,34)`, `(41,34)`, and `(42,34)`, while the lower bend
  through `(44,38)` reached town cleanly. The old safety marker at `(45,34)`
  was removed because it sent the player north, then immediately back south
  toward town. These routes warn once that monsters
  should become safer beyond the bridge. From Garinham, these safety routes
  now first guide through the north-coast and shoulder markers back toward
  `Garinham east field` and `Erdrick's Cave road` before using the already
  tested cave-to-safety route. The Garinham-bound route uses those same
  markers in reverse after `Erdrick's Cave road`; it currently includes
  `Garinham east field`, `Garinham ridge entry`, `Garinham east ridge`,
  `Garinham shoulder bend`, `Garinham shoulder east step`, `Garinham mountain
  shoulder`, `Garinham north coast lane`, `Garinham north coast west lane`,
  `Garinham outskirts`, and `Garinham approach` `(2,2)` before the town at
  `(1,2)`. It completes on map `0x09`. The
  safety routes still complete on the destination maps (`0x08` for
  Brecconary; `0x04` / `0x05` for Tantegel Castle).
- Read-only hotkey speech now queues instead of interrupting current speech:
  position, HP/MP, level, gold, experience, stats, screen text, and `R` route
  guidance/status use non-interrupting speech. While a manual step is still
  settling, `R` may report an active route's status, but starting a new route
  or using movement-changing object controls waits for stable movement and
  says `Wait for movement to finish`.
- Visited flags are session-only and map-scoped. Use `Shift+V` or
  `mark_visited` to mark manually; `clear_visited` clears the current map and
  `clear_visited:all` clears all maps. After TALK dialogue, the auto-visited
  marker now falls back to live NPC RAM if the cached object list has stale NPC
  coordinates, which can happen under BizHawk's disabled periodic NPC refresh.
  It also recognizes modeled service interaction stands such as Brecconary's
  weapon-shop counter even when that merchant is not the currently selected
  object. The marker stays armed for slow dialogue stabilization and survives
  BizHawk source reloads, so delayed NPC text should still mark the talked-to
  NPC without losing existing visited flags on `touch main.lua`.
- Selected-object teleport uses `Shift+Enter` for the selected object, with
  NPCs landing at an adjacent or service interaction cell, and
  `Shift+direction` for an adjacent landing on that side of the target.
- Watch selected-object teleport near doors/stairs and moving NPC clusters.
  The first manual test did not show lost keyboard input after teleport; logs
  showed the player boxed in at `(4,6)` on map `0x05` by NPCs at `(3,6)` and
  `(5,6)`, the door south, and a noisy north doorway edge.
- Direct selected-object teleport to an unwalkable target should speak a simple
  player-facing refusal, without mentioning debug-only `near` or `force` flags.
- Latest manual pass: Guard 1's route recovered and reached an adjacent tile,
  but the post-arrival facing input stepped into the guard's planned tile
  because the NPC hold used his wandered live position. `route_manager.lua` now
  holds the selected NPC at the planned target tile, and the false-visited case
  still behaves correctly.
- Stale command-menu cache was confirmed from live logs: after a TALK/dialogue
  attempt, `EVENT: command menu opened` had no matching close event, and later
  `auto_walk` commands were blocked before planning. `main.lua` now treats the
  raw `COMMAND` header match as scanner input only unless a confirmed live
  field-menu session is active. Movement and auto-walk stay blocked for that
  confirmed live session while the cursor hold or raw header is present, so a
  still-open command menu cannot let auto-step record false field blocks after
  the cursor blink/hold expires; TALK and menu-close paths clear the live flag
  before lingering PPU text can freeze field movement.
- Console reloads can leave required modules cached. A Guard 1 retest after a
  console reload still used the old `route_manager.lua` target-hold code and
  walked the hero onto Guard 1's tile at `(7,5)`. `main.lua` now clears project
  modules from `package.loaded` before requiring them. After a fresh reload,
  the visible lower text `'There is no one there.` was logged and spoken, while
  `report_upper_dialogue_state` reported `menu_raw=true menu_active=false`.
- A later Guard 1 playtest at `(18,2)` found a different TALK-failure silence:
  the normal filtered lower reader captured `'There is no one there.`, but the
  y<=3 row-1 cleaned dialogue path missed it and left `announced_lower` empty.
  The row-1 reader now falls back to the already-filtered lower dialogue when
  its fixed-row scan finds no lowercase text. An intermediate bad reload hit
  Lua 5.1's local limit, but the corrected file validates and later live
  reload probes have succeeded.
- Person 1 in the reachable NPC list can still be temporarily blocked by moving
  NPC traffic because the reachable filter intentionally ignores live NPC
  occupancy. The player-facing no-path hint should call that NPC clutter, not a
  closed door, when an NPC-free route exists. `route_manager.lua` now prioritizes
  that explanation over nearby closed-door frontiers. Live note: the reload
  verification accidentally auto-walked the post-reload selected `Exit to World
  Map`; current logged position after cleanup was map `0x04` `(11,28)` with
  runtime blocks clear.
- Reload-lag follow-up: after module-cache clearing, the old BizHawk shim's
  `FCEU` global survived reload and made `emulator_compat.lua` falsely detect
  FCEUX, disabling BizHawk scan throttling. The live symptom was a fresh log
  header with very slow frame progress and `report_scan_stats` saying
  `SCAN_PROFILE unavailable: not running under BizHawk`. `emulator_compat.lua`
  now detects real BizHawk APIs before trusting a stale `FCEU` shim; live
  `touch main.lua` recovery reached `launcher_probe:reload_detect` at frame 60
  and produced normal BizHawk scan stats.
- Reload-input follow-up: after the BizHawk/FCEUX detection fix, stale wrapped
  `joypad`/`input` tables could still be captured as native on reload. That
  could make `joypad.read()` empty and make `joypad.set()` neutralize controls,
  matching the observed `X`/`Z` failures and odd emulator-key behavior.
  `emulator_compat.lua` now unwraps previous adapter closures back to native
  BizHawk APIs and replaces its `FCEU.frameadvance` wrapper on every reload.
  Live reload check reached frame 180, reported `cache_flushes=179`, and had no
  stuck keys in `input_status`.
- Pathfinding confusion follow-up: the no-path behavior after manual movement
  around Guard 1/door terrain was caused by manual blocked steps being promoted
  into runtime blockers on map `0x05`. `route_manager.lua` now treats
  `queued_route=false` blocks as diagnostic seam observations only. A live
  post-reload snapshot reported `RUNTIME_BLOCKS map=0x05 none`.
- Guard 1 overlap follow-up: post-arrival facing was still being interpreted by
  `auto_step` as a player tap, which could walk onto the NPC square. The live
  retest after the suppression patch stayed at `(4,7)` with Guard 1 one tile
  north at `(4,6)`.
- Route-blocking follow-up: if a queued route is blocked by a live NPC, it
  should now be treated as temporary NPC movement instead of map geometry. A
  separate chest route from `(4,7)` hit a current runtime seam block at
  `(4,6)` from the south; current NPC blockers were elsewhere, so that case is
  not NPC clutter.
- Command-menu open follow-up: after the King dialogue fix, opening the command
  menu could still briefly speak the last-used cursor selection before settling
  on TALK. `main.lua` now debounces the opening announcement for six frames and
  uses the first real cursor movement or settled cursor item, so the expected
  open line is `Command. TALK` without a stale selection first. After killing
  and restarting the script, the user physically retested the fix and confirmed
  it worked as expected.
- Death-square follow-up: manual movement found a damaging/death tile on
  Tantegel Castle map `0x04` at `(10,18)`. Entering it from `(10,19)` logged
  `Lost 15 HP. HP 0`, then the normal `Thou art dead.` / Death King recovery
  sequence. Death King dialogue narration passed. The tile is now modeled as a
  hazard, not a wall, so auto-walk, teleport walkability, and tap-to-step
  extension avoid it while deliberate held manual movement remains under
  player control.
- Reachable NPC dialogue pass: the user finished dialogue testing all
  reachable NPCs in this part of Tantegel Castle. Waiting for NPC movement
  remained tedious enough that Guard 1 was reached by teleport. The castle
  merchant-labeled NPCs behaved as dialogue-only NPCs in this pass; keep an
  eye on whether they ever sell later, and consider removing them from the
  Services filter if they stay dialogue-only.
- First-town merchant follow-up: Brecconary `Merchant 1` also behaved as a
  dialogue-only NPC (`Please, save us from the minions of the Dragonlord.`),
  despite being listed under Services. When the merchant moved near the top of
  town, the y<=3 dialogue reader spoke only `Please, save us from`. The row-1
  dialogue path now prefers the richer normal lower-window candidate when the
  fixed y<=3 row scan catches only part of a multi-line message.
- Brecconary service-discovery follow-up: the user talked to all reachable
  townspeople in the first town and still did not find an inn keeper or real
  merchant service. Woman 3 said she was near the shop. The shop/inn actors may
  be blocked targets, may be represented differently than normal wandering
  NPCs, or may need a shop-counter/object interaction path rather than ordinary
  TALK-to-NPC handling.
- Brecconary weapon-shop follow-up: the true weapon/armor merchant is
  `Merchant 2` at `(5,4)`. The safe public access path reaches the doorway/
  counter square at `(5,6)`; face north and TALK even though the merchant object
  is two tiles north. The route enters through `(5,8)->(5,7)->(5,6)`; both
  `(5,7)` and `(5,6)` are false-wall passthrough tiles in the map model. Routes from the merchant pockets to the
  world-map exit proved `(4,4)`, `(4,5)`, `(4,6)`, `(5,5)`, `(6,4)`, and
  `(6,5)` are trap/service-pocket cells for autonomous movement; the map model
  keeps those pathfinder-forbidden and also blocks the false `(8,5)->LEFT`
  shortcut into `(7,5)`.
- Brecconary Merchant 2 item-list narration regression is fixed after the
  `main.lua` local-reduction refactor. The shop list is rendered in fixed
  screen/menu rows even while field scroll registers remain non-zero, so
  merchant scanning now reads screen coordinates by default. Live proof after
  reload: the list reported all six offers and a Down input spoke
  `Clothes. 20 gold.`
- Brecconary counter-service discovery: raw map block `0xF` marks the shop
  counter/large-tile trigger. `Inn` at `(10,21)` is the inn keeper; TALK from
  the public stand tile `(8,21)` while facing east opens `Welcome to the
  traveler's Inn... Room and board is 6 GOLD per night.` `Merchant 4` at
  `(25,25)` is the tool shop; TALK from `(24,25)` while facing east opens
  `Welcome. We deal in tools.` `objects.lua` now exposes these confirmed
  service interaction tiles directly, while keeping the generic adjacent raw
  large-tile inference for future service counters. Later Merchant 4 probing
  superseded the route target: `(24,25)` remains a blocked movement seam and
  `(25,26)` remains an alternate pocket; normal service routing should use the
  public `(23,25)` stand facing east.
- Weapon-shop item list follow-up: the buy/yes-no prompt worked, but the item
  list initially spoke field command labels and raw cursor coordinates because
  the shop list also shows a `COMMAND` header and reuses menu cursor RAM.
  `merchant.lua` now decodes the visible scrolled shop rows and prices, and
  `main.lua` suppresses command-menu speech whenever that merchant layout or
  lower shop dialogue is present. The merchant scan also keeps running while
  the shop prompt sets the generic dialogue hint, so the item reader does not
  starve after a buy/error/continue cycle. Live validation completed a Copper
  Sword not-enough-gold loop and returned to the list with `Bamboo Pole. 10
  gold.` instead of `STATUS` / `SEARCH`.
- Ctrl+W crash follow-up: the script crashed immediately after `Ctrl+W` with a
  fresh `dw_script_error.log` entry in `snapshot.update`; the fatal line was
  adapter logging through BizHawk `console.log()` while memory fallback was
  active. Adapter logging is now protected. A follow-up reload-window crash
  also showed temporarily unavailable BizHawk memory APIs, so the adapter now
  fails closed for unavailable reads/writes instead of crashing. The second
  live reload succeeded and speech reported ready.

## Initial Gameplay Pass Checklist

Use this as a lightweight first pass:
- Start or load a normal early-game state
- Confirm speech backend readiness with `speech_status`
- Confirm player state with `report_position` or `log_state`
- Navigate around the starting castle/interior without visual assumptions
- Interact with the king/throne-room objects if available
- Use stairs/doors/exits intentionally
- Visit the first town and interact with NPCs/shops if reachable
- In town, verify visited flags and Services/Treasure/Travel filter categories
- On the world map, select `Erdrick's Cave`, `Brecconary`, or `Tantegel
  Castle`, press `R` or run `route_guidance`, browse the small Travel route
  layer, verify `current_object` selects `Route next`, and verify
  `route_status` plus one route-progress announcement
- Enter a simple combat encounter and evaluate narration
- Record every point where the player would feel lost, under-informed, or unable to recover

## Open Gameplay Issues

### GP-002

Severity: Medium

Area: Command menu narration / map-position sensitivity

Status:
Resolved for the latest King/dialogue and command-menu opening reports. Keep
watching this area during normal play, but there is no active blocker at the
2026-05-05 wrap-up.

Description:
Manual testing found that in certain parts of the map, the command menu or
dialogue options do not read correctly. The latest scripted snapshots only saw
the status row (`menu_raw=false menu_active=false lower=""`), so the bug was
not present at capture time. `main.lua` now keeps command-menu scanning active
during current/recent player input even while BizHawk dialogue throttling is
active, but automated simulated A/B presses did not open the field menu in the
live session.

Next evidence to collect:
- Reproduce one bad command-menu read.
- Immediately capture `report_position`, `input_status`, and ideally
  `report_upper_dialogue_state` plus `report_movement_state:menu_bad_region`.
- Compare with a nearby position where the command menu reads correctly.
- Check whether the issue correlates with scroll/camera bytes, row-1 command
  menu parsing, or map-specific PPU layout.
- For King/dialogue silence specifically, the latest bad-state `Ctrl+D` dump
  contained no visible command/menu/dialogue text in raw PPU, and the live
  parser state also saw only status text with speech ready. The diagnostic
  samplers now clear BizHawk's PPU cache first; if the next dump is still blank
  while text is believed to be visible, treat it as a capture-timing or
  alternate-domain problem rather than a normal parser-row bug. The next
  `Ctrl+D` dump should include a `PPU source comparison` section to compare
  native `ppu.readbyte` with available nametable-like BizHawk memory domains.
- Follow-up resolved the source issue: native BizHawk `ppu.readbyte` was the
  blank source, while `CIRAM (nametables)` had the actual King question,
  `COMMAND`, and Yes/No/menu text. The compatibility layer now prefers that
  nametable memory domain. Live reload proof spoke the King question and
  `YES NO prompt. YES`; continue playtesting menu/dialogue normally from here.
- The remaining silent King farewell was a separate stale-base issue. The dump
  had the farewell text (`Goodbye now... Take care...`) in the nametable, but
  `PPUCTRL` reported `base_nt=0` while the text still required NT1-first screen
  order. The lower-dialogue reader now tries the alternate nametable order when
  it contains more lowercase dialogue. Retest on the next King save/continue
  flow; the final farewell should now speak.
- A follow-up confirmed the King dialogue path is working. Continue with normal
  command-menu playtesting.
- After a script restart, the command-menu opening debounce also passed the
  physical retest: the previous selection is no longer spoken before TALK.

### GP-001

Severity: High

Area: Emulator default / BizHawk performance

Status:
BizHawk swap accepted as successful enough to continue normal playtesting from
the BizHawk path. First clean early-game flow was confirmed manually on
2026-04-30, and basic manual testing on the first two maps after the conversion
found scripts behaving as expected. Remaining audio stutters or small narration
bugs should be handled as ordinary gameplay polish unless fresh logs show a new
large script spike.

Description:
BizHawk is now the default emulator path. It can launch the ROM and
accessibility script, and the script can speak through title/continue flow.
Early gameplay was initially super laggy once the game proper started, but the
current BizHawk-only throttles have substantially reduced scan load during the
king's boot dialogue.

Reproduction steps:
- Launch with `./launch_dw.sh`
- Continue an existing quest
- Wait until the game proper starts

Observed behavior:
- Title flow and speech work.
- Lag improves with compatibility-layer PPU caching and gameplay scan
  throttling.
- During the king's normal boot dialogue, current profiling shows only
  dialogue/yes-no scans running; command-menu, merchant, and object refresh
  scans are suppressed.
- Lag did not fully stop after king dialogue ended in the live script that was
  running before the latest state-detector patch.
- Spoken status summaries appearing inside king dialogue were caused by stray
  BizHawk keyboard hotkeys, not by dialogue parsing. BizHawk keyboard hotkeys
  are now disabled by default.
- The object explorer initially stopped working under BizHawk because the first
  hotkey gate blocked every keyboard shortcut. The current patch restores the
  default object/navigation hotkeys through `bizhawk_keyboard_hotkey_allowlist`.
  The `N` tile/coordinate diagnostic is also allowed for playtesting, while
  broader status/raw-dump diagnostics stay blocked.
- Pressing `N` then provided a clean audio-cutout repro: the spoken coordinate
  check was coupled to the full `tile_diag.txt` dump and could stall audio for
  about 1.5-2 seconds. The current patch keeps `N` to the compact spoken
  coordinate/tile summary by default; set `tile_diag_dump_on_hotkey=true` only
  for slow forensic dumps.
- A command-file `current_object` probe still returned an object description,
  so this was a keyboard-filter issue rather than an object-list failure.
- Normal play audio is now reported smooth, but route/path commands can still
  glitch emulator audio while processing. A live sample showed command/object
  refresh spikes rather than steady frame-loop lag: `debug_tools.tick
  max_ms=1931` and `objects.check_refresh max_ms=2068`.
- Dialogue is no longer lagging, but live testing showed it could speak before
  all new text arrived. The current patch clears BizHawk's PPU cache for
  dynamic dialogue scans so partially rendered cached text should not announce
  as stable.
- Object navigator caused an approximate two-second BizHawk freeze. The current
  patch makes BizHawk object descriptions skip reachability/path checks by
  default; explicit `pathfind` and `auto_walk` still do the heavier work.
- Object-browser hotkeys now explicitly request brief descriptions only:
  name/direction/count, without path reachability previews or raw coordinate
  debug suffixes. Explicit `O` pathfind and `U` auto-walk remain the route-work
  commands.
- After reloading with the latest object-refresh patch, broad lag is mostly
  under control. Object-list navigation still causes a small amount of lag, but
  profiling no longer shows script-side object/hotkey spikes.
- Rapid J/L object navigation now coalesces speech by default with
  `object_nav_speech_coalesce_frames=18`: selection changes immediately, but
  only the latest object description speaks after a short pause. K/current
  object still speaks immediately. The first 6-frame trial still flushed
  repeatedly during manual tapping, so this wider delay needs live BizHawk
  audio confirmation.
- The BizHawk audio config trial helped: with `SoundBufferSizeMs=200`,
  `SoundThrottle=true`, `FrameSkip=0`, and `Rewind.Enabled=false`, background
  window work no longer reproduced the previous audio glitching. One glitch
  occurred while focused in the emulator, but it has not reproduced.
- Wrap-up manual testing on 2026-04-30 covered the first two maps at a basic
  level. Apart from audio stuttering, script behavior matched expectations
  after the emulator conversion.
- Random emulator audio freezes were also observed, especially while working in
  other windows. This still needs correlation with `CMD_TIMING` and scan stats;
  if no script spike appears, treat it as a BizHawk/Windows focus or scheduling
  issue rather than the Lua loop.
- Normal movement/menu responsiveness after reloading the latest script still
  needs a fresh player-control check.
- Standing by the king on map `0x05`, auto-walk to the selected stairs returned
  "No path found". After the ROM-domain fix, live probes now show sane map
  dimensions and tile data: `(8,8)` is passable stair/corridor passthrough,
  while `(4,7)` is a closed magic-key door. The remaining no-path is normal
  locked-door route state, not a BizHawk ROM decode failure.

Expected behavior:
- Emulator remains responsive enough for normal play while the accessibility
  script runs.

Evidence:
- PPU caching improved title lag but not field lag enough.
- Current hypothesis is that field gameplay runs too many PPU-heavy scans each
  frame under BizHawk's slower Lua memory-domain APIs.
- A BizHawk-only scan-throttle patch has been added for title-state rescans,
  yes/no prompt scans, command/battle menu checks, merchant analysis, lower
  dialogue, and upper dialogue.
- Latest king-dialogue sample after boot-dialogue grace: `PPU_STATS
  reads=123840 cache_hits=108736 cache_misses=15104`; active scan profiles
  were lower dialogue, yes/no prompt, and upper dialogue only.
- Latest post-dialogue/player-control sample before the state patch:
  `state.check_for_changes calls=240 reads=0 ms=26984 avg_ms=112.433`. The
  source was the BizHawk path reading `$6003` every frame for sprite CHR/battle
  detection.
- Latest route/path command patch caches static object sources per map, adds
  `CMD_TIMING` logging for slow command handlers, and throttles repeated
  `CAN_WALK false` debug lines.
- Latest object/dialogue patch clears dynamic text PPU cache reads under
  BizHawk and adds `bizhawk_object_reachability_descriptions=false` so object
  navigator speech is quick by default.
- Latest post-dialogue object-list samples:
  `objects.check_refresh max_ms=1` for command-file object navigation, and a
  real-hotkey sample showed `hotkeys.update max_ms=1` plus
  `objects.check_refresh max_ms=1`. The earlier two-second object-refresh spike
  is no longer present with `bizhawk_periodic_npc_refresh=false`.
- The object-nav speech coalescer is covered by `test_hotkeys.lua`; tests cover
  delayed J/L speech, rapid-tap latest-only speech, K/current-object immediate
  speech, route-action clearing, and `object_nav_speech_coalesce_frames=0`.
- `emulator_compat.lua` now scores BizHawk ROM candidate domains/address
  mappings so headerless PRG-only ROM domains still emulate FCEUX
  `rom.readbyte()` offsets. New validation: `test_emulator_compat.lua` covers
  full iNES and headerless PRG domain layouts.
- Live follow-up on 2026-04-29 confirmed the map `0x05` stair path now decodes
  correctly under BizHawk: `inspect_tile:8,8` returned `dims=10x10`,
  `tile=15.0`, `reason=passthrough`, and `effective_passable=true`;
  `inspect_move:4,6,DOWN` returned `reason=door_closed` for `(4,7)`.
- Route messaging now detects a closed-door frontier on no-path plans and tells
  the player to get/use a magic key instead of only saying "No path found".
  Covered by `test_route_manager.lua`.
- Live playtesting after this still showed the door as closed after the player
  opened it. Root cause: BizHawk `memory.readbyte()` was still reading
  `$600C/$600D` opened-door slots through `mainmemory`, but DW1 stores those
  slots in cartridge work RAM. `emulator_compat.lua` now routes `$6000-$7FFF`
  reads through System Bus / PRG-RAM-style domains, and
  `test_emulator_compat.lua` plus `test_map_reader.lua` cover opened-door RAM.
- Manual retest after the cartridge-RAM fix confirmed the expected flow from
  game launch: open all throne-room chests, open the `(4,7)` door, and walk
  down the stairs into the castle proper.
- The same run showed auto-walk audio pain around blocked-step retries. Local
  config now uses `auto_step_timeout=45` and `auto_step_block_retry_limit=1`
  to shorten blocked-route retry windows.
- A 2026-05-05 fresh-game playtest found manual autostep feeling like native
  BizHawk movement: direction keys worked, but the player often had to hold
  until the game turned or stepped. Recent logs showed many 45-frame
  `auto_step timeout retry` paths, and the checked-in config had quick
  turn-only re-presses disabled. `auto_step_turn_repress_limit` is now `1`
  again so a tap that only turns gets one prompt follow-up press before the
  slower timeout retry path. Follow-up logs showed early subpixel changes could
  still mark a turn-in-place as movement started, suppressing that quick
  re-press until the timeout path; `auto_step.lua` now treats very early
  subpixel-only starts as eligible for the turn re-press too.
- The same fresh-game pass exposed stale object-browser NPCs after entering
  the second map from the throne room: old map `0x05` NPCs could remain
  selected on map `0x04` until routing hit a blocking live NPC and refreshed
  the list. Fresh Lua startup transitions cleanly; the repro returned only
  after touching `main.lua` for a BizHawk reload. The stale-state PPU dump did
  not show the prior wrong-source bug, so the fix is reload/transition-state
  based. The first signature patch fixed the current map after reload but not
  the next transition. The current patch keeps accepted NPC signatures in
  `_G.DW_OBJECTS_RELOAD_STATE`, observes the latest current-map NPC coordinate
  signature during normal gameplay frames, masks off direction/frame bits, and
  hides NPCs on map entry while RAM still matches the just-observed previous
  map. Retest by touching `main.lua`, waiting for reload to settle, using
  STAIRS between map `0x05` and `0x04`, and checking the NPC filter for the
  destination map's NPCs rather than the map just left. User retest confirmed
  the desired result after reload: 4 NPCs on map `0x05`, and 20 NPCs on map
  `0x04`.
- A later 2026-04-30 first-town manual run reported that route/path commands
  still caused lag, name-entry clicks could double-enter letters, and movement
  could overshoot cells. The live `dw_debug.log` did not contain `CMD_TIMING`
  or scan-profile spikes for the hotkey-triggered `O`/`U` work, so route-plan
  timing is now logged separately as `ROUTE_PLAN_TIMING`.
- The same log showed a concrete queued auto-walk overshoot pattern: after a
  south step to `(1,4)`, the next queued `right` step completed at `(1,5)`
  while the planned seam was `(2,4)`; after a right segment to `(3,5)`, the
  next queued `down` completed at `(4,5)` while the planned seam was `(3,6)`.
  `auto_step_route_turn_settle_frames=16` now pauses queued routes before
  changing direction, while straight segments can still chain quickly.
- Chosen-path summaries remain in the log, but tile-by-tile chosen-path dumps
  are now opt-in with `pathfind_log_steps=true` because the detailed dump is
  slow and noisy during ordinary playtesting.
- Focused wrap-up validation after making `N` cheap and object browsing brief
  passed `luac -p hotkeys.lua objects.lua route_manager.lua config.lua
  test_hotkeys.lua`, `lua test_hotkeys.lua`, `lua test_route_manager.lua`,
  `lua test_objects.lua`, and `git diff --check`.
- Route-turn follow-up validation passed `luac -p auto_step.lua pathfinder.lua
  route_manager.lua config.lua test_auto_step.lua`, `lua test_auto_step.lua`,
  `lua test_route_manager.lua`, `lua test_pathfinder.lua`, and
  `git diff --check`. `test_pathfinder.lua` still prints the known WSL
  Tolk/`cmd` warning before passing.
- A follow-up live log after reloading showed the queued route turn-settle
  working for a 2-step route, but also exposed the remaining autowalk lag as
  route planning: `ROUTE_PLAN_TIMING map=0x08 start=(0,15) target_id=npc_15 ...
  path_len=2 ms=1978.000`. `pathfinder.lua` now prunes adjacent candidates that
  cannot beat the current shortest landing path and defers reachable-area
  diagnostics unless needed for an equal-length tie or no-path evidence.
- The same run's quickload/town object issue matched a two-phase object refresh:
  static objects were available first, while NPCs were deferred until a later
  refresh. Under BizHawk scan throttling that delay could leave only "Exit to
  World Map" in Brecconary briefly. `objects.needs_refresh(map_id)` now lets
  map-entry and deferred NPC refreshes bypass the periodic 120-frame throttle.
- Route-planning/object-refresh validation passed `luac -p pathfinder.lua
  objects.lua main.lua test_pathfinder.lua test_objects.lua`,
  `lua test_pathfinder.lua`, `lua test_objects.lua`, `lua test_route_manager.lua`,
  `lua test_map_survey.lua`, `lua test_auto_step.lua`, and `git diff --check`.
- Live retest after script reload confirmed the object list populated quickly,
  but auto-walk still choked and then cancelled for path drift. The log showed
  `ROUTE_PLAN_TIMING map=0x08 start=(0,15) target_id=npc_4 ... path_len=13
  ms=1836.000`, followed by drift during turn-settle: after reaching `(4,14)`
  and preparing to turn up, the player slid to `(5,14)` and the route cancelled
  with `route_drift_off_path`.
- `auto_step.lua` now actively neutralizes the D-pad during route-settle frames,
  not just the first post-step release frames. `pathfinder.lua` now uses a
  per-plan walkability snapshot from `map_reader.lua`, with a fallback per-search
  cache, so A* does not repeatedly call the slower map-reader walkability path.
- Latest live retest showed auto-walk lag is reduced but still audible, and
  `O` show-path lags too. The log showed auto-walk route plans at `path_len=13
  ms=1852.000` and `path_len=10 ms=1238.000`; show-path route previews logged
  `path_len=7 ms=1422.000` and `path_len=1 ms=1514.000`. Because the 1-step
  preview still lagged, the likely culprit is fixed route-command overhead,
  especially forced live NPC refresh/freezing under BizHawk.
- BizHawk now skips forced live NPC refresh before `O`/`U` route plans by
  default (`bizhawk_route_refresh_npcs=false`) and skips auto-walk's NPC RAM
  freeze by default (`bizhawk_autowalk_freeze_npcs=false`). FCEUX keeps the
  previous behavior, and both BizHawk options can be turned back on for a
  blocker/NPC-specific investigation.
- The same log still showed route drift: after a first `right` step from
  `(0,15)` to `(1,15)`, settle before a planned `up` drifted to `(2,15)`; after
  a right segment from `(6,16)` to `(7,16)`, settle before a planned `up`
  drifted to `(8,16)`. `auto_step.lua` now actively releases route-owned D-pad
  input after the inject window as well as during turn-settle frames.
- Latest route-lag/drift validation passed `luac -p auto_step.lua
  route_manager.lua config.lua pathfinder.lua map_reader.lua objects.lua
  main.lua test_auto_step.lua test_route_manager.lua test_pathfinder.lua
  test_map_reader.lua test_objects.lua test_map_survey.lua`,
  `lua test_auto_step.lua`, `lua test_route_manager.lua`,
  `lua test_pathfinder.lua`, `lua test_map_reader.lua`,
  `lua test_objects.lua`, `lua test_map_survey.lua`, and `git diff --check`.
- 2026-04-30 follow-up from quick slot 1 in Brecconary: warming the current map
  grid during map-entry object refresh removed the first usable `O` /
  `auto_walk` route spike to Person 2; the prior cold route was about
  1.7-1.9 seconds. 2026-05-05 live castle play then showed that moving the cost
  to map entry made transitions hitch under BizHawk (`objects.check_refresh
  max_ms=1846`), so BizHawk now skips map-entry grid prewarm by default and
  builds the grid lazily on first route/path use. FCEUX keeps prewarming, and
  BizHawk can opt in with `bizhawk_map_entry_prewarm_path_grid=true`.
- The same live route reached the intended adjacent tile `(10,15)` and ended
  with neutral input. The old turn-settle drift signatures did not reappear.
  There is still a smaller executor issue: the first facing/step from the town
  entrance can consume one timeout/brute-force retry before walking succeeds.
- If audio still cuts out shortly after quickload or map entry, first inspect
  `objects.check_refresh max_ms` and whether it coincides with lazy first-route
  path-grid work before moving any cost back onto the transition frame.
- Latest user retest: manual walking overshoot is much better, with remaining
  overshoot mostly when several movement presses are entered rapidly. Auto-walk
  audio is improved, but a lag spike still happened near the end of route
  attempts. Fresh logs showed the latest route reached the intended adjacent
  tile `(15,19)` with neutral input and no runtime blockers; the suspicious
  spike is `objects.check_refresh max_ms=1658` from route cleanup. BizHawk now
  skips the immediate post-route object refresh by default with
  `bizhawk_route_cleanup_refresh_objects=false`.
- Live validation after reloading the patch completed two Brecconary auto-walks:
  Person 4 from `(0,15)` to `(1,14)`, then Person 2 from `(1,14)` to `(9,14)`.
  Both ended adjacent to the target with neutral input and no runtime blockers.
  Around the longer 10-step route, `objects.check_refresh max_ms=0`,
  `debug_tools.tick max_ms=3`, and `auto_step.update max_ms=1`.
- User hands-on retest after that patch confirmed auto-walk is behaving much
  better, reaching intended targets, and the lag seems under control.
- King dialogue follow-up: the main King greeting now reads in correct screen
  order, but the Yes/No prompts initially repeated the tail of the previous
  dialogue page before the question. The worktree now strips that overlap so
  the save prompt should speak just `Will thou tell me now...` and the continue
  prompt should speak just `Dost thou wish to continue thy quest?` before
  `YES NO prompt`.
- Latest lag check: BizHawk's config is already on the safer audio/throttle
  baseline. The latest scan stats instead point at script-side spikes,
  especially object refresh and route/movement work. For the next lag repro,
  use `reset_scan_stats`, perform one action, then `report_scan_stats` before
  changing emulator timing settings.
- Reload/menu silence follow-up: after reload near the King, speech backend
  diagnostics were healthy but the command-menu scanner saw no menu at
  `scroll_tiles=22 base_nt=1`. The worktree now scans both nametable wrap
  orders for command-menu and Yes/No UI text. Retest physically by opening the
  command menu and using TALK near the King; automated debug A input still does
  not reproduce a real menu open here.
- The first PPU dump for the remaining silence did not include an active menu
  or dialogue page and only covered lower rows. `Ctrl+D` now writes a full
  0-29-row PPU dump with decoded NT0/NT1 wrap orders and parser match hints.
  If silence remains, capture `Ctrl+D` while the menu or dialogue is actually
  visible, or use `report_menu_state` while holding the bad state.
- Main-menu erase/name-entry follow-up: the latest live log showed the erase
  confirmation being treated as `field` on map `0x00`, causing extra dialogue,
  bogus auto-step block logs, and the false "Game started" / "Unknown Map 0"
  path. `state.lua` now keeps erase confirmation and name entry in title state,
  and `main.lua` now suppresses repeated A frames on name entry until a short
  stable release. `report_title_state` can log the visible title rows and
  selected name-grid cell if the issue needs another capture after reload.
- The next input check found that `S` is BizHawk's NES `P1 A` autofire binding,
  while normal A is `X`. Retest name entry and erase confirmation with `X`, not
  `S`; the map announcement after erase likely came from an extra autofire
  confirm into real gameplay.
- Mod hotkeys were regrouped to avoid BizHawk controls: common object actions
  stay on bare keys (`J/K/L/O/U/Q`), info commands use `Shift+key`, diagnostics
  use `Ctrl+key`, freeze NPCs is `Shift+F`, and tile diagnostics is `Ctrl+N`.
- King dialogue regression: after the hotkey/menu fixes, the king's lower
  dialogue was present (`lower_len=97`) but not automatically read because
  `in_gameplay` stayed false after the title-to-field debounce. `main.lua` now
  clears that debounce after "Game started."; the next live log confirmed king
  and NPC dialogue auto-read again.
- Command menu and post-dialogue status polish: command-menu openings now speak
  the highlighted item immediately, such as `Command. TALK`, instead of only
  saying `Command.`. The lower dialogue reader now skips persistent status rows
  like `Bill LV 1 HP 15 MP 0 G 120 E 0`, including hero names with lowercase
  letters, so the status line should not speak after dialogue dismissal.
- Follow-up log evidence showed the remaining status-line speech was coming
  from the upper dialogue reader, not the lower one: `report_upper_dialogue_state`
  showed `upper="Bill LV ..."` and `lower_len=0`. The upper reader now suppresses
  extracted `new_text` fragments that are themselves status text and logs
  `UPPER_DIALOGUE_SUPPRESS_STATUS` when that path is caught.
- BizHawk launchers now support `--state-slot N`; quick slot 1 can be loaded
  with `./launch_dw.sh --state-slot 1` or `./launch_bizhawk.sh --state-slot 1`.
- 2026-05-01 quick live map `0x05` route cycle: from throne-room `(3,4)`,
  object enumeration found 9 objects and the door/stairs data still looked sane
  (`inspect_tile:4,7` = `door_closed`, `inspect_tile:8,8` = `passthrough`).
  Auto-walk reached a nearby chest and then Guard 3. The Guard 3 route first
  logged `NEW BLOCK` for `(4,4)` down into `(4,5)`, but a controlled
  `probe_edge:DOWN` from `(4,4)` moved successfully, changing the seam evidence
  to noisy/transient rather than a confirmed map blocker.
- The same cycle found player-facing hitch risk in debug commands, not focused
  route execution: `report_path_state`, `inspect_move`, explicit
  `pathfind_adjacent`, and `probe_edge` all produced roughly 1-1.7 second
  `CMD_TIMING` lines. The focused Guard 3 auto-walk window itself reported
  `objects.check_refresh max_ms=0`, `auto_step.update max_ms=1`, and
  `debug_tools.tick max_ms=2`.
- 2026-05-05 crash during live play: `dw_debug.log` reset to a bare header and
  `dw_script_error.log` showed `snapshot.update: 69` from BizHawk
  `mainmemory.read_u8` during `game_snapshot.update`. The memory adapter now
  catches direct RAM API errors and falls back to `System Bus`, but because the
  script was already dead, this still needs a manual BizHawk script reload or
  emulator relaunch before gameplay retest.
- 2026-05-05 King dialogue glitch: the line was spoken as
  `greatly pleased 'I am thou hast that rned, Bill. retu`. Logs confirmed the
  same scrambled string in `EVENT: dialogue`, so the speech backend was not at
  fault. The fix teaches the PPU text reader to assemble rows in visible screen
  order using horizontal scroll plus the active nametable bit. Retest after a
  manual script reload: TALK to the King should read the sentence in normal
  order, starting with `I am greatly pleased...`.
- 2026-05-09 B1 auto-walk timing follow-up: the noisy return-route reroutes
  were partly false route-executor timeouts caused by early movement-subpixel
  twitches, not new engine blockers. After the autowalk timing patch, a clean
  live B1 pass from entrance to stairs reached `(9,9)` with only the known
  `(6,3).west` direct-retry failure, and the return route reached `(0,0)`
  without blocked events or runtime blockers.

Recommended next step:
- The narrow Brecconary exit target is now clean after the autostep timing
  patch. A full parked-NPC object survey from `(15,15)` is the next useful
  confidence check before moving on to broader playtesting.
- Continue real early-game playtesting from the BizHawk path. Good next targets
  are combat narration, shops/inns, item/spell flows, and any remaining menu or
  dialogue polish that shows up naturally. If the post-dialogue status row
  appears again, check for `UPPER_DIALOGUE_SUPPRESS_STATUS` and
  `report_upper_dialogue_state` before changing the dialogue parser again.
- Future Erdrick's Cave B2 polish task: revisit the chest-to-stairs return route
  from chest-adjacent `(8,3)` to B2 stairs `(8,9)` when pathfinding cleanup is
  back in scope. Use direct verifiers/probes on the return-trip bounce
  candidates before changing permanent map data; the current route is playable
  and should not block the pivot to combat/dialogue work.
- While testing object navigation, rapidly tap J/L and listen for reduced audio
  hitching. Use K to speak the current selection immediately. If the short delay
  feels worse than the old behavior, set `object_nav_speech_coalesce_frames=0`
  in `dw_access.ini` and reload the script.
- Keep the current BizHawk audio trial settings for now. Apply future config
  patches while EmuHawk is closed; live edits can be overwritten when the
  emulator exits.
- Good next experiments: tune BizHawk audio buffer/throttle settings, then
  compare one clean repro at a time with `reset_scan_stats` /
  `report_scan_stats`, fresh `CMD_TIMING` lines, and fresh
  `ROUTE_PLAN_TIMING` lines.
- Retest manual movement overshoot in normal play. The route executor now
  clears injected D-pad after movement starts, but manual cell-jumping still
  needs the user's hands-on confirmation.
- Retest auto-walk from quick slot 1 without pressing it immediately after
  launch. Use `current_object` first; if it says "No objects found", wait for
  the deferred object refresh, then select the target and try `O` / `U`.
- If auto-walk still feels choppy after objects are populated, capture
  `reset_scan_stats`, exactly one `auto_walk`, then `report_scan_stats`. A
  fresh `objects.check_refresh max_ms=...` line matters most if the hitch
  happens at route completion/cancel; `ROUTE_PLAN_TIMING` still matters if the
  hitch happens before movement starts.
- If the throne-room `(4,4)->(4,5)` route block appears again, do not promote it
  to map data from a single auto-walk. Reprobe with `probe_edge:DOWN` from
  `(4,4)` and compare against the latest noisy evidence.

When adding issues, use this format:
- ID
- Severity
- Area
- Description
- Reproduction steps
- Observed behavior
- Expected behavior
- Evidence or relevant log lines

## Useful Commands

State and speech:
- `speech_status`
- `log_state`
- `report_position`
- `current_object`
- `reset_scan_stats`
- `report_scan_stats`

Object navigation:
- `next_object`
- `prev_object`
- `next_filter`
- `pathability_filter`
- `pathfind_adjacent:X,Y`
- `auto_walk`

Path/debug recovery:
- `report_path_state`
- `inspect_tile:X,Y`
- `inspect_move:DIR`
- `report_runtime_blocks`
