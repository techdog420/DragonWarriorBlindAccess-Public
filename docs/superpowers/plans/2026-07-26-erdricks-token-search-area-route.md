# Erdrick's Token Search-Area Route Implementation Plan

> **Execution note:** Use `superpowers:executing-plans` task by task. Keep live
> FCEUX work inline unless the user explicitly asks for subagents; combat and
> script reloads require the user's intervention.

**Goal:** Add clue-preserving bidirectional overworld guidance between Cantlin
and a safe perimeter pin beside the eastern Great Swamp, without exposing or
automatically searching Erdrick's Token square.

**Architecture:** `objects.lua` gains one Travel-compatible search-area
landmark after its coordinate is live-confirmed. `overworld_routes.lua` gains
literal `great_swamp_cantlin` and `cantlin_great_swamp` routes that reuse the
existing route state machine. The final outbound waypoint uses its existing
`warning` field to append the Gwaelin's Love/Search reminder to normal arrival
speech. The exact treasure coordinate remains limited to tests, documentation,
and live validation evidence.

**Tech Stack:** Lua 5.1/LuaJIT, existing object and overworld-route modules,
table-driven Lua tests, FCEUX 2.6.6, `dw_commands.ps1`, `dw_debug.log`,
PowerShell, Git Bash/WSL, and the repository Python harness.

## Global Constraints

- Treat Tantegel `(43,43)` plus the clue offset as internal coordinate
  `(83,113)`.
- Never add `(83,113)` as a player-facing object or route waypoint.
- Use player-facing name `Eastern Great Swamp Search Area`.
- Treat reference-map hill `(89,112)` as provisional until normal FCEUX
  movement proves it is reachable, safe, non-damaging, and resumable.
- Start outbound validation at the normal Cantlin World Map landing
  `(73,102)`.
- Reuse live-confirmed Cantlin departure geometry where applicable, but do not
  assume the new route shares the entire Hauksness chain.
- Define the return route explicitly; do not generate it at runtime.
- Do not change autowalk timing, carry semantics, route-manager control flow,
  swamp damage, encounters, or hidden-treasure mechanics.
- Do not add runtime or permanent blockers from a timing failure, reference
  map, or one failed traversal.
- Stop movement when combat starts. Resume only after the user clears the
  field and a fresh state probe is clean.
- FCEUX requires the user's manual `main.lua` restart after Lua changes.
- Keep `work_notes/hauksness_stat_corruption_20260724.log` untracked.

---

### Task 1: Establish live route geometry and confirm the safe pin

**Files:**

- Read: `session_handoff.md`
- Read: `PLAYTESTING.md`
- Read: `overworld_routes.lua`
- Read: `dw_debug.log`
- Working evidence only: `work_notes/current_investigation.md`

**Interfaces:**

- Consumes: normal Cantlin exit landing, `launcher_probe`,
  `report_position`, `route_status`, `report_path_state`,
  `report_runtime_blocks`, `report_input_guard_state`, `inspect_tile`,
  `probe_edge`, and short normal-movement/autowalk segments
- Produces: a clean ordered coordinate trace from Cantlin to the eastern Great
  Swamp, a confirmed safe staging coordinate, and a separate reverse trace

- [ ] **Step 1: Start from a clean Cantlin baseline**

Ask the user to place the hero at the normal Cantlin World Map exit landing
with no route or path active. Then run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait-ready TOKEN_ROUTE_DISCOVERY
.\dw_commands.ps1 --replace --timeout 15 --wait "POSITION:" report_position route_status report_path_state report_runtime_blocks report_input_guard_state
```

Expected: World Map `0x01`, position `(73,102)`, no active route/path, no
runtime blocks, and command polling confirmed by the fresh launcher tag.

- [ ] **Step 2: Confirm the reusable Cantlin departure**

Walk the already validated north departure one segment at a time:

```text
(73,102) -> (73,91) -> (68,91)
```

At each turn, record:

- origin and destination;
- first movement direction;
- whether exact radius `0` is required;
- any carry, drift, timeout, or battle interruption;
- whether the segment belongs unchanged in the new route.

Do not copy the remainder of `hauksness_cantlin` without walking the new
destination path.

- [ ] **Step 3: Locate the eastern bridge and Great Swamp approach**

Follow the canonical route shape through normal movement:

1. western detour from Cantlin;
2. southwest through the forest;
3. open plains;
4. eastern bridge;
5. southeast toward the Great Swamp.

Send only the smallest next movement batch. After every narrow turn or bridge
edge, read the new log tail and record the exact coordinate.

If a move reports a block, preserve the origin and run only the matching
quoted probe, for example:

```powershell
.\dw_commands.ps1 --replace --timeout 20 --wait "EDGE_PROBE_RESULT" "probe_edge:RIGHT"
```

A clean same-origin probe rejects a static-blocker conclusion.

- [ ] **Step 4: Evaluate provisional staging tile `(89,112)`**

Approach `(89,112)` through normal movement. Confirm:

- the hero can enter and leave from the intended route direction;
- standing still does not cause swamp damage;
- the tile is not an entrance or other transition;
- the tile is not occupied by a fixed object;
- there is enough stable space to stop guidance and begin the return route;
- the clue square `(83,113)` remains outside the route.

If any check fails, test nearby perimeter tiles one at a time and select the
nearest practical safe alternative. Record the rejected candidate and reason
in `work_notes/current_investigation.md`; do not edit production files yet.

- [ ] **Step 5: Walk the return geometry independently**

From the confirmed pin, walk back to Cantlin through the same broad corridor.
Record direction-specific changes:

- extra turn anchors;
- alternate axis order;
- carry that must be disabled or sustained;
- drift recovery points;
- any candidate waypoint that can be omitted safely.

The result of Task 1 is two evidence-backed ordered waypoint lists. Stop here
if command polling fails, live state becomes contaminated, or the exact
practical approach remains unclear.

---

### Task 2: Add RED tests for the clue-preserving World Map landmark

**Files:**

- Modify: `test_objects.lua`
- Read: `objects.lua`

**Interfaces:**

- Consumes: the live-confirmed staging coordinate from Task 1
- Produces: failing tests for one safe Travel landmark and its disclosure
  boundary

- [ ] **Step 1: Add a failing World Map landmark test**

Add a test near the other overworld landmark coverage:

```lua
function tests.world_map_exposes_great_swamp_search_area_without_token_square()
    local env = make_env()

    env.set_position(0x01, 73, 102)
    env.set_terrain_offset(0x00)
    env.objects.refresh(0x01)

    local obj = env.objects.find_object_by_id(
        "overworld_eastern_great_swamp_search_area")
    assert_equal(obj ~= nil, true, "World Map should expose the search area")
    assert_equal(obj.name, "Eastern Great Swamp Search Area",
        "landmark should use clue-preserving name")
    assert_equal(obj.type, env.objects.TYPE_EXIT,
        "search area should remain Travel-compatible")
    assert_equal(obj.x, CONFIRMED_SAFE_X, "safe pin x")
    assert_equal(obj.y, CONFIRMED_SAFE_Y, "safe pin y")
    assert_equal(obj.x == 83 and obj.y == 113, false,
        "search-area landmark must not expose the buried square")

    local speech = env.objects.describe_object(obj):lower()
    assert_equal(speech:find("token", 1, true), nil,
        "object speech should not name the token")
    assert_equal(speech:find("erdrick", 1, true), nil,
        "object speech should not name Erdrick")

    env.restore()
end
```

Replace `CONFIRMED_SAFE_X/Y` with Task 1's live-confirmed coordinate before
running the test.

- [ ] **Step 2: Run the object suite and verify RED**

Run:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "cd /d/modding/DragonWarrior1 && luajit test_objects.lua"
```

Expected: failure because
`overworld_eastern_great_swamp_search_area` does not exist. Confirm the
failure is not a harness or fixture error.

- [ ] **Step 3: Commit the RED test**

Run:

```powershell
git add test_objects.lua
git diff --cached --check
git commit -m "test: specify Great Swamp search-area landmark"
```

Expected: the commit contains only `test_objects.lua`.

---

### Task 3: Implement the World Map search-area landmark

**Files:**

- Modify: `objects.lua`
- Verify: `test_objects.lua`

**Interfaces:**

- Consumes: the RED object test
- Produces: one Travel-compatible overworld landmark at the confirmed safe pin

- [ ] **Step 1: Add the landmark**

Add a relative entry to `OVERWORLD_LANDMARKS`. Derive `dx` and `dy` from the
confirmed absolute coordinate and Tantegel `(43,43)`.

For provisional `(89,112)`, the entry would be:

```lua
    {dx = 46, dy = 69, name = "Eastern Great Swamp Search Area"},
```

Use that entry only if Task 1 confirmed `(89,112)`. Do not add a second
landmark for `(83,113)`.

- [ ] **Step 2: Run the object suite and verify GREEN**

Run:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "cd /d/modding/DragonWarrior1 && luajit test_objects.lua && luajit -b objects.lua /tmp/objects.luac && luajit -b test_objects.lua /tmp/test_objects.luac"
git diff --check -- objects.lua test_objects.lua
```

Expected: object tests and bytecode checks pass; whitespace check is silent.

- [ ] **Step 3: Commit the minimal implementation**

Run:

```powershell
git add objects.lua
git diff --cached --check
git commit -m "feat: add Great Swamp search-area landmark"
```

Expected: production commit contains only `objects.lua`.

---

### Task 4: Add RED outbound-route tests from live evidence

**Files:**

- Modify: `test_overworld_routes.lua`
- Read: `overworld_routes.lua`

**Interfaces:**

- Consumes: outbound waypoint trace and confirmed safe pin from Task 1
- Produces: failing route lookup, geometry, warning, arrival, and
  non-disclosure regressions

- [ ] **Step 1: Specify route selection and aliases**

Add tests asserting:

- `routes.start("great swamp search area", 0x01, 73, 102)` selects
  `great_swamp_cantlin`;
- `start_for_object` with
  `overworld_eastern_great_swamp_search_area` selects the same route;
- the first target after `(73,102)` matches the live departure;
- aliases do not contain `token` or `Erdrick`.

- [ ] **Step 2: Specify every evidence-backed narrow turn**

Create helper-driven waypoint group tests following the existing
Cantlin/Hauksness pattern. Populate them from Task 1 rather than from the
external map. Assert coordinate, first step, radius, axis order, and any
route-local timing metadata at each narrow turn.

- [ ] **Step 3: Specify arrival and disclosure**

Add assertions equivalent to:

```lua
local route = assert(routes._route_for_tests("great_swamp_cantlin"))
local final = route.waypoints[#route.waypoints]

assert_equal(final.x, CONFIRMED_SAFE_X, "outbound safe pin x")
assert_equal(final.y, CONFIRMED_SAFE_Y, "outbound safe pin y")
assert_equal(final.final, true, "safe pin should finish the route")
assert_contains(final.warning, "Gwaelin's Love",
    "arrival should preserve the intended coordinate tool")
assert_contains(final.warning, "Search",
    "arrival should preserve the intended interaction")

for _, waypoint in ipairs(route.waypoints) do
    assert_equal(waypoint.x == 83 and waypoint.y == 113, false,
        "outbound route must not target the buried square")
end
```

Observe the final pin and assert the event message contains both:

- `Arrived at Eastern Great Swamp Search Area`;
- `Use Gwaelin's Love and Search to continue`.

- [ ] **Step 4: Run the route suite and verify RED**

Run:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "cd /d/modding/DragonWarrior1 && luajit test_overworld_routes.lua"
```

Expected: route lookup fails because `great_swamp_cantlin` is not registered.

- [ ] **Step 5: Commit the RED outbound tests**

Run:

```powershell
git add test_overworld_routes.lua
git diff --cached --check
git commit -m "test: specify Cantlin route to Great Swamp search area"
```

---

### Task 5: Implement the outbound route

**Files:**

- Modify: `overworld_routes.lua`
- Verify: `test_overworld_routes.lua`

**Interfaces:**

- Consumes: Task 4's RED tests
- Produces: literal `great_swamp_cantlin` route and deterministic lookup

- [ ] **Step 1: Add the literal outbound route**

Add:

```lua
    great_swamp_cantlin = {
        id = "great_swamp_cantlin",
        title = "Eastern Great Swamp Search Area",
        aliases = {
            "great swamp search area",
            "eastern great swamp",
            "great swamp from cantlin",
            "cantlin to great swamp",
        },
        target_object_ids = {
            "overworld_eastern_great_swamp_search_area",
        },
        waypoints = {
            -- Populate only from Task 1's outbound trace.
        },
    },
```

The final waypoint must use:

```lua
{
    x = CONFIRMED_SAFE_X,
    y = CONFIRMED_SAFE_Y,
    name = "Eastern Great Swamp Search Area",
    radius = 0,
    final = true,
    warning = "Use Gwaelin's Love and Search to continue.",
},
```

Place a separate danger warning on the last safe approach before hazardous
swamp travel. Do not create a `destination_maps` entry because arrival remains
on World Map `0x01`.

- [ ] **Step 2: Register lookup without stealing other routes**

Add `great_swamp_cantlin` to `ROUTE_IDS`. Add alternates only where required
by actual object/alias selection. Do not add it to Cantlin's route alternates;
the route targets the search-area object.

- [ ] **Step 3: Run focused tests and bytecode checks**

Run:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "cd /d/modding/DragonWarrior1 && luajit test_overworld_routes.lua && luajit test_route_manager.lua && luajit -b overworld_routes.lua /tmp/overworld_routes.luac && luajit -b test_overworld_routes.lua /tmp/test_overworld_routes.luac"
git diff --check -- overworld_routes.lua test_overworld_routes.lua
```

Expected: route and route-manager tests pass; bytecode and whitespace checks
are clean.

- [ ] **Step 4: Commit the outbound route**

Run:

```powershell
git add overworld_routes.lua
git diff --cached --check
git commit -m "feat: add Cantlin route to Great Swamp search area"
```

---

### Task 6: Add and implement the independent return route

**Files:**

- Modify: `test_overworld_routes.lua`
- Modify: `overworld_routes.lua`

**Interfaces:**

- Consumes: Task 1's reverse trace and existing `overworld_cantlin` object
- Produces: explicit `cantlin_great_swamp` route selected near the safe pin

- [ ] **Step 1: Add RED return-route tests**

Specify:

- selecting the ordinary `overworld_cantlin` object at the safe pin chooses
  `cantlin_great_swamp`;
- aliases such as `great swamp to cantlin` resolve unambiguously;
- the first step leaves the pin in the live-confirmed direction;
- the route preserves all reverse-only anchors and metadata;
- no waypoint is `(83,113)`;
- the final waypoint is strict Cantlin `(73,102)`;
- the new variant does not steal Cantlin selection near Hauksness;
- arriving at `(73,102)` stops guidance.

Run `luajit test_overworld_routes.lua` and confirm RED because the return route
does not exist. Commit only the RED tests:

```powershell
git add test_overworld_routes.lua
git diff --cached --check
git commit -m "test: specify Great Swamp return route to Cantlin"
```

- [ ] **Step 2: Add the literal return route**

Add:

```lua
    cantlin_great_swamp = {
        id = "cantlin_great_swamp",
        title = "Cantlin",
        aliases = {
            "great swamp to cantlin",
            "cantlin from great swamp",
            "return to cantlin from great swamp",
        },
        target_object_ids = {"overworld_cantlin"},
        waypoints = {
            -- Populate from Task 1's independently recorded return trace.
        },
    },
```

Register the route in `ROUTE_IDS` and add it to Cantlin alternates with
selection bounds if necessary. Keep the existing `cantlin_hauksness` variant
authoritative near Hauksness.

- [ ] **Step 3: Verify and commit**

Run:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "cd /d/modding/DragonWarrior1 && luajit test_overworld_routes.lua && luajit test_route_manager.lua && luajit -b overworld_routes.lua /tmp/overworld_routes.luac"
git diff --check -- overworld_routes.lua test_overworld_routes.lua
```

Then commit only production route data:

```powershell
git add overworld_routes.lua
git diff --cached --check
git commit -m "feat: add Great Swamp return route to Cantlin"
```

---

### Task 7: Run the complete automated verification gate

**Files:**

- Verify: `objects.lua`
- Verify: `overworld_routes.lua`
- Verify: `route_manager.lua`
- Verify: `auto_step.lua`
- Verify: all modified tests

- [ ] **Step 1: Run focused suites**

Run:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "cd /d/modding/DragonWarrior1 && luajit test_objects.lua && luajit test_overworld_routes.lua && luajit test_route_manager.lua && luajit test_auto_step.lua"
```

Expected: all suites exit zero with no `FAIL` lines.

- [ ] **Step 2: Byte-compile affected Lua**

Run:

```powershell
& 'C:\Program Files\Git\bin\bash.exe' -lc "cd /d/modding/DragonWarrior1 && luajit -b objects.lua /tmp/objects.luac && luajit -b overworld_routes.lua /tmp/overworld_routes.luac && luajit -b test_objects.lua /tmp/test_objects.luac && luajit -b test_overworld_routes.lua /tmp/test_overworld_routes.luac"
```

- [ ] **Step 3: Run whitespace and full harness checks**

Run:

```powershell
git diff --check
wsl.exe bash -lc "cd /mnt/d/modding/DragonWarrior1 && python3 run_tests.py --allow-missing-speech-dep"
```

Expected: whitespace check is silent and the repository harness passes,
allowing only the documented optional speech dependency warning.

---

### Task 8: Validate the outbound route live

**Files:**

- Read: `dw_debug.log`
- Working evidence: `work_notes/current_investigation.md`

- [ ] **Step 1: Pause for manual Lua restart**

Ask the user to restart `main.lua` through FCEUX Lua Script Control and stand
at Cantlin's World Map landing `(73,102)` with no route active.

- [ ] **Step 2: Establish fresh baseline**

Run:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait-ready TOKEN_ROUTE_OUTBOUND
.\dw_commands.ps1 --replace --timeout 15 --wait "POSITION:" report_position route_status report_path_state report_runtime_blocks report_input_guard_state
```

- [ ] **Step 3: Select the ordinary search-area Travel object**

Confirm the object and route:

```powershell
.\dw_commands.ps1 --replace --timeout 15 --wait "OBJECT:" current_object
.\dw_commands.ps1 --replace --timeout 15 --wait "route=great_swamp_cantlin" route_guidance route_status
```

- [ ] **Step 4: Walk one segment at a time**

For each route segment:

```powershell
.\dw_commands.ps1 --replace auto_walk
Get-Content -LiteralPath 'dw_debug.log' -Tail 140
```

Wait for waypoint advance, accepted carry, battle, timeout, drift, or
cancellation before sending the next command. On combat, stop and wait for the
user's `field clear`, then fresh-probe.

- [ ] **Step 5: Confirm safe-pin arrival**

Expected at the final waypoint:

- position equals the live-confirmed safe pin;
- arrival speech names `Eastern Great Swamp Search Area`;
- speech says to use Gwaelin's Love and Search;
- active route and path clear;
- no Search command is sent automatically;
- no runtime blocker was required.

---

### Task 9: Confirm the clue and validate the return route

- [ ] **Step 1: Perform the clue-driven manual search**

From the safe pin, the user moves manually and uses Gwaelin's Love to reach
70 south and 40 east of Tantegel. Confirm the resulting World Map coordinate
is `(83,113)`. The user issues Search manually and confirms the Token is
awarded.

Do not add the exact square to player-facing source after confirmation.

- [ ] **Step 2: Return to the safe pin**

Move back to the safe pin manually if collecting the Token moved the hero
away from it. Fresh-probe and confirm no route/path/runtime block remains.

- [ ] **Step 3: Select Cantlin and validate `cantlin_great_swamp`**

Select the ordinary Cantlin Travel object, start guidance, and validate one
segment at a time using the same battle and same-origin-probe rules as the
outbound pass.

Expected final state:

- World Map `(73,102)`;
- route cleared;
- no runtime or permanent blocker used;
- existing Cantlin entrance remains usable.

---

### Task 10: Record durable state and update the draft PR

**Files:**

- Modify after successful live validation: `PLAYTESTING.md`
- Modify after successful live validation: `session_handoff.md`
- Preserve untracked: `work_notes/hauksness_stat_corruption_20260724.log`

- [ ] **Step 1: Document only confirmed results**

Record:

- final safe staging coordinate;
- outbound and return route IDs;
- automated test counts;
- end-to-end live validation status;
- whether `(89,112)` was accepted or replaced;
- any unresolved timing evidence, clearly separated from route correctness;
- next recommended objective.

- [ ] **Step 2: Re-run verification**

Repeat Task 7 and run:

```powershell
git status --short --branch
git diff main...HEAD --stat
git diff --check
```

- [ ] **Step 3: Commit only durable validation docs**

Run:

```powershell
git add PLAYTESTING.md session_handoff.md
git diff --cached --check
git commit -m "docs: validate Great Swamp search-area routes"
```

- [ ] **Step 4: Push the completed branch**

Run:

```powershell
git push
```

Update the existing draft PR with exact verification and live-validation
results. Mark it ready only after both directions work live and the PR diff
contains no unrelated files.
