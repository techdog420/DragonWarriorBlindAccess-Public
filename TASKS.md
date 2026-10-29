# Project Roadmap and Backlog

Updated: 2026-10-29

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
  recorded pass on 2026-10-28 covered 44 host-runnable Lua suites and 82 Python
  tests, plus syntax, speech dependency, and command-queue checks.
  `test_screen.lua` and
  `test_speech.lua` require live FCEUX and are explicitly skipped.
- The current package passed actual non-ASCII Windows account acceptance on
  2026-10-15 under `C:\Users\DWTest-é`: supported ROM install, two NVDA launches,
  King battery save/reload, private paths and manual movement. The corrected
  diagnostic collector preserved an advancing keyboard heartbeat. No package
  changes were needed. See `work_notes/non_ascii_account_20261015.md`.

## Release and narration

Ending narration polish completed 2026-09-30 in `86252b0`: final-screen
NVDA/player acceptance and a full patched replay passed. Story/credits/copyright are
preserved, title/artwork fragments suppressed, and The End announced once
per ending. Gate passed 42 Lua suites and 68 Python tests. See `PLAYTESTING.md`.

1. Choose the final public version and publication destination for the next
   player release. Local qualification of `2026.10.15-qualification1`, built
   from `b6261ba`, completed 2026-10-15: player/source repeat builds are
   byte-identical; manifest/source matching, ROM/save exclusion, clean install,
   and separate NVDA/JAWS launch, gameplay, normal King save, exit, and battery
   reload checks pass. NVDA restored the new 4-experience-to-level marker;
   JAWS restored its earlier 5-point marker. This is current candidate evidence,
   separate from the historical alpha. Any changed payload needs qualification
   of its final artifacts. Nothing has been published from this pass.
   See `docs/plans/2026-10-15-player-package-qualification.md`.
   The 2026-10-16 source review subsequently fixed keyboard write-lock recovery,
   literal dollar-sign installation paths, Lua speech pipe errors, and speech
   test/queue gaps. The original ZIPs remain unchanged. The new
   `2026.10.23-qualification1` player/source ZIPs include these and the
   player-accepted darkness speech fixes. Repeat builds, manifests and clean
   install/validation pass. Fresh package smoke in C:\tmp1 is player-accepted
   with NVDA: ROM discovery, startup, character creation, quest start and
   initial gameplay. The candidate is ready for alternate-hardware validation.
   See `work_notes/darkness_fixes_20261023.md` and
   `docs/reviews/2026-10-16-pre-release-code-review.md`; broad refactoring is
   deferred because no demonstrated gameplay benefit offsets its release risk.
   The October 29 `2026.10.29-qualification1` rebuild now includes descriptions
   from `90e50d0`: repeat builds, archive audits, and clean install/validation
   pass. Use this new candidate for the tester's check.
   Representative source description listening is accepted; fresh package
   gameplay and alternate-hardware acceptance remain open. See
   `work_notes/packaging_qualification_20261029.json`. Official release is
   conditional on no issues from that check; no assets have been published.
2. Expand hardware and blind-player testing beyond the single complete run
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

The broader representative Travel pass completed on 2026-10-15. It fixed
Charlock selection, disconnected openings, and staged destination recovery;
covered additional regional selectors and all 16 model audits; walked four
24-step checkpoints plus a 14-step network boundary; and verified explicit
resume and Kol arrival/exit. Physical TALK and REPEL result/refusal/dismissal
are player-accepted. See `docs/plans/2026-10-13-travel-acceptance.md` and
`PLAYTESTING.md` for scope and evidence. This does not establish every
world-map cell, quest state, or destination as live-traversed.

Remaining watch items:

1. During normal play, capture physical in-battle Shift+R and an independent
   dialogue-only onset if a suitable case occurs. Existing battle interruption
   and combined menu/text results are covered; avoid a separate battle grind
   or injected dialogue flags solely to fill these acceptance gaps.
2. Treat isolated timing, moving-NPC, and FCEUX input-latch reports as watch
   items. Reproduce one in a fresh state before adding a permanent map rule.
   The 2026-10-02 `(56,57)->UP` stop crossed with a same-origin probe and
   passed the repeated recovery/guided handoff without timeout retries.
   The 2026-10-13 western recovery carried from `(11,30)` to `(11,31)` and
   cancelled conservatively; all five 2026-10-15 checkpoint/network stops
   landed exactly. Reproduce the original case before changing timing or maps.

## Accessible discovery and quality of life

`SPEECH-LATENCY-01` remains open: the player perceives NVDA delay relative to
JAWS during browsing/dialogue. Initial standalone profiling found a 0.907 ms
median pipe-write-to-API-return time and 31-53 ms NVDA beginning-mark callbacks.
These do not measure physical key-to-audio latency or compare JAWS onset.
No production fix is justified yet. Next: controlled in-game input/audio timing
with equivalent actions. Preserve the qualified package and reader settings.
See `work_notes/nvda_responsiveness_20261015.md` and `PLAYTESTING.md`.

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

## Map artwork descriptions - representative acceptance complete (2026-10-29)

Implemented and source-reviewed for all 28 interiors. The player accepted
Tantegel's throne room, Tantegel main floor, and Brecconary on October 28,
then additional towns and multiple floors in Garin's Grave and Charlock on
October 29. Exact additional map IDs were not enumerated. Keep the accepted
style and length; no full map tour or further editorial pass is required.
Physical-light, interruption, and continued auto-walk cases have host coverage
but were not individually reported in these listening checks. Capture fresh
issues during ordinary play. The next release gate is the tester's alternate-hardware
validation. The player authorized commit/push and
a new package including descriptions; official publication remains conditional
on that check. Source index: `project_resources/maps/descriptions/README.md`.
