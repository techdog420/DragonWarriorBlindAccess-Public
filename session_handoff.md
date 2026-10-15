# Session Handoff - Active Resume

Updated: 2026-10-15

This is the short current-state entry point. `TASKS.md` is the open roadmap;
`PLAYTESTING.md` holds dated gameplay evidence; `PROJECT_MEMORY.md` holds
durable architecture and workflow lessons. The former 4,528-line handoff is
preserved at `handoff_archive/session_handoff_2026-09-24_pre_cleanup.md`.
Its old branch, frame, test-count, and "next work" statements are historical,
not instructions for the current checkout.

## Project state

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
- An actual non-ASCII Windows username has not been tested with the final
  player package. A non-ASCII extraction directory was tested successfully;
  it does not cover account-profile paths. A broader release also needs a
  fresh package build and player acceptance on that build.

## Verification and runtime rules

- The latest recorded `python -u run_tests.py` pass on 2026-10-13 covered
  42 host-runnable Lua suites, 68 Python tests, Lua/Python/shell syntax, speech
  dependency, and command queue checks. Focused counts are 346 overworld-route,
  169 route-manager, 154 auto-step tests. The gate explicitly skipped live-only
  `test_screen.lua` and `test_speech.lua`. No Lua changed after that final gate;
  manual reload and loaded verification completed on 2026-10-15.
- Final fresh `travel_acceptance_complete_20261015`, frame `91440`: clear World
  Map field/menu/text `(96,14)`, path nil, zero NPC/runtime blockers,
  HP 149/149, MP 85/121, speech ready/error none. Brecconary remains selected on
  `tantegel_bridge_staging`, next West of Kol north lane `7 south`; movement
  was manually stopped after the explicit post-dialogue resume. No required player
  check is pending. Probe afresh before further movement. Evidence:
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

1. Keep `TASKS.md` as the active queue. Ending narration polish is complete;
   the next release task is qualification of a new player package from
   current source.
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
