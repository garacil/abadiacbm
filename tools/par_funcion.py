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

"""A function of the 64 KiB game (its C in src/c64/certifica/anfitrion/f_*.c) next to the full game's (the PC
rebuild, /home/german/Proyectos/abadia/c/src), for reading the differences (milestone H10, the full game).

    par_funcion.py NAME [PC_NAME]
"""
import glob, os, re, sys
P = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
PC = "/home/german/Proyectos/abadia/c/src"
def busca(ficheros, cab):
    for f in ficheros:
        t = open(f).read()
        for m in re.finditer(r"/\*(?:(?!\*/).)*?" + cab + r".*?\*/\n(?:[^\n]*\n)*?\}\n", t, re.S):
            return os.path.basename(f), m.group(0)
    return None, "(not found)\n"
nom = sys.argv[1]; npc = sys.argv[2] if len(sys.argv) > 2 else nom
f, c = busca(sorted(glob.glob(os.path.join(P, "src", "c64", "certifica", "anfitrion", "f_*.c"))), r"\b[0-9A-F]{4} " + nom + r"\b")
print(f"==== 64 KiB ({f})\n{c}")
f, c = busca(sorted(glob.glob(os.path.join(PC, "*.c"))), r"1000:[0-9A-F]{4} " + npc + r"\b")
print(f"==== PC ({f})\n{c}")
