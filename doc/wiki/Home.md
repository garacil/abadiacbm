<!-- Made by tools/wiki.py from doc/wiki/fuentes/Home.md: edit the template, not this page. -->
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

# How the abbey works — the abadiacbm wiki

*La abadía del crimen* (The Abbey of Crime; Paco Menéndez and Juan Delcán, Opera Soft, 1987) is an isometric
adventure in which Brother William of Occam (Guillermo) and his novice Adso spend seven days in a Benedictine abbey
to solve a series of deaths.  This wiki explains how the game works inside, part by part, through the code of its
Commodore versions:

* **abadia64ks** — Commodore 64, tape and disk: the Amstrad CPC 64 KiB tape version, translated to 6502 routine by
  routine and certified against the original Z80 program frame by frame;
* **abadia128ks** — Commodore 128 in its own mode, disk: the full game (the map and rules of the CPC 6128 and PC
  versions) on the same 6502 code, with high-resolution heads, 2 MHz in the borders and the Ave María;
* **abadia128ks for the P500** — Commodore P500 (CBM-II 510, 128 KiB), disk: the same full game on the MOS 6509 and its
  banks.

The releases, their packages and the videos of complete games: [abbeyofcrime.com](https://abbeyofcrime.com).

*En español: [Inicio](es/Inicio.md), la misma wiki en español, más detallada, rutina a rutina.*

Every code excerpt is taken from the sources when the wiki is built (`tools/wiki.py`), with its file and line
numbers, so it always matches the code in this repository.

## Pages

| Page | What it explains |
|---|---|
| [The abbey as a game](The-abbey.md) | the seven days, the hours, the ceremonies, the monks, the obsequium, the objects, the end and the percentage |
| [From the Z80 to the 6502](From-Z80-to-6502.md) | how the CPC program was translated: registers, data names, addresses, the routines' contracts |
| [Memory map](Memory-map.md) | where the game lives in the C64's 64 KiB, how the map is generated, the screen |
| [Main loop and timing](Main-loop.md) | the start, a new game, the frame, the 300 Hz interrupt, the speed |
| [The clock and the ceremonies](Clock.md) | days, hours, their durations, what happens at each hour |
| [Rooms and the isometric engine](Isometric-engine.md) | the room table, the block interpreter, tiles, depth, the camera |
| [Characters and movement](Characters.md) | the character records, steps, turns, heights, animation, projection |
| [Sprites and the screen](Sprites.md) | the sprite table, composition in rectangles, the light, the blit |
| [Heights and path finding](Paths.md) | the height buffer, the searches inside a room and between rooms, the movement commands |
| [The monks' minds](Monks.md) | the behaviour scripts and their virtual machine, the drivers, every character |
| [Objects, doors and the mirror](Objects.md) | holders, picking up and dropping, keys and doors, the mirror riddle |
| [Text and the score bar](Text.md) | words and phrases, the scroller, the score bar, the obsequium bar |
| [Sound](Sound.md) | the sound sequencer of the interrupt, music and effects, the AY played on the SID |
| [The Commodore 64 platform](Platform-C64.md) | the machine set-up, the interrupt, keyboard and joystick, inks, disk |
| [The Commodore 128](C128.md) | the MMU and block 1, 2 MHz, the hires heads, the Ave María, the ending's load |
| [The Commodore P500](P500.md) | the 6509's banks, the chips of bank 15, the interrupt's acknowledgement, the keyboard, the KERNAL's call between banks, the loading |
| [Loading: tape and disks](Loading.md) | the start menu, the tape's turbo loader and stages, the disks, compression |
| [Presentation and ending](Parchments.md) | the parchments with their music, written in C |
| [Building and certification](Building.md) | the build chain, the generated data, the tests, the certification against the CPC and the PC |
| [Graphics and tools](Graphics.md) | the CPC graphics on the C64, the conversion, the editor, the other tools |
| [My tools](Tools.md) | how I build, prove and measure the game: the hybrid host, the certification, the cycle analyzer, the measurement in VICE, the licence, this wiki |
| [Glossary](Glossary.md) | the Spanish names used in the code and the game's terms |

## Reading the code

* The 6502 sources are in `src/c64/juego_final/` (the game), `src/c64/plataforma/` (the machine), `src/c64/cinta/`,
  `disco64/`, `disco128/` (loading) and `src/c64/presentacion/` (the parchments).
* Almost every routine starts with a comment giving the **address of the Z80 function** it translates in the CPC
  64 KiB program (for example `; 20BE game_main`), and many lines carry the address of the Z80 instruction they
  replace.  The same names are used in the C translation (`src/juego/f_*.c`), which is the readable reference.
* Data are reached by the names `D64_*`: each is a datum of the CPC program placed at a C64 address by the
  generated memory map (see [Memory map](Memory-map.md)).
* The routines keep the Z80 function's interface: the Z80 register pairs are zero-page pairs (`zbc`, `zde`, `zhl`,
  `zix`, `ziy`), the accumulator is the accumulator (see [From the Z80 to the 6502](From-Z80-to-6502.md)).
* Comments, names and documents are in English; file and directory names are often Spanish (see the
  [Glossary](Glossary.md)).
