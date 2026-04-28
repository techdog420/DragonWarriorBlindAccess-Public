# Handoff 2026-04-24 — x=15 hidden-state probe

## What happened

After the movement A/B ruled out a global longer-hold fix, the strongest suspect
became stale hidden movement/camera/subtile state around `teleport_to`.

The focused edge was `(16,3)->LEFT`, entering destination cell `(15,3)` from
the east on map `0x04` (Tantegel Castle).

Setup used frozen NPCs and cleared runtime/seam memory before exact checks:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks clear_seam_cells teleport_to:17,3 report_position report_coords
```

## Evidence

Known-open movement worked:

```text
COORDS ... player=(17,3) overworld=(32,119) raw003C_0043=06 90 77 01 B6 02 20 1F
simulate_raw_input:LEFT,90
POSITION ... x=16 y=3
COORDS ... player=(16,3) overworld=(31,135) raw003C_0043=08 90 87 01 B6 02 1F 1E
```

From the resulting state, repeated left holds/probes into `(15,3)` blocked:

```text
Teleported to (16,3)
COORDS ... player=(16,3) overworld=(31,135) raw003C_0043=04 90 87 01 B6 02 1F 20
auto_step blocked dir=left from=(16,3) frames=60 timeout_retries=3/3
SEAM_OBSERVATION map=0x04 cell=(15,3) approach=east result=blocked
```

A second left hold from the post-failure state also blocked, so this is not just
a one-press facing/repress issue.

Reverse movement from `(15,3)` to the right was allowed and overshot through the
corridor:

```text
Teleported to (15,3)
COORDS ... player=(15,3) overworld=(31,135) raw003C_0043=00 90 87 01 B6 02 1F 1F
simulate_raw_input:RIGHT,90
POSITION ... x=17 y=3
COORDS ... player=(17,3) overworld=(32,103) raw003C_0043=06 90 67 01 B6 02 20 1F
```

After that reverse traversal, `teleport_to:16,3` preserved a different hidden
state and the exact same edge probe moved:

```text
Teleported to (16,3)
COORDS ... player=(16,3) overworld=(31,103) raw003C_0043=08 90 67 01 B6 02 1F 20
probe_edge:16,3,LEFT
EDGE_PROBE_RESULT ... status=moved final=(15,3) ... reason=position_changed
auto_step complete dir=left from=(16,3) to=(15,3) frames=6
```

Then, after the successful probe changed the hidden state again, teleporting
back to `(16,3)` produced another stale byte pattern and the same edge blocked:

```text
COORDS ... player=(15,3) overworld=(30,119) raw003C_0043=00 90 77 01 B6 02 1E 20
Teleported to (16,3)
COORDS ... player=(16,3) overworld=(20,119) raw003C_0043=00 90 77 01 B6 02 14 08
probe_edge:16,3,LEFT
EDGE_PROBE_RESULT ... status=blocked final=(16,3) ... reason=route_blocked
EDGE_PROBE_MODEL_MISMATCH ... blocked_despite_open_preview
```

## Interpretation

This is strong evidence that `teleport_to` leaves movement/camera-adjacent RAM
in stale states that can change engine collision outcomes. The same modeled-open
edge `(16,3)->LEFT` can either move or block depending on hidden bytes that are
not normalized by `teleport_to`.

Do not promote `(15,3) east=true` into permanent map data from these mixed
results. The failure is stateful.

## Patch applied

Added a diagnostic command in `debug_tools.lua`:

```text
report_movement_state
report_movement_state:TAG
```

It logs:

- current map, terrain, player coords, overworld shadow coords
- `scroll_y` and `buttons`
- RAM windows `0x0000..0x001F` and `0x0030..0x004F`

`debug_hooks.txt` was updated with the command.

Validation:

```bash
luac -p debug_tools.lua
```

passed.

## Recommended next step

Reload the full Lua script, then rerun the pass/block sequence with
`report_movement_state` tags immediately before each probe:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks clear_seam_cells teleport_to:17,3 report_movement_state:from_17_3
./dw_commands.sh --replace simulate_raw_input:LEFT,90
./dw_commands.sh --replace report_movement_state:after_left_to_16_3
./dw_commands.sh --replace clear_runtime_blocks clear_seam_cells teleport_to:16,3 report_movement_state:block_candidate
./dw_commands.sh --replace probe_edge:16,3,LEFT
./dw_commands.sh --replace report_movement_state:after_block_or_move
```

If the expanded dump consistently isolates one or two bytes, consider a narrow
`teleport_to` normalization patch or a safer diagnostic setter to A/B those
bytes before touching route logic.
