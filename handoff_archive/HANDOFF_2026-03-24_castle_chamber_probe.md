# Castle Chamber Probe Handoff

Date: 2026-03-24

## Purpose

This handoff captures the current state of the `map 0x04` castle collision
probe after the validator repair and the latest live chamber-mapping pass.

The main value here is not generic pathfinding context. It is:

- which cells were actually confirmed open vs blocked in live movement
- which earlier "blocked pocket" assumptions are now known to be wrong
- what validator bug was fixed
- where to resume probing next without re-deriving the chamber map

## Current Status

### Validator / test system

The important bug fixed today was in `path_debug.lua`.

Observed failure before the patch:

- `trace_path` planned one route
- `validate_path` could drift onto a different route
- validation still reported `OK`

Concrete repro from the live log before the fix:

- traced route to `(14,16)`:
  - `(16,17)->(15,17)->(14,17)->(14,16)`
- validation actually walked:
  - `(16,17)->(15,17)->(13,17)->(13,16)`
- validation still ended `3/3 OK`

Root cause:

- validation derived expected step coordinates from the actor's live current
  position, so once movement drifted, later steps silently adopted the drift

Fix now in `path_debug.lua`:

- each validation step is anchored to the planned stored path coordinates
- validation aborts if the actor is already off the planned start tile before
  a step is injected
- successful validated steps cancel any active `auto_step` hold to reduce
  overshoot between steps

Live verification after reload:

- route from `(13,16)` to `(16,18)` traced as:
  - `(13,16)->(13,17)->(13,18)->(14,18)->(15,18)->(16,18)`
- `validate_path` followed that exact route and ended:
  - `VALIDATE COMPLETE: 5/5 steps OK, 0 mismatches`

So multi-step validation is trustworthy again.

### Map probe conclusions

No new hardcoded tile patch was required in this pass.

What changed is the map model, not the code:

- the previously assumed "blocked pocket" in this area is not isolated
- there is a real connected chamber reachable through the west/south side
- several boundaries that looked ambiguous before are now confirmed live

## Confirmed Connected Chamber

This route is live-validated and traversable:

- `(14,18) -> (15,18) -> (16,18) -> (16,19) -> (17,19) -> (18,19)`

From there, the chamber continued:

- row `19`:
  - `(16,19)`, `(17,19)`, `(18,19)`, `(19,19)`, `(20,19)` open
- row `20`:
  - `(16,20)`, `(17,20)`, `(18,20)`, `(19,20)` open
- upper transition band:
  - `(15,17)`, `(16,17)`, `(17,17)`, `(18,17)`, `(19,17)` open

Additional live-validated open anchors:

- `(13,16)`
- `(14,16)`
- `(15,17)`
- `(16,18)`
- `(20,18)`

## Confirmed Hard Boundaries

These were confirmed as real map walls during live inspection/probing and do
not currently look stale:

### Upper / east side

- `16,16`
- `17,16`
- `18,16`
- `19,16`
- `20,17`
- `21,18`
- `21,19`

### Lower / southeast side

- `18,21`
- `19,21`
- `20,20`

### Lower / southwest side

- `16,21`
- `17,21`

### Interior walls already holding

- `15,16`
- `15,19`

The important shape result:

- row `17` remains open across the chamber until it stops at `20,17`
- the row above it (`y=16`) is blocked on the east side from at least
  `16,16` through `19,16`
- row `20` remains open until the southeast corner at `20,20`
- the south edge is blocked along at least `16,21` through `19,21`

## Verified Open / Blocked Transitions

Useful high-confidence local transitions:

### Open

- `(15,17) -> (14,17)`
- `(15,17) -> (16,17)`
- `(15,17) -> (15,18)`
- `(16,18) -> (16,17)`
- `(16,18) -> (17,18)`
- `(16,18) -> (16,19)`
- `(17,19) -> (18,19)`
- `(18,20) -> (19,20)`
- `(19,19) -> (20,18)` via `NORTH, EAST`

### Blocked

- `(15,17) -> (15,16)`
- `(16,17) -> (16,16)`
- `(20,18) -> (20,17)`
- `(20,18) -> (21,18)`
- `(20,19) -> (21,19)`
- `(20,19) -> (20,20)`
- `(17,20) -> (17,21)`
- `(16,20) -> (16,21)`

## What Was Not Confirmed

No new stale hardcoded cells were proven in this pass.

No new hidden blockers were proven in this pass.

This pass was mainly about replacing a bad mental model ("isolated blocked
pocket") with a live-validated chamber map.

## Best Resume Point

Resume from the upper/east transition edge. The best next probe target is:

- continue east/northeast from the open band at `row 17`
- verify whether the chamber fully terminates at the `20,17 / 21,18 / 21,19`
  corner or reconnects somewhere farther north/west through another opening

If resuming with live commands, the cleanest next loop is:

```bash
./dw_commands.sh log_state
./dw_commands.sh inspect_move:RIGHT
./dw_commands.sh inspect_move:UP
./dw_commands.sh debug_pathfind_to:X,Y
./dw_commands.sh trace_path
./dw_commands.sh validate_path
```

Use `trace_path` before `validate_path` whenever testing a multi-step route.
Now that validation is fixed, any mismatch between trace and walk should be
treated as a real gameplay/collision issue again.

## Relevant Files

- `path_debug.lua`
  - validator repair: planned-coordinate anchoring, desync abort, active-step
    cancellation on success
- `auto_step.lua`
  - still uses the one-time internal timeout retry behavior
- `map_reader.lua`
  - no new changes needed from this pass

## Local Verification

Latest local checks were clean:

- `lua test_pathfinder.lua`
- `python3 run_tests.py --allow-missing-speech-dep`

Only the expected speech dependency warning remains in this WSL environment.
