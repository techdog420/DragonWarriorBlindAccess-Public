# Hauksness Map And Decode Reference

Fetched: 2026-07-24

Use these references for orientation and test planning only. Live FCEUX
movement, normal-route arrival, same-origin probes, and the repository's own
ROM decoding remain the source of truth. Do not import map bytes, coordinate
tables, or implementation code from the outside accessibility mod.

## Current Verified State

- Game map ID: `0x03` (`Ruins of Hauksness`).
- Live entry from World Map `(25,89)` lands at Hauksness `(0,10)`.
- Moving west from Hauksness `(0,10)` returns to World Map `(25,89)`.
- Hauksness is represented as a 20-by-20 map in the visual references and in
  the outside mod's independently extracted snapshot.
- Interior passability, false walls, directional blockers, the fixed encounter,
  and the hidden armor event have not yet been verified by this project.

## Local Images

- `external/mikesrpgcenter_hauksness.png`
  - Source page: https://mikesrpgcenter.com/dw1/maps/hauksness.html
  - Source image: https://mikesrpgcenter.com/dw1/maps/hauksness.png
  - PNG, 320 by 320 pixels.
  - The image is a direct 20-by-20 tile map. Its numbered point `1` is on tile
    `(18,12)` and is identified by the source page as Erdrick's Armor guarded
    by an Axe Knight.
- `external/realmofdarkness_hauksness.png`
  - Source page:
    https://www.realmofdarkness.net/dq/nes-dw-hauksness/
  - Source image:
    https://www.realmofdarkness.net/dq/wp-content/img/nes/dw/maps/hauksness-3.png
  - PNG, 770 by 535 pixels.
  - Includes the town map plus labels for Erdrick's Armor, the Axe Knight, and
    the town encounter set.
- `external/vgmaps_hauksness.png`
  - Source page: https://vgmaps.de/maps/view?m=1945
  - Source image:
    https://vgmaps.com/Atlas/NES/DragonWarrior-Hauksness.png
  - PNG, 770 by 535 pixels.
  - Byte-for-byte identical to `realmofdarkness_hauksness.png`; retain only as
    a source cross-check, not as independent map evidence.
- `external/classicgamesparadise_hauksness.png`
  - Source page:
    https://www.classicgamesparadise.com/nes/Dragon%20Warrior%20Maps.html
  - Source image:
    https://www.classicgamesparadise.com/nes/Dragon%20Warrior/map%20Dragon_Warrior_hauksness.png
  - PNG, 412 by 414 pixels.
  - Unlabeled layout reference.

## Guide Cross-Checks

- GameFAQs Hauksness walkthrough:
  https://gamefaqs.gamespot.com/nes/563408-dragon-warrior/faqs/82541/hauksness
- Gamer Corner Hauksness walkthrough:
  https://guides.gamercorner.net/dw/walkthrough/erdricks-armor-in-hauksness
- Gamer Corner Hauksness location data:
  https://guides.gamercorner.net/dw/locations/hauksness
- Realm of Darkness Hauksness page:
  https://www.realmofdarkness.net/dq/nes-dw-hauksness/
- Mike's RPG Center Hauksness map:
  https://mikesrpgcenter.com/dw1/maps/hauksness.html

The guide sources agree on these gameplay facts:

- Hauksness has no surviving townspeople or usable services.
- Ordinary encounters use the dangerous Cantlin-area monster set: Werewolf,
  Starwyvern, Green Dragon, and Wizard.
- A fixed Axe Knight encounter guards a lone tree behind the ruined eastern
  shop and can cast `SLEEP`.
- After winning, the player must `SEARCH` the same tree tile without moving to
  obtain Erdrick's Armor.
- The Axe Knight is reported as repeatable at that fixed location.

The GameFAQs route description and the 20-by-20 Mike's map combine into this
coordinate hypothesis:

1. From entrance `(0,10)`, travel south and then east to the southeast shop
   area.
2. Reach the walkable tile west of the shop counter, likely `(16,15)`.
3. Move two west to `(14,15)`.
4. Move three north to `(14,12)`.
5. Move four east through the swamp to the guarded tree at `(18,12)`.

Every coordinate after the verified entrance is a survey target, not permanent
map truth, until normal live movement confirms it.

## Outside Accessibility Mod Cross-Check

Read-only reference:

`C:\tmp\DragonWarriorAccess\analysis_extract\DragonWarriorAccess\Data\662904817335100.lua`

Its map-`0x03` snapshot proposes:

- dimensions `20 x 20`;
- west exit `(0,10)`, returning to World Map `(25,89)`;
- one hidden event at `(18,12)`;
- no NPC/service navigation.

The exit agrees with this project's live evidence. The proposed event tile
also agrees with the independently labeled Mike's RPG Center image. This makes
`(18,12)` a strong target for live inspection, fixed-battle confirmation, and
post-battle `SEARCH`, but it must not be copied directly into source map data.

## First Decode Priorities

1. Reload or launch FCEUX and establish a fresh Hauksness `(0,10)` baseline
   with no runtime blocks.
2. Record the decoded tile and neighbor state at the entrance before starting
   a normal-movement survey.
3. Survey the entrance component and route toward the southeast shop area.
4. Treat random battles as interruptions; do not convert combat stops into
   blockers.
5. Verify the proposed approach points `(16,15)`, `(14,15)`, and `(14,12)`
   using normal arrival plus same-origin probes where needed.
6. At `(18,12)`, separately capture:
   - pre-battle position and tile;
   - fixed Axe Knight trigger;
   - post-battle position without movement;
   - `SEARCH` result and resulting armor/quest state.
7. Add permanent passability, directional, and object/search data only after
   the live evidence is clean and regression tests cover map `0x03`.

## Accessibility And Spoiler Note

The guarded tree and ruined shop are useful nonvisual landmarks. When the
search event is eventually exposed through object navigation, prefer a
progressive label such as `Guarded Tree Behind Ruined Shop` over announcing
`Erdrick's Armor` before the player has defeated the Axe Knight or found the
item. Exact guidance can remain an optional later disclosure.
