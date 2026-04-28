# Handoff: Map04 Row-16 Retest And Park-NPCs Comparison
Date: 2026-04-13

## What Changed In Code

Updated `map_reader.lua` for Tantegel Castle `0x04` row `y=16`:

- removed stale full-cell blockers at:
  - `(16,16)`
  - `(17,16)`
  - `(19,16)`
  - `(18,16)`
  - `(15,16)`
- added a directional blocker at:
  - `MAP_DIRECTIONAL_BLOCKS[0x04]["16,16"].east = true`
  - `MAP_DIRECTIONAL_BLOCKS[0x04]["17,16"].south = true`
  - `MAP_DIRECTIONAL_BLOCKS[0x04]["18,16"].south = true`
- added passthrough overrides at:
  - `MAP_PASSTHROUGH_CELLS[0x04]["15,16"] = true`
  - `MAP_PASSTHROUGH_CELLS[0x04]["16,16"] = true`
  - `MAP_PASSTHROUGH_CELLS[0x04]["17,16"] = true`

Updated `test_map_reader.lua` to cover the new model:

- `(20,17)` remains open
- `(19,16)` is no longer permanently blocked
- `(18,16)` is no longer permanently blocked
- `(17,16)` is no longer permanently blocked
- `(16,16)` is no longer permanently blocked
- `(15,16)` is no longer permanently blocked
- `(15,16)` is passthrough with no confirmed directional blocker yet
- `(16,16)` is passthrough and blocks only from the east
- `(17,16)` blocks only from the south
- `(18,16)` blocks only from the south

Verification passed:

```bash
lua test_map_reader.lua
```

## Survey Comparison Result

Compared frozen-NPC baseline versus `park_npcs` using `survey_target:npc_3`
(`Old Man 1`) from start `(13,16)`.

### Frozen baseline

Command:

```bash
./dw_commands.sh --replace freeze_npcs survey_target:npc_3
```

Observed:

- `SURVEY_RESULT run=3`
- `failure_class=command_timing_or_state_issue`
- `blocked_events=2`
- `blocked_tiles=20,16|21,17`
- `reason=reroute_no_path`

### Parked-NPC run

Command:

```bash
./dw_commands.sh --replace survey_target:npc_3,park_npcs
```

Observed before manual stop:

- first fresh runtime hit was `(14,16)` approached from west
- later reroute also hit:
  - `(20,16)`
  - `(21,17)`
- after several reroutes, manual stop logged:
  - `failure_class=suspected_engine_blocked_tile`
  - `blocked_tiles=14,16|20,16|21,17|14,20|15,21`

Interpretation:

- `park_npcs` did surface a new candidate at `(14,16)`
- but direct repro disproved `(14,16)` as a stable blocker
- parked mode is still useful because it changed the failure shape enough to
  expose a deeper row-16 retest opportunity

## Direct Repros From This Session

### `(14,16)` from the west is **not** a stable blocker

Commands:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:13,16 report_position
./dw_commands.sh --replace inspect_tile:14,16 inspect_move:13,16,RIGHT
./dw_commands.sh --replace probe_edge:RIGHT report_position
```

Observed:

- `inspect_tile:14,16`
  - `tile=11`
  - `base_walkable=true`
  - `walkable=true`
  - `permanent_blocked=false`
- `probe_edge:RIGHT`
  - `status=moved`
  - `final=(14,16)`

Important neighboring wrinkle:

- exact `teleport_to:15,16` was refused
- `inspect_tile:15,16` shows `permanent_blocked=true`

So:

- do **not** promote `(14,16)` into permanent map data
- the parked-survey hit there was likely route/state noise caused by the nearby
  real block picture around `(15,16)`

### Updated row-16 west-band picture

The old handoff had treated `(19,16)` as the current west hard-stop.
Current live repros no longer support that.

#### `(19,16)` is enterable despite the old permanent blocker

All of these moved into `(19,16)`:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:19,17 report_position
./dw_commands.sh --replace probe_edge:UP

./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:19,15 report_position
./dw_commands.sh --replace probe_edge:DOWN

./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:20,16 report_position
./dw_commands.sh --replace probe_edge:LEFT

./dw_commands.sh --replace inspect_move:18,16,RIGHT
./dw_commands.sh --replace probe_edge:RIGHT
```

All corresponding `inspect_move` calls still claimed:

- `walkable=false`
- `permanent_blocked=true`

But the actual `EDGE_PROBE_RESULT` lines ended with:

- `status=moved`
- `final=(19,16)`

Interpretation:

- `MAP_BLOCKED_CELLS[0x04]["19,16"]` was stale

#### `(18,16)` is partially open, not a full-cell wall

Observed:

- `(19,16) -> LEFT` moved to `(18,16)`
- `(18,15) -> DOWN` moved to `(18,16)`
- `(18,17) -> UP` blocked at `(18,16)`

Interpretation:

- `(18,16)` should not remain a full permanent block
- best current model is:
  - cell is occupiable
  - south approach is blocked

#### Post-reload retest shifted the west stop one tile farther west

After reloading the Lua script in FCEUX and re-running the row-16 probes, the
new live picture became:

- `(19,17) -> UP` moved to `(19,16)`
- `inspect_tile:19,16`
  - `walkable=true`
  - `permanent_blocked=false`
- `(18,15) -> DOWN` moved to `(18,16)`
- `inspect_tile:18,16`
  - `walkable=true`
  - `permanent_blocked=false`
  - `directional_blocked=true`
- exact `teleport_to:18,16` now succeeds after reload
- `(18,16) -> LEFT` moved to `(17,16)`
- `(17,15) -> DOWN` moved to `(17,16)`
- `(17,17) -> UP` blocked at `(17,16)` with runtime block:
  - `cell=(17,16) approach=south`
- `(17,16) -> LEFT` blocked at `(16,16)` with runtime block:
  - `cell=(16,16) approach=east`

Current best read after reload:

- row `16` remains open across:
  - `(17,16) -> (16,16)`
  - `(20,16) -> (19,16)`
  - `(19,16) -> (18,16)`
  - `(18,16) -> (17,16)`
- after more split repros:
  - `(15,17) -> UP` moved to `(15,16)`
  - `(15,16) -> LEFT` moved to `(14,16)`
  - `(16,15) -> DOWN` moved to `(16,16)`
  - `(16,17) -> UP` moved to `(16,16)`
  - `(17,16) -> LEFT` blocked at `(16,16)` from the east
- current best west stop is now farther west than `(16,16)`
- repeated `(13,16) -> LEFT` repros on `(12,16)` were mixed:
  - one direct probe moved into `(12,16)`
  - the next clean repeat blocked with `reason=route_blocked`
  - do **not** change the `(12,16)` east-side directional blocker yet
- `(17,16)` should be modeled directional-only from the south
- `(16,16)` should be modeled as a passthrough cell with an east-side blocker
- the next live west-stop candidate is now `(15,16)` or farther west

## Recommended Next Steps

1. Reload the Lua script in FCEUX so the row-16 blocker model is live.

2. Recheck the updated cells after reload:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:19,17 report_position
./dw_commands.sh --replace probe_edge:UP report_position
./dw_commands.sh --replace inspect_tile:19,16

./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:18,15 report_position
./dw_commands.sh --replace probe_edge:DOWN report_position
./dw_commands.sh --replace inspect_tile:18,16
```

3. Reload the Lua script in FCEUX again so the `15,16` passthrough fix is live.

4. Continue west-bisection at the new stop candidate:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:15,16 report_position
./dw_commands.sh --replace probe_edge:LEFT report_position

./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:14,15 report_position
./dw_commands.sh --replace probe_edge:DOWN report_position

./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:14,17 report_position
./dw_commands.sh --replace probe_edge:UP report_position
```

5. Re-check the unstable `(12,16)` east-entry only after the latest reload:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:13,16 report_position
./dw_commands.sh --replace probe_edge:LEFT report_position
```

## Final Pass Before Wrap-up

Using a fresh reload from the user, one more west-corridor pass was run.

### `15,16` is another decoder-gap corridor tile

Observed:

- exact `teleport_to:15,16` now works when the latest script is loaded
- `(15,16) -> LEFT` initially looked open on `inspect_move`
- one direct `probe_edge:LEFT` from `(15,16)` blocked at `(14,16)` with:
  - `runtime block: cell=(14,16) approach=east`
- but `15,16` itself remained clearly occupiable and later:
  - `(15,17) -> UP` moved to `(15,16)`
  - `(15,16) -> LEFT` moved to `(14,16)` in the same live session

Code/model update from this evidence:

- `MAP_PASSTHROUGH_CELLS[0x04]["15,16"] = true`
- removed stale full blocker at `(15,16)`

### `14,16` is now mixed and should stay unpromoted for the moment

North and south probes disagreed:

- `(14,15) -> DOWN`
  - `inspect_move` reported open
  - `probe_edge` moved to `(14,16)`
- `(14,17) -> UP`
  - `inspect_move` also reported open
  - but `probe_edge` blocked with:
    - `runtime block: cell=(14,16) approach=south`
    - `reason=route_blocked`

And earlier in the same session:

- `(15,16) -> LEFT` also produced one blocked repro into `(14,16)` from east

Current best interpretation:

- `(14,16)` is not a clean permanent blocker
- `(14,16)` is also no longer a cleanly-open cell in runtime behavior
- evidence now points to either:
  - a directional runtime blocker from south and possibly east
  - or state-sensitive probe noise around this corridor transition

Recommendation:

- do **not** promote a directional block for `(14,16)` yet
- keep it as a live recheck target after a fresh reload and a few more direct
  one-step repros

### `12,16` remains mixed

Same as earlier this day:

- one `(13,16) -> LEFT` repro moved into `(12,16)`
- the next clean repeat blocked with:
  - `runtime block: cell=(12,16) approach=east`

Recommendation remains unchanged:

- do **not** change `MAP_DIRECTIONAL_BLOCKS[0x04]["12,16"].east` yet
- treat it as unresolved until repeated on a later session

## Late Addendum: Cleaner Retest From The Same Live Session

After confirming the script was live again on `map=0x04` and returning a
baseline `POSITION: x=7 y=7`, the exact resume-point probes were rerun in short
split batches.

### `(14,16)` no longer reproduced as mixed

Commands:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:15,16 report_position
./dw_commands.sh --replace probe_edge:LEFT report_position

./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:14,15 report_position
./dw_commands.sh --replace probe_edge:DOWN report_position

./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:14,17 report_position
./dw_commands.sh --replace probe_edge:UP report_position
```

Observed:

- exact `teleport_to:15,16` succeeded
- `(15,16) -> LEFT` moved to `(14,16)`
- `(14,15) -> DOWN` moved to `(14,16)`
- `(14,17) -> UP` also moved to `(14,16)` after timeout retries
- all three `MOVE` previews for destination `(14,16)` logged:
  - `permanent_blocked=false`
  - `directional_blocked=false`
  - `effective_passable=true`

Interpretation:

- the earlier blocked south/east repros at `(14,16)` did **not** reproduce in
  this cleaner pass
- current best live read is that `(14,16)` stays open
- do **not** add a directional blocker there

### `(12,16)` east-entry is still mixed, with a clearer planner/runtime mismatch

Commands:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:13,16 report_position
./dw_commands.sh --replace probe_edge:LEFT report_position

./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:13,16 report_position
./dw_commands.sh --replace probe_edge:LEFT report_position
```

Observed on the first repeat:

- `MOVE` preview still claimed for destination `(12,16)`:
  - `directional_blocked=true`
  - `blocked_approach=east`
  - `approach_blocked=true`
  - `effective_passable=false`
- despite that, `EDGE_PROBE_RESULT` ended with:
  - `status=moved`
  - `final=(12,16)`

Observed on the second repeat:

- the same `MOVE` preview fields were logged again
- this time `EDGE_PROBE_RESULT` ended with:
  - `status=blocked`
  - `reason=route_blocked`
- runtime block logged:
  - `cell=(12,16) approach=east`

Interpretation:

- `(12,16)` east-entry is still not stable enough to edit map data
- the east-side directional blocker should remain in `map_reader.lua` for now
- but the newer logs now show a more specific follow-up target:
  - understand why a probe can sometimes move into `(12,16)` even while the
    preview says the east approach is blocked

Updated recommendation:

- keep `(14,16)` open
- keep `(12,16)` unresolved
- spend the next live session on repeated exact-start `(13,16) -> LEFT` probes,
  plus any logging that helps explain the preview/result mismatch

## Code Follow-up: Probe Mismatch Logging

`main.lua` now records the probe preview at `EDGE_PROBE_START` time and, after a
Lua reload in FCEUX, emits an extra structured line when preview and outcome
disagree:

- `EDGE_PROBE_MODEL_MISMATCH`

This is meant to catch cases exactly like `(13,16) -> LEFT` on `(12,16)`.

The mismatch log reports:

- whether the probe moved through a modeled block or blocked despite an open
  preview
- the start-of-probe `approach_blocked` and `effective_passable` values
- the final post-probe values
- whether the blocked approach came from:
  - static directional map data
  - runtime directional block data

Use this after reloading the script in FCEUX before the next row-16 retest.

## Post-Reload Verification Of The New Probe Logging

After the user reloaded the Lua script in FCEUX, the new logging was checked
with short exact-start probe batches.

### `(13,16) -> LEFT` is currently blocking consistently again

Commands:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks report_position
./dw_commands.sh --replace inspect_move:13,16,LEFT
./dw_commands.sh --replace probe_edge:LEFT report_position

./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:13,16 report_position
./dw_commands.sh --replace probe_edge:LEFT report_position
```

Observed:

- `inspect_move:13,16,LEFT` still logged:
  - `directional_blocked=true`
  - `blocked_approach=east`
  - `approach_blocked=true`
  - `effective_passable=false`
- both post-reload `probe_edge:LEFT` runs ended with:
  - `status=blocked`
  - `reason=route_blocked`
- each blocked run published:
  - `runtime block: map=0x04 cell=(12,16) approach=east`
- no `EDGE_PROBE_MODEL_MISMATCH` line appeared in either blocked run

Interpretation:

- the new mismatch logger did not false-trigger on a normal blocked outcome
- the current live session did **not** reproduce the earlier
  moved-through-modeled-block contradiction at `(12,16)`
- keep `(12,16)` unresolved because the older moved result still exists in the
  same day’s evidence set

### Other historically mixed one-step probes were clean after reload

Commands:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:14,17 report_position
./dw_commands.sh --replace probe_edge:UP report_position

./dw_commands.sh --replace freeze_npcs clear_runtime_blocks teleport_to:15,16 report_position
./dw_commands.sh --replace probe_edge:LEFT report_position
```

Observed:

- `(14,17) -> UP` moved to `(14,16)`
- `(15,16) -> LEFT` moved to `(14,16)`
- neither run emitted `EDGE_PROBE_MODEL_MISMATCH`

Interpretation:

- `(14,16)` continues to look open in the current post-reload session
- the new logger is staying quiet on normal successful probes
- the logger still needs a future contradictory live repro to be verified
  end-to-end

4. For survey work, keep treating `park_npcs` as a comparison/debug mode, not
   evidence by itself. Repro fresh candidates directly before promoting map
   data.
