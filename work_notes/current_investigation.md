# Current Investigation Scratchpad

Updated: 2026-10-15
Status: broader representative Travel pass complete; no required player check pending.

Use `session_handoff.md` for current state and `TASKS.md` for the next requested work.
The detailed older scratchpad is preserved in
`handoff_archive/current_investigation_2026-10-15_pre_travel_wrap.md`.
Its old active/next-work statements are historical.

## Verified result

- Three focused fixes: Charlock corridor selection, full-opening corridor/recovery
  validation, and public request IDs for staged destination recovery. No geometry,
  permanent/runtime map blockers, or global movement timing changed.
- Final native gate (2026-10-13): 42 Lua suites / 68 Python tests plus syntax,
  speech dependency, and command queue. Focused counts: 346 routes / 169 manager /
  154 auto-step. Manual reload and final loaded checks passed 2026-10-15.
- Both Swamp Cave previews passed at (73,96), frames 17880/18000. All 16 fresh
  model audits completed, unreachable 0 and max safe recovery distance 117.
- Brecconary recovery from normally reached (90,108) planned 113 safe steps.
  Battles interrupted the first 3 steps. After player-cleared battles and REPEL,
  four 24-step checkpoints and a 14-step network entry stopped exactly, with
  explicit resumes despite continuous Travel. Final entry (23,98) at 47035.
- Explicit guided resume, Kol arrival/normal exit, and post-dialogue resume passed.
  The player accepted physical TALK and REPEL result status/refusal/dismissal.
  REPEL remained paired with a spell submenu, so it was not dialogue-only onset.
- Final fresh probe 91440: clear World Map field/menu/text (96,14), path nil,
  NPC/runtime blockers 0, HP 149/149, MP 85/121, speech ready/error none.
  Brecconary retained, next West of Kol north lane, 7 south. Movement stopped.

## Watch items and evidence limits

- UNRESOLVED TIMING WATCH: western recovery reached (11,30), then carried to
  (11,31) during final settle and cancelled conservatively. Five later recovery
  checkpoint/network stops landed exactly. Reproduce the original before a fix;
  this is not terrain evidence.
- COVERAGE LIMITS: physical in-battle Shift+R and independent dialogue-only onset
  remain unaccepted. Capture opportunistically during normal play; no battle grind.
  No ordinary safe non-transition hazard-only origin exists in the decoded model;
  live Charlock hazard stopping and host recovery guard tests cover that safety slice.
- DO NOT PROMOTE: the teleport-seeded Kol positioning probe carried onto decoded
  water (93,34). Transition seam logs can also contain old local-map coordinates.
  Neither supplies new world-map passability evidence.
- Preserve debug/speech logs before host gates and reloads. The Oct13 recovery
  reload extract is reconstructed from exact tool outputs after log truncation;
  it is not a full original log. Full Oct15 raw backups are ignored in `.test_tmp/`.

## Evidence

- `docs/plans/2026-10-13-travel-acceptance.md`: completed plan and scope.
- `work_notes/travel_acceptance_20261015.txt`: focused live/player evidence.
- `work_notes/travel_recovery_audit_20261015.txt`: fresh model counts/samples.
- `work_notes/travel_acceptance_20261013_pre_reload.txt`, `post_reload.txt`,
  and `recovery_reload.txt`: earlier focused/reconstructed milestones.
- `.test_tmp/travel_acceptance_gate_20261013_staged.log`: final native gate.
