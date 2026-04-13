# Tantegel South Gate Handoff

Date: 2026-03-25

## Issue

On the live "second Tantical map" investigation, the south gate leading from
Tantegel Castle to the world map was missing from the object list.

Live observations:

- Player position: `(11,29)`
- Expected gate/door cells: `(10,30)` and `(11,30)`
- Live map ID from RAM/logs: `0x04`
- `dw_debug.log` showed blocked movement from `(11,29)` down into `(11,30)`

## Root Cause

There were two separate problems:

1. The castle south gate door cells were not listed in `objects.lua`, so they
   could never appear in the object list because town/castle door scanning is
   disabled for this tileset.

2. `map_reader.lua` was treating ROM metadata width/height bytes as direct tile
   counts. Live evidence showed they are inclusive max coordinates instead.
   Example: on `map 0x04`, the ROM metadata read as `29x29`, while the player
   was validly standing at `y=29`. That means the real dimensions are `30x30`.
   This off-by-one clipped the bottom row and hid south-edge map data.

## Patch Applied

### `objects.lua`

- Added `map 0x04` castle exit at `(11,29)` with destination `World Map`
- Added explicit south gate door objects at:
  - `(10,30)`
  - `(11,30)`

The old unverified `0x08` castle exit entry was left in place as an alternate
mapping note.

### `map_reader.lua`

- Changed metadata loading so ROM width/height bytes are interpreted as max
  coordinates and converted to dimensions via `+1`

## Regression Coverage

Added a focused unit test in `test_map_reader.lua` confirming that metadata
bytes `29,29` produce dimensions `30,30`.

## Verification

Local verification passed:

- `lua test_map_reader.lua`
- `python3 run_tests.py`

User also confirmed live in emulator that the missing south-gate doors now
appear where expected.

## Relevant Coordinates

- Castle exit tile: `(11,29)`
- South gate door tiles: `(10,30)`, `(11,30)`
- Map ID: `0x04`

## Files Touched

- `map_reader.lua`
- `objects.lua`
- `test_map_reader.lua`
