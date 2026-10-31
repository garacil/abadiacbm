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

"""Sum of the T-states of the instructions in [FROM, TO) of tiempos_z80.py's output; for a conditional
instruction the cost is chosen with a suffix in the range list: 'FROM-TO' takes the first (smaller,
not taken) value of every conditional, 'FROM-TO:t' the larger (taken) one, and 'ADDR=t'/'ADDR=n'
overrides one instruction.   suma.py TIEMPOS.txt 6701-6713 6716-6721 6721=... """
import sys
t = {}
for l in open(sys.argv[1]):
    p = l.split()
    if len(p) >= 2 and len(p[0]) == 4:
        t[int(p[0], 16)] = [int(x) for x in p[1].split("/")]
total = 0
over = {}
for a in sys.argv[2:]:
    if "=" in a:
        k, v = a.split("=")
        over[int(k, 16)] = v
for a in sys.argv[2:]:
    if "=" in a:
        continue
    r, _, modo = a.partition(":")
    d, h = (int(x, 16) for x in r.split("-"))
    s = 0
    for k in sorted(t):
        if d <= k < h:
            v = t[k]
            m = over.get(k, modo or "n")
            c = v[-1] if m == "t" else v[0]
            s += c
    print(f"{r:>10} {modo or 'n'}: {s}")
    total += s
print("total", total)
