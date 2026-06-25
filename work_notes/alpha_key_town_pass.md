# Alpha Key Town Pass

Working checklist for revisiting early towns now that the party has Magic Keys.
Use this as scratchpad guidance, not permanent project truth.

## Overall Rule

- Treat this as an alpha-prep smoke pass, not full map perfection.
- Prioritize stable routes to services, exits, stairs, locked doors, chests, and required search/object targets.
- Patch route geometry only when fresh live evidence proves the route failure is real.
- Keep runtime probes and uncertain door hypotheses out of permanent map data until door RAM or repeated live movement confirms them.

## Brecconary

Status, 2026-06-24:

- Complete for the current alpha-prep pass.
- Routes to both locked doors, all critical services, the Fairy Water merchant,
  the curse remover, and the town exit have been smoke-tested or patched.
- FCEUX still needs a manual Lua reload before the latest source-level fixes
  are live, but the live workaround restored object browsing to All at the
  exit tile.

Historical live baseline:

- Player is on `map=0x08(Brecconary)` at `(5,23)` after opening the inn west-room door.
- Magic Key count changed from `3` to `2`.
- Opened-door RAM slot `0=(5,23)`.
- Current selected door object was `Inn West Room Door`, formerly modeled at `(5,22)`.
- Manual OPEN from `(6,22)` facing west produced `There is no door here`.
- `verify_door_after` from `(6,23)` facing left confirmed expected door
  `(5,23)`, `expected_present=true`, and `key_delta=1`.
- `inspect_move:left` from `(6,23)` reports destination `(5,23)` as floor tile
  `4`, but the east approach was directionally blocked before the door opened.
- Follow-up route-out failure from the opened door cell was not door placement:
  raw left movement from `(5,23)` carried through `(4,23)` into type-0
  `(3,23)`, so `(3,23)` is a Brecconary passthrough.
- The false west exit from that bridge is blocked: same-origin `(3,23)->WEST`
  into `(2,23)` timed out, so `(2,23).east` is permanent directional data.
- Later restored-route testing superseded the earlier noisy north-corridor
  read: autowalk from `(6,23)` blocked twice on `(8,23)->UP`, and a direct
  same-origin probe from `(8,23)` timed out with `blocked_despite_open_preview`.
  Keep `(8,22).south` modeled as blocked and find the door-to-entrance detour
  around this edge.
- Frontier follow-up found that detour: `verify_walked_edge:6,21,right`
  walked normally to `(6,21)`, then crossed `(6,21)->RIGHT` through `(7,21)`
  despite the stale `(7,21).west` block. Keep `(7,21).west` open.
- After `reload_navigation_modules`, `auto_walk_blocker:1,15` from `(8,21)`
  queued `4 north, 7 west, 2 north`, reached `(1,15)`, restored parked NPCs,
  and left `RUNTIME_BLOCKS map=0x08 none`.
- `(8,11)->UP` still carries through decoded wall `(8,10)` to `(8,9)` when the
  route reaches that corridor.

Door research:

- Guide/project orientation says Brecconary has two locked doors:
  - Northeast building door.
  - West room in the inn.
- Current static model exposes:
  - `Northeast Door` at `(21,6)`.
  - `Inn West Room Door` at `(5,23)` after the live correction.
- The old `(5,22)` inn-west model was a ghost; OPEN from `(6,22)` facing west
  reported `There is no door here`.
- The live-confirmed inn stand is `(6,23)` facing west, expected door cell
  `(5,23)`.
- Likely northeast test stand:
  - `(21,7)` facing north, expected door cell `(21,6)`.

Use the verifier workflow for each suspected door:

```text
verify_door_stand:X,Y,DIR
manual OPEN from the ready stand
verify_door_after
```

Patch only after `verify_door_after` shows the expected door in opened-door RAM and a key delta.

Brecconary alpha smoke list:

- Done: pinned the two actual locked-door cells and interaction stands.
- Done: service routes to inn, weapons merchant, tool merchant, Fairy Water
  merchant, and curse remover.
- Done: route/filter behavior around the Exit to World Map, with a patch for
  reachable-filter collapse when standing on the in-town exit tile `(0,15)`.
- Done: object filters expose the real locked doors and public service stands.

## Tantegel Castle / Throne Room

- Recheck known Magic Key doors and treasure-room access.
- Recheck throne-room south door / stairs route if it is still in the route set.
- Finish or smoke-test returning Princess Gwaelin to the castle.
- Confirm door RAM/opened-door status does not pollute object visibility.

## Kol

- Smoke route to inn/shop services.
- Verify Fairy Flute search target and speech/readout.
- Check whether any key-gated object exists; do not assume a door without guide/live evidence.

## Rimuldar

- High priority before alpha because it sells Magic Keys.
- Smoke route to:
  - Magic Key merchant.
  - Inn.
  - Weapons/armor shop.
  - Wings chest route behind the known inn/chest doors.
  - Town exits.
- Recheck the two modeled Rimuldar doors and opened-door routing.

## Garinham

- Quick smoke only unless something breaks.
- Verify service routes and grave-door routing after reload.
- Avoid broad blocker hunting here; recent work says this town is good enough for normal play.

## Stop / Commit Points

- Commit after each town if route/object data changes.
- If a town only receives live verification and no code changes, update this checklist or `PLAYTESTING.md` only if the result changes alpha guidance.
- Stop live testing if command polling goes stale, the script needs a reload, or a test would spend a key without a nearby restore point and the player does not approve.
