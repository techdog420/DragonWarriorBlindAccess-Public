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
guidance from `(16,27)`, confirms that `Western desert
south shelf` remains the active waypoint, and asserts that the first planned
step is LEFT and the second is DOWN.

Run the regression before production code and confirm that it fails because
the current first step is DOWN. After adding the waypoint-local axis order,
run all overworld-route tests, byte-compile the changed Lua files, and run
`git diff --check`.

## Live verification

FCEUX requires a manual `main.lua` restart after the source change. Following
reload, re-establish Hauksness guidance from the current World Map state and
confirm that the segment approaches `(15,28)` through `(15,27)` without
attempting `(16,27)->DOWN`.

If the live segment deviates from the tested LEFT-then-DOWN sequence, stop and
capture fresh position and movement logs before changing any other waypoint.
