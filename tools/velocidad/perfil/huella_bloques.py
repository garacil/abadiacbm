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

"""Map a routine's memory footprint (the tracer's .huella_ADDR.tsv: "ADDR\\tR|W|RW", R = read before written in
some call, W = written in some call) to the blocks of mapa64.tsv (name, CPC start, CPC length, C64 address, C64
length, mode, zone, kind) and to the whole-game check's exclusions (juego6502.tsv): which compared blocks the
routine writes (what a change must leave identical at every frame point) and which it only reads.  Addresses
outside every block are reported by range (the code, the stack, the scratch).  Deterministic.

    huella_bloques.py MAPA64.tsv JUEGO6502.tsv HUELLA.tsv [HUELLA.tsv...]"""
import sys
import os


def main():
    mapa, j6502 = sys.argv[1], sys.argv[2]
    blocks = []
    for l in open(mapa):
        if l.startswith("#") or not l.strip():
            continue
        t = l.rstrip("\n").split("\t")
        name, cpc, lcpc, c64, l64, mode, zone, kind = t[:8]
        blocks.append((int(c64, 16), int(l64), name, mode, zone, kind, cpc))
    blocks.sort()
    excl = set()
    for l in open(j6502):
        if l.startswith("#") or not l.strip():
            continue
        t = l.split()
        if t[0] == "nuevo" or t[0] == "final" or t[0].startswith("@"):
            continue
        excl.add(t[0])
    starts = [b[0] for b in blocks]
    import bisect

    def block_of(a):
        i = bisect.bisect_right(starts, a) - 1
        if i >= 0 and blocks[i][0] <= a < blocks[i][0] + blocks[i][1]:
            return blocks[i]
        return None
    for hf in sys.argv[3:]:
        per = {}
        outside = {}
        for l in open(hf):
            a, k = l.split()
            a = int(a, 16)
            b = block_of(a)
            if b is None:
                key = (a >> 8)
                d = outside.setdefault(key, [0, 0, 0xFFFF, 0])
                d[0] += "R" in k; d[1] += "W" in k; d[2] = min(d[2], a); d[3] = max(d[3], a)
                continue
            d = per.setdefault(b, [0, 0])
            d[0] += "R" in k
            d[1] += "W" in k
        print(f"== {os.path.basename(hf)}")
        print("block\tc64\tlen\tmode\tzone\tkind\tcompared\tread_before_write\twritten")
        for b, (r, w) in sorted(per.items()):
            c64, l64, name, mode, zone, kind, cpc = b
            cmp_ = "no (juego6502.tsv)" if name in excl else "no (mode nada)" if mode == "nada" else "yes"
            print(f"{name}\t{c64:04X}\t{l64}\t{mode}\t{zone}\t{kind}\t{cmp_}\t{r}\t{w}")
        for page, (r, w, lo, hi) in sorted(outside.items()):
            print(f"(no block)\t{lo:04X}-{hi:04X}\t\t\t\t\t-\t{r}\t{w}")


if __name__ == "__main__":
    main()
