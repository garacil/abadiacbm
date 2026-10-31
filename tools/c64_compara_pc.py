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

"""The graphics of the PC game with the EGA option (the CPC inks), one by one, against the Commodore 64's.

    c64_compara_pc.py OUTDIR [--grupo protagonistas|caras|habitos|monjes] [--escala N] [--antes DIR]
                     [--columnas pc,antes,trazos,1a1]

Columns of the sheet: pc (the PC EGA graphic), antes (the C64 before the rule trazos), trazos (the rule), 1a1 (
without removing a single pixel of the original: every PC pixel as one C64 multicolour pixel, which is twice as
wide, so the graphic keeps all its pixels and colours and is twice as wide on the screen), sprite (a MOCK-UP, not a
C64 build: the black pixels exact at 320 pixels a line, as a hires hardware sprite would draw them, over the body in
the multicolour bitmap: the orange, yellow and transparent pixels halved with the rule trazos; only the pairs of two
different non-black pens, and the half-transparent pairs without black, differ from the PC).

the C64 graphics must look the same as the PC EGA ones, compared pixel for pixel, with the same
shape although the resolutions differ.  For every graphic of the group this tool
  1. decodes the PC graphic as the PC game draws it (the CGA bytes through the game's own colour tables; the EGA
     option only changes the inks), from the PC reference (../abadia, read only), and the CPC 64 KiB tape image's
     graphic (data/cpc64/juego/ram.bin, the input of the C64 build), and checks that both are the same pixels
     in pen space (CGA colour c = CPC pen (3, 0, 1, 2)[c]; PC 1 cyan = CPC pen 0 = transparent in sprites);
  2. takes the C64 graphic as it was before the rule trazos (the converted blocks kept in data/c64graf_sim:
     rules sim/aislado plus the hand retouches; --antes DIR for another directory) and makes the new one with the
     rule `trazos` (c64_mitad.py), as c64_graficos.py now does for the protagonists;
  3. measures each C64 version against the PC one, doubled back to the PC's width (c64_mitad.compara): the runs of
     the drawing that are lost (black, inner gaps, yellow, orange) and the silhouette differences.  The count of
     differing pixels is also given but says nothing about the quality: every pair of two different pens differs in
     exactly one pixel whatever the choice, so it is the same for every rule (except where the hand retouches put a
     pen that was in neither pixel);
  4. draws a sheet (PNG, 3 screen pixels per C64/PC pixel): PC EGA with the CPC inks | C64 now | C64 trazos, each
     C64 version with the colodore colours of src/c64/datos/paleta.tsv, and writes the measures to a TSV.
Nothing of the C64 build is changed by this tool.
"""
import argparse
import os
import sys

from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)
PC = os.path.join(os.path.dirname(RAIZ), "abadia")
sys.path.insert(0, AQUI)
sys.path.insert(0, os.path.join(PC, "trabajo", "re", "notas", "datos"))
import c64_graficos as G          # noqa: E402
import c64_mitad as M             # noqa: E402
_cwd = os.getcwd()
os.chdir(PC)                      # comun.py reads the PC reference by relative paths
from comun import ds_inicial, draw_through   # noqa: E402
os.chdir(_cwd)

PEN_DE_CGA = (3, 0, 1, 2)         # CGA colour -> CPC pen (day: black, cyan, orange, pastel yellow)
# how they look: the PC with the EGA option's inks, the C64 with VICE's colodore palette (paleta.tsv: 3, 8, 7, 0)
TINTA_PC = {0: (60, 60, 72), 1: (255, 128, 0), 2: (255, 255, 128), 3: (0, 0, 0)}
TINTA_C64 = {0: (60, 60, 72), 1: (0x9F, 0x48, 0x15), 2: (0xEF, 0xF3, 0x47), 3: (0, 0, 0)}

# a graphic = (name, parts); a part = (C64 block, PC address in DS 1800:xxxx, CPC address in the tape image, width in
# bytes, lines); the parts are stacked (a monk = a face of 10 lines over a robe, as the game composes it)
def parte(bloque, pa, ca, w, h):
    return (bloque, pa, ca, w, h)


PROTAGONISTAS = [(n, [parte("personajes", pa, ca, w, h)]) for n, pa, ca, w, h in [
    ("Guillermo 0", 0x1322, 0xA300, 5, 36), ("Guillermo 1", 0x13D6, 0xA3B4, 5, 34), ("Guillermo 2", 0x1480, 0xA45E, 5, 34),
    ("Guillermo 3", 0x152A, 0xA508, 5, 35), ("Guillermo 4", 0x15D9, 0xA5B7, 5, 33), ("Guillermo 5", 0x1688, 0xA666, 4, 33),
    ("Adso 0", 0x170C, 0xA6EA, 5, 32), ("Adso 1", 0x17AC, 0xA78A, 5, 32), ("Adso 2", 0x184C, 0xA82A, 5, 31),
    ("Adso 3", 0x18E7, 0xA8C5, 4, 30), ("Adso 4", 0x195F, 0xA93D, 4, 30), ("Adso 5", 0x19D7, 0xA9B5, 4, 30)]]
MONJES = ["Severino", "Abad", "Malaquias", "Berengario", "Bernardo", "Jorge", "Encapuchado"]
CARAS = [(f"Cara {MONJES[i]} {'ab'[j]}", [parte("caras", 0x2125 + 0x64 * i + 0x32 * j, 0xB103 + 0x64 * i + 0x32 * j, 5, 10)])
         for i in range(7) for j in (0, 1)]
HABITOS_DEF = [(0x1B7B, 0xAB59, 26), (0x1BFD, 0xABDB, 24), (0x1C75, 0xAC53, 24), (0x1CED, 0xACCB, 25), (0x1D6A, 0xAD48, 23),
               (0x1DDD, 0xADBB, 23)]
HABITOS = [(f"Habito {k}", [parte("habitos", pa, ca, 5, h)]) for k, (pa, ca, h) in enumerate(HABITOS_DEF)]
# every monk's first face over robe 0 (as the PC sheet shows them; the game puts any face over any robe)
MONJES_COMPUESTOS = [(f"Monje {MONJES[i]}", [parte("caras", 0x2125 + 0x64 * i, 0xB103 + 0x64 * i, 5, 10),
                                            parte("habitos", 0x1B7B, 0xAB59, 5, 26)]) for i in range(7)]
PUERTA = [("Puerta", [parte("puerta", 0x1A6B, 0xAA49, 6, 40)])]
# the objects live in the tile block on the C64 (baldosas), at the CPC pointer the sprite table holds
OBJETOS = [(n, [parte("baldosas", pa, ca, 4, 12)]) for n, pa, ca in [
    ("Lampara", 0x30E2, 0xD7A0), ("Libro", 0x3112, 0xD7D0), ("Gafas", 0x47A2, 0x9720), ("Guantes", 0x47D2, 0x9750),
    ("Llave", 0x4802, 0x9780), ("Pergamino", 0x4832, 0x97B0)]]
GRUPOS = {"protagonistas": PROTAGONISTAS, "caras": CARAS, "habitos": HABITOS, "monjes": MONJES_COMPUESTOS,
          "puerta": PUERTA, "objetos": OBJETOS}


def pc_sprite(ds, tablas, a, w, h):
    """A PC sprite as the game draws it (AND/OR tables 4 and 5 of 1800:D968), as CPC pens, transparent = pen 0."""
    rows = draw_through(ds, w, h, a, tablas[4], tablas[5], {0: "0", 1: "1", 2: "2", 3: "3"}, None)
    return [[0 if p is None else PEN_DE_CGA[int(p)] for p in r] for r in rows]


def c64_antes(antes):
    """The graphics of an earlier conversion (its <block>.bin files and marcos64.tsv): {(block, CPC address): C64 pens}."""
    datos, out = {}, {}
    for linea in open(os.path.join(antes, "marcos64.tsv")):
        if linea.startswith("#") or linea.startswith("block"):
            continue
        blk, ptr, w, h, off, n, nota = linea.rstrip("\n").split("\t")
        if blk not in ("personajes", "caras", "habitos", "puerta", "baldosas") or "start" in nota or "GARBAGE" in nota:
            continue
        if blk not in datos:
            datos[blk] = open(os.path.join(antes, blk + ".bin"), "rb").read()
        out[(blk, int(ptr, 16))] = G.de_filas(datos[blk][int(off):int(off) + int(n)], int(w), int(h))
    return out


def sprite_negro(rows):
    """Mock-up of a hires black sprite over a multicolour body (c64_mitad.cuerpo): rows at the PC's width."""
    cuerpo = M.cuerpo(rows)
    return [[3 if row[x] == 3 else cuerpo[y][x // 2] for x in range(len(row))] for y, row in enumerate(rows)]


def lamina(rows, tinta, escala):
    im = Image.new("RGB", (len(rows[0]) * escala, len(rows) * escala))
    px = im.load()
    for y, r in enumerate(rows):
        for x, p in enumerate(r):
            for dy in range(escala):
                for dx in range(escala):
                    px[x * escala + dx, y * escala + dy] = tinta[p]
    return im


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("salida")
    ap.add_argument("--grupo", default="protagonistas", choices=sorted(GRUPOS))
    ap.add_argument("--escala", type=int, default=3)
    ap.add_argument("--antes", default=os.path.join(RAIZ, "data", "c64graf_sim"))
    ap.add_argument("--columnas", default="pc,antes,trazos")
    ap.add_argument("--ancho-max", type=int, default=0, help="graphics a row chosen to fit this width")
    x = ap.parse_args()
    os.makedirs(x.salida, exist_ok=True)
    ds = ds_inicial()
    tablas = [ds[0xD968 + 0x100 * i:0xD968 + 0x100 * i + 0x100] for i in range(6)]
    m = open(os.path.join(RAIZ, "data", "cpc64", "juego", "ram.bin"), "rb").read()
    actual = c64_antes(x.antes)
    e = x.escala
    columnas = x.columnas.split(",")
    filas_tsv = ["grafico\tpc\tcpc\tw\th\tpc_vs_cpc\tversion\tpixels_dif\tpixels\tsilueta_dif\tperdidos\ttramos"]
    piezas = []
    for nombre, partes in GRUPOS[x.grupo]:
        pc, cpc, viejo, nuevo, cont = [], [], [], [], []
        igual = 0
        for bloque, pa, ca, w, h in partes:          # each part converted on its own, as the build does
            fuente = pc_sprite(ds, tablas, pa, w, h)
            cinta = G.imagen(m, {0xD7A0: 0x88A0, 0xD7D0: 0x88D0}.get(ca, ca), w, h)   # the lamp and the book: tape image address
            igual += sum(1 for yy in range(h) for xx in range(4 * w) if fuente[yy][xx] != cinta[yy][xx])
            pc += fuente
            cpc += cinta
            viejo += actual[(bloque, ca)]
            nuevo += M.trazos(fuente)
            cont += M.contorno(fuente)                # the continuous contours (c64_mitad.contorno)
        pa, ca, w, h = partes[0][1], partes[0][2], partes[0][3], len(pc)
        actual[ca] = viejo
        versiones = [("antes", viejo), ("trazos", nuevo), ("contorno", cont)]
        for ver, mc in versiones:
            r = M.compara(pc, mc)
            filas_tsv.append(f"{nombre}\t{pa:04X}\t{ca:04X}\t{w}\t{h}\t{igual}\t{ver}\t{r['pixels']}\t{r['total']}\t"
                             f"{r['silueta']}\t{r['perdidos']}\t{r['tramos']}")
        simulado = sprite_negro(pc)
        dif_sprite = sum(1 for yy in range(h) for xx in range(4 * w) if simulado[yy][xx] != pc[yy][xx])
        filas_tsv.append(f"{nombre}\t{pa:04X}\t{ca:04X}\t{w}\t{h}\t{igual}\tsprite\t{dif_sprite}\t{4 * w * h}\t-\t-\t-")
        laminas = dict(pc=lambda: lamina(pc, TINTA_PC, e), antes=lambda: lamina(M.doble(viejo), TINTA_C64, e),
                       trazos=lambda: lamina(M.doble(nuevo), TINTA_C64, e), **{"1a1": lambda: lamina(M.doble(pc), TINTA_C64, e)},
                       contorno=lambda: lamina(M.doble(cont), TINTA_C64, e),
                       sprite=lambda: lamina(simulado, TINTA_C64, e))
        piezas.append((nombre, igual, [laminas[c]() for c in columnas]))
        with open(os.path.join(x.salida, f"{nombre.replace(' ', '_')}.txt"), "w") as f:
            ch = {0: ".", 1: "o", 2: "Y", 3: "#"}
            f.write(f"{nombre}: PC {pa:04X} | C64 antes | C64 trazos (C64 pixels printed twice)\n")
            for yy in range(h):
                f.write("".join(ch[p] for p in pc[yy]) + "  " + "".join(ch[p] * 2 for p in actual[ca][yy]) + "  "
                        + "".join(ch[p] * 2 for p in nuevo[yy]) + "\n")
    open(os.path.join(x.salida, f"medidas_{x.grupo}.tsv"), "w").write("\n".join(filas_tsv) + "\n")

    # the sheet: 6 graphics a row (14 for the faces), each as PC | antes | trazos
    por_fila = 14 if x.grupo == "caras" else 6
    ancho_pieza = max(sum(im.width for im in p[2]) for p in piezas) + 4 * (len(columnas) - 1)
    alto_pieza = max(p[2][0].height for p in piezas) + 26
    if x.ancho_max:
        por_fila = max(1, (x.ancho_max - 16) // (ancho_pieza + 14))
    sep = 14
    nfilas = (len(piezas) + por_fila - 1) // por_fila
    hoja = Image.new("RGB", (16 + por_fila * (ancho_pieza + sep), 44 + nfilas * (alto_pieza + sep)), (36, 36, 44))
    d = ImageDraw.Draw(hoja)
    d.text((16, 8), " | ".join({"pc": "PC EGA (tintas CPC)", "antes": "C64 antes", "trazos": "C64 trazos", "contorno": "C64 contorno",
                                "1a1": "C64 1:1 (todos los pixeles, doble ancho)",
                                "sprite": "C64 sprite hires negro + cuerpo multicolor (maqueta)"}[c] for c in columnas)
           + f"   grupo {x.grupo}, x{e}", fill=(255, 220, 120))
    d.text((16, 22), "C64 con la paleta colodore de VICE; gris = transparente", fill=(150, 150, 165))
    for i, (nombre, igual, ims) in enumerate(piezas):
        x0 = 16 + (i % por_fila) * (ancho_pieza + sep)
        y0 = 44 + (i // por_fila) * (alto_pieza + sep)
        xx = x0
        for im in ims:
            hoja.paste(im, (xx, y0))
            xx += im.width + 4
        d.text((x0, y0 + ims[0].height + 3), nombre + ("" if igual == 0 else f"  PC!=CPC {igual}"), fill=(225, 225, 225))
        d.text((x0, y0 + ims[0].height + 14), " | ".join(columnas), fill=(150, 150, 165))
    ruta = os.path.join(x.salida, f"hoja_{x.grupo}.png")
    hoja.save(ruta)
    print(ruta, hoja.size)
    print("\n".join(filas_tsv))


if __name__ == "__main__":
    main()
