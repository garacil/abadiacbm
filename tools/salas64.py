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

"""Rooms of the CPC 64 KiB version: build and draw them from a CPC memory image.

The room builder is the model of the full game's builder (bloques_base.py, a copy of
abadia/trabajo/re/notas/motor_b/bloques.py), pointed at the CPC 64 KiB tables: room table 6100h,
block table 11DDh, opcode handler table 1BEEh (same 28 handlers in the same order as the PC's
B7F4h), tiles at 8300h (32 bytes each, CPC mode 1, 4 bytes x 8 lines).

Masking (from the PC's pixel tables, carried to CPC pens through the measured pen correspondence
PC 0,1,2,3 = CPC 3,1,2,0): tiles 01-0A are opaque; tiles 0B-7F: pen 2 transparent, 3->3, 1->2,
0->1; tiles 80-FF: pen 1 transparent, 3->3, 2->0, 0->1.  To be checked against the real screen.

    salas64.py IMAGE build N                 tile buffer of room N
    salas64.py IMAGE render N OUT.png [--pal 06,0E,03,14]   room N alone, CPC colours
    salas64.py IMAGE check SCREEN_IMAGE N    compare room N drawn here with the play area of a
                                             CPC memory dump taken while the room is shown
    salas64.py IMAGE render-all DIR
"""
import os, struct, sys, zlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bloques_base as B

PC_TABLE = [0x2A58, 0x2AD2, 0x2ADE, 0x2B0F, 0x2B13, 0x2B17, 0x2B26, 0x2B36, 0x2B8F, 0x2A7E, 0x2A82, 0x2A86, 0x2A8A,
            0x2A8E, 0x2A9C, 0x2AB0, 0x2AAA, 0x2ABC, 0x2AB6, 0x2C18, 0x2B2E, 0x2C06, 0x2BEC, 0x2BEC, 0x2BEC, 0x2BEC,
            0x2BEC, 0x2C0E]
PCW = [(3, 1, 2, 0)]
PEN_OF_PC = (3, 1, 2, 0)           # PC colour c is CPC pen PEN_OF_PC[c]


class Mem:
    def __init__(self, path):
        self.ds = bytearray(open(path, "rb").read()[:0x10000]); self.video = None; self.path = path
    def b(self, a): return self.ds[a & 0xFFFF]
    def w(self, a): return self.ds[a & 0xFFFF] | self.ds[(a + 1) & 0xFFFF] << 8


def setup(mem):
    B.ROOM_TABLE, B.BLOCK_TABLE, B.OP_TABLE, B.TILE_GFX = 0x6100, 0x11DD, 0x1BEE, 0x8300
    B.HANDLERS = {mem.w(B.OP_TABLE + 2 * i): B.HANDLERS[PC_TABLE[i]] for i in range(28)}


def cpc_pixels(byte):
    return [((byte >> (7 - i)) & 1) | (((byte >> (3 - i)) & 1) << 1) for i in range(4)]


def cpc_byte(p):
    v = 0
    for i, c in enumerate(p):
        v |= ((c & 1) << (7 - i)) | (((c >> 1) & 1) << (3 - i))
    return v


def pc_rule(table):
    """CPC pen -> output CPC pen or None (transparent), carried from the PC tables."""
    if table == 1:   # PC: 0->0, 1->2, 3->1, 2 transparent
        pc = {0: 0, 1: 2, 3: 1, 2: None}
    else:            # PC: 0->0, 2->3, 3->1, 1 transparent
        pc = {0: 0, 2: 3, 3: 1, 1: None}
    return {PEN_OF_PC[g]: (None if o is None else PEN_OF_PC[o]) for g, o in pc.items()}


OUT = (2, 0, 1, 3)   # output pen of the PC-derived rules -> pen on the CPC screen (measured on room 16h)
R1 = {k: (None if v is None else OUT[v]) for k, v in pc_rule(1).items()}
R2 = {k: (None if v is None else OUT[v]) for k, v in pc_rule(2).items()}


# opaque tiles 01-0A: the PC copies the table-1 OR byte, so the transparent pen (PC 2) gives PC colour 0
R1o = {k: (OUT[PEN_OF_PC[0]] if v is None else v) for k, v in R1.items()}


def render(mem, buf, fill=0):
    """Pens of the 256x160 play area as a list of rows."""
    scr = [[fill] * 256 for _ in range(160)]
    for (r, c) in B.spiral():
        if not (0 <= r < B.ROWS and 0 <= c < B.COLS): continue
        o = (r * B.COLS + c) * B.CELL
        for tile in (buf[o + 2], buf[o + 5]):
            if not tile: continue
            src = B.TILE_GFX + tile * 32
            rule = R2 if tile & 0x80 else R1
            for line in range(8):
                y = r * 8 + line
                for i in range(4):
                    for k, p in enumerate(cpc_pixels(mem.b(src + line * 4 + i))):
                        x = c * 16 + i * 4 + k
                        if tile < 0x0B:
                            scr[y][x] = R1o[p]
                        elif rule[p] is not None:
                            scr[y][x] = rule[p]
    return scr


HW = [(128,128,128),(128,128,128),(0,255,128),(255,255,128),(0,0,128),(255,0,128),(0,128,128),(255,128,128),
      (255,0,128),(255,255,128),(255,255,0),(255,255,255),(255,0,0),(255,0,255),(255,128,0),(255,128,255),
      (0,0,128),(0,255,128),(0,255,0),(0,255,255),(0,0,0),(0,0,255),(0,128,0),(0,128,255),
      (128,0,128),(128,255,128),(128,255,0),(128,255,255),(128,0,0),(128,0,255),(128,128,0),(128,128,255)]


def write_png(path, scr, pal):
    h, w = len(scr), len(scr[0])
    rows = [b"\0" + b"".join(bytes(HW[pal[p]]) * 2 for p in row) for row in scr for _ in (0, 1)]
    def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w * 2, h * 2, 8, 2, 0, 0, 0))
                           + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b""))


def screen_play_area(m):
    """Pens of the play area from a CPC dump (screen at C000h, 64 bytes a line, as the game sets the CRTC)."""
    scr = []
    for y in range(160):
        row = []
        for xb in range(64):
            row += cpc_pixels(m[0xC000 + ((y & 7) << 11) + (y >> 3) * 64 + xb])
        scr.append(row)
    return scr


def main():
    mem = Mem(sys.argv[1]); setup(mem)
    cmd = sys.argv[2]
    pal = [int(x, 16) for x in (sys.argv[sys.argv.index("--pal") + 1].split(",") if "--pal" in sys.argv else "06,0E,03,14".split(","))]
    if cmd == "build":
        B.cmd_build(mem, int(sys.argv[3], 16))
    elif cmd == "render":
        buf = B.build_room(mem, int(sys.argv[3], 16))
        write_png(sys.argv[4], render(mem, buf), pal)
    elif cmd == "render-all":
        os.makedirs(sys.argv[3], exist_ok=True)
        for r in range(B.room_count(mem)):
            if B.room_entries(mem, B.room_ptr(mem, r))[0]:
                write_png(os.path.join(sys.argv[3], f"sala_{r:02X}.png"), render(mem, B.build_room(mem, r)), pal)
    elif cmd == "check":
        dump = open(sys.argv[3], "rb").read()
        n = int(sys.argv[4], 16)
        mine = render(mem, B.build_room(mem, n))
        real = screen_play_area(dump)
        same = sum(1 for y in range(160) for x in range(256) if mine[y][x] == real[y][x])
        print(f"room {n:02X}: {same} of {160 * 256} pixels equal to the dump (the rest = sprites over it)")
        if "--png" in sys.argv:
            p = sys.argv[sys.argv.index("--png") + 1]
            write_png(p + "_mia.png", mine, pal); write_png(p + "_real.png", real, pal)


if __name__ == "__main__":
    main()
