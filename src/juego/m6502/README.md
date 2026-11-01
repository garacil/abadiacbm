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

# m6502: a 6502 core for the hybrid host

`6502.c` and `6502.h` are cc65's sim65 CPU core (<https://github.com/cc65/cc65>, `src/sim65/`, the copy
built in `tools/terceros/cc65`, version `cc65 V2.19 - Git a6530f469`), zlib licence (see the notice at the
top of each file), unchanged.  The headers it includes from sim65 are replaced here by minimal ones
(`memory.h`, `peripherals.h`, `paravirt.h`, `trace.h`, `error.h`, written for abadia64ks): the memory
is the array `Mem[]` (`m6502.c`), no paravirtualisation, no trace.  Use: `m6502.h`.
