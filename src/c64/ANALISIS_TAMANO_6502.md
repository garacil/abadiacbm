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

# Size analysis of the 6502 game code (src/c64/juego_final, src/c64/plataforma)

Read-only analysis of the C64 build (no `-D PRUEBA`, ordinary memory map, not SPRHW).  Every count below was
taken from ca65 listings assembled in a scratch copy of the sources with the ordinary `mapa64.inc`
(the project's current one is the SPRHW variant) and from a scratch link with the same `juego.cfg`; the
scripts (`analiza.py`: routine sizes and repeated windows, `patrones.py`: verified pattern counts,
`muertos.py`: code nothing references, `fidel.py`: write-only variables) live in a scratch directory and
touch nothing in the project.  Line numbers are those of the sources.

## Applied (after the analysis)

Items 2, 3, 4 (all but D64_VEC_4AFC / D64_AI_UNUSED_3CAD), 5 (as the macros DI / EI / EI_RTS of zp.inc; plat_di /
plat_ei kept for the checked build), 6, 8 and 12 (the la_q helper, the two branches, plat_psg), plus the play-area
fill of item 7 as a pointer loop.  The grid-marks loop of item 12 was tried and reverted: the unrolled original
chooses the buffer by the high byte of chr_hbuf_ptr, whose initial value is not one of the two buffers.  Result:
CODE 26 236 -> 25 601 bytes in the normal build (the checked build is unchanged: `comprueba.sh` 0 differences,
0 traps over the 8 sessions).  The SPRHW build (src/c64/SPRITES_HW.md) lives in the room gained.

## Baseline

| Segment | Start | Size | |
|---|---|---|---|
| CODE | $0800 | 26236 | all .s of juego_final (except datos64/stubs64/sprites_hw) + tinta, teclado, psg, interrupcion, disco |
| RODATA | $6E7C | 535 | |
| DATA | $7093 | 31 | |
| BSS | $70B2 | 72 | |
| end | $70FA | | `CODIGO_FIN` = $7151: **87 bytes free** of the 26961 |

CODE bytes per file: logica_b 3086, logica_b_guiones 2901 (script bytecode, data), logica_a_spr 2849,
personajes 2708, estado_texto 2348, camino 2312, logica_a 1970, logica_a_cam 1891, objetos_sonido 1838,
motor_iso 1834, principal 918, psg 654, disco 309, teclado 228, interrupcion 193, tinta 160, motor_iso_spr 34.

The 10 biggest routines (`.proc` or top-level label, bytes of CODE):

| Bytes | Routine | Where |
|---|---|---|
| 745 | spr_draw_all | logica_a_spr.s:865 |
| 742 | la_busca (the two path searches, with the Z80-stack fidelity code, see 3) | logica_a_cam.s:251 |
| 338 | chr_cmd_write_path | logica_a_cam.s:1005 |
| 316 | la_tramo | logica_a_spr.s:1495 |
| 316 | obj_drop_object | logica_b.s:949 |
| 311 | la_mezcla | logica_a_spr.s:1258 |
| 306 | la_luz | logica_a_spr.s:1714 |
| 304 | spr_blit_to_screen | logica_a_spr.s:672 |
| 303 | chr_path_find | camino.s:539 |
| 284 | iso_update_camera_room | motor_iso.s:933 |

(then chr_project 281, game_main 279, ai_update_adso 278, la_capas 277, obj_pick_up_objects 272.)  The script
bytecode of logica_b_guiones.s is one 2901-byte block of data for the VM: not code to share.

## What the mechanical search found (and did not)

* Exact repeated windows of 3-12 instructions across all files: the biggest exact duplicate is the 15-byte
  `la_q += la_f4w` (3 copies, item 12); everything else ≤ 14 bytes with 2-4 copies.  The code is already
  written with shared tails, BIT-skips and fall-throughs: the usual "write it once" candidates (JSR+RTS → JMP:
  **0** cases; the I/O prologue `lda $01 / pha / lda #$34 / sta $01`: 3 cases, all needed) are exhausted.
* The real room is in (a) code that exists only for the hybrid host's checks and is unreachable or
  write-only in the C64 build, (b) unrolled fills in cold paths, (c) a 256-byte table in the data zone that
  the C64 never reads, and (d) a few parametrised helpers.

## Ranked opportunities

Savings are bytes of the C64 build, counted from the listing.  "Cycles" is the cost added per use (JSR+RTS = 12
plus the helper's own).  Risk classes: **low** = no observable behaviour changes, the checked build is
untouched (`.ifdef PRUEBA`) or the change is in the platform layer; **medium** = a design decision
(the C64 build stops mirroring the Z80 in bytes nothing reads, or a register/scratch clobber to check per site).

### 1. Drop the sprite OR table (`G_TABLA_OR_SPR`) from the C64 map — 256 + 6 bytes, medium

* The table at $BE00 (256 bytes, zone `datos`, `D_TABLA_OR_SPR` in juego.cfg) is written once by
  `vid_init_stub` (estado_texto.s:1120-1121, `jsr @or / sta G_TABLA_OR_SPR,x`, 6 bytes) and **read by nothing**:
  la_tramo merges with `and G_TABLA_AND_SPR` and the EOR form (logica_a_spr.s:1614-1621); graficos64.tsv says
  "written for the host's checks" (the check of vid_init_stub compares the tables it builds).
* The code area ends where the lowest `datos` block starts ("the code lives from $0800 to the lowest datos",
  mapa64.py), and the page tables $BB00-$BF00 are packed down from $C000: without this page the packer can
  move the blocks below it up by one page, so `CODIGO_FIN` gains 256 bytes.
* Rewrite: a `SIN_C64 = {"tabla_or_spr"}` in mapa64.py for the C64 map (as `SIN_HW` already does for the SPRHW
  build) and `.ifdef PRUEBA` around the two instructions.  Risk: the C64 map differs from the checked build's
  (the SPRHW build already lives with that); the checked build keeps the table and its check.  Verify that
  nothing in src/juego/m6502 reads $BE00 from the C64 image (c64_graficos.py only generates the expected table).

### 2. Routines kept only for the host's per-routine checks — 182 bytes, low

Exported, listed in resultados.tsv, and referenced by no instruction, table or data pointer of the C64 build
(checked over all sources and datos64.s):

| Bytes | Routine | Lines | Note |
|---|---|---|---|
| 53 | vid_spiral_put | logica_a.s:251-282 | the spiral pass does it inline (la_espiral_pon) |
| 42 | vid_set_crtc | motor_iso.s:1134-1162 | plat_crtc does nothing on the C64 |
| 30 | spr_tile_ptr_check | estado_texto.s:375-392 | la_en_tb is the C64's test |
| 28 | iso_fetch_operand + iso_operand_value | motor_iso.s:842-862 | the interpreter uses mi_fetch / mi_operand |
| 23 | iso_tile_run (the `CALL 1D0A / DB step` form) | motor_iso.s:729-739 | mi_tile_run (745) stays |
| 5 | `lda #1 / jsr plat_modo` | estado_texto.s:1032-1033 | plat_modo is an RTS on the C64 |
| 1 | the shared RTS plat_crtc/plat_modo | interrupcion.s:149-151 | |

Rewrite: `.ifdef PRUEBA` around each (and its `.export`), exactly as spr_mirror_byte, snd_start,
util_bits_set_or_clear… already are.  No cycle cost, no behaviour change; comprueba.sh unchanged.

### 3. la_busca: the Z80's stack words written for the shadow comparison — 126 bytes, medium

The room/floor search writes the Z80's CALL return addresses and pushed registers below the queue top so that
the host sees the same memory (logica_a_cam.s:227-250).  Nothing in the game reads those words (only
`la_q`/`la_p` are read, always above V).  Removable in the C64 build (`.ifdef PRUEBA`):

| Bytes | What | Lines |
|---|---|---|
| 59 | la_tw, la_xj, la_j0, la_rexp | logica_a_cam.s:589-620 |
| 20 | ret_exp, ret_lo, ret_hi | 623, 628-629 |
| 29 | the bookkeeping at `fin:` (txa … jsr la_tw … jsr la_rexp … jsr la_j0) | 329-344 |
| 6 | `jsr la_xj` (465) and `jsr la_tw` in `lazo` (480) | |
| 6 | the LA_PAGINA test in `encola` (only the words could reach the grid) | 554-556 |
| 6 | `ldx la_q / stx la_t+2` (424-425) and `ldx #0` in `vacia` (356) | |

The exact mode itself (`modo1`, `la_exacto`, `exacta` without its two JSRs) must stay: it also serves an origin
outside 1..22.  Cycles: the searches get slightly faster.  Risk: the design decision only; the checked build
keeps everything.  (A further 30 bytes: the four unrolled neighbour tests `o_n3..o_n0`, 441-464, 47 bytes,
could use the 21-byte `lazo` loop of the exact mode, at ~8 cycles per neighbour tried — a speed trade-off in the
search's inner loop, not counted below.)

### 4. Stores to Z80 operands that the 6502 never reads — 123 bytes, medium

`fidel.py`: every `D64_*` symbol that the C64 build stores and never loads (by name, by index, by `(zp),y`
alias — checked against mapa64.inc: each address below has one name; excluded `D64_SPR_LIGHT_FLIP_PATCH`
(= `D64_SPR_LIGHT_FLIP`, read in la_luz), `D64_SND_CHANNEL_MASK_COPY` (= `D64_SND_MIXER_SENT`, read in
s_interrupcion), the `D64_SND_VOICE_*` bytes (sound data read through pointers) and `D64_AI_RANDOM` (saved
game state)).  They are the CPC's self-modified operands (`46AE`, `46C3`, `4A28`…), written "as the Z80 does":

| Bytes | Site | Instructions that only feed the store |
|---|---|---|
| 12 | logica_a_spr.s:378-383 | `lda #$FC / sta DST_SKIP / sta COPY_SKIP / lda #$07 / sta DST_SKIP_HI / sta COPY_SKIP_HI` |
| 4 | logica_a_spr.s:534-535 | the two `sta …SKIP_HI` (the `lda #0` also feeds la_f4w+1) |
| 10 | logica_a_spr.s:537-541 | `lda LA_RECT_SIZE / sec / sbc #4 / sta DST_SKIP / sta COPY_SKIP` (542 reloads A) |
| 14 | logica_a_spr.s:674, 720, 733, 738-739, 750-751 | D64_SPR_BLIT_SKIP ×3 (2 each), `lda la_t+3 / sta BLIT_WIDTH` (4), `lda la_t+1 / sta BLIT_LINES` (4) |
| 8 | logica_a_spr.s:1259-1262 | `lda #$CC / sta OV_MIRROR_CALL / lda #$23 / sta OV_SRC_STEP` |
| 11 | logica_a_spr.s:1265-1266, 1269, 1274-1275 | OV_LINE (4), OV_SRC_STRIDE (2), OV_DST_STRIDE (5) |
| 6 | logica_a_spr.s:1439-1442 | `lda #$C4 / sta / … sta OV_SRC_STEP` (keep `lda #$2B / sta la_esp`) |
| 8 | estado_texto.s:279-282 | D64_OBJ_DOOR_ALLOW_OP: `lda #0 / bcc @op / lda #$3F / @op: sta` (the `lsr zbc` carry goes straight to `bcs @clr`) |
| 15 | estado_texto.s:856-857, 882-885, 905-906 | the HBUF step/width opcodes (`lda #$0C / adc #0 / sta …,x / lsr` keeps C: `tya / asl` already leaves it) |
| 8 | logica_b.s:1557-1558, 1569-1570 | D64_HUD_DAY_GLYPH_STEP (`lda #$03 / sta`, `lda #$0B / sta`) |
| 2 | motor_iso.s:237 | D64_VID_FILL_BYTE |
| 15 | personajes.s:147-150, 1773-1776 | D64_SPR_LIGHT_DX_REST (7), D64_SPR_FLIP_WIDTH (8) |
| 10 | principal.s:100-101, 482-483 | D64_VEC_4AFC (`lda #$C3 / sta`), D64_AI_UNUSED_3CAD (`lda #0 / sta`) |

Rewrite: `.ifdef PRUEBA` around each group (the checked build and the whole-game memory comparison keep
them).  Risk: the C64 memory no longer mirrors those CPC bytes; none is in a saved-game range
(28D0-2BE7, 2BE8-2C07, 37D2-389A, 3568-3648) or in script reach.

### 5. `jsr plat_di` / `jsr plat_ei` → `sei` / `cli` in the C64 build — 50 bytes, low

plat_di is `sei / rts`, plat_ei `cli / rts` (interrupcion.s:139-147).  In the C64 build (the `.ifdef PRUEBA`
DIs are already out): 13 `jsr plat_di` (estado_texto.s:618, logica_a.s:1141, objetos_sonido.s:774,
personajes.s:1297, 1398, 1599, 1633, principal.s:80, 86, 133, 286, 410, 437), 9 `jsr plat_ei`
(estado_texto.s:628, logica_a.s:1170, logica_a_cam.s:48, logica_a_spr.s:896, personajes.s:1307, 1574, 1611,
principal.s:148, 324), 2 `jmp plat_ei` (objetos_sonido.s:776, personajes.s:1652).  Macros in zp.inc:

```
.macro DI
  .ifdef PRUEBA
        jsr     plat_di          ; the host's IFF mirror
  .else
        sei
  .endif
.endmacro                        ; EI the same with plat_ei / cli; a tail `jmp plat_ei` becomes `EI / rts`
```

22 × 2 + 2 × 1 = 46 bytes, plus the two 2-byte routines once nothing calls them (4; their `.import` lines
go under `.ifdef PRUEBA` too, ld65 resolves every import).  Each use saves 10 cycles.  No flags or registers
involved; the checked build is byte-identical.

### 6. plat_tinta's unrolled fill — 69 bytes, low

tinta.s:71-91 (102 bytes): 24 × `sta PANTALLA+CELDA0+40*r,x` (72) plus the loop that flips the 24 operands
between the screen RAM and the colour RAM (30).  A pointer loop over 24 rows of 32 cells (33 bytes):

```
llena:  sta     zp0+2                   ; the fill byte (A), Y = the target's page
        sty     zp0+1                   ; (not zt0: vid_palette_* keeps its counters in zt0, zt0+1)
        lda     #<CELDA0
        sta     zp0
        ldx     #CELDAS_Y
fila:   ldy     #CELDAS_X-1
        lda     zp0+2
:       sta     (zp0),y
        dey
        bpl     :-
        lda     zp0                     ; the next row: +40
        clc
        adc     #40
        sta     zp0
        bcc     :+
        inc     zp0+1
:       dex
        bne     fila
        pla                             ; (the X and A kept, as now)
        tax
        pla
        rts
```

Cycles: ~9 000 per pen instead of ~4 000; the game writes five pens at a palette change (start, day/night):
~25 000 cycles (a fifth of a frame) a few times a game.  plat_tinta is main-code only (vid_palette_*, which
keeps its loop counters in zt0/zt0+1), so zp0..zp0+2 are free by the convention of CODIGO6502.md; the
platform README's "clobbers Y" becomes "clobbers Y, zp0-zp0+2".

### 7. vid_fill_play_area and iso_clear_tile_buffer as pointer loops — 45 bytes, medium (speed)

motor_iso.s:236-245 (71 bytes, 20 × `sta MI_PLAY_AREA+320*R,y`) and 223-232 (33 bytes, 8 ×
`sta TB-1+240*I,y`).  Loops with `(zp0),y` and a 16-bit step take 39 and ~20 bytes.  Cost: the fill goes from
~5.3 to 11 cycles a byte: +29 000 cycles per play-area fill and +11 000 per tile-buffer clear, both on a room
change (iso_draw_room) and at a new game: a fifth of a frame on a room change, which already redraws the room.
Only if that cost is accepted; otherwise keep.

### 8. principal.s: reune and restaura share their table loop — 29 bytes, low

principal.s:411-432 and 443-464 are the same 46-byte loop (six `lda piezas_x+k,x / sta` pairs, `jsr copia`,
`+6`) over two tables.  Put piezas_v right after piezas_r (they already are, RODATA) and share one routine:

```
; the (destination, source, length) triples from X to the end A of piezas_r: copied (copia); A, X, Y clobbered
piezas: sta     zt0
:       lda     piezas_r,x
        sta     PD
        … (the six pairs as now, indexed from piezas_r) …
        txa
        pha
        jsr     copia
        pla
        clc
        adc     #6
        tax
        cpx     zt0
        bne     :-
        rts
```

reune: `ldx #0 / lda #piezas_v-piezas_r / jsr piezas`; restaura: `ldx #piezas_v-piezas_r / lda #piezas_v_fin-piezas_r / jsr piezas`.
The two 46-byte loops (92) become one of 49 plus two 7-byte calls: 63, **29 saved**.  The routine (not under
the host: the C64's own disk menu) keeps zbc for copia; zt0 is free there.

### 9. Helper: 16-bit add of a constant to a zero-page pair — up to 40 bytes, medium

25 sites of the 9-byte form `lda q / clc / adc #n / sta q / bcc :+ / inc q+1 / :` (all zero page):
camino.s:343, 1098, 1120; estado_texto.s:925; logica_a.s:302, 477, 1284; logica_a_cam.s:1169;
logica_a_spr.s:588, 602, 887, 920, 1237, 1659, 1769; logica_b.s:613, 814, 885, 1587; motor_iso.s:833;
objetos_sonido.s:192, 433, 1088; personajes.s:113, 347.

```
; zero-page pair X += A (unsigned); X, Y kept, A changed.  10 bytes, 12 + ~11 cycles
addw:   clc
        adc     0,x
        sta     0,x
        bcc     :+
        inc     1,x
:       rts
```

Call `lda #n / ldx #q / jsr addw` = 7 bytes: 2 saved per site, 50 − 10 = 40 at most.  Only at sites where X
is free (several are loops that count in X, e.g. logica_a_spr.s:1237's `p5` keeps Y, logica_b.s:613's
obj_pick_up_objects keeps X): to be checked one by one; the (zp,x) forms cost 1 cycle more each.  Not for
the interrupt's routines (none of the 25 is).

### 10. Helper: a 16-bit constant into a zero-page pair, the word inline — up to 59 bytes, medium

47 sites of the 8-byte `lda #<X / sta q / lda #>X / sta q+1` (q = zhl 20, zix 6, zp0 5, zde 4, zbc 3,
la_p/la_s 2 each, cam_ptr, la_c, lb_tgt, o_spr, ziy 1 each; patrones.py (e) lists every line).  One helper
that takes the target and the word after the JSR:

```
; q := word: JSR ldw / .byte q / .word X (6 bytes a use).  A, X, Y and zt0, zt0+1 changed.  35 bytes, ~72 cycles
ldw:    pla
        sta     zt0
        pla
        sta     zt0+1           ; the JSR's address + 2
        ldy     #1
        lda     (zt0),y         ; q
        tax
        iny
        lda     (zt0),y
        sta     0,x
        iny
        lda     (zt0),y
        sta     1,x
        lda     zt0             ; return past the three bytes
        clc
        adc     #3
        tay
        lda     zt0+1
        adc     #0
        pha
        tya
        pha
        rts
```

2 bytes a use: 94 − 35 = 59 at most.  Each use clobbers X, Y and zt0/zt0+1 and costs ~70 cycles: usable only
where those are dead (many sites are followed by `ldy #0` or a JSR, but e.g. camino.s:717 keeps zbc+1 and
logica_a_spr.s:1757 is inside la_luz, which uses zt0+4..): per-site check needed, and never from t_frase /
s_interrupcion (interrupt scratch rule) — none of the 47 is there.  Low value for the effort.

### 11. Helper: a record's word into a pair — up to 36 bytes, low-medium

25 sites of `lda (p),y / sta q / iny / lda (p),y / sta q+1` (9 bytes, patrones.py (d2)); by source pair:
(ziy) 7 (→ zhl camino.s:510, 852, 1244, logica_a_cam.s:1128; → zbc logica_a_spr.s:1199; → la_s 1289;
→ o_guarda objetos_sonido.s:550), (zix) 7 (→ zhl camino.s:643, logica_a_spr.s:1000, 1022; → zp0 763,
logica_b.s:1033; → zde logica_a_spr.s:1028, motor_iso.s:828).  Two helpers:

```
; q (X) := the word at (ziy),Y; Y + 1, A changed.  10 bytes each (the same with zix)
ldw_iy: lda     (ziy),y
        sta     0,x
        iny
        lda     (ziy),y
        sta     1,x
        rts
```

Call `ldx #q / jsr ldw_iy` = 5 bytes: 4 saved a site, 7 × 4 − 10 = 18 per helper, 36 for both; X clobbered
(check each site), +12 + 2 cycles.

### 12. Small verified items — 56 bytes, low

* `la_q += la_f4w` (15 bytes) ×3: logica_a_spr.s:609-615, 1331-1337, 1398-1404 → a 16-byte helper
  (`lda la_q / clc / adc la_f4w / … / rts`, A only): 45 − 9 − 16 = **20**.
* Two `bxx :+ / jmp T / :` whose T is within range: logica_a_spr.s:1817 (`beq :+ / jmp fila`, −104) and
  personajes.s:635 (`bne :+ / jmp chr_step_level`, +102) → the inverted branch: **6**.
* psg.s plat_psg `hecho:` (225-239) repeats pon_frecuencia's tone branch (`ldx voz,y / lda frec_lo,y /
  sta SID+0,x / lda frec_hi,y / sta SID+1,x`, 13 bytes): `jsr pon_frecuencia` (it re-tests onda,y, 5 cycles):
  **12**.
* camino.s chr_path_clear_grid_marks (990-1021, 72 bytes): the two 3-strip loops exist because the buffer is
  one of two addresses; one loop through `(zp0),y` from D64_CHR_HBUF_PTR is ~44 bytes: **18**, at +2 cycles a
  cell (576 cells per path search).

Not worth it (counted, rejected): the 73 word copies `lda a / sta b / lda a+1 / sta b+1` (a helper saves 1
byte a use at best); `lsr ×4` (17 sites, 1 byte each); `ldy #n / lda (p),y / and #m` (27 sites: a helper
saves 0); the (zp),y load/store pairs with a fixed Y (a helper needs the Y anyway); the disco.s save/restore
loops (table-driven: ~25 bytes for much uglier code); the 300 Hz paths (s_interrupcion's two `.repeat 2`,
t_frase's `.repeat 8` scroll): speed matters there.

## Totals

| Class | Items | Bytes |
|---|---|---|
| Low risk, verified | 2, 5, 6, 8, 12 | 182 + 50 + 69 + 29 + 56 = **386** |
| Medium: `.ifdef PRUEBA` fidelity code (no behaviour change in the C64, a design decision) | 3, 4 | 126 + 123 = **249** |
| Medium: the map (the OR table) | 1 | **262** (256 of them in the data zone, freed for code by the packer) |
| Medium: helpers with register/scratch checks per site, speed trade-offs | 7, 9, 10, 11 | 45 + 40 + 59 + 36 = **180** |
| | all | **~1 075** |

The 600-byte minimum is reached with the low-risk items plus either the fidelity code (3 + 4, 635) or the OR
table (1, 648); items 1-6, 8 and 12 together give ~900 without touching any hot loop.  1 500 is not reachable without
slowing the drawing or the searches (7, the `o_n` loop, the interrupt fills) or re-encoding the 2 901 bytes of
script bytecode, which this analysis did not attempt.

## Further checks

* Scratch zero page: 9-11 use zt0/zt0+1 or X/Y and must not be called from sys_tick's callees
  (s_interrupcion, t_frase, txt_draw_char: none of the listed sites is there); 5 touches no register; 2-4 only
  remove code.
* Flags: `sei`/`cli` keep every flag; `addw` returns C from the add as the inline code did; the branch
  inversions keep the flags.
* comprueba.sh: items 2-4 and 1's code part are `.ifdef PRUEBA`, so the checked build and its per-routine
  comparisons are byte-identical; 5-12 change neither results nor the memory the host compares (plat_tinta and
  the disk menu are not under the host; the helpers keep each routine's observable interface).
