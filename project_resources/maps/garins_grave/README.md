# Garin's Grave Map Reference

Updated: 2026-05-30

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

- Current live map is `0x18` / Garin's Grave B1.
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
  B2 is a `13x11` floor with six stair cells:
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
- Latest live staging has the hero on B2 `(1,10)` with those two B2 blockers
  re-injected into the FCEUX runtime overlay. The return path to B2 `(11,2)`
  currently plans as `7 north, 10 east, 1 north`.
- Guide route bias:
  - the nearby return-side stair and the center stair are dead-end/trap leads
  - northwest and southeast stairs lead toward the Cursed Belt branch
  - the southwest staircase is the main progression lead toward the Silver Harp

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

## Pending Live Verification

- Manually open/confirm the B1 northeast chest contents and exact content-code
  mapping. Current object coordinates are `(11,0)`, `(12,0)`, and `(13,0)`.
- Execute the B3 `(2,17)` to `(9,5)` route live and collect only clean direct
  verifier evidence if hidden blockers appear.
- Confirm whether B3 `(9,5)` lands on B4 `(0,4)`, then inspect the B4 connector
  toward `(5,4)`.
