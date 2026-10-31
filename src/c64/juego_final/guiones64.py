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

The bytecode is the Z80 code of the scripts, read from data/cpc64/juego/ram.bin with the code / inline split
of data/cpc64/particion64.bin, with 6502 operands and shorter forms for the common cases (v below and the
D7's variable: 2 x the variable's number mod 256, the offset of its word in the table 386Ah):
  CF <expr>            RST 08h: test (the same expression bytes; only for the expressions no chain below makes)
  D7 v <expr>          RST 10h: assignment (the same)
  D8 v n               RST 10h of `v n` (a literal), without the evaluator; like every form below that is not a
                       Z80 opcode, never right after a CF/D7 expression, which ends at a Z80 opcode (ai_script_eval's
                       rule)
  D9 v n               D8 followed by RET
  DA v n w m           D8 v n followed by D8 w m
  DB/DC/DD/DE v n      RST 10h of `v v n 26h/2Bh/2Ah/2Dh`: [v] := [v] OR / + / AND / - n
  D0 b / D1 b          CALL hud_say / hud_say_now with its inline byte b
  D2 / D3              CALL ai_guillermo_is_close / hud_obsequium_minus_2
  D4                   JP ai_stay
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
  3E n / 01            LD A,n / XOR A (the key tests)
An RST 08h whose expression is a comparison or a tree of them becomes a chain of tests, each with its jump e
(from the next instruction); every test leaves A = C = its value (00h true, FFh false) and the flags of AND A,
so the one that decides leaves the whole expression's:
  F8+p a n e           `v n =`, the jump when false (v at the C64 address p * 256 + a, p 0-7: the table 386Ah is
                       constant, so this reads the byte the evaluator reads)
  E2 v n e             `v n =`, the jump when true
  E3 / E4 v n e        `v n >` (v >= n), the jump when false / true   E5 / E6 v n e   `v n <`
  E7 / E8 v w e        `v w =` (two variables)                        E9 / EA v m n e  `v m * n =` (v AND m = n)
  EB v e / EC v m e    [v] / [v] AND m, any value, the jump when it is not 0 (only as the last test)
  F0+p, A8+p, A0+p, B0+p a n e  F8+p, E2, E3, E5 that leave A, C and the flags as they were: the code after them
                       sets those before reading them, whichever way they go (the variable as in F8+p)
A tree joined by 26h (the OR of 00h/FFh values: true when both are) and 2Ah (the AND: true when either is) is
compiled with short-circuit jumps (both commute: a value EB / EC goes last); the JR NZ or JP NZ after the RST
gives the jump when false (dropped unless it is a jump's target), else (or when a jump does not reach) the chain
ends at the next instruction.
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
ram = open(os.environ.get("C64_RAM", os.path.join(P, "..", "data", "cpc64", "juego", "ram.bin")), "rb").read()
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

# the C64 address of a script variable as a symbol of mapa64.inc: the table 386Ah is constant, so the tests that
# take their variable's address from the bytecode (F0-FF) read the same byte as the evaluator
bloques = []
for l in open(os.path.join(D, "mapa64.tsv")):
    t = l.rstrip("\n").split("\t")
    if len(t) >= 6 and t[0].startswith("D64_") and t[5] == "copia" and t[2] == t[4]:
        bloques.append((t[0], int(t[1], 16), int(t[2])))
def var_c64(v2):
    """the symbol of the variable at offset v2 of the table (2 x its number mod 256)"""
    a = ram[0x386A + v2] | ram[0x386A + v2 + 1] << 8
    for n, ini, lon in bloques:
        if ini <= a < ini + lon: return "%s+%d" % (n, a - ini) if a > ini else n
    sys.exit("guiones64.py: variable %02X (%04X): no block of mapa64.tsv" % (v2 // 2 + 0x80, a))

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

# ---- the fast forms: a test made of comparisons (a chain of tests), the assignment of a literal --------
OPS = set(OPERADORES)
def arbol(x):
    """the expression bytes x as a tree, as ai_script_eval reads them: ('L', n), ('V', v), (operator, e, c)"""
    st, n = [], 0
    while n < len(x):
        b = x[n]
        if n and b in OPS:
            if len(st) < 2: return None
            c = st.pop(); e = st.pop(); st.append((b, e, c)); n += 1
        elif b == 0x40: st.append(("L", x[n + 1])); n += 2
        elif b < 0x80: st.append(("L", b)); n += 1
        else: st.append(("V", b)); n += 1
    return st[0] if len(st) == 1 else None
def hoja(nd):
    """a comparison the VM tests directly: (opcode for "jump when false", operand bytes), else None"""
    if nd[0] in (0x3D, 0x3E, 0x3C) and nd[1][0] == "V" and nd[2][0] == "L":
        return ({0x3D: 0xE1, 0x3E: 0xE3, 0x3C: 0xE5}[nd[0]], [2 * nd[1][1] & 0xFF, nd[2][1]])
    if nd[0] == 0x3D and nd[1][0] == "V" and nd[2][0] == "V":
        return (0xE7, [2 * nd[1][1] & 0xFF, 2 * nd[2][1] & 0xFF])
    if nd[0] == 0x3D and nd[1][0] == 0x2A and nd[1][1][0] == "V" and nd[1][2][0] == "L" and nd[2][0] == "L":
        return (0xE9, [2 * nd[1][1][1] & 0xFF, nd[1][2][1], nd[2][1]])
    return None
def valor(nd):
    """a value the VM tests directly as the last test of a chain (its value is the expression's): [v] (EB) or
    [v] AND m (EC)"""
    if nd[0] == "V": return (0xEB, [2 * nd[1] & 0xFF])
    if nd[0] == 0x2A and nd[1][0] == "V" and nd[2][0] == "L": return (0xEC, [2 * nd[1][1] & 0xFF, nd[2][1]])
    return None
def booleano(nd):
    """a tree of comparisons joined by 26h (OR of 00h/FFh values: true when both are) and 2Ah (AND: true when
    either is)"""
    if nd is None or nd[0] in ("L", "V"): return False
    if hoja(nd): return True
    return nd[0] in (0x26, 0x2A) and booleano(nd[1]) and booleano(nd[2])
def ordena(nd):
    """26h and 2Ah commute, and reading the variables changes nothing: a value that is not 00h/FFh goes to the
    right of a comparison, where it can be the chain's last test"""
    if nd is None or nd[0] in ("L", "V") or nd[0] not in (0x26, 0x2A): return nd
    e, c = ordena(nd[1]), ordena(nd[2])
    if not booleano(e) and booleano(c): e, c = c, e
    return (nd[0], e, c)
def encadenable(nd):
    """a boolean tree, or one whose last value (the rightmost, reached when every test before it leaves the
    result open) is any value of valor(): 00h OR x = x, FFh AND x = x"""
    if nd is None: return False
    if booleano(nd) or valor(nd): return True
    return nd[0] in (0x26, 0x2A) and booleano(nd[1]) and encadenable(nd[2])
def cadena(nd, si, no, sigue, marcas, pref):
    """the tests of tree nd that go to label si when it is true (00h), to no when false (FFh); the code after
    them is label sigue (si or no).  Each test leaves A, C and the flags of its value, so the one that decides
    leaves the whole expression's: [("hoja", opcode, operands, label)] and [("marca", label)]"""
    h = hoja(nd)
    if h:
        if sigue == si: return [("hoja", h[0], h[1], no)]              # jump when false
        return [("hoja", h[0] + 1, h[1], si)]                           # jump when true
    h = valor(nd)
    if h:                                                               # (the last one: falls into si)
        assert sigue == si
        return [("hoja", h[0], h[1], no)]                               # jump when not 0
    m = "M%s_%d" % (pref, len(marcas)); marcas.append(m)
    if nd[0] == 0x26: izq = cadena(nd[1], m, no, m, marcas, pref)    # both true
    else: izq = cadena(nd[1], si, m, m, marcas, pref)                  # either true
    return izq + [("marca", m)] + cadena(nd[2], si, no, sigue, marcas, pref)
def rapida_set(x):
    """(opcode, v, n): D8 [v] := n; DB / DC / DD / DE [v] := [v] OR / + / AND / - n"""
    if len(x) == 2 and x[1] < 0x80 and x[1] != 0x40: return (0xD8, 2 * x[0] & 0xFF, x[1])
    if len(x) == 3 and x[1] == 0x40: return (0xD8, 2 * x[0] & 0xFF, x[2])
    nd = arbol(x[1:])
    if nd and nd[0] in (0x26, 0x2B, 0x2A, 0x2D) and nd[1] == ("V", x[0]) and nd[2][0] == "L":
        return ({0x26: 0xDB, 0x2B: 0xDC, 0x2A: 0xDD, 0x2D: 0xDE}[nd[0]], 2 * x[0] & 0xFF, nd[2][1])
    return None
def formas(sin_cadena):
    """each instruction with its fast form: "cadena" (a chain of tests), (D8, v, n) or None (the generic CF / D7,
    and the instruction after one keeps its long form too: the expression ends at a Z80 opcode)"""
    generica_antes = False
    for i, (a, k, x, t) in enumerate(ins0):
        r = None
        if not generica_antes:
            if k == "test" and sin_cadena.get(a, 0) < 2 and encadenable(ordena(arbol(x))): r = "cadena"
            if k == "set": r = rapida_set(x)
        ins[i] = (a, k, x, t, r)
        generica_antes = k in ("test", "set") and r is None
ins0 = list(ins)

# ---- pass 2: the bytecode items, their sizes, the short jumps ---------------------------------------
CORTO = {0x4B7C: 0xD0, 0x4B71: 0xD1, 0x39AE: 0xD2, 0x5124: 0xD3}    # D0 b, D1 b, D2, D3; D4 = JP ai_stay
def construye(sin_cadena):
    """the items [address, kind, size, data]; sin_cadena: the tests whose chain does not take the jump after it
    (1) or that stay CF expressions (2)"""
    global items
    formas(sin_cadena)
    # a chain of tests takes the JR NZ that follows it (a JR NZ that is a jump's target stays: the chain jumps
    # where it goes and falls into it when true); the assignment of a literal merges with a RET after it
    omite, setret, cad = set(), set(), {}
    for i, (a, k, x, t, r) in enumerate(ins):
        if k == "test" and r:
            sig = ins[i + 1]
            libre = sig[0] not in destinos and sig[0] not in entradas
            fin = "T%04X" % a
            if (sig[1] == "jrnz" or sig[1] == "jpnz" and INICIO <= sig[2] < FIN) and a not in sin_cadena:
                cad[i] = (cadena(ordena(arbol(x)), fin, etiqueta(sig[2]), fin, [], "%04X" % a), fin, i + 1)
                if libre: omite.add(i + 1)
            else: cad[i] = (cadena(ordena(arbol(x)), fin, fin, fin, [], "%04X" % a), fin, i)
        if k == "set" and r and r[0] == 0xD8 and ins[i + 1][1] == "ret" and ins[i + 1][0] not in destinos | set(entradas):
            setret.add(i); omite.add(i + 1)
    items = []
    generica_antes = False
    finales = {}                             # instruction index -> the chain's end label placed after it
    for i, (a, k, x, t, r) in enumerate(ins):
        if i not in omite:
            corto = not generica_antes
            if i in cad:
                hs, fin, tras = cad[i]
                marcas = {}
                for n, h in enumerate(hs):
                    if h[0] == "marca": items.append([("m", a, h[1]), "marca", 0, h[1]])
                    else: items.append([a if n == 0 else ("h", a, n), "hoja", 2 + len(h[2]), (h[1], h[2], h[3], t)])
                finales[tras] = fin
            elif i in setret: items.append([a, "setret", 3, (r, t)])
            elif r: items.append([a, "rapida", 3, (r, t)])
            elif k == "test" or k == "set": items.append([a, k, 1 + len(x), (x, t)])
            elif k in ("jrnz", "jr"): items.append([a, k, 2, x])
            elif k in ("jpnz", "jp") and INICIO <= x < FIN: items.append([a, k, 3, x])  # JR / JR NZ when in range
            elif k == "jp":
                if x not in (0x39A8, 0x39E5): sys.exit("guiones64.py: %04X: JP %04X not in the VM's table" % (a, x))
                items.append([a, "jpn", 1 if x == 0x39A8 and corto else 3, x])
            elif k == "call": items.append([a, "call", 1 if x in CORTO and corto else 3, x])
            elif k == "callb": items.append([a, "callb", 2 if x in CORTO and corto else 4, (x, t)])
            elif k == "switch": items.append([a, "switch", 3 + 2 * (len(x) + 1), x])
            elif k == "ret": items.append([a, "ret", 1, None])
            elif k == "lda": items.append([a, "lda", 2, x])
            elif k == "xora": items.append([a, "xora", 1, None])
            else: sys.exit("guiones64.py: %s" % k)
        if i in finales: items.append([("m", a, finales[i]), "marca", 0, finales[i]])
        generica_antes = k in ("test", "set") and not r and i not in omite
    # two assignments of literals in a row (the second no jump's target): DA v n w m
    k = 0
    while k < len(items) - 1:
        p, q = items[k], items[k + 1]
        if p[1] == "rapida" and q[1] == "rapida" and p[3][0][0] == q[3][0][0] == 0xD8 and q[0] not in destinos \
           and q[0] not in entradas:
            items[k] = [p[0], "set2", 5, (p[3], q[3])]
            del items[k + 1]
        k += 1
    # the code that falls into the next script function (5FDD: past its switch table, the code after it is
    # 5FEE): a JR over the function's JSR logica_b_vm, to its bytecode
    CAE = {"ret", "jp", "jpn", "setret", "jr"}              # the kinds that never go on to the next item
    k = 0
    while k < len(items) - 1:
        if items[k + 1][0] in entradas and items[k][1] not in CAE:
            items.insert(k + 1, [("cae", items[k + 1][0]), "jr", 2, items[k + 1][0]])
            k += 1
        k += 1
    while True:                              # the long JP / JP NZ that reach as JR / JR NZ (sizes only shrink)
        d, total = direcciones()
        cambia = False
        for it in items:
            if it[1] in ("jp", "jpnz") and it[2] == 3 and -128 <= d[it[3]] - (d[it[0]] + 2) <= 127:
                it[2] = 2; cambia = True
        if not cambia: break
    return d, total
def direcciones():
    d, pos = {}, 0
    for it in items:
        if it[0] in entradas: pos += 3
        d[it[0]] = pos
        if it[1] == "marca": d[it[3]] = pos
        pos += it[2]
    return d, pos
def destino(d, l):
    return d[l] if isinstance(l, str) and l[0] in "MT" else d[int(l[1:], 16)]
sin_cadena = {}
while True:              # a chain whose jumps do not reach: without the jump after it, then a CF expression
    d, total = construye(sin_cadena)
    lejos = {it[0] if isinstance(it[0], int) else it[0][1] for it in items if it[1] == "hoja"
             and not -128 <= destino(d, it[3][2]) - (d[it[0]] + it[2]) <= 127}
    if not lejos: break
    for a in lejos: sin_cadena[a] = sin_cadena.get(a, 0) + 1

# ---- what each test must leave: A, C and the flags matter only where the code reads them before setting them
def indices():
    pos = {}
    for n, it in enumerate(items):
        if it[1] == "marca": pos[it[3]] = n
        elif isinstance(it[0], int): pos.setdefault(etiqueta(it[0]), n)
        elif it[0][0] == "cae": pos.setdefault(("cae", it[0][1]), n)
    return pos
MATA = {"hoja", "test", "set", "rapida", "set2", "setret"}     # they set A, C and the flags before reading them
def lee_desde(pos):
    memo = {}
    def lee(n):
        if n >= len(items): return True
        if n in memo: return memo[n]
        memo[n] = True                                           # (a loop: conservative)
        it = items[n]
        if it[1] in MATA: r = False
        elif it[1] == "marca": r = lee(n + 1)
        elif it[1] in ("jr", "jp") and (it[1] == "jr" or it[2] == 2 or INICIO <= it[3] < FIN):
            r = lee(pos[etiqueta(it[3])]) if etiqueta(it[3]) in pos else True
        else: r = True
        memo[n] = r
        return r
    return lee
# the tests that leave A, C and the flags as they were (internal codes, made paged below): E1 `=` -> E0,
# E3 `>` -> 1A3, E2 `=` the jump when true -> 1A8, E5 `<` -> 1B0
SIN_RESULTADO = {0xE1: 0xE0, 0xE3: 0x1A0, 0xE2: 0x1A8, 0xE5: 0x1B0}
# the tests with the variable's C64 page in the opcode: F8+p (E1), F0+p (E0), A0+p, A8+p, B0+p
PAGINADAS = {0xE1: 0xF8, 0xE0: 0xF0, 0x1A0: 0xA0, 0x1A8: 0xA8, 0x1B0: 0xB0}
pos = indices()
lee = lee_desde(pos)
for n, it in enumerate(items):
    if it[1] == "hoja":
        op, b, dest, t = it[3]
        salto = lee(pos[dest]) if dest in pos else True
        cae = lee(n + 1)
        if not salto and not cae and op in SIN_RESULTADO: op = SIN_RESULTADO[op]   # nothing reads what it leaves
        it[3] = (op, b, dest, t, salto, cae)

# ---- pass 3: the source ---------------------------------------------------------------------------
importa = set()
L = ["; generated by guiones64.py from the Z80 scripts 51E7-60F2 (data/cpc64/juego/ram.bin): do not edit;",
     "; logica_b_vm's bytecode (the format: guiones64.py, logica_b.s).  Lxxxx = the Z80 address of the instruction.", "",
     "; JR NZ / JR: the displacement from the next instruction, as on the Z80",
     ".macro JRNZ destino", "        .local aqui", "aqui:   .byte   $20, <(destino - aqui - 2)",
     "        .assert destino - aqui - 2 >= -128 && destino - aqui - 2 <= 127, error, \"JR NZ out of range\"",
     ".endmacro", ".macro JR destino", "        .local aqui", "aqui:   .byte   $18, <(destino - aqui - 2)",
     "        .assert destino - aqui - 2 >= -128 && destino - aqui - 2 <= 127, error, \"JR out of range\"",
     ".endmacro", "; E1-EC v .. e, F0-FF a n e: a test and its jump (e from the next instruction)",
     ".macro PRUEBAP op, dir, n, destino", "        .local aqui", "aqui:   .byte   op | >(dir), <(dir), n, <(destino - aqui - 4)",
     "        .assert >(dir) < 8, error, \"a script variable above page 7\"",
     "        .assert destino - aqui - 4 >= -128 && destino - aqui - 4 <= 127, error, \"test jump out of range\"",
     ".endmacro", ".macro PRUEBA op, b1, b2, destino", "        .local aqui", "aqui:   .byte   op, b1, b2, <(destino - aqui - 4)",
     "        .assert destino - aqui - 4 >= -128 && destino - aqui - 4 <= 127, error, \"test jump out of range\"",
     ".endmacro", ".macro PRUEBA3 op, b1, destino", "        .local aqui", "aqui:   .byte   op, b1, <(destino - aqui - 3)",
     "        .assert destino - aqui - 3 >= -128 && destino - aqui - 3 <= 127, error, \"test jump out of range\"",
     ".endmacro", ".macro PRUEBA5 op, b1, b2, b3, destino", "        .local aqui",
     "aqui:   .byte   op, b1, b2, b3, <(destino - aqui - 5)",
     "        .assert destino - aqui - 5 >= -128 && destino - aqui - 5 <= 127, error, \"test jump out of range\"",
     ".endmacro", "", ".segment \"CODE\""]
for a, k, n, x in items:
    if a in entradas:
        L += ["", "; %04X %s" % (a, entradas[a]), entradas[a] + ":", "        jsr     logica_b_vm"]
    if isinstance(a, int) and (a in destinos or a in entradas): L.append(etiqueta(a) + ":")
    if k == "marca": L.append(x + ":")
    elif k == "hoja":
        op, b, dest, t, salto, cae = x
        if isinstance(a, int): L.append("        ; %s" % t)
        if op in PAGINADAS:                     # the variable's page in the opcode, its low byte
            L.append("        PRUEBAP $%02X, %s, $%02X, %s" % (PAGINADAS[op], var_c64(b[0]), b[1], dest))
        else:
            L.append("        PRUEBA%s  $%02X, %s, %s" % ({1: "3", 2: " ", 3: "5"}[len(b)], op, ", ".join("$%02X" % v for v in b), dest))
    elif k == "setret": L.append("        .byte   $D9, $%02X, $%02X  ; %s / RET" % (x[0][1], x[0][2], x[1]))
    elif k == "set2":
        (r1, t1), (r2, t2) = x
        L.append("        .byte   $DA, $%02X, $%02X, $%02X, $%02X  ; %s / %s" % (r1[1], r1[2], r2[1], r2[2], t1, t2))
    elif k == "rapida": L.append("        .byte   $%02X, $%02X, $%02X  ; %s" % (x[0][0], x[0][1], x[0][2], x[1]))
    elif k == "test": L.append("        .byte   $CF, %s  ; %s" % (", ".join("$%02X" % b for b in x[0]), x[1]))
    elif k == "set": L.append("        .byte   $D7, %s  ; %s" % (", ".join("$%02X" % b for b in (2 * x[0][0] & 0xFF,) + tuple(x[0][1:])), x[1]))
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
    elif k == "xora": L.append("        .byte   $01  ; XOR A")
cab = ["        .include \"mapa64.inc\"",
       "        .export " + ", ".join(entradas[a] for a in sorted(entradas)) + ", lb_orient_guillermo, lb_orient_abbot",
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
print("%d instructions, %d functions, %d imports, %d bytes; %d tests as chains, %d as CF expressions" % (len(ins),
      len(entradas), len(importa), total, len({it[0] for it in items if it[1] == "hoja" and isinstance(it[0], int)}),
      sum(it[1] == "test" for it in items)))
