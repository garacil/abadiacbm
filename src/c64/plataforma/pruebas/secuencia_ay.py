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

"""An AY register log ('TICK REGISTER VALUE' lines, 300 Hz ticks: the GNU build's --ay, galeria_ay) as the
stream the sound test's interrupt plays through plat_psg (t_psg.s), and the log of what it plays.

    secuencia_ay.py LOG OUT.bin [--desde TICK] [--hasta TICK] [--log OUT.txt]

Records: delta (1-255 ticks after the previous record; the first counts from the tick before --desde),
n (0-31), n pairs (register, value); a gap over 255 ticks is a record with delta 255 and no writes; the end is
delta 0.  Writes that change nothing are left out (a register written with the value it has), except the
coarse tone byte after its fine byte changed (plat_psg converts the period at the coarse byte), so the
stream fits in the C64 (the sound is the same).  --log writes the stream back as a log with ticks from 0.
"""
import sys


def main():
    a = sys.argv[1:]
    desde = int(a[a.index("--desde") + 1]) if "--desde" in a else 0
    hasta = int(a[a.index("--hasta") + 1]) if "--hasta" in a else 1 << 30
    regs = [None] * 16
    fino = [False] * 3
    por_tick = {}
    inicial = True
    for linea in open(a[0]):
        t, r, v = map(int, linea.split())
        if t >= hasta:
            break
        if t < desde:                       # before the window: only the state it starts with
            regs[r] = v
            continue
        if inicial and desde:
            inicial = False
            por_tick[0] = [(k, regs[k]) for k in (0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 7) if regs[k] is not None]
        anterior = regs[r]
        regs[r] = v
        if r in (0, 2, 4):
            fino[r // 2] = anterior != v
            if anterior == v:
                continue
        elif r in (1, 3, 5):
            cambia = anterior != v or fino[r // 2]
            fino[r // 2] = False
            if not cambia:
                continue
        elif anterior == v:
            continue
        por_tick.setdefault(t - desde, []).append((r, v))
    out = bytearray()
    previo = -1
    for t in sorted(por_tick):
        while t - previo > 255:
            out += bytes([255, 0])
            previo += 255
        w = por_tick[t]
        while len(w) > 31:
            out += bytes([t - previo, 31]) + bytes(x for rv in w[:31] for x in rv)
            w = w[31:]
            previo = t
            t += 1
        out += bytes([t - previo, len(w)]) + bytes(x for rv in w for x in rv)
        previo = t
    out += bytes([0, 0])
    open(a[1], "wb").write(out)
    if "--log" in a:
        with open(a[a.index("--log") + 1], "w") as f:
            for t in sorted(por_tick):
                for r, v in por_tick[t]:
                    f.write(f"{t} {r} {v}\n")
    print(f"{sum(len(w) for w in por_tick.values())} writes in {len(por_tick)} ticks, {len(out)} bytes")


if __name__ == "__main__":
    main()
