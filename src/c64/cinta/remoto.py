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

"""A VICE already running on another machine, driven through its binary monitor (as vice_mb.Vice drives the one it
starts): for sessions watched on a desktop screen (c64/cinta/sesion_final.py).  The emulator is started
there with `-binarymonitor -binarymonitoraddress ip4://<its VPN address>:<port>`; this neither starts nor ends it."""
import os, socket, sys
D = os.path.dirname(os.path.realpath(__file__))
P = os.path.dirname(os.path.dirname(D))
sys.path.insert(0, os.path.join(P, "c64", "plataforma", "pruebas"))
import vice_mb as V                                   # noqa: E402


class Remoto(V.Vice):
    def __init__(self, maquina, puerto):
        self.puerto = puerto
        self.proc = None
        self.casa = None
        self.registro = None
        self.s = socket.create_connection((maquina, puerto), timeout=30)
        self.s.settimeout(None)
        self.id = 0
        self.eventos = []
        self.parado = False
        self.pc = None
        self.paradas = 0
        self.golpes = set()
        self.jams = 0

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        try:
            self.orden(V.CMD_EXIT)                      # the emulator goes on by itself
        except Exception:
            pass
        self.s.close()
        return False
