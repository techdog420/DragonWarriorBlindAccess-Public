# Hauksness Lower-Pocket Carry Recovery

Date: 2026-07-24

## Problem

The `kol_hauksness` segment from `(15,93)` targets `Hauksness lower west
drop` at `(24,93)`. Live FCEUX execution reached that waypoint, then accepted
one tile of final-settle carry and stopped at `(25,93)`.

The next waypoint is `Hauksness lower west pocket` at `(24,91)`. Its default
vertical-first plan tried `(25,93)->UP` into `(25,92)`. Four queued attempts
and a same-origin raw probe all blocked without NPC, menu, runtime-block, or
input contamination. A raw LEFT probe crossed `(24,93)`, and a same-origin UP
probe from `(24,93)` crossed `(24,92)` and reached `(24,91)`.

## Design

Set `axis_order = {"horizontal", "vertical"}` only on the
`Hauksness lower west pocket` waypoint in `kol_hauksness`.

- From the carried landing `(25,93)`, the segment first recovers LEFT to
  column 24, then moves UP.
- From the normal landing `(24,93)`, horizontal distance is zero, so the
  segment continues to begin UP.
- Do not modify global final-carry acceptance.
- Do not add an overworld map blocker; overworld guidance encodes this
  directional geometry in its route waypoints.

## Regression Coverage

Add a focused route test that advances `kol_hauksness` through
`Hauksness lower west drop`, plans from the reproduced carry landing
`(25,93)`, and asserts:

- the target remains `Hauksness lower west pocket`;
- the first step is LEFT;
- the subsequent steps move UP toward `(24,91)`.

Keep the existing lower-pocket progression test, which verifies that the
normal `(24,93)` arrival still begins UP.

## Live Verification

The current live route has already recovered to `(24,91)` and may continue.
After the source patch and tests pass, defer the required FCEUX Stop/Run until
it will not disrupt the active return-route validation. On a later
Hauksness-to-Kol pass, reproduce the final-settle carry or begin at
`(25,93)` with the route active and confirm that the planned first step is
LEFT rather than UP.
