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

"""The pointer fields inside the game's data (H3): every 16-bit field of a data block that holds an
address of another datum (or of Z80 code), so the data image (src/c64/juego/datos64.py) can rewrite it
CPC -> C64 and the hybrid host (src/juego/m6502/sombra6502.c) can translate both ways when it checks a 6502
routine.

    punteros64.py        -> src/c64/juego/punteros64.tsv

Columns: field (CPC address of the word, little endian), block (the block of src/c64/juego/mapa64.tsv that
holds it), target, flag, note.
  target: a block name, several separated by '|' (the one whose CPC range holds the value), or a class:
          gfx (the converted graphics, through data/c64graf/marcos64.tsv), code (a Z80 routine: the 6502
          routine of the same entry when it exists), pila (a Z80 stack address: not relocated, not compared)
  flag:   -, bit14 (bit 14 is a flag, not part of the address: the robes), virtual (the value may be a base
          before the target block: relocated with the block's offset), tagC0 (values C000h-C0FFh are a tag,
          not an address: the monks' animation)
The value 0000h is never relocated (no pointer).  A value outside its target stays as it is (stale data).

Sources: the tables (decoded here from data/cpc64/juego/ram.bin: the block data and its table, the sound
sequences, the record arrays), the variables (by their meaning, src/juego/datos_*.h and the C translation), the
initial-state copy 0103h (the same fields as the state blocks it copies).
"""
import os, sys

P = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import salas64 as S, bloques_base as B

m = open(os.environ.get("C64_RAM", os.path.join(P, "data", "cpc64", "juego", "ram.bin")), "rb").read()
def w(a): return m[a] | m[a + 1] << 8

campos = []                   # (field, target, flag, note)
def campo(a, destino, marca="-", nota=""):
    campos.append((a, destino, marca, nota))

BLOQUES_DATOS = "D64_ISO_BLOCK_DATA_1|D64_ISO_BLOCK_DATA_2|D64_ISO_BLOCK_DATA_3"
REGISTROS = "D64_CHR_GUILLERMO"
HEIGHTS = "D64_CHR_FLOOR0_HEIGHTS|D64_CHR_FLOOR1_HEIGHTS|D64_CHR_FLOOR2_HEIGHTS"
# the height buffer pointer: AE2Eh, or the path grid 8174h inside the scratch region 7F80h-8EFFh (kept contiguous
# on the C64, so a cell computed past the grid lands where it lands on the CPC)
HBUF = "D64_CHR_HEIGHT_BUFFER|D64_SPR_BUFFER|D64_ISO_MIRROR_BUF_GUILLERMO|D64_PATH_QUEUE_TOP|D64_ISO_TILE_BUFFER"

def bloques_y_tabla():
    mem = S.Mem(os.environ.get("C64_RAM", os.path.join(P, "data", "cpc64", "juego", "ram.bin"))); S.setup(mem)
    usados = set(); a = 0x6100
    for r in range(129):
        ents, end = B.room_entries(mem, a)
        for e in ents: usados.add(e["type"])
        a += mem.b(a)
    for t in range(0, 0xB0, 2):
        campo(0x11DD + t, BLOQUES_DATOS, "-", "block table: type %02X%s" % (t, "" if t in usados else " (no room uses it)"))
    todo, visto = [mem.w(0x11DD + t) for t in sorted(usados)], set()
    while todo:
        blk = todo.pop()
        if blk in visto: continue
        visto.add(blk)
        campo(blk, BLOQUES_DATOS, "-", "block %04X: its tile list" % blk)
        code, calls = B.block_code(mem, blk)
        for s, lines, flags in code:
            for at, hx, txt in lines:
                k = txt.split()[0]
                if k in ("CALL", "CALL_KEEP", "JUMP"): campo(at + 1, BLOQUES_DATOS, "-", "block %04X: %s" % (blk, k))
        todo.extend(calls)

def sonido():
    starts = [0x106E, 0x10F0, 0x1106, 0x110F, 0x1118, 0x1121, 0x112A, 0x1157, 0x1163, 0x11C0, 0x11D0]
    todo, visto = list(starts), set()
    nombre = {0xF9: "jump", 0xFA: "volume envelope", 0xFB: "tone envelope", 0xFC: "nothing", 0xFD: "channel C plays", 0xFE: "channel B plays"}
    while todo:
        a = todo.pop()
        if a in visto: continue
        visto.add(a)
        while True:
            c = m[a]
            if 0xF9 <= c <= 0xFE:
                campo(a + 1, "D64_SND_DATA", "-", "sound sequence command %02X (%s)" % (c, nombre[c]))
                if c in (0xFD, 0xFE, 0xF9): todo.append(w(a + 1))
                if c == 0xF9: break
                a += 3; continue
            if c == 0xFF: break
            a += 3 if c & 0x80 else 2

def main():
    # ---- constant tables ----
    bloques_y_tabla()
    sonido()
    for i in range(6): campo(0x0F77 + 3 * i, "code", "-", "sound command handler")
    for i in range(4): campo(0x08FA + 4 * i, "code", "-", "path exit: band routine")
    for i in range(28): campo(0x1BEE + 2 * i, "code", "-", "block opcode handler")
    for i in range(4): campo(0x1E81 + 2 * i, "code", "-", "camera transform")
    for e in range(6):
        a = 0x2703 + 10 * e
        campo(a, "D64_SPR_TABLE", "-", "chr_table entry %d: sprite" % e)
        campo(a + 2, REGISTROS, "-", "chr_table entry %d: character record" % e)
        campo(a + 4, "code", "-", "chr_table entry %d: behaviour routine" % e)
        campo(a + 6, "code", "-", "chr_table entry %d: flip routine" % e)
        campo(a + 8, "D64_CHR_ANIM_GUILLERMO", "tagC0", "chr_table entry %d: animation table (C000h + 2k for a monk)" % e)
    for i, v in enumerate((0x2477, 0x247E, 0x24A6, 0x25AE, 0x25D9)):
        campo(0x2741 + 2 * i, "var", "-", "chr_param_targets: the operand %04X" % v)
    for i in range(4): campo(0x2BE8 + 2 * i, "gfx", "-", "monk face")
    for i in range(24): campo(0x2CF0 + 4 * i, "gfx", "-", "animation frame (%s)" % ("Guillermo", "Adso", "monk: face, written by chr_select_frame")[i // 8])
    for i in range(6): campo(0x30F0 + 2 * i, REGISTROS, "-", "chr_pos_ptrs: a character's x")
    for i in range(16): campo(0x3134 + 3 * i, "var", "-", "state block %d" % i)
    for i in range(65): campo(0x386A + 2 * i, "var", "-", "script variable %02X" % (0x80 + i))
    for i in range(6): campo(0x3D30 + 2 * i, REGISTROS, "-", "chr_record_ptrs")
    for i in range(16): campo(0x4431 + 2 * i, "gfx", "bit14", "monk robe (bit 14 = drawn mirrored)")
    # ---- variables and records ----
    campo(0x0213, "D64_CHR_PATH_SLOT", "-", "the candidate destination tried")
    for c in range(3):
        base = 0x0C10 + 0x18 * c
        campo(base + 0x00, "D64_SND_DATA", "-", "sound channel %c: the sequence" % "ABC"[c])
        campo(base + 0x05, "D64_SND_DATA", "-", "sound channel %c: the tone envelope" % "ABC"[c])
        campo(base + 0x0A, "D64_SND_DATA", "-", "sound channel %c: the volume envelope" % "ABC"[c])
    campo(0x11DA, "D64_ISO_ROOM_TABLE", "-", "the room record shown")
    campo(0x28D3, "D64_AI_HOUR_DURATIONS", "fin", "the hour name shown (4B12h + 7k; the next letter while it scrolls in: one past the block after COMPLETAS)")
    campo(0x28D5, "D64_CHR_SPRITE_OFFSET_TABLES", "-", "the sprite offsets of the camera orientation")
    campo(0x28D9, REGISTROS, "-", "the character the camera follows")
    campo(0x28DB, HBUF, "-", "the height buffer in use (AE2Eh, or 8174h for the path search)")
    campo(0x28ED, "D64_TXT_WORDS|D64_TXT_PUNCTUATION", "fin", "the next letter of the word printed (or of the punctuation 3447h; one past its end after the last code)")
    campo(0x28EF, "D64_TXT_PHRASES", "-", "the next byte of the phrase")
    campo(0x2901, "pila", "-", "SP saved by the path searches")
    for i in range(6): campo(0x292B + 3 * i, REGISTROS, "-", "door permissions %d: the character's x" % i)
    for i in range(6): campo(0x293E + 7 * i, REGISTROS, "-", "object holder %d: the character's x" % i)
    for k in range(23): campo(0x2968 + 0x14 * k + 7, "gfx", "-", "sprite %d: its graphic (0000 = the light)" % k)
    for k in range(6): campo(0x2B87 + 15 * k + 0x0C, "D64_CHR_COMMAND_BUFFERS", "-", "character %d: its command buffer (0000 = none)" % k)
    campo(0x2BE1, "pila", "-", "the lowest sprite of the list pushed on the stack")
    campo(0x2BE3, "pila", "-", "the next sprite of that list")
    campo(0x2EDE, "D64_CHR_FLOOR2_HEIGHTS", "-", "the mirror's 5 height bytes (A2F0h)")
    campo(0x2EE5, "D64_ISO_ROOM_TABLE", "-", "the mirror's entry in the room data (7ABCh)")
    campo(0x3454, HEIGHTS, "-", "the height list of the current floor")
    campo(0x3F73, "D64_CHR_ROOM_LINKS", "-", "the room links of the floor searched (023Dh, 02EDh, 02F5h)")
    campo(0x4473, "pila", "-", "SP at the entry of spr_draw_all")
    campo(0x4475, "pila", "-", "the next sprite of the list to overlay (on the stack)")
    # the operands the code rewrites
    campo(0x08A0, REGISTROS, "-", "the character the grid is built for")
    campo(0x1697, BLOQUES_DATOS, "-", "the block of the entry being built")
    campo(0x2013, "D64_ISO_FLOOR_MAPS", "virtual", "the floor map shown: base 1E79h, 1F09h or 1F11h")
    campo(0x2070, "D64_SPR_TABLE", "-", "the sprite being set up")
    campo(0x2074, REGISTROS, "-", "its record")
    campo(0x2477, "D64_SPR_TABLE", "-", "the sprite of the character updated")
    campo(0x247E, REGISTROS, "-", "its record")
    campo(0x25D9, "D64_CHR_ANIM_GUILLERMO", "tagC0", "its animation table (C000h + 2k for a monk)")
    campo(0x2E6A, "D64_SYS_KEYS_DOWN", "-", "the key bitmap tested")
    for k in range(9):                    # the object records: +2/+3 the holder when bit 7 of +0 is set, else y:x
        campo(0x2B5B + 5 * k, "D64_CHR_BACKUP", "held", "object %d: its holder (a 293Dh.. entry) when bit 7 of +0 is set, else y:x" % k)
    campo(0x390D, "var", "-", "the script variable assigned last")
    campo(0x41D4, HBUF, "-", "the queue entry that reached the target")
    RECT = "D64_SPR_BUFFER|D64_ISO_MIRROR_BUF_GUILLERMO|D64_PATH_QUEUE_TOP"   # rectangles are allocated up to 877Dh
    campo(0x4690, RECT, "-", "the buffer of the rectangle")
    campo(0x4471, RECT, "-", "spr_buf_free: the next free byte of the sprite buffer")
    for k in range(23):
        campo(0x2978 + 0x14 * k, RECT, "-", "sprite %d: its rectangle in the sprite buffer" % k)
    campo(0x2BE6, "D64_SPR_BUFFER|D64_ISO_MIRROR_BUF_GUILLERMO|D64_PATH_QUEUE_TOP|D64_ISO_TILE_BUFFER", "region",
          "spr_tile_pos: the tile buffer cell (it may run past 8EFFh: the region 7F80h-9FFFh is shifted as a whole)")
    for a in (0x4F9A, 0x4F9E, 0x4FA2, 0x4FA6): campo(a, "D64_CHR_BACKUP", "-", "the mirror state (28DEh/28E3h + 1 or + 3)")
    campo(0x4FD9, "D64_ISO_MIRROR_BUF_GUILLERMO", "-", "the mirror image buffer (855Ch, 8656h)")
    for a, n in ((0x076B, "exit band routine"), (0x09BA, "obj_for_each_visible callback"), (0x12C0, "iso_put_tile form"),
                 (0x1DFC, "block CALL vector"), (0x24A6, "behaviour routine"), (0x25AE, "flip routine"),
                 (0x2656, "camera transform"), (0x312A, "state block copy"), (0x436A, "command generator"),
                 (0x497D, "tile test jump")):
        campo(a, "code", "-", n)
    # ---- the initial-state copy 0103h: the fields of the state blocks it copies ----
    dst = 0x0103
    for i in range(16):
        a, n = w(0x3134 + 3 * i), m[0x3134 + 3 * i + 2]
        for f, d, mk, nt in list(campos):
            if a <= f and f + 2 <= a + n and f not in range(0x0103, 0x01AA):
                campo(dst + f - a, d, mk, "initial-state copy of %04X: %s" % (f, nt))
        dst += n
    # ---- the block of each field, from the map ----
    mapa = []
    for l in open(os.path.join(P, "src", "c64", "juego", "mapa64.tsv")):
        if l.startswith("#"): continue
        x = l.rstrip("\n").split("\t")
        if x[1] != "-": mapa.append((x[0], int(x[1], 16), int(x[2])))
    def bloque(a):
        for n, c, l in mapa:
            if c <= a and a + 2 <= c + l: return n
        raise SystemExit(f"field {a:04X} lies in no block of mapa64.tsv")
    vistos = set()
    out = ["# The pointer fields inside the game's data (punteros64.py; src/c64/NOTAS_MAPA.md).  field (CPC, word), block,",
           "# target (block[|block...] or class gfx / code / var / pila), flag (- / bit14 / virtual / tagC0 / held: a pointer only",
           "# when bit 7 of the byte two before the field is set / fin: may point one past the end of a target block / region: a",
           "# value in 7F80h-9FFFh outside the blocks is shifted as the first target block is), note"]
    for f, d, mk, nt in sorted(campos):
        if f in vistos: continue
        vistos.add(f)
        out.append(f"{f:04X}\t{bloque(f)}\t{d}\t{mk}\t{nt}")
    salida = sys.argv[1] if len(sys.argv) > 1 else os.path.join(P, "src", "c64", "juego")   # the build's directory
    open(os.path.join(salida, "punteros64.tsv"), "w").write("\n".join(out) + "\n")
    # the values in the tape image against their targets (a variable may hold a stale value at the start)
    rangos = {n: (c, l) for n, c, l in mapa}
    graf = []
    for l in open(os.path.join(os.environ.get("C64_GRAF", os.path.join(P, "data", "c64graf")), "graficos64.tsv")):
        x = l.rstrip("\n").split("\t")
        if l.startswith("#") or x[0] == "name" or x[1] in ("", "-"): continue
        graf.append((int(x[1], 16), int(x[2])))
    part = open(os.path.join(P, "data", "cpc64", "particion64.bin"), "rb").read()
    raros = 0
    for f, d, mk, nt in sorted(set(campos)):
        v = w(f)
        if v == 0 or (mk == "tagC0" and v >> 8 == 0xC0): continue
        if mk == "held" and not m[f - 2] & 0x80: continue
        if mk == "bit14": v &= ~0x4000
        if d == "code": ok = part[v] == 1
        elif d == "pila": ok = True
        elif d == "gfx": ok = any(c <= v < c + l for c, l in graf) or 0x855C <= v < 0x8750
        elif d == "var": ok = any(c <= v < c + l for c, l in rangos.values())
        else:
            ok = any(rangos[n][0] <= v < rangos[n][0] + rangos[n][1] for n in d.split("|"))
            if mk == "virtual": ok = ok or any(rangos[n][0] - 0x20 <= v < rangos[n][0] for n in d.split("|"))
            if mk == "fin": ok = ok or any(v == rangos[n][0] + rangos[n][1] for n in d.split("|"))
            if mk == "region": ok = ok or 0x7F80 <= v < 0xA000
        if not ok:
            raros += 1
            print(f"  {f:04X} = {v:04X} not in {d} ({nt})")
    print(f"{len(out) - 2} pointer fields; {raros} values of the tape image outside their target (stale variables)")

main()
