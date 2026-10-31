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

"""The PC version's Ave Maria for the C128 (milestone H10; the Ave Maria at mass, on or off,
played as on the PC): c64/datos/pc/voz_ave_maria.bin (the PC's voice at 2E44:0000, 8062 samples a second,
unsigned 8 bit, 110976 bytes: c64/datos/pc/PROCEDENCIA.tsv) as the C128 plays it through the SID's volume register:
the first 13.45 s (after them the PC plays 0.27 s of other data: a click), each two samples averaged (4031 a second),
4 bits (8 + x * 7.5 / 160 of the pairs' sum x, clipped: 99 % of them inside), two a byte, the first in the high
nibble.  Writes OUT_DIR/ave.bin and OUT_DIR/ave128.inc (AVE_LARGO; AVE_CICLOS, a PAL C128's cycles a sample).

    ave128.py OUT_DIR"""
import os, sys
D = os.path.dirname(os.path.realpath(__file__))
P = os.path.dirname(os.path.dirname(D))
FUENTE = os.path.join(P, "c64", "datos", "pc", "voz_ave_maria.bin")
HZ_PC, SEGUNDOS, PAL = 8062, 13.45, 985248


def main():
    sal = sys.argv[1]
    os.makedirs(sal, exist_ok=True)
    d = open(FUENTE, "rb").read()
    assert len(d) == 110976
    fin = int(SEGUNDOS * HZ_PC)
    s = [d[i] + d[i + 1] - 256 for i in range(0, fin - 1, 2)]
    n4 = [max(0, min(15, 8 + round(x * 7.5 / 160))) for x in s]
    if len(n4) & 1: n4.append(8)
    datos = bytes(n4[i] << 4 | n4[i + 1] for i in range(0, len(n4), 2))
    open(os.path.join(sal, "ave.bin"), "wb").write(datos)
    ciclos = round(PAL / (HZ_PC / 2))
    open(os.path.join(sal, "ave128.inc"), "w").write(
        "; made by c64/disco128/ave128.py (do not edit): the Ave Maria for the C128\n"
        f"AVE_LARGO  = {len(datos)}                 ; bytes, two 4-bit samples each\n"
        f"AVE_CICLOS = {ciclos}                   ; PAL cycles a sample ({HZ_PC // 2} a second)\n")
    print(f"ave.bin: {len(datos)} bytes, {len(n4)} samples at {HZ_PC / 2:.0f} Hz ({len(n4) / (HZ_PC / 2):.2f} s), "
          f"{ciclos} cycles each")


if __name__ == "__main__":
    main()
