# Rain Shrine / Northern Cave

> Public archive note: reference image filenames below document the research
> sources. The images are retained in the private development archive and are
> not included in this public checkout. Source links and authored descriptions
> remain available; these images are not required to run or test the mod.

Map id: `0x0D`

External orientation:

- Realm of Darkness identifies this NES location as the Northern Shrine / Rain
  shrine and notes that the wise man gives the Staff of Rain after receiving
  the Silver Harp.
- Source: https://www.realmofdarkness.net/dq/nes-dw-northern-shrine/

Current live notes:

- Live NPC/object evidence places the old man / wise man at `(4,4)`.
- The route dump for the first old-man approach showed the bottom
  entry/exit/start tile at `(4,9)`. `objects.lua` models `Exit to World Map`
  there, facing south.
- First old-man route evidence found two narrow engine walls around row 6:
  `(4,6)` and `(5,6)` both decode as walkable tile `14`, but northward entry
  from `(4,7)` and `(5,7)` repeatedly blocked. `map_reader.lua` keeps these as
  directional `south=true` blocks, not full blocked cells.
- A follow-up old-man route found the same south-approach wall farther west:
  `(3,6).south` reached 6 blocked / 0 moved and `(2,6).south` reached 4
  blocked / 0 moved, while `(3,7)` and `(2,7)` had horizontal moved evidence.
  `map_reader.lua` now models `(2,6)`, `(3,6)`, `(4,6)`, and `(5,6)` as
  directional `south=true` blocks.
- The next loop proved the west face of the hidden wall cluster. Entry eastward
  into `(2,3)` and `(2,4)` from column `x=1` repeated as blocked-only, reaching
  36/0 and 37/0 respectively, while `(2,5).west` and `(2,6).west` also had
  route-context blocked-only hits. Movement along column `x=1`, including
  `(1,3)<->(1,4)`, stayed open.
- After the script reloaded with the permanent map patch, runtime blocks were
  empty and `debug_pathfind_adjacent:4,4` from current `(4,1)` planned
  `2 south`, landing at `(4,3)` facing south.
- The direct top approach was false. Auto-walk from `(4,1)` blocked entering
  `(4,2)` from the north four times, then the reroute via `(3,1)` blocked
  entering `(3,2)` from the north three times. The manual route reached the
  old man by going east along row 1, descending on the far east side, and
  returning west along row 4. `map_reader.lua` now models `(3,2).north`,
  `(4,2).north`, `(5,2).north`, and `(6,2).north` as directional-only blocks,
  while keeping the far-east descent and row-4 return seams open.
- The first route back out from the old-man side exposed a mid-wall near
  `(6,5)`. `probe_edge_verify` confirmed `(5,5).north`, `(5,5).east`, and
  `(6,6).north` blocked 5/5 each. After live runtime injection of those edges,
  the route shifted east and `probe_edge_verify` confirmed `(7,5).west` and
  `(7,5).north` blocked 5/5 each. `map_reader.lua` models those as
  directional-only blocks; `(6,4).west/south`, `(6,5).north`, and
  `(7,4).west/east` had moved evidence and stay open.
- The next entrance-to-old-man route from `(4,9)` reached row 7 cleanly, then
  looped trying to enter `(6,6)` and `(7,6)` from the south. Raw
  `probe_edge_verify` confirmed `(6,6).south` and `(7,6).south` blocked 5/5
  each. `map_reader.lua` models those as directional-only blocks; `(6,7)`
  horizontal movement and `(7,7).west` had moved evidence and stay open.
- Final noisy-cleanup verifiers promoted `(7,6).east` and `(5,3).east`, both
  blocked 5/5. `(5,3).south` had route-block noise, but raw verification was
  mixed/passable at 3 moved / 2 blocked, so that edge stays open.
- A live route back to the exit after that cleanup completed to `(4,9)` but
  exposed three more confirmed directional walls: `(7,5).east`,
  `(7,9).north`, and `(6,9).north` all raw-verified blocked 5/5. The nearby
  `(8,9).north` route hit is intentionally not modeled because raw
  verification produced an inconclusive map-change case instead of a stable
  blocked edge.
- Follow-up playtest reported the routes to and from the old man both finished
  smoothly. The return route had one recovered reroute, which is deferred to
  polishing. The remaining chest access is progression-gated until the old man
  receives what he is waiting for.
