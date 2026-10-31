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
"""Lines typed into a running xcbm5x0 (the P500) through its binary monitor, each ended by RETURN: into the KERNAL's
keyboard buffer of bank 15 ($03AB, its count $D1: ten places, $03B5 on is a vector, so in pieces of up to ten, each
taken by the screen editor before the next).  Each line waits for BASIC's "ready." (one more of them on the text
screen, $D000 of bank 15: the monitor's I/O bank, 16): the machine's start-up first, then the previous line's work (a
DLOAD of the 43 KiB presentation on an emulated 8050: 18 s).
    teclea_p500.py HOST PORT LINE...      (e.g. 'DLOAD"ABADIA"' 'RUN')"""
import os, socket, struct, sys, time
sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "src", "c64", "plataforma", "pruebas"))
import vice_mb as V


READY = bytes([0x12, 0x05, 0x01, 0x04, 0x19, 0x2E])    # "ready." in screen codes


def espera_ready(v, antes, limite=180):
    """run until the text screen shows more "ready." than antes; their number"""
    t0 = time.time()
    while time.time() - t0 < limite:
        _, c = v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, 0xD000, 0xD3E7, 0, 16))
        n = c[2:].count(READY)
        if n > antes:
            return n
        v.orden(V.CMD_EXIT)
        time.sleep(0.5)
        v.orden(V.CMD_PING)
    sys.exit("teclea_p500.py: no ready.")


def main():
    host, puerto, lineas = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
    v = object.__new__(V.Vice)
    for _ in range(100):
        try:
            v.s = socket.create_connection((host, puerto))
            break
        except OSError:
            time.sleep(0.2)
    v.id = 0; v.eventos = []; v.parado = False; v.pc = None; v.paradas = 0; v.golpes = set(); v.jams = 0
    listos = 0
    for n, linea in enumerate(lineas):
        listos = espera_ready(v, listos)
        texto = linea + "\r"
        for k in range(0, len(texto), 10):
            t = texto[k:k + 10]
            v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, 0x03AB, 0x03AB + len(t) - 1, 0, 15) + t.encode("ascii"))
            v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, 0xD1, 0xD1, 0, 15) + bytes([len(t)]))
            v.orden(V.CMD_EXIT)
            time.sleep(0.5)
            v.orden(V.CMD_PING)
    v.orden(V.CMD_EXIT)
    v.s.close()


if __name__ == "__main__":
    main()
