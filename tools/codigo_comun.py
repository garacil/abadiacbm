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

"""Which executed code of one Z80 image also exists in another one (byte runs of >= K bytes).

    codigo_comun.py IMAGE COVERAGE OTHER [--desde 0100 --hasta BFFF]

Executed addresses are grouped into runs; each run is searched in OTHER as 8-byte keys and reported
with the fraction found and the best offset delta.  Runs that are not found are changed or new code.
"""
import collections, sys
K = 8


def main():
    img, other = open(sys.argv[1], "rb").read(), open(sys.argv[3], "rb").read()
    pcs = sorted(int(l, 16) for l in open(sys.argv[2]))
    lo = int(sys.argv[sys.argv.index("--desde") + 1], 16) if "--desde" in sys.argv else 0x0100
    hi = int(sys.argv[sys.argv.index("--hasta") + 1], 16) if "--hasta" in sys.argv else 0xBFFF
    pcs = [p for p in pcs if lo <= p <= hi]
    idx = collections.defaultdict(list)
    for i in range(len(other) - K + 1):
        idx[other[i:i + K]].append(i)
    runs, s, prev = [], None, None
    for p in pcs:
        if s is None: s = p
        elif p > prev + 4: runs.append((s, prev + 3)); s = p
        prev = p
    runs.append((s, prev + 3))
    tot = found = 0
    bad = []
    for a, b in runs:
        n = b - a + 1
        hit = [False] * n
        deltas = collections.Counter()
        for i in range(a, b - K + 2):
            for j in idx.get(img[i:i + K], [])[:4]:
                deltas[j - i] += 1
                for k in range(K): hit[i - a + k] = True
        f = sum(hit)
        tot += n; found += f
        if f < n:
            bad.append((a, b, n - f, deltas.most_common(1)))
    print(f"executed code {tot} bytes in {len(runs)} runs, {found} found in the other image ({100 * found / tot:.1f}%)")
    for a, b, miss, d in bad:
        print(f"  {a:04X}-{b:04X}: {miss} bytes not found" + (f" (delta {d[0][0]:+X})" if d else ""))


if __name__ == "__main__":
    main()
