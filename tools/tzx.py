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

"""TZX / CDT tape images: list the blocks, and give the data of each data block.

    tzx.py FILE.cdt              list the blocks (id, timings, length, the CPC header of standard blocks)
    tzx.py FILE.cdt --vuelca DIR write every data block's bytes to DIR/bloqueNN.bin

Blocks handled: 10 (standard speed), 11 (turbo speed), 12 (pure tone), 13 (pulse sequence), 14 (pure
data), 15 (direct recording), 20 (pause), 21/22 (group), 30 (text), 32 (archive info), 33, 35, 5A.
"""
import os, struct, sys


def bloques(d):
    assert d[:8] == b"ZXTape!\x1a", "not a TZX/CDT file"
    i = 10
    while i < len(d):
        bid = d[i]; i += 1
        if bid == 0x10:
            pausa, n = struct.unpack_from("<HH", d, i); datos = d[i + 4:i + 4 + n]
            yield bid, {"pausa": pausa}, datos; i += 4 + n
        elif bid == 0x11:
            piloto, s1, s2, b0, b1, ntonos, ult, pausa = struct.unpack_from("<HHHHHHBH", d, i)
            n = d[i + 15] | d[i + 16] << 8 | d[i + 17] << 16
            yield bid, {"piloto": piloto, "sync": (s1, s2), "bits": (b0, b1), "tonos": ntonos, "ultimo": ult, "pausa": pausa}, d[i + 18:i + 18 + n]
            i += 18 + n
        elif bid == 0x12:
            yield bid, {"pulso": struct.unpack_from("<H", d, i)[0], "n": struct.unpack_from("<H", d, i + 2)[0]}, b""; i += 4
        elif bid == 0x13:
            n = d[i]; yield bid, {"pulsos": struct.unpack_from("<%dH" % n, d, i + 1)}, b""; i += 1 + 2 * n
        elif bid == 0x14:
            b0, b1, ult, pausa = struct.unpack_from("<HHBH", d, i); n = d[i + 7] | d[i + 8] << 8 | d[i + 9] << 16
            yield bid, {"bits": (b0, b1), "ultimo": ult, "pausa": pausa}, d[i + 10:i + 10 + n]; i += 10 + n
        elif bid == 0x15:
            t, pausa, ult = struct.unpack_from("<HHB", d, i); n = d[i + 5] | d[i + 6] << 8 | d[i + 7] << 16
            yield bid, {"t_muestra": t, "pausa": pausa, "ultimo": ult}, d[i + 8:i + 8 + n]; i += 8 + n
        elif bid == 0x20:
            yield bid, {"pausa": struct.unpack_from("<H", d, i)[0]}, b""; i += 2
        elif bid == 0x21:
            n = d[i]; yield bid, {"grupo": d[i + 1:i + 1 + n].decode("latin1")}, b""; i += 1 + n
        elif bid == 0x22:
            yield bid, {}, b""
        elif bid == 0x30:
            n = d[i]; yield bid, {"texto": d[i + 1:i + 1 + n].decode("latin1")}, b""; i += 1 + n
        elif bid == 0x32:
            n = struct.unpack_from("<H", d, i)[0]; blk = d[i + 2:i + 2 + n]; k = 1; info = []
            for _ in range(blk[0]):
                t, l = blk[k], blk[k + 1]; info.append((t, blk[k + 2:k + 2 + l].decode("latin1"))); k += 2 + l
            yield bid, {"info": info}, b""; i += 2 + n
        elif bid == 0x33:
            n = d[i]; yield bid, {}, b""; i += 1 + 3 * n
        elif bid == 0x35:
            n = struct.unpack_from("<I", d, i + 16)[0]; yield bid, {"id": d[i:i + 16].decode("latin1").strip()}, d[i + 20:i + 20 + n]; i += 20 + n
        elif bid == 0x5A:
            i += 9
        else:
            raise ValueError(f"unknown block {bid:02X} at {i - 1}")


def main():
    d = open(sys.argv[1], "rb").read()
    destino = sys.argv[sys.argv.index("--vuelca") + 1] if "--vuelca" in sys.argv else None
    if destino: os.makedirs(destino, exist_ok=True)
    for k, (bid, p, datos) in enumerate(bloques(d)):
        extra = ""
        if datos and bid in (0x10, 0x11, 0x14) and len(datos) >= 1 and datos[0] == 0x2C and len(datos) >= 30:
            nombre = datos[1:17].decode("latin1").rstrip("\0 ")
            blq, ult, tipo = datos[17], datos[18], datos[19]
            ln, carga = struct.unpack_from("<HH", datos, 20)
            extra = f'  CPC header "{nombre}" block {blq} last {ult:02X} type {tipo:02X} len {ln:04X} load {carga:04X}'
        elif datos:
            extra = f"  first bytes {datos[:8].hex()}"
        print(f"{k:3} {bid:02X} {len(datos):6} {p}{extra}")
        if destino and datos:
            open(os.path.join(destino, f"bloque{k:02d}.bin"), "wb").write(datos)


if __name__ == "__main__":
    main()
