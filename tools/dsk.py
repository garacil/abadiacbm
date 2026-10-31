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

"""Read an Amstrad CPC disk image (MV - CPC standard or EXTENDED CPC DSK).

    dsk.py IMAGE                 list tracks/sectors and the AMSDOS directory
    dsk.py IMAGE --extract DIR   write every AMSDOS file (header kept apart as NAME.hdr) and the raw
                                 sector stream of the image (pistas.bin, in sector-id order)
"""
import os, struct, sys


def tracks(img):
    std = img.startswith(b"MV - CPC")
    ntr, nsd = img[0x30], img[0x31]
    tsize = struct.unpack_from("<H", img, 0x32)[0]
    off = 0x100
    out = {}
    for t in range(ntr * nsd):
        size = tsize if std else img[0x34 + t] * 256
        if size == 0:
            continue
        ti = img[off:off + size]
        assert ti[:10] == b"Track-Info", (t, ti[:12])
        nsec = ti[0x15]
        secs, p = [], off + 0x100
        for s in range(nsec):
            c, h, r, n, st1, st2, alen = struct.unpack_from("<BBBBBBH", ti, 0x18 + 8 * s)
            ln = (128 << n) if std or alen == 0 else alen
            secs.append((c, h, r, n, img[p:p + ln]))
            p += ln
        out[(ti[0x10], ti[0x11])] = secs
        off += size
    return out


def sector_map(trs):
    """(track, record id) -> bytes."""
    m = {}
    for (t, h), secs in trs.items():
        for c, hh, r, n, data in secs:
            m[(t, r)] = data
    return m


def amsdos(trs):
    """Directory of a DATA (C1-C9) or SYSTEM (41-49) format disk: [(user, name, ext, size, blocks)]."""
    first = min(r for (t, r) in sector_map(trs) if t == 0)
    fmt = "data" if first == 0xC1 else "system" if first == 0x41 else "other"
    if fmt == "other":
        return fmt, []
    base, reserved = (0xC1, 0) if fmt == "data" else (0x41, 2)
    m = sector_map(trs)
    def block(b):
        lin = b * 2
        res = b""
        for k in range(2):
            t, s = divmod(lin + k, 9)
            res += m.get((t + reserved, base + s), b"\xe5" * 512)
        return res
    d = block(0) + block(1)
    files = {}
    for e in range(64):
        ent = d[32 * e:32 * e + 32]
        if ent[0] == 0xE5:
            continue
        name = bytes(x & 0x7F for x in ent[1:9]).decode("latin1").strip()
        ext = bytes(x & 0x7F for x in ent[9:12]).decode("latin1").strip()
        key = (ent[0], name, ext)
        files.setdefault(key, []).append((ent[12], ent[15], [b for b in ent[16:32] if b]))
    out = []
    for key, exts in files.items():
        exts.sort()
        blocks = [b for _, _, bl in exts for b in bl]
        recs = sum(rc for _, rc, _ in exts) if len(exts) == 1 else (len(exts) - 1) * 128 + exts[-1][1]
        data = b"".join(block(b) for b in blocks)[:recs * 128]
        out.append((key[0], key[1], key[2], data))
    return fmt, out


def main():
    img = open(sys.argv[1], "rb").read()
    trs = tracks(img)
    for (t, h), secs in sorted(trs.items()):
        print(f"track {t:2} side {h}: " + " ".join(f"{r:02X}/{128 << n if n < 8 else '?'}" for c, hh, r, n, d in secs))
    fmt, files = amsdos(trs)
    print("format", fmt)
    for u, n, e, data in files:
        hdr = ""
        if len(data) >= 128 and sum(data[:67]) & 0xFFFF == struct.unpack_from("<H", data, 67)[0]:
            typ, load, ln, ent = data[18], *struct.unpack_from("<H", data, 21), struct.unpack_from("<H", data, 24)[0], struct.unpack_from("<H", data, 26)[0]
            hdr = f"type {typ} load {load:04X} len {ln:04X} entry {ent:04X}"
        print(f"  {u}:{n}.{e} {len(data)} bytes {hdr}")
    if "--extract" in sys.argv:
        out = sys.argv[sys.argv.index("--extract") + 1]
        os.makedirs(out, exist_ok=True)
        for u, n, e, data in files:
            nm = f"{n}.{e}" if e else n
            if len(data) >= 128 and sum(data[:67]) & 0xFFFF == struct.unpack_from("<H", data, 67)[0]:
                ln = struct.unpack_from("<H", data, 24)[0]
                open(os.path.join(out, nm + ".hdr"), "wb").write(data[:128])
                data = data[128:128 + ln]
            open(os.path.join(out, nm), "wb").write(data)
        raw = b"".join(d for (t, h), secs in sorted(trs.items()) for c, hh, r, n, d in sorted(secs, key=lambda s: s[2]))
        open(os.path.join(out, "pistas.bin"), "wb").write(raw)


if __name__ == "__main__":
    main()
