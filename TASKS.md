# Task Backlog

Updated: 2026-05-14

This is a lightweight backlog for useful follow-up work that should not
interrupt the active debug loop. Keep current live state and resume steps in
`session_handoff.md`; use this file for small future chores and tooling ideas.

## Tooling

- Player-facing auto-walk stop: add a command and hotkey to cancel the active
  auto-walk route immediately, clear queued route/step state, release held
  direction input, clear route context, and speak a concise confirmation. This
  came up when an exit route boxed itself into repeated blocked-edge reroutes;
  players need a reliable "stop trying this route" escape hatch without waiting
  for reroute failure limits.

- Image parsing helper: consider adding Pillow support in a repo-local Python
  virtual environment, or commit a small built-in PNG sampler for indexed map
  images. Goal: make saved visual map references, such as
  `project_resources/maps/brecconary/mikesrpgcenter_brecconary.png`, easier to
  sample and describe without relying on external image tools. This is optional
  QoL; live movement probes remain authoritative for map passability.

## Process

- Task tracking convention: if this backlog grows, decide whether to keep
  `TASKS.md` as the simple tracker or split into focused checklists by area
  such as map decoding, pathfinding, speech/UI, and tooling.

## Map Decoding

- Brecconary Merchant 4 optional follow-up: the current evidence says the
  southeast tool-shop pocket is isolated/locked from the public waypoint graph,
  not explained by either known Brecconary door. If gameplay later suggests the
  tool shop should be reachable, add a small debug helper to test TALK from a
  chosen coordinate/facing, then re-check possible customer stands around
  `(25,27)` before changing more map data.
