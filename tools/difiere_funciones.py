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

"""The code differences of the 64 KiB game against the full game, per 64 KiB function (milestone H10, the full
game for abadia128ks).  Reads data/cpc64/dif_total.txt (difcodigo_total.py: the 64 KiB
code, A, against the 6128's, B, instruction by instruction, 16-bit operands normalised) and gives every
difference to the 64 KiB function that holds its A address; the functions and their PC counterparts come from
the headers of src/c64/certifica/anfitrion/f_*.c ("/* XXXX name (PC 1000:YYYY) ...").

    difiere_funciones.py OUT.tsv            (and OUT_detalle.txt: every difference, both sides)
"""
import glob, os, re, sys
P = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
funcs = []
for f in sorted(glob.glob(os.path.join(P, "src", "c64", "certifica", "anfitrion", "f_*.c"))):
    for m in re.finditer(r"/\* ([0-9A-F]{4}) ([a-z_0-9]+)(?: \(PC ([^)]*)\))?", open(f).read()):
        funcs.append((int(m.group(1), 16), m.group(2), m.group(3) or "", os.path.basename(f)))
funcs = sorted(set(funcs))
def funcion(a):
    best = None
    for f in funcs:
        if f[0] <= a: best = f
        else: break
    return best
ops, ultimo_a = [], 0
lineas = open(os.path.join(P, "data", "cpc64", "dif_total.txt")).read().splitlines()
i = 0
while i < len(lineas):
    l = lineas[i]
    m = re.match(r"= \d+ instructions A ([0-9A-F]{4})-([0-9A-F]{4})", l)
    if m: ultimo_a = int(m.group(2), 16)
    m = re.match(r"(insert|replace|delete) A\((\d+)\) \[(.*)\]$", l)
    if m:
        tipo, n, a_txt = m.group(1), int(m.group(2)), m.group(3)
        b = re.match(r"\s+B\((\d+)\) \[(.*)\]$", lineas[i + 1])
        a_dirs = [int(x, 16) for x in re.findall(r"(?:^|; )([0-9A-F]{4}) ", a_txt)]
        at = a_dirs[0] if a_dirs else ultimo_a + 1
        ops.append((at, tipo, n, int(b.group(1)), a_txt, b.group(2)))
        i += 2; continue
    i += 1
por = {}
for op in ops:
    f = funcion(op[0])
    por.setdefault(f, []).append(op)
with open(sys.argv[1], "w") as o:
    o.write("addr64\tname\tpc\tfile\tops\tA_instr\tB_instr\tfirst_A\tfirst_B\n")
    for f in sorted(por, key=lambda f: f[0] if f else -1):
        l = por[f]
        o.write(f"{f[0]:04X}\t{f[1]}\t{f[2]}\t{f[3]}\t{len(l)}\t{sum(x[2] for x in l)}\t{sum(x[3] for x in l)}\t{l[0][4]}\t{l[0][5]}\n"
                if f else f"----\t(before the first function)\t\t\t{len(l)}\t{sum(x[2] for x in l)}\t{sum(x[3] for x in l)}\t\t\n")
with open(os.path.splitext(sys.argv[1])[0] + "_detalle.txt", "w") as o:
    for f in sorted(por, key=lambda f: f[0] if f else -1):
        o.write(f"\n=== {f[0]:04X} {f[1]} (PC {f[2]})\n" if f else "\n=== (before the first function)\n")
        for op in por[f]:
            o.write(f"  {op[1]} A({op[2]}) [{op[4][:400]}]\n      B({op[3]}) [{op[5][:400]}]\n")
print(len(ops), "differences in", len(por), "functions")
