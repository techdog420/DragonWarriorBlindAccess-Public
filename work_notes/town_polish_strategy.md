# Proposed town polishing workflow

Reviewed 2026-09-10; terrain preflight made explicit2026-09-17 after the
Brecconary/Kol corrections. Initial recommendation below predates those fixes.
Quick-services commit fb3b13b matches origin/codex/quick-services after fetch.

## Recommendation

Use target-driven audits, with a short shared-decoder sanity check before more
individual map overrides. Pilot Kol and Brecconary, then reuse the same procedure
for every town and Tantegel. Services first, then all talkable NPCs, doors/exits,
and return paths. A service passing once is not whole-town completion.

## Existing tools and their best uses

- map_reader.lua: packed-nibble ROM decoder, town walkability table, map-scoped
  passthrough/full-cell/directional overrides, door state and timing exceptions.
  Town classification comments explicitly retain empirical assumptions. This
  warrants checking for shared patterns, not assuming the whole decoder is bad.
- route_manager.lua / debug_route_frontier_skip_npcs:X,Y,LIMIT: rank rejected
  boundaries of the reachable component; hidden_bridge=true identifies modeled
  wall-looking one-cell connectors to the target side. These are hypotheses,
  not proof, and longer missing corridors may need local exploration.
- debug_pathfind_to and its skip_npcs variant: cheap separation of a model route
  failure from NPC occupancy. For counter services target the interaction stand,
  not the NPC cell; use adjacent planning for ordinary NPCs where appropriate.
- report_survey_start / survey_target / survey_objects: exercise actual routes,
  retain per-target failures, and support retry_failed and park_npcs modes.
  Surveys can be stranded by a bad approach; clustered downstream failures do
  not imply that all affected targets need separate map edits.
- verify_walked_edge:X,Y,DIR: walk to the exact origin, then use a raw held-input
  probe. probe_edge:DIR is appropriate when already at a normally reached origin.
  Revisit through normal movement to repeat evidence and check reverse travel.
- sweep_walk / crawl_map_frontier: broader discovery through normal movement.
  Default three attempts and 200 recorded edges; mobile NPCs parked, stationary
  NPCs retained; hazards, closed doors and boundary cells skipped. Reports split
  candidates, dynamic blockers, unknowns, and unsafe aborts. Useful locally when
  ranked route frontiers do not explain the missing connection.
- sweep_map / explicit-origin probe_edge_verify: teleport/reset-based forensic
  evidence. Do not use as an automatic source of permanent passability fixes.

## Practical sequence

1. Establish a known entrance anchor, fresh command probe, map ID, door state,
   NPC state, and clean known runtime overlays. Preserve the player's save state.
2. Briefly compare raw ROM layout decoding against independent local map
   references, and predicted movement against actual walked evidence in two
   towns. Inspect dimensions, nibble order, tileset choice, counter interpretation,
   and old overrides. For every remaining town, explicitly check raw0 grass
   and raw4 stone against the game's town conversion/collision table and safe
   normal-arrival movement probes before adding coordinate exceptions. Record
   which terrain table the map actually uses and its validation status. The old
   base table reversed these meanings in Brecconary/Kol, making missing routes
   and wall reroutes appear to need many isolated patches. Verify door state
   and raw9/A hazards separately; retain validated per-map exceptions. If other
   failures share a pattern, investigate the shared rule before accumulating
   coordinate exceptions. Do not remove old fixes wholesale or apply an
   unaudited town/dungeon-wide change solely from another map's evidence.
3. Inventory each target's ID, role, interaction stand/facing, and modeled route
   with and without NPCs. Services and exits first, then other talkable NPCs.
   Group failures sharing the same disconnected area or rejected edge.
4. Exercise entrance-to-service routes and their returns under ordinary NPC
   conditions. When planning fails, inspect the highest-ranked target frontier.
   When execution fails, investigate the first failed edge before another long
   reroute. Use parked-NPC runs only to isolate obstruction, not for acceptance.
5. Walk to the suspect edge, probe it, repeat from normal arrival, and check
   the reverse direction. Distinguish collision, moving NPC, closed door,
   wrong interaction stand, and auto-step timing. Use a short bounded sweep only
   if the connector cannot be located by targeted evidence.
6. Promote only reviewed evidence: directional block for one-way entry failure,
   passthrough/removal of a stale block for proven false walls, interaction
   metadata for a wrong counter stand, execution fix for timing. A failed entry
   does not prove that the whole destination tile must be blocked.
7. Run focused map/object/route regressions, reload, then verify round trips and
   actual TALK/shop access with ordinary NPCs restored. Run the full native gate
   for the completed town patch. Record unresolved NPCs explicitly.

## Best small tooling investment

Implemented on codex/town-audit: audit_town and audit_town:services use existing
object, reachability, and shared frontier helpers. One row per target:
map, target ID/name, stand/facing, route with NPCs, route without NPCs, shared
blocking frontier, live arrival, interaction result, return result, evidence tag.
Do cheap planning for all targets, but obtain detailed frontiers only for failures.
Save each snapshot separately; never carry forward stale live validation when
map data, start/door conditions, or target metadata change. Live route evidence
is recorded separately in playtesting/work notes. Avoid polling and
feeding entire debug logs into every model turn. Do not add a new route executor.

Current crawler start_impl resets report edges, candidates, stack, and probed-edge
state. It exports JSON, but does not resume traversal from that JSON. Archive
reports before subsequent runs/reloads; do not schedule repeated whole-town
sweeps expecting cumulative coverage. Durable audit results are the first
investment; full crawler resume can wait unless bounded sweeps become dominant.

## Pilot evidence

- Kol: latest Tool Merchant run planned nine steps from (19,23) to (12,21),
  encountered west-entry failures at (16,23), (10,17), and (7,14), then an NPC
  obstruction and drift. It was stopped before arrival. These remain candidates.
- Brecconary: current objects.lua maps the Tool Merchant at (25,25) to the public
  stand (23,25), facing east. PROJECT_MEMORY.md records earlier TALK proof and
  an approach through (17,22), plus an isolated alternate/debug pocket at
  (25,26). The player's new report reopens route acceptance; historical success
  does not establish that today's approach and return work.

## Cost rationale

The goal is reliable access to every intended interaction, not testing every
map edge indiscriminately. Grouping failures lets one verified connector fix
several NPC routes. Reuse existing probes, test only relevant frontiers, preserve
results across sessions, and keep emulator movement independent of model polling.
Exact runtime and model-cost savings need a pilot measurement, not a guess.

## Brecconary Tool Merchant follow-up, 2026-09-10

Normal movement from the entrance proved a four-cell missing grass strip east
of the bridge: (19..22,22), raw type0. The existing stand (23,25), facing east,
opened the shop. Return testing exposed two raw type4 wall approaches that the
model allowed: (23,23).south and (21,24).east. Both were confirmed by repeated
route failures and raw probes from normally reached origins without NPCs on
the destination. The focused fix adds those four passthrough cells and two
directional approaches; it does not change the shared tileset classification.

This strengthens the case for checking the shared town tile classifications
against independent reference maps and live controls before a long series of
coordinate patches. Raw0 grass versus boundary and raw4 wall versus floor need
context-aware investigation. Do not infer a global correction from this town.
