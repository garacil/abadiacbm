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

"""The picture of the ink test: the CPC 64K screen with room 16h and the score bar
(c64/plataforma/prueba_pantalla_datos.c, from data/cpc64/run5/ram.bin) as the game's C64 bitmap
(c64/MAPA.md: CPC screen address a -> $E000 + 320 row + 8 (xb / 2 + 4) + line, a CPC byte -> a C64 nibble by
c64/plataforma/tabla_pantalla.inc), and the bitmap's invisible bytes (cells 0-3 and 36-39 of rows 0-23, row
24) filled with pseudo-random bytes, as the game's data there: they must not show.

    pantalla_prueba.py OUT.bin      (8000 bytes: $E000-$FF3F)
"""
import os, random, re, sys

AQUI = os.path.dirname(os.path.abspath(__file__))
PLAT = os.path.dirname(AQUI)


def main():
    texto = open(os.path.join(PLAT, "prueba_pantalla_datos.c")).read()
    cpc = [int(x, 16) for x in re.findall(r"0x([0-9A-Fa-f]{2})", texto.split("{", 1)[1])]
    assert len(cpc) == 12800
    tabla = [int(x, 16) for x in re.findall(r"\$([0-9A-Fa-f]{2})", open(os.path.join(PLAT, "tabla_pantalla.inc")).read())]
    assert len(tabla) == 256
    rnd = random.Random(64)
    bitmap = bytearray(rnd.randrange(256) for _ in range(8000))     # the data in the invisible bytes
    for fila in range(24):                                          # the game's cells: cleared, then the picture
        for celda in range(4, 36):
            for linea in range(8):
                bitmap[320 * fila + 8 * celda + linea] = 0
    for linea in range(8):
        for o in range(1536):                                       # rows 0-23 of each pixel line
            fila, xb = o >> 6, o & 63
            v = tabla[cpc[linea * 1600 + o]]
            k = 320 * fila + 8 * (xb // 2 + 4) + linea
            bitmap[k] |= v if xb & 1 else v << 4
    open(sys.argv[1], "wb").write(bitmap)


if __name__ == "__main__":
    main()
