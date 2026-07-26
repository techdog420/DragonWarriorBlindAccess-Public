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

The waypoint chain will be the exact reverse of all 58 waypoints in
`hauksness_cantlin`. Names will describe travel toward Cantlin, and the warning
will remain near Hauksness so the player hears the danger notice at the start.
The first step away from Hauksness and the final Cantlin approach will use
strict zero-radius anchors.

`return from hauksness` will remain assigned only to the existing Kol route to
avoid an alias collision.

## Selection and Runtime Behavior

Selecting the ordinary Cantlin Travel object near Hauksness should choose
`cantlin_hauksness`. Starting by an explicit route alias should produce the
same route.

The existing route manager will retain the route through random battles and
resume from the current waypoint afterward. Entering map `0x0A` will announce
arrival and clear the active route.

No new permanent map blockers, runtime blockers, movement timing changes, or
route-manager semantics are part of this change.

## Test-First Coverage

Focused tests will establish:

1. Cantlin selection from the Hauksness entrance chooses
   `cantlin_hauksness`.
2. The explicit Hauksness-to-Cantlin aliases resolve without colliding with the
   existing Kol return alias.
3. The waypoint coordinates exactly reverse `hauksness_cantlin`.
4. Selection at the entrance advances past the current Hauksness anchor and
   targets the doorstep-west waypoint.
5. The final Cantlin anchor remains strict and entering map `0x0A` completes
   and clears the route.
6. Existing Hauksness, Kol, and Cantlin-to-Hauksness route behavior remains
   unchanged.

## Live Validation

After the Lua script is manually reloaded, validation will begin from the
Hauksness entrance with a fresh probe and no active route.

The route will be walked normally to Cantlin. Battles are expected and are not
route failures. After each interruption, the live state will be freshly
checked before continuing.

Movement failures will be classified before any source change:

- planner error,
- execution or settle-timing issue,
- battle or dialogue interruption,
- transition behavior,
- or repeated same-origin engine blockage.

The final northern Cantlin approach is intentionally tested as the true reverse
of the validated outbound route. If it proves unreliable, validation will stop
at the failure and the final segment may be redesigned to use the independently
proven southern entry from `(73,103)` by stepping `UP`. A single failure will
not be promoted into permanent map data.

## Documentation and Publication

Once live validation succeeds, update `session_handoff.md` and
`PLAYTESTING.md` with the exact result and any recoverable timing observations.
Commit and push the implementation and evidence to the existing branch so PR
#4 contains both directions.
