Session handoff: 2026-03-23

Scope
- Live QA and targeted patching for hidden collision cells on `map 0x04` (Tantegel Castle).
- Focus areas were `test_path`, direct `debug_pathfind_to`, `validate_path`, and sweep-driven discovery.

Stable verified fixes before the final reload
- `validate_path` no longer drifts expected coordinates after a failed step.
- `stop_validate` now cancels the active injected step and no longer leaves runtime-block residue.
- Validation/step-debug no longer pollutes runtime blockers.
- Runtime blockers are pruned when the player is actually standing on a blocked cell.
- `test_path` now snapshots blockers once per suite run and became stable on repeated `map 0x04` runs.
- Direct-goal pathfinding now rejects blocked or non-walkable exact goals.

Confirmed hidden collision cells patched in `map_reader.lua`
- `20,20`
- `21,19`
- `20,3`
- `22,3`
- `27,2`
- `26,3`
- `19,2`

Live verification completed for these cells
- `(20,20)` and `(21,19)`
  - Previously looked walkable and pathable.
  - One-step live validation failed.
  - After patch, `inspect_tile` reported `walkable=false` and `debug_pathfind_to` returned `No path found`.
- `(20,3)` and `(22,3)`
  - Same pattern from live position `(21,3)`.
  - After patch, both reported `walkable=false` and no direct path.
- `(27,2)` and `(26,3)`
  - Same pattern from live position `(27,3)`.
  - After patch, both reported `walkable=false` and no direct path.

Last patch made but not yet re-verified after reload
- Added `["19,2"] = true` to `MAP_BLOCKED_CELLS[0x04]` in `map_reader.lua`.
- Repro before patch:
  - Stable live position at `(19,3)`.
  - `inspect_tile:19,2` -> `walkable=true`
  - `inspect_move:UP` -> destination `(19,2)` reported open
  - `debug_pathfind_to:19,2` -> `Path: 1 north`
  - `validate_path` -> immediate mismatch; actual stayed `(19,3)`
- The user reloaded after this patch, but the session wrapped before we read back the verification logs.

Current code files touched this session/history
- `main.lua`
- `route_manager.lua`
- `path_debug.lua`
- `auto_step.lua`
- `map_reader.lua`
- `pathfinder.lua`

Important behavior notes
- `map 0x04` is the large castle map where most pathfinding issues were found.
- The user often referred to the "second map"; actual live checks repeatedly confirmed when the emulator was on `map 0x04`.
- Running direct probes while `sweep_map` is active is noisy because the sweep teleports the player. Stop the sweep before validating a candidate cell.
- Best workflow for new hidden collisions:
  1. `./dw_commands.sh freeze_npcs`
  2. `./dw_commands.sh clear_runtime_blocks`
  3. `./dw_commands.sh sweep_map`
  4. let it run long enough to gather repeated `SWEEP BLOCKED` lines
  5. `./dw_commands.sh stop_sweep`
  6. `./dw_commands.sh export_blocks`
  7. use the stopped position to directly validate only nearby candidates with:
     - `inspect_tile:X,Y`
     - `inspect_move:DIR`
     - `debug_pathfind_to:X,Y`
     - `validate_path`
  8. patch only cells reproduced directly

Known sweep-derived candidates not yet promoted
- These appeared in exports and/or sweep logs but were not directly confirmed in a stable stopped state:
  - `20,2`
  - `21,2`
  - `23,3`
  - `24,2`
  - `25,2`
  - `25,3`
  - `9,2`
  - `10,2`
  - `2,3`
- We previously promoted some low-confidence sweep hits too early and caused `test_path` regressions, so keep the promotion threshold conservative.

Most recent stable results before wrap-up
- After patching `(27,2)` and `(26,3)`, live verification succeeded and `test_path` still passed `5/5`.
- After stopping a later sweep, live position was `(18,3)`.
- `(19,3)` was directly tested and validated OK, so that cell should NOT be patched.
- `(19,2)` was directly tested and failed validation, so that cell WAS patched.

Recommended next-session start
1. Verify the last reload picked up `19,2`:
   - `./dw_commands.sh inspect_tile:19,2`
   - `./dw_commands.sh debug_pathfind_to:19,2`
   - optional if needed: `./dw_commands.sh validate_path`
2. Re-run `./dw_commands.sh test_path` on `map 0x04`.
3. Resume the frozen sweep workflow and validate only nearby candidates from the stopped sweep position.

Expected success criteria for the first next-session check
- `inspect_tile:19,2` should show `walkable=false`
- `debug_pathfind_to:19,2` should return `No path found`
- `test_path` should remain `5 passed, 0 failed`
