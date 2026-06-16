# Current Investigation Scratchpad

Updated: 2026-06-15

This file is the temporary scratchpad for the active Garin's Grave work. Older
line-by-line probe transcripts were compacted on 2026-06-15; durable route
facts are in `session_handoff.md`, `PLAYTESTING.md`,
`project_resources/maps/garins_grave/README.md`, and the dated handoff archive.

## Active Target

- Current unresolved gameplay target: B3 west chest / likely Cursed Belt at
  `(1,1)`.
- Most important next live check: after manual FCEUX Lua reload, stand on the
  B3 NW/top-row side and run:
  - `debug_pathfind_to:1,1`
  - `pathability_filter:reachable`
  - `current_object`

## Current Emulator Rule

- FCEUX is the normal gameplay and agent-driven runtime.
- BizHawk is opt-in for explicit automation/debug/reload/profiling work only.
- Do not steer normal Garin's Grave route work back to BizHawk just for agent
  convenience; the lag slows route/seam testing too much.

## Durable Garin's Grave Facts

- B3 top-row false boundary:
  - live movement proved `(9,0)<->(10,0)` is bidirectionally passable
  - `map_reader.lua` has scoped B3 passthroughs for `(9,0)` and `(10,0)`
  - `test_map_reader.lua` covers both passthrough cells and the route from
    `(10,0)` to west chest `(1,1)`
- B2 from `Stairs Up` `(11,2)`:
  - reaches `Stairs Up`, `Northeast Stairs Down`, `Southeast Stairs Down`, and
    `Southwest Stairs Down`
  - current permanent model returns `No path found` for `Northwest Stairs Down`
    `(1,1)` and `Central Stairs Down` `(5,6)`
- B3 southeast-stair component:
  - does not route to west chest `(1,1)`
  - reachable-object filter reports only local `Southeast Stairs Up`
- B3 northeast-stair and southeast/up pockets:
  - pruned to local return stair only after same-origin live blocker evidence
- B3 lower-stair / Silver Harp side:
  - route to chest `(13,6)` and back to `Lower Stairs Down` `(10,9)` is stable
  - the save already had Silver Harp when the chest was opened
- B4 connector:
  - west/east stair connector remains stable both directions

## Evidence Rules To Keep

- Promote permanent map data only from clean normal-walked route evidence plus
  same-origin `probe_edge` agreement when possible.
- Treat battle, menu/dialogue, stale queued commands, teleport seed state,
  explicit-origin verifier artifacts, and FCEUX `LeftAlt` latch noise as
  contamination until disproven.
- `low_exit_count` and isolated-start survey failures are start-tile viability
  warnings, not direct proof that the target is blocked.
- B2 is an intended six-stair hub. Do not seal extra stair objects just to
  shorten object lists.
- Player-facing internal stair labels should stay spoiler-safe: use spatial
  labels plus visible `Up`/`Down`, not exact destination floors.

## Recent Tooling Cleanup

- Edge-flow command starters now share `edge_flow_guard.lua`.
- `probe_edge`, `probe_edge_verify`, `probe_edge_after_raw`, and
  `probe_edge_after_raw_to` refuse while any edge probe/verifier/seeded probe
  state is active.
- Regression coverage lives in `test_edge_flow_guard.lua`.

## Where To Look For Detail

- Current restart summary: `session_handoff.md`
- Active gameplay/playability notes: `PLAYTESTING.md`
- Garin's Grave map orientation and route summary:
  `project_resources/maps/garins_grave/README.md`
- Historical full evidence:
  `handoff_archive/HANDOFF_2026-06-07_garins_grave_b2_b3_wrapup_full.md`
