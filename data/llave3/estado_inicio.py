#!/usr/bin/env python3
# abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
#
# Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
#
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along with this program.  If not, see
# <https://www.gnu.org/licenses/>.

"""A start state for the hybrid host: a copy of data/puro/estados/ram_dDhH.bin (a new game at day D,
hour H: [BF4F] = day, [BF4E] = hour, read by ai_clock_init) with Guillermo's start position changed:
[BF50] = x, [BF51] = y, [BF52] = height, which the game's own start (2110-2123, src/juego/f_principal.c)
copies into Guillermo's record and, x - 2 and y + 2, into Adso's.  Nothing else changes.

  estado_inicio.py IN.bin OUT.bin X Y Z      (hex)
"""
import sys
ram = bytearray(open(sys.argv[1], 'rb').read())
x, y, z = (int(a, 16) for a in sys.argv[3:6])
ram[0xBF50], ram[0xBF51], ram[0xBF52] = x, y, z
open(sys.argv[2], 'wb').write(ram)
print('%s: day %d hour %d, Guillermo at %02X %02X %02X, Adso at %02X %02X %02X'
      % (sys.argv[2], ram[0xBF4F], ram[0xBF4E], x, y, z, (x - 2) & 0xFF, (y + 2) & 0xFF, z))
