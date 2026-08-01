# Licensing and Distribution Scope

The original Dragon Warrior Accessibility source code and documentation in
this repository are Copyright (c) 2026 Bill Freeman and are available under
the MIT License in `LICENSE`, except where a file or bundled component states
different terms.

The release package also contains separately licensed software:

- The modified FCEUX executable and covered source are distributed under the
  GNU General Public License. The player ZIP contains its license and source
  notice; the matching release must publish the corresponding-source ZIP as a
  sibling asset.
- Qt, SDL2, libarchive, Lua, the NVDA Controller Client, Python, and Python
  packages retain their own licenses and notices under `licenses` and in the
  generated player package.
- Qt graphics compatibility files, including ANGLE and the Mesa llvmpipe
  software renderer, are retained so the emulator can run on a wider range of
  Windows graphics configurations. Their notices are included with the
  release.

The player package does not include a Dragon Warrior ROM or other copyrighted
game data. Players must provide their own legally obtained compatible ROM.

The project does not bundle Tolk or JAWS binaries. JAWS support uses the API
installed with JAWS. NVDA support uses the redistributable NVDA Controller
Client DLL and includes its LGPL license and matching source in the
corresponding-source asset.
