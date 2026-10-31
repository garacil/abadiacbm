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
"""The loading picture of abadia128ks on the P500 as VICE shows it (xcbm5x0, warp, an 8050 with the disk
c64/discop500/abadia128ks_p500.d80): DLOAD"ABADIA" and RUN into the KERNAL's buffer (bank 15, ten places), the menu's
language (es / en) and SPACE into cc65's buffer (keybuf / keyidx), the parchment ended with SPACE; at the loader's
loader (carga500.s), a moment later, VICE's screenshot (384x272), for the title card and the thumbnails
(monta.py, miniaturas.py).

    captura_carga500.py es|en OUT.png"""
import os, struct, sys, time
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path[:0] = [str(HERE), str(ROOT / "c64/plataforma/pruebas")]
os.environ["VICE_EMU"] = "xcbm5x0"
import vice_mb as V                                   # noqa: E402

idioma, salida = sys.argv[1], Path(sys.argv[2]).resolve()
PRES = ROOT / "c64/presentacion/generado_p500"
ab = V.etiquetas(str(PRES / "abadia.lbl"))


def escribe(v, ini, datos, banco):
    v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, ini, ini + len(datos) - 1, 0, banco) + bytes(datos))


def teclea(v, texto):                                 # the KERNAL's buffer, ten places at a time
    for k in range(0, len(texto), 10):
        p = texto[k:k + 10].encode("ascii")
        escribe(v, 0x03AB, p, 15)
        escribe(v, 0xD1, bytes([len(p)]), 15)
        v.orden(V.CMD_EXIT); time.sleep(0.4); v.para()


def tecla(v, c):                                      # cc65's buffer
    escribe(v, ab["keybuf"], c.encode("ascii"), 0)
    escribe(v, ab["keyidx"], b"\x01", 0)


def hasta(v, dir, antes=None, limite=600):
    _, c = v.orden(V.CMD_CHECKPOINT_SET, struct.pack("<HHBBBBB", dir, dir, 1, 1, 4, 1, 0))
    num = struct.unpack("<I", c[:4])[0]
    v.golpes.discard(num)
    if antes:
        antes()
    v.s.settimeout(limite)
    v.orden(V.CMD_EXIT)
    while num not in v.golpes:
        v._respuesta()
    v.s.settimeout(None)


with V.Vice(None, ["-model", "510", "-ramsize", "128", "-pal", "-sounddev", "dummy", "-warp", "-drive8type", "8050",
                   "-drive8truedrive", "-8", str(ROOT / "c64/discop500/abadia128ks_p500.d80")]) as v:
    v.orden(V.CMD_EXIT); time.sleep(6); v.para()
    teclea(v, 'DLOAD"ABADIA"\r')
    v.orden(V.CMD_EXIT); time.sleep(10); v.para()
    hasta(v, ab["_menu500"], antes=lambda: teclea(v, "RUN\r"))
    v.orden(V.CMD_EXIT); time.sleep(2); v.para()
    if idioma == "en":
        tecla(v, "1")
        v.orden(V.CMD_EXIT); time.sleep(1); v.para()
    hasta(v, ab["_manusintro"], antes=lambda: tecla(v, " "))
    v.orden(V.CMD_EXIT); time.sleep(3); v.para()
    hasta(v, ab["_carga_juego500"], antes=lambda: tecla(v, " "))
    v.orden(V.CMD_EXIT); time.sleep(0.05); v.para()   # the picture on the screen, the files loading (VICE's picture
    v.captura(str(salida))                            #   taken while stopped inside the KERNAL's LOAD can be black)
    print(salida)
