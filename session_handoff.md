# Session Handoff — 2026-04-12

Latest detailed handoff:
- `HANDOFF_2026-04-12_survey_park_npcs_mode.md`

Quick summary of the latest session:
- Added an explicit survey-only parked-NPC mode:
  - `survey_map:park_npcs`
  - `survey_objects:park_npcs`
  - `survey_objects:retry_failed,park_npcs`
  - `survey_target:NAME,park_npcs`
  - `report_survey_start:park_npcs`
- parked mode behavior:
  - parks all active non-target NPC slots off-screen for the run
  - restores the current NPC target before its own attempt
  - restores the original survey-start NPC bytes on survey completion/manual stop
  - clears parked state on map change without writing old-map bytes into new-map RAM
- important current assumption:
  - until NPC movement-byte semantics are decoded, parked mode treats all
    active non-target NPCs as eligible instead of trying to identify "true
    movers" from byte 2
- focused regression coverage passed:
  - `lua test_map_survey.lua`
  - `lua test_route_manager.lua`
  - `lua test_map_reader.lua`
  - `lua test_objects.lua`
  - `lua -e 'assert(loadfile("map_survey.lua")); assert(loadfile("main.lua"))'`
- before live use:
  - reload the Lua script in FCEUX
  - compare `survey_map` vs `survey_map:park_npcs`
  - if parked mode surfaces new blocker candidates, still repro them directly
    before promoting permanent map data

Older handoff content follows for historical context.

# Earlier 2026-04-12 Summary

Latest detailed handoff:
- `HANDOFF_2026-04-12_route_cleanup_and_west_bisection.md`

Quick summary of the latest session:
- Morning code changes are now verified and documented:
  - `route_manager.lua` no longer treats `survey_safe` as shorthand for
    `skip_npcs`, so actual route planning still respects frozen NPC blockers
  - non-queued blocked steps still record runtime blocks but no longer trigger
    reroutes
  - Tantegel Castle now exposes only the reachable south-gate door object
    `door_10_30`
- new live chamber evidence found one stale permanent blocker on Map `0x04`:
  - `(19,17) -> RIGHT` moved onto `(20,17)`
  - `(20,18) -> UP` also moved onto `(20,17)`
  - but `inspect_tile:20,17` and exact `teleport_to:20,17` still treated it as
    permanently blocked
  - `map_reader.lua` was updated to remove stale blocker `20,17`
- after script reload, the fix verified live:
  - `inspect_tile:20,17` now reports `walkable=true` and
    `permanent_blocked=false`
  - clean repros from both west and south moved onto `(20,17)`
  - `debug_pathfind_to:23,16` and `debug_pathfind_to:18,22` now both find
    routes from `(13,16)`
- focused regression coverage passed:
  - `lua test_map_reader.lua`
  - `lua test_objects.lua`
  - `lua test_route_manager.lua`
  - `lua test_map_survey.lua`
  - `lua test_auto_step.lua`
  - `lua test_path_debug.lua`
- live west-bisection follow-up refined the current Map `0x04` picture:
  - `(23,15) -> LEFT` is open
  - `(23,17) -> LEFT` is open
  - `(20,15) -> LEFT` is open
  - `teleport_to:19,16` is refused because `(19,16)` is already
    `permanent_blocked=true`
  - direct `(20,16) -> LEFT` repro failed cleanly, re-confirming the existing
    blocker at `19,16`
- fresh post-fix survey evidence is encouraging:
  - `report_survey_start` from `(13,16)` is now `status=viable` with
    `reachable_area=128` and `open_exits=north|south|east`
  - a new `survey_map` from `(13,16)` is in progress and already advanced past
    the old chamber-isolation story
  - `Guard 3` completed with
    `reason=reroute_succeeded_after_runtime_block`
  - a fresh transient/runtime block candidate appeared at `(14,16)` from the
    west during that survey run
- best next-step repros from here:
  - finish reading out the in-flight `survey_map` results
  - if `(14,16)` repeats as a runtime block, repro it directly with split
    commands before changing map data
  - compare the updated chamber picture against
    `HANDOFF_2026-03-24_castle_chamber_probe.md`

Older handoff content follows for historical context.

# Earlier 2026-04-12 Summary

Latest detailed handoff:
- `HANDOFF_2026-04-12_map04_command_timing_and_bisection.md`

Quick summary of the latest session:
- The hop-over movement fix held up in live testing:
  - repeated single-press `DOWN` from `(13,18)` landed on `(13,19)`, not
    `(13,20)`
  - no new code changes were needed after the earlier commit
- Map `0x04` survey noise is now separating cleanly from seam evidence:
  - `Guard 2` and `Guard 3` from `(13,16)` both fell into
    `SURVEY_NPC_BLOCKED_ROUTE`
  - no fresh `route_blocked` / `blocked_step` seam evidence surfaced from
    those long frozen-NPC routes
- The old `tile=11` middle-band suspicion weakened:
  - `(13,16)` and `(14,16)` inspect as `base_walkable=true` and
    `effective_passable=true`
  - direct `probe_edge:RIGHT` from `(13,16)` moved successfully to `(14,16)`
- Most important new testing rule:
  - batching `teleport_to` with `survey_target` or `probe_edge` can produce
    stale start-state reads
  - reliable pattern is:
    - `freeze_npcs teleport_to:X,Y report_position`
    - wait for log confirmation
    - then send `probe_edge` / `survey_target` separately
- East-band bisection with the split-command pattern found these row-16 seams
  are open both ways:
  - `(20,16) <-> (21,16)`
  - `(21,16) <-> (22,16)`
  - `(22,16) <-> (23,16)`
- strongest next-step repros for tomorrow:
  - `teleport_to:23,15` then `probe_edge:LEFT`
  - `teleport_to:23,17` then `probe_edge:LEFT`
  - if both are open, `teleport_to:19,16` then `probe_edge:RIGHT`
    to continue the westward bisection

Older handoff content follows for historical context.

# Earlier 2026-04-12 Summary

Latest detailed handoff:
- `HANDOFF_2026-04-11_tantegel_seam_followup.md`

Quick summary of the latest session:
- The intermittent auto-step hop-over bug is closed for now:
  - `auto_step.lua` now forces a 2-frame neutral release immediately after a
    successful held step, preventing stale turn-repress input from chaining
    into a second tile
  - live repro from `(13,18)` with single `DOWN` input landed on `(13,19)` in
    three consecutive runs after reload
- Survey classification is more meaningful under `freeze_npcs`:
  - routes that fail only because frozen NPCs occupy the path now log
    `SURVEY_NPC_BLOCKED_ROUTE`
  - those attempts classify as `command_timing_or_state_issue` instead of
    polluting map no-route evidence
- Tantegel Castle Map `0x04` seam modeling improved again:
  - `12,16` now blocks east approach after repeated `(13,16) -> LEFT` failures
  - `13,24` now blocks west approach after repeated `(12,24) -> RIGHT` failures
  - stale `6,24 west` stayed removed after repeated successful live crossings
- verification passed:
  - `lua test_auto_step.lua`
  - `lua test_map_reader.lua`
  - `lua test_map_survey.lua`
  - `lua test_route_manager.lua`

Older handoff content follows for historical context.

# Session Handoff — 2026-04-11

Latest detailed handoff:
- `HANDOFF_2026-04-11_tantegel_seam_followup.md`

Quick summary of the latest session:
- Timing-noise handling is much better:
  - queued survey autowalk now has a settle gap
  - blocked-step retry budget increased to `3`
  - clean orphaned queued routes get one retry
- A stale route-context leak was fixed:
  - manual `probe_edge` failures no longer trigger reroutes from an old
    autowalk/survey target
  - survey orphan cleanup now clears route-manager state explicitly
- Tantegel Castle Map `0x04` south-pocket modeling improved:
  - stale permanent blockers at `13,24` and `14,20` were removed earlier in
    the session
  - fresh direct probes then refined the seam again:
    - `(13,20) -> RIGHT` into `14,20` failed twice
    - `(12,20) -> UP` into `12,19` succeeded twice
    - `(12,24) -> RIGHT` into `13,24` succeeded twice
  - `map_reader.lua` now:
    - removes stale `12,19 south`
    - keeps `12,19 east`
    - adds `14,20 west`
    - keeps `13,24` open
- Focused nearby-NPC surveys:
  - `Guard 11` succeeded
  - `Guard 10` succeeded
  - `Guard 3` crossed the seam successfully, then failed later with new
    blocker evidence centered on `6,24` and a secondary suspect at `12,16`
- strongest next-step repros for tomorrow:
  - `teleport_to:5,24` then `probe_edge:RIGHT` for `6,24`
  - `teleport_to:13,16` then `probe_edge:LEFT` for `12,16`
- verification passed:
  - `lua test_auto_step.lua`
  - `lua test_map_reader.lua`
  - `lua test_map_survey.lua`
  - `lua test_route_manager.lua`
  - `lua test_path_debug.lua`

Older handoff content follows for historical context.

# Session Handoff — 2026-03-21

## What Was Accomplished This Session

### 1. Remote command logging improved (FIXED & VERIFIED)
Remote object-navigation commands were reaching the emulator but were not
writing useful results to `dw_debug.log`; they only spoke via TTS. This made
automation testing blind.

**Fixes**
- `main.lua`: `next_object`, `prev_object`, `current_object`, and `next_filter`
  now emit structured `OBJECT:` / `FILTER:` log lines before speaking.
- `debug_tools.lua`: `report_position` now uses overworld coordinate RAM on
  map `0x00` instead of always reading interior-map coordinates.

**Verified live**
- `./dw_commands.sh current_object` now logs an `OBJECT:` line.
- `./dw_commands.sh next_object` advances selection and logs the new object.

### 2. Debug frame prefixes made monotonic (FIXED & VERIFIED)
`dw_debug.log` frame numbers were going backward because `frame_count` in
`main.lua` wrapped every 600 frames.

**Fix**
- `main.lua`: changed `frame_count = (frame_count + 1) % 600` to
  `frame_count = frame_count + 1`.

**Verified live**
- Successive commands logged increasing frames:
  `2520 -> 2760 -> 3060`.

### 3. NPC freeze regression check after frame change (VERIFIED OK)
The user raised a valid concern that the frame change might have affected
`freeze_npcs`.

**Investigation**
- Code inspection showed freeze uses RAM snapshots plus `apply_npc_freeze()`
  after every `FCEU.frameadvance()`, independent of `frame_count`.
- Live testing used `report_blockers` before freeze, during freeze, and after
  unfreeze.

**Verified live**
- Two successive blocker reports under freeze matched exactly.
- After `unfreeze_npcs`, blocker positions changed again.
- Conclusion: `freeze_npcs` was not affected.

### 4. Pathfinding behavior clarified: announce-only by design
I reproduced that `pathfind` computes and logs routes correctly but does not
move the player. That initially looked like a bug, but the user clarified this
is intentional: current pathfinder behavior is announce-only.

**Observed live**
- `./dw_commands.sh pathfind` logs a full route and sets `last_pathfind_obj`.
- `./dw_commands.sh report_position` immediately after still shows the player
  unchanged.

### 5. Auto-walk feature added as a separate pathfinder mode (IMPLEMENTED, NOT YET LIVE-TESTED)
The user requested a separate auto-walk feature while preserving the original
announce-only pathfinder logic.

**Implementation**
- `config.lua`: added `key_auto_walk` defaulting to `U`.
- `dw_access.ini`: added `key_auto_walk=U`.
- `main.lua`:
  - kept `O` / `pathfind` as announce-only
  - added `U` hotkey path to auto-walk the current object
  - added remote command `auto_walk`
  - refactored shared planning into helper functions
  - added `AUTO_WALK:` debug log lines
- `pathfinder.lua`:
  - added `find_route_to()`
  - added `find_route_to_adjacent()`
  - preserved existing `pathfind_to()` and `pathfind_to_adjacent()` output/logging
- `auto_step.lua`:
  - added queued multi-step route execution via `start_route()`
  - added route clearing/cancellation on manual input, blocked step, or invalid state

**Verification so far**
- `lua -e 'assert(loadfile("main.lua"))'` passed
- `lua -e 'assert(loadfile("auto_step.lua"))'` passed
- `lua -e 'assert(loadfile("pathfinder.lua"))'` passed
- `python3 run_tests.py` passed

**Important**
- Auto-walk is implemented in code but has not yet been verified live in FCEUX.
- A Lua script reload is required before testing it in-emulator.

## Current State

- Current known live location during testing was `Charlock Castle B4` at `x=14, y=7`.
- `debug_mode=true` and command-driven testing through `dw_commands.sh` is working.
- `pathfind` still announces only.
- `auto_walk` now exists, but still needs live verification after reload.

## Known Remaining Issues / Risks

### Auto-walk is not yet live-tested
Code compiles and existing tests pass, but the new queued route execution has
not yet been validated in the emulator.

Things to verify next session:
- `./dw_commands.sh auto_walk` actually starts movement
- queued route continues across multiple steps
- manual D-pad input cancels queued auto-walk cleanly
- blocked-step reroute still works when auto-walking

### NPC interaction after arrival may still be imperfect
Even with NPC freeze available, auto-walk and pathfinding to NPCs should be
tested specifically for:
- freeze engaging on initial auto-walk to NPC targets
- arrival adjacent to the correct NPC
- TALK succeeding instead of "There is no one there"

### Overworld auto-walk is intentionally unsupported
Auto-walk currently only works on interior maps. On overworld maps it should
announce that limitation and fall back to spoken directions only.

## Files Changed This Session

| File | Key Changes |
|------|-------------|
| `main.lua` | object command logging; monotonic frame counter; separate auto-walk helper/hotkey/command |
| `debug_tools.lua` | `report_position` uses overworld-safe coordinates |
| `pathfinder.lua` | route-returning helpers added while preserving existing announcement API |
| `auto_step.lua` | queued multi-step route execution for auto-walk |
| `config.lua` | new `key_auto_walk` default (`U`) |
| `dw_access.ini` | new `key_auto_walk=U` |
| `dw_commands.sh` | help text updated for `auto_walk` |

## Next Session Priorities

1. Reload the Lua script in FCEUX so the new auto-walk code is live.

2. Verify auto-walk on the current map:
   - `./dw_commands.sh current_object`
   - `./dw_commands.sh auto_walk`
   - `./dw_commands.sh report_position`
   - `./dw_commands.sh report_path_state`

3. Watch `dw_debug.log` for:
   - `AUTO_WALK: queued ...`
   - position changes over time
   - `runtime block:` entries
   - reroute logs if a step blocks

4. Test cancellation behavior:
   - begin auto-walk
   - manually press a D-pad direction
   - confirm the queued route cancels cleanly

5. Test NPC-target behavior:
   - auto-walk to a nearby guard
   - confirm freeze behavior is sufficient
   - check whether TALK succeeds on arrival

6. If auto-walk works, test additional hooks:
   - `pathfind_to:X,Y`
   - `pathfind_adjacent:X,Y`
   - `inspect_move:DIR`
   - `inspect_tile:X,Y`

## Useful Commands

```bash
./dw_commands.sh current_object
./dw_commands.sh next_object
./dw_commands.sh pathfind
./dw_commands.sh auto_walk
./dw_commands.sh report_position
./dw_commands.sh report_path_state
./dw_commands.sh report_blockers
./dw_commands.sh freeze_npcs
./dw_commands.sh unfreeze_npcs
./dw_commands.sh log_state
```
