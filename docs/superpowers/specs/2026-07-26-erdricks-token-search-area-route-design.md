# Erdrick's Token Search-Area Route Design

Date: 2026-07-26

## Goal

Add bidirectional overworld guidance between Cantlin and a safe staging point
beside the eastern Great Swamp. The staging point helps a blind player reach
the intended search region without revealing the buried square or bypassing
Gwaelin's Love and the Search command.

The feature is intentionally named for the search area, not Erdrick's Token,
in player-facing objects and speech.

## Canonical Clue and Coordinate Model

The guide clue says the buried item is 70 tiles south and 40 tiles east of
Tantegel Castle. The mod's established World Map anchor is Tantegel
`(43,43)`, so the clue resolves to `(83,113)`.

That exact coordinate is useful as internal validation evidence. It must not
become:

- an ordinary Travel object;
- a route waypoint;
- an exact destination announcement;
- an automatic Search action; or
- a default hidden-treasure hint.

The external walkthrough and NES map are orientation sources only. They show
that the buried square is in the eastern Great Swamp and that Cantlin's
mountain enclosure requires a northern departure and western detour. Normal
FCEUX movement remains authoritative for every production waypoint.

Reference sources:

- https://guides.gamercorner.net/dw/walkthrough/erdricks-token-and-the-rainbow-drop
- https://nesmaps.com/maps/DragonWarrior/DragonWarriorOverworldMap.html

## Player Experience

The World Map Travel list gains a destination named:

`Eastern Great Swamp Search Area`

Selecting it near Cantlin starts a named route to a safe, non-damaging
perimeter tile. The provisional reference-map candidate is hill tile
`(89,112)`, seven Manhattan steps from the clue coordinate. This coordinate
is not production data until normal movement proves that it is reachable,
non-damaging, and suitable for stopping and restarting guidance.

Arrival narration should say:

`Arrived at Eastern Great Swamp Search Area. Use Gwaelin's Love and Search to continue.`

The route may warn that the surrounding swamp and monsters are dangerous. It
must not say which direction or how many steps lead to the buried square.

The player then uses the original mechanics:

1. Gwaelin's Love reports position relative to Tantegel.
2. The player applies the learned 70-south, 40-east clue.
3. The player reaches the matching square.
4. The player uses Search manually.

This preserves the original information constraint while removing inaccessible
long-distance route finding.

## Route Architecture

Add one overworld landmark in `objects.lua` after its staging coordinate is
live-confirmed:

- name: `Eastern Great Swamp Search Area`;
- type: existing Travel-compatible exit type;
- id: `overworld_eastern_great_swamp_search_area`;
- coordinate: live-confirmed safe perimeter tile.

Add two literal routes in `overworld_routes.lua`:

- `great_swamp_cantlin`: Cantlin to the search area;
- `cantlin_great_swamp`: search area back to Cantlin.

The outbound route targets
`overworld_eastern_great_swamp_search_area`. The return route targets the
existing `overworld_cantlin` object. Both use the ordinary route state machine,
waypoint observation, autowalk planning, battle interruption, recalculation,
warnings, and final-waypoint completion.

The route names follow the current destination-from-origin convention. The
reverse route is declared independently. It may begin as the reversed
live-confirmed geometry for test construction, but production metadata and
waypoints must be adjusted independently when turn order, carry, drift, or
recovery evidence differs.

No new command, route-manager mode, pathfinder algorithm, map blocker, or
cross-map automation is required.

## Route Discovery Strategy

Start on the World Map at the normal Cantlin exit landing `(73,102)` with no
route active.

The outbound investigation should:

1. confirm the existing validated north departure through `(73,91)`;
2. follow the guide's western detour and identify which part of the validated
   Cantlin-to-Hauksness forest route can be reused;
3. locate the eastern bridge and record exact approach, bridge, and departure
   coordinates through normal movement;
4. continue southeast toward the Great Swamp;
5. approach the provisional `(89,112)` candidate without entering speculative
   coordinates as permanent route data;
6. confirm the candidate's terrain, damage behavior, adjacent movement, and
   ability to resume a return route;
7. choose the nearest practical safe alternative if `(89,112)` fails any
   criterion.

Use zero-radius waypoints at narrow turns, bridge seams, shore boundaries, and
any coordinate where axis order matters. Compress only broad straight
corridors after live movement shows that route-aware carry is safe.

An autowalk timeout, drift, or blocked report is not map evidence by itself.
Reprobe the exact failed edge from the same origin before changing route data,
and require repeated evidence before considering permanent map data.

## Disclosure Boundary

Player-facing source data may disclose:

- the eastern Great Swamp as the broad search region;
- the safe perimeter pin;
- that Gwaelin's Love and Search are the intended tools;
- hazard and combat warnings.

Player-facing source data must not disclose:

- `(83,113)`;
- a waypoint on the buried square;
- directions from the staging pin to the buried square;
- a treasure object named Erdrick's Token;
- automatic Search behavior.

Tests and design documentation may use `(83,113)` to prove that the
player-facing landmark and route remain distinct from the treasure square.

## Failure Handling

- Combat pauses live movement. The user clears the field, then validation
  resumes only after a fresh position, route, path, runtime-block, and input
  baseline.
- Timing failures and route drift remain executor evidence unless a same-origin
  probe proves a terrain or directional restriction.
- A failed provisional staging coordinate is replaced with the nearest
  live-confirmed safe perimeter tile; the exact token coordinate does not
  change.
- The route is not considered validated merely because its waypoint list
  passes deterministic tests.
- The return route is not considered valid merely because the outbound list
  was reversed.

## Automated Tests

Add focused regressions covering:

- the World Map exposes exactly one Travel landmark named
  `Eastern Great Swamp Search Area`;
- the landmark uses the live-confirmed safe coordinate and never `(83,113)`;
- player-facing object descriptions do not contain `token`, `Erdrick`,
  `83`, or `113`;
- selecting the search-area object near Cantlin chooses
  `great_swamp_cantlin`;
- route aliases remain clue-preserving;
- the outbound route starts at the normal Cantlin landing and preserves every
  live-confirmed narrow turn;
- the outbound final waypoint is the safe staging pin;
- arriving at the pin announces the search-area message and stops guidance;
- selecting Cantlin at the staging pin chooses `cantlin_great_swamp`;
- the return geometry and direction-sensitive metadata match live evidence;
- the new Cantlin alternate does not steal Cantlin starts from Hauksness or
  other established origins;
- existing Cantlin/Hauksness behavior remains unchanged.

Run the focused object, overworld-route, route-manager, and autowalk tests;
byte-compile changed Lua files; run `git diff --check`; and run the complete
repository harness before requesting live validation.

## Live Validation

Validate in this order:

1. Cantlin `(73,102)` to the safe search-area pin.
2. Confirm arrival narration, route completion, and no automatic Search.
3. Manually use Gwaelin's Love while moving from the pin until the clue
   coordinate is reached.
4. Use Search manually and confirm the game awards the Token.
5. Return to the safe pin if necessary.
6. Start the ordinary Cantlin Travel destination and validate the independent
   return route to `(73,102)`.

Record map correctness separately from timing, drift, combat, and carry
behavior. Only the two route traversals and the staging coordinate are route
validation evidence; finding the Token confirms the clue coordinate but does
not validate the return route.

## Future Configurable Guidance

A later quality-of-life setting may add progressive hidden-treasure guidance,
for example:

- default: broad search-area route only;
- proximity: non-exact cues when near a clue-supported hidden item;
- exact: optional exact-square guidance.

That setting, quest-flag gating, NPC-clue tracking, and automatic exact
guidance are outside this change.

## Non-Goals

This work does not:

- expose Erdrick's Token as a default object;
- route directly to `(83,113)`;
- automate Gwaelin's Love or Search;
- add the future hidden-treasure configuration;
- modify swamp damage or encounter behavior;
- change autowalk timing or carry policy;
- add permanent blockers from reference-map interpretation;
- start an overworld route from inside Cantlin.
