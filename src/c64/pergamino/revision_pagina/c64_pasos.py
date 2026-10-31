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

"""The C64 page turn's time step by step, from a test build of the first stage assembled with MIDE
(`--asm-define MIDE=1`: pagina.s writes the time at each step's start, after its corner and after its wait, and at the
end, from $C000: the interrupt count, CIA 1 and CIA 2 timers A; the probes cost a few dozen cycles each), run in VICE to
the first keyboard read after the turn.  With MIDE=2 (mide.sh 2) the corner is drawn with the interrupt held off: the
last column is then its own cycles (CIA 2), without the music's share.

    c64_pasos.py PRG LBL [OUT.tsv] [--vuelta N]      (the N-th page turn; default the first)

Prints, for each of the 91 steps, its duration and how it is spent (the corner, the wait, the restores), the total,
the steps whose drawing outlasted the CPC's time (no wait left), and the share of the CPU the music interrupt takes
(a loop of known length, timed before the turn).
"""
import os, sys

P = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__)))))
sys.path.insert(0, os.path.join(P, "c64/plataforma/pruebas"))
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from vice_mb import Vice, etiquetas                                  # noqa: E402
from c64_pagina import hasta_punto, CICLOS_TICK, HZ                  # noqa: E402

N = 2 + 91 * 3 + 1
BUCLE = 51359                                 # the cycles of pagina.s's test loop


def main():
    a = sys.argv[1:]
    vuelta = 1
    if "--vuelta" in a:
        i = a.index("--vuelta"); vuelta = int(a[i + 1]); del a[i:i + 2]
    sys.argv[1:] = a
    prg, lbl = sys.argv[1], sys.argv[2]
    e = etiquetas(lbl)
    with Vice(prg, opciones=["-sounddev", "dummy", "-warp"]) as v:
        v.para()
        for _ in range(vuelta):
            hasta_punto(v, e["_pasa_pagina"])
        hasta_punto(v, e["_tecla_espacio"])
        d = v.lee(0xC000, 0xC000 + 8 * N - 1)
    t, t2 = [], []
    leido = lambda h1, lo, h2: h1 * 256 + lo if h1 == h2 or lo < 0x80 else h2 * 256 + lo
    for i in range(N):
        tl, th, h1, lo, h2, g1, glo, g2 = d[8 * i:8 * i + 8]
        t.append((tl | th << 8) * CICLOS_TICK + (CICLOS_TICK - 1 - leido(h1, lo, h2)))
        t2.append(leido(g1, glo, g2))         # CIA 2 timer A, free-running down from $FFFF
    for i in range(1, N):                     # an underflow not yet counted by the interrupt (it was held off)
        while t[i] < t[i - 1]:
            t[i] += CICLOS_TICK
    t0_bucle = t[1] - t[0]
    carga = 1 - BUCLE / t0_bucle
    t = t[2:]
    t2 = t2[2:]
    propio = [(t2[3 * k] - t2[3 * k + 1]) % 65536 for k in range(91)]    # the corner by CIA 2 (MIDE=2: no interrupt)
    filas = []
    for k in range(91):
        a, b, c = t[3 * k], t[3 * k + 1], t[3 * k + 2]
        sig = t[3 * k + 3]
        bandas = 3 + k if k < 45 else 47 - (k - 45)
        filas.append((k + 1, bandas, b - a, c - b, sig - c, sig - a, propio[k]))
    ms = lambda x: x * 1000 / HZ
    print("step bands corner_ms wait_ms restore_ms step_ms corner_cycles_by_CIA2")
    for f in filas:
        print(f"{f[0]:4d} {f[1]:5d} {ms(f[2]):9.2f} {ms(f[3]):7.2f} {ms(f[4]):10.2f} {ms(f[5]):7.2f} {f[6]:8d}")
    tot = t[-1] - t[0]
    print(f"total {tot} cycles, {tot / HZ:.3f} s; steps with less than 1 ms of wait: "
          f"{[f[0] for f in filas if ms(f[3]) < 1]}")
    print(f"the music interrupt's share of the CPU (a loop of {BUCLE} cycles took {t0_bucle} cycles): {100 * carga:.1f} %")
    if len(sys.argv) > 3:
        with open(sys.argv[3], "w") as o:
            o.write("step\tbands\tcorner_cycles\twait_cycles\trestore_cycles\tstep_cycles\tcorner_cycles_cia2\n")
            for f in filas:
                o.write("\t".join(str(x) for x in f) + "\n")


if __name__ == "__main__":
    main()
