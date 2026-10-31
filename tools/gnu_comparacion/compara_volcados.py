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

"""Two screen-state dumps (referencia.py and abadia64ks --volcado) compared frame by frame: the screen
memory C000h-FFFFh, the mode, the inks that the mode shows (pens 0-3 in mode 1, 0-15 in mode 0, and the
border) and the CRTC registers that place the picture (R1, R6, R9, R12, R13).

    compara_volcados.py A.bin B.bin [FROM [TO]]
Prints the frames compared, how many are identical, and the first differences (frame, what, bytes)."""
import struct, sys

TAM = 4 + 1 + 17 + 16 + 0x4000


def lee(nombre):
    d = open(nombre, "rb").read()
    r = {}
    for k in range(0, len(d) - TAM + 1, TAM):
        f, = struct.unpack_from("<I", d, k)
        r[f] = d[k + 4:k + TAM]
    return r


a, b = lee(sys.argv[1]), lee(sys.argv[2])
desde = int(sys.argv[3]) if len(sys.argv) > 3 else 0
hasta = int(sys.argv[4]) if len(sys.argv) > 4 else 1 << 30
comunes = sorted(f for f in a if f in b and desde <= f <= hasta)
iguales, informados = 0, 0
for f in comunes:
    x, y = a[f], b[f]
    modo = x[0]
    pens = list(range(4 if modo == 1 else 16)) + [16]
    dif = []
    if x[0] != y[0]:
        dif.append(f"mode {x[0]} {y[0]}")
    for p in pens:
        if x[1 + p] != y[1 + p]:
            dif.append(f"pen {p}: {x[1 + p]:02X} {y[1 + p]:02X}")
    for r in (1, 6, 9, 12, 13):
        if x[18 + r] != y[18 + r]:
            dif.append(f"R{r} {x[18 + r]} {y[18 + r]}")
    pa, pb = x[34:], y[34:]
    n = sum(1 for i in range(0x4000) if pa[i] != pb[i])
    if n:
        primero = next(i for i in range(0x4000) if pa[i] != pb[i])
        dif.append(f"{n} screen bytes, the first at {0xC000 + primero:04X} ({pa[primero]:02X} {pb[primero]:02X})")
    if dif:
        if informados < 12:
            print(f"frame {f}: " + "; ".join(dif))
        informados += 1
    else:
        iguales += 1
print(f"{len(comunes)} frames compared ({comunes[0] if comunes else '-'}-{comunes[-1] if comunes else '-'}), "
      f"{iguales} identical, {len(comunes) - iguales} different")
sys.exit(0 if comunes and iguales == len(comunes) else 1)
