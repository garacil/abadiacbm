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

"""The game live in VICE on a desktop, without its loader or a disk: as arranca.py, the whole 64 KiB image
(JUEGO_DIR/juego.bin, default c64/juego_final/c64; c64hw: the hardware sprites) is written into the RAM through the
binary monitor once the machine has booted and the CPU is sent to principal_inicio; then the monitor is left and
VICE keeps running on its own (sound, keyboard, no warp) until it is closed by hand.

    vivo.py [VICE OPTIONS...]        e.g. -VICIIdsize for a 4K desktop
    VICE_DISPLAY=:1  the desktop's X display (vice_mb's default is Xvfb :99); XAUTHORITY and PULSE_SERVER pass through
    VICE_LOG=FILE    the emulator's output (default: discarded)
"""
import os, sys
D = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, os.path.join(D, "../../plataforma/pruebas"))
sys.path.insert(0, D)
import vice_mb as V
from arranca import banco, escribe_banco, arranca_juego


def main():
    juego = os.environ.get("JUEGO_DIR", os.path.join(D, "../c64"))
    img = open(os.path.join(juego, "juego.bin"), "rb").read()
    e = V.etiquetas(os.path.join(juego, "juego.lbl"))
    v = V.Vice(None, sys.argv[1:], registro=os.environ.get("VICE_LOG"))
    v.hasta(0xE5CD, limite=120)                 # the KERNAL's screen editor waits for a key: booted
    escribe_banco(v, banco(v, "ram"), 0x0002, img[2:0x10000])
    arranca_juego(v, e["principal_inicio"])
    v.orden(V.CMD_EXIT)                         # the emulation resumed; the monitor's socket left open but unused
    v.s.close()
    print(f"VICE running (pid {v.proc.pid}) with {os.path.join(juego, 'juego.bin')}", flush=True)


if __name__ == "__main__":
    main()
