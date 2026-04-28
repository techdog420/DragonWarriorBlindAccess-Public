# Handoff 2026-04-24 — Map 0x04 south-entry probe confirmation

## What happened

After the `x=15 east=true` patch and full Lua reload, the focused throne-room
target still failed on three remaining south-entry seams:

- `(15,4)->UP->(15,3)`
- `(8,4)->UP->(8,3)`
- `(14,4)->UP->(14,3)`

Controlled post-reload direct probes were run for those three seams. The
workflow preserved the state-sensitive split:

1. teleport/report position
2. wait for `POSITION`
3. run `probe_edge:X,Y,UP`
4. wait for `EDGE_PROBE_RESULT`

Runtime/seam memory was cleared before the campaign:

```bash
./dw_commands.sh --replace clear_runtime_blocks clear_seam_cells freeze_npcs teleport_to:15,4 report_position
```

## Results

All three suspect seams blocked 3/3 on direct post-reload probes and reached
runtime `classification=confirmed_blocked`.

Confirmed:

- `(15,4)->UP->(15,3)`
  - destination `(15,3)` approach `south`
  - 3 direct blocks, 0 moves
  - `EDGE_PROBE_MODEL_MISMATCH ... blocked_despite_open_preview`
  - runtime block injected
- `(8,4)->UP->(8,3)`
  - destination `(8,3)` approach `south`
  - 3 direct blocks, 0 moves
  - `EDGE_PROBE_MODEL_MISMATCH ... blocked_despite_open_preview`
  - runtime block injected
- `(14,4)->UP->(14,3)`
  - destination `(14,3)` approach `south`
  - 3 direct blocks, 0 moves
  - `EDGE_PROBE_MODEL_MISMATCH ... blocked_despite_open_preview`
  - runtime block injected

Runtime export:

```lua
[0x04] = {
    ["8,3"] = {south=true},
    ["14,3"] = {south=true},
    ["15,3"] = {south=true},
},
```

## Interpretation

These three seams are now strong permanent map-data candidates.

This supersedes the earlier contradictory direct-pass evidence because the new
checks were performed after a full Lua reload, with controlled adjacent starts,
and each seam reproduced 3/3 with runtime confirmation.

Recommended narrow patch:

```lua
["8,3"]  = {south = true},
["14,3"] = {south = true},
["15,3"] = {south = true},
```

Do not add any unrelated blockers from the routed survey.

## Patch applied

The narrow patch was applied to `map_reader.lua` on 2026-04-24:

```lua
["8,3"]  = {south = true},
["14,3"] = {south = true},
["15,3"] = {east = true, south = true},
```

Validation:

```bash
luac -p map_reader.lua
```

passed.

## Next step

Reload Lua, then rerun:

```bash
./dw_commands.sh --replace clear_runtime_blocks clear_seam_cells teleport_to:17,5 report_position
./dw_commands.sh --replace "survey_target:Stairs Down to Throne Room,park_npcs"
```
