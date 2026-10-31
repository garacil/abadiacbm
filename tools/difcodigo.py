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

"""Instruction-level differences between the executed code of one Z80 image and another image.

    difcodigo.py IMG_A COVERAGE_A IMG_B [--b-desde 0100 --b-hasta 7FFF] > diferencias.txt

IMG_A's code is disassembled (z80dasm) run by run from its executed addresses; IMG_B is disassembled
linearly.  Instructions are normalised (16-bit numbers -> NN, so relocated addresses do not count;
8-bit constants, opcodes and relative jumps do), each run of A is anchored in B through normalised
4-instruction keys, and the two sequences are compared with difflib.  Only differences are printed.
"""
import collections, difflib, os, re, subprocess, sys, tempfile

NUM16 = re.compile(r"\b0?([0-9a-f]{3,4})h\b")


def disasm(mem, start, end):
    with tempfile.NamedTemporaryFile(suffix=".bin") as f:
        f.write(mem[start:end + 1]); f.flush()
        out = subprocess.run(["z80dasm", "-a", "-g", hex(start), f.name], capture_output=True, text=True).stdout
    ins = []
    for line in out.splitlines():
        if not line.startswith("\t") or ";" not in line:
            continue
        text, addr = line.strip().rsplit(";", 1)
        ins.append((int(addr.strip(), 16), " ".join(text.split())))
    return ins


def norm(t):
    t = NUM16.sub(lambda m: "NN" if int(m.group(1), 16) > 0xFF else m.group(0), t)
    return t


def main():
    a, b = open(sys.argv[1], "rb").read(), open(sys.argv[3], "rb").read()
    pcs = sorted(int(l, 16) for l in open(sys.argv[2]) if 0x100 <= int(l, 16) < 0xC000)
    blo = int(sys.argv[sys.argv.index("--b-desde") + 1], 16) if "--b-desde" in sys.argv else 0x0100
    bhi = int(sys.argv[sys.argv.index("--b-hasta") + 1], 16) if "--b-hasta" in sys.argv else 0x7FFF
    B = disasm(b, blo, bhi)
    Bn = [norm(t) for _, t in B]
    key = collections.defaultdict(list)
    for i in range(len(Bn) - 3):
        key[tuple(Bn[i:i + 4])].append(i)
    runs, s, prev = [], None, None
    for p in pcs:
        if s is None: s = p
        elif p > prev + 4: runs.append((s, prev)); s = p
        prev = p
    runs.append((s, prev))
    same = changed = unanchored = 0
    for ra, rb in runs:
        A = [x for x in disasm(a, ra, min(rb + 3, 0xFFFF)) if x[0] <= rb]
        if not A:
            continue
        An = [norm(t) for _, t in A]
        votes = collections.Counter()
        for i in range(len(An) - 3):
            for j in key.get(tuple(An[i:i + 4]), [])[:6]:
                votes[j - i] += 1
        if not votes:
            unanchored += len(A)
            print(f"== A {ra:04X}-{rb:04X}: not found in B ({len(A)} instructions)")
            for ad, t in A[:12]:
                print(f"   A {ad:04X} {t}")
            continue
        d = votes.most_common(1)[0][0]
        j0 = max(0, d - 4)
        Bw = Bn[j0:j0 + len(An) + 12]
        sm = difflib.SequenceMatcher(None, An, Bw, autojunk=False)
        ops = [o for o in sm.get_opcodes() if o[0] != "equal"]
        eq = sum(i2 - i1 for t, i1, i2, _, _ in sm.get_opcodes() if t == "equal")
        same += eq
        # leading/trailing inserts in B are just window slack
        ops = [o for o in ops if not (o[0] == "insert" and (o[1] == 0 or o[1] == len(An)))]
        if not ops:
            continue
        changed += len(A) - eq
        print(f"== A {ra:04X}-{rb:04X} ~ B {B[j0 + ops[0][3]][0] if ops[0][3] < len(Bw) else B[j0][0]:04X}")
        for t, i1, i2, k1, k2 in ops:
            la = [f"{A[i][0]:04X} {A[i][1]}" for i in range(i1, i2)]
            lb = [f"{B[j0 + k][0]:04X} {B[j0 + k][1]}" for k in range(k1, k2)]
            print(f"   {t}: A [{'; '.join(la)}]  B [{'; '.join(lb)}]")
    print(f"# instructions equal {same}, differing {changed}, unanchored {unanchored}")


if __name__ == "__main__":
    main()
