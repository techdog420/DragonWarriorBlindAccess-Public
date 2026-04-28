# Handoff 2026-04-23 — Map 0x04 post-patch survey analysis

## What happened

After adding the five directly confirmed directional blocks from the suspect
probe campaign, a fresh `survey_objects:park_npcs` run was executed on map
`0x04`.

Survey start:
- `SURVEY_START_CONTEXT run=2 map=0x04 start=(10,10)` in `dw_debug.log:47`

Survey summary:
- `targets=29`
- `successes=14`
- `failures=15`
- `gated_or_isolated=5`
- `suspected_engine_blocked=8`
- `state_issues=2`

Summary line:
- `dw_debug.log:18780`

## Net effect of the five-block patch

The patch did **not** improve the total success count yet:
- prior run: `15 successes / 14 failures`
- this run: `14 successes / 15 failures`

But it **did** improve the structure of the failures:
- prior run failures repeatedly cited the east-wall cluster
  `(18,6)/(19,6)/(20,6)/(21,5)/(21,4)` plus noisy neighbors
- this run no longer centers on that five-cell cluster
- most east-side failures now collapse to a **single seam**:
  `(17,6)` approached from north (stepping down from `(17,5)`)

That means the five-block model update likely removed the old false-open
connector band correctly, and the remaining issue is now narrower.

## Current failure groups

### Expected gated set

Five failures are still the expected gated west-wing group:
- `Chest` x4
- `Guard` x1

Grouped in:
- `SURVEY_FAILURE_START map=0x04 start=(13,16) failures=5 ... gated_or_isolated=5`
- `dw_debug.log:18783`

### Main residual east-side issue: `(17,6)`

Seven failures now cluster around start `(17,5)`:
- `Guard 5`
- `Merchant 3`
- `Old Man 1`
- `Old Man 2`
- `Stairs Down to Throne Room`
- `Stairs Down to Treasure Room`
- `Woman 2`

Grouped in:
- `dw_debug.log:18782`

Of those, six are `suspected_engine_blocked_tile` failures that cite only
`17,6`:
- `Woman 2` — `dw_debug.log:17289`
- `Merchant 3` — `dw_debug.log:17526`
- `Guard 5` — `dw_debug.log:17743`
- `Old Man 2` — `dw_debug.log:17958`
- `Stairs Down to Treasure Room` — `dw_debug.log:18089`
- `Old Man 1` — `dw_debug.log:18219`

Typical pattern:
- route begins at `(17,5)`
- first move is `dir=down` into `(17,6)`
- auto-step times out 3 times
- survey records runtime block at `(17,6)` north approach
- reroute then says no path to goal

Clear example:
- `Woman 2` sequence: `dw_debug.log:17263-17289`

### Two remaining state-ish failures

1. `Guard 8`
- `dw_debug.log:17036`
- still labeled `command_timing_or_state_issue`
- suspects: `14,5|15,5|17,6`

2. `Stairs Down to Throne Room`
- `dw_debug.log:18777`
- still labeled `command_timing_or_state_issue`
- suspects: `15,3|15,2|15,1|8,3|14,3`

## Important interpretation

`(17,6)` still does **not** look safe to promote immediately to permanent map
data, even though it dominates the new survey failures.

Why:
- the direct manual suspect probe from `(17,5)` to `(17,6)` **moved**
  successfully earlier in the session (`dw_debug.log:20146`)
- this survey run also contains at least one successful reroute that later
  traverses out of `(17,5)` and recovers after initially citing `17,6`
  (`Stairs Up to Tantegel Castle Throne Room`, `dw_debug.log:4617`)

So the evidence now points to:
- a **narrow residual execution/state issue** around the `(17,5)->(17,6)` step,
  or
- a highly noisy seam,
not yet a clean permanent directional wall candidate.

## Recommended next step

Do **not** patch `["17,6"] = {north=true}` yet.

Best next diagnostic:
- run one or two focused single-target or path-debug tests that start at `(17,5)`
  and require the first step `(17,5)->(17,6)`, for example:
  - `survey_target:Woman 2,park_npcs`
  - `debug_pathfind_adjacent:27,5`
  - `report_path_state`

Goal:
- determine whether `(17,6)` is a real intermittent seam, or whether the survey
  route/execution logic is mishandling that first southward step from `(17,5)`
