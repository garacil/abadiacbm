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

"""Wraps the hybrid host's part of a game file (the wrappers w_*, the checks r_*, the tables, and the
static helpers only they use) in #ifndef JUEGO_PURO ... #endif, so the pure C build compiles the game
code alone.  Idempotent: a file that already has the guards is left as it is.

    guarda_hibrido.py FILE.c [...]
"""
import re, sys

HIBRIDO = re.compile(r'\b(cpu|z80|z80_ret|SET_HL|SET_DE|SET_BC|traducida_t|CHEQUEO|llama_z80\w*|HL|DE|BC)\b')

def sin_comentarios(t):
    t = re.sub(r'/\*.*?\*/', ' ', t, flags=re.S)
    t = re.sub(r'"(\\.|[^"\\])*"', '""', t)
    return t

def items(lineas):
    """top-level items: (first line, last line) with the comment block before each one"""
    res = []
    i, n = 0, len(lineas)
    while i < n:
        l = lineas[i]
        if not l.strip():
            i += 1
            continue
        ini = i
        # a comment block: it belongs to the next item
        if l.lstrip().startswith('/*'):
            while '*/' not in lineas[i]:
                i += 1
            i += 1
            while i < n and not lineas[i].strip():
                i += 1
            if i >= n:
                res.append((ini, n - 1))
                break
            if lineas[i].lstrip().startswith('/*') or lineas[i].startswith('#'):
                res.append((ini, i - 1))
                continue
        if lineas[i].startswith('#'):
            j = i
            while lineas[j].rstrip().endswith('\\'):
                j += 1
            res.append((ini, j))
            i = j + 1
            continue
        # a declaration or definition: up to the ; or the } at depth 0
        prof, j, visto = 0, i, False
        while j < n:
            t = sin_comentarios(lineas[j])
            for c in t:
                if c == '{':
                    prof += 1; visto = True
                elif c == '}':
                    prof -= 1
            if prof == 0 and (t.rstrip().endswith(';') or (visto and t.rstrip().endswith('}')) or t.rstrip().endswith('};')):
                # a macro call line (CHEQUEO(...)) has no ; nor braces
                break
            if prof == 0 and not visto and re.match(r'^\s*[A-Z_]+\(.*\)\s*$', t):
                break
            j += 1
        res.append((ini, j))
        i = j + 1
    return res

def nombre(texto):
    t = sin_comentarios(texto)
    m = re.match(r'\s*#define\s+(\w+)', t)
    if m: return m.group(1)
    m = re.match(r'\s*CHEQUEO\((\w+)', t)
    if m: return m.group(1)
    m = re.search(r'(\w+)\s*(\[[^\]]*\])?\s*(=|\(|;)', t)
    return m.group(1) if m else None

def procesa(path):
    s = open(path).read()
    if 'JUEGO_PURO' in s:
        print(path, 'already guarded'); return
    lineas = s.split('\n')
    its = items(lineas)
    textos = ['\n'.join(lineas[a:b + 1]) for a, b in its]
    nombres = [nombre(t) for t in textos]
    codigos = [sin_comentarios(t) for t in textos]
    hib = []
    for t, c, nm in zip(textos, codigos, nombres):
        es = bool(HIBRIDO.search(c)) or (nm or '').startswith(('w_', 'r_'))
        if c.lstrip().startswith('#include'): es = False
        hib.append(es)
    # static helpers (and macros) used only by hybrid items
    cambio = True
    while cambio:
        cambio = False
        for k, (c, nm) in enumerate(zip(codigos, nombres)):
            if hib[k] or not nm: continue
            estatico = c.lstrip().startswith('static') or c.lstrip().startswith('#define')
            if not estatico: continue
            usos = [j for j, cc in enumerate(codigos) if j != k and re.search(r'\b%s\b' % re.escape(nm), cc)]
            if (usos and all(hib[j] for j in usos)) or (not usos and c.lstrip().startswith('#define')):
                hib[k] = True; cambio = True
    out, k, i = [], 0, 0
    abierto = False
    for (a, b), es in zip(its, hib):
        while i < a:
            out.append(lineas[i]); i += 1
        if es and not abierto:
            out.append('#ifndef JUEGO_PURO  /* the hybrid host */'); abierto = True
        if not es and abierto:
            # the blank lines before the item stay outside
            while out and not out[-1].strip(): out.pop(); i -= 1
            out.append('#endif'); abierto = False
            while i < a: out.append(lineas[i]); i += 1
        while i <= b:
            out.append(lineas[i]); i += 1
    if abierto:
        while out and not out[-1].strip(): out.pop()
        out.append('#endif')
        out.append('')
    while i < len(lineas):
        out.append(lineas[i]); i += 1
    open(path, 'w').write('\n'.join(out))
    print(path, sum(hib), 'hybrid items of', len(hib))

for p in sys.argv[1:]:
    procesa(p)
