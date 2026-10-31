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

"""A flat profile of the whole 6502 game (hibrido --juego6502 with SOMBRA6502_PERFIL=F: cycles per address;
the labels of `PERFIL=1 ./construye.sh`) by
routine: each address goes to the routine (a .proc or a top-level label of the sources, exported or not: by
exported labels alone an unexported routine linked after another module was counted as that module's last
exported routine) nearest at or below it, and to the nearest label of any kind (juego_todo.lbl).
    perfil64.py PROFILE.tsv FRAMES [N]     the N (default 40) costliest of each, cycles per frame"""
import bisect, sys, os
D = os.path.dirname(os.path.realpath(__file__))
def etiquetas(f, solo_unicas):
    out = {}
    for l in open(f):
        t = l.split()
        if len(t) == 3 and t[0] == "al":
            out.setdefault(int(t[1], 16), t[2].lstrip("."))
    return sorted(out.items())
ciclos = [(int(a, 16), int(c)) for a, c in (l.split() for l in open(sys.argv[1]) if l.strip())]
frames = int(sys.argv[2]); n = int(sys.argv[3]) if len(sys.argv) > 3 else 40
import glob, re
rutinas = set()                 # every routine: the .proc names and the top-level labels (column 0, not @ / :)
for f in glob.glob(os.path.join(D, "*.s")) + glob.glob(os.path.join(D, "../plataforma/*.s")):
    texto = open(f).read()
    rutinas.update(re.findall(r"^\s*\.proc\s+(\w+)", texto, re.M))
    rutinas.update(re.findall(r"^([A-Za-z_]\w*):", texto, re.M))
por_nombre = {}
for linea in open(os.path.join(D, "juego_todo.lbl")):
    t = linea.split()
    if len(t) == 3 and t[0] == "al":
        por_nombre.setdefault(t[2].lstrip("."), set()).add(int(t[1], 16))
for titulo, lista in (("by routine (a .proc or a top-level label with one address)",
                       sorted((min(v), nom) for nom, v in por_nombre.items() if nom in rutinas and len(v) == 1)),
                      ("by label", etiquetas(os.path.join(D, "juego_todo.lbl"), False))):
    dirs = [a for a, _ in lista]
    suma = {}
    for a, c in ciclos:
        i = bisect.bisect_right(dirs, a) - 1
        nom = lista[i][1] if i >= 0 else "?"
        suma[nom] = suma.get(nom, 0) + c
    total = sum(suma.values())
    print(f"== {titulo}: {total / frames:.0f} cycles per frame")
    for nom, c in sorted(suma.items(), key=lambda x: -x[1])[:n]:
        print(f"{nom:36s} {c / frames:9.0f} {100 * c / total:5.1f} %")
