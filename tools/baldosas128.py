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

"""The tiles of abadia128ks (milestone H10, the full game; new graphics
added only where they are really used, each converted the same way as the existing ones, and the existing ones not
changed; the same tiles as in the 64ks, with those the 128ks uses and the 64ks lacks added, so that the tiles common
to the 64ks and the 128ks show no difference).

The full game's rooms keep the PC's tile numbers (its room and block data unchanged).  Every room of the PC (its data
space, abadia/trabajo/re/disco/programa.bin: room table 82C2h, block table B71Dh, tiles 2B22h) is built by
bloques_base.py and drawn in the game's order, each play-area pixel noted with the tile that set it last (tiles
01-0A opaque, 0B-7F PC pen 2 clear, 80-FF PC pen 1 clear); the mirror's room 72h also with its entry closed, open
and as the trap.  A tile is shown when it owns a pixel somewhere.  For each shown tile: the 64 KiB tile whose CPC
image is the same (PC pens 0,1,2,3 = CPC 3,1,2,0; preferring the same number, then a tile the 64 KiB rooms show) —
its C64 graphic is taken as it is, the edits included —, or `new` (converted by the same rule).  The tiles
shown nowhere are free; two runs of them take the objects' graphics that the C64 keeps in the tile block.

    baldosas128.py OUT.tsv
"""
import os, sys
AQUI = os.path.dirname(os.path.abspath(__file__))
P = os.path.normpath(os.path.join(AQUI, ".."))
sys.path.insert(0, AQUI)
import bloques_base as B, salas64 as S

PC_PROGRAMA = os.path.join(os.environ.get("ABADIA_PC", os.path.expanduser("~/Proyectos/abadia")), "trabajo/re/disco/programa.bin")
OBJETOS_64K = set(range(0x2D, 0x30)) | set(range(0xA1, 0xA7))     # c64_graficos.py SLOTS_OBJETOS
NBALDOSAS_64K = 0xDA


def dueños(mem, buf, pix):
    d = set()
    vis = [[0] * 256 for _ in range(160)]
    for (row, c) in B.spiral():
        if not (0 <= row < B.ROWS and 0 <= c < B.COLS): continue
        o = (row * B.COLS + c) * B.CELL
        for tile in (buf[o + 2], buf[o + 5]):
            if not tile: continue
            for line in range(8):
                for i in range(4):
                    for k, op in enumerate(pix(tile, line, i)):
                        if op: vis[row * 8 + line][c * 16 + i * 4 + k] = tile
    for f in vis: d.update(t for t in f if t)
    return d


def visibles_pc():
    mem = B.Mem(PC_PROGRAMA)
    def pix(tile, line, i):
        b = mem.b(B.TILE_GFX + tile * 32 + line * 4 + i)
        clear = 1 if tile & 0x80 else 2
        return [tile < 0x0B or ((b >> (6 - 2 * k)) & 3) != clear for k in range(4)]
    vis = set()
    for r in range(B.room_count(mem)):
        if B.room_entries(mem, B.room_ptr(mem, r))[0]:
            vis |= dueños(mem, B.build_room(mem, r), pix)
    ents, _ = B.room_entries(mem, B.room_ptr(mem, 0x72))          # the mirror (game_init_mirror: block 1F AA 51)
    at = [e["at"] for e in ents if e["raw"][:3] == [0x1F, 0xAA, 0x51]][0]
    orig = bytes(mem.ds[at:at + 3])
    for t0 in (0x1F, 0x6B):
        for y in (0x51, 0x11):
            mem.ds[at] = t0; mem.ds[at + 2] = y
            vis |= dueños(mem, B.build_room(mem, 0x72), pix)
    mem.ds[at:at + 3] = orig
    return vis, mem


def visibles_64k(m64):
    mem = S.Mem(os.path.join(P, "data", "cpc64", "juego", "ram.bin")); S.setup(mem)
    def pix(tile, line, i):
        rule = S.R2 if tile & 0x80 else S.R1
        return [tile < 0x0B or rule[p] is not None for p in S.cpc_pixels(mem.b(B.TILE_GFX + tile * 32 + line * 4 + i))]
    vis = set()
    for r in range(0x81):                                          # the 129 records of the 64 KiB table
        if B.room_entries(mem, B.room_ptr(mem, r))[0]:
            vis |= dueños(mem, B.build_room(mem, r), pix)
    return vis


def main():
    m64 = open(os.path.join(P, "data", "cpc64", "juego", "ram.bin"), "rb").read()
    vis64 = visibles_64k(m64)
    # (bloques_base's globals: the PC's tables again after salas64.setup pointed them at the 64 KiB ones)
    import importlib
    importlib.reload(B)
    vis, mem = visibles_pc()
    def cpc(n):
        t = mem.ds[0x2B22 + 32 * n:0x2B22 + 32 * n + 32]
        return bytes(S.cpc_byte([S.PEN_OF_PC[(b >> (6 - 2 * k)) & 3] for k in range(4)]) for b in t)
    t64 = {k: m64[0x8300 + 32 * k:0x8300 + 32 * k + 32] for k in range(1, NBALDOSAS_64K) if k not in OBJETOS_64K}
    clase = lambda x: 0 if x < 0x0B else 1 if x < 0x80 else 2
    filas = []
    for n in range(256):
        if n == 0: filas.append((n, "empty", "")); continue
        if n not in vis: filas.append((n, "free", "")); continue
        ks = sorted((k for k in t64 if t64[k] == cpc(n)), key=lambda k: (k != n, k not in vis64, clase(k) != clase(n), k))
        filas.append((n, "64K", f"{ks[0]:02X}") if ks else (n, "new", cpc(n).hex()))
    libres = [n for n, q, _ in filas if q == "free"]
    def tramo(k):
        for i in range(len(libres) - k + 1):
            if libres[i + k - 1] - libres[i] == k - 1: return libres[i]
        raise SystemExit(f"no run of {k} free tiles")
    obj1 = tramo(3)                                               # the lamp and the book (64 KiB slots 2D-2F)
    resto = [x for x in libres if not obj1 <= x < obj1 + 3]
    libres_tmp, libres[:] = libres[:], resto
    obj2 = tramo(6)                                               # glasses, object 1, keys, parchment (A1-A6)
    libres[:] = libres_tmp
    with open(sys.argv[1], "w") as o:
        o.write("# made by tools/baldosas128.py (do not edit): abadia128ks's 256 tiles (the PC's numbers).\n"
                "# kind: 64K = the C64 graphic of that 64 KiB tile as it is (same image); new = converted (its CPC image,\n"
                "# 32 bytes); free = shown in no room of the full game; objects = the C64's object graphics moved there.\n"
                f"# objects: lamp and book from 2D-2F to {obj1:02X}-{obj1 + 2:02X}; glasses, object 1, keys, parchment from A1-A6 to "
                f"{obj2:02X}-{obj2 + 5:02X}\n")
        o.write("tile\tkind\tsource\n")
        for n, q, s in filas:
            if q == "free" and (obj1 <= n < obj1 + 3 or obj2 <= n < obj2 + 6): q = "objects"
            o.write(f"{n:02X}\t{q}\t{s}\n")
    cuenta = {}
    for _, q, _ in filas: cuenta[q] = cuenta.get(q, 0) + 1
    print(f"{len(vis)} tiles shown in the full game: {cuenta}; objects at {obj1:02X} and {obj2:02X}")


if __name__ == "__main__":
    main()
