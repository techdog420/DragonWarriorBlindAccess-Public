# Playtesting Notes

Updated: 2026-05-04

This file tracks the shift from map decoding toward actual blind-player gameplay.

## Current Goal

Run the early game as a player would, using the accessibility mod as the primary interface. Capture friction, missing narration, confusing commands, pathfinding recovery problems, and quality-of-life improvements.

## Focus Areas

Location awareness:
- Announce current map, coordinates when useful, facing, exits, nearby objects, and hazards
- Make it easy to recover orientation after movement or teleport/debug commands

Object interaction:
- Verify NPC, chest, door, stair, shop, and inn workflows
- Ensure object navigation explains whether a target is reachable
- Prefer actionable failure reasons over generic no-path messages

Menus and combat:
- Confirm menu cursor narration is reliable
- Confirm combat narration exposes HP, enemy state, results, and turn outcomes clearly
- Identify missing item/spell/shop narration needed for normal play

Movement and routing:
- Prefer routes that feel stable during actual play, not only during survey loops
- Log route failures with enough context to reproduce
- Avoid permanent map-data changes without direct blocker evidence

QoL feature check:
- `auto_walk` should now speak progress on longer routes and speak completion.
- After auto-walking to an NPC, the target should be held briefly so the player
  has time to use TALK. The route should also face the target after arrival so
  TALK does not fail with "There is no one there."
- Object filters are All, NPCs, Services, Treasure, Travel, and Doors; `Q`
  cycles forward, `Shift+J` and `Shift+L` move filter categories without
  scrolling objects, and `Shift+K` jumps back to All.
- `Shift+O` cycles the separate pathability filter: All, Reachable, and
  Unreachable. This stacks with the object category filter, ignores moving NPC
  occupancy, and is intended for sanity-checking larger maps without making
  rapid J/K/L browsing run pathfinding every tap.
- Visited flags are session-only and map-scoped. Use `Shift+V` or
  `mark_visited` to mark manually; `clear_visited` clears the current map and
  `clear_visited:all` clears all maps.
- Selected-object teleport uses `Shift+Enter` for the target cell and
  `Shift+direction` for an adjacent landing on that side of the target.
- Watch selected-object teleport near doors/stairs and moving NPC clusters.
  The first manual test did not show lost keyboard input after teleport; logs
  showed the player boxed in at `(4,6)` on map `0x05` by NPCs at `(3,6)` and
  `(5,6)`, the door south, and a noisy north doorway edge.
- Direct selected-object teleport to an unwalkable target should speak a simple
  player-facing refusal, without mentioning debug-only `near` or `force` flags.
- Latest manual pass: auto-walk is mostly behaving as expected. A possible
  Guard 1 auto-walk failure still needs log review, but the previously patched
  false-visited case now behaves correctly.

## Initial Gameplay Pass Checklist

Use this as a lightweight first pass:
- Start or load a normal early-game state
- Confirm speech backend readiness with `speech_status`
- Confirm player state with `report_position` or `log_state`
- Navigate around the starting castle/interior without visual assumptions
- Interact with the king/throne-room objects if available
- Use stairs/doors/exits intentionally
- Visit the first town and interact with NPCs/shops if reachable
- In town, verify visited flags and Services/Treasure/Travel filter categories
- Enter a simple combat encounter and evaluate narration
- Record every point where the player would feel lost, under-informed, or unable to recover

## Open Gameplay Issues

### GP-002

Severity: Medium

Area: Command menu narration / map-position sensitivity

Status:
Needs investigation in the next playtest/debug session.

Description:
Manual testing found that in certain parts of the map, the command menu does
not read correctly. This appears to be map-region or player-position dependent,
not a general screen-reader failure.

Next evidence to collect:
- Reproduce one bad command-menu read.
- Immediately capture `report_position`, `input_status`, and ideally
  `report_movement_state:menu_bad_region`.
- Compare with a nearby position where the command menu reads correctly.
- Check whether the issue correlates with scroll/camera bytes, row-1 command
  menu parsing, or map-specific PPU layout.

### GP-001

Severity: High

Area: Emulator default / BizHawk performance

Status:
BizHawk swap accepted as successful enough to continue normal playtesting from
the BizHawk path. First clean early-game flow was confirmed manually on
2026-04-30, and basic manual testing on the first two maps after the conversion
found scripts behaving as expected. Remaining audio stutters or small narration
bugs should be handled as ordinary gameplay polish unless fresh logs show a new
large script spike.

Description:
BizHawk is now the default emulator path. It can launch the ROM and
accessibility script, and the script can speak through title/continue flow.
Early gameplay was initially super laggy once the game proper started, but the
current BizHawk-only throttles have substantially reduced scan load during the
king's boot dialogue.

Reproduction steps:
- Launch with `./launch_dw.sh`
- Continue an existing quest
- Wait until the game proper starts

Observed behavior:
- Title flow and speech work.
- Lag improves with compatibility-layer PPU caching and gameplay scan
  throttling.
- During the king's normal boot dialogue, current profiling shows only
  dialogue/yes-no scans running; command-menu, merchant, and object refresh
  scans are suppressed.
- Lag did not fully stop after king dialogue ended in the live script that was
  running before the latest state-detector patch.
- Spoken status summaries appearing inside king dialogue were caused by stray
  BizHawk keyboard hotkeys, not by dialogue parsing. BizHawk keyboard hotkeys
  are now disabled by default.
- The object explorer initially stopped working under BizHawk because the first
  hotkey gate blocked every keyboard shortcut. The current patch restores the
  default object/navigation hotkeys through `bizhawk_keyboard_hotkey_allowlist`.
  The `N` tile/coordinate diagnostic is also allowed for playtesting, while
  broader status/raw-dump diagnostics stay blocked.
- Pressing `N` then provided a clean audio-cutout repro: the spoken coordinate
  check was coupled to the full `tile_diag.txt` dump and could stall audio for
  about 1.5-2 seconds. The current patch keeps `N` to the compact spoken
  coordinate/tile summary by default; set `tile_diag_dump_on_hotkey=true` only
  for slow forensic dumps.
- A command-file `current_object` probe still returned an object description,
  so this was a keyboard-filter issue rather than an object-list failure.
- Normal play audio is now reported smooth, but route/path commands can still
  glitch emulator audio while processing. A live sample showed command/object
  refresh spikes rather than steady frame-loop lag: `debug_tools.tick
  max_ms=1931` and `objects.check_refresh max_ms=2068`.
- Dialogue is no longer lagging, but live testing showed it could speak before
  all new text arrived. The current patch clears BizHawk's PPU cache for
  dynamic dialogue scans so partially rendered cached text should not announce
  as stable.
- Object navigator caused an approximate two-second BizHawk freeze. The current
  patch makes BizHawk object descriptions skip reachability/path checks by
  default; explicit `pathfind` and `auto_walk` still do the heavier work.
- Object-browser hotkeys now explicitly request brief descriptions only:
  name/direction/count, without path reachability previews or raw coordinate
  debug suffixes. Explicit `O` pathfind and `U` auto-walk remain the route-work
  commands.
- After reloading with the latest object-refresh patch, broad lag is mostly
  under control. Object-list navigation still causes a small amount of lag, but
  profiling no longer shows script-side object/hotkey spikes.
- Rapid J/L object navigation now coalesces speech by default with
  `object_nav_speech_coalesce_frames=18`: selection changes immediately, but
  only the latest object description speaks after a short pause. K/current
  object still speaks immediately. The first 6-frame trial still flushed
  repeatedly during manual tapping, so this wider delay needs live BizHawk
  audio confirmation.
- The BizHawk audio config trial helped: with `SoundBufferSizeMs=200`,
  `SoundThrottle=true`, `FrameSkip=0`, and `Rewind.Enabled=false`, background
  window work no longer reproduced the previous audio glitching. One glitch
  occurred while focused in the emulator, but it has not reproduced.
- Wrap-up manual testing on 2026-04-30 covered the first two maps at a basic
  level. Apart from audio stuttering, script behavior matched expectations
  after the emulator conversion.
- Random emulator audio freezes were also observed, especially while working in
  other windows. This still needs correlation with `CMD_TIMING` and scan stats;
  if no script spike appears, treat it as a BizHawk/Windows focus or scheduling
  issue rather than the Lua loop.
- Normal movement/menu responsiveness after reloading the latest script still
  needs a fresh player-control check.
- Standing by the king on map `0x05`, auto-walk to the selected stairs returned
  "No path found". After the ROM-domain fix, live probes now show sane map
  dimensions and tile data: `(8,8)` is passable stair/corridor passthrough,
  while `(4,7)` is a closed magic-key door. The remaining no-path is normal
  locked-door route state, not a BizHawk ROM decode failure.

Expected behavior:
- Emulator remains responsive enough for normal play while the accessibility
  script runs.

Evidence:
- PPU caching improved title lag but not field lag enough.
- Current hypothesis is that field gameplay runs too many PPU-heavy scans each
  frame under BizHawk's slower Lua memory-domain APIs.
- A BizHawk-only scan-throttle patch has been added for title-state rescans,
  yes/no prompt scans, command/battle menu checks, merchant analysis, lower
  dialogue, and upper dialogue.
- Latest king-dialogue sample after boot-dialogue grace: `PPU_STATS
  reads=123840 cache_hits=108736 cache_misses=15104`; active scan profiles
  were lower dialogue, yes/no prompt, and upper dialogue only.
- Latest post-dialogue/player-control sample before the state patch:
  `state.check_for_changes calls=240 reads=0 ms=26984 avg_ms=112.433`. The
  source was the BizHawk path reading `$6003` every frame for sprite CHR/battle
  detection.
- Latest route/path command patch caches static object sources per map, adds
  `CMD_TIMING` logging for slow command handlers, and throttles repeated
  `CAN_WALK false` debug lines.
- Latest object/dialogue patch clears dynamic text PPU cache reads under
  BizHawk and adds `bizhawk_object_reachability_descriptions=false` so object
  navigator speech is quick by default.
- Latest post-dialogue object-list samples:
  `objects.check_refresh max_ms=1` for command-file object navigation, and a
  real-hotkey sample showed `hotkeys.update max_ms=1` plus
  `objects.check_refresh max_ms=1`. The earlier two-second object-refresh spike
  is no longer present with `bizhawk_periodic_npc_refresh=false`.
- The object-nav speech coalescer is covered by `test_hotkeys.lua`; tests cover
  delayed J/L speech, rapid-tap latest-only speech, K/current-object immediate
  speech, route-action clearing, and `object_nav_speech_coalesce_frames=0`.
- `emulator_compat.lua` now scores BizHawk ROM candidate domains/address
  mappings so headerless PRG-only ROM domains still emulate FCEUX
  `rom.readbyte()` offsets. New validation: `test_emulator_compat.lua` covers
  full iNES and headerless PRG domain layouts.
- Live follow-up on 2026-04-29 confirmed the map `0x05` stair path now decodes
  correctly under BizHawk: `inspect_tile:8,8` returned `dims=10x10`,
  `tile=15.0`, `reason=passthrough`, and `effective_passable=true`;
  `inspect_move:4,6,DOWN` returned `reason=door_closed` for `(4,7)`.
- Route messaging now detects a closed-door frontier on no-path plans and tells
  the player to get/use a magic key instead of only saying "No path found".
  Covered by `test_route_manager.lua`.
- Live playtesting after this still showed the door as closed after the player
  opened it. Root cause: BizHawk `memory.readbyte()` was still reading
  `$600C/$600D` opened-door slots through `mainmemory`, but DW1 stores those
  slots in cartridge work RAM. `emulator_compat.lua` now routes `$6000-$7FFF`
  reads through System Bus / PRG-RAM-style domains, and
  `test_emulator_compat.lua` plus `test_map_reader.lua` cover opened-door RAM.
- Manual retest after the cartridge-RAM fix confirmed the expected flow from
  game launch: open all throne-room chests, open the `(4,7)` door, and walk
  down the stairs into the castle proper.
- The same run showed auto-walk audio pain around blocked-step retries. Local
  config now uses `auto_step_timeout=45` and `auto_step_block_retry_limit=1`
  to shorten blocked-route retry windows.
- A later 2026-04-30 first-town manual run reported that route/path commands
  still caused lag, name-entry clicks could double-enter letters, and movement
  could overshoot cells. The live `dw_debug.log` did not contain `CMD_TIMING`
  or scan-profile spikes for the hotkey-triggered `O`/`U` work, so route-plan
  timing is now logged separately as `ROUTE_PLAN_TIMING`.
- The same log showed a concrete queued auto-walk overshoot pattern: after a
  south step to `(1,4)`, the next queued `right` step completed at `(1,5)`
  while the planned seam was `(2,4)`; after a right segment to `(3,5)`, the
  next queued `down` completed at `(4,5)` while the planned seam was `(3,6)`.
  `auto_step_route_turn_settle_frames=16` now pauses queued routes before
  changing direction, while straight segments can still chain quickly.
- Chosen-path summaries remain in the log, but tile-by-tile chosen-path dumps
  are now opt-in with `pathfind_log_steps=true` because the detailed dump is
  slow and noisy during ordinary playtesting.
- Focused wrap-up validation after making `N` cheap and object browsing brief
  passed `luac -p hotkeys.lua objects.lua route_manager.lua config.lua
  test_hotkeys.lua`, `lua test_hotkeys.lua`, `lua test_route_manager.lua`,
  `lua test_objects.lua`, and `git diff --check`.
- Route-turn follow-up validation passed `luac -p auto_step.lua pathfinder.lua
  route_manager.lua config.lua test_auto_step.lua`, `lua test_auto_step.lua`,
  `lua test_route_manager.lua`, `lua test_pathfinder.lua`, and
  `git diff --check`. `test_pathfinder.lua` still prints the known WSL
  Tolk/`cmd` warning before passing.
- A follow-up live log after reloading showed the queued route turn-settle
  working for a 2-step route, but also exposed the remaining autowalk lag as
  route planning: `ROUTE_PLAN_TIMING map=0x08 start=(0,15) target_id=npc_15 ...
  path_len=2 ms=1978.000`. `pathfinder.lua` now prunes adjacent candidates that
  cannot beat the current shortest landing path and defers reachable-area
  diagnostics unless needed for an equal-length tie or no-path evidence.
- The same run's quickload/town object issue matched a two-phase object refresh:
  static objects were available first, while NPCs were deferred until a later
  refresh. Under BizHawk scan throttling that delay could leave only "Exit to
  World Map" in Brecconary briefly. `objects.needs_refresh(map_id)` now lets
  map-entry and deferred NPC refreshes bypass the periodic 120-frame throttle.
- Route-planning/object-refresh validation passed `luac -p pathfinder.lua
  objects.lua main.lua test_pathfinder.lua test_objects.lua`,
  `lua test_pathfinder.lua`, `lua test_objects.lua`, `lua test_route_manager.lua`,
  `lua test_map_survey.lua`, `lua test_auto_step.lua`, and `git diff --check`.
- Live retest after script reload confirmed the object list populated quickly,
  but auto-walk still choked and then cancelled for path drift. The log showed
  `ROUTE_PLAN_TIMING map=0x08 start=(0,15) target_id=npc_4 ... path_len=13
  ms=1836.000`, followed by drift during turn-settle: after reaching `(4,14)`
  and preparing to turn up, the player slid to `(5,14)` and the route cancelled
  with `route_drift_off_path`.
- `auto_step.lua` now actively neutralizes the D-pad during route-settle frames,
  not just the first post-step release frames. `pathfinder.lua` now uses a
  per-plan walkability snapshot from `map_reader.lua`, with a fallback per-search
  cache, so A* does not repeatedly call the slower map-reader walkability path.
- Latest live retest showed auto-walk lag is reduced but still audible, and
  `O` show-path lags too. The log showed auto-walk route plans at `path_len=13
  ms=1852.000` and `path_len=10 ms=1238.000`; show-path route previews logged
  `path_len=7 ms=1422.000` and `path_len=1 ms=1514.000`. Because the 1-step
  preview still lagged, the likely culprit is fixed route-command overhead,
  especially forced live NPC refresh/freezing under BizHawk.
- BizHawk now skips forced live NPC refresh before `O`/`U` route plans by
  default (`bizhawk_route_refresh_npcs=false`) and skips auto-walk's NPC RAM
  freeze by default (`bizhawk_autowalk_freeze_npcs=false`). FCEUX keeps the
  previous behavior, and both BizHawk options can be turned back on for a
  blocker/NPC-specific investigation.
- The same log still showed route drift: after a first `right` step from
  `(0,15)` to `(1,15)`, settle before a planned `up` drifted to `(2,15)`; after
  a right segment from `(6,16)` to `(7,16)`, settle before a planned `up`
  drifted to `(8,16)`. `auto_step.lua` now actively releases route-owned D-pad
  input after the inject window as well as during turn-settle frames.
- Latest route-lag/drift validation passed `luac -p auto_step.lua
  route_manager.lua config.lua pathfinder.lua map_reader.lua objects.lua
  main.lua test_auto_step.lua test_route_manager.lua test_pathfinder.lua
  test_map_reader.lua test_objects.lua test_map_survey.lua`,
  `lua test_auto_step.lua`, `lua test_route_manager.lua`,
  `lua test_pathfinder.lua`, `lua test_map_reader.lua`,
  `lua test_objects.lua`, `lua test_map_survey.lua`, and `git diff --check`.
- 2026-04-30 follow-up from quick slot 1 in Brecconary: after warming the
  current map grid during map-entry object refresh, the first usable `O` /
  `auto_walk` route to Person 2 no longer logged `ROUTE_PLAN_TIMING` or
  `CMD_TIMING` spikes. The prior cold route was about 1.7-1.9 seconds.
- The same live route reached the intended adjacent tile `(10,15)` and ended
  with neutral input. The old turn-settle drift signatures did not reappear.
  There is still a smaller executor issue: the first facing/step from the town
  entrance can consume one timeout/brute-force retry before walking succeeds.
- `objects.check_refresh` can still show a one-time deferred NPC refresh hitch
  around 1.3 seconds after map entry. If audio still cuts out shortly after
  quickload or town entry, treat that refresh as the next performance target.
- Latest user retest: manual walking overshoot is much better, with remaining
  overshoot mostly when several movement presses are entered rapidly. Auto-walk
  audio is improved, but a lag spike still happened near the end of route
  attempts. Fresh logs showed the latest route reached the intended adjacent
  tile `(15,19)` with neutral input and no runtime blockers; the suspicious
  spike is `objects.check_refresh max_ms=1658` from route cleanup. BizHawk now
  skips the immediate post-route object refresh by default with
  `bizhawk_route_cleanup_refresh_objects=false`.
- Live validation after reloading the patch completed two Brecconary auto-walks:
  Person 4 from `(0,15)` to `(1,14)`, then Person 2 from `(1,14)` to `(9,14)`.
  Both ended adjacent to the target with neutral input and no runtime blockers.
  Around the longer 10-step route, `objects.check_refresh max_ms=0`,
  `debug_tools.tick max_ms=3`, and `auto_step.update max_ms=1`.
- User hands-on retest after that patch confirmed auto-walk is behaving much
  better, reaching intended targets, and the lag seems under control.
- Main-menu erase/name-entry follow-up: the latest live log showed the erase
  confirmation being treated as `field` on map `0x00`, causing extra dialogue,
  bogus auto-step block logs, and the false "Game started" / "Unknown Map 0"
  path. `state.lua` now keeps erase confirmation and name entry in title state,
  and `main.lua` now suppresses repeated A frames on name entry until a short
  stable release. `report_title_state` can log the visible title rows and
  selected name-grid cell if the issue needs another capture after reload.
- The next input check found that `S` is BizHawk's NES `P1 A` autofire binding,
  while normal A is `X`. Retest name entry and erase confirmation with `X`, not
  `S`; the map announcement after erase likely came from an extra autofire
  confirm into real gameplay.
- Mod hotkeys were regrouped to avoid BizHawk controls: common object actions
  stay on bare keys (`J/K/L/O/U/Q`), info commands use `Shift+key`, diagnostics
  use `Ctrl+key`, freeze NPCs is `Shift+F`, and tile diagnostics is `Ctrl+N`.
- King dialogue regression: after the hotkey/menu fixes, the king's lower
  dialogue was present (`lower_len=97`) but not automatically read because
  `in_gameplay` stayed false after the title-to-field debounce. `main.lua` now
  clears that debounce after "Game started."; the next live log confirmed king
  and NPC dialogue auto-read again.
- Command menu and post-dialogue status polish: command-menu openings now speak
  the highlighted item immediately, such as `Command. TALK`, instead of only
  saying `Command.`. The lower dialogue reader now skips persistent status rows
  like `Bill LV 1 HP 15 MP 0 G 120 E 0`, including hero names with lowercase
  letters, so the status line should not speak after dialogue dismissal.
- Follow-up log evidence showed the remaining status-line speech was coming
  from the upper dialogue reader, not the lower one: `report_upper_dialogue_state`
  showed `upper="Bill LV ..."` and `lower_len=0`. The upper reader now suppresses
  extracted `new_text` fragments that are themselves status text and logs
  `UPPER_DIALOGUE_SUPPRESS_STATUS` when that path is caught.
- BizHawk launchers now support `--state-slot N`; quick slot 1 can be loaded
  with `./launch_dw.sh --state-slot 1` or `./launch_bizhawk.sh --state-slot 1`.
- 2026-05-01 quick live map `0x05` route cycle: from throne-room `(3,4)`,
  object enumeration found 9 objects and the door/stairs data still looked sane
  (`inspect_tile:4,7` = `door_closed`, `inspect_tile:8,8` = `passthrough`).
  Auto-walk reached a nearby chest and then Guard 3. The Guard 3 route first
  logged `NEW BLOCK` for `(4,4)` down into `(4,5)`, but a controlled
  `probe_edge:DOWN` from `(4,4)` moved successfully, changing the seam evidence
  to noisy/transient rather than a confirmed map blocker.
- The same cycle found player-facing hitch risk in debug commands, not focused
  route execution: `report_path_state`, `inspect_move`, explicit
  `pathfind_adjacent`, and `probe_edge` all produced roughly 1-1.7 second
  `CMD_TIMING` lines. The focused Guard 3 auto-walk window itself reported
  `objects.check_refresh max_ms=0`, `auto_step.update max_ms=1`, and
  `debug_tools.tick max_ms=2`.

Recommended next step:
- Continue real early-game playtesting from the BizHawk path. Good next targets
  are combat narration, shops/inns, item/spell flows, and any remaining menu or
  dialogue polish that shows up naturally. If the post-dialogue status row
  appears again, check for `UPPER_DIALOGUE_SUPPRESS_STATUS` and
  `report_upper_dialogue_state` before changing the dialogue parser again.
- While testing object navigation, rapidly tap J/L and listen for reduced audio
  hitching. Use K to speak the current selection immediately. If the short delay
  feels worse than the old behavior, set `object_nav_speech_coalesce_frames=0`
  in `dw_access.ini` and reload the script.
- Keep the current BizHawk audio trial settings for now. Apply future config
  patches while EmuHawk is closed; live edits can be overwritten when the
  emulator exits.
- Good next experiments: tune BizHawk audio buffer/throttle settings, then
  compare one clean repro at a time with `reset_scan_stats` /
  `report_scan_stats`, fresh `CMD_TIMING` lines, and fresh
  `ROUTE_PLAN_TIMING` lines.
- Retest manual movement overshoot in normal play. The route executor now
  clears injected D-pad after movement starts, but manual cell-jumping still
  needs the user's hands-on confirmation.
- Retest auto-walk from quick slot 1 without pressing it immediately after
  launch. Use `current_object` first; if it says "No objects found", wait for
  the deferred object refresh, then select the target and try `O` / `U`.
- If auto-walk still feels choppy after objects are populated, capture
  `reset_scan_stats`, exactly one `auto_walk`, then `report_scan_stats`. A
  fresh `objects.check_refresh max_ms=...` line matters most if the hitch
  happens at route completion/cancel; `ROUTE_PLAN_TIMING` still matters if the
  hitch happens before movement starts.
- If the throne-room `(4,4)->(4,5)` route block appears again, do not promote it
  to map data from a single auto-walk. Reprobe with `probe_edge:DOWN` from
  `(4,4)` and compare against the latest noisy evidence.

When adding issues, use this format:
- ID
- Severity
- Area
- Description
- Reproduction steps
- Observed behavior
- Expected behavior
- Evidence or relevant log lines

## Useful Commands

State and speech:
- `speech_status`
- `log_state`
- `report_position`
- `current_object`
- `reset_scan_stats`
- `report_scan_stats`

Object navigation:
- `next_object`
- `prev_object`
- `next_filter`
- `pathability_filter`
- `pathfind_adjacent:X,Y`
- `auto_walk`

Path/debug recovery:
- `report_path_state`
- `inspect_tile:X,Y`
- `inspect_move:DIR`
- `report_runtime_blocks`
