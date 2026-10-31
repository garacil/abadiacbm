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
"""The game's files of the P500's disk (abadia128ks for the CBM-II 510, c64/discop500/NOTAS.md), from the P500 build
(c64/juego_final P500=1: p500/ and, English, p500_en/):
  B    the game's bank 1 (juego.bin.banco1: the room table, the texts, the heads' blacks), loaded into bank 1 at $1000;
  J    the game's bank 0 ($0002-$FFF5: everything but the 6509's two registers and the bytes the last stage writes)
       crunched by Exomizer (`mem`, backwards) in one piece, loaded into bank 1 so that it ends at J_FIN ($FF00, below
       the bytes of the KERNAL's return path the last stage writes there);
  E    the bytes of the English image that differ, as records (address lo, address hi, length 1-255, the bytes), ended
       by an address 0: bank 0's, then bank 1's (the texts), loaded into bank 1 at the game's ave_muestra (free until
       the Ave Maria is loaded, last);
  AVE  the Ave Maria's samples (ave128.py, in the build's directory) at the game's ave_muestra (bank 1), loaded by the
       last stage once J and E are used;
and juego500_gen.inc for the last stage (etapa500.s): J's end and start in bank 1, E's place and the game's addresses
the stage writes (principal_inicio, plat_opciones, plat_unidad, the three sound calls).  Both images must have the
same layout (the same labels but for the strings in game_check_end) and bank 1 the same but for the texts.
    piezas500.py P500_DIR P500_EN_DIR OUT_DIR       Deterministic."""
import os, subprocess, sys, tempfile
D = os.path.dirname(os.path.realpath(__file__))
P = os.path.dirname(os.path.dirname(D))
EXO = os.path.join(P, "..", "tools", "terceros", "exomizer", "exomizer2", "src", "exomizer")
B1 = 0x1000                                             # the game's bank 1 data (juego.cfg's B1)
J_DESDE, J_HASTA = 0x0002, 0xFFF6                       # bank 0's bytes in J
J_FIN = 0xFF00                                          # J's end in bank 1
ETAPA, ETAPA_FIN = 0x0200, 0x1000                       # where the last stage runs (bank 1, below B)
FIJAS = ["principal_inicio", "plat_opciones", "plat_unidad", "cinta_paso", "cinta_pitido", "c128_ave_llamada",
         "ave_muestra"]
DENTRO_GCE = {"cert_pausa2"}                            # the labels inside game_check_end (its strings)


def etiquetas(f):
    e = {}
    for l in open(f):
        t = l.split()
        if len(t) >= 3 and t[0] == "al": e[t[2].lstrip(".")] = int(t[1], 16)
    return e


def crunch(datos, inicio, tmp):
    """a piece crunched as the tape's programs are (a PRG: its load address first), the outfile without one"""
    prg = os.path.join(tmp, "p.prg"); out = os.path.join(tmp, "p.exo")
    open(prg, "wb").write(bytes([inicio & 255, inicio >> 8]) + datos)
    subprocess.run([EXO, "mem", "-q", "-l", "none", "-o", out, prg], check=True)
    return open(out, "rb").read()


def main():
    es, en, sal = sys.argv[1:4]
    os.makedirs(sal, exist_ok=True)
    img, img_en = open(os.path.join(es, "juego.bin"), "rb").read(), open(os.path.join(en, "juego.bin"), "rb").read()
    b1 = open(os.path.join(es, "juego.bin.banco1"), "rb").read()
    b1_en = open(os.path.join(en, "juego.bin.banco1"), "rb").read()
    assert len(b1) == len(b1_en), "bank 1's length differs between the languages"
    textos = [(int(c[3], 16), int(c[3], 16) + int(c[4])) for c in (l.split("\t") for l in open(os.path.join(es, "mapa64.tsv")))
              if len(c) > 6 and c[6] == "banco1" and c[0].startswith("D64_TXT_")]
    dif1 = [B1 + i for i in range(len(b1)) if b1[i] != b1_en[i]]
    assert all(any(a <= x < z for a, z in textos) for x in dif1), "bank 1 differs outside the texts"
    e, e_en = etiquetas(os.path.join(es, "juego.lbl")), etiquetas(os.path.join(en, "juego.lbl"))
    otras = sorted(n for n in set(e) | set(e_en) if e.get(n) != e_en.get(n) and n not in DENTRO_GCE)
    assert not otras, "labels at other addresses in English: " + " ".join(otras)
    assert not any(img[J_HASTA:]), "the image has bytes from $FFF6 on (the last stage writes its jump there)"
    assert not any(img[0xFF20:0xFF30]), "the image has bytes where the KERNAL's return path goes ($FF26)"
    for n, b in (("cinta_paso", 0x17), ("cinta_pitido", 0x54), ("c128_ave_llamada", 0x20)):
        assert img[e[n]] == b, f"{n} is not {b:02X}h (the footstep's note, the beep's, a JSR)"
    # E: the English records
    dif = [a for a in range(0x10000) if img[a] != img_en[a]]
    assert not any(a < J_DESDE or a >= J_HASTA for a in dif), "English bytes outside J"
    reg = bytearray()
    for dif_, mem, base in ((dif, img_en, 0), (dif1, b1_en, B1)):
        i = 0
        while i < len(dif_):
            j = i
            while j + 1 < len(dif_) and dif_[j + 1] == dif_[j] + 1 and j + 1 - i < 255: j += 1
            a = dif_[i]
            reg += bytes([a & 255, a >> 8, j - i + 1]) + mem[a - base:a - base + j - i + 1]
            i = j + 1
        reg += b"\x00\x00"
    with tempfile.TemporaryDirectory() as tmp:
        j = crunch(img[J_DESDE:J_HASTA], J_DESDE, tmp)
    j_ini = J_FIN - len(j)
    e_ini = e["ave_muestra"]
    assert e_ini >= B1 + len(b1), "ave_muestra overlaps bank 1's data"
    assert e_ini + len(reg) <= j_ini, f"bank 1 is full: E ends at ${e_ini + len(reg):04X}, J starts at ${j_ini:04X}"
    ave = open(os.path.join(es, "ave.bin"), "rb").read()
    assert ave == open(os.path.join(en, "ave.bin"), "rb").read()
    assert e["ave_muestra"] + len(ave) <= 0xFF00
    prg = lambda a, d: bytes([a & 255, a >> 8]) + d
    open(os.path.join(sal, "B.prg"), "wb").write(prg(B1, b1))
    open(os.path.join(sal, "J.prg"), "wb").write(prg(j_ini, j))
    open(os.path.join(sal, "E.prg"), "wb").write(prg(e_ini, bytes(reg)))
    open(os.path.join(sal, "AVE.prg"), "wb").write(prg(e["ave_muestra"], ave))
    inc = ["; made by c64/discop500/piezas500.py (do not edit): the game's files in bank 1, for etapa500.s",
           f"J_FIN = ${J_FIN:04X}                     ; J's end in bank 1 (Exomizer's `mem`: decrunched backwards)",
           f"J_INI = ${j_ini:04X}", f"B1_INGLES = ${e_ini:04X}"]
    nombres = {"principal_inicio": "J_PRINCIPAL_INICIO", "plat_opciones": "J_PLAT_OPCIONES", "plat_unidad": "J_PLAT_UNIDAD",
               "cinta_paso": "J_PASO", "cinta_pitido": "J_PITIDO", "c128_ave_llamada": "J_AVE", "ave_muestra": "J_AVE_MUESTRA"}
    inc += [f"{nombres[n]} = ${e[n]:04X}" for n in FIJAS]
    open(os.path.join(sal, "juego500_gen.inc"), "w").write("\n".join(inc) + "\n")
    print(f"B: ${B1:04X}-${B1 + len(b1) - 1:04X} ({len(b1)} bytes); E: {len(dif)} + {len(dif1)} English bytes, {len(reg)} bytes "
          f"at ${e_ini:04X}; J: {len(j)} bytes at ${j_ini:04X}-${J_FIN - 1:04X} (bank 0 ${J_DESDE:04X}-${J_HASTA - 1:04X}, "
          f"{J_HASTA - J_DESDE} bytes; {j_ini - e_ini - len(reg)} free before it); AVE: {len(ave)} bytes at ${e['ave_muestra']:04X}")


if __name__ == "__main__":
    main()
