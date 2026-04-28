# Handoff 2026-04-22 — East Wing y=4 Corridor Fix

## What happened this session

### Survey run 2 analysis (map 0x04)

Launched `survey_objects:park_npcs` from `(10,8)`. Completed 29/29 targets:

```
successes=7  gated_or_isolated=6  suspected_engine_blocked=1  state_issues=15
```

**7 successes** (center/west main hall):
- Guard 6, Guard 7, Stairs Up to Throne Room, Person 2, Merchant 2, Guard 3, Stairs Down to Throne Room

**6 gated_or_isolated** (west wing, magic-key door — expected):
- chest_0 (1,13), chest_1 (1,15), chest_2 (2,14), chest_3 (3,15), Guard 4 (2,14), Person (1,7)

**1 suspected_engine_blocked** — Guard 1 (13,2):
- Stalled at (7,4), suspected_tiles=`4,7|3,6|7,3`

**15 state_issues** — every east-wing target:
- Guard 2, Guard 5, Guard 8, Guard 9, Guard 10, Guard 11, Merchant 1, Merchant 3,
  Old Man 1, Old Man 2, Woman 1, Woman 2, Door, Exit to World Map, Stairs Down to Treasure Room
- All 15 reported `suspected_tiles=6,2|6,1`
- All 15 ended at `final=(5,1)` — player walked from northwest staircase to x=5 then couldn't go east

### Root cause analysis

The survey visited "Stairs Down to Throne Room" at (1,1), leaving the player in the
northwest corner. All subsequent east-wing targets tried to go east from around (5,1)
and hit engine walls at `(6,1)` and `(6,2)`. No alternative route existed in the model
because `(8,4)` — the decoder-gap bridge between the western and eastern halves of the
y=4 passthrough corridor — was missing from MAP_PASSTHROUGH_CELLS.

Two model errors compounded the problem:
1. `(8,4)` unmodeled → A* couldn't bridge `(7,4)` east to the regular floor at `(9,4)+`
2. `(7,3)` had no `south=true` → A* planned false paths through `(7,4)→north→(7,3)`,
   which the engine blocks at runtime

### Probe campaign (probe_east_wing.sh)

Designed and ran a 18-probe systematic campaign. Key results:

| Probe | Status | Meaning |
|---|---|---|
| (5,1)→RIGHT→(6,1) | BLOCK `blocked_despite_open_preview` | (6,1) west=true confirmed |
| (5,2)→RIGHT→(6,2) | BLOCK `blocked_despite_open_preview` | (6,2) west=true confirmed |
| (5,4)→RIGHT→(6,4) | PASS (no mismatch) | existing passthrough works |
| **(7,4)→UP→(7,3)** | **BLOCK `blocked_despite_open_preview`** | **(7,3) south=true confirmed** |
| (7,3)→DOWN→(7,4) | PASS | can exit (7,3) south; only entry from below is blocked |
| (7,3)→RIGHT→(8,3) | PASS | east exit still works |
| (7,3)→UP→(7,2) | PASS, tile=6 | (7,3) accessible from above |
| **(7,4)→RIGHT→(8,4)** | **PASS `moved_through_modeled_block`** | **(8,4) is decoder gap — was missing** |
| (8,4)→RIGHT→(9,4) | PASS, tile=6 | regular floor, already walkable |
| (9,4)→(10,4)→(11,4)→(12,4)→(13,4)→(14,4) | PASS chain | full corridor confirmed |
| (8,3)→UP→(8,2)→UP→(8,1) | PASS chain | y=1 route viable from (8,3) |
| (8,1)→RIGHT→(9,1) | PASS `moved_through_modeled_block` | (9,1) also decoder gap |
| (7,2)→DOWN→(7,3) | PASS | (7,3) accessible from (7,2) going south |

**Note on (5,3)→(6,3)**: The teleport to (5,3) missed (player stayed at 5,2), so the
probe fired at (6,2) a second time. (6,3) west=true was added as an inferred entry
based on the consistent x=6 barrier pattern and survey run evidence.

### Changes applied to map_reader.lua

**MAP_PASSTHROUGH_CELLS[0x04]** — added:
```lua
["8,4"] = true,   -- decoder gap (tile=0); bridges (7,4) to regular floor at (9,4)+
                  -- Confirmed 2026-04-22 probe_edge:RIGHT from (7,4) → moved_through_modeled_block
```

**MAP_DIRECTIONAL_BLOCKS[0x04]** — added:
```lua
["7,3"] = {south = true},  -- engine blocks northward entry from (7,4)
                            -- Confirmed 2026-04-22: probe_edge:UP from (7,4) → blocked_despite_open_preview
["6,1"] = {west = true},   -- x=6 north corridor: engine blocks eastward entry
["6,2"] = {west = true},   -- Confirmed 2026-04-22 via probe_edge:RIGHT from (5,1)/(5,2)
["6,3"] = {west = true},   -- Inferred: consistent x=6 barrier + survey run 2 suspected_tiles pattern
```

**Comments updated** at MAP_PASSTHROUGH_CELLS (7,3-4-8,3 section) and MAP_DIRECTIONAL_BLOCKS
(4,7 section) to reflect the corrected y=4 east-corridor route.

### Verification pathfinds (post-reload, from 10,8)

All confirmed finding paths:

| Target | Result |
|---|---|
| Guard 1 (13,2) direct | **Path found** via y=4 corridor + x=8 north column |
| Guard 2 (23,11) adjacent | **Path to (23,10)** found — long east via y=4 |
| Guard 9 (15,20) adjacent | **Path to (16,20)** found — short south-east through main hall |
| Stairs Down (24,1) adjacent | **Path to (24,2)** found — y=4 east then north |
| East wing (20,4) direct | **Path found**: `…13 north, 15 east` — clean y=4 run |

The y=4 path segment `(5,4)→E×15→(20,4)` uses:
`(6,4)→(7,4)→(8,4)[new]→(9,4)→(10,4)→(11,4)→(12,4)→(13,4)→(14,4)→(15,4)→(16,4)→(17,4)→(18,4)→(19,4)→(20,4)`

### Actual east-wing route model

The y=4 corridor is a decoder-gap row that runs the full width of the castle:

```
West confirmed:  (4,4)  (5,4)  (6,4)  (7,4)   — tile=0 decoder gaps
Bridge (new):    (8,4)                          — tile=0 decoder gap (was missing)
Center:          (9,4)  (10,4) (11,4) (12,4) (13,4) — tile=6 regular floor
East confirmed:  (14,4) (15,4)                 — tile=0 decoder gaps
East wing:       (16,4) (17,4) → east wing     — tile=4 regular floor
```

The old route comment `(7,4)→N→(7,3)→E→(8,3)→N→(8,2)→N→(8,1)→east along y=1`
was wrong — `(7,3) south=true` blocks the first step. The y=1 route via `(8,3)` is
still theoretically accessible from `(7,2)` going south, but it is not the primary
corridor and A* should not prefer it.

## What still needs to happen

### Immediate next step: re-run the survey

Script is already reloaded. The east-wing model is now corrected. Run:
```
./dw_commands.sh survey_objects:park_npcs
```
from a good start position (e.g. `teleport_to:10,8` first).

Expected outcome:
- ~22–24 successes (up from 7)
- 6 gated_or_isolated (west-wing magic-key targets — expected, unchanged)
- 0–1 remaining state_issues (some east-wing NPCs sit on unmodeled cells like 23,11)

### Known remaining issues

1. **Guard 1 (13,2) path not execution-tested**: A* plans a path but auto_step hasn't
   walked it yet. The route uses `(8,4)→2N→(8,2)→5E→(13,2)`. `(8,2)` and the y=2
   row from x=8 to x=13 are regular floor tiles — should be fine, but watch for
   runtime blocks.

2. **`(9,1)` decoder gap unmodeled**: probe confirmed `(8,1)→RIGHT→(9,1)` moves through
   a modeled block (`moved_through_modeled_block`). If the y=1 route is ever used,
   `(9,1)` and possibly `(10,1)`, `(11,1)` etc. would need to be added as passthroughs.
   Not urgent since the y=4 route is primary.

3. **`(6,3)` not directly probed**: added as inferred west=true; confirm if a route
   ever tries to use it.

4. **`(23,11)` not walkable in model** (`goal_not_walkable`): Guard 2 sits on a cell
   the model says is impassable. The adjacent probe succeeded (reaching 23,10), so
   practical NPC interaction works. This is a pre-existing issue unrelated to this fix.

5. **West-wing targets still gated** (magic-key door) — unchanged, expected.

6. **Open issues from prior handoff still apply** (survey-logic, (3,16)/(4,15) noisy
   seams, (6,11) west-wing seam, Guard 4 internal west-pocket failures) — none of
   those were touched this session.

## Files changed this session

```
map_reader.lua   — (8,4) passthrough, (7,3) south=true, (6,1-3) west=true, comment fixes
probe_east_wing.sh — new probe script (18 targeted probes for east-wing diagnosis)
```

**Uncommitted.** All prior session uncommitted changes (auto_step.lua, route_manager.lua,
map_survey.lua, etc.) are also still uncommitted.
