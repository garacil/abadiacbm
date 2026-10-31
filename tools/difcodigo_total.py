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

"""Whole-program instruction diff of two Z80 images (linear disassembly, normalised numbers).

    difcodigo_total.py IMG_A A_FROM A_TO IMG_B B_FROM B_TO

Both ranges are disassembled linearly with z80dasm; 16-bit numbers become NN (relocation), the
streams are compared with difflib and every non-equal block is printed with both addresses.
Data areas inside the ranges show up as noise blocks; code changes show up as short blocks inside
long equal stretches.
"""
import difflib, sys
from difcodigo import disasm, norm


def main():
    a = open(sys.argv[1], "rb").read(); af, at = int(sys.argv[2], 16), int(sys.argv[3], 16)
    b = open(sys.argv[4], "rb").read(); bf, bt = int(sys.argv[5], 16), int(sys.argv[6], 16)
    A, B = disasm(a, af, at), disasm(b, bf, bt)
    An, Bn = [norm(t) for _, t in A], [norm(t) for _, t in B]
    sm = difflib.SequenceMatcher(None, An, Bn, autojunk=False)
    eq = 0
    for t, i1, i2, j1, j2 in sm.get_opcodes():
        if t == "equal":
            eq += i2 - i1
            print(f"= {i2 - i1} instructions A {A[i1][0]:04X}-{A[i2 - 1][0]:04X} B {B[j1][0]:04X}-{B[j2 - 1][0]:04X}")
            continue
        la = "; ".join(f"{A[i][0]:04X} {A[i][1]}" for i in range(i1, min(i2, i1 + 30))) + (" ..." if i2 - i1 > 30 else "")
        lb = "; ".join(f"{B[j][0]:04X} {B[j][1]}" for j in range(j1, min(j2, j1 + 30))) + (" ..." if j2 - j1 > 30 else "")
        print(f"{t} A({i2 - i1}) [{la}]\n   B({j2 - j1}) [{lb}]")
    print(f"# equal {eq} of A {len(A)} / B {len(B)}")


if __name__ == "__main__":
    main()
