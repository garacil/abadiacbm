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

"""Side-by-side pictures of the page turn: the CPC (cpc_pagina.py's screenshots) and one or more C64 builds
(c64_pagina.py's), the 320 x 200 display of each with 8 pixels of border, CPC pixels 1:1 (Caprice32's screenshot is
at scale 2), each labelled.

    compara.py pasos OUT.png CPCDIR C64DIR[=label] ...    the corner's held steps (cpc_paso<k>.png, c64_paso<k>.png)
    compara.py tiempo OUT.png CPCDIR C64DIR[=label] ...   the screenshots taken every so often from the turn's start
                                                          (cpc_t<ms>.png, c64_t<ms>.png: each CPC one with the C64's
                                                          nearest in time)
    [--escala N] (default 1) [--filas k1,k2,...] (pasos: the steps to show; tiempo: the CPC times in ms)
"""
import glob, os, re, sys
from PIL import Image, ImageDraw

MARGEN = 8
CPC_ORIGEN = (64, 84)        # the 320 x 200 display's top-left in Caprice32's 768 x 540 screenshot (scale 2)
C64_ORIGEN = (32, 35)        # and in VICE's 384 x 272 (vice_mb.foto's borders)


def recorta(f, cpc):
    im = Image.open(f).convert("RGB")
    if cpc:
        x, y = CPC_ORIGEN
        im = im.crop((x - 2 * MARGEN, y - 2 * MARGEN, x + 640 + 2 * MARGEN, y + 400 + 2 * MARGEN))
        return im.resize((im.width // 2, im.height // 2), Image.NEAREST)
    x, y = C64_ORIGEN
    return im.crop((x - MARGEN, y - MARGEN, x + 320 + MARGEN, y + 200 + MARGEN))


def tiempos(d, pref):
    out = {}
    for f in glob.glob(os.path.join(d, f"{pref}_t*.png")):
        out[int(re.search(r"_t(\d+)\.png$", f).group(1))] = f
    return out


def main():
    a = sys.argv[1:]
    escala, filas = 1, None
    if "--escala" in a:
        i = a.index("--escala"); escala = int(a[i + 1]); del a[i:i + 2]
    if "--filas" in a:
        i = a.index("--filas"); filas = [int(x) for x in a[i + 1].split(",")]; del a[i:i + 2]
    modo, salida, cpc = a[0], a[1], a[2]
    c64 = [(x.split("=", 1) + [os.path.basename(x)])[:2] for x in a[3:]]
    cab = ["CPC (Caprice32)"] + [lab for _, lab in c64]
    renglones = []                                       # (row label, [pictures])
    if modo == "pasos":
        ks = sorted(int(re.search(r"paso(\d+)", f).group(1)) for f in glob.glob(os.path.join(cpc, "cpc_paso*.png")))
        for k in filas or ks:
            fs = [os.path.join(cpc, f"cpc_paso{k:02d}.png")] + [os.path.join(d, f"c64_paso{k:02d}.png") for d, _ in c64]
            if all(os.path.exists(f) for f in fs):
                fase = 1 if k <= 45 else 2
                bandas = 2 + k if k <= 45 else 47 - (k - 46)
                renglones.append((f"step {k} (phase {fase}, {bandas} bands)", fs))
    else:
        tc = tiempos(cpc, "cpc")
        t64 = [tiempos(d, "c64") for d, _ in c64]
        for t in filas or sorted(tc):
            if t not in tc:
                t = min(tc, key=lambda x: abs(x - t))
            fs, et = [tc[t]], [f"{t} ms"]
            for tt in t64:
                n = min(tt, key=lambda x: abs(x - t))
                fs.append(tt[n]); et.append(f"{n} ms")
            renglones.append(("t = " + " / ".join(et), fs))
    an, al = (320 + 2 * MARGEN) * escala, (200 + 2 * MARGEN) * escala
    col = len(cab)
    img = Image.new("RGB", (col * (an + 6) + 6, 20 + len(renglones) * (al + 22) + 4), (255, 255, 255))
    dib = ImageDraw.Draw(img)
    for i, c in enumerate(cab):
        dib.text((6 + i * (an + 6), 4), c, fill=(0, 0, 0))
    for r, (lab, fs) in enumerate(renglones):
        y = 20 + r * (al + 22)
        dib.text((6, y + 2), lab, fill=(0, 0, 0))
        for i, f in enumerate(fs):
            p = recorta(f, i == 0)
            if escala != 1:
                p = p.resize((p.width * escala, p.height * escala), Image.NEAREST)
            img.paste(p, (6 + i * (an + 6), y + 16))
    img.save(salida)
    print(salida, img.size)


if __name__ == "__main__":
    main()
