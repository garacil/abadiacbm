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

"""The function map of the CPC 64 KiB game: entries seen as call targets in simulator runs
(llamadas.tsv of cpc_carga.py --llamadas), named after the full game's functions.

    funciones64.py OUT.tsv LLAMADAS.tsv...

A PC function whose description gives its CPC 6128 address gets the 64K address of that Z80
instruction (6128 -> 64K code alignment); a call target equal to it takes its name.  Unnamed targets
keep `f_XXXX`.  Columns: 64K address, name, PC address, CPC 6128 address, times called, callers.
"""
import collections, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bisect
from mapa_por_codigo import code_map, pc_functions


def main():
    pairs = code_map()
    keys = [p[0] for p in pairs]
    def to64(c):
        i = bisect.bisect_left(keys, c)
        if i < len(keys) and keys[i] == c: return pairs[i][1]
        return None
    named = {}
    for a, name, c128 in pc_functions():
        if c128 is None: continue
        z = to64(c128)
        if z is not None: named[z] = (name, a, c128)
    times = collections.Counter(); callers = collections.defaultdict(set)
    for path in sys.argv[2:]:
        for line in open(path):
            if line.startswith(("caller", "#")): continue   # (and my licence header)
            c, t, k = line.split()
            times[int(t, 16)] += int(k); callers[int(t, 16)].add(int(c, 16))
    entries = set(times) | set(named)
    with open(sys.argv[1], "w") as f:
        f.write("# functions of the CPC 64 KiB game (funciones64.py)\n")
        f.write("addr64\tname\tpc\tcpc6128\ttimes\tcallers\n")
        for z in sorted(entries):
            name, a, c = named.get(z, (f"f_{z:04X}", None, None))
            f.write(f"{z:04X}\t{name}\t{'' if a is None else format(a, '04X')}\t{'' if c is None else format(c, '04X')}\t"
                    f"{times[z]}\t{' '.join(format(x, '04X') for x in sorted(callers[z])[:6])}\n")
    seen = set(times)
    print(f"call targets seen {len(seen)}; named {len(seen & set(named))}; PC functions placed in 64K {len(named)} "
          f"({len(set(named) - seen)} of them not called in these runs)")


if __name__ == "__main__":
    main()
