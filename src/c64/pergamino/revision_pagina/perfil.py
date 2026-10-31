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

"""The page turn's own cycles on a 6502 core: builds the first stage with debug labels (as c64/presentacion/pruebas/disco_prueba/construye.sh,
with cl65 -g) into a temporary directory, takes the C64's RAM at the entry of _pasa_pagina from VICE (Xvfb :99, the
binary monitor), builds perfil6502.c with the project's 6502 core (juego/m6502, read only) and runs it.

    perfil.py [STEPS.tsv]
"""
import os, shutil, subprocess, sys, tempfile

D = os.path.dirname(os.path.realpath(__file__))
PERG = os.path.dirname(D)
P = os.path.dirname(os.path.dirname(PERG))
sys.path.insert(0, os.path.join(P, "c64/plataforma/pruebas"))
sys.path.insert(0, D)
from vice_mb import Vice, etiquetas                                  # noqa: E402
from c64_pagina import hasta_punto                                   # noqa: E402


def main():
    t = tempfile.mkdtemp(prefix="perfil_")
    try:
        for f in os.listdir(PERG):
            if f.endswith((".c", ".s", ".h", ".inc")) or f == "cargador.bin":
                shutil.copy(os.path.join(PERG, f), t)
        B = os.path.join(P, "tools/terceros/cc65/bin")
        destino = next("$" + l.split()[1][2:] for l in open(os.path.join(PERG, "cargador.lbl")) if l.split()[2:] == [".inicio"])
        subprocess.run([os.path.join(B, "cl65"), "-t", "c64", "-O", "-Cl", "-g", "--asm-define", f"DESTINO={destino}",
                        "--bin-include-dir", ".", "-o", "pergamino.prg", "-Ln", "pergamino.lbl", "main.c", "espera.s",
                        "pixel.s", "musica.s", "sid.s", "carga.s", "datos.c", "carga.c"], cwd=t, check=True)
        e = etiquetas(os.path.join(t, "pergamino.lbl"))
        with Vice(os.path.join(t, "pergamino.prg"), opciones=["-sounddev", "dummy", "-warp"]) as v:
            v.para()
            hasta_punto(v, e["_pasa_pagina"])
            ram = v.lee(0x0000, 0x7FFF) + v.lee(0x8000, 0xFFFF)
        open(os.path.join(t, "ram.bin"), "wb").write(ram)
        m = os.path.join(P, "juego/m6502")
        subprocess.run(["gcc", "-O2", "-I", m, "-o", os.path.join(t, "perfil6502"), os.path.join(D, "perfil6502.c"),
                        os.path.join(m, "6502.c"), os.path.join(m, "m6502.c")], check=True)
        subprocess.run([os.path.join(t, "perfil6502"), os.path.join(t, "ram.bin"), os.path.join(t, "pergamino.lbl")]
                       + sys.argv[1:], check=True)
    finally:
        shutil.rmtree(t, ignore_errors=True)


if __name__ == "__main__":
    main()
