# Session Handoff - Active Resume

Updated: 2026-10-29

This is the short current-state entry point. `TASKS.md` is the open roadmap;
`PLAYTESTING.md` holds dated gameplay evidence; `PROJECT_MEMORY.md` holds
durable architecture and workflow lessons. The former 4,528-line handoff is
preserved at `handoff_archive/session_handoff_2026-09-24_pre_cleanup.md`.
Its old branch, frame, test-count, and "next work" statements are historical,
not instructions for the current checkout.

## Project state

- New local candidate `2026.10.29-qualification1` includes all map artwork
  descriptions from `90e50d0`. Native Windows gate passed 44 Lua suites and
  82 Python tests. Player/source archives are repeat-build identical; independent
  manifest, source, hash, exclusion-policy, and clean archived install/validation
  checks pass. No emulator was started for the archived checks; a gameplay smoke
  pass for these exact ZIP bytes is not claimed. The player accepted broader
  source spot checks across Garin's Grave, Charlock, and more towns. the tester's
  alternate-hardware check is pending;
  official release remains conditional on no issues. New artifacts are under
  `.tools/release-output/`; older candidates remain preserved. See
  `work_notes/packaging_qualification_20261029.json` and its companion Markdown.
- Map artwork descriptions added 2026-10-28 in development source: all 28
  interior maps have short, spoiler-safe paragraphs. Shift+D (configurable
  `key_map_description`) and read-only `describe_map` use queued speech and leave
  movement unchanged. Dark dungeons require physical light even with unrestricted
  navigation. Images, map bindings, sources, hashes, and editorial policy are in
  `project_resources/maps/descriptions/README.md`. The player accepted descriptions
  for Tantegel Throne Room, Tantegel main floor, and Brecconary on 2026-10-28:
  useful general descriptions without information overload. Follow-up editorial
  review completed all remaining 25 paragraphs against their NES images, keeping
  each at 71-80 words and preserving the three accepted paragraphs unchanged.
  Focused description tests and Lua syntax pass; see the linked editorial review
  in the source index. On 2026-10-29 the player accepted additional spot checks
  across multiple floors in Garin's Grave and Charlock and additional towns.
  Exact floors/towns were not enumerated. Description authoring and representative
  listening acceptance are complete; individual light/interruption/auto-walk cases
  were not separately reported. The player authorized commit/push and a fresh
  package; official release remains conditional on the tester's alternate-hardware check.
  Native Windows `python -u run_tests.py` passed: 44 Lua suites, 82 Python
  tests, syntax, speech dependency, and command queue checks. Existing qualified
  ZIPs are preserved and do not include this feature.
- Darkness speech fixes completed 2026-10-23: Radiant's animated expansion now
  produces one final-radius announcement, preserving navigation restoration;
  World Map ignores dungeon light/terrain bytes on exit. Both are player-accepted
  after manual Lua reload with NVDA. Focused suite: 21 tests; final host gate:
  43 Lua suites and 82 Python tests. New local `2026.10.23-qualification1`
  player/source ZIPs include these and the October 16 hardening fixes; repeat
  builds and archive/clean-install checks pass. Fresh packaged launch smoke is
  player-accepted at `C:\tmp1\Dragon Warrior Accessibility 2026.10.23-qualification1`:
  ROM install/discovery, NVDA startup, character creation, quest start and initial
  gameplay pass; all 525 installed payload hashes match. Ready for alternate-
  hardware validation; publication remains open. See
  `work_notes/darkness_fixes_20261023.md` and
  `work_notes/packaging_qualification_20261023.json`.
- Pre-release source review completed 2026-10-16 with focused local fixes for
  keyboard sharing-lock recovery, literal dollar-sign paths in FCEUX config,
  speech pipe error detection, and speech test/queue gaps. Final host gate:
  43 Lua suites and 82 Python tests. No movement/map changes or live acceptance
  were performed. The qualified `2026.10.15-qualification1` ZIPs are unchanged;
  the October 23 rebuild includes these fixes and has passed the fresh packaged
  player smoke test. Full findings and
  refactor assessment: `docs/reviews/2026-10-16-pre-release-code-review.md`.
- The user reports map cleanup complete. The latest accepted pass closed all
  three Tantegel Castle floors on 2026-09-22: main-floor services, doors, four
  chests, 18 non-service NPCs, and two secondary entrances; Throne Room door,
  three chests, three guards, and King; Sun Shrine chest and Old Man. Guard5
  required deliberate manual damage-floor crossings. Safe automatic hazard
  refusal remains correct. See the dated castle record in `PLAYTESTING.md`
  and `handoff_archive/current_investigation_2026-10-15_pre_travel_wrap.md`
  for exact routes and frames.
- Brecconary, Kol, Garinham, Rimuldar, and Cantlin town passes are also
  player-accepted. Charlock's dungeon spine, branches, chests, Dragonlord,
  and post-victory return were completed earlier. Do not resume broad map
  decoding from an older checkpoint; investigate only a fresh play failure.
- The map-specific Bank00 town collision corrections keep raw0 grass
  walkable and raw4 stone blocked where verified. Door, directional, hazard,
  and moving-NPC behavior remain separate. An isolated timing retry or
  NPC obstruction is not evidence for a permanent map block.
- Connected overworld Travel routes and the known on-network selector
  corridors have extensive source and representative live coverage. The first
  bounded off-network recovery also passed live FCEUX acceptance. The broader
  representative destination/recovery and field-result acceptance pass completed
  on 2026-10-15. Coverage limits remain explicit below and in `PLAYTESTING.md`.
- The final Hauksness return-corridor selector check closed on 2026-10-02.
  At World Map `(73,96)`, Rimuldar, Magic Temple, and Charlock each selected
  `hauksness_return_staging`, waypoint 2 `Cantlin north road` at `(73,91)`.
  Separate status checks preserved the final destination and position;
  cancellation cleared guidance. The player confirmed Shift+R/Shift+U speech
  for Charlock. This closed the loaded selector/status/cancellation gap;
  broader representative acceptance followed on 2026-10-15.
- Representative Tantegel menu/battle/manual-drift validation passed on
  2026-10-02. A narrow selector fix makes known Charlock corridor starts use
  `charlock_return`, with alias/object regression coverage. Menu and battle
  interruptions retained Tantegel and stopped movement; one-east recovery
  from `(55,57)` stopped at the network boundary and required explicit resume.
  One initial north-step timing stop crossed normally in a same-origin probe
  and passed a repeated guided handoff. Keep it as a watch item, not map data.
- The 2026-10-13 broader pass reproduced other destinations choosing direct
  mainland openings at normally walked Charlock corridor `(51,50)`, through
  decoded mountain cells north of `(51,49)`. Ten existing south-island
  variants now also match `charlock_return` / `charlock_castle`. A 150-case
  regression passes. After manual reload, all 16 loaded selectors passed at
  `(51,50)`, and Brecconary's corrected one-north opening completed normally.
  Geometry and map data are unchanged. The player accepted physical field-TALK
  status/refusal/dismissal in the combined menu/result state; D cleared both
  without restarting movement. This does not isolate dialogue-onset cancellation.
- A later western start reproduced another disconnected opening. The general
  guard now checks every opening step against the selected route's corridor,
  redirects unsafe openings to bounded recovery, and filters corner-cutting
  recovery entries. After the second manual reload, western recovery safely
  walked south instead of north/east through mountains. Battle interruptions
  retained Brecconary. A final one-tile carry past the proposed entry cancelled
  conservatively; subsequent stale-guidance recalculation stopped without
  movement, and explicit resume completed three established guided legs.
  The isolated recovery carry remains a watch item.
- Regional selector/preview checks also exposed internal staging IDs restricting
  recovery. A public destination request ID now preserves the selected target
  while allowing recovery to choose the appropriate corridor from its new
  origin. After the third manual reload, both Swamp Cave previews passed at
  `(73,96)`. All 16 fresh model audits completed with unreachable 0. Four 24-step
  checkpoints plus a final 14-step network entry stopped exactly; every resume
  was explicit despite continuous Travel. Kol arrival cleared guidance and
  stopped movement; normal exit worked. The player accepted REPEL-result
  Shift+R/U-refusal/D dismissal, and explicit post-dialogue resume passed.
  TALK/REPEL both retained a menu, so independent dialogue-only onset and
  physical in-battle status speech remain unaccepted coverage cases.

## Accessibility and release state

- The recorded darkness, low-health/Travel warning, spoken settings, Key
  Reference, object sort, quick Services, and clue-bound treasure first slices
  are accepted. Terminal ending narration was implemented 2026-09-30 in
  `86252b0`; the player heard The End after reload with NVDA and fresh polling
  confirmed.
  Gate passed 42 Lua suites and 68 Python tests. Full patched replay then
  preserved story/credits/copyright, suppressed title/artwork fragments, and
  announced The End once. Ending polish is complete; progressive discovery
  remains in `TASKS.md`.
- The published `v0.1.0-alpha` tag is at `133d65c` (2026-07-31). This source
  snapshot includes the ending fix, Tantegel validation through `63c64d6`, and
  the three broader Travel fixes, regressions, and acceptance records completed
  on 2026-10-15. Check Git history and remote state for the exact publication
  commit. The alpha package is not a build of current source.
  Its separate JAWS/NVDA acceptance and licensing/source-package checks remain
  historical release evidence.
- Local candidate `2026.10.15-qualification1` now builds the `b6261ba` app
  payload. Player and matching corresponding-source ZIPs are under
  `.tools/release-output/`; two builds of each are byte-identical. Independent
  manifest/hash/source/policy checks and clean install/validation pass.
  Separate NVDA and JAWS launch, gameplay, normal King save, exit, and battery
  reload are now player-accepted. Each reader was active alone and selected
  automatically. JAWS restored its 5-experience-to-level progress; NVDA then
  saved new progress and restored the 4-point marker, confirmed by fresh speech
  and the player. The early FCEUX slot save is recorded separately from the
  accepted normal battery saves. Local qualification is complete; no runtime
  source/config changes were needed. Raw logs and save backups remain under
  `.test_tmp/packaging-20261015-baseline/`. The pristine artifact pair is still
  unpublished; final version/destination and broader release checks remain.
  See `docs/plans/2026-10-15-player-package-qualification.md` and
  `work_notes/packaging_qualification_20261015.json` for hashes and scope.
- Actual non-ASCII account acceptance is complete under `C:\Users\DWTest-é`,
  SID ending `1021`, session 2 with NVDA. Supported ROM install, two launches,
  private config/log/input paths and normal King battery save/reload passed.
  Run 002 restored LOKI's 5-XP marker; the player confirmed manual arrows, with
  fresh position speech and v3 heartbeat advancing from 3 to 1017 over more than
  four minutes. FCEUX was left running in that account; Codex remains `developer`.
  Run 001's input failure was traced to a likely diagnostic artifact: the old
  `Copy-Item` collector twice reproduced a fatal sharing error against the
  unchanged helper. Shared-read snapshots fixed the collector and passed both
  stress and actual account retests. No ACLs or qualified package files changed.
  Evidence: `work_notes/non_ascii_account_20261015.md` and local
  `.test_tmp/non_ascii_account_20261015/accepted-run-002/`.
  Separately, the D: Unicode extraction correctly refused launch when Windows
  supplied no fully ASCII compatibility path, verifying the relocation fallback.
- Post-package follow-up `SPEECH-LATENCY-01`: the player reports NVDA feels
  slower than JAWS for object browsing and arriving dialogue during the quick
  reader switch. Initial standalone profiling completed with FCEUX closed:
  nine samples showed 0.907 ms median / 1.171 ms maximum from pipe write to
  NVDA API return; separate beginning-mark callbacks took 31-53 ms. These
  measure different stages and are not actual audible-onset timings or a JAWS
  comparison. The player could not judge isolated samples confidently. No
  production code/reader setting changed; package hashes remain intact.
  Cause remains unresolved. Next useful evidence is controlled in-game
  input-to-audio timing. See `work_notes/nvda_responsiveness_20261015.md`.

## Verification and runtime rules

- The latest recorded `python -u run_tests.py` pass on 2026-10-29 covered
  44 host-runnable Lua suites, 82 Python tests, Lua/Python/shell syntax, speech
  dependency, and command queue checks. Focused counts are 346 overworld-route,
  169 route-manager, 154 auto-step tests. The gate explicitly skipped live-only
  `test_screen.lua` and `test_speech.lua`. Travel manual reload and loaded
  verification completed on 2026-10-15. The current development source was
  manually reloaded for the accepted October 23 darkness check. The October 23
  rebuilt candidate includes `tolk.lua` hardening; its fresh packaged launch
  smoke is now separately player-accepted with NVDA.
- Latest gameplay evidence (2026-10-23) is the fresh package under
  `C:\tmp1\Dragon Warrior Accessibility 2026.10.23-qualification1`, using its
  bundled Python and NVDA. The player accepted character creation, quest start
  and initial gameplay; speech logs include completed auto-walks and entry to
  Tantegel Castle. Do not target development-root commands at this package.
  Earlier same-day development-root evidence covers the accepted Radiant cast
  in Erdrick's Cave B1 and World Map exit after manual reload.
  The earlier October 15 package test used the separate account extraction under
  `C:\Users\DWTest-é\Downloads\Dragon Warrior Package Test\Dragon Warrior Accessibility 2026.10.15-qualification1/`.
  The distributable ZIP/build output remains untouched. The packaged defaults
  keep debug logging off; first launches were checked through speech status/logs
  and keyboard heartbeat. The earlier responsiveness probes ran standalone with
  FCEUX closed. Keep that historical package/account evidence separate from
  the October 23 fresh package smoke and development-source darkness acceptance.
- Historical Travel probe `travel_acceptance_complete_20261015`, frame `91440`: clear World
  Map field/menu/text `(96,14)`, path nil, zero NPC/runtime blockers,
  HP 149/149, MP 85/121, speech ready/error none. Brecconary remains selected on
  `tantegel_bridge_staging`, next West of Kol north lane `7 south`; movement
  was manually stopped after the explicit post-dialogue resume. No required Travel
  player check is pending. This predates the separate package session; probe
  afresh before further development movement. Evidence:
  `work_notes/travel_acceptance_20261015.txt` and
  `work_notes/travel_recovery_audit_20261015.txt`.
- Recovery carry watch: the three-step recovery reached `(11,30)` at `31919`
  then carried to `(11,31)` during final settle, cancelling `route_drift_off_path`
  at `31935`. The latter tile is a compatible network cell. Explicit auto-walk
  at `36840` recalculated there without queuing motion; the next press completed
  three guided legs. Reproduce the exact boundary/checkpoint carry before any
  timing fix. Five later recovery checkpoint/network stops landed exactly.
  It supplies no new terrain blocker evidence.
- Preserve live debug/speech logs before host gates as well as reloads. The
  2026-10-13 recovery-reload record is labelled as reconstructed tool-output
  excerpts after log truncation. The full 2026-10-15 live logs are backed up
  under ignored `.test_tmp/`; tracked focused extracts retain the useful proof.
- The restricted test attempt hit Lua startup, shell, and temp-directory
  access errors. The unmodified gate passed in normal host context with the
  installed Lua5.1/luac; no runtime or global settings were changed.
- FCEUX with the verified patched runtime is the normal gameplay/debug path;
  BizHawk remains an explicit alternate debug/reload path. Before a live
  check, verify fresh command polling with `launcher_probe` and use short,
  state-sensitive `dw_commands.ps1 --replace` batches. Do not treat an old
  frame or saved coordinate in historical notes as the current game state.
- For any future map correction, first distinguish planner error, movement
  execution timing, input contamination, NPC motion, door/hazard state, and
  an engine block. Promote only map-scoped, live-proven evidence with a
  regression assertion. Preserve safe automatic hazard refusal.

## Next work

1. Keep `TASKS.md` as the active queue. October 15 local package qualification is complete
   with separate NVDA/JAWS gameplay and normal save/reload acceptance. No local
   reader check is pending on the original account. Actual non-ASCII account
   acceptance is also complete, including Continue/5-XP progress, manual arrows
   and sustained heartbeat. Final public version/destination and broader testing
   remain open. The 2026-10-16 review fixes and October 23 darkness fixes are in
   the new `2026.10.23-qualification1` candidate. Its fresh packaged launch smoke
   passed in C:\tmp1 with NVDA. The October 29 description-inclusive rebuild
   supersedes it as the candidate for the tester: automated artifact checks pass, and
   fresh gameplay/alternate-hardware acceptance of that package remains open. Preserve
   both qualified artifact pairs. The first `SPEECH-LATENCY-01` investigation
   found a fast standalone bridge handoff; the user agreed to defer it. Review
   its focused report before adding instrumentation or changing behavior.
   The latest source feedback is the October 29 description spot checks; the
   latest recorded package gameplay smoke used C:\tmp1, not DWTest-é. Preserve
   that account's completed acceptance evidence rather than repeating its matrix.
2. The broader representative Travel pass is complete; see the completed plan
   `docs/plans/2026-10-13-travel-acceptance.md`. Do not resume the old regional
   matrix or checkpoint assignment. Capture the remaining dialogue-only and
   battle-keyboard cases opportunistically during normal play, and reproduce
   the isolated western carry before any timing change.
3. Keep optional progressive discovery, Speech settings, cross-town services,
   and bookmarks behind the release and gameplay-reliability work unless the
   user reprioritizes them.

## Historical evidence

- Detailed town/castle acceptance: `PLAYTESTING.md` and
  `handoff_archive/current_investigation_2026-10-15_pre_travel_wrap.md`.
- Former full handoff: `handoff_archive/session_handoff_2026-09-24_pre_cleanup.md`.
- Former detailed roadmap and 40 route slices:
  `handoff_archive/TASKS_2026-09-24_pre_cleanup.md`.
