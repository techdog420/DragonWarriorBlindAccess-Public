# Overworld Final-Drift Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let overworld route segments complete after an exact one-cell carry in the final planned direction while rejecting every other final drift shape.

**Architecture:** `route_manager.lua` opts overworld segments into the existing final-drift mechanism. `auto_step.lua` narrows that mechanism to an exact one-cell continuation from the planned endpoint in the last route direction; it does not reset movement RAM.

**Tech Stack:** Lua 5.1/LuaJIT, the existing `test_auto_step.lua` and `test_route_manager.lua` harnesses, FCEUX live command queue.

## Global Constraints

- Do not write `$003C`, `$003D`, or other gameplay RAM as part of this fix.
- Preserve conservative cancellation for sideways, reverse, diagonal, multi-cell, map-changing, and pre-final-step drift.
- Preserve the existing `auto_step_reset_movement_on_route_turn_settle=false` configuration.
- Do not change permanent map data.

---

### Task 1: Guard final-drift acceptance by direction and distance

**Files:**
- Modify: `test_auto_step.lua:4310`
- Modify: `auto_step.lua:1315`
- Modify: `auto_step.lua:1994`

**Interfaces:**
- Consumes: existing `route_steps`, `route_last_x`, `route_last_y`, `direction_delta(dir)`, and `route_accept_final_drift_completion` option.
- Produces: internal `is_exact_final_direction_carry(px, py) -> boolean` used only during final settle.

- [ ] **Step 1: Add failing drift-shape tests**

Add three focused tests beside `queued_route_final_settle_drift_can_complete_when_opted_in`. Each starts `{"right"}` with `route_accept_final_drift_completion=true`, completes at `(4,1)`, then supplies one invalid live position:

```lua
-- Sideways carry.
env.set_position(4, 2)

-- Reverse carry.
env.set_position(3, 1)

-- Two-cell forward carry.
env.set_position(6, 1)
```

For each case, assert that `route_cancelled` has `reason == "route_drift_off_path"` and that no `route_completed` event is published. Keep the existing opted-in `(5,1)` test as the passing exact-forward specification.

- [ ] **Step 2: Run the test and verify RED**

Run: `lua test_auto_step.lua`

Expected: the three new invalid-shape tests fail because the current opt-in accepts every off-path final-settle position.

- [ ] **Step 3: Implement the exact carry predicate**

Add before `complete_route_from_final_drift`:

```lua
local function is_exact_final_direction_carry(px, py)
    if not route_steps or #route_steps == 0
       or route_last_x == nil or route_last_y == nil then
        return false
    end
    local dx, dy = direction_delta(route_steps[#route_steps])
    return px == route_last_x + dx and py == route_last_y + dy
end
```

Narrow the final-settle branch:

```lua
if route_final_settle_active
   and should_accept_final_drift_completion()
   and is_exact_final_direction_carry(px, py) then
    complete_route_from_final_drift(px, py, "route_final_settle_carry")
    sync_prev_held(joy)
    return true
end
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run: `lua test_auto_step.lua`

Expected: all auto-step tests pass, including the existing exact-forward completion and the three new cancellation cases.

### Task 2: Opt overworld segments into guarded final carry

**Files:**
- Modify: `test_route_manager.lua:799`
- Modify: `route_manager.lua:3734`

**Interfaces:**
- Consumes: `auto_step.start_route(steps, opts)`.
- Produces: `opts.route_accept_final_drift_completion=true` for every overworld waypoint segment unless that waypoint explicitly sets the property to `false`.

- [ ] **Step 1: Change the overworld queue test to require the default**

Remove `route_accept_final_drift_completion = true` from the waypoint fixture in `overworld_autowalk_queues_active_waypoint_segment`, but retain and clarify the assertion:

```lua
assert_equal(
    env.last_start_route_opts().route_accept_final_drift_completion,
    true,
    "overworld segments should enable guarded final-drift completion by default"
)
```

- [ ] **Step 2: Run the route-manager test and verify RED**

Run: `lua test_route_manager.lua`

Expected: the changed assertion fails with `nil` because the waypoint no longer supplies the option.

- [ ] **Step 3: Enable the safe default in the overworld queue**

Before `queue_overworld_segment_steps`, derive an explicit-false override:

```lua
local accept_final_drift = not (
    segment.waypoint
    and segment.waypoint.route_accept_final_drift_completion == false)
```

Pass it in the existing option table:

```lua
route_accept_final_drift_completion = accept_final_drift,
```

- [ ] **Step 4: Run focused movement tests**

Run:

```powershell
lua test_auto_step.lua
lua test_route_manager.lua
luac -p auto_step.lua route_manager.lua test_auto_step.lua test_route_manager.lua
git diff --check
```

Expected: both suites pass, all four files byte-compile, and `git diff --check` reports no errors.

- [ ] **Step 5: Commit the movement fix**

```powershell
git add auto_step.lua route_manager.lua test_auto_step.lua test_route_manager.lua
git commit -m "fix: accept guarded overworld final drift"
```

### Task 3: Live movement verification

**Files:**
- Modify after proof: `work_notes/current_investigation.md`

**Interfaces:**
- Consumes: FCEUX `main.lua` manual restart and the active Hauksness route.
- Produces: fresh log evidence that exact same-direction carry completes and unsafe drift still cancels.

- [ ] **Step 1: Ask the user to restart `main.lua`**

Do not queue movement until the user confirms restart.

- [ ] **Step 2: Confirm fresh baseline**

Run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait-ready overworld_final_drift report_position report_runtime_blocks report_path_state route_status
```

Expected: a fresh launcher marker, World Map state, no runtime blockers, and Hauksness guidance or a clean route restart.

- [ ] **Step 3: Resume one segment at a time**

Ensure the Travel selection is Hauksness, then run `auto_walk` with a fresh completion/cancellation wait. On a final carry, require `OVERWORLD_AUTO_WALK: event=complete`, the live position exactly one tile beyond the waypoint in the final direction, and no RAM-reset log.

- [ ] **Step 4: Record only verified evidence**

Append the exact segment, endpoint, carry position, completion event, runtime-block state, and any unresolved executor behavior to `work_notes/current_investigation.md`.
