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

"""Data of a parchment of the CPC 64 KiB version, as C source for the C64 program.

    c64_pergamino_datos.py STAGE_RAM OUT.c

STAGE_RAM is the CPC memory when the parchment's code is entered at 6000h: the introduction
(ABADIA64.BAS once unpacked, data/cpc64/perg_inicial/ram.bin) or the ending (ABADIA64.BN1 loaded
and unpacked by the game at 3346h, data/cpc64/final_6000/ram.bin), both made by cpc_carga.py.
Both files carry the same code at 6000h-68A8h; only the text, the music and where the borders lie
differ, so the addresses are read from the code's own operands (the reading, see ESTADO.md):
  [6028h]  the text, ended by 1Ah (intro 8400h, ending 7400h)   6772h  glyph pointers for 20h..7Ch (0 = none)
  [655Bh]  top border, 48 columns x 8 lines     [6567h]  right border, 192 lines x 2 bytes
  [6573h]  left border, 192 lines x 2 bytes     [657Fh]  bottom border, 48 columns x 8 lines
  (intro 788Ah 7A0Ah 7B8Ah 7D0Ah, ending 8400h 8580h 8700h 8880h)
  68A9h  the corner pattern (4 bytes)           610Fh  inks: pen 3, 2, 1, 0, border
  [601Ah]  the music (1 KiB, tempo in its last byte, 8000h in both)  6148h-6199h  the player's state
Glyph bytes: YX = a pixel at cursor + (X, Y); Fw = end of the glyph, advance w.
The blank parchment (CPC 6515h) is computed here as the C64 program drew it byte by byte (pixel.s's
colour rule, pens -> C64 colours from src/c64/datos/paleta.tsv): only the cells the borders change are
written out, with their bitmap bytes and colours.
"""
import os, sys

P = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from licencia import cabecera   # noqa: E402  (the GPL header of the generated sources)


def paleta():
    m = {}
    for line in open(os.path.join(P, "src", "c64", "datos", "paleta.tsv")):
        if line.startswith("#") or not line.strip(): continue
        t = line.rstrip("\n").split("\t")
        m[int(t[0], 16)] = int(t[2])
    return m


def cpc_pixels(b):
    return [((b >> (7 - i)) & 1) | (((b >> (3 - i)) & 1) << 1) for i in range(4)]


def w(m, a):
    return m[a] | m[a + 1] << 8


def bordes(m):
    """top, right, left, bottom: the operands of LD DE,nnnn at 655Ah, 6566h, 6572h, 657Eh"""
    for a in (0x655A, 0x6566, 0x6572, 0x657E):
        assert m[a] == 0x11, f"not LD DE,nnnn at {a:04X}"
    return [w(m, a + 1) for a in (0x655A, 0x6566, 0x6572, 0x657E)]


SUPLENTE = (3, 2, 1, 0)                  # pen standing in when a cell has no room (pixel.s)


def pon_byte(bitmap, cells, colour, xb, y, v):
    """src/c64/pergamino/pixel.s _pon_byte_rapido on a C64 hires bitmap and its cell colours: the CPC byte v
    at window byte column xb, line y (the nibble of cell column (xb + 8) / 2), each pixel's pen decided
    as the pixels arrive (no capital sprites here)."""
    ci = (y >> 3) * 40 + ((xb + 8) >> 1)
    bi = ci * 8 + (y & 7)
    alto = (xb + 8) & 1 == 0

    def decide(pen):                     # True: set the bit (the cell's fg); False: clear it (bg)
        c = colour[pen]
        fg, bg = cells[ci] >> 4, cells[ci] & 15
        if c == bg: return False
        if c == fg: return True
        if fg == bg or pen == 1 or not any(bitmap[ci * 8:ci * 8 + 8]):
            cells[ci] = c << 4 | bg
            return True
        return colour[SUPLENTE[pen]] != bg

    def bit(i, poner):
        b = (0x80 >> i) if alto else (0x08 >> i)
        bitmap[bi] = bitmap[bi] | b if poner else bitmap[bi] & ~b & 0xFF

    uniforme = {0x00: 0, 0xF0: 1, 0x0F: 2, 0xFF: 3}
    if v in uniforme:
        poner = decide(uniforme[v])
        for i in range(4): bit(i, poner)
    else:
        for i, pen in enumerate(cpc_pixels(v)):
            bit(i, decide(pen))


def blank(m, colour):
    """main.c pergamino_en_blanco (CPC 6515h) as the C64 program did it byte by byte: cells of one colour
    (columns 8-31 of rows 0-23 pen 0, the rest pen 1), then the four borders in the CPC's order.  Returns
    the bitmap and the cell colours."""
    bitmap, cells = bytearray(8000), bytearray(1000)
    for cy in range(25):
        for cx in range(40):
            c = colour[0] if cy < 24 and 8 <= cx < 32 else colour[1]
            cells[cy * 40 + cx] = c << 4 | c
    arriba, derecha, izquierda, abajo = bordes(m)
    src = arriba
    for col in range(48):                                          # top, column-major
        for l in range(8): pon_byte(bitmap, cells, colour, col + 8, l, m[src]); src += 1
    src = derecha
    for l in range(192):                                           # right
        pon_byte(bitmap, cells, colour, 0xDA >> 2, l, m[src]); pon_byte(bitmap, cells, colour, (0xDA >> 2) + 1, l, m[src + 1]); src += 2
    src = izquierda
    for l in range(192):                                           # left
        pon_byte(bitmap, cells, colour, 8, l, m[src]); pon_byte(bitmap, cells, colour, 9, l, m[src + 1]); src += 2
    src = abajo
    for col in range(48):                                          # bottom
        for l in range(8): pon_byte(bitmap, cells, colour, col + 8, 0xB8 + l, m[src]); src += 1
    return bitmap, cells


def arr(ctype, name, data, per=20):
    rows = ",\n".join("  " + ",".join(f"0x{b:02X}" if ctype != "unsigned int" else f"0x{b:04X}" for b in data[i:i + per]) for i in range(0, len(data), per))
    return f"const {ctype} {name}[{len(data)}] = {{\n{rows}\n}};\n"


def main():
    m = open(sys.argv[1], "rb").read()
    pal = paleta()
    inks = [m[0x610F + i] for i in range(5)]                       # pen 3, 2, 1, 0, border
    pen_hw = {3: inks[0], 2: inks[1], 1: inks[2], 0: inks[3]}
    colour = {p: pal[hw] for p, hw in pen_hw.items()}
    border = pal[inks[4]]
    assert m[0x6026:0x6028] == b"\xDD\x21" and m[0x6019] == 0x21, "not the parchment code"
    texto, musica = w(m, 0x6028), w(m, 0x601A)
    end = m.index(0x1A, texto)
    text = m[texto:end + 1]
    arriba, derecha, izquierda, abajo = bordes(m)
    ptr = [m[0x6772 + 2 * i] | m[0x6773 + 2 * i] << 8 for i in range(0x5D)]
    used = [p for p in ptr if 0x6000 <= p < 0x8000]
    lo = min(used); hi = max(used)
    while (m[hi] & 0xF0) != 0xF0: hi += 1
    glyphs = m[lo:hi + 1]
    offs = [(p - lo) if p in used else 0xFFFF for p in ptr]
    bitmap, cells = blank(m, colour)
    # the cells the borders changed: the C64 program fills the rest with one colour and copies these
    # (byte by byte it took 3 s against the CPC's 0.2 s)
    lisos = [colour[0] if cy < 24 and 8 <= cx < 32 else colour[1] for cy in range(25) for cx in range(40)]
    celdas = [i for i in range(1000) if cells[i] != (lisos[i] << 4 | lisos[i]) or any(bitmap[i * 8:i * 8 + 8])]
    with open(sys.argv[2], "w") as f:
        f.write(cabecera("c"))
        f.write(f"/* generated by tools/c64_pergamino_datos.py from {os.path.relpath(sys.argv[1], P)} (CPC 64 KiB version) */\n")
        f.write(f"/* inks (CPC hardware colour per pen 0-3, border): {pen_hw[0]:02X} {pen_hw[1]:02X} {pen_hw[2]:02X} {pen_hw[3]:02X} {inks[4]:02X} */\n")
        f.write(arr("unsigned char", "perg_texto", text))
        f.write(arr("unsigned int", "perg_glifo_desp", offs, 10))
        f.write(arr("unsigned char", "perg_glifos", glyphs))
        f.write(arr("unsigned char", "perg_borde_arriba", m[arriba:arriba + 384]))
        f.write(arr("unsigned char", "perg_borde_derecha", m[derecha:derecha + 384]))
        f.write(arr("unsigned char", "perg_borde_izquierda", m[izquierda:izquierda + 384]))
        f.write(arr("unsigned char", "perg_borde_abajo", m[abajo:abajo + 384]))
        f.write(f"const unsigned char perg_blanco_n = {len(celdas)};\n")
        f.write(arr("unsigned int", "perg_blanco_celda", celdas, 10))
        f.write(arr("unsigned char", "perg_blanco_color", [cells[i] for i in celdas]))
        f.write(arr("unsigned char", "perg_blanco_bitmap", b"".join(bitmap[i * 8:i * 8 + 8] for i in celdas), 16))
        f.write(arr("unsigned char", "perg_esquina", m[0x68A9:0x68AD]))
        f.write(arr("unsigned char", "perg_color_pluma", [colour[p] for p in range(4)]))
        f.write(f"const unsigned char perg_color_borde = {border};\n")
        f.write(arr("unsigned char", "perg_musica", m[musica:musica + 0x400]))
        f.write(arr("unsigned char", "perg_reproductor", m[0x6148:0x619A]))
    print(f"blank parchment: {len(celdas)} border cells, text {len(text)} bytes, glyphs {len(glyphs)} bytes at {lo:04X}-{hi:04X}, inks {[hex(x) for x in inks]}, colours {colour}, border {border}")


if __name__ == "__main__":
    main()
