# Project Roadmap and Backlog

Updated: 2026-08-12

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

- Player-facing auto-walk stop is implemented in source with configurable
  default `Shift+U`. It cancels active or deferred movement before ordinary
  battle/dialogue/menu object guards, clears queued steps and route-manager
  context, force-releases held direction input, preserves the selected object
  and guided Travel destination, and announces active versus idle results. Two
  live FCEUX/JAWS cancellations stopped multi-step routes with no queued-step
  restart, and a fresh probe confirmed no active path. Focused and broad tests
  pass; this item is closed.
- Begin the connected overworld travel network and off-network recovery work
  below.

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
  route data is preferred over replacing live-validated segments.
- Off-network recovery: when a player manually explores or gets lost, provide a
  player-facing command that finds a safe route back to the nearest reachable
  waypoint-network entry and then continues toward the selected destination.
  Recovery must not teleport, require knowledge of route names, or silently
  cross hazards and unknown blockers.
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
