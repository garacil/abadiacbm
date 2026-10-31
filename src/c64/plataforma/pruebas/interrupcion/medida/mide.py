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

"""The 300 Hz interrupt's cycles in VICE: the game's frames 1-N from its start, no keys (as c64/juego_final/vice/arranca.py),
on an image whose plat_irq times its JSR sys_tick with CIA 1 timer B (medida.sh builds it; med.bin at $0100).
    mide.py IMAGEDIR MED.bin [FRAMES]     prints the frames' cycles, the windows and their mean
The game does not use CIA 1 timer B, and its stack stays above $01B0: $0198-$01AF hold a pattern the run checks
at its end (below it med.bin at $0100-$015F, the measuring plat_irq at $0160-$0187, the instrument's variables at
$0188-$0192)."""
import os, struct, sys
sys.dont_write_bytecode = True                       # no __pycache__ next to the imported modules
P = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "../../../../.."))
sys.path.insert(0, os.path.join(P, "c64/plataforma/pruebas"))
sys.path.insert(0, os.path.join(P, "c64/juego_final/vice"))
import vice_mb as V                                  # noqa: E402
from arranca import banco, escribe_banco             # noqa: E402

TESTIGO = bytes((0x5A + 7 * i) & 0xFF for i in range(0x18))   # $0198-$01AF: the stack must not reach it
VARS = 0x0188                                        # ACC (4), N (3), T0, TMP: med.s


def main():
    d, med = sys.argv[1], sys.argv[2]
    ultimo = int(sys.argv[3]) if len(sys.argv) > 3 else 400
    img = open(os.path.join(d, "juego.bin"), "rb").read()
    e = V.etiquetas(os.path.join(d, "juego.lbl"))
    with V.Vice(None, ["-sounddev", "dummy", "-warp"]) as v:
        v.hasta(0xE5CD, limite=120)
        ram = banco(v, "ram")
        escribe_banco(v, ram, 0x0002, img[2:0x10000])
        escribe_banco(v, ram, 0x0100, open(med, "rb").read())
        escribe_banco(v, ram, VARS, bytes(11))
        escribe_banco(v, ram, 0x0198, TESTIGO)
        v.pon_pc(e["principal_inicio"])
        io = banco(v, "io")
        escribe_banco(v, io, 0xDD04, b"\xff\xff\xff\xff")     # CIA 2: the frames' clock, as arranca.py
        escribe_banco(v, io, 0xDD0F, b"\x51")
        escribe_banco(v, io, 0xDD0E, b"\x11")
        escribe_banco(v, io, 0xDC06, b"\xff\xff")             # CIA 1 timer B: latch FFFFh, continuous, the clock
        escribe_banco(v, io, 0xDC0F, b"\x11")
        n = 0
        golpe = v.punto(e["game_input_and_mirror"], temporal=False)
        filas = []
        while n < ultimo:
            v.golpes.discard(golpe)
            v.orden(V.CMD_EXIT)
            while golpe not in v.golpes:
                v._respuesta()
            n += 1
            if n in (1, ultimo):
                _, c = v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, 0xDD04, 0xDD07, 0, io))
                ta, tb = struct.unpack("<HH", c[2:6])
                t = (0xFFFF - tb) * 65536 + (0xFFFF - ta)
                _, c = v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, VARS, VARS + 6, 0, ram))
                filas.append((t, struct.unpack("<I", c[2:6])[0], c[6] | c[7] << 8 | c[8] << 16))
        _, c = v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, 0x0198, 0x01AF, 0, ram))
        if c[2:2 + len(TESTIGO)] != TESTIGO:
            sys.exit("the game's stack reached $0198-$01AF: the instrument below it is not safe")
        print("the game's stack stayed above $01AF (the instrument at $0100-$0187 untouched)")
    (t1, a1, n1), (t2, a2, n2) = filas
    print(f"frames 1-{ultimo}: {t2 - t1} cycles (the instrument's included); {n2 - n1} windows, {(a2 - a1) / (n2 - n1):.1f} "
          f"cycles each (the JSR sys_tick ... RTS and the instrument's own, ~36: medida.sh VACIO=1 measures it)")


if __name__ == "__main__":
    main()
