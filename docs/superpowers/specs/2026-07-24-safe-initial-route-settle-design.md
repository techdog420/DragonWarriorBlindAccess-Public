# Safe Initial Route Settle Design

Date: 2026-07-24

## Problem

Hauksness autowalk reached the Axe Knight safe stand at `(17,12)`, carried
during final settle to `(18,12)`, and initiated drift recovery. Drift recovery
queued one west step with `initial_settle_frames=16`.

`auto_step.start_route()` currently treats any positive initial settle as
permission to zero movement RAM `$003C/$003D`, regardless of
`auto_step_reset_movement_on_route_turn_settle`. On the next emulated frame,
player-stat bytes `$00C8-$00CE` collapsed from valid level-17 values to
`04 03 0F 00 20 33 00`. This matches the movement-reset corruption mechanism
previously implicated by the Grave A/B test.

## Scope

This patch prevents automatic movement-RAM writes when movement resetting is
disabled. It does not change:

- initial-settle duration,
- route planning or drift detection,
- NPC parking,
- the Axe Knight landmark coordinate,
- final-settle carry handling, or
- the separate one-cell Axe Knight overshoot.

The overshoot will be investigated independently after RAM safety is restored.

## Design

Keep the existing configuration contract:

- `auto_step_reset_movement_on_route_turn_settle=false` means route settle
  periods wait with neutral input but never write `$003C/$003D`.
- An explicit `true` preserves the experimental reset behavior.

In `auto_step.start_route()`, a positive initial settle will always set
`route_settle_frames`. It will set
`route_settle_reset_movement_active=true` and call
`reset_movement_engine_state("queued_route_initial_settle")` only when
`should_reset_movement_on_route_turn_settle()` returns true.

This gate covers both the immediate reset in the queueing frame and repeated
settle-frame resets, because `reset_movement_for_route_settle()` already
requires `route_settle_reset_movement_active`.

No new configuration option or production helper is required.

## Tests

Use test-driven development in `test_auto_step.lua`:

1. Add a failing regression with
   `auto_step_reset_movement_on_route_turn_settle="false"`, nonzero movement
   bytes, and `initial_settle_frames=16`. It must assert that no movement-RAM
   writes occur.
2. Preserve the existing timing regression proving initial settle holds
   neutral input for the requested frame count.
3. Update the existing reset regression to set
   `auto_step_reset_movement_on_route_turn_settle="true"` explicitly. It must
   continue to assert zero writes to `$003C/$003D`.
4. Run the complete auto-step and route-manager suites, Lua byte-compilation,
   and `git diff --check`.

The new disabled-setting test must fail against current source before the
production gate is added.

## Live Validation

After the user restores the known-good Hauksness entrance save and manually
reloads the FCEUX Lua script:

1. Confirm clean player stats, map, position, runtime blocks, and command
   polling.
2. Resume Hauksness route validation.
3. If final-settle drift invokes a reroute with an initial settle, confirm the
   log contains no `PLAYER_STAT_FRAMEADVANCE_TRANSITION`,
   `PLAYER_STAT_INTEGRITY_TRANSITION`, or integrity warning.
4. Treat any Axe Knight overshoot as separate movement-timing evidence.

Success requires both automated tests and a clean live route-settle event.

## Evidence

The reproduction log is preserved at
`work_notes/hauksness_stat_corruption_20260724.log`. The exact transition is
also summarized in `work_notes/current_investigation.md`.
