#!/usr/bin/env python3 -I
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

"""Find, in a 64 KiB C64 image (juego.bin) with its ld65 label file (juego.lbl), the addresses this
measurement needs: the frame-wait loop of game_main (LDA zp D64_SYS_TICKS / CMP zp D64_SYS_FRAME_TICKS /
BCS +3 / JMP loop) and every `JSR target` site of the given targets inside the CODE area.  Deterministic:
prints one line per finding, in address order.  Usage: sitios.py juego.bin juego.lbl NAME=ADDR... TARGET...
(NAME=ADDR gives zero-page variables by hand; TARGET is a label of juego.lbl)."""
import sys

img = open(sys.argv[1], "rb").read()
lbl = {}
for line in open(sys.argv[2]):
    t = line.split()
    if len(t) == 3 and t[0] == "al":
        lbl[t[2].lstrip(".")] = int(t[1], 16)
zp = {}
targets = []
for a in sys.argv[3:]:
    if "=" in a:
        k, v = a.split("=")
        zp[k] = int(v, 16)
    else:
        targets.append(a)
code_end = lbl.get("CODIGO_FIN", 0x7151)
# the wait loop
pat = bytes([0xA5, zp["D64_SYS_TICKS"], 0xC5, zp["D64_SYS_FRAME_TICKS"], 0xB0, 0x03, 0x4C])
i = img.find(pat)
while i >= 0:
    dest = img[i + 7] | (img[i + 8] << 8)
    print(f"espera\t{i:04X}\tjmp->{dest:04X}\texit={i + 9:04X}\t{'self-loop' if dest == i else 'NOT a self-loop'}")
    i = img.find(pat, i + 1)
for name in targets:
    a = lbl[name]
    pat = bytes([0x20, a & 0xFF, a >> 8])
    i = img.find(pat)
    while i >= 0:
        if 0x0800 <= i < code_end:
            print(f"jsr\t{name}\t{a:04X}\tsite={i:04X}\tret={i + 3:04X}")
        i = img.find(pat, i + 1)
