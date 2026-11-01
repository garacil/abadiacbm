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

# My tools

[Home](Home.md) · previous: [Graphics and tools](Graphics.md) · next: [Glossary](Glossary.md)

I made, checked and measured everything in this project with tools I wrote for it, and they are all in the
repository, under the same licence as the game: `doc/HERRAMIENTAS.md` lists every one, grouped by what I use it for.
This page shows how the most important ones work.  Three rules hold for all of them: the same inputs give the same
outputs, byte for byte; every machine fact comes from the official documentation or from the code being measured,
never from memory; and whatever changes the game is followed by the checks that prove it is still the same game.

## The hybrid host: every routine against the Z80

The C translation and the 6502 routines were never trusted by reading them: `src/juego/hibrido` runs the original
Z80 program of the CPC, and every time the Z80 calls a function I translated, the translation runs first from the
same state, then the machine is put back and the Z80 original runs the same call:

{{code src/juego/hibrido.c | ^static void llamada_traducida | ^\x7d}}

The comparison takes the whole 64 KiB, SP, PC and the results each function declares (its flags, its registers);
only the dead stack below the entry, which a C function never writes, is left out:

{{code src/juego/hibrido.c | ^static void compara\(const traducida_t | ^\x7d}}

With `--6502 DIR` the game's 6502 routines (`src/c64/juego_final`) are checked the same way on sim65's 6502 core
(`src/juego/m6502/sombra6502.c`), and with `--juego6502 DIR` the whole 6502 game runs in step with the Z80, its
memory compared at every frame.  The checks run over the 8 exploration sessions, 16 long scripts, every day and hour
of the game and the ending (`src/c64/juego_final/comprueba.sh`, `dias.sh`): 0 differences.

## The certification on the real machines

The host proves the 6502 code; the certification proves the releases.  `src/c64/certifica/certifica.py` runs the real
C64 build in VICE frame by frame in step with the host's Z80 through two FIFOs; `src/c64/certifica/pc/lote.sh` runs
the C128's and the P500's disks in VICE (`corre128.py`, `corre500.py`: the P500 from its own disk, its menu, its
parchment and its loader) beside my PC rebuild of the full game with the same keys, and `compara.py` compares 237
data at every frame.

## Cycles taken from the emulator's own source

For the speed work I needed the exact cost of every instruction.  `tools/velocidad/analizador/ciclos6502.py` does not
carry a table of cycles: it reads them from sim65's `6502.c` itself, its opcode table and the macros of each handler,
and every figure keeps the source lines it was taken from:

{{code tools/velocidad/analizador/ciclos6502.py | ^def parse_6502c | +24}}

`prueba_sim65.py` then checks the analyzer against reality: a small program for every legal opcode, with and without
page crossings, and a program of loops, all measured by `sim65 --cycles` (200 cases, 0 differences).

## Measuring the real frame in VICE

`tools/velocidad/vice/medir.py` measures the C64's frame in VICE without disturbing it: it only stops the emulator at
checkpoints and reads CIA 2 as a 32-bit cycle counter at each stop, so every figure is exact:

{{code tools/velocidad/vice/medir.py | ^Checkpoints \(addresses from juego.lbl | +9}}

## My licence on every file

`tools/licencia.py` puts my header on every text file of the repository in the file's own comment syntax, and says
which ones lack it (`--comprueba --git`, before every commit):

{{code tools/licencia.py | ^def cabecera | ^    return}}

## This wiki

`tools/wiki.py` makes these pages from their templates: every excerpt is cut from the sources when the wiki is built,
with its file and its line numbers, so no excerpt is copied by hand and none can go stale:

{{code tools/wiki.py | ^def extracto | ^    return}}

`tools/wiki_github.py` publishes the pages of both languages in the repository's GitHub wiki.
