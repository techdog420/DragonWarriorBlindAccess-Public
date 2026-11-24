# Emulator Bakeoff Saves

The public repository does not distribute game saves. The historical raw
battery-save baseline remains in the private development archive.

For a same-save emulator comparison, make a normal in-game save with the king,
close the emulator, and use your own raw battery save for both emulator paths.
Use battery data, not FCEUX or BizHawk emulator savestates. Keep a backup before
testing; save files are ignored by Git.

Example, replacing the path with your own save:

    ./launch_dw.sh --battery-save path/to/your-own-save.sav
    ./launch_dw.sh --emulator bizhawk --battery-save path/to/your-own-save.sav
