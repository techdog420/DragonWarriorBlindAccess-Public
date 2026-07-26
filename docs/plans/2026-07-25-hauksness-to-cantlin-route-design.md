# Hauksness-to-Cantlin Route Design

## Goal

Add a named World Map route from the Hauksness entrance to Cantlin by reversing
the newly pinned and live-validated Cantlin-to-Hauksness route. Keep the work on
the existing `codex/cantlin-hauksness-return` branch and draft PR #4.

## Route Definition

- Route ID: `cantlin_hauksness`
- Title: `Cantlin`
- Target object: `overworld_cantlin`
- Destination map: `0x0A`
- Start anchor: Hauksness World Map entrance at `(25,89)`
- Final World Map anchor: Cantlin at `(73,102)`
- Aliases:
  - `cantlin from hauksness`
  - `hauksness to cantlin`
  - `return to cantlin`

The final waypoint chain contains 57 strict waypoints. It follows the reverse
of `hauksness_cantlin` except for two validation-driven north-carry splices:

- `(50,100)->(50,99)` carries to `(50,98)`, replacing the reverse-only
  `(51,99)->(51,98)` jog.
- `(64,93)->(64,92)` carries to `(64,91)`, replacing the reverse-only
  `(68,92)` approach.

Names describe travel toward Cantlin, and the warning remains near Hauksness so
the player hears the danger notice at the start. The first step away from
Hauksness and the final Cantlin approach use strict zero-radius anchors.

`return from hauksness` will remain assigned only to the existing Kol route to
avoid an alias collision.

## Selection and Runtime Behavior

Selecting the ordinary Cantlin Travel object near Hauksness should choose
`cantlin_hauksness`. Starting by an explicit route alias should produce the
same route.

The existing route manager will retain the route through random battles and
resume from the current waypoint afterward. Entering map `0x0A` will announce
arrival and clear the active route.

No permanent or runtime map blockers and no route-manager semantics changed.
The two north-entry waypoints use route-local sustained-hold, extended
early-twitch, and carry-preserving settle controls. The final Cantlin waypoint
uses horizontal-first recovery so an east-column settle corrects west before
descending.

## Test-First Coverage

Focused tests will establish:

1. Cantlin selection from the Hauksness entrance chooses
   `cantlin_hauksness`.
2. The explicit Hauksness-to-Cantlin aliases resolve without colliding with the
   existing Kol return alias.
3. The waypoint coordinates reverse `hauksness_cantlin` except for the two
   explicitly asserted live carry splices.
4. Selection at the entrance advances past the current Hauksness anchor and
   targets the doorstep-west waypoint.
5. The final Cantlin anchor remains strict and entering map `0x0A` completes
   and clears the route.
6. Existing Hauksness, Kol, and Cantlin-to-Hauksness route behavior remains
   unchanged.

## Live Validation Result

Completed on 2026-07-26 from the Hauksness entrance with a fresh script and no
active route.

The route walked normally to Cantlin. Battles and a REPEL-expiry dialogue
interrupted the run without losing safe route recovery. The two north entries
produced the carry landings described above. The final east lane settled at
`(74,91)`; horizontal-first recovery from `(74,99)` moved left to `(73,99)`
before descending.

Movement failures will be classified before any source change:

- planner error,
- execution or settle-timing issue,
- battle or dialogue interruption,
- transition behavior,
- or repeated same-origin engine blockage.

The final northern Cantlin approach entered town from `(73,101)`. The route
emitted arrival at waypoint 57 and landed on map `0x0A` at `(15,0)`. A fresh
probe confirmed route `none`, neutral controller input, and no runtime blocks.
No permanent blocker was added.

## Documentation and Publication

Once live validation succeeds, update `session_handoff.md` and
`PLAYTESTING.md` with the exact result and any recoverable timing observations.
Commit and push the implementation and evidence to the existing branch so PR
#4 contains both directions.
