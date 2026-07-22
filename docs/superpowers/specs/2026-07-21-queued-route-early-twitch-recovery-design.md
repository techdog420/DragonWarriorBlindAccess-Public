# Queued-Route Early-Twitch Recovery Design

Date: 2026-07-21

## Problem

FCEUX can report a movement-subpixel change immediately after a queued route
press without moving the player. `auto_step` correctly treats this as an early
movement twitch. Straight queued steps recover because the executor can issue a
same-direction cadence re-press. A step immediately followed by a turn, or the
last step in a route, cannot use that recovery: the current guard suppresses
the re-press to avoid committing an extra tile in the old direction. The step
therefore waits for the 32-frame timing-suspect deadline and reports a false
block.

Live Hauksness validation reproduced the same failure at `(20,7)->LEFT`,
`(19,7)->UP`, and `(19,5)->DOWN`. Direct same-origin edge probes moved through
all three edges. Input recovery also confirmed `left_alt=false`, so these are
executor timing failures rather than map blockers or stale keyboard state.

## Goals

- Recover queued steps safely when an early twitch occurs before an immediate
  turn or on the route's final step.
- Apply the behavior generically in `auto_step`, including overworld and local
  queued routes.
- Preserve the existing straight-route cadence behavior.
- Avoid a second press if the initial pulse completes the tile during the
  neutral interval.
- Preserve timing-suspect classification and avoid recording false permanent
  blockers when recovery still fails.

## Non-goals

- Do not alter overworld waypoint data or permanent map passability.
- Do not reset Dragon Warrior movement RAM at every route boundary.
- Do not change manual-tap behavior.
- Do not redesign route planning or ordinary block retry limits.

## Design

When a queued step detects an early movement twitch and ordinary
same-direction cadence recovery is unsafe because the following route step
turns or does not exist, `auto_step` will convert that attempt into a guarded
neutral-and-repress recovery.

The executor will:

1. Treat the already-issued direction as the probe pulse.
2. Release all directions for the existing entry-settle interval.
3. Observe the live player coordinate throughout the neutral interval.
4. If the player reaches the expected adjacent tile, complete the queued step
   without another press.
5. If the player moves somewhere else, cancel as route drift.
6. If the player remains at the origin, issue one fresh committed press using
   the existing entry-waveform state and normal injection window.
7. If the fresh press still cannot complete, use the existing bounded timeout
   and publish a timing-suspect block; never loop indefinitely.

The implementation should reuse the existing pending-repress and entry-prime
waveform machinery rather than adding a second cadence state machine. A small
helper may decide whether the current early twitch needs guarded recovery and
schedule the existing waveform with the current step's origin, direction, and
route index.

## Compatibility and Safety

Straight queued steps retain their current early-twitch hold/re-press path.
Manual taps remain unchanged. The guarded recovery owns the controller's
directional state during its neutral and committed windows, matching the
existing entry waveform behavior. Route cancellation, hazards, live-input
interrupts, and drift checks remain authoritative.

Because the player coordinate is checked before the fresh press, a late tile
completion cannot cause an extra step in the old direction. Recovery is bounded
by the existing retry and timeout controls.

## Tests

Add focused `test_auto_step.lua` regressions before production changes:

- An immediate-turn route with a frame-1 twitch enters a neutral interval,
  receives one guarded fresh press, and completes instead of blocking at frame
  33.
- A one-step route receives the same guarded recovery.
- If the first pulse completes during the neutral interval, the executor
  completes the step and never emits the fresh press.
- Movement in the wrong direction during the neutral interval cancels as route
  drift.
- A genuinely unmoving step remains bounded and publishes a timing-suspect
  block after recovery.
- A straight route continues to use its existing cadence path.

Run the focused auto-step suite, then the route-manager and overworld-route
suites, Lua syntax checks, and the broader project tests appropriate to the
changed files.

## Live Verification

After a manual FCEUX script reload, resume the Hauksness route from the current
Garinham ridge area. Confirm that the previously failing immediate-turn steps
complete through normal `auto_walk`, no runtime/permanent block is created, and
the route advances beyond waypoint 30. Continue Hauksness validation, then
validate Cantlin. Combat remains user-handled.
