# Garin's Grave Map Reference

Updated: 2026-06-17

This folder stores orientation notes for Grave of Garinham / Garin's Grave.
Guide data is for route-shape orientation only; live FCEUX movement remains the
source of truth for map data.

## Local Assets

- `realm_grave_garinham.png`: Realm of Darkness composite map for all four NES
  grave floors.
- `mikes_garins_grave_b1.png`: Mike's RPG Center B1 map image.

## Sources

- Realm of Darkness Grave of Garinham NES page:
  `https://www.realmofdarkness.net/dq/nes-dw-grave-garinham/`
- Realm of Darkness map image:
  `https://www.realmofdarkness.net/dq/wp-content/img/nes/dw/maps/grave-garinham-2.png`
- Mike's RPG Center Garin's Grave map page:
  `https://www.mikesrpgcenter.com/dw1/maps/garins_grave.html`
- Mike's RPG Center B1 image:
  `https://www.mikesrpgcenter.com/dw1/maps/garins_grave_b1.png`
- Gamer Corner Garinham B1 floor page:
  `https://guides.gamercorner.net/dw/location-floors/garinham-b1`
- Gamer Corner walkthrough page:
  `https://guides.gamercorner.net/dw/walkthrough/garins-tomb-and-the-silver-harp`

## Live Anchors

- Garin's Grave route decoding wrapped on 2026-06-17. Treat this dungeon as
  complete for current playtesting unless a fresh gameplay failure appears.
- Entry live map is `0x18` / Garin's Grave B1.
- Live FCEUX position after entering from Garinham is `(6,11)`.
- Using STAIRS from `(6,11)` returns to Garinham `(19,0)`.
- The old `Exit to World Map` object at `(0,0)` was stale and has been removed.
- `objects.lua` now exposes `stair_6_11` as `Stairs to Garinham`.
- Local ROM table pass found the B1 stair-down entry at `(1,18)` and B1 chest
  entries at `(11,0)`, `(12,0)`, and `(13,0)`.
- Live play shows the B1 treasure row itself is standable even though moving
  north past it can leave the map: `(11,0)` produced SEARCH text saying there
  is a treasure box, `(12,0)` also produced the treasure-box SEARCH text, and
  `(13,0)` held stable through a forced-teleport guard.
- 2026-06-16 B1 entrance route cleanup: live FCEUX movement round-tripped
  between `Stairs to Garinham` `(6,11)` and `Stairs Down` `(1,18)`. The false
  short return route through `(3,17)->RIGHT` blocked twice under same-origin
  probes from a normally walked origin, so `(4,17).west` is permanent map data.
  A follow-up at normally reached `(17,9)` blocked `(17,9)->LEFT` into
  `(16,9)` twice, so `(16,9).east` is also permanent map data. Pulling the
  remaining live runtime overlay before reload promoted `(17,8).south`,
  `(18,8).north`, `(7,10).north`, and `(19,12).north`. Follow-up
  `auto_walk_blocker` cleanup confirmed `(16,7)->DOWN` into `(16,8)` and
  normally reached `(17,18)->DOWN` into `(17,19)` as blocked under repeated
  same-origin probes, then found and confirmed the east/west entries
  `(18,19)->LEFT` and `(16,19)->RIGHT` into `(17,19)` the same way.
  `(16,8).north` and `(17,19).north/east/west` are now permanent map data.
  Noisy `(18,8).south` is still unpromoted.

## Guide Orientation For B1

- Mike's RPG Center labels B1 point `1` as the entrance/exit and point `2` as
  the northeast chest cluster.
- Gamer Corner says B1 has three treasures: Herb, 5-20 GOLD, and 6-13 GOLD.
  Mike's RPG Center lists the same chest cluster with slightly different gold
  ranges: Herb, 6-20 G, and 7-12 G.
- Gamer Corner lists one locked door on B1, in the southeast part of the floor;
  the walkthrough says this door leads toward B2 and requires a Magic Key.
- Gamer Corner route orientation: from the B1 stairs, go generally east and
  north to a four-way intersection, then east to the wall. From there, north
  reaches the treasure cluster and south reaches the locked door/stairs toward
  B2.
- Realm of Darkness lists five total Grave of Garinham treasures across the
  dungeon: 5-20 Gold, 6-13 Gold, Cursed Belt, Herb, and Silver Harp.

## Guide Orientation For B2

- B2 is a stair hub rather than a full maze floor.
- Local ROM stair tables plus the Realm of Darkness composite map agree that
  B2 is a `14x12` floor, max coordinate `(13,11)`, with six stair cells:
  - up to B1 at `(11,2)`
  - down stairs at `(1,1)`, `(12,1)`, `(5,6)`, `(1,10)`, `(12,10)`
- The older object placeholders `(19,0)` and `(12,12)` were impossible on this
  floor and have been removed from `objects.lua`.
- Live follow-up confirmed the corrected B2 return stair at `(11,2)` and
  confirmed the southwest B2 stair `(1,10)` deposits on B3 `(2,17)`.
- Follow-up route cleanup toward the southwest stair confirmed two B2
  directional blockers in map data: `(2,10).east` and `(3,9).south`. Mixed
  candidates `(8,9).east`, `(3,11).north`, and `(1,11).east` remain
  unmodeled.
- Latest live B2 route status supersedes the older all-stairs-reachable audit:
  from the B2 return stair `(11,2)`, the prior permanent model reached
  `Stairs Up`, `Northeast Stairs Down`, `Southeast Stairs Down`, and
  `Southwest Stairs Down`, while `Central Stairs Down` `(5,6)` returned
  `No path found`.
- A 2026-06-16 west-chest escape pass found new normal-walked evidence on the
  northwest side: from `Northwest Stairs Down` `(1,1)` or the B2 northwest
  landing `(1,2)`, the player can enter the left-edge false-boundary strip at
  `(0,1)`/`(0,2)`, follow it down through `(0,11)`, exit right to `(1,11)`,
  and reach `Stairs Up` `(11,2)`. The permanent model now scopes B2
  passthroughs for `(0,1)` through `(0,11)`.
- The same pass closed false shortcuts at `(1,2).north/south`, `(2,1).west`,
  `(2,2).west`, `(2,8).west`, `(1,9).north`, and `(1,9).west`. The reverse
  route from B2 `Stairs Up` back toward `Northwest Stairs Down` is not
  live-proven yet; if object navigation exposes it after reload, verify that
  direction explicitly.
- The southwest staircase remains the confirmed Silver Harp progression lead.

## Guide Orientation For B3 And B4

- Local ROM stair tables now back the full B3/B4 static stair objects too.
- B3 (`19x19`) exposes five return stairs up to B2 at `(14,1)`, `(18,1)`,
  `(6,11)`, `(2,17)`, and `(18,13)`, plus two down stairs to B4 at `(9,5)` and
  `(10,9)`.
- B4 (`9x9`) exposes two return stairs up to B3 at `(0,4)` and `(5,4)`.
- Live proof so far: the B2 southwest stair `(1,10)` maps to B3 `(2,17)`,
  matching the fourth stair entry in the ROM table order.
- Read-only live path check from B3 `(2,17)` to the likely progression stair
  `(9,5)` succeeds with `12 north, 7 east`.
- B3 west chest / likely Cursed Belt route note: the earlier NW-side dead-end
  conclusion was superseded by the live false-boundary route through top-row
  cells `(8,0)`, `(9,0)`, `(10,0)`, left-edge cells `(0,2)` through `(0,6)`,
  and chest-side cells `(1,2)` and `(2,2)`. The B2 escape pass above completes
  the current route back to the upward stairs after leaving the B3 chest side.
  The player has since opened this chest and confirmed the Cursed Belt.
- After the Cursed Belt pickup, a B3 NW-side object cleanup proved the false
  reachable routes to `Upper Stairs Down` `(9,5)`, `Southeast Stairs Up`
  `(18,13)`, and `Southwest Stairs Up` `(2,17)` all collapse behind
  `(5,2).north` and `(1,7).north`. With those blockers active, the NW-side
  reachable-object list is just the opened chest and local `Northwest Stairs
  Up`; reload Lua before rechecking this without runtime overlays.

## Pending Live Verification

- Optional polish: manually open/confirm the B1 northeast chest contents and
  exact content-code mapping. Current object coordinates are `(11,0)`,
  `(12,0)`, and `(13,0)`.
- If future gameplay exposes a reverse B2 route from `Stairs Up` to
  `Northwest Stairs Down`, verify that direction live before documenting it as
  player-facing two-way travel.
