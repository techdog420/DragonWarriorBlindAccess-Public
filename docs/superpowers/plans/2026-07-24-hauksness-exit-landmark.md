# Hauksness Exit Landmark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a safe Hauksness exit navigation target at `(0,10)` and use it
to begin a live, evidence-driven return-route decode from the Axe Knight area.

**Architecture:** Add one map-scoped record to the existing `EXITS` table so
the normal Travel object and interaction-goal machinery remains authoritative.
Focused object tests lock down its identity, filter membership, stopping tile,
and west-facing arrival. Live FCEUX blocker-hunt then targets the exit
coordinate without automatically applying or permanently promoting suspected
blockers.

**Tech Stack:** Lua, the repository's table-driven Lua test harness,
`objects.lua`, PowerShell command queue tooling, and FCEUX 2.6.6.

## Global Constraints

- Player-facing name is exactly `Exit to World Map`.
- Stable object ID is exactly `exit_0_10`.
- The exit subject and safe autowalk destination are both Hauksness map `0x03`
  cell `(0,10)`.
- Selected-object navigation finishes facing west and releases movement on
  map `0x03`.
- Leaving Hauksness requires one deliberate manual west step.
- The exit appears under `All` and `Travel`, never `NPCs`, `Services`,
  `Treasure`, or `Doors`.
- Do not add Hauksness-specific logic to `route_manager.lua` or
  `auto_step.lua`.
- Do not change generic exit behavior or automatically issue the transition
  step.
- Treat combat, dialogue, menus, NPC interference, and movement timing as
  distinct from permanent map geometry.
- Add a runtime blocked edge only after reviewing a same-origin probe from a
  normally reached origin.
- Do not promote the existing runtime-only Hauksness blocker list
  speculatively.
- Preserve the user's live FCEUX state; changing `objects.lua` requires a
  manual Lua script reload.

---

### Task 1: Add the Hauksness Exit with Focused Regression Coverage

**Files:**
- Modify: `test_objects.lua:1289`
- Modify: `objects.lua:288`

**Interfaces:**
- Consumes: `EXITS`, `get_exits(map_id)`, `M.TYPE_EXIT`,
  `M.find_object_by_id(id, opts)`, `M.set_filter(filter)`, and the existing
  generic interaction fields `interaction_x`, `interaction_y`,
  `interaction_face_dir`, and `interaction_label`
- Produces: Travel object `exit_0_10` named `Exit to World Map`, with subject
  and interaction coordinate `(0,10)`, west-facing arrival, and `exit`
  interaction label

- [ ] **Step 1: Write the failing object and filter regression**

Insert this test immediately before
`tests.rimuldar_exits_use_live_transition_tiles` in `test_objects.lua`:

```lua
function tests.hauksness_exit_uses_live_west_entry_tile_and_manual_transition()
    local env = make_env({npc_count = 20})

    env.set_position(0x03, 17, 12)
    env.set_terrain_offset(0x10)
    env.objects.refresh(0x03)

    local id = "exit_0_10"
    local exit = env.objects.find_object_by_id(id)
    assert_equal(exit ~= nil, true, "Hauksness should expose its live west-edge exit")
    assert_equal(exit.name, "Exit to World Map", "Hauksness should use the normal world-map exit label")
    assert_equal(exit.type, env.objects.TYPE_EXIT, "Hauksness exit should use the Travel-compatible type")
    assert_equal(exit.x, 0, "Hauksness exit should use the live west boundary X")
    assert_equal(exit.y, 10, "Hauksness exit should use the live entry row")
    assert_equal(exit.interaction_x, 0, "Hauksness exit route should stop on the boundary tile")
    assert_equal(exit.interaction_y, 10, "Hauksness exit stand should match the live entry row")
    assert_equal(exit.interaction_face_dir, "west", "Hauksness exit stand should face the world transition")
    assert_equal(exit.interaction_label, "exit", "Hauksness exit should use the generic interaction label")

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
            "Hauksness exit filter membership should match the approved design"
        )
    end

    env.restore()
end
```

- [ ] **Step 2: Run the focused test file and verify the red failure**

Run:

```powershell
wsl.exe --cd /mnt/d/modding/DragonWarrior1 lua test_objects.lua
```

Expected: exit code `1`; the new test fails at
`Hauksness should expose its live west-edge exit` because `exit_0_10` does not
exist.

- [ ] **Step 3: Add the minimal exit-table record**

Insert this entry at the start of the town section in `EXITS`:

```lua
    {
        map = 0x03,
        x = 0,
        y = 10,
        name = "Exit",
        dest = "World Map",
        interaction_x = 0,
        interaction_y = 10,
        interaction_face_dir = "west",
        interaction_label = "exit",
    },                                                                      -- Hauksness
```

Do not set `object_name`; `get_exits()` must continue deriving the normal
`Exit to World Map` label. Do not modify filters, route-manager code, or
autowalk code.

- [ ] **Step 4: Re-run focused tests and syntax verification**

Run:

```powershell
wsl.exe --cd /mnt/d/modding/DragonWarrior1 lua test_objects.lua
wsl.exe --cd /mnt/d/modding/DragonWarrior1 lua test_route_manager.lua
wsl.exe --cd /mnt/d/modding/DragonWarrior1 luac -p objects.lua test_objects.lua
```

Expected:

- `test_objects.lua` exits `0` with one more test than its pre-change total;
- `test_route_manager.lua` exits `0` with its existing generic
  interaction-route coverage intact;
- `luac` exits `0` with no output.

- [ ] **Step 5: Run the full repository gate**

Run:

```powershell
wsl.exe --cd /mnt/d/modding/DragonWarrior1 python3 run_tests.py --allow-missing-speech-dep
git diff --check
```

Expected: every repository check reports `PASS`, the test runner exits `0`,
and `git diff --check` produces no output. The allowed
`accessible_output2` warning may remain.

- [ ] **Step 6: Commit the source and regression**

Run:

```powershell
git add objects.lua test_objects.lua
git diff --cached --check
git diff --cached --stat
git commit -m "Add Hauksness exit landmark"
```

Expected: the commit contains one `EXITS` record and one focused object test.
It contains no map blocker, route-manager, autowalk, dialogue, or unrelated
documentation change.

---

### Task 2: Verify the Exit and Begin the Live Return-Route Decode

**Files:**
- Modify after verified evidence: `work_notes/current_investigation.md`
- Runtime evidence: `dw_debug.log`

**Interfaces:**
- Consumes: committed object `exit_0_10`, `auto_walk_blocker:0,10`,
  `probe_edge:DIR`, `add_blocked_edge:X,Y,DIR`, `report_position`,
  `report_path_state`, and the user's manual Lua reload and combat handling
- Produces: live proof that the landmark is browsable and safe, plus reviewed
  runtime-only return-route evidence toward `(0,10)`

- [ ] **Step 1: Ask the user to reload the Lua script**

State that `objects.lua` changed and FCEUX requires a manual script restart.
Do not queue live movement until the user confirms the reload.

- [ ] **Step 2: Establish a fresh Hauksness baseline**

Run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait-ready HAUKSNESS_EXIT "launcher_probe:HAUKSNESS_EXIT"
```

Expected: a fresh ready marker on map `0x03`, command polling active, field
state clear, and no stale active path. If combat, dialogue, or a menu is
active, pause for the user rather than queueing movement.

- [ ] **Step 3: Verify the player-facing exit object**

Run:

```powershell
.\dw_commands.ps1 --replace current_object
```

Use separate `next_filter` calls, each followed by `current_object`, until the
announced filter is `Travel`. Then use separate `next_object` calls followed
by `current_object` until the selected object is `Exit to World Map`.

Expected: the selected object reports ID `exit_0_10`, target `(0,10)`,
interaction `(0,10)`, and west-facing exit behavior. Do not assume filter or
selection state survived the reload.

- [ ] **Step 4: Start blocker-hunt navigation toward the exit**

Run:

```powershell
.\dw_commands.ps1 --replace auto_walk_blocker:0,10
```

Expected: the route either advances toward `(0,10)`, reaches the exit, pauses
for a field interruption, or logs one `AUTO_WALK_BLOCKER_FOUND` record with
an exact origin, destination, direction, and suggested
`add_blocked_edge:X,Y,DIR`.

- [ ] **Step 5: Resolve each interruption with the smallest evidence cycle**

For combat, stop and let the user clear the field. Then run:

```powershell
.\dw_commands.ps1 --replace report_position report_path_state
```

For a movement failure, first confirm that the player remains at the logged
origin. Then run exactly one same-origin raw probe using the reported
direction:

```powershell
.\dw_commands.ps1 --replace probe_edge:DIR
```

Interpret the fresh log:

- If the probe moves, do not add a blocker; report the new coordinate and
  resume from fresh state.
- If the probe stays at the normally reached origin with no combat, menu,
  dialogue, NPC, or input contamination, queue the exact
  `add_blocked_edge:X,Y,DIR` suggestion logged by blocker-hunt, then resume
  `auto_walk_blocker:0,10`.
- If the result is ambiguous, record it as uncertain and do not alter the
  runtime or permanent map model.

Repeat for at least three focused route/evidence cycles unless the route
reaches `(0,10)`, the user pauses the session, or live state becomes unsafe
or contaminated.

- [ ] **Step 6: Verify safe arrival before taking the transition**

When navigation reports completion, run:

```powershell
.\dw_commands.ps1 --replace report_position report_path_state current_object
```

Expected: map `0x03`, player `(0,10)`, no active path, selected
`Exit to World Map`, and west-facing completion evidence. The player must
still be inside Hauksness.

Only after that evidence is captured, ask the user to press west manually.
Then fresh-probe:

```powershell
.\dw_commands.ps1 --replace report_position
```

Expected: world map `0x01` at `(25,89)`.

- [ ] **Step 7: Record only verified live results**

Append this bullet under the current Hauksness investigation after complete
arrival proof:

```markdown
- EXIT LANDMARK LIVE VERIFIED: after a manual FCEUX script reload,
  `Exit to World Map` appeared under Travel. Blocker-hunt navigation stopped
  on Hauksness `(0,10)`, released movement, and faced west without crossing
  the transition. One manual west step returned to World Map `(25,89)`.
```

If the session stops before arrival, instead record the exact last confirmed
coordinate, reviewed runtime edges, uncertain edges, field state, and next
command. Do not claim exit acceptance.

- [ ] **Step 8: Commit the live evidence if shared project state changed**

Run:

```powershell
git add work_notes/current_investigation.md
git diff --cached --check
git commit -m "Record live Hauksness exit validation"
```

Expected: a documentation-only commit containing the verified live result or
a durable resumable checkpoint. Runtime-only edges remain out of
`map_reader.lua` until a separate focused source-and-regression batch is
approved by the collected evidence.

## Failure Handling

- If the new object test does not fail before implementation, inspect the
  Hauksness object list and stop rather than adding a duplicate exit.
- If the exit appears under an unrelated filter, fix only its table data or
  the focused test expectation; do not redesign filter semantics.
- If generic interaction routing attempts a west step after reaching
  `(0,10)`, retain the log and stop live movement. Do not add a Hauksness
  routing exception without revisiting the approved design.
- If FCEUX does not consume the launcher probe after manual reload, relaunch
  through `./launch_dw.sh` instead of queueing more state-sensitive commands.
- If the player is no longer on map `0x03`, ask the user to restore the
  Hauksness state before continuing.
- If a random encounter begins, pause for the user. Never interpret the
  interruption as blocker evidence.
- If a same-origin probe crosses an edge that blocker-hunt rejected, classify
  the rejection as timing/state evidence and leave permanent map data
  unchanged.
- If a same-origin probe is blocked but the origin was reached by teleport or
  forced relocation, retain it as forensic evidence only and reacquire the
  origin through normal movement before promotion.
