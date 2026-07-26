# Overworld Cross-Waypoint Turn Timing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reuse the existing pre-turn injection window when exact carry metadata proves that a queued overworld segment ends immediately before a perpendicular cross-waypoint turn.

**Architecture:** `auto_step.lua` will interpret the already-forwarded exact carry pair only as timing lookahead for the final queued step. It will preserve the existing within-segment rule, exact final-carry acceptance, and conservative fallback behavior. `test_auto_step.lua` will verify controller output for perpendicular, straight, missing, and malformed lookahead.

**Tech Stack:** Lua 5.1/LuaJIT, the repository's table-driven Lua test harness, FCEUX 2.6.6, WSL, and the existing Python repository test runner.

## Global Constraints

- Do not modify `overworld_routes.lua`, `route_manager.lua`, map data, waypoint
  coordinates, or `dw_access.ini`.
- Keep `auto_step_inject_limit=12` and
  `auto_step_route_pre_turn_inject_limit=10`.
- Do not write `$003C`, `$003D`, or other movement/player-stat RAM.
- Preserve exact final-carry acceptance and `route_drift_off_path`
  cancellation.
- Preserve manual taps, probes, map crawling, interior routes, marked entry
  waveforms, hazards, and live-input interruption.
- Missing, incomplete, diagonal, reverse, or multi-cell carry lookahead must
  retain ordinary timing.
- Do not address guarded-twitch false blocks in this patch.
- Preserve unrelated worktree content. Do not stage
  `work_notes/hauksness_stat_corruption_20260724.log`.

## File Structure

- Modify `test_auto_step.lua`: add controller-output regressions for the
  cross-waypoint timing decision.
- Modify `auto_step.lua`: infer a perpendicular next direction from the exact
  final-carry pair and reuse the existing pre-turn injection limit.
- Read only for verification: `test_route_manager.lua`,
  `test_overworld_routes.lua`, and `run_tests.py`.

---

### Task 1: Make final-step timing aware of a perpendicular exact carry

**Files:**
- Modify: `test_auto_step.lua:1574-1600`
- Modify: `auto_step.lua:344-363`
- Modify: `auto_step.lua:678-692`
- Modify: `auto_step.lua:850-860`
- Modify: `auto_step.lua:974-986`

**Interfaces:**
- Consumes: paired `route_final_carry_x_override` and
  `route_final_carry_y_override` values established by
  `auto_step.start_route()`.
- Produces: private
  `queued_route_step_before_turn(step_index, dir, start_x, start_y) -> boolean`.
- Preserves: `build_route_step_opts(step_index, dir, start_x, start_y) -> table`
  and every public `auto_step` interface.

- [ ] **Step 1: Add the failing perpendicular-carry regression**

Add after
`queued_route_uses_shorter_inject_on_continuing_step_before_turn`:

```lua
function tests.queued_route_final_step_uses_pre_turn_limit_for_perpendicular_carry()
    local env = make_env({
        config_values = {
            auto_step_inject_limit = "12",
            auto_step_route_pre_turn_inject_limit = "10",
        },
    })
    env.auto_step.start_route({"right"}, {
        route_final_carry_x = 4,
        route_final_carry_y = 2,
    })

    for _ = 1, 12 do
        env.update(true)
    end

    assert_frame_only_direction(
        env, 11, "right",
        "cross-waypoint pre-turn step final owned frame")
    assert_frame_neutral(
        env, 12,
        "cross-waypoint pre-turn step release")

    env.restore()
end
```

The fixture starts at `(3,1)`. Its queued step ends at `(4,1)`, and the exact
carry target `(4,2)` proves that the next route direction is down.

- [ ] **Step 2: Add conservative control cases before production code**

Add:

```lua
function tests.queued_route_final_step_keeps_normal_limit_without_perpendicular_carry()
    local cases = {
        {
            name = "straight",
            opts = {route_final_carry_x = 5, route_final_carry_y = 1},
        },
        {
            name = "incomplete",
            opts = {route_final_carry_x = 4},
        },
        {
            name = "diagonal",
            opts = {route_final_carry_x = 5, route_final_carry_y = 2},
        },
        {
            name = "reverse",
            opts = {route_final_carry_x = 3, route_final_carry_y = 1},
        },
        {
            name = "multi-cell",
            opts = {route_final_carry_x = 4, route_final_carry_y = 3},
        },
    }

    for _, case in ipairs(cases) do
        local env = make_env({
            config_values = {
                auto_step_inject_limit = "12",
                auto_step_route_pre_turn_inject_limit = "10",
            },
        })
        env.auto_step.start_route({"right"}, case.opts)

        for _ = 1, 12 do
            env.update(true)
        end

        assert_frame_only_direction(
            env, 12, "right",
            case.name .. " final carry timing")
        env.restore()
    end
end
```

- [ ] **Step 3: Run the auto-step suite and verify RED**

Run from WSL:

```powershell
wsl.exe -e bash -lc "cd /mnt/d/modding/DragonWarrior1 && lua test_auto_step.lua"
```

Expected: the new perpendicular test fails because frame 12 still contains
RIGHT. The new conservative cases and the prior 140 tests pass.

- [ ] **Step 4: Move the existing direction delta helper before turn analysis**

Move the unchanged `direction_delta(dir)` definition from below
`begin_step()` to immediately before the queued-route turn helpers:

```lua
local function direction_delta(dir)
    if dir == "up" then
        return 0, -1
    elseif dir == "down" then
        return 0, 1
    elseif dir == "left" then
        return -1, 0
    elseif dir == "right" then
        return 1, 0
    end
    return 0, 0
end
```

Do not retain a second copy.

- [ ] **Step 5: Add exact cardinal and perpendicular helpers**

Immediately after `direction_delta(dir)`, add:

```lua
local function cardinal_direction_between(from_x, from_y, to_x, to_y)
    if from_x == nil or from_y == nil or to_x == nil or to_y == nil then
        return nil
    end
    local dx = to_x - from_x
    local dy = to_y - from_y
    if dx == 0 and dy == -1 then
        return "up"
    elseif dx == 0 and dy == 1 then
        return "down"
    elseif dx == -1 and dy == 0 then
        return "left"
    elseif dx == 1 and dy == 0 then
        return "right"
    end
    return nil
end

local function directions_are_perpendicular(first, second)
    local first_vertical = first == "up" or first == "down"
    local first_horizontal = first == "left" or first == "right"
    local second_vertical = second == "up" or second == "down"
    local second_horizontal = second == "left" or second == "right"
    return (first_vertical and second_horizontal)
        or (first_horizontal and second_vertical)
end
```

- [ ] **Step 6: Generalize the private pre-turn decision**

Replace `queued_route_continuing_step_before_turn(next_dir)` with:

```lua
local function queued_route_step_before_turn(
        step_index, current_dir, start_x, start_y)
    if route_steps == nil
       or step_index == nil
       or current_dir == nil then
        return false
    end

    local previous_dir = route_steps[step_index - 1]
    local following_dir = route_steps[step_index + 1]
    if following_dir ~= nil then
        return previous_dir == current_dir
            and following_dir ~= current_dir
    end
    if step_index ~= #route_steps then
        return false
    end

    local dx, dy = direction_delta(current_dir)
    local endpoint_x = start_x and start_x + dx or nil
    local endpoint_y = start_y and start_y + dy or nil
    local carry_dir = cardinal_direction_between(
        endpoint_x,
        endpoint_y,
        route_final_carry_x_override,
        route_final_carry_y_override)
    return directions_are_perpendicular(current_dir, carry_dir)
end
```

This preserves the prior within-segment requirement that the step before a
turn continues an existing same-direction run. The new final-step branch
requires paired, exact, one-cardinal-cell carry metadata and a perpendicular
direction.

- [ ] **Step 7: Pass the live step origin into the timing decision**

Change:

```lua
local function build_route_step_opts(step_index, next_dir)
```

to:

```lua
local function build_route_step_opts(step_index, next_dir, start_x, start_y)
```

and replace its pre-turn condition with:

```lua
    if queued_route_step_before_turn(
            step_index, next_dir, start_x, start_y) then
        step_opts.inject_limit = get_route_pre_turn_inject_limit()
    end
```

In `begin_next_route_step(px, py)`, call:

```lua
    local step_opts = build_route_step_opts(
        step_index, next_dir, px, py)
```

Leave `arm_entry_prime()` unchanged; it may omit the optional origin because
its marked waveform intentionally restores the normal committed-input window.

- [ ] **Step 8: Run the focused suite and verify GREEN**

Run:

```powershell
wsl.exe -e bash -lc "cd /mnt/d/modding/DragonWarrior1 && lua test_auto_step.lua"
```

Expected: all 142 tests pass. The new perpendicular case releases at frame 12,
while straight and malformed cases still inject RIGHT on frame 12.

- [ ] **Step 9: Inspect the focused diff**

Run:

```powershell
git diff --check
git diff -- auto_step.lua test_auto_step.lua
```

Expected: only the private timing decision, helper relocation, focused tests,
and necessary call-site arguments changed.

---

### Task 2: Verify and commit the implementation

**Files:**
- Verify: `auto_step.lua`
- Verify: `test_auto_step.lua`
- Read-only adjacent suites: `test_route_manager.lua`,
  `test_overworld_routes.lua`

**Interfaces:**
- Consumes from Task 1:
  `queued_route_step_before_turn(step_index, dir, start_x, start_y)`.
- Produces: a reviewable implementation commit on
  `codex/cantlin-hauksness-return`.

- [ ] **Step 1: Run focused and adjacent Lua suites**

Run:

```powershell
wsl.exe -e bash -lc "cd /mnt/d/modding/DragonWarrior1 && lua test_auto_step.lua && lua test_route_manager.lua && lua test_overworld_routes.lua"
```

Expected: 142 auto-step, 113 route-manager, and 127 overworld-route tests pass.

- [ ] **Step 2: Run Lua syntax checks independently**

Run:

```powershell
wsl.exe -e bash -lc "cd /mnt/d/modding/DragonWarrior1 && luac -p auto_step.lua"
wsl.exe -e bash -lc "cd /mnt/d/modding/DragonWarrior1 && luac -p test_auto_step.lua"
```

Expected: both commands exit successfully without output.

- [ ] **Step 3: Run repository verification**

Run:

```powershell
git diff --check
wsl.exe -e bash -lc "cd /mnt/d/modding/DragonWarrior1 && python3 run_tests.py --allow-missing-speech-dep"
```

Expected: all code and configuration checks pass. The known optional
`accessible_output2` dependency may remain the only nonzero diagnostic, and
the Windows-only speech bridge may emit its known non-failing `cmd: not found`
message under WSL.

- [ ] **Step 4: Stage only the implementation and focused tests**

Run:

```powershell
git add -- auto_step.lua test_auto_step.lua
git diff --cached --check
git diff --cached --stat
git status --short
```

Expected: only `auto_step.lua` and `test_auto_step.lua` are staged.
`work_notes/hauksness_stat_corruption_20260724.log` remains untracked.

- [ ] **Step 5: Commit the verified implementation**

Run:

```powershell
git commit -m "fix: shorten cross-waypoint turn input"
```

Expected: one implementation commit containing only production timing logic
and its deterministic regressions.

- [ ] **Step 6: Pause for manual FCEUX reload**

Tell the user:

```text
The source and automated verification are ready. Please restart main.lua in
FCEUX, then tell me when it is reloaded. I will fresh-probe the current state
before starting live route validation.
```

Do not update `PLAYTESTING.md` or `session_handoff.md`, push, or claim live
success until the reloaded source has been exercised and a fresh trace is
preserved.
