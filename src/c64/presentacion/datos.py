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

"""The data files of the presentation and ending (c64/presentacion/NOTAS.md), made from the files and the tape.

    datos.py DIR           writes DIR/text1.bin, text2.bin, pp.bin, musica_inicio.c, musica_final.c; checks them
    datos.py --texto       prints the ending's text as plain text (for reading)
    datos.py --glifos PNG  a picture of the new glyphs among the font's (x4), and of the credits' lines

Inputs: the original files (c64/presentacion/original/graphics/pergamino: pp.bin, text1.bin, copied from
the directory) and the original tape's two parchment stages (data/cpc64/cinta/primera_etapa.bin, the introduction;
final.bin, the ending, ABADIA64.BN1; each the CPC memory when the stage's code at 6000h is entered).  The addresses
are read from the stage's own code as tools/c64_pergamino_datos.py reads them: the text at [6028h]
(ended by 1Ah), the music at [601Ah] (1 KiB), the player's state 6148h-6199h, the glyph pointers at 6772h.

  text1.bin    the introduction text, which is the tape's (8400h) byte for byte (checked), with the credits of this
               version (CREDITOS) put before its end mark 1Ah.  The codes are the CPC's: 0Dh a new line, 0Ah a new
               page, 20h a space, 1Ah the end, 2Ch-7Ah a glyph (40h-5Fh drawn as capitals: red, 2 pixels left).
  text2.bin    the ending's original text (7400h), followed by the credits and dedication on separate pages.
  pp.bin       the pp.bin (the border's cells, their graphics, the glyph pointers, the glyphs) with the glyphs the
               credits need and the CPC's font lacks (GLIFOS: 0, 6, @, B) appended after the glyphs; their
               pointers, in the table, continue the CPC's addresses (727Eh on) as the manusmkletptr expects.  The @
               is not given its ASCII code 40h, a capital's code (red, two pixels left in the manusrun and on the
               CPC), but 60h (the font has nothing there): text1.bin writes 60h for the e-mail's @.
  musica_inicio.c, musica_final.c   the music of each stage for musica.s: perg_musica (the 1 KiB at [601Ah]) and
               perg_reproductor (6148h-6199h).

Checks (exit 1 on a failure): the text1.bin is the tape's introduction text; the glyphs and pointers are the tape's
(6772h, 68ADh-727Dh), and the ending's font is the introduction's (the pp.bin serves both); every character of both
texts has a glyph; no line of the credits reaches further right than the tape's own lines.

As a module: glifos(pp) and paginas(texto, glifos, desplaza) model the pages the manusrun writes (the tests).
"""
import os, sys

D = os.path.dirname(os.path.realpath(__file__))
P = os.path.dirname(os.path.dirname(D))
sys.path.insert(0, os.path.join(P, "..", "tools"))
from c64_pergamino_datos import w                                   # noqa: E402
from licencia import cabecera                                       # noqa: E402

ORIGINAL = os.path.join(D, "original", "graphics", "pergamino")
CINTA = os.path.join(P, "..", "data", "cpc64", "cinta")

# pp.bin's parts (the README.txt): pergascr 0x00-0xb9, pergagraf 0xba-0x117, perga 0x118-0x2b5, the glyph pointers
# 0x2b6-0x355 (characters 2Ch-7Ah, then FFFFh), the glyphs from 0x356 (the CPC's 68ADh-727Dh)
PP_PUNTEROS, PP_GLIFOS, N_GLIFOS_CPC = 0x2B6, 0x356, 0x9D1
CPC_GLIFOS = 0x68AD

# the credits of this version, after the tape's own ("autor: / Paco Menendez / graficos y caratula: / Juan Delcan /
# copyright: / Opera Soft", which fill their page), on a page of their own (0Ah) in their style: a lower-case label
# with a colon, the lines below it indented; three spaces, not the tape's four, so that the e-mail ends before the
# right border (x 248: with four it would end at x 251)
# (the @ as 60h: CODIGO below)
CREDITOS_TEXTO = "\x0aversion commodore:\r   German Luis\r   Aracil Boned\r   garacilb@gmail.com\r   2016 - 2026\r"
DEDICATORIA_TEXTO = ("\x0adedicado a todo\rel equipo de\rOpera Soft.\r\r"
                     "Con admiracion\ry agradecimiento.\r\rGerman Luis\rAracil Boned")
MARGEN = 247                # the last pixel column before the parchment's right border (cells of column 31)

# the glyphs the credits need that the CPC's font has not (its pointers for them are 0): drawn in the font's style
# (the digits' height and flourish of 2, 3 and 7; B from P's bowl and D's foot; @ an a in a ring), '#' = ink.
# (x, y) from the cursor as the CPC's glyph bytes (YX); the advance as the font's: digits 8, capitals 14.
# the code each new glyph takes: its ASCII code but for @, which takes 60h (40h-5Fh are capitals)
CODIGO = {"0": 0x30, "6": 0x36, "@": 0x60, "B": 0x42}


def codifica(texto):
    """text -> the parchment's codes: ASCII but the @ (CODIGO)"""
    return texto.encode("ascii").replace(b"@", bytes([CODIGO["@"]]))


CREDITOS = codifica(CREDITOS_TEXTO)
DEDICATORIA = codifica(DEDICATORIA_TEXTO)


GLIFOS = {
    "0": (8, ["........",
              "........",
              "........",
              "..###...",
              ".##.##..",
              "##..###.",
              "##...##.",
              "##...##.",
              "##...##.",
              "##...##.",
              "###..##.",
              ".##.##..",
              "..###..."]),
    "6": (8, ["........",
              "........",
              "........",
              "...###.#",
              "..##.##.",
              ".##.....",
              "##......",
              "##.###..",
              "###..##.",
              "##...##.",
              "##...##.",
              ".##.##..",
              "..###..."]),
    "@": (11, ["...........",
               "...........",
               "...........",
               "...#####...",
               ".##.....##.",
               "#...##.#..#",
               "#..#.###..#",
               "#.##..##..#",
               "#.##..##..#",
               "#.##..##.#.",
               "#..##.###..",
               ".##........",
               "...######.."]),
    "B": (14, ["...##..###....",
               "#.###.######..",
               ".#######.###..",
               "..###..#.###..",
               "..###..#.###..",
               "..###..####...",
               "..###..#####..",
               "..###..#..###.",
               "..###..#..###.",
               "..###..#..###.",
               "..###..#..###.",
               ".####..#.###..",
               "#.##########..",
               "..#..#####...."]),
}


def glifo_bytes(ancho, filas):
    """the CPC's glyph format: a byte YX for each pixel (here column by column, top to bottom: the order the pen
    draws them in), then F0h + the advance"""
    pix = [(x, y) for x in range(len(filas[0])) for y in range(len(filas)) if filas[y][x] == "#"]
    assert all(x < 16 and y < 16 for x, y in pix) and ancho < 16
    return bytes(y << 4 | x for x, y in pix) + bytes([0xF0 | ancho])


def texto_cinta(m):
    a = w(m, 0x6028)
    return m[a:m.index(0x1A, a) + 1]


def etapa(nombre):
    m = open(os.path.join(CINTA, nombre), "rb").read()
    assert m[0x6026:0x6028] == b"\xDD\x21" and m[0x6019] == 0x21, f"{nombre}: not the parchment code"
    return m


def texto_final():
    """Keep the complete original ending, then add the port's credits and personal dedication."""
    return texto_cinta(etapa("final.bin"))[:-1] + CREDITOS + DEDICATORIA + b"\x1a"


def glifos(pp):
    """pp.bin's glyphs as the manusmkletptr / manusrun read them: {code: (pixels [(x, y)], advance)}"""
    ptr = [w(pp, PP_PUNTEROS + 2 * i) for i in range(80)]
    assert ptr[79] == 0xFFFF
    base = ptr[0]
    out = {}
    for i, p in enumerate(ptr[:79]):
        if p == 0:
            continue
        k = PP_GLIFOS + p - base
        pix = []
        while pp[k] & 0xF0 != 0xF0:
            pix.append((pp[k] & 15, pp[k] >> 4))
            k += 1
        out[0x2C + i] = (pix, pp[k] & 15)
    return out


def paginas(texto, gl, desplaza=2):
    """the pages the manusrun writes (manuscrito.c): the cursor from (76, 16), a line 16 pixels down, a new page
    past y 164 (the CPC: from A4h) or at 0Ah, a space 10 pixels; a glyph pixel at the cursor + (x, y), capitals
    (codes 40h-5Fh) `desplaza` pixels to the left (the code: 2; the CPC: 0).  -> a list of pages, each a dict:
    'tinta' {(x, y): colour of the cell's screen RAM it sets (0xA0 ink, 0xA2 a capital)}, 'celdas' {cell: the last
    colour written there}, 'texto' (its characters), 'derecha' (its rightmost ink pixel)"""
    out = []
    pag = dict(tinta={}, celdas={}, texto="", derecha=0)
    x, y = 76, 16
    for c in texto:
        if c == 0x1A:
            break
        if c == 0x0D:
            x, y = 76, y + 16
            pag["texto"] += "\n"
            if y > 164:
                out.append(pag)
                pag = dict(tinta={}, celdas={}, texto="", derecha=0)
                x, y = 76, 16
            continue
        if c == 0x20:
            x += 10
            pag["texto"] += " "
            continue
        if c == 0x0A:
            out.append(pag)
            pag = dict(tinta={}, celdas={}, texto="", derecha=0)
            x, y = 76, 16
            continue
        color = 0xA2 if c & 0x60 == 0x40 else 0xA0
        cap = desplaza if color == 0xA2 else 0
        pix, avance = gl[c]
        for dx, dy in pix:
            px, py = x - cap + dx, y + dy
            pag["tinta"][(px, py)] = color
            pag["celdas"][(py >> 3) * 40 + (px >> 3)] = color
            pag["derecha"] = max(pag["derecha"], px)
        x += avance
        pag["texto"] += "@" if c == CODIGO["@"] else chr(c)
    out.append(pag)
    return out


def lineas(texto, gl):
    """each line's characters and its rightmost ink pixel (the rule)"""
    out, x, linea, der = [], 76, "", 0
    for c in texto:
        if c in (0x0D, 0x0A, 0x1A):
            out.append((linea, der))
            x, linea, der = 76, "", 0
            continue
        if c == 0x20:
            x += 10
            linea += " "
            continue
        cap = 2 if c & 0x60 == 0x40 else 0
        pix, avance = gl[c]
        der = max([der] + [x - cap + dx for dx, _ in pix])
        x += avance
        linea += chr(c)
    return out


def c_musica(m, nombre_etapa):
    def arr(nombre, datos):
        filas = ",\n".join("  " + ",".join(f"0x{b:02X}" for b in datos[i:i + 16]) for i in range(0, len(datos), 16))
        return f"const unsigned char {nombre}[{len(datos)}] = {{\n{filas}\n}};\n"
    musica = w(m, 0x601A)
    return (cabecera("c") + "\n" + f"/* generated by c64/presentacion/datos.py from data/cpc64/cinta/{nombre_etapa}: the music "
            f"([601Ah] = {musica:04X}h, 1 KiB, its tempo in the last byte) and the player's state (6148h-6199h) */\n"
            + arr("perg_musica", m[musica:musica + 0x400]) + arr("perg_reproductor", m[0x6148:0x619A]))


def legible(texto):
    return texto.replace(b"\x1a", b"").replace(b"\r", b"\n").replace(b"\n\x0a", b"\n\n").decode("ascii")


def muestra(fichero):
    """the new glyphs among the font's (the colours: ink black, capitals red, on the parchment's light red)"""
    sys.path.insert(0, os.path.join(P, "c64", "plataforma", "pruebas"))
    import vice_mb
    pp = bytearray(open(os.path.join(ORIGINAL, "pp.bin"), "rb").read())
    for ch, (ancho, filas) in GLIFOS.items():
        i = CODIGO[ch] - 0x2C
        a = CPC_GLIFOS + len(pp) - PP_GLIFOS
        pp[PP_PUNTEROS + 2 * i:PP_PUNTEROS + 2 * i + 2] = bytes([a & 255, a >> 8])
        pp += glifo_bytes(ancho, filas)
    gl = glifos(bytes(pp))
    lineas_ = [codifica(l) for l in ["0 6 @ B   1 2 3 7  a o g  D P", ""] + CREDITOS_TEXTO.strip("\x0a\r").split("\r")]
    ancho, alto, esc = 320, 16 * len(lineas_) + 4, 3
    pix = [[0] * ancho for _ in range(alto)]
    for n, linea in enumerate(lineas_):
        x = 4
        for c in linea:
            if c == 0x20:
                x += 10
                continue
            pts, av = gl[c]
            cap = 2 if c & 0x60 == 0x40 else 0
            for dx, dy in pts:
                pix[2 + 16 * n + dy][x - cap + dx] = 2 if cap else 1
            x += av
    color = {0: bytes((0xD7, 0x88, 0x7C)), 1: bytes((0, 0, 0)), 2: bytes((0x81, 0x33, 0x38))}   # C64 10, 0, 2
    rgb = b"".join(b"".join(color[pix[y][x]] * esc for x in range(ancho)) * esc for y in range(alto))
    vice_mb.png(fichero, ancho * esc, alto * esc, rgb)


def main():
    if sys.argv[1:] == ["--texto"]:
        print(legible(texto_final()))
        return
    if sys.argv[1:2] == ["--glifos"]:
        muestra(sys.argv[2])
        return
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    fallos = []
    def comprueba(cond, texto):
        print(("ok    " if cond else "FALLO ") + texto)
        if not cond:
            fallos.append(texto)
    intro, fin_ = etapa("primera_etapa.bin"), etapa("final.bin")
    t1 = open(os.path.join(ORIGINAL, "text1.bin"), "rb").read()
    pp = open(os.path.join(ORIGINAL, "pp.bin"), "rb").read()
    comprueba(t1 == texto_cinta(intro), f"the text1.bin ({len(t1)} bytes) is the tape's introduction text at "
              f"{w(intro, 0x6028):04X}h, byte for byte")
    comprueba(len(pp) == PP_GLIFOS + N_GLIFOS_CPC and pp[PP_GLIFOS:] == intro[CPC_GLIFOS:CPC_GLIFOS + N_GLIFOS_CPC]
              and pp[PP_PUNTEROS:PP_PUNTEROS + 0x9E] == intro[0x678A:0x678A + 0x9E] and w(pp, PP_PUNTEROS + 0x9E) == 0xFFFF,
              "the pp.bin: the glyphs and their pointers are the tape's (68ADh-727Dh, 678Ah-6827h), then FFFFh")
    comprueba(fin_[0x6772:0x727E] == intro[0x6772:0x727E], "the ending's font is the introduction's (pp.bin serves both)")
    original_final = texto_cinta(fin_)
    t2 = texto_final()
    comprueba(t2.startswith(original_final[:-1]), "the complete original ending precedes the new credits and dedication")
    # the new glyphs, appended
    nuevo = bytearray(pp)
    for ch, (ancho, filas) in GLIFOS.items():
        i = CODIGO[ch] - 0x2C
        assert w(nuevo, PP_PUNTEROS + 2 * i) == 0, f"{ch} has a glyph already"
        a = CPC_GLIFOS + len(nuevo) - PP_GLIFOS
        nuevo[PP_PUNTEROS + 2 * i:PP_PUNTEROS + 2 * i + 2] = bytes([a & 255, a >> 8])
        nuevo += glifo_bytes(ancho, filas)
    nuevo = bytes(nuevo)
    t1n = t1[:-1] + CREDITOS + b"\x1a"
    gl = glifos(nuevo)
    for nombre, t in (("text1.bin", t1n), ("text2.bin", t2)):
        sin = sorted({c for c in t if c not in (0x0D, 0x0A, 0x20, 0x1A) and c not in gl})
        comprueba(not sin, f"{nombre}: every character has a glyph" + (f" (none for {[chr(c) for c in sin]})" if sin else ""))
    cred = lineas(CREDITOS + DEDICATORIA, gl)
    comprueba(all(d <= MARGEN for _, d in cred), f"the credits' lines end at x <= {max(d for _, d in cred)} (the right "
              f"border starts at x {MARGEN + 1}; the tape's own lines end at x <= "
              f"{max(d for t in (t1, t2) for _, d in lineas(t, gl))})")
    pags = paginas(t1n, gl)
    original_pages = paginas(original_final, gl)
    final_pages = paginas(t2, gl)
    comprueba(final_pages[:len(original_pages)] == original_pages,
              "all original ending pages are unchanged, followed by credits and dedication")
    comprueba(len(final_pages) == len(original_pages) + 2, "one final credits page and one dedication page")
    open(os.path.join(out, "text1.bin"), "wb").write(t1n)
    open(os.path.join(out, "text2.bin"), "wb").write(t2)
    open(os.path.join(out, "pp.bin"), "wb").write(nuevo)
    open(os.path.join(out, "musica_inicio.c"), "w").write(c_musica(intro, "primera_etapa.bin"))
    open(os.path.join(out, "musica_final.c"), "w").write(c_musica(fin_, "final.bin"))
    print(f"      text1.bin {len(t1n)} bytes (0x{len(t1n):x}; the original {len(t1)} + the credits {len(CREDITOS)}), "
          f"{len(pags)} pages; its last page:\n" + "\n".join("        | " + l for l in pags[-1]["texto"].split("\n")))
    print(f"      text2.bin {len(t2)} bytes (0x{len(t2):x}), {len(paginas(t2, gl))} pages")
    print(f"      pp.bin {len(nuevo)} bytes; glyphs 0x{len(nuevo) - PP_GLIFOS:x} bytes (the original 0x{N_GLIFOS_CPC:x} + "
          f"{len(nuevo) - len(pp)} for {''.join(GLIFOS)})")
    sys.exit(1 if fallos else 0)


if __name__ == "__main__":
    main()
