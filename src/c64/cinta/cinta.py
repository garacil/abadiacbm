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

"""The tape image (TAP version 1) of abadia64ks (c64/cinta/NOTAS.md): the KERNAL's files in the C64 ROM's own
encoding (doc/referencias/cinta_c64.md) and the turbo blocks (turbo.s).

    cinta.py OUT.tap ITEM...      ITEM: kernal:NAME:FILE.prg (a KERNAL file, a PRG with its load address) or
                                  turbo:ID:ADDRESS:FILE[:PILOT] (a turbo block: FILE's bytes for ADDRESS; PILOT bytes
                                  of pilot, default 160) or pausa:SECONDS (silence)
Deterministic: the same items, the same bytes."""
import struct, sys

# the KERNAL's waves (TAP values = cycles / 8): C64-Wiki "Datassette Encoding", PAL: 2 x 182.7, 2 x 265.7,
# 2 x 348.8 us at 985248 Hz -> 360, 524, 687 cycles
K_CORTA, K_MEDIA, K_LARGA = 0x2D, 0x41, 0x56
K_GUIA_PRIMERA = 27136                  # about 10 s of short waves before a file's first block (W)
K_GUIA = 5376                           # about 2 s before every other copy (W)

# the turbo blocks (turbo.s, cinta.inc): a short wave is a 1, a long one a 0; UMBRAL = 392 cycles between them
T_CORTA, T_LARGA = 0x2C, 0x58           # 352 and 704 cycles (the game's loader works up to ~350 cycles between two
PILOTO, SINCRO = 0x40, 0x5A             # bytes, plus a bad line's 43: measured failing with 272 / 512 / 392)
UMBRAL = 528
assert 8 * T_CORTA + 120 < UMBRAL < 8 * T_LARGA - 120, "the turbo's waves too close to its threshold"


class Cinta:
    def __init__(self):
        self.ondas = bytearray()

    def silencio(self, ciclos):
        """a wave of `ciclos` cycles (TAP v1: $00 and the length, 3 bytes LOW/HIGH: Schepers' TAP.TXT)"""
        while ciclos > 0xFFFFFF:
            self.ondas += b"\0" + (0xFFFFFF).to_bytes(3, "little")
            ciclos -= 0xFFFFFF
        self.ondas += b"\0" + ciclos.to_bytes(3, "little")

    # ---- the KERNAL's encoding (W, C: doc/referencias/cinta_c64.md) ----
    def k_bit(self, b):
        self.ondas += bytes([K_MEDIA, K_CORTA] if b else [K_CORTA, K_MEDIA])

    def k_byte(self, v):
        self.ondas += bytes([K_LARGA, K_MEDIA])             # the byte marker
        p = 1
        for i in range(8):                                   # the least significant bit first
            b = v >> i & 1
            self.k_bit(b)
            p ^= b
        self.k_bit(p)                                        # odd parity

    def k_bloque(self, datos, guia, repeticion):
        self.ondas += bytes([K_CORTA]) * guia
        for n in range(9, 0, -1):                            # the countdown: $89..$81, the repeat $09..$01
            self.k_byte(n if repeticion else n | 0x80)
        x = 0
        for v in datos:
            self.k_byte(v)
            x ^= v
        self.k_byte(x)                                       # the checksum: the XOR of the payload
        self.ondas += bytes([K_LARGA, K_CORTA])              # the end of the block

    def kernal(self, nombre, prg):
        """a KERNAL file: a relocatable program (type 1), the PRG's bytes after its load address"""
        ini = prg[0] | prg[1] << 8
        cuerpo = prg[2:]
        fin = ini + len(cuerpo)
        n = nombre.upper().encode("ascii")
        assert len(n) <= 16
        cab = bytes([0x01, ini & 255, ini >> 8, fin & 255, fin >> 8]) + n.ljust(16, b" ")
        cab = cab.ljust(192, b" ")
        self.k_bloque(cab, K_GUIA_PRIMERA, False)
        self.k_bloque(cab, K_GUIA, True)
        self.silencio(20000)                                 # (C: 20 ms between the header and the data)
        self.k_bloque(cuerpo, K_GUIA, False)
        self.k_bloque(cuerpo, K_GUIA, True)
        self.ondas += bytes([K_CORTA]) * 200

    # ---- the turbo blocks (turbo.s) ----
    def t_byte(self, v):
        for i in range(7, -1, -1):                           # the most significant bit first
            self.ondas.append(T_CORTA if v >> i & 1 else T_LARGA)

    def turbo(self, ident, dir_, datos, piloto=160):
        assert 0 < len(datos) < 0x10000 and dir_ + len(datos) <= 0x10000
        for _ in range(piloto):
            self.t_byte(PILOTO)
        self.t_byte(SINCRO)
        for v in (ident, dir_ & 255, dir_ >> 8, len(datos) & 255, len(datos) >> 8):
            self.t_byte(v)
        x = 0
        for v in datos:
            self.t_byte(v)
            x ^= v
        self.t_byte(x)
        self.ondas += bytes([T_CORTA]) * 16                  # a tail: the last bit's wave ends

    def guarda(self, ruta):
        cab = b"C64-TAPE-RAW" + bytes([1, 0, 0, 0]) + struct.pack("<I", len(self.ondas))
        open(ruta, "wb").write(cab + bytes(self.ondas))

    def segundos(self):
        c = 0
        i = 0
        o = self.ondas
        while i < len(o):
            if o[i]:
                c += 8 * o[i]; i += 1
            else:
                c += int.from_bytes(o[i + 1:i + 4], "little"); i += 4
        return c / 985248


def main():
    salida, items = sys.argv[1], sys.argv[2:]
    t = Cinta()
    for it in items:
        p = it.split(":")
        if p[0] == "kernal":
            t.kernal(p[1], open(p[2], "rb").read())
        elif p[0] == "turbo":
            t.turbo(int(p[1], 0), int(p[2], 0), open(p[3], "rb").read(), *(int(x) for x in p[4:5]))
        elif p[0] == "pausa":
            t.silencio(int(float(p[1]) * 985248))
        else:
            sys.exit(f"cinta.py: unknown item {it}")
    t.guarda(salida)
    print(f"{salida}: {len(t.ondas)} waves' bytes, {t.segundos():.1f} s of tape")


if __name__ == "__main__":
    main()
