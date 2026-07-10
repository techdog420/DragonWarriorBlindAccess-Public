# Current Investigation Scratchpad

Updated: 2026-07-09

## 2026-07-04 Cantlin Town First Survey

- Baseline: fresh command polling verified with
  `launcher_probe:codex_cantlin_survey`; `report_position` confirmed
  Cantlin `map=0x0A` at `(20,24)`, `DOOR_STATE keys=6`, and
  `RUNTIME_BLOCKS map=0x0A none`.
- Parked-NPC survey preflight from `(20,24)` was viable:
  `targets=20`, `reachable_area=128`, `reachable_targets=20`,
  `unreachable_targets=0`, and `open_exits=north|south|west|east`.
- `survey_objects:park_npcs` run 1 started at `(20,24)` with 20 targets.
  It completed `Merchant 1` at `(21,25)` and `Guard 2` at `(20,21)`, then
  stalled on `Old Man 4` at `(22,22)`. The run was manually stopped after
  target 3; summary: `targets=3 successes=2 failures=1`, with Old Man 4
  classified as `suspected_engine_blocked_tile`.
- Old Man 4 failure details: survey ended at `(25,23)` and reported suspected
  cells around `21,22|21,21|22,21|23,21|24,22|25,22|26,22|23,23|24,24|25,24|26,23|24,23`.
  `SURVEY_STRONG_CANDIDATES map=0x0A none`, so do not promote a broad block
  batch from this run.
- Read-only follow-up from `(25,23)` showed `debug_pathfind_adjacent:22,22`
  expects a simple stand route to `(22,23)` via `3 west`, and tile inspection
  says `(24,23)`, `(25,23)`, `(25,22)`, `(21,22)`, and `(20,22)` are statically
  walkable. The failed route is therefore a live engine/state issue, not an
  obvious static wall.
- Contamination/recovery boundary: after the first direct `auto_walk_blocker`
  and same-origin `probe_edge:LEFT`, `report_movement_state` still showed a
  stuck left/movement state. `recover_fceux_input.sh` cleared the FCEUX
  `LeftAlt` latch (`INPUT_STATUS tag=fceux_recovery keys=- joy1=- bridge=-
  left_alt=false`), then `reset_movement_state` zeroed the movement/subpixel
  bytes. Treat evidence before this cleanup as noisy unless rechecked after the
  reset.
- Clean same-origin probes after input/movement cleanup from `(25,23)`:
  `(25,23)->LEFT`, `(25,23)->DOWN`, `(25,23)->UP`, and `(25,23)->RIGHT` all
  timed out with `EDGE_PROBE_MODEL_MISMATCH ... kind=blocked_despite_open_preview`.
  Runtime blocks for LEFT and DOWN were injected only long enough to retest the
  route and were cleared afterward (`RUNTIME_BLOCKS map=0x0A none`).
- Current live state after cleanup: hero remains at Cantlin `(25,23)`, no
  runtime blocks. Because all four exits from `(25,23)` blocked cleanly, this
  looks like a standable but boxed engine pocket reached during the survey.
  Do not promote it directly to `map_reader.lua` until either the entry edge is
  reconstructed from clean walking or the pocket is deliberately modeled as an
  isolated/non-routeable tile.
- Hard-lock follow-up: the user's controller lock was not a Lua crash or total
  emulator hang. `qfceux` was OS-responsive, `launcher_probe` and later
  `trace_input:180` were consumed, and `dw_keyboard_input.txt` was neutral.
  Windows did not report Alt or any direction physically held, but FCEUX/Lua
  continued to see stable `keys=LeftAlt joy1=- bridge=-`; the game input byte
  remained `buttons=0x20`. Treat all movement evidence from this live state as
  contaminated until recovery/relaunch plus a fresh baseline clears or explains
  that stale game-side button byte.
- Recovery attempts: `recover_fceux_input.sh` foregrounded FCEUX, reset the
  bridge, and briefly cleared the stale Alt report
  (`INPUT_STATUS tag=fceux_recovery keys=- joy1=- bridge=- left_alt=false`).
  It did not clear the game-side `buttons=0x20`, and FCEUX later relatched
  `LeftAlt`. `clear_input` and a raw `START`/`B` pulse did not open the menu or
  clear `buttons=0x20`; the raw `START` did reach Lua as `joy1=start`. No
  scripted relaunch was attempted because `SDL.AutoResume = 0` and there was no
  obvious current Cantlin quickslot, so relaunching from Codex risked landing
  in unrelated state.
- Source guardrail added after restart: direct `probe_edge`,
  `probe_edge_verify`, and seeded edge probes now check for the contamination
  signature before starting. If Lua joy and the bridge are idle while
  `$0047`/`BUTTONS_PRESSED` remains nonzero, the command refuses and logs
  `EDGE_PROBE_ABORT reason=input_contaminated ...` instead of producing new
  movement evidence. This needs a Lua reload before it affects the live
  emulator session.
- Reload replay / DO NOT PROMOTE: after user reloaded Lua, focused unit tests
  passed (`luac -p`, `lua test_debug_tools.lua`, and `git diff --check`), and
  `launcher_probe:codex_guard_reload` confirmed command polling. Fresh baseline
  was Cantlin `map=0x0A` at `(20,22)`, `keys=6`, no runtime blocks, stale
  FCEUX `LeftAlt` only, and `buttons=0x00`.
- The repeat `report_survey_start:park_npcs` was viable from `(20,22)` with
  `targets=21`, `reachable_area=128`, `reachable_targets=21`, and
  `open_exits=north|south|west|east`. The follow-up
  `survey_objects:park_npcs` immediately looped on `Old Man 4` at `(22,22)`
  with route-timeout reroutes from `(20,22)`.
- Contaminated replay details: survey logs showed repeated
  `movement_started=true` twitch timeouts for LEFT, RIGHT, UP, and DOWN from
  `(20,22)`, with temporary suspected cells `(19,22)`, `(21,22)`, `(20,21)`,
  and `(20,23)`. Manual `stop_survey` produced `SURVEY_COMPLETE targets=1
  successes=0 failures=1 suspected_engine_blocked=1`; treat this whole replay
  as movement-state evidence, not Cantlin geometry.
- Read-only `inspect_move:20,22,UP/DOWN/LEFT/RIGHT` says all four adjacent
  destinations are `effective_passable=true`. `recover_fceux_input.sh` cleared
  the stale Alt latch (`keys=- joy1=- bridge=- left_alt=false`), but a small
  post-recovery `simulate_input:RIGHT` still only twitched and left the hero at
  `(20,22)`. Current recommendation: do not continue Cantlin surveys from this
  emulator state; re-establish a known-clean walked position or restart/load a
  clean state before collecting map evidence.
- Manual recovery replay: after the user verified the emulator manually and
  reloaded Lua, `launcher_probe:codex_cantlin_reverify` confirmed the command
  loop. Baseline was Cantlin `(18,24)`, `keys=6`, no runtime blocks, stale
  LeftAlt only, and `buttons=0x00`. `auto_walk_blocker:19,24` proved queued
  route movement was viable by moving east to `(19,24)` via seam retry.
- The next `survey_objects:park_npcs` again drove toward `Old Man 4`, walked
  around the target area, then returned to the suspect `(25,23)` pocket. At
  `codex_survey_timeout_state`, Lua/bridge input were idle but
  `buttons=0x20` was stuck again. `stop_survey` completed with
  `targets=1 successes=0 failures=1 suspected_engine_blocked=1`.
- Live guard proof: in the reproduced contaminated state, `probe_edge:LEFT`
  refused with
  `EDGE_PROBE_ABORT reason=input_contaminated command=probe_edge keys=LeftAlt joy=- bridge=- buttons=0x20`.
  `recover_fceux_input.sh` did not clear the game-side byte; the post-recovery
  state remained Cantlin `(25,23)` with `buttons=0x20`. Do not continue surveys
  or edge probing from this state without a fresh manual recovery/reload.
- Source guardrail follow-up: the shared contamination detector now also stops
  survey and auto-walk work. `survey_objects` refuses contaminated startup,
  aborts active runs from tick/route events without recording candidates, and
  clears route context; auto-walk refuses before planning and aborts in-flight
  route blocks before reroute planning or seam-observation recording. Verified
  with `lua test_map_survey.lua`, `lua test_route_manager.lua`,
  `lua test_debug_tools.lua`, `luac -p ...`, `git diff --check`, and
  `python3 run_tests.py --allow-missing-speech-dep`. FCEUX still needs a
  manual Lua reload before the new live behavior is active.
- Post-save-state retest found a guardrail false positive, not new Cantlin
  geometry. After the user restored a save state, fresh baseline was clean at
  Cantlin `(20,22)` with `buttons=0x00`, no menu, and no runtime blocks.
  Broad `survey_objects:park_npcs` and targeted
  `survey_target:Guard 2,park_npcs` both started movement normally, but
  `map_survey.tick` saw the expected active auto-step game button byte
  (`buttons=0x10`) while joy/bridge were idle and aborted as
  `reason=input_contaminated`. Source fix: skip the tick-time contamination
  check while `auto_step.get_active_step_state()` is non-nil, leaving startup,
  route-event, and route-manager block guards intact. Verified with
  `lua test_map_survey.lua`, `lua test_route_manager.lua`,
  `lua test_debug_tools.lua`, `luac -p ...`, `git diff --check`, and
  `python3 run_tests.py --allow-missing-speech-dep`. FCEUX needs another manual
  Lua reload before continuing live survey.
- Reload after the tick-guard refinement: command polling verified with
  `launcher_probe:codex_after_tick_guard_reload`. Fresh baseline was Cantlin
  `(20,21)`, `buttons=0x00`, no menu/guard, and no runtime blocks. Preflight
  `report_survey_start:park_npcs` was viable (`targets=21`,
  `reachable_targets=20`, `unreachable_targets=1`, `open_exits=north|south|west|east`).
  `survey_objects:park_npcs` started and the refined tick guard allowed normal
  active movement/rerouting to proceed through many Old Man 4 seam-retry steps.
  The run eventually aborted on a real stuck-input signature at `(23,26)`:
  after a seam retry right from `(23,26)` blocked, Lua joy/bridge were idle but
  game input RAM remained `buttons=0x80`; both survey and auto-walk guards
  refused with `reason=input_contaminated`. A post-abort snapshot still showed
  Cantlin `(23,26)`, `buttons=0x80`, no runtime blocks. Standard
  `recover_fceux_input.sh` did not clear it; follow-up snapshot remained
  `(23,26)`, `buttons=0x80`. Treat this as emulator/input contamination, not
  promotable Cantlin map evidence.
- After another save-state restore, fresh baseline was Cantlin `(20,22)`,
  `buttons=0x00`, no menu/guard, and no runtime blocks. Targeted
  `survey_target:Guard 2,park_npcs` avoided the Old Man 4 opener and made real
  route progress north to `(20,8)`, then rerouted around `(20,8)->UP` and
  completed a step right into `(21,8)`. The survey then aborted on tick with
  `buttons=0x80`; follow-up snapshot had progressed to `(22,8)` and was clean
  again (`buttons=0x00`, no runtime blocks). This was another guard timing
  false positive: route-settle / between-step time can briefly leave the game
  button byte nonzero after a queued step completed. Source fix: skip tick-time
  contamination checks while `auto_step.is_route_active()` is true as well as
  while `get_active_step_state()` is non-nil. Verified with
  `lua test_map_survey.lua`, `lua test_route_manager.lua`,
  `lua test_debug_tools.lua`, `luac -p ...`, `git diff --check`, and
  `python3 run_tests.py --allow-missing-speech-dep`. FCEUX needs another
  manual Lua reload before continuing live survey from the clean `(22,8)` area
  or after a fresh save-state restore.
- Reload validation after the route-active tick fix: command polling verified
  with `launcher_probe:codex_after_reload_20260705`; baseline was Cantlin
  `(20,22)`, `buttons=0x00`, no runtime blocks. Retrying
  `survey_target:Guard 2,park_npcs` no longer aborted from the route-active
  contamination guard, confirming the tick false positive fix live.
- The same `Guard 2` run exposed a separate survey safety problem: it rerouted
  repeatedly around the top-wall approach and accumulated 69 blocked events /
  43 temporary route blocks before manual `stop_survey`. Final survey result:
  `movement_succeeded=false`, `failure_class=suspected_engine_blocked_tile`,
  `reason=manual_stop`, `final=(12,5)`. Post-stop snapshot was healthy:
  Cantlin `(12,5)`, `buttons=0x00`, `RUNTIME_BLOCKS map=0x0A none`, and
  `PATH_STATE target=nil`. DO NOT PROMOTE the broad suspected-tile list from
  this run; it is route-churn diagnostic noise until focused same-origin
  evidence isolates real geometry.
- Source guardrail added: `map_survey.lua` now stops a target after more than
  32 route-block events, logs `SURVEY_ROUTE_CHURN_ABORT`, cancels active route
  state, finishes the run, and classifies the target as
  `command_timing_or_state_issue` instead of clean engine-blocker evidence.
  Regression coverage: `route_churn_cap_stops_target_as_state_issue`.
  Verification passed: `lua test_map_survey.lua`, `lua test_route_manager.lua`,
  `lua test_debug_tools.lua`, `luac -p ...`, `git diff --check`, and
  `python3 run_tests.py --allow-missing-speech-dep`. FCEUX needs another
  manual Lua reload before this cap is active live.
- Reload validation for the route-churn cap: after the user reloaded Lua,
  `launcher_probe:codex_churn_reload_20260705` confirmed polling and the
  baseline was clean at Cantlin `(20,22)`, `buttons=0x00`, no runtime blocks.
  A focused `survey_target:Guard 2,park_npcs` matched the currently moving
  `npc_9` at `(24,10)` and succeeded, ending adjacent at `(23,10)`. It logged
  one reroute-only suspect `(21,11)` and `reason=reroute_succeeded_after_runtime_block`;
  do not promote that single target-route observation without focused
  same-origin proof.
- A broad `survey_objects:park_npcs` from `(23,10)` did not produce survey
  attempts because the command menu/dialogue was open (`menu_active=true`,
  `dialogue_len=23`). `stop_survey` restored all 19 parked NPCs with zero
  targets attempted, and `simulate_input:B` closed the command menu. Treat this
  as workflow contamination, not map survey data.
- Focused `survey_target:Old Man 4,park_npcs` then reproduced the hard
  input-contamination signature before the new route-churn cap could fire:
  at `(23,26)`, after 14 temporary route blocks and while under the cap,
  survey and auto-walk refused with `reason=input_contaminated`,
  `keys=LeftAlt joy=- bridge=- buttons=0x80`. Cleanup worked: the survey
  restored all 19 NPC slots, recorded no targets/results, and left no runtime
  blocks or active path. Standard `recover_fceux_input.sh` cleared/restarted
  the bridge but did not clear the game-side byte; the live snapshot remained
  Cantlin `(23,26)`, `buttons=0x80`. Stop condition: do not continue Cantlin
  movement/survey/probe work from this state.
- Reload/hypothesis check after suspecting the overworld auto-walk timing
  refinements: `launcher_probe:codex_ram_hypothesis_reload_20260705` confirmed
  polling, and baseline was clean at Cantlin `(18,23)`, `buttons=0x00`, no
  menu, no runtime blocks, and no active path. A 180-frame `trace_input` idle
  sample showed only benign stale `LeftAlt`; `dw_keyboard_input.txt` was
  neutral. Code inspection found the recent timing helpers can write movement
  engine bytes `$003C/$003D`, but not `$0047` / `BUTTONS_PRESSED`.
- Focused repro with `survey_target:npc_18,park_npcs` started run 4 cleanly
  from `(18,23)` and reproduced contamination at frame `137384`. The final
  triggering event was a queued-route `DOWN` attempt from `(25,23)`:
  `movement_started=true`, `movement_start_frame=4`, blocked after 36 frames,
  then survey/auto-walk refused with `keys=LeftAlt joy=- bridge=- buttons=0x20`.
  The guard restored all 20 parked NPC slots, recorded no target results, and
  left no runtime blocks or active path.
- Diagnostic recovery checks from the contaminated `(25,23)` state:
  `reset_movement_state` cleared `$003C/$003D` from `0x08/0x08` to `0x00/0x00`
  but left `$0047` stuck at `0x20`. `clear_input` also left `$0047=0x20`.
  This suggests the timing code may be leaving the game in a stale input-byte
  state indirectly, but the current movement reset/neutral joypad hooks are not
  enough to recover it. Next diagnostic should be an explicit, guarded
  debug-only `$0047` clear to see whether the game immediately relatches the
  byte or stays recovered.
- Source diagnostic added: `debug_tools.lua` now supports `clear_game_input`,
  which reads `BUTTONS_PRESSED` (`$0047`), writes `0x00`, re-reads it, and logs
  `GAME_INPUT_CLEAR before=... after=... addr=0x0047`. `debug_hooks.txt`
  documents it, and `test_debug_tools.lua` pins the exact one-byte write/log
  behavior. Verified with `lua test_debug_tools.lua`, `luac -p debug_tools.lua
  test_debug_tools.lua`, and `git diff --check`. FCEUX needs a manual Lua
  reload before the command is available live.
- Live validation after fresh emulator/script reload: command polling was
  confirmed with `launcher_probe:codex_clear_game_input_live_20260706`.
  Baseline was Cantlin `(20,22)`, `buttons=0x00`, no runtime blocks, and no
  active path. Running `clear_game_input` logged
  `GAME_INPUT_CLEAR before=0x00 after=0x00 addr=0x0047`, so the command is live
  and harmless against a clean byte. Repeating the bad
  `survey_target:npc_18,park_npcs` run did not reproduce stuck `$0047`; it hit
  `SURVEY_ROUTE_CHURN_ABORT` after 33 blocked events / 4 suspected tiles at
  `(20,22)`, restored all 20 parked NPCs, classified the target as
  `command_timing_or_state_issue`, and recorded no promotable map evidence.
  Post-abort state remained clean: Cantlin `(20,22)`, `buttons=0x00`, no
  runtime blocks, no active path, and 20 NPC blockers restored. Recovery from a
  genuinely contaminated `$0047` byte remains unproven until the stuck state
  recurs or is reproduced under controlled conditions.
- Follow-up survey repro after the user noted yesterday's failures were quick:
  `launcher_probe:codex_survey_repro_20260706_a` confirmed polling, baseline
  was again Cantlin `(20,22)` with `buttons=0x00`, and `lua
  test_debug_tools.lua` still passed 23 tests. A focused
  `survey_target:npc_18,park_npcs` run reproduced route churn but not input
  contamination; it hit `SURVEY_ROUTE_CHURN_ABORT` at 33 blocked events,
  restored all 20 parked NPCs, and left the state clean. A broader
  `survey_objects:park_npcs` run also routed immediately to `npc_18` and churned
  around `(20,22)` for 28 timing-block events without sticking `$0047`; it was
  manually stopped before the cap, restored all 20 NPCs, and left Cantlin
  `(20,22)`, `buttons=0x00`, no runtime blocks, and no active path. Because
  the manual stop recorded `failure_class=suspected_engine_blocked_tile`, treat
  run 3 as diagnostic churn noise and DO NOT PROMOTE its
  `21,22|20,21|20,23|19,22` suspected tiles. A post-survey `clear_game_input`
  check logged `before=0x00 after=0x00`, so recovery from a real stuck byte
  remains unproven.
- Source follow-up before the next targeted survey reload: the shared
  `debug_tools.input_contamination_refusal` path now captures and auto-clears
  idle-input/nonzero-`$0047` cases. The next real stuck-byte event should log
  `INPUT_CONTAMINATION_CAPTURE`, `GAME_INPUT_AUTO_CLEAR`, and a delayed
  `GAME_INPUT_AUTO_CLEAR_CHECK` sample while still refusing/aborting the
  contaminated command based on the pre-clear state. `map_survey.lua` now also
  classifies manual-stop route/churn evidence as `command_timing_or_state_issue`
  instead of `suspected_engine_blocked_tile`, so a manual survey stop cannot
  promote timing churn into Cantlin geometry. Verified with focused TDD
  regressions in `lua test_debug_tools.lua` and `lua test_map_survey.lua`.
- Bridge-off A/B / recovery boundary: after reload, `set_input_bridge:off`
  persisted through save-state restore and a focused Old Man 4 survey ran much
  longer, but it still reproduced the stuck input byte at `(25,23)` on a
  queued-route `DOWN` attempt: `INPUT_CONTAMINATION_CAPTURE ... buttons=0x20`,
  `GAME_INPUT_AUTO_CLEAR ... after=0x00`, and delayed
  `GAME_INPUT_AUTO_CLEAR_CHECK ... buttons=0x00`. Manual controls nevertheless
  stayed dead until the user restored a save state. Post-restore baseline at
  `(25,23)` had `buttons=0x00`, `bridge_enabled=false`, no runtime blocks, no
  active path, and `report_survey_start:park_npcs` still considered all four
  exits open/reachable; read-only `inspect_move:25,23,UP/DOWN/LEFT/RIGHT`
  also reported every edge `effective_passable=true`. Treat this as evidence
  that `$0047` is a tripwire/symptom rather than the whole root cause.
- Source mitigation after that boundary: contamination auto-clear now also
  opens a 30-frame raw-neutral `GAME_INPUT_AUTO_NEUTRAL` window via the existing
  isolation machinery. This is a mitigation/evidence cleanup step, not proven
  emulator recovery. Verified with a red/green update to
  `test_debug_tools.lua`, plus `lua test_debug_tools.lua`,
  `lua test_map_survey.lua`, `lua test_route_manager.lua`,
  `luac -p debug_tools.lua test_debug_tools.lua main.lua map_survey.lua
  route_manager.lua`, and `git diff --check`. FCEUX needs a manual Lua reload
  before live testing this behavior.
- Strong hard-lock signature after reload: command polling still worked and
  `isolate_input:180` completed, but manual controls stayed dead. The visible
  input layers were clean or recoverable: `$0047=0x00`, bridge disabled during
  the test, and `recover_fceux_input.sh` cleared the stale Alt report to
  `keys=- joy1=- bridge=- buttons=0x00`. Manual direction presses and
  Lua-injected raw `START`/`A` reached `joypad.read()` (`joy1=right`,
  `joy1=start`, `joy1=A`), but the hero did not move and raw `A` did not open
  the normal field command menu. `reset_movement_state` cleared `$003C/$003D`
  from `0x08/0x08`, but raw `A` still did not open the menu afterward. The
  user also confirmed physical controller `A` cannot open the command menu in
  this state. This is stronger evidence of a FCEUX/game-core input consumption
  wedge below the mod's visible input surfaces; restore save state or emulator
  investigation is the next honest recovery path.
- FCEUX source detour: upstream `TASEmulators/fceux` tag `v2.6.6` was cloned to
  `/mnt/d/modding/fceux-input-debug` on branch
  `codex/input-hardlock-diagnostics`. Diagnostic-only instrumentation was added
  behind `FCEUX_DW_INPUT_TRACE=1` with optional
  `FCEUX_DW_INPUT_TRACE_FILE=...`; it logs Qt key/gamepad events, Lua
  `joypad.set` / `FCEU_LuaReadJoypad` masks, core `UpdateGP`, `$4016` strobe
  and serial reads, and savestate load boundaries. Verification so far:
  `git diff --check`, `g++ -std=c++11 -fsyntax-only -DPSS_STYLE=1 -Isrc
  src/input.cpp`, `g++ -std=c++11 -fsyntax-only -DPSS_STYLE=1 -Isrc
  src/state.cpp`, and standalone syntax for `src/input_trace.h`. Full FCEUX
  build was not run because WSL and Windows both lack `cmake`; Windows also
  lacks the expected MSBuild/Qt 5.15 paths from upstream's `qwin64_build.bat`.

## 2026-07-03 Cantlin Overworld Trail

- Baseline after user relocation: `report_position` confirmed World Map
  `(15,93)` and `report_runtime_blocks` showed no runtime blocks on map `0x01`.
- `debug_pathfind_to:73,102` reported the direct coordinate guess
  `9 south, 58 east`, but `trace_path` showed this coordinate plan does not
  store an A* path (`path_length=0`), so it is guide-orientation only.
- `auto_walk_blocker:15,102` is not usable for overworld coordinate trail
  cutting in the currently running script: before cleanup it correctly refused
  because the command menu was open; after closing the menu with
  `simulate_input:B`, it reached the overworld-route branch and reported
  `No overworld route active`.
- Live movement evidence: same-origin `probe_edge:DOWN` moved from `(15,93)`
  to `(15,94)`, then another `probe_edge:DOWN` moved from `(15,94)` to
  `(15,95)`.
- Follow-up after the user healed: southbound probes confirmed the guide's
  southwest descent from `(15,95)` through `(15,97)`, `(15,99)`,
  `(15,101)`, and the southwest corner at `(15,103)`. Raw `probe_edge`
  carries often landed two tiles away, so keep the route waypoints coarse
  rather than treating every destination cell as a precise single-step proof.
- The guide-shaped east crossing is live-confirmed from `(15,103)` through
  `(17,103)`, `(19,103)`, `(21,103)`, `(23,103)`, `(25,103)`, `(27,103)`,
  `(29,103)`, `(31,103)`, and `(32,103)`.
- After the `(32,103)` battle, live route checks confirmed the first bend:
  `(32,103)->UP` carried to `(32,101)` and `(32,101)->UP` carried to
  `(32,99)`. East from `(32,103)` and east from `(32,101)` both blocked.
- Contamination boundary: user reported the emulator/controller became
  unresponsive after the later battle sequence and explicitly asked that the
  last-battle evidence be discarded and retried. Treat row-99 exploration
  after reaching `(32,99)`, including `(32,99)->RIGHT`, the `(37,99)` /
  `(35,99)` spurs, isolated-looking `(33,99)`, forced teleports to `(32,99)` /
  `(32,103)`, and all post-force blocker results as tainted route evidence.
- Read-only input diagnostics while left in the bad state: command polling and
  Lua were alive, `report_position` still showed World Map `(32,103)`,
  `report_menu_state` showed no active command menu/dialogue, and
  `report_input_guard_state` showed no suppress/teleport/menu guard. At rest
  Lua saw only stale `LeftAlt` (`joy=-`, bridge buttons `0x00`). A passive
  `trace_input:300` also saw no joypad/bridge input. Earlier manual presses did
  reach Lua as rapidly changing directions, but `auto_step` canceled each
  attempted step from the contaminated movement state.
- Recovery observation: user pressed Start; log showed
  `INPUT_STUCK_ALT_CLEAR ... joy1=start`, then command menu opened and closed.
  Normal manual movement immediately resumed: down completed from `(32,103)` to
  `(32,104)`, up returned to `(32,103)`, and another up completed to
  `(32,102)`. Fresh read-only snapshot at `(32,102)` showed no active menu, no
  input guard, no active path, and no runtime blocks. `LeftAlt` is still latched
  at idle, but the code treats LeftAlt-only FCEUX idle state as benign latch
  noise rather than synthetic input.
- Clean reprobe after Start recovery: from `(32,102)`, raw `probe_edge:UP`
  moved through `(32,101)` and carried to `(32,100)`. A second
  `probe_edge:UP` from `(32,100)` reached `(32,99)` and carried to `(32,98)`.
  After calibrating a short raw `UP,20` hold to settle exactly on `(32,99)`,
  `probe_edge:RIGHT` cleanly moved from `(32,99)` through `(33,99)` and carried
  to `(34,99)`. Further clean right probes reached `(36,99)` and then
  `(37,99)`. From `(37,99)`, `probe_edge:UP` cleanly moved through `(37,98)`
  and carried to `(37,97)`.
- Current live interruption: immediately after reaching `(37,97)`, a Wraith
  Knight battle started. The queued follow-up `probe_edge:RIGHT` was refused
  because edge probes are only available while walking on the field. Resume
  after battle from the live position if still on/near `(37,97)`, and re-run
  the east/north/south spur checks from clean field state.
- Post-Wraith clean continuation: after battle, fresh baseline confirmed field
  state at `(37,97)` with no menu/input guard/runtime blocks. Same-origin
  `probe_edge:RIGHT` moved cleanly into `(38,97)`, then immediately triggered a
  Demon Knight battle. Treat `(37,97)->RIGHT` as passable; resume after the
  Demon Knight from the live field position, likely `(38,97)`, and continue
  checking exits from that spur.
- Post-Demon clean continuation: after battle and user HEAL, fresh baseline
  confirmed field state at `(38,97)` with no menu/input guard/runtime blocks.
  Clean probes found `(38,97)->RIGHT` blocked, `(38,97)->UP` blocked, and
  `(38,97)->DOWN` open to `(38,98)`.
- The clean trail from `(38,98)` then continued east/north/east/north:
  `(38,98)->RIGHT` carried to `(40,98)`, `(40,98)->RIGHT` moved to `(41,98)`
  and triggered a Metal Slime encounter that ran away, then fresh baseline at
  `(41,98)` was clean. Continuing from there: `(41,98)->RIGHT` reached
  `(42,98)`, `(42,98)->RIGHT` blocked, `(42,98)->UP` reached `(42,97)`,
  `(42,97)->UP` blocked, `(42,97)->RIGHT` carried to `(44,97)`,
  `(44,97)->RIGHT` blocked, `(44,97)->UP` carried to `(44,95)`, and
  `(44,95)->UP` reached `(44,94)`.
- Current live interruption: a Metal Slime battle started immediately after
  reaching `(44,94)` and did not clear during the short watch window. Resume
  only after battle from a clean field baseline at/near `(44,94)`.
- Post-Metal-Slime continuation: fresh field baseline confirmed World Map
  `(44,94)` with no menu/input guard/runtime blocks. Clean probes found
  `(44,94)->UP` blocked and `(44,94)->RIGHT` open, carrying to `(46,94)`.
  The east leg continued through `(48,94)`, `(49,94)`, and `(50,94)`;
  `(50,94)->RIGHT` blocked. The route then bent north: `(50,94)->UP` reached
  `(50,93)`, and `(50,93)->UP` reached `(50,92)` before a Knight battle
  started.
- Post-Knight continuation: after battle and user HEAL, fresh field baseline
  confirmed World Map `(50,92)` with no menu/input guard/runtime blocks. Clean
  north probes moved through `(50,91)`, `(50,90)`, carried to `(50,88)`, then
  carried to `(50,86)`. `(50,86)->UP` blocked, and `(50,86)->RIGHT` carried to
  `(52,86)`. `(52,86)->RIGHT` then moved to `(53,86)` before another Knight
  battle started.
- Post-second-Knight continuation: fresh field baseline confirmed World Map
  `(53,86)` with no menu/input guard/runtime blocks. Clean east probes moved
  through `(54,86)`, `(55,86)`, `(56,86)`, `(57,86)`, `(58,86)`, and
  `(59,86)`. From the tip, `(59,86)->RIGHT`, `(59,86)->UP`, and
  `(59,86)->DOWN` all blocked, so the route backed west to `(58,86)`.
  `(58,86)->UP` reached `(58,85)`, and `(58,85)->UP` reached `(58,84)` before
  a Werewolf battle started.
- Post-Werewolf continuation: fresh field baseline confirmed World Map
  `(58,84)` with no menu/input guard/runtime blocks. From there,
  `(58,84)->UP` blocked, while right carried to `(60,84)` and `(62,84)`,
  with `(62,84)->RIGHT` blocked. The south/east side pocket from `(62,84)`
  was explored through `(62,85)`, `(63,85)`, `(63,86)`, `(65,86)`, and
  `(67,86)`; its right, up, and down exits at the tip all blocked, and the
  branch was a dead end. Backtracking exposed the real continuation:
  `(62,85)->UP` carried to `(62,83)`, then the clean route moved north to
  `(62,82)`, east to `(63,82)`, north to `(63,81)`, east to `(64,81)`, north
  to `(64,80)`, and east via carries through `(66,80)`, `(68,80)`, and
  `(70,80)`.
- Post-Magiwyvern continuation: after battle and user HEALs, fresh field
  baseline confirmed World Map `(71,80)` with no menu/input guard/runtime
  blocks. The clean route continued east through `(73,80)`, `(75,80)`, and
  `(77,80)`, where right and up blocked and south opened to `(77,81)`.
  From there, down blocked, east reached `(78,81)`, east/up blocked, and south
  carried to `(78,83)`. The route then bent east to `(79,83)`, south to
  `(79,84)`, east via `(81,84)` to `(82,84)`, with `(82,84)->RIGHT` blocked.
  South from `(82,84)` carried through `(82,86)` and `(82,88)`.
- Post-Demon-Knight continuation: after battle and user HEALs, fresh field
  baseline confirmed World Map `(82,89)` with no menu/input guard/runtime
  blocks. The clean route moved south to `(82,90)`, where south blocked and
  east reached `(83,90)`. From there, east blocked, south carried to
  `(83,92)`, south blocked, east reached `(84,92)`, and south carried through
  `(84,94)` to `(84,96)`. From `(84,96)`, south blocked, east carried to
  `(86,96)`, east blocked, south reached `(86,97)`, south blocked, east reached
  `(87,97)`, east blocked, and south carried through `(87,99)` to `(87,100)`.
  From `(87,100)`, south blocked and east carried to `(89,100)`, where east
  blocked and south continued through `(89,102)`, `(89,103)`, `(89,104)`, and
  `(89,105)`.
- Post-Knight-at-89106 continuation: after battle and user HEAL, fresh field
  baseline confirmed World Map `(89,106)` with no menu/input guard/runtime
  blocks. The clean route continued straight south through `(89,107)`,
  `(89,108)`, and `(89,109)`.
- Post-Knight-at-89110 continuation: after battle, user HEAL, and some
  transient FCEUX input-bridge chatter, a fresh baseline confirmed World Map
  `(89,110)` with menu closed, no dialogue/input guard, no runtime blocks, and
  only the known idle `LeftAlt` latch. Clean probes continued south through
  `(89,111)`, `(89,112)`, and `(89,113)`. From `(89,113)`, south and east
  blocked, while west opened to `(88,113)`.
- The clean trail then snaked southwest through the lower forest corridor:
  `(88,113)->DOWN` to `(88,114)`, south blocked, west to `(87,114)`, south to
  `(87,115)`, south blocked, west to `(86,115)`, south blocked, west to
  `(85,115)`, south to `(85,116)`, south blocked, west to `(84,116)`, south
  blocked, west to `(83,116)`, south blocked, west to `(82,116)`. At
  `(82,116)`, south and west blocked; north opened to `(82,115)`, then west
  continued through `(81,115)`, `(80,115)`, and `(79,115)`. At `(79,115)`,
  south and west blocked; north opened to `(79,114)`. The trail then went west
  to `(78,114)`, where west and south blocked; north opened to `(78,113)`,
  west continued through `(77,113)` and `(76,113)`, south at `(76,113)`
  blocked, west continued through `(75,113)` to `(74,113)`, then south opened
  through `(74,114)` to `(74,115)`.
- Current live interruption: moving down from `(74,114)` reached `(74,115)` and
  triggered a regular `Starwyvern` battle (`A Starwyvern draws near!`), not the
  Golem. Resume only after battle from a clean field baseline at/near
  `(74,115)`.
- Starwyvern death/reposition boundary: the user reported the hero lost the
  Starwyvern RNG battle, refreshed, teleported back, and walked around to clear
  taint. Treat the battle/death/teleport sequence as a hard contamination
  boundary, but the fresh post-teleport baseline is clean: after closing a
  leftover command menu, `report_position` confirmed World Map `(73,115)` with
  menu closed, no dialogue/input guard/runtime blocks, no active path, HP
  `85/92`, MP `85/85`, and only the known idle `LeftAlt` latch.
- Post-reposition continuation: clean same-origin probes found
  `(73,115)->DOWN` to `(73,116)`, where south and east blocked; west opened to
  `(72,116)`. The route then continued south/west through `(72,117)`,
  `(71,117)`, `(71,118)`, and west through `(70,118)` to `(69,118)`. South
  from `(72,117)` and south from `(71,118)` both blocked. Moving west from
  `(70,118)` reached `(69,118)` and triggered a regular `Werewolf` battle
  (`A Werewolf draws near!`), not the Golem. Resume only after battle from a
  clean field baseline at/near `(69,118)`.
- Post-Werewolf-at-69118 continuation: after battle, fresh baseline confirmed
  World Map `(69,118)`, menu closed, no dialogue/input guard/runtime blocks,
  no active path, HP `72/92`, MP `85/85`, and only the known idle `LeftAlt`
  latch. The clean route continued west through `(68,118)` and `(67,118)`,
  then south to `(67,119)`, west through `(66,119)`, `(65,119)`, `(64,119)`,
  and `(63,119)`. From there north opened to `(63,118)`, west continued through
  `(62,118)`, `(61,118)`, and `(60,118)`, and north opened to `(60,117)`.
  West from `(60,117)` carried to `(58,117)`; west from `(58,117)` carried to
  `(56,117)`. At `(56,117)`, HP was still `52/92`; west reached `(55,117)`,
  where west blocked and north carried to `(55,115)`. West from `(55,115)`
  carried through `(53,115)` to `(51,115)`, where west blocked and north
  carried to `(51,113)`. West from `(51,113)` reached `(50,113)` and triggered
  another regular `Werewolf` battle (`A Werewolf draws near!`), not the Golem.
  Resume only after battle from a clean field baseline at/near `(50,113)`.
- Post-Werewolf-at-50113 continuation: after battle, user HEALs, and manual
  movement, a fresh baseline confirmed World Map `(52,113)` with menu closed,
  no dialogue/input guard/runtime blocks, HP `81/92`, MP `69/85`, and only the
  known idle `LeftAlt` latch. Same-origin east probes then carried
  `(52,113)->RIGHT` to `(54,113)` and `(54,113)->RIGHT` to `(56,113)`. The
  latter move immediately triggered a regular `Starwyvern` battle (`A
  Starwyvern draws near!`), not the Golem. Resume only after battle from a
  clean field baseline at/near `(56,113)`.
- Post-Starwyvern-at-56113 continuation: after battle and user HEALs, fresh
  baseline confirmed World Map `(56,113)`, menu closed, no dialogue/input
  guard/runtime blocks, no active path, HP `91/92`, MP `57/85`, and only the
  known idle `LeftAlt` latch. The route continued east through `(58,113)`,
  `(60,113)`, `(62,113)`, `(64,113)`, `(65,113)`, and `(66,113)`, then north
  through `(66,112)`, `(66,111)`, `(66,110)`, carried to `(66,108)`, and
  reached `(66,107)`. From `(66,107)`, north and east blocked; west carried to
  `(64,107)`. From there north reached `(64,106)`, where north and east
  blocked; west carried to `(62,106)`. North reached `(62,105)`, where north
  blocked and east reached `(63,105)`. From `(63,105)`, east and north blocked;
  south reached `(63,106)` and triggered another regular `Starwyvern` battle
  (`A Starwyvern draws near!`), not the Golem. Resume only after battle from a
  clean field baseline at/near `(63,106)`.
- Post-Starwyvern-at-63106 continuation: after battle and user HEALs, fresh
  baseline confirmed World Map `(63,106)`, menu closed, no dialogue/input
  guard/runtime blocks, no active path, HP `84/92`, MP `45/85`, and only the
  known idle `LeftAlt` latch. Clean probes found `(63,106)->RIGHT` open to
  `(64,106)`, `(64,106)->DOWN` carrying to `(64,108)`, then east through
  `(66,108)` to `(67,108)`. From `(67,108)`, east and north blocked while
  south opened to `(67,109)`. The route then bent east/south/east through
  `(68,109)`, `(69,109)`, `(69,110)`, `(70,110)`, `(71,110)`, `(72,110)`,
  `(72,111)`, `(73,111)`, `(73,112)`, `(74,112)`, and `(74,113)`, with
  north/east blockers at the tested tips. Read-only `debug_pathfind_to:73,102`
  from `(74,113)` only produced compass fallback (`path_len=0`) because the
  overworld is not A*-decoded; `teleport_to:89,102` was refused by missing
  model walkability and should not be treated as live map proof.
- Post-heal continuation near Cantlin maze: from `(74,113)`, clean probes found
  a live loop back through `(73,113)`, `(73,112)`, `(72,112)`, `(72,111)`,
  `(71,111)`, and `(71,110)`, with north from `(71,110)` blocked. After the
  user took a healing break, fresh baseline confirmed World Map `(70,110)`,
  menu closed, no dialogue/input guard/runtime blocks, no active path,
  HP `91/92`, MP `33/85`, and only the known idle `LeftAlt` latch. From there,
  north blocked; west reached `(69,110)`, north reached `(69,109)`, west
  reached `(68,109)`, north blocked, west reached `(67,109)`, west carried to
  `(65,109)`, north carried to `(65,107)`, north blocked, west carried to
  `(63,107)`, north carried to `(63,105)`, and west carried to `(61,105)`.
  Immediately after reaching `(61,105)`, a regular `Starwyvern` battle started
  (`A Starwyvern draws near!`), not the Golem. A queued `probe_edge:UP` was
  refused during battle. The log later reported `Thou art dead.` Treat the
  death/refresh/reposition sequence as the next hard contamination boundary;
  resume only after a fresh field baseline.
- Post-death restore at `(61,105)`: the user restored from death and returned
  to the field at/near `(61,105)`. Fresh baseline confirmed World Map
  `(61,105)`, menu closed, no dialogue/input guard/runtime blocks, no active
  path, HP `87/92`, MP `85/85`, and only the known idle `LeftAlt` latch.
  Clean probes found `(61,105)->UP` blocked, `(61,105)->LEFT` carrying to
  `(59,105)`, `(59,105)->UP` open to `(59,104)`, and `(59,104)->UP` blocked.
  West from `(59,104)` reached `(58,104)` and immediately triggered another
  regular `Starwyvern` battle (`A Starwyvern draws near!`), not the Golem.
  Resume only after battle from a clean field baseline at/near `(58,104)`.
- Post-Starwyvern-at-58104 continuation: after battle and user HEALs, fresh
  baseline confirmed World Map `(58,104)`, menu closed, no dialogue/input
  guard/runtime blocks, no active path, HP `84/92`, MP `69/85`, and only the
  known idle `LeftAlt` latch. Clean probes found north blocked at `(58,104)`;
  west then carried through `(56,104)` and `(54,104)`. From `(54,104)`, north
  opened to `(54,103)` but north from there blocked, so the trail bent west
  through `(52,103)` to `(51,103)`, where north and west blocked. South from
  `(51,103)` carried to `(51,105)`, then west/north/west/north/west/north
  traced `(50,105)`, `(50,104)`, `(48,104)`, `(48,102)`, `(48,100)`,
  `(48,98)`, and `(48,97)`, with north at `(48,97)` blocked. East from
  `(48,97)` carried to `(50,97)`, and north from `(50,97)` reached `(50,96)`
  immediately before a regular `Werewolf` battle started (`A Werewolf draws
  near!`), not the Golem. Resume only after battle from a clean field baseline
  at/near `(50,96)`.
- Post-Werewolf-at-50096 continuation: after battle and user HEALs, fresh
  baseline confirmed World Map `(50,96)`, menu closed, no dialogue/input
  guard/runtime blocks, no active path, HP `84/92`, MP `57/85`, and only the
  known idle `LeftAlt` latch. Clean probes found north blocked at `(50,96)`,
  east carrying to `(52,96)`, north opening to `(52,95)`, north from there
  blocked, east carrying to `(54,95)`, and north carrying to `(54,93)`.
  Immediately after reaching `(54,93)`, a regular `Magiwyvern` battle started
  (`A Magiwyvern draws near!`), not the Golem. A queued follow-up
  `probe_edge:UP` was refused during battle; resume only after battle from a
  clean field baseline at/near `(54,93)`.
- Post-Magiwyvern-at-54093 continuation: after battle, user HEALs, and a brief
  FCEUX input-bridge recovery sequence, fresh baseline confirmed World Map
  `(54,93)`, menu closed, no dialogue/input guard/runtime blocks, no active
  path, HP `88/92`, MP `43/85`, and only the known idle `LeftAlt` latch.
  Clean probes found north blocked at `(54,93)`, east carrying to `(56,93)`,
  north opening to `(56,92)`, north from there blocked, east carrying to
  `(58,92)`, and north from `(58,92)` blocked. East from `(58,92)` reached
  `(59,92)` and immediately triggered a regular `Demon Knight` battle (`A
  Demon Knight draws near!`), not the Golem. Resume only after battle from a
  clean field baseline at/near `(59,92)`.
- Post-Demon-Knight-at-59092 continuation: after battle, user HEALs, and an
  interrupted probe recovery, fresh baseline confirmed World Map `(83,102)`
  with menu closed, no dialogue/input guard/runtime blocks, no active path, HP
  `85/92`, MP `39/85`, and only the known idle `LeftAlt` latch. Clean route
  evidence from `(59,92)` continued north to `(59,91)`, then east to
  `(61,91)`, north to `(61,89)`, east through `(63,89)`, `(65,89)`, and
  `(67,89)`, north to `(67,88)`, and a dead-end check at `(68,88)` where
  north/east/south blocked. Backtracking exposed the lower continuation:
  `(66,88)` south to `(66,90)`, east through `(68,90)` and `(69,90)`, south to
  `(69,91)`, east through `(71,91)`, `(72,91)`, and `(73,91)`, north to
  `(73,90)`, then east through `(74,90)`, `(75,90)`, `(76,90)`, and `(77,90)`.
  East blocked there, so the route bent south/east through `(77,92)`,
  `(79,92)`, `(79,91)`, back south to `(79,93)`, west to `(77,93)`, south to
  `(77,95)`, east through `(79,95)` and `(80,95)`, south to `(80,97)`, east to
  `(82,97)`, south to `(82,99)`, east to `(83,99)`, north/east dead-end checks
  through `(83,98)` and `(84,98)`, then back through `(82,98)`, south to
  `(82,100)`, south to `(82,102)`, and east to `(83,102)`. The interrupted
  `(83,102)->UP` probe later logged cleanly blocked; after closing the
  accidental command menu and re-baselining, `(83,102)->RIGHT` also blocked,
  while south carried to `(83,104)` and east from `(83,104)` reached
  `(84,104)`. That last move immediately triggered a regular `Wizard` battle
  (`A Wizard draws near!`), not the Golem. A fresh read-only baseline during
  the pause confirmed battle state at `(84,104)`, HP `74/92`, MP `39/85`,
  enemy HP `65`, and no runtime blocks. Resume only after battle from a clean
  field baseline at/near `(84,104)`.
- Post-Wizard-at-84104 continuation: after battle and user HEALs, fresh
  baseline confirmed World Map `(84,104)`, menu closed, no dialogue/input
  guard/runtime blocks, no active path, HP `83/92`, MP `23/85`, and only the
  known idle `LeftAlt` latch. Clean probes found `(84,104)->DOWN` and
  `(84,104)->RIGHT` blocked, while north opened to `(84,103)`. From
  `(84,103)`, north blocked and east opened to `(85,103)`, but `(85,103)` was
  a dead-end tip with east, south, and north all blocked. Backtracking west
  from `(85,103)` carried through `(84,103)` to `(83,103)`, then west carried
  cleanly through `(81,103)`, `(79,103)`, and `(77,103)`. West from
  `(77,103)` reached `(76,103)` and immediately triggered a regular
  `Starwyvern` battle (`A Starwyvern draws near!`), not the Golem. Resume only
  after battle from a clean field baseline at/near `(76,103)`.
- Quick-load contamination/config boundary: after the Starwyvern interruption,
  the user accidentally hit FCEUX quick load on `P` while recovering. Treat the
  resulting restored state as a hard contamination boundary until the user
  returns to position and a fresh field baseline is captured. Local FCEUX config
  `D:\emulation\fceux\bin\fceux.cfg` was backed up to
  `fceux.cfg.pre_unbind_savestate_20260704`, and the general
  `SDL.Hotkeys.LoadState` / `SDL.Hotkeys.SaveState` bindings were blanked.
  Slot-specific F-key savestate bindings remain unchanged.
- Post-quick-load continuation: after FCEUX restart/reposition, fresh baseline
  confirmed World Map `(78,103)`, menu initially open, no runtime blocks, HP
  `92/92`, MP `85/85`, and only idle `LeftAlt`; the command menu was closed
  and stale `Cantlin` auto-walk target cleared before probing. Treat this as a
  new clean route evidence segment after the quick-load contamination boundary.
  West from `(78,103)` carried to `(76,103)`, then continued west through
  `(74,103)`, `(72,103)`, `(70,103)`, `(68,103)`, `(66,103)`, `(64,103)`, and
  `(62,103)`. South from `(62,103)` opened and carried down the vertical lane
  through `(62,105)`, `(62,107)`, `(62,109)`, `(62,111)`, `(62,113)`,
  `(62,114)`, `(62,116)`, `(62,117)`, `(62,118)`, and finally `(62,119)`.
  The move into `(62,119)` triggered a regular `Starwyvern` battle (`A
  Starwyvern draws near!`), not the Golem. Resume only after battle from a
  clean field baseline at/near `(62,119)`.
- Post-Starwyvern-at-62119 continuation: after battle, fresh baseline confirmed
  World Map `(62,119)`, menu closed, no dialogue/input guard/runtime blocks,
  no active path, HP `91/92`, MP `73/85`, and only the known idle `LeftAlt`
  latch. South from `(62,119)` blocked at the map edge/bottom lane, while east
  opened and continued along row 119 through `(63,119)`, `(64,119)`,
  `(65,119)`, `(66,119)`, `(67,119)`, `(68,119)`, and `(69,119)`. East from
  `(69,119)` blocked, and north opened through `(69,118)`, `(69,117)`, and
  `(69,116)` to `(69,115)`. The move into `(69,115)` triggered another regular
  `Starwyvern` battle (`A Starwyvern draws near!`), not the Golem. Resume only
  after battle from a clean field baseline at/near `(69,115)`.
- Post-Starwyvern-death/reposition boundary: the hero lost the Starwyvern fight
  and the user restored, manually walked back, and healed. Treat the
  death/restore/manual-walk sequence as a hard contamination boundary. Fresh
  baseline confirmed World Map `(69,115)`, menu closed, no dialogue/input
  guard/runtime blocks, no active path, HP `92/92`, MP `69/85`, and only the
  known idle `LeftAlt` latch. Clean probes confirmed the north lane from
  `(69,115)` through `(69,114)`, `(69,113)`, `(69,112)`, `(69,111)`,
  `(69,110)`, and `(69,109)`. East and north from `(69,109)` both blocked.
  West then opened through `(68,109)` and `(67,109)`, with the next west hold
  carrying to `(65,109)`. North from `(65,109)` reached `(65,108)` and
  immediately triggered a regular `Wizard` battle (`A Wizard draws near!`),
  not the Golem. Resume only after battle from a clean field baseline at/near
  `(65,108)`.
- Post-Wizard-at-65108 continuation: after battle and user HEALs, fresh
  baseline confirmed World Map `(65,108)`, menu closed, no dialogue/input
  guard/runtime blocks, no active path, HP `80/92`, MP `55/85`, and only the
  known idle `LeftAlt` latch. North opened to `(65,107)`. East opened to
  `(66,107)`, but east and north from `(66,107)` both blocked, making that a
  short spur. West back to `(65,107)` moved cleanly and immediately triggered a
  regular `Starwyvern` battle (`A Starwyvern draws near!`), not the Golem.
  Resume only after battle from a clean field baseline at/near `(65,107)`.
- Post-Starwyvern-death-at-65107 restore: after the Starwyvern killed the hero,
  the user restored to `(65,108)`. Treat the death/restore as a hard evidence
  boundary. Fresh baseline confirmed World Map `(65,108)`, menu closed, no
  dialogue/input guard/runtime blocks, no active path, HP `80/92`, MP `55/85`,
  and only idle `LeftAlt`. Clean probes found north to `(65,107)`, north from
  `(65,107)` blocked, west carrying to `(63,107)`, north carrying to
  `(63,105)`, and then a regular `Green Dragon` battle, not the Golem. The
  queued `(63,105)->UP` probe was refused during battle and is not evidence.
  After the Green Dragon was defeated and HEALs were cast, fresh baseline at
  `(63,105)` was clean: HP `83/92`, MP `43/85`, no runtime blocks or active
  path. From there, north blocked, west carried to `(61,105)`, south carried to
  `(61,107)`, east carried back through `(63,107)`, and south/east traced a
  lower connector through `(63,109)`, `(65,109)`, `(65,110)`, `(66,110)`,
  `(67,110)`, `(68,110)`, `(69,110)`, `(70,110)`, `(71,110)`, and `(72,110)`.
  North and east from `(72,110)` blocked; the route curled through `(72,111)`,
  `(73,111)`, `(73,112)`, `(74,112)`, and `(74,113)`, with north/east blocks
  at the tested tips. East from `(74,113)` opened into a new lane:
  `(75,113)`, `(76,113)`, `(77,113)`, `(78,113)`, north to `(78,112)`, east
  to `(79,112)`, north to `(79,111)`, east to `(80,111)`, north to `(80,110)`,
  east to `(81,110)`, north to `(81,109)`, then east through `(82,109)`,
  `(83,109)`, `(84,109)`, `(85,109)`, north to `(85,108)`, east to `(86,108)`.
  A transient `dw_commands.txt` write hiccup occurred before the first
  `(86,108)->UP` attempt; it produced no consumed command and no map evidence.
  After a clean re-anchor at `(86,108)`, north opened to `(86,107)`, north from
  `(86,107)` blocked, and east reached `(87,107)` immediately before a regular
  `Werewolf` battle (`A Werewolf draws near!`), not the Golem. Resume only
  after battle from a clean field baseline at/near `(87,107)`.
- Post-Werewolf-death-at-87107 restore: after the Werewolf killed the hero, the
  user restored and relocated to `(87,107)`. Treat the death/restore/relocation
  as a hard evidence boundary. Fresh baseline confirmed World Map `(87,107)`,
  menu closed, no dialogue/input guard/runtime blocks, no active path,
  HP `92/92`, MP `85/85`, and only idle `LeftAlt`. Clean probes found north to
  `(87,106)`, north to `(87,105)`, north carrying to `(87,103)`, north carrying
  to `(87,101)`, west carrying to `(85,101)`, then west to `(84,101)`. The move
  into `(84,101)` immediately triggered a regular `Wizard` battle (`A Wizard
  draws near!`), not the Golem. Resume only after battle from a clean field
  baseline at/near `(84,101)`.
- Post-Wizard-at-84101 continuation: after battle and user HEALs, fresh field
  baseline confirmed World Map `(84,101)`, menu closed, no dialogue/input
  guard/runtime blocks, no active path, HP `92/92`, MP `75/85`, and only idle
  `LeftAlt`. Clean west probes found `(84,101)->LEFT` carrying to `(82,101)`,
  then `(82,101)->LEFT` carrying to `(80,101)`. The next west step moved into
  `(79,101)` and immediately triggered a regular `Green Dragon` battle (`A
  Green Dragon draws near!`), not the Golem. Resume only after battle from a
  clean field baseline at/near `(79,101)`.
- Cantlin entry completion: after the Green Dragon, fresh baseline confirmed
  World Map `(79,101)`, menu closed, no dialogue/input guard/runtime blocks,
  no active path, HP `82/92`, MP `63/85`, and only idle `LeftAlt`. West from
  `(79,101)` reached `(77,101)` and a regular `Werewolf` encounter fired a few
  frames after the probe result; the log then showed `RUN` and returned to
  field. Because there was no post-battle baseline before the next movement,
  treat that Werewolf/run sequence as a battle boundary, not clean route-state
  evidence. Subsequent west movement reached `(75,101)`, and west into
  `(74,101)` triggered another regular `Werewolf` encounter, again not the
  Golem; the log again returned to field after `RUN`. A clean read-only
  re-baseline at `(74,101)` then confirmed menu closed, no input guard/runtime
  blocks, no active path, HP `84/92`, MP `63/85`. From that clean baseline:
  `(74,101)->LEFT` carried through `(73,101)` to `(72,101)`;
  `(72,101)->DOWN` carried through `(72,102)` to `(72,103)`;
  `(72,103)->RIGHT` carried through `(73,103)` to `(74,103)`.
  `simulate_raw_input:LEFT,12` corrected precisely back to `(73,103)`.
  Two short `UP,12` nudges from `(73,103)` did not move, but same-origin
  `probe_edge:UP` from `(73,103)` produced `map change -> 0x0A (Cantlin)`,
  landing at in-town `(15,0)`. No Golem encounter fired during this approach;
  either the Golem is already cleared in the current save/state, is at a
  different approach square, or the guide's forced encounter condition was not
  active for this run. Final confirmed state: Cantlin `(15,0)`, menu closed,
  no input guard/runtime blocks, no active path.

## 2026-06-29 Kol Speech/Menu Regression Follow-Up

- User manual pass from the Kol entrance confirmed command-menu open/close,
  SPELL menu entry, and ITEM menu browsing no longer speak stale `Bill` / `ll`
  fragments or bogus merchant prices.
- Follow-up Kol service pass confirmed the Weapons Merchant buy flow and Tool
  Merchant buy screen read correctly. The Tool Merchant sell list exposed a
  lower-row regression: after the cursor reached `Gwaelin's Love` / `Torch`,
  `speech_bridge.log` repeatedly spoke the full merchant summary (`Merchant.
  Gold 22041. Offered: ...`) between item names.
- Source fix in `main.lua`: after a merchant offer selection is already known,
  changed cursor selections still speak, but the fallback full-offer summary is
  suppressed on cursor-blink/split-row redraw frames. Verification passed with
  `luac -p main.lua test_sweep_walk_command_surface.lua merchant.lua
  test_merchant.lua`, `lua test_sweep_walk_command_surface.lua`, `lua
  test_merchant.lua`, and `git diff --check`. POST-RELOAD LIVE VERIFIED:
  fresh `speech_bridge.log` session at `2026-06-29 20:01:20` read the sell
  list as `Herb. 6 gold`, then item names only (`Fairy Flute`, `Dragon's
  Scale`, `Wings`, `Stones of Sunlight`, `Staff of Rain`, `Cursed Belt`,
  `Gwaelin's Love`, `Torch`) without repeated full merchant summaries. The
  game only rendered the Herb sell-list price; later confirmation dialogue read
  `Cursed Belt` as 180 GOLD.
- Two follow-up speech issues were captured from `speech_bridge.log`: field
  spell casts only spoke MP deltas (`Used 4 MP. MP 60`, `Used 3 MP. MP 57`)
  with no result dialogue, and ITEM menu entry spoke the first item twice
  (`Items. Dragon's Scale` followed by `Dragon's Scale`).
- Source fix in `main.lua`: ITEM entry now remembers the item name already
  spoken on submenu entry and suppresses the delayed first cursor update only
  when it matches that name; different immediate cursor movement still speaks.
- Source fix in `main.lua`: STATUS and ITEM lower-window rows remain absorbed
  as memory-spoken submenu UI, but SPELL only absorbs uppercase/no-lowercase
  spell-list rows. Lowercase field spell-result dialogue can now stabilize and
  speak even if it appears before `submenu_mode` clears.
- Verification: `luac -p main.lua test_sweep_walk_command_surface.lua`,
  `lua test_sweep_walk_command_surface.lua`, `lua test_items.lua`,
  `lua test_text.lua`, `lua test_menu.lua`, `lua test_merchant.lua`,
  `lua test_hotkeys.lua`, and `git diff --check` passed.
- POST-RELOAD LIVE VERIFIED: fresh `speech_bridge.log` session at
  `2026-06-29 19:38:55` showed RADIANT cast speech as `Used 3 MP. MP 54`,
  then `Bill chanted the spell of RADIANT.`, then `But nothing happened.` The
  ITEM retest spoke `Items. Dragon's Scale` and then the next movement spoke
  `Fairy Flute`, with no immediate duplicate `Dragon's Scale`.

## 2026-06-29 Kol West Side Door Route Cleanup

### PROMOTED THIS PASS

- Live baseline: map `0x07` / Kol. `report_door_state` showed only the
  western-building door `(7,12)` open; the West Side Door `(1,14)` remained
  closed. Runtime blockers were initially clear.
- The entrance-to-door-stand route originally stalled at `(3,18)->LEFT` into
  `(2,18)`. Same-origin `probe_edge:LEFT` from `(3,18)` raw-hold timed out
  with no NPC and no existing approach block, so `(2,18).east` was promoted.
- Frontier analysis then found the real lower connector: from `(3,17)`,
  `probe_edge:LEFT` entered decoded type-0 `(2,17)` and carried through to
  the already modeled `(1,17)` throat. `map_reader.lua` now models `(2,17)`
  as a Kol passthrough.
- Follow-up route/probe work proved the apparent door-side lane is sealed:
  `(2,15).west`, `(2,16).west`, `(2,16).south`, and `(2,18).west` all blocked
  from same-origin live probes. The upper bridge candidates into decoded
  type-0 `(4,14)` also blocked from `(4,15)->UP` and `(5,14)->LEFT`, so
  `(4,14).south` and `(4,14).east` are modeled as closed approaches.

### LIVE STATUS / NEXT

- Follow-up manual movement proved the route target was wrong, not unreachable:
  the user reached `(1,15)`, pressed north, and the next `report_door_state`
  showed keys `0` with opened-door slot `1=(1,14)`. `objects.lua` now models
  the West Side Door public stand as `(1,15)` facing north.
- Opened-door return route to the Kol exit is now validated. From the
  West-Side-Door area, route retries plus same-origin `probe_edge` checks
  confirmed `(2,10).south`, `(3,10).south`, `(4,11).west`, `(4,12).west`,
  `(4,13).west`, `(2,14).north/west`, and `(3,14).north`. After injecting that
  runtime overlay, `auto_walk_blocker:19,23` reached `(19,23)` and faced south.
- User validation pass then exercised all current Kol door/service routes both
  directions: `West Side Door`, `Western Building Door`, `Tool Merchant`,
  `Weapons Merchant`, and `Inn`, each with a clean return to `Exit to World Map`
  at `(19,23)`. Follow-up log scan found only route-complete markers for the
  validation sequence and no blocker/no-path/interrupt lines.

## 2026-06-29 Kol Closed-Door Tool Merchant Cleanup

### PROMOTED THIS PASS

- Live baseline: map `0x07` / Kol, player at the north-west building lip,
  `report_door_state` showed keys `2` and all opened-door slots `(0,0)`, so
  both known Kol magic-key doors were closed.
- The closed-door route to Tool Merchant stand `(12,21)` repeatedly tried
  false cuts around the western building instead of collapsing at the locked
  boundary. Runtime blockers added and promoted:
  `(7,10).east`, `(7,9).east`, `(7,8).east`, `(6,8).north`,
  `(7,8).north`, `(5,7).east`, `(5,6).east`, `(5,5).east`,
  `(6,4).south`, `(7,4).south`, and `(8,4).south`.
- Most entries were confirmed by route/seam-retry plus same-origin
  `probe_edge`; `(7,8).north` had route evidence only but matches the same
  closed lip and was needed for the no-path collapse.
- With the first five runtime edges active, `auto_walk_blocker:12,21`
  reported `AUTO_WALK: no path` with no opened-door RAM. The follow-up frontier
  still listed row-7 hidden-bridge candidates, so the pass continued by probing
  their reachable approaches and exposed the x=5 east lip / north cap above.

### LIVE STATUS / NEXT

- Current live runtime overlay has ten destination entries:
  `6,4(south)`, `7,4(south)`, `8,4(south)`, `5,5(east)`,
  `5,6(east)`, `5,7(east)`, `6,8(north)`, `7,8(east,north)`,
  `7,9(east)`, and `7,10(east)`.
- FCEUX still needs a manual `main.lua` reload before the permanent source
  blockers affect live pathfinding. After reload, rerun the closed-door
  `auto_walk_blocker:12,21` and `debug_route_frontier_skip_npcs:12,21,80`
  from a clean Kol entrance or the current north-west lip.

## 2026-06-26 Rimuldar Inn / Wings Door Route Cleanup

### PROMOTED THIS PASS

- Live route cleanup started from the user-reported blocker `(29,16)->WEST`.
  Source already modeled that as the row-16 transition guard, so no new
  permanent change was needed for `(29,16).west`.
- Promoted the hidden passthrough `(18,18)`: same-origin `probe_edge:DOWN`
  from `(18,17)` moved through decoded wall tile `(18,18)` and settled at
  `(18,19)`, then later live routing traversed `(18,19)->(18,18)->(18,17)`
  while returning to the entrance.
- Promoted route/probe-confirmed Rimuldar directional blockers:
  `(19,17).west`, `(25,17).east`, `(19,22).west`, `(18,21).south`,
  `(19,23).west`, `(22,20).north`, `(24,21).north`, `(25,20).west`,
  `(25,19).west`, `(23,17).south`, `(22,22).west`, and `(28,16).east`.
- Added explicit interaction points for `Rimuldar Inn Outer Door`:
  public side `(21,20)` facing south, plus the previously proven inside stand
  `(21,22)` facing north. The public side is the primary stand so route-to-door
  from the entrance no longer chooses the unreachable inside stand.
- Added explicit interaction points for `Wings Chest Door`: approach side
  `(21,23)` facing east is now primary, with the previously pinned chest-side
  stand `(23,23)` facing west preserved as an alternate.
- Focused checks passed after the updates:
  `luac -p map_reader.lua objects.lua test_map_reader.lua test_objects.lua`,
  `lua test_map_reader.lua`, `lua test_objects.lua`, and `git diff --check`.

### LIVE STATUS / NEXT

- With the current runtime overlay active, route from the entrance `(29,13)`
  to the public outer-door stand `(21,20)` completed cleanly, and later route
  from `(21,22)` to the inner-door approach stand `(21,23)` completed after a
  timing retry that resolved as passable.
- Door RAM was closed (`slots all (0,0)`) before debug seeding; after real
  manual opens, `report_door_state` showed keys `2` and slots
  `0=(21,21) 1=(22,23)`.
- `debug_seed_open_doors:21,21` was used only for planner inspection, not real
  gameplay. With the outer door seeded, planner paths from `(21,20)` exist to
  `(21,22)`, `(23,23)`, and chest `(24,23)`.
- Real post-door validation is now clean:
  `(21,23)->(24,23)` reached `chest_7` through opened door `(22,23)`, return
  route from chest `(24,23)` to town exit `(29,13)` reached the exit, and full
  town-exit-to-chest route reached `(24,23)`. A later polish pass found the
  remaining row-16 false cut: `(29,16)->LEFT` into `(28,16)` blocked during
  autowalk and same-origin `probe_edge:LEFT`, so `(28,16).east` is promoted.

## 2026-06-27 Rimuldar Weapons Merchant Route Polish

### PROMOTED THIS PASS

- SUPERSEDED: the earlier `(27,8).east` blocker was wrong. After a FCEUX Lua
  reload, the user manually crossed `(28,8)->LEFT` into `(27,8)` and reported
  `(27,8)->RIGHT` also open. A fresh same-origin probe from `(27,8)->RIGHT`
  moved through `(28,8)` and carried to `(29,8)`. Since crossing from
  `(28,8)` into `(27,8)` immediately restores the Weapons Merchant path,
  `map_reader.lua` now keeps `(27,8).east` open.
- Follow-up route hit `(27,5)->LEFT` into `(26,5)`; same-origin
  `probe_edge:LEFT` timed out from `(27,5)`. Promoted `(26,5).east`.
- Follow-up route hit `(24,3)->DOWN` into `(24,4)`; same-origin
  `probe_edge:DOWN` timed out from `(24,3)`. Promoted `(24,4).north`.
- After those three closures, the public stand `(24,7)` became a separate
  target-side component. Frontier analysis listed four hidden bridge
  candidates; same-origin probes from normally reached `(25,3)->DOWN`,
  `(26,3)->DOWN`, and `(28,7)->LEFT` all timed out. The remaining
  `(22,3)->DOWN` candidate was checked from a teleport-seeded forensic origin:
  it moved into hidden `(22,4)`, then `(22,4)->DOWN` moved to `(22,5)`.
  From `(22,5)`, live-NPC pathing reaches the Weapons Merchant stand via
  `2 east, 2 south` without crossing the occupied merchant cell. Promoted
  `(22,4)` as the likely missing passthrough; revalidate entrance/return
  routes after script reload because the bridge proof started from teleport.
- Post-reload validation from `(19,3)` found the next false shortcut:
  autowalk to `Weapons Merchant` tried `(19,3)->RIGHT` into `(20,3)`, seam
  retries blocked twice, and same-origin `probe_edge:RIGHT` from `(19,3)`
  timed out. Promoted `(20,3).west` and injected
  `add_blocked_edge:19,3,RIGHT` at runtime. With this closed, frontier search
  shows the next candidate bridge is likely around `(24,3)->LEFT` into
  hidden `(23,3)` or `(22,1)->DOWN` into hidden `(22,2)`.
- Attempting to walk the long lower route to `(24,3)` exposed and verified
  four more lower-loop false exits: `(10,7)->UP` into `(10,6)`,
  `(12,8)->DOWN` into `(12,9)`, `(12,8)->RIGHT` into `(13,8)`, and
  `(15,6)->RIGHT` into `(16,6)`. Each blocked during route/seam retry and
  also timed out from a same-origin probe, so `(10,6).south`,
  `(12,9).north`, `(13,8).west`, and `(16,6).west` are promoted.
  The route later suspected `(8,9)->RIGHT` into `(9,9)`, but that edge was
  not same-origin probed in this pass and remains unpromoted.
- Later target-side forensic routing exposed the actual weapon-shop throat:
  from the stand `(24,7)`, `debug_pathfind_to:29,13` planned
  `1 south, 5 east, 5 south`; live probes moved `(24,7)->DOWN` through
  `(24,8)` to `(24,9)` and then `(24,9)->UP` back through `(24,8)` to the
  stand. This supersedes the older `(24,8).south` blocker, which was removed
  so the entrance can route through the real counter aisle. A manual FCEUX Lua
  reload is required before live route validation.

## 2026-06-24 Brecconary Fairy Water Route / Input Lock Capture

### CLOSEOUT

- User verified routes to and from the Fairy Water merchant are clean.
- Brecconary Magic Key revisit is complete for the current alpha-prep pass.
- Remaining caveat is source reload only: FCEUX must reload `main.lua` before
  the fixed Fairy Water target hold and exit-tile pathability behavior are live
  in the emulator script.

### CLEAN / PROMOTED

- Map `0x08` Fairy Water route pocket evidence was fresh route/manual evidence,
  not old broad survey noise. The route repeatedly tried to enter the NE shop
  counter cells from the public west-side aisle:
  `(21,3)->LEFT` into `(20,3).east`, `(21,5)->LEFT` into `(20,5).east`,
  `(21,3)->UP` into `(21,2).south`, `(22,3)->UP` into `(22,2).south`,
  and `(22,3/4/5)->RIGHT` into `(23,3/4/5).west`.
- Promoted those approach blockers in `map_reader.lua`.
- `Fairy Water Merchant` is a moving Woman sprite behind the NE counter.
  `objects.lua` now labels live rows `(24,3)`, `(24,4)`, and `(24,5)` and
  routes each to the fixed public counter stand `(22,4)` facing east.
- Live prompt evidence at frame `02209` proved the trigger when the player was
  at `(22,4)` facing east and the target NPC was held at `(24,4)`.
- Later failed access after returning was explained by the same-row route model:
  the route targeted `(22,3)` when the merchant was on `(24,3)` and held the
  target at `(24,3)`, then TALK reported `There is no one there.` Controlled
  raw/TALK probes from `(22,3)`, `(22,4)`, `(22,5)`, and `(25,4)` did not open
  the prompt when the target was not held on `(24,4)`.
- Focused tests now cover the Fairy Water directional blockers and all three
  moving-row service records, the fixed counter stand, and explicit target
  hold coordinates.

### EARLIER INPUT LOCK CAPTURE

- During Fairy Water TALK testing, the emulator entered a funky state where
  Lua command polling stayed alive and `joy1=A` was visible for controlled
  12-frame `simulate_sequence:A` presses, but the game never opened the field
  command menu.
- Captured state showed no active command menu, submenu, dialogue, merchant
  screen, route, runtime blocks, or script error. `dw_script_error.log` had no
  fresh entry.
- `report_movement_state` showed `buttons=0x00` after failed `A` presses.
  Movement bytes around `0x003C/0x003D` varied during the bad state, but
  `reset_movement_state:funky_input_fix` did not restore `A` menu behavior.
- `recover_fceux_input.sh` briefly produced a clean `left_alt=false` marker,
  but FCEUX rel latched `LeftAlt`; controlled `A` still did not open the menu.
- `freeze_npcs` was released with `unfreeze_npcs`; the issue persisted.
- Added read-only diagnostic command `report_input_guard_state`, but FCEUX must
  manually reload `main.lua` before that command exists in the live script.
- Current merchant access failure is explained by the fixed-row trigger above;
  return to this input-lock thread only if `(22,4)` facing east with the target
  held at `(24,4)` still fails after reload.

### RESOLVED NEXT CHECK

- If Brecconary is revisited after reload, only spot-check the Fairy Water
  route and the `(0,15)` reachable-filter boundary behavior. Do not reopen
  broad blocker hunting unless a new gameplay route failure appears.

## 2026-06-22 Swamp Cave Door / Princess Route

### CLEAN / CURRENT LIVE STATE

- Started from Swamp Cave `0x15` at `(2,17)` after script liveness was
  confirmed with `launcher_probe:codex_swamp_start`.
- Runtime blockers were clear: `RUNTIME_BLOCKS map=0x15 none`.
- Current object was `Gwaelin Door`, door cell `(5,20)`, interaction stand
  `(5,21)` facing north.
- `debug_pathfind_to:5,21` planned `Path: 4 south, 3 east`.
- `auto_walk` reached the door stand `(5,21)` and faced north. The only route
  hiccup was `(2,20)->DOWN` timing retry, which immediately moved on seam
  retry and cleared itself. Do not promote that as a blocker.
- `OPEN` was executed through the command menu. `report_door_state` confirmed
  keys dropped to `5` and opened-door slot `0=(5,20)`.
- After the door opened, `debug_pathfind_to:4,14` planned `Path: 7 north,
  1 west`, proving the opened-door branch routes toward the logged Green
  Dragon / Princess area.
- The route through the opened door moved cleanly from `(5,21)` to `(5,20)`
  and `(5,19)`.

### RESOLVED / LIVE FINDINGS

- After the user defeated the random Scorpion and later the Green Dragon,
  field control resumed cleanly in Swamp Cave. Fresh state showed opened-door
  slot `0=(5,20)`, keys `5`, and no runtime blocks.
- The Green Dragon remains a fixed event encounter at `(4,14)`; after it is
  defeated, `(4,14)->DOWN` to `(4,15)` is passable again.
- Realm of Darkness' map clarified that Gwaelin is by the door-side room, not
  at the northern dragon pocket. The successful rescue route ended at
  `(5,19)`, the first tile north of the opened door cell `(5,20)`.
- From `(5,19)`, raw face north and `TALK` reaches Princess Gwaelin at
  `(5,18)`. Dialogue confirmed:
  `Thou art brave indeed to rescue me, Bill.`, then
  `I am Gwaelin, daughter of Lorik.`, then
  `Will thou take me to the castle?`
- Accepted the YES prompt. Follow-up dialogue included
  `Princess Gwaelin embraces thee.` and `I'm so happy!`; final state returned
  to field at `(5,19)` with `combat=0x09` and `quest=0x40`.
- Runtime blockers were clear after rescue. Several route-only blocked seams
  were observed while chasing the wrong northern pocket and returning to
  `(5,19)`; keep them as scratch evidence until same-origin verification is
  needed for a future route patch.

### 2026-06-22 Restored Route Blocker Cleanup

- User restored from the pre-rescue state and manually reloaded with the
  Princess special object live. Baseline at `map=0x15`, `(4,15)`, had
  `combat=0x08`, door slots empty, runtime blocks clear, and current object
  `Princess Gwaelin` with talk stand `(5,19)`.
- Direct planner route from `(4,15)` to Princess stand `(5,19)` initially
  tried `4 south, 1 east`, but walked autowalk proved the direct lower-right
  pocket is blocked until the door branch is used. Random encounters interrupted
  twice; combat cleared normally and field control resumed without script
  reload.
- Runtime-only blockers injected from walked route evidence:
  `add_blocked_edge:4,15,DOWN`,
  `add_blocked_edge:3,15,DOWN`,
  `add_blocked_edge:2,16,RIGHT`,
  `add_blocked_edge:2,17,RIGHT`,
  `add_blocked_edge:2,18,RIGHT`,
  `add_blocked_edge:2,19,RIGHT`,
  `add_blocked_edge:2,20,RIGHT`,
  `add_blocked_edge:3,21,UP`,
  `add_blocked_edge:4,21,UP`,
  `add_blocked_edge:5,15,DOWN`.
  `list_blocked_tiles` collapsed these to eight effective runtime cells:
  `(3,16)` dirs north/west, `(4,16)` north, `(5,16)` north, `(3,17)` west,
  `(3,18)` west, `(3,19)` west, `(3,20)` south/west, `(4,20)` south.
- With those runtime blockers active and the door still closed,
  `debug_pathfind_to:5,19` correctly returned `No path found`, while
  `debug_pathfind_to:5,21` planned `Path: 2 south, 3 east` from `(2,19)` to
  the Gwaelin Door stand.
- After the user manually opened the door, `DOOR_STATE keys=5 slots=0=(5,20)`
  at `(5,21)`. From there, `auto_walk:5,19` planned and walked `Path: 2 north`
  through opened door cell `(5,20)` to the Princess talk stand `(5,19)`.
  Final object readout: `Princess Gwaelin: 1 north, talk here`.
- Promotion status: keep these as runtime/live-evidence blockers for now.
  Permanent `map_reader.lua` promotion should be test-first and scoped to map
  `0x15`, with regression coverage that the closed-door side cannot route to
  `(5,19)` through the false lower pocket while the opened-door path
  `(5,21)->(5,20)->(5,19)` stays available when the door is open.

### 2026-06-22 South-Stairs Route Polish

- With the pre-rescue save restored, the Gwaelin door manually opened, and the
  Princess object still present at `(5,18)`, targeted `auto_walk_blocker:0,29`
  was used instead of a broad sweep.
- Baseline before the polish pass: `map=0x15`, field state, selected object
  `South Stairs Up` at `(0,29)`, and the restored-route runtime blockers from
  the Princess route cleanup active.
- Clean `AUTO_WALK_BLOCKER_FOUND` edges added as runtime blockers while
  pruning false routes toward `South Stairs Up`:
  `add_blocked_edge:4,21,DOWN`,
  `add_blocked_edge:3,21,DOWN`,
  `add_blocked_edge:2,21,DOWN`,
  `add_blocked_edge:2,21,LEFT`,
  `add_blocked_edge:5,21,DOWN`,
  `add_blocked_edge:2,20,LEFT`,
  `add_blocked_edge:2,19,LEFT`,
  `add_blocked_edge:2,18,LEFT`,
  `add_blocked_edge:2,17,LEFT`,
  `add_blocked_edge:2,16,LEFT`,
  `add_blocked_edge:2,15,LEFT`,
  `add_blocked_edge:2,15,UP`,
  `add_blocked_edge:3,15,UP`,
  `add_blocked_edge:4,14,LEFT`,
  `add_blocked_edge:2,13,LEFT`,
  `add_blocked_edge:3,13,DOWN`,
  `add_blocked_edge:2,12,LEFT`,
  `add_blocked_edge:2,11,LEFT`,
  `add_blocked_edge:2,10,LEFT`,
  `add_blocked_edge:2,9,LEFT`,
  `add_blocked_edge:1,8,DOWN`,
  `add_blocked_edge:1,25,RIGHT`.
- Contaminated/no-promote note: one `(3,21)->LEFT` retry was interrupted by a
  Ghost battle and was discarded. A later clean rerun moved through
  `(3,21)->(2,21)`, proving that edge passable.
- Clean route result: after the blockers above were active,
  `auto_walk_blocker:0,29` walked from `(1,25)` through `(1,26)`,
  `(2,26)`, `(3,26)`, `(3,27)`, `(3,28)`, `(3,29)`, `(2,29)`, `(1,29)` to
  `(0,29)`. Final readout: `OBJECT: South Stairs Up: here`, runtime block
  count `27`.
- Reverse-route polish from `(0,29)` back to Gwaelin door stand `(5,21)`
  found additional clean blockers:
  `add_blocked_edge:3,29,RIGHT`,
  `add_blocked_edge:3,26,RIGHT`,
  `add_blocked_edge:5,24,LEFT`, and
  `add_blocked_edge:3,25,LEFT`.
  The old mixed `(5,24)->LEFT` evidence is now clean enough to promote. A
  Scorpion interrupted one `(3,26)->UP` timing retry, so that edge was not
  promoted. After the reverse blockers were active, `auto_walk_blocker:5,21`
  reached `(5,21)` cleanly. That successful route also walked the standable
  middle strip `(2,16)`, `(2,17)`, and `(2,18)`, which should be modeled as
  passthroughs rather than blocked decode cells.
- Forward route after returning to the door stand stayed available when the
  Gwaelin door was open: live `debug_pathfind_to:0,29` from `(5,21)` planned
  `Path: 2 north, 1 west, 11 north, 4 west, 16 south, 3 east, 5 south, 3 west`.
- Promotion complete for the south-stairs / door-stand batch in
  `MAP_DIRECTIONAL_BLOCKS[0x15]` with focused regression assertions. Preserve
  the proven passable route to `(0,29)` and do not model untested neighboring
  faces.

## 2026-06-23 Swamp Cave North Exit Return Polish

- Started from the opened-door / Gwaelin branch side on map `0x15`, working the
  return route toward `North Exit to World Map` at `(0,0)`.
- Direct `probe_edge` checks confirmed these blocked approaches before
  promotion: `(4,17)->UP` into `(4,16).south`, `(5,17)->UP` into
  `(5,16).south`, `(4,17)->LEFT` into `(3,17).east`, `(4,18)->LEFT` into
  `(3,18).east`, `(4,19)->LEFT` into `(3,19).east`, `(4,19)->DOWN` into
  `(4,20).north`, `(5,20)->LEFT` into `(4,20).east`, `(4,13)->UP` into
  `(4,12).south`, and `(2,8)->UP` into `(2,7).south`.
- With the runtime overlay applied, `auto_walk_blocker:0,0` routed around the
  false shortcuts, crossed west at row 21, climbed through `(2,13)..(2,8)`,
  moved into the x=0 corridor at `(0,8)`, and reached `(0,0)`.
- Two Scorpion battles interrupted route execution; both cleared and were not
  treated as blocker evidence.
- Promoted the confirmed approach-only blockers into `map_reader.lua` and added
  focused `test_map_reader.lua` assertions. `lua test_map_reader.lua`,
  `lua test_pathfinder.lua`, and `git diff --check` pass.

## 2026-06-23 Swamp Cave Princess-to-South-Stairs Polish

- Manual route from the Princess side toward `South Stairs Up` reached
  `(0,24)`, where planner output wanted `(0,24)->RIGHT`.
- Same-origin `probe_edge:RIGHT` from `(0,24)` confirmed the open-preview seam
  blocked into `(1,24).west`. With runtime `add_blocked_edge:0,24,RIGHT`,
  `auto_walk_blocker:0,29` rerouted through `(0,25)`, `(1,25)`, `(1,26)`,
  `(2,26)`, `(3,26)`, `(3,29)`, and reached `(0,29)`.
- Promoted `(1,24).west` into `map_reader.lua` with a focused
  `test_map_reader.lua` assertion. No new combat interruption occurred during
  this route continuation.

## 2026-06-23 Swamp Cave South-Stairs-to-Princess Return Polish

- Working back toward Princess Gwaelin from the south-stairs/x=0 return side,
  manual walking reached `(2,12)`. Planner output wanted `(2,12)->RIGHT`
  toward the Princess stand `(5,19)`, but close-timed manual route readouts
  created early-twitch cancels rather than clean movement proof.
- Fresh baseline confirmed `POSITION: map=0x15(Swamp Cave) x=2 y=12`.
  Same-origin `probe_edge:RIGHT` from `(2,12)` reported `status=blocked`,
  `dest=(3,12)`, `reason=raw_hold_timeout`, with no permanent directional
  block, runtime block, or NPC block involved.
- Runtime `add_blocked_edge:2,12,RIGHT` added `(3,12).west`. With that single
  runtime block, `auto_walk_blocker:5,19` walked through `(2,13)`, `(4,13)`,
  `(4,15)`, `(2,15)..(2,21)`, `(5,21)`, opened door cell `(5,20)`, and reached
  the Princess talk stand `(5,19)`. Timing retries at `(3,13)->RIGHT`,
  `(4,14)->DOWN`, `(3,15)->LEFT`, `(2,20)->DOWN`, and `(4,21)->RIGHT` all
  subsequently moved and were not promoted.
- Promoted `(3,12).west` into `map_reader.lua` with a focused
  `test_map_reader.lua` assertion and a route guard that the post-battle door
  route does not retry `(2,12)->RIGHT`.
- Follow-up north-exit route work reached `(3,13)` and exposed `(3,13)->UP`.
  Same-origin `probe_edge:UP` reported `status=blocked`, `dest=(3,12)`,
  `reason=raw_hold_timeout`, with no NPC or approach-specific blocker active.
  Runtime `add_blocked_edge:3,13,UP` merged `(3,12).south` with the existing
  `(3,12).west` overlay, and `auto_walk_blocker:0,0` then reached the north
  exit `(0,0)`. Timing retries at `(3,13)->LEFT`, `(2,9)->UP`, and
  `(1,8)->LEFT` all subsequently moved and were not promoted.
  Promoted `(3,12).south` into `map_reader.lua` with a focused assertion and a
  route guard that the door-to-north route does not retry `(3,13)->UP`.
- Follow-up top-corridor return-to-Princess work from `(0,2)` exposed
  `(0,2)->RIGHT`. Same-origin `probe_edge:RIGHT` reported `status=blocked`,
  `dest=(1,2)`, `reason=raw_hold_timeout`, with no permanent/runtime/NPC
  blocker active. Runtime `add_blocked_edge:0,2,RIGHT` added `(1,2).west`.
  `auto_walk_blocker:5,19` then found `(0,7)->RIGHT`; same-origin
  `probe_edge:RIGHT` from `(0,7)` likewise blocked into `(1,7).west`.
  With both runtime blockers active, the route used `(0,8)->RIGHT` as the
  first open re-entry and reached the Princess stand `(5,19)`. A Scorpion
  battle interrupted once at `(2,16)`, then cleared; timing retries around
  `(0,6)->DOWN`, `(1,8)->RIGHT`, `(2,12)->DOWN`, `(3,13)->RIGHT`,
  `(4,14)->DOWN`, `(3,15)->LEFT`, `(2,16)->DOWN`, `(2,20)->DOWN`, and
  `(4,21)->RIGHT` all moved on retry and were not promoted.
  Promoted `(1,2).west` and `(1,7).west` with assertions and a
  north-exit-to-Princess route guard.
- Follow-up top-corridor return-to-Princess work from `(0,5)` exposed a tight
  three-sided pocket around `(1,6)`. Same-origin probes confirmed
  `(0,5)->RIGHT` into `(1,5).west`, `(1,6)->RIGHT` into `(2,6).west`,
  `(1,6)->DOWN` into `(1,7).north`, and `(1,6)->UP` into `(1,5).south` as
  blocked-despite-open-preview seams with no NPC or approach-runtime blocker
  contamination. With all four runtime blockers active, `auto_walk_blocker:5,19`
  escaped through `(0,8)->RIGHT`, climbed/descended the known `(2,8)..(2,21)`
  route, and reached `(5,19)` after one Druin battle interrupted at `(5,21)`
  and cleared. Timing retries at `(2,12)->DOWN`, `(3,13)->RIGHT`,
  `(4,14)->DOWN`, `(3,15)->LEFT`, `(2,20)->DOWN`, and `(4,21)->RIGHT` all
  moved on retry and were not promoted. Promoted `(1,5).west/south`,
  `(2,6).west`, and `(1,7).north` with assertions and north-exit-to-Princess
  route guards.
- Follow-up noisy-route work from `(3,4)` started with the user's
  `(3,4)->DOWN` report. Same-origin probes confirmed `(3,4)->DOWN` into
  `(3,5).north`, `(3,4)->RIGHT` into `(4,4).west`, `(2,5)->DOWN` into
  `(2,6).north`, `(2,5)->RIGHT` into `(3,5).west`, `(2,4)->UP` into
  `(2,3).south`, `(4,3)->DOWN` into `(4,4).north`, and `(5,13)->DOWN` into
  `(5,14).north`. With those runtime blockers active, `auto_walk_blocker:5,19`
  escaped through `(3,3)`, `(4,3)`, `(5,3)`, the east column, then back through
  the known middle strip and reached `(5,19)`. Magician/Druin battles
  interrupted at `(2,17)`, `(2,18)`, and `(5,20)` and cleared under the
  30-second combat-watch rule. Interrupted down/up steps at those battle starts
  moved after combat and were not promoted. Promoted the seven confirmed
  blockers with assertions and a `(3,4)`-to-Princess route guard.

## 2026-06-23 Swamp Cave Entrance-to-Entrance Pass Polish

- Started from `POSITION: map=0x15(Swamp Cave) x=1 y=23` with target
  `South Stairs Up` `(0,29)` and no runtime blockers active.
- Same-origin `probe_edge:DOWN` from `(1,23)` reported `status=blocked`,
  `dest=(1,24)`, `reason=raw_hold_timeout`, final position `(1,23)`, no NPC
  block, no runtime block, and no approach-specific static block. The
  pre-existing `(1,24)` entry already had other blocked faces, so this promotes
  only `(1,24).north`.
- Runtime `add_blocked_edge:1,23,DOWN` added `(1,24).north`.
  `auto_walk_blocker:0,29` then planned `2 east, 6 south, 3 west`, moved
  through `(2,23)`, `(3,23)..(3,29)`, and reached `(0,29)` after resuming from
  a Ghost battle at `(1,29)`.
- Timing retries at `(2,23)->RIGHT`, `(3,28)->DOWN`, and the battle-interrupted
  `(1,29)->LEFT` were not promoted. The final `(1,29)->LEFT` moved cleanly
  after combat cleared.
- Promoted `(1,24).north` into `map_reader.lua` with a focused assertion and a
  north-exit-to-south-stairs route guard.

### NEXT CHECK

- The immediate gameplay next step is escorting Gwaelin back to Tantegel
  Castle. Object navigation now exposes `Princess Gwaelin` as a Swamp Cave-only
  NPC at `(5,18)` with interaction stand `(5,19)` facing north, and hides that
  target once the rescue/carry bit is set (`combat` changed from `0x08` to
  `0x09` after rescue).

The 2026-06-19 through 2026-06-21 `sweep_walk` break-in and hostile-area
validation has wrapped. Detailed live evidence was archived here:

- `handoff_archive/HANDOFF_2026-06-21_sweep_walk_break_in_scratchpad.md`
- `handoff_archive/HANDOFF_2026-06-19_sweep_walk_break_in_handoff.md`

Use `session_handoff.md`, `PLAYTESTING.md`, and `PROJECT_MEMORY.md` for
durable current state.

## Sweep Walk Break-In Summary

- `sweep_walk` is now the preferred normal-movement sweep command. It writes
  `sweep_status.txt` while active and final `sweep_walk_MM_runNNN.json`,
  `sweep_walk_MM_runNNN_summary.txt`, and `dw_crawl_MM.txt` review output on
  finish. The generated status/JSON/summary files are ignored.
- Garinham and Tantegel live runs covered larger safe areas without trusted
  teleport-backed blocker exports. Remaining noisy observations were kept in
  review-only timing-suspect, unstable-origin, door-frontier, boundary, or
  dynamic buckets unless same-origin walked verification supported a map patch.
- Swamp Cave hostile validation proved the battle-interruption exit path:
  random encounters stop the active sweep with `reason=battle_interrupted` and
  `source_classification=battle_interrupted`. For now, resume manually by
  starting a new sweep after combat returns to field control.
- Resume-from-JSON support is intentionally deferred. Field use should prove a
  real need before adding pause/resume complexity.
- User-observed `stop_sweep` behavior is good enough for this cleanup pass; the
  final live check was not repeated.

## Durable Bugs Fixed During Break-In

- Debug teleports now synchronize logical player coordinates with screen and
  sprite-position RAM through `teleport_state.lua`, reducing split-state
  failures after `teleport_to`.
- `speech_bridge.py` dispatches speech on a worker so a blocking screen reader
  call cannot stop command-file polling.
- Field/menu/dialogue scanning now suppresses scrolling status/name artifacts
  without relying on hard-coded hero names such as Bill or Ivy.
- `auto_step.lua` force-releases script-owned D-pad state on live-direction
  cancellation and map-crawl step cleanup paths, reducing sticky-input hangs.
- `map_crawler.lua` no longer resets movement RAM during sweep step completion
  or settle cleanup. Hostile Swamp Cave reruns after this change kept player
  stats clean across encounter interruptions.

## Next Work

- Local verification and CodeRabbit review passed on the cleaned diff.
- Resume normal gameplay/playtesting from the current save.
- Treat future sweep JSON as review evidence only. Promote map data only after
  walked same-origin confirmation or similarly strong live evidence.

For the next live map task, start a new dated section here with:

- current map id, floor, and player position
- exact target/object being investigated
- runtime blockers injected during the session
- evidence that is still uncertain or should not be promoted
- evidence that has been promoted to permanent map data

## 2026-06-24 Garinham Door / Route Triage

- Baseline resumed on Garinham `0x09`, with door RAM empty and
  `RUNTIME_BLOCKS map=0x09 none`.
- Door filter exposes exactly the two confirmed town doors:
  `Locked Building Door` at door cell `(4,6)`, interaction stand `(4,7)`
  facing north, and `Grave Route Door` at door cell `(17,10)`, interaction
  stand `(17,9)` facing south. `pathability_filter:reachable` reported no
  door objects; `pathability_filter:unreachable` reported those two.
- Skipping NPCs from the entrance and from the lower east corridor still
  produced no path to `(17,9)`, `(4,7)`, or the grave stairs `(19,0)`.
- The two lower hidden-bridge candidates were rechecked with walked origins:
  `verify_walked_edge:18,11,UP` blocked into `(18,10)` and
  `verify_walked_edge:19,11,UP` blocked into `(19,10)`, both with
  `reason=raw_hold_timeout`, no NPC block, no runtime block, and no existing
  directional block. Do not promote either cell as a passthrough from this
  evidence.
- Public-route polish:
  - From lower east corridor `(19,11)`, planner and live autowalk reached the
    exit stand `(1,14)`.
  - From `(1,14)`, live object browsing showed the Tool Merchant interaction
    stand is `(3,11)` for the current NPC position; the earlier coordinate
    probe to `(4,10)` was the wrong stand for this live object. Planner and
    `auto_walk_blocker:3,11` reached the Tool Merchant stand cleanly.
  - From Tool Merchant `(3,11)`, planner routes existed to Weapons `(10,16)`,
    Inn `(15,15)`, and exit `(1,14)`. `auto_walk_blocker:10,16` reached the
    Weapons stand cleanly.
  - First `auto_walk_blocker:15,15` from Weapons hit a live NPC at
    `(15,13)` from `(14,13)->RIGHT`; log marked `npc_blocked=true` and emitted
    no patch command. Retrying after the NPC moved reached the Inn stand.
  - `auto_walk_blocker:1,14` from the Inn stand reached the exit stand cleanly.
- Inn clutter follow-up:
  - User-reported blocker at `(13,16)->RIGHT`: two same-origin `probe_edge`
    checks blocked into `(14,16).west` with raw-hold timeouts and no NPC or
    runtime contamination. Runtime `add_blocked_edge:13,16,RIGHT` changed the
    planner away from that edge.
  - The reroute then exposed `(13,17)->RIGHT`: `auto_walk_blocker:15,15`
    reported a real seam-retry block, and same-origin `probe_edge:RIGHT`
    confirmed `(14,17).west` with no NPC or runtime contamination.
  - With runtime blockers active for `(14,16).west` and `(14,17).west`,
    `auto_walk_blocker:15,15` reached the Inn stand. Both edges were promoted
    to `map_reader.lua` with regression assertions in `test_map_reader.lua`.
- Grave Route Door follow-up:
  - Current object routing from public-side `(14,10)` targeted interaction
    stand `(17,9)` and reported `No path found` even with NPCs skipped.
    Inspection showed `(17,10)` is the closed door cell, `(17,9)` is walkable
    but unreachable from the public side, and `(17,11)` is walkable/reachable.
  - `verify_door_stand:17,11,UP` routed from `(14,10)` through `(14,11)` and
    row 11 to `(17,11)`, then logged `DOOR_VERIFY_READY` with
    `expected_door=(17,10)`, `keys_before=5`, and `baseline_slots=none`. The
    pending verifier was cancelled without spending a key.
  - Root cause: `objects.lua` preserved only the north-side grave-route OPEN
    stand `(17,9)` facing south. It now keeps that primary stand and adds the
    public-side stand `(17,11)` facing north via `interaction_points`, so the
    existing route-manager alternate-interaction logic can select the reachable
    side after a full script reload.
- Actual grave entrance follow-up:
  - User verified the Grave Route Door route now opens the door and leads to
    the appropriate stand. With the door open, the target pocket around
    `(18,0)`, `(18,1)`, `(19,0)`, and `(19,1)` inspected as internally
    walkable/passable, but both normal and skip-NPC pathfinding still reported
    no route from the door-side component.
  - `debug_route_frontier_skip_npcs:18,1,32` from `(18,7)` showed the same
    bridge family separating the target side: hidden candidates
    `(13,1)->DOWN` and `(19,11)->UP`, plus row-7/right-side directional gates
    such as `(13,1)->RIGHT`, `(18,7)->UP`, `(18,7)->RIGHT`,
    `(18,8)->RIGHT`, and `(18,9)->RIGHT`.
  - Fresh walked-origin checks confirmed blocked edges for `(13,1)->DOWN`,
    `(13,1)->RIGHT`, `(18,7)->RIGHT`, and `(18,7)->UP`. These agree with the
    existing model and do not identify a new promotable passthrough.
  - Closeout probe: script alive at position `(18,7)`, with
    `RUNTIME_BLOCKS map=0x09 none`, `PATH_STATE target=nil`, and runtime count
    0.
  - UNRESOLVED: no clean route to the actual grave entrance/stairs was found
    from the public/door side. Remaining useful checks are the nearby frontier
    gates `(18,8)->RIGHT`, `(18,9)->RIGHT`, `(17,7)->UP`, `(16,7)->UP`, and
    the lower hidden candidate `(19,11)->UP` if this path should continue.
  - User follow-up probed the four nearby frontier gates and reported all were
    blockers. The log confirmed clean blocks for `(18,9)->RIGHT`,
    `(17,7)->UP`, and `(16,7)->UP`; `(18,8)->RIGHT` was already refused by the
    model as directional-blocked.
  - Fresh frontier from live `(19,11)` to the stairs `(19,0)`, skipping NPCs,
    still reported `No path found` and only one bridge-to-target candidate:
    hidden bridge `(19,11)->UP` through `(19,10)`.
  - `(19,11)->UP` remains blocked under proper `probe_edge:up` evidence. A
    preceding manual-tap log briefly marked `(19,10)` passable immediately
    after `teleport_to:19,11`; treat that as teleport-seeded/movement-state
    fallout and DO NOT PROMOTE it as a passthrough.
  - Follow-up user/manual route check found the real bypass on the top edge:
    `(12,0)->RIGHT` entered `(13,0)`, `(13,0)->RIGHT` entered `(14,0)`, and
    `(14,0)->LEFT` returned to `(13,0)`. Fresh inspection showed the live
    source still treated `(13,0)` and `(14,0)` as `engine_boundary`, so
    `debug_pathfind_to_skip_npcs:19,0` from `(13,0)` stayed `No path found`
    despite the walked route.
  - Promoted `(13,0)` and `(14,0)` as Garinham `MAP_PASSTHROUGH_CELLS[0x09]`.
    Regression coverage now asserts both cells report `passthrough` and that
    pathfinder can route from `(13,0)` across `(14,0)` toward `(19,0)`. Leave
    the row-1 `(14,1).east/west` directional blockers in place; the valid route
    bypasses them along row 0. Reload `main.lua` in FCEUX before judging the
    live planner against this source fix.
  - Follow-up grave-stairs polishing after reload started with the
    user-reported `(9,3)->UP` blocker. `auto_walk_blocker:19,0` plus
    same-origin `probe_edge` confirmed `(8,3)->UP`, `(9,3)->UP`,
    `(10,3)->UP`, `(7,3)->UP`, `(6,3)->UP`, `(6,3)->DOWN`,
    `(7,4)->LEFT`, `(7,5)->LEFT`, `(7,6)->LEFT`, `(2,7)->UP`, and
    `(14,0)->DOWN` as real raw-hold timeouts with no NPC contamination.
  - With those false shortcuts closed at runtime, the route revealed the actual
    top-lane descent: `(14,0)->RIGHT` moved into `(15,0)` despite the model's
    `engine_boundary`, `(15,0)->RIGHT` into `(16,0)` blocked, and
    `(15,0)->DOWN` moved into `(15,1)`. From `(15,1)`, live
    `auto_walk_blocker:19,0` reached `(19,0)` through row 1. Promoted `(15,0)`
    as a Garinham passthrough, added the corresponding approach-only blockers,
    and extended regression coverage to require the
    `(13,0)->(14,0)->(15,0)->(15,1)` route shape.
  - After source reload, the user verified the route to stairs and found one
    remaining noisy upper-entry cut at `(6,7)->UP`. Same-origin
    `probe_edge:UP` confirmed `(6,6).south` blocked with raw-hold timeout and
    no NPC/runtime contamination. With runtime `add_blocked_edge:6,7,UP`, the
    route advanced to `(3,7)->UP`; same-origin raw probe confirmed
    `(3,6).south` blocked. With both runtime blocks active,
    `auto_walk_blocker:19,0` reached `(19,0)` through the top-lane descent.
    Promoted `(6,6).south` and `(3,6).south` with focused assertions.
  - Next user report named `(3,2)->WEST`, but live inspection showed that exact
    edge was already modeled as `(2,2).east`. The current live position and
    previous probe evidence were for adjacent `(3,1)->LEFT` into `(2,1).east`:
    route retry plus same-origin `probe_edge:left` both blocked with no
    NPC/runtime contamination. Runtime `add_blocked_edge:3,1,LEFT` preserved
    the route from `(3,1)` to the grave stairs, which reached `(19,0)`, but
    collapsed the return route from `(3,1)` to the world-map exit into a
    `No path found` with the stationary grave-door guard boundary. Promoted
    `(2,1).east`; continue return-side cleanup from fresh live evidence.
  - Return route from the grave stairs `(19,0)` to the world-map exit `(1,14)`
    can appear and disappear under live NPC planning. Fresh post-reload log
    samples alternated between 66-step routes and `No path found` with
    `npc_mode=live_npcs`, `npc_blocks=14`, and no runtime blocks. Controlled
    same-frame comparison at frame `14760` confirmed the cause: normal
    `debug_pathfind_to:1,14` returned `No path found [no_path]`, while
    `debug_pathfind_to_park_npcs:1,14` parked 15 slots and immediately found
    the stable 66-step route. Treat this as moving/stale NPC contamination,
    not permanent map geometry.
  - Follow-up return-route blocker from `(17,10)->LEFT` is clean geometry:
    `auto_walk_blocker` found `(16,10).east`, then same-origin `probe_edge:LEFT`
    from `(17,10)` blocked with `reason=raw_hold_timeout`, no NPC/runtime
    blocker, and open-looking floor. Promoted `(16,10).east` in
    `map_reader.lua` with a focused map-reader assertion. With runtime
    `add_blocked_edge:17,10,LEFT`, the route detoured down to row 14 and
    reached the exit stand `(1,14)`. Intervening stops around `(10,13)` /
    `(1,14)` were NPC timing/occupancy and should not be promoted.
  - Next grave-stairs pass started at `(5,7)->UP`: `auto_walk_blocker`
    seam retry found `(5,6).south`, then same-origin `probe_edge:UP` blocked
    with `reason=raw_hold_timeout`, no NPC/runtime/static blocker, and an
    open-looking floor preview. Runtime `add_blocked_edge:5,7,UP` rerouted west
    to the x=1 column, climbed back to row 1/top lane, and reached the grave
    stairs `(19,0)`. Promoted `(5,6).south` with a focused assertion.
  - Grave-stairs-to-Inn route cleanup started with `(1,4)->RIGHT`.
    `auto_walk_blocker` found `(2,4).west`, and same-origin
    `probe_edge:RIGHT` from `(1,4)` confirmed `reason=raw_hold_timeout`, no
    NPC/runtime blocker, and an open-looking tile preview. Runtime
    `add_blocked_edge:1,4,RIGHT` rerouted down the x=1 corridor, crossed row 8,
    descended through the grave-door/Inn approach, and reached the Inn stand
    `(15,15)`. Promoted `(2,4).west` with a focused assertion.

## 2026-06-25 Tantegel Sun Shrine Return Route

- Working from Sun Shrine stairs back to `Stairs Up to Tantegel Castle Throne
  Room` on map `0x04`.
- CLEAN / PROMOTED CANDIDATES: route plus same-origin `probe_edge:left`
  confirmed `(28,9)->LEFT`, `(28,10)->LEFT`, `(28,12)->LEFT`,
  `(28,13)->LEFT`, `(28,14)->LEFT`, `(28,15)->LEFT`, and `(28,16)->LEFT`
  as blocked with raw-hold timeout and no NPC/runtime contamination. These are
  east-approach blocks into `(27,9)`, `(27,10)`, `(27,12)`, `(27,13)`,
  `(27,14)`, `(27,15)`, and `(27,16)`. Follow-up continued the same pattern
  through `(28,17)->LEFT`, `(28,18)->LEFT`, and `(28,19)->LEFT`, confirming
  east-approach blocks into `(27,17)`, `(27,18)`, and `(27,19)`.
- DO NOT PROMOTE: intervening vertical moves down the x=28 lane repeatedly
  looked sticky on first hold but moved on seam retry; keep those vertical
  seams open.
- LIVE RESULT: with runtime east-approach blockers active for `(27,9)`,
  `(27,10)`, and `(27,12)..(27,19)`, `auto_walk_blocker:7,7` reached the
  throne-room stairs from `(28,19)`, and `auto_walk_blocker:28,19` returned to
  the Sun Shrine-side stand. `(6,17)` east/west twitches recovered on seam
  retry in both directions and remain timing noise, not map blockers.

## 2026-06-25 Sun Shrine Chest / Old Man Cleanup

- Map `0x0C` live baseline: started at `Stairs to Tantegel Castle` `(0,4)`
  with no runtime blockers. Object browsing only exposed the stairs from the
  west-edge tile, so cleanup used direct coordinate routing to chest `(4,5)`
  and old-man stand `(4,7)`.
- CLEAN / PROMOTED CANDIDATES: route retries plus same-origin probes confirmed
  `(2,4)->RIGHT`, `(2,5)->RIGHT`, and `(2,6)->RIGHT` block into
  `(3,4).west`, `(3,5).west`, and `(3,6).west`; route/probe also confirmed
  `(3,7)->UP` blocks into `(3,6).south`.
- DO NOT PROMOTE: `(2,4)->DOWN`, `(2,5)->DOWN`, `(2,6)->DOWN`, and
  `(4,5)->RIGHT` were retry-passable and should stay open.
- LIVE RESULT: with runtime blockers active, `auto_walk_blocker:4,5` reached
  the chest, `auto_walk_blocker:4,7` reached the old-man stand from the stairs,
  and `auto_walk_blocker:0,4` returned to the Tantegel stairs. Final position
  was map `0x0C` at `(0,4)`.

## 2026-06-25 Sun Shrine Follow-Up Route Polish

- Follow-up route from the stairs was still bouncy after the first geometry
  change. Fresh route retries plus same-origin probes confirmed additional
  false cuts: `(2,3)->RIGHT` into `(3,3).west`, `(3,2)->DOWN` into
  `(3,3).north`, `(4,2)->DOWN` into `(4,3).north`, `(5,2)->DOWN` into
  `(5,3).north`, `(6,2)->DOWN` into `(6,3).north`, and the right-wall
  entries `(7,3..6)->LEFT` into `(6,3..6).east`.
- DO NOT PROMOTE: `(2,2)->DOWN` was rechecked from a normal-walked origin and
  moved through `(2,3)`, ending at `(2,4)` during the probe hold. The x=2
  vertical lane and row-7 bypass remain the intended open route.
- LIVE RESULT: with the runtime overlay active, fresh
  `auto_walk_blocker:4,7` from `(0,4)` reached the old-man stand through
  `(2,4)->(2,7)->(4,7)`, and `auto_walk_blocker:0,4` returned to the stairs.

## 2026-06-25 Sun Shrine Chest Return Polish

- CLEAN / PROMOTED CANDIDATES: starting from chest cell `(4,5)`, the return
  route to `Stairs to Tantegel Castle` first tried `(4,5)->LEFT`; route failure
  plus same-origin `probe_edge:left` confirmed `(3,5).east` with raw-hold
  timeout and no NPC/runtime contamination. Follow-up reroutes confirmed
  `(3,4).east` from `(4,4)->LEFT`, `(4,3).south` from `(4,4)->UP`,
  `(5,3).south` from `(5,4)->UP`, `(6,4).west` from `(5,4)->RIGHT`, and
  `(6,5).west` from `(5,5)->RIGHT` using the same route-plus-probe pattern.
- DO NOT PROMOTE: `(4,5)->UP` into `(4,4).south` and `(4,4)->RIGHT` into
  `(5,4).west` both moved on seam retry and should stay open.
- LIVE RESULT: with runtime blockers for `(3,5).east`, `(3,4).east`,
  `(4,3).south`, `(5,3).south`, `(6,4).west`, and `(6,5).west`,
  `auto_walk_blocker:0,4` returned from the chest-side pocket to the stairs
  via `(5,5)->(5,7)->(1,7)->(1,4)->(0,4)`.

## 2026-06-26 Rain Shrine Staff Return Route

- CLEAN / PROMOTED CANDIDATES: starting from the Staff of Rain side on map
  `0x0D`, route failure plus same-origin `probe_edge:up` from `(5,4)`
  confirmed `(5,3).south`. After runtime patching that edge, the reroute found
  `(8,8)->DOWN`; same-origin `probe_edge:down` confirmed `(8,9).north`. Both
  blocked with raw-hold timeout, no NPC blocker, and no pre-existing runtime
  blocker.
- DO NOT PROMOTE: the route successfully walked down the x=8 lane through
  `(8,5)..(8,8)`, then after the second patch walked west across row 8 through
  `(7,8)`, `(6,8)`, `(5,8)`, `(4,8)` and down through `(4,9).north`. Keep
  those seams open.
- LIVE RESULT: with runtime blockers for `(5,3).south` and `(8,9).north`,
  `auto_walk_blocker:4,9` reached the exit tile at `(4,9)`.

## 2026-06-26 Kol Tool Merchant Trigger Hunt

- LIVE BASELINE: map `0x07` / Kol, both known magic-key doors already open:
  `(7,12)` and `(1,14)`. Tool Merchant NPC remained at `(14,21)`. The
  selected-teleport stand `(12,21)` is still a valid shop trigger but not
  reachable from the public route graph.
- CLEAN / CONFIRMED EXISTING GEOMETRY: direct same-origin probes confirmed the
  frontier bridges into the tool-counter component are sealed in live play:
  `(12,18)->DOWN`, `(11,19)->DOWN`, `(11,19)->RIGHT`, `(13,18)->DOWN`,
  `(14,18)->DOWN`, `(15,18)->DOWN`, `(16,18)->DOWN`, `(11,18)->LEFT`,
  `(11,19)->LEFT`, `(17,19)->LEFT`, and `(17,20)->LEFT` all blocked with
  raw-hold timeout. Earlier same-state route work had already confirmed
  `(17,21)->LEFT` and `(17,22)->LEFT`.
- DOOR THEORY CHECKED: `verify_door_stand:17,21,LEFT` plus manual DOOR logged
  "There is no door here"; `verify_door_after` reported expected door
  `(16,21)` absent, keys `4 -> 4`, door slots unchanged. Repeated from
  `(17,22)` facing left for expected door `(16,22)` with the same no-door,
  no-key-delta result.
- TALK CHECKED: `(17,20)` facing west returned "There is no one there" and did
  not activate the merchant detector.
- LIVE RESULT: `debug_route_frontier_skip_npcs:12,21` still reports
  `hidden_bridge_candidates=0`; all direct bridge-to-target candidates are
  accounted for. No new permanent map data was discovered in this pass. The
  current open question is whether Kol's item shop has a different public
  trigger than the selected-teleport stand, or whether this service should stay
  unrouteable/flagged until a manual trigger is found.

### Follow-Up: West-Side Throat Found

- LIVE PROOF: the user found that walking `(1,16)->DOWN` reaches `(1,17)` and
  immediately revives the known Tool Merchant route. Fresh logs showed
  `(1,16)` itself is ordinary walkable floor, while `(1,17)` ROM-decodes as
  tile-0/non-walkable. Manual movement repeatedly crossed `(1,16)<->(1,17)`,
  and route planning from `(1,17)` found the Tool Merchant route again.
- CLEAN / PROMOTED: `map_reader.lua` now models only `(1,17)` as a Kol
  passthrough. `(1,18)` inspected as ordinary walkable floor; no nearby
  directional blockers were removed.
- RELOAD NEEDED: FCEUX needs a manual `main.lua` reload before live
  `debug_pathfind_to_skip_npcs:12,21` or Tool Merchant autowalk will reflect
  the source fix from `(1,16)`.

### Follow-Up: `(1,19)` Pocket Closed

- LIVE PROOF: after the script reload picked up the `(1,17)` passthrough, the
  Tool Merchant route next tried the standable pocket at `(1,19)`. Route
  failure plus same-origin probes confirmed `(1,19)->RIGHT` into `(2,19).west`,
  `(1,19)->DOWN` into `(1,20).north`, and `(1,19)->UP` into `(1,18).south`
  all block with raw-hold timeout and no NPC involvement. `(1,19)->LEFT`
  already fails as the west engine boundary.
- CLEAN / PROMOTED: `map_reader.lua` now models only those three false exits
  as Kol directional blockers. The destination cells remain open from
  unproven/opposite approaches.
- RELOAD NEEDED: FCEUX needs another manual `main.lua` reload before the live
  planner reflects the new pocket blockers.
- DO NOT PROMOTE: after teleporting back to `(1,16)` only to escape the
  confirmed `(1,19)` dead pocket, `auto_walk_blocker:12,21` reported
  `(1,16)->DOWN` into `(1,17).north` as blocked. Follow-up raw/sequence input
  from the same seed also failed to move, and a one-step autowalk to ordinary
  open floor `(2,16)` falsely reported `(2,16).west` blocked. Treat those
  `(1,16)` failures as contaminated post-teleport/input-state evidence. Next
  clean route check should start after a manual reload/restore or after the
  player has manually re-established normal movement at the west-side throat.

### Follow-Up: Entrance-Side Connector Found

- LIVE BASELINE: after a clean script/game restore at Kol `(19,23)`, both
  known Magic Key doors were open in RAM: door slots `(7,12)` and `(1,14)`.
  Runtime blockers were empty. Normal and skip-NPC pathfinding from the town
  entrance could not reach `(1,16)` or Tool Merchant stand `(12,21)`.
- LIVE PROOF: `debug_route_frontier_skip_npcs:1,16,20` and
  `debug_route_frontier_skip_npcs:12,21,30` both reported three hidden bridge
  candidates: `(5,13)->DOWN` into `(5,14)`, `(6,13)->DOWN` into `(6,14)`, and
  `(7,13)->DOWN` into `(7,14)`. All three candidate cells decode as tile-0.
  A normal autowalk from `(19,23)` reached `(5,13)`, and same-origin
  `probe_edge:DOWN` moved through `(5,14)` and settled at `(5,15)`, logging
  `moved_through_modeled_block`. From `(5,15)`, skip-NPC paths exist to
  `(1,16)` and `(12,21)`.
- CLEAN / PROMOTED: `map_reader.lua` now models only `(5,14)` as the
  entrance-side Kol passthrough. `(6,14)` and `(7,14)` remain unmodeled until
  they get their own live movement proof.
- RELOAD NEEDED: FCEUX needs a manual `main.lua` reload before entrance-side
  Tool Merchant autowalk can use `(5,14)`.

### Dialogue Filter Detour

- LIVE BUG: Kol's scrolling/status layout exposed a stale lower-window fragment
  `ll` while the field UI was otherwise clear. Diagnostics showed
  `MENU_STATE lower_len=2`, `UPPER_STATE lower="ll"`, and
  `INPUT_GUARD_STATE dialogue_len=0 unavailable_reason=nil`. Starting an edge
  probe then let the fragment re-enter `PREV.dialogue`, causing
  `EDGE_PROBE_RESULT status=interrupted reason=Wait for dialogue to finish`.
  The same shared guard can block object/readout hotkeys such as `J/K/L/O`
  until the stale fragment clears.
- SOURCE FIX: `lower_status_noise_suppression_active()` now suppresses known
  passive status/name fragments whenever the game is in field play and no
  modal field UI is active, instead of limiting that suppression to passive
  idle, autowalk, or map-crawl windows.
- FOLLOW-UP SOURCE FIX: the command-menu lower-dialogue gate now applies the
  same passive status/name fragment filter before deciding whether lower
  dialogue should block menu speech. Live bad state had raw/cached command menu
  open with `lower="ll"`, `active_block=false`, and `cmd_confirmed=false`,
  which cleared the live command-menu session and made SPELL/`J/K/L/O` style
  controls behave as though dialogue were still active.
- FOLLOW-UP SOURCE FIX: after a restore to the Kol entrance, opening the
  command menu still announced standalone `Bill`. Logs showed
  `EVENT: command menu opened`, then `PREV.dialogue_len=4` and
  `EVENT: dialogue: Bill` while `menu_active=true`. The status/name fragment
  suppression now also runs during the field command menu; it still skips
  submenus, Yes/No prompts, merchants, battle, and non-field states. Real
  command responses are preserved because they do not match
  `text.is_passive_field_status_noise()`.
- FOLLOW-UP SOURCE FIX: after that source reload, the command menu stopped
  speaking the hero name, but the same standalone `Bill` fragment could migrate
  to the SPELL submenu. The suppression guard now also runs while
  `submenu_mode == "SPELL"` because spell-list speech comes from cursor/RAM
  state; STATUS, ITEM, Yes/No, merchant, battle, and non-field screens remain
  excluded from this passive-fragment suppression.
- FOLLOW-UP SOURCE FIX: held ITEM menu browsing then exposed the merchant
  parser claiming the inventory list. Recent logs showed `MERCHANT_SELECT`
  lines for held inventory entries such as `Fairy Flute`, `Wings`,
  `Gwaelin's Love`, and bogus prices like `Magic Armor. 4 gold.` before ITEM
  submenu ownership could stabilize. `merchant.lua` now rejects offer-list
  detection when a full field-command backdrop is visible behind the item list,
  and when only status rows plus unpriced inventory entries are visible after
  scroll/base context selection, while preserving actual shop offer screens and
  Buy/Sell prompts.
- FOLLOW-UP SOURCE FIX: after another reload/test, the log still showed
  `MERCHANT_SELECT` at frames `01488`, `01643`, and `01712`, but no
  `CMD_ITEM_FIRE`/`ITEM_CURSOR` ownership. Root cause is order as well as
  parser shape: `check_command_menu()` let merchant detection return before a
  confirmed command-ITEM-to-item-list cursor jump could set
  `submenu_mode = "ITEM"`. Confirmed ITEM entry now runs before merchant
  override and clears stale merchant state.
- FOLLOW-UP SOURCE FIX: after a full emulator restart, held ITEM browsing still
  spoke as merchant. Fresh logs showed command-menu input reaching ITEM, then
  `MERCHANT_SELECT` at frame `00913` with no `CMD_ITEM_FIRE`; a live
  `report_menu_state` while the item list was open showed `submenu=nil` and
  `merchant_active=true`. The cursor-jump detector is too late for this screen,
  so `check_command_menu()` now handles the direct A press on confirmed
  ITEM(1,1) before merchant detection, sets `submenu_mode = "ITEM"`, and keeps
  the older cursor-jump detector as a fallback.
- FOLLOW-UP SOURCE FIX: after the direct ITEM ownership fix, merchant speech was
  gone but the generic lower dialogue reader still announced visible inventory
  rows such as `Silver Harp Cursed Belt Gwaelin's Love Torch`. Live state while
  the menu was open showed `submenu=ITEM`, `merchant_active=false`, and
  `PREV.dialogue_len=25`. `check_dialogue()` now absorbs STATUS, ITEM, and
  SPELL submenu windows because those screens are spoken from cursor/RAM state,
  not generic dialogue.
- LIVE VERIFICATION: after the ITEM/menu fixes were manually reloaded, the user
  verified command responses and submenus were reading normally. Fresh logs
  showed no new `MERCHANT_SELECT` pollution while browsing command responses.
- FOLLOW-UP SOURCE FIX: during Kol wrap-up, the user attempted `U` autowalk
  while the field command menu was open. Logs showed
  `AUTO_WALK_HOTKEY_RELEASE_START` at frame `01195`, but
  `EVENT: command menu closed` did not occur until frame `01860`, so the
  route queued before the menu guard caught up. Root cause: the main loop runs
  `hotkeys.update()` before `check_command_menu()`, and
  `DW_QOL_STATE.command_menu_blocks_field_movement()` only trusted
  `CMD.menu_live`; a fresh visible command menu could therefore slip through
  for that early frame. `main.lua` now also blocks raw `menu.is_open()` when a
  visible cursor tile is present, preserving the older stale-COMMAND protection
  because raw text alone is still ignored. `hotkeys.lua` now speaks the current
  guard reason if a deferred `U` release is cancelled. Focused checks passed:
  `luac -p main.lua hotkeys.lua test_hotkeys.lua
  test_sweep_walk_command_surface.lua`, `lua test_hotkeys.lua`, and
  `lua test_sweep_walk_command_surface.lua`.

### Follow-Up: Lower Tool Merchant Bridge Found

- LIVE PROOF: continuing from the entrance-to-Tool-Merchant route, autowalk
  reached `(5,15)` through the existing `(5,14)` passthrough. Same-origin
  probes confirmed the false route exits `(5,15)->DOWN`,
  `(3,15)->LEFT`, `(3,16)->LEFT`, and `(3,15)->UP` all raw-hold-timeout
  blocked without menu/dialogue/NPC contamination.
- FRONTIER LEAD: with those runtime blockers active, `debug_route_frontier_skip_npcs:12,21,40`
  reported row-17 hidden bridge candidates. The nearest live candidate was
  `(3,16)->DOWN` into tile-0 `(3,17)`, with target-side exit down to `(3,18)`.
- LIVE PROOF: from normally walked `(3,15)`, `probe_edge:DOWN` moved through
  `(3,16)` and settled on tile-0 `(3,17)`. `inspect_tile:3,17` reported
  tile-0/non-walkable in the current model while the hero stood there.
  `probe_edge:DOWN` from `(3,17)` then moved through `(3,18)` and settled at
  `(3,19)`, where skip-NPC pathfinding found `7 east, 2 south, 2 east` to
  `(12,21)`.
- LIVE PROOF: final autowalk from `(3,19)` found one more false shortcut,
  `(9,19)->RIGHT` into `(10,19).west`, confirmed by same-origin
  `probe_edge:RIGHT`. After runtime `add_blocked_edge:9,19,RIGHT`,
  `auto_walk_blocker:12,21` reached `(12,21)`.
- CLEAN / PROMOTED: `map_reader.lua` now adds Kol passthrough `(3,17)` and
  directional blockers `(5,16).north`, `(2,15).east`, `(2,16).east`,
  `(3,14).south`, and `(10,19).west`. Focused `test_map_reader.lua`
  assertions cover the new passthrough, keep adjacent row-17 siblings closed,
  and verify the promoted edge blockers.
- RELOAD NEEDED: FCEUX needs a manual `main.lua` reload before validating the
  full entrance-to-Tool-Merchant route against source instead of runtime
  blockers.

### Follow-Up: Tool Merchant Return Route Cleaned

- LIVE PROOF: continuing from the Tool Merchant stand `(12,21)`, repeated
  `auto_walk_blocker:19,23` route failures plus same-origin `probe_edge`
  checks closed the false return-route shortcuts. The promoted destination
  blockers are `(7,15).west`, `(4,16).west/north`, `(4,18).east`,
  `(6,16).north`, `(10,18).west`, `(2,19).east/south`, `(4,20).east/north/west`,
  `(10,20).south/west`, `(11,20).south`, `(12,20).south`,
  `(3,21).north/south/west`, `(4,21).east`, `(13,21).west`,
  `(4,22).east/west`, `(10,22).north/west`, `(11,22).north`,
  `(12,22).north`, `(4,23).west`, and `(5..9,23).north`.
- LIVE RESULT: with the runtime overlay active, `auto_walk_blocker:19,23`
  reached the town exit `(19,23)`. The reverse check
  `auto_walk_blocker:12,21` then walked from the exit back to the Tool
  Merchant stand, completing at `(12,21)`.
- CLEAN / PROMOTED: `map_reader.lua` now carries the return-route blockers in
  Kol `MAP_DIRECTIONAL_BLOCKS[0x07]`; `test_map_reader.lua` covers the
  promoted edges. Focused checks passed: `luac -p map_reader.lua
  test_map_reader.lua`, `lua test_map_reader.lua`, and `git diff --check`.
- RELOAD NEEDED: FCEUX still has the runtime overlay from this investigation.
  Manual `main.lua` reload is needed before validating the route against source
  alone.

### Follow-Up: Inn Route Final Edge

- LIVE PROOF: while cleaning the entrance-to-Inn route, autowalk stopped at
  `(9,4)->RIGHT` into `(10,4).west`. The same-origin `probe_edge:right` from
  `(9,4)` also raw-hold-timeout blocked with no NPC involvement. Runtime
  `add_blocked_edge:9,4,RIGHT` then planned around the edge and
  `auto_walk_blocker:19,2` reached the confirmed Inn stand at `(19,2)`.
- CLEAN / PROMOTED: `map_reader.lua` now adds `(10,4).west` to Kol
  `MAP_DIRECTIONAL_BLOCKS[0x07]`, and `test_map_reader.lua` asserts it beside
  the existing Kol inn-route blockers. Focused checks passed: `luac -p
  map_reader.lua test_map_reader.lua`, `lua test_map_reader.lua`,
  `lua test_pathfinder.lua`, and `git diff --check`.
- RELOAD NEEDED: FCEUX still has the runtime overlay for this edge. Manual
  `main.lua` reload is needed before validating the route against source alone.

## 2026-06-27 Rimuldar Inn Route Recheck

- LIVE PROOF: entrance-to-Inn route planning targeted the stored public stand
  `(16,17)` for `Merchant 3` / `Inn` at `(16,18)`, then failed at
  `(15,16)->DOWN`. Same-origin `probe_edge:DOWN` from normally walked
  `(15,16)` raw-hold-timeout blocked with no NPC involvement, so
  `(15,17).north` is promoted.
- LIVE PROOF: after runtime `add_blocked_edge:15,16,DOWN`, the next lower
  route reached `(18,19)` and failed `(18,19)->LEFT`. Same-origin
  `probe_edge:LEFT` from normally walked `(18,19)` raw-hold-timeout blocked
  with no NPC involvement, superseding the older mixed `(17,19).east` note.
- LIVE RESULT: with runtime blockers for `(15,17).north` and `(17,19).east`,
  `debug_route_frontier_skip_npcs:16,17,60` reports no remaining untested
  bridge into the stored stand. The hidden bridge candidates
  `(16,15)->DOWN`, `(15,16)->RIGHT`, `(18,18)->LEFT`, `(18,16)->LEFT`, and
  `(17,15)->DOWN` were already checked from walked origins and blocked.
- LIVE RESULT: `debug_pathfind_adjacent_skip_npcs:16,18` shows no route to any
  innkeeper-adjacent stand. `(16,17)` and `(16,19)` are walkable but
  unreachable; `(15,18)` and `(17,18)` are not walkable. A focused
  `debug_route_frontier_skip_npcs:16,19,40` found only the already-modeled
  `(16,20)->UP` south approach as a bridge to the south stand.
- CLEAN / PROMOTED: `map_reader.lua` now adds Rimuldar blockers
  `(15,17).north` and `(17,19).east`; `test_map_reader.lua` covers both.
- REOPENED / DO NOT PROMOTE: the apparent `(17,17)`/`(18,17)` connector was not
  bidirectional. The command-side `probe_edge:RIGHT` from `(17,17)` moved
  through `(18,17)`, but the clean entrance-to-Inn route from `(29,13)` reached
  `(18,17)` and repeatedly blocked on `(18,17)->LEFT` into `(17,17)`. Seam
  retries logged `blocked=6 moved=0`, added runtime block `(17,17)` with
  `approach=east`, and then the route collapsed with `No path found`.
- CLEAN / PROMOTED: restored `(17,17).east` in `map_reader.lua` and updated
  `test_map_reader.lua` to guard the entrance-to-Inn regression. Keep the
  reverse movement clue as one-way evidence only; this seam is not the missing
  public connector to the inn stand.
- CLEAN / PROMOTED: user found the actual reachable Inn stand. From `(18,18)`,
  TALK opened the `Welcome to the traveler's Inn. Room and board is 55 GOLD per
  night` prompt; `report_position` confirmed `(18,18)`, `report_npcs` confirmed
  `npc_16` / `Inn` remains at `(16,18)`, and path debug from `(18,18)` to the
  town exit `(29,13)` found routes in both skip-NPC and live-NPC modes. Updated
  `objects.lua` so the Inn routes primarily to `(18,18)` facing west, while
  preserving `(16,17)` facing south as an alternate prompt stand.

### Follow-Up: Magic Key Merchant Route Cleanup

- LIVE PROOF / PROMOTED: entrance-to-Magic-Key route stopped at
  `(9,10)->UP` into `(9,9).south`; route seam retry and same-origin
  `probe_edge:UP` both raw-hold-timeout blocked with no NPC involvement.
  Runtime `add_blocked_edge:9,10,UP` opened the next route stage.
- LIVE PROOF / PROMOTED: the next stage stopped at `(12,10)->UP` into
  `(12,9).south`; same-origin `probe_edge:UP` also blocked. Runtime
  `add_blocked_edge:12,10,UP` opened the west-side route stage.
- UNRESOLVED: the west-side stage then stopped at `(1,8)->RIGHT` into
  `(2,8).west`. Same-origin `probe_edge:RIGHT` and forensic
  `probe_edge_verify:1,8,RIGHT,5` both blocked. However, adding that runtime
  edge makes the route to the Magic Key Merchant no-path. `debug_route_frontier`
  reported 12 one-step bridge candidates into the merchant-side component; the
  reachable candidates checked from normal origins all blocked:
  `(1,6)->RIGHT`, `(1,7)->RIGHT`, `(4,9)->UP`, `(3,9)->UP`, `(2,9)->UP`,
  `(6,9)->UP`, `(7,6)->LEFT`, `(7,5)->LEFT`, `(7,4)->LEFT`,
  `(7,3)->LEFT`, and `(1,5)->RIGHT`. A focused
  `crawl_map_frontier:attempts=2,max_edges=80` was manually stopped after 41
  edges and found no passthrough or directional candidates.
- Fresh tainted-verifier audit rechecked `(6,9)->UP` with
  `verify_walked_edge:6,9,UP`: the route reached `(6,9)` through normal
  movement, then the up probe into `(6,8)` raw-hold-timeout blocked with no
  NPC/runtime blocker involved. Keep `(6,8).south` closed unless contradicted
  by later live movement from a cleaner state.
- Fresh tainted-verifier audit also rechecked the disputed bridge
  `(1,8)->RIGHT` after FCEUX input recovery. The walked verifier reached
  `(1,8)` and raw-hold-timeout blocked into `(2,8)` even though current source
  still treats `(2,8).west` as passable. This strongly suggests the old
  passable verifier proof was tainted or state-dependent.
- With temporary runtime `add_blocked_edge:1,8,RIGHT`, `debug_route_frontier`
  from the town entrance still reported only the same 12 one-step bridge
  candidates into the Magic Key Merchant component. Fresh audit rechecked
  `(7,6)->LEFT`, `(4,9)->UP`, `(1,6)->RIGHT`, `(1,7)->RIGHT`, and
  `(1,5)->RIGHT`; all reached their origins through normal movement and then
  raw-hold-timeout blocked. That leaves no known single-edge reopen candidate.
- UNRESOLVED / TRANSITION CHECK: the apparent alternate-overworld-entry theory
  did not hold up in live FCEUX. Leaving Rimuldar through the east edge changed
  to the world map at `(102,72)`. Re-entering the town tile from all four
  adjacent overworld sides landed at the same interior coordinate `(29,14)`:
  `(103,72)->LEFT`, `(101,72)->RIGHT`, `(102,71)->DOWN`, and
  `(102,73)->UP`. A normally reached `(4,3)->UP` probe also stayed blocked,
  so do not assume the modeled `Northwest Exit to World Map` gives a second
  key-shop-side town entrance without fresh transition proof.
- CLEAN / PROMOTED: `map_reader.lua` now models `(9,9).south` and
  `(12,9).south`; `test_map_reader.lua` covers both and flips the stale
  `(9,9).south must stay open` assertion. Do not promote `(2,8).west` yet; it
  needs either a missing alternate bridge or a state-condition explanation.
- FRESH AUDIT / DO NOT PROMOTE: after clearing the temporary `(2,8).west`
  runtime close, a source-planned route from the normally reached row-2/top
  strip walked to `(1,8)` and again blocked on `(1,8)->RIGHT` into
  `(2,8).west`. Seam retry logged `blocked=3 moved=0`, no runtime blocks were
  active, and `auto_walk_blocker` reported `patch_command=add_blocked_edge:1,8,RIGHT`.
  This reinforces that the old 5/5 open verifier was tainted or state-dependent.
- FRESH AUDIT / REVIEW ONLY: with `(2,8).west` closed at runtime, local
  ROM-backed reranking found only row-1/top-strip hypotheses. Walked-origin
  probes proved `(9,2)`, `(10,2)`, and `(11,2)` are real hidden row-2 strip
  cells, and row-2 movement also crossed through `(12,2)->RIGHT` to `(14,2)`.
  However, north entries into row 1 from `(9,2)`, `(10,2)`, `(11,2)`,
  `(12,2)`, `(13,2)`, and cleanly reached `(14,2)` all raw-hold-timeout
  blocked. Do not promote the row-2 cells as a route fix yet; they did not
  reconnect the Magic Key Merchant component.
- FRESH AUDIT / UNRESOLVED: with temporary runtime
  `add_blocked_edge:1,8,RIGHT` active, `debug_route_frontier_skip_npcs:4,6,80`
  from the cleanly reached `(14,2)` strip still reported the same 12
  bridge-to-target candidates and no hidden bridge candidates. The top-ranked
  candidate remained the runtime-blocked `(1,8)->RIGHT`; all other high-value
  bridge candidates match already-rejected edges from this cleanup pass.
- FRESH CRAWL / UNRESOLVED: after FCEUX input recovery, with runtime
  `(2,8).west` still closed and no bridge input active, a normal-movement
  `crawl_map_frontier:attempts=2,max_edges=80,park_mobile_npcs=true` from the
  key-shop-side component hit the edge cap at 80 edges. It exported
  `passthrough=0`, `directional=0`, `stationary_npc=0`, and
  `door_frontier=0`; only x=1 boundary/timing cells plus `(2,12)` were marked
  unstable. A read-only frontier comparison from `(3,10)` likewise found no
  hidden bridges and ranked the temporary runtime-closed `(1,8)->RIGHT` edge
  first. This pass did not find an alternate bridge into the Magic Key
  Merchant component.
- GUIDE-ALIGNED REGION AUDIT / UNRESOLVED: external guide/map data points to
  the northwest water-hugging route, so the upper x=7 bridge candidates were
  rechecked from walked origins. `verify_walked_edge:7,3,LEFT`,
  `verify_walked_edge:7,4,LEFT`, `verify_walked_edge:7,5,LEFT`, and
  `verify_walked_edge:7,6,LEFT` all reached their origins normally and then
  raw-hold-timeout blocked into `(6,3)..(6,6)`. A stateful carry test on the
  x=1 strip did not prove `(1,8)->RIGHT`: entering `(1,8)` from `(1,7)` with
  raw Down and a short wait drifted to `(1,9)`, while entering from `(1,9)`
  with raw Up and a longer wait overshot to `(1,7)` and then blocked
  `(1,7)->RIGHT`. Treat these seed-flow runs as evidence that the x=1 strip
  has carry/scroll timing quirks, not as passability proof for `(2,8).west`.
- USER SCREENSHOT FOLLOW-UP / BLOCKED: user positioned the hero at `(1,8)`.
  Fresh `report_position` confirmed map `0x0B` at `(1,8)`. Direct same-origin
  `probe_edge:RIGHT` into `(2,8)` first blocked with runtime `(2,8).west`
  active, then blocked again after `clear_runtime_blocks:0x0B`, with
  `reason=raw_hold_timeout`, no NPC or permanent blocker, and source preview
  still effectively passable. Runtime `(2,8).west` was restored afterward as
  a live-only blocker. This is clean evidence that `(1,8)->RIGHT` is currently
  not the missing bridge, but the alternate bridge into the key-shop component
  remains unresolved.
- TOOLING BUG / PATCHED, NEEDS RELOAD: FCEUX repeatedly latched
  `LeftAlt+Return`; the external bridge ignored stale Alt, but the native
  stuck-Alt fallback in `debug_tools.lua` translated Return into repeated
  Start. Added regression coverage in `test_debug_tools.lua` and changed the
  native fallback to ignore Return/Enter while stale Alt is active. The
  explicit sidecar bridge can still send `start`. `recover_fceux_input.ps1`
  and `launch_dw.ps1` now release Return in the same key-up pulse as Alt.
  FCEUX must reload `main.lua` before further live route probing benefits
  from this fix.
- POST-RELOAD FRONTIER SWEEP / STILL UNRESOLVED: after the script reload and
  stale-Alt hardening, the player stood at `(1,8)` with the command menu
  closed. A local normal-movement crawl from `(1,8)` with runtime
  `add_blocked_edge:1,8,RIGHT` completed 69 edges and exported
  `passthrough=0`, `directional=0`, `stationary_npc=0`, and
  `door_frontier=0`; the only notable excluded cell was the already-known
  dead pocket `(1,19)`. Fresh walked-origin checks then revalidated all
  twelve `debug_route_frontier_skip_npcs:4,6` bridge-to-target candidates:
  `(1,8)->RIGHT` is the runtime-blocked edge; `(1,6)->RIGHT`,
  `(1,7)->RIGHT`, `(1,5)->RIGHT`, `(2,9)->UP`, `(3,9)->UP`,
  `(4,9)->UP`, `(6,9)->UP`, and `(7,3..7,6)->LEFT` all reached their
  origins by normal walking and raw-hold-timeout blocked with no NPC cause.
  A fresh frontier snapshot from `(7,3)` still reported exactly those twelve
  bridge-to-target entries and no `hidden_bridge=true` candidates. With the
  runtime block briefly cleared for read-only comparison, the source model's
  route from `(7,3)` to `(4,6)` was
  `3 south, 1 east, 3 south, 7 west, 1 north, 3 east, 2 north`, confirming
  the permanent model still relies on the contested `(1,8)->RIGHT` bridge.
  The runtime `(2,8).west` block was restored immediately. Do not promote the
  permanent block until either the missing state condition / bridge is found
  or the key-merchant route is intentionally marked unresolved.
- FORENSIC NORTHWEST EXIT CHECK / REVIEW ONLY: explicit `teleport_to:4,3`
  followed by `probe_edge:UP` moved to `(4,2)` and logged a
  `moved_through_modeled_block` mismatch for `(4,2).south`; this was
  teleport-seeded and is not valid route proof. Follow-up `probe_edge:UP` from
  `(4,2)` blocked into `(4,1)` and did not transition to the world map. The
  player was returned to `(7,3)` afterward. This does not solve the missing
  public route; keep the earlier alternate-overworld-entry theory unresolved /
  unproven.
- FORENSIC Y=0 CHECK / REVIEW ONLY: after clearing stale FCEUX Alt input, the
  source model rejected `(13,0)` / `(4,0)` as `engine_boundary` and rejected
  `(13,1)` / `(4,1)` as non-walkable tile type, while `(13,2)` remained a
  modeled passthrough. A forced `teleport_to:13,0,force` then proved the user's
  top-row observation is real in a forced seed: `probe_edge:RIGHT` moved through
  modeled boundary `(14,0)` and carried to `(15,0)`, and a second right probe
  carried from `(15,0)` to `(17,0)`. Descent samples from `(15,0)->DOWN` and
  `(17,0)->DOWN` both raw-hold-timeout blocked into row 1. This is not
  promotable map evidence yet; look for a normal-walk entry into y=0 or a
  descent back into the trusted map before exposing any row-0 Rimuldar cells.
  The player was restored to `(1,8)` afterward.
- SECOND GUIDE-ALIGNED PASS / STILL UNRESOLVED: after input recovery, the user
  / live state had the player at `(7,2)`, near the upper water-hugging strip.
  With temporary runtime `(2,8).west` closed, `debug_route_frontier_skip_npcs`
  from `(7,2)` to the key stand reported `target_reachable=false`,
  `bridge_candidates=13`, and `hidden_bridge_candidates=0`. The 13th
  bridge-to-target candidate not covered by the prior 12-edge sweep was
  `(7,2)->LEFT` into `(6,2)`; same-origin `probe_edge:LEFT` from the live
  `(7,2)` origin raw-hold-timeout blocked with the permanent `(6,2).east`
  directional blocker active. Alternate adjacent talk stands around Old Man 1
  were also no-path while `(2,8).west` was closed: `(4,6)`, `(4,8)`, `(3,7)`,
  and `(5,7)` all stayed unreachable, so there is no obvious alternate stand
  workaround. Carry/timing tests from normally reached `(1,7)` and `(1,9)`
  did not prove `(1,8)->RIGHT`: down-seeded and up-seeded targeted probes to
  `(1,8)` drifted vertically to `(1,9)` / `(1,7)` before the right probe could
  enter `(2,8)`. A short wait (`wait_frames=8`) still drifted. The seeded
  helper's trace shows the vertical seed/carry can remain visible at arm time,
  so these runs are diagnostic rather than passability proof. Runtime blocks
  were cleared afterward; final state was map `0x0B` at `(2,9)`.
- ORDER / STATE FOLLOW-UP / STILL BLOCKED: a normal route from `(2,9)` to the
  Magic Key stand approached `(1,8)` from the south and then tried
  `(1,8)->RIGHT`; queued route, timeout retry, and seam retry all blocked, and
  `AUTO_WALK_BLOCKER_FOUND` again reported `add_blocked_edge:1,8,RIGHT` with
  no runtime block active. A north-side setup then routed to `(1,7)`, stepped
  down to a settled `(1,8)`, and direct `probe_edge:RIGHT` again
  raw-hold-timeout blocked into `(2,8)`. This reduces the odds that the
  missing path is simply "enter `(1,8)` from the right prior direction."
- TOOLING FOLLOW-UP / PATCHED, NEEDS RELOAD: `main.lua` now makes edge-probe
  input switching/release explicit by sending false for all D-pad directions
  instead of `joypad.set(1, {})`, matching the safer FCEUX patterns used by
  `auto_step.lua`, `route_manager.lua`, and `debug_tools.lua`. The targeted
  seeded probe also now aborts with `target_drifted` if the hero continues
  moving off the requested target tile during the neutral wait, so future
  stateful probe logs do not accidentally report an edge from the wrong origin.
- POST-RELOAD GUARD TEST / WORKING: after manual FCEUX Lua reload,
  `probe_edge_after_raw_to:DOWN,120,1,8,16,RIGHT` reached `(1,8)` but then
  drifted to `(1,9)` during the neutral wait. The new guard ended the run as
  `reason=target_drifted`, preventing a wrong-origin right probe from being
  logged as evidence for `(1,8)->RIGHT`.
- POST-GUARD MAGIC KEY HUNT / STILL UNRESOLVED: mid-carry raw tests from
  `(1,6)` with Down holds of 28, 32, 35, 36, 37, and 43 frames did not cross
  east into `(2,8)`. With live-only `(2,8).west` closed, route-frontier
  snapshots still show the same twelve bridge-to-target candidates and no
  hidden bridge candidates. A read-only source route still depends on the
  disputed `(1,8)->RIGHT` edge, while a true entrance-to-merchant autowalk
  again blocked there. Do not promote `(2,8).west` until the missing bridge or
  state condition is understood.
- CLEAN / PROMOTED: the return/reset route back toward the entrance found five
  ordinary false shortcuts with route failure plus same-origin probe evidence:
  `(8,9)->RIGHT` into `(9,9).west`, `(16,7)->RIGHT` into `(17,7).west`,
  `(16,8)->DOWN` into `(16,9).north`, `(16,7)->UP` into `(16,6).south`, and
  `(14,8)->DOWN` into `(14,9).north`. These are now in `map_reader.lua` with
  regression assertions in `test_map_reader.lua`.
- POST-RESTORE BRIDGE AUDIT / STILL UNRESOLVED: after the user restored a clean
  save state, fresh baseline was Rimuldar `(29,13)` with command/menu state
  clear. Clearing only the live-only `(2,8).west` edge let the source route walk
  from the town entrance to `(1,8)`, where it again blocked on
  `(1,8)->RIGHT`; same-origin `probe_edge:RIGHT` from `(1,8)` also timed out,
  so runtime `(2,8).west` was restored as review-only route protection. With
  that edge closed, `debug_route_frontier_skip_npcs:4,6` reported exactly the
  same twelve bridge-to-target candidates and no hidden bridge candidates.
  Eleven were already covered, and the remaining NPC-contaminated
  `(1,7)->RIGHT` candidate was later rechecked after Woman 2 moved away:
  `probe_edge:RIGHT` from cleanly reached `(1,7)` raw-hold-timeout blocked into
  `(2,7)`. The apparent `(1,5)->DOWN` blocker during an NPC-adjacent autowalk
  was invalid timing/NPC noise; a later direct `probe_edge:DOWN` from `(1,5)`
  moved through to `(1,7)`. Net: every known one-edge bridge into the Magic Key
  Merchant component is currently blocked from walked origins, so the remaining
  explanation is likely a transition/state/modeling issue rather than another
  obvious local false-wall bridge.
- FOLLOW-UP / RUNTIME ONLY: while checking the user's current screenshot
  position, the hero was standing at `(23,2)` even though source still decodes
  it as non-walkable. Neighbor inspection showed `(24,2)` and `(24,3)` are the
  already-modeled northeast strip passthroughs. Same-origin `probe_edge:RIGHT`
  from `(23,2)` moved through `(24,2)` and carried to `(25,2)`, confirming a
  real hidden upper-east pocket, but `debug_pathfind_to_skip_npcs:4,6` from
  `(25,2)` still found no path to the Magic Key stand while runtime
  `(2,8).west` was closed. `debug_route_frontier_skip_npcs:4,6` reported the
  same twelve bridge-to-target candidates and no hidden bridge candidates, so
  this pocket is not the missing key-shop connector.
- CONTROLLED REOPEN / STILL BLOCKED: clearing only the review-only
  `(2,8).west` runtime block and keeping the other reset-route blockers let the
  planner create a 53-step path from `(25,2)` to `(4,6)`. The first live run
  stopped at `(28,8)->LEFT` into `(27,8).east`; same-origin `probe_edge:LEFT`
  also blocked. Do not promote this edge yet: earlier reloaded manual evidence
  crossed `(28,8)<->(27,8)` and source/test comments intentionally keep
  `(27,8).east` open, so today's result is state-dependent route evidence only.
  With runtime `(27,8).east` added for the current pass, the route continued to
  `(1,8)` and again blocked on `(1,8)->RIGHT` into `(2,8).west` under queued
  route, timeout retry, and seam retry. Runtime `(2,8).west` was restored.
  Current conservative runtime overlay has seven entries, including the
  review-only `(27,8).east`; current position after the pass was `(1,8)`.

## 2026-06-29 Clean Rimuldar Magic Key Baseline

- CHECKPOINT / PUSHED: before the clean baseline, committed and pushed
  `f980728` (`Checkpoint Rimuldar route investigation`) with the existing
  route/map/tooling changes and handoff cleanup. Verification before that
  checkpoint passed: `luac -p main.lua map_reader.lua objects.lua
  debug_tools.lua test_debug_tools.lua test_map_reader.lua test_objects.lua`,
  `git diff --check`, `lua test_debug_tools.lua` (19 tests),
  `lua test_map_reader.lua` (55 tests), and `lua test_objects.lua` (85 tests).
  The debug-tools test race was fixed by letting tests override the command
  file path, so live FCEUX command polling no longer steals test commands from
  the real `dw_commands.txt`.
- CLEAN BASELINE / STILL BLOCKED: after the user reloaded save state, reloaded
  the Lua script, walked out of Rimuldar, and walked back in, the first fresh
  probe found the hero on the World Map at `(102,71)` with no runtime blocks.
  A single `simulate_raw_input:DOWN,30` entered Rimuldar at `(29,14)`, again
  with no runtime blocks and no active path target.
- STATIC PLANNER CHECK: from `(29,14)`, both `debug_pathfind_to:4,6` with live
  NPCs and `debug_pathfind_to_skip_npcs:4,6` found a 45-step route to the Magic
  Key stand `(4,6)`. Before adding any runtime closure,
  `debug_route_frontier_skip_npcs:4,6,80` reported `target_reachable=true`.
- LIVE MOVEMENT CHECK: `auto_walk_blocker:4,6` walked the route normally to
  `(1,8)`, then the next step `(1,8)->RIGHT` into `(2,8).west` failed under
  queued movement, timeout retry, and seam retry. The log emitted
  `AUTO_WALK_BLOCKER_FOUND` with `patch_command=add_blocked_edge:1,8,RIGHT`,
  `npc_blocked=false`, and `timing_suspect=false`.
- RUNTIME CLOSURE CHECK: adding runtime `add_blocked_edge:1,8,RIGHT` from the
  stopped `(1,8)` state made `debug_route_frontier_skip_npcs:4,6,80` report
  `target_reachable=false`, `bridge_candidates=12`, and
  `hidden_bridge_candidates=0`. The twelve bridge candidates were the same
  local blocked-directional set already reviewed; the only runtime candidate
  was the disputed `(1,8)->RIGHT` / `(2,8).west` edge.
- CLEANUP / NEXT: the runtime block was cleared after the check. Final live
  state was Rimuldar `(1,8)`, no active path, no runtime blocks. Do not promote
  `(2,8).west` into permanent map data yet: closing it isolates the known
  merchant-side component, while leaving it open produces a route that fails
  live. The best next move is no longer broad local candidate hunting; pivot to
  a manual route trace, a transition/state investigation, or explicitly mark
  the Magic Key merchant route unresolved until new state evidence appears.

## 2026-07-06 Cantlin FCEUX Input Trace Repro

- REPRO: with the diagnostic qfceux binary at
  `D:\modding\DragonWarrior1\.tools\fceux-build-tools\build-fceux\bin\qfceux.exe`,
  `survey_target:Old Man 4,park_npcs` reproduced input contamination in
  Cantlin at `(25,23)` on a queued-route `DOWN` attempt. Lua logged
  `INPUT_CONTAMINATION_CAPTURE command=survey_objects keys=LeftAlt joy=- bridge=- buttons=0x20`,
  immediately followed by `GAME_INPUT_AUTO_CLEAR ... before=0x20 after=0x00`
  and `GAME_INPUT_AUTO_NEUTRAL ... frames=30`.
- TRACE RESULT: `D:\modding\fceux-input-debug\dw_fceux_input_trace.log`
  showed raw host/gamepad input was `0x00` while Lua was issuing
  `joypad.set` Down. The key diagnostic window had `LUA_JOYPAD_SET
  frame=6655686 ... force_mask=0x20`, `UPDATE_GP ... raw=[00,00,00,00]
  before=[00,00,00,00] after=[20,00,00,00]`, then neutralization at
  `frame=6655699` with `force_mask=0x00` and `after=[00,00,00,00]`.
  A second Down burst began at `frame=6655707` and neutralized at
  `frame=6655720`. No nearby `QT_KEY`/`QT_GAMEPAD` event produced Down.
- LOW-LEVEL CONFIRMATION: when FCEUX internal `joy0=0x20`, the `$4016` trace
  serializes Down as `READ_GP ... bit_before=5 ... ret=0x01` / `JPREAD
  ... ret=0x41`. When Lua neutralizes, `UPDATE_INPUT` returns to
  `joy=[00,00,00,00]`. This points at Lua automation/retry input reaching
  the NES input port normally, not a physical controller or keyboard source.
- AFTER-STATE: the survey aborted cleanly, restored parked NPCs, and command
  polling remained alive. Follow-up `stop_survey stop_auto_walk report_position
  report_runtime_blocks report_path_state input_status:after_repro
  report_input_guard_state` reported Cantlin `(25,23)`, no runtime blocks,
  no active path, `$0047=0x00`, and only the known benign stale `LeftAlt`.

## 2026-07-06 FCEUX RAM Trace Build

- SOURCE PATCH: extended the diagnostic FCEUX tree at
  `D:\modding\fceux-input-debug` with watched CPU/Lua RAM-write tracing for
  canonical RAM `$0038-$004F`, named `$003C` as `MOVEMENT_STATE`, `$003D` as
  `MOVEMENT_SUBPIXEL`, and `$0047` as `BUTTONS_PRESSED`. The patch also adds
  `pc=0x%04X` to the existing `$4016`/gamepad serial trace lines.
- BUILD FIX: the first compile failed in `src\x6502.cpp` because the new
  `WrRAM` trace used `currFrameCounter` without a local declaration. Added
  `extern int currFrameCounter;` in that file.
- BUILD RESULT: direct CMake/MSBuild still fails from the Codex environment
  with duplicate `PATH` / `Path`, so the compile was run through a clean
  PowerShell wrapper. The wrapper did not return cleanly, but the build log
  shows `fceux.vcxproj -> ...\src\Release\fceux.exe`, stderr stayed empty,
  and no `cmake`, `MSBuild`, `cl`, or `link` process remained afterward.
- DEPLOYED BINARY: copied the new
  `.tools\fceux-build-tools\build-fceux\src\Release\fceux.exe` over
  `.tools\fceux-build-tools\build-fceux\bin\qfceux.exe`. The deployed binary
  is 3,864,576 bytes, SHA256
  `ECFB2571C8260750C1A3CA73590CDF97BCCE5F8AE759E49F8184660294679ADE`, and
  contains `RAM_WRITE`, `LUA_MEM_WRITE`, `BUTTONS_PRESSED`,
  `source=cpu_fast_ram`, `source=cpu_handler_low`, and `pc=0x%04X`.
- NEXT REPRO: launch the deployed diagnostic `qfceux.exe` with
  `FCEUX_DW_INPUT_TRACE=1`, load the Cantlin state and `main.lua`, then rerun
  the narrow repro (`survey_target:Old Man 4,park_npcs`) so the new trace can
  distinguish CPU/game RAM writes from Lua `memory.writebyte` cleanup.

## 2026-07-06 RAM Trace Live Repro Attempt

- BASELINE: diagnostic `qfceux.exe` was running from
  `.tools\fceux-build-tools\build-fceux\bin\qfceux.exe`. Command polling was
  alive but slowed; `launcher_probe:codex_lag_baseline` took about 8 seconds
  to match. Baseline state was Cantlin `(20,22)`, `$0047 buttons=0x00`, no
  runtime blocks, no active path, and only benign stale `LeftAlt`.
- TRACE LOAD: `D:\modding\fceux-input-debug\dw_fceux_input_trace.log` grew by
  about `1.3-1.6 MB` per 2 seconds while idle/near-idle. The tail was dominated
  by `RAM_WRITE` lines for watched RAM, including repeated `$0047`
  `old=0x00 new=0x00`. Treat the current trace build as too noisy for long
  live repro loops.
- PREFLIGHT: `report_survey_start:park_npcs` from `(20,22)` reported
  `status=viable`, `targets=21`, `reachable_area=128`, `open_exit_count=4`,
  `reachable_targets=21`, and `npc_mode=park_npcs`.
- REPRO ATTEMPT: `survey_target:Old Man 4,park_npcs` started cleanly but did
  not produce `INPUT_CONTAMINATION_CAPTURE` within a 240-second wait. It
  churned through timing-sensitive movement and route retries toward Old Man 4.
  Manual stop at frame `5280` produced `SURVEY_RESULT ... failure_class=
  command_timing_or_state_issue ... blocked_events=16 ... reason=manual_stop`;
  do not promote the suspected tiles from this run.
- RECOVERY: after `stop_survey stop_auto_walk`, state was Cantlin `(27,21)`,
  no runtime blocks, no active path, but visible input was still
  `joy1=down buttons=0x20`. `isolate_input:180` cleared the condition; final
  check at frame `5700` was Cantlin `(27,22)`, no runtime blocks, no active
  path, `joy1=-`, bridge `-`, and `$0047 buttons=0x00`.
- NEXT: quiet/rebuild the RAM trace before the next long repro. A better
  default is to log `$0047` only on changed or nonzero writes and put the broad
  `$0038-$004F` firehose behind `FCEUX_DW_INPUT_TRACE_VERBOSE=1`.

## 2026-07-06 Quiet RAM Trace Build

- SOURCE PATCH: updated `D:\modding\fceux-input-debug\src\input_trace.h` so
  default RAM-write tracing still watches `$0038-$004F`, but only logs
  `$0047` / `BUTTONS_PRESSED` when the old or new byte is nonzero or the byte
  changes. `FCEUX_DW_INPUT_TRACE_VERBOSE=1` still logs all watched RAM writes,
  including `$003C/$003D` movement state.
- BUILD RESULT: direct CMake/MSBuild remains unsuitable from the Codex
  environment because of duplicate `PATH` / `Path`. The clean wrapper again
  timed out externally, but
  `.tools\fceux-build-tools\quiet_ramtrace_build_stdout.log` shows
  `fceux.vcxproj -> ...\src\Release\fceux.exe`, stderr is empty, and no
  compiler/build process remained afterward.
- DEPLOYED BINARY: copied the rebuilt
  `.tools\fceux-build-tools\build-fceux\src\Release\fceux.exe` over
  `.tools\fceux-build-tools\build-fceux\bin\qfceux.exe`. SHA256 is
  `D3AEBB34138EF9FC026FAF8F90BEF9867B3434AAF6B3948474359A1D7B6A520F`.
- NEXT REPRO: launch the deployed diagnostic with only
  `FCEUX_DW_INPUT_TRACE=1` and without
  `FCEUX_DW_INPUT_TRACE_VERBOSE=1`; then rerun
  `survey_target:Old Man 4,park_npcs`.

## 2026-07-07 Quiet Trace Cantlin Repro

- BASELINE: diagnostic `.tools\fceux-build-tools\build-fceux\bin\qfceux.exe`
  was running with SHA256
  `D3AEBB34138EF9FC026FAF8F90BEF9867B3434AAF6B3948474359A1D7B6A520F`.
  `launcher_probe:codex_quiet_baseline` confirmed command polling. Cantlin
  baseline was `(20,22)`, `$0047 buttons=0x00`, no runtime blocks, no active
  path, and only benign stale `LeftAlt`.
- PREFLIGHT: `report_survey_start:park_npcs` reported `status=viable`,
  `targets=21`, `reachable_area=128`, and `reachable_targets=21`.
- REPRO: `survey_target:Old Man 4,park_npcs` reproduced the contamination at
  frame `20166` while probing from `(24,23)` toward `UP`. The mod log reported
  `INPUT_CONTAMINATION_CAPTURE command=survey_objects keys=LeftAlt joy=-
  bridge=- buttons=0x11`, followed by `GAME_INPUT_AUTO_CLEAR before=0x11
  after=0x00` and `GAME_INPUT_AUTO_CLEAR_CHECK ... buttons=0x00`.
- TRACE RESULT: `D:\modding\fceux-input-debug\dw_fceux_input_trace.log`
  showed Lua forcing `force_mask=0x10` for the movement direction. At FCEUX
  frame `6642700`, `QT_GAMEPAD ... pads=[01,00,00,00]` appeared and
  `LUA_READ_JOYPAD ... input=0x01 ... output=0x11` merged the raw native A
  bit with Lua's direction. There was no nearby `QT_KEY` event in the tail,
  so the raw A bit was probably stale native keyboard-backed GamePad.0 state.
- CONFIG FINDING: direct `.tools` launch was using
  `.tools\fceux-build-tools\build-fceux\bin\fceux.cfg`, which still had
  `SDL.Input.GamePad.0.DeviceType = Keyboard`, `SDL.ToggleMenu = 0`,
  `SDL.Hotkeys.MainMenuHide = Alt+/`, and
  `SDL.Hotkeys.FullScreen = Alt+Return`. This bypassed the normal launcher
  mitigations documented in `launch_dw.ps1`.
- MITIGATION APPLIED: patched the `.tools` `fceux.cfg` so
  `SDL.Input.GamePad.0.DeviceType = None`, `SDL.ToggleMenu = 1`, and both
  Alt hotkeys are blank. This affects the next FCEUX start; the currently
  running emulator had already loaded the old config.
- RELOAD FOLLOW-UP: after the user reloaded back to the Cantlin save state,
  `launcher_probe:codex_after_config_reload` confirmed command polling and
  Cantlin `(20,22)` with `$0047 buttons=0x00`, but the `.tools` config had
  reverted/restored to `SDL.Input.GamePad.0.DeviceType = Keyboard`,
  `SDL.ToggleMenu = 0`, `SDL.Hotkeys.MainMenuHide = Alt+/`, and
  `SDL.Hotkeys.FullScreen = Alt+Return`. Conditions are good for reproducing
  the old path, but not for judging the config mitigation. Next clean test
  should launch the diagnostic binary via `launch_dw.ps1 -FceuxPath` or add
  source-level `DTestButton` source tracing/suppression.
- AFTER-STATE: `simulate_input:B` closed the command menu. Final live check
  was Cantlin `(24,23)`, `$0047 buttons=0x00`, no runtime blocks, no active
  path, and `menu_active=false`.

## 2026-07-07 Launcher Config And Self-Input Guard

- VERIFY: user launched through `launch_dw.ps1`; live process was the
  diagnostic `.tools\fceux-build-tools\build-fceux\bin\qfceux.exe`. The
  `.tools` runtime config still showed `SDL.Input.GamePad.0.DeviceType = None`,
  `SDL.ToggleMenu = 1`, and blank Alt menu/fullscreen hotkeys while FCEUX was
  running. This supports using the launcher as the durable pre-start mitigation
  because direct FCEUX exits/restarts can rewrite the local config.
- LIVE REPRO: `survey_target:Old Man 4,park_npcs` no longer reproduced the
  direct-launch raw `A` merge. It eventually aborted at Cantlin `(25,23)` on a
  queued-route `DOWN` timeout: `INPUT_CONTAMINATION_CAPTURE ... buttons=0x20`,
  then `GAME_INPUT_AUTO_CLEAR ... after=0x00`.
- TRACE RESULT: `D:\modding\fceux-input-debug\dw_fceux_input_trace.log` showed
  raw host/gamepad input stayed `0x00`; Lua forced `Down` (`force_mask=0x20`),
  FCEUX delivered it through `$4016`, the ROM wrote `$0047`, and Lua later
  neutralized. The remaining `$0047=0x20` was therefore self-injected route
  input sampled during route-block cleanup, not a physical/controller redirect.
- CODE FIX: `debug_tools.input_contamination_refusal` now accepts contextual
  route-block options and ignores only timing-suspect `route_blocked` samples
  where `$0047` exactly matches the direction just injected. `map_survey.lua`
  and `route_manager.lua` pass that context; startup, idle/tick, wrong-button,
  raw `A`, and raw `Start` contamination paths still refuse/abort.
- VERIFY: `luajit -b debug_tools.lua NUL`, `luajit -b route_manager.lua NUL`,
  and `luajit -b map_survey.lua NUL` passed. `luajit test_route_manager.lua`
  passed 103 tests. `luajit test_map_survey.lua` passed 53 tests.
  `luajit test_debug_tools.lua` passed 27 tests when run with
  `DW_TEST_TMPDIR` pointed at a workspace-local temp directory; a filtered run
  also passed `input_guard_allows_timing_suspect_route_blocked_self_direction`.
- NEXT: manually reload `main.lua` in FCEUX, then re-run the narrow
  `survey_target:Old Man 4,park_npcs` from a clean Cantlin save state. Expect
  `INPUT_CONTAMINATION_IGNORED ... reason=route_blocked_self_input` instead of
  `SURVEY_ABORT reason=input_contaminated` for the self-injected `DOWN`
  timing sample; any raw `A`/wrong-button recurrence should still abort and be
  treated as a separate input-source bug.
- POST-RELOAD HARD-LOCK: after the user manually reloaded `main.lua`, command
  polling stayed live at Cantlin `(25,23)` and visible input was clean
  (`joy1=-`, bridge `-`, `$0047=0x00`). The pre-recovery movement snapshot
  still had `$003C/$003D = 0x08/0x08`; `reset_movement_state` cleared those to
  `0x00/0x00`, and `clear_game_input` / `isolate_input:30` left `$0047=0x00`.
  A corrected quoted `simulate_raw_input:A,12` reached Lua/FCEUX
  (`Queued raw joypad: A for 12 frames`, `joy1=A`), but the normal field
  command menu still did not open (`menu_active=false`). This confirms the
  deeper hard-lock persists below the mod-visible input layers; save-state
  restore is the right recovery before further Cantlin surveying.

## 2026-07-07 Post-Restore Self-Input Filter And Controller-Poll Wedge

- BASELINE: after save-state restore, `launcher_probe:post_restore_cantlin_baseline`
  confirmed command polling. Cantlin was `map=0x0A` at `(20,22)`, `$0047
  buttons=0x00`, no menu/dialogue, no runtime blocks, and no active path.
  `report_survey_start:park_npcs` was viable with `targets=21`,
  `reachable_area=128`, and all four exits open.
- FOCUSED REPRO: `survey_target:Old Man 4,park_npcs` started from `(20,22)`.
  It churned through multiple route retries and reached the familiar `(25,23)`
  pocket. At frame `26108`, queued-route `DOWN` produced `$0047=0x20`; the new
  guard correctly logged `INPUT_CONTAMINATION_IGNORED ... reason=route_blocked_self_input`
  for both `survey_objects` and `auto_walk`, then continued instead of
  aborting.
- SECOND-STAGE WEDGE: the follow-up seam retry from `(25,23)` toward `DOWN`
  timed out with `movement_started=false`. At frame `26251`, the guard captured
  `keys=LeftAlt joy=- bridge=- buttons=0x20`, with movement bytes
  `$003C/$003D = 0x08/0x08`, logged `GAME_INPUT_AUTO_CLEAR ... before=0x20
  after=0x00`, and the delayed `GAME_INPUT_AUTO_CLEAR_CHECK` still showed
  `$0047 buttons=0x00`.
- RECOVERY TEST: despite `$0047=0x00`, a raw `simulate_raw_input:A,12` at
  frame `28260` reached Lua/FCEUX but did not open the field command menu.
  `reset_movement_state:post_auto_clear_raw_a_failed` then cleared
  `$003C/$003D` from `0x08/0x08` to `0x00/0x00`; a second raw
  `simulate_raw_input:A,12` at frame `30780` still did not open the menu.
  Final snapshot at frame `32160` was internally clean from Lua's view:
  `(25,23)`, `$0047=0x00`, `$003C/$003D=0x00/0x00`, no runtime blocks, no
  active path.
- FCEUX TRACE RESULT: `D:\modding\fceux-input-debug\dw_fceux_input_trace.log`
  showed the raw `A` injections were present in FCEUX (`LUA_READ_JOYPAD ...
  output=0x01`, `UPDATE_INPUT joy=[01,00,00,00]`) for frames
  `6638765..6638777` and `6641285..6641297`, but the tail segment showed no
  `B4016`, `STROBE_GP`, `READ_GP`, or `JPREAD` during those raw-A windows.
  This means the input is not being lost in the FCEUX/Lua merge path; the ROM
  appears to have stopped polling `$4016` in the wedged state.
- CPU TOOLING: `report_cpu_state[:TAG]` was implemented to capture the wedged
  ROM PC/register/opcode state without disturbing gameplay.
- CPU CAPTURE: after reload while still wedged, `report_cpu_state:fceux_wedged`
  and `report_cpu_state:fceux_wedged_2` caught the ROM at `$B9F8` and `$B9ED`.
  Live opcode bytes were `$B9F8: 4C ED B9` (`JMP $B9ED`) and
  `$B9ED: C0 00 F0` (`CPY #$00; BEQ ...`). The relevant RAM window showed
  `$004E=0x2A`, `$004F=0x81`, `$0047=0x00`, and `$003C/$003D=0x00/0x00`.
- ROOT-CAUSE SHAPE: ROM bank 0 at `$B9E9-$B9F8` loads `Y` from `$004E`,
  writes `0xF0` to `$0200,Y`, increments `Y` by 4, and loops until `Y==0`.
  Starting at `$004E=0x2A` is impossible to terminate because `0x2A mod 4`
  stays 2 forever. This explains why FCEUX/Lua can deliver input while the
  ROM never polls `$4016`: the game is trapped in its sprite-OAM clear loop.
- SOURCE FOLLOW-UP: `report_oam_offset[:TAG]` and
  `watch_oam_offset[:on|off|status|TAG]` are implemented in
  `debug_tools.lua`. A first live arm proved the hook survived save-state
  restore, but `$004E` is a normal hot scratch/OAM cursor byte: it logged
  79,902 writes before being disarmed, including many temporary misaligned
  values that were later corrected. Do not use verbose logging for the repro.
- QUIET WATCHER UPDATE: `watch_oam_offset[:TAG]` now keeps a recent-write ring
  buffer silently and logs only `OAM_OFFSET_STUCK` if the CPU is actually at
  `$B9ED`/`$B9F8` with a non-terminating `$004E` value. Verbose per-write
  logging moved to `watch_oam_offset_verbose[:TAG]` for tiny captures only.
  Verification passed: `luajit -b debug_tools.lua NUL`, focused
  `DW_TEST_FILTER=oam_offset luajit test_debug_tools.lua`, full
  `luajit test_debug_tools.lua` with 32 tests, and `git diff --check`.
- NEXT: manually reload `main.lua`, restore the clean Cantlin save state if
  the reload disturbs it, then arm quiet `watch_oam_offset:repro` before
  reproducing `survey_target:Old Man 4,park_npcs`. The target evidence line is
  `OAM_OFFSET_STUCK tag=repro ... value=0x2A ... recent=...`; runtime PC/write
  context should decide which normal `$004E` writer leaves the final bad value.

## 2026-07-07 OAM Root Cause And Parking Fix

- CLEAN REPRO CAPTURE: after the user restored the Cantlin save state, quiet
  `watch_oam_offset:repro` was armed from a clean `(20,22)` baseline and
  `survey_target:Old Man 4,park_npcs` reproduced the hard lock at frame
  `10601`. The key log line was
  `OAM_OFFSET_STUCK tag=repro ... value=0x2A ... pc=0xB9F8 ...
  diagnosis=misaligned_offset_will_never_exit_B9ED_B9F8`.
- WRITER CONTEXT: the recent write ring ended with the ROM object-draw writer
  logged as `pc=0xB972 value=0x2A` after the `STX $4E` at `$B970`. Since
  `$2A / 3 = 14`, the bad offset maps to NPC object-table slot 14. A later
  `report_npcs` after restore showed slot 14 is `Merchant 6`; the slot had
  already been restored by then, so this names the table slot, not the live
  parked bytes during the lock.
- ROOT CAUSE: parked-NPC survey used low coordinate `(31,31)` for non-target
  NPCs. The Dragon Warrior renderer does not treat that as inactive; it skips
  only slots whose low x/y coordinate bits are both zero. During parked-NPC
  survey, those offscreen-but-rendered slots can drive the object draw loop and
  leave `$004E` as a non-multiple-of-4 object-table offset. The subsequent
  `$B9ED-$B9F8` OAM clear loop increments by 4 until `Y==0`, so `$004E=0x2A`
  can never terminate.
- SOURCE FIX: `map_survey.lua` now parks non-target NPCs at low coordinate
  `(0,0)`, and `route_manager.lua` does the same for proactive and reactive
  autowalk NPC parking while preserving each raw byte's high bits. Tests were
  updated in `test_map_survey.lua` and `test_route_manager.lua`.
- VERIFY: `git diff --check`, `luajit -b map_survey.lua NUL`,
  `luajit -b route_manager.lua NUL`, `luajit test_map_survey.lua`, and
  `luajit test_route_manager.lua` passed. `luajit test_debug_tools.lua` also
  passed 32 tests when run with `DW_TEST_TMPDIR` pointed at `.tmp-tests`; on
  this Windows LuaJIT path the default `/tmp` fallback is not writable.
- CONTAMINATED FOLLOW-UP: after the user reloaded `main.lua`, a baseline probe
  still reported Cantlin `(25,23)`, `pc=$B9F6/$B9F8`, and `$004E=0x2A`. That
  proves the script reload alone did not reset the ROM out of the prior OAM
  loop. `watch_oam_offset:off` disarmed the stale watcher.
- LIVE VALIDATION: after the user restored the clean Cantlin save state,
  `launcher_probe:parking_fix_clean` confirmed a clean `(20,22)` baseline with
  `$0047 buttons=0x00`. `report_oam_offset:parking_fix_clean` reported
  `$004E=0x60`, `aligned=true`, `reaches_zero=true`, and the quiet watcher
  armed with `stuck_reports=0`. Re-running
  `survey_target:Old Man 4,park_npcs` did not produce `OAM_OFFSET_STUCK` and
  did not hard-lock controls; the survey failed as a normal route issue with
  `state_issues=1`.
- ROUTE FOLLOW-UP: after the parking fix held, nine Cantlin Old Man 4
  lower-pocket seams reproduced as route failures and were confirmed with
  same-origin `probe_edge` checks:
  `(20,23)->RIGHT` into `(21,23).west`,
  `(20,24)->RIGHT` into `(21,24).west`,
  `(22,24)->LEFT` into `(21,24).east`,
  `(21,25)->UP` into `(21,24).south`,
  `(22,24)->UP` into `(22,23).south`,
  `(22,24)->RIGHT` into `(23,24).west`,
  `(22,25)->RIGHT` into `(23,25).west`, and
  `(23,26)->UP` into `(23,25).south`, and
  `(24,25)->UP` into `(24,24).south`. These were promoted to
  `MAP_DIRECTIONAL_BLOCKS[0x0A]` in `map_reader.lua` with regression coverage
  in `test_map_reader.lua`.
- POST-RELOAD CHECK: after the user reloaded `main.lua`, command polling was
  live at Cantlin `(23,26)`, `RUNTIME_BLOCKS map=0x0A none`, and
  `$0047 buttons=0x00`. The static model routed around the eight existing
  seams, then same-origin probing confirmed `(24,25)->UP` into
  `(24,24).south` as the ninth seam. Because that ninth seam was patched after
  the reload, FCEUX needs one more manual `main.lua` reload before the current
  source model is fully live.
- NEXT: manually reload `main.lua` again so FCEUX picks up the ninth
  `map_reader.lua` seam, confirm `report_runtime_blocks` is clear, then retry
  the narrow `survey_target:Old Man 4,park_npcs` or a direct route to the Old
  Man 4 stand.

## 2026-07-08 Cantlin Locked Door Pinning

- RESUME RECOVERY: after the Codex app restart, the pending manual OPEN at
  `(4,20)` was recovered with `verify_door_after`. The armed verifier had
  `stand=(4,20) dir=down expected_door=(4,21)`, and the result confirmed
  `expected_present=true`, keys `3 -> 2`, and door RAM slot `3=(4,21)`.
- FINAL DOOR: the remaining guide-backed icon door was not the north stand
  `(8,24)` facing down; that verifier churned and was stopped cleanly. The
  valid stand was `(7,25)` facing east toward `(8,25)`. Manual OPEN played the
  door sound, and `verify_door_after` confirmed `expected_present=true`,
  keys `2 -> 1`, and door RAM slot `4=(8,25)`.
- PROMOTED: `map_reader.lua` now models all five Cantlin door cells:
  `(26,9)`, `(15,25)`, `(14,25)`, `(4,21)`, and `(8,25)`. `objects.lua`
  exposes matching door objects, including `Western Shop North Door` and
  `Western Shop East Door`.
- FINAL LIVE STATE: Cantlin `(7,25)`, keys `1`, door RAM
  `0=(26,9) 1=(15,25) 2=(14,25) 3=(4,21) 4=(8,25)`,
  `RUNTIME_BLOCKS map=0x0A none`, and `buttons=0x00`.
- NEXT: manually reload `main.lua` in FCEUX before judging the latest door
  object/path data live.

## 2026-07-08 Cantlin Service Route Start

- User restored an all-doors-open Cantlin save state. Fresh baseline:
  `POSITION map=0x0A(Cantlin) x=8 y=25`, door RAM
  `0=(26,9) 1=(15,25) 2=(14,25) 3=(4,21) 4=(8,25)`, and
  `RUNTIME_BLOCKS map=0x0A none`.
- Practical town-entry origin is `(15,1)`. Forced `(15,0)` remains a boundary
  start artifact and should not be used as the route origin until separately
  decoded.
- COMPLETED SERVICE ROUTE: entrance `(15,1)` to `Merchant 4` interaction tile
  `(8,5)`. TALK from `(8,5)` facing north opened:
  `Welcome to the traveler's Inn. Room and board is 100 GOLD per night.`
- PROMOTED after same-origin `probe_edge_verify:...,3` results:
  `(13,1).east`, `(13,2).east`, `(13,3).east`, `(13,4).east`,
  `(13,5).east`, `(13,6).east`, `(13,7).east`, `(13,8).east`,
  `(20,2).north`, `(21,2).north`, `(22,2).north`, `(18,2).west`,
  and `(18,6).west`.
- NOT PROMOTED: `(15,2).north` became noisy and moved during full-route
  attempts. Merchant 2 survey suspects near `(21,5)`, `(21,6)`, `(22,7)`,
  `(23,5)`, and `(23,6)` came from a timed-out/manual-stop survey and need
  direct same-origin verification before any source patch.
- Source patch: `map_reader.lua` `MAP_DIRECTIONAL_BLOCKS[0x0A]` plus
  `test_map_reader.lua` regression coverage. `luajit.exe test_map_reader.lua`
  passes after the patch. Reload `main.lua` in FCEUX before live retest.

## 2026-07-08 Cantlin Merchant 2 Route Continuation

- LABEL FIX: `objects.lua` now labels Cantlin `Merchant 4` as `Inn` with
  counter stand `(8,5)` facing north, matching the service-label format used by
  other towns' inns. `report_npcs` confirmed the live object name as `Inn`.
- MERCHANT 2 PROMPT PROOF: while adjacent to `Merchant 2`, raw TALK opened:
  `We deal in weapons and armor. Dost thou wish to buy anything today?`
  `objects.lua` now labels this moving service NPC as `Weapons Merchant` while
  keeping adjacent-NPC routing. The durable route is not finished yet.
- PROMOTED MERCHANT 2 ROUTE EDGES: same-origin
  `probe_edge_verify:...,3` checks confirmed all of these blocked-only seams:
  `(16,1).west`, `(19,2).north/south`, `(20,2).south`,
  `(23,2).north`, `(21,3).west`, `(21,4).west`, `(21,5).west`,
  `(21,6).west`, `(20,7).north`, `(19,7).north`,
  `(18,3).east/south/west`, and `(18,6).east/north`.
  These extend the earlier service-route blockers `(13,1..8).east`,
  `(20,2).north`, `(21,2).north`, `(22,2).north`, `(18,2).west`, and
  `(18,6).west`.
- POST-RELOAD FOLLOW-UP: after the user reloaded `main.lua`, live route hunts
  continued from the post-source baseline and promoted these additional
  same-origin `probe_edge_verify:...,3` blockers:
  `(23,4).east`, `(23,5).east`, `(23,6).east`, `(23,7).east/south`,
  `(22,7).south`, `(21,7).south`, `(20,7).south`, `(19,7).south`,
  `(18,7).south/west`, `(18,2).north`, `(23,3).east`, and
  `(23,2).east`. Each was mirrored into runtime with `add_blocked_edge`
  because source edits after the reload are not live until the next manual
  script reload.
- MERCHANT 2 COMPONENT CHECK: with runtime blockers active, Merchant 2 at
  `(22,5)` produced `Debug pathfind adjacent ... No path found`. A follow-up
  `debug_route_frontier_skip_npcs:22,5,80` from `(24,2)` reported
  `target_reachable=false`, `bridge_candidates=34`, and
  `hidden_bridge_candidates=0`; the top bridge candidates were already
  confirmed runtime/source blockers such as `(24,5)->LEFT`, `(24,4)->LEFT`,
  `(24,6)->LEFT`, and `(22,8)->UP`.
- COUNTER-STAND NEGATIVE PROOF: route to public-side `(24,5)` succeeded, then
  raw alignment held Merchant 2 at `(22,4)` while the hero stood at `(24,4)`.
  Raw `LEFT`, command-menu `TALK` returned `There is no one there`, so do not
  promote `(24,4)` facing west as a fixed Weapons Merchant counter stand.
- CURRENT LIVE CHECKPOINT: FCEUX is at Cantlin `(24,4)`, menu closed,
  Merchant 2 / `Weapons Merchant` frozen at `(22,4)`, and
  `RUNTIME_BLOCKS map=0x0A count=12` mirrors the post-reload source blockers.
  Reload `main.lua` before relying on source-only map data, or continue by
  testing another Cantlin service route rather than forcing a fixed Merchant 2
  counter stand.

## 2026-07-09 Cantlin Service Route Reload Follow-Up

- User reloaded `main.lua`; fresh baseline from `(24,4)` had all five Cantlin
  doors open and `RUNTIME_BLOCKS map=0x0A none`.
- Merchant 2 / `Weapons Merchant` at `(22,6)` still had no adjacent path from
  the public component. Frontier check reported `hidden_bridge_candidates=0`,
  so no new bridge candidate was promoted.
- Entrance return from `(24,4)` toward `(15,1)` found and verified
  `(16,1).east` from `(17,1)->LEFT`.
- Merchant 1 route work then promoted these same-origin verified blockers:
  `(8,4).south`, `(11,4).south`, `(11,8).south`, `(12,8).south`,
  `(10,8).south/west`, `(10,7).west`, `(9,6).south`, `(6,5).east`,
  `(7,6).north`, and `(9,6).north`.
- With the runtime overlay active, the route chain completed to `(4,9)`, then
  reached Merchant 1 stand probes `(8,7)` and `(8,6)`. No prompt proof was
  collected: Merchant 1 moved from `(8,6)` to `(8,5)` and then to `(12,5)`
  before a stable TALK attempt.
- CURRENT LIVE CHECKPOINT: Cantlin `(8,6)`, NPCs frozen, menu closed, runtime
  overlay `RUNTIME_BLOCKS map=0x0A count=10` cells. `(9,6)` now has both
  `north` and `south` runtime directions. Reload `main.lua` to absorb source
  blockers if runtime is cleared.
- NEXT: use object-selected autowalk / targeted survey for moving Merchant 1,
  or pivot to more static service NPCs (`Merchant 5`, `Merchant 6`,
  `Merchant 7`, `Merchant 3`).

## 2026-07-09 Cantlin Merchant 5 Route Pass

- Reload baseline after user reloaded `main.lua`: `POSITION map=0x0A(Cantlin)
  x=8 y=6`, door RAM `0=(26,9) 1=(15,25) 2=(14,25) 3=(4,21) 4=(8,25)`,
  `RUNTIME_BLOCKS map=0x0A none`, menu closed.
- Target: Merchant 5 at `(2,12)`. Initial adjacent plan from `(8,6)` was
  `5 south, 6 west` to north stand `(2,11)`, facing south.
- CLEAN / PROMOTED with same-origin `probe_edge_verify:...,3`:
  `(8,11).north`, `(2,11).north`, `(3,11).east`, `(3,12).east`,
  `(3,13).east`, `(3,14).east`, `(3,15).east`, `(2,15).south`, and
  `(3,15).south`.
- RUNTIME: mirrored with `add_blocked_edge`; final runtime overlay is
  `RUNTIME_BLOCKS map=0x0A count=8`, with `(3,15)` carrying both `east` and
  `south`.
- CURRENT LIVE CHECKPOINT: Cantlin `(3,16)`, NPCs frozen, menu closed. Latest
  non-moving planner for Merchant 5 reports `Approach: 2 west, 3 north, 1
  east`, face north, targeting stand `(2,13)` beside Merchant 5 `(2,12)`.
- NEXT: after reload/runtime sync, retry `auto_walk_blocker:2,13` from
  `(3,16)` or use the adjacent planner again if the live position changes.

## 2026-07-09 Cantlin Merchant 5 Route Continuation

- Continued from `(3,16)` using `auto_walk_blocker:2,13` and mirrored each
  newly verified source-only edge into runtime with `add_blocked_edge`.
- CLEAN / PROMOTED with same-origin `probe_edge_verify:...,3`:
  `(1,16).east` from `(2,16)->LEFT`, `(1,17).east` from `(2,17)->LEFT`,
  `(2,18).north` from `(2,17)->DOWN`, `(3,18).north` from `(3,17)->DOWN`,
  `(4,18).north` from `(4,17)->DOWN`, `(3,11).north` from `(3,10)->DOWN`,
  `(1,11).north` from `(1,10)->DOWN`, `(5,15).north` from `(5,14)->DOWN`,
  `(6,15).north` from `(6,14)->DOWN`, and `(7,15).north` from
  `(7,14)->DOWN`.
- Each verifier result was `classification=confirmed_blocked`, `moved=0
  blocked=3`, with no drift, map change, interruption, or teleport artifact
  suspicion.
- CURRENT LIVE CHECKPOINT: Cantlin `(7,14)`, NPCs frozen, menu closed, runtime
  overlay `RUNTIME_BLOCKS map=0x0A count=10` for the continuation edges.
- NEXT: reload `main.lua` to absorb this source batch, then retry
  `auto_walk_blocker:2,13` from `(7,14)`. If continuing without reload, the
  runtime overlay already includes the continuation edges.

## 2026-07-09 Cantlin Merchant 5 Second Reload Continuation

- User reloaded `main.lua`; baseline confirmed Cantlin `(7,14)`, all five
  door slots still open, menu closed, and `RUNTIME_BLOCKS map=0x0A none`.
- Continued `auto_walk_blocker:2,13` and mirrored each newly verified
  source-only edge into runtime with `add_blocked_edge`.
- CLEAN / PROMOTED with same-origin `probe_edge_verify:...,3`:
  `(8,15).north` from `(8,14)->DOWN`, `(8,18).east` from `(9,18)->LEFT`,
  `(1,18).south` from `(1,19)->UP`, `(2,18).south` from `(2,19)->UP`,
  `(3,18).south` from `(3,19)->UP`, `(5,18).south` from `(5,19)->UP`, and
  `(4,18).south` from `(4,19)->UP`.
- Each verifier result was `classification=confirmed_blocked`, `moved=0
  blocked=3`, with no drift, map change, interruption, or teleport artifact
  suspicion. The `(5,19)->UP` route had an earlier settle drift before reroute,
  but the same-origin verifier itself was clean.
- CURRENT LIVE CHECKPOINT: Cantlin `(4,19)`, NPCs frozen, menu closed, runtime
  overlay `RUNTIME_BLOCKS map=0x0A count=7` for the newest edges.
- Latest parked-NPC planner to Merchant 5 `(2,12)` still reports a route to
  stand `(2,13)`: `2 east, 1 north, 5 west, 5 north, 1 east`, face north.
- NEXT: reload `main.lua` to absorb this source batch, then retry
  `auto_walk_blocker:2,13` from `(4,19)`. If continuing without reload, the
  runtime overlay already includes the newest edges.

## 2026-07-09 Cantlin Merchant 5/6 Follow-Up

- Started from the user's next reload with the hero at Cantlin `(4,19)`.
  The command menu was open on `TALK`; `simulate_raw_sequence:B,24,60` closed
  it without using `clear_input`.
- Merchant 5 `(2,12)` follow-up:
  - Promoted same-origin `probe_edge_verify:...,3` blockers:
    `(6,18).south`, `(7,18).south`, `(8,18).south`, `(8,17).east`,
    `(8,16).east`, `(8,15).east`, `(5,18).north`, `(6,18).north`,
    `(7,18).north`, `(8,17).west`, `(8,16).west`, `(7,15).south`,
    `(6,15).south`, `(5,16).east`, `(5,16).south`, `(5,15).west`,
    and `(5,16).west`.
  - `debug_pathfind_adjacent_skip_npcs:2,12` found no adjacent public route,
    and `debug_route_frontier_skip_npcs:2,13,30` had
    `hidden_bridge_candidates=0`.
  - TALK from `(4,12)` facing west produced only:
    `Come buy my radishes! They are fresh and cheap. Buy thy radishes today!`
    Promoted object override: cell `(2,12)` is `Radish Merchant`,
    `service=false`.
- Merchant 6 `(7,12)` route follow-up from practical entrance `(15,1)`:
  - Promoted same-origin `probe_edge_verify:...,3` blockers
    `(14,11).east` from `(15,11)->LEFT`, `(7,11).north` from
    `(7,10)->DOWN`, `(15,12).north` from `(15,11)->DOWN`,
    `(8,12).east` from `(9,12)->LEFT`, `(8,11).east` from
    `(9,11)->LEFT`, and `(7,11).west` from `(6,11)->RIGHT`.
  - After runtime injection, `debug_pathfind_adjacent_skip_npcs:7,12` chose
    stand `(8,12)` via `9 south, 6 west, 3 south, 1 west, 1 north`, facing
    west.
- Live stop condition:
  - Current live position: Cantlin `(15,1)`.
  - NPCs frozen; command menu closed.
  - Runtime overlay: `RUNTIME_BLOCKS map=0x0A count=16`, including
    `7,11(north,west)`, `8,11(east)`, `8,12(east)`, `14,11(east)`,
    and `15,12(north)`.
  - Auto-walk is blocked before planning because `PREV.dialogue="16Bill"`
    remains cached even though no real menu/dialogue is active.
- Source fix made this pass:
  - `field_action_guard.lua` ignores active dialogue when `dialogue_text` is a
    passive status/name fragment.
  - `main.lua` passes `dialogue_text = PREV.dialogue` into the field-action
    guard state.
  - `text.lua` classifies short digit-prefixed name fragments such as
    `16Bill` as passive field status noise.
  - Regression tests added to `test_field_action_guard.lua` and
    `test_text.lua`.
- Next pickup after manual FCEUX `main.lua` reload:
  1. Confirm baseline:
     `bash ./dw_commands.sh --replace --timeout 25 --wait "UPPER_STATE" report_upper_dialogue_state report_menu_state report_position report_runtime_blocks`
  2. Re-check Merchant 6 adjacency:
     `bash ./dw_commands.sh --replace --timeout 25 --wait "Debug pathfind adjacent" freeze_npcs 'debug_pathfind_adjacent_skip_npcs:7,12' report_position report_runtime_blocks`
  3. If it still chooses `(8,12)`, route/probe:
     `bash ./dw_commands.sh --replace freeze_npcs 'auto_walk_blocker:8,12' report_position report_path_state report_runtime_blocks`

## 2026-07-09 Cantlin Merchant 6 Counter Resolution

- User reloaded `main.lua`; fresh baseline from Cantlin `(15,1)` had menu
  closed, no lower dialogue, and `RUNTIME_BLOCKS map=0x0A none`.
- Merchant 6 `(7,12)` adjacent-route blockers promoted with same-origin
  `probe_edge_verify:...,3`, each `classification=confirmed_blocked`,
  `moved=0 blocked=3`, no NPC clutter:
  `(8,13).east` from `(9,13)->LEFT`, `(6,11).north` from `(6,10)->DOWN`,
  `(8,13).south` from `(8,14)->UP`, `(7,13).south` from `(7,14)->UP`,
  `(6,12).west` from `(5,12)->RIGHT`, `(6,11).west` from `(5,11)->RIGHT`,
  `(6,13).west` from `(5,13)->RIGHT`, and `(6,13).south` from
  `(6,14)->UP`.
- After runtime injection, `debug_pathfind_adjacent_skip_npcs:7,12` returned
  `No path found`; `debug_route_frontier_skip_npcs:7,12,40` reported
  `target_reachable=false`, `bridge_candidates=12`,
  `hidden_bridge_candidates=0`. The top bridge entries were the newly
  confirmed runtime blockers plus prior modeled directional blockers.
- Counter-stand tests:
  `(9,12)` facing west -> `There is no one there`.
  `(7,14)` facing north -> `There is no one there`.
  `(5,12)` facing east -> `Welcome. We deal in tools. What can I do for thee?`
  with merchant state `mode=action`, selection `Buy`.
- Source updates: `objects.lua` labels `Merchant 6` as `Tool Merchant` and
  routes the service to `(5,12)` facing east. `main.lua` / `text.lua` now avoid
  storing lower-dialogue plus stale command/status overlays as the processed
  upper marker; live evidence included
  `COMMAND BillTALK ... LV 16 STATUS ITEM`.
- Current live checkpoint after closing the shop/farewell: Cantlin `(5,12)`,
  NPCs frozen, command menu closed, no lower dialogue, merchant inactive,
  runtime overlay count 5:
  `6,11(north,west)`, `6,12(west)`, `6,13(south,west)`,
  `7,13(south)`, `8,13(east,south)`.
- NEXT: manually reload `main.lua`, then route to Services -> `Tool Merchant`;
  expected public stand is `(5,12)` facing east. Continue remaining Cantlin
  service discovery after that reload.

## 2026-07-09 Cantlin Tool Merchant Return-To-Entrance Pass

- User reloaded `main.lua`; fresh baseline confirmed the previous Tool Merchant
  source changes were live. Services filter reported `Tool Merchant` at object
  `(7,12)` with interaction stand `(5,12)` facing east.
- Active target: return route from the Tool Merchant/public-stand side toward
  the practical Cantlin entrance `(15,1)`.
- CLEAN / PROMOTED with same-origin `probe_edge_verify:...,3`; every verifier
  had `classification=confirmed_blocked`, `moved=0 blocked=3`, no drift,
  no map change, no interruption, and no teleport-artifact suspicion:
  `(6,1).west`, `(6,2).west`, `(6,3).west`, `(6,4).west`,
  `(6,5).west`, `(6,6).west`, `(7,7).west`, `(6,6).south`,
  `(7,7).south`, `(13,5).west`, `(12,4).south`, `(13,6).west`,
  `(13,7).west`, `(12,8).north`, `(10,1).south`, `(13,2).west`,
  `(12,1).south`, `(13,3).west`, `(12,4).north`, `(11,1).south`,
  `(11,4).north`, `(11,4).west`, `(9,2).east`, `(9,3).east`,
  `(9,4).east`, `(9,4).south`, `(7,4).south`, `(11,8).north`,
  `(10,7).east`, `(10,6).east`, and `(10,6).north`.
- Open / not promoted from this pass: route movement cleanly entered
  `(5,2..7)`, `(6,7)`, `(6,8)`, `(7,8)`, `(8,5..8)`, `(9,5)`,
  `(10,5)`, `(11,5)`, `(12,5)`, `(12,6)`, `(11,2)`, and `(12,2)`
  through adjacent route steps before later false-wall retries.
- Runtime mirrors were injected with `add_blocked_edge` after each source patch.
  Final runtime checkpoint: Cantlin `(10,5)`, NPCs frozen, menu closed, no
  lower dialogue or merchant state, `RUNTIME_BLOCKS map=0x0A count=25`.
  Current-pass runtime cells include `6,1(west)`, `10,1(south)`,
  `11,1(south)`, `12,1(south)`, `6,2(west)`, `9,2(east)`,
  `13,2(west)`, `6,3(west)`, `9,3(east)`, `13,3(west)`,
  `6,4(west)`, `7,4(south)`, `9,4(east,south)`,
  `11,4(north,west)`, `12,4(north,south)`, `6,5(west)`,
  `13,5(west)`, `6,6(south,west)`, `10,6(east,north)`,
  `13,6(west)`, `7,7(south,west)`, `10,7(east)`, `13,7(west)`,
  `11,8(north)`, and `12,8(north)`.
- Verification during the pass: each promoted edge followed TDD red/green
  updates in `test_map_reader.lua` and `map_reader.lua`; final
  `luajit.exe test_map_reader.lua` passed 58 tests.
- NEXT: manually reload `main.lua` before judging these new source blockers
  without the runtime overlay. Then retry:
  `.\dw_commands.ps1 --replace --timeout 60 --wait "AUTO_WALK_BLOCKER" freeze_npcs "auto_walk_blocker:15,1" report_position report_runtime_blocks report_menu_state`
  If continuing before reload, the current runtime overlay already mirrors this
  batch.

## 2026-07-09 Cantlin Tool Merchant Completion / Merchant 7 Pass

- CLEAN reload baseline: Cantlin `(10,5)`, five opened door slots,
  `RUNTIME_BLOCKS none`, NPCs frozen, menu/dialogue closed.
- CLEAN / PROMOTED by same-origin `probe_edge_verify:...,3`; each result was
  `classification=confirmed_blocked`, `moved=0 blocked=3`, with no drift,
  map change, interruption, NPC block, timing suspicion, or teleport artifact:
  `(7,6).east` from `(8,6)->LEFT`, `(9,6).west` from
  `(8,6)->RIGHT`, `(23,21).east` from `(24,21)->LEFT`,
  `(24,22).north` from `(24,21)->DOWN`, `(25,22).north` from
  `(25,21)->DOWN`, `(26,22).north` from `(26,21)->DOWN`, and
  `(27,24).north` from `(27,23)->DOWN`.
- With the first two edges mirrored live, `auto_walk_blocker:15,1` completed
  from the Tool Merchant side and `auto_walk_blocker:5,12` completed from the
  entrance, proving the Tool Merchant stand route in both directions.
- Merchant 3 targeted parked-NPC survey reached target `(12,23)` from
  `(5,12)`, but the restored NPC was mobile (`move=0xEE`) and wandered to
  `(13,18)` before TALK. No Merchant 3 role or stand was promoted.
- Merchant 7 is stationary at `(27,26)` (`move=0x00`). The broad targeted
  survey hit its route-churn cap with 33 blocked events and was downgraded to
  `command_timing_or_state_issue`; `SURVEY_STRONG_CANDIDATES none`. DO NOT
  PROMOTE that broad suspect list. The five Merchant 7 edges above were later
  isolated and direct-verified from normal walked origins.
- The focused `auto_walk_blocker:25,26` route completed after those runtime
  mirrors. From stand `(25,26)` facing east, TALK opened:
  `We deal in weapons and armor. Dost thou wish to buy anything today?`
  `objects.lua` now labels Merchant 7 as `Weapons Merchant` and stores the
  fixed public counter stand `(25,26)` facing east.
- Current live checkpoint: Cantlin `(25,26)`, NPCs frozen, command menu and
  dialogue closed, `RUNTIME_BLOCKS map=0x0A count=7`. Source changes require
  a manual `main.lua` reload before the seven blockers and Merchant 7 label
  are live without the overlay.
- NEXT after reload: route from Merchant 7 stand back to entrance `(15,1)`;
  then validate the full entrance-to-Merchant 7 stand route.

## 2026-07-09 Cantlin Merchant 7 Return And Reverse Pass

- Reload baseline: Cantlin public stand `(25,26)`, stationary Merchant 7 at
  `(27,26)` labeled `Weapons Merchant`, all five doors open, menu/dialogue
  closed, and `RUNTIME_BLOCKS none`.
- CLEAN / PROMOTED during stand-to-entrance routing, each with same-origin
  `probe_edge_verify:DIR,3`, `moved=0 blocked=3`,
  `classification=confirmed_blocked`, and no NPC block, timing suspicion,
  timeout, drift, map change, interruption, or teleport artifact:
  `(25,22).south`, `(23,23).east`, `(24,22).south`, `(24,24).north`,
  `(26,22).south`, `(27,20).south`, `(24,14).south`, `(15,13).south`,
  `(16,14).west`, `(16,14).south`, `(14,14).south`, `(13,14).south`,
  `(12,14).south`, `(11,13).south`, and `(12,14).west`.
- RESULT: after runtime mirroring, `auto_walk_blocker:15,1` completed at the
  practical entrance `(15,1)`.
- CLEAN / PROMOTED during full reverse validation toward `(25,26)`:
  `(21,11).west` from `(20,11)->RIGHT`, `(21,26).west` from
  `(20,26)->RIGHT`, `(21,27).west` from `(20,27)->RIGHT`, and
  `(21,28).west` from `(20,28)->RIGHT`; each verifier was again clean 3/3.
- TRANSITION EVIDENCE: after those lower-wall mirrors, A* planned through
  `(20,28)->DOWN` into `(20,29)`. Movement succeeded, then immediately logged
  `EVENT: map change -> 0x01 (World Map)` at `(73,102)`. This is not an engine
  wall. Source now models `(20,29).north` as a pathfinding transition guard so
  ordinary in-town routes do not select it.
- RECOVERY: `(73,102)->DOWN` reached `(73,103)` and triggered a Starwyvern.
  The first RUN attempt failed; the second succeeded. `probe_edge:UP` from
  `(73,103)` re-entered Cantlin at `(15,0)`. A subsequent DOWN probe carried
  to `(15,2)`.
- STATE BOUNDARY: re-entering Cantlin cleared the current-pass runtime overlay
  and all five opened-door RAM slots. Current live checkpoint is Cantlin
  `(15,2)`, `RUNTIME_BLOCKS none`, all doors closed, one key. Source tests pass,
  but current-pass source blockers and the transition guard require a manual
  `main.lua` reload.
- NPC PARK NOTE: Merchant 3's restored position was `(15,14)`. While the hero
  occupied that cell, restore was deferred and the absent slot temporarily
  shifted generic labels. Moving the hero to `(15,15)` restored slot 8 and
  normalized `Radish Merchant`, `Tool Merchant`, and `Weapons Merchant`; this
  was temporary runtime state, not label-source corruption.
- NEXT: reload the all-doors-open save state, reload `main.lua`, and retry
  `auto_walk_blocker:25,26` from practical entrance `(15,1)`. If A* selects a
  different south-edge transition, record it and stop rather than leaving town.

## 2026-07-09 Cantlin Merchant 7 Bidirectional Completion

- Initial restored baseline: Cantlin `(8,25)`, all five door RAM slots open,
  menu/dialogue closed, and `RUNTIME_BLOCKS none`; `(20,29).north` was live.
- CLEAN / PROMOTED before the mid-pass emulator restart, each via same-origin
  `probe_edge_verify:DIR,3`, `moved=0 blocked=3`,
  `classification=confirmed_blocked`, and no NPC/timing/drift/transition
  contamination: `(8,24).south`, `(10,25).west`, `(23,11).north`,
  `(22,11).north`, `(21,11).north`, `(21,21).west`, `(21,26).east`.
- The first route reached Merchant 7 stand `(25,26)`. A return run exposed
  `(21,26).east`, then the user restarted the laggy emulator and restored the
  same all-doors-open save.
- Post-restart baseline: Cantlin `(8,25)`, all five doors open, menu closed,
  `RUNTIME_BLOCKS none`. `inspect_move:22,26,LEFT` confirmed `(21,26).east`
  was active after navigation module refresh.
- CLEAN / PROMOTED after restart with the same verifier guarantees:
  `(13,8).south`, `(17,14).north`, `(21,13).west`, `(23,21).north`,
  `(22,21).north`, `(21,21).north`, `(24,24).east`, `(23,25).east`,
  and `(19,25).east`.
- LIVE COMPLETION: with nine post-restart runtime mirrors, uninterrupted
  `auto_walk_blocker:25,26` completed from entrance `(15,1)`,
  `auto_walk_blocker:15,1` completed from stand `(25,26)`, and a final
  uninterrupted `auto_walk_blocker:25,26` completed again from `(15,1)`.
- Current live checkpoint: Cantlin `(25,26)`, all five doors open, menu and
  dialogue closed, runtime overlay count 9. The nine post-restart source
  directions require manual `main.lua` reload before overlay-free validation.
- NEXT: reload `main.lua`, then continue the next unclassified Cantlin service;
  mobile Merchant 3 remains the strongest targeted follow-up.

## 2026-07-10 Cantlin Dialogue-Merchant Classification

- Reload baseline was Cantlin `(25,26)`, all five doors open, menu closed,
  `RUNTIME_BLOCKS none`, and the restored-state `(13,8).south` source blocker
  active.
- A frozen single-target survey toward Merchant 3 initially planned 22 steps
  from `(25,26)` toward target `(3,27)`. It reached `(3,29)` after extensive
  rerouting, then stopped at `route_churn_cap` with 33 blocked events and
  `failure_class=command_timing_or_state_issue`.
- SCRATCH ONLY / DO NOT PROMOTE: the broad suspect cells were
  `22,27|21,27|22,28|20,26|19,26|19,27|19,28|17,24|18,25|15,23|16,25|`
  `12,24|13,25|10,25|8,24|8,26|8,27|8,28|3,28`.
  Do not patch any of these without isolated same-origin verification.
- Merchant 3 was subsequently frozen at `(4,27)`. Debug landing `(5,27)`
  facing west and live TALK read: `My Grandfather Wynn once had a shop on the
  east side of Hauksness.`
- Merchant 1 was frozen at `(1,0)`. After resetting the blocked-facing
  movement residue with a same-cell `(1,1)` re-land, live TALK facing north
  read: `Grandfather used to say that his friend, Wynn, had buried something
  of great value at the foot of a tree behind his shop.`
- RESULT: both are dialogue-only hint NPCs. `objects.lua` keeps their generic
  NPC labels but adds `Merchant 1` and `Merchant 3` to Cantlin's
  `SERVICE_EXCLUSIONS`. `luajit test_objects.lua` passes all 92 tests.
- STATE NOTE: a one-frame blocked facing tap can leave movement bytes at
  `move=0x10 sub=0x10`, causing delayed field actions. A same-cell debug
  re-land reset both to `0x00`; the delayed dialogue was genuine Merchant 1
  proof, not route evidence.
- Current checkpoint: Cantlin `(1,1)`, all five doors open, menu/dialogue
  closed, NPCs frozen, and `RUNTIME_BLOCKS none`. Reload `main.lua`, confirm
  the cleaned Services list, then continue only the confirmed shop routes.

## 2026-07-10 Cantlin Isolated Pocket And `llE` Route Cancellation

- Reload baseline: Cantlin `(1,1)`, all five doors open, menu/dialogue closed,
  `RUNTIME_BLOCKS none`; Merchant 1 and Merchant 3 both reported `service=false`.
- CLEAN / PROMOTED: entrance-route blocker hunt stopped at normal origin
  `(1,1)` on `(1,1)->RIGHT` and `(1,1)->DOWN`. Same-origin
  `probe_edge_verify:RIGHT,3` and `probe_edge_verify:DOWN,3` each returned
  `attempts=3 moved=0 blocked=3 classification=confirmed_blocked`, with no
  timeout, NPC block, drift, map change, interruption, or teleport artifact.
- Runtime mirrors were destination/approach pairs `(2,1).west` and
  `(1,2).north`. With both active, normal and skip-NPC planners each visited
  one tile and returned `No path found`; `(1,1)` is an isolated debug pocket.
- Repositioned to practical entrance `(15,1)` after clearing runtime mirrors.
- Mobile Weapons Merchant 2 was first frozen at `(5,10)`. Explicit target
  `(5,11)` was occupied by Guard 2, so `auto_walk_blocker:5,11` resolved the
  guard object rather than a coordinate target. Do not reuse occupied stands.
- That first route reached `(15,4)` and canceled with `PREV.dialogue_len=3`.
  After the residue cleared, Weapons Merchant 2 was frozen at `(8,10)` and an
  unoccupied north stand `(8,9)` produced the same immediate cancellation.
- BUG / LIVE REPRO: frame 51306 logged `CAN_WALK false ... PREV.dialogue_len=3`
  with no menu, submenu, merchant UI, or upper dialogue. Frame 51335 then
  decoded the exact phantom dialogue as `llE`. This is the hero-name suffix
  fused to the uppercase Experience/status label, not real game dialogue.
- FIX: `text.is_passive_field_status_noise("llE")` now uses the existing fused
  status-label token detector. `field_action_guard.dialogue_blocks_movement`
  centralizes passive-versus-real dialogue classification, and `main.lua`'s
  per-frame `can_walk` gate uses it instead of requiring empty dialogue text.
- TESTS: 58 map tests, 58 text tests, and 7 field-action-guard tests pass.
- CURRENT: Cantlin `(15,4)`, all five doors open, menu/dialogue closed,
  `RUNTIME_BLOCKS none`. NPC freeze released after route cancellation; mobile
  Weapons Merchant 2 was last seen at `(0,3)` and will move before reload.
- NEXT: reload `main.lua`, report and freeze NPCs, choose a currently unoccupied
  adjacent coordinate for Weapons Merchant 2, and retry the route.

## 2026-07-10 Cantlin Command-Menu `llE` Suffix

- LIVE REPRO after reload: SEARCH and TALK results were announced as
  `Bill searched the ground all about. llE`, `But there found nothing. llE`,
  and `'There is no one there. llE`.
- `report_upper_dialogue_state` isolated the residue to wrapped lower-dialogue
  base nametable 1, scan index 10, row 8: `text="llE"`.
- ROOT CAUSE: standalone passive-noise filtering did not help when that row was
  concatenated with valid command-result rows. The per-row filter recognized
  status values and context-derived name fragments, but did not reject the
  already-known fused name/status-label token class.
- FIX / TEST: `filtered_dialogue_from_rows` now excludes fused status-label
  rows before concatenation. The exact wrapped PPU regression first failed with
  the unwanted suffix, then passed; all 59 focused text tests pass.
- CURRENT: Cantlin `(15,4)`, all five doors open, one key, menu/dialogue closed,
  `RUNTIME_BLOCKS none`. Reload `main.lua`, then retry SEARCH and empty-space
  TALK before resuming the Merchant 2 route.

## 2026-07-10 Merchant 2 Route And Stale Services Selection

- USER LIVE VALIDATION: all command-menu actions, Merchant 2, SPELL, and ITEM
  spoke correctly after reload; clean log results no longer contained `llE`.
- Baseline: Cantlin `(15,5)`, mobile Weapons Merchant 2 at `(15,4)`, all five
  doors open, one key, menu/dialogue closed, `RUNTIME_BLOCKS none`.
- CLEAN ROUTE: `(15,5)` to entrance `(15,1)` completed `4 north`; every seam
  moved and no blocker or dialogue cancellation occurred.
- CLEAN REVERSE ROUTE: after waiting for an interior patrol position, Merchant
  2 was frozen at `(14,4)`. Normal and skip-NPC adjacent planners both chose
  stand `(14,3)` with `2 south, 1 west` from entrance. The actual blocker-mode
  route completed with no runtime patch or speech residue.
- BUG / LIVE REPRO: after `debug_pathfind_adjacent` triggered
  `NAVIGATION_MODULES_REFRESHED`, two `next_filter` commands announced
  `Services`, but `current_object` and `next_object` remained
  `Eastern Building Door (10 of 25)`.
- ROOT CAUSE: `main.lua` replaced `package.loaded["objects"]` and re-registered
  object commands, but route manager retained its pre-reload local `objects`
  table. Filter label/count and route description therefore read different
  module instances.
- FIX / TDD: `route_manager.refresh_navigation_modules()` now rebinds
  `objects = require "objects"`. The new regression failed with stale `Chest`
  and passed with replacement `Weapons Merchant`; all 104 route-manager tests
  pass.
- CURRENT: Cantlin `(14,3)`, all five doors open, one key, menu/dialogue closed,
  `RUNTIME_BLOCKS none`, NPC freeze released; Merchant 2 last reported `(16,3)`.
- NEXT: reload `main.lua`; switch from All to Services, verify four entries and
  no stale door selection, then run object-selected `auto_walk_blocker` to the
  mobile Weapons Merchant.

## 2026-07-10 Services Fix Validation And Category Audit

- LIVE FIX VALIDATED: after explicit `NAVIGATION_MODULES_REFRESHED`, Services
  reported `Inn (1 of 4)` and `current_object` matched. The stale door/25-item
  selection did not recur.
- Four Services entries: mobile Weapons Merchant, Inn, Tool Merchant, fixed
  Weapons Merchant. Object-selected `auto_walk_blocker` refreshed Merchant 2 to
  `(17,4)`, walked three east from `(14,3)` to `(17,3)`, faced south, and held
  the target. No blocker, runtime patch, menu, or dialogue residue occurred.
- TIMING ONLY / NO PATCH: batching `reload_navigation_modules next_filter` in
  one emulator frame produced `NPCs. No objects`; issuing reload alone, waiting
  two seconds, then filtering produced `NPCs ... (1 of 19)`. Normal player
  filter timing is unaffected.
- REACHABILITY AUDIT: Services `4 reachable / 0 unreachable`; Travel `1 / 0`;
  Doors `5 / 0`; NPCs `18 / 1`. The sole unreachable NPC was Radish Merchant
  `(2,12)`.
- PRIOR PROOF: TALK from `(4,12)` facing west produced the radish dialogue.
  Fresh blocker-mode routing from `(17,3)` planned 22 steps and reached `(4,12)`
  cleanly with every seam moved and `RUNTIME_BLOCKS none`.
- ROOT CAUSE: the role override labeled Radish Merchant and set `service=false`
  but could not store a non-service interaction stand, so NPC pathability tried
  the sealed adjacent pocket.
- FIX / TDD: explicit role overrides may now copy `interaction_x/y`, facing,
  and label before the non-service return. Cantlin `(2,12)` uses interaction
  `(4,12)`, facing west, label `counter`. The focused test failed on nil
  interaction X and now passes; all 92 object tests pass.
- CURRENT: Cantlin `(4,12)`, all five doors open, one key, menu/dialogue closed,
  `RUNTIME_BLOCKS none`.
- NEXT: reload `main.lua`, rerun NPC reachability, and expect all 19 reachable.

## 2026-07-10 Cantlin Damage Barrier And Object-Reload Timing

- LIVE HAZARD EVIDENCE: autowalk from Radish Merchant stand `(4,12)` toward
  Travel exit `(14,29)` entered the lower-center striped barrier. The route
  walked across `(15,26)` through `(11,26)`, and the next status read showed
  4 HP. Source previously had no Cantlin hazard cells, so normal and
  hazard-allowed planners initially produced the same route with `hazards=0`.
- MAP ORIENTATION: the 30x30 Cantlin reference map places the striped barrier
  at `y=26: x=11..18`, `y=27: x=11,18`, and
  `y=28: x=11..13,16..18`. These 16 cells are now damage hazards in
  `MAP_HAZARD_CELLS[0x0A]`; focused map tests cover every cell and a nearby
  safe negative.
- CLEAN BLOCKER: from live origin `(12,26)`, `probe_edge_verify:DOWN,3`
  returned `moved=0 blocked=3 classification=confirmed_blocked` for
  `(12,27).north`, which is now directional source data.
- LIVE PATCH CHECK: from `(12,26)`, normal exit planning detoured while
  hazard-allowed planning took the short route through `(13,26)` and `(14,26)`
  with `hazards=2`. North escape then hit `(12,25).south`; a verifier became
  inconclusive because the patched hazard origin is intentionally no longer a
  valid verifier landing, so that second seam was not promoted.
- RECOVERY / ROUTE: debug teleport moved the 4-HP hero to known-safe `(9,25)`.
  Normal and hazard-allowed entrance plans agreed on 30 steps with `hazards=0`,
  and `auto_walk_blocker:15,1` completed the route without a blocker or hazard.
- TIMING BUG REPRO: same-frame `reload_navigation_modules next_filter`
  produced `FILTER: NPCs. No objects`; splitting the commands had previously
  shown all 19 NPCs. Root cause was a newly required `objects` module with no
  current-map list until a later `check_refresh` frame.
- FIX / TDD: `object_commands.refresh_after_module_reload()` synchronously
  refreshes the live map, and `register()` invokes it only when the new object
  module reports a refresh is needed. `main.refresh_navigation_modules()` also
  primes explicitly before registration. The focused regression failed on the
  missing prime and now passes all 3 object-command tests.
- LIVE TIMING VALIDATION: the exact same-frame batch now reports
  `NPCs. Merchant 1 ... (1 of 19)` and `current_object` agrees.
- CURRENT: Cantlin practical entrance `(15,1)`, all five doors open, one key,
  menu/dialogue closed, `RUNTIME_BLOCKS none`; NPC filter is selected.
