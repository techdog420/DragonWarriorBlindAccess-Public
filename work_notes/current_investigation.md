## Findings

### RIMULDAR IMPORTANT-TARGET ROUTE LOG REVIEW - 2026-05-21
- User reload/test pass after the Weapons Merchant geometry patch looked strong:
  all route attempts in the fresh log ended with
  `AUTO_WALK_NPC_PARK_RESTORE ... reason=autowalk route complete`.
- Completed route set in the log:
  - Weapons Merchant <-> Exit
  - Inn -> Exit
  - Exit -> Magic Key Merchant
  - Magic Key Merchant -> Exit
  - Exit -> Chest
  - Chest -> Exit
- The one visible Magic Key route hiccup was near the end of the inbound route:
  - `(2,8)->UP` into `(2,7)` blocked during the queued route and seam retry,
    so the runtime planner marked `(2,7)` temporarily blocked.
  - The route then tried `(2,8)->RIGHT` into `(3,8)`, first saw a transient
    block, brute-forced it, classified it noisy, and finished cleanly at the
    Magic Key Merchant stand `(4,6)` facing south.
- Direct follow-up verifiers showed these were not permanent geometry fixes:
  - `probe_edge_verify:2,8,UP,5` moved 5/5 into `(2,7)`.
  - `probe_edge_verify:16,17,RIGHT,5` moved 5/5 into `(17,17)`.
  - `probe_edge_verify:4,9,RIGHT,5` moved 5/5 into `(5,9)`.
- Conclusion:
  - no new `map_reader.lua` patch is indicated from this route sweep
  - the remaining artifacts are transient route-step timing recoveries, not
    durable blockers
  - the crawler-opened hidden paths also produced a working route from the
    Magic Key Merchant back to the main entrance
  - Rimuldar's important-target route sweep is complete enough to leave town
  - player was restored to Rimuldar `(29,13)` afterward

### RIMULDAR ENTRANCE-TO-WEAPONS MERCHANT FOLLOW-UP - 2026-05-21
- Goal: keep the town-entrance route to the Weapons Merchant service stand
  `(24,7)` reachable after the latest chest-route geometry corrections.
- Confirmed new blocker:
  - autowalk reached `(20,8)` and repeatedly tried `RIGHT` into `(21,8)`
  - `probe_edge_verify:20,8,RIGHT,5` blocked `5/5` with no drift, map change,
    refusal, or interruption
  - promoted `MAP_DIRECTIONAL_BLOCKS[0x0B]["21,8"].west`
- Route-collapse follow-up:
  - with that edge runtime-blocked, the planner no longer found the old
    entrance-to-merchant path
  - the missing bridge was the east x=29 hidden north strip below the already
    modeled x=29 upper cells
- Confirmed hidden strip:
  - `probe_edge_verify:29,13,UP,5` moved into `(29,12)` `5/5`
  - forced-origin raw probes moved `(29,12)->UP`, `(29,11)->UP`,
    `(29,10)->UP`, and `(29,9)->UP` cleanly `5/5` each
  - `(29,8)` is ordinary walkable floor, and `(29,7)` was already modeled
- Permanent patch:
  - added passthrough cells `(29,9)`, `(29,10)`, `(29,11)`, and `(29,12)`
    to `MAP_PASSTHROUGH_CELLS[0x0B]`
  - added focused `test_map_reader.lua` assertions for the new strip and
    blocker
- Reload note:
  - FCEUX needs a Lua reload before the live route planner sees these new
    permanent passthroughs.

### RIMULDAR ENTRANCE-TO-CHEST PLANNER ROUTE VIA `(23,18)` - 2026-05-21
- Goal: find a clean open route from the town entrance `(29,14)` to the Wings
  chest at `(23,23)` with both inn doors open.
- Lower/middle frontier candidates stayed unsuitable for permanent promotion:
  - `(22,25)->UP` into `(22,24)` first looked open, then blocked on a fresh
    verifier; the temporary passthrough was backed out.
  - `(21,19)->UP` into `(21,18)`, `(20,19)->UP` into `(20,18)`,
    `(22,25)->RIGHT` into `(23,25)`, and `(14,22)->RIGHT` into `(15,22)` were
    mixed/noisy and remain unpromoted.
  - `(21,25)->UP`, `(20,25)->UP`, `(14,23)->RIGHT`, and `(14,24)->RIGHT`
    verified blocked 5/5 and should stay modeled as blockers.
- Chest-side crawling exposed the useful bridge candidate `(23,18)`:
  - crawler evidence showed `(23,19)->UP` reaching `(23,18)` and `(23,18)->UP`
    continuing to `(23,17)`.
  - direct verifier from `(23,19)->UP` stayed mixed (`8 moved / 7 blocked` over
    the larger retry), so do not model that approach as clean.
  - direct verifier from the public-side approach `(23,17)->DOWN` into
    `(23,18)` moved 5/5 with no drift, refusal, map change, or interruption.
- Permanent patch:
  - added `(23,18)` to `MAP_PASSTHROUGH_CELLS[0x0B]`
  - added matching `test_map_reader.lua` assertions and snapshot coverage
- Planning result after reload:
  - `debug_pathfind_to:23,23` from `(29,14)` now finds 17-step routes through
    `(23,18)` to the chest.
  - Representative trace:
    `(29,14)->(29,15)->(28,15)->(27,15)->(26,15)->(26,16)->(26,17)->(25,17)->(24,17)->(23,17)->(23,18)->(23,19)->(23,20)->(24,20)->(24,21)->(24,22)->(24,23)->(23,23)`.
- Remaining executor issue:
  - `auto_walk:23,23` from `(29,14)` deviated into the lower exit strip and
    looped on blocked `(28,16)/(28,17)` instead of following the traced route.
  - exact `validate_path` reached `(28,15)` on retry, then overshot to
    `(27,15)` during settle and aborted after 1/17 steps.
  - Next work should focus on route queue / auto-step timing from
    `(29,15)->WEST` and why `auto_walk` deviates from the planner route, rather
    than promoting more permanent blockers.
- Tooling sync follow-up:
  - `debug_pathfind_to` / `debug_pathfind_adjacent` now use the route-manager
    coordinate planning path, so route-mode policy and debug traces come from
    the same planning layer as object/autowalk routes.
  - Use `debug_pathfind_to_park_npcs:23,23` from the entrance when comparing
    against parked-NPC autowalk behavior.
- Live validation after reload:
  - `debug_pathfind_to_park_npcs:23,23` from `(29,13)` produced an 18-step
    route through `(23,18)`:
    `(29,13)->(29,14)->(29,15)->(28,15)->(27,15)->(26,15)->(25,15)->(25,16)->(25,17)->(24,17)->(23,17)->(23,18)->(23,19)->(23,20)->(24,20)->(24,21)->(24,22)->(23,22)->(23,23)`.
  - `validate_path` reproduced the executor bug cleanly: steps 1 and 2
    completed, step 3 reached expected `(28,15)`, then the hero slid to
    `(27,15)` during the confirm window. This was post-step input carryover
    after a successful synthetic west step, not a blocked seam.
  - Patch: synthetic `inject_step` and queued-route completions/blocks now force
    the post-step neutral release path, while ordinary manual holds still keep
    the older softer behavior.
  - After live reload, this helped: the old step-3 overshoot no longer
    reproduced. Step 3 `(29,15)->WEST` reached `(28,15)` and stayed stable.
  - The next failure moved to step 4: `(28,15)->WEST` first reported a
    movement-start timeout/block, then the retry reached `(27,15)` and overshot
    to `(26,15)` during confirmation. The log shows the retry saw an early
    subpixel movement start and then scheduled a turn re-press for synthetic
    `inject_step`; that re-press likely landed while movement was already
    completing and committed the extra west tile.
  - Follow-up patch: `inject_step` no longer uses the queued-route-only
    "movement-start twitch, then turn re-press anyway" path after a retry.
    Queued routes keep that special timing behavior; debug/probe injected steps
    should now wait for completion/block instead of re-pressing into an already
    moving tile.
  - Reload follow-up:
    - The overshoot class quieted down; `validate_path` no longer slid past the
      expected tile during confirmation in the repeated checks below.
    - Direct raw verifier confirmed these runtime blockers, each with
      `moved=0 blocked=5` and no drift/map change/interruption:
      `(25,16)->DOWN`, `(24,16)->DOWN`, `(23,16)->DOWN`, `(22,16)->DOWN`,
      `(21,16)->DOWN`, `(20,16)->DOWN`, `(19,16)->DOWN`, `(21,21)->RIGHT`,
      and `(29,17)->LEFT`.
    - `probe_edge_verify:18,16,DOWN,5` and
      `probe_edge_verify:28,16,DOWN,5` both moved 5/5, so those two row-17
      entries are confirmed open crossings.
    - With the runtime blockers active, the full parked-NPC entrance-to-chest
      route from `(29,13)` validated cleanly:
      `(29,13)->(29,14)->(29,15)->(28,15)->(27,15)->(27,16)->(27,17)->(26,17)->(25,17)->(24,17)->(23,17)->(23,18)->(23,19)->(23,20)->(24,20)->(24,21)->(23,21)->(23,22)->(23,23)`.
      `VALIDATE COMPLETE: 18/18 steps OK, 0 mismatches`.
    - Permanent patch follow-up: the confirmed blockers above were promoted to
      `MAP_DIRECTIONAL_BLOCKS[0x0B]` with focused `test_map_reader.lua`
      assertions. The two 5/5 open crossings remain unblocked.

### RIMULDAR CRAWLER STALE-CANDIDATE FILTERING AND X=11 STRIP - 2026-05-21
- Live `Rimuldar (0x0B)` north-edge regression rerun from `(13,20)` no longer re-exported `(12,20)`, so the earlier timing-suspect false-wall fix held.
- That same crawl still exported three directional review candidates and two passthrough candidates:
  - passthrough: `["11,15"] = true`, `["11,16"] = true`
  - directional: `["12,19"] = {north = true}`, `["12,9"] = {south = true}`, `["9,9"] = {south = true}`
- Direct verifier follow-up split the batch:
  - `probe_edge_verify:12,18,DOWN,5` moved `5/5`, so `(12,19).north` is **not** a real blocker
  - `probe_edge_verify:12,10,UP,5` moved `5/5`, so `(12,9).south` is **not** a real blocker
  - `probe_edge_verify:9,10,UP,5` blocked `5/5`, while reverse `probe_edge_verify:9,9,DOWN,5` stayed mixed `moved=3 blocked=2`; leave `(9,9).south` review-only for now
  - `probe_edge_verify:11,17,UP,5` moved `5/5` into `(11,16)`
  - `probe_edge_verify:11,16,UP,5` could not restart there because the cell was not yet live in the running model, so five forced raw `probe_edge:UP` checks from `teleport_to:11,16,force` were used instead; all five moved into `(11,15)`
- Newly confirmed permanent map data:
  - promote `(11,15)` and `(11,16)` into `MAP_PASSTHROUGH_CELLS[0x0B]`
- New crawler bookkeeping bug and fix:
  - after the direct verifiers changed `(12,19).north` and `(12,9).south` from blocked-only to noisy/passable, `report_map_crawl` and `export_map_crawl_candidates` still emitted the old stored candidate set
  - patched `map_crawler.lua` so report/export/count paths re-check current seam classifications through `route_manager.get_seam_observation(...)`
  - directional candidates now export only while their recorded approaches are still `blocked_only` or `confirmed_blocked`
  - passthrough candidates now retain their source approaches and export only while at least one recorded approach still classifies as `passable_only`
- Focused static validation after this follow-up patch:
  - `test_map_crawler.lua`: 23 tests passed
  - `test_map_reader.lua`: 33 tests passed
  - `git diff --check`: clean

### RIMULDAR LAST CRAWLER REVIEW CANDIDATE DISPROVED - 2026-05-21
- Final live follow-up on the remaining crawler export `["9,9"] = {south = true}`:
  - `inspect_move:9,10,UP` and `inspect_move:9,9,DOWN` both reported `effective_passable=true`
  - `probe_edge_verify:UP,5` from `(9,10)` moved into `(9,9)` `5/5`
  - `probe_edge_verify:DOWN,5` from `(9,9)` moved into `(9,10)` `5/5`
- Conclusion:
  - `(9,9).south` is not a blocker and should stay open in the permanent model
  - after those verifier moves updated seam memory, `report_map_crawl` / `export_map_crawl_candidates` reported `no_review_candidates=true`
- Practical result:
  - the current Rimuldar crawler report is clean; there are no remaining review candidates from this pass

### RIMULDAR CHEST-RETURN LOOP AT (16,20) - 2026-05-21
- User-reported live chest-return autowalk loop reproduced at `Rimuldar (0x0B) (16,20)`.
- Recent route evidence before manual stop:
  - queued autowalk repeatedly tried `(16,20)->DOWN` into `(16,21)` and logged `blocked_only` again and again
  - the paired fallback `(16,20)->RIGHT` into `(17,20)` stayed noisy, not cleanly blocked
- Fresh direct follow-up from the stopped loop:
  - `inspect_move:16,20,DOWN` still previewed `effective_passable=true` despite the route failures
  - `probe_edge_verify:16,20,DOWN,5` then blocked `5/5` with no drift or map change
  - promote `(16,21).north` as a confirmed blocker now; the earlier mixed/passable notes are superseded
- Live planning consequence:
  - after temporary `add_blocked_edge:16,20,DOWN`, `debug_pathfind_to:29,13` from `(16,20)` reported `no_path`
  - the planner had been depending on that seam, so the honest new state is that the current permanent model does not yet contain an alternate bridge from this lower chest-return pocket back toward the entrance
- Lower-pocket follow-up around `(17,20)` / `(17,21)` / `(17,22)`:
  - bounded crawls from `(16,20)` and `(17,22)` found no new exportable candidates
  - both runs repeatedly hit an execution anomaly on the `return_to_frontier` step `(17,21)->UP`, once landing at `(17,22)` and aborting as `movement_drift`
  - direct `probe_edge_verify:17,21,UP,5` came back mixed `moved=3 blocked=2`, so do not promote anything there yet
  - `inspect_move` from `(17,22)` shows `UP`, `DOWN`, and `LEFT` modeled open; only `RIGHT` is currently blocked by NPC occupancy
- Practical next state:
  - patch the confirmed blocker `(16,21).north`
  - treat the remaining lower-pocket issue as “missing bridge or execution anomaly still unresolved,” not as another confirmed blocker yet

### CRAWLER FALSE-POSITIVE FILTER TIGHTENING - 2026-05-21
- Root cause of the remaining crawler false-positive path:
  - `mixed_probe` already suppressed cases like `Rimuldar (0x0B) (24,6).south` where a false-wall edge first blocked and then moved on a later crawler attempt.
  - The unresolved bad export path was different: a false-wall move that completed only after the `auto_step` timeout/turn-repress recovery path could still land on the destination and be recorded as a normal `false_wall_candidate`.
  - That is what happened on the earlier `Rimuldar (0x0B) (12,20)` crawl export: the move into `(12,20)` was timing-suspect, not a clean first-pass false-wall crossing.
- Permanent patch:
  - `auto_step.lua` now includes step-completion timing metadata (`timeout_retries`, `turn_represses`, `frames`, `inject_limit`) on `route_step_completed` events.
  - `map_crawler.lua` now classifies false-wall moves completed through `pending_repress` or any timeout/repress retry path as `timing_suspect_false_wall` instead of a normal `false_wall_candidate`.
  - Those timing-suspect cells are marked `MAP_CRAWL_UNSTABLE_CANDIDATE` for the rest of the run, so later same-run re-entries do not get re-exported as ordinary passthroughs.
- Focused tests added and passed:
  - `pending_repress_false_wall_stays_diagnostic_and_exports_nothing` in `test_map_crawler.lua`
  - full focused validation after the patch:
    - `test_map_crawler.lua`: 21 tests passed
    - `test_map_reader.lua`: 33 tests passed
    - `test_auto_step.lua`: 51 tests passed
    - `git diff --check`: clean

### RIMULDAR POST-RELOAD LIVE VALIDATION - 2026-05-21
- Reload validation of the new `stop_map_crawl` behavior succeeded live on `Rimuldar (0x0B)`:
  - A long crawl from `(24,7)` was manually stopped while an in-flight `down` step from `(23,2)` was active.
  - The running script logged `MAP_CRAWL_STOP_WAIT`, then `MAP_CRAWL_STOP_SETTLED ... final=(23,2) expected=(23,3) reason=no_post_stop_movement`, then `MAP_CRAWL_FINISH ... reason=manual_stop`.
  - A delayed `report_position` still showed the hero stable at `(23,2)`, so the earlier “finish now, drift later” bug is fixed live.
- Reload follow-up on the unresolved `x=12` south candidate disproved it:
  - Fresh `probe_edge_verify:12,19,DOWN,5` blocked `5/5` into `(12,20)` with `classification=confirmed_blocked`.
  - Do **not** promote `(12,20)`; leave it closed and treat the earlier crawl export as a false positive.
- Cleanup after reload validation:
  - no new code changes were needed beyond the already-patched stop fix and earlier passthrough promotions
  - restore hero to safe `Rimuldar (0x0B)` baseline before the next crawl

### RIMULDAR CRAWLER FOLLOW-UP AND STOP SAFETY - 2026-05-21
- Live continuation test from `Rimuldar (0x0B) (24,7)` did **not** extend the hidden strip westward. Instead, the bounded crawl exported one directional candidate:
  - `["24,6"] = {south = true}`
- Direct verifier disproved that candidate immediately:
  - `probe_edge_verify:24,7,UP,5` moved into `(24,6)` `5/5` with `classification=confirmed_passable`, no drift, no timeout, and no map change.
  - Treat `["24,6"] = {south = true}` as a crawler false positive, not map data.
- North-edge regression retest from `Rimuldar (0x0B) (13,20)` still behaved correctly at the unstable frontier:
  - `(13,1)` again logged `MAP_CRAWL_UNSTABLE_CANDIDATE` and backtracked instead of wandering sideways.
  - The same run continued down the adjacent `x=12` strip and exported four new passthrough candidates:
    - `["12,15"] = true`
    - `["12,16"] = true`
    - `["12,18"] = true`
    - `["12,20"] = true`
- Direct verifier follow-up:
  - `probe_edge_verify:12,14,DOWN,5` confirmed `(12,15)` passable `5/5`
  - `probe_edge_verify:12,17,UP,5` confirmed `(12,16)` passable `5/5`
  - `probe_edge_verify:12,17,DOWN,5` confirmed `(12,18)` passable `5/5`
  - `probe_edge_verify:12,19,DOWN,5` for `(12,20)` came back mixed: `moved=4 blocked=1`
- Permanent patch:
  - Added `(12,15)`, `(12,16)`, and `(12,18)` to `MAP_PASSTHROUGH_CELLS[0x0B]` in `map_reader.lua`
  - Left `(12,20)` review-only because the verifier was mixed
- Stop-safety harness result:
  - `stop_map_crawl` during an in-flight backtrack at `(22,1)->DOWN` reported `manual_stop`, but the hero later settled at `(22,2)`.
  - Root cause: `map_crawler.stop()` finished immediately after canceling `auto_step`, so the crawler stopped tracking before a committed tile could settle.
  - Fix: `map_crawler.lua` now defers `manual_stop` cleanup when `auto_step` reports `movement_started=true`, waits up to a short settle window for the player to land or remain still, then restores parked NPCs and finishes the run.
  - Added `auto_step.get_active_step_state()` plus a focused crawler regression test covering the deferred-stop path.
- Focused static validation passed after the patch:
  - `test_map_crawler.lua`: 20 tests passed
  - `test_map_reader.lua`: 33 tests passed
  - `git diff --check`: clean
- Cleanup after the live pass:
  - restored normal play state with `unfreeze_npcs`
  - teleported hero back to `Rimuldar (0x0B) (29,14)`
  - confirmed both door slots `(21,21)` and `(22,23)` stayed open

### RIMULDAR X=24 FRONTIER ADVANCE - 2026-05-21
- The latest user-run bounded crawl started from `Rimuldar (0x0B) (25,3)` after reload and exported three new passthrough candidates:
  - `["24,2"] = true`
  - `["24,3"] = true`
  - `["24,4"] = true`
- The crawl evidence was strong enough to promote directly without a separate verifier loop:
  - `(25,2)->LEFT` moved into `(24,2)`, then `(24,1)->DOWN` and `(24,3)->UP` both returned into `(24,2)`.
  - `(24,2)->DOWN` moved into `(24,3)`, and `(24,3)->UP` returned into `(24,2)`.
  - `(24,3)->DOWN` moved into `(24,4)`, `(24,4)->UP` returned into `(24,3)`, and `(24,4)->DOWN` kept moving onward into normal floor at `(24,5)`.
  - The same crawl then continued through existing hidden-strip bridge `(24,6)` and onward into `(24,7)`, which confirms these new cells are part of the same live route rather than isolated noise.
- Important non-promotion from the same pass:
  - `(26,3)->DOWN` into `(26,4)` stayed `class=modeled_blocked`, so `(26,4)` remains a normal wall, not a passthrough candidate.
- Permanent patch:
  - Added `(24,2)`, `(24,3)`, and `(24,4)` to `MAP_PASSTHROUGH_CELLS[0x0B]` in `map_reader.lua`
  - Added matching assertions and snapshot checks to `test_map_reader.lua`

### RIMULDAR X=25/X=26 FRONTIER ADVANCE - 2026-05-21
- The latest user-run bounded crawl started from `Rimuldar (0x0B) (27,3)` after reload and exported four new passthrough candidates:
  - `["26,2"] = true`
  - `["26,3"] = true`
  - `["25,3"] = true`
  - `["25,2"] = true`
- The same crawl also showed `MAP_CRAWL_EDGE ... from=(26,3) dir=down dest=(26,4) class=modeled_blocked blocked_attempts=1`, so `(26,4)` remains a normal modeled wall, not a passthrough target.
- Direct confirmation:
  - `probe_edge_verify:LEFT,5` from `(27,2)` -> `(26,2)` moved `5/5` with `classification=confirmed_passable`, no drift, timeout, or map change.
  - Five forced raw `probe_edge:DOWN` checks from `(26,2)` all moved into `(26,3)`.
  - Five forced raw `probe_edge:LEFT` checks from `(26,3)` all moved into `(25,3)`.
  - Five forced raw `probe_edge:UP` checks from `(25,3)` all moved into `(25,2)`.
- Permanent patch:
  - Added `(26,2)`, `(26,3)`, `(25,3)`, and `(25,2)` to `MAP_PASSTHROUGH_CELLS[0x0B]` in `map_reader.lua`
  - Added matching assertions to `test_map_reader.lua`
- Focused static validation passed:
  - `test_map_reader.lua`: 33 tests passed
  - `git diff --check`: clean
- Cleanup after the pass:
  - restored normal state with `unfreeze_npcs`
  - teleported hero back to `(29,14)`
  - confirmed both Rimuldar door slots `(21,21)` and `(22,23)` stayed open

### RIMULDAR X=27 FRONTIER ADVANCE - 2026-05-21
- After reloading the newly promoted `(28,7)` passthrough, the next bounded crawler test started from `Rimuldar (0x0B) (28,7)`:
  - `reset_map_crawl`
  - `freeze_npcs teleport_to:28,7 report_position`
  - `crawl_map_frontier:attempts=1,max_edges=12`
  - `report_map_crawl export_map_crawl_candidates`
- Result:
  - `MAP_CRAWL_FINISH run=1 map=0x0B completed=false reason=max_edges edges=15 passthrough_candidates=2 directional_candidates=0 stationary_npc_cells=0 transitions=2`
  - Exported candidates: `["27,2"] = true`, `["27,3"] = true`
- Direct confirmation:
  - `probe_edge_verify:LEFT,5` from `(28,2)` -> `(27,2)` moved `5/5` with `classification=confirmed_passable`, no drift, timeout, or map change.
  - Repeated verifier still could not normalize origin `(27,2)` because it was not yet modeled live, so `(27,3)` was checked with forced raw probes instead:
    - five separate cycles of `freeze_npcs teleport_to:27,2,force report_position` plus `probe_edge:DOWN`
    - every attempt logged `EDGE_PROBE_RESULT ... status=moved final=(27,3) ... reason=position_changed`
- Permanent patch:
  - Added `(27,2)` and `(27,3)` to `MAP_PASSTHROUGH_CELLS[0x0B]` in `map_reader.lua`
  - Added matching assertions to `test_map_reader.lua`
- Focused static validation passed:
  - `test_map_reader.lua`: 33 tests passed
  - `git diff --check`: clean
- Cleanup after the pass:
  - restored normal state with `unfreeze_npcs`
  - teleported hero back to `(29,14)`
  - confirmed both Rimuldar door slots `(21,21)` and `(22,23)` stayed open

### RIMULDAR UPPER-STRIP FOLLOW-UP AFTER `(28,2)` RELOAD - 2026-05-21
- After the user reloaded FCEUX Lua with `(28,2)` live, a repeat forced-start crawl from `(29,9)` on Rimuldar `(0x0B)` no longer exported any new review candidates:
  - `MAP_CRAWL_FINISH run=1 map=0x0B completed=false reason=max_edges edges=14 passthrough_candidates=0 directional_candidates=0 stationary_npc_cells=0 transitions=1`
  - `report_map_crawl export_map_crawl_candidates` returned `no_review_candidates=true`.
- Interpretation: this was the expected “frontier absorbed” result. The earlier `(28,2)` candidate is now modeled correctly enough that the same upper-strip crawl no longer rediscovers it.

### RIMULDAR X=28 FRONTIER ADVANCE - 2026-05-21
- Next bounded crawler test started from live passthrough `(28,2)` on Rimuldar `(0x0B)`:
  - `reset_map_crawl`
  - `freeze_npcs teleport_to:28,2 report_position`
  - `crawl_map_frontier:attempts=1,max_edges=12`
  - `report_map_crawl export_map_crawl_candidates`
- Result:
  - `MAP_CRAWL_FINISH run=2 map=0x0B completed=false reason=max_edges edges=18 passthrough_candidates=4 directional_candidates=0 stationary_npc_cells=0 transitions=1`
  - Exported candidates: `["28,3"] = true`, `["28,4"] = true`, `["28,6"] = true`, `["28,7"] = true`
- Clean direct verifier follow-up:
  - `probe_edge_verify:DOWN,5` from `(28,2)` -> `(28,3)` moved `5/5`, `classification=confirmed_passable`
  - `probe_edge_verify:UP,5` from `(28,5)` -> `(28,4)` moved `5/5`, `classification=confirmed_passable`
  - `probe_edge_verify:DOWN,5` from `(28,5)` -> `(28,6)` moved `5/5`, `classification=confirmed_passable`
- Remaining holdout:
  - Initial forced `probe_edge_verify:DOWN,5` from `(28,6)` failed as `classification=inconclusive_control reason=teleport_failed:not walkable`
  - After reloading the newly promoted `(28,6)` passthrough, the same verifier completed cleanly:
    - `EDGE_VERIFY_RESULT map=0x0B from=(28,6) dir=down dest=(28,7) attempts=5 moved=5 blocked=0 timed_out=0 refused=0 drifted=0 map_changed=0 interrupted=0 classification=confirmed_passable`
  - `(28,7)` is now promoted too.
- Permanent patch:
  - Added `(28,3)`, `(28,4)`, `(28,6)`, and `(28,7)` to `MAP_PASSTHROUGH_CELLS[0x0B]` in `map_reader.lua`
  - Added matching assertions to `test_map_reader.lua`
- Focused static validation passed:
  - `test_map_reader.lua`: 33 tests passed
  - `git diff --check`: clean
- Cleanup after the pass:
  - restored normal state with `unfreeze_npcs`
  - teleported hero back to `(29,14)`
  - confirmed both Rimuldar door slots `(21,21)` and `(22,23)` stayed open

### RIMULDAR UPPER X=29 STRIP CRAWLER FOLLOW-UP - 2026-05-21
- Goal: resume the next crawler test from above the earlier `(29,10)` choke so the north-edge behavior could be observed without the lower-strip contamination.
- Baseline before test: `POSITION map=0x0B(Rimuldar) x=29 y=14`, both doors still open, `RUNTIME_BLOCKS map=0x0B none`.
- `teleport_to:29,9` was refused because `(29,9)` is still modeled non-walkable (`tile=0x00`), so the focused test used `teleport_to:29,9,force`.
- Bounded crawler result from forced start `(29,9)`:
  - `MAP_CRAWL_FINISH run=1 map=0x0B completed=false reason=max_edges edges=14 passthrough_candidates=1 directional_candidates=0 stationary_npc_cells=0 transitions=1`
  - The `transitions=1` count is expected here because `boundary_frontier` shares the transitions bucket; there was no world-map change.
  - Boundary behavior stayed correct: `(29,1)->UP dest=(29,0)` logged `class=boundary_frontier note=destination_boundary`, and the crawl backtracked to `(29,2)` instead of leaving town.
  - New review-only export from this pass: `MAP_CRAWL_EXPORT_PASSTHROUGH map=0x0B line='["28,2"] = true,'`
- Direct verifier follow-up:
  - `probe_edge_verify:29,2,LEFT,5` moved into `(28,2)` `5/5` with `classification=confirmed_passable`, no drift, no timeout, no map change, and no runtime block injection.
  - The crawl itself had already shown onward route evidence by moving `(28,2)->UP` into `(28,1)`.
- Permanent patch:
  - Added `(28,2)` to `MAP_PASSTHROUGH_CELLS[0x0B]` in `map_reader.lua`.
  - Added `(28,2)` to the northeast false-wall strip assertion list in `test_map_reader.lua`.
- Focused static validation passed:
  - `test_map_reader.lua`: 33 tests passed.
  - `git diff --check`: clean.
- Cleanup after the test: restored normal state with `unfreeze_npcs`, teleported back to `(29,14)`, and confirmed both door slots `(21,21)` and `(22,23)` were still open.

### RIMULDAR EXIT-SEAM CLASSIFIER FOLLOW-UP - 2026-05-21
- Direct live verifier recheck on the restored two-door state confirmed `(29,13)->LEFT` into `(28,13)` is a real one-way seam, not a noisy candidate:
  - `probe_edge_verify:29,13,LEFT,5` blocked `5/5` with `classification=confirmed_blocked`.
  - Reverse `probe_edge_verify:28,13,RIGHT,5` stepped onto `(29,13)` and immediately map-changed to `0x01`, so treat `(29,13)` as the live exit tile rather than a symmetric blocker.
- Permanent map patch: `map_reader.lua` now models `["28,13"] = {south = true, east = true}` and `test_map_reader.lua` pins the new `east` approach block.
- Root cause of the duplicate crawler export: `map_crawler.classify_blocked()` was only checking whether the destination tile was generally walkable. It did not suppress probes whose specific blocked approach was already present in `map_reader.get_directional_blocks(map_id)`.
- Permanent crawler patch: `map_crawler.lua` now classifies an already-modeled approach as `modeled_blocked note=approach_already_modeled` instead of re-exporting it as a fresh `directional_block_candidate`.
- Static validation on Windows LuaJIT passed after the fix:
  - `test_map_crawler.lua`: 19 tests passed, including new `already_modeled_directional_block_is_not_reexported`.
  - `test_map_reader.lua`: 33 tests passed.
  - `git diff --check`: clean.
- Live state after the user's latest restore/probe: `POSITION map=0x0B(Rimuldar) x=29 y=16`, `DOOR_STATE` still shows both open door slots `(21,21)` and `(22,23)`.
- Remaining live step: FCEUX must reload Lua before rerunning the bounded Rimuldar crawl, otherwise the active script will still use the old crawler classifier.

### RIMULDAR 29,14 BOUNDED RERUN AFTER RELOAD - 2026-05-21
- After manual FCEUX Lua reload, live baseline was clean: `POSITION map=0x0B(Rimuldar) x=29 y=16`, both doors still open, and `RUNTIME_BLOCKS map=0x0B none`.
- Rerun command sequence:
  - `reset_map_crawl`
  - `freeze_npcs teleport_to:29,14 report_position`
  - `crawl_map_frontier:attempts=1,max_edges=12`
  - `report_map_crawl export_map_crawl_candidates`
- Result: the rerun finished cleanly with `MAP_CRAWL_FINISH run=1 map=0x0B completed=false reason=max_edges edges=12 passthrough_candidates=4 directional_candidates=0 stationary_npc_cells=0 transitions=0`.
- Most important regression check: the old export `["28,13"] = {east = true}` did **not** reappear. `directional_candidates=0` confirms the running crawler respected the new already-modeled-approach suppression.
- New review-only exports from this run were passthrough candidates on the same north-side strip:
  - `["29,9"] = true`
  - `["29,10"] = true`
  - `["29,11"] = true`
  - `["29,12"] = true`
- Interpretation: this was a successful live proof for the classifier fix. The next useful investigation is no longer the `(28,13).east` seam; it is whether the remaining north-strip cells `(29,9)` through `(29,12)` should join the earlier `MAP_PASSTHROUGH_CELLS[0x0B]` entries on that same column.
- Cleanup after rerun: restored normal play state with `unfreeze_npcs`, teleported hero back to safe `(29,14)`, and rechecked that both doors were still open.

### RIMULDAR 29,14 BOUNDED CRAWLER RETEST - 2026-05-21
- Test command: `reset_map_crawl freeze_npcs teleport_to:29,14 report_position`, then `crawl_map_frontier:attempts=1,max_edges=12`, followed by `report_map_crawl` and `export_map_crawl_candidates`.
- Result: the crawl stayed stable and restored parked NPCs, but it did **not** reproduce the old north-edge boundary case because a stationary NPC blocked the vertical strip at `(29,10)`. The run stopped at `max_edges` with `MAP_CRAWL_FINISH ... reason=max_edges edges=17 passthrough_candidates=0 directional_candidates=1 stationary_npc_cells=1 transitions=2`.
- Safety/behavior checks that passed:
  - no map transition or movement drift occurred;
  - `boundary_frontier` still prevented probing past the east boundary at `(30,11)` / `(30,12)`;
  - unstable boundary-origin cells `(29,11)` and `(29,12)` backtracked instead of probing sideways;
  - `MAP_CRAWL_NPC_PARK_RESTORE ... restored=true restored_slots=5 reason=max_edges`.
- New review candidate from this run: `MAP_CRAWL_EXPORT_DIRECTIONAL map=0x0B line='["28,13"] = {east = true},'`, coming from `(29,13)->LEFT` blocking once while the model thought `(28,13)` was open.
- Follow-up interpretation: this was a useful stability test, but not a clean north-edge regression test. For the actual north-edge case, start above the `(29,10)` stationary NPC (for example the earlier proven `(29,9)` strip) or use a nearby column with a clear route to `y=1`.

### CRAWLER SHAKEDOWN - 2026-05-21
- First live `crawl_map_frontier:attempts=2,max_edges=40` started at Rimuldar `(29,13)`, not the safer `(29,14)` suggested in chat. It parked 10 mobile NPC slots.
- The crawler walked north on x=29 through cells `(29,12)` down to `(29,0)`, then probed `(29,0)->UP` toward out-of-bounds `(29,-1)`. That triggered `EVENT: map change -> 0x01 (World Map)` and landed at world `(102,72)`.
- Bug 1: `tick()` saw the map change before the `route_step_completed` callback classified the active edge, so the report finished with `transitions=0` instead of recording the edge as a transition candidate.
- Bug 2: boundary/engine-boundary destinations were treated like ordinary false-wall candidates, so the crawler could walk onto/probe the north boundary and physically leave town.
- Patch applied: `map_crawler` now preflight-skips out-of-bounds and `engine_boundary` destinations as `boundary_frontier`, records active-edge `transition_candidate` when `tick()` sees a map change first, and bare `report_map_crawl` uses the latest crawl map after a transition instead of defaulting to the current world map.
- Validation after patch: `luac -p map_crawler.lua main.lua test_map_crawler.lua`, `lua test_map_crawler.lua` (13 tests), `lua test_map_reader.lua` (33), `lua test_map_survey.lua` (45), `lua test_debug_tools.lua` (5), and `git diff --check` passed; only the known `dw_access.ini` CRLF warning appeared.
- Live state check after the user's manual re-entry: `report_position` returned `map=0x0B(Rimuldar) x=29 y=9`. Patched Lua still needs FCEUX script reload before another live crawler run.

### CRAWLER SHAKEDOWN 2 - 2026-05-21
- The next live `crawl_map_frontier:attempts=2,max_edges=40` started at Rimuldar `(29,13)` after the user reloaded Lua.
- Boundary preflight worked: the crawler logged `(29,1)->UP dest=(29,0)` as `boundary_frontier` instead of walking the player out of town.
- Bug 3: the preflight boundary record had `run=0 map=0x00` because skipped edges were recorded before inheriting the active crawl run/map IDs.
- Bug 4: after probing a known neighbor, the `return_to_frontier` completion was handled like a normal discovery. That scheduled the reverse return again, producing a live ping-pong between `(29,1)` and `(29,2)` and growing the report to 324 edges before manual stop.
- Live stop: `stop_map_crawl` restored parked NPCs (`restored_slots=2`) and finished with `reason=manual_stop`.
- Patch applied: preflight records now fall back to the active crawler run/map, and completed `return_to_frontier` moves return immediately like backtracks.
- Patched Lua needs FCEUX script reload before another live crawler run.

### POST-STOP TOWN EXIT - 2026-05-21
- The later town exit was not logged as a crawler probe. After the stopped crawl left the hero near the north edge, FCEUX logged an external bridge/manual-tap `Up` from `(29,1)` to `(29,0)`, followed by `EVENT: map change -> 0x01 (World Map)`.
- The user manually returned to Rimuldar; live `report_position` confirmed `map=0x0B(Rimuldar) x=29 y=14`.
- `report_map_crawl` still showed the old contaminated 324-edge report, so `reset_map_crawl` was queued and confirmed with `MAP_CRAWL_RESET map=0x0B`.
- FCEUX input recovery logged `INPUT_STATUS tag=fceux_recovery keys=- joy1=- left_alt=false`, but a later held/stale `Up` moved the hero from `(29,14)` to `(29,13)`. Avoid live crawler movement until input is quiet and the patched Lua is reloaded.
- Patch applied: crawler manual stop, low-HP abort, and script-error abort now call `auto_step.cancel_active_step(true, true)` to force-release injected auto-step input.

### LIVE PATCHED CRAWLER TEST - 2026-05-21
- After user-confirmed script reload/menu clear, live baseline was Rimuldar `(29,9)` with only the known `LeftAlt` latch and no joypad direction. `reset_map_crawl` confirmed.
- Test command: `crawl_map_frontier:attempts=1,max_edges=12`.
- Result: finished cleanly with `MAP_CRAWL_FINISH run=1 map=0x0B completed=false reason=max_edges edges=13 passthrough_candidates=5 directional_candidates=0 stationary_npc_cells=0 transitions=2`.
- Boundary behavior verified live: `(29,1)->UP dest=(29,0)` and `(28,1)->UP dest=(28,0)` logged as `boundary_frontier` with active `run=1 map=0x0B`; no world-map transition occurred.
- Return behavior verified live: after probing `(29,1)->DOWN` into known `(29,2)`, exactly one `return_to_frontier` moved back to `(29,1)`, then the crawler continued with `(29,1)->LEFT` instead of ping-ponging.
- NPC parking restored at finish: `MAP_CRAWL_NPC_PARK_RESTORE ... restored=true restored_slots=2 reason=max_edges`.
- Review-only export from this small run produced passthrough candidates `29,2`, `29,3`, `29,4`, `29,6`, and `29,7`; treat them as candidates for review, not permanent map edits.
- After the crawl left the hero near the north edge at `(28,1)`, Codex teleported back to safer `(29,14)` and confirmed `POSITION: map=0x0B(Rimuldar) x=29 y=14`.

### CRAWLER SHAKEDOWN 3 - 2026-05-21
- Test command: from Rimuldar `(13,20)`, `crawl_map_frontier:attempts=2,max_edges=60`.
- Result: stopped manually after a live movement-drift bug. The crawler walked north through the south-side connector to `(13,1)`, preflight-skipped `(13,1)->UP dest=(13,0)` as `boundary_frontier`, then probed `(13,1)->DOWN dest=(13,2)`.
- Bug: auto_step reported `dir=down from=(13,1)` but completed at `(13,0)`, while the crawler accepted the edge as if it had landed at `(13,2)`. It then tried a `return_to_frontier` from `(13,2)` while the live hero was actually at `(13,0)`.
- Safety response: `stop_map_crawl` restored 4 parked NPC slots, and Codex moved the hero back to `(29,14)`.
- Patch applied: crawler now records `movement_drift` and aborts if a completed step lands anywhere other than the expected destination, and records `position_drift`/aborts before injecting an edge if the live position does not match the edge origin. These drift records are diagnostic only and do not export map candidates.

### X=29 CRAWLER CANDIDATE FOLLOW-UP - 2026-05-21
- The lack of blocker sounds is consistent with the crawler output: these were `false_wall_candidate` records, meaning movement succeeded into cells the current model marks non-walkable. They are not blocker candidates.
- Direct verifier results:
  - `(29,8)->UP` into `(29,7)`: moved 5/5, `classification=confirmed_passable`.
  - `(29,5)->DOWN` into `(29,6)`: moved 5/5, `classification=confirmed_passable`.
  - `(29,5)->UP` into `(29,4)`: moved 5/5, `classification=confirmed_passable`.
  - `(29,1)->DOWN` into `(29,2)`: moved 5/5, `classification=confirmed_passable`.
- Chained hidden-origin follow-up:
  - Explicit `probe_edge_verify:29,7,UP,5` was inconclusive because relocation to `(29,7)` is refused while the model still marks it non-walkable.
  - Force-origin raw probe from `(29,2)->DOWN` moved into `(29,3)`.
  - Force-origin raw probe from `(29,4)->UP` moved into `(29,3)`.
- Current interpretation: `29,2`, `29,4`, `29,6`, and `29,7` are clean passthrough candidates; `29,3` is very likely part of the same vertical hidden strip but needs a post-model-update verifier if promoted.
- Hero restored to safer Rimuldar entrance-side tile `(29,14)` after testing.
- Permanent patch: added `MAP_PASSTHROUGH_CELLS[0x0B]` entries for `29,2`, `29,3`, `29,4`, `29,6`, and `29,7`, plus `test_map_reader.lua` assertions. `29,3` is documented as the chained force-origin raw-probe cell; optional follow-up after reload is `probe_edge_verify:29,2,DOWN,5` or `probe_edge_verify:29,4,UP,5`.
- Post-patch reload follow-up: after the user manually reloaded FCEUX Lua, `probe_edge_verify:29,2,DOWN,5` and `probe_edge_verify:29,4,UP,5` both moved into `(29,3)` 5/5 with no refused attempts, drift, map change, timeout, or interruption. `29,3` is now cleanly confirmed passable from both sides. Hero restored to `(29,14)`.

### CRAWLER SHAKEDOWN 3 - 2026-05-21
- After script reload, bounded crawl from `(13,20)` with `crawl_map_frontier:attempts=2,max_edges=60` parked 1 mobile NPC and walked the west-side vertical strip north. It stopped safely on the old edge case: `(13,1)->DOWN` intended `(13,2)` but landed at `(13,0)`, now classified as `movement_drift`; parked NPCs were restored.
- Initial export listed passthrough candidates `(13,1)`, `(13,2)`, and `(13,4)`. Direct verifier follow-up promoted only the clean cells:
  - `probe_edge_verify:13,5,UP,5` moved into `(13,4)` 5/5 with no drift/map change/refusal.
  - `probe_edge_verify:13,3,UP,5` moved into `(13,2)` 5/5 with no drift/map change/refusal.
  - `probe_edge_verify:13,2,UP,5` was inconclusive because the verifier reset refused origin `(13,2)` before the passthrough patch was loaded.
- Force-origin raw probes from `(13,2)->UP` moved into `(13,1)` 3/3, but the hero later settled at `(13,0)` before a reverse probe could start. Treat `(13,1)` as an unstable north-edge frontier, not a normal passthrough candidate, until a post-patch verifier or dedicated exit model can classify it.
- Permanent patch: added `MAP_PASSTHROUGH_CELLS[0x0B]` entries for `(13,2)` and `(13,4)` only, plus `test_map_reader.lua` assertions. Also tightened `map_crawler.lua` so a false-wall candidate is removed from export if that same cell later acts as the origin of a boundary, transition, position-drift, or movement-drift edge.
- Post-reload live retest from `(13,20)` confirmed `(13,4)` and `(13,2)` now classify as `open_floor` / `model_reason=passthrough`, and `(13,1)` logs `MAP_CRAWL_UNSTABLE_CANDIDATE` instead of exporting. New issue found: because `(13,1)->DOWN` now returns cleanly to `(13,2)`, the old runtime kept exploring sideways from unstable `(13,1)` and exported `(12,2)` after crawling through `(12,1)`. Treat that `(12,2)` export as frontier-contaminated evidence, not a map patch.
- Follow-up patch: unstable cells are now backtrack-only during the same crawl. Once a cell becomes a boundary/transition/drift origin, the crawler will backtrack instead of probing its remaining directions. This should suppress the `(13,1)->(12,1)->(12,2)` artifact after the next script reload.
- Post-backtrack-only reload: bounded crawl from `(13,20)` proved the fix live. `(13,1)` logged `MAP_CRAWL_UNSTABLE_CANDIDATE`, immediately backtracked down to `(13,2)`, and did not probe `(13,1)->LEFT` / `(12,1)`. The crawl then legitimately entered x=12 from stable origins and exported `(12,2)`, `(12,8)`, `(12,9)`, and `(12,11)`.
- Direct verifier follow-up confirmed all four 5/5 passable with no drift/map change/refusal/timeout:
  - `probe_edge_verify:13,2,LEFT,5` -> `(12,2)` moved 5/5.
  - `probe_edge_verify:12,7,DOWN,5` -> `(12,8)` moved 5/5.
  - `probe_edge_verify:12,10,UP,5` -> `(12,9)` moved 5/5.
  - `probe_edge_verify:12,10,DOWN,5` -> `(12,11)` moved 5/5.
- Permanent patch: added `MAP_PASSTHROUGH_CELLS[0x0B]` entries for `(12,2)`, `(12,8)`, `(12,9)`, and `(12,11)`, plus test assertions.

### CLEAN / PROMOTED
- Map 0x0B `(23,20)->LEFT`: after reload/menu-clear, return autowalk looped on this shelf entry; direct `probe_edge_verify:23,20,LEFT,5` blocked 5/5 with no drift/map change. Promoted `(22,20).east`.
- Map 0x0B `(20,20)->DOWN`: return reroute repeatedly tried row-20 south exit; direct `probe_edge_verify:20,20,DOWN,5` blocked 5/5. Promoted `(20,21).north`.
- Map 0x0B `(19,20)->DOWN`: next row-20 fallback; direct `probe_edge_verify:19,20,DOWN,5` blocked 5/5. Promoted `(19,21).north`.
- Map 0x0B `(18,20)->DOWN`: next row-20 fallback; direct `probe_edge_verify:18,20,DOWN,5` blocked 5/5. Promoted `(18,21).north`.
- Map 0x0B `(17,21)->RIGHT`: after the row-20 south exits were runtime-injected, return route tried entering `(18,21)` from the west; direct `probe_edge_verify:17,21,RIGHT,5` blocked 5/5. Promoted `(18,21).west`.
- Map 0x0B `(14,19)->RIGHT`: after closing the command menu, `probe_edge_verify:RIGHT,3` blocked 3/3 while `(15,19)->LEFT` moved 3/3. Promoted `(15,19).west`.
- Map 0x0B `(13,20)`: `probe_edge_verify:13,21,UP,5` moved 5/5 into `(13,20)`, and a force-origin raw `probe_edge:UP` from `(13,20)` moved into `(13,19)`. Promoted `(13,20)` as a passthrough cell.
- Map 0x0B `(14,23)->RIGHT`: return-route planner tried entering `(15,23)` from the west; direct verifier blocked 5/5. Promoted `(15,23).west`.
- Map 0x0B `(14,24)->RIGHT`: likely fallback after `(15,23).west`; direct verifier blocked 5/5. Promoted `(15,24).west`.
- Map 0x0B `(21,25)->UP`: autowalk looped on the row-25 fallback; direct `probe_edge_verify:21,25,UP,5` blocked 5/5 with no drift/map change. Promoted `(21,24).south`.
- Map 0x0B `(15,25)->UP`: same lower-row fallback loop; direct `probe_edge_verify:15,25,UP,5` blocked 5/5 with no drift/map change. Promoted `(15,24).south`.
- Map 0x0B `(16,27)->RIGHT`: next entrance-to-chest autowalk reroute reached `(16,27)`; direct `probe_edge_verify:16,27,RIGHT,5` blocked 5/5 with no drift/map change. Promoted `(17,27).west`.
- Map 0x0B `(16,27)->DOWN`: same reroute; direct `probe_edge_verify:16,27,DOWN,5` blocked 5/5 with no drift/map change. Promoted `(16,28).north`.
- Map 0x0B `(15,27)->DOWN`: coordinate autowalk reroute reached `(15,27)`; direct `probe_edge_verify:15,27,DOWN,5` blocked 5/5 with no drift/map change. Promoted `(15,28).north`.
- Map 0x0B `(13,26)->LEFT`: parked-NPC entrance-to-chest route tried the lower west branch; direct `probe_edge_verify:13,26,LEFT,5` blocked 5/5. Promoted `(12,26).east`.
- Map 0x0B `(13,25)->LEFT`: fallback from the same branch; direct `probe_edge_verify:13,25,LEFT,5` blocked 5/5. Promoted `(12,25).east`.
- Map 0x0B `(13,23)->LEFT`: next west-branch reroute; direct `probe_edge_verify:13,23,LEFT,5` blocked 5/5. Promoted `(12,23).east`.
- Map 0x0B `(13,24)->LEFT`: paired west-branch reroute; direct `probe_edge_verify:13,24,LEFT,5` blocked 5/5. Promoted `(12,24).east`.
- Map 0x0B `(13,22)->LEFT`: west-branch entry shifted upward again; direct `probe_edge_verify:13,22,LEFT,5` blocked 5/5. Promoted `(12,22).east`.
- Map 0x0B `(13,21)->LEFT`: final upper west-branch entry; direct `probe_edge_verify:13,21,LEFT,5` blocked 5/5. Promoted `(12,21).east`.
- Map 0x0B `(23,20)->DOWN`: chest-return planner looped on the upper shelf; direct `probe_edge_verify:23,20,DOWN,5` blocked 5/5. Promoted `(23,21).north`.
- Map 0x0B `(23,22)->UP`: return autowalk from the chest-side stand repeatedly failed into `(23,21)`; direct verifier blocked 5/5. Promoted `(23,21).south`.
- Map 0x0B `(23,22)->LEFT`: paired row-22 shelf fallback; direct verifier blocked 5/5. Promoted `(22,22).east`.
- Map 0x0B `(24,22)->UP`: next return fallback tried `(24,21)`; direct verifier blocked 5/5. Promoted `(24,21).south`.
- Map 0x0B `(17,21)->LEFT`: return route reached `(17,21)` and failed into `(16,21)`; direct verifier blocked 5/5. Promoted `(16,21).east`.
- Map 0x0B `(16,22)->UP`: lower return fallback failed into `(16,21)`; direct verifier blocked 5/5. Promoted `(16,21).south`.
- Map 0x0B `(16,22)->LEFT`: paired fallback from `(16,22)` into `(15,22)`; direct verifier blocked 5/5. Promoted `(15,22).east`.
- Map 0x0B `(16,23)->DOWN`: next lower fallback failed into `(16,24)`; direct verifier blocked 5/5. Promoted `(16,24).north`.
- Map 0x0B `(16,23)->LEFT`: paired fallback from `(16,23)` into `(15,23)`; direct verifier blocked 5/5. Promoted `(15,23).east`.

### VERIFIED STILL CLOSED
- `(17,19)->LEFT` into `(16,19)` had one mixed 3-attempt run, then a clean 10/10 blocked verifier. Keep `(16,19).east`.
- `(16,20)->UP` into `(16,19)` blocked 5/5. Keep `(16,19).south`.

### DO NOT PROMOTE
- `(23,21)->LEFT` into `(22,21)` is mixed, 2 moved / 3 blocked, despite blocked-only autowalk evidence. Leave open for now.
- `(15,16)->DOWN` into `(15,17)` is mixed, 2 moved / 3 blocked. Leave open.
- `(23,20)->LEFT` into `(22,20)` directly moved 5/5; the autowalk blocked-only evidence was false/timing-contaminated.
- `(23,20)->DOWN` into `(23,21)` was later rechecked cleanly and promoted; older mixed note is superseded.
- `validate_path` from entrance to chest aborted early on row 14 due overshoot after retries, not a map blocker.
- `(14,21)->RIGHT` into `(15,21)` produced one mixed 1 moved / 4 blocked run, then a clean 15/15 blocked verifier. Keep `(15,21).west`.
- `(14,22)->RIGHT` into `(15,22)` rechecked as blocked 5/5. Keep `(15,22).west`.
- `(14,19)->RIGHT` into `(15,19)` rechecked as blocked 5/5. Keep `(15,19).west`.
- `(13,20)->RIGHT` into `(14,20)` moved 3/5 and `(14,21)->UP` moved 5/5, proving `(14,20)` is a hidden passable spur, but `(14,20)->RIGHT` stayed blocked by raw `probe_edge`. Do not add it as a route bridge yet.
- `(16,20)->DOWN` into `(16,21)` was mixed 1 moved / 4 blocked. Leave the north approach into `(16,21)` open.
- Reload follow-up rechecked `(16,20)->DOWN` with `probe_edge_verify:16,20,DOWN,5`; it moved 5/5. Even though autowalk still often times out here, keep `(16,21).north` open and treat this as route execution/timing noise unless future direct probes reverse it.
- 2026-05-21 narrow stop-test: the live autowalk target was `Exit to World Map`, not stairs, and it drove `(16,21).north` to `blocked=76 moved=0` before manual stop at `(16,20)`. Fresh frozen-NPC follow-up immediately downgraded that seam again: `inspect_move:16,20,DOWN` still reports `effective_passable=true`, `probe_edge_verify:16,20,DOWN,5` came back mixed `moved=3 blocked=2 reason=raw_hold_timeout`, and the seam log flipped from `blocked_only` back to `noisy`. The paired `(16,20)->RIGHT` seam also self-disproved again with `probe_edge_verify:16,20,RIGHT,5` moving 5/5. Do not promote either edge from this pass.
- `(22,25)->UP` into `(22,24)` is mixed and should not be promoted yet. The first verifier moved 5/5, but after input recovery/config reload and a fresh teleport, `probe_edge_verify:22,25,UP,3` blocked 3/3. A temporary `(22,24)` passthrough made the planner route through this throat, but live autowalk still failed there, so that passthrough was backed out.

### LOCAL ROUTE PROOF
- With patched files, the ROM-backed local BFS and opened doors `(21,21)` and `(22,23)` finds both:
- `23,23 -> 29,13`, length 36, via `(13,21)->(13,20)->(13,19)->(13,18)` then east to the entrance.
- `29,13 -> 23,23`, length 36, returning through `(13,20)` and the door-side/chest-side pocket.
- After adding runtime blockers for `(15,23).west` and `(15,24).west`, live FCEUX still finds:
- `29,13 -> 23,23`, length 40, routed through `(14,25)` and row 25.
- `23,23 -> 29,13`, length 36, routed through `(13,20)` and row 14/13.
- Row-25 fallback then looped on `(21,25)->UP` and `(15,25)->UP`; both are now confirmed/patched as south-approach blocks and need a fresh live planner/autowalk pass.
- Entrance-to-chest autowalk then looped from `(16,27)` into `(17,27)`/`(16,28)`; both are now confirmed/patched and need a fresh live planner/autowalk pass.
- The next reroute looped from `(15,27)` down into `(15,28)`; that north-approach block is now confirmed/patched and needs another planner/autowalk pass.
- Parked-NPC forward route later reached the lower west branch and looped on `(13,26)->LEFT` / `(13,25)->LEFT`; both are now confirmed/patched and need another skip-NPC planner/autowalk pass.
- The next lower west reroute looped on `(13,23)->LEFT` / `(13,24)->LEFT`; both are now confirmed/patched and need another skip-NPC planner/autowalk pass.
- The following skip-NPC route shifted to `(13,22)->LEFT`; this is now confirmed/patched and needs another planner pass.
- The route then shifted to `(13,21)->LEFT`; this is now confirmed/patched and needs another planner pass.
- With runtime blockers for `(23,21).north/south`, `(22,22).east`, `(24,21).south`, `(16,21).east/south`, `(15,22).east`, `(16,24).north`, and `(15,23).east`, live planner still finds a return route from the current lower fallback area to `(29,13)`, but the most recent autowalk had not yet reached the entrance before stopping.
- After injecting `(22,20).east`, `(20,21).north`, `(19,21).north`, `(18,21).north`, and `(18,21).west`, live `debug_pathfind_to:29,13` from `(17,21)` finds a 30-step return route through `(16,20)->(16,21)->(15,21)->(14,21)->(13,21)->(13,20)->...->(29,13)`.
- Live `debug_pathfind_to_skip_npcs:23,23` from the entrance `(29,13)` still reports no path with both doors open. The search reaches the west-side frontier `(13,20)->(13,21)->(14,21)` and rejects `(15,21)` as `blocked_directional`, so the missing entrance-to-chest bridge remains east of that west-side component.
- Temporary modeling of `(22,24)` as a passthrough made both `debug_pathfind_to_skip_npcs:23,23` and `debug_pathfind_adjacent_skip_npcs:24,23` plan through `(22,25)->(22,24)->(22,23)->(23,23)`, but the fresh direct verifier blocked that edge 3/3. Treat this as a disproved/mixed bridge until a clean normalized movement run proves otherwise.
- `auto_step_timeout` was raised from 45 to 60 because several passable-looking route steps were completing or failing just past the old threshold. This is an executor-tolerance change, not blocker evidence.

### NEXT CHECK
- Reload FCEUX Lua so the new `(13,20)` passthrough and `(15,19)/(15,23)/(15,24)` west closures are live.
- Reopen Rimuldar inn doors if the reload/map-state reset closed them.
- Run `teleport_to:23,23,force`, `report_door_state`, `debug_pathfind_to:29,13`, and `trace_path`.
- Then test reverse from entrance side with `teleport_to:29,13,force`, `debug_pathfind_to:23,23`, and `trace_path`.
