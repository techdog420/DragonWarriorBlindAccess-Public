# Hauksness-to-Cantlin Route Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Completion note (2026-07-26):** Implemented and live-validated. The final route has 57 waypoints, not the initially planned exact 58-point reversal. Live evidence required two north-carry splices at `(50,99)->(50,98)` and `(64,92)->(64,91)`, plus horizontal-first recovery for the final Cantlin waypoint. The checklist and code samples below preserve the original execution plan; use `overworld_routes.lua`, the focused tests, and the completed design document as the current specification.

**Goal:** Add and live-validate a named World Map route from the Hauksness entrance to Cantlin by primarily reversing the validated Cantlin-to-Hauksness waypoint coordinates and retaining any live-proven directional adjustments.

**Architecture:** Add one explicit route record to the existing `overworld_routes.lua` registry and expose it through the existing Cantlin Travel object. Keep route selection, battle persistence, and map passability unchanged; tests compare the new coordinate chain with the validated outbound chain and explicitly assert validation-driven asymmetries.

**Tech Stack:** Lua route registry and regression harness, FCEUX 2.6.6, `dw_commands.sh`, `dw_debug.log`, WSL Lua test runner, Git.

## Global Constraints

- Keep the work on `codex/cantlin-hauksness-return` and draft PR #4.
- Route ID is `cantlin_hauksness`; title is `Cantlin`.
- Target object is `overworld_cantlin`; destination map is `0x0A`.
- Start anchor is Hauksness `(25,89)` and final World Map anchor is Cantlin `(73,102)`.
- Begin from the reversed `hauksness_cantlin` chain, then preserve live-proven carry splices explicitly. The validated result has 57 waypoints.
- Preserve `return from hauksness` exclusively for `kol_hauksness`.
- Do not change route-manager semantics or permanent/runtime map blockers. Route-local timing metadata is allowed only when supported by live evidence.
- During live QA, classify failures before changing source; a single failed movement is not map evidence.
- If the northern Cantlin entry is unreliable, stop and gather evidence before considering the proven `(73,103)->UP` southern entry.
- Preserve the unrelated untracked `work_notes/hauksness_stat_corruption_20260724.log`.

## File Structure

- Modify `overworld_routes.lua`: define and register the explicit reverse route.
- Modify `test_overworld_routes.lua`: cover selection, aliases, coordinate reversal, strict endpoints, destination matching, and arrival cleanup.
- Modify `session_handoff.md`: record only the final live-validated state and next action.
- Modify `PLAYTESTING.md`: record the durable route result and any verified timing behavior.
- Update `docs/plans/2026-07-25-hauksness-to-cantlin-route-design.md` with the completed validation outcome.

---

### Task 1: Add the Reverse Route with Focused Regressions

**Files:**
- Modify: `test_overworld_routes.lua:1747`
- Modify: `overworld_routes.lua:647`
- Modify: `overworld_routes.lua:980`

**Interfaces:**
- Consumes: `routes.start(route_name, map_id, px, py, opts)`, `routes.start_for_object(obj, map_id, px, py, opts)`, `routes.plan_next_segment(map_id, px, py, opts)`, `routes.observe_position(map_id, px, py, terrain_offset)`, and `routes._route_for_tests(id)`.
- Produces: route record `cantlin_hauksness`, alias resolution for `cantlin from hauksness`, `hauksness to cantlin`, and `return to cantlin`, and active waypoint object IDs `route_cantlin_hauksness_NN`.

- [ ] **Step 1: Write failing route-selection and alias tests**

Add these tests after the existing `hauksness_cantlin` tests:

```lua
function tests.cantlin_object_from_hauksness_uses_reverse_variant()
    routes.reset_for_tests()

    local info, err = routes.start_for_object({
        id = "overworld_cantlin",
        name = "Cantlin",
        x = 73,
        y = 102,
    }, 0x01, 25, 89)

    assert_equal(err, nil, "Cantlin Travel object should start at Hauksness")
    assert_equal(info.route.id, "cantlin_hauksness", "Cantlin object should choose the Hauksness variant")
    assert_equal(info.object_id, "route_cantlin_hauksness_02", "Hauksness start should skip the current entrance anchor")
    assert_contains(info.message, "Hauksness doorstep west", "route should begin west from Hauksness")

    local segment = assert(routes.plan_next_segment(0x01, 25, 89))
    assert_equal(segment.waypoint.x, 24, "first reverse target x")
    assert_equal(segment.waypoint.y, 89, "first reverse target y")
    assert_equal(segment.steps[1], "left", "first reverse step should leave Hauksness to the west")

    routes.reset_for_tests()
end

function tests.cantlin_hauksness_aliases_are_unambiguous()
    local aliases = {
        "cantlin from hauksness",
        "hauksness to cantlin",
        "return to cantlin",
    }

    for _, alias in ipairs(aliases) do
        routes.reset_for_tests()
        local info, err = routes.start(alias, 0x01, 25, 89)
        assert_equal(err, nil, alias .. " should resolve")
        assert_equal(info.route.id, "cantlin_hauksness", alias .. " should select the Cantlin route")
    end

    routes.reset_for_tests()
    local kol_info, kol_err = routes.start("return from hauksness", 0x01, 25, 89)
    assert_equal(kol_err, nil, "existing Kol return alias should still resolve")
    assert_equal(kol_info.route.id, "kol_hauksness", "Cantlin route must not steal the Kol return alias")

    routes.reset_for_tests()
end
```

- [ ] **Step 2: Write failing coordinate, endpoint, object-match, and arrival tests**

Add:

```lua
function tests.cantlin_hauksness_exactly_reverses_validated_route()
    local outbound = assert(routes._route_for_tests("hauksness_cantlin"))
    local inbound = assert(routes._route_for_tests("cantlin_hauksness"))

    assert_equal(#inbound.waypoints, 58, "Cantlin reverse route waypoint count")
    assert_equal(#inbound.waypoints, #outbound.waypoints, "reverse route should preserve waypoint count")

    for index, waypoint in ipairs(inbound.waypoints) do
        local expected = outbound.waypoints[#outbound.waypoints - index + 1]
        assert_equal(waypoint.x, expected.x, "reverse waypoint " .. index .. " x")
        assert_equal(waypoint.y, expected.y, "reverse waypoint " .. index .. " y")
    end

    assert_equal(inbound.waypoints[1].radius, 0, "Hauksness start anchor should be strict")
    assert_equal(inbound.waypoints[58].radius, 0, "Cantlin final anchor should be strict")
    assert_equal(inbound.waypoints[58].final, true, "Cantlin final anchor should finish the route")
end

function tests.active_hauksness_cantlin_route_matches_ordinary_cantlin_object()
    routes.reset_for_tests()
    routes.start("hauksness to cantlin", 0x01, 25, 89)

    local matches = routes.active_route_matches_object({
        id = "overworld_cantlin",
        name = "Cantlin",
        x = 73,
        y = 102,
    })

    assert_equal(matches, true, "active reverse route should retain the ordinary Cantlin destination")
    routes.reset_for_tests()
end

function tests.entering_cantlin_stops_hauksness_variant()
    routes.reset_for_tests()
    local info, err = routes.start("hauksness to cantlin", 0x01, 25, 89)

    assert_equal(err, nil, "Hauksness Cantlin alias should start")
    assert_equal(info.route.id, "cantlin_hauksness", "alias should select the reverse route")

    local event = routes.observe_position(0x0A, 15, 0)

    assert_contains(event.message, "Arrived at Cantlin", "entering Cantlin should complete the reverse route")
    assert_equal(event.refresh, true, "Cantlin arrival should refresh Travel objects")
    assert_equal(routes.is_active(), false, "reverse route should stop after entering Cantlin")

    routes.reset_for_tests()
end
```

- [ ] **Step 3: Run the focused tests and confirm the expected red state**

Run:

```powershell
wsl.exe bash -lc "cd /mnt/d/modding/DragonWarrior1 && lua test_overworld_routes.lua"
```

Expected: FAIL because `routes._route_for_tests("cantlin_hauksness")` is absent or the aliases return `Unknown overworld route`. Existing earlier tests should remain green up to the first new test.

- [ ] **Step 4: Add the explicit reverse route**

Insert this route after `hauksness_cantlin` and before `kol_hauksness` in `overworld_routes.lua`:

```lua
    cantlin_hauksness = {
        id = "cantlin_hauksness",
        title = "Cantlin",
        aliases = {
            "cantlin from hauksness",
            "hauksness to cantlin",
            "return to cantlin",
        },
        target_object_ids = {"overworld_cantlin"},
        destination_maps = {0x0A},
        waypoints = {
            {x = 25, y = 89, name = "Hauksness", radius = 0},
            {
                x = 24,
                y = 89,
                name = "Hauksness doorstep west",
                radius = 0,
                warning = "Hauksness route to Cantlin. Strong monsters remain throughout the eastern route; keep HP high.",
            },
            {x = 22, y = 89, name = "Hauksness west approach", radius = 0},
            {x = 22, y = 95, name = "Hauksness western corridor south lane", radius = 0},
            {x = 23, y = 95, name = "Hauksness western corridor east step", radius = 0},
            {x = 23, y = 107, name = "Hauksness south corridor", radius = 0},
            {x = 22, y = 107, name = "Hauksness south road west step", radius = 0},
            {x = 22, y = 108, name = "Hauksness south road south step", radius = 0},
            {x = 20, y = 108, name = "Hauksness south road west lane", radius = 0},
            {x = 20, y = 116, name = "Southern forest northwest entry", radius = 0},
            {x = 21, y = 116, name = "Southern forest first east step", radius = 0},
            {x = 21, y = 117, name = "Southern forest lower lane", radius = 0},
            {x = 33, y = 117, name = "Southern forest long east lane", radius = 0},
            {x = 33, y = 116, name = "Southern forest first rise", radius = 0},
            {x = 36, y = 116, name = "Southern forest second east lane", radius = 0},
            {x = 36, y = 115, name = "Southern forest second rise", radius = 0},
            {x = 38, y = 115, name = "Southern forest third east lane", radius = 0},
            {x = 38, y = 114, name = "Southern forest third rise", radius = 0},
            {x = 39, y = 114, name = "Southern forest fourth east step", radius = 0},
            {x = 39, y = 113, name = "Southern forest fourth rise", radius = 0},
            {x = 40, y = 113, name = "Southern forest fifth east step", radius = 0},
            {x = 40, y = 112, name = "Southern forest fifth rise", radius = 0},
            {x = 41, y = 112, name = "Southern forest sixth east step", radius = 0},
            {x = 41, y = 111, name = "Southern forest sixth rise", radius = 0},
            {x = 42, y = 111, name = "Southern forest seventh east step", radius = 0},
            {x = 42, y = 108, name = "Southern forest long rise", radius = 0},
            {x = 43, y = 108, name = "Western forest first east step", radius = 0},
            {x = 43, y = 107, name = "Western forest first rise", radius = 0},
            {x = 44, y = 107, name = "Western forest second east step", radius = 0},
            {x = 44, y = 106, name = "Western forest second rise", radius = 0},
            {x = 45, y = 106, name = "Western forest third east step", radius = 0},
            {x = 45, y = 105, name = "Western forest third rise", radius = 0},
            {x = 47, y = 105, name = "Western forest fourth east lane", radius = 0},
            {x = 47, y = 104, name = "Western forest fourth rise", radius = 0},
            {x = 48, y = 104, name = "Western forest fifth east step", radius = 0},
            {x = 48, y = 102, name = "Western forest first long rise", radius = 0},
            {x = 49, y = 102, name = "Western forest sixth east step", radius = 0},
            {x = 49, y = 100, name = "Western forest second long rise", radius = 0},
            {x = 50, y = 100, name = "Western forest seventh east step", radius = 0},
            {x = 50, y = 99, name = "Western forest seventh rise", radius = 0},
            {x = 51, y = 99, name = "Western forest eighth east step", radius = 0},
            {x = 51, y = 98, name = "Western forest eighth rise", radius = 0},
            {x = 52, y = 98, name = "Western forest ninth east step", radius = 0},
            {x = 52, y = 97, name = "Western forest ninth rise", radius = 0},
            {x = 53, y = 97, name = "Western forest tenth east step", radius = 0},
            {x = 53, y = 96, name = "Western forest tenth rise", radius = 0},
            {x = 54, y = 96, name = "Western forest eleventh east step", radius = 0},
            {x = 54, y = 95, name = "Western forest final rise", radius = 0},
            {x = 56, y = 95, name = "Upper forest first east lane", radius = 0},
            {x = 56, y = 94, name = "Upper forest first rise", radius = 0},
            {x = 60, y = 94, name = "Upper forest middle east lane", radius = 0},
            {x = 60, y = 93, name = "Upper forest second rise", radius = 0},
            {x = 64, y = 93, name = "Upper forest upper east lane", radius = 0},
            {x = 64, y = 92, name = "Upper forest third rise", radius = 0},
            {x = 68, y = 92, name = "Cantlin western approach", radius = 0},
            {x = 68, y = 91, name = "Cantlin northwest turn", radius = 0},
            {x = 73, y = 91, name = "Cantlin north road", radius = 0},
            {x = 73, y = 102, name = "Cantlin", radius = 0, final = true},
        },
    },
```

Add `"cantlin_hauksness"` immediately after `"hauksness_cantlin"` in `ROUTE_IDS`. Do not add it to the Hauksness alternates because it has a different destination, and do not add `return from hauksness` to its aliases.

- [ ] **Step 5: Run the focused route tests and confirm green**

Run:

```powershell
wsl.exe bash -lc "cd /mnt/d/modding/DragonWarrior1 && lua test_overworld_routes.lua"
```

Expected: all `test_overworld_routes.lua` tests pass, with the total increased by five.

- [ ] **Step 6: Run neighboring route-manager and movement regressions**

Run:

```powershell
wsl.exe bash -lc "cd /mnt/d/modding/DragonWarrior1 && lua test_route_manager.lua && lua test_auto_step.lua && lua test_battle.lua"
```

Expected: all four focused suites pass. The optional `accessible_output2` warning is acceptable; any assertion failure is not.

- [ ] **Step 7: Check syntax, whitespace, and intended scope**

Run:

```powershell
wsl.exe bash -lc "cd /mnt/d/modding/DragonWarrior1 && luac -p overworld_routes.lua test_overworld_routes.lua"
git diff --check
git status --short
git diff -- overworld_routes.lua test_overworld_routes.lua
```

Expected: syntax and whitespace checks pass; only the two intended source/test files plus the implementation-plan document are changed, while `work_notes/hauksness_stat_corruption_20260724.log` remains untracked.

- [ ] **Step 8: Commit the tested route implementation**

Run:

```powershell
git add overworld_routes.lua test_overworld_routes.lua
git commit -m "feat: add Hauksness route to Cantlin"
```

Expected: one commit containing only `overworld_routes.lua` and `test_overworld_routes.lua`.

---

### Task 2: Reload and Live-Validate the Reverse Route

**Files:**
- Read: `dw_debug.log`
- Read: `dw_commands.sh`
- Modify after successful validation: `session_handoff.md`
- Modify after successful validation: `PLAYTESTING.md`

**Interfaces:**
- Consumes: FCEUX polling loop, `launcher_probe:TAG`, `report_position`, `report_path_state`, `report_runtime_blocks`, `start_overworld_route:hauksness to cantlin`, `auto_walk`, and route log events.
- Produces: live evidence that `cantlin_hauksness` walks from `(25,89)` into map `0x0A`, plus durable handoff/playtesting status.

- [ ] **Step 1: Pause for the user’s manual FCEUX Lua reload**

Tell the user that `overworld_routes.lua` changed and FCEUX requires a manual script reload. Do not queue the route until the user confirms the reload.

- [ ] **Step 2: Establish a fresh Hauksness baseline**

Run:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "cd /d/modding/DragonWarrior1 && ./dw_commands.sh --replace launcher_probe:cantlin_reverse_ready report_position report_path_state report_runtime_blocks"
```

Then inspect the new end of `dw_debug.log`.

Expected baseline:

```text
LAUNCHER_PROBE: cantlin_reverse_ready
POSITION: map=0x01 ... x=25 y=89
```

Also require no active route and no runtime blocks. If the player is still inside map `0x03`, ask the user to exit Hauksness before continuing.

- [ ] **Step 3: Start and verify the explicit reverse route**

Run:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "cd /d/modding/DragonWarrior1 && ./dw_commands.sh --replace 'start_overworld_route:hauksness to cantlin' route_status"
```

Expected log evidence:

```text
event=start route=cantlin_hauksness
```

The next waypoint must be `Hauksness doorstep west`, index `2`, west of `(25,89)`.

- [ ] **Step 4: Walk one waypoint segment at a time**

For each segment, queue only:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "cd /d/modding/DragonWarrior1 && ./dw_commands.sh --replace auto_walk"
```

Inspect the fresh log tail after every segment. Require either:

- `event=reached route=cantlin_hauksness` with the next index, or
- a clearly classified interruption.

When battle begins, stop queueing commands and tell the user the exact World Map coordinate and route index. After the user reports the field is clear, queue a fresh `report_position report_path_state route_status` batch before resuming.

For a movement stop, capture the origin, requested direction, actual position, route index, and settle result. Use a same-origin `probe_edge:DIR` only when the live state is clean and the edge itself needs classification. Do not add blockers during this pass.

- [ ] **Step 5: Verify Cantlin arrival and cleanup**

The success condition is a route event equivalent to:

```text
event=arrived route=cantlin_hauksness waypoint=Cantlin index=57
```

followed by a fresh probe showing:

```text
map=0x0A
x=15 y=0
route=none
```

Also confirm menu/dialogue state is closed and runtime blockers remain empty. If the route stops on the northern approach without entering Cantlin, preserve the precise evidence and stop before altering the endpoint.

- [ ] **Step 6: Update durable route-status documentation**

At the top current-state sections of `session_handoff.md` and `PLAYTESTING.md`, record:

- commit/branch context,
- the exact start `(25,89)`,
- the final arrival event and Cantlin landing `(15,0)`,
- the number and classification of any battle or recoverable timing interruptions,
- whether any blockers were added (expected: none),
- and the next gameplay/route objective.

Do not paste raw log dumps into either durable document.

- [ ] **Step 7: Run final verification**

Run:

```powershell
wsl.exe bash -lc "cd /mnt/d/modding/DragonWarrior1 && lua test_overworld_routes.lua && lua test_route_manager.lua && lua test_auto_step.lua && lua test_battle.lua"
wsl.exe bash -lc "cd /mnt/d/modding/DragonWarrior1 && python3 run_tests.py"
git diff --check
git status --short
```

Expected: focused suites and full harness pass; only the known optional `accessible_output2` warning is acceptable. The untracked Hauksness diagnostic log remains untouched.

- [ ] **Step 8: Commit, push, and update draft PR #4**

Run:

```powershell
git add session_handoff.md PLAYTESTING.md
git commit -m "docs: record Hauksness to Cantlin validation"
git push
```

Expected: the branch pushes successfully and draft PR #4 contains the design, implementation, tests, and live-validation evidence.
