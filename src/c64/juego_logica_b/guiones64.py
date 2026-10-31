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

"""The monks' scripts (Z80 51E7-60F2 of the CPC 64 KiB game) as bytecode for logica_b's 6502 VM
(logica_b.s, `logica_b_vm`): logica_b_guiones.s.

    guiones64.py            -> logica_b_guiones.s (next to this file; construye.sh assembles it)

The bytecode is the Z80 code of the scripts byte for byte, read from data/cpc64/juego/ram.bin with the
code / inline split of data/cpc64/particion64.bin; only the operands change:
  CF <expr>            RST 08h: test (the same expression bytes)
  D7 <var> <expr>      RST 10h: assignment
  E0/E1/E2 v n         RST 08h of `v n =` / `v n >` / `v n <` (v a variable, n a literal, 40h-prefixed or not)
  D6 v n               RST 10h of `v n` (a literal): the two commonest forms, shorter and without the evaluator;
                       never right after a CF/D7 expression, which ends at a Z80 opcode (ai_script_eval's rule)
  E4/E5/E6 v n e       E0/E1/E2 followed by JR NZ e (e from the next instruction)
  D5 v n               D6 followed by RET
  D8 v n w m           D6 v n followed by D6 w m
  D0 b / D1 b          CALL hud_say / hud_say_now with its inline byte b
  D2 / D3              CALL ai_guillermo_is_close / hud_obsequium_minus_2
  D4                   JP ai_stay (the short forms, like the fast ones, never right after a CF/D7 expression)
  a JP / JP NZ to bytecode within reach becomes JR / JR NZ
  20 e / 18 e          JR NZ / JR (e recomputed from labels: dead bytes are dropped)
  C2 nn                JP NZ (always to bytecode: nn = its 6502 label)
  C3 nn                JP to bytecode (nn = a label of this file)
  C3 k 00              JP to a native routine: a tail call through the VM's table (k = 6 ai_stay, 8
                       ai_next_state_on_arrival; the table: logica_b.s lb_tabla)
  CD nn                CALL a native routine (nn = its 6502 address: an .import or a routine of logica_b)
  CD k 00 [b]          CALL through the VM's table: k = 0 hud_say, 2 hud_say_now, 4 game_set_c004_inline,
                       each followed by its inline byte; k = 10 the switch (3A5D: the table of bytecode
                       labels follows, 0 ends it)
  C9                   RET
  3E n / AF            LD A,n / XOR A (the key tests)
A script function (an entry of traducidas_logica_b) is `JSR logica_b_vm` followed by its bytecode; a jump or
a switch entry to another function's code goes to its bytecode label (Lxxxx), a CALL to its 6502 entry, and
code that falls into the next function (the Z80's 5FDD past its table into 5FEE) gets a JR over that JSR.
Deterministic: the same output for the same ram.bin.
"""
import glob, os, re, sys

D = os.path.dirname(os.path.abspath(__file__))
P = os.path.dirname(os.path.dirname(D))
sys.path.insert(0, os.path.join(P, "..", "tools"))
from licencia import cabecera   # noqa: E402  (the GPL header of the generated sources)
ram = open(os.path.join(P, "..", "data", "cpc64", "juego", "ram.bin"), "rb").read()
part = open(os.path.join(P, "..", "data", "cpc64", "particion64.bin"), "rb").read()
J = os.path.join(P, "juego")

INICIO, FIN = 0x51E7, 0x60F3
FIN_EXPR = {0x20, 0xD7, 0xC2, 0xCD, 0xCF, 0xC9, 0xC3, 0x18}
OPERADORES = {0x3D: "=", 0x3E: ">=", 0x3C: "<", 0x2A: "and", 0x26: "or", 0x2B: "+", 0x2D: "-"}
TABLA_VM = {0x4B7C: 0, 0x4B71: 2, 0x3D07: 4, 0x39A8: 6, 0x39E5: 8, 0x3A5D: 10}   # logica_b_vm's table
CON_BYTE = {0x4B7C, 0x4B71, 0x3D07}

# the C names of the Z80 entries
nombres = {}
for f in sorted(glob.glob(os.path.join(J, "f_*.c"))) + [os.path.join(J, "funciones.c")]:
    for m in re.finditer(r'\{\s*0x([0-9A-Fa-f]{4})u?\s*,\s*"([^"]+)"', open(f).read()):
        nombres.setdefault(int(m.group(1), 16), m.group(2))
# the script functions of the group (traducidas_logica_b) in the range
entradas = {}
for m in re.finditer(r'\{\s*0x([0-9A-Fa-f]{4}),\s*"([^"]+)"', open(os.path.join(J, "f_logica_b.c")).read()):
    a = int(m.group(1), 16)
    if INICIO <= a < FIN: entradas[a] = m.group(2)
# the script variables: 80h + i -> the D64_ name of the address in the table 386Ah
d64 = {}
for f in sorted(glob.glob(os.path.join(J, "datos_*.h"))):
    for m in re.finditer(r"#define\s+(D64_\w+)\s+0x([0-9A-Fa-f]{4})u", open(f).read()):
        d64.setdefault(int(m.group(2), 16), m.group(1))
def var(op):
    a = ram[0x386A + 2 * (op - 0x80)] | ram[0x386A + 2 * (op - 0x80) + 1] << 8
    return d64.get(a, "%04Xh" % a)[4:].lower()

def expresion(a, primera):
    """the bytes of an expression at a (ai_script_eval's rule) and its rendering"""
    n, txt, op = 0, [], True
    while True:
        x = ram[a + n]
        if n and x in FIN_EXPR: return n, " ".join(txt)
        if n and x in OPERADORES: txt.append(OPERADORES[x]); n += 1; continue
        if x == 0x40: txt.append("%02Xh" % ram[a + n + 1]); n += 2
        elif x < 0x80: txt.append("%02Xh" % x); n += 1
        else:
            if not 0x80 <= x <= 0xC0: sys.exit("guiones64.py: %04X: variable %02X out of the table" % (a + n, x))
            txt.append("[" + var(x) + "]"); n += 1

# ---- pass 1: the instructions, the targets ----------------------------------------------------------
ins, destinos = [], set()
a = INICIO
while a < FIN:
    if part[a] != 1 and a != 0x5A74:       # 5A74: the RET after 3A5D's table (part 0: never run, but reachable)
        a += 1; continue
    o = ram[a]
    if o == 0xCF:
        n, t = expresion(a + 1, True); ins.append((a, "test", ram[a + 1:a + 1 + n], t)); a += 1 + n
    elif o == 0xD7:
        n, t = expresion(a + 2, True)
        ins.append((a, "set", ram[a + 1:a + 2 + n], "[%s] := %s" % (var(ram[a + 1]), t))); a += 2 + n
    elif o in (0x20, 0x18):
        d = (a + 2 + (ram[a + 1] ^ 0x80) - 0x80) & 0xFFFF; destinos.add(d)
        ins.append((a, "jrnz" if o == 0x20 else "jr", d, "")); a += 2
    elif o in (0xC2, 0xC3, 0xCD):
        d = ram[a + 1] | ram[a + 2] << 8
        if o == 0xCD and d == 0x3A5D:
            tabla, k = [], a + 3
            while ram[k] | ram[k + 1] << 8:
                tabla.append(ram[k] | ram[k + 1] << 8); k += 2
            destinos.update(tabla)
            ins.append((a, "switch", tabla, "")); a = k + 2
        elif o == 0xCD and d in CON_BYTE:
            ins.append((a, "callb", d, ram[a + 3])); a += 4
        else:
            if INICIO <= d < FIN and not (o == 0xCD): destinos.add(d)
            ins.append((a, {0xC2: "jpnz", 0xC3: "jp", 0xCD: "call"}[o], d, "")); a += 3
    elif o == 0xC9: ins.append((a, "ret", None, "")); a += 1
    elif o == 0x3E: ins.append((a, "lda", ram[a + 1], "")); a += 2
    elif o == 0xAF: ins.append((a, "xora", None, "")); a += 1
    else: sys.exit("guiones64.py: %04X: opcode %02X not in the VM" % (a, o))

def etiqueta(d):
    return "L%04X" % d
def nativo(d):
    if INICIO <= d < FIN:
        if d not in entradas: sys.exit("guiones64.py: CALL %04X: not a function of the group" % d)
        return entradas[d]
    if d not in nombres: sys.exit("guiones64.py: %04X: no C name" % d)
    return nombres[d]

# the byte after every expression must end it (the bytecode keeps the Z80 opcodes)
for i, (a, k, x, t) in enumerate(ins):
    if k in ("test", "set") and i + 1 < len(ins):  # (in the Z80 code: the fast forms below keep it)
        sig = ram[ins[i + 1][0]]
        if sig not in FIN_EXPR: sys.exit("guiones64.py: %04X: the expression is followed by %02X" % (a, sig))

# ---- the fast forms: a test of a variable against a literal, the assignment of a literal --------------
OPS = set(OPERADORES)
def rapida(k, x):
    """(opcode, v, n) when the test / assignment has a fast form, else None"""
    if k == "test":
        if len(x) == 3 and x[0] >= 0x80 and x[1] < 0x40 and x[1] not in FIN_EXPR | OPS and x[2] in (0x3D, 0x3E, 0x3C):
            return ({0x3D: 0xE0, 0x3E: 0xE1, 0x3C: 0xE2}[x[2]], x[0], x[1])
        if len(x) == 4 and x[0] >= 0x80 and x[1] == 0x40 and x[3] in (0x3D, 0x3E, 0x3C):
            return ({0x3D: 0xE0, 0x3E: 0xE1, 0x3C: 0xE2}[x[3]], x[0], x[2])
    if k == "set":
        if len(x) == 2 and x[1] < 0x80 and x[1] != 0x40: return (0xD6, x[0], x[1])
        if len(x) == 3 and x[1] == 0x40: return (0xD6, x[0], x[2])
    return None
generica_antes = False                       # the previous instruction ends with a CF/D7 expression
for i, (a, k, x, t) in enumerate(ins):
    r = rapida(k, x) if k in ("test", "set") else None
    if r and generica_antes: r = None
    ins[i] = (a, k, x, t, r)
    generica_antes = k in ("test", "set") and r is None

# ---- pass 2: the bytecode items, their sizes, the short jumps ---------------------------------------
CORTO = {0x4B7C: 0xD0, 0x4B71: 0xD1, 0x39AE: 0xD2, 0x5124: 0xD3}    # D0 b, D1 b, D2, D3; D4 = JP ai_stay
# the fast forms merged with the JR NZ / RET that follows them (when that is no jump's target)
fusion = set()
for i in range(len(ins) - 1):
    a, k, x, t, r = ins[i]
    sig = ins[i + 1]
    if r and sig[0] not in destinos and sig[0] not in entradas:
        if k == "test" and sig[1] == "jrnz": fusion.add(i)
        if k == "set" and sig[1] == "ret": fusion.add(i)
omite = {i + 1 for i in fusion}
items = []                                   # [Z80 address, kind, size, data]
generica_antes = False
for i, (a, k, x, t, r) in enumerate(ins):
    if i in omite: continue
    corto = not generica_antes
    if i in fusion: it = [a, "testj" if k == "test" else "setret", 4 if k == "test" else 3, (r, ins[i + 1][2], t)]
    elif r: it = [a, "rapida", 3, (r, t)]
    elif k == "test" or k == "set": it = [a, k, 1 + len(x), (x, t)]
    elif k in ("jrnz", "jr"): it = [a, k, 2, x]
    elif k in ("jpnz", "jp") and INICIO <= x < FIN: it = [a, k, 3, x]          # JR / JR NZ when in range
    elif k == "jp":
        if x not in (0x39A8, 0x39E5): sys.exit("guiones64.py: %04X: JP %04X not in the VM's table" % (a, x))
        it = [a, "jpn", 1 if x == 0x39A8 and corto else 3, x]
    elif k == "call": it = [a, "call", 1 if x in CORTO and corto else 3, x]
    elif k == "callb": it = [a, "callb", 2 if x in CORTO and corto else 4, (x, t)]
    elif k == "switch": it = [a, "switch", 3 + 2 * (len(x) + 1), x]
    elif k == "ret": it = [a, "ret", 1, None]
    elif k == "lda": it = [a, "lda", 2, x]
    elif k == "xora": it = [a, "xora", 1, None]
    else: sys.exit("guiones64.py: %s" % k)
    items.append(it)
    generica_antes = k in ("test", "set") and not r and i not in fusion
# two assignments of literals in a row (the second no jump's target): D8 v n v n
k = 0
while k < len(items) - 1:
    p, q = items[k], items[k + 1]
    if p[1] == "rapida" and q[1] == "rapida" and p[3][0][0] == 0xD6 and q[3][0][0] == 0xD6 \
       and q[0] not in destinos and q[0] not in entradas:
        items[k] = [p[0], "set2", 5, (p[3], q[3])]
        del items[k + 1]
    k += 1
# the code that falls into the next script function (5FDD: past its switch table, the code after it is 5FEE):
# a JR over the function's JSR logica_b_vm, to its bytecode
CAE = {"ret", "jp", "jpn", "setret", "jr"}                  # the kinds that never go on to the next item
k = 0
while k < len(items) - 1:
    if items[k + 1][0] in entradas and items[k][1] not in CAE:
        items.insert(k + 1, [("cae", items[k + 1][0]), "jr", 2, items[k + 1][0]])
        k += 1
    k += 1
def direcciones():
    d, pos = {}, 0
    for it in items:
        if it[0] in entradas: pos += 3
        d[it[0]] = pos
        pos += it[2]
    return d, pos
while True:                                  # the long JP / JP NZ that reach as JR / JR NZ (sizes only shrink)
    d, total = direcciones()
    cambia = False
    for it in items:
        if it[1] in ("jp", "jpnz") and it[2] == 3 and -128 <= d[it[3]] - (d[it[0]] + 2) <= 127:
            it[2] = 2; cambia = True
    if not cambia: break

# ---- pass 3: the source ---------------------------------------------------------------------------
importa = set()
L = ["; generated by guiones64.py from the Z80 scripts 51E7-60F2 (data/cpc64/juego/ram.bin): do not edit;",
     "; logica_b_vm's bytecode (the format: guiones64.py, logica_b.s).  Lxxxx = the Z80 address of the instruction.", "",
     "; JR NZ / JR: the displacement from the next instruction, as on the Z80",
     ".macro JRNZ destino", "        .local aqui", "aqui:   .byte   $20, <(destino - aqui - 2)",
     "        .assert destino - aqui - 2 >= -128 && destino - aqui - 2 <= 127, error, \"JR NZ out of range\"",
     ".endmacro", ".macro JR destino", "        .local aqui", "aqui:   .byte   $18, <(destino - aqui - 2)",
     "        .assert destino - aqui - 2 >= -128 && destino - aqui - 2 <= 127, error, \"JR out of range\"",
     ".endmacro", "; E4/E5/E6 v n e: a fast test and JR NZ (e from the next instruction)",
     ".macro TESTJ op, v, n, destino", "        .local aqui", "aqui:   .byte   op, v, n, <(destino - aqui - 4)",
     "        .assert destino - aqui - 4 >= -128 && destino - aqui - 4 <= 127, error, \"JR NZ out of range\"",
     ".endmacro", "", ".segment \"CODE\""]
for a, k, n, x in items:
    if a in entradas:
        L += ["", "; %04X %s" % (a, entradas[a]), entradas[a] + ":", "        jsr     logica_b_vm"]
    if a in destinos or a in entradas: L.append(etiqueta(a) + ":")
    if k == "testj":
        r, dest, t = x
        L.append("        TESTJ   $%02X, $%02X, $%02X, %s  ; %s / JR NZ" % (r[0] + 4, r[1], r[2], etiqueta(dest), t))
    elif k == "setret": L.append("        .byte   $D5, $%02X, $%02X  ; %s / RET" % (x[0][1], x[0][2], x[2]))
    elif k == "set2":
        (r1, t1), (r2, t2) = x
        L.append("        .byte   $D8, $%02X, $%02X, $%02X, $%02X  ; %s / %s" % (r1[1], r1[2], r2[1], r2[2], t1, t2))
    elif k == "rapida": L.append("        .byte   $%02X, $%02X, $%02X  ; %s" % (x[0][0], x[0][1], x[0][2], x[1]))
    elif k == "test": L.append("        .byte   $CF, %s  ; %s" % (", ".join("$%02X" % b for b in x[0]), x[1]))
    elif k == "set": L.append("        .byte   $D7, %s  ; %s" % (", ".join("$%02X" % b for b in x[0]), x[1]))
    elif k in ("jrnz", "jr") or (k in ("jpnz", "jp") and n == 2):
        L.append("        %s    %s" % ("JRNZ" if k in ("jrnz", "jpnz") else "JR  ", etiqueta(x)))
    elif k == "jpnz": L.append("        .byte   $C2\n        .word   %s" % etiqueta(x))
    elif k == "jp": L.append("        .byte   $C3\n        .word   %s" % etiqueta(x))
    elif k == "jpn":
        if n == 1: L.append("        .byte   $D4  ; JP ai_stay")
        else: L.append("        .byte   $C3, %d, 0  ; JP %s" % (TABLA_VM[x], nombres[x]))
    elif k == "call":
        if n == 1: L.append("        .byte   $%02X  ; CALL %s" % (CORTO[x], nativo(x)))
        else:
            if not INICIO <= x < FIN: importa.add(nativo(x))  # (the group's own natives are exported by logica_b.s)
            L.append("        .byte   $CD\n        .word   %s" % nativo(x))
    elif k == "callb":
        if n == 2: L.append("        .byte   $%02X, $%02X  ; %s" % (CORTO[x[0]], x[1], nombres[x[0]]))
        else: L.append("        .byte   $CD, %d, 0, $%02X  ; %s" % (TABLA_VM[x[0]], x[1], nombres[x[0]]))
    elif k == "switch":
        L.append("        .byte   $CD, %d, 0  ; util_jump_table_inline" % TABLA_VM[0x3A5D])
        L.append("        .word   %s, 0" % ", ".join(etiqueta(dd) for dd in x))
    elif k == "ret": L.append("        .byte   $C9")
    elif k == "lda": L.append("        .byte   $3E, $%02X" % x)
    elif k == "xora": L.append("        .byte   $AF")
cab = ["        .export " + ", ".join(entradas[a] for a in sorted(entradas)) + ", lb_orient_guillermo, lb_orient_abbot",
       "        .import logica_b_vm, " + ", ".join(sorted(importa))]
# obj_drop_object 4E4B-4E53 reads the dropped object's orientation at (height << 8) | the low byte of the CPC
# address of the holder's character orientation (2B88h Guillermo, 2BB5h the abbot: the only holders that drop,
# 4DC3 and 3C0F): the bytes of the tape image there (heights 1 and 2 fall in the initial-state copy and the
# room links, which change: logica_b.s reads those from the C64 blocks)
L += ["", "; obj_drop_object's orientation quirk: the CPC bytes at (height << 8) | 88h (Guillermo) and | B5h (the",
      "; abbot), heights 00h-23h (01h, 02h: read from D64_GAME_INITIAL_STATE / D64_CHR_ROOM_LINKS instead)",
      ".segment \"RODATA\""]
for n, b in (("lb_orient_guillermo", 0x88), ("lb_orient_abbot", 0xB5)):
    v = [ram[h << 8 | b] for h in range(0x24)]
    L.append(n + ":")
    for k in range(0, 0x24, 12): L.append("        .byte   " + ", ".join("$%02X" % x for x in v[k:k + 12]))
L.append(".segment \"CODE\"")
open(os.path.join(D, "logica_b_guiones.s"), "w").write(cabecera("asm") + "\n".join(L[:3] + cab + L[3:]) + "\n")
print("%d instructions, %d functions, %d imports, %d bytes" % (len(ins), len(entradas), len(importa), total))
