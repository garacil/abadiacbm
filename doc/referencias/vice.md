<!--
  abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines

  Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)

  This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
  option) any later version.

  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
  implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
  for more details.

  You should have received a copy of the GNU General Public License along with this program.  If not, see
  <https://www.gnu.org/licenses/>.
-->

# VICE (checked on the machines)

- VICE 3.10 (Arch package `vice`, repository extra) on my three PCs (installed with
  pacman): x64sc (C64), x128 (C128), xcbm5x0 (P500), xcbm2 (B series), c1541, petcat.
- xcbm5x0 drive types (`xcbm5x0 -help`, `-drive8type`): 0 none, 2031, 2040, 3040, 4040, 1001, 8050, 8250, 9000.
- c1541 makes D64, D71 and D80 images (`c1541 -format "name,id" d80 file.d80`: 533248 bytes; d71: 349696 bytes).
- The binary monitor (`-binarymonitor`) drives every test of this project (src/c64/plataforma/pruebas/vice_mb.py).
- Palette files: /usr/share/vice/C64/colodore.vpl (the editor's C64 colours).
