# Handoff 2026-04-24 — Map 0x04 post-x15 reload check

## What happened

After patching `MAP_DIRECTIONAL_BLOCKS[0x04]` with:

```lua
["15,1"] = {east = true},
["15,2"] = {east = true},
["15,3"] = {east = true},
```

the user reloaded the FCEUX Lua script. The fresh `dw_debug.log` header confirms
reload:

```text
Started: 2026-04-24 10:02:17
```

Setup after reload:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks clear_seam_cells teleport_to:17,5 report_position
```

Confirmed:

```text
POSITION: map=0x04(Tantegel Castle) x=17 y=5
```

Then ran:

```bash
./dw_commands.sh --replace "survey_target:Stairs Down to Throne Room,park_npcs"
```

## Result

The new static `x=15 east` patch loaded correctly in the sense that the focused
target result no longer listed `15,1` or `15,2` as suspected tiles. The old
east-entry band was no longer the active failure set.

The target still failed/rerouted for the remaining direct-pass-but-route-blocking
south-entry seams. The run was manually stopped after enough evidence:

```text
SURVEY_RESULT run=1 map=0x04 target_id=stair_1_1 target_name="Stairs Down to Throne Room" start=(17,5) ... final=(13,4) failure_class=suspected_engine_blocked_tile blocked_events=5 suspected_tiles=15,3|8,3|14,3 blocked_tiles=15,3|8,3|14,3|8,3|14,3 reason=manual_stop
```

Important observations:

- Initial plan from `(17,5)` was still length 19, but it now used vertical
  movement in the `x=15` column rather than east-entry into `(15,1..3)`.
- First blocker after the patch:
  - `(15,4)->UP->(15,3)`, recorded as `(15,3)` approach `south`.
- Reroute then repeatedly hit:
  - `(8,4)->UP->(8,3)`, approach `south`
  - `(14,4)->UP->(14,3)`, approach `south`

## Interpretation

The `x=15 east=true` patch did what it was supposed to do: it removed the
confirmed east-entry band from the active target failure set.

The next bottleneck is the set of vertical/south-entry seams that previously
passed direct probes but repeatedly block under routed movement:

- `(15,3)` south
- `(8,3)` south
- `(14,3)` south

Do **not** automatically patch these just because the routed survey blocked.
They still contradict direct-probe evidence. This now looks more like either:

- noisy engine seams that need repeated adjacent direct repros after reload, or
- an `auto_step`/route execution timing issue specific to these vertical north
  entries.

## Recommended next step

Run controlled post-reload direct probe repeats for the three remaining suspects:

```bash
./dw_commands.sh --replace clear_runtime_blocks clear_seam_cells freeze_npcs teleport_to:15,4 report_position
./dw_commands.sh --replace probe_edge:15,4,UP

./dw_commands.sh --replace teleport_to:8,4 report_position
./dw_commands.sh --replace probe_edge:8,4,UP

./dw_commands.sh --replace teleport_to:14,4 report_position
./dw_commands.sh --replace probe_edge:14,4,UP
```

As before, do not batch `teleport_to` with `probe_edge`; wait for position
confirmation between them. If any of these block repeatedly under controlled
direct probes after reload, promote only that exact approach.
