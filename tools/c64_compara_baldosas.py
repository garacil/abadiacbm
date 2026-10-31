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

"""The room tiles (00h-D9h, 16 x 8 CPC pixels each, the same bytes on the PC: src/c64/NOTAS_GRAFICOS.md) converted by
the rules, side by side: the source | the build's tile (data/c64graf, rule detalle) | trazos | contorno, with
the transparent pen of each class (01h-0Ah opaque, 0Bh-7Fh pen 2, 80h-D9h pen 1) and the measures of each rule
(runs of the source lost, silhouette pixels changed), as c64_compara_pc.py does for the characters.

    c64_compara_baldosas.py OUTDIR [--escala N] [--desde N] [--hasta N] [--columnas fuente,actual,trazos,contorno]
"""
import argparse, os, sys
AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import c64_graficos as G
import c64_mitad as M
from PIL import Image, ImageDraw

RAIZ = os.path.join(AQUI, "..")
TINTA = {0: (117, 206, 200), 1: (133, 76, 25), 2: (237, 241, 113), 3: (0, 0, 0)}   # VICE colodore: cyan, orange, yellow, black
GRIS = (60, 60, 70)


def clase(n):
    """the transparent pen of tile n, or None (opaque)"""
    return None if n <= 0x0A else 2 if n <= 0x7F else 1


def lamina(rows, e, tr, doble=False):
    w, h = len(rows[0]) * (2 if doble else 1), len(rows)
    im = Image.new("RGB", (w * e, h * e), GRIS)
    d = ImageDraw.Draw(im)
    for y, r in enumerate(rows):
        for x, p in enumerate(r):
            col = GRIS if p == tr else TINTA[p]
            x0 = x * (2 if doble else 1) * e
            d.rectangle((x0, y * e, x0 + (2 if doble else 1) * e - 1, y * e + e - 1), fill=col)
    return im


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("salida")
    ap.add_argument("--escala", type=int, default=5)
    ap.add_argument("--desde", type=lambda s: int(s, 16), default=0)
    ap.add_argument("--hasta", type=lambda s: int(s, 16), default=G.NBALDOSAS - 1)
    ap.add_argument("--columnas", default="fuente,actual,trazos,contorno")
    ap.add_argument("--por-fila", type=int, default=8)
    x = ap.parse_args()
    os.makedirs(x.salida, exist_ok=True)
    m = open(os.path.join(RAIZ, "data", "cpc64", "juego", "ram.bin"), "rb").read()
    actuales = open(os.path.join(RAIZ, "data", "c64graf", "baldosas.bin"), "rb").read()
    cols = x.columnas.split(",")
    e = x.escala
    piezas, tsv = [], ["tile\tclase_transparente\tversion\tpixels_dif\tsilueta_dif\tperdidos\ttramos"]
    for n in range(x.desde, x.hasta + 1):
        tr = clase(n)
        trn = -1 if tr is None else tr                  # no transparent pen: a pen index no pixel has
        fuente = G.imagen(m, 0x8300 + 32 * n, 4, 8)
        actual = G.de_baldosa(actuales[16 * n:16 * n + 16])
        versiones = {"fuente": None, "actual": actual, "trazos": M.trazos(fuente, tr=trn),
                     "contorno": M.contorno(fuente, pen=3, tr=trn)}
        for ver in ("actual", "trazos", "contorno"):
            r = M.compara(fuente, versiones[ver], tr=trn)
            tsv.append(f"{n:02X}\t{'-' if tr is None else tr}\t{ver}\t{r['pixels']}\t{r['silueta']}\t{r['perdidos']}\t{r['tramos']}")
        ims = [lamina(fuente, e, trn) if c == "fuente" else lamina(versiones[c], e, trn, doble=True) for c in cols]
        piezas.append((n, tr, ims))
    open(os.path.join(x.salida, f"medidas_baldosas_{x.desde:02X}_{x.hasta:02X}.tsv"), "w").write("\n".join(tsv) + "\n")
    ancho = max(sum(im.width for im in p[2]) for p in piezas) + 3 * (len(cols) - 1)
    alto = 8 * e + 24
    sep = 10
    nf = (len(piezas) + x.por_fila - 1) // x.por_fila
    hoja = Image.new("RGB", (16 + x.por_fila * (ancho + sep), 40 + nf * (alto + sep)), (36, 36, 44))
    d = ImageDraw.Draw(hoja)
    d.text((16, 8), " | ".join(cols) + f"   tiles {x.desde:02X}-{x.hasta:02X}, x{e}; grey = the class's transparent pen", fill=(255, 220, 120))
    for i, (n, tr, ims) in enumerate(piezas):
        x0 = 16 + (i % x.por_fila) * (ancho + sep)
        y0 = 40 + (i // x.por_fila) * (alto + sep)
        xx = x0
        for im in ims:
            hoja.paste(im, (xx, y0))
            xx += im.width + 3
        d.text((x0, y0 + 8 * e + 4), f"{n:02X}" + ("" if tr is None else f" tr{tr}"), fill=(225, 225, 225))
    ruta = os.path.join(x.salida, f"hoja_baldosas_{x.desde:02X}_{x.hasta:02X}.png")
    hoja.save(ruta)
    print(ruta, hoja.size)


if __name__ == "__main__":
    main()
