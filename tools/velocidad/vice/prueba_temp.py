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

"""Does a checkpoint created while stopped, a few dozen cycles before its address is reached, stop the emulation?
Three variants over 200 interrupts each: (a) a temporary checkpoint at the RTI created at the IRQ entry stop;
(b) a permanent one created there and deleted at the next stop; (c) a permanent one created at the start.
Prints how many of the 200 resumes stopped at the RTI.  Usage: prueba_temp.py IMGDIR"""
import os, struct, sys
D = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, D)
sys.path.insert(0, os.path.join(D, "..", "..", "..", "src", "c64", "plataforma", "pruebas"))   # vice_mb
import vice_mb as V
from medir import arranque, Medida, segmentos, sitios

imgdir = sys.argv[1]
img = open(os.path.join(imgdir, "juego.bin"), "rb").read()
e = V.etiquetas(os.path.join(imgdir, "juego.lbl"))
s = sitios(img, e, segmentos(os.path.join(imgdir, "juego.map")))
os.environ.setdefault("VICE_DISPLAY", ":90")
with V.Vice(None, ["-sounddev", "dummy", "-warp", "+VICIIvsync"]) as v:
    io = arranque(v, img, e)
    m = Medida(v, io)
    m.punto("IRQ", s["IRQ"])
    for variante in "abc":
        bien = 0
        fijo = m.punto("RTI", s["RTI"]) if variante == "c" else None
        for _ in range(200):
            pc, _ = m.sigue()
            while pc != s["IRQ"]:
                pc, _ = m.sigue()
            if variante == "a":
                m.punto("RTI", s["RTI"], temporal=True)
            elif variante == "b":
                n = m.punto("RTI", s["RTI"])
            pc, golpes = m.sigue()
            if pc == s["RTI"]:
                bien += 1
            if variante == "b":
                m.borra(n)
        if fijo is not None:
            m.borra(fijo)
        print(f"variant {variante}: {bien}/200 stops at the RTI")
