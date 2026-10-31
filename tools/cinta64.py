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

"""The CPC 64 KiB version from its original cassette (a CDT/TZX image): the three blocks its loader
reads, placed in memory as the loader places them.

    cinta64.py FILE.cdt OUTDIR

The tape: a standard-format file "CARGADOR" (512 bytes at 0100h, run there) whose loader (0150h: A =
flag byte, HL = last address, DE = length; the bytes are stored downwards from HL) reads three turbo
blocks (TZX block 11h, a flag byte then the data):
  16h: 2C00h bytes, 8BFFh down to 6000h: the first stage (the introduction parchment), CALL 6000h;
  20h: FE00h bytes, FFFFh down to 0200h: the game and, in the screen memory, the loading screen,
       shown as it loads (mode 0, the inks of 0103h, the CRTC of 01E9h); then SP = C000h, JP 0200h;
  2Ah: 2C00h bytes, 8BFFh down to 6000h: the ending parchment, loaded by the game (31CFh) at 100 %.
Writes OUTDIR/cargador.bin (the 512 bytes), primera_etapa.bin, juego.bin, final.bin (64 KiB images:
the loader's memory with each block in place: 0000h-00FFh as the loader leaves it, the loader's
routines copied to 0064h, RST 38h = RET), and tintas.txt (the loading screen's 17 inks, hardware
numbers, pens 0-15 then the border: the loop at 026Ch, run at 00C6h, counts A down from 11h and writes
pen A-1, so the table at 0103h holds the border first, then pens 15 down to 0).
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tzx import bloques


def main():
    d = open(sys.argv[1], "rb").read()
    out = sys.argv[2]
    os.makedirs(out, exist_ok=True)
    datos = [b for bid, p, b in bloques(d) if bid in (0x10, 0x11, 0x14) and b]
    cab = next(b for b in datos if b[0] == 0x2C)
    carg_blq = datos[datos.index(cab) + 1]
    cargador = carg_blq[1:257] + carg_blq[259:515]                     # two 256-byte segments, CRCs dropped
    base = bytearray(65536)
    base[0x0100:0x0300] = cargador
    base[0x0064:0x0064 + 0x9C] = base[0x020A:0x020A + 0x9C]            # 011Ah: LDIR 020Ah -> 0064h, 9Ch bytes
    base[0x0038] = 0xC9                                                 # 0115h: RST 38h = RET
    def carga(mem, flag, fin, n):
        blq = next(b for b in datos[datos.index(carg_blq) + 1:] if b[0] == flag)   # the turbo blocks after the loader
        assert len(blq) >= n + 1, f"block {flag:02X} too short"
        for k in range(n):
            mem[fin - k] = blq[1 + k]
        return mem
    open(os.path.join(out, "cargador.bin"), "wb").write(cargador)
    primera = carga(bytearray(base), 0x16, 0x8BFF, 0x2C00)
    open(os.path.join(out, "primera_etapa.bin"), "wb").write(primera)
    juego = carga(bytearray(primera), 0x20, 0xFFFF, 0xFE00)
    open(os.path.join(out, "juego.bin"), "wb").write(juego)
    final = carga(bytearray(juego), 0x2A, 0x8BFF, 0x2C00)
    open(os.path.join(out, "final.bin"), "wb").write(final)
    tabla = cargador[3:20]                                              # 0103h: border, pen 15, ..., pen 0
    tintas = list(reversed(tabla[1:])) + [tabla[0]]
    open(os.path.join(out, "tintas.txt"), "w").write(" ".join(f"{b:02X}" for b in tintas) + "\n")
    print("blocks:", " ".join(f"{b[0]:02X}:{len(b)}" for b in datos))


if __name__ == "__main__":
    main()
