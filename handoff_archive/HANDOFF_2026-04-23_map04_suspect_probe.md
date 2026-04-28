# Handoff 2026-04-23 — Map 0x04 suspect probe campaign

## What happened

After a fresh `survey_objects:park_npcs` run on map `0x04`, a temporary probe
script (`probe_map04_suspects.sh`) was used to directly test the unique suspect
seams instead of running another full survey.

The probe set covered 14 approaches:
- east-connector reroute band:
  - `(17,6)` from north
  - `(18,6)` from north
  - `(19,6)` from north
  - `(20,6)` from north
  - `(21,5)` from west
  - `(21,4)` from west
- north-entry rechecks:
  - `(14,5)` from north
  - `(15,5)` from north
- throne-room reroute suspects:
  - `(8,3)` from south
  - `(14,3)` from south
  - `(15,3)` from south
  - `(15,3)` from east
  - `(15,2)` from east
  - `(15,1)` from east

Result summary:
- **5 direct blocked mismatches**
- **9 direct passes**

## Confirmed real blockers

These five all blocked on direct manual probe with
`EDGE_PROBE_MODEL_MISMATCH ... kind=blocked_despite_open_preview`, which means
the current model still treats them as open but the engine rejects the move:

- `(18,6)` north approach
- `(19,6)` north approach
- `(20,6)` north approach
- `(21,5)` west approach
- `(21,4)` west approach

Evidence in `dw_debug.log`:
- `(18,6)` from north blocked: lines `20168-20171`
- `(19,6)` from north blocked: lines `20193-20196`
- `(20,6)` from north blocked: lines `20218-20221`
- `(21,5)` from west blocked: lines `20243-20246`
- `(21,4)` from west blocked: lines `20268-20271`

Recommended model update:

```lua
["18,6"] = {north = true},
["19,6"] = {north = true},
["20,6"] = {north = true},
["21,5"] = {west = true},
["21,4"] = {west = true},
```

Update applied on 2026-04-23:
- these five directional blocks were added to `map_reader.lua`
- next validation step is a fresh `survey_objects:park_npcs` run

## Not confirmed as blockers

These all **moved successfully** on direct probe and should **not** be promoted
to permanent blocks from this evidence:

- `(17,6)` from north
- `(14,5)` from north
- `(15,5)` from north
- `(8,3)` from south
- `(14,3)` from south
- `(15,3)` from south
- `(15,3)` from east
- `(15,2)` from east
- `(15,1)` from east

Each of those seams had prior survey-era blocked counts, but the direct probe
converted them to `classification=noisy` with one clean `status=moved` result.

Important interpretation:
- `(17,6)` is the only east-band seam that flipped from repeated survey blocking
  to a direct successful move. Treat it as **noisy / unresolved**, not as a new
  permanent wall.
- The entire throne-room reroute suspect cluster appears to have been
  **reroute/state noise**, not a decoder gap or real wall:
  - `(8,3)` south pass: lines `20328-20330`
  - `(14,3)` south pass: lines `20347-20349`
  - `(15,3)` south pass: lines `20366-20368`
  - `(15,3)` east pass: lines `20385-20387`
  - `(15,2)` east pass: lines `20404-20406`
  - `(15,1)` east pass: lines `20423-20425`

## Recommended next step

With the narrow permanent map update now applied, rerun:

```bash
./dw_commands.sh survey_objects:park_npcs
```

Expected effect:
- east-wing reroute failures should drop substantially
- do **not** add `(17,6)` yet
- do **not** add any of the throne-room reroute suspects

## Files touched in this investigation

- `probe_map04_suspects.sh` — temporary 14-probe campaign
- `dw_debug.log` — evidence only
