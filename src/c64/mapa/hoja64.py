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

"""Every graphic of the Commodore 64 version on one sheet, in its C64 format and colours, labelled with its C64
address (and the CPC address it comes from).

    python3 -I c64/mapa/hoja64.py [OUT.png]       (default c64/mapa/graficos_c64.png; needs PIL)

The game's graphics are read from the 6502 game image (c64/juego_final/juego.bin) at the addresses of its map
(mapa64.tsv), in the formats of c64/NOTAS_GRAFICOS.md, the frames as data/c64graf/marcos64.tsv lists them;
drawn as the C64 shows them (a multicolour pixel two screen pixels wide) with the game's inks as C64 colours
(c64/datos/paleta.tsv) and VICE's colodore palette, everything twice its size.  The disk's other pictures are
the presentation's (c64/presentacion): the loading picture abadia.koa (Koala: 8000 bytes of bitmap, 1000 of screen RAM, 1000
of colour RAM, background black) and the parchment's gothic letters (pp.bin, as datos.glifos reads them), with
a VICE capture of its first page (c64/presentacion/resultados, made by c64/presentacion/pruebas/disco_prueba/prueba.py).
"""
import os
import sys

from PIL import Image, ImageDraw

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
sys.dont_write_bytecode = True                 # nothing written next to the modules it reads
from comun64 import (RAIZ, JUEGO, PALETA, NOMBRES, DIA, NOCHE, PERGAMINO, PAR_PLUMA, bloques, pixeles, imagen,  # noqa: E402
                     texto, ancho_texto)

C = PALETA
FONDO = C[6]
LETRA = C[14]
TITULO = C[1]
NOTA = C[15]
HUECO = C[11]                  # transparent pixels (pen 0) of the sprites
ESCALA = 2
ANCHO = 1500

M = open(os.path.join(JUEGO, 'juego.bin'), 'rb').read()
B = bloques()


def marcos():
    out = []
    for l in open(os.path.join(RAIZ, '..', 'data', 'c64graf', 'marcos64.tsv')):
        t = l.rstrip('\n').split('\t')
        if l.startswith('#') or t[0] == 'block':
            continue
        out.append(dict(bloque=t[0], cpc=int(t[1], 16), w=int(t[2]), h=int(t[3]), off=int(t[4]), n=int(t[5]), nota=t[6]))
    return out


def dir64(bloque, off=0):
    return B[bloque][2] + off


def grande(im, k=ESCALA):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def sprite(a, w, h, pal=DIA, transparente=True):
    """A row-major sprite of w CPC bytes (= nibbles) x h lines at C64 address a: ceil(w/2) bytes a line."""
    bpl = (w + 1) // 2
    filas = pixeles(M[a:a + bpl * h], bpl, h, pal)
    filas = [f[:w * 4] for f in filas]                  # an odd width: the last nibble is padding
    if transparente:
        cero = C[pal[0]]
        for y in range(h):
            for x in range(0, w * 4, 2):
                b = M[a + y * bpl + x // 8]
                if PAR_PLUMA[(b >> (6 - 2 * ((x // 2) % 4))) & 3] == 0:
                    filas[y][x] = filas[y][x + 1] = HUECO
                else:
                    pass
        del cero
    return grande(imagen(filas))


def baldosa(n, pal):
    """Tile n: 16 bytes at $D000 + 16n, column-major (8 lines of the left byte, then 8 of the right one)."""
    a = dir64('baldosas', 16 * n)
    datos = bytes(M[a + col * 8 + l] for l in range(8) for col in range(2))
    return grande(imagen(pixeles(datos, 2, 8, pal)))


class Hoja:
    def __init__(self):
        self.piezas = []            # (x, y, image or callable)
        self.y = 20

    def titulo(self, t, tam=2):
        self.piezas.append((20, self.y, ('t', t, TITULO, tam)))
        self.y += 8 * tam + 10

    def linea(self, t, color=NOTA):
        self.piezas.append((20, self.y, ('t', t, color, 1)))
        self.y += 12

    def fila(self, items, sep=14, margen=20):
        """items: (image, [caption lines]); laid out left to right, wrapping at ANCHO."""
        x, alto = margen, 0
        for im, cap in items:
            w = max(im.width, max((ancho_texto(c) for c in cap), default=0))
            if x + w > ANCHO - 20 and x > margen:
                self.y += alto + sep
                x, alto = margen, 0
            self.piezas.append((x, self.y, im))
            for i, c in enumerate(cap):
                self.piezas.append((x - 2, self.y + im.height + 2 + 11 * i, ('t', c, LETRA, 1)))
            alto = max(alto, im.height + 4 + 11 * len(cap))
            x += w + sep
        self.y += alto + sep + 6

    def pinta(self, destino):
        L = Image.new('RGB', (ANCHO, self.y + 20), FONDO)
        for x, y, p in self.piezas:
            if isinstance(p, tuple):
                texto(L, x, y, p[1], p[2], p[3])
            else:
                L.paste(p, (x, y))
        L.save(destino, optimize=True)
        return L.size


def muestra(color, w=24, h=16):
    im = Image.new('RGB', (w, h), C[color])
    ImageDraw.Draw(im).rectangle((0, 0, w - 1, h - 1), outline=C[0])
    return im


def paletas(H):
    H.titulo('Tintas: las plumas del juego como colores del C64 (paleta colodore de VICE)', 1)
    for nombre, pal in (('dia (prima a visperas)', DIA), ('noche (completas, noche)', NOCHE),
                        ('pergamino del juego', PERGAMINO)):
        H.fila([(muestra(c), [f'pluma {p}', f'{c} {NOMBRES[c]}', f'#{C[c][0]:02X}{C[c][1]:02X}{C[c][2]:02X}'])
                for p, c in enumerate(pal)] + [(Image.new('RGB', (1, 16), FONDO), [nombre])], sep=30)
    H.linea('Cada byte del bitmap son 4 pixeles multicolor (pares 00 = $D021 pluma 3, 01 = pantalla alta pluma 0, '
            '10 = pantalla baja pluma 1, 11 = RAM de color pluma 2); cada pixel C64 vale dos del CPC.')
    H.linea('Todas las celdas llevan las mismas cuatro tintas, como el CPC: el dia y la noche cambian solo las tintas. '
            'Gris oscuro en los sprites = transparente (pluma 0).')
    H.y += 8


def personajes(H, MS):
    H.titulo('Personajes, puerta y objetos (sprites: pluma 0 transparente)', 1)
    for quien, lo, hi in (('Guillermo', 0xA300, 0xA6EA), ('Adso', 0xA6EA, 0xAA2D)):
        items = []
        for m in MS:
            if m['bloque'] == 'personajes' and lo <= m['cpc'] < hi and 'frame' in m['nota']:
                a = dir64('personajes', m['off'])
                items.append((sprite(a, m['w'], m['h']), [f'${a:04X}', f'{m["w"]}x{m["h"]}', f'CPC {m["cpc"]:04X}']))
        H.linea(f'{quien}: los fotogramas de su animacion (el juego los voltea en su sitio para mirar al otro lado)',
                TITULO)
        H.fila(items)
    items = [(sprite(dir64('puerta'), 6, 40), [f'puerta ${dir64("puerta"):04X}', '6x40', 'CPC AA49'])]
    for m in MS:
        if m['bloque'] == 'baldosas' and 'GARBAGE' not in m['nota']:
            a = dir64('baldosas', m['off'])
            nombre = m['nota'].split(':')[1].split('(')[0].strip()
            nombre = {'glasses': 'gafas', 'object 1': 'objeto 1', 'keys': 'llaves', 'parchment': 'pergamino',
                      'lamp': 'lampara', 'book': 'libro'}.get(nombre, nombre)
            items.append((sprite(a, 4, 12), [nombre, f'${a:04X}', f'CPC {m["cpc"]:04X}']))
    H.fila(items)
    H.titulo('Monjes: los habitos y las caras', 1)
    items = []
    for m in MS:
        if m['bloque'] == 'habitos':
            a = dir64('habitos', m['off'])
            items.append((sprite(a, 5, m['h']), [f'${a:04X}', f'5x{m["h"]}', f'CPC {m["cpc"]:04X}']))
    H.linea('Habitos (el juego los dibuja tambien volteados: bit 14 de su puntero)', TITULO)
    H.fila(items)
    items = []
    for m in MS:
        if m['bloque'] == 'caras':
            a = dir64('caras', m['off'])
            quien = m['nota'].split(' (')[0]
            segunda = quien.startswith('second ')
            quien = quien.replace('second face of ', '').replace('face of ', '')
            quien = {'abbot': 'abad', 'hooded monk': 'encapuchado'}.get(quien, quien)
            quien = ('2a ' if segunda else '') + quien
            items.append((sprite(a, 5, 10), [quien, f'${a:04X}', f'CPC {m["cpc"]:04X}']))
    H.fila(items, sep=10)


def baldosas(H):
    H.titulo('Las baldosas de las salas: 218 huecos de 16 bytes en $D000 (debajo de la E/S), de dia y de noche', 1)
    H.linea('Baldosa n en $D000 + 16n: 8 lineas de la columna izquierda y luego 8 de la derecha.  01-0A opacas; 0B-7F '
            'con la pluma 2 transparente; 80-D9 con la pluma 1 transparente.')
    H.linea('Los huecos 2D-2F y A1-A6 guardan los graficos de los objetos (arriba); 00, 6D, 73, 85 y 86 no los dibuja '
            'ninguna sala.')
    obj = set(range(0x2D, 0x30)) | set(range(0xA1, 0xA7))
    libres = {0x00, 0x6D, 0x73, 0x85, 0x86}
    por_fila = 8
    ancho_celda = 2 * 16 * ESCALA + 6
    for base in range(0, 0xDA, por_fila * 2):
        items = []
        for n in range(base, min(base + por_fila * 2, 0xDA)):
            im = Image.new('RGB', (ancho_celda, 8 * ESCALA + 2), FONDO)
            if n in obj:
                ImageDraw.Draw(im).rectangle((0, 0, ancho_celda - 1, 8 * ESCALA + 1), outline=C[14])
                texto(im, 6, 1, 'objeto', C[14])
            else:
                im.paste(baldosa(n, DIA), (0, 1))
                im.paste(baldosa(n, NOCHE), (16 * ESCALA + 6, 1))
            items.append((im, [f'{n:02X} ${dir64("baldosas", 16 * n):04X}' + (' -' if n in libres else '')]))
        H.fila(items, sep=8)


def marcador(H):
    H.titulo('El marcador y su letra', 1)
    a = dir64('marcador')
    datos = bytes(M[a + (y // 8) * 256 + (x // 1) * 8 + y % 8] for y in range(32) for x in range(32))
    H.fila([(grande(imagen(pixeles(datos, 32, 32))), [f'marcador ${a:04X}: filas 20-23 del bitmap, en su orden',
                                                       '(4 filas x 32 celdas x 8 bytes), CPC C600 D600 E600 F600'])])
    items = []
    for i, n in enumerate(('V', 'I')):
        r = dir64('romanos', 8 * i)
        items.append((grande(imagen(pixeles(M[r:r + 8], 1, 8))), [f'{n} ${r:04X}', '2x8']))
    f = dir64('fuente')
    glifos = Image.new('RGB', (46 * 10, 8), C[7])
    for g in range(46):
        for y in range(8):
            b = M[f + 4 * g + y // 2]
            nib = b >> 4 if y % 2 == 0 else b & 15
            for x in range(4):
                if nib >> (3 - x) & 1:
                    glifos.putpixel((g * 10 + 2 * x, y), C[0])
                    glifos.putpixel((g * 10 + 2 * x + 1, y), C[0])
    items.append((grande(glifos), [f'letra ${f:04X}: 46 signos, codigos 2Dh-5Ah, 4 bytes cada uno',
                                   '(filas 2k y 2k+1 en los nibbles), pixel puesto = pluma 3 sobre la pluma 2']))
    H.fila(items, sep=24)
    lz = dir64('luz')
    luz = Image.new('RGB', (16 * 8, 15 * 4), C[0])
    d = ImageDraw.Draw(luz)
    for fila in range(15):
        v = M[lz + 2 * fila] << 8 | M[lz + 2 * fila + 1]
        for b in range(16):
            if v >> (15 - b) & 1:
                d.rectangle((b * 8, fila * 4, b * 8 + 7, fila * 4 + 3), fill=C[7])
    cola = Image.new('RGB', (4 * 20, 8), C[0])
    co = dir64('cola_obsequium')
    for k in range(4):
        nib = M[co + k] & 15
        for x in range(2):
            if (nib >> (2 - 2 * x)) & 3:
                cola.paste(C[7], (k * 20 + 4 * x, 0, k * 20 + 4 * x + 4, 8))
    H.fila([(grande(luz), [f'luz de la lampara ${lz:04X}: 15 palabras, un bit por nibble C64', '(amarillo = se ve)']),
            (grande(cola), [f'cola del obsequium ${co:04X}', 'obsequium & 3 = 0, 1, 2, 3'])], sep=30)


def carga(H):
    H.titulo('La pantalla de carga del disco: mi abadia.koa (Koala, fondo negro)', 1)
    k = open(os.path.join(RAIZ, 'c64', 'presentacion', 'original', 'graphics', 'abadia.koa'), 'rb').read()
    bm, sc, co = k[:8000], k[8000:9000], k[9000:10000]
    im = Image.new('RGB', (320, 200))
    px = im.load()
    for cy in range(25):
        for cx in range(40):
            c = cy * 40 + cx
            col = (0, sc[c] >> 4, sc[c] & 15, co[c] & 15)
            for l in range(8):
                b = bm[c * 8 + l]
                for x in range(4):
                    rgb = C[col[(b >> (6 - 2 * x)) & 3]]
                    px[cx * 8 + 2 * x, cy * 8 + l] = rgb
                    px[cx * 8 + 2 * x + 1, cy * 8 + l] = rgb
    H.fila([(grande(im), ['c64/presentacion/original/graphics/abadia.koa: se ve mientras carga el juego'])])


def pergamino(H):
    H.titulo('El pergamino del disco (mi programa): sus letras goticas y su primera pagina', 1)
    sys.path.insert(0, os.path.join(RAIZ, 'c64', 'presentacion'))
    import datos                                                    # noqa: E402
    pp = open(os.path.join(RAIZ, 'c64', 'presentacion', 'generado', 'pp.bin'), 'rb').read()
    gl = datos.glifos(pp)
    items = []
    for code in sorted(gl):
        pix, avance = gl[code]
        if not pix:
            continue
        w = max(x for x, y in pix) + 1
        h = max(y for x, y in pix) + 1
        im = Image.new('RGB', (max(w, avance), h), C[10])
        for x, y in pix:
            im.putpixel((x, y), C[2] if 0x40 <= code <= 0x5F else C[0])
        items.append((grande(im), [f'{code:02X} {chr(code) if code != 0x60 else "@"}']))
    H.fila(items, sep=8)
    cap = os.path.join(RAIZ, 'c64', 'presentacion', 'resultados', '2_pergamino_pagina_1.png')
    if os.path.exists(cap):
        H.fila([(grande(Image.open(cap).convert('RGB')), ['la primera pagina en VICE (c64/presentacion/pruebas/disco_prueba/prueba.py)'])])


def main(destino):
    H = Hoja()
    H.titulo('La Abadia del Crimen en el Commodore 64: todos los graficos')
    H.linea('Leidos de la imagen del juego 6502 (c64/juego_final/juego.bin) en sus direcciones C64 (c64/juego_final/'
            'mapa64.tsv), con su origen en el CPC de 64 KiB; al doble de tamano.', LETRA)
    H.linea('Formatos: c64/NOTAS_GRAFICOS.md (un byte CPC = un nibble C64; los sprites por filas, ceil(w/2) bytes cada '
            'una; w y h en bytes CPC y lineas).', LETRA)
    H.y += 10
    paletas(H)
    MS = marcos()
    personajes(H, MS)
    baldosas(H)
    marcador(H)
    carga(H)
    pergamino(H)
    w, h = H.pinta(destino)
    print(f'{destino}: {w}x{h}')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(AQUI, 'graficos_c64.png'))
