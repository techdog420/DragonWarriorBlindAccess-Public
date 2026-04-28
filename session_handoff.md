# Session Handoff - Active Resume

Updated: 2026-04-28

## Current Focus

The project is pivoting from broad map decoding and blocker discovery toward actual gameplay/playability work.

The first three maps are in good enough shape to shift attention to:
- Screen reader narration during normal play
- Object navigation usability
- Combat/menu/item/shop/chest/stair workflows
- Route reliability during real gameplay rather than exhaustive survey loops
- Test coverage and small professional cleanup as work proceeds

## Current Baseline

Latest committed checkpoint:
- Commit: `97e648f Stabilize pathfinding and survey tooling`
- Worktree was clean immediately after that commit.
- Plain Lua test baseline passed before commit:
  - `lua test_route_manager.lua`: 16/16
  - `lua test_map_survey.lua`: 40/40
  - Full `test_*.lua` plain run: 126 unit tests passed
  - FCEUX-only diagnostic tests skip cleanly under plain Lua
  - `luac -p *.lua` passed
  - `git diff --check` passed

Latest live validation notes:
- Script reload and polling were validated after the pathfinding/survey hardening changes.
- Live map was last observed in the Tantegel interior range, with runtime blocks clear.
- Confirm exact live map id and position with `report_position` before any state-sensitive debug work.

## Active Project Memory Files

Read these first for future Codex sessions:
- `AGENTS.md` - project rules, priorities, command model, and accessibility preferences
- `PROJECT_MEMORY.md` - durable architecture facts and long-lived lessons
- `PLAYTESTING.md` - current gameplay/playability focus and issue queue
- `session_handoff.md` - this concise active resume

Historical evidence is archived under `handoff_archive/`.
Do not treat archived handoffs as active context unless investigating an old map-data decision.

## Current Map/Pathfinding Truth

General rules:
- Require direct blocker evidence before changing permanent map data.
- Do not promote aggregate `export_blocks` output by itself; it can include old accumulated observations.
- Keep runtime/test-only blocked tiles separate from permanent map data.
- Confirm live map id before applying map-specific conclusions, especially around Tantegel map ids.

Brecconary/map `0x08`:
- Broad blocker hunting can pause.
- Latest reliable survey found no strong blocker candidates and no runtime blocks.
- Remaining failed objects are clean gated/isolated regions, not map-data evidence.
- Known permanent/pathfinder-forbidden fixes remain in `map_reader.lua`, including the Brecconary trap cells and directional seam fixes discovered during April 2026 surveys.

Tantegel/castle/interior maps:
- Repo history often refers to map `0x04` as live Tantegel Castle and map `0x05` as a throne-room/interior area.
- Confirm the live `POSITION` map id before making permanent map-data changes.
- Recent map `0x05` runtime block observations looked transient; no durable `map_reader.lua` patch was justified from them.

## Preferred Next Work

Recommended next phase:
- Start a real playthrough-oriented pass from the early-game maps.
- Record friction in `PLAYTESTING.md` instead of starting another broad decoding campaign.
- Prefer targeted fixes that improve the actual blind-player loop.

Good first gameplay checks:
- Can the player reliably understand location, facing, nearby objects, exits, and hazards?
- Can the player use stairs, doors, chests, shops, menus, and NPC interaction without visual feedback?
- Does object navigation announce reachability and failure reasons clearly?
- Does combat narration expose enough state to make decisions?
- Are pathfinding failures explained in a way that lets the player recover?

## Memory Strategy

Canonical project memory now lives in the repo.

Use this hierarchy:
- `session_handoff.md`: current state only; keep it short.
- `PROJECT_MEMORY.md`: durable architecture, command contracts, known quirks, and long-lived lessons.
- `PLAYTESTING.md`: gameplay issue queue and player-facing polish notes.
- `handoff_archive/`: historical evidence and old investigations.
- `~/.codex/memories/` and `.claude/agent-memory/`: assistant-local aids only; not source of truth.

When substantial work finishes:
- Update `session_handoff.md` with the new current state.
- Update `PROJECT_MEMORY.md` only for durable facts.
- Update `PLAYTESTING.md` for gameplay findings and priorities.
- Avoid creating new dated handoffs unless an investigation is large enough to need a detailed evidence packet.

## Codex memory access note - 2026-04-28

- Codex can write normal repo files here, but project-local `.codex/` is mounted read-only inside this session.
- Keep canonical mutable memory in `session_handoff.md`, `PROJECT_MEMORY.md`, `AGENTS.md`, and focused docs such as `debug_hooks.txt`.
- Use `/home/developer/.codex/memories/` only as assistant-local reminder storage.
- Linux/WSL remains the recommended launch environment; the `.codex` write failure is a sandbox/read-only mount detail, not a reason to move the workflow to another environment.
