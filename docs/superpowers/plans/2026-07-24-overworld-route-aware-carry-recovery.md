# Overworld Route-Aware Carry Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent guarded overworld recovery from committing an unintended extra tile while accepting a naturally carried tile only when it is the deterministic first step toward the next waypoint.

**Architecture:** `overworld_routes.lua` will derive an exact optional carry coordinate with the same axis-order logic used by normal segment planning. `route_manager.lua` will forward that coordinate without interpreting movement. `auto_step.lua` will distinguish guarded recovery from marked entry cadence, release the guarded press when its fresh attempt starts moving, and accept final drift only at the supplied coordinate.

**Tech Stack:** Lua 5.1/LuaJIT, the repository's table-driven Lua test harnesses, FCEUX 2.6.6, `dw_commands.ps1`, `dw_debug.log`, and the existing Python repository test runner.

## Global Constraints

- `auto_step_reset_movement_on_route_turn_settle=false` remains the production setting.
- Do not write `$003C`, `$003D`, or other gameplay RAM as part of recovery or carry handling.
- Preserve the full committed-input window for marked dungeon and town-entry waveforms.
- Preserve manual taps, raw probes, map crawling, interior pathfinding, hazards, live-input interruption, and ordinary on-segment drift consumption.
- A missing, malformed, incomplete, non-cardinal, or ambiguous carry target must default to strict arrival.
- Final route waypoints and waypoints with `route_accept_final_drift_completion=false` must not receive a carry target.
- Reverse, sideways, diagonal, multi-cell, and wrong-target drift must cancel as `route_drift_off_path`.
- Add no dependency and no user-facing configuration option.
- Preserve unrelated worktree content. In particular, do not stage `work_notes/hauksness_stat_corruption_20260724.log`.

## File Structure

- Modify `overworld_routes.lua`: extract reusable axis-ordered step construction, preview the first step after an intermediate waypoint, and add the optional coordinate to planned segments.
- Modify `test_overworld_routes.lua`: lock horizontal-first, vertical-first, final, and explicitly strict preview behavior.
- Modify `route_manager.lua`: forward and log `route_final_carry_x` / `route_final_carry_y`.
- Modify `test_route_manager.lua`: verify intermediate forwarding and strict final behavior.
- Modify `auto_step.lua`: tag guarded recovery separately from entry cadence, release it on fresh movement, validate the exact carry coordinate, and remove the broad same-direction completion rule.
- Modify `test_auto_step.lua`: cover guarded release, marked-entry compatibility, exact carry acceptance, wrong-target rejection, malformed metadata, and existing drift cases.
- Modify `PLAYTESTING.md`: record focused/full automated results and exact live evidence.
- Modify `session_handoff.md`: record the final autowalk status and next work.
- Read `dw_debug.log`: confirm guarded release, carry acceptance/rejection, exact position, and stat integrity.

---

### Task 1: Derive the next-route carry coordinate with the existing planner

**Files:**
- Modify: `test_overworld_routes.lua:108-132`
- Modify: `overworld_routes.lua:998-1027`
- Modify: `overworld_routes.lua:1432-1504`
- Modify: `overworld_routes.lua:1623-1635`

**Interfaces:**
- Consumes: `waypoint_axis_order(route, point, opts)` and `append_axis_steps(steps, axis, px, py, target_x, target_y)`
- Produces: private `build_axis_ordered_steps(route, point, px, py, opts) -> steps`
- Produces: private `preview_final_carry(route, index, opts) -> x|nil, y|nil`
- Produces for tests: `overworld_routes._preview_final_carry_for_tests(route, index, opts)`
- Produces for Task 2: `segment.route_final_carry_x` and `segment.route_final_carry_y`

- [ ] **Step 1: Add failing pure-preview and planned-segment regressions**

Add these tests near the existing axis-order tests in
`test_overworld_routes.lua`:

```lua
function tests.final_carry_preview_uses_next_waypoint_axis_order_and_strictness()
    local horizontal_route = {
        waypoints = {
            {x = 10, y = 10, name = "Current"},
            {
                x = 13,
                y = 12,
                name = "Horizontal next",
                axis_order = {"horizontal", "vertical"},
            },
        },
    }
    local vertical_route = {
        waypoints = {
            {x = 10, y = 10, name = "Current"},
            {
                x = 13,
                y = 12,
                name = "Vertical next",
                axis_order = {"vertical", "horizontal"},
            },
        },
    }

    local hx, hy = routes._preview_final_carry_for_tests(horizontal_route, 1)
    assert_equal(hx, 11, "horizontal-first lookahead should move east")
    assert_equal(hy, 10, "horizontal-first lookahead should preserve the row")

    local vx, vy = routes._preview_final_carry_for_tests(vertical_route, 1)
    assert_equal(vx, 10, "vertical-first lookahead should preserve the column")
    assert_equal(vy, 11, "vertical-first lookahead should move south")

    local final_x, final_y =
        routes._preview_final_carry_for_tests(vertical_route, 2)
    assert_equal(final_x, nil, "final waypoint should have no carry target")
    assert_equal(final_y, nil, "final waypoint should have no carry target")

    horizontal_route.waypoints[1].route_accept_final_drift_completion = false
    local strict_x, strict_y =
        routes._preview_final_carry_for_tests(horizontal_route, 1)
    assert_equal(strict_x, nil, "explicitly strict waypoint should reject carry")
    assert_equal(strict_y, nil, "explicitly strict waypoint should reject carry")
end

function tests.plan_next_segment_includes_route_aware_final_carry()
    routes.reset_for_tests()
    routes.start("erdrick", 0x01, 30, 32)

    local segment = assert(routes.plan_next_segment(0x01, 30, 32))

    assert_equal(
        segment.waypoint.name,
        "East choke approach",
        "fixture should target the east choke"
    )
    assert_equal(
        segment.route_final_carry_x,
        35,
        "next segment should remain on the eastern mountain column"
    )
    assert_equal(
        segment.route_final_carry_y,
        31,
        "next segment should begin one tile north toward the mountain lane"
    )

    routes.reset_for_tests()
end
```

- [ ] **Step 2: Run the overworld-route suite and verify RED**

Run:

```powershell
luajit test_overworld_routes.lua
```

Expected: the 106-test baseline remains otherwise green. The new tests fail
because `_preview_final_carry_for_tests` and the segment coordinate fields do
not exist.

- [ ] **Step 3: Extract one axis-ordered step builder**

Immediately after `waypoint_axis_order()` in `overworld_routes.lua`, add:

```lua
local function build_axis_ordered_steps(route, point, px, py, opts)
    local steps = {}
    local cx = px
    local cy = py

    for _, axis in ipairs(waypoint_axis_order(route, point, opts)) do
        cx, cy = append_axis_steps(
            steps, axis, cx, cy, point.x, point.y)
    end
    if cx ~= point.x then
        cx, cy = append_axis_steps(
            steps, "horizontal", cx, cy, point.x, point.y)
    end
    if cy ~= point.y then
        cx, cy = append_axis_steps(
            steps, "vertical", cx, cy, point.x, point.y)
    end

    return steps
end
```

Replace the duplicated builder inside `plan_next_segment()` with:

```lua
    local steps = build_axis_ordered_steps(route, point, px, py, opts)
```

This refactor must preserve every existing planned direction.

- [ ] **Step 4: Add the pure carry preview**

Below `build_axis_ordered_steps()`, add:

```lua
local function preview_final_carry(route, index, opts)
    local point = route and route.waypoints and route.waypoints[index]
    local next_point =
        route and route.waypoints and route.waypoints[index + 1]
    if not point
       or point.final == true
       or point.route_accept_final_drift_completion == false
       or not next_point then
        return nil, nil
    end

    local steps = build_axis_ordered_steps(
        route, next_point, point.x, point.y, opts)
    local first = steps[1]
    if first == "up" then
        return point.x, point.y - 1
    elseif first == "down" then
        return point.x, point.y + 1
    elseif first == "left" then
        return point.x - 1, point.y
    elseif first == "right" then
        return point.x + 1, point.y
    end
    return nil, nil
end
```

In the planned return path of `plan_next_segment()`, calculate and return the
pair:

```lua
    local route_final_carry_x, route_final_carry_y =
        preview_final_carry(route, index, opts)

    return {
        route = route,
        waypoint = point,
        index = index,
        steps = steps,
        path_length = #steps,
        route_final_carry_x = route_final_carry_x,
        route_final_carry_y = route_final_carry_y,
        status = "planned",
        direction = direction,
        message = string.format(
            "Auto-walk to %s, %s. %d step(s).",
            point.name,
            direction,
            #steps),
        log = make_log("autowalk_plan", route, point, index),
        object_id = route_object_id(route, index),
    }
```

Do not add carry fields to the `already_at_waypoint` result; it queues no
segment.

Expose only the established test seam near `_route_for_tests()`:

```lua
function M._preview_final_carry_for_tests(route, index, opts)
    return preview_final_carry(route, index, opts)
end
```

- [ ] **Step 5: Run the focused and adjacent suites**

Run:

```powershell
luajit test_overworld_routes.lua
luajit test_route_manager.lua
luajit -b overworld_routes.lua NUL
luajit -b test_overworld_routes.lua NUL
```

Expected: all tests pass and both bytecode checks exit without output.

- [ ] **Step 6: Review and commit the planner contract**

Run:

```powershell
git diff --check
git diff -- overworld_routes.lua test_overworld_routes.lua
git add -- overworld_routes.lua test_overworld_routes.lua
git diff --cached --check
git commit -m "feat: preview route-aware overworld carry"
```

Expected: only the route module and its focused test are committed.

---

### Task 2: Forward exact carry metadata through the route manager

**Files:**
- Modify: `test_route_manager.lua:800-860`
- Modify: `route_manager.lua:3732-3780`
- Modify: `route_manager.lua:3898-3915`
- Modify: `route_manager.lua:4860-4876`

**Interfaces:**
- Consumes from Task 1: `segment.route_final_carry_x: integer|nil` and `segment.route_final_carry_y: integer|nil`
- Produces for Task 4: `auto_step.start_route(steps, {route_final_carry_x = x, route_final_carry_y = y})`
- Preserves: `route_early_twitch_timeout_frames`, `route_hold_after_movement_start_frames`, and `route_reset_movement_on_turn_settle`

- [ ] **Step 1: Replace the broad-opt-in assertion with an exact-coordinate assertion**

In the `overworld_autowalk_queues_active_waypoint_segment` fixture, add:

```lua
            route_final_carry_x = 16,
            route_final_carry_y = 5,
```

Replace its `route_accept_final_drift_completion` assertion with:

```lua
    assert_equal(
        env.last_start_route_opts().route_final_carry_x,
        16,
        "overworld segment should forward the allowed carry column"
    )
    assert_equal(
        env.last_start_route_opts().route_final_carry_y,
        5,
        "overworld segment should forward the allowed carry row"
    )
    assert_equal(
        env.last_start_route_opts().route_accept_final_drift_completion,
        nil,
        "overworld segment should not use broad same-direction carry"
    )
```

Add a second test whose final segment omits both fields:

```lua
function tests.overworld_autowalk_keeps_final_segment_strict()
    local env = make_env({
        is_overworld = true,
        start_map_id = 0x01,
        start_x = 24,
        start_y = 89,
        current_object = {
            id = "route_hauksness_final",
            name = "Route next: Hauksness",
            type = "exit",
            x = 25,
            y = 89,
        },
        overworld_segment = {
            route = {id = "hauksness", title = "Hauksness"},
            waypoint = {name = "Hauksness", x = 25, y = 89, final = true},
            index = 1,
            steps = {"right"},
            message = "Auto-walk to Hauksness, 1 east. 1 step.",
            object_id = "route_hauksness_final",
        },
    })

    local plan = env.route_manager.autowalk_to_current()
    local opts = env.last_start_route_opts()

    assert_equal(plan.status, "queued", "final overworld segment should queue")
    assert_equal(opts.route_final_carry_x, nil,
        "final segment should not pass a carry column")
    assert_equal(opts.route_final_carry_y, nil,
        "final segment should not pass a carry row")

    env.restore()
end
```

- [ ] **Step 2: Run the route-manager suite and verify RED**

Run:

```powershell
luajit test_route_manager.lua
```

Expected: the 112-test baseline remains otherwise green. The new assertions
fail because the manager still sends the broad boolean and drops the exact
coordinates.

- [ ] **Step 3: Forward the pair without recreating route logic**

Remove `accept_final_drift` from the overworld queue path. Queue the segment
with:

```lua
    if not queue_overworld_segment_steps(segment.steps, {
        route_early_twitch_timeout_frames =
            segment.waypoint
            and segment.waypoint.route_early_twitch_timeout_frames,
        route_hold_after_movement_start_frames =
            segment.waypoint
            and segment.waypoint.route_hold_after_movement_start_frames,
        route_reset_movement_on_turn_settle =
            segment.waypoint
            and segment.waypoint.route_reset_movement_on_turn_settle,
        route_final_carry_x = segment.route_final_carry_x,
        route_final_carry_y = segment.route_final_carry_y,
    }) then
```

In `queue_overworld_segment_steps()`, replace the old boolean forwarding line
with:

```lua
        route_final_carry_x = opts.route_final_carry_x,
        route_final_carry_y = opts.route_final_carry_y,
```

Store the pair in `active_overworld_segment`:

```lua
        route_final_carry_x = segment.route_final_carry_x,
        route_final_carry_y = segment.route_final_carry_y,
```

- [ ] **Step 4: Add coordinate evidence to overworld logs**

Extend the overworld `event=start` log with:

```lua
carry=(%s,%s)
```

and arguments:

```lua
        tostring(active_overworld_segment.route_final_carry_x),
        tostring(active_overworld_segment.route_final_carry_y)
```

Extend the overworld `event=cancel` log with:

```lua
expected_carry=(%s,%s)
```

using the saved active-segment pair. Keep the current route, waypoint, index,
reason, and actual position fields.

- [ ] **Step 5: Run focused verification**

Run:

```powershell
luajit test_route_manager.lua
luajit test_overworld_routes.lua
luajit -b route_manager.lua NUL
luajit -b test_route_manager.lua NUL
git diff --check
```

Expected: both suites pass, syntax checks are silent, and no whitespace errors
appear.

- [ ] **Step 6: Commit the routing integration**

Run:

```powershell
git add -- route_manager.lua test_route_manager.lua
git diff --cached --check
git commit -m "feat: forward route-aware carry target"
```

Expected: the commit contains only route-manager integration and tests.

---

### Task 3: Release guarded recovery when the fresh attempt starts moving

**Files:**
- Modify: `test_auto_step.lua:1390-1518`
- Modify: `auto_step.lua:603-632`
- Modify: `auto_step.lua:990-1026`
- Modify: `auto_step.lua:1688-1756`

**Interfaces:**
- Consumes: the existing guarded neutral-and-repress state
- Produces: `auto_entry_waveform.guarded_twitch_recovery: boolean`
- Preserves: ordinary marked entry waveforms with `guarded_twitch_recovery == false`

- [ ] **Step 1: Add the failing fresh-sample release regression**

Add this test after the existing guarded-repress tests:

```lua
function tests.guarded_twitch_fresh_press_releases_on_its_own_movement_start()
    local env = make_env({
        sticky_joypad_set = true,
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_route_early_release_grace_frames = "10",
            auto_step_route_turn_settle_frames = "2",
            auto_step_inject_limit = "6",
        },
    })
    env.auto_step.start_route({"right", "down"})

    env.update(true)          -- Frame 1: original press.
    env.set_subpixel(0x20)
    env.update(true)          -- Frame 2: early twitch schedules recovery.
    env.update(true)          -- Frame 3: neutral settle.
    env.update(true)          -- Frame 4: neutral settle.
    env.update(true)          -- Frame 5: fresh recovery press.
    env.set_subpixel(0x30)
    env.update(true)          -- Frame 6: fresh movement must release.

    local sequences = collect_direction_sequences(env, "right", 6)
    assert_equal(#sequences, 2,
        "guarded recovery should issue exactly one fresh press")
    assert_equal(sequences[2].count, 1,
        "guarded fresh press should stop when its own movement begins")
    assert_frame_owned_neutral(
        env,
        6,
        "guarded movement start should release the committed direction"
    )

    env.restore()
end
```

- [ ] **Step 2: Run the auto-step suite and verify RED**

Run:

```powershell
luajit test_auto_step.lua
```

Expected: the existing 136 tests remain green. The new regression fails
because the guarded attempt still owns the full six-frame committed window.

- [ ] **Step 3: Tag only guarded recovery waveforms**

In the recovery record built by
`schedule_turn_repress(dir, guarded_twitch)`, add:

```lua
            guarded_twitch_recovery = true,
```

When `begin_step()` builds `auto_entry_waveform`, copy:

```lua
        guarded_twitch_recovery =
            state.guarded_twitch_recovery == true,
```

Do not set this field in `arm_entry_prime()` or
`schedule_entry_prime_retry()`. Their waveform remains fully committed.

- [ ] **Step 4: Release the guarded waveform before the full-window branch**

In the movement-start branch of `handle_active_auto_step()`, make guarded
recovery the first decision:

```lua
        if auto_entry_waveform
           and auto_entry_waveform.guarded_twitch_recovery == true then
            auto_entry_waveform.committed_frames_remaining = 0
            debug_tools.info(string.format(
                "AUTO_STEP_GUARDED_TWITCH_RELEASE from=(%d,%d) dir=%s frame=%d subpixel=0x%02X->0x%02X",
                auto_start_x or -1,
                auto_start_y or -1,
                tostring(auto_dir),
                auto_frames or -1,
                auto_start_subpixel or -1,
                current_subpixel or -1))
            neutralize_direction(joy, "neutral")
        elseif entry_committed_frames_remaining > 0 then
            -- The marked cadence owns its complete bounded press.
            neutralize_direction(nil, auto_dir)
            auto_entry_waveform.committed_frames_remaining =
                entry_committed_frames_remaining - 1
            auto_frames = auto_frames + 1
        elseif schedule_turn_repress(auto_dir, true) then
            neutralize_direction(joy, "neutral")
        elseif should_hold_after_movement_start()
           and (auto_entry_waveform == nil
                or auto_entry_waveform.hold_after_movement_start == true) then
            debug_tools.debug(string.format(
                "auto_step early movement twitch held dir=%s from=(%d,%d) frame=%d grace=%d queued_route=%s",
                tostring(auto_dir),
                auto_start_x or -1,
                auto_start_y or -1,
                auto_movement_start_frame or -1,
                get_route_early_release_grace_frames(),
                tostring(route_steps ~= nil)))
            if auto_entry_waveform then
                neutralize_direction(nil, auto_dir)
            else
                joypad.set(1, {[auto_dir] = true})
            end
        else
            neutralize_direction(
                joy,
                auto_entry_waveform and "neutral" or nil)
        end
```

Leave the existing `schedule_turn_repress`, bounded timeout, coordinate
completion, and off-direction cancellation branches after it.

- [ ] **Step 5: Prove marked entry cadence remains unchanged**

Run:

```powershell
luajit test_auto_step.lua
```

Expected: the new guarded-release regression passes. Existing
`primed_entry_committed_press_owns_exact_window_across_early_twitch`,
`primed_entry_retry_owns_exact_window_across_early_twitch`, and
`primed_entry_turn_repress_replays_full_waveform` remain green.

Run adjacent checks:

```powershell
luajit test_route_manager.lua
luajit -b auto_step.lua NUL
luajit -b test_auto_step.lua NUL
git diff --check
```

- [ ] **Step 6: Commit the bounded recovery change**

Run:

```powershell
git add -- auto_step.lua test_auto_step.lua
git diff --cached --check
git commit -m "fix: release guarded recovery on movement"
```

Expected: only the guarded-recovery tag, release branch, log, and focused test
are included.

---

### Task 4: Replace broad final drift with exact route-aware carry

**Files:**
- Modify: `test_auto_step.lua:4300-4425`
- Modify: `auto_step.lua:129-136`
- Modify: `auto_step.lua:335-337`
- Modify: `auto_step.lua:576-590`
- Modify: `auto_step.lua:1315-1343`
- Modify: `auto_step.lua:2003-2013`
- Modify: `auto_step.lua:2460-2480`

**Interfaces:**
- Consumes from Task 2: paired `route_final_carry_x` and `route_final_carry_y`
- Produces: exact-coordinate final-settle completion
- Preserves: `route_cancelled.reason == "route_drift_off_path"` for rejected drift

- [ ] **Step 1: Convert the successful-carry test to the exact pair**

Rename
`queued_route_final_settle_drift_can_complete_when_opted_in` to
`queued_route_final_settle_drift_completes_at_exact_allowed_target`.

Replace its route options with:

```lua
    env.auto_step.start_route({"right"}, {
        route_final_carry_x = 5,
        route_final_carry_y = 1,
    })
```

Keep the planned endpoint `(4,1)`, carried position `(5,1)`, and completion
assertions.

- [ ] **Step 2: Add wrong-target and malformed-pair regressions**

Add:

```lua
function tests.queued_route_final_settle_rejects_same_direction_wrong_target()
    local env = make_env({
        config_values = {
            auto_step_route_final_settle_frames = "5",
        },
    })
    env.auto_step.start_route({"right"}, {
        route_accept_final_drift_completion = true,
        route_final_carry_x = 4,
        route_final_carry_y = 2,
    })

    env.update(true)
    env.set_position(4, 1)
    env.update(true)
    env.set_position(5, 1)
    for _ = 1, 4 do
        env.update(true)
    end

    local cancelled = nil
    for _, event in ipairs(env.published) do
        if event.name == "route_cancelled" then
            cancelled = event.payload
        end
        assert_truthy(event.name ~= "route_completed",
            "same-direction drift to the wrong target must not complete")
    end
    assert_equal(cancelled and cancelled.reason, "route_drift_off_path",
        "wrong-target carry should cancel as route drift")

    env.restore()
end

function tests.queued_route_final_settle_rejects_non_cardinal_carry_target()
    local env = make_env({
        config_values = {
            auto_step_route_final_settle_frames = "5",
        },
    })
    env.auto_step.start_route({"right"}, {
        route_final_carry_x = 5,
        route_final_carry_y = 2,
    })

    env.update(true)
    env.set_position(4, 1)
    env.update(true)
    env.set_position(5, 2)
    for _ = 1, 4 do
        env.update(true)
    end

    local saw_cancel = false
    for _, event in ipairs(env.published) do
        local payload = event.payload or {}
        if event.name == "route_cancelled"
           and payload.reason == "route_drift_off_path" then
            saw_cancel = true
        end
        assert_truthy(event.name ~= "route_completed",
            "diagonal carry metadata must not complete")
    end
    assert_truthy(saw_cancel,
        "non-cardinal carry metadata should preserve strict arrival")

    env.restore()
end

function tests.queued_route_final_settle_ignores_incomplete_carry_pair()
    local env = make_env({
        config_values = {
            auto_step_route_final_settle_frames = "5",
        },
    })
    env.auto_step.start_route({"right"}, {
        route_final_carry_x = 5,
    })

    env.update(true)
    env.set_position(4, 1)
    env.update(true)
    env.set_position(5, 1)
    for _ = 1, 4 do
        env.update(true)
    end

    local saw_cancel = false
    for _, event in ipairs(env.published) do
        local payload = event.payload or {}
        if event.name == "route_cancelled"
           and payload.reason == "route_drift_off_path" then
            saw_cancel = true
        end
        assert_truthy(event.name ~= "route_completed",
            "incomplete carry metadata must not complete")
    end
    assert_truthy(saw_cancel,
        "incomplete carry metadata should preserve strict arrival")

    env.restore()
end
```

Update the existing nonmatching-carry table test to pass a valid target:

```lua
        route_final_carry_x = 5,
        route_final_carry_y = 1,
```

Keep its sideways, reverse, and two-cell cases.

- [ ] **Step 3: Run the auto-step suite and verify RED**

Run:

```powershell
luajit test_auto_step.lua
```

Expected: Task 3 remains green. Exact pair completion fails because the
executor does not read the new fields, while the wrong-target test proves the
old same-direction rule is too broad when its legacy boolean is enabled.

- [ ] **Step 4: Replace the boolean override with a coordinate pair**

At module state, replace:

```lua
local route_accept_final_drift_completion_override = nil
```

with:

```lua
local route_final_carry_x_override = nil
local route_final_carry_y_override = nil
```

Clear both in `clear_route()`.

Remove `should_accept_final_drift_completion()` and
`is_exact_final_direction_carry()`. Add:

```lua
local function is_allowed_final_carry(px, py)
    if route_final_carry_x_override == nil
       or route_final_carry_y_override == nil
       or route_last_x == nil
       or route_last_y == nil then
        return false
    end

    local distance =
        math.abs(route_final_carry_x_override - route_last_x)
        + math.abs(route_final_carry_y_override - route_last_y)
    if distance ~= 1 then
        debug_tools.info(string.format(
            "AUTO_STEP_FINAL_CARRY_INVALID from=(%d,%d) target=(%s,%s)",
            route_last_x or -1,
            route_last_y or -1,
            tostring(route_final_carry_x_override),
            tostring(route_final_carry_y_override)))
        return false
    end

    return px == route_final_carry_x_override
        and py == route_final_carry_y_override
end
```

Update `complete_route_from_final_drift()` to log:

```text
AUTO_STEP_FINAL_CARRY_ACCEPTED
```

with the prior endpoint, expected target, actual coordinate, route index, and
source.

- [ ] **Step 5: Parse only a complete integer pair at route start**

In `M.start_route()`, replace the old boolean parsing with:

```lua
    local raw_final_carry_x = opts.route_final_carry_x
    local raw_final_carry_y = opts.route_final_carry_y
    local final_carry_x = tonumber(raw_final_carry_x)
    local final_carry_y = tonumber(raw_final_carry_y)
    local valid_final_carry =
        final_carry_x ~= nil
        and final_carry_y ~= nil
        and final_carry_x == math.floor(final_carry_x)
        and final_carry_y == math.floor(final_carry_y)

    if valid_final_carry then
        route_final_carry_x_override = final_carry_x
        route_final_carry_y_override = final_carry_y
    else
        route_final_carry_x_override = nil
        route_final_carry_y_override = nil
        if raw_final_carry_x ~= nil or raw_final_carry_y ~= nil then
            debug_tools.info(string.format(
                "AUTO_STEP_FINAL_CARRY_METADATA_INVALID target=(%s,%s)",
                tostring(raw_final_carry_x),
                tostring(raw_final_carry_y)))
        end
    end
```

Do not infer a coordinate from the final planned direction.

- [ ] **Step 6: Enforce the exact target during final settle**

Replace the broad acceptance condition with:

```lua
            if route_final_settle_active
               and is_allowed_final_carry(px, py) then
                complete_route_from_final_drift(
                    px, py, "route_final_settle_carry")
                sync_prev_held(joy)
                return true
            end
```

All other `off_path` results continue through
`cancel_route_for_drift(px, py, "route_settle_catchup")`.

- [ ] **Step 7: Run focused and adjacent verification**

Run:

```powershell
luajit test_auto_step.lua
luajit test_route_manager.lua
luajit test_overworld_routes.lua
luajit -b auto_step.lua NUL
luajit -b test_auto_step.lua NUL
git diff --check
```

Expected: all focused suites pass. Existing on-segment catch-up, strict
default, marked-entry cadence, manual movement, hazard, and movement-reset
regressions remain green.

- [ ] **Step 8: Commit exact carry enforcement**

Run:

```powershell
git add -- auto_step.lua test_auto_step.lua
git diff --cached --check
git commit -m "fix: require route-aware final carry target"
```

Expected: the commit contains only executor carry enforcement and tests.

---

### Task 5: Verify the complete change live and publish project state

**Files:**
- Modify after evidence: `PLAYTESTING.md`
- Modify after evidence: `session_handoff.md`
- Read: `dw_debug.log`
- Read: `speech_bridge.log`

**Interfaces:**
- Consumes: Tasks 1 through 4 and the existing FCEUX command queue
- Produces: automated and live evidence for draft PR #3

- [ ] **Step 1: Run the complete automated verification gate**

Run:

```powershell
luajit test_overworld_routes.lua
luajit test_route_manager.lua
luajit test_auto_step.lua
luajit -b overworld_routes.lua NUL
luajit -b route_manager.lua NUL
luajit -b auto_step.lua NUL
luajit -b test_overworld_routes.lua NUL
luajit -b test_route_manager.lua NUL
luajit -b test_auto_step.lua NUL
git diff --check
wsl.exe bash -lc "cd /mnt/d/modding/DragonWarrior1 && python3 run_tests.py --allow-missing-speech-dep"
```

Expected: all focused suites, bytecode checks, and the full repository harness
pass. If WSL remains unavailable in the Codex sandbox, request permission or
run the Windows-accessible focused suites first and require the full harness
before completion.

- [ ] **Step 2: Pause for the user's manual FCEUX Lua restart**

Tell the user:

```text
The source and automated tests are ready. Please use Restart in FCEUX's Lua
Script Control, then tell me the current world-map coordinate and active route.
```

Do not treat source-on-disk results as live before the restart.

- [ ] **Step 3: Establish fresh polling, position, route, and stat baseline**

After restart confirmation, run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait-ready AUTOWALK_ROUTE_CARRY
.\dw_commands.ps1 --replace --timeout 15 --wait "REPORT_POSITION" report_position log_state report_path_state route_guidance speech_status
```

Expected: fresh `LAUNCHER_PROBE: AUTOWALK_ROUTE_CARRY`, world map state, an
internally consistent stat snapshot, no stale movement command, and current
route guidance. Stop if polling is stale, the menu is open, combat is active,
or the map is not the world map.

- [ ] **Step 4: Exercise intermediate route segments**

Use normal gameplay positioning and the active route; do not use teleport
evidence to judge movement timing. Queue one segment at a time:

```powershell
.\dw_commands.ps1 --replace auto_walk
```

Inspect after each segment:

```powershell
Get-Content -LiteralPath .\dw_debug.log -Tail 260
```

Continue through at least three short intermediate segments unless combat,
reload, or another stop condition requires the user. Prefer the Hauksness-to-
Kol north-coast area around `(8,3)` if it is reachable through normal play,
because that area previously produced final-settle carry.

For guarded recovery, require:

```text
AUTO_STEP_GUARDED_TWITCH_REPRESS
AUTO_STEP_GUARDED_TWITCH_RELEASE
```

The release must occur after the fresh attempt's movement-start log and before
an unintended second coordinate. If no guarded twitch occurs during three
clean segments, record clean ordinary timing while keeping the exact waveform
behavior automated-verified.

For carried movement, require:

```text
AUTO_STEP_FINAL_CARRY_ACCEPTED
```

and verify the actual coordinate equals the `carry=(x,y)` target from
`OVERWORLD_AUTO_WALK: event=start`. If no natural carry occurs, keep exact
acceptance/rejection automated-verified rather than forcing movement.

- [ ] **Step 5: Validate a strict destination**

Continue through normal play to a final town or entrance segment, or use the
next naturally available final segment. Confirm its start log contains:

```text
carry=(nil,nil)
```

and that completion occurs only on the exact final waypoint. Any position
beyond the destination must cancel rather than publish route completion.

- [ ] **Step 6: Confirm stat and RAM safety**

After field control returns, run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait "REPORT_POSITION" report_position log_state report_path_state
```

Inspect the live log for absence of:

```text
PLAYER_STAT_FRAMEADVANCE_TRANSITION
PLAYER_STAT_INTEGRITY_TRANSITION
PLAYER_STAT_INTEGRITY_WARNING
queued_route_turn_settle movement reset
```

Require internally consistent HP, MP, Strength, Agility, Attack, Defense, and
spell state. Do not attribute combat damage or spell use to corruption.

- [ ] **Step 7: Update shared project status from exact evidence**

Add a concise `PLAYTESTING.md` entry containing:

- focused and full automated test outcomes;
- reload tag and starting coordinate;
- routes/segments exercised;
- whether guarded release and valid carry occurred naturally;
- exact accepted or rejected coordinates;
- strict final-destination result; and
- stat-integrity outcome.

Update `session_handoff.md` with the final behavior, any live case still
awaiting a natural occurrence, and the next recommended autowalk or map task.
Do not claim a natural event was observed when only the deterministic unit
fixture exercised it.

- [ ] **Step 8: Commit, push, and update draft PR #3**

Run:

```powershell
git add -- PLAYTESTING.md session_handoff.md
git diff --cached --check
git commit -m "docs: record route-aware autowalk validation"
git push origin codex/battle-dialogue-autowalk-tuning
git status --short --branch
```

Expected: the branch matches
`origin/codex/battle-dialogue-autowalk-tuning`; draft PR #3 contains the
design, plan, test-first implementation commits, and validation notes. The raw
Hauksness diagnostic log remains untracked.
