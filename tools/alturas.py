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

"""Height maps of La Abadía (format: data/re/notas/datos.md 4.6 of the full project).

    alturas.py IMAGE ADDR            list the entries of the list at ADDR
    alturas.py --compara IMG_A ADDR_A IMG_B ADDR_B GRID_IMG GRID_ADDR
                                     cells whose height differs, grouped by room (grid of 16x16-cell rooms)
"""
import sys


def entries(m, a):
    out = []
    while m[a] != 0xFF:
        b0 = m[a]
        t = b0 & 7
        if t in (0, 6, 7):
            break
        if b0 & 8:
            e = (b0 >> 4, t, m[a + 1], m[a + 2], m[a + 3] + 1, m[a + 4] + 1); a += 5
        else:
            e = (b0 >> 4, t, m[a + 1], m[a + 2], (m[a + 3] >> 4) + 1, (m[a + 3] & 15) + 1); a += 4
        out.append(e)
    return out, a


SLOPE = {1: (1, 0), 2: (0, -1), 3: (-1, 0), 4: (0, 1), 5: (0, 0)}


def render(ents):
    g = {}
    for h, t, x, y, nx, ny in ents:
        dx, dy = SLOPE[t]
        for j in range(ny):
            for i in range(nx):
                g[((x + i) & 0xFF, (y + j) & 0xFF)] = (h + dx * i + dy * j) & 0xFF
    return g


def main():
    if sys.argv[1] != "--compara":
        m = open(sys.argv[1], "rb").read()
        ents, end = entries(m, int(sys.argv[2], 16))
        for e in ents:
            print("h=%X type=%d x=%02X y=%02X %dx%d" % e)
        print(f"{len(ents)} entries, FF at {end:04X}")
        return
    ma, aa, mb, ab, mg, ag = sys.argv[2], int(sys.argv[3], 16), sys.argv[4], int(sys.argv[5], 16), sys.argv[6], int(sys.argv[7], 16)
    ea, enda = entries(open(ma, "rb").read(), aa)
    eb, endb = entries(open(mb, "rb").read(), ab)
    grid = open(mg, "rb").read()[ag:ag + 256]
    ga, gb = render(ea), render(eb)
    print(f"A: {len(ea)} entries ({enda - aa + 1} bytes), B: {len(eb)} entries ({endb - ab + 1} bytes)")
    rooms = {}
    for c in set(ga) | set(gb):
        if ga.get(c, 0) != gb.get(c, 0):
            x, y = c
            room = grid[(y & 0xF0) | (x >> 4)]
            rooms.setdefault((room, x >> 4, y >> 4), []).append(c)
    for (room, cx, cy), cells in sorted(rooms.items()):
        print(f"room {room:02X} (cell {cx:X},{cy:X}): {len(cells)} cells differ")
    sa, sb = set(ea), set(eb)
    print(f"entries only in A: {len(sa - sb)}, only in B: {len(sb - sa)}")


if __name__ == "__main__":
    main()
