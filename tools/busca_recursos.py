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

"""Where are the resources of the PC rebuild in other memory images?

    busca_recursos.py RES_DIR IMAGE [IMAGE...]

For every file of RES_DIR/manifest.tsv: in each image, the exact offset if the whole file is there,
otherwise the fraction of its bytes covered by matching runs of at least 12 bytes (found through
an index of 12-byte keys) and the offsets of the longest runs.
"""
import os, sys
K = 12


def index(img):
    idx = {}
    for i in range(len(img) - K + 1):
        idx.setdefault(img[i:i + K], []).append(i)
    return idx


def coverage(data, img, idx):
    covered = bytearray(len(data))
    runs = []
    i = 0
    while i <= len(data) - K:
        cands = idx.get(data[i:i + K])
        if not cands:
            i += 1
            continue
        best, where = 0, None
        for c in cands[:64]:
            n = K
            while i + n < len(data) and c + n < len(img) and data[i + n] == img[c + n]:
                n += 1
            if n > best:
                best, where = n, c
        runs.append((i, where, best))
        for j in range(i, i + best):
            covered[j] = 1
        i += best
    return sum(covered) / max(1, len(data)), runs


def main():
    res = sys.argv[1]
    imgs = [(os.path.basename(os.path.dirname(p)) + "/" + os.path.basename(p), open(p, "rb").read()) for p in sys.argv[2:]]
    idxs = [index(im) for _, im in imgs]
    print("file\tsize\t" + "\t".join(n for n, _ in imgs))
    for line in open(os.path.join(res, "manifest.tsv")):
        if line.startswith("#") or line.startswith("file\t"):
            continue
        f, dest, size, kind = line.split("\t")[:4]
        data = open(os.path.join(res, f), "rb").read()
        if len(data) < K or kind in ("unused", "buf", "stack", "var"):
            continue
        cols = []
        for (n, im), idx in zip(imgs, idxs):
            p = im.find(data)
            if p >= 0:
                cols.append(f"= {p:05X}")
                continue
            frac, runs = coverage(data, im, idx)
            top = sorted(runs, key=lambda r: -r[2])[:3]
            cols.append(f"{frac * 100:5.1f}% " + ",".join(f"{a:X}@{b:05X}+{c}" for a, b, c in top))
        print(f"{f}\t{size}\t" + "\t".join(cols))


if __name__ == "__main__":
    main()
