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

"""Where each datum of the full game (PC data space, include/direcciones.h of the C rebuild) is in the
CPC 64 KiB version's memory.

    mapa64.py C_DIR CPC64_RAM OUT.tsv

The PC side is the initial data space rebuilt from the resources (C_DIR/res/manifest.tsv, ds:XXXX).
Methods: `exacto` = the datum's initial bytes occur once in the CPC memory (data of at least 3 bytes,
not all equal); `bloque` = between two located data with the same displacement, it is assumed to keep
it; `vecino` = after a located datum, displacement of the nearest located datum before it within 64
bytes; else unknown.  The displacement groups are printed (PC range -> CPC range).
"""
import os, re, sys


def pc_image(cdir):
    ds = bytearray(0x10000)
    for line in open(os.path.join(cdir, "res", "manifest.tsv")):
        if line.startswith("#") or line.startswith("file\t"): continue
        t = line.split("\t")
        if t[1].startswith("ds:"):
            a = int(t[1][3:], 16)
            d = open(os.path.join(cdir, "res", t[0]), "rb").read()
            ds[a:a + len(d)] = d
    return ds


def items(cdir):
    txt = open(os.path.join(cdir, "include", "direcciones.h")).read()
    sizes = dict((m.group(1), int(m.group(2))) for m in re.finditer(r"#define (\w+)_SIZE\s+(\d+)u", txt))
    out = []
    for m in re.finditer(r"#define (\w+)\s+0x([0-9A-F]+)u\s+/\* ([^,]*), ([^:]*):", txt):
        name = m.group(1)
        if name.endswith("_SIZE"): continue
        out.append((int(m.group(2), 16), sizes.get(name, 1), name, m.group(3), m.group(4)))
    return sorted(out)


def main():
    cdir, cpc, outp = sys.argv[1], open(sys.argv[2], "rb").read(), sys.argv[3]
    ds = pc_image(cdir)
    its = items(cdir)
    res = {}
    for a, n, name, kind, area in its:
        d = bytes(ds[a:a + n])
        if n < 3 or len(set(d)) < 2: continue
        i = cpc.find(d)
        if i >= 0 and cpc.find(d, i + 1) < 0:
            res[name] = (i, "exacto")
    # displacement groups among exact matches, in PC order
    located = [(a, n, name, res[name][0] - a) for a, n, name, k, ar in its if name in res]
    for idx, (a, n, name, kind, area) in enumerate(its):
        if name in res: continue
        before = [x for x in located if x[0] <= a]
        after = [x for x in located if x[0] > a]
        if before and after and before[-1][3] == after[0][3]:
            res[name] = (a + before[-1][3], "bloque")
        elif before and a - (before[-1][0] + before[-1][1]) < 64:
            res[name] = (a + before[-1][3], "vecino")
    with open(outp, "w") as f:
        f.write("# PC data of the full game -> CPC 64 KiB address (tools/mapa64.py)\n")
        f.write("name\tpc\tsize\tkind\tarea\tcpc64\tmethod\n")
        for a, n, name, kind, area in its:
            c, how = res.get(name, (None, "?"))
            f.write(f"{name}\t{a:04X}\t{n}\t{kind}\t{area}\t{'' if c is None else format(c, '04X')}\t{how}\n")
    counts = {}
    for a, n, name, k, ar in its:
        how = res.get(name, (None, "?"))[1]
        counts[how] = counts.get(how, 0) + 1
    print("items:", len(its), counts)
    groups, prev = [], None
    for a, n, name, d in located:
        if prev and prev[3] == d and a - prev[1] < 0x400:
            prev[1] = a + n; prev[4] += 1
        else:
            prev = [a, a + n, name, d, 1]; groups.append(prev)
    for g in groups:
        if g[4] >= 2:
            print(f"  PC {g[0]:04X}-{g[1]:04X} -> CPC {(g[0] + g[3]) & 0xFFFF:04X}  ({g[4]} data, from {g[2]})")


if __name__ == "__main__":
    main()
