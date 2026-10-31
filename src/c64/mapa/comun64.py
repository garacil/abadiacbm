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

"""What the C64 pictures of c64/mapa share: the C64 image and its symbols, the C64 palette, the C64's own
letters, the multicolour pixels.

* The 6502 game image: c64/juego_final/juego.bin (built with -D PRUEBA, as the host's --juego6502 runs it), its
  symbols mapa64.inc (the data, D64_*), juego.lbl (the routines), plataforma.inc.
* The colours: VICE's colodore palette (/usr/share/vice/C64/colodore.vpl), the one the project judged the colours
  on (c64/datos/paleta.tsv, doc/revisiones/pantalla_carga/pantalla.py); the game's pens -> C64 colours of c64/datos/paleta.tsv.
* The letters: the C64 character ROM (/usr/share/vice/C64/chargen-901225-01.bin), its lower/upper case set;
  the C64 has no accents (they are dropped) and no right or down arrow (drawn here in its style).
* A bitmap byte holds 4 multicolour pixels, each two screen pixels wide; bit pairs 00 = $D021 (CPC pen 3),
  01 = screen RAM high nibble (pen 0), 10 = low nibble (pen 1), 11 = colour RAM (pen 2) (c64/NOTAS_GRAFICOS.md).
"""
import os
import unicodedata

from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
JUEGO = os.path.join(RAIZ, 'c64', 'juego_final')
VICE = '/usr/share/vice/C64'

PALETA = [tuple(int(t, 16) for t in l.split()[:3])
          for l in open(os.path.join(VICE, 'colodore.vpl')) if l.strip() and not l.startswith('#')]
NOMBRES = ('negro', 'blanco', 'rojo', 'cian', 'púrpura', 'verde', 'azul', 'amarillo', 'naranja', 'marrón',
           'rojo claro', 'gris oscuro', 'gris', 'verde claro', 'azul claro', 'gris claro')
# the game's palettes as C64 colours, pens 0-3 (c64/datos/paleta.tsv: CPC inks of 3A73h-3A7Dh and 610Fh)
DIA = (3, 8, 7, 0)            # pen 0 cyan, 1 orange, 2 yellow, 3 black
NOCHE = (6, 4, 12, 0)         # pen 0 blue, 1 purple, 2 grey, 3 black
PERGAMINO = (10, 2, 0, 2)     # pen 0 light red, 1 red, 2 black, 3 red
PAR_PLUMA = (3, 0, 1, 2)      # multicolour bit pair -> CPC pen


def simbolos():
    """The names of the 6502 image: mapa64.inc, plataforma.inc, zp.inc (NAME = $XXXX) and juego.lbl."""
    s = {}
    for f in ('mapa64.inc', 'plataforma.inc', 'zp.inc'):
        for l in open(os.path.join(JUEGO, f)):
            t = l.split()
            if len(t) >= 3 and t[1] == '=' and t[2].startswith('$'):
                s[t[0]] = int(t[2][1:], 16)
    for l in open(os.path.join(JUEGO, 'juego.lbl')):
        t = l.split()
        if len(t) == 3 and t[0] == 'al':
            s[t[2].lstrip('.')] = int(t[1], 16)
    return s


def bloques():
    """The blocks of mapa64.tsv: name -> (CPC start or None, CPC length, C64 start, C64 length)."""
    out = {}
    for l in open(os.path.join(JUEGO, 'mapa64.tsv')):
        t = l.split()
        if l.startswith('#') or len(t) < 8:
            continue
        try:
            out[t[0]] = (None if t[1] == '-' else int(t[1], 16), int(t[2]), int(t[3], 16), int(t[4]))
        except ValueError:
            continue
    return out


def pixeles(datos, ancho_bytes, alto, pal=DIA):
    """Rows of RGB of a bitmap in multicolour pixel pairs (each C64 pixel twice), ancho_bytes a line."""
    filas = []
    for y in range(alto):
        f = []
        for x in range(ancho_bytes * 4):
            b = datos[y * ancho_bytes + x // 4]
            c = PALETA[pal[PAR_PLUMA[(b >> (6 - 2 * (x % 4))) & 3]]]
            f += (c, c)
        filas.append(f)
    return filas


def imagen(filas):
    im = Image.new('RGB', (len(filas[0]), len(filas)))
    im.putdata([p for f in filas for p in f])
    return im


# ------------------------------------------------------------------ the C64's letters

_ROM = open(os.path.join(VICE, 'chargen-901225-01.bin'), 'rb').read()[2048:]      # lower/upper case set
_PROPIOS = {                                          # in the ROM's style: 2-pixel strokes
    '→': (0x00, 0x18, 0x0C, 0xFE, 0x0C, 0x18, 0x00, 0x00),
    '↓': (0x18, 0x18, 0x18, 0x18, 0x7E, 0x3C, 0x18, 0x00),
    '↑': (0x18, 0x3C, 0x7E, 0x18, 0x18, 0x18, 0x18, 0x00),
    '↔': (0x00, 0x24, 0x66, 0xFF, 0x66, 0x24, 0x00, 0x00),
}


def _glifo(ch):
    if ch in _PROPIOS:
        return _PROPIOS[ch]
    ch = unicodedata.normalize('NFD', ch)[0]
    o = ord(ch)
    if 'a' <= ch <= 'z':
        c = o - 96
    elif 'A' <= ch <= 'Z':
        c = o
    elif 32 <= o <= 63 or ch in '[]@':
        c = {'@': 0, '[': 27, ']': 29}.get(ch, o)
    elif ch == '_':
        c = 100
    else:
        c = 63
    return _ROM[8 * c:8 * c + 8]


def ancho_texto(s, tam=1, margen=2):
    return 8 * len(s) * tam + 2 * margen


def texto(img, x, y, s, color, tam=1, fondo=None, margen=2):
    """Writes s with the C64's letters (color, fondo: RGB); returns the size of its box."""
    m = Image.new('L', (8 * len(s), 8))
    m.putdata([255 if _glifo(ch)[yy] >> (7 - xx) & 1 else 0 for yy in range(8) for ch in s for xx in range(8)])
    if tam > 1:
        m = m.resize((m.width * tam, m.height * tam), Image.NEAREST)
    w, h = m.width + 2 * margen, m.height + 2 * margen
    if fondo is not None:
        img.paste(fondo, (x, y, x + w, y + h))
    img.paste(color, (x + margen, y + margen), m)
    return w, h
