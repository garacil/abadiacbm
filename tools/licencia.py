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
"""My licence header (GNU GPL version 3 or later, as the FSF recommends it) on every text file of the project.

    licencia.py [--comprueba] PATH...     PATH: files or directories (searched recursively)
    licencia.py [--comprueba] --git       every text file the repository tracks

Each text file gets the header in its own comment syntax: C and Java (.c .h .java) a /* */ block; ca65 and the Z80
listings (.s .inc .asm .lbl, .s.pendiente) ';' lines; Python, shell, Makefiles, ld65 configurations, plain text and
the data files (.py .sh .cfg .txt .tsv .map .dump .patch .gitignore) '#' lines, after a '#!' line and a coding line;
Markdown (.md) an HTML comment, which GitHub does not show; DOS batch files (.bat) REM lines; JSON, which has no
comments, a first key "_licencia" with the header's lines.  The files that hold something of the original game
(the Z80 listings of its code, its music recorded, my translation of its texts: ORIGINAL) get the header's other
form, which says so: what they hold of the original is the original's, not under my licence.  A file that already
carries a header is left alone (idempotent).  Third-party files keep their own notices and are skipped (TERCEROS:
sim65's 6502 core and cc65's licence, zlib; superzazu's Z80 core, MIT; Magnus Lind's Exomizer decruncher; the GPL's
text; archive.org's description of the original tape; Ghidra's own project files), and so are the files that are
data loaded as they are (.bin).  The release READMEs (src/c64/video/entrega/README*.txt) are signed at their end
and travel in the download zips: they are left as they are.  The generators of generated files call cabecera() so
the files they write carry it too.  --comprueba: only list the files without it (exit 1 if any).

The data files' readers skip the header: its lines begin with the format's comment character ('#' or ';'), at the
top of the file.
"""
import json
import os
import subprocess
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
TEXTO_ORIGINAL = [
    "abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines",
    "",
    "Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)",
    "",
    "I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its",
    "code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:",
    "you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the",
    "Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY",
    "WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).",
]
MARCA = "GNU General Public License as published by the Free Software Foundation"
MARCA2 = "Public License as published by the Free Software Foundation"
MARCA3 = "I made this file from the original game, La Abad"

# the files that hold something of the original game: the header's other form
ORIGINAL = ("data/cpc64/listado/", "data/cpc64/perg_6000.asm", "data/cpc64/final/ay.txt", "data/cpc64/perg_ay.txt",
            "data/cpc64/diferencias_codigo.txt", "data/cpc64/dif_total.txt", "src/c64/ingles/frases_en.txt",
            "src/c64/ingles/pergamino_final_en.txt", "src/c64/ingles/pergamino_intro_en.txt")

# third-party files: their own licences (kept as they are), known by their notices
TERCEROS = ("Ullrich von Bassewitz", "superzazu/z80", "Copyright (c) 2019 Nicolas Allemand", "Magnus Lind")
TERCEROS_RUTAS = ("z80/z80.c", "z80/z80.h", "m6502/6502.c", "m6502/6502.h", "COPYING", "m6502/LICENSE.cc65",
                  "z80/LICENSE", "archive.org/amstrad_abadia_del_crimen_64_meta.xml")
TAL_CUAL = ("src/c64/video/entrega/README.txt", "src/c64/video/entrega/README128.txt",
            "src/c64/video/entrega/README500.txt")   # in the download zips: signed at their end

SALTAR_DIRS = {".git", "__pycache__", ".venv", "herramientas_externas", "cc65", "proyecto"}
DATOS = (".txt", ".tsv", ".map", ".dump", ".lbl", ".asm", ".patch")
HAZ = (".py", ".sh", ".cfg", ".txt", ".tsv", ".map", ".dump", ".patch", ".conf", ".mk")


def estilo(ruta):
    nombre = os.path.basename(ruta)
    ext = os.path.splitext(nombre)[1]
    if ext in (".c", ".h", ".java"):
        return "c"
    if ext in (".s", ".inc", ".asm", ".lbl") or nombre.endswith(".s.pendiente"):
        return "asm"
    if ext in HAZ or nombre in ("Makefile", ".gitignore"):
        return "hash"
    if ext == ".md":
        return "html"
    if ext == ".bat":
        return "rem"
    if ext == ".json":
        return "json"
    return None


def variante(ruta):
    r = ruta.replace(os.sep, "/")
    return TEXTO_ORIGINAL if any(o in r for o in ORIGINAL) else TEXTO


def cabecera(est, texto=TEXTO):
    """The header as text in a comment style: "c", "asm", "hash", "html" or "rem" (for the generators); texto: TEXTO
    or TEXTO_ORIGINAL."""
    if est == "c":
        return "/*\n" + "".join((" * " + l).rstrip() + "\n" for l in texto) + " */\n"
    if est == "html":
        return "<!--\n" + "".join(("  " + l).rstrip() + "\n" for l in texto) + "-->\n"
    if est == "rem":
        return "".join(("REM " + l).rstrip() + "\r\n" for l in texto)
    pre = ";" if est == "asm" else "#"
    return "".join((pre + " " + l).rstrip() + "\n" for l in texto)


def tercero(ruta):
    r = ruta.replace(os.sep, "/")
    if r.endswith(TERCEROS_RUTAS) or r.endswith(TAL_CUAL) or r.endswith(".bin"):
        return True
    try:
        cabeza = open(ruta, encoding="utf-8", errors="replace").read(3000)
    except OSError:
        return False
    return any(t in cabeza for t in TERCEROS)


def tiene(texto):
    cabeza = texto[:6000]
    return MARCA in cabeza or MARCA2 in cabeza or MARCA3 in cabeza or '"_licencia"' in cabeza


def es_texto(ruta):
    try:
        b = open(ruta, "rb").read(8192)
    except OSError:
        return False
    return b"\0" not in b


def pon(ruta):
    est = estilo(ruta)
    if not est or tercero(ruta) or not es_texto(ruta):
        return False
    try:
        texto = open(ruta, encoding="utf-8", newline="").read()
        cod = "utf-8"
    except UnicodeDecodeError:
        texto = open(ruta, encoding="latin-1", newline="").read()
        cod = "latin-1"
    if tiene(texto):
        return False
    texto_cab = variante(ruta)
    if est == "json":
        datos = json.loads(texto)
        nuevo = json.dumps({"_licencia": texto_cab, **datos}, indent=2, ensure_ascii=False) + "\n"
    else:
        lineas = texto.splitlines(keepends=True)
        cab = cabecera(est, texto_cab)
        if cod == "latin-1":
            cab = cab.replace("Germán", "German").replace("Abadía", "Abadia")
        i = 0
        if est == "hash":
            if lineas and lineas[0].startswith("#!"):
                i = 1
            if len(lineas) > i and lineas[i].startswith("#") and "coding" in lineas[i]:
                i += 1
        sep = "\r\n" if est == "rem" or (lineas and lineas[0].endswith("\r\n")) else "\n"
        cab = cab.replace("\r\n", "\n").replace("\n", sep)             # the file's own line ends
        blanca = sep if lineas[i:] and lineas[i].strip() and not ruta.endswith(DATOS) else ""   # (data: no blank line,
        nuevo = "".join(lineas[:i]) + cab + blanca + "".join(lineas[i:])                        #  their readers skip '#')
    with open(ruta, "w", encoding=cod, newline="") as f:
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


def seguidos():
    """the files the repository tracks (run from anywhere inside it)"""
    raiz = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=True).stdout.strip()
    nombres = subprocess.run(["git", "-C", raiz, "ls-files", "-z"], capture_output=True, check=True).stdout.split(b"\0")
    return [os.path.join(raiz, n.decode()) for n in nombres if n and os.path.isfile(os.path.join(raiz, n.decode()))]


def main(argv):
    comprueba = "--comprueba" in argv
    rutas = [a for a in argv[1:] if a not in ("--comprueba", "--git")]
    if "--git" in argv:
        rutas = [r for r in seguidos() if not set(r.split(os.sep)) & SALTAR_DIRS]
    if not rutas:
        sys.exit(__doc__)
    faltan, puestos = [], 0
    for r in recorre(rutas):
        if not estilo(r) or tercero(r) or not es_texto(r):
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
