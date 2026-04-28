# Handoff: Brecconary Input Release Patch — 2026-04-26

## Context

After the `(16,23)` trap-cell patch, the user reloaded Lua and asked Codex to
continue the Brecconary parked object survey from `(3,17)`.

Initial checks looked clean:

```text
POSITION: map=0x08(Brecconary) x=3 y=17
RUNTIME_BLOCKS map=0x08 none
SURVEY_START_CHECK mode=park_npcs ... targets=21 reachable_area=128
```

The survey was then started with:

```text
clear_blocked_tiles:0x08
survey_objects:park_npcs
```

## Invalid Survey

The run failed immediately on the first target:

```text
SURVEY_START run=1 map=0x08 start=(3,17) targets=21 mode=objects npc_mode=park_npcs runtime_blocks=0
auto_step blocked dir=right from=(3,17) ... queued_route=true
auto_step blocked dir=up from=(3,17) ... queued_route=true
SURVEY_COMPLETE run=1 map=0x08 targets=1 successes=0 failures=1 suspected_engine_blocked=1
```

This survey is invalid and should not be used for map-data promotion. It
suggested `(4,17)` and `(3,16)`, but `inspect_move:RIGHT` and
`inspect_move:UP` both reported those edges as open:

```text
MOVE map=0x08 from=(3,17) dir=right dest=(4,17) ... effective_passable=true
MOVE map=0x08 from=(3,17) dir=up    dest=(3,16) ... effective_passable=true
```

Repeated movement diagnostics showed `buttons=0x80` persisting through failed
probes, including a direct `probe_edge:RIGHT` from `(3,17)` that blocked despite
an open preview. Treat the resulting runtime block/seam evidence as polluted.

## Root Cause Hypothesis

The live state strongly suggests stale injected joypad state after a failed
probe or script reload:

- `debug_tools.tick()` returned held/raw simulated input for the requested
  frames but did not emit a neutral release frame afterward.
- A first patch tried to clear stale `joypad.set` state once on Lua reload, but
  that was too invasive: the user reported broken controller input after
  reload, so automatic startup neutralization was removed.
- `auto_step.lua` actively neutralized after successful steps, but not after a
  step timed out as blocked.

This leaves a failed probe/survey able to poison the next diagnostic attempt.

## Code Changes

- `debug_tools.lua`
  - Emits one neutral `{}` joypad frame after one-frame simulated input,
    multi-frame simulated input, and sweep input.
  - Adds `clear_input` / `neutral_input` as an explicit debug recovery command.
  - Does **not** emit a neutral frame automatically on startup/reload; normal
    player controller input keeps ownership unless debug automation has run.
- `auto_step.lua`
  - Sends a neutral D-pad frame immediately when a step is finally reported
    blocked.
  - Keeps the existing short post-step neutral window active after blocked
    steps as well as successful steps.
- `test_auto_step.lua`
  - Adds regression coverage that blocked steps clear stale directions on the
    blocked frame and the following frame.
- `debug_hooks.txt`
  - Documents `clear_input`.

## Validation

Passed:

```text
luac -p debug_tools.lua auto_step.lua test_auto_step.lua
luac -p main.lua map_survey.lua route_manager.lua
lua test_auto_step.lua      # 12/12
lua test_map_survey.lua     # 37/37
lua test_route_manager.lua  # 16/16
```

After removing the automatic startup neutral frame, re-ran:

```text
luac -p debug_tools.lua auto_step.lua test_auto_step.lua
lua test_auto_step.lua      # 12/12
```

## Next Resume Point

Reload Lua before the next live check; the currently running script predates
this patch. The old-script live session was cleaned up afterward:

```text
POSITION: map=0x08(Brecconary) x=3 y=17
RUNTIME_BLOCKS map=0x08 none
```

After reload:

1. Run `clear_input clear_blocked_tiles:0x08 report_position report_movement_state:post_reload`.
2. Confirm the player is still on `map=0x08` at a sane town position.
3. Start a fresh parked survey only after runtime blocks are clear:

```text
clear_blocked_tiles:0x08
survey_objects:park_npcs
```

Do not patch `(4,17)`, `(3,16)`, or `(2,15)` from the invalid run.
