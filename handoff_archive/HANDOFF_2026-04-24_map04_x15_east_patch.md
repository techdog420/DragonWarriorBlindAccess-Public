# Handoff 2026-04-24 — Map 0x04 x=15 east-entry patch

## What changed

`map_reader.lua` was patched in `MAP_DIRECTIONAL_BLOCKS[0x04]` with the three
directly confirmed east-entry seams:

```lua
["15,1"] = {east = true},
["15,2"] = {east = true},
["15,3"] = {east = true},
```

The patch intentionally does **not** add:

- `(17,6)` north
- `(8,3)` south
- `(14,3)` south
- `(15,3)` south

Reason: those approaches moved in controlled direct probes, while the three
`x=15` east-entry seams blocked three direct probes each and reached runtime
`classification=confirmed_blocked`.

Validation:

```bash
luac -p map_reader.lua
```

passed.

## Live assessment caveat

An immediate focused check was attempted before reloading the FCEUX Lua script:

```bash
./dw_commands.sh --replace freeze_npcs clear_seam_cells teleport_to:17,5 report_position
./dw_commands.sh --replace "survey_target:Stairs Down to Throne Room,park_npcs"
```

This was **not a valid assessment of the static patch** because the running Lua
script had not reloaded `map_reader.lua`, and the survey harness cleared the
runtime blocks at attempt reset:

```text
SURVEY_START ... runtime_blocks=3
runtime blocks cleared: map=0x04 count=3
SURVEY_ATTEMPT_RESET ... cleared_runtime_blocks=3
```

As a result, the stale loaded planner still routed through `(15,3)/(15,2)/(15,1)`
from the east, re-learned those seams as blocked, and entered a long reroute.
The run was manually stopped:

```text
SURVEY_RESULT ... target_name="Stairs Down to Throne Room" ... reason=manual_stop
```

## Next step

Reload the full FCEUX Lua script so the new static `map_reader.lua` entries are
loaded. `reload_config` is insufficient; the source note in `main.lua` says a
full script restart/reload is needed for Lua source changes.

After reload, run:

```bash
./dw_commands.sh --replace clear_runtime_blocks clear_seam_cells teleport_to:17,5 report_position
./dw_commands.sh --replace "survey_target:Stairs Down to Throne Room,park_npcs"
```

Expected signal:

- the initial planned route should no longer include east-entry steps into
  `(15,1)`, `(15,2)`, or `(15,3)`
- if the route still fails, inspect whether the remaining blockers are the
  noisy direct-pass seams `(8,3) south`, `(14,3) south`, `(15,3) south`, or
  a separate route execution issue
