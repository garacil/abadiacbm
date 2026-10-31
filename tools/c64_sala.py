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

"""A room of the CPC 64 KiB version as a Commodore 64 multicolour bitmap (proof of concept).

    c64_sala.py CPC_IMAGE ROOM OUT.c [--pal 06,0E,03,14] [--regla derecho|izquierdo|no_negro]

The room is built and drawn by salas64.py (CPC pens, 256x160), each pair of CPC pixels becomes one
multicolour pixel (by default the right one: the CPC graphics put the black outline on the left of
most mixed pairs, so the right pixel keeps the columns yellow and the brick lines; compared on room
16h in data/cpc64/reduccion.png; rule "detalle", the default, also keeps one-pixel vertical lines
of 3 rows or more that the right pixel would lose, such as the shading line of the columns), the play area is centred in the 160x200 bitmap (x 16..143, y 0..159).
Bit pairs: 00 = $D021 (CPC pen 3, black), 01 = screen RAM high nibble (pen 0), 10 = screen RAM low
nibble (pen 1), 11 = colour RAM (pen 2), every cell with the same colours: the CPC's four inks.
The C file defines sala_bitmap[8000], sala_screen[1000], sala_color[1000], sala_bg.
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import salas64 as S

PAL = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "src", "c64", "datos", "paleta.tsv")
BITS = {3: 0, 0: 1, 1: 2, 2: 3}       # CPC pen -> multicolour bit pair


def aislado(scr, x, y):
    """CPC pixel (x, y) differs from both horizontal neighbours (a one-pixel-wide vertical feature)."""
    row = scr[y]
    return 0 < x < len(row) - 1 and row[x] != row[x - 1] and row[x] != row[x + 1]


def linea(scr, x, y):
    """Pixel (x, y) is part of a vertical line one pixel wide, at least 3 rows long."""
    if not aislado(scr, x, y):
        return False
    n, yy = 1, y - 1
    while yy >= 0 and scr[yy][x] == scr[y][x] and aislado(scr, x, yy): n += 1; yy -= 1
    yy = y + 1
    while yy < len(scr) and scr[yy][x] == scr[y][x] and aislado(scr, x, yy): n += 1; yy += 1
    return n >= 3


def estria(scr, x, y):
    """CPC pixel x of row y lies in a run of pixels alternating between two colours (a b a b a b),
    six pixels around it: the fluting of the columns."""
    row = scr[y]
    lo, hi = max(0, x - 3), min(len(row), x + 3)
    seg = row[lo:hi]
    if len(seg) < 6:
        return False
    return all(seg[i] != seg[i + 1] for i in range(len(seg) - 1)) and all(seg[i] == seg[i + 2] for i in range(len(seg) - 2))


def mitad_detalle(scr, x, y):
    """Multicolour pixel x (CPC pixels 2x, 2x+1).  Inside fluting (alternating pixels over 3 rows or
    more) the pixel taken alternates left/right with x, so the stripes stay as stripes twice as wide;
    else the left pixel when it belongs to a one-pixel vertical line and the right one does not;
    else the right pixel."""
    a, b = scr[y][2 * x], scr[y][2 * x + 1]
    if a == b:
        return a
    rows = [yy for yy in (y - 1, y, y + 1) if 0 <= yy < len(scr)]
    if sum(1 for yy in rows if estria(scr, 2 * x, yy)) >= 2 and estria(scr, 2 * x, y):
        return b if x & 1 else a
    if linea(scr, 2 * x, y) and not linea(scr, 2 * x + 1, y):
        return a
    return b


def c64_colour():
    m = {}
    for line in open(PAL):
        if line.startswith("#") or not line.strip(): continue
        t = line.split("\t")
        m[int(t[0], 16)] = int(t[2])
    return m


def main():
    img, room, out = sys.argv[1], int(sys.argv[2], 16), sys.argv[3]
    pal = [int(x, 16) for x in (sys.argv[sys.argv.index("--pal") + 1] if "--pal" in sys.argv else "06,0E,03,14").split(",")]
    regla = sys.argv[sys.argv.index("--regla") + 1] if "--regla" in sys.argv else "detalle"
    mem = S.Mem(img); S.setup(mem)
    scr = S.render(mem, S.B.build_room(mem, room))
    col = c64_colour()
    mc = [[0] * 160 for _ in range(200)]
    for y in range(160):
        for x in range(128):
            a, b = scr[y][2 * x], scr[y][2 * x + 1]
            if regla == "detalle":
                p = mitad_detalle(scr, x, y)
            else:
                p = {"izquierdo": a, "derecho": b, "no_negro": b if a == 3 else a}[regla]
            mc[y][16 + x] = BITS[p]
    bitmap = bytearray(8000)
    for cy in range(25):
        for cx in range(40):
            for line in range(8):
                v = 0
                for k in range(4):
                    v = (v << 2) | mc[cy * 8 + line][cx * 4 + k]
                bitmap[(cy * 40 + cx) * 8 + line] = v
    c0, c1, c2, c3 = (col[pal[p]] for p in range(4))
    screen = bytes([(c0 << 4) | c1] * 1000)
    color = bytes([c2] * 1000)
    def arr(name, data):
        rows = ",\n".join("  " + ",".join(f"0x{b:02X}" for b in data[i:i + 20]) for i in range(0, len(data), 20))
        return f"const unsigned char {name}[{len(data)}] = {{\n{rows}\n}};\n"
    with open(out, "w") as f:
        f.write(f"/* generated by tools/c64_sala.py: room {room:02X} of the CPC 64 KiB version */\n")
        f.write(arr("sala_bitmap", bitmap) + arr("sala_screen", screen) + arr("sala_color", color))
        f.write(f"const unsigned char sala_bg = {col[pal[3]]};\n")


if __name__ == "__main__":
    main()
