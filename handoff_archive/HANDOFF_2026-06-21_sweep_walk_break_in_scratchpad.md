# Current Investigation Scratchpad

Updated: 2026-06-17

No active investigation is in progress.

Garin's Grave route decoding wrapped on 2026-06-17. The detailed live evidence
from the final Cursed Belt, B2 escape, B1 cleanup, and `auto_walk_blocker`
passes has been archived here:

- `handoff_archive/HANDOFF_2026-06-17_garins_grave_final_scratchpad.md`
- `handoff_archive/HANDOFF_2026-06-17_garins_grave_final_wrapup_full.md`

Use `session_handoff.md`, `PLAYTESTING.md`, `PROJECT_MEMORY.md`, and
`project_resources/maps/garins_grave/README.md` for durable current state.

For the next live map task, start a new dated section here with:

- current map id, floor, and player position
- exact target/object being investigated
- runtime blockers injected during the session
- evidence that is still uncertain or should not be promoted
- evidence that has been promoted to permanent map data

## 2026-06-19 Sweep Walk Break-In

### Target

- Validate the new normal-movement `sweep_walk` command in live FCEUX.
- Starting live state from user: map `0x09` Garinham, locked-building room
  stand `(4,7)`.

### Baseline

- Fresh command polling confirmed with
  `LAUNCHER_PROBE: sweep_breakin_baseline`.
- Baseline position/menu:
  `POSITION: map=0x09(Garinham) x=4 y=7`;
  `MENU_STATE raw_open=false cached_open=false`.

### Live Finding

- Command:
  `sweep_walk:attempts=2,max_edges=25`.
- Result:
  `MAP_CRAWL_FINISH run=2 map=0x09 completed=false reason=movement_drift edges=7`.
- The run did prove multi-cell traversal before aborting:
  `cells_visited=3`, `edges_tested=7`, `passable_edges=3`,
  `blocked_edges=1`, `unknown_edges=1`, `dynamic_blockers=1`,
  `unsafe_aborts=1`.
- Drift root cause evidence:
  after `(4,8)->LEFT` completed at `(3,8)`, the next probe started
  immediately as `(3,8)->UP`, but live movement landed at `(2,8)`,
  continuing the prior left movement. Treat this as a step-settle timing bug,
  not map geometry.
- Generated files:
  `sweep_walk_09_run002.json`,
  `sweep_walk_09_run002_summary.txt`,
  `sweep_status.txt`.

### Patch Under Test

- `map_crawler.lua` now waits 16 ticks after a completed probe before starting
  the next edge.
- Regression:
  `test_map_crawler.lua` covers that the crawler does not start the next probe
  during the post-step settle window.
- Static checks passed before live reload:
  `lua test_map_crawler.lua`,
  `lua test_debug_tools.lua`,
  `lua test_sweep_walk_command_surface.lua`,
  `luac -p main.lua map_crawler.lua debug_tools.lua test_map_crawler.lua test_debug_tools.lua test_sweep_walk_command_surface.lua`,
  and `git diff --check`.

### Next

- Reload `main.lua` in FCEUX.
- Re-run:
  `sweep_walk:attempts=2,max_edges=25`.
- Expected improvement: no `movement_drift` at `(3,8)->UP`; run should either
  continue toward `max_edges`/`complete` or expose a new, later live issue.

### After Reload Follow-Up

- Reload confirmed with `LAUNCHER_PROBE: sweep_after_settle_reload`.
- Reload baseline was the prior drift landing:
  `POSITION: map=0x09(Garinham) x=2 y=8`; menu closed.
- Running `sweep_walk:attempts=2,max_edges=25` from `(2,8)` completed cleanly:
  `MAP_CRAWL_FINISH run=1 map=0x09 completed=true reason=complete edges=4`.
  This was a tiny isolated component, not broad coverage:
  `visited=1`, `passable=0`, `blocked=4`, `unsafe_aborts=0`.
- `rg -n '^0x09:' dw_blocks.log` returned no matches, so the sweep did not
  persist legacy block data.
- Repositioned with `teleport_to:4,7`; log confirmed
  `POSITION: map=0x09(Garinham) x=4 y=7`, menu closed.
- After that teleport, FCEUX stopped consuming `dw_commands.txt`. A queued
  `sweep_walk:attempts=2,max_edges=25` and a later liveness probe timed out
  with `dw_debug.log` stale at the teleport confirmation. Running
  `./recover_fceux_input.sh` focused qfceux and queued
  `input_status:fceux_recovery`, but the command queue still was not consumed.

### Current Blocker

- Live command polling is stalled after the teleport to `(4,7)`.
- Next action: user should unpause/reload/restart the FCEUX Lua loop; then
  confirm with:
  `report_position report_menu_state`.

### Restart Follow-Up

- User restarted the FCEUX Lua script.
- Restart liveness confirmed: stale queued `report_position report_menu_state`
  and `input_status:fceux_recovery` were consumed at frame 60.
- Baseline after restart:
  `POSITION: map=0x09(Garinham) x=4 y=7`, menu closed.
- Re-running `sweep_walk:attempts=2,max_edges=25` no longer hit the old
  immediate `movement_drift`, but still failed after the passable
  `(4,8)->LEFT` edge:
  `MAP_CRAWL_ABORT run=1 map=0x09 reason=position_drift expected=(3,8) current=(2,8)`.
- Root cause interpretation:
  the crawler waited 16 ticks after the completed step, but the NES movement
  engine still carried the player one extra tile left during that settle
  window. This is still movement-state carry after a successful probe, not map
  geometry.

### Patch Under Test, Round 2

- `map_crawler.lua` now calls
  `auto_step.reset_movement_engine_state("map_crawl_step_complete",
  {log=false})` immediately after a completed probe lands on its expected
  destination, before the crawler's settle countdown.
- Regression:
  `test_map_crawler.lua` now covers both:
  - waiting before the next probe after a completed step,
  - resetting movement state after a completed probe.
- Static checks passed:
  `lua test_map_crawler.lua`,
  `lua test_debug_tools.lua`,
  `lua test_sweep_walk_command_surface.lua`,
  `luac -p main.lua map_crawler.lua debug_tools.lua test_map_crawler.lua test_debug_tools.lua test_sweep_walk_command_surface.lua`,
  and `git diff --check`.
- Next live action:
  reload `main.lua` in FCEUX again, then rerun
  `sweep_walk:attempts=2,max_edges=25` from `(4,7)`.

### Teleport Stall Follow-Up

- After the round-2 reload, command polling was live at
  `LAUNCHER_PROBE: sweep_reset_after_reload`; position was `(2,7)`, menu
  closed.
- `teleport_to:4,7 report_position report_menu_state` logged a successful
  teleport and menu-closed state, then command polling stopped again before
  `TELEPORT_STATE_GUARD_END`.
- No fresh `dw_script_error.log` entry appeared. This suggests the failure is
  likely outside Lua's caught-call path, plausibly in or before the next
  `FCEU.frameadvance()` after the teleport RAM write.
- New diagnostic patch under test: `report_movement_state` now includes
  `ram0090_0093`, the DataCrystal player sprite-position bytes. Hypothesis:
  `teleport_to` updates logical position `$003A/$003B` but leaves sprite
  position `$0090-$0093` stale, which may explain intermittent teleport state
  poisoning or frame stalls.
- Static check for the diagnostic passed:
  `lua test_debug_tools.lua` and `luac -p debug_tools.lua test_debug_tools.lua`.
- Next reload probe:
  `report_movement_state:before_teleport_probe report_position report_menu_state`.
- If live, run a controlled same-frame comparison:
  `report_movement_state:pre_teleport teleport_to:4,7 report_movement_state:post_teleport`.
  If polling stalls again after the teleport, the pre/post logs should still
  reveal whether `$0090-$0093` stayed inconsistent with `$003A/$003B`.

### Teleport Speech Wedge Evidence

- Reload probe confirmed command polling and the new diagnostic:
  `MOVEMENT_STATE tag=before_teleport_probe map=0x09 ... player=(4,7) ...
  ram0090_0093=E0 FF D0 00`.
- A single-command `teleport_to:4,7` reproduced the wedge even though it did
  not change logical coordinates.
- Last `dw_debug.log` line before the stall:
  `Teleported to (4,7)`.
- In `main.lua`, that log line is immediately followed by
  `tolk.output_interrupt(msg)` when `opts.speak` is true.
- `speech_bridge.log` confirms Python received
  `command='interrupt:Teleported to (4,7)'` and then produced no later command
  activity. This points to a blocking speech bridge / accessible_output call,
  not a map, guard, or frameadvance failure.
- Patch under test: the file-command `teleport_to` now calls
  `DW_QOL_STATE.perform_teleport_to(tx, ty, flag, {speak = false})`, keeping
  debug teleports log-only so speech cannot block command polling. The shared
  helper and player-facing selected teleport path are otherwise unchanged.
- Static checks passed:
  `lua test_sweep_walk_command_surface.lua`,
  `lua test_debug_tools.lua`,
  `luac -p main.lua debug_tools.lua test_debug_tools.lua test_sweep_walk_command_surface.lua`,
  and `git diff --check`.
- Next action: reload `main.lua` in FCEUX, then rerun a silent
  `teleport_to:4,7` followed by `report_movement_state:after_silent_teleport`
  to verify command polling survives the teleport.

### Silent Teleport Follow-Up

- User reloaded `main.lua`.
- Reload baseline:
  `POSITION: map=0x09(Garinham) x=4 y=7`; menu closed;
  `MOVEMENT_STATE tag=reload_silent_tp_baseline ... ram0090_0093=E0 FF D0 00`.
- `teleport_to:4,7` with `{speak=false}` still wedged command polling after
  logging `Teleported to (4,7)`.
- `speech_bridge.log` did **not** receive `interrupt:Teleported to (4,7)` in
  this run, proving the silent command path loaded and ruling out speech as
  the only blocker.
- Since `Teleported to (4,7)` reached disk, the command handler likely reached
  `process_command`'s final flush; the remaining wedge appears after command
  processing, before the next command poll.
- New instrumentation under test:
  - `debug_tools.flush()` exposes an explicit debug-log flush.
  - `main.lua` logs and flushes `TELEPORT_FRAMEADVANCE_ENTER` and
    `TELEPORT_FRAMEADVANCE_RETURN` while `teleport_state_guard` is active.
- Static checks passed:
  `lua test_debug_tools.lua`,
  `lua test_sweep_walk_command_surface.lua`,
  `luac -p main.lua debug_tools.lua test_debug_tools.lua test_sweep_walk_command_surface.lua`,
  and `git diff --check`.
- Next action: reload `main.lua` in FCEUX, run `teleport_to:4,7`, and inspect
  whether the last marker is `TELEPORT_FRAMEADVANCE_ENTER` (hang inside
  `FCEU.frameadvance()`), `TELEPORT_FRAMEADVANCE_RETURN` (hang after frame
  return), or neither (hang before the frameadvance boundary).

### Frameadvance Marker Follow-Up

- The frameadvance-marker run reproduced the same-cell teleport wedge with the
  last log line still `Teleported to (4,7)`.
- No `TELEPORT_FRAMEADVANCE_ENTER` or `TELEPORT_FRAMEADVANCE_RETURN` appeared,
  so the stall is before the explicit `FCEU.frameadvance()` boundary.
- A later liveness probe after the user's reload attempt timed out:
  `launcher_probe:codex_post_reload_frameprobe` remained queued in
  `dw_commands.txt`, with `dw_debug.log` still stale at the same teleport line.
  Treat this as command polling not yet restored; do not append more live
  commands until a reload/relaunch consumes the queued probe or the queue is
  replaced.
- New instrumentation under test:
  - `debug_tools.lua` logs flushed `TELEPORT_TICK_*` breadcrumbs after command
    polling, input-watch updates, legacy sweep tick, and before return from
    `debug_tools.tick`.
  - `main.lua` logs flushed `TELEPORT_LOOP_*` breadcrumbs after
    `debug_tools.tick`, path-debug tick, simulated-input handling, name-entry
    guard, teleport-hotkey release check, teleport input neutralization,
    edge/map crawl ticks, and before frameadvance.
- Static checks passed:
  `lua test_sweep_walk_command_surface.lua`,
  `lua test_debug_tools.lua`,
  `luac -p main.lua debug_tools.lua test_sweep_walk_command_surface.lua test_debug_tools.lua`,
  and `git diff --check`.
- Temporary note: file-command `teleport_to` is still running with
  `{speak=false}` only for this investigation. User explicitly asked to flip
  the speech flag back after the teleport investigation is done.

### Teleport Neutralize Finding

- After the user reloaded with `TELEPORT_TICK_*` / `TELEPORT_LOOP_*`
  instrumentation, fresh polling was confirmed:
  `LAUNCHER_PROBE: codex_tp_loop_baseline`.
- Baseline:
  `POSITION: map=0x09(Garinham) x=4 y=7`, menu closed, and
  `MOVEMENT_STATE tag=tp_loop_baseline ... ram0090_0093=E0 FF D0 00`.
- A same-cell `teleport_to:4,7` reproduced the stall.
- Last flushed breadcrumbs:
  `TELEPORT_TICK_PRE_RETURN`,
  `TELEPORT_LOOP_POST_DEBUG_TICK`,
  `TELEPORT_LOOP_POST_PATH_DEBUG_TICK`,
  `TELEPORT_LOOP_POST_SIM_INPUT`,
  `TELEPORT_LOOP_POST_NAME_GUARD`,
  `TELEPORT_LOOP_PRE_HOTKEY_RELEASE`,
  `TELEPORT_LOOP_POST_HOTKEY_RELEASE`,
  `TELEPORT_LOOP_PRE_NEUTRALIZE`.
- `TELEPORT_LOOP_POST_NEUTRALIZE` did not appear. This isolates the wedge to
  `neutralize_teleport_input()`, at its `joypad.set(1, cleaned)` call.
- Patch under test: `neutralize_teleport_input()` now uses
  `make_teleport_neutral_input(extra)`, returning `{}` for neutral release and
  only truthy override buttons for pending facing, matching the proven
  `clear_edge_probe_input()` empty-table release pattern.
- Static checks passed:
  `lua test_sweep_walk_command_surface.lua`,
  `lua test_debug_tools.lua`,
  `luac -p main.lua debug_tools.lua test_sweep_walk_command_surface.lua test_debug_tools.lua`,
  and `git diff --check`.
- Next action: reload `main.lua` in FCEUX, confirm liveness, rerun
  `teleport_to:4,7`, and verify that `TELEPORT_LOOP_POST_NEUTRALIZE`,
  `TELEPORT_FRAMEADVANCE_ENTER`, `TELEPORT_FRAMEADVANCE_RETURN`, and eventually
  `TELEPORT_STATE_GUARD_END` appear.

### Same-Frame Duplicate Neutralize Finding

- User reloaded after the compact-neutral-table patch.
- Fresh polling was confirmed:
  `LAUNCHER_PROBE: codex_neutral_patch_baseline`.
- Baseline remained map `0x09` at `(4,7)`, menu closed, no lower dialogue.
  The preceding reload had some manual `F` / search-dialogue input noise, but
  the command baseline was clean enough for the same-cell teleport repro.
- Same-cell `teleport_to:4,7` still wedged. The queued post-teleport
  `report_position report_menu_state report_movement_state:after_neutral_patch_teleport`
  timed out and remained in `dw_commands.txt`.
- The last marker was still `TELEPORT_LOOP_PRE_NEUTRALIZE`; no
  `TELEPORT_LOOP_POST_NEUTRALIZE` appeared.
- Important refinement: `perform_teleport_to()` already called
  `DW_QOL_STATE.suppress_teleport_input()`, and that first
  `neutralize_teleport_input()` returned because the log reached
  `TELEPORT_STATE_GUARD` and `Teleported to (4,7)`. The wedge is therefore the
  duplicate neutralize from the main-loop guard in the same frame, not simply
  the neutral table shape.
- Patch under test:
  - `DW_QOL_STATE.teleport_input_neutralized_frame` records the frame where
    `suppress_teleport_input()` already called `neutralize_teleport_input()`.
  - The main-loop teleport guard skips a duplicate same-frame neutralize and
    logs `TELEPORT_LOOP_SKIP_NEUTRALIZE_ALREADY_DONE`.
  - Later frames still neutralize normally while suppress/guard state remains.
- Static checks passed:
  `lua test_sweep_walk_command_surface.lua`,
  `lua test_debug_tools.lua`,
  `luac -p main.lua debug_tools.lua test_sweep_walk_command_surface.lua test_debug_tools.lua`,
  and `git diff --check`.
- Next action: reload `main.lua` in FCEUX, replace the stale queued
  post-teleport probe with a fresh liveness baseline, rerun `teleport_to:4,7`,
  and inspect for `TELEPORT_LOOP_SKIP_NEUTRALIZE_ALREADY_DONE` followed by
  `TELEPORT_LOOP_POST_TELEPORT_INPUT_GATE` / frameadvance markers.

### FCEUX Guard-Frame Neutralize Finding

- User reloaded after the same-frame duplicate-neutralize patch.
- Fresh polling was confirmed:
  `LAUNCHER_PROBE: codex_sameframe_skip_baseline`.
- Baseline remained map `0x09` at `(4,7)`, menu closed, no lower dialogue.
- Same-cell `teleport_to:4,7` still wedged, but moved farther:
  - `TELEPORT_LOOP_SKIP_NEUTRALIZE_ALREADY_DONE` appeared on frame `03180`.
  - `TELEPORT_LOOP_POST_TELEPORT_INPUT_GATE`, edge/map tick markers,
    `TELEPORT_FRAMEADVANCE_ENTER`, and `TELEPORT_FRAMEADVANCE_RETURN` all
    appeared on frame `03180`.
  - Frame `03181` then wedged at `TELEPORT_LOOP_PRE_NEUTRALIZE` with
    `frames_left=11`.
- Interpretation: the first same-frame duplicate was handled; the remaining
  FCEUX wedge is any guard-frame `joypad.set` after the first teleport
  `frameadvance` returns.
- Patch under test:
  - Main loop now computes `teleport_guard_active`.
  - When `emulator_compat.is_fceux and teleport_guard_active`, it logs
    `TELEPORT_LOOP_SKIP_NEUTRALIZE_FCEUX_GUARD_ACTIVE` instead of calling
    `neutralize_teleport_input()`.
  - It still treats teleport input as suppressed for that frame, so
    `auto_step.update` stays blocked while the guard settles.
- Static checks passed:
  `lua test_sweep_walk_command_surface.lua`,
  `lua test_debug_tools.lua`,
  `luac -p main.lua debug_tools.lua test_sweep_walk_command_surface.lua test_debug_tools.lua`,
  and `git diff --check`.
- Next action: reload `main.lua` in FCEUX, replace stale post-teleport queued
  commands with a fresh liveness baseline, rerun `teleport_to:4,7`, and verify
  that `TELEPORT_LOOP_SKIP_NEUTRALIZE_FCEUX_GUARD_ACTIVE` repeats through the
  guard and reaches `TELEPORT_STATE_GUARD_END`.

### FCEUX Guard Skip / Sweep Round 3

- User reloaded after the FCEUX guard-frame neutralize skip.
- Fresh baseline:
  `LAUNCHER_PROBE: codex_sweep_retry_baseline`;
  `POSITION: map=0x09(Garinham) x=2 y=8`, menu closed. This was the prior
  sweep drift landing, not the intended start.
- Repositioned with same-cell-safe `teleport_to:4,7`.
  Teleport survived and a follow-up probe confirmed:
  `POSITION: map=0x09(Garinham) x=4 y=7`, menu closed,
  `MOVEMENT_STATE tag=after_retry_reposition ... buttons=0x00`.
- Re-ran:
  `sweep_walk:attempts=2,max_edges=25`.
- Result reproduced the sweep drift:
  `MAP_CRAWL_FINISH run=2 map=0x09 completed=false reason=position_drift edges=6`.
- Fresh log evidence:
  - First `(4,7)->DOWN` attempt was noisy: movement started, timed out, then
    blocked, so edge `(4,7)->DOWN` became `mixed_probe`.
  - Later `(4,8)->DOWN` second blocked attempt also logged
    `movement_started=true`.
  - `(4,8)->LEFT` then completed correctly to `(3,8)` at frame `13792`.
  - After the crawler's 16-frame settle, frame `13809` aborted with
    `expected=(3,8) current=(2,8)`.
- Interpretation:
  the previous RAM reset and settle window are insufficient by themselves.
  Crawler-owned `inject_step` outcomes must also force-release auto-step input
  before retrying or starting the next DFS edge.
- Patch under test:
  - `map_crawler.lua` now calls a crawler-local stabilization helper after
    both completed and blocked crawler-owned step outcomes.
  - The helper calls `auto_step.cancel_active_step(true, true)` and then
    `auto_step.reset_movement_engine_state(...)`.
  - Completed probes use reason `map_crawl_step_complete`; blocked probes use
    `map_crawl_step_blocked`.
- Regressions added:
  - `crawler_force_releases_after_completed_probe`.
  - `crawler_force_releases_before_blocked_retry`.
- Static checks passed:
  `lua test_map_crawler.lua`,
  `lua test_debug_tools.lua`,
  `lua test_sweep_walk_command_surface.lua`,
  `luac -p main.lua map_crawler.lua debug_tools.lua test_map_crawler.lua test_debug_tools.lua test_sweep_walk_command_surface.lua`,
  and `git diff --check`.
- Next live action:
  reload `main.lua` in FCEUX, confirm liveness/position, then rerun
  `sweep_walk:attempts=2,max_edges=25` from `(4,7)`.

### Blocked-Outcome Settle Finding

- User reloaded after the completed/blocked force-release patch.
- Fresh baseline consumed commands:
  `LAUNCHER_PROBE: codex_sweep_release_baseline`;
  `POSITION: map=0x09(Garinham) x=4 y=7`; menu closed;
  `MOVEMENT_STATE tag=sweep_release_baseline ... buttons=0x00`.
- Re-ran:
  `sweep_walk:attempts=2,max_edges=25`.
- Result:
  `MAP_CRAWL_FINISH run=1 map=0x09 completed=true reason=complete edges=4`.
- The old post-left drift did not recur, but this was not a trustworthy larger
  traversal validation:
  - only `visited=1`;
  - `(4,7)->DOWN`, `(4,7)->LEFT`, and `(4,7)->RIGHT` were all reported as
    verified directional candidates;
  - `(4,7)->DOWN` was passable in the earlier drift repro.
- `dw_blocks.log` still had no `0x09:` persisted entries, so the suspicious
  candidates stayed review/export-only.
- Root-cause evidence from the log:
  after each blocked outcome, the crawler immediately started the retry or
  next direction on the following frame while the forced auto-step release
  window from `auto_step.cancel_active_step(true, true)` was still active.
- Patch under test:
  `map_crawler.lua` now sets `state.step_settle_frames = STEP_SETTLE_FRAMES`
  after blocked outcomes too, so forced release can drain before retrying the
  same edge or starting the next DFS direction.
- Regression added:
  `crawler_waits_for_step_settle_after_blocked_probe`, covering both retry and
  next-edge cases after blocked outcomes.
- Existing tests with synthetic blocked outcomes were updated to advance the
  new settle window before publishing the next fake step.
- Static checks passed:
  `lua test_map_crawler.lua`,
  `lua test_debug_tools.lua`,
  `lua test_sweep_walk_command_surface.lua`,
  `luac -p main.lua map_crawler.lua debug_tools.lua test_map_crawler.lua test_debug_tools.lua test_sweep_walk_command_surface.lua`,
  and `git diff --check`.
- Next live action:
  reload `main.lua` in FCEUX, confirm liveness/position, then rerun
  `sweep_walk:attempts=2,max_edges=25` from `(4,7)`.

### Completed-Step Active Stabilization Finding

- User reloaded after the blocked-outcome settle patch.
- Fresh baseline consumed commands:
  `LAUNCHER_PROBE: codex_blocked_settle_baseline`;
  `POSITION: map=0x09(Garinham) x=4 y=7`; menu closed;
  `MOVEMENT_STATE tag=blocked_settle_baseline ... buttons=0x00`.
- Re-ran:
  `sweep_walk:attempts=2,max_edges=25`.
- Result:
  `MAP_CRAWL_FINISH run=1 map=0x09 completed=false reason=position_drift edges=3`.
- New evidence:
  - `(4,7)->UP` was the expected closed-door frontier.
  - `(4,7)->DOWN` was skipped as `stationary_npc_blocked`, review-only.
  - `(4,7)->LEFT` completed to `(3,7)`, then after the crawler settle window
    the player had drifted to `(2,7)`.
  - The completion event was timing-suspect: after a timeout retry and turn
    repress, `auto_step complete ... frames=2 timeout_retries=1
    turn_represses=1`, then the extra tile drift appeared during settle.
- Interpretation:
  `auto_step` can publish `route_step_completed` when the logical tile first
  changes while the engine still has enough movement carry to continue into
  the next tile. One forced release/reset at completion is not sufficient in
  FCEUX.
- Patch under test:
  during `state.step_settle_frames`, `map_crawler.tick` now calls
  `stabilize_after_step_outcome("map_crawl_step_settle")` every tick before
  decrementing the settle counter. This repeatedly force-releases auto-step
  input and resets movement state while the crawler is waiting.
- Regression added:
  `crawler_keeps_stabilizing_during_completed_step_settle`.
- Static checks passed:
  `lua test_map_crawler.lua`,
  `lua test_debug_tools.lua`,
  `lua test_sweep_walk_command_surface.lua`,
  `luac -p main.lua map_crawler.lua debug_tools.lua test_map_crawler.lua test_debug_tools.lua test_sweep_walk_command_surface.lua`,
  and `git diff --check`.
- Next live action:
  reload `main.lua` in FCEUX, confirm liveness/position, then rerun
  `sweep_walk:attempts=2,max_edges=25` from `(4,7)`.

### Teleport Screen-State Split Finding

- User reloaded after the active-stabilization patch.
- Fresh liveness:
  `LAUNCHER_PROBE: codex_after_user_reload_01`.
- Baseline was the prior drift landing:
  `POSITION: map=0x09(Garinham) x=1 y=7`;
  `MOVEMENT_STATE tag=after_user_reload_01 ... scroll_x=0xB0 ...
  ram0090_0093=B0 FF D0 00`.
- Repositioned with `teleport_to:4,7`; command polling survived and
  `TELEPORT_STATE_GUARD_END` appeared.
- Follow-up state exposed a different teleport bug:
  `POSITION: map=0x09(Garinham) x=4 y=7`, but
  `MOVEMENT_STATE tag=after_reposition_for_sweep ... scroll_x=0xB0 ...
  ram0090_0093=B0 FF D0 00`.
- Interpretation:
  the FCEUX guard-frame neutralization fix made teleport non-wedging, but
  `teleport_to` was still only writing logical position bytes. When moving
  from `(1,7)` to `(4,7)`, the screen/sprite low bytes stayed at the old
  tile's values. Do not use this split state as trusted `sweep_walk`
  validation evidence.
- Patch under test:
  - New `teleport_state.lua` helper writes the landing position and, on
    non-overworld maps, translates scroll/player-sprite low bytes by the same
    16-pixel-per-tile delta.
  - `addresses.lua` now names `PLAYER_SPRITE_X=0x0090` and
    `PLAYER_SPRITE_Y=0x0092`.
  - `main.lua` routes `perform_teleport_to()` through
    `teleport_state.apply_landing()` and logs `TELEPORT_SCREEN_SYNC`.
- Regression added:
  `test_teleport_state.lua` covers indoor X translation and overworld shadow
  coordinate preservation.
- Static checks passed:
  `lua test_teleport_state.lua`,
  `lua test_debug_tools.lua`,
  `lua test_sweep_walk_command_surface.lua`,
  `lua test_map_crawler.lua`,
  and `luac -p main.lua map_crawler.lua debug_tools.lua teleport_state.lua
  test_map_crawler.lua test_debug_tools.lua test_sweep_walk_command_surface.lua
  test_teleport_state.lua`.
- Caveat:
  the current live RAM was already split before this patch. After reload, first
  verify whether patched `teleport_to` can establish coherent movement state
  before trusting a larger sweep result.

### Auto-Step Lost / Can-Walk Gate Finding

- User reloaded after the teleport screen-state patch.
- Fresh liveness:
  `LAUNCHER_PROBE: codex_teleport_sync_reload`.
- Baseline after reload was `(4,5)`, menu closed:
  `MOVEMENT_STATE tag=teleport_sync_reload ... player=(4,5) ...
  scroll_y=0xC0 ... ram0090_0093=B0 FF B0 00`.
- Patched `teleport_to:4,7` survived and logged:
  `TELEPORT_SCREEN_SYNC map=0x09 from=(4,5) to=(4,7) dx=0 dy=2
  screen_synced=true`.
- Follow-up state showed the Y screen/sprite bytes translated by two tiles:
  `MOVEMENT_STATE tag=after_teleport_sync_patch ... player=(4,7) ...
  scroll_y=0xE0 ... ram0090_0093=B0 FF D0 00`.
- Re-ran:
  `sweep_walk:attempts=2,max_edges=25`.
- Result:
  `MAP_CRAWL_FINISH run=1 map=0x09 completed=false
  reason=auto_step_lost edges=2`.
- Root-cause boundary:
  `(4,7)->DOWN` actually moved; post-abort state was
  `POSITION map=0x09 x=4 y=8`. The abort happened because `auto_step` canceled
  while active with `can_walk=false` before publishing a completion/block event:
  `auto_step cancel: can_walk=false auto_dir=down pending_repress=nil`.
- New diagnostic patch under test:
  `main.lua` now logs the full `CAN_WALK false` gate while
  `map_crawler.is_active()` is true, including `map_crawl_active=%s`.
- Static checks passed:
  `lua test_sweep_walk_command_surface.lua`,
  `luac -p main.lua test_sweep_walk_command_surface.lua`,
  and `git diff --check`.
- Next live action:
  reload `main.lua`, rerun from a clean `(4,7)` baseline, and inspect the new
  `CAN_WALK false` line if `auto_step_lost` reproduces.

### Mixed Modeled-Floor Origin Finding

- After the next reload, a larger
  `sweep_walk:attempts=2,max_edges=120` run from Garinham produced no
  passthrough or directional candidates, so the prior bad `(6,17).north`
  export did not recur. That run did not revisit the original `(6,16)` mixed
  false-wall edge, so treat this as export-level validation rather than exact
  origin-marker coverage.
- The run later stopped with:
  `MAP_CRAWL_FINISH ... reason=backtrack_blocked edges=64`.
- The failed backtrack was `(10,16)->UP` into `(10,15)`, but a same-origin
  `verify_walked_edge:10,16,up` moved through the edge, confirming this was
  sweep mechanics noise rather than map geometry.
- Root cause pattern: `(10,16)` had been entered through a modeled-floor
  `mixed_probe` (`blocked_attempts=1`, then moved). The crawler trusted that
  cell as a DFS origin and explored outward, allowing downstream false
  blocked/backtrack evidence.
- Patch under test:
  - `map_crawler.lua` now marks all mixed-probe destinations as unstable
    origins.
  - Hidden-cell mixed entries keep the existing
    `mixed_false_wall_origin` reason.
  - Modeled-floor mixed entries use the new `mixed_probe_origin` reason.
  - DFS skips remaining probes from those origins, preventing downstream
    directional or backtrack exports from mixed-entry state.
- Regression added:
  `modeled_floor_mixed_probe_origin_is_not_explored`.
- Red/green evidence:
  - Before the fix, `lua test_map_crawler.lua` failed with
    `expected down, got up`.
  - After the fix, `lua test_map_crawler.lua` passed 47 tests.
- Adjacent checks passed:
  `lua test_sweep_walk_command_surface.lua`,
  `lua test_map_reader.lua`,
  `luac -p map_crawler.lua test_map_crawler.lua
  test_sweep_walk_command_surface.lua map_reader.lua test_map_reader.lua
  main.lua`, and
  `git diff --check -- map_crawler.lua test_map_crawler.lua map_reader.lua
  test_map_reader.lua work_notes/current_investigation.md`.
- Next live action:
  reload `main.lua`, confirm liveness/position, then rerun a larger
  `sweep_walk:attempts=2,max_edges=120` and check that modeled-floor mixed
  entries are logged as `note=mixed_probe_origin` / unstable cells instead of
  being explored.

### Timing-Suspect Block Split Finding

- User reloaded after the mixed modeled-floor origin patch.
- Fresh liveness:
  `LAUNCHER_PROBE: codex_mixed_origin_reload`.
- Baseline:
  `POSITION: map=0x09(Garinham) x=10 y=14`, menu closed,
  `RUNTIME_BLOCKS map=0x09 none`, door RAM empty.
- A `sweep_walk:attempts=2,max_edges=120` from `(10,14)` completed cleanly but
  only covered two edges. Both edges were `mixed_probe` with
  `note=mixed_probe_origin`, and `dw_crawl_09.txt` exported no passthrough or
  directional candidates. This live-validated the exact unstable-origin
  marker behavior.
- Repositioned with `teleport_to:7,15`; teleport reached
  `TELEPORT_STATE_GUARD_END`, and follow-up state was coherent at `(7,15)`.
- A larger-start `sweep_walk:attempts=2,max_edges=120` from `(7,15)` also
  completed cleanly but only covered four edges. It found one passable edge and
  three `mixed_probe` unknowns, all from the same pattern:
  the first attempt logged `movement_started=true` then timed out/blocked, and
  the retry moved in about 17 frames.
- Root cause refinement:
  clean blocked-then-moved evidence should still mark an origin unstable, but
  `auto_step` movement-start timeouts are timing noise, not clean wall bumps.
  Treating both as `blocked_attempts` over-pruned normal floor traversal.
- Patch under test:
  - `map_crawler.lua` now tracks
    `timing_suspect_blocked_attempts` separately from clean
    `blocked_attempts`.
  - `route_blocked` events with `movement_started=true` or
    `timing_suspect=true` increment only the timing-suspect counter.
  - If such an edge later moves into modeled floor, it remains `open_floor`
    with `note=timing_suspect_retry` instead of `mixed_probe`.
  - If such an edge never moves, it records `timing_suspect_blocked` with
    `note=movement_started_timeout`, staying review-only and exporting no
    directional candidate.
  - Clean blocked-then-moved modeled-floor edges still use
    `mixed_probe_origin` and are not explored.
- Regressions added:
  `timing_suspect_block_then_move_keeps_modeled_floor_explorable` and
  `timing_suspect_blocked_floor_stays_review_only`.
- Red/green evidence:
  - Before the fix, `lua test_map_crawler.lua` failed with
    `expected up, got down`.
  - After the fix, `lua test_map_crawler.lua` passed 49 tests.
- Adjacent checks passed:
  `lua test_sweep_walk_command_surface.lua`,
  `lua test_map_reader.lua`,
  `luac -p map_crawler.lua test_map_crawler.lua
  test_sweep_walk_command_surface.lua map_reader.lua test_map_reader.lua
  main.lua`, and
  `git diff --check -- map_crawler.lua test_map_crawler.lua map_reader.lua
  test_map_reader.lua work_notes/current_investigation.md`.
- Next live action:
  reload `main.lua`, confirm liveness/position, then rerun
  `sweep_walk:attempts=2,max_edges=120` from `(7,15)`. Expected improvement:
  timing-suspect block-then-move edges should log
  `class=open_floor ... note=timing_suspect_retry` and traversal should extend
  beyond the four-edge component without exporting timing noise as blockers.

## 2026-06-17 Garinham Grave Stairs / Inn Route

### Target

- Map `0x09` Garinham, starting from grave-return stairs `(19,0)`.
- Find a viable route to the public inn stand `(15,15)` and back toward the
  grave route.

### Baseline

- Fresh command polling confirmed with `launcher_probe:codex_grave_resume`.
- Position: `POSITION: map=0x09(Garinham) x=19 y=0`.
- Door state: `DOOR_STATE keys=5 slots=0=(17,10)`.
- Runtime overlay before new work: `(14,1).east`, `(4,2).west`,
  `(17,14).north`.
- With the current loaded map model, `debug_pathfind_to_skip_npcs:15,15`
  reports `No path found`; frontier reaches only 7 top-lane tiles.

### Working Hypothesis

- The grave-return pocket may not have an in-town path to the inn. A viable
  route may need to leave through the top-edge world-map transition around
  `(18,0)`, then re-enter Garinham from the normal west entrance before routing
  to the inn.

### Live Results

- Forward escape to the inn is viable through the world map:
  - From `(19,0)`, route/walked to the top lane and used `(18,1)->RIGHT`.
  - Log showed map transition to `0x01` / World Map at `(2,2)`.
  - `start_overworld_route:garinham` plus `auto_walk` reached `(1,2)`.
  - `probe_edge:RIGHT` re-entered Garinham at `(0,14)`.
  - `auto_walk:15,15` from `(0,14)` reached the public inn stand.
- Inn-route cleanup candidates from that completed forward route:
  - `(14,16).west` and `(14,17).west` each produced one blocked-only seam
    observation during reroute.
  - They were not same-origin re-probed, so do not promote them yet.
- Return from inn to grave stairs is not currently viable:
  - From inn `(15,15)`, planner chose `Path: 4 north, 4 east, 11 north` to
    `(19,0)`.
  - Live auto-walk failed at `(19,11)->UP` into `(19,10)` with blocked-only
    seam evidence, then no reroute.
  - Same-origin `probe_edge:UP` from `(19,11)` also blocked. This supersedes
    the older teleport-backed verifier claim that `(19,10)` was passable.
- With the door slot `(17,10)` temporarily seeded open and the bad
  `(19,10).south` bridge blocked at runtime, the remaining candidate bridges
  were walked to and probed:
  - Row-10 family: `(18,11)->UP`, `(18,9)->DOWN`, and `(17,10)->RIGHT` all
    blocked.
  - Top/dark-wall family: `(13,1)->DOWN` and `(13,1)->RIGHT` blocked.
  - West boundary strip: `(12,3)->RIGHT`, `(12,4)->RIGHT`, `(12,5)->RIGHT`,
    and `(12,6)->RIGHT` blocked.
  - Row-7/8/9 gates: `(13..18,7)->UP`, `(18,7)->RIGHT`,
    `(18,8)->RIGHT`, and `(18,9)->RIGHT` blocked.
  - After runtime-blocking the verified false row-10/`(13,1)->DOWN` bridges,
    `debug_route_frontier_skip_npcs:19,0,80` reported
    `hidden_bridge_candidates=0`.

### Promoted

- Removed stale `MAP_PASSTHROUGH_CELLS[0x09]["19,10"]`.
- Updated `test_map_reader.lua` so the Garinham dark-wall fixture keeps
  `(19,10)` as a live-matching type-2 wall instead of a passthrough.

### Still Unpromoted

- Route-shaped blocked-only observations from the attempted route to `(13,1)`:
  `(6..10,2).south` and `(6,4).north/east`.
- Forward inn-route bumps at `(14,16).west` and `(14,17).west`.
- These are good candidates for a later focused pass, but they were only used
  as runtime search pruning in this session.

### Cleanup State

- Diagnostic opened-door seed cleared with `debug_seed_open_doors:clear`.
- Runtime blocked edges cleared with `clear_blocked_tiles`.
- Final live snapshot: `DOOR_STATE keys=5 slots=0=(0,0) ...`,
  `RUNTIME_BLOCKS map=0x09 none`, `POSITION: map=0x09(Garinham) x=18 y=8`.

## 2026-06-18 Garinham Door Survey

### Research

- External map/guide pass found that Garinham has three locked doors overall:
  two on 1F and one in Garinham B1.
- Gamer Corner lists the 1F doors as "East end of town" and "Inside locked
  building"; B1 is dungeon scope.
- Realm of Darkness says the Grave of Garinham entrance is inside the grey
  building and that two guards are behind the locked door inside that building.
- Treat these as orientation only; live OPEN/door RAM still controls permanent
  `MAP_DOOR_CELLS` updates.

### Live State

- Clean baseline after user manual navigation:
  `POSITION: map=0x09(Garinham) x=3 y=11`,
  `DOOR_STATE keys=6 slots=0=(0,0) ...`,
  `RUNTIME_BLOCKS map=0x09 none`, menu/dialogue closed.
- Later cleanup after route probing:
  `POSITION: map=0x09(Garinham) x=8 y=12`,
  `DOOR_STATE keys=6 slots=0=(0,0) ...`,
  `RUNTIME_BLOCKS map=0x09 none`.
- User manual door find follow-up:
  `POSITION: map=0x09(Garinham) x=4 y=5`,
  `DOOR_STATE keys=5 slots=0=(4,6) ...`,
  `RUNTIME_BLOCKS map=0x09 none`.
- Pocket follow-up from the same live state:
  `NPC_SLOT ... Guard 2 x=3 y=5 ... move=0x00` and
  `NPC_SLOT ... Guard 3 x=5 y=5 ... move=0x00`, so the side exits from
  `(4,5)` are stationary guard blocks, not map-wall evidence.
- Raw north probe from `(4,5)`:
  `EDGE_PROBE_RESULT map=0x09 from=(4,5) dir=up dest=(4,4) status=blocked
  final=(4,5) ... npc_blocked=false ... reason=raw_hold_timeout`, followed by
  `EDGE_PROBE_MODEL_MISMATCH ... kind=blocked_despite_open_preview`.
  This confirms the north face of the pocket is an engine block that the model
  currently treats as open.
- Raw south probe from `(4,5)`:
  `EDGE_PROBE_RESULT map=0x09 from=(4,5) dir=down dest=(4,6) status=moved
  final=(4,7) ... reason=position_changed`, with `EDGE_PROBE_CARRY` logging
  the carry through to `(4,7)`. Final snapshot:
  `POSITION: map=0x09(Garinham) x=4 y=7`,
  `DOOR_STATE keys=5 slots=0=(4,6) ...`, `RUNTIME_BLOCKS map=0x09 none`.

### Pinned Doors / Candidates

- Confirmed existing 1F outer/grave-route door:
  - Door cell `(17,10)`.
  - Previously opened from `(17,9)` facing south; door RAM recorded `(17,10)`.
  - Current live inspect still reports
    `TILE map=0x09 x=17 y=10 ... reason=door_closed`.
- Confirmed 1F inside-grey-building door:
  - Door cell `(4,6)`.
  - Fresh door-RAM proof after the user found the door:
    `DOOR_STATE keys=5 slots=0=(4,6)`.
  - South-side OPEN/approach stand is `(4,7)` facing north. After opening, the
    player can pass through `(4,6)` into the interior pocket at `(4,5)`.
  - The interior pocket is real local engine behavior, not just a model guess:
    north from `(4,5)` blocks into `(4,4)`, west/east are occupied by stationary
    guards at `(3,5)` and `(5,5)`, and south exits back through the opened door.
  - Reasoning: live NPCs place the two guide-mentioned guards at `(3,5)` and
    `(5,5)`, with the candidate door between/south of them; 1F locked-building
    chests are at `(8,5)`, `(9,5)`, and `(8,6)`.
  - It decodes as ordinary walkable floor, so model it as a floor-backed engine
    door like the Rimuldar inn doors rather than a wall-backed door like
    `(17,10)`.
- Disproved old east-end guess remains disproved:
  - `(19,16)` should stay out of `objects.lua` / `MAP_DOOR_CELLS[0x09]`.

### Route Notes

- `debug_pathfind_to:4,7` from `(3,11)` initially planned a path, but live
  `auto_walk:4,7` looped/rerouted on false seams instead of reaching the stand.
- During that attempted route, live movement repeatedly blocked:
  - `(14,10)->RIGHT` into `(15,10)`.
  - `(4,13)->UP` into `(4,12)`.
- Temporary runtime edge blocks for those two seams made both `(17,9)` and
  `(4,7)` no-path from the current `(8,12)` position. The runtime blocks were
  cleared before stopping.
- Do not promote the two seam blocks solely from this route attempt; they are
  useful next candidates, but the immediate door-survey result is coordinate
  pinning plus the need for actual OPEN proof.

### Promoted

- `MAP_DOOR_CELLS[0x09]["4,6"]` models the inner locked-building door as a
  floor-backed engine door.
- `objects.lua` exposes that door as `Locked Building Door`, routing to the
  `(4,7)` south-side stand facing north.
- `MAP_DIRECTIONAL_BLOCKS[0x09]["4,4"].south` closes the false north exit from
  the guard pocket after the same-origin raw probe from `(4,5)->UP`.
- `test_map_reader.lua` covers the inner door RAM behavior and pocket blocker;
  `test_objects.lua` covers the door object and interaction stand.

### Remaining Caution

- `(4,5)` is the post-door interior pocket and should not be treated as a useful
  through-route toward the grave stairs unless later gameplay moves the guards
  or proves another event opens this trap.

## 2026-06-19 Sweep Walk Deep Validation

### Teleport Settling / Screen Sync

- Same-cell and nearby teleports in FCEUX can leave movement/input state wedged
  if the post-teleport guard frame neutralizes input while the teleport guard is
  active.
- Added live breadcrumbs around teleport guard state and movement RAM to
  separate true teleport failure from command-polling or speech stalls.
- Current live proof after the screen-sync patch:
  `TELEPORT_SCREEN_SYNC map=0x09 from=(4,5) to=(4,7) dx=0 dy=2
  screen_synced=true`; follow-up state reported `POSITION ... x=4 y=7` and
  `ram0090_0093=B0 FF D0 00`.

### Sweep Walk Auto-Step Abort

- From `(4,7)`, `sweep_walk:attempts=2,max_edges=25` finished with
  `MAP_CRAWL_FINISH run=1 map=0x09 completed=false reason=auto_step_lost
  edges=2`.
- The crawler had injected `(4,7)->DOWN`, then `auto_step` canceled at frame
  `06078` with `can_walk=false`; a post-abort probe showed the player actually
  landed at `(4,8)`.
- Current hypothesis: the step completed physically, but `auto_step` cleared
  before publishing a completion event to the crawler. Added `can_walk`
  diagnostics including `map_crawl_active` to capture the exact gate on the
  next live repro.

### Speech Bridge Launch Hang

- After the `can_walk` diagnostic reload, FCEUX kept running the ROM but the Lua
  script stopped processing keyboard/dialogue/command events.
- Fresh log stopped after command-menu/dialogue events, while
  `speech_bridge.log` ended at `command='speak:Wait for dialogue to finish'`.
  `dw_commands.sh --wait-ready codex_launch_hang_probe report_position` timed
  out, and no fresh `dw_script_error.log` entry appeared.
- Root-cause hypothesis: `speech_bridge.py` read and logged the speech command,
  then blocked inside `accessible_output2`/screen-reader speech. Lua then
  blocked on a later pipe write before reaching the command polling tick.
- Patch in progress: `speech_bridge.py` now drains stdin on the main thread and
  dispatches speech calls through a daemon worker queue. `test_speech_bridge.py`
  reproduces the blocked-speaker case; local checks passed:
  `python3 test_speech_bridge.py`,
  `python3 -m py_compile speech_bridge.py test_speech_bridge.py`, and
  `git diff --check -- speech_bridge.py test_speech_bridge.py`.

### Live Sweep Results / Dialogue False Positive

- After the emulator restart, the bridge log showed the patched startup marker
  `audio pipeline prime queued`, and `launcher_probe:codex_after_recover_probe`
  was consumed successfully.
- A locked-room sweep from `(4,7)` completed cleanly:
  `MAP_CRAWL_FINISH ... completed=true reason=complete edges=4
  passthrough_candidates=0 directional_candidates=3 stationary_npc_cells=0
  transitions=0`.
- Exported review candidates:
  `(3,7).east`, `(4,8).north`, `(5,7).west`, plus closed door frontier
  `(4,6)`.
- A larger sweep from teleported `(8,12)` was refused by preflight, not hung:
  `sweep_walk: close menus and dialogue before starting`.
- `report_upper_dialogue_state` showed this was false dialogue: lower text was
  just `Bill`, while upper/baseline text was the field status display
  `Bill LV 1 HP 8 MP 6 G2148 E1258`.
- Added `test_text.lua` coverage for wrapped lower-dialogue scans that see a
  player-name status fragment next to status marker rows; `text.lua` now skips
  that narrow fragment. Checks passed:
  `lua test_text.lua`, `lua test_sweep_walk_command_surface.lua`,
  `lua test_map_crawler.lua`, `luac -p main.lua map_crawler.lua text.lua
  test_sweep_walk_command_surface.lua test_map_crawler.lua test_text.lua`, and
  `git diff --check -- main.lua map_crawler.lua text.lua
  test_sweep_walk_command_surface.lua test_map_crawler.lua test_text.lua`.
- Follow-up live row dump after state/script reload showed the exact split
  status shape at `(8,12)`:
  `LOWER_DIALOGUE_ROW base=0 scan_index=8 row=02 status=false text="Bill"` and
  `LOWER_DIALOGUE_ROW base=0 scan_index=10 row=04 status=false text="LV  1"`.
  The first filter only recognized complete status rows, so it missed this
  split marker fragment.
- Added a narrower split-status regression plus a control that preserves
  single-word dialogue without nearby status context. `text.lua` now treats
  short nearby status marker fragments such as `LV  1` as status context for
  player-name fragments. Checks passed:
  `lua test_text.lua`, `lua test_sweep_walk_command_surface.lua`,
  `lua test_map_crawler.lua`, `luac -p main.lua map_crawler.lua text.lua
  test_sweep_walk_command_surface.lua test_map_crawler.lua test_text.lua`, and
  `git diff --check -- main.lua map_crawler.lua text.lua
  test_sweep_walk_command_surface.lua test_map_crawler.lua test_text.lua`.
- After reload, `sweep_walk:attempts=1,max_edges=30` from `(8,12)` started and
  progressed, proving the split-status `Bill` preflight blocker was fixed.
  It later aborted at `(8,15)->LEFT` with `auto_step_lost`; the `can_walk`
  diagnostic showed `PREV.dialogue_len=3`, and a later row dump showed
  another false lower-dialogue fragment:
  base 0 rows contained `Bi`, `LV`, `HP`, `MP`, `G21`; base 1 rows contained
  `ll`, `15`, `86`, `64`, `489`.
- Root cause: the alternate-nametable fallback promoted the base-1 fragment
  `ll` over the filtered primary scan because `ll` had more lowercase
  characters. Added a cross-nametable regression that reproduces this exact
  split status display. `text.lua` now refuses to promote short alternate
  fragments when they pair with the other nametable into a short status-name
  token and nearby status marker fragments are present. Checks passed:
  `lua test_text.lua`, `lua test_sweep_walk_command_surface.lua`,
  `lua test_map_crawler.lua`, `luac -p main.lua map_crawler.lua text.lua
  test_sweep_walk_command_surface.lua test_map_crawler.lua test_text.lua`, and
  `git diff --check -- main.lua map_crawler.lua text.lua
  test_sweep_walk_command_surface.lua test_map_crawler.lua test_text.lua`.
- User reported `ll` was repeatedly announced on menu open/close after reload.
  Live repro showed this was the same split status display with `base_nt=1`:
  `report_menu_state` had `lower_len=2`, `lower="ll"`, and the row dump showed
  base 0 `Bi/LV/HP/MP/G21` with base 1 `ll/15/86/64/489`. The previous patch
  only blocked promotion of a bad alternate scan; with the menu open, `ll` was
  the reported-base primary scan. Added
  `dialogue_filter_skips_reported_base_split_status_name_fragment`; `text.lua`
  now applies the cross-nametable status-fragment check to the primary scan
  before considering alternate promotion. Checks passed:
  `lua test_text.lua`, `lua test_sweep_walk_command_surface.lua`,
  `lua test_map_crawler.lua`, `luac -p main.lua map_crawler.lua text.lua
  test_sweep_walk_command_surface.lua test_map_crawler.lua test_text.lua`, and
  `git diff --check -- main.lua map_crawler.lua text.lua
  test_sweep_walk_command_surface.lua test_map_crawler.lua test_text.lua`.
- User then reported `HP` after the hero TALKed/search-talked into empty space.
  Fresh logs showed the actual emitted line was the real failure dialogue plus a
  padded status suffix:
  `EVENT: dialogue: 'There is no one there.               HP`.
  Added a visible-row regression for a padded trailing `HP` suffix, plus a
  control preserving ordinary unpadded `Low HP` dialogue. `text.lua` now strips
  only padded trailing status fragments such as `HP`, `MP`, `LV`, `G...`, or
  `E...` from mixed dialogue rows. Checks passed:
  `lua test_text.lua`, `lua test_sweep_walk_command_surface.lua`,
  `lua test_map_crawler.lua`, `luac -p main.lua map_crawler.lua text.lua
  test_sweep_walk_command_surface.lua test_map_crawler.lua test_text.lua`, and
  `git diff --check -- main.lua map_crawler.lua text.lua
  test_sweep_walk_command_surface.lua test_map_crawler.lua test_text.lua`.
- 2026-06-19 13:34 CDT contaminated input note: the unexpected command menu
  open after run 4 was not a queued sweep command. The pre-open log showed a
  stale FCEUX `LeftAlt` latch plus external bridge `up`/`A`; later menu
  navigation was user input after switching back to FCEUX. `dw_commands.txt`
  and `dw_keyboard_input.txt` were clean after recovery, one live
  `keyboard_bridge.ps1` sidecar was present, and a raw `B` sequence closed the
  command menu at frame 62826. Treat this as input/focus contamination, not map
  or sweep evidence.

### Garinham `(3,17)` Passthrough

- 2026-06-19 sweep break-in run 2 reached Garinham `(4,17)` by normal
  movement, then moved `(4,17)->LEFT` into `(3,17)` even though the model
  decoded `(3,17)` as type-11 non-walkable. The sweep backtracked
  `(3,17)->RIGHT` to `(4,17)` successfully.
- After a script reload, same-origin `probe_edge:left` from `(4,17)` again
  moved into `(3,17)`, and same-origin `probe_edge:right` moved back to
  `(4,17)`. Menu was closed; only the known idle `LeftAlt` latch was present.
- Promoted `MAP_PASSTHROUGH_CELLS[0x09]["3,17"] = true` with a focused
  `test_map_reader.lua` regression. Red failure before the patch:
  `Garinham (3,17) should be walkable ... expected true, got false`.
  Green checks after patch:
  `lua test_map_reader.lua`,
  `luac -p map_reader.lua test_map_reader.lua`, and
  `git diff --check -- map_reader.lua test_map_reader.lua`.

### Sweep run 1 after `(3,17)` patch

- After reload, `inspect_tile:3,17` and `inspect_move:left` from `(4,17)`
  reported `reason=passthrough` / `effective_passable=true`, confirming the
  `MAP_PASSTHROUGH_CELLS[0x09]["3,17"]` patch was live.
- `sweep_walk:attempts=1,max_edges=120` from `(4,17)` finished cleanly at the
  edge cap: `edges=120`, `unknown=0`, `unsafe_aborts=0`, `dynamic=2`,
  `transitions=3`. This proves the old `(3,17)` unknown no longer blocks
  the sweep.
- Review candidates from `dw_crawl_09.txt`: passthrough candidates `(3,13)`
  and `(4,16)`; directional candidates `(1,12).south`, `(3,12).south`,
  `(4,12).south`; stationary NPC cells `(2,14)` and `(2,15)`;
  origin-boundary frontiers `(1,13)`, `(1,14)`, `(1,15)` excluded.
- A non-teleport verifier attempt for `(4,13)->LEFT` routed from `(7,10)` but
  aborted before reaching the origin: route got to `(7,13)`, retried
  `(7,13)->LEFT`, then `can_walk=false` due to `PREV.dialogue_len=4`.
  The retry still physically left the player at `(6,13)`.
- `report_upper_dialogue_state` showed the false dialogue shape at `(6,13)`:
  status rows with clipped labels such as `Bill`, `V  15`, and `P  86`.
  Added `test_text.lua` coverage for clipped status label/value rows and
  updated `text.lua` so `V <number>` and `P <number>` count as status marker
  fragments. Checks passed:
  `lua test_text.lua`, `lua test_sweep_walk_command_surface.lua`,
  `lua test_map_crawler.lua`,
  `luac -p text.lua test_text.lua main.lua map_reader.lua test_map_reader.lua test_sweep_walk_command_surface.lua`,
  and `git diff --check -- text.lua test_text.lua main.lua map_reader.lua test_map_reader.lua test_sweep_walk_command_surface.lua work_notes/current_investigation.md`.
- After reload, the same clipped status rows were still visible, but
  `report_upper_dialogue_state` reported `lower_len=0`, confirming the text
  filter fix was live. `verify_walked_edge:4,13,left` then routed from
  `(6,13)` to `(4,13)` without the prior `can_walk=false` cancellation.
- The walked verifier's raw probe moved from `(4,13)->LEFT` into the modeled
  wall `(3,13)` and carried to `(2,13)`. A follow-up same-origin
  `probe_edge:right` from `(2,13)` entered `(3,13)` and carried back to
  `(4,13)`. Promoted `MAP_PASSTHROUGH_CELLS[0x09]["3,13"] = true` with a
  focused `test_map_reader.lua` regression. Checks passed:
  `lua test_map_reader.lua`,
  `luac -p map_reader.lua test_map_reader.lua`, and
  `git diff --check -- map_reader.lua test_map_reader.lua`.

### Post-Restore Locked-Room Sweep Drift

- After an accidental state restore and user script reload, fresh command
  polling was confirmed with `LAUNCHER_PROBE: restored_state_baseline`.
  Baseline: `POSITION: map=0x09(Garinham) x=4 y=7`, menu closed,
  `PREV.dialogue_len=0`, with only the known benign stale `LeftAlt` latch.
- Non-moving model checks confirmed the latest passthrough patches were live:
  `(3,13)` and `(3,17)` both reported `reason=passthrough` and
  `effective_passable=true`; `(4,16)` still reported
  `effective_passable=false` / `reason=tile_type`.
- A small locked-room `sweep_walk:attempts=2,max_edges=25` reproduced a
  cleaner one-tile carry bug: after `(3,7)->LEFT` completed to `(2,7)`, the
  crawler's settle window found the player at `(1,7)` and finished
  `reason=position_drift edges=11`. No dialogue/menu blocker was present.
- Root-cause interpretation:
  the crawler was using the normal debug `inject_step` profile. On turn-repress
  style crawler steps, `auto_step` could hold until coordinate change, letting
  FCEUX commit an immediate extra tile before the crawler could stabilize.
- Patch under test:
  - `map_crawler.lua` now injects crawler-owned steps with
    `source="map_crawl"` and `release_after_inject_limit=true`.
  - `auto_step.lua` gives `source="map_crawl"` the short
    `auto_step_route_pre_turn_inject_limit` window by default and carries that
    short-release profile through turn represses.
- Regression checks passed:
  `lua test_auto_step.lua`,
  `lua test_map_crawler.lua`,
  `lua test_sweep_walk_command_surface.lua`,
  `lua test_debug_tools.lua`,
  `luac -p auto_step.lua map_crawler.lua test_auto_step.lua
  test_map_crawler.lua test_sweep_walk_command_surface.lua test_debug_tools.lua
  main.lua`, and
  `git diff --check -- auto_step.lua map_crawler.lua test_auto_step.lua
  test_map_crawler.lua`.
- Next live action:
  reload `main.lua` in FCEUX, confirm position/menu/dialogue, and rerun
  `sweep_walk:attempts=2,max_edges=25` from `(4,7)`. Expected improvement:
  no post-completion carry from `(3,7)->LEFT` to `(1,7)`.

### Map-Crawl Profile Reload Follow-Up

- User reloaded script/emulator on 2026-06-20. Fresh baseline:
  `LAUNCHER_PROBE: sweep_mapcrawl_reload_baseline`;
  `POSITION: map=0x09(Garinham) x=4 y=7`; menu closed;
  `PREV.dialogue_len=0`; known benign stale `LeftAlt` only.
- Reran `sweep_walk:attempts=2,max_edges=25` from `(4,7)`.
  Result: `MAP_CRAWL_FINISH ... reason=max_edges edges=25`, with
  `unknown=0`, `unsafe_aborts=0`, `transitions=0`. This verifies the previous
  post-completion carry from `(3,7)->LEFT` to `(1,7)` did not recur in the
  smoke sweep.
- The log confirmed the new crawler profile was live on normal/repress steps:
  `source=map_crawl` and `inject_limit=10`.
- New small bug found before widening coverage:
  timeout retries still logged `source=map_crawl` but fell back to
  `inject_limit=12`, because `auto_step`'s timeout-retry branch reused the
  global `auto_step_inject_limit`.
- Patch under test:
  `auto_step.lua` now preserves the short map-crawl inject window and
  release-after-inject behavior through timeout retries as well as turn
  represses.
- Regression checks passed:
  `lua test_auto_step.lua`,
  `lua test_map_crawler.lua`,
  `lua test_sweep_walk_command_surface.lua`,
  `luac -p auto_step.lua map_crawler.lua test_auto_step.lua
  test_map_crawler.lua test_sweep_walk_command_surface.lua main.lua`, and
  `git diff --check -- auto_step.lua map_crawler.lua test_auto_step.lua
  test_map_crawler.lua work_notes/current_investigation.md`.
- Next live action:
  reload `main.lua` again, rerun the small `(4,7)` sweep, and confirm timeout
  retry lines remain `inject_limit=10` instead of `12`.

### Map-Crawl Retry Fix Live Verification

- User reloaded after the timeout-retry profile patch.
- Fresh baseline:
  `LAUNCHER_PROBE: sweep_retry_reload_baseline`;
  `POSITION: map=0x09(Garinham) x=7 y=3`; menu closed;
  `PREV.dialogue_len=0`; known benign stale `LeftAlt` only.
- This was the exact prior timeout-retry origin, so no reposition was needed.
- Ran targeted `sweep_walk:attempts=2,max_edges=6`.
  Result: `MAP_CRAWL_FINISH ... reason=max_edges edges=6`,
  `unknown=0`, `dynamic=0`, `transitions=0`, `unsafe_aborts=0`.
- Live retry proof:
  `(7,3)->UP` logged `source=map_crawl` with `inject_limit=10` for the
  initial press, timeout retry, repress begin, and blocked outcome on both
  attempts. No `inject_limit=12` fallback appeared.
- Review candidate from this tiny targeted sweep:
  `["7,2"] = {south = true}`. Treat as review-only until same-origin
  non-sweep verification is needed; the immediate goal here was sweep/auto-step
  timing validation.

### Medium Sweep After Retry Fix

- After confirming current RAM position `POSITION ... x=7 y=4`, ran
  `sweep_walk:attempts=2,max_edges=60`.
- Result:
  `MAP_CRAWL_FINISH ... reason=max_edges edges=60`,
  `unknown=1`, `dynamic=2`, `transitions=0`, `unsafe_aborts=0`.
- The previous timeout-retry profile issue stayed fixed throughout this run:
  checked logs had no `inject_limit=12` and no `position_drift`,
  `movement_drift`, or `auto_step_lost`.
- The one unknown was intentionally conservative JSON bucketing:
  `(7,4)->UP` toward `(7,3)` was a `mixed_probe` with one blocked attempt and
  one moved attempt. Treat it as ambiguous/review-only, not map evidence.
- Exported review candidates from `dw_crawl_09.txt`:
  directional candidates `(6,5).east`, `(6,6).east`, `(7,2).south`,
  `(8,2).south`, `(9,2).south`; stationary NPC cells `(6,3)` and `(9,6)`.
  These are review-only until separately verified from walked origins.

### 120-Edge Sweep / Frontier-Return Failure

- From clean live position `(7,7)`, ran `sweep_walk:attempts=2,max_edges=120`.
- The run exercised the earlier locked-room drift path again, including
  `(4,7)->LEFT` and `(3,7)->UP/DOWN`, with no over-hold regression:
  all checked map-crawl steps and retries stayed `inject_limit=10`.
- It aborted later at 72 edges:
  `MAP_CRAWL_FINISH ... reason=position_drift edges=72`.
- Root cause:
  after a mixed/noisy `(2,8)->RIGHT` into `(3,8)`, the crawler scheduled a
  `return_to_frontier` edge from `(3,8)->LEFT` back to already visited
  `(2,8)`. That return was blocked, with log evidence of a live stationary NPC
  at `(2,8)` on one attempt. The crawler classified the final failed return as
  a normal `directional_block_candidate`, then resumed expecting `(2,8)` while
  the player was still at `(3,8)`, producing the later `position_drift`.
- Interpretation:
  this is crawler recovery/classification fallout, not map evidence. Do not
  promote the exported `(2,8).east`-style candidate from this failed run.
- Patch under test:
  `map_crawler.lua` now treats final failed `return_to_frontier` edges like
  failed backtracks: record diagnostic `return_to_frontier_blocked`, finish
  with `reason=return_to_frontier_blocked`, and avoid exporting a directional
  candidate for that return edge.
- Regression checks passed:
  `lua test_map_crawler.lua`,
  `lua test_sweep_walk_command_surface.lua`,
  `luac -p map_crawler.lua test_map_crawler.lua
  test_sweep_walk_command_surface.lua main.lua`, and
  `git diff --check -- map_crawler.lua test_map_crawler.lua
  work_notes/current_investigation.md`.
- Next live action:
  reload `main.lua`, then rerun a medium/large sweep from the current Garinham
  state and confirm a blocked frontier return ends as
  `return_to_frontier_blocked` instead of delayed `position_drift`.

### Frontier-Return Patch Live Verification

- After reload, fresh baseline:
  `LAUNCHER_PROBE: frontier_return_reload_baseline`;
  `POSITION: map=0x09(Garinham) x=3 y=8`; menu closed;
  `PREV.dialogue_len=0`; known benign stale `LeftAlt` only.
- Targeted `sweep_walk:attempts=2,max_edges=120` from `(3,8)` reproduced the
  recovery-failure path directly and now finished as intended:
  `MAP_CRAWL_FINISH ... reason=return_to_frontier_blocked edges=24`.
- The failed return edge was diagnostic, not geometry evidence:
  `MAP_CRAWL_EDGE ... class=return_to_frontier_blocked ...
  note=return_to_visited_frontier_blocked`.
  `dw_crawl_09.txt` exported only two unrelated directional review candidates
  and did not promote the failed return edge.
- Reporting cleanup:
  `map_crawler.lua` now buckets `backtrack_blocked` and
  `return_to_frontier_blocked` as `unsafe_abort` in sweep JSON instead of
  ordinary `unknown` geometry. Added
  `walk_sweep_failed_return_to_frontier_exports_as_unsafe_abort`.
- Checks passed:
  `lua test_map_crawler.lua`,
  `lua test_auto_step.lua`,
  `lua test_sweep_walk_command_surface.lua`,
  `luac -p map_crawler.lua test_map_crawler.lua
  test_sweep_walk_command_surface.lua auto_step.lua test_auto_step.lua
  main.lua`, and
  `git diff --check -- map_crawler.lua test_map_crawler.lua auto_step.lua
  test_auto_step.lua work_notes/current_investigation.md`.

### Broad Sweep Stress After Reload

- After reloading the unsafe-abort reporting patch, baseline at `(1,6)` was
  clean. A component-local `sweep_walk:attempts=2,max_edges=120` completed:
  `MAP_CRAWL_FINISH ... completed=true reason=complete edges=27`,
  with `unsafe_aborts=0`.
- Repositioned with coarse `teleport_to:4,7`, then re-baselined:
  `POSITION: map=0x09(Garinham) x=4 y=7`; menu/dialogue inactive; no announced
  status-noise despite the visible split status baseline.
- Broad stress run from `(4,7)`:
  `sweep_walk:attempts=2,max_edges=120` finished at the cap:
  `MAP_CRAWL_FINISH ... reason=max_edges edges=120`, with summary stats
  `visited=30`, `passable=20`, `unknown=68`, `dynamic=1`, `transitions=7`,
  `unsafe_aborts=0`.
- Checked logs showed no `position_drift`, `movement_drift`,
  `auto_step_lost`, `return_to_frontier_blocked`, `backtrack_blocked`, or
  `inject_limit=12` during these post-reload runs.
- The broad run exported review-only candidates:
  passthrough candidates `(4,3)`, `(5,3)`; directional candidates
  `(1,2).south`, `(2,2).south/east`, `(2,6).south`, `(3,6).south`,
  `(3,9).east`, `(4,10).north`, `(4,2).south`, `(4,4).north`,
  `(5,2).south`, `(5,4).north`, `(5,6).south`, `(5,9).west`,
  `(6,2).south`, `(6,4).north`, `(6,6).south`, `(7,2).south`; closed door
  frontier `(4,6)`; boundary-origin unstable cells `(1,3)` through `(1,8)`
  plus `(3,1)`. Treat all as review-only until separately verified from
  walked origins.
- Post-cap cleanup check:
  after the 120-edge cap, a fresh baseline at `(2,3)` was responsive and a
  follow-up `sweep_walk:attempts=2,max_edges=20` finished at cap with
  `unsafe_aborts=0`. This validates command polling, NPC restore, and crawler
  cleanup after capped runs.

### Locked-Room Door Candidate Follow-Up

- After patching verified walked blockers around the lower locked-room route,
  `verify_door_stand:4,9,down` rerouted from `(3,13)` and reached `(14,10)`,
  then blocked twice on `(14,10)->RIGHT` into `(15,10)` and aborted before
  `DOOR_VERIFY_READY`.
- Direct same-origin `verify_walked_edge:14,10,right` reproduced the block,
  but the probe report was NPC-contaminated:
  `npc_blocked=true`, `permanent_blocked=false`, `directional_blocked=false`.
- `report_npcs` immediately afterward showed `Guard 1` at `(15,10)`.
  Normal pathfinding to `(4,9)` returned `No path found`, while
  `debug_pathfind_to_skip_npcs:4,9` and `debug_pathfind_to_park_npcs:4,9`
  both found `Path: 1 east, 1 north, 11 west`.
- Interpretation:
  do not promote `(15,10).west` as a permanent Garinham blocker from this
  evidence. The failure is dynamic NPC/parking contamination.
- Patch under test:
  `walked_edge_verifier.lua` now requests full NPC parking
  (`park_mobile_npcs=true`, `park_stationary_npcs=true`) for verifier
  route-to-origin autowalks. This keeps normal gameplay autowalk defaults
  unchanged, but makes forensic door/edge verifier routes match the fully
  parked diagnostic path.
- Regression checks passed:
  `lua test_walked_edge_verifier.lua`,
  `lua test_sweep_walk_command_surface.lua`,
  `luac -p walked_edge_verifier.lua test_walked_edge_verifier.lua main.lua
  route_manager.lua`, and
  `git diff --check -- walked_edge_verifier.lua test_walked_edge_verifier.lua`.
- Next live action:
  reload `main.lua`, then retry `verify_door_stand:4,9,down`. Expected
  improvement: route-to-origin should park all active NPC slots before
  planning/walking, so `(15,10)` guard clutter should no longer masquerade as
  map geometry.

### `(15,10).west` Recheck After Full NPC Parking

- After reload, `WALKED_EDGE_VERIFIER_BUILD` included `full_npc_parking`.
- Baseline before retry:
  `POSITION: map=0x09(Garinham) x=14 y=10`; menu closed; keys `6`;
  opened-door RAM empty; `RUNTIME_BLOCKS map=0x09 none`.
- Retried `verify_door_stand:4,9,down`.
  Route-to-origin did use the new full parking behavior:
  `AUTO_WALK_NPC_PARK_START ... parked_slots=15`;
  `npc_blocks=0`; planned route `Path: 1 east, 1 north, 11 west`.
- Despite all NPCs parked, the route blocked twice on
  `(14,10)->RIGHT` into `(15,10)` and aborted before `DOOR_VERIFY_READY`.
- Clean isolating check:
  `park_npcs report_npcs verify_walked_edge:14,10,right`.
  With all 15 NPC slots manually parked, same-origin raw probe still blocked:
  `EDGE_PROBE_RESULT ... status=blocked ... npc_blocked=false
  permanent_blocked=false ... reason=raw_hold_timeout`, followed by
  `EDGE_PROBE_MODEL_MISMATCH ... kind=blocked_despite_open_preview ...
  runtime_approach_blocked=false`.
- `restore_parked_npcs` restored all 15 slots, and position stayed `(14,10)`.
- Promoted `(15,10).west` in `MAP_DIRECTIONAL_BLOCKS[0x09]`; this supersedes
  older `probe_edge_verify` moved evidence that is now considered stale.
- Red/green checks:
  the new `test_map_reader.lua` assertion first failed with
  `(15,10).west ... expected true, got nil`; after patching
  `["15,10"] = {south = true, west = true}`, checks passed:
  `lua test_map_reader.lua`, `luac -p map_reader.lua test_map_reader.lua`,
  and `git diff --check -- map_reader.lua test_map_reader.lua`.
- Next live action:
  reload `main.lua` in FCEUX, then retry `verify_door_stand:4,9,down` from
  the current `(14,10)` state.

### Lower Pocket Door Disproof and `(1,13)` Passthrough

- After the user manually OPENed around the small lower pocket,
  `verify_door_after` for stand `(3,10)` facing right into `(4,10)` logged
  `expected_present=false`, `keys_before=6`, `keys_after=6`, `key_delta=0`,
  and `before_slots=none after_slots=none`. This disproves the `(4,10)` door
  hypothesis; the repeated dialogue was `There is no door here.`
- Fresh baseline afterward: `POSITION: map=0x09(Garinham) x=2 y=10`,
  menu closed, opened-door RAM empty, `RUNTIME_BLOCKS map=0x09 none`.
- `debug_route_frontier_skip_npcs:4,9,40` and `:4,10,40` reported the
  immediate pocket frontiers as blocked directional edges, with only two
  hidden bridge candidates into the target-side island:
  `(2,13)->LEFT` and `(1,14)->UP`, both into `(1,13)`.
- Walked verifier results:
  - `(2,13)->LEFT` into `(1,13)` moved through the type-2 wall and carried to
    `(0,13)`.
  - `(0,13)->RIGHT` moved back through `(1,13)` and carried to `(2,13)`.
  - `(1,14)->UP` moved directly into `(1,13)`.
  - `(1,13)->UP` into `(1,12)` blocked with `reason=raw_hold_timeout`.
  - `(1,13)->DOWN` moved through `(1,14)` and carried to `(1,15)`.
- Promoted `MAP_PASSTHROUGH_CELLS[0x09]["1,13"] = true` and
  `MAP_DIRECTIONAL_BLOCKS[0x09]["1,12"].south = true`. Regression started red
  on missing `(1,12).south`, then passed after patching:
  `lua test_map_reader.lua`, `luac -p map_reader.lua test_map_reader.lua`,
  and `git diff --check -- map_reader.lua test_map_reader.lua`.
- Next live action: reload `main.lua`, then rerun the lower-pocket
  frontier/pathfind checks to confirm the new hidden cell no longer creates a
  false route into `(4,9)/(4,10)`.

### Sweep Boundary-Frontier Reporting Fix

- After reload, lower-pocket checks confirmed the `(1,13)` patch behaved as
  intended:
  `debug_route_frontier_skip_npcs:4,9,60` and `:4,10,60` both reported
  `target_reachable=false` with `hidden_bridge_candidates=0`, while
  `debug_pathfind_to_skip_npcs:1,13` found `Path: 2 north`.
- A follow-up `sweep_walk:attempts=2,max_edges=120` from `(1,15)` completed
  naturally after 13 edges, with no passthrough, directional, dynamic, or
  unsafe-abort candidates. Runtime state remained clean afterward:
  `POSITION ... x=1 y=15`, menu closed, `RUNTIME_BLOCKS map=0x09 none`,
  opened-door RAM empty.
- The run exposed a reporting bug, not map evidence: engine-boundary
  `boundary_frontier` preflight skips were counted/exported as observed
  transitions. Example JSON had `status="transition"` and
  `source_classification="boundary_frontier"` for `(1,13)->LEFT`.
- Patched `map_crawler.lua` so `boundary_frontier` still marks its origin
  unstable but no longer enters `report.transitions` and exports as an
  `unknown` edge instead of a map transition. Added regression coverage in
  `test_map_crawler.lua`.
- Checks passed:
  `lua test_map_crawler.lua` (45 tests),
  `lua test_sweep_walk_command_surface.lua`,
  `lua test_map_reader.lua`,
  `luac -p map_reader.lua test_map_reader.lua map_crawler.lua
  test_map_crawler.lua test_sweep_walk_command_surface.lua`, and
  `git diff --check -- map_reader.lua test_map_reader.lua map_crawler.lua
  test_map_crawler.lua work_notes/current_investigation.md`.
- Next live action: reload `main.lua`, rerun the same small sweep from the
  current `(1,15)` state, and verify boundary-frontier edges appear under
  `unknowns` with `transitions=0`.
- After reload, the same `sweep_walk:attempts=2,max_edges=120` from `(1,15)`
  completed naturally after 13 edges and verified the reporting fix live:
  `MAP_CRAWL_FINISH ... transitions=0`; summary says `Unknown edges: 9` and
  `Map transitions found: 0`; JSON has boundary-frontier records under
  `unknowns` with `status="unknown"` and `transitions=[]`. Post-run state
  stayed clean at `(1,15)` with menu closed, no runtime blocks, and empty
  opened-door RAM.

### Map-Crawl Early-Twitch Repress Tuning

- A larger `sweep_walk:attempts=2,max_edges=120` from `(3,13)` finished safely
  at the cap after the boundary-frontier fix: `visited=30`, `edges=120`,
  `passable=20`, `blocked=21`, `confirmed_blockers=0`, `unknown=79`,
  `dynamic=0`, `transitions=0`, `unsafe_aborts=0`.
- Post-run cleanup was good:
  `POSITION ... x=8 y=12`, menu closed, `RUNTIME_BLOCKS map=0x09 none`, and
  opened-door RAM empty.
- The high unknown count was almost entirely first-attempt timing noise:
  JSON grouped `unknowns` as `boundary_frontier=3` and `mixed_probe=76`.
  Recent log examples showed a short map-crawl press seeing an early subpixel
  twitch, timing out as blocked, then a retry moving in about 17 frames from
  the same tile. Interpretation: the first press likely only turned/faced the
  hero but the early movement byte suppressed the normal turn re-press path.
- Patch under test:
  `auto_step.lua` now allows only `source="map_crawl"` early subpixel twitches
  to use the existing short same-direction turn re-press path before timeout.
  Normal manual/debug probes and queued routes keep their previous early-twitch
  safeguards.
- Red/green coverage:
  added `map_crawl_early_subpixel_twitch_can_turn_repress_before_timeout`;
  it failed before the patch, then passed after the source-gated change.
- Checks passed:
  `lua test_auto_step.lua`, `lua test_map_crawler.lua`,
  `lua test_sweep_walk_command_surface.lua`,
  `luac -p auto_step.lua test_auto_step.lua map_crawler.lua
  test_map_crawler.lua test_sweep_walk_command_surface.lua main.lua`, and
  `git diff --check -- auto_step.lua test_auto_step.lua`.
- Next live action:
  reload `main.lua`, then rerun a small/medium sweep from the current
  Garinham state. Expected improvement: fewer `mixed_probe` unknowns from
  open edges, with no return of position drift or extra-tile carry.
- After reload, baseline was clean at `(8,12)` with menu closed, no runtime
  blocks, and empty opened-door RAM. A medium
  `sweep_walk:attempts=2,max_edges=60` from `(8,12)` finished safely at cap:
  `visited=23`, `edges=60`, `passable=20`, `confirmed_blockers=4`,
  `unknown=29`, `dynamic=0`, `transitions=0`, `unsafe_aborts=0`.
  Cleanup remained clean at `(3,14)` with no runtime blocks or door RAM.
- The first patch was live but incomplete: logs showed map-crawl early-twitch
  re-presses firing, but most mixed probes were caused by late subpixel
  twitches around frame 16 after the short inject window. Those late twitches
  suppressed the turn re-press path and then timed out as false blocked
  attempts before the retry moved cleanly.
- Second patch under test:
  map-crawl no-coordinate movement twitches, early or late, may now use the
  same short same-direction turn re-press before timeout. This remains gated to
  `source="map_crawl"`; manual/debug probes and queued routes keep the older
  behavior.
- Added red/green coverage:
  `map_crawl_late_subpixel_twitch_can_turn_repress_before_timeout` failed
  before the patch and passed afterward. Current checks passed:
  `lua test_auto_step.lua`, `lua test_map_crawler.lua`,
  `lua test_sweep_walk_command_surface.lua`,
  `luac -p auto_step.lua test_auto_step.lua map_crawler.lua
  test_map_crawler.lua test_sweep_walk_command_surface.lua main.lua`, and
  `git diff --check -- auto_step.lua test_auto_step.lua`.
- Next live action:
  reload `main.lua` again and rerun a medium sweep from the current Garinham
  state. Expected improvement: the frame-16 late-twitch mixed probes should
  convert to first-attempt passable or modeled-blocked results without
  position drift.
- After reload, the second patch proved unsafe. A
  `sweep_walk:attempts=2,max_edges=60` from `(3,14)` aborted after 4 edges:
  `MAP_CRAWL_FINISH ... reason=position_drift`. Root cause was extra-tile
  carry after a map-crawl re-press: `(3,13)->DOWN` completed to `(3,14)` only
  3 frames after the re-press, then live position kept moving to `(3,15)` while
  the crawler expected `(3,14)`.
- The movement-twitch re-press approach is rejected for now. It can reduce
  some `mixed_probe` noise, but it is not safe for normal-movement sweep
  validation because it can corrupt the crawler's live origin.
- Rollback/safety patch under test:
  map-crawl early and late movement twitches must not schedule a same-direction
  turn re-press before timeout. Updated regression coverage to
  `map_crawl_early_subpixel_twitch_does_not_turn_repress_before_timeout` and
  `map_crawl_late_subpixel_twitch_does_not_turn_repress_before_timeout`.
  Kept `map_crawl_success_force_releases_sticky_direction_after_completion`
  as a guard for neutral release after successful crawler probes.
- Checks passed after rollback:
  `lua test_auto_step.lua`, `lua test_map_crawler.lua`,
  `lua test_sweep_walk_command_surface.lua`,
  `luac -p auto_step.lua test_auto_step.lua map_crawler.lua
  test_map_crawler.lua test_sweep_walk_command_surface.lua main.lua`, and
  `git diff --check -- auto_step.lua test_auto_step.lua`.
- Next live action:
  reload `main.lua`, then rerun a small/medium sweep from the current
  Garinham state. Expected result is safety first: no `position_drift` or
  extra-tile carry. `mixed_probe` unknowns may return until a safer scanner
  classification strategy is designed.
- After reload, rollback validation passed. Baseline at `(3,15)` was clean
  with menu closed, no runtime blocks, and empty opened-door RAM. A
  `sweep_walk:attempts=2,max_edges=60` from `(3,15)` finished safely at cap:
  `visited=14`, `edges=60`, `passable=12`, `blocked=13`,
  `confirmed_blockers=0`, `unknown=35`, `dynamic=0`, `transitions=0`,
  `unsafe_aborts=0`.
- `dw_crawl_09.txt` exported no passthrough or directional additions. The JSON
  unknowns were `mixed_probe=32` plus `boundary_frontier=3`, matching the
  expected conservative rollback behavior. Log scan found no `position_drift`,
  `movement_drift`, `auto_step_lost`, `return_to_frontier_blocked`,
  `backtrack_blocked`, or map-crawl `schedule turn repress` lines.
- Post-run cleanup stayed clean at `(1,15)`: menu closed,
  `RUNTIME_BLOCKS map=0x09 none`, opened-door RAM empty. Safety is restored;
  remaining work is scanner/reporting strategy for noisy `mixed_probe` edges
  or moving to another sweep area.
- Follow-up complete-run check from `(1,15)` also passed:
  `sweep_walk:attempts=2,max_edges=120` completed naturally after 13 edges
  with `passable=2`, `blocked=2`, `unknown=9`, `dynamic=0`, `transitions=0`,
  `unsafe_aborts=0`, and no exported passthrough/directional candidates.
  Unknowns were the expected `mixed_probe=6` plus `boundary_frontier=3`.
- Post-run cleanup again stayed clean at `(1,15)` with menu closed, no runtime
  blocks, and empty opened-door RAM. This validates both rollback safety and
  the boundary-frontier reporting behavior in the small lower pocket.
- Routed from `(1,15)` to the broader Garinham component at `(8,12)` by normal
  `auto_walk`; route completed and cleanup was clean: menu closed,
  `RUNTIME_BLOCKS map=0x09 none`, opened-door RAM empty.
- Broad stress sweep from `(8,12)`:
  `sweep_walk:attempts=2,max_edges=120` finished at cap after 332 seconds with
  `visited=35`, `edges=120`, `passable=20`, `blocked=22`,
  `confirmed_blockers=3`, `unknown=78`, `dynamic=0`, `transitions=0`,
  `unsafe_aborts=0`. Log scan found no drift/unsafe markers. Post-run state
  was `(2,15)`, menu closed, no runtime blocks, and empty opened-door RAM.
- The broad sweep exported three review-only directional candidates:
  `["6,17"] = {east = true}`, `["7,18"] = {north = true}`, and
  `["8,17"] = {west = true}`. All came from the same walked origin `(7,17)`,
  where down/left/right blocked twice each. The north approach into `(7,17)`
  stayed usable.
- Follow-up non-teleport walked verifiers confirmed the three candidates:
  `verify_walked_edge:7,17,down`, `verify_walked_edge:7,17,left`, and
  `verify_walked_edge:7,17,right` each logged `EDGE_PROBE_RESULT ... status=blocked`
  with `permanent_blocked=false`, `npc_blocked=false`,
  `directional_blocked=false`, and `reason=raw_hold_timeout`.
- Promoted those three Garinham directional blockers in `map_reader.lua` and
  added `test_map_reader.lua` assertions, including an open-approach guard for
  `(7,17).north`. Checks passed: `lua test_map_reader.lua`,
  `luac -p map_reader.lua test_map_reader.lua`, and
  `git diff --check -- map_reader.lua test_map_reader.lua`.
- After reload, a new `sweep_walk:attempts=2,max_edges=120` from `(7,17)`
  verified that the previously patched `(7,17)` cluster no longer exported.
  The run finished at cap after 344 seconds with `visited=47`, `edges=120`,
  `passable=14`, `blocked=16`, `confirmed_blockers=3`, `unknown=90`,
  `dynamic=0`, `transitions=0`, and `unsafe_aborts=0`. Unknowns were all
  `mixed_probe`. Post-run cleanup was clean at `(14,12)` with menu closed,
  no runtime blocks, and empty opened-door RAM.
- The second broad-component sweep exported three review-only directional
  candidates: `["8,16"] = {north = true}`,
  `["10,17"] = {north = true}`, and `["9,16"] = {east = true}`.
  They came from walked origins `(8,15)` and `(10,16)`.
- Follow-up non-teleport walked verifiers confirmed all three:
  `verify_walked_edge:8,15,down`, `verify_walked_edge:10,16,down`, and
  `verify_walked_edge:10,16,left` each logged `EDGE_PROBE_RESULT ... status=blocked`
  with `permanent_blocked=false`, `npc_blocked=false`,
  `directional_blocked=false`, and `reason=raw_hold_timeout`.
- Promoted those three Garinham directional blockers in `map_reader.lua` and
  added `test_map_reader.lua` assertions, including open-approach guards for
  `(8,15).north` and `(10,16).north`. Checks passed:
  `lua test_map_reader.lua`, `luac -p map_reader.lua test_map_reader.lua`,
  and `git diff --check -- map_reader.lua test_map_reader.lua`.
- After reload, a third `sweep_walk:attempts=2,max_edges=120` from `(10,16)`
  verified that the previously patched `(8,15)/(10,16)` cluster no longer
  exported. The run finished at cap after 341 seconds with `visited=48`,
  `edges=120`, `passable=19`, `blocked=20`, `confirmed_blockers=1`,
  `unknown=81`, `dynamic=0`, `transitions=0`, and `unsafe_aborts=0`.
  Unknowns were all `mixed_probe`. Post-run cleanup was clean at `(2,12)`
  with menu closed, no runtime blocks, and empty opened-door RAM.
- The third broad-component sweep exported one review-only directional
  candidate: `["9,16"] = {north = true}`, from walked origin `(9,15)`.
- Follow-up non-teleport walked verifier `verify_walked_edge:9,15,down`
  routed to `(9,15)` from the west, then logged `EDGE_PROBE_RESULT ... status=blocked`
  with `permanent_blocked=false`, `npc_blocked=false`,
  `approach_blocked=false`, and `reason=raw_hold_timeout`. The destination
  already had a different verified face, so `directional_blocked=true` in the
  log was expected and did not self-confirm the new north approach.
- Promoted `(9,16).north` by merging it with the existing `(9,16).east`
  Garinham directional entry, and added `test_map_reader.lua` assertions with
  an open-approach guard for `(9,15).west`. Checks passed:
  `lua test_map_reader.lua`, `luac -p map_reader.lua test_map_reader.lua`,
  and `git diff --check -- map_reader.lua test_map_reader.lua`.
- After reload, the next `sweep_walk:attempts=2,max_edges=120` from `(9,15)`
  no longer exported the prior `(9,16)` candidate, but stopped after 76 edges
  with `completed=false reason=backtrack_blocked`. The exported review
  candidate was `["6,17"] = {north = true}` from walked origin `(6,16)`.
- The abort edge `(7,17)->UP` did not reproduce as map geometry:
  `verify_walked_edge:7,17,up` moved through the destination, with one extra
  carry tile to `(7,15)`. Treat the backtrack abort as timing/noise for now,
  not a permanent `(7,16).south` blocker.
- The `(6,17).north` candidate was also not clean map evidence. JSON/logs
  showed `(6,16)` is tile type 2 and modeled non-walkable; the sweep reached
  it only through mixed/noisy `(6,15)->DOWN` probes, then walked right to
  `(7,16)`. A walked verifier for `(6,16)->DOWN` could not route to the
  origin because `target_walkable=false`.
- Root cause fixed in `map_crawler.lua`: a mixed probe into a model-blocked
  false-wall cell now marks that cell unstable with
  `reason=mixed_false_wall_origin`, which makes DFS backtrack instead of
  exploring/exporting blockers from the untrusted origin. Added the regression
  `blocked_edge_from_mixed_false_wall_origin_stays_diagnostic` in
  `test_map_crawler.lua`.
- Checks passed after the crawler fix: `lua test_map_crawler.lua`,
  `lua test_sweep_walk_command_surface.lua`, `lua test_map_reader.lua`, and
  `luac -p map_crawler.lua test_map_crawler.lua`.
- Next live action: reload `main.lua` in FCEUX, then rerun a medium or broad
  sweep from the current Garinham state. Expected result: mixed false-wall
  origins such as `(6,16)` should become unstable/unknown review data and no
  longer export downstream directional blockers.
- After reload, the first timing-suspect split validation sweep from `(7,15)`
  reached the 120-edge cap cleanly after 340 seconds: `visited=38`,
  `frontier=33`, `passable=107`, `unknown=13`, `dynamic=0`,
  `transitions=0`, `unsafe_aborts=0`, and no passthrough/directional exports.
  JSON grouping was `open_floor=107` and `timing_suspect_blocked=13`; many
  open edges carried `note=timing_suspect_retry`, confirming the split kept
  transient movement-start timeouts review-only while allowing later successful
  probes to count as passable.
- A second validation sweep from `(13,12)` also reached the 120-edge cap
  cleanly after 345 seconds: `visited=37`, `frontier=31`, `passable=99`,
  `unknown=20`, `dynamic=1`, `transitions=0`, `unsafe_aborts=0`, and no
  passthrough/directional exports. The single dynamic item was an informational
  closed-door frontier at `(17,10)`; `dw_crawl_09.txt` also excluded one
  unstable timing-suspect false wall at `(15,18)`.
- Post-run state stayed clean at `(19,14)`: menu closed, runtime blocks empty,
  opened-door RAM empty. The timing-suspect split is live-validated enough to
  continue broader sweep investigation without the previous false directional
  candidates corrupting results.
- A third validation sweep from `(19,14)` reached the 120-edge cap cleanly
  after 339 seconds: `visited=49`, `frontier=46`, `passable=101`,
  `unknown=18`, `dynamic=1`, `transitions=0`, `unsafe_aborts=0`, and again no
  passthrough/directional exports. The JSON groups were `open_floor=101`,
  `timing_suspect_blocked=17`, `timing_suspect_false_wall=1`, and
  `door_frontier=1`. The closed door frontier was again `(17,10)`; the
  unstable excluded false-wall cell was `(13,18)`.
- Post-run state after run 3 remained clean at `(9,14)`: menu closed, runtime
  blocks empty, opened-door RAM empty. Across three post-fix live runs, the
  walker tested 360 edges with zero permanent candidate exports, zero unsafe
  aborts, and timing-noise retained in review-only buckets.
- A fourth validation sweep from `(9,14)` reached the 120-edge cap cleanly
  after 337 seconds: `visited=38`, `frontier=28`, `passable=98`,
  `unknown=22`, `dynamic=0`, `transitions=0`, `unsafe_aborts=0`, and no
  passthrough/directional exports. The JSON groups were `open_floor=98`,
  `timing_suspect_blocked=20`, and `timing_suspect_false_wall=2`; the unstable
  excluded false-wall cells were `(4,16)` and `(6,16)`.
- Post-run state after run 4 remained clean at `(2,13)`: menu closed, runtime
  blocks empty, opened-door RAM empty. Across four post-fix live runs, the
  walker tested 480 edges with zero permanent candidate exports and zero unsafe
  aborts. The remaining output is conservative diagnostic data rather than map
  patch material.

## Swamp Cave Hostile Sweep Setup

- Baseline after teleport to map `0x15` `(3,23)` showed the script alive, but
  `sweep_walk` refused to start because `PREV.dialogue` contained the false
  lower text fragment `llHP  86`.
- `report_upper_dialogue_state` confirmed this was status-display leakage, not
  real dialogue: base 0 row 4 decoded `llHP  86` while base 1 held the matching
  status fragments (`Bi`, `LV`, `HP`, `MP`, `G21`).
- Root cause: the existing passive status-noise suppression rejected strings
  containing spaces, so fused name-suffix/status-value fragments such as
  `llHP  86` could stabilize and block movement-changing commands.
- Patched `text.lua` to drop fused name-suffix/status-value rows when status
  context is visible, and to classify the same shape as passive field status
  noise. Added focused regressions in `test_text.lua`.
- Checks passed: `lua test_text.lua`, `lua test_sweep_walk_command_surface.lua`,
  `luac -p text.lua test_text.lua main.lua`, and
  `git diff --check -- text.lua test_text.lua`.
- Next live action after FCEUX Lua reload: verify `report_upper_dialogue_state`
  and `report_menu_state` no longer show active `PREV.dialogue`, then retry
  `sweep_walk:attempts=2,max_edges=120` from Swamp Cave `(3,23)`.

## Swamp Cave Command-Menu Text Noise Follow-Up

- After reload, command menu activity on map `0x15` still produced false
  dialogue events, but the new evidence was upper/status classification rather
  than the previous lower-dialogue stale state.
- Fresh log examples: `V  15 llHP  86 1MP  54 8G21530 5E12610 530 610 Bill`,
  `L llH 1M 8G 5E 530 610 Bill`, and a real command-result line contaminated
  as `'There is no one llH there.`
- `report_upper_dialogue_state` at frame 12360 showed `lower=""` and
  `PREV.dialogue_len=0`, confirming the previous lower-reader fused-value fix
  was working. The remaining visible upper baseline was
  `L llH 1M 8G 5E 530 610 Bill`.
- Root cause: `text.is_status_text()` did not recognize these scrolled
  command-menu/status fragments, and the lower row cleaner did not strip short
  inline fused status tokens such as `llH` from otherwise real command results.
- Patched `text.lua` to classify the scrolled command-menu status strings as
  status text and to strip short inline fused status tokens when status context
  is visible. Added focused regressions in `test_text.lua`.
- Checks passed: `lua test_text.lua`, `lua test_sweep_walk_command_surface.lua`,
  `luac -p text.lua test_text.lua main.lua`, and
  `git diff --check -- text.lua test_text.lua`.
- Next live action after FCEUX Lua reload: try several command-menu
  open/close and failed command-result cases here, then run
  `report_upper_dialogue_state report_menu_state` before restarting
  `sweep_walk`.
- After the next reload, the real command-result line was clean, but the
  overlap-stripped upper fragment `llH 1M 8G 5E 530 610 Bill` still announced
  after command text cleared. The full upper row `L llH ...` was covered by
  the previous regression, but the extracted fragment without the leading `L`
  was not.
- Added that extracted-fragment shape to `text.is_status_text()` coverage so
  `check_upper_dialogue()` suppresses it before speech.
- After the next reload, spell command text was still mangled when status
  shards were glued to real words: `Bill chanted the spell llHof HURT.` and
  `1MBut nothing happened.` The command-menu garbage itself was suppressed
  (`UPPER_DIALOGUE_SUPPRESS_STATUS` logged for the upper fragment), so this was
  a lower-reader inline cleanup issue.
- Patched the status-context cleaner to strip short status prefixes from the
  front of a token while preserving the real suffix, e.g. `llHof` -> `of` and
  `1MBut` -> `But`. Added a focused regression in `test_text.lua`.
- Hostile sweep run 1 on map `0x15` walked north from `(3,23)` to `(3,19)`,
  then a Ghost encounter started during the `(3,19)->up` probe. The sweep did
  not crash: it exported `sweep_walk_15_run001.json` and stopped with one
  unsafe abort, but the reason was the generic `auto_step_lost`.
- Root cause: the crawler only received `can_walk=false`; when `auto_step`
  cancelled the active probe in battle, the crawler had no state context to
  distinguish a hostile-area graceful exit from a generic orphaned step.
- Patched `main.lua` to pass the current game state into `map_crawler.tick`,
  and patched `map_crawler.lua` to export `battle_interrupted` with note
  `battle_started_during_probe` when an active sweep probe is interrupted by
  battle. Added `test_map_crawler.lua` coverage that checks logs, JSON,
  summary, and heartbeat status.
- Checks passed: `lua test_map_crawler.lua`, `lua test_sweep_walk_command_surface.lua`,
  `luac -p map_crawler.lua test_map_crawler.lua main.lua`, and
  `git diff --check -- map_crawler.lua test_map_crawler.lua main.lua`.
- Next live action after FCEUX Lua reload: from a field state in Swamp Cave,
  rerun a small hostile sweep and confirm encounter interruptions finish with
  `reason=battle_interrupted` / `source_classification=battle_interrupted`
  instead of `auto_step_lost`.
- Live validation after FCEUX reload passed. Baseline probe consumed commands
  at map `0x15` `(3,19)` with menu closed, no runtime blocks, and no path
  target. `sweep_walk:attempts=2,max_edges=120` then ran for 39 seconds,
  visited 9 cells, tested 19 edges, and was interrupted by a Green Dragon
  battle during `(4,14)->up`.
- The live log, heartbeat, summary, and JSON all reported
  `reason=battle_interrupted` / `source_classification=battle_interrupted`
  with note `battle_started_during_probe`. The run exported one
  `unsafe_abort`, 12 passable edges, 6 timing-suspect unknowns, 0 confirmed
  blockers, 0 directional/passthrough candidates, and 0 transitions. This is a
  validated hostile-area graceful exit, not map patch evidence.
- Current live cave state after the validation: battle is active against a
  Green Dragon. Another sweep requires the battle to be resolved or the state
  to be restored/repositioned back to field control.

## Swamp Cave Manual-Move Hang Toward Gwaelin Door

- After the player defeated the Green Dragon, field play resumed at map `0x15`
  near `(4,14)`. Object navigation selected `Gwaelin Door`; route planning
  logged viable paths from `(4,14)`, `(4,15)`, and `(5,15)`.
- While the player manually worked toward the door, `auto_step` repeatedly
  started physical `manual_tap` holds from `(5,15)`, saw early subpixel
  movement twitches, and cancelled when live input changed direction. The last
  log line before command polling died was:
  `auto_step cancel: different live direction pressed`.
- A fresh `launcher_probe:hung_probe` command timed out and remained
  unconsumed, while `dw_script_error.log` had no new stack trace. This points
  to the script loop wedging after the live-direction cancel path rather than
  a normal caught Lua error.
- Root-cause hypothesis with code evidence: the `different live direction`
  cancel branch reset Lua auto-step state but did not emit a neutral
  `joypad.set` frame, unlike blocked/completed/early-twitch cancel paths. In
  sticky FCEUX-style input, that can leave the previous script-owned direction
  active while live keyboard input changes direction.
- Patched `auto_step.lua` so live-direction cancellation immediately clears
  the script-owned D-pad hold and schedules the normal short post-release
  cleanup. Added `test_auto_step.lua` coverage using sticky `joypad.set`
  behavior to prove the stale hold is flushed.
- Checks passed: `lua test_auto_step.lua` (80 tests),
  `lua test_sweep_walk_command_surface.lua`,
  `luac -p auto_step.lua test_auto_step.lua main.lua`, and
  `git diff --check -- auto_step.lua test_auto_step.lua`.
- Cleared the stale `launcher_probe:hung_probe` entry from `dw_commands.txt`
  with `DW_COMMAND_GUARD_ALLOW_RAW=1` so the next reload does not consume an
  old diagnostic command.
- Next live action after FCEUX Lua reload: verify command polling with a fresh
  probe, then reproduce the manual direction-change movement near the Gwaelin
  Door route before resuming `sweep_walk`.

## Swamp Cave Upper-Cell Sweep Follow-Up

- After FCEUX reload, command polling was live at map `0x15` `(3,15)`, menu
  closed, no active route, and no runtime blockers.
- Non-teleport `verify_walked_edge` checks reached each origin through normal
  movement and then raw-held into an open model preview that stayed blocked:
  - `(2,13)->DOWN` into `(2,14)`: `EDGE_PROBE_RESULT ... status=blocked`,
    `EDGE_PROBE_MODEL_MISMATCH kind=blocked_despite_open_preview`.
  - `(3,8)->RIGHT` into `(4,8)`: same-origin blocked result and model
    mismatch.
  - `(3,8)->DOWN` into `(3,9)`: same-origin blocked result and model
    mismatch.
- Injected runtime continuity blockers for the live session:
  `add_blocked_edge:2,13,DOWN`, `add_blocked_edge:3,8,RIGHT`, and
  `add_blocked_edge:3,8,DOWN`, producing runtime entries
  `(2,14).north`, `(4,8).west`, and `(3,9).north`.
- Promoted the three clean edges to `map_reader.lua` under map `0x15` and
  added focused assertions in `test_map_reader.lua`.
- Red/green evidence:
  - Before the map patch, `lua test_map_reader.lua` failed in
    `swamp_cave_west_edge_corridor_overrides_boundary` because `dirs["2,14"]`
    was missing.
  - After the patch, `lua test_map_reader.lua` passed all 51 tests.
  - Additional checks passed:
    `luac -p map_reader.lua test_map_reader.lua`,
    `git diff --check -- map_reader.lua test_map_reader.lua`, and
    `lua test_sweep_walk_command_surface.lua`.
- Continued hostile-area `sweep_walk` with the runtime overlay active:
  - Run 1 from `(3,8)` ended with `reason=battle_interrupted` after 18 edges,
    7 visited cells, 12 passable edges, 4 timing-suspect unknowns, 1
    stationary-NPC/dynamic edge, 0 confirmed blockers, 0 directional exports,
    and 0 passthrough exports.
  - After command polling survived the Ghost fight, run 2 from `(5,8)` ended
    with `reason=battle_interrupted` after 31 edges, 12 visited cells, 24
    passable edges, 5 timing-suspect unknowns, 1 stationary-NPC/dynamic edge,
    0 confirmed blockers, 0 directional exports, and 0 passthrough exports.
- Current live state after run 2: sweep finalized successfully and then a
  Druin battle continued. Do not queue more movement until the fight is
  resolved or the state is reloaded.
- Reload note: the permanent map patch requires FCEUX Lua reload to replace
  the live runtime overlay with static `map_reader.lua` data.

## Swamp Cave Stat Corruption During Hostile Sweep

- After a later hostile-area sweep/fight sequence, `h` and `log_state`
  confirmed gameplay-effective stat corruption, not only speech noise:
  map `0x15` `(2,11)`, level 15, `hp=80/15`, `mp=58/0`,
  `STR=0x04`, `AGI=0x03`, `ATK=0x18`, `DEF=0x25`, spells `CE=0x00`.
  This explains the user's report that a trash mob took abnormally long to
  kill.
- Earlier captured logs showed the stat tail flip from clean
  `44 39 56 40 58 40 FF 10` to corrupt `04 03 0F 00 18 25 00 10`
  shortly before the battle-start event, while still in field state. The
  strongest current suspect was crawler step-outcome stabilization calling
  `auto_step.reset_movement_engine_state()` during sweep probe completion,
  block handling, and settle frames.
- Patched `map_crawler.lua` so crawler stabilization still force-releases
  script-owned input with `auto_step.cancel_active_step(true, true)`, but no
  longer writes movement RAM through `reset_movement_engine_state()`. Added
  regression coverage in `test_map_crawler.lua` that completed probes and
  settle frames do not call movement reset.
- Checks passed: `lua test_map_crawler.lua`,
  `lua test_sweep_walk_command_surface.lua`,
  `luac -p map_crawler.lua test_map_crawler.lua`, and
  `git diff --check -- map_crawler.lua test_map_crawler.lua`.
- Follow-up log clue: at frame 63998, a new Green Dragon battle produced
  `PLAYER_STAT_FRAMEADVANCE_TRANSITION from=bad to=clean`, restoring
  `hp=86/86`, `mp=62/64`, spells `CE=0xFF`, and normal combat stats before
  the battle menu. This suggests battle setup can refresh the corrupted stat
  mirror, so live validation should start from a known-clean state and then
  watch for a fresh `bad` transition during sweep.
- Next live action after FCEUX Lua reload: start from clean stats, run a small
  hostile `sweep_walk`, and confirm no `PLAYER_STAT_INTEGRITY_TRANSITION
  from=clean to=bad` or corrupted `h` output appears while sweep probes and
  battle interruptions occur.
- Live validation after reload/restored save: baseline at map `0x15` `(4,14)`
  was clean (`hp=84/86`, `mp=58/64`, normal level-15 stats, spells
  `CE=0xFF CF=0x10`) with no runtime blockers.
- Hostile `sweep_walk:attempts=2,max_edges=120,park_mobile_npcs=false` ran
  from `(4,14)` for 79 seconds, visited 31 cells, tested 95 edges, and stopped
  with `reason=battle_interrupted` when a Ghost encounter started during
  `(0,20)->DOWN`. The battle-start snapshot and post-sweep battle probe both
  kept clean stats; no `PLAYER_STAT_*` warnings appeared.
- After defeating the Ghost, field baseline at `(0,20)` remained clean. A
  second `sweep_walk:attempts=2,max_edges=80,park_mobile_npcs=false` tested 15
  more edges and stopped with `reason=battle_interrupted` on a Magician
  encounter during `(0,6)->UP`. The battle-start snapshot and post-battle
  field probe again kept clean stats with no stat-integrity warnings.
- Current evidence: removing crawler movement-RAM resets appears to have fixed
  the sweep-induced stat corruption path. Remaining Swamp Cave sweep output
  contains no confirmed blockers or map patch candidates from these two runs;
  review-only data is timing-suspect/boundary/dynamic and should not be
  promoted.
