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

"""The English (British) game data: data/cpc64/juego/ram.bin with its Spanish texts replaced.

    genera_ram_en.py OUTDIR      writes OUTDIR/ram_en.bin and OUTDIR/informe_textos.txt; exit 1 if anything does not fit

What changes in the 64 KiB image (every address is the CPC 64K version's, as c64/juego/bloques64.tsv):
  words    B580h, 1257 bytes: the dictionary, 239 words, bit 7 on each word's last letter.  Here: the same first
           fourteen (the Latin of the mirror riddle, phrase 0, untouched, and word 6 'AAA' where the mirror's numeral is
           written, offset 1Eh) followed by the English words of frases_en.txt, padded with zeros.
  phrases  BB00h, 924 bytes: 56 token lists ending in FFh (token < F9h a word, preceded by a space; F9h w a word glued
           to the previous; FAh-FEh the glyphs of the punctuation table 3447h: FA '¿' (unused in English), FB '?',
           FC ';', FD '.', FE ','); phrase 0 as the tape has it, 1-55 tokenised from frases_en.txt.  The voice byte of
           each phrase (51AFh) is not touched: phrase n keeps its speaker.
  hours    4B12h, 7 x 7 font codes: the names of the canonical hours (NIGHT, PRIME, TERCE, SEXT, NONES, VESPERS, COMPLIN);
           the Spanish ones used the glyphs - . / > as digraphs, which the C64's 4-pixel font cannot show.
  font     B400h, 46 glyphs 2Dh-5Ah of 8 bytes: the glyph of 'W', which the Spanish font draws as N-tilde (the tape's
           words write the tilde as W), becomes a real W (its C64 form is the mirror image of M, 3 pixels wide).
  score bar  C600h-F7FFh: the gothic "Dia" becomes "Day" (dia_en.py).
Everything else is the tape's, byte for byte (the report lists the ranges that differ).
"""
import os, re, sys

D = os.path.dirname(os.path.realpath(__file__))
P = os.path.dirname(os.path.dirname(D))
sys.path.insert(0, D)             # (python3 -I does not put the script's directory on the path)

PALABRAS, N_PALABRAS, MAX_PALABRAS = 0xB580, 239, 1257
FRASES, N_FRASES, MAX_FRASES = 0xBB00, 56, 924
HORAS = 0x4AD0 + 66
FUENTE = 0xB400
PUNTUACION = {".": 0xFD, ",": 0xFE, "?": 0xFB, ";": 0xFC, "!": 0xFA}
LATIN = ["SECRET", "UM", "FINIS", "AFRICAE", "MANUS", "SUPRA", "AAA", "IDOLUM", "AGE", "PRIM", "ET", "SEPTIM", "DE", "QUATUOR"]
NOMBRES_HORAS = [" NIGHT ", " PRIME ", " TERCE ", " SEXT  ", " NONES ", "VESPERS", "COMPLIN"]

# the glyph of W: the mirror image of M at the C64's 3 x 7 pixels (the C64 font takes the right pixel of each pair of
# the CPC glyph's pixels: a 3-pixel pattern doubled gives the same 3 pixels back), written here as the CPC glyph
W_C64 = ["...", "#.#", "#.#", "#.#", "###", "###", "###", "#.#"]


def glifo_w():
    """the CPC glyph (8 rows of 8 pixels): each pixel of the C64 pattern doubled"""
    filas = []
    for r in W_C64:
        bits = "".join(("11" if c == "#" else "00") for c in r) + "00"
        filas.append(int(bits, 2))
    return bytes(filas)


def frases_ingles():
    out = {}
    for l in open(os.path.join(D, "frases_en.txt"), encoding="utf-8"):    # (my licence header: utf-8, '#' lines)
        if l[0].isdigit():
            assert l.isascii(), f"frases_en.txt: not ASCII: {l!r}"
            n, t = l.rstrip("\n").split("|", 1)
            out[int(n)] = t
    assert sorted(out) == list(range(1, N_FRASES)), "frases_en.txt: phrases 1-55 expected"
    return out


def trocea(texto):
    """a phrase -> its items: words and punctuation marks ('...' is three full stops)"""
    items = re.findall(r"[A-Z]+|\.\.\.|[.,?;!]", texto)
    assert "".join(items) == re.sub(r"[ ]+", "", texto), f"characters the font cannot show in: {texto}"
    out = []
    for it in items:
        out += ["."] * 3 if it == "..." else [it]
    return out


def construye(ram):
    m = bytearray(ram)
    fr = frases_ingles()
    # the tape's Latin phrase 0, as it is
    a, original0 = FRASES, []
    while ram[a] != 0xFF:
        original0.append(ram[a]); a += 1
    palabras = list(LATIN)
    # check the Latin words are the tape's first fourteen, in place
    a = PALABRAS
    for w in LATIN:
        leido = ""
        while True:
            b = ram[a]; a += 1
            leido += chr(b & 0x7F)
            if b & 0x80: break
        assert leido == w, f"the tape's word is {leido}, not {w}"
    assert PALABRAS + 0x1E == 0xB59E and ram[0xB59E:0xB5A1] == b"AA\xc1", "the mirror's numeral is not word 6 at B59Eh"
    usadas = {}
    for n in range(1, N_FRASES):
        for it in trocea(fr[n]):
            if it[0].isalpha() and it not in palabras:
                palabras.append(it)
    tok = {w: i for i, w in enumerate(palabras)}
    assert len(palabras) <= 0xF9, f"{len(palabras)} words, at most 249 (tokens below F9h)"
    bytes_pal = b"".join(bytes([ord(c) for c in w[:-1]] + [ord(w[-1]) | 0x80]) for w in palabras)
    assert len(bytes_pal) <= MAX_PALABRAS, f"words: {len(bytes_pal)} bytes, room for {MAX_PALABRAS}"
    lista = [bytes(original0 + [0xFF])]
    for n in range(1, N_FRASES):
        t = []
        for it in trocea(fr[n]):
            t.append(tok[it] if it[0].isalpha() else PUNTUACION[it])
        lista.append(bytes(t + [0xFF]))
    bytes_fr = b"".join(lista)
    assert len(bytes_fr) <= MAX_FRASES, f"phrases: {len(bytes_fr)} bytes, room for {MAX_FRASES}"
    m[PALABRAS:PALABRAS + MAX_PALABRAS] = bytes_pal + bytes(MAX_PALABRAS - len(bytes_pal))
    m[FRASES:FRASES + MAX_FRASES] = bytes_fr + bytes(MAX_FRASES - len(bytes_fr))
    for i, nombre in enumerate(NOMBRES_HORAS):
        assert len(nombre) == 7
        m[HORAS + 7 * i:HORAS + 7 * i + 7] = nombre.encode("ascii")
    m[FUENTE + (0x57 - 0x2D) * 8:FUENTE + (0x57 - 0x2D) * 8 + 8] = glifo_w()
    informe = [f"words: {len(palabras)} of 239 (tape), {len(bytes_pal)} of {MAX_PALABRAS} bytes",
               f"phrases: 56, {len(bytes_fr)} of {MAX_FRASES} bytes",
               f"longest phrase: {max(len(x) for x in lista) - 1} tokens"]
    return bytes(m), informe, palabras, lista


def decodifica(m, palabras_dir, frases_dir):
    """the text of every phrase as the game prints it (for the report and the tests)"""
    pal, a = [], palabras_dir
    for _ in range(0xF9):
        s = ""
        while True:
            b = m[a]; a += 1
            s += chr(b & 0x7F)
            if b & 0x80: break
        pal.append(s)
        if m[a] == 0 and len(pal) >= 14 and all(x == 0 for x in m[a:a + 8]): break
    return pal


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    ram = open(os.path.join(P, "..", "data", "cpc64", "juego", "ram.bin"), "rb").read()
    m, informe, palabras, lista = construye(ram)
    try:
        from dia_en import pon_day
        m, nota = pon_day(m)
        informe.append(nota)
    except ImportError:
        informe.append("score bar: not changed yet (dia_en.py missing)")
    open(os.path.join(out, "ram_en.bin"), "wb").write(m)
    cambios, i = [], 0
    while i < len(ram):
        if ram[i] != m[i]:
            j = i
            while j < len(ram) and ram[j] != m[j]: j += 1
            cambios.append((i, j)); i = j
        else:
            i += 1
    informe.append("differing ranges (hex, first, last): " + " ".join(f"{a:04X}-{b - 1:04X}" for a, b in cambios))
    # the phrases as the game will print them
    for n, t in enumerate(lista):
        texto = ""
        k = 0
        while t[k] != 0xFF:
            b = t[k]
            if b == 0xF9:
                texto += palabras[t[k + 1]]; k += 2; continue
            if b >= 0xFA:
                texto += {0xFA: "!", 0xFB: "?", 0xFC: ";", 0xFD: ".", 0xFE: ","}[b]
            else:
                texto += " " + palabras[b]
            k += 1
        informe.append(f"{n:2d} {texto}")
    open(os.path.join(out, "informe_textos.txt"), "w").write("\n".join(informe) + "\n")
    print("\n".join(informe[:5]))


if __name__ == "__main__":
    main()
