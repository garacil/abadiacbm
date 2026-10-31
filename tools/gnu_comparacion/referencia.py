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

"""The CPC reference for the GNU parchments: tools/cpc_carga.py, unchanged, with its
screenshot replaced by a dump of the screen state, at every 50 Hz frame of its non-synchronous mode
(--int; a frame every 6 interrupts of 13312 T-states).

    referencia.py VOLCADO.bin [--png F1,F2,...] [cpc_carga.py options...]   (--fotos 1-N: the frames to dump;
                                   --png: also cpc_carga.py's own screenshot of those frames, OUT/fNNNNNN.png)

VOLCADO.bin: per frame a little-endian u32 frame, u8 mode, 17 palette bytes (hardware colours), 16 CRTC
registers (only those written since the start; cpc_carga.py starts R1 = 40, R6 = 25, R9 = 7, R12 = 30h),
the 16 KiB at C000h-FFFFh: the format of abadia64ks --volcado.
"""
import os, struct, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import cpc_carga

salida = open(sys.argv[1], "wb")
del sys.argv[1]
pngs = set()
if len(sys.argv) > 2 and sys.argv[1] == "--png":
    pngs = {int(x) for x in sys.argv[2].split(",")}
    del sys.argv[1:3]
foto = cpc_carga.Machine.screenshot


def vuelca(self, path):
    if os.path.basename(path) == "final.png":
        return
    if self.frame in pngs:
        foto(self, path)
    salida.write(struct.pack("<IB", self.frame, self.mode) + bytes(p & 0x1F for p in self.palette)
                 + bytes(self.crtc[:16]) + bytes(self.mem[0xC000:0x10000]))


cpc_carga.Machine.screenshot = vuelca
cpc_carga.main()
salida.close()
