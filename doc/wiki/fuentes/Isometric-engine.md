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

# Rooms and the isometric engine

[Home](Home.md) · previous: [The clock and the ceremonies](Clock.md) · next: [Characters and movement](Characters.md)

The abbey is a world of 256 x 256 positions on three floors (the ground, the first floor with the scriptorium, and
the library under the roof), cut into **rooms** of 16 x 16 positions.  Only one room is shown at a time, drawn in
isometric projection; when the character the camera follows walks out of it, the next room is built and drawn.

## Which room, and from which side

The floor maps give a room number for each 16 x 16 square of each floor.  Every frame `iso_update_camera_room`
checks the square of the character the camera follows (`x & F0h`, `y & F0h`, the floor of its height); when it
changed, it selects the room, and also the **camera's orientation**, which depends on the room's position: the
abbey is seen from a different side in neighbouring rooms, one of the game's best-known traits.

{{code src/c64/juego_final/motor_iso.s | ^; 1F79 iso_update_camera_room | +9}}

## Rooms are programs

A room is not a picture.  Its record in the room table (`ISO_ROOM_TABLE`: 129 records in the 64 KiB game) is a list of
**entries**, three or four bytes each, and each entry places a **block** — a wall, a floor, a staircase, an arch, a
table, a bookcase... — at a position of the room's grid, with two size parameters and an optional height:

| byte | bits | meaning |
|---|---|---|
| 0 | 7-1 | the block type: an even number, the index of a word in the block table |
| 0 | 0 | 1 = a height byte follows |
| 1 | 4-0, 7-5 | x (0-31) and the first size parameter p1 (0-7) |
| 2 | 4-0, 7-5 | y (0-31) and the second size parameter p2 (0-7) |
| 3 | 7-0 | the height (when present) |

`FF` ends the record.  `iso_draw_room` clears the tile buffer, fills the play area (black for a dark room) and runs
the record; a lit room is then drawn from the tile buffer:

{{code src/c64/juego_final/motor_iso.s | ^; 1611 iso_draw_room | ^:       rts}}

`iso_build_room` decodes one entry after another.  Before entering a block it pushes its own address as the return
tag, so that the block's `END` comes back to it for the next entry, as the Z80 did with its own stack:

{{code src/c64/juego_final/motor_iso.s | ^; 163F iso_build_room | ^        txa                             ; A = the height}}

## The block interpreter

Each block is a list of 12 tile numbers and a small **bytecode** program that puts those tiles into the tile buffer.
The opcodes are stored complemented (`FF` is opcode 0), and the dispatcher jumps to the handler through a table of
addresses with an `RTS`, the 6502's equivalent of the Z80's `PUSH DE / RET`:

{{code src/c64/juego_final/motor_iso.s | ^; 1C2C the dispatcher | ^        rts}}

{{code src/c64/juego_final/motor_iso.s | ^; the handlers of opcodes FFh down to E4h | +12}}

| Opcode | Meaning |
|---|---|
| `FF` END | back to the caller (the next room entry, or the block that called this one) |
| `FE` / `FD` LOOP | repeat until `FA` NEXT p1 or p2 times |
| `FC` / `FB` | push / pop the position |
| `F9` / `F8` / `EB` | a run of tiles: up, right, left, one cell after each |
| `F7` SET | a register := an expression (operands: literals, the tile registers, p1, p2, the height, the depth) |
| `F6`-`F1` | move the position: y+1, x+1, y−1, x−1, y += expr, x += expr |
| `F0`-`ED` | p1 / p2 + 1 or − 1 |
| `EC` CALL, `E4` CALL_KEEP | run another block here (with its own tiles, or keeping these) |
| `EA` JUMP | continue in another block's program: most blocks share code this way |
| `E9`-`E5` MIRROR | mirror the x direction until the block's END: a wall facing the other way is the same block mirrored |

A floor, for example, is two nested loops (p2 + 1 rows of p1 + 1 tiles) of `TILES_UP t1, t1` plus an edge, and a
front border; a thicker wall is the same program as a thin one with another tile list.  The whole abbey is drawn by fewer than a
hundred blocks of a few dozen bytes each (88 in the 64 KiB game's block table).

## The tile buffer and the depth

The visible part of the grid is 16 x 20 cells of 16 x 8 pixels.  Each cell of the tile buffer keeps the last **two**
tiles put into it (the lower one is drawn first), and for each a **depth**: the block's position in the world, so that
the sprite engine can later decide, pixel by pixel, whether a tile hides a character.

{{code src/c64/juego_final/motor_iso.s | ^; 1295 iso_put_tile | ^iso_put_tile:}}

The depth of a block comes from its position and its height, as the inverse of the projection of the characters:

{{code src/c64/juego_final/motor_iso.s | ^; 1BC6 iso_block_depth | ^@r:     rts}}

## Drawing

A lit room is drawn from the tile buffer in a spiral from the centre outwards (`iso_draw_room_spiral`); each tile is
8 lines in the C64's multicolour format, 4 bytes a line; the tiles below 0Bh are copied opaque, the others merged
through the AND/OR tables.  The tiles live under the I/O (`$D000`), so the drawing switches the I/O off while it reads them.
A dark room (the library's rooms on the top floor, all but one) leaves the play area black and only the lamp's light shows (see
[Sprites and the screen](Sprites.md)).
