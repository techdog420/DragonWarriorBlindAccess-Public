# Playtesting Notes

Updated: 2026-04-30

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

## Initial Gameplay Pass Checklist

Use this as a lightweight first pass:
- Start or load a normal early-game state
- Confirm speech backend readiness with `speech_status`
- Confirm player state with `report_position` or `log_state`
- Navigate around the starting castle/interior without visual assumptions
- Interact with the king/throne-room objects if available
- Use stairs/doors/exits intentionally
- Visit the first town and interact with NPCs/shops if reachable
- Enter a simple combat encounter and evaluate narration
- Record every point where the player would feel lost, under-informed, or unable to recover

## Open Gameplay Issues

### GP-001

Severity: High

Area: Emulator default / BizHawk performance

Status:
Substantially improved. First clean early-game flow confirmed manually on
2026-04-30. Basic manual testing on the first two maps after the BizHawk
conversion found scripts behaving as expected, with emulator audio stuttering
still present under heavier load.

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
- Focused wrap-up validation after making `N` cheap and object browsing brief
  passed `luac -p hotkeys.lua objects.lua route_manager.lua config.lua
  test_hotkeys.lua`, `lua test_hotkeys.lua`, `lua test_route_manager.lua`,
  `lua test_objects.lua`, and `git diff --check`.

Recommended next step:
- Continue real early-game playtesting past the first two maps. Treat remaining
  audio stoppages under load as the main BizHawk tuning target unless
  `CMD_TIMING` or scan stats show a new script spike.
- While testing object navigation, rapidly tap J/L and listen for reduced audio
  hitching. Use K to speak the current selection immediately. If the short delay
  feels worse than the old behavior, set `object_nav_speech_coalesce_frames=0`
  in `dw_access.ini` and reload the script.
- Keep the current BizHawk audio trial settings for now. Apply future config
  patches while EmuHawk is closed; live edits can be overwritten when the
  emulator exits.
- Good next experiments: tune BizHawk audio buffer/throttle settings, then
  compare one clean repro at a time with `reset_scan_stats` /
  `report_scan_stats` and fresh `CMD_TIMING` lines.

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
- `pathfind_adjacent:X,Y`
- `auto_walk`

Path/debug recovery:
- `report_path_state`
- `inspect_tile:X,Y`
- `inspect_move:DIR`
- `report_runtime_blocks`
