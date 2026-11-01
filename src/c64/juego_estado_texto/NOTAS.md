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

# estado_texto: the 6502 translation (Z80 2FAD-3AAE)

Group estado_texto of the C64 game (src/c64/TRADUCCION6502.md, src/c64/CODIGO6502.md): the game state blocks and the
new game, the room height buffer, the start-up, the text (font drawing and the phrase scroller), the script
evaluator, the door permissions, the hour, the palettes.  C reference: `src/juego/f_estado_texto.c` (table
`traducidas_estado_texto`, 48 entries; 31DF, the tape menu, is not this group's), `src/juego/datos_estado_texto.h`.

## Files

| File | What |
|---|---|
| `estado_texto.s` | the routines the C64 game needs (2348 bytes in the C64 build; the Z80 entries only the checks call are under `.ifdef PRUEBA`) |
| `estado_texto_tabla.s` | table entries nothing in the C64 game calls, kept with their Z80 interfaces so that the host checks them; the merge can drop the file (297 bytes): 391E ai_script_test, 38FC ai_script_assign, 3A5D util_jump_table_inline, 3994 ai_script_operand, 3910 ai_script_var_ptr, 316E util_clear_bytes, 3521/352C/3535/3540 the height slopes, 3558 vid_next_line, 3778 vid_xy_to_offset |
| `resultados.tsv` | the group's lines (after `# group estado_texto`), and two stub lines (hud_say INLINE, spr_flip_graphics_h >HL:gfx) |
| `pantalla_fuente.patch` | the host patch for `PANTALLA:fuente` (below), against src/juego/m6502/sombra6502.c |
| `pruebas/unidad.c`, `pruebas/tablas.c` | unit tests on juego.bin with sim65's core (below) |

Not translated, the C64 does not need them: 3598 hud_rows_from_hidden and 35B0 vid_copy_lines_to_row (the
score bar is part of the bitmap image), the start-up's copy of the tiles 8300h to the hidden rows (the tiles are
at $D000 in the image).  3607 vid_init_stub builds the C64 drawing tables instead of the CPC's 8F00h-92FFh.

## The script evaluator (3926 ai_script_eval) for logica_b's VM

* In: zhl = the 6502 address of the expression's first byte.
* Out: zbc (C) = X = the value, zhl = the address of the terminator byte, A = the terminator byte, N/Z of the
  value (the Z80 leaves Z = 1: not compared).  Clobbers Y and $CE (ET_C, the group's zero page) and its own
  self-modified operand (`et_ld`); does not touch zbc+1, zde, zt0-zp0 or any other zero page (in particular not
  logica_b's $E6-$F1).  The values below the top of the expression stack go on the 6502 stack (at most 3 in the
  570 expressions of the game), balanced at the exit.  Not reentrant: never from the interrupt.
* Operands: 40h nn (literal nn), a byte below 80h (literal), 80h-C0h a variable (the byte at the word
  D64_AI_SCRIPT_VARS + (2 op mod 256)).  Operators 3Dh '=' 3Eh '>' 3Ch '<' 2Ah '*' (AND) 26h '&' (OR) 2Bh '+' 2Dh
  '-' (e - c).  The terminator rule is the Z80's exactly: the first byte, in operator position, among 20h D7h
  C2h CDh CFh C9h C3h 18h (the opcode of the Z80 instruction after the expression); any other byte there is an
  operand (pushed).  No terminator superset (the VM keeps the Z80 bytes).
* `estado_texto_eval_y` (exported for the table file): the same with Y preset (the expression at zhl + Y).
* Speed: the operand fetch is inlined (no JSR per operand); bytes 80h-FFh are classified first (variables,
  then the high terminators), then '=' and 20h, the most frequent operator and terminator.  2 000 717 calls in
  the 8 sessions (checked through a variant build, below): 231.5 cycles a call on average, all inclusive.
* The wrappers (table file): `JSR ai_script_test <expr>` returns past the expression with A = zbc = the
  value and Z; `JSR ai_script_assign <var> <expr>`; `JSR util_jump_table_inline <.word t0, t1, ..., 0>` (Z
  selects t0, else entry zbc from t1; the entry is entered by JMP with the JSR's return dropped; past the 0
  word it returns after the table).  They take their return address from the 6502 stack, read the inline
  bytes and JMP back past them.

## The text

* txt_draw_char 364D / txt_draw_char_inverted 3649: the C64 font (4 bytes a glyph, `G_FUENTE`, the blank glyph
  `G_GLIFO_BLANCO`) through `G_TABLA_FUENTE_NIBBLE` (a set pixel pen 3 = 00, a clear one pen 2 = 11; inverted:
  EOR FFh), opaque, into the bitmap at txt_cursor (x in CPC bytes, y in lines); an odd x straddles two C64 bytes
  (the low nibble of one, the high nibble of the next cell).  Below 2Dh (but 20h): nothing, C set.
* txt_phrase_tick 368A: the strip (lines A4h-ABh, CPC bytes 10h-2Fh = cells 12-27) scrolls one C64 byte to the
  left (an unrolled copy at the strip's fixed bitmap addresses, LDA abs,X / STA abs,X: ~1340 cycles), then the
  character is drawn inverted at A42Eh.  The phrase logic is the Z80's (words, F9 nn, FA-FE punctuation, FFh
  and the 16 trailing blanks, the voice bytes); the word skip (3770 txt_skip_words) is done inline with zp0.
  Since the interrupt work (src/c64/optimizacion/interrupcion): sys_tick makes the cheap test (the counter + 1 =
  2Dh) inline and calls `t_frase`, the 2Dh-th tick's work; the Z80 entry txt_phrase_tick (with its DI) and
  txt_skip_words stay in the checked build only (-D PRUEBA).
* **Interrupt rule** (it runs in the 300 Hz interrupt): the cheap path (44 of every 45 calls, or no phrase)
  touches only A and txt_scroll_timer.  The active path saves X, Y (the C64's handler does not), $14-$1D (zt0-
  zt0+7, zp0, zp0+1: all the zero page it and txt_draw_char use) and txt_cursor on the 6502 stack (14 bytes) and
  restores them at the end; it uses no register pair and no zero page of its own ($CE-$D9 untouched), so the
  main code's state is safe whatever it was doing.  The beep: in the checked build snd_start's DI ... EI
  (s_empieza: the IFF mirror as the Z80's); on the C64 s_pon alone, so the IRQ is not re-enabled inside the
  handler (no tick nests: the one that falls due comes after the RTI).
* Screen check: `PANTALLA:fuente` (host patch `pantalla_fuente.patch`): the rule par, plus the CPC byte -> C64
  nibble pairs of the C64 font's own glyphs (the hand-made 'N' and ';' of c64_graficos.py fuente_der follow no
  pair rule), derived at load from data/c64graf/fuente.bin and the CPC font at B400h of the tape image.  With
  it every text routine gives 0 differences.

## The height buffer

3456 chr_hbuf_fill_room (and 346E chr_hbuf_fill_list, its Z80 entry, kept for the checks only) write the Z80's
self-modified operands as the Z80 does (the visible width at 34EA and 3510, the step opcodes NOP / INC C / DEC C at
3515 and 351C), but fill with plain loops: a flat row from its last cell down, and a slope loop (+1 / -1 a column),
the slopes' first height and step set from small indexed variables (column / row).  Each span is clipped by
3786 util_clip_span itself (`hb_span`: the results of 3549 / 354D, which only the checks call now).

**The cache** (src/c64/optimizacion/texto): the fills come from the path searches (082F chr_path_build_grid) and the
room changes; a character that path-searches in the same room again (often every frame) makes the same fill:
the same list and window.  The lists never change but for the library's last record, the mirror's (5 bytes at
[obj_mirror_height_ptr]: the record when closed, FFh when open, F5h after a load).  So the fill keeps, in $D4-$D9
(HC_KEY: the list's high byte and the window x, y; HC_N; HC_RES) and $C3E8-$C3FF (HC_LO / HC_HI), the addresses of
the first 12 visible records of the last list and window and the point where a scan must resume (the first
visible record not kept, else the FFh, or in the library's list the mirror's place).  A miss scans the whole list
(a quick test of the x span first, util_clip_span's rule) and keeps; a hit draws the kept records again, then scans
from the resume point: the same records in the same order, so the same buffer, operands and end of the list; a kept
record that has become FFh (the mirror opened) ends the list there, as a scan does.  Neither area is loaded from the
disk: principal's 2151 (the game's start, a new game, a loaded game) empties the cache (`hbuf_cache_key` = 0)
before any fill.  The fill's scratch: zt0-zt0+7, zp0-zp0+6, zhl, zde, zbc.

Cost (host profile, whole game): a room's fill on a cold cache 31 100 / 8 650 / 28 100 cycles (the three lists,
all the room windows: as before), again 6 400 / 1 500 / 4 100.  Fills in the runs: 98 % hits with no keys to frame
2472, 63 % / 94 % / 85 % in sessions 1 / 5 / 8; the fill's cycles a frame 27 300 -> 10 300 (no keys), 5 050 ->
2 760, 19 300 -> 7 890, 15 000 -> 6 020 (sessions 1, 5, 8; util_clip_span included).  Checked also by
src/c64/optimizacion/texto/pruebas/hbuf.c (a C model of the Z80's 346E / 3786 against the build, the cache warm, the
mirror changed under it, random lists).

## The start-up and the tables

3568 sys_startup_init: sys_startup_done = 0Dh, every pen black (vid_palette_black), mode 1, the initial-state
snapshot (310E), the mirror (35C3), then (JMP) vid_init_stub, which on the C64 builds the ten drawing tables
of src/c64/NOTAS_GRAFICOS.md (and/or tiles A and B, and/or sprites, espejo_nibble, espejo_byte, nibbles,
fuente_nibble: 2320 bytes) in 70 400 cycles.  `pruebas/tablas.c` zeroes the ten tables of juego.bin, runs
vid_init_stub and finds them byte-identical to the image's (made by c64_graficos.py), nothing else written: the
loader need not load those 2320 bytes.

## The palettes

3A83 / 3A88 / 3A8D: pens 3, 2, 1, 0 and the border from D64_VID_PALETTE_BLACK + 0 / 5 / 10 (C64 colours in the
data image), through plat_tinta (X = the C64 colour); the host converts the Z80's CPC inks with
src/c64/datos/paleta.tsv for the comparison.

## Zero page

$CE ET_C (the evaluator's top value), $CF-$D0 ET_K (loop counters), $D1 ET_M (a mask), $D2-$D3 ET_T
(temporaries); $D4-$D9 the height lists' cache (HC_KEY 3, HC_N, HC_RES 2; `hbuf_cache_key` = $D4 exported to
principal.s, which empties it at 2151).  The text routines use only zt0 / zp0 (saved by the phrase scroller).

## Routines: bytes, calls checked, cycles

Bytes from the linked labels (shared helpers counted with the routine they follow); calls and cycles from the
hybrid host (`SOMBRA6502_CICLOS`, the 6502's own cycles, traps not counted): 8 sessions for the main build,
sessions 1-4 for the variant builds (marked v), plus the long scripts 101-106 (39.2 M calls, 0 differences).

| Z80 | routine | file | bytes | calls (8 sessions / v) | cycles a call |
|---|---|---|---|---|---|
| 2FAD | obj_open_left_wing_doors | main | 23 | unit test | |
| 2FB9 | sys_check_pause_save_load | main | 36 | 26 973 | 17 |
| 304F | spr_unflip_monk_faces | main | 59 | never called | |
| 3087 | obj_fix_owner_pointers | main | 124 | unit test (1000) | |
| 30FD | spr_tile_ptr_check | main | 30 | 991 838 | 41.7 |
| 310E | game_snapshot_initial_state | main | 8 | 4 v | 5 042 |
| 3111 | game_for_each_state_block | main | 60 | 12 v | 4 967 |
| 3166 | game_state_block_save | main | 13 | 128 v | 259 |
| 316B | game_state_block_restore (with the shared advance) | main | 32 | 384 v | 255 |
| 316E | util_clear_bytes | table | 45 | 72 v | 2 076 |
| 3176 | game_init_new_game | main | 92 | 21 | 7 502 |
| 3456 | chr_hbuf_fill_room (with the cache: hb_list, hb_span, hb_draw) | main | 439 | 6 279 | 38 412 (before the cache) |
| 346E | chr_hbuf_fill_list (the Z80 entry: the checks only) | main | 22 (PRUEBA) | 2 142 v | 38 246 (before the cache) |
| 3521 352C 3535 3540 | chr_hbuf_slope_* | table | 4 x 10 | 6 898 v | 19 |
| 3549 / 354D | chr_hbuf_clip_x / _y (the checks only) | main | 19 (PRUEBA) | 449 766 / 71 495 v | 63.2 / 67.3 |
| 3558 | vid_next_line | table | 25 | 45 904 | 20.6 |
| 3568 | sys_startup_init | main | 22 | 8 | 91 536 (with 3607) |
| 35C3 | game_init_mirror | main | 87 | 4 v | 15 699 |
| 35F8 | chr_hbuf_skip_list | main | 21 | 8 v | 10 686 |
| 3607 | vid_init_stub (the 10 C64 tables) | main | 145 | 12 v, unit test | 70 408 |
| 3649 / 364D | txt_draw_char_inverted / txt_draw_char | main | 210 (the bitmap address inline) | 975 (31 173 v) / 189 | 786 / 1 208 (before) |
| 368A | txt_phrase_tick | main | 341 | 893 376 | 166.8 |
| 3770 | txt_skip_words | main | 26 | 5 772 v | 1 977 |
| 3778 | vid_xy_to_offset | table | 24 | 24 823 | 38 |
| 3786 | util_clip_span | main | 77 | 138 733 (839 605 v) | 42.7 (36.1 v) |
| 38FC | ai_script_assign | table | 34 | 284 540 | 137.9 |
| 3910 | ai_script_var_ptr | table | 13 | 1 651 150 v | 24.3 |
| 391E | ai_script_test | table | 15 | 1 716 177 | 293.2 |
| 3926 | ai_script_eval (its entry: the checks only; the VM enters at estado_texto_eval_y) | main | 205 | 1 021 502 v | 231.5 |
| 3994 | ai_script_operand | table | 50 | 2 578 177 v | 44.1 |
| 39A8 | ai_stay | main | 6 | 1 746 | 12 |
| 39AE | ai_guillermo_is_close | main | 68 | 37 925 | 104.2 |
| 39E5 | ai_next_state_on_arrival | main | 34 | unit test (1000) | |
| 39F1 | obj_set_door_permissions | main | 88 | 136 940 | 637 |
| 3A30 | util_bits_set_or_clear (the checks only) | main | 10 (PRUEBA) | 2 526 336 v | 12.8 |
| 3A37 | ai_hour_update | main | 44 | 26 960 | 42.8 |
| 3A58 | ai_say_phrase_param | main | 10 | never called | |
| 3A5D | util_jump_table_inline | table | 51 | 12 v | 156 |
| 3A83 3A88 3A8D | vid_palette_black / _day / _night | main | 34 | 12 v / 21 / never | 230 / 226 |

Size: 2662 bytes after the first full check, 2573 after the size pass (main 2276 + table 297; the table file
is dropped at the merge if nothing imports it).  Budget 3300.

## Checks

* The 8 exploration sessions (`--hasta 4472`): 0 differences, 8 162 901 calls in the main build; the long
  scripts largo101-largo106 (`--hasta 20472`): 0 differences, 39 216 140 calls.
* Variant builds, 0 differences (scratch copies in which some of the group's routines are renamed, so that the host reaches
  the routines they call at top level): var_a hides 391E 38FC 3176 3456 39F1 3568 368A (checks 3926, 316E,
  346E, 3A30, 3A83, 310E, 3111, 35C3, 3607, 3770, 3649 from the scroller); var_b also hides 3926 3111 310E 346E
  35C3 (checks 3994, 3910, 3166, 316B, 3549, 354D, the slopes, 35F8); var_c also hides 3994 3549 354D (checks
  3910 from 3994's callers, 3786 from 3552); var_d hides 3A37 (checks 3A5D from 5A61).
* Unit tests (`pruebas/unidad.c`, sim65's core on juego.bin): 2FAD; 3087 on 1000 random object / holder /
  position states; 39E5 on 1000 random places (the sessions never call them).  `pruebas/tablas.c`: 3607.
* Never called in the sessions and not unit-tested: 304F spr_unflip_monk_faces and the pause path of 2FB9 (they
  need traps: spr_flip_graphics_h, the keyboard), 3A58 ai_say_phrase_param (hud_say inline), 3A8D
  vid_palette_night (the same code as 3A88 with another table offset).

## Host and map changes this group needed (made in the host and the map)

INLINE for checked routines and `>HL:INLINE` / `HL:INLINE` (391E 38FC 3A5D; 3926 3994), the alternate set
loaded into $0C-$13 (3521 3535 read H'), the inks compared as C64 colours, the 28ED target with
D64_TXT_PUNCTUATION and the flag `fin` (one past the end after the last punctuation code), the `held` holder
pointers.  Pending: `PANTALLA:fuente` (pantalla_fuente.patch, tested on a scratch copy of the host).
