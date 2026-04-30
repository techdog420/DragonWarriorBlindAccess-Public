# Session Handoff - Active Resume

Updated: 2026-04-30

## Current Focus

The project has pivoted to BizHawk as the default emulator while preserving
FCEUX as an explicit fallback.

Reason for the decision:
- FCEUX has recurring keyboard/input weirdness, especially stale Alt/menu focus.
- FCEUX command-line/script reload behavior is awkward for automated testing.
- FCEUX menu navigation with a screen reader can inject gameplay input.
- BizHawk is more screen-reader tolerable, supports clean command-line Lua
  launch/reload workflows, and does not send the player walking while JAWS is
  used in menus.

Keep FCEUX supported as a fallback. New work should assume BizHawk is the
primary path unless the task explicitly targets FCEUX.

## Current Baseline

Latest BizHawk transition checkpoint:
- Commit: `a5386bc Make BizHawk the default emulator path`

Previous FCEUX keyboard bridge checkpoint:
- Commit: `a79bd6f Stabilize FCEUX keyboard input bridge`

That commit includes:
- FCEUX native keyboard GamePad.0 disabled on launcher startup.
- `keyboard_bridge.ps1` for Windows real-key polling.
- Foreground-gated key forwarding so terminal typing does not bleed into FCEUX.
- `enable_keyboard_input_bridge=true` config default.
- Runtime bridge file `dw_keyboard_input.txt` ignored.

The BizHawk default transition contains:
- `main.lua` loads `emulator_compat.lua` before the existing modules.
- `emulator_compat.lua` supplies FCEUX-shaped globals under BizHawk.
- `launch_dw.sh` now defaults to BizHawk. Use `./launch_dw.sh --emulator fceux`,
  `./launch_fceux.sh`, or `launch_fceux.ps1` for the FCEUX fallback.
- `launch_bizhawk.sh` and `launch_bizhawk.ps1` still explicitly launch EmuHawk
  with `--lua=main.lua`.
- BizHawk-only PPU scan throttling now reduces gameplay-loop screen scans
  without changing FCEUX behavior.
- `scan_profiler.lua` provides BizHawk-only scan scheduling/profiling plus
  `report_scan_stats` / `reset_scan_stats` debug commands.
- BizHawk keyboard hotkeys from `input.get()` are disabled by default via
  `enable_bizhawk_keyboard_hotkeys=false`, because stray keyboard/screen-reader
  state triggered diagnostic speech during dialogue.
- When full BizHawk hotkeys are off, `hotkey_filter.lua` still permits the
  config-driven `bizhawk_keyboard_hotkey_allowlist`; default entries restore
  object explorer/navigation shortcuts: J/K/L/O/U/F/X plus `N` tile/coordinate
  diagnostics.
- The `N` tile/coordinate hotkey now speaks only the compact coordinate/tile
  summary by default. The old full `tile_diag.txt` dump is behind
  `tile_diag_dump_on_hotkey=true` because it can stall BizHawk audio.
- `state.lua` now avoids BizHawk's slow `$6003` sprite-CHR cartridge work-RAM
  read during normal field play when enemy HP is clear.
- `objects.lua` now caches static object sources per map so route/path commands
  can refresh live NPC blockers without rereading ROM-backed chests/stairs/
  exits/doors every time.
- `debug_tools.lua` logs `CMD_TIMING command=... ms=...` for command handlers
  over 25 ms, and `main.lua` throttles repeated `CAN_WALK false` debug lines.
- During BizHawk dialogue scans, `main.lua` now clears the PPU cache for dynamic
  text reads so half-rendered dialogue does not look stable for 120 cached
  frames.
- Under BizHawk, object descriptions now skip reachability/path checks by
  default (`bizhawk_object_reachability_descriptions=false`). Object navigator
  keys should speak name/direction quickly; `pathfind` and `auto_walk` still do
  real route work when requested.
- J/K/L/F object-browser hotkeys explicitly request brief descriptions:
  name/direction/count only, with no reachability path preview and no raw
  player/object coordinate suffix.
- Rapid previous/next object hotkeys now coalesce speech through
  `object_nav_speech_coalesce_frames=18`. J/L still change the selected object
  immediately, but only the latest description speaks after the player pauses;
  K/current-object, filter, pathfind, auto-walk, and other immediate speech
  clear the pending object announcement.
- Under BizHawk, periodic background NPC/object refresh is disabled by default
  (`bizhawk_periodic_npc_refresh=false`). Map changes, deferred map-load
  refreshes, explicit route/path commands, and debug commands still refresh NPCs
  when they need current blockers.
- BizHawk rewrites `D:\emulation\bizhawk\config.ini` from its in-memory
  settings on shutdown when settings have changed. Do not patch `config.ini`
  while EmuHawk is running and expect it to stick; close BizHawk first or patch
  immediately before launch.

Lightweight checks passed during the BizHawk default transition:
- `git diff --check`
- Lua parse checks for `main.lua` and `emulator_compat.lua`
- `bash -n launch_dw.sh launch_bizhawk.sh launch_fceux.sh`
- `./launch_dw.sh --dry-run` reports BizHawk as the default emulator
- `./launch_dw.sh --emulator fceux --dry-run` reports the FCEUX fallback
- `python3 run_tests.py --allow-missing-speech-dep` passed locally; the only
  warning was the expected missing `accessible_output2` package for WSL
  `/usr/bin/python`.
- 2026-04-29 docs follow-up: `CLAUDE.md` and `prompt1.txt` were updated so
  future agents no longer see stale FCEUX-only launch/runtime guidance.
  Refreshed checks passed: `git diff --check`, `bash -n launch_dw.sh
  launch_bizhawk.sh launch_fceux.sh`, both `launch_dw.sh --dry-run` variants,
  and `python3 run_tests.py --allow-missing-speech-dep`. The first sandboxed
  test run failed only because the sandbox blocked writes to `dw_commands.txt`
  and `__pycache__`; the approved rerun passed.
- 2026-04-29 live follow-up: after increasing
  `object_nav_speech_coalesce_frames` to `18` and adding the closed-door
  no-path hint, `python3 run_tests.py --allow-missing-speech-dep` and
  `git diff --check` passed again.
- Latest follow-up after the cartridge work-RAM fix and shorter auto-step retry
  window: `git diff --check`, `bash -n launch_dw.sh launch_bizhawk.sh
  launch_fceux.sh dw_commands.sh`, and
  `python3 run_tests.py --allow-missing-speech-dep` passed. The only warning
  remains the expected missing WSL `accessible_output2` package.
- 2026-04-30 manual BizHawk playtest confirmed the clean early-game flow from
  launch: start/continue, open all throne-room chests, open the `(4,7)` door,
  and walk down the stairs into the castle proper.
- 2026-04-30 wrap-up validation after the fast `N` diagnostic/object-browser
  changes passed: `luac -p hotkeys.lua objects.lua route_manager.lua
  config.lua test_hotkeys.lua`, `lua test_hotkeys.lua`,
  `lua test_route_manager.lua`, `lua test_objects.lua`, and
  `git diff --check`.
- A broader `python3 run_tests.py --allow-missing-speech-dep` run passed its
  Lua test portion, then failed at the known sandbox write boundary while
  trying to write `__pycache__` and `dw_commands.txt`. The rerun requiring
  unsandboxed writes was intentionally not pursued because the session was
  wrapping up.

## BizHawk Default Status

What works:
- BizHawk launches from `./launch_dw.sh` and `./launch_bizhawk.sh`.
- ROM and `main.lua` load.
- Speech bridge starts and speaks.
- Script reaches title flow and can get through "Continue a quest."
- Fresh manual playtesting confirms chest collection, magic-key door opening,
  and stair descent from the throne room work as expected.
- Basic manual testing on the first two maps after the emulator conversion
  found the scripts behaving as expected apart from audio stuttering under
  heavier emulator/script load.
- Missing FCEUX globals already shimmed: `FCEU`, `memory`, `joypad`, `input`, `ppu`, `rom`, `AND`, and `BIT`.
- ROM reads are cached permanently.
- PPU reads are cached across multiple BizHawk frames.

Remaining watch items:
- BizHawk is now the default, and the first early-game door/stairs flow has a
  clean manual confirmation.
- Latest user report after reloading the script and clearing the king dialogue:
  broad lag is mostly under control; object-list navigation still produces a
  small amount of lag. The current worktree has a hotkey-side speech coalescer
  intended to reduce rapid J/L speech-interrupt pressure; it still needs live
  BizHawk confirmation.
- Auto-walk can still glitch emulator audio. The shorter blocked-step retry
  window may help, but audio behavior still needs future correlation with
  `CMD_TIMING` and scan stats.
- Emulator audio can still stop for short stretches under heavier load. Current
  evidence points toward timing/config tuning and reducing synchronous hotkey
  work rather than a game-script correctness problem.

Important clues:
- Earlier title-screen lag improved after PPU read caching.
- The PPU adapter selected a nametable-related domain and initially produced out-of-range warnings before domain scoring was improved.
- `state.detect()` was also doing a full title-text PPU scan during gameplay;
  under BizHawk this now rescans only rarely after field/battle state is
  confirmed.
- `main.lua` now throttles the gameplay PPU-heavy checks under BizHawk:
  yes/no prompt, command/battle menu, merchant screen, lower dialogue, and
  upper dialogue. Stability counters receive elapsed-frame deltas so speech
  timing should remain close to FCEUX.
- `emulator_compat.lua` now keeps the BizHawk PPU cache for 120 frames and
  clears it on real or simulated input.
- During the king's normal boot dialogue, `main.lua` enters a BizHawk-only
  boot-dialogue grace that suppresses command-menu, merchant, and object scans
  and keeps only dialogue/yes-no style scans active.
- Latest live king-dialogue profile after reset: PPU reads dropped to 123,840
  over a 900-frame sample. The active scan profile was only lower dialogue
  (52,800 reads), yes/no prompt (36,480), and upper dialogue (34,560);
  command-menu, merchant, and object refresh scans did not run in that window.
- The previous comparable king-dialogue sample before boot-dialogue grace was
  about 1,039,344 PPU reads; an earlier broad field sample was about 4,157,376.
- User-reported "Level 1. HP 15 of 15..." lines embedded in king dialogue were
  not dialogue-parser output. They were stray BizHawk keyboard hotkeys firing
  the status diagnostic through `input.get()`.
- The first hotkey gate disabled object explorer too. It was replaced with the
  allowlist model so future QoL shortcuts can be added by appending their
  config key name to `bizhawk_keyboard_hotkey_allowlist`. `N` tile/coordinate
  diagnostics is now allowed for playtesting; broad status/raw-dump diagnostics
  like S/D remain blocked by default.
- Live command-file probe while the old hotkey gate was running showed the
  object system itself still worked: `current_object` logged
  `Door: 2 south, 4 west (4 of 6) [player 8,5 obj 4,7]. Not currently reachable`.
- Fresh post-dialogue/player-control profile before the `$6003` fix:
  `state.check_for_changes calls=240 reads=0 ms=26984 avg_ms=112.433`.
  The dominant cost was not PPU scanning, but a per-frame cartridge work-RAM
  read of `addr.CHR_PAGE_SPRITES` (`$6003`) in BizHawk.
- After lag was gone in normal play, user reported audio glitches only while
  route/path commands were processing. A fresh sample around `pathfind` showed
  `debug_tools.tick max_ms=1931` and `objects.check_refresh max_ms=2068`;
  this pointed to synchronous command/object-refresh work rather than the
  steady frame loop.
- Latest live observation after the broader lag fixes: dialogue no longer lags,
  but can speak before all text arrives; object navigator can freeze BizHawk for
  about two seconds; emulator audio can randomly freeze while working in other
  windows. The first two have code-side patches in this worktree. The last
  still needs correlation against `CMD_TIMING`/scan stats and may be host focus
  or emulator scheduling behavior.
- Fresh post-dialogue object-navigation command-file sample after disabling
  periodic BizHawk NPC refresh: `objects.check_refresh calls=14 ms=1 max_ms=1`;
  no `CMD_TIMING` lines were emitted for object commands.
- Fresh real-hotkey sample while the user tapped object navigation:
  `hotkeys.update max_ms=1`, `objects.check_refresh max_ms=1`,
  `debug_tools.tick max_ms=3`, and all screen scans stayed at small single-digit
  max times. This suggests the remaining small object-list hitch is not a Lua
  object-refresh or hotkey-handler spike; treat speech interrupt overhead or
  BizHawk/Windows audio scheduling as more likely unless stronger evidence
  appears.
- The current hotkey patch targets that likely speech side: J/L object
  navigation queues only the latest object description for a short idle delay.
  The delay was increased from 6 to 18 frames after live logs showed 6 frames
  still flushed speech repeatedly during manual object-list tapping.
  `object_nav_speech_coalesce_frames=0` restores immediate speech if the delay
  feels worse in play.
- The next audio-cutout repro was the `N` tile/coordinate diagnostic: after it
  was allowlisted, pressing it caused about 1.5-2 seconds of audio cut-out while
  the full diagnostic dump was built. The hotkey now speaks the compact
  coordinate/tile summary only unless `tile_diag_dump_on_hotkey=true`.
- BizHawk audio-trial settings helped substantially. With
  `SoundBufferSizeMs=200`, `SoundThrottle=true`, `FrameSkip=0`, and
  `Rewind.Enabled=false`, the user could work in other windows with game audio
  running and did not hear the previous background-window audio glitches. One
  audio glitch occurred while focused in the emulator, but it was not
  reproducible.
- Latest BizHawk-specific pathing failure started as a ROM-domain translation
  bug: live `inspect_tile` on known throne-room cells returned `tile=nil`, even
  though the same map was already verified under FCEUX. `emulator_compat.lua`
  now scores ROM candidate domains and supports headerless PRG-only BizHawk ROM
  domains while preserving FCEUX-style `rom.readbyte()` file offsets. A new
  `test_emulator_compat.lua` covers both full iNES and headerless PRG mappings.
- Live follow-up on 2026-04-29 confirmed that map `0x05` now decodes correctly
  under BizHawk: `inspect_tile:8,8` returned `dims=10x10`, `tile=15.0`,
  `reason=passthrough`, and `effective_passable=true`. The remaining no-path
  to the selected stairs is caused by the closed magic-key door at `(4,7)`, not
  bad map data. `route_manager.lua` now adds a closed-door hint to no-path
  object plans, covered by `test_route_manager.lua`.
- Subsequent live playtesting showed that after the door was opened, the script
  still reported `(4,7)` as `door_closed`. Root cause: the BizHawk adapter was
  reading `$600C/$600D` opened-door slots through `mainmemory`; those bytes live
  in cartridge work RAM. `emulator_compat.lua` now routes `$6000-$7FFF` through
  System Bus / PRG-RAM-style domains, with new tests in
  `test_emulator_compat.lua` and `test_map_reader.lua`.
- Manual retest after this fix confirmed the launch-to-chests-to-door-to-stairs
  flow works normally.
- Auto-walk still causes emulator audio pain, especially when a route hits a
  blocked step and retries for several seconds. Local config now shortens that
  window with `auto_step_timeout=45` and `auto_step_block_retry_limit=1`.
- `inspect_tile` and `inspect_move` logs now include map dimensions and the
  walkability `reason`, so future bad-grid cases should show whether the model
  is clipping as `out_of_bounds`, using a passthrough, or reading ordinary tile
  data.

## Recommended Next Work

Best next step:
- Continue the early-game BizHawk playthrough beyond the now-confirmed
  first-two-map smoke test. Focus on command menus, object explorer ergonomics,
  first combat, shops/inns, and any repeatable audio glitches during object
  browsing, diagnostics, pathfind, or auto-walk.

Suggested live check:
- Use `./launch_dw.sh` for BizHawk by default. Use
  `./launch_dw.sh --emulator fceux`, `./launch_fceux.sh`, or
  `launch_fceux.ps1` only when checking the fallback path.
- The old door/stairs verification is now passed manually. Re-run
  `report_door_state` / `inspect_tile:4,7` only if the door regression returns.
- Use the saved post-dialogue state for quick repro loops.
- Use `reset_scan_stats`, play for 10-20 seconds, then `report_scan_stats` if
  lag returns.
- If audio stutters under load, use the cleanest repro available and capture
  `reset_scan_stats` / `report_scan_stats` around only that action. Also check
  fresh `CMD_TIMING` lines before assuming steady-frame-loop lag.
- If route/path command glitches remain, check `CMD_TIMING` lines first, then
  use `reset_scan_stats`/`report_scan_stats` around exactly one command to see
  whether `debug_tools.tick`, `objects.check_refresh`, or pathfinding dominates.
- If random background-window audio freezes remain without fresh
  `CMD_TIMING`/scan-profile spikes, investigate BizHawk/Windows focus or
  priority behavior separately from Lua script performance.
- Keep the current BizHawk audio baseline unless it causes a new problem:
  `SoundBufferSizeMs=200`, `SoundThrottle=true`, `FrameSkip=0`, and
  `Rewind.Enabled=false`. Patch these only while EmuHawk is closed.

Decision still open:
- When BizHawk survives enough real gameplay, decide whether to keep FCEUX as a
  maintained fallback or archive it as legacy support.

## Gameplay Direction

Once emulator stability is settled, return to real playtesting:
- Screen reader narration during normal play
- Object navigation usability
- Combat/menu/item/shop/chest/stair workflows
- Route reliability during actual gameplay rather than survey-only loops
- Small professional cleanup as work proceeds

## Active Project Memory Files

Use this hierarchy:
- `AGENTS.md`: project rules, priorities, command model, and accessibility preferences
- `PROJECT_MEMORY.md`: durable architecture facts and long-lived lessons
- `PLAYTESTING.md`: gameplay issue queue and player-facing polish notes
- `session_handoff.md`: this concise active resume
- `handoff_archive/`: historical evidence only

Do not rely on assistant-private memory as the only record of current project state.
