# Darkness Parity Design

Status: first slice and local-report/config-opt-out slice live-verified on `codex/darkness-parity`

## Goal

Preserve Dragon Warrior's dungeon-darkness information limits while providing
an equivalent nonvisual understanding of the area the hero can currently see.
Darkness must not expose the full decoded dungeon through object browsing or
path previews, but it must also not reduce exploration to unexplained guessing.

## Source model to validate live

- Dungeon/cave terrain uses terrain offset `0x20`.
- `LIGHT_RADIUS` at RAM `0x00D0` uses odd visible-window diameters: `1`, `3`,
  `5`, and `7`.
- The corresponding visible half-span is `floor(LIGHT_RADIUS / 2)`, producing
  the current tile only, then one, two, or three tiles in every direction.
- `RADIANT_TIMER` at RAM `0x00DA` distinguishes Radiant light from ordinary
  Torch light and supports later expiry diagnostics.

These interpretations are covered deterministically and are now confirmed in
FCEUX during unlit, Torch, Radiant, moving-window, shrink, and fade states.

## First slice

1. Add one central darkness module that describes the current visible span,
   tests whether a cell is visible, and can mask a decoded walkability grid.
2. Announce darkness on dungeon entry and announce only meaningful radius
   changes, not every Radiant timer decrement.
3. Limit ordinary object browsing to objects inside the current visible square.
   Re-evaluate visibility when the hero moves or the light radius changes.
4. Limit ordinary selected-object path previews and reachability descriptions
   to the current visible square. Keep explicit developer coordinate probes and
   surveys unrestricted.
5. Add a read-only `report_light_state` command with structured logging for
   live validation.

## Deferred slices

- Dynamic darkness-aware auto-walk that moves only through currently visible
  information, stops or replans as the visible square moves, and never uses a
  decoded route hidden beyond the current light.
- Progressive discovery for clue-bound hidden treasure. This is related to
  information parity but remains separate from dungeon darkness.

## Local report and difficulty opt-out slice

1. `Shift+N` or `F21` gives an on-demand local report. It describes the four
   cardinal paths to either a blocker or the edge of the light, up to two
   fully visible nearby branches or turns, and up to four objects whose cells
   are physically inside the current light square.
2. The report never uses decoded information beyond the physical light square,
   including when the navigation restriction is disabled.
3. `darkness_navigation_limits=true` remains the default. Setting it to
   `false` restores unrestricted decoded object browsing, path previews, and
   auto-walk planning for players who find darkness too difficult and for
   debugging. The game's light, light-state announcements, and local report
   remain unchanged.
4. The `visible_area` debug command speaks the same report and logs it under a
   `VISIBLE_AREA` prefix for repeatable live validation.

## Acceptance

Use Erdrick's Cave B1 as the initial live test bed.

1. Enter without a light source and run `report_light_state`.
2. Browse Travel and Treasure objects; only cells in the reported visible
   square should appear.
3. Use a Torch, then repeat the report and browsing checks.
4. Cast Radiant, repeat the checks, and walk until the visible radius shrinks.
5. Confirm each radius change is announced once and that newly visible objects
   appear without reloading the script.
6. Confirm an ordinary path preview cannot route outside the visible square.
7. Confirm explicit debug path and map-survey commands remain available for
   development work.

## Live acceptance result

Erdrick's Cave B1 passed the first-slice matrix on `2026-09-04`. Unlit entry
reported raw radius `1`; Torch expanded it to `3`; Radiant expanded through
`5` to `7`. Manual movement then produced exactly one structured event for
each meaningful shrink: `7` to `5` at frame `198101`, `5` to `3` at frame
`209831`, and `3` to `1` at frame `274265`. Object browsing followed the
moving square and hid the adjacent entrance once the half-span reached zero.
The corrected Radiant cast dialogue was also accepted live.

Important light-change warnings now wait for a short input-idle window so held
directional input does not discard them.

The local-report and config-opt-out slice passed live acceptance on
`2026-09-06`. At B1 `(0,0)`, Radiant reported the three-tile light boundary,
local blockers, a turn, a branch, and the entrance on the current tile. After
moving to `(1,0)`, it recomputed the paths and reported the entrance one tile
west. Reloading the unlit entrance state produced only the current tile and
entrance, with no neighboring terrain. With `darkness_navigation_limits=false`,
the same report remained physically light-bounded and explicitly disclosed
unrestricted assistance; object browsing and auto-walk then selected the
distant B1 down stairs and completed the decoded route to `(9,8)`. The default
was restored to `true` and confirmed live after the test.
