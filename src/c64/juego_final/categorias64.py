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

"""The categories file for juego/hibrido's SOMBRA6502_CATEGORIAS (per frame, the 6502 cycles spent in each source
module and the number of times some routines run): one category per module of the CODE segment (from juego.map's
"Modules list"), plus "hit" lines for the routines given (from juego.lbl).

    categorias64.py OUT [--juego DIR] [--hit label...]

Prints the column names in the order hibrido --ciclos-frame writes them (after frame, z80_tstates, c64_cycles,
budget_ticks): the 16 categories (the modules, 0 = everything else) and then the hits.
"""
import os, sys
args = sys.argv[1:]
jdir = os.path.dirname(os.path.realpath(__file__))
hits = []
out = None
while args:
    a = args.pop(0)
    if a == "--juego": jdir = args.pop(0)
    elif a == "--hit":
        while args and not args[0].startswith("--"): hits.append(args.pop(0))
    else: out = a
if not out: sys.exit(__doc__)
code_start = None
mods = []
en = False
mod = None
for l in open(os.path.join(jdir, "juego.map")):
    if l.startswith("Modules list:"): en = True; continue
    if l.startswith("Segment list:"): en = False
    if en:
        if l and not l[0].isspace() and l.rstrip().endswith(":"): mod = l.strip()[:-1]
        p = l.split()
        if len(p) >= 3 and p[0] == "CODE" and p[1].startswith("Offs="):
            mods.append((mod, int(p[1][5:], 16), int(p[2][5:], 16)))
    p = l.split()
    if len(p) >= 4 and p[0] == "CODE" and code_start is None and not l.startswith(" "):
        try: code_start = int(p[1], 16)
        except ValueError: pass
labels = {}
for l in open(os.path.join(jdir, "juego.lbl")):
    p = l.split()
    if len(p) == 3 and p[0] == "al": labels[p[2].lstrip(".")] = int(p[1], 16)
names = ["other"]
with open(out, "w") as f:
    for i, (m, offs, size) in enumerate(mods[:15]):
        f.write(f"{code_start + offs:04X} {code_start + offs + size - 1:04X} {i + 1}\n")
        names.append(m.replace(".o", ""))
    for h in hits:
        f.write(f"hit {labels[h]:04X}\n")
print("\t".join(names + [f"hit_{h}" for h in hits]))
