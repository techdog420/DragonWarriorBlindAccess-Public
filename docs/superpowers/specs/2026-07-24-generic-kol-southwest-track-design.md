# Generic Kol Southwest-Track Ordering

Date: 2026-07-24

## Problem

After a fresh FCEUX script restart, in-memory route state was empty at World
Map `(54,15)`. Selecting Kol and starting guidance chose the generic `kol`
route. Its bridge segment correctly moved DOWN first and reached `(58,18)`,
then continued to `North Alefgard bridge road` at `(74,18)`.

The next waypoint, `Kol southwest track` at `(84,26)`, is explicitly
horizontal-first in generic `kol`. Live execution therefore moved east along
row 18 and stopped at `(77,18)` after the queued `(77,18)->RIGHT` step blocked.
The same edge was already raw-proven blocked during `kol_hauksness`
validation. A fresh same-origin DOWN probe crossed `(77,19)` and carried to
`(77,20)` with no NPC, runtime block, modeled directional block, menu, battle,
or input contamination.

`kol_hauksness` already uses vertical-first ordering for the same forward
waypoint. The generic `kol` route is the remaining forward route with stale
ordering.

## Design

Change only generic `kol`'s `Kol southwest track` waypoint from:

```lua
axis_order = {"horizontal", "vertical"}
```

to:

```lua
axis_order = {"vertical", "horizontal"}
```

This makes guidance from `(74,18)` descend to row 26 before moving east toward
`(84,26)`. From the live failure origin `(77,18)`, it likewise moves DOWN
rather than retrying the blocked east edge.

Keep these behaviors unchanged:

- `kol_hauksness` remains vertical-first at this waypoint.
- Reverse `hauksness` and `tantegel_kol` routes remain horizontal-first because
  they approach the same area from Kol in the opposite direction.
- Global route planning, final-carry handling, movement reset behavior, and
  executor retries do not change.
- No overworld map blocker is added; route waypoint geometry remains the
  appropriate model for this directional lane.

## Regression Coverage

Add a generic-route test that:

1. Starts `kol` from `(54,15)`, where generic `kol` is selected.
2. Advances through the shared bridge waypoints to `(74,18)`.
3. Plans the next segment from the reproduced failure origin `(77,18)`.
4. Asserts the target remains `Kol southwest track`.
5. Asserts the first step is DOWN and that vertical movement precedes eastward
   movement.

The existing `kol_hauksness_return_descends_before_kol_southwest_track` test
continues to cover the Hauksness return variant. Existing reverse-route tests
must remain green.

## Live Verification

Current live state after the recovery probe is World Map `(77,20)`. The
generic `kol` route had blocked at `(77,18)` before that probe.

After the source change and a manual FCEUX Stop/Run:

1. Establish a fresh field baseline with Kol selected and no active route.
2. Restore or normally reach the known `(54,15)` checkpoint.
3. Start Kol guidance and confirm `route=kol`.
4. Re-run the bridge approach to `(74,18)`.
5. Confirm the `Kol southwest track` segment begins DOWN and reaches row 26
   before turning east.

If debug teleport is used only to restore `(54,15)`, treat the run as
planner/reload validation rather than new passability evidence. The clean
same-origin probes already establish the blocked east edge and open south
lane.
