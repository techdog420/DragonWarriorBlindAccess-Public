# Project Memory

Updated: 2026-05-16

This file contains durable project knowledge for the Dragon Warrior accessibility mod. It is intended to be stable, concise, and repo-native. Use `session_handoff.md` for current state and `PLAYTESTING.md` for active gameplay notes.
Use `TASKS.md` for lightweight future-work/backlog items that should not
interrupt the active debug loop.

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
- Prefer service-grade routing over perfect map completion. Prioritize viable
  paths to merchants, inns, exits, stairs, locked doors, chests, and other
  essential services. Leave unreachable dialogue-only NPCs for polish unless
  they provide a progression clue, required hint, or other gameplay-critical
  information.
- Continue improving pathfinding when real gameplay exposes issues, but avoid broad unrelated refactors.
- Before starting a new map or major new floor, check external map/walkthrough
  guidance for the intended route and special conditions. Prefer a visual or
  decoded map image when available, with text notes captured in the handoff for
  blind-friendly reuse. Use it as orientation only; live movement evidence
  still controls permanent map data.

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

## Object Navigation Policy

Object focus should represent the player's selected target, not an internal
route marker. Overworld route guidance may add `route_*` waypoint objects to
the Travel list and may request a deferred object refresh, but it should not
automatically switch filters or select the active waypoint. If the player
selected a landmark such as Garinham or Erdrick's Cave, that destination should
remain focused while `auto_walk` follows the active guided route internally.

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
- Use `--replace` for state-sensitive command batches so stale queued work does
  not contaminate the next observation
- Use `--wait PATTERN` or `--wait-ready TAG` when the next step depends on a
  fresh emulator/log state
- Use `--require-live SECONDS` when stale `dw_debug.log` output would make the
  result misleading
- Use `--json` from `dw_commands.sh` / `dw_commands.ps1` when automated harness
  code needs machine-readable sent/matched/timeout status
- A fresh `dw_debug.log` header does not prove command polling is active; verify command consumption

For state-sensitive work:
- Use short command batches
- Wait for log confirmation between steps
- Treat stale queued commands and polling delay as real failure causes
- Confirm live map id and position before map-specific conclusions

## Map Evidence Policy

Dragon Warrior's engine can produce movement timing noise on passable cells.
Route-timeout, verifier, seam-memory, and `dw_blocks.log` evidence must remain
diagnostic until a human deliberately promotes a specific map-scoped cell or
edge. Current policy:
- Permanent map edits belong under the correct `map_id` in `map_reader.lua`.
- Use passthrough cells for directly confirmed false walls.
- Use directional blocks for directly confirmed engine walls.
- In Brecconary Merchant 4 work, manual confirmation remains the tiebreaker for
  suspect route seams. Validation-only noise kept `(25,23).north` open, while
  manual-confirmed blocks such as `(21,25).east`, `(23,23).north`, and
  `(26,28).east`, `(27,29).north`, and `(28,28).west` are promoted
  directionally.
- Runtime blockers are added only by explicit commands such as
  `add_blocked_tile` or `add_blocked_edge`.
- `dw_blocks.log` is legacy/forensic and is ignored unless
  `auto_step_record_debug_blocks=true`.
- Blocked-only seam memory is diagnostic-only; reroute may temporarily avoid
  the edge it just hit, but same-session seam noise must not become route truth.
- Manual tap-to-step should not add extra pressure into static blockers the map
  model already knows about. `auto_step.lua` refuses manual tap extensions into
  permanent and directional static blocks with `AUTO_STEP_REFUSED_STATIC_BLOCK`,
  while debug/probe `inject_step` still intentionally tests those edges.
- Physical `manual_tap` must also release synthetic D-pad input after an early
  movement-subpixel twitch; otherwise unmodeled walls and live NPC blocks can
  keep playing collision input after the player has released the key. Keep the
  conservative early-twitch hold for debug/probe `inject_step` and queued route
  verification, where false blockers are more damaging than a brief probe hold.
- If a physical `manual_tap` has already seen an early movement-subpixel twitch,
  do not schedule the same-direction turn-repress recovery; that re-press can
  recreate the wall/NPC collision hold that the early release just avoided.
- Released physical `manual_tap` wall/NPC bumps should not publish blocked seam
  evidence. If a movement-subpixel twitch has happened but the tile has not
  changed after a short wait, silently cancel the manual step before the normal
  blocked timeout path; keep blocked-event publication for debug/probe
  injection and queued routes.
- Physical `manual_tap` needs a short post-twitch hold on open floor. Releasing
  immediately after the first early subpixel twitch made some ordinary taps fail
  to move at all. `auto_step_manual_early_hold_frames` caps that extra hold
  while preserving the no-repress and silent-cancel wall/NPC protections.
- `validate_path` evidence is also diagnostic. The validator must wait for an
  active `auto_step` before retrying and must cancel injected auto-step state on
  abort so validation failures do not write stale seam observations. Validation
  may force-release injected D-pad state after success/abort, but normal manual
  cancel behavior must not be changed.
- Route-settle `route_drift_off_path` during object auto-walk is execution
  drift, not map evidence by itself. Recover by replanning from the drifted
  tile to the same active target and log `AUTO_WALK_DRIFT_REROUTE`; only promote
  map data when independent movement evidence supports it.

## Codex Tooling Contract

Codex is the primary project agent; Claude-style docs are legacy fallback
context only.

Durable tooling facts:
- `AGENTS.md` is the repo contract; `session_handoff.md`,
  `PROJECT_MEMORY.md`, and `PLAYTESTING.md` are the durable project truth
  sources.
- `.codex/config.toml` should keep project safety/tooling defaults only.
  Model choice, memory enablement, and account-level trust belong in global
  Codex config.
- Repo-local hooks live under `.codex/hooks/` and are enabled by
  `.codex/hooks.json`. Hook commands should resolve the git root before
  invoking scripts so Codex can start from subdirectories.
- The live-command guard is a safety rail, not a full enforcement boundary.
  Keep the real rules in `AGENTS.md` and docs, and keep the guard focused on
  catching common hazardous command shapes.
- Repo-specific Codex skills belong under `.agents/skills/`. The
  `dw-debug-loop` skill should stay BizHawk-first and should only trigger for
  live emulator/log/timing workflows, not ordinary static edits.

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
  script; confirm reloads with a fresh `launcher_probe:TAG`. `main.lua` now
  clears project modules from `package.loaded` before requiring them because
  BizHawk console/script reloads can otherwise keep stale required-module code
  alive while re-running only the main chunk. When clearing/reloading the
  compatibility adapter, prefer real BizHawk API markers over the shim-created
  `FCEU` global; stale shim globals can survive a reload and make the adapter
  misdetect BizHawk as FCEUX, disabling scan throttling. Also unwrap prior
  adapter closures for `joypad`, `input`, `memory`, and `ppu` before installing
  a fresh shim; otherwise a reload can capture its own wrappers as "native" and
  break controls or cache aging. Under BizHawk, replace `FCEU.frameadvance` on
  every adapter load so the active PPU cache flushes on the current frame hook.
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
- Avoid assigning player-facing BizHawk hotkeys to `P` on this machine. The
  local BizHawk config binds global Quick Load to `P`, and `Shift+P` proved
  unreliable during live play. The project position/read-location hotkey is now
  `Shift+W`.
- Object pathability filtering is a second layer over the normal object
  category filter. `Shift+O` cycles All, Reachable, and Unreachable; the
  command-file hook is `pathability_filter`. It computes reachability on
  demand through `route_manager.lua` with shared NPC-free blocking, then lets
  `objects.lua` filter from cached statuses so rapid J/K/L browsing stays
  cheap. Moving NPC occupancy is intentionally ignored so wandering NPCs do
  not hide otherwise reachable targets.
- Manual overworld route guidance lives in `overworld_routes.lua`, not in the
  interior A* pathfinder. The player-facing hotkey is `R`: select a supported
  Travel destination such as `Erdrick's Cave`, `Garinham`, `Brecconary`, or
  `Tantegel Castle`, then press `R` to start guidance or press it again for
  active route status/recalculation. If an active route exists and the
  selected Travel object resolves to a different guided destination, `R`
  replaces the active route instead of leaving stale waypoints in control. If
  the active waypoint is selected and the player has drifted far from it, `R`
  recalculates the next route marker from the current world-map position.
  Command-file equivalents
  are `route_guidance`,
  `start_overworld_route:cave` (aliases `erdrick` and `erdric`),
  `start_overworld_route:garinham` (aliases `galenholm`, `galen`, and
  `garin`),
  `start_overworld_route:brecconary` (alias `breconary`),
  `start_overworld_route:castle`, `route_status`, `route_recalculate`, and
  `stop_overworld_route`.
  Overworld Travel landmarks also participate in same-map teleport support:
  selected-object teleport can land on the current world-map Travel object, and
  debug command `teleport_landmark:NAME` (alias `teleport_overworld:NAME`)
  resolves a named landmark by exact name, object id, or unique prefix. These
  trusted Travel targets intentionally bypass map-reader walkability because the
  world map does not expose reliable interior-style tile metadata here. Keep it
  world-map only; it should refuse from towns/caves rather than cross-map warp.
  First-phase overworld auto-walk now reuses the active guided route: `auto_walk`
  on the world map asks `overworld_routes.plan_next_segment()` for a short
  straight segment to the next waypoint and queues those steps through
  `auto_step`. It intentionally stops rather than rerouting when a blocker is
  encountered, and `can_walk_false` cancels the segment quietly so battle/menu
  narration remains in charge. This is not full world-map A* yet.
  In FCEUX, be careful with the stuck-Alt external keyboard bridge: neutral raw
  bridge frames must not suppress `auto_step.update`, or queued routes will log
  `OVERWORLD_AUTO_WALK: event=start` but never begin stepping. The bridge should
  only suppress auto-step for raw frames that actually contain a button.
  Active route waypoints are
  injected as a small Travel layer, currently capped at the next two markers,
  so the player can browse guidance without cluttering the major destination
  list. The Erdrick route deliberately includes mountain-pinch intermediate
  markers (`East choke approach`, `Eastern mountain lane`, `North ridge bend`)
  because a straight heading from the pinch led the player into blocked
  mountain tiles. The east-choke and eastern-lane markers are exact-tile
  markers at `(35,32)` and `(35,24)` because radius-based arrival consumed
  them one tile west and made the next leg turn too early. It also routes
  through `Bridge south bend`, `Bridge lower west lane`, `Bridge west bend`,
  and `Upper bridge lane` before `East choke approach`; live evidence
  showed the direct first-bridge-to-pinch leg blocked north from `(45,34)` into
  `(45,33)`, and the early lower-detour version tempted blocked north moves
  from `(41,35)`, `(40,35)`, and `(39,35)`. The old `Mountain pinch turn`
  marker caused a short west-then-east reversal near the east choke, so it is
  no longer mandatory on the bridge/east-choke segment. The Brecconary and
  Tantegel Castle safety routes reverse those markers from the cave side, then
  use `Upper bridge lane`, `Bridge west bend`, `Bridge lower west lane`, and
  `Bridge south bend` before heading directly to safety. The old return-route
  marker at `(45,34)` was removed because it caused a north-then-south
  backtrack. Safety routes complete on destination maps `0x08` for Brecconary
  and `0x04` / `0x05` for Tantegel Castle. The Garinham / Galenholm route
  reuses the proven bridge and Erdrick's Cave lane, then adds northwest
  markers through `Garinham east field` `(20,9)`, `Garinham ridge entry`
  `(19,6)`, `Garinham east ridge` `(16,6)`, `Garinham shoulder bend`
  `(16,5)`, `Garinham shoulder east step` `(15,4)`, `Garinham mountain
  shoulder` `(14,4)`, `Garinham north coast lane` `(14,3)`, `Garinham north
  coast west lane` `(8,3)`, `Garinham outskirts` `(5,4)`, `Garinham approach`
  `(2,2)`, and the town at `(1,2)`. The `(2,2)` tile is only the north-south
  approach corridor; use the western guide coordinate for the actual Garinham
  landmark. Brecconary and Tantegel Castle safety routes include those markers
  in reverse so a route back from Garinham can start with the selected safety
  destination. Garinham completes on map `0x09`. Entering
  Erdrick's Cave maps `0x1C` / `0x1D` completes the first-dungeon route even
  if the world-map final tile was not observed before the map transition. `O`
  should remain the plain heading/path preview, and `U` should remain
  available for future overworld auto-walk until the world-map decoder and
  encounter-flow behavior are proven live.
- The Garinham-to-cave-road leg should not be a single diagonal target.
  Live grinding showed south moves from `(19,7)` and `(21,11)` timing out,
  while east-first movement through `(20,7)`, `(21,10)`, `(23,11)`, and
  `(23,13)` worked. Keep the explicit `Garinham field east lane`,
  `Garinham field road bend`, `Cave road north edge`, `Cave road west lane`,
  and `Cave road south lane` markers in `overworld_routes.lua`; they are route
  evidence, not permanent world-map blocked-tile data.
- The first Kol route should not use the direct east pocket from Brecconary.
  Live raw holds from `(57,38)` blocked east into `(58,38)` and also blocked
  north/south, with nearby row-39/40 and north-branch checks dead-ending. Keep
  Kol on the Galenholm/Garinham-style north road: proven western bridge/cave
  road first, then the lower northeast bridge lane before the southwest bridge
  toward Kol. Northeast bridge evidence is route-lane evidence, not permanent
  world-map blocked-tile data: `(59,19)->(60,19)`, `(61,19)->(61,18)`, and
  `(60,19)->(60,18)` moved live, while route attempts from the north/row-18
  pinch blocked or pulled back. The route should avoid vertical-first entry
  into `(60,18)` from `(60,17)`.
- The Kol south-road leg should not target `(90,30)` after the southwest
  bridge. Live player movement from the first Kol run worked around the old
  pullback by going east from `(90,37)` and then north through the x=92/93/96
  lane: `(92,37)`, `(92,36)`, `(93,36)`, `(93,35)`, `(96,35)`, and `(96,32)`.
  Treat `(96,32)` as the south-road marker and continue north toward
  `(96,21)`. After this lane patch and reload, the user reached Kol and a fresh
  position probe confirmed `map=0x07(Kol) x=19 y=23`.
- The Swamp Cave overworld route is Kol-side, not an all-map route.
  External orientation puts the entrance south of Kol near the bridge, and
  Gamer Corner's coordinate `(1S,61E)` matches the existing Travel landmark at
  `(104,44)`. `overworld_routes.lua` should stage far starts through Kol, then
  use the proven Kol south-road chain before the cave spur. From Kol, start
  through `Kol forest west edge`, `West of Kol north lane`, `Kol south road`,
  and `Kol south road east lane`, then back out through `(93,35)`, `(93,36)`,
  `(92,36)`, and `Kol bridge east lane` instead of entering the old x104 north
  pocket. Live probes showed the old `(100,35)->(104,39)->(104,42)` spur can
  route into a blocked pocket; later live testing also proved the x92/x93 drop
  into row 41 is blocked. The corrected lower approach descends to `(94,40)`,
  drops at `(94,40)->DOWN` to `(94,41)`, crosses the rechecked row-41 lane to
  `(97,41)`, then uses `(97,42)`, `(102,42)`, `(102,43)`, and `(104,43)` before
  stepping down into the cave at `(104,44)`. Do not route into row 41 at x92 or
  x93; enter at x94 or farther east. Keep the bridge-side variant for starts
  around `Kol southwest bridge`; it should join the same lower approach at
  `Kol bridge east lane`. The route completes on Swamp Cave map `0x15`; live
  play reached that map after the x94 patch. The return to Kol uses
  `kol_swamp_cave`, sharing the `overworld_kol` destination. It reverses the
  cave spur through `(104,43)`, `(102,43)`, `(102,42)`, `(97,42)`, `(97,41)`,
  `(94,41)`, and `(94,40)`, then uses horizontal-first routing back to
  `(92,37)` so it follows the verified row-40/bridge-lane path before returning
  through the Kol south-road and forest waypoints to `(104,10)`. The user
  tested the Swamp Cave route in both directions live; remaining issues are
  polish-level rough edges, not major blockers.
- Swamp Cave (`map 0x15`) interior is a 6x30 one-floor tunnel. Guide
  orientation puts the north entrance at `(1S,61E)` and south exit at
  `(6S,61E)`, with one locked door, no chests, and Princess Gwaelin behind a
  Green Dragon side objective. Live play and user testing showed the `x=0`
  corridor is passable in both directions from `(0,0)` through `(0,25)`, where
  south access ends, so `MAP_PASSTHROUGH_CELLS[0x15]` models
  `x=0,y=0..25` as walkable despite the generic interior boundary rule.
  Later live evidence corrected the south-island object coordinate twice:
  `(0,25)` is the west-corridor bend and reports no stairs, and `(5,29)` is only
  the bottom-right alcove. The ROM up-stair table entry `15 00 1D` at file
  offset `0xF486` points to the actual south-island stairs at `(0,29)`, reached
  from row 29. Swamp Cave should expose two Travel objects, `North Exit to World
  Map` at `(0,0)` and `Stairs Up to South Island` at `(0,29)`. A later
  south-exit return-route log proved `(0,28)` passable, while `(0,26)..(0,27)`
  stay closed until live movement proves otherwise. `MAP_DIRECTIONAL_BLOCKS`
  for map `0x15` covers lower-route failed approaches into `(1,24)`, `(1,27)`,
  `(2,28)`, and `(2,27)` so A* avoids the loop-prone seams. A later auto-walk
  loop toward `Stairs Up to South Island` repeatedly bounced between
  `(1,26)->DOWN` into `(1,27)` and `(2,26)->DOWN` into `(2,27)`, with queued
  route and seam-retry failures, so `(1,27).north` and `(2,27).north` are also
  modeled as directional blocks. The south-exit
  stairs path from the row-29 exit area lands on the world map at `(104,49)`,
  exactly five tiles south of the known north entrance `(104,44)` and consistent
  with the guide coordinate pair `(1S,61E)` / `(6S,61E)`. World-map Travel
  should expose `Swamp Cave South Entrance` at `(104,49)` separately from the
  north `Swamp Cave` landmark at `(104,44)`. Later live route looping produced
  working auto-walk routes between `North Exit to World Map` and
  `Stairs Up to South Island` in both directions. Treat later lower-route
  entries that time out after movement starts and then move on seam retry as
  timing noise unless a fresh direct verifier proves the edge blocked-only.
  Realm of Darkness' Swamp Cave map places Gwaelin and the Green Dragon behind
  the lower-right branch door. The first `(5,22)` coordinate hypothesis was
  disproven live: from `(5,23)`, OPEN reported "There is no door here."
  Follow-up no-key OPEN probes from `(5,21)` and `(5,19)` both reported "Thou
  hast not a key to use." DW1's OPEN routine checks only the four adjacent
  cells, so the shared adjacent coordinate is the confirmed door cell `(5,20)`.
  Model `Gwaelin Door` at `(5,20)` with the normal route stand `(5,21)` facing
  north. A later south-stairs-to-door auto-walk loop exposed two more confirmed
  lower-branch directional seams: `(3,22).south` blocks entry from `(3,23)`,
  and `(4,23).west` blocks entry from `(3,23)`. With those modeled, live
  `debug_pathfind` routes work between the `Gwaelin Door` stand and both cave
  exits in both directions. A later post-battle loop from `(3,26)` confirmed
  `(4,24).west` as another real lower-branch directional seam; `(2,22).south`
  had mixed verifier results and should not be promoted without stronger
  evidence. The next loop at `(5,23)` confirmed `(5,22).south` and
  `(4,23).east` as additional blocked approach seams, both with 3/3
  `probe_edge_verify` results; static routes still detour from `(5,23)` to the
  door stand through `(5,24)->(4,24)->(4,23)->(4,22)->(4,21)->(5,21)`.
  The next lower-branch loop confirmed `(4,24).south` from `(4,25)->UP` with a
  3/3 verifier, while `(4,24).east` from `(5,24)->LEFT` stayed mixed despite
  heavy loop evidence. Keep `(4,24).east` runtime-only unless a future verifier
  reaches consensus.
  The following lower-left detour run promoted more confirmed approach-only
  seams: `(2,22).south`, `(1,22).south/west`, `(1,21).west`, `(1,20).west`,
  and `(1,19).west`, all from 3/3 `probe_edge_verify` results. The next
  candidate re-entry was row 18, but manual follow-up confirmed the x=0 east
  re-entry stays blocked through row 9 and first opens at `(0,8)`. Model
  `(1,9).west` through `(1,18).west`, while keeping `(1,8).west` open.
  The Green Dragon fixed encounter is log-confirmed at `(4,14)`: after
  auto-walk reached `(4,14)` and attempted `DOWN`, battle started at field
  position `(4,14)`, followed by `A Green Dragon draws near!`. Later restarts
  also reported Green Dragon snapshots at `(4,14)`, so the dragon is on the
  rescue branch before the door-route continuation rather than behind the door.
  Random encounters can still interrupt auto-walk. If a touch-plus-probe
  source reload appears to succeed but `inspect_move` still lacks those latest
  disk directions, inject matching runtime edges or manually reload before
  judging the live session.
- Rimuldar is the next south-island target after Swamp Cave. Gamer Corner lists
  Rimuldar at `(29S,59E)`, which maps to local world coordinate `(102,72)` from
  the current Tantegel anchor. Rimuldar has an inn for 55 G, 2 locked doors,
  Wings treasure, a Weapons/Armor shop, and the first Magic Key shop that does
  not require a key; Magic Keys cost 53 G there. Mike's RPG Center agrees on
  the 53 G Magic Key shop and lists the weapon/armor stock as Copper Sword,
  Hand Axe, Broad Sword, Half Plate, Full Plate, and Magic Armor. Gamer Corner
  recommends the west route around the craggy mountains from the Swamp Cave
  south side because it is safer, and warns that the Rimuldar area is dangerous
  for a level 8-9 hero; SLEEP is useful on the approach. `overworld_routes.lua`
  has live-corrected route guidance `rimuldar` and `swamp_cave_south` between
  `Swamp Cave South Entrance` `(104,49)` and Rimuldar `(102,72)`. First
  shakedown evidence showed the initial `(104,49)->LEFT` seam was noisy but
  passable, then found two real route-shape bugs: the old `(92,56)` notch made
  autowalk retry blocked `(93,57)->UP`, and the old final row-72 push hit the
  north-side town wall at `(97,72)->RIGHT`. The route now drops from `(93,56)`
  to `(93,57)`, stays west through `(90,57)`, and approaches Rimuldar from the
  proven east doorstep `(103,72)->LEFT` instead of cutting straight east from
  `(90,72)`. The reverse route to Swamp Cave South Entrance is not a simple
  mirror: `(92,57)->UP` into `(92,56)` is engine-blocked, so the return now
  uses the live-probed west-pocket detour through `(85,58)`, `(85,56)`,
  `(83,56)`, `(83,54)`, `(86,54)`, `(86,52)`, `(92,52)`, `(92,48)`,
  `(100,48)`, `(100,50)`, and `(104,50)`, with a recovery route for starts or
  recalculations at the bad notch. First Rimuldar service proof: `Merchant 2`
  occupies `(23,7)` and
  is the weapon/armor shop, opened from public counter stand `(23,9)` facing
  north. Live inventory is Copper Sword 180 G, Hand Axe 560 G, Broad Sword
  1500 G, Half Plate 1000 G, Full Plate 3000 G, and Magic Armor 7700 G. The
  Rimuldar town exit is not the old `(15,14)` object; that tile is ordinary
  interior floor. Live edge proof from `(29,13)->RIGHT` changed to the world
  map and landed at `(102,72)`, so model Rimuldar's `Exit to World Map` at
  `(29,13)` with east-facing interaction. A follow-up user check confirmed the
  corrected exit object lines up from inside town.
- Kol service work should start from `project_resources/maps/kol/README.md`,
  which now has local map images and a screen-reader service transcription.
  External guides agree on these first priorities: Inn 20 G, weapon/armor shop
  selling Copper Sword, Hand Axe, Half Plate, Full Plate, and Small Shield,
  item/tool shop selling Herb, Torch, Dragon's Scale, and Wings, and the Fairy
  Flute hidden four steps south of the bath. Treat those guide facts as
  orientation; patch `objects.lua` only after live survey/TALK evidence proves
  service NPC slots, public stand/facing tiles, exit coordinates, and hidden
  search-tile coordinates.
- Kol's Fairy Flute search tile is modeled at `(9,6)`. Evidence: `Woman 2`
  at `(12,1)` says the bath cures rheumatism, Mike's local Kol map has the
  only blue bath/water tile at `(9,2)`, guide wording says four steps south of
  the bath, live `inspect_tile:9,6` reported walkable, and
  `debug_pathfind_to:9,6` from `(1,22)` found a route. `objects.lua` exposes
  it under Treasure with the player-facing label `Disturbed Earth Near Bath`
  so the hidden reward is not spoiled before SEARCH succeeds.
- The harp/Staff of Rain target west of Kol is an overworld shrine/cave, not a
  Kol town cellar. The existing Travel landmark is `Northern Cave` at `(81,1)`,
  and entering it uses map `0x0D` (`Rain Shrine`). `overworld_routes.lua` now
  has a Kol-side `northern_cave` route with aliases such as `rain shrine`,
  `staff of rain`, `harp shrine`, and `cave west of kol`. First live testing
  showed the short `(88,6)->(83,3)` approach was wrong: from the east-shore
  pocket around `(91,5)`, the route must recover south and west around the
  water/mountain gap before approaching `(81,1)`. The user reached the cave
  live after this change. Returning to Kol from the shrine needs its own
  reverse variant, `kol_rain_shrine`; otherwise the plain `kol` chain can snap
  to the far southern Kol approach. Route recalculation may switch between
  same-destination variants based on the current world-map position. Do not
  treat Northern Cave as an all-overworld route yet: from far starts such as
  Tantegel, start the Kol route first and tell the player that Northern Cave
  starts from Kol. Keep this staged-hub behavior until a real overworld route
  graph replaces the current ordered waypoint chains.
- Rain Shrine / Northern Cave map `0x0D` has the wise man / old man at `(4,4)`
  and the live bottom entry/exit tile at `(4,9)`. The first old-man route pass
  proved the south approaches into row 6 are engine-blocked even though the
  ROM/model marks those cells as walkable tile `14`; keep `(2,6).south`,
  `(3,6).south`, `(4,6).south`, and `(5,6).south` as directional-only blocks
  so side approaches remain usable. A later loop proved the west face of the
  same hidden wall cluster: keep `(2,3).west`, `(2,4).west`, `(2,5).west`, and
  `(2,6).west` as directional-only blocks, while preserving the open movement
  along column `x=1`. The later manual route to the old man proved a top-wall
  approach too: keep `(3,2).north`, `(4,2).north`, `(5,2).north`, and
  `(6,2).north` as directional-only blocks; the valid detour goes east along
  row 1, descends on the far east side, and returns west along row 4. The
  route back out then verified `(5,5).north`, `(5,5).east`, and
  `(6,6).north` as blocked 5/5. After live injection of those edges, the next
  reroute verified `(7,5).west` and `(7,5).north` as blocked 5/5. A later
  entrance-to-old-man pass verified `(6,6).south` and `(7,6).south` as blocked
  5/5. Keep them directional-only, with `(6,4).west/south`, `(6,5).north`,
  `(6,7).east/west`, `(7,4).west`, and `(7,7).west` open. Final noisy
  cleanup promoted `(7,6).east`, `(5,3).east`, `(7,5).east`,
  `(7,9).north`, and `(6,9).north` after raw 5/5 verifiers; keep
  `(5,3).south` open because its raw verifier was mixed/passable, and keep
  `(8,9).north` open because its raw verifier hit a map-change case instead
  of a stable block. Follow-up playtest reported both old-man routes complete
  smoothly; the one recovered return-route reroute is polish-level, and the
  remaining chest access is progression-gated by the old-man interaction.
- The route system can model positional variants for the same Travel target.
  `Tantegel Castle` now has a Kol-side `tantegel_kol` variant that shares
  `overworld_tantegel_castle`; object and alias route starts score matching
  variants by their nearest next waypoint so Kol starts do not snap to the
  Garinham/cave-road safety branch.
- Kol's live town entry/exit is `(19,23)`, not the old `(15,14)` placeholder.
  Entering from the world map lands at `(19,23)`, moving south from `(19,23)`
  exits town, and movement from `(19,22)->(19,23)` plus `(19,23)->(20,23)`
  proved the bottom strip is engine-passable despite type-0 ROM tiles. A later
  pathability-filter repro from live `(18,23)` proved the west neighbor is also
  part of this strip; keep `(18,23)`, `(19,23)`, and `(20,23)` as map-0x07
  passthrough cells.
- The first Kol parked survey exposed a tight route loop near Person 1:
  `(20,17)` blocks from the south and `(21,18)` blocks from the west. The
  stopped run logged 51 and 50 blocked observations respectively, while
  surrounding entry-lane seams had moved evidence. Keep these as directional
  blockers only; do not promote whole cells from that survey.
- Kol west-NPC browsing after the service pass exposed Old Man 1 at object
  `(2,13)`, with route loops between `(8,11)` and `(8,12)` trying west into
  `(7,11)` and `(7,12)`. Keep `(7,11).east` and `(7,12).east` as map-0x07
  directional blockers only; the `(8,11)<->(8,12)` vertical connector moved
  repeatedly and stays open.
- Merchant 1 routing in Kol has narrow directional wall evidence from two live
  autowalk runs. Keep these map-0x07 blockers directional-only: `(10,18).east`,
  `(10,19).east`, `(11,20).north`, `(12,19).west`, `(16,21).east`,
  `(16,20).east`, `(16,19).east`, `(10,16).east`, `(10,16).north`,
  `(9,16).north`, `(8,16).north`, and `(7,15).east`. The strongest loop was at
  `(8,15)`, where `(8,16).north` and `(7,15).east` each reached 45+ blocked
  observations with no moves. The current manual escape to `(9,15)` should not
  be treated as service-route proof beyond showing `(9,15).west` can move. A
  later retest toward adjacent goal `(11,21)` added `(12,19).north`,
  `(13,19).north`, `(15,19).north`, `(14,19).north`, and
  `(16,19).north`; keep noisy moved seams like `(15,16).west` and
  `(17,21).east` open. Merchant 4 path testing later disproved the stale
  `(16,22).east` candidate; keep the `(16,22)<->(17,22)` seam open both ways.
- Kol `Merchant 1` is dialogue-only. Live TALK after selected teleport to
  `npc_7` produced the southern-island/Rimuldar hint, not a shop or inn prompt.
  Keep him browsable under NPCs but excluded from Services; continue service
  decoding with the remaining Kol merchants. A same-turn `report_door_state`
  showed `keys=0` and no opened-door RAM slots, so do not record a confirmed
  Kol door coordinate from this NPC yet.
- Kol `Merchant 2` is the Inn. Live TALK from public stand `(19,2)` facing
  south toward `npc_12` at `(19,4)` opened the 20 GOLD inn prompt. The first
  Inn-to-exit autowalk loop exposed directional-only row-3 blockers:
  `(21,3).north` and `(22,3).north`; keep row-2 horizontal movement open. The
  follow-up retest exposed the next east-wall pair, `(23,1).west` and
  `(23,2).west`, while `(22,1)<->(22,2)` kept moved evidence. A later pass
  drifted one tile west, recovered, and exposed `(10,4).north` and
  `(11,3).west`; leave `(10,3).north` open because its retry moved and the seam
  was reclassified noisy. The reverse route from the town entrance back to the
  Inn then exposed `(21,3).south` and `(22,3).south` with `blocked=20 moved=0`
  each; keep `(21,4).east` and `(22,4).west` open because they moved repeatedly.
  The next entrance-to-Inn retest looped across row 4 and exposed
  `(23,3).south` plus `(20,4).east`, both `blocked=36 moved=0`; keep the
  row-4 connector through `(21,4)`, `(22,4)`, and `(23,4)` open. A later pass
  routed west and exposed `(11,4).south` plus `(11,4).east`; keep the connector
  around `(11,5)`, `(12,5)`, and `(12,4)` open, and treat the two-block row-5
  hits as diagnostic until they repeat. The first working noisy round trip then
  justified cleanup blockers `(10,4).south`, `(9,2).south`, `(11,3).north`,
  `(19,17).south`, and `(18,17).south`; keep noisy/moved seams like
  `(10,3).west` and `(18,18).east` open.
- Kol `Merchant 3` is the weapon/armor shop. Live proof selected `npc_13` at
  `(22,12)`, landed at public stand `(20,12)`, faced east, and opened the buy
  list. The live inventory is Copper Sword 180 G, Hand Axe 560 G, Half Plate
  1000 G, Full Plate 3000 G, and Small Shield 90 G. `objects.lua` labels map
  `0x07` `Merchant 3` as `Weapons Merchant` and routes him through `(20,12)`
  facing east.
- Kol `Merchant 4` is the item/tool shop. Live proof selected `npc_15` at
  `(14,21)`, landed at public stand `(12,21)`, faced east, and opened the buy
  list. The live inventory is Herb 24 G, Torch 8 G, Dragon's Scale 20 G, and
  Wings 70 G. `objects.lua` labels map `0x07` `Merchant 4` as `Tool Merchant`
  and routes him through `(12,21)` facing east.
- Read-only hotkey speech should avoid cutting off route progress
  announcements. `hotkeys.lua` uses non-interrupting `tolk.output` for
  position, HP/MP, level, gold, experience, stats, screen text, and `R` route
  guidance/status. During auto-step movement, `R` may still report an active
  route's status, but starting a new route or running movement-changing object
  controls remains blocked until movement is stable.
- Fast combat action dialogue should also avoid cutting off current speech.
  Keep `Battle!` and the first coherent `draws near` opening line interrupting
  so encounters are announced promptly, but queue ordinary attack, damage,
  miss/dodge, and reward text with non-interrupting speech. The FCEUX bridge log
  can confirm the policy: pre-patch multi-action rounds showed player attack,
  enemy attack, and HP-loss lines as repeated `interrupt:` commands one or two
  seconds apart.
- When adding a new safe BizHawk hotkey, update both `config.lua` defaults and
  the checked-in `dw_access.ini` allowlist. Existing explicit allowlists
  override default allowlist changes, so a newly appended key binding can still
  be filtered out until the allowlist includes its setting name.
- Visited flags live in `objects.lua` as session-only, map-scoped state. They
  survive BizHawk source reloads through `_G.DW_OBJECTS_RELOAD_STATE`, but
  still intentionally do not persist across full script restarts yet; use
  `clear_visited` and `clear_visited:all` for local cleanup during a playtest.
  Auto-marking after TALK should not rely only on cached object-list
  coordinates, because BizHawk normally disables periodic NPC object refreshes.
  If a real dialogue appears and no cached adjacent NPC matches, fall back to
  live NPC RAM slots and mark the stable `npc_N` id. Keep the pending TALK
  marker alive long enough for slow dialogue stabilization; live logs showed a
  valid NPC dialogue could arrive about 300 frames after TALK, so the marker
  timeout is 720 frames and logs explicit expiry.
- `auto_walk` is now a tester-facing feature, not only a debug hook. Long routes
  should provide periodic progress speech, completion should be spoken, and NPC
  targets may be held briefly after arrival so the player has time to use TALK.
  For adjacent interaction targets, auto-walk should also face the target after
  arrival; otherwise a route whose final step is sideways can leave the hero
  adjacent but facing away, making TALK say "There is no one there." When
  holding a moving NPC after arrival, pin the selected NPC slot to the planned
  object coordinates while preserving the encoded sprite/facing/movement bits;
  snapshotting the live slot position can hold the NPC where it wandered and
  leave the planned TALK tile empty.
- Survey-safe autowalks are different from player-facing autowalks. They should
  not perform post-arrival facing taps, target-NPC holds, or normal completion
  speech, because that synthetic input can be read by the next survey attempt
  as `live_input_interrupt` and create false `command_timing_or_state_issue`
  failures. Keep this behavior scoped to `survey_safe`; normal player routes
  should still face and hold NPCs after arrival.
- Auto-step must stay disabled for an active field command menu until the
  session really closes. The cursor tile can blink or the cursor-hold timer can
  expire while the menu remains open; treating that as walkable can turn menu
  D-pad navigation into false runtime blocked tiles around the player. Pair raw
  `COMMAND` header checks with a confirmed live menu-session flag, and clear
  that flag on TALK/menu-close so stale PPU command text does not block field
  movement afterward.
- The y<=3 interior dialogue path should not trust only its fixed row formula.
  BizHawk scroll/base state can place short TALK-failure text where the normal
  filtered lower dialogue reader sees it, while `read_y1_dialogue()` scans an
  empty row band. If the row-1 scan finds no lowercase text, fall back to the
  already-filtered lower dialogue so failures such as `'There is no one there.`
  are spoken instead of being absorbed into `prev_dialogue`. If both readers
  see lowercase text, prefer the candidate with more lowercase content; moving
  NPCs near the top of Brecconary produced a partial fixed-row read
  (`Please, save us from`) while the normal lower-window reader can hold the
  full multi-line message.
- For object reachability, the `Reachable` pathability filter is geometry-only
  and may ignore temporary live NPC occupancy by design. When auto-walk cannot
  reach a target that the filter listed as reachable, infer the no-path reason
  by checking whether an NPC-free route exists before using a generic
  closed-door frontier hint. Otherwise castle maps with nearby locked doors can
  mislabel NPC clutter as "blocked by a closed door." If the NPC-free route is
  blocked by an NPC whose movement byte is `0x00`, report it as a stationary
  NPC blocker instead of telling the player to wait.
- Brecconary (`map 0x08`) has two guide-backed locked doors that the ROM tile
  scan does not find: `Northeast Door` at `(21,6)` for the northeast building
  and `Inn West Room Door` at `(5,22)`. Mike's map labels `4) Fairy Water` in
  the center-east building and `5) Removes Curses` in the top-right building
  (local copy: `project_resources/maps/brecconary/mikesrpgcenter_brecconary.png`),
  so keep the object labels positional instead of overcommitting to a service
  name. With the current live Brecconary NPC table, door-specific static
  pathfinding from public origin `(1,15)` shows `Northeast Door` alone makes
  `Woman 1` reachable. The user manually verified `Woman 1` as the Fairy Water
  merchant, so that target is expected to be locked behind the northeast door.
  `Inn West Room Door` alone makes `Old Man 1`
  reachable at his current `(1,20)` position and also makes `Guard 4`
  reachable. Opening both modeled doors still does not route to
  `Weapons Merchant`, `Person 3`, `Person 5`, `Old Man 2`, `Merchant 4`,
  `Person 1`, or the currently no-path `Guard 2` / `Guard 3`, so those remain
  route/blocker-data follow-ups, not explained by the known locked doors.
  Closed-door no-path hints should remain target-aware: do not give key/door
  advice merely because a closed door is reachable if opening it would not make
  the selected object reachable.
- Garinham (`map 0x09`) guide/image context lives under
  `project_resources/maps/garinham/`. Local reference image:
  `realmofdarkness_garinham.png`; screen-reader transcription:
  `project_resources/maps/garinham/README.md`. Public first-pass priorities
  are exit, inn, item shop, and weapon/armor shop. Guide-backed service data:
  Inn costs 25 G; item shop sells Herb, Torch, and Dragon's Scale; weapon/armor
  shop sells Club, Copper Sword, Hand Axe / Iron Axe, Leather Armor, Chain
  Mail, Half Plate, and Large Shield / Iron Shield. The large grey/north
  building is Magic-Key/later content; its visible chests are 10-17 G, Torch,
  and Herb. Realm of Darkness places the Grave of Garinham entrance inside the
  grey building at the northwest corner of the back wall, while StrategyWiki
  describes the hidden "wall of darkness" path behind the building and says the
  internal locked-door guards are nonessential. Gamer Corner lists three locked
  doors overall, but one is in Garinham B1, so do not treat that dungeon door as
  town-service scope.
- Garinham is public-service complete until Magic Keys. Treat exit/entrance,
  `Merchant 2` / `Tool Merchant`, `Merchant 3` / `Inn`, `Merchant 4` /
  `Weapons Merchant`, and the public east door at `(19,16)` as the current
  service set. The town-side `Exit to World Map` object should target the live
  west entry boundary `(0,14)` and route/teleport to interaction stand `(1,14)`
  facing west; the old `(15,14)` target is only a corridor near the inn. Leave
  the internal grey-building door, locked chests, hidden grave/back-building
  route, and remaining hidden/dialogue-only NPCs for the key revisit unless
  normal play exposes a progression blocker first.
- Garinham's confirmed town-scope locked door is the public east-end door at
  `(19,16)`. Live no-key movement from `(19,17)->UP` stayed on `(19,17)` and
  logged a blocked seam into `(19,16)`, matching the guide's east-end town door
  clue. `map_reader.lua` lists it in `MAP_DOOR_CELLS[0x09]`, so opened-door RAM
  can make it passable after a Magic Key use, and `objects.lua` exposes it as
  `East Door` / `door_19_16`. Post-reload `inspect_move:19,17,UP` reports
  `reason=door_closed` and `effective_passable=false`. Leave the
  guide-mentioned inside-grey-building town door unmodeled until
  keys/opened-door access confirms the exact cell; the Garinham B1 locked door
  belongs to dungeon scope.
- Garinham `Merchant 2` is the public item/tool merchant. Live shop menu proof
  opened Herb 24 G, Torch 8 G, and Dragon's Scale 20 G from that merchant, so
  `objects.lua` labels map `0x09` `Merchant 2` as `Tool Merchant` and keeps him
  in Services. The first noisy return autowalk from this merchant stalled near
  `(3,11)` against `(3,12)` / `(4,11)`; the follow-up manual check confirmed
  `(3,11)` is open north/west and engine-blocked south/east. Model those as
  `(3,12).north` and `(4,11).west` directional blockers, leaving the cell and
  the verified north/west seams open. The next exit-route loop then verified
  three adjacent Garinham building-pocket blockers: `(3,12).west`,
  `(4,10).west`, and `(3,9).south`, each confirmed by `probe_edge_verify`
  5/5 before promotion. A later loop from `(2,10)` added `(2,9).south` and
  `(1,10).east` after both verified blocked 5/5; do not promote
  `(2,10).east` / `(3,10)->LEFT`, because seam brute force crossed that edge.
  A later pass around `(2,11)` / `(2,12)` added `(1,11).east` and
  `(1,12).east` after 5/5 verifier blocks, while preserving the noisy but
  passable `(2,10)<->(3,10)` seam. The same pass found a Garinham decoder gap:
  `(2,13)` decodes as type-2/non-walkable, but `(2,12)->DOWN` moved into it
  5/5, so `MAP_PASSTHROUGH_CELLS[0x09]["2,13"]` keeps the Tool Merchant
  return route connected. The entrance-to-Tool-Merchant reverse route later
  proved the x=7-to-x=6 west entries are false-open: `(7,10)->LEFT`,
  `(7,11)->LEFT`, and `(7,12)->LEFT` all blocked 5/5 and are modeled as
  `(6,10).east`, `(6,11).east`, and `(6,12).east`. The replacement route from
  `(15,14)` to the Merchant 2 stand at `(4,10)` uses the south/top entry into
  that column; raw verification moved 5/5 through `(7,13)->LEFT`,
  `(6,13)->UP`, `(6,12)->UP`, `(6,11)->UP`, `(6,10)->LEFT`, and
  `(5,10)->LEFT`.
- Garinham Tool Merchant drift reroutes after the map cleanup were one-tile
  previous-direction overshoots during route-turn settle, not new map blockers.
  The exit route overshot at `(10,10)->(11,10)`, `(12,11)->(12,12)`, and
  `(13,13)->(13,14)`; the entrance-to-tool route overshot at
  `(7,13)->(6,13)`. Keep these separate from map-data evidence.
  `auto_step.lua` now releases queued early-twitch movement before a route turn
  and suppresses that old-direction re-press, while straight queued segments
  still keep early-twitch holding. Later user retest confirmed the routes are
  usable with one remaining drift reroute each, so treat the residual drift as
  polish unless it starts causing route failures.
- Garinham `Merchant 4` is the public weapon/armor merchant. Live proof selected
  `Merchant 4` at `(10,18)`, landed at `(10,16)`, faced south, and opened the
  weapon/armor menu: Club 60 G, Copper Sword 180 G, Hand Axe 560 G, Leather
  Armor 70 G, Chain Mail 300 G, Half Plate 1000 G, and Large Shield 800 G.
  `objects.lua` labels map `0x09` `Merchant 4` as `Weapons Merchant` and routes
  the interaction to `(10,16)` facing south.
- Garinham `Merchant 3` is the public inn keeper. Live proof from the stand at
  `(15,15)` opened `Welcome to the traveler's Inn. Room and board is 25 GOLD
  per night...`, and `VISITED_AUTO` marked `npc_15` / `Merchant 3`. `report_npcs`
  confirmed `npc_15` at `(17,15)`. `objects.lua` labels map `0x09`
  `Merchant 3` as `Inn` and routes the interaction through `(15,15)` facing
  east.
- Garinham Weapons Merchant return-route cleanup found two confirmed
  engine-blocked west approaches that decoded as open floor: `(11,16).west`
  from `(10,16)->RIGHT`, and `(14,14).west` from `(13,14)->RIGHT`. Both raw
  `probe_edge_verify` checks blocked 5/5. Keep nearby noisy-but-passable seams
  open unless fresh raw verifier evidence says otherwise. After patching, the
  route from `(10,16)` to the exit plans `1 north, 4 east, 1 north, 1 east` and
  `validate_path` completed 7/7 with 0 mismatches.
- Garinham entrance-to-Weapons-Merchant cleanup added the reverse-direction
  counter-throat blockers after raw `probe_edge_verify` checks blocked 5/5:
  `(11,15).east`, `(11,16).east`, `(12,16).north`, `(14,14).east`,
  `(14,16).east`, `(14,15).east`, and `(14,14).north`. Keep
  `(15,13)->LEFT` open unless new raw evidence contradicts it; validation
  crossed that seam on retry. The current validated route from the exit tile
  `(15,14)` to the Weapons Merchant stand `(10,16)` is `1 north, 3 west,
  1 south, 2 west, 2 south`; `validate_path` completed 9/9 with 0 mismatches.
- Garinham Weapons Merchant successful-route follow-up found no drift-reroute
  log entries, but two remaining seam bumps were real engine blockers:
  `(10,15)->RIGHT` into `(11,15)` and `(13,15)->RIGHT` into `(14,15)` each
  blocked 5/5 in raw verifier checks. These are modeled as `(11,15).west` and
  `(14,15).west`. The suspicious `(15,17)->LEFT` into `(14,17)` moved 5/5, so
  keep `(14,17).east` open.
- Brecconary `Tool Merchant` is the normal tool/item shop; older logs and raw
  NPC numbering call him `Merchant 4`. He has a public access node. The user
  found a small walkable pocket at `(22,25)`/`(23,25)`; fresh logs confirmed
  repeated movement `(22,25)<->(23,25)`, repeated blocked movement
  `(23,25)->RIGHT` into `(24,25)`, and `MERCHANT_ACTION: Merchant. Buy.` when
  TALK was used from `(23,25)` facing east. Model the Tool Merchant service
  interaction as `(23,25)` facing east. Keep `(23,25).east` and `(24,25).west`
  as directional movement blockers: the counter can be talked across, but the
  hero cannot walk across it. The older `(25,26)` north-facing tool-shop tile
  is still a real alternate/debug interaction pocket reached from
  `(25,27)->UP`, but it is not the normal public service route. Keep its
  one-way/isolated movement data modeled for pathfinding, especially
  `(25,27).north` blocking exit back south.
- Brecconary `Merchant 4` / `Tool Merchant` route recovery after the
  2026-05-14 retest: the earlier `(17,25)` bridge evidence was superseded
  when live route execution and raw `probe_edge_verify:RIGHT,3` from `(16,25)`
  confirmed `(17,25).west` is blocked. Keep `(17,25)` as a standable
  passthrough for other approaches, but block `(17,25).west`. The replacement
  bridge is `(17,22)`: later manual movement and raw verifiers crossed into it
  from both `(16,22)` and `(18,22)` 3/3 times, so remove the stale permanent
  trap-cell override and keep `(17,22)` as a Brecconary passthrough. After
  reload, `debug_pathfind_to:23,25` from entrance `(1,15)` reports a 38-step
  path.
- The Merchant 4 return-route evidence for `(21,26)` was also superseded by a
  2026-05-14 retest. Keep `(21,26)` as a standable Brecconary passthrough for
  other approach checks, but block `(21,26).east`: live auto-walk, seam retries,
  and manual taps from `(22,26)->LEFT` all blocked, ending with
  `SEAM_OBSERVATION cell=(21,26) approach=east blocked=13 moved=0`. The
  current return route from `(23,25)` goes back through the row-22 bridge; a
  first reverse debug route can still no-path on live NPC clutter, but after
  NPCs moved it found a 36-step path to `(1,15)`.
- Brecconary `map=0x08` is service-complete for now as of the 2026-05-14
  manual pass. Essential services route to and from the town entrance in normal
  play. Remaining unreachable NPCs were manually checked; a couple provide
  clues, but none are currently required for progression. Defer those NPCs to
  polish unless later progression proves a clue is mandatory.
- Next gameplay verification focus after Brecconary is the first castle /
  Tantegel area. A guide mentioned a sage who may restore MP; verify whether
  that object/service exists, whether it should be modeled as an essential
  service, and whether routes to/from it pass before moving deeper into game
  progression.
- On BizHawk, keep background periodic NPC refresh off by default to avoid
  frame/audio hitches. Plain object browsing should also avoid full
  `objects.update_npcs()` rebuilds; instead, `objects.describe_current()` reads
  only the selected NPC slot live so moving NPC directions update cheaply.
  Reserve full NPC refresh for route/planning actions and explicit
  pathability refreshes where current blockers matter.
- Blocked-step, seam-memory, and `probe_edge_verify` results should remain
  diagnostics and should not automatically promote into pathfinding runtime
  blockers. The engine and input timing can produce convincing false blocker
  evidence, so hard runtime blocker promotion should come only from explicit
  manual commands after review, such as `add_blocked_edge:X,Y,DIR` for a
  directional edge or `add_blocked_tile:X,Y` for an intentionally full blocked
  tile. Route-timeout and seam-retry evidence can still be used as soft
  same-session reroute avoidance. When merging runtime blockers into a mutable
  pathfinding overlay, copy direction tables first so temporary reroute blocks
  cannot mutate the manual runtime table by aliasing.
- Screenshots can be useful evidence for over-promoted directional blocks, but
  promote route changes only after live probes and route outcomes agree. In
  Brecconary, early `(8,5)->LEFT` moved evidence for `(7,5).east` was
  superseded by controlled public-side probe/route failures; Merchant 2 access
  is a counter interaction from `(5,6)` while the merchant object remains at
  `(5,4)`.
- Engine-walkable hazard cells should be modeled separately from walls. The
  first confirmed case is Tantegel Castle map `0x04` `(10,18)`, which manual
  movement reached from `(10,19)` and immediately produced `Lost 15 HP. HP 0`
  followed by the death sequence. Keep these cells pathfinder-forbidden and
  prevent tap-to-step/queued auto-step from extending into them, but do not
  mislabel them as permanent blockers because the player can still deliberately
  walk onto them.
- Queued-route blocks caused by live NPC occupancy are temporary clutter, not
  map geometry. Check the destination against current NPC RAM before
  seam-bruteforcing or promoting runtime blockers; if the destination is an
  NPC, cancel with an NPC-blocker message instead. Use the decoded movement
  byte to distinguish ordinary wandering clutter from stationary NPC blockers,
  but keep the player-facing stationary-NPC hint cautious: Brecconary logs
  showed `NO_PATH_STATIONARY_NPC` followed by a tryable route seconds later, so
  the spoken hint should say the route may be blocked by a stationary or
  out-of-date NPC position and suggest retrying.
- Post-arrival facing for auto-walk must not feed back into tap-to-step.
  `route_manager.lua` may inject a short direction press so the hero faces an
  adjacent NPC, but `auto_step.lua` must suppress edge tracking for that
  artificial tap or it can extend the face press into a full tile step.
- Do not use raw `menu.is_open()` as the sole field movement or auto-walk
  blocker. It is a COMMAND-header PPU match and can stay true after TALK or
  dialogue transitions because the header lingers in nametable memory. Movement
  gating should use the confirmed live command-menu session plus recent visible
  cursor hold, while the scanner can still use the raw header match to recover
  real menu open/close state.
- Command-menu open speech should tolerate one short stale-cursor window. DW1
  can expose the last-used command cursor in RAM for a few frames before the
  newly opened field menu settles on TALK. Debounce the open announcement and
  flush it with the first real cursor movement or settled item instead of
  immediately speaking `Command. <last item>`.
- Field command submenus that reuse D8/D9 need explicit modes. `STATUS` reads
  full status, `ITEM` maps D9 through the inventory list, and `SPELL` maps D9
  through known spells from `items.lua`. Enter SPELL from the confirmed
  command-menu selection so a one-spell list, such as level-3 Heal, speaks
  immediately even if there is no visible cursor tile or later cursor movement.
  Suppress the first synthetic cursor jump after entry so the first spell is
  not spoken twice. DW1's field spell list does not display per-spell MP costs;
  speech should add the NES spell cost from metadata, for example
  `Heal. 4 MP`.
- BizHawk dialogue throttling should not put the command-menu scanner fully to
  sleep during player input. A fresh A/X press can open the field menu one
  frame after the input is sampled, so keep menu scanning awake during current
  or recent field input even while dialogue hints are active.
- `report_upper_dialogue_state` includes both raw and active menu state plus
  the lower dialogue text and lower previous/announced baselines. Use it when
  diagnosing silent dialogue around row-scrolled command-menu leftovers.
- BizHawk periodic NPC/object refresh is disabled by default with
  `bizhawk_periodic_npc_refresh=false` because live profiling showed background
  `objects.check_refresh` calls could spike around 1.7-2.0 seconds. Explicit
  route/path/debug commands still call `objects.update_npcs()` when they need
  current live blockers; plain browser keys should use selected-slot live reads
  instead of a full list rebuild.
- Accepted NPC RAM signatures for map-entry object refresh must survive
  BizHawk Lua reloads. `main.lua` clears `package.loaded["objects"]` on reload,
  so `objects.lua` stores accepted signatures in `_G.DW_OBJECTS_RELOAD_STATE`.
  Full object-list refresh is not enough because BizHawk disables periodic NPC
  object rebuilds and NPCs can move between refresh and stairs use. `main.lua`
  should call `objects.observe_npcs(map_id)` during normal gameplay frames and
  reload grace so map entry can compare against the latest observed previous
  map signature. The signature should mask off NPC direction/frame bits and
  compare sprite/x/y coordinates, then hide NPCs on the destination map while
  RAM still matches the map just left.
- Dungeon/cave maps should not parse the live NPC RAM table for object
  browsing. That RAM can contain stale town/castle NPC bytes after map entry
  and should not be force-accepted after retry windows. Keep live NPC objects
  limited to the town/castle terrain context; dungeons/caves should expose
  static travel, door, and treasure objects unless a future map proves an
  actual NPC-like object source.
- Selected-object teleport should avoid full object-list rebuilds on the hotkey
  path. Use direct live NPC RAM checks for "landing occupied" tests and for the
  selected `npc_N` slot's current target position. `Shift+Enter` on an NPC
  should resolve to a service interaction stand when one is modeled, otherwise
  to an open cardinal adjacent cell; it should never intentionally land on the
  NPC's occupied cell. After a selected NPC teleport, queue a one-frame raw
  facing tap after teleport input suppression, then neutralize input, instead
  of using an auto-step/held direction; counter stands such as Brecconary
  `(5,6)` have walkable tiles in front, so held directions can walk onto the
  counter rather than just face it. Because BizHawk can also see
  `Shift+Enter`/`Shift+direction` as NES Start/D-pad input, selected teleport
  suppression should stay active until the non-modifier trigger key (`Enter` or
  the arrow) is released; a fixed short window can leak Start and leave the
  player in a command-menu/control-stuck-feeling state. Also reject generic NPC
  adjacent landings with no non-target escape route. The Brecconary Woman 3
  repro at target `(4,7)` initially chose `(5,7)`; live injected movement from
  that cell engine-blocked UP into `(5,6)`, DOWN into `(5,8)`, and RIGHT into
  `(6,7)`, while LEFT was the NPC. The safe fallback is the south stand
  `(4,8)`, facing north.
  A manual teleport retest found the apparent lost-keyboard state was actually
  a boxed-in landing at map `0x05` `(4,6)` with NPC blockers on both sides, a
  door south, and a noisy north seam.
- Selected-object NPC teleport also needs to keep the target in place long
  enough for the player to use TALK. A Garinham repro landed beside live
  `Woman 2`, faced the old target tile, and later TALK missed because the NPC
  had wandered. The teleport hotkey path now uses `route_manager.hold_target_npc`
  to pin the selected NPC's live target tile with `teleport_npc_hold_frames`,
  holds the facing direction for `teleport_face_target_frames` frames, logs
  `TELEPORT_SELECTED_TIMING` / `TELEPORT_SCAN_GRACE`, and gives the field loop
  a short `teleport_post_scan_grace_frames` window to avoid expensive text/menu
  scans during immediate input suppression/facing. Keep the selected-teleport
  hold shorter than the auto-walk hold, write NPC hold bytes only when they
  drift, and release the hold as soon as TALK dialogue opens or misses.
- BizHawk ROM domains can be exposed as headerless PRG data even when the
  project expects FCEUX-style `rom.readbyte()` file offsets that include the
  16-byte iNES header. `emulator_compat.lua` must score candidate ROM domains
  and address mappings instead of accepting the first readable byte; otherwise
  ROM-backed tables such as map metadata can be shifted by 16 bytes and produce
  nonsense dimensions under BizHawk.

Known BizHawk risk:
- BizHawk's Lua memory-domain reads are much slower than FCEUX for PPU-heavy screen scanning
- Compatibility-layer PPU caching helps but may not be enough
- BizHawk native `ppu.readbyte` can expose a stale/blank nametable view during
  dialogue even when the visible text is present in the `CIRAM (nametables)`
  memory domain. Prefer a readable nametable memory domain for PPU text reads
  and keep native `ppu.readbyte` as fallback.
- `PPUCTRL` bit 0 can also be stale during dialogue/menu transitions. If
  `scroll_tiles` indicates a wrapped row but the reported base nametable yields
  no lowercase dialogue, try the alternate nametable order before declaring the
  lower window empty.
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
  the retry gets a real held direction. A later fresh-game playtest showed that
  relying only on timeout retry made manual autostep feel like native held-key
  movement, so the BizHawk config now allows one quick turn-only re-press by
  default (`auto_step_turn_repress_limit=1`) while keeping the neutral-gap and
  movement-start release guards. Because a turn-in-place can trigger a very
  early subpixel change, `auto_step.lua` tracks the frame of the subpixel
  change and still schedules the re-press when no tile move follows.
- Queued-route timing-suspect blocks should not become survey map candidates.
  If a queued route needed a turn re-press, saw movement start, and then timed
  out quickly, mark the block data `timing_suspect`, let `route_manager.lua`
  direct-retry the same seam, and have `map_survey.lua` ignore that route block
  for blocked-tile counting. If the direct retry lands exactly at the adjacent
  goal, `route_manager.lua` must publish `route_completed`; otherwise surveys
  can falsely report `route_inactive_without_completion`.
- The Brecconary first-route `O`/`U` lag was mostly first-use map-grid/ROM-cache
  cost. Prewarming the current interior map grid during map-entry refresh moved
  that cost away from the first route, but later live castle play showed the
  transition itself could hitch (`objects.check_refresh max_ms=1846`). BizHawk
  now skips map-entry path-grid prewarm by default with
  `bizhawk_map_entry_prewarm_path_grid=false`; FCEUX keeps the old prewarm, and
  BizHawk can opt in when first-route warmup is preferable.
- End-of-route BizHawk hitches can come from route cleanup, not route planning.
  A user retest showed improved auto-walk audio and a successful route to
  `(15,19)` with neutral input, but `report_scan_stats` later showed
  `objects.check_refresh max_ms=1658`. `route_manager.lua` now skips the
  immediate object/NPC refresh after BizHawk route completion or cancellation by
  default (`bizhawk_route_cleanup_refresh_objects=false`). FCEUX keeps the old
  refresh, and BizHawk can opt back in for stale-object investigations.
- Object caches must also honor explicit map-change events, not only
  `objects.check_refresh()` noticing a different current map id. In normal play
  the map id can change before NPC RAM has loaded the new map's NPC table.
  `navigation.lua` exposes `previous_map_id`, and `main.lua` should pass it to
  `objects.on_map_change(map_id, {previous_map_id=...})`. `objects.lua` should
  keep accepted NPC RAM signatures by map; on map entry, if current NPC bytes
  still match the previous map's accepted signature, keep NPCs hidden and retry
  instead of publishing previous-map NPCs in the browser.
- If King or other field Yes/No prompts speak a fragment of the previous page
  before the question, inspect the lower-window overlap handling before changing
  row decoding. `text.extract_new_dialogue()` owns the field overlap logic and
  handles both old-suffix/new-prefix overlap and the prompt case where the new
  visible text starts from inside the old page before appending the actual
  question. `main.lua`'s `check_yesno_prompt()` should log/speak the extracted
  new fragment but keep the full raw lower-window text as `announced_dialogue`
  for later stability comparisons.
- BizHawk settings are not the first suspect for the latest King-area lag: the
  active config already has the safer baseline (`SoundBufferSizeMs=200`,
  `SoundThrottle=true`, `FrameSkip=0`, `Rewind.Enabled=false`, VSync off). A
  live 2026-05-05 `report_scan_stats` showed single-digit max times for
  dialogue/menu scans, but second-scale script spikes in `objects.check_refresh`,
  `hotkeys.update`, and `auto_step.update`. Use a reset/profile window around
  one repro before changing emulator timing settings such as frame skip or skip
  lag frames.
- Menu and Yes/No prompt detection must account for both horizontal nametable
  orders. In throne-room scroll states like `scroll_tiles=22 base_nt=1`, visible
  UI text can cross from NT1 back into NT0. `text.lua` handles this for decoded
  rows; `menu.lua` separately scans both NT0->NT1 and NT1->NT0 virtual rows for
  `COMMAND` and Yes/No cursor patterns. If command-menu speech goes silent after
  reload while speech status is ready and scanners are active, inspect wrapped
  menu/header detection before chasing the speech backend.
- For silent menu/dialogue captures, the old PPU diagnostic rows 15-29 are not
  enough because the command menu may be in upper rows. The `Ctrl+D` PPU dump
  now records rows 0-29 for both nametables, decoded NT0->NT1 and NT1->NT0 row
  orders, scroll/base/cursor RAM, and explicit `COMMAND` / `YESNO` match hints.
  Pair it with `report_menu_state` for parser state while the bad UI is still
  visible.
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
- Random encounters are not map evidence. On `battle_started`, the survey
  pauses, cancels the active auto-walk route, clears route context, and keeps
  the current queue index unchanged so the interrupted target is retried after
  field movement is safe. If combat returns on a different map, abort rather
  than resuming with contaminated context. Low HP remains a hard survey abort.
- Fresh dungeon floors may start on a stair/entrance corner with only one open
  exit. Treat `low_exit_count` from that tile as a survey-start guardrail, not
  blocker evidence. Move to a nearby interior seed with multiple exits, run
  targeted object surveys first, and use direct `probe_edge` checks before
  promoting noisy survey reroute observations to permanent map data.

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
- Latest broad surveys showed no strong blocker candidates. The 2026-05-09
  parked-NPC stress sequence from `(15,15)` has repeatedly ended with
  `suspected_engine_blocked=0` and `RUNTIME_BLOCKS none` after separating
  survey-safe post-arrival input, route-drift retry ordering, and
  timing-suspect queued-route blocks from real map geometry. Route-specific
  live play can still promote narrow service-pocket traps when repeated route
  evidence is clean.
- `Weapons Merchant` is the real Brecconary weapon/armor shop at `(5,4)`. The safe
  public interaction square is the doorway/counter at `(5,6)`; face north and
  TALK even though the object reports two tiles north. The doorway throat
  `(5,7)` and the counter square `(5,6)` are both type-0 false-wall tiles and
  must stay in Brecconary passthrough data.
  Treat `(4,4)`, `(4,5)`, `(4,6)`, `(5,5)`, `(6,4)`, and `(6,5)` as
  pathfinder-forbidden service-pocket traps, and keep `(7,5).east` blocked so
  A* does not try the false shortcut from `(8,5)`. A 2026-05-09 verifier also
  confirmed `(5,2)->DOWN` into `(5,3)` blocks 5/5 despite the decoded tile
  looking open, so keep `(5,3).north` modeled as a directional block.
- Survey blocker classification should not promote an orphaned route as engine
  evidence when the final position is the same tile it suspected was blocked.
  The 2026-05-09 Brecconary Old Man 1 report on `(20,14)` was this case:
  `probe_edge_verify:19,14,RIGHT,5` later confirmed the edge passable 5/5.
- Survey `route_drift_retry` events should retry the same target immediately
  from the live drifted position. Appending the retry behind the remaining
  queue can turn one auto-step overshoot into a cluster of bogus
  `gated_or_isolated` failures from the drifted start tile.
- Queued auto-step should not keep holding early subpixel twitches after a
  timeout retry. If the retry press catches an already-moving step close to
  tile completion, the old hold-through-grace behavior can commit an unwanted
  extra tile before route settle catches it.
- Queued auto-step should mark early turn re-press timeouts as timing-suspect
  and direct-retry them rather than waiting for the full wall timeout or
  counting them as survey blockers. A focused Brecconary exit target from
  `(15,15)` reached `(1,15)` with `blocked_events=0` after this handling even
  though the live log still showed multiple `AUTO_WALK_TIMING_RETRY` entries.
- Queued auto-step should not combine hold-through-grace and same-direction
  turn re-press recovery for the same early movement twitch. The 2026-05-09
  Brecconary entrance-to-Inn route held through the first right-step twitch and
  then re-pressed right, committing an extra tile to `(2,15)` during
  right-to-down settle. Keep early-twitch reports timing-suspect/direct-retry
  eligible, but suppress the re-press while hold-through-grace is active.
- Early queued-route twitch timeouts and turn-repress twitch timeouts need
  different budgets. A 24-frame timeout was safe for turn-repress retries but
  too aggressive for a real in-progress queued step: the Brecconary
  `(2,14)->RIGHT` route to `Weapons Merchant` timed out just before tile
  completion, then the seam retry re-pressed into the tile boundary and
  carried the hero off route. Use the separate
  `auto_step_route_early_twitch_timeout_frames` setting to give early movement
  twitches a few extra neutral frames before retry injection.
- Queued-route completion must match the injected direction. If a queued step
  says `left` but the engine lands south, cancel as `route_drift_off_path`
  instead of publishing a false step completion. For survey-safe routes, keep
  the long neutral settle around direction changes but skip it between
  same-direction straight steps; the 2026-05-09 Brecconary Inn comparison
  dropped `route_settle_catchup` to zero while still finishing at `(8,21)`.
- Raw map block `0xF` is the town/castle large-tile counter trigger. Use
  `map_reader.get_raw_block_id()` / `is_large_tile()` for service-counter
  discovery instead of changing the existing pathfinding grid decoder.
- Brecconary `Inn` at `(10,21)` is the inn keeper. TALK works from the public
  stand tile `(8,21)` facing east; `(9,21)` can trigger the inn but is blocked
  from the public west approach and should not be the route target. Keep
  `(8,17).west` blocked so the entrance-to-inn route avoids the discovered
  timeout. Brecconary `Tool Merchant` at `(25,25)` is the tool/item shop. The
  public route-facing TALK tile is `(23,25)`, facing east across a blocked
  movement seam into the counter trigger; the older `(25,26)` north-facing
  stand and raw `(24,25)` trigger also open the shop but are alternate/debug
  pockets, not the normal public route target. These are direct counter
  interactions, not ordinary adjacent-NPC TALK targets.
- Brecconary `Merchant 1` is dialogue-only, not a service. Keep him browsable
  as an NPC but exclude him from the Services filter. Woman 1 is the
  `Fairy Water Merchant` behind the northeast door; do not treat her as
  public-route cleanup. Old Man 2 is the `Curse Remover` based on his live
  dialogue claim; verify the actual effect later when the hero is cursed. The
  2026-05-14 route pass solved Old Man 2's public approach by promoting
  `(24,12)` as a Brecconary passthrough and leaving `(24,11)<->(24,12)` open.
  Live proof after reload: `debug_pathfind_adjacent:24,10` from entrance
  `(1,15)` chooses the TALK stand `(24,11)` with a 29-step route and
  `Face north`; `debug_pathfind_to:1,15` from `(24,11)` returns in 29 steps;
  `RUNTIME_BLOCKS map=0x08 none` for both. Keep the west/north trap blockers
  around the room (`(23,9).east/south`, `(23,10).north/west`,
  `(24,8).south`, `(22,10).east`, and the older `(24,9)`/`(25,9)`/`(26,9)`
  directional walls), but do not restore the older noisy `(25,11).west` or
  `(24,11).north/south` blocks.
- Survey target copies must preserve service interaction metadata
  (`service`, `interaction_x`, `interaction_y`, `interaction_face_dir`).
  Dropping those fields makes surveys route to raw adjacent NPC cells while
  manual Services autowalk correctly routes to counter stand tiles, producing
  false no-path results for counter services such as the Brecconary inn.
- Remaining broad failures are clean gated/isolated object regions.
- Existing permanent Brecconary fixes in `map_reader.lua` should be preserved unless better evidence appears.
- Treat remaining first-town service issues as counter/large-tile interaction
  problems first, not just dialogue filtering or ordinary adjacent NPC routing.

Tantegel/castle/interior maps:
- Confirm live map id before permanent edits.
- Historical notes sometimes label map `0x04` as Tantegel Castle and `0x05` as throne room/interior.
- Recent map `0x05` blocked-cell observations looked transient and did not justify permanent map-data changes.
- Tantegel Castle map `0x04` Old Man 2 at `(20,26)` is the MP-restoring
  `Sage`, confirmed by user dialogue/effect testing and corroborated by guide
  notes for the castle wise man. Keep him in the Services filter and route him
  as an adjacent NPC, not as a counter service.
- Current 2026-05-14 Sage routing state: from entrance-side `(11,29)` and
  standable `(12,29)`, NPC-free `debug_pathfind_adjacent_skip_npcs:20,26`
  reports `No path found`; from Sage-side `(20,25)`,
  `debug_pathfind_adjacent_skip_npcs:11,29` succeeds to `(12,29)` in 12 steps.
  This is a one-way/static-graph issue, not live NPC clutter. Keep the raw
  confirmed south-gate blockers `(16,29)->UP`, `(17,29)->UP`, `(18,29)->UP`,
  `(19,29)->UP`, and `(19,29)->RIGHT`; future work should find the alternate
  public approach or an over-modeled blocker elsewhere.

Erdrick's Cave/maps `0x1C` / `0x1D`:
- The B1 object baseline is static-only: `Exit to World Map` at `(0,0)` and
  `Stairs Down to B2` at `(9,9)`. B2 returns via `Stairs Up to B1` at `(8,9)`.
  Stale Brecconary NPCs after cave entry are RAM carryover, not real dungeon
  objects.
- Do not reuse the old `(1,1)` Erdrick B1 stair guess. Live STAIRS at `(1,1)`
  produced `'There are no stairs here.` The ROM stair-down table contains
  `1C 09 09`, and live STAIRS from `(9,9)` changed to map `0x1D` landing at
  `(8,9)`. Live STAIRS from B2 `(8,9)` returned to B1 `(9,9)`.
- B2 (`0x1D`) now has first-pass chest-route directional seams in
  `map_reader.lua`, all promoted from 5/5 direct `probe_edge_verify` consensus:
  `(5,3).south`, `(6,4).west`, `(6,5).east/south`, `(7,4).south`,
  `(8,5).west/south`, `(9,5).south`, `(5,8).south/east`, and `(7,8).west`.
  A second focused pass added `(1,6).south` and `(2,6).south` after clean 5/5
  direct verifiers. `(4,7).west` and `(2,6).east` were route-observed but
  direct verifier-mixed, so they intentionally remain unmodeled. A later
  stairs-to-chest decoder pass added `(3,5).south`, `(4,4).east`,
  `(4,5).east`, `(4,6).east/west`, `(5,7).north/east`, `(5,8).west`,
  `(7,8).east`, and `(8,7).south`. A morning follow-up after a normal
  stairs-to-chest route added `(6,5).west`, `(7,7).north`, `(8,7).north`,
  `(4,7).south`, and `(4,7).west` after fresh 5/5 verifier
  consensus. After real BizHawk auto-reload, route validation exposed
  `(8,7).east` as blocked 5/5 and `(2,6).east` as blocked 10/10; both are now
  modeled. A reverse pass from chest-side `(8,3)` toward stairs added
  `(9,5).north`, `(7,4).north`, `(6,4).north`, `(5,3).east`, `(5,2).east`, and
  `(5,1).east` after clean 10/10 direct verification. Route-observed
  `(8,5).north` first stayed mixed on direct checks (2/10 moved, then 2/15
  moved), and `(7,4).east` also stayed mixed (1/10 moved), so both initially
  stayed unmodeled. A later chest-to-stairs route naturally failed at the same
  two exits from `(8,4)`, and fresh direct repeats verified both blocked 15/15;
  `(8,5).north` and `(7,4).east` are now modeled. Walkthrough-guided follow-up
  says B2 should be a normal loop to the tablet. `(7,9).east` was briefly
  demoted after timing-confounded raw movement evidence, then restored after
  route-shaped raw checks from settled stairs and
  `probe_edge_verify:8,9,LEFT,15` both stayed blocked. `(9,5).south` stays
  modeled because raw held UP from `(9,6)` remained blocked and auto-walk
  failed there despite one mixed verifier run. A later left-edge pass found the
  intended loop hidden by the generic dungeon boundary rule: B2 needs narrow
  passthrough cells `(0,4)` through `(0,7)`, while `(0,8)`, `(0,9)`, and
  `(0,3)` remain blocked or mixed and stay unmodeled. That same pass promoted
  `(1,3).south`, `(2,3).south`, and `(4,3).west` after clean 5/5 verifiers.
  A follow-up stairs-to-chest reroute exposed more upper-left blockers:
  `(1,5).west`, `(4,4).west`, `(4,3).north`, `(5,2).west`, `(4,1).south`,
  `(3,1).south`, `(3,5).north/west`, `(2,3).east`, `(2,1).south`, and
  `(1,1).south`; `(1,1).south` also verified blocked 15/15 directly. Static
  graph checks then identified the missing edge continuation. Live
  `probe_edge_verify:1,2,LEFT,15` moved into `(0,2)` 15/15, and a forced-origin
  `probe_edge:UP` from `(0,2)` moved into `(0,1)`. A later autowalk reached
  `(0,1)`, then `(0,1)->RIGHT` into `(1,1)` verified blocked 15/15. Graph checks
  and live probes then proved the top-edge continuation: `(0,1)->UP` into
  `(0,0)` passed 15/15, route-shaped probes moved through `(1,0)`..`(6,0)`,
  north entries into `(1,1)`..`(5,1)` blocked, and `(6,0)->DOWN` moved into
  `(6,1)`. Static tests pass, live `inspect_tile` reports `(0,0)` and `(6,0)`
  as `reason=passthrough`, and `debug_pathfind_adjacent:9,3` from B2 stairs
  `(8,9)` now chooses chest-adjacent `(8,3)` with a 42-step path and
  `Face east`. Actual auto-walk is now playably validated in both directions:
  stairs-to-chest reached the chest after one reroute bounce around `(7,2)`,
  and chest-to-stairs reached B2 stairs `(8,9)` after several return-trip
  bounce/reroute candidates. The successful run ended cleanly with
  `RUNTIME_BLOCKS map=0x1D none`, so remaining return-trip bounces should be
  treated as optional direct-verifier cleanup rather than blockers required for
  cave progress.
- B1 has confirmed directional maze seams, but route/probe evidence must be
  consensus-checked before becoming map data. Keep the current truth in
  `map_reader.lua` / `test_map_reader.lua`, keep all B1 seams directional-only,
  and do not promote route-only timeout observations into hard runtime or
  permanent map blockers. `(6,3)` from the west is currently mixed and should
  stay unmodeled unless a future `probe_edge_verify` pass reaches consensus.
  Reverse-route follow-up also confirmed the east approaches into `(8,9)`,
  `(5,1)`, and `(4,5)` with `5/5` verifier blocks each; these belong in the
  directional table, not as full-cell blockers.
  If a touch-plus-probe reload is consumed but B1 still sounds noisy, confirm
  the live static model with `inspect_move`; stale `map_reader.lua` has already
  made patched approaches report `approach_blocked=false` until a manual
  reload/relaunch.
- The B1 entrance uses confirmed edge passthrough cells: `(0,0)` and `(1,0)`.
  Live probes confirmed `(0,0)->RIGHT->(1,0)->DOWN->(1,1)` and the reverse
  path. Keep `(0,1)` blocked until it has its own direct evidence.
- BizHawk queued auto-walk can produce false "blocked" route events when the
  movement subpixel byte twitches during engine settle or turn-in-place. Do not
  treat those as geometry by default. `auto_step.lua` keeps queued-route input
  held through early twitches with
  `auto_step_route_early_release_grace_frames`, and route-timeout metadata lets
  `route_manager.lua` direct-retry suspect movement-start timeouts before
  accepting a silent alternate reroute.

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

## BizHawk Memory Adapter Lessons

- A live crash with `dw_script_error.log` showing `snapshot.update: 69` from
  `emulator_compat.lua` inside `mainmemory.read_u8` means BizHawk's direct
  RAM API raised a native/numeric error before the domain fallback could run.
- Keep BizHawk memory adapter reads/writes behind `pcall` and fall back to the
  domain-backed `System Bus` API for ordinary CPU RAM. This keeps one flaky
  direct memory call from killing the whole Lua loop during startup or reload.
- Keep BizHawk adapter logging behind `pcall` too. A `Ctrl+W`-adjacent crash
  showed `console.log()` itself can raise while the adapter is reporting a
  memory fallback, so logging must fail closed and never become the fatal path.
- If BizHawk briefly exposes no usable read/write memory API during reload or
  window churn, the compatibility shim should fail closed for that frame:
  return `0` for reads and drop writes after a one-time log instead of crashing
  the Lua loop.
- Once the Lua loop has crashed, `touch main.lua` is not reliable by itself.
  Always pair it with a fresh launcher probe; if the probe does not arrive,
  reload the script from BizHawk or relaunch the emulator.

## PPU Text And Scroll Lessons

- Dialogue row decoding must use both horizontal scroll and the active
  horizontal nametable bit. Reading NT0 then NT1 as a flat 64-tile row can
  scramble visible text when PPUCTRL bit 0 selects NT1 as the first visible
  nametable.
- Live King repro on map `0x05` at `(3,4)` had `PPU_CTRL=0x03` and
  `SCROLL_X=0xB0` (22 tiles). The visible order was NT1 columns 22-31 followed
  by NT0 columns 0-21, which turned the intended sentence into
  `greatly pleased 'I am ... retu` before `text.decode_row()` was fixed.
- Merchant/shop list readers need the same visible-screen treatment plus
  vertical scroll. The Brecconary weapon shop at `(5,4)` showed a `COMMAND`
  header and reused D8/D9 cursor RAM, so stale command-menu logic spoke
  `STATUS`, `SEARCH`, and raw cursor values until `merchant.lua` decoded
  visible scrolled rows and `main.lua` forced a fresh merchant-layout check
  before command-menu speech. Keep merchant scans running while shop prompts
  make `dialogue_hint` true; otherwise the item reader can starve after
  buy/error/continue cycles. Item confirmation/error dialogue can leave command
  labels visible behind lower text, so command-menu speech must stay blocked
  while lower dialogue is active. Keep the fixed merchant context as a
  conservative first pass, but fall back to live horizontal/vertical scroll and
  the alternate nametable base; the Brecconary weapon counter has shown
  `base_nt=1` while the active list decoded from the opposite base with
  `vertical_scroll_tiles=6`. Tool shops need the same parser but a broader
  catalog: Brecconary `Merchant 4` showed `Herb`, `Torch`, and split
  `Dragon's` / `Scale` rows, and stayed silent until the shop catalog included
  item-shop goods in addition to equipment names. Merchant action prompts are a
  third shop state: Brecconary `Merchant 4` overlays `BUY`/`SELL` on stale
  command-menu rows while reusing D8/D9, so parse it as `mode=action`
  (`0=Buy`, `1=Sell`) instead of letting the field command reader call those
  cursor positions `TALK`/`STATUS`. While merchant UI owns the screen, keep the
  lower-dialogue baseline synchronized with the visible shop prompt; otherwise
  closing/error lines can re-announce previous shop prompt text before the new
  farewell or error.
- For future dialogue bugs, capture `report_movement_state` and
  `report_upper_dialogue_state`; for shop/menu bugs also capture
  `report_merchant_state`. Useful fields are `ppu_ctrl`, `scroll_x`, `scroll_y`,
  `scroll_tiles`, `base_nt`, and the raw lower/upper/merchant decoded text.

## Codex Memory Access

- In Codex sessions, `.codex/` under this repository can be mounted read-only even though the surrounding repo is writable.
- Do not depend on editing `.codex/skills/dw-debug-loop/SKILL.md` during normal project work.
- Canonical mutable project memory should live in repo files: `session_handoff.md`, `PROJECT_MEMORY.md`, `AGENTS.md`, and targeted docs such as `debug_hooks.txt`.
- Assistant-local memory belongs under `/home/developer/.codex/memories/`; use it as a reminder layer only, not as the source of truth when repo docs disagree.
- Current recommendation: keep launching Codex from Linux/WSL. The memory issue is a sandbox/read-only mount detail, not a reason to switch environments.
