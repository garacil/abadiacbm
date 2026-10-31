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

"""Per-function Z80 listings of the CPC 64 KiB game, for the translation to C.

    listado64.py FUNCIONES64.tsv COBERTURA.txt RAM.bin OUTDIR

For every function of the map: OUTDIR/<ADDR>_<name>.asm, the z80dasm disassembly from its entry to
the next known entry (at most 0x300 bytes), every instruction marked `*` when it was executed in the
exploration sessions, calls and jumps to known functions named, plus a header (PC name and address,
CPC 6128 address, times called, callers).  OUTDIR/indice.tsv lists them.
"""
import os, re, subprocess, sys, tempfile


def main():
    fun = []
    for line in open(sys.argv[1]):
        if line.startswith(("#", "addr64")): continue
        t = line.rstrip("\n").split("\t")
        fun.append((int(t[0], 16), t[1], t[2], t[3], t[4], t[5]))
    fun.sort()
    cov = set(int(l, 16) for l in open(sys.argv[2]))
    ram = open(sys.argv[3], "rb").read()
    out = sys.argv[4]
    os.makedirs(out, exist_ok=True)
    names = {a: n for a, n, *_ in fun}
    idx = open(os.path.join(out, "indice.tsv"), "w")
    idx.write("addr64\tname\tpc\tcpc6128\ttimes\tlines\texecuted\tfile\n")
    for i, (a, name, pc, c128, times, callers) in enumerate(fun):
        end = min(fun[i + 1][0] if i + 1 < len(fun) else a + 0x100, a + 0x300)
        with tempfile.NamedTemporaryFile(suffix=".bin") as f:
            f.write(ram[a:end]); f.flush()
            d = subprocess.run(["z80dasm", "-a", "-g", hex(a), f.name], capture_output=True, text=True).stdout
        lines = []
        ex = 0
        for l in d.splitlines():
            m = re.match(r"\t(.*?)\s*;([0-9a-f]{4})$", l)
            if not m: continue
            ad = int(m.group(2), 16)
            txt = m.group(1)
            def nm(mm):
                v = int(mm.group(1), 16)
                return f"{names[v]}" if v in names else mm.group(0)
            txt = re.sub(r"\b0?([0-9a-f]{4})h\b", lambda mm: nm(mm) if re.match(r"(call|jp)", txt) else mm.group(0), txt)
            mark = "*" if ad in cov else " "
            ex += ad in cov
            lines.append(f"{ad:04X} {mark} {txt}")
        fn = f"{a:04X}_{name}.asm"
        with open(os.path.join(out, fn), "w") as f:
            f.write(f"; {name} at {a:04X} (64K)   PC: {pc or '-'}   CPC 6128: {c128 or '-'}   called {times} times by {callers or '-'}\n")
            f.write("; '*' = executed in the exploration sessions; the listing runs to the next known entry\n")
            f.write("\n".join(lines) + "\n")
        idx.write(f"{a:04X}\t{name}\t{pc}\t{c128}\t{times}\t{len(lines)}\t{ex}\t{fn}\n")
    idx.close()
    print(f"{len(fun)} functions listed in {out}")


if __name__ == "__main__":
    main()
