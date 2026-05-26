# Current Investigation Scratchpad

Updated: 2026-05-25

The long Tantegel Castle map `0x04` shrine/key-merchant investigation has been
archived at:

- `handoff_archive/HANDOFF_2026-05-25_tantegel_investigation_scratchpad.md`
- `handoff_archive/HANDOFF_2026-05-25_tantegel_map04_wrapup_session_handoff_full.md`

## Active Status

- No active map `0x04` blocker investigation is open.
- Tantegel Castle map `0x04` is gameplay-usable and parked for now.
- Shrine stairs and Magic Key Merchant routes are noisy but live-working.
- Continue with normal gameplay/playtesting unless a fresh failure appears.

## Do Not Promote Without Fresh Evidence

Route-local churn has appeared around `(23,9)`, `(24,9)`, `(18,14)`,
`(18,15)`, `(24,10)`, `(25,6)`, `(17,6)`, and `(15,5)`. These are not
permanent map facts. Promote only after clean post-reload verifier/manual
evidence.

## Recovery Reminder

If FCEUX movement controls wedge, use `clear_input` or
`./recover_fceux_input.sh`, then confirm with `input_status` and
`report_path_state`.
