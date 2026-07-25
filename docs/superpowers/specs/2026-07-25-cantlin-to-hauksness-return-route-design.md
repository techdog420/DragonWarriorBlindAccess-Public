# Cantlin-to-Hauksness Return Route Design

Date: 2026-07-25

## Goal

Add reliable named overworld guidance from Cantlin to the Ruins of Hauksness.
The route begins after the player uses Cantlin's existing town exit and reaches
the World Map. It ends by entering Hauksness through the confirmed World Map
entrance at `(25,89)`.

This work is stacked on the battle-dialogue and route-aware autowalk branch so
the live route validation exercises the recent carry, guarded-twitch, and
turn-settle behavior.

## Scope and Existing Evidence

Cantlin's existing Travel object already routes safely to the southeast exit
stand at town `(20,28)`, facing south toward transition `(20,29)`. This change
does not combine that in-town route with an overworld route. After the map
transition, the player selects the ordinary Hauksness Travel object and starts
the new named overworld variant.

The direct Cantlin approach is live-proven from World Map `(73,103)`: moving UP
enters Cantlin and lands at town `(15,0)`. The historical Cantlin trail also
contains clean, normally walked evidence connecting the Hauksness-side origin
at `(15,93)` to the Cantlin approach. That investigation includes explicit
battle, death, reload, teleport, and dead-end boundaries. Only clean route
segments may become production waypoints.

The final Hauksness approach is already live-validated:

1. shared Hauksness-side origin `(15,93)`;
2. Hauksness west approach `(15,89)`;
3. Hauksness doorstep west `(24,89)`;
4. Hauksness entrance `(25,89)`, moving east into map `0x03`.

## Architecture

Define an explicit route named `hauksness_cantlin` in
`overworld_routes.lua`:

- title `Hauksness`;
- aliases such as `hauksness from cantlin`, `cantlin to hauksness`, and
  `return from cantlin`;
- target object `overworld_hauksness`;
- destination map `0x03`;
- a static waypoint list beginning at the Cantlin World Map approach and
  ending at Hauksness `(25,89)`.

Add the new route to deterministic lookup and to the Hauksness alternate set.
The ordinary `overworld_hauksness` Travel object will then select
`hauksness_cantlin` near Cantlin while preserving the existing `hauksness`
route elsewhere.

Use route-local selection bounds if necessary to prevent the long Cantlin
variant from winning at shared Hauksness-road coordinates. Selection
constraints affect route-start scoring only; they must not truncate an active
route.

No new command, Travel object, route-manager branch, or cross-map route
orchestration is required.

## Waypoint Construction

Declare the return waypoints explicitly rather than generating them by
reversing another route at runtime. The historical trail is evidence, not a
canonical forward route definition, and its explored dead ends and
contamination boundaries make mechanical reversal unsafe.

Build the production chain from clean, normally walked segments in
`work_notes/current_investigation.md`. The initial Cantlin departure must
preserve the confirmed approach seam rather than cutting diagonally across it:

1. establish the fresh World Map landing coordinate after using Cantlin's
   southeast exit;
2. move away from the Cantlin entrance without accidentally re-entering town;
3. reverse the clean `(73,103)`, `(72,103)`, `(72,101)`, `(74,101)` approach
   geometry;
4. follow the clean western trail toward `(15,93)`;
5. append the already validated Hauksness final approach.

Compress only broad straight corridors where the recorded evidence supports
carry-through movement. Preserve exact zero-radius waypoints at narrow turns,
direction-sensitive seams, and dead-end avoidance bends. Review `axis_order`
for every waypoint where both axes differ from the likely predecessor.

The existing route manager continues to derive segment plans and route-aware
carry metadata. The final Hauksness entrance remains strict: the segment into
`(25,89)` must not accept an overshooting carry target.

## Selection and Data Flow

When the player selects Hauksness on the World Map near Cantlin:

1. `route_id_for_object` gathers routes targeting `overworld_hauksness`.
2. Existing route-start scoring compares the next eligible waypoint for each
   Hauksness variant.
3. `hauksness_cantlin` wins because its Cantlin-departure chain is local.
4. `start_for_object` activates the variant without changing the visible
   Travel object name.
5. Normal route observation, per-segment planning, warnings, recalculation,
   battle interruption, and arrival handling continue unchanged.

Entering Hauksness map `0x03` completes the route, clears active guidance, and
refreshes Travel objects through the existing destination-map behavior.

An active `hauksness_cantlin` route must continue to match the ordinary
Hauksness object after object refreshes or combat. Recalculation may compare
the Hauksness variants, but the new variant must not steal ordinary starts near
Kol or along the already validated original route.

## Failure Handling

The route remains conservative:

- an off-path drift is handled by existing waypoint recalculation;
- a movement timeout or unrecoverable segment failure pauses or cancels under
  existing executor rules;
- combat interrupts movement and requires a fresh field-state baseline before
  continuing live validation;
- an apparent blocked edge is reprobed from the same origin before any route
  or permanent map edit;
- timing-only movement failures and post-battle state are not promoted as map
  evidence;
- uncertain historical trail fragments are excluded until live validation
  supplies clean evidence.

## Tests

Add focused regressions before production route data:

- starting Hauksness guidance at or near Cantlin chooses
  `hauksness_cantlin`;
- selecting the ordinary `overworld_hauksness` object near Cantlin chooses
  the new variant;
- the initial Cantlin departure preserves the `(73,103)`, `(72,103)`,
  `(72,101)`, `(74,101)` seam geometry and moves away from the entrance;
- representative narrow bends from each major trail section remain explicit
  and use the correct axis order;
- the route joins the validated Hauksness chain at `(15,93)`;
- the final segment approaches `(25,89)` from `(24,89)` and remains strict;
- entering map `0x03` announces Hauksness arrival and clears the route;
- active-route matching survives ordinary-object refresh and battle pause;
- the new variant does not replace the existing Hauksness route near Kol or
  at its established start;
- all existing Hauksness and Kol/Hauksness-return behavior remains unchanged.

Run the focused overworld-route and route-manager tests, byte-compile changed
Lua sources, run the repository harness, and run `git diff --check`.

## Live Validation

After automated checks pass, FCEUX requires a manual `main.lua` restart.
Use Cantlin's existing southeast Exit to World Map object, cross the transition
manually, and obtain a fresh probe before starting the named route. Record the
actual World Map landing coordinate rather than assuming it from historical
entry evidence.

Select the ordinary Hauksness Travel object and confirm the active route is
`hauksness_cantlin`. Validate through normal movement:

1. Cantlin departure and the first approach seam;
2. each major trail corridor and narrow bend;
3. the join at `(15,93)`;
4. Hauksness west approach `(15,89)`;
5. doorstep `(24,89)` and strict east entry at `(25,89)`;
6. destination-map completion on map `0x03`.

Pause whenever combat starts. After each battle, collect fresh position,
active-route, path, runtime-block, and input-state evidence before resuming.
Inspect route-aware carry logs during long corridors and turns so this run also
serves as a smoke test of the recent autowalk changes. If a route correction is
needed, change only the smallest waypoint or selection constraint supported by
the live evidence, then reload and retest from a clean checkpoint.

## Non-Goals

This change does not:

- start the Hauksness route from inside Cantlin;
- automatically cross Cantlin's town-to-world transition;
- generate reverse routes automatically;
- refactor shared route storage or the route manager;
- change movement timing, carry semantics, or turn-settle behavior;
- add permanent World Map blockers without new live evidence;
- alter the validated original Hauksness route except for the minimum
  alternate-selection metadata needed to include the Cantlin variant.
