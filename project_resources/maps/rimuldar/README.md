# Rimuldar Map And Route Reference

Fetched: 2026-05-17

## Local Images

- `external/mikesrpgcenter_rimuldar.png`
  - Source page: https://mikesrpgcenter.com/dw1/maps/rimuldar.html
  - Source image: https://mikesrpgcenter.com/dw1/maps/rimuldar.png
  - PNG, 480x480 pixels
- `external/realmofdarkness_rimuldar.png`
  - Source page: https://www.realmofdarkness.net/dq/nes-dw-rimuldar/
  - Source image: https://www.realmofdarkness.net/dq/wp-content/img/nes/dw/maps/rimuldar-3.png
  - PNG, 731x698 pixels
- `external/realmofdarkness_rimuldar_shopinfo.png`
  - Source page: https://www.realmofdarkness.net/dq/nes-dw-town-maps/
  - Source image: https://www.realmofdarkness.net/dq/wp-content/img/nes/dw/maps/rimuldar-5.png
  - PNG, 757x500 pixels

Use these as visual orientation references only. Live movement probes,
`survey_map`, and `map_reader.lua` remain the source of truth for passability,
hidden seams, locked doors, and service interaction tiles.

## Guide Cross-Checks

- Gamer Corner Rimuldar location:
  https://guides.gamercorner.net/dw/locations/rimuldar
- Gamer Corner Rimuldar walkthrough:
  https://guides.gamercorner.net/dw/walkthrough/magic-keys-in-rimuldar
- Gamer Corner Magic Key shop:
  https://guides.gamercorner.net/dw/shops/rimuldar-magic-keys
- Gamer Corner South Rimuldar / Goldmen:
  https://guides.gamercorner.net/dw/walkthrough/goldmen-and-the-southern-cave
- Mike's RPG Center Rimuldar map:
  https://mikesrpgcenter.com/dw1/maps/rimuldar.html
- Mike's RPG Center walkthrough:
  https://mikesrpgcenter.com/dw1/walkthrough.html
- Realm of Darkness Rimuldar:
  https://www.realmofdarkness.net/dq/nes-dw-rimuldar/
- Realm of Darkness locked-door overview:
  https://www.realmofdarkness.net/dq/nes-dw-locked-doors/

## External Orientation

- Gamer Corner lists Rimuldar entrance as `(29S,59E)`. In the current local
  world-coordinate system, this matches the existing `overworld_rimuldar`
  object at `(102,72)`.
- Rimuldar is reached after exiting Swamp Cave on the south side. The guide
  route heads toward the town from the Swamp Cave south landing, then goes
  around the craggy mountains. Gamer Corner says the west route is safer than
  the east route, but the Rimuldar area is still dangerous at level 8-9.
- The current local route is already live-corrected from guide orientation:
  `rimuldar` runs from `Swamp Cave South Entrance` `(104,49)` to Rimuldar
  `(102,72)`, and `swamp_cave_south` returns from Rimuldar to the cave. Use
  `PLAYTESTING.md` and `session_handoff.md` for the latest route-shape caveats.

## Services And Items

- Inn: 55 G.
- Weapons/armor shop:
  - Copper Sword, 180 G
  - Hand Axe, 560 G
  - Broad Sword, 1500 G
  - Half Plate, 1000 G
  - Full Plate, 3000 G
  - Magic Armor, 7700 G
- Magic Key shop:
  - Magic Key, 53 G
  - This is the first Magic Key shop that does not require a key to reach.
  - Gamer Corner and Realm of Darkness list stack/carry limit as 6 keys.
- Treasure:
  - Wings / Wing of the Wyvern in a chest inside the inn.
  - Gamer Corner says the chest is behind two locked doors.
- Locked doors:
  - Gamer Corner lists two Rimuldar locked doors, both in the inn: outer and
    inner.
  - Realm of Darkness' locked-door page confirms Rimuldar is where keys should
    be purchased first before handling other locked locations.
- There is no tool shop in Rimuldar. Do not plan on buying Herbs there.

## Interesting Non-Merchant Notes

- The Magic Key shop is not just a shop target; it is a navigation puzzle. Realm
  of Darkness and Gamer Corner both say the player must walk around the outside
  / water edge of town to reach it. The service object should therefore confirm
  the public exterior approach and not assume normal building-counter access.
- The inn contains a two-door locked sequence, one chest, and at least one
  useful sage/hint contact. Gamer Corner says the first door brings the player
  to a sage who repeats the Kol clue: search four steps south of the bath for a
  magic item. Since the player already found the Fairy Flute, this is useful as
  a clue transcript rather than a new progression blocker.
- Practical status: weapon/armor, inn, Magic Keys, exits, and useful clue NPCs
  are cracked for playability. The first Wings chest door is pinned, but the
  opened chest-room pocket still has no confirmed walk-out route to the public
  network. `(13,18)` is a real false-wall connector elsewhere on the south side,
  but it is not currently reachable from the opened door-side start at `(23,23)`.
  Any remaining inn door/chest looting work should start by confirming whether a
  second guide-mentioned door/access point is missing or wrong.
- Rimuldar gives several main-quest hints:
  - Stones of Sunlight are hidden in Tantegel Castle.
  - Erdrick created a rainbow on the west side of the island.
  - The Dragonlord's castle has a hidden entrance behind the throne.
  - Old Man 3 asks, "Hast thou found a magic temple?", with a yes/no prompt.
    The access seam at `(1,23)<->(2,23)` is open both ways even though both
    cells decode as blocked; `(2,23)` is the public stand facing east.
  - A magic temple lies to the south.
  - Old Man 4 / Howard says that four steps south of the bath in Kol is a
    magic item, matching the Fairy Flute clue.
  - The Fighter's Ring hint is intentionally misleading/flavor; Gamer Corner
    notes the NPC mocks the ring if the player returns wearing it.
- South of Rimuldar is a strong gold-grinding area. Gamer Corner highlights
  Goldmen as excellent midgame gold, but warns that the region also has
  Wolflords, Wraiths, and Metal Scorpions. Herbs are limited because Rimuldar
  has no tool shop, so grinding there is risky until defenses improve.
- Immediate progression after keys is not "clear Rimuldar"; it is usually:
  buy keys, rest if needed, consider Broad Sword / Full Plate goals, then use
  keys to open earlier progression locations such as Tantegel's Stones of
  Sunlight route, Garinham's grave entrance, and eventually Swamp Cave's
  Gwaelin branch when the Green Dragon is safe.

## Local Live Status To Preserve

- Rimuldar `Exit to World Map` is live-confirmed at `(29,13)` facing east.
- Rimuldar `Merchant 2` is live-confirmed as the weapon/armor merchant at
  `(23,7)`. The planner-safe public stand is `(24,7)` facing west; the earlier
  `(23,9)` north-facing stand was stale for entrance-side route planning.
- Rimuldar `Merchant 3` is live-confirmed as the inn keeper at `(16,18)`. The
  route stand is `(16,17)` facing south, and TALK opens the 55 G inn prompt.
  The route to and from the east entrance is already smooth, so no new map
  blockers are attached to this service proof.
- Rimuldar `Old Man 1` is live-confirmed as the Magic Key merchant at `(4,7)`.
  The public route stand is `(4,5)` facing south across impassable counter
  `(4,6)`, and TALK opens the 53 G Magic Key prompt. `Merchant 1` at `(2,4)`
  is dialogue-only; reachable hidden-cell probes only produced the short
  `Welcome!` greeting, so he should stay out of Services.
- Rimuldar `Old Man 3` is live-confirmed as a temple-clue NPC at `(3,23)`.
  The practical public stand is `(2,23)` facing east; the west-side seam
  `(1,23)<->(2,23)` moved both ways during manual FCEUX play.
- Rimuldar `Old Man 4` / Howard is live-confirmed at `(20,23)` with a north
  stand at `(20,22)`. His dialogue gives the Kol bath / hidden magic item clue.
- Rimuldar `Wings Chest Door` is live-pinned at `(22,23)`. After the user
  opened the door from inside, `report_door_state` reported opened-door slot
  `0=(22,23)` while Bill stood at `(23,23)`. `inspect_tile:22,23` still decoded
  it as type-6 walkable floor, so `map_reader.lua` must treat it as a manual
  magic-key door until opened-door RAM lists it. The nearby Wings chest object
  is `chest_7` at `(24,23)`.
- Rimuldar Wings chest room walk-out is unresolved. `(13,18)` is live-confirmed
  as a real false-wall connector from `(13,19)` to the public-side row and back,
  but later locked-room return testing showed it is not reachable from the
  opened door pocket at `(23,23)` under the corrected blocker model. The row-22
  branch is real but dead-ended, and the lower row-25 hidden strip is real but
  isolated. The apparent `(21,23)->DOWN` throat into `(21,24)` moved only from a
  fresh forced origin; every legitimate door-side approach blocked, raw held
  DOWN did not move, and OPEN while facing south reported "There is no door
  here." Final parked-NPC survey from `(23,23)` to `exit_29_13` reports
  `path_found=false`, `blocked_events=0`, and `reason=no_path`. Do not promote
  `(19,25).east`; the verifier there was NPC-contaminated.
- The intended key-shop approach is the outer-bank route. From entry `(29,14)`,
  walk north along `x=29` to `(29,2)`, west along row 2 to `(21,2)`, north to
  `(21,0)`, west along `y=0` to `(0,0)`, south along `x=0` to `(0,3)`, and
  east across bridge `(1,3)->(2,3)`. Entering
  `x=0` horizontally below the top row exits to the World Map, so turn through
  `(0,0)`. Do not cross the entire top row from `(29,0)`: fixed `Person 4` at
  `(27,0)` blocks `(26,0)->RIGHT`, so the row-2 / x=21 jog is required. Bypass
  fixed `Merchant 1` at `(2,4)` via
  `(3,3)->(4,3)->(5,3)->(5,4)->(5,5)->(4,5)`, then TALK south across counter
  `(4,6)`. This full normal-movement route opened the 53 G shop prompt with no
  runtime blocks on 2026-07-15.
- Older key-shop modeling used hidden connector cells. `(24,7)->UP`
  moves into `(24,6)` even though tile `(24,6)` decodes blocked. The later
  entrance-to-key-shop shakedown proved `(19,9)` as the route bridge around the
  false `(24,9)` north pocket: `(19,10)->UP` into `(19,9)` moved 3/3,
  `(19,9)->UP` moved into `(19,8)`, `(19,8)->DOWN` moved back into `(19,9)`,
  and `(18,9)->RIGHT` into `(19,9)` moved 3/3. Follow-up route probes also
  model `(14,8)`, `(13,9)`, `(13,8)`, `(16,8)`, `(1,8)`, and `(1,7)` as
  passable hidden cells. Earlier `(1,7)->RIGHT` evidence into `(2,7)` was later
  superseded by repeated route-shaped blocks, so `(2,7).west` is now closed
  even though `(2,7)` remains standable from other approaches.
- The old generic town exit at `(15,14)` is invalid; it behaved as ordinary
  interior floor during live testing.
- First in-town walkabout seam review promoted exactly one directional block:
  `(28,13).south`, from repeated `(28,14)->UP` blocks with no NPC at either
  tile. The nearby valid exit route is `(29,14)->(29,13)->east`, and the noisy
  `(27,15).west` seam stays open because it moved on retry.
- The Magic Key route shakedown also promoted these directional-only blockers:
  `(24,12).south`, `(23,12).south`, `(25,11).east`, `(20,10).south/west`,
  `(21,11).west`, `(21,12).south/west`, `(24,8).south`, `(13,6).south`,
  `(13,8).east`, `(14,6).east/south`, `(13,7).east`, `(6,4).east`,
  `(6,5).east`, `(6,6).east`, `(2,6).west`, `(17,6).east`, and
  `(17,7).east`. The final key-counter maze then added hidden cells `(6,3)`,
  `(5,3)`, `(5,5)`, `(4,5)`, and `(3,5)`, plus blockers
  `(3,6).north/east`, `(5,6).north/west`, `(6,4).north`, and
  `(6,5).north/west`. The last route-solving passes added `(10,6).north`,
  `(13,9).south`, `(14,9).east/south`, `(15,9).south`, `(16,9).south`,
  `(17,9).south`, `(28,13).east`, `(17,9).east`, `(9,6).north/west`,
  `(12,6).north/west`, and `(13,6).north`. A later fresh run showed
  `(12,7)` is a true dead end on the north and east sides, so
  `(12,6).south` and `(13,7).west` are now blocked. The latest return-side
  lower-lane loops proved `(4,11).north`, `(5,11).north`, `(6,11).north`, and
  `(7,10).west`. The following entrance-side route loop proved four more
  false approaches before stale Alt returned: `(8,10).east`, `(9,11).north`,
  `(9,12).south`, and `(8,13).east`. The next both-direction pass added
  `(22,12).south`, `(9,12).east`, and `(8,14).east` on the entrance route,
  then closed the visible return pocket from `(3,11)` with `(3,12).north` and
  `(4,11).west`. The following loop batch showed `(5,7)` is a one-way trap
  east of the seller: close `(5,6).south`, `(4,7).east`, `(6,7).west`, and
  `(5,8).north`, and also close the false south-pocket connector
  `(17,17).east`. The latest batches add `(7,15).south`, `(6,16).east/south`,
  `(5,16).south`, `(3,13).south`, `(3,15).north`, `(7,10).north`,
  `(8,10).north`, `(10,6).east`, and `(6,3).east` after repeated clean loops.
  The `(6,3).east` block supersedes the older open note after a later reloaded
  return-route cluster hit it 6x. The newest pre-Alt route snapshot adds
  `(4,16).south`, `(3,16).south`, `(7,11).south`, `(4,8).south`,
  `(6,8).south`, `(6,4).west`, and `(6,3).west`; the last two supersede the
  previous plan that tried to return through `(5,4)->RIGHT` and
  `(5,3)->RIGHT`. The latest route/manual pass adds `(2,15).south`,
  `(3,16).west`, `(4,12).south`, `(3,13).east`, `(5,2).south`, and
  `(4,2).south`. The 2026-07-15 live route supersedes the old counter check:
  `(4,5)->DOWN` correctly blocks because `(4,6)` is the counter, while TALK
  south from `(4,5)` reaches the seller at `(4,7)`. The `(4,2).south` edge is
  a transition guard: `(4,3)->UP`
  changes to the world map, so in-town A* should route to the exit stand rather
  than through row 2. Follow-up route/manual evidence
  adds passthroughs `(1,5)`, `(1,13)`, `(3,9)`, and `(15,5)`, plus blockers
  `(3,15).west`, `(4,12).east`, `(5,11).south`, `(14,6).north`,
  `(24,12).north`, and `(25,11).west`. The newest clean log adds
  `(2,15).west`, `(6,11).south`, `(8,12).west`, `(4,4).south`, and
  `(4,3).south`; the next route-to-merchant loop adds `(7,14).west` and
  `(6,15).north` from repeated `(6,14)` bad exits. The latest weapon/key-route
  pass promotes `(25,12).east/south`, `(21,6).west`, `(21,7).west`,
  `(8,13).west`, and `(7,14).north`; the initial no-path in that batch was
  likely NPC occupancy at `(6,13)`, not terrain. The `(4,4)/(4,3)` blockers steer the key-stand-to-northwest-exit route
  through `(5,3)->LEFT` instead of the blocked `(4,4)->UP` seam. Later
  route-shaped evidence closed `(2,7).west`; `(2,7)` remains standable from
  other approaches. Nearby `(4,9).north`,
  `(4,10).north`, `(6,10).north`,
  `(25,14).east`, `(26,14).east`, `(28,14).east`, `(29,14).north`,
  `(4,5).south`, `(5,5).west`, and `(5,3).south` moved on retry or later
  passes and stay open. That `(4,5).south` approach enters `(4,5)` from below
  and is distinct from the counter collision at `(4,6).north`. Keep
  `(23,10).south`, `(14,8).south`, and
  `(5,3).east` open unless fresh proof supersedes this: they were
  mixed/passable later, affected by NPC occupancy, or explicitly passable.
- The old `(1,8)->RIGHT` bridge hypothesis is resolved as the wrong route, not
  a stateful seam. Keep `(2,8).west` unpromoted; it is irrelevant to the valid
  outer-bank route through `(1,3)`. Source still needs a test-first repair:
  `objects.lua` points the Magic Key service at stale stand `(4,6)` instead of
  `(4,5)`; `decompress_map()` treats packed-nibble interior map bytes as RLE;
  and blanket `engine_boundary` handling rejects the valid Rimuldar `y=0` and
  `x=0` bank cells. The live route above is the source of truth until those
  regressions and fixes land.
- `(6,6)` is not a full-cell blocker. It remains walkable from the modeled west
  lane, but the east approach from `(7,6)->LEFT` is a confirmed 3/3 raw verifier
  block. Do not delete `(6,6).east` to fix route planning.
- One Rimuldar inn / Wings chest door is pinned at `(22,23)`. Any additional
  guide-mentioned inn door and the chest contents still need live confirmation
  if the user wants the town completely looted.

## Suggested Survey Targets

For the next Rimuldar town pass:

- Locked inn doors:
  - Keep `(22,23)` as confirmed and pinned.
  - Confirm any other guide-mentioned door cell with OPEN from adjacent tiles
    before adding another door object or map door cell.
- Wings chest:
  - Do not route the opened door pocket back to public Rimuldar via `(13,18)`
    yet. That connector is real, but the corrected door-side model still gives
    no path from `(23,23)` to `exit_29_13`.
  - Before adding more blockers, verify whether a second inn door/access point
    is missing or whether the chest room is intended as an item/teleport pocket.
  - `chest_7` is at `(24,23)` in the object list; confirm contents/loot state
    live if desired.
- Quest-hint NPCs:
  - Prioritize NPCs with progression hints: Stones of Sunlight, Rainbow Drop /
    Dragonlord hidden entrance, Southern Cave, and Kol bath clue transcript.
  - Treat flavor-only NPCs as polish unless they block route geometry.
