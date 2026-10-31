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

"""The CPC's loading picture as the original shows it once loaded, in the Caprice32 (doc/control_fifo.md, its
control socket, Xvfb :99): the tape's block 20h in memory (data/cpc64/cinta/juego.bin: the screen C000h-FFFFh
holds the picture) with the loader's display: mode 0, its inks (data/cpc64/cinta/tintas.txt: pens 0-15, then the
border; the table at 0103h), its CRTC (01E9h: R1 = 32, R2 = 43, R6 = 24; the rest the power-on values), the CPU held
in a JR $ with the interrupts off; a screenshot after 5 frames.

    cpc_pantalla.py OUT.png
"""
import os, sys, time

P = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__)))))
sys.path.insert(0, os.path.join(P, "tools"))
sys.path.insert(0, os.path.join(P, "src/c64/pergamino/revision_pagina"))
from cpc_velocidad import sna                                         # noqa: E402
from cpc_pagina import Cap, regs                                      # noqa: E402

TRAMPA = 0x0040


def main():
    out = os.path.realpath(sys.argv[1])
    d = os.path.dirname(out)
    ram = bytearray(open(os.path.join(P, "data/cpc64/cinta/juego.bin"), "rb").read())
    ram[TRAMPA:TRAMPA + 2] = b"\x18\xFE"                              # JR $
    tintas = [int(x, 16) for x in open(os.path.join(P, "data/cpc64/cinta/tintas.txt")).read().split()]
    e = {k: 0 for k in ("A", "B", "C", "D", "E", "H", "L", "IXh", "IXl", "IYh", "IYl", "I", "R",
                        "A'", "F'", "B'", "C'", "D'", "E'", "H'", "L'", "F")}
    e.update({"SP": 0xC000, "PC": TRAMPA, "IFF": 0, "IM": 1, "mode": 0, "palette": tintas,
              "crtc": [63, 32, 43, 0x8E, 38, 0, 24, 30, 0, 7, 0, 0, 0x30, 0, 0, 0]})
    s = os.path.join(d, "pantalla_cpc.sna")
    sna(bytes(ram), e, s)
    c = Cap(os.path.join(d, "cap32_pantalla.sock"), os.path.join(d, "cap32_pantalla.log"), False)
    try:
        c.orden(["pause", f"loadsnap {s}", "resume"])
        f0 = regs(c.orden(["regs"])[0])["frame"]
        while regs(c.orden(["regs"])[0])["frame"] < f0 + 5:
            time.sleep(0.01)
        c.orden([f"screenshot {out}"])
        r = regs(c.orden(["regs"])[0])
        assert r["PC"] == TRAMPA, hex(r["PC"])
    finally:
        c.cierra()
    os.unlink(s)
    print(out)


if __name__ == "__main__":
    main()
