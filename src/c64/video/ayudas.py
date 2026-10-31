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

"""VICE helpers of the video session (sesion64.py): the same as the separate English disk's test
(c64/ingles/pruebas/prueba_en.py, used by the pilot's session then; that edition was removed), kept here
so the session needs nothing else."""
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "plataforma" / "pruebas"))
import vice_mb as V                                                  # noqa: E402

CMD_BANKS, CMD_TECLADO = 0x82, 0x72


def bancos(v):
    _, c = v.orden(CMD_BANKS)
    n = struct.unpack("<H", c[:2])[0]
    out, k = {}, 2
    for _ in range(n):
        tam = c[k]
        bid = struct.unpack("<H", c[k + 1:k + 3])[0]
        nlen = c[k + 3]
        out[c[k + 4:k + 4 + nlen].decode()] = bid
        k += 1 + tam
    return out


def lee(v, banco, ini, fin):
    out = b""
    while ini <= fin:
        f = min(fin, ini + 0x3FFF)
        _, c = v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, ini, f, 0, banco))
        out += c[2:2 + struct.unpack("<H", c[:2])[0]]
        ini = f + 1
    return out


def escribe(v, texto):
    """text into the KERNAL's keyboard buffer (VICE's keyboard feed)"""
    t = texto.encode("ascii")
    v.orden(CMD_TECLADO, bytes([len(t)]) + t)


def corre_hasta(v, dir, golpes=1, limite=900):
    """run until the checkpoint at dir has been hit `golpes` times (the PC is then dir)"""
    num = v.punto(dir, temporal=False)
    try:
        for _ in range(golpes):
            v.golpes.discard(num)
            v.orden(V.CMD_EXIT)
            v.s.settimeout(limite)
            while num not in v.golpes:
                v._respuesta()
            v.s.settimeout(None)
        v.para()
        pc = v.registros()[3]
        if pc != dir:
            raise RuntimeError(f"stopped at {pc:04X}, not at {dir:04X}")
    finally:
        v.orden(V.CMD_CHECKPOINT_DELETE, struct.pack("<I", num))


class Puntos:
    """several checkpoints at once: siguiente() runs until one of them is hit and returns its address"""
    def __init__(self, v):
        self.v, self.num = v, {}

    def pon(self, dir):
        if dir not in self.num.values():
            self.num[self.v.punto(dir, temporal=False)] = dir

    def quita(self, dir):
        for n, d in list(self.num.items()):
            if d == dir:
                self.v.orden(V.CMD_CHECKPOINT_DELETE, struct.pack("<I", n))
                del self.num[n]

    def siguiente(self, limite=900):
        v = self.v
        v.golpes.clear()
        v.orden(V.CMD_EXIT)
        v.s.settimeout(limite)
        try:
            while not v.golpes & self.num.keys():
                v._respuesta()
        finally:
            v.s.settimeout(None)
        v.para()
        pc = v.registros()[3]
        if pc not in self.num.values():
            raise RuntimeError(f"stopped at {pc:04X}, not at a checkpoint")
        return pc

    def fuera(self):
        for n in list(self.num):
            self.v.orden(V.CMD_CHECKPOINT_DELETE, struct.pack("<I", n))
        self.num = {}


def escribe_banco(v, banco, ini, datos):
    v.orden(V.CMD_MEM_SET, struct.pack("<BHHBH", 0, ini, ini + len(datos) - 1, 0, banco) + bytes(datos))
