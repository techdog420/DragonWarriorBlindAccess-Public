# Handoff 2026-04-26 - Object finder reachability messaging

## Change

The object finder now appends a short reachability warning when the selected
interior-map object has no current route:

```text
Chest: 3 north (1 of 5). Not currently reachable
```

Reachable object announcements are unchanged.

## Implementation

- `route_manager.lua`
  - Added `object_reachability(obj, opts)`.
  - Added `describe_object_with_reachability(obj, base_description, opts)`.
  - Added `describe_current_object(opts)`.
  - The preview uses quiet lower-level route checks instead of the chatty
    `pathfind_to_adjacent` wrapper.
  - It does not freeze NPCs and does not queue movement.
  - It skips overworld A* and leaves overworld object descriptions as distance
    and bearing only.
  - It mirrors existing route mode rules: NPCs/doors use adjacent routing;
    chests try direct routing and then adjacent fallback.

- `hotkeys.lua`
  - `next_object`, `prev_object`, `current_object`, and filter announcements now
    speak `route_mgr.describe_current_object()`.

- `main.lua`
  - Remote debug commands `next_object`, `prev_object`, `current_object`, and
    `next_filter` now log and speak the reachability-aware description.

- `test_route_manager.lua`
  - Added regression coverage for:
    - unreachable selected object appends the warning
    - reachable selected object stays concise
    - chest adjacent fallback counts as reachable
    - preview does not freeze NPCs or queue movement

## Validation

```text
luac -p route_manager.lua hotkeys.lua main.lua test_route_manager.lua
lua test_route_manager.lua        # 16/16 pass
lua test_map_survey.lua           # 37/37 pass
lua test_objects.lua              # 6/6 pass
```

## Next use

Before moving into the town survey cleanup, reload the Lua script in FCEUX so
object browsing picks up the new message. This should make stale town blocker
data less confusing while cycling through objects.
