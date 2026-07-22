# Queued-Route Early-Twitch Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make queued routes recover safely from a false early movement twitch when the current step turns immediately afterward or is the route's final step.

**Architecture:** `auto_step.lua` will recognize the unsafe-to-hold early-twitch shape and convert the already-issued press into a guarded cadence pulse. It will reuse `pending_repress` and the entry-waveform controller ownership: wait through the configured route-turn settle, accept coordinate completion during that wait, otherwise issue one bounded fresh press.

**Tech Stack:** Lua 5.1-compatible source, local Lua test harness, FCEUX command queue, `dw_debug.log`.

## Global Constraints

- Apply recovery generically to queued routes, including overworld and local routes.
- Preserve the existing straight-route early-twitch cadence path.
- Do not alter overworld waypoint data, permanent map passability, or manual-tap behavior.
- Do not reset Dragon Warrior movement RAM at every route boundary.
- Check the live coordinate before the fresh press so late completion cannot cause an extra step.
- Keep recovery bounded by existing retry and timeout controls.
- Preserve timing-suspect block classification when recovery fails.
- Write and run each regression before changing production code.
- FCEUX requires one manual Lua reload after the source change.

---

### Task 1: Add guarded queued-route twitch recovery

**Files:**
- Modify: `test_auto_step.lua:1335-1530`
- Modify: `auto_step.lua:348-450,911-1000,1635-1685`

**Interfaces:**
- Consumes: `route_steps`, `route_index`, `auto_dir`, `auto_movement_start_frame`, `get_route_early_release_grace_frames()`, `get_route_turn_settle_frames()`, and the existing `pending_repress` entry-waveform state.
- Produces: `queued_route_needs_guarded_twitch_repress() -> boolean`.
- Produces: `schedule_guarded_route_twitch_repress() -> boolean`.
- Produces log: `AUTO_STEP_GUARDED_TWITCH_REPRESS from=(X,Y) dir=DIR step=N settle=N`.

- [ ] **Step 1: Replace the obsolete no-repress regression with failing recovery regressions.**

Replace `queued_route_early_subpixel_twitch_releases_before_turn` with:

```lua
function tests.queued_route_pre_turn_early_twitch_uses_guarded_fresh_press()
    local env = make_env({
        sticky_joypad_set = true,
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_route_early_release_grace_frames = "10",
            auto_step_route_turn_settle_frames = "2",
            auto_step_inject_limit = "3",
        },
    })
    env.auto_step.start_route({"right", "down"})
    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)
    assert_truthy(env.injected[2] and not has_any_direction(env.injected[2]),
        "pre-turn twitch recovery should release the probe pulse")
    env.update(true)
    env.update(true)
    env.update(true)
    assert_equal(#collect_direction_sequences(env, "right", 5), 2,
        "pre-turn twitch recovery should issue one guarded fresh press")
    env.set_position(4, 1)
    env.update(true)
    local completed = false
    for _, event in ipairs(env.published) do
        local payload = event.payload or {}
        if event.name == "route_step_completed"
           and payload.from_x == 3 and payload.from_y == 1
           and payload.to_x == 4 and payload.to_y == 1
           and payload.dir == "right" then
            completed = true
        end
        assert_truthy(event.name ~= "route_blocked",
            "guarded pre-turn recovery should not publish a false block")
    end
    assert_truthy(completed,
        "guarded pre-turn recovery should complete the current route step")
    env.restore()
end
```

Add these tests directly after it:

```lua
function tests.queued_route_final_early_twitch_uses_guarded_fresh_press()
    local env = make_env({
        sticky_joypad_set = true,
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_route_early_release_grace_frames = "10",
            auto_step_route_turn_settle_frames = "2",
            auto_step_inject_limit = "3",
        },
    })
    env.auto_step.start_route({"right"})
    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)
    env.update(true)
    env.update(true)
    env.update(true)
    assert_equal(#collect_direction_sequences(env, "right", 5), 2,
        "final-step twitch recovery should issue one guarded fresh press")
    env.set_position(4, 1)
    env.update(true)
    for _, event in ipairs(env.published) do
        assert_truthy(event.name ~= "route_blocked",
            "guarded final-step recovery should not publish a false block")
    end
    env.restore()
end

function tests.guarded_twitch_repress_skips_fresh_press_after_late_completion()
    local env = make_env({
        sticky_joypad_set = true,
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_route_early_release_grace_frames = "10",
            auto_step_route_turn_settle_frames = "2",
        },
    })
    env.auto_step.start_route({"right", "down"})
    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)
    env.set_position(4, 1)
    env.update(true)
    assert_equal(#collect_direction_sequences(env, "right", 8), 1,
        "late completion during guarded settle must suppress the fresh press")
    env.restore()
end

function tests.guarded_twitch_repress_cancels_wrong_direction_drift()
    local env = make_env({
        sticky_joypad_set = true,
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_route_early_release_grace_frames = "10",
            auto_step_route_turn_settle_frames = "2",
        },
    })
    env.auto_step.start_route({"right", "down"})
    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)
    env.set_position(3, 2)
    env.update(true)
    local cancelled = nil
    for _, event in ipairs(env.published) do
        if event.name == "route_cancelled" then cancelled = event.payload end
    end
    assert_equal(cancelled and cancelled.reason, "route_drift_off_path",
        "wrong-direction guarded movement should cancel as route drift")
    assert_equal(cancelled and cancelled.source, "pending_repress_mismatch",
        "wrong-direction guarded movement should use pending-repress drift handling")
    env.restore()
end

function tests.guarded_twitch_repress_failure_remains_bounded_timing_suspect()
    local env = make_env({
        sticky_joypad_set = true,
        config_values = {
            auto_step_release_on_movement_start = "true",
            auto_step_timeout = "60",
            auto_step_block_retry_limit = "0",
            auto_step_route_early_release_grace_frames = "10",
            auto_step_route_turn_repress_timeout_frames = "12",
            auto_step_route_turn_settle_frames = "2",
            auto_step_inject_limit = "3",
        },
    })
    env.auto_step.start_route({"right", "down"})
    env.update(true)
    env.set_subpixel(0x20)
    env.update(true)
    env.update(true)
    env.update(true)
    env.update(true)
    env.set_subpixel(0x30)
    env.update(true)
    for _ = 1, 30 do env.update(true) end
    local blocked = nil
    for _, event in ipairs(env.published) do
        if event.name == "route_blocked" then blocked = event.payload end
    end
    assert_truthy(blocked ~= nil,
        "unmoving guarded recovery should remain bounded")
    assert_equal(blocked and blocked.timing_suspect, true,
        "failed guarded recovery should retain timing-suspect classification")
    env.restore()
end
```

The existing `queued_route_early_subpixel_twitch_keeps_hold_active` regression
remains the straight-route compatibility check.

- [ ] **Step 2: Run the focused suite and verify RED.**

Run `lua test_auto_step.lua`.

Expected: the new immediate-turn and final-step tests fail because only one
`right` press sequence exists; the existing suite otherwise runs normally.

- [ ] **Step 3: Add the guarded-recovery predicate and scheduler.**

Add this predicate immediately after `should_hold_after_movement_start()`:

```lua
local function queued_route_needs_guarded_twitch_repress()
    return route_steps ~= nil
        and auto_dir ~= nil
        and auto_step_source ~= "manual_tap"
        and auto_movement_started
        and auto_movement_start_frame ~= nil
        and auto_movement_start_frame <= get_route_early_release_grace_frames()
        and not should_hold_after_movement_start()
        and route_steps[route_index] ~= auto_dir
end
```

Add this scheduler immediately after `schedule_entry_prime_retry()`:

```lua
local function schedule_guarded_route_twitch_repress()
    if not queued_route_needs_guarded_twitch_repress() then
        return false
    end
    local settle_frames = get_route_turn_settle_frames()
    local recovery = {
        dir = auto_dir,
        timeout_retries = auto_timeout_retries,
        turn_represses = auto_turn_represses + 1,
        inject_limit = math.max(
            tonumber(auto_inject_limit) or 0,
            tonumber(get_inject_limit()) or INJECT_LIMIT),
        release_frames = settle_frames,
        start_x = auto_start_x,
        start_y = auto_start_y,
        source = auto_step_source or "queued_route",
        release_after_inject_limit = false,
        hold_after_movement_start = false,
        entry_prime_waveform = true,
        entry_prime_pending = false,
        entry_prime_frames = 1,
        entry_prime_remaining = 0,
        entry_prime_settle_frames = settle_frames,
        entry_prime_echo_grace_frames = 0,
        entry_step_index = route_index - 1,
    }
    clear_active_attempt_state()
    pending_repress = recovery
    route_settle_frames = 0
    route_final_settle_active = false
    route_settle_reset_movement_active = false
    debug_tools.info(string.format(
        "AUTO_STEP_GUARDED_TWITCH_REPRESS from=(%d,%d) dir=%s step=%s settle=%d",
        recovery.start_x or -1,
        recovery.start_y or -1,
        tostring(recovery.dir),
        tostring(recovery.entry_step_index or "-"),
        settle_frames))
    return true
end
```

In the movement-start branch, insert this clause immediately before the
existing `elseif should_hold_after_movement_start()` clause:

```lua
        elseif schedule_guarded_route_twitch_repress() then
            neutralize_direction(joy, "neutral")
```

- [ ] **Step 4: Run the focused suite and verify GREEN.**

Run `lua test_auto_step.lua`.

Expected: all auto-step tests pass, including the five new guarded-recovery
tests and the existing straight-route cadence regressions.

- [ ] **Step 5: Run syntax and route integration checks.**

Run:

```powershell
luac -p auto_step.lua test_auto_step.lua route_manager.lua overworld_routes.lua
lua test_route_manager.lua
lua test_overworld_routes.lua
git diff --check
```

Expected: every command exits zero, both route suites report all tests passing,
and `git diff --check` prints no whitespace errors.

- [ ] **Step 6: Commit the executor regression and fix.**

```powershell
git add auto_step.lua test_auto_step.lua
git commit -m "fix: recover queued route movement twitches"
```

---

### Task 2: Verify the fix live and resume route validation

**Files:**
- Modify: `work_notes/current_investigation.md` with live findings.
- Modify only after a material route-status change: `session_handoff.md`, `PLAYTESTING.md`.

**Interfaces:**
- Consumes command queue: `report_position`, `route_status`, `auto_walk`, and `report_runtime_blocks`.
- Consumes log evidence: `AUTO_STEP_GUARDED_TWITCH_REPRESS`, `OVERWORLD_AUTO_WALK`, `POSITION`, and `EDGE_PROBE_RESULT`.
- Produces: log-backed live verdict for Hauksness waypoint 30 and later route segments.

- [ ] **Step 1: Ask the user to reload `main.lua` in FCEUX.**

Wait for explicit confirmation because FCEUX cannot hot-reload Lua source.

- [ ] **Step 2: Establish a fresh live baseline.**

Run:

```powershell
.\dw_commands.ps1 --replace launcher_probe:queued_twitch_fix report_position route_status report_runtime_blocks
```

Expected: the probe is consumed, the player remains on World Map near the
Garinham ridge, the Hauksness route remains active, and no new runtime blocker
exists for the previously probed passable edges.

- [ ] **Step 3: Re-run normal overworld auto-walk through waypoint 30.**

Run `.\dw_commands.ps1 --replace auto_walk`.

Expected log sequence: `AUTO_STEP_GUARDED_TWITCH_REPRESS` if the false twitch
recurs, followed by `route_step_completed` and
`OVERWORLD_AUTO_WALK: event=complete`, rather than `event=blocked` at
`(19,7)->UP` or `(19,5)->DOWN`.

- [ ] **Step 4: Continue Hauksness and Cantlin validation in short segments.**

After each combat-clear confirmation, queue one `auto_walk`, wait for
`OVERWORLD_AUTO_WALK`, and record exact segment endpoints and any reproduced
failure. Use `probe_edge` only for a same-origin movement failure; do not promote
map data from a timing-suspect executor event.

- [ ] **Step 5: Update project state only when warranted.**

Record executor verification and route progress in
`work_notes/current_investigation.md`. Update `session_handoff.md` and
`PLAYTESTING.md` only if Hauksness or Cantlin reaches a new durable validation
state or a new unresolved blocker changes next-step guidance.
