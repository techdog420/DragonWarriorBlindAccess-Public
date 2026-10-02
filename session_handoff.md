# Session Handoff - Active Resume

Updated: 2026-10-02

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
  refusal remains correct. See the top of `PLAYTESTING.md` and
  `work_notes/current_investigation.md` for exact routes and frames.
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
  arbitrary-start/interruption acceptance goal remains open in `TASKS.md`.
- The final Hauksness return-corridor selector check closed on 2026-10-02.
  At World Map `(73,96)`, Rimuldar, Magic Temple, and Charlock each selected
  `hauksness_return_staging`, waypoint 2 `Cantlin north road` at `(73,91)`.
  Separate status checks preserved the final destination and position;
  cancellation cleared guidance. The player confirmed Shift+R/Shift+U speech
  for Charlock. This closes the loaded selector/status/cancellation gap;
  broader Travel acceptance remains open.
- Representative Tantegel menu/battle/manual-drift validation passed on
  2026-10-02. A narrow selector fix makes known Charlock corridor starts use
  `charlock_return`, with alias/object regression coverage. Menu and battle
  interruptions retained Tantegel and stopped movement; one-east recovery
  from `(55,57)` stopped at the network boundary and required explicit resume.
  One initial north-step timing stop crossed normally in a same-origin probe
  and passed a repeated guided handoff. Keep it as a watch item, not map data.

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
- The published `v0.1.0-alpha` tag is at `133d65c` (2026-07-31). Current source
  includes the later ending fix `86252b0` and published documentation through
  `089e849` (2026-10-02). The Tantegel selector fix, regression, and validation
  records are included in this validation update. Check Git state before
  publishing further work. The alpha package is not a build of current source.
  Its separate JAWS/NVDA acceptance and licensing/source-package checks remain
  historical release evidence.
- An actual non-ASCII Windows username has not been tested with the final
  player package. A non-ASCII extraction directory was tested successfully;
  it does not cover account-profile paths. A broader release also needs a
  fresh package build and player acceptance on that build.

## Verification and runtime rules

- The latest recorded `python -u run_tests.py` pass on 2026-10-02 covered
  42 host-runnable Lua suites, 68 Python tests, Lua/Python/shell syntax, speech
  dependency, and command
  queue checks. It explicitly skipped live-only `test_screen.lua` and
  `test_speech.lua`.
- The 2026-10-02 Travel validation ended at frame `59520`, World Map `(67,50)`,
  clear field/menu, with movement stopped, path target nil, zero NPC/runtime
  blockers, HP109/149, MP89/121, and speech bridge ready with no error.
  Tantegel guidance remains active: `Rainbow Bridge inlet southeast turn`,
  `3 east`, on `charlock_return`. The fresh
  `travel_validation_complete_20261002` probe was consumed. This is the last
  observed state; probe again before further live work. Focused evidence is
  in `work_notes/travel_validation_20261002_post_reload.txt`; menu and
  pre-fix selection evidence is in the corresponding `pre_reload.txt` file.
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
2. Expand Travel acceptance to other destination/start-region combinations
   and field-dialogue interruption/resume. The Hauksness selector gap and
   representative Tantegel menu/battle/manual-drift slice are closed.
3. Keep optional progressive discovery, Speech settings, cross-town services,
   and bookmarks behind the release and gameplay-reliability work unless the
   user reprioritizes them.

## Historical evidence

- Detailed town/castle acceptance: `PLAYTESTING.md` and
  `work_notes/current_investigation.md`.
- Former full handoff: `handoff_archive/session_handoff_2026-09-24_pre_cleanup.md`.
- Former detailed roadmap and 40 route slices:
  `handoff_archive/TASKS_2026-09-24_pre_cleanup.md`.
