# Rimuldar Magic Key Route Correctness Design

Date: 2026-07-15
Status: Approved design; static route repair complete; live executor amendment
awaits written-spec review

## Goal

Make source-only navigation route from Rimuldar's normal east entry `(29,14)`
to the Magic Key Merchant's real interaction stand `(4,5)`, face south, and
open the 53 G shop prompt without teleporting or adding runtime blockers.

## Verified Baseline

Normal FCEUX movement proved this route on map `0x0B`:

1. North along `x=29` from `(29,14)` to `(29,2)`.
2. West along row 2 to `(21,2)`.
3. North to `(21,0)`, then west along `y=0` to `(0,0)`.
4. South along `x=0` to `(0,3)`.
5. East across bridge `(1,3)->(2,3)`.
6. Around fixed `Merchant 1` at `(2,4)` through
   `(3,3)->(4,3)->(5,3)->(5,4)->(5,5)->(4,5)`.
7. TALK south from `(4,5)` across counter `(4,6)` to seller `(4,7)`.

Entering `x=0` horizontally below `y=0` changes to the World Map. Therefore
the route must enter `(0,0)` from `(1,0)` before descending. `(4,5)->DOWN`
correctly blocks because raw block `0xF` at `(4,6)` is the counter.

The full top row is not a valid live-NPC shortcut. A normal self-review pass
crossed through `(26,0)`, then `(26,0)->RIGHT` blocked with
`npc_blocked=true` because fixed `Person 4` occupies `(27,0)`. The row-2 /
`x=21` jog above is therefore part of the required route.

After the shop proof and upper-route audit, the final live state was entry
`(29,14)`, menu/dialogue closed, six keys, and
`RUNTIME_BLOCKS map=0x0B none`.

## Live Acceptance Findings

The corrected source plans a 52-step route from `(29,14)` to `(4,5)`:

- 12 north;
- 8 west;
- 2 north;
- 21 west;
- 3 south;
- 4 east;
- 2 south.

The first source-only autowalk followed that route until `(1,0)->LEFT`, where
the normal attempt and both seam retries failed to enter `(0,0)`. The planner
still reported the edge passable, no NPC occupied either endpoint, and
`RUNTIME_BLOCKS map=0x0B none` remained true.

Raw input calibration isolated the difference: an uninterrupted 64-frame
RIGHT hold moved `(1,0)->(5,0)`, and an uninterrupted 80-frame LEFT hold moved
`(5,0)->(0,0)`. The edge is therefore passable through normal movement, but
the engine requires the westbound top-bank run to remain continuously held.
The queued executor currently inserts neutral input, a four-frame cooldown,
and a forced post-step release after every crossed tile.

Starting from `(0,0)`, the remaining nine-step autowalk reached `(4,5)`. Its
last seam retry succeeded, but the seam-retry destination branch published
route completion and cleared route context without running the normal arrival
path. It consequently skipped the target-facing and completion behavior.
After a manual one-frame DOWN face, TALK opened the verified `53 GOLD?` Magic
Key prompt. These findings add an executor amendment to the approved static
map, planner, and service design; they do not change the decoded route.

## Root Causes

Five independent source assumptions combine to break routing and execution:

1. `map_reader.lua` describes and expands interior map bytes as nibble RLE.
   The ROM instead stores two block IDs per byte. When map pointers are sorted
   by ROM address, all 27 consecutive interior-map spans equal
   `ceil(width*height/2)`. Rimuldar occupies exactly 450 bytes from `$8B62` to
   `$8D24`, equal to `30*30/2`.
2. Generic `engine_boundary` handling rejects every `x=0` or `y=0` cell, but
   Rimuldar's intended outer bank deliberately uses both boundaries.
3. `SERVICE_INTERACTION_OVERRIDES[0x0B]["4,7"]` targets counter `(4,6)` as the
   player stand. The live stand is `(4,5)` facing south.
4. Queued movement always releases and represses the D-pad after each tile.
   Rimuldar's westbound top-bank entry into `(0,0)` requires uninterrupted
   input across the straight run leading to that edge.
5. A successful seam retry that lands directly on the route destination uses
   a shortened completion branch. That branch bypasses the standard final
   facing, settle, and completion-speech behavior.

## Approaches Considered

### Chosen: staged correctness repair

Correct the shared packed-nibble reader first, model only the live-proven
Rimuldar outer route and transition direction, correct the service stand, and
then add an end-to-end regression. This fixes the real data contract and keeps
Rimuldar-specific engine behavior map-scoped.

Trade-off: correcting a shared decoder can expose stale assumptions on other
maps. The implementation must run the full Lua suite and investigate each
failure instead of adding speculative broad passthroughs.

### Rejected: Rimuldar-only passthrough patch

Leave the decoder unchanged, add every route coordinate as a passthrough, and
correct only the service stand. This has a smaller immediate blast radius but
preserves a known global decoder defect and makes future map work less reliable.

### Rejected: documentation-only route

Keep the manual route in project notes without changing navigation. This is
safe but leaves a progression-critical service unreachable through autowalk.

## Design

### 1. One packed-nibble data path

Introduce one internal block reader used by both `decompress_map()` and
`get_raw_block_id()`:

- `tile_index = y * width + x`
- `byte_offset = data_ptr + floor(tile_index / 2)`
- even `tile_index`: high nibble
- odd `tile_index`: low nibble

Linear indexing matters for odd-width maps; row-padded indexing would consume
more bytes than the pointer spans permit. `decompress_map()` will fill the grid
left-to-right and top-to-bottom using exactly `width*height` nibbles. Existing
overworld behavior remains unchanged.

The implementation will retain nil/out-of-range handling and will update stale
RLE comments. No new public API is required.

### 2. Map-scoped Rimuldar outer-bank model

Represent the live route as explicit map `0x0B` passability, using the existing
per-map override infrastructure before the generic boundary check:

- east strip `(29,2..14)`;
- upper lane `(21..29,2)`;
- vertical connector `(21,0..2)`;
- top-bank terrain `(0..29,0)`, including both sides of fixed NPC `(27,0)`;
- far-left bank `(0,1..3)`;
- bridge/landing cells `(1,3)`, `(2,3)`, and `(3,3)` as needed after correct
  raw decoding.

Add east-approach directional guards on `(0,1)`, `(0,2)`, and `(0,3)`. These
prevent A* from entering `x=0` horizontally at rows that transition to the
World Map while preserving north/south travel down the bank. Entry into
`(0,0)` from `(1,0)` and bridge travel from `(0,3)` to `(1,3)` stay open.

Do not add or promote `(2,8).west`; it is unrelated to the valid route.
The whole top-bank terrain remains walkable, but the route must not pass
through fixed NPC `(27,0)`. Normal NPC blocking, rather than an artificial
terrain closure, must keep the planner on the proven row-2 / x=21 jog.

### 3. Correct service geometry

Change the Rimuldar Magic Key override to interaction `(4,5)`, facing south.
Keep seller `(4,7)` movement-blocking. Correct packed decoding naturally makes
raw-`0xF` counter `(4,6)` globally non-walkable; remove the stale test/comment
that requires its north approach to be open. Do not replace it with a
directional block unless separate live evidence requires one.

The generic service-routing and visited-NPC plumbing already consumes the
interaction override and requires no logic change.

### 4. Deterministic route behavior

The route goal is `(4,5)`, not adjacency to seller `(4,7)` and not counter
`(4,6)`. Planning from `(29,14)` must use the row-2 / x=21 outer-bank jog and
real bridge, avoid fixed NPCs `(27,0)` and `(2,4)`, never require
`(1,8)->(2,8)`, and finish facing south.

No quest flag, opened door, teleport state, or runtime block is part of route
eligibility. Movement cadence is an execution requirement for one verified
Rimuldar boundary, not a planner eligibility rule.

### 5. Map-scoped continuous-run execution

Add explicit, map-scoped metadata for cadence-sensitive entries. Rimuldar map
`0x0B` marks entry into `(0,0)` from the east. Keep `auto_step.lua` generic and
coordinate-free: `route_manager.lua` translates a planned path containing a
marked entry into per-boundary `continuous_hold_after_steps` options.

For a marked entry, walk backward through the contiguous same-direction run
and mark each internal tile boundary in that run. This keeps the entire
westbound approach continuously held rather than releasing only one tile
before `(0,0)`. The executor retains the existing flat per-tile queue and must
still publish exactly one `route_step_completed` event for every crossed tile.

At a marked internal boundary, when the next queued direction is identical,
the executor will:

- update the completed-tile coordinates and per-tile watchdog state;
- publish that tile's normal completion event;
- validate the next step and any hazard refusal;
- consume and begin the next same-direction step in the same frame;
- omit neutral input, cooldown, and forced post-step release only at that
  marked boundary.

All safety behavior remains mandatory. If the next direction changes, the
route ends, the completion callback clears or replans the route, a hazard is
refused, or cancellation occurs, input neutralizes through the existing safe
path. In particular, the final west tile releases normally at `(0,0)` before
the route turns south, preventing an extra west input from triggering the
World Map transition. Ordinary routes and unmarked boundaries retain current
release timing.

The marker is route/path data, not merchant-specific state. Every fresh plan,
reroute, or seam-followup recomputes its markers from the map metadata and
actual path. Do not overload `settle_same_direction=false`; survey-safe routes
already use that option for a different purpose.

Log entry into, continuation of, and exit from a continuous run with map,
origin, destination, direction, and route-step index. Existing blocker,
timeout, cancellation, hazard, and progress logs remain intact.

### 6. One standard arrival path

Extract or reuse one route-manager arrival helper for both ordinary completion
and a successful seam retry that lands on the destination. The helper must
capture the active target and facing direction before clearing route context,
perform the normal final neutral/settle behavior, face south at the merchant
stand, and issue the usual completion feedback.

Per-tile completion and route arrival remain separate events: exactly one
`route_step_completed` event is emitted for the final tile, followed later by
exactly one route-complete event. A seam retry must neither double-complete nor
discard the target context needed for facing.

## Test Strategy

Implementation follows red-green-refactor. Each production change requires a
failing regression first.

### Packed decoder tests

- A synthetic even-width map proves high/low nibble order in the grid.
- A synthetic odd-width map proves continuous linear indexing across a row
  boundary for both `decompress_map()` and `get_raw_block_id()`.
- Rimuldar fixture bytes prove bridge `(1,3)=0xE`, stand `(4,5)=0x6`, and
  counter `(4,6)=0xF`.

### Rimuldar passability tests

- The east strip, row-2 upper lane, x=21 connector, full top-bank terrain, and
  left-bank route cells are effectively walkable.
- `(0,1..3).east` blocks horizontal entry from `(1,y)`.
- `(0,1..3).north` and `.south` stay unset/open for vertical bank travel.
- `(0,0).east` stays open, and `(0,3)->RIGHT` across the bridge stays open.
- Live NPC `(27,0)` prevents the planner from choosing a full-top-row shortcut.
- Counter `(4,6)` is globally non-walkable, including from `(4,5)`.

### Object/service tests

- Magic Key Merchant exposes interaction `(4,5)`, facing south.
- Visiting/TALKing from `(4,5)` marks the seller visited.
- Seller `(4,7)` remains a movement blocker; greeting NPC `(2,4)` remains
  outside Services.

### End-to-end route regression

Add a pathfinder integration test that uses real `pathfinder.find_path`, real
`map_reader` ROM fixture data, and explicit NPC blockers `(27,0)`, `(2,4)`, and
`(4,7)`. Planning from `(29,14)` to `(4,5)` must avoid those NPCs and counter
`(4,6)`, include the row-2 / x=21 jog and outer-bank bridge `(1,3)`, and reach
the stand. Keep this separate from a route-manager test that asserts the
selected service goal is `(4,5)` with south-facing interaction state; the
existing route-manager tests stub pathfinding and cannot prove map integration.

### Continuous-run executor tests

- A route with an explicitly marked straight-run boundary proves there is no
  neutral frame between the marked same-direction steps.
- The same route proves one direction sequence and exactly one
  `route_step_completed` event per tile.
- A turn immediately after the marked run proves neutral release before the
  new direction and no old-direction overshoot.
- A route ending after a marked run proves normal final neutralization.
- Blocker reporting after multiple continuously held tiles identifies the
  correct current origin and attempted destination.
- Opposite-direction input still cancels immediately.
- Hazard refusal before the next tile neutralizes input and does not consume
  that unsafe step.
- An otherwise identical unmarked route retains the existing forced release
  between tiles.

### Cadence metadata and arrival tests

- A synthetic Rimuldar path ending in the east approach to `(0,0)` marks only
  the internal boundaries of its contiguous westbound run.
- Turns, the final entry tile, unrelated straight runs, other maps, and paths
  that do not cross the marked edge remain unmarked.
- A successful seam retry that lands on `(4,5)` emits one final step event and
  one route-complete event, preserves the Magic Key target, faces south, and
  produces the standard completion feedback.
- Existing survey-safe seam completion remains unchanged.

### Verification commands

Run focused map-reader, object, pathfinder, and route-manager suites first,
then every repository Lua test and `luac -p` over changed Lua files. Capture
the injected-input waveform in executor tests so continuous means no neutral
frame, not merely a shorter delay. The final live check requires a manual
FCEUX Lua reload, `RUNTIME_BLOCKS map=0x0B none`, normal entry `(29,14)`, one
source-only autowalk to `(4,5)`, standard south-facing arrival, and the 53 G
prompt.

## Failure Handling

- If packed decoding breaks unrelated tests, classify each failure as a stale
  decoder expectation, a legitimate live override, or an unresolved map fact.
- Do not weaken tests or add broad passthrough ranges merely to restore green.
- If an unrelated map needs new live evidence, stop that part of the decoder
  rollout and report the exact map/cell rather than guessing.
- If FCEUX does not consume commands after source edits, manually reload
  `main.lua`; if polling remains stale, relaunch with `./launch_dw.sh`.
- Keep runtime/test-only blocks separate from permanent map data throughout
  live verification.
- If continuous execution loses route context, encounters a refused hazard, or
  sees a different next direction, fail closed by neutralizing input and using
  the existing release/replan behavior.
- Never infer continuous execution merely from adjacent equal directions;
  require explicit map/path metadata so ordinary routes retain their proven
  anti-overshoot timing.

## Scope Boundaries

Included:

- packed interior-map decoding;
- Rimuldar outer-bank passability and transition direction;
- Magic Key Merchant interaction geometry;
- focused and end-to-end regressions;
- map-scoped cadence metadata and generic per-boundary executor support;
- standard arrival handling after a destination seam retry;
- stale source comments directly describing this route.

Excluded:

- unrelated Rimuldar inn/Wings routes;
- broad cleanup of historical per-map overrides;
- promotion of `(2,8).west`;
- a global continuous-hold default or merchant-specific executor flag;
- fake blockers, teleports, or quest-state gates for the `(0,0)` seam;
- emulator launcher or desktop-control automation.

## Acceptance Criteria

1. Focused and full Lua tests pass after demonstrating the new regressions fail
   on the pre-fix source.
2. `git diff --check` and Lua syntax checks pass.
3. The planner selects `(4,5)` facing south for the Magic Key Merchant.
4. One source-only live autowalk reaches `(4,5)` from `(29,14)` via the row-2 /
   x=21 jog, uninterrupted top-bank run into `(0,0)`, and bridge `(1,3)`.
5. The executor releases before turning south at `(0,0)`, never transitions to
   the World Map, and preserves per-tile progress/blocker/cancel safety.
6. A destination seam retry uses the standard arrival path, leaves the player
   at `(4,5)` facing south, and emits one route-complete result.
7. TALK opens the 53 G key prompt with no runtime blocks.
8. Active handoff, playtesting, map notes, and durable project memory agree.
