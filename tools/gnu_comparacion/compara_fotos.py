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

"""The CPC simulator's screenshot (cpc_carga.py --fotos: 640 x 200 for the 40 x 25 screen, a mode 1 pixel
2 x 1) against abadia64ks's picture of the same frame (--fotos: 384 x 272, the 320 x 200 screen at 32, 36):
pixel by pixel over the screen area.     compara_fotos.py CPC.png GNU.bmp"""
import sys
from PIL import Image
a = Image.open(sys.argv[1]).convert("RGB")
b = Image.open(sys.argv[2]).convert("RGB")
assert a.size == (640, 200) and b.size == (384, 272), (a.size, b.size)
pa, pb = a.load(), b.load()
n = sum(1 for y in range(200) for x in range(320) if pa[2 * x, y] != pb[32 + x, 36 + y] or pa[2 * x + 1, y] != pb[32 + x, 36 + y])
print(f"{sys.argv[1].split('/')[-1]}: {64000 - n} of 64000 pixels equal")
sys.exit(1 if n else 0)
