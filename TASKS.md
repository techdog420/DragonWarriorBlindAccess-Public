# Project Roadmap and Backlog

Updated: 2026-08-26

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
- Off-network recovery: when a player manually explores or gets lost, provide a
  player-facing command that finds a safe route back to the nearest reachable
  waypoint-network entry and then continues toward the selected destination.
  Recovery must not teleport, require knowledge of route names, or silently
  cross hazards and unknown blockers.
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
- Clue-bound treasure audit: identify every place where object navigation or
  routing leads directly to a treasure whose location the original game expects
  the player to infer from dialogue or environmental clues.
- Fairy Flute first pass: consider exposing Kol's bath as the initial landmark
  rather than exposing the exact search tile. After the player has received the
  clue and explored near the bath, provide progressively stronger search cues;
  keep exact tile guidance optional. Apply the same pattern to other hidden or
  clue-bound treasures found by the audit.

## Quality of Life

### Endgame narration polish

- Detect the credits and terminal `The End` sequence separately from the
  ordinary title screen. Preserve the successfully narrated story and staff
  credits, suppress the premature `Title screen.` announcement, filter the two
  decorative-glyph fragments after the copyright line, and announce a concise
  `The End.` once when the terminal screen settles.

### In-game mod configuration

- Add an accessible in-game configuration surface rather than requiring manual
  INI edits. Candidate settings include auto-step on/off, speech backend and
  speech options, verbosity, and debug mode.
- Settings must announce their current value, explain consequential changes,
  persist safely, and provide a restore-defaults path. Keep developer-only or
  unsafe diagnostics clearly separated from ordinary player settings.

### Object navigator

- Add selectable sort orders, beginning with distance and alphabetical order.
  Announce the active category, pathability filter, and sort order without
  making rapid object browsing noisy.
- Add search and/or quick access for common services such as inns, shops,
  healers, keys, and save points. Results must still report reachability and
  the reason when a service cannot currently be reached.
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
