# Session Handoff - Active Resume

Updated: 2026-05-22

This file is intentionally short. It is the current resume point, not the
historical evidence archive. The previous long handoff was preserved at
`handoff_archive/HANDOFF_2026-05-22_pre_cleanup_session_handoff_full.md`.

## Current Direction

- Player-facing gameplay is currently FCEUX-first.
- BizHawk remains the preferred automation/debug/reload-heavy runtime.
- Keep both emulator paths supported. Do not remove the FCEUX player-facing
  path or BizHawk automation affordances unless explicitly asked.
- Current branch focus: player-facing quality-of-life features before the next
  normal gameplay pass.
- Avoid broad new map-decoding passes unless gameplay exposes a blocker.
- Codex is the primary implementation/debugging agent. Claude is now mainly a
  limited-bandwidth second-eyes reviewer, so do not rely on Claude memory as an
  active project-state source.

## Runtime Baseline

- Normal launch: `./launch_dw.sh`
- Explicit FCEUX launch: `./launch_dw.sh --emulator fceux` or
  `./launch_fceux.sh`
- Explicit BizHawk launch: `./launch_dw.sh --emulator bizhawk` or
  `./launch_bizhawk.sh`
- Commands go through `./dw_commands.sh` from bash or `./dw_commands.ps1` from
  PowerShell/Codex.
- Use `--replace` for state-sensitive command batches and verify
  `dw_debug.log` between live steps.
- Use `--require-live SECONDS` when stale logs would mislead the result.
- Do not batch `teleport_to` with `probe_edge`, `survey_target`,
  `report_survey_start`, or path-debug follow-up commands when exact start
  state matters.

## Latest Accepted Work

### Map Crawler Review + Hardening

Detailed handoff: `HANDOFF_2026-05-22_map_crawler_review.md`

Commit: `9076d3a Harden map crawler and add per-map export file`

Accepted review outcome:
- Keep the commit.
- `auto_step_lost` orphan-step detection is the right crawler-local fix.
- Failed backtracks now classify as `backtrack_blocked` diagnostic evidence and
  no longer pollute directional candidates.
- `crawl_map_frontier` now refuses to start outside field state or while menus
  or dialogue are active.
- Every crawler finish writes `dw_crawl_<mapid_hex>.txt` next to
  `dw_debug.log` with Lua-snippet candidates for review.
- Finish speech now emits exactly one summary message.

Validation already run:
- `lua5.1 test_map_crawler.lua` passed: 32 tests.
- `luac5.1 -p map_crawler.lua main.lua test_map_crawler.lua` passed.
- `git diff --check HEAD~1..HEAD` passed.
- `python3 run_tests.py --allow-missing-speech-dep` passed with only the known
  WSL speech dependency warning for missing `accessible_output2`.

Optional follow-ups once the emulator is running:
- Live smoke test: run a tiny `crawl_map_frontier` with a low `max_edges`, stop
  it, then confirm `MAP_CRAWL_EXPORT_FILE` and the generated
  `dw_crawl_*.txt`.
- Harden export writes around `file:write` / `file:close`, not just `io.open`.
- Make `test_map_crawler.lua` restore global `io.open` through a per-test
  cleanup wrapper even when an assertion fails.

## Current Gameplay State

- Rimuldar is clean enough to leave for now.
- Rimuldar player-facing services and important routes had passed the latest
  route sweep before the handoff cleanup:
  - Weapons Merchant
  - Inn
  - Magic Key Merchant
  - Chest
  - Exit routes
- Do not continue broad Rimuldar blocker harvesting unless normal gameplay
  exposes a fresh failure.
- Next route/map work should move to another town, cave, or gameplay target.

## Open Review Items

- Resolve the Tantegel `4,11-4,15` evidence conflict during the next
  locked-door/item mapping pass.
- Decide whether overworld route waypoint validation needs a real overworld
  passability source before changing radius-0 behavior.

## Documentation Cleanup Notes

- Canonical current docs are:
  - `AGENTS.md`
  - `session_handoff.md`
  - `PROJECT_MEMORY.md`
  - `PLAYTESTING.md`
  - `debug_hooks.txt`
- `handoff_archive/` is historical evidence only. Do not read the whole archive
  by default.
- Assistant-local memories and `.claude/agent-memory/` are subordinate to repo
  docs when they disagree.
- Review packets for Claude should point to the current diff, focused tests,
  and this handoff instead of expecting Claude to reconstruct context from
  old archive files.

## Best Next Steps

1. Once the emulator is up, do the small crawler export smoke test.
2. Then continue with player-facing QoL or the next normal gameplay pass under
   FCEUX unless the task specifically needs BizHawk automation/debug behavior.
