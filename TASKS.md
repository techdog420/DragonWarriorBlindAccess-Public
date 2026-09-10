# Project Roadmap and Backlog

Updated: 2026-09-08

This is the durable roadmap for work that should not interrupt the active
debug or release loop. Keep current live state and resume steps in
`session_handoff.md`. The broad priority order is release stabilization,
remaining map completion, systemic accessibility improvements, and then
quality-of-life work.

## Design Principles

- Preserve the original information constraints, not the visual presentation.
  Translate information into an equivalent nonvisual form without revealing
  exact solutions by default.
- Use progressive disclosure for exploration and secrets: clue, exploration,
  and proximity first; optional exact guidance only as an explicit escalation.
- Accessibility must not become blind random guessing. If the original game
  gives a sighted player a meaningful visual cue, provide an equivalent audio
  or text cue at the same stage.
- Independently derive and test new behavior. External mods may suggest areas
  to investigate, but do not copy unlicensed code, data tables, prose, or
  binaries.

## Release Follow-up

- Completed baseline: the licensed `0.1.0-alpha` player and corresponding-source
  packages passed deterministic build checks, ROM/save exclusion, separate NVDA
  and JAWS launch/gameplay/save/relaunch acceptance, and a complete blind-player
  run through the original `The End` screen.
- Completed offline gate: `python run_tests.py` automatically discovers all 33
  host-runnable Lua suites, runs all Python unit tests, syntax-checks every
  root Lua/Python source, and explicitly skips the two live-FCEUX diagnostic
  scripts. Keep new `test_*.lua` and `test_*.py` files inside this discovery
  contract instead of maintaining a partial hand-written suite list.
- Non-ASCII Windows user-account test: run the final player package from an
  actual Windows account whose profile name contains non-ASCII characters.
  Use NVDA, install the supported ROM through the documented process, launch
  twice, create and reload a save, and confirm the private config, speech log,
  and keyboard bridge remain package-local. The completed non-ASCII extraction
  folder test does not substitute for this account-level test.

## Immediate Next Implementation

- Player-facing route controls are implemented and live-verified. Configurable
  default `Shift+U` cancels active/deferred movement and guided Travel state
  before ordinary battle/dialogue/menu guards, clears queued steps, releases
  held direction input, preserves the selected object, and distinguishes
  movement-only, guidance-only, combined, and idle results. `Shift+R` is an
  always-read-only route-status command, so checking progress cannot create,
  replace, or recalculate guidance; full hero status moved to `Shift+B`.
  Loaded acceptance stopped both layers on one press, the follow-up status
  reported no route, and a fresh probe confirmed no active path or runtime
  blocks. Focused and broad tests pass; this item is closed.
- The first connected-route slice is implemented in source for `Tantegel ->
  Kol -> Northern Cave`. Selecting Northern Cave near Tantegel keeps the final
  Travel target focused while the current leg follows the existing Kol route.
  Route status names both the Kol leg and Northern Cave destination; reaching
  or entering Kol hands guidance off to the existing Northern Cave route but
  waits for another `U` before moving. Live FCEUX/JAWS acceptance passed the
  final-target/status behavior, the Kol transition handoff, the no-automatic-
  movement pause, and the explicit second-leg start. Bare `U` now follows the
  active guided route even if a map refresh selects the nearby Kol landmark;
  explicit object-target APIs still switch destinations. The older Kol route
  also now uses the live-proven `(98,32) -> (98,26)` detour around the blocked
  `(96,28) -> UP` edge. Focused tests pass `161/161` overworld-route and
  `116/116` route-manager tests; the full gate passes all 33 host-runnable Lua
  suites plus 68 Python tests. The user also manually completed the combined
  Tantegel-to-Northern-Cave route and confirmed the system behaved as expected.
  This pilot is closed and ready to expand.
- The second connected-route slice is implemented for `Tantegel -> Kol ->
  Swamp Cave`. Far Swamp Cave starts preserve the final destination while
  following the Kol leg; the Kol handoff selects the canonical full
  `swamp_cave` route instead of its bridge-only alternate and waits for another
  `U`. Loaded status, handoff, pause, and stale-object bare-`U` behavior pass.
  A clean natural run from Kol traversed every established south-road,
  x94 poison-swamp, and cave-entrance waypoint, entering Swamp Cave map `0x15`
  at `(0,0)` with HP `149/149`, no active path, and no runtime blockers.
  Focused tests pass `164/164`; the full gate passes all 33 host-runnable Lua
  suites plus 68 Python tests. The user manually completed the combined
  Tantegel-to-Swamp-Cave route: fresh logs show the Kol route start at frame
  `71501`, handoff to Swamp Cave at frame `84046`, and cave arrival at frame
  `89299`. The final probe confirmed map `0x15` `(0,0)`, no active path, and no
  runtime blockers. This slice is closed.
- The third connected-route slice is implemented for `Rimuldar -> Swamp Cave
  South Entrance -> Rainbow Bridge unlock point`. A far Rainbow Bridge request
  follows the established `swamp_cave_south` route, hands off on entering map
  `0x15` at `(0,29)`, waits for the player to exit with STAIRS, and then
  continues from World Map `(104,49)`. Live validation corrected Rimuldar's
  direct north carry, reset movement state at four diagonal turns, and routed
  west before south around the blocked `(98,70)->(98,71)` edge. The loaded
  itinerary completed every staging and bridge waypoint, arrived at `(65,49)`,
  and cleared route/path state with no runtime blockers. Manual acceptance also
  found that `(99,68)->DOWN` is passable but needs a sustained hold; the loaded
  fix crossed it in 33 frames with zero retries and added no blocker. Focused
  tests pass `169/169`; the broad gate passes all 33 host-runnable Lua suites
  plus 68 Python tests. The user then completed the full outbound and return
  itinerary. Two retryable timing stalls and two non-destructive carry drifts
  remain optional future polish; final state at `(104,49)` had route/path nil
  and no runtime blockers. This slice is closed.
- The fourth connected-route slice is implemented for `Rimuldar -> Swamp Cave
  South Entrance -> Charlock Castle`. Selecting Charlock outside Rimuldar
  follows the established `swamp_cave_south` route, hands off on entering map
  `0x15` at `(0,29)`, waits for the player's STAIRS exit, and then continues
  from World Map `(104,49)` without losing the final destination. Loaded
  acceptance completed every waypoint and entered Charlock map `0x02` at
  `(10,19)` with route/path cleared and no runtime blockers. Two route stalls
  passed unchanged-origin raw holds, one carry drift recovered normally, and
  no blocker was promoted. Focused tests pass `170/170`; the broad gate passes
  all 33 host-runnable Lua suites plus 68 Python tests. The user's final manual
  pass also reached Charlock with no blocked or canceled route events; fresh
  state at map `0x02` `(10,19)` had route/path nil and no runtime blockers.
  This slice is closed.
- The fifth connected-route slice is implemented for `Swamp Cave South
  Entrance -> Rimuldar -> Magic Temple`. A far Magic Temple request follows
  the established `rimuldar` route, hands off inside Rimuldar map `0x0B` at
  `(29,14)` without moving automatically, preserves the final destination
  across the player's manual exit, and then follows all 22 Magic Temple
  waypoints to `(108,109)`. Manual acceptance proved `(93,52)->DOWN` is
  engine-blocked, so the Rimuldar leg now reuses the validated reverse corridor
  through `(92,52)`, `(86,52)`, `(86,54)`, `(83,54)`, `(83,56)`, `(85,56)`,
  `(85,58)`, and `(88,58)`. The loaded replacement rejoined the original route
  without blockers. Four later timing stalls each completed on the next route
  activation; final state had route/path nil and zero runtime blockers.
  Focused tests pass `175/175`; the broad gate passes all 33 host-runnable Lua
  suites plus 68 Python tests. This slice is closed.
- The sixth connected-route slice is live-verified for `Tantegel -> Kol ->
  Hauksness`. Far Hauksness starts now stage through the established Kol route,
  retain the final destination, and hand off at Kol `(104,10)` to the existing
  live-validated Hauksness chain. On-route western starts remain direct, and no
  Hauksness waypoint geometry changed. Continuous overworld auto-walk is also
  integrated as an opt-in setting; checked-in and generated player configs keep
  waypoint mode as the default. Focused tests pass `179/179` overworld routes,
  `123/123` route
  manager, and `3/3` config tests; the broad gate passes all 33 host-runnable
  Lua suites plus 68 Python tests. Loaded travel from Tantegel `(43,43)` handed
  off at Kol, then completed the full Hauksness corridor and entered map `0x03`
  with route/path state clear and zero runtime blockers. The legacy Kol leg
  still entered Brecconary; that remains part of the separate early-route
  town-entry polish task. This slice is closed.
- The seventh connected-route slice is live-verified for `Tantegel -> Kol ->
  Hauksness -> Cantlin`. A generic ordered continuation list now supports more
  than one staging handoff while retaining Cantlin as the selected final
  destination. Both intermediate handoffs pause before movement, and direct
  Hauksness-side and Great-Swamp-side Cantlin starts remain local. The loaded
  route completed from `(43,43)` through both manual town-exit handoffs and
  entered Cantlin at `(15,0)` with no blocker, cancellation, retry exhaustion,
  or runtime-block pollution. Focused tests pass `184/184`; the native Windows
  broad gate passes all 33 host-runnable Lua suites plus 68 Python tests. This
  slice is closed; early-route town-entry avoidance remains separate polish.
- The eighth connected-route slice is fully live-verified for `Tantegel -> Kol
  -> Western desert east road -> Mountain Cave`, with the existing ordered continuation list
  also composing `Tantegel -> Kol -> connector -> Mountain Cave`. The internal
  connector is derived from the live-validated Hauksness route prefix through
  `(18,64)`, so it cannot drift from that shared corridor. Direct local starts
  remain unchanged. The loaded continuous pass from World Map `(104,10)`
  handed off at `(18,64)`, entered Mountain Cave map `0x16` at `(0,7)`, and
  finished with route/path state clear and zero NPC/runtime blockers. The user
  manually repeated and accepted the route; a fresh arrival probe confirmed
  the same clean state. A complete manual Tantegel run entered Brecconary and
  Kol, completed both staging handoffs, and entered Mountain Cave without a
  blocker, cancellation, or exhausted retry. One initial timing retry
  recovered. Focused tests pass `189/189`; the native Windows broad gate passes
  all 33 host-runnable Lua suites plus 68 Python tests. This slice is closed;
  Brecconary/Kol entry remains part of the separate early-route town-entry
  polish task.

## Remaining Map Completion

- Charlock is complete. Its hidden entrance, seven-link main dungeon spine,
  Erdrick's Sword branch, B4/B5 false branch, B6 same-floor loop, visible
  ground-floor decoys, complete B1/B2 stair graph, locked treasure room, six
  chests, Dragonlord encounter, Ball of Light sequence, and return routes are
  source-only and live-verified. The post-victory sequence gives the Ball of
  Light and moves the hero directly to World Map `(48,48)`; the decorative
  throne enclosure is not required and no longer needs decoding.

## Overworld Navigation

- Anywhere-to-anywhere routing: replace the requirement that players understand
  which fixed route leads toward which destination. Model the existing route
  chains and waypoints as a connected graph so selecting any supported
  overworld location can compose a route from the player's current position,
  through existing waypoint corridors, to the destination. Reusing current
  route data is preferred over replacing live-validated segments. The opt-in
  Northern Cave, Swamp Cave, Rimuldar, Rainbow Bridge, Charlock Castle, Magic
  Temple, and Hauksness are implemented and live-accepted as connected routes.
  Choose the next existing staged destination before generalizing the route
  model further.
- The connected Rimuldar slice is live-accepted. Far starts compose
  `kol_staging -> swamp_cave -> rimuldar`, bridging the validated northern and
  southern route networks through Swamp Cave rather than synthesizing an
  unverified shortcut. A loaded run from `(43,43)` handed off outside Kol,
  paused for cave traversal, resumed from World Map `(104,49)`, and entered
  Rimuldar at `(29,14)` with route/path state clear and zero runtime blockers.
  Direct nearby starts remain unchanged. Focused tests pass `199/199`, and the
  broad gate passes all 33 host-runnable Lua suites plus 68 Python tests. The
  nested Magic Temple path is source-covered but was not part of this live
  acceptance.
- Off-network recovery: the first bounded slice is live-verified. Exact
  membership on the proven Kol-to-Swamp-Cave corridor now lets Brecconary,
  Erdrick's Cave, and Garinham resume through `kol_swamp_cave_staging` instead
  of synthesizing a long opening. Brecconary passed live from `(99,42)`,
  Erdrick's Cave was revalidated from exact waypoint `(97,42)`, and Garinham
  passed the same loaded selection check. The next bounded slice is also
  source-complete and live-verified: exact membership on the
  Northern-Cave-to-Kol return now gives those same three destinations a
  three-step opening from `(92,13)` instead of 63 or 64 synthesized steps. All
  three loaded route selections preserved their requested final destination,
  and the final audit found no active path or runtime blockers. A third bounded
  slice is source-complete and live-verified: Swamp Cave South,
  Rainbow Bridge, and Charlock now resume from the same shrine-return corridor
  at `(78,3)`, replacing an incorrect 51-step `rainbow_bridge_return` opening
  with one step west on `kol_rain_shrine_staging`. All three loaded selections
  preserved the requested final destination; the final audit found no active
  path or runtime blockers. A fourth bounded slice is source-complete and
  live-verified: Tantegel, Mountain Cave, Hauksness, Cantlin, and
  Great Swamp now select that same one-step-west shrine-return recovery from
  `(78,3)` instead of their previous 19-step openings. Static coverage includes
  each Travel object and alias plus all 1,040 combinations of 65 exact corridor
  cells and 16 destinations; none now opens with more than 11 steps. Loaded
  starts preserved all five requested final destinations and the user confirmed
  the expected starting waypoints. The final probe found no active path or
  runtime blockers. A fifth bounded slice is source-complete and live-verified:
  Swamp Cave South, Rainbow Bridge, and Charlock now recover from
  exact `kol_swamp_cave_staging` membership through the mainland north-entrance
  approach instead of selecting the disconnected southern-island route. The
  former seven-step deceptive opening at `(99,42)` now uses the proven
  `swamp_cave_bridge` approach, and the 38-step opening at `(96,14)` is seven
  steps to the next `swamp_cave` waypoint. Static coverage checks all 186
  combinations of 62 corridor cells and three destinations, with no direct
  south-island selection and no opening over 10 steps. The dedicated safe
  re-entry behavior at `(104,44)` remains unchanged. Loaded checks confirmed
  all three two-step-west starts from `(99,42)` plus Charlock's seven-step-south
  start from `(96,14)`; the final probe found no active path or runtime
  blockers. A sixth bounded slice is source-complete and live-verified: Swamp
  Cave South, Rainbow Bridge, and Charlock now recognize
  exact membership on the existing `erdrick` corridor and resume through
  `kol_staging`. From `(28,17)`, this replaces the incorrect 51-step
  `charlock_return` opening with three steps south to `North trail marker` at
  `(28,20)`. Static coverage checks all 171 combinations of 57 corridor cells
  and three destinations: every selection uses `kol_staging`, none uses
  `charlock_return`, and none opens with more than 9 steps. Focused route tests
  pass `302/302`; all 33 host-runnable Lua suites and all 68 Python tests pass.
  Loaded route selections from `(28,17)` retained all three final destinations
  while starting the expected route and waypoint. The user confirmed each
  generated as expected; the final probe found no active path or runtime
  blockers. A seventh bounded slice is source-complete and live-verified:
  Hauksness, Cantlin, and Great Swamp now use an eleven-step
  off-network staging boundary from the Erdrick corridor. From `(44,36)`, each
  replaces a synthetic 24-step opening with two steps south on `kol_staging`.
  Exact Hauksness-route membership remains direct even when its next validated
  marker is farther than eleven steps. Static coverage checks all 171
  combinations of 57 Erdrick-corridor cells and three destinations; every
  selection resolves and none opens with more than 11 steps. Focused route
  tests pass `304/304`; all 33 host-runnable Lua suites and all 68 Python tests
  pass. Loaded route selections from `(44,36)` retained all three final
  destinations while starting the expected route and waypoint. The user
  confirmed each generated as expected; the final probe found no active path
  or runtime blockers. A comprehensive follow-up checked all 912 combinations
  of 57 exact Erdrick-corridor cells and 16 Travel destinations; every route
  resolves and none opens with more than 11 steps, closing that corridor for
  this pass. An eighth bounded slice is source-complete and live-verified:
  Swamp Cave South, Rainbow Bridge, and Charlock now recognize the
  Magic-Temple-to-Rimuldar return corridor. From `(105,114)`, each replaces a
  synthetic 44-step opening with one step west on
  `rimuldar_magic_temple_staging`. A four-tile Rimuldar exclusion preserves the
  direct local cave return. Static coverage checks all 216 combinations of 72
  corridor cells and three destinations; every selection resolves through an
  established route, and the largest remaining segment is the validated
  13-step southern-road leg. Focused route tests pass `305/305`; all 33
  host-runnable Lua suites and all 68 Python tests pass. Loaded selections from
  `(105,114)` retained all three final destinations while starting the expected
  route and waypoint. The user confirmed each behaved correctly; the final
  probe found no active path or runtime blockers. A ninth bounded slice is
  source-complete and live-verified: Brecconary, Erdrick's Cave,
  and Garinham now recognize the same Magic-Temple-to-Rimuldar return corridor
  through their existing south-island variants. From `(107,113)`, each replaces
  a synthetic 131- or 132-step failure with one step south on
  `rimuldar_magic_temple_staging`. Static coverage checks all 216 combinations
  of 72 corridor cells and three destinations; every selection resolves, and
  the largest segment is the existing validated 13-step southern-road leg.
  Focused route tests pass `306/306`; all 33 host-runnable Lua suites and all 68
  Python tests pass. Loaded selections from `(107,113)` retained all three final
  destinations while starting the Rimuldar leg at `Temple south approach east`,
  one south. The user confirmed each generated correctly; the final probe found
  no active path or runtime blockers. A tenth bounded slice is source-complete
  and live-verified: Hauksness, Cantlin, and the Eastern Great Swamp
  Search Area now recognize the same Magic-Temple-to-Rimuldar return corridor
  through their existing south-island variants. From `(107,113)`, each replaces
  an 89-step synthetic failure with one step south on
  `rimuldar_magic_temple_staging`. Static coverage checks all 216 combinations
  of 72 corridor cells and three destinations; every selection resolves, and
  the largest segment is the existing validated 13-step southern-road leg.
  Focused route tests pass `307/307`; all 33 host-runnable Lua suites and all 68
  Python tests pass. Loaded selections from `(107,113)` retained all three final
  destinations while starting the Rimuldar leg at `Temple south approach east`,
  one south. The user confirmed each generated correctly; the final probe found
  no active path or runtime blockers. An eleventh bounded slice is
  source-complete and live-verified: Kol, Northern Cave, Mountain
  Cave, and Swamp Cave North Entrance now recognize the same
  Magic-Temple-to-Rimuldar return corridor through their existing south-island
  variants. From `(107,113)`, each replaces a rejected cross-world opening with
  one step south on `rimuldar_magic_temple_staging`. Static coverage checks all
  288 combinations of 72 corridor cells and four destinations; every selection
  resolves, and the largest segment is the existing validated 13-step
  southern-road leg. Loaded selections from `(107,113)` retained Kol, Northern
  Cave, Mountain Cave, and Swamp Cave North Entrance while starting the
  expected Rimuldar leg at frames `3026`, `3752`, `4822`, and `5938`; each
  targeted `Temple south approach east`, one south, and cancelled cleanly.
  Fresh frame `24120` confirmed World Map `(107,113)`, path target nil, and no
  NPC or runtime blockers. A twelfth bounded slice is source-complete and
  live-verified: Tantegel now recognizes the same return corridor
  through its existing Magic Temple variant. From `(107,113)`, it replaces an
  unrelated 18-step `cantlin_return_staging` opening with one step south on
  `rimuldar_magic_temple_staging`, while preserving Tantegel Castle as the
  final destination. No waypoint geometry or movement timing changed. The
  comprehensive 72-cell by 16-destination audit now has zero flagged
  selections or errors and a maximum opening of 13 steps. Focused route tests
  pass `309/309`; all 33 host-runnable Lua suites and all 68 Python tests pass.
  The loaded selection at `(107,113)` started the expected Rimuldar leg at
  frame `1698`, retained `staged_from=tantegel_kol`, and targeted `Temple south
  approach east`. The user confirmed the generated route; fresh frame `6840`
  found no active path, NPC blockers, or runtime blockers. A thirteenth bounded
  slice is source-complete and live-verified: Swamp Cave South,
  Rainbow Bridge, and Charlock now recognize exact membership on the validated
  Tantegel-to-Kol `kol_staging` corridor. From `(32,13)`, each replaces an
  incorrect 51-step `charlock_return` opening with three steps east to `North
  Alefgard west road` on `kol_staging`, while retaining its final destination.
  No waypoint geometry or movement timing changed. Static coverage checks all
  564 combinations of 188 exact corridor cells and three destinations; every
  selection resolves, and none opens with more than the existing validated
  19-step Kol segment. Focused route tests pass `310/310`; all 33 host-runnable
  Lua suites and all 68 Python tests pass. Loaded starts from `(32,13)` at
  frames `4119`, `5284`, and `6370` retained Swamp Cave South, Rainbow Bridge,
  and Charlock while starting the expected Kol leg. The user confirmed all
  three generated correctly; fresh frame `10200` found no active path, NPC
  blockers, or runtime blockers. A fourteenth bounded slice is source-complete
  and live-verified: Brecconary, Erdrick's Cave, and Garinham now
  recognize exact membership on the northern/eastern Tantegel-to-Kol corridor
  through their existing Kol-origin variants. The bounded region `x >= 47,
  y <= 37` preserves direct local starts near Tantegel, Brecconary, and
  Erdrick's Cave. From `(91,37)`, each replaces a 47- or 48-step synthetic
  opening with one step west to `Kol southwest bridge` on
  `tantegel_bridge_staging`, while retaining its final destination. Exact
  bridge-return membership preserves the known 18-step segment from `(84,26)`.
  No waypoint geometry or movement timing changed. Static coverage checks all
  564 combinations of 188 exact corridor cells and three destinations; every
  selection resolves within the existing 24-step early-destination staging
  bound. Focused route tests pass `311/311`; all 33 host-runnable Lua suites and
  all 68 Python tests pass. Loaded starts from `(91,37)` at frames `4442`,
  `5069`, and `5593` retained Brecconary, Erdrick's Cave, and Garinham while
  starting the expected bridge-junction leg. The user confirmed all three
  generated correctly; fresh frame `7740` found no active path, NPC blockers,
  or runtime blockers. The complete follow-up audit checks all 3,008
  combinations of 188 exact Kol-corridor cells and 16 destinations; every
  route resolves within the established 24-step bound, closing that corridor
  for this pass. A fifteenth bounded slice is source-complete and live-verified:
  six forward Kol-to-Swamp-Cave cells omitted by the reversed
  route's alternate L-turn ordering now select the existing connected route.
  From `(96,24)`, Brecconary, Erdrick's Cave, and Garinham start
  `tantegel_bridge_swamp_cave_staging`; Swamp Cave South, Rainbow Bridge, and
  Charlock start `swamp_cave`. All six target `West of Kol north lane` three
  steps north, replacing 26-64-step synthetic openings. The bounded selector
  covers only `(96,22)` through `(96,26)` plus `(97,26)`, and changes no
  waypoint geometry or movement timing. Static audits of the three shared
  63-cell corridors cover 3,024 combinations against all 16 destinations with
  zero failures and a maximum opening of 13. Focused route tests pass
  `313/313`; all 33 host-runnable Lua suites and all 68 Python tests pass.
  Loaded starts from `(96,24)` selected the expected route and waypoint for all
  six destinations at frames `1370`, `4879`, `5431`, `6518`, `7308`, and
  `7760`. The user confirmed every generated route; fresh frame `14820` found
  no active path, NPC blockers, or runtime blockers. A sixteenth bounded slice
  is source-complete and live-verified: six cells on the Tantegel
  bridge-return L-turn now preserve Swamp Cave South, Rainbow Bridge, or
  Charlock while selecting `kol_staging`. From `(32,22)`, each targets `North
  ridge bend` three steps north instead of opening 38-43 steps toward Charlock.
  The selector is limited to `(32,21)` through `(32,24)`, plus `(33,24)` and
  `(34,24)`; no waypoint geometry or movement timing changed. Static audits of
  the three identical 176-cell wrappers cover 8,448 combinations against all
  16 destinations with zero failures and a maximum opening of 24. Focused
  route tests pass `314/314`; all 33 host-runnable Lua suites and all 68 Python
  tests pass. Loaded starts from `(32,22)` retained all three final destinations
  while selecting `kol_staging` and `North ridge bend` at frames `1179`,
  `1999`, and `2376`. The user confirmed every generated route; tagged
  readiness passed at frame `6480`, and fresh frame `7260` found no active
  path, NPC blockers, or runtime blockers. A seventeenth bounded slice is
  source-complete and live-verified: Swamp Cave North, Swamp Cave
  South, Rainbow Bridge, and Charlock now recognize the Garinham-exclusive
  `x <= 24` section of `tantegel_garinham_staging`. From `(14,4)`, each starts
  that return and targets `Garinham shoulder east step` one step east instead
  of opening 25-88 steps on generic or disconnected routes. Shared Erdrick
  starts remain unchanged. Static coverage checks all 328 combinations of 82
  corridor cells and four destinations within 24 steps; the full corridor
  audit drops from 150 failures to 21, leaving a separate
  Kol/Northern/Mountain batch. Focused route tests pass `315/315`; all 33
  host-runnable Lua suites and all 68 Python tests pass. Loaded starts from
  `(14,4)` retained all four final destinations while selecting
  `tantegel_garinham_staging` and `Garinham shoulder east step` at frames
  `3067`, `3473`, `4530`, and `5011`. The user confirmed every generated route;
  tagged readiness passed at frame `7380`, and fresh frame `7800` found no
  active path, NPC blockers, or runtime blockers. An eighteenth bounded slice
  is source-complete and live-verified: Kol and Northern Cave now
  recognize the exact Garinham bridge-return corridor through `x <= 13`, while
  Mountain Cave recognizes it only through `x <= 7`. The selectors reuse
  `kol_hauksness`, `northern_cave_garinham`, and `mountain_cave_garinham`
  without changing waypoint geometry or movement timing. From `(7,3)`, all
  three target `Garinham north coast lane` at `(14,3)`, seven steps east; Kol
  starts `kol_hauksness`, and the other two start
  `tantegel_garinham_staging`. The complete audit now covers all 1,312
  combinations of 82 exact corridor cells and all 16 Travel destinations with
  no opening longer than 24 steps. Focused route tests pass `316/316`; all 33
  host-runnable Lua suites and all 68 Python tests pass. Loaded starts from
  `(7,3)` selected the expected route and waypoint for Kol, Northern Cave, and
  Mountain Cave at frames `1147`, `3860`, and `5098`; the user confirmed all
  three generated correctly. Tagged readiness passed at frame `23100`, and
  fresh frame `23460` found no active autowalk path, NPC blockers, or runtime
  blockers. The final Kol route remains selected. A nineteenth bounded slice
  is source-complete and live-verified: Brecconary, Erdrick's Cave,
  and Garinham now recognize all 23 exact cells of the `mountain_cave` spur
  through their existing western-return variants. This reuses
  `mountain_cave_return` and the established nested return chain without
  changing waypoint geometry or movement timing. At `(16,61)`, all three start
  that return and target `Mountain Cave forest turn` at `(16,64)`, three steps
  south, instead of opening 46-48 steps on generic routes. Static coverage
  checks all 69 spur/destination combinations within 24 steps. Focused route
  tests pass `317/317`; all 33 host-runnable Lua suites and all 68 Python tests
  pass. Loaded starts from `(16,61)` selected the expected return and waypoint
  for all three destinations at frames `591`, `1056`, and `1497`; the user
  confirmed each route and cancellation. Tagged readiness passed at frame
  `4560`, and fresh frame `4860` found no active path, NPC blockers, runtime
  blockers, or new script error. A twentieth bounded slice is source-complete
  and live-verified: Swamp Cave South, Rainbow Bridge, and Charlock
  now recognize all 23 exact cells of the `mountain_cave` spur through
  `swamp_cave_south_mainland` and its western staging leg. This reuses the
  established Mountain Cave, Hauksness, Kol, and manual cave-crossing chain
  without changing waypoint geometry or movement timing. At `(16,61)`, all
  three start `mountain_cave_return` and target `Mountain Cave forest turn` at
  `(16,64)`, three steps south, instead of opening 33 steps toward Charlock
  island. Static coverage checks all 69 spur/destination combinations within
  24 steps. Focused route tests pass `318/318`; all 33 host-runnable Lua suites
  and all 68 Python tests pass. Loaded starts from `(16,61)` selected the
  expected return and waypoint for all three destinations at frames `764`,
  `1708`, and `2227`; the user confirmed each route and cancellation. Tagged
  readiness passed at frame `4980`, and fresh frame `5280` found no active
  path, NPC blockers, runtime blockers, or new script error. A twenty-first
  bounded slice is source-complete and live-verified: Northern Cave,
  Hauksness, Cantlin, and Great Swamp now recognize the exact `mountain_cave`
  corridor through their existing northwestern-return variants. The shared
  western Swamp Cave staging leg also retains Swamp Cave North as its active
  destination during the nested return. No waypoint geometry or movement
  timing changed. At `(24,58)`, those five destinations all start
  `mountain_cave_return`, remain selected, and target `Mountain Cave south
  approach` at `(25,58)`, one step east. The complete audit covers all 368
  combinations of 23 exact spur cells and all 16 Travel destinations within 24
  steps. Focused route tests pass `319/319`; all 33 host-runnable Lua suites and
  all 68 Python tests pass. Loaded starts from World Map `(24,58)` selected the
  expected return and waypoint for all five destinations at frames `2960`,
  `3402`, `4661`, `5403`, and `5893`; the user confirmed every route. Shift+U
  stopped each route and autowalk cleanly at frames `3271`, `3660`, `4909`,
  `5667`, and `6172`. Tagged readiness passed at frame `10380`, and fresh frame
  `10740` found no active path, NPC blockers, runtime blockers, or new script
  error. A twenty-second bounded slice is source-complete and live-verified:
  the Swamp Cave northern-return wrapper now retains the selected
  Swamp Cave North destination across 11 exact Kol/bridge cells. Both complete
  Kol and Tantegel bridge corridor regressions now assert destination retention
  across all 5,824 combinations. At `(96,13)`, the route selects
  `swamp_cave_northern_return_staging`, remains matched to Swamp Cave North,
  and targets `West of Kol north lane` at `(96,21)`, eight steps south. Focused
  route tests pass `319/319`; the full gate passes all 33 host-runnable Lua
  suites and all 68 Python tests. A loaded start at `(96,13)` selected the
  expected return and waypoint at frame `1791`; Shift+R reported status on the
  same route at frame `2110` instead of replacing it, and Shift+U stopped the
  route and autowalk cleanly at frame `2405`. The user confirmed the route.
  Tagged readiness passed at frame `7620`, and fresh frame `7920` found no
  active path, NPC blockers, runtime blockers, or new script error. A
  twenty-third bounded slice is source-complete and live-verified:
  Brecconary, Erdrick's Cave, and Garinham now recognize all 85 exact cells on
  the validated `rimuldar_swamp_cave_north_staging` corridor. All 255
  destination combinations retain the requested target and open within 24
  steps. At `(99,49)`, all three start `rainbow_bridge_return` toward Swamp
  Cave South at `(104,49)`, five steps east, instead of synthesizing 59-60-step
  mainland openings. Focused route tests pass `320/320`; the full gate passes
  all 33 host-runnable Lua suites and all 68 Python tests. Loaded starts from
  `(99,49)` selected the expected cave-return leg and waypoint for Brecconary,
  Erdrick's Cave, and Garinham at frames `4390`, `5064`, and `6167`; the user
  confirmed every route. Shift+U stopped each route and autowalk cleanly at
  frames `4663`, `5342`, and `6442`. Tagged readiness passed at frame `8760`,
  and fresh frame `9660` found no active path, NPC blockers, runtime blockers,
  or new script error. A twenty-fourth bounded slice is source-complete and
  live-verified: Kol, Northern Cave, and Mountain Cave now recognize
  all 85 exact cells on the validated `rimuldar_swamp_cave_north_staging`
  corridor. All 255 destination combinations retain the requested target, with
  no opening over 14 steps. At `(83,55)`, all three start `swamp_cave_south`
  toward `South island west ridge lane` at `(83,54)`, one step north, instead
  of opening 25-48 steps. Live starts at `(83,55)` retained Kol, Northern Cave,
  and Mountain Cave at frames `2601`, `3863`, and `4534`; Shift+U stopped each
  route and autowalk cleanly at frames `3824`, `4334`, and `5013`. Tagged
  readiness passed at frame `9840`, and fresh frame `10200` found no active
  path, NPC blockers, runtime blockers, or new script error. Focused route tests
  pass `321/321`; the full gate passes all 33 host-runnable Lua suites and all
  68 Python tests.
  A twenty-fifth bounded slice is source-complete and live-verified:
  Hauksness, Cantlin, and the Eastern Great Swamp Search Area now recognize all
  85 exact cells on `rimuldar_swamp_cave_north_staging`. Before the patch, each
  had 48 openings over the connected bound, beginning at `(83,55)` with a
  25-step `kol_staging` segment. All 255 destination combinations now retain
  the requested target with no opening over 14 steps. At `(83,55)`, all three
  start `swamp_cave_south` toward `South island west ridge lane` at `(83,54)`,
  one step north. Focused route tests pass `322/322`; the full gate passes all
  33 host-runnable Lua suites and all 68 Python tests. Tantegel and Swamp Cave
  North remain as the final isolated pair on this corridor. Loaded starts
  retained Hauksness at frames `730` and `3571`, Cantlin at frame `5069`, and
  Great Swamp at frame `5893`; each selected the expected nearby return.
  Shift+U stopped the accepted runs at frames `4046`, `5456`, and `6221`.
  Tagged readiness passed at frame `8400`; fresh frame `8700` found no active
  path, NPC blockers, runtime blockers, or new script error.
  A twenty-sixth bounded slice is source-complete and live-verified:
  Tantegel and Swamp Cave North now recognize all 85 exact cells on
  `rimuldar_swamp_cave_north_staging`. Before the patch, each had 48 openings
  over the connected 24-step bound, reaching 61 steps for Tantegel and 48 for
  Swamp Cave North. All 170 combinations now retain the requested target with
  no opening over 14 steps. At `(83,55)`, both start `swamp_cave_south` toward
  `South island west ridge lane` at `(83,54)`, one step north. Focused route
  tests pass `323/323`; the full gate passes all 33 host-runnable Lua suites and
  all 68 Python tests. Loaded starts retained Swamp Cave North at frame `2454`
  and Tantegel at frame `3522`; both selected the expected nearby return.
  Shift+U stopped them cleanly at frames `3009` and `3838`. Tagged readiness
  passed at frame `6960`; fresh frame `7320` found no active path, NPC blockers,
  runtime blockers, or new script error. This closes the source and live audit
  for every destination on the 85-cell Rimuldar return corridor.
  A twenty-seventh bounded slice is source-complete and live-verified:
  Brecconary, Erdrick's Cave, and Garinham now recognize all 85
  exact cells on `cantlin_return_staging` through their existing western-return
  variants. Before the patch, each had 80 openings over the connected 24-step
  bound, 240 total; the representative Brecconary start at `(85,113)` attempted
  a 109-step synthetic opening. All 255 destination combinations now retain the
  requested target with no opening over 14 steps. At `(85,113)`, all three
  start `cantlin_return_staging` toward the nearest `Great Swamp east lane`
  waypoint at `(89,113)`, four steps east. Focused route tests pass `324/324`;
  the full gate passes all 33 host-runnable Lua suites and all 68 Python tests.
  Loaded starts retained Brecconary at frame `1864`, Erdrick's Cave at frame
  `4034`, and Garinham at frame `4465`; all selected the expected corridor and
  waypoint. Shift+U stopped the routes cleanly at frames `3976`, `4292`, and
  `4769`. Fresh frame `18900` found World Map `(85,113)` with no active path,
  NPC blockers, runtime blockers, or new script error.
  A twenty-eighth bounded slice is source-complete and live-verified: Kol,
  Northern Cave, and Mountain Cave now recognize all 85 exact
  cells on `cantlin_return_staging` through their existing northwestern-return
  variants. Before the patch, the permanent regression reproduced an 81-step
  Kol opening from this connected corridor. All 255 destination combinations
  now retain the requested target with no opening over 14 steps. At
  `(85,113)`, all three start `cantlin_return_staging` toward the nearest
  `Great Swamp east lane` waypoint at `(89,113)`, four steps east. Focused
  route tests pass `325/325`; the full gate passes all 33 host-runnable Lua
  suites and all 68 Python tests. Loaded starts retained Kol at frame `2710`,
  Mountain Cave at frame `3979`, and Northern Cave at frame `4674`; all
  selected the expected corridor and waypoint. Shift+R preserved the active
  routes, and Shift+U stopped them cleanly at frames `3182`, `4465`, and
  `5173`. Fresh frame `8040` found World Map `(85,113)` with no active path,
  NPC blockers, runtime blockers, or new script error.
  A twenty-ninth bounded slice is source-complete and live-verified: Hauksness,
  Swamp Cave North, and Swamp Cave South now recognize all 85 exact
  cells on `cantlin_return_staging` through their existing destination
  wrappers. The pre-patch audit found 27 overlong Hauksness openings and 80
  each for the two cave destinations; at `(85,113)`, the openings were 81, 81,
  and 45 steps respectively. All 255 destination combinations now retain the
  requested target with no opening over 14 steps. At `(85,113)`, all three
  start `cantlin_return_staging` toward the nearest `Great Swamp east lane`
  waypoint at `(89,113)`, four steps east. Focused route tests pass `326/326`;
  the full gate passes all 33 host-runnable Lua suites and all 68 Python tests.
  Loaded starts retained Hauksness at frame `795`, Swamp Cave North at frame
  `3296`, and Swamp Cave South at frame `4575`; all selected the expected
  corridor and waypoint. Shift+R preserved the active routes, and Shift+U
  stopped them cleanly at frames `1258`, `3804`, and `5109`. Fresh frame `7440`
  found World Map `(85,113)` with no active path, NPC blockers, runtime
  blockers, or new script error.
  A thirtieth bounded slice is source-complete and live-verified: Rimuldar,
  Magic Temple, and Rainbow Bridge now recognize all 85 exact cells
  on `cantlin_return_staging` through their existing destination itineraries.
  The pre-patch audit found 80 overlong openings for each destination, 240
  total; at `(85,113)`, the openings were 18, 81, and 45 steps respectively.
  All 255 destination combinations now retain the requested target with no
  opening over 14 steps. At `(85,113)`, all three start
  `cantlin_return_staging` toward the nearest `Great Swamp east lane` waypoint
  at `(89,113)`, four steps east. Focused route tests pass `327/327`; the full
  gate passes all 33 host-runnable Lua suites and all 68 Python tests. Loaded
  starts retained Rimuldar at frame `790`, Rainbow Bridge at frame `1612`, and
  Magic Temple at frame `2689`; all selected the expected corridor and
  waypoint. Shift+R preserved the active routes, and Shift+U stopped them
  cleanly at frames `1224`, `2082`, and `3147`. Fresh frame `5280` found World
  Map `(85,113)` with no active path, NPC blockers, runtime blockers, or new
  script error. At that checkpoint, Charlock remained the final isolated audit
  item on this corridor.
  A thirty-first bounded slice is source-complete and live-verified: the
  preceding Rainbow Bridge corridor integration already
  connected Charlock through their shared `FINAL_PROGRESSION_STAGING` chain,
  so no redundant production selector was added. A dedicated regression now
  checks all 85 exact `cantlin_return_staging` cells, retains Charlock Castle as
  the requested final destination, and keeps every opening within 14 steps. At
  `(85,113)`, Charlock starts `cantlin_return_staging` toward
  `Great Swamp east lane` at `(89,113)`, four steps east. Focused route tests
  pass `328/328`; the full gate passes all 33 host-runnable Lua suites and all
  68 Python tests. Loaded selection at frame `71879` retained Charlock, started
  `cantlin_return_staging`, and targeted `Great Swamp east lane`; Shift+R at
  frame `72140` reported the same route, waypoint, and index. Fresh frame
  `75600` found World Map `(85,113)` with path target nil, zero NPC/runtime
  blockers, and no new script error. This closes the source and live audit for
  every supported destination on the 85-cell Cantlin return corridor.
  A thirty-second bounded slice is source-complete and live-verified:
  Brecconary, Erdrick's Cave, and Garinham now recognize all 125
  exact cells on `hauksness_return_staging` through their existing
  western-return variants. Before the patch, each had 87 openings over the
  connected 24-step bound. At `(73,97)`, their direct routes attempted 81, 82,
  and 82 steps and exceeded the planner limit. All 375 combinations now retain
  the selected destination with no opening over 14 steps. From `(73,96)`, all
  three start `hauksness_return_staging` toward `Cantlin north road` at
  `(73,91)`, five steps north. No waypoint geometry or movement timing changed.
  Focused route tests pass `329/329`; the full gate passes all 33 host-runnable
  Lua suites and all 68 Python tests. Loaded starts retained Brecconary at frame
  `2471`, Erdrick's Cave at frame `3277`, and Garinham at frame `3776`; Shift+R
  preserved each route and Shift+U stopped them cleanly. Fresh frame `7260`
  found World Map `(73,96)` with path target nil, zero NPC/runtime blockers,
  and no new script error.
  A thirty-third bounded slice is source-complete and live-verified: Kol,
  Northern Cave, and Mountain Cave now recognize all 125 exact cells on
  `hauksness_return_staging` through their existing northwestern-return
  variants. Before the patch, Kol had 59 openings over the connected 24-step
  bound; Northern Cave and Mountain Cave each had 87. At `(73,97)`, Kol opened
  53 steps while the two cave routes each attempted 77 steps and exceeded the
  planner limit. All 375 combinations now retain the selected destination with
  no opening over 14 steps. From `(73,96)`, all three start
  `hauksness_return_staging` toward `Cantlin north road` at `(73,91)`, five
  steps north. No waypoint geometry or movement timing changed. Focused route
  tests pass `330/330`; the full gate passes all 33 host-runnable Lua suites and
  all 68 Python tests. Loaded starts retained Kol at frame `2037`, Northern
  Cave at frame `2508`, and Mountain Cave at frame `3125`; Shift+R preserved
  each route and Shift+U stopped them cleanly. Fresh frame `5520` found World
  Map `(73,96)` with path target nil, zero NPC/runtime blockers, and no new
  script error.
  A thirty-fourth bounded slice is source-complete and live-verified: Swamp
  Cave North, Swamp Cave South, and Rainbow Bridge now
  recognize all 125 exact cells on `hauksness_return_staging` through their
  existing cave and final-progression wrappers. Before the patch, each had 87
  openings over the connected 24-step bound. At `(73,97)`, Swamp Cave North
  attempted 77 steps and exceeded the planner limit; Swamp Cave South and
  Rainbow Bridge each opened 41 steps through the wrong cave return. All 375
  combinations now retain the selected destination with no opening over 14
  steps. From `(73,96)`, all three start `hauksness_return_staging` toward
  `Cantlin north road` at `(73,91)`, five steps north. No waypoint geometry or
  movement timing changed. Focused route tests pass `331/331`; the full gate
  passes all 33 host-runnable Lua suites and all 68 Python tests. Loaded starts
  retained Swamp Cave North at frame `787`, Swamp Cave South at frame `1416`,
  and Rainbow Bridge at frame `2533`; Shift+R preserved each route and Shift+U
  stopped them cleanly. Fresh frame `5220` found World Map `(73,96)` with path
  target nil, zero NPC/runtime blockers, and no new script error.
  A thirty-fifth bounded slice completes the Hauksness return-corridor source
  audit and awaits live validation. Rimuldar was the only remaining selector
  hole: 75 of the 125 exact `hauksness_return_staging` cells opened beyond the
  connected 14-step bound. Magic Temple, Charlock, Tantegel, Hauksness,
  Cantlin, and Great Swamp were already connected through existing shared or
  local routes. Rimuldar now recognizes the Hauksness return through its
  existing staging chain, with no waypoint geometry or movement timing change.
  Dedicated tests cover all 2,000 corridor/destination combinations—125 cells
  across all 16 landmarks—with no opening over 14 steps. From `(73,96)`,
  Rimuldar, Magic Temple, and Charlock each start
  `hauksness_return_staging` toward `Cantlin north road` at `(73,91)`, five
  steps north. Focused route tests pass `333/333`; the full gate passes all 33
  host-runnable Lua suites and all 68 Python tests. Reload `main.lua` and
  validate those three destinations from clear World Map `(73,96)`, using
  Shift+U between selections.
  A thirty-sixth bounded slice starts the Kol return-corridor recovery and is
  source-complete and live-verified. Brecconary, Erdrick's Cave, and Garinham now
  recognize the disconnected western portion of the 373-cell
  `kol_return_staging` corridor through their existing western-return variants.
  Before the patch, each destination had 140 openings over the connected
  24-step bound; Brecconary reproduced a rejected 71-step opening at `(31,81)`.
  Membership is limited to exact corridor cells with `y >= 30`, preserving the
  already-correct Garinham-local overlap farther north. All 1,119 combinations
  now retain the selected target with no opening over 24 steps. From `(31,81)`,
  all three start `kol_return_staging` toward `Hauksness north ridge` at
  `(29,82)`, two steps west and one south. No waypoint geometry or movement
  timing changed. Focused route tests pass `334/334`; the full gate passes all
  33 host-runnable Lua suites and all 68 Python tests. Loaded starts retained
  Brecconary at frame `2079`, Erdrick's Cave at frame `2804`, and Garinham at
  frame `3594`; Shift+R preserved each route and Shift+U stopped them cleanly.
  Tagged readiness at frame `6720` found World Map `(31,81)` with path target
  nil, zero NPC/runtime blockers, and no new script error.
  A thirty-seventh bounded slice continues the Kol return-corridor recovery
  and is source-complete and live-verified. Northern Cave, Mountain Cave, and
  Swamp Cave North now recognize the exact disconnected portions of the
  373-cell `kol_return_staging` corridor through their existing northwestern-
  return variants. Before the patch, they had 155, 82, and 155 openings
  respectively over the connected 24-step bound. Destination-specific bounds
  cover only those holes, and the Swamp Cave bridge alias can now consider the
  western return on the shared west strip without stealing its local bridge
  approach. All 1,119 combinations retain the selected target with no opening
  over 24 steps. From `(31,81)`, all three start `kol_return_staging` toward
  `Hauksness north ridge` at `(29,82)`, two steps west and one south. No
  waypoint geometry or movement timing changed. Focused route tests pass
  `335/335`; the full gate passes all 33 host-runnable Lua suites and all 68
  Python tests. Loaded starts retained Swamp Cave North at frame `2083`,
  Northern Cave at frame `2618`, and Mountain Cave at frame `3315`; Shift+R
  preserved each route and Shift+U stopped them cleanly. Fresh frame `6660`
  found World Map `(31,81)` with path target nil, zero NPC/runtime blockers,
  and no new script error.
  A thirty-eighth bounded slice continues the Kol return-corridor recovery and
  is source-complete and live-verified. Swamp Cave South, Rainbow Bridge, and
  Charlock now recognize the exact disconnected portions of the 373-cell
  `kol_return_staging` corridor through the existing
  `swamp_cave_south_mainland` wrapper. Before the patch, each destination had
  186 openings over the connected 24-step bound and opened the wrong
  `charlock_return` leg; at `(31,81)`, each attempted 37 steps. The selector
  expansion is limited to exact corridor cells and preserves local cave,
  bridge, and final-island starts. All 1,119 combinations retain the selected
  target with no opening over 24 steps. From `(31,81)`, all three start
  `kol_return_staging` toward `Hauksness north ridge` at `(29,82)`, two steps
  west and one south. No waypoint geometry or movement timing changed. Focused
  route tests pass `336/336`; the full gate passes all 33 host-runnable Lua
  suites and all 68 Python tests. Loaded starts retained Swamp Cave South at
  frame `1415`, Rainbow Bridge at frame `2881`, and Charlock at frame `4666`;
  Shift+R preserved each route and Shift+U stopped them cleanly. Fresh frame
  `7140` found World Map `(31,81)` with path target nil, zero NPC/runtime
  blockers, and no new script error. The remaining audit has only Tantegel's
  18 and Rimuldar's 9 overlong openings; Kol, Magic Temple, Cantlin, Hauksness,
  and Great Swamp are already clean.
  A thirty-ninth bounded slice completes the Kol return-corridor audit and is
  source-complete and live-verified. Tantegel's 18 remaining overlong openings
  lay on
  the west strip from `(8,43)` through `(12,30)`; Rimuldar's 9 lie on the
  Hauksness row from `(15,93)` through `(24,93)`. Exact bounded
  `kol_return_staging` selector regions reconnect only those holes to the
  established return, with no waypoint geometry or movement timing change.
  All 746 combinations—373 corridor cells for each destination—retain the
  selected target with no opening over 24 steps. Tantegel from `(8,40)` starts
  `kol_return_staging` toward `Western desert pass foot` in six steps, opening
  north. Rimuldar from `(20,93)` starts the same return toward `Hauksness lower
  west drop` in four steps, opening east. Focused route tests pass `337/337`;
  the full gate passes all 33 host-runnable Lua suites and all 68 Python tests.
  Loaded Tantegel started the expected return at frame `676`; Shift+R preserved
  its waypoint at frame `957`, and Shift+U stopped it at frame `3635`. Loaded
  Rimuldar started the expected return at frame `3965`; Shift+R preserved its
  waypoint at frame `4171`, and Shift+U stopped it at frame `4333`. Fresh frame
  `8940` found World Map `(20,93)` with route and path target nil, zero
  NPC/runtime blockers, and no new script error. The Kol-return audit is closed.
  A fortieth bounded slice closes the final known on-network corridor hole and
  is source-complete and live-verified. A uniform audit checked all 23,296
  combinations across 13 selector corridors and 16 destinations. Twelve
  corridors were clean; only Great Swamp travel failed from seven exact cells
  on `cantlin_return_staging`, falling through to `kol_staging` with invalid
  82-93-step openings. New `great_swamp_cantlin_return` reverses the
  established southern return suffix only from `(73,113)`, `(73,111)`,
  `(71,111)`, `(65,109-110)`, and `(63,107-108)`. The existing valid 15-step
  opening from `(74,113)` and all ordinary local routes remain unchanged. All
  85 Cantlin-return cells now retain Great Swamp with openings no longer than
  15 steps. Representative source checks open two steps east from `(73,113)`,
  one south from `(65,109)`, and one south from `(63,107)`. Focused route tests
  pass `338/338`; the full gate passes all 33 host-runnable Lua suites and all
  68 Python tests. Loaded starts selected the expected recovery at frames
  `388`, `3988`, and `7506`; Shift+R preserved each route and Shift+U stopped
  each cleanly. A frame `6240` teleport was safely refused while movement was
  unsettled, and the subsequent reposition completed normally. Fresh frame
  `10380` found World Map `(63,107)` with route and path target nil, zero
  NPC/runtime blockers, and no new script error. All known on-network selector
  corridors are closed.
  The first general off-network recovery slice is source-complete and
  live-verified in FCEUX. `preview_overworld_recovery` performs a read-only
  decoded A* search from the hero to the nearest safely reachable cell on the
  established waypoint network for the active Travel destination. The search
  blocks modeled hazards, runtime/static blockers, and landmark transition
  cells; rejects entries whose guided opening exceeds 24 steps; preserves the
  active destination and waypoint; and never queues movement or teleports.
  Structured `OVERWORLD_RECOVERY_PREVIEW` logging records the chosen entry,
  recovery length, next leg, final destination, and rejected-candidate counts.
  The first loaded attempt selected the expected Cantlin corridor but frame
  `17880` refused with `walkability_unavailable`, exposing that the production
  map reader still skipped map `0x01` while tests supplied a mock snapshot.
  `map_reader.lua` now decodes the ROM's 120-entry row-pointer and nibble-RLE
  overworld format, with water, mountains, and block tiles impassable. Focused
  tests pass `82/82` map reader, `22/22` pathfinder, `339/339` overworld routes,
  and `129/129` route manager; the full gate passes all 33 host-runnable Lua
  suites and all 68 Python tests. The repeat at `(58,108)` selected entry
  `(58,104)` with a four-step recovery and then `great_swamp_cantlin` /
  `Southern plains west road`. The preview preserved the active
  `cantlin_staging` route at waypoint index 35, position, nil path target, and
  zero blocker counts; no movement or new script error occurred. A zero-step
  follow-up at the selected entry `(58,104)` also passed: the
  ordinary route correctly targeted the adjacent `Southern plains west road`
  waypoint, while the preview reported `already_on_network`, entry `(58,104)`,
  and path length 0 without changing route index 25 or queuing movement.
  The first executable slice is source-complete and live-verified in FCEUX.
  Auto-walk now detects off-network starts, queues only decoded-safe recovery
  paths up to 24 steps, stops at the network boundary even in continuous mode,
  recalculates the unchanged final destination from the reached entry, and
  requires a second auto-walk press before guided travel resumes. Hazardous
  manual-only previews, over-limit paths, queue failures, and live blockers
  fail closed without handoff. The loaded run walked the four-step `(58,108)`
  to `(58,104)` recovery, stopped at the boundary in continuous mode, preserved
  Great Swamp, and required another auto-walk press. A confirmed poison-entry
  timing suspect at `(66,109)` stopped without movement; the next confirmed
  attempt reached `(66,110)` without drift and continued to the final
  `(89,112)` destination. Confirmed poison routes now suppress the generic
  guarded repress after an early committed twitch. Fresh frame `8160` found
  route none, nil path target, and zero runtime/NPC blockers. Focused tests pass
  `151/151` auto-step, `339/339` overworld routes, and `139/139` route manager;
  the authoritative Windows gate passes all 33 host-runnable Lua suites and all
  68 Python tests. Recovery does not teleport, require knowledge of route names,
  or silently cross hazards and unknown blockers.
- Early-route town-entry polish is live-verified for the Kol and
  Cantlin/Hauksness staging
  chain. Kol now bypasses Brecconary entrance `(48,41)` through west doorstep
  `(47,41)`, while a hidden `kol_staging` route hands connected destinations
  off at Kol west doorstep `(103,10)` instead of entering Kol `(104,10)`.
  Direct Kol travel still enters its requested destination, and accidental Kol
  entry remains a fallback handoff. A clean continuous Hauksness run from
  `(43,43)` bypassed Brecconary without entering map `0x08`, handed off at
  `(103,10)` without entering Kol map `0x07`, and arrived in Hauksness map
  `0x03` at `(0,10)`. Final route/path state was clear with zero runtime
  blockers. The next Cantlin validation exposed that its ordinary Hauksness
  intermediate leg still entered map `0x03`; Cantlin now uses hidden
  `hauksness_staging`, which stops outside at `(24,89)` and immediately targets
  `(22,89)` westbound. Direct Hauksness travel remains unchanged. Focused tests
  pass `191/191`; the broad gate passes all 33 host-runnable Lua suites plus 68
  Python tests. Loaded validation handed off on World Map `(24,89)` without a
  map change, moved west to `(22,89)`, and continued normally toward Cantlin.
  It arrived in Cantlin map `0x0A` at `(15,0)` with route/path state clear and
  no runtime blockers. This polish item is closed; audit other early
  destinations separately.
- The next early-route polish slice is live-verified for Garinham and Erdrick's
  Cave. Both outbound routes now use Brecconary west bypass `(47,41)` instead
  of intermediate town entrance `(48,41)`, then reconnect to the unchanged
  bridge corridor at `(44,38)`. Direct Brecconary travel remains unchanged,
  and the reverse Tantegel routes already avoid the town. Focused tests pass
  `194/194`; the broad gate passes all 33 host-runnable Lua suites plus 68
  Python tests. Separate loaded runs from World Map `(43,43)` bypassed
  Brecconary without entering map `0x08`, then arrived in Garinham map `0x09`
  and Erdrick's Cave map `0x1C` with clean final route/path state and zero
  runtime blockers. This slice is closed.
- Preserve object focus while routing. Internal waypoint selection must not
  replace the player's selected destination, and route status should explain
  the current recovery leg, next waypoint, and final destination.
- Completion criteria: route between every supported overworld landmark from
  arbitrary reachable world-map starts, recover after deliberate manual drift,
  and resume safely after battles, menus, and dialogue.

## Game Mechanics and Accessible Discovery

- Darkness parity: add logic so navigation cannot bypass the game's darkness
  mechanic. Object discovery, map descriptions, path previews, routing, and
  auto-walk in dark areas should reveal or use only information available
  within the current Torch/Radiant light radius. Announce equivalent nonvisual
  information about the visible area, changing light radius, and expiring
  light without exposing the full dungeon layout.
- Design darkness handling as its own feature with deterministic and live
  tests. Check unlit entry, Torch use, Radiant use and expiry, movement near the
  light boundary, object browsing, route recalculation, and script reload.
  The active first-slice design is documented in
  `docs/plans/2026-09-03-darkness-parity.md`.
- The first darkness slice is source-complete and live-verified in Erdrick's
  Cave B1. Unlit, Torch, Radiant expansion, moving visibility, object masking,
  and every meaningful shrink boundary passed. A light-bounded local layout
  report (`Shift+N` or `F21`, plus `visible_area`) and the original strict and
  unrestricted `darkness_navigation_limits` behaviors are live-verified in
  Radiant, unlit, moving-window, and unrestricted-navigation states. Dynamic
  darkness-aware auto-walk is now source-complete: every queued interior step
  rechecks the next cell, selected destination, and complete remaining route
  against the live light square; hidden route tails stop before input, while
  drift/blocker retries retain the darkness policy. Live acceptance passed in
  Erdrick's Cave B1: a visible stair approach completed normally, while a
  17-step route to the hidden entrance stopped before step two immediately
  after restrictions were re-enabled.
  A balanced intermediate mode is now source-complete as the shipped default:
  navigation remains unrestricted while Torch or Radiant exposes neighboring
  tiles, then remote browsing/planning and active auto-walk cut off when the
  light expires. `authentic` keeps the strict behavior and `unrestricted` keeps
  full assistance; legacy `true`/`false` values remain compatible. Live
  lit routing is verified in both directions on Erdrick B1. That pass promoted
  `(6,3).west` only after nine normal failures plus nine same-origin seam
  failures; three post-reload 17-step routes then completed without reroutes or
  runtime blocks. The natural cutoff is also live-verified: Radiant reached raw
  radius `1` during an active route, autowalk stopped at `(7,7)` before hidden
  `(8,7)`, and the full recovery warning was delivered. Final state had no
  active path, blockers, or pending speech. This darkness slice is closed.
  Retain progressive-discovery work as a later slice. Deferred warning
  delivery is source-complete on `codex/deferred-warning-delivery`: important
  warnings wait for a short keyboard/controller-neutral window, retain separate
  FIFO message records for future speech history, and passed live held-key
  acceptance with both JAWS and NVDA.
- Clue-bound treasure first pass is complete (`2026-09-06`). Kol exposes
  `Bath` under Travel at the water tile `(9,2)`, with an approach at `(9,3)`
  facing north. The exact Fairy Flute SEARCH object is removed, including from
  unfiltered lookup and Treasure. Live auto-walk reached the bath edge from
  `(9,6)` without retries or runtime blockers. The buried-reward audit also
  checked Erdrick's Armor (already absent; only the Axe Knight approach is
  exposed) and Erdrick's Token (the existing Great Swamp destination stops
  away from the hidden tile). Visible ROM chests retain ordinary navigation.
  All 35 host-runnable Lua suites and 68 Python tests pass.
- Later progressive-discovery work: track received clues and offer optional
  stronger search cues. The completed first pass does not automatically reveal
  treasure through proximity, clue receipt, or an invented environmental hint.

## Quality of Life

### Endgame narration polish

- Detect the credits and terminal `The End` sequence separately from the
  ordinary title screen. Preserve the successfully narrated story and staff
  credits, suppress the premature `Title screen.` announcement, filter the two
  decorative-glyph fragments after the copyright line, and announce a concise
  `The End.` once when the terminal screen settles.

### In-game mod configuration

- The first grouped spoken configuration menu is implemented on
  `codex/in-game-mod-settings`; core live acceptance passed. Shift+F11 opens,
  Shift+F12 explains, Left/Right switches groups, Up/Down selects, Enter edits,
  Control+Enter saves, and Escape discards. Initial options cover auto-step,
  continuous travel, darkness mode, browsing speech delay, and route progress.
  Defaults can restore one group or all exposed settings. All 37 Lua suites
  and 68 Python tests pass. The player accepted browsing/help, edit/discard,
  and save/reload persistence. The saved file changes only the selected value;
  the backup preserves the original. Controller isolation and active-route
  interruption also passed live: controller presses do not operate the game
  or the keyboard-only settings menu, and opening settings stopped two active
  auto-walks with parked NPCs restored. This first implementation is closed.
- Low-health warnings are source-complete on `codex/low-health-warnings`;
  threshold-triggered live speech acceptance passed. Announcements exposes an enabled-by-default
  toggle and a 25-percent default threshold (menu range 5-100 in steps of 5).
  The detector observes battle and field HP independently of generic damage
  narration, warns once at/below the threshold, and rearms above it. Loading
  alive with low HP also warns once. Pending warnings update to current HP
  and cancel on recovery/death/disable, preserving other warning records.
  All 39 Lua suites and 68 Python tests pass. The player heard one complete
  deferred warning at temporary threshold 100 percent; restoring 25 percent
  rearmed the detector. Combat/healing acceptance also passed at a 75-percent
  threshold: three delivered battle warnings were separated by two confirmed
  above-threshold rearm events. Sustained held-movement speech also passed
  live in the eastern swamp: the warning refreshed pending HP and delivered
  after release at 12 neutral frames. Off/On testing
  exposed stale FCEUX Space blocking speech despite physical release. The
  source fix uses fresh v3 keyboard-bridge activity for warning timing and
  retains legacy fallback/controller checks. All gates pass. Post-fix live
  Off/On and reload-while-low acceptance passed: the player heard the alert,
  logs confirmed delivery after 12 neutral frames, and no warning remained
  pending. Core low-health functionality is live-accepted.
- Travel warnings has a saved, default-On toggle under Announcements on
  `codex/travel-warning-setting`. It now controls dangerous-tile prompts,
  hazard route warnings, light changes, and
  hazard/darkness auto-walk stops. Disabling cancels pending travel records
  without cancelling low-health warnings or weakening movement safeguards.
  Required auto-walk swamp confirmation prompts remain audible when muted.
  Menu/save and runtime mute acceptance passed on the Kol-to-Swamp-Cave route;
  hazard confirmation still applied and no warnings were queued or delivered.
  Live re-enable acceptance passed with Radiant expansion and dimming after
  fixing the retained speech-module config reference across Lua reloads.
  All 39 Lua suites and 68 Python tests pass. See
  `docs/travel-warnings.md` for the audited message scope.
- Future settings: a Speech group/submenu.
  Add them as the underlying
  behavior becomes available; muting narration must not disable movement
  safeguards.
- The grouped Key Reference is source-complete on `codex/key-reference-screen`;
  live acceptance passed. Shift+F12 opens it outside Mod Settings and still
  gives contextual help inside settings. Groups cover Gameplay, Information,
  Object Navigation, Travel, Optional Movement, and Mod Settings. Enter only
  explains; bindings come from the loaded config, and the shared menu capture
  stops auto-walk and prevents input from reaching the game. All 38 Lua
  suites and 68 Python tests pass. The player also confirmed normal game
  controls and script hotkeys resume after closing. This slice is closed.
- Settings must announce their current value, explain consequential changes,
  persist safely, and provide a restore-defaults path. Keep developer-only or
  unsafe diagnostics clearly separated from ordinary player settings.

### Object navigator

- First object-sorting slice is source-complete on `codex/object-sort-order`.
  Navigation offers Distance (default, Manhattan tile distance) and
  Alphabetical (case-insensitive name, stable ID ties). Saving announces the
  new sort mode once; category/reachability announcements include the mode.
  Re-sorting and ordinary object refresh retain selection by ID and preserve
  filtering. Live sorting acceptance passed in Kol and on the overworld;
  Alphabetical and Distance saves were confirmed in the log. All 39 Lua
  suites and 68 Python tests pass. This first slice is complete.
- Sort shortcut is source-complete on `codex/object-sort-hotkey`: configurable
  Shift+Q switches Distance/Alphabetical and saves the shared preference.
  Selection and filters remain intact; failures preserve the existing order
  and report the save error. Key Reference includes it. Held-key and save
  failure regressions pass. Live shortcut, persistence, and menu synchronization
  acceptance passed in both sort modes. All 39 Lua suites and 68 Python tests
  pass. This slice is complete.
- Sorting and its Shift+Q shortcut are merged and pushed to `main` at `fed84fb`.
- First quick-services slice is implemented on `codex/quick-services`;
  player acceptance passed on 2026-09-10. Shift+P jumps directly to the current map's existing Services
  category, retaining sorting and reachability filters. J/K/L browse, U approaches;
  opening never starts movement. Reopening retains the selected service. Service
  descriptions report reachability and known blockers, with distinct feedback
  for an empty map, a filtered-empty list, and a map still loading.
  Key Reference and the `quick_services` debug command expose the same action.
- Prioritize a Kol service-route polishing pass next. The 2026-09-10 Tool
  Merchant walk from (19,23) to stand (12,21) hit repeated reroutes and did not
  arrive before the player stopped it. Reproduce the failed west approaches
  at (16,23), (10,17), and (7,14), distinguish geometry from timing/NPC state,
  and verify approach/return routes for all three services. Single-run evidence
  is recorded in `work_notes/current_investigation.md`; no map data promoted.
- Consider service-type search or cross-town service lookup after the current-map
  shortcut is playtested; reuse verified service roles and interaction stands.
- Add named bookmarks for player-chosen locations such as a favorite grinding
  spot. Define whether bookmarks are save-slot-specific or global, persist them
  across script reloads, and integrate them with overworld/interior routing
  without displacing the currently selected object unexpectedly.

## Tooling

- Image parsing helper: consider adding Pillow support in a repo-local Python
  virtual environment, or commit a small built-in PNG sampler for indexed map
  images. Goal: make saved visual map references, such as
  `project_resources/maps/brecconary/mikesrpgcenter_brecconary.png`, easier to
  sample and describe without relying on external image tools. This is optional
  QoL; live movement probes remain authoritative for map passability.

## Process

- Keep `TASKS.md` as the canonical high-level roadmap. Create focused design
  and implementation plans under `docs/plans/` only when a roadmap item becomes
  active; link those plans back here rather than copying detailed task lists
  into multiple files.

## Map Decoding

- Brecconary Merchant 4 optional follow-up: the current evidence says the
  southeast tool-shop pocket is isolated/locked from the public waypoint graph,
  not explained by either known Brecconary door. If gameplay later suggests the
  tool shop should be reachable, add a small debug helper to test TALK from a
  chosen coordinate/facing, then re-check possible customer stands around
  `(25,27)` before changing more map data.
