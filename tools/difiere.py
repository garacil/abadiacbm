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

"""Byte differences of the full game's resources in another memory image.

    difiere.py RES_DIR IMAGE [FILE...]

For each resource: the alignment (image offset of resource byte 0) chosen as the most common delta
of its matching 8-byte runs, then the differing bytes in that alignment, grouped into ranges.
"""
import collections, os, sys
K = 8


def main():
    res, img = sys.argv[1], open(sys.argv[2], "rb").read()
    idx = collections.defaultdict(list)
    for i in range(len(img) - K + 1):
        idx[img[i:i + K]].append(i)
    names = sys.argv[3:]
    if not names:
        names = [l.split("\t")[0] for l in open(os.path.join(res, "manifest.tsv")) if not l.startswith(("#", "file\t"))]
    for f in names:
        data = open(os.path.join(res, f), "rb").read()
        votes = collections.Counter()
        for i in range(0, len(data) - K + 1):
            for j in idx.get(data[i:i + K], [])[:8]:
                votes[j - i] += 1
        if not votes:
            print(f"{f}: no match"); continue
        base, v = votes.most_common(1)[0]
        diffs = [i for i in range(len(data)) if not (0 <= base + i < len(img)) or img[base + i] != data[i]]
        ranges, s = [], None
        for k, i in enumerate(diffs):
            if s is None: s = p = i
            elif i == p + 1: p = i
            else: ranges.append((s, p)); s = p = i
        if s is not None: ranges.append((s, p))
        print(f"{f}: at {base:05X}, {len(diffs)}/{len(data)} bytes differ in {len(ranges)} ranges: "
              + " ".join(f"{a:X}" + (f"-{b:X}" if b > a else "") for a, b in ranges[:40]) + (" ..." if len(ranges) > 40 else ""))


if __name__ == "__main__":
    main()
