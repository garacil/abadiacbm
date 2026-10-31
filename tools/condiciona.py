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

"""One ca65 source with two versions of it: OLD as it is, NEW under `.ifdef SYMBOL` (abadia128ks's speed work,
the C64 images stay byte for byte as they are, the C128's take the faster routines).  The lines the two
versions share stay once; every difference becomes `.ifdef SYMBOL` NEW `.else` OLD `.endif`, widened to whole
routines: a difference inside a .proc, .macro, .repeat, .scope or .if block takes the whole outermost block of each
version (so no block opens in one branch and closes in another, and each routine reads whole in both).  Checked
here: removing the branches gives back NEW (SYMBOL defined) and OLD (not), line for line.

    condiciona.py OLD NEW SYMBOL OUT        Deterministic.
"""
import difflib, re, sys

ABRE = re.compile(r"^\s*(?:[\w@]*:\s*)?\.(proc|macro|mac|repeat|scope|if|ifdef|ifndef|ifblank|ifnblank|ifconst|ifref|ifnref|ifp02|ifp816|ifpc02|ifpsc02)\b", re.I)
CIERRA = re.compile(r"^\s*(?:[\w@]*:\s*)?\.(endproc|endmacro|endmac|endrepeat|endrep|endscope|endif)\b", re.I)


def regiones(lin):
    """for each line, the [first, last] of the outermost block holding it (or itself)"""
    r = [(i, i) for i in range(len(lin))]
    nivel, ini = 0, None
    for i, l in enumerate(lin):
        c = l.split(";")[0]
        if ABRE.match(c):
            if nivel == 0: ini = i
            nivel += 1
        elif CIERRA.match(c):
            nivel -= 1
            assert nivel >= 0, f"line {i + 1}: a block closes that was not opened"
            if nivel == 0:
                for k in range(ini, i + 1): r[k] = (ini, i)
    assert nivel == 0, "a block is not closed"
    return r


def main():
    fv, fn, sim, fo = sys.argv[1:5]
    v, n = open(fv).read().split("\n"), open(fn).read().split("\n")
    rv, rn = regiones(v), regiones(n)
    ops = difflib.SequenceMatcher(None, v, n, autojunk=False).get_opcodes()
    par = []                                        # the shared lines (i, j)
    mv, mn = [False] * len(v), [False] * len(n)
    for op, i1, i2, j1, j2 in ops:
        if op == "equal": par += [(i1 + k, j1 + k) for k in range(i2 - i1)]
        else:
            for i in range(i1, i2): mv[i] = True
            for j in range(j1, j2): mn[j] = True
    cambia = True
    while cambia:
        cambia = False
        for m, r in ((mv, rv), (mn, rn)):
            for i in range(len(m)):
                if m[i]:
                    a, b = r[i]
                    for k in range(a, b + 1):
                        if not m[k]: m[k] = True; cambia = True
        for i, j in par:
            if mv[i] != mn[j]: mv[i] = mn[j] = True; cambia = True
    anclas = [(i, j) for i, j in par if not mv[i]] + [(len(v), len(n))]
    out, pi, pj = [], 0, 0
    for i, j in anclas:
        viejo, nuevo = v[pi:i], n[pj:j]
        if viejo or nuevo:
            if nuevo and viejo: out += [f".ifdef {sim}"] + nuevo + [".else"] + viejo + [".endif"]
            elif nuevo: out += [f".ifdef {sim}"] + nuevo + [".endif"]
            else: out += [f".ifndef {sim}"] + viejo + [".endif"]
        if i < len(v): out.append(v[i])
        pi, pj = i + 1, j + 1
    # the check: what the assembler sees, with SYMBOL defined and without, is NEW's and OLD's (the versions' own
    # `.ifdef SYMBOL` blocks evaluated the same way; any other conditional is copied as it is)
    def vista(lin, definido):
        o, pila = [], []                            # entries: [ours?, active]
        for l in lin:
            s = l.split(";")[0].strip()
            activo = all(e[1] for e in pila)
            if s in (f".ifdef {sim}", f".ifndef {sim}"):
                pila.append([True, (s == f".ifdef {sim}") == definido]); continue
            if ABRE.match(s) and s.split()[0].lower().startswith(".if"):
                pila.append([False, True])
                if activo: o.append(l)
                continue
            if s.lower().startswith(".else") and pila:
                if pila[-1][0]: pila[-1][1] = not pila[-1][1]; continue
                if activo: o.append(l)
                continue
            if s.lower().startswith(".endif") and pila:
                e = pila.pop()
                if not e[0] and activo: o.append(l)
                continue
            if activo: o.append(l)
        assert not pila
        return o
    assert vista(out, True) == vista(n, True), "SYMBOL defined: not NEW"
    assert vista(out, False) == vista(v, False), "SYMBOL not defined: not OLD"
    open(fo, "w").write("\n".join(out))
    trozos = sum(1 for l in out if l in (f".ifdef {sim}", f".ifndef {sim}"))
    print(f"{fo}: {trozos} conditional blocks, {sum(mv)} of {len(v)} old lines and {sum(mn)} of {len(n)} new ones in them")


if __name__ == "__main__":
    main()
