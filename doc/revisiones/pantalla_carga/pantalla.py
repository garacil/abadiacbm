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

"""The loading picture of the CPC tape on the C64, as the loader builds it up (doc/revisiones/pantalla_carga/NOTAS.md).

    pantalla.py CARGA.c [PNG_DIR]

The picture: the CPC screen in the tape's block 20h (data/cpc64/cinta/juego.bin, C000h-FFFFh: 32 x 24 characters
of mode 0, 64 bytes a line), with the loader's inks (data/cpc64/cinta/tintas.txt: pens 0-15, then the border).
A mode 0 pixel is a C64 multicolour pixel and a CPC byte a C64 nibble, so the picture is copied 1:1 into the game's
screen: cells 4-35 of rows 0-23 (where the game's own screen is, as on the CPC, whose loader sets the game's CRTC
geometry).  The colours (doc/revisiones/pantalla_carga/NOTAS.md): judged on a real C64's palette (VICE's colodore.vpl)
with a perceptual distance (CIEDE2000) from the CPC's own colours.  Each CPC pen gets one C64 colour for the whole
picture (asignacion: the nearest, but where two pens drawn side by side would become one colour, the choice that
loses the least: the dark cyan of the monk's robe becomes dark grey, apart from its grey); $D021 black (the picture's
most used colour, and the cells outside the picture must show black whatever their bitmap holds); each 4 x 8 cell
takes the 3 colours that keep its pens' colours, and in a cell with more (68) the least visible substitutes.

While it loads the CPC shows pen 0 (pink) wherever the bytes have not come, and pink is also a colour of the
picture.  Here $D021 stays black and each cell gets pink in one of its three slots (screen RAM high nibble = pair
01, low nibble = 10, colour RAM = 11): the slot of pink when the cell uses it, else a free slot (kept after the
load: no pixel uses it), else (three other colours: the cell "lends" a colour) the slot of its least used colour,
put in the screen RAM's low nibble (pair 10), so that its true colour comes back with a screen RAM byte when the
picture is complete.  The cell's bitmap starts as its pink pair everywhere; each nibble that comes takes the
picture's pairs.

As a module: convierte() -> the cells; the picture bytes in the CPC's order; the colour fixes; previews.
CARGA.c: the first stage's data: carga_pantalla[768], carga_color[768] (the loading colours of the 32 x 24 cells,
row by row) and carga_rosa.
"""
import itertools, math, os, struct, sys, zlib

D = os.path.dirname(os.path.realpath(__file__))
P = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(D))), "src")
sys.path.insert(0, os.path.join(P, "..", "tools"))
from c64_colores import CPC, lab, vpl                              # noqa: E402
from licencia import cabecera                                      # noqa: E402
sys.path.insert(0, D)
from color import de2000                                           # noqa: E402

PALETA = "/usr/share/vice/C64/colodore.vpl"


def pens_cinta():
    """the 128 x 192 pens of the tape's picture (mode 0: pixel i of a byte = bits 7-i, 3-i, 5-i, 1-i -> pen bits
    0, 1, 2, 3; checked against Caprice32's display of the same memory, revision_pantalla/NOTAS.md)"""
    ram = open(os.path.join(P, "..", "data", "cpc64", "cinta", "juego.bin"), "rb").read()
    pens = bytearray(128 * 192)
    for y in range(192):
        for xb in range(64):
            b = ram[0xC000 + ((y & 7) << 11) + (y >> 3) * 64 + xb]
            for i in range(2):
                pens[y * 128 + 2 * xb + i] = (((b >> (7 - i)) & 1) | ((b >> (3 - i)) & 1) << 1
                                             | ((b >> (5 - i)) & 1) << 2 | ((b >> (1 - i)) & 1) << 3)
    return pens


def distancias():
    """the CIEDE2000 distance of each CPC pen's colour (the loader's inks) to each C64 colour, and the palette"""
    tintas = [int(x, 16) for x in open(os.path.join(P, "..", "data", "cpc64", "cinta", "tintas.txt")).read().split()]
    pal = vpl(PALETA)
    return [[de2000(lab(CPC[hw & 31]), lab(pal[i])) for i in range(16)] for hw in tintas[:16]], pal


def colores_c64():
    """the C64 colour nearest each CPC pen, and the palette"""
    dist, pal = distancias()
    return [min(range(16), key=lambda i: d[i]) for d in dist], pal


LAMBDA = 1.0          # the weight of a lost edge (two neighbouring pixels of different pens made one colour)


def asignacion(pens, dist):
    """the C64 colour of each CPC pen for the whole picture: the one that minimises the sum over the pixels of their
    distance plus, for each pair of neighbouring pixels of different pens given one colour, LAMBDA times the distance
    between the two CPC colours (the edge the picture loses); from the nearest colours, one pen changed at a time while
    the sum goes down (deterministic: pens and colours in order)"""
    tintas = [int(x, 16) for x in open(os.path.join(P, "..", "data", "cpc64", "cinta", "tintas.txt")).read().split()]
    L = [lab(CPC[hw & 31]) for hw in tintas[:16]]
    cuenta, bordes = {}, {}
    for y in range(192):
        for x in range(128):
            a = pens[y * 128 + x]
            cuenta[a] = cuenta.get(a, 0) + 1
            for b in ((pens[y * 128 + x + 1],) if x < 127 else ()) + ((pens[(y + 1) * 128 + x],) if y < 191 else ()):
                if a != b:
                    k = (min(a, b), max(a, b))
                    bordes[k] = bordes.get(k, 0) + 1
    contraste = {k: de2000(L[k[0]], L[k[1]]) for k in bordes}
    def coste(m):
        return (sum(n * dist[p][m[p]] for p, n in cuenta.items())
                + LAMBDA * sum(n * contraste[k] for k, n in bordes.items() if m[k[0]] == m[k[1]]))
    m = [min(range(16), key=lambda i: d[i]) for d in dist]
    mejor = coste(m)
    cambio = True
    while cambio:
        cambio = False
        for p in sorted(cuenta):
            for c in range(16):
                if c != m[p]:
                    viejo, m[p] = m[p], c
                    e = coste(m)
                    if e < mejor - 1e-9:
                        mejor, cambio = e, True
                    else:
                        m[p] = viejo
    return m


DESVIO = 15.0         # added to a pixel's distance when a cell gives its pen another colour than asignacion()'s


def convierte():
    """the 768 cells, row by row: dict(bitmap=[8 final bytes], s=final screen RAM, c=final colour RAM, s_carga, c_carga,
    presta=True when the cell lends a colour to the pink while it loads, perdida=True when its pens' colours (asignacion)
    are more than 3 besides black: some take a substitute)"""
    pens = pens_cinta()
    dist, pal = distancias()
    cerca = [min(range(16), key=lambda i: d[i]) for d in dist]
    rosa = cerca[0]
    m = asignacion(pens, dist)
    coste = [[dist[p][x] + (0 if x == m[p] else DESVIO) for x in range(16)] for p in range(16)]
    celdas = []
    for r in range(24):
        for c in range(32):
            px = [[pens[(r * 8 + l) * 128 + c * 4 + k] for k in range(4)] for l in range(8)]
            cuenta = {}
            for fila in px:
                for p in fila:
                    cuenta[p] = cuenta.get(p, 0) + 1
            # the 3 cell colours (black is $D021) that minimise the sum over the cell's pixels: each pen its colour of the
            # whole picture when the cell has room for it, else the least visible substitute
            mejor = None
            for trio in itertools.combinations(range(1, 16), 3):
                e = sum(n * min(coste[p][0], coste[p][trio[0]], coste[p][trio[1]], coste[p][trio[2]]) for p, n in cuenta.items())
                if mejor is None or e < mejor[0] - 1e-9:
                    mejor = (e, trio)
            elige = {p: min((0,) + mejor[1], key=lambda x: coste[p][x]) for p in cuenta}
            uso = {}
            for p, n in cuenta.items():
                if elige[p]:
                    uso[elige[p]] = uso.get(elige[p], 0) + n
            keep = sorted(uso, key=lambda x: (-uso[x], x))            # the colours the pixels use, most used first
            presta = len(keep) == 3 and rosa not in keep
            ranuras = [keep[0], keep[2], keep[1]] if presta else keep + [None] * (3 - len(keep))
            par = {0: 0}
            for i, x in enumerate(ranuras):
                if x is not None:
                    par[x] = i + 1
            bitmap = []
            for l in range(8):
                v = 0
                for k in range(4):
                    v = v << 2 | par[elige[px[l][k]]]
                bitmap.append(v)
            carga = list(ranuras)
            if presta:
                carga[1] = rosa
            elif rosa not in keep:
                carga[carga.index(None)] = rosa            # a free slot: pink, and it stays so
                ranuras = list(carga)
            fin = [x or 0 for x in ranuras]
            carga = [x or 0 for x in carga]
            nucleo = {m[p] for p in cuenta} - {0}
            celdas.append(dict(bitmap=bitmap, s=fin[0] << 4 | fin[1], c=fin[2], s_carga=carga[0] << 4 | carga[1],
                               c_carga=carga[2], presta=presta, perdida=len(nucleo) > 3))
    return celdas, rosa


def direccion(fila, celda, linea):
    """the bitmap byte of game cell `celda` (0-31) of row `fila`, line `linea`"""
    return 0xE000 + 320 * fila + 8 * (celda + 4) + linea


def orden_cpc():
    """the picture's C64 bytes in the CPC tape's order: (row, cell, line) for line 7..0, row 23..0, cell 31..0
    (the CPC byte FFFFh - p: line (a >> 11) & 7, offset a & 7FFh, row offset >> 6, byte column offset & 63, the odd
    column (low nibble) first)"""
    return [(fila, celda, linea) for linea in range(7, -1, -1) for fila in range(23, -1, -1) for celda in range(31, -1, -1)]


def bytes_imagen(celdas):
    return bytes(celdas[f * 32 + c]["bitmap"][l] for f, c, l in orden_cpc())


def arreglos(celdas):
    """the colour fixes once the picture is complete: entries (step, byte) along the screen RAM from $C000; a step 0
    is 255 on without a byte"""
    out, ant = [], 0xC000
    for i, cel in enumerate(celdas):
        if cel["s"] != cel["s_carga"]:
            a = 0xC000 + (i // 32) * 40 + 4 + i % 32
            while a - ant > 255:
                out.append((0, None))
                ant += 255
            out.append((a - ant, cel["s"]))
            ant = a
        assert cel["c"] == cel["c_carga"], "a colour RAM fix (the generator puts the lent slot in the screen RAM)"
    return out


def patron_rosa(cel, rosa):
    s = cel["s_carga"]
    return 0x55 if s >> 4 == rosa else 0xAA if s & 15 == rosa else 0xFF


def pantalla(celdas, rosa, nibbles=None, final=False):
    """the 320 x 200 C64 colour indices of the display: the loading state after `nibbles` nibbles of the CPC order
    (None: all), with the final colours if `final` (the fixes applied); outside the picture black"""
    bm = {}
    for i, cel in enumerate(celdas):
        p = patron_rosa(cel, rosa)
        for l in range(8):
            bm[(i // 32, i % 32, l)] = p
    orden = orden_cpc()
    n = 2 * len(orden) if nibbles is None else nibbles
    for k in range(n):
        f, c, l = orden[k // 2]
        v = celdas[f * 32 + c]["bitmap"][l]
        m = 0x0F if k % 2 == 0 else 0xF0
        bm[(f, c, l)] = bm[(f, c, l)] & ~m & 0xFF | v & m
    img = bytearray(320 * 200)
    for i, cel in enumerate(celdas):
        f, c = i // 32, i % 32
        s, k = (cel["s"], cel["c"]) if final else (cel["s_carga"], cel["c_carga"])
        cc = [0, s >> 4, s & 15, k]
        for l in range(8):
            b = bm[(f, c, l)]
            for x in range(4):
                v = cc[(b >> (6 - 2 * x)) & 3]
                y, px = f * 8 + l, (c + 4) * 8 + 2 * x
                img[y * 320 + px] = img[y * 320 + px + 1] = v
    return bytes(img)


def png(nombre, idx, pal, ancho=320, alto=200):
    filas = b"".join(b"\0" + b"".join(bytes(pal[v]) for v in idx[y * ancho:(y + 1) * ancho]) for y in range(alto))
    def trozo(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    open(nombre, "wb").write(b"\x89PNG\r\n\x1a\n" + trozo(b"IHDR", struct.pack(">IIBBBBB", ancho, alto, 8, 2, 0, 0, 0))
                             + trozo(b"IDAT", zlib.compress(filas, 9)) + trozo(b"IEND", b""))


def main():
    celdas, rosa = convierte()
    def arr(nombre, datos):
        filas = ",\n".join("  " + ",".join(f"0x{b:02X}" for b in datos[i:i + 16]) for i in range(0, len(datos), 16))
        return f"const unsigned char {nombre}[{len(datos)}] = {{\n{filas}\n}};\n"
    with open(sys.argv[1], "w") as f:
        f.write(cabecera("c") + "\n")
        f.write("/* generated by doc/revisiones/pantalla_carga/pantalla.py: the loading colours of the picture's 32 x 24 cells (screen RAM,\n"
                " * colour RAM), row by row, and the C64 colour of the CPC's pink (pen 0 while it loads) */\n")
        f.write(arr("carga_pantalla", [c["s_carga"] for c in celdas]) + arr("carga_color", [c["c_carga"] for c in celdas]))
        f.write(f"const unsigned char carga_rosa = {rosa};\n")
    prestan = sum(c["presta"] for c in celdas)
    pierden = sum(c["perdida"] for c in celdas)
    print(f"pink = C64 colour {rosa}; {prestan} of 768 cells lend a colour to the pink while they load, "
          f"{pierden} have more than 3 colours besides black (substitutes); {len(arreglos(celdas))} fix entries")
    if len(sys.argv) > 2:
        _, pal = colores_c64()
        os.makedirs(sys.argv[2], exist_ok=True)
        for n in (0, 3072, 6144, 9216):
            png(os.path.join(sys.argv[2], f"carga_{n}.png"), pantalla(celdas, rosa, n), pal)
        png(os.path.join(sys.argv[2], "carga_completa.png"), pantalla(celdas, rosa, None), pal)
        png(os.path.join(sys.argv[2], "final.png"), pantalla(celdas, rosa, None, final=True), pal)


if __name__ == "__main__":
    main()
