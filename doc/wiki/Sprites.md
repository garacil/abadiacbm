<!-- Made by tools/wiki.py from doc/wiki/fuentes/Sprites.md: edit the template, not this page. -->
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

# Sprites and the screen

[Home](Home.md) · previous: [Characters and movement](Characters.md) · next: [Heights and path finding](Paths.md)

The CPC has no hardware sprites, and the game does not use the C64's either: every moving thing — the characters,
the doors, the objects, the lamp's light — is a software **sprite**, drawn into the bitmap together with the tiles in
front of it.  This is the most expensive work of a frame, and it is done only where something changed.

## The sprite table

`SPR_TABLE` holds 23 records of 20 bytes (and an `FF` end): the six characters first, then the doors, the objects
and the light.

| Offset | Meaning |
|---|---|
| +0 | `FE` = inactive; bit 7 = to be redrawn; bit 6 = composed in this pass; bits 0-5 = the depth (the drawing order) |
| +1, +2 | x (in CPC bytes, 4 pixels each) and y (in lines) |
| +3, +4 | the previous x and y |
| +5, +6 | the width and the height (bit 7 of the width: erase the old area) |
| +7, +8 | the graphic |
| +9, +0A | the previous width and height |
| +0B | the animation (orientation x 4 + frame) |
| +0C-0F | the rectangle being composed |
| +10, +11 | where the rectangle lies in the sprite buffer |
| +12, +13 | the local position, for the depth test against the tiles |

## Composing in rectangles

`spr_draw_all` collects the sprites that changed, sorts them by depth, and gives each changed sprite a **rectangle**
that covers both its old and its new place, aligned to the tiles (4 bytes wide, 8 lines high).  Each rectangle is
composed in a buffer: the tiles behind, every sprite that overlaps it in depth order, the tiles in front; then it is
copied to the screen in one go, so nothing flickers:

[`src/c64/juego_final/logica_a_spr.s`](../../src/c64/juego_final/logica_a_spr.s#L944-L956), lines 944–956:

```asm
; 447D spr_draw_all: composes and draws every sprite that changed.  The active sprites (FE skipped, FF ends)
; listed (the Z80 pushed them on its stack: the last one first, and counted those with bit 7); none with bit 7: EI
; and out (looked for first: the list, which is the C64's own memory, is not needed then).
; Bubble sort by depth ([spr] & 3Fh, ascending from the top).  Then for each sprite of the list: bit 6 cleared;
; bit 7 set: the union of its new and old rectangles aligned to tiles (spr_rect_pos/size, [spr+0Ch..0Fh]),
; spr_tile_pos := 8594h + 12 y + 1.5 x (the tile buffer), the rectangle allocated in the sprite buffer (full past
; 877Eh: step 5) and cleared, bit 6 set, spr_depth_upper := 0; every sprite of the list (vanishing ones skipped)
; clipped to it (3786, x then y), the tiles between the previous depth and its depth [spr+12h] copied, the sprite
; merged; at the end the tiles in front of everything (BC = FCFCh, the hook 491B = NOP).  Step 5: every composed
; sprite blitted, its flags cleared, a vanishing one becomes FE; then the whole routine again (the sprites that did
; not fit).  Out: IX = the FFh of the sprite table (step 5), IY = the last sprite overlaid (both kept when nothing
; changed), HL = the FFh of the sprite table, DE = 14h, A = C = 0; EI.
.proc spr_draw_all
```

On the C64 the buffer is kept in the bitmap's own layout — cell by cell, 8 bytes a cell — so a tile is 16 consecutive
bytes and a row of the rectangle is a run of consecutive bitmap bytes: the copy moves whole rows.

[`src/c64/juego_final/logica_a_spr.s`](../../src/c64/juego_final/logica_a_spr.s#L19-L32), lines 19–32:

```asm
; The C64 sprite buffer.  Every changed sprite gets a rectangle aligned to the tiles (x multiple of 4 CPC bytes,
; y of 8 lines, w and h likewise), allocated as on the CPC (spr_buf_free advances by w * h, so the variables keep
; the CPC's values and the same sprites fit in a pass), but held in the C64 format, cell-major: the rectangle is
; h / 8 rows of w / 2 cells, a cell 8 bytes (its 8 lines), a row 4w bytes; the byte of rectangle line y, nibble x
; (CPC byte x) is at buffer + (y >> 3) 4w + (x >> 1) 8 + (y & 7), the high nibble for an even x.  A tile is then 16
; consecutive bytes (its two cell columns, as the tile graphics), and a row of the rectangle is consecutive bitmap
; bytes, so the blit copies whole rows.  The rest of the CPC's w * h bytes is unused.  The sprite routines leave
; the sprite buffer out of the shadow comparison (resultados.tsv).
;
; The graphics: tiles $D000 + 16n (column-major, merged with the tables $C400-$C7FF), sprites row-major,
; ceil(w / 2) bytes a line (the odd width's padding nibble 5 is transparent), merged with the tables and_spr /
; or_spr (pen 0 transparent); the robes drawn mirrored (bit 14 of their pointer) read backwards through
; espejo_byte; a sprite at an odd CPC x is half a byte off: the nibble swap table (c64/NOTAS_GRAFICOS.md).  The
; tiles, faces, door, objects and light lie under the I/O: the drawing routines switch it off ($01 = $34).
```

## Merging a sprite

`la_mezcla` merges one sprite into the rectangle, line by line: pen 0 is transparent, so each byte is combined through
two tables (`AND` the background with a mask, `OR` the sprite's pixels).  A sprite at an odd CPC x is half a byte off:
its nibbles go through a swap table.  The monks are drawn in two parts: the face (each monk his own) and the robe
(shared; read backwards when mirrored).

## The tiles in front

A tile hides a character when the tile's depth (stored in the tile buffer when the room was built, see
[Rooms and the isometric engine](Isometric-engine.md)) is in front of the character's position: `la_capas` copies, for
each sprite, the tiles between the previous sprite's depth and this one's, and at the end the tiles in front of
everything.  So a character walking behind a column disappears behind it pixel for pixel.

## The copy to the screen

[`src/c64/juego_final/logica_a_spr.s`](../../src/c64/juego_final/logica_a_spr.s#L634-L639), lines 634–639:

```asm
; 47E7 spr_blit_to_screen: the composed rectangle of the sprite IX (buffer [IX+10h], x [IX+0Ch] bytes, y [IX+0Dh]
; lines, w [IX+0Eh], h [IX+0Fh]) copied to the screen, clipped to the play area (sprite space: lines 28h-C7h, bytes
; 8-47h): spr_blit_skip, spr_blit_width (low byte), spr_blit_lines as the Z80 computes them; the copy goes by
; rows of cells (the cuts are whole cells: the rectangles are tile-aligned).  A rectangle cut on both sides (wider
; than the play area) is copied right here, where the CPC skipped only the right cut after each line.
.proc spr_blit_to_screen
```

On the C128 the copy waits for the raster beam (`la_haz`): it never copies the lines the beam is about to show, so the
sprites appear whole; there the heads are also drawn in high resolution by the VIC-II's own sprites (see
[The Commodore 128](C128.md)).

## Dark rooms and the lamp

In the library's dark rooms nothing is drawn except the lamp's light, which follows Adso when he carries the lamp:

[`src/c64/juego_final/personajes.s`](../../src/c64/juego_final/personajes.s#L101-L110), lines 101–110:

```asm
; 2236 spr_draw_or_darken: lit room: the sprites are drawn (JP 447D); dark room: 223D.
.proc spr_draw_or_darken
        lda     D64_ISO_ROOM_DARK
        bne     personajes_dark
        jmp     spr_draw_all
.endproc

; 223D (inside 2236, also reached from 2274): dark room.  Clears the redraw bit 7 of every active sprite record
; (FE inactive, FF end); then, if Adso's sprite is active and he carries the lamp (bit 7 of [2944]), the light
; is shown (BCh) and the sprites drawn (JP 447D).
```

The light is a sprite whose graphic is a mask: a pattern of 16-bit rows that leaves the area around Adso visible and
the rest of its rectangle dark.  The C64 version applies it two nibbles at a time on the cell-major buffer:

[`src/c64/juego_final/logica_a_spr.s`](../../src/c64/juego_final/logica_a_spr.s#L1734-L1739), lines 1734–1739:

```asm
; The same CPC light mask, applied two nibbles at a time in the cell-major C64 buffer. spr_place_light and
; tile alignment guarantee even x, fill counts 159/239, dx 0..3 and dx_rest = 4-dx. Each 16-bit pattern row,
; with its dark margins, is expanded to ten byte masks only once, then reused for its four lines. The cursor
; retains the original linear wrapping at the rectangle's width (not at the light's width of 20 nibbles).
; la_q is the destination pointer, la_s the logical x/y; la_f4w was set by la_capas. No multiply per pixel.
.proc la_luz
```
