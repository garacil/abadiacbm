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

"""Measure the host-side cost of VICE's binary monitor operations (not deterministic: wall time only):
a command round trip while stopped, and a stop/resume cycle at a checkpoint hit every ~3279 cycles (the IRQ).
Usage: latencia.py IMGDIR [VICE OPTIONS...]"""
import os, struct, sys, time
D = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, D)
sys.path.insert(0, os.path.join(D, "..", "..", "..", "src", "c64", "plataforma", "pruebas"))   # vice_mb
import vice_mb as V
from medir import banco, escribe_banco, arranca_juego, Medida, segmentos, sitios

imgdir = sys.argv[1]
img = open(os.path.join(imgdir, "juego.bin"), "rb").read()
e = V.etiquetas(os.path.join(imgdir, "juego.lbl"))
s = sitios(img, e, segmentos(os.path.join(imgdir, "juego.map")))
os.environ.setdefault("VICE_DISPLAY", ":90")
with V.Vice(None, ["-sounddev", "dummy", "-warp"] + sys.argv[2:]) as v:
    v.hasta(0xE5CD, limite=120)
    ram = banco(v, "ram")
    escribe_banco(v, ram, 0x0002, img[2:0x10000])
    arranca_juego(v, e["principal_inicio"])
    io = banco(v, "io")
    escribe_banco(v, io, 0xDD04, b"\xff\xff\xff\xff"); escribe_banco(v, io, 0xDD0F, b"\x51"); escribe_banco(v, io, 0xDD0E, b"\x11")
    m = Medida(v, io)
    t0 = time.time()
    for _ in range(300):
        m.tiempo()
    print(f"round trip (MEM_GET while stopped): {(time.time() - t0) / 300 * 1000:.2f} ms")
    t0 = time.time()
    for _ in range(300):
        v.registros()
    print(f"round trip (REGISTERS_GET): {(time.time() - t0) / 300 * 1000:.2f} ms")
    m.punto("IRQ", s["IRQ"])
    t0 = time.time()
    for _ in range(300):
        m.sigue()
    print(f"stop/resume at the IRQ (every 3279 cycles), no other command: {(time.time() - t0) / 300 * 1000:.2f} ms")
    t0 = time.time()
    for _ in range(300):
        m.sigue(); m.tiempo()
    print(f"stop/resume + one MEM_GET: {(time.time() - t0) / 300 * 1000:.2f} ms")
    n = m.punto("RTI", s["RTI"])
    t0 = time.time()
    for _ in range(300):
        m.sigue(); m.tiempo()
    print(f"stop/resume + MEM_GET with the RTI stop too (2 stops a tick, ~90 cycles apart): {(time.time() - t0) / 300 * 1000:.2f} ms per stop")
