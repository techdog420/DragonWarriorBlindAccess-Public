# Project Roadmap and Backlog

Updated: 2026-10-02

This file lists work that remains open. Current runtime state and resume steps
belong in `session_handoff.md`; dated gameplay evidence belongs in
`PLAYTESTING.md`. The completed route and map history formerly kept here is
preserved in `handoff_archive/TASKS_2026-09-24_pre_cleanup.md`.

## Current baseline

- Map cleanup is complete by player acceptance. Brecconary, Kol, Garinham,
  Rimuldar, Cantlin, and all three Tantegel Castle floors received focused
  player-facing route passes. Charlock and the other established dungeon routes
  were completed earlier. Reopen a map only for a new gameplay failure backed
  by fresh movement evidence.
- Connected Travel routes, the known on-network selector corridors, and the
  first bounded off-network recovery are implemented and live-verified in
  representative FCEUX runs. These passes do not prove every arbitrary start or
  interruption case.
- Darkness-aware navigation, clue-bound treasure presentation, grouped spoken
  settings, Key Reference, object sorting, quick Services, low-health warnings,
  and Travel warnings have completed their recorded implementation and live
  acceptance slices. Their older branch names and test counts are historical.
- The published `v0.1.0-alpha` package passed separate JAWS and NVDA install,
  gameplay, save, and relaunch checks, and one blind-player run reached the
  original `The End` screen. The current source is newer than that package.
- The current native Windows gate is `python -u run_tests.py`. The latest
  recorded pass on 2026-10-02 covered 42 host-runnable Lua suites and 68 Python
  tests, plus syntax, speech dependency, and command-queue checks.
  `test_screen.lua` and
  `test_speech.lua` require live FCEUX and are explicitly skipped.

## Release and narration

Ending narration polish completed 2026-09-30 in `86252b0`: final-screen
NVDA/player acceptance and a full patched replay passed. Story/credits/copyright are
preserved, title/artwork fragments suppressed, and The End announced once
per ending. Gate passed 42 Lua suites and 68 Python tests. See `PLAYTESTING.md`.

1. Plan and qualify the next player package from current source. Rebuild the
   player and corresponding-source artifacts, verify deterministic contents and
   ROM/save exclusion, and repeat separate JAWS/NVDA launch, gameplay, save,
   and relaunch acceptance before publication. The existing alpha checks are
   historical evidence, not acceptance of the post-alpha source.
2. Test the final package under an actual Windows account with a non-ASCII
   username. Install the supported ROM, launch twice with NVDA, create and
   reload a save, and verify private config, speech log, and keyboard bridge
   paths. The earlier non-ASCII extraction-folder test did not cover this.
3. Expand hardware and blind-player testing beyond the single complete run
   when preparing a broader release. The supported, tested ROM remains
   `Dragon Warrior (USA) (Rev 1)`.

## Routing and gameplay reliability

The specific Hauksness return-corridor validation gap closed on 2026-10-02.
Loaded FCEUX checks at `(73,96)` passed for Rimuldar, Magic Temple, and Charlock:
each selected `Cantlin north road` at `(73,91)`, preserved its final destination
in read-only status, and cancelled cleanly. The player confirmed Shift+R,
Shift+U, and the resulting speech. See the dated `PLAYTESTING.md` entry.

The representative Tantegel menu/battle/manual-drift check also passed on
2026-10-02. It exposed and fixed a selector gap on known Charlock corridor
cells: Tantegel now reuses the established return instead of a direct castle
opening. Recovery stopped at the network boundary, explicit resume worked,
and interruptions retained the destination without restarting movement.

1. Complete the broader Travel acceptance criteria: supported destinations
   from other reachable world-map start regions, additional destination/drift
   combinations, and field-dialogue interruption/resume. Build on the recorded
   Tantegel menu/battle/drift pass and bounded off-network recovery. Preserve
   the selected destination and explain the recovery leg and next waypoint.
   Do not silently cross hazards or promote timing stalls to map blockers.
2. Treat isolated timing, moving-NPC, and FCEUX input-latch reports as watch
   items. Reproduce one in a fresh state before adding a permanent map rule.
   The 2026-10-02 `(56,57)->UP` stop crossed with a same-origin probe and
   passed the repeated recovery/guided handoff without timeout retries.

## Accessible discovery and quality of life

1. Design a later progressive-discovery slice for hidden treasures: track
   received clues and offer optional stronger search cues after clue receipt,
   exploration, or proximity. The completed Kol Bath landmark and the
   non-exact Hauksness armor/Great Swamp token guidance must remain
   spoiler-safe by default. Preserve original information constraints while
   giving an equivalent nonvisual cue when the game supplies a visual one.
2. Add a Speech group to the spoken settings menu when there are meaningful
   speech controls to expose. Muting narration must not disable movement
   safeguards or required hazard confirmation.
3. Consider service-type search or cross-town service lookup after the
   current-map `Shift+P` shortcut. Reuse verified service roles and stands.
4. Consider named player bookmarks for places such as grinding spots. Decide
   whether they are save-slot-specific or global, persist them across Lua
   reloads, and avoid changing the selected object unexpectedly.

## Optional tooling

- Add a repo-local PNG sampler only if saved map images need text-based
  inspection again. Live movement remains authoritative for passability.

## Working rules

- Activate one backlog item at a time with a focused plan under `docs/plans/`
  when needed; keep this file short and update its status when work closes.
- Begin any reopened town audit with raw0 grass/raw4 stone classification,
  doors, and hazards. Do not infer one map's table from another without live
  evidence.
