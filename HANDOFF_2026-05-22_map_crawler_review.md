# Handoff — 2026-05-22 Map Crawler Review + Hardening

Deep review of the new `map_crawler.lua` tool and supporting integrations, followed by two critical bug fixes, a round of comment cleanup, a new export-file feature, and TTS finish announcements. One commit on `main`; tree is clean.

## What landed

Single commit (this one) on top of `9ff005d`. Three files touched:

| File                  | Net change |
|-----------------------|-----------:|
| `map_crawler.lua`     | +234 / -7  |
| `test_map_crawler.lua`| +379 / -0  |
| `main.lua`            | +17 / -2   |

Test suite: `lua5.1 test_map_crawler.lua` — **32 passed** (was 23 at start of session).

## Review findings

Initial deep review identified two critical issues and several minor cleanup items. All addressed in this pass.

### Critical 1 — Indefinite hang when `auto_step` silently drops the in-flight step

**Root cause:** `tick_impl` returned early whenever `state.active_edge ~= nil`, waiting for `route_step_completed` or `route_blocked` to clear it. But `auto_step.lua` has two production paths that silently reset the in-flight step without emitting either event:

- `auto_step.lua:798` — when `can_walk` drops to false (battle, dialogue, menu opens mid-probe). `emit_route_cancelled` is only fired if `had_route` was true; inject_step probes have no queued route.
- `auto_step.lua:971-985` — when a different live direction is pressed. Same `had_route` gate.

A third path (line 776, auto_step config disabled) is also silent but unlikely during a debug session.

**Fix:** In `tick_impl`, when `state.active_edge` is set, poll `auto_step.get_active_step_state()`. If it returns nil, the in-flight step was silently dropped → record an `auto_step_lost` diagnostic edge and `finish_run(false, "auto_step_lost")`.

The new `auto_step_lost` classification deliberately does **not** match any of `record_edge`'s candidate-promoting `elif` branches, so it shows up in `report.edges`, `report.counts`, and the `MAP_CRAWL_EDGE` log line but never pollutes `passthroughs` or `directionals`. A lost step tells us nothing reliable about geometry.

**Why polling beats other options:**
- Option A (make `auto_step` emit `route_cancelled` for inject_step too) — would touch `auto_step.lua` in three spots and could subtly alter behavior for `route_manager` / `map_survey` subscribers.
- Option B (frame-counter timeout in crawler) — arbitrary threshold; risk of false positives on legitimately slow steps.
- Option C *(chosen)* — deterministic, self-contained, no `auto_step` changes. Works because `map_crawler.tick` runs *before* `auto_step.update` in `main.lua`'s per-frame loop, so the orphan is detected the frame *after* the silent reset.

### Critical 2 — Failed backtracks polluted directional candidates

**Root cause:** When a backtrack edge failed in `handle_blocked`, `classify_blocked` was called and typically returned `directional_block_candidate`. The `record_edge` elif promoted that into `report.directionals` for the parent cell before `finish_run(false, "backtrack_blocked")` fired. A failed backtrack is more likely a transient (mobile-NPC re-spawn, timing edge, position desync) than real one-way geometry, and we already walked the opposite direction across that same edge. Recording it as a candidate was misleading.

**Fix (two coordinated edits):**

1. In `handle_blocked`, when `edge.kind == "backtrack"`, skip `classify_blocked` entirely. Override the classification to `"backtrack_blocked"` with note `"backtrack_to_parent_blocked"`.
2. In `record_edge`, dropped `backtrack_blocked` from the directional-promote `elif` (it was already a dead branch — no producer ever set that classification before this change).

After both edits, a failed backtrack:
- Still appears in `report.edges` and the `MAP_CRAWL_EDGE` log line.
- Counts in `report.counts["backtrack_blocked"]`.
- Triggers the existing abort path.
- Does **not** appear in `report.directionals` → `export_candidates` won't emit a directional line for the parent cell.

**Why not mark the parent unstable?** Probes from the parent that completed *before* the backtrack failed are still valid observations; the failure only tells us we can't safely DFS further. Demoting clean prior data would be over-aggressive.

## Minor cleanup

All comments-only changes in `map_crawler.lua`:

- **`mark_unstable_candidate`** — comment block explaining the intentional asymmetry: passthroughs are pruned when a cell goes unstable, but directionals (which are destination-keyed) are not. A probe from an unstable origin into a different destination is still a valid observation of the *destination*.
- **`handle_step_complete`** OOB else-branch — comment flagging it as defensive. `maybe_prepare_probe` rejects out-of-bounds destinations before injection in normal flow.
- **`classify_blocked`** — comment explaining why the second `stationary_npc_at` scan isn't cached from preflight. Mobile NPCs can escape parking mid-step; the duplicate check is the whole point.
- **`event_bus.subscribe` block** — comment noting that hot-reload yields harmless duplicate handlers thanks to the early-return guards inside each handler.

## Game-state guard

Added to `main.lua`'s `crawl_map_frontier` command (not the module — keeps the crawler test-friendly without needing to mock `state.lua`):

- Refuse start unless `game_state.state == state.STATE_FIELD`.
- Refuse start if `menu.is_open() or PREV.dialogue ~= "" or PREV.upper_active`.

Same speech/log pattern as the existing survey and auto-walk guards.

## Export file feature

The crawler now auto-writes a per-map Lua-snippet file on every `finish_run`.

**Path:** `<script_dir>/dw_crawl_<mapid_hex_lowercase>.txt` (matches the convention used by `debug_tools.lua` for `dw_debug.log` et al). One file per map; overwrites on each new crawl of that map.

**When written:** On every `finish_run` — successful completion, `max_edges` cap, `manual_stop`, `auto_step_lost`, `backtrack_blocked`, etc. Even aborted runs may have salvageable candidates worth preserving.

**Format:** Lua-snippet form with comment header, intended to be both paste-ready into `map_reader.lua` and grep-friendly for agents.

```lua
-- Map crawler export
-- map: 0x0B (Rimuldar)
-- run: 7
-- completed: true
-- reason: complete
-- timestamp: 2026-05-22T19:30:15Z
-- edges: 42  passthrough: 3  directional: 5  stationary_npc: 2  door_frontier: 1  unstable: 0
--

-- MAP_PASSTHROUGH_CELLS additions (3):
["12,5"] = true,
["13,5"] = true,
["14,5"] = true,

-- MAP_DIRECTIONAL_BLOCKS additions (5):
["8,9"] = {north = true, east = true, south = true},
["12,19"] = {east = true, south = true},
["14,20"] = {west = true, south = true, east = true},
["15,21"] = {north = true, south = true},
["19,16"] = {south = true},

-- Stationary NPC cells (2, informational):
--   "3,3" -> npc_slot 0
--   "7,4" -> npc_slot 3

-- Closed door frontiers (1, informational):
--   "10,6" -> door at (10,6)
```

**Logging:** Each successful write emits a `MAP_CRAWL_EXPORT_FILE run=N map=0xXX path=...` line; failures log `MAP_CRAWL_EXPORT_FILE_FAIL ... error=...` and do not block the rest of finish_run.

**Implementation:**
- Forward-declared `local write_export_file` and `local speak_finish_summary` near the existing module locals.
- Bodies defined after `format_direction_table` (the only dependency).
- `script_dir` derivation matches `debug_tools.lua` (uses `debug.getinfo(1, "S").source`).
- Map name from `maps.get_name(map_id)` in the header.

## TTS finish announcements

`finish_run` now always emits exactly one tolk message describing the outcome and salvaged candidate counts.

- **Natural finish:** `"Map crawl complete. 3 passthrough, 5 directional."`
- **Manual stop:** `"Map crawl stopped. 3 passthrough, 5 directional."`
- **Other aborts (`max_edges`, `auto_step_lost`, `backtrack_blocked`, `map_change`, etc.):** `"Map crawl ended: max_edges. 3 passthrough, 5 directional."`
- **`low_hp`:** *skipped* (the abort handler already spoke `"HP critical (N)."`).
- **`script_error`:** `"Map crawl errored. Check log."` — no candidate counts to avoid misreporting from a half-broken state.

**Double-speak avoidance:** `M.stop()` now returns `(true, nil)` for the immediate-finish branch (instead of `"Stopped map crawl on map XX"`). `finish_run` does the announcement. The deferred-settle branch still returns `"Stopping map crawl on map XX"` so the user gets immediate feedback that the stop was heard; `finish_run` then speaks the summary once the settle lands.

`main.lua`'s `stop_map_crawl` command nil-guards the returned message.

## Tests added (9 total)

| Test | Verifies |
|------|----------|
| `failed_backtrack_finishes_without_promoting_parent_candidate` | Critical 2 fix: failed backtrack writes `backtrack_blocked` diagnostic but does not promote the parent. Sibling directionals collected before the backtrack still export. |
| `auto_step_silently_cleared_aborts_without_hanging` | Critical 1 fix: silent `auto_step` reset triggers `auto_step_lost` abort instead of hanging. |
| `deep_dfs_backtracks_through_multiple_frames` | Two-level DFS pop (depth 3 → 2 → 1); asserts inject order and `kind=backtrack` count. |
| `max_edges_limit_finishes_with_max_edges_reason` | Cap triggers `finish_run(false, "max_edges")` cleanly. |
| `pending_repress_into_open_floor_stays_open_floor` | Inverse of the existing pending-repress test: model-walkable destination must classify as `open_floor`, not escalate to `timing_suspect`. |
| `open_door_pushes_dfs_frame_for_further_exploration` | DFS continues past an open door; next probe originates from the door cell. |
| `complete_finish_writes_export_file_with_lua_snippets` | Export file written with correct header, paste-ready passthrough and directional lines, log line, and finish speech. |
| `aborted_finish_still_writes_export_file_with_failure_reason` | `max_edges` abort still writes the file with `completed=false reason=max_edges` and salvaged candidates. |
| `manual_immediate_stop_speaks_finish_summary_only_once` | Immediate-stop path returns nil msg and emits exactly one finish announcement (no double-speak). |

**Test env additions to `make_env`:**
- `clear_auto_step_state()` — simulates `auto_step`'s silent reset.
- `io.open` interception for write-mode (read-mode passes through to real `io.open` so package loading is unaffected).
- `list_captured_paths()`, `get_captured_file(path)` for inspecting captured writes.

## Files changed

- `map_crawler.lua` — orphan detection, backtrack classification fix, export file writer, speech helper, four comment blocks.
- `main.lua` — `crawl_map_frontier` state guards; `stop_map_crawl` nil-guard.
- `test_map_crawler.lua` — io.open mock, three new env helpers, nine new tests.

## What I did NOT change

- **`MANUAL_STOP_SETTLE_FRAMES = 30`** — judged not worth a config knob for a debug tool.
- **`auto_step.lua`** — deliberately untouched. Orphan detection happens crawler-side via polling.
- **`map_survey.lua` export format** — separate tool, separate file pattern.
- **Structured JSON export** — Lua-snippet format chosen per user preference (paste-ready into `map_reader.lua`).
- **Filename in speech announcement** — would add noise; agents/users can find the path via the `MAP_CRAWL_EXPORT_FILE` log line.

## Open items / future follow-ups

- The `MANUAL_STOP_SETTLE_FRAMES` constant could become configurable if a future map exposes slower tile transitions.
- Per-map export files accumulate across crawls of different maps. A `dw_crawl_*.txt` cleanup helper could pair with `reset` if the directory gets cluttered.
- The crawler's `find_run` path always writes the file even when there are zero candidates (the file documents the empty result). Reasonable; revisit only if users complain about churn.
