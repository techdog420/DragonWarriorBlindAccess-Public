# Hauksness Lower-Pocket Carry Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Hauksness-to-Kol return route recover safely when final-settle carry places the hero at `(25,93)` after the `(24,93)` waypoint.

**Architecture:** Preserve the global movement executor and encode the proven local geometry on the existing `Hauksness lower west pocket` waypoint. A route-level regression will reproduce the carried landing through the public route state API and assert the consumer-visible step sequence.

**Tech Stack:** Lua 5.1-compatible route data and the repository's standalone Lua test harness.

## Global Constraints

- Change only the `kol_hauksness` return-route waypoint; do not alter the forward `hauksness` route.
- Do not change global final-carry acceptance or movement-reset behavior.
- Do not add an overworld map blocker.
- Preserve normal arrival behavior from `(24,93)`, where the first useful step remains UP.
- Do not reload the FCEUX script while the active return-route validation is in progress.

---

### Task 1: Add local carry recovery and regression coverage

**Files:**
- Modify: `test_overworld_routes.lua:1452`
- Modify: `overworld_routes.lua:671`
- Modify: `work_notes/current_investigation.md`

**Interfaces:**
- Consumes: `overworld_routes.start(destination, map_id, x, y)`, `overworld_routes.observe_position(map_id, x, y)`, and `overworld_routes.plan_next_segment(map_id, x, y)`.
- Produces: The existing `kol_hauksness` route will plan `left, up, up` toward `Hauksness lower west pocket` when planning from `(25,93)`.

- [x] **Step 1: Write the failing route regression**

Add this test immediately after
`tests.kol_hauksness_return_preserves_lower_pocket_recovery`:

```lua
function tests.kol_hauksness_return_recovers_west_after_lower_drop_carry()
    routes.reset_for_tests()
    routes.start("hauksness to kol", 0x01, 25, 89)

    routes.observe_position(0x01, 24, 89)
    routes.observe_position(0x01, 15, 89)
    routes.observe_position(0x01, 15, 93)
    routes.observe_position(0x01, 24, 93)

    local segment = assert(routes.plan_next_segment(0x01, 25, 93))

    assert_equal(segment.waypoint.name, "Hauksness lower west pocket", "carry recovery should retain the next return waypoint")
    assert_equal(segment.steps[1], "left", "carry recovery should return to column 24 before climbing")
    assert_equal(segment.steps[2], "up", "carry recovery should climb after returning to column 24")
    assert_equal(segment.steps[3], "up", "carry recovery should reach the lower west pocket")

    routes.reset_for_tests()
end
```

This catches removal or misplacement of the local horizontal-first route
ordering. It exercises the real route planner and uses a hand-derived sequence
from the live-proven `(25,93)->LEFT`, `(24,93)->UP` path.

- [x] **Step 2: Run the route suite and verify RED**

Run:

```powershell
lua test_overworld_routes.lua
```

Expected: exactly the new test fails with
`carry recovery should return to column 24 before climbing: expected left, got up`.
Existing route tests should remain passing.

- [x] **Step 3: Add the minimal waypoint correction**

In the `kol_hauksness` route only, replace:

```lua
{x = 24, y = 91, name = "Hauksness lower west pocket", radius = 0},
```

with:

```lua
{
    x = 24,
    y = 91,
    name = "Hauksness lower west pocket",
    radius = 0,
    axis_order = {"horizontal", "vertical"},
},
```

- [x] **Step 4: Run focused verification and verify GREEN**

Run:

```powershell
luac -p overworld_routes.lua test_overworld_routes.lua
lua test_overworld_routes.lua
lua test_route_manager.lua
git diff --check
```

Expected:

- Lua syntax validation exits zero.
- All overworld-route tests pass, including the new carried-landing regression.
- All route-manager tests pass.
- `git diff --check` exits zero with no whitespace errors.
- The existing `kol_hauksness_return_preserves_lower_pocket_recovery` test still proves normal `(24,93)` arrival begins UP.

- [x] **Step 5: Record the source fix and deferred live check**

Append this concise evidence to the current Hauksness return-route section in
`work_notes/current_investigation.md`:

```markdown
- LOWER-POCKET FINAL-CARRY RECOVERY: after the route reached lower-west-drop
  waypoint `(24,93)`, final settle carried to `(25,93)`. Four queued UP
  attempts and a same-origin raw UP probe all blocked into `(25,92)`, while
  same-origin LEFT crossed `(24,93)` and UP from `(24,93)` reached `(24,91)`.
  The return-only `Hauksness lower west pocket` waypoint now uses
  horizontal-first order. Its regression reproduces planning from `(25,93)`
  and requires `left, up, up`; the existing exact `(24,93)` progression
  remains UP-first. Defer FCEUX Stop/Run and live replay until the active
  return-route validation can be safely interrupted.
```

- [x] **Step 6: Review the final diff**

Run:

```powershell
git diff -- test_overworld_routes.lua overworld_routes.lua work_notes/current_investigation.md
git status --short
```

Expected: only the regression, one return-waypoint field, and the evidence note
are changed; the approved design and implementation plan remain tracked repo
documents. Do not commit unless the user separately requests it.

- [x] **Step 7: Perform deferred live verification**

After a manual script reload and fresh Hauksness map entry/exit, the active
`kol_hauksness` route reached `Hauksness lower west drop` at exact `(24,93)`
without carrying. A same-origin RIGHT probe recreated the prior carry landing
at `(25,93)` while preserving the active route and a clean field. The loaded
route then planned and executed exactly `left, up, up`, completed at `(24,91)`,
and advanced to `Hauksness lower pocket`. No NPC or runtime blockers were
present.
