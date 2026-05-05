# Session Handoff - Active Resume

Updated: 2026-05-04

## Current Focus

The BizHawk emulator swap is now good enough to call successful. The current
branch is adding player-facing quality-of-life features before the next normal
gameplay pass, while preserving FCEUX as an explicit fallback.

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

2026-05-04 QoL feature batch implemented in the worktree:
- `auto_walk` now speaks progress every 6 completed queued steps on longer
  routes and announces route completion. When the target is an NPC, arrival
  briefly holds that NPC slot in place and prompts the player to use TALK.
- Object navigation filters are now player-facing categories:
  All, NPCs, Services, Treasure, Travel, and Doors. `Q` cycles forward;
  `Shift+J` / `Shift+L` cycle filters backward/forward, and `Shift+K` jumps
  directly back to All without also speaking the current object.
- Object navigation also has a separate pathability layer on `Shift+O`.
  It cycles All, Reachable, and Unreachable, stacking with the category filter
  (for example `Treasure, reachable`). The debug command is
  `pathability_filter`, with `:all`, `:reachable`, `:unreachable`, and
  `:refresh` forms. Reachability is computed on demand with shared blocking,
  ignores moving NPC occupancy, and resets to All on overworld maps where
  interior A* reachability is unavailable.
- Object-browser command registration moved out of `main.lua` into
  `object_commands.lua` to keep main's local-variable pressure down while
  adding the pathability command.
- Session-only visited flags are map-scoped. `Shift+V` / `mark_visited` marks
  the current object; TALK followed by real dialogue marks an adjacent NPC
  automatically; `clear_visited` clears the current map and
  `clear_visited:all` clears all maps.
- Selected-object teleport is available through configurable hotkeys:
  `Shift+Enter` for exact target cell, and `Shift+Up/Down/Left/Right` for the
  adjacent cell on that side of the selected object. Teleport reuses the
  existing safe refusal checks, rejects NPC-occupied landings unless forced
  through the debug command, normalizes movement state, and suppresses leaked
  D-pad/Start input for a few frames. The NPC-occupied landing check now reads
  live NPC RAM directly instead of forcing a full object-list rebuild.
- Manual selected-object teleport failures now use a simpler player-facing
  refusal when the target cell is not walkable. The debug command still keeps
  the developer hint about `near` / `force`.

Manual test finding from the first QoL pass:
- The reported "keyboard/controller input stopped responding" after teleport
  did not show a script crash or lost emulator polling. A follow-up
  `report_position input_status report_path_state speech_status` command was
  consumed at frame `113460`, reporting map `0x05`, position `(4,6)`,
  `keys=-`, and speech ready.
- The log shows the player had teleported north of the door at `(4,7)` to
  `(4,6)`, then multiple manual directions were seen by `auto_step` and timed
  out as blocked. At the live snapshot, NPC blockers occupied `(3,6)` and
  `(5,6)`, the door blocked south, and the north edge was the known noisy
  `(4,6)->(4,5)` doorway seam. Treat this as a boxed-in landing/pathing
  situation, not an input bridge failure.
- `report_path_state` itself took `1476 ms` because it builds current blocker
  state; avoid using that command as a routine player-facing check during
  manual testing.

Manual test finding from the auto-walk/TALK pass:
- Auto-walk reached the King at map `0x05` by standing at `(3,4)` beside the
  target at `(3,3)`, but the final route step was left, so the hero was still
  facing west. TALK then produced `There is no one there.` even though the NPC
  was adjacent.
- `route_manager.lua` now queues a short post-arrival facing press toward
  adjacent interaction targets before prompting TALK, and the NPC hold default
  is longer (`auto_walk_npc_hold_frames=1200`) so manual menu selection has
  more time. Failed TALK text no longer marks the adjacent NPC as visited.

Latest manual playtest notes:
- Live `Shift+O` follow-up: the first manual test did not reach
  `hotkeys.lua` because the existing checked-in `dw_access.ini`
  `bizhawk_keyboard_hotkey_allowlist` was an explicit override missing
  `key_pathability_filter`. The setting itself had been auto-appended, but the
  allowlist still blocked the combo while full BizHawk hotkeys were off.
  `dw_access.ini` now includes `key_pathability_filter` in the allowlist;
  `reload_config` was consumed at frame `14580`, and command-file
  `pathability_filter` logged `All, reachable. Chest: 1 east (1 of 8)`.
  The browser was reset with `pathability_filter:all`, so the next physical
  `Shift+O` press should cycle to Reachable.
- Auto-walk is mostly working as expected after the facing/TALK patch. There
  may still have been an auto-walk failure on Guard 1; review fresh logs before
  changing route behavior.
- The false-visited regression test through failed TALK now behaves correctly
  in manual testing.
- New investigation target for tomorrow: in certain parts of the map, the
  command menu does not read correctly. Treat this as likely position/map-region
  dependent. Capture `report_position`, `input_status`, and
  `report_movement_state:menu_bad_region` at a bad tile, then compare with a
  nearby good tile before patching parser logic.

Validation already run for this batch:
- `luac -p config.lua hotkey_filter.lua hotkeys.lua objects.lua
  object_commands.lua route_manager.lua main.lua test_hotkey_filter.lua
  test_hotkeys.lua test_objects.lua test_route_manager.lua`
- `lua test_hotkey_filter.lua`
- `lua test_hotkeys.lua`
- `lua test_objects.lua`
- `lua test_route_manager.lua`
- `python3 run_tests.py --allow-missing-speech-dep` passed with the known WSL
  `accessible_output2` missing warning and `cmd: not found` speech-bridge noise.
- `git diff --check`

Latest BizHawk transition checkpoint:
- Pending wrap-up commit: BizHawk stabilization and main-menu/playtesting polish
- Previous committed baseline: `a5386bc Make BizHawk the default emulator path`

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
  player readouts, object explorer/navigation shortcuts J/K/L/O/U/Q,
  `Shift+F` NPC freeze, and compact `Ctrl+N` tile/coordinate diagnostics.
  Heavier developer diagnostics (`Ctrl+M`, `Ctrl+D`, `Ctrl+Y`) are behind
  `enable_bizhawk_diagnostic_hotkeys`; the generated/shipping default is
  `false`, while the current checked-in `dw_access.ini` is intentionally
  `true` for manual testing.
- The `Ctrl+N` tile/coordinate hotkey now speaks only the compact coordinate/tile
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
- J/K/L/Q object-browser hotkeys explicitly request brief descriptions:
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
- 2026-04-30 route-turn follow-up after the user's first-town playtest passed:
  `luac -p auto_step.lua pathfinder.lua route_manager.lua config.lua
  test_auto_step.lua`, `lua test_auto_step.lua`, `lua test_route_manager.lua`,
  `lua test_pathfinder.lua`, and `git diff --check`. The pathfinder test still
  prints the known WSL-side Tolk/`cmd` warning before passing.
- 2026-04-30 route-planning/object-refresh follow-up passed:
  `luac -p pathfinder.lua objects.lua main.lua test_pathfinder.lua
  test_objects.lua`, `lua test_pathfinder.lua`, `lua test_objects.lua`,
  `lua test_route_manager.lua`, `lua test_map_survey.lua`,
  `lua test_auto_step.lua`, and `git diff --check`. `test_pathfinder.lua` still
  prints the known WSL-side Tolk/`cmd` warning before passing.
- 2026-04-30 route-lag/drift follow-up passed: `luac -p auto_step.lua
  route_manager.lua config.lua pathfinder.lua map_reader.lua objects.lua
  main.lua test_auto_step.lua test_route_manager.lua test_pathfinder.lua
  test_map_reader.lua test_objects.lua test_map_survey.lua`,
  `lua test_auto_step.lua`, `lua test_route_manager.lua`,
  `lua test_pathfinder.lua`, `lua test_map_reader.lua`,
  `lua test_objects.lua`, `lua test_map_survey.lua`, and `git diff --check`.
  `test_pathfinder.lua` still prints the known WSL-side Tolk/`cmd` warning
  before passing.
- 2026-04-30 route-cleanup refresh follow-up passed:
  `luac -p route_manager.lua config.lua test_route_manager.lua`,
  `lua test_route_manager.lua`, `lua test_auto_step.lua`, `lua test_objects.lua`,
  and `git diff --check`.
- Live BizHawk validation after that patch relaunched quick slot 1, selected
  Person 4 and then Person 2 in Brecconary, and completed both auto-walks with
  neutral input, no runtime blockers, no `ROUTE_PLAN_TIMING` spikes, and
  `objects.check_refresh max_ms=0`.
- 2026-04-30 name-entry follow-up passed:
  `luac -p main.lua config.lua hotkeys.lua debug_tools.lua`,
  `lua test_state.lua`, `lua test_hotkeys.lua`, and `git diff --check`.
  The live pre-reload log only showed title/name-entry state with no held input;
  the code patch still needs a Lua reload before user retest.
- 2026-04-30 main-menu follow-up passed:
  `luac -p state.lua main.lua test_state.lua`, `lua test_state.lua`, and
  `git diff --check -- state.lua main.lua test_state.lua`. User logs showed
  erase-confirmation screens being misclassified as field/map `0x00`, which
  let dialogue/map/auto-step logic run on title-menu input. `state.lua` now
  treats the erase confirmation and name-entry grid as title screens even when
  save RAM contains a valid level, `main.lua` keeps auto-step off during
  title-to-field debounce, and the name-entry A guard now requires a short
  stable release before accepting another A press. This still needs a Lua
  reload and live retest of "Erase a quest" plus name entry.
- Important BizHawk input finding from the next retest: normal NES `P1 A` is
  `X`, normal `P1 B` is `Z`, `Start` is `Enter`, and `Select` is `Space` in
  `D:\emulation\bizhawk\config.ini`. `S` is not normal A; it is bound under
  `AllTrollersAutoFire` as NES `P1 A` autofire, with one-frame on/off pulses.
  Avoid `S` for name entry and erase confirmation. If extra A confirms or map
  announcements continue with `X`, collect a fresh `report_title_state` /
  `trace_input:300` capture.
- Hotkey remap follow-up: `hotkeys.lua` now accepts modifier combos such as
  `Ctrl+N` and `Shift+F`, and `hotkey_filter.lua` only passes combo components
  through BizHawk's allowlist when the whole combo is actually held. Current
  layout keeps frequent object keys unmodified (`J/K/L/O/U/Q`), puts less-used
  info hotkeys on `Shift+key`, puts diagnostics on `Ctrl+key`, and avoids
  BizHawk NES control/autofire keys (`X`, `Z`, `Enter`, `Space`, `A`, `S`).
- King-dialogue regression follow-up: live probe after entering the game showed
  `state=field` on map `0x05`, `UPPER_STATE ... lower_len=97`, but no
  `check_dialogue` scan-profile entry; `check_title_screen` had kept running
  in field. Root cause was the title-to-field debounce counter not being
  cleared after "Game started.", so `in_gameplay` stayed false forever.
  `main.lua` now clears `field_from_title_ct` when `FIELD_DEBOUNCE` completes.
  The next live log confirmed king/NPC dialogue auto-read again.
- 2026-05-01 command/dialogue polish passed:
  `luac -p main.lua text.lua menu.lua test_text.lua test_state.lua
  test_hotkeys.lua test_hotkey_filter.lua`, `lua test_text.lua`,
  `lua test_state.lua`, `lua test_hotkeys.lua`, `lua test_hotkey_filter.lua`,
  and `git diff --check -- main.lua text.lua test_text.lua`. `main.lua` now
  speaks the highlighted command item when the field command menu opens, for
  example `Command. TALK`, and `text.lua`/`read_y1_dialogue()` skip persistent
  status rows such as `Bill LV 1 HP 15 MP 0 G 120 E 0` before they can be
  treated as lower dialogue. Needs Lua reload and a quick live retest of command
  menu open plus post-dialogue dismissal.
- Follow-up live retest showed the status row could still speak from the upper
  dialogue path. `report_upper_dialogue_state` confirmed `upper`, `baseline`,
  and `announced` were the status row while `lower_len=0`. `main.lua` now also
  suppresses extracted upper-dialogue `new_text` when that extracted fragment is
  itself status text, logging `UPPER_DIALOGUE_SUPPRESS_STATUS` instead of
  speaking it. Validation: `luac -p main.lua text.lua test_text.lua`,
  `lua test_text.lua`, and `git diff --check -- main.lua text.lua
  test_text.lua`. The patch was auto-reloaded in BizHawk and confirmed with
  `launcher_probe:upper-status-guard-loaded`; it still needs the user's hands-on
  post-dialogue dismissal retest.
- A broader `python3 run_tests.py --allow-missing-speech-dep` run passed its
  Lua test portion, then failed at the known sandbox write boundary while
  trying to write `__pycache__` and `dw_commands.txt`. The rerun requiring
  unsandboxed writes was intentionally not pursued because the session was
  wrapping up.
- 2026-05-01 diagnostic-hotkey gate follow-up passed:
  `luac -p hotkey_filter.lua config.lua test_hotkey_filter.lua`,
  `lua test_hotkey_filter.lua`, `lua test_hotkeys.lua`, `git diff --check`,
  and `python3 run_tests.py --allow-missing-speech-dep`. The full run only
  showed the known WSL-side speech dependency warning / `cmd` noise.
- 2026-05-01 quick manual retest confirmed the diagnostic gate behaves as
  intended with `enable_bizhawk_diagnostic_hotkeys=true`: the heavier diagnostic
  key combos pass through and activate the proper functions.
- 2026-05-01 quick live map `0x05` movement/pathing cycle started from
  `(3,4)` in the throne room. Object enumeration found 9 objects, including the
  closed door at `(4,7)` and stairs at `(8,8)`. `inspect_tile:4,7` still reports
  `reason=door_closed`, while `inspect_tile:8,8` reports `reason=passthrough`.
  `auto_walk` completed a 1-step move to `(4,4)` and a rerouted walk to Guard 3
  ending at `(5,5)`. During the Guard 3 route, the first queued `down` from
  `(4,4)` to `(4,5)` timed out once and logged `NEW BLOCK`, but a controlled
  `probe_edge:DOWN` from `(4,4)` then moved successfully to `(4,5)`. Treat this
  seam as noisy/transient route-executor evidence, not permanent map data.
- The same map `0x05` cycle exposed debug-command hitches: `report_path_state`
  repeatedly logged about 1.4-1.7 seconds, `inspect_move:UP` logged 1.413s,
  `inspect_move:DOWN` logged 0.972s, `pathfind_adjacent:4,4` logged 1.564s,
  `pathfind_to:8,8` logged 1.004s, and `probe_edge:DOWN` logged 1.593s.
  Focused route execution itself looked much healthier: the Guard 3 route
  window had `objects.check_refresh max_ms=0`, `auto_step.update max_ms=1`, and
  `debug_tools.tick max_ms=2`. The player was restored to `(3,4)` afterward.

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
- Auto-walk lag/drift is now substantially improved in both live logs and the
  user's hands-on retest. The current worktree addresses the observed causes:
  route-command refresh/freeze overhead, post-route object refresh, and queued
  movement drift from sticky D-pad state after the route inject window.
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
- The latest live log from the first-town manual run showed queued auto-walk
  direction changes could continue the previous direction for one more cell:
  after moving south to `(1,4)`, a queued `right` completed at `(1,5)` while
  the planned seam was `(2,4)`, and a later queued `down` from `(3,5)`
  completed at `(4,5)` while the planned seam was `(3,6)`. `auto_step.lua` now
  adds a configurable turn-settle pause only when queued route direction
  changes (`auto_step_route_turn_settle_frames=16`).
- `pathfinder.lua` now keeps chosen-path summaries but suppresses tile-by-tile
  chosen-path dumps unless `pathfind_log_steps=true`, and
  `route_manager.lua` logs `ROUTE_PLAN_TIMING ... ms=...` for plans over
  25 ms so hotkey-triggered `O`/`U` lag is visible even when no `CMD_TIMING`
  line is produced.
- The next live log produced a concrete route-planning spike:
  `ROUTE_PLAN_TIMING map=0x08 start=(0,15) target_id=npc_15 ... path_len=2
  ms=1978.000`. The queued walking phase then completed the expected 2-step
  route with the new turn-settle line, so the lag was in adjacent-route planning
  rather than the step executor. `pathfinder.lua` now sorts adjacent candidates
  by lower-bound distance, skips candidates that cannot beat the current best
  path, and only computes reachable-area/open-exit diagnostics when needed for
  equal-length ties or no-path survey evidence.
- The same user report explained the quickload/town object oddity: Brecconary
  initially showed only "Exit to World Map" because interior map-entry refreshes
  intentionally build static objects first and defer NPC parsing, but BizHawk's
  120-frame object-refresh throttle could delay the second phase. `objects.lua`
  now exposes `needs_refresh(map_id)`, and `main.lua` lets map changes/deferred
  refreshes bypass the periodic throttle.
- Live retest after reloading confirmed the object-refresh fix felt good: the
  user did not notice the objects missing. The next auto-walk log still showed
  two problems: route planning was still slow
  (`ROUTE_PLAN_TIMING map=0x08 start=(0,15) target_id=npc_4 ... path_len=13
  ms=1836.000`), and the route drifted during turn-settle at `(4,14)` to
  `(5,14)`, causing `route_drift_off_path`. `auto_step.lua` now actively sends
  neutral D-pad frames throughout route-settle, and `map_reader.lua` /
  `pathfinder.lua` now provide and consume per-plan walkability snapshots so A*
  avoids repeated slow map-reader checks.
- Another live retest showed both `U` auto-walk and `O` show-path still lagged:
  auto-walk plans logged `path_len=13 ms=1852.000` and `path_len=10
  ms=1238.000`; show-path logged `path_len=7 ms=1422.000` and even
  `path_len=1 ms=1514.000`. Because a one-step preview still took about
  1.5 seconds, treat the remaining lag as fixed route-command overhead before
  blaming path length alone.
- `route_manager.lua` now skips forced live NPC refresh before BizHawk `O`/`U`
  plans by default (`bizhawk_route_refresh_npcs=false`) and skips BizHawk
  auto-walk's per-frame NPC RAM freeze by default
  (`bizhawk_autowalk_freeze_npcs=false`). FCEUX keeps the old default behavior,
  and both BizHawk behaviors remain opt-in through config.
- The same retest produced two newer drift signatures during turn-settle: after
  a first `right` step from `(0,15)` to `(1,15)`, the player slid to `(2,15)`
  before the planned `up`; after a right segment from `(6,16)` to `(7,16)`,
  the player slid to `(8,16)` before the planned `up`. `auto_step.lua` now also
  neutralizes queued route input after the inject window, so sticky `joypad.set`
  state cannot commit the next tile before settle/turn handling runs.
- `inspect_tile` and `inspect_move` logs now include map dimensions and the
  walkability `reason`, so future bad-grid cases should show whether the model
  is clipping as `out_of_bounds`, using a passthrough, or reading ordinary tile
  data.
- Latest 2026-04-30 quick-slot-1 follow-up: `auto_step.lua` now resets
  movement-start tracking on timeout retry and the default config sets
  `auto_step_turn_repress_limit=0`, avoiding the eager turn-repress path that
  created false blocked steps. In the live Brecconary route to Person 2,
  auto-walk reached `(10,15)` with neutral input and did not reproduce the old
  route-settle drift points.
- `objects.lua` now prewarms the current interior map grid during map-entry
  refresh. After waiting for objects to populate, `pathfind` plus `auto_walk`
  to Person 2 produced no `ROUTE_PLAN_TIMING` or `CMD_TIMING` lines, compared
  with the previous 1.7-1.9 second first-route spike. Do not judge O/U lag from
  a command sent before `current_object` sees the town objects; a too-early
  command can still say "No objects found".
- Remaining known hitch: `objects.check_refresh` can still show a one-time
  deferred NPC refresh around 1.3 seconds after map entry. If the user still
  hears a post-quickload audio cutout, inspect that path next.
- The latest user retest showed manual overshoot is much better, with remaining
  overshoot mostly when rapid manual movement presses queue up. Auto-walk audio
  is also better, but the user still heard a lag spike near the end of route
  attempts. Fresh logs showed a later auto-walk did reach `(15,19)` adjacent to
  Woman 2 with neutral input and no runtime blockers, while `report_scan_stats`
  showed `objects.check_refresh max_ms=1658`. BizHawk route cleanup now skips
  the immediate post-completion/cancel object refresh by default via
  `bizhawk_route_cleanup_refresh_objects=false`; FCEUX keeps the old refresh.
- Live validation with the cleanup patch loaded completed a short route
  `(0,15)->(1,14)` to Person 4 and a longer route `(1,14)->(9,14)` to Person 2.
  Both ended adjacent to the target with `keys=- joy1=-`, `RUNTIME_BLOCKS none`,
  and `objects.check_refresh max_ms=0`. The first step can still consume one
  timeout retry before movement takes, but it recovered cleanly in both runs.
- User hands-on retest after the cleanup patch confirmed auto-walk is reaching
  intended targets and the lag feels under control.
- The name-entry double-character issue likely comes from a held A/button press
  being accepted on multiple frames by the name grid. `main.lua` now suppresses
  repeated A frames while the name-entry grid is visible, allowing the first
  frame through and forcing A false until release. A new `report_title_state`
  debug command logs title/name-entry cursor RAM, selected tile byte/character,
  controller state, and decoded title rows for future repros.
- BizHawk launchers now support quick slots:
  `./launch_dw.sh --state-slot 1 --no-wait` and
  `./launch_bizhawk.sh --state-slot 1 --no-wait`.

## Recommended Next Work

Best next step:
- Reload the Lua script and do a short hands-on BizHawk check of the new QoL
  layer before resuming ordinary early-game playtesting. Prioritize: one long
  `auto_walk`, NPC arrival hold plus TALK, `Shift+V` visited marking,
  `clear_visited`, filter cycling with `Q` / `Shift+J` / `Shift+L`, and
  selected-object teleport with `Shift+Enter` plus at least one
  `Shift+direction`.
- After that, resume combat narration, shops/inns, item/spell flows, and any
  menu/dialogue polish that appears during real play. If the status row speaks
  again after dialogue, inspect fresh `UPPER_DIALOGUE_SUPPRESS_STATUS` /
  `report_upper_dialogue_state` evidence before patching.

Suggested live check:
- Use `./launch_dw.sh` for BizHawk by default. Use
  `./launch_dw.sh --emulator fceux`, `./launch_fceux.sh`, or
  `launch_fceux.ps1` only when checking the fallback path.
- The old door/stairs verification is now passed manually. Re-run
  `report_door_state` / `inspect_tile:4,7` only if the door regression returns.
- Use the saved post-dialogue state for quick repro loops.
- For the current quick-slot town repro, use
  `./launch_dw.sh --state-slot 1 --no-wait`, wait until `current_object` shows
  town objects, then run `reset_scan_stats`, one `pathfind` or `auto_walk`, and
  `report_scan_stats`.
- Reload the Lua script before judging the new route-turn, route-manager,
  pathfinder, map-reader, or object-refresh patches. A config-only
  `reload_config` is not enough for `auto_step.lua`, `route_manager.lua`,
  `pathfinder.lua`, `map_reader.lua`, `objects.lua`, or `main.lua` changes.
- Use `reset_scan_stats`, play for 10-20 seconds, then `report_scan_stats` if
  lag returns.
- If audio stutters under load, use the cleanest repro available and capture
  `reset_scan_stats` / `report_scan_stats` around only that action. Also check
  fresh `CMD_TIMING` lines before assuming steady-frame-loop lag.
- If route/path command glitches remain, check `CMD_TIMING` lines first, then
  `ROUTE_PLAN_TIMING` lines. For the known Brecconary-style repros, compare
  the old timings after a Lua reload: 1978 ms for a 2-step `npc_15` route,
  1836/1852 ms for 13-step `npc_4` routes, 1238 ms for a 10-step auto-walk,
  and 1422/1514 ms for show-path previews. Also watch for absence/presence of
  `route_drift_off_path`, especially the prior drift points `(4,14)->(5,14)`,
  `(1,15)->(2,15)`, and `(7,16)->(8,16)` during route settle. Use
  `reset_scan_stats`/`report_scan_stats` around exactly one command if timings
  still point away from route planning.
- If map `0x05` shows a fresh `(4,4)` to `(4,5)` route block, reproduce it with
  a controlled `probe_edge:DOWN` before patching anything. The latest probe
  moved successfully after one queued-route block, so the seam is currently
  noisy rather than a confirmed directional blocker.
- If audio cuts out while using debug commands on map `0x05`, check
  `report_path_state`, `inspect_move`, explicit `pathfind_adjacent`, and
  `probe_edge` `CMD_TIMING` lines. The latest run showed second-scale debug
  command hitches even while focused auto-walk execution stayed cheap.
- If no `CMD_TIMING`/`ROUTE_PLAN_TIMING` appears but audio still cuts out,
  inspect `objects.check_refresh max_ms` in `report_scan_stats`; that is now
  the most suspicious remaining script-side spike.
- If random background-window audio freezes remain without fresh
  `CMD_TIMING`/scan-profile spikes, investigate BizHawk/Windows focus or
  priority behavior separately from Lua script performance.
- Keep the current BizHawk audio baseline unless it causes a new problem:
  `SoundBufferSizeMs=200`, `SoundThrottle=true`, `FrameSkip=0`, and
  `Rewind.Enabled=false`. Patch these only while EmuHawk is closed.

Fallback decision:
- Keep FCEUX as an explicit fallback for now, but new gameplay/accessibility
  work should assume BizHawk first.

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
