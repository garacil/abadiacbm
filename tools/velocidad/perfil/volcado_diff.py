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

"""Compare two 64 KiB memory dumps of the scratch host (parche_traza.py's SOMBRA6502_TRAZA_VOLCADO: 64 KiB + 8
register bytes A X Y SP SR PCL PCH 0) and group the differing bytes by the blocks of mapa64.tsv (addresses outside
every block by page).  Prints the registers of both, the count per block and, with --bytes, each differing address
with both values.  Deterministic.

    volcado_diff.py MAPA64.tsv DUMP1 DUMP2 [--bytes]"""
import bisect
import sys

mapa, f1, f2 = sys.argv[1:4]
show = "--bytes" in sys.argv
blocks = []
for l in open(mapa):
    if l.startswith("#") or not l.strip():
        continue
    t = l.rstrip("\n").split("\t")
    blocks.append((int(t[3], 16), int(t[4]), t[0], t[5], t[6], t[7]))
blocks.sort()
starts = [b[0] for b in blocks]


def block_of(a):
    i = bisect.bisect_right(starts, a) - 1
    if i >= 0 and blocks[i][0] <= a < blocks[i][0] + blocks[i][1]:
        return blocks[i]
    return None


d1, d2 = open(f1, "rb").read(), open(f2, "rb").read()
for n, d in ((f1, d1), (f2, d2)):
    r = d[0x10000:0x10008]
    print(f"{n}: A={r[0]:02X} X={r[1]:02X} Y={r[2]:02X} SP={r[3]:02X} SR={r[4]:02X} PC={r[6]:02X}{r[5]:02X}")
per = {}
lines = []
for a in range(0x10000):
    if d1[a] == d2[a]:
        continue
    b = block_of(a)
    key = (b[0], b[2], b[3], b[4], b[5]) if b else (a & 0xFF00, "(no block)", "", "", "")
    per[key] = per.get(key, 0) + 1
    if show:
        lines.append(f"  {a:04X} {d1[a]:02X} -> {d2[a]:02X} {key[1]}")
print(f"{sum(per.values())} bytes differ")
for key, n in sorted(per.items()):
    print(f"  {key[0]:04X} {key[1]} {key[2]} {key[3]} {key[4]}: {n}")
for l in lines:
    print(l)
