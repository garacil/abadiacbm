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

"""The data addresses of the full game (PC data space) in the CPC 64 KiB version, found through the
code: the PC program is a mechanical translation of the Z80 program, so a PC function and its Z80
original refer to their data in the same order.

    mapa_por_codigo.py OUT.tsv

Steps: (1) the Z80 instructions of the 6128 game that equal those of the 64 KiB game (normalised
linear disassembly, difflib; difcodigo_total.py) give 128K -> 64K code addresses; (2) the PC functions
whose description names their CPC (6128) address (data/re/anotaciones/*/funciones.tsv of the full
project) get a 64K address; (3) in each such pair, the sequence of absolute data operands and 16-bit
immediates of the PC function (objdump, 8086) and of the Z80 function (z80dasm) are aligned by kind
(memory / immediate) and every aligned pair votes for "PC address -> CPC 64 KiB address".
The output lists every voted PC address with its best CPC address, its votes and the runner-up.
"""
import bisect, collections, difflib, glob, os, re, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from difcodigo import disasm, norm

ABADIA = os.environ.get("ABADIA_PC", os.path.expanduser("~/Proyectos/abadia"))
T = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")
M64 = open(os.path.join(T, "cpc64", "juego", "ram.bin"), "rb").read()
M128 = open(os.path.join(T, "cpc128", "memoria.bin"), "rb").read()
PC = open(os.path.join(ABADIA, "trabajo", "re", "listado", "programa.bin"), "rb").read()


def code_map():
    """pairs (a128, a64) of equal instructions"""
    A, B = disasm(M64, 0x0100, 0x5FFF), disasm(M128, 0x0100, 0x7FFF)
    sm = difflib.SequenceMatcher(None, [norm(t) for _, t in A], [norm(t) for _, t in B], autojunk=False)
    pairs = []
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal":
            for k in range(i2 - i1):
                pairs.append((B[j1 + k][0], A[i1 + k][0]))
    pairs.sort()
    return pairs


def pc_functions():
    out = []
    for f in glob.glob(os.path.join(ABADIA, "trabajo", "re", "anotaciones", "*", "funciones.tsv")):
        for line in open(f):
            if line.startswith("#") or "\t" not in line: continue
            t = line.rstrip("\n").split("\t")
            if len(t) < 3 or not t[0].startswith("1000:"): continue
            m = re.search(r"(?:Matches |matches |CPC[ :]*)(?:CPC )?(?:0x)?([0-9A-F]{4})", t[2])
            out.append((int(t[0][5:], 16), t[1], int(m.group(1), 16) if m else None))
    return sorted(out)


def pc_operands(a, b):
    d = subprocess.run(["objdump", "-D", "-b", "binary", "-m", "i8086", "-M", "intel",
                        f"--start-address={a}", f"--stop-address={b}", os.path.join(ABADIA, "trabajo", "re", "listado", "programa.bin")],
                       capture_output=True, text=True).stdout
    ops = []
    for line in d.splitlines():
        m = re.match(r"\s*[0-9a-f]+:\s+(?:[0-9a-f]{2} )+\s*(\S.*)$", line)
        if not m: continue
        ins = m.group(1)
        if re.match(r"(call|jmp|j\w+|loop)\b", ins): continue
        for mm in re.finditer(r"ds:0x([0-9a-f]+)|\[0x([0-9a-f]+)\]", ins):
            ops.append(("m", int(mm.group(1) or mm.group(2), 16)))
        mm = re.match(r"mov\s+(bx|si|di|dx|cx|bp|ax),0x([0-9a-f]{3,4})$", ins)
        if mm and int(mm.group(2), 16) >= 0x100:
            ops.append(("i", int(mm.group(2), 16)))
    return ops


def z80_operands(a, b):
    ops = []
    for addr, t in disasm(M64, a, b):
        if re.match(r"(call|jp|jr|djnz|rst)\b", t): continue
        for mm in re.finditer(r"\(0?([0-9a-f]{3,4})h\)", t):
            ops.append(("m", int(mm.group(1), 16)))
        mm = re.match(r"ld (hl|de|bc|ix|iy|sp),0?([0-9a-f]{3,4})h$", t)
        if mm and int(mm.group(2), 16) >= 0x100:
            ops.append(("i", int(mm.group(2), 16)))
    return ops


def main():
    pairs = code_map()
    keys = [p[0] for p in pairs]
    def to64(c):
        i = bisect.bisect_left(keys, c)
        if i < len(keys) and keys[i] - c < 4: return pairs[i][1] - (keys[i] - c)
        return None
    funcs = pc_functions()
    starts = [f[0] for f in funcs]
    z_starts = sorted(to64(f[2]) for f in funcs if f[2] is not None and to64(f[2]) is not None)
    votes = collections.defaultdict(collections.Counter)
    used = 0
    for idx, (a, name, c128) in enumerate(funcs):
        if c128 is None: continue
        z = to64(c128)
        if z is None: continue
        b = starts[idx + 1] if idx + 1 < len(starts) else a + 0x100
        j = bisect.bisect_right(z_starts, z)
        zb = z_starts[j] if j < len(z_starts) else z + 0x100
        if zb - z > 0x400 or b - a > 0x800: continue
        po, zo = pc_operands(a, b), z80_operands(z, zb - 1)
        sm = difflib.SequenceMatcher(None, [k for k, v in po], [k for k, v in zo], autojunk=False)
        for tag, i1, i2, j1, j2 in sm.get_opcodes():
            if tag in ("equal", "replace") and i2 - i1 == j2 - j1:
                for k in range(i2 - i1):
                    votes[po[i1 + k][1]][zo[j1 + k][1]] += 1
        used += 1
    with open(sys.argv[1], "w") as f:
        f.write("# PC data address -> CPC 64 KiB address, voted by aligned operands (mapa_por_codigo.py)\n")
        f.write("pc\tcpc64\tvotes\ttotal\trunner_up\n")
        for p in sorted(votes):
            (best, n), *rest = votes[p].most_common(2) + [(None, 0)]
            tot = sum(votes[p].values())
            ru = rest[0]
            f.write(f"{p:04X}\t{best:04X}\t{n}\t{tot}\t{'' if ru[0] is None else format(ru[0], '04X')}:{ru[1]}\n")
    strong = sum(1 for p in votes if votes[p].most_common(1)[0][1] >= 2 and votes[p].most_common(1)[0][1] * 2 > sum(votes[p].values()))
    print(f"function pairs used {used}; PC addresses voted {len(votes)}; with >= 2 votes and a majority {strong}")


if __name__ == "__main__":
    main()
