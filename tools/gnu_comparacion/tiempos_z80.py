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

"""T-states of every instruction of a z80dasm listing, measured by SkoolKit's simulator (the one
cpc_carga.py uses): each instruction is run once from its address with the flags all clear and all
set, B = 1 and B = 2 (DJNZ), BC = 1 and 2 (LDIR), so both outcomes of a condition are seen.
    tiempos_z80.py RAM.bin LISTING.asm [FROM TO]   (hex addresses) -> 'ADDR T[/T2]  instruction'
"""
import re, sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from z80sim import Simulator
from skoolkit.simutils import A, F, B, C, SP, PC, T

ram = bytearray(open(sys.argv[1], "rb").read())
desde, hasta = (int(sys.argv[3], 16), int(sys.argv[4], 16)) if len(sys.argv) > 4 else (0, 0x10000)
for linea in open(sys.argv[2]):
    m = re.search(r";([0-9a-f]{4})$", linea.rstrip())
    if not m:
        continue
    a = int(m.group(1), 16)
    if not desde <= a < hasta:
        continue
    vistos = set()
    for f in (0x00, 0xFF):
        for b, c in ((1, 0), (2, 0), (0, 1), (0, 2)):
            mem = bytearray(ram)
            s = Simulator(mem)
            r = s.registers
            r[PC], r[F], r[B], r[C], r[SP], r[T] = a, f, b, c, 0xBF00, 0
            s.run()
            vistos.add(r[T])
    ins = linea.split(";")[0].strip()
    print(f"{a:04X} {'/'.join(str(t) for t in sorted(vistos)):>8}  {ins}")
