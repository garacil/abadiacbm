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

"""The inventory of the game's data: every D64_ name of src/juego/datos_*.h by address, with what the
sessions measured about it.  Input of the C64 memory map (src/c64/MAPA.md, src/c64/juego/mapa64.tsv).

    datos64.py [JUEGO_DIR]    -> data/datos64.tsv

Columns: CPC address, names (all groups'), bytes up to the next named address, bytes of that range the
Z80 read / wrote as data in the 8 exploration sessions (data/cpc64/accesos/), executed Z80 code
bytes in that range (the listings' '*' lines), the area, the first comment.
"""
import glob, os, re, sys

P = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
J = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(P, "src", "juego"))
nombres, comentarios = {}, {}
for f in sorted(glob.glob(os.path.join(J, "datos_*.h"))):
    for l in open(f):
        m = re.match(r"#define\s+(D64_\w+)\s+0x([0-9A-Fa-f]{1,4})u?\b\s*(/\*(.*?)(\*/)?)?\s*$", l)
        if not m: continue
        a = int(m.group(2), 16)
        nombres.setdefault(a, [])
        if m.group(1) not in nombres[a]: nombres[a].append(m.group(1))
        if m.group(4) and a not in comentarios: comentarios[a] = m.group(4).strip()
acc = {}
for f in glob.glob(os.path.join(P, "data", "cpc64", "accesos", "azar*.txt")):
    for l in open(f):
        if l.startswith("#"): continue                      # (my licence header)
        a, fl = l.split(); a = int(a, 16)
        acc[a] = acc.get(a, 0) | (1 if "r" in fl else 0) | (2 if "w" in fl else 0)
codigo = set()
for f in glob.glob(os.path.join(P, "data", "cpc64", "listado", "*.asm")):
    lines = [l for l in open(f) if re.match(r"^[0-9A-F]{4} ", l)]
    addrs = [int(l[:4], 16) for l in lines]
    for i, l in enumerate(lines):
        if l[5] != "*": continue
        n = addrs[i + 1] - addrs[i] if i + 1 < len(lines) else 1
        if 0 < n <= 4: codigo.update(range(addrs[i], addrs[i] + n))

def zona(a):
    if a < 0x0100: return "low"
    if a < 0x6000: return "code area"
    if a < 0xC000: return "data area"
    return "screen hidden" if (a & 0x7FF) >= 0x600 else "screen"

dirs = sorted(a for a in nombres if a < 0x10000)
out = ["addr\tnames\tlen_to_next\tread\twritten\tcode_bytes\tarea\tcomment"]
for i, a in enumerate(dirs):
    b = dirs[i + 1] if i + 1 < len(dirs) else 0x10000
    rango = range(a, b)
    r = sum(1 for k in rango if acc.get(k, 0) & 1); w = sum(1 for k in rango if acc.get(k, 0) & 2)
    c = sum(1 for k in rango if k in codigo)
    out.append(f"{a:04X}\t{' '.join(nombres[a])}\t{b - a}\t{r}\t{w}\t{c}\t{zona(a)}\t{comentarios.get(a, '')[:100]}")
open(os.path.join(P, "data", "datos64.tsv"), "w").write("\n".join(out) + "\n")
print(f"{len(dirs)} addresses, {sum(len(v) for v in nombres.values())} names")
