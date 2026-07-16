# Rimuldar Magic Key Route Correctness Design

Date: 2026-07-15
Revised: 2026-07-16
Status: Revised executor design approved after live cadence calibration

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

The first calibration was misread as a continuous-hold requirement. Fresh
same-state trials disproved that model: an uninterrupted 80-frame LEFT hold
from `(5,0)` advanced only to `(1,0)` and then stalled. Releasing there and
pressing LEFT again entered `(0,0)`. Explicit two-press sequences showed the
threshold: neutral gaps of 8 and 12 frames still failed, while a 16-frame
neutral gap followed by a fresh LEFT press entered `(0,0)` and stayed in
Rimuldar. The edge is therefore passable through normal movement, but the
engine requires a settled release/repress before the final west step.

The source-only continuous-run implementation correctly propagated its
markers and kept LEFT asserted, but failed at `(1,0)->(0,0)` because it
preserved the exact stale movement state that must settle. Raising the generic
early-twitch watchdog from 32 to 60 frames did not help. Static source-order
review also ruled out a later Lua `joypad.set()` writer overwriting the input.

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
4. Ordinary queued movement releases for only its short generic cooldown.
   Rimuldar's westbound top-bank entry into `(0,0)` requires at least 16
   neutral frames at `(1,0)` before a fresh LEFT press.
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

### 5. Map-scoped settled re-press execution

Add explicit, map-scoped metadata for cadence-sensitive entries. Rimuldar map
`0x0B` marks entry into `(0,0)` from the east with `settle_frames=16`. Keep
`auto_step.lua` generic and coordinate-free: `route_manager.lua` translates a
planned path containing that entry into a per-step
`settle_before_steps[step_index]=16` option.

Only the destination-entry step is marked. The preceding westbound tiles use
ordinary per-tile execution. After the route completes `(2,0)->(1,0)`, the
executor keeps the next step queued and starts a fresh LEFT press only after
16 physical neutral frames. The tile-completion frame is already neutral, so
15 countdown frames remain after a normally completed prior step. A fresh
plan or reroute whose first step is `(1,0)->(0,0)` has no completion frame and
therefore waits all 16 frames before step 1. The existing flat per-tile queue
and exactly-one `route_step_completed` event per crossed tile remain
unchanged.

Implement this through the existing route-settle state rather than a second
input state machine. Extract a coordinate-free `begin_next_route_step()` from
the current continuous-hold helper before deleting that obsolete branch.
Per-step settle metadata takes the maximum of the normal settle requirement
and the marked entry's remaining countdown. The metadata is honored even on a
same-direction segment, on step 1, and when `settle_same_direction=false`,
because it describes a verified engine requirement rather than optional route
smoothing.

The existing forced two-frame post-step release runs before route-settle
processing. After a prior tile completes and its completion callback returns,
a marked later step clears that redundant release only if the same route table
and next-step index still remain. Route settling then owns the very next
frame; otherwise the press occurs two frames late and live input is hidden
during those two frames. A callback that clears or installs an unmarked
replacement leaves the ordinary forced release intact. When a callback queues
a route whose first step is marked, installing that first-step settle clears
the just-finished route's release itself. This transfer of ownership is
targeted to marked entries. Unmarked routes keep their existing post-step
release and cooldown timing.

Matching route drift can complete a planned tile without using the normal
active-step completion branch. If catch-up exposes a marked next step, the
neutral drift-observation frame counts as its completion frame and installs
the remaining 15-frame settle. Catch-up stops immediately if a completion
callback replaces or clears the route, so old-route iterations cannot consume
or mutate callback-installed route state.

All safety behavior remains mandatory. Live direction input during the settle
still cancels the route, drift is consumed or rejected through existing
logic, hazards are checked before the fresh step begins, and callback-driven
route cancellation prevents the step from starting. The executor releases
normally at `(0,0)` before turning south, preventing an extra west input from
triggering the World Map transition. Ordinary routes and unmarked boundaries
retain current release timing.

The metadata is route/path data, not merchant-specific state. Every fresh
plan, reroute, or seam follow-up recomputes it from the map entry and actual
path. Remove the disproven continuous-hold metadata and executor branch rather
than retaining two competing cadence models.

Log the scheduled settle with map, origin, destination, direction, route-step
index, required physical neutral frames, and remaining countdown frames.
Existing blocker, timeout, cancellation, hazard, and progress logs remain
intact.

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

### Settled re-press executor tests

- A route with `settle_before_steps={[2]=16}` proves the completion frame plus
  15 countdown frames are neutral before the second same-direction press.
- A route with `settle_before_steps={[1]=16}` proves a fresh first step waits
  all 16 neutral frames.
- The marked route emits exactly one `route_step_completed` event per crossed
  tile and one route-complete event.
- The per-step requirement still applies when `settle_same_direction=false`.
- A larger ordinary turn/final settle remains authoritative through
  maximum-value merging.
- Live direction input during the marked settle cancels immediately.
- Both ordinary active-step completion and pending-repress completion transfer
  the first follow-up frame directly to marked route settling.
- A callback-requeued route whose first step is marked does not inherit the
  completed route's forced post-step release.
- A callback that clears the marked continuation or replaces it with an
  unmarked route retains ordinary forced-release behavior.
- Drift catch-up that exposes a marked next step installs the exact remaining
  settle, while callback mutation stops multi-step catch-up immediately.
- Drift during the marked settle uses the existing catch-up/cancel behavior.
- Hazard refusal before the fresh step neutralizes input and does not consume
  the unsafe step.
- A step-completion callback that clears the route prevents the marked next
  step from starting.
- An otherwise identical unmarked route retains its existing forced-release
  and cooldown timing, including its frame-6 second press in the focused
  two-step regression.

### Cadence metadata and arrival tests

- `get_entry_settle_frames(0x0B, 0, 0, "east")` returns `16`.
- Reverse approach, neighboring cells, other maps, and missing entries return
  zero.
- A synthetic Rimuldar path entering `(0,0)` from the east marks only that
  path step with `settle_before_steps[entry_index]=16`.
- Turns, unrelated straight runs, other maps, and paths that do not cross the
  marked edge remain unmarked.
- A successful seam retry that lands on `(4,5)` emits one final step event and
  one route-complete event, preserves the Magic Key target, faces south, and
  produces the standard completion feedback.
- Existing survey-safe seam completion remains unchanged.

### Verification commands

Run focused map-reader, object, pathfinder, and route-manager suites first,
then every repository Lua test and `luac -p` over changed Lua files. Capture
the injected-input waveform in executor tests so exactly 16 physical neutral
frames precede the fresh press. The final live check requires a manual
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
- If settled re-press execution loses route context, encounters a refused
  hazard, or sees off-path drift, fail closed through the existing
  release/cancel/replan behavior.
- Never infer a long settle merely from coordinates or adjacent equal
  directions; require explicit map/path metadata so ordinary routes retain
  their proven timing.

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
- a global long-settle default or merchant-specific executor flag;
- fake blockers, teleports, or quest-state gates for the `(0,0)` seam;
- emulator launcher or desktop-control automation.

## Acceptance Criteria

1. Focused and full Lua tests pass after demonstrating the new regressions fail
   on the pre-fix source.
2. `git diff --check` and Lua syntax checks pass.
3. The planner selects `(4,5)` facing south for the Magic Key Merchant.
4. One source-only live autowalk reaches `(4,5)` from `(29,14)` via the row-2 /
   x=21 jog, a 16-frame settled re-press at `(1,0)`, and bridge `(1,3)`.
5. The executor sends exactly 16 physical neutral frames before the fresh west
   press, including the already-neutral completion frame when applicable,
   releases before turning south at `(0,0)`, never transitions to the World
   Map, and preserves per-tile progress/blocker/cancel safety.
6. A destination seam retry uses the standard arrival path, leaves the player
   at `(4,5)` facing south, and emits one route-complete result.
7. TALK opens the 53 G key prompt with no runtime blocks.
8. Active handoff, playtesting, map notes, and durable project memory agree.
