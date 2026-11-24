# Garinham Map Reference

> Public archive note: reference image filenames below document the research
> sources. The images are retained in the private development archive and are
> not included in this public checkout. Source links and authored descriptions
> remain available; these images are not required to run or test the mod.

Fetched: 2026-05-14

Primary local image source: Realm of Darkness, Dragon Warrior Garinham NES
Page: https://www.realmofdarkness.net/dq/nes-dw-garinham/
Image: https://www.realmofdarkness.net/dq/wp-content/img/nes/dw/maps/garinham-3.png

Cross-check sources:

- Mike's RPG Center Garinham map page: https://mikesrpgcenter.com/dw1/maps/garinham.html
- Gamer Corner Garinham location page: https://guides.gamercorner.net/dw/locations/garinham
- Gamer Corner To Garinham walkthrough: https://guides.gamercorner.net/dw/walkthrough/to-garinham
- StrategyWiki Northwest Alefgard: https://strategywiki.org/wiki/Dragon_Warrior/Northwest_Alefgard
- StrategyWiki Unlocking Secrets: https://strategywiki.org/wiki/Dragon_Warrior/Unlocking_Secrets

Local image:

- `realmofdarkness_garinham.png`
- PNG, 709x476 pixels

Live entry confirmation:

- `POSITION: map=0x09(Garinham) x=0 y=14`
- The player-facing Travel object should not use the old `(15,14)` corridor.
  Use exit target `(0,14)` with interaction stand `(1,14)` facing west.
  Live checks after the correction reported `Exit to World Map: 1 west, exit
  here` from `(1,14)`.

Live service confirmation:

- `Merchant 2` opened the item/tool shop menu: Herb 24 G, Torch 8 G, and
  Dragon's Scale 20 G. The object browser should label him as `Tool Merchant`.
- `Merchant 4` opened the weapon/armor shop menu from public stand `(10,16)`
  facing south, with the target object at `(10,18)`. The menu listed Club 60 G,
  Copper Sword 180 G, Hand Axe 560 G, Leather Armor 70 G, Chain Mail 300 G,
  Half Plate 1000 G, and Large Shield 800 G. The object browser should label
  him as `Weapons Merchant`.
- A later autowalk from Merchant 2 toward the entrance/exit stalled at
  `POSITION: map=0x09(Garinham) x=3 y=11`, repeatedly testing `(3,12)` and
  `(4,11)`. After reload, `RUNTIME_BLOCKS map=0x09 none` and `PATH_STATE
  target=nil`. Follow-up manual movement confirmed `(3,11)` is open north/west
  and engine-blocked south/east. The running map model now closes
  `(3,12).north` and `(4,11).west` directionally while keeping up/left from
  `(3,11)` passable.
- Retrying the exit route wandered around the same building pocket. Direct
  verifiers confirmed `(2,12)->RIGHT`, `(3,10)->RIGHT`, and `(3,10)->UP` all
  blocked 5/5 with `reason=raw_hold_timeout`; these are modeled as
  `(3,12).west`, `(4,10).west`, and `(3,9).south`.
- The next exit-route attempt reached `(2,10)`. `(3,10)->LEFT` into `(2,10)`
  was noisy but crossed during seam retry, so it remains open. Direct
  verifiers confirmed `(2,10)->UP` and `(2,10)->LEFT` each blocked 5/5; these
  are modeled as `(2,9).south` and `(1,10).east`.
- Follow-up manual and live checks preserved `(2,10)<->(3,10)` as a noisy but
  passable seam. The next route loop around `(2,11)` / `(2,12)` verified
  `(2,11)->LEFT` and `(2,12)->LEFT` blocked 5/5; these are modeled as
  `(1,11).east` and `(1,12).east`.
- After those blockers were modeled, the planner rejected the only south exit
  because `(2,13)` decoded as type-2/non-walkable. Live verification overrode
  that static read: `probe_edge_verify:2,12,DOWN,5` moved into `(2,13)` on all
  five attempts. `(2,13)` is now a scoped Garinham passthrough cell, and a
  fresh live `debug_pathfind_to:15,14` from `(2,13)` returns `1 south, 13
  east`.
- Entrance-to-Tool-Merchant follow-up: the return route to entrance completed
  after one reroute, but the route back toward Merchant 2 bounced along the
  x=7 lane. Clean verifiers confirmed `(7,10)->LEFT`, `(7,11)->LEFT`, and
  `(7,12)->LEFT` each blocked 5/5; these are modeled as `(6,10).east`,
  `(6,11).east`, and `(6,12).east`. After reload, the planner from `(15,14)`
  to Merchant 2's adjacent stand chooses `1 north, 9 west, 3 north, 2 west`,
  facing west from `(4,10)`. The replacement route's south/top entry through
  the x=6 column was raw-verified passable 5/5 on `(7,13)->LEFT`,
  `(6,13)->UP`, `(6,12)->UP`, `(6,11)->UP`, `(6,10)->LEFT`, and
  `(5,10)->LEFT`.
- Drift follow-up: the remaining reroutes on the successful entrance/exit
  routes were one-tile previous-direction overshoots during route-turn settle,
  not new geometry. No map blockers were promoted from those drift events.
  `auto_step.lua` has a timing guard for queued early-twitch movement before a
  route turn. User retest after the manual-tap timing change says both Tool
  Merchant routes are usable, with one drift reroute each. Defer remaining
  drift to polishing unless it starts causing real route failures.
- Locked-door correction: the old public east-end town-door guess at `(19,16)`
  was disproved after Magic Key access. Selected-object teleport landed at
  `(19,17)` facing north, and OPEN reported `There is no door here.` The
  `(19,16)` override has been removed from `map_reader.lua` and `objects.lua`.
  Follow-up manual OPEN work from the confirmed grave stairs back toward town
  placed the grey-building grave-route door at door cell `(17,10)`, opened
  from stand `(17,9)` while facing south and exposed as `Grave Route Door`.
  Fresh `report_door_state` then recorded `DOOR_STATE keys=5 slots=0=(17,10)`;
  the earlier `(18,9)` estimate is not a door override. The Garinham B1 locked
  door remains dungeon scope.
- Garin's Grave route investigation: guide clues and the local map image point
  to the grey-building "wall of darkness" path. Live verification proved the
  dark-wall entry `(3,4)->UP` into `(3,3)` moves 6/6 even though the ROM tile
  decodes as wall, so `(3,3)` is now a Garinham passthrough. The top hidden
  route is reachable after modeling route-shaped false entries. Old Man 3 at
  `(14,1)` appears in the NPC list but is not treated as an NPC blocker.
  Door-to-grave trail-blazing later proved the west approach into that cell is
  a real engine seam: `(13,1)->RIGHT` into `(14,1)` blocked 5/5 with no NPC at
  the destination. A later route from `(4,11)` reached `(18,1)`.
  Direct edge probing then proved `(18,1)->UP` moves into the standable
  top-edge cell `(18,0)`, but `(18,0)->UP` changes to `0x01` / World Map and
  lands near the town on the overworld. `(18,0)` is now a Garinham passthrough
  cell, not the grave trigger. The actual town-side grave trigger is the
  top-right boundary stair tile `(19,0)`: ROM stair-down table entry `09 13 00`
  at file offset `0xF411` points there, and live STAIRS from `(19,0)` produced
  `EVENT: map change -> 0x18 (Garin's Grave B1)`. User manual follow-up
  confirmed the Grave B1 arrival/return tile is `(6,11)`, and using the return stairs
  comes back to Garinham `(19,0)`. `objects.lua` exposes this as
  `Stairs to Garin's Grave`, and `MAP_PASSTHROUGH_CELLS[0x09]` keeps `(19,0)`
  walkable despite the generic top-edge boundary rule.
- Door-to-grave trail bridge: once `(14,1).west` was blocked at runtime, route
  frontier found a lower bridge from `(19,11)->UP` into `(19,10)`. Direct
  verifier evidence moved 6/6 including stability recheck, so `(19,10)` is a
  Garinham passthrough. The other hidden-bridge candidate `(13,1)->DOWN` into
  `(13,2)` blocked 5/5 and remains closed by the normal tile model. A
  pre-reload autowalk then reached `(19,11)` and failed the upward turn because
  stale movement bytes were still armed; the executor-side fix is in
  `auto_step.lua`, not the Garinham map data.
- Reverse grave-stairs-to-door run: after reload, autowalk from Garinham
  `(19,0)` toward `Grave Route Door` did not find a new door. It drifted out
  to `0x01` / World Map from the upper-right edge after moving into `(19,1)`.
  Clean direct verifiers confirmed `(15,1)->LEFT` into `(14,1)` and
  `(15..18,1)->DOWN` into row 2 block 5/5. `(19,1)->DOWN` was mixed
  (`moved=2 blocked=3`), so `(19,2).north` stays unmodeled for now.
- Grave-route blocker evidence: post-reload direct verifiers confirmed
  `(15,11)->UP` into `(15,10)` blocked 5/5 and `(16,11)->UP` into `(16,10)`
  blocked 5/5, while `(14,10)->RIGHT` into `(15,10)` moved 6/6 and
  `(4,13)->UP` moved 6/6. Model only the two south approaches as directional
  blockers.
- Current town status: public services and the Grave of Garinham entrance are
  clean enough to move on. Revisit next for locked chests, Garin's Grave B1
  itself, and remaining hidden/dialogue-only NPCs.

Page legend / service transcription:

- 1: Item shop
  - Herb, 24 G
  - Torch, 8 G
  - Dragon's Scale, 20 G
- 2: Weapon/armor shop
  - Club, 60 G
  - Copper Sword, 180 G
  - Hand Axe / Iron Axe, 560 G
  - Leather Armor, 70 G
  - Chain Mail, 300 G
  - Half Plate, 1000 G
  - Large Shield / Iron Shield, 800 G
- 3: Inn, 25 G
- 4: Locked-building chests
  - 10-17 G, Torch, Herb
- 5: To/from Garin's Grave

Guide orientation:

- Early public priorities are the exit, inn, item shop, and weapon/armor shop.
- The large grey/north building is Magic-Key/later content.
- Realm of Darkness says the entrance to the Grave of Garinham is inside the
  grey building, at the northwest corner of the back wall.
- StrategyWiki says not to waste a Magic Key on the door inside the grey
  building just to reach the two guards; they do not provide important progress.
- StrategyWiki also describes the "wall of darkness" clue: pushing through the
  dark wall in the grey building eventually reveals the hidden path behind the
  building, leading toward the grave entrance.
- Gamer Corner lists Garinham as having 3 locked doors overall: east end of
  town, inside the locked building, and one in Garinham B1. Treat B1 as dungeon
  scope, not town-service scope.
- Gamer Corner says early Garinham gives two Princess Gwaelin clues: she is in
  a cave, and she was taken eastward.
- Garin's Grave and the Silver Harp are later progression. StrategyWiki
  recommends waiting until Magic Keys, stronger gear, and ideally Outside
  before tackling the grave.

Use this as a visual orientation reference only. Live movement probes and
`map_reader.lua` remain the source of truth for passability, hidden seams,
locked doors, and service interaction tiles.
