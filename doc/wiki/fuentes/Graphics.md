# Graphics and tools

[Home](Home.md) · previous: [Building and certification](Building.md) · next: [Glossary](Glossary.md)

## From the CPC's pixels to the C64's

The CPC game draws in mode 1: four colours, 320 pixels a line.  The C64's multicolour bitmap also has four colours a
cell, but 160 pixels a line: each pair of CPC pixels must become one C64 pixel.  For a tile or a wall it hardly
matters; for a face 5 pixels wide it decides whether the eyes survive.  The conversion is a program,
`tools/c64_graficos.py`, and its rules were chosen by looking at the result on the screen:

{{code tools/c64_graficos.py | ^The pixel rule: a CPC mode 1 byte | ^           vertical lines and fluting\)\.}}

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

| Tool | What |
|---|---|
| `tools/c64_compara_pc.py` | sheets comparing each graphic: the PC EGA one, the C64 one, the rules side by side, with measures of the strokes lost |
| `tools/mapa_por_codigo.py`, `tools/compara_datos_pc.py`, `tools/difiere_funciones.py`, `tools/par_funcion.py` | the 64 KiB game against the full game (the PC version): data by name, functions by code, side by side |
| `tools/datos128.py`, `tools/baldosas128.py` | the full game's map and tiles for the C128, from the PC version's data |
| `tools/punteros64.py`, `tools/inventario64.py` | the pointer fields inside the data; the inventory of what the game reads |
| `tools/cpc_velocidad.py` | the CPC game's real speed in Caprice32, for the speed comparisons |
| `tools/guion_azar.py` | random key scripts for the certification sessions |
| `tools/genera_todo.sh`, `tools/genera_cinta.sh` | the releases in one go |
| `tools/sincroniza.sh` | the project copied to the other two PCs, the graphic edits compared first |
| `tools/wiki.py` | this wiki: every code excerpt taken from the sources when it is built |
| `src/c64/mapa/hoja64.py`, `mapa64.py` | a sheet of every C64 graphic, and the whole abbey's map as the C64 draws it |

## This wiki

The pages in `doc/wiki/` are made by `tools/wiki.py` from the templates in `doc/wiki/fuentes/`: a line
`{{code PATH | START | END}}` becomes the lines of PATH from the one that matches START to the one that matches END,
with the file and the line numbers.  `tools/wiki.py --check` tells whether a page no longer matches the sources.
