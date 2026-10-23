# Current Investigation Scratchpad

Updated: 2026-10-15
Status: non-ASCII account acceptance complete; speech responsiveness deferred.

Use `session_handoff.md` for current state and `TASKS.md` for the next requested work.
The detailed older scratchpad is preserved in
`handoff_archive/current_investigation_2026-10-15_pre_travel_wrap.md`.
Its old active/next-work statements are historical.

## Current account-test findings

- Real DWTest-é identity/profile and NVDA session confirmed. First install,
  launch, private paths and normal King save passed. LOKI's marker is 5 XP.
- Manual input failed; helper started but its cleanup heartbeat stopped before
  game exit. The collector's old Copy-Item reader twice reproduced a fatal
  WriteAllText sharing error against an isolated unchanged keyboard helper.
- Corrected shared-read snapshots survived 12,828 stress samples with advancing
  heartbeat. Only temporary test harness files changed; package remains intact.
- Run 002 passed: the player confirmed battery reload and manual arrows. Fresh
  speech confirms LOKI's 5-XP marker and movement; v3 heartbeat advanced from 3
  to 1017 over more than four minutes with the corrected observer. Actual account
  qualification is complete. FCEUX was left running in the test account.
- Full evidence: `work_notes/non_ascii_account_20261015.md` and the local
  `.test_tmp/non_ascii_account_20261015/` run/capture-check directories.

## Deferred speech responsiveness findings

- Player report: NVDA feels slower than JAWS during object browsing and arriving
  dialogue on the same qualified candidate. FCEUX was closed before this pass.
- Nine real bridge/controller samples: parent pipe write to API return median
  0.907 ms, maximum 1.171 ms; worker queue median 0.056 ms. No RPC errors.
- Separate supported SSML beginning marks: 31-53 ms, three successful calls.
  This is a downstream proxy, not actual sound onset or the game's normal API.
- First marker attempt cancelled (1223) because of the diagnostic's own pending
  cancellation; excluded. Settling before registration produced valid samples.
- Static checks: browsing bypasses duplicate debounce; ordinary dialogue's
  30-frame stability wait applies equally to both readers. NVDA controller
  methods queue work internally and return before sound starts.
- NVDA 2026.2 AMD64, SAPI5 Eloquence; saved audio ducking off, keep-awake 30 s.
  No source/settings/package edits. Both qualified ZIP hashes still match.
- UNRESOLVED: physical key-to-audio timing, game-side handler time under real
  load, actual synth/audio onset, and a measured JAWS comparison. The user found
  isolated sample comparison hard to judge. No fix or backend fault established.
- NEXT USEFUL CHECK: controlled equivalent in-game actions with submission and
  actual audio-onset timing separated. Avoid speculative speech changes.
- Evidence: `work_notes/nvda_responsiveness_20261015.md` and `.json`; local
  diagnostic scripts/raw data under `.test_tmp/speech_latency_20261015/`.

## Prior completed Travel result

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
