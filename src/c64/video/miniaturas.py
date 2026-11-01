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

"""The videos' thumbnails (1280x720 PNG), as the PC video's (abadia-english/partida/miniaturas.py): the loading
picture as VICE shows it (captura_carga.py: 384x272, the picture at 32,35), at 4:3 (960x720) and centred, a band at
the bottom with the words.  Nothing is drawn on the picture but the band.

    miniaturas.py es|en VICE_SCREENSHOT.png OUT.png [--c128 | --p500]

--p500: the P500's, with the computer drawn at the top right (ordenador_p500.py)."""
import os, sys
from PIL import Image, ImageDraw, ImageFont

FONT = None
for c in ("/usr/share/fonts/TTF/Arial-Black.ttf", "/usr/share/fonts/TTF/ariblk.ttf",
          "/usr/share/fonts/liberation/LiberationSans-Bold.ttf", "/usr/share/fonts/TTF/LiberationSans-Bold.ttf",
          "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"):
    if os.path.exists(c):
        FONT = c
        break
LINEAS = {"es": ("PARTIDA COMPLETA", "COMMODORE {m}  ·  ESPAÑOL"),
          "en": ("FULL PLAYTHROUGH", "COMMODORE {m}  ·  ENGLISH")}


def compone(imagen, linea1, linea2, salida):
    lienzo = Image.new("RGB", (1280, 720), (8, 8, 8))
    lienzo.paste(imagen.resize((960, 720), Image.BOX), (160, 0))
    capa = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
    ImageDraw.Draw(capa).rectangle([160, 560, 1120, 720], fill=(0, 0, 0, 205))
    lienzo = Image.alpha_composite(lienzo.convert("RGBA"), capa)
    d = ImageDraw.Draw(lienzo)
    f1, f2 = ImageFont.truetype(FONT, 66), ImageFont.truetype(FONT, 38)
    for texto, fuente, y, color in ((linea1, f1, 572, (255, 232, 130)), (linea2, f2, 650, (255, 255, 255))):
        w = d.textlength(texto, font=fuente)
        d.text(((1280 - w) / 2, y), texto, font=fuente, fill=color, stroke_width=3, stroke_fill=(0, 0, 0))
    lienzo.convert("RGB").save(salida, optimize=True)


def main():
    idioma, fuente, salida = sys.argv[1:4]
    img = Image.open(fuente).convert("RGB").crop((32, 35, 352, 235))
    l1, l2 = LINEAS[idioma]
    p500 = "--p500" in sys.argv
    compone(img, l1, l2.format(m="P500" if p500 else "128" if "--c128" in sys.argv else "64"), salida)
    if p500:
        # the P500: the computer itself, drawn (ordenador_p500.py), at the top right over the picture's corner
        sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
        from ordenador_p500 import maquina
        lienzo = Image.open(salida).convert("RGBA")
        if os.environ.get("ABADIA_FOTO_P500"):  # the photograph: a quarter of the width, in the bottom right corner
            from PIL import ImageFilter         # above the band, with a soft shadow (no box behind it)
            maq = maquina(320)
            x, y = 1280 - maq.width - 8, 560 - maq.height - 6
            sombra = Image.new("RGBA", lienzo.size, (0, 0, 0, 0))
            sombra.paste((0, 0, 0, 170), (x + 5, y + 6), maq.getchannel("A"))
            lienzo.alpha_composite(sombra.filter(ImageFilter.GaussianBlur(7)))
            lienzo.alpha_composite(maq, (x, y))
        else:
            maq = maquina(420)
            fondo = Image.new("RGBA", (maq.width + 24, maq.height + 16), (0, 0, 0, 170))
            lienzo.alpha_composite(fondo, (1280 - fondo.width - 14, 14))
            lienzo.alpha_composite(maq, (1280 - maq.width - 26, 22))
        lienzo.convert("RGB").save(salida, optimize=True)
    print(salida, FONT)


if __name__ == "__main__":
    main()
