# Handoff 2026-04-24 — Map 0x04 suspect direct probes

## What happened

The overnight survey showed contradictory seam evidence, so a controlled direct
probe campaign was run instead of immediately patching `map_reader.lua`.

Setup:

```bash
./dw_commands.sh --replace freeze_npcs clear_runtime_blocks clear_seam_cells teleport_to:17,5 report_position
```

The emulator consumed the setup and confirmed:

```text
POSITION: map=0x04(Tantegel Castle) x=17 y=5
```

Each probe used the disciplined split pattern:

1. `teleport_to:X,Y report_position`
2. wait for position confirmation in `dw_debug.log`
3. `probe_edge:X,Y,DIR`
4. wait for `EDGE_PROBE_RESULT`

No `teleport_to` command was batched with a `probe_edge` command.

## Direct probe results

Passes:

- `(17,5)->DOWN->(17,6)`
  - `EDGE_PROBE_RESULT ... status=moved final=(17,6)`
  - `SEAM_OBSERVATION ... cell=(17,6) approach=north result=moved ... classification=passable_only`
- `(8,4)->UP->(8,3)`
  - `EDGE_PROBE_RESULT ... status=moved final=(8,3)`
  - `SEAM_OBSERVATION ... cell=(8,3) approach=south result=moved ... classification=passable_only`
- `(14,4)->UP->(14,3)`
  - `EDGE_PROBE_RESULT ... status=moved final=(14,3)`
  - `SEAM_OBSERVATION ... cell=(14,3) approach=south result=moved ... classification=passable_only`
- `(15,4)->UP->(15,3)`
  - `EDGE_PROBE_RESULT ... status=moved final=(15,3)`
  - `SEAM_OBSERVATION ... cell=(15,3) approach=south result=moved ... classification=passable_only`

Confirmed direct blocks:

- `(16,1)->LEFT->(15,1)` blocked three direct probes
  - `EDGE_PROBE_MODEL_MISMATCH ... kind=blocked_despite_open_preview`
  - reached `classification=confirmed_blocked`
  - runtime injected `cell=(15,1) approach=east`
- `(16,2)->LEFT->(15,2)` blocked three direct probes
  - `EDGE_PROBE_MODEL_MISMATCH ... kind=blocked_despite_open_preview`
  - reached `classification=confirmed_blocked`
  - runtime injected `cell=(15,2) approach=east`
- `(16,3)->LEFT->(15,3)` blocked three direct probes
  - `EDGE_PROBE_MODEL_MISMATCH ... kind=blocked_despite_open_preview`
  - reached `classification=confirmed_blocked`
  - runtime injected `cell=(15,3) approach=east`

Runtime block export after the confirmation pass:

```lua
[0x04] = {
    ["15,1"] = {east=true},
    ["15,2"] = {east=true},
    ["15,3"] = {east=true},
},
```

## Interpretation

Do not patch every overnight survey suspect.

The direct-probe evidence says:

- Keep `(17,6)` north unpatched for now. It moved again on direct probe, even
  though surveys can still block there.
- Keep `(8,3)` south and `(14,3)` south unpatched for now. Both moved on direct
  probe.
- Keep `(15,3)` south unpatched. South entry moved even though east entry blocks.
- Strong candidates for permanent map data:
  - `["15,1"] = {east = true}`
  - `["15,2"] = {east = true}`
  - `["15,3"] = {east = true}`

These three east-entry seams are now backed by both:

- the overnight survey/runtime evidence
- three controlled direct probe blocks each in this session

The fact that yesterday's suspect probe campaign reportedly moved through these
same east-entry seams means there is still a historical contradiction, but the
new evidence is much stronger and cleaner than the survey-only signal.

## Recommended next step

If we choose to promote the three east-entry seams, make the narrow
`MAP_DIRECTIONAL_BLOCKS[0x04]` patch only:

```lua
["15,1"] = {east = true},
["15,2"] = {east = true},
["15,3"] = {east = true},
```

Then reload Lua and rerun a targeted survey check for the throne-room route,
for example:

```bash
./dw_commands.sh --replace clear_runtime_blocks clear_seam_cells teleport_to:17,5 report_position
./dw_commands.sh --replace "survey_target:Stairs Down to Throne Room,park_npcs"
```

Keep `(17,6)` out of permanent map data until a controlled direct probe blocks
repeatedly.
