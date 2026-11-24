# Map artwork descriptions

> Public archive note: reference image filenames below document the research
> sources. The images are retained in the private development archive and are
> not included in this public checkout. Source links and authored descriptions
> remain available; these images are not required to run or test the mod.

Added 2026-10-28. All 28 interior maps have authored descriptions in
`map_descriptions.lua`. World Map is outside this feature's scope.

Shift+D (configurable `key_map_description`) and `describe_map` read the same
paragraph and log `MAP_DESCRIPTION map=... result=...`. Field play is required.
Dark dungeon terrain requires a physical visible half-span greater than zero,
even with unrestricted navigation. A lit dungeon receives a whole-floor artistic
overview; Shift+N remains the local report bounded by actual illumination.
Speech queues normally, leaves routes and objects unchanged, and may be
interrupted by gameplay. Settings and Key Reference retain keyboard capture.

## Editorial rules

Usually 60-100 words, shorter for a simple room. Describe NES colors, materials,
architecture, greenery, water, and broad shapes. Avoid directions to objectives,
hidden passages, treasure contents, solutions, story outcomes, and claims about
current NPC or chest state. Do not invent sounds, smells, or lore. Guide labels,
arrows, monster illustrations, legends, and opened-secret overlays are not game
artwork. Broad floor shapes are artistic orientation, not proof of passability.
The paragraphs are static; they do not change after victory or item collection.
The wording is source-reviewed. The player accepted the style and length in
Tantegel Throne Room, Tantegel main floor, and Brecconary on 2026-10-28.
The remaining 25 paragraphs were then refined against the reference images,
keeping each at 71-80 words and leaving those three accepted entries unchanged.
Authoring and editorial review are complete for all 28 interior maps; see the
[editorial closeout](editorial_review_20261028.md) for per-map review coverage
and focused verification. Player listening acceptance remains separate.

## Map-to-image index

Paths below are relative to `project_resources/maps`. Existing folder READMEs
retain their original provenance. Composite floor labels identify individual
floors, not additional independent evidence.

| RAM ID | Map | Image |
|---|---|---|
| 0x02 | Charlock Castle | `charlock/external/mikesrpgcenter_charlock_level_1.png` |
| 0x03 | Ruins of Hauksness | `hauksness/mikesrpgcenter_hauksness.png` |
| 0x04 | Tantegel Castle | `tantegel/mikesrpgcenter_main_floor.png` |
| 0x05 | Tantegel Castle Throne Room | `tantegel/mikesrpgcenter_throne_room.png` |
| 0x06 | Dragonlord's Lair | `charlock/external/mikesrpgcenter_charlock_level_8.png` |
| 0x07 | Kol | `kol/external/mikesrpgcenter_kol.png` |
| 0x08 | Brecconary | `brecconary/mikesrpgcenter_brecconary.png` |
| 0x09 | Garinham | `garinham/realmofdarkness_garinham.png` |
| 0x0A | Cantlin | `cantlin/external/mikesrpgcenter_cantlin.png` |
| 0x0B | Rimuldar | `rimuldar/external/mikesrpgcenter_rimuldar.png` |
| 0x0C | Sun Shrine | `tantegel/mikesrpgcenter_sun_shrine.png` |
| 0x0D | Rain Shrine | `rain_shrine/realmofdarkness_northern_shrine.gif` |
| 0x0E | Magic Temple | `magic_temple/realmofdarkness_southern_shrine.gif` |
| 0x0F | Dragonlord B1 | `charlock/external/mikesrpgcenter_charlock_level_2.png` |
| 0x10 | Dragonlord B2 | `charlock/external/mikesrpgcenter_charlock_level_3.png` |
| 0x11 | Dragonlord B3 | `charlock/external/mikesrpgcenter_charlock_level_4.png` |
| 0x12 | Dragonlord B4 | `charlock/external/mikesrpgcenter_charlock_level_5.png` |
| 0x13 | Dragonlord B5 | `charlock/external/mikesrpgcenter_charlock_level_6.png` |
| 0x14 | Dragonlord B6 | `charlock/external/mikesrpgcenter_charlock_level_7.png` |
| 0x15 | Swamp Cave | `swamp_cave/mikesrpgcenter_swamp_cave.png` |
| 0x16 | Mountain Cave | `mountain_cave/mikesrpgcenter_b1.png` |
| 0x17 | Mountain Cave B2 | `mountain_cave/mikesrpgcenter_b2.png` |
| 0x18 | Garin's Grave B1 | `garins_grave/mikes_garins_grave_b1.png` |
| 0x19 | Garin's Grave B2 | `garins_grave/realm_grave_garinham.png` |
| 0x1A | Garin's Grave B3 | `garins_grave/realm_grave_garinham.png` |
| 0x1B | Garin's Grave B4 | `garins_grave/realm_grave_garinham.png` |
| 0x1C | Erdrick's Cave B1 | `erdricks_cave/mikesrpgcenter_b1.png` |
| 0x1D | Erdrick's Cave B2 | `erdricks_cave/mikesrpgcenter_b2.png` |

## New reference downloads

Fetched and decoded successfully on 2026-10-28. These are development references,
not runtime assets, and are excluded from the player package. Authored prose is
bundled instead. Source images retain their annotations and are not edited.

Mike's index: https://www.mikesrpgcenter.com/dw1/index.html
Rain Shrine page: https://www.realmofdarkness.net/dq/nes-dw-northern-shrine/
Magic Temple page: https://www.realmofdarkness.net/dq/nes-dw-southern-shrine/

Tantegel image numbering differs from RAM order: `tantegel_1` is the throne
room, `tantegel_2` the main floor, and `tantegel_3` Sun Shrine. Charlock guide
Levels 1-8 mean ground floor, B1-B6, then the final lair. These mappings were
checked against the images and existing project map names and floor notes.

| Local image | Direct source | SHA-256 |
|---|---|---|
| `tantegel/mikesrpgcenter_throne_room.png` | https://www.mikesrpgcenter.com/dw1/maps/tantegel_1.png | `0ed04137532c8b331d21b97bbe20b36bc7d645720605ba5a0d8c3b1004f0d6bc` |
| `tantegel/mikesrpgcenter_main_floor.png` | https://www.mikesrpgcenter.com/dw1/maps/tantegel_2.png | `37a76c9ab33c40fd9255ff79bb6214375f42b28f5750ff70d81064a73e8d4921` |
| `tantegel/mikesrpgcenter_sun_shrine.png` | https://www.mikesrpgcenter.com/dw1/maps/tantegel_3.png | `b14a7f774cf5360b3145b90bd6de2caf04a0d2f59b32299e5fc990cdf43625f2` |
| `hauksness/mikesrpgcenter_hauksness.png` | https://www.mikesrpgcenter.com/dw1/maps/hauksness.png | `68aab3bc915232a4c38344a4978be305ac51862d9be2a2349c3c55fc3ca9c869` |
| `rain_shrine/realmofdarkness_northern_shrine.gif` | https://www.realmofdarkness.net/dq/wp-content/img/nes/dw/maps/northern-shrine.gif | `683c9aae9b61e37057ae6cb1dfbaf7fa100230f867e9dbe1fdb42220b8c0cc2c` |
| `magic_temple/realmofdarkness_southern_shrine.gif` | https://www.realmofdarkness.net/dq/wp-content/img/nes/dw/maps/southern-shrine.gif | `c7c30482837cf733d3c20d92f59080c07dd9ceb3bec124d1e6735a873f3457ac` |
| `swamp_cave/mikesrpgcenter_swamp_cave.png` | https://www.mikesrpgcenter.com/dw1/maps/swamp_cave.png | `66f7472c8e6487a64976d0247fe4f1887ed478c1e5914915be8adaacc5b2d232` |
| `mountain_cave/mikesrpgcenter_b1.png` | https://www.mikesrpgcenter.com/dw1/maps/mountain_cave_b1.png | `bf51778d5e56abca393165775c2056a4578cf9fdb3427ebb99930b7177e74957` |
| `mountain_cave/mikesrpgcenter_b2.png` | https://www.mikesrpgcenter.com/dw1/maps/mountain_cave_b2.png | `fdd51c180005492ea3c07d8e6f839cadbefbfbce10328f2b54b452fe69f5b700` |
| `erdricks_cave/mikesrpgcenter_b1.png` | https://www.mikesrpgcenter.com/dw1/maps/erdricks_cave_b1.png | `f0e5c026696f391ca4d45fa78253b375d1587e59da257bc1263827d78224fb14` |
| `erdricks_cave/mikesrpgcenter_b2.png` | https://www.mikesrpgcenter.com/dw1/maps/erdricks_cave_b2.png | `75d3d27f4ed41140061e63338aead260b78e412163788c108b963a03217cb4fe` |

## Verification (2026-10-28)

Native Windows `python -u run_tests.py` passed: 44 host Lua suites, 82 Python
unit tests (including package fixture builds/dependency coverage), syntax checks,
speech dependency, and command queue checks. The live-only screen and speech
scripts remain excluded by the gate. Focused coverage checks all 28 IDs,
light loss/restoration in every navigation mode, overworld/unknown/non-field
fallbacks, remapping, held-key behavior, queued speech, route preservation,
Key Reference, allowlists, and documentation bindings.

Initial Linux/WSL gate attempts passed Lua but could not correctly run Windows
fixture paths; a sandboxed attempt also hit WSL socket restrictions. The native
Windows pass is the final host result. The implementation session did not reload
the emulator; the qualified package outputs were not rebuilt or replaced.

The player subsequently examined Tantegel Throne Room (0x05), Tantegel main
floor (0x04), and Brecconary (0x08), accepting them as good general descriptions
without information overload. This is listening/content acceptance for those
three maps, not acceptance of all maps or every interaction case.

On 2026-10-29 the player reported further successful spot checks across multiple
floors of Garin's Grave and Charlock and additional towns. Exact floors and town
names were not supplied. Representative listening/content acceptance is now
complete. The physical-light, speech-interruption, and continued-auto-walk cases
were not individually reported; their automated coverage remains separate.
Further editorial polishing or a full map tour is not a standing assignment.

The player authorized committing/pushing the feature and rebuilding the package.
The tester's alternate-hardware check is pending; official release remains conditional on that result. This report does not
claim an alternate-hardware pass or a published release.

The debug equivalent of Shift+D is
`./dw_commands.sh --replace --require-live 5 --wait "MAP_DESCRIPTION" describe_map`.
Target the commands at the runtime's own app directory.

## Candidate package (2026-10-29)

The feature is committed in `90e50d0` and included in the local
`2026.10.29-qualification1` player archive. Player/source repeat builds match,
archive audits and clean install/validation checks pass, and older candidates
are preserved. the tester's alternate-hardware check and official publication remain
pending. Artifact hashes and coverage are recorded in
`work_notes/packaging_qualification_20261029.json` at the repository root.
