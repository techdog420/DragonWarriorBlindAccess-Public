# Hauksness Map And Decode Reference

> Public archive note: reference image filenames below document the research
> sources. The images are retained in the private development archive and are
> not included in this public checkout. Source links and authored descriptions
> remain available; these images are not required to run or test the mod.

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
- Live blocker-hunt reached the objective through normal movement plus
  same-origin probes. Nineteen runtime-only blocker cells remain to be promoted
  into focused map data and tests.
- A same-origin RIGHT probe from `(17,12)` moved onto `(18,12)` and triggered
  `An Axe Knight draws near!`; the apparent autowalk block was the scripted
  encounter transition, not permanent geometry or an NPC RAM object.
- After victory, the hero remained at `(18,12)`. `SEARCH` announced
  `Bill discovers the Erdrick's Armor.` Equipment byte `$00BE` changed from
  `DB` to `DF`, defense changed from `0x4D` to `0x51`, and the armor was
  automatically equipped. Quest flags remained `0x42`.
- The live tile remains decoded as town tile type `8` before and after the
  event. The visual references show it as a lone green tree behind the eastern
  ruins, with no visible Axe Knight sprite; battle victory and armor discovery
  do not replace the terrain tile.

## External Image References

A local copy, `mikesrpgcenter_hauksness.png`, was added for artwork descriptions
on 2026-10-28. Other images below remain reference links. See
`../descriptions/README.md` for the download source and hash.

- Mike's RPG Center
  - Source page: https://mikesrpgcenter.com/dw1/maps/hauksness.html
  - Source image: https://mikesrpgcenter.com/dw1/maps/hauksness.png
  - The image is a direct 20-by-20 tile map. Its numbered point `1` is on tile
    `(18,12)` and is identified by the source page as Erdrick's Armor guarded
    by an Axe Knight.
- Realm of Darkness
  - Source page:
    https://www.realmofdarkness.net/dq/nes-dw-hauksness/
  - Source image:
    https://www.realmofdarkness.net/dq/wp-content/img/nes/dw/maps/hauksness-3.png
  - Includes the town map plus labels for Erdrick's Armor, the Axe Knight, and
    the town encounter set.
- VGMaps
  - Source page: https://vgmaps.de/maps/view?m=1945
  - Source image:
    https://vgmaps.com/Atlas/NES/DragonWarrior-Hauksness.png
  - Retain only as a source cross-check, not as independent map evidence.
- Classic Games Paradise
  - Source page:
    https://www.classicgamesparadise.com/nes/Dragon%20Warrior%20Maps.html
  - Source image:
    https://www.classicgamesparadise.com/nes/Dragon%20Warrior/map%20Dragon_Warrior_hauksness.png
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

This guide route was orientation rather than map truth. Live blocker-hunt
confirmed the objective but required a substantially different route around
engine-hidden ruined walls. The verified blocker batch remains runtime-only
until source and regression work is complete.

## Outside Accessibility Mod Cross-Check

Read-only reference:

`C:\tmp\DragonWarriorAccess\analysis_extract\DragonWarriorAccess\Data\662904817335100.lua`

Its map-`0x03` snapshot proposes:

- dimensions `20 x 20`;
- west exit `(0,10)`, returning to World Map `(25,89)`;
- one hidden event at `(18,12)`;
- no NPC/service navigation.

The exit agrees with this project's live evidence. Live FCEUX evidence now
independently confirms `(18,12)` as the fixed-battle and hidden-search tile.
The outside snapshot remains reference-only and must not be copied directly
into source map data.

## First Decode Priorities

1. Promote the clean same-origin blocker batch into map `0x03` directional
   data with focused regression assertions.
2. Expose `Axe Knight Approach` under All and Travel only, using `(18,12)`
   only as the internal subject and routing to the safe preparation tile
   `(17,12)` facing east.
3. Keep the buried armor entirely out of player-facing object browsing,
   Treasure filtering, route speech, and SEARCH guidance.
4. Ensure autowalk does not convert the scripted `(17,12)->RIGHT` encounter
   transition into a permanent blocker, then validate the source-only route
   from `(0,10)` to the safe approach and back out.

## Accessibility And Spoiler Note

The fixed Axe Knight is useful as a nonvisual maze landmark even though the
game draws no enemy sprite on the tile. Expose only the persistent
`Axe Knight Approach` landmark under All and Travel only, and stop at
`(17,12)` facing east. The buried armor remains an intentional secret: do not
add its tile under Treasure, name the reward, suggest SEARCH, or automate the
final encounter step.
