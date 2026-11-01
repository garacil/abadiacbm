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

"""Join the chunks of medir.py (OUT/trozos/tAAAA_BBBB/) into one run: OUT/final/{ciclos,fases,ticks,psg}.tsv.
Checks that the chunks are contiguous (frame numbers) and seamless (a chunk's first frame starts at the cycle
where the previous chunk's last frame ended), and renumbers the ticks globally.  Deterministic.
Usage: une.py OUT  (the chunks' directories are taken in name order)"""
import os, sys

out = sys.argv[1]
trozos = sorted(d for d in os.listdir(os.path.join(out, "trozos")) if os.path.isdir(os.path.join(out, "trozos", d)))
os.makedirs(os.path.join(out, "final"), exist_ok=True)
tablas = {k: [] for k in ("ciclos", "fases", "ticks", "psg")}
cab = {}
ultimo_frame, fin_anterior, n_tick = 0, None, 0
for d in trozos:
    base = os.path.join(out, "trozos", d)
    filas = {}
    for k in tablas:
        with open(os.path.join(base, k + ".tsv")) as f:
            lineas = [l.rstrip("\n").split("\t") for l in f]
        cab[k] = lineas[0]
        filas[k] = lineas[1:]
    fases = filas["fases"]
    primero, ultimo = int(fases[0][0]), int(fases[-1][0])
    assert primero == ultimo_frame + 1, f"{d}: frames not contiguous ({primero} after {ultimo_frame})"
    if fin_anterior is not None:
        assert int(fases[0][1]) == fin_anterior, f"{d}: starts at {fases[0][1]}, the previous chunk ended at {fin_anterior}"
    fin_anterior = int(fases[-1][1]) + int(fases[-1][2])
    ultimo_frame = ultimo
    tablas["ciclos"] += filas["ciclos"]
    tablas["fases"] += fases
    desplaza = n_tick
    for r in filas["ticks"]:
        r[0] = str(int(r[0]) + desplaza)
        tablas["ticks"].append(r)
    for r in filas["psg"]:
        r[0] = str(int(r[0]) + desplaza) if int(r[0]) else "0"
        tablas["psg"].append(r)
    n_tick += len(filas["ticks"])
    print(f"{d}: frames {primero}-{ultimo}, {len(filas['ticks'])} ticks, {len(filas['psg'])} SID writes")
# ciclos.tsv as arranca.py writes it (cycles_of_frame from the joined list)
prev = 0
for r in tablas["ciclos"]:
    t = int(r[1]); r[2] = str(t - prev); prev = t
for k, filas in tablas.items():
    with open(os.path.join(out, "final", k + ".tsv"), "w") as o:
        o.write("\t".join(cab[k]) + "\n")
        for r in filas:
            o.write("\t".join(r) + "\n")
print(f"joined: frames 1-{ultimo_frame}, {n_tick} ticks")
