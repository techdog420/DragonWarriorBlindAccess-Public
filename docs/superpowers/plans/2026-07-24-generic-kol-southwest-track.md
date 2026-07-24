# Generic Kol Southwest-Track Ordering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make generic Kol guidance descend from the north bridge road before moving east toward the Kol southwest track.

**Architecture:** Encode the proven local geometry on the existing generic `kol` waypoint instead of changing global movement or map data. A planner-level regression will advance the real generic route through the bridge approach and reproduce the `(77,18)` failure origin.

**Tech Stack:** Lua 5.1-compatible route data, the standalone Lua test harness, and FCEUX live validation.

## Global Constraints

- Change only generic `kol`'s `Kol southwest track` waypoint.
- Preserve `kol_hauksness`'s existing vertical-first correction.
- Preserve horizontal-first ordering in reverse `hauksness` and `tantegel_kol` routes.
- Do not change global route planning, final-carry handling, movement reset behavior, or executor retries.
- Do not add an overworld map blocker.
- Do not reload FCEUX until the user is ready; the current live checkpoint is `(77,20)`.
- Leave implementation changes uncommitted until the user requests a combined commit.

---

### Task 1: Correct generic Kol southwest-track ordering

**Files:**
- Modify: `test_overworld_routes.lua`
- Modify: `overworld_routes.lua:158`
- Modify: `work_notes/current_investigation.md`

**Interfaces:**
- Consumes: `overworld_routes.start(route_name, map_id, x, y)`, `overworld_routes.observe_position(map_id, x, y)`, and `overworld_routes.plan_next_segment(map_id, x, y)`.
- Produces: Generic `kol` plans DOWN from `(77,18)` toward `Kol southwest track`, finishes the vertical leg to row 26, and only then plans RIGHT.

- [x] **Step 1: Write the failing generic-route regression**

Add this test near the existing generic Kol route tests:

```lua
function tests.kol_route_descends_before_southwest_track()
    routes.reset_for_tests()

    local start = assert(routes.start("kol", 0x01, 54, 15))
    assert_equal(start.route.id, "kol", "north bridge start should use the generic Kol route")

    local bridge_waypoints = {
        {x = 58, y = 18},
        {x = 59, y = 19},
        {x = 61, y = 19},
        {x = 61, y = 18},
        {x = 74, y = 18},
    }
    for _, waypoint in ipairs(bridge_waypoints) do
        routes.observe_position(0x01, waypoint.x, waypoint.y)
    end

    local segment = assert(routes.plan_next_segment(0x01, 77, 18))

    assert_equal(segment.waypoint.name, "Kol southwest track", "generic Kol route should retain the southwest-track target")
    assert_equal(segment.steps[1], "down", "generic Kol route should descend before the blocked east edge")
    assert_equal(segment.steps[8], "down", "generic Kol route should finish descending to row 26")
    assert_equal(segment.steps[9], "right", "generic Kol route should turn east only after reaching row 26")

    routes.reset_for_tests()
end
```

This test catches removal or misplacement of the generic waypoint's
vertical-first order. It uses real route state and hand-derived expectations:
from `(77,18)` there are eight DOWN steps to row 26, followed by seven RIGHT
steps toward `(84,26)`.

- [x] **Step 2: Run the route suite and verify RED**

Run:

```powershell
& 'C:\Users\developer\AppData\Local\Programs\LuaJIT\bin\luajit.exe' 'test_overworld_routes.lua'
```

Expected: exactly the new test fails with
`generic Kol route should descend before the blocked east edge: expected down, got right`.
The existing 105 tests should remain passing.

- [x] **Step 3: Apply the minimal generic waypoint correction**

In generic `kol` only, replace:

```lua
{x = 84, y = 26, name = "Kol southwest track", radius = 1, axis_order = {"horizontal", "vertical"}},
```

with:

```lua
{x = 84, y = 26, name = "Kol southwest track", radius = 1, axis_order = {"vertical", "horizontal"}},
```

Do not change the other three `Kol southwest track` occurrences.

- [x] **Step 4: Run focused verification and verify GREEN**

Run:

```powershell
& 'C:\Users\developer\AppData\Local\Programs\LuaJIT\bin\luajit.exe' -e "assert(loadfile('overworld_routes.lua')); assert(loadfile('test_overworld_routes.lua'))"
& 'C:\Users\developer\AppData\Local\Programs\LuaJIT\bin\luajit.exe' 'test_overworld_routes.lua'
& 'C:\Users\developer\AppData\Local\Programs\LuaJIT\bin\luajit.exe' 'test_route_manager.lua'
git diff --check
```

Expected:

- Lua syntax loading exits zero.
- All 106 overworld-route tests pass.
- All 111 route-manager tests pass.
- `git diff --check` exits zero.
- The existing `kol_hauksness_return_descends_before_kol_southwest_track` test remains green.

- [x] **Step 5: Record the generic-route evidence**

Append this evidence to the current Hauksness/Kol section in
`work_notes/current_investigation.md`:

```markdown
- GENERIC KOL SOUTHWEST-TRACK GAP: after reload cleared route state, selecting
  Kol at `(54,15)` chose generic `kol`. Its bridge correction moved DOWN first
  and reached `(58,18)`, then the shared corridor reached `(74,18)`. Generic
  `Kol southwest track` still planned horizontal-first, moved east to
  `(77,18)`, and blocked on the already-proven `(77,18)->RIGHT` edge. A fresh
  clean baseline at `(77,18)` had no path, NPC, menu, battle, or runtime
  blocks; same-origin DOWN crossed `(77,19)` and carried to `(77,20)`. Generic
  `kol` now uses vertical-first ordering at this waypoint. Its regression
  requires eight DOWN steps before the first RIGHT step. Reverse routes remain
  horizontal-first.
```

- [x] **Step 6: Review the implementation diff**

Run:

```powershell
git diff -- overworld_routes.lua test_overworld_routes.lua work_notes/current_investigation.md
git status --short
```

Expected: this task adds one generic-route regression, changes one generic
waypoint field, and adds one evidence note. Existing uncommitted lower-pocket
carry changes and their plan remain present. Do not commit.

- [x] **Step 7: Perform deferred live verification**

After the user manually stops and restarts the FCEUX script:

1. Run a fresh `launcher_probe`, `report_position`, `route_status`,
   `report_path_state`, and `report_runtime_blocks` baseline.
2. Confirm Kol is selected before invoking `auto_walk`; use `current_object`
   and `next_object` as needed.
3. Restore or normally reach `(54,15)`, start Kol guidance, and confirm
   `route=kol`.
4. Run the bridge segments to `(74,18)`.
5. Run one `Kol southwest track` segment and confirm the first logged
   `auto_step begin_step` is DOWN.
6. Confirm the route reaches row 26 before turning RIGHT toward `(84,26)`.

If `(54,15)` is restored with `teleport_to:54,15,force`, classify the result as
planner/reload validation rather than new passability evidence.

Live result: after a manual script restart, a fresh probe confirmed world map
`(54,15)`, generic route `kol`, selected object Kol, and no active path, NPC,
or runtime blockers. The bridge approach reached `(74,18)`. `Kol southwest
track` then planned and completed 18 steps from `(74,18)` to `(84,26)`: eight
DOWN moves followed by ten RIGHT moves. It did not attempt the blocked
`(77,18)->RIGHT` edge. The next active waypoint was `Kol southwest bridge`.
Two earlier bridge segments needed one retry each because of known movement
timing failures; neither produced permanent blocker evidence.
