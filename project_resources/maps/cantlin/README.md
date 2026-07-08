# Cantlin Map And Route Reference

Fetched: 2026-07-04

## Local Images

- `external/mikesrpgcenter_cantlin.png`
  - Source page: https://mikesrpgcenter.com/dw1/maps/cantlin.html
  - Source image: https://mikesrpgcenter.com/dw1/maps/cantlin.png
  - PNG, 480x480 pixels
- `external/realmofdarkness_cantlin.png`
  - Source page: https://www.realmofdarkness.net/dq/nes-dw-cantlin/
  - Source image: https://www.realmofdarkness.net/dq/wp-content/img/nes/dw/maps/cantlin-3.png
  - PNG, 840x860 pixels
- `external/vgmaps_cantlin.png`
  - Source image: https://vgmaps.com/Atlas/NES/DragonWarrior-Cantlin.png
  - PNG, 840x860 pixels
  - Current downloaded bytes match `realmofdarkness_cantlin.png`; keep as a
    source cross-check, not separate map evidence.
- `external/classicgamesparadise_cantlin.png`
  - Source page: https://www.classicgamesparadise.com/nes/Dragon%20Warrior%20Maps.html
  - Source image: https://www.classicgamesparadise.com/nes/Dragon%20Warrior/map%20Dragon_Warrior_cantlin.png
  - PNG, 666x536 pixels

Use these as visual orientation references only. Live movement probes,
`survey_map`, `sweep_walk`, and `map_reader.lua` remain the source of truth for
passability, hidden seams, locked doors, service interaction tiles, and the
town entrance/exit handoff.

## Service Guide Transcription

Cross-check sources:

- Mike's RPG Center Cantlin map: https://mikesrpgcenter.com/dw1/maps/cantlin.html
- Realm of Darkness Cantlin page: https://www.realmofdarkness.net/dq/nes-dw-cantlin/
- Gamer Corner Cantlin location: https://guides.gamercorner.net/dw/locations/cantlin
- Classic Games Paradise maps page: https://www.classicgamesparadise.com/nes/Dragon%20Warrior%20Maps.html
- Dragon Quest Wiki town maps page: https://dragon-quest.org/wiki/Dragon_Quest/Maps/Towns

Known Cantlin services and points of interest:

- Inn: 100 G.
- Weapon/armor shop, north/basic:
  - Bamboo Pole, 10 G
  - Club, 60 G
  - Copper Sword, 180 G
  - Leather Armor, 70 G
  - Chain Mail, 300 G
  - Large Shield, 800 G
- Tool shop, north:
  - Herb, 24 G
  - Torch, 8 G
- Tool shop, south:
  - Dragon's Scale, 20 G
  - Wings, 70 G
- Fairy Water shop:
  - Fairy Water, 38 G
- Weapon/armor shop, south:
  - Hand Axe, 560 G
  - Broad Sword, 1500 G
  - Full Plate, 3000 G
  - Magic Armor, 7700 G
- Magic Key shop:
  - Magic Key, 98 G
  - Guide sources mark this shop as key-locked.
- Locked weapon/armor shop:
  - Flame Sword, 9800 G
  - Silver Shield, 14800 G
  - Guide sources mark this shop as key-locked.
- Locked doors: Gamer Corner lists five on Cantlin 1F:
  - north side of western shop,
  - east side of western shop,
  - eastern building,
  - left door in central building,
  - right door in central building.
- Live locked-door status:
  - Confirmed eastern building door: door cell `(26,9)`, opened from public
    stand `(25,9)` while facing east. Live verifier proof on 2026-07-07 showed
    keys `6 -> 5` and opened-door RAM slot `0=(26,9)`.
  - Confirmed central right door: door cell `(15,25)`, opened from public
    stand `(15,24)` while facing south. Live verifier proof on 2026-07-07
    showed keys `5 -> 4` and opened-door RAM slot `1=(15,25)`.
  - Confirmed central left door: door cell `(14,25)`, opened from public stand
    `(14,24)` while facing south. Live verifier proof on 2026-07-07 showed
    keys `4 -> 3` and opened-door RAM slot `2=(14,25)`.
  - Confirmed western shop north door: door cell `(4,21)`, opened from public
    stand `(4,20)` while facing south. Live verifier proof on 2026-07-08
    showed keys `3 -> 2` and opened-door RAM slot `3=(4,21)`.
  - Confirmed western shop east door: door cell `(8,25)`, opened from public
    stand `(7,25)` while facing east. Live verifier proof on 2026-07-08 showed
    keys `2 -> 1` and opened-door RAM slot `4=(8,25)`.
  - The exact five-repeat door-icon tile in `mikesrpgcenter_cantlin.png`
    appears at `(26,9)`, `(4,21)`, `(8,25)`, `(14,25)`, and `(15,25)`; all
    five now have live OPEN/door-RAM proof.
  - Disproved/non-door checks include `(5,12)` facing right/up, `(4,12)`
    facing up/right, and the eastern facade candidate `(25,13)` facing up
    toward `(25,12)`.
- Progression notes:
  - Sources describe Cantlin as guarded by Golem and recommend the Fairy Flute.
    Current project evidence says the latest live approach entered town without
    a fixed Golem encounter in this save/state, so treat guide boss notes as
    gameplay orientation rather than current-state proof.
  - A wise man in town gives Erdrick's Token coordinates.
  - The town is a major gear stop before further overworld validation.

## First Decode Priorities

- Confirm live entry and exit coordinates. Current repo state says the player
  entered map `0x0A` at `(15,0)`, while `objects.lua` still has an old hardcoded
  Cantlin exit at `(14,29)`. Do not trust either direction until live movement
  proves the town/world handoff.
- Run a parked-NPC object/service survey from the live entrance component before
  adding service objects. Cantlin has many separate walled pockets, so an
  "unreachable" result may mean a locked door or hidden connector, not a bad
  service coordinate.
- Identify live NPC slots and public stand/facing for each shop/inn prompt
  before adding service interaction overrides.
- Decode the five locked-door cells separately from service stands. Treat Magic
  Key and Flame Sword/Silver Shield access as key-gated route work, not ordinary
  open-town routing.
- Prioritize player-useful services first:
  - Inn,
  - south weapon/armor shop for Hand Axe/Broad Sword/Full Plate/Magic Armor,
  - Magic Key shop,
  - locked Flame Sword/Silver Shield shop if the player has keys,
  - Fairy Water and tool shops.

## Live Baseline Note

On 2026-07-04, an attempted fresh `report_position` was not queued because
`dw_debug.log` was stale by more than the `--require-live` window. Before live
Cantlin decoding, restart/reload the Lua loop and confirm command polling with
`launcher_probe` or a fresh `report_position`.
