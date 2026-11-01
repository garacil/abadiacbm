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

# What the CPC 64 KiB version removed (measured)

The CPC 464/664 tape version of La Abadía del Crimen ("ABADIA64", archive.org item
`amstrad_abadia_del_crimen_64`, transfer of the original cassette) compared with the full game (the
6128 disk version and my rebuild of the PC version, `~/Proyectos/abadia`).  Everything
here was measured by the tools on the unpacked 64 KiB memory (`data/cpc64/juego/ram.bin`, the game
at its start, 20BEh); sources on the web only said that "corridors without influence on the plot" and
"the crosses of the windows" were removed, and that the start point changed.

## Loading

**The original cassette** (`original/archive.org/cdt/`: two independent dumps of the tape, the normal
and the "Promotional" release, byte-identical once loaded; `tools/cinta64.py` extracts
them into `data/cpc64/cinta/`):

| Block | What |
|---|---|
| `CARGADOR` (standard format, 512 bytes at 0100h) | the loader: copies its edge routines to 0064h, RST 38h = RET, then reads three turbo blocks (a flag byte, then the data stored downwards from the last address) |
| flag 16h: 2C00h bytes, 8BFFh down to 6000h | the **first stage**: the introduction parchment (6000h-68A8h code, the text, the glyphs, the borders, the music); `CALL 6000h` |
| flag 20h: FE00h bytes, FFFFh down to 0200h | the **game and the loading screen**: before reading it the loader sets mode 0, the 16 inks and the border of its table at 0103h (`cinta/tintas.txt`) and the game's CRTC (R1 = 20h, R2 = 2Bh, R6 = 18h); the picture in C000h-FFFFh builds up as the bytes arrive (the screen comes first, FFFFh downwards); then SP = C000h, `JP 0200h` (= `JP 20BEh`) |
| flag 2Ah: 2C00h bytes, 8BFFh down to 6000h | the **ending parchment**: the same code as the first stage with its own text (7400h), tune (8000h) and borders; loaded by the game when the investigation is solved |

**The disk transfer** used (`original/archive.org/amstrad_abadia_del_crimen_64.dsk`,
archive.org "transtape from the original cassette") is a 2006 repack: `ABADIA64.BAS` (BASIC `CALL &1A0`
+ the first stage packed with CNGSoft's LZ2PACKER), `ABADIA64.BIN` (the game, packed), `ABADIA64.BN1`
(the ending, packed).  Its first stage, game and ending are the tape's except: the byte at 6000h; the
loading screen effect (its own code at 0200h-0261h opens the picture from the centre by the CRTC); the
tape save/load and loading routines 31C5h, 323Ch-323Dh, 3250h-3251h, 32ABh-3445h (rewritten for
AMSDOS: files `ABADIA64.BS1`..`BS9`); and 3EC6h-3EE9h, where its firmware restart stub (copied to BE80h
to load the ending from disk) overwrote the end of the game's message and **3EE6h
ai_stop_hour_countdown**, so on the disk version a call of 3EE6h (Berengar's script at 55CEh, 5612h,
56BEh, 56DFh) restarts the game: a bug of the repack, not of the original (CPC-Power flags that dump as
corrupt).  From the game's start the two give the same memory, screen included, outside those bytes
(8 sessions of 4000 frames compared).

### The ending (measured)

* 3E29h (from the main loop, 2197h), once the game is over: "HAS RESUELTO EL / xx POR CIENTO / DE LA
  INVESTIGACION"; when the first digit at 3E61h is `1` (100 %) it goes on at 3EC6h: "PON EL CASSETTE EN
  MARCHA" and `JP 31CFh`, which loads the 2Ah block from tape (32ABh, the game's own tape code) and
  calls 6000h for ever; else "PULSA ESPACIO PARA EMPEZAR" and a new game (20C7h).
* Each pass of the ending parchment stops the music after space, sets every ink black, clears the
  screen and returns; the next pass restarts the music (channel A) and writes the text again.

### Saving and loading the game on tape

* 31DFh (from the main loop, 2186h): CONTROL + TAB pauses (sound off, a mark on the screen); then S saves,
  L loads, ESC goes on.  1500 bytes of game state at 7F80h (2FD7h packs them, a checksum at 3254h),
  written and read by the game's own tape routines (the original; the disk repack replaced them by
  AMSDOS files).  On the C64: a save to disk.

## Rooms

| | 64 KiB | Full |
|---|---|---|
| room table | 6100h-7B98h, 129 records, 6808 bytes | 9392 bytes (116 rooms + padding) |
| rooms emptied (record `02 FF`) | **17h** (the full game's start room), **27h, 32h, 33h, 35h, 36h, 4Bh** | — |
| other rooms | almost all lost decoration: 20-30 % fewer block entries | |
| library (64h-73h) | untouched or nearly (66h, 68h, 69h, 6Ah, 6Bh, 6Eh identical) | |
| floor grids (room numbers) | identical | |

## Heights (where one can walk)

| Floor | 64 KiB | Full | Changed rooms |
|---|---|---|---|
| ground (7B98h) | 215 entries, 921 bytes | 255 entries, 1097 bytes | the whole exterior south of the abbey (the full game's start area), the east wing (2Dh-36h), 17h, 27h, 3Ah, 3Bh, 66h, 67h |
| first (9E40h) | 59 entries, 250 bytes | 64 entries, 269 bytes | 4Bh (emptied), 4Ch, 41h, 44h, 45h, 4Ah, 4Eh |
| library (9F60h) | 222 entries, 913 bytes | 223 entries | 73h |

## Graphics

* Tiles at 8300h (256 × 32 bytes, CPC mode 1): **76 tiles differ** from the full game's (rearranged
  or replaced), so the 64 KiB rooms only make sense with their own tiles and blocks.
* Block table 11DDh (96 pointers) and block data rewritten for the new tiles; the block interpreter
  (28 opcodes at 1BEEh) is the same.

## Start and logic

* Start: Guillermo and Adso in the **cloister** (room 16h, Guillermo at x 88h, y 9Ch), not at the
  entrance (room 17h no longer exists).
* Code: 12724 of 14819 instructions identical to the 6128 code once relocated
  (`data/cpc64/dif_total.txt`); the remaining blocks are data noise, relocation and the changes
  that follow from the new start, rooms and heights.  The rebuild in C translates the 64 KiB code
  itself, so its changes are kept without listing them one by one.
* The mirror numeral is chosen with the Z80 refresh register (LD A,R at 518Ah), as on the 6128; the
  PC version had replaced that read by a fixed value.

## Further cuts for the C64 and Atari (ours)

None yet: the 64 KiB version fits as it is in data (about 23 KB on the C64 once the graphics are
converted to multicolour); more rooms will be emptied only if the code does not fit (see ESTADO.md,
H3).
