# Safe NPC Parking Origin Guard Design

Date: 2026-07-17
Status: Approved

## Goal

Prevent automatic NPC parking from turning a real `(0,0)` route cell into an
engine blocker, without moving NPC slots to another synthetic coordinate or
adding new RAM writes.

## Proven Root Cause

Rimuldar's verified Magic Key Merchant route crosses `(1,0)->(0,0)`. During
auto-walk, mobile NPC parking preserved each slot's high bits and movement byte
but changed its low coordinates to `(0,0)`.

The Dragon Warrior ROM treats `(0,0)` differently in two subsystems:

- NPC update and rendering skip slots whose low X and Y are both zero.
- player-to-NPC collision scans all 20 slots, masks their low five coordinate
  bits, and does not skip `(0,0)`.

Consequently, every parked slot occupies `(0,0)` for collision even though it
is not updated or rendered. With parking enabled, the marked Rimuldar entry
failed every attempt. With only `auto_walk_park_mobile_npcs=false` reloaded,
the same marked entry succeeded on its first attempt.

## Constraints

- Do not choose another synthetic NPC coordinate. `(31,31)` previously kept
  slots renderer-active and could hard-lock the ROM's OAM clear loop; the ROM
  provides no universally safe per-slot alternative.
- Do not change NPC entry layout, high bits, movement bytes, adjacent RAM, or
  ROM code.
- Preserve existing parking behavior on maps where `(0,0)` is not modeled as
  walkable.
- Preserve live-NPC planning, blocking, rerouting, and logging as the fallback.
- Keep the configuration default for experimental parking disabled.

## Approaches Considered

### Chosen: map-origin safety guard

Before starting proactive auto-walk parking, query
`map_reader.is_walkable(map_id, 0, 0)`. If it is true, refuse parking for that
route, log the map and reason, and plan in `live_npcs` mode. Otherwise retain
the existing parking path.

This is conservative: a map with a legitimate origin may skip parking even
when a particular route does not cross it. That is preferable to silently
changing engine passability and keeps the fix independent of planner timing or
later reroutes.

### Rejected: path-aware two-pass parking

Plan with live NPCs, inspect whether the path crosses `(0,0)`, then optionally
park and replan. This is more precise but fails when a roaming NPC prevents the
first plan and adds stateful two-plan behavior to every auto-walk.

### Rejected: alternate parking coordinate

No coordinate is both invisible to NPC update/render logic and ignored by
collision. Off-map alternatives remain renderer-active and risk the prior OAM
failure. Changing slot bytes beyond coordinates would be speculative RAM or
ROM manipulation.

## Implementation

Add one route-manager predicate that answers whether mobile parking is safe on
the current map. Apply it before `start_autowalk_npc_parking()` in the standard
auto-walk entry path. A safety refusal must leave parking inactive and use the
normal `live_npcs` planning mode.

Emit one structured line:

`AUTO_WALK_NPC_PARK_SKIP map=0xNN reason=walkable_origin origin=(0,0)`

Do not change manual freeze, target hold, map survey, NPC restoration, or
reactive parking behavior in this focused repair. Reactive parking cannot be
entered for a route whose active NPC mode is `live_npcs`.

## Tests

Write the regression first and confirm it fails because parking still writes
NPC coordinates on a map with a walkable origin. The passing assertions must
show:

- configuration requests mobile parking;
- `(0,0)` is modeled walkable;
- no NPC parking RAM writes occur;
- the queued plan records `npc_mode=live_npcs`;
- the structured skip reason is logged.

Retain existing coverage proving that a map with non-walkable `(0,0)` still
parks mobile NPCs. Run the full route-manager suite and repository test runner.

## Live Acceptance

After manual Lua reload, restore `auto_walk_park_mobile_npcs=true` to exercise
the guard rather than relying on the temporary configuration bypass. From
Rimuldar `(1,0)`, the isolated route to `(0,0)` must log the parking skip and
cross without a cadence or seam retry.

Then validate the actual 52-step route from normal entry `(29,14)` to the Magic
Key Merchant stand `(4,5)`, facing south, using normal movement, no teleport,
and no runtime blocks. Repeat the complete route before declaring it fixed.

The isolated test's later west-boundary transition remains review evidence,
not part of this parking change. Address it only if the real route, which turns
south from `(0,0)`, reproduces the transition or fails to continue.
