# Group logica_a: the 6502 translation (H4)

Z80 3AAF-4C45 of the CPC 64 KiB game, C reference `src/juego/f_logica_a.c` (table `traducidas_logica_a`, 79 entries).
Sources: `logica_a.inc` (the group's zero page $DA-$E5 and two names), `logica_a.s` (the spiral wipe, the scripted
placements, camera and speed, lamp and night timers, percentage and bonus, Malaquias, Guillermo's place, the
parchment, the delay, the score-bar phrases, the inline texts, the inventory), `logica_a_cam.s` (the path searches,
Adso's steps, the command writers), `logica_a_spr.s` (the sprite engine, the room drawing by tiles).  Every
routine of the table is exported with the C function's name and the Z80 function's registers; the internal helpers
are `la_*` (not exported).  `game_check_end` 3E29 and `game_ending` 3EC6 are not in the table (they do not return
to their caller; the main loop's group handles them): not translated here.

## Design

* **Screen addresses are computed on the C64**: the bitmap byte of play-area line y, CPC byte x is
  `la_fila[y >> 3] + 8 (x >> 1) + (y & 7)` (`la_fila_lo/hi`: cell 4, line 0 of each character row, rows 0-24), the
  high nibble for an even x.  vid_xy_to_offset 3778 and vid_next_line 3558 are never called.
* **The sprite buffer on the C64** (`logica_a_spr.s` header): every rectangle is allocated as on the CPC (w * h
  bytes, so spr_buf_free, the "buffer full" test and every variable keep the CPC's values), but holds the C64
  format, **cell-major**: h / 8 rows of w / 2 cells, 8 bytes a cell, 4w bytes a row; byte of line y, CPC byte x at
  `+ (y >> 3) 4w + (x >> 1) 8 + (y & 7)`.  A tile is then 16 consecutive bytes (as the tile graphics, column-major),
  in the buffer and on the screen alike, and a row of cells is consecutive bitmap bytes: the blit copies whole rows.
  Rectangles are always tile-aligned, so every clip of the blit is a whole number of cells.
* **Sprite merge** (la_mezcla, la_linea): per line, the source nibbles are fetched into `la_lin` (backwards through
  espejo_byte for a mirrored robe), aligned to the destination's nibble with the `nibbles` table when the parities
  differ, the nibbles outside the clipped span made transparent (5), then merged with and_spr / or_spr (bytes 55h
  skipped), +8 a byte (the next cell).  The monk's switch to the robe at sprite line 10, the robe's bit-14 mirror and
  every self-modified operand of the Z80 (46AE, 46C3, 467C, 4703, 46A1, 46C9, 470B, 4972, 4975, 497D, 4A28-4A48, the
  blit's 4863/4868/486D) are written with the Z80's values (they are compared).
* **Tiles** (la_baldosa): $D000 + 16n, 01h-0Ah copied, 0Bh-7Fh with and/or_tile_a, 80h-D9h with and/or_tile_b.
  The I/O is switched off ($01 = $34) by spr_draw_all, iso_draw_room_spiral, spr_draw_tiles_in_depth_range and the
  standalone tile entries (spr_tile_to_buffer, iso_draw_tile), and restored.
* spr_tile_ptr_check 30FD (estado_texto, a pure range test) is done inline (`la_en_tb`): it runs per tile entry.
* **The searches** keep their queue where the Z80 kept it (below 877Eh: D64_PATH_QUEUE) and write the same bytes,
  including the words the Z80's CALLs and PUSHes left just below the queue's top (Z80 return addresses as constants,
  the queue address as the CPC's: `LA_ESCRATCH`): the shadow check compares that memory.  They are never read.
  The room and floor searches share one queue loop (`la_busca`, mode 0 / 4); the neighbour cells are addressed as
  8-bit offsets from one base pointer per expanded cell.  The searches end with EI (plat_ei) as the Z80 does.
* **The light** (graphic 0) writes dark nibbles at the CPC's linear offsets of the rectangle (stride 14h), tracked
  as (x, y, line address); offsets past the rectangle are not written (on the CPC they fell into free buffer).
* The spiral wipe moves a bitmap pointer and a nibble mask with the position (no address computation per byte);
  it assumes E = FFh or 00h (the only values its caller uses).

## Results declared (resultados.tsv)

As the C check's masks (`CHEQUEO`), in the host's vocabulary, except where the Z80 value is a code address that
cannot match: game_set_c004_inline's HL, txt_print_inline's IX, hud_say's HL when busy, game_camera_update's A (the
high byte of an address), iso_draw_tile's DE (a CPC screen address).  Pointer registers relocated (`REG:` /
`>REG:`), INLINE for 3D07, 4B44, 4B71, 4B7C.  The sprite routines leave out the sprite buffer and the area the
CPC's rectangles may reach past it (`!D64_SPR_BUFFER !D64_ISO_MIRROR_BUF_GUILLERMO !D64_PATH_QUEUE_TOP`) and the
final value of spr_tile_test_jump (`!D64_SPR_TILE_TEST_JUMP`: dead, reset at each cell before use, and it depends on
the garbage the tile rows past the tile buffer read: the CPC's pixel tables at 8F00h, other data on the C64).
Stub lines declare the pointer registers of the other groups' functions this group calls (IX/IY records,
command and step pointers).

## Checking

All 8 sessions (4472 frames) and the 16 long scripts (20472 frames) give 0 differences except `spr_tile_pos`
(2BE6h) below, **with three map changes and the exact screen check applied in a test copy** (scratch workspace;
the files here are unchanged):

1. `punteros64.tsv`: the sprite records' rectangle field `2978h + 14h k` (k = 0-22, written by spr_draw_all, read by
   the blit) is a pointer, target `D64_SPR_BUFFER|D64_ISO_MIRROR_BUF_GUILLERMO|D64_PATH_QUEUE_TOP`; and 4471h
   (spr_buf_free), 4690h (spr_cur_buffer) need the same three blocks (rectangles are allocated up to 877Dh).
2. `bloques64.tsv`: D64_ISO_MIRROR_BUF_GUILLERMO must be `copia`, not `nada`: the path queue grows below 8750h into
   it (chr_cmd_write_path reads the queue there; with `nada` the 6502 sees no queue and loops: "does not return").
   The mirror routines (4FC9) can leave it out with `!D64_ISO_MIRROR_BUF_GUILLERMO`.
3. `punteros64.tsv` 2BE6h (spr_tile_pos): rectangles above or left of the play area give values below the tile
   buffer (from 8594h): target `D64_ISO_MIRROR_BUF_GUILLERMO|D64_PATH_QUEUE_TOP|D64_ISO_TILE_BUFFER`; rectangles
   below it give values past 8EFFh (to ~9400h), which no block relocates: these are the last differences (1-9 per
   session).  They need a relocation by the path scratch's constant offset (C64 = CPC + 1D4Dh) for 7F80h-9FFFh, e.g.
   a flag `virtual` that also covers values after the block.
4. `mapa64.inc`: D64_SPR_RECT_SIZE is generated as a constant $2928 (it is CPC 2928h in D64_CHR_BACKUP: $02FC);
   the group uses `LA_RECT_SIZE = D64_SPR_RECT_POS + 2`.

**The screen of the tile and sprite composition** cannot be compared exactly with any per-byte conversion (the tiles'
detalle rule depends on the neighbours; transparent merges do not commute with a pixel-pair conversion), and
`PANTALLA:par` also fails on correct output where detalle-converted tiles merge.  `pantalla_doble.patch` (against
`src/juego/m6502/sombra6502.c`) adds `PANTALLA:doble`: the Z80 original is run a second time on doubled graphics (every
tile, sprite frame and the screen replaced by its C64 form, each C64 pixel as two equal CPC pixels); its screen then
converts exactly to what the C64 code must draw.  spr_draw_all and iso_draw_room_spiral pass it with 0 differences
in all sessions and long scripts; with the patch applied, their `PANTALLA:par` should become `PANTALLA:doble`.

Nested routines (never called from outside their group's callers) were checked individually by hiding their callers
in a test build: spr_draw_tiles_in_depth_range, spr_rect_union_old, spr_rect_tile_align, util_mul_al_bx,
spr_tile_unmark_hook, game_idle_camera_check, ai_jorge_book_talk_with_gloves, game_speed_default,
obj_play_inventory_sound, txt_skip_strings, chr_cmd_write_step, chr_cmd_write_turn, chr_adso_step_prepare/restore,
vid_spiral_put, chr_path_floor_search, chr_path_floor_cell_ptr: 0 differences.  spr_blit_to_screen, spr_tile_to_buffer,
iso_draw_tile and spr_mirror_byte work on C64-format data (the buffer, a bitmap address, a C64 byte) and differ by
design when called standalone from the Z80's CPC-format state; they are checked inside spr_draw_all and
iso_draw_room_spiral.

Never executed in the sessions nor the long scripts (assembled, written from the C): the scripted placements
(obj_place_*, obj_remove_*, chr_bernardo_arrives, chr_jorge_appears, chr_berengar_vanishes, chr_berengar_hooded,
util_store_dx_at_bx, obj_lamp_reset, obj_remove_glasses, obj_jorge_drops_book, obj_abbot_drops_parchment,
obj_book_to_jorge, obj_place_lamp, obj_jorge_takes_book), ai_malaquias_rise, ai_check_guillermo_at_mass /
_refectory / _at, ai_stop_hour_countdown, hud_blink_yes_no, util_delay_cx, game_speed_set (alone),
game_camera_from_ch_unused (no caller), obj_abbot_wants_parchment (a RET), and the light (472D).

## Size

Code 6648 bytes + BSS 65 = 6713 (from 7021 before the size pass; budget about 5230).  Per routine:
`juego.map` / the debug scopes.

## Cycles (8 sessions, traps not counted)

spr_draw_all 41 370 a call on average (one call a frame), 242 939 at most; iso_draw_room_spiral 224 000;
chr_path_room_search 168 000 on average, 325 600 at most; chr_path_room_to_marked 29 100; chr_path_floor_to_screen
16 500; vid_spiral_wipe 1 246 000 (the CPC needs about 0.7-0.9 s for it).  Measured standalone: spr_tile_to_buffer
451 (with the I/O switch; the internal la_baldosa about 425), spr_tile_unmark_hook 36 (inline in the tile loop: 8
when not in the final pass), spr_mirror_byte 12, spr_draw_tiles_in_depth_range 5 960, spr_blit_to_screen 3 600,
util_mul_al_bx 225, iso_draw_tile 471, vid_spiral_put 208.

## Tools used (scratch, not in the project)

A private copy of the host with a PC trace on "does not return", every difference printed, a cycle maximum per
routine, a per-instruction cycle profile, and `PANTALLA:doble`; a test copy of the workspace with the map changes
above and a variant mode that hides chosen exports (so the host checks the nested routines one by one).
