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

# Official references (index)

Facts this project relies on, each with its source and how it was checked.  The rule:
always from the official documentation, never from memory, and every official fact kept in the project, properly
indexed.  A fact is marked **checked** only when the real thing (VICE with
the real ROMs, the hardware, the original game) confirmed it; otherwise **from the source**.

| File | Subject |
|---|---|
| [cinta_c64.md](cinta_c64.md) | The C64 tape: the KERNAL's tape encoding (pulses, bytes, blocks, header), the TAP file format |
| [c128.md](c128.md) | The Commodore 128: the MMU (its registers bit by bit, from "Mapping the Commodore 128"), memory banks, common RAM, VIC-II video bank; the KERNAL (boot sector, LOAD's limit, SETBNK, the raster interrupt, JIRQ, 2 MHz), VICE |
| [p500.md](p500.md) | The Commodore P500 (CBM-II): the 6509 and its banks, the I/O of bank 15 (VIC-II, SID, 6526, the two 6525 TPIs), the interrupt's acknowledgement, the keyboard matrix, the KERNAL (its variables, LOAD, SAVE, the cross-bank call), cc65's cbm510 runtime, VICE |
| [vice.md](vice.md) | VICE 3.10 on my PCs: emulators, disk and tape image tools |
