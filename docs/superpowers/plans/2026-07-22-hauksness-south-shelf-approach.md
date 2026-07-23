# Hauksness South-Shelf Approach Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Hauksness guidance correct west before descending at the blocked `(16,27)->DOWN` seam, then validate that fix and the existing southern-road fix in FCEUX.

**Architecture:** Keep the solution entirely in Hauksness waypoint metadata. Add horizontal-first ordering to `Western desert south shelf (15,28)`, preserve the same invariant on `Western desert east shelf (15,14)`, and cover both the planned LEFT-then-DOWN behavior and route metadata with focused Lua regressions. Live validation uses the existing route command and one auto-walk segment at a time; no World Map blocker data or general planner behavior changes.

**Tech Stack:** LuaJIT, repository Lua unit-test harness, FCEUX 2.6.6, `dw_commands.ps1`, `dw_debug.log`, Git.

## Global Constraints

- Do not change `map_reader.lua`, add a waypoint, or make the general overworld planner map-aware.
- Do not define a synthetic Hauksness return route in this patch.
- Preserve `Western desert east shelf (15,14)` with horizontal-first ordering as the reverse-seam invariant.
- Use normal World Map movement and existing route guidance for live proof; do not teleport to the seam.
- Send one state-sensitive FCEUX command at a time with `--replace` and inspect fresh logs before continuing.
- Pause immediately for combat or dialogue and resume only after the user confirms field control.
- Preserve the unrelated uncommitted changes in `work_notes/current_investigation.md` and do not stage that file with this patch.

---

### Task 1: Add the seam regressions and waypoint-local fix

**Files:**
- Modify: `test_overworld_routes.lua:1300-1310`
- Modify: `overworld_routes.lua:591-598`

**Interfaces:**
- Consumes: `routes.start(route_id, map_id, x, y)`, `routes.plan_next_segment(map_id, x, y)`, `routes._route_for_tests(route_id)`, and the existing `find_waypoint(route_id, name)` test helper.
- Produces: `Western desert south shelf` with `axis_order = {"horizontal", "vertical"}`; no new functions or command semantics.

- [ ] **Step 1: Add the two focused failing regressions**

Add these tests immediately after `tests.hauksness_south_road_moves_east_before_blocked_x1_descent`:

```lua
function tests.hauksness_south_shelf_corrects_west_before_blocked_x16_descent()
    routes.reset_for_tests()
    routes.start("hauksness", 0x01, 16, 27)

    local segment = assert(routes.plan_next_segment(0x01, 16, 27))
    assert_equal(segment.waypoint.name, "Western desert south shelf", "blocked x16 approach should retain the south-shelf waypoint")
    assert_equal(segment.steps[1], "left", "south-shelf approach should correct west before descending")
    assert_equal(segment.steps[2], "down", "south-shelf approach should descend only after reaching x15")

    routes.reset_for_tests()
end

function tests.hauksness_desert_seam_waypoints_remain_horizontal_first()
    local east_shelf = assert(find_waypoint("hauksness", "Western desert east shelf"))
    local south_shelf = assert(find_waypoint("hauksness", "Western desert south shelf"))

    assert_equal(east_shelf.axis_order and east_shelf.axis_order[1], "horizontal", "east shelf should keep horizontal-first reverse-seam protection")
    assert_equal(east_shelf.axis_order and east_shelf.axis_order[2], "vertical", "east shelf should turn vertical after correcting its column")
    assert_equal(south_shelf.axis_order and south_shelf.axis_order[1], "horizontal", "south shelf should use horizontal-first forward-seam protection")
    assert_equal(south_shelf.axis_order and south_shelf.axis_order[2], "vertical", "south shelf should descend after correcting its column")
end
```

- [ ] **Step 2: Run the regressions and verify the expected red state**

Run:

```powershell
luajit test_overworld_routes.lua
```

Expected: exit code 1 after 94 tests. The behavior regression reports that the first step expected `left` but got `down`; the metadata regression reports that `Western desert south shelf` expected `horizontal` but got `nil`. All pre-existing tests remain passing.

- [ ] **Step 3: Add the minimal waypoint-local implementation**

Change only the south-shelf waypoint to:

```lua
            {
                x = 15,
                y = 28,
                name = "Western desert south shelf",
                radius = 0,
                axis_order = {"horizontal", "vertical"},
                warning = "Hauksness route. Strong monsters ahead; keep HP high.",
            },
```

- [ ] **Step 4: Run the focused suite and verify green**

Run:

```powershell
luajit test_overworld_routes.lua
```

Expected: exit code 0 and `Ran 94 Lua unit tests`, with both new test names reported as `PASS`.

- [ ] **Step 5: Byte-compile the changed Lua files**

Run:

```powershell
luajit -b overworld_routes.lua NUL
luajit -b test_overworld_routes.lua NUL
```

Expected: both commands exit 0 with no output.

- [ ] **Step 6: Review scope and whitespace**

Run:

```powershell
git diff --check -- overworld_routes.lua test_overworld_routes.lua
git diff -- overworld_routes.lua test_overworld_routes.lua
git status --short
```

Expected: no whitespace errors; the diff contains only two new tests and one `axis_order` field; `work_notes/current_investigation.md` remains modified but unstaged.

- [ ] **Step 7: Commit the static patch**

Run:

```powershell
git add overworld_routes.lua test_overworld_routes.lua
git commit -m "fix: route Hauksness around south shelf seam"
```

Expected: the commit contains exactly `overworld_routes.lua` and `test_overworld_routes.lua`.

---

### Task 2: Validate the forward seam and southern road in FCEUX

**Files:**
- Read: `dw_debug.log`
- Read: `dw_script_error.log`
- No source files change during live validation.

**Interfaces:**
- Consumes: FCEUX manual `main.lua` restart, `start_overworld_route:hauksness`, `auto_walk`, `report_position`, and `report_runtime_blocks`.
- Produces: fresh log evidence that the south-shelf segment runs LEFT then DOWN to `(15,28)` and the south-road segment runs RIGHT before descending to `(2,64)`.

- [ ] **Step 1: Ask the user to restart `main.lua` manually**

Do not queue movement until the user confirms the restart.

- [ ] **Step 2: Prove the new Lua loop is live and capture the baseline**

Run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait-ready hks_south_shelf_reload
.\dw_commands.ps1 --replace --timeout 15 --wait "POSITION:" report_position report_runtime_blocks
```

Expected: a fresh `LAUNCHER_PROBE: hks_south_shelf_reload`, World Map position, and `RUNTIME_BLOCKS map=0x01 none`. If the probe times out or `dw_script_error.log` gains a current error, stop and repair the reload before testing.

- [ ] **Step 3: Re-establish the live seam origin without teleporting**

The pre-reload position is `(15,28)`. Ask the user to move UP once to `(15,27)` and RIGHT once to `(16,27)`, pausing if a battle begins. Then run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait "POSITION:" report_position report_runtime_blocks
```

Expected: `POSITION: map=0x01(World Map) x=16 y=27` and no runtime blocks. If the position differs, do not start the route until normal movement reaches `(16,27)`.

- [ ] **Step 4: Start Hauksness guidance at the seam**

Run:

```powershell
.\dw_commands.ps1 --replace --require-live 60 --timeout 15 --wait "route=hauksness waypoint=Western desert south shelf" "start_overworld_route:hauksness"
```

Expected: `OVERWORLD_ROUTE: event=start route=hauksness waypoint=Western desert south shelf` with no route replacement or stale command.

- [ ] **Step 5: Execute and verify the two-step shelf segment**

Run:

```powershell
.\dw_commands.ps1 --replace --require-live 60 --timeout 30 --wait "event=complete route=hauksness waypoint=Western desert south shelf" auto_walk
Get-Content -LiteralPath 'dw_debug.log' -Tail 100 | Select-String -Pattern 'Western desert south shelf|AUTO_STEP_TRACE begin_step_before_joypad|POSITION:'
```

Expected: the start line says `steps=2 from=(16,27) to=(15,28)`; the first queued direction is `left`, the second is `down`, and completion occurs at `(15,28)`. There must be no new attempt at `(16,27)->DOWN`.

- [ ] **Step 6: Continue one route segment at a time to the west-wall carry landing**

For each segment, run the following command once, inspect the fresh completion/position, and only then repeat it:

```powershell
.\dw_commands.ps1 --replace --require-live 60 --timeout 30 --wait "OVERWORLD_ROUTE: event=advance route=hauksness" auto_walk
```

Expected waypoint sequence:

```text
Western desert west detour (13,28)
Western desert south detour (13,30)
Western desert lower west lane (11,30)
Western desert lower notch (11,31)
Western desert west notch (9,31)
Western desert vertical pass (8,31)
Western desert pass foot (8,34)
Western desert long descent (8,51)
Western desert row 51 west bend (6,51)
Western desert row 52 bend (6,52)
Western desert row 52 west lane (4,52)
Western desert lower shelf (4,54)
Western desert west wall (2,54)
```

At any battle, dialogue interruption, timeout, or unexpected coordinate, stop. The user clears the interruption, then run `report_position` and `route_status` before resuming; do not infer a blocker from the interruption.

- [ ] **Step 7: Establish the south-road regression origin**

Run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait "POSITION:" report_position report_runtime_blocks
```

Expected: the previously observed final carry lands at `(1,54)`. If it instead settles at `(2,54)`, ask the user to move LEFT once normally to `(1,54)`, then repeat the position report. Do not teleport.

- [ ] **Step 8: Execute and verify the southern-road segment**

Run:

```powershell
.\dw_commands.ps1 --replace --require-live 60 --timeout 30 --wait "event=complete route=hauksness waypoint=Western desert south road" auto_walk
Get-Content -LiteralPath 'dw_debug.log' -Tail 160 | Select-String -Pattern 'Western desert south road|AUTO_STEP_TRACE begin_step_before_joypad|POSITION:'
```

Expected: the segment starts from `(1,54)` toward `(2,64)`, its first queued direction is `right`, it descends only from x=2, and it completes at `(2,64)` without attempting `(1,63)->DOWN`.

- [ ] **Step 9: Capture the final live state**

Run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait "POSITION:" report_position report_runtime_blocks route_status
```

Expected: World Map `(2,64)`, runtime blocks none, and Hauksness guidance active toward `Western desert east road`. The forward seam and southern road are now live-verified; the full return route remains a separate task starting from its own defined origin.

---

### Task 3: Promote the verified route status into concise project docs

**Files:**
- Modify: `session_handoff.md:5-19`
- Modify: `PLAYTESTING.md:446-456`

**Interfaces:**
- Consumes: successful Task 2 log evidence.
- Produces: current active-resume guidance and durable player-facing route status; no runtime behavior changes.

- [ ] **Step 1: Update the active handoff only after both live checks pass**

In the first Hauksness bullet, replace the sentences beginning `The
horizontal-first Western desert south-road source patch` and ending
`dialogue-tuning pass.` with:

```markdown
The horizontal-first Western desert seam fixes are live-verified: from
`(16,27)`, south-shelf guidance moved LEFT to `(15,27)` before descending to
`(15,28)`; from the west-wall carry landing `(1,54)`, south-road guidance
moved RIGHT before descending and completed at `(2,64)` without retrying the
blocked `(1,63)->DOWN` edge. Runtime blocks remained empty. The next route
task is to define and validate the Hauksness return route from its own start.
Combat dialogue repeatedly emitted overlapping windows near y=88, while
fights at `(20,93)` and `(15,92)` behaved normally; detailed evidence remains
in `work_notes/current_investigation.md` for the later dialogue-tuning pass.
```

Keep the existing warning about the two final Hauksness executor/timing edges and the deferred combat-dialogue tuning evidence.

- [ ] **Step 2: Update the player-facing Hauksness route note**

Replace the stale reload sentence at the end of the Hauksness entry in `PLAYTESTING.md` with:

```markdown
The Western desert south-shelf and south-road approach-order fixes are live-
verified: guidance corrects LEFT before descending from `(16,27)` and RIGHT
before descending from the `(1,54)` carry landing. The full Hauksness return
route is deferred until it can be defined and validated from its own start.
```

- [ ] **Step 3: Verify the documentation-only diff**

Run:

```powershell
git diff --check -- session_handoff.md PLAYTESTING.md
git diff -- session_handoff.md PLAYTESTING.md
git status --short
```

Expected: the two docs report the verified coordinates and deferred return-route scope; no unverified claim is added; `work_notes/current_investigation.md` remains unstaged.

- [ ] **Step 4: Commit the verified status update**

Run:

```powershell
git add session_handoff.md PLAYTESTING.md
git commit -m "docs: record Hauksness desert route validation"
```

Expected: the commit contains exactly `session_handoff.md` and `PLAYTESTING.md`.
