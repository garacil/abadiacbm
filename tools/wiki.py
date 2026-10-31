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

"""The project's wiki (German: «create a wiki about how the abbey works. all parts with code lines explain
all important things all in english»): doc/wiki/*.md made from the templates doc/wiki/fuentes/*.md, every code
excerpt taken from the sources at the moment of the build, so that no excerpt is copied by hand or goes stale.

A template line

    {{code PATH | START | END}}

becomes the lines of PATH (from the repository's root) from the one START matches (a Python regular expression that
must match exactly one line of the file) to the first line after it that END matches (inclusive), or `+N` lines in
all; a caption names the file and the line numbers, linked to them.  Inside the patterns a `|` is written `\x7c` and a
`}` `\x7d` (the directive's own characters).  An excerpt longer than 80 lines, a pattern that
matches no line or more than one, or a missing file stops everything.

    tools/wiki.py            # writes doc/wiki/*.md
    tools/wiki.py --check    # only checks that every page is up to date (exit 1 if not)"""
import re, sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
FUENTES = RAIZ / "doc" / "wiki" / "fuentes"
SALIDA = RAIZ / "doc" / "wiki"
LENGUAJE = {".s": "asm", ".inc": "asm", ".py": "python", ".c": "c", ".h": "c", ".sh": "bash", ".cfg": "text",
            ".tsv": "text", ".md": "markdown", "": "text"}
MAX_LINEAS = 80
DIRECTIVA = re.compile(r"^\{\{code (?P<ruta>[^|]+?)\s*\|\s*(?P<ini>.+?)\s*\|\s*(?P<fin>.+?)\s*\}\}$")


def falla(pagina, msg):
    sys.exit(f"wiki.py: {pagina}: {msg}")


def extracto(pagina, ruta, ini, fin):
    f = RAIZ / ruta
    if not f.is_file():
        falla(pagina, f"{ruta}: no such file")
    lineas = f.read_text(encoding="utf-8", errors="replace").split("\n")
    try:
        r = re.compile(ini)
        rf = None if fin.startswith("+") else re.compile(fin)
    except re.error as e:
        falla(pagina, f"{ruta}: a bad pattern: {e}")
    hallados = [i for i, l in enumerate(lineas) if r.search(l)]
    if len(hallados) != 1:
        falla(pagina, f"{ruta}: /{ini}/ matches {len(hallados)} lines (it must match one)")
    a = hallados[0]
    if fin.startswith("+"):
        b = a + int(fin[1:]) - 1
    else:
        b = next((i for i in range(a + 1, len(lineas)) if rf.search(lineas[i])), None)
        if b is None:
            falla(pagina, f"{ruta}: /{fin}/ matches no line after line {a + 1}")
    b = min(b, len(lineas) - 1)
    if b - a + 1 > MAX_LINEAS:
        falla(pagina, f"{ruta}: the excerpt from line {a + 1} has {b - a + 1} lines (at most {MAX_LINEAS})")
    profundidad = "../../"
    titulo = f"[`{ruta}`]({profundidad}{ruta}#L{a + 1}-L{b + 1}), lines {a + 1}–{b + 1}"
    codigo = "\n".join(lineas[a:b + 1]).replace("\t", "    ")
    return f"{titulo}:\n\n```{LENGUAJE.get(f.suffix, 'text')}\n{codigo}\n```"


def pagina(fuente):
    salida = []
    for n, l in enumerate(fuente.read_text(encoding="utf-8").split("\n"), 1):
        m = DIRECTIVA.match(l.strip())
        if m:
            salida.append(extracto(f"{fuente.name}:{n}", m["ruta"].strip(), m["ini"], m["fin"]))
        elif l.strip().startswith("{{code"):
            falla(f"{fuente.name}:{n}", "a malformed {{code PATH | START | END}}")
        else:
            salida.append(l)
    aviso = (f"<!-- Made by tools/wiki.py from doc/wiki/fuentes/{fuente.name}: edit the template, not this page. -->\n")
    return aviso + "\n".join(salida)


def main():
    comprueba = "--check" in sys.argv
    viejas = []
    fuentes = sorted(FUENTES.glob("*.md"))
    if not fuentes:
        sys.exit("wiki.py: no templates in doc/wiki/fuentes/")
    for f in fuentes:
        texto = pagina(f)
        destino = SALIDA / f.name
        if comprueba:
            if not destino.exists() or destino.read_text(encoding="utf-8") != texto:
                viejas.append(f.name)
        else:
            destino.write_text(texto, encoding="utf-8")
    if comprueba:
        if viejas:
            sys.exit("wiki.py: out of date: " + ", ".join(viejas))
        print(f"wiki.py: {len(fuentes)} pages up to date")
    else:
        print(f"wiki.py: {len(fuentes)} pages written to doc/wiki/")


if __name__ == "__main__":
    main()
