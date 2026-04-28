# Handoff 2026-04-24 — Map 0x04 overnight parked-NPC survey analysis

## What happened

The user ran an overnight `survey_objects:park_npcs` survey on map `0x04`.
The fresh `dw_debug.log` started at `2026-04-24 00:05:02` and contains only
two queued commands before the survey:

```text
CMD: teleport_to:10,10
CMD: survey_objects:park_npcs
```

There is no configured Git remote in this checkout, so there was nothing to
network-pull; the relevant artifact was the local `dw_debug.log`.

## Survey result

The run completed cleanly:

```text
SURVEY_COMPLETE run=1 map=0x04 targets=11 successes=3 failures=8 no_route=0 gated_or_isolated=5 movement_failed=0 suspected_engine_blocked=2 state_issues=1 adjacency_issues=0
```

Target-level results:

- Successes:
  - `stair_7_7` — Stairs Up to Tantegel Castle Throne Room
  - `door_10_30` — Door
  - `exit_11_29` — Exit to World Map
- Gated/isolated from `(8,7)`:
  - `chest_2`, `chest_3`, `chest_1`, `chest_0`, `npc_1` Guard
- Suspected engine-blocked:
  - `npc_3` Old Man — failed at `(17,5)`, suspected `17,6`
  - `stair_29_1` Stairs Down to Treasure Room — failed at `(17,5)`, suspected `17,6`
- State/timing issue:
  - `stair_1_1` Stairs Down to Throne Room — failed at `(16,3)`, suspected
    `15,3|8,3|14,3|15,1|15,2`

Failure-start summary:

```text
SURVEY_FAILURE_START map=0x04 start=(8,7) failures=5 ... gated_or_isolated=5 targets=Chest|Chest|Chest|Chest|Guard
SURVEY_FAILURE_START map=0x04 start=(17,5) failures=2 ... suspected_engine_blocked=1 state_issues=1 targets=Stairs Down to Throne Room|Stairs Down to Treasure Room
SURVEY_FAILURE_START map=0x04 start=(10,29) failures=1 ... suspected_engine_blocked=1 targets=Old Man
```

## Route-manager regression signal

The previous bad orphan behavior did **not** recur.

Important negative check:
- no `route_inactive_without_completion`
- no observed reversion to the old orphaned route result

For `17,6`, the seam-bruteforce path now behaves as intended:

```text
SEAM_BRUTE_FORCE map=0x04 from=(17,5) dir=down dest=(17,6) attempt=1/2
SEAM_BRUTE_FORCE map=0x04 from=(17,5) dir=down dest=(17,6) attempt=2/2
SURVEY_RESULT ... target_name="Old Man" ... reason=reroute_no_path
```

This supports the 2026-04-23 `route_manager.lua` fix: blocked seam retries now
stay inside reroute handling and cancel cleanly rather than orphaning surveys.

## Blocker evidence from this run

Confirmed by runtime seam accumulation in this survey:

- `(17,6)` north approach:
  - blocked as queued route, then blocked twice as seam-bruteforce/manual retry
  - reached `classification=confirmed_blocked`
  - caused failures for Old Man and Stairs Down to Treasure Room
- `(8,3)` south approach:
  - reached `classification=confirmed_blocked`
- `(14,3)` south approach:
  - reached `classification=confirmed_blocked`
- `(15,1)` east approach:
  - reached `classification=confirmed_blocked`
- `(15,2)` east approach:
  - reached `classification=confirmed_blocked`
- `(15,3)` south and east approaches:
  - both reached `classification=confirmed_blocked`

## Interpretation

Do **not** immediately promote these new overnight runtime confirmations into
permanent `map_reader.lua` directional blocks.

Reason:
- The 2026-04-23 direct suspect-probe campaign showed clean movement through
  `(17,6)` north and through the throne-room reroute suspect set
  `(8,3) south`, `(14,3) south`, `(15,3) south/east`, `(15,2) east`,
  `(15,1) east`.
- The overnight survey contradicts that direct-probe evidence, so this is now a
  noisy-seam / route-execution question, not a safe map-data patch.

The one strong positive result is that the old `(18-21,4-6)` false-open cluster
does not appear as a failure source after the five 2026-04-23 map-data patches.

## Next recommended work

Focus on reproducibility before permanent map data:

1. Re-run direct `probe_edge` checks for the contradictory seams from controlled
   starts, especially `(17,5)->DOWN->(17,6)`.
2. Re-probe the throne-room route seams from exact adjacent starts:
   `(8,4)->UP->(8,3)`, `(14,4)->UP->(14,3)`,
   `(16,1)->LEFT->(15,1)`, `(16,2)->LEFT->(15,2)`,
   `(15,4)->UP->(15,3)`, and `(16,3)->LEFT->(15,3)`.
3. Do not batch `teleport_to` with `probe_edge`; confirm position first.
4. If direct probes still pass while survey walking blocks, investigate
   `auto_step` / route execution timing around turns and re-presses instead of
   patching `map_reader.lua`.
