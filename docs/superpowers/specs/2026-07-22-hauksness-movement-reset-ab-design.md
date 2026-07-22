# Hauksness Movement-Reset A/B Design

Date: 2026-07-22

## Purpose

Determine whether the existing queued-route movement reset improves the final
Hauksness town-entry sequence without globally re-enabling a setting previously
associated with battle-time stat corruption.

## Evidence and Hypothesis

The completed reset-disabled route produced two different timing failures:

- `(15,90)->UP` timed out during a same-direction four-step segment. A
  turn-settle reset does not run between same-direction steps, so this failure
  is outside the useful scope of this experiment.
- `(24,89)->RIGHT` timed out on the one-step entry segment after the preceding
  segment had completed at `(24,89)`. A final-settle reset on that preceding
  segment can normalize movement state before the entry segment begins.

The test hypothesis is therefore limited: resetting movement state at the
final settle of the segment ending at `(24,89)` may allow the following RIGHT
input to enter Hauksness reliably.

Historical Grave testing does not justify globally restoring the option. The
May 30 corruption repro correlated a queued-route final-complete reset with a
temporary battle-time rewrite of player stat bytes `C8..CE`. Disabling all
turn/final-settle resets was followed by five clean battles, but that evidence
was observational rather than a controlled same-state A/B. The July 7 NPC
parking/OAM failure was a separate hard-lock signature and does not clear the
movement reset of risk.

## Chosen Approach

Keep `auto_step_reset_movement_on_route_turn_settle=false` globally. Add the
existing waypoint-level `route_reset_movement_on_turn_settle=true` override
only to the Hauksness waypoint named `Hauksness doorstep west` at `(24,89)`.

No new reset mechanism, configuration key, command, or generalized timing
change is part of this experiment. `route_manager.lua` and `auto_step.lua`
already forward and honor the waypoint override.

The comparison is:

1. Control: the already recorded reset-disabled approach, where
   `(24,89)->RIGHT` timed out and a same-origin `probe_edge:RIGHT` entered map
   `0x03`.
2. Treatment: restore a repeatable overworld state before the doorstep
   approach, run the same route with only the `(24,89)` override enabled, and
   observe whether normal auto-walk enters map `0x03`.

## Source and Test Scope

Expected implementation scope:

- `overworld_routes.lua`: add the waypoint-level override to `(24,89)` only.
- `test_overworld_routes.lua`: assert that the Hauksness doorstep segment
  exposes the override while adjacent Hauksness waypoints retain their current
  behavior.

Existing route-manager and auto-step tests already cover forwarding and
honoring the override. They should be rerun, but those modules should not be
changed unless the focused test exposes a separate defect.

## Live Test Protocol

1. Confirm the global config remains false.
2. Run focused static tests and syntax checks.
3. Ask the user to manually reload `main.lua` in FCEUX.
4. Confirm the reload with a fresh launcher probe and record the starting map,
   position, route state, runtime blocks, and player-stat integrity.
5. Restore or reach a repeatable overworld position before the segment ending
   at `(24,89)`.
6. Resume the Hauksness route and observe the settle at `(24,89)` and the next
   RIGHT step.
7. Pause for the user if combat begins.
8. After arrival or failure, record position, route state, runtime blocks,
   movement-reset markers, timeout/drift markers, and player-stat integrity.

## Success and Safety Criteria

The treatment is useful only if all of the following hold:

- The log shows the scoped movement reset at the `(24,89)` final settle.
- Normal auto-walk performs the following RIGHT step and changes from world
  map `0x01` to Hauksness map `0x03` without `probe_edge`, manual movement, or
  a route timeout.
- No `PLAYER_STAT_FRAMEADVANCE_TRANSITION`,
  `PLAYER_STAT_INTEGRITY_TRANSITION`, or integrity warning appears.
- No unrelated route behavior changes and no runtime blocker is promoted.

Stop the experiment and remove the override if a stat-integrity transition,
control hard lock, unexpected map change, or new persistent movement anomaly
appears. A clean entry is evidence only for this waypoint boundary; it is not
permission to enable the global option or apply the override broadly.

## Outcomes

- If the treatment enters Hauksness cleanly, retain the local override and
  document the waypoint-specific result.
- If it repeats the timeout, remove the override and continue investigating
  entry-step timing independently of movement reset.
- If the result is contaminated by combat, stale input, reload failure, or an
  unreproducible starting state, record it as inconclusive and repeat from a
  clean baseline rather than changing additional variables.

## Non-Goals

- Re-enabling movement reset globally.
- Explaining or fixing the older Grave stat corruption.
- Fixing the separate `(15,90)->UP` same-direction timeout.
- Changing permanent map passability or adding runtime blockers.
- Combining this A/B with the pending final-drift or gold-dialogue changes.
