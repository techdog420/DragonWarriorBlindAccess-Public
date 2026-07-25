# Overworld Route-Aware Carry Recovery Design

Date: 2026-07-24

## Problem

Queued overworld movement can produce an early subpixel twitch without
immediately changing the player coordinate. The guarded recovery added for
that condition safely waits through a neutral interval, but its fresh recovery
press reuses the entry-prime waveform and owns a complete committed-input
window. When movement begins early in that window, the remaining held frames
can commit a second tile.

The current final-drift exception then accepts any exact one-cell continuation
in the final planned direction. That rule prevents false cancellation when
normal movement carry is useful, but it does not know whether the extra cell
advances the next waypoint. It can therefore report a segment complete after
carrying into an unhelpful cell. Live overworld validation has shown both
route-cancellation timing noise and an unintended extra-tile carry.

Movement-RAM reset is not a solution. Writes to `$003C/$003D` were implicated
in player-stat corruption and must remain disabled during normal route settle.

## Goals

- Stop a guarded overworld recovery press from manufacturing an extra tile
  after real movement begins.
- Preserve a naturally committed one-cell carry only when it is the
  deterministic first step toward the next overworld waypoint.
- Keep final town, entrance, object, and interaction destinations exact.
- Preserve the special full cadence needed by verified dungeon and town-entry
  waveforms.
- Cancel honestly and log the observed position whenever drift is unsafe or
  ambiguous.
- Make no movement-RAM writes.

## Non-Goals

This change will not:

- alter overworld waypoint coordinates or permanent map passability;
- enable `auto_step_reset_movement_on_route_turn_settle`;
- change manual taps, raw probes, map crawling, or interior pathfinding;
- add corrective movement after an overshoot;
- accept reverse, sideways, diagonal, or multi-cell drift;
- redesign general route planning; or
- solve unrelated open-edge timeouts that do not involve guarded recovery or
  final carry.

## Chosen Approach

Use adaptive guarded recovery plus route-aware carry.

Guarded early-twitch recovery will remain bounded and will continue to use a
neutral interval before one fresh press. Unlike a marked entry waveform, the
guarded recovery press will release its direction as soon as real movement
begins, then settle with neutral input. Marked dungeon and town-entry
waveforms retain their complete committed-input windows.

At the end of an intermediate overworld segment, one carried tile may complete
the segment only when the live coordinate exactly matches a target computed
from the next waypoint's existing route-planning rules. No next waypoint means
no allowed carry.

This design rejects both weaker alternatives:

- Neutral settling alone cannot retract a second tile that the recovery press
  already committed.
- Accepting or correcting arbitrary final carry would mask executor mistakes
  and could move the hero away from the intended route.

## Components

### `overworld_routes.lua`

Extract the existing axis-ordered step construction from
`plan_next_segment()` into a pure helper that can also preview movement from
one waypoint toward the next. The helper must preserve the route and
waypoint-specific axis order already used by normal planning.

For an intermediate segment, compute at most one allowed post-segment carry
target:

1. Use the current waypoint coordinate as the origin.
2. Select the following waypoint.
3. Build its normal axis-ordered steps.
4. Return the coordinate reached by the first step.

Return no target when the segment is final, the current waypoint explicitly
disables final-drift completion, the next step cannot be determined, or the
preview would not be exactly one cardinal tile.

### `route_manager.lua`

The route manager owns overworld meaning. When it queues a segment, it will
pass the optional allowed carry coordinate as paired
`route_final_carry_x` and `route_final_carry_y` options. Supplying only one
coordinate is invalid and must be treated as no allowed carry.

The active overworld segment will retain enough metadata to log the planned
waypoint, the allowed carry target, and the final observed position. Other
route types will not acquire overworld lookahead logic.

### `auto_step.lua`

The generic executor will receive an optional exact final-carry target. Its
responsibilities remain mechanical:

- a guarded recovery attempt records a fresh starting subpixel value after its
  neutral interval, then releases after detecting movement relative to that
  fresh sample;
- neutral settle observes coordinate changes;
- drift matching remaining steps in the current queue is consumed as it is
  today;
- final drift completes only when the live coordinate equals the exact
  supplied carry target; and
- any other final drift cancels with structured evidence.

The existing broad `route_accept_final_drift_completion` behavior will be
replaced for overworld segments by this coordinate-specific contract. There
will be no new user-facing configuration option.

## Data Flow

1. `overworld_routes.plan_next_segment()` builds the current segment.
2. The route helper previews the first step after that segment, if one exists.
3. `route_manager.lua` queues the segment with the optional allowed carry
   coordinate pair.
4. `auto_step.lua` executes each planned step.
5. If guarded recovery is required, it performs one neutral-and-repress cycle
   and releases when movement begins.
6. During settle, ordinary on-segment drift is consumed against the remaining
   queued steps.
7. After the final queued step, the executor accepts only the exact supplied
   one-cell carry target.
8. Route completion returns control to the route manager, which observes the
   live position and plans the next segment from that position.

## Safety and Failure Behavior

- `auto_step_reset_movement_on_route_turn_settle=false` remains the production
  setting, and this change adds no writes to `$003C/$003D`.
- A missing, malformed, or ambiguous lookahead target defaults to strict
  arrival.
- An incomplete `route_final_carry_x` / `route_final_carry_y` pair is ignored
  and logged as invalid route metadata.
- Final route waypoints never receive a carry target.
- A waypoint with `route_accept_final_drift_completion=false` remains strict.
- Wrong-direction, reverse, diagonal, or multi-cell drift cancels as
  `route_drift_off_path`.
- A late completion during the guarded recovery's neutral interval still
  completes without issuing the fresh press.
- Guarded recovery remains bounded by the current retry and timeout controls.
- Marked entry waveforms retain their existing full committed press and settle
  semantics.
- Manual input, live-input interruption, hazards, and route cancellation
  remain authoritative.

Structured logging will distinguish:

- guarded recovery scheduled;
- movement-triggered recovery release;
- route-aware carry accepted, including expected and actual coordinates; and
- carry rejected, including the waypoint, expected target, and actual
  coordinate.

## Automated Tests

Use test-driven development.

### `test_overworld_routes.lua`

- The preview uses the same horizontal-first or vertical-first order as normal
  route planning.
- The preview returns exactly the first cardinal cell toward the next
  waypoint.
- A final waypoint returns no carry target.
- A waypoint that disables final-drift completion returns no target.

### `test_route_manager.lua`

- An intermediate overworld segment passes exactly one allowed carry
  coordinate to `auto_step.start_route()`.
- A final town or entrance segment passes no carry coordinate.
- An explicitly strict waypoint passes no carry coordinate.
- Existing overworld segment metadata and cancellation behavior remain intact.

### `test_auto_step.lua`

- A guarded recovery press releases after movement begins instead of
  delivering the rest of a full committed-input window.
- A late coordinate completion during the neutral interval still skips the
  fresh press.
- Marked entry recovery continues to replay its full waveform.
- An exact allowed one-cell final carry completes.
- Same-direction carry to a coordinate other than the allowed target cancels.
- Reverse, sideways, diagonal, and multi-cell final drift cancel.
- Final drift with no allowed target cancels.
- Existing on-segment drift catch-up still consumes queued steps.
- No movement-RAM write is introduced.

Run the focused auto-step, route-manager, and overworld-route suites; Lua
bytecode compilation for changed files; `git diff --check`; and the complete
repository harness.

## Live Validation

After a manual FCEUX script reload:

1. Establish a fresh world-map position and confirm command polling.
2. Exercise a short overworld segment containing a direction change that can
   invoke guarded early-twitch recovery.
3. Confirm the recovery log shows release after movement begins and that the
   hero does not advance an unintended second tile.
4. Exercise an intermediate segment where a naturally carried tile is the
   first step toward the next waypoint. Confirm it is accepted and the next
   segment plans from the live cell.
5. Exercise a final town or entrance segment. Confirm arrival remains exact
   and no carry past the destination is accepted.
6. Confirm logs contain no player-stat integrity transition and no
   movement-RAM reset.

Combat and manual Lua reloads remain user-handled. If combat interrupts a
route, fresh state must be confirmed before drawing a timing conclusion.

## Acceptance Criteria

- Autowalk never silently reports success from an unapproved coordinate.
- Guarded recovery does not produce an unintended extra tile after movement
  begins.
- A one-cell carry is accepted only when it deterministically advances the
  next waypoint.
- Final destinations remain strict.
- Entry cadence, manual movement, interior routes, probes, and map crawling do
  not regress.
- Focused and full automated tests pass.
- Live logs confirm correct recovery/carry behavior without movement-RAM or
  player-stat corruption.
