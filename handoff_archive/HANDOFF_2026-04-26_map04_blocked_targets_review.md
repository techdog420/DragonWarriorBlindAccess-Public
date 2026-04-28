# Handoff 2026-04-26 - Map 0x04 blocked-target review

## Context

After the clean post-catch-up parked survey:

```text
SURVEY_COMPLETE run=1 map=0x04 targets=28 successes=14 failures=14 no_route=0 gated_or_isolated=14 movement_failed=0 suspected_engine_blocked=0 state_issues=0 adjacency_issues=0
SURVEY_CANDIDATES map=0x04 none
SURVEY_STRONG_CANDIDATES map=0x04 none
SURVEY_CANDIDATE_SUGGESTIONS map=0x04 none
PATH_STATE ... runtime_count=0
```

the user asked whether the remaining blocked targets are intended for this game
state, especially the east-wing targets.

## Important correction

The prior session handoff and `map_reader.lua` comments said "east-wing targets
are reachable without magic keys" via the x=5 decoder-gap bypass. That was too
broad.

The x=5 bypass reaches the y=4 east connector, but it does **not** prove the
far-east/upper-east target cluster is reachable. The confirmed east-wall seams
`21,4 west` and `21,5 west` still separate the cluster beyond x=21.

`map_reader.lua` and `session_handoff.md` were updated to say this explicitly.

## Focused checks

A normal `debug_pathfind_adjacent` check includes live NPC blockers, so the
authoritative recheck used single-target parked surveys from `(10,8)`, matching
the clean survey conditions.

Commands used:

```text
teleport_to:10,8
survey_target:npc_9,park_npcs
survey_target:npc_10,park_npcs
survey_target:Woman 2,park_npcs
```

Results:

```text
SURVEY_RESULT run=2 ... target_id=npc_9  target=(26,21) path_found=false final=(10,8) failure_class=no_route_found blocked_events=0 reason=no_path
SURVEY_RESULT run=3 ... target_id=npc_10 target=(24,1)  path_found=false final=(10,8) failure_class=no_route_found blocked_events=0 reason=no_path
SURVEY_RESULT run=4 ... target_id=npc_11 target=(27,5)  path_found=false final=(10,8) failure_class=no_route_found blocked_events=0 reason=no_path
```

There were no runtime blocks and no candidate suggestions associated with these
checks.

## Current read

- West/southwest chest failures remain expected gated/isolated outcomes for the
  current closed-door/current-map state.
- Far-east targets `npc_9`, `npc_10`, and `npc_11` are also currently clean
  no-path under parked-NPC conditions.
- This looks like real topology/gating/isolation, not bad probe data.
- Do not patch map data for these targets unless manual gameplay proves a
  missing opening. The likely places to recheck if new evidence appears are the
  already-confirmed connector seams `21,4 west`, `21,5 west`, and the
  `17..20,6 north` band.
