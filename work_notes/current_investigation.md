# Current Investigation Scratchpad

Updated: 2026-05-25

The long Tantegel Castle map `0x04` shrine/key-merchant investigation has been
archived at:

- `handoff_archive/HANDOFF_2026-05-25_tantegel_investigation_scratchpad.md`
- `handoff_archive/HANDOFF_2026-05-25_tantegel_map04_wrapup_session_handoff_full.md`

## Active Status

- Active map is now `0x0C` / `Sun Shrine`.
- Tantegel Castle map `0x04` is gameplay-usable and parked for now.
- Shrine stairs and Magic Key Merchant routes are noisy but live-working.
- Continue the Sun Shrine decoding pass before returning to broader overworld
  playtesting.

## Sun Shrine `0x0C` Decode Start

External orientation sources:

- Realm of Darkness: `https://www.realmofdarkness.net/dq/nes-dw-tantegel/`
  includes a small "Stones Of Sunlight" inset connected from the Tantegel
  castle route.
- Mike's RPG Center: `https://mikesrpgcenter.com/dw1/maps/tantegel_3.png` is
  a cropped 10x10-ish shrine/cellar map image for the same Stones of Sunlight
  chamber.
- Mike's Dragon Warrior map index:
  `https://mikesrpgcenter.com/dw1/maps.html`

Fresh live anchors from `dw_debug.log`:

- `POSITION: map=0x0C(Sun Shrine) x=0 y=2`.
- All-object filter exposes three objects:
  - `Stairs to Tantegel Castle` / `exit_0_4` at `(0,4)`.
  - `Chest` at `(4,5)`.
  - `Old Man` / `npc_10` at `(4,6)`, raw NPC bytes `A4,46,00`, stationary.
- `dump_grid` reports size `10x10`.
- `report_survey_start` currently reports `reachable_area=0`,
  `status=isolated_start`, and `open_exits=east` from start `(0,2)`.

Initial decoder suspicion:

- `inspect_tile:0,2` and `inspect_tile:0,4` both report `reason=engine_boundary`
  and `walkable=false`, even though the player is live-standing on `(0,2)` and
  the exit object is `(0,4)`.
- `inspect_move:RIGHT` from `(0,2)` to `(1,2)` is model-passable, while
  `inspect_move:DOWN` to `(0,3)` is blocked by the same x=0 boundary rule.
- First likely fix to investigate is map-specific boundary/edge handling for
  `0x0C`, not a permanent full-map blocker patch.

Follow-up decode/survey results:

- `MAP_PASSTHROUGH_CELLS[0x0C]` now includes `(0,2)`, `(0,4)`, and `(0,7)`.
  `(0,7)` came from user/manual movement plus `SEAM_OBSERVATION ... moved`
  after `(1,7)->LEFT` reached the west edge.
- `objects.lua` now labels the return object as `Stairs to Tantegel Castle`,
  matching user confirmation that these stairs return to Tantegel interior, not
  the world map.
- Survey preflight from `(0,7)` stayed isolated until the running
  `map_survey.lua` module was refreshed; from interior tile `(1,7)`,
  `report_survey_start` was viable with `reachable_area=83`, `targets=3`.
- `survey_objects` run `1` from `(1,7)` reached the Old Man and Chest. The old
  man occupies `(4,6)` and blocks the chest's south side only; the route to the
  old man lands on the chest tile `(4,5)`, and the chest target then succeeds
  as `already_there`. Current live state after survey: `map=0x0C x=4 y=5`,
  `PATH_STATE target=Chest`, and `RUNTIME_BLOCKS map=0x0C none`.
- User quick-validation route from the entrance/west side to the old man drifted
  heavily but eventually completed. The log shows many row-7 reroutes, including
  loops through `(3,7)`, `(4,7)`, and `(5,7)`, plus noisy evidence on
  `(1,7).west`; it finally reached `(4,7)`, faced north, and opened old-man
  dialogue. Treat this as command/input drift or route-execution noise, not
  blocker evidence.
- Chest pickup succeeded after that route. The log recorded `Fortune smiles
  upon thee, Bill. Thou hast found the Stones of Sunlight.` Fresh state probe:
  `POSITION map=0x0C x=4 y=5`, `OBJECT: Chest (opened): here`,
  `PATH_STATE target=nil`, and `RUNTIME_BLOCKS map=0x0C none`.
- The only survey failure was `Stairs to Tantegel Castle`, classified as
  `command_timing_or_state_issue` / `route_drift_off_path`; no no-route,
  movement-failed, or suspected-engine-blocked evidence was recorded.
- `main.lua` now expands `reload_navigation_modules` so future live debug
  reloads refresh `objects`, `path_debug`, `map_survey`, and `map_crawler`
  along with `map_reader` and `pathfinder`. A full script reload is needed
  once before this improved hook is available in a running session.

## Do Not Promote Without Fresh Evidence

Route-local churn has appeared around `(23,9)`, `(24,9)`, `(18,14)`,
`(18,15)`, `(24,10)`, `(25,6)`, `(17,6)`, and `(15,5)`. These are not
permanent map facts. Promote only after clean post-reload verifier/manual
evidence.

## Recovery Reminder

If FCEUX movement controls wedge, use `clear_input` or
`./recover_fceux_input.sh`, then confirm with `input_status` and
`report_path_state`.
