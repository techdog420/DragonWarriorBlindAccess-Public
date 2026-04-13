# Handoff: Brecconary Survey Follow-Up

Date: 2026-04-03

## What Changed This Session

Work stayed focused on Brecconary (`map 0x08`) survey reliability and
pathfinder behavior during adjacent-goal reroutes.

### 1. `survey_map` bookkeeping was stabilized

`map_survey.lua` no longer mutates the survey denominator mid-run when retries
are queued. The original target set stays fixed, and retries are handled from a
separate internal queue.

Effect:
- survey logs now keep a stable `idx=X/21`
- retries still happen once
- cross-run comparisons are much easier

### 2. Survey start logging was improved

`survey_map` now logs:

- `SURVEY_START`
- `SURVEY_START_CONTEXT`
- `SURVEY_START_WARNING` for low-connectivity starts

This makes it obvious when a run begins from a pocket tile instead of only
discovering that after a collapse.

### 3. Adjacent-goal tie-breaking was strengthened

`pathfinder.lua` now prefers equal-length adjacent destinations by:

1. larger reachable walk area
2. then larger immediate open-exit count

This was added to reduce the chance of picking short routes into tiny
continuation-poor pockets.

### 4. Regression coverage was extended

Tests were added/updated in:

- `test_map_survey.lua`
- `test_pathfinder.lua`

Verification passed earlier in the session with:

- `lua test_map_survey.lua`
- `lua test_pathfinder.lua`
- `lua test_map_reader.lua`
- `python3 run_tests.py --allow-missing-speech-dep`

The expected warning in this environment is still missing `accessible_output2`.

## Latest Live Survey After Restart

The newest live run in `dw_debug.log` started after a script restart at:

- `Started: 2026-04-03 21:08:33`
- `SURVEY_START run=1 map=0x08 start=(8,16) targets=21 mode=objects runtime_blocks=0`
- `SURVEY_START_CONTEXT ... open_exit_count=4 open_exits=north|south|west|east`

So the run did **not** start from a trapped tile this time.

### What went well

- start-context logging worked as intended
- the survey denominator stayed fixed
- the initial `Guard 6` adjacent selection improved

For `Guard 6`, the planner now initially chose:

- `pathfind chosen adj=(9,26)` at line `465`

That is better than the earlier tendency to head straight for `(10,25)`.

### Where the run still failed

During that same `Guard 6` route:

- movement from `(9,28)` to `(9,27)` failed
- the runtime block logged was `cell=(9,27) approach=south`
- the survey recorded `blocked_tiles=9,27`

Useful anchors:

- initial `Guard 6` choice: line `465`
- runtime-block reroute sequence begins around line `601`
- `Guard 6` result: line `858`

After that failure, reroute still chose:

- `pathfind chosen adj=(10,25)` at line `680`

and the route completed there. The survey then cleared runtime blocks for the
next target, but it was still physically starting from `(10,25)`, and most of
the remaining targets devolved into `no_path_found`.

Final summary for this run:

- `SURVEY_COMPLETE run=1 map=0x08 targets=21 successes=6 failures=15 no_route=15 movement_failed=0 suspected_engine_blocked=0 state_issues=0 adjacency_issues=0`

## Most Important Current Interpretation

This latest run changes the picture a bit:

- the new tie-breaker **did** help the initial adjacent choice for `Guard 6`
- the survey still collapsed because the **reroute after a live block at
  `9,27`** ended in `(10,25)`
- the remaining problem is now less about the first adjacent choice and more
  about reroute behavior after a mid-route blockage

Important nuance:
- the permanent map data currently encodes `(9,27)` as `north = true`
- the newest live failure implicated `(9,27)` from `approach=south`
- that is not enough by itself to promote a new permanent directional block,
  but it is now a high-value direct repro target

## Evidence References

Useful `dw_debug.log` anchors from the latest run:

- survey start:
  - line `9`
- survey start context:
  - line `10`
- first improved `Guard 6` adjacent choice to `(9,26)`:
  - line `465`
- live runtime-block hit at `9,27` leading to reroute:
  - line `601`
- reroute choosing `(10,25)`:
  - line `680`
- `Guard 6` survey result with `blocked_tiles=9,27`:
  - line `858`
- runtime blocks cleared before next attempt:
  - lines `860-861`
- final survey summary:
  - line `2248`

Relevant code/data anchors:

- permanent Brecconary blocker entry for `(9,27)`:
  - `map_reader.lua:643`
- assertion for existing `(9,27).north` expectation:
  - `test_map_reader.lua:216`

## Best Next Steps Tomorrow

1. Confirm the latest Lua changes are actually live in FCEUX before probing
   further.

2. Re-run the clean survey setup once:

```bash
./dw_commands.sh clear_runtime_blocks
./dw_commands.sh freeze_npcs
./dw_commands.sh survey_map
```

3. If `Guard 6` still becomes the pivot, directly investigate the new
   `9,27 approach=south` question before changing permanent data:

```bash
./dw_commands.sh debug_pathfind_adjacent:10,26
./dw_commands.sh trace_path
./dw_commands.sh validate_path
```

4. If needed, probe the specific movement edge explicitly:

```bash
./dw_commands.sh inspect_move:9,28,UP
./dw_commands.sh inspect_move:9,26,DOWN
```

5. Treat `(10,25)` as a continuation trap for survey purposes even after
   runtime blocks are cleared. If a reroute lands there again, inspect why that
   destination still wins.

## Open Questions

### 1. Is `(9,27)` blocked from both north and south?

Current permanent data only captures `north`. The latest live run suggests a
possible `south`-approach failure too, but this still needs a direct,
repeatable repro outside survey noise.

### 2. Why does reroute still prefer `(10,25)` after the `9,27` hit?

The new heuristic helped on the first choice, so tomorrow's investigation
should focus on the reroute search state after a runtime-block insertion rather
than reworking the initial chooser blindly.

### 3. Is `7,20` still a real blocker?

That earlier suspicion remains unresolved, but the newest run did not produce a
fresh strong repro for it. Do not promote it based on stale survey evidence
alone.

## Worktree Note

The worktree is intentionally dirty. Continue with narrow edits only, and do
not broadly revert unrelated files.
