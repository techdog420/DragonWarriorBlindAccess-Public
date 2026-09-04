# Darkness Parity Design

Status: first slice source-complete and live-verified on `codex/darkness-parity`

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
- Full map-description and nearby-tile narration constrained by the same
  visibility policy.
- Progressive discovery for clue-bound hidden treasure. This is related to
  information parity but remains separate from dungeon darkness.

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

Held directional input can interrupt light-change speech at the screen-reader
level. Reliable post-input delivery for important warnings is a separate
speech-polish follow-up; the structured events and visibility behavior are
correct.
