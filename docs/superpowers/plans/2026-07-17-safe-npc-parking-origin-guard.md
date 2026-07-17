# Safe NPC Parking Origin Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent auto-walk NPC parking from occupying a real `(0,0)` route cell while preserving existing parking on maps whose origin is not walkable.

**Architecture:** `route_manager.lua` will make one map-safety decision before starting proactive parking. If `map_reader.is_walkable(map_id, 0, 0)` is true, the route will log the refusal, retain `live_npcs` planning, and use the existing in-place freeze behavior; otherwise the current parking path remains unchanged.

**Tech Stack:** Lua 5.1-compatible source, local Lua test harness, FCEUX command queue, `dw_debug.log`.

## Global Constraints

- Do not choose another synthetic NPC coordinate.
- Do not change NPC entry layout, high bits, movement bytes, adjacent RAM, or ROM code.
- Preserve current parking behavior when `(0,0)` is not pathfinder-walkable.
- Preserve live-NPC planning, blocking, rerouting, freezing, and cleanup behavior as the fallback.
- Keep `auto_walk_park_mobile_npcs` disabled by default in `config.lua`.
- Write and run the regression before changing production code.
- FCEUX requires a manual Lua reload after the source change.

---

### Task 1: Guard proactive auto-walk parking

**Files:**
- Modify: `test_route_manager.lua:439-444,3075-3141`
- Modify: `route_manager.lua:488-497,4023-4034`

**Interfaces:**
- Consumes: `map_reader.is_walkable(map_id, x, y) -> boolean`.
- Produces: `autowalk_npc_parking_safe(map_id) -> boolean, reason_or_nil`.
- Produces log: `AUTO_WALK_NPC_PARK_SKIP map=0xNN reason=walkable_origin origin=(0,0)`.

- [ ] **Step 1: Add the failing route-manager regression and explicit harness origin state.**

In the `map_reader.is_walkable` test stub, make the synthetic map origin blocked
unless a test explicitly opts into a walkable origin:

```lua
is_walkable = function(_, x, y)
    if x == 0 and y == 0 then
        return options.walkable_origin == true
    end
    if non_walkable_cells[x .. "," .. y] then
        return false
    end
    return true
end,
```

Add this test beside the existing mobile-parking tests:

```lua
function tests.autowalk_skips_mobile_parking_when_map_origin_is_walkable()
    local env = make_env({
        start_map_id = 0x0B,
        walkable_origin = true,
        config_values = {
            auto_walk_park_mobile_npcs = "true",
            auto_walk_npc_hold_frames = "0",
        },
        memory_values = {
            [0] = 0x80 + 4,
            [1] = 0x60 + 4,
            [2] = 0x12,
        },
    })

    local plan = env.route_manager.autowalk_to_current()
    local logs = table.concat(env.debug_infos(), "\n")

    assert_equal(plan.status, "queued", "walkable-origin route should still queue")
    assert_equal(plan.npc_mode, "live_npcs", "walkable-origin route should use live NPC blocking")
    assert_equal(
        env.route_manager.get_active_route_npc_mode(),
        "live_npcs",
        "queued route should retain the safe live-NPC mode"
    )
    assert_equal(
        env.route_manager.is_autowalk_npc_parking_active(),
        false,
        "walkable-origin route must not activate coordinate parking"
    )
    assert_equal(#env.memory_writes, 0, "walkable-origin refusal must not write NPC RAM")
    assert_contains(
        logs,
        "AUTO_WALK_NPC_PARK_SKIP map=0x0B reason=walkable_origin origin=(0,0)",
        "parking refusal should name the collision reason"
    )

    env.restore()
end
```

- [ ] **Step 2: Run the focused regression and verify RED.**

Run:

```powershell
lua test_route_manager.lua
```

Expected: exit `1`; the new test reports NPC parking active, RAM writes present,
or `npc_mode=park_mobile_npcs` because the safety guard does not exist yet.

- [ ] **Step 3: Implement the minimal map-origin safety predicate.**

Add beside `should_park_mobile_npcs_for_autowalk`:

```lua
local function autowalk_npc_parking_safe(map_id)
    if map_reader.is_walkable
       and map_reader.is_walkable(map_id, 0, 0) == true then
        return false, "walkable_origin"
    end
    return true, nil
end
```

Replace the proactive parking selection in `autowalk_to_object` with:

```lua
local npc_mode = route_npc_mode_from_opts(opts)
local parked_slots = nil
local park_mobile_npcs = should_park_mobile_npcs_for_autowalk(opts)
if park_mobile_npcs then
    local parking_safe, parking_skip_reason = autowalk_npc_parking_safe(map_id)
    if not parking_safe then
        park_mobile_npcs = false
        npc_mode = "live_npcs"
        debug_tools.info(string.format(
            "AUTO_WALK_NPC_PARK_SKIP map=0x%02X reason=%s origin=(0,0)",
            map_id or 0,
            tostring(parking_skip_reason or "unsafe_origin")))
    end
end
if park_mobile_npcs then
    parked_slots = start_autowalk_npc_parking(obj, opts)
    npc_mode = "park_mobile_npcs"
elseif should_freeze_npcs_for_autowalk(opts) then
    freeze_npcs_for_pathing()
else
    debug_tools.debug("AUTO_WALK: NPC freeze skipped for this route")
end
opts = route_planning_opts(opts, npc_mode, "autowalk_initial")
opts.planning_parked_slots = parked_slots
```

- [ ] **Step 4: Run the focused regression and verify GREEN.**

Run:

```powershell
lua test_route_manager.lua
```

Expected: the new regression passes with no NPC RAM writes and the exact skip
log.

- [ ] **Step 5: Run the complete focused suite and static checks.**

Run:

```powershell
lua test_route_manager.lua
luac -p route_manager.lua test_route_manager.lua
git diff --check
```

Expected: all route-manager tests pass, both files parse, and the diff check
exits `0`. Existing mobile-parking tests must still prove that a blocked origin
retains the current parking behavior.

---

### Task 2: Verify the guard in live Rimuldar play

**Files:**
- Modify: `dw_access.ini:113` only to restore the user's pre-diagnostic `auto_walk_park_mobile_npcs=true` setting.
- Review: `dw_debug.log`.
- Conditionally modify after evidence only: `auto_step.lua`, `test_auto_step.lua`.

**Interfaces:**
- Consumes command queue: `reload_config`, `report_position`, `report_path_state`, `report_runtime_blocks`, `trace_input`, `auto_walk`.
- Produces live acceptance evidence for the isolated entry and complete 52-step merchant route.

- [ ] **Step 1: Restore parking configuration and reload configuration.**

Change only:

```ini
auto_walk_park_mobile_npcs=true
```

Run:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc './dw_commands.sh --replace reload_config'
```

Expected: `Config reloaded from dw_access.ini`. This deliberately requests
parking so the source guard, not the temporary configuration bypass, is tested.

- [ ] **Step 2: Ask the user to reload `main.lua`, then verify the fresh script.**

Run after the user confirms reload:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc './dw_commands.sh --replace --timeout 20 --wait-ready RIMULDAR_PARK_GUARD report_position report_path_state report_runtime_blocks'
```

Expected: a fresh launcher marker, no active route, and no runtime blocks.

- [ ] **Step 3: Re-enter Rimuldar normally if the player remains on the World Map.**

From World Map `(102,72)`, use normal debug-injected movement in separate
batches and verify after each step:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc './dw_commands.sh --replace simulate_input:RIGHT'
& 'C:\Program Files\Git\bin\bash.exe' -lc './dw_commands.sh --replace --timeout 15 --wait "POSITION:" report_position'
& 'C:\Program Files\Git\bin\bash.exe' -lc './dw_commands.sh --replace simulate_input:LEFT'
& 'C:\Program Files\Git\bin\bash.exe' -lc './dw_commands.sh --replace --timeout 15 --wait "POSITION:" report_position'
```

Expected: first reach World Map `(103,72)`, then enter Rimuldar at `(29,14)`.

- [ ] **Step 4: Run the complete route before treating the isolated stop as a separate bug.**

From Rimuldar `(29,14)` run:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc './dw_commands.sh --replace trace_input:900 auto_walk:4,5'
```

Expected evidence:

- `AUTO_WALK_NPC_PARK_SKIP map=0x0B reason=walkable_origin origin=(0,0)`;
- initial plan uses `npc_mode=live_npcs` and the 52-step outer-bank route;
- `(1,0)->(0,0)` succeeds without cadence or seam retry;
- the next queued step turns south and remains in Rimuldar;
- final position is `(4,5)` with no runtime blocks.

- [ ] **Step 5: Branch only on real-route evidence.**

If the full route turns south and reaches `(4,5)`, do not change marked
completion behavior from the isolated `(0,0)` stop. If the full route exits to
the World Map or fails to continue south, write a failing auto-step regression
for that exact coordinate-change/remaining-commit behavior before changing
`auto_step.lua`.

- [ ] **Step 6: Repeat the complete normal-entry route and run the repository gate.**

After returning normally to `(29,14)`, repeat Step 4. Then run:

```powershell
python run_tests.py --allow-missing-speech-dep
git diff --check
git status --short
```

Expected: two complete merchant routes, the full repository suite passes, and
only intentional Rimuldar implementation/test/config changes remain.

- [ ] **Step 7: Commit the verified implementation batch.**

Because `route_manager.lua` and its tests already contain the approved
uncommitted Rimuldar executor work, review the complete staged diff before
creating one coherent checkpoint:

```powershell
git diff -- route_manager.lua test_route_manager.lua dw_access.ini
git add route_manager.lua test_route_manager.lua dw_access.ini
git commit -m "fix: avoid unsafe NPC parking on walkable origin"
```

Expected: the commit contains no alternate-coordinate writes and includes the
guard regression plus the restored user configuration.
