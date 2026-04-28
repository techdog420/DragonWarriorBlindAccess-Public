# Handoff 2026-04-24 — Movement timing/state noise investigation

## Why focus changed

The post-x15-reopen targeted survey proved the planner can now find a route to
the throne-room stairs, but execution still produced contradictory x=15 seam
results. This prompted a shift away from permanent map-data patching and toward
pinning down movement timing/state noise.

## Live findings

Same-session controlled probe after the failed targeted survey:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks clear_seam_cells teleport_to:16,3 report_position
./dw_commands.sh --replace probe_edge:16,3,LEFT
```

Result:

```text
EDGE_PROBE_RESULT map=0x04 from=(16,3) dir=left dest=(15,3) status=blocked final=(16,3) ... reason=route_blocked
EDGE_PROBE_MODEL_MISMATCH ... kind=blocked_despite_open_preview ... effective_passable=true
```

Then a raw long-hold test was run:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks clear_seam_cells teleport_to:16,3 report_position
./dw_commands.sh --replace simulate_raw_input:LEFT,90
./dw_commands.sh --replace report_position report_coords
```

Result:

```text
POSITION: map=0x04(Tantegel Castle) x=16 y=3
COORDS: map=0x04(Tantegel Castle) terrain=0x10 effective=(16,3) player=(16,3) overworld=(32,87) raw003C_0043=08 90 57 01 D1 01 20 1F
```

Interpretation:

- In this current state, simply holding LEFT longer did **not** move through
  `(16,3)->(15,3)`.
- The earlier direct-probe moves through x=15 are therefore not enough to
  reopen those seams permanently without understanding hidden state.
- Candidate causes include hidden movement/facing/subtile/scroll state after
  teleporting, not just `auto_step` hold duration.

## Code changes

`auto_step.lua`:

- added configurable movement-timing knobs:
  - `auto_step_inject_limit`
  - `auto_step_turn_repress_delay`
  - `auto_step_turn_repress_limit`
  - `auto_step_turn_repress_release_frames`
  - `auto_step_block_retry_limit`
- added structured debug logs for successful and blocked auto-steps, including:
  - frames
  - timeout retry count
  - turn re-press count
  - inject limit
  - queued-route flag

`config.lua` and `dw_access.ini`:

- added default/current values for the new movement-timing knobs

Validation:

```text
luac -p auto_step.lua config.lua
lua test_auto_step.lua
```

Both passed.

## Recommended next step

Reload the full Lua script so the new instrumentation is active, then rerun:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks clear_seam_cells teleport_to:17,5 report_position
./dw_commands.sh --replace "survey_target:Stairs Down to Throne Room,park_npcs"
```

Then compare the new `auto_step complete` / `auto_step blocked` log lines.

If the x=15 blocks still occur with `inject_limit=12`, try an A/B config test:

```ini
auto_step_inject_limit=24
```

Then use `reload_config` or reload the script before repeating. If longer
inject still fails, focus on hidden movement/facing/subtile state rather than
hold duration.
