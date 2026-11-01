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

"""The inventory of the game's data for the C64 (H3): every block of src/c64/juego/bloques64.tsv (and the
graphics of data/c64graf/graficos64.tsv), with what the 8 exploration sessions measured, and every other
range of the CPC 64 KiB memory with the reason it is not needed on the C64.

    inventario64.py        -> data/datos64_inventario.tsv; checks printed (exit 1 when one fails)

Checks: the blocks do not overlap; every D64_ address of src/juego/datos_*.h lies in a block, in the Z80 code
or in a range declared not needed; every byte the sessions accessed as data (data/cpc64/accesos) lies
in a block or in a declared range.  Inputs: data/cpc64/particion64.bin (particion64.py),
data/cpc64/accesos/quien.tsv (quien64.py), src/c64/juego/punteros64.tsv when present.
"""
import glob, os, re, sys

P = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
C = os.path.join(P, "data", "cpc64")

# ranges of the CPC memory that hold no datum the C64 needs, with the reason (start, end inclusive)
NO = [
    (0x0000, 0x00FD, "RST vectors and the firmware's low page: the 6502 calls the RST helpers by JSR, its own vectors"),
    (0x00FF, 0x0102, "the tape loader's jump (0100h)"),
    (0x01AA, 0x0200, "the rest of the tape loader (0200h is JP 20BEh at load, then data)"),
    (0x3D2A, 0x3D2F, "6 bytes of a 6128 table nothing reads"),
    (0x128D, 0x128E, "the block table's entry of type B0h (no room uses it; the next ones overlap the code at 128Fh)"),
    (0x1BDB, 0x1BDB, "1 byte before the block interpreter's registers, never accessed"),
    (0x1E4A, 0x1E4A, "dead Z80 code: an unreachable byte between routines"),
    (0x221E, 0x2225, "dead Z80 code: LD BC,7F89h / OUT (C),C / JP 0591h, never reached (a 6128 leftover)"),
    (0x254F, 0x2552, "dead Z80 code: LD (IY+4),E / RET after a JR, never reached"),
    (0x30FC, 0x30FC, "dead Z80 code: a RET after chr_pos_ptrs, never reached"),
    (0x3567, 0x3567, "dead Z80 code: a second RET, never reached"),
    (0x3A82, 0x3A82, "dead Z80 code: a RET after the palettes, never reached"),
    (0x3DA7, 0x3DA7, "dead Z80 code: a RET after inline data, never reached"),
    (0x40E7, 0x40EA, "dead bytes after a RET (C4 A9 1E 63), never reached"),
    (0x442E, 0x4430, "dead Z80 code: JP 20BEh before the robe table, never reached"),
    (0x564D, 0x564E, "dead bytes in the monk scripts (JR after a RET), never reached"),
    (0x5A4E, 0x5A4E, "dead bytes in the monk scripts (a second RET), never reached"),
    (0x5A56, 0x5A57, "dead bytes in the monk scripts (JR after a RET), never reached"),
    (0x5A74, 0x5A74, "dead bytes in the monk scripts, never reached"),
    (0x5DD3, 0x5DD4, "dead bytes in the monk scripts (JR after a RET), never reached"),
    (0x5EF3, 0x5EF4, "dead bytes in the monk scripts (JR after a RET), never reached"),
    (0x446F, 0x4470, "2 bytes after the light pattern (the 6128's 16th row), never read"),
    (0x4ACF, 0x4ACF, "1 byte before the hour durations, never read"),
    (0x328B, 0x3292, "8 bytes nothing reads (between 328A RET and the tape code)"),
    (0x6000, 0x60FF, "the end of the monk scripts is code (6000h-60F5h); 60F6h-60FFh dead bytes"),
    (0x7F31, 0x7F7F, "after the ground-floor heights: leftover bytes"),
    (0x9F3A, 0x9F5F, "after the first-floor heights: zeros"),
    (0xB06E, 0xB102, "the tail of a dead copy of the robes: a new game copies AB59h-AE2Dh to AE2Eh (2126h, LDIR 2D5h) and "
                     "flips it; the height buffer overwrites AE2E-B06D and nothing draws from B06E-B102 (the robes are "
                     "mirrored while drawing, bit 14 of their pointers)"),
    (0xA2F5, 0xA2FF, "after the library heights and the mirror's entry"),
    (0xB570, 0xB57F, "16 bytes between the font and the words (a graphics fragment), never read"),
    (0xBA69, 0xBAFF, "after the last word: zeros"),
    (0xBE9C, 0xBF48, "after the 56th phrase: leftover phrases and stack filler, never read"),
    (0xBF53, 0xBFFF, "the Z80 stack (SP = C000h); the 6502 has its own at $0100"),
    (0xC000, 0xFFFF, "the CPC screen: the visible part becomes the C64 bitmap $E000 + screen RAM $C000; the hidden "
                     "parts (offsets 600h-7FFh of each 2 KiB line block) hold the tiles 00h-7Fh after the start-up "
                     "(they are converted and placed at $D000 directly) and, at load, the score bar's source "
                     "(converted, init-only)"),
]
# inside the graphics area: ranges the graphics conversion may leave out are reported by c64_graficos.py

def carga_bloques():
    b = []
    for l in open(os.path.join(P, "src", "c64", "juego", "bloques64.tsv")):
        if l.startswith("#") or not l.strip(): continue
        x = l.rstrip("\n").split("\t")
        b.append(dict(nombre=x[0], cpc=None if x[1] == "-" else int(x[1], 16), len=int(x[2]), tipo=x[3], zona=x[4],
                      modo=x[5], alin=int(x[6]), desc=x[7] if len(x) > 7 else "", len64=int(x[2])))
    g = os.path.join(P, "data", "c64graf", "graficos64.tsv")
    if os.path.exists(g):
        for l in open(g):
            if l.startswith("#") or not l.strip() or l.startswith("name"): continue
            x = l.rstrip("\n").split("\t")
            b.append(dict(nombre=x[0], cpc=None if x[1] in ("-", "") else int(x[1], 16), len=int(x[2]) if x[2] not in ("-", "") else 0,
                          tipo="graf", zona="graf", modo="conv", alin=1, desc=(x[4] + "; " + x[-1]) if len(x) > 5 else "",
                          len64=int(x[3])))
    return b

def main():
    bloques = carga_bloques()
    part = open(os.path.join(C, "particion64.bin"), "rb").read()
    acc = {}
    for f in glob.glob(os.path.join(C, "accesos", "azar*.txt")):
        for l in open(f):
            if l.startswith("#"): continue                  # (my licence header)
            a, fl = l.split(); a = int(a, 16)
            acc[a] = acc.get(a, 0) | (1 if "r" in fl else 0)
    quien = {}
    for l in open(os.path.join(C, "accesos", "quien.tsv")):
        if l[0] == "#": continue
        a, f = l.rstrip("\n").split("\t"); a = int(a, 16)
        quien[a] = [x.rsplit(":", 1) for x in f.split()]
        if any("w" in fl for n, fl in quien[a]): acc[a] = acc.get(a, 0) | 2
    nombres = {}
    for f in sorted(glob.glob(os.path.join(P, "src", "juego", "datos_*.h"))):
        for l in open(f):
            m = re.match(r"#define\s+(D64_\w+)\s+0x([0-9A-Fa-f]{1,4})u?\b", l)
            if m: nombres.setdefault(int(m.group(2), 16), set()).add(m.group(1))
    punteros = {}
    pt = os.path.join(P, "src", "c64", "juego", "punteros64.tsv")
    if os.path.exists(pt):
        for l in open(pt):
            if l.startswith("#") or not l.strip(): continue
            x = l.split("\t"); punteros.setdefault(x[1], 0); punteros[x[1]] += 1
    fallos = 0
    # overlaps
    cub = {}
    for b in bloques:
        if b["cpc"] is None or b["zona"] == "graf" and b["len"] == 0: continue
        for a in range(b["cpc"], b["cpc"] + b["len"]):
            if a in cub and b["zona"] != "graf" and cub[a]["zona"] != "graf":
                print(f"OVERLAP {a:04X}: {cub[a]['nombre']} and {b['nombre']}"); fallos += 1
            cub.setdefault(a, b)
    def no_needed(a):
        for s, e, r in NO:
            if s <= a <= e: return r
        return None
    # D64_ names
    for a, ns in sorted(nombres.items()):
        if a in cub or part[a] in (1, 2) or no_needed(a): continue
        if a < 0x100 and a not in (0xFE,): continue          # small constants (opcodes, sizes)
        print(f"NAME OUTSIDE {a:04X} {' '.join(sorted(ns))}"); fallos += 1
    # accessed bytes
    sueltos = [a for a in sorted(acc) if a not in cub and part[a] != 1 and not no_needed(a) and part[a] != 2]
    if sueltos:
        r, s, e = [], sueltos[0], sueltos[0]
        for a in sueltos[1:]:
            if a == e + 1: e = a
            else: r.append((s, e)); s = e = a
        r.append((s, e))
        for s, e in r: print(f"ACCESSED OUTSIDE {s:04X}-{e:04X}"); fallos += 1
    # the inventory
    out = ["# The game's data on the C64 (inventario64.py): blocks of src/c64/juego/bloques64.tsv and data/c64graf/graficos64.tsv,",
           "# then the ranges not needed.  read/written: bytes of the block the 8 sessions read / wrote as data; readers/writers:",
           "# the functions (data/cpc64/accesos/quien.tsv); pointers: pointer fields inside it (src/c64/juego/punteros64.tsv).",
           "name\tcpc_start\tcpc_end\tlen\tlen_c64\tkind\tzone\tmode\tread\twritten\treaders\twriters\tnames\tpointers\tdesc"]
    for b in sorted(bloques, key=lambda b: (b["cpc"] is None, b["cpc"] or 0)):
        if b["cpc"] is None:
            out.append(f"{b['nombre']}\t-\t-\t0\t{b['len64']}\t{b['tipo']}\t{b['zona']}\t{b['modo']}\t0\t0\t\t\t\t0\t{b['desc']}")
            continue
        rng = range(b["cpc"], b["cpc"] + b["len"])
        r = sum(1 for a in rng if acc.get(a, 0) & 1); w = sum(1 for a in rng if acc.get(a, 0) & 2)
        lec, esc = set(), set()
        for a in rng:
            for n, fl in quien.get(a, []):
                if "r" in fl: lec.add(n)
                if "w" in fl: esc.add(n)
        ns = sorted(n for a in rng for n in nombres.get(a, ()))
        out.append(f"{b['nombre']}\t{b['cpc']:04X}\t{b['cpc'] + max(b['len'], 1) - 1:04X}\t{b['len']}\t{b['len64']}\t{b['tipo']}\t{b['zona']}\t"
                   f"{b['modo']}\t{r}\t{w}\t{' '.join(sorted(lec))}\t{' '.join(sorted(esc))}\t{' '.join(ns)}\t{punteros.get(b['nombre'], 0)}\t{b['desc']}")
    # not needed: the complement of the blocks in 0000-BFFF, by kind
    out.append("# not needed on the C64")
    a = 0
    tot = {"code": 0, "inline": 0, "other": 0}
    while a < 0x10000:
        if a in cub: a += 1; continue
        if a >= 0xC000:
            out.append(f"-\tC000\tFFFF\t16384\t0\tscreen\t-\tno\t\t\t\t\t\t0\t{no_needed(0xC000)}"); break
        k = "code" if part[a] == 1 else "inline" if part[a] == 2 else "other"
        e = a
        while e + 1 < 0xC000 and e + 1 not in cub and ("code" if part[e + 1] == 1 else "inline" if part[e + 1] == 2 else "other") == k \
                and (k != "other" or no_needed(e + 1) == no_needed(a)):
            e += 1
        why = {"code": "Z80 code (becomes 6502 code)",
               "inline": "data inline in the Z80 code (script expressions after RST 08h/10h, inline call data, texts): it moves with the code"}.get(k)
        if k == "other": why = no_needed(a) or "UNEXPLAINED"
        if why == "UNEXPLAINED" and a >= 0x8300 and a <= 0xB3FF: why = "graphics area: see data/c64graf/graficos64.tsv (converted blocks) and src/c64/NOTAS_GRAFICOS.md"
        tot[k] += e - a + 1
        out.append(f"-\t{a:04X}\t{e:04X}\t{e - a + 1}\t0\t{k}\t-\tno\t\t\t\t\t\t0\t{why}")
        a = e + 1
    open(os.path.join(P, "data", "datos64_inventario.tsv"), "w").write("\n".join(out) + "\n")
    nb = sum(1 for b in bloques)
    print(f"{nb} blocks, {sum(b['len'] for b in bloques if b['cpc'] is not None)} CPC bytes -> {sum(b['len64'] for b in bloques)} C64 bytes; "
          f"not needed below C000h: code {tot['code']}, inline {tot['inline']}, other {tot['other']}; {fallos} problems")
    return 1 if fallos else 0

sys.exit(main())
