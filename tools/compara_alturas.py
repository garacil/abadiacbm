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

"""The 64 KiB height fill (src/c64/certifica/anfitrion/f_estado_texto.c chr_hbuf_fill_list) and the full game's (the PC
rebuild, chr.c 1000:34E5) on the PC's three height lists, and the library's with the mirror closed, for every window
origin: do they give the same 24x24 buffer?  (Milestone H10, the full game; step 1, all 65536 windows:
0 differ on every list, data/completo/compara_alturas.txt.)

    compara_alturas.py [STEP]
"""
import sys
R = "/home/german/Proyectos/abadia/c/res/"
def clip(win, pos, ln, wl=24):
    a = (win - pos) & 255
    if a == 0: return True, (wl if wl < ln else ln), 0, 0
    if win < pos:
        a = (pos - win) & 255
        if a >= wl: return False, a, 0, a
        a = (wl - a) & 255
        return True, (a if a < ln else ln), 0, (pos - win) & 255
    if a >= ln: return False, a, pos, win
    cnt = ((ln - a) & 255) if ((a + wl) & 255) >= ln else wl
    return True, cnt, a, 0
def f64(d, wx, wy):
    buf = [0] * 576; ix = 0
    while d[ix] != 0xFF:
        c = d[ix]; dd = d[ix + 3]
        if not c & 8: dd = (dd >> 4) & 15
        okx, nx, skx, stx = clip(wx, d[ix + 1], (dd + 1) & 255)
        if okx:
            dd = d[ix + 4] if c & 8 else d[ix + 3] & 15
            oky, ny, sky, sty = clip(wy, d[ix + 2], (dd + 1) & 255)
            if oky:
                kind, h = c & 7, (c >> 4) & 15
                cs = rs = 0
                if kind == 1: cs = 1; h = (h + skx) & 255
                elif kind == 2: rs = -1; h = (h - sky) & 255
                elif kind == 3: cs = -1; h = (h - skx) & 255
                elif kind == 4: rs = 1; h = (h + sky) & 255
                p = sty * 24 + stx
                rv = h
                for r in range(ny if ny else 256):
                    v = rv
                    for k in range(nx if nx else 256):
                        q = p + r * 24 + k
                        if 0 <= q < 576: buf[q] = v
                        else: return None            # (a write outside the buffer: report)
                        v = (v + (0 if kind == 5 else cs)) & 255
                    rv = (rv + (0 if kind == 5 else rs)) & 255
        ix += 5 if d[ix] & 8 else 4
    return buf
DELTAS = [(0, 0), (1, 0), (0, -1), (-1, 0), (0, 1), (0, 0)]
def fpc(d, wx, wy):
    buf = [0] * 576; si = 0
    while True:
        b0 = d[si]
        if b0 == 0xFF: return buf
        kind = b0 & 7
        if kind == 0 or kind >= 6: return buf
        if b0 & 8: nx1, ny1 = d[si + 3], d[si + 4]
        else: c = d[si + 3]; ny1 = c & 15; nx1 = (c >> 4) & 15
        h = (b0 >> 4) & 15; bl, bh = d[si + 1], d[si + 2]
        si += 5 if b0 & 8 else 4
        cl, ch = (nx1 + 1) & 255, (ny1 + 1) & 255
        if bl < wx:
            if ((wx - bl) & 255) >= cl: continue
        elif ((bl - wx) & 255) >= 24: continue
        if bh < wy:
            if ((wy - bh) & 255) >= ch: continue
        elif ((bh - wy) & 255) >= 24: continue
        if kind != 5:
            dx, dy = DELTAS[kind]
            y = bh
            for j in range(ch if ch else 256):
                v = h; cx = bl
                for i in range(cl if cl else 256):
                    if y >= wy and ((y - wy) & 255) < 24 and cx >= wx and ((cx - wx) & 255) < 24:
                        buf[((y - wy) & 255) * 24 + ((cx - wx) & 255)] = v
                    v = (v + dx) & 255; cx = (cx + 1) & 255
                h = (h + dy) & 255; y = (y + 1) & 255
            continue
        if bl < wx:
            al = (((bl - wx) & 255) + cl) & 255
            if al >= 24: al = 24
            cl = al; bl = 0
        else:
            bl = (bl - wx) & 255; s = (bl + cl) & 255
            if s >= 24: cl = (cl - ((s - 24) & 255)) & 255
        if bh < wy:
            al = (((bh - wy) & 255) + ch) & 255
            if al >= 24: al = 24
            ch = al; bh = 0
        else:
            bh = (bh - wy) & 255; s = (bh + ch) & 255
            if s >= 24: ch = (ch - ((s - 24) & 255)) & 255
        p = bh * 24 + bl
        for r in range(ch if ch else 256):
            for k in range(cl if cl else 256):
                q = p + r * 24 + k
                if 0 <= q < 576: buf[q] = h
                else: return None
lists = {n: open(R + f, "rb").read() for n, f in [("floor0", "pantallas/4ea3_chr_floor0_heights.bin"),
         ("floor1", "pantallas/56a4_chr_floor1_heights.bin"), ("floor2", "estado/5aa5_chr_floor2_heights.bin")]}
lists["floor2_closed"] = lists["floor2"][:916] + bytes([0xF5, 0x20, 0x62, 0x0B, 0xFF])
paso = int(sys.argv[1]) if len(sys.argv) > 1 else 4
for nom, d in lists.items():
    dif = errs = 0; ej = None
    for wx in range(0, 256, paso):
        for wy in range(0, 256, paso):
            a, b = f64(d, wx, wy), fpc(d, wx, wy)
            if a is None or b is None: errs += 1; continue
            if a != b:
                dif += 1
                if ej is None: ej = (wx, wy, sum(1 for x, y in zip(a, b) if x != y))
    print(f"{nom}: {(256 // paso) ** 2} windows, {dif} differ, {errs} with a write outside the buffer; first: {ej}")
