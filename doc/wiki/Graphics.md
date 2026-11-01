<!-- Made by tools/wiki.py from doc/wiki/fuentes/Graphics.md: edit the template, not this page. -->
<!--
  abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines

  Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)

  This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
  option) any later version.

  This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
  implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
  for more details.

  You should have received a copy of the GNU General Public License along with this program.  If not, see
  <https://www.gnu.org/licenses/>.
-->

# Graphics and tools

[Home](Home.md) · previous: [Building and certification](Building.md) · next: [My tools](Tools.md)

## From the CPC's pixels to the C64's

The CPC game draws in mode 1: four colours, 320 pixels a line.  The C64's multicolour bitmap also has four colours a
cell, but 160 pixels a line: each pair of CPC pixels must become one C64 pixel.  For a tile or a wall it hardly
matters; for a face 5 pixels wide it decides whether the eyes survive.  The conversion is a program,
`tools/c64_graficos.py`, and its rules were chosen by looking at the result on the screen:

[`tools/c64_graficos.py`](../../tools/c64_graficos.py#L55-L75), lines 55–75:

```python
The pixel rule: a CPC mode 1 byte (4 pixels) becomes one C64 multicolour nibble (2 pixels), each pair of
CPC pixels one C64 pixel, pen -> bit pair BITS (c64_sala.py: pen 3 = 00 = $D021, pen 0 = 01, pen 1 = 10,
pen 2 = 11).  Which pixel of a pair survives:
  sim      the door and the objects: the pen first in 1, 2, 3, 0 (orange, yellow, black, then transparent pen 0).
           Mirror-symmetric and per byte, so the game's in-place flip of the door gives exactly the conversion of
           the flipped CPC graphic.
  trazos   Guillermo, Adso, the monks' faces and robes (c64_mitad.py: the same shape as the PC
           EGA / CPC drawing): per line, the least-cost choice of one pixel of each pair, where losing a stroke of
           the drawing (a run of any pen that is darker or lighter than its neighbours, an inner gap) costs much,
           losing a one-pixel step of shading costs little, and moving an edge costs little; the silhouette grows
           outward; ties go with the line above.  Not mirror-symmetric: the game flips the C64 data in place
           (faces, Guillermo, Adso) or reads the robes backwards, and the host's checks take a flipped unit from the
           image (src/juego/m6502/sombra6502.c, convierte).  It replaces the rules aislado and the hand retouches of
           src/c64/datos/retoques64.txt (kept, no longer applied).  Over the rule, the lines edited by hand with
           tools/c64_editor.py (src/c64/datos/editados64.txt, same format: the graphic's CPC address, the
           line, one character a C64 pixel) replace the rule's lines of Guillermo, Adso, the faces, the robes and
           the tiles 01h-D9h but the object slots (the tile's key: its tape address 8300h + 32n; normal build only,
           not --hw); a line of the wrong length, outside its graphic or at an unknown address
           stops the build.  Another file: the environment variable C64_EDITADOS.
  detalle  tiles (per tile), the roman numerals: c64_sala.py's rule (right pixel, keeps one-pixel
           vertical lines and fluting).
```

The colours are the CPC version's palettes (not the PC's), mapped by hue to the nearest C64 colours
(`src/c64/datos/paleta.tsv`).

## Hand edits

Over the rules, the lines retouched by hand replace the converted ones.  `tools/c64_editor.py` (PySide6) shows each
character's frames, the monks' faces and robes, and the tiles, the PC EGA graphic beside the C64 one, and edits them
pixel by pixel: a blinking pixel cursor, the colour chosen with the digits, SPACE paints, O P Q A move; undo and redo;
the walking cycle animated as the game plays it, at a chosen speed.  It writes `src/c64/datos/editados64.txt`, one line
per edited graphic line, which every build applies; a line of the wrong length or at an address that cannot be
edited stops the build.  The tiles of the 64ks and the 128ks are the same; on the C128 the heads differ (their black
strokes go to the hardware sprites), and the C128's new tiles (the full game's 32 new images) are converted by the same
rule.

## The C128's heads

With `--c128` the conversion keeps the heads' black strokes apart: the multicolour head keeps only the fills, and the
black of each of the 26 heads (Guillermo's and Adso's 12 frames, the monks' 14 faces) is stored at the PC's full width,
one bit a pixel, for the VIC-II's hires sprites (see [The Commodore 128](C128.md)).

## Other tools

All my tools are listed in `doc/HERRAMIENTAS.md`, and the main ones explained in [My tools](Tools.md).

| Tool | What |
|---|---|
| `tools/c64_compara_pc.py` | sheets comparing each graphic: the PC EGA one, the C64 one, the rules side by side, with measures of the strokes lost |
| `tools/mapa_por_codigo.py`, `tools/compara_datos_pc.py`, `tools/difiere_funciones.py`, `tools/par_funcion.py` | the 64 KiB game against the full game (the PC version): data by name, functions by code, side by side |
| `tools/datos128.py`, `tools/baldosas128.py` | the full game's map and tiles for the C128, from the PC version's data |
| `tools/punteros64.py`, `tools/inventario64.py` | the pointer fields inside the data; the inventory of what the game reads |
| `tools/cpc_velocidad.py` | the CPC game's real speed in Caprice32, for the speed comparisons |
| `tools/guion_azar.py` | random key scripts for the certification sessions |
| `tools/genera_todo.sh`, `tools/genera_cinta.sh` | the releases in one go |
| `tools/sincroniza.sh` | the project copied to my other machines, the graphic edits compared first |
| `tools/wiki.py` | this wiki: every code excerpt taken from the sources when it is built |
| `src/c64/mapa/hoja64.py`, `mapa64.py` | a sheet of every C64 graphic, and the whole abbey's map as the C64 draws it |

## This wiki

The pages in `doc/wiki/` are made by `tools/wiki.py` from the templates in `doc/wiki/fuentes/`: a line
`{{code PATH | START | END}}` becomes the lines of PATH from the one that matches START to the one that matches END,
with the file and the line numbers.  `tools/wiki.py --check` tells whether a page no longer matches the sources.
