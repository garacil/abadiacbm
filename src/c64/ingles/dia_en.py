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

"""The score bar's gothic "Dia" (Spanish for day) redrawn as "Day" in the tape's image (genera_ram_en.py calls pon_day).

The score bar is 32 lines of 64 CPC bytes (mode 1, 4 pixels a byte) in the hidden rows C600h, D600h, E600h, F600h (8 lines
each); the C64 build takes the LEFT pixel of every pair of CPC pixels (c64_graficos.py, rule izq: 128 x 32 C64 pixels).  So the
new word is drawn here at the C64's resolution and every pixel is written twice: what the C64 shows is exactly this drawing.
Drawn by hand in the original's two tones (orange above, cyan below, on black): they are not the original artist's lettering and need
a visual review (c64/ingles/NOTAS.md).  Region: C64 pixels x 1-18, lines 6-16 of the bar; its decoration above, below and to the
sides, the box on the right and "OBSEQUIUM" are untouched.
"""

SRC = (0xC600, 0xD600, 0xE600, 0xF600)
X0, Y0, ANCHO, ALTO = 1, 6, 18, 11            # the region (C64 pixels x, bar lines y)
PEN = {"o": 1, "c": 0, ".": 3}               # orange, cyan, black (CPC pens of the game's day palette); '.' = background

# the letters, line 0 = bar line 6; o orange (upper strokes), c cyan (lower), . black.  D 7 wide (lines 0-8), a 4 wide (lines 4-8),
# y 4 wide (lines 4-10: its descender), one blank column between letters
D = ["ooooo..",
     "oo..oo.",
     "oo...oo",
     "oo...oo",
     "oo...oo",
     "cc...cc",
     "cc...cc",
     "cc..cc.",
     "ccccc.."]
A = [".oo.",
     "...o",
     ".ccc",
     "c..c",
     ".ccc"]
Y = ["o..o",
     "o..o",
     "c..c",
     ".ccc",
     "...c",
     "...c",
     "ccc."]


def _compone():
    filas = []
    for j in range(ALTO):
        d = D[j] if j < len(D) else "." * 7
        a = A[j - 4] if 4 <= j < 4 + len(A) else "." * 4
        y = Y[j - 4] if 4 <= j < 4 + len(Y) else "." * 4
        filas.append(d + "." + a + "." + y + ".")
    return filas


DIBUJO = _compone()


def pon_pixel(m, x, y, pen):
    src = SRC[y // 8]
    a = src + (y % 8) * 64 + x // 4
    p = x % 4
    b = m[a] & ~((0x80 >> p) | (0x08 >> p))
    if pen & 1:
        b |= 0x80 >> p
    if pen & 2:
        b |= 0x08 >> p
    m[a] = b


def pon_day(m):
    m = bytearray(m)
    assert len(DIBUJO) == ALTO and all(len(f) == ANCHO for f in DIBUJO), "the drawing's size"
    for j, fila in enumerate(DIBUJO):
        for i, ch in enumerate(fila):
            for k in (0, 1):                  # the C64 pixel i is the CPC pixels 2i (taken) and 2i + 1 (equal)
                pon_pixel(m, 2 * (X0 + i) + k, Y0 + j, PEN[ch])
    return bytes(m), f"score bar: Dia -> Day ({ANCHO} x {ALTO} C64 pixels at x {X0}, line {Y0}; dia_en.py)"
