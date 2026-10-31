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

"""The height map of one floor of the CPC 64K game, decoded from the floor's height list as
chr_hbuf_fill_list (346E, src/juego/f_estado_texto.c) fills the 24x24 buffer, but over the whole world
(x, y 00..FF).  Records: byte 0 = h<<4 | big<<3 | kind, x, y, then (nx-1)<<4 | (ny-1) (4 bytes) or
nx-1, ny-1 (5 bytes, big = 1); FFh ends.  Kind 5 flat; 1 +1 per column, 2 -1 per row, 3 -1 per
column, 4 +1 per row; 0, 6, 7 flat.  Cells no record covers are 0.

  mapa_alturas.py RAM.bin FLOOR(0|1|2) X0 Y0 X1 Y1   prints the heights (hex digit, '.' for 0)
"""
import sys

LISTS = {0: 0x7B98, 1: 0x9E40, 2: 0x9F60}


def floor_map(ram, floor):
    m = [[0] * 256 for _ in range(256)]          # m[y][x]
    p = LISTS[floor]
    while ram[p] != 0xFF:
        c = ram[p]
        big = c & 0x08
        x0, y0 = ram[p + 1], ram[p + 2]
        if big:
            nx, ny = ram[p + 3] + 1, ram[p + 4] + 1
        else:
            nx, ny = (ram[p + 3] >> 4) + 1, (ram[p + 3] & 0x0F) + 1
        kind, h = c & 7, c >> 4
        for j in range(ny):
            for i in range(nx):
                v = h
                if kind == 1: v = h + i
                elif kind == 2: v = h - j
                elif kind == 3: v = h - i
                elif kind == 4: v = h + j
                m[(y0 + j) & 0xFF][(x0 + i) & 0xFF] = v & 0xFF
        p += 5 if big else 4
    return m


if __name__ == '__main__':
    ram = open(sys.argv[1], 'rb').read()
    floor = int(sys.argv[2])
    x0, y0, x1, y1 = (int(a, 16) for a in sys.argv[3:7])
    m = floor_map(ram, floor)
    print('   y\\x ' + ''.join('%X' % (x & 15) for x in range(x0, x1 + 1)))
    for y in range(y0, y1 + 1):
        print('   %02X  ' % y + ''.join(('.' if m[y][x] == 0 else '%X' % (m[y][x] & 15)) if m[y][x] < 16 else '#'
                                       for x in range(x0, x1 + 1)))
