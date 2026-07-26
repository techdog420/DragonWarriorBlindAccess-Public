# Overworld Cross-Waypoint Turn Timing Design

Date: 2026-07-26

## Problem

The live Cantlin-to-Hauksness validation completed successfully, but five
intermediate waypoint segments carried one extra tile in the segment's final
direction before the next waypoint turned perpendicular:

- `(68,91)` carried west to `(67,91)` before a south turn;
- `(64,92)` carried west to `(63,92)` before a south turn;
- `(60,93)` carried west to `(59,93)` before a south turn;
- `(47,104)` carried west to `(46,104)` before a south turn; and
- `(22,89)` carried north to `(22,88)` before an east turn.

Each final step retained the ordinary 12-frame injection window. The extra
cell appeared during the 16-frame final settle, cancelled safely as
`route_drift_off_path`, and recovered when the user restarted autowalk.

`auto_step.lua` already uses a shorter pre-turn injection window for a
continuing step when the turn is visible inside one queued segment. Overworld
waypoint segments are queued separately, however, so the executor cannot see
that the exact final-carry target represents a perpendicular first step toward
the next waypoint. It therefore treats the final segment step like an
ordinary straight step.

## Goals

- Apply the existing shorter pre-turn input window when an exact final-carry
  target proves that the next waypoint begins with a perpendicular turn.
- Preserve ordinary timing for straight final carries and segments without
  valid lookahead.
- Keep exact final-carry acceptance and conservative drift cancellation.
- Avoid route-coordinate, map-passability, and movement-RAM changes.
- Add deterministic coverage for the cross-waypoint timing decision.

## Non-Goals

This change will not:

- alter Cantlin-to-Hauksness or Hauksness-to-Cantlin waypoints;
- promote timing failures into permanent or runtime map blockers;
- change the global injection, timeout, retry, or settle configuration;
- enable movement-state resets or write movement RAM;
- change manual taps, probes, map crawling, interior routes, or marked entry
  waveforms; or
- attempt to solve guarded-twitch false blocks in the same patch.

The five same-origin false blocks and thirteen internal retries remain a
separate timing investigation after this change is live-validated.

## Considered Approaches

### 1. Carry-aware cross-waypoint pre-turn timing

Infer the direction from the completed segment endpoint to the existing exact
final-carry coordinate. When it is one cardinal tile and perpendicular to the
segment's final direction, apply the existing pre-turn injection limit to that
final step.

This is the chosen approach. It reuses already-validated route lookahead,
changes only executor timing, and defaults to current behavior when metadata
is missing or invalid.

### 2. Route-specific timing annotations

Add a timing marker to every waypoint that showed drift and teach the route
manager to forward it. This would duplicate a geometric fact already encoded
by the exact carry coordinate and could leave equivalent turns elsewhere
unprotected.

### 3. Globally shorten overworld step injection

Reduce the ordinary 12-frame input window for every overworld step. This could
reduce drift but would also increase under-commit and false-block risk on
straight terrain and known difficult entries.

## Design

### `auto_step.lua`

Add a small helper that determines whether the current queued step is followed
by a turn:

1. Prefer the next direction inside `route_steps`.
2. If the current step is the final queued step, calculate its expected
   endpoint from the step origin and direction.
3. Validate that the paired final-carry coordinate is exactly one cardinal
   tile from that expected endpoint.
4. Treat the inferred carry direction as the next direction only when it is
   perpendicular to the current step.
5. If the pair is absent, incomplete, non-cardinal, reverse, or otherwise
   ambiguous, retain current timing.

`build_route_step_opts()` will use that decision to select the existing
`auto_step_route_pre_turn_inject_limit` for the final queued step. Existing
within-segment pre-turn behavior remains unchanged.

The final-carry coordinate remains only an exact permitted settle destination.
This timing use does not broaden which drift can complete a route.

### `test_auto_step.lua`

Add behavior-first regressions:

- a final queued step followed by a perpendicular exact carry releases at the
  shorter pre-turn injection limit;
- a final queued step followed by a straight exact carry retains ordinary
  timing;
- incomplete, diagonal, reverse, and multi-cell carry metadata retain
  ordinary timing; and
- existing exact-carry acceptance and rejection tests remain green.

The principal regression must fail before production code changes because the
current final step continues injecting through the ordinary limit.

No route-manager or overworld-route production change is expected because
they already pass the exact carry pair into `auto_step.start_route()`.

## Safety and Logging

- No writes to `$003C`, `$003D`, or other movement/player-stat RAM are added.
- Missing or malformed carry metadata remains conservative.
- The shorter window affects only a final queued step whose next exact
  cardinal direction is perpendicular.
- Existing `AUTO_STEP_FINAL_CARRY_ACCEPTED` and
  `route_drift_off_path` behavior remains authoritative.
- No new player-facing configuration or speech is added.

## Verification

Automated verification:

1. Run the new focused `test_auto_step.lua` regression and observe the expected
   failure before implementation.
2. Implement the minimal carry-aware pre-turn decision and rerun
   `test_auto_step.lua`.
3. Run the focused overworld-route and route-manager suites.
4. Run Lua bytecode checks, `git diff --check`, and the full repository
   harness.

Live validation after the user manually reloads `main.lua` in FCEUX:

1. Fresh-probe the hero and confirm no active route, runtime blocks, or input
   contamination.
2. Re-run Cantlin-to-Hauksness or another route containing cross-waypoint
   perpendicular turns.
3. Confirm final steps at those boundaries use the shorter injection window
   and do not carry one tile in the old direction.
4. Confirm exact route-aware carry still works where the next waypoint
   continues straight.
5. Keep combat and dialogue interruptions separate from timing conclusions.
6. Confirm arrival, route cleanup, and player-stat integrity.

## Acceptance Criteria

- Cross-waypoint perpendicular turns use the existing shorter pre-turn input
  window.
- Straight carries and invalid or absent carry metadata retain current timing.
- Wrong-coordinate drift still cancels rather than being accepted.
- No route, map, movement-RAM, manual-input, or marked-waveform behavior
  changes.
- Focused and full automated verification passes.
- A preserved live trace shows no old-direction one-tile drift at the tested
  perpendicular waypoint boundaries.
