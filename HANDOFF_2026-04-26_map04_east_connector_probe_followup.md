# Handoff 2026-04-26 - Map 0x04 east connector probe follow-up

## What happened

Codex investigated the six repeated runtime blockers from the fresh map `0x04`
parked-NPC survey:

```text
17,6(north)
18,6(north)
19,6(north)
20,6(north)
21,4(west)
21,5(west)
```

Workflow:

- froze NPCs
- cleared runtime blocks and seam memory before each exact-start check
- split `teleport_to` setup from `probe_edge`
- logged `report_movement_state` before/after representative checks
- followed up with raw held-input tests to distinguish `auto_step` artifacts
  from actual engine rejection

## Direct probe results

All six `probe_edge` checks blocked despite open model previews:

```text
(17,5)->DOWN  dest=(17,6): blocked_despite_open_preview
(18,5)->DOWN  dest=(18,6): blocked_despite_open_preview
(19,5)->DOWN  dest=(19,6): blocked_despite_open_preview
(20,5)->DOWN  dest=(20,6): blocked_despite_open_preview
(20,4)->RIGHT dest=(21,4): blocked_despite_open_preview
(20,5)->RIGHT dest=(21,5): blocked_despite_open_preview
```

Each direct probe exhausted the full `auto_step` retry cycle:

```text
frames=60 timeout_retries=3/3 turn_represses=1 inject_limit=12 queued_route=false
```

## Raw held-input controls

Raw held input split the set:

Blocked under raw/natural input:

```text
(17,5)->DOWN,90: final=(17,5)
(18,5)->DOWN,90: final=(18,5)
(19,5)->DOWN,90: final=(19,5)
```

Moved under raw/natural input:

```text
(20,5)->DOWN,90: final=(20,8)
(20,4)->RIGHT,90: final=(23,4)
(20,5)->RIGHT,90: final=(24,5)
```

## Interpretation

The six-cell survey/runtime set is not uniform.

**Superseded by `HANDOFF_2026-04-26_map04_post_reload_survey_followup.md`:**
after the user reloaded the full script and reran the survey, normalized raw
controls showed the first raw "moved" pass was contaminated. The final patch
models all six seams.

Initially likely real engine blockers, supported by both direct probe and the
first raw held-input pass:

```lua
["17,6"] = {north = true},
["18,6"] = {north = true},
["19,6"] = {north = true},
```

Initially suspected `probe_edge` / `auto_step` false positives, because the
first raw held-input pass appeared to move through them:

```text
20,6 north
21,4 west
21,5 west
```

This interpretation is no longer current. Post-reload normalized raw controls
stayed in place on all three, so `20,6 north`, `21,4 west`, and `21,5 west` were
also promoted to permanent map data.

## Patch applied

Initial patch applied after the first raw held-input split:

```lua
["17,6"] = {north = true},
["18,6"] = {north = true},
["19,6"] = {north = true},
```

Also patched the evidence pipeline:

- `main.lua`: raw debug input frames now skip `auto_step.update(can_walk)`, so
  `simulate_raw_input` cannot accidentally produce synthetic blocked auto-step
  events after a raw hold.
- `map_survey.lua`: candidates seen only in `command_timing_or_state_issue`
  failures are marked `confidence=needs_repro`, remain visible in diagnostic
  candidate listings, and are excluded from strong candidate / export suggestions.

## Suggested next step

See `HANDOFF_2026-04-26_map04_post_reload_survey_followup.md` for the current
state. Reload the full Lua script in FCEUX, then rerun a focused east-wing target
or a full parked-NPC survey against the final six-seam patch.
