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

"""abadia128ks against the PC, frame by frame (milestone H10, the full game): the dumps of corre128.py (x128: block 0,
then block 1's data from $1000, juego.bin.banco1's length: the room table, the texts...) and of the PC rebuild with arnes.c (its data space), both taken at game_input_and_mirror's
entry with the same keys.  Every datum with a shared name (D64_NAME of the C128 build's mapa64.inc, NAME of the PC's
include/direcciones.h) is compared; a 16-bit value counts as equal when on both sides it names the same datum or
function at the same offset (the pointers of the two machines).  The data listed in IGNORA are not compared (their
reason there).  Out: per datum, the first frame where it differs and how many frames differ.

    compara.py JUEGO_DIR C128_DUMP PC_DUMP [FROM-TO]
"""
import glob, os, re, sys
PC = "/home/german/Proyectos/abadia/c"
juego, f128, fpc = sys.argv[1], sys.argv[2], sys.argv[3]
rango = sys.argv[4] if len(sys.argv) > 4 else None
# not compared: run-time work areas whose layout or meaning is the machine's
IGNORA = {
    "ISO_TILE_BUFFER": "the room's tile buffer: drawing work",
    "CHR_HEIGHT_BUFFER": "the screen's height buffer: rebuilt from the lists when needed",
    "CHR_PATH_GRID": "the path search's work grid",
    "SPR_BUFFER": "the sprites' composition buffer (graphics)",
    "SYS_STACK": "the stack", "SYS_DEMO_BUFFER": "the PC's demo recorder",
    # the machine: the interrupt's ticks and the frame budget (CPC 300 Hz, PC timer), the sound, the text's scroll
    # timer (an interrupt counter), self-modified operands and code vectors, the drawing's own state
    "SYS_TICKS": "interrupt ticks", "SYS_FRAME_TICKS": "frame budget in ticks", "SYS_FRAME_TICKS_NORMAL": "idem",
    "TXT_SCROLL_TIMER": "interrupt counter",
    "ISO_STEP_RIGHT_INSN": "self-modified code", "SPR_TILE_TEST_JUMP": "self-modified code",
    "ISO_ENTER_VECTOR": "code vector", "ISO_BLOCK_OPCODE_TABLE": "code addresses", "ISO_MIRROR_BUFFER": "drawing",
    "SPR_CUR_BUFFER": "drawing", "SPR_BUF_FREE": "drawing", "SPR_SORTED_TOP": "drawing", "SPR_SORTED_CURSOR": "drawing",
    "SPR_OVERLAY_CURSOR": "drawing", "SPR_OV_LINE": "drawing", "SPR_SAVED_SP": "a stack pointer", "SPR_TILE_POS": "drawing",
    "SPR_FLIP_WIDTH": "drawing", "VID_SPIRAL_SIDES": "drawing", "OBJ_ENTITY_CALLBACK": "code vector",
    "CHR_PATH_SAVED_SP": "a stack pointer", "CHR_BACKUP": "scratch",
    "SPR_MONK_FACES": "graphics pointers", "SPR_MONK_ROBES": "graphics pointers", "CHR_ANIM_GUILLERMO": "graphics pointers",
    "CHR_ANIM_ADSO": "graphics pointers", "CHR_ANIM_MONK": "graphics pointers", "CHR_SPRITE_OFFSETS": "a table pointer",
    "ISO_FLOOR_MAP_PTR": "a table pointer",
    "ISO_DARK_FLOOR": "a constant on the 64 KiB game",
}
SND = re.compile(r"^SND_")
# load-time values the game sets before it reads them: compared from frame 2
DESDE2 = {"OBJ_ROOM_REDRAW", "ISO_ROOM_PTR"}
c64, tam64 = {}, {}
for l in open(os.path.join(juego, "mapa64.inc")):
    if "a constant" in l: continue
    m = re.match(r"D64_(\w+) = \$([0-9A-F]+)\s+;(?: CPC [0-9A-F]+h, \d+ -> (\d+) bytes)?", l)
    if m:
        c64[m.group(1)] = int(m.group(2), 16)
        if m.group(3): tam64[m.group(1)] = int(m.group(3))
pcs, tampc = {}, {}
TIPOS = {"byte": 1, "word": 2, "dword": 4, "ptr": 2}
for l in open(os.path.join(PC, "include", "direcciones.h")):
    m = re.match(r"#define (\w+)\s+0x([0-9A-F]+)u\s+/\* (\w+)(?::(0x[0-9a-fA-F]+|\d+))?", l)
    if m and not m.group(1).endswith("_SIZE"):
        pcs[m.group(1)] = int(m.group(2), 16)
        tipo, n = m.group(3), m.group(4)               # (the comment's type: byte, word, bytes:N, ptrs:N, ascii:N...)
        if tipo in TIPOS: tampc[m.group(1)] = TIPOS[tipo]
        elif n: tampc[m.group(1)] = int(n, 0) * (2 if tipo in ("ptrs", "words") else 1)
    m = re.match(r"#define (\w+)_SIZE\s+(\d+)u", l)
    if m: tampc[m.group(1)] = int(m.group(2))
comunes = sorted(n for n in c64 if n in pcs and n not in IGNORA and not SND.match(n))
for n in c64:                                   # (a name inside a block: the PC's size of the same name)
    if n not in tam64 and n in tampc: tam64[n] = tampc[n]
# the command buffers: 5 of 45 bytes on the 64 KiB game (Malachi, the abbot, Berengar, Severin, Adso), 5 of 48 on the
# PC (Adso, Malachi, the abbot, Berengar, Severin): compared buffer by buffer, and a pointer into one names its owner
BUF64, BUFPC = 45, 48
ORDEN64_A_PC = [1, 2, 3, 4, 0]
comunes = [n for n in comunes if n != "CHR_COMMAND_BUFFERS"]
# pointers: an address -> (name, offset) on each side (the innermost datum); the PC's functions by their 1000:XXXX,
# the 6502's by label
zpc = sorted((pcs[n], pcs[n] + max(tampc.get(n, 1), 1), n) for n in pcs)
z64 = sorted((c64[n], c64[n] + max(tam64.get(n, 1), 1), n) for n in c64)
fun_pc = {}
for f in glob.glob(os.path.join(PC, "src", "*.c")):
    for a, nom in re.findall(r"/\* 1000:([0-9A-F]{4}) (\w+)", open(f).read()): fun_pc.setdefault(int(a, 16), nom)
fun64 = {}
for l in open(os.path.join(juego, "juego.lbl")):
    x = l.split()
    if len(x) == 3: fun64.setdefault(int(x[1], 16), x[2].lstrip("."))
# the same datum under two names (the 64 KiB name -> the PC's)
IGUALES = {"ISO_BLOCK_DATA_1": "ISO_BLOCK_DATA", "AI_UNUSED_3CAD": "AI_UNUSED_C123"}
# the path searches' queue (the stack, growing down): from D64_PATH_QUEUE on the 6502, from 1800:EE8C on the PC
COLA_PC = 0xEE8C
def que(zonas, funs, v, es64):
    """the set of what v can name: a function, a command buffer (its owner, by the PC's order), every datum holding it"""
    s = set()
    if v in funs: s.add(("f", funs[v], 0))
    cb = c64["CHR_COMMAND_BUFFERS"] if es64 else pcs["CHR_COMMAND_BUFFERS"]
    tam = BUF64 if es64 else BUFPC
    if cb <= v < cb + 5 * tam:
        i = (v - cb) // tam
        s.add(("b", ORDEN64_A_PC[i] if es64 else i, (v - cb) % tam))
    for a0, a1, n in zonas:
        if a0 <= v < a1: s.add(("d", IGUALES.get(n, n) if es64 else n, v - a0))
    tope = c64["PATH_QUEUE"] if es64 else COLA_PC
    if tope - 0x600 <= v <= tope: s.add(("q", tope - v, 0))
    return s
# (the C128 dump: block 0, then block 1 from $1000: the data mapa64.py put there, zone banco1, and the names inside them)
TAM128 = 0x10000 + os.path.getsize(os.path.join(juego, "juego.bin.banco1"))
B1 = {c[0][4:] for c in (l.rstrip("\n").split("\t") for l in open(os.path.join(juego, "mapa64.tsv")))
      if len(c) > 6 and c[6] == "banco1" and c[0].startswith("D64_")}
for l in open(os.path.join(juego, "mapa64.inc")):
    m = re.match(r"D64_(\w+) = \$[0-9A-F]+\s+; CPC [0-9A-F]+h in D64_(\w+)", l)
    if m and m.group(2) in B1: B1.add(m.group(1))
n128 = os.path.getsize(f128) // TAM128; npc = os.path.getsize(fpc) // 0x10000
n = min(n128, npc)
f0, f1 = (int(x) for x in rango.split("-")) if rango else (1, n)
a, b = open(f128, "rb"), open(fpc, "rb")
primero, cuenta, ejemplo = {}, {}, {}
for fr in range(f0, min(f1, n) + 1):
    a.seek((fr - 1) * TAM128); m64 = a.read(TAM128)
    b.seek((fr - 1) * 0x10000); mpc = b.read(0x10000)
    for nom in comunes:
        k = min(tam64.get(nom, tampc.get(nom, 1)), tampc.get(nom, tam64.get(nom, 1)))
        if nom in B1: x = m64[0x10000 + c64[nom] - 0x1000:0x10000 + c64[nom] - 0x1000 + k]
        else: x = m64[c64[nom]:c64[nom] + k]
        y = mpc[pcs[nom]:pcs[nom] + k]
        if x == y: continue
        if nom in DESDE2 and fr == 1: continue
        if nom == "SPR_TABLE":                  # (each record's +7/+8: its graphic, the machine's address)
            x = bytes(0 if i % 20 in (7, 8) else c for i, c in enumerate(x))
            y = bytes(0 if i % 20 in (7, 8) else c for i, c in enumerate(y))
            if x == y: continue
        i, dif = 0, []
        while i < k:
            if x[i] == y[i]: i += 1; continue
            hecho = False
            for j in (i - 1, i):
                if 0 <= j and j + 1 < k:
                    q64 = que(z64, fun64, x[j] | x[j + 1] << 8, True); qpc = que(zpc, fun_pc, y[j] | y[j + 1] << 8, False)
                    if q64 & qpc: i = j + 2; hecho = True; break
            if not hecho: dif.append(i); i += 1
        if dif:
            primero.setdefault(nom, fr); cuenta[nom] = cuenta.get(nom, 0) + 1
            ejemplo.setdefault(nom, " ".join(f"+{d}:{x[d]:02X}/{y[d]:02X}" for d in dif[:8]))
    for i in range(5):                          # the command buffers, by owner
        nom = f"CHR_COMMAND_BUFFERS[{i}]"
        x = m64[c64["CHR_COMMAND_BUFFERS"] + BUF64 * i:][:BUF64]
        k = ORDEN64_A_PC[i]
        y = mpc[pcs["CHR_COMMAND_BUFFERS"] + BUFPC * k:][:BUF64]
        if x != y:
            primero.setdefault(nom, fr); cuenta[nom] = cuenta.get(nom, 0) + 1
            d = [q for q in range(BUF64) if x[q] != y[q]]
            ejemplo.setdefault(nom, " ".join(f"+{q}:{x[q]:02X}/{y[q]:02X}" for q in d[:8]))
print(f"frames {f0}-{min(f1, n)}: {len(comunes)} data compared ({len(IGNORA)} ignored); {len(primero)} differ")
for nom in sorted(primero, key=lambda n: (primero[n], n)):
    print(f"  {nom:32s} first frame {primero[nom]:5d}, {cuenta[nom]:5d} frames   {ejemplo[nom]}  (C128/PC)")
