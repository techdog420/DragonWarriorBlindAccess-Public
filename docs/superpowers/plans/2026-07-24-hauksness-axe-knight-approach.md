# Hauksness Axe Knight Approach Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent `Axe Knight Approach` Travel landmark that routes to Hauksness `(17,12)`, faces east, and stops without exposing the buried armor or issuing SEARCH.

**Architecture:** Add one map-scoped entry to a dedicated static-landmark table in `objects.lua`, represented with the existing Travel-compatible `TYPE_EXIT` and generic interaction-point fields. Existing route-manager behavior already routes any interaction object to `interaction_x, interaction_y` and applies `interaction_face_dir`, so production route logic does not change; focused object and route-manager regressions lock down that contract.

**Tech Stack:** Lua, the repository's table-driven test harness, `objects.lua`, `route_manager.lua`, PowerShell command queue tooling, and FCEUX 2.6.6.

## Global Constraints

- Player-facing name is exactly `Axe Knight Approach`.
- Stable object ID is exactly `landmark_hauksness_axe_knight`.
- The internal subject coordinate is Hauksness map `0x03` cell `(18,12)`.
- The safe autowalk destination is `(17,12)`, facing east.
- Autowalk releases movement at `(17,12)` and never takes the final east step.
- Entering the encounter requires one deliberate manual east step.
- The landmark appears under `All` and `Travel`, never `NPCs`, `Services`, `Treasure`, or `Doors`.
- Do not add a new object type or filter.
- Do not represent the Axe Knight as NPC RAM.
- Do not add the buried armor as an object or treasure target.
- Ordinary object browsing, descriptions, route guidance, and completion speech must not name the armor, suggest SEARCH, or automatically issue SEARCH.
- Keep the landmark available after the battle and after the armor has been collected.
- Preserve the already-live-verified Hauksness NPC-suppression changes currently unstaged in `objects.lua` and `test_objects.lua`.
- Preserve the user's live FCEUX state; source edits require a manual Lua script reload.

---

### Task 1: Preserve the Existing Hauksness NPC-Suppression Prerequisite

**Files:**
- Modify: none; this task commits the already-verified changes in `objects.lua` and `test_objects.lua`
- Test: `test_objects.lua`

**Interfaces:**
- Consumes: existing `MAPS_WITHOUT_NPCS[0x03]` guard and `tests.hauksness_never_exposes_stale_town_npc_ram`
- Produces: a clean source/test baseline on which the landmark hunks can be reviewed and committed independently

- [ ] **Step 1: Confirm that only the known prerequisite hunks are present**

Run:

```powershell
git diff -- objects.lua test_objects.lua
```

Expected: `objects.lua` contains the map `0x03` NPC-suppression guard and its three call-site updates; `test_objects.lua` contains only the matching stale-NPC regression.

- [ ] **Step 2: Re-run the prerequisite regression suite**

Run:

```powershell
wsl.exe --cd /mnt/d/modding/DragonWarrior1 lua test_objects.lua
```

Expected: exit code `0` and final line `Ran 100 Lua unit tests`.

- [ ] **Step 3: Commit only the prerequisite source and test**

Run:

```powershell
git add objects.lua test_objects.lua
git diff --cached --check
git diff --cached --stat
git commit -m "Fix stale NPC data in Hauksness"
```

Expected: the commit contains only `objects.lua` and `test_objects.lua`. Leave `project_resources/maps/hauksness/README.md` and `work_notes/current_investigation.md` unstaged for Task 3.

---

### Task 2: Add the Safe Encounter Landmark with Focused Regressions

**Files:**
- Modify: `objects.lua:1316-1323`
- Modify: `objects.lua:1763-1784`
- Test: `test_objects.lua:383`
- Test: `test_route_manager.lua:1559`

**Interfaces:**
- Consumes: `M.TYPE_EXIT`, `M.FILTER_*`, `M.describe_object(obj)`, `get_static_objects(map_id)`, and generic interaction fields `interaction_x`, `interaction_y`, `interaction_face_dir`, `interaction_label`
- Produces: static object `landmark_hauksness_axe_knight` with subject `(18,12)`, interaction `(17,12)`, east facing, and `safe approach` label

- [ ] **Step 1: Write the missing-object regression**

Insert this test after `tests.hauksness_never_exposes_stale_town_npc_ram` in `test_objects.lua`:

```lua
function tests.hauksness_exposes_safe_axe_knight_travel_landmark_without_treasure_hint()
    local env = make_env({npc_count = 20})

    env.set_position(0x03, 17, 12)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x03)

    local id = "landmark_hauksness_axe_knight"
    local landmark = env.objects.find_object_by_id(id)
    assert_equal(landmark ~= nil, true, "Hauksness should expose the fixed Axe Knight approach")
    assert_equal(landmark.name, "Axe Knight Approach", "encounter landmark should use the approved player-facing name")
    assert_equal(landmark.type, env.objects.TYPE_EXIT, "encounter landmark should reuse the Travel-compatible type")
    assert_equal(landmark.x, 18, "encounter landmark should retain the fixed battle X")
    assert_equal(landmark.y, 12, "encounter landmark should retain the fixed battle Y")
    assert_equal(landmark.interaction_x, 17, "encounter landmark should route to the safe west stand X")
    assert_equal(landmark.interaction_y, 12, "encounter landmark should route to the safe west stand Y")
    assert_equal(landmark.interaction_face_dir, "east", "safe stand should face east toward the encounter")
    assert_equal(landmark.interaction_label, "safe approach", "object speech should identify the preparation point")
    assert_equal(
        env.objects.describe_object(landmark),
        "Axe Knight Approach: 1 east, safe approach here",
        "object speech should identify the encounter and safe stand without naming the reward"
    )

    local expected_by_filter = {
        [env.objects.FILTER_ALL] = true,
        [env.objects.FILTER_NPC] = false,
        [env.objects.FILTER_SERVICE] = false,
        [env.objects.FILTER_TREASURE] = false,
        [env.objects.FILTER_TRAVEL] = true,
        [env.objects.FILTER_DOOR] = false,
    }
    for filter, expected in pairs(expected_by_filter) do
        env.objects.set_filter(filter)
        assert_equal(
            env.objects.find_object_by_id(id, {filtered = true}) ~= nil,
            expected,
            "Axe Knight approach filter membership should match the approved design"
        )
    end

    env.objects.set_filter(env.objects.FILTER_TREASURE)
    assert_equal(env.objects.get_count(), 0, "Hauksness should not expose the buried armor under Treasure")

    local exposed = (landmark.name .. " " .. env.objects.describe_object(landmark)):lower()
    assert_equal(exposed:find("armor", 1, true), nil, "landmark speech should not name the armor")
    assert_equal(exposed:find("erdrick", 1, true), nil, "landmark speech should not name the reward")
    assert_equal(exposed:find("search", 1, true), nil, "landmark speech should not suggest SEARCH")

    env.restore()
end
```

- [ ] **Step 2: Add the generic interaction-route characterization**

Insert this test after `tests.service_interaction_goal_routes_to_counter_tile_and_faces_service` in `test_route_manager.lua`:

```lua
function tests.hauksness_axe_knight_landmark_stops_at_safe_approach_and_faces_east()
    local landmark = {
        id = "landmark_hauksness_axe_knight",
        name = "Axe Knight Approach",
        type = "exit",
        x = 18,
        y = 12,
        interaction_x = 17,
        interaction_y = 12,
        interaction_face_dir = "east",
        interaction_label = "safe approach",
    }
    local env = make_env({
        start_map_id = 0x03,
        start_x = 15,
        start_y = 12,
        map_width = 20,
        map_height = 20,
        current_object = landmark,
        object_list = {landmark},
        config_values = {
            auto_walk_face_target_frames = "1",
        },
        pathfind_to_fn = function(start_x, start_y, goal_x, goal_y)
            if goal_x == 17 and goal_y == 12 then
                return "Path: 2 east", "east",
                    make_path_from_dirs(start_x, start_y, {"east", "east"})
            end
            return "No path found", nil, nil
        end,
    })

    local plan = env.route_manager.plan_path_to_object(landmark)
    local direct = env.last_direct_call()
    assert_equal(plan.interaction_goal, true, "Axe Knight route should use the safe interaction stand")
    assert_equal(plan.goal_x, 17, "Axe Knight route should stop west of the encounter")
    assert_equal(plan.goal_y, 12, "Axe Knight route should stay on the encounter row")
    assert_equal(plan.face_dir, "east", "Axe Knight route should finish facing the encounter")
    assert_equal(direct.goal_x, 17, "pathfinder should target the safe stand X")
    assert_equal(direct.goal_y, 12, "pathfinder should target the safe stand Y")
    for _, step in ipairs(plan.path) do
        assert_equal(
            step.x == 18 and step.y == 12,
            false,
            "planned movement must not include the combat trigger tile"
        )
    end

    local queued = env.route_manager.autowalk_to_current()
    local steps = env.last_start_route_steps()
    assert_equal(queued.status, "queued", "Axe Knight approach should queue a normal route")
    assert_equal(#steps, 2, "Axe Knight approach should queue only the two safe east steps")
    assert_equal(steps[1], "right", "first queued step should move toward the safe stand")
    assert_equal(steps[2], "right", "final queued step should land on the safe stand")

    env.auto_step.on_route_complete()
    env.route_manager.apply_npc_freeze()
    assert_equal(
        env.joypad_sets[#env.joypad_sets].buttons.right,
        true,
        "arrival should face east without taking another movement step"
    )

    env.restore()
end
```

- [ ] **Step 3: Run both focused files and confirm the red/characterization split**

Run:

```powershell
wsl.exe --cd /mnt/d/modding/DragonWarrior1 lua test_objects.lua
```

Expected: exit code `1`; the new Hauksness landmark test fails because `landmark_hauksness_axe_knight` does not exist.

Run:

```powershell
wsl.exe --cd /mnt/d/modding/DragonWarrior1 lua test_route_manager.lua
```

Expected: exit code `0` and final line `Ran 112 Lua unit tests`. This passing characterization proves no route-manager production change is required.

- [ ] **Step 4: Add the minimal static-landmark data source**

Add this table immediately after `EXTRA_TREASURES` in `objects.lua`:

```lua
-- Static local-map landmarks that belong under Travel but are not exits,
-- stairs, NPCs, or treasure objects.
local EXTRA_LANDMARKS = {
    -- Hauksness fixed encounter. Route to the safe west stand and leave the
    -- final east step under player control. The buried reward intentionally
    -- remains absent from player-facing object data.
    [0x03] = {
        {
            x = 18,
            y = 12,
            name = "Axe Knight Approach",
            type = M.TYPE_EXIT,
            id = "landmark_hauksness_axe_knight",
            interaction_x = 17,
            interaction_y = 12,
            interaction_face_dir = "east",
            interaction_label = "safe approach",
        },
    },
}
```

Append the new source in `get_static_objects(map_id)` immediately after the `EXTRA_TREASURES` append:

```lua
    extra = EXTRA_LANDMARKS[map_id]
    if extra then
        append_objects(objects, extra)
    end
```

Do not modify filter constants, `matches_type_filter`, `route_manager.lua`, or autowalk execution.

- [ ] **Step 5: Re-run the focused suites and syntax check**

Run:

```powershell
wsl.exe --cd /mnt/d/modding/DragonWarrior1 lua test_objects.lua
```

Expected: exit code `0` and final line `Ran 101 Lua unit tests`.

Run:

```powershell
wsl.exe --cd /mnt/d/modding/DragonWarrior1 lua test_route_manager.lua
```

Expected: exit code `0` and final line `Ran 112 Lua unit tests`.

Run:

```powershell
wsl.exe --cd /mnt/d/modding/DragonWarrior1 luac -p objects.lua test_objects.lua test_route_manager.lua
```

Expected: exit code `0` and no output.

- [ ] **Step 6: Commit the source and focused regressions**

Run:

```powershell
git add objects.lua test_objects.lua test_route_manager.lua
git diff --cached --check
git diff --cached --stat
git commit -m "Add safe Hauksness Axe Knight approach"
```

Expected: the commit contains one static landmark, one object/filter/speech regression, and one generic route-arrival regression. It contains no map blocker, NPC, treasure, SEARCH, or route-manager production change.

---

### Task 3: Align Hauksness Developer Notes with the Approved Spoiler Boundary

**Files:**
- Modify: `project_resources/maps/hauksness/README.md:118-140`
- Modify: `work_notes/current_investigation.md:61-68`
- Test: documentation wording scan plus full repository verification

**Interfaces:**
- Consumes: approved design spec `docs/superpowers/specs/2026-07-24-hauksness-axe-knight-approach-design.md`
- Produces: current map guidance that calls for an encounter landmark while explicitly rejecting a player-facing armor/search object

- [ ] **Step 1: Replace the stale map priority and accessibility guidance**

Replace `First Decode Priorities` items 2-4 with:

```markdown
2. Expose `Axe Knight Approach` under Travel, using `(18,12)` only as the
   internal subject and routing to the safe preparation tile `(17,12)` facing
   east.
3. Keep the buried armor entirely out of player-facing object browsing,
   Treasure filtering, route speech, and SEARCH guidance.
4. Ensure autowalk does not convert the scripted `(17,12)->RIGHT` encounter
   transition into a permanent blocker, then validate the source-only route
   from `(0,10)` to the safe approach and back out.
```

Replace the `Accessibility And Spoiler Note` body with:

```markdown
The fixed Axe Knight is useful as a nonvisual maze landmark even though the
game draws no enemy sprite on the tile. Expose only the persistent
`Axe Knight Approach` Travel landmark and stop at `(17,12)` facing east. The
buried armor remains an intentional secret: do not add its tile under
Treasure, name the reward, suggest SEARCH, or automate the final encounter
step.
```

- [ ] **Step 2: Correct the active investigation note**

Replace the final sentence of `ARMOR EVENT LIVE VERIFIED` with:

```markdown
  The generic object list still reports no object on the tile. The approved
  follow-up is a persistent `Axe Knight Approach` Travel landmark that stops at
  `(17,12)` facing east; keep the buried armor and SEARCH action out of
  player-facing object data.
```

- [ ] **Step 3: Prove the obsolete player-facing search-object recommendation is gone**

Run:

```powershell
rg -n "search/navigation object|Guarded Tree Behind Ruined Shop|optional later disclosure" project_resources/maps/hauksness/README.md work_notes/current_investigation.md
```

Expected: exit code `1` with no matches.

- [ ] **Step 4: Run full automated verification**

Run:

```powershell
wsl.exe --cd /mnt/d/modding/DragonWarrior1 python3 run_tests.py --allow-missing-speech-dep
```

Expected: every repository check reports `PASS` and the process exits `0`.

Run:

```powershell
git diff --check
```

Expected: exit code `0` and no output.

- [ ] **Step 5: Commit the developer-note correction**

Run:

```powershell
git add project_resources/maps/hauksness/README.md work_notes/current_investigation.md
git diff --cached --check
git commit -m "Document Hauksness encounter landmark boundary"
```

Expected: the commit preserves the internal live evidence while removing the stale recommendation to expose a search/treasure target.

---

### Task 4: Perform Focused Live FCEUX Acceptance

**Files:**
- Modify after successful verification: `work_notes/current_investigation.md`
- Runtime evidence: `dw_debug.log`

**Interfaces:**
- Consumes: committed `landmark_hauksness_axe_knight`, current FCEUX Hauksness state, `dw_commands.ps1`, and the user's manual Lua reload
- Produces: fresh evidence that browsing is spoiler-safe and selected-object autowalk stops at `(17,12)` facing east

- [ ] **Step 1: Ask the user to reload the Lua script**

State clearly that `objects.lua` changed and FCEUX requires a manual script restart. Do not queue live commands until the user confirms the reload.

- [ ] **Step 2: Establish a fresh Hauksness probe**

Run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait-ready HAUKSNESS_AXE_LANDMARK "launcher_probe:HAUKSNESS_AXE_LANDMARK"
```

Expected: a fresh ready marker on map `0x03`, field state clear, and command polling active. If the player is not in Hauksness, ask the user to restore or enter the map before continuing.

- [ ] **Step 3: Select the landmark under Travel and capture its speech**

Run:

```powershell
.\dw_commands.ps1 --replace next_filter current_object
```

Repeat that short batch until the announced filter is `Travel`. If another
Travel object is selected, run:

```powershell
.\dw_commands.ps1 --replace next_object current_object
```

Repeat only until `current_object` reports `Axe Knight Approach`. This avoids
assuming that the object filter or selection reset to a particular value
during Lua reload. The fresh log segment must not announce armor, Erdrick,
treasure, or SEARCH.

- [ ] **Step 4: Route from a nearby safe cell**

If the post-search save still places the player at `(18,12)`, run:

```powershell
.\dw_commands.ps1 --replace auto_walk
```

Otherwise, have the user move to any confirmed nearby safe cell west of the encounter and then run the same command.

Expected: autowalk finishes at `(17,12)`, releases movement, faces east, and does not start combat.

- [ ] **Step 5: Confirm final state without re-searching**

Run:

```powershell
.\dw_commands.ps1 --replace report_position report_path_state current_object
```

Expected: map `0x03`, player `(17,12)`, no active path, selected `Axe Knight Approach`, and east-facing arrival evidence in the fresh log segment.

Do not issue SEARCH. The earlier same-origin live proof already established that one manual east step enters `(18,12)` and starts the fixed battle before the reward is collected. If a pre-fight save is intentionally restored, one manual east step may be used to reconfirm the encounter; otherwise the cleared encounter state is not a feature failure.

- [ ] **Step 6: Record successful live acceptance**

Append this bullet under the current Hauksness investigation only after the stated evidence is present:

```markdown
- AXE KNIGHT LANDMARK LIVE VERIFIED: after a manual FCEUX script reload,
  `Axe Knight Approach` appeared under Travel without armor or SEARCH speech.
  Selected-object autowalk stopped at `(17,12)`, released movement, and faced
  east without entering the fixed encounter tile `(18,12)`.
```

- [ ] **Step 7: Commit the live evidence**

Run:

```powershell
git add work_notes/current_investigation.md
git diff --cached --check
git commit -m "Record live Axe Knight landmark validation"
```

Expected: one documentation-only commit containing the fresh acceptance result.

## Failure Handling

- If the new object test does not fail before implementation, inspect the full object list for an accidentally pre-existing Hauksness landmark and stop rather than adding a duplicate.
- If the route characterization fails, fix the test setup first unless current generic interaction behavior demonstrably violates the approved design; do not add Hauksness-specific route-manager logic.
- If `test_objects.lua` reports failures unrelated to the landmark after Task 1, preserve the verified NPC-suppression baseline and investigate the exact failing test before proceeding.
- If FCEUX does not consume the launcher probe after manual reload, relaunch through `./launch_dw.sh` rather than queueing more state-sensitive commands.
- If combat, a menu, dialogue, or live input interrupts autowalk, pause for the user, clear the field, fresh-probe position, and rerun only the smallest remaining acceptance step.
- If autowalk attempts `(17,12)->RIGHT`, stop immediately and retain the log evidence; do not convert `(18,12).west` into permanent blocked map data.
- If the fresh object speech contains armor or SEARCH guidance, fail acceptance and remove the disclosure before any live retry.
