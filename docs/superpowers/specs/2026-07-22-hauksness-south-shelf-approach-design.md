# Hauksness South-Shelf Approach Design

Date: 2026-07-22

## Goal

Prevent Hauksness overworld guidance from attempting the confirmed engine-
blocked edge `(16,27)->DOWN` when approaching `Western desert south shelf`
at `(15,28)`.

## Evidence

Normal route execution reached `(16,27)` and exhausted its timing retry twice
while attempting DOWN into `(16,28)`. A same-origin raw probe then held DOWN
for 60 frames and remained at `(16,27)`, with no NPC, runtime block, modeled
directional block, or map transition.

The narrow bypass is live-proven: `(16,27)->LEFT` reached `(15,27)`, and the
same-origin DOWN probe then reached waypoint `(15,28)`.

## Scope

Change only the Hauksness waypoint named `Western desert south shelf` in
`overworld_routes.lua`. Give that waypoint horizontal-first axis ordering so
an off-column approach corrects x before descending.

Do not add permanent World Map data to `map_reader.lua`, add a new waypoint,
or make the general overworld route planner map-aware. The current planner is
waypoint-driven, and the verified bypass requires only a waypoint-local order.

## Behavior

From `(16,27)`, planning the active Hauksness segment to `(15,28)` must produce
LEFT followed by DOWN. Approaches already aligned at x=15 keep their direct
vertical movement, and unrelated route waypoints retain their existing axis
orders.

## Tests

Add a focused regression in `test_overworld_routes.lua` that starts Hauksness
guidance from `(16,27)`, confirms that `Western desert south shelf` remains
the active waypoint, and asserts that the first planned step is LEFT and the
second is DOWN.

Add route-metadata coverage asserting that both seam waypoints use
horizontal-first ordering:

- `Western desert east shelf (15,14)`, which already protects the reverse
  approach.
- `Western desert south shelf (15,28)`, which this patch changes to protect
  the forward approach.

Because no explicit Hauksness return route exists yet, do not invent a
synthetic executable return route solely for this patch. The metadata
assertion records the required reverse-seam invariant until that route is
defined and validated from its actual start.

Run the regression before production code and confirm that it fails because
the current first step is DOWN. After adding the waypoint-local axis order,
run all overworld-route tests, byte-compile the changed Lua files, and run
`git diff --check`.

## Live verification

FCEUX requires a manual `main.lua` restart after the source change. Following
reload, re-establish Hauksness guidance from the current World Map state and
confirm that the segment approaches `(15,28)` through `(15,27)` without
attempting `(16,27)->DOWN`.

Continue the same forward-route validation through the existing southern-road
patch. From its carry landing near `(1,54)`, confirm that guidance toward
`Western desert south road (2,64)` corrects RIGHT before descending, avoiding
the known blocked approach at `(1,63)->DOWN`.

If the live segment deviates from the tested LEFT-then-DOWN sequence, stop and
capture fresh position and movement logs before changing any other waypoint.

## Reverse-route safety and deferred scope

The repository currently defines only the forward `hauksness` route. A future
return route must preserve `Western desert east shelf (15,14)` as the seam
target, with its existing horizontal-first ordering. From an x=16 approach,
that ordering corrects LEFT before moving UP and therefore avoids reversing
through the blocked x=16 seam.

This patch records and tests that invariant but does not define or live-test a
full return route. After the forward seam and southern road pass live
validation, return-route work will begin separately and be validated from its
defined start.
