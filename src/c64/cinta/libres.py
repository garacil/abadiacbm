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

"""Which bytes of the game image the game does not need at its start (c64/cinta/FLUJO.md, "What the loader
leaves out"), checked with the hybrid host: a copy of the checked build (c64/juego_final, the host's juego.bin)
with those bytes garbled, the whole 6502 game run against the Z80 frame by frame (hibrido --juego6502), every
session; 0 differences = the game never reads them before writing them.

    libres.py [--sesiones N] [--tablas]

The candidates are the C64 build's holes (c64/juego_final/c64/juego.map: every byte outside its segments, the
BSS included: the stack page, the zero page outside the game's operands, $079D-$07FF, the BSS and the gap
before $7151, the screen RAM, $CFFD-$CFFF, $DFEA-$DFFF, the bitmap's free invisible bytes and the vectors) plus
the host build's own BSS, and the two 'nada' buffers ISO_VM_STACK and SPR_SORTED_LIST ($C800-$C86F).  The
play area (rows 0-19, cells 4-35) is left alone: the host fills it from the CPC screen (pantalla_a_bitmap).

--tablas garbles only the merge tables (the 'conv' blocks of mapa64.tsv that vid_init_stub 3607 rebuilds:
$BB00-$BFFF, $C400-$C7FF, $EA06-$EA15).  The host compares a 'conv' block with the image it read, so the
expected result is the opposite: differences in those blocks only, the 6502's value being the original byte
(the game rebuilt the table at its start-up), and none anywhere else.

The copy is a tree of links to the project with c64/<scratch> at the depth of c64/juego_final (the host reads
../datos and ../../../data from the build directory), removed at the end.  Deterministic: the garbling pattern
is a fixed pseudo-random sequence.
"""
import os, random, re, shutil, subprocess, sys

D = os.path.dirname(os.path.realpath(__file__))
P = os.path.dirname(os.path.dirname(D))
FINAL = os.path.join(P, "c64", "juego_final")


def segmentos(mapa):
    """ld65 map -> [(name, first, last)]"""
    out, dentro = [], False
    for linea in open(mapa):
        if linea.startswith("Segment list"):
            dentro = True
            continue
        if dentro:
            t = linea.split()
            if len(t) >= 4 and re.fullmatch(r"[0-9A-F]{6}", t[1]):
                out.append((t[0], int(t[1], 16), int(t[2], 16)))
            elif linea.startswith("Exports"):
                break
    return out


def area_juego(a):
    """the play area: rows 0-19, cells 4-35 of the bitmap at $E000"""
    if not 0xE000 <= a < 0xE000 + 20 * 320:
        return False
    return 32 <= (a - 0xE000) % 320 < 288


def tablas():
    out = []
    for linea in open(os.path.join(FINAL, "mapa64.tsv")):
        t = linea.rstrip("\n").split("\t")
        if len(t) >= 8 and t[5] == "conv" and t[0].startswith("tabla_"):
            out.append((int(t[3], 16), int(t[4])))
    return out


def candidatos():
    usado = bytearray(0x10000)
    for n, s, e in segmentos(os.path.join(FINAL, "c64", "juego.map")):
        if n != "BSS":
            usado[s:e + 1] = b"\1" * (e - s + 1)
    libre = [a for a in range(2, 0x10000) if not usado[a] and not area_juego(a)]
    for n, s, e in segmentos(os.path.join(FINAL, "juego.map")):     # the host build's own BSS
        if n == "BSS":
            libre += range(s, e + 1)
    libre += range(0xC800, 0xC870)                                   # ISO_VM_STACK, SPR_SORTED_LIST ('nada')
    return sorted(set(libre))


def tramos(dirs):
    out = []
    for a in dirs:
        if out and out[-1][1] == a - 1:
            out[-1][1] = a
        else:
            out.append([a, a])
    return out


def main():
    sesiones = 8
    solo_tablas = "--tablas" in sys.argv
    if "--sesiones" in sys.argv:
        sesiones = int(sys.argv[sys.argv.index("--sesiones") + 1])
    if solo_tablas:
        dirs = sorted(a for ini, n in tablas() for a in range(ini, ini + n))
    else:
        dirs = candidatos()
    print(f"{len(dirs)} bytes garbled in {len(tramos(dirs))} ranges:")
    print("  " + " ".join(f"{s:04X}-{e:04X}" for s, e in tramos(dirs)))
    T = os.path.join(P, "c64", f"disco_libres_{os.getpid()}")
    os.makedirs(T)
    try:
        for x in os.listdir(FINAL):
            if x != "juego.bin":
                os.symlink(os.path.join(FINAL, x), os.path.join(T, x))
        img = bytearray(open(os.path.join(FINAL, "juego.bin"), "rb").read())
        orig = bytes(img)
        r = random.Random(64)
        for a in dirs:
            img[a] ^= r.randrange(1, 256)
        open(os.path.join(T, "juego.bin"), "wb").write(img)
        J = os.path.join(P, "juego")
        procs = []
        for k in range(1, sesiones + 1):
            orden = ["./hibrido", "../../data/cpc64/inicio_juego/ram.bin", "../../data/cpc64/inicio_juego/estado.txt",
                     "../../data/sincrono/puntos64.txt", "--guion", f"../../data/cpc64/exploracion/azar{k}.txt",
                     "--hasta", "4472", "--limite", "50000000", "--juego6502", T]
            procs.append((k, subprocess.Popen(orden, cwd=J, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)))
        mal = 0
        for k, p in procs:
            out = p.communicate()[0]
            resumen = [l for l in out.splitlines() if "6502 game:" in l]
            linea = resumen[-1].split("; ")[-1] if resumen else "FAILED: " + out.strip().splitlines()[-1]
            print(f"azar{k}: {linea}")
            difs = [l for l in out.splitlines() if l.startswith("6502 GAME frame")]
            if solo_tablas:
                # every reported difference must be in a table, the 6502 holding the original byte
                otros = 0
                for l in difs:
                    for m in re.finditer(r"\[(\S+) (\w+)->(\w+)\] (\w+)/(\w+)", l):
                        nombre, a, v6502 = m.group(1), int(m.group(3), 16), int(m.group(4), 16)
                        if not nombre.startswith("tabla_") or v6502 != orig[a]:
                            otros += 1
                            print("   unexpected: " + m.group(0))
                    if "plat_final" in l or "no frame" in l:
                        otros += 1
                print(f"   {len(difs)} frames reported, {otros} differences outside the tables or not the original byte")
                mal += otros
            else:
                for l in difs[:3]:
                    print("   " + l[:300])
                if not (resumen and " 0 with differences" in resumen[-1]):
                    mal += 1
        print("result:", "as expected" if mal == 0 else "NOT as expected")
        sys.exit(1 if mal else 0)
    finally:
        shutil.rmtree(T, ignore_errors=True)


if __name__ == "__main__":
    main()
