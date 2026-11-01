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

"""The cost of la_busca by its parts, from per-address profiles (SOMBRA6502_PERFIL or the tracer's .ctx_ files:
"ADDR\\tCYCLES").  Every profiled address inside the .proc goes to the nearest label at or below it (ld65's debug
file: every label, the macro-local ones as LOCAL_MACRO_SYMBOL_n), and each label to a part by the address ranges
below (the labels of logica_a_cam.s, in address order).  Deterministic.

    partes.py DBG NFRAMES NAME:PROFILE [NAME:PROFILE...] > table.tsv

Prints, per profile, the cycles and cycles per frame of each part and of each label, and the .proc's total."""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from atribuye import Atribucion

# the parts: (first label, part name); a label's part is the last entry whose first label is at or below it
PARTES = [("la_busca", "setup (queue, origin, la_hb, mode)"),
          ("hallado", "end (hallado/fin/hl/vacia, the Z80 stack words)"),
          ("planta", "floor expansion (planta/plan1/plan2/sig_p)"),
          ("o_n3", "room expansion: neighbours inline (o_n3..o_n0, VECINO)"),
          ("sig", "room queue loop (sig/sig1/sig2/modo1/pagina/separa/meta_i)"),
          ("exacta", "exact mode (exacta/lazo)"),
          ("mete", "mete (the origin / separator queued)"),
          ("cuadro", "cuadro: the square check (generic)"),
          ("encola", "encola/mete1: a neighbour queued"),
          ("px", "cuadro's slopes (px/py/pend_x/pend_y) and meta"),
          ("la_exacto", "la_exacto and the PRUEBA-only word writers (la_tw/la_xj/la_j0/la_rexp)"),
          ("ret_exp", "data")]


def main():
    dbg, nframes = sys.argv[1], float(sys.argv[2])
    at = Atribucion(dbg)
    lo, hi = at.proc_span("la_busca")
    labels = [(v, n) for v, n, sc in at.labs if lo <= v < hi]
    # the part boundaries: the address of each first label (the first occurrence at or above the previous one)
    bounds = []
    pos = lo
    for first, pname in PARTES:
        cands = [v for v, n in labels if n == first and v >= pos]
        if not cands:
            sys.exit(f"label {first} not found in la_busca at or above {pos:04X}")
        bounds.append((cands[0], pname))
        pos = cands[0]

    def part_of(a):
        p = bounds[0][1]
        for v, n in bounds:
            if a >= v:
                p = n
        return p
    specs = sys.argv[3:]
    print("profile\tkind\tname\taddr\tcycles\tcycles_per_frame\tpercent_of_proc")
    for spec in specs:
        name, prof = spec.split(":", 1)
        cyc = {}
        for l in open(prof):
            t = l.split()
            if len(t) == 2:
                cyc[int(t[0], 16)] = cyc.get(int(t[0], 16), 0) + int(t[1])
        total = sum(c for a, c in cyc.items() if lo <= a < hi)
        by_part, by_label = {}, {}
        for a, c in cyc.items():
            if not lo <= a < hi:
                continue
            by_part[part_of(a)] = by_part.get(part_of(a), 0) + c
            la, ln = at.nearest_label(a)
            by_label[(la, ln)] = by_label.get((la, ln), 0) + c
        print(f"{name}\tproc\tla_busca\t{lo:04X}-{hi - 1:04X}\t{total}\t{total / nframes:.1f}\t100.00")
        for v, pname in bounds:
            c = by_part.get(pname, 0)
            print(f"{name}\tpart\t{pname}\t{v:04X}\t{c}\t{c / nframes:.1f}\t{100 * c / total if total else 0:.2f}")
        for (la, ln), c in sorted(by_label.items()):
            print(f"{name}\tlabel\t{ln}\t{la:04X}\t{c}\t{c / nframes:.1f}\t{100 * c / total if total else 0:.2f}")


if __name__ == "__main__":
    main()
