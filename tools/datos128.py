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

"""The full game's map for abadia128ks (milestone H10; the PC version is the reference): the data
blocks of the 64 KiB game that the full game has otherwise (data/completo/PLAN.md), from the PC rebuild's
resources (abadia/c/res) and its data space at load (abadia/trabajo/re/disco/programa.bin), written for
src/c64/juego_final/mapa64.py and datos64.py (C64_COMPLETO=DIR):

  DIR/completo.tsv     block (the 64 KiB game's name), its file, its new length
  DIR/<block>.bin      the block's bytes
  DIR/punteros.tsv     the pointer fields inside them: block, offset, target block, offset in the target
  DIR/parches.tsv      single values inside other blocks: block, offset, bytes (hex), why

The room table, the three height lists (the library's ends with the room for the mirror's 5 closing bytes, as the
64 KiB keeps it: obj_close_mirror), the block table (96 types) and the block data (one block; the 64 KiB game's
second and third pieces become empty) with their pointers (each block: its tile list; the operands of CALL,
CALL_KEEP and JUMP: bloques_base.py's disassembler, as tools/punteros64.py does on the 64 KiB data),
the room links; the start square (Guillermo x 88h, y A8h: the PC's 1000:1F41) and Berengar's place on it.

    datos128.py DIR
"""
import os, sys
AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import bloques_base as B

RES = "/home/german/Proyectos/abadia/c/res"
PC_PROGRAMA = "/home/german/Proyectos/abadia/trabajo/re/disco/programa.bin"
TABLA, DATOS = 0xB71D, 0xAECC          # the PC's block table (96 words) and block data (2126 bytes)
N_TABLA, N_DATOS = 192, 2126


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    mem = B.Mem(PC_PROGRAMA)
    def res(f): return open(os.path.join(RES, f), "rb").read()
    tabla = bytes(mem.ds[TABLA:TABLA + N_TABLA])
    datos = bytes(mem.ds[DATOS:DATOS + N_DATOS])
    assert tabla == res("pantallas/b71d_iso_block_table.bin") and datos == res("pantallas/aecc_iso_block_data.bin")
    bloques = {
        "D64_ISO_ROOM_TABLE": res("estado/82c2_iso_room_table.bin"),
        "D64_CHR_FLOOR0_HEIGHTS": res("pantallas/4ea3_chr_floor0_heights.bin"),
        "D64_CHR_FLOOR1_HEIGHTS": res("pantallas/56a4_chr_floor1_heights.bin"),
        "D64_CHR_FLOOR2_HEIGHTS": res("estado/5aa5_chr_floor2_heights.bin"),
        "D64_ISO_BLOCK_TABLE": tabla,
        "D64_ISO_BLOCK_DATA_1": datos,
        "D64_ISO_BLOCK_DATA_2": b"",
        "D64_ISO_BLOCK_DATA_3": b"",
        "D64_CHR_ROOM_LINKS": res("estado/aafd_chr_room_links.bin"),
    }
    # the library's list: its FFh and the 5 bytes after it are where obj_close_mirror writes F5 20 62 0B FF
    l2 = bloques["D64_CHR_FLOOR2_HEIGHTS"]
    p = 0
    while l2[p] != 0xFF: p += 5 if l2[p] & 8 else 4
    assert p + 5 <= len(l2), "the library's list has no room for the mirror's closing bytes"
    # the pointers: every block table entry, every block's tile list and its CALL / CALL_KEEP / JUMP operands
    campos = {}
    def campo(blq, off, valor):
        assert DATOS <= valor < DATOS + N_DATOS, f"{blq}+{off}: {valor:04X} outside the block data"
        campos[(blq, off)] = ("D64_ISO_BLOCK_DATA_1", valor - DATOS)
    usados = set()
    for r in range(B.room_count(mem)):
        for e in B.room_entries(mem, B.room_ptr(mem, r))[0]: usados.add(e["type"])
    for t in range(0, N_TABLA, 2):
        v = mem.w(TABLA + t)
        if v == 0 and t not in usados: continue        # (type 00: no block)
        campo("D64_ISO_BLOCK_TABLE", t, v)
    todo, visto = [mem.w(TABLA + t) for t in sorted(usados)], set()
    while todo:
        blk = todo.pop()
        if blk in visto: continue
        visto.add(blk)
        campo("D64_ISO_BLOCK_DATA_1", blk - DATOS, mem.w(blk))
        code, calls = B.block_code(mem, blk)
        for s, lines, flags in code:
            for at, hx, txt in lines:
                if txt.split()[0] in ("CALL", "CALL_KEEP", "JUMP"):
                    campo("D64_ISO_BLOCK_DATA_1", at + 1 - DATOS, mem.w(at + 1))
        todo.extend(calls)
    for (blq, off), _ in campos.items():
        assert off + 2 <= len(bloques[blq])
    for nom, d in bloques.items():
        open(os.path.join(out, nom + ".bin"), "wb").write(d)
    with open(os.path.join(out, "completo.tsv"), "w") as o:
        o.write("# made by tools/datos128.py (do not edit): the full game's map blocks for abadia128ks\n"
                "block\tfile\tlength\n")
        for nom, d in bloques.items(): o.write(f"{nom}\t{nom}.bin\t{len(d)}\n")
    with open(os.path.join(out, "punteros.tsv"), "w") as o:
        o.write("# made by tools/datos128.py (do not edit): pointer fields of the full game's map blocks\n"
                "block\toffset\ttarget\ttarget_offset\n")
        for (blq, off), (tgt, toff) in sorted(campos.items()): o.write(f"{blq}\t{off}\t{tgt}\t{toff}\n")
    with open(os.path.join(out, "parches.tsv"), "w") as o:
        o.write("# made by tools/datos128.py (do not edit): values of the full game inside other blocks\n"
                "name\toffset\tbytes\twhy\n"
                "D64_GAME_START_POS\t0\t88a8\tthe start square: Guillermo x 88h, y A8h (the entrance; PC 1000:1F41), Adso beside him\n"
                "D64_AI_BERENGAR_PLACES\t13\ta8\tBerengar's place at the start square (9Ch on the 64 KiB game)\n")
    print(f"{len(bloques)} blocks ({sum(len(d) for d in bloques.values())} bytes), {len(campos)} pointer fields, "
          f"{len(visto)} blocks reached from {len(usados)} block types")


if __name__ == "__main__":
    main()
