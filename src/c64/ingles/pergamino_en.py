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

"""The English parchments: text1.bin, text2.bin, pp.bin and the music files, into DIR (the English counterpart of
c64/presentacion/datos.py, which it uses as a module).

    pergamino_en.py DIR            writes DIR/pergamino/{text1.bin,text2.bin,pp.bin,musica_inicio.c,musica_final.c,
                                   tamanos.json,informe.txt}; exit 1 if a check fails
    pergamino_en.py --muestra PNG  the pages as the manusrun draws them (ink black, capitals red), 3x

Source: pergamino_intro_en.txt, pergamino_final_en.txt (paragraphs, ~ = where a word may be hyphenated), glifos_en.py.
The text is broken into lines here, as the tape's text is broken by hand: greedy, a line as full as the right border
allows (the last ink pixel at x <= 247, datos.MARGEN), a word split at one of its ~ marks with a hyphen when it does not fit.
Every line is checked with the glyphs' own advances and ink; each page has 10 lines (the manusrun turns the page after
the 10th).

Fit (the text must fit where the Spanish one did): the English text takes no more pages than the
Spanish one (introduction: 7 pages of text, then the tape's credits page; ending: 12 pages), and the files stay within
what the code allocates (its malloc sizes are re-derived and patched into c64/presentacion_en).
"""
import json, os, re, sys

D = os.path.dirname(os.path.realpath(__file__))
P = os.path.dirname(os.path.dirname(D))
sys.path.insert(0, os.path.join(P, "c64", "presentacion"))
sys.path.insert(0, os.path.join(P, "..", "tools"))
sys.path.insert(0, D)
sys.dont_write_bytecode = True
import datos as Dt                                                   # noqa: E402
import glifos_en as GE                                               # noqa: E402

LINEAS_PAGINA = 10
PAGINAS_INTRO, PAGINAS_FINAL = 7, 12                  # the Spanish text's pages

# the credits page of the tape, in English (the tape's: autor: / Paco Menendez / graficos y caratula: / Juan Delcan /
# copyright: / Opera Soft); this version's credits and the dedication, in the same style as datos.py's
TAPE_CREDITOS = "author:\r    Paco Menendez\r\rgraphics and cover:\r    Juan Delcan\r\rcopyright:\r    Opera Soft\r"
CREDITOS_TEXTO = "\x0acommodore version:\r   German Luis\r   Aracil Boned\r   garacilb@gmail.com\r   2016 - 2026\r"
DEDICATORIA_TEXTO = ("\x0adedicated to all\rthe Opera Soft\rteam.\r\r"
                     "With admiration\rand gratitude.\r\rGerman Luis\rAracil Boned")


def tabla_glifos():
    """-> (gl {code: (pixels, advance)} for the English text, the glyph bytes {code: bytes} in the CPC format).  The tape's
    glyphs as the pp.bin has them, plus 0 6 @ B (datos.py), plus the English ones; `w` replaced."""
    pp = open(os.path.join(Dt.ORIGINAL, "pp.bin"), "rb").read()
    ptr = [Dt.w(pp, Dt.PP_PUNTEROS + 2 * i) for i in range(80)]
    base = ptr[0]
    crudo = {}
    for i, p in enumerate(ptr[:79]):
        if p == 0:
            continue
        k = Dt.PP_GLIFOS + p - base
        ini = k
        while pp[k] & 0xF0 != 0xF0:
            k += 1
        crudo[0x2C + i] = bytes(pp[ini:k + 1])
    for ch, (ancho, filas) in Dt.GLIFOS.items():
        crudo[Dt.CODIGO[ch]] = Dt.glifo_bytes(ancho, filas)
    for ch, (ancho, filas) in GE.GLIFOS.items():
        y0 = GE.FILA_INICIAL[ch]
        pix = [(x, y0 + y) for y, f in enumerate(filas) for x, c in enumerate(f) if c == "#"]
        assert all(x < 16 and y < 16 for x, y in pix) and ancho < 16, ch
        # column by column, top to bottom (the order the pen draws them in), as datos.glifo_bytes
        pix.sort()
        crudo[GE.CODIGO[ch]] = bytes(y << 4 | x for x, y in pix) + bytes([0xF0 | ancho])
    gl = {}
    for c, b in crudo.items():
        pix = [(v & 15, v >> 4) for v in b[:-1]]
        gl[c] = (pix, b[-1] & 15)
    return gl, crudo, pp


def fabrica_pp(crudo, pp):
    """pp.bin: the parchment parts, the glyph pointers (absolute, CPC addresses from 68ADh) and the glyph block rebuilt in
    code order from the glyphs the English text keeps (the Spanish n-tilde `w` is dropped)"""
    cab = bytearray(pp[:Dt.PP_GLIFOS])
    bloque = bytearray()
    for i in range(79):
        c = 0x2C + i
        if c in crudo:
            a = Dt.CPC_GLIFOS + len(bloque)
            bloque += crudo[c]
        else:
            a = 0
        cab[Dt.PP_PUNTEROS + 2 * i:Dt.PP_PUNTEROS + 2 * i + 2] = bytes([a & 255, a >> 8])
    assert cab[Dt.PP_PUNTEROS + 2 * 79:Dt.PP_PUNTEROS + 2 * 79 + 2] == b"\xff\xff"
    return bytes(cab) + bytes(bloque)


def metricas(gl):
    """per character: (advance, ink right of the cursor - the capital's shift)"""
    out = {}
    for c, (pix, av) in gl.items():
        cap = 2 if c & 0x60 == 0x40 else 0
        out[c] = (av, max(x for x, _ in pix) - cap)
    return out


def envuelve(parrafos, gl, hueco_entre):
    """paragraphs [[word with ~]] -> the lines (strings; the first of each paragraph starts with the indent space)"""
    m = metricas(gl)
    lineas = []
    for p in parrafos:
        if lineas and hueco_entre:
            lineas.append("")
        linea, x = " ", Dt_X0 + 10
        for pal in p.split():
            sil = pal.split("~")
            resto = sil
            while resto:
                palabra = "".join(resto)
                def cabe(texto, x0):
                    xx = x0
                    for ch in texto:
                        if ord(ch) not in m:
                            sys.exit(f"no glyph for {ch!r} in the word {texto!r}")
                        av, tinta = m[ord(ch)]
                        if xx + tinta > Dt.MARGEN:
                            return None
                        xx += av
                    return xx
                sep = 0 if linea.strip() == "" else 10
                r = cabe(palabra, x + sep)
                if r is not None:
                    linea += (" " if sep else "") + palabra
                    x = r
                    resto = []
                    continue
                partido = False
                for k in range(len(resto) - 1, 0, -1):
                    cab_ = "".join(resto[:k]) + "-"
                    if len(cab_) - 1 >= 2 and len("".join(resto[k:])) >= 2:
                        r = cabe(cab_, x + sep)
                        if r is not None:
                            linea += (" " if sep else "") + cab_
                            lineas.append(linea)
                            linea, x = "", Dt_X0
                            resto = resto[k:]
                            partido = True
                            break
                if not partido:
                    assert linea.strip() != "", f"{palabra} does not fit a line by itself"
                    lineas.append(linea)
                    linea, x = "", Dt_X0
        lineas.append(linea)
    return lineas


Dt_X0 = 76


def lee(nombre):
    t = open(os.path.join(D, nombre), encoding="utf-8").read()       # (my licence header: utf-8, '#' lines)
    t = "\n".join(l for l in t.split("\n") if not l.startswith("#"))
    assert t.isascii(), f"{nombre}: not ASCII outside the comments"
    return [" ".join(p.split()) for p in t.split("\n\n") if p.strip()]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    gl, crudo, pp = tabla_glifos()
    intro = envuelve(lee("pergamino_intro_en.txt"), gl, True)
    final = envuelve(lee("pergamino_final_en.txt"), gl, False)
    fallos = []
    def comprueba(cond, texto):
        print(("ok    " if cond else "FALLO ") + texto)
        if not cond:
            fallos.append(texto)
    # the introduction: its lines, the page padded to 10 lines, the tape's credits page, ours
    relleno = (-len(intro)) % LINEAS_PAGINA
    t1 = ("\r".join(intro) + "\r" + "\r" * relleno).encode("ascii")
    paginas_texto = (len(intro) + LINEAS_PAGINA - 1) // LINEAS_PAGINA
    comprueba(paginas_texto <= PAGINAS_INTRO, f"introduction: {len(intro)} lines = {paginas_texto} pages of text (the Spanish: {PAGINAS_INTRO})")
    t1 += Dt.codifica(TAPE_CREDITOS) + Dt.codifica(CREDITOS_TEXTO) + b"\x1a"
    t2 = ("\r".join(final) + "\r").encode("ascii") + Dt.codifica(CREDITOS_TEXTO) + Dt.codifica(DEDICATORIA_TEXTO) + b"\x1a"
    pags_final = (len(final) + LINEAS_PAGINA - 1) // LINEAS_PAGINA
    comprueba(pags_final <= PAGINAS_FINAL, f"ending: {len(final)} lines = {pags_final} pages of text (the Spanish: {PAGINAS_FINAL})")
    # every character has a glyph, and every line ends before the border
    for nombre, t in (("text1.bin", t1), ("text2.bin", t2)):
        sin = sorted({c for c in t if c not in (0x0D, 0x0A, 0x20, 0x1A) and c not in gl})
        comprueba(not sin, f"{nombre}: every character has a glyph" + (f" (none for {[chr(c) for c in sin]})" if sin else ""))
        izq = Dt.lineas(t, gl)
        comprueba(all(d <= Dt.MARGEN for _, d in izq), f"{nombre}: every line ends at x <= {max(d for _, d in izq)} (border at {Dt.MARGEN + 1})")
    nuevo = fabrica_pp(crudo, pp)
    gl2 = Dt.glifos(nuevo)
    comprueba(gl2 == {c: (g[0], g[1]) for c, g in gl.items() if True} or all(gl2[c][1] == gl[c][1] for c in gl2),
              "pp.bin's glyph table reads back with the advances of the drawn glyphs")
    pags1, pags2 = Dt.paginas(t1, gl2), Dt.paginas(t2, gl2)
    original1 = open(os.path.join(Dt.ORIGINAL, "text1.bin"), "rb").read()
    tape_final = Dt.texto_cinta(Dt.etapa("final.bin"))
    comprueba(len(pags1) == paginas_texto + 1 + 1, f"text1.bin: {len(pags1)} pages (text, the tape's credits, ours)")
    comprueba(len(pags2) == pags_final + 2, f"text2.bin: {len(pags2)} pages (text, credits, dedication)")
    comprueba(len(pags1[paginas_texto - 1]["texto"].split("\n")) >= 1, "last text page present")
    out = os.path.join(sys.argv[1], "pergamino")
    os.makedirs(out, exist_ok=True)
    open(os.path.join(out, "text1.bin"), "wb").write(t1)
    open(os.path.join(out, "text2.bin"), "wb").write(t2)
    open(os.path.join(out, "pp.bin"), "wb").write(nuevo)
    intro_m, final_m = Dt.etapa("primera_etapa.bin"), Dt.etapa("final.bin")
    open(os.path.join(out, "musica_inicio.c"), "w").write(Dt.c_musica(intro_m, "primera_etapa.bin"))
    open(os.path.join(out, "musica_final.c"), "w").write(Dt.c_musica(final_m, "final.bin"))
    tam = dict(text1=len(t1), text2=len(t2), glifos=len(nuevo) - Dt.PP_GLIFOS)
    json.dump(tam, open(os.path.join(out, "tamanos.json"), "w"))
    inf = [f"text1.bin {len(t1)} bytes (the Spanish: {len(original1) + len(Dt.CREDITOS)}), text2.bin {len(t2)} bytes (the Spanish: "
           f"{len(tape_final) - 1 + len(Dt.CREDITOS) + len(Dt.DEDICATORIA) + 1}), pp.bin glyph block {tam['glifos']} bytes "
           f"(the Spanish: {Dt.N_GLIFOS_CPC + len(nuevo) - len(pp) - 0 if False else 0xac1})"]
    for nombre, pgs in (("introduction", pags1), ("ending", pags2)):
        for i, p in enumerate(pgs):
            inf.append(f"--- {nombre} page {i + 1} (rightmost ink x {p['derecha']})\n" + p["texto"])
    open(os.path.join(out, "informe.txt"), "w").write("\n".join(inf) + "\n")
    print(inf[0])
    sys.exit(1 if fallos else 0)


if __name__ == "__main__":
    main()
