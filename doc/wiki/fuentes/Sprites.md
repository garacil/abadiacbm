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

{{code src/c64/juego_final/logica_a_spr.s | ^; 447D spr_draw_all | ^\.proc spr_draw_all}}

On the C64 the buffer is kept in the bitmap's own layout — cell by cell, 8 bytes a cell — so a tile is 16 consecutive
bytes and a row of the rectangle is a run of consecutive bitmap bytes: the copy moves whole rows.

{{code src/c64/juego_final/logica_a_spr.s | ^; The C64 sprite buffer | ^; tiles, faces, door, objects and light lie under}}

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

{{code src/c64/juego_final/logica_a_spr.s | ^; 47E7 spr_blit_to_screen | ^\.proc spr_blit_to_screen}}

On the C128 the copy waits for the raster beam (`la_haz`): it never copies the lines the beam is about to show, so the
sprites appear whole; there the heads are also drawn in high resolution by the VIC-II's own sprites (see
[The Commodore 128](C128.md)).

## Dark rooms and the lamp

In the library's dark rooms nothing is drawn except the lamp's light, which follows Adso when he carries the lamp:

{{code src/c64/juego_final/personajes.s | ^; 2236 spr_draw_or_darken | +10}}

The light is a sprite whose graphic is a mask: a pattern of 16-bit rows that leaves the area around Adso visible and
the rest of its rectangle dark.  The C64 version applies it two nibbles at a time on the cell-major buffer:

{{code src/c64/juego_final/logica_a_spr.s | ^; The same CPC light mask | ^\.proc la_luz}}
