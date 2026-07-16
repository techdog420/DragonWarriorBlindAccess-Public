# Rimuldar Magic Key Route Correctness Implementation Plan

> **Status:** Static decoder, map, pathfinder, and service tasks were completed
> through the commits preceding `923d426`. Live acceptance exposed a separate
> executor-cadence and seam-arrival defect. Remaining work is superseded by
> `docs/superpowers/plans/2026-07-15-rimuldar-seam-cadence-and-arrival.md`.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the live-proven normal-movement route from Rimuldar's east entrance at `(29,14)` to the Magic Key Merchant's public interaction stand at `(4,5)` reproducible by the decoder, pathfinder, object model, and route manager.

**Architecture:** Replace the incorrect RLE/row-padded interior-map interpretation with one shared linear packed-nibble reader, then model only the live-proven false-wall cells and one-way exit protections for map `0x0B`. Keep moving NPCs as runtime blockers, keep the raw counter at `(4,6)` non-walkable, and express the seller's interaction stand as object metadata rather than special-casing pathfinding or route execution.

**Tech Stack:** Lua 5.1-compatible source, LuaJIT test runtime, FCEUX live runtime, PowerShell, repository command queue/debug log.

## Global Constraints

- Work on branch `codex/rimuldar-magic-key-correctness` in the current checkout because FCEUX reloads `D:\modding\dragonwarrior1\main.lua` from this exact path.
- Follow strict red-green-refactor order. Do not edit production code for a task until its new assertion has failed for the expected reason.
- Use `C:\Users\developer\AppData\Local\Programs\LuaJIT\bin\luajit.exe`; plain `lua` is not on the current PowerShell `PATH`.
- Run Lua tests sequentially. Parallel Lua suites can contend for the speech bridge and produce unrelated file-lock noise.
- Do not change `pathfinder.lua` or `route_manager.lua` unless a new regression exposes a genuine generic defect. The approved design expects data/decoder/object corrections only.
- Do not add runtime blocked tiles or promote NPC positions to permanent terrain blocks.
- Do not make `(4,6)` a passthrough. It decodes as raw block `0xF` and is the physical counter.
- Do not reload the live Lua script. The user will perform any required FCEUX script reload.
- Preserve unrelated user changes. Use `git diff --check`, focused diffs, and scoped commits after every green task.

## File Structure

- Modify `map_reader.lua`
  - one shared packed-nibble decoder used by both full-grid and raw-cell reads
  - explicit Rimuldar route passthrough cells
  - destination-side one-way exit guards at `(0,1)`, `(0,2)`, and `(0,3)`
- Modify `test_map_reader.lua`
  - packed-nibble decoder regressions
  - packed fixture helpers and migration of legacy RLE fixtures
  - Rimuldar route-cell, counter, and directional-guard assertions
- Modify `test_pathfinder.lua`
  - portable real-stack Rimuldar fixture and exact route/NPC regression
- Modify `objects.lua`
  - Magic Key Merchant interaction stand `(4,5)`, facing south toward seller `(4,7)` across counter `(4,6)`
- Modify `test_objects.lua`
  - service metadata and visited-from-stand regression
- Modify `test_route_manager.lua`
  - exact Rimuldar service goal/facing regression using existing generic plumbing
- Modify `work_notes/current_investigation.md` only while collecting live verification evidence.
- Update `session_handoff.md`, `PLAYTESTING.md`, `PROJECT_MEMORY.md`, or the approved spec only after a manual reload and live route verification materially changes shared project state.

---

## Task 1: Correct Interior Map Decoding and Migrate Test Fixtures

**Files:**

- Modify: `test_map_reader.lua`
- Modify: `map_reader.lua`

**Interfaces:**

- Preserve `map_reader.decompress_map(map_id)` and its zero-based `grid[y][x]` return shape.
- Preserve `map_reader.get_raw_block_id(map_id, x, y)` and its `nil` behavior for invalid map IDs or coordinates.
- Introduce a private helper only; do not export a new public API.

- [ ] **Step 1: Add reusable packed-map fixture helpers.**

  Add these test-only helpers near the existing assertion helpers in `test_map_reader.lua`:

  ```lua
  local function fill_packed_map(rom_bytes, data_start, width, height, block_id)
      local packed = (block_id % 16) * 0x11
      for offset = 0, math.ceil(width * height / 2) - 1 do
          rom_bytes[data_start + offset] = packed
      end
  end

  local function set_packed_block(rom_bytes, data_start, width, x, y, block_id)
      local tile_index = y * width + x
      local offset = data_start + math.floor(tile_index / 2)
      local byte = rom_bytes[offset] or 0
      block_id = block_id % 16
      if tile_index % 2 == 0 then
          rom_bytes[offset] = block_id * 16 + byte % 16
      else
          rom_bytes[offset] = math.floor(byte / 16) * 16 + block_id
      end
  end
  ```

- [ ] **Step 2: Write decoder regressions before changing production.**

  Add three tests:

  1. A `4x2` fixture containing bytes `4F C0 9A 12`, expecting rows `4,F,C,0` and `9,A,1,2`.
  2. A `3x2` fixture containing bytes `12 34 56`, expecting rows `1,2,3` and `4,5,6`; this proves there is no byte padding at odd-width row boundaries.
  3. A packed `30x30` map-`0x0B` fixture asserting raw/grid agreement for bridge `(1,3)=0xE`, stand `(4,5)=0x6`, and counter `(4,6)=0xF`.

  For every coordinate, assert both `decompress_map()` and `get_raw_block_id()` return the same nibble.

- [ ] **Step 3: Run the new tests and confirm the expected red state.**

  ```powershell
  $lua = 'C:\Users\developer\AppData\Local\Programs\LuaJIT\bin\luajit.exe'
  & $lua 'test_map_reader.lua'
  ```

  Expected: nonzero exit. The even-width test must expose RLE interpretation, and the odd-width test must expose row-padded raw addressing. If failure is only fixture setup or syntax, fix the test and rerun; do not edit `map_reader.lua` yet.

- [ ] **Step 4: Implement one private linear packed-nibble reader.**

  In `map_reader.lua`, replace the RLE description and logic with a shared helper equivalent to:

  ```lua
  local function read_packed_block_id(meta, tile_index)
      if not meta or tile_index < 0 or tile_index >= meta.width * meta.height then
          return nil
      end

      local byte = rom.readbyte(meta.data_ptr + math.floor(tile_index / 2))
      if byte == nil then return nil end
      byte = math.floor(tonumber(byte) or 0) % 256

      if tile_index % 2 == 0 then
          return math.floor(byte / 16) % 16
      end
      return byte % 16
  end
  ```

  Make `decompress_map()` iterate `tile_index = 0 .. width * height - 1`, derive `x` and `y`, and call the helper. Make `get_raw_block_id()` validate/coerce coordinates and call the same helper with `y * width + x`. Remove the stale RLE and per-row-byte-padding explanations.

- [ ] **Step 5: Run the suite once and inventory only fixture failures caused by the corrected decoder.**

  ```powershell
  & $lua 'test_map_reader.lua'
  ```

  Expected: the new decoder tests pass; legacy RLE-shaped fixtures may now fail. Record the failing test names before migrating them so unrelated regressions are not disguised as fixture work.

- [ ] **Step 6: Migrate the known legacy fixtures to packed bytes.**

  Use `fill_packed_map()` plus `set_packed_block()` rather than hand-built RLE runs. Migrate these known fixture groups:

  - uniform `0x2F` fixtures near the early boundary/door tests to packed tile `0x2`
  - the bespoke Garinham fixture to a packed base plus cells `(19,10)=0x2`, `(3,13)=0x2`, and `(3,17)=0xB`
  - uniform `0x6F` Rimuldar/Cantlin fixtures to packed tile `0x6`
  - Cantlin premium-counter fixture to packed tile `0x6` plus `(25,12)`, `(26,12)`, `(27,12)`, and `(29,12)` set to `0xF`
  - uniform `0x4F` hazard fixture to packed tile `0x4`
  - remaining literal-run fixtures around the existing dungeon, bridge, B3, damage-tile, and late walkability tests
  - consolidate the B3 fixture's separate grid/raw byte areas into one packed map; use packed floor plus `(1,2)`, `(2,2)`, `(3,2)=0x1` and `(4,14)=0xF`

  Do not mechanically rewrite the intentional high/low-nibble raw-reader literals in the existing raw-block tests.

- [ ] **Step 7: Verify Task 1 green.**

  ```powershell
  & $lua 'test_map_reader.lua'
  git diff --check
  git diff -- 'map_reader.lua' 'test_map_reader.lua'
  ```

  Expected: `test_map_reader.lua` exits `0`; decoder regressions pass; no whitespace errors; production diff is limited to decoding/comments.

- [ ] **Step 8: Commit Task 1.**

  ```powershell
  git add map_reader.lua test_map_reader.lua
  git commit -m "fix: decode interior maps as packed nibbles"
  ```

---

## Task 2: Encode the Live-Proven Rimuldar Route and Protect Its Exit Seams

**Files:**

- Modify: `test_map_reader.lua`
- Modify: `test_pathfinder.lua`
- Modify: `map_reader.lua`

**Interfaces:**

- Keep `MAP_PASSTHROUGH_CELLS` explicit and map-scoped.
- Keep `MAP_DIRECTIONAL_BLOCKS` destination-cell semantics: a flag names the direction from which entry into that destination is blocked.
- Preserve normal A* and NPC-blocker APIs; this task must not special-case Rimuldar in `pathfinder.lua`.

- [ ] **Step 1: Add focused map-reader route assertions before data changes.**

  In `test_map_reader.lua`, use a packed Rimuldar fixture and assert effective walkability for the exact live route:

  - east strip `(29,14)` through `(29,2)`
  - row-2 jog `(29,2)` through `(21,2)`
  - connector `(21,2)` to `(21,0)`
  - top bank `(21,0)` through `(0,0)`; include both sides of the fixed NPC at `(27,0)`
  - left descent `(0,0)` through `(0,3)`
  - bridge/tail `(1,3)`, `(2,3)`, `(3,3)`, `(4,3)`, `(5,3)`, `(5,4)`, `(5,5)`, `(4,5)`

  Assert `(4,6)` is globally non-walkable and not a passthrough. Replace the stale assertion describing `(4,6)` as the public stand.

  Assert destination guards for `(0,1)`, `(0,2)`, and `(0,3)` have `east=true`, while their `north` and `south` flags remain absent. These guards prevent walking west out of town from the hidden x=0 strip while preserving vertical travel.

- [ ] **Step 2: Add a real decoder + real pathfinder integration regression before data changes.**

  In `test_pathfinder.lua`, add `make_rimuldar_integration_env()` that stubs only emulator globals/dependencies, requires real `map_reader` and real `pathfinder`, and restores every module/global even after assertion failure.

  Embed these exact `30x30` Rimuldar block-ID rows from the local Rev-1 ROM and pack adjacent hex digits into 450 bytes at test setup. Do not depend on an external ROM at test runtime.

  ```lua
  local rows = {
      "000000000000000000000000000000",
      "000222222222222222000000000000",
      "022244488000000002222000000000",
      "0E0066480000088800082222000000",
      "220066400006666666688002222000",
      "284666408006080611600000882000",
      "2844F4400446444644600444442000",
      "204666400466646664600466642200",
      "20444440046664666468044F441200",
      "200000000444444444666666641200",
      "20000002280000080060C466641200",
      "208022222200066666660466641220",
      "210228882208666666660444448020",
      "212280082006660000660000888820",
      "2111808220666008006666666666E6",
      "2122882200660088006666666666E6",
      "21022220006608804D600880088820",
      "208000080066008444644444448020",
      "20000088806608846F646646640220",
      "204444444466408444666666640200",
      "204666666666400466666646648200",
      "204666646666408446444B44448200",
      "204446646666401466646646642200",
      "2846F66664464014666466B6342000",
      "284446646666401444444444442000",
      "224666646666481111800882222000",
      "024666666666488008002222000000",
      "024444444444488882222000000000",
      "000222222222222222000000000000",
      "000000000000000000000000000000",
  }
  ```

  Set map-`0x0B` metadata to a `30x30` map at a synthetic data start (for example `0x200`), set terrain RAM to town value `0x10`, require real `map_reader` first and real `pathfinder` second, and restore `addresses`, `config`, `debug_tools`, `map_reader`, `maps`, `pathfinder`, `rom`, `memory`, and `AND` in cleanup.

  With NPC blockers `27,0`, `2,4`, and `4,7`, assert a path exists from `(29,14)` to `(4,5)`, has the corrected planner length `52`, and visits these waypoints in order:

  ```text
  (29,2), (21,2), (21,0), (0,0), (0,3), (1,3), (2,3),
  (3,3), (4,3), (5,3), (5,4), (5,5), (4,5)
  ```

  Assert the path never steps on `(27,0)`, `(2,4)`, `(4,7)`, or `(4,6)`.

  Add a causal local control: without blockers, the two-step path from `(26,0)` to `(28,0)` crosses `(27,0)`; with only `27,0` blocked, that short top-bank segment has no path. This proves the terrain under Person 4 is walkable and the fixed NPC splits the direct top-bank lane. Do not claim this local control alone proves every cause of the wider row-2/x=21 route; `(29,1)` is intentionally outside the approved passability set.

- [ ] **Step 3: Run both new regressions and confirm red.**

  ```powershell
  & $lua 'test_map_reader.lua'
  & $lua 'test_pathfinder.lua'
  ```

  Expected: at least one missing outer-route passthrough/guard assertion fails and the real-stack path is absent or differs before the route data is added. A fixture-loader or module-leak failure is not an acceptable red state.

- [ ] **Step 4: Add only the live-proven route cells to map `0x0B`.**

  Extend `MAP_PASSTHROUGH_CELLS[0x0B]` with explicit, commented entries for raw-`0x0` route cells:

  - `(29,2..13)` as the east strip (ordinary walkable `(29,14)` may be asserted but need not be overridden)
  - `(21..29,2)` as the row-2 jog
  - `(21,0..2)` as the connector
  - `(0..29,0)` as the top bank, including terrain under fixed NPC `(27,0)`
  - `(0,1..3)` as the left descent
  - `(2,3)` and `(3,3)` as the bridge landing/tail

  Retain existing verified entries such as `(4,3)`, `(4,5)`, `(5,3)`, and `(5,5)` rather than duplicating them. Do not override `(4,6)`.

- [ ] **Step 5: Add the three destination-side one-way exit guards.**

  Add to `MAP_DIRECTIONAL_BLOCKS[0x0B]`:

  ```lua
  ["0,1"] = {east = true},
  ["0,2"] = {east = true},
  ["0,3"] = {east = true},
  ```

  Document that a westward move from x=1 enters these destination cells from the east and otherwise triggers an unintended world-map transition. Do not block north/south movement along x=0.

- [ ] **Step 6: Verify Task 2 green.**

  ```powershell
  & $lua 'test_map_reader.lua'
  & $lua 'test_pathfinder.lua'
  git diff --check
  git diff -- 'map_reader.lua' 'test_map_reader.lua' 'test_pathfinder.lua'
  ```

  Expected: both suites exit `0`; exact route length is `52`; causal NPC control passes; counter remains non-walkable; only intended Rimuldar map data changes.

- [ ] **Step 7: Commit Task 2.**

  ```powershell
  git add map_reader.lua test_map_reader.lua test_pathfinder.lua
  git commit -m "fix: model Rimuldar Magic Key route"
  ```

---

## Task 3: Point the Magic Key Service at the Real Public Stand

**Files:**

- Modify: `test_objects.lua`
- Modify: `objects.lua`
- Modify: `test_route_manager.lua`
- Verify only: `route_manager.lua`

**Interfaces:**

- Seller remains Old Man 1 at `(4,7)` and remains a movement blocker.
- Public interaction goal becomes `(4,5)` with `interaction_face_dir="south"`.
- Merchant 1 at `(2,4)` remains browsable but excluded from Services.
- Existing route-manager interaction-goal and post-arrival facing plumbing remains generic.

- [ ] **Step 1: Change service expectations first.**

  In `test_objects.lua`'s existing Rimuldar service test:

  - expect `magic_key_merchant.interaction_y == 5`
  - mark the merchant visited from `(4,5)`, not `(4,6)`
  - keep assertions for seller position `(4,7)`, seller blocking, south facing, and greeting-NPC exclusion

- [ ] **Step 2: Run the object suite and confirm red.**

  ```powershell
  & $lua 'test_objects.lua'
  ```

  Expected: nonzero exit with the focused mismatch `expected 5, got 6` for the Magic Key Merchant's public stand.

- [ ] **Step 3: Correct the service override and its evidence comment.**

  In `objects.lua`, change only the Rimuldar Magic Key Merchant override from `y=6` to `y=5`. Keep `x=4`, seller key `"4,7"`, `face_dir="south"`, label, and name. Update the adjacent comment to state:

  - seller `(4,7)`
  - raw-`0xF` counter `(4,6)`
  - player stand `(4,5)`
  - Merchant 1 `(2,4)` is only the greeter

  Remove the stale unrelated `(24,6)` key-shop bridge claim from this service comment.

- [ ] **Step 4: Verify the object suite green.**

  ```powershell
  & $lua 'test_objects.lua'
  ```

  Expected: all object tests pass, including visited-from-stand behavior.

- [ ] **Step 5: Replace the generic route-manager interaction fixture with the exact Rimuldar case.**

  In `test_route_manager.lua`, adapt the existing service-interaction test to use:

  - map `0x0B`
  - start `(29,14)`
  - seller `(4,7)`
  - interaction goal `(4,5)`
  - interaction facing south

  Assert the plan is queued in direct mode, identifies an interaction goal, passes `(4,5)` to the pathfinder stub, and reports `face_dir="south"`. Complete the route and assert the final input sets `buttons.down=true`. The stub returns north, so the south assertion proves interaction metadata overrides generic pathfinder facing.

- [ ] **Step 6: Run route-manager regression and inspect production scope.**

  ```powershell
  & $lua 'test_route_manager.lua'
  git diff --check
  git diff -- 'objects.lua' 'test_objects.lua' 'test_route_manager.lua' 'route_manager.lua'
  ```

  Expected: suite exits `0`; `route_manager.lua` has no diff; source change is limited to the service override/comment.

- [ ] **Step 7: Commit Task 3.**

  ```powershell
  git add objects.lua test_objects.lua test_route_manager.lua
  git commit -m "fix: target Rimuldar key merchant stand"
  ```

---

## Task 4: Static Verification, Manual Reload Handoff, and Live Acceptance

**Files:**

- Verify: all changed Lua/test files
- Possibly modify after live evidence: `work_notes/current_investigation.md`
- Possibly modify after successful acceptance: `session_handoff.md`, `PLAYTESTING.md`, `PROJECT_MEMORY.md`, `docs/superpowers/specs/2026-07-15-rimuldar-magic-key-route-design.md`

- [ ] **Step 1: Run fresh focused suites sequentially.**

  ```powershell
  $lua = 'C:\Users\developer\AppData\Local\Programs\LuaJIT\bin\luajit.exe'
  & $lua 'test_map_reader.lua'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $lua 'test_pathfinder.lua'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $lua 'test_objects.lua'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $lua 'test_route_manager.lua'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  ```

  Expected baseline counts before additions were `61/61`, `18/18`, `99/99`, and `104/104`; final totals must be higher where tests were added and all must pass.

- [ ] **Step 2: Run the repository test runner and static diff checks.**

  ```powershell
  $env:PATH = 'C:\Users\developer\AppData\Local\Programs\LuaJIT\bin;C:\Program Files\Git\bin;' + $env:PATH
  python run_tests.py --allow-missing-speech-dep
  & $lua -b 'map_reader.lua' 'NUL'
  & $lua -b 'objects.lua' 'NUL'
  & $lua -b 'test_map_reader.lua' 'NUL'
  & $lua -b 'test_pathfinder.lua' 'NUL'
  & $lua -b 'test_objects.lua' 'NUL'
  & $lua -b 'test_route_manager.lua' 'NUL'
  git diff --check
  git status --short
  git log --oneline -4
  ```

  The explicit `PATH` prefix gives the runner LuaJIT and Git Bash without changing the user's persistent environment. The `-b ... NUL` commands are syntax/bytecode checks and must each exit `0`. If the full runner reports only a known optional speech dependency, confirm it is covered by `--allow-missing-speech-dep`. Treat any map, object, pathfinder, or route-manager failure as blocking.

- [ ] **Step 3: Perform focused implementation review before asking for reload.**

  Confirm from the diff and tests:

  - full-grid and raw reads share one decoder
  - odd-width rows remain continuous
  - route uses explicit map-`0x0B` data only
  - x=0 guards use destination-side `east=true` semantics
  - `(4,6)` remains non-walkable
  - NPCs are passed as runtime blockers
  - route manager remains generic
  - no source reload has been attempted by Codex

- [ ] **Step 4: Ask the user for the manual FCEUX script reload.**

  Report the static evidence and the exact changed source files. Ask the user to reload `main.lua` in FCEUX and reply when complete. Do not queue live route commands until the user confirms the reload.

- [ ] **Step 5: Establish a fresh live baseline after confirmation.**

  Use the `dw-debug-loop` discipline and short replace-mode batches:

  ```powershell
  .\dw_commands.ps1 --replace freeze_npcs report_position report_runtime_blocks
  ```

  Confirm fresh command consumption in `dw_debug.log`, map `0x0B`, expected start `(29,14)` or restore it deliberately, and no stale runtime blocked tiles. Do not infer readiness from a log header alone.

- [ ] **Step 6: Exercise the service route through normal movement.**

  With NPCs represented consistently for the acceptance scenario, use the normal object/service route command rather than teleport-backed sweep tooling. Observe:

  - planner reaches `(4,5)`
  - route follows the row-2/top-bank/x=0/bridge shape
  - route does not step on `(27,0)`, `(2,4)`, `(4,7)`, or `(4,6)`
  - arrival faces south
  - TALK opens the Magic Key merchant prompt

  If execution fails after planning, inspect the exact failure edge and runtime state before changing permanent data.

- [ ] **Step 7: Record the acceptance result and update shared docs only if state materially changed.**

  On success, record the exact verified route, seller/stand/counter coordinates, key-shop prompt, and absence of runtime blocker dependence. On failure, keep uncertain evidence in `work_notes/current_investigation.md` and do not present the static implementation as live-complete.

- [ ] **Step 8: Run final verification after any documentation edits.**

  ```powershell
  git diff --check
  git status --short
  ```

  Commit only evidence-backed documentation changes with a scoped message such as:

  ```powershell
  git add session_handoff.md PLAYTESTING.md PROJECT_MEMORY.md docs/superpowers/specs/2026-07-15-rimuldar-magic-key-route-design.md
  git commit -m "docs: record verified Rimuldar key route"
  ```

## Acceptance Criteria

- Packed decoder regressions prove high/low nibble order, odd-width continuity, and raw/grid agreement.
- `test_map_reader.lua`, `test_pathfinder.lua`, `test_objects.lua`, and `test_route_manager.lua` all pass sequentially.
- Real-stack pathfinding reaches `(4,5)` from `(29,14)` in the expected 52-step route while honoring fixed NPC blockers.
- `(4,6)` is non-walkable; seller `(4,7)` is a blocker; interaction stand is `(4,5)` facing south.
- Vertical movement along x=0 remains open, while east-origin entry into `(0,1..3)` is guarded against unintended world-map transitions.
- Full static suite passes with no whitespace errors.
- After the user reloads, normal live routing reaches the Magic Key merchant and TALK opens the shop without runtime blocked-tile injection.
