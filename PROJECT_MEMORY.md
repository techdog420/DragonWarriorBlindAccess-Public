# Project Memory

Updated: 2026-05-13

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
  Travel destination such as `Erdrick's Cave`, `Brecconary`, or `Tantegel
  Castle`, then press `R` to start guidance or press it again for active route
  status/recalculation. If an active route exists and the selected Travel
  object resolves to a different guided destination, `R` replaces the active
  route instead of leaving stale waypoints in control. If the active waypoint
  is selected and the player has drifted far from it, `R` recalculates the next
  route marker from the current world-map position. Command-file equivalents
  are `route_guidance`,
  `start_overworld_route:cave` (aliases `erdrick` and `erdric`),
  `start_overworld_route:brecconary` (alias `breconary`),
  `start_overworld_route:castle`, `route_status`, `route_recalculate`, and
  `stop_overworld_route`.
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
  and `0x04` /
  `0x05` for Tantegel Castle. Entering
  Erdrick's Cave maps `0x1C` / `0x1D` completes the first-dungeon route even
  if the world-map final tile was not observed before the map transition. `O`
  should remain the plain heading/path preview, and `U` should remain
  available for future overworld auto-walk until the world-map decoder and
  encounter-flow behavior are proven live.
- Read-only hotkey speech should avoid cutting off route progress
  announcements. `hotkeys.lua` uses non-interrupting `tolk.output` for
  position, HP/MP, level, gold, experience, stats, screen text, and `R` route
  guidance/status. During auto-step movement, `R` may still report an active
  route's status, but starting a new route or running movement-changing object
  controls remains blocked until movement is stable.
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
