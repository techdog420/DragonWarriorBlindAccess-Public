# Session Handoff - Active Resume

Updated: 2026-05-24

This file is intentionally short. It is the current resume point, not the
historical evidence archive. The previous long handoff was preserved at
`handoff_archive/HANDOFF_2026-05-22_pre_cleanup_session_handoff_full.md`.

## Current Direction

- Player-facing gameplay is currently FCEUX-first.
- BizHawk remains the preferred automation/debug/reload-heavy runtime.
- Keep both emulator paths supported. Do not remove the FCEUX player-facing
  path or BizHawk automation affordances unless explicitly asked.
- Current branch focus: player-facing quality-of-life features before the next
  normal gameplay pass.
- Avoid broad new map-decoding passes unless gameplay exposes a blocker.
- Main route blocker for Tantegel Sun Shrine stairs is now confirmed solved in live
  gameplay: routes from both entrance and throne-room stair routes to `29,29` are
  viable and complete.
- Codex is the primary implementation/debugging agent. Claude is now mainly a
  limited-bandwidth second-eyes reviewer, so do not rely on Claude memory as an
  active project-state source.

## Latest Route Resolution

- As of the latest live verification, the missing bridge for the route to
  `0x04 (Tantegel Castle) -> (29,29)` has been resolved.
- `debug_pathfind_to`, `debug_pathfind_to_skip_npcs`, and `debug_pathfind_to_park_npcs`
  all produce valid routes from both the entrance side and throne-room stairs side
  when the model is freshly loaded and the stale-input state is handled.
- The route is now considered gameplay-complete for Sun Shrine stair access in both
  directions (with known hazard areas in the lower x=25/x=26 corridor remaining as
  an independent survivability/watchpoint, not a bridge blocker).

- Cleanup follow-up before floor closure:
  - Removed the stale `objects.lua` stairs artifact at `Tantegel` `(1,1)` and
    kept the Sun Shrine route stair as the live-only destination.
  - Removed the stale south-gate door artifact object at `(10,30)` from
    `EXTRA_DOORS`; entrance travel is modeled through the actual exit.
  - Added regression coverage in `test_objects.lua` and `test_map_reader.lua` to
    ensure the stale markers stay absent and `(25,16)/(25,17)` stay non-hazard.

## Runtime Baseline

- Normal launch: `./launch_dw.sh`
- Explicit FCEUX launch: `./launch_dw.sh --emulator fceux` or
  `./launch_fceux.sh`
- Explicit BizHawk launch: `./launch_dw.sh --emulator bizhawk` or
  `./launch_bizhawk.sh`
- Commands go through `./dw_commands.sh` from bash or `./dw_commands.ps1` from
  PowerShell/Codex.
- Use `--replace` for state-sensitive command batches and verify
  `dw_debug.log` between live steps.
- Use `--require-live SECONDS` when stale logs would mislead the result.
- Do not batch `teleport_to` with `probe_edge`, `survey_target`,
  `report_survey_start`, or path-debug follow-up commands when exact start
  state matters.

## Latest Accepted Work

### Tantegel Sun Shrine Forward Route Correction

Follow-up live FCEUX route testing on 2026-05-23 corrected the earlier
"horizontal row-9 bridge" interpretation and kept the forward route to
`(29,29)` under active investigation:
- User play proved the Sun Shrine stairs back to the entrance/throne-room side
  are clean, but the return direction from the throne side toward `(29,29)`
  failed at `(14,16)->RIGHT`.
- Direct verifier evidence confirmed the old row-16 forward route is invalid:
  `probe_edge_verify:14,16,RIGHT,5` blocked 5/5 with no drift, map change, or
  NPC contamination. `MAP_DIRECTIONAL_BLOCKS[0x04]["15,16"].west` is now
  modeled.
- User then found row-9 reversal behavior around `(12,9)` / `(13,9)`. Fresh
  reload plus hardened verifier split transient reversal from stable movement:
  after entering `(12,9)` from the east, a quick eastward reversal can return
  to `(13,9)`, but stable `probe_edge_verify:12,9,RIGHT,5` blocked 5/5 with
  `settle_frames=49`. `MAP_DIRECTIONAL_BLOCKS[0x04]["13,9"].west` is now
  modeled as blocked again.
- A fixed-verifier retest later showed `(14,8)->DOWN` was also stale latch
  evidence: it blocked 5/5 with `blocked_model_mismatch=5`, so
  `["14,9"].north` is closed. `["14,9"].south` remains blocked and
  `["14,9"].west` remains open.
- The apparent `(20,17)->RIGHT` bridge was a stale/contaminated verifier result.
  After a manual FCEUX Lua reload and live autowalk failure at the same edge,
  fresh hardened `probe_edge_verify:20,17,RIGHT,5` blocked 5/5 with
  `blocked_model_mismatch=5`. Reverse `probe_edge_verify:21,17,LEFT,5`
  still confirmed passable 6/6 with the delayed stability recheck, so this is
  modeled again as a one-way seam: `MAP_DIRECTIONAL_BLOCKS[0x04]["21,17"].west`.
- A temporary/open-model pass did expose three real southeast-pocket false exits,
  each confirmed 5/5 with no drift, map change, or interruption:
  `(27,21).west`, `(26,22).north`, and `(24,22).north`.
- Later pinball near the stairs superseded the earlier mixed
  `(25,22).north` result: quiet direct `probe_edge_verify:25,21,DOWN,5`
  blocked 5/5 with no drift, map change, or interruption, so
  `(25,22).north` is now modeled. Do not promote `(27,20).west`: quiet direct
  `probe_edge_verify:26,20,RIGHT,5` again confirmed passable 6/6 including
  the delayed stability recheck, despite noisy route-shaped blocked counts.
- Current live proof: the final southeast leg is usable once reached. From
  `(28,20)`, FCEUX `auto_walk:29,29` reached `(29,29)` cleanly and faced south,
  using `(28,20)->(28,21)->(28,22)->(28,23)->(29,23)->...->(29,29)`.
- Current interpretation: the shrine-to-throne/entrance direction remains
  clean. The throne/entrance-side forward route is not yet clean: with the
  fresh `(21,17).west` runtime block injected, live `debug_pathfind_to:29,29`
  and `debug_pathfind_to_skip_npcs:29,29` both report no path from the
  `(19,17)/(20,17)` side. Next work is to bracket the missing forward bridge
  without reopening `(20,17)->RIGHT`.
- 2026-05-23 follow-up on the southeast connector:
  `probe_edge` from forced `(28,10)` moved to `(28,11)` despite `MAP_BLOCKED_CELLS`
  reporting it as blocked (model-mismatch), and forced `(28,11)->UP` moved back.
  A clean `probe_edge:RIGHT` from forced `(28,11)` moved to `(29,11)` and then
  the engine transitioned to `map=0x01 (World Map)`, confirming the eastward
  seam at x=28 is a functional bridge rather than a hard block.
- 2026-05-23 follow-up from user play disproved the apparent `(14,7)->RIGHT`
  bridge as verifier-only contamination. Natural FCEUX autowalk attempts from
  `(14,7)` into `(15,7)` accumulated blocked-only evidence up to
  blocked `9` / moved `0`, so `MAP_DIRECTIONAL_BLOCKS[0x04]["15,7"].west`
  remains modeled.
- Route-shaped/current-position probes also kept these candidate bridges
  closed: `(14,8)->RIGHT`, `(14,8)->DOWN`, `(18,25)->RIGHT`,
  `(18,26)->RIGHT`, `(18,27)->RIGHT`, `(18,27)->DOWN`, `(17,27)->DOWN`,
  `(20,20)->RIGHT`, `(20,17)->RIGHT`, `(14,16)->RIGHT`, and northward entries
  from row 17 into row 16 at x=15,16,17,18,19,20.
- A capped review-only `crawl_map_frontier:attempts=3,max_edges=80` pass was
  manually stopped at 101 edges. It found passthrough candidates `(10,20)`,
  `(11,21)`, and `(13,13)`, but local ROM-backed route simulation showed those
  three do not connect the throne-side component to `(29,29)`. Keep them as
  review-only, not promoted route fixes.
- Follow-up after the user's `(14,7)` stall report confirmed the stall is real:
  `(14,7)->RIGHT` into `(15,7)` remains engine-blocked, and the earlier
  verifier-only passable result is contaminated evidence.
- External guide orientation agrees the Stones/Sunlight route requires a Magic
  Key, exits near the top/top-right of the castle, and hugs the outside wall to
  the lower-right stairs. Live door RAM during this pass already had both
  relevant map `0x04` doors open: `(4,13)` and `(18,6)`.
- Additional live checks kept the obvious single-bridge candidates closed:
  `(15,27)->DOWN`, `(15,27)->RIGHT`, `(19,23)->DOWN`,
  `(20,23)->DOWN`, `(20,18)->RIGHT`, `(20,19)->RIGHT`,
  `(20,21)->RIGHT`, `(14,6)->RIGHT`, `(14,15)->RIGHT`,
  `(14,13)->RIGHT`, `(14,12)->RIGHT`, and `(14,10)->RIGHT`.
- A second door-open frontier crawl was manually stopped at 236 edges. It
  exported review-only passthroughs `(9,6)`, `(10,6)`, `(11,6)`, `(12,6)`,
  `(13,13)`, `(7,12)`, `(8,12)` plus directional candidates `(3,6).north` and
  `(4,6).north`; local ROM-backed simulation with those opened still found no
  route from `(7,7)` to `(29,29)`. Do not promote those as the route fix.
- Top-right door-side route follow-up found the hidden exterior connector:
  `probe_edge_verify:21,8,RIGHT,5` entered `(22,8)` 6/6 despite tile `0`, and
  follow-up from `(22,8)` moved down into `(22,9)`. `MAP_PASSTHROUGH_CELLS`
  now includes `0x04["22,8"]`; this was the missing key-area/top-right
  connector, not a lower-boundary bridge.
- Reloaded route testing then stalled at `(14,6)->UP`. Direct verifier
  `probe_edge_verify:14,6,UP,5` blocked 5/5 with no drift, map change, or
  interruption, so `MAP_DIRECTIONAL_BLOCKS[0x04]["14,5"].south` is now modeled
  alongside the older `north` face.
- With `(14,5).south` injected at runtime, live planner still found a route
  from `(14,6)` / `(7,7)` to `(29,29)`. The next live autowalk attempt pinballed
  near `(25,21)` / `(26,20)`: promote only the quiet-confirmed
  `(25,22).north` blocker, keep `(27,20).west` open after a clean passable
  verifier, and continue live route verification after a script reload.
- Post-reload follow-up found the real x=25 descent the user had walked:
  `(25,10)->DOWN` entered `(25,11)` 6/6 despite tile `0`, and forced follow-up
  from `(25,11)->DOWN` entered normal floor `(25,12)`. `MAP_PASSTHROUGH_CELLS`
  now includes `0x04["25,11"]`.
- After `(25,11)` was reloaded, planner output from `(25,13)` changed to the
  desired lower descent route instead of the bad upper x=29 world-exit lane.
  Live autowalk then confirmed another false east exit:
  `probe_edge_verify:26,14,RIGHT,5` blocked 5/5, so `(27,14).west` is now
  modeled.
- Follow-up after revive/reload resolved the contradictory `(22,8)->DOWN`
  report: clean `probe_edge_verify:22,8,DOWN,5` blocked 5/5, so
  `(22,9).north` is now modeled. The missing connector was east along the
  top exterior strip instead: `(22,8)->RIGHT` moved 6/6 into `(23,8)`, and
  force-position/raw probes proved continuation through `(24,8)`, `(25,8)`,
  `(26,8)`, then down into normal floor `(26,9)`. `MAP_PASSTHROUGH_CELLS`
  now includes `0x04["23,8"]` through `["26,8"]`.
- Clean retry after a strange FCEUX input state reversed several apparent
  blockers: `(7,7)->RIGHT`, `(26,5)->LEFT`, and `(26,5)->UP` each moved 6/6
  with the verifier stability recheck. Do not promote the earlier blocked
  results for those edges.
- The upper x=29 exit lane is now guarded permanently: clean route testing
  showed west entries into `(29,9)` / `(29,10)` can leave Tantegel for the
  World Map instead of progressing toward the Sun Shrine. `MAP_DIRECTIONAL_BLOCKS`
  now includes `["29,9"].west` and `["29,10"].west` on map `0x04`.
- With only those two exit-lane guards injected at runtime, FCEUX autowalk from
  the throne-room stair tile `(7,7)` crossed the west side, the open `(18,6)`
  door, the top exterior strip, and the x=25 descent. It reached the lower
  corridor before dying: HP was `54/54` earlier in the run, `9/54` at
  `(26,20)`, then `Thou art dead.` at `(26,19)`.
- Current live blocker batch is paused for revive/reload plus lower-route
  hazard work. The lower x=25/x=26 route is walkable enough to reach the
  southeast corridor, but it crosses unmodeled damage cells. Candidate hazard
  cells from the death route include `(25,16)`, `(25,17)`, `(25,18)`,
  `(26,18)`, `(26,19)`, and `(26,20)`. Keep noisy route evidence for
  `(27,19).west` / `(27,20).west` unpromoted; prior quiet verifiers kept them
  open.
- Additional clean evidence confirmed the remaining forward bridge seam at the
  lower descent is one-way: `probe_edge_verify:26,14,DOWN,5` blocked
  `5/5` with no drift or interruption, while `probe_edge_verify:26,15,UP,5`
  confirmed passable. `MAP_DIRECTIONAL_BLOCKS[0x04]["26,15"].north` is now
  modeled to match this confirmed one-way behavior.
- Note: `(29,29)` intentionally exposes both `Stairs Down to Sun Shrine` and
  the `Southeast Exit to World Map` interaction. Coordinate `auto_walk:29,29`
  may log the exit label because both objects share the tile.

### Map-Patch Guardrails Added

Safety follow-up on 2026-05-22 after repeated wrong-map paste mistakes:
- `test_map_reader.lua` now has map-specific directional assertion helpers,
  including `assert_tantegel_dir(...)`, so future live Tantegel blockers can be
  asserted without manually retyping the map id in every assertion.
- Recent Tantegel route blockers now also have focused "not Brecconary"
  absence assertions where those coordinates should not legitimately exist on
  map `0x08`.
- `test_map_reader.lua` includes a narrow lint test for
  `MAP_DIRECTIONAL_BLOCKS` comments that obviously mention the wrong map, such
  as Tantegel/Sun Shrine/throne-route comments inside Brecconary blocks or
  Brecconary comments inside Tantegel blocks.
- `AGENTS.md` now tells future agents to use those helpers and to add focused
  wrong-map absence checks only when the coordinate is not legitimately shared.

Validation passed:
- `luac5.1 -p test_map_reader.lua map_reader.lua`
- `lua5.1 test_map_reader.lua` (36 tests)
- `git diff --check`

### Edge Verifier Tightened For One-Way Latches

Follow-up on 2026-05-23 after the `(12,9)` / `(13,9)` row-9 latch behavior:
- `probe_edge_verify` no longer publishes per-attempt `verified_probe_move`
  seam observations. It records passable seam history only after the final
  verifier classification is cleanly `confirmed_passable`.
- If all requested attempts move, the verifier waits an extra stability window
  (`edge_verify_stability_recheck_frames`, default 240) and performs one more
  raw-hold attempt before reporting `confirmed_passable`.
- Moves through a currently modeled blocked approach are logged with
  `moved_model_mismatch` and classify as `suspect_passable_model_mismatch`
  instead of clean passable evidence. Treat these as manual-review candidates,
  not automatic map-data proof.
- Final `EDGE_VERIFY_RESULT` now includes `moved_model_mismatch`,
  `blocked_model_mismatch`, and `stability_recheck` fields.

### Tantegel Sun Shrine Stairs Corrected

Live FCEUX investigation on 2026-05-22 corrected the bad Tantegel Castle
treasure/Sun Shrine stair marker:
- The old object at `(29,1)` was reachable ordinary floor; using STAIRS there
  produced "There are no stairs here."
- ROM down-stair candidates for map `0x04` included `(14,2)` and `(29,29)`.
- `auto_walk:29,29` reached `(29,29)` cleanly, and selecting STAIRS from that
  tile produced `EVENT: map change -> 0x0C (Sun Shrine)`.
- The live landing was `map=0x0C(Sun Shrine) x=0 y=4`.

Code/data updates:
- `objects.lua` now exposes the Sun Shrine stair as
  `Stairs Down to Sun Shrine` at `(29,29)` instead of the stale `(29,1)`
  treasure-room marker.
- The Sun Shrine return/exit marker on map `0x0C` is now `Exit to World Map`
  at `(0,4)`, matching the live stair landing, instead of the stale `(4,4)`.
- The route-crossed damage pocket near the southwest Tantegel barrier now marks
  `(9,18)`, `(10,18)`, `(11,18)`, and `(11,19)` as `damage` hazards so
  pathfinding and auto-step avoid them without misreporting them as walls.
- `test_objects.lua` rejects the stale `stair_29_1` object and requires
  `stair_29_29`, and also covers `exit_0_4`.
- `test_map_reader.lua` covers the expanded Tantegel damage hazard set.

Validation passed:
- `luac5.1 -p objects.lua map_reader.lua test_objects.lua test_map_reader.lua`
- `lua5.1 test_map_reader.lua` (35 tests)
- `lua5.1 test_objects.lua` (66 tests)

Current reload boundary:
- FCEUX needs a manual Lua reload before object navigation advertises the new
  `(29,29)` stair marker, the corrected Sun Shrine exit marker, and the new
  hazard avoidance data.
- Current live position after the stair proof was `map=0x0C(Sun Shrine) x=0
  y=4`.
- Follow-up log check live-disproved the other ROM map `0x04` down-stair
  candidate at `(14,2)`: STAIRS there produced "There are no stairs here."

### Tantegel 1F Door Locations Corrected

Live FCEUX investigation on 2026-05-22 found the two real locked doors on
Tantegel Castle `map=0x04`:
- West treasure-room door: stand at `(3,13)`, face east, OPEN records door RAM
  slot `(4,13)` and consumes one Magic Key.
- North/key-shop-area door: stand at `(18,5)`, face south, OPEN records door
  RAM slot `(18,6)` and consumes one Magic Key.
- The old y=6 "center door" band was disproved. OPEN returned
  "There is no door here" for the tested cells, and several y=6 cells allowed
  live movement without key consumption or door RAM writes.

Code/data updates:
- `MAP_DOOR_CELLS[0x04]` now contains only `(4,13)` and `(18,6)`.
- `(4,13)` was removed from `MAP_BLOCKED_CELLS[0x04]`; `(18,6).north` was
  removed from `MAP_DIRECTIONAL_BLOCKS[0x04]`.
- `objects.lua` now exposes `Treasure Room Door` and `Magic Key Area Door`
  instead of the bogus `Center Door`.

Validation passed:
- `luac5.1 -p map_reader.lua objects.lua test_map_reader.lua test_objects.lua debug_tools.lua`
- `lua5.1 test_map_reader.lua` (34 tests)
- `lua5.1 test_objects.lua` (64 tests)
- `git diff --check`

Current reload boundary:
- FCEUX still has the pre-patch Lua model loaded for any source changes below.
  Ask the player to reload `main.lua`, then verify that opened `(18,6)`
  remains traversable and that object browsing lists the two corrected doors.

### Tantegel Key-Merchant Route Cleanup

User play on 2026-05-22 found minor route hiccups around the unlocked chest
door and stair routes, but more trouble to/from the Magic Key Merchant. Log
review plus direct FCEUX verifiers split the suspects:
- Promoted `MAP_DIRECTIONAL_BLOCKS[0x04]["15,7"].east` after
  `probe_edge_verify:16,7,LEFT,5` blocked 5/5.
- Promoted `MAP_DIRECTIONAL_BLOCKS[0x04]["15,8"].east` after
  `probe_edge_verify:16,8,LEFT,5` blocked 5/5.
- Promoted `MAP_DIRECTIONAL_BLOCKS[0x04]["16,9"].north` after
  `probe_edge_verify:16,8,DOWN,5` blocked 5/5.
- Did not promote `(14,5).north`: `probe_edge_verify:14,4,DOWN,5` moved 5/5,
  so that earlier route hiccup was timing/noise, not map data.

Follow-up from the entrance route:
- Promoted the south approaches into `(20,6)`, `(21,6)`, `(22,6)`, and
  `(23,6)` after direct `probe_edge_verify` checks from row 7 each blocked
  5/5.
- Promoted `(24,2).south` and `(25,2).south` after direct counter-pocket
  verifiers from `(24,3)` and `(25,3)` blocked 5/5.
- Kept `(19,6).west` and `(19,6).south` open: after FCEUX input recovery,
  direct verifiers from `(18,6)` and `(19,7)` moved 5/5, and the successful
  route crossed `(19,6)` horizontally.
- The actual Magic Key Merchant stand is `(24,3)` facing north; `(24,2)` is
  the blocked counter/wall tile, not the route target.
- Live validation with the confirmed runtime blockers injected:
  `auto_walk:24,3` from the entrance `(11,28)` completed at `(24,3)`.

Validation passed:
- `luac5.1 -p map_reader.lua test_map_reader.lua`
- `lua5.1 test_map_reader.lua` (35 tests)
- `git diff --check`

Current live state:
- Last observed FCEUX position after the later route-loop investigation was
  `(28,17)` on Tantegel Castle `map=0x04`.
- The running FCEUX Lua script is stale versus source. Source already modeled
  `(27,16).east`, but live `inspect_move:28,16,LEFT` still reported it open.
  Ask the player to reload `main.lua` before judging any patched route below.

### Tantegel Sun Shrine / Throne Route Loop Cleanup

After the damage-hazard patch, the entrance-to-Sun-Shrine-stairs route and an
accidental throne-room-stairs route exposed more hidden Tantegel edges:
- Promoted `(14,5).north` and `(15,5).north` after the Sun Shrine route
  repeatedly failed entries from row 4.
- Promoted `(17,9).north`, `(18,9).north`, `(19,9).north`, `(20,9).north`,
  and `(21,9).north` after the Sun Shrine route repeatedly failed entries
  from row 8. The first four route blockers were found from route logs; the
  `(17,9)`, `(18,9)`, and `(19,9)` follow-ups were direct
  `probe_edge_verify` checks that each blocked 5/5.
- Promoted `(27,17).east` and `(27,20).east` from the accidental throne-room
  route; `(27,16).east` was already modeled in source and helped prove the
  live FCEUX script was stale. A post-reload check found those two new entries
  were initially misplaced in the Brecconary `0x08` block; they have been
  moved into Tantegel `0x04`.
- Did not promote retry-success/noisy observations around `(11,27)`,
  `(12,24)`, `(16,4)`, or horizontal movement around `(20,8)/(21,8)`.
- Live route status after runtime injection:
  - From `(28,16)`, `auto_walk:29,29` reached the Sun Shrine stairs cleanly.
  - From the entrance `(11,28)`, the route no longer loops but reports no path
    once the verified row-9 north-wall band is blocked.
  - Bracketing checks showed `(22,8)`, `(23,8)`, and `(24,8)` are wall tiles,
    so the east-wing detour cannot bridge around the row-9 wall band.
  - Superseded by the 2026-05-23 route proof above: the old row-16 route is
    invalid after `(15,16).west` was confirmed blocked, but the throne-side
    route reaches `(29,29)` via the reopened row-9 bridge. Treat the older "no
    safe route" interpretation as historical partial bracketing only.

Validation passed:
- `luac5.1 -p objects.lua map_reader.lua test_objects.lua test_map_reader.lua`
- `lua5.1 test_map_reader.lua` (35 tests)
- `lua5.1 test_objects.lua` (66 tests)
- `git diff --check`

Current reload boundary:
- FCEUX has runtime overlays for the post-reload edits in the current session:
  `(17,9).north`, `(18,9).north`, `(19,9).north`, `(27,17).east`, and
  `(27,20).east`.
- A future manual `main.lua` reload will clear those runtime overlays and load
  the same data permanently from `map_reader.lua`.
- After reload, a focused read-only check should show `approach_blocked=true`
  for `inspect_move:14,4,DOWN`, `inspect_move:15,4,DOWN`,
  `inspect_move:17,8,DOWN`, `inspect_move:18,8,DOWN`,
  `inspect_move:19,8,DOWN`, `inspect_move:20,8,DOWN`,
  `inspect_move:21,8,DOWN`, `inspect_move:28,17,LEFT`, and
  `inspect_move:28,20,LEFT`.

### Tantegel `4,11-4,15` Evidence Conflict Resolved

Open review item resolved on 2026-05-22:
- Live FCEUX recheck on map `0x04` kept most of the strip full-blocked:
  `(3,11..15)->RIGHT`, `(5,12..15)->LEFT`, and `(4,16)->UP` all verified
  blocked 5/5; `(5,11)->LEFT` repeated as blocked 10/10.
- `(4,10)->DOWN` into `(4,11)` stayed mixed and should not become a
  directional blocker by itself. A follow-up single probe blocked, and
  forced-origin checks from `(4,11)` could not move back out or continue down.
- The later door investigation split out `(4,13)` as the west treasure-room
  Magic Key door. `map_reader.lua` now keeps full blocks for `(4,11)`,
  `(4,12)`, `(4,14)`, and `(4,15)` while modeling `(4,13)` in
  `MAP_DOOR_CELLS[0x04]`.
- Validation: `luac5.1 -p map_reader.lua test_map_reader.lua`,
  `lua5.1 test_map_reader.lua`, and `git diff --check` passed.

### Map Crawler Review + Hardening

Detailed handoff: `HANDOFF_2026-05-22_map_crawler_review.md`

Commit: `9076d3a Harden map crawler and add per-map export file`

Accepted review outcome:
- Keep the commit.
- `auto_step_lost` orphan-step detection is the right crawler-local fix.
- Failed backtracks now classify as `backtrack_blocked` diagnostic evidence and
  no longer pollute directional candidates.
- `crawl_map_frontier` now refuses to start outside field state or while menus
  or dialogue are active.
- Every crawler finish writes `dw_crawl_<mapid_hex>.txt` next to
  `dw_debug.log` with Lua-snippet candidates for review.
- Finish speech now emits exactly one summary message.

Validation already run:
- `lua5.1 test_map_crawler.lua` passed: 32 tests.
- `luac5.1 -p map_crawler.lua main.lua test_map_crawler.lua` passed.
- `git diff --check HEAD~1..HEAD` passed.
- `python3 run_tests.py --allow-missing-speech-dep` passed with only the known
  WSL speech dependency warning for missing `accessible_output2`.

Optional follow-ups once the emulator is running:
- Live smoke test: run a tiny `crawl_map_frontier` with a low `max_edges`, stop
  it, then confirm `MAP_CRAWL_EXPORT_FILE` and the generated
  `dw_crawl_*.txt`.
- Harden export writes around `file:write` / `file:close`, not just `io.open`.
- Make `test_map_crawler.lua` restore global `io.open` through a per-test
  cleanup wrapper even when an assertion fails.

## Current Gameplay State

- Rimuldar is clean enough to leave for now.
- Rimuldar player-facing services and important routes had passed the latest
  route sweep before the handoff cleanup:
  - Weapons Merchant
  - Inn
  - Magic Key Merchant
  - Chest
  - Exit routes
- Do not continue broad Rimuldar blocker harvesting unless normal gameplay
  exposes a fresh failure.
- Next route/map work should move to another town, cave, or gameplay target.

## Open Review Items

- Decide whether overworld route waypoint validation needs a real overworld
  passability source before changing radius-0 behavior.

## Documentation Cleanup Notes

- Canonical current docs are:
  - `AGENTS.md`
  - `session_handoff.md`
  - `PROJECT_MEMORY.md`
  - `PLAYTESTING.md`
  - `debug_hooks.txt`
- `handoff_archive/` is historical evidence only. Do not read the whole archive
  by default.
- Assistant-local memories and `.claude/agent-memory/` are subordinate to repo
  docs when they disagree.
- Review packets for Claude should point to the current diff, focused tests,
  and this handoff instead of expecting Claude to reconstruct context from
  old archive files.

## Best Next Steps

1. Once the emulator is up, do the small crawler export smoke test.
2. Then continue with player-facing QoL or the next normal gameplay pass under
   FCEUX unless the task specifically needs BizHawk automation/debug behavior.
