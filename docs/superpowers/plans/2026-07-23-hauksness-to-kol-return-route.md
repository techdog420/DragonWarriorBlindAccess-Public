# Hauksness-to-Kol Return Route Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an explicit, automatically selected overworld route from Hauksness to Kol and validate it through both deterministic Lua tests and live FCEUX play.

**Architecture:** `overworld_routes.lua` gains a literal `kol_hauksness` route whose coordinates are the validated forward Hauksness chain in reverse order, with return-direction metadata kept explicit. Existing object matching and nearest-route scoring select this variant for the ordinary Kol Travel object; a route-local `selection_max_index` stops that local variant from stealing shared Kol-road starts after it rejoins the Garinham corridor. No new command, object, route-manager branch, or runtime route-generation helper is introduced.

**Tech Stack:** Lua 5.1/LuaJIT, the existing `overworld_routes` state machine, table-driven Lua regression tests, FCEUX 2.6.6, `dw_commands.ps1`, and `dw_debug.log`.

## Global Constraints

- Preserve the ordinary `overworld_kol` Travel object and automatic nearest-variant selection.
- Define `kol_hauksness` as explicit route data; do not generate it by reversing `hauksness` at runtime.
- Do not add permanent World Map blockers without new repeated same-origin live evidence.
- Do not change movement timing, movement RAM reset behavior, battle dialogue, or the validated forward `hauksness` route.
- Treat combat as an interruption: the user clears the battle, then testing resumes only after a fresh position, route, and runtime-block baseline.
- FCEUX requires a manual `main.lua` restart after Lua source changes.
- Use `C:\Users\developer\AppData\Local\Programs\LuaJIT\bin\luajit.exe`; plain `lua` is not available on the current PowerShell `PATH`.
- Keep `work_notes/current_investigation.md` unstaged unless its full diff is deliberately reviewed and belongs to the commit.

---

### Task 1: Add the explicit Kol return variant with test-first coverage

**Files:**
- Modify: `test_overworld_routes.lua` after the existing Hauksness route tests
- Modify: `overworld_routes.lua` in `ROUTES`, `ROUTE_IDS`, and `ROUTE_ALTERNATES`

**Interfaces:**
- Consumes: `routes.start(route_name, map_id, x, y)`, `routes.start_for_object(obj, map_id, x, y)`, `routes.plan_next_segment(map_id, x, y)`, `routes.observe_position(map_id, x, y)`, and `routes.recalculate(map_id, x, y)`
- Produces: route id `kol_hauksness`; aliases `kol from hauksness`, `hauksness to kol`, and `return from hauksness`; target object id `overworld_kol`; destination map `0x07`

- [ ] **Step 1: Add the failing route-selection, seam, ridge, recalculation, and arrival tests**

Add these complete tests to `test_overworld_routes.lua`:

```lua
function tests.kol_route_from_hauksness_uses_hauksness_return_variant()
    routes.reset_for_tests()

    local info, err = routes.start("kol", 0x01, 25, 89)

    assert_equal(err, nil, "Kol alias should resolve outside Hauksness")
    assert_equal(info.route.id, "kol_hauksness", "route should use the Hauksness return variant")
    assert_equal(info.object_id, "route_kol_hauksness_02", "Hauksness exit should target the west doorstep")
    assert_contains(info.message, "Hauksness doorstep west", "route should begin by leaving the ruins westward")

    local segment = assert(routes.plan_next_segment(0x01, 25, 89))
    assert_equal(segment.waypoint.name, "Hauksness doorstep west", "first segment should target the west doorstep")
    assert_equal(segment.steps[1], "left", "first return step should move west away from Hauksness")

    routes.reset_for_tests()
end

function tests.kol_object_from_hauksness_uses_hauksness_return_variant()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_kol",
        name = "Kol",
        x = 104,
        y = 10,
    }, 0x01, 25, 89)

    assert_equal(err, nil, "Kol Travel object should start from Hauksness")
    assert_equal(info.route.id, "kol_hauksness", "ordinary Kol object should choose the Hauksness return route")
    assert_equal(info.object_id, "route_kol_hauksness_02", "Kol object should target the local west doorstep")

    routes.reset_for_tests()
end

function tests.kol_hauksness_return_preserves_lower_pocket_recovery()
    routes.reset_for_tests()
    routes.start("hauksness to kol", 0x01, 25, 89)

    local expected = {
        {x = 24, y = 89, name = "Hauksness doorstep west", first = "left"},
        {x = 15, y = 89, name = "Hauksness west approach", first = "left"},
        {x = 15, y = 93, name = "Hauksness lower west lane", first = "down"},
        {x = 24, y = 93, name = "Hauksness lower west drop", first = "right"},
        {x = 24, y = 91, name = "Hauksness lower west pocket", first = "up"},
        {x = 26, y = 91, name = "Hauksness lower pocket", first = "right"},
        {x = 26, y = 90, name = "Hauksness lower south bend", first = "up"},
        {x = 26, y = 88, name = "Hauksness lower east lane", first = "up"},
        {x = 15, y = 88, name = "Hauksness west approach lower lane", first = "left"},
    }

    local x, y = 25, 89
    for _, waypoint in ipairs(expected) do
        local segment = assert(routes.plan_next_segment(0x01, x, y))
        assert_equal(segment.waypoint.name, waypoint.name, "return route should preserve the lower-pocket recovery chain")
        assert_equal(segment.steps[1], waypoint.first, waypoint.name .. " should begin in the proven direction")
        routes.observe_position(0x01, waypoint.x, waypoint.y)
        x, y = waypoint.x, waypoint.y
    end

    routes.reset_for_tests()
end

function tests.kol_hauksness_return_uses_reverse_desert_shelf_guard()
    routes.reset_for_tests()
    routes.start("hauksness to kol", 0x01, 15, 28)

    local segment = assert(routes.plan_next_segment(0x01, 16, 28))

    assert_equal(segment.waypoint.name, "Western desert east shelf", "return route should target the validated north shelf")
    assert_equal(segment.steps[1], "left", "x16 return approach should correct west before moving north")
    assert_equal(segment.steps[2], "up", "return route should move north only after reaching x15")

    routes.reset_for_tests()
end

function tests.kol_hauksness_return_uses_live_proven_ridge_gap()
    routes.reset_for_tests()
    routes.start("hauksness to kol", 0x01, 7, 14)

    local expected = {
        {x = 5, y = 14, name = "Hauksness coast lower bend", first = "left"},
        {x = 5, y = 13, name = "Hauksness coast lower east step", first = "up"},
        {x = 4, y = 13, name = "Hauksness coast south step", first = "left"},
        {x = 4, y = 12, name = "Hauksness coast east step", first = "up"},
        {x = 3, y = 12, name = "Hauksness ridge lower coast", first = "left"},
        {x = 3, y = 7, name = "Hauksness ridge west gap", first = "up"},
        {x = 5, y = 7, name = "Hauksness ridge west notch", first = "right"},
        {x = 5, y = 6, name = "Hauksness ridge west turn", first = "up"},
        {x = 7, y = 6, name = "Hauksness ridge upper lip", first = "right"},
        {x = 7, y = 4, name = "Hauksness north road", first = "up"},
    }

    local x, y = 7, 14
    for _, waypoint in ipairs(expected) do
        local segment = assert(routes.plan_next_segment(0x01, x, y))
        assert_equal(segment.waypoint.name, waypoint.name, "return ridge should use the live-proven western gap")
        assert_equal(segment.steps[1], waypoint.first, waypoint.name .. " should begin in the proven direction")
        routes.observe_position(0x01, waypoint.x, waypoint.y)
        x, y = waypoint.x, waypoint.y
    end

    routes.reset_for_tests()
end

function tests.kol_variants_recalculate_to_and_from_hauksness()
    local starts = {
        {alias = "kol", x = 43, y = 43},
        {alias = "kol from rain shrine", x = 81, y = 1},
        {alias = "kol from swamp cave", x = 104, y = 44},
    }

    for _, start in ipairs(starts) do
        routes.reset_for_tests()
        routes.start(start.alias, 0x01, start.x, start.y)

        local info = routes.recalculate(0x01, 25, 89)

        assert_equal(info.route.id, "kol_hauksness", start.alias .. " should recalculate to the Hauksness return variant")
        assert_equal(info.object_id, "route_kol_hauksness_02", "recalculation should target the local west doorstep")
    end

    routes.reset_for_tests()
    routes.start("hauksness to kol", 0x01, 25, 89)

    local swamp = routes.recalculate(0x01, 104, 44)

    assert_equal(swamp.route.id, "kol_swamp_cave", "Hauksness variant should recalculate to the nearer Swamp Cave return")

    routes.reset_for_tests()
end

function tests.entering_kol_stops_hauksness_return_route()
    routes.reset_for_tests()
    routes.start("hauksness to kol", 0x01, 25, 89)

    local event = routes.observe_position(0x07, 0, 0)

    assert_contains(event.message, "Arrived at Kol", "entering Kol should complete the Hauksness return route")
    assert_equal(event.refresh, true, "Kol arrival should refresh Travel objects")
    assert_equal(routes.is_active(), false, "route should stop after entering Kol")

    routes.reset_for_tests()
end
```

- [ ] **Step 2: Run the tests and verify they fail for the missing route**

Run:

```powershell
$dwLua = 'C:\Users\developer\AppData\Local\Programs\LuaJIT\bin\luajit.exe'
& $dwLua test_overworld_routes.lua
```

Expected: the existing 94 tests still pass, the seven new tests fail, and the
output ends with `Ran 101 Lua unit tests`. Failures should report the absent
`kol_hauksness` route, the wrong selected Kol variant, or `Unknown overworld
route`; they must not be syntax or test-harness failures.

- [ ] **Step 3: Add the explicit return route**

Add this complete route entry to `ROUTES` immediately after `hauksness`:

```lua
    kol_hauksness = {
        id = "kol_hauksness",
        title = "Kol",
        aliases = {
            "kol from hauksness",
            "hauksness to kol",
            "return from hauksness",
        },
        target_object_ids = {"overworld_kol"},
        destination_maps = {0x07},
        -- Auto-selection ends at Garinham; an active route still retains the full chain to Kol.
        selection_max_index = 54,
        waypoints = {
            {x = 25, y = 89, name = "Hauksness", radius = 1},
            {
                x = 24,
                y = 89,
                name = "Hauksness doorstep west",
                radius = 0,
                warning = "Hauksness return to Kol. Strong monsters remain nearby; keep HP high.",
            },
            {x = 15, y = 89, name = "Hauksness west approach", radius = 0},
            {x = 15, y = 93, name = "Hauksness lower west lane", radius = 0},
            {x = 24, y = 93, name = "Hauksness lower west drop", radius = 0},
            {x = 24, y = 91, name = "Hauksness lower west pocket", radius = 0},
            {x = 26, y = 91, name = "Hauksness lower pocket", radius = 0},
            {x = 26, y = 90, name = "Hauksness lower south bend", radius = 0},
            {x = 26, y = 88, name = "Hauksness lower east lane", radius = 0},
            {x = 15, y = 88, name = "Hauksness west approach lower lane", radius = 0},
            {x = 15, y = 86, name = "Hauksness west approach north", radius = 0},
            {x = 16, y = 86, name = "Hauksness west lower bend", radius = 0},
            {x = 16, y = 85, name = "Hauksness west lower lane", radius = 0},
            {x = 18, y = 85, name = "Hauksness western wall", radius = 0},
            {x = 20, y = 85, name = "Hauksness southwest lower bend", radius = 0},
            {x = 20, y = 83, name = "Hauksness southwest shelf", radius = 0},
            {x = 22, y = 83, name = "Hauksness west road south turn", radius = 0},
            {x = 22, y = 79, name = "Hauksness west road", radius = 0},
            {x = 26, y = 79, name = "Hauksness ridge rise", radius = 0},
            {x = 26, y = 81, name = "Hauksness western ridge", radius = 0},
            {x = 31, y = 81, name = "Hauksness northwest bend", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 29, y = 82, name = "Hauksness north ridge", radius = 0},
            {x = 29, y = 69, name = "Hauksness outer road", radius = 1},
            {x = 18, y = 69, name = "Western desert southeast bend", radius = 0},
            {x = 18, y = 64, name = "Western desert east road", radius = 0},
            {x = 2, y = 64, name = "Western desert south road", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 2, y = 54, name = "Western desert west wall", radius = 0},
            {x = 4, y = 54, name = "Western desert lower shelf", radius = 0},
            {x = 4, y = 52, name = "Western desert row 52 west lane", radius = 0},
            {x = 6, y = 52, name = "Western desert row 52 bend", radius = 0},
            {x = 6, y = 51, name = "Western desert row 51 west bend", radius = 0},
            {x = 8, y = 51, name = "Western desert long descent", radius = 0},
            {x = 8, y = 34, name = "Western desert pass foot", radius = 1},
            {x = 8, y = 31, name = "Western desert vertical pass", radius = 0},
            {x = 9, y = 31, name = "Western desert west notch", radius = 0},
            {x = 11, y = 31, name = "Western desert lower notch", radius = 0},
            {x = 11, y = 30, name = "Western desert lower west lane", radius = 0},
            {x = 13, y = 30, name = "Western desert south detour", radius = 0},
            {x = 13, y = 28, name = "Western desert west detour", radius = 0},
            {x = 15, y = 28, name = "Western desert south shelf", radius = 0, axis_order = {"horizontal", "vertical"}},
            {
                x = 15,
                y = 14,
                name = "Western desert east shelf",
                radius = 0,
                axis_order = {"horizontal", "vertical"},
                warning = "Leaving the western desert. Monsters should become safer ahead.",
            },
            {x = 7, y = 14, name = "Hauksness northern descent", radius = 1},
            {x = 5, y = 14, name = "Hauksness coast lower bend", radius = 0},
            {x = 5, y = 13, name = "Hauksness coast lower east step", radius = 0},
            {x = 4, y = 13, name = "Hauksness coast south step", radius = 0},
            {x = 4, y = 12, name = "Hauksness coast east step", radius = 0},
            {x = 3, y = 12, name = "Hauksness ridge lower coast", radius = 0},
            {x = 3, y = 7, name = "Hauksness ridge west gap", radius = 0},
            {x = 5, y = 7, name = "Hauksness ridge west notch", radius = 0},
            {x = 5, y = 6, name = "Hauksness ridge west turn", radius = 0},
            {x = 7, y = 6, name = "Hauksness ridge upper lip", radius = 0},
            {x = 7, y = 4, name = "Hauksness north road", radius = 0},
            {x = 5, y = 4, name = "Garinham outskirts", radius = 1},
            {x = 8, y = 3, name = "Garinham north coast west lane", radius = 1},
            {x = 14, y = 3, name = "Garinham north coast lane", radius = 0},
            {x = 14, y = 4, name = "Garinham mountain shoulder", radius = 0},
            {x = 15, y = 4, name = "Garinham shoulder east step", radius = 0},
            {x = 16, y = 5, name = "Garinham shoulder bend", radius = 0},
            {x = 16, y = 6, name = "Garinham east ridge", radius = 0},
            {x = 19, y = 6, name = "Garinham ridge entry", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 20, y = 7, name = "Garinham field east lane", radius = 0},
            {x = 20, y = 9, name = "Garinham east field", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 21, y = 10, name = "Garinham field road bend", radius = 0},
            {x = 21, y = 11, name = "Cave road north edge", radius = 0},
            {x = 23, y = 11, name = "Cave road west lane", radius = 0},
            {x = 23, y = 13, name = "Cave road south lane", radius = 1},
            {x = 28, y = 13, name = "Erdrick's Cave road", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 35, y = 13, name = "North Alefgard west road", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 45, y = 13, name = "North Alefgard east road", radius = 1, axis_order = {"vertical", "horizontal"}},
            {x = 54, y = 15, name = "Northeast bridge west approach", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 58, y = 18, name = "Northeast bridge west bend", radius = 0, axis_order = {"horizontal", "vertical"}},
            {x = 59, y = 19, name = "Northeast bridge lower west lane", radius = 0},
            {x = 61, y = 19, name = "Northeast bridge south lane", radius = 0},
            {x = 61, y = 18, name = "Northeast bridge", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 74, y = 18, name = "North Alefgard bridge road", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 84, y = 26, name = "Kol southwest track", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 90, y = 37, name = "Kol southwest bridge", radius = 0},
            {x = 92, y = 37, name = "Kol bridge east lane", radius = 0},
            {x = 92, y = 36, name = "Kol lower south lane", radius = 0},
            {x = 93, y = 36, name = "Kol south road bend", radius = 0},
            {x = 93, y = 35, name = "Kol south road lower bend", radius = 0},
            {x = 96, y = 35, name = "Kol south road east lane", radius = 0},
            {x = 96, y = 32, name = "Kol south road", radius = 1},
            {x = 98, y = 32, name = "Kol south road lower east lane", radius = 0},
            {x = 98, y = 26, name = "Kol south road east detour", radius = 0, axis_order = {"vertical", "horizontal"}},
            {x = 96, y = 21, name = "West of Kol north lane", radius = 1},
            {x = 96, y = 13, name = "Kol forest west edge", radius = 1, axis_order = {"horizontal", "vertical"}},
            {x = 104, y = 10, name = "Kol", radius = 0, final = true},
        },
    },
```

- [ ] **Step 4: Constrain local selection, then register every Kol alternate**

In `route_start_score`, reject only route-start candidates beyond a route's
optional local-selection handoff:

```lua
local function route_start_score(route, map_id, px, py, terrain_offset)
    if not route then
        return math.huge
    end
    local index = choose_next_index(route, map_id, px, py, terrain_offset)
    if route.selection_max_index and index > route.selection_max_index then
        return math.huge
    end
    local point = route.waypoints[index]
    if not point then
        return math.huge
    end
    return distance(px, py, point)
end
```

Add `"kol_hauksness"` to `ROUTE_IDS` after `"kol_swamp_cave"`, then replace
the four Kol alternate entries with:

```lua
    kol = {"kol", "kol_rain_shrine", "kol_swamp_cave", "kol_hauksness"},
    kol_rain_shrine = {"kol", "kol_rain_shrine", "kol_swamp_cave", "kol_hauksness"},
    kol_swamp_cave = {"kol_swamp_cave", "kol", "kol_rain_shrine", "kol_hauksness"},
    kol_hauksness = {"kol_hauksness", "kol", "kol_rain_shrine", "kol_swamp_cave"},
```

The relevant `ROUTE_IDS` excerpt must read:

```lua
    "kol",
    "northern_cave",
    "kol_rain_shrine",
    "kol_swamp_cave",
    "kol_hauksness",
    "swamp_cave",
```

- [ ] **Step 5: Run focused and integration tests**

Run:

```powershell
$dwLua = 'C:\Users\developer\AppData\Local\Programs\LuaJIT\bin\luajit.exe'
& $dwLua test_overworld_routes.lua
& $dwLua test_route_manager.lua
```

Expected:

- `test_overworld_routes.lua` ends with `Ran 101 Lua unit tests` and no `FAIL`.
- `test_route_manager.lua` ends with `Ran 110 Lua unit tests` and no `FAIL`.

- [ ] **Step 6: Byte-compile and review the exact source diff**

Run:

```powershell
$dwLua = 'C:\Users\developer\AppData\Local\Programs\LuaJIT\bin\luajit.exe'
& $dwLua -b overworld_routes.lua NUL
& $dwLua -b test_overworld_routes.lua NUL
git diff --check -- overworld_routes.lua test_overworld_routes.lua
git diff -- overworld_routes.lua test_overworld_routes.lua
```

Expected: both byte-compiles exit zero, `git diff --check` prints nothing, and
the diff contains only the new tests, literal route data, the route-local
selection cutoff, `ROUTE_IDS` entry, and four Kol alternate lists.

- [ ] **Step 7: Commit the automated implementation**

Run:

```powershell
git add overworld_routes.lua test_overworld_routes.lua
git commit -m "feat: add Hauksness return route to Kol"
```

Expected: the commit contains exactly those two files. Do not stage
`work_notes/current_investigation.md`.

---

### Task 2: Validate the return route live and record durable project state

**Files:**
- Modify after successful end-to-end validation: `PLAYTESTING.md`
- Modify after successful end-to-end validation: `session_handoff.md`
- Preserve unstaged working evidence: `work_notes/current_investigation.md`

**Interfaces:**
- Consumes: `kol_hauksness`, the ordinary Kol Travel object, `route_guidance`, `route_status`, `auto_walk`, `report_position`, `report_runtime_blocks`, and FCEUX manual Lua restart
- Produces: live evidence for Hauksness exit, lower-pocket recovery, western ridge, desert seams, northern roads, Kol approach, and destination-map completion

- [ ] **Step 1: Manually reload Lua and restore the Hauksness save state**

In FCEUX, manually restart `main.lua`. Restore the saved state at Ruins of
Hauksness map `0x03`, `(0,10)`, then move one tile WEST. The expected landing
is World Map `0x01`, `(25,89)`.

- [ ] **Step 2: Establish a clean baseline and start from the ordinary Kol Travel object**

Run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait "POSITION:" report_position route_status report_runtime_blocks
```

Expected baseline evidence:

```text
POSITION: map=0x01(World Map) x=25 y=89
RUNTIME_BLOCKS map=0x01 none
```

Use the normal object-filter controls to select `Kol` in the Travel filter.
Confirm the selection with:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait "OBJECT:" current_object
```

Expected: the object description begins with `Kol`. Then run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait "route=kol_hauksness" route_guidance route_status
```

Expected: `OVERWORLD_ROUTE: event=start route=kol_hauksness`, and the active
waypoint is `Hauksness doorstep west (24,89)`.

- [ ] **Step 3: Validate one route segment at a time**

For each segment, run:

```powershell
.\dw_commands.ps1 --replace auto_walk
Get-Content -LiteralPath 'dw_debug.log' -Tail 100
```

Do not queue the next `auto_walk` until the log shows one of:

- the expected waypoint advance;
- a completed segment from a one-tile accepted final drift;
- a battle start;
- an explicit timeout, drift, blocker, or cancellation.

Validate these checkpoint groups in order:

1. Exit and lower pocket:
   `(24,89)`, `(15,89)`, `(15,93)`, `(24,93)`, `(24,91)`,
   `(26,91)`, `(26,90)`, `(26,88)`, `(15,88)`.
2. Western ridge:
   `(29,82)`, `(31,81)`, `(26,81)`, `(26,79)`, `(22,79)`,
   then the established western-wall chain.
3. Southern and central desert:
   `(18,64)`, `(2,64)`, the row-54/52/51 bends, `(8,34)`,
   `(15,28)`, and `(15,14)`.
4. Northern ridge gap:
   `(7,14)`, `(5,14)`, `(5,13)`, `(4,13)`, `(4,12)`,
   `(3,12)`, `(3,7)`, `(5,7)`, `(5,6)`, `(7,6)`, `(7,4)`.
5. Garinham, North Alefgard, and Kol:
   the cave-road chain, northeast bridge chain, Kol southwest road,
   `(96,21)`, `(96,13)`, and `(104,10)`.

- [ ] **Step 4: Handle combat and apparent blockers conservatively**

If combat begins, stop sending movement commands. After the user clears the
field, run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait "POSITION:" report_position route_status report_runtime_blocks
```

If a route step times out or reports a block, preserve the exact origin and
run only the command matching the failed logged direction:

```powershell
.\dw_commands.ps1 --replace --timeout 20 --wait "EDGE_PROBE_RESULT" "probe_edge:UP"
.\dw_commands.ps1 --replace --timeout 20 --wait "EDGE_PROBE_RESULT" "probe_edge:DOWN"
.\dw_commands.ps1 --replace --timeout 20 --wait "EDGE_PROBE_RESULT" "probe_edge:LEFT"
.\dw_commands.ps1 --replace --timeout 20 --wait "EDGE_PROBE_RESULT" "probe_edge:RIGHT"
```

Run exactly one of those four commands, never the whole block. A successful
probe is timing evidence and must not change permanent route or map data. A
repeated same-origin block with clean field state is evidence for a separate
focused design/test cycle; stop this plan before patching it.

- [ ] **Step 5: Confirm Kol destination-map completion**

Enter Kol normally from `(104,10)`, then run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait "POSITION:" report_position route_status report_runtime_blocks
```

Expected: the map is Kol `0x07`, `route_status` reports
`event=status route=none`, and no runtime blocker was injected to force
completion.

- [ ] **Step 6: Record the successful route status in durable docs**

After end-to-end success, add this paragraph to the Hauksness route section of
`PLAYTESTING.md`:

```markdown
The explicit Hauksness-to-Kol return variant is live-validated from the normal
Hauksness exit at World Map `(25,89)` through the lower-pocket recovery,
western ridge, western desert seams, live-proven ridge gap `(3,7)`, Garinham
roads, northeast bridge, and Kol approach. Selecting the ordinary Kol Travel
destination near Hauksness automatically chooses `kol_hauksness`; entering
Kol map `0x07` clears the route. Battles remain manual pause points, and no
runtime or permanent blocker is part of the route definition.
```

Add this concise state item to `session_handoff.md`:

```markdown
- Hauksness return complete: `kol_hauksness` is automated-test and live
  validated from the normal `(25,89)` exit to Kol map `0x07`. The ordinary
  Kol Travel destination selects it automatically near Hauksness. Preserve
  the explicit lower-pocket, desert-shelf, and `(3,7)` ridge-gap checkpoints.
```

Do not promote the coordinate-sensitive battle-dialogue evidence into these
route-completion statements; it remains a separate later tuning task.

- [ ] **Step 7: Re-run verification and commit only durable documentation**

Run:

```powershell
$dwLua = 'C:\Users\developer\AppData\Local\Programs\LuaJIT\bin\luajit.exe'
& $dwLua test_overworld_routes.lua
& $dwLua test_route_manager.lua
git diff --check -- PLAYTESTING.md session_handoff.md
git diff -- PLAYTESTING.md session_handoff.md
git add PLAYTESTING.md session_handoff.md
git commit -m "docs: validate Hauksness return route to Kol"
```

Expected: 101 overworld-route tests and 110 route-manager tests pass; the docs
describe only observed live success; the commit contains exactly
`PLAYTESTING.md` and `session_handoff.md`.
