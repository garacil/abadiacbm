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

"""The loading picture with its title in English: abbey.koa from abadia.koa ("La abadia del crimen" -> "The Abbey of Crime").

    titulo_en.py OUT.koa [PNG]     writes the picture (10000 bytes: bitmap, screen RAM, colour RAM, as abadia.koa) and, if given,
                                   a 3x picture of it for looking at

The Spanish title (cells 13-39, rows 0-10 of the 40 x 25 cells) is erased; the monk, the skull, the book and "OPERA soft" are
untouched.  The new title is set in the parchment's own gothic letters (the tape's font, with the glyphs of c64/ingles/glifos_en.py),
each glyph pixel drawn as one multicolour pixel wide and two lines tall (the font's 320-pixel aspect on the C64's 160): a pink top,
a brown body and a cyan outline, the title's colours; every cell of the title holds those three colours and black, so any shape fits.
Drawn programmatically, not by the original artist (Juan Delcan): it needs a visual review (c64/ingles/NOTAS.md).
"""
import os, sys

D = os.path.dirname(os.path.realpath(__file__))
P = os.path.dirname(os.path.dirname(D))
sys.path.insert(0, D)
sys.dont_write_bytecode = True
import pergamino_en as PE                                            # noqa: E402

ORIGINAL = os.path.join(P, "c64", "presentacion", "original", "graphics", "abadia.koa")
ROSA, CIAN, MARRON = 10, 3, 9                    # light red, cyan, brown: pens 1, 2, 3 of every cell of the title
COLS, FILAS = range(13, 40), range(0, 11)        # the cells the Spanish title occupies (the book's top edge, cols 35-39 row 10, stays)
CONSERVA = {(c, 10) for c in range(35, 40)}
# the lines: (text, x in C64 pixels of the picture's 160, y of the capitals' top in lines)
LINEAS = [("The Abbey", 56, 3), ("of", 66, 54), ("Crime", 88, 54)]
# "of" as a small word between the lines, like the Spanish "del": drawn without the pink top (white would need a 4th colour)


def decodifica(k):
    bm, scr, col = k[:8000], k[8000:9000], k[9000:10000]
    pix = [[0] * 160 for _ in range(200)]          # the pen 0-3 of every C64 pixel
    for c in range(1000):
        for l in range(8):
            b = bm[c * 8 + l]
            for p in range(4):
                pix[c // 40 * 8 + l][c % 40 * 4 + p] = (b >> (6 - 2 * p)) & 3
    return pix, scr, col


def mascara(gl):
    """{(x, y): True} of the title's glyph pixels (x in C64 pixels, y in lines)"""
    m = set()
    for texto, x0, y0 in LINEAS:
        x = x0
        for ch in texto:
            if ch == " ":
                x += 10
                continue
            pts, av = gl[ord(ch)]
            for gx, gy in pts:
                for dy in (0, 1):
                    m.add((x + gx, y0 + 2 * gy + dy))
            x += av
    return m


def pinta(m):
    """the pens of the title: 1 pink (the top lines of each stroke), 3 brown (the body), 2 cyan (the outline)"""
    pen = {}
    for (x, y) in m:
        arriba = (x, y - 3) not in m                # within 3 lines of the top of its stroke: pink
        pen[(x, y)] = 1 if arriba else 3
    for (x, y) in m:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                q = (x + dx, y + dy)
                if q not in m and q not in pen and 0 <= q[0] < 160 and 0 <= q[1] < 200:
                    pen[q] = 2
    return pen


def principal(salida, png=None):
    gl, _, _ = PE.tabla_glifos()
    k = bytearray(open(ORIGINAL, "rb").read())
    assert len(k) == 10000
    bm, scr, col = bytearray(k[:8000]), bytearray(k[8000:9000]), bytearray(k[9000:10000])
    celdas = [(c, f) for f in FILAS for c in COLS if (c, f) not in CONSERVA] + [(12, f) for f in (0, 1, 2)] + [(11, 0), (11, 1)]   # the tip of the old L
    for c, f in celdas:
        i = f * 40 + c
        bm[i * 8:i * 8 + 8] = bytes(8)
        scr[i] = ROSA << 4 | CIAN
        col[i] = MARRON
    pen = pinta(mascara(gl))
    fuera = [(x, y) for (x, y) in pen if (x // 4, y // 8) not in set(celdas)]
    assert not fuera, f"the title leaves its cells at {fuera[:5]}"
    for (x, y), v in pen.items():
        i = (y // 8) * 40 + x // 4
        bm[i * 8 + y % 8] |= v << (6 - 2 * (x % 4))
    open(salida, "wb").write(bytes(bm + scr + col))
    if png:
        from PIL import Image
        pal = [(0, 0, 0), (255, 255, 255), (129, 51, 56), (117, 206, 200), (142, 60, 151), (86, 172, 77), (46, 44, 155), (237, 241, 113),
               (142, 80, 41), (85, 56, 0), (196, 108, 113), (74, 74, 74), (123, 123, 123), (169, 255, 159), (112, 109, 235), (178, 178, 178)]
        pix, s, c2 = decodifica(bytes(bm + scr + col))
        S = 3
        im = Image.new("RGB", (160 * 2 * S, 200 * S))
        px = im.load()
        for y in range(200):
            for x in range(160):
                i = (y // 8) * 40 + x // 4
                colores = [0, s[i] >> 4, s[i] & 15, c2[i] & 15]
                c = pal[colores[pix[y][x]]]
                for a in range(2 * S):
                    for b in range(S):
                        px[x * 2 * S + a, y * S + b] = c
        im.save(png)


if __name__ == "__main__":
    principal(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
