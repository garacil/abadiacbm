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

"""The AY writes of the CPC (cpc_carga.py --ay, with --marca 613F --marca 6146: its trace gives each
interrupt handler's span) against abadia64ks --ay ('TICK REGISTER VALUE'): each CPC write gets the tick of
the 300 Hz interrupt whose handler made it, or, outside a handler (64F1h stopping the music), the ticks
passed; then the two lists are compared in order.
    compara_ay.py CPC_TRAZA.log CPC_AY.txt GNU_AY.txt"""
import bisect, sys
ini, fin = [], []
for l in open(sys.argv[1]):
    if l.startswith("M 613F"):
        ini.append(int(l.split()[2][2:]))
    elif l.startswith("M 6146"):
        fin.append(int(l.split()[2][2:]))
ref = []
for l in open(sys.argv[2]):
    t, r, v = map(int, l.split())
    i = bisect.bisect_right(ini, t) - 1
    dentro = i >= 0 and i < len(fin) and ini[i] <= t <= fin[i]
    ref.append((ini[i] // 13312 if dentro else t // 13312, r, v))
gnu = [tuple(map(int, l.split())) for l in open(sys.argv[3])]
n = min(len(ref), len(gnu))
d = [i for i in range(n) if ref[i] != gnu[i]]
print(f"AY writes: CPC {len(ref)}, GNU {len(gnu)}, compared {n}, different {len(d)}",
      [(ref[i], gnu[i]) for i in d[:5]])
sys.exit(1 if d or not n else 0)
