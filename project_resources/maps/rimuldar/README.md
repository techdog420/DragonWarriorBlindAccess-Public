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
- Rimuldar gives several main-quest hints:
  - Stones of Sunlight are hidden in Tantegel Castle.
  - Erdrick created a rainbow on the west side of the island.
  - The Dragonlord's castle has a hidden entrance behind the throne.
  - A magic temple lies to the south.
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
  The public route stand is `(4,6)` facing south, and TALK opens the 53 G Magic
  Key prompt. `Merchant 1` at `(2,4)` is dialogue-only; reachable hidden-cell
  probes only produced the short `Welcome!` greeting, so he should stay out of
  Services.
- The key-shop approach uses confirmed hidden connector cells. `(24,7)->UP`
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
  `(4,2).south`. The later Magic Key counter check reopens `(4,6).north`
  because `(4,6)` is the correct public stand and must be reachable from
  `(4,5)->DOWN`. The `(4,2).south` edge is a transition guard: `(4,3)->UP`
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
  passes and stay open. Keep `(23,10).south`, `(14,8).south`, and
  `(5,3).east` open unless fresh proof supersedes this: they were
  mixed/passable later, affected by NPC occupancy, or explicitly passable.
- The entrance route from the town entrance `(29,13)` to the key stand `(4,6)`
  is not solved yet. Older static proofs were superseded by live route/seam
  evidence. The newly found northwest exit at `(4,3)` facing north still gives
  a 5-step route from the key stand and is exposed as `Northwest Exit to World
  Map`; the old key-to-east-exit route is geometry-only and invalid while Old
  Man 1 occupies `(4,7)`, because it walks south through the seller. The user
  found the key strip by crossing `(4,8)->DOWN` into `(4,9)`, but fresh
  evidence says the seller's own `(4,7)` cell blocks movement; `objects.lua`
  now blocks that NPC while keeping the `(4,6)` interaction override. The
  latest frontier pass closes `(3,8).south`, `(2,8).south`, `(5,8).south`,
  `(6,8).east`, `(6,7).east`, and `(6,2).east`. `(3,7)` remains a modeled
  hidden cell and `(3,6).south` remains open, but it is not a solved bridge
  after `(3,8).south` closed. Local ROM-backed A* currently reports no path
  from `(29,14)` to the key stand with the seller blocking movement. The only
  one-cell frontier left is noisy `(1,8)->RIGHT` into `(2,8)`: one verifier was
  mixed, then a harder run blocked 10/10 while stale FCEUX `LeftAlt` was still
  active. Do not expose `(2,8)` until a clean post-reload verifier resolves
  that west approach. A later clean trace superseded the earlier
  `(28,13).east` uncertainty, so that approach is now modeled as blocked. If
  the live planner reports no path again, inspect the new
  `AUTO_WALK_NO_PATH_DETAIL` line and `report_path_state` before patching more
  map data.
- `(6,6)` is not a full-cell blocker. It remains walkable from the modeled west
  lane, but the east approach from `(7,6)->LEFT` is a confirmed 3/3 raw verifier
  block. Do not delete `(6,6).east` to fix route planning.
- Inn doors, Wings chest, and quest-hint NPC route stands still need live
  service confirmation before permanent object patches beyond the existing
  route/weapon-shop/inn/key-shop/exit work.

## Suggested Survey Targets

For the next Rimuldar town pass, prove these before patching `objects.lua`:

- Locked inn doors:
  - Confirm exact door cells with OPEN from adjacent tiles before adding door
    objects or map door cells.
  - Track key count before/after if possible.
- Wings chest:
  - Confirm chest coordinate and whether the route requires both inn doors.
- Quest-hint NPCs:
  - Prioritize NPCs with progression hints: Stones of Sunlight, Rainbow Drop /
    Dragonlord hidden entrance, Southern Cave, and Kol bath clue transcript.
  - Treat flavor-only NPCs as polish unless they block route geometry.
