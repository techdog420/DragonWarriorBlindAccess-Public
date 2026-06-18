# Current Investigation Scratchpad

Updated: 2026-06-17

No active investigation is in progress.

Garin's Grave route decoding wrapped on 2026-06-17. The detailed live evidence
from the final Cursed Belt, B2 escape, B1 cleanup, and `auto_walk_blocker`
passes has been archived here:

- `handoff_archive/HANDOFF_2026-06-17_garins_grave_final_scratchpad.md`
- `handoff_archive/HANDOFF_2026-06-17_garins_grave_final_wrapup_full.md`

Use `session_handoff.md`, `PLAYTESTING.md`, `PROJECT_MEMORY.md`, and
`project_resources/maps/garins_grave/README.md` for durable current state.

For the next live map task, start a new dated section here with:

- current map id, floor, and player position
- exact target/object being investigated
- runtime blockers injected during the session
- evidence that is still uncertain or should not be promoted
- evidence that has been promoted to permanent map data

## 2026-06-17 Garinham Grave Stairs / Inn Route

### Target

- Map `0x09` Garinham, starting from grave-return stairs `(19,0)`.
- Find a viable route to the public inn stand `(15,15)` and back toward the
  grave route.

### Baseline

- Fresh command polling confirmed with `launcher_probe:codex_grave_resume`.
- Position: `POSITION: map=0x09(Garinham) x=19 y=0`.
- Door state: `DOOR_STATE keys=5 slots=0=(17,10)`.
- Runtime overlay before new work: `(14,1).east`, `(4,2).west`,
  `(17,14).north`.
- With the current loaded map model, `debug_pathfind_to_skip_npcs:15,15`
  reports `No path found`; frontier reaches only 7 top-lane tiles.

### Working Hypothesis

- The grave-return pocket may not have an in-town path to the inn. A viable
  route may need to leave through the top-edge world-map transition around
  `(18,0)`, then re-enter Garinham from the normal west entrance before routing
  to the inn.

### Live Results

- Forward escape to the inn is viable through the world map:
  - From `(19,0)`, route/walked to the top lane and used `(18,1)->RIGHT`.
  - Log showed map transition to `0x01` / World Map at `(2,2)`.
  - `start_overworld_route:garinham` plus `auto_walk` reached `(1,2)`.
  - `probe_edge:RIGHT` re-entered Garinham at `(0,14)`.
  - `auto_walk:15,15` from `(0,14)` reached the public inn stand.
- Inn-route cleanup candidates from that completed forward route:
  - `(14,16).west` and `(14,17).west` each produced one blocked-only seam
    observation during reroute.
  - They were not same-origin re-probed, so do not promote them yet.
- Return from inn to grave stairs is not currently viable:
  - From inn `(15,15)`, planner chose `Path: 4 north, 4 east, 11 north` to
    `(19,0)`.
  - Live auto-walk failed at `(19,11)->UP` into `(19,10)` with blocked-only
    seam evidence, then no reroute.
  - Same-origin `probe_edge:UP` from `(19,11)` also blocked. This supersedes
    the older teleport-backed verifier claim that `(19,10)` was passable.
- With the door slot `(17,10)` temporarily seeded open and the bad
  `(19,10).south` bridge blocked at runtime, the remaining candidate bridges
  were walked to and probed:
  - Row-10 family: `(18,11)->UP`, `(18,9)->DOWN`, and `(17,10)->RIGHT` all
    blocked.
  - Top/dark-wall family: `(13,1)->DOWN` and `(13,1)->RIGHT` blocked.
  - West boundary strip: `(12,3)->RIGHT`, `(12,4)->RIGHT`, `(12,5)->RIGHT`,
    and `(12,6)->RIGHT` blocked.
  - Row-7/8/9 gates: `(13..18,7)->UP`, `(18,7)->RIGHT`,
    `(18,8)->RIGHT`, and `(18,9)->RIGHT` blocked.
  - After runtime-blocking the verified false row-10/`(13,1)->DOWN` bridges,
    `debug_route_frontier_skip_npcs:19,0,80` reported
    `hidden_bridge_candidates=0`.

### Promoted

- Removed stale `MAP_PASSTHROUGH_CELLS[0x09]["19,10"]`.
- Updated `test_map_reader.lua` so the Garinham dark-wall fixture keeps
  `(19,10)` as a live-matching type-2 wall instead of a passthrough.

### Still Unpromoted

- Route-shaped blocked-only observations from the attempted route to `(13,1)`:
  `(6..10,2).south` and `(6,4).north/east`.
- Forward inn-route bumps at `(14,16).west` and `(14,17).west`.
- These are good candidates for a later focused pass, but they were only used
  as runtime search pruning in this session.

### Cleanup State

- Diagnostic opened-door seed cleared with `debug_seed_open_doors:clear`.
- Runtime blocked edges cleared with `clear_blocked_tiles`.
- Final live snapshot: `DOOR_STATE keys=5 slots=0=(0,0) ...`,
  `RUNTIME_BLOCKS map=0x09 none`, `POSITION: map=0x09(Garinham) x=18 y=8`.

## 2026-06-18 Garinham Door Survey

### Research

- External map/guide pass found that Garinham has three locked doors overall:
  two on 1F and one in Garinham B1.
- Gamer Corner lists the 1F doors as "East end of town" and "Inside locked
  building"; B1 is dungeon scope.
- Realm of Darkness says the Grave of Garinham entrance is inside the grey
  building and that two guards are behind the locked door inside that building.
- Treat these as orientation only; live OPEN/door RAM still controls permanent
  `MAP_DOOR_CELLS` updates.

### Live State

- Clean baseline after user manual navigation:
  `POSITION: map=0x09(Garinham) x=3 y=11`,
  `DOOR_STATE keys=6 slots=0=(0,0) ...`,
  `RUNTIME_BLOCKS map=0x09 none`, menu/dialogue closed.
- Later cleanup after route probing:
  `POSITION: map=0x09(Garinham) x=8 y=12`,
  `DOOR_STATE keys=6 slots=0=(0,0) ...`,
  `RUNTIME_BLOCKS map=0x09 none`.
- User manual door find follow-up:
  `POSITION: map=0x09(Garinham) x=4 y=5`,
  `DOOR_STATE keys=5 slots=0=(4,6) ...`,
  `RUNTIME_BLOCKS map=0x09 none`.
- Pocket follow-up from the same live state:
  `NPC_SLOT ... Guard 2 x=3 y=5 ... move=0x00` and
  `NPC_SLOT ... Guard 3 x=5 y=5 ... move=0x00`, so the side exits from
  `(4,5)` are stationary guard blocks, not map-wall evidence.
- Raw north probe from `(4,5)`:
  `EDGE_PROBE_RESULT map=0x09 from=(4,5) dir=up dest=(4,4) status=blocked
  final=(4,5) ... npc_blocked=false ... reason=raw_hold_timeout`, followed by
  `EDGE_PROBE_MODEL_MISMATCH ... kind=blocked_despite_open_preview`.
  This confirms the north face of the pocket is an engine block that the model
  currently treats as open.
- Raw south probe from `(4,5)`:
  `EDGE_PROBE_RESULT map=0x09 from=(4,5) dir=down dest=(4,6) status=moved
  final=(4,7) ... reason=position_changed`, with `EDGE_PROBE_CARRY` logging
  the carry through to `(4,7)`. Final snapshot:
  `POSITION: map=0x09(Garinham) x=4 y=7`,
  `DOOR_STATE keys=5 slots=0=(4,6) ...`, `RUNTIME_BLOCKS map=0x09 none`.

### Pinned Doors / Candidates

- Confirmed existing 1F outer/grave-route door:
  - Door cell `(17,10)`.
  - Previously opened from `(17,9)` facing south; door RAM recorded `(17,10)`.
  - Current live inspect still reports
    `TILE map=0x09 x=17 y=10 ... reason=door_closed`.
- Confirmed 1F inside-grey-building door:
  - Door cell `(4,6)`.
  - Fresh door-RAM proof after the user found the door:
    `DOOR_STATE keys=5 slots=0=(4,6)`.
  - South-side OPEN/approach stand is `(4,7)` facing north. After opening, the
    player can pass through `(4,6)` into the interior pocket at `(4,5)`.
  - The interior pocket is real local engine behavior, not just a model guess:
    north from `(4,5)` blocks into `(4,4)`, west/east are occupied by stationary
    guards at `(3,5)` and `(5,5)`, and south exits back through the opened door.
  - Reasoning: live NPCs place the two guide-mentioned guards at `(3,5)` and
    `(5,5)`, with the candidate door between/south of them; 1F locked-building
    chests are at `(8,5)`, `(9,5)`, and `(8,6)`.
  - It decodes as ordinary walkable floor, so model it as a floor-backed engine
    door like the Rimuldar inn doors rather than a wall-backed door like
    `(17,10)`.
- Disproved old east-end guess remains disproved:
  - `(19,16)` should stay out of `objects.lua` / `MAP_DOOR_CELLS[0x09]`.

### Route Notes

- `debug_pathfind_to:4,7` from `(3,11)` initially planned a path, but live
  `auto_walk:4,7` looped/rerouted on false seams instead of reaching the stand.
- During that attempted route, live movement repeatedly blocked:
  - `(14,10)->RIGHT` into `(15,10)`.
  - `(4,13)->UP` into `(4,12)`.
- Temporary runtime edge blocks for those two seams made both `(17,9)` and
  `(4,7)` no-path from the current `(8,12)` position. The runtime blocks were
  cleared before stopping.
- Do not promote the two seam blocks solely from this route attempt; they are
  useful next candidates, but the immediate door-survey result is coordinate
  pinning plus the need for actual OPEN proof.

### Promoted

- `MAP_DOOR_CELLS[0x09]["4,6"]` models the inner locked-building door as a
  floor-backed engine door.
- `objects.lua` exposes that door as `Locked Building Door`, routing to the
  `(4,7)` south-side stand facing north.
- `MAP_DIRECTIONAL_BLOCKS[0x09]["4,4"].south` closes the false north exit from
  the guard pocket after the same-origin raw probe from `(4,5)->UP`.
- `test_map_reader.lua` covers the inner door RAM behavior and pocket blocker;
  `test_objects.lua` covers the door object and interaction stand.

### Remaining Caution

- `(4,5)` is the post-door interior pocket and should not be treated as a useful
  through-route toward the grave stairs unless later gameplay moves the guards
  or proves another event opens this trap.
