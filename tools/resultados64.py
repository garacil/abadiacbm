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

"""Merges the groups' resultados.tsv into one for the integrated 6502 build (src/c64/juego_final).

    resultados64.py [--cambia=FILE] OUT.tsv SOURCES... -- GROUPDIRS...

SOURCES are the .s files of the integrated build, given in their group's directory: the routine a file exports
(".export") is owned by that group.  A source written !path is a file of a group left out of the build (routines
nothing calls in the final game): the functions it exports get no line.  GROUPDIRS are the groups' workspaces (src/c64/juego_<group>), each with its resultados.tsv: the lines for the
group's own routines and the lines it wrote for other groups' functions it called as traps (stubs).

For every function named in any resultados.tsv:
  * exported by a source (translated): the lines of the group whose directory holds that source; if that group
    wrote none, the function gets no line (its owner checked it without declarations; the other groups' lines
    were for its trap).
  * exported by none (still a trap): the stub lines, which must agree.
--cambia=FILE: lines that replace the merged line of their function (the integration's own: a routine that called
a trap in its group's checks and now calls the translated routine inherits its comparison rules, e.g. the
PANTALLA:doble of the sprite drawing).  Lines are compared as whitespace-separated token lists; disagreeing duplicates stop the merge.  The header
comment is the first group's.  Deterministic: the output is sorted by group (GROUPDIRS order), then by the
order of first appearance in that group's file.
"""
import os
import re
import sys


def lee(ruta):
    cab, filas = [], []
    with open(ruta) as f:
        for n, linea in enumerate(f):
            linea = linea.rstrip("\n")
            if linea.startswith("#"):
                if not filas and n < 10:
                    cab.append(linea)
                continue
            t = linea.split()
            if t:
                filas.append(t)
    return cab, filas


def main(argv):
    if "--" not in argv or len(argv) < 4:
        sys.exit(__doc__)
    cambios = {}
    while argv[1].startswith("--cambia="):
        for t in lee(argv[1][len("--cambia="):])[1]:
            cambios[t[0]] = t
        del argv[1]
    i = argv.index("--")
    salida, fuentes, grupos = argv[1], argv[2:i], argv[i + 1:]
    dueno = {}                                  # function -> the group directory of the source exporting it
    fuera = set()                               # functions of the sources left out
    for s in fuentes:
        quita = s.startswith("!")
        s = s[1:] if quita else s
        g = os.path.realpath(os.path.dirname(s))
        if g not in [os.path.realpath(d) for d in grupos]:
            sys.exit(f"resultados64: {s} is not in one of the group directories")
        g = [d for d in grupos if os.path.realpath(d) == g][0]
        with open(s) as f:
            texto = f.read()
        for m in re.finditer(r"^\s*\.export\s+([^;\n]*)", texto, re.M):
            for nombre in m.group(1).split(","):
                nombre = nombre.strip()
                if nombre and quita:
                    fuera.add(nombre)
                elif nombre:
                    if nombre in dueno and dueno[nombre] != g:
                        sys.exit(f"resultados64: {nombre} exported twice ({dueno[nombre]}, {g})")
                    dueno[nombre] = g
    cab, porgrupo = None, {}
    for d in grupos:
        c, filas = lee(os.path.join(d, "resultados.tsv"))
        cab = cab if cab is not None else c
        porgrupo[d] = filas
    elegidas, orden, fallos = {}, [], []
    for d in grupos:
        for t in porgrupo[d]:
            f = t[0]
            if f in fuera and f not in dueno:
                continue
            if f in dueno:
                if dueno[f] != d:
                    continue
            if f in elegidas:
                if elegidas[f] != t:
                    fallos.append(f"{f}: {' '.join(elegidas[f])} / {' '.join(t)} ({d})")
                continue
            elegidas[f] = t
            orden.append((d, f))
    if fallos:
        sys.exit("resultados64: lines that disagree:\n  " + "\n  ".join(fallos))
    for f, t in cambios.items():
        if f not in elegidas:
            sys.exit(f"resultados64: --cambia names {f}, which has no line")
        elegidas[f] = t
    with open(salida, "w") as o:
        o.write("\n".join(cab) + "\n")
        o.write("# merged by tools/resultados64.py from the groups' resultados.tsv: each translated\n"
                "# routine with its owner's lines, each function still a trap with the stub lines\n")
        anterior = None
        for d, f in orden:
            if d != anterior:
                o.write(f"# ---- {os.path.basename(os.path.normpath(d))}\n")
                anterior = d
            if f in cambios:
                o.write("# (the next line is the integration's own: --cambia)\n")
            o.write("\t".join(elegidas[f]) + "\n")
    print(f"{len(orden)} lines, {sum(1 for _, f in orden if f in dueno)} translated routines, "
          f"{sum(1 for _, f in orden if f not in dueno)} traps")


if __name__ == "__main__":
    main(sys.argv)
