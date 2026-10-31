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

"""The loading picture of abadia64ks / abadia128ks as VICE shows it (x64sc or x128, warp, the disk c64/disco64/
abadia64ks.d64 or c64/disco128/abadia128ks.d64): the menu, the language (es / en), SPACE; the presentation's
parchment ended with a key (a key ends it at once: manuscrito.c), SPACE again; at the game's loader (cargador.s
inicio; the C128: the presentation's gameload) a second more and VICE's screenshot (384x272), for the thumbnails
(miniaturas.py).

    captura_carga.py es|en OUT.png [--c128]"""
import os, sys, time
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path[:0] = [str(HERE), str(ROOT / "c64/plataforma/pruebas")]
if "--c128" in sys.argv: os.environ["VICE_EMU"] = "x128"
import vice_mb as V                                   # noqa: E402
import ayudas as D                                    # noqa: E402

idioma, salida = sys.argv[1], Path(sys.argv[2]).resolve()
C128 = "--c128" in sys.argv
if C128:
    PRES = ROOT / "c64/presentacion/generado_c128"
    menu = V.etiquetas(str(ROOT / "c64/disco128/generado/menu.lbl"))
    opciones = ["-sounddev", "dummy", "-hidevdcwindow", "-40col", "-8", str(ROOT / "c64/disco128/abadia128ks.d64")]   # (real time: its picture lasts ~25 s, then the last stage blanks the screen)
else:
    PRES = ROOT / "c64/presentacion/generado_disco64"
    menu = V.etiquetas(str(ROOT / "c64/disco64/generado/menu.lbl"))
    opciones = ["-sounddev", "dummy", "-warp", "-autostart", str(ROOT / "c64/disco64/abadia64ks.d64")]
ab = V.etiquetas(str(PRES / "abadia.lbl"))
carga = ab["_gameload"] if C128 else V.etiquetas(str(PRES / "cargador.lbl"))["inicio"]
with V.Vice(None, opciones, registro=str(salida.with_suffix(".vice.log"))) as v:
    D.corre_hasta(v, menu["tecla"], limite=600)
    if idioma == "en":
        D.escribe(v, "1")
        v.orden(V.CMD_EXIT); time.sleep(1); v.para()
    D.escribe(v, " ")
    D.corre_hasta(v, ab["_musicstart"], limite=600)
    D.escribe(v, " ")                                 # the parchment ended at once
    D.corre_hasta(v, ab["_cgetc"], limite=600)
    v.orden(V.CMD_EXIT); time.sleep(0.5); v.para()
    D.escribe(v, " ")
    D.corre_hasta(v, carga, limite=600)
    v.orden(V.CMD_EXIT); time.sleep(3 if C128 else 1); v.para()
    v.captura(str(salida))
print(salida)
