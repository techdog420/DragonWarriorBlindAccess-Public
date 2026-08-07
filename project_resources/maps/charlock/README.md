# Charlock Castle Map And ROM Reference

Fetched: 2026-08-03

This folder contains orientation material for decoding Charlock Castle and the
Dragonlord dungeon. External maps and guide claims are research aids only.
Live FCEUX movement, map transitions, SEARCH behavior, doors, and object state
remain the source of truth before permanent data is added to the mod.

## Local Assets

- `chatgpt_research_notes.txt`
  - User-supplied research note that motivated this reference pass.
  - It includes a proposed main progression spine, optional sword branch, B6
    loop warning, final-lair objects, and source links.
- `external/mikesrpgcenter_charlock_level_1.png`
  - Ground floor / guide Level 1, 320x320 pixels.
- `external/mikesrpgcenter_charlock_level_2.png`
  - B1 / guide Level 2, 352x352 pixels.
- `external/mikesrpgcenter_charlock_level_3.png` through
  `external/mikesrpgcenter_charlock_level_7.png`
  - B2 through B6 / guide Levels 3 through 7, each 192x192 pixels.
- `external/mikesrpgcenter_charlock_level_8.png`
  - Dragonlord's Lair / B7, 480x496 pixels.
- `external/realmofdarkness_charlock_composite.png`
  - Labeled eight-floor composite, 1581x1145 pixels.
- `external/vgmaps_charlock_composite.png`
  - VGMaps copy of the same labeled composite, 1581x1145 pixels.
  - This file is byte-for-byte identical to the Realm of Darkness copy:
    SHA-256 `C0E6088742D16F20D3106E9C05E2EEC0D0A98D5F441316A6BB7B5F3F1475A09D`.
    Keep both filenames only to preserve the two provenance paths; they are not
    independent map evidence.
- `rom_stair_graph.tsv`
  - Machine-readable zero-based transition graph transcribed from the pinned
    ROM disassembly tables.

## External Sources

- Mike's RPG Center Charlock page:
  https://mikesrpgcenter.com/dw1/maps/charlock_castle.html
- Mike's individual image pattern:
  `https://mikesrpgcenter.com/dw1/maps/charlock_b1.png` through
  `charlock_b8.png`
- Realm of Darkness Charlock page:
  https://www.realmofdarkness.net/dq/nes-dw-charlock-castle/
- Realm of Darkness composite image:
  https://www.realmofdarkness.net/dq/wp-content/img/nes/dw/maps/charlock-2.png
- VGMaps NES index:
  https://www.vgmaps.com/atlas/NES/index.htm
- VGMaps composite image:
  https://www.vgmaps.com/Atlas/NES/DragonWarrior-CharlockCastle.png
- Gamer Corner Charlock overview and linked floor graph:
  https://guides.gamercorner.net/dw/locations/charlock-castle
- Data Crystal ROM map offsets:
  https://datacrystal.tcrf.net/wiki/Dragon_Warrior/ROM_map
- Dragon Warrior disassembly, pinned commit:
  https://github.com/nmikstas/dragon-warrior-disassembly/tree/ebe6a13da77a3593c67300f54d95ed49c23effc2
- Pinned map metadata and collision behavior (`Bank00.asm`):
  https://github.com/nmikstas/dragon-warrior-disassembly/blob/ebe6a13da77a3593c67300f54d95ed49c23effc2/source_files/Bank00.asm
- Pinned SEARCH logic and stair tables (`Bank03.asm`):
  https://github.com/nmikstas/dragon-warrior-disassembly/blob/ebe6a13da77a3593c67300f54d95ed49c23effc2/source_files/Bank03.asm

## Floor Naming And ROM IDs

Use the following names in the mod unless live state disproves them. Mike's
images call these Levels 1 through 8; Gamer Corner calls them 1F and B1-B7.

- Ground Floor / 1F: map `0x02`, 20x20.
- B1: map `0x0F`, 20x20.
- B2: map `0x10`, 10x10.
- B3: map `0x11`, 10x10.
- B4: map `0x12`, 10x10.
- B5: map `0x13`, 10x10.
- B6: map `0x14`, 10x10.
- Dragonlord's Lair / B7: map `0x06`, 30x30.

The disassembly metadata encodes dimensions as maximum zero-based coordinates,
so `$13` means coordinates `0..19`, `$09` means `0..9`, and `$1D` means
`0..29`.

Ground-floor live evidence already agrees with this namespace: World Map
`(48,48)` enters map `0x02` at `(10,19)`. Record the live map ID and position
after every deeper staircase before binding floor names in source.

## Hidden Passage Behavior

The hidden route is special state, not an ordinary visible stair:

- Throne clue tile: ground floor `(10,3)`. SEARCH reports wind from behind the
  throne.
- Hidden passage tile: ground floor `(10,1)`.
- Before discovery, the engine substitutes a force-field block for the stair
  at `(10,1)`.
- SEARCH while standing at `(10,1)` sets `F_PSG_FOUND`, modifies the current
  map block, and reveals stairs down.
- The revealed stair connects to B1 map `0x0F` at `(9,0)`.

Accessibility implication: expose `(10,1)` as a searchable landmark before
discovery, then as stairs after discovery. Do not model it as permanently
passable stairs from startup.

## ROM-Confirmed Main Progression Spine

Coordinates are zero-based. Each arrow is bidirectional through the paired
down/up stair records.

1. Ground `0x02 (10,1)` -> B1 `0x0F (9,0)`; SEARCH required first.
2. B1 `0x0F (8,19)` -> B2 `0x10 (5,0)`.
3. B2 `0x10 (3,0)` -> B3 `0x11 (7,0)`.
4. B3 `0x11 (1,6)` -> B4 `0x12 (0,9)`.
5. B4 `0x12 (2,2)` -> B5 `0x13 (9,0)`.
6. B5 `0x13 (0,0)` -> B6 `0x14 (0,6)`.
7. B6 `0x14 (9,6)` -> Dragonlord's Lair `0x06 (10,29)`.

## Branches And Traps

- Ground-floor visible decoys:
  - `(4,14)` -> B1 `(8,13)`.
  - `(15,14)` -> B1 `(17,15)`.
  These lead into the large B1 branch network rather than the hidden main
  entrance behind the throne.
- B4 sword/upward branch: B4 `(7,7)` returns to B3 `(7,7)`. The live-proven
  route crosses B3 to `(2,2)`, uses the adjacent B2/B1 stair pair, follows the
  B1 east-boundary/southwest zigzag from `(15,1)` to `(13,7)`, and enters the
  isolated B2 sword room at `(4,4)`. The chest is at `(5,5)`; taking it raised
  the hero's Attack from 115 to 127. The complete reverse route is also proven.
- B4 false inner branch: B4 `(8,1)` -> B5 `(4,0)`. The live-proven B5 route
  crosses hidden top cells `(5,0)..(7,0)`, then follows the inner corridor to
  B5 `(5,5)` -> B6 `(0,0)`.
- B6 same-floor loop: the complete hidden top row `(0,0)..(9,0)` is
  live-proven, and STAIRS at `(9,0)` sends the player back to B6 `(0,0)`.
  Treat this as a deliberate routing trap, not a normal floor change. Two
  apparent `(3,0)->(4,0)` blocks were confirmed control-lock contamination and
  are not map evidence. After source reload, the planner and autowalk completed
  the row as exactly `9 east` with no runtime blockers, and the stair again
  returned to `(0,0)` on map `0x14`.
- Loaded component audit: B3 entry `(7,0)` can reach true descent `(1,6)`
  directly, so its false-return stair loop is optional. B4 main descent
  `(2,2)`, false-inner stair `(8,1)`, and sword-return stair `(7,7)` are in one
  walking component. On B5, main arrival/descent `(9,0)/(0,0)` is disconnected
  from false-inner arrival/descent `(4,0)/(5,5)`. On B6, main
  arrival/descent `(0,6)/(9,6)` is disconnected from loop endpoints
  `(0,0)/(9,0)`.
- The complete branch graph is in `rom_stair_graph.tsv`; B1 has seven separate
  stair pairs with B2, and B2 has four with B3.

## Final Lair Live Result

The main final-floor route is now live-confirmed:

- Entry from B6: `(10,29)`.
- Return stair: `(10,29)` -> B6 `(9,6)`. The reverse transition is live-proven,
  and loaded object navigation reports `South Stairs Up: here (1 of 1)` under
  Travel at the exact entry coordinate.
- The route winds around the outer corridor, crosses raw-type-0 passages at
  `(28,13)`, `(28,14)`, `(25,16)`, and `(25,21)`, and reaches the east-side
  Dragonlord approach `(17,24)`.
- Dragonlord occupies `(16,24)`. TALK from `(17,24)` produced his opening
  dialogue, and loaded object browsing identifies him as `Dragonlord`.
- The locked treasure-room door is `(17,12)`. OPEN from `(18,12)` facing west
  consumed one key and wrote opened-door RAM `(17,12)`. The raw type-5 tile at
  return stair `(10,29)` is not a door. Source now names the real door and makes
  it planner-passable only when its RAM slot is open. After reload, the tile
  reported `reason=door_open` and ordinary movement crossed it in both
  directions.
- The locked central room's six live-opened chests are `(11,11)` Herb,
  `(11,12)` 680 gold, `(12,12)` Magic Key, `(11,13)` Wings, `(12,13)` Cursed
  Belt, and `(13,13)` Herb. If Herb inventory is already at its maximum of six,
  TAKE still consumes the Herb chest while reporting `Unfortunately, it is
  empty.` The item is lost. A later TAKE reports `There is nothing to take
  here`. Object tracking now treats either definitive message as opened even
  without an inventory increase; the loaded fix marked `(13,13)` opened.
- The safe treasure-room return is live-proven. Ordinary autowalk from the
  final chest `(13,13)` crossed the open door `(17,12)`, reached its outside
  stand `(18,12)`, and followed the 25-step outer-corridor route back to lair
  stair `(10,29)`. Two Armored Knights and one Red Dragon were combat-only
  interruptions; every resumed segment finished with zero runtime blockers.
- The Dragonlord offer is destructive to an unsaved run: accepting it freezes
  the game state and requires reset. Preserve a safe test/save boundary before
  dialogue validation.

## Resolved Source Status

The hidden ground-floor route, main spine through maps `0x0F` to `0x14`, final
descent, Dragonlord approach, Erdrick's Sword branch, B4/B5 false branch, and
B6 same-floor loop are live-proven and modeled. The stale deeper stair
placeholders were replaced with the ROM-backed coordinates. The final-lair
treasure door coordinate, interaction stands, key consumption, and opened-door
RAM state are live-proven and modeled. All six treasure-room chest coordinates,
contents, the full-Herb loss behavior, and the safe return to `(10,29)` are
also live-proven.
Other optional branch stairs remain orientation until their connected walking
routes are decoded.

## Recommended Remaining Decode Order

1. Decode the visible ground-floor decoy stairs and remaining B1/B2 branch
   network.
2. Decode the final-floor throne enclosure and any remaining optional pockets.
