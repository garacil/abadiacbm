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

"""A route for a 2x2 character on one floor of the CPC 64K game, over the height map of mapa_alturas.py,
with the rules of the game's own path search (chr_path_check_square 4080, src/juego/f_logica_a.c path_square_ok):
a position (x, y) is the top-right cell of the square (x-1..x, y-1..y); a step goes to a 4-neighbour
whose top-right height c is within 1 of the height of the cell left, and whose square is flat or a single
slope (along x or along y).  Breadth first, so the route is a shortest one.

  ruta.py RAM.bin FLOOR X0 Y0 X1 Y1      prints the route as segments 'orientation length' and the cells
  (orientation 0 +x, 1 -y, 2 -x, 3 +y: the step table 23A8)
"""
import sys
from collections import deque
from mapa_alturas import floor_map

DIRS = {0: (1, 0), 1: (0, -1), 2: (-1, 0), 3: (0, 1)}


def square_ok(m, x, y, h):
    c = m[y][x] & 0x3F
    if c >= 0x0E or not (-1 <= h - c <= 1):
        return False
    d1 = (m[y][x - 1] & 0x3F) - c
    d2 = (m[y - 1][x] & 0x3F) - c
    d3 = (m[y - 1][x - 1] & 0x3F) - c
    if d1 == 0:
        return -1 <= d2 <= 1 and d3 == d2
    return d1 in (-1, 1) and d2 == 0 and d3 == d1


def route(m, start, goal, ocupadas=(), ventana=None):
    """ocupadas: cells held by characters (a character's mark: no square holds them); ventana: (x0, y0, x1,
    y1), the search kept inside"""
    if ocupadas:
        m = [fila[:] for fila in m]
        for (x, y) in ocupadas:
            m[y][x] = 0x1F
    prev = {start: None}
    q = deque([start])
    while q:
        p = q.popleft()
        if p == goal:
            break
        h = m[p[1]][p[0]] & 0x0F
        for o, (dx, dy) in DIRS.items():
            n = ((p[0] + dx) & 0xFF, (p[1] + dy) & 0xFF)
            if ventana and not (ventana[0] <= n[0] <= ventana[2] and ventana[1] <= n[1] <= ventana[3]):
                continue
            if not (1 <= n[0] <= 0xFE and 1 <= n[1] <= 0xFE):
                continue
            if n in prev or not square_ok(m, n[0], n[1], h):
                continue
            prev[n] = (p, o)
            q.append(n)
    if goal not in prev:
        return None
    cells, steps = [goal], []
    p = goal
    while prev[p]:
        p, o = prev[p]
        steps.append(o)
        cells.append(p)
    return cells[::-1], steps[::-1]


def celdas(x, y):
    """the four cells of a 2x2 character at (x, y)"""
    return {(x, y), (x - 1, y), (x, y - 1), (x - 1, y - 1)}


def segments(steps):
    seg = []
    for o in steps:
        if seg and seg[-1][0] == o:
            seg[-1][1] += 1
        else:
            seg.append([o, 1])
    return seg


if __name__ == '__main__':
    ram = open(sys.argv[1], 'rb').read()
    m = floor_map(ram, int(sys.argv[2]))
    x0, y0, x1, y1 = (int(a, 16) for a in sys.argv[3:7])
    r = route(m, (x0, y0), (x1, y1))
    if r is None:
        print('no route')
        sys.exit(1)
    cells, steps = r
    print(' '.join('%d:%d' % (o, n) for o, n in segments(steps)))
    print(' '.join('%02X,%02X' % c for c in cells))
