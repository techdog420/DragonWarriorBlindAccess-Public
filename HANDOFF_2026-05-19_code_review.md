# Handoff — 2026-05-19 Code Review Cleanup

Code review of the weekend's work (FCEUX stale-Alt containment, overworld routes, town/dungeon map decoding) followed by targeted fixes.

## What landed

Five commits, all on `main`:

| Commit  | Title |
|---------|-------|
| `095865a` | Remove dead FCEUX stale-Alt warning machinery |
| `5d873f3` | Drop dead duplicate Rimuldar (5,6) directional entry |
| `9661190` | Fix overworld route autowalk correctness gaps |
| `ac7a0a6` | Add route_manager integration tests for overworld autowalk |
| (this doc) | HANDOFF + memory refresh |

A prior commit `121dd94` "Solve Rimuldar magic key route" also rolled in the related dead-branch deletion in `main.lua` that the review flagged.

Full test suite (`python3 run_tests.py`) passes everywhere except the pre-existing `accessible_output2 missing` environment failure on this WSL host.

## Chunk-by-chunk

### Chunk A — `debug_tools.lua` cleanup (commit `095865a`)
- Removed the dead `_stale_fceux_keyboard` pause sentinel path: the flag was never set after commit `445474b`, but the consumer block in `main.lua` still tested it.
- Removed the disabled stuck-Alt speech path: `local should_speak = false` was hardcoded, making `speak_stuck_alt_warning`, the cooldown constants, and the `stuck_alt_last_spoken_frame` tracker all dead.
- Removed the duplicate `if not fceux_stale and not bridge_active then return nil end` guard that became unreachable after `445474b`.
- Trimmed the `INPUT_STUCK_ALT` log line to drop the always-false `spoken=%s` and always-zero `cooldown_remaining=%d` fields.

Net: ~25 lines deleted, zero behavior change today.

### Chunk B — `map_reader.lua` duplicate key (commit `5d873f3`)
- `MAP_DIRECTIONAL_BLOCKS[0x0B]` had two `["5,6"]` keys added in the same commit (`3a321ae`). Lua silently kept the later (more restrictive) `{north,south,west}` entry and dropped the earlier `{north,west}`.
- Replaced the earlier entry with a one-line comment explaining the redirect, so the audit-trail commentary above it remains coherent.

**Two contradictions I did NOT fix and why:**

- **Brecconary `(4,6)`** — present in both PASSTHROUGH (line 409) and BLOCKED_CELLS (line 1095). This is intentional layered design: the cell is engine-walkable so manual movement works, but BLOCKED forces autonomous pathfinding to avoid it because Woman 3 stands at (4,7). The comments at 405-408 and 1085-1092 document this. Not a bug.
- **Tantegel `(4,11)–(4,15)`** — BLOCKED_CELLS (line 1033, 2026-04-23 survey) shadows directional entries (lines 1201–1205, 1233) including a "y=13 reopened 2026-04-18" comment. This is an active evidence conflict between an April 18 direct probe and an April 23 survey, not a code bug. Resolving it requires your call on which evidence is correct.

### Chunk C — Overworld route correctness (commit `9661190`)

Three real bugs from the review, plus the perf nit:

1. **`is_overworld` divergence.** `overworld_routes.is_overworld(map_id)` only checked `map_id == 0x01`, while the canonical `maps.is_overworld(map_id, terrain_offset)` also accepts `terrain_offset == 0`. During the single-frame transition out of a town, `snapshot.map_id` can lag while `terrain_offset` has already flipped, producing spurious "only available on the world map" refusals.
   - Routed the module through `maps.is_overworld`.
   - Added optional `terrain_offset` to `observe_position` (4th arg) and `plan_next_segment` (`opts.terrain_offset`).
   - `main.lua` and `route_manager.lua` now pass `snapshot.terrain_offset`.

2. **Autowalk stalls on a waypoint tile.** Old behavior: `plan_next_segment` returned `already_at_waypoint` with zero steps; `autowalk_overworld_segment` spoke "Already at overworld waypoint" and returned without advancing. Since `observe_position` only advances on a real position change, the route was a permanent no-op until the player moved.
   - Added `opts.advance_if_at_waypoint` flag. When set, `plan_next_segment` bumps `state.next_index` and replans once.
   - `route_manager.autowalk_overworld_segment` now opts in.
   - Status queries via `M.status` etc. keep the old behavior.

3. **`autowalk_to_object` cross-talk.** On the overworld, `autowalk_to_object` was dropping its `obj` argument and silently advancing whatever route was active. Selecting Garinham with a Brecconary route active would advance Brecconary.
   - Now checks `overworld_routes.route_id_for_object(obj, ...)` against `active_route_id()`.
   - If they differ, calls `overworld_routes.start(target_route_id, ...)` first.
   - Surfaces start errors as `status = "route_start_failed"`.

Perf nit: hoisted `require("overworld_routes")` from the per-frame field loop in `main.lua` to a module-level local.

### Chunk D — Persistent memory refresh
The auto-memory at `~/.claude/projects/-mnt-d-modding-DragonWarrior1/memory/MEMORY.md` was 60 days stale, with a map-ID table that disagreed with `maps.lua` and a wrong override-order rule (claimed PASSTHROUGH → DOOR → BLOCKED → table; reality is BLOCKED is overlaid last).

- Rewrote `MEMORY.md` as a sparse index.
- Created `map_overrides.md`, `fceux_stale_alt.md`, `scroll_formula.md` capturing the facts genuinely worth keeping.
- Added `code_review_investigation.md` capturing the feedback lesson: do not auto-fix map_reader contradictions; investigate per-cell evidence first.
- Removed the wrong map-ID table and Map 4 layout sections that duplicated `maps.lua` and code.

### Chunk E — Integration tests (commit `ac7a0a6`)
Added four `test_route_manager.lua` tests covering the route-switch and advance-opt paths introduced in Chunk C:
- `overworld_autowalk_forwards_advance_opt_to_planner`
- `overworld_autowalk_to_object_switches_routes_when_destination_differs`
- `overworld_autowalk_to_object_skips_switch_when_same_destination`
- `overworld_autowalk_to_object_reports_start_error_without_planning`

Extended the `overworld_routes` test stub with `active_route_id`, `route_id_for_object`, and `start` spies plus a `plan_next_segment` opts log.

Also added two tests to `test_overworld_routes.lua` covering the terrain_offset acceptance and the `advance_if_at_waypoint` path.

## Findings I reported but did NOT fix

Three review findings turned out not to be real bugs after deeper investigation:

1. **"Overworld route state persists across interior map descent."** Reviewed live: `observe_position` calls `finish_route` on the first frame where `map_id` matches `destination_maps`, which clears `state.active_id`. Subsequent frames see `route = nil` and return early. No spurious second arrival. The agent's claim was based on incomplete reading.
2. **"`is_destination_map` only-on-overworld guard needed."** Same root cause — `finish_route` already clears state, so the guard isn't needed.
3. **"`M.start` recalculate-message-after-staging-swap"** — cosmetic edge case, no real impact.

## Open items still on the review board

Updated 2026-05-20 after Codex follow-up cleanup:

- **Resolved: terrain-offset propagation.** Route start/status/guidance paths now accept and pass `terrain_offset`, matching autowalk/observe behavior during one-frame town-exit map-id lag.
- **Resolved: `position_key` allocation.** `overworld_routes.observe_position` now compares cached numeric map/x/y fields instead of concatenating a string each observed frame.
- **Resolved: `safety` / `safe` alias scope.** `safe` and `safety` are now contextual pseudo-aliases over Brecconary and Tantegel; `town` and `first town` still mean Brecconary.
- **Still open: Tantegel `4,11–4,15`.** Defer until the upcoming Tantegel locked-door/quest-item mapping pass; clean live evidence should pick between the April 18 reopen evidence and the April 23 survey before changing `MAP_BLOCKED_CELLS` or directional entries.
- **Still open: radius-0 waypoint chains / waypoint validation.** `map_reader` explicitly skips overworld grids, so true load-time walkability validation against `map_reader` is not available yet. Do not widen radius-0 waypoints blindly; first decide whether to build a real overworld passability/route-validation source or add a narrower route-data diagnostic.
