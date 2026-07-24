# Safe Initial Route Settle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent route initial-settle waits from writing movement RAM when movement resetting is disabled.

**Architecture:** Keep route timing and drift recovery unchanged. Gate the existing immediate and repeated initial-settle movement resets through `should_reset_movement_on_route_turn_settle()`, using the existing default-false configuration contract.

**Tech Stack:** Lua 5.1/LuaJIT, FCEUX Lua runtime, repository Lua unit-test harness.

## Global Constraints

- `auto_step_reset_movement_on_route_turn_settle=false` must wait with neutral input without writing `$003C/$003D`.
- An explicit `true` must preserve the experimental reset behavior.
- Do not change initial-settle duration, route planning, drift detection, NPC parking, Axe Knight coordinates, final-settle carry handling, or the separate Axe Knight overshoot.
- Add no configuration option and no production helper.
- Preserve all unrelated dirty worktree changes.

---

## File Structure

- Modify `test_auto_step.lua`: add disabled-setting regression and make the existing reset test explicitly opt in.
- Modify `auto_step.lua`: gate initial-settle movement resets with the existing reset policy.
- Update `work_notes/current_investigation.md` only after live validation changes the finding from pending to verified.

### Task 1: Lock the Configuration Contract With a Failing Test

**Files:**
- Modify: `test_auto_step.lua`
- Test: `test_auto_step.lua`

**Interfaces:**
- Consumes: `auto_step.start_route(steps, opts)` and the existing test harness `env.memory_writes`.
- Produces: regression coverage for disabled and enabled initial-settle resets.

- [ ] **Step 1: Add the disabled-setting regression**

Place this test immediately before the existing initial-settle reset test:

```lua
function tests.queued_route_initial_settle_preserves_movement_state_when_reset_disabled()
    local env = make_env({
        movement_state = 0x05,
        movement_subpixel = 0x20,
        config_values = {
            auto_step_reset_movement_on_route_turn_settle = "false",
        },
    })

    env.auto_step.start_route({"left"}, {initial_settle_frames = 16})

    assert_equal(#env.memory_writes, 0,
        "disabled initial-settle reset should not write movement RAM")

    env.restore()
end
```

- [ ] **Step 2: Make the existing reset test explicitly opt in**

Rename the existing test to
`queued_route_initial_settle_clears_movement_carry_when_reset_enabled` and add:

```lua
config_values = {
    auto_step_reset_movement_on_route_turn_settle = "true",
},
```

Keep its four existing address/value assertions unchanged.

- [ ] **Step 3: Run the auto-step suite and verify RED**

Run:

```powershell
luajit test_auto_step.lua
```

Expected: exit 1. The new disabled-setting test fails with an assertion equivalent to:

```text
disabled initial-settle reset should not write movement RAM: expected 0, got 2
```

The existing 135-test baseline otherwise remains intact.

### Task 2: Gate Initial-Settle Movement Writes

**Files:**
- Modify: `auto_step.lua`
- Test: `test_auto_step.lua`

**Interfaces:**
- Consumes: existing `should_reset_movement_on_route_turn_settle()` policy.
- Produces: unchanged settle timing with conditional `$003C/$003D` writes.

- [ ] **Step 1: Apply the minimal production gate**

Replace the unconditional initial-settle reset block in
`auto_step.start_route()` with:

```lua
if route_settle_frames > 0 then
    route_settle_reset_movement_active =
        should_reset_movement_on_route_turn_settle()
    if route_settle_reset_movement_active then
        reset_movement_engine_state("queued_route_initial_settle", {log = false})
    end
    debug_tools.debug(string.format(
        "auto_step route initial settle frames=%d steps=%d start=(%d,%d)",
        route_settle_frames,
        #route_steps,
        route_last_x or -1,
        route_last_y or -1))
end
```

Do not alter `route_settle_frames`, `reset_movement_for_route_settle()`, or
route-manager reroute options.

- [ ] **Step 2: Run the auto-step suite and verify GREEN**

Run:

```powershell
luajit test_auto_step.lua
```

Expected: exit 0 and `Ran 136 Lua unit tests`.

### Task 3: Verify and Commit the Focused Patch

**Files:**
- Modify: `auto_step.lua`
- Modify: `test_auto_step.lua`

**Interfaces:**
- Consumes: completed Task 2 source and regression.
- Produces: locally verified, reviewable commit containing only the safety fix.

- [ ] **Step 1: Byte-compile the changed Lua files**

Run:

```powershell
luajit -b auto_step.lua NUL
luajit -b test_auto_step.lua NUL
```

Expected: both commands exit 0 with no output.

- [ ] **Step 2: Run the adjacent route-manager suite**

Run:

```powershell
luajit test_route_manager.lua
```

Expected: exit 0 and `Ran 112 Lua unit tests`.

- [ ] **Step 3: Check formatting and patch scope**

Run:

```powershell
git diff --check
git diff -- auto_step.lua test_auto_step.lua
git status --short
```

Expected: no whitespace errors; only the intended gate and two test changes
appear in these files. Existing Hauksness changes remain unstaged.

- [ ] **Step 4: Commit only the implementation files**

Run:

```powershell
git add -- auto_step.lua test_auto_step.lua
git diff --cached --check
git diff --cached --name-only
git commit -m "fix: honor movement reset setting during initial settle"
```

Expected staged names before commit:

```text
auto_step.lua
test_auto_step.lua
```

### Task 4: Validate the Safety Fix in FCEUX

**Files:**
- Modify after evidence: `work_notes/current_investigation.md`

**Interfaces:**
- Consumes: manually reloaded FCEUX Lua source and restored clean entrance save.
- Produces: live evidence that a drift reroute initial settle no longer corrupts player stats.

- [ ] **Step 1: Ask the user to stop and restart the FCEUX Lua script**

Do not use `reload_config`; `auto_step.lua` is Lua source and requires manual
FCEUX script reload.

- [ ] **Step 2: Establish a fresh clean baseline**

Run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait-ready safe_initial_settle_reload
.\dw_commands.ps1 --replace --timeout 15 --wait "RUNTIME_BLOCKS map=0x03" log_state report_position current_object report_path_state report_runtime_blocks
```

Expected: map `0x03`, clean level-17 stats from the restored save, no active
path, no runtime blocks, and fresh command polling. If the restored entrance
state differs in level or resources, require internally consistent stats
rather than the previous exact values.

- [ ] **Step 3: Resume blocker-aware routing toward Axe Knight Approach**

Run:

```powershell
.\dw_commands.ps1 --replace auto_walk_blocker
```

Monitor `dw_debug.log`. Pause immediately for combat or user intervention.

- [ ] **Step 4: Validate an actual initial-settle reroute event**

Require both:

```text
auto_step route initial settle frames=16
AUTO_WALK_DRIFT_REROUTE
```

Then confirm no subsequent:

```text
PLAYER_STAT_FRAMEADVANCE_TRANSITION from=clean to=bad
PLAYER_STAT_INTEGRITY_TRANSITION from=clean to=bad
PLAYER_STAT_INTEGRITY_WARNING
```

Use `log_state` after field control returns to confirm internally consistent
HP, MP, Strength, Agility, Attack, Defense, and spells.

- [ ] **Step 5: Record the live outcome**

Update `work_notes/current_investigation.md` with:

- reload baseline,
- the initial-settle reroute frame,
- before/after stat bytes,
- absence or presence of integrity warnings, and
- a separate note that Axe Knight overshoot remains unresolved.

Do not claim the live bug fixed unless the actual reroute path executes with
clean stats.
