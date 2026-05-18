# Emulator Bakeoff

This folder records same-save emulator comparison runs for Dragon Warrior
playability. Use the raw battery save baseline at
`project_resources/saves/emulator_bakeoff/dw1_bakeoff_king_save_2026-05-18.sav`
for both emulator paths.

## Task List

1. Autowalk from Tantegel Castle stairs to the entrance, then back.
2. Walk to the sage and have dialogue.
3. Flip quickly through object navigator entries and switch modes with
   `Shift+O`.
4. Walk outside, teleport/setup for Rimuldar-area overworld travel, route
   between a few waypoints, and play a real fight.

## FCEUX Run - 2026-05-18

Status: passes the first player-feel pass.

Player notes:
- Tantegel route test had no visible lag. Both routes completed smoothly, with
  one small seam bump that the script recovered from.
- Sage/dialogue test had no emulator lag. Dialogue speech was a little delayed,
  but this looks like script timing/polish rather than emulator performance.
- Object navigator stress had no lag and mode switching felt correct.
- Overworld/autowalk/combat had no lag. Some overworld autowalk segments popped
  out before hard seams, but this looks like route/seam logic, not FCEUX.
  Combat also felt responsive.

Log evidence from `dw_debug.log` started at `2026-05-18 15:14:59`:
- Start marker: frame `03360`,
  `INPUT_STATUS tag=bakeoff_fceux_start keys=LeftAlt joy1=- left_alt=true`.
- Start position: frame `03540`,
  `POSITION: map=0x05(Tantegel Castle Throne Room) x=3 y=4`.
- Recovery helper briefly cleared the latch at frame `04200`
  (`left_alt=false`), but FCEUX relatched by frame `04440`.
- End marker: frame `83760`,
  `INPUT_STATUS tag=bakeoff_end keys=LeftAlt joy1=- left_alt=true`.
- Final position: frame `84480`,
  `POSITION: map=0x01(World Map) x=87 y=69`.
- Stale Alt remained quarantined: 10 `INPUT_STALE_ALT_IGNORED` entries and
  10 `INPUT_STUCK_ALT` entries in the bakeoff window, all `spoken=false`;
  no `spoken=true` stuck-Alt warnings appeared.
- Bridge input stayed balanced: 57 `INPUT_EXTERNAL_BRIDGE_ACTIVE` entries and
  57 matching `INPUT_EXTERNAL_BRIDGE_CLEAR` entries in the bakeoff window.
- No `WARNING`, `ERROR`, `AUTO_WALK_FAILED`, `CMD_TIMING`, or
  `ROUTE_PLAN_TIMING` entries appeared in the bakeoff window.
- Castle/sage route actions queued and completed to face targets, including
  `AUTO_WALK_FACE target=Exit to World Map` and
  `AUTO_WALK_FACE target=Sage`.
- Eight `AUTO_WALK_NO_PATH_DETAIL` entries occurred while targeting
  `Exit to World Map`, all with `reason=stationary_npc_blocker`; treat these
  as route/object-state issues, not emulator failures.
- Rimuldar route navigation logged one completed overworld waypoint and two
  blocked events on the next waypoint near `(93,49)` and `(93,52)`. Manual
  movement later pushed through nearby seams, matching the player observation
  that this was route/seam behavior rather than lag.
- Three battle starts were logged. The run included a Magidrakee that ran away,
  a Magidrakee defeat, and a Skeleton defeat. Combat menu and A-button bridge
  input stayed responsive.
- `report_scan_stats` under FCEUX returned
  `SCAN_PROFILE unavailable: not running under BizHawk`, so BizHawk-style scan
  timing is not available for the FCEUX side.

Current FCEUX verdict:
- FCEUX still has the native `LeftAlt` latch, but this run supports the
  quarantine model: it did not cause menu focus trouble, speech spam, player
  movement, route contamination, or combat/menu lag from a player's
  perspective.
- FCEUX is now the default normal gameplay launcher again. BizHawk remains the
  explicit automation/debug path.

## BizHawk Run

Status: functionally passes, but loses the first player-feel pass to FCEUX.

Player notes:
- Save data transferred correctly. Startup had a bit of lag when the game
  initialized, but it was not a major concern.
- Tantegel route test completed, but route start, a few seconds into autowalk,
  and seam crossings caused lag spikes / audio cut-outs around 1-2 seconds.
- Dialogue with the sage had no noticeable lag and worked as expected.
- Fast object navigation worked well. Switching object modes with `Shift+O`
  caused a burst of lag between swaps, roughly around one second.
- Small lag spikes appeared when entering/exiting maps.
- Overworld route planning and autowalk felt lag-free once underway.
- Combat mostly worked well. Opening the spell menu and cycling spells caused
  small lag spikes.
- While an autowalk was active, canceling from the wrong window was awkward;
  sending `./dw_commands.sh stop_auto_walk` successfully stopped the route.

Log evidence from `dw_debug.log` started at `2026-05-18 15:45:15`:
- Start marker: frame `00060`,
  `INPUT_STATUS tag=bakeoff_bizhawk_start keys=- joy1=- left_alt=false`.
- Baseline loaded correctly: after title load and king dialogue,
  `POSITION: map=0x05(Tantegel Castle Throne Room) x=3 y=4` at frame `01980`.
- Scan stats were reset at frame `01740`.
- User run marker: frame `12060`,
  `INPUT_STATUS tag=bakeoff_start keys=- joy1=- left_alt=false`.
- End marker: frame `67680`,
  `INPUT_STATUS tag=bakeoff_end keys=- joy1=- left_alt=false`.
- Final position: frame `68700`,
  `POSITION: map=0x0B(Rimuldar) x=24 y=7`.
- Follow-up marker: frame `72900`,
  `INPUT_STATUS tag=bakeoff_bizhawk_end keys=- joy1=- left_alt=false`.
- No stale-Alt events, stuck-Alt events, external bridge events, warnings, or
  errors appeared in the BizHawk log.
- Route/autowalk evidence matched the player lag reports:
  - 7 `AUTO_WALK: queued` entries.
  - 2 `ROUTE_PLAN_TIMING` entries:
    - Tantegel stairs route: `ms=550.000`, `path_len=9`.
    - Rimuldar weapons merchant route: `ms=1268.000`, `path_len=26`.
  - 24 `SEAM_BRUTE_FORCE` entries.
  - 23 `AUTO_WALK_TIMING_RETRY` entries.
  - 3 `PATH_RUNTIME_BLOCK` entries.
  - 4 overworld `event=blocked` entries followed later by 2
    `event=complete` entries.
  These support the user's observation that BizHawk gets noticeably rough when
  route/seam retry work happens.
- Object navigation logged 28 `object_nav_speech queued` entries and 28
  matching flushes. There is no explicit `Shift+O` timing marker in the log,
  so the mode-switch lag is preserved as player-observed evidence.
- Combat logged one Warlock fight. Menu state advanced through `FIGHT`,
  `SPELL`, `ITEM`, back to `SPELL`, read the spell list (`Heal`, `Hurt`,
  `Sleep`, `Radiant`), returned to `FIGHT`, and completed the fight. This
  matches the player note: combat works, but spell menu navigation can hitch.
- Post-run scan report:
  `PPU_STATS reads=149279028 cache_hits=103853042 cache_misses=45425986
  direct_reads=0 domain_reads=45429226 bulk_reads=1627656
  bulk_bytes=45302434 cache_flushes=67844`.
  `SCAN_PROFILE none` was reported because `start_scan_profiling` was not
  running during the test.

Current comparison:
- FCEUX is the better player-feel emulator in this bakeoff: no observed lag in
  the same task loop, smooth object navigation, and responsive combat. Its
  native Alt latch remains present, but stayed quarantined and benign.
- BizHawk remains valuable for automated debugging because startup and script
  loading are reliable, SaveRAM seeding works, input starts clean, and script
  reload/profiling support is better. It should stay available as the debug
  emulator even if FCEUX becomes the gameplay default.
- Normal gameplay launches have been switched back to FCEUX. BizHawk remains
  the automation/debug path.
