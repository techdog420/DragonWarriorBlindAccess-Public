# Hauksness-to-Kol Return Route Design

Date: 2026-07-23

## Goal

Add reliable overworld guidance from the Ruins of Hauksness back to Kol while
preserving the existing Travel-object workflow: selecting the ordinary Kol
Travel object near Hauksness must automatically choose the return variant.

## Evidence

The forward `hauksness` route has been live-validated from Kol through the
western desert and the final Hauksness approach. Normal movement west from
Ruins of Hauksness map `0x03` at `(0,10)` changed to World Map `0x01` at
`(25,89)`. This exit was reproduced twice. Moving east from `(25,89)` also
re-entered Hauksness and landed at `(0,10)`.

The forward validation identified direction-sensitive seams and timing-only
movement failures. In particular, the western desert shelf coordinates require
explicit horizontal correction before vertical movement. Those findings make
a generic automatic reversal unsafe even though the verified coordinates are
the correct basis for the return route.

## Architecture

Define a new explicit route named `kol_hauksness` in
`overworld_routes.lua`. It will follow the established `kol_rain_shrine` and
`kol_swamp_cave` pattern:

- title `Kol`;
- aliases `kol from hauksness`, `hauksness to kol`, and
  `return from hauksness`;
- target object `overworld_kol`;
- destination map `0x07`;
- an explicitly declared waypoint list beginning at Hauksness `(25,89)` and
  ending at Kol `(104,10)`.

The waypoint coordinates will be the validated `hauksness` chain in reverse
order. The return definition will be independent rather than generated at
runtime, allowing names, radii, warnings, and axis ordering to be audited for
the return direction.

Add `kol_hauksness` to deterministic route lookup and to every Kol alternate
set. The existing nearest-next-waypoint score will then select it
automatically for both the `kol` alias and the ordinary `overworld_kol` Travel
object when the player is near Hauksness. Recalculation will also be able to
switch between `kol_hauksness`, `kol`, `kol_rain_shrine`, and
`kol_swamp_cave` when the player's location makes another variant nearer.

The Hauksness variant is eligible for automatic selection only through its
unique route section ending at Garinham outskirts. A route-local
`selection_max_index` enforces that handoff during route-start scoring so the
long reversed route cannot steal existing shared Kol-road starts. This
selection constraint does not truncate an already active route; its complete
waypoint chain remains available through Kol.

No new command, Travel object, route-manager branch, or automatic route
handoff is required.

## Waypoint and Seam Behavior

The return route begins with these exact checkpoints:

1. Hauksness `(25,89)`.
2. Hauksness doorstep west `(24,89)`.
3. Hauksness west approach `(15,89)`.
4. The validated lower-pocket recovery chain in reverse, beginning with
   `(15,93)`.

Starting at `(25,89)` must therefore plan LEFT, not attempt to re-enter the
ruins. The route then follows the full validated approach chain backward
rather than taking a visually plausible shortcut through the Hauksness
mountains.

Every waypoint with nonzero x and y differences from its likely predecessor
must have its return-direction axis order reviewed. Critical invariants are:

- the Hauksness lower-pocket and western-ridge chain retains its explicit
  turns rather than diagonally collapsing the detour;
- the western desert return targets `Western desert east shelf (15,14)` with
  horizontal-first ordering, so an x=16 approach corrects LEFT before moving
  UP through the known seam;
- the southern-road and row-51/52 bends retain their explicit narrow-lane
  checkpoints;
- the northern Hauksness ridge is traversed through the live-proven western
  gap `(3,7)`;
- bridge and Kol-road warnings describe decreasing danger on the return
  journey where appropriate.

Waypoint radii remain zero for exact narrow-lane turns. Radius one is retained
only for broad, already-validated road anchors where skipping the exact center
cannot bypass a required turn.

## Selection and Data Flow

When the player selects Kol:

1. `route_id_for_object` gathers all routes targeting `overworld_kol`.
2. The existing route-start scoring compares each variant's next reachable
   waypoint from the current overworld coordinate.
3. Near `(25,89)`, `kol_hauksness` wins because its local exit/doorstep chain
   is nearest.
4. `start_for_object` activates that route without changing the visible Travel
   object name.
5. Normal route observation, segment planning, warnings, recalculation, and
   arrival handling continue unchanged.

Entering Kol map `0x07` completes the route, clears active guidance, and
refreshes Travel objects through the existing destination-map behavior.

## Failure Handling

The route remains conservative:

- a movement timeout or off-path drift cancels or pauses under existing
  executor rules;
- ordinary combat pauses progression and is cleared by the user before a
  fresh state probe;
- a live blocked edge is investigated at the same origin before any permanent
  map or route edit;
- timing-only failures are not promoted as blockers;
- a route recalculation may select another Kol variant only through the
  existing nearest-route mechanism.

The recurring coordinate-sensitive battle-dialogue repeats are separate
speech-reader evidence and must not alter route geometry.

## Tests

Add focused regressions in `test_overworld_routes.lua` before production data:

- starting the `kol` alias at or near `(25,89)` selects `kol_hauksness`;
- selecting the ordinary `overworld_kol` Travel object near Hauksness selects
  `kol_hauksness`;
- the first segment from `(25,89)` targets `(24,89)` and begins LEFT;
- the route preserves the lower-pocket recovery checkpoints instead of
  shortcutting the mountain pocket;
- the reverse western-desert shelf corrects horizontally before moving UP
  from an x=16 approach;
- the reverse northern ridge uses the western gap `(3,7)`;
- recalculation among Kol variants includes `kol_hauksness`;
- entering destination map `0x07` announces arrival at Kol and clears the
  route;
- the forward `hauksness` route and all existing Kol variants retain their
  current behavior.

Run the focused test file, byte-compile the changed Lua sources, run the
project's relevant route regression suite, and run `git diff --check`.

## Live Validation

After the source and tests pass, FCEUX requires a manual `main.lua` restart.
Restore the saved Hauksness interior state at map `0x03`, `(0,10)`, then move
one tile west to the confirmed World Map exit `(25,89)`.

Select the ordinary Kol Travel object and confirm that status reports
`kol_hauksness`. Validate the route in Productive Investigation Mode:

1. confirm the Hauksness doorstep and lower-pocket recovery;
2. confirm the western ridge and live-proven northern gap;
3. confirm both western desert seam approaches;
4. confirm the northern roads, bridge, and Kol approach;
5. enter Kol and verify destination-map completion.

Pause whenever combat begins. After each battle, obtain a fresh position,
active-route, and runtime-block baseline before continuing. If an apparent
blocker occurs, preserve the origin and use a same-origin probe before
changing route or permanent map data.

## Non-Goals

This change does not:

- generate reverse routes automatically;
- refactor shared route storage;
- add a special Hauksness-to-Kol Travel object;
- change movement timing or movement RAM reset behavior;
- fix battle-dialogue repetition;
- add permanent World Map blockers without new live evidence;
- alter the already validated forward Hauksness route except where a failing
  regression proves shared alternate-selection metadata must include the new
  Kol variant.
