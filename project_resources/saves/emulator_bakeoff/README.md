# Emulator Bakeoff Saves

This folder holds repo-owned raw battery save baselines for cross-emulator
Dragon Warrior testing. These are plain NES battery save files, not FCEUX
`.fc*` savestates or BizHawk `.State` files.

## Current Baseline

- `dw1_bakeoff_king_save_2026-05-18.sav`
  - Source: `D:\emulation\fceux\bin\sav\Dragon Warrior (USA) (Rev 1).sav`
  - Captured after a normal in-game save with the king in FCEUX.
  - Size: 8192 bytes.
  - SHA-256:
    `fdbf2150210b8761301ed75285885caf806d1c58f4cc08eb569dee148a099c4d`

Use this file with either emulator launcher:

```bash
./launch_dw.sh --battery-save project_resources/saves/emulator_bakeoff/dw1_bakeoff_king_save_2026-05-18.sav
./launch_dw.sh --emulator fceux --battery-save project_resources/saves/emulator_bakeoff/dw1_bakeoff_king_save_2026-05-18.sav
```
