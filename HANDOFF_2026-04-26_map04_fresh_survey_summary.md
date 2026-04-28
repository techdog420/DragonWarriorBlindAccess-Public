# Handoff 2026-04-26 - Map 0x04 fresh parked-NPC survey summary

## What happened

The user started a fresh `survey_objects:park_npcs` run on map `0x04` after
Claude's east-wing/door-band work. Codex picked up the session read-only while
the survey was near the final target, then requested post-survey status with:

```bash
./dw_commands.sh --replace report_position report_path_state report_survey_findings report_failed_targets
```

The survey completed before the report commands were consumed.

## Survey result

Summary from `dw_debug.log`:

```text
SURVEY_COMPLETE run=1 map=0x04 targets=29 successes=14 failures=15 no_route=0 gated_or_isolated=6 movement_failed=0 suspected_engine_blocked=0 state_issues=9 adjacency_issues=0
```

Failure starts:

```text
start=(3,8): 6 gated_or_isolated targets
start=(17,5): 4 state_issues
start=(20,4): 2 state_issues
start=(16,20): 1 state_issue
start=(11,27): 1 state_issue
start=(10,29): 1 state_issue
```

The six gated/isolated results were:

- four chests in the west/southwest pocket
- west-pocket guard
- `Stairs Down to Throne Room`

The nine state/timing failures were:

- `Guard 2`
- `Merchant 2`
- `Guard 8`
- `Woman 2`
- `Guard 5`
- `Merchant 3`
- `Old Man 1`
- `Old Man 2`
- `Stairs Down to Treasure Room`

## Runtime blockers left after survey

Post-survey `report_path_state` showed the player at `(17,5)` with
`runtime_count=6`:

```text
21,4(west)
21,5(west)
17,6(north)
18,6(north)
19,6(north)
20,6(north)
```

`report_survey_findings` also listed these same six as high-count strong
candidates (`count=13`, `targets=11`, `retry_successes=2`), plus smaller
reroute candidates `3,6(south)`, `4,7(west)`, and `6,13(west)`.

## Interpretation

Do not immediately promote the six high-count candidates back into permanent
`MAP_DIRECTIONAL_BLOCKS[0x04]`.

Reason:

- The current code/comment state says the `17..20,6 north` and `21,4/21,5 west`
  east-connector band was removed as false-positive data after NPC-free natural
  walk / stale-state follow-up.
- The new survey re-learned that same band as runtime blocks during queued route
  execution, while still classifying the affected targets as
  `command_timing_or_state_issue`, not `suspected_engine_blocked`.
- This keeps the current problem in the movement/state/queued-route bucket until
  controlled adjacent-start probes reproduce it outside the survey harness.

## Suggested next step

Run focused, split-command checks for the six repeated seams, with NPCs frozen
and runtime/seam memory cleared before the campaign. Do not batch `teleport_to`
with the follow-up movement/probe command.

Recommended first pair:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks clear_seam_cells teleport_to:17,5 report_position report_movement_state:before_17_5_down
./dw_commands.sh --replace probe_edge:17,5,DOWN
./dw_commands.sh --replace report_position report_movement_state:after_17_5_down
```

Then repeat for:

- `(18,5)->DOWN` into `18,6`
- `(19,5)->DOWN` into `19,6`
- `(20,5)->DOWN` into `20,6`
- `(20,4)->RIGHT` into `21,4`
- `(20,5)->RIGHT` into `21,5`

If direct probes move while surveys block, investigate queued route state or NPC
parking/freeze timing before changing permanent map data.
