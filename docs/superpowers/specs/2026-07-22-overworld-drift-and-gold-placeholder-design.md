# Overworld Final-Drift and GOLD Placeholder Design

Date: 2026-07-22

## Goal

Remove two blockers found during live Hauksness validation:

1. Overworld auto-walk can reach the final tile of a segment and then carry one
   extra tile in the same direction during neutral final settle. The segment
   currently cancels as `route_drift_off_path` even though it reached its
   waypoint first.
2. PPU byte `0xF5` decodes as the placeholder `[GOLD]`. On the overworld, the
   same byte can occur in background data and leak into ordinary command
   results such as `There is no one [GOLD] there.`

## Scope

This change is limited to overworld segment completion and filtered lower
dialogue assembly. It will not alter permanent map data, movement RAM, parked
NPC handling, the global character table, merchant price handling, or literal
`GOLD` words rendered as normal letters.

The theory that moving parked NPCs away from cell zero may have removed the
earlier movement-RAM corruption trigger remains unconfirmed. Movement-state
reset stays disabled and is not part of this work.

## Overworld final-drift behavior

`route_manager.lua` will opt overworld segment auto-walk into the existing
final-drift completion mechanism.

`auto_step.lua` will accept a final-settle drift only when all of these are
true:

- the route explicitly opted in;
- the route had already completed its final planned step;
- the live position is exactly one tile beyond the planned endpoint;
- the extra tile is in the same direction as the final planned step.

An accepted carry completes the segment from the live position. The next
player `auto_walk` command will plan the next waypoint from that live tile.
Sideways, reverse, diagonal, multi-cell, map-changing, or pre-final-step drift
continues to cancel as `route_drift_off_path`.

This approach does not write `$003C/$003D` or any other gameplay RAM.

## GOLD placeholder filtering

`text.lua` will remove the exact literal token `[GOLD]` while assembling
filtered PPU dialogue rows. Whitespace will be normalized after removal.

The filter will preserve:

- literal `GOLD` rendered from normal letter tiles;
- reward text such as `Of GOLD thou hast gained 12`;
- price questions such as `Wilt thou buy it for 52 GOLD?`;
- merchant speech produced from decoded prices and snapshot gold.

The global `chars.lua` mapping remains unchanged because other readers may
still use the placeholder diagnostically.

## Tests

Test-first coverage will establish:

- an opted-in exact one-cell same-direction final carry completes;
- a sideways final drift still cancels;
- a reverse final drift still cancels;
- a two-cell final drift still cancels;
- overworld segment queuing opts into guarded final-carry completion;
- `[GOLD]` is removed from the reproduced TALK and STAIRS responses;
- genuine literal `GOLD` reward and price text remains unchanged.

Focused Lua tests, bytecode compilation, and `git diff --check` must pass.
FCEUX then requires a manual `main.lua` restart. Live verification will resume
the Hauksness route from the current World Map state and repeat a command-menu
response on an overworld cell containing `0xF5` background data.

## Failure handling

If the live drift is not exactly a one-cell continuation, auto-walk remains
conservative and cancels. If `[GOLD]` still appears after reload, the raw and
filtered PPU rows will be logged again before broadening the filter.
