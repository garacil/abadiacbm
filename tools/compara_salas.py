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

"""Compare the room table of the full game (PC rebuild resource) with the one in a CPC memory image.

    compara_salas.py PC_ROOM_TABLE IMAGE [--grid PC_GRID]

Room table format (data/re/notas/motor_b.md 1.2 of the PC project): records [len][entries][FF],
room n = n-th record.  The image's table is found as the longest chain of well-formed records.
"""
import sys


def records(buf, start, limit=400):
    out, p = [], start
    while len(out) < limit and p < len(buf):
        n = buf[p]
        if n < 2 or p + n > len(buf) or buf[p + n - 1] != 0xFF:
            break
        out.append(bytes(buf[p:p + n]))
        p += n
    return out, p


def entries(rec):
    e, i = [], 1
    while i < len(rec) - 1:
        b = rec[i]
        if b == 0xFF:
            break
        n = 4 if b & 1 else 3
        e.append(rec[i:i + n])
        i += n
    return e


def main():
    pc = open(sys.argv[1], "rb").read()
    img = open(sys.argv[2], "rb").read()
    pcr, _ = records(pc, 0)
    best = (0, 0)
    for s in range(len(img)):
        if img[s] >= 2 and img[s] < 0x80:
            r, end = records(img, s, 400)
            if len(r) > best[1]:
                best = (s, len(r))
    s, n = best
    imr, end = records(img, s, 400)
    print(f"PC table: {len(pcr)} records; image table at {s:04X}: {n} records, ends {end:04X}")
    same = diff = 0
    for i in range(max(len(pcr), len(imr))):
        a = pcr[i] if i < len(pcr) else None
        b = imr[i] if i < len(imr) else None
        if a == b:
            if a is not None and len(a) > 2:
                same += 1
            continue
        diff += 1
        ea, eb = entries(a or b"\x02\xff"), entries(b or b"\x02\xff")
        gone = [x for x in ea if x not in eb]
        new = [x for x in eb if x not in ea]
        print(f"room {i:02X}: PC {len(a) if a else '-'} bytes, image {len(b) if b else '-'} bytes; "
              f"{len(gone)} PC entries missing, {len(new)} new: "
              f"missing {' '.join(x.hex() for x in gone[:12])}{' ...' if len(gone) > 12 else ''} "
              f"new {' '.join(x.hex() for x in new[:12])}")
    print(f"identical non-empty rooms: {same}, different records: {diff}")


if __name__ == "__main__":
    main()
