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

"""What the 6502 game never uses: the union of the addresses the host's 6502 read, wrote or executed over several
runs (juego/hibrido --juego6502 DIR --usados6502 F, one file per run), against the build's segments (juego.map),
its labels (juego.lbl) and the data map (mapa64.tsv).

    usados64.py [--juego DIR] USADOS... [--accesos F...]

Reports: the totals; per segment the bytes never used; the code never executed, by routine (the label below each
run); the data blocks never read (dead data), never written and never touched; the never-touched ranges inside
the image; and, with the Z80's --accesos files of the same runs, the copied data blocks (mode copia) whose bytes
the Z80 read and the 6502 did not, or the reverse: a byte-for-byte cross-check of the data footprint.
Everything is an upper bound of the unused set: an address none of the given runs touched (the runs do not play
the ending nor the save/load menu unless their scripts do).
"""
import os, sys, bisect

R, W, X = 1, 2, 4
args = sys.argv[1:]
jdir = os.path.dirname(os.path.realpath(__file__))
accesos = []
usados = []
while args:
    a = args.pop(0)
    if a == "--juego": jdir = args.pop(0)
    elif a == "--accesos": accesos = [x for x in args if not x.startswith("--")]; args = [x for x in args if x.startswith("--")]
    else: usados.append(a)
if not usados: sys.exit(__doc__)

u = bytearray(0x10000)
for f in usados:
    for l in open(f):
        a, fl = l.split()
        u[int(a, 16)] |= (R if "r" in fl else 0) | (W if "w" in fl else 0) | (X if "x" in fl else 0)
# the core marks the opcode byte of every instruction executed: its operand bytes are marked from the image and the
# 6502's instruction lengths (self-modifying code aside: the instruction as the image holds it)
img = open(os.path.join(jdir, "juego.bin"), "rb").read()
def longitud(op):
    c, alto = op & 0x0F, op & 0x10
    if c == 0: return {0x00: 1, 0x20: 3, 0x40: 1, 0x60: 1}.get(op, 2)
    if c == 2: return 2 if op in (0x82, 0xA2, 0xC2, 0xE2) else 1
    if c in (1, 3, 4, 5, 6, 7): return 2
    if c in (8, 0xA): return 1
    if c in (9, 0xB): return 3 if alto else 2
    return 3
for k in range(0x10000):
    if u[k] & X:
        for j in range(1, longitud(img[k])): u[(k + j) & 0xFFFF] |= X
z = bytearray(0x10000)                              # the Z80's data accesses (CPC addresses)
for f in accesos:
    for l in open(f):
        a, fl = l.split()
        z[int(a, 16)] |= (R if "r" in fl else 0) | (W if "w" in fl else 0)

# the build: segments, labels, the data blocks
segs = []
en = False
for l in open(os.path.join(jdir, "juego.map")):
    if l.startswith("Segment list:"): en = True; continue
    if en and (l.startswith("Exports list") or l.startswith("Imports list")): break
    p = l.split()
    if en and len(p) >= 4 and p[0] not in ("Name", "Segment") and not p[0].startswith("-"):
        try: segs.append((p[0], int(p[1], 16), int(p[2], 16)))
        except ValueError: pass
segs.sort(key=lambda s: s[1])
labels = []
for l in open(os.path.join(jdir, "juego.lbl")):
    p = l.split()
    if len(p) == 3 and p[0] == "al":
        n = p[2].lstrip(".")
        if "@" not in n and not n.startswith("__"): labels.append((int(p[1], 16), n))
labels.sort()
laddr = [a for a, _ in labels]
def label(a):
    i = bisect.bisect_right(laddr, a) - 1
    return labels[i][1] if i >= 0 and labels[i][0] <= a else "?"
bloques = []
for l in open(os.path.join(jdir, "mapa64.tsv")):
    if l.startswith("#"): continue
    p = l.rstrip("\n").split("\t")
    if len(p) < 8: continue
    cpc = int(p[1], 16) if p[1] not in ("", "-") else -1
    bloques.append(dict(nombre=p[0], cpc=cpc, lcpc=int(p[2]), c64=int(p[3], 16), l64=int(p[4]), modo=p[5], zona=p[6], tipo=p[7]))

def rangos(pred, lo=0, hi=0x10000):
    """the maximal runs [a, b) of addresses in [lo, hi) with pred(a)"""
    out, a = [], None
    for k in range(lo, hi + 1):
        if k < hi and pred(k):
            if a is None: a = k
        elif a is not None: out.append((a, k)); a = None
    return out

print(f"runs: {len(usados)}; build: {jdir}")
usado = sum(1 for k in range(0x10000) if u[k])
print(f"addresses used {usado} (executed {sum(1 for k in range(0x10000) if u[k] & X)}, read "
      f"{sum(1 for k in range(0x10000) if u[k] & R)}, written {sum(1 for k in range(0x10000) if u[k] & W)}), never used {0x10000 - usado}")

print("\n== segments: bytes never used (read, written or executed) / size")
total_cod_sin = 0
for n, s, e in segs:
    sz = e - s + 1
    sin = sum(1 for k in range(s, e + 1) if not u[k])
    sinx = sum(1 for k in range(s, e + 1) if not u[k] & X)
    cod = any(u[k] & X for k in range(s, e + 1))
    if cod: total_cod_sin += sinx
    if sin or (cod and sinx):
        print(f"  {n:28s} {s:04X}-{e:04X} {sz:6d}  never used {sin:5d}" + (f"  never executed {sinx:5d}" if cod else ""))
print(f"  code never executed in all the segments with code: {total_cod_sin} bytes")

print("\n== code never executed, by routine (the label ranges inside the segments with code; whole = every byte)")
codigo = [(s, e) for n, s, e in segs if any(u[k] & X for k in range(s, e + 1))]
filas = []
for s, e in codigo:
    i = max(bisect.bisect_right(laddr, s) - 1, 0)
    while i < len(labels) and labels[i][0] <= e:
        la = max(labels[i][0], s)
        lb = min(labels[i + 1][0] if i + 1 < len(labels) else e + 1, e + 1)
        if lb > la:
            sin = [k for k in range(la, lb) if not u[k] & X]
            if sin: filas.append((labels[i][1], len(sin), lb - la, sin[0]))
        i += 1
for n, sz, tam, a in sorted(filas, key=lambda x: -x[1]):
    print(f"  {n:36s} {sz:5d} bytes" + ("  whole" if sz >= tam else f"  of {tam}") + f"  from {a:04X}")
print(f"  routines with code never executed: {len(filas)}, whole: {sum(1 for f in filas if f[1] >= f[2])}")

print("\n== data blocks (mapa64.tsv): never read / never written / never touched")
muertos, intactos, solo_escritos = [], [], []
for b in bloques:
    s, e = b["c64"], b["c64"] + b["l64"]
    nr = sum(1 for k in range(s, e) if not u[k] & R)
    nw = sum(1 for k in range(s, e) if not u[k] & W)
    nt = sum(1 for k in range(s, e) if not u[k])
    b.update(nr=nr, nw=nw, nt=nt)
    if nt == b["l64"]: intactos.append(b)
    elif nr == b["l64"]: solo_escritos.append(b)
print(f"  blocks {len(bloques)}, bytes {sum(b['l64'] for b in bloques)}; never touched (any byte) "
      f"{sum(b['nt'] for b in bloques)}, never read {sum(b['nr'] for b in bloques)}, never written {sum(b['nw'] for b in bloques)}")
print("  blocks never touched at all:")
for b in intactos: print(f"    {b['nombre']:36s} {b['c64']:04X} {b['l64']:5d}  {b['zona']}/{b['tipo']}")
print("  blocks written but never read (dead data):")
for b in solo_escritos: print(f"    {b['nombre']:36s} {b['c64']:04X} {b['l64']:5d}  {b['zona']}/{b['tipo']}")
print("  blocks partly never touched (bytes never touched / size), 8 bytes or more:")
for b in sorted(bloques, key=lambda b: -b["nt"]):
    if 0 < b["nt"] < b["l64"] and b["nt"] >= 8:
        print(f"    {b['nombre']:36s} {b['c64']:04X} {b['nt']:5d} / {b['l64']:5d}")

print("\n== never-touched ranges of 16 bytes or more inside the image's segments and blocks")
dentro = bytearray(0x10000)
for n, s, e in segs:
    for k in range(s, e + 1): dentro[k] = 1
for b in bloques:
    for k in range(b["c64"], b["c64"] + b["l64"]): dentro[k] = 1
for a, b_ in rangos(lambda k: dentro[k] and not u[k]):
    if b_ - a >= 16:
        que = [n for n, s, e in segs if s <= a <= e] + [b["nombre"] for b in bloques if b["c64"] <= a < b["c64"] + b["l64"]]
        print(f"  {a:04X}-{b_ - 1:04X} {b_ - a:5d}  {label(a)}  {' '.join(que)}")

if accesos:
    print("\n== cross-check with the Z80 (--accesos): copied data blocks, byte for byte")
    print("  (CPC byte read by the Z80 but its C64 byte not read by the 6502: 'z80 only'; the reverse: '6502 only')")
    d = 0
    for b in bloques:
        if b["modo"] != "copia" or b["cpc"] < 0 or b["lcpc"] != b["l64"]: continue
        z_solo = sum(1 for i in range(b["l64"]) if z[b["cpc"] + i] & R and not u[b["c64"] + i] & R)
        c_solo = sum(1 for i in range(b["l64"]) if u[b["c64"] + i] & R and not z[b["cpc"] + i] & R)
        if z_solo or c_solo:
            d += 1
            print(f"    {b['nombre']:36s} {b['cpc']:04X}->{b['c64']:04X} {b['l64']:5d}  z80 only {z_solo:5d}  6502 only {c_solo:5d}")
    print(f"  copied blocks with a difference: {d} of {sum(1 for b in bloques if b['modo'] == 'copia')}")
