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

"""The 64 KiB game's data against the full game's (the PC rebuild: the PC version is the
reference), datum by datum through the shared names: D64_NAME of src/c64/juego_final/mapa64.inc (CPC address, size) and NAME
of the PC rebuild's include/direcciones.h (PC address, size).  The values compared are the initial ones: the 64 KiB
memory at the game's start (data/cpc64/juego/ram.bin) and the PC's data space as the disk loads it
(abadia/trabajo/re/disco/programa.bin, 1800:0000).  A 16-bit field that differs by a relocation shows up too:
the report says how many bytes differ and shows both.

    compara_datos_pc.py OUT.tsv
"""
import os, re, sys
P = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
PC = os.environ.get("ABADIA_PC", os.path.expanduser("~/Proyectos/abadia"))
m64 = open(os.path.join(P, "data", "cpc64", "juego", "ram.bin"), "rb").read()
ds = open(os.path.join(PC, "trabajo", "re", "disco", "programa.bin"), "rb").read()[0x8000:0x18000]
pcs = {}
for l in open(os.path.join(PC, "c", "include", "direcciones.h")):
    m = re.match(r"#define (\w+)\s+0x([0-9A-F]+)u", l)
    if m and not m.group(1).endswith("_SIZE"): pcs[m.group(1)] = [int(m.group(2), 16), None]
    m = re.match(r"#define (\w+)_SIZE\s+(\d+)u", l)
    if m and m.group(1) in pcs: pcs[m.group(1)][1] = int(m.group(2))
# a 16-bit value of the PC's data space -> the 64 KiB address of the same thing: inside a datum of a shared name,
# or a function of the PC (1000:XXXX) cited by an f_*.c header of src/c64/certifica/anfitrion
pc_tam, cpc_de = {}, {}
for l in open(os.path.join(P, "src", "c64", "juego_final", "mapa64.inc")):
    m = re.match(r"D64_(\w+) = \$[0-9A-F]+\s+; CPC ([0-9A-F]+)h", l)
    if m: cpc_de[m.group(1)] = int(m.group(2), 16)
zonas = sorted((pa, pa + (sz or 1), cpc_de[nom]) for nom, (pa, sz) in pcs.items() if nom in cpc_de)
import glob
funcs = {}
for f in glob.glob(os.path.join(P, "src", "c64", "certifica", "anfitrion", "f_*.c")):
    for m in re.finditer(r"/\* ([0-9A-F]{4}) [a-z_0-9]+ \(PC 1000:([0-9A-F]{4})", open(f).read()):
        funcs[int(m.group(2), 16)] = int(m.group(1), 16)
def pc_a_cpc(v):
    if v in funcs: return funcs[v]
    for a0, a1, c in zonas:
        if a0 <= v < a1: return c + (v - a0)
    return None
def reales(a, b):
    """the byte positions that differ once relocated 16-bit pointers are taken as equal"""
    dif, i = [], 0
    while i < len(a):
        if a[i] == b[i]: i += 1; continue
        for j in (i - 1, i):
            if 0 <= j and j + 1 < len(a) and pc_a_cpc(b[j] | b[j + 1] << 8) == (a[j] | a[j + 1] << 8):
                i = j + 2; break
        else:
            dif.append(i); i += 1
    return dif
filas = []
for l in open(os.path.join(P, "src", "c64", "juego_final", "mapa64.inc")):
    m = re.match(r"D64_(\w+) = \$[0-9A-F]+\s+; CPC ([0-9A-F]+)h(?:, (\d+) ->)?", l)
    if not m: continue
    nom, cpc, n = m.group(1), int(m.group(2), 16), m.group(3)
    if nom not in pcs: filas.append((nom, cpc, None, None, "no PC name")); continue
    pa, psz = pcs[nom]
    n = int(n) if n else (psz or 1)
    if psz and psz != n: nota = f"sizes 64K {n} PC {psz}"
    else: nota = ""
    k = min(n, psz or n)
    a, b = m64[cpc:cpc + k], ds[pa:pa + k]
    d = sum(1 for x, y in zip(a, b) if x != y)
    r = reales(a, b)
    filas.append((nom, cpc, pa, k, f"{d} of {k} bytes differ, {len(r)} not relocations" + (f"; {nota}" if nota else ""),
                  a[:24].hex(" "), b[:24].hex(" "), " ".join(f"+{x}:{a[x]:02X}/{b[x]:02X}" for x in r[:16])))
with open(sys.argv[1], "w") as o:
    o.write("name\tcpc64\tpc\tbytes\tresult\t64K\tPC\treal (offset:64K/PC)\n")
    for f in filas:
        o.write("\t".join("" if x is None else (f"{x:04X}" if isinstance(x, int) and i in (1, 2) else str(x)) for i, x in enumerate(f)) + "\n")
dif = [f for f in filas if len(f) > 5 and not f[4].startswith("0 of")]
real = [f for f in dif if ", 0 not relocations" not in f[4]]
print(len(filas), "data;", sum(1 for f in filas if f[4] == "no PC name"), "without a PC name;", len(dif), "differ;",
      len(real), "beyond relocated pointers")
