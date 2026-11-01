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

"""Measure the cycles the VIC-II steals from the CPU (its bad lines) in VICE, with checkpoint stops only (exact,
as the whole measurement): in frame N's frame wait (LDA zp 3 / CMP zp 3 / BCS 2 / JMP 3 = 11 cycles a pass, no
memory writes) the checkpoint at the loop head stops at every pass; a pass that takes more than 11 cycles was
stalled by the VIC-II (the raster line, VIC $D012 with $D011 bit 7, is read at the stop).  A pass with a 300 Hz
interrupt inside is left out (the interrupt is run to its RTI with checkpoints).  Deterministic.  Prints the stalls
per raster line, the stolen cycles per 19656-cycle video frame (PAL: 312 lines x 63 cycles) and the share of the
clock.  Usage: prueba_vic.py IMGDIR N MAXPASSES"""
import os, struct, sys
D = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, D)
sys.path.insert(0, os.path.join(D, "..", "..", "..", "src", "c64", "plataforma", "pruebas"))   # vice_mb
import vice_mb as V
from medir import arranque, Medida, segmentos, sitios

imgdir, N, S = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
img = open(os.path.join(imgdir, "juego.bin"), "rb").read()
e = V.etiquetas(os.path.join(imgdir, "juego.lbl"))
s = sitios(img, e, segmentos(os.path.join(imgdir, "juego.map")))
PASO = 11
os.environ.setdefault("VICE_DISPLAY", ":90")
with V.Vice(None, ["-sounddev", "dummy", "-warp", "+VICIIvsync"]) as v:
    io = arranque(v, img, e)
    m = Medida(v, io)
    m.punto("FRAME", s["FRAME"])
    frame = 0
    while frame < N - 1:
        pc, _ = m.sigue()
        if pc == s["FRAME"]:
            frame += 1
    m.punto("ESPERA", s["ESPERA"]); m.punto("IRQ", s["IRQ"]); m.punto("RTI", s["RTI"]); m.punto("SALIDA", s["SALIDA"])
    pc, _ = m.sigue()
    while pc != s["ESPERA"]:
        pc, _ = m.sigue()
    def raster():
        _, c = v.orden(V.CMD_MEM_GET, struct.pack("<BHHBH", 0, 0xD011, 0xD012, 0, io))
        return c[3] | ((c[2] & 0x80) << 1)
    t_ini = m.tiempo(); t = t_ini
    robados = 0; paradas = {}; pasos = 0; en_irq = 0; irq_dentro = False; limpio = 0
    while pasos < S:
        pc, _ = m.sigue()
        if pc == s["IRQ"]:
            irq_dentro = True
            en_irq += 1
            continue
        if pc == s["RTI"]:
            continue
        if pc == s["SALIDA"]:
            break
        assert pc == s["ESPERA"], hex(pc)
        t2 = m.tiempo()
        pasos += 1
        if not irq_dentro:
            d = t2 - t - PASO
            limpio += PASO
            if d:
                robados += d
                r = raster()
                paradas[r] = paradas.get(r, 0) + d
        irq_dentro = False
        t = t2
    total = t - t_ini
    lineas = sorted(paradas)
    print(f"frame {N}: {pasos} passes of the wait loop over {total} clock cycles, {en_irq} interrupts met (their passes left out: {limpio} clean loop cycles + {robados} stolen in the passes kept)")
    print("stalls by raster line (line: stolen cycles): " + " ".join(f"${r:03X}:{c}" for r, c in sorted(paradas.items())))
    print(f"stalled raster lines: {len(lineas)} ({', '.join('$%03X' % r for r in lineas[:30])}{' ...' if len(lineas) > 30 else ''}); stolen per stalled line: min {min(paradas.values())}, max {max(paradas.values())}")
    print(f"stolen cycles: {robados} = {100 * robados / (limpio + robados):.2f} % of the clock in the passes kept; per 19656-cycle video frame: {robados * 19656 / (limpio + robados):.0f}")
