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

"""The loading picture: the CPC's against the C64's before and after the revision (doc/revisiones/pantalla_carga/NOTAS.md).

    analiza.py OUTDIR [CPC.png]

The CPC: the 128 x 192 mode 0 picture of the tape's block 20h with the loader's inks, in the CPC's colours (Caprice32's
table, 0/128/255; CPC.png, cpc_pantalla.py's Caprice32 screenshot, is checked to show exactly these pixels).  The C64:
the final picture of each conversion as the loader leaves it (pantalla.pantalla(final=True), the model prueba.py
checks VICE's memory against), in the colodore palette: before = revision_pantalla/antes/pantalla.py, after =
doc/revisiones/pantalla_carga/pantalla.py.  Each C64 multicolour pixel is a CPC mode 0 pixel.

Prints, for each: the mean CIEDE2000 distance of the pixels to the CPC's, the pixels whose C64 colour is not the
nearest colour of their CPC pen (the "ideal" of a C64 with no cells), the CPC's edges (neighbouring pixels of
different pens) that the C64 picture loses (both the same colour), the cells that hold more than 3 colours besides
black; and each CPC pen's colour in both.  Writes OUTDIR/comparacion.png (CPC | before | after, 3 x) and
OUTDIR/detalle.png (the face and the hand, 6 x).
"""
import importlib.util, os, sys
from PIL import Image

D = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, D)
from color import CPC, NAMES, COLODORE, P, de2000, lab, vpl          # noqa: E402


def modulo(nombre, ruta):
    spec = importlib.util.spec_from_file_location(nombre, ruta)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    m.P = P                                    # (the copy in antes/ would look for the project two levels up from it)
    return m


def pens_ok():
    """the picture's pens, mode 0 decoded as the CPC does (checked against Caprice32)"""
    ram = open(os.path.join(P, "..", "data/cpc64/cinta/juego.bin"), "rb").read()
    pens = []
    for y in range(192):
        for xb in range(64):
            b = ram[0xC000 + ((y & 7) << 11) + (y >> 3) * 64 + xb]
            for i in range(2):
                pens.append(((b >> (7 - i)) & 1) | ((b >> (3 - i)) & 1) << 1 | ((b >> (5 - i)) & 1) << 2
                            | ((b >> (1 - i)) & 1) << 3)
    return pens


def c64_imagen(mod):
    """the 128 x 192 C64 colour indices of a conversion's final picture"""
    celdas, rosa = mod.convierte()
    idx = mod.pantalla(celdas, rosa, None, final=True)
    return [idx[y * 320 + 32 + 2 * x] for y in range(192) for x in range(128)], celdas


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    tintas = [int(x, 16) for l in open(os.path.join(P, "..", "data/cpc64/cinta/tintas.txt")) if not l.startswith("#") for x in l.split()]
    pens = pens_ok()
    rgb_cpc = [CPC[tintas[p]] for p in pens]
    if len(sys.argv) > 2:                      # Caprice32's screenshot: the same pixels (mode 0 pixel = 4 x 2 there)
        cap = Image.open(sys.argv[2]).convert("RGB")
        q = lambda c: tuple(0 if v < 64 else 128 if v < 192 else 255 for v in c)
        mejor = max(((sum(q(cap.getpixel((ox + 4 * x + 1, oy + 2 * y))) == rgb_cpc[y * 128 + x]
                          for y in range(0, 192, 6) for x in range(0, 128, 4)), ox, oy)
                     for oy in range(0, cap.height - 383, 2) for ox in range(0, cap.width - 511, 4)))
        n = sum(q(cap.getpixel((mejor[1] + 4 * x + 1, mejor[2] + 2 * y))) == rgb_cpc[y * 128 + x]
                for y in range(192) for x in range(128))
        print(f"Caprice32's screenshot: {n} of {128 * 192} pixels as decoded here (at {mejor[1]}, {mejor[2]})")
    pal = vpl(COLODORE)
    L_cpc = {p: lab(CPC[tintas[p]]) for p in range(16)}
    L_pal = [lab(c) for c in pal]
    dist = {(p, c): de2000(L_cpc[p], L_pal[c]) for p in range(16) for c in range(16)}
    cerca = {p: min(range(16), key=lambda c: dist[p, c]) for p in range(16)}
    antes = modulo("pantalla_antes", os.path.join(D, "antes", "pantalla.py"))
    despues = modulo("pantalla_despues", os.path.join(D, "pantalla.py"))
    usados = sorted(set(pens), key=lambda p: -pens.count(p))
    res = {}
    for nombre, mod in (("before", antes), ("after", despues)):
        img, celdas = c64_imagen(mod)
        n = len(img)
        de = sum(dist[pens[i], img[i]] for i in range(n)) / n
        ideal = sum(img[i] != cerca[pens[i]] for i in range(n))
        bordes = perdidos = 0
        for y in range(192):
            for x in range(128):
                a = y * 128 + x
                for b in ([a + 1] if x < 127 else []) + ([a + 128] if y < 191 else []):
                    if pens[a] != pens[b]:
                        bordes += 1
                        perdidos += img[a] == img[b]
        choques = sum(len({cerca[pens[(r * 8 + l) * 128 + c * 4 + k]] for l in range(8) for k in range(4)} - {0}) > 3
                      for r in range(24) for c in range(32))
        prestan = sum(c["presta"] for c in celdas)
        color_de = {}
        for p in usados:
            cs = [img[i] for i in range(n) if pens[i] == p]
            color_de[p] = max(set(cs), key=cs.count)
        res[nombre] = img
        print(f"{nombre}: mean CIEDE2000 {de:.2f}; pixels unlike the nearest colour of their pen {ideal} of {n}; "
              f"CPC edges lost {perdidos} of {bordes}; cells lending a colour to the pink while loading {prestan}")
        print("   each pen's colour (most of its pixels): " + ", ".join(
            f"{p}:{tintas[p]:02X}->{NAMES[color_de[p]]}" for p in usados))
    print(f"cells whose pens' nearest colours are more than 3 besides black (the C64's clashes): {choques}")
    # $D021 (shared by every cell): the sum of the distances with each colour as $D021 and each cell's best 3 others
    import itertools
    cuentas = []
    for r in range(24):
        for c in range(32):
            k = {}
            for l in range(8):
                for x in range(4):
                    p = pens[(r * 8 + l) * 128 + c * 4 + x]
                    k[p] = k.get(p, 0) + 1
            cuentas.append(k)
    fondo = {}
    for b in range(16):
        tot = 0.0
        otros = [x for x in range(16) if x != b]
        for k in cuentas:
            tot += min(sum(n * min(dist[p, b], dist[p, t[0]], dist[p, t[1]], dist[p, t[2]]) for p, n in k.items())
                       for t in itertools.combinations(otros, 3))
        fondo[b] = tot / (128 * 192)
    print("$D021: the mean distance with the best 3 colours a cell besides it: " + ", ".join(
        f"{NAMES[b]} {fondo[b]:.2f}" for b in sorted(fondo, key=fondo.get)[:5]))
    print("the pens: " + ", ".join(f"{p}:{tintas[p]:02X} {CPC[tintas[p]]} x{pens.count(p)} nearest {NAMES[cerca[p]]} "
                                   f"({dist[p, cerca[p]]:.1f})" for p in usados))

    def imagen(cols, escala):
        im = Image.new("RGB", (128, 192))
        im.putdata(cols)
        return im.resize((128 * 2 * escala, 192 * escala), Image.NEAREST)
    paneles = [imagen(rgb_cpc, 3), imagen([pal[v] for v in res["before"]], 3), imagen([pal[v] for v in res["after"]], 3)]
    hoja = Image.new("RGB", (3 * paneles[0].width + 40, paneles[0].height), (255, 255, 255))
    for k, p in enumerate(paneles):
        hoja.paste(p, (k * (p.width + 20), 0))
    hoja.save(os.path.join(out, "comparacion.png"))
    zonas = [(10, 30, 46, 74), (58, 108, 100, 152)]         # (x0, y0, x1, y1) in CPC mode 0 pixels: the face, the hand
    filas = []
    for x0, y0, x1, y1 in zonas:
        fila = [imagen(c, 6).crop((x0 * 12, y0 * 6, x1 * 12, y1 * 6)) for c in
                (rgb_cpc, [pal[v] for v in res["before"]], [pal[v] for v in res["after"]])]
        filas.append(fila)
    ancho = sum(f.width for f in filas[0]) + 40
    alto = sum(f[0].height for f in filas) + 20
    hoja = Image.new("RGB", (max(ancho, sum(f.width for f in filas[1]) + 40), alto), (255, 255, 255))
    y = 0
    for fila in filas:
        x = 0
        for f in fila:
            hoja.paste(f, (x, y))
            x += f.width + 20
        y += fila[0].height + 20
    hoja.save(os.path.join(out, "detalle.png"))


if __name__ == "__main__":
    main()
