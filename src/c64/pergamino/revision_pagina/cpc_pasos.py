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

"""The CPC's page turn step by step, from cpc_pagina.py's readings (OUTDIR/lecturas.tsv: at every frame top the PC, SP,
BC and the top of the stack).  A reading inside a step's delay (672Ch, called from 660Dh / 662Fh: the return address
6610h / 6632h on top, the step's BC pushed at [SP+4]: B the steps left, C the bands) gives the time the delay began:
the reading's time less (2000 - BC) passes; the pass time is measured from the readings inside 6756h's long delays (the
music's interrupt included).  Fits a step's time as A (first phase) or A' (second phase) + B x its bands (least squares
over the delays' starts), as pagina.s uses it.

    cpc_pasos.py LECTURAS.tsv
"""
import sys
import numpy as np

F = 19968.0                                   # microseconds a frame (312 lines of 64 us)


def main():
    filas = [l.rstrip("\n").split("\t") for l in open(sys.argv[1]) if not l.startswith("#")][1:]   # (my licence header)
    R = [dict(frame=int(r[0]), PC=int(r[1], 16), SP=int(r[2], 16), BC=int(r[3], 16), w0=int(r[5], 16),
              w2=int(r[7], 16)) for r in filas]
    largas = [r for r in R if r["w0"] == 0x6765 and 0x672C <= r["PC"] <= 0x6732]
    a, b = largas[0], largas[-1]               # from the first reading in them to the last (BC counts down, from 0
    vueltas = sum(1 for x, y in zip(largas, largas[1:]) if y["BC"] > x["BC"])        # = 65536 in each delay)
    pasadas = a["BC"] - b["BC"] + 65536 * vueltas
    tiempo = (b["frame"] - a["frame"]) * F
    p = tiempo / pasadas
    print(f"a delay pass (6756h's delays, the music's interrupt included): {p:.3f} us ({pasadas} passes)")
    inicio = {}
    for r in R:
        if 0x672C <= r["PC"] <= 0x6732 and r["w0"] in (0x6610, 0x6632):
            B, C = r["w2"] >> 8, r["w2"] & 255
            k = 0x2D - B + 1 if r["w0"] == 0x6610 else 45 + 0x2E - B + 1
            inicio.setdefault(k, []).append((r["frame"] * F - (2000 - r["BC"]) * p, C))
    bandas = {k: (2 + k if k <= 45 else 47 - (k - 46)) for k in range(1, 92)}
    filas_a, t0 = [], []
    for k in sorted(inicio):
        assert all(c == bandas[k] for _, c in inicio[k])
        filas_a.append([1, sum(1 for j in range(2, k + 1) if j <= 45), sum(1 for j in range(2, k + 1) if j > 45),
                        sum(bandas[j] for j in range(2, k + 1))])
        t0.append(sum(t for t, _ in inicio[k]) / len(inicio[k]) / 1000)
    x, *_ = np.linalg.lstsq(np.array(filas_a, float), np.array(t0), rcond=None)
    _, A1, A2, Bb = x
    res = np.array(filas_a, float) @ x - np.array(t0)
    print(f"steps with a reading in their delay: {len(inicio)} of 91")
    print(f"a step: first phase {A1:.3f} ms + {Bb:.4f} ms a band, second phase {A2:.3f} ms + {Bb:.4f} ms a band "
          f"(residuals: rms {np.sqrt(np.mean(res ** 2)):.2f} ms, largest {np.max(np.abs(res)):.2f} ms)")
    tot = sum((A1 if k <= 45 else A2) + Bb * bandas[k] for k in range(1, 92))
    print(f"the 91 steps by the fit: {tot:.1f} ms")
    c64 = 985.248 / 9.0625                    # espera.s's passes a millisecond
    print(f"in espera.s's passes (9.0625 cycles): {A1 * c64:.0f} + {Bb * c64:.1f} c, {A2 * c64:.0f} + {Bb * c64:.1f} c")


if __name__ == "__main__":
    main()
