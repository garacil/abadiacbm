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

# abadiacbm — La abadía del crimen for Commodore computers

*La abadía del crimen* (The Abbey of Crime; Paco Menéndez and Juan Delcán, Opera Soft, 1987) for the Commodore 64,
the Commodore 128 and the Commodore P500, which I wrote in 6502 assembler as a faithful translation of the original
Z80 program and certified frame by frame: the C64 game against the CPC original, the C128's and the P500's against my
PC rebuild.

**Downloads, videos and news: [abbeyofcrime.com](https://abbeyofcrime.com).**

| Release | Machine | Media | What it is |
|---|---|---|---|
| **abadia64ks** | Commodore 64 | tape (`.tap`) and disk (`.d64`) | the Amstrad CPC 64 KiB tape version: its map, rules, clock, monks and puzzles; Spanish and English chosen in a start menu |
| **abadia128ks** | Commodore 128 (C128 mode) | disk (`.d64`) | the full game (the map and rules of the CPC 6128 and PC versions), hires heads with the VIC-II's sprites, 2 MHz in the borders, the whole game in memory, the digitised Ave Maria; Spanish and English |
| **abadia128ks for the P500** | Commodore P500 (CBM-II 510, 128 KiB) | disk (`.d80` for an 8050, `.d64` for a 2031 or 4040) | the same full game on the MOS 6509: the game in bank 0, the rooms, texts, faces' masks and Ave Maria in bank 1, the chips in bank 15, reached with the 6509's cross-bank instructions; hires heads, the Ave Maria; Spanish and English |

The current releases are in the repository, built from these sources: `src/c64/cinta/abadia64ks.tap`,
`src/c64/disco64/abadia64ks.d64` and `src/c64/disco128/abadia128ks.d64` (both disks work with a 1541 or a 1571 drive),
`src/c64/discop500/abadia128ks_p500.d80` and `.d64`; their packages with instructions are on
[abbeyofcrime.com](https://abbeyofcrime.com).

**How the game works**, part by part with the code: the wiki in [`doc/wiki/Home.md`](doc/wiki/Home.md), also on this
repository's [wiki](https://github.com/garacil/abadiacbm/wiki) (`tools/wiki_github.py`).

## Layout

| Directory | Contents |
|---|---|
| `src/c64/` | the 6502 game (`juego_final/`), its platform layer (`plataforma/`), the tape and the game's stream with its loader tools (`cinta/`, `cinta/FLUJO.md`), the C64 disk (`disco64/`), the C128 disk (`disco128/`), the P500 disks (`discop500/`), the presentation and ending (`presentacion/`, with its test disk in `pruebas/disco_prueba/`), the certification (`certifica/`), the video sessions (`video/`), notes and tests |
| `src/juego/` | the original program translated to C, function by function: the host that runs the Z80 original and the 6502 build side by side for the certification |
| `tools/` | all my tools (what each one does and how: `doc/HERRAMIENTAS.md`): graphics conversion and pixel editor (`c64_graficos.py`, `c64_editor.py`), the data generators, the comparators, the speed instruments (`velocidad/`), the licence header (`licencia.py`), the wiki (`wiki.py`), the synchronisation of my machines |
| `tools/terceros/` | third-party tools, **not in the repository** (below) |
| `data/` | the original game's data (the CPC tape images and memory dumps, the full game's map), the recorded sessions and reference states the checks use |
| `doc/` | my working reference (`PROYECTO.md`: releases, builds and checks, machines, design, videos, rules), my tools (`HERRAMIENTAS.md`), my work log (`ESTADO.md`), the milestones (`HITOS.md`), the cuts (`RECORTES.md`), the references of the machines (`referencias/`), the reviews against the CPC with their pictures (`revisiones/`), the wiki (`wiki/`) |

## Building

Requirements: Python 3 with Pillow, GCC and make, VICE 3.10's `c1541` (the disk images), and in `tools/terceros/`:

* `cc65/` — cc65 V2.19 (https://github.com/cc65/cc65), built there (`tools/terceros/cc65/bin/ca65`, `ld65`, `cl65`);
* `exomizer/` — Exomizer 2.0.9 (the source archive https://github.com/bitshifters/exomizer), built in
  `tools/terceros/exomizer/exomizer2/src/`.

Then, each release from its own directory (or all of them: `tools/genera_todo.sh`):

    src/c64/cinta/construye.sh        # abadia64ks.tap (and every C64 image)
    src/c64/disco64/construye.sh      # abadia64ks.d64
    src/c64/disco128/construye.sh     # abadia128ks.d64
    src/c64/discop500/construye.sh    # abadia128ks_p500.d80 and .d64

Every build is deterministic: the same sources give the same images, byte for byte.

## Checking

My hybrid host runs the original Z80 program and checks every translated routine and the whole 6502 game against it
(GCC; `src/juego/prueba.sh`, `src/c64/juego_final/comprueba.sh [--juego]`, `dias.sh`).  VICE 3.10 (`x64sc`, `x128`,
`xcbm5x0`) runs the tests and the certifications:

    src/c64/cinta/prueba_cinta.py OUT [--disco [--unidad 1541|1571]] [--opciones KEYS] [--final]   # the tape / the C64 disk
    src/c64/disco128/prueba128.py OUT [--opciones KEYS] [--final|--guarda] [--unidad 1571|1541]     # the C128 disk
    src/c64/certifica/lote.sh BUILD OUT N SESSION...                           # the C64 game against the CPC original
    src/c64/certifica/pc/lote.sh BUILD PC_BUILD OUT FRAMES N SEED...           # the C128 game against the PC rebuild
                                                                               # (PC_BUILD: outside this repository)
    CORRE=corre500.py src/c64/certifica/pc/lote.sh src/c64/juego_final/p500 PC_BUILD OUT FRAMES N SEED...
                                                                               # the P500 game against the PC rebuild

Some tools need more: NumPy, PySide6 (the pixel editor), SkoolKit (the Z80 simulator of the analysis tools), the
Caprice32 emulator (the CPC's speed); each one says so in its text.

## Credits

*La abadía del crimen*: Paco Menéndez (author), Juan Delcán (graphics and cover), Opera Soft, 1987; after Umberto
Eco's novel *The Name of the Rose*.

The Commodore versions: Germán Luis Aracil Boned, 2016-2026 — garacilb@gmail.com — https://abbeyofcrime.com

The project began in September 2016 with the presentation's parchment program in C (cc65).

The code is free software under the GNU General Public License, version 3 or later (`COPYING`).  The original
game's graphics, texts, music and data belong to their authors.

---

**En español.**  *La abadía del crimen* para Commodore 64 (abadia64ks: la versión de cinta de 64 KiB del Amstrad
CPC, en cinta y en disco), Commodore 128 (abadia128ks: el juego completo, en disco) y Commodore P500 (el mismo juego
completo, en disco), en ensamblador 6502, traducción fiel del programa original del Z80 y certificada contra él
fotograma a fotograma.  Descargas, vídeos y novedades: [abbeyofcrime.com](https://abbeyofcrime.com).
Español e inglés en cada edición.
Versiones para Commodore de Germán Luis Aracil Boned.
