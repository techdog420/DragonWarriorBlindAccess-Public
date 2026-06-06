# Handoff — Player-Stat Corruption Fixes (2026-05-31)

Author: Claude review notes, reconciled and implemented by Codex
Scope: Two targeted fixes for intermittent corruption of the player-status RAM
block (`0x00BA–0x00D0`: experience / gold / equipment / HP / MP / level / stats)
reported during autowalk.

Status: **Implemented, focused Lua tests pass, full runner reaches 477 PASS before
the known speech dependency failure. Nothing committed.** Changes live in the
working tree for review.

---

## Background / how we got here

Code review of the changes committed since 2026-05-13 (`b1db286~1..HEAD`) while
chasing a report that "one of the new step-stealing functions is corrupting live
memory around player status values at random times." Claude identified two
possible mechanisms; Codex verified the current tree and brought the actual
implementation in line with the useful parts of that analysis.

Important context the user gave: **the corruption stopped recurring after
`auto_step_reset_movement_on_route_turn_settle=false` was set in `dw_access.ini`**
(line 190). So Suspect #2 (movement-engine resets) was the active trigger most
recently; Suspect #1 is a latent, one-edit-away landmine that is the only path
that could write *directly* onto the stat bytes if an invalid NPC slot reached
the write layer. The observed live pattern still fits Suspect #2 more strongly.

---

## Suspect #1 — Unbounded NPC slot can write into the stat block (latent)

### The mechanism
All NPC freeze / park / target-hold writes compute their RAM address as:

```lua
local base = addr.NPC_DATA_START + slot * addr.NPC_ENTRY_SIZE   -- 0x0051 + slot*3
```

then `memory.writebyte(base, ...)`. With a valid slot (0–19) `base` stays inside
the NPC array `0x0051–0x008C`. With an out-of-range slot it walks straight into
the stat block:

- `slot = 35` → base `0x00BA` → Experience (low)
- `slot = 38` → base `0x00C3` → items / HP region
- `slot = 39` → base `0x00C5` → Current HP

That would be direct player-stat RAM corruption if an unvalidated slot reached
an NPC write path.

### Why it was latent (not constant)
`parse_npc_slot` (route_manager.lua:1135) and `npc_slot_from_id` (line 574) both
correctly reject `slot >= NPC_COUNT`. BUT two sites trusted a pre-existing
`npc.slot` field *without* validation, only falling back to the validated parser
when `.slot` was nil:

- `is_destination_occupied_by_npc` (was line 682): `npc.slot or npc_slot_from_id(npc.id)`
- `add_live_npc_to_autowalk_parking` (was line 1325): `npc.slot or npc_slot_from_id(npc.id)`

Current object sources normally derive slots from bounded NPC IDs/RAM scans, so
this was not a strong match for the observed `C8..CE` flip pattern. It was still
worth hardening because a future or stale object source with a raw `.slot` could
make the reactive-park-on-blocked-step path write beyond the NPC table.

### The fix (route_manager.lua)
1. **New helper `valid_npc_slot(slot)`**: coerces any value to a safe
   `0 .. NPC_COUNT-1` integer or `nil`. The helper documents why the guard
   exists.
2. **Hardened the single write chokepoint** `write_npc_bytes_if_changed`
   (line ~1173): validates the slot first; on out-of-range it **refuses the
   write and logs an error**:
   ```
   NPC write refused: slot=<x> out of range 0..19 (would corrupt RAM near player stats)
   ```
   Every freeze/park/hold write funnels through this function, so this is a hard
   backstop regardless of upstream callers.
3. **Closed both bypass sites** to validate `npc.slot` before trusting it:
   - `is_destination_occupied_by_npc`: `valid_npc_slot(npc.slot) or npc_slot_from_id(npc.id)`
   - `add_live_npc_to_autowalk_parking`: same pattern.

### Detector value
The "NPC write refused" log line doubles as instrumentation. If it ever appears
in `dw_debug.log`, the bad-slot source was caught in the act (and harmlessly
refused). That is the fastest way to confirm whether this path is real in live
play. Watch for it.

---

## Suspect #2 — Multiple movement-engine reset write points (the recent trigger)

### The mechanism
The "step-stealing" resets write `0x00` to `MOVEMENT_STATE (0x003C)` and
`MOVEMENT_SUBPIXEL (0x003D)`. These are **not** in the stat block, so they cannot
corrupt stats by direct address. The risk is *indirect*: 0x3C/0x3D are zero-page
bytes; NES games reuse zero-page scratch aggressively across game states
(battle / menu / dialogue). Forcing them to 0 outside a strictly field-stable
window can stomp engine state mid-computation, which can surface downstream as
bad stats.

The real problem for debugging: there were **three** places issuing these writes
(`auto_step.lua` reset helper, plus two raw `writebyte` pairs in `main.lua` —
`DW_QOL_STATE.reset_movement_engine_state` and `apply_teleport_state_guard`).
That meant "toggle off `auto_step_reset_movement_on_route_turn_settle`" did NOT
silence all movement-byte writes, making the corruption impossible to bisect
cleanly.

### The fix (single write point)
- **auto_step.lua**: exported the existing canonical reset as
  `M.reset_movement_engine_state` (the function already used by all the gated
  seam/settle paths; honors `{log = false}`).
- **main.lua**: replaced BOTH raw `writebyte(MOVEMENT_STATE/SUBPIXEL, 0)` pairs
  with `auto_step.reset_movement_engine_state(reason, {log = false})`:
  - `DW_QOL_STATE.reset_movement_engine_state` (~line 5113) — keeps its richer
    `MOVEMENT_STATE_RESET` log line.
  - `apply_teleport_state_guard` (~line 5206) — keeps its own first-reset logging.
- Verified: **zero** raw `writebyte(addr.MOVEMENT_*)` remain in main.lua. Every
  0x3C/0x3D write in the codebase now lives in one function.

### Deliberate non-change
The `seam_retry_complete` resets in auto_step.lua (lines ~900, ~1044) still fire
**unconditionally** — they are NOT behind `should_reset_movement_on_route_turn_settle()`.
This is intentional: the existing test
`seam_retry_success_resets_movement_state_after_completion` asserts they fire.
Consolidating to one write point already gives the single gate the user asked
for. If we later want the toggle (or a new `auto_step_reset_movement_on_seam_retry`
flag) to silence seam-retry too, it is now a one-line change in the shared
`reset_movement_engine_state` plus a test update.

### Config note (not changed, flagged for decision)
`config.lua:92` ships the schema default `auto_step_reset_movement_on_route_turn_settle="true"`,
while `dw_access.ini:190` overrides it to `false`. Anyone regenerating the ini
from defaults silently re-enables the suspected-bad behavior. Consider flipping
the schema default to `false` until corruption is root-caused. Left as-is for
now (user's call).

---

## Files changed (working tree, uncommitted)

- `route_manager.lua` — `valid_npc_slot` helper; guarded `write_npc_bytes_if_changed`;
  two bypass sites validated; freeze/park/hold writes now share the guarded
  write path.
- `auto_step.lua` — exported `M.reset_movement_engine_state`.
- `main.lua` — two reset sites delegate to the shared auto_step reset.
- `test_route_manager.lua` — regression coverage for out-of-range raw NPC slots
  in reactive parking.
- `test_auto_step.lua` — regression coverage for the exported movement reset.

---

## Verification

- `luac5.1 -p route_manager.lua auto_step.lua main.lua test_route_manager.lua test_auto_step.lua`: pass.
- `lua5.1 test_auto_step.lua`: **72/72 pass.**
- `lua5.1 test_route_manager.lua`: **94/94 pass.**
- `python3 run_tests.py`: reaches **477 PASS** before the known speech dependency
  failure.
  - The movement-reset tests pass:
    `seam_retry_success_resets_movement_state_after_completion`,
    `queued_route_turn_settle_resets_movement_state`,
    `queued_route_final_step_resets_movement_state`,
    `queued_route_final_settle_keeps_resetting_movement_state`,
    `queued_route_final_settle_skips_movement_reset_when_disabled`, and
    `exported_reset_movement_engine_state_clears_movement_bytes`.
  - All 94 `test_route_manager.lua` tests pass, including the new invalid-slot
    guard regressions.
- The single FAIL (`accessible_output2` missing for the speech bridge) is
  **pre-existing and environmental**. Unrelated to these changes.

Test interpreters available locally: `/usr/bin/lua5.1`, `/usr/bin/luajit`,
`/usr/bin/lua`. Runner: `python3 run_tests.py`.

---

## Suggested next steps for Codex

1. **Decide on Suspect #2 verification strategy.** With the single write point in
   place, the cleanest A/B test is: re-enable
   `auto_step_reset_movement_on_route_turn_settle=true`, play the Garin's Grave
   B3 route, and watch for corruption. If it returns, the movement resets are
   confirmed as the trigger and the next move is to hard-gate the resets to a
   verified field-stable state (or gate seam-retry behind a flag too).
2. **Keep an eye on `dw_debug.log` for "NPC write refused"** during normal play.
   If it never fires, Suspect #1 stays purely theoretical. If it fires, capture
   the surrounding context (map, route, blocker) to find which object source is
   handing in a raw `.slot`.
3. **Optional hardening**: flip `config.lua:92` default to `false` so the safe
   state is the default until root cause is nailed.
4. Consider committing these two fixes on a branch before resuming the B3 /
   Silver Harp routing work, so the safety fixes are isolated from data changes.
