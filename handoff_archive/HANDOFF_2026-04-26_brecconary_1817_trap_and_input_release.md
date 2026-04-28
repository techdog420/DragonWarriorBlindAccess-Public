# Handoff: Brecconary 18,17 Trap and Input Release Follow-up - 2026-04-26

## Context

After the user reloaded Lua, Codex ran the recommended follow-up checks from
the latest Brecconary work:

- verify same-poll `teleport_to` snapshot refresh
- harden candidate export so diagnostic `needs_repro` entries are not paste-ready
- run a parked Brecconary regression survey

## Live Checks

The same-poll teleport check passed:

```text
POSITION: map=0x08(Brecconary) x=8 y=28
MOVE map=0x08 from=(8,28) dir=up dest=(8,27) ... effective_passable=true
RUNTIME_BLOCKS map=0x08 none
```

Starting a regression survey at `(3,17)` immediately reproduced a queued-route
false block on `(3,17)->RIGHT`, but split direct probes from `(3,17)` moved to
`(4,17)` twice. One direct probe required two internal retries before moving.
Do not patch `(4,17)` west; it remains timing-sensitive/noisy.

The cleaner regression survey from `(1,14)` was stopped after it became polluted:

```text
SURVEY_COMPLETE run=2 map=0x08 targets=13 successes=6 failures=7 no_route=0 gated_or_isolated=2 movement_failed=0 suspected_engine_blocked=0 state_issues=5 adjacency_issues=0
SURVEY_STRONG_CANDIDATES map=0x08 none
SURVEY_CANDIDATE_SUGGESTIONS map=0x08 none
RUNTIME_BLOCKS map=0x08 none
```

All reported candidates were `needs_repro`. The bad evidence clustered around
`(18,17)` and the older noisy south edges:

```text
18,16 south
17,17 east
18,18 north
10,27 south
8,27 south
12,29 north
```

## Confirmed Trap Cell

Focused split probes from `(18,17)` confirmed a real trap-like engine behavior,
not just a queued-route artifact:

```text
EDGE_PROBE_RESULT map=0x08 from=(18,17) dir=down dest=(18,18) status=blocked ... effective_passable=true
EDGE_PROBE_RESULT map=0x08 from=(18,17) dir=left dest=(17,17) status=blocked ... effective_passable=true
TELEPORT_POST to=(18,17) ... movement bytes normalized
EDGE_PROBE_RESULT map=0x08 from=(18,17) dir=left dest=(17,17) status=blocked ... effective_passable=true
EDGE_PROBE_RESULT map=0x08 from=(18,17) dir=up dest=(18,16) status=blocked ... effective_passable=true
```

`RIGHT` is already a wall tile. `map_reader.lua` now marks
`MAP_BLOCKED_CELLS[0x08]["18,17"] = true` so A* will not enter the cell.

## Input Release Patch

The survey also exposed a possible stale debug-owned input leak: auto-step
stopped injecting after its hold window but did not actively send neutral frames
on cleanup paths. `auto_step.lua` now:

- neutralizes on blocked-step cleanup and `cancel_active_step`
- preserves non-direction buttons while clearing directions

Important follow-up: after this first patch was reloaded, live controller input
stopped responding before any survey started. The fresh log showed manual
controller directions being converted into auto-steps from `(9,25)` and `(3,17)`,
but movement never committed:

```text
auto_step begin_step dir=left from=(9,25)
auto_step timeout retry 1/3 ...
auto_step timeout retry 2/3 ...
auto_step timeout retry 3/3 ...
auto_step blocked dir=left from=(9,25) queued_route=false
```

The cause was the mid-step neutral frame after the inject window: it could
override real held controller input before the engine began walking. Codex
patched that back out. Current intended behavior is:

- do not emit neutral frames merely because the inject window expired
- do neutralize on confirmed completion and blocked timeout
- post-step neutral frames only run while no live direction is pressed

Second follow-up: after a total relaunch, the game reached the title screen but
physical title-screen keys still did not respond. Read-only commands confirmed
the script was alive and in `state=title`. Root cause was narrower: if the title
transition happened while `post_step_release_frames > 0`, the `can_walk=false`
branch sent `joypad.set({})` every frame forever because the release counter was
not cleared there. `auto_step.lua` now clears release state passively when
`can_walk=false`, without writing neutral input, and `cancel_active_step()` no
longer emits neutral input.

Live rescue performed:

1. Temporarily changed `dw_access.ini` to `enable_auto_step=false`.
2. Sent `reload_config` to the running title-screen script.
3. Restored `dw_access.ini` to `enable_auto_step=true` on disk.

This means the current running script has auto-step disabled until the next full
Lua reload, but the file is back to normal for the next reload. `lua
test_auto_step.lua` passes with:

- `inject_window_does_not_neutralize_live_direction`
- `can_walk_false_clears_release_state_without_neutralizing`
- `cancel_active_step_does_not_emit_sticky_neutral`

## Candidate Export Patch

`map_survey.lua` now makes `export_blocked_candidates` export only pasteable
confirmed candidates. Diagnostic entries are logged as
`SURVEY_CANDIDATE_EXPORT_SKIP ... reason=not_exportable_needs_repro`.

## Validation

Passed:

```text
luac -p auto_step.lua test_auto_step.lua map_survey.lua test_map_survey.lua map_reader.lua test_map_reader.lua main.lua
lua test_auto_step.lua        # 15/15, rerun after title/controller-regression patches
lua test_map_survey.lua       # 37/37
git diff --check -- auto_step.lua test_auto_step.lua map_survey.lua test_map_survey.lua map_reader.lua test_map_reader.lua debug_hooks.txt main.lua
```

Caveat: full `lua test_map_reader.lua` still fails on two older map04/Tantegel
assertions unrelated to the Brecconary `(18,17)` patch:

```text
(12,19) should stay open from south ... expected nil, got true
(16,16) should block the east approach ... expected true, got nil
```

## Live State Restored

After the focused probes, live state was restored:

```text
POSITION: map=0x08(Brecconary) x=9 y=25
RUNTIME_BLOCKS map=0x08 none
NPCs unfrozen
```

Reload Lua before relying on the `18,17` map patch or the new auto-step neutral
release behavior.
