# Kol Map And Route Reference

Fetched: 2026-05-15

## Local Images

- `external/mikesrpgcenter_kol.png`
  - Source page: https://mikesrpgcenter.com/dw1/maps/kol.html
  - Source image: https://mikesrpgcenter.com/dw1/maps/kol.png
  - PNG, 384x384 pixels
- `external/realmofdarkness_kol.png`
  - Source page: https://www.realmofdarkness.net/dq/nes-dw-kol/
  - Source image: https://www.realmofdarkness.net/dq/wp-content/img/nes/dw/maps/kol-3.png
  - PNG, 452x714 pixels
- `external/vgmaps_kol.png`
  - Source image: https://vgmaps.com/Atlas/NES/DragonWarrior-Kol.png
  - PNG, 452x714 pixels
  - Current downloaded bytes match `realmofdarkness_kol.png`; keep as a
    source cross-check, not separate map evidence.

Use these as visual orientation references only. Live movement probes,
`survey_map`, and `map_reader.lua` remain the source of truth for passability,
hidden seams, locked doors, and service interaction tiles.

## Service Guide Transcription

Cross-check sources:

- Mike's RPG Center Kol map: https://mikesrpgcenter.com/dw1/maps/kol.html
- Mike's RPG Center walkthrough: https://mikesrpgcenter.com/dw1/walkthrough.html
- Realm of Darkness Kol page: https://www.realmofdarkness.net/dq/nes-dw-kol/
- Gamer Corner Kol location: https://guides.gamercorner.net/dw/locations/kol
- Gamer Corner Kol walkthrough: https://guides.gamercorner.net/dw/walkthrough/kol
- StrategyWiki Northeast Alefgard: https://strategywiki.org/wiki/Dragon_Warrior/Northeast_Alefgard
- NESMaps labeled overworld map: https://nesmaps.com/maps/DragonWarrior/DragonWarriorOverworldMap.html

Known Kol services and points of interest:

- Inn: 20 G. Map images place it in the northeast building.
- Weapon/armor shop:
  - Copper Sword, 180 G
  - Hand Axe, 560 G
  - Half Plate, 1000 G
  - Full Plate, 3000 G
  - Small Shield, 90 G
- Item/tool shop:
  - Herb, 24 G
  - Torch, 8 G
  - Dragon's Scale, 20 G
  - Wings / Wyvern Wings, 70 G
- Hidden treasure: Fairy Flute. Guides agree it is found by searching four
  steps south of the bath.
- Locked doors: Gamer Corner lists two. One is on the west side of town and is
  not needed; one is in the western building.
- Progression notes: Kol is a useful base around level 5-6, the inn is cheap,
  Wings become accessible here, and the Fairy Flute is needed later against
  the Golem at Cantlin.

## Service Survey Targets

When the player runs the Kol survey, use the results to prove these before
patching `objects.lua`:

- Confirm the live entry/exit coordinates. First proof showed that arriving
  from the world map lands at `(19,23)`, and moving south from `(19,23)` exits
  town. The old hardcoded Kol exit `(15,14)` was stale; `objects.lua` now uses
  `(19,23)` facing south as the Travel exit.
- Identify the live NPC slots and coordinates for the inn, weapon/armor shop,
  and item/tool shop.
- For each service, confirm the public stand tile and facing direction by
  opening the actual inn or shop prompt, then add service interaction overrides.
- Hidden Fairy Flute coordinates are now decoded enough for object browsing.
  Mike's 24x24 Kol map has a single bath/water tile at `(9,2)`; the guide
  clue "four steps south of the bath" therefore points to `(9,6)`. Live
  `inspect_tile:9,6` reported it walkable, and `debug_pathfind_to:9,6` from
  `(1,22)` found a route. `objects.lua` exposes `(9,6)` as `Fairy Flute Search
  Tile` internally, but the player-facing Treasure label is `Disturbed Earth
  Near Bath` so the reward is not spoiled before SEARCH succeeds.
- Add locked-door objects only after live door coordinates are confirmed.

## First Survey Evidence

Archived pre-reload log:

- `handoff_archive/dw_debug_2026-05-15_kol_service_survey_pre_reload.log`
- `handoff_archive/dw_debug_2026-05-15_kol_merchant1_bounce_pre_reload.log`
- `handoff_archive/dw_debug_2026-05-15_kol_merchant1_inner_bounce_pre_reload.log`
- `handoff_archive/dw_debug_2026-05-15_kol_post_stop_autowalk_blockers.log`
- `handoff_archive/dw_debug_2026-05-15_kol_bath_flute_oldmen_pre_patch.log`

Live findings from the stopped survey:

- Initial `survey_objects:park_npcs` from `(19,23)` and `(20,23)` aborted as
  isolated because both bottom-edge entry tiles ROM-decode as type-0 walls.
  Manual movement then proved `(19,22)->DOWN` enters `(19,23)`,
  `(19,23)->DOWN` exits to the world map, and `(19,23)->RIGHT` enters
  `(20,23)`. A later object pathability-filter repro from live `(18,23)`
  showed that west neighbor is also part of the false-wall entrance strip.
  `map_reader.lua` now treats `(18,23)`, `(19,23)`, and `(20,23)` as map-0x07
  passthrough cells.
- A survey from `(20,21)` targeted `Person 1` and looped at `(20,18)` between
  north into `(20,17)` and east into `(21,18)`. The stopped run logged
  `blocked=51 moved=0` for `(20,17)` from the south and `blocked=50 moved=0`
  for `(21,18)` from the west. `map_reader.lua` now models these as
  directional blockers: `(20,17).south` and `(21,18).west`.
- Nearby seams from the same run stayed open/noisy rather than blocked:
  `(20,18)`, `(20,19)`, `(20,21)`, `(19,22)`, `(20,22)`, `(21,22)`,
  `(19,23)`, and `(20,23)` all had live moved evidence. Do not promote those
  to blockers from this run.
- After the service pass exposed more NPCs, the route to `Old Man 1` at object
  `(2,13)` looped between `(8,11)` and `(8,12)`. The archived log
  `handoff_archive/dw_debug_2026-05-15_kol_west_npc_loop_pre_patch.log` shows
  repeated blocked-only attempts entering `(7,11)` and `(7,12)` from the east.
  `map_reader.lua` models `(7,11).east` and `(7,12).east` only; the vertical
  connector between `(8,11)` and `(8,12)` moved repeatedly and stays open.
- `report_survey_findings` after stopping reported no strong reroute
  candidates because the run was manually stopped, but the repeated seam list
  gives enough evidence for the two narrow directional blockers above.

## Bath And Clue NPCs

- `Woman 2` is the bath clue NPC. Live route evidence targeted `npc_11` at
  `(12,1)`, used public stand `(12,2)` facing north, and TALK read "This bath
  cures rheumatism."
- Local image analysis of `external/mikesrpgcenter_kol.png` found only one
  blue bath/water tile: `(9,2)`. The hidden search tile is modeled at `(9,6)`,
  four steps south, and is labeled `Disturbed Earth Near Bath` in Treasure.
  The user found the flute there live after this coordinate was added.
- `Old Man 1` is the flute clue NPC. Live TALK after selected teleport to
  `npc_3` read "Hast thou found the flute? Howard had it, but he went to
  Rimuldar and never returned." Current NPC RAM later placed him at `(2,13)`;
  `debug_pathfind_adjacent:2,13` from `(1,22)` found a stand at `(3,13)`
  facing west.
- `Old Man 4` is the better-weapons clue NPC at `(1,1)`. Live TALK read that
  Bill cannot defeat the Dragonlord with current weapons and should come back
  again. `debug_pathfind_adjacent:1,1` from `(1,22)` now chooses stand `(1,2)`
  facing north. The earlier row-2 route loop proved directional blockers
  `(9,2).east`, `(2,1).east`, and `(2,2).east`; those are modeled in
  `map_reader.lua` without closing the neighboring cells wholesale.
- The guide note about a cellar west of Kol refers to the overworld
  `Northern Cave` / `Rain Shrine`, not a Kol town basement. The staged route
  starts from world-map Kol `(104,10)` and targets the existing
  `overworld_northern_cave` landmark at `(81,1)`. First live testing reached
  the east-shore pocket around `(91,5)`, where the old short approach tried to
  go west/north across a water/mountain gap. The current staged route should
  recover by heading south around that bay before crossing back toward the
  cave; final entry at `(81,1)` still needs live validation.

Follow-up Merchant 1 autowalk evidence:

- After reloading the script, `auto_walk` to Merchant 1 from the town entrance
  queued a route to the service NPC at `(8,19)` but bounced between `(11,18)`
  and `(11,19)`. Movement left into `(10,18)` from the east repeatedly blocked
  and reached `blocked=38 moved=0`; movement left into `(10,19)` from the east
  reached `blocked=36 moved=0`.
- Nearby seams from the same bounce should stay usable: `(11,18)` from the
  south was passable-only, `(11,19)` from the north was noisy but moved, and
  the earlier approach into the x=11 lane had moved evidence. `map_reader.lua`
  now models only `(10,18).east` and `(10,19).east`.
- A later clean reload and retest promoted `(12,19).west`: it was no longer
  only manual noise, because the queued Merchant 1 route reproduced it six
  times with no moved observations. The same route also proved `(11,20).north`
  with seven blocked observations.
- The second Merchant 1 run advanced from `(21,21)` into the inner west
  approach, then discovered a band of counter/building seams before looping at
  `(8,15)`. The lower-count seams are now modeled as directional-only route
  evidence: `(16,21).east`, `(16,20).east`, `(16,19).east`, `(10,16).east`,
  `(10,16).north`, and `(9,16).north`. The final hard loop reached
  `blocked=46 moved=0` for `(7,15).east` and `blocked=47 moved=0` for
  `(8,16).north` before a small right tap broke the active route and moved the
  hero to `(9,15)`.
- The right tap used to break the loop logged `(9,15).west` as passable. Treat
  that as a manual escape/cancel action, not a service-route target.
- A later retest started from `(9,15)` and confirmed the `stop_auto_walk`
  command works: it released NPC freeze and stopped the route without extra
  movement input. The route target was still Merchant 1, with adjacent goal
  `(11,21)`, and it looped between `(12,18)` and `(13,18)`. The strong new
  blockers are `(12,19).north` with `blocked=18 moved=0` and `(13,19).north`
  with `blocked=22 moved=0`. The same run also produced clean queued-step plus
  seam-retry pairs for `(15,19).north`, `(14,19).north`, and
  `(16,19).north`; these are modeled as directional-only route evidence.
  Noisy seams `(15,16).west` and `(17,21).east` both had moved evidence and
  should stay open. Later Merchant 4 path testing disproved the stale
  `(16,22).east` candidate, so the `(16,22)<->(17,22)` seam stays open both
  ways.
- After that blocker batch was live, a read-only path preview from `(12,18)`
  to adjacent goal `(11,21)` returned `No path found`, and
  `debug_pathfind_adjacent_skip_npcs:11,21` also returned no path. The current
  Merchant 1 target appears geometrically isolated/counter-side rather than
  blocked by live NPC traffic.
- The user then selected/teleported to `npc_7` / `Merchant 1` and TALK proved
  him as an information NPC: `Hast thou been to the southern island?` followed
  by the Rimuldar hint. `objects.lua` now keeps Kol `Merchant 1` browsable
  under NPCs but excludes him from Services. A sequential `report_door_state`
  at player position `(12,21)` reported `keys=0` and all opened-door RAM slots
  as `(0,0)`, so no live door coordinate has been confirmed from this contact
  yet.
- The user verified `npc_12` / `Merchant 2` as the inn keeper. Selected
  teleport landed at the public stand `(19,2)`, facing south toward the target
  at `(19,4)`, and TALK opened the 20 GOLD inn prompt. `objects.lua` now labels
  this service as `Inn` and pins the interaction stand/facing.
- Autowalk from the Inn stand back to the town entrance/exits looped along row
  2. It repeatedly moved horizontally between `(21,2)` and `(22,2)` while
  trying to enter `(21,3)` and `(22,3)` from the north. Before
  `stop_auto_walk`, `(21,3).north` reached `blocked=36 moved=0` and
  `(22,3).north` reached `blocked=34 moved=0`; both are now modeled as
  directional blockers. Row-2 horizontal seams had moved evidence and stay open.
- After reload, the next Inn-to-exit retest advanced to the east wall. It
  alternated between `(22,1)` and `(22,2)`, repeatedly trying to enter
  `(23,1)` and `(23,2)` from the west. Before `stop_auto_walk`,
  `(23,1).west` reached `blocked=17 moved=0` and `(23,2).west` reached
  `blocked=18 moved=0`; both are now modeled as directional blockers. The
  `(22,1)<->(22,2)` vertical seam and row-2 approaches into `(20,2)`,
  `(21,2)`, and `(22,2)` had moved evidence and stay open.
- The next Inn-to-exit pass drifted one tile west during turn settle, logged
  `AUTO_WALK_DRIFT_REROUTE` from `(10,2)`, then recovered into a stable loop
  from `(10,3)`. The first `(10,3).north` observation moved on brute-force
  retry and is not modeled. The repeated blocker pair was `(10,4).north` and
  `(11,3).west`; before `stop_auto_walk`, `(10,4).north` reached
  `blocked=19 moved=0` and `(11,3).west` reached `blocked=18 moved=0`.
  Current live position after stop/probe was `(10,3)`, with runtime blockers
  still reporting none.
- After reload, Inn-to-exit completed, but the return route from town entrance
  back to Inn got close and looped at the northeast approach. The preserved
  evidence log is
  `handoff_archive/dw_debug_2026-05-15_kol_inn_return_loop_pre_patch.log`.
  Final strong blockers were `(21,3).south blocked=20 moved=0` and
  `(22,3).south blocked=20 moved=0`, so both are now modeled. The row-4 side
  seams were noisy but repeatedly moved: `(21,4).east blocked=1 moved=10` and
  `(22,4).west blocked=2 moved=10`, so they stay open. Earlier low-count
  recovered blockers from the same run, including `(11,3).north`,
  `(19,17).south`, `(18,17).south`, `(18,5).south`, `(19,5).south`, and
  `(20,5).south`, remain diagnostic only.
- After another reload, the entrance-to-Inn retest started at `(21,4)`, queued
  8 steps for Inn, and looped across row 4. The preserved evidence log is
  `handoff_archive/dw_debug_2026-05-15_kol_entrance_to_inn_loop_pre_patch.log`.
  Final strong blockers were `(23,3).south blocked=36 moved=0` and
  `(20,4).east blocked=36 moved=0`, so both are now modeled. Row-4 connector
  movement stays open: `(21,4).east moved=18`, `(22,4).east moved=18`,
  `(22,4).west blocked=3 moved=19` noisy, and `(23,4).west moved=19`.
  `stop_auto_walk` left the hero at `(23,4)`, with runtime blockers reporting
  none.
- The next entrance-to-Inn retest started from `(23,4)`, queued 24 steps for
  Inn, worked through low-count row-5 obstacles, and looped farther west around
  `(11,5)`, `(12,5)`, and `(12,4)`. The preserved evidence log is
  `handoff_archive/dw_debug_2026-05-15_kol_entrance_to_inn_loop2_pre_patch.log`.
  Final strong blockers were `(11,4).south blocked=18 moved=0` and
  `(11,4).east blocked=19 moved=0`, so both are now modeled. Nearby connector
  seams stay open: `(11,5).east moved=9`, `(12,4).south moved=9`,
  `(12,5).north moved=9`, and `(12,5).west moved=9`. Earlier low-count row-5
  blockers from this run, including `(18,5).south`, `(19,5).south`,
  `(20,5).east`, and `(20,5).south`, reached only two blocks and were bypassed,
  so they remain diagnostic only.
- The first full working but noisy round trip is preserved at
  `handoff_archive/dw_debug_2026-05-15_kol_inn_roundtrip_noisy_success.log`.
  It reached Inn, Exit to World Map, then Inn again. Manual cleanup promoted
  `(10,4).south blocked=4 moved=0` and `(9,2).south blocked=4 moved=0` from the
  success log, plus repeated low-count reroute seams `(11,3).north`,
  `(19,17).south`, and `(18,17).south` that also appeared in earlier return
  evidence. The same pass kept noisy/moved seams open: `(10,3).west blocked=2
  moved=2`, `(18,18).east blocked=1 moved=1`, and row-5 two-block bypasses.
- The user live-confirmed `npc_13` / Merchant 3 as the weapon/armor shop. The
  selected teleport proof targeted `(22,12)`, landed at `(20,12)`, and faced
  east. TALK opened the buy list, and the reader spoke: Copper Sword 180 G,
  Hand Axe 560 G, Half Plate 1000 G, Full Plate 3000 G, and Small Shield 90 G.
  `objects.lua` now labels this service as `Weapons Merchant` and pins the
  public stand/facing.
- The user live-confirmed `npc_15` / Merchant 4 as the item/tool shop. The
  selected teleport proof targeted `(14,21)`, landed at `(12,21)`, and faced
  east. TALK opened the buy list, and the reader spoke: Herb 24 G, Torch 8 G,
  Dragon's Scale 20 G, and Wings 70 G. `objects.lua` currently labels this
  service as `Tool Merchant` through `(12,21)` facing east. Public-route
  cleanup first ruled out the east-side lane: route checks could not reach
  `(12,21)`, `(15,21)`, `(14,22)`, or `(16,21)`, TALK from `(17,22)` /
  `(17,21)` facing west returned "There is no one there," and door checks from
  `(17,21)` / `(17,22)` facing west produced no-door/no-key-delta results.
  The missing public throat was then found west of the shop route: manual
  movement from `(1,16)->DOWN` reaches `(1,17)` even though `(1,17)` decodes
  as tile-0/non-walkable. Once standing on `(1,17)`, the route to `(12,21)`
  returns. A later clean-restore frontier check from the town entrance found
  the entrance-side connector to that throat: `(5,14)` decodes as tile-0, but
  normal walking to `(5,13)` and same-origin `probe_edge:DOWN` moved through
  `(5,14)` and settled at `(5,15)`. `map_reader.lua` now exposes only
  `(1,17)` and `(5,14)` as Kol passthroughs; sibling candidates `(6,14)` and
  `(7,14)` stay unmodeled until live proof. The follow-up reload proved
  `(1,19)` is a standable dead pocket rather than a route segment:
  `(1,19)->RIGHT`, `(1,19)->DOWN`, and `(1,19)->UP` all blocked from
  same-origin probes, while west is the map boundary. Final entrance-to-stand
  cleanup found the real lower bridge: from a normally walked `(3,15)`,
  `probe_edge:DOWN` carried through `(3,16)` onto tile-0 `(3,17)`, and
  `(3,17)->DOWN` exited to the target-side lane. The false pocket exits
  `(5,15)->DOWN`, `(3,15)->LEFT`, `(3,16)->LEFT`, `(3,15)->UP`, and the final
  `(9,19)->RIGHT` shortcut into `(10,19)` are now directional blockers. With
  those runtime blockers active, live `auto_walk_blocker:12,21` reached the
  stand. A follow-up return-route cleanup from stand `(12,21)` to the town
  exit `(19,23)` promoted the remaining public-route false edges around
  `(4,16)/(4,18)`, `(4,20)..(4,23)`, `(10,18)`, `(10,20)..(10,22)`,
  `(11,20)/(11,22)`, `(12,20)/(12,22)`, `(13,21)`, `(7,15)`, `(2,19)`,
  and the north wall of row 23 at x `5..9`. With that runtime overlay active,
  `auto_walk_blocker:19,23` reached the exit and the reverse
  `auto_walk_blocker:12,21` reached the stand. Reload `main.lua` in FCEUX
  before validating the live planner against these fixes.

NPC/service slot snapshot after the stopped survey:

- `npc_0` / Person 1: `(23,16)` after NPC restore; survey target had been
  recorded at `(20,16)`.
- `npc_7` / Merchant 1: `(8,19)`, dialogue-only Rimuldar hint NPC; excluded
  from Services after TALK proof.
- `npc_12` / Merchant 2: `(19,4)`, confirmed `Inn`; public stand `(19,2)`
  facing south.
- `npc_13` / Merchant 3: `(22,12)`, confirmed `Weapons Merchant`; public stand
  `(20,12)` facing east.
- `npc_15` / Merchant 4: `(14,21)`, confirmed `Tool Merchant`;
  interaction stand `(12,21)` facing east, reached through the `(5,14)` and
  `(3,17)` public-route passthroughs after reload.

## Overworld Route Orientation

- Kol's existing overworld landmark is `(104,10)`, from the Gamer Corner
  coordinate convention already encoded in `objects.lua` as 33 north and 61
  east of the live Tantegel Castle anchor `(43,43)`.
- Gamer Corner describes the safer route as starting at Tantegel Castle,
  heading north, turning east after the craggy mountains, crossing the eastern
  bridge into the East of Tantegel area, continuing east/south to a second
  bridge, then heading north from that bridge and east into the forest to Kol.
- StrategyWiki confirms the bridge northeast of Tantegel Castle and Brecconary
  as the first step into Northeast Alefgard, and notes that the enemies across
  the second bridge are stronger.
- NESMaps was used only as visual orientation for the waypoint shape; live
  movement validated and corrected exact bridge/south-road lanes.
- First live shakedown disproved the direct Brecconary-east pocket: raw
  `probe_edge` checks from `(57,38)` blocked right into `(58,38)`, up into
  `(57,37)`, and down into `(57,39)`. Nearby pockets at `(56,39)`, `(54,40)`,
  `(53,41)`, and the north branch around `(54,35)` also dead-ended. Treat
  those as route-lane evidence, not permanent overworld map blocks.

Current route in `overworld_routes.lua`:

- `Tantegel Castle road` `(43,43)`
- `Brecconary road` `(48,41)`
- `Bridge south bend` `(44,38)`
- `Bridge lower west lane` `(38,36)`
- `Bridge west bend` `(38,34)`
- `Upper bridge lane` `(38,32)`
- `East choke approach` `(35,32)`
- `Eastern mountain lane` `(35,24)`
- `North ridge bend` `(32,19)`
- `North trail marker` `(28,20)`
- `Erdrick's Cave road` `(28,13)`
- `North Alefgard west road` `(35,13)`
- `North Alefgard east road` `(45,13)`
- `Northeast bridge west approach` `(54,15)`
- `Northeast bridge west bend` `(58,18)`
- `Northeast bridge lower west lane` `(59,19)`
- `Northeast bridge south lane` `(61,19)`
- `Northeast bridge` `(61,18)`
- `North Alefgard bridge road` `(74,18)`
- `Kol southwest track` `(84,26)`
- `Kol southwest bridge` `(90,37)`
- `Kol bridge east lane` `(92,37)`
- `Kol lower south lane` `(92,36)`
- `Kol south road bend` `(93,36)`
- `Kol south road lower bend` `(93,35)`
- `Kol south road east lane` `(96,35)`
- `Kol south road` `(96,32)`
- `West of Kol north lane` `(96,21)`
- `Kol forest west edge` `(96,13)`
- `Kol` `(104,10)`

Player-facing note:

- The first direct east-pocket route was wrong. The active route now follows
  the Galenholm/Garinham-style north road before cutting east toward Kol.
- The user reached Kol after the north-bridge and south-road lane patches; the
  fresh post-reload probe confirmed `POSITION: map=0x07(Kol) x=19 y=23`.
