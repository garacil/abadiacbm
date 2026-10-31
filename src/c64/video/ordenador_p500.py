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
"""A drawing of the Commodore P500 (the CBM-II 510: one wedge-shaped case with the keyboard; the keys in four groups:
the ten function keys on top, the typewriter keys, the cursor and editing keys, the numeric keypad), for the P500
video's title card and thumbnails (monta.py, miniaturas.py --p500).  Drawn here from simple shapes, in the machine's
two-tone colours (a cream case, dark keys, lighter function keys): no photograph is used.

    ordenador_p500.py OUT.png [WIDTH]       (RGBA, transparent around the case)"""
import os, sys
from PIL import Image, ImageDraw, ImageFont

FUENTE = next((f for f in ("/usr/share/fonts/TTF/Arial-Black.ttf", "/usr/share/fonts/liberation/LiberationSans-Bold.ttf",
                           "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf") if os.path.exists(f)), None)
CREMA, CREMA_OSCURA, SOMBRA = (226, 214, 186), (196, 182, 152), (150, 138, 112)
TECLA, TECLA_ALTA, TECLA_BORDE = (64, 58, 54), (94, 88, 82), (34, 30, 28)
FUNCION, FUNCION_ALTA = (176, 120, 70), (206, 150, 96)


def tecla(d, x, y, w, h, color=TECLA, alta=TECLA_ALTA, k=1.0):
    r = max(2, int(3 * k))
    d.rounded_rectangle([x, y, x + w, y + h], radius=r, fill=TECLA_BORDE)
    d.rounded_rectangle([x + 2 * k, y + 1 * k, x + w - 2 * k, y + h - 4 * k], radius=r, fill=color)
    d.rounded_rectangle([x + 4 * k, y + 3 * k, x + w - 4 * k, y + h - 7 * k], radius=r, fill=alta)


def dibuja(ancho=1200):
    k = ancho / 1200
    alto = int(560 * k)
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # the case: a wedge seen from the front and above (the back higher), its front edge darker
    d.polygon([(40 * k, 130 * k), (1160 * k, 130 * k), (1190 * k, 480 * k), (10 * k, 480 * k)], fill=CREMA)
    d.polygon([(10 * k, 480 * k), (1190 * k, 480 * k), (1190 * k, 530 * k), (10 * k, 530 * k)], fill=CREMA_OSCURA)
    d.polygon([(40 * k, 60 * k), (1160 * k, 60 * k), (1160 * k, 130 * k), (40 * k, 130 * k)], fill=CREMA_OSCURA)
    d.line([(40 * k, 130 * k), (1160 * k, 130 * k)], fill=SOMBRA, width=max(1, int(3 * k)))
    d.rectangle([10 * k, 528 * k, 1190 * k, 540 * k], fill=SOMBRA)
    # the badge on the back panel
    if FUENTE:
        f = ImageFont.truetype(FUENTE, int(34 * k))
        d.text((70 * k, 76 * k), "commodore", font=f, fill=(60, 60, 70))
        f2 = ImageFont.truetype(FUENTE, int(30 * k))
        w = d.textlength("P500", font=f2)
        d.text((1130 * k - w, 78 * k), "P500", font=f2, fill=(60, 60, 70))
    # the function keys (ten, in two groups of five) and the editing keys of the top row
    y0, s = 150 * k, 54 * k
    for i in range(10):
        x = (80 + i * 64 + (30 if i >= 5 else 0)) * k
        tecla(d, x, y0, 58 * k, 34 * k, FUNCION, FUNCION_ALTA, k)
    for i in range(4):
        tecla(d, (800 + i * 64) * k, y0, 58 * k, 34 * k, k=k)
    # the typewriter keys: five rows, each shifted as on the machine, and the long space bar
    filas = [(80, 14), (110, 13), (125, 12), (155, 11)]
    for r, (x0, n) in enumerate(filas):
        y = 200 * k + r * s
        for i in range(n):
            tecla(d, (x0 + i * 52) * k, y, 48 * k, 48 * k, k=k)
    tecla(d, 250 * k, 200 * k + 4 * s, 420 * k, 48 * k, k=k)
    # the cursor keys and the numeric keypad on the right
    for i in range(2):
        for j in range(2):
            tecla(d, (840 + i * 52) * k, 200 * k + (j + 1) * s, 48 * k, 48 * k, k=k)
    for r in range(5):
        for c in range(4):
            tecla(d, (960 + c * 52) * k, 200 * k + r * s, 48 * k, 48 * k, k=k)
    return img


if __name__ == "__main__":
    ancho = int(sys.argv[2]) if len(sys.argv) > 2 else 1200
    dibuja(ancho).save(sys.argv[1])
    print(sys.argv[1])
