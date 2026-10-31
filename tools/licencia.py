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
"""The project's licence header (GNU GPL version 3 or later, as the FSF recommends it) on every source file.

    licencia.py [--comprueba] PATH...     PATH: files or directories (searched recursively)

Each source file gets the header in its own comment syntax: C (.c .h) a /* */ block; ca65 (.s .inc) ';' lines;
Python, shell, Makefiles and ld65 configurations (.cfg) '#' lines, after a '#!' line and a coding line.  A file
that already carries it is left alone (idempotent).  Third-party files keep their own notices and are skipped
(TERCEROS: sim65's 6502 core, zlib licence; superzazu's Z80 core, MIT licence).  The generators of generated
sources call cabecera() so the files they write carry it too.  --comprueba: only list the files without it
(exit 1 if any).
"""
import os
import sys

TEXTO = [
    "abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines",
    "",
    "Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)",
    "",
    "This program is free software: you can redistribute it and/or modify it under the terms of the GNU General",
    "Public License as published by the Free Software Foundation, either version 3 of the License, or (at your",
    "option) any later version.",
    "",
    "This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the",
    "implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License",
    "for more details.",
    "",
    "You should have received a copy of the GNU General Public License along with this program.  If not, see",
    "<https://www.gnu.org/licenses/>.",
]
MARCA = "GNU General Public License as published by the Free Software Foundation"
MARCA2 = "Public License as published by the Free Software Foundation"

# third-party files: their own licences (kept as they are), known by their notices
TERCEROS = ("Ullrich von Bassewitz", "superzazu/z80", "Copyright (c) 2019 Nicolas Allemand")

SALTAR_DIRS = {".git", "__pycache__", ".venv", "herramientas_externas", "original", "cc65"}


def estilo(ruta):
    nombre = os.path.basename(ruta)
    ext = os.path.splitext(nombre)[1]
    if ext in (".c", ".h"):
        return "c"
    if ext in (".s", ".inc"):
        return "asm"
    if ext in (".py", ".sh", ".cfg") or nombre == "Makefile":
        return "hash"
    return None


def cabecera(est):
    """The header as text in a comment style: "c", "asm" or "hash" (for the generators)."""
    if est == "c":
        return "/*\n" + "".join((" * " + l).rstrip() + "\n" for l in TEXTO) + " */\n"
    pre = ";" if est == "asm" else "#"
    return "".join((pre + " " + l).rstrip() + "\n" for l in TEXTO)


TERCEROS_RUTAS = ("z80/z80.c", "z80/z80.h", "m6502/6502.c", "m6502/6502.h")   # z80.c has no notice of its own


def tercero(ruta):
    if ruta.replace(os.sep, "/").endswith(TERCEROS_RUTAS):
        return True
    try:
        cabeza = open(ruta, encoding="utf-8", errors="replace").read(3000)
    except OSError:
        return False
    return any(t in cabeza for t in TERCEROS)


def tiene(texto):
    return MARCA in texto or MARCA2 in texto


def pon(ruta):
    est = estilo(ruta)
    if not est or tercero(ruta):
        return False
    try:
        texto = open(ruta, encoding="utf-8").read()
    except UnicodeDecodeError:
        texto = open(ruta, encoding="latin-1").read()
    if tiene(texto):
        return False
    lineas = texto.splitlines(keepends=True)
    cab = cabecera(est)
    i = 0
    if est == "hash":
        if lineas and lineas[0].startswith("#!"):
            i = 1
        if len(lineas) > i and lineas[i].startswith("#") and "coding" in lineas[i]:
            i += 1
    nuevo = "".join(lineas[:i]) + cab + ("\n" if lineas[i:] and lineas[i].strip() else "") + "".join(lineas[i:])
    with open(ruta, "w", encoding="utf-8") as f:
        f.write(nuevo)
    return True


def recorre(rutas):
    for r in rutas:
        if os.path.isdir(r):
            for base, dirs, ficheros in os.walk(r):
                dirs[:] = sorted(d for d in dirs if d not in SALTAR_DIRS)
                for f in sorted(ficheros):
                    yield os.path.join(base, f)
        else:
            yield r


def main(argv):
    comprueba = "--comprueba" in argv
    rutas = [a for a in argv[1:] if a != "--comprueba"]
    if not rutas:
        sys.exit(__doc__)
    faltan, puestos = [], 0
    for r in recorre(rutas):
        if not estilo(r) or tercero(r):
            continue
        if comprueba:
            try:
                t = open(r, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            if not tiene(t):
                faltan.append(r)
        elif pon(r):
            puestos += 1
    if comprueba:
        for r in faltan:
            print(r)
        sys.exit(1 if faltan else 0)
    print(f"{puestos} files got the header")


if __name__ == "__main__":
    main(sys.argv)
