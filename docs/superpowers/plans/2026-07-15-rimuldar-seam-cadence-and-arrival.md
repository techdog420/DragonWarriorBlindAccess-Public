# Rimuldar Seam Cadence and Arrival Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make one source-only autowalk travel from Rimuldar's east entry `(29,14)` through the cadence-sensitive `(1,0)->(0,0)` seam, stop safely before turning south, arrive at the Magic Key Merchant stand `(4,5)` facing south, and preserve all ordinary route safety behavior.

**Architecture:** Store the verified cadence requirement as map-scoped entry metadata in `map_reader.lua`, translate paths crossing that entry into per-boundary `continuous_hold_after_steps` markers in `route_manager.lua`, and consume those markers generically in `auto_step.lua` without changing flat per-tile queues. Reuse one route-manager arrival helper for ordinary completion and destination seam retries so event ordering, cleanup, facing, NPC hold, and speech stay consistent.

**Tech Stack:** Lua 5.1-compatible source, LuaJIT unit tests, FCEUX 2.6.6 live runtime, PowerShell, repository command queue, and `dw_debug.log`.

## Global Constraints

- Work on branch `codex/rimuldar-magic-key-correctness` in `D:\modding\dragonwarrior1`; FCEUX reloads source from this exact checkout.
- Begin from design checkpoint `923d426` and the completed static route commits before it. Do not redo the packed decoder, Rimuldar passability, or service-stand work.
- Follow strict red-green-refactor order. A production behavior change begins only after its focused regression fails for the expected reason.
- Run Lua suites sequentially with `C:\Users\developer\AppData\Local\Programs\LuaJIT\bin\luajit.exe`; plain `lua` is not reliably available on the PowerShell `PATH`.
- Keep `auto_step.lua` coordinate-free. Only `map_reader.lua` knows map `0x0B` and cell `(0,0)`.
- Keep `route_steps` as flat per-tile directions and emit exactly one `route_step_completed` event per crossed tile.
- Continuous input is opt-in and per-boundary. Ordinary routes, unmarked boundaries, survey semantics, and `settle_same_direction=false` retain their current behavior.
- A continuous run must release on its final tile before a turn or route end, even if malformed markers request otherwise.
- Hazard refusal, blocker origin, live opposite-direction cancellation, callback-driven clear/replan, timeout handling, and final neutral settle remain fail-closed.
- Do not add runtime blocked tiles, fake passability, teleports, quest gates, or a global continuous-hold configuration default.
- Do not reload `main.lua` automatically. Pause after static verification for the user to reload FCEUX Lua.
- Use short replace-mode live command batches and treat command consumption, current position, and `RUNTIME_BLOCKS map=0x0B none` as required evidence.

## File Structure

- Modify `map_reader.lua`
  - own `MAP_CONTINUOUS_HOLD_ENTRIES`
  - expose one boolean cadence-entry query without changing passability
- Modify `test_map_reader.lua`
  - prove the Rimuldar entry is map-, cell-, and approach-scoped
- Modify `route_manager.lua`
  - translate marked entries into per-step-boundary route options
  - reuse one standard arrival helper for normal and seam-retry completion
- Modify `test_route_manager.lua`
  - capture cadence options passed to `auto_step`
  - prove destination seam retry preserves event order, facing, and speech
- Modify `auto_step.lua`
  - copy route markers
  - hold marked run members through movement-start detection
  - continue same-direction marked boundaries in the same frame
  - release safely for turns, route end, hazards, cancellation, and callback changes
- Modify `test_auto_step.lua`
  - capture every `joypad.set()` call, including multiple calls in one frame
  - prove waveform continuity, per-tile events, blocker origin, hazards, cancellation, callback abort, and unchanged unmarked routes
- Update `work_notes/current_investigation.md`, `session_handoff.md`, `PLAYTESTING.md`, `PROJECT_MEMORY.md`, and the approved design spec only after successful live acceptance.

---

### Task 1: Map Cadence Metadata to Per-Boundary Route Options

**Files:**

- Modify: `map_reader.lua:4684-4690`
- Modify: `test_map_reader.lua` near the Rimuldar route regressions
- Modify: `route_manager.lua:3715-3778`, plus the four local-map queue call sites
- Modify: `test_route_manager.lua:15-592` and the service/queue regression area

**Interfaces:**

- Consumes: path nodes shaped as `{x=integer, y=integer, direction="north"|"south"|"east"|"west"}`.
- Produces: `map_reader.requires_continuous_hold_entry(map_id, x, y, approach) -> boolean`.
- Produces: `auto_step.start_route(steps, {continuous_hold_after_steps={[step_index]=true}})` where a key means “after completing this step, do not release before the next identical direction.”

- [ ] **Step 1: Add the failing map-scoped metadata regression.**

  Add this test beside the existing Rimuldar route tests in `test_map_reader.lua`:

  ```lua
  function tests.rimuldar_marks_only_verified_continuous_hold_entry()
      local env = make_env()

      assert_equal(
          env.map_reader.requires_continuous_hold_entry(0x0B, 0, 0, "east"),
          true,
          "Rimuldar (0,0) east entry should require uninterrupted input"
      )
      assert_equal(
          env.map_reader.requires_continuous_hold_entry(0x0B, 0, 0, "west"),
          false,
          "Rimuldar reverse entry should retain ordinary cadence"
      )
      assert_equal(
          env.map_reader.requires_continuous_hold_entry(0x0B, 1, 0, "east"),
          false,
          "neighboring top-bank cells should not become cadence entries"
      )
      assert_equal(
          env.map_reader.requires_continuous_hold_entry(0x0A, 0, 0, "east"),
          false,
          "continuous-hold metadata should remain map-scoped"
      )

      env.restore()
  end
  ```

- [ ] **Step 2: Run the map-reader suite and verify the expected RED result.**

  ```powershell
  $lua = 'C:\Users\developer\AppData\Local\Programs\LuaJIT\bin\luajit.exe'
  & $lua 'test_map_reader.lua'
  ```

  Expected: exit `1`; `rimuldar_marks_only_verified_continuous_hold_entry` fails because `requires_continuous_hold_entry` does not exist. All pre-existing tests remain green.

- [ ] **Step 3: Add separate cadence metadata and its boolean query.**

  Add this section immediately before `get_directional_blocks()` in `map_reader.lua`:

  ```lua
  -- ============================================================
  -- Per-Map Continuous-Hold Entry Overrides
  -- ============================================================
  -- These entries do not change passability. They identify live-passable
  -- destination approaches whose preceding straight run must keep the D-pad
  -- asserted without a release/repress gap.
  --
  -- Format: MAP_CONTINUOUS_HOLD_ENTRIES[map_id]["x,y"] = {approach=true}
  -- Approach names use the same destination-side convention as
  -- MAP_DIRECTIONAL_BLOCKS.
  local MAP_CONTINUOUS_HOLD_ENTRIES = {
      [0x0B] = {
          -- Normal westbound top-bank entry `(1,0)->(0,0)`. Raw uninterrupted
          -- LEFT movement succeeds; per-tile release/repress fails live.
          ["0,0"] = {east = true},
      },
  }

  function M.requires_continuous_hold_entry(map_id, x, y, approach)
      local map_entries = MAP_CONTINUOUS_HOLD_ENTRIES[tonumber(map_id)]
      local nx = tonumber(x)
      local ny = tonumber(y)
      if not map_entries or nx == nil or ny == nil or approach == nil then
          return false
      end
      local key = tostring(math.floor(nx)) .. "," .. tostring(math.floor(ny))
      local entry = map_entries[key]
      return type(entry) == "table" and entry[tostring(approach)] == true
  end
  ```

- [ ] **Step 4: Run the map-reader suite and verify GREEN.**

  ```powershell
  & $lua 'test_map_reader.lua'
  ```

  Expected: exit `0`; `66` tests pass. No walkability or directional-block expectation changes.

- [ ] **Step 5: Extend the route-manager test stub and add the failing marker regression.**

  In `test_route_manager.lua`'s `map_reader` stub, add:

  ```lua
  requires_continuous_hold_entry = function(map_id, x, y, approach)
      local by_map = options.continuous_hold_entries
          and options.continuous_hold_entries[map_id]
      local entry = by_map and by_map[tostring(x) .. "," .. tostring(y)]
      return type(entry) == "table" and entry[approach] == true
  end,
  ```

  Then add this test near the existing queue-option regressions:

  ```lua
  function tests.rimuldar_path_marks_only_internal_boundaries_before_cadence_entry()
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
          continuous_hold_entries = {
              [0x0B] = { ["0,0"] = {east = true} },
          },
          pathfind_to_fn = function()
              return "Path: north, 3 west, south, east", "east", path
          end,
      })

      local result = env.route_manager.autowalk_to_object(target, {speak = false})
      local markers = env.last_start_route_opts().continuous_hold_after_steps

      assert_equal(result.status, "queued", "synthetic Rimuldar route should queue")
      assert_equal(markers and markers[2], true, "first internal west boundary should stay held")
      assert_equal(markers and markers[3], true, "second internal west boundary should stay held")
      assert_equal(markers and markers[1], nil, "turn into the west run should retain ordinary input")
      assert_equal(markers and markers[4], nil, "entry tile should release before the south turn")
      assert_equal(markers and markers[5], nil, "south turn should not inherit west continuity")

      env.restore()
  end
  ```

- [ ] **Step 6: Run the route-manager suite and verify the expected RED result.**

  ```powershell
  & $lua 'test_route_manager.lua'
  ```

  Expected: exit `1`; the new test fails because `continuous_hold_after_steps` is absent. Existing route-manager tests remain green.

- [ ] **Step 7: Build markers inside every local-path queue operation.**

  Add this helper immediately before `queue_path_steps()` in `route_manager.lua`:

  ```lua
  local function continuous_hold_after_steps_for_path(map_id, path, start_x, start_y)
      if not map_reader.requires_continuous_hold_entry then
          return nil
      end

      local markers = {}
      for entry_index, step in ipairs(path or {}) do
          local key_dir = DIR_NAME_TO_KEY[step.direction]
          local approach = key_dir and DIR_TO_APPROACH[key_dir]
          if approach
             and map_reader.requires_continuous_hold_entry(
                  map_id, step.x, step.y, approach) then
              local run_start = entry_index
              while run_start > 1
                and path[run_start - 1].direction == step.direction do
                  run_start = run_start - 1
              end

              for completed_index = run_start, entry_index - 1 do
                  markers[completed_index] = true
              end

              if entry_index > run_start then
                  local origin = run_start == 1
                      and {x = start_x, y = start_y}
                      or path[run_start - 1]
                  debug_tools.info(string.format(
                      "AUTO_WALK_CONTINUOUS_RUN map=0x%02X from=(%d,%d) dest=(%d,%d) dir=%s steps=%d-%d",
                      map_id or -1,
                      tonumber(origin and origin.x) or -1,
                      tonumber(origin and origin.y) or -1,
                      tonumber(step.x) or -1,
                      tonumber(step.y) or -1,
                      tostring(key_dir),
                      run_start,
                      entry_index))
              end
          end
      end

      return next(markers) and markers or nil
  end
  ```

  In `queue_path_steps()`, resolve the map after deriving `start_x/start_y`:

  ```lua
  local live_map_id = select(1, nav.get_position())
  local map_id = tonumber(opts.map_id) or live_map_id
  local continuous_hold_after_steps = continuous_hold_after_steps_for_path(
      map_id, path, start_x, start_y)
  ```

  Pass it to `auto_step.start_route()`:

  ```lua
  continuous_hold_after_steps = continuous_hold_after_steps,
  ```

  Pass explicit `map_id` at all four local-path queue sites:

  ```lua
  -- Initial autowalk plan
  map_id = plan.map_id,

  -- Route-drift reroute
  map_id = map_id,

  -- Blocked-step reroute
  map_id = map_id,

  -- Seam-retry follow-up
  map_id = map_id,
  ```

  Keep `queue_overworld_segment_steps()` unchanged because its route segments do not carry local-map destination nodes.

- [ ] **Step 8: Verify Task 1 GREEN and commit the interface.**

  ```powershell
  & $lua 'test_map_reader.lua'
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $lua 'test_route_manager.lua'
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  git diff --check
  git diff -- map_reader.lua test_map_reader.lua route_manager.lua test_route_manager.lua
  git add map_reader.lua test_map_reader.lua route_manager.lua test_route_manager.lua
  git commit -m "feat: mark Rimuldar cadence-sensitive route run"
  ```

  Expected: map-reader `66/66`; route-manager `105/105`; no whitespace errors. The only new executor input is the ignored-by-old-source `continuous_hold_after_steps` option.

---

### Task 2: Execute Marked Straight Runs Without Any Neutral Gap

**Files:**

- Modify: `test_auto_step.lua:18-205` and queued-route regression area
- Modify: `auto_step.lua:120-185`, `340-430`, `530-830`, `1081-1160`, `1370-1470`, `1754-1830`

**Interfaces:**

- Consumes: `opts.continuous_hold_after_steps={[completed_step_index]=true}` from Task 1.
- Preserves: flat `route_steps`, one `route_step_completed` per tile, `route_index` as the next unstarted step, and all callback/event signatures.
- Produces: no neutral `joypad.set()` call anywhere inside a marked same-direction run, including movement-start detection; normal neutral release on the final run tile.

- [ ] **Step 1: Capture every injected call instead of only the last call per frame.**

  In `make_env()` add `local injected_calls = {}`. Replace the test joypad setter with:

  ```lua
  set = function(_, buttons)
      local copied = {}
      for key, value in pairs(buttons or {}) do
          copied[key] = value
      end
      injected[frame] = copied
      injected_calls[#injected_calls + 1] = {frame = frame, buttons = copied}
      if opts.sticky_joypad_set then
          sticky_joy = copied
      end
  end,
  ```

  Expose `injected_calls = injected_calls` from the environment and add:

  ```lua
  local function injection_calls_for_frame(env, wanted_frame)
      local calls = {}
      for _, call in ipairs(env.injected_calls) do
          if call.frame == wanted_frame then
              calls[#calls + 1] = call.buttons
          end
      end
      return calls
  end

  local function assert_frame_only_direction(env, frame, dir, message)
      local calls = injection_calls_for_frame(env, frame)
      assert_truthy(#calls > 0, message .. " should inject on frame " .. frame)
      for _, buttons in ipairs(calls) do
          assert_equal(buttons[dir], true, message .. " should keep " .. dir .. " pressed")
          for _, other in ipairs({"up", "down", "left", "right"}) do
              if other ~= dir then
                  assert_truthy(not buttons[other], message .. " should not press " .. other)
              end
          end
      end
  end

  local function assert_frame_neutral(env, frame, message)
      local calls = injection_calls_for_frame(env, frame)
      assert_truthy(#calls > 0, message .. " should inject on frame " .. frame)
      for _, buttons in ipairs(calls) do
          assert_truthy(not has_any_direction(buttons), message .. " should be neutral")
      end
  end
  ```

- [ ] **Step 2: Add the complete RED regression set.**

  Add these tests beside the existing queued-route tests:

  ```lua
  function tests.marked_run_holds_through_movement_start_and_releases_before_turn()
      local env = make_env({sticky_joypad_set = true})
      env.auto_step.start_route({"right", "right", "down"}, {
          start_x = 3,
          start_y = 1,
          continuous_hold_after_steps = {[1] = true, [2] = true},
      })

      env.update(true)
      env.set_subpixel(0x20)
      env.update(true)
      env.set_position(4, 1)
      env.update(true)
      env.set_subpixel(0x30)
      env.update(true)
      env.set_position(5, 1)
      env.update(true)

      for frame = 1, 4 do
          assert_frame_only_direction(env, frame, "right", "marked straight run")
      end
      assert_frame_neutral(env, 5, "marked run before direction change")

      local completed = {}
      for _, event in ipairs(env.published) do
          if event.name == "route_step_completed" then
              completed[#completed + 1] = event.payload
          end
      end
      assert_equal(#completed, 2, "marked run should emit one completion per crossed tile")
      assert_equal(completed[1].from_x, 3, "first marked step should retain its origin")
      assert_equal(completed[1].to_x, 4, "first marked step should retain its destination")
      assert_equal(completed[2].from_x, 4, "second marked step should rebase its origin")
      assert_equal(completed[2].to_x, 5, "second marked step should retain its destination")

      env.restore()
  end

  function tests.marked_run_final_tile_neutralizes_before_route_complete()
      local env = make_env({
          sticky_joypad_set = true,
          config_values = {auto_step_route_final_settle_frames = "5"},
      })
      env.auto_step.start_route({"right", "right"}, {
          start_x = 3,
          start_y = 1,
          continuous_hold_after_steps = {[1] = true},
      })

      env.update(true)
      env.set_subpixel(0x20)
      env.update(true)
      env.set_position(4, 1)
      env.update(true)
      env.set_subpixel(0x30)
      env.update(true)
      env.set_position(5, 1)
      env.update(true)

      assert_frame_neutral(env, 5, "final marked tile")
      for _, event in ipairs(env.published) do
          assert_truthy(event.name ~= "route_completed", "final settle should delay route completion")
      end
      for _ = 1, 10 do env.update(true) end
      local count = 0
      for _, event in ipairs(env.published) do
          if event.name == "route_completed" then count = count + 1 end
      end
      assert_equal(count, 1, "marked route should complete exactly once after neutral settle")

      env.restore()
  end

  function tests.marked_boundary_refuses_next_hazard_before_continuing()
      local env = make_env({
          sticky_joypad_set = true,
          hazard_cells = {[0x05] = {["5,1"] = "damage"}},
      })
      env.auto_step.start_route({"right", "right"}, {
          start_x = 3,
          start_y = 1,
          continuous_hold_after_steps = {[1] = true},
      })

      env.update(true)
      env.set_position(4, 1)
      env.update(true)

      assert_frame_neutral(env, 2, "hazard refusal inside marked run")
      assert_equal(env.auto_step.is_route_active(), false, "hazard refusal should clear the marked route")
      local completed = 0
      local cancelled = nil
      for _, event in ipairs(env.published) do
          if event.name == "route_step_completed" then completed = completed + 1 end
          if event.name == "route_cancelled" then cancelled = event.payload end
      end
      assert_equal(completed, 1, "hazard refusal should preserve the completed safe tile")
      assert_equal(cancelled and cancelled.reason, "dangerous_tile", "hazard should cancel before the next tile")
      assert_equal(cancelled and cancelled.dest_x, 5, "hazard cancellation should report destination X")
      assert_equal(cancelled and cancelled.dest_y, 1, "hazard cancellation should report destination Y")

      env.restore()
  end

  function tests.marked_boundary_rebases_block_watchdog_origin()
      local env = make_env({
          config_values = {
              auto_step_timeout = "4",
              auto_step_turn_repress_limit = "0",
              auto_step_block_retry_limit = "0",
          },
      })
      env.auto_step.start_route({"right", "right"}, {
          start_x = 3,
          start_y = 1,
          continuous_hold_after_steps = {[1] = true},
      })

      env.update(true)
      env.set_position(4, 1)
      env.update(true)
      local active = env.auto_step.get_active_step_state()
      assert_equal(active and active.start_x, 4, "continued step should rebase blocker origin X")
      assert_equal(active and active.start_y, 1, "continued step should rebase blocker origin Y")
      for _ = 1, 6 do env.update(true) end

      local blocked = nil
      for _, event in ipairs(env.published) do
          if event.name == "route_blocked" then blocked = event.payload end
      end
      assert_equal(blocked and blocked.from_x, 4, "continuous timeout should report current origin X")
      assert_equal(blocked and blocked.from_y, 1, "continuous timeout should report current origin Y")
      assert_equal(blocked and blocked.dir, "right", "continuous timeout should report current direction")
      assert_equal(blocked and blocked.queued_route, true, "continuous timeout should remain a queued-route block")

      env.restore()
  end

  function tests.opposite_input_cancels_active_continuous_step()
      local env = make_env({sticky_joypad_set = true})
      env.auto_step.start_route({"right", "right"}, {
          start_x = 3,
          start_y = 1,
          continuous_hold_after_steps = {[1] = true},
      })

      env.update(true)
      env.set_position(4, 1)
      env.update(true)
      env.set_joy({left = true})
      env.update(true)

      assert_frame_neutral(env, 3, "opposite input during continuous route")
      assert_equal(env.auto_step.is_route_active(), false, "opposite input should stop continuous route")
      local cancelled = nil
      for _, event in ipairs(env.published) do
          if event.name == "route_cancelled" then cancelled = event.payload end
      end
      assert_equal(cancelled and cancelled.reason, "live_input_interrupt", "opposite input should use normal cancellation")
      assert_equal(cancelled and cancelled.active_dir, "right", "cancellation should report injected direction")

      env.restore()
  end

  function tests.completion_callback_can_abort_marked_continuation()
      local env = make_env({sticky_joypad_set = true})
      env.auto_step.on_step_complete = function()
          env.auto_step.clear_route()
      end
      env.auto_step.start_route({"right", "right"}, {
          start_x = 3,
          start_y = 1,
          continuous_hold_after_steps = {[1] = true},
      })

      env.update(true)
      env.set_position(4, 1)
      env.update(true)

      assert_frame_neutral(env, 2, "callback-cleared marked route")
      assert_equal(env.auto_step.is_route_active(), false, "completion callback should be able to clear route")

      env.restore()
  end

  function tests.unmarked_same_direction_route_keeps_forced_release()
      local env = make_env({sticky_joypad_set = true})
      env.auto_step.start_route({"right", "right"}, {start_x = 3, start_y = 1})

      env.update(true)
      env.set_position(4, 1)
      env.update(true)

      assert_frame_neutral(env, 2, "ordinary same-direction route")

      env.restore()
  end
  ```

- [ ] **Step 3: Run the auto-step suite and verify the expected RED result.**

  ```powershell
  & $lua 'test_auto_step.lua'
  ```

  Expected: exit `1`. The first marked test reports a neutral call during frames `2` or `3`; hazard evaluation is delayed; blocker origin is not rebased immediately. The existing `88` tests remain green.

- [ ] **Step 4: Add copied marker state and per-active-step hold state.**

  Add state beside the existing route and active-step fields:

  ```lua
  local auto_continuous_hold = false
  local route_continuous_hold_after_steps = nil
  ```

  Reset `auto_continuous_hold = false` in `reset_active_step()`. Reset `route_continuous_hold_after_steps = nil` in `clear_route()`. Copy the active flag into `pending_repress` in `schedule_turn_repress()`:

  ```lua
  continuous_hold = auto_continuous_hold,
  ```

  After constructing `pending_repress`, set `auto_continuous_hold = false` alongside the existing `auto_dir/auto_frames/auto_start_x/auto_start_y` resets. The pending state owns the flag until `begin_step()` restores it.

  Restore it in `begin_step()`:

  ```lua
  auto_continuous_hold = state and state.continuous_hold == true or false
  ```

  Make movement-start and pre-start injection respect it:

  ```lua
  local function should_hold_after_movement_start()
      if auto_continuous_hold then
          return true
      end
      -- retain the existing body after this guard
  end
  ```

  In the ordinary pre-timeout injection branch, place this condition before the inject-limit fallback:

  ```lua
  elseif auto_continuous_hold and not auto_movement_started then
      joypad.set(1, {[auto_dir] = true})
  ```

- [ ] **Step 5: Add coordinate-free route-marker and step-start helpers.**

  Add these helpers after `step_destination()` and the forward declaration of `refuse_hazard_step`:

  ```lua
  local function copy_continuous_hold_markers(markers, step_count)
      local copied = {}
      for raw_index, enabled in pairs(type(markers) == "table" and markers or {}) do
          local index = tonumber(raw_index)
          if enabled == true and index ~= nil then
              index = math.floor(index)
              if index >= 1 and index < step_count then
                  copied[index] = true
              end
          end
      end
      return next(copied) and copied or nil
  end

  local function continuous_hold_after_step(step_index)
      return route_continuous_hold_after_steps ~= nil
          and route_continuous_hold_after_steps[step_index] == true
  end

  local function queued_step_uses_continuous_hold(step_index)
      return continuous_hold_after_step(step_index)
          or continuous_hold_after_step(step_index - 1)
  end

  local function log_continuous_hold(event_name, step_index, dir, from_x, from_y, reason)
      local map_id = select(1, nav.get_position())
      local dest_x, dest_y = step_destination(from_x, from_y, dir)
      debug_tools.info(string.format(
          "AUTO_STEP_CONTINUOUS_HOLD event=%s map=0x%02X from=(%d,%d) dest=(%d,%d) dir=%s step=%d reason=%s",
          tostring(event_name),
          map_id or -1,
          from_x or -1,
          from_y or -1,
          dest_x or -1,
          dest_y or -1,
          tostring(dir),
          step_index or -1,
          tostring(reason or "-")))
  end

  local function build_queued_step_opts(step_index, next_dir, event_name)
      local step_opts = {
          source = "queued_route",
          continuous_hold = queued_step_uses_continuous_hold(step_index),
      }
      if queued_route_continuing_step_before_turn(next_dir) then
          step_opts.inject_limit = get_route_pre_turn_inject_limit()
      end
      if route_hold_after_movement_start_frames_override ~= nil then
          step_opts.hold_after_movement_start = true
          step_opts.hold_after_movement_start_frames = route_hold_after_movement_start_frames_override
      end
      if step_opts.continuous_hold then
          log_continuous_hold(event_name or "enter", step_index, next_dir,
              route_last_x, route_last_y)
      end
      return step_opts
  end

  local function begin_next_queued_route_step(px, py, event_name)
      local step_index = route_index
      local next_dir = route_steps and route_steps[step_index]
      if not next_dir then
          return false, "route_end", nil
      end
      if refuse_hazard_step(next_dir, px, py, "queued_route") then
          return false, "hazard_refused", next_dir
      end
      local step_opts = build_queued_step_opts(step_index, next_dir, event_name)
      route_index = step_index + 1
      begin_step(next_dir, px, py, step_opts)
      return true, nil, next_dir
  end
  ```

  In `start_route()`, after copying `steps`, copy the markers rather than retaining caller state:

  ```lua
  route_continuous_hold_after_steps = copy_continuous_hold_markers(
      opts.continuous_hold_after_steps, #route_steps)
  ```

  Update the public options comment to include `continuous_hold_after_steps={[step_index]=true}`.

- [ ] **Step 6: Continue marked boundaries in the completion frame, after the per-tile callback.**

  In the successful coordinate-change branch of `handle_active_auto_step()`, capture these values before `reset_active_step()`:

  ```lua
  local completed_route_steps = route_steps
  local completed_next_index = route_index
  local completed_step_index = completed_next_index - 1
  local completed_continuous_hold = auto_continuous_hold
  local next_route_dir = completed_route_steps
      and completed_route_steps[completed_next_index]
  local marked_continuation = completed_queued_route
      and continuous_hold_after_step(completed_step_index)
      and next_route_dir == completed_dir
  ```

  Before the existing release block, add this complete marked branch:

  ```lua
  if marked_continuation then
      reset_active_step()
      route_last_x = px
      route_last_y = py
      emit_step_complete(completed_from_x, completed_from_y, completed_dir, px, py, "auto_hold", {
          input_source = completed_source,
          timeout_retries = completed_retries,
          turn_represses = completed_turn_represses,
          frames = completed_frames,
          inject_limit = completed_inject_limit,
      })

      if route_steps == completed_route_steps
         and route_index == completed_next_index then
          local started, reason = begin_next_queued_route_step(px, py, "continue")
          if started then
              cooldown = 0
              post_step_release_frames = 0
              sync_prev_held(joy)
              return true
          end

          cooldown = COOLDOWN_FRAMES
          neutralize_direction(joy)
          start_post_step_release(true)
          log_continuous_hold("exit", completed_step_index, completed_dir,
              completed_from_x, completed_from_y, reason)
          sync_prev_held(joy)
          return true
      end

      cooldown = COOLDOWN_FRAMES
      neutralize_direction(joy)
      start_post_step_release(true)
      log_continuous_hold("exit", completed_step_index, completed_dir,
          completed_from_x, completed_from_y, "callback_changed_route")
      sync_prev_held(joy)
      return true
  end
  ```

  Keep the unmarked release block semantically unchanged:

  ```lua
  reset_active_step()
  cooldown = COOLDOWN_FRAMES
  neutralize_direction(joy)
  start_post_step_release(should_force_post_step_release(completed_source, completed_queued_route))
  if route_steps then
      route_last_x = px
      route_last_y = py
      route_settle_frames = route_settle_after_step(completed_dir)
  end
  if completed_source == "seam_retry" then
      reset_movement_engine_state("seam_retry_complete")
  elseif completed_queued_route and route_steps ~= nil and route_steps[route_index] == nil then
      if route_settle_reset_movement_active then
          reset_movement_engine_state("queued_route_final_complete")
      end
  elseif completed_queued_route and route_steps ~= nil then
      reset_movement_for_route_settle()
  end
  if completed_continuous_hold then
      local exit_reason = next_route_dir == nil and "route_end" or "direction_change"
      log_continuous_hold("exit", completed_step_index, completed_dir,
          completed_from_x, completed_from_y, exit_reason)
  end
  emit_step_complete(completed_from_x, completed_from_y, completed_dir, px, py, "auto_hold", {
      input_source = completed_source,
      timeout_retries = completed_retries,
      turn_represses = completed_turn_represses,
      frames = completed_frames,
      inject_limit = completed_inject_limit,
  })
  ```

  The callback runs before continuation only for marked internal boundaries. The identity/index checks ensure a callback can clear or replace the route without an old step leaking into the new route.

- [ ] **Step 7: Reuse the step-start helper for ordinary queue progress.**

  Replace the duplicated `next_dir` option/hazard/start block in `handle_route_progress()` with:

  ```lua
  local next_dir = route_steps[route_index]
  if next_dir then
      local started, reason = begin_next_queued_route_step(px, py, "enter")
      if started or reason == "hazard_refused" then
          if reason == "hazard_refused" then
              neutralize_direction(joy)
              start_post_step_release(true)
          end
          sync_prev_held(joy)
          return true
      end
  end
  ```

  Leave the existing route-end `clear_route()`, `route_completed` publication, and callback immediately after this block.

- [ ] **Step 8: Run focused executor tests and inspect the waveform-sensitive diff.**

  ```powershell
  & $lua 'test_auto_step.lua'
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $lua 'test_route_manager.lua'
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  git diff --check
  git diff -- auto_step.lua test_auto_step.lua route_manager.lua test_route_manager.lua
  ```

  Expected: auto-step `95/95` and route-manager `105/105`. Frames inside the marked run contain only RIGHT calls, the turn/final frame contains only neutral calls, and all original `88` auto-step tests remain green.

- [ ] **Step 9: Commit the generic executor behavior.**

  ```powershell
  git add auto_step.lua test_auto_step.lua
  git commit -m "fix: preserve marked straight route holds"
  ```

---

### Task 3: Use Standard Arrival Behavior After a Destination Seam Retry

**Files:**

- Modify: `test_route_manager.lua:20-592` and seam-retry tests near line 2542
- Modify: `route_manager.lua:4611-4690`

**Interfaces:**

- Consumes: existing active-route target, face direction, completion-action policy, speech policy, step totals, hazard stop, and overworld state.
- Produces: `finish_active_route_arrival(reason, opts)` as a private route-manager helper.
- Preserves event ownership: auto-step owns `route_step_completed`; normal queued completion already publishes `route_completed`; only an injected destination seam retry asks the helper to publish `route_completed`.

- [ ] **Step 1: Expose test event publication and add the failing merchant seam-arrival regression.**

  In `make_env()`, define one publisher before the event-bus stub:

  ```lua
  local function publish_event(name, payload)
      published_events[#published_events + 1] = {name = name, payload = payload}
  end
  ```

  Use `publish = publish_event` in the stub and expose `publish_event = publish_event` from the returned environment. Add this test beside `successful_seam_bruteforce_at_destination_publishes_route_complete`:

  ```lua
  function tests.rimuldar_destination_seam_uses_standard_south_facing_arrival()
      local merchant = {
          id = "npc_12",
          name = "Magic Key Merchant",
          type = "npc",
          x = 4,
          y = 7,
          interaction_x = 4,
          interaction_y = 5,
          interaction_face_dir = "south",
      }
      local env = make_env({
          start_map_id = 0x0B,
          start_x = 4,
          start_y = 4,
          current_object = merchant,
          object_list = {merchant},
          config_values = {
              auto_walk_npc_hold_frames = "0",
              auto_walk_face_target_frames = "1",
          },
          pathfind_to_fn = function(start_x, start_y)
              if start_x == 4 and start_y == 4 then
                  return "Path: 1 south", "south", {
                      {x = 4, y = 5, direction = "south"},
                  }
              end
              if start_x == 4 and start_y == 5 then
                  return "Already there", "south", {}
              end
          end,
      })

      local queued = env.route_manager.autowalk_to_object(merchant)
      assert_equal(queued.status, "queued", "merchant seam test should queue its opening step")
      env.auto_step.on_blocked(4, 4, "down", {
          queued_route = true,
          movement_started = true,
          movement_start_frame = 5,
      })
      env.publish_event("route_step_completed", {
          from_x = 4, from_y = 4, dir = "down", to_x = 4, to_y = 5,
          source = "auto_hold", input_source = "seam_retry", queued_route = false,
      })
      env.auto_step.on_step_complete(4, 4, "down", 4, 5, {
          queued_route = false,
          source = "auto_hold",
          input_source = "seam_retry",
      })

      local step_index = nil
      local route_index = nil
      local route_count = 0
      for index, event in ipairs(env.published_events()) do
          if event.name == "route_step_completed" then step_index = index end
          if event.name == "route_completed" then
              route_index = index
              route_count = route_count + 1
          end
      end

      assert_equal(env.inject_step_calls(), 1, "blocked route should use one seam retry")
      assert_equal(env.start_route_calls(), 1, "destination seam should not queue an empty follow-up")
      assert_equal(route_count, 1, "destination seam should publish route completion exactly once")
      assert_truthy(step_index and route_index and step_index < route_index,
          "tile completion should precede route completion")
      assert_equal(env.suppress_direction_tracking_calls(), 1,
          "standard seam arrival should queue safe facing suppression")
      env.route_manager.apply_npc_freeze()
      assert_equal(env.joypad_sets[#env.joypad_sets].buttons.down, true,
          "destination seam arrival should face south toward the seller")
      assert_contains(table.concat(env.outputs, "\n"),
          "Auto-walk complete. Arrived at Magic Key Merchant",
          "destination seam should use standard completion speech")

      env.restore()
  end
  ```

- [ ] **Step 2: Run the route-manager suite and verify the expected RED result.**

  ```powershell
  & $lua 'test_route_manager.lua'
  ```

  Expected: exit `1`; route completion is published, but facing suppression is `0`, no DOWN input is queued, and output uses the shortened `Seam crossed` message.

- [ ] **Step 3: Extract one complete arrival helper and route both completion paths through it.**

  Replace the body of `auto_step.on_route_complete` with this private helper plus wrapper:

  ```lua
  local function finish_active_route_arrival(reason, opts)
      opts = opts or {}
      local overworld_segment = active_overworld_segment
      local target = opts.target or active_route_target or last_pathfind_obj
      local face_dir = opts.face_dir or active_route_face_dir
      local total_steps = active_route_total_steps
      local completion_actions = active_route_completion_actions
      local speak_completion = active_route_speak_completion
      local hazard_stop = active_route_hazard_stop

      if opts.publish_route_completed == true then
          event_bus.publish("route_completed")
      end
      clear_active_route_context(reason or "autowalk route complete",
          should_refresh_objects_after_route())

      if overworld_segment then
          debug_tools.info(string.format(
              "OVERWORLD_AUTO_WALK: event=complete route=%s waypoint=%s index=%s steps=%s",
              tostring(overworld_segment.route_id or "-"),
              tostring(overworld_segment.waypoint_name or "-"),
              tostring(overworld_segment.index),
              tostring(overworld_segment.steps)))
      end

      if target then
          if hazard_stop then
              local msg = "Auto-walk stopped before hazard"
              if total_steps and total_steps > 0 then
                  msg = msg .. string.format(" after %d steps", total_steps)
              end
              msg = msg .. ". " .. build_hazard_warning(hazard_stop.summary)
              if speak_completion then
                  tolk.output_interrupt(msg)
              end
              return
          end

          local msg = string.format("Auto-walk complete. Arrived at %s",
              target.name or "destination")
          if total_steps and total_steps > 0 then
              msg = msg .. string.format(" after %d steps", total_steps)
          end
          if completion_actions then
              queue_target_face(face_dir, target)
          end
          if completion_actions
             and target.type == objects.TYPE_NPC
             and start_target_npc_hold(target) then
              msg = msg .. ". Target held briefly. Use TALK now"
          end
          if speak_completion then
              tolk.output_interrupt(msg)
          end
      elseif speak_completion then
          tolk.output_interrupt("Auto-walk complete")
      end
  end

  auto_step.on_route_complete = function()
      finish_active_route_arrival("autowalk route complete")
  end
  ```

  Replace only the no-path-empty successful seam-destination branch with:

  ```lua
  finish_active_route_arrival("seam brute force reached destination", {
      target = target,
      face_dir = should_face_after_plan(plan) and plan.face_dir or nil,
      publish_route_completed = true,
  })
  return
  ```

  Do not call `auto_step.on_route_complete()` recursively and do not publish a second `route_step_completed` event from `route_manager.lua`.

- [ ] **Step 4: Verify arrival behavior and all route-manager regressions.**

  ```powershell
  & $lua 'test_route_manager.lua'
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $lua 'test_auto_step.lua'
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  git diff --check
  git diff -- route_manager.lua test_route_manager.lua
  ```

  Expected: route-manager `106/106`; auto-step `95/95`. Existing survey-safe seam completion stays silent and injects no arrival input; normal completion, NPC holds, overworld logging, hazard speech, object refresh, and completion totals remain unchanged.

- [ ] **Step 5: Commit the shared arrival path.**

  ```powershell
  git add route_manager.lua test_route_manager.lua
  git commit -m "fix: finish seam arrivals normally"
  ```

---

### Task 4: Static Verification, Manual Reload, Live Acceptance, and Durable Handoff

**Files:**

- Verify: `map_reader.lua`, `route_manager.lua`, `auto_step.lua`, and their test files
- Modify after successful live evidence: `work_notes/current_investigation.md`
- Modify after successful live evidence: `session_handoff.md`
- Modify after successful live evidence: `PLAYTESTING.md`
- Modify after successful live evidence: `PROJECT_MEMORY.md`
- Modify after successful live evidence: `docs/superpowers/specs/2026-07-15-rimuldar-magic-key-route-design.md`

**Interfaces:**

- Consumes: user-confirmed manual FCEUX Lua reload.
- Produces: one live source-only route result with exact position, continuous-run logs, completion/facing state, shop dialogue, and runtime-block state.

- [ ] **Step 1: Run fresh focused suites sequentially.**

  ```powershell
  $lua = 'C:\Users\developer\AppData\Local\Programs\LuaJIT\bin\luajit.exe'
  & $lua 'test_map_reader.lua'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $lua 'test_auto_step.lua'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $lua 'test_route_manager.lua'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $lua 'test_pathfinder.lua'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $lua 'test_objects.lua'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  ```

  Expected: map reader `66/66`, auto-step `95/95`, route manager `106/106`, pathfinder `19/19`, and objects `99/99`.

- [ ] **Step 2: Run the repository suite, syntax checks, and clean-diff checks.**

  ```powershell
  $env:PATH = 'C:\Users\developer\AppData\Local\Programs\LuaJIT\bin;C:\Program Files\Git\bin;' + $env:PATH
  python run_tests.py --allow-missing-speech-dep
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $lua -b 'map_reader.lua' 'NUL'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $lua -b 'route_manager.lua' 'NUL'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $lua -b 'auto_step.lua' 'NUL'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $lua -b 'test_map_reader.lua' 'NUL'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $lua -b 'test_route_manager.lua' 'NUL'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & $lua -b 'test_auto_step.lua' 'NUL'; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  git diff --check
  git status --short
  ```

  Expected: runner exit `0`, every bytecode check exit `0`, and no whitespace errors. Only planned files or post-plan documentation are modified.

- [ ] **Step 3: Pause for the user to reload `main.lua`.**

  Report the exact commits and static counts. Do not queue live acceptance until the user confirms the script reload.

- [ ] **Step 4: Establish a fresh normal-entry baseline.**

  Restore the known Rimuldar-entry save or leave/re-enter town through normal play so the hero is map `0x0B` at `(29,14)`. Do not use a teleport-backed setup as route proof. Then run:

  ```powershell
  .\dw_commands.ps1 --replace launcher_probe:rimuldar_cadence_accept freeze_npcs report_position report_runtime_blocks report_path_state
  ```

  Confirm a fresh `launcher_probe` result, `POSITION map=0x0B(Rimuldar) x=29 y=14`, no active route, and `RUNTIME_BLOCKS map=0x0B none`.

- [ ] **Step 5: Select the service and run one uninterrupted source-only autowalk.**

  Use short `next_filter current_object` and `next_object current_object` batches until `current_object` reports `Magic Key Merchant` at seller `(4,7)` with interaction `(4,5)`. Then:

  ```powershell
  .\dw_commands.ps1 --replace auto_walk report_path_state
  ```

  Wait for fresh log consumption. Required evidence:

  - planner queues `52` steps from `(29,14)` to `(4,5)`;
  - `AUTO_WALK_CONTINUOUS_RUN` identifies the westbound run ending at `(0,0)`;
  - `AUTO_STEP_CONTINUOUS_HOLD event=enter` and `event=continue` occur with no intervening block/retry;
  - `event=exit ... reason=direction_change` occurs on arrival at `(0,0)` before DOWN;
  - no map change to `0x01` occurs;
  - exactly one route completion occurs;
  - final player position is `(4,5)` facing south;
  - `RUNTIME_BLOCKS map=0x0B none` remains true.

- [ ] **Step 6: Open and verify the 53 GOLD shop prompt.**

  With arrival facing already south, run these as separate consumed commands:

  ```powershell
  .\dw_commands.ps1 --replace simulate_input:A report_menu_state
  .\dw_commands.ps1 --replace simulate_input:A report_menu_state
  ```

  Confirm dialogue contains `Magic keys!`, `purchase one for 53`, and `GOLD?`, with `yesno=true`. Cancel without purchasing and record final state:

  ```powershell
  .\dw_commands.ps1 --replace simulate_input:B report_position report_runtime_blocks
  ```

- [ ] **Step 7: Update shared project state only after every live criterion passes.**

  Replace the stale `SOURCE GAPS` bullet in `work_notes/current_investigation.md` and add this verified result:

  ```markdown
  - EXECUTOR ACCEPTANCE: after the cadence/arrival reload, one selected-service
    autowalk planned 52 steps from Rimuldar entry `(29,14)` and completed at
    Magic Key stand `(4,5)`. The westbound top-bank run stayed continuously
    held into `(0,0)`, released before DOWN, never changed to the World Map,
    and required no runtime blocker.
  - ARRIVAL ACCEPTANCE: route completion occurred once, queued the standard
    south-facing arrival, and TALK opened `purchase one for 53 GOLD?`.
    Final runtime overlay remained `RUNTIME_BLOCKS map=0x0B none`.
  ```

  Insert this bullet at the top of `session_handoff.md`'s Immediate FCEUX Handoff and near the top of `PLAYTESTING.md`:

  ```markdown
  - 2026-07-15 Rimuldar Magic Key route is source-only live-complete. From
    normal entry `(29,14)`, selected-service autowalk follows the 52-step
    row-2 / x=21 / top-bank / x=0 / northwest-bridge route to public stand
    `(4,5)`. Map-scoped cadence metadata keeps the west run uninterrupted into
    `(0,0)` and releases before the south turn; no World Map overshoot or
    runtime block occurs. Destination seam completion uses the standard
    arrival path, faces south once, and TALK opens the 53 G key prompt.
  ```

  Add this durable statement in the Rimuldar section of `PROJECT_MEMORY.md`:

  ```markdown
  - Rimuldar map `0x0B` has one cadence-sensitive entry: `(0,0)` approached
    from the east. `route_manager.lua` marks only the preceding contiguous
    westbound path boundaries, while generic `auto_step.lua` holds those tiles
    without neutral input and releases on `(0,0)` before turning south. Keep
    this metadata separate from passability and never make continuous hold a
    global route default.
  ```

  In the design spec, change the status to:

  ```markdown
  Status: Implemented and live-verified in FCEUX
  ```

  Append the exact source commit IDs and focused test totals under `Live Acceptance Findings`.

- [ ] **Step 8: Run documentation checks, request code review, and commit the acceptance record.**

  ```powershell
  git diff --check
  git status --short
  git diff -- work_notes/current_investigation.md session_handoff.md PLAYTESTING.md PROJECT_MEMORY.md docs/superpowers/specs/2026-07-15-rimuldar-magic-key-route-design.md
  git add work_notes/current_investigation.md session_handoff.md PLAYTESTING.md PROJECT_MEMORY.md docs/superpowers/specs/2026-07-15-rimuldar-magic-key-route-design.md
  git commit -m "docs: record verified Rimuldar key route"
  ```

  Before claiming completion, invoke `superpowers:requesting-code-review`, resolve every critical or important finding through a fresh RED/GREEN cycle, then invoke `superpowers:verification-before-completion` and rerun the focused and repository verification commands.

## Acceptance Criteria

- `map_reader.requires_continuous_hold_entry(0x0B, 0, 0, "east")` alone is true for the verified cadence entry and approach.
- A path crossing that entry marks only internal boundaries in its preceding contiguous westbound run.
- Every `joypad.set()` call through a marked run keeps the same direction asserted, including movement-start frames.
- The final west tile releases before the south turn and a marked final route tile neutralizes before route completion.
- Exactly one `route_step_completed` event is emitted per crossed tile.
- Hazard refusal, blocker origin, opposite-direction cancellation, callback-driven route clear, and ordinary unmarked release all pass focused regressions.
- A destination seam retry emits one route completion after its tile event, retains target context, faces south, and uses standard completion feedback.
- Focused suites and the full repository runner pass with no syntax or whitespace failures.
- After a user reload, one normal-entry autowalk reaches `(4,5)`, never enters the World Map, leaves no runtime blockers, faces south, and opens the 53 GOLD prompt.
