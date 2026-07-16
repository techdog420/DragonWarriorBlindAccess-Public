# Rimuldar Settled Re-press Amendment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the disproven Rimuldar continuous-hold executor with a map-scoped 16-frame neutral settle before the final west press into `(0,0)`.

**Architecture:** `map_reader.lua` owns the verified entry requirement as a numeric frame count. `route_manager.lua` converts a path crossing that entry into `settle_before_steps[step_index]`, and generic `auto_step.lua` merges that value into its existing route-settle state before starting the marked step. The existing standard-arrival repair remains unchanged.

**Tech Stack:** Lua 5.1-compatible source, local Lua test harnesses, `luac`, FCEUX command queue, `dw_debug.log`.

## Global Constraints

- Use normal movement only for acceptance; no teleport or runtime blocker.
- The only marked entry is map `0x0B`, destination `(0,0)`, approach `east`, with `16` physical neutral frames before its press.
- Treat the value as an entry execution requirement, not passability.
- Ordinary and unmarked routes retain their existing timing.
- After the completion callback, a still-current marked continuation owns the
  next frame and bypasses redundant forced release; callback replacement keeps
  the replacement route's appropriate release/settle state.
- A marked settle keeps route cancellation, drift, hazard, blocker, and per-tile event behavior intact.
- Remove the disproven continuous-hold metadata and executor behavior instead of retaining both models.
- Write and run each regression before its production change.
- FCEUX requires a manual Lua reload after source changes.

---

### Task 1: Replace cadence metadata and path translation

**Files:**
- Modify: `map_reader.lua`
- Modify: `route_manager.lua`
- Test: `test_map_reader.lua`
- Test: `test_route_manager.lua`

**Interfaces:**
- Produces: `map_reader.get_entry_settle_frames(map_id, x, y, approach) -> integer`.
- Produces: `auto_step.start_route(steps, {settle_before_steps={[step_index]=frames}})`.
- The numeric key identifies the step that must begin only after the specified neutral settle.

- [ ] **Step 1: Replace the map-reader regression with the desired numeric contract.**

```lua
function tests.rimuldar_marks_only_verified_entry_settle()
    local env = make_env()

    assert_equal(
        env.map_reader.get_entry_settle_frames(0x0B, 0, 0, "east"),
        16,
        "Rimuldar (0,0) east entry should require a 16-frame neutral settle"
    )
    assert_equal(
        env.map_reader.get_entry_settle_frames(0x0B, 0, 0, "west"),
        0,
        "Rimuldar reverse entry should retain ordinary cadence"
    )
    assert_equal(
        env.map_reader.get_entry_settle_frames(0x0B, 1, 0, "east"),
        0,
        "neighboring top-bank cells should not become cadence entries"
    )
    assert_equal(
        env.map_reader.get_entry_settle_frames(0x0A, 0, 0, "east"),
        0,
        "entry-settle metadata should remain map-scoped"
    )

    env.restore()
end
```

- [ ] **Step 2: Run the map-reader test and verify RED.**

Run:

```powershell
lua test_map_reader.lua
```

Expected: exit `1`; the new test fails because `get_entry_settle_frames` does not exist.

- [ ] **Step 3: Replace the route-manager stub and regression with step-local settle metadata.**

In the `map_reader` stub inside `make_env`:

```lua
get_entry_settle_frames = function(map_id, x, y, approach)
    local by_map = options.entry_settle_frames
        and options.entry_settle_frames[map_id]
    local entry = by_map and by_map[tostring(x) .. "," .. tostring(y)]
    return math.max(0, math.floor(tonumber(
        type(entry) == "table" and entry[approach] or 0
    ) or 0))
end,
```

Replace the continuous-run path test with:

```lua
function tests.rimuldar_path_marks_only_the_cadence_entry_step()
    local target = {id = "exit_test", name = "Test destination", type = "exit", x = 1, y = 1}
    local path = {
        {x = 3, y = 0, direction = "north"},
        {x = 2, y = 0, direction = "west"},
        {x = 1, y = 0, direction = "west"},
        {x = 0, y = 0, direction = "west"},
        {x = 0, y = 1, direction = "south"},
        {x = 1, y = 1, direction = "east"},
    }
    local env = make_env({
        start_map_id = 0x0B,
        start_x = 3,
        start_y = 1,
        current_object = target,
        entry_settle_frames = {
            [0x0B] = {["0,0"] = {east = 16}},
        },
        pathfind_to_fn = function()
            return "Path: north, 3 west, south, east", "east", path
        end,
    })

    local result = env.route_manager.autowalk_to_object(target, {speak = false})
    local settles = env.last_start_route_opts().settle_before_steps

    assert_equal(result.status, "queued", "synthetic Rimuldar route should queue")
    assert_equal(settles and settles[4], 16, "entry step should receive the verified settle")
    assert_equal(settles and settles[2], nil, "earlier west steps should retain ordinary timing")
    assert_equal(settles and settles[3], nil, "the approach step should not settle early")
    assert_equal(settles and settles[5], nil, "the south turn should not inherit the entry settle")

    env.restore()
end

function tests.rimuldar_path_marks_cadence_entry_when_it_is_step_one()
    local target = {id = "entry_test", name = "Entry destination", type = "exit", x = 0, y = 0}
    local env = make_env({
        start_map_id = 0x0B,
        start_x = 1,
        start_y = 0,
        current_object = target,
        entry_settle_frames = {
            [0x0B] = {["0,0"] = {east = 16}},
        },
        pathfind_to_fn = function()
            return "Path: 1 west", "west", {
                {x = 0, y = 0, direction = "west"},
            }
        end,
    })

    local result = env.route_manager.autowalk_to_object(target, {speak = false})
    local settles = env.last_start_route_opts().settle_before_steps

    assert_equal(result.status, "queued", "one-step Rimuldar route should queue")
    assert_equal(settles and settles[1], 16, "first entry step should retain its settle")

    env.restore()
end
```

- [ ] **Step 4: Run the route-manager test and verify RED.**

Run:

```powershell
lua test_route_manager.lua
```

Expected: exit `1`; the new path test fails because `settle_before_steps` is absent.

- [ ] **Step 5: Implement numeric map metadata.**

Replace `MAP_CONTINUOUS_HOLD_ENTRIES` and `requires_continuous_hold_entry` with:

```lua
local MAP_ENTRY_SETTLE_FRAMES = {
    [0x0B] = {
        -- A held west run stalls at (1,0). Live raw sequences proved that
        -- 8- and 12-frame gaps fail while a 16-frame neutral gap succeeds.
        ["0,0"] = {east = 16},
    },
}

function M.get_entry_settle_frames(map_id, x, y, approach)
    local map_entries = MAP_ENTRY_SETTLE_FRAMES[tonumber(map_id)]
    local nx = tonumber(x)
    local ny = tonumber(y)
    if not map_entries or nx == nil or ny == nil or approach == nil then
        return 0
    end
    local key = tostring(math.floor(nx)) .. "," .. tostring(math.floor(ny))
    local entry = map_entries[key]
    local frames = type(entry) == "table" and tonumber(entry[tostring(approach)]) or 0
    return math.max(0, math.floor(frames or 0))
end
```

- [ ] **Step 6: Implement path-to-step translation.**

Replace `continuous_hold_after_steps_for_path` with:

```lua
local function settle_before_steps_for_path(map_id, route_path, start_x, start_y)
    if not map_reader.get_entry_settle_frames then
        return nil
    end

    local settles = {}
    for step_index, step in ipairs(route_path or {}) do
        local key_dir = DIR_NAME_TO_KEY[step.direction]
        local approach = key_dir and DIR_TO_APPROACH[key_dir]
        local frames = approach and map_reader.get_entry_settle_frames(
            map_id, step.x, step.y, approach) or 0
        if frames > 0 then
            settles[step_index] = frames
            local origin = step_index == 1
                and {x = start_x, y = start_y}
                or route_path[step_index - 1]
            debug_tools.info(string.format(
                "AUTO_WALK_ENTRY_SETTLE map=0x%02X from=(%d,%d) dest=(%d,%d) dir=%s step=%d frames=%d",
                map_id or -1,
                tonumber(origin and origin.x) or -1,
                tonumber(origin and origin.y) or -1,
                tonumber(step.x) or -1,
                tonumber(step.y) or -1,
                tostring(key_dir),
                step_index,
                frames))
        end
    end

    return next(settles) and settles or nil
end
```

In `queue_path_steps`, compute and pass:

```lua
local settle_before_steps = settle_before_steps_for_path(
    map_id, path, start_x, start_y)
```

```lua
settle_before_steps = settle_before_steps,
```

Delete the continuous-run logger and marker construction.

- [ ] **Step 7: Run focused tests and verify GREEN.**

Run:

```powershell
lua test_map_reader.lua
lua test_route_manager.lua
git diff --check
```

Expected: both suites pass and `git diff --check` exits `0`.

- [ ] **Step 8: Commit Task 1.**

```powershell
git add map_reader.lua route_manager.lua test_map_reader.lua test_route_manager.lua
git commit -m "fix: mark Rimuldar settled entry step"
```

---

### Task 2: Replace continuous hold with per-step route settling

**Files:**
- Modify: `auto_step.lua`
- Test: `test_auto_step.lua`

**Interfaces:**
- Consumes: `opts.settle_before_steps={[step_index]=frames}`.
- Preserves: flat `route_steps`, existing `route_settle_frames`, normal cancellation, and one completion event per tile.

- [ ] **Step 1: Replace continuous-hold tests with the required settle waveform.**

```lua
function tests.marked_entry_waits_for_sixteen_physical_neutral_frames_before_repress()
    local env = make_env({sticky_joypad_set = true})
    env.auto_step.start_route({"right", "right"}, {
        start_x = 3,
        start_y = 1,
        settle_before_steps = {[2] = 16},
    })

    env.update(true)
    env.set_position(4, 1)
    env.update(true)

    -- Frame 2 is the neutral completion frame. Frames 3-17 supply the
    -- remaining 15 neutral frames.
    for frame = 3, 17 do
        env.update(true)
        assert_frame_neutral(env, frame, "marked entry settle")
    end

    env.update(true)
    assert_frame_only_direction(env, 18, "right", "fresh marked-entry press")

    env.restore()
end

function tests.marked_first_step_waits_for_all_sixteen_neutral_frames()
    local env = make_env({sticky_joypad_set = true})
    env.auto_step.start_route({"right"}, {
        start_x = 3,
        start_y = 1,
        settle_before_steps = {[1] = 16},
    })

    for frame = 1, 16 do
        env.update(true)
        assert_frame_neutral(env, frame, "marked first-step settle")
    end

    env.update(true)
    assert_frame_only_direction(env, 17, "right", "fresh first-step press")

    env.restore()
end

function tests.marked_entry_settle_owns_first_followup_frame()
    local env = make_env({sticky_joypad_set = true})
    env.auto_step.start_route({"right", "right"}, {
        start_x = 3,
        start_y = 1,
        settle_before_steps = {[2] = 16},
    })

    env.update(true)
    env.set_position(4, 1)
    env.update(true)
    env.set_joy({left = true})
    env.update(true)

    local cancelled = nil
    for _, event in ipairs(env.published) do
        local payload = event.payload or {}
        if event.name == "route_cancelled" and event.frame == 3 then
            cancelled = payload
            break
        end
    end

    assert_equal(cancelled and cancelled.reason, "live_input_interrupt",
        "first followup frame should cancel through route settle")
    assert_equal(cancelled and cancelled.source, "route_settle",
        "marked route settle should own the first followup frame")
    assert_equal(env.auto_step.is_route_active(), false,
        "live input should cancel the marked settle immediately")

    env.restore()
end

function tests.callback_requeued_marked_first_step_owns_initial_settle()
    local env = make_env({sticky_joypad_set = true})
    local requeued = false
    env.auto_step.on_step_complete = function()
        if requeued then return end
        requeued = true
        env.auto_step.start_route({"right"}, {
            start_x = 4,
            start_y = 1,
            settle_before_steps = {[1] = 16},
        })
    end
    env.auto_step.start_route({"right"}, {start_x = 3, start_y = 1})

    env.update(true)
    env.set_position(4, 1)
    env.update(true)
    env.set_joy({left = true})
    env.update(true)

    local cancelled = nil
    for _, event in ipairs(env.published) do
        local payload = event.payload or {}
        if event.name == "route_cancelled" and event.frame == 3 then
            cancelled = payload
            break
        end
    end

    assert_equal(cancelled and cancelled.reason, "live_input_interrupt",
        "callback-requeued first-step settle should see live input immediately")
    assert_equal(cancelled and cancelled.source, "route_settle",
        "marked initial settle should replace stale post-step release")
    assert_equal(env.auto_step.is_route_active(), false,
        "live input should cancel callback-requeued marked route")

    env.restore()
end

function tests.callback_unmarked_replacement_preserves_stale_blip_release()
    local env = make_env()
    local replacement_started = false
    env.auto_step.on_step_complete = function()
        if replacement_started then return end
        replacement_started = true
        env.auto_step.start_route({"down"}, {
            start_x = 4,
            start_y = 1,
        })
    end
    env.auto_step.start_route({"right", "right"}, {
        start_x = 3,
        start_y = 1,
        settle_before_steps = {[2] = 16},
    })

    env.update(true)
    env.set_position(4, 1)
    env.update(true)
    env.set_joy({right = true})
    env.update(true)

    assert_frame_neutral(env, 3,
        "callback replacement stale-input release")
    assert_equal(env.auto_step.is_route_active(), true,
        "unmarked callback replacement should survive the stale blip")
    for _, event in ipairs(env.published) do
        local payload = event.payload or {}
        assert_truthy(
            not (event.frame == 3
                and event.name == "route_cancelled"
                and payload.reason == "live_input_interrupt"),
            "old marked settle must not clear replacement-route release state")
    end

    env.restore()
end

function tests.marked_entry_settle_applies_when_straight_settle_is_disabled()
    local env = make_env({sticky_joypad_set = true})
    env.auto_step.start_route({"right", "right"}, {
        start_x = 3,
        start_y = 1,
        settle_same_direction = false,
        settle_before_steps = {[2] = 16},
    })

    env.update(true)
    env.set_position(4, 1)
    env.update(true)
    for frame = 3, 17 do
        env.update(true)
        assert_frame_neutral(env, frame, "required same-direction entry settle")
    end
    env.update(true)
    assert_frame_only_direction(env, 18, "right", "required same-direction re-press")

    env.restore()
end

function tests.larger_turn_settle_remains_authoritative()
    local env = make_env({
        sticky_joypad_set = true,
        config_values = {auto_step_route_turn_settle_frames = "20"},
    })
    env.auto_step.start_route({"right", "down"}, {
        start_x = 3,
        start_y = 1,
        settle_before_steps = {[2] = 16},
    })

    env.update(true)
    env.set_position(4, 1)
    env.update(true)
    for frame = 3, 22 do
        env.update(true)
        assert_frame_neutral(env, frame, "maximum merged settle")
    end
    env.update(true)
    assert_frame_only_direction(env, 23, "down", "post-turn fresh press")

    env.restore()
end

function tests.completion_callback_can_abort_marked_entry_settle()
    local env = make_env({sticky_joypad_set = true})
    env.auto_step.on_step_complete = function()
        env.auto_step.clear_route()
    end
    env.auto_step.start_route({"right", "right"}, {
        start_x = 3,
        start_y = 1,
        settle_before_steps = {[2] = 16},
    })

    env.update(true)
    env.set_position(4, 1)
    env.update(true)
    env.set_joy({right = true})
    env.update(true)
    assert_frame_neutral(env, 3,
        "callback-cleared route should retain completion release")
    env.set_joy({})
    for _ = 1, 19 do env.update(true) end

    for frame = 2, 22 do
        assert_truthy(
            not (env.injected[frame] and env.injected[frame].right),
            "callback-cleared route should not start marked next step"
        )
    end
    assert_equal(env.auto_step.is_route_active(), false,
        "completion callback should clear the marked route")

    env.restore()
end
```

Add a state-derived pending-repress helper and regression so both completion
paths prove the same ownership and frame count:

```lua
local function complete_route_step_via_pending_repress(env)
    local pending = nil
    for _ = 1, 40 do
        env.update(true)
        local state = env.auto_step.get_active_step_state()
        if state
           and state.frames == 0
           and state.turn_represses == 1
           and state.source == "queued_route" then
            pending = state
            break
        end
    end
    assert_truthy(pending ~= nil,
        "test setup should reach queued pending-repress state")

    env.set_joy({})
    env.set_position(4, 1)
    env.update(true)

    local completion = nil
    for i = #env.published, 1, -1 do
        local event = env.published[i]
        local payload = event.payload or {}
        if event.name == "route_step_completed"
           and payload.source == "pending_repress" then
            completion = event
            break
        end
    end
    assert_truthy(completion ~= nil,
        "position change during release gap should complete through pending-repress")
    assert_equal(completion.payload.input_source, "queued_route",
        "pending completion should preserve queued-route input source")
    return completion.frame
end

function tests.pending_repress_completion_uses_exact_marked_entry_settle()
    local env = make_env({
        config_values = {
            auto_step_turn_repress_delay = "3",
            auto_step_turn_repress_limit = "1",
        },
    })
    env.auto_step.start_route({"right", "right"}, {
        start_x = 3,
        start_y = 1,
        settle_before_steps = {[2] = 16},
    })

    local completion_frame = complete_route_step_via_pending_repress(env)
    assert_frame_neutral(env, completion_frame,
        "pending-repress completion frame")
    for offset = 1, 15 do
        env.update(true)
        assert_frame_neutral(env, completion_frame + offset,
            "pending-repress marked settle")
    end
    env.update(true)
    assert_frame_only_direction(env, completion_frame + 16, "right",
        "pending-repress fresh marked-entry press")

    env.restore()
end
```

Add drift regressions. The first proves that catch-up of the step immediately
before a marked entry installs the exact countdown:

```lua
function tests.drift_before_marked_entry_starts_exact_settle()
    local env = make_env()
    env.auto_step.start_route({"right", "right"}, {
        start_x = 3,
        start_y = 1,
        initial_settle_frames = 1,
        settle_before_steps = {[2] = 16},
    })

    env.set_position(4, 1)
    env.update(true)

    local catchup = nil
    for _, event in ipairs(env.published) do
        local payload = event.payload or {}
        if event.name == "route_step_completed"
           and payload.source == "route_settle_catchup"
           and payload.from_x == 3
           and payload.to_x == 4 then
            catchup = event
            break
        end
    end
    assert_truthy(catchup ~= nil,
        "drift should consume the step immediately before the marked entry")
    assert_frame_neutral(env, catchup.frame,
        "marked-entry drift observation")

    for offset = 1, 15 do
        env.update(true)
        assert_frame_neutral(env, catchup.frame + offset,
            "post-drift marked-entry settle")
    end
    env.update(true)
    assert_frame_only_direction(env, catchup.frame + 16, "right",
        "fresh marked press after drift settle")

    env.restore()
end
```

Add a second focused drift regression in which one observation matches at
least two old-route steps and the first catch-up completion callback installs
a replacement route. Assert that catch-up stops after that callback, emits no
completion from the replacement route, and leaves the replacement's index and
first direction intact.

Keep the existing unmarked-route timing, drift, hazard, cancellation, final
settle, and callback tests. Strengthen the unmarked two-step regression to
prove frames 2-5 remain without a direction and the second press begins on
frame 6. Delete tests whose only requirement is a continuous asserted
direction.

- [ ] **Step 2: Run the executor test and verify RED.**

Run:

```powershell
lua test_auto_step.lua
```

Expected: exit `1`; the marked route re-presses before frame 18 and the marked first step begins immediately because the new option is ignored.

- [ ] **Step 3: Add copied per-step settle state.**

Add:

```lua
local route_settle_before_steps = nil
```

Add a helper:

```lua
local function copy_settle_before_steps(entries, step_count)
    local copied = {}
    for raw_index, raw_frames in pairs(type(entries) == "table" and entries or {}) do
        local index = tonumber(raw_index)
        local frames = tonumber(raw_frames)
        if index and frames then
            index = math.floor(index)
            frames = math.floor(frames)
            if index >= 1 and index <= step_count and frames > 0 then
                copied[index] = math.min(frames, 120)
            end
        end
    end
    return next(copied) and copied or nil
end

local function settle_before_step(step_index)
    return route_settle_before_steps
        and route_settle_before_steps[step_index]
        or 0
end

local function log_entry_settle(step_index, required_frames, remaining_frames)
    local next_dir = route_steps and route_steps[step_index]
    if not next_dir or required_frames <= 0 then
        return
    end
    local _, live_x, live_y = nav.get_position()
    local from_x = route_last_x or live_x
    local from_y = route_last_y or live_y
    local dest_x, dest_y = step_destination(from_x, from_y, next_dir)
    local map_id = select(1, nav.get_position())
    debug_tools.info(string.format(
        "AUTO_STEP_ENTRY_SETTLE map=0x%02X from=(%d,%d) dest=(%d,%d) dir=%s step=%d required=%d remaining=%d",
        map_id or -1,
        from_x or -1,
        from_y or -1,
        dest_x or -1,
        dest_y or -1,
        tostring(next_dir),
        step_index or -1,
        required_frames,
        remaining_frames))
end
```

Clear `route_settle_before_steps` in `clear_route()`. In `start_route()`:

```lua
route_settle_before_steps = copy_settle_before_steps(
    opts.settle_before_steps, #route_steps)
```

Update the public option comment to:

```lua
-- opts: { settle_frames = N, settle_same_direction = true|false,
--         start_x = X, start_y = Y,
--         settle_before_steps = {[step_index] = frames} }
```

- [ ] **Step 4: Merge the entry requirement into existing settle selection.**

In `route_settle_after_step(completed_dir)`, after computing ordinary
same-direction/turn settling and before returning, count the already-neutral
completion frame as the first required frame. Return the requirement alongside
the selected settle, but do not clear release state or log yet. Update the
final-step return to provide zero requirement values:

```lua
local entry_required = settle_before_step(route_index)
local entry_remaining = math.max(0, entry_required - 1)
if entry_remaining > settle_frames then
    settle_frames = entry_remaining
end
return settle_frames, entry_required, entry_remaining
```

Add an identity helper and claim marked ownership only after the completion
callback returns:

```lua
local function route_still_matches(expected_steps, expected_index)
    return route_steps == expected_steps
        and route_index == expected_index
end

local function claim_entry_settle_after_callback(
        expected_steps, expected_index, entry_required, entry_remaining)
    entry_required = tonumber(entry_required) or 0
    if entry_required <= 0
       or not route_still_matches(expected_steps, expected_index) then
        return false
    end
    post_step_release_frames = 0
    log_entry_settle(expected_index, entry_required, entry_remaining)
    return true
end
```

In both the ordinary active-step and pending-repress completion paths, capture
the route table and next index, assign all three return values from
`route_settle_after_step()`, emit `route_step_completed`, then call
`claim_entry_settle_after_callback(...)`. The identity guard must cover every
post-callback release mutation and log. If a callback clears or replaces the
route, do not claim the old marked settle.

In `start_route()`, a marked first step has no preceding neutral completion
frame, so merge the full requirement into the initial settle:

```lua
local configured_initial_settle = math.max(
    0, tonumber(opts.initial_settle_frames) or 0)
local first_step_settle = settle_before_step(1)
route_settle_frames = math.max(configured_initial_settle, first_step_settle)
if first_step_settle > 0 then
    -- A completion callback may requeue this marked route after already
    -- scheduling forced release for the prior route.
    post_step_release_frames = 0
    log_entry_settle(1, first_step_settle, first_step_settle)
end
```

Route drift bypasses both normal completion paths. In each
`consume_route_drift()` caller, capture the expected route table and starting
index before catch-up. When callbacks leave that same route at exactly
`start_index + consumed`, and the new next step is marked:

- use the last consumed old-route direction to recompute ordinary plus entry
  settling;
- count the already-neutral drift observation as the first physical frame;
- explicitly neutralize the observation frame in the no-settle/cooldown
  caller;
- clear redundant release, log the marked settle, and leave
  `handle_route_progress()` as the only countdown.

When the next step is unmarked, retain the existing default-settle behavior.
When a callback changed the route, mutate nothing and do not overwrite its
new initial settle.

Use one shared helper so both callers apply identical identity and entry
logic:

```lua
local function install_entry_settle_after_drift(
        expected_steps, start_index, consumed)
    local expected_index = start_index + consumed
    if consumed <= 0
       or not route_still_matches(expected_steps, expected_index) then
        return false, false
    end

    local entry_required = settle_before_step(route_index)
    if entry_required <= 0 then
        return false, true
    end

    local completed_dir = expected_steps[route_index - 1]
    local settle_frames, required, remaining =
        route_settle_after_step(completed_dir)
    route_settle_frames = settle_frames
    post_step_release_frames = 0
    log_entry_settle(route_index, required, remaining)
    return true, true
end
```

The two returns mean `marked_settle_installed, same_route`. Only execute the
caller's old default-settle reset when `same_route` is true and no marked
settle was installed. In the no-settle/cooldown caller, explicitly call
`neutralize_direction(joy)` when the helper installs a marked settle.

Inside `consume_route_drift()`, use the captured old route table/index for
each matched step and check `route_still_matches(...)` after every
`emit_step_complete()`. Stop catch-up immediately when a callback changed the
route, preventing later iterations from reading or advancing replacement
route state.

The existing `handle_route_progress` branch must remain the only countdown:
it neutralizes, checks interruption/drift, decrements
`route_settle_frames`, and begins the queued step after the full countdown.
Do not reorder the general pending-release handler or change unmarked timing.

- [ ] **Step 5: Remove the disproven continuous-hold implementation.**

First extract the generic behavior currently hidden inside
`continuous_hold.build_step_opts()` and `continuous_hold.begin_next_step()`:

```lua
local function build_route_step_opts(step_index, next_dir)
    local step_opts = {source = "queued_route"}
    if queued_route_continuing_step_before_turn(next_dir) then
        step_opts.inject_limit = get_route_pre_turn_inject_limit()
    end
    if route_hold_after_movement_start_frames_override ~= nil then
        step_opts.hold_after_movement_start = true
        step_opts.hold_after_movement_start_frames =
            route_hold_after_movement_start_frames_override
    end
    return step_opts
end

local function begin_next_route_step(px, py)
    local step_index = route_index
    local next_dir = route_steps and route_steps[step_index]
    if not next_dir then
        return false, "route_end", nil
    end
    if refuse_hazard_step(next_dir, px, py, "queued_route") then
        return false, "hazard_refused", next_dir
    end
    route_index = step_index + 1
    begin_step(next_dir, px, py, build_route_step_opts(step_index, next_dir))
    return true, nil, next_dir
end
```

Replace the generic route-progress call with `begin_next_route_step(px, py)`.
Then delete:

- `continuous_hold.active` and `.markers`;
- marker copying and run logging helpers;
- same-frame marked continuation;
- continuous-hold fields in pending-repress state;
- `continuous_hold_after_steps` option handling.

Restore all steps to the ordinary completion branch so every crossed tile
neutralizes before the next step unless `route_settle_frames` controls the
delay.

- [ ] **Step 6: Run focused executor tests and verify GREEN.**

Run:

```powershell
lua test_auto_step.lua
luac -p auto_step.lua test_auto_step.lua
git diff --check
```

Expected: all auto-step tests pass, bytecode parsing passes, and whitespace check exits `0`.

- [ ] **Step 7: Commit Task 2.**

```powershell
git add auto_step.lua test_auto_step.lua
git commit -m "fix: settle before Rimuldar seam re-press"
```

---

### Task 3: Static integration verification and review

**Files:**
- Verify: `map_reader.lua`
- Verify: `route_manager.lua`
- Verify: `auto_step.lua`
- Verify: `test_map_reader.lua`
- Verify: `test_route_manager.lua`
- Verify: `test_auto_step.lua`

**Interfaces:**
- Confirms the metadata-to-planner-to-executor chain.
- Confirms the previous arrival helper remains intact.

- [ ] **Step 1: Run focused suites.**

```powershell
lua test_map_reader.lua
lua test_auto_step.lua
lua test_route_manager.lua
lua test_pathfinder.lua
lua test_objects.lua
```

Expected: every suite exits `0`.

- [ ] **Step 2: Run the repository Lua test runner.**

```powershell
python run_tests.py --allow-missing-speech-dep
```

If the runner cannot find Lua because the desktop child PATH is sanitized,
prepend the verified Lua directory only for this process and rerun the same
runner. Expected: all repository checks pass.

- [ ] **Step 3: Run syntax and repository checks.**

```powershell
luac -p main.lua map_reader.lua route_manager.lua auto_step.lua test_map_reader.lua test_route_manager.lua test_auto_step.lua
git diff --check
git status --short
```

Expected: syntax and whitespace checks exit `0`; status contains only intentional changes, if any.

- [ ] **Step 4: Request code review and resolve every important finding through a fresh RED/GREEN cycle.**

Review scope:

- Only `(0,0).east` on map `0x0B` returns 16.
- Only the matching path step receives settle metadata.
- The marked same-direction step cannot start before the countdown expires.
- Existing cancellation, drift, hazard, and arrival paths remain unchanged.
- No continuous-hold behavior remains.

---

### Task 4: Live acceptance and durable documentation

**Files:**
- Modify after successful live proof: `work_notes/current_investigation.md`
- Modify after successful live proof: `session_handoff.md`
- Modify after successful live proof: `PLAYTESTING.md`
- Modify after successful live proof: `PROJECT_MEMORY.md`
- Modify if final wording changes: `docs/superpowers/specs/2026-07-15-rimuldar-magic-key-route-design.md`

**Interfaces:**
- Consumes the source-only route implementation after a manual FCEUX Lua reload.
- Produces one verified entry-to-merchant route result and durable project state.

- [ ] **Step 1: Ask the user to reload `main.lua`.**

Do not queue movement until a fresh marker is consumed.

- [ ] **Step 2: Verify the fresh runtime baseline.**

```powershell
.\dw_commands.ps1 --replace --wait-ready rimuldar_settled_repress launcher_probe:rimuldar_settled_repress report_position report_runtime_blocks report_path_state
```

Required baseline:

- map `0x0B`;
- normal Rimuldar entry `(29,14)`;
- `RUNTIME_BLOCKS map=0x0B none`;
- no active route.

If the player is elsewhere, restore the entry through ordinary movement and
report the resulting position before acceptance.

- [ ] **Step 3: Select the Magic Key Merchant and queue exactly one autowalk.**

Use short filter/object commands until:

```text
OBJECT: Magic Key Merchant ... [player 29,14 obj 4,7 interact 4,5]
```

Then queue:

```powershell
.\dw_commands.ps1 --replace --wait "AUTO_WALK: queued 52 step(s) for Magic Key Merchant" --timeout 20 freeze_npcs auto_walk
```

- [ ] **Step 4: Verify the cadence and arrival logs.**

Required evidence:

```text
AUTO_WALK_ENTRY_SETTLE map=0x0B from=(1,0) dest=(0,0) dir=left step=43 frames=16
AUTO_STEP_ENTRY_SETTLE map=0x0B from=(1,0) dest=(0,0) dir=left step=43 required=16 remaining=15
auto_step complete dir=left from=(1,0) to=(0,0)
POSITION: map=0x0B(Rimuldar) x=4 y=5
NPC freeze released: autowalk route complete
AUTO_WALK_FACE target=Magic Key Merchant face=south dir=down
RUNTIME_BLOCKS map=0x0B none
```

There must be no World Map transition, route-blocked result, seam retry, or
runtime blocker for `(0,0)`.

- [ ] **Step 5: Verify TALK opens the shop.**

Send one normal TALK action and confirm the `53 GOLD` Magic Key purchase
prompt. Cancel cleanly if no purchase is intended.

- [ ] **Step 6: Update durable docs only after acceptance succeeds.**

Record:

- the 52-step normal-entry route;
- the 16-frame settled re-press at `(1,0)`;
- successful `(0,0)` crossing without a seam retry;
- standard arrival at `(4,5)` facing south;
- the 53 G prompt;
- no runtime blocks.

Remove or supersede statements that call the route a continuous hold.

- [ ] **Step 7: Run final verification and commit docs.**

```powershell
lua test_map_reader.lua
lua test_auto_step.lua
lua test_route_manager.lua
lua test_pathfinder.lua
lua test_objects.lua
luac -p main.lua map_reader.lua route_manager.lua auto_step.lua test_map_reader.lua test_route_manager.lua test_auto_step.lua
git diff --check
git status --short
git add work_notes/current_investigation.md session_handoff.md PLAYTESTING.md PROJECT_MEMORY.md docs/superpowers/specs/2026-07-15-rimuldar-magic-key-route-design.md
git commit -m "docs: record verified Rimuldar settled route"
```

Expected: all checks pass and the documentation commit succeeds.

## Acceptance Criteria

- `get_entry_settle_frames(0x0B, 0, 0, "east") == 16`; unrelated queries return `0`.
- The 52-step path marks only step 43 with `settle_before_steps[43] == 16`.
- Auto-step keeps the route queued through exactly 16 physical neutral frames before the fresh LEFT press: the completion frame plus 15 remaining frames, or all 16 frames when the marked entry is step 1.
- Marked settling owns the first follow-up frame after both active-step and pending-repress completion only while the same route/index remains; callback-cleared or unmarked replacement routes retain ordinary forced release, while a callback-requeued marked step 1 owns its initial settle.
- Drift catch-up that exposes a marked entry installs the same exact remaining settle, and callback mutation stops old-route catch-up before it can alter replacement state.
- An equivalent unmarked two-step route retains its existing frame-6 second press.
- Continuous-hold metadata and executor behavior are removed.
- One source-only autowalk reaches `(4,5)` from `(29,14)` without a seam retry, World Map transition, or runtime block.
- Arrival faces south once and TALK opens the 53 G Magic Key prompt.
- Focused tests, full tests, syntax checks, review, and documentation agree.
