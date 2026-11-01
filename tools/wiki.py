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

"""My wiki of the project, how the abbey works, part by part, with its code: doc/wiki/*.md made from the templates
doc/wiki/fuentes/*.md, every code excerpt taken from the sources at the moment of the build, so that no excerpt is
copied by hand or goes stale.
The same for the Spanish wiki: doc/wiki/es/*.md from doc/wiki/es/fuentes/*.md (its captions in Spanish).

A template line

    {{code PATH | START | END}}

becomes the lines of PATH (from the repository's root) from the one START matches (a Python regular expression that
must match exactly one line of the file) to the first line after it that END matches (inclusive), or `+N` lines in
all; a caption names the file and the line numbers, linked to them.  Inside the patterns a `|` is written `\x7c` and a
`}` `\x7d` (the directive's own characters).  An excerpt longer than 80 lines, a pattern that
matches no line or more than one, or a missing file stops everything.

    {{rutinas PATH}}

becomes a table of the routines of PATH: every `.proc NAME` and every label at the start of a line with a comment
just above it, with the address of the original's function when that comment starts with one (`; 5060 ...`,
`; ---- 20BE ...`), each linked to its line.

    tools/wiki.py            # writes doc/wiki/*.md and doc/wiki/es/*.md
    tools/wiki.py --check    # only checks that every page is up to date (exit 1 if not)"""
import re, sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
FUENTES = RAIZ / "doc" / "wiki" / "fuentes"
SALIDA = RAIZ / "doc" / "wiki"
# each wiki: its templates, its pages, and its words (the caption's "lines", the routines' table, the warning)
IDIOMAS = [dict(fuentes=FUENTES, salida=SALIDA, lineas="lines", tabla=("Original", "Routine", "Line"),
                aviso="<!-- Made by tools/wiki.py from doc/wiki/fuentes/{n}: edit the template, not this page. -->\n"),
           dict(fuentes=SALIDA / "es" / "fuentes", salida=SALIDA / "es", lineas="líneas",
                tabla=("Original", "Rutina", "Línea"),
                aviso="<!-- Hecha por tools/wiki.py desde doc/wiki/es/fuentes/{n}: se edita la plantilla, no esta "
                      "página. -->\n")]
LENGUAJE = {".s": "asm", ".inc": "asm", ".py": "python", ".c": "c", ".h": "c", ".sh": "bash", ".cfg": "text",
            ".tsv": "text", ".md": "markdown", "": "text"}
MAX_LINEAS = 80
DIRECTIVA = re.compile(r"^\{\{code (?P<ruta>[^|]+?)\s*\|\s*(?P<ini>.+?)\s*\|\s*(?P<fin>.+?)\s*\}\}$")
RUTINAS = re.compile(r"^\{\{rutinas (?P<ruta>[^}]+?)\s*\}\}$")


def falla(pagina, msg):
    sys.exit(f"wiki.py: {pagina}: {msg}")


def extracto(pagina, ruta, ini, fin, idioma):
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
    profundidad = "../" * len(idioma["salida"].relative_to(RAIZ).parts)
    titulo = f"[`{ruta}`]({profundidad}{ruta}#L{a + 1}-L{b + 1}), {idioma['lineas']} {a + 1}–{b + 1}"
    codigo = "\n".join(lineas[a:b + 1]).replace("\t", "    ")
    return f"{titulo}:\n\n```{LENGUAJE.get(f.suffix, 'text')}\n{codigo}\n```"


def rutinas(pagina, ruta, idioma):
    """the table of the routines of ruta (see the module's text)"""
    f = RAIZ / ruta
    if not f.is_file():
        falla(pagina, f"{ruta}: no such file")
    lineas = f.read_text(encoding="utf-8", errors="replace").split("\n")
    profundidad = "../" * len(idioma["salida"].relative_to(RAIZ).parts)
    filas = []
    for i, l in enumerate(lineas):
        m = re.match(r"^\.proc\s+([A-Za-z_][A-Za-z_0-9]*)", l) or re.match(r"^([A-Za-z_][A-Za-z_0-9]*):", l)
        if not m or i == 0 or not lineas[i - 1].startswith(";"):
            continue
        k = i - 1
        while k > 0 and lineas[k - 1].startswith(";"):
            k -= 1
        d = re.match(r"^;\s*(?:-+\s*)?([0-9A-F]{4})\b", lineas[k])
        filas.append(f"| {d.group(1) + 'h' if d else '—'} | [`{m.group(1)}`]({profundidad}{ruta}#L{i + 1}) | {i + 1} |")
    if not filas:
        falla(pagina, f"{ruta}: no routine with a comment above it")
    o, r_, n = idioma["tabla"]
    return "\n".join([f"| {o} | {r_} | {n} |", "|---|---|---|"] + filas)


def pagina(fuente, idioma):
    salida = []
    for n, l in enumerate(fuente.read_text(encoding="utf-8").split("\n"), 1):
        m = DIRECTIVA.match(l.strip())
        mr = RUTINAS.match(l.strip())
        if m:
            salida.append(extracto(f"{fuente.name}:{n}", m["ruta"].strip(), m["ini"], m["fin"], idioma))
        elif mr:
            salida.append(rutinas(f"{fuente.name}:{n}", mr["ruta"].strip(), idioma))
        elif l.strip().startswith(("{{code", "{{rutinas")):
            falla(f"{fuente.name}:{n}", "a malformed {{code PATH | START | END}} or {{rutinas PATH}}")
        else:
            salida.append(l)
    return idioma["aviso"].format(n=fuente.name) + "\n".join(salida)


def main():
    comprueba = "--check" in sys.argv
    viejas, total = [], 0
    for idioma in IDIOMAS:
        fuentes = sorted(idioma["fuentes"].glob("*.md"))
        if not fuentes:
            sys.exit(f"wiki.py: no templates in {idioma['fuentes'].relative_to(RAIZ)}/")
        for f in fuentes:
            texto = pagina(f, idioma)
            destino = idioma["salida"] / f.name
            if comprueba:
                if not destino.exists() or destino.read_text(encoding="utf-8") != texto:
                    viejas.append(str(destino.relative_to(RAIZ)))
            else:
                destino.write_text(texto, encoding="utf-8")
        total += len(fuentes)
    if comprueba:
        if viejas:
            sys.exit("wiki.py: out of date: " + ", ".join(viejas))
        print(f"wiki.py: {total} pages up to date")
    else:
        print(f"wiki.py: {total} pages written to doc/wiki/ and doc/wiki/es/")


if __name__ == "__main__":
    main()
