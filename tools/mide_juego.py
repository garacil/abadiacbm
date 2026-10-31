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

"""Size of the game's C (src/juego/f_*.c, funciones.c) once compiled by cc65 for the C64, per function.

    mide_juego.py [JUEGO_DIR]

Each file is copied with mide_juego/juego.h (the same interface for cc65: ds[] external, accessors as
macros) and compiled by cc65 -O -Os -Cl -t c64 -DJUEGO_PURO (the game alone, as the pure C build), then assembled with a listing; the CODE bytes between
.proc and .endproc of every function are counted.  Wrappers (w_*), checks (r_*, resultado_*) and the
tables are the hybrid host's, so they are listed apart: the game's code is the rest.  Prints a table
per file, totals, and writes mide_juego.tsv (file, function, bytes, kind) next to JUEGO_DIR.
"""
import os, re, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CC65 = os.path.join(os.path.dirname(HERE), "tools", "terceros", "cc65", "bin")


def tamanos(lst):
    funcs, cur, seg, datos = {}, None, None, {}
    for line in open(lst, errors="replace"):
        m = re.match(r"^([0-9A-F]{6})r? \d\s+(.*)$", line)
        if not m: continue
        body = m.group(2)
        mseg = re.search(r"\.segment\s+\"(\w+)\"", body)
        if mseg: seg = mseg.group(1); continue
        lab = re.search(r"\.proc\s+_(\w+)", body)
        if lab: cur = lab.group(1); funcs.setdefault(cur, 0); continue
        if re.search(r"\.endproc", body): cur = None; continue
        b = re.match(r"((?:[0-9A-Fr]{2} ?){1,4})", body.strip())
        if not b: continue
        n = len(re.findall(r"[0-9A-Fr]{2}", b.group(1)))
        if cur and seg == "CODE": funcs[cur] += n
        elif seg in ("RODATA", "DATA", "BSS"): datos[seg] = datos.get(seg, 0) + n
    return funcs, datos


def clase(nombre):
    return "host" if re.match(r"(w_|r_|resultado_|sin_resultados|compara)", nombre) else "game"


def main():
    J = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "src", "juego"))
    fuentes = sorted(f for f in os.listdir(J) if (f.startswith("f_") or f == "funciones.c") and f.endswith(".c"))
    t = tempfile.mkdtemp()
    shutil.copy(os.path.join(HERE, "mide_juego", "juego.h"), t)
    for f in os.listdir(J):
        if f.endswith(".h") and f != "juego.h": shutil.copy(os.path.join(J, f), t)
    filas, total = [], {"game": 0, "host": 0}
    for f in fuentes:
        shutil.copy(os.path.join(J, f), t)
        s, l = os.path.join(t, f[:-2] + ".s"), os.path.join(t, f[:-2] + ".lst")
        r = subprocess.run([os.path.join(CC65, "cc65"), "-t", "c64", "-O", "-Os", "-Cl", "-DJUEGO_PURO", "-I", t, "-o", s, os.path.join(t, f)],
                           capture_output=True, text=True)
        if r.returncode:
            print(f"{f}: cc65 failed\n" + "\n".join(r.stderr.splitlines()[:15])); continue
        subprocess.run([os.path.join(CC65, "ca65"), "-t", "c64", "-l", l, "-o", os.path.join(t, "x.o"), s], check=True)
        funcs, datos = tamanos(l)
        g = sum(v for k, v in funcs.items() if clase(k) == "game"); h = sum(v for k, v in funcs.items() if clase(k) == "host")
        total["game"] += g; total["host"] += h
        print(f"{f:28} game code {g:6}  host code {h:6}  rodata {datos.get('RODATA', 0):5}  data {datos.get('DATA', 0):4}  bss {datos.get('BSS', 0):4}")
        filas += [(f, k, v, clase(k)) for k, v in funcs.items()]
    print(f"{'total':28} game code {total['game']:6}  host code {total['host']:6}")
    with open(os.path.join(os.path.dirname(J), "data", "mide_juego.tsv"), "w") as o:
        o.write("file\tfunction\tbytes\tkind\n")
        for r in sorted(filas, key=lambda r: -r[2]): o.write("\t".join(map(str, r)) + "\n")
    shutil.rmtree(t)


if __name__ == "__main__":
    main()
