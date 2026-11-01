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

# abadia64ks on the Commodore 64: memory map (H3)

The game's code on the C64 is 6502 assembly (ca65) written from the C reference and the Z80 (ESTADO.md,
"The translated game measured with cc65": the C compiled by cc65 would be ~60 KB of code).  The BASIC and
KERNAL ROMs are switched off during the game (`$01 = $35`: RAM everywhere but the I/O at $D000-$DFFF); the
KERNAL comes back only to load or save from disk (the ending parchment, a saved game).  This file is the map
and the budget; how it was made, the decisions and the open questions are in `src/c64/NOTAS_MAPA.md`, the graphics
formats in `src/c64/NOTAS_GRAFICOS.md`.

## How the map is made (all generated, deterministic)

| File | What |
|---|---|
| `src/c64/juego/bloques64.tsv` | the data blocks of the CPC memory the C64 needs (hand-written): name, CPC start, length, kind, zone, check mode |
| `data/c64graf/graficos64.tsv`, `marcos64.tsv`, `*.bin` | the graphics in their C64 formats (`tools/c64_graficos.py`) |
| `src/c64/juego/mapa64.py` -> `mapa64.tsv`, `mapa64.inc` | places every block in its zone; the ca65 symbols (every block, every `D64_` address of `src/juego/datos_*.h` at its C64 address, `CODIGO_INICIO`, `CODIGO_FIN`) |
| `tools/punteros64.py` -> `src/c64/juego/punteros64.tsv` | the 642 pointer fields inside the data |
| `src/c64/juego/datos64.py` -> `datos64.s`, `juego.cfg`, `conversion64.tsv` | the data image as ca65 segments at their addresses, the ld65 configuration (one 64 KiB image) |
| `src/c64/juego/construye.sh` | all of the above, then ca65 + ld65: `juego.bin` (64 KiB from $0000), `juego.lbl` |
| `tools/inventario64.py` -> `data/datos64_inventario.tsv` | the inventory with what the sessions measured, and every range not needed with its reason; checks |

## The C64 map

| C64 range | Size | Use |
|---|---|---|
| $0000-$0001 | 2 | CPU port |
| $0002-$0023 | 34 | the Z80-like registers and scratch of the 6502 code (`zp.inc`) |
| $0024-$009D | 122 | the 93 operands the Z80 code rewrites (self-modified operands and opcodes: the hottest variables) |
| $009E-$00FF | 98 | free zero page for the 6502 code (pointers) |
| $0100-$01FF | 256 | 6502 stack |
| $0200-$0213 | 20 | the 10 code pointers kept in Z80 operands (jump vectors: `JMP (abs)`) |
| $0214-$079C | 1417 | variables: the CPC variable blocks kept whole and in CPC order (28B9h-2967h, the sprite, door, object and character records 2968h-2BE7h, the logic variables 37D2h-3869h, the sound state, the keyboard...), the sprite offset tables ($0699), the blank glyph |
| $079D-$07FF | 99 | segment BAJO: the C64 build's own code, the footsteps and the music (objetos_sonido.s) and their voicing on the SID (psg.s); 88 bytes used ($079D-$07F4); in the checked build (no BAJO) $07C0-$07FF hold the platform mirrors the host compares (plataforma.inc), so a memory the host converts must get BAJO back (estado_final.py) |
| **$0800-$7150** | **26961** | **the code area (contiguous)** |
| $7151-$BFFF | 20143 | data: initial-state copy, room links, block table and data, floor maps ($7BD6), command buffers, script variable table, room table ($7E9C), ground heights ($9934), the path scratch 7F80h-8EFFh with the tile buffer as one region ($9CCD-$AC4C, the tile buffer at $A4CD), first and library heights, phrases ($B0DC), characters ($B478), robes ($B895, in $8000-$BFFF: bit 14 of their pointers is a flag), font; the five 256-byte merge tables, page-aligned ($BB00-$BFFF) |
| $C000-$C3E7 | 1000 | screen RAM of the multicolour bitmap (VIC bank 3): pens 0 and 1 of every cell; the cells outside the 32 x 24 of the game stay black |
| $C3E8-$C3FF | 24 | estado_texto's height-list cache (chr_hbuf_fill_room: the kept records' addresses; not loaded, emptied at 2151); $C3F8-$C3FF are the VIC's sprite pointers for screen RAM $C000: the sprites are off |
| $C400-$C7FF | 1024 | the tiles' merge tables (AND/OR of both tile classes), page-aligned |
| $C800-$CFFC | 2045 | block interpreter stack, sorted sprite list, the words (1257), the height buffer (576), the animation tables |
| $D000-$DFE9 | 4074 | under the I/O, read and written only with the I/O switched off: the tiles 00h-D9h with the objects in free slots (3488), the faces, the door leaf, the day numerals, the light pattern |
| $D800-$DBE7 | (I/O) | colour RAM: pen 2 of every cell |
| $E000-$FF3F | 8000 | the multicolour bitmap: the game's 256 x 192 CPC pixels as 128 x 192 in cells 4-35 of rows 0-23; the score bar is part of the image (rows 20-23) |
| inside $E000-$FFF9 | 2042 | the bitmap's invisible bytes (cells 0-3 and 36-39 of rows 0-23, row 24, $FF40-$FFF9: their colours stay black): 1171 used by 32 small tables and the sound data, 871 free in pieces of up to 64 bytes |
| $FFFA-$FFFF | 6 | NMI, RESET, IRQ vectors (RAM: KERNAL off) |

The exact address of every block: `src/c64/juego/mapa64.tsv`; of every named datum: `src/c64/juego/mapa64.inc`.

## The screen

The game's CPC screen (mode 1, 256 x 192: 64 bytes a line, 24 rows) becomes 128 x 192 multicolour pixels
centred in the 160 of the C64 (4 cells from the left), one C64 pixel per CPC pixel pair, pens 3, 0, 1, 2 ->
bit pairs 00 ($D021), 01 (screen RAM high nibble), 10 (screen RAM low nibble), 11 (colour RAM); a CPC byte
is a C64 nibble.  A CPC ink change (`plat_tinta`) is a change of $D021 or a fill of the 32 x 24 cells of the
screen RAM / colour RAM: no pixel is redrawn, as on the CPC.  Pen 3 and the border are black in all three
palettes of the game, so $D021 is always black and the cells outside the game area, with black screen RAM and
colour RAM, never show their bytes: they hold data, as the CPC kept data in the hidden part of its screen.
CPC screen address a -> bitmap byte $E000 + 320 row + 8 (xb / 2 + 4) + line (line = a >> 11 & 7, row =
(a & 7FFh) >> 6, xb = a & 63; the low nibble when xb is odd); `mapa64.inc` gives the `D64_SCR_*` names so.

## Budget

| Data (`mapa64.tsv`, grouped) | CPC 64K (bytes) | C64 (bytes) |
|---|---|---|
| room table (129 records) | 6808 | 6808 |
| graphics: tiles + objects 6976, characters 1837, robes 725, faces 700, font 368 + blank glyph 8, door 240, numerals and HUD pieces 38, light 30, score bar 2048 | 12970 | 6779 (the score bar's 1024 are the bitmap itself: 5755 outside the screen) |
| buffers: path scratch 7F80h-877Fh (2048) + tile buffer (1920) kept contiguous, height buffer 576, command buffers 225, initial-state copy 167, the C64's interpreter stack 64 and sprite list 48 | 4936 + 112 | 5048 |
| texts and clock tables: words 1257, phrases 924, hour durations / day numerals / hour names 115, phrase voices 56, punctuation 5, mirror numerals 9 | 2366 | 2366 |
| merge tables of the C64 formats (the CPC built 1024 at 8F00h, not needed): 1040 required, 1280 for speed | (1024) | 2320 |
| block table (88 pointers) and block data | 2222 | 2222 |
| heights of the 3 floors | 2088 | 2088 |
| other tables: sound data 482, sprite offsets 256, floor maps 240, script variable table 130, 26 small tables 602 | 1710 | 1710 |
| variables and records: sprite records 461, room links 304, 28B9h-2967h 175, logic variables 37D2h-3869h 152, characters 90, sound state 79, animation tables 96, ... | 1557 | 1557 |
| operands the Z80 code rewrites (93) | 142 | 142 |
| **data on the C64** | | **31040**: zero page 122, $0200-$07FF 1437, below $C000 20143, $C400-$CFFF 3069, under the I/O 4074, bitmap gaps 1171, score bar 1024 in the bitmap |
| Z80 code not needed as data (`data/cpc64/particion64.tsv`) | 16072 instructions + 2176 inline data (script expressions, inline call data, texts) | becomes 6502 code |
| screen | 16384 (4096 of it data in the hidden part) | bitmap 8000 + screen RAM 1000 (2042 bytes of it data room) |
| **left for the code** | | **26961 contiguous ($0800-$7150)** + 98 zero page + ~195 at $0200-$07FF + 871 in the bitmap gaps (small tables) |

The 6502 code is estimated at 1.3-1.6 times the Z80's 16 KB of instructions (21-26 KB) plus the inline data
(script expressions stay inline after a `JSR`, 2.2 KB): 23-28 KB.  It may not fit: the cuts below are ready.

## Cuts to propose if the code does not fit (not applied; to decide)

| Cut | Saving (bytes) | Cost |
|---|---|---|
| drop the five optional merge tables (OR of tiles A/B and sprites, mirror byte, nibble swap: the 6502 computes them, `src/c64/NOTAS_GRAFICOS.md`) | 1280 | slower tile and sprite drawing (an AND/ORA per byte instead of a table lookup) |
| empty room 00h (99 bytes, not in any floor map: to confirm it is never shown) | 97 | none if never shown |
| drop the block data no room reaches (blocks of the unused types 3Eh, 40h, 42h, 44h, 56h, 6Ah, 7Ah, 9Ch, AEh, B0h: 1405h-1407h, 1568h-156Ah, 1763h-1765h, 17C9h-17CAh, 17E9h-17EDh, 183Ah-1843h, 19FDh-19FEh, 1A75h-1ABAh, 1AE4h-1AF0h), compacting the block data (its pointers are relocated anyway) | ~125 | none |
| empty more rooms as the CPC 64K did with 17h, 27h, 32h, 33h, 35h, 36h, 4Bh (record `02 FF`, heights and links adjusted so they cannot be entered): biggest ground-floor rooms 15h 150, 08h 107, 28h 99, 18h 93, 23h 91, 05h 91, 3Eh 89, 07h 87, 0Dh 85, 25h 85, 0Fh 85, 10h 85, 1Eh 84 (each also frees its height entries) | 80-150 each | rooms of the abbey lost; scripts and routes through them must be checked (monks' places tables 37F8h-3869h) |
| smaller rooms by removing decoration entries (as the CPC 64K did, 20-30 % fewer entries) | ~3-4 bytes an entry | less decoration |
| the first floor (16 rooms, 1126 bytes) and the library (18 rooms, 1633) are part of the plot: not candidates | | |
| a hand-drawn C64 font with 2 glyph rows per byte is already used (184); the score bar is in the bitmap (0) | 0 | |

Further room without cuts: the 871 free bytes of the bitmap gaps (pieces of up to 64 bytes) can hold the
6502 code's own small tables (dispatch tables of the scripts and the block opcodes, the sound commands...),
and the 98 free zero-page bytes and ~195 bytes of $0200-$07FF its variables.
