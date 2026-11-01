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

# Building and certification

[Home](Home.md) · previous: [Presentation and ending](Parchments.md) · next: [Graphics and tools](Graphics.md)

## The build chain

Everything is generated from the sources and the original game's data, deterministically: the same sources give the
same tape and disks, byte for byte.

1. **The graphics**: `tools/c64_graficos.py` converts every graphic of the CPC game to the C64's formats (and applies the
   hand edits from `src/c64/datos/editados64.txt`), into `data/c64graf/`.
2. **The memory map**: `mapa64.py` places every data block; `punteros64.py` finds the pointer fields; `datos64.py` writes
   the data image as ca65 segments and the linker's configuration (see [Memory map](Memory-map.md)).
3. **The scripts**: `guiones64.py` translates the monks' Z80 scripts into the VM's bytecode (see [The monks' minds](Monks.md)).
4. **The game**: ca65 and ld65 assemble and link the 6502 sources and the data into one 64 KiB image.
5. **The release**: the presentation and the ending (cc65), the stream or the crunched files, the menu, the tape or
   the disk image.

{{code src/c64/juego_final/construye.sh | ^# The 6502 game for the hybrid host's checks | ^# tools/inventario64.py}}

The same sources build every variant through conditionals: `C64=1` the real machine (without it, the build for the
checking host), `CINTA=1` the tape, `DISCO=1` the C64 disk, `C128=1` the Commodore 128, `IDIOMA=en` English; the C128
build adds `-D COMPLETO` and `-D VELOZ`.

## Three levels of checking

**1. Every routine, at every call.**  The hybrid host (`src/juego/hibrido`) runs the original Z80 program, and at every
call of a function that has a 6502 translation it also runs the 6502 routine on a 6502 core (cc65's sim65), from the
same state converted to the C64's map, and compares: the registers and flags the function returns, and every data
block.  `comprueba.sh` does it for the eight recorded sessions (and `--largos` for sixteen long ones):

{{code src/c64/juego_final/comprueba.sh | ^# The checks of the integrated 6502 build | ^# Prints the host's summary}}

**2. The whole game, frame by frame.**  With `--juego` the host runs the whole 6502 game from its entry in step with the
Z80, and compares the whole memory at every frame; `dias.sh` starts it at every day and hour of the game (49 states) and
plays to the 100 % ending.

**3. The real machine against the original.**  `src/c64/certifica/certifica.py` runs the real C64 build in VICE with the
same keys as the original Z80, the same random byte and the same interrupt model, and compares at every frame the C64's
whole RAM with the CPC's memory through the map:

{{code src/c64/certifica/certifica.py | ^"""The certification of the C64 game | ^c64/juego_final/juego6502.tsv}}

The C128's full game is certified the same way against the PC version's rebuild (`src/c64/certifica/pc/`), which plays
the full game and was itself verified frame by frame against the PC original: random sessions of 4000 frames, 0
differences.  The P500's too: `corre500.py` starts the P500's own disk in xcbm5x0 as a player would (the menu, the
parchment, the loader, the stage in bank 1), then holds the same keys at every frame and dumps bank 0 and bank 1's
data; four random sessions of 6000 frames (past the first completas, the abbot after Guillermo, the doors opening and
closing), 237 data compared at every frame, 0 differences:

{{code src/c64/certifica/pc/corre500.py | ^"""abadia128ks on the P500 against the PC | ^"""$}}

## The tests of the releases

The releases themselves are tested in VICE, from the tape or the disk as a player would start them:

| Test | What it checks |
|---|---|
| `src/c64/cinta/prueba_cinta.py OUT [--opciones KEYS] [--final]` | the tape: the menu, every block loaded, the game's memory at its first instruction equal to its image, the options (the footstep's and the beep's notes as rests), the ending loaded from the tape |
| `prueba_cinta.py OUT --disco [--unidad 1541\|1571]` | the same on the C64 disk, with each drive |
| `src/c64/disco128/prueba128.py OUT [--opciones 1234] [--final\|--guarda] [--unidad 1571\|1541]` | the C128 disk: the boot, both blocks of memory, the options, saving and loading, the ending; with each drive |
| `src/c64/presentacion/pruebas/disco_prueba/prueba.py` | the parchments' pages and music, the picture during the load |

`tools/genera_todo.sh --prueba` builds the three releases and runs these tests.
