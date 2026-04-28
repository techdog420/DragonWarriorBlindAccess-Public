# Session Handoff - 2026-04-28

## Current Resume

Last live state:
- Runtime verification pass (2026-04-28): latest script reload and pathfinder hardening was smoke-tested in live mode via `freeze_npcs` and controlled `teleport_to`/`debug_pathfind_to`/`inspect_tile` flows.
- Map `0x08` Brecconary, player at `(10,25)` after the latest fresh parked
  survey.
- NPC parking restored at survey completion:
  `SURVEY_NPC_PARK_RESTORE run=1 map=0x08 restored=true restored_slots=20
  reason=complete`.
- Runtime blocks clear for Brecconary: `RUNTIME_BLOCKS map=0x08 none`.
- Latest completed parked survey after reloading the route-drift retry patch:
  `SURVEY_COMPLETE run=1 map=0x08 targets=21 successes=12 failures=9
  no_route=0 gated_or_isolated=9 movement_failed=0
  suspected_engine_blocked=0 state_issues=0 adjacency_issues=0`.
- Latest findings still have no block candidates:
  `SURVEY_STRONG_CANDIDATES map=0x08 none` and
  `SURVEY_FINDINGS map=0x08 run=1 failed_targets=9 failure_starts=4
  strong_reroute_candidates=0`.
- The retry-accounting patch behaved correctly live: `route_drift_retry` fired
  for `npc_8`, `npc_6`, and `npc_0`; those targets later succeeded.
- The remaining nine failures are all clean `gated_or_isolated_region` results.
- Retrying failed targets from the live `(10,25)` position is not useful:
  `SURVEY_START_STATUS map=0x08 mode=retry_failed start=(10,25) targets=9 ...
  status=isolated_start ... reachable_targets=0 unreachable_targets=9
  isolation_reason=low_target_coverage`.
- No permanent `map_reader.lua` patch is justified from this survey.
- The broad `export_blocks` command can still print old accumulated
  blocked-move observations across maps; do not treat it as the clean latest
  survey patch list.

Project direction:
- Brecconary/map `0x08` is clean enough to pause broad blocker hunting.
  Remaining failures look like NPCs in gated/isolated town regions, not missing
  doors/stairs/chests or map-data candidates.
- The project has enough decoded map data to begin real playtesting and
  player-facing quality-of-life improvements.
- Map `0x05` was rechecked in this cleanup pass: one prior runtime block at
  `(9,1)` rerouted successfully (`blocked_events=1`, `reroute_succeeded_after_runtime_block`)
  appears transient:
  - `pathfind_to:9,1` from `(8,1)` -> immediate `Path: 1 east`, `RUNTIME_BLOCKS map=0x05 none`.
  - `inspect_move` `(8,1)->right` -> `effective_passable=true`.
  - `pathfind_to:8,8` from `(6,1)` -> `RUNTIME_BLOCKS map=0x05 none`.
- No durable map-data patch for `0x05` is justified yet; keep it as confirmed transient.
- Historical naming note: this repo often treats map `0x04` as live Tantegel
  Castle and map `0x05` as the Tantegel Throne Room/interior. Confirm the live
  `POSITION` map id before making permanent map-data changes.

Best next step:
- Do not run Brecconary `retry_failed` from `(10,25)`.
- If continuing Brecconary for any reason, relocate deliberately to a useful
  open/central start and focus on object classification rather than hidden
  blocker discovery.
- Continue to require direct blocker evidence before changing permanent map
  data: `movement_failed`, `suspected_engine_blocked`, or a strong candidate.
- Do not use aggregate `retry_failed` from isolated pockets as blocker
  evidence; it is useful mainly as a preflight signal.

Current Brecconary truth:
- `(3,5) west` is confirmed blocked from route-context evidence; an earlier
  direct moved probe is considered noisy/subtile contamination.
- `(17,22)` is now pathfinder-forbidden: the survey entered it from the west,
  then direct probes confirmed LEFT/RIGHT/DOWN all block despite open previews,
  while NORTH is a wall; raw `LEFT,120` also stayed pinned.
- Previous Brecconary trap/edge fixes remain in place, including `(16,23)`,
  `(18,17)`, `(8,25)`, `(8,26)`, `(8,27) south`, and `(10,27) north/south`.
- `MAP_DIRECTIONAL_BLOCKS[0x08]["10,27"]` is now
  `{north = true, south = true}`; the south face is context-sensitive but
  unreliable enough during routed movement to avoid it.
- Broad survey starts now abort when target coverage is effectively stranded,
  preventing repeats of the misleading `(9,24)` southwest-pocket run.

Validation snapshot:
- `lua test_map_survey.lua` now passes `40/40`, including the new
  `route_drift_retry_is_still_allowed_after_transient_no_path_retry`
  regression.
- `luac -p map_survey.lua test_map_survey.lua` passed.
- `git diff --check -- map_survey.lua test_map_survey.lua` passed.
- `lua test_auto_step.lua` passed `17/17`.
- `lua test_pathfinder.lua` passed `10/10` after the directional/ runtime
  path rejection classification update (`blocked_directional` now requires either
  permanent directional evidence or overlap with runtime + static).
- `luac -p map_reader.lua test_map_reader.lua` passed.
- `git diff --check -- map_reader.lua test_map_reader.lua main.lua
  session_handoff.md HANDOFF_2026-04-27_brecconary_fresh_survey_1027_followup.md`
  passed.
- `git diff --check -- session_handoff.md
  HANDOFF_2026-04-27_brecconary_route_drift_retry_survey.md` passed.
- `git diff --check -- map_reader.lua test_map_reader.lua session_handoff.md
  HANDOFF_2026-04-27_brecconary_35_false_blocker.md` passed.
- `git diff --check -- map_reader.lua test_map_reader.lua session_handoff.md
  HANDOFF_2026-04-27_brecconary_35_context_repro.md
  HANDOFF_2026-04-27_brecconary_35_false_blocker.md` passed.
- `lua test_map_reader.lua` still has two known unrelated Tantegel failures:
  `(12,19)` south and `(16,16)` east.

- Current focused check (2026-04-28, map `0x04`, Guard 1):
- From `start=(6,15)` and `start=(10,8)`/`(20,8)`, `debug_pathfind_adjacent:11,2`
  (Guard 1 adjacency) returns `No path found [no_path]`; `survey_target:Guard 1`
  from `start=(10,8)` also returns `failure_class=no_route_found` with
  `blocked_events=0`.
- `SURVEY_START_STATUS` at these starts shows `reachable_targets=12` and
  `unreachable_targets=16`, with `runtime_blocks` clear, so this is a real
  start-target partitioning case rather than transient runtime collision.
- Direct checks still align with current model:
  - `inspect_move:14,4,UP` is blocked, while `inspect_move:14,3,UP` is open, matching
    `MAP_DIRECTIONAL_BLOCKS[0x04]["14,3"] = {south=true}`.
  - The west seam around `x=6` (especially `y=13-16`) still behaves as blocked
    crossings in the same direction set already modeled in `MAP_DIRECTIONAL_BLOCKS`.
- No durable `map_reader.lua` adjustment is warranted from these reproductions alone.

## Active Handoff Set

Historical notes:
- `HANDOFF_2026-04-28_playability_pivot_and_map05.md` — Brecconary/map `0x08`
  is clean enough to pause broad blocker hunting; latest reliable survey stayed
  at `targets=21 successes=12 failures=9`, with all failures clean
  `gated_or_isolated`, runtime blocks none, and strong candidates none; project
  direction can shift to actual gameplay/playtesting and accessibility QoL;
  map `0x05` remains a useful focused blocked-cell learning target, but confirm
  live map id because repo history often labels map `0x04` as Tantegel Castle
  and map `0x05` as Throne Room/interior
- `HANDOFF_2026-04-28_brecconary_fresh_retry_patch_survey.md` — latest fresh
  parked Brecconary survey after reloading the retry patch completed
  `targets=21 successes=12 failures=9`, with all nine failures clean
  `gated_or_isolated`, zero movement failures, zero suspected engine blockers,
  zero state issues, runtime blocks none, and strong candidates none; live
  retry patch validation succeeded because route-drift retries fired for
  `npc_8`, `npc_6`, and `npc_0`, and all three later completed; current live
  position is `(10,25)`, but failed-target preflight from there reports
  `reachable_targets=0/9` and `isolation_reason=low_target_coverage`, so do
  not run `retry_failed` from that pocket; no map-data patch justified
- `HANDOFF_2026-04-28_brecconary_route_drift_after_transient_retry.md` — latest parked Brecconary survey completed `targets=21 successes=9 failures=12`, with 11 clean `gated_or_isolated` failures, one state issue, no movement failures, no suspected engine blockers, runtime blocks none, and no strong candidates/suggestions; the only actionable trace was `Old Man` after an earlier `transient_no_path` retry consumed the old single per-target retry slot, so the later real-path `route_drift_off_path` from `(4,8)->(4,10)` did not get `route_drift_retry`; patched `map_survey.lua` to track retry counts per reason and allow one route-drift retry after a transient no-path retry, capped by two total retries per target; `test_map_survey.lua` covers the sequence; live state restored to `(20,15)`, NPCs unfrozen, runtime blocks none; reload Lua before the next survey
- `HANDOFF_2026-04-27_brecconary_failed_cluster_audit.md` — implemented the focused audit plan for the eight remaining Brecconary failures; checked failure starts `(28,15)`, `(9,15)`, `(4,8)`, and `(20,13)` with `report_survey_start:retry_failed,park_npcs` plus representative `debug_pathfind_adjacent` commands; every audited start reports `reachable_targets=0/8`/`isolation_reason=low_target_coverage`, representative targets return clean no-path, runtime blocks remain none, and `SURVEY_STRONG_CANDIDATES map=0x08 none`; existing `map_reader.lua`/`test_map_reader.lua` data already covers the relevant center-east, NE, southeast, and southwest barrier bands; no map-data patch justified; live state restored to `(20,15)`, NPCs unfrozen
- `HANDOFF_2026-04-27_brecconary_clean_post_35_survey.md` — latest full parked Brecconary survey after reloading the restored `(3,5) west` block completed `targets=21 successes=13 failures=8`, with all failures `gated_or_isolated`, zero movement failures, zero suspected engine blockers, zero state issues, runtime blocks none, and `SURVEY_STRONG_CANDIDATES map=0x08 none`; `route_drift_retry` fired for Woman/Merchant/Guard targets and those later succeeded after reachable-priority reorder; live state is `(10,25)`, runtime blocks none; `report_survey_start:retry_failed,park_npcs` from `(10,25)` reports `reachable_targets=0/8` and `isolation_reason=low_target_coverage`, so do not retry-failed from that pocket; no map-data patch justified
- `HANDOFF_2026-04-27_brecconary_35_context_repro.md` — supersedes the earlier `(3,5)` false-blocker handoff; after reload cleared failed targets, a fresh parked survey from `(6,8)` blocked `(2,5)->RIGHT` into `(3,5)` during Merchant 2, then brute-force/manual confirm repeated the same block and promoted the seam to confirmed_blocked; Guard 3 and Merchant 1 later hit the same seam and succeeded after reroute, producing `SURVEY_STRONG_CANDIDATE map=0x08 x=3 y=5 count=5 targets=3 retry_successes=2 approaches=west confidence=high`; `map_reader.lua` keeps/restores `MAP_DIRECTIONAL_BLOCKS[0x08]["3,5"].west=true`, `test_map_reader.lua` asserts it, live state is `(20,15)`, NPCs unfrozen, runtime blocks none; reload Lua before the next survey
- `HANDOFF_2026-04-27_brecconary_35_false_blocker.md` — superseded by `HANDOFF_2026-04-27_brecconary_35_context_repro.md`; focused retry preflight from `(6,8)` showed `0/8` remaining failed targets reachable with runtime blocks clear, and a controlled direct probe from `(2,5)->RIGHT` appeared to move into `(3,5)` despite the static west block, but later route-context plus manual-confirm evidence proved this was noisy/subtile contamination
- `HANDOFF_2026-04-27_brecconary_route_drift_retry_survey.md` — after reloading the `route_drift_retry` patch, the next parked Brecconary survey improved to `targets=21 successes=13 failures=8`, with all eight failures clean `gated_or_isolated`, zero movement failures, zero suspected engine blockers, zero state issues, runtime blocks clear, and `SURVEY_STRONG_CANDIDATES map=0x08 none`; the retry rail fired for `Old Man` and `Guard` after quick north-step route drift and both targets later succeeded, while the prior `Woman 3` state issue also succeeded; current live position is `(10,25)`, but retry-failed preflight from there reports `reachable_targets=0` for the remaining eight targets, so do not run retry-failed from that pocket; no `map_reader.lua` patch is justified
- `HANDOFF_2026-04-27_brecconary_post_1027_survey_analysis.md` — latest parked Brecconary object survey after the `10,27 south` patch completed `targets=21 successes=11 failures=10`, with zero movement failures, zero suspected engine-blocked tiles, runtime blocks clear, and `SURVEY_STRONG_CANDIDATES map=0x08 none`; nine failures are the expected gated/isolated clusters, and the only state issue is `Woman 3`, where the planned route from `(1,14)` to adjacent `(4,8)` started `north, east...`, the first north step completed to `(1,13)` in 8 frames, then the player drifted to `(1,12)` during settle and `route_drift_off_path` cancelled the route before bogus blocker evidence could be exported; `map_survey.lua` now requeues same-map `route_drift_off_path` attempts once as `route_drift_retry` when no blocked/suspected tiles were observed, and `test_map_survey.lua` covers retrying from the live drifted position; reload Lua and rerun the parked survey
- `HANDOFF_2026-04-27_brecconary_fresh_survey_1027_followup.md` — latest map08/Brecconary follow-up first saw a `10,27 south` candidate downgrade after a normalized teleport probe moved through `(10,28)->UP`, then a reload/confidence survey reproduced the candidate as high confidence (`targets=21 successes=9 failures=12`, `count=4`, `targets=2`, `retry_successes=1`); route-context probing moved `(11,28)->LEFT` into `(10,28)` and then blocked on `(10,28)->UP`, and raw `UP,120` from that state stayed pinned; patched `MAP_DIRECTIONAL_BLOCKS[0x08]["10,27"]={north=true,south=true}` and updated the map-reader test; live cleanup cleared survey candidates, runtime blocks, and seam memory, unfroze NPCs, and left the player at `(10,28)`; `main.lua` now logs structured `RUNTIME_BLOCKS` lines for `report_runtime_blocks`
- `HANDOFF_2026-04-26_brecconary_1722_trap_cell.md` — latest reloaded Brecconary parked survey started cleanly from `(4,17)` but later entered `(17,22)` from the west and became trapped; run completed `targets=21 successes=7 failures=14` with `suspected_engine_blocked=3`, `state_issues=4`, and a large failure cluster from `(17,22)`; split direct probes with runtime blocks cleared and NPCs frozen confirmed `(17,22)->LEFT`, `(17,22)->RIGHT`, and `(17,22)->DOWN` all block despite open previews, while NORTH is a tile wall; raw `LEFT,120` from `(17,22)` also stayed pinned; patched `MAP_BLOCKED_CELLS[0x08]["17,22"] = true` as a pathfinder-forbidden trap cell and added the map-reader assertion; `luac -p map_reader.lua test_map_reader.lua` and `git diff --check -- map_reader.lua test_map_reader.lua` passed; full `lua test_map_reader.lua` still has the two known unrelated Tantegel failures
- `HANDOFF_2026-04-26_brecconary_stranded_start_abort.md` — latest parked Brecconary survey started inside the southwest guard pocket at `(9,24)` and therefore completed `targets=21 successes=1 failures=20`, all twenty failures as `gated_or_isolated`/`stranded_start_unreachable`; no blocked events, runtime blocks, or candidate exports were produced; patched `map_survey.lua` preflight so broad object surveys abort when only one or zero targets are reachable from the start despite a non-tiny reachable area/open-exit count, logging `isolation_reason=low_target_coverage`; guard applies only to target sets of at least 8 so small continuation/focused surveys are preserved; `test_map_survey.lua` covers the multi-exit low-target-coverage abort and passes 38/38; live state moved to `(4,17)`, runtime blocks clear, NPCs unfrozen, and `report_survey_start:park_npcs` reports viable
- `HANDOFF_2026-04-26_brecconary_post_guard_patch_survey_analysis.md` — post-reload Brecconary survey after the Guard 4 southwest-pocket patch completed `targets=21 successes=13 failures=8`, with six clean gated/isolated failures plus two actionable traces; `10,27 south` initially exported as a high-confidence survey candidate from Guard 4, but a focused split probe from `(10,28)->UP` moved and downgraded the seam to noisy/needs_repro with export count 0, so no map-data patch; `Woman 3` bogus `(4,7)` block came from queued-route off-path drift after `(1,14)->(1,13)` overshot to `(1,12)` during settle, then stale route execution continued from the wrong tile and tried one extra `UP`; patched `auto_step.lua` so unmatched queued-route drift cancels immediately with `route_cancelled reason=route_drift_off_path`; `lua test_auto_step.lua` passes 17/17; live state restored to `(10,25)`, NPCs unfrozen, runtime blocks clear
- `HANDOFF_2026-04-26_brecconary_guard4_southwest_followup.md` — latest reloaded parked Brecconary survey was stopped after Guard 4 churned in the southwest pocket; direct probes confirmed `(7,25)->RIGHT` into `(8,25)` blocks, `(7,26)->RIGHT` into `(8,26)` blocks, and `(8,25)->DOWN` into `(8,26)` blocks despite open previews; controlled probes moved through neighboring noisy cells `(5,25)`, `(5,26)`, `(6,27)`, and `(7,27)` from the tested approaches; patched `MAP_DIRECTIONAL_BLOCKS[0x08]["8,25"]={east=true,west=true}` and `["8,26"]={east=true,north=true,west=true}` with regression assertions; live state restored to `(7,25)`, NPCs unfrozen, runtime blocks clear
- `HANDOFF_2026-04-26_brecconary_827_south_and_survey_cleanup.md` — latest parked Brecconary survey completed `targets=21 successes=13 failures=8`, with six clean `gated_or_isolated_region` failures, no runtime blocks, no strong candidates, and two state issues; direct follow-up kept `10,27 south` open/noisy, confirmed `(8,28)->UP` into `(8,27)` blocked while reverse `(8,27)->DOWN` moved, patched `MAP_DIRECTIONAL_BLOCKS[0x08]["8,27"]={south=true}`, fixed queued-route post-step stale-direction cleanup, and marked `simulate_raw_input` neutral release frames as raw so auto-step cannot synthesize bogus manual-block evidence after a raw probe
- `HANDOFF_2026-04-26_brecconary_1817_trap_and_input_release.md` — post-reload follow-up verified same-poll `teleport_to` snapshot refresh, hardened blocked-candidate export so `needs_repro` diagnostics are skipped, stopped a polluted Brecconary regression survey after it clustered at `(18,17)`, direct-probed `(18,17)->DOWN/LEFT/UP` as blocked despite open previews even after teleport normalization, patched `MAP_BLOCKED_CELLS[0x08]["18,17"] = true`, and corrected auto-step neutral cleanup after two controller regressions: mid-step neutral overriding live movement, then repeated `can_walk=false` neutral frames locking title-screen input
- `HANDOFF_2026-04-26_brecconary_cleaner_survey_analysis.md` — after controller rollback/reload, latest Brecconary parked survey completed `targets=21 successes=14 failures=7` with `suspected_engine_blocked=0`, `movement_failed=0`, `state_issues=1`, runtime blocks clear, strong candidates none, and candidate suggestions none; split probes confirmed `(10,28)->UP` and `(8,28)->UP` both move, so `10,27 south` and `8,27 south` remain noise; patched `teleport_to` to refresh `game_snapshot` after RAM writes so same-poll `inspect_move` cannot read pre-teleport coordinates
- `HANDOFF_2026-04-26_brecconary_input_release_patch.md` — stopped an invalid post-reload Brecconary survey after open edges at `(3,17)->RIGHT/UP` falsely timed out with stale `buttons=0x80`; patched debug/auto-step neutral release handling and added `clear_input`; automatic startup neutral was removed after it likely interfered with controller input; reload Lua before the next survey
- `HANDOFF_2026-04-26_brecconary_trap_cell_followup.md` — analyzed reloaded 9/12 Brecconary survey; direct-probed `(16,23)` trap cell, added it as pathfinder-forbidden full block, left noisy `(10,27)/(8,27) south` unpromoted, and restored live state to `(3,17)`
- `HANDOFF_2026-04-26_brecconary_town_survey.md` — analyzed first fresh Brecconary parked survey; corrected `(10,27)` from stale `south=true` to confirmed `north=true`, rejected noisy `(8,27) south`, and restored live state to `(10,26)` with NPCs unfrozen
- `HANDOFF_2026-04-26_object_finder_reachability.md` — object finder now appends "Not currently reachable" for selected interior objects with no current path; uses quiet route preview and does not freeze NPCs or queue movement
- `HANDOFF_2026-04-26_map04_blocked_targets_review.md` — reviewed latest 14/14 clean survey failures; corrected the overbroad east-wing reachability note; far-east targets still no-path from `(10,8)` with parked NPCs and no blocked-event evidence
- `HANDOFF_2026-04-26_map04_catchup_verified_survey.md` — reloaded survey after queued-route catch-up patch improved to 14/14, all failures gated/isolated, no candidates, no runtime blocks, and no blocked route events
- `HANDOFF_2026-04-26_map04_post_catchup_survey_followup.md` — latest 13/15 survey stayed clean gated/isolated; candidate guard contained `(4,6) north` as `needs_repro`; patched queued-route drift catch-up after `(6,8)` stale-step recurrence
- `HANDOFF_2026-04-26_map04_new_survey_overshoot_followup.md` — latest 13/15 survey had no map candidates; exposed queued-route auto-step overshoot into known walls; patched immediate neutral on step completion
- `HANDOFF_2026-04-26_map04_post_exit_reload_west_boundary.md` — post-exit-reload 28-target survey; verified `(4,7)` west, rejected `(3,6)`/`(4,6)` reroute-only false positives; tightened candidate exports
- `HANDOFF_2026-04-26_map04_exit_walk_and_south_gate_wall.md` — diagnosed survey exit walk, excluded south-gate door from default surveys, verified south-gate wall band
- `HANDOFF_2026-04-26_map04_reload_survey_6_13_followup.md` — reloaded quiet survey; verified and patched `(6,13)` west approach
- `HANDOFF_2026-04-26_map04_quiet_survey_stranded_skip_fix.md` — quiet 15/14 survey; fixed premature stranded-start queue trimming
- `HANDOFF_2026-04-26_map04_post_reload_survey_followup.md` — post-reload survey investigation; corrected the east-connector raw-input split
- `HANDOFF_2026-04-26_map04_east_connector_probe_followup.md` — focused follow-up on the 6 fresh survey runtime blockers
- `HANDOFF_2026-04-26_map04_fresh_survey_summary.md` — fresh post-door-band survey result
- `HANDOFF_2026-04-24_*.md` — prior session detail
- `HANDOFF_2026-04-17_survey_abort_staircase_fix.md`
- `handoff_archive/`

## Claude Quick Resume

Current focus (2026-04-28 playability pivot):
- **Playability pivot and map 0x05 follow-up:** Brecconary/map `0x08` is clean
  enough to pause broad blocker hunting. The remaining failures are clean
  `gated_or_isolated` NPC regions with runtime blocks none and strong
  candidates none, so no map-data patch is justified. The project can shift
  toward actual playtesting and quality-of-life improvements. The user plans to
  move to the first castle/interior map and start a fresh survey; map `0x05`
  remains a focused blocked-cell learning target, but confirm the live map id
  before patching because repo history often labels `0x04` as Tantegel Castle
  and `0x05` as Throne Room/interior. See
  `HANDOFF_2026-04-28_playability_pivot_and_map05.md`.
- **Prior context follows.**
- **Latest Brecconary fresh retry-patch survey:** after reloading the
  retry-accounting patch, the parked survey completed `targets=21 successes=12
  failures=9 no_route=0 gated_or_isolated=9 movement_failed=0
  suspected_engine_blocked=0 state_issues=0 adjacency_issues=0`. Runtime
  blocks are clear, strong candidates are none, and the failed-target preflight
  from live `(10,25)` reports `reachable_targets=0/9` with
  `isolation_reason=low_target_coverage`, so do not run `retry_failed` from
  that pocket. The patch was validated live: `route_drift_retry` fired for
  `npc_8`, `npc_6`, and `npc_0`, and all three later completed. No map-data
  patch is justified. See
  `HANDOFF_2026-04-28_brecconary_fresh_retry_patch_survey.md`.
- **Prior context follows.**
- **Latest Brecconary failed-cluster audit:** focused diagnostics checked all
  four failure starts from the latest eight failed targets: `(28,15)`,
  `(9,15)`, `(4,8)`, and `(20,13)`. Each
  `report_survey_start:retry_failed,park_npcs` preflight reported
  `reachable_targets=0/8` with `isolation_reason=low_target_coverage`, and
  representative `debug_pathfind_adjacent` checks for `(20,10)`, `(25,25)`,
  `(24,5)`, `(4,26)`, and `(20,23)` all returned clean no-path. Existing
  Brecconary map data/tests already cover the relevant barrier bands, runtime
  blocks remain clear, and strong candidates remain none. No map patch is
  justified. Live state was restored to `(20,15)`, NPCs unfrozen. See
  `HANDOFF_2026-04-27_brecconary_failed_cluster_audit.md`.
- **Latest Brecconary clean post-`(3,5)` survey:** after reloading with
  `(3,5) west` restored, the full parked survey completed `targets=21
  successes=13 failures=8 no_route=0 gated_or_isolated=8 movement_failed=0
  suspected_engine_blocked=0 state_issues=0 adjacency_issues=0`. Follow-up
  reports `RUNTIME_BLOCKS map=0x08 none` and `SURVEY_STRONG_CANDIDATES map=0x08
  none`. The eight remaining failures are clean gated/isolated clusters, not
  blocker evidence. `route_drift_retry` fired for three targets and those later
  succeeded after reorder. Live state is `(10,25)`; do not run `retry_failed`
  there because preflight reports `reachable_targets=0/8` and
  `isolation_reason=low_target_coverage`. No map-data patch is justified. See
  `HANDOFF_2026-04-27_brecconary_clean_post_35_survey.md`.
- **Latest Brecconary `(3,5)` route-context repro:** after reload cleared
  failed targets, a fresh parked survey from `(6,8)` blocked Merchant 2 on
  `(2,5)->RIGHT` into `(3,5)`. Brute-force/manual confirmation repeated the
  same block, and later Guard 3/Merchant 1 attempts hit the same seam and then
  succeeded after reroute. The partial survey stopped at `targets=10
  successes=6 failures=4`, with `SURVEY_STRONG_CANDIDATE map=0x08 x=3 y=5
  count=5 targets=3 retry_successes=2 approaches=west confidence=high`.
  `map_reader.lua` now keeps/restores
  `MAP_DIRECTIONAL_BLOCKS[0x08]["3,5"].west=true`; `test_map_reader.lua`
  asserts the west approach is blocked. The earlier direct moved probe is
  superseded as noisy/subtile state. Live state is `(20,15)`, NPCs unfrozen,
  runtime blocks clear. Reload Lua, then run another parked Brecconary survey.
  See `HANDOFF_2026-04-27_brecconary_35_context_repro.md`.
- **Latest Brecconary route-drift retry survey:** after reloading the
  `route_drift_retry` patch and running another parked object survey, map
  `0x08` completed `targets=21 successes=13 failures=8 no_route=0
  gated_or_isolated=8 movement_failed=0 suspected_engine_blocked=0
  state_issues=0 adjacency_issues=0`. Runtime blocks are clear and
  `SURVEY_STRONG_CANDIDATES map=0x08 none`. The retry rail fired for `Old Man`
  and `Guard` after quick north-step drift; both requeued once and later
  succeeded. The prior `Woman 3` state issue also succeeded. The remaining
  eight failed targets are clean gated/isolated clusters, not blocker evidence.
  Current live state is `(10,25)`, but
  `report_survey_start:retry_failed,park_npcs` from there reports
  `reachable_targets=0` and `isolation_reason=low_target_coverage`, so do not
  run retry-failed from that pocket. No `map_reader.lua` patch is justified;
  either stop Brecconary blocker hunting for now or relocate before retrying
  the last eight. See
  `HANDOFF_2026-04-27_brecconary_route_drift_retry_survey.md`.
- **Prior context follows.**
- **Latest Brecconary fresh survey:** after the morning controller fix, the
  first fresh map08 survey produced a `10,27 south` candidate, but a normalized
  teleport probe from `(10,28)->UP` moved and downgraded it to noisy. A later
  reload/confidence survey reproduced the same seam under route conditions:
  `targets=21 successes=9 failures=12`, with ten gated/isolated failures, one
  Guard 4 suspected engine block, and one Guard 5 route-drift state issue. The
  decisive repro was route-context, not teleport-normalized: `(11,28)->LEFT`
  moved into `(10,28)`, then `(10,28)->UP` blocked, and a raw `UP,120` hold
  from that state stayed pinned. `map_reader.lua` now models
  `MAP_DIRECTIONAL_BLOCKS[0x08]["10,27"]={north=true,south=true}`, and
  `test_map_reader.lua` covers the south approach. Runtime/test cleanup cleared
  survey candidates, runtime blocks, and seam memory; NPCs are unfrozen and the
  live position is `(10,28)`. Reload Lua before the next parked Brecconary
  survey so this map patch and the structured `RUNTIME_BLOCKS` logging are
  active. See
  `HANDOFF_2026-04-27_brecconary_fresh_survey_1027_followup.md`.
- **Latest Brecconary `(17,22)` trap-cell follow-up:** after reloading and
  running a fresh parked survey, Brecconary started from `(4,17)` and completed
  `targets=21 successes=7 failures=14`; this was not the previous `(9,24)` bad
  start. The main new failure cluster came after the route entered `(17,22)`
  from the west. From that cell, direct split probes confirmed LEFT into
  `(16,22)`, RIGHT into `(18,22)`, and DOWN into `(17,23)` all block despite
  open previews; NORTH is already tile-blocked. A raw `LEFT,120` hold from
  `(17,22)` also stayed at `(17,22)`. `map_reader.lua` now treats
  `MAP_BLOCKED_CELLS[0x08]["17,22"] = true` as a pathfinder-forbidden trap
  cell, and `test_map_reader.lua` covers it. Syntax and diff checks passed;
  full `test_map_reader.lua` still has the two known unrelated Tantegel
  failures. Reload Lua before the next Brecconary survey. See
  `HANDOFF_2026-04-26_brecconary_1722_trap_cell.md`.
- **Latest Brecconary stranded-start survey:** after reload, a parked survey
  started from `(9,24)`, inside the southwest guard pocket. It completed
  `targets=21 successes=1 failures=20`; all failures were
  `gated_or_isolated`/`stranded_start_unreachable`, with no blocked events, no
  runtime blocks, and no candidate exports. This was a bad survey start, not a
  map-data regression. `map_survey.lua` now aborts broad object surveys when
  start coverage is effectively stranded: for target sets of at least 8, only
  0 or 1 reachable targets marks the start as isolated with
  `isolation_reason=low_target_coverage`. This prevents another wall of
  misleading stranded failures while preserving small focused/continuation
  surveys. `test_map_survey.lua` covers the multi-exit low-target-coverage
  abort and passes 38/38. Live state was moved to `(4,17)`, NPCs unfrozen,
  runtime blocks clear; `report_survey_start:park_npcs` reports that start as
  viable. Reload Lua before the next parked survey. See
  `HANDOFF_2026-04-26_brecconary_stranded_start_abort.md`.
- **Latest Brecconary post-guard-patch survey:** the fresh parked survey after
  reloading the `8,25/8,26` patch completed `targets=21 successes=13
  failures=8`. Six failures are still clean gated/isolated clusters. The
  remaining two were diagnostic: Guard 4 produced a `10,27 south` candidate,
  but a focused split probe from `(10,28)->UP` moved into `(10,27)`, downgraded
  the seam to noisy/needs_repro, and cleared candidate exports. Do not patch
  `10,27 south`; keep only `10,27 north=true`. `Woman 3` exposed the real
  tooling hole: after `(1,14)->(1,13)`, stale movement drifted to `(1,12)`
  during the route settle window, the old route kept executing from the wrong
  tile, and it generated a bogus `(4,7)` block by trying one extra `UP` into
  the target NPC. `auto_step.lua` now cancels queued routes immediately when
  drift cannot be matched to upcoming route steps, publishing
  `route_cancelled reason=route_drift_off_path`; `test_auto_step.lua` covers
  this and passes 17/17. Live state restored to `(10,25)`, NPCs unfrozen,
  runtime blocks clear. Reload Lua before the next parked Brecconary survey.
  See `HANDOFF_2026-04-26_brecconary_post_guard_patch_survey_analysis.md`.
- **Latest Brecconary Guard 4 southwest-pocket follow-up:** after Lua reload and
  a fresh parked survey, Guard 4 churned around `(8,25)/(8,26)`. The survey was
  stopped and split direct probes confirmed `(7,25)->RIGHT` into `(8,25)`,
  `(7,26)->RIGHT` into `(8,26)`, and `(8,25)->DOWN` into `(8,26)` all block
  despite open previews. Neighboring survey suspects `(5,25)`, `(5,26)`,
  `(6,27)`, and `(7,27)` moved from the tested approaches, so they stay noisy
  rather than permanent data. `map_reader.lua` now models
  `MAP_DIRECTIONAL_BLOCKS[0x08]["8,25"]={east=true,west=true}` and
  `["8,26"]={east=true,north=true,west=true}`; `test_map_reader.lua` covers
  the added faces. Live state was restored to `(7,25)`, NPCs unfrozen, runtime
  blocks clear. Reload Lua before the next parked Brecconary survey. See
  `HANDOFF_2026-04-26_brecconary_guard4_southwest_followup.md`.
- **Latest Brecconary survey cleanup:** the newest parked survey completed
  `targets=21 successes=13 failures=8`; six failures are clean
  `gated_or_isolated_region`, `movement_failed=0`,
  `suspected_engine_blocked=0`, `runtime_count=0`, strong candidates `none`,
  and candidate suggestions `none`. Focused checks confirmed
  `(10,28)->UP` into `(10,27)` moves, so `10,27 south` remains noisy/open.
  The same follow-up confirmed `(8,28)->UP` into `(8,27)` blocks despite an
  open preview; a 90-frame raw UP hold also stayed at `(8,28)`, while reverse
  `(8,27)->DOWN` moved. `map_reader.lua` now models
  `MAP_DIRECTIONAL_BLOCKS[0x08]["8,27"] = {south = true}` only. The `Old Man 1`
  state issue showed a queued route orphaned by a stale route-owned direction
  after a post-step release blip at `(5,9)/(5,10)`. `auto_step.lua` now
  neutralizes route-owned stale direction during the queued-route post-step
  release window, and `debug_tools.lua` marks `simulate_raw_input` release
  frames as raw so auto-step cannot observe a synthetic release edge. Reload Lua
  before the next retry/fresh Brecconary survey. See
  `HANDOFF_2026-04-26_brecconary_827_south_and_survey_cleanup.md`.
- **Brecconary `(18,17)` trap + input-release follow-up:** after reload,
  Codex verified the same-poll `teleport_to` snapshot fix live, then stopped a
  polluted parked survey that reached `(18,17)` and repeatedly timed out on
  open-preview exits. Split direct probes from `(18,17)` confirmed
  `DOWN`, `LEFT`, and `UP` all block despite open previews; `LEFT` and `UP`
  still blocked after teleport normalization, and `RIGHT` is already a wall.
  `map_reader.lua` now forbids `MAP_BLOCKED_CELLS[0x08]["18,17"] = true`.
  A first input-release patch broke live controller movement after reload: logs
  showed manual directions becoming auto-steps that never committed, because
  the mid-step neutral frame was overriding real held input after the inject
  window. A later relaunch reached the title screen but title keys still did
  not work; read-only commands confirmed `state=title` and exposed that
  `can_walk=false` was repeatedly neutralizing because `post_step_release_frames`
  was not cleared. `auto_step.lua` has now been corrected again: no neutral
  frame is emitted merely because the inject window expired, `can_walk=false`
  clears release state without writing input, and `cancel_active_step()` no
  longer writes neutral input. Live rescue: `enable_auto_step=false` was loaded
  into the running title-screen script via `reload_config`, then
  `dw_access.ini` was restored to `enable_auto_step=true` on disk. The current
  running script therefore has auto-step disabled until the next full Lua
  reload; the next full reload should use auto-step again with the corrected
  code. See
  `HANDOFF_2026-04-26_brecconary_1817_trap_and_input_release.md`.
- **Latest Brecconary cleaner survey:** after the controller-input rollback and
  Lua reload, Brecconary `map=0x08` parked survey completed
  `targets=21 successes=14 failures=7`, with `movement_failed=0`,
  `suspected_engine_blocked=0`, `state_issues=1`, and `runtime_count=0`.
  Strong candidates and candidate suggestions were both `none`. The only
  diagnostic candidates were `8,27 south` and `10,27 south`, both
  `confidence=needs_repro`; split direct probes confirmed `(8,28)->UP` and
  `(10,28)->UP` both move, so do not patch either south approach. Six
  remaining failures are clean `gated_or_isolated_region` targets. Live state
  was restored to `(9,25)`, NPCs unfrozen, runtime blocks clear. See
  `HANDOFF_2026-04-26_brecconary_cleaner_survey_analysis.md`.
- **Teleport/debug tooling patch:** same-poll
  `teleport_to:10,28 report_position inspect_move:UP` showed
  `report_position` reading `(10,28)` from RAM while `inspect_move` still used
  the cached pre-teleport `(9,25)` snapshot. `main.lua` now refreshes
  `game_snapshot` after `teleport_to` writes coordinates and movement-state
  bytes. `luac -p main.lua` and `git diff --check -- main.lua` passed. Reload
  Lua before relying on this patch.
- **Brecconary input-release patch:** the post-reload parked survey after the
  `(16,23)` patch was stopped as invalid. It immediately timed out on
  `(3,17)->RIGHT` and `(3,17)->UP`, even though `inspect_move` reported both
  destinations open/effective-passable and movement diagnostics kept showing
  `buttons=0x80`. Treat the resulting `(4,17)`, `(3,16)`, and later `(2,15)`
  runtime evidence as polluted. `debug_tools.lua` now emits neutral joypad
  frames after debug-owned simulated/sweep input and adds `clear_input`, while
  `auto_step.lua` actively clears directions after blocked timeouts. The
  automatic startup neutral frame was removed because it plausibly broke normal
  controller input after reload. Reload Lua before the next live survey. See
  `HANDOFF_2026-04-26_brecconary_input_release_patch.md`.
- **Brecconary trap-cell follow-up:** reloaded parked survey improved to
  `targets=21 successes=9 failures=12`, with `suspected_engine_blocked=0` and
  no strong candidate suggestions. The only actionable issue was the southeast
  trap at `(16,23)`: after the survey reached it, all four exits repeatedly
  blocked. Split direct probes confirmed `(16,23)->RIGHT/UP/LEFT/DOWN` all
  block despite open previews, and controlled `(16,24)->UP` also blocked after
  the earlier route-run move. `MAP_BLOCKED_CELLS[0x08]["16,23"] = true` now
  forbids A* from entering that trap. Noisy `(10,27) south` and `(8,27) south`
  were not promoted. Reload Lua before the next Brecconary survey. See
  `HANDOFF_2026-04-26_brecconary_trap_cell_followup.md`.
- **Brecconary town survey follow-up:** first fresh parked-NPC survey on
  `map=0x08` completed `targets=21 successes=5 failures=16`; nine suspected
  engine-blocked failures shared `(10,27)` from the north approach. Split
  probes confirmed `(10,26)->DOWN` blocks into `(10,27)`, while
  `(10,28)->UP` moves through, so `MAP_DIRECTIONAL_BLOCKS[0x08]["10,27"]`
  is now `{north=true}` instead of stale `{south=true}`. The weaker `(8,27)`
  south hit was directly reprobed and moved, so it remains unmodeled/noisy.
  Reload Lua before the next Brecconary survey. See
  `HANDOFF_2026-04-26_brecconary_town_survey.md`.
- **MAP_DOOR_CELLS[0x04] added and reload done.** Verification COMPLETE (see below).
- **Object finder reachability messaging implemented.** `next_object`,
  `prev_object`, `current_object`, and filter announcements now append
  "Not currently reachable" when the selected interior object has no current
  route. The preview is quiet, does not freeze NPCs, does not queue movement,
  and keeps reachable object speech unchanged. See
  `HANDOFF_2026-04-26_object_finder_reachability.md`.
- **Blocked target review correction:** the prior “east-wing targets reachable
  without magic keys” note was too broad. The x=5 bypass reaches the y=4 east
  connector, but far-east targets past the confirmed `21,4/21,5 west` wall
  still cleanly no-path from `(10,8)`/`(10,10)` under parked-NPC checks.
- All prior work (6 false-positive block removals, teleport normalization,
  seam oscillation fix, x=15 east=true blocks) remains in place.
- **East connector revised after post-reload controls:** normalized raw held
  input now confirms the full band:
  `17,6/18,6/19,6/20,6 north=true` plus `21,4/21,5 west=true`.
  The earlier raw "moved through 20,6/21,4/21,5" result was contaminated.
- Probe/survey garbage-data guards added:
  raw debug input no longer feeds `auto_step`, and survey candidates produced
  only by `command_timing_or_state_issue` are marked `needs_repro` and excluded
  from strong/export suggestions. Latest guard: successful-reroute-only
  candidates also stay `needs_repro` and cannot become pasteable directional
  exports unless a focused direct/manual probe confirms the approach; mixed
  moved/blocked seam evidence is downgraded to `needs_repro`.
- **Latest post-exit-reload survey:** map04 default parked survey now has
  `targets=28` and completed `successes=14 failures=14`, all failures
  `gated_or_isolated`, with `state_issues=0`, `adjacency_issues=0`, and
  `suspected_engine_blocked=0`. `door_10_30` stayed excluded, `exit_11_29`
  completed safely, and the south-gate wall churn did not recur.
- **West-boundary follow-up:** survey reported candidates `3,6 south`,
  `4,7 west`, and `4,6 north`. Split direct probes confirmed only
  `(4,7) west` as blocked. `(3,7)->UP` moved to `(3,6)`, and
  `(4,5)->DOWN` moved to `(4,6)`, so those two stay unmodeled. `map_reader.lua`
  now models `["4,7"] = {east = true, west = true, south = true}`. See
  `HANDOFF_2026-04-26_map04_post_exit_reload_west_boundary.md`.
- **Latest new survey after reload:** map04 completed `targets=28`,
  `successes=13 failures=15`, all failures `gated_or_isolated`, and still
  `movement_failed=0`, `state_issues=0`, `adjacency_issues=0`,
  `suspected_engine_blocked=0`. Post-run reports showed no blocked candidates,
  no strong candidates, no candidate suggestions, and runtime_count=0. The one
  extra failure versus the prior 14/14 run was `chest_1` at `(1,15)`, failed as
  a clean no-path from `(9,20)`.
- **Auto-step overshoot patch:** the latest survey showed a queued route complete
  `(3,8)->(4,8)` and then begin the next step from `(5,8)`, causing a reroute
  into the known wall at `(6,8)`. `auto_step.lua` now sends a neutral D-pad
  frame immediately when a step completion is observed, before the existing
  post-step neutral window. This should reduce successful-route reroutes into
  already-known static blocks. See
  `HANDOFF_2026-04-26_map04_new_survey_overshoot_followup.md`.
- **Latest post-neutral survey and catch-up patch:** a new reloaded survey again
  completed `targets=28 successes=13 failures=15`; all 15 failures were
  `gated_or_isolated`, with `movement_failed=0`, `state_issues=0`,
  `adjacency_issues=0`, and `suspected_engine_blocked=0`. Reports showed
  strong candidates `none`, candidate suggestions `none`, `runtime_count=0`,
  and only diagnostic `(4,6) north confidence=needs_repro`. The `(6,8)` false
  block still recurred because queued-route settle drift reached the next
  planned tile but the route queue replayed that stale direction. `auto_step.lua`
  now catches up small queued-route drift that matches upcoming route steps and
  emits `source=route_settle_catchup`; `test_auto_step.lua` covers it. Reload
  Lua before the next survey. See
  `HANDOFF_2026-04-26_map04_post_catchup_survey_followup.md`.
- **Catch-up verification survey:** after reload, map04 completed
  `targets=28 successes=14 failures=14`; all 14 failures were
  `gated_or_isolated`, with `movement_failed=0`, `state_issues=0`,
  `adjacency_issues=0`, and `suspected_engine_blocked=0`. Post-run reports
  showed `SURVEY_CANDIDATES none`, strong candidates `none`, suggestions
  `none`, and `runtime_count=0`. Focused log search found no
  `SEAM_OBSERVATION result=blocked`, no `auto_step blocked`, and no
  `blocked_events > 0`. The prior `(6,8)` false block was avoided by
  `route_settle_catchup` consuming `(4,8)->(5,8)` before the route continued
  downward. See `HANDOFF_2026-04-26_map04_catchup_verified_survey.md`.
- **Blocked target intent review:** focused parked single-target checks from
  `(10,8)` reproduced clean no-path for `npc_9` Guard/Guard 5 `(26,21)`,
  `npc_10` Merchant/Merchant 3 `(24,1)`, and `npc_11` Woman/Woman 2 `(27,5)`.
  Each had `blocked_events=0`, no candidates, and `runtime_blocks=0`, matching
  the full survey. Treat these as currently gated/isolated targets, not
  collision-data bugs, unless new manual gameplay evidence shows an opening.
  See `HANDOFF_2026-04-26_map04_blocked_targets_review.md`.
- **Earlier reloaded quiet survey before the south-gate door exclusion:** map04 reached `successes=14 failures=15`, all
  failures are `gated_or_isolated`, with `state_issues=0`,
  `adjacency_issues=0`, and `suspected_engine_blocked=0`. The stranded-start
  fix is working: trimming is deferred while reachable continuation targets
  remain, and the only mass trim happens from `(5,24)` after reachable pending
  targets drop to zero.
- The reloaded survey produced one real new candidate: `(6,13)` approached from
  the west. Split direct probes from `(5,13)->RIGHT` reproduced it twice after
  teleport normalization and promoted the seam to confirmed_blocked. `map_reader.lua`
  now models `["6,13"] = {east = true, west = true}` and `test_map_reader.lua`
  asserts the west approach. See
  `HANDOFF_2026-04-26_map04_reload_survey_6_13_followup.md`.
- **Exit-walk fix:** a partial survey walked through the south-gate door target
  `door_10_30` and changed to map `0x01`. `objects.lua` now marks that door
  `survey_exclude=true`, and default object surveys skip excluded objects while
  keeping the door available for explicit navigation. The restarted partial run
  was stopped manually after it began cycling on south-gate wall seams.
- **South-gate wall patch:** direct probes with runtime blocks cleared confirmed
  `16,28/17,28/18,28/19,28 south=true` and `20,29 west=true`. These are now in
  `MAP_DIRECTIONAL_BLOCKS[0x04]`, with regression coverage in
  `test_map_reader.lua`. See
  `HANDOFF_2026-04-26_map04_exit_walk_and_south_gate_wall.md`.

### Superseded pickup note: pre-patch fresh survey result (2026-04-26)

This earlier `survey_objects:park_npcs` run is kept for history only. It was
superseded by the reloaded quiet survey above after the east connector and
survey garbage-data fixes were applied:

```text
SURVEY_COMPLETE run=1 map=0x04 targets=29 successes=14 failures=15 no_route=0 gated_or_isolated=6 movement_failed=0 suspected_engine_blocked=0 state_issues=9 adjacency_issues=0
```

Post-survey `report_path_state` showed `runtime_count=6` at player position
`(17,5)`:

```text
21,4(west)
21,5(west)
17,6(north)
18,6(north)
19,6(north)
20,6(north)
```

Important: do **not** immediately re-promote these six seams into permanent
`MAP_DIRECTIONAL_BLOCKS[0x04]`. The current code/comment state says this band
was removed as false-positive data after NPC-free natural-walk / stale-state
follow-up. The new survey re-learned it during queued-route execution and still
classified affected targets as `command_timing_or_state_issue`, not
`suspected_engine_blocked`.

Recommended next step: run split-command, adjacent-start direct probes with
NPCs frozen and `report_movement_state` before/after:
`(17,5)->DOWN`, `(18,5)->DOWN`, `(19,5)->DOWN`, `(20,5)->DOWN`,
`(20,4)->RIGHT`, `(20,5)->RIGHT`.

Initial follow-up completed by Codex:
- all six `probe_edge` checks blocked despite open previews
- first raw held-input pass appeared to split the set:
  - blocked under raw input: `(17,5)->DOWN`, `(18,5)->DOWN`, `(19,5)->DOWN`
  - moved under raw input: `(20,5)->DOWN`, `(20,4)->RIGHT`, `(20,5)->RIGHT`
- after the user reloaded and reran the survey, Codex repeated normalized raw
  controls and the apparent split disappeared:
  `(20,5)->DOWN`, `(20,4)->RIGHT`, and `(20,5)->RIGHT` all stayed in place
- `map_reader.lua` now models the full confirmed band:
  `["17,6"]={north=true}`, `["18,6"]={north=true}`,
  `["19,6"]={north=true}`, `["20,6"]={north=true}`,
  `["21,4"]={west=true}`, `["21,5"]={west=true}`
- `main.lua` now suppresses `auto_step.update()` on raw debug-input frames, so
  raw control checks cannot create synthetic blocked auto-step evidence
- `map_survey.lua` now keeps state/timing-only blocked candidates visible for
  diagnostics as `confidence=needs_repro`, but excludes them from strong
  candidate reports and exported/pasteable map-data suggestions
- see `HANDOFF_2026-04-26_map04_east_connector_probe_followup.md`
- see `HANDOFF_2026-04-26_map04_post_reload_survey_followup.md` for the correction

Code status (2026-04-26 — **RELOADED AND VERIFIED**):
- `map_reader.lua` — MAP_DOOR_CELLS[0x04] added: (10-14,6) = magic-key doors
- `map_reader.lua` — east connector patch: `17,6/18,6/19,6/20,6 north=true`;
  `21,4/21,5 west=true`
- MAP_BLOCKED_CELLS comment for (11,9) corrected (was wrongly called "closed door")
- MAP_DOOR_CELLS comment corrected (removed false "sole crossing" claim, then
  narrowed the overbroad "east-wing targets are reachable" note after parked
  target checks showed the far-east cluster still no-path)
- `luac -p map_reader.lua` passes; `lua test_map_reader.lua` 10/13 (3 pre-existing)

### Key discovery: map 0x04 topology (corrected 2026-04-26 post-verification)

Map 0x04 has a horizontal **magic-key door band at y=6, x=10-14** (5 type-15 tiles,
confirmed by dump_grid). These are the ONLY F- tiles on the map. MAP_DOOR_CELLS[0x04]
added so is_walkable() dynamically checks opened-door RAM ($600C/$600D).

**Corrected revision**: The **x=5 decoder gap bypass** at (5,6)
(MAP_PASSTHROUGH_CELLS) reaches the y=4 east connector without magic keys:
```
(10,8) → west to ~x=5 → north via x=5 column →
(5,7) → (5,6)[passthrough] → (5,5) → (5,4)[passthrough] →
(6,4)[passthrough] → (7,4)[passthrough] → (8,4)[passthrough] →
y=4 east corridor
```

Do **not** generalize that to all east-side targets. Post-catch-up live checks
from `(10,8)` with parked NPCs showed clean no-path for the far-east/upper-east
targets `npc_9` `(26,21)`, `npc_10` `(24,1)`, and `npc_11` `(27,5)`. The
confirmed `21,4/21,5 west` blocks still separate that cluster; no blocked-event
or candidate evidence points to a missing opening.

**What the magic-key doors DO gate**: The door band at y=6, x=10-14 provides the
*shorter direct-center* crossing. Only (14,6) is useful as a path node:
`(14,6)→(14,5)[passthrough]→(14,4)[passthrough]→east wing`. Doors at (10-13,6)
exit into MAP_BLOCKED_CELLS north-wall cells at y=5 — dead ends.

**West wing status**: NOT YET VERIFIED via x=5 bypass. x=5 north reach y=4
confirmed; whether y=4 west section or antechamber north allows routing into west
wing without keys is unknown. Treat west wing as potentially gated pending test.

### Additional notes

- (11,9) "antechamber door" comment in MAP_BLOCKED_CELLS was a misidentification:
  dump_grid confirmed (11,9) is tile type 6+ (walkable), NOT type 15. Comment fixed.
- (17,6)/(18,6)/(19,6)/(20,6) north=true and (21,4)/(21,5) west=true are now
  patched from 2026-04-26 post-reload raw held-input confirmation. The earlier
  raw pass that crossed 20,6/21,4/21,5 was treated as stale-state contamination.
- x=15 east=true blocks at y=1-3 confirmed genuine (2026-04-24 natural walk test).

Prior survey result (2026-04-24, superseded by later false-positive removals and
the fresh 2026-04-26 survey note above):
- 15/29 successes (52%)
- 6 gated/isolated — all west-wing magic-key targets; CORRECT, expected
- 5 suspected_engine_blocked — all blocked at (17,6) north on first step from (17,5)
- 3 state_issues — long routes hitting (17,6) mid-route
- Dominant bottleneck was `(17,6) north`; this older uncertainty is now resolved
  by the 2026-04-26 raw held-input follow-up. Current code models `17,6/18,6/19,6`
  north only.

Key findings from this session:
- `0x003C` (MOVEMENT_STATE) and `0x003D` stale values cause probe false positives
  (turn-in-place mechanism); both normalized to 0x00 on teleport_to — DONE
- x=15 east blocks (15,1/15,2/15,3) GENUINE: 90-frame natural walk test confirmed
  at y=1,2,3; east=true restored to static model
- `(17,6) north` is now settled by the 2026-04-26 raw held-input follow-up and
  patched with `18,6` and `19,6` north.
- Pattern: "moved on direct probe" results were all anomalous sub-pixel states
  (0x003E differing from natural value by 1 tile); natural walk is ground truth
- Survey was started at (10,8) and succeeded with (10,29) final position

## Current State

### Changes made this session (2026-04-24 — bug-hunt)

**Seam oscillation fix** (`route_manager.lua` — `observe_seam_result`):

Root cause of mixed survey/probe data: `observe_seam_result("moved")` was
unconditionally clearing any runtime block on a single successful traversal,
even when that cell had a prior `blocked_count > 0`. This let one
state-contaminated probe erase a seam-confirmed engine block, causing A* to
re-plan routes through unreliable cells and re-trigger the same block cycle.

Fix: `clear_runtime_block_direction` is now only called when
`entry.blocked_count == 0` (purely passable seam, no prior blocking evidence).
A noisy or confirmed-blocked seam keeps its runtime block until
`clear_runtime_blocks` / `clear_seam_cells` is called explicitly.

- `test_route_manager.lua` updated; test renamed to
  `successful_traversal_marks_noisy_seam_but_confirmed_block_persists`
- `lua test_route_manager.lua` — 13/13 pass

**Teleport diagnostic logging** (`main.lua` — `teleport_to` command):

When `debug_mode=true`, every `teleport_to` now logs:
```
TELEPORT_PRE  to=(X,Y) map=0x04 ram0030_004F=<32 hex bytes>
TELEPORT_POST to=(X,Y) map=0x04 ram0030_004F=<32 hex bytes>
```

PRE captures the pre-teleport state (history-dependent). POST shows exactly
which bytes the teleport changed (should be ONLY positions 0x0A/0x0B in the
0x0030 window = PLAYER_X/PLAYER_Y). Any byte that differs between passing and
blocking probe sessions in the PRE/POST lines is a normalization candidate for
teleport_to.

**0x003C documented** (`addresses.lua` — new constant `M.MOVEMENT_STATE`):

Added documentation for 0x003C as suspected movement-state/facing byte with
a note that `teleport_to` does not normalize it and that this is the suspected
root cause of state-dependent probe results.

Validation:
```
luac -p route_manager.lua main.lua addresses.lua  — all pass
lua test_route_manager.lua                         — 13/13 pass
```

### Changes made this session (2026-04-24)

**x=15 hidden-state probe**
(`HANDOFF_2026-04-24_x15_hidden_state_probe.md`):

Focused checks on `(16,3)->LEFT` into `(15,3)` showed the same modeled-open
edge can either block or move depending on stale coordinate/camera-adjacent RAM
left behind by previous movement and `teleport_to`.

Key evidence:
- after one hidden-state pattern, repeated left holds/probes from `(16,3)` into
  `(15,3)` blocked after full timeout/retry
- reverse movement from `(15,3)->RIGHT` was allowed and changed the raw
  coordinate-adjacent byte pattern
- after that reverse traversal, `teleport_to:16,3` preserved a different hidden
  state and `probe_edge:16,3,LEFT` moved in 6 frames
- after the successful probe changed state again, teleporting back to `(16,3)`
  produced another hidden-state pattern and the same edge blocked

Interpretation:
- do not promote `(15,3) east=true` into permanent map data from mixed evidence
- the failure is stateful; `teleport_to` likely needs stronger normalization or
  better diagnostics around movement/camera/subtile RAM

Patch applied:
- `debug_tools.lua` now supports `report_movement_state[:TAG]`
- `debug_hooks.txt` documents it

Validation:
- `luac -p debug_tools.lua` passed

Immediate next step:
- reload the full Lua script
- rerun the pass/block sequence with `report_movement_state` tags immediately
  before and after each probe

**Movement A/B targeted checks**
(`HANDOFF_2026-04-24_movement_ab_targeted_checks.md`):

After reloading the script with new auto-step instrumentation, the targeted
throne-room survey was rerun from `(17,5)`.

Baseline `auto_step_inject_limit=12`:
- planner found the same 19-step route
- normal route moves completed with structured timing logs
- x=15 left-entry attempts all exhausted full timeout/retry:
  `frames=60 timeout_retries=3/3 turn_represses=1 inject_limit=12`
- final result remained `command_timing_or_state_issue`, `path_found=true`,
  `movement_succeeded=false`, `final=(16,3)`,
  `suspected_tiles=15,3|15,2|15,1`

A/B `auto_step_inject_limit=24`:
- reloaded config and reran the same target
- x=15 still blocked repeatedly with full timeout/retry
- longer injection introduced overshoot/chaining:
  after `(17,5)->UP`, the next queued `UP` began from `(17,3)` instead of
  `(17,4)`
- the A/B survey was manually stopped after enough evidence

Cleanup:
- restored `auto_step_inject_limit=12`
- `reload_config` succeeded
- cleared runtime blocks and seam memory
- `report_path_state` confirmed `runtime_count=0`

Interpretation:
- do not globally increase `auto_step_inject_limit`
- the simple "hold longer" hypothesis is not supported
- next focus should be hidden movement/facing/subtile/scroll state and whether
  `teleport_to`/direct probes leave collision state inconsistent

**Movement timing/state noise investigation**
(`HANDOFF_2026-04-24_movement_noise_investigation.md`):

Focus shifted from map-data patching to movement execution noise after the
post-x15-reopen survey found a route but failed during execution.

Same-session x=15 checks after the failed survey:
- `probe_edge:16,3,LEFT` blocked despite model-open preview
- `simulate_raw_input:LEFT,90` from `(16,3)` also did not move; final position
  remained `(16,3)`

Interpretation:
- for this current state, longer raw hold alone did not solve `(16,3)->(15,3)`
- earlier direct-probe successes through x=15 may have depended on hidden
  movement/facing/subtile/teleport state
- do not treat the x=15 contradiction as settled permanent map data yet

Patch applied:
- `auto_step.lua` now exposes movement timing knobs through config:
  `auto_step_inject_limit`, `auto_step_turn_repress_delay`,
  `auto_step_turn_repress_limit`, `auto_step_turn_repress_release_frames`,
  and `auto_step_block_retry_limit`
- `auto_step.lua` now logs structured completion/block timing:
  frames, retry counts, turn re-press count, inject limit, and queued-route flag
- `config.lua` and `dw_access.ini` include the new keys

Validation:
- `luac -p auto_step.lua config.lua` passed
- `lua test_auto_step.lua` passed

Immediate next step:
- reload the full Lua script
- rerun the targeted throne-room survey
- compare new `auto_step complete` / `auto_step blocked` log lines
- if needed, A/B test `auto_step_inject_limit=24` via `reload_config` or script
  reload

**Map 0x04 post-x15-reopen targeted survey**
(`HANDOFF_2026-04-24_map04_post_x15_reopen_target_survey.md`):

After reloading the full FCEUX Lua script, the targeted throne-room stairs
survey was rerun from `(17,5)`:
- `survey_target:Stairs Down to Throne Room,park_npcs`

Result:
- planner now finds a 19-step route to adjacent `(2,1)`
- target is no longer `no_route_found`
- movement executed through `(17,4)`, `(17,3)`, and `(16,3)`
- queued route execution then repeatedly blocked on x=15 east-entry seams:
  `15,3`, `15,2`, and `15,1`
- final class was `command_timing_or_state_issue`, not
  `suspected_engine_blocked`

Final summary:
- `path_found=true`
- `path_length=19`
- `movement_succeeded=false`
- `final=(16,3)`
- `blocked_events=9`
- `suspected_tiles=15,3|15,2|15,1`
- `reason=reroute_no_path`

Interpretation:
- reopening x=15 fixed planning
- remaining issue is contradictory direct-probe-vs-queued-route behavior at
  x=15, so do not re-promote static x=15 `east=true` from this survey alone

Immediate next step:
- run same-session controlled direct probes for `(16,3)->LEFT`, `(16,2)->LEFT`,
  and `(16,1)->LEFT`
- if direct probes move while queued routes block, investigate auto-step timing
  or seam-bruteforce behavior before changing permanent map data

**Map 0x04 legitimate throne-route investigation**
(`HANDOFF_2026-04-24_map04_legit_throne_route.md`):

After the post-south-patch target check made `Stairs Down to Throne Room`
report clean `no_route_found`, a connector investigation found the static
model was still masking a legitimate north-corridor route.

Fresh-reload direct probes contradicted the prior x=15 east-entry patch:
- `(16,1)->LEFT->(15,1)` moved through the modeled block
- `(16,2)->LEFT->(15,2)` moved through the modeled block twice
- `(16,3)->LEFT->(15,3)` moved through the modeled block

Patch applied:
- removed `east=true` from `["15,1"]`, `["15,2"]`, and `["15,3"]`
- kept `["15,3"] = {south = true}` because the south-entry block was
  independently confirmed from `(15,4)->UP`
- added regression coverage in `test_map_reader.lua`

Validation:
- `luac -p map_reader.lua` passed
- `lua test_map_reader.lua` still has three unrelated existing failures, but
  the new x=15 regression test passed

Immediate next step:
- reload the full FCEUX Lua script
- rerun from `(17,5)`:
  `survey_target:Stairs Down to Throne Room,park_npcs`

**Map 0x04 post-south-patch reload check**
(`HANDOFF_2026-04-24_map04_post_south_patch_reload_check.md`):

After reloading Lua, the focused throne-room target check was rerun from `(17,5)`:
- `survey_target:Stairs Down to Throne Room,park_npcs`

Result:
- no movement attempt through the newly patched seams
- target now fails cleanly as planner `no_route_found`
- `blocked_events=0`
- `suspected_tiles=-`
- `reason=no_path`

Follow-up:
- `debug_pathfind_adjacent:1,1`
- `dump_path_grid`

confirmed:
- `Debug pathfind adjacent to (1,1): No path found [no_path] (visited=587 path=0)`

Interpretation:
- this is likely progress: the model no longer claims a path through engine-
  rejected seams
- open question is whether `stair_1_1` should now be considered gated/isolated
  from main-hall start `(17,5)`, or whether another legitimate connector is
  still missing

Immediate next step:
- rerun broader `survey_objects:park_npcs` after reload to measure overall impact
- classify `stair_1_1` carefully if it remains `no_route_found`

**Map 0x04 south-entry probe confirmation**
(`HANDOFF_2026-04-24_map04_south_entry_probe_confirmation.md`):

Controlled post-reload direct probes were run for the three remaining
throne-route suspects:
- `(15,4)->UP->(15,3)`
- `(8,4)->UP->(8,3)`
- `(14,4)->UP->(14,3)`

All three blocked 3/3, logged
`EDGE_PROBE_MODEL_MISMATCH ... blocked_despite_open_preview`, and reached
runtime `classification=confirmed_blocked`.

Runtime export:
- `["8,3"] = {south=true}`
- `["14,3"] = {south=true}`
- `["15,3"] = {south=true}`

Interpretation:
- these three were promoted into permanent `MAP_DIRECTIONAL_BLOCKS[0x04]`
- this supersedes the earlier contradictory direct-pass evidence because the
  new checks were post-reload, adjacent-start, and reproduced 3/3

Patch applied:
- `["8,3"] = {south = true}`
- `["14,3"] = {south = true}`
- `["15,3"] = {east = true, south = true}`

Validation:
- `luac -p map_reader.lua` passed

Immediate next step:
- reload Lua and rerun the focused throne-room target survey from `(17,5)`

**Map 0x04 post-x15 reload check**
(`HANDOFF_2026-04-24_map04_post_x15_reload_check.md`):

After the user reloaded the FCEUX Lua script, the focused target check was rerun:
- start `(17,5)`
- command: `survey_target:Stairs Down to Throne Room,park_npcs`

The fresh log header confirmed script reload:
- `Started: 2026-04-24 10:02:17`

Result:
- the static `x=15 east=true` patch loaded and removed the old
  `15,1|15,2|15,3` east-entry failure band from the active target result
- the run was manually stopped after it repeatedly hit the remaining
  direct-pass-but-route-blocking south-entry seams

Final stopped result:
- `failure_class=suspected_engine_blocked_tile`
- `suspected_tiles=15,3|8,3|14,3`
- `blocked_tiles=15,3|8,3|14,3|8,3|14,3`
- `reason=manual_stop`

Interpretation:
- the `x=15 east=true` patch had the intended effect
- remaining bottleneck is now `(15,3)` south, `(8,3)` south, and `(14,3)` south
- do **not** promote these yet based only on routed movement, because they moved
  in earlier controlled direct probes

Immediate next step:
- repeat controlled post-reload direct probes for:
  `(15,4)->UP->(15,3)`, `(8,4)->UP->(8,3)`, `(14,4)->UP->(14,3)`

**Map 0x04 x=15 east-entry patch**
(`HANDOFF_2026-04-24_map04_x15_east_patch.md`):

Patched `map_reader.lua` with only the three direct-confirmed east-entry seams:
- `["15,1"] = {east = true}`
- `["15,2"] = {east = true}`
- `["15,3"] = {east = true}`

Validation:
- `luac -p map_reader.lua` passed

Not patched:
- `(17,6)` north
- `(8,3)` south
- `(14,3)` south
- `(15,3)` south

Attempted a focused `survey_target:Stairs Down to Throne Room,park_npcs`
before a full Lua reload, but this was **not a valid assessment** of the static
patch because the running script had not reloaded `map_reader.lua` and the
survey harness cleared the matching runtime blocks at attempt reset:
- `SURVEY_START ... runtime_blocks=3`
- `runtime blocks cleared: map=0x04 count=3`
- `SURVEY_ATTEMPT_RESET ... cleared_runtime_blocks=3`

The stale-code run was manually stopped after it re-learned the same x=15
east-entry blocks and entered a long reroute. Real impact testing still requires
full FCEUX Lua script reload, not `reload_config`.

Immediate next step:
- reload the full Lua script in FCEUX
- run from `(17,5)`:
  `survey_target:Stairs Down to Throne Room,park_npcs`

**Map 0x04 suspect direct probes**
(`HANDOFF_2026-04-24_map04_suspect_direct_probes.md`):

Controlled direct probes were run for the overnight suspect seams without
batching `teleport_to` with `probe_edge`.

Direct passes:
- `(17,5)->DOWN->(17,6)` moved
- `(8,4)->UP->(8,3)` moved
- `(14,4)->UP->(14,3)` moved
- `(15,4)->UP->(15,3)` moved

Direct confirmed blocks:
- `(16,1)->LEFT->(15,1)` blocked 3/3 and reached `classification=confirmed_blocked`
- `(16,2)->LEFT->(15,2)` blocked 3/3 and reached `classification=confirmed_blocked`
- `(16,3)->LEFT->(15,3)` blocked 3/3 and reached `classification=confirmed_blocked`

Runtime export after the probes:
- `["15,1"] = {east=true}`
- `["15,2"] = {east=true}`
- `["15,3"] = {east=true}`

Interpretation:
- do **not** patch `(17,6)` north, `(8,3)` south, `(14,3)` south, or
  `(15,3)` south from this evidence
- the only current strong permanent map-data candidates are the three
  east-entry seams at `(15,1)`, `(15,2)`, and `(15,3)`
- `map_reader.lua` was intentionally left unchanged pending the patch decision

Immediate next step:
- if approved, add only those three `east=true` entries to
  `MAP_DIRECTIONAL_BLOCKS[0x04]`, reload Lua, and run a focused
  `survey_target:Stairs Down to Throne Room,park_npcs` from `(17,5)`

**Map 0x04 overnight parked-NPC survey analysis**
(`HANDOFF_2026-04-24_map04_overnight_survey_analysis.md`):

The user ran a fresh overnight `survey_objects:park_npcs` survey on map `0x04`.
The local `dw_debug.log` started at `2026-04-24 00:05:02` and showed:
- `CMD: teleport_to:10,10`
- `CMD: survey_objects:park_npcs`

There is no configured Git remote in this checkout, so there was nothing to
network-pull. The analysis was performed from the local log artifact.

Survey result:
- `targets=11`
- `successes=3`
- `failures=8`
- `gated_or_isolated=5`
- `suspected_engine_blocked=2`
- `state_issues=1`

Most important regression result:
- the old `route_inactive_without_completion` orphan behavior did **not** recur
- `17,6` seam-bruteforce now attempts `1/2`, then `2/2`, then cancels through
  normal `reason=reroute_no_path`

New runtime-confirmed-but-contradictory seam evidence from the survey:
- `(17,6)` north
- `(8,3)` south
- `(14,3)` south
- `(15,1)` east
- `(15,2)` east
- `(15,3)` south and east

Interpretation:
- do **not** promote these to permanent `map_reader.lua` directional blocks yet
- the 2026-04-23 direct probe campaign moved through all of these seams, so the
  overnight survey contradicts direct-probe evidence
- treat this as noisy seam / auto-step execution timing until controlled
  adjacent-start `probe_edge` reruns prove otherwise

Immediate next step:
- re-probe the contradictory seams from exact adjacent starts, especially
  `(17,5)->DOWN->(17,6)`, without batching `teleport_to` and `probe_edge`

### Changes made this session (2026-04-23)

**Map 0x04 seam-retry orphan fix** (`HANDOFF_2026-04-23_map04_seam_retry_orphan_fix.md`):

Focused live debugging showed that the remaining east-side `(17,6)` failures
were not just a bad map decode.

Direct probe result:
- `(17,5) -> (17,6)` is mixed: it blocked once and moved once
- `(17,6) -> (17,5)` moved cleanly

That means `(17,6)` north-entry is currently a **noisy seam**, not yet safe
for permanent map data.

A clean single-target repro from `(10,10)` using:
- `survey_target:Merchant 3,park_npcs`

showed the real failure path:
- queued route step `(17,5) -> (17,6)` blocked
- reroute launched `SEAM_BRUTE_FORCE attempt=1/2`
- the brute-force retry also blocked
- `route_manager.lua` treated that blocked retry as an unrelated manual block
  and ignored it
- the route then went inactive without `route_completed` or `route_cancelled`
- survey finalized the target with
  `reason=route_inactive_without_completion`

Code fix applied:
- `route_manager.lua` now keeps blocked seam-bruteforce retries inside reroute
  handling by distinguishing true manual probes from `same_seam_retry(...)`
  failures
- `test_route_manager.lua` now includes
  `failed_seam_bruteforce_retries_again_then_cancels_cleanly`

Validation:
- `luac -p route_manager.lua`
- `luac -p test_route_manager.lua`
- `lua test_route_manager.lua`

All Lua route-manager tests passed.

Immediate next step for live verification:
- now completed: after the script restarted, the focused `Merchant 3`
  parked-NPC repro was rerun live from `(10,10)`
- live result now shows:
  - `SEAM_BRUTE_FORCE ... attempt=1/2`
  - `SEAM_BRUTE_FORCE ... attempt=2/2`
  - final `SURVEY_RESULT ... reason=reroute_no_path`
- the old orphan result `reason=route_inactive_without_completion` no longer
  appears

Immediate next step:
- rerun a full `survey_objects:park_npcs` on map `0x04`
- measure how many east-side failures disappear now that seam retries cancel
  cleanly instead of orphaning the survey

**Map 0x04 post-patch survey analysis** (`HANDOFF_2026-04-23_map04_post_patch_survey.md`):

After adding the five directly confirmed directional blocks
`(18,6)/(19,6)/(20,6) north=true` and `(21,5)/(21,4) west=true`, a fresh
parked-NPC survey was rerun on map `0x04`.

Result:
- `successes=14`
- `failures=15`
- `gated_or_isolated=5`
- `suspected_engine_blocked=8`
- `state_issues=2`

This did not improve the raw total yet, but it did narrow the dominant east-side
failure mode. The old `(18-21,4-6)` false-open cluster dropped out, and most
remaining east failures now collapse onto a single seam:
- `(17,6)` approached from north, i.e. the first southward step from `(17,5)`

Important interpretation:
- `(17,6)` still should **not** be promoted to permanent map data yet
- it moved on the earlier direct manual probe
- it also appears in at least one successful reroute path later in the survey
- current evidence points more toward a narrow route/execution or noisy-seam issue
  than a clean permanent wall

Immediate next step for map04 work:
- debug the `(17,5)->(17,6)` step directly with a focused single-target/path-debug run

**Map 0x04 suspect probe campaign** (`HANDOFF_2026-04-23_map04_suspect_probe.md`):

After a fresh `survey_objects:park_npcs` run on map `0x04`, a temporary probe
script (`probe_map04_suspects.sh`) directly tested the unique suspect seams.

Probe result summary:
- 14 targeted probes total
- 5 direct blocked mismatches
- 9 direct passes

Five seams are now strong permanent-model candidates because direct probes
blocked with `EDGE_PROBE_MODEL_MISMATCH ... blocked_despite_open_preview`:
- `(18,6)` north=true
- `(19,6)` north=true
- `(20,6)` north=true
- `(21,5)` west=true
- `(21,4)` west=true

Important non-findings:
- `(17,6)` from north moved successfully on direct probe and should stay
  **unmodeled for now** (treat as noisy / unresolved)
- earlier survey suspects `(14,5)`, `(15,5)`, `(8,3)`, `(14,3)`, `(15,3)`,
  `(15,2)`, `(15,1)` all passed on direct probe and should **not** be promoted
  to permanent blocks from this run

Immediate next step for map04 work:
- rerun `survey_objects:park_npcs` against the newly patched map model

**Startup Lua failure matrix** (`HANDOFF_2026-04-23_loadlua_failure_matrix.md`):

The user reran `./launch_dw.sh` and it failed waiting for `dw_debug.log`.
Fresh testing then showed that startup Lua is failing before any Lua-side files
refresh, even though the live `qfceux.exe` process receives `--loadlua=...`.

`frame_probe.lua` was used to isolate startup-Lua behavior from `main.lua`.
It failed to start under all tested variants:
- default `--loadlua ... ROM` order
- ROM-first order
- no-space ROM path (`dw1_cli_test.nes`)
- direct PowerShell `Start-Process`
- temporary `SDL.LuaScript = frame_probe.lua`

No visible Lua error dialog was present. File-based PowerShell automation can
activate the FCEUX window, but tested `Ctrl+L`, `Shift+L`, and `Alt+S` → `R`
did not revive the script.

Temporary cleanup completed:
- restored `SDL.LuaScript =` blank
- closed the final probe-launched `qfceux.exe`

Immediate next step:
- manual UI verification inside FCEUX on a fresh launch to confirm whether ROM
  loading and Lua reload work by hand in this build

**Manual-load path hardening** (`main.lua`):

User follow-up evidence showed that launcher-started emulator instances also
failed when manually loading the accessibility script, with output pointing near
`main.lua` line `18` (`require "tolk"`).

`main.lua` now prepends its own directory to `package.path` before the first
`require(...)`, so sibling modules like `tolk.lua` no longer depend on FCEUX's
current working directory.

Immediate retest after this patch:
- launch through the project launcher
- manually load `main.lua` in FCEUX
- if it now starts, the manual-load branch is fixed even if startup autoload
  remains broken

Result:
- user confirmed manual loading now works in a launcher-started emulator
- this fixes the manual-load/module-search-path branch
- remaining launcher issue is startup autoload only

### Changes made this session (2026-04-23)

**Launcher readiness probe cleanup** (`launch_dw.ps1`, `debug_tools.lua`,
`debug_hooks.txt`):

Launch debugging found that the old readiness probe used `speech_status`, which
is not a pure command-polling test because it routes through the speech backend.

Three changes applied:
- `debug_tools.lua` added `launcher_probe[:TAG]`, which writes
  `LAUNCHER_PROBE: TAG` to `dw_debug.log`
- `launch_dw.ps1` now queues a GUID-tagged `launcher_probe:<tag>` and waits for
  that exact log line instead of using `speech_status`
- `debug_hooks.txt` documents the new launcher probe command

Evidence gathered this session:
- `speech_bridge.log` showed the bridge launched and startup speech fired on
  2026-04-23, so the unresolved issue is more likely command polling / launcher
  readiness than basic `--loadlua` failure
- stale launch-diagnostic leftovers from ad-hoc experiments should not be
  treated as a clean repro baseline

Immediate next step for launcher work:
```
./launch_dw.sh
```
If it still fails, the error will now name the exact `LAUNCHER_PROBE: <tag>`
marker it was waiting for.

### Changes made this session (2026-04-22)

**Map 0x04 east-wing connectivity — y=4 corridor fully modeled** (`map_reader.lua`):

Survey run 2 from `(10,8)` completed `29/29` targets with only 7 successes and 15
east-wing `state_issues`. All 15 failed from `final=(5,1)` with `suspected_tiles=6,2|6,1`.

Root cause: `(8,4)` was missing from `MAP_PASSTHROUGH_CELLS`, so A* couldn't bridge
from `(7,4)` east to the open corridor at `(9,4)+`. Combined with an unmodeled
`(7,3) south=true` block that made A* plan a false route through `(7,4)→N→(7,3)`.

Probe campaign (`probe_east_wing.sh`, 18 probes) confirmed:
- `(7,4)→UP→(7,3)` BLOCK — (7,3) south=true real
- `(7,4)→RIGHT→(8,4)` PASS moved_through_modeled_block — (8,4) is decoder gap
- `(5,1)→RIGHT→(6,1)`, `(5,2)→RIGHT→(6,2)` BLOCK — x=6 north corridor walls real

Three changes applied to `map_reader.lua`:
- `MAP_PASSTHROUGH_CELLS[0x04]["8,4"] = true` — bridges y=4 corridor to east wing
- `MAP_DIRECTIONAL_BLOCKS[0x04]["7,3"] = {south=true}` — blocks northward entry from (7,4)
- `MAP_DIRECTIONAL_BLOCKS[0x04]["6,1"] = {west=true}` — x=6 north corridor walls
- `MAP_DIRECTIONAL_BLOCKS[0x04]["6,2"] = {west=true}`
- `MAP_DIRECTIONAL_BLOCKS[0x04]["6,3"] = {west=true}` (inferred; not directly probed)

Post-fix pathfind verification (all from `(10,8)`) confirmed paths found to:
- Guard 1 (13,2), Guard 2 adj (23,10), Guard 9 adj (16,20), Stairs Down adj (24,2), (20,4) direct

The y=4 corridor is now fully modeled:
```
(4,4)→(5,4)→(6,4)→(7,4)→(8,4)[new]→(9,4)→...→(13,4)→(14,4)→east wing
```

### Uncommitted changes in working tree

All changes from this session AND prior sessions remain uncommitted:
```
map_reader.lua      — (8,4) passthrough, (7,3) south=true, (6,1-3) west=true, comment fixes
probe_east_wing.sh  — new: 18-probe east-wing connectivity campaign
probe_map04_suspects.sh — new: targeted 14-probe campaign for fresh survey suspects
auto_step.lua       — restore 18-frame re-press timing; neutral gap; manual input cancels routes
route_manager.lua   — stop forwarding autonomous route suppression to auto_step
map_survey.lua      — stop requesting autonomous route suppression; survey-logic improvements
test_auto_step.lua  — neutral-gap + manual-override coverage
debug_tools.lua     — multi-frame simulate_input holds
debug_hooks.txt     — document multi-frame syntax
dw_commands.ps1     — PowerShell command sender
codex.ps1           — LuaJIT + luarocks PATH setup for Codex
AGENTS.md           — prefer dw_commands.ps1 in PowerShell
.codex/             — hooks and skill updates for Codex/PowerShell
```

### Open issues

1. **Immediate next step**: Reload the full Lua script in FCEUX, then rerun a
   focused east-wing target or full `survey_objects:park_npcs` from a clean open
   start to measure the impact of the full east-connector band patch and the
   stranded-start trimming fix.

2. **Guard 1 (13,2) not execution-tested**: A* plans a path via y=4 corridor + x=8
   north column, but auto_step hasn't walked it. Route: `(8,4)→2N→(8,2)→5E→(13,2)`.

3. **`(9,1)` decoder gap unmodeled**: `(8,1)→RIGHT→(9,1)` moves through modeled block.
   Not urgent — y=4 corridor is primary, y=1 route not used by A*.

4. **East connector residual watchpoint**: the full `17..20,6 north` plus
   `21,4/21,5 west` band is now modeled. If this creates new no-route issues,
   debug alternate connectors before removing the blocks again.

5. **`(6,3)` not directly probed**: teleport to (5,3) missed during probe campaign;
   added as inferred west=true from consistent x=6 barrier pattern.

6. **West-wing targets still gated** (magic-key door) — unchanged, expected.

7. **Open issues from prior handoff still apply** (survey-logic, (3,16)/(4,15) noisy
   seams, (6,11) west-wing seam, Guard 4 internal west-pocket failures).

## Best Resume Points

**First action next session:**
1. Reload Lua script in FCEUX (Script > Reload)
2. Teleport to a good open start: `./dw_commands.sh teleport_to:10,8`
3. Run a focused east-wing target or `./dw_commands.sh survey_objects:park_npcs`
4. Check `SURVEY_CANDIDATE*` output for `confidence=needs_repro` entries before
   promoting any further map-data blockers

**PowerShell users** (Codex): use `./dw_commands.ps1` instead of `./dw_commands.sh`.
Quote comma-bearing arguments: `./dw_commands.ps1 "teleport_to:10,8"`.

**Do not:**
- Survey from staircase tile (7,7) — still triggers low-exit-count abort
- Remove (12,16) east=true block
- Remove (20,16) south=true or (21,17) west=true — both real engine blocks
- Treat (3,16)/(4,15) as stable — they are noisy seam cells, monitor only
