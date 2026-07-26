# Cantlin-to-Hauksness Return Route Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an explicit, automatically selected overworld route from Cantlin to the confirmed Hauksness entrance and validate it through deterministic Lua tests and live FCEUX play.

**Architecture:** `overworld_routes.lua` gains a literal `hauksness_cantlin` route built from a map-oriented and live-validated 58-waypoint western chain. Existing object matching and nearest-route scoring select this variant for the ordinary Hauksness Travel object near Cantlin; `selection_max_index = 56` prevents it from stealing the established Hauksness route at the shared final approach. No new command, Travel object, route-manager branch, or cross-map orchestration is introduced.

**Tech Stack:** Lua 5.1/LuaJIT, the existing `overworld_routes` state machine, table-driven Lua regression tests, FCEUX 2.6.6, `dw_commands.ps1`, `dw_debug.log`, PowerShell, and the WSL Python test harness.

## Live Correction and Completion

Tasks 1 through 4 below preserve the original rejected candidate for
historical TDD context only. **Do not execute their code snippets, coordinate
lists, expected results, or live-validation procedure.** Live probing showed
that candidate's eastern/southern trail was invalid. The implemented route
starts at the actual Cantlin exit landing `(73,102)`, runs north and west
through the explicit forest switchbacks, and joins the Hauksness approach at
`(23,95)->(22,95)->(22,89)->(24,89)->(25,89)`. The production route and
`test_overworld_routes.lua` are authoritative.

FCEUX validated the corrected route end to end. Arrival changed to map `0x03`
at `(0,10)`, emitted `OVERWORLD_ROUTE: event=arrived
route=hauksness_cantlin waypoint=Hauksness index=58`, and cleared the route.
Two recoverable final-settle overshoots and several same-origin-probe-clean
queued blocks were retained as autowalk timing evidence; none justify static
map changes.

## Global Constraints

- Start the named route only after Cantlin's existing town exit has changed to World Map `0x01`.
- Preserve Cantlin's existing southeast Exit to World Map stand at town `(20,28)`, facing south toward transition `(20,29)`.
- End by stepping east from World Map `(24,89)` into Hauksness at `(25,89)`, destination map `0x03`.
- Define `hauksness_cantlin` as explicit route data; do not generate it by reversing historical notes at runtime.
- Preserve the existing `hauksness` and `kol_hauksness` route behavior.
- Do not add permanent World Map blockers without new repeated same-origin live evidence.
- Do not change movement timing, carry semantics, guarded-twitch behavior, turn-settle behavior, battle dialogue, or route-manager control flow.
- Treat combat as an interruption: the user clears the battle, then testing resumes only after a fresh position, route, path, runtime-block, and input baseline.
- FCEUX requires a manual `main.lua` restart after Lua source changes.
- Keep `work_notes/hauksness_stat_corruption_20260724.log` untracked.

---

### Historical Task 1: Rejected selection and route-shape regressions

**Files:**
- Modify: `test_overworld_routes.lua` after the existing Hauksness/Kol return tests
- Read: `overworld_routes.lua`

**Interfaces:**
- Consumes: `routes.start(route_name, map_id, x, y)`, `routes.start_for_object(obj, map_id, x, y)`, `routes.active_route_matches_object(obj)`, `routes.plan_next_segment(map_id, x, y)`, `routes.observe_position(map_id, x, y)`, and `routes.reset_for_tests()`
- Produces: ten failing regressions specifying route id `hauksness_cantlin`, aliases, object matching, route geometry, local-selection bounds, strict final approach, and destination-map completion

- [ ] **Step 1: Add the failing route-selection tests**

Add these tests to `test_overworld_routes.lua`:

```lua
function tests.hauksness_alias_from_cantlin_uses_cantlin_variant()
    routes.reset_for_tests()

    local info, err = routes.start("hauksness", 0x01, 73, 103)

    assert_equal(err, nil, "Hauksness alias should resolve outside Cantlin")
    assert_equal(info.route.id, "hauksness_cantlin", "Cantlin start should use the local Hauksness variant")
    assert_equal(info.object_id, "route_hauksness_cantlin_02", "Cantlin start should skip the current entrance anchor")
    assert_contains(info.message, "Cantlin entrance west step", "route should begin by moving away from Cantlin")

    local segment = assert(routes.plan_next_segment(0x01, 73, 103))
    assert_equal(segment.waypoint.name, "Cantlin entrance west step", "first segment should target the west step")
    assert_equal(segment.steps[1], "left", "first return step should move west away from Cantlin")

    routes.reset_for_tests()
end

function tests.hauksness_object_from_cantlin_uses_cantlin_variant()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_hauksness",
        name = "Hauksness",
        x = 25,
        y = 89,
    }, 0x01, 73, 103)

    assert_equal(err, nil, "Hauksness Travel object should start outside Cantlin")
    assert_equal(info.route.id, "hauksness_cantlin", "ordinary Hauksness object should choose the Cantlin variant")
    assert_equal(info.object_id, "route_hauksness_cantlin_02", "Hauksness object should target the local west step")

    routes.reset_for_tests()
end

function tests.active_cantlin_hauksness_route_matches_ordinary_object()
    routes.reset_for_tests()
    routes.start("cantlin to hauksness", 0x01, 73, 103)

    local matches = routes.active_route_matches_object({
        id = "overworld_hauksness",
        name = "Hauksness",
        x = 25,
        y = 89,
    })

    assert_equal(matches, true, "active Cantlin variant should retain the ordinary Hauksness destination")

    routes.reset_for_tests()
end
```

- [ ] **Step 2: Add the failing exact-departure and eastern-zigzag tests**

Add:

```lua
function tests.cantlin_hauksness_departure_preserves_entry_seam()
    routes.reset_for_tests()
    routes.start("cantlin to hauksness", 0x01, 73, 103)

    local expected = {
        {x = 72, y = 103, name = "Cantlin entrance west step", first = "left"},
        {x = 72, y = 101, name = "Cantlin entrance north lane", first = "up"},
        {x = 74, y = 101, name = "Cantlin south road west bend", first = "right"},
        {x = 87, y = 101, name = "Cantlin south road east bend", first = "right"},
    }

    local x, y = 73, 103
    for _, waypoint in ipairs(expected) do
        local segment = assert(routes.plan_next_segment(0x01, x, y))
        assert_equal(segment.waypoint.name, waypoint.name, "Cantlin departure should preserve the proven entry seam")
        assert_equal(segment.steps[1], waypoint.first, waypoint.name .. " should begin in the proven direction")
        routes.observe_position(0x01, waypoint.x, waypoint.y)
        x, y = waypoint.x, waypoint.y
    end

    routes.reset_for_tests()
end

function tests.cantlin_hauksness_preserves_eastern_forest_zigzag()
    routes.reset_for_tests()
    routes.start("cantlin to hauksness", 0x01, 87, 101)

    local expected = {
        {x = 87, y = 107, name = "Cantlin forest east descent", first = "down"},
        {x = 86, y = 107, name = "Cantlin forest east west step", first = "left"},
        {x = 86, y = 108, name = "Cantlin forest east lower step", first = "down"},
        {x = 85, y = 108, name = "Cantlin forest middle west step", first = "left"},
        {x = 85, y = 109, name = "Cantlin forest middle lower step", first = "down"},
        {x = 81, y = 109, name = "Cantlin forest west corridor", first = "left"},
        {x = 81, y = 110, name = "Cantlin forest west lower step", first = "down"},
        {x = 80, y = 110, name = "Cantlin forest west first step", first = "left"},
        {x = 80, y = 111, name = "Cantlin forest west first drop", first = "down"},
        {x = 79, y = 111, name = "Cantlin forest west second step", first = "left"},
        {x = 79, y = 112, name = "Cantlin forest west second drop", first = "down"},
        {x = 78, y = 112, name = "Cantlin forest southwest step", first = "left"},
        {x = 78, y = 113, name = "Cantlin forest southwest gate", first = "down"},
    }

    local x, y = 87, 101
    for _, waypoint in ipairs(expected) do
        local segment = assert(routes.plan_next_segment(0x01, x, y))
        assert_equal(segment.waypoint.name, waypoint.name, "Cantlin forest route should preserve every narrow turn")
        assert_equal(segment.steps[1], waypoint.first, waypoint.name .. " should begin in the proven direction")
        routes.observe_position(0x01, waypoint.x, waypoint.y)
        x, y = waypoint.x, waypoint.y
    end

    routes.reset_for_tests()
end
```

- [ ] **Step 3: Add the failing southern-maze and northwestern-connector tests**

Add:

```lua
function tests.cantlin_hauksness_preserves_southern_maze_turns()
    routes.reset_for_tests()
    routes.start("cantlin to hauksness", 0x01, 78, 113)

    local expected = {
        {x = 78, y = 114, name = "Southern maze west entry", first = "down"},
        {x = 79, y = 114, name = "Southern maze first east step", first = "right"},
        {x = 79, y = 115, name = "Southern maze first drop", first = "down"},
        {x = 82, y = 115, name = "Southern maze west corridor", first = "right"},
        {x = 82, y = 116, name = "Southern maze lower west step", first = "down"},
        {x = 85, y = 116, name = "Southern maze lower corridor", first = "right"},
        {x = 85, y = 115, name = "Southern maze east rise", first = "up"},
        {x = 87, y = 115, name = "Southern maze east corridor", first = "right"},
        {x = 87, y = 114, name = "Southern maze second rise", first = "up"},
        {x = 88, y = 114, name = "Southern maze northeast step", first = "right"},
        {x = 88, y = 113, name = "Southern maze northeast rise", first = "up"},
        {x = 89, y = 113, name = "Southern maze north gate", first = "right"},
    }

    local x, y = 78, 113
    for _, waypoint in ipairs(expected) do
        local segment = assert(routes.plan_next_segment(0x01, x, y))
        assert_equal(segment.waypoint.name, waypoint.name, "southern maze should preserve every verified bend")
        assert_equal(segment.steps[1], waypoint.first, waypoint.name .. " should begin in the proven direction")
        routes.observe_position(0x01, waypoint.x, waypoint.y)
        x, y = waypoint.x, waypoint.y
    end

    routes.reset_for_tests()
end

function tests.cantlin_hauksness_preserves_northwestern_connector()
    routes.reset_for_tests()
    routes.start("cantlin to hauksness", 0x01, 89, 113)

    local expected = {
        {x = 89, y = 100, name = "Southern forest north corridor", first = "up"},
        {x = 87, y = 100, name = "Southern forest west bend", first = "left"},
        {x = 87, y = 97, name = "Southern forest west rise", first = "up"},
        {x = 86, y = 97, name = "Southern forest ridge west step", first = "left"},
        {x = 86, y = 96, name = "Southern forest ridge rise", first = "up"},
        {x = 84, y = 96, name = "Southern forest ridge west lane", first = "left"},
        {x = 84, y = 92, name = "Southern forest middle rise", first = "up"},
        {x = 83, y = 92, name = "Southern forest middle west step", first = "left"},
        {x = 83, y = 90, name = "Southern forest upper rise", first = "up"},
        {x = 82, y = 90, name = "Southern forest upper west step", first = "left"},
        {x = 82, y = 84, name = "Southern forest long rise", first = "up"},
        {x = 79, y = 84, name = "Southern forest northwest lane", first = "left"},
        {x = 79, y = 83, name = "Southern forest northwest rise", first = "up"},
        {x = 78, y = 83, name = "Southern forest northwest step", first = "left"},
        {x = 78, y = 81, name = "Southern forest north rise", first = "up"},
        {x = 77, y = 81, name = "Southern forest north west step", first = "left"},
        {x = 77, y = 80, name = "Southern forest north gate", first = "up"},
        {x = 64, y = 80, name = "Southern forest north road", first = "left"},
        {x = 64, y = 81, name = "Southern forest northwest drop", first = "down"},
        {x = 63, y = 81, name = "Southern forest northwest west step", first = "left"},
        {x = 63, y = 82, name = "Southern forest northwest lower step", first = "down"},
        {x = 62, y = 82, name = "Southern forest northwest notch", first = "left"},
        {x = 62, y = 83, name = "Southern forest northwest exit", first = "down"},
        {x = 62, y = 84, name = "Southern forest west shelf", first = "down"},
    }

    local x, y = 89, 113
    for _, waypoint in ipairs(expected) do
        local segment = assert(routes.plan_next_segment(0x01, x, y))
        assert_equal(segment.waypoint.name, waypoint.name, "northwestern connector should preserve the verified turns")
        assert_equal(segment.steps[1], waypoint.first, waypoint.name .. " should begin in the proven direction")
        routes.observe_position(0x01, waypoint.x, waypoint.y)
        x, y = waypoint.x, waypoint.y
    end

    routes.reset_for_tests()
end
```

- [ ] **Step 4: Add the failing western-join, selection-bound, and arrival tests**

Add:

```lua
function tests.cantlin_hauksness_joins_validated_final_approach()
    routes.reset_for_tests()
    routes.start("cantlin to hauksness", 0x01, 32, 103)

    local expected = {
        {x = 15, y = 103, name = "Hauksness southern origin road", first = "left"},
        {x = 15, y = 93, name = "Hauksness lower west lane", first = "up"},
        {x = 15, y = 89, name = "Hauksness west approach", first = "up"},
        {x = 24, y = 89, name = "Hauksness doorstep west", first = "right"},
        {x = 25, y = 89, name = "Hauksness", first = "right"},
    }

    local x, y = 32, 103
    for _, waypoint in ipairs(expected) do
        local segment = assert(routes.plan_next_segment(0x01, x, y))
        assert_equal(segment.waypoint.name, waypoint.name, "Cantlin route should join the validated Hauksness approach")
        assert_equal(segment.steps[1], waypoint.first, waypoint.name .. " should begin in the proven direction")
        if waypoint.name == "Hauksness" then
            assert_equal(segment.path_length, 1, "final Hauksness entry should remain one strict east step")
        else
            routes.observe_position(0x01, waypoint.x, waypoint.y)
            x, y = waypoint.x, waypoint.y
        end
    end

    routes.reset_for_tests()
end

function tests.cantlin_hauksness_variant_does_not_steal_shared_approach()
    routes.reset_for_tests()

    local info, err = routes.start("hauksness", 0x01, 15, 93)

    assert_equal(err, nil, "ordinary Hauksness route should start at the established lower lane")
    assert_equal(info.route.id, "hauksness", "Cantlin variant should not steal the shared Hauksness approach")
    assert_equal(info.object_id, "route_hauksness_86", "existing Hauksness route should retain its west-approach target")

    routes.reset_for_tests()
end

function tests.entering_hauksness_stops_cantlin_variant()
    routes.reset_for_tests()
    routes.start("cantlin to hauksness", 0x01, 73, 103)

    local event = routes.observe_position(0x03, 0, 0)

    assert_contains(event.message, "Arrived at Hauksness", "entering Hauksness should complete the Cantlin variant")
    assert_equal(event.refresh, true, "Hauksness arrival should refresh Travel objects")
    assert_equal(routes.is_active(), false, "Cantlin variant should stop after entering Hauksness")

    routes.reset_for_tests()
end
```

- [ ] **Step 5: Run the tests and verify the missing route fails cleanly**

Run:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "cd /d/modding/DragonWarrior1 && luajit test_overworld_routes.lua"
```

Expected: the existing 108 tests remain green, the ten new tests fail because
`hauksness_cantlin` and its aliases do not exist, and the final count is
`Ran 118 Lua unit tests`. Syntax or harness failures are not an acceptable RED
state.

- [ ] **Step 6: Commit the RED tests**

Run:

```powershell
git add test_overworld_routes.lua
git diff --cached --check
git commit -m "test: specify Cantlin return route to Hauksness"
```

Expected: the commit contains only `test_overworld_routes.lua`, with ten
intentional failing regressions.

---

### Historical Task 2: Rejected Cantlin-side Hauksness candidate

**Files:**
- Modify: `overworld_routes.lua` in `ROUTES`, `ROUTE_IDS`, and `ROUTE_ALTERNATES`
- Test: `test_overworld_routes.lua`

**Interfaces:**
- Consumes: the existing `choose_next_index`, `route_start_score`, `choose_best_route_id`, `route_id_for_object`, and destination-map completion behavior
- Produces: route id `hauksness_cantlin`; aliases `hauksness from cantlin`, `cantlin to hauksness`, and `return from cantlin`; target object `overworld_hauksness`; destination map `0x03`; route-start cutoff `selection_max_index = 69`

- [ ] **Step 1: Add the literal route table**

Add this route immediately after `ROUTES.hauksness`:

```lua
    hauksness_cantlin = {
        id = "hauksness_cantlin",
        title = "Hauksness",
        aliases = {
            "hauksness from cantlin",
            "cantlin to hauksness",
            "return from cantlin",
        },
        target_object_ids = {"overworld_hauksness"},
        destination_maps = {0x03},
        -- Auto-selection ends before the shared final approach; an active route retains the full chain.
        selection_max_index = 69,
        waypoints = {
            {x = 73, y = 103, name = "Cantlin", radius = 0},
            {
                x = 72,
                y = 103,
                name = "Cantlin entrance west step",
                radius = 0,
                warning = "Cantlin return to Hauksness. Strong monsters remain throughout the southern route; keep HP high.",
            },
            {x = 72, y = 101, name = "Cantlin entrance north lane", radius = 0},
            {x = 74, y = 101, name = "Cantlin south road west bend", radius = 0},
            {x = 87, y = 101, name = "Cantlin south road east bend", radius = 0},
            {x = 87, y = 107, name = "Cantlin forest east descent", radius = 0},
            {x = 86, y = 107, name = "Cantlin forest east west step", radius = 0},
            {x = 86, y = 108, name = "Cantlin forest east lower step", radius = 0},
            {x = 85, y = 108, name = "Cantlin forest middle west step", radius = 0},
            {x = 85, y = 109, name = "Cantlin forest middle lower step", radius = 0},
            {x = 81, y = 109, name = "Cantlin forest west corridor", radius = 0},
            {x = 81, y = 110, name = "Cantlin forest west lower step", radius = 0},
            {x = 80, y = 110, name = "Cantlin forest west first step", radius = 0},
            {x = 80, y = 111, name = "Cantlin forest west first drop", radius = 0},
            {x = 79, y = 111, name = "Cantlin forest west second step", radius = 0},
            {x = 79, y = 112, name = "Cantlin forest west second drop", radius = 0},
            {x = 78, y = 112, name = "Cantlin forest southwest step", radius = 0},
            {x = 78, y = 113, name = "Cantlin forest southwest gate", radius = 0},
            {x = 78, y = 114, name = "Southern maze west entry", radius = 0},
            {x = 79, y = 114, name = "Southern maze first east step", radius = 0},
            {x = 79, y = 115, name = "Southern maze first drop", radius = 0},
            {x = 82, y = 115, name = "Southern maze west corridor", radius = 0},
            {x = 82, y = 116, name = "Southern maze lower west step", radius = 0},
            {x = 85, y = 116, name = "Southern maze lower corridor", radius = 0},
            {x = 85, y = 115, name = "Southern maze east rise", radius = 0},
            {x = 87, y = 115, name = "Southern maze east corridor", radius = 0},
            {x = 87, y = 114, name = "Southern maze second rise", radius = 0},
            {x = 88, y = 114, name = "Southern maze northeast step", radius = 0},
            {x = 88, y = 113, name = "Southern maze northeast rise", radius = 0},
            {x = 89, y = 113, name = "Southern maze north gate", radius = 0},
            {x = 89, y = 100, name = "Southern forest north corridor", radius = 0},
            {x = 87, y = 100, name = "Southern forest west bend", radius = 0},
            {x = 87, y = 97, name = "Southern forest west rise", radius = 0},
            {x = 86, y = 97, name = "Southern forest ridge west step", radius = 0},
            {x = 86, y = 96, name = "Southern forest ridge rise", radius = 0},
            {x = 84, y = 96, name = "Southern forest ridge west lane", radius = 0},
            {x = 84, y = 92, name = "Southern forest middle rise", radius = 0},
            {x = 83, y = 92, name = "Southern forest middle west step", radius = 0},
            {x = 83, y = 90, name = "Southern forest upper rise", radius = 0},
            {x = 82, y = 90, name = "Southern forest upper west step", radius = 0},
            {x = 82, y = 84, name = "Southern forest long rise", radius = 0},
            {x = 79, y = 84, name = "Southern forest northwest lane", radius = 0},
            {x = 79, y = 83, name = "Southern forest northwest rise", radius = 0},
            {x = 78, y = 83, name = "Southern forest northwest step", radius = 0},
            {x = 78, y = 81, name = "Southern forest north rise", radius = 0},
            {x = 77, y = 81, name = "Southern forest north west step", radius = 0},
            {x = 77, y = 80, name = "Southern forest north gate", radius = 0},
            {x = 64, y = 80, name = "Southern forest north road", radius = 0},
            {x = 64, y = 81, name = "Southern forest northwest drop", radius = 0},
            {x = 63, y = 81, name = "Southern forest northwest west step", radius = 0},
            {x = 63, y = 82, name = "Southern forest northwest lower step", radius = 0},
            {x = 62, y = 82, name = "Southern forest northwest notch", radius = 0},
            {x = 62, y = 83, name = "Southern forest northwest exit", radius = 0},
            {x = 62, y = 84, name = "Southern forest west shelf", radius = 0},
            {x = 58, y = 84, name = "Southwest forest east shelf", radius = 0},
            {x = 58, y = 86, name = "Southwest forest east drop", radius = 0},
            {x = 50, y = 86, name = "Southwest forest north road", radius = 0},
            {x = 50, y = 94, name = "Southwest forest west descent", radius = 0},
            {x = 44, y = 94, name = "Southwest forest west road", radius = 0},
            {x = 44, y = 97, name = "Southwest forest west drop", radius = 0},
            {x = 42, y = 97, name = "Southwest forest lower west step", radius = 0},
            {x = 42, y = 98, name = "Southwest forest lower drop", radius = 0},
            {x = 38, y = 98, name = "Southwest forest lower road", radius = 0},
            {x = 38, y = 97, name = "Southwest forest lower rise", radius = 0},
            {x = 37, y = 97, name = "Southwest forest west step", radius = 0},
            {x = 37, y = 99, name = "Southwest forest final drop", radius = 0},
            {x = 32, y = 99, name = "Hauksness southern road east bend", radius = 0},
            {x = 32, y = 103, name = "Hauksness southern road lower bend", radius = 0},
            {x = 15, y = 103, name = "Hauksness southern origin road", radius = 0},
            {x = 15, y = 93, name = "Hauksness lower west lane", radius = 0},
            {
                x = 15,
                y = 89,
                name = "Hauksness west approach",
                radius = 0,
                warning = "Hauksness ruins are very dangerous. Be ready for strong encounters.",
            },
            {x = 24, y = 89, name = "Hauksness doorstep west", radius = 0},
            {x = 25, y = 89, name = "Hauksness", radius = 0, final = true},
        },
    },
```

- [ ] **Step 2: Register deterministic lookup and both Hauksness alternates**

Add `"hauksness_cantlin"` immediately after `"hauksness"` in `ROUTE_IDS`.
Add these entries to `ROUTE_ALTERNATES`:

```lua
    hauksness = {"hauksness", "hauksness_cantlin"},
    hauksness_cantlin = {"hauksness_cantlin", "hauksness"},
```

The relevant `ROUTE_IDS` excerpt must read:

```lua
    "swamp_cave_south",
    "swamp_cave_south_recovery",
    "hauksness",
    "hauksness_cantlin",
    "erdrick",
```

Do not modify `route_start_score`: its existing `selection_max_index` support
already supplies the required local-selection cutoff.

- [ ] **Step 3: Run the focused route tests and verify GREEN**

Run:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "cd /d/modding/DragonWarrior1 && luajit test_overworld_routes.lua"
```

Expected: exit zero, no `FAIL` lines, and final count
`Ran 118 Lua unit tests`.

- [ ] **Step 4: Run route-manager regression and bytecode checks**

Run:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "cd /d/modding/DragonWarrior1 && luajit test_route_manager.lua && luajit -b overworld_routes.lua /tmp/overworld_routes.luac && luajit -b test_overworld_routes.lua /tmp/test_overworld_routes.luac"
git diff --check -- overworld_routes.lua test_overworld_routes.lua
```

Expected: `test_route_manager.lua` exits zero with `Ran 113 Lua unit tests`;
both bytecode checks exit zero; `git diff --check` prints nothing.

- [ ] **Step 5: Inspect the exact source diff**

Run:

```powershell
git diff -- overworld_routes.lua test_overworld_routes.lua
git status --short
```

Expected: production changes are limited to the literal route, one
`ROUTE_IDS` entry, and two Hauksness alternate lists. The only intended test
changes are the ten regressions from Task 1. The unrelated
`work_notes/hauksness_stat_corruption_20260724.log` remains untracked.

- [ ] **Step 6: Commit the production route**

Run:

```powershell
git add overworld_routes.lua
git diff --cached --check
git commit -m "feat: add Cantlin return route to Hauksness"
```

Expected: the commit contains only `overworld_routes.lua`; Task 1's test
commit remains separate.

---

### Historical Task 3: Initial automated verification gate

**Files:**
- Verify: `overworld_routes.lua`
- Verify: `test_overworld_routes.lua`
- Verify: `route_manager.lua`
- Verify: `auto_step.lua`

**Interfaces:**
- Consumes: the complete source and test commits from Tasks 1 and 2
- Produces: focused route, route-manager, executor, bytecode, whitespace, and full-harness evidence before any live-state claim

- [ ] **Step 1: Run all focused suites affected by the stacked change**

Run:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "cd /d/modding/DragonWarrior1 && luajit test_overworld_routes.lua && luajit test_route_manager.lua && luajit test_auto_step.lua && luajit test_battle.lua"
```

Expected:

- `test_overworld_routes.lua`: `Ran 118 Lua unit tests`;
- `test_route_manager.lua`: `Ran 113 Lua unit tests`;
- `test_auto_step.lua`: `Ran 140 Lua unit tests`;
- `test_battle.lua`: `Ran 43 Lua unit tests`;
- no `FAIL` lines.

- [ ] **Step 2: Byte-compile all touched and behavior-adjacent Lua files**

Run:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "cd /d/modding/DragonWarrior1 && luajit -b overworld_routes.lua /tmp/overworld_routes.luac && luajit -b test_overworld_routes.lua /tmp/test_overworld_routes.luac && luajit -b route_manager.lua /tmp/route_manager.luac && luajit -b auto_step.lua /tmp/auto_step.luac"
```

Expected: exit zero with no syntax or bytecode errors.

- [ ] **Step 3: Run whitespace and full repository verification**

Run:

```powershell
git diff --check
wsl.exe bash -lc "cd /mnt/d/modding/DragonWarrior1 && python3 run_tests.py --allow-missing-speech-dep"
```

Expected: `git diff --check` prints nothing; the full repository harness
passes, allowing only the known optional `accessible_output2` warning.

---

### Historical Task 4: Rejected live-validation procedure

**Files:**
- Read: `dw_debug.log`
- Preserve working evidence: `work_notes/current_investigation.md`

**Interfaces:**
- Consumes: `hauksness_cantlin`, Cantlin's existing southeast Exit to World Map object, the ordinary Hauksness Travel object, `route_guidance`, `route_status`, `auto_walk`, `report_position`, `report_path_state`, `report_runtime_blocks`, `report_input_guard_state`, and FCEUX manual Lua restart
- Produces: live evidence for the actual Cantlin World Map landing, route selection, each major corridor, route-aware carry behavior, strict final entry, and destination-map completion

- [ ] **Step 1: Pause for the user's manual FCEUX Lua restart**

Tell the user:

```text
The route source and automated tests are ready. Please use Restart in FCEUX's
Lua Script Control, reach Cantlin normally, select its southeast Exit to World
Map, and stop immediately after the transition. Tell me when you are on the
World Map with no route running.
```

Do not treat source-on-disk results as live before the restart.

- [ ] **Step 2: Establish fresh polling and record the actual exit landing**

After the user confirms the transition, run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait-ready CANTLIN_HAUKSNESS_RETURN
.\dw_commands.ps1 --replace --timeout 15 --wait "POSITION:" report_position route_status report_path_state report_runtime_blocks report_input_guard_state
```

Expected: fresh launcher tag `CANTLIN_HAUKSNESS_RETURN`, World Map `0x01`,
no active route/path, no runtime blockers, and clean controller/input state.
The expected coordinate from existing entry evidence is `(73,103)`, but the
fresh town-exit observation is authoritative. If it differs, stop before
starting guidance and make the smallest test-first adjustment to waypoint 1
and its selection tests.

- [ ] **Step 3: Select the ordinary Hauksness object and confirm the variant**

Use the normal object-filter controls to select `Hauksness` under Travel.
Confirm:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait "OBJECT:" current_object
.\dw_commands.ps1 --replace --timeout 15 --wait "route=hauksness_cantlin" route_guidance route_status
```

Expected: the current object is the ordinary Hauksness Travel destination;
`OVERWORLD_ROUTE` reports `route=hauksness_cantlin`; the first active target is
`Cantlin entrance west step (72,103)`.

- [ ] **Step 4: Validate one route segment at a time**

For each segment, run:

```powershell
.\dw_commands.ps1 --replace auto_walk
Get-Content -LiteralPath 'dw_debug.log' -Tail 120
```

Do not queue the next `auto_walk` until the log reports the expected waypoint
advance, an accepted route-aware carry, battle start, or explicit
timeout/drift/cancellation.

Validate these checkpoint groups in order:

1. Cantlin departure:
   `(72,103)`, `(72,101)`, `(74,101)`, `(87,101)`.
2. Eastern forest zigzag:
   `(87,107)`, `(86,107)`, `(86,108)`, `(85,108)`, `(85,109)`,
   `(81,109)`, `(81,110)`, `(80,110)`, `(80,111)`, `(79,111)`,
   `(79,112)`, `(78,112)`, `(78,113)`.
3. Southern maze:
   `(78,114)`, `(79,114)`, `(79,115)`, `(82,115)`, `(82,116)`,
   `(85,116)`, `(85,115)`, `(87,115)`, `(87,114)`, `(88,114)`,
   `(88,113)`, `(89,113)`.
4. Northwestern connector:
   `(89,100)`, `(87,100)`, `(87,97)`, `(86,97)`, `(86,96)`,
   `(84,96)`, `(84,92)`, `(83,92)`, `(83,90)`, `(82,90)`,
   `(82,84)`, `(79,84)`, `(79,83)`, `(78,83)`, `(78,81)`,
   `(77,81)`, `(77,80)`, `(64,80)`, `(64,81)`, `(63,81)`,
   `(63,82)`, `(62,82)`, `(62,83)`, `(62,84)`.
5. Southwest forest and Hauksness origin:
   `(58,84)`, `(58,86)`, `(50,86)`, `(50,94)`, `(44,94)`,
   `(44,97)`, `(42,97)`, `(42,98)`, `(38,98)`, `(38,97)`,
   `(37,97)`, `(37,99)`, `(32,99)`, `(32,103)`, `(15,103)`,
   `(15,93)`.
6. Validated Hauksness entry:
   `(15,89)`, `(24,89)`, then strict east entry at `(25,89)` into
   map `0x03`.

- [ ] **Step 5: Check recent autowalk behavior during the route**

At one long corridor, one one-tile turn, and the final entry, inspect the
latest log for:

```text
OVERWORLD_AUTO_WALK
carry=(...)
```

Confirm:

- long corridor metadata may carry only along the same route segment;
- a one-tile turn settles on its exact waypoint before changing direction;
- any guarded early-twitch release is logged and the route resumes without
  injecting a blocker;
- the final Hauksness segment reports strict carry metadata
  `carry=(nil,nil)`.

These checks are smoke evidence for the already automated route-aware carry
change. Absence of a naturally occurring early twitch is not a route failure
and must not be claimed as live proof of that waveform.

- [ ] **Step 6: Handle combat and apparent blockers conservatively**

If combat begins, stop sending movement commands. After the user clears it,
run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait "POSITION:" report_position route_status report_path_state report_runtime_blocks report_input_guard_state
```

If a segment times out or reports a block, preserve the exact origin and run
only the probe matching the failed logged direction:

```powershell
.\dw_commands.ps1 --replace --timeout 20 --wait "EDGE_PROBE_RESULT" "probe_edge:UP"
.\dw_commands.ps1 --replace --timeout 20 --wait "EDGE_PROBE_RESULT" "probe_edge:DOWN"
.\dw_commands.ps1 --replace --timeout 20 --wait "EDGE_PROBE_RESULT" "probe_edge:LEFT"
.\dw_commands.ps1 --replace --timeout 20 --wait "EDGE_PROBE_RESULT" "probe_edge:RIGHT"
```

Run exactly one of those four commands, never the whole block. A successful
same-origin probe is timing or route-geometry evidence, not a permanent
blocker. A repeated clean same-origin block starts a separate focused
test-first correction; do not add permanent map data during this validation.

- [ ] **Step 7: Confirm destination-map completion**

After the strict east step from `(24,89)`, run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait "POSITION:" report_position route_status report_path_state report_runtime_blocks
```

Expected: Ruins of Hauksness map `0x03`, route status
`event=status route=none`, no active path, and no runtime blocker used to force
completion.

---

### Task 5: Record durable validation state and publish the stacked draft PR

**Files:**
- Modify after end-to-end success: `PLAYTESTING.md`
- Modify after end-to-end success: `session_handoff.md`
- Preserve untracked: `work_notes/hauksness_stat_corruption_20260724.log`

**Interfaces:**
- Consumes: automated evidence from Task 3 and live evidence from Task 4
- Produces: durable project status, final verification commit, pushed branch `codex/cantlin-hauksness-return`, and a draft PR based on `codex/battle-dialogue-autowalk-tuning`

- [ ] **Step 1: Update durable docs only after end-to-end success**

Add this paragraph near the active Hauksness/Cantlin route status in
`PLAYTESTING.md`:

```markdown
- Cantlin-to-Hauksness return route (`2026-07-25`): after using Cantlin's
  existing southeast Exit to World Map, selecting the ordinary Hauksness
  Travel destination automatically chooses `hauksness_cantlin`. The explicit
  route is live-validated from actual World Map landing `(73,102)` through the
  northern departure, western and southern forest switchbacks, western
  corridor `(23,95)`, west approach `(22,89)`, and strict east entry from
  `(24,89)` into Hauksness map `0x03`. Combat remains a manual pause point; no
  runtime or permanent blocker is part of the route definition.
```

Add this concise item near the top of `session_handoff.md`:

```markdown
- Cantlin return complete: `hauksness_cantlin` is automated-test and live
  validated from normal Cantlin World Map landing `(73,102)` through the
  western and southern forest route to Hauksness map `0x03`. The ordinary
  Hauksness Travel object selects it automatically near Cantlin. Preserve the
  explicit switchbacks, `(23,95)->(22,95)->(22,89)` final approach, and strict
  `(24,89)->RIGHT` entry.
```

The paragraphs above contain the live-corrected coordinates; do not restore
the rejected pre-validation eastern-trail hypothesis from earlier task
examples.

- [ ] **Step 2: Re-run the complete verification gate**

Run:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "cd /d/modding/DragonWarrior1 && luajit test_overworld_routes.lua && luajit test_route_manager.lua && luajit test_auto_step.lua && luajit test_battle.lua"
wsl.exe bash -lc "cd /mnt/d/modding/DragonWarrior1 && python3 run_tests.py --allow-missing-speech-dep"
git diff --check
git status --short
```

Expected: 118 overworld-route, 113 route-manager, 140 auto-step, and 43 battle
tests pass; the full harness passes with only the known optional speech
dependency warning; `git diff --check` prints nothing.

- [ ] **Step 3: Commit only the durable validation docs**

Run:

```powershell
git add PLAYTESTING.md session_handoff.md
git diff --cached --check
git commit -m "docs: validate Cantlin return route to Hauksness"
```

Expected: the commit contains exactly `PLAYTESTING.md` and
`session_handoff.md`.

- [ ] **Step 4: Audit branch scope**

Run:

```powershell
git status --short --branch
git log --oneline codex/battle-dialogue-autowalk-tuning..HEAD
git diff --stat codex/battle-dialogue-autowalk-tuning...HEAD
```

Expected: the branch contains the design, implementation plan, RED tests,
production route, and live-validation docs. The only unrelated working-tree
item is the preserved untracked diagnostic log.

- [ ] **Step 5: Push the dedicated branch**

Run:

```powershell
git push -u origin codex/cantlin-hauksness-return
```

Expected: the remote branch is created and tracks
`origin/codex/cantlin-hauksness-return`.

- [ ] **Step 6: Open the stacked draft PR**

Create a draft PR with:

- base: `codex/battle-dialogue-autowalk-tuning`;
- head: `codex/cantlin-hauksness-return`;
- title: `Add Cantlin return route to Hauksness`;
- body:

```markdown
## Summary

- add an explicit Cantlin-side Hauksness overworld route variant
- select it automatically through the ordinary Hauksness Travel object near Cantlin
- preserve narrow southern-route turns and the validated strict Hauksness entry

## Verification

- `luajit test_overworld_routes.lua` - 118 passed
- `luajit test_route_manager.lua` - 113 passed
- `luajit test_auto_step.lua` - 140 passed
- `luajit test_battle.lua` - 43 passed
- `python3 run_tests.py --allow-missing-speech-dep` - passed
- live FCEUX route from Cantlin's World Map exit to Hauksness map `0x03` - passed

## Notes

- stacked on `codex/battle-dialogue-autowalk-tuning`
- combat remains a manual pause point
- no runtime or permanent blocker was added
```

Expected: a draft PR targets `codex/battle-dialogue-autowalk-tuning`, not the
repository default branch.
