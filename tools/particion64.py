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

"""The CPC 64 KiB game's memory split into Z80 code, data inline in the code, and the rest (data or
unused), by a recursive descent of the Z80 code of data/cpc64/juego/ram.bin (the tape's image at the
game's start).  Input of the C64 data inventory (src/c64/NOTAS_MAPA.md).

    particion64.py            -> data/cpc64/particion64.tsv (ranges) and particion64.bin (a byte per
                                 address: 0 not code, 1 instruction byte, 2 inline data of the code)

Seeds: the function entries (data/cpc64/funciones64.tsv and the tables of src/juego/f_*.c), the instruction starts executed in the
exploration sessions and the start-up (exploracion/cobertura_total.txt, inicio_juego/cobertura.txt from
0400h: below it that run executed the tape loader), the game's start 20BEh, and
the code pointers kept in data tables (below).  The routines that read inline data after their CALL
(RST 08h/10h expressions, 1E6E CRTC pairs, 3A5D jump table, 3C84/3BE6 records, 3D07, 4B71, 4B7C, 5129
bytes, 4B44 text) are followed with their own rule.  Self-modified opcodes that can be RET or NOP are
taken as NOP so the code after them is reached.
"""
import os, sys

P = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
C = os.path.join(P, "data", "cpc64")
m = open(os.path.join(C, "juego", "ram.bin"), "rb").read()
def b(a): return m[a & 0xFFFF]
def w(a): return b(a) | b(a + 1) << 8

# ---- Z80 instruction length -------------------------------------------------------------------------
L2 = {0x06, 0x0E, 0x16, 0x1E, 0x26, 0x2E, 0x36, 0x3E, 0xC6, 0xCE, 0xD6, 0xDE, 0xE6, 0xEE, 0xF6, 0xFE,
      0x10, 0x18, 0x20, 0x28, 0x30, 0x38, 0xD3, 0xDB, 0xCB}
L3 = {0x01, 0x11, 0x21, 0x31, 0x22, 0x2A, 0x32, 0x3A, 0xC2, 0xCA, 0xD2, 0xDA, 0xE2, 0xEA, 0xF2, 0xFA,
      0xC3, 0xC4, 0xCC, 0xD4, 0xDC, 0xE4, 0xEC, 0xF4, 0xFC, 0xCD}
HLMEM = {0x34, 0x35, 0x36, 0x46, 0x4E, 0x56, 0x5E, 0x66, 0x6E, 0x7E, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75,
         0x77, 0x86, 0x8E, 0x96, 0x9E, 0xA6, 0xAE, 0xB6, 0xBE}

def longitud(a):
    o = b(a)
    if o == 0xCB: return 2
    if o == 0xED:
        return 4 if b(a + 1) in (0x43, 0x4B, 0x53, 0x5B, 0x63, 0x6B, 0x73, 0x7B) else 2
    if o in (0xDD, 0xFD):
        o2 = b(a + 1)
        if o2 == 0xCB: return 4
        if o2 in (0xDD, 0xFD, 0xED): return 1          # a lone prefix
        n = 1 + (3 if o2 in L3 else 2 if o2 in L2 else 1)
        if o2 in HLMEM: n += 1
        return n
    return 3 if o in L3 else 2 if o in L2 else 1

# ---- the routines with inline data after their CALL: (bytes of inline data, falls through after it) --
FIN_EXPR = {0x20, 0xD7, 0xC2, 0xCD, 0xCF, 0xC9, 0xC3, 0x18}
def expresion(a):
    """the length of a script expression at a (ai_script_eval: operands 40h nn / literal / variable,
    operators; ends before a terminator byte)"""
    n = 0
    while True:
        x = b(a + n)
        if n and x in FIN_EXPR: return n
        if x == 0x40: n += 2
        else: n += 1
        if n > 64 or a + n > 0x6100: return None             # not an expression: dead bytes

def hasta_ff(a, paso=1):
    n = 0
    while b(a + n) != 0xFF: n += paso
    return n + 1

def tabla_3a5d(a):
    n = 0
    while w(a + n): n += 2
    return n + 2

INLINE = {
    0x1E6E: lambda a: (hasta_ff(a, 2), True),           # CRTC (register, value) pairs, FFh
    0x3A5D: lambda a: (tabla_3a5d(a), False),            # dw targets ..., 0000: JP to one of them
    0x3C84: lambda a: (7, False),                        # dw record, 5 bytes: returns to the caller's caller
    0x3BE6: lambda a: (7, False),                        # the same through JP 3C84
    0x3D07: lambda a: (1, True),
    0x4B71: lambda a: (1, True),
    0x4B7C: lambda a: (1, True),
    0x5129: lambda a: (1, True),
    0x4B44: lambda a: (hasta_ff(a), True),               # text up to FFh
}

# self-modified opcodes (RET or NOP, ...): every form is followed
SMC_RET = {0x2684, 0x09D4, 0x40C2, 0x491B}

tipo = bytearray(0x10000)                                 # 1 instruction, 2 inline data
destinos_inline = set()
pendientes = []
def semilla(a):
    if 0 <= a < 0x10000: pendientes.append(a)

for l in open(os.path.join(C, "funciones64.tsv")):
    if l[0] in "#a": continue
    semilla(int(l.split("\t")[0], 16))
for f in ("exploracion/cobertura_total.txt", "inicio_juego/cobertura.txt"):
    for l in open(os.path.join(C, f)):
        if not l.strip() or l.startswith("#"): continue     # (my licence header)
        a = int(l.split()[0], 16)
        # the start-up run also covers the tape loader (0100h-03FFh, gone once the game is loaded)
        if f.startswith("inicio") and a < 0x0400: continue
        semilla(a)
import glob, re
for f in glob.glob(os.path.join(P, "src", "juego", "f_*.c")):   # the functions the C translation knows
    for x in re.findall(r'\{ 0x([0-9A-F]{4}), "\w+"', open(f).read()): semilla(int(x, 16))
semilla(0x20BE)                      # the game's start (JP 0200h -> 20BEh)
for a in (0x12C2, 0x4FC9): semilla(a)   # entered through self-modified jumps (12C0h, chr_cur_flip)

# code pointers kept in data (read from the image: tables whose words are routine addresses)
TABLAS_CODIGO = []
def tabla(a, n, paso=2, off=0):
    for i in range(n):
        x = w(a + i * paso + off); TABLAS_CODIGO.append((a + i * paso + off, x)); semilla(x)
tabla(0x1BEE, 28)                    # the block interpreter's handlers
tabla(0x0F76, 6, 3, 1)               # the sound sequence commands (byte, handler word)
tabla(0x08FA, 4, 4, 0)               # the path exits (routine word, grid target word)
tabla(0x1E81, 4)                     # the camera rotations
for e in range(6):                   # chr_table entries: behaviour +4, flip +6
    tabla(0x2703 + 10 * e + 4, 1); tabla(0x2703 + 10 * e + 6, 1)

def marca(a, n, t):
    for k in range(n):
        if tipo[(a + k) & 0xFFFF] == 0: tipo[(a + k) & 0xFFFF] = t

visto = set()
while pendientes:
    a = pendientes.pop()
    while 0 <= a < 0x10000 and a not in visto:
        if a >= 0x6100: break                             # no code from the room table (6100h) up
        visto.add(a)
        o = b(a); n = longitud(a)
        marca(a, n, 1)
        sig = a + n
        if a in SMC_RET:                                  # RET or NOP: both forms
            a = sig; continue
        if o in (0xC3,):                                  # JP nn
            a = w(a + 1); continue
        if o == 0x18:                                     # JR e
            a = (sig + (b(a + 1) ^ 0x80) - 0x80) & 0xFFFF; continue
        if o in (0x20, 0x28, 0x30, 0x38, 0x10):
            semilla((sig + (b(a + 1) ^ 0x80) - 0x80) & 0xFFFF); a = sig; continue
        if o in (0xC2, 0xCA, 0xD2, 0xDA, 0xE2, 0xEA, 0xF2, 0xFA):
            semilla(w(a + 1)); a = sig; continue
        if o in (0xCD, 0xC4, 0xCC, 0xD4, 0xDC, 0xE4, 0xEC, 0xF4, 0xFC):
            t = w(a + 1); semilla(t)
            if t in INLINE:
                k, sigue = INLINE[t](sig)
                marca(sig, k, 2)
                if t == 0x3A5D:
                    for i in range(0, k - 2, 2): semilla(w(sig + i)); destinos_inline.add(w(sig + i))
                if not sigue or o != 0xCD:
                    if o != 0xCD: semilla(sig + k)            # conditional: both
                    break
                a = sig + k; continue
            a = sig; continue
        if o in (0xC9,): break                            # RET
        if o == 0xED and b(a + 1) in (0x45, 0x4D): break  # RETN, RETI
        if o == 0xE9 or (o in (0xDD, 0xFD) and b(a + 1) == 0xE9): break   # JP (HL)/(IX)/(IY)
        if o == 0xCF:                                     # RST 08h <expr>
            k = expresion(sig)
            if k is None: break
            marca(sig, k, 2); a = sig + k; continue
        if o == 0xD7:                                     # RST 10h <var> <expr>
            k = expresion(sig + 1)
            if k is None: break
            marca(sig, k + 1, 2); a = sig + k + 1; continue
        a = sig

# ---- output ---------------------------------------------------------------------------------------
open(os.path.join(C, "particion64.bin"), "wb").write(bytes(tipo))
out = ["# the CPC 64K memory split (particion64.py): start, end (inclusive), length, kind",
       "# kind: code = Z80 instructions; inline = data inline in the code (script expressions, inline call data); rest = data or unused"]
nombre = {0: "rest", 1: "code", 2: "inline"}
a = 0
tot = {0: 0, 1: 0, 2: 0}
while a < 0x10000:
    t = tipo[a]; e = a
    while e + 1 < 0x10000 and tipo[e + 1] == t: e += 1
    out.append(f"{a:04X}\t{e:04X}\t{e - a + 1}\t{nombre[t]}")
    if a < 0x6100: tot[t] += min(e, 0x60FF) - a + 1
    a = e + 1
open(os.path.join(C, "particion64.tsv"), "w").write("\n".join(out) + "\n")
print(f"0000-60FF: code {tot[1]}, inline {tot[2]}, rest {tot[0]} bytes; code pointers in tables {len(TABLAS_CODIGO)}, "
      f"3A5D targets {len(destinos_inline)}")
