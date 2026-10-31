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

"""The game's files of the C128's disk (abadia128ks, c64/disco128/NOTAS.md), from the C128 build (c64/juego_final
C128=1: c128/ and, English, c128_en/):
  B  the game's zero page and stack page ($0000-$01FF of block 0, raw) then the game's block 1 (juego.bin.banco1,
     from $1000), loaded into block 1 at B1_PAGINAS = $0E00 (the two parts are contiguous);
  J  (J1 and J2) the game's block 0 crunched by Exomizer (`mem`, backwards) in pieces: $0200-$7FFF (J1),
     $8000-$BFFF, $C400-$FEFF, $FF05-$FFFF (J2; split so since abadia128ks's texts went to block 1) (left out: $0000-$01FF, in B; $C000-$C3FF, where the last stage runs, the game's screen
     RAM, all zero in the image; the MMU's registers $FF00-$FF04, zero too), loaded into block 1 so that it ends at
     $BFFF: the last stage maps 16 KiB of common RAM at the top ($C000-$FFFF always block 0), so block 1 is readable
     only below $C000 (and the KERNAL's LOAD fails with error 16 once its pointer reaches $FF00: "Mapping the
     Commodore 128", LOAD $F265);
  E  the bytes of the English image that differ, as records (address lo, address hi, length 1-255, the bytes),
     ended by an address 0: block 0's, then block 1's (the texts, which live there: mapa64.py BANCO1), loaded into
     block 1 right after B;
and juego128_gen.inc for the last stage (etapa128.s): the pieces' ends in block 1, B1_PAGINAS, B1_INGLES and the
game's addresses the stage writes (principal_inicio, plat_opciones, plat_unidad, the two sound calls).  Both images
must have the same layout (the same labels but for the strings in game_check_end) and block 1 the same but for the
texts.

    piezas128.py C128_DIR C128_EN_DIR OUT_DIR       Deterministic."""
import os, subprocess, sys, tempfile
D = os.path.dirname(os.path.realpath(__file__))
P = os.path.dirname(os.path.dirname(D))
EXO = os.path.join(P, "..", "tools", "terceros", "exomizer", "exomizer2", "src", "exomizer")
B1_PAGINAS = 0x0E00
PIEZAS = [(0x0200, 0x8000), (0x8000, 0xC000), (0xC400, 0xFF00), (0xFF05, 0x10000)]   # J1 = the first, J2 the rest
FIJAS = ["principal_inicio", "plat_opciones", "plat_unidad", "cinta_paso", "cinta_pitido", "kernal_foto",
         "c128_ave_llamada", "c128_carga_ave", "c128_carga"]
FOTO = 0x600                                            # the KERNAL's photograph in block 1 (plataforma/c128.s)
DENTRO_GCE = {"cert_pausa2"}                            # the labels inside game_check_end (its strings)


def etiquetas(f):
    e = {}
    for l in open(f):
        t = l.split()
        if len(t) >= 3 and t[0] == "al": e[t[2].lstrip(".")] = int(t[1], 16)
    return e


def crunch(datos, inicio, tmp, n):
    """a piece crunched as the tape's programs are (a PRG: its load address first), the outfile without one"""
    prg = os.path.join(tmp, f"p{n}.prg"); out = os.path.join(tmp, f"p{n}.exo")
    open(prg, "wb").write(bytes([inicio & 255, inicio >> 8]) + datos)
    subprocess.run([EXO, "mem", "-q", "-l", "none", "-o", out, prg], check=True)
    return open(out, "rb").read()


def main():
    es, en, sal = sys.argv[1:4]
    os.makedirs(sal, exist_ok=True)
    img, img_en = open(os.path.join(es, "juego.bin"), "rb").read(), open(os.path.join(en, "juego.bin"), "rb").read()
    b1 = open(os.path.join(es, "juego.bin.banco1"), "rb").read()
    b1_en = open(os.path.join(en, "juego.bin.banco1"), "rb").read()
    assert len(b1) == len(b1_en), "block 1's length differs between the languages"
    textos = [(int(c[3], 16), int(c[3], 16) + int(c[4])) for c in (l.split("\t") for l in open(os.path.join(es, "mapa64.tsv")))
              if len(c) > 6 and c[6] == "banco1" and c[0].startswith("D64_TXT_")]
    dif1 = [0x1000 + i for i in range(len(b1)) if b1[i] != b1_en[i]]
    assert all(any(a <= x < z for a, z in textos) for x in dif1), "block 1 differs outside the texts"
    e, e_en = etiquetas(os.path.join(es, "juego.lbl")), etiquetas(os.path.join(en, "juego.lbl"))
    otras = sorted(n for n in set(e) | set(e_en) if e.get(n) != e_en.get(n) and n not in DENTRO_GCE)
    assert not otras, "labels at other addresses in English: " + " ".join(otras)
    assert not any(img[0xC000:0xC400]), "the image has bytes where the last stage runs ($C000-$C3FF)"
    assert not any(img[0xFF00:0xFF05]), "the image has bytes under the MMU's registers"
    for n, nota in (("cinta_paso", 0x17), ("cinta_pitido", 0x54)):
        assert img[e[n]] == nota, f"{n} is not the note {nota:02X}h (the footstep's, the beep's)"
    # B: the two pages, then block 1
    b = img[0:0x200] + b1
    assert B1_PAGINAS + 0x200 == 0x1000
    # E: the English records
    dif = [a for a in range(0x10000) if img[a] != img_en[a]]
    assert not any(0xC000 <= a < 0xC400 or 0xFF00 <= a < 0xFF05 or a < 0x200 for a in dif), "English bytes outside the pieces"
    reg = bytearray()
    for dif_, mem, base in ((dif, img_en, 0), (dif1, b1_en, 0x1000)):
        i = 0
        while i < len(dif_):
            j = i
            while j + 1 < len(dif_) and dif_[j + 1] == dif_[j] + 1 and j + 1 - i < 255: j += 1
            a = dif_[i]
            reg += bytes([a & 255, a >> 8, j - i + 1]) + mem[a - base:a - base + j - i + 1]
            i = j + 1
        reg += b"\x00\x00"
    # J1: the first piece (the game's code and most data), loaded into block 1 so that it ends at $C000; J2: the other
    # two, loaded by the last stage once J1's piece is in place (the game's own KERNAL call, c128_carga) where J1 was
    with tempfile.TemporaryDirectory() as tmp:
        piezas = [crunch(img[a:z], a, tmp, k) for k, (a, z) in enumerate(PIEZAS)]
    j = piezas[0]
    j2 = b"".join(piezas[1:])
    j_ini = 0xC000 - len(j)
    fines = [0xC000]
    fines2, x = [], j_ini
    for p in piezas[1:]:
        x += len(p); fines2.append(x)
    b1_ingles = max(B1_PAGINAS + len(b), e["kernal_foto"] + FOTO)    # E after the photograph (made first)
    assert e["kernal_foto"] >= B1_PAGINAS + len(b), "the photograph overlaps block 1's data"
    assert b1_ingles + len(reg) <= j_ini, f"block 1 is full: B and E end at ${b1_ingles + len(reg):04X}, J1 starts at ${j_ini:04X}"
    assert j_ini + len(j2) <= 0xC000
    prg = lambda a, d: bytes([a & 255, a >> 8]) + d
    open(os.path.join(sal, "B.prg"), "wb").write(prg(B1_PAGINAS, b))
    open(os.path.join(sal, "J.prg"), "wb").write(prg(j_ini, j))
    open(os.path.join(sal, "J2.prg"), "wb").write(prg(j_ini, j2))
    open(os.path.join(sal, "E.prg"), "wb").write(prg(b1_ingles, bytes(reg)))
    # AVE: the Ave Maria's samples (ave128.py, in the build's directory) at the game's ave_muestra (block 1), loaded by
    # the last stage once the game is in place (J and E are no longer needed then)
    ave = open(os.path.join(es, "ave.bin"), "rb").read()
    assert ave == open(os.path.join(en, "ave.bin"), "rb").read()
    assert e["ave_muestra"] >= e["kernal_foto"] + FOTO and e["ave_muestra"] + len(ave) <= 0xD000
    assert img[e["c128_ave_llamada"]] == 0x20, "c128_ave_llamada is not a JSR"
    open(os.path.join(sal, "AVE.prg"), "wb").write(prg(e["ave_muestra"], ave))
    inc = ["; made by c64/disco128/piezas128.py (do not edit): the game's files in block 1, for etapa128.s",
           f"PIEZA1_FIN = ${fines[0]:04X}                ; J1's piece's end in block 1",
           f"NPIEZAS2 = {len(fines2)}",
           ".define PIEZAS2_LO " + ", ".join(f"${f & 255:02X}" for f in fines2),
           ".define PIEZAS2_HI " + ", ".join(f"${f >> 8:02X}" for f in fines2),
           f"B1_PAGINAS = ${B1_PAGINAS:04X}", f"B1_INGLES = ${b1_ingles:04X}"]
    nombres = {"principal_inicio": "J_PRINCIPAL_INICIO", "plat_opciones": "J_PLAT_OPCIONES", "plat_unidad": "J_PLAT_UNIDAD",
               "cinta_paso": "J_PASO", "cinta_pitido": "J_PITIDO", "kernal_foto": "J_FOTO",
               "c128_ave_llamada": "J_AVE", "c128_carga_ave": "J_CARGA_AVE", "c128_carga": "J_CARGA"}
    inc += [f"{nombres[n]} = ${e[n]:04X}" for n in FIJAS]
    open(os.path.join(sal, "juego128_gen.inc"), "w").write("\n".join(inc) + "\n")
    print(f"B: ${B1_PAGINAS:04X}-${B1_PAGINAS + len(b) - 1:04X} ({len(b)} bytes); E: {len(dif)} + {len(dif1)} English bytes, "
          f"{len(reg)} bytes at ${b1_ingles:04X}; J1: {len(j)} bytes at ${j_ini:04X}-$BFFF ({j_ini - b1_ingles - len(reg)} free before it), "
          f"J2: {len(j2)} bytes; the pieces "
          + ", ".join(f"${a:04X}-${z - 1:04X} {z - a} -> {len(p)}" for (a, z), p in zip(PIEZAS, piezas)))


if __name__ == "__main__":
    main()
