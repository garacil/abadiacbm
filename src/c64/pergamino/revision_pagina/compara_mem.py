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

"""The page turn's held steps, CPC against C64, pixel by pixel: the CPC's screen memory (cpc_pagina.py --pasos:
cpc_paso<k>.bin, mode 1 at C000h) with each pen in the C64 colour the port gives it (datos.c's perg_color_pluma:
pink, red, black, red), and the C64's memory (c64_pagina.py --pasos: c64_paso<k>.bin, the hires bitmap with its cell
colours and the capital sprites in front), both 320 x 200 (a CPC mode 1 pixel is a C64 hires pixel).

    compara_mem.py CPCDIR C64DIR [C64DIR ...] [--fotos OUTDIR]

For each step held in all of them: the pixels whose colour differs from the CPC's (all, and those in the parchment's
border cells: cell columns 8 and 31, rows 0 and 23, where the border's black, red and pink share cells), and with --fotos a picture of
the differences (CPC | each C64 | the differences of each in white).
"""
import glob, os, re, struct, sys, zlib

PLUMA = [10, 2, 0, 2]                          # perg_color_pluma (c64/pergamino/datos.c)
PALETA = "/usr/share/vice/C64/colodore.vpl"


def paleta():
    out = []
    for linea in open(PALETA):
        t = linea.split("#")[0].split()
        if len(t) >= 3:
            out.append(tuple(int(x, 16) for x in t[:3]))
    return out[:16]


def cpc(f):
    m = open(f, "rb").read()
    img = bytearray(320 * 200)
    for y in range(200):
        for xb in range(80):
            b = m[(y & 7) * 0x800 + (y >> 3) * 80 + xb]
            for i in range(4):
                img[y * 320 + xb * 4 + i] = PLUMA[((b >> (7 - i)) & 1) | ((b >> (3 - i)) & 1) << 1]
    return img


def c64(f):
    m = open(f, "rb").read()
    celdas, bitmap, vic = m[0:0x800], m[0x800:0x800 + 8000], m[0x800 + 8000:]
    img = bytearray(320 * 200)
    for y in range(200):
        for x in range(320):
            c = celdas[(y >> 3) * 40 + (x >> 3)]
            bit = bitmap[(y >> 3) * 320 + (x >> 3) * 8 + (y & 7)] >> (7 - (x & 7)) & 1
            img[y * 320 + x] = c >> 4 if bit else c & 15
    for n in range(7, -1, -1):                 # sprite 0 in front of the others
        if not vic[0x15] >> n & 1:
            continue
        sx = vic[2 * n] | (vic[0x10] >> n & 1) << 8
        sy = vic[2 * n + 1]
        ptr = celdas[0x3F8 + n] * 64
        datos = m[ptr:ptr + 63] if ptr + 63 <= 0x800 else bytes(63)
        for r in range(21):
            for p in range(24):
                if datos[r * 3 + p // 8] >> (7 - p % 8) & 1:
                    x, y = sx - 24 + p, sy - 50 + r
                    if 0 <= x < 320 and 0 <= y < 200:
                        img[y * 320 + x] = vic[0x27 + n] & 15
    return img


def png(nombre, ancho, alto, rgb):
    filas = b"".join(b"\0" + rgb[y * ancho * 3:(y + 1) * ancho * 3] for y in range(alto))
    def trozo(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    open(nombre, "wb").write(b"\x89PNG\r\n\x1a\n" + trozo(b"IHDR", struct.pack(">IIBBBBB", ancho, alto, 8, 2, 0, 0, 0))
                             + trozo(b"IDAT", zlib.compress(filas, 9)) + trozo(b"IEND", b""))


def main():
    a = sys.argv[1:]
    fotos = None
    if "--fotos" in a:
        i = a.index("--fotos"); fotos = a[i + 1]; del a[i:i + 2]
        os.makedirs(fotos, exist_ok=True)
    cdir, dirs = a[0], a[1:]
    pal = paleta()
    ks = sorted(int(re.search(r"paso(\d+)\.bin", f).group(1)) for f in glob.glob(os.path.join(cdir, "cpc_paso*.bin")))
    print("step  " + "  ".join(f"{os.path.basename(d.rstrip('/')):>24}" for d in dirs) + "   (pixels unlike the CPC: all / in the border's cells)")
    for k in ks:
        fs = [os.path.join(d, f"c64_paso{k:02d}.bin") for d in dirs]
        if not all(os.path.exists(f) for f in fs):
            continue
        ref = cpc(os.path.join(cdir, f"cpc_paso{k:02d}.bin"))
        imgs = [c64(f) for f in fs]
        cols = []
        for im in imgs:
            dif = [i for i in range(320 * 200) if im[i] != ref[i]]
            def anillo(i):                     # the parchment's border cells: cell columns 8 and 31, rows 0 and 23
                cx, cy = (i % 320) // 8, (i // 320) // 8
                return 8 <= cx <= 31 and cy <= 23 and (cx in (8, 31) or cy in (0, 23))
            borde = [i for i in dif if anillo(i)]
            cols.append(f"{len(dif):>12} / {len(borde):<10}")
        print(f"{k:4d}  " + "  ".join(cols))
        if fotos:
            ancho = 320 * (1 + 2 * len(imgs))
            rgb = bytearray(ancho * 200 * 3)
            def pon(col, im, blanco=None):
                for y in range(200):
                    for x in range(320):
                        c = (255, 255, 255) if blanco and blanco[y * 320 + x] else pal[im[y * 320 + x]] if im else (0, 0, 0)
                        o = (y * ancho + col * 320 + x) * 3
                        rgb[o:o + 3] = bytes(c)
            pon(0, ref)
            for j, im in enumerate(imgs):
                pon(1 + 2 * j, im)
                pon(2 + 2 * j, bytes(320 * 200), [im[i] != ref[i] for i in range(320 * 200)])
            png(os.path.join(fotos, f"dif_paso{k:02d}.png"), ancho, 200, bytes(rgb))


if __name__ == "__main__":
    main()
