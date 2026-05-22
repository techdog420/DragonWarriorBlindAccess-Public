# Session Handoff - Active Resume

Updated: 2026-05-21

## Latest Code Review (2026-05-19)

See `HANDOFF_2026-05-19_code_review.md` for the full breakdown of the post-weekend code review and follow-on fixes. Five commits landed (`095865a`, `5d873f3`, `9661190`, `ac7a0a6`, plus the doc). Follow-up cleanup on 2026-05-20 fixed the remaining terrain-offset propagation gap in route guidance/status/start paths, removed the per-frame `position_key` string allocation in `overworld_routes.observe_position`, made `safe`/`safety` contextual between Brecconary and Tantegel, and corrected the `dw-debug-loop` handoff-heading guidance. Open review-board items still worth carrying: resolve the Tantegel `4,11-4,15` evidence conflict during the upcoming locked-door/item mapping pass, and decide whether overworld route waypoint validation needs a real overworld passability source before changing radius-0 behavior.

## Rimuldar Chest Exit Blocker Fix (2026-05-20)

- Confirmed remaining false one-way blockers were blocking chest-to-exit routes in
  Rimuldar even with both inn doors open:
  - `Rimuldar` `MAP_DIRECTIONAL_BLOCKS[0x0B]["22,21"].south` (from `(22,22)->UP`)
  - `Rimuldar` `MAP_DIRECTIONAL_BLOCKS[0x0B]["23,24"].north` (from `(23,23)->DOWN`)
- Both were removed from the directional table after direct `probe_edge` mismatch logs:
  - `(22,22)->UP` actually reaches `(22,21)` in live checks.
  - `(23,23)->DOWN` actually reaches `(23,24)` in live checks.
- Follow-up live probing found the next route blockers:
  - `(14,19)->RIGHT` into `(15,19)` is a real one-way block after the command
    menu is closed: 3/3 blocked, while `(15,19)->LEFT` moved 3/3. Keep
    `MAP_DIRECTIONAL_BLOCKS[0x0B]["15,19"].west`.
  - `(13,20)` is a hidden passable bridge between the chest-side component and
    the exit route: `(13,21)->UP` moved 5/5 and force-origin `(13,20)->UP`
    moved into `(13,19)`. It is now a Rimuldar passthrough cell.
- After FCEUX reload, `pathfind_to` and `debug_pathfind_to` find open routes in
  both directions. The return-side planner then exposed two more clean blocked
  approaches: `(14,23)->RIGHT` into `(15,23)` and `(14,24)->RIGHT` into
  `(15,24)` both blocked 5/5, so `MAP_DIRECTIONAL_BLOCKS[0x0B]["15,23"].west`
  and `["15,24"].west` are now modeled. With those runtime-injected, live
  planning still finds `(29,13)->(23,23)` via row 25 and `(23,23)->(29,13)` via
  `(13,20)`.
- The next autowalk loop exposed two lower-row false exits: `(21,25)->UP` into
  `(21,24)` and `(15,25)->UP` into `(15,24)`. Direct verifiers confirmed both
  as blocked 5/5 with no drift/map change, so `["21,24"].south` and
  `["15,24"].south` are now modeled.
- A fresh entrance-to-chest autowalk then reached `(16,27)` and looped on
  `(16,27)->RIGHT` into `(17,27)` plus `(16,27)->DOWN` into `(16,28)`. Direct
  verifiers confirmed both blocked 5/5, so `["17,27"].west` and
  `["16,28"].north` are now modeled.
- The next reroute reached `(15,27)` and looped on `(15,27)->DOWN` into
  `(15,28)`. Direct verifier confirmed blocked 5/5, so `["15,28"].north` is
  now modeled. `(15,27)->UP` showed noisy retry/passable behavior and was not
  promoted.
- A parked-NPC forward route then exposed the lower west branch as false:
  `(13,26)->LEFT` into `(12,26)` and `(13,25)->LEFT` into `(12,25)` both
  verified blocked 5/5, so `["12,26"].east` and `["12,25"].east` are now
  modeled.
- The next lower-west reroute exposed `(13,23)->LEFT` into `(12,23)` and
  `(13,24)->LEFT` into `(12,24)` as the same class of false branch. Both
  verified blocked 5/5, so `["12,23"].east` and `["12,24"].east` are now
  modeled too.
- The next skip-NPC route shifted to `(13,22)->LEFT` into `(12,22)`, which also
  verified blocked 5/5; `["12,22"].east` is now modeled.
- The final upper entry in that west branch, `(13,21)->LEFT` into `(12,21)`,
  also verified blocked 5/5; `["12,21"].east` is now modeled.
- Follow-up return-route harvesting from the chest/door shelf found and modeled
  the next confirmed blockers:
  - `(23,20)->DOWN` into `(23,21)`, `(23,22)->UP` into `(23,21)`, and
    `(23,22)->LEFT` into `(22,22)` all verified blocked 5/5.
  - `(24,22)->UP` into `(24,21)` verified blocked 5/5.
  - `(17,21)->LEFT` into `(16,21)`, `(16,22)->UP` into `(16,21)`,
    `(16,22)->LEFT` into `(15,22)`, `(16,23)->DOWN` into `(16,24)`, and
    `(16,23)->LEFT` into `(15,23)` each verified blocked 5/5.
  - These are now modeled as directional blockers on `["23,21"].north/south`,
    `["22,22"].east`, `["24,21"].south`, `["16,21"].east/south`,
    `["15,22"].east`, `["16,24"].north`, and `["15,23"].east`.
- The same pass found `(14,20)` is a hidden passable spur from the west-side
  component (`(14,21)->UP` moved 5/5 and `(13,20)->RIGHT` was mixed/passable),
  but it does not bridge eastward because `(14,20)->RIGHT` stayed blocked. Do
  not promote it as the missing entrance-to-chest bridge yet.
- Reload follow-up after the user cleared/reloaded the script found five more
  clean return-route blockers:
  - `(23,20)->LEFT` into `(22,20)` verified blocked 5/5, so `["22,20"].east`
    is now modeled.
  - `(20,20)->DOWN`, `(19,20)->DOWN`, and `(18,20)->DOWN` into row 21 each
    verified blocked 5/5, so `["20,21"].north`, `["19,21"].north`, and
    `["18,21"].north` are now modeled.
  - `(17,21)->RIGHT` into `(18,21)` verified blocked 5/5, so
    `["18,21"].west` is now modeled.
  Direct `probe_edge_verify:16,20,DOWN,5` moved 5/5, so keep
  `["16,21"].north` open despite noisy autowalk timeout loops on that seam.
  With the new runtime blockers active, live `debug_pathfind_to:29,13` from
  `(17,21)` still finds a 30-step return route through `(13,20)` to the
  Rimuldar entrance.
- The return-side planner still finds a route from the lower fallback area to
  the Rimuldar entrance, but autowalk has noisy executor timeouts around
  `(16,20)->DOWN` and has not yet arrived at the entrance in a full live run.
  Older entrance-to-chest searches still had no clean durable route through the
  west-side component: the search reached `(13,20)->(13,21)->(14,21)` and
  rejected `(14,21)->RIGHT` into `(15,21)` as a modeled directional block.
- Follow-up on the entrance side checked the lower row-25 throat:
  `(22,25)->UP` into `(22,24)` first moved 5/5, so a temporary local
  passthrough made both `debug_pathfind_to_skip_npcs:23,23` and
  `debug_pathfind_adjacent_skip_npcs:24,23` plan through
  `(22,25)->(22,24)->(22,23)->(23,23)`. After input recovery/config reload and
  a fresh teleport, `probe_edge_verify:22,25,UP,3` blocked 3/3. The temporary
  passthrough was backed out; treat `(22,24)` as mixed/disproved for now, not
  permanent map data.
- Follow-up chest-side crawling found the missing public-side bridge at
  `(23,18)`. Direct verification from the stable approach
  `(23,17)->DOWN` moved 5/5, while the south approach `(23,19)->UP` remained
  mixed/noisy, so only the passthrough cell was promoted and no directional
  block was changed. After reload, live `debug_pathfind_to:23,23` from the town
  entrance `(29,14)` found a 17-step route through
  `(29,14)->(29,15)->(28,15)->...->(23,17)->(23,18)->(23,19)->...->(23,23)`.
  `auto_walk:23,23` and exact `validate_path` still fail from executor/timing
  behavior near the entrance row, including overshoot/deviation after the first
  step; treat that as the next route-following bug, not new map-block evidence
  yet.
- Follow-up tooling sync after that route find: coordinate debug path commands
  now route through `route_manager.plan_path_to_coordinates(...)` instead of
  calling `pathfinder` directly, and route-manager direct plans pass
  `path_debug` callbacks into A*. New `debug_pathfind_to_park_npcs:X,Y` and
  `debug_pathfind_adjacent_park_npcs:X,Y` commands temporarily park mobile NPCs
  before planning, giving an apples-to-apples comparison with parked-NPC
  autowalk/survey routes.
- The first reloaded `validate_path` against that parked-NPC debug route proved
  the remaining failure is executor timing: step 3 reached expected `(28,15)`,
  then overshot to `(27,15)` during the confirm window. `auto_step.lua` now
  forces the post-step neutral-release path after synthetic `inject_step`
  completions/blocks and queued-route completions/blocks, while preserving the
  softer release behavior for ordinary manual holds. After reload, that old
  step-3 overshoot was fixed, but the next run exposed the companion retry path:
  step 4 `(28,15)->WEST` retried after an early movement twitch, scheduled a
  synthetic turn re-press, reached `(27,15)`, then overshot to `(26,15)`.
  `auto_step.lua` now prevents non-route `inject_step` retries from scheduling
  that queued-route-only twitch/re-press path once movement has already started.
  After reload, that change removed the observed overshoot class in the traced
  `validate_path` runs. The remaining failures were real engine blockers, not
  timing: direct raw verifiers confirmed `(25,16)->DOWN`, `(24,16)->DOWN`,
  `(23,16)->DOWN`, `(22,16)->DOWN`, `(21,16)->DOWN`, `(20,16)->DOWN`,
  `(19,16)->DOWN`, `(21,21)->RIGHT`, and `(29,17)->LEFT` as blocked 5/5, while
  `(18,16)->DOWN` and `(28,16)->DOWN` moved 5/5 and remain open. With those
  blockers runtime-injected, the parked-NPC planner found and `validate_path`
  completed a full entrance-to-chest route from `(29,13)` to `(23,23)`:
  `(29,13)->(29,14)->(29,15)->(28,15)->(27,15)->(27,16)->(27,17)->(26,17)->(25,17)->(24,17)->(23,17)->(23,18)->(23,19)->(23,20)->(24,20)->(24,21)->(23,21)->(23,22)->(23,23)`.
  The final live result was `VALIDATE COMPLETE: 18/18 steps OK, 0 mismatches`.
  The confirmed blockers have now been promoted to
  `MAP_DIRECTIONAL_BLOCKS[0x0B]`; the verified-open `(18,16)->DOWN` and
  `(28,16)->DOWN` crossings remain unblocked. Reload Lua before rerunning
  important-target routes against the permanent data.
- `auto_step_timeout` was raised from 45 to 60 in `config.lua`/`dw_access.ini`
  because several noisy-but-passable route steps were reaching the old timeout
  edge. This is executor tolerance, not evidence for new map blockers.
- Entrance-to-Weapons Merchant follow-up after the geometry changes found one
  new confirmed blocker and the missing bridge for the replacement route.
  `probe_edge_verify:20,8,RIGHT,5` blocked entry into `(21,8)` from the west
  5/5, so `MAP_DIRECTIONAL_BLOCKS[0x0B]["21,8"].west` is now modeled. With
  that barrier active, the planner needed the east x=29 hidden north strip:
  `(29,13)->UP` moved into `(29,12)` 5/5, and forced raw probes moved
  `(29,12)->UP`, `(29,11)->UP`, `(29,10)->UP`, and `(29,9)->UP` 5/5 each.
  `(29,9)`, `(29,10)`, `(29,11)`, and `(29,12)` are now Rimuldar passthrough
  cells. Reload Lua before retesting the Weapons Merchant route.
- Post-reload important-target route sweep looked good. Weapons Merchant, Inn,
  Magic Key Merchant, Chest, and exit routes all completed with NPC parking
  restored. The Magic Key route had one recovery near the end: `(2,8)->UP`
  into `(2,7)` blocked during the queued route/retry, then the planner
  recovered through `(2,8)->RIGHT` into `(3,8)` and finished at the merchant.
  Direct follow-up verifiers showed the suspicious edges were timing/noisy
  artifacts, not new map blockers: `(2,8)->UP`, `(16,17)->RIGHT`, and
  `(4,9)->RIGHT` each moved 5/5. No new map patch is indicated from this pass.
  The crawler-opened hidden paths also produced a working route from the Magic
  Key Merchant back to the main entrance. Rimuldar is now clean enough to leave;
  next route/map work should move on to another town, cave, or gameplay target
  instead of continuing broad Rimuldar blocker harvesting.
- Do not promote the other autowalk blocker-looking seams yet: `(23,21)->LEFT`
  was mixed 2 moved / 3 blocked, `(15,16)->DOWN` was mixed 2 moved / 3
  blocked, `(22,25)->UP` became mixed after the fresh 3/3 block, and
  `(23,20)->LEFT` stayed mixed/noisy on the latest recheck. A `validate_path`
  run aborted early from row-14 overshoot after retries, not from a map
  blocker. The older `(23,20)->DOWN` mixed note is superseded by the clean 5/5
  verifier above.
- `test_map_reader.lua` was updated for the open approaches/latest blockers and
  now passes all 33 tests. `test_auto_step.lua` also passes all 51 tests after
  the timeout default/config update.

## Rimuldar Frontier Crawler Shakedown (2026-05-21)

- A bounded `crawl_map_frontier:attempts=2,max_edges=60` from `(13,20)` walked
  the west-side vertical strip and safely stopped when `(13,1)->DOWN` intended
  `(13,2)` but landed at `(13,0)`. The crawler restored the parked mobile NPC
  and logged `reason=movement_drift` instead of treating the drift edge as map
  geometry.
- Direct follow-up promoted only the clean passthroughs:
  `probe_edge_verify:13,5,UP,5` moved into `(13,4)` 5/5, and
  `probe_edge_verify:13,3,UP,5` moved into `(13,2)` 5/5. These are now in
  `MAP_PASSTHROUGH_CELLS[0x0B]`.
- Do not promote `(13,1)` yet. Force-origin raw probes from `(13,2)->UP` moved
  into `(13,1)` 3/3, but the hero later settled at `(13,0)` before a reverse
  probe could start. Treat it as an unstable north-edge frontier until a
  post-patch verifier or dedicated exit model classifies it.
- `map_crawler.lua` now removes a false-wall passthrough candidate from export
  if that cell later becomes the origin of a boundary, transition,
  position-drift, or movement-drift edge. This prevents `(13,1)`-style
  frontier/exit artifacts from appearing as normal review snippets.
- Post-reload live retest showed that `(13,4)` and `(13,2)` now classify as
  normal modeled passthroughs, and `(13,1)` correctly logs
  `MAP_CRAWL_UNSTABLE_CANDIDATE`. It also showed the crawler should not keep
  exploring sideways from such an unstable frontier: the old runtime continued
  through `(12,1)` and exported `(12,2)`. Treat that `(12,2)` export as
  frontier-contaminated and do not patch it. `map_crawler.lua` now makes
  unstable cells backtrack-only during the same crawl; reload before retesting
  this live.
- Post-backtrack-only reload confirmed the fix: `(13,1)` immediately
  backtracked to `(13,2)` instead of probing sideways into `(12,1)`. The crawl
  then found a clean adjacent x=12 strip from stable origins. Direct verifiers
  promoted `(12,2)`, `(12,8)`, `(12,9)`, and `(12,11)` as passthroughs:
  `probe_edge_verify:13,2,LEFT,5`, `probe_edge_verify:12,7,DOWN,5`,
  `probe_edge_verify:12,10,UP,5`, and `probe_edge_verify:12,10,DOWN,5` all
  moved 5/5 with no drift, map change, refusal, timeout, or interruption.
- Verification: `luac -p map_crawler.lua main.lua test_map_crawler.lua
  test_map_reader.lua`, `lua test_map_crawler.lua` (18 tests),
  `lua test_map_reader.lua` (33 tests), `lua test_map_survey.lua` (45 tests),
  and `lua test_debug_tools.lua` (5 tests) passed. `git diff --check` only
  reported the existing `dw_access.ini` CRLF warning.

## Current Emulator Note

FCEUX is now the default gameplay launcher again after the same-save emulator
bakeoff. BizHawk remains the explicit automation/debug path because its script
reload workflow is useful and its lag did not appear to corrupt automated
results. `SDL.AutoResume` is old-session restore, so the FCEUX launcher leaves
it untouched and relies on explicit `--state-slot` / `--loadstate` for slots.
The FCEUX path now launches with `-bginput 0`, enables Hide Menu through
`SDL.ToggleMenu = 1`, blanks `SDL.Hotkeys.MainMenuHide` and
`SDL.Hotkeys.FullScreen`, and has a manual recovery helper:
`./recover_fceux_input.sh`. That helper focuses qfceux, sends
LeftAlt/RightAlt/generic Alt key-up, taps Escape, resets
`dw_keyboard_input.txt` to `-`, and queues `input_status:fceux_recovery`.
FCEUX command-line ROM/Lua startup is still less reliable than BizHawk's
reload path; if readiness fails but qfceux is open, manual ROM plus `main.lua`
loading remains the practical gameplay fallback.

Same-save emulator bakeoff: use raw battery data as the portable baseline, not
FCEUX `.fc*` savestates or BizHawk `.State` files. `./launch_dw.sh
--battery-save PATH` now accepts either `.sav` or `.SaveRAM` and copies it to
the selected emulator's expected save path. The local FCEUX and BizHawk battery
files both present as 8192-byte raw save data:
`D:\emulation\fceux\bin\sav\Dragon Warrior (USA) (Rev 1).sav` and
`D:\emulation\bizhawk\NES\SaveRAM\Dragon Warrior.SaveRAM`. The current bakeoff
baseline is the FCEUX king-save copy at
`project_resources/saves/emulator_bakeoff/dw1_bakeoff_king_save_2026-05-18.sav`
with SHA-256
`fdbf2150210b8761301ed75285885caf806d1c58f4cc08eb569dee148a099c4d`.
Detailed bakeoff results are recorded in
`project_resources/emulator_bakeoff/README.md`. FCEUX passed the first
player-feel run on 2026-05-18: no observed emulator lag during castle
autowalk, sage dialogue, object navigation/mode switching, overworld movement,
or combat. The log window from `bakeoff_fceux_start` to `bakeoff_end` still
showed the native `LeftAlt` latch, but it stayed quarantined: 10
`INPUT_STALE_ALT_IGNORED` and 10 `INPUT_STUCK_ALT` entries, all
`spoken=false`, with no `spoken=true` regression and 57 bridge active/clear
pairs. The route blemishes were script-side rather than emulator-side:
`AUTO_WALK_NO_PATH_DETAIL ... reason=stationary_npc_blocker` at the castle exit
and two Rimuldar overworld route blocks near `(93,49)` / `(93,52)`.
BizHawk's same-save run is also recorded in
`project_resources/emulator_bakeoff/README.md`. It transferred the save
correctly and kept clean input (`left_alt=false`, no stale/stuck Alt, no bridge
events), but lost the player-feel comparison: startup had a small hitch, route
start/seam crossings caused 1-2 second lag/audio cut-outs, `Shift+O` mode
switching lagged around a second per swap, map transitions had small spikes,
and battle spell-menu navigation hitched. Log evidence supports the rough
route/seam profile: 2 `ROUTE_PLAN_TIMING` entries at 550 ms and 1268 ms, 24
`SEAM_BRUTE_FORCE`, 23 `AUTO_WALK_TIMING_RETRY`, 3 `PATH_RUNTIME_BLOCK`, 4
overworld blocked events, and post-run `PPU_STATS reads=149279028`. Current
verdict: FCEUX is the normal gameplay launcher again, while BizHawk remains the
explicit automated-debugging path unless we decide to tune BizHawk's
route/object/menu scanning further. `./launch_dw.sh` now defaults to FCEUX; use
`./launch_dw.sh --emulator bizhawk` or `./launch_bizhawk.sh` for BizHawk.
Launcher flip validation passed `bash -n launch_dw.sh launch_bizhawk.sh
launch_fceux.sh recover_fceux_input.sh`, `git diff --check`,
`./launch_dw.sh --dry-run`, `./launch_dw.sh --emulator bizhawk --dry-run`,
`./launch_dw.sh --state-slot 1 --dry-run`, `./launch_dw.sh --emulator bizhawk
--state-slot 1 --dry-run`, and FCEUX/BizHawk `--battery-save` dry-runs against
the bakeoff save. Earlier save-transfer PowerShell dry runs also passed:
`launch_bizhawk.ps1 -BatterySavePath <FCEUX .sav> -DryRun` and
`launch_dw.ps1 -BatterySavePath <BizHawk .SaveRAM> -DryRun`. The PowerShell
BizHawk dry run resolved the target to
`D:\emulation\bizhawk\NES\SaveRAM\Dragon Warrior.SaveRAM`; the FCEUX dry run
resolved the target to
`D:\emulation\fceux\bin\sav\Dragon Warrior (USA) (Rev 1).sav`.
Earlier FCEUX Alt-stabilization static validation passed `luac -p
debug_tools.lua main.lua test_debug_tools.lua`, `lua test_debug_tools.lua`,
`bash -n launch_dw.sh launch_fceux.sh recover_fceux_input.sh`, `git diff --check`,
`./launch_dw.sh --dry-run`, `./launch_dw.sh --state-slot 1 --dry-run`,
`./launch_dw.sh --emulator fceux --dry-run`, `./launch_dw.sh --emulator fceux
--state-slot 1 --dry-run`, PowerShell `launch_dw.ps1 -DryRun` and
`-StateSlot 1 -DryRun`, and `recover_fceux_input.ps1` / `.sh` dry-runs.
Live FCEUX follow-up on 2026-05-18 shows Hide Menu plus the recovery helper
alone was not enough, but the new hotkey-blanking and benign-idle handling are
live. The patched launcher blanked `SDL.Hotkeys.MainMenuHide` (`Alt+/`) and
`SDL.Hotkeys.FullScreen` (`Alt+Return`), and the config now shows both blank
with `SDL.ToggleMenu = 1`. FCEUX still did not reliably honor the command-line
ROM/Lua startup, so the user manually loaded the ROM and script. After manual
load, command polling worked: `input_status:manual_after_load` at frame `04440`
reported `keys=LeftAlt joy1=- left_alt=true`. The patched Lua treated this as
benign idle noise: `INPUT_STALE_ALT_IGNORED ... reason=fceux_alt_tab_latch`
and `INPUT_STUCK_ALT ... spoken=false ... benign=true`. Running
`./recover_fceux_input.sh` cleared the latch at frame `04920`
(`keys=- joy1=- left_alt=false`), but FCEUX relatched by frame `05100`; the
follow-up `input_status:after_helper` at frame `05160` again reported
`left_alt=true`, and `input_status:final_fceux_alt_check` at frame `13440`
still reported `keys=LeftAlt joy1=- left_alt=true`. Pre-bakeoff verdict: FCEUX
still had the native Alt latch, but idle latch state no longer spoke or
synthesized joypad input. That caution is now superseded by the same-save
bakeoff recorded above; the latch stayed benign during real Alt+Tab-heavy use,
so `./launch_dw.sh` is back to FCEUX by default.
The follow-up FCEUX grinding pass supports the quarantine model. In the fresh
`dw_debug.log` started at `2026-05-18 14:08:31`, the log showed 18
`INPUT_STALE_ALT_IGNORED` entries and 3 `INPUT_STUCK_ALT` entries; all stuck
Alt warnings were `spoken=false` and `benign=true`, with no `spoken=true`
regression. Real bridge input still worked while FCEUX thought Alt was held:
217 bridge activations, including 16 with `keys=LeftAlt`, and no neutral bridge
activation. The only blocked seam observations were queued overworld route
blocks at `(106,72).west` and `(105,68).east`, both outside stale-Alt episodes.
Post-grind probe `input_status:post_grind_log_review` at frame `70920` still
reported `keys=LeftAlt joy1=- left_alt=true`, and `report_position` put Bill on
world map `(102,72)`. Treat the native latch as still present but quarantined
for ordinary manual play unless a later log shows route evidence, speech spam,
or menu focus contamination during `keys=LeftAlt joy1=-`.
Follow-up window-switch stress pass stayed clean. After the frame `70920`
post-grind marker, the user's heavy Alt+Tab/window switching produced no new
log events at all until the review probe. The fresh
`input_status:post_window_switch_stress` at frame `90000` still reported
`keys=LeftAlt joy1=- left_alt=true`, and `report_position` still put Bill on
world map `(102,72)`. Between frames `70920` and `90000` there were no new
`INPUT_STALE_ALT_IGNORED`, `INPUT_STUCK_ALT`, bridge, menu, seam, autowalk, or
speech-warning anomalies. This strengthens the current verdict: FCEUX's native
Alt latch persists but stays inert under window switching.

## Active Resume

Strategic map-completion pivot after the Merchant 4 push: do not spend the
next phase trying to make every map perfectly decoded before play can continue.
Prioritize viable paths to merchants, inns, exits, stairs, locked doors,
chests, and other essential services. Leave unreachable dialogue-only NPCs for
the polishing phase unless they provide a progression clue, required hint, or
other gameplay-critical information.

Rimuldar Magic Key route status: the seller and counter stand are correct, and
the missing west-side bridge is now identified. Earlier `2026-05-18` work had
temporarily promoted `(2,8).west` after noisy/misaligned checks, but a clean
post-recovery verifier disproved it: `probe_edge_verify:1,8,RIGHT,5` moved
5/5 into `(2,8)`. A single forced-origin raw reverse probe from `(2,8)->LEFT`
also moved back to `(1,8)`. The patch now exposes `(2,8)` as a Rimuldar
passthrough, removes the false `(2,8).west` / `(1,8).east` closures, and keeps
only `(2,8).south` blocked because `(2,9)->UP` still reports the south approach
closed. The corrected town-tileset route then found one more required
connector: `(9,10)->LEFT` into `(8,10)` reconfirmed blocked 5/5, but
`probe_edge_verify:9,10,UP,5` moved 5/5 into `(9,9)`. `map_reader.lua` now
exposes `(9,9)` as the row-9 connector while keeping `(8,10).east` closed.
Follow-up raw/probe evidence also confirmed the route corridor west of it:
forced-origin `(9,9)->LEFT` moved into `(8,9)`, then repeated verifiers showed
`(8,9)->LEFT`, `(7,9)->LEFT`, `(6,9)->LEFT`, `(5,9)->LEFT`, `(4,9)->LEFT`,
`(3,9)->LEFT`, `(2,9)->LEFT`, and `(1,9)->UP` each moved 5/5.

The validated live entrance strip is:
`(1,8)->RIGHT` into `(2,8)` confirmed passable 5/5,
`(2,8)->RIGHT` into `(3,8)` moved by raw probe,
`(3,8)->UP` into `(3,7)` confirmed passable 5/5,
`(3,7)->UP` into `(3,6)` confirmed passable 5/5, and
`(3,6)->RIGHT` into the key stand `(4,6)` confirmed passable 5/5.
The running FCEUX script picked up the `(2,8)` bridge after manual reload, then
live `debug_pathfind_to:4,6` failed at the row-10 frontier until `(9,9)` was
added. A ROM-backed local A* using the patched files, real ROM, and town
terrain finds `(29,14)->(4,6)` as a 39-step route while blocking Old Man 1 at
`(4,7)`. After another manual reload, the live FCEUX autowalk from the town
entrance `(29,13)` queued 40 steps and reached the Magic Key stand `(4,6)`,
faced south, held the key merchant, and opened the 53 G Magic Key prompt. Treat
the early failures in that log as input/state contamination: three attempts
from `(29,13)` falsely classified `(29,14).north` as blocked after leftover
teleport/FCEUX bridge input (`Return+RightShift`, later Down/Left/A/B/Start
bursts). The successful run later moved the same edge and changed the seam
classification from `blocked_only` to `noisy`. Do not promote `(29,14).north`
as a blocker. The successful route also had one timing retry at `(2,8)->UP`
into `(2,7)`; the retry moved, so do not promote `(2,7).south` either.

Post-merchant Rimuldar NPC pass: the remaining useful clue NPCs are
documented. `Old Man 3` at `(3,23)` asks about a magic temple with a yes/no
prompt. The access seam `(1,23)<->(2,23)` moved both directions in FCEUX, so
`map_reader.lua` exposes both false-wall cells; `(2,23)` is the practical
public stand facing east. `Old Man 4` / Howard at `(20,23)` gives the Kol bath
clue, "Four steps south of the bath in Kol thou shalt find a magic item."
Current scope: the Rimuldar Wings chest room phantom door is solved. External
guide data says the inn treasure is behind an outer and inner door; live FCEUX
confirmed the outer door at `(21,21)` and the inner Wings chest door at
`(22,23)`. The first known door was `(22,23)`: `report_door_state` after the
user opened it from inside reported `slots=0=(22,23)` while Bill stood at
`(23,23)`, and `inspect_tile:22,23` showed tile 6 walkable floor, so
`map_reader.lua` gates it as a magic-key door until opened-door RAM lists it.
The missing outer door was found by opening from `(21,22)` facing north:
`report_door_state` then reported `keys=4 slots=0=(22,23) 1=(21,21)`, and
`probe_edge_verify:21,22,UP,3` moved 3/3 through `(21,21)` after opening.
`objects.lua` now exposes `Rimuldar Inn Outer Door` and `Wings Chest Door`; the
nearby chest object is `chest_7` at `(24,23)`.

Earlier clean FCEUX probes proved `(13,18)` is a real false-wall connector:
`(13,19)->UP` entered `(13,18)` and continued to the public row, and the
reverse route moved back down through `(13,18)` to `(13,19)`. Later locked-room
return testing disproved that connector as a current escape from the opened
inner-door-side start. The old clean no-path from `(23,23)` to `exit_29_13`
was missing the outer door at `(21,21)`, so do not reuse it as current route
truth. A patched-code local route simulation with opened-door RAM slots
`(22,23)` and `(21,21)` now finds `(23,23)->exit_29_13` and
`(21,22)->exit_29_13`; live raw verification confirms `(21,22)->UP` through
the opened door, even though the still-running FCEUX script had not reloaded
the source patch and previewed the old static directional block. The row-22
branch is the outer-door approach, not a dead end. The lower row-25 strip is
also real: `(20,25)->LEFT` verified passable 5/5 into
`(19,25)`, and `(19,25)->LEFT` moved into `(18,25)`. The apparent throat from
`(21,23)->DOWN` into `(21,24)` is false from all legitimate approaches, though
a fresh forced-origin probe once moved through it; routes from east, west, and
north all blocked, raw held DOWN did not move, and OPEN while facing south
reported "There is no door here."

Do not promote `(19,25).east`; the 15-attempt verifier blocked there with
`npc_blocked=true`, so that lead is occupancy-contaminated. Validation after
the outer-door patch passed `luac -p map_reader.lua test_map_reader.lua
objects.lua test_objects.lua`, `lua test_map_reader.lua`,
`lua test_objects.lua`, and `git diff --check`. The running FCEUX script
reloaded the patch afterward: live `inspect_tile:21,21` reports
`reason=door_open`, `directional_blocked=false`, and `effective_passable=true`.
Follow-up door-side routing confirms the weirdness is real door/edge geometry:
the later live door RAM had `keys=4` but all opened-door slots were `(0,0)`.
User confirmation explains why: at least in Rimuldar, leaving the map closes
opened magic-key doors, and reopening them consumes another key. Treat door
slots as map-entry session state, not a permanent "unlocked" flag.
With the doors closed, `(22,24)->UP` into the inner door `(22,23)` and
`(21,22)->UP` into the outer door `(21,21)` both inspect as `reason=door_closed`.
The direct north edge from `(22,22)->UP` into `(22,21)` is also a real wall:
`probe_edge_verify:22,22,UP,3` blocked 3/3. The open route from the inner-door
side is therefore left to `(21,22)` and then through the outer door after it is
opened, not straight north through `(22,21)`.
The user's exit autowalk after breaking into the route network exposed two
clean new directional blockers: `probe_edge_verify:16,20,UP,3` and
`probe_edge_verify:17,20,UP,3` both blocked 3/3, so `map_reader.lua` now models
`(16,19).south` and `(17,19).south`. Do not promote the other tempting seams:
`(17,19).east` stayed mixed at 1 moved / 2 blocked, `(21,24).south` moved 3/3,
and `(15,24).south` stayed mixed at 1 moved / 2 blocked. Follow-up user
testing then confirmed the route did leave town once: the live log changed to
World Map at frame `11968` after autowalk stepped `(28,16)->RIGHT` into
`(29,16)`. That was a drifted/rerouted exit path, not the clean current plan:
fresh `debug_pathfind_to:29,13` from `(21,20)` traces through
`(21,20)->...->(13,18)->...->(29,13)` and does not include `(29,16)`.
`map_reader.lua` now guards `(29,16).west` so ordinary in-town routing does not
treat that row-16 transition as a corridor. Current live cleanup state:
`POSITION: map=0x0B(Rimuldar) x=21 y=20`, `PATH_STATE target=nil`,
`RUNTIME_BLOCKS map=0x0B none`, and `DOOR_STATE keys=1 slots=0=(21,21)`,
so the outer door is open and the inner door is closed. The user also reports
the throne-room door likely stays open after unlocking; treat that as a
possible special case and do not generalize Rimuldar's map-leave door reset to
all magic-key doors without a live check.
Full validation of every dialogue-only NPC route can wait for a later polish
pass; it is not worth re-entering the one-way maze unless one of those NPCs
proves progression-critical.

Current Rimuldar Magic Key route patch in the worktree: `Old Man 1` at `(4,7)`
is the live-confirmed Magic Key seller, using public stand `(4,6)` facing
south. The route is a one-way maze, matching the guide warning that the key
seller is reached by walking around the outside/water edge. `map_reader.lua`
now includes Rimuldar passthrough cells `(24,6)`, `(19,9)`, `(14,8)`,
`(13,9)`, `(13,8)`, `(16,8)`, `(1,8)`, `(1,7)`, `(2,7)`,
`(1,23)`, `(2,23)`, and final maze
cells `(6,3)`, `(5,3)`, `(5,5)`, `(4,5)`, `(3,5)`, and the confirmed bridge
cells `(2,8)`, `(3,7)`, and `(9,9)`, plus the lower
escape strip `(4,7)`, `(4,8)`, and `(4,9)`, the one-way trap cell `(5,7)`,
the hidden lower lane `(5,9)`, `(6,7)`, `(6,8)`, `(6,9)`, and `(7,9)`, plus the
south-side connector `(13,15)` and `(13,16)`, the real south-side connector
`(13,18)` that is not a confirmed door-pocket escape, plus the latest manual
false-wall
cells `(1,14)`, `(2,14)`, `(3,14)`, `(4,14)`, `(5,14)`, `(8,7)`, `(8,8)`,
and `(14,5)`, plus the northwest exit false-wall cells `(3,4)` and `(4,3)`.
Directional-only key-route blockers
now include `(24,12).south`, `(23,12).south`, `(25,11).east`,
`(20,10).south/west`, `(21,11).west`, `(21,12).south/west`,
`(24,8).south`, `(13,6).north/south`, `(13,8).east`, `(14,6).east/south`,
`(13,7).east`, `(3,6).north/east`, `(4,7).east`, `(5,6).north/south/west`,
`(6,3).east/west`, `(6,4).east/north/west`, `(6,5).east/north/west`,
`(6,6).east`, `(0,5).east`, `(1,4).south`, `(2,5).west`, `(2,6).west`, `(2,7).west`, `(2,8).south`, `(17,6).east`, `(17,7).east`, `(28,13).east`,
`(10,6).east/north`,
`(9,6).north/west`, `(12,6).north/south/west`, `(13,9).south`,
`(13,7).west`, `(14,9).east/south`, `(15,9).south`, `(16,9).south`, and
`(17,9).east/south`, `(16,19).south`, and `(17,19).south`, plus the newest
entrance-side blocks `(22,12).south`,
`(9,12).east`, `(8,14).east`, `(7,15).south`, `(6,16).east/south`,
`(5,16).south`, `(3,13).south`, `(3,15).north`, and
`(17,17).east`, plus the latest maze seals `(4,16).south`, `(3,16).south`,
`(7,11).south`, `(4,8).south`, and `(6,8).south`, plus lower-lane pocket blocks
`(3,12).north`, `(4,11).north/west`,
`(5,8).north/west`, `(5,11).north`, `(6,7).west`, `(6,11).north/south`, and
`(7,10).north/west`, `(3,8).south`, `(5,8).south`,
`(6,2).east`, `(6,7).east`, and `(6,8).east`, and entrance-loop blocks
`(8,10).east/north`, `(9,11).north`, `(9,12).south`, and `(8,13).east/west`, plus
the newest blockers `(2,15).south`, `(3,16).west`, `(4,12).south`,
`(3,13).east`, `(5,2).south`, `(2,15).west`, `(4,3).south`, `(4,4).south`,
`(8,12).west`, `(6,15).north`, `(7,14).north/west`, `(25,12).east/south`,
`(21,6).west`, `(21,7).west`, and the northwest-exit transition guard `(4,2).south`. The newest
FCEUX passes
reconfirmed the dead-end exits from `(12,7)` as real blockers, then found a
clean entrance-side block at `(18,9)->LEFT` into `(17,9)` and return-side false
drops into `(9,6)`, `(12,6)`, and `(13,6)`. The user then found the one-way
lower return connector `(4,8)->DOWN` into `(4,9)`; follow-up autowalk from
`(4,10)` proved the bad pocket exits `(4,10)->DOWN` into `(4,11)` and
`(5,10)->DOWN` into `(5,11)` before stale Alt returned. The old missing
entrance-side false wall note is now split: `(2,7)` remains a Rimuldar
passthrough cell, but later route-shaped evidence closes its west approach from
`(1,7)`. Keep `(5,3).east` open for now. The latest both-direction pass added the three
entrance-side blocks `(22,12).south`, `(9,12).east`, and `(8,14).east`, then
proved the visible pocket exits from `(3,11)` are closed:
`(3,11)->DOWN` into `(3,12)` and `(3,11)->RIGHT` into `(4,11)` repeatedly
blocked. Route-back failure was NPC/model related in the other direction:
fresh attempts to leave `(4,6)` by walking south into Old Man 1 at `(4,7)`
repeatedly blocked, while TALK from `(4,6)` facing south still opened the Magic
Key shop. `objects.lua` now treats the seller as movement-blocking again; the
valid service stand remains `(4,6)`. The next route batch showed `(5,7)` is a
tiny one-way pocket, not the actual return lane: attempts from `(5,7)` into
`(5,6)`, `(4,7)`, `(6,7)`, and `(5,8)` all blocked, while the earlier
`(4,7)->RIGHT` proof only proves entry into the pocket. The same batch proved
`(18,17)->LEFT` into `(17,17)` is closed, and
manual movement walked the south-side false cells `(13,15)` and `(13,16)`,
which reconnect the entrance route without using `(17,17)`. The suspicious
`(6,8)` sequence remains hidden passability, not a full-cell blocker: earlier
logs moved through it, but the latest clean route-shaped batch proves the south
approach from `(6,9)->UP` into `(6,8)` is blocked and should be modeled
directionally. The latest FCEUX
batch proved the prior south-side connector patch was live by walking through
`(13,15)` and `(13,16)`, then found clean blockers at `(7,16)->UP` into
`(7,15)` and `(7,16)->LEFT` into `(6,16)` before stale Alt returned. The return
route then repeatedly blocked `(7,9)->DOWN` into `(7,10)`, but manual movement
crossed `(7,9)<->(8,9)` twice, so `(8,9)` is now a passthrough connector.
The next reloaded/manual pass showed neither route was fully solved yet:
entrance-side autowalk looped at `(6,17)->UP` into `(6,16)` and
`(5,17)->UP` into `(5,16)`, then a manual left-side pocket reached false-wall
cells `(1,14)->(2,14)->(3,14)` before route-to-key looped on `(3,14)->UP`
into `(3,13)` and `(3,14)->DOWN` into `(3,15)`. Return-side walking proved
`(8,9)->DOWN` into `(8,10)`, `(11,6)->LEFT` into `(10,6)`, and later
`(7,3)->LEFT` into `(6,3)` as blocked; `(14,5)` is now the upper false-wall
connector that keeps the return graph open after those seals. The newest
pre-Alt FCEUX snapshot found the next real blockers at `(4,17)->UP` into
`(4,16)`, `(3,17)->UP` into `(3,16)`, `(7,12)->UP` into `(7,11)`,
`(4,9)->UP` into `(4,8)`, `(6,9)->UP` into `(6,8)`, `(5,4)->RIGHT` into
`(6,4)`, and `(5,3)->RIGHT` into `(6,3)`. The row-14 false-wall cells
`(4,14)` and `(5,14)` are now passthroughs; they shorten the inbound/recovery
route after those seals. The latest route/manual pass added clean blockers at
`(2,16)->UP` into `(2,15)`, `(2,16)->RIGHT` into `(3,16)`,
`(4,13)->UP` into `(4,12)`, `(4,13)->LEFT` into `(3,13)`, and
`(5,3)->UP` into `(5,2)`. The earlier `(4,6).north` closure was later
disproved because the Magic Key public stand must be reachable from
`(4,5)->DOWN`. Manual movement
then found the alternate northwest world-map exit: the player stood on
false-wall `(4,3)`, pressed north, and the log changed to map `0x01` at world
position `(102,72)`; re-entering from `(102,71)->DOWN` landed at Rimuldar
`(29,14)`. `objects.lua` now exposes this as `Northwest Exit to World Map` at
`(4,3)` facing north, while `(4,2).south` is blocked so normal in-town A*
does not route through the exit transition as if it were a corridor. The latest
patch also blocks `(4,3).south`, so the route from the key stand reaches the
northwest exit through `(5,3)->LEFT` instead of the blocked `(4,4)->UP` seam.
The latest local ROM-backed A* again finds a service-grade entrance route after
the corrected `(2,8)` bridge patch: `(29,14)->(4,6)` is a 39-step route with
Old Man 1 at `(4,7)` blocked. The return from the stand to the northwest exit
still survives as 5 steps. The old east-exit return is geometry-only and tries
to walk through the seller, so it is intentionally no-path when NPC occupancy
is modeled. Starting in the trap cell `(5,7)` correctly has no route to the
east exit.
Validation after this patch passed `luac`, `test_map_reader.lua`,
`test_objects.lua`, `test_route_manager.lua`, `test_debug_tools.lua`,
`git diff --check`, and the ROM-backed route proof above. Manually
reload/restart FCEUX Lua before trusting the next live autowalk test.
`route_manager.lua` now logs `AUTO_WALK_NO_PATH_DETAIL` with start, goal,
target, mode, reason, goal block, and blocker counts when autowalk immediately
fails to plan.
The next live autowalk attempt should restart/reload FCEUX Lua before testing:
the latest route attempts happened while FCEUX reported stale `LeftAlt`
(`keys=LeftAlt`, `joy1=-`). Treat the stale-Alt blocked seams such as
`(4,5).south` and `(29,14).north` as contaminated, not map evidence. Runtime
seam memory and runtime blocks for map `0x0B` were cleared afterward.
`debug_tools.lua`/`main.lua` now tag FCEUX LeftAlt-only neutral bridge frames
as sentinel-only stale input. `main.lua` releases any active `auto_step` once,
then pauses without repeatedly calling `joypad.set(1, neutral)`, so future
Alt-tab focus quirks should be less likely to manufacture blockers or fight
manual recovery movement. This does not clear FCEUX's native latched `LeftAlt`;
manual Alt/Escape recovery or a reload may still be needed. Final live cleanup
cleared map `0x0B` runtime blocks and seam memory, left autowalk stopped and
NPCs unfrozen, kept Bill at
`(4,10)`, and `input_status` still reported `left_alt=true`; press/release
Alt/Escape or restart/reload before trusting the next live blocker pass. The
latest log again ended with stale `LeftAlt` at frames `18937`/`19056`, after
the northwest exit re-entry proof, so clear Alt or restart/reload before the
next live autowalk attempt.
Follow-up FCEUX route/manual evidence promoted another Rimuldar Magic Key patch:
false-wall passthroughs `(1,5)`, `(1,13)`, `(3,9)`, and `(15,5)` are now
modeled. The new directional blockers are `(3,15).west`, `(4,12).east`,
`(5,11).south`, `(14,6).north`, `(24,12).north`, and `(25,11).west`. The
next log promoted `(2,15).west`, `(6,11).south`, `(8,12).west`,
`(4,4).south`, and `(4,3).south`; it also reopened `(4,6).north` because the
counter stand must be reachable from `(4,5)->DOWN`. The latest route-to-merchant
attempt got to `(6,14)`, then repeatedly looped on `(6,14)->RIGHT` into
`(7,14)` and `(6,14)->DOWN` into `(6,15)` before stale Alt returned, so
`(7,14).west` and `(6,15).north` are now modeled. The latest log repeatedly
blocked `(1,7)->RIGHT` into `(2,7)`, and follow-up route-shaped evidence now
supersedes the earlier noisy/open probe: `(2,7).west` is modeled as a
directional blocker while `(2,7)` remains a passable hidden cell for other
approaches. Next best live check after FCEUX reload/Alt recovery: the initial
no-path to the key seller may still involve live NPC contamination from
`Old Man 2` at `(6,13)`, but terrain now also needs a new alternate bridge into
the key-counter lane. The user then walked
to the Weapons Merchant, canceled the loop, and a new key path opened; the clean
pre-Alt weapon-route loop promoted `(25,12).east/south`, `(21,6).west`, and
`(21,7).west`. The later key-route loop reached `(7,13)` and promoted
`(8,13).west` plus `(7,14).north`. Stale Alt returned only after those key-route
blocks (`9585`/`9704`), so they are modeled. After reload, test
entrance-to-key and key-to-`Northwest Exit to World Map`; if entrance-to-key
fails immediately again, check current NPC occupancy around `(6,13)` before
adding more terrain blockers. Validation for this patch passed `luac`,
`test_map_reader.lua`, `test_objects.lua`, and ROM-backed route proof.
Newest runtime-only Rimuldar pass switched to the stricter manual/projection
loop. From `(4,15)`, the live log repeatedly blocked `(4,15)->LEFT` into
`(3,15)` and `(4,15)->DOWN` into `(4,16)` before stale Alt reactivated; counts
reached `(3,15).east` 22 blocked / 0 moved and `(4,16).north` 23 blocked / 0
moved. A follow-up seam-list pull after manual wandering promoted those two
edges permanently and also promoted `(6,15).west`, which was still 22 blocked /
0 moved. The first sift held `(5,16).north` open as noisy, but the post-reload
autowalk reached `(5,15)` and the fresh seam list showed `(5,15)->DOWN` into
`(5,16)` blocked 3/3 with no moves and no runtime block left behind. That edge
is now modeled too. Direct verifiers after the patch confirmed both suspected
exits from `(5,15)`: `(5,15)->DOWN` into `(5,16)` blocked 3/3, and
`(5,15)->RIGHT` into `(6,15)` blocked 3/3. Current live position after the
latest pull was `(5,15)`. Even with NPCs skipped,
`debug_pathfind_adjacent_skip_npcs:4,7` now reports no path from `(5,15)` to
any square adjacent to Old Man 1 (`visited=207`, `path=0`), so the split is
geometry, not just live NPC clutter. A local ROM-backed component/frontier pass
showed the nearest one-hop false-wall candidates that could reconnect the
current component to the key-stand component are `(1,12)` and `(2,13)`; farther
candidates include `(8,16)`, `(10,11)`, and `(9,9)`. The follow-up verifier
batch found the clean bridge at `(1,12)`: `(1,13)->UP` moved 4/5 and
`(1,11)->DOWN` moved 5/5. Local ROM-backed routing with only `(1,12)` added
finds a 16-step route from `(5,15)` to stand `(4,6)`:
`1 north, 4 west, 7 north, 1 east, 1 north, 2 east`. `(2,13)` is not modeled
yet: `(2,14)->UP` moved 5/5, but `(3,13)->LEFT` into it blocked 5/5 and
`(1,13)->RIGHT` was mixed 2 moved / 3 blocked. After the permanent patch,
reload FCEUX Lua and retest entrance-to-key and key-to-`Northwest Exit to World
Map`. Validation after the `(5,16).north` promotion passed `luac -p
map_reader.lua test_map_reader.lua debug_tools.lua main.lua
test_debug_tools.lua`, `lua test_map_reader.lua`, `lua test_debug_tools.lua`,
`lua test_route_manager.lua`, and `git diff --check`; the same focused checks
also pass after the new `(1,12)` passthrough patch.
The next live route reached the new bridge and proved `(1,12)->UP` with
`probe_edge_verify:1,12,UP,5` as 5/5 passable, then choked later at the old
`(1,7)->RIGHT` into `(2,7)` connector. Later route-shaped evidence repeatedly
blocked that same seam and reached `blocked=18 moved=0`; a live runtime edge
was injected for `(2,7).west`, and `debug_pathfind_to:4,6 trace_path` from the
east entrance then returned no path. `map_reader.lua` now closes `(2,7).west`
permanently while leaving `(2,7)` itself exposed as a hidden passable cell.
The alternate `(3,8)` bridge is still not solved. Earlier
`probe_edge_verify:3,9,UP,5` moved 5/5 into `(3,8)`, while
`probe_edge_verify:4,8,LEFT,5` blocked 5/5 entering the same cell from the
east, but the latest live route superseded the south-entry proof:
`(3,9)->UP` into `(3,8)` blocked repeatedly under queued route plus seam
retries, reaching 9 blocked / 0 moved. `map_reader.lua` now models
`(3,8).south` as well as `(3,8).east`.
Fresh focused probing showed several tempting cells are pockets or real walls:
`(2,9)->UP` into `(2,8)` verified 0/5 moved, `(5,9)->UP` into `(5,8)`
verified 0/5 moved, `(7,9)->UP` into `(7,8)` verified 5/5 passable, but
forced/current probes from `(7,8)->LEFT`, `(7,7)->LEFT`, and `(7,2)->LEFT`
each blocked into the x=6 lane. `map_reader.lua` now models `(2,8).south`,
`(5,8).south`, `(6,8).east`, `(6,7).east`, and `(6,2).east`. A later clean
post-recovery verifier resolved the remaining `(1,8)->RIGHT` frontier:
`probe_edge_verify:1,8,RIGHT,5` moved 5/5 into `(2,8)`, so `(2,8)` is now
exposed as passthrough and `(2,8).west` must stay open.
The upper maze seams `(7,3)->LEFT`, `(7,4)->LEFT`, `(7,5)->LEFT`, and
`(7,6)->LEFT` each verified blocked 5/5, so do not remove the existing east
approach blockers around `(6,3)`..`(6,6)`.
Follow-up frontier probing found one more real lower-lane passthrough:
`probe_edge_verify:4,9,RIGHT,5` moved 5/5 into `(5,9)`, so `(5,9)` is now
modeled. That candidate does not break into the counter lane yet:
`probe_edge:UP` from forced `(5,9)` blocked into `(5,8)`, and the later
focused verifier closed west entry into that same pocket:
`probe_edge_verify:4,8,RIGHT,5` blocked `(5,8).west` 5/5. The upper-left
shortcuts through `(1,4)/(0,5)` also failed: `(1,5)->UP` and `(1,5)->LEFT`
each blocked 5/5. A stale/noisy `(2,5)` lead was disproved by the latest
route/probe pass: the route reached `(1,5)` and repeatedly blocked east into
`(2,5)`, then direct verifier classified `(1,5)->RIGHT` confirmed_blocked
5/5, so `(2,5).west` is now modeled while `(2,5)` remains standable for any
future non-west approach. The `(3,7)` lead is still valuable map data:
weighted static search picked `(3,8)->(3,7)->(3,6)`, and the follow-up clean
verifiers proved the complete final approach: `(3,8)->UP`, `(3,7)->UP`, and
`(3,6)->RIGHT` each moved 5/5. The corrected town-tileset run then reached the
row-10 frontier and found one more missing connector: `(9,10)->LEFT` into
`(8,10)` reconfirmed blocked 5/5, but `(9,10)->UP` into `(9,9)` moved 5/5.
With `(2,8)` and `(9,9)` exposed, local ROM-backed A* with town terrain and Old
Man 1 blocking movement now finds a 39-step route from `(29,14)` to the Magic
Key stand `(4,6)`. Reload FCEUX Lua before the next live autowalk test; the
running script needs to pick up the new `(9,9)` map patch.

Current Kol clue/object patch in the worktree: Woman 2 at `(12,1)` is the bath
clue NPC and talks from stand `(12,2)` facing north. Local image analysis of
`project_resources/maps/kol/external/mikesrpgcenter_kol.png` found the only
blue bath/water tile at `(9,2)`, so the guide clue "four steps south of the
bath" points to `(9,6)`. Live `inspect_tile:9,6` reported it walkable and
`debug_pathfind_to:9,6` from `(1,22)` found a route, so `objects.lua` now
exposes `Disturbed Earth Near Bath` at `(9,6)` in the Treasure filter. The user
then found the flute there live, confirming the coordinate. Old Man 1 is the
flute clue NPC; current `debug_pathfind_adjacent:2,13` from `(1,22)` chooses
stand `(3,13)` facing west. Old Man 4 is the better-weapons clue NPC at
`(1,1)`; current `debug_pathfind_adjacent:1,1` chooses stand `(1,2)` facing
north. The earlier Old Man 4 row-2 loop proved additional directional blockers
at `(9,2).east`, `(2,1).east`, and `(2,2).east`.

Current Northern Cave route patch in the worktree: `overworld_routes.lua` now
has a `northern_cave` route for the harp/Staff of Rain shrine west of Kol. It
targets the existing `overworld_northern_cave` Travel landmark at `(81,1)` and
completes when the player enters map `0x0D` (`Rain Shrine`). Aliases include
`northern cave`, `rain shrine`, `staff of rain`, `harp shrine`, `silver harp`,
`cave west of kol`, and `shrine west of kol`. This is a Kol-side route first:
from world-map Kol `(104,10)`, it guides through `Kol forest west edge`
`(96,13)` and `West of Kol forest bend` `(92,10)`, then takes a long
south-and-west detour around the water/mountain gap before approaching
`Northern Cave` `(81,1)`. Live testing exposed why the first short route was
wrong: the user reached `(91,5)` on the east shore pocket, with active route
`northern_cave` still targeting `Rain shrine west approach`; the route then
tried to pull west/north toward `(83,3)` even though the NESMaps overworld
orientation and live movement showed a water/mountain gap there. The corrected
route now recovers from `(91,5)` by targeting `West of Kol forest bend` and
heading south toward the detour. The user then reached the cave live with only
minor route noise. Static proof after the first Rain Shrine interior patch:
`lua test_overworld_routes.lua` (50 tests), `lua test_objects.lua` (59 tests),
`lua test_map_reader.lua` (29 tests), `lua test_route_manager.lua` (58 tests),
`luac -p` on route/object/map-reader files and tests, and `git diff --check`.
After the first shrine visit, the route back to Kol exposed the reverse-side
gap: an active plain `kol` route near the shrine could try to pick up the
southern `North Alefgard bridge road` / later Kol chain instead of backing out
through the Rain Shrine approach. `overworld_routes.lua` now has a
`kol_rain_shrine` route variant sharing the `overworld_kol` destination. It
reverses the Northern Cave approach from `(81,1)` back to Kol, and
`route_recalculate` can switch an already-active `kol` route onto that variant
when the current world-map position is near the shrine. Fresh user grinding
playtest after this patch: Kol to Northern Cave worked perfectly, and the
reverse route back to Kol had only a few minor hiccups. Treat remaining issues
on this route pair as polish unless later logs show a repeatable blocker. A
follow-up test found that requesting Northern Cave from Tantegel started the
Kol-side route at a disconnected Rain Shrine waypoint and produced an
unfeasible long segment. `overworld_routes.lua` now guards that case: Northern
Cave starts are accepted only in the local Kol/Rain Shrine corridor; from
Tantegel or other far western/southern starts, the request automatically starts
the Kol route first and explains that Northern Cave starts from Kol. Follow-up
route-selection bug fix: while a route is active, pressing route guidance on a
different supported Travel destination now replaces the active route again.
Same-destination selections still recalculate/status the current route, and
non-route selections still leave the active route in control.

Current Swamp Cave route patch in the worktree: `overworld_routes.lua` now has
Kol-side `swamp_cave`, bridge-side `swamp_cave_bridge`, and return-side
`kol_swamp_cave` variants. The forward variants target the existing
`overworld_swamp_cave` Travel landmark at `(104,44)` and complete when entering
map `0x15` (`Swamp Cave`); the return variant shares the `overworld_kol`
Travel destination and completes on Kol map `0x07`. External orientation came
from Gamer Corner's `(1S,61E)` Swamp Cave coordinate, the NESMaps labeled
overworld, Mike's RPG Center placing the cave far south of Kol near the bridge,
and Gamer Corner's Rimuldar walkthrough warning that the approach crosses
poison swamp. The route is intentionally staged through Kol from far starts
rather than treated as an all-map route.

Forward route details: from Kol `(104,10)`, it reuses `Kol forest west edge`
`(96,13)`, `West of Kol north lane` `(96,21)`, `Kol south road` `(96,32)`, and
`Kol south road east lane` `(96,35)`, then backs through the proven south-road
jog at `(93,35)`, `(93,36)`, `(92,36)`, and `Kol bridge east lane` `(92,37)`.
The first cave spur through `(100,35)`, `(104,39)`, and `(104,42)` was wrong:
live probes showed it routes into a blocked x104/x107 pocket before the
entrance row. A later live shakedown then reached the swamp edge but hung on
the x92 transition: auto-walk reached `(92,40)` and blocked trying `DOWN` into
`(92,41)`. Fresh probe proof: `(92,40)->DOWN` and `(93,40)->DOWN` blocked,
while `(94,40)->DOWN`, `(95,40)->DOWN`, `(96,40)->DOWN`, and `(97,40)->DOWN`
moved; `(92,40)->RIGHT` and `(93,40)->RIGHT` also moved. The corrected route
now descends to `Swamp Cave lower west approach` `(94,40)`, drops to
`(94,41)`, crosses the rechecked row-41 lane through `(97,41)`, then uses
`(97,42)`, `(102,42)`, `(102,43)`, and `Swamp Cave doorstep` `(104,43)` before
stepping down into the cave trigger at `(104,44)`. From the southwest bridge
`(90,37)`, the bridge variant starts at `Kol bridge east lane` and joins the
same x94 lower approach. Live proof after the x94 patch: the user reached the
cave and `dw_debug.log` recorded `EVENT: map change -> 0x15 (Swamp Cave)` plus
`OVERWORLD_ROUTE: event=arrived route=swamp_cave_bridge waypoint=Swamp Cave`.

Return route details: `kol_swamp_cave` starts near Swamp Cave `(104,44)` and
backs out through `(104,43)`, `(102,43)`, `(102,42)`, `(97,42)`, `(97,41)`,
`(94,41)`, and `(94,40)`. From `(94,40)` it targets `Kol bridge east lane`
`(92,37)` with horizontal-first routing so it crosses west on row 40 and then
climbs the verified bridge lane instead of trying an untested x94 north climb.
It then returns through `(92,36)`, `(93,36)`, `(93,35)`, `(96,35)`, `(96,32)`,
`(96,21)`, `(96,13)`, and Kol `(104,10)`. Static proof after wiring the return:
`lua test_overworld_routes.lua` (64 tests) and `luac -p overworld_routes.lua
test_overworld_routes.lua`. The user then tested the route live in both
directions. Both sides are usable; a few rough edges remain for future route
polishing, but there is no major blocker before the next Swamp Cave interior
exploration pass.

Current Swamp Cave interior patch in the worktree: external orientation agrees
that Swamp Cave / Quagmire Cave is the one-floor tunnel from north Alefgard to
the south/Rimuldar island, with a second objective behind one locked door:
Princess Gwaelin is held here by a Green Dragon. Gamer Corner lists the north
entrance at `(1S,61E)`, the south exit at `(6S,61E)`, one floor B1, one locked
door, random monsters Scorpion/Magician/Ghost/Druin, and the Green Dragon boss.
Realm of Darkness notes that the cave has no treasure chests and is the only
way to reach the southern world section that includes Rimuldar. Local live
state confirms map `0x15` (`Swamp Cave`) is 6x30. The user tested the `x=0`
corridor both northbound and southbound: it is open from `(0,0)` through
`(0,25)`, and south access ends there. Current evidence shows `(0,25)` is only
the west-corridor bend: using STAIRS there produced "There are no stairs here",
and repeated manual `DOWN` attempts from `(0,25)` started twitch movement but
did not complete a tile step. A later live check showed `(5,29)` is only the
bottom-right alcove: STAIRS also says no stairs there, south/east are out of
bounds, and north is open. The south-island stairs coordinate is `(0,29)`,
identified from the ROM up-stair table entry `15 00 1D` at file offset
`0xF486`; it should be reached from row 29, not by walking south from `(0,25)`.
`map_reader.lua` now exposes `MAP_PASSTHROUGH_CELLS[0x15]` for `x=0,y=0..25`
plus the separate lower west-edge `(0,28)` return-route turn and `(0,29)` exit
cell; `(0,26)..(0,27)` stay closed. The user then manually worked the route
from the island exit area back toward the original entrance. Log evidence
promoted directional-only lower-route blockers for `(1,25)->UP` into `(1,24)`,
repeated `(1,28)->UP` into `(1,27)`, approaches into `(2,28)` from `(2,29)`,
`(3,28)`, and `(1,28)`, and `(3,27)->LEFT` into `(2,27)`. A follow-up
auto-walk loop toward `Stairs Up to South Island` was manually stopped at frame
`09480` after repeatedly alternating between `(1,26)->DOWN` into `(1,27)` and
`(2,26)->DOWN` into `(2,27)`. The loop reached blocked counts 28 and 26,
respectively, with both queued-route and seam-retry failures; `map_reader.lua`
now adds `(1,27).north` and `(2,27).north` to those directional blockers.
`objects.lua` removes the duplicate `Stairs Up` entry at `(0,0)` and exposes
two Swamp Cave interior Travel objects: `North Exit to World Map` at `(0,0)`
and `Stairs Up to South Island` at `(0,29)`. Static proof:
`luac -p map_reader.lua objects.lua test_map_reader.lua test_objects.lua`,
`lua test_map_reader.lua` (30 tests, including A* path from `(0,0)` to
`(0,25)`, no path to `(0,26)`, and route continuation to `(0,29)` through row
29 in an open fixture, plus south-to-north return path rejection of the newly
modeled lower-cave blocked approaches), and `lua test_objects.lua` (61 tests).
Live validation
after using the south-exit stairs path from the row-29 exit area confirmed the
expected south-island overworld landing: `EVENT: map change -> 0x01 (World Map)`
and the next world movement started from `(104,49)`; a fresh `report_position`
later reported `map=0x01(World Map) x=104 y=49`. This matches the existing
north entrance at `(104,44)` plus the guide offset from `(1S,61E)` to
`(6S,61E)`. World-map Travel now exposes `Swamp Cave South Entrance` at
`(104,49)` separately from plain `Swamp Cave` at `(104,44)`. Follow-up live
route looping now has working auto-walk routes between `North Exit to World Map`
and `Stairs Up to South Island` in both directions. The remaining scary-looking
route log entries on the lower path were timing/noisy seam cases: examples
include `(2,26)->RIGHT` into `(3,26)` and `(3,28)->DOWN` into `(3,29)`, where a
queued step timed out after movement had started and the seam-bruteforce retry
then moved successfully. A battle interruption also contaminated one pass. Do
not promote those latest noisy cells into permanent map data without fresh raw
probe evidence. Cleanup after the route pass cleared map `0x15` runtime blocks
and seam memory; `report_runtime_blocks:0x15` reported none and
`report_seam_cells:0x15` reported `total=0`. Locked-door follow-up: Realm of
Darkness' Swamp Cave map places Gwaelin and the Green Dragon behind a
lower-right branch door, but the first local coordinate hypothesis is now
disproven. The user stood at the reachable lower-right branch tile `(5,23)` and
OPEN reported "There is no door here." Follow-up probes also disproved the west
approach from `(4,22)` and the lower branch seam from `(3,23)`. The real door
coordinate is `(5,20)`: live no-key OPEN from `(5,21)` and from `(5,19)` both
reported "Thou hast not a key to use." The Dragon Warrior disassembly confirms
OPEN checks only the four adjacent cells, so the shared adjacent tile from those
two successful probes is `(5,20)`. `map_reader.lua` now treats `(5,20)` as the
Swamp Cave magic-key door cell, and `objects.lua` exposes `Gwaelin Door` at
`(5,20)` with interaction stand `(5,21)` facing north. Static tests cover
closed/open door RAM behavior and routing to the `(5,21)` stand from both cave
exits. Follow-up auto-walk from the south stairs toward `Gwaelin Door` exposed
two more false lower-branch exits: `(3,23)->UP` into `(3,22)` blocked 37 times
and direct `probe_edge:UP` confirmed `status=blocked`; `(3,23)->RIGHT` into
`(4,23)` blocked 36 times and direct `probe_edge:RIGHT` confirmed
`status=blocked`. `map_reader.lua` now models these as directional blockers
`["3,22"]={south=true}` and `["4,23"]={west=true}`. After the source reload,
`inspect_move:3,23,UP` and `inspect_move:3,23,RIGHT` both report
`directional_blocked=true`, runtime blocks are clear, and live `debug_pathfind`
routes work in all four useful directions: door stand `(5,21)` to south stairs
`(0,29)` is 13 steps, door stand to north exit `(0,0)` is 26 steps, south
stairs to door stand is 13 steps, and north exit to door stand is 26 steps.
A final live auto-walk attempt from south stairs was interrupted by a random
Magician at `(3,26)` before reaching the old loop; Bill won for 4 XP and 11 G.
Follow-up looping from that post-battle tile confirmed one more permanent seam:
`probe_edge_verify:3,24,RIGHT,3` was 3/3 blocked into `(4,24)`, so
`map_reader.lua` also models `["4,24"]={west=true}`. The nearby
`(2,23)->UP` into `(2,22)` looked blocked in auto-walk, but direct/verify
evidence was mixed (1 moved, 2 blocked), so it is intentionally left unmodeled.
After reloading and clearing runtime blocks, `inspect_move:3,24,RIGHT` reports
`directional_blocked=true`, while `inspect_move:2,23,UP` remains open. Live
`debug_pathfind_to:5,21` from `(3,26)` now traces cleanly through
`(3,26)->(4,26)->(5,26)->(5,25)->(5,24)->(5,23)->(5,22)->(5,21)`.
Latest lower-branch auto-walk loop at `(5,23)` exposed two more confirmed
edges: `(5,23)->UP` into `(5,22)` and `(5,23)->LEFT` into `(4,23)` both
verified 3 blocked / 0 moved with `probe_edge_verify`, so disk now models
`["5,22"]={south=true}` and adds `east=true` to `["4,23"]`. Static validation
passes and still finds door routes. Live caveat: the touch-plus-probe reload
did not pick up this newest disk patch in the running Lua instance, so the
current play session has matching runtime edges injected with
`add_blocked_edge:0x15,5,23,UP` and `add_blocked_edge:0x15,5,23,LEFT`.
With those runtime edges active, `debug_pathfind_to:5,21` from `(5,23)` finds
a 6-step detour:
`(5,23)->(5,24)->(4,24)->(4,23)->(4,22)->(4,21)->(5,21)`.
Next auto-walk loop moved one step farther down the same lower-branch detour.
Direct verification confirmed `(4,25)->UP` into `(4,24)` as 3 blocked / 0
moved, so disk now adds `south=true` to `["4,24"]`. The sibling edge
`(5,24)->LEFT` into `(4,24)` had strong loop evidence but mixed verifier
results (1 moved, 2 blocked), so it is not permanent map data; the current
live session has it injected runtime-only as `(4,24).east` to keep the route
from immediately retrying that loop. With runtime `(4,24).east,south`, live
`debug_pathfind_to:5,21` from `(5,24)` finds an 11-step detour:
`(5,24)->(5,25)->(4,25)->(3,25)->(3,24)->(3,23)->(2,23)->(2,22)->(2,21)->(3,21)->(4,21)->(5,21)`.
Validation of that detour got 2/11 steps OK, then a random Druin started a
battle at `(4,25)` and the validator aborted for battle state rather than map
geometry. Bill won. Current live state after the fight: field, map `0x15`,
position `(4,25)`, runtime block `(4,24)` with `east,south`.
Latest lower-left detour run confirmed a wider west-edge re-entry wall. The
loop repeatedly hit `(2,23)->UP` into `(2,22)` and `(1,23)->UP` into `(1,22)`;
fresh `probe_edge_verify` calls confirmed both 3 blocked / 0 moved, so disk
now models `["2,22"]={south=true}` and `["1,22"]={south=true}`. Follow-up
validation then exposed west-edge re-entry blocks from `(0,21)->RIGHT`,
`(0,20)->RIGHT`, `(0,22)->RIGHT`, and `(0,19)->RIGHT`; each verified 3/3
blocked and disk now models `["1,21"]={west=true}`, `["1,20"]={west=true}`,
adds `west=true` to `["1,22"]`, and adds `["1,19"]={west=true}`. With those
runtime-injected, the live planner from `(0,19)` detoured through
`(0,18)->(1,18)->(1,19)->(1,20)->(2,20)->(3,20)->(3,21)->(4,21)->(5,21)`.
Validation of that row-18 re-entry got one clean step, then a Magician started
a fight while `(0,18)->RIGHT` was just beginning. The user later manually
validated `(0,18)->RIGHT` as engine-blocked and checked the x=0 corridor
eastward: re-entry stays blocked through `(0,9)->RIGHT`, with `(0,8)` the
first eastward opening. Disk now models `(1,9).west` through `(1,18).west`;
`(1,8).west` intentionally stays open. Runtime guards for those rows are active
in the live session too. After injection, live `debug_pathfind_to:5,21` from
the current `(3,8)` position traces:
`(3,8)->(3,9)->(3,10)->(4,10)->(4,11)->(4,12)->(4,13)->(4,14)->(4,15)->(4,16)->(4,17)->(4,18)->(4,19)->(4,20)->(4,21)->(5,21)`.
Green Dragon location is now log-confirmed without further live poking: the
first clean Green Dragon battle started at frame `04027` on map `0x15`, field
position `(4,14)`, immediately after auto-walk reached `(4,14)` and attempted
`DOWN` toward `(4,15)` while routing to `Gwaelin Door`; frame `04095` then
reported `A Green Dragon draws near!`. Later manual checks/battle restarts
again showed Green Dragon snapshots at `(4,14)` (`enemy_hp` around 52/55), so
the dragon is a fixed rescue-branch encounter before the modeled door route, not
behind the door. Hero level 9 is not ready; avoid using the door route as a
player-safe objective until keys/dragon readiness are handled.
Remember `(4,24).east` is still runtime-only mixed evidence.
The rescue branch itself still needs magic-key testing and a future safe plan
for handling or warning about the Green Dragon.

Current Rimuldar route state: external guide prep is recorded and the first
live shakedown corrected the guide-derived overworld route. Local guide images
and text notes are now archived in `project_resources/maps/rimuldar/README.md`
with Mike's RPG Center and Realm of Darkness map PNGs under
`project_resources/maps/rimuldar/external/`. Gamer Corner lists
Rimuldar at `(29S,59E)`, matching the existing
`overworld_rimuldar` object at local world coordinate `(102,72)`, with inn
55 G, 2 locked doors, Wings treasure, a Weapons/Armor shop, and the first
no-key Magic Key shop. Gamer Corner's Magic Key page lists Magic Keys at 53 G
in Rimuldar and notes the other key shops require keys first; Mike's RPG Center
agrees that Rimuldar's Magic Key shop sells keys for 53 G and lists the
weapon/armor stock as Copper Sword, Hand Axe, Broad Sword, Half Plate, Full
Plate, and Magic Armor. Gamer Corner's walkthrough recommends reaching
Rimuldar from the Swamp Cave south side by taking the west route around the
craggy mountains because it is safer, and warns that the Rimuldar area is
dangerous at level 8-9; SLEEP is useful.

`overworld_routes.lua` now adds `rimuldar` targeting `overworld_rimuldar` and
`swamp_cave_south` targeting `overworld_swamp_cave_south_entrance`. The first
westbound segment from `(104,49)` toward `(93,49)` looked blocked at first, but
later moved and is classified as noisy rather than a permanent route blocker.
Two route-shape bugs were corrected from the successful manual run: the old
`(92,56)` notch made autowalk retry blocked `(93,57)->UP`, so the forward route
now drops to `(93,57)` and heads west through `(90,57)`; the old final push
from `(90,72)` straight east to Rimuldar ran into the north-side town wall at
`(97,72)->RIGHT`, so the route now takes the manual north/east bypass and
enters from the proven east doorstep `(103,72)->LEFT`. The return
`swamp_cave_south` route was updated to use the same east approach before
rejoining the west lake. Follow-up auto-walk from Rimuldar toward the cave
exposed a non-reversible mountain notch: live `probe_edge:UP` from `(92,57)`
blocked into `(92,56)`, and nearby row-57/56 northbound probes showed the old
reverse chute was the wrong return hinge. A live west-pocket investigation
found the viable return detour through `(85,58)`, `(85,56)`, `(83,56)`,
`(83,54)`, `(86,54)`, `(86,52)`, `(92,52)`, `(92,48)`, `(100,48)`,
`(100,50)`, and `(104,50)`; probing `UP` from `(104,50)` triggered the Swamp
Cave south entrance and landed inside at `(0,29)`. `swamp_cave_south` now uses
that west-pocket return detour, and `swamp_cave_south_recovery` catches route
starts/recalculations from the bad `(92,57)` notch by steering west first.
Latest forward-route user check from Swamp Cave South Entrance to Rimuldar
completed successfully. Log review found two polish-level route-shape issues:
the west-lake bend from `(89,72)` should step right before going north, and the
north-wall corner from `(97,71)` should step up before going east because
`(97,71)->RIGHT` into `(98,71)` blocked twice. `overworld_routes.lua` now
sets those two waypoint axis orders accordingly; other scary cells from the
pass, such as `(102,49).east`, `(88,65).north`, and `(94,72).west`, later moved
and are still treated as timing/noisy seam observations rather than map data.
Static proof:
`luac -p overworld_routes.lua test_overworld_routes.lua` and
`lua test_overworld_routes.lua` (76 tests). Live caveat: the bypass is derived
from the successful manual route through hostile overworld terrain, so further
auto-walk polishing may still find isolated timing noise or encounter
interruptions.

Rimuldar service proof from the current live session: the user left the
weapon/armor merchant dialogue open. Fresh read-only probes reported
`POSITION: map=0x0B(Rimuldar) x=23 y=9`; `report_npcs` showed `Merchant 2` as
slot 13 at `(23,7)`; and `report_merchant_state` reported active offers
`Copper Sword, Hand Axe, Broad Sword, Half Plate, Full Plate, Magic Armor`.
Visible merchant rows gave prices: Copper Sword 180 G, Hand Axe 560 G, Broad
Sword 1500 G, Half Plate 1000 G, Full Plate 3000 G, and Magic Armor 7700 G.
`objects.lua` first labeled Rimuldar `Merchant 2` as `Weapons Merchant` and
used the south counter stand `(23,9)` facing north. Follow-up selected
teleport/TALK proof found the planner-safe public counter stand at `(24,7)`
facing west: teleport dropped the player on `(24,7)`, `TELEPORT_FACE` set west,
and TALK opened the weapon/armor prompt. The stale `(23,9)` target explained
why the exit-to-merchant route could fail even after the merchant-to-exit route
worked. `objects.lua` now routes the service interaction through `(24,7)`
facing west. Static proof after the route-target and inn correction:
`luac -p objects.lua test_objects.lua map_reader.lua test_map_reader.lua`,
`lua test_objects.lua` (63 tests), `lua test_map_reader.lua` (32 tests), and
`git diff --check`.
Rimuldar inn confirmation came next without exposing more map geometry issues:
`Merchant 3` is the inn keeper at `(16,18)`. The live route from the east
entrance `(29,13)` to `Merchant 3` queued 17 clean steps to `(16,17)`, faced
south, and TALK opened `Welcome to the traveler's Inn. Room and board is 55
GOLD per night...`. `objects.lua` now labels Rimuldar `Merchant 3` as `Inn`
and routes him through `(16,17)` facing south. No directional blockers were
added for this inn pass because the user confirmed the route worked smoothly
both ways.
Rimuldar Magic Key seller proof followed after a clean relaunch so required
modules were definitely refreshed. `report_npcs` showed `Merchant 1` at
`(2,4)` and `Old Man 1` at `(4,7)`. Hidden-cell probes around `Merchant 1`
could reach some adjacent cells, but TALK only produced the short `Welcome!`
greeting; `Merchant 1` is therefore dialogue-only and stays out of Services.
The real key seller is `Old Man 1`: from `(4,6)` facing south, TALK opened
`Magic keys! They will unlock any door. Dost thou wish to purchase one for 53
GOLD?`. The purchase was cancelled, leaving key count unchanged. `objects.lua`
now labels Old Man 1 as `Magic Key Merchant`, routes him through `(4,6)` facing
south, and keeps `Merchant 1` browsable but non-service. Route investigation
from the east entrance found the required north/water-edge bridge at `(24,6)`:
`probe_edge:UP` from `(24,7)` moved into `(24,6)` even though the ROM tile
decoded as blocked. Fresh live proof after relaunch: Services contains
`Weapons Merchant`, `Inn`, and `Magic Key Merchant`; `Magic Key Merchant`
reports stand `(4,6)`; and the first `debug_pathfind_to:4,6 trace_path` from
the east entrance succeeded via `(24,7)->(24,6)` and then west to the key-shop
stand. `pathfind` on the selected service still produced little/no speech in
that session, but the debug path and Services object data are valid.
Follow-up autowalk toward the key merchant looped in the east/north pocket and
exposed the real entrance-side key-route connector. Confirmed permanent
directional blockers are `(24,12).south`, `(23,12).south`, `(25,11).east`,
`(20,10).south`, `(20,10).west`, `(21,11).west`, `(21,12).south`,
`(21,12).west`, and `(24,8).south`; each had `probe_edge_verify` 3/3 blocked
evidence. Do not promote `(25,12).south`, `(25,12).east`, or `(23,10).south`:
the first two were mixed/passable later, and `(23,10)` was affected by Guard 2
clutter before moving cleanly after NPCs were released. The planner was then
cut off only by `(24,9)->UP` into `(24,8)`, which is a real blocked edge; the
missing bridge is instead `(19,9)`. Live proof: `(19,10)->UP` into `(19,9)`
moved 3/3 despite tile `0x0F`, `(19,9)->UP` moved into `(19,8)`,
`(19,8)->DOWN` moved back into `(19,9)`, and `(18,9)->RIGHT` into `(19,9)`
moved 3/3. `map_reader.lua` now models `(19,9)` and `(24,6)` as Rimuldar
passthroughs and adds the confirmed directional blockers above. Static proof:
`luac -p map_reader.lua test_map_reader.lua`, `lua test_map_reader.lua`
(32 tests), and `git diff --check`. FCEUX needs a manual script restart to pick
up the new `(19,9)` passthrough before live `debug_pathfind_to:4,6` can succeed
again from the east entrance. The live session was left with autowalk stopped,
NPCs unfrozen, and Bill at Rimuldar's east entrance `(29,13)`.
Follow-up route cleanup from the same live town walkabout: the user bumped
around Rimuldar and warned that some apparent blockers could be NPC occupancy.
Fresh `report_npcs` at frame `166440` showed all NPCs stationary and no NPC at
`(28,13)` or `(28,14)`. `report_seam_cells:0x0B` showed 55 observed seams:
53 passable-only, one noisy seam, and exactly one blocked-only seam. The noisy
`(27,15).west` had one block and one moved observation and is intentionally
left open. The blocked-only seam was `(28,13).south`: the exit-route replan
from `(28,14)` tried `UP` into `(28,13)`, then the seam brute-force retry
blocked again, while the reroute through `(29,14)->(29,13)` moved cleanly and
the user later exited east from `(29,13)`. That first cleanup modeled
`["28,13"] = {south = true}` for Rimuldar, with a regression test preserving
the open `(29,13)` exit route and leaving `(27,15).west` unmodeled. Because the
current FCEUX-flavored session may not source-reload cleanly, the matching
runtime edge was also injected for the live session:
`add_blocked_edge:0x0B,28,14,UP`, and
`report_runtime_blocks:0x0B` confirmed the runtime block at map `0x0B`,
cell `(28,13)`, direction `south`.
Reload caveat resolved for the latest checks: the earlier touch-plus-probe path
did not reload required modules, but a clean `./launch_dw.sh` relaunch did pick
up the patched service labels, the Rimuldar `(24,6)` passthrough, and the
latest object data.

Rimuldar exit correction from the same follow-up: the old `Exit to World Map`
object at `(15,14)` is invalid. The user selected/teleported to it, walked
around, and auto-walk completed there without leaving town; `(15,14)` and nearby
tiles behaved as ordinary interior floor. Static inspection showed east-edge
tiles `(29,13)` and `(29,14)` are walkable, and the earlier town-entry log had
already hinted at an east-edge arrival. Fresh live proof: after teleporting to
`(29,13)`, `probe_edge:RIGHT` produced `EVENT: map change -> 0x01 (World Map)`,
and `report_position` landed at `(102,72)`. `objects.lua` now models Rimuldar's
exit at `(29,13)` with interaction stand `(29,13)` facing east. Static proof:
`luac -p objects.lua test_objects.lua` and `lua test_objects.lua` (63 tests).
Follow-up user check confirmed the new town-side `Exit to World Map` lines up
correctly from inside Rimuldar.

Current Rain Shrine / Northern Cave interior patch in the worktree: map `0x0D`
is the Staff of Rain shrine described by Realm of Darkness as the Northern
Shrine. The live old man / wise man NPC is at `(4,4)`, and the path-grid route
dump from the entry route showed the live bottom entry/exit at `(4,9)`.
`objects.lua` now moves Rain Shrine's `Exit to World Map` object from the stale
`(4,4)` coordinate to `(4,9)` with a south-facing interaction point. The first
old-man autowalk looped between `(4,7)` and `(5,7)` while trying to move north
into `(4,6)` and `(5,6)`. `inspect_tile` / `inspect_move` said both target
cells are model-walkable tile `14`, but live movement proved the south
approaches blocked-only: `(4,6).south` reached 20 blocked / 0 moved and
`(5,6).south` reached 18 blocked / 0 moved. The next pass from the rerouted
path found the same row-6 wall farther west: `(3,6).south` reached 6 blocked /
0 moved and `(2,6).south` reached 4 blocked / 0 moved, while horizontal/lower
connectors at `(3,7)` and `(2,7)` moved. `map_reader.lua` now models only
`(2,6).south`, `(3,6).south`, `(4,6).south`, and `(5,6).south` as directional
blocks from that pass. The latest old-man route then looped between `(1,3)`
and `(1,4)` while repeatedly trying east into column `x=2`: `(2,3).west`
reached 36 blocked / 0 moved and `(2,4).west` reached 37 blocked / 0 moved,
while `(2,5).west` and `(2,6).west` had route-context blocked-only hits.
Movement along column `x=1` stayed open, including repeated
`(1,3)<->(1,4)` movement, so `map_reader.lua` now models `(2,3).west`,
`(2,4).west`, `(2,5).west`, and `(2,6).west` as directional-only blocks too.
The source edit triggered the active Lua reload, clearing temporary runtime
edges; fresh `report_runtime_blocks` on map `0x0D` reports none. With the
permanent map patch live, `debug_pathfind_adjacent:4,4` from current `(4,1)`
planned `2 south`, landing at `(4,3)` and facing south. The user's next live
test proved that direct top approach was still wrong: auto-walk from `(4,1)`
blocked entering `(4,2)` from the north four times, then rerouted via `(3,1)`
and blocked entering `(3,2)` from the north three times. Manual routing then
worked by going east along row 1, descending on the far east side, and coming
back west along row 4 to talk to the old man. The successful route logged
open seams `(5,1).west`, `(6,1).west`, `(7,1).west`, `(8,2).north`,
`(8,4).north`, `(7,4).east`, `(6,4).east`, and `(5,4).east`. `map_reader.lua`
now models `(3,2).north`, `(4,2).north`, `(5,2).north`, and `(6,2).north` as
directional-only top-wall blocks; keep `(7,2).north` as a watch item because
there was no clean failed-edge log for that cell yet. The first route back out
toward `Exit to World Map` started from the old-man side and queued six steps.
It first proved `(5,5).north` blocked from `(5,4)->DOWN` (route count 2/0,
then raw `probe_edge_verify:5,4,down,5` confirmed 5 blocked / 0 moved). The
reroute moved `(5,4)->RIGHT` into `(6,4)` and `(6,4)->DOWN` into `(6,5)`,
then looped between attempts to enter `(5,5)` from the east and `(6,6)` from
the north. Those reached 40+ blocked-only observations before stop, then raw
verifiers confirmed `(5,5).east` and `(6,6).north` blocked 5/5 each.
`map_reader.lua` now models `(5,5).north/east` and `(6,6).north` as
directional-only blocks. After those edges were runtime-injected, the route
shifted east and proved the next wall face too: `(7,5).west` from
`(6,5)->RIGHT` and `(7,5).north` from `(7,4)->DOWN` both verified blocked 5/5.
`map_reader.lua` now models those as directional-only blocks as well. Keep
`(6,4).west/south`, `(6,5).north`, and `(7,4).west/east` open because they
moved during the exit attempt. The next entrance-to-old-man route from `(4,9)`
was clean through `(4,8)`, `(4,7)`, `(5,7)`, and `(6,7)`, then found another
pair: `(6,6).south` from `(6,7)->UP` and `(7,6).south` from `(7,7)->UP`.
Both had repeated route evidence over 20 blocked / 0 moved and raw
`probe_edge_verify` confirmed each 5 blocked / 0 moved. `map_reader.lua` now
models `(6,6).south` and `(7,6).south` as directional-only blocks. Keep
`(6,7).east/west` and `(7,7).west` open because they moved repeatedly during
the loop. Final noisy-cleanup pass after both old-man directions were working
promoted two more verifier-grade edges: `(7,6).east` from `(8,6)->LEFT` and
`(5,3).east` from `(6,3)->LEFT`, both 5 blocked / 0 moved. The tempting
`(5,3).south` route hit was checked with `probe_edge_verify:5,4,up,5` and
came back mixed/passable, 3 moved / 2 blocked, so it must stay open. A later
live exit route from `(6,3)` completed to `(4,9)` but exposed three more
verifier-grade walls: `(7,5).east` from `(8,5)->LEFT`, `(7,9).north` from
`(7,8)->DOWN`, and `(6,9).north` from `(6,8)->DOWN` all confirmed 5 blocked /
0 moved. `(8,9).north` is deliberately not modeled: its raw verifier was
inconclusive with one moved attempt followed by a map-change abort, not a
stable blocked edge.
User playtest after this cleanup reported both old-man routes finished
smoothly. The return route had one reroute, but it recovered and is deferred to
polishing rather than treated as an active blocker. The remaining chest access
is progression-gated until the old man receives what he is waiting for.

Current Kol-to-Tantegel return patch in the worktree: selecting `Tantegel
Castle` from near Kol no longer snaps to the old Garinham/cave-road safety
route and asks for a huge west push. `overworld_routes.lua` now has a
`tantegel_kol` route variant sharing the same `overworld_tantegel_castle`
Travel target, and object/alias route starts choose the closest matching route
variant from the current world-map position. From world-map Kol `(104,10)`, the
castle route now leaves through `Kol forest west edge` `(96,13)`, retraces the
live south-road and northeast-bridge chain, reconnects at `Erdrick's Cave road`
`(28,13)`, then follows the existing castle return through `North trail
marker`, `East choke approach`, `Upper bridge lane`, and `Bridge south bend`.
Static proof: `luac -p` on the changed route/object files and tests, `lua
test_overworld_routes.lua` (49 tests), `lua test_objects.lua` (58 tests), `lua
test_route_manager.lua` (58 tests), and `git diff --check`. Fresh user
grinding playtest: the reverse path from Kol back toward Tantegel solved the
major navigation problems. It still needed minor manual adjustment, but worked
well enough to treat remaining issues as polishing work.

Latest dialogue/accessibility polish is live-validated in FCEUX but not yet
committed. The STATUS command now interrupts with the full memory-backed status
readout and suppresses the visual equipment rows from being re-read as generic
dialogue; the user confirmed the status box reads well after reload. A
post-combat stale-dialogue blocker was also fixed: when the lower dialogue
window clears, the idle field reader now clears `PREV.announced_dialogue`, and
object hotkeys no longer treat that historical announcement cache as active
dialogue. Live proof after a Ghost fight with a level-up logged `dialogue cache
cleared: lower window empty`; afterward the command menu opened/closed and
object navigation speech queued/flushed normally instead of saying "Wait for
dialogue to finish." Current wrap-up position probe: `POSITION:
map=0x01(World Map) x=21 y=10`.

Current audio-tuning patch in the worktree: fast combat action dialogue still
uses the quick complete-sentence detector, but it now queues speech instead of
calling `tolk.output_interrupt()`. This should stop closely spaced combat
messages from cutting off the previous announcement mid-sentence. Battle
start/opening lines still interrupt so a new encounter is announced promptly.
Next live check: reload the Lua script and judge one or two normal fights,
especially multi-action Magician/Ghost rounds where player attack, enemy
action, and HP loss arrive close together.

Current overworld route patch in the worktree: the safety-route leg around
Garinham east field and Erdrick's Cave road now uses explicit small waypoints
instead of one coarse diagonal segment. Log evidence from the user's grinding
run showed the old active `tantegel` route aiming at `Erdrick's Cave road`
from `(21,11)` and auto-walk trying `DOWN` into `(21,12)`, which blocked;
nearby manual movement then succeeded by going east first, then south through
`(23,11)`, `(23,12)`, `(23,13)`, and onward. Earlier in the same log,
southward movement from `(19,7)` near `Garinham east field` also timed out
while the route became usable after moving east toward `(20,7)`. The route
table now adds `Garinham field east lane`, `Garinham field road bend`,
`Cave road north edge`, `Cave road west lane`, and `Cave road south lane`;
tests prove safety-route auto-walk starts east rather than south from both
`(19,7)` and `(21,11)`. Live command verification was not run because
`dw_debug.log` was stale and `--require-live` refused to queue commands; after
Lua reload, retest `route_recalculate` / `auto_walk` near `(21,11)` or the
current cave-road area.

Latest focused-destination fix in the worktree: route guidance was changing the
selected Travel object to the active route waypoint. The immediate cause was
`focus_route_waypoint()` in both `hotkeys.lua` and `object_commands.lua`; it
refreshed the object list, switched to Travel, and selected IDs such as
`route_garinham_04` whenever guidance started or status was requested. After
that, route-advance refreshes could keep shifting focus to the next route
waypoint. The helper has been removed/replaced with deferred route-object
refresh only, so the selected destination should stay on the original landmark
while active route waypoint markers remain available in Travel. Static proof:
`lua test_hotkeys.lua` (27 tests), `lua test_objects.lua` (55 tests),
`lua test_overworld_routes.lua` (34 tests), `lua test_route_manager.lua` (58
tests), `luac -p hotkeys.lua object_commands.lua objects.lua
overworld_routes.lua test_hotkeys.lua test_objects.lua`, and `git diff
--check`.

Current Kol route patch in the worktree: `overworld_routes.lua` now has a
guided `kol` route, with aliases `kol`, `kol town`, `kol village`, `fairy
flute`, `faerie flute`, and `faeries flute`, targeting the existing
`overworld_kol` Travel landmark and completing on map `0x07`. External
orientation came from Gamer Corner, GameFAQs, StrategyWiki, and the NESMaps
overworld. Live shakedown disproved the initial direct east-pocket route:
`probe_edge:57,38,RIGHT` blocked into `(58,38)`, and raw probes also blocked
north/south from `(57,38)`; nearby row-39/40 and north-branch checks around
`(56,39)`, `(54,40)`, `(53,41)`, `(54,35)`, and `(53,34)` found dead ends.
The route now follows the Galenholm/Garinham-style road: western bridge road,
cave road, east across the northeast bridge, southeast to the bridge southwest
of Kol, then north/east into the forest. Waypoints include `Bridge south bend`,
`Upper bridge lane`, `Erdrick's Cave road`, `Northeast bridge west bend`,
`Northeast bridge lower west lane`, `Northeast bridge south lane`,
`Northeast bridge`, `North Alefgard bridge road`, `Kol southwest bridge`,
`Kol south road`, `West of Kol north lane`, `Kol forest west edge`, and `Kol`.
The north bridge was tightened from pre-reload log evidence saved at
`handoff_archive/dw_debug_2026-05-15_kol_waypoint_blocker_pre_reload.log`:
row 18 around `(59,18)/(60,18)` produced route blocks/noisy pullbacks, while
raw probes after reload moved through `(59,19)->(60,19)`,
`(61,19)->(61,18)`, and forced-origin `(60,19)->(60,18)`. A follow-up live
auto-walk from `(60,17)` still tried `down` into `(60,18)` and blocked, so the
final worktree patch makes the crossing horizontal-first from the north side
and prevents `(61,18)` from pulling the route back west. Static proof after the
north-bridge fix: `luac -p overworld_routes.lua test_overworld_routes.lua`,
`lua test_overworld_routes.lua` (41 tests), `lua test_objects.lua` (55 tests),
`lua test_route_manager.lua` (58 tests), and `git diff --check`. Final source
reload landed at `dw_debug.log` start `2026-05-15 11:56:50`; live movement then
matched the patch shape: `down` from `(60,17)` still early-twitch-canceled,
but `right` to `(61,17)` moved and then `down` to `(61,18)` moved cleanly,
advancing the Kol route toward `North Alefgard bridge road`. A Red Slime battle
interrupted before a clean queued `auto_walk` segment could be run, but the
subsequent run reached Kol successfully.
Latest same-run south-road follow-up: the user worked around trouble after the
`Kol southwest bridge` marker and reached `West of Kol north lane`. The log
showed the old `Kol south road` waypoint at `(90,30)` pulling guidance west
from the live road: from `(90,37)`, north/down attempts were unreliable while
`right` to `(91,37)` worked; the successful workaround used the east-side lane
through `(92,37)`, `(92,36)`, `(93,36)`, `(93,35)`, `(96,35)`, `(96,32)`,
then north toward `(96,21)`. `overworld_routes.lua` now replaces the coarse
`(90,30)` south-road leg with explicit `Kol bridge east lane`, `Kol lower
south lane`, `Kol south road bend`, `Kol south road lower bend`,
`Kol south road east lane`, and a corrected `Kol south road` at `(96,32)`.
Static proof after this lane patch: `luac -p overworld_routes.lua
test_overworld_routes.lua`, `lua test_overworld_routes.lua` (42 tests),
`lua test_objects.lua` (55 tests), `lua test_route_manager.lua` (58 tests), and
`git diff --check`. The user then reloaded and reached Kol; the old log just
before reload showed `EVENT: map change -> 0x07 (Kol)` and
`OVERWORLD_ROUTE: event=arrived route=kol waypoint=Kol index=25`, and the fresh
post-reload probe confirms `POSITION: map=0x07(Kol) x=19 y=23`. Treat the
Tantegel-to-Kol route as playtested enough to move on to Kol services unless a
return route exposes a new issue. Fresh user grinding playtest later reported
that Tantegel to Kol works rather well, with a few manual side-steps needed to
get back on course; smooth those points later as route polish.
Kol service decoding has started. Local reference images were downloaded to
`project_resources/maps/kol/external/`: `mikesrpgcenter_kol.png` and
`realmofdarkness_kol.png` (plus a duplicate `vgmaps_kol.png` mirror). The
screen-reader transcription in `project_resources/maps/kol/README.md` now
lists the service guide facts: Inn 20 G in the northeast building,
weapon/armor shop with Copper Sword, Hand Axe, Half Plate, Full Plate, and
Small Shield, item/tool shop with Herb, Torch, Dragon's Scale, and Wings, and
the Fairy Flute hidden four steps south of the bath. Next step: use the user's
Kol survey to confirm live entry/exit coordinates, shopkeeper NPC slots,
public stand/facing tiles, the Fairy Flute search tile, and any locked-door
coordinates before patching `objects.lua`. Watch the mismatch between the old
hardcoded Kol exit `(15,14)` and the fresh post-arrival live position
`map=0x07(Kol) x=19 y=23`.
Latest Kol service-survey patch: the user confirmed `(19,23)` is both the
world-map arrival tile and the town-side tile where moving south exits Kol.
The first parked survey also proved why the old start looked isolated:
`teleport_to:19,23` refused because the decoder read tile type `0x00`, while
manual movement then crossed `(19,22)->(19,23)`, exited from `(19,23)->DOWN`,
re-entered Kol back to `(19,23)`, and had moved evidence into `(20,23)` from
the west. A later object pathability-filter repro from live `(18,23)` showed
all NPCs as unreachable because `(18,23)` also ROM-decodes as type `0x00` and
was missing from the passthrough set; live position proves it is part of the
same entrance strip. `objects.lua` now exposes Kol's exit as `(19,23)` facing
south, and `map_reader.lua` treats `(18,23)`, `(19,23)`, and `(20,23)` as
map-0x07 passthrough cells.
Latest Kol west-NPC route patch: after the services were decoded, the reachable
NPC filter exposed `Old Man 1` at object `(2,13)`. Autowalk toward him from
the west approach looped between `(8,11)` and `(8,12)`, repeatedly trying left
into `(7,11)` and `(7,12)`. The log is archived at
`handoff_archive/dw_debug_2026-05-15_kol_west_npc_loop_pre_patch.log`;
evidence reached `(7,11).east blocked=23 moved=0` and
`(7,12).east blocked=24 moved=0`, with seam retries and no runtime blockers.
The vertical connector stayed open: `(8,11)->DOWN` and `(8,12)->UP` moved
repeatedly. `map_reader.lua` now models only `(7,11).east` and `(7,12).east`
as directional blockers.
The same survey targeted `Person 1` from start `(20,21)` and looped at
`(20,18)`: seam memory ended with `(20,17)` from the south blocked 51/51 and
`(21,18)` from the west blocked 50/50, while nearby entry-lane seams stayed
passable/noisy. Those two edges are now narrow directional blockers:
`(20,17).south` and `(21,18).west`; no full cells were blocked. The useful
pre-reload log is archived at
`handoff_archive/dw_debug_2026-05-15_kol_service_survey_pre_reload.log`.
Static proof: `luac -p map_reader.lua objects.lua test_map_reader.lua
test_objects.lua`, `lua test_map_reader.lua` (28 tests), `lua
test_objects.lua` (56 tests), `lua test_route_manager.lua` (58 tests), `lua
test_map_survey.lua` (45 tests), `lua test_overworld_routes.lua` (42 tests),
and `git diff --check`. Live source reload was not confirmed: `touch main.lua`
plus `launcher_probe:codex_kol_service_patch` was consumed, but `dw_debug.log`
kept the old `Started: 2026-05-15 12:10:00` header, so the active FCEUX script
likely still needs a manual Lua reload before rerunning the Kol survey.
`report_npcs` after the stopped survey listed Kol service NPC slots as
Merchant 1 `(8,19)`, Merchant 2 `(19,4)`, Merchant 3 `(22,12)`, and Merchant 4
`(14,21)`, all `service=true`; do not relabel them until TALK/shop-menu proof
confirms which one is inn, weapon/armor, and item/tool.
Latest Kol Merchant 1 follow-up: the user had autowalk bouncing while trying
to reach Merchant 1. Three evidence logs are archived:
`handoff_archive/dw_debug_2026-05-15_kol_merchant1_bounce_pre_reload.log` and
`handoff_archive/dw_debug_2026-05-15_kol_merchant1_inner_bounce_pre_reload.log`,
plus `handoff_archive/dw_debug_2026-05-15_kol_post_stop_autowalk_blockers.log`.
The first run showed the route from the entry area toward Merchant 1 `(8,19)`
bouncing between `(11,18)` and `(11,19)`: left into `(10,18)` from the east
reached `blocked=38 moved=0`, and left into `(10,19)` from the east reached
`blocked=36 moved=0`. A later clean reload proved the old `(12,19).west`
observation was not just manual noise: the queued route reproduced it six
times with no moves, and also proved `(11,20).north` seven times. The second
run advanced from `(21,21)` toward the target near `(6,17)`, found
directional-only route blockers at `(16,21).east`, `(16,20).east`,
`(16,19).east`, `(10,16).east`, `(10,16).north`, and `(9,16).north`, then
looped hard at `(8,15)`: `(7,15).east` reached `blocked=46 moved=0` and
`(8,16).north` reached `blocked=47 moved=0`. A small right tap broke the loop
and moved the hero to `POSITION: map=0x07(Kol) x=9 y=15`; treat that as a
manual escape, not as service-route target proof. `map_reader.lua` now models
all of those as map-0x07 directional blockers only. Static proof for this
follow-up: `luac -p main.lua map_reader.lua test_map_reader.lua`, `lua
test_map_reader.lua` (28 tests), `lua test_map_survey.lua` (45 tests), `lua
test_route_manager.lua` (58 tests), `lua test_objects.lua` (56 tests), and
`git diff --check`. Live source reload is still pending: `touch main.lua` plus
`launcher_probe:codex_kol_m1_inner_patch` was consumed and reported the hero at
`map=0x07(Kol) x=9 y=15`, but the log header stayed at `Started:
2026-05-15 13:12:25`, so the active FCEUX script likely has not loaded the new
blockers or command yet. Reload Lua manually before the next Merchant 1 retest.
There is also now a `stop_auto_walk` debug command for future object-route
loops; it cancels the active auto-step route and releases route/NPC-freeze state
without injecting movement. The next manual-reload retest confirmed that command
worked: it logged `CMD: stop_auto_walk`, `NPC freeze released: manual
stop_auto_walk`, and `AUTO_WALK: manually stopped`, leaving the hero at
`POSITION: map=0x07(Kol) x=12 y=18`. That run targeted Merchant 1 with adjacent
goal `(11,21)`. The route looped between `(12,18)` and `(13,18)` because
`(12,19).north` reached `blocked=18 moved=0` and `(13,19).north` reached
`blocked=22 moved=0`; both are now map-0x07 directional blockers. Lower-count
but clean queued-step plus seam-retry evidence from the same run also added
`(15,19).north`, `(14,19).north`, and `(16,19).north`.
Noisy seams `(15,16).west` and `(17,21).east` had moved evidence and are not
modeled. Reload for this batch is confirmed: `touch main.lua` plus
`launcher_probe:codex_kol_post_stop_patch` produced a fresh log header
`Started: 2026-05-15 13:29:38` and reported `POSITION: map=0x07(Kol) x=12
y=18`, so the new blockers are live. A read-only follow-up preview from
`(12,18)` to adjacent target `(11,21)` now returns `No path found`, and
`debug_pathfind_adjacent_skip_npcs:11,21` also returns no path, so the current
Merchant 1 target appears geometrically isolated/counter-side rather than
blocked by live NPC traffic. The user then selected/teleported to `npc_7` /
`Merchant 1`; TALK proved he is a dialogue-only southern-island/Rimuldar hint
NPC, not a shop. `objects.lua` now excludes Kol `Merchant 1` from Services
while keeping him browsable under NPCs. A sequential `report_door_state` from
`POSITION: map=0x07(Kol) x=12 y=21` reported `keys=0` and all opened-door RAM
slots as `(0,0)`, so his exact locked-door relationship is not confirmed yet.
The next service proof identified `npc_12` / `Merchant 2` as the Inn: selected
teleport landed at `(19,2)`, faced south toward the keeper at `(19,4)`, and
TALK opened the 20 GOLD inn prompt. `objects.lua` now labels Merchant 2 as
`Inn` and pins `(19,2)` facing south as the interaction stand. The user's
autowalk from the Inn stand back to the town entrance looped on row 2 until
`stop_auto_walk`; `dw_debug.log` is archived at
`handoff_archive/dw_debug_2026-05-15_kol_inn_exit_loop_pre_patch.log`. The
route repeatedly moved between `(21,2)` and `(22,2)` while trying to enter
`(21,3)` and `(22,3)` from the north. Final seam counts were
`(21,3).north blocked=36 moved=0` and `(22,3).north blocked=34 moved=0`; both
are now map-0x07 directional blockers. Current live position after stop/probe:
`POSITION: map=0x07(Kol) x=22 y=2`; `report_runtime_blocks` says none. Treat
the next step as reload plus retest Inn-to-exit, then continue
service/interaction-tile identification for the remaining Kol merchants. The
post-reload retest found the next pair immediately: the route got past the
row-3 pair, alternated between `(22,1)` and `(22,2)`, and tried to enter
`(23,1)` and `(23,2)` from the west. The log is archived at
`handoff_archive/dw_debug_2026-05-15_kol_inn_exit_loop_pair2_pre_patch.log`.
Final seam counts were `(23,1).west blocked=17 moved=0` and
`(23,2).west blocked=18 moved=0`; both are now map-0x07 directional blockers.
Current live position after stop/probe: `POSITION: map=0x07(Kol) x=22 y=1`;
`report_runtime_blocks` still says none. The next retest drifted one tile west
during turn settle, logged `AUTO_WALK_DRIFT_REROUTE map=0x07 target=Exit to
World Map current=(10,2)`, then recovered into a stable loop from `(10,3)`.
That log is archived at
`handoff_archive/dw_debug_2026-05-15_kol_inn_exit_loop_pair3_pre_patch.log`.
Do not model `(10,3).north`: it first looked blocked but immediately moved on
the brute-force retry and was reclassified noisy. The real pair was
`(10,4).north blocked=19 moved=0` and `(11,3).west blocked=18 moved=0`; both
are now map-0x07 directional blockers. Current live position after stop/probe:
`POSITION: map=0x07(Kol) x=10 y=3`; `report_runtime_blocks` still says none.
The latest reload/test completed the Inn-to-exit route, then the return route
from the town entrance got close to the Inn before looping at the northeast
approach. The full pre-patch log is archived at
`handoff_archive/dw_debug_2026-05-15_kol_inn_return_loop_pre_patch.log`.
Final strong blockers were `(21,3).south blocked=20 moved=0` and
`(22,3).south blocked=20 moved=0`, so `map_reader.lua` now models those south
approaches in addition to the previous north approaches. The side seams
`(21,4).east blocked=1 moved=10` and `(22,4).west blocked=2 moved=10` are noisy
but repeatedly moved, so they stay open. Low-count recovered blockers from the
same run, including `(11,3).north`, `(19,17).south`, `(18,17).south`,
`(18,5).south`, `(19,5).south`, and `(20,5).south`, were left diagnostic only.
Post-investigation read-only probe reported
`POSITION: map=0x07(Kol) x=21 y=4` and `RUNTIME_BLOCKS map=0x07 none`; the
same probe accidentally queued the wait flags as literal commands afterward, so
ignore the harmless `Unknown command: '--wait'/'POSITION'/'--timeout'/'8'`
noise after frame 22440 in the live log.
The follow-up entrance-to-Inn retest after reload started at `(21,4)`, queued
8 steps for Inn, and looped across row 4. The full pre-patch log is archived at
`handoff_archive/dw_debug_2026-05-15_kol_entrance_to_inn_loop_pre_patch.log`.
Strong blockers were `(23,3).south blocked=36 moved=0` and
`(20,4).east blocked=36 moved=0`; both are now map-0x07 directional blockers.
Keep the row-4 connector open: `(21,4).east moved=18`, `(22,4).east moved=18`,
`(22,4).west blocked=3 moved=19` noisy, and `(23,4).west moved=19`. The stop
probe reported `POSITION: map=0x07(Kol) x=23 y=4` and
`RUNTIME_BLOCKS map=0x07 none`. Next live step: reload Lua and retest
entrance-to-Inn again. The next reload/test started from `(23,4)`, queued
24 steps for Inn, worked through some low-count row-5 obstacles, then looped
around `(11,5)`, `(12,5)`, and `(12,4)`. The full pre-patch log is archived at
`handoff_archive/dw_debug_2026-05-15_kol_entrance_to_inn_loop2_pre_patch.log`.
Strong blockers were `(11,4).south blocked=18 moved=0` and
`(11,4).east blocked=19 moved=0`; both are now map-0x07 directional blockers.
The surrounding seams moved and stay open: `(11,5).east moved=9`,
`(12,4).south moved=9`, `(12,5).north moved=9`, and
`(12,5).west moved=9`. Earlier low-count row-5 hits in the same run, including
`(18,5).south`, `(19,5).south`, `(20,5).east`, and `(20,5).south`, remained at
two blocks each and were bypassed, so they stay diagnostic only. Stop probe:
`POSITION: map=0x07(Kol) x=12 y=4`, `RUNTIME_BLOCKS map=0x07 none`. Next live
step: reload Lua and retest entrance-to-Inn again. The latest reload produced a
working noisy round trip: Inn was reached at `AUTO_WALK_FACE target=Inn`, then
Exit to World Map completed, then entrance-to-Inn completed again with
`AUTO_WALK_FACE target=Inn`. That success log is archived at
`handoff_archive/dw_debug_2026-05-15_kol_inn_roundtrip_noisy_success.log`.
Manual cleanup promoted the highest suspects: `(10,4).south blocked=4 moved=0`
and `(9,2).south blocked=4 moved=0` from the success log, plus repeated
two-block reroute seams `(11,3).north`, `(19,17).south`, and `(18,17).south`
that appeared in both the success log and earlier return evidence. Read-only
`inspect_move` at frame 15480 confirmed the pre-patch model still allowed those
approaches. Noisy/moved seams stayed open, including `(10,3).west blocked=2
moved=2`, `(18,18).east blocked=1 moved=1`, and the row-5 two-count seams.
Kol Merchant 3 is now live-confirmed as the weapon/armor shop. The user opened
the buy list, and `dw_debug.log` is archived at
`handoff_archive/dw_debug_2026-05-15_kol_merchant3_weapons_menu.log`. The log
shows selected teleport to `npc_13` / `Merchant 3`, target `(22,12)`, landing
`(20,12)`, face east, then `VISITED_AUTO`. The spoken menu entries were:
Copper Sword 180 G, Hand Axe 560 G, Half Plate 1000 G, Full Plate 3000 G, and
Small Shield 90 G. `objects.lua` now labels Kol `Merchant 3` as
`Weapons Merchant` and routes him through the public stand `(20,12)` facing
east. `merchant.lua` already recognized this item list; `test_merchant.lua`
now pins the exact Kol offer set. Before reloading, the user tried an autowalk
from the Weapons Merchant stand to the town exit and stopped the resulting
loop; the raw log is archived at
`handoff_archive/dw_debug_2026-05-15_kol_weapon_to_entrance_loop_pre_patch.log`.
The route queued 12 steps for Exit to World Map, moved from `(20,12)` to
`(19,12)`, then eventually into `(19,13)` after one noisy retry. From there it
looped between south into `(19,14)` and west into `(18,13)`. Final evidence:
`(19,14).north blocked=22 moved=0` and `(18,13).east blocked=21 moved=0`, while
`(19,13).north` had moved evidence and stays open. `map_reader.lua` now models
only those two new map-0x07 directional blockers. After reload, the outbound
Weapons Merchant-to-exit route made it back to the entrance, then the inbound
route from entrance back to Weapons Merchant looped between `(20,19)` and
`(20,20)` while trying right into `(21,19)` and `(21,20)`. That log is archived
at `handoff_archive/dw_debug_2026-05-15_kol_entrance_to_weapon_loop_pre_patch.log`.
Final inbound evidence reached `(21,19).west blocked=28 moved=0` and
`(21,20).west blocked=26 moved=0`; both are now map-0x07 directional blockers.
The vertical seam between `(20,19)` and `(20,20)` moved repeatedly, so no full
cell was blocked. Low-count outbound reroute hits in the same log,
`(21,12).west`, `(18,13).north`, and `(18,14).west`, were initially left
diagnostic-only; later clean-route evidence repeated them and they are now
promoted as directional-only blockers. The next reload got closer again:
entrance-to-Weapons-Merchant routed
around the old west-approach pair, then looped between `(20,15)` and `(21,15)`
trying north into `(20,14)` and `(21,14)`. The log is archived at
`handoff_archive/dw_debug_2026-05-15_kol_entrance_to_weapon_loop2_pre_patch.log`.
Final stopped evidence reached `(20,14).south blocked=24 moved=0` and
`(21,14).south blocked=24 moved=0`; both are now map-0x07 directional blockers.
The horizontal seam between `(20,15)` and `(21,15)` moved repeatedly. The early
two-count `(21,20).south` block is left diagnostic-only because the route
recovered around it through `(22,21)->(22,20)`. The next entrance-to-Weapons-
Merchant retry got closer again and looped between `(18,15)` and `(19,15)`
while trying to move north into `(18,14)/(19,14)`; the raw log is archived at
`handoff_archive/dw_debug_2026-05-15_kol_entrance_to_weapon_loop3_pre_patch.log`.
Final stopped evidence reached `(18,14).south blocked=24 moved=0` and
`(19,14).south blocked=25 moved=0`, so both are now map-0x07 directional
blockers. The horizontal row-15 seam moved repeatedly, with `(18,15).east`
ending noisy but moved and `(19,15).west` passable-only, so those stay open.
The next retest successfully reached Weapons Merchant from the prior position,
returned to the entrance, then looped on the entrance-to-Weapons-Merchant route
between `(22,15)` and `(23,15)`. The raw stopped log is archived at
`handoff_archive/dw_debug_2026-05-15_kol_entrance_to_weapon_loop4_pre_patch.log`.
Final evidence reached `(22,14).south blocked=27 moved=0` and
`(23,14).south blocked=26 moved=0`, so both are now map-0x07 directional
blockers. The row-15 horizontal seams stayed open: `(22,15).east` and
`(23,15).west` both ended noisy with 13 moved observations. Earlier low-count
blocks in the same log, such as `(21,12).west`, `(18,13).north`, and
`(18,14).west`, were left diagnostic-only at that point because those routes
recovered and completed. A fresh return-to-exit success log is now archived at
`handoff_archive/dw_debug_2026-05-15_kol_weapon_to_entrance_noisy_success_pre_patch.log`.
It completed Weapons Merchant -> exit, then entrance -> Weapons Merchant, but
the return leg repeated `(21,12).west blocked=2 moved=0`,
`(18,13).north blocked=2 moved=0`, and `(18,14).west blocked=2 moved=0`.
It also added `(18,17).west blocked=2 moved=0`, matching the existing row-17
wall-band evidence. These four are now map-0x07 directional blockers. The
route's successful recovery path kept `(17,12)`, `(17,13)`, `(17,14)`, the
vertical strip down x=17, and the lower exit lane passable. After reload, that
geometry made the return-to-exit planner choose a row-16 approach and expose
another row-17 wall band. The stopped log is archived at
`handoff_archive/dw_debug_2026-05-15_kol_weapon_to_entrance_loop5_pre_patch.log`.
Evidence: `(18,17).north blocked=2 moved=0` on the early alternate route, then
a stable loop between `(19,16)` and `(20,16)` trying down into
`(19,17)/(20,17)`, with final counts `(19,17).north blocked=22 moved=0` and
`(20,17).north blocked=22 moved=0`. These three north approaches are now
map-0x07 directional blockers. The row-16 horizontal seam stayed open:
`(19,16).east` and `(20,16).west` both ended passable-only with 11 moved
observations. Next live step: reload Lua and smoke-test Weapons Merchant ->
exit again. The user then reported both Weapons Merchant routes clean and
live-confirmed Kol `Merchant 4` / `npc_15` as the item/tool shop. The proof log
is archived at `handoff_archive/dw_debug_2026-05-15_kol_merchant4_tool_menu.log`:
selected teleport targeted `(14,21)`, landed at the public counter stand
`(12,21)`, faced east, TALK opened Buy, and the merchant reader saw Herb 24 G,
Torch 8 G, Dragon's Scale 20 G, and Wings 70 G. `objects.lua` now labels
Merchant 4 as `Tool Merchant` and routes him through `(12,21)` facing east;
`test_merchant.lua` pins the exact Kol tool-shop offer list.

Merchant 4 route testing then disproved the older Kol `(16,22).east`
directional blocker. The proof log is archived at
`handoff_archive/dw_debug_2026-05-15_kol_merchant4_1622_false_blocker.log`:
the script moved `(16,22)->RIGHT` into `(17,22)` repeatedly, then refused
`(17,22)->LEFT` before touching the engine because the static map table still
marked `(16,22).east` blocked. The user confirmed west-to-east and
east-to-west are both passable, so map `0x07` now keeps both sides of the
`(16,22)<->(17,22)` seam open. Reload Lua before the next Tool Merchant route
retest so the planner can use that corridor.

Polish item to revisit: FCEUX still sometimes reports `keys=LeftAlt` while
`joy1=-` and the external bridge is empty. This appears to be FCEUX/Windows
retaining a stale Alt key state after focus/menu interactions, not Dragon
Warrior dialogue state. Movement or a real key clears it temporarily, but idle
can re-trigger the warning. Good follow-up: make the FCEUX bridge treat
LeftAlt-only/idle/empty-bridge as a stale modifier after a grace period instead
of repeatedly warning unless controls are truly blocked.

Latest manual validation closes the Brecconary pass for now. The user tested
all essential services, and routes both to and from the town entrance pass in
normal play. The remaining unreachable NPCs were manually chatted up; a couple
give clues, but none are required for game progression. Treat Brecconary
`map=0x08` as service-complete and do not resume broad blocker hunting there
unless normal play exposes a required route failure. Tantegel Castle `map=0x04`
is also service-complete enough to leave for now: the Sage is pinned down and
reachable with NPC-traffic caveats, Merchants 1 and 2 are dialogue-only, and
Merchant 3 sells Magic Keys but cannot be accessed yet. Next playtest focus is
moving on toward the next town rather than continuing broad Tantegel cleanup.

Garinham public-service pass is now complete enough to pause until Magic Keys.
Confirmed public targets are: town exit/entrance, `Merchant 2` as Tool Merchant,
`Merchant 3` as Inn, `Merchant 4` as Weapons Merchant, and the public east-end
locked door at `(19,16)`. The town-side `Exit to World Map` object was
corrected after the user noticed the old `(15,14)` target was just a
north-south corridor: it now uses the live west entry boundary `(0,14)` with
interaction stand `(1,14)` facing west. Tool and Weapons Merchant routes now
have viable entrance/return paths with modeled Garinham blockers; one-off drift
reroutes remain polishing unless they start causing route failures. Leave the
internal grey-building door, hidden/back-building grave path, locked chests,
and any remaining hidden/dialogue-only NPCs for the key revisit. Current live
state after cleanup is `POSITION: map=0x09(Garinham) x=1 y=14`, menu closed,
input neutral.

Selected-object teleport follow-up: player-facing NPC teleport now holds the
target NPC briefly and uses a sturdier facing tap. The latest Garinham repro
showed selected teleport landing beside `Woman 2`, but by the time TALK was
used the NPC had wandered, causing `There is no one there.` The hotkey path now
pins the selected NPC's live target tile with `teleport_npc_hold_frames=600`,
faces the target for `teleport_face_target_frames=4`, and sets
`teleport_post_scan_grace_frames=45` to skip the expensive text/menu scan loop
during the immediate post-teleport suppression/facing window. A new
`teleport_selected[:MODE]` debug command exercises the same landing/facing path
as the player hotkey. Live validation after reload selected Garinham `Woman 2`,
ran `teleport_selected`, logged `target_held=true`, `TELEPORT_FACE ... frames=4`,
and `TELEPORT_SELECTED_TIMING ... ms=3.000`; subsequent TALK opened `Welcome to
Garinham. May thy stay be a peaceful one.` instead of the miss dialogue. Follow
up lag tuning made the selected-teleport NPC hold diff-only, releases it as
soon as TALK dialogue opens or misses, and profiles
`route_manager.apply_npc_freeze`; a live Old Man 2 teleport logged
`TELEPORT_SCAN_GRACE frames=45`, `frames=600`, and
`route_manager.apply_npc_freeze avg_ms=0.016 max_ms=2`. Idle text/menu scanner
cadence is now throttled while no input/menu/dialogue needs fast scanning; the
post-reload idle sample showed `check_command_menu calls=113`,
`check_yesno_prompt calls=75`, `check_merchant_screen calls=56`,
`check_dialogue calls=90`, and `check_upper_dialogue calls=50` over 900 frames.
Final cleanup restored the hero to `POSITION: map=0x09(Garinham) x=15 y=14`,
menu closed, input neutral.

Overworld landmark teleport is live-validated. The user reached Tantegel Castle,
saved, and then hit the first failure: selected-object exact teleport to
`overworld_garinham` refused with `reason=no open adjacent cell`, because world
map Travel tiles do not have reliable interior-map-reader walkability data. The
fix treats overworld Travel objects (`overworld_*` landmarks and `route_*`
waypoints) as exact same-map teleport landings and lets those trusted Travel
targets bypass the map-reader walkability gate while still using the normal
teleport refusal checks. `perform_teleport_to()` also updates the dedicated
overworld shadow bytes whenever `snapshot.is_overworld` is true, not only for
obsolete synthetic map `0x00`. New debug commands `teleport_landmark:NAME` and
alias `teleport_overworld:NAME` resolve named overworld Travel landmarks by
exact name, object id, or unique prefix, refuse off the world map, and reuse the
same trusted Travel landing path. Live proof after reload:
`LAUNCHER_PROBE: codex_landmark_reload`, `POSITION: map=0x01(World Map) x=43
y=43`, `teleport_landmark:Garinham` logged `TELEPORT_LANDMARK ...
landing=(1,2)`, split `report_position` confirmed `POSITION: map=0x01(World
Map) x=1 y=2`, and selected-object `teleport_selected` on `Garinham` logged
`landing_reason=overworld_travel` / `ok=true`.

First-phase overworld auto-walk is implemented in the worktree and FCEUX live
validated. On the world map, `auto_walk` now
uses the active overworld route rather than refusing outright: it asks
`overworld_routes.plan_next_segment()` for the next waypoint segment, queues
those directional steps through `auto_step`, and suppresses the interior
pathfinder/reroute path. The segment stops when the waypoint route completes,
when a queued movement step blocks (`reason=overworld_blocked`), or when
`can_walk_false` cancels movement for battle/menu/dialogue. This is deliberately
not full world-map A*: blockers stop the segment and leave evidence in the log
instead of trying to reroute around unknown terrain. Static proof so far:
`luac -p overworld_routes.lua route_manager.lua test_overworld_routes.lua
test_route_manager.lua`, `lua test_overworld_routes.lua` (31 tests), and
`lua test_route_manager.lua` (58 tests).

FCEUX live proof after the follow-up reload: `launcher_probe` matched
`codex_fceux_autowalk_patch`, current position was `map=0x01(World Map)
x=28 y=13`, and `start_overworld_route:cave` replaced the active route with
`route=erdrick waypoint=Erdrick's Cave index=11`. Running `auto_walk` logged
`OVERWORLD_AUTO_WALK: event=start route=erdrick ... steps=1 from=(28,13)
to=(28,12)`, then `auto_step begin_step ... source=queued_route`, proving the
command path now drives `auto_step` in FCEUX. The step stopped cleanly on an
engine block: `SEAM_OBSERVATION map=0x01 cell=(28,12) approach=south
result=blocked ... source=queued_route_block` followed by
`OVERWORLD_AUTO_WALK: event=blocked route=erdrick waypoint=Erdrick's Cave`.
This validates the first-phase stop-on-blocker behavior and leaves a route-data
investigation target around the Erdrick's Cave south approach. Before this
patch, FCEUX's stuck-Alt external keyboard bridge emitted neutral raw frames
every tick; `main.lua` now lets neutral raw frames clear stale input without
suppressing `auto_step.update`, so queued routes are no longer starved while
the bridge is idle.

Garinham overworld route setup is now in the worktree. External orientation
cross-checks matched the plan: StrategyWiki describes Garinham as far north
and west / northwest of Tantegel and warns that bridge crossings increase
monster danger, while the GameFAQs coordinate table lists Galenholm/Garinham
as 41 north and 41-42 west of Tantegel. The western coordinate variant is the
correct landmark: `(2,2)` is the north-south approach corridor, and the
Garinham Travel landmark is now `(1,2)` from the Tantegel anchor `(43,43)`.
The route still completes on map `0x09`. `overworld_routes.lua` now adds a
Garinham / Galenholm route that reuses the already-tested Tantegel/Brecconary
to Erdrick's Cave lane, then guides through `Garinham east field` `(20,9)`,
`Garinham ridge entry` `(19,6)`, `Garinham east ridge` `(16,6)`,
`Garinham shoulder bend` `(16,5)`, `Garinham shoulder east step` `(15,4)`,
`Garinham mountain shoulder` `(14,4)`, `Garinham north coast lane` `(14,3)`,
`Garinham north coast west lane` `(8,3)`, `Garinham outskirts` `(5,4)`,
`Garinham approach` `(2,2)`, and `Garinham` `(1,2)`. The Brecconary and
Tantegel Castle safety routes now
include that northwest leg in reverse, so selecting either safety destination
from Garinham starts by leaving town toward Erdrick's Cave road. The first live
try exposed why the old single `(12,6)` woods marker was too coarse: from
`POSITION: map=0x01(World Map) x=14 y=4`, repeated west/down attempts
early-twitch-canceled against the obstacle while the route still pointed
southwest. The split route now has regression coverage proving recalculation
from `(14,4)` points to `Garinham north coast lane`, `1 north`. Static
validation passed: `luac -p overworld_routes.lua test_overworld_routes.lua`,
`lua test_overworld_routes.lua` (27 tests), current object integration check
`lua test_objects.lua` (49 tests), earlier `lua test_hotkeys.lua` (27 tests), and
`git diff --check`. Live reload proof after the split:
`LAUNCHER_PROBE: codex_garinham_shoulder_reload`, then
`POSITION: map=0x01(World Map) x=14 y=4`; `route_recalculate` logged
`OVERWORLD_ROUTE: event=recalculate route=garinham waypoint=Garinham north
coast lane index=18`, so the current immediate instruction should be 1 north.
Earlier live proof before the split: `LAUNCHER_PROBE:
codex_garinham_route_reload`, then `POSITION: map=0x01(World Map) x=43 y=43`;
`start_overworld_route:garinham` logged `OVERWORLD_ROUTE: event=start
route=garinham waypoint=Brecconary road index=2`.
Latest static proof after the coordinate correction: `lua test_overworld_routes.lua`
includes `garinham_corridor_points_west_to_town`, proving world `(2,2)` now
points `1 west` to the corrected town landmark instead of completing early.

Garinham map-cracking context is now staged. The user reached the town, and
entry-side live position confirmed `POSITION: map=0x09(Garinham) x=0 y=14`. A
local map reference was downloaded to
`project_resources/maps/garinham/realmofdarkness_garinham.png`, with a
screen-reader transcription and source notes in
`project_resources/maps/garinham/README.md`. Cross-checks used Realm of
Darkness, Mike's RPG Center, Gamer Corner, StrategyWiki, and VGMaps. External
orientation says public early priorities are the exit, inn, item shop, and
weapon/armor shop. Guide-backed service data: Inn costs 25 G; item shop sells
Herb 24 G, Torch 8 G, and Dragon's Scale 20 G; weapon/armor shop sells Club
60 G, Copper Sword 180 G, Hand Axe / Iron Axe 560 G, Leather Armor 70 G,
Chain Mail 300 G, Half Plate 1000 G, and Large Shield / Iron Shield 800 G.
The large grey/north building is Magic-Key/later content. Locked-building
chests are 10-17 G, Torch, and Herb. Realm says the Grave of Garinham entrance
is inside the grey building at the northwest corner of the back wall.
StrategyWiki says the internal locked door only reaches two nonessential
guards, and the important progression is the hidden "wall of darkness" path
behind the building toward Garin's Grave. Gamer Corner lists 3 locked doors
overall: east end of town, inside locked building, and one in Garinham B1; do
not treat B1 as town-service scope. Treat guide data as orientation only; live
movement and map data still decide passability and interaction stands.

Garinham first-service live pass: the user manually reached `Merchant 2`, and
the live shop menu identified him as the item/tool merchant: Herb 24 G, Torch
8 G, and Dragon's Scale 20 G. `objects.lua` now labels Garinham `Merchant 2`
as `Tool Merchant` and keeps him in Services; `lua test_objects.lua` now covers
that map-specific service override. The follow-up autowalk from Merchant 2 back
to the town entrance/exits got caught at `POSITION: map=0x09(Garinham) x=3
y=11`, repeatedly trying `(3,11)->DOWN` into `(3,12)` and `(3,11)->RIGHT` into
`(4,11)`. After a source reload stopped the loop, fresh checks reported
`RUNTIME_BLOCKS map=0x09 none`, `PATH_STATE target=nil map=0x09
runtime_count=0`, and the player still at `(3,11)`. The user then manually
checked `(3,11)` and confirmed north/west are open while south/east are
engine-blocked. `map_reader.lua` now models `(3,12).north` and `(4,11).west`
as Garinham directional blockers, with regression coverage in
`test_map_reader.lua`. Live reload proof after
`LAUNCHER_PROBE: codex_garinham_311_edges`: `inspect_move:3,11,DOWN` and
`inspect_move:3,11,RIGHT` report `directional_blocked=true` /
`effective_passable=false`, while `inspect_move:3,11,UP` and
`inspect_move:3,11,LEFT` report `directional_blocked=false` /
`effective_passable=true`. Retrying the exit autowalk from the Tool Merchant
area then exposed a tight loop around the same building pocket: the route
cycled through `(3,10)`, `(3,11)`, `(2,11)`, and `(2,12)` while repeatedly
trying `(3,10)->RIGHT` into `(4,10)` and `(2,12)->RIGHT` into `(3,12)`; after
those were avoided, it also tried `(3,10)->UP` into `(3,9)`. The route was
stopped with a source reload; fresh state was `POSITION: map=0x09(Garinham)
x=2 y=12`, `PATH_STATE target=nil`, and `RUNTIME_BLOCKS map=0x09 none`.
Follow-up raw verifiers promoted the three exact edges: `probe_edge_verify:
2,12,RIGHT,5`, `probe_edge_verify:3,10,RIGHT,5`, and
`probe_edge_verify:3,10,UP,5` each returned `moved=0 blocked=5
classification=confirmed_blocked reason=raw_hold_timeout`. `map_reader.lua`
now models `(3,12).west`, `(4,10).west`, and `(3,9).south` in addition to the
previous `(3,12).north` and `(4,11).west`; live post-reload `inspect_move`
confirmed those three new edges report `directional_blocked=true` /
`effective_passable=false`. Post-patch `debug_pathfind_to:15,14` from `(3,10)`
now reports a new 20-step route: `1 west, 1 north, 8 east, 3 south, 1 east, 1
south, 2 east, 1 south, 2 east`. Retrying that route found the next pocket:
`(3,10)->LEFT` initially timed out but seam brute force crossed into `(2,10)`,
so do not promote that edge. From `(2,10)`, the route then repeatedly tried
`(2,10)->UP` into `(2,9)` and `(2,10)->LEFT` into `(1,10)`. A reload stopped
the loop; fresh state was `POSITION: map=0x09(Garinham) x=2 y=10`,
`PATH_STATE target=nil`, and `RUNTIME_BLOCKS map=0x09 none`.
`probe_edge_verify:2,10,UP,5` and `probe_edge_verify:2,10,LEFT,5` each
returned `moved=0 blocked=5 classification=confirmed_blocked
reason=raw_hold_timeout`. `map_reader.lua` now models `(2,9).south` and
`(1,10).east`; live post-reload `inspect_move` confirmed both as
`directional_blocked=true` / `effective_passable=false`. Post-patch
`debug_pathfind_to:15,14` from `(2,10)` now reports a 23-step route: `1 south,
1 west, 2 north, 9 east, 1 south, 5 east, 4 south`. The next live pass
matched the user's manual note that `(2,10)<->(3,10)` is noisy but genuinely
passable: post-reload `inspect_move:2,10,RIGHT` and `inspect_move:3,10,LEFT`
both reported `directional_blocked=false` / `effective_passable=true`, so keep
that seam open. The active route then bounced around `(2,11)` and `(2,12)` by
trying left exits into `(1,11)` and `(1,12)`. `probe_edge_verify:
2,11,LEFT,5` and `probe_edge_verify:2,12,LEFT,5` each returned `moved=0
blocked=5 classification=confirmed_blocked reason=raw_hold_timeout`;
`map_reader.lua` now models `(1,11).east` and `(1,12).east`, with live
`inspect_move` proof after reload. That made the static planner report no path
from `(2,12)`; `dump_search_log` showed the only remaining south exit was
rejected because `(2,13)` decoded as `not_walkable`. Raw verifier then proved
`(2,12)->DOWN` into `(2,13)` is actually passable 5/5 despite tile type 2, so
`MAP_PASSTHROUGH_CELLS[0x09]["2,13"]` now models the decoder gap. Live reload
proof after `LAUNCHER_PROBE: codex_garinham_213_passthrough`: `POSITION:
map=0x09(Garinham) x=2 y=13`, `debug_pathfind_to:15,14` reports `Path: 1
south, 13 east`, and `PATH_STATE target=nil map=0x09 runtime_count=0`. Next
Garinham step is to retry the Tool Merchant return autowalk only if the player
wants the actual movement validated; the current planner can route out of this
pocket.

Garinham entrance-to-Tool-Merchant follow-up: the user reported the return
route completed after one reroute, but the entrance-to-tool route then bounced
near the merchant. Before stopping the loop, the live log repeatedly showed
westward blocks from the x=7 lane into the x=6 line, especially
`(7,10)->LEFT` and `(7,11)->LEFT`, with an earlier `(7,12)->LEFT` hit too. A
source reload stopped the loop at `POSITION: map=0x09(Garinham) x=7 y=11`,
`PATH_STATE target=nil`, and `RUNTIME_BLOCKS map=0x09 none`. Clean verifiers
confirmed `probe_edge_verify:7,10,LEFT,5`, `probe_edge_verify:7,11,LEFT,5`,
and `probe_edge_verify:7,12,LEFT,5` all returned `moved=0 blocked=5
classification=confirmed_blocked reason=raw_hold_timeout`; `map_reader.lua`
now models `(6,10).east`, `(6,11).east`, and `(6,12).east`, with regression
coverage in `test_map_reader.lua`. Live reload proof after
`LAUNCHER_PROBE: codex_garinham_x6_wall_patch`: `inspect_move:7,10,LEFT`,
`:7,11,LEFT`, and `:7,12,LEFT` all report `directional_blocked=true` /
`effective_passable=false`. The planner now avoids those west pushes. From the
entrance/exit tile `(15,14)`, `debug_pathfind_adjacent:3,10` now chooses
`Approach: 1 north, 9 west, 3 north, 2 west. Face west`, ending at `(4,10)`
for Merchant 2. The newly used route strip was spot-checked with raw
verifiers: `(7,13)->LEFT`, `(6,13)->UP`, `(6,12)->UP`, `(6,11)->UP`,
`(6,10)->LEFT`, and `(5,10)->LEFT` all moved 5/5, so the replacement route's
critical seams are currently clean. The final debug position drifted to
`POSITION: map=0x09(Garinham) x=3 y=10` after the last verifier's lingering
left input; no route was active and runtime blockers were empty. Codex then
teleported the hero back to the Merchant 2 east-side stand at `(4,10)`, with
fresh `POSITION: map=0x09(Garinham) x=4 y=10`.

Garinham drift investigation: after the user confirmed both Tool Merchant
routes eventually completed, `dw_debug.log` showed the remaining reroutes were
execution drift, not map geometry. Every `AUTO_WALK_DRIFT_REROUTE` was a
one-tile overshoot in the previous route direction during a turn-settle window:
Exit route drifted `(10,10)->(11,10)` before a planned down turn,
`(12,11)->(12,12)` before a planned right turn, and `(13,13)->(13,14)` before
a planned right turn; Tool Merchant route drifted `(7,13)->(6,13)` before a
planned down turn. The reroutes then recovered, and the suspect seams were
timing-noisy but passable after brute force, e.g. `(12,10)->RIGHT`,
`(13,14)->RIGHT`, and `(6,13)->UP`. `auto_step.lua` now keeps early-twitch
holding on straight queued segments but releases instead when the next queued
step is a turn, and it suppresses the same-direction turn re-press in that
specific early-twitch-before-turn case. This is covered by
`queued_route_early_subpixel_twitch_releases_before_turn` in
`test_auto_step.lua`; `lua test_auto_step.lua` now runs 51 tests. Live reload
proof after `LAUNCHER_PROBE: codex_garinham_drift_timing_fix`: `POSITION:
map=0x09(Garinham) x=3 y=11`, `PATH_STATE target=nil`, and `RUNTIME_BLOCKS
map=0x09 none`. User retest after the timing changes confirmed the Tool
Merchant target is handled: manual movement feels better, and both Tool
Merchant routes are usable, though each still reroutes once from drift. Treat
those remaining drift reroutes as polishing work unless they start causing real
route failures; no new Garinham map blockers were promoted from drift evidence.

Manual-movement follow-up: the user reported that ordinary manual movement can
still alternate between no movement and overshoot. That matches the same
tap-to-step timing family rather than Garinham map data: the prior wall-bump
fix made released physical `manual_tap` input stop immediately after an early
movement-subpixel twitch, which protects wall/NPC bumps but can starve
legitimate open-floor taps before the step commits. `auto_step.lua` now keeps a
short configurable hold for released physical manual taps after an early
twitch, capped by `auto_step_manual_early_hold_frames=8` and the normal inject
limit. The older protections stay in place: no same-direction re-press after a
physical early twitch, no long blocked timeout for released manual bumps, and
debug/probe injection plus queued routes keep their separate conservative
behavior. Focused validation passed with `luac -p auto_step.lua
test_auto_step.lua config.lua` and `lua test_auto_step.lua` (51 tests). Live
reload proof after `LAUNCHER_PROBE: codex_manual_short_hold_reload`: `POSITION:
map=0x09(Garinham) x=3 y=11`, `PATH_STATE target=nil`, and `RUNTIME_BLOCKS
map=0x09 none`. User retest says manual movement is working better. Next
Garinham work should move to the next service/target; revisit drift during
polishing or if reroutes become disruptive.

Garinham Weapons Merchant confirmation: the user stood at `Merchant 4` and the
live log identified the service. Selected-object teleport targeted `npc_17`
`Merchant 4` at `(10,18)`, landed at `(10,16)`, and faced south; TALK opened
`We deal in weapons and armor...`, then the menu listed Club 60 G, Copper
Sword 180 G, Hand Axe 560 G, Leather Armor 70 G, Chain Mail 300 G, Half Plate
1000 G, and Large Shield 800 G. `objects.lua` now labels map `0x09`
`Merchant 4` as `Weapons Merchant` and routes the service interaction through
the live-confirmed counter stand `(10,16)` facing south. `lua test_objects.lua`
now covers both confirmed public Garinham merchants. Next public-service target
is likely the inn or another still-unconfirmed accessible NPC/service.

Weapons Merchant return-route cleanup: the successful route from `(10,16)` to
the exit still bounced into two visually-open but engine-blocked west
approaches. The route first tried `(10,16)->RIGHT` into `(11,16)`, then later
looped around `(13,14)->RIGHT` into `(14,14)`. Clean raw verifiers confirmed
both edges blocked 5/5 with `reason=raw_hold_timeout`, while nearby
`(13,14)->UP` and `(13,13)->RIGHT` were noisy but passable and should stay
open. `map_reader.lua` now models `(11,16).west` and `(14,14).west`, with
regression coverage in `test_map_reader.lua`. Live reload proof after
`LAUNCHER_PROBE: codex_garinham_weapon_exit_blocks`: `inspect_move:
10,16,RIGHT` and `inspect_move:13,14,RIGHT` both report
`directional_blocked=true` / `effective_passable=false`. From `(10,16)`,
`debug_pathfind_to:15,14` now reports `Path: 1 north, 4 east, 1 north, 1 east`;
`validate_path` walked it cleanly with `VALIDATE COMPLETE: 7/7 steps OK, 0
mismatches`.

Weapons Merchant inbound-route cleanup: the user then autowalked from the exit
back to the Weapons Merchant and collected another useful bounce cluster around
the same counter throat. Clean raw verifiers promoted `(11,15).east`,
`(11,16).east`, `(12,16).north`, `(14,14).east`, `(14,16).east`,
`(14,15).east`, and `(14,14).north`: each blocked 5/5 with
`reason=raw_hold_timeout`. Keep the mixed `(15,13)->LEFT` seam open; validation
blocked once there but then crossed it on retry. After the final reload,
`debug_pathfind_to:10,16` from the exit tile `(15,14)` reports `Path: 1 north,
3 west, 1 south, 2 west, 2 south`; `validate_path` walked it cleanly with
`VALIDATE COMPLETE: 9/9 steps OK, 0 mismatches`. `test_map_reader.lua` now
covers the Garinham public-shop route edges under
`garinham_public_shop_route_edges_match_live_checks`.

Weapons Merchant successful-route reroute follow-up: the next round trip had
viable entrance/merchant routes but still produced a few engine bumps. The log
showed no `AUTO_WALK_DRIFT_REROUTE` events; bumps were seam retries. Raw
verifiers confirmed `(10,15)->RIGHT` into `(11,15)` and `(13,15)->RIGHT` into
`(14,15)` both blocked 5/5 with `reason=raw_hold_timeout`, so
`map_reader.lua` now also models `(11,15).west` and `(14,15).west`. The
suspect `(15,17)->LEFT` into `(14,17)` moved 5/5, so keep `(14,17).east` open.
Codex unfroze NPCs and restored the hero to `POSITION: map=0x09(Garinham)
x=15 y=14`; runtime blocks were empty.

Garinham Inn confirmation: the user manually found the inn keeper at the public
counter. Fresh log evidence from `POSITION: map=0x09(Garinham) x=15 y=15`
opened dialogue `Welcome to the traveler's Inn. Room and board is 25 GOLD per
night. Dost thou want a room?`, and `VISITED_AUTO` marked `target_id=npc_15`
`target_name=Merchant 3`. `report_npcs` confirmed `npc_15` is `Merchant 3` at
`(17,15)` with `service=true`. `objects.lua` now labels Garinham `Merchant 3`
as `Inn` and routes him via public stand `(15,15)` facing east. `test_objects.lua`
covers the label, Services filter entry, interaction stand, and visited marking
from that stand. Current live player position remains `(15,15)` unless moved by
the user.

Garinham locked-door first pass: the town map did not expose a door object even
though guide data lists an east-end town door plus another door inside the
locked grey building. The public/east door is now modeled only at the confirmed
coordinate: the grid showed `(19,16)` as the east-end door-looking cell, and a
no-key movement probe from `(19,17)->UP` stayed at `(19,17)` while logging a
blocked seam into `(19,16)`. `map_reader.lua` now treats `(19,16)` as a
Garinham door cell that becomes passable from the opened-door RAM, and
`objects.lua` exposes it as `East Door` / `door_19_16`. The second
town-scope door inside the grey building is intentionally still pending until
keys/opened-door access lets us verify the exact cell; the Garinham B1 door is
dungeon scope, not this town-service pass. Validation passed with
`luac -p objects.lua map_reader.lua test_objects.lua test_map_reader.lua`,
`lua test_objects.lua` (50 tests), and `lua test_map_reader.lua` (26 tests).
Live reload proof after `LAUNCHER_PROBE: codex_garinham_east_door`:
`inspect_move:19,17,UP` reports `dest=(19,16)`, `reason=door_closed`, and
`effective_passable=false`. Codex then closed the stale command menu and
restored the hero to `POSITION: map=0x09(Garinham) x=15 y=15`; runtime blocks
were empty.

Tantegel Castle Sage follow-up: the user confirmed Old Man 2 restores MP.
`objects.lua` now labels the castle Old Man 2 at `(20,26)` as `Sage` and keeps
him in the Services filter. The Sage is not an ordinary adjacent-NPC target:
fresh live dialogue proof from `(18,26)` facing east opened the Sage dialogue
even though the object/NPC is two tiles east at `(20,26)`. `objects.lua` now
models `(18,26)` as the Sage's counter interaction stand facing east. Live
reload proof after `LAUNCHER_PROBE: codex_sage_counter_stand`: Services filter
reported `Sage: 2 east, counter here ... obj 20,26 interact 18,26`; from
`(12,29)` it reported `counter 3 north, 6 east`. The old adjacent-NPC route to
`(20,26)` was therefore misleading.

Sage routing is now good enough for play, with an NPC-traffic caveat. The old
reverse-route failures were partly caused by stale modeling at `(20,20)`: live
retest proved `(20,20)` is standable, exits north/south/west, and can be
entered from north/south/east; only `(20,20)->RIGHT` into `(21,20)` is
engine-blocked. `map_reader.lua` now removes `(20,20)` from the full blocked
cell list and models `(21,20).west` as a one-way directional block. Post-reload
proof after `LAUNCHER_PROBE: codex_2020_edge_patch`: `inspect_tile:20,20`
reports `effective_passable=true`; `inspect_move:20,20,UP/DOWN/LEFT` are
passable; `inspect_move:20,20,RIGHT` reports `directional_blocked=true`; and
`inspect_move:21,20,LEFT` is passable. From the Sage stand `(18,26)`,
`debug_pathfind_adjacent:11,29` now finds a 37-step route to the exit-adjacent
tile, while the skip-NPC route finds a 29-step route. The user then confirmed a
successful entrance-to-Sage route in normal play; getting it and the return
route to open can be fiddly because live NPCs get in the way. Treat the Sage as
pinned down for now. Do not reopen the confirmed south-gate seams to force
shorter paths.

Tantegel Castle merchant cleanup: the user confirmed Merchants 1 and 2 only
offer dialogue, so `objects.lua` keeps them in the NPC filter but removes them
from Services on map `0x04`. Merchant 3 sells Magic Keys, so he is now labeled
`Magic Key Merchant` and remains in Services. Follow-up research confirmed
Merchant 3 cannot be accessed yet, likely because the route is locked-door
gated. Do not treat no-path/no-route to him as a map blocker until Magic Keys
are available and the relevant doors can be opened.

Guide cross-check for the Sage does not support a locked-door explanation.
StrategyWiki describes the MP-restoring old man as to the right of the castle
entrance; Gamer Corner describes him southeast of the central courtyard. Realm
of Darkness and Gamer Corner list the Magic Key shop and Stones of Sunlight
route as the Tantegel content gated by Magic Keys, not the MP-restoring old
man. The user also flagged `(18,27)->DOWN` as blocked; fresh
`probe_edge_verify:18,27,DOWN,5` confirmed `moved=0 blocked=5` into `(18,28)`
with `classification=confirmed_blocked`, so `map_reader.lua` now keeps
`(18,28)` standable but closes its `north` approach in addition to the older
`south` approach. After reload, `inspect_move:18,27,DOWN` reports
`approach_blocked=true` and `effective_passable=false`. Later manual play
superseded the older no-path debug result by finding an NPC-sensitive route to
the Sage.

Follow-up verifier checks around the same pocket initially split the user's
next three manual observations. `(17,27)->DOWN` into `(17,28)` verified blocked
5/5 with `reason=raw_hold_timeout`, so `map_reader.lua` keeps `(17,28)`
standable but adds its `north` approach. `(17,27)->LEFT` into `(16,27)` also
verified blocked 5/5, but
`inspect_move:17,27,LEFT` already reports `reason=permanent_blocked` because
`(16,27)` is in the map's full blocked-cell overrides, so no new directional
entry was needed for that west edge. After reload, `inspect_move:17,27,DOWN`
reports `approach_blocked=true` and `effective_passable=false`. The
`(18,27)->RIGHT` edge later contradicted the first passable verifier: recent
manual taps showed repeated early-twitch cancels, and two fresh clean-state
`probe_edge_verify:18,27,RIGHT,5` runs both returned `moved=0 blocked=5` into
`(19,27)` while menu/dialogue state was clean. `map_reader.lua` now treats the
earlier passable result as contaminated and closes `(19,27).west`. After
reload, `inspect_move:18,27,RIGHT` reports `approach_blocked=true` and
`effective_passable=false`.

The user then suspected `(18,26)->RIGHT` too. Menu/input state was clean
(`MENU_STATE raw_open=false active_block=false submenu=nil`), and two
`probe_edge_verify:18,26,RIGHT,5` runs both returned `moved=0 blocked=5` into
`(19,26)`. `map_reader.lua` now closes `(19,26).west`; after reload,
`inspect_move:18,26,RIGHT` reports `approach_blocked=true` and
`effective_passable=false`. The post-patch reverse path from the Sage stand to
`(12,29)` rerouted via `1 north, 1 east, 4 south, 7 west`; the user then
suspected the first new east step too. `(18,25)->RIGHT` into `(19,25)` verified
blocked 5/5 twice, so `map_reader.lua` now closes `(19,25).west`; after reload,
`inspect_move:18,25,RIGHT` reports `approach_blocked=true` and
`effective_passable=false`. The later `(20,20)` retest reopened the Sage-side
return path to the exit-adjacent tile, so keep the counter-row blockers but do
not treat the earlier Sage-to-exit no-path result as current. If autowalk later
exposes a different candidate route, verify the next exact edge rather than
reopening the confirmed counter-row blockers.

Throne-room stair route regression from the castle entrance side was the same
south-gate false-entry pattern. The user reported that routing from the castle
entrance to `Stairs Up to Tantegel Castle Throne Room` became noisy and then
failed. Log analysis showed `AUTO_WALK` queued a 31-step route from `(12,29)`
whose first step was `(12,29)->UP`; that blocked, seam-retried, then rerouted
through `(13,29)->UP`, which also blocked. After clearing same-session seam
memory, `debug_pathfind_to:7,7` reproduced the bad modeled route:
`1 north, 1 west, 6 north, ...`. Raw verification confirmed both south
approaches as real blockers: `probe_edge_verify:12,29,UP,5` and
`probe_edge_verify:13,29,UP,5` each returned `moved=0 blocked=5`.
`map_reader.lua` now closes `(12,28).south` and `(13,28).south`. The
`(11,29)` control was inconclusive because that tile is not walkable
(`tile=0`), while `(10,29)` is walkable and `(10,29)->UP` previews open;
however, even from `(10,29)`,
`debug_pathfind_to:7,7` currently reports no path. Post-reload checks after
`LAUNCHER_PROBE: codex_stair_route_false_entries` now report
`inspect_move:12,29,UP` and `inspect_move:13,29,UP` with
`approach_blocked=true`/`effective_passable=false`; cleared-state
`debug_pathfind_to:7,7` from `(12,29)` returns clean `No path found` with no
autowalk noise. Treat this as progress from noisy execution to clean
no-route/gated-isolated behavior, not as proof that a working public route to
the throne-room return stair exists.

Latest Tantegel south-pocket wrinkle: the user flagged an engine blocker at
`(14,24)` when moving west. Fresh raw verifier proof after a live `POSITION:
map=0x04 x=14 y=24` check confirmed `(14,24)->LEFT` into `(13,24)` blocked
5/5 with `reason=raw_hold_timeout` and `runtime_added=false`. `map_reader.lua`
now keeps `(13,24)` standable but adds the `east` approach to its existing
directional blocker, so `(12,24)->RIGHT` and `(14,24)->LEFT` are both closed.
Post-reload proof after `LAUNCHER_PROBE: codex_1324_east_block`:
`inspect_move:14,24,LEFT` reports `approach_blocked=true` and
`effective_passable=false`, while `inspect_move:14,24,UP` and
`inspect_move:14,24,DOWN` both report `directional_blocked=false` and
`effective_passable=true`. This is not a full tile block; preserve north-south
movement through `(14,24)`. From `(14,24)`, the patched skip-NPC path back to
the entrance-adjacent tile now detours via `(12,29)` instead of the false
three-west shortcut. From `(12,29)`, `debug_pathfind_adjacent_skip_npcs:20,26`
still reports no path to the Sage, so this wrinkle cleans up a false route but
does not solve entrance-to-Sage access by itself.

Brecconary service-table cleanup now reflects that strategy. Merchant 1 only
gives ordinary Dragonlord dialogue, so `objects.lua` keeps him browsable as an
NPC but removes him from the Services filter. The confirmed Brecconary services
now modeled are `Weapons Merchant`, `Inn`, `Tool Merchant` at `(23,25)` facing
east, `Fairy Water Merchant` behind the northeast door, and `Curse Remover`
for Old Man 2. The curse-removal service is claim-confirmed from dialogue, not
yet tested while actually cursed. The Old Man 2 route is now viable: latest
manual movement and logs proved the real south approach through `(24,12)` and
`(24,11)`. `map_reader.lua` now promotes `(24,12)` as a Brecconary passthrough
and leaves the `(24,11)<->(24,12)` vertical seam open, while preserving the
confirmed trap blockers around the west/north landings:
`(23,9).east/south`, `(23,10).north/west`, `(24,8).south`,
`(22,10).east`, and the older `(24,9)`/`(25,9)`/`(26,9)` directional walls.
Reload proof after `LAUNCHER_PROBE: codex_curse_debug_stats`: from the town
entrance `(1,15)`, `debug_pathfind_adjacent:24,10` now chooses `(24,11)` with
a 29-step route and `Face north`; from `(24,11)`, `debug_pathfind_to:1,15`
returns a 29-step route back to the entrance. Both checks reported
`RUNTIME_BLOCKS map=0x08 none`. This completes the Curse Remover part of the
Brecconary service pass, but the Tool Merchant route reopened immediately
afterward: live route testing found `(16,25)->RIGHT` into `(17,25)` blocked.
`probe_edge_verify:RIGHT,3` from `(16,25)` with NPCs frozen confirmed
`moved=0 blocked=3 reason=raw_hold_timeout`, while inspect still thought
`(17,25)` was a passthrough. `map_reader.lua` now keeps `(17,25)` standable but
adds `(17,25).west` as a directional blocker. The latest return-route retest
then superseded the older `(21,26)` open evidence: auto-walk and manual taps
from `(22,26)->LEFT` repeatedly blocked, ending with
`SEAM_OBSERVATION cell=(21,26) approach=east blocked=13 moved=0`.
`map_reader.lua` keeps `(21,26)` standable for other approaches but adds
`(21,26).east`. The next live/manual clue found the replacement bridge:
`(17,22)` is part of the long east-west corridor and the older trap-cell
override was stale. Manual movement plus raw verifiers crossed
`(16,22)->RIGHT` and `(18,22)->LEFT` into `(17,22)` 3/3 times from each side,
so `map_reader.lua` now removes `(17,22)` from permanent blockers and promotes
it as a passthrough. After reload, `inspect_move:18,22,LEFT` reported
`permanent_blocked=false` and `effective_passable=true`; `(16,22)->RIGHT`
also reported `permanent_blocked=false` but had a live NPC on the destination.
From the entrance `(1,15)`, `debug_pathfind_to:23,25` now finds a 38-step
route to the Tool Merchant public stand. From `(23,25)`, the first reverse
debug route was blocked only by live NPC clutter at `(12,20)`/`(20,23)`; after
`unfreeze_npcs` and a short wait, `debug_pathfind_to:1,15` found a 36-step
return route. User manual testing then confirmed routes to and from the Tool
Merchant and the other essential Brecconary services pass in normal play. Other fresh blocked/noisy observations
in this log were not promoted: `(20,14).east` and `(4,16).west` were NPC-sourced, while
`(1,14).south`, `(1,16).north`, `(19,13).west`, and `(24,12).north` later
moved and are currently noisy/passable evidence only. Probe tooling was also
tightened during this pass: `probe_edge` / `probe_edge_verify` now hold raw
D-pad input and suspend `auto_step` while probing, because the old
auto-step-driven verifier could report false blockers/openings in this pocket.
Autowalk's stationary-NPC hint was also softened after the same log showed
`NO_PATH_STATIONARY_NPC` followed by a tryable route seconds later; it now says
the route may be blocked by a stationary or out-of-date NPC position and
suggests retrying rather than claiming waiting cannot help.
Validation for the `(21,26).east` / stationary-NPC hint patch passed:
`luac -p map_reader.lua test_map_reader.lua route_manager.lua
test_route_manager.lua`, `lua test_map_reader.lua` (24 tests),
`lua test_route_manager.lua` (54 tests), and `git diff --check` with only the
known `dw_access.ini` CRLF warning. Live reload proof:
`LAUNCHER_PROBE: codex_2126_east_block` at `(22,26)`, then
`inspect_move:22,26,LEFT` reported `directional_blocked=true`,
`blocked_approach=east`, and `effective_passable=false`.
Validation for the `(17,22)` corridor fix passed:
`luac -p map_reader.lua test_map_reader.lua`, `lua test_map_reader.lua`
(24 tests), and `git diff --check` with only the known `dw_access.ini` CRLF
warning. Live reload proof: `LAUNCHER_PROBE: codex_1722_corridor`, then the
route checks listed above.

Adjacent-path debug stats were cleaned up after the Curse Remover proof:
`pathfinder.lua` / `path_debug.lua` now prevent a successful adjacent route
from inheriting a stale `no_path` reason from a later failed adjacent candidate.
Regression coverage lives in `test_pathfinder.lua`.

Object-browser moving-NPC performance follow-up: the previous on-demand fix
kept moving NPCs fresh by calling `objects.update_npcs()` on plain browse keys,
but that brought back the old BizHawk hitch: switching objects could freeze
emulation and audio for about 1.5-2 seconds. `J`/`K`/`L`, filter readouts, and
command-file `next_object`/`prev_object`/`current_object` no longer rebuild the
full object list. Instead, `objects.describe_current()` reads only the selected
NPC slot live when forming the spoken description, so moving NPC directions can
update without paying for a full browser rebuild. Full NPC refresh is still
kept for route/planning actions (`R`, `O`, `U`, `pathfind`, `auto_walk`) and
the explicit pathability filter refresh, where current blockers matter more
than instant browse responsiveness.

Validation for this tuning passed:
`luac -p hotkeys.lua object_commands.lua objects.lua test_hotkeys.lua
test_objects.lua`, `lua test_hotkeys.lua` (27 tests), `lua test_objects.lua`
(43 tests), and `git diff --check`. Live BizHawk proof: launched via
`./launch_dw.sh --no-wait`, accepted `LAUNCHER_PROBE:
codex_object_browser_tune` at frame 30000, then a command-file browse sample at
frame 30720 (`reset_scan_stats`, `next_object`, `next_object`, `prev_object`,
`current_object`, `report_scan_stats`) produced object descriptions with no
`CMD_TIMING` warning. `report_scan_stats` showed no scan-profile sample because
profiling was not recording; the important quick check is that the command
handlers did not cross the 25 ms timing threshold. User-focused retest: this
brought the object-browser hop delay down from a 1.5-2 second emulator/music
freeze to a fraction of a second between hops. This is a successful first
tuning pass; remaining work is optional polish only if the smaller pause still
feels disruptive during normal play.

Player-facing selected-object teleport follow-up: the latest log showed
`Shift+Enter` exact teleport on `Exit to World Map` at Brecconary `(0,15)`
refusing because exact non-NPC selected-object teleport still used the object's
raw tile. That boundary tile is not walkable, so the hotkey entered the slow
manual-refusal path. `objects.resolve_teleport_landing()` now validates
non-NPC exact targets too: walkable objects such as stairs still land exactly,
while blocked exits/doors/chests look for an adjacent open cell with an escape
route and facing direction back toward the object. `main.lua` now uses that
resolver for all exact selected-object teleports, not only NPCs. Validation
passed: `luac -p objects.lua main.lua test_objects.lua`, `lua
test_objects.lua` (46 tests), and `git diff --check` with only the known
`dw_access.ini` CRLF warning. No live reload/repro was run during the user's
active castle travel, to avoid interfering with movement.

Latest Merchant 4 public access update: the user found a small walkable pocket
at `(22,25)`/`(23,25)` with an access node one tile east of the player. Fresh
live recheck at `POSITION: map=0x08(Brecconary) x=23 y=25` reported
`RUNTIME_BLOCKS map=0x08 none`; `inspect_move:22,25,RIGHT` and
`inspect_move:23,25,LEFT` are passable, while `inspect_move:23,25,RIGHT` and
`inspect_move:24,25,LEFT` are directionally blocked. The crucial correction is
that this is a blocked movement seam but still a valid counter interaction:
the recent log shows `MERCHANT_ACTION: Merchant. Buy.` from `(23,25)` facing
east. `objects.lua` now routes Merchant 4's service stand to `(23,25)` facing
east, and `map_reader.lua` keeps `(23,25).east` / `(24,25).west` closed for
movement. This supersedes the older "Merchant 4 isolated" route target below;
do not reopen the movement edge just because TALK reaches across the counter.

Latest Merchant 4 route-breakthrough: the remaining public route blocker was
one missing passthrough at `(17,25)`. A static graph pass showed that making
`(17,25)` walkable would connect public origin `(1,15)` to the confirmed
Merchant 4 public stand `(23,25)`. Live verifier proof then moved
`(16,25)->RIGHT` into `(17,25)` 3/3 times with `runtime_added=false`, so
`map_reader.lua` now records `(17,25)` as a Brecconary passthrough and
`test_map_reader.lua` pins it. Validation passed: `luac -p map_reader.lua
test_map_reader.lua` and `lua test_map_reader.lua` (24 tests). Reload proof:
`LAUNCHER_PROBE: codex_1725_reload`; after teleporting to `(1,15)`, live
`debug_pathfind_to:23,25` produced a 38-step route through
`... (16,25)->(17,25)->(18,25) ... ->(23,25)`. A first live retry briefly
reported no path because a live NPC occupied the `(12,20)` choke; a second
retry after NPC refresh succeeded. `validate_path` did not finish the route: it
aborted on an early open-floor overshoot at `(1,16)->RIGHT`, before reaching
the new Merchant 4 bridge. Treat that as movement-validation timing noise, not
new blocker evidence. Runtime blockers remained empty.

Latest Merchant 4 return-route follow-up: the previous `(21,26)` return-route
passthrough is now superseded. A later live route from `(22,26)` tried to move
west into `(21,26)` repeatedly; queued-route, seam-retry, and manual evidence
all blocked, ending at `SEAM_OBSERVATION map=0x08 cell=(21,26) approach=east
blocked=13 moved=0 classification=blocked_only source=manual_block`.
`map_reader.lua` still records `(21,26)` as standable so other approaches can
be investigated, but now blocks `(21,26).east`. Treat any older notes saying
`(22,26)->(21,26)` is the valid return connector as stale.

Latest route-drift follow-up: the user's first successful entrance-to-Merchant
4 auto-walk exposed route execution drift, not another map blocker. The log
shows planned routes cancelled after route-settle overshoots at `(7,16)->(8,16)`
and `(10,16)->(11,16)` while the next queued steps were different directions;
music/control freezes were not involved in this symptom. `route_manager.lua`
now handles `route_drift_off_path` cancellations by replanning from the drifted
tile to the same active target, preserving route context and logging
`AUTO_WALK_DRIFT_REROUTE` on recovery. Validation passed with targeted route
manager and auto-step tests. Live reload proof showed repeated drift recovery
on a Guard 2 route, eventually arriving and facing the target. A focused
Merchant 4 retest selected Merchant 4 at `(1,15)`, but the current live state
reported `NO_PATH_STATIONARY_NPC ... blocker=Guard 1 ... x=20 y=25` before a
route could start. Later user testing confirmed the entrance-to-Merchant 4
route succeeds after reroutes; the remaining manual repro was the return path,
which is covered by the `(21,26)` passthrough follow-up above.

Earlier Merchant 4 forced-teleport confirmation: the alternate tool-shop
pocket at `(25,26)` also opens the normal tool shop while facing north, and a
fresh state read reported `POSITION: map=0x08(Brecconary) x=25 y=26`,
`RUNTIME_BLOCKS map=0x08 none`, and `OBJECT: Merchant 4 (visited): 1 north,
counter here`. A reverse route from that pocket to public origin `(1,15)`
reported `No path found [no_path] (visited=1 path=0)`. Edge inspection from
that pocket still shows no public exit: `(25,26)->UP` is the merchant/NPC,
`(25,26)->DOWN` is blocked by `(25,27).north`, `(25,26)->LEFT` is
blocked/nonwalkable, `(25,26)->RIGHT` is nonwalkable, and from `(25,27)` only
`UP` into `(25,26)` remains passable. Keep this modeled as a real
one-way/isolated alternate interaction pocket, but do not use it as Merchant
4's normal route target now that the public `(23,25)` stand is confirmed.

Merchant 4 tool-shop item-list speech is now fixed in the live session. Before
the patch, `report_merchant_state` on the open list showed the visible rows
`Herb 24`, `Torch 8`, and split `Dragon's 20` / `Scale`, but
`active=false` and `offers=""` because `merchant.lua` only cataloged equipment
names. `items.lua` now exposes a shop catalog that includes equipment plus
item-shop goods such as `Herb`, `Torch`, `Dragon's Scale`, `Fairy Water`,
`Wings`, and `Magic Key`, and `merchant.lua` uses that catalog. Regression
coverage in `test_merchant.lua` pins the exact Brecconary tool-shop layout.
Validation passed: `luac -p items.lua merchant.lua test_merchant.lua
test_items.lua`, `lua test_merchant.lua` (13 tests), and `lua test_items.lua`
(3 tests). Live reload proof: `LAUNCHER_PROBE: merch4_tool_items_reload`, then
`MERCHANT_SELECT: Merchant. Gold 42. Herb. 24 gold.` A fresh
`report_merchant_state` reported `active=true` and
`offers="Herb, Torch, Dragon's Scale"`. Simulated Down taps in the open list
spoke `MERCHANT_SELECT: Torch. 8 gold.` and then
`MERCHANT_SELECT: Dragon's Scale. 20 gold.`

Merchant 4's first shop prompt is also fixed. The user reported the cursor was
on Buy, and a live dump showed the first prompt is a merchant-specific
Buy/Sell overlay: rows included `BUY` and `SELL`, while the ordinary
command-menu parser misread the same D8/D9 cursor as field `TALK`/`STATUS`.
`merchant.lua` now detects this `mode=action` prompt when the visible text says
`What can I do for thee?` and both `BUY`/`SELL` are present; D9 `0` maps to
`Buy`, D9 `1` maps to `Sell`. `main.lua` now announces
`MERCHANT_ACTION` for this mode and suppresses repeated stable-summary chatter
from the cursor blink. Regression coverage in `test_merchant.lua` pins the
live Brecconary Buy/Sell layout. Validation passed:
`luac -p merchant.lua main.lua test_merchant.lua` and `lua test_merchant.lua`
(14 tests). Live proof after reload: `LAUNCHER_PROBE:
merch_action_prompt_quiet_reload` spoke `MERCHANT_ACTION: Merchant. Sell.`
once with no repeat spam; a raw Up input then spoke `MERCHANT_ACTION: Buy`, and
`report_merchant_state` reported `active=true mode=action action_selection="Buy"`.

Merchant close-out dialogue leak is fixed. The user noticed old shop dialogue
sneaking in after closing Merchant 4. Before the fix, closing the item-list path
could let lower-dialogue speech see the previously visible shop prompt plus the
new farewell as one string, for example `Welcome... What dost thou want?` before
`I will be waiting for thy next visit.` `main.lua` now keeps the lower-dialogue
baseline synchronized while the merchant reader owns an active shop prompt or
list, so appended shop dialogue strips the already-visible prompt. Regression
coverage in `test_text.lua` pins the exact shop-prompt + farewell overlap.
Validation passed: `luac -p main.lua text.lua test_text.lua merchant.lua
test_merchant.lua`, `lua test_text.lua` (11 tests), and `lua test_merchant.lua`
(14 tests). Live proof after `LAUNCHER_PROBE:
merch_dialogue_baseline_reload`: from the active Merchant 4 Buy/Sell prompt,
raw A opened the list (`MERCHANT_SELECT: Merchant. Gold 42. Herb. 24 gold.`),
then raw B closed it and logged only `EVENT: dialogue: 'I will be waiting for
thy next visit.` without the earlier welcome/prompt text.

Current Brecconary Merchant 4 follow-up: map data is still anchored to
`map=0x08(Brecconary)`, not castle data. The fresh post-reload baseline is
`LAUNCHER_PROBE: final_clean_probe`, `POSITION: map=0x08(Brecconary) x=27
y=25`, and `RUNTIME_BLOCKS map=0x08 none`. `map_reader.lua` now records
`(27,26)` as a Brecconary passthrough after `probe_edge_verify:27,25,DOWN,3`
confirmed movement 3/3, with six moved observations total in the same log.
The lower-right invented bypass is also closed: live `validate_path` failed at
`(28,27)->DOWN` and a direct verifier attempt blocked there, so
`map_reader.lua` records `(28,28).north`. Reload proof after the patch:
`inspect_move:27,25,DOWN` is `effective_passable=true`, and
`inspect_move:28,27,DOWN` is `directional_blocked=true`,
`effective_passable=false`.

Latest manual Merchant 4 frontier update: the user manually verified
`(22,25)->LEFT` into `(21,25)` is hard engine-blocked. The live log backed this
up with repeated `manual_tap` blocks on `map=0x08` and `RUNTIME_BLOCKS map=0x08
none`, while pre-patch `inspect_move:22,25,LEFT` incorrectly reported
`effective_passable=true`. `map_reader.lua` now records `(21,25).east` as a
Brecconary directional block, not a full-cell blocker.

Validation/noise follow-up from the same pass: after `(21,25).east`, a route
from live `(23,22)` to Merchant 4's stand planned as `1 south, 4 east, 5 south,
2 west, 2 north`. Live `validate_path` failed on step 1,
`(23,22)->DOWN` into `(23,23)`, while `inspect_move:23,22,DOWN` still reported
`effective_passable=true`. The user then manually verified the engine definitely
does not allow `(23,22)->DOWN`; the live log also shows repeated `manual_tap`
blocks on `map=0x08`. `map_reader.lua` now records `(23,23).north` as a
Brecconary directional block, not a full-cell blocker. Reload proof:
`LAUNCHER_PROBE: codex_2323_reload`; `inspect_move:23,22,DOWN` now reports
`directional_blocked=true`, `approach_blocked=true`,
`effective_passable=false`, and `RUNTIME_BLOCKS map=0x08 none`. After the
subsequent validation overshoot left the hero at `(25,22)`, a fresh reload
`LAUNCHER_PROBE: codex_force_release_reload` plus `debug_pathfind_to:25,26`
reported `No path found [no_path] (visited=52 path=0)` with runtime blockers
still empty. `path_debug.lua` was
hardened so validation waits when `auto_step` is still active instead of
injecting a duplicate direction, and validation abort now cancels the active
injected step. `auto_step.cancel_active_step` also has a validation-only forced
release mode so successful validation arrivals can flush injected D-pad state
without changing normal manual-cancel behavior. The final live abort did not
leave a post-abort seam observation behind.

Latest manual cluster note: the user found the vertical x=22 cluster open
through the public approach: `(22,21)` is open from the south; `(22,22)` through
`(22,25)` are open north-to-south; `(22,26)` is open from the north but closed
to the south. East/west on these cells was not checked. Live `inspect_move`
already matches this model: all checked north/south opens report
`effective_passable=true`, while `inspect_move:22,26,DOWN` reports
`directional_blocked=true` into `(22,27)`, with `RUNTIME_BLOCKS map=0x08 none`.
No new blocker was promoted from the noisy seam observations; `test_map_reader`
now pins these open approaches so future timing noise does not close them.
Follow-up `debug_pathfind_to:25,26` from live `(22,21)` planned
`1 south, 3 east, 1 south, 2 east, 5 south, 2 west, 2 north`. `validate_path`
confirmed the first four steps through `(22,22)->(23,22)->(24,22)->(25,22)`,
then failed on `(25,22)->DOWN` into `(25,23)`. `inspect_move:25,22,DOWN` still
reported `effective_passable=true`, and runtime blockers remained empty. The
user manually verified `(25,22)->DOWN` is open from north to south, and the log
shows repeated successful moves into `(25,23)`. Treat that validator failure as
noise; `test_map_reader` now pins `(25,23).north` open. The next validation
from live `(25,23)` planned `2 east, 5 south, 2 west, 2 north` and cleanly
validated through `(27,28)`, then failed on `(27,28)->LEFT` into `(26,28)`.
`inspect_move:27,28,LEFT` still reported `effective_passable=true` and
`RUNTIME_BLOCKS map=0x08 none`, but repeated manual left taps from `(27,28)`
also blocked and the user confirmed this edge is engine-blocked. `map_reader.lua`
now records `(26,28).east` as a Brecconary directional block, not a full-cell
blocker. Reload proof: `LAUNCHER_PROBE: codex_2628_reload`;
`inspect_move:27,28,LEFT` now reports `directional_blocked=true`,
`blocked_approach=east`, `approach_blocked=true`, and
`effective_passable=false`, with `RUNTIME_BLOCKS map=0x08 none`. The next
planner detour from `(27,28)` is `1 south, 1 west, 1 north, 1 west, 2 north`;
`validate_path` failed immediately on `(27,28)->DOWN` into `(27,29)`, while
`inspect_move:27,28,DOWN` still reported `effective_passable=true`. Repeated
manual down taps from `(27,28)` blocked on the same edge, and the user confirmed
this south exit is engine-blocked. `map_reader.lua` now records `(27,29).north`
as another Brecconary directional block. Reload proof:
`LAUNCHER_PROBE: codex_2729_reload`; `inspect_move:27,28,DOWN` now reports
`directional_blocked=true`, `blocked_approach=north`,
`approach_blocked=true`, and `effective_passable=false`, with
`RUNTIME_BLOCKS map=0x08 none`. The next planner detour from `(27,28)` is
`1 east, 1 south, 2 west, 1 north, 1 west, 2 north`; `validate_path` failed
immediately on `(27,28)->RIGHT` into `(28,28)`, while
`inspect_move:27,28,RIGHT` still reported `approach_blocked=false` and
`effective_passable=true`. Repeated manual right taps from `(27,28)` blocked,
and the user confirmed this east exit is engine-blocked. `map_reader.lua` now
merges `(28,28).west` with the existing `(28,28).north` directional block.
Reload proof: `LAUNCHER_PROBE: codex_2828_west_reload`;
`inspect_move:27,28,RIGHT` now reports `directional_blocked=true`,
`blocked_approach=west`, `approach_blocked=true`, and
`effective_passable=false`, with `RUNTIME_BLOCKS map=0x08 none`. From the same
live position, `debug_pathfind_to:25,26` now reports `No path found [no_path]
(visited=52 path=0)`, so the current lower-right Merchant 4 detour is closed
without runtime blocker contamination.

The saboteur reappeared in a remaining soft-block path, not permanent map
data. A parked-NPC Merchant 4 survey hit timing noise on the newly confirmed
`(27,25)->DOWN` edge and seam memory briefly treated `(27,26).north` as
blocked-only. `route_manager.lua` now keeps seam-memory observations
diagnostic-only even when callers pass `include_unconfirmed_seams=true`;
reroutes may still add a one-off temporary block for the edge that just failed,
but old blocked-only seam noise no longer becomes same-session pathfinding
truth. Fresh reload reset the poisoned survey state and left runtime blockers
empty. Focused tests passed: `luac -p route_manager.lua test_route_manager.lua
map_reader.lua test_map_reader.lua`, `lua test_route_manager.lua` (53 tests),
`lua test_map_reader.lua` (24 tests), `luac -p auto_step.lua debug_tools.lua
config.lua test_auto_step.lua`, and `lua test_auto_step.lua` (43 tests).

Current Merchant 4 route status: from `(27,25)`, the model can step into
`(27,26)`, but current live pathfinding still reports no route to the real tool
shop stand `(25,26)`. The latest clean search rejects `(27,27)` as
`blocked_npc`; before reload, the live NPC table showed `Person 2` occupying
the lower-right route area. Treat this as live NPC occupancy / movement
execution follow-up, not a new permanent blocker. Best next step is to verify
Merchant 4 with NPCs parked or a skip-NPC debug path after the movement timing
noise is calmer; do not promote anything from `dw_blocks.log` or blocked-only
seam memory.

Manual wall-collision lag follow-up: recent logs showed repeated real wall
bumps in Brecconary timing out as `manual_tap` blocks after 45 frames, for
example `(23,22)->DOWN`, `(21,22)->DOWN`, `(27,28)->DOWN`, and
`(27,25)->LEFT`. The worst pattern is when a physical key press already hits a
known static wall, then tap-to-step extends the released tap into the same
blocked edge and emits another blocked seam observation. `auto_step.lua` now
checks manual tap-to-step releases against static permanent blockers and static
directional blockers before starting the synthetic hold. Known blocked manual
edges now log `AUTO_STEP_REFUSED_STATIC_BLOCK` and do not inject D-pad input or
write another seam observation; debug/probe `inject_step` still intentionally
tests known blocked edges. Reload proof:
`LAUNCHER_PROBE: codex_static_wall_refusal_reload`; live position after reload
was `map=0x08(Brecconary) x=24 y=25`. Focused checks passed:
`luac -p auto_step.lua test_auto_step.lua`, `lua test_auto_step.lua` (47
tests), and `git diff --check` with only the known `dw_access.ini` CRLF warning.

Follow-up after the user still felt a 5-6 second hang after releasing movement:
fresh logs from `(24,25)` showed the same `manual_tap` pattern on an unmodeled
wall edge `(24,25)->DOWN` into `(24,26)` and on a live NPC block
`(24,25)->RIGHT` into `(25,25)`. Because those were not known static blocks,
the prior fix did not trigger; auto-step still held the synthetic D-pad through
the 45-frame timeout after the physical key was released. `auto_step.lua` now
releases physical `manual_tap` synthetic input as soon as the movement subpixel
twitched, while preserving the old early-twitch hold for debug/probe
`inject_step` and queued route verification. Unit coverage now distinguishes
physical press/release taps from debug injection. Reload proof:
`LAUNCHER_PROBE: codex_manual_tap_release_reload`; live position after reload
was still `map=0x08(Brecconary) x=24 y=25`. Focused checks passed:
`luac -p auto_step.lua test_auto_step.lua`, `lua test_auto_step.lua` (49
tests), and `git diff --check` with only the known `dw_access.ini` CRLF warning.

Second follow-up after user still saw little improvement: the fresh post-reload
log proved the first half worked but the same-direction turn-repress recovery
undid it. Example: `(24,25)->DOWN` released after a frame-4 subpixel twitch,
then `auto_step schedule turn repress` fired at frame 18, re-pressed DOWN, and
timed out at frame 45 with `turn_represses=1`; RIGHT into live NPC `(25,25)`
did the same. `auto_step.lua` now suppresses turn-repress recovery for physical
`manual_tap` once any movement-start/subpixel twitch has happened. Debug/probe
`inject_step` and queued routes still retain the conservative re-press behavior.
Reload proof: `LAUNCHER_PROBE: codex_manual_repress_suppressed_reload`; live
position after reload was still `map=0x08(Brecconary) x=24 y=25`. Focused
checks passed again: `luac -p auto_step.lua test_auto_step.lua` and
`lua test_auto_step.lua` (49 tests). Next live proof should be one quick
released manual bump into DOWN or RIGHT from `(24,25)`; the log should no
longer show `auto_step schedule turn repress` for that physical tap after an
early twitch.

Third follow-up from the user's timing clue: the emulator did not freeze until
roughly half a second after key release. Fresh logs after the re-press fix
matched that: physical `manual_tap` no longer repressed in most bump attempts,
but it still waited until the normal 45-frame blocked timeout and then
published `route_blocked`/`SEAM_OBSERVATION`/NPC-block handling. That delayed
blocked-event path is likely the remaining hitch. `auto_step.lua` now treats a
released physical `manual_tap` with a movement-subpixel twitch as gameplay
input, not map evidence: if the tile has not changed about 20 frames after the
twitch, it logs `auto_step cancel manual_tap early-twitch wait`, neutralizes
input, and silently cancels before the blocked-step machinery fires. Debug/probe
`inject_step` and queued routes still publish blocked events. Reload proof:
`LAUNCHER_PROBE: codex_manual_twitch_silent_cancel_reload`; live position after
reload was still `map=0x08(Brecconary) x=24 y=25`. Focused checks passed:
`luac -p auto_step.lua test_auto_step.lua`, `lua test_auto_step.lua` (50
tests), and `git diff --check` with only the known `dw_access.ini` CRLF warning.

Current Brecconary blocker-policy and weapon-shop throat follow-up: the user
manually verified `(5,7)<->(5,6)` is freely passable both ways, matching the
previous manual proof that `(5,7)<->(5,8)` is open. `map_reader.lua` now keeps
both vertical weapon-shop throat seams open: remove the stale `(5,6).south`
directional block as well as the earlier stale `(5,8).north`; keep the east
wall into `(6,7)` modeled. Live reload proof:
`LAUNCHER_PROBE: codex_manual_promotion_reload`; after clearing
`clear_blocked_tiles:8` and `clear_seam_cells:8`, `inspect_move:5,7,UP`
reported `effective_passable=true`, `directional_blocked=false`, and
`RUNTIME_BLOCKS map=0x08 none`.

The cranky-engine policy is now explicit in code: blocked-step, seam-memory,
and `probe_edge_verify` evidence no longer automatically inject runtime
blockers. A hostile verifier repro after reload still reported
`probe_edge_verify:5,7,UP,3` as `classification=confirmed_blocked`, but the
important new result is `runtime_added=false`, `manual_promotion_required=true`,
and a follow-up `RUNTIME_BLOCKS map=0x08 none`. Treat verifier consensus as
diagnostic evidence only. To promote after manual review, use
`add_blocked_edge:X,Y,DIR` (or `add_blocked_edge:MAP,X,Y,DIR`) for a specific
directional edge, or `add_blocked_tile:X,Y` only for a deliberate full-cell
runtime block. Static validation for this policy passed:
`luac -p main.lua route_manager.lua auto_step.lua test_route_manager.lua
test_auto_step.lua`, `lua test_route_manager.lua` (53 tests),
`lua test_auto_step.lua` (39 tests), `lua test_map_reader.lua` (24 tests),
`lua test_objects.lua` (42 tests), and `git diff --check`.

Earlier Merchant 4 alternate-pocket pass: the user manually verified `Merchant 4` is
the normal Brecconary tool merchant, and the user also verified `Woman 1` is
the Fairy Water merchant behind the northeast door. Live probing found two
separate tool-shop interaction facts. The raw large-tile trigger at `(24,25)`
still opens `Welcome. We deal in tools. What can I do for thee?` while facing
east, but it is a false public seam: `(24,25)->LEFT` into `(23,25)` and the
reverse `(23,25)->RIGHT` both blocked 5/5. A later fresh live/manual check
superseded the old TALK miss from `(23,25)`: the engine still blocks walking
east across the seam, but TALK from `(23,25)` facing east opens the tool shop.
`map_reader.lua` keeps `(23,25).east` and `(24,25).west` directional-only so
the counter trigger stays standable without letting A* route through it.

The alternate tool-shop interaction tile is `(25,26)` facing north. Live
verifier `probe_edge_verify:25,27,UP,3` moved into `(25,26)` 3/3 despite the ROM
decoding that cell as type-0 nonwalkable; from `(25,26)`, TALK opened the tool
shop and the item list showed `Herb 24`, `Torch 8`, and `Dragon's Scale 20`.
`map_reader.lua` keeps `(25,26)` as a Brecconary passthrough/alternate pocket,
but `objects.lua` now targets Merchant 4's normal public service interaction at
`(23,25)` facing east. Older reload proof for the alternate pocket:
`dw_debug.log` from `Started: 2026-05-11 14:30:39` logged
`LAUNCHER_PROBE: merch4_patch`, then reported `POSITION:
map=0x08(Brecconary) x=25 y=26` and re-read the tool-shop dialogue.

The `(25,26)` pocket now looks isolated/locked rather than a missing public
route from the main waypoint system. After the first Merchant 4 patch,
`debug_pathfind_to:25,26` from public origin `(1,15)` still reported
`No path found [no_path]`, and the remaining public-to-tool-shop frontier is the
lower southeast seam cluster. Earlier probes already blocked
`(14,28)->RIGHT`, `(15,27)->DOWN`, and `(15,27)->RIGHT`; the previously
unchecked edge `probe_edge_verify:16,26,DOWN,5` also blocked 5/5 into
`(16,27)`. Reverse checks showed parts of that boundary are one-way:
`(16,27)->UP` moved 3/3 and `(15,28)->LEFT` moved 3/3. The Merchant stand is
also one-way/trap-like: `(25,27)->UP` enters `(25,26)`, but
`(25,26)->DOWN` blocked 5/5, so `map_reader.lua` records `(25,27).north`.
`(16,27)->LEFT` was noisy mixed (2 moved, 1 blocked) and should not be
promoted yet.

A focused inside-out validation from `(25,27)` initially found a static route
back to public space, but live `validate_path` failed on step 1 at
`(25,27)->LEFT`. A clean repeat then confirmed `(25,27)->LEFT` into `(24,27)`
blocked 5/5, so `map_reader.lua` records `(24,27).east`. After reload, the
planner's next invented exit was `(25,27)->DOWN`; `probe_edge_verify` confirmed
that edge blocked 5/5 into `(25,28)`, so `map_reader.lua` records
`(25,28).north`. With both seams modeled, `debug_pathfind_to:1,15` from
`(25,27)` reports `No path found [no_path] (visited=2)`, and the public-origin
check `debug_pathfind_to:25,26` reports `No path found [no_path] (visited=406)`
with `RUNTIME_BLOCKS map=0x08 none`. The saved visual map supports this
classification: sampled dominant colors show `(25,28)` as blue water and the
tool-shop pocket not drawn as an ordinary street connection. Follow-up public
route evidence reached `(22,26)`, but the user manually verified
`(22,26)->DOWN` into `(22,27)` is hard engine-blocked; before patch,
`inspect_move:22,26,DOWN` incorrectly reported `effective_passable=true`, so
`map_reader.lua` now records `(22,27).north` as a directional seam. Reload
proof: `LAUNCHER_PROBE: merch4_edge_reload`; after reload,
`inspect_move:22,26,DOWN` reported `directional_blocked=true`,
`approach_blocked=true`, `effective_passable=false`, and
`RUNTIME_BLOCKS map=0x08 none`. From current live position `(22,26)`,
`debug_pathfind_to:25,26` now reports clean `No path found [no_path]
(visited=51)`. The refreshed search frontier can still explore the upper/right
southeast cluster, but it cannot enter the real tool-shop stand region: current
frontiers include the deliberate false-trigger seam into `(24,25)`, the new
hard block at `(22,27).north`, and ROM-wall neighbors such as `(23,26)`,
`(26,25)`, and `(27,26)`. Current validation passed:
`luac -p map_reader.lua test_map_reader.lua`, `lua test_map_reader.lua` (24
tests), `lua test_objects.lua` (42 tests), and `git diff --check`.

Merchant 4 suspect-cell probe follow-up after `(22,27).north`: no new
permanent map changes were made. The model inspection showed `(23,26)`,
`(24,26)`, `(26,26)`, and `(27,26)` are type-0 false-wall candidates, while
`(26,25)`, `(23,27)`, and `(26,27)` are older full permanent blockers. Live
probes found `(27,25)->LEFT` into `(26,25)` blocked 5/5 and
`(27,27)->LEFT` into `(26,27)` blocked 5/5. `(27,25)->DOWN` did move once into
`(27,26)`, but the repeated verifier then aborted because the held input left
an active step; from the live `(27,26)` position, `(27,26)->LEFT` into
`(26,26)` blocked. `(22,26)->RIGHT` into `(23,26)` moved twice, blocked once,
then aborted from the same held-input issue; from the live `(23,26)` position,
`(23,26)->RIGHT` into `(24,26)` blocked and `(23,26)->DOWN` into `(23,27)`
blocked. The tool-shop-side checks were also not route-opening:
`(25,26)->LEFT` into `(24,26)` was noisy mixed (1 moved, 2 blocked), while
`(24,25)->DOWN` into `(24,26)`, `(24,27)->UP` into `(24,26)`, and
`(25,26)->RIGHT` into `(26,26)` all blocked 3/3. Final live state after the
pass: `POSITION: map=0x08(Brecconary) x=25 y=26` and
`RUNTIME_BLOCKS map=0x08 none`. Best next manual checks are the noisy
passable-looking cells `(23,26)`, `(24,26)`, and `(27,26)`; the automated
evidence says they do not currently form a reliable route to Merchant 4.

Current Brecconary door-attribution refinement: live state remained clean at
`POSITION: map=0x08(Brecconary) x=24 y=25`, `RUNTIME_BLOCKS map=0x08 none`,
and `DOOR_STATE keys=0` with no opened slots. `report_npcs` from the current
live table showed `Old Man 1` at `(1,20)`, `Woman 1` at `(24,4)`, `Guard 4` at
`(3,22)`, `Weapons Merchant` at `(5,4)`, `Person 3` at `(20,10)`,
`Old Man 2` at `(24,10)`, `Person 1` at `(24,22)`, `Person 5` at `(20,23)`,
`Merchant 4` at `(25,25)`, plus currently no-path `Guard 2` at `(24,11)` and
`Guard 3` at `(6,26)`. Static pathfinder checks from the public Brecconary
origin `(1,15)` with NPC blockers skipped and door RAM simulated per state
split the targets cleanly: `Northeast Door` `(21,6)` alone makes `Woman 1`
reachable (`len=33`, stand `(24,5)`). The user then manually verified that
`Woman 1` is the Fairy Water merchant, so treat that target as intentionally
locked behind the northeast door. `Inn West Room Door` `(5,22)` alone makes
`Old Man 1` reachable (`len=26`, stand `(1,21)`) and `Guard 4` reachable
(`len=24`, stand `(3,21)`). Opening both doors still leaves `Weapons Merchant`
stand `(5,6)`, the center-east room (`Person 3`, `Old Man 2`, `Guard 2`), the
southeast room (`Person 1`, `Person 5`), `Guard 3`'s lower-left room, and
`Merchant 4`'s southeast tool-shop region no-path. Treat those as route/seam
follow-ups, not known-door-gated NPCs. This refines the older "both doors only unlock
`Guard 4` and `Woman 1`" note with the current live NPC table: `Old Man 1` is
also inn-west-room gated at his current `(1,20)` position.

Current Brecconary map-comparison pass: Mike's RPG Center's Brecconary
reference image is now saved locally at
`project_resources/maps/brecconary/mikesrpgcenter_brecconary.png`, with a
screen-reader-friendly source/legend note in
`project_resources/maps/brecconary/README.md`. This was cross-checked with
Realm of Darkness, StrategyWiki, and Gamer Corner. External guide evidence says
Brecconary has two locked doors: the northeast Fairy Water shop and the west
room in the inn. The object locator previously exposed no Brecconary
doors; `objects.lua` now adds `Northeast Door` at `(21,6)` and
`Inn West Room Door` at `(5,22)`, while `map_reader.lua` now treats both as
door cells controlled by the opened-door RAM array. Live reload proof:
`dw_debug.log` from `Started: 2026-05-10 20:43:06` logged
`LAUNCHER_PROBE: brec_doors_reload`; the Doors filter then listed
`Inn West Room Door` and `Northeast Door`, `report_door_state` showed
`keys=0` and no opened slots, and `RUNTIME_BLOCKS map=0x08 none`. Static
RAM-open simulation with both Brecconary doors open originally made only
`Guard 4` and `Woman 1` reachable; the current live-NPC refinement above also
classifies `Old Man 1` as inn-door gated at `(1,20)`. `Weapons Merchant`,
`Person 3`, `Person 5`, `Old Man 2`, `Merchant 4`, and `Person 1` stayed
unreachable, with current live no-path additions `Guard 2` and `Guard 3`, so
those are missing route/blocker-data follow-ups rather than explained by the
known doors. The
weapon stand `(5,6)` also still has direct verifier evidence:
`probe_edge_verify:5,7,UP,5` blocked 5/5 in the current engine state.
`route_manager.lua` now only gives the closed-door no-path hint when opening
the reachable closed-door frontier would make the selected target reachable,
so bad-blocker cases like `Merchant 4` do not get misreported as door-gated.
Final reload proof after the route-hint patch: `dw_debug.log` from
`Started: 2026-05-10 20:50:26` logged
`LAUNCHER_PROBE: brec_route_hint_reload` and
`POSITION: map=0x08(Brecconary) x=1 y=15`.
Static validation passed: `luac -p route_manager.lua objects.lua
map_reader.lua test_objects.lua test_map_reader.lua test_route_manager.lua`,
`lua test_objects.lua` (41 tests), `lua test_map_reader.lua` (23 tests),
`lua test_route_manager.lua` (51 tests), and `git diff --check`.

Follow-up false-blocker poke-around did not find a live false blocker yet.
Mike's map labels the center-east building as `4) Fairy Water` and the
top-right building as `5) Removes Curses`, while Realm says the Fairy
Water/special item shop needs a Magic Key and Gamer Corner lists only two
Brecconary locked doors: northeast building and west room in inn. Because the
service labels disagree by source/location, keep `Northeast Door` positional
instead of calling it the Fairy Water door. A static "open one candidate" pass
showed `(20,12)/(21,12)/(22,12)/(24,12)` would connect the Person 3 / Old Man
2 room, and several southeast candidates would connect `Person 5`, `Person 1`,
or `Merchant 4`; live probes then blocked the checked candidates:
`(24,13)->UP`, `(21,8)->DOWN`, `(17,10)->RIGHT`, `(21,16)->DOWN`,
`(25,14)->DOWN`, `(17,20)->DOWN`, `(16,25)->RIGHT`, `(16,26)->RIGHT`,
`(14,28)->RIGHT`, `(15,27)->DOWN`, `(15,27)->RIGHT`, `(22,13)->UP`,
`(21,13)->UP`, `(20,13)->UP`, `(19,13)->UP`, and `(16,22)->RIGHT`.
Each verifier-added runtime block was cleared; final live state was restored to
`POSITION: map=0x08(Brecconary) x=1 y=15` with
`RUNTIME_BLOCKS map=0x08 none`. Superseding note: the Old Man 2 room was later
opened by manual/live proof that `(24,12)` is the intended passthrough, and the
old `(16,22)->RIGHT` block was later disproved by raw verifier proof that
`(17,22)` is passable from both east and west.

Future tooling/process note: `TASKS.md` now exists as a lightweight backlog.
It includes the optional image-parsing QoL task: add Pillow support in a
repo-local Python virtual environment, or keep/commit a small built-in PNG
sampler for indexed map images. This should help future visual-map reference
work without interrupting live probe loops.

Current local patch fixes selected-object teleport for NPCs while the user is
checking Brecconary dialogue before moving on. `Shift+Enter` on an NPC now
resolves a usable landing through `objects.resolve_teleport_landing()` instead
of aiming at the NPC's occupied cell. The resolver keeps the hotkey path cheap:
it reads the selected NPC slot's live RAM position without a full object-list
rebuild, skips NPC-occupied adjacent landings, honors service interaction
stands such as Brecconary counters, and falls back to cardinal adjacent cells
that have at least one non-target exit.
Fresh logs confirmed the counter resolver chose
`Weapons Merchant target=(5,4) landing=(5,6) landing_reason=interaction`, but
TALK still said `There is no one there.` because the hero was not facing north.
`main.lua` now queues one raw post-teleport facing tap after input
suppression. This logs `TELEPORT_FACE`, skips auto-step for that frame, then
neutralizes input for two more frames, and should face counter/service NPCs
without walking onto walkable counter tiles. After the user reported that
`Shift+Enter` teleport could leave controller access apparently stuck until
Enter was pressed again, the suppression became release-aware: it now watches
the non-modifier trigger key (`Enter` or an arrow) and keeps Start/D-pad
neutralized until that key is released, then runs the facing tap. Static
Follow-up live investigation showed the remaining "hung" case was not menu or
input state: at `map=0x08 x=5 y=7`, logs reported `keys=-`, `joy1=-`,
`buttons=0x00`, menu closed, and path target nil. The first injected-movement
read treated UP, DOWN, and RIGHT as blocked while LEFT was the target NPC at
`(4,7)`, but the DOWN portion was later disproved by manual movement and is
now documented below as a bad directional promotion. `map_reader.lua` still
models the confirmed UP and RIGHT seams around that trap, and
`objects.resolve_teleport_landing()` skips adjacent landings with no escape
route. The intended fallback for that Woman 3 case is now the south stand at
`(4,8)`, facing north. Static validation passed: `luac -p main.lua
objects.lua map_reader.lua config.lua test_objects.lua test_map_reader.lua
test_hotkeys.lua`, `lua test_objects.lua` (40 tests), `lua test_map_reader.lua`
(22 tests), `lua test_hotkeys.lua` (25 tests), and `git diff --check` (with the
known `dw_access.ini` CRLF warning). Latest reload proof:
`dw_debug.log` from `Started: 2026-05-10 20:04:46` logged
`LAUNCHER_PROBE: codex_teleport_escape_fix` at frame 60. Next manual check:
press `Shift+Enter` on a selected Brecconary NPC and confirm
`TELEPORT_INPUT_SUPPRESS`, `TELEPORT_INPUT_RELEASED`,
`TELEPORT_SELECTED ... landing_reason=adjacent|interaction`, and
`TELEPORT_FACE ... face=<dir>` before TALK. For Woman 3 at `(4,7)`, landing
should be `(4,8)`, not `(5,7)`.

Post-restore follow-up on 2026-05-11 found the weapon-shop TALK visited marker
still missed when the selected object was not the service NPC. The restored
live state was Brecconary `(5,6)`, menu closed, speech ready, no runtime
blocks, and current object `Exit to World Map`; selecting TALK opened the
weapon shop but previously logged `VISITED_AUTO skipped: no adjacent NPC
matched TALK dialogue`. `objects.mark_adjacent_npc_visited()` now checks all
NPC/service objects whose `interaction_x/y` equals the player's TALK tile
before falling back to one-tile adjacency or live-NPC RAM. Validation passed:
`luac -p objects.lua test_objects.lua`, `lua test_objects.lua` (42 tests), and
`git diff --check`. Live reload proof:
`LAUNCHER_PROBE: visited_counter_reload`; from `(5,6)` with `Exit to World Map`
selected, TALK opened the weapon shop and logged
`VISITED_AUTO map=0x08 target_id=npc_10 target_name=Weapons Merchant`. The shop
was backed out afterward; final check showed menu closed, position still
`(5,6)`, and speech ready.

Manual Brecconary west-wing throat follow-up: the user found the player trapped
in a pocket with no pathable NPCs because the local graph still treated live
passable type-0 cells as walls. Fresh log evidence showed `(3,7)->DOWN` into
`(3,8)` moved, `(3,8)->DOWN` into `(3,9)` moved, `(3,9)->UP` back to `(3,8)`
moved, `(3,8)->UP` into `(3,7)` moved, and east/west movement between `(2,9)`
and `(3,9)` moved. `inspect_tile` before patch showed `(3,7)`, `(2,9)`, and
`(3,9)` as type-0 nonwalkable despite live movement. The user also hammered
`(3,7)->UP` into `(3,6)`, which logged five blocked attempts and
`inspect_tile:3,6` showed type-0, no NPC, no runtime block, so `(3,6)` stays
closed. `map_reader.lua` now adds Brecconary passthrough cells `(3,7)`,
`(2,9)`, and `(3,9)` while keeping `(3,6)` closed. Validation passed:
`luac -p map_reader.lua test_map_reader.lua`, `lua test_map_reader.lua`
(24 tests), and `git diff --check`. Live reload proof:
`LAUNCHER_PROBE: brec_west_throat_reload`; `inspect_tile` reports `(3,7)`,
`(2,9)`, and `(3,9)` as `reason=passthrough`, `(3,6)` as closed by
`reason=tile_type`, and `RUNTIME_BLOCKS map=0x08 none`. From live position
`(3,7)`, `pathability_filter:Reachable` reported `All, reachable. Woman 3:
1 east (1 of 16)`, confirming the pocket is no longer pathability-empty.

Manual Brecconary east-wing throat follow-up: the user found another
pathability-empty pocket caused by a live-passable type-0 cell. Fresh log
evidence showed repeated bidirectional vertical movement between `(22,24)` and
`(22,23)`: `(22,24)->UP` into `(22,23)` moved four times, and
`(22,23)->DOWN` back into `(22,24)` moved five times. Before the patch,
`inspect_tile:22,24` reported `tile=0.0 base_walkable=false reason=tile_type`
with `permanent_blocked=false`, `npc_blocked=false`, no directional block, and
`RUNTIME_BLOCKS map=0x08 none`, so the false blocker came from the base town
tile decoder rather than `MAP_BLOCKED_CELLS` or runtime block data.
`map_reader.lua` now adds `(22,24)` as a Brecconary passthrough and
`test_map_reader.lua` pins it in the passthrough snapshot test. Validation
passed: `luac -p map_reader.lua test_map_reader.lua`,
`lua test_map_reader.lua` (24 tests), and `git diff --check`. Live reload
proof: `LAUNCHER_PROBE: brec_east_throat_reload`; `inspect_tile:22,24` now
reports `reason=passthrough`, `effective_passable=true`, runtime blocks remain
empty, and from live position `(22,24)` `pathability_filter:Reachable` reported
`All, reachable. Person 5: 1 north, 2 west (1 of 18)`.

Manual Brecconary weapon-shop throat false-directional follow-up: the user
found that the edge between `(5,7)` and `(5,8)` is open both ways, reopening
the path out of the Weapons Merchant throat. Fresh log evidence showed
`(5,7)->DOWN` into `(5,8)` moved four times, `(5,8)->UP` into `(5,7)` moved
three times, and pathfinding from `(5,8)` to the town exit already found the
southwest route while pathfinding from `(5,7)` still reported no path. Before
the patch, `inspect_move:5,7,DOWN` showed the only blocker was the stale model
entry `blocked_approach=north approach_blocked=true` on destination `(5,8)`;
tile, permanent, NPC, and runtime blockers were all clear. This came from the
2026-05-10 selected-NPC teleport "trap" repro, which over-promoted `(5,8).north`
from a noisy injected-movement timeout. `map_reader.lua` now removes
`(5,8).north` while keeping the still-modeled `(5,6).south` and `(6,7).west`
seams. Validation passed: `luac -p map_reader.lua test_map_reader.lua`,
`lua test_map_reader.lua` (24 tests), and `git diff --check`. Live reload
proof: `LAUNCHER_PROBE: brec_57_58_unblock_reload`; `inspect_move:5,7,DOWN`
and `inspect_move:5,8,UP` both report `approach_blocked=false` and
`effective_passable=true`; after teleporting to `(5,7)`,
`debug_pathfind_to:1,15` found `2 south, 3 west, 5 south, 1 west, 1 south`
with `visited=28 path=12`, and `pathability_filter:Reachable` reported
13 reachable objects.

Resume from world-map grinding after exiting Erdrick's Cave. The combat spell
bug was captured in a Red Slime fight where the user parked the battle SPELL
submenu on the first spell; live state showed cursor `D8=0 D9=0`, visible spell
text `HEAL` / `HURT`, HP `22/31`, and MP `14/14`.

Combat spell reading now has a first fix in the worktree, plus a lag follow-up.
`battle.lua` can recognize a battle spell-list screen by visible known spell
names, and `main.lua` keeps a battle spell submenu mode so cursor `(0,0)` is
announced as the selected spell instead of top-level `FIGHT`. After BizHawk
auto-reload, `dw_debug.log` from `Started: 2026-05-10 15:25:01` logged
`BATTLE_SPELL: Spells. Heal. 4 MP` while still on the parked spell list.
The first implementation lagged combat because it decoded the upper battle
window every battle-menu poll. The current patch limits that expensive
spell-screen scan to a one-time recovery probe after reload/attach; normal
SPELL entry is tracked from the A press. Latest polish also stops doing the
recovery scan on every normal battle start, treats an A-held transition from
top-level SPELL into cursor `(0,0)` as spell-list entry without a PPU scan, and
uses interrupting speech for spell-list announcements so rapid Heal/Hurt cursor
movement does not queue stale spell names. Follow-up logs showed combat start
was fixed, but spell-menu entry and Heal/Hurt movement still glitched. The
latest disk patch removes the generic field-menu `COMMAND` PPU scanner from
the battle-menu path entirely; battle cursor tracking now reads the already
cached D8/D9 cursor RAM from `game_snapshot` and only uses the upper-window
spell scan for the rare case where the script reloads directly into an unknown
battle spell-list state.

Current validation passed: `luac -p main.lua battle.lua test_battle.lua
test_items.lua`, `lua test_battle.lua` (26 tests), `lua test_items.lua`, and
`git diff --check`. Latest reload proof is `dw_debug.log` from
`Started: 2026-05-10 19:01:39`, with
`LAUNCHER_PROBE: battle_dot_artifact_dedupe` at frame 60. After the user
confirmed opening battle announcements now work well, the latest patch keeps
the `Battle!`/`draws near` fast path and adds a battle-action fast path:
complete action/damage sentence prefixes such as attacks and HP reduction/loss
lines can interrupt stale menu speech after a short 6-frame confirmation,
without waiting for the whole lower dialogue page to stabilize. Victory/reward
text stays on the normal stable battle-dialogue path, and leaked `Gold`
macro artifacts like `GOLD Gold increases` are normalized. Next useful test is
a normal fight: confirm attack/damage lines are spoken during the round rather
than near the end, while reward text remains readable and not chattery.
Follow-up log analysis found one missed action line in a quick Slime one-hit
kill: the log went from `A Slime draws near!` directly to reward text, while
longer Red Slime rounds announced attacks/damage correctly. The latest patch
preserves already-complete action prefixes before a truncated `reduced by` /
`decreased by` fragment is dropped, and the fast path now extracts the last
eligible action prefix before reward text begins. Reload proof:
`Started: 2026-05-10 18:52:58` with
`LAUNCHER_PROBE: battle_fast_prefix_fix` at frame 60. Next useful live check:
one-shot Slimes should now still announce at least `Bill attacks!`, and
non-lethal hits should continue speaking full damage lines.
The user then reported a repeated `Bill attacks` line. Fresh logs showed the
same Red Slime hit announced three times because equivalent PPU render variants
looked different to overlap detection: `Hit . Points`, `been . reduced`, and
trailing `5. .`. `battle.normalize_dialogue()` now collapses isolated dot
tiles between words and duplicate punctuation-dot artifacts before fast-path
dedupe. Next useful live check with stronger enemies: repeated attack/damage
lines should be suppressed while each distinct round still speaks once.

Recently completed: user decision was to call Erdrick's Cave B2 done enough.
This cave chest is the only known required chest/interaction on that floor, and
both stairs-to-chest and chest-to-stairs are playable. Do not keep polishing B2
bounce candidates unless normal gameplay exposes a fresh blocker.

Morning route/verifier pass after the user ran stairs-to-chest first promoted
six more B2 directional seams from clean 5/5 direct verifier consensus:
`(6,5).west`, `(7,9).east`, `(7,7).north`, `(8,7).north`, `(4,7).south`, and
`(4,7).west`. Later walkthrough-guided loop testing briefly made
`(7,9).east` suspect because a same-batch raw-input/report run appeared to
cross west from the stairs. The latest route-shaped raw pass and fresh
`probe_edge_verify:8,9,LEFT,15` both stayed blocked, so `(7,9).east` is modeled
again. After the user enabled BizHawk auto-reload and reloaded for real,
validation exposed `(8,7).east`, which verified blocked 5/5, then exposed
`(2,6).east`, which verified blocked 10/10. Both are now promoted.

Reverse-route pass after the user teleported adjacent to the chest and routed
toward the stairs promoted six more clean 10/10 direct-verifier B2 seams:
`(9,5).north`, `(7,4).north`, `(6,4).north`, `(5,3).east`, `(5,2).east`, and
`(5,1).east`. Two route-observed seams remain intentionally unmodeled because
direct verification was mixed: `(8,5).north` from `(8,4)->DOWN` moved 2/10,
then 2/15 on a longer repeat, and `(7,4).east` from `(8,4)->LEFT` moved 1/10.
After the user reran chest-to-stairs, those exact exits failed naturally from
`(8,4)`. Fresh direct repeats promoted both: `(8,5).north` from
`(8,4)->DOWN` verified blocked 15/15, and `(7,4).east` from `(8,4)->LEFT`
verified blocked 15/15.

Latest left-edge investigation found the missing route shape. The generic
dungeon boundary rule was hiding the intended B2 loop along the west edge. The
current uncommitted patch now marks B2 passthrough cells `(0,1)`, `(0,2)`,
`(0,4)`, `(0,5)`, `(0,6)`, and `(0,7)`, and adds confirmed directional seams
from both the left-edge and upper-left reroute passes.

Live evidence for that patch:
- `(1,7)->LEFT` first verified passable 5/5 and a later raw hold from `(1,7)`
  ended at `(0,7)`. One later single `probe_edge` false-blocked from the same
  origin, so treat this edge as hidden-state noisy but route-shaped passable.
- From `(0,7)`, route-shaped probes moved north through `(0,6)`, `(0,5)`, and
  `(0,4)`. `(0,4)->RIGHT` moved to `(1,4)`.
- `(0,4)->UP` into `(0,3)` blocked, `(1,8)->LEFT` into `(0,8)` blocked 5/5,
  and `(1,9)->LEFT` into `(0,9)` was mixed 4 moved / 1 blocked, so those
  boundary cells intentionally remain unmodeled.
- After the left edge opened, `(1,4)->UP`, `(2,4)->UP`, and
  `(3,3)->RIGHT` each verified blocked 5/5 and are now modeled as directional
  seams. `(4,4)->UP` was mixed 1 moved / 4 blocked, and `(3,3)->UP` was mixed
  4 moved / 1 blocked, so both remain unmodeled.

Latest reroute investigation:
- The user reran stairs-to-chest after the left-edge patch. The route got deep
  into the upper-left loop, then failed from `(1,2)` after repeated blockers.
- Newly promoted directional seams: `(1,5).west`, `(4,4).west`,
  `(4,3).north`, `(5,2).west`, `(4,1).south`, `(3,1).south`,
  `(3,5).north/west`, `(2,3).east`, `(2,1).south`, and `(1,1).south`.
  Most came from queued-route blocks plus seam retries; `(1,1).south` then
  verified blocked 15/15 directly.
- A static leave-one-out graph check showed that the confirmed upper-left
  blockers require another narrow west-edge opening. Live
  `probe_edge_verify:1,2,LEFT,15` moved into `(0,2)` 15/15, and a forced-origin
  `probe_edge:UP` from `(0,2)` moved into `(0,1)`.
- The next real autowalk reached `(0,1)` and failed on `(0,1)->RIGHT` into
  `(1,1)`. Fresh `probe_edge_verify:0,1,RIGHT,15` confirmed `(1,1).west`
  blocked 15/15. Graph and live probes then found the top-edge continuation:
  `(0,1)->UP` into `(0,0)` verified passable 15/15, route-shaped probes moved
  right through `(1,0)` through `(6,0)`, downward entries into `(1,1)` through
  `(5,1)` blocked, and `(6,0)->DOWN` moved into `(6,1)`. The current patch adds
  B2 passthrough cells `(0,0)` through `(6,0)` plus the matching north-entry
  blockers for `(1,1)` through `(5,1)`.
- Static validation after the upper-left patch passed:
  `luac -p map_reader.lua test_map_reader.lua`, `lua test_map_reader.lua`
  (22 tests), and a local ROM-backed pathfinder run. The patched model now
  finds a 42-step route from B2 stairs `(8,9)` to chest-adjacent `(8,3)`,
  facing east.
- Live validation after reload: `inspect_tile:0,0` and `inspect_tile:6,0`
  both report `base_walkable=true walkable=true reason=passthrough`.
  `debug_pathfind_adjacent:9,3` from `(8,9)` chooses `(8,3)` with the 42-step
  route and `Face east`: `1 north, 1 east, 2 north, 3 west, 3 south,
  2 west, 1 north, 1 west, 1 north, 3 west, 3 north, 3 east, 2 north,
  3 west, 2 north, 6 east, 2 south, 2 east, 1 south`.
- Actual two-way proof after the user reran the route: stairs-to-chest queued
  43 steps for `Chest`, bounced at `(6,2)->RIGHT` into `(7,2)`, rerouted
  through `(6,3)`, and reached the chest. The return queued 29 steps for
  `Stairs Up to B1`, bounced through several route-learned dead branches, and
  still reached B2 stairs `(8,9)`.
- Return-trip bounce candidates observed in the successful run, not yet
  promoted as permanent data: `(1,3).north`, `(2,3).north`, `(2,6).north`,
  `(1,5).east/north`, `(2,8).north`, `(3,9).north`, `(7,9).west`, and
  `(7,7).west`. Treat these as optional direct-verifier cleanup targets.
- Current live state is `(8,9)`, `RUNTIME_BLOCKS map=0x1D none`, and
  `PATH_STATE target=nil`.

Latest loop investigation notes:
- External guide context agrees with the user's clue: Erdrick's Cave B2 is a
  normal loop to the tablet/chest, not a special-gated puzzle; torch is for
  visibility.
- `(9,5).south` was temporarily demoted after `probe_edge_verify:9,6,UP,10`
  produced mixed 2 moved / 8 blocked, but raw held UP from `(9,6)` stayed at
  `(9,6)` and a live auto-walk failed there. Restored `(9,5).south` as blocked.
- Latest route-shaped raw walk from the stairs reconfirmed the east-side and
  west-loop blockers already modeled: `(9,6)->UP`, `(8,6)->UP`, `(6,6)->UP`,
  `(5,4)->UP/RIGHT/LEFT`, `(4,8)->UP`, `(3,6)->LEFT/UP`, `(2,7)->UP`,
  `(1,7)->UP`, and the `(7,5)` north/west/east branches all stayed blocked.
- `(7,9).east` is restored as permanent data after a settled raw `LEFT,90`
  from `(8,9)` stayed at `(8,9)` and verifier evidence returned
  15 blocked / 0 moved. Post-reload `inspect_move:8,9,LEFT` reports
  `directional_blocked=true`, and `RUNTIME_BLOCKS map=0x1D none`.
- Do not trust same-command `simulate_raw_input:* report_position`; the report
  can run before queued raw input has played out. Split raw input and later
  `report_position` with a delay.
- Raw/teleport checks around the west loop are still hidden-state sensitive.
  The chest route is now playably validated in both directions. The next useful
  B2 work would only be optional cleanup of the return-trip bounce candidates
  with direct verifiers. The user has decided to move on now that the only
  required cave chest is reachable. Keep using the external visual/decoded map
  reference as orientation on future maps, but live movement remains the source
  of truth.

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

BizHawk 2.11.1 side-install note:
- Installed official `BizHawk-2.11.1-win-x64.zip` side by side at
  `D:\emulation\bizhawk-2.11.1` / `/mnt/d/emulation/bizhawk-2.11.1`.
- The existing `D:\emulation\bizhawk` 2.10 install was left untouched.
- Version check:
  `EmuHawk.exe` reports `FileVersion 2.11.1.0` and
  `ProductVersion 2.11.1+bdddf4a58aa1a022afb11dc73294a81a5aa7bbd5`.
- Test with:
  `./launch_dw.sh --bizhawk-path /mnt/d/emulation/bizhawk-2.11.1/EmuHawk.exe`.
- Dry-run confirmation resolved to
  `D:\emulation\bizhawk-2.11.1\EmuHawk.exe` with the normal ROM and
  `main.lua` arguments.

BizHawk 2.11.1 bulk PPU-read experiment status:
- Implemented an experimental `ppu.readbyterange(address, length)` path in
  `emulator_compat.lua`. When BizHawk exposes
  `memory.read_bytes_as_binary_string` or `memory.read_bytes_as_array`, the
  adapter reads contiguous nametable/CIRAM spans through one bulk memory call
  and populates the existing within-frame PPU cache. It falls back to the old
  byte loop when bulk APIs are unavailable.
- `text.lua`, `menu.lua`, and `merchant.lua` now request contiguous PPU row or
  row-span reads, preserving byte-loop fallback for FCEUX/older runtimes.
- `scan_profiler.lua` now includes `bulk_reads` and `bulk_bytes` in
  `PPU_STATS`, so a real live reload should make bulk use obvious in logs.
- Static validation passed:
  `luac -p emulator_compat.lua scan_profiler.lua text.lua menu.lua merchant.lua main.lua test_emulator_compat.lua`,
  `lua test_emulator_compat.lua`, `lua test_text.lua`, `lua test_menu.lua`,
  `lua test_merchant.lua`, `lua test_hotkeys.lua`, and `git diff --check`.
- Live caveat: WSL/PowerShell timestamp nudges did not actually reload the
  current BizHawk Lua script; the old `report_scan_stats` command closure kept
  logging the pre-patch `PPU_STATS` format with no `bulk_reads`. A real Lua
  Console script reload or close/relaunch of BizHawk 2.11.1 is needed before
  judging the experiment.
- Live result after enabling BizHawk auto-reload and reloading manually:
  `report_scan_stats` now shows the new `PPU_STATS` fields. A 2,280-frame
  Brecconary sample logged `bulk_reads=46482`, `bulk_bytes=1290432`, proving
  the bulk path is active. Compared with the earlier 2.11.1 idle profile,
  average costs improved: `check_yesno_prompt 3.566ms -> 1.246ms`,
  `check_merchant_screen 1.823ms -> 0.302ms`, `check_dialogue 1.119ms ->
  0.337ms`, `check_upper_dialogue 0.790ms -> 0.254ms`, and
  `check_command_menu 1.499ms -> 1.126ms`. Recording was stopped after the
  sample at frame `08340`.
- Follow-up lag attribution test: in Brecconary, `pathability_filter:refresh`
  from `(1,15)` over 21 objects took `59ms` and logged matching
  `CMD_TIMING`; scan profiling put the spike in `debug_tools.tick max_ms=60`
  while `objects.check_refresh` stayed `0ms`. Selected `Guard 2` at `(4,8)`;
  `pathfind` planned a 9-step route to `(4,9)` without hitting the 25ms route
  timing threshold, and `auto_walk` completed the 9 steps with normal 23-28
  frame moves, no timeout/retry reroute, then faced/held the guard. Current
  player position after the test is `(4,9)`.
- Object pathability refresh now builds one reachable-cell set for the current
  map/start/blocking context and classifies all objects against that set,
  instead of running one A* search per object. Static tests confirm the batch
  path no longer calls per-object pathfinding and still refreshes immediately
  when the player's position changes. Live reload proof:
  `LAUNCHER_PROBE: codex_pathability_flood` at frame 60; from Brecconary
  `(4,9)`, `pathability_filter:refresh` over 21 objects returned normally and
  emitted no `OBJECT_PATHABILITY_TIMING` or `CMD_TIMING` warning, meaning it
  stayed under the existing 25ms log threshold. This is not a perfect
  apples-to-apples comparison with the old `(1,15)` 59ms sample, but it removes
  the identified per-target A* cost center.
- Manual reroute-lag follow-up: user noticed a lag spike during reroute while
  traveling from Merchant 2 toward the Brecconary exit. Log evidence showed
  queued auto-walk timing out on `(5,13)->LEFT` into `(4,13)`, publishing
  `SEAM_OBSERVATION map=0x08 cell=(4,13) approach=east result=blocked`, then
  rerouting successfully via `(5,12)`. `map_reader.lua` now models Brecconary
  `(4,13)` with `{east=true}`. Live reload proof:
  `LAUNCHER_PROBE: codex_brec_413_block`; a path-only probe from `(5,6)` to
  adjacent `(0,15)` chose `3 south, 1 west, 3 south, 2 west, 2 south, 1 west,
  1 south`, avoiding the old `(5,13)->LEFT` timeout. Player was restored to
  Brecconary `(1,15)` afterward.
- Brecconary inn/service route follow-up: the old `Merchant 3` service entry
  targeted `(9,21)`, which TALK can use but which is directionally blocked from
  the public west approach. Live proof from `(1,15)` showed `pathfind_to:9,21`
  failed while `pathfind_to:8,21` succeeded; a controlled TALK probe from
  `(8,21)` facing east opened the inn dialogue. `objects.lua` now labels
  Merchant 2 as `Weapons Merchant`, labels Merchant 3 as `Inn`, and routes the
  inn to `(8,21)` facing east. The first retest exposed a real timeout on
  `(7,17)->RIGHT` into `(8,17)`, so `map_reader.lua` now blocks `(8,17)` from
  the west. Live reload proof: `LAUNCHER_PROBE: codex_inn_edge_reload`, then
  `auto_walk` from Brecconary `(1,15)` queued 17 steps for `Inn`, reached
  `(8,21)`, and logged `AUTO_WALK_FACE target=Inn face=east` with no new
  blocked edge. Player was restored to `(1,15)`.
- Level-3 spell menu follow-up: after learning Heal, selecting `SPELL` opened a
  list that was silent because `main.lua` only tracked `STATUS` and `ITEM`
  submenus. Live `report_menu_state` while in the spell list showed
  `raw_open=true`, speech ready, `cursor=(0,0)`, no lower/upper text, and
  `submenu=nil`, meaning this was a missing submenu mode rather than a speech
  backend failure. `items.lua` now exposes known-spell list helpers and
  `main.lua` tracks `submenu=SPELL`. The game screen only shows the spell name
  (`>HEAL`) plus the separate current-MP status panel, not per-spell costs, so
  speech adds NES MP costs from spell metadata. Entry/cursor speech now says
  entries such as `Spells. Heal. 4 MP`; later spell-list movement speaks the
  selected spell with its cost. A follow-up reload suppressed the first
  synthetic cursor jump so entry no longer double-speaks. Live proof:
  `LAUNCHER_PROBE: codex_spell_menu_dedup_reload`; after backing out and
  re-entering SPELL, `speech_bridge.log` recorded one `speak:Spells. Heal`.
  Cost follow-up proof: `LAUNCHER_PROBE: codex_spell_cost_reload`; re-entering
  SPELL recorded `speak:Spells. Heal. 4 MP`, `MENU_STATE` reported
  `submenu=SPELL`, and `speech_status` was ready with `error=none`.

## Current Baseline

2026-05-10 Erdrick's Cave B2 first chest-route investigation:
- User reached brand-new map `0x1D` / Erdrick's Cave B2 and selected the only
  visible chest at `(9,3)`. Auto-walk planned routes but repeatedly gave up
  because B2 had no permanent directional seam model yet; decoded cave floor
  tiles looked walkable while the engine blocked one-way maze approaches.
- Direct verifier-confirmed B2 seam data has been promoted to `map_reader.lua`
  as directional-only blockers: `(5,3).south`, `(6,4).west`,
  `(6,5).east/south`, `(7,4).south`, `(8,5).west/south`, `(9,5).south`,
  `(1,6).south`, `(2,6).south`, `(5,8).south/east`, and `(7,8).west`. These
  are all `probe_edge_verify` 5/5 blocked results; a first mixed `(6,6)->UP`
  result was not promoted until a later verifier pass returned clean 5/5
  blocked. A later route-observed `(4,7).west` and `(2,6).east` were checked
  directly and came back mixed, so they remain unmodeled.
- Final focused verifier pass from the stairs/chest churn added
  `(3,5).south`, `(4,4).east`, `(4,5).east`, `(4,6).east/west`,
  `(5,7).north/east`, `(5,8).west`, `(7,8).east`, and `(8,7).south`.
  Additional route-observed `(6,5).west` and `(4,7).south` came back mixed
  under direct verification and were not promoted.
- Morning follow-up after a normal stairs-to-chest route promoted six more
  clean direct-verifier seams: `(6,5).west`, `(7,9).east`, `(7,7).north`,
  `(8,7).north`, `(4,7).south`, and `(4,7).west`. After the user enabled
  BizHawk auto-reload and reloaded for real, validation exposed `(8,7).east`,
  which verified blocked 5/5, and then `(2,6).east`, which verified blocked
  10/10. Both are now modeled.
- Reverse-route follow-up from chest side toward stairs promoted six more clean
  10/10 verifier seams: `(9,5).north`, `(7,4).north`, `(6,4).north`,
  `(5,3).east`, `(5,2).east`, and `(5,1).east`. Route-observed
  `(8,5).north` and `(7,4).east` stayed mixed under direct verification and
  remain unmodeled.
- Final static validation passed after the reverse-route B2 pass:
  `luac -p map_reader.lua test_map_reader.lua`, `lua test_map_reader.lua`,
  and `git diff --check`.
- Live reload proof after auto-reload was enabled: `LAUNCHER_PROBE:
  codex_b2_87east_reload` and `LAUNCHER_PROBE: codex_b2_26east_reload`.
  Reverse-route reload proof: `LAUNCHER_PROBE: codex_b2_reverse_edges`.
  Runtime B2 blocks were cleared afterward and `RUNTIME_BLOCKS map=0x1D none`
  reported, with the player restored to chest-side `(8,3)` and
  `PATH_STATE target=nil`.
- Caveat: this is still a partial B2 decode, not a full map solve. The current
  disk model finds no stairs-to-chest route. From chest-side `(8,3)`, it can
  plan back to stairs `(8,9)`, but the route depends on mixed seam
  `(8,5).north`; the next useful work is targeted bridge/region investigation
  rather than treating this as a normal player-facing chest route.
- Later left-edge investigation found the missing route shape: B2 needs narrow
  west-edge passthrough cells `(0,4)` through `(0,7)`, plus new directional
  blockers `(1,3).south`, `(2,3).south`, and `(4,3).west`. Static tests pass
  and a local patched-model pathfinder run reaches chest-adjacent `(8,3)` from
  stairs `(8,9)` in 30 steps. Live BizHawk still needs a real Lua reload before
  that patch can be judged in-emulator; timestamp nudges only proved the old
  script loop was still consuming commands.

2026-05-09 Brecconary autowalk stress survey:
- User returned to Brecconary and stood at the town entrance. The entrance tile
  `(0,15)` is a transition/isolated tile, and `(1,15)` still trips the survey
  `low_exit_count` guardrail, so the stress survey was launched from the open
  interior seed `(15,15)` with `survey_objects:park_npcs`.
- Survey run `2` completed on map `0x08`: `targets=21`, `successes=7`,
  `failures=14`, `gated_or_isolated=8`, `state_issues=6`,
  `suspected_engine_blocked=0`, and `strong_reroute_candidates=0`.
  Post-run checks showed `PATH_STATE target=nil map=0x08 runtime_count=0`,
  `RUNTIME_BLOCKS map=0x08 none`, `SURVEY_STRONG_CANDIDATES map=0x08 none`,
  and player position `(10,25)`.
- The six `command_timing_or_state_issue` failures were traced to survey routes
  performing normal post-arrival actions: `AUTO_WALK_FACE` and target-NPC hold
  fired after a successful route, then the next survey target started on the
  next frame and auto_step saw that synthetic facing input as
  `live_input_interrupt`. This is autowalk orchestration noise, not map data.
- `route_manager.lua` now treats `survey_safe` autowalks as silent
  post-arrival routes: no target-facing input, no target NPC hold, and no
  normal completion speech. Normal player autowalk still faces/holds/speaks
  after arrival. Regression coverage was added in `test_route_manager.lua`.
  Static checks passed: `lua test_route_manager.lua`, `lua test_auto_step.lua`,
  `lua test_map_survey.lua`, and `git diff --check` (with the existing
  `dw_access.ini` CRLF warning).
- Fresh rerun after the survey-safe patch completed with `targets=21`,
  `successes=12`, `failures=9`, `gated_or_isolated=7`,
  `suspected_engine_blocked=2`, and `state_issues=0`. The two suspects split
  cleanly under direct verifier:
  `probe_edge_verify:5,2,DOWN,5` confirmed `(5,3).north` blocked 5/5, while
  `probe_edge_verify:19,14,RIGHT,5` confirmed `(20,14).west` passable 5/5.
  `map_reader.lua` now models Brecconary `(5,3).north`; after reload
  `inspect_move:5,2,DOWN` reports `directional_blocked=true` and
  `report_runtime_blocks:0x08` reports none.
- `map_survey.lua` now downgrades orphaned-route blocker claims when the hero
  actually lands on the suspected tile before `route_inactive_without_completion`.
  That covers the false Old Man 1 `(20,14)` report without weakening real
  `reroute_no_path` blocker evidence. Regression coverage was added in
  `test_map_survey.lua`.
- Follow-up survey after reload was materially contaminated by two
  `route_drift_retry` events, not map geometry. The first was Old Man 1:
  `(7,12)->UP` completed at `(7,11)`, then stale/continued movement put the
  hero at `(7,10)` during route settle. The second was Person 4:
  `(2,12)->DOWN` completed at `(2,13)`, then drifted to `(2,14)`. Because
  route-drift retries were appended to the survey tail, seven later targets
  were attempted from the stranded `(7,10)` start and became bogus
  `gated_or_isolated` failures. Current run summary was therefore
  `successes=13 failures=8`, but the `start=(7,10)` failure cluster should not
  be interpreted as map data.
- `map_survey.lua` now inserts `route_drift_retry` and
  `timing_orphaned_route` retries immediately after the failed target instead
  of appending them after the rest of the object queue. `auto_step.lua` also
  avoids queued-route early-twitch holding after a timeout retry; this targets
  the exact overshoot pattern where a retry press lands on the next tile within
  8 frames and can commit one extra tile. Regression coverage was added in
  `test_map_survey.lua` and `test_auto_step.lua`. Live reload proof:
  `LAUNCHER_PROBE: codex_drift_retry_patch`, followed by
  `POSITION: map=0x08(Brecconary) x=10 y=25` and
  `RUNTIME_BLOCKS map=0x08 none`.
- Fresh user-run parked-NPC survey from `(15,15)` completed as run `1` on
  map `0x08`: `targets=21`, `successes=10`, `failures=11`,
  `gated_or_isolated=9`, `state_issues=2`, and
  `suspected_engine_blocked=0`. Follow-up live checks showed
  `POSITION: map=0x08(Brecconary) x=10 y=25`,
  `PATH_STATE target=nil map=0x08 runtime_count=0`, and
  `RUNTIME_BLOCKS map=0x08 none`.
- The two remaining state issues are still route timing/orchestration, not
  map data. `Guard 2` briefly marked `(15,17).west` blocked, then immediately
  brute-forced into `(15,17)`, so the harness downgraded it to
  `command_timing_or_state_issue`. `Old Man 1` drifted off the queued route
  from `(18,18)` to `(16,18)` during route settle, retried immediately, then
  hit a target-NPC adjacency problem (`NO_PATH_STATIONARY_NPC`) rather than a
  hidden wall. The one runtime reroute at `(9,15).west` was noisy and recovered;
  no runtime blocks persisted.
- Follow-up queued-route timing patch is live and validated. `auto_step.lua`
  now keeps queued-route input held through early movement-subpixel twitches,
  uses a shorter configured timeout after a turn re-press twitch, and marks
  those reports as `timing_suspect` so survey does not promote them as map
  candidates. `route_manager.lua` now publishes `route_completed` when a
  seam-bruteforce retry lands exactly at the adjacent goal. Regression coverage
  was added in `test_auto_step.lua`, `test_route_manager.lua`, and
  `test_map_survey.lua`.
- Live proof after reload `LAUNCHER_PROBE: codex_timing_ignore_reload`: from
  Brecconary `(15,15)`, `survey_target:Exit,park_npcs` hit the same early
  twitch/turn-repress path repeatedly, logged `SURVEY_TIMING_BLOCK_IGNORED`
  plus `AUTO_WALK_TIMING_RETRY`, reached `(1,15)`, and recorded
  `movement_succeeded=true`, `blocked_events=0`, `suspected_tiles=-`,
  `failure_class=none`, `reason=route_completed`. Final checks showed
  `RUNTIME_BLOCKS map=0x08 none` and `POSITION map=0x08 x=1 y=15`.
- Latest user-run parked-NPC Brecconary survey from `(15,15)` is cleaner but
  still not a map-data patch candidate. Run `1` on map `0x08` completed with
  `targets=21`, `successes=13`, `failures=8`, `no_route=0`,
  `gated_or_isolated=8`, `movement_failed=0`,
  `suspected_engine_blocked=0`, `state_issues=0`, and
  `adjacency_issues=0`. Failure starts were `(28,2)` for four targets
  (`Guard`, `Merchant`, `Person`, `Weapons Merchant`), `(17,16)` for two
  targets (`Old Man 2`, `Person 5`), `(1,2)` for `Inn`, and `(24,7)` for
  `Woman 1`. Every failed `SURVEY_RESULT` had `blocked_events=0` and
  `suspected_tiles=-`; follow-up reports showed
  `SURVEY_STRONG_CANDIDATES map=0x08 none`,
  `SURVEY_FINDINGS ... failed_targets=8 failure_starts=4
  strong_reroute_candidates=0`, and `RUNTIME_BLOCKS map=0x08 none`. The log
  did contain `118` `SURVEY_TIMING_BLOCK_IGNORED` /
  `AUTO_WALK_TIMING_RETRY` pairs, so route timing remains noisy even though the
  survey now classifies that noise without promoting false blockers.
- Follow-up tuning attempt did not leave a new timing patch. Focused live
  repro was `survey_target:Exit,park_npcs` from Brecconary `(15,15)`.
  Extending queued-route early-twitch holding removed route-level timing
  retries briefly, but chained extra tiles and caused `route_drift_off_path`
  around `(7,15)`/`(7,17)`. Moving the first timing retry inside `auto_step`
  kept queued-route state stuck long enough to become normal blocked events.
  Narrowing the early-twitch grace and widening the turn-repress timeout still
  produced the same every-other-tile `AUTO_WALK_TIMING_RETRY` pattern on the
  westbound exit route. Those experimental changes were reverted. The useful
  clue is that queued-route steps from even x-coordinates on the westbound
  path often see `0x00->0x90` subpixel twitches and time out, while the direct
  seam retry from the same tile succeeds quickly after a fresh inject. Next
  timing work should investigate why queued-route retry state behaves
  differently from `inject_step`/seam-bruteforce state, rather than only tuning
  grace/timeout thresholds.
- Survey/manual autowalk comparison found one real survey-data skew and one
  remaining timing concern. Before the fix, manual Services autowalk to the
  Brecconary `Inn` from `(15,15)` used the service counter target `(8,21)`,
  queued `13` steps, hit one `AUTO_WALK_TIMING_RETRY`, and arrived with
  `RUNTIME_BLOCKS map=0x08 none`; `survey_target:Inn` copied only
  `id/name/type/x/y`, lost `interaction_x/y/face_dir`, and therefore tried raw
  adjacent routing to the innkeeper at `(10,21)`, producing a false no-path.
  `map_survey.copy_object()` now preserves `service`, `interaction_x`,
  `interaction_y`, and `interaction_face_dir`, with regression coverage in
  `test_map_survey.lua`. Live proof after reload
  `LAUNCHER_PROBE: ab_service_copy_reload`: `survey_target:Inn` from
  `(15,15)` now logs `mode=direct path_length=13`, succeeds at final `(8,21)`,
  and reports `blocked_events=0`, `RUNTIME_BLOCKS map=0x08 none`. That fixed
  route still logged five timing retries / five
  `SURVEY_TIMING_BLOCK_IGNORED` entries and two `route_settle_catchup` lines,
  so survey data is no longer losing the service target, but survey-safe
  settle timing remains noisy and worth later tuning. A static code check also
  confirmed survey-safe exits/stairs intentionally route adjacent while manual
  `auto_walk` routes direct to walkable exits/stairs, so exit comparisons are
  not apples-to-apples unless the goal mode is specified.
- Catchup-noise follow-up kept the service-target fix and narrowed the survey
  settle behavior. An abandoned branch that delayed queued-route re-press after
  early movement twitches could finish at the wrong tile, so it was not kept.
  `auto_step.lua` now cancels a queued route as `route_drift_off_path` if a
  step lands somewhere other than the injected direction would allow, and
  survey-safe routes now skip the long settle between same-direction straight
  steps while retaining it for direction changes. Live reload
  `LAUNCHER_PROBE: catchup_straight_settle_reload`; `survey_target:Inn` from
  `(15,15)` succeeded at `(8,21)` with `blocked_events=0`,
  `RUNTIME_BLOCKS map=0x08 none`, `route_settle_catchup=0`, and four
  `AUTO_WALK_TIMING_RETRY` / `SURVEY_TIMING_BLOCK_IGNORED` pairs. That is an
  improvement over the previous fixed-Inn proof's five retry pairs plus two
  catchups, and it did not skew the route target or survey result.
- Player-facing Inn autowalk route-drift follow-up: after the catchup tuning,
  a live route from the Brecconary entrance `(0,15)` to `Inn` canceled at
  `(2,15)` as `route_drift_off_path`. The drift guard was correct; the executor
  had held through an early first-step movement twitch and then scheduled a
  same-direction turn re-press, which committed an extra right tile during the
  planned right-to-down settle. `auto_step.lua` now treats early queued-route
  movement twitches as timing-suspect short timeouts/direct retries but does
  not schedule the same-direction turn re-press while the hold-through-grace
  path is active. Live proof `LAUNCHER_PROBE: route_twitch_patch_inn_repro`:
  from `(0,15)`, player-facing `auto_walk` to `Inn` reached `(8,21)` and
  logged `AUTO_WALK_FACE target=Inn face=east`; final checks showed
  `PATH_STATE target=nil`, `RUNTIME_BLOCKS map=0x08 none`, and no route-drift
  lines. One `AUTO_WALK_TIMING_RETRY` remains on the first twitchy step, but it
  no longer skews the route.
- Follow-up player-facing drift while routing from `Merchant 1` to
  `Weapons Merchant`: log showed `AUTO_WALK` from `(2,14)` queued 11 steps,
  timed out the first `(2,14)->RIGHT` early-twitch step at frame 24, then
  seam-bruteforce retried right. The retry landed at `(3,14)` in one frame,
  but the immediate follow-up `UP` step saw residual right movement carry the
  hero to `(4,14)`, so the drift guard canceled with
  `source=auto_hold_mismatch`; later status was `(4,13)`,
  `PATH_STATE target=nil`, and `RUNTIME_BLOCKS map=0x08 none`. This is
  executor timing, not map data. Worktree patch separates early-twitch timeout
  from turn-repress timeout: `auto_step_route_turn_repress_timeout_frames`
  stays `24`, while new `auto_step_route_early_twitch_timeout_frames=32`
  lets a real in-progress tile finish before injecting a seam retry. After the
  user reloaded the Lua script, live proof `LAUNCHER_PROBE:
  weapons_drift_patch_live` from `(2,14)` reached `Weapons Merchant` and logged
  `AUTO_WALK_FACE target=Weapons Merchant face=north`; the first timing retry
  now reported `timeout=32`. A second live proof
  `LAUNCHER_PROBE: inn_entrance_patch_live` force-started from the entrance
  `(0,15)`, reached the inn stand tile `(8,21)`, and logged
  `AUTO_WALK_FACE target=Inn face=east`. The fresh post-reload log contains no
  `clear_route`, `route_drift`, or `auto_hold_mismatch` lines. Final status was
  `POSITION map=0x08 x=8 y=21`, `PATH_STATE target=nil`, and
  `RUNTIME_BLOCKS map=0x08 none`.
- Weapons-merchant item-list follow-up: after the clean route, TALK/YES reached
  the shop prompt but the item list was silent. The pre-fix report at frame
  `40020` showed speech was ready and lower text contained the merchant prompt,
  but `MERCHANT_STATE active=false` and the fixed merchant row reader dumped no
  item rows. Root cause was scroll context: at the Brecconary weapon counter the
  shop overlay is vertically scrolled (`dialogue_start_row=25`, so merchant
  visual rows need `vertical_scroll_tiles=6`), and BizHawk reported
  `base_nt=1` while the text was in the alternate base order. `merchant.lua`
  now supports ordered screen-context fallbacks, and `main.lua` passes fixed,
  live, and live-alt-base contexts to merchant scans and cursor reads. Live
  reload proof `LAUNCHER_PROBE: merchant_context_reload` reported
  `MERCHANT_STATE active=true ... context=live_alt_base context_scroll=30
  context_base=0 context_vertical=6`, recovered all six offers, and spoke
  `Merchant. Gold 44. Club. 60 gold.` A down/up cursor pulse then spoke
  `Copper Sword. 180 gold.` and `Club. 60 gold.`, leaving the cursor back on
  Club.
- Overworld route replacement/recalculation follow-up: player testing found
  that once a route was active, pressing `R` only reported the old route and
  never calculated a route to a newly selected Travel destination. The route
  decision now lives in `overworld_routes.guidance_for_object()`: selecting a
  different guided Travel destination replaces the active route, selecting the
  same destination recalculates from the current world-map position, and
  pressing `R` on an active route waypoint recalculates/statuses the current
  route so large drift can recover to the best next marker. While movement is
  unstable, `R` remains read-only status and will not replace/recalculate the
  active route until object controls are stable. Command-file helpers now
  include `route_recalculate` and `recalculate_overworld_route`;
  `stop_overworld_route` remains the explicit cancel command. Static
  validation passed: `luac -p overworld_routes.lua hotkeys.lua
  object_commands.lua test_overworld_routes.lua test_hotkeys.lua`,
  `lua test_overworld_routes.lua`, `lua test_hotkeys.lua`, and
  `lua test_objects.lua`.

2026-05-08 Erdrick's Cave B1 first-floor cleanup in the worktree:
- Dungeon/cave object browsing no longer accepts stale town NPC RAM. Live
  proof after reload `LAUNCHER_PROBE: codex_dungeon_npc_fix` showed
  `POSITION: map=0x1C(Erdrick's Cave B1) x=0 y=0`, with exactly two objects:
  `Exit to World Map` at `(0,0)` and the old hard-coded
  `Stairs Down to B2` at `(1,1)`. The NPC filter reported `No objects`.
- Live stairway probes confirmed the cave entrance strip is walkable even
  though the decoded tile type is 9 and the old generic boundary rule rejected
  it: `(0,0)->RIGHT` moved to `(1,0)`, `(1,0)->DOWN` moved to `(1,1)`,
  `(1,1)->UP` moved back to `(1,0)`, and `(1,0)->LEFT` moved back to `(0,0)`.
  `map_reader.lua` now models `(0,0)` and `(1,0)` on map `0x1C` as scoped
  passthrough cells and lets passthroughs override the generic interior
  x/y-zero boundary in both direct tile checks and walkability snapshots.
- Live validation after reload `LAUNCHER_PROBE: codex_cave_snapshot_patch`:
  `pathfind_to:1,1` from `(0,0)` now returns `Path: 1 east, 1 south`, and
  `report_survey_start` reports `targets=2`, `reachable_area=83`,
  `open_exits=east`, and `status=viable`.
- Survey battle-interruption safety is now implemented. If `battle_started`
  fires during a survey, `map_survey.lua` cancels the active auto-walk route,
  clears route context, logs `SURVEY_PAUSE reason=battle_started`, keeps the
  interrupted target queued, and resumes it when `can_walk` becomes true again.
  This prevents random encounters from becoming bogus `SURVEY_RESULT` failures
  or blocked-tile candidates. If combat ends on a different map, the survey
  aborts rather than continuing with contaminated context.
- Targeted B1 surveys are clean enough to proceed. Starting surveys directly
  from `(0,0)` hit the expected `low_exit_count` guardrail, so `(2,2)` is the
  current interior survey seed: `report_survey_start` from there reports
  `reachable_area=83` and `open_exit_count=4`. `survey_target:Exit` succeeded
  for `Exit to World Map`. The earlier `survey_target:Stairs` success only
  proved that the route could reach the old modeled coordinate, not that the
  coordinate was correct: standing at `(1,1)` and selecting STAIRS produced
  `'There are no stairs here.`
- Erdrick B1/B2 stair coordinates are corrected in `objects.lua`. The ROM
  stair-down table contains `1C 09 09`, and live proof from `(9,9)` selecting
  STAIRS changed to `map=0x1D(Erdrick's Cave B2)` with landing `(8,9)`.
  Returning from B2 `(8,9)` via STAIRS changed back to `map=0x1C` with landing
  `(9,9)`. `Stairs Down to B2` is now `(9,9)` and `Stairs Up to B1` is now
  `(8,9)`. Live reload proof `LAUNCHER_PROBE: codex_erdrick_stairs_fix` then
  `current_object` at B1 `(9,9)` reported
  `Stairs Down to B2: here (1 of 2) [player 9,9 obj 9,9]`.
- The survey route briefly marked `(2,1)` from the south and `(1,2)` from the
  east as blocked/noisy, but direct probes from `(2,2)` with `probe_edge:UP`
  and `probe_edge:LEFT` both moved successfully, so do not promote those to
  permanent map data. `RUNTIME_BLOCKS map=0x1C none`. Current live position
  after the stair confirmation is `(9,9)` on B1.
- Full B1 route passes exposed real directional maze seams, with no
  `EVENT: battle` / `battle_started` log entries. Direct `probe_edge` checks
  after clearing runtime blocks confirmed the pre-regression approaches:
  `(3,3)` from north/south, `(4,3)` from north/south, `(2,4)` from east/west,
  `(3,5)` from north, `(7,2)` from west, `(6,3)` from north, `(1,5)` from
  north, `(6,6)` from west, `(5,7)` from north, `(8,8)` from north/west, and
  `(8,9)` from west. `map_reader.lua` models them as directional-only blocks
  for map `0x1C`.
  Reload proofs: `LAUNCHER_PROBE: codex_b1_route_blocks`,
  `codex_b1_more_seams`, `codex_b1_upper_seams`, `codex_b1_top_verticals`,
  and `codex_b1_logpass_edges`.
- A later B1 pass got worse after four newer one-probe additions and produced
  many reroutes plus contaminated runtime blocks. Those newest additions are
  rolled back for now: `(4,3)` from east, `(4,1)` from south, `(6,3)` from
  west, and `(6,6)` from north. Route-only blocked observations now remain
  seam-memory evidence and no longer promote into hard `runtime_blocked` map
  facts. Use `probe_edge_verify:DIR[,N]` or
  `probe_edge_verify:X,Y,DIR[,N]` before re-promoting any suspect B1 edge.
  The verifier resets movement state between attempts and only reports
  `confirmed_blocked` / `confirmed_passable` when every attempt agrees.
  Static tests pass. The stale live Lua loop was relaunched during this check;
  the current emulator is on the title screen (`map=0x00`) after
  `LAUNCHER_PROBE: codex_relaunch_probe`, and the command-surface check from
  title refused cleanly. A live field-edge verifier run is still needed after
  restoring gameplay state.
- Follow-up after manual reload: both B1 entrance/stairs routes can eventually
  succeed, but the live log still shows engine-collision sounds as soft seam
  observations. The latest clean route to stairs hit blocked-only route evidence
  at `(2,1)` from west, `(2,3)` from west/north, `(6,3)` from west,
  `(6,4)` from west, and `(6,6)` from north; it then recovered and reached
  `(9,9)` with `RUNTIME_BLOCKS map=0x1C none`. Do not promote these from route
  evidence alone.
- `probe_edge_verify:X,Y,DIR,N` was adjusted so explicit-coordinate verifier
  calls relocate to the origin themselves instead of requiring a separate
  `teleport_to` command. `luac -p main.lua` and `git diff --check` pass.
  Live verification is still blocked because the Lua command loop stalled after
  `report_runtime_blocks` at frame `07620`: BizHawk remains responsive, but
  `dw_debug.log` stops advancing and a queued
  `launcher_probe:codex_probe_after_missing_cmd` remains in `dw_commands.txt`.
  After a fresh manual reload/relaunch, test with single commands such as
  `probe_edge_verify:6,5,DOWN,5`, `probe_edge_verify:5,4,RIGHT,5`, and
  `probe_edge_verify:5,3,RIGHT,5`.
- Latest B1 route validation: from entrance `(0,0)`, `pathfind_to:9,9`
  planned `Path: 1 east, 2 south, 4 east, 2 south, 3 east, 2 south, 1 east,
  3 south`; auto-walk to `Stairs Down to B2` reached `(9,9)` and ended with
  `RUNTIME_BLOCKS map=0x1C none`. The route still produced a one-off blocked
  observation at `(6,4)` from the west, but direct probe `(5,4)->RIGHT` moved
  successfully, so do not promote it. Also keep `(5,1)` from south, `(2,1)`
  from east/south/west, and `(2,3)` from north/west unpromoted; direct probes
  moved through those logged approaches.
- Latest diagnostic follow-up after manual reload: auto-walk from B1 entrance
  to `Stairs Down to B2` reached `(9,9)` again, but produced six route-only
  blocked auto-step events: `(2,1)` from west, `(2,3)` from west and north,
  `(6,3)` from west, `(6,4)` from west, and `(6,6)` from north. Current-state
  reports after a fresh `launcher_probe:codex_b1_after_reroutes` showed
  `PATH_STATE target=nil map=0x1C runtime_count=0`,
  `RUNTIME_BLOCKS map=0x1C none`, and
  `SEAM_SUMMARY map=0x1C total=26 confirmed_blocked=0 noisy=0 blocked_only=6
  passable_only=20`. This confirms the soft-seam gate is working: route-only
  collisions are not contaminating hard runtime blockers.
- The first live `probe_edge_verify:1,1,RIGHT,3` retest still wedged the Lua
  command loop before any verifier lines reached `dw_debug.log`; a later
  `report_position` remained queued in `dw_commands.txt`, and
  `dw_script_error.log` had no fresh entry. `debug_tools.lua` now flushes the
  `CMD:` marker immediately before and after command handlers, and
  `main.lua` makes `probe_edge_verify` log-only, defers the first verifier
  movement out of the command callback, and wraps `tick_edge_probe` /
  `tick_edge_verify` in `checked_call` so future verifier failures leave either
  `EDGE_VERIFY_*` evidence or a `dw_script_error.log` entry. Static validation:
  `luac -p main.lua debug_tools.lua`, `lua test_route_manager.lua`,
  `lua test_map_reader.lua`, `lua test_auto_step.lua`, and `git diff --check`
  all pass.
- Live reload note: after the verifier logging patch, `touch main.lua` plus
  `launcher_probe:codex_verifier_patch_reload` successfully reloaded the
  patched script and consumed the command at frame `00060`; `dw_commands.txt`
  is empty and `dw_script_error.log` has no fresh entry. The active state was
  `title`, so B1 edge verification still needs to wait until gameplay is back
  on Erdrick's Cave B1.
- At that point, the best next step was to run a single verifier such as
  `probe_edge_verify:1,1,RIGHT,3` and wait for either `EDGE_VERIFY_RESULT` or a
  fresh script-error entry. If that produces useful output, verify the
  remaining soft B1 route-only edges before moving on to B2; otherwise debug
  the verifier loop itself before trusting further probe data.
- Follow-up verifier crash from the first B1 retry is fixed in the worktree:
  `dw_script_error.log` reported
  `tick_edge_verify: [string "main"]:582: attempt to call a nil value (global
  'get_autowalk_unavailable_reason')`. Cause: `tick_edge_verify` is defined
  before the local guard function, so Lua resolved it as a nil global. `main.lua`
  now forward-declares `get_autowalk_unavailable_reason` before the verifier
  helpers and assigns the existing guard body later. Validation passed:
  `luac -p main.lua debug_tools.lua`, `lua test_route_manager.lua`,
  `lua test_auto_step.lua`, and `git diff --check`. A reload probe attempted
  after the patch timed out because the running script was already stopped by
  the old crash; `dw_commands.txt` has been cleared. Manually reload/relaunch
  before retrying `probe_edge_verify:1,1,RIGHT,3`.
- Live verifier follow-up after manual reload: the script no longer crashed.
  The first `probe_edge_verify:1,1,RIGHT,3` completed as `classification=mixed`
  with `moved=1 blocked=2`, so it correctly avoided runtime promotion. A later
  same-edge retry completed `confirmed_blocked` with `moved=0 blocked=3` and
  `runtime_added=true`. Additional soft-edge checks produced:
  `(1,3)->RIGHT` into `(2,3)` confirmed blocked 3/3 and added runtime,
  `(2,2)->DOWN` into `(2,3)` mixed 1/2,
  `(5,3)->RIGHT` into `(6,3)` confirmed passable 3/3,
  `(5,4)->RIGHT` into `(6,4)` mixed 1/2, and
  `(6,5)->DOWN` into `(6,6)` mixed 2/1. Current live state after summaries:
  `POSITION map=0x1C x=6 y=5`, `RUNTIME_BLOCKS count=2`, with runtime
  directional blocks only for `(2,1)` west and `(2,3)` west.
- Worktree-only verifier hardening after that live pass: `main.lua` now raises
  verifier post-teleport settle to 18 frames and adds a 30-frame inter-attempt
  settle before the next teleport/attempt. Caveat: the attempted
  `touch main.lua` reload did not actually restart the Lua script; later live
  verifier logs still showed the old `settle_frames=8` format. Manually reload
  before judging the new settle patch. A clean retest should first clear
  runtime blocks, then verify the two current confirmed edges and the three
  mixed edges again. The new `EDGE_VERIFY_START` line should include
  `settle_frames=18 between_settle_frames=30`.
- Latest B1 verifier pass after manual reload: the new settle patch is live;
  `EDGE_VERIFY_START` now reports
  `settle_frames=18 between_settle_frames=30`. Five-attempt verification
  confirmed four west-approach engine seams on map `0x1C`: `(2,1)` west,
  `(2,3)` west, `(6,4)` west, and `(8,6)` west. `map_reader.lua` now models
  those as directional blocks and `test_map_reader.lua` asserts them while
  keeping unconfirmed approaches open. Mixed/unpromoted edges remain
  `(2,3)` north, `(6,3)` west, and `(6,6)` north. Runtime simulation with all
  four confirmed blocks reached `Stairs Down to B2` at `(9,9)` and reduced the
  route to one remaining blocked auto-step: `(2,2)->DOWN` into `(2,3)` from
  the north. Fresh state marker `LAUNCHER_PROBE: codex_b1_final_state` then
  reported `PATH_STATE target=nil map=0x1C runtime_count=4` and
  `SEAM_SUMMARY map=0x1C total=27 confirmed_blocked=4 noisy=0 blocked_only=3
  passable_only=20`. Validation passed:
  `luac -p map_reader.lua test_map_reader.lua main.lua debug_tools.lua
  route_manager.lua test_route_manager.lua test_auto_step.lua`,
  `lua test_map_reader.lua`, `lua test_route_manager.lua`,
  `lua test_auto_step.lua`, and `git diff --check`. A later
  `touch main.lua` plus `launcher_probe:codex_b1_permanent_reload` was
  consumed at frame `34260` without resetting the frame counter, so it did not
  prove a source reload. Manually reload/relaunch before judging the permanent
  `map_reader.lua` version with runtime blocks cleared.
- Latest B1 route follow-up after the user reloaded the script: the permanent
  four-seam patch is live and made the entrance-to-stairs route cleaner. The
  route from `(0,0)` to `Stairs Down to B2` reached `(9,9)` with three
  remaining route-only collisions: `(2,2)->DOWN` into `(2,3)` from the north,
  `(5,3)->RIGHT` into `(6,3)` from the west, and `(7,5)->RIGHT` into `(8,5)`
  from the west. Five-attempt verifier results: `(2,3)` north confirmed
  blocked `5/5`, `(8,5)` west confirmed blocked `5/5`, `(6,6)` north confirmed
  blocked `5/5` after the runtime-simulation retest exposed it again, and
  `(6,3)` west stayed mixed with `moved=4 blocked=1`. `map_reader.lua` now
  models only the three confirmed approaches and keeps `(6,3)` west unmodeled.
  A runtime simulation with `(2,3)` north, `(8,5)` west, and `(6,6)` north
  active reached `(9,9)` and only bumped the mixed `(6,3)` west edge. Fresh
  summary at `FRAME:26700`: `PATH_STATE target=nil map=0x1C runtime_count=3`,
  runtime blocks exactly those three verified approaches, and
  `SEAM_SUMMARY map=0x1C total=22 confirmed_blocked=3 noisy=0 blocked_only=1
  passable_only=18`. Validation passed again:
  `luac -p map_reader.lua test_map_reader.lua main.lua debug_tools.lua
  route_manager.lua test_route_manager.lua test_auto_step.lua`,
  `lua test_map_reader.lua`, `lua test_route_manager.lua`,
  `lua test_auto_step.lua`, and `git diff --check`.
- Reverse-route log investigation found a real runtime-contamination bug plus a
  stale-live-code issue. `route_manager.build_path_blocking()` used to pass a
  live `runtime_blocked` direction table directly into the mutable pathfinding
  overlay when no static entry already existed. A later reroute-only temporary
  block could then mutate that verified runtime table and make one confirmed
  approach look like several hard runtime directions. `route_manager.lua` now
  copies runtime direction tables before merging them into the planner overlay,
  and `test_route_manager.lua` has a regression
  `reroute_temporary_block_does_not_mutate_verified_runtime_dirs`. Validation:
  `luac -p route_manager.lua test_route_manager.lua map_reader.lua
  test_map_reader.lua main.lua debug_tools.lua test_auto_step.lua`,
  `lua test_route_manager.lua`, `lua test_map_reader.lua`,
  `lua test_auto_step.lua`, and `git diff --check` passed.
- Live reload attempt `touch main.lua` plus
  `launcher_probe:codex_route_alias_fix` was consumed, but did not pick up the
  latest `map_reader.lua` directional table. Evidence: after clearing B1
  runtime/seam state and rerunning stairs-to-entrance from `(9,9)`, the route
  reached `(0,0)` with `PATH_STATE target=nil map=0x1C runtime_count=0` and
  `RUNTIME_BLOCKS map=0x1C none`, so the hard runtime contamination was gone.
  However `inspect_move:4,4,DOWN` still reported `approach_blocked=false` for
  `(4,5)` north, `inspect_move:5,2,UP` reported `approach_blocked=false` for
  `(5,1)` south, and `inspect_move:9,8,LEFT` saw a directional entry at
  `(8,8)` but not the newly patched east approach. That means the current
  emulator script is still using older map-reader data; manually reload/relaunch
  before judging the reverse route or promoting more B1 seams.
- Post-reload reverse-route failure investigation from B1 stairs `(9,9)` to
  entrance `(0,0)` found three more confirmed one-way engine blockers. The route
  hard-stopped at `(9,9)->LEFT` into `(8,9)` from the east; verifier
  `probe_edge_verify:9,9,LEFT,5` blocked `5/5`, so `(8,9).east` is now modeled.
  Runtime simulation with that block exposed `(6,1)->LEFT` into `(5,1)` from
  the east; `probe_edge_verify:6,1,LEFT,5` blocked `5/5`, so `(5,1).east` is
  now modeled. A second simulation exposed `(5,5)->LEFT` into `(4,5)` from the
  east; `probe_edge_verify:5,5,LEFT,5` blocked `5/5`, so `(4,5).east` is now
  modeled. `test_map_reader.lua` keeps unverified approaches open for all three
  cells. The current live session is stopped at B1 `(5,5)`, `PATH_STATE
  target=nil`, command queue empty, with runtime blocks exactly `(8,9).east`,
  `(5,1).east`, and `(4,5).east`. Because the earlier reload probe left
  `map_reader.lua` stale, manually reload/relaunch before judging whether the
  disk patch fully quiets the route; a full stairs-to-entrance run with all three
  changes loaded from disk has not yet been completed.
- 2026-05-09 route-2 follow-up after the user drove the hero back toward the
  B1 entrance: route 1 to `Stairs Down to B2` is clean enough for now, but the
  return route stopped at `(4,6)->UP` into `(4,5)` from the south. A focused
  verifier confirmed `(4,5).south` blocked `5/5`, and follow-up verifier runs
  confirmed the same south-approach wall at `(1,5)`, `(2,5)`, and `(3,5)`.
  `map_reader.lua` now models those four row-5 south approaches as directional
  B1 blockers, and `test_map_reader.lua` asserts them while preserving other
  approaches. Control check: `(4,2)->LEFT` into `(3,2)` moved `5/5`, so do not
  promote that earlier repeated route-only noise. With the four confirmed
  runtime blocks active in the stale live session, a short `auto_walk` tail
  reached the entrance `(0,0)`. It logged noisy but passable brute-force bumps
  at `(3,1).south`, `(2,1).south`, `(1,0).south`, and `(0,0).east`; do not
  promote those from route-only evidence.
- Validation for the row-5 B1 patch passed:
  `luac -p map_reader.lua test_map_reader.lua`, `lua test_map_reader.lua`, and
  `git diff --check`. Live caveat: `touch main.lua` plus
  `launcher_probe:codex_b1_45_south_reload` proved the command loop was alive,
  but after clearing runtime blocks, `inspect_move:4,6,UP` still reported
  `approach_blocked=false`, so the running BizHawk Lua state had not picked up
  the disk `map_reader.lua` change. Current live state after the route tail:
  B1 `(0,0)`, no active path, runtime blocks exactly `(1,5).south`,
  `(2,5).south`, `(3,5).south`, and `(4,5).south`. A real Lua reload/relaunch
  is still needed before judging the permanent disk data without runtime help.
- Later 2026-05-09 rerun after the user found the BizHawk Lua Console
  auto-reload setting is not persistent across emulator exit and reran both
  route directions: the fresh log started at `2026-05-09 10:29:39`, so the
  row-5 disk patch was live. Route 1 from B1 entrance `(0,0)` to `Stairs Down
  to B2` at `(9,9)` reached the target with only one reroute, `(5,3)->RIGHT`
  into `(6,3)` from the west. Leave `(6,3).west` unmodeled because earlier
  verifier evidence was mixed and this rerun was only a single route bounce.
  The return route reached `(0,0)` but bounced heavily; post-run state was
  `POSITION map=0x1C x=0 y=0`, `PATH_STATE target=nil runtime_count=0`, and
  `RUNTIME_BLOCKS none`.
- Focused verifier follow-up on the return-route bounce cluster confirmed seven
  more B1 directional blockers with `probe_edge_verify` 5/5 blocked attempts:
  `(9,5).south`, `(8,6).east`, `(7,3).south`, `(6,4).east`, `(8,2).south`,
  `(7,3).east`, and `(4,3).east`. `map_reader.lua` now models those confirmed
  directions and `test_map_reader.lua` asserts them. The top-row check
  `probe_edge_verify:3,2,UP,5` was mixed (`moved=4 blocked=1`), so do not
  promote `(3,1).south`; similarly, route-only noisy bumps such as
  `(9,7).south`, `(9,6).south`, `(7,7).east`, `(7,6).south`, `(7,5).south`,
  `(7,4).south`, `(7,1).east`, `(6,1).east`, `(4,2).east`, `(3,2).east`,
  `(2,1).south`, `(1,0).south`, and `(0,0).east` still need verifier consensus
  before permanent modeling.
- Validation for the later return-route patch passed:
  `luac -p map_reader.lua test_map_reader.lua`, `lua test_map_reader.lua`, and
  `git diff --check`. Current live state after the verifier pass is B1 `(3,1)`,
  no active path, and runtime blocks matching the newly confirmed directions:
  `(8,2).south`, `(4,3).east`, `(7,3).east/south`, `(6,4).east`,
  `(9,5).south`, and `(8,6).east`. A reload or relaunch will load the disk
  model; if route tests again look stale, manually re-enable BizHawk Lua
  Console auto reload before touching source files.
- Follow-up manual pass later on 2026-05-09 looked much better. Starting from
  the prior verifier position `(3,1)`, the route first returned to entrance
  `(0,0)` with small top-left noise, then route 1 from entrance to `Stairs Down
  to B2` queued 18 steps and reached `(9,9)` with only the known
  `(6,3).west` route-only bounce. The return route to entrance also completed
  and ended at `(0,0)` with no active path. It still logged noisy/passable
  brute-force corrections at several previously noisy seams plus hard route
  bounces at cells already covered by static or verifier runtime data, but no
  new edge had verifier-grade evidence. Live caveat: `report_runtime_blocks`
  after the pass still showed the six verifier runtime cells active
  (`(8,2).south`, `(4,3).east`, `(7,3).east/south`, `(6,4).east`,
  `(9,5).south`, `(8,6).east`), so this was a practical route-success check,
  not a clean disk-only validation. For disk-only proof, reload/relaunch or
  clear B1 runtime blocks before the next route pair.
- Reloaded disk-only pass and focused verifier follow-up on the recurring
  suspects clarified the remaining route bounces. After the clean route pair,
  `POSITION` was B1 `(0,0)`, `PATH_STATE target=nil runtime_count=0`, and
  `RUNTIME_BLOCKS map=0x1C none`, so the previous verifier runtime overlay was
  not carrying the pass. The route still produced some temporary route bounces,
  but focused `probe_edge_verify` split them cleanly. New confirmed blockers
  now modeled in `map_reader.lua`: `(6,7).east` from
  `probe_edge_verify:7,7,LEFT,5`, `(6,6).east` from
  `probe_edge_verify:7,6,LEFT,5`, `(8,2).east` from
  `probe_edge_verify:9,2,LEFT,5`, `(7,2).north` from
  `probe_edge_verify:7,1,DOWN,5`, and `(2,1).south` from
  `probe_edge_verify:2,2,UP,5`; all were `5/5` blocked. Do not model the mixed
  results: `(6,3).west` was `moved=1 blocked=4`, `(5,5).east` was
  `moved=4 blocked=1`, `(8,2).north` was `moved=1 blocked=4`, and
  `(3,1).south` again was `moved=4 blocked=1`. Validation for this patch passed
  `luac -p map_reader.lua test_map_reader.lua`, `lua test_map_reader.lua`, and
  `git diff --check`. Current live state after verifier probes is B1 `(2,2)`,
  no active path, with runtime blocks matching the five new disk entries; reload
  before judging a fresh disk-only route pair.
- Later route-2 geometry pass after those five entries were loaded from disk:
  the log restarted at `2026-05-09 11:01:49`, proving a fresh script run. The
  route returned from the prior verifier position to entrance, route 1 reached
  `Stairs Down to B2` with the known `(6,3).west` mixed bounce, and route 2
  eventually reached entrance `(0,0)` but detoured farther through the lower B1
  rows. Post-route state before probes was clean: `POSITION` B1 `(0,0)`,
  `PATH_STATE target=nil runtime_count=0`, and `RUNTIME_BLOCKS none`. Focused
  verifier follow-up promoted three more real engine seams: `(5,7).south` from
  `probe_edge_verify:5,8,UP,5`, `(5,7).west` from
  `probe_edge_verify:4,7,RIGHT,5`, and `(2,1).east` from
  `probe_edge_verify:3,1,LEFT,5`; all were `5/5` blocked and are now modeled in
  `map_reader.lua`. Do not model the cleared suspects from this pass:
  `(7,6).south` verified `moved=5 blocked=0`, `(6,8).east` was mixed
  `moved=2 blocked=3`, `(6,8).south` was mixed `moved=4 blocked=1`,
  `(9,1).south` verified `moved=5 blocked=0`, and `(5,5).east` verified
  `moved=5 blocked=0`. Validation passed `luac -p map_reader.lua
  test_map_reader.lua`, `lua test_map_reader.lua`, and `git diff --check`.
  Current live state after verifier probes is B1 `(3,1)`, no active path, with
  runtime blocks matching the three new disk directions; reload before judging
  the next clean disk-only route pair.
- 2026-05-09 silent-reroute/autowalk timing investigation: the noisy return
  route was not only map geometry. Many queued-route blocks showed
  `movement_started=true` from an early `$003D` subpixel twitch, then timed out;
  the same edge either succeeded immediately through seam brute-force or should
  have been direct-tested before allowing an alternate reroute. `auto_step.lua`
  now keeps queued-route input held through early subpixel twitches
  (`auto_step_route_early_release_grace_frames=6` in `dw_access.ini`) and adds
  blocked-step metadata (`movement_started`, `movement_start_frame`,
  retry/turn counts). `route_manager.lua` treats movement-start route timeouts
  as suspect timing and tries the same seam with `AUTO_WALK_TIMING_RETRY`
  before silently rerouting around it.
  Validation passed `luac -p auto_step.lua route_manager.lua config.lua
  test_auto_step.lua test_route_manager.lua`, `lua test_auto_step.lua`,
  `lua test_route_manager.lua`, and `git diff --check` (only the known
  `dw_access.ini` CRLF warning). Live reload proof:
  `LAUNCHER_PROBE: codex_autowalk_timing_patch` at frame `00060`.
  Clean live B1 retest from `(0,0)` with no runtime/seam state reached
  `(9,9)`; early twitch holds turned the previous false blockers into normal
  10-13 frame steps. The only blocked edge was `(5,3)->RIGHT` into `(6,3)`
  from the west, which got the new `AUTO_WALK_TIMING_RETRY`, failed direct
  retry, and then detoured without hard runtime contamination. Return route
  from `(9,9)` to entrance then reached `(0,0)` cleanly with no blocked events.
  Final state: `POSITION map=0x1C x=0 y=0`, `PATH_STATE target=nil
  runtime_count=0`, `RUNTIME_BLOCKS none`, and seam memory was passable-only
  except the still-unmodeled `(6,3).west` blocked-only route/seam evidence.

2026-05-08 overworld route-guidance QoL implemented in the worktree:
- `overworld_routes.lua` adds manual route guidance for the first dungeon,
  Erdrick's Cave, plus safety returns to Brecconary and Tantegel Castle. It is
  route-table driven, accepts `erdrick`, `erdric`, `cave`, `brecconary`,
  `breconary`, `town`, `safe`, `tantegel`, and `castle`, and keeps the route
  in reload-surviving Lua state while the script remains alive.
- Route guidance deliberately does not enable overworld `auto_walk`. The
  player-facing hotkey is `R`: select a supported Travel destination such as
  `Erdrick's Cave`, `Brecconary`, or `Tantegel Castle`, then press `R` to start
  guidance or press it again for active route status/recalculation. Selecting
  another guided Travel destination and pressing `R` replaces the active route;
  selecting the same destination recalculates from the current world-map
  position. The active route injects a small Travel layer capped at the next
  two `Route next` / `Route later` markers, and advances one waypoint at a time
  as the player manually reaches markers.
- The first route includes a one-time bridge warning: `Bridge crossing.
  Monsters may become more dangerous beyond this point.` This addresses the
  early-game clue about bridge/danger boundaries without making every step
  noisy.
- Live route follow-up after the first successful trip to the dungeon: the
  `North trail marker` waypoint was consumed correctly, but the final cave
  waypoint was not cleared because the map changed to `0x1C` before the
  world-map final-tile arrival check fired. `overworld_routes.lua` now treats
  Erdrick's Cave destination maps `0x1C` and `0x1D` as route completion.
  The same log showed blocked mountain tiles around `(30,31)`, `(29,32)`,
  `(27,33)`, and `(28,32)` when the route gave a long heading from the pinch,
  so the route now guides through `East choke approach`,
  `Eastern mountain lane`, and `North ridge bend` before `North trail marker`.
- Cave-bound bridge follow-up: after the safety-route patch, a live cave-bound
  trip reached `map=0x01 x=45 y=34` with active Erdrick route status still
  pointing at `Mountain pinch turn`; pressing north from `(45,34)` blocked into
  `(45,33)`. `overworld_routes.lua` now routes Erdrick's Cave through `Bridge
  south bend` `(44,38)`, `Bridge lower west lane` `(38,36)`, `Bridge west
  bend` `(38,34)`, `Upper bridge lane` `(38,32)`, then
  `East choke approach` `(35,32)`.
  Reload proof: `launcher_probe:cave_bridge_detour_reload` plus `route_status`
  at frame `00060` reported `route=erdrick waypoint=Bridge south bend index=4`
  while the player was still at `map=0x01(World Map) x=45 y=34`.
- Latest bridge-detour log review: the `Bridge south bend` -> `Bridge west
  bend` leg was still too diagonal and produced blocked north attempts from
  `(41,35)`, `(40,35)`, and `(39,35)` before the player found the passable
  `x=38` column. The `Bridge lower west lane` marker at `(38,36)` exists to
  steer west on the lower lane before turning north. The same review found a
  safety-route backtrack where `Bridge south bend` sent the player up toward
  `(45,34)`, then the next Brecconary checkpoint sent them south again; safety
  routes now go from `Bridge south bend` directly to the destination.
  Validation: `luac -p overworld_routes.lua test_overworld_routes.lua
  objects.lua test_objects.lua hotkeys.lua main.lua`, `lua
  test_overworld_routes.lua`, `lua test_objects.lua`, `lua test_hotkeys.lua`,
  and `git diff --check` passed (only the existing `dw_access.ini` CRLF
  warning). BizHawk reload proof:
  `launcher_probe:bridge_lower_lane_reload`; fresh position reported
  `map=0x01(World Map) x=48 y=41`.
- East-choke log review: the route advanced `East choke approach` while the
  player was still at `(34,32)`, one tile west of the intended `(35,32)` lane,
  then `Eastern mountain lane` advanced from `(34,24)` before the player
  finished correcting east. These were early-consumed route markers rather
  than confirmed terrain blockers. `overworld_routes.lua` now requires exact
  arrival at `(35,32)` and `(35,24)` for the east choke / mountain lane turn
  points in both cave-bound and safety routes. Focused regression tests cover
  the one-tile-west non-advance cases.
- East-choke reversal follow-up: the exact marker fix exposed an older route
  ordering problem. Cave-bound guidance sent the player west from `(35,32)` to
  the old `Mountain pinch turn`, then immediately back east four steps to
  `East choke approach`. The route now uses `Upper bridge lane` at `(38,32)`
  between `Bridge west bend` and `East choke approach`; return routes use the
  same marker in reverse, so the player should stay on the east/west lane
  instead of doing a west-then-east reversal.
- Safety-route follow-up: `overworld_routes.lua` now has reverse routes to
  Brecconary and Tantegel Castle using the same cave-road, north-trail,
  mountain-lane, east-choke, upper-bridge, and bridge markers. A live Brecconary
  return then showed the direct `Mountain pinch turn` -> `First bridge
  crossing` leg hitting blocked moves into `(39,34)`, `(41,34)`, and `(42,34)`.
  The safety routes now insert `Upper bridge lane` at `(38,32)`, `Bridge west
  bend` at `(38,34)`, `Bridge lower west lane` at `(38,36)`, and `Bridge south
  bend` at `(44,38)`. Brecconary completes on map `0x08`; Tantegel Castle
  completes on maps `0x04` and `0x05`. Both routes warn once at the bridge
  that monsters should become safer beyond that point.
- New debug/player command hooks: `route_guidance`, `start_overworld_route`,
  `start_overworld_route:erdrick`, `start_overworld_route:erdric`,
  `start_overworld_route:cave`, `start_overworld_route:brecconary`,
  `start_overworld_route:castle`, `route_status`, `route_recalculate`,
  `recalculate_overworld_route`, and `stop_overworld_route`.
- Follow-up after the first live try: the route command was registered and the
  object list grew from 13 to 16 entries, but selection stayed on the old
  `Erdrick's Cave` landmark. `object_commands.lua` now refreshes the overworld
  list immediately, clears the pathability layer, switches to Travel, and
  selects the active `Route next` waypoint when `route_guidance` or
  `start_overworld_route:*` runs. `O` remains a plain heading/path preview for
  the selected object; `U` remains reserved for auto-walk.
- Input/speech QoL follow-up: player testing showed the generic `Object
  controls unavailable right now` message felt bad when pressing readout keys
  during step movement, and route announcements could be cut off by hotkey
  interrupts. `hotkeys.lua` now lets `R` report active route status while
  movement is settling, keeps new route starts and movement-changing object
  controls blocked until stable movement, and uses non-interrupting speech for
  read-only hotkeys (`Shift+W`, `Shift+H`, `Shift+I`, `Shift+G`, `Shift+E`,
  `Shift+R`, `Shift+T`, and `R`). `main.lua` now passes a specific block reason
  such as `Wait for movement to finish`.
- Latest input/speech QoL validation passed: `luac -p hotkeys.lua main.lua
  test_hotkeys.lua overworld_routes.lua test_overworld_routes.lua objects.lua
  object_commands.lua config.lua hotkey_filter.lua`, `lua test_hotkeys.lua`
  (24 tests), `lua test_objects.lua`, `lua test_overworld_routes.lua`,
  `lua test_hotkey_filter.lua`, and `git diff --check` (only the existing
  `dw_access.ini` CRLF warning). BizHawk source reload was nudged with
  `launcher_probe:input_qol_reload`; fresh position reported
  `map=0x01(World Map) x=45 y=34`.
- Validation passed: `luac -p overworld_routes.lua objects.lua
  object_commands.lua hotkeys.lua hotkey_filter.lua config.lua main.lua
  test_overworld_routes.lua test_objects.lua test_hotkeys.lua
  test_hotkey_filter.lua`, `lua test_overworld_routes.lua`,
  `lua test_objects.lua`, `lua test_hotkeys.lua`, `lua test_hotkey_filter.lua`,
  `lua test_route_manager.lua`, `lua test_maps.lua`, and `git diff --check`
  (only the existing `dw_access.ini` CRLF warning). Live note: the first
  timestamp nudge plus `launcher_probe:route_destination_patch` proved the old
  loop was still polling but did not immediately reload the route table. A
  later fresh script header appeared, and `start_overworld_route:cave` then
  logged `waypoint=Eastern mountain lane index=5` at frame `01440`, proving
  that version of the refined pinch-point route was live. A later hands-on pass
  still hit blockage on the first leg, then worked smoothly after reaching the
  eastern lane; `overworld_routes.lua` now adds `East choke approach` at
  `(35,32)` before `Eastern mountain lane`. The stale active route from the
  completed cave trip had also been cleared earlier with `stop_overworld_route`
  at frame `47760`. Destination-map completion then worked live at frame
  `13879`: entering map `0x1C` logged `OVERWORLD_ROUTE: event=arrived`.

2026-05-05 Codex-first tooling refresh implemented in the worktree:
- `.codex/config.toml` now uses `AGENTS.md` first, falls back to
  `PROJECT_MEMORY.md` then `CLAUDE.md`, keeps hooks enabled, leaves model and
  memory preferences to global config, and keeps the project sandboxed with
  network disabled by default.
- Repo-local hook commands now resolve from the git root and use `python3`.
  The session-start hook summarizes the real `Current Focus` instead of
  accidentally treating the first handoff bullet as the active handoff.
- `pretool_dw_command_guard.py` now parses actual shell invocations instead of
  raw substring matches. It blocks hazardous live command batches, raw writes
  to `dw_commands.txt` / `dw_debug.log`, source reload triggers without a
  follow-up probe/wait, and state-sensitive `dw_commands` calls without
  `--replace`, while allowing documentation strings that merely mention bad
  examples.
- `dw_commands.sh` and `dw_commands.ps1` now support `--require-live SECONDS`,
  `--wait-ready TAG`, and `--json` for automated harnesses. `--require-live`
  fails before queueing commands when the log is missing or stale; `--wait-ready`
  queues `launcher_probe:TAG` and waits for the fresh marker; `--json` emits a
  machine-readable status object.
- The `dw-debug-loop` skill moved from legacy `.codex/skills/` to the documented
  repo-skill location `.agents/skills/dw-debug-loop/SKILL.md` with BizHawk-first
  wording and current reload/stale-log guidance.

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
  `Shift+Enter` for the selected object, using an adjacent/interaction landing
  for NPCs, and `Shift+Up/Down/Left/Right` for the adjacent cell on that side
  of the selected object. Teleport reuses the existing safe refusal checks,
  rejects NPC-occupied landings unless forced through the debug command,
  normalizes movement state, and suppresses leaked D-pad/Start input for a few
  frames. NPC target and landing checks read live NPC RAM directly instead of
  forcing a full object-list rebuild.
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
- 2026-05-07 refactor review / merchant regression follow-up: after the
  `main.lua` local-reduction refactor, field entry initially looked dead
  because `get_autowalk_unavailable_reason()` captured `MER` before the local
  merchant state table was declared. `main.lua` now forward-declares `MER`,
  and the per-frame `scan_profiler.call(...)` paths go through `checked_scan`
  so future scan-loop crashes are written to `dw_script_error.log` instead of
  silently stopping after the startup header. Validation:
  `luac -p main.lua merchant.lua route_manager.lua hotkeys.lua`,
  `lua test_hotkeys.lua`, `lua test_merchant.lua`, `lua test_route_manager.lua`,
  and `git diff --check`.
- Same follow-up: Brecconary Merchant 2's weapon/armor item list was visible
  but silent because `merchant.read_rows()` defaulted to live field scroll
  registers (`scroll_tiles=10`, `base_nt=1` in the failing log) and therefore
  missed the fixed shop/menu rows. `merchant.lua` now defaults merchant scans
  to screen coordinates while still accepting explicit scrolled contexts.
  Live reload evidence: `MERCHANT_STATE active=true` found Bamboo Pole, Club,
  Copper Sword, Clothes, Leather Armor, and Small Shield; a raw Down input
  then logged `MERCHANT_SELECT: Clothes. 20 gold.`
- Same follow-up: the object pathability reachability cache no longer reuses
  changed-context data inside an `os.clock()` throttle window. The signature
  cache still avoids recompute when map/start/objects/runtime blocks are
  unchanged, but a changed player position now recomputes immediately; the new
  regression is
  `object_pathability_filter_recomputes_when_position_changes`.
- 2026-05-06 Spark-change review / hotkey crash follow-up: reviewed the
  field-only object-hotkey patch and tightened it before the next live pass.
  `hotkeys.update` still receives `game_state` plus an object-hotkey allowance,
  but `main.lua` now blocks object/teleport/path/mark/freeze hotkeys when the
  existing auto-walk interaction guard reports menu/dialogue/merchant/sweep/step
  state, when lower dialogue has not fully cleared, or while an auto-walk route
  is active. The position readout now protects `nav.get_position_string()` and
  speech output with `pcall`; a failed "where am I" read logs the error and says
  `Position unavailable` instead of killing the Lua loop. Validation:
  `lua test_hotkeys.lua` (15 tests), `lua test_hotkey_filter.lua` (9 tests),
  `luac -p hotkeys.lua test_hotkeys.lua test_hotkey_filter.lua`, and
  `git diff --check`.
- Live status from the same review: `dw_debug.log` is stale at only a fresh
  header from `2026-05-06 12:42:24`; `./dw_commands.sh --require-live 60 ...`
  refused to queue, and a guarded `touch main.lua && ./dw_commands.sh --replace
  --wait "LAUNCHER_PROBE: codex_review_reload" launcher_probe:codex_review_reload`
  timed out. Windows still shows an `EmuHawk` process with window title
  `Lua Console`, so the next live test needs a manual script restart or an
  intentional close/relaunch of BizHawk before judging `Shift+W` / Ctrl+W.
  Also note an untracked zero-byte `main..lua` exists in the repo root, likely
  accidental scratch output; remove it after confirming no external tool needs
  it.
- Loader-error correction from the screenshot: the Lua console showed
  `[string "main"]:4010: too many local variables (limit is 200) in main
  function near '='`. The new object-hotkey helper pushed `main.lua` over the
  Lua 5.1/NLua local limit. The helper was removed and the same boolean is now
  passed inline at the `hotkeys.update` call site, so `luac -p main.lua` now
  passes again. After the fix, `touch main.lua && ./dw_commands.sh --replace
  --wait "LAUNCHER_PROBE: codex_local_limit_fixed" ...` still timed out, which
  means the existing failed Lua Console instance did not auto-reload; reload the
  script manually in BizHawk's Lua Console or close/relaunch BizHawk before the
  next live probe.
- Follow-up after script reload: the Lua loop is live again in Brecconary at
  `(21,7)`. `speech_status` reports `backend=bridge ready=true available=true
  error=none`, and `speech_bridge.log` received fresh utterances including
  `Codex_speech_test`, current-object speech, and `Teleport refused. Target
  cell is occupied by an NPC`. A command-file `teleport_to:5,4` refused because
  Merchant 2 occupies that tile and did not move the player. No physical
  selected-object teleport hotkey event appeared in `dw_debug.log`, so the
  likely bad experience was a silent object-hotkey guard/focus/key-filter miss,
  not a teleport or speech crash. `hotkeys.lua` now speaks `Object controls
  unavailable right now` and logs `object hotkey blocked: CONFIG_KEY` when a
  blocked object/path/teleport/freeze hotkey is pressed. Reload verification:
  `launcher_probe:object_hotkey_guard_message` landed at frame `00060` after
  `touch main.lua`, with speech ready and position still `map=0x08 x=21 y=7`.
- Blocked-teleport input leak follow-up: after the guard-message patch, physical
  blocked teleport attempts logged `object hotkey blocked: key_teleport_*`, but
  the directional component still leaked into gameplay. Evidence: immediately
  after blocked `key_teleport_west/east/south/north`, `auto_step` began manual
  steps left/up/right from `(21,7)`, hit blocked edges, and left the player
  feeling control-locked. A live `clear_input input_status:unlock_check
  report_position report_menu_state speech_status` recovered/confirmed neutral
  input (`keys=- joy1=- left_alt=false`), menu closed, speech ready, and player
  at Brecconary `(22,7)`. `hotkeys.lua` now calls
  `DW_QOL_STATE.suppress_teleport_input()` whenever an object/path/teleport/freeze
  hotkey is blocked, so the same six-frame neutralization used by successful
  teleports also prevents leaked D-pad/Start input from reaching `auto_step`.
  Validation: `luac -p main.lua hotkeys.lua test_hotkeys.lua test_hotkey_filter.lua`,
  `lua test_hotkeys.lua` (15 tests), `lua test_hotkey_filter.lua` (9 tests), and
  `git diff --check`. Reload verification:
  `launcher_probe:blocked_hotkey_suppresses_input` landed at frame `00060`,
  with speech ready, position `map=0x08 x=22 y=7`, and neutral input.
- Held-key/self-blocking correction: the first suppression patch only neutralized
  input for six frames after the rising edge, but a held `Shift+Up` outlasted
  that window and still reached `auto_step`. `hotkeys.lua` now suppresses leaked
  input every frame while a blocked object/path/teleport/freeze hotkey remains
  held, but only speaks the guard on the initial press. Also, `main.lua` no
  longer bases object-hotkey allowance on `field_dialogue_guard_active()`, because
  that function treats the teleport hotkey's own Enter/arrow component as live
  joypad input and made teleport hotkeys refuse themselves. The allowance still
  uses the menu/dialogue/merchant/autowalk guard via
  `get_autowalk_unavailable_reason()`, pending lower-dialogue state, and active
  route state. Validation: `luac -p main.lua hotkeys.lua test_hotkeys.lua
  test_hotkey_filter.lua`, `lua test_hotkeys.lua` (16 tests),
  `lua test_hotkey_filter.lua` (9 tests), and `git diff --check`.
  Reload verification: `launcher_probe:teleport_self_block_removed` landed at
  frame `00060`, speech ready, neutral input, Brecconary `(22,7)`.
- Initial 2026-05-06 hotkey robustness follow-up: object/teleport/path/mark-visited hotkeys were moved behind a field-state gate.
  `hotkeys.update` now receives `game_state`, and `main.lua` evaluates state before
  hotkey processing so battle-state actions are suppressed in that pass. `Shift+V`
  / `mark_visited` and selected-object teleport remain available in field play.
  Superseded by the interaction-aware guard, loader-error correction, and later
  validation notes above.
- Ctrl+W crash follow-up: immediately after the user used `Ctrl+W`, the script
  crashed with `2026-05-06T03:35:37Z snapshot.update: nil`. The stack pointed
  at `emulator_compat.lua:174` inside `bizhawk_console.log()` while reporting a
  `mainmemory.read_u8` fallback from `game_snapshot.update()`. `emulator_compat`
  now wraps adapter logging in `pcall`, disables the console-log path after its
  first failure, and falls back to protected `print`. The first reload then
  surfaced a second transient `BizHawk memory read_u8/readbyte API is
  unavailable` crash; the adapter now returns `0` for temporarily unavailable
  reads and drops unavailable writes after logging once, instead of killing the
  Lua loop. Validation passed:
  `luac -p emulator_compat.lua test_emulator_compat.lua` and
  `lua test_emulator_compat.lua` (14 tests). Live reload after the second fix
  succeeded: `launcher_probe:memory_api_hardened` landed at frame `00060`, and
  `speech_status` reported `backend=bridge ready=true`.
- Future overworld QoL note: the user heard an NPC clue that crossing bridges
  leads into more dangerous areas. This is a good later candidate for an
  optional/subtle alert when the player crosses into a new encounter-strength
  region or other invisible overworld danger boundary.
- Brecconary service-discovery note: the user talked to every reachable
  towns-person target and did not find the inn keeper or a true selling
  merchant. Woman 3 mentioned she was near the shop. Next pass should inspect
  whether shop/inn keepers are blocked targets, static/counter objects, or
  missing from normal NPC/service registration.
- Brecconary counter-service discovery follow-up: the missing first-town
  services were counter/large-tile interactions. `map_reader.lua` now exposes
  non-invasive raw block helpers (`get_raw_block_id`, `is_large_tile`) for the
  original two-nibbles-per-byte map data. `objects.lua` infers service counters
  from adjacent raw `0xF` large tiles, but Brecconary has live-confirmed direct
  overrides: `Weapons Merchant` at `(5,4)` uses `(5,6)` facing north for the
  weapon/armor shop; `Inn` at `(10,21)` uses the public stand `(8,21)` facing
  east because `(9,21)` is blocked from the west approach; Merchant 4 `(25,25)`
  now uses the public stand `(25,26)` facing north for the tool shop. The raw
  `(24,25)` trigger also opens the shop while facing east, but later probes
  proved it is isolated from public floor. Live evidence:
  TALK from `(8,21)` opened `Welcome to the traveler's Inn... Room and board
  is 6 GOLD per night`, and TALK from `(24,25)` opened `Welcome. We deal in
  tools.` A later `(25,26)` probe opened the same tool shop and item list.
  Final reload verification originally showed `Services` objects with
  `Weapons Merchant ... interact 5,6`, `Inn ... interact 8,21`, and
  `Merchant 4 ... interact 24,25`; current active state supersedes that with
  `Merchant 4 ... interact 25,26`.
- Brecconary Merchant 2 located: selected-object teleport placed the player west
  of `Merchant 2` at `(5,4)`, and TALK from `(4,4)` opened the real
  weapon/armor shop (`We deal in weapons and armor...`). Follow-up proved that
  `(4,4)`, `(4,5)`, `(4,6)`, `(5,5)`, `(6,4)`, and `(6,5)` are trap/service
  pocket cells for autonomous routing. A later public-side route repro
  superseded the old noisy `(8,5)->LEFT` moved evidence: `(7,5).east` is blocked
  too. The real public service approach is the doorway/counter square `(5,6)`;
  face north and TALK to Merchant 2 at `(5,4)`, two tiles away.
- Merchant item-list readout fix: the weapon/armor list can show a `COMMAND`
  header while reusing command-menu cursor RAM, so the command-menu reader was
  speaking `TALK` / `STATUS` / `SEARCH` and raw cursor values. `merchant.lua`
  now reads visible rows with horizontal scroll, vertical scroll, and active
  nametable order, and `main.lua` does a fresh merchant-layout check before
  command-menu speech. Follow-up found two stability issues: merchant scans
  were starved while the shop prompt kept `dialogue_hint` true, and stale
  command labels were visible behind item confirmation/error dialogue.
  `main.lua` now keeps merchant scanning active during dialogue hints and blocks
  command-menu speech while lower dialogue is present. Live validation completed
  a Copper Sword not-enough-gold loop and returned to the list with
  `Bamboo Pole. 10 gold.` and no fresh command-label chatter.
- Merchant 2 routing correction: `(4,4)`, `(4,5)`, `(4,6)`, `(5,5)`,
  `(6,4)`, and `(6,5)` are all pathfinder-forbidden trap/service-pocket cells.
  After reload, a trapped start at `(5,5)` reports `No path found` immediately
  with no runtime blocks, while a public start at `(8,5)` auto-walked all the
  way to the world-map exit at `(1,15)` and ended with `RUNTIME_BLOCKS none`.
  Follow-up route validation found that `(5,3)` was a false interaction target:
  the shop opens from `(5,6)` while the merchant object remains two squares
  north at `(5,4)`. `objects.lua` now exposes a Brecconary service interaction
  override for Merchant 2, and `route_manager.lua` routes to the interaction
  square directly, then faces north. Live reload verification:
  `FILTER: Services. Merchant 2: 2 north, counter here (1 of 4) [player 5,6
  obj 5,4 interact 5,6]`.
- Merchant 2 doorway passthrough correction: the first counter-interaction
  route still stopped short because the doorway throat tiles `(5,6)` and
  `(5,7)` decoded as non-walkable type-0 tiles. Live evidence showed movement
  through `(5,8)->UP->(5,7)->UP->(5,6)` and TALK from `(5,6)` opens the shop.
  `map_reader.lua` now marks `(5,6)` and `(5,7)` as narrow Brecconary
  passthrough cells. Live validation after reload: `debug_pathfind_to:5,6`
  found a 13-step path from the west exit side, `auto_walk` queued 13 steps for
  Merchant 2, arrived at `(5,6)`, faced north, and `pathability_filter:refresh`
  from `(5,6)` reported `targets=21 reachable=11 unreachable=10` with no
  runtime blocks.
- Live verification (2026-05-06): after a restart in BizHawk and reload of the
  current state, `next_filter` still reports `Services. Merchant 1/2/3/4` plus
  a `Woman 3` NPC. TALK attempts on `Merchant 1` and `Woman 3` both return
  `There is no one there.` with `VISITED_AUTO skipped`. Superseded follow-up:
  `Weapons Merchant` is the weapon/armor shop, `Inn` is reached via public
  stand `(8,21)`, and Merchant 4 is the tool shop via interaction tile
  `(25,26)` facing north. The old `(24,25)` counter tile remains a working but
  isolated debug trigger.
- Brecconary Guard 6 follow-up: after auto-walk reached Guard 6 in the
  southwest/southeast guard pocket, the object browser recomputed pathability
  as `targets=21 reachable=1 unreachable=20`, leaving only Guard 6 in the
  reachable filter. This matches the known isolated guard-pocket behavior from
  `handoff_archive/HANDOFF_2026-04-26_brecconary_stranded_start_abort.md` and
  `HANDOFF_2026-04-27_brecconary_clean_post_35_survey.md`, not a stale object
  scanner by itself. If continued play needs broad Brecconary routing, move the
  player back to a viable central/open-town start before judging target
  reachability.
- Investigation note: a standalone Lua pathfinder probe accidentally loaded the
  real `debug_tools.lua` once and reset `dw_debug.log` at local time
  `2026-05-05 22:31:03`. Do not treat that fresh header as proof that the
  emulator consumed commands; rely on later frame-bearing log lines or
  `speech_bridge.log` for live evidence.
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
- Guard 1 follow-up from live map `0x05`: the route itself recovered and
  reached `(6,5)` adjacent to Guard 1 at `(7,5)`, but the post-arrival facing
  input walked into `(7,5)` and TALK returned `There is no one there.` Root
  cause was the target NPC hold snapshotting the guard's current live RAM
  position after he had wandered, not the object coordinates used for the
  route plan. `route_manager.lua` now pins the held NPC slot to the planned
  object `(x,y)` while preserving sprite/facing/movement bits, and restores the
  held target before applying the facing input.
- Stale command-menu follow-up: live logs showed `EVENT: command menu opened`
  after a TALK attempt and dialogue appeared, but there was no matching
  `EVENT: command menu closed`. Later `auto_walk` attempts were repeatedly
  blocked before planning. The raw `menu.is_open()` value can stay true from
  lingering `COMMAND` PPU text after the field menu is no longer interactive,
  so `main.lua` now blocks movement/auto-walk only when the confirmed live
  command-menu session still has a recent visible cursor hold. The command
  menu scanner still uses the raw header match so real open/close tracking can
  recover.
- Reload-cache follow-up: a BizHawk console reload re-ran `main.lua` but kept
  the old cached `route_manager.lua`; evidence was the old
  `NPC target hold started: target=Guard 1 slot=0 frames=1200` log without the
  new `at=(x,y)` suffix. `main.lua` now clears project modules from
  `package.loaded` before requiring them, so console/file-change reloads should
  actually pick up required-module edits. After touching `main.lua`, the log
  reset and `report_upper_dialogue_state` used the new diagnostic format.
- Reload-lag follow-up: clearing `package.loaded["emulator_compat"]` exposed a
  second reload trap. The old BizHawk shim-created `FCEU` global survived in the
  Lua state, so the fresh adapter saw `FCEU` first, misdetected the runtime as
  FCEUX, disabled `scan_profiler`, and made reloads crawl. `emulator_compat.lua`
  now prefers real BizHawk API markers (`emu` plus `mainmemory`/`client` or
  memory-domain APIs) over stale `FCEU` shim globals. Live recovery check after
  `touch main.lua`: `launcher_probe:reload_detect` landed at frame `00060` and
  `report_scan_stats` produced normal BizHawk `SCAN_PROFILE` lines instead of
  `SCAN_PROFILE unavailable`.
- Reload-input follow-up: another stale-shim layer could still leave BizHawk in
  the right mode while capturing old wrapped `joypad`/`input`/`ppu` tables as
  if they were native. Symptoms were player controls like `X`/`Z` not working
  and keys behaving like emulator/UI shortcuts after reload. `emulator_compat`
  now unwraps prior adapter closures back to the original BizHawk tables and
  replaces the `FCEU.frameadvance` wrapper on every BizHawk reload so the active
  PPU cache flushes under the current adapter. Live check after `touch main.lua`:
  `launcher_probe:frameadvance_unwrap` landed at frame `00180`,
  `cache_flushes=179`, and `input_status` reported no stuck keys.
- P-key follow-up: the project-side `Shift+P` position hotkey was configured
  and allowlisted correctly, but the local BizHawk config has global
  `"Quick Load": "P"`, making P a bad player-facing shortcut in this runtime.
  `key_position` is now `Shift+W` in both `config.lua` defaults and
  `dw_access.ini`. Live `reload_config` was consumed at frame `12780`; the
  follow-up `input_status:after_position_key_remap` showed no stuck keys.
- Pathfinding confusion follow-up: live logs showed manual blocked movement
  near the throne-room door/seam area promoted runtime blockers at `(4,7)` and
  `(5,7)` on map `0x05`, which then made later autowalks report no path.
  `route_manager.lua` now keeps `queued_route=false` manual blocks as seam
  diagnostics only; runtime blocker promotion still happens for queued-route
  and seam-retry failures. After the reload, `report_runtime_blocks` reported
  `RUNTIME_BLOCKS map=0x05 none`, and the later config-reload snapshot stayed
  clean.
- Guard/NPC overlap follow-up: a live Guard 1 route still arrived at `(4,7)`
  and then the post-arrival facing helper pressed north long enough for
  `auto_step` to treat the artificial face tap as a player step. That walked
  the hero onto Guard 1's square `(4,6)`. `auto_step.lua` now exposes
  `suppress_direction_tracking(frames)`, and `route_manager.lua` calls it when
  queuing post-arrival facing, so the face tap can turn the hero without being
  reinterpreted as tap-to-step. Live retest after reload:
  `auto_walk` while adjacent to Guard 1 logged `AUTO_WALK_FACE ... dir=up
  frames=8`, then a later `report_position` still showed `(4,7)`.
- NPC-clutter route follow-up: queued-route blocks that are currently caused by
  a live NPC are now logged as `AUTO_WALK_NPC_BLOCK`, cancel with "Route
  blocked by NPC movement", do not seam-bruteforce into the NPC, and do not
  promote runtime map blockers. Separately, a live chest route from `(4,7)` to
  the chest at `(4,4)` blocked at `(4,6)` from the south while current NPC
  blockers were `(3,6)`, `(5,6)`, `(2,6)`, and `(3,3)`. That one was not NPC
  clutter; it promoted `BLOCKER_RUNTIME map=0x05 cell=4,6(south)` as current
  live seam evidence.
- Command-menu scan follow-up: while BizHawk dialogue throttling is active,
  `main.lua` now keeps the command-menu scanner awake during current or recent
  player input. This should catch a fresh menu open after dialogue even when
  the menu was not already known open. Automated `simulate_raw_input:A` /
  `simulate_input:A` / `simulate_raw_input:B` did not open the field command
  menu in the live session, so this still needs a physical `X`/command-menu
  test from the user.
- King dialogue wrap follow-up: live play produced
  `greatly pleased 'I am thou hast that rned, Bill. retu` for the King's
  line that should read in normal screen order. The live state at map `0x05`
  `(3,4)` had `PPU_CTRL=0x03` and horizontal scroll `0xB0` (22 tiles), so the
  visible dialogue row starts in NT1 and wraps into NT0. `text.decode_row()`
  now assembles visible rows using horizontal scroll plus PPUCTRL bit 0 instead
  of reading NT0 then NT1 blindly. `report_upper_dialogue_state` now logs
  `scroll_tiles` and `base_nt`; `report_movement_state` logs `ppu_ctrl` and
  `scroll_x`. Offline tests cover NT1-first dialogue wrap. Live validation was
  attempted with `touch main.lua`, but BizHawk did not reload/poll the command
  queue, so the next physical script reload should retest the King dialogue.
- King Yes/No prompt follow-up: the fixed King row order exposed a separate
  lower-window overlap issue. Live logs showed the prompt reads as repeated
  prior tail text plus the actual question, for example
  `experience thou must gain 7 Points. 'Will thou tell me now of thy deeds so
  they won't be forgotten?'`. `text.extract_new_dialogue()` now strips both the
  normal suffix/prefix dialogue overlap and the prompt-specific "new text
  starts inside old text" overlap; `check_yesno_prompt()` speaks/logs only the
  genuinely new question while keeping the full lower-window baseline for the
  normal dialogue scanner.
- Current lag note: the local BizHawk config already matches the known safer
  baseline (`SoundBufferSizeMs=200`, `SoundThrottle=true`, `FrameSkip=0`,
  `Rewind.Enabled=false`, VSync off). A live `report_scan_stats` during the
  King follow-up showed dialogue/menu scanners staying in single-digit max
  milliseconds, while the remaining suspicious spikes were script-side:
  `objects.check_refresh max_ms=3027`, `hotkeys.update max_ms=2270`, and
  `auto_step.update max_ms=1536`. Treat future lag repros as object refresh,
  route command, or movement executor evidence first unless a clean scan window
  shows no script spike.
- Reload/menu silence follow-up: after another script reload at map `0x05`
  `(3,5)`, command-menu and dialogue speech went silent while the script still
  polled commands. Diagnostics at frame `06900` showed speech bridge ready,
  state `field`, `scroll_tiles=22`, `base_nt=1`, and active scanners, but
  `menu_raw=false lower=""`. Root cause is the same NT1-first scroll condition
  as the King dialogue row bug, but in `menu.lua`: the command-menu and Yes/No
  scanners still searched only NT0-first physical row order. `menu.lua` now
  scans both NT0->NT1 and NT1->NT0 virtual row orders for the `COMMAND` header
  and Yes/No cursor patterns. A live `touch main.lua` reload succeeded and
  `launcher_probe:menu_nt_wrap_patch` landed at frame `00180`; physical
  command-menu/TALK retest is still needed because automated simulated A input
  still did not open the field menu in this live state.
- Follow-up PPU dump note: the user-provided `ppu_dump.txt` did not capture an
  active command menu or dialogue page; it only included rows 15-29, which miss
  much of the command window. The PPU dump hotkey now records all rows 0-29 for
  both NT0 and NT1, decodes both NT0->NT1 and NT1->NT0 row orders, and marks
  explicit `COMMAND` / `YESNO` matches. `report_menu_state` is now available to
  log parser/cursor state (`raw_open`, cached open, cursor visibility, yes/no,
  scroll/base, and dialogue start row). Live reload probe
  `launcher_probe:menu_dump_diag_patch` landed at frame `00180`; current idle
  state had `MENU_STATE raw_open=false ... lower_len=0 ... base_nt=0
  dialogue_start_row=13`.
- Latest King silence capture: after a manual reload and a PPU dump taken while
  the King dialogue was believed to be open, the dump still contained no
  `COMMAND` match, no `YESNO` match, and no lower-window lowercase dialogue.
  It showed map `0x05`, player `(3,4)`, `scroll_tiles=22`, `base_nt=1`, and
  only the status/name fragments. A live `report_menu_state
  report_upper_dialogue_state speech_status` probe likewise reported
  `raw_open=false`, `lower_len=0`, and speech bridge ready. Diagnostics now
  clear the BizHawk PPU cache immediately before `Ctrl+D`,
  `report_menu_state`, and `report_upper_dialogue_state` sample the screen so
  the next capture rules out stale cached nametable bytes. The dump hotkey now
  also appends a diagnostic-only `PPU source comparison` section that compares
  native `ppu.readbyte` with available BizHawk nametable-like memory domains,
  so the next bad-state dump can show whether another source sees text that the
  normal reader misses.
- Root cause confirmed by the next dump: native BizHawk `ppu.readbyte` showed
  the blank/status-only state, while `CIRAM (nametables)` contained the real
  King text, the `COMMAND` header, and the Yes/No/menu rows. `emulator_compat.lua`
  now prefers a readable nametable memory domain for PPU reads and falls back
  to native `ppu.readbyte` only when no domain is available. Live reload proof:
  after `touch main.lua`, frame `00144` logged the full King dialogue event,
  and `speech_bridge.log` spoke both the question and `YES NO prompt. YES`.
- King final-line follow-up: the final page dump showed the farewell text in
  the nametable (`'Goodbye now, Bill. Take care and tempt not the Fates.`), but
  no matching dialogue event or speech. On that page `PPUCTRL` reported
  `base_nt=0` even though `scroll_tiles=22` still required the NT1-to-NT0
  visible order. With the reported base, the lower reader missed rows 12-17
  entirely. `text.read_dialogue_window_filtered()` now compares the reported
  base with the alternate nametable order and keeps the one with more lowercase
  dialogue. Live reload proof: frame `00156` spoke a lower-window error line
  (`'There are no stairs here.`) while `base_nt=0`, confirming the fallback is
  active in the running script. Retest the King farewell naturally on the next
  save/continue interaction.
- Command-menu opening follow-up: after the King dialogue fix, live speech logs
  still showed stale cursor RAM leaking into the first command-menu
  announcement, e.g. `Command. STAIRS` immediately before `TALK`. The snapshot
  matched this (`report_menu_state` had cursor `(0,2)` / `STAIRS` while the
  live menu was not confirmed). `main.lua` now queues the menu-open speech for
  a short six-frame debounce and either flushes it with the first real cursor
  movement or speaks the settled current item. The first live reload attempt
  was blocked by the idle emulator loop, but after the user killed/restarted the
  script, the physical retest worked as expected: opening the command menu no
  longer speaks the last-used selection before TALK.
- Death-square follow-up: manual movement found a damaging/death tile on map
  `0x04` at `(10,18)`. The relevant log evidence is a manual/tap step from
  `(10,19)` to `(10,18)`, followed by speech `Lost 15 HP. HP 0`, `Thou art
  dead.`, and the normal Death King recovery dialogue. Treat this as a hazard
  discovery, not an autowalk failure. `map_reader.lua` now models `(10,18)` as
  an engine-walkable hazard, making snapshots/pathfinding/teleport walkability
  avoid it, and `auto_step.lua` refuses tap-extension or queued-route injected
  steps into known hazards while raw held manual movement remains player-owned.
- Reachable-NPC dialogue pass: the user finished dialogue testing all
  reachable NPCs in this part of Tantegel Castle. NPC traffic was still
  annoying enough that Guard 1 was reached by teleport. The castle
  merchant-labeled NPCs only offered dialogue in this pass; verify later
  whether they ever sell before keeping them in the Services object filter.
- First-town merchant dialogue follow-up: in Brecconary, `Merchant 1` also
  offered dialogue only (`Please, save us from the minions of the Dragonlord.`)
  while still appearing in Services. The first encounter at `(15,8)` spoke the
  full line, but after the NPC moved near the top of town, the later encounters
  at `(11,4)` logged/spoke only `Please,save us from`. Root cause is likely the
  y<=3 special row reader catching only the first line and ignoring the richer
  normal lower-window candidate. `read_y1_dialogue()` now compares the fixed
  row scan against the already-filtered lower reader and uses the candidate
  with more lowercase text. Validation passed (`luac -p main.lua text.lua
  test_text.lua`, `lua test_text.lua`, `lua test_auto_step.lua`, and
  `git diff --check` with the known `dw_access.ini` CRLF warning). This patch
  has not been live-reloaded yet, to avoid interrupting active town autowalk.
- Script-crash follow-up: the user reported the script acted funky, lagged,
  then crashed. `dw_debug.log` only had a fresh header, but
  `dw_script_error.log` showed `snapshot.update: 69` from
  `emulator_compat.lua` inside `mainmemory.read_u8`. `emulator_compat.lua` now
  wraps direct BizHawk RAM reads/writes in `pcall` and falls back through the
  domain-backed `System Bus` memory API instead of letting one native memory
  read kill the Lua loop. Because the script was already dead, `touch main.lua`
  did not reload it; relaunch/reload BizHawk Lua before judging the fix.
- Map-transition lag follow-up: after the live `0x05` -> `0x04` transition,
  `report_scan_stats` showed `objects.check_refresh max_ms=1846` while dialogue
  and menu scans stayed in single-digit milliseconds. The spike was the
  map-entry path-grid prewarm. BizHawk now skips that prewarm by default via
  `bizhawk_map_entry_prewarm_path_grid=false`; FCEUX keeps the old behavior,
  and BizHawk can opt back in if first-route warmup matters more than transition
  smoothness.
- Latest scripted live state after the manual-block patch: the player was on
  map `0x05` at `(4,7)`, the selected object had reset to `Door (opened)`, and
  `report_upper_dialogue_state` showed only the status row:
  `menu_raw=false menu_active=false lower=""`. This snapshot did not reproduce
  the silent command-menu/dialogue issue; capture the next bad state while the
  menu or dialogue is visibly up before patching parser logic.
- Second-map stale object-browser follow-up: during normal fresh-game play,
  entering map `0x04` from the throne room could leave old map `0x05` NPCs in
  the current object browser until a later route/NPC-block check forced an NPC
  refresh. The user narrowed the repro: a fresh Lua load transitions cleanly,
  but after touching `main.lua` for a BizHawk reload, the old behavior returns.
  The `ppu_dump.txt` capture from the stale state did not show the prior wrong
  PPU-source failure; `ppu.readbyte` and `CIRAM (nametables)` agreed for the
  decoded rows. Root cause is reload/transition state instead. The first
  signature patch fixed only the current-map list after reload; the user's
  follow-up proved the next transition still accepted previous-map NPC RAM
  after those NPCs had moved or changed facing. `objects.lua` now stores
  signatures in `_G.DW_OBJECTS_RELOAD_STATE`, masks off NPC direction/frame
  bits, and exposes `observe_npcs(map_id)` so `main.lua` records the latest
  current-map NPC coordinate signature during normal frames and reload grace.
  On map entry, if NPC RAM still matches the just-observed previous map, the
  browser hides NPCs and retries until RAM changes instead of publishing old
  King/guard or castle entries as current-map objects. Live reload sanity check
  after this second patch: `launcher_probe:object_observe_field_only_patch`
  landed at frame `00060`; on map `0x04`, `current_object` reported a clean
  30-object castle list. User physical retest then confirmed the actual
  post-reload stairs-transition case: map `0x05` shows 4 NPCs, and map `0x04`
  shows 20 NPCs.
- Visited-after-TALK follow-up: live first-town logs showed a real TALK
  dialogue at frame `18346`, followed by
  `VISITED_AUTO skipped: no adjacent NPC matched TALK dialogue`. The TALK
  marker was armed correctly; the miss came from `objects.mark_adjacent_npc_visited()`
  using cached object-list coordinates while BizHawk periodic NPC object
  refresh is disabled. `objects.lua` now falls back to live NPC RAM slots when
  no cached adjacent NPC matches, marking the same stable `npc_N` id so the
  browser shows the NPC as visited once the object list catches up. Live reload
  probe `launcher_probe:visited_live_npc_patch` landed at frame `00060`.
- Guard 1/menu-open false-block follow-up: while testing reachable NPCs on map
  `0x04`, Guard 1 completed at `(18,2)`, then later route attempts from that
  tile recorded false runtime blocks at `(18,1)`, `(17,2)`, and `(18,3)` while
  the field command menu was still open. That boxed object pathability into
  `reachable=0`. `command_menu_blocks_field_movement()` now keeps blocking
  auto-step for a confirmed live command-menu session while either the cursor
  hold is fresh or the raw COMMAND header is still open; TALK/menu-close paths
  still clear the live-session flag before stale PPU text can linger. The live
  session was unboxed with `clear_blocked_tiles:0x04` (`count=3`), reloaded with
  `launcher_probe:guard1_menu_gate_patch`, and verified at `(18,2)` with
  `PATH_STATE ... runtime_count=0`.
- Guard 1/TALK-failure silence follow-up: immediately afterward, the user's
  failed TALK at `(18,2)` did render lower dialogue, but nothing spoke it.
  `report_upper_dialogue_state` captured `lower="'There is no one there."`,
  `prev_lower` equal to the same text, and `announced_lower=""`; the normal
  filtered lower reader saw the text, but the y<=3 row-1 cleaned dialogue path
  scanned the wrong rows for this BizHawk scroll/base state and treated the
  message as empty forever. `read_y1_dialogue()` now accepts the already
  filtered lower dialogue as a fallback when its fixed-row scan finds no
  lowercase text. Important live note: the first attempted patch briefly pushed
  `main.lua` over Lua 5.1's 200-local limit, and BizHawk appears to have
  stopped polling before the corrected patch could reload. The file is fixed,
  `luac -p main.lua` passes, and later live source-reload probes have
  succeeded.
- Delayed-dialogue visited follow-up: the user noticed visited flags were most
  likely to miss when NPC dialogue took a while to read. Logs confirmed it:
  the first Person 1 TALK armed the marker, then the real dialogue arrived
  about 299 frames later, after the old 240-frame pending marker expired, so no
  `VISITED_AUTO` line was emitted. A later faster repeat of the same dialogue
  did mark Person 1. `main.lua` now keeps pending TALK visits for 720 frames
  and logs explicit expiry; `objects.lua` stores `visited_by_map` in
  `_G.DW_OBJECTS_RELOAD_STATE`, and `main.lua` migrates the old module-local
  visited table before clearing cached modules so the first hot reload after
  this patch should not wipe the current playtest's visited flags. Live reload
  probe `launcher_probe:talk_visit_timeout_patch` landed at frame `00060`.
- Person 1 reachable-filter/no-path hint follow-up: live castle logs showed
  Person 1 in `NPCs, reachable`, then auto-walk failed with the closed-door
  hint. The planner itself was not treating Person 1 as truly isolated: the
  reachability filter is intentionally geometry-only and ignores live NPC
  occupancy, while the failed route had already logged an `AUTO_WALK_NPC_BLOCK`.
  The bad part was `infer_no_path_reason()` preferring any nearby
  closed-door frontier before checking whether an NPC-free route exists, so a
  temporary NPC-clutter no-path could be narrated as "blocked by a closed door."
  `route_manager.lua` now checks the NPC-free route first and only falls back
  to the closed-door hint when NPC clutter is not the better explanation.
  Regression: `autowalk_npc_clutter_hint_takes_precedence_over_nearby_closed_door`.
  Live caveat: after reloading `launcher_probe:person1_hint_patch`, a probe
  `auto_walk` hit the post-reload selected object (`Exit to World Map`) instead
  of Person 1 and moved the player from `(13,20)` to `(11,28)`. Runtime blocks
  are clear (`PATH_STATE ... runtime_count=0`), but do not treat that accidental
  route as a Person 1 physical retest.
- The false-visited regression test through failed TALK still behaves correctly
  in manual testing.
- Current investigation target: no active blocker at wrap-up. The stale
  object-browser reload/transition fix is confirmed by user retest, the NPC
  clutter hint is corrected, and the delayed-dialogue visited fix is live after
  a probe-only reload. Continue normal playtesting and watch whether the next
  slow NPC dialogue emits `VISITED_AUTO`.

Validation already run for this batch:
- 2026-05-05 Codex-first tooling refresh validation:
  source-text compile checks for `.codex/hooks/pretool_dw_command_guard.py`,
  `.codex/hooks/session_start_project_context.py`, and `test_tooling.py`;
  `bash -n dw_commands.sh launch_dw.sh launch_bizhawk.sh launch_fceux.sh`;
  TOML/JSON parse checks for `.codex/config.toml` and `.codex/hooks.json`;
  `python3 test_tooling.py`; PowerShell smoke test of `dw_commands.ps1`
  `--json --replace report_position` against a temp copy; and
  `git diff --check`.
- `luac -p config.lua hotkey_filter.lua hotkeys.lua objects.lua
  object_commands.lua route_manager.lua main.lua test_hotkey_filter.lua
  test_hotkeys.lua test_objects.lua test_route_manager.lua`
- `lua test_hotkey_filter.lua`
- `lua test_hotkeys.lua`
- `lua test_objects.lua`
- `lua test_route_manager.lua`
- 2026-05-05 Guard 1 follow-up validation: `luac -p route_manager.lua
  test_route_manager.lua`, `lua test_route_manager.lua`,
  `lua test_auto_step.lua`, and `git diff --check`.
- 2026-05-05 stale command-menu follow-up validation: `luac -p main.lua
  route_manager.lua`, `lua test_route_manager.lua`, `lua test_menu.lua`,
  `lua test_auto_step.lua`, `git diff --check`, and
  `python3 run_tests.py --allow-missing-speech-dep` passed with the known WSL
  `accessible_output2` warning and `cmd: not found` speech-bridge noise.
- 2026-05-05 autostep/object-browser follow-up validation: `luac -p
  auto_step.lua objects.lua main.lua navigation.lua test_auto_step.lua
  test_objects.lua config.lua`, `lua test_auto_step.lua`,
  `lua test_objects.lua`, and `git diff --check` passed. `git diff --check`
  still prints the known `dw_access.ini` CRLF warning.
- 2026-05-06 object-browser reload follow-up validation: `luac -p
  objects.lua main.lua navigation.lua test_objects.lua test_auto_step.lua
  config.lua`, `lua test_objects.lua`, `lua test_auto_step.lua`, and
  `git diff --check` passed. `git diff --check` still prints the known
  `dw_access.ini` CRLF warning. New regression coverage includes observed
  previous-map NPC signatures surviving an `objects.lua` module reload, plus
  direction/frame-bit-only NPC changes. Live `touch main.lua` plus
  `launcher_probe:object_observe_field_only_patch` passed, and `current_object`
  reported the clean map `0x04` 30-object list after reload.
- 2026-05-06 visited-auto live-RAM follow-up validation: `luac -p
  objects.lua test_objects.lua main.lua`, `lua test_objects.lua`,
  `lua test_auto_step.lua`, live `touch main.lua` plus
  `launcher_probe:visited_live_npc_patch`, and `git diff --check` passed.
  `git diff --check` still prints the known `dw_access.ini` CRLF warning.
- 2026-05-06 delayed-dialogue visited follow-up validation: `luac -p
  main.lua objects.lua test_objects.lua test_route_manager.lua`,
  `lua test_objects.lua`, `lua test_route_manager.lua`, live source reload
  with `launcher_probe:talk_visit_timeout_patch`, and `git diff --check`
  passed. `git diff --check` still prints the known `dw_access.ini` CRLF
  warning. Regression coverage includes visited flags surviving an
  `objects.lua` module reload and staying cleared after `clear_visited:all`.
- 2026-05-06 death-square hazard follow-up validation: `luac -p
  map_reader.lua auto_step.lua route_manager.lua test_map_reader.lua
  test_auto_step.lua`, `lua test_map_reader.lua`, `lua test_auto_step.lua`,
  `lua test_route_manager.lua`, and `git diff --check` passed. `git diff
  --check` still prints the known `dw_access.ini` CRLF warning. Live source
  reload with `launcher_probe:hazard_patch` landed at frame `00060`; the log
  reset cleanly, and `dw_script_error.log` had no new entry beyond older known
  crashes.
- 2026-05-05 reload-cache/diagnostic follow-up validation:
  `luac -p main.lua route_manager.lua test_route_manager.lua`,
  `lua test_route_manager.lua`, `lua test_menu.lua`, `lua test_auto_step.lua`,
  `git diff --check`, and `python3 run_tests.py --allow-missing-speech-dep`
  passed with the same known WSL speech warnings/noise.
- 2026-05-05 reload-lag follow-up validation: `luac -p emulator_compat.lua
  test_emulator_compat.lua`, `lua test_emulator_compat.lua`,
  live `touch main.lua` plus `launcher_probe:reload_detect report_scan_stats`,
  `git diff --check`, and `python3 run_tests.py --allow-missing-speech-dep`
  passed before the later memory-read crash fix.
- 2026-05-05 memory-read crash follow-up validation: `luac -p
  emulator_compat.lua test_emulator_compat.lua` and
  `lua test_emulator_compat.lua`, `git diff --check`, and
  `python3 run_tests.py --allow-missing-speech-dep` passed with the known WSL
  speech warnings/noise. A live `touch main.lua` could not reload the script
  because the Lua loop had already crashed and was no longer polling commands.
- 2026-05-05 King dialogue wrap validation: `luac -p addresses.lua text.lua
  main.lua debug_tools.lua test_text.lua`, `lua test_text.lua`,
  `python3 run_tests.py --allow-missing-speech-dep`, and `git diff --check`
  passed with known WSL speech warnings/noise and the known `dw_access.ini`
  CRLF warning. A live `touch main.lua` did not trigger command polling, so
  physical script reload/retest is still needed.
- 2026-05-05 King Yes/No prompt overlap validation: `luac -p text.lua
  main.lua test_text.lua`, `lua test_text.lua`, `python3 run_tests.py
  --allow-missing-speech-dep`, and `git diff --check` passed with the known WSL
  speech warnings/noise and the known `dw_access.ini` CRLF warning. Live retest
  still needs a physical Lua reload and another King save/continue prompt.
- 2026-05-05 reload/menu silence validation: `luac -p menu.lua test_menu.lua
  main.lua`, `lua test_menu.lua`, `python3 run_tests.py
  --allow-missing-speech-dep`, and `git diff --check` passed with the known WSL
  speech warnings/noise and `dw_access.ini` CRLF warning. Live reload probe
  passed with `launcher_probe:menu_nt_wrap_patch`; physical command-menu/TALK
  retest is still needed.
- 2026-05-05 PPU/menu diagnostic follow-up validation: `luac -p main.lua
  hotkeys.lua test_hotkeys.lua`, `lua test_hotkeys.lua`, and `git diff --check`
  passed with the known `dw_access.ini` CRLF warning. Live reload probe passed
  with `launcher_probe:menu_dump_diag_patch`.
- 2026-05-05 reload-input follow-up validation: `luac -p emulator_compat.lua
  test_emulator_compat.lua`, `lua test_emulator_compat.lua`, live `touch
  main.lua` plus `launcher_probe:frameadvance_unwrap report_scan_stats
  input_status:after_frameadvance_unwrap`, `git diff --check`, and
  `python3 run_tests.py --allow-missing-speech-dep` passed with the same known
  WSL speech warnings/noise.
- 2026-05-05 manual-block/P-key follow-up validation: `luac -p config.lua
  route_manager.lua test_hotkey_filter.lua test_hotkeys.lua
  test_route_manager.lua`, `lua test_hotkey_filter.lua`,
  `lua test_hotkeys.lua`, `lua test_route_manager.lua`, live `reload_config
  input_status:after_position_key_remap report_runtime_blocks
  report_upper_dialogue_state`, `python3 run_tests.py
  --allow-missing-speech-dep`, and `git diff --check`. The live log showed
  `RUNTIME_BLOCKS map=0x05 none`; broad harness still has the known WSL
  `accessible_output2` warning and `cmd: not found` speech-bridge noise.
- 2026-05-05 menu/facing/NPC-block follow-up validation so far: `luac -p
  main.lua auto_step.lua route_manager.lua test_auto_step.lua
  test_route_manager.lua`, `lua test_auto_step.lua`, `lua test_route_manager.lua`,
  live `launcher_probe:menu_face_npc_clutter_patch`, and live Guard 1 facing
  retest that stayed at `(4,7)`. Follow-up broad validation:
  `python3 run_tests.py --allow-missing-speech-dep` and `git diff --check`;
  broad harness still has the known WSL `accessible_output2` warning and
  `cmd: not found` speech-bridge noise, and `git diff --check` still has the
  known `dw_access.ini` CRLF warning.
- 2026-05-05 command-menu opening debounce validation: `luac -p main.lua`,
  `lua test_menu.lua`, `python3 run_tests.py --allow-missing-speech-dep`, and
  `git diff --check` passed. The broad harness still has the known WSL
  `accessible_output2` warning and `cmd: not found` speech-bridge noise, and
  `git diff --check` still has the known `dw_access.ini` CRLF warning. A live
  `touch main.lua` probe timed out because the emulator loop was idle and did
  not consume commands.
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

Historical BizHawk default transition contained:
- `main.lua` loads `emulator_compat.lua` before the existing modules.
- `emulator_compat.lua` supplies FCEUX-shaped globals under BizHawk.
- At that time, `launch_dw.sh` defaulted to BizHawk. This was superseded by
  the 2026-05-18 bakeoff: `launch_dw.sh` now defaults to FCEUX, with BizHawk
  available through `./launch_dw.sh --emulator bizhawk` or `./launch_bizhawk.sh`.
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

Historical lightweight checks passed during the BizHawk default transition:
- `git diff --check`
- Lua parse checks for `main.lua` and `emulator_compat.lua`
- `bash -n launch_dw.sh launch_bizhawk.sh launch_fceux.sh`
- At that time, `./launch_dw.sh --dry-run` reported BizHawk as the default
  emulator and `./launch_dw.sh --emulator fceux --dry-run` reported the FCEUX
  fallback; this is now historical rather than current launcher behavior.
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
  movement-start tracking on timeout retry and the later route-settle fixes
  neutralize route-owned input after the inject window. A 2026-05-05 fresh-game
  playtest then showed manual movement/autostep feeling too native and
  timeout-retry heavy, so the default config is back to
  `auto_step_turn_repress_limit=1`. A follow-up log showed the remaining slow
  taps were often early `$003D` subpixel changes from turn-in-place animation;
  `auto_step.lua` now records the frame of the subpixel change and still
  schedules the quick re-press when that change happened very early and no tile
  move followed. Watch future routes for the older false block / route-settle
  drift signatures, but the neutral gap and movement-start release guards
  should keep this safer than the original eager re-press path.
- `objects.lua` previously prewarmed the current interior map grid during
  map-entry refresh to avoid a 1.7-1.9 second first-route spike. As of
  2026-05-05, that prewarm is disabled by default under BizHawk because live
  map transitions showed `objects.check_refresh max_ms=1846`; the first route
  on a new map may pay the lazy grid-build cost instead. FCEUX still prewarms,
  and BizHawk can opt in with `bizhawk_map_entry_prewarm_path_grid=true`.
- Remaining transition-performance note: if the user still hears a post-entry
  audio cutout, compare `objects.check_refresh max_ms` against first-route
  `ROUTE_PLAN_TIMING` / `CMD_TIMING` before moving more work back onto the
  transition frame.
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
- Rerun the full Brecconary parked-NPC object survey from `(15,15)` as the next
  confidence check. The narrow exit target now succeeds cleanly under the new
  timing-suspect handling; a full survey will show whether the remaining
  `Guard 2` / `Old Man 1` state issues are gone or need a separate route-settle
  pass.
- Do not promote new Brecconary map blockers from this run. If `(15,17).west`
  or `(9,15).west` recurs during normal play, verify with
  `probe_edge_verify` first; current evidence remains noisy/recovered.
- B1 can then resume as the next dungeon/map stress target. Do not promote
  `(6,3)` west from route-only evidence; its latest verifier was mixed. If B1
  routes get meaningfully stuck again, use fresh `probe_edge_verify` consensus
  before changing permanent map data.

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
