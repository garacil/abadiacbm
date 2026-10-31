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

"""CPC hardware colours -> nearest Commodore 64 colours (CIE Lab, VICE palette file).

    c64_colores.py [PALETTE.vpl] HW...      e.g. 06 0E 03 14
"""
import math, sys

CPC = [(128,128,128),(128,128,128),(0,255,128),(255,255,128),(0,0,128),(255,0,128),(0,128,128),(255,128,128),
       (255,0,128),(255,255,128),(255,255,0),(255,255,255),(255,0,0),(255,0,255),(255,128,0),(255,128,255),
       (0,0,128),(0,255,128),(0,255,0),(0,255,255),(0,0,0),(0,0,255),(0,128,0),(0,128,255),
       (128,0,128),(128,255,128),(128,255,0),(128,255,255),(128,0,0),(128,0,255),(128,128,0),(128,128,255)]
NAMES = ["black", "white", "red", "cyan", "purple", "green", "blue", "yellow", "orange", "brown", "light red",
         "dark grey", "grey", "light green", "light blue", "light grey"]


def vpl(path):
    out = []
    for line in open(path):
        t = line.split("#")[0].split()
        if len(t) >= 3:
            out.append(tuple(int(x, 16) for x in t[:3]))
    return out[:16]


def lab(rgb):
    def lin(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = map(lin, rgb)
    x, y, z = (r * .4124 + g * .3576 + b * .1805) / .95047, r * .2126 + g * .7152 + b * .0722, (r * .0193 + g * .1192 + b * .9505) / 1.08883
    f = lambda t: t ** (1 / 3) if t > 216 / 24389 else (24389 / 27 * t + 16) / 116
    return 116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))


def nearest(rgb, pal):
    a = lab(rgb)
    return min(range(16), key=lambda i: math.dist(a, lab(pal[i])))


def main():
    args = sys.argv[1:]
    path = args.pop(0) if args and args[0].endswith(".vpl") else "/usr/share/vice/C64/colodore.vpl"
    pal = vpl(path)
    for h in args:
        n = nearest(CPC[int(h, 16)], pal)
        print(f"CPC {h} {CPC[int(h, 16)]} -> C64 {n} {NAMES[n]} {pal[n]}")


if __name__ == "__main__":
    main()
