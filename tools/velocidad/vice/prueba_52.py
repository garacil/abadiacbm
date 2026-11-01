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

"""Single-step the frame-wait loop of frame N to see what runs between the ESPERA stop and the SALIDA stop
(some frames show 52 cycles there with no interrupt).  Prints each instruction's PC, the CIA 2 time, the status
register, zero page $50 (D64_SYS_TICKS) and $3C (D64_SYS_FRAME_TICKS), and CIA 1 timer A.
Usage: prueba_52.py IMGDIR N"""
import os, struct, sys
D = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, D)
sys.path.insert(0, os.path.join(D, "..", "..", "..", "src", "c64", "plataforma", "pruebas"))   # vice_mb
import vice_mb as V
from medir import arranque, Medida, segmentos, sitios, REG_PC

CMD_ADVANCE = 0x71
imgdir, N = sys.argv[1], int(sys.argv[2])
img = open(os.path.join(imgdir, "juego.bin"), "rb").read()
e = V.etiquetas(os.path.join(imgdir, "juego.lbl"))
s = sitios(img, e, segmentos(os.path.join(imgdir, "juego.map")))
os.environ.setdefault("VICE_DISPLAY", ":90")
with V.Vice(None, ["-sounddev", "dummy", "-warp", "+VICIIvsync"]) as v:
    io = arranque(v, img, e)
    m = Medida(v, io)
    m.punto("FRAME", s["FRAME"])
    frame = 0
    while frame < N - 1:
        pc, _ = m.sigue()
        if pc == s["FRAME"]:
            frame += 1
    m.punto("ESPERA", s["ESPERA"])
    pc, _ = m.sigue()
    assert pc == s["ESPERA"], hex(pc)
    def estado():
        r = v.registros()
        _, c = v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, 0x3C, 0x50, 0, 0))
        zp = c[2:]
        return f"PC {r[REG_PC]:04X} t {m.tiempo()} SR {r[5]:02X} ticks {zp[0x50 - 0x3C]} budget {zp[0]} TA {m.cia1_ta()} SP {r[4]:02X}"
    print("at ESPERA:", estado())
    for i in range(40):
        v.orden(CMD_ADVANCE, struct.pack("<BH", 0, 1))
        while True:                                  # wait for the stop
            tipo, error, rid, cuerpo = v._respuesta()
            if tipo == V.RESP_STOPPED:
                break
        st = estado()
        print(f"step {i + 1}:", st)
        if st.startswith(f"PC {s['SALIDA']:04X}"):
            break
