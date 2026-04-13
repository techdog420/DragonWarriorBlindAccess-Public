# Handoff: Brecconary Blockers And Survey Regression

Date: 2026-04-03

## What Happened This Session

Work stayed focused on Brecconary (`map 0x08`) pathfinding fidelity and live
confirmation of engine-blocked but visually passable tiles.

The session had three phases:

1. Confirm and promote remaining northeast / Merchant 1 blocker candidates.
2. Improve debug visibility so `inspect_move` and edge probes report
   directional approach blocks honestly.
3. Analyze a fresh survey regression that collapsed to `1/21` successes and
   trace it to a repeat southwest reroute trap rather than a global pathfinder
   failure.

## Code Changes Made

### 1. Debug reporting now reflects directional approach blocks better

`main.lua` was updated so tile/move reports include:

- `directional_blocked`
- `blocked_approach`
- `approach_blocked`
- `effective_passable`

This made live probing much faster because `inspect_move` and edge-probe output
now at least surfaces known directional data instead of pretending all
walkable-looking cells are equivalent.

### 2. Brecconary permanent directional blockers promoted from direct repros

`map_reader.lua` now includes these directly reproduced Brecconary directional
blocks:

- northeast band:
  - `(27,5)` blocked from `east`

- Merchant 1 pocket:
  - `(7,19)` blocked from `east`
  - `(6,20)` blocked from `south`
  - `(5,21)` blocked from `east`
  - `(7,21)` blocked from `west`

- southwest survey reroute trap:
  - `(5,23)` blocked from `east`
  - `(8,25)` blocked from `east`
  - `(8,26)` blocked from `east`
  - `(9,27)` corrected to blocked from `north`

Important nuance:
- `7,22` was probed during the Merchant 1 work, but that failure matched
  already-existing permanent data rather than revealing a new blocker.
- `7,20` is still not directly confirmed in the latest loop. It remains a
  likely suspect, but was not promoted this session.

### 3. Regression coverage was extended

`test_map_reader.lua` was updated to assert all newly promoted Brecconary
directional blockers above, including the corrected `9,27.north`.

## Key Live Findings

### Merchant 1 pocket

The original survey candidate cluster around Merchant 1 produced clean direct
repros:

- `(6,21) -> (6,20)` failed with runtime block on cell `(6,20)` approach
  `south`
- `(6,21) -> (5,21)` failed with runtime block on cell `(5,21)` approach
  `east`
- `(6,21) -> (7,21)` failed with runtime block on cell `(7,21)` approach
  `west`

These are the strongest blockers added this session because they came from
`debug_pathfind_* + trace_path + validate_path`, not just survey correlation.

### Northeast Brecconary is much clearer now

Live checks confirmed:

- west entry is blocked on the `x=27, y=2..6` band
- `(28,7) -> (27,7)` is the first real opening
- the old northeast pocket is not sealed; it dead-ends structurally farther in
- `Woman 1` now resolves as `no_path_found` rather than a misleading movement
  failure, which is consistent with the fixed northeast blocker data

### Fresh survey regression was local, not global

After reloading and rerunning `survey_map`, the run finished at:

- `targets=21 successes=1 failures=20 no_route=6 suspected_engine_blocked=14`

The failure pattern was not “planner can no longer reach anything.”
Instead, nearly all routed attempts got poisoned by the same southwest reroute
sequence:

- first attempt from `(6,22)` to `Guard 4` failed at `(5,23)` from the east
- reroutes then repeatedly failed at:
  - `(9,27)` from the north
  - `(8,26)` from the east
  - `(8,25)` from the east

After that, many later survey attempts restarted from `(9,25)` and repeated
the same collapse.

This is why the run looked catastrophic even though it was mostly one local
trap being rediscovered.

## Evidence References

Useful `dw_debug.log` anchors from this session:

- Merchant 1 direct repros:
  - `(6,20)` mismatch + runtime block: lines `171` and `174`
  - `(5,21)` mismatch + runtime block: lines `213` and `216`
  - `(7,21)` mismatch + runtime block: lines `253` and `257`

- southwest survey trap:
  - `(5,23)` runtime block: line `59`
  - `(9,27)` runtime block: line `228`
  - `(8,26)` runtime block: line `374`
  - `(8,25)` runtime block: line `528`

- bad survey summary:
  - `SURVEY_COMPLETE ... successes=1 failures=20 ...`: line `7181`

## Verification Performed

Local verification passed after the latest edits:

- `lua test_map_reader.lua`
- `python3 run_tests.py --allow-missing-speech-dep`

The only expected warning in this environment is missing `accessible_output2`.

## Files Changed This Session

- `main.lua`
- `map_reader.lua`
- `test_map_reader.lua`

## Remaining Unresolved Issues

### 1. `7,20` still needs direct confirmation

The Merchant 1 cluster likely still contains a real blocker at `7,20`, but the
latest direct setup route hit `7,21` first. Do not promote `7,20` permanently
until it gets the same direct repro standard as the neighboring cells.

### 2. Survey target count still mutates mid-run

The survey denominator changed during a single run (for example `1/21`, then
later `3/22`, and later as high as `21/27`). That means the target list is not
stable after survey start.

This is a harness reliability issue independent of the Brecconary block map.
It makes cross-run comparisons noisy and should be investigated once the most
obvious map blockers stop dominating the run.

### 3. `inspect_move` is better, but still not perfect for some live cases

One notable example:

- `inspect_move:9,26,DOWN` reported destination `(9,27)` with
  `blocked_approach=north`
- that helped reveal that the permanent data had the wrong direction for
  `9,27`

So the reporting improvements were valuable, but it is still worth sanity-
checking suspicious cases against actual `validate_path` output.

## Best Next Steps

When work resumes:

1. Reload the Lua script in FCEUX so the newest Brecconary blocker data is
   live.

2. Run a clean survey setup:

```bash
./dw_commands.sh clear_runtime_blocks
./dw_commands.sh freeze_npcs
./dw_commands.sh survey_map
```

3. If the survey still collapses early, inspect the first routed failure before
   changing more permanent data.

4. Highest-value focused follow-ups:

```bash
./dw_commands.sh debug_pathfind_adjacent:4,22
./dw_commands.sh trace_path
./dw_commands.sh validate_path

./dw_commands.sh debug_pathfind_adjacent:4,19
./dw_commands.sh trace_path
./dw_commands.sh validate_path
```

Interpretation:
- `4,22` is the southwest trap follow-up after the latest fixes
- `4,19` is the best remaining Merchant 1 pocket follow-up and may expose
  whether `7,20` deserves promotion

5. After blocker behavior stabilizes, investigate why `survey_map` mutates its
   target count mid-run.

## Worktree Note

The worktree is already dirty from prior sessions. Do not broadly revert files.
Continue with narrow edits and verify each live blocker before promoting it into
permanent map data.
