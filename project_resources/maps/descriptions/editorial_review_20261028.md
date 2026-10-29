# Map description editorial closeout - 2026-10-28

The player accepted Tantegel main floor (0x04), Tantegel Throne Room (0x05),
and Brecconary (0x08) as useful general descriptions without information overload.
Those three paragraphs are unchanged in this follow-up pass.

All other 25 paragraphs were checked against their indexed NES reference images
and revised. Each is 71-80 words. The revisions favor a few concrete, distinctive
visual features over repeated general remarks about maze complexity. There are
no new route instructions, object coordinates, quest solutions, or invented
sensory details. Reference labels, opened secrets, floor-connection annotations,
monster panels, and guide-only backgrounds were excluded.

## Review coverage

Image paths and provenance are in [the source index](README.md). Garin's Grave
B2-B4 were reviewed as separate labeled panels in the existing composite.
Charlock guide Levels 1-8 were matched to the established RAM IDs, including the
final lair at 0x06. This is editorial/image review, not a live map traversal.

| RAM ID | Map | Visual review and spoiler handling |
|---|---|---|
| 0x02 | Charlock Castle | Symmetrical halls, striped enclosures, gold throne pattern; omit revealed passages. |
| 0x03 | Ruins of Hauksness | Broken room outlines, isolated brick patches, sand and greenery; omit encounter and discovery marker. |
| 0x06 | Dragonlord's Lair | Water surrounding an irregular complex, long western gallery and sandy eastern banks; omit story and contents. |
| 0x07 | Kol | Sandy central clearing, dense tree rows, scattered rooms and blue bathing pool; omit hidden discovery. |
| 0x09 | Garinham | Broad tiled northern roof and smaller southern buildings; omit secret routes and guide inset contents. |
| 0x0A | Cantlin | Central pool, green patches, dense town blocks and striped southern enclosure. |
| 0x0B | Rimuldar | Irregular channels, arched bridges, separate building clusters and tree rows. |
| 0x0C | Sun Shrine | Small cellar, central enclosure and plain masonry; omit treasure contents. |
| 0x0D | Rain Shrine | Outer square passage enclosing a smaller room with projecting walls; omit quest exchanges. |
| 0x0E | Magic Temple | Paired stone projections and near symmetry around central enclosure; omit quest outcomes. |
| 0x0F | Dragonlord B1 | Large square maze, outer passages and heavy central block; omit stair labels and connections. |
| 0x10 | Dragonlord B2 | Small lattice of short strips, crooked connections and little interior blocks; omit treasure markers. |
| 0x11 | Dragonlord B3 | Long lower strip around a jagged central enclosure; omit stair labels. |
| 0x12 | Dragonlord B4 | Strong upper/right outline with stepped inner partitions and lower hook; omit stair labels. |
| 0x13 | Dragonlord B5 | Parallel U-shaped lanes around a tighter central pocket; omit stair labels. |
| 0x14 | Dragonlord B6 | Broad chamber and separate upper strip; exclude cyan guide separator from artwork description. |
| 0x15 | Swamp Cave | Elongated cave and ladder-like crosspieces; omit inhabitants and encounter markers. |
| 0x16 | Mountain Cave | Long horizontal bands with tighter bends below; omit chests and stair labels. |
| 0x17 | Mountain Cave B2 | Uneven chamber sizes, isolated blocks and short recesses; omit treasure contents. |
| 0x18 | Garin's Grave B1 | Large square labyrinth of loops, parallel lanes and crossways; omit chest row details. |
| 0x19 | Garin's Grave B2 | Nested rectangular outlines and compact inner partitions; omit stair connections. |
| 0x1A | Garin's Grave B3 | Outer lane enclosing staggered walls and tightly packed pockets; omit guide treasure labels. |
| 0x1B | Garin's Grave B4 | Small stepped diamond surrounded by broad masonry; omit stair label. |
| 0x1C | Erdrick's Cave B1 | Upper masonry band and shorter lower turns; omit route labels. |
| 0x1D | Erdrick's Cave B2 | Asymmetrical passages around a broad central mass; omit treasure contents. |

## Verification and remaining acceptance

`lua test_map_descriptions.lua` passed all three test groups: all 28 map bindings
and paragraph bounds, physical-light policy in all navigation modes, and safe
unavailable responses. `luac -p map_descriptions.lua` passed. A before/after
comparison confirmed exactly 25 changed entries and the three accepted
paragraphs unchanged. All 28 source-index entries resolve to local images.

Runtime interfaces and behavior are unchanged. The earlier native Windows gate
passed 44 Lua suites and 82 Python tests for the feature integration. This
follow-up changes wording and documentation only; no full gate rerun was needed.

Editorial work is complete for all 28 interiors. The remaining 25 paragraphs
are ready for ordinary play; player listening acceptance is still limited to
the three reported maps. Dungeon light gating, speech interruption, and continued
auto-walk still await specific player feedback. No emulator state or qualified
release output was changed. Source changes appear after the next Lua reload.
