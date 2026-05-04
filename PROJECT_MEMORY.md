# Project Memory

Updated: 2026-05-04

This file contains durable project knowledge for the Dragon Warrior accessibility mod. It is intended to be stable, concise, and repo-native. Use `session_handoff.md` for current state and `PLAYTESTING.md` for active gameplay notes.

## Project Shape

This repository contains a Lua accessibility mod for Dragon Warrior. BizHawk is
now the default emulator path, with FCEUX kept as a supported fallback.

Core goals:
- Reliable screen reader narration for normal gameplay
- Navigation and object assistance for blind players
- Robust pathfinding and movement diagnostics
- Accurate map passability, including hidden engine-blocked tiles
- Repeatable debug and test workflows

Current strategic direction:
- The first decoded maps are good enough to move from map decoding toward real playtesting.
- Continue improving pathfinding when real gameplay exposes issues, but avoid broad unrelated refactors.

## Accessibility and Collaboration Preferences

The user is blind.

Prefer:
- Text-first explanations
- Concrete filenames and outcomes
- Summaries of command output and logs in prose
- A few clear options when decisions matter
- Accessibility behavior preservation over aesthetic cleanup

Avoid:
- Screenshot-dependent explanations
- Visual-only descriptions
- Large speculative rewrites

## Runtime Command Model

The mod uses a command queue file and emulator polling loop.

Important details:
- Preferred launcher: `./launch_dw.sh` (defaults to BizHawk)
- FCEUX fallback launcher: `./launch_dw.sh --emulator fceux`,
  `./launch_fceux.sh`, or `launch_fceux.ps1`
- Commands are sent through `./dw_commands.ps1` or `./dw_commands.sh`
- Commands are written to `dw_commands.txt`
- Debug output is written to `dw_debug.log`
- The mod polls commands roughly once per second
- Commands append by default
- Use `--replace` only when queue replacement is intentional
- A fresh `dw_debug.log` header does not prove command polling is active; verify command consumption

For state-sensitive work:
- Use short command batches
- Wait for log confirmation between steps
- Treat stale queued commands and polling delay as real failure causes
- Confirm live map id and position before map-specific conclusions

## Emulator Strategy

BizHawk is the current default runtime.

Durable BizHawk facts:
- Preferred launcher: `./launch_dw.sh`
- Explicit BizHawk launcher: `./launch_bizhawk.sh`
- The emulator swap is now considered successful enough to resume normal
  playtesting from the BizHawk path. Keep FCEUX as an explicit fallback rather
  than the primary workflow.
- `launch_dw.sh --dry-run` should show `Emulator: BizHawk`
- The default path is chosen because BizHawk launches cleanly from the command
  line and JAWS/menu navigation does not inject random player movement the way
  FCEUX can
- Keep emulator differences in `emulator_compat.lua` and launcher scripts, not
  scattered through gameplay modules

Durable FCEUX facts:
- Fallback launcher: `./launch_dw.sh --emulator fceux`,
  `./launch_fceux.sh`, or `launch_fceux.ps1`
- Current tested emulator baseline has been `qfceux.exe`
- The launcher disables FCEUX native keyboard GamePad.0 and uses the project keyboard bridge when needed
- `dw_keyboard_input.txt` is runtime bridge state and should stay ignored

Emulator compatibility direction:
- Keep existing gameplay code FCEUX-shaped for now
- Put emulator differences in `emulator_compat.lua`
- Preserve FCEUX globals where practical: `FCEU`, `memory`, `joypad`, `input`, `ppu`, `rom`, `AND`, and `BIT`
- Use `launch_dw.sh` as the default WSL-to-Windows launcher; it routes to
  BizHawk unless `--emulator fceux` is requested
- Keep FCEUX runnable until BizHawk has survived enough real gameplay that the
  fallback is clearly unnecessary
- Patch `D:\emulation\bizhawk\config.ini` only while EmuHawk is closed or
  immediately before launch. Live edits can be overwritten when BizHawk exits,
  because shutdown may write its in-memory settings back to `config.ini`.
- BizHawk Lua Console's `ReloadOnScriptFileChange` feature is useful for
  fast iteration. With it enabled, `touch main.lua` from WSL auto-reloads the
  script; confirm reloads with a fresh `launcher_probe:TAG` because module
  caching may keep some required-module startup behavior alive.
- Keep BizHawk performance fixes gated on `DW_EMULATOR_COMPAT.is_bizhawk` so
  FCEUX remains behaviorally unchanged.
- Current BizHawk performance approach is a gameplay-level PPU scan throttle:
  title-state rescans are periodic after gameplay is confirmed, and menu,
  yes/no, merchant, lower-dialogue, and upper-dialogue scans run on short
  cadences with elapsed-frame stability deltas.
- `scan_profiler.lua` owns BizHawk-only scan scheduling/profiling. Use
  `reset_scan_stats` then `report_scan_stats` in live BizHawk sessions to
  identify active scan costs.
- BizHawk PPU caching now holds for 120 frames and clears on real/simulated
  input so passive text/menu scanning is cheap while user actions still refresh
  screen state.
- Dynamic dialogue scans clear the BizHawk PPU cache before reading text. This
  avoids treating a cached half-rendered line as stable and speaking fragments
  such as the first few letters of the next dialogue page.
- Lower dialogue filtering must reject persistent status rows with `LV`/`HP`
  markers even when the hero name contains lowercase letters. Otherwise rows
  like `Bill LV 1 HP 15 MP 0 G 120 E 0` can bleed through as dialogue after an
  NPC/king text window closes.
- Upper dialogue extraction needs the same status-row guard after overlap
  stripping. A status-only upper window can produce a lowercase `new_text`
  fragment because the hero name is mixed case, so check `text.is_status_text`
  on the extracted fragment before the lowercase-dialogue filter.
- A BizHawk-only boot-dialogue grace suppresses command-menu, merchant, and
  object refresh scans while the normal king dialogue is expected after
  continuing a quest.
- BizHawk `input.get()` keyboard hotkeys are disabled by default with
  `enable_bizhawk_keyboard_hotkeys=false`. In live testing, stray keyboard or
  screen-reader key state triggered status and diagnostic hotkeys during king
  dialogue.
- `hotkey_filter.lua` keeps the default BizHawk keyboard path extensible:
  when full keyboard hotkeys are off, only shortcuts named in
  `bizhawk_keyboard_hotkey_allowlist` pass through. Add future QoL shortcut
  setting names to that allowlist instead of re-enabling all diagnostics.
  Hotkey settings can now use modifier combos such as `Ctrl+N` and `Shift+F`.
  The `key_diag_tiles=Ctrl+N` coordinate/tile diagnostic is intentionally
  allowlisted because it is useful during BizHawk playtesting and surveys.
  Keep it cheap: `Ctrl+N` speaks only the compact coordinate/tile summary
  unless `tile_diag_dump_on_hotkey=true`.
- In BizHawk field play, avoid reading cartridge work-RAM address `$6003`
  (`addr.CHR_PAGE_SPRITES`) every frame. A post-dialogue profile showed
  `state.check_for_changes` averaging about 112 ms per frame from this path
  even with zero PPU reads. Refresh the sprite CHR page only around battle-like
  signals or battle exit.
- Route/path command spikes can come from object refresh as much as A* itself.
  A live post-fix sample showed `debug_tools.tick max_ms=1931` and
  `objects.check_refresh max_ms=2068` around a path command. Keep static object
  sources cached per map, and use `CMD_TIMING` lines to identify command
  handlers over 25 ms.
- BizHawk object-navigation descriptions should stay lightweight by default.
  With `bizhawk_object_reachability_descriptions=false`, J/K/L/Q style object
  speech skips reachability path checks; explicit `pathfind`/`auto_walk`
  commands still do route work. The hotkey path now explicitly requests brief
  name/direction/count descriptions and suppresses raw player/object coordinate
  suffixes while browsing.
- Object navigator speech from rapid previous/next hotkeys is coalesced by
  default with `object_nav_speech_coalesce_frames=18`. J/L selection changes
  still happen immediately; the speech layer only speaks the newest selected
  object after a short idle gap. The delay was raised from 6 after live logs
  showed repeated 6-frame flushes during manual object-list tapping. Set the
  value to `0` to restore immediate previous/next speech.
- Player-facing QoL hotkeys are part of the safe BizHawk allowlist. Current
  additions are `Shift+J` / `Shift+L` for object-filter categories, `Shift+K`
  to jump filters back to All, `Shift+V` for session-only visited marking, and
  `Shift+Enter` plus `Shift+direction` for selected-object teleport. Keep these
  shortcuts configurable and avoid re-enabling all BizHawk keyboard hotkeys for
  normal testers.
- Visited flags live in `objects.lua` as session-only, map-scoped state. They
  intentionally do not persist across script restarts yet; use
  `clear_visited` and `clear_visited:all` for local cleanup during a playtest.
- `auto_walk` is now a tester-facing feature, not only a debug hook. Long routes
  should provide periodic progress speech, completion should be spoken, and NPC
  targets may be held briefly after arrival so the player has time to use TALK.
  For adjacent interaction targets, auto-walk should also face the target after
  arrival; otherwise a route whose final step is sideways can leave the hero
  adjacent but facing away, making TALK say "There is no one there."
- BizHawk periodic NPC/object refresh is disabled by default with
  `bizhawk_periodic_npc_refresh=false` because live profiling showed background
  `objects.check_refresh` calls could spike around 1.7-2.0 seconds. Explicit
  route/path/debug commands still call `objects.update_npcs()` when they need
  current live blockers.
- Selected-object teleport should avoid full object-list rebuilds on the hotkey
  path. Use direct live NPC RAM checks for "landing occupied" tests; a manual
  teleport retest found the apparent lost-keyboard state was actually a boxed-in
  landing at map `0x05` `(4,6)` with NPC blockers on both sides, a door south,
  and a noisy north seam.
- BizHawk ROM domains can be exposed as headerless PRG data even when the
  project expects FCEUX-style `rom.readbyte()` file offsets that include the
  16-byte iNES header. `emulator_compat.lua` must score candidate ROM domains
  and address mappings instead of accepting the first readable byte; otherwise
  ROM-backed tables such as map metadata can be shifted by 16 bytes and produce
  nonsense dimensions under BizHawk.

Known BizHawk risk:
- BizHawk's Lua memory-domain reads are much slower than FCEUX for PPU-heavy screen scanning
- Compatibility-layer PPU caching helps but may not be enough
- Emulator audio can still stop briefly under heavier load even when script
  behavior is otherwise correct. Correlate clean repros with `CMD_TIMING` and
  `report_scan_stats`, then tune BizHawk audio/config settings separately if
  Lua timings stay small.
- Long-term BizHawk support may still need timing instrumentation, subsystem
  read counters, or a deeper PPU snapshot/bulk-read strategy if scan
  throttling is not enough.
- Treat impossible decoded map dimensions under BizHawk as a compatibility
  layer clue before changing permanent map data.

## Testing Baseline

Latest BizHawk transition checkpoint:
- `a5386bc Make BizHawk the default emulator path`

Previous FCEUX keyboard bridge checkpoint:
- `a79bd6f Stabilize FCEUX keyboard input bridge`

Latest pre-commit validation:
- Full plain Lua `test_*.lua` run passed with 126 unit tests
- FCEUX-only diagnostic tests skipped cleanly under plain Lua
- `luac -p *.lua` passed
- `git diff --check` passed

Do not assume this remains current after new edits. Re-run targeted checks when asked or when preparing a commit.

Latest BizHawk default validation:
- 2026-04-29 docs follow-up: `CLAUDE.md` and `prompt1.txt` now describe
  BizHawk as the primary emulator and FCEUX as an explicit fallback. Refreshed
  local checks passed: `git diff --check`, `bash -n launch_dw.sh
  launch_bizhawk.sh launch_fceux.sh`, `./launch_dw.sh --dry-run`,
  `./launch_dw.sh --emulator fceux --dry-run`, and
  `python3 run_tests.py --allow-missing-speech-dep`. The first sandboxed test
  run failed only because repo-local writes were blocked; an approved rerun
  passed.
- 2026-04-29 live follow-up: after increasing
  `object_nav_speech_coalesce_frames` to `18` and adding closed-door no-path
  messaging, `python3 run_tests.py --allow-missing-speech-dep` and
  `git diff --check` passed again.
- Latest follow-up after the cartridge work-RAM fix and shorter auto-step retry
  window: `git diff --check`, `bash -n launch_dw.sh launch_bizhawk.sh
  launch_fceux.sh dw_commands.sh`, and
  `python3 run_tests.py --allow-missing-speech-dep` passed. The only warning
  remains the expected missing WSL `accessible_output2` package.
- `python3 run_tests.py --allow-missing-speech-dep` passed after adding the
  BizHawk scan-throttle/profiler patches, default-launcher routing, and
  launcher shell-syntax validation.
- `./launch_dw.sh --dry-run` reports BizHawk as the default emulator, while
  `./launch_dw.sh --emulator fceux --dry-run` reports the FCEUX fallback.
- The only warning was expected in WSL: `/usr/bin/python` lacks
  `accessible_output2`, so speech dependency validation must still be checked
  from the Windows/FCEUX/BizHawk runtime.
- Live BizHawk king-dialogue sample after latest throttles: `PPU_STATS
  reads=123840 cache_hits=108736 cache_misses=15104`, with active scans limited
  to lower dialogue, yes/no prompt, and upper dialogue. Before boot-dialogue
  grace, the comparable sample was about 1,039,344 reads; an earlier broad
  field sample was about 4,157,376 reads.
- Live BizHawk post-dialogue/player-control sample before the `$6003` state
  fix: `state.check_for_changes calls=240 reads=0 ms=26984 avg_ms=112.433`.
  After the patch, local validation passed with a new regression test ensuring
  BizHawk clear-field detection skips that slow sprite-page read.
- Live BizHawk route/path command sample before static-object caching:
  `debug_tools.tick max_ms=1931` and `objects.check_refresh max_ms=2068`.
  Full local validation passed after caching static object sources and
  throttling repeated `CAN_WALK false` debug logging.
- Latest local validation also covers BizHawk object descriptions skipping
  reachability by default while allowing opt-in through
  `bizhawk_object_reachability_descriptions=true`.
- Latest live post-dialogue object-navigation validation after disabling
  periodic BizHawk NPC refresh: command-file object navigation showed
  `objects.check_refresh max_ms=1`; a real-hotkey sample while the user tapped
  object navigation showed `hotkeys.update max_ms=1`,
  `objects.check_refresh max_ms=1`, and no object command `CMD_TIMING` spikes.
  Remaining small object-list lag is probably speech interrupt overhead or
  BizHawk/Windows audio scheduling rather than Lua object refresh.
- Local validation now includes `test_hotkeys.lua`, covering the hotkey-side
  object navigator speech coalescer, immediate K/current-object reads,
  route-action clearing, and `object_nav_speech_coalesce_frames=0`.
- BizHawk audio trial config was patched while closed with:
  `SoundBufferSizeMs=200`, `SoundThrottle=true`, `FrameSkip=0`, and
  `Rewind.Enabled=false`. An earlier attempt to patch these while EmuHawk was
  running was later overwritten on shutdown by BizHawk's in-memory settings.
- Live audio result: that BizHawk audio baseline substantially reduced the
  background-window glitching. The user could work in other windows with game
  audio running without reproducing the old stutter. A single in-emulator glitch
  happened once but could not be reproduced, so treat it as a watch item rather
  than a current script-side blocker.
- Local validation now includes `test_emulator_compat.lua`, which verifies that
  the ROM adapter returns the same FCEUX-style offsets for both full iNES ROM
  domains and headerless PRG-only ROM domains.
- Live BizHawk follow-up on map `0x05` confirmed the stair route now decodes
  correctly after the ROM-domain fix: `(8,8)` is passable passthrough, and
  `(4,7)` is the closed magic-key door. A remaining no-path to the selected
  stairs before opening that door is normal route state. `route_manager.lua`
  now turns that case into a closed-door/magic-key hint, covered by
  `test_route_manager.lua`.
- BizHawk cartridge work RAM must not be read through `mainmemory`. DW1 stores
  opened-door slots at `$600C/$600D`; `emulator_compat.lua` maps `$6000-$7FFF`
  through System Bus or PRG-RAM-style domains so door-open checks work under
  BizHawk. Tests cover both domain styles and map `0x05` door-open walkability.
- After that cartridge work-RAM fix, a 2026-04-30 manual BizHawk playtest from
  game launch through throne-room chests, the `(4,7)` door, and the stairs into
  the castle proper worked as expected.
- Later 2026-04-30 basic manual testing on the first two maps found scripts
  behaving as expected after the emulator conversion, apart from emulator audio
  stoppages under heavier load.
- A later 2026-04-30 first-town run exposed queued auto-walk direction-change
  overshoot: the route could start a new `right`/`down` command while the
  engine was still finishing the previous step, so the next cell sometimes
  continued the previous direction. `auto_step.lua` now applies
  `auto_step_route_turn_settle_frames=16` only when queued route direction
  changes.
- Path route lag from hotkey-triggered `O`/`U` was not covered by
  `CMD_TIMING`, so `route_manager.lua` now logs `ROUTE_PLAN_TIMING` for plans
  over 25 ms. `pathfinder.lua` keeps path summaries but gates detailed
  tile-by-tile chosen-path logs behind `pathfind_log_steps=true`.
- A follow-up log showed `ROUTE_PLAN_TIMING map=0x08 start=(0,15)
  target_id=npc_15 ... path_len=2 ms=1978.000`, while the queued walk completed
  normally with the route-turn settle. Treat that class of lag as adjacent-route
  planning cost first. `pathfinder.lua` now sorts adjacent candidates by
  lower-bound distance, skips candidates that cannot beat the current best path,
  and computes reachable-area/open-exit metrics only for equal-length ties or
  no-path diagnostics.
- Interior/town object refresh is intentionally two-phase under BizHawk: static
  objects first, NPCs after a frame so RAM has settled. Because periodic
  `objects.check_refresh` is throttled, map-entry and deferred refreshes must
  bypass the throttle via `objects.needs_refresh(map_id)`; otherwise Brecconary
  can briefly show only the world-map exit after quickload/re-entry.
- After the object-refresh fix, live retest confirmed objects populated quickly,
  but auto-walk still showed route-planning lag and a movement executor bug:
  `ROUTE_PLAN_TIMING map=0x08 start=(0,15) target_id=npc_4 ... path_len=13
  ms=1836.000`, then drift from `(4,14)` to `(5,14)` during route-settle before
  a planned turn upward. `auto_step.lua` now actively neutralizes D-pad input
  during route-settle frames, and `map_reader.lua` / `pathfinder.lua` use
  per-plan walkability snapshots so A* avoids repeated slow walkability calls.
- A later route lag sample showed fixed overhead beyond A* path length:
  auto-walk plans logged 1852 ms for 13 steps and 1238 ms for 10 steps, while
  show-path logged 1422 ms for 7 steps and 1514 ms for only 1 step. Under
  BizHawk, `route_manager.lua` therefore skips forced live NPC refresh before
  `O`/`U` plans by default (`bizhawk_route_refresh_npcs=false`) and skips
  auto-walk's NPC RAM freeze by default (`bizhawk_autowalk_freeze_npcs=false`).
  FCEUX keeps the previous defaults, and both BizHawk behaviors remain opt-in.
- Queued route drift can still occur after tile coordinates update if sticky
  route-owned input remains active after the inject window. Fresh examples were
  `(1,15)->(2,15)` and `(7,16)->(8,16)` during settle before a planned `up`.
  `auto_step.lua` must neutralize after the queued-route inject window, not
  only during explicit route-turn settle frames.
- BizHawk auto-step movement-start detection is useful but subtle:
  `$003D`/`MOVEMENT_SUBPIXEL` can change during a turn-in-place before the tile
  step is truly underway. If an early movement-start release later times out,
  timeout retry must reset `auto_movement_started` and the baseline subpixel so
  the retry gets a real held direction. The safer BizHawk config now disables
  quick turn-represses by default (`auto_step_turn_repress_limit=0`) and relies
  on timeout retry for turn-only attempts.
- The Brecconary first-route `O`/`U` lag was mostly first-use map-grid/ROM-cache
  cost. `objects.refresh()` now prewarms the current interior map grid during
  map-entry refresh, so the first usable path command after objects populate no
  longer pays the old 1.7-1.9 second `ROUTE_PLAN_TIMING` cost.
- End-of-route BizHawk hitches can come from route cleanup, not route planning.
  A user retest showed improved auto-walk audio and a successful route to
  `(15,19)` with neutral input, but `report_scan_stats` later showed
  `objects.check_refresh max_ms=1658`. `route_manager.lua` now skips the
  immediate object/NPC refresh after BizHawk route completion or cancellation by
  default (`bizhawk_route_cleanup_refresh_objects=false`). FCEUX keeps the old
  refresh, and BizHawk can opt back in for stale-object investigations.
- Live validation after the cleanup patch completed Brecconary routes to Person
  4 and Person 2 with no route drift, neutral final input, no runtime blockers,
  no route-planning timing spikes, and `objects.check_refresh max_ms=0`.
- The follow-up hands-on retest confirmed auto-walk is reaching intended
  targets and lag feels under control, so treat Brecconary auto-walk lag/drift
  as stabilized unless a new route-specific repro appears.
- For the title name-entry screen, repeated/double letters are likely a held
  A-button or short release-gap problem rather than auto-step. `main.lua` has a
  title-only name-entry guard that allows the first A frame, then suppresses A
  until the button has been released stably for several frames. Use
  `report_title_state` plus `trace_input:300` for any future name-entry repro.
- Title/menu screens can have valid save RAM loaded, so state detection must
  not rely only on level RAM. `state.lua` treats the erase confirmation
  (`ERASE` + `CHARACTER`) and name-entry grid (`BACK` + `END` on row 22) as
  title screens. If logs show map `0x00` auto-step blocks or "Unknown Map 0"
  during the main menu, inspect title-state detection before treating it as map
  data.
- BizHawk's default NES keyboard bindings are easy to misread by experiment:
  normal `P1 A` is `X`, normal `P1 B` is `Z`, `Start` is `Enter`, and `Select`
  is `Space`. The `S` key is configured as NES `P1 A` autofire in
  `AllTrollersAutoFire`, not normal A; it pulses every other frame and can cause
  double name-entry letters or extra menu confirms.
- Current mod hotkey layout intentionally avoids BizHawk NES control/autofire
  keys. Frequent object navigation remains bare `J/K/L/O/U/Q`; less-used
  information commands use `Shift+key`; diagnostics use `Ctrl+key`; NPC freeze
  is `Shift+F`; tile diagnostics are `Ctrl+N`. Combo hotkeys are parsed by
  `key_combo.lua`, and BizHawk's filtered hotkey mode only forwards combo
  components when the complete combo is held.
- The title-to-field debounce is only a startup classifier, not a long-lived
  gameplay gate. If `check_title_screen` keeps running while `log_state` reports
  `state=field`, or if `report_upper_dialogue_state` shows lower dialogue text
  without `check_dialogue` scan-profile entries, confirm `field_from_title_ct`
  is cleared after `FIELD_DEBOUNCE` announces "Game started."
- BizHawk supports command-line savestate loading with `--load-slot N`.
  `launch_dw.sh`, `launch_bizhawk.sh`, and `launch_bizhawk.ps1` now pass this
  through via `--state-slot N`, and the PowerShell launcher quotes the ROM path
  for `Start-Process` so paths containing `Dragon Warrior ...` work with
  `--no-wait`.
- 2026-04-30 route-lag/drift validation passed focused Lua parse/unit checks:
  `test_auto_step.lua`, `test_route_manager.lua`, `test_pathfinder.lua`,
  `test_map_reader.lua`, `test_objects.lua`, `test_map_survey.lua`, and
  `git diff --check`.
- 2026-04-30 wrap-up validation after making `N` cheap and object browsing
  brief passed focused Lua parse/unit checks plus `git diff --check`. A broad
  `python3 run_tests.py --allow-missing-speech-dep` run passed its Lua test
  portion, then hit the known sandbox write boundary when it tried to write
  `__pycache__` and `dw_commands.txt`.

## Pathfinding Rules

When debugging pathfinding:
- Separate planner errors, movement execution errors, queue timing issues, and actual engine-blocked tiles
- Do not treat one failed route as proof of bad map data
- Prefer runtime blocked-tile injection during investigation
- Promote permanent map data only after repeated or direct evidence
- Inspect the failure point before patching permanent passability
- Keep runtime/test-only blocked tiles separate from permanent map data
- Scope blocked-tile data by map

Important classification lesson:
- Clean `gated_or_isolated` survey failures are not blocker evidence.
- Aggregate `export_blocks` output can contain historical observations and should not be treated as a clean patch list.

## Map Survey Architecture

`map_survey.lua` is the primary systematic survey tool.

Durable model:
- Survey state uses `survey_state.queue[]` and a `queue_index`
- `target_total` is frozen at survey start for denominator logging
- Retries and deferrals can grow the queue after survey start
- Classification flows through attempt classification, clean no-path clustering, retry decisions, and finalization
- Run-end logic can retroactively classify isolated-start results
- Route planning diagnostics flow from pathfinder through route manager into survey classification

Important maintenance risk:
- Reachability/BFS-like logic exists in both `pathfinder.lua` and `map_survey.lua`
- When changing directional blocking or reachable-area logic, check both layers

## Pathfinder Return Contracts

Public return shapes:
- `find_route_to_adjacent()` returns `path, face_direction, best_adj, diagnostics`
- `pathfind_to_adjacent()` returns `result_string, face_dir, path, diagnostics`
- `pathfind_to()` returns `result_string, face_dir, path`
- `find_route_to()` returns `path`

Lua callers may silently discard extra returns. Removing or reordering returns is riskier than adding an extra trailing return.

## Snapshot Architecture

`game_snapshot.lua` provides frame-consistent game state via `M.update()` once per frame.

Useful field groups:
- Location: map id, player coordinates, overworld coordinates
- Stats: HP, MP, level, strength, agility, attack, defense, EXP, gold
- Inventory: equipment, keys, herbs, item slots
- Flags and combat state
- Cursor and environment state
- Input buttons

Snapshot consumers include core gameplay/navigation modules such as `main.lua`, `state.lua`, `navigation.lua`, `menu.lua`, `items.lua`, and `route_manager.lua`.

Guidance:
- Prefer snapshot reads in gameplay modules when frame consistency matters
- Raw `memory.readbyte` is still appropriate for low-level diagnostics that inspect addresses not represented in the snapshot

## Hotkeys Architecture

`hotkeys.lua` was extracted from `main.lua` and owns hotkey handling.

Durable facts:
- `hotkeys.update(keys)` is the public entry point
- Main loop calls it after snapshot update and before state detection
- Some diagnostic hotkeys still use raw memory reads
- PPU, ROM, zero-page, and other low-level diagnostics should remain raw reads
- Stat and simple position hotkeys are candidates for future snapshot migration

## Known Map Notes

Brecconary/map `0x08`:
- Broad blocker hunting can pause.
- Latest reliable surveys showed no strong blocker candidates and no runtime blocks.
- Remaining failures are clean gated/isolated object regions.
- Existing permanent Brecconary fixes in `map_reader.lua` should be preserved unless better evidence appears.

Tantegel/castle/interior maps:
- Confirm live map id before permanent edits.
- Historical notes sometimes label map `0x04` as Tantegel Castle and `0x05` as throne room/interior.
- Recent map `0x05` blocked-cell observations looked transient and did not justify permanent map-data changes.

## Memory Policy

Repo files are the source of truth.

Use:
- `session_handoff.md` for current resume only
- `PROJECT_MEMORY.md` for durable architecture and lessons
- `PLAYTESTING.md` for active gameplay findings
- `handoff_archive/` for detailed historical evidence

Do not rely on assistant-local memory as the only record of important project state.

## Debug Loop Optimization

- Prefer wrapper-level confirmation over ad-hoc sleeps: use `./dw_commands.sh --wait "PATTERN" ...` or `./dw_commands.ps1 --wait "PATTERN" ...` when a command has an expected log line.
- `--wait` watches only fresh `dw_debug.log` lines written after queueing the command, which avoids stale-log false positives.
- Default wait timeout is 10 seconds; use `--timeout SECONDS` for longer survey/pathfinding operations.
- Good smoke check after reload: `./dw_commands.sh --replace --wait "LAUNCHER_PROBE: ready" launcher_probe:ready report_position`.

## Codex Memory Access

- In Codex sessions, `.codex/` under this repository can be mounted read-only even though the surrounding repo is writable.
- Do not depend on editing `.codex/skills/dw-debug-loop/SKILL.md` during normal project work.
- Canonical mutable project memory should live in repo files: `session_handoff.md`, `PROJECT_MEMORY.md`, `AGENTS.md`, and targeted docs such as `debug_hooks.txt`.
- Assistant-local memory belongs under `/home/developer/.codex/memories/`; use it as a reminder layer only, not as the source of truth when repo docs disagree.
- Current recommendation: keep launching Codex from Linux/WSL. The memory issue is a sandbox/read-only mount detail, not a reason to switch environments.
