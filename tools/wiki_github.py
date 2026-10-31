#!/usr/bin/env python3
# abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
# Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
# You should have received a copy of the GNU General Public License along with this program.  If not, see
# <https://www.gnu.org/licenses/>.

"""The wiki of the repository's GitHub page from doc/wiki/*.md and doc/wiki/es/*.md (tools/wiki.py's pages, English
and Spanish, every name distinct: GitHub's wiki names a page by its file name, in one flat list): the links between
pages without their .md or directory, the links into the sources made absolute
(https://github.com/garacil/abadiacbm/blob/main/...), and a sidebar (_Sidebar.md: every page of each language in the
order of its index, Home's and Inicio's tables, and abbeyofcrime.com) and a footer (_Footer.md).  OUT is a clone of the wiki's repository
(git@github.com:garacil/abadiacbm.wiki.git); its .md files are replaced.

    tools/wiki_github.py OUT"""
import re, sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
WIKI = RAIZ / "doc" / "wiki"
REPO = "https://github.com/garacil/abadiacbm/blob/main/"
WEB = "https://abbeyofcrime.com"


def convierte(texto):
    texto = re.sub(r"<!-- Made by tools/wiki\.py[^>]*-->\n", "", texto)
    texto = re.sub(r"\]\(((?:\.\./)+)([^)#\s]+)(#[^)]*)?\)",
                   lambda m: f"]({REPO}{m.group(2)}{m.group(3) or ''})", texto)     # the sources
    texto = re.sub(r"\]\((?:\.\./|es/)?([A-Za-z0-9-]+)\.md(#[^)]*)?\)", lambda m: f"]({m.group(1)}{m.group(2) or ''})",
                   texto)
    return texto


def main():
    out = Path(sys.argv[1])
    if not (out / ".git").exists():
        sys.exit("wiki_github.py: OUT must be a clone of the wiki's repository")
    for f in out.glob("*.md"):
        f.unlink()
    paginas = sorted(WIKI.glob("*.md")) + sorted((WIKI / "es").glob("*.md"))
    nombres = [f.name for f in paginas]
    if len(set(nombres)) != len(nombres):
        sys.exit("wiki_github.py: an English and a Spanish page with the same name")
    for f in paginas:
        (out / f.name).write_text(convierte(f.read_text(encoding="utf-8")), encoding="utf-8")
    lado, orden = [], []
    for indice, titulo in ((WIKI / "Home.md", "Home"), (WIKI / "es" / "Inicio.md", "Inicio")):
        filas = re.findall(r"^\| \[([^\]]+)\]\(([A-Za-z0-9-]+)\.md\)", indice.read_text(encoding="utf-8"), re.M)
        orden += filas
        lado += [f"**[{'English' if titulo == 'Home' else 'Español'}]({titulo})**", ""] + [f"* [{t}]({n})" for t, n in filas] + [""]
    lado += [f"[abbeyofcrime.com]({WEB})"]
    (out / "_Sidebar.md").write_text("\n".join(lado) + "\n", encoding="utf-8")
    (out / "_Footer.md").write_text(f"*La abadía del crimen* for Commodore computers — [abbeyofcrime.com]({WEB}) — "
                                    f"[the repository](https://github.com/garacil/abadiacbm)\n", encoding="utf-8")
    sueltos = [n for f in out.glob("*.md") for n in re.findall(r"\]\(([^):/#]+)(?:#[^)]*)?\)", f.read_text())
               if not (out / (n + ".md")).exists()]
    if sueltos:
        sys.exit("wiki_github.py: links to no page: " + " ".join(sorted(set(sueltos))))
    print(f"wiki_github.py: {len(paginas)} pages, _Sidebar.md ({len(orden)} entries) and _Footer.md in {out}")


main()
