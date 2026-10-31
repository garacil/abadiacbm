; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; This program is free software: you can redistribute it and/or modify it under the terms of the GNU General
; Public License as published by the Free Software Foundation, either version 3 of the License, or (at your
; option) any later version.
;
; This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
; implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
; for more details.
;
; You should have received a copy of the GNU General Public License along with this program.  If not, see
; <https://www.gnu.org/licenses/>.

; abadia64ks, 6502 code of the game: group logica_a, part 3 (Z80 447D-4AC8; C reference juego/f_logica_a.c): the
; sprite engine and the room drawing by tiles.
;
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
        .include "logica_a.inc"
.ifdef P500
        .include "io500.inc"            ; (haz_espera: the VIC-II of bank 15)
.endif

        .export spr_draw_all, spr_blit_to_screen, spr_rect_union_old, util_mul_al_bx, spr_rect_tile_align
        .export iso_draw_room_spiral
.ifdef PRUEBA
        ; the Z80 functions the 6502 game reaches only inside the routines above: their entries for the host's
        ; per-routine checks
        .export spr_mirror_byte, spr_tile_unmark_hook, spr_draw_tiles_in_depth_range, spr_tile_to_buffer
        .export iso_draw_tile
.endif
        .export la_fila_lo, la_fila_hi

        .import util_clip_span, plat_ei

TB    = D64_ISO_TILE_BUFFER             ; the tile buffer (CPC 8780h)
TBFIN = D64_ISO_TILE_BUFFER + 1920
TJ    = D64_SPR_TILE_TEST_JUMP          ; 497F (the depth test) or 49AA (draw): Z80 addresses kept as values
LISTA = SPR_SORTED_LIST                 ; the sorted sprite list (the Z80 kept it on its stack), 0-terminated
CPU   = MEMCFG                             ; the 6510's port: $34 all RAM, $35 with the I/O

.ifdef C128
        .import cab_despues, cab_fin_rect, cab_paso5, cab_q, cab_marca, cab_marca_op, cz_h   ; (cabezas128.s)
        .export haz_espera, la_bsrc, la_bta, la_f4w, la_yl, la_dp
.endif
.segment "BSS"
la_cur:   .res 1                        ; the next entry of the list to compose (index)
la_ocur:  .res 1                        ; the next entry of the list to overlay (index)
la_f4w:   .res 2                        ; 4w: a row of cells of the rectangle (C64 bytes)
.ifdef PRUEBA
la_bal:   .res 1                        ; la_baldosa_io: the CPU port
.endif
; the merge of a sprite
la_sw:    .res 1                        ; the sprite's C64 stride: ceil(w / 2)
la_m:     .res 1                        ; destination bytes a line
la_dp:    .res 1                        ; the destination's start parity (1: low nibble)
la_ult:   .res 1                        ; not 0: the last destination nibble is not drawn
la_esp:   .res 1                        ; not 0: the source is read backwards, mirrored
la_yl:    .res 1                        ; the destination line within its cell (0-7)
la_lineas: .res 1                       ; the lines of the part
la_resto: .res 1                        ; the lines after a monk's switch to his robe (FFh: none)
la_ncel:  .res 1                        ; la_tramo: the cells after the first
; the light
la_mascara: .res 10                    ; one 20-nibble line, repeated four times

.segment "CODE"

; the bitmap address of cell 4, line 0 of each character row (the play area's left edge), rows 0-24
la_fila_lo:
        .repeat 25, r
        .byte   <($E000 + 320 * r + 32)
        .endrepeat
la_fila_hi:
        .repeat 25, r
        .byte   >($E000 + 320 * r + 32)
        .endrepeat

; zt0 (16 bits) = A * X (8 x 8 bits); Y kept
.proc la_mul
        sta     zt0+3
        stx     zt0+2
        lda     #0
        sta     zt0+1
        ldx     #8
:       asl
        rol     zt0+1
        asl     zt0+3
        bcc     :+
        clc
        adc     zt0+2
        bcc     :+
        inc     zt0+1
:       dex
        bne     :--
        sta     zt0
        rts
.endproc

; ==== 48EB-491A: the rectangle helpers ==================================================================

; 48EB util_mul_al_bx: DE = HL * A (8 shift-and-add steps).  Out: DE, HL = HL << 8, A = 0, B = 0.
.proc util_mul_al_bx
        ldx     #0
        stx     zde
        stx     zde+1
        ldx     #8
:       lsr
        bcc     :+
        pha
        lda     zde
        clc
        adc     zhl
        sta     zde
        lda     zde+1
        adc     zhl+1
        sta     zde+1
        pla
:       asl     zhl
        rol     zhl+1
        dex
        bne     :--
        stx     zbc+1
        rts
.endproc

; 48FC spr_rect_tile_align: the tile the rectangle starts in (x & FCh, y & F8h) and its size grown to whole tiles:
; w = (w + (x & 3) + 3) & FCh, h = (h + (y & 7) + 7) & F8h.  In: HL = pos (L = x), DE = size (E = w).
; Out: HL, DE, C = y & 7, B = x & 3, A = the new w.
.proc spr_rect_tile_align
        lda     zhl+1
        and     #7
        sta     zbc
        lda     zhl+1
        and     #$F8
        sta     zhl+1
        lda     zhl
        and     #3
        sta     zbc+1
        lda     zhl
        and     #$FC
        sta     zhl
        lda     zde+1
        clc
        adc     zbc
        clc
        adc     #7
        and     #$F8
        sta     zde+1
        lda     zde
        clc
        adc     zbc+1
        clc
        adc     #3
        and     #$FC
        sta     zde
        rts
.endproc

; 4886 spr_rect_union_old: spr_rect_pos / size grown to cover the old rectangle at HL (L = x) of size DE (E = w),
; re-aligned to tiles (x to 4 bytes, then y to 8 lines), with the 8-bit arithmetic of the original.  Out: A, C,
; DE as the original leaves them.
.proc spr_rect_union_old
        ldx     #0
par:    lda     D64_SPR_RECT_POS,x
        sec
        sbc     zhl,x
        bcc     menor
        sta     zbc                     ; the new one starts after the old one: from the old one's start
        lda     LA_RECT_SIZE,x
        clc
        adc     zbc
        cmp     zde,x
        bcc     :+
        sta     zde,x
:       lda     zhl,x
        and     bajo,x
        sta     zbc
        lda     zhl,x
        and     alto,x
        sta     D64_SPR_RECT_POS,x
        lda     zde,x
        clc
        adc     zbc
alinea: clc
        adc     bajo,x
        and     alto,x
        sta     LA_RECT_SIZE,x
sig:    inx
        cpx     #2
        bne     par
        rts
menor:  eor     #$FF                    ; it starts before: the size grows to the old one's end
        sec
        adc     zde,x
        sta     zbc
        lda     LA_RECT_SIZE,x
        cmp     zbc
        bcs     sig
        lda     zbc
        jmp     alinea
bajo:   .byte   3, 7
alto:   .byte   $FC, $F8
.endproc

; 4717 spr_mirror_byte: on the C64 a sprite byte holds two CPC bytes as nibbles; each nibble's two pixels swapped
; (espejo_nibble): the conversion of the CPC byte mirrored by the Z80 routine, for each of the two.
; In: A.  Out: A.  (The engine mirrors whole lines through its tables; this is the routine of the table, which only
; the host's per-routine checks call: the C64 build leaves it out.)
.ifdef PRUEBA
.proc spr_mirror_byte
        tax
        lda     G_TABLA_ESPEJO_NIBBLE,x
        rts
.endproc
.endif

; ==== 49E5, 4AC8: a tile ==============================================================================

; tile A merged into the 16 bytes at (zp0+2): tiles 01h-0Ah copied (two bytes a step), 0Bh-7Fh pen 2 transparent,
; 80h-FFh pen 1 transparent (the tile read through the patched operand of `src`, the tables' pages patched: the
; AND table's page, the OR table's the next one).  The I/O must be off.
.assert >G_TABLA_OR_TILE_A = >G_TABLA_AND_TILE_A | 1 && >G_TABLA_OR_TILE_B = >G_TABLA_AND_TILE_B | 1 && <G_BALDOSAS = 0, error, "la_baldosa: the tables' pages"
.proc la_baldosa
        tax
        asl
        asl
        asl
        asl
        tay
        txa
        lsr
        lsr
        lsr
        lsr
        ora     #>G_BALDOSAS
        cpx     #$0B
        bcc     copia
        sty     src+1
        sta     src+2
        lda     #>G_TABLA_AND_TILE_A
        cpx     #$80
        bcc     :+
        lda     #>G_TABLA_AND_TILE_B
:       sta     ta+2
        ora     #1
        sta     to+2
        ldy     #15
src:    ldx     $FFFF,y
        lda     (zp0+2),y
ta:     and     G_TABLA_AND_TILE_A,x
to:     ora     G_TABLA_OR_TILE_A,x
        sta     (zp0+2),y
        dey
        bpl     src
.ifdef C128
        bit     cz_h                    ; the C128: a head registered in this rectangle: the tile marked over it
        bmi     :+                      ; (cabezas128.s)
        jmp     cab_marca
:
.endif
        rts
copia:  sty     zp0
        sta     zp0+1
        ldy     #15
:       lda     (zp0),y
        sta     (zp0+2),y
        dey
        lda     (zp0),y
        sta     (zp0+2),y
        dey
        bpl     :-
.ifdef C128
        bit     cz_h                    ; (an opaque tile: all of it)
        bmi     :+
        jmp     cab_marca_op
:
.endif
        rts
.endproc
.ifdef C128
la_bsrc = la_baldosa::src               ; (cabezas128.s cab_marca: the tile's pointer and its AND table)
la_bta  = la_baldosa::ta
.endif

; 49E5 spr_tile_to_buffer: tile A at the shadow DE (the sprite buffer or the bitmap: 16 consecutive bytes on the
; C64 in both).  The next-line steps of the CPC (4A28/4A2C, 4A44/4A48) are not needed.  4AC8 iso_draw_tile: tile A
; at the bitmap address DE (2 cells), DE kept.  (The 6502 game draws its tiles through la_baldosa: only the host's
; per-routine checks call these two, and the C64 build leaves them out.)
.ifdef PRUEBA
.proc spr_tile_to_buffer
        ldx     zde2
        stx     zp0+2
        ldx     zde2+1
        stx     zp0+3
        ; falls into la_baldosa_io
.endproc

; la_baldosa with the I/O switched off around it
.proc la_baldosa_io
        ldx     CPU
        stx     la_bal
        ldx     #MEM_RAM
        stx     CPU
        jsr     la_baldosa
        lda     la_bal
        sta     CPU
        rts
.endproc

.proc iso_draw_tile
        ldx     zde
        stx     zp0+2
        ldx     zde+1
        stx     zp0+3
        jmp     la_baldosa_io
.endproc
.endif

; ==== 4A5F: the room ==================================================================================

; 4A5F iso_draw_room_spiral: the whole tile buffer drawn to the screen from the centre outwards: from the entry
; 8AAAh and the screen at C21Ch (bitmap row 8, cells 18-19), 8 rounds of runs down, right, up, left
; (iso_spiral_runs: lengths 4, 1, 5, 2, each 2 longer the next round; tile-buffer steps +60h, +6, -60h, -6;
; bitmap steps +320, +16, -320, -16); each entry's background tile [+2], then its foreground tile [+5], when not 0.
; The CPC's next-line steps 07FCh are stored as the Z80 does.
.proc iso_draw_room_spiral
        lda     CPU
        pha
        lda     #MEM_RAM
        sta     CPU
        lda     #$FC
        sta     D64_SPR_TILE_DST_SKIP
        sta     D64_SPR_TILE_COPY_SKIP
        lda     #$07
        sta     D64_SPR_TILE_DST_SKIP_HI
        sta     D64_SPR_TILE_COPY_SKIP_HI
        lda     #4
        sta     D64_ISO_SPIRAL_RUNS
        lda     #1
        sta     D64_ISO_SPIRAL_RUNS+4
        lda     #5
        sta     D64_ISO_SPIRAL_RUNS+8
        lda     #2
        sta     D64_ISO_SPIRAL_RUNS+12
        lda     #<(TB + $8AAA - $8780)
        sta     la_c
        lda     #>(TB + $8AAA - $8780)
        sta     la_c+1
        lda     #<($E000 + 320 * 8 + 8 * 18)
        sta     zp0+2
        lda     #>($E000 + 320 * 8 + 8 * 18)
        sta     zp0+3
        lda     #8
        sta     la_t
vuelta: ldx     #0
dir:    lda     D64_ISO_SPIRAL_RUNS,x
        sta     la_t+1
        clc
        adc     #2
        sta     D64_ISO_SPIRAL_RUNS,x
        stx     la_t+2
:       ldy     #2
        lda     (la_c),y
        beq     :+
        jsr     la_baldosa
:       ldy     #5
        lda     (la_c),y
        beq     :+
        jsr     la_baldosa
:       ldx     la_t+2
        lda     la_c
        clc
        adc     D64_ISO_SPIRAL_RUNS+1,x
        sta     la_c
        lda     la_c+1
        adc     D64_ISO_SPIRAL_RUNS+3,x
        sta     la_c+1
        txa
        lsr
        lsr
        tay
        lda     zp0+2
        clc
        adc     paso_lo,y
        sta     zp0+2
        lda     zp0+3
        adc     paso_hi,y
        sta     zp0+3
        dec     la_t+1
        bne     :---
        txa
        clc
        adc     #4
        tax
        cpx     #16
        bne     dir
        dec     la_t
        bne     vuelta
        pla
        sta     CPU
        rts
paso_lo: .byte  <320, <16, <-320, <-16
paso_hi: .byte  >320, >16, >-320, >-16
.endproc

; ==== 491B-49E4: the tiles of the rectangle in a depth range ============================================

; 491B spr_tile_unmark_hook: the byte 491B: C9 (RET) normally; 00 (NOP, the final pass): the drawn bit 7 of the
; tile-buffer entry IX cleared when it lies in the tile buffer.  (Only the host's per-routine checks call it: the
; C64 build leaves it out, la_capas does it inline.)
.ifdef PRUEBA
.proc spr_tile_unmark_hook
        lda     D64_SPR_TILE_UNMARK_HOOK
        cmp     #$C9
        beq     fin
        lda     zix
        sta     la_c
        lda     zix+1
        sta     la_c+1
        jsr     la_en_tb
        bcs     fin
        ldy     #0
        lda     (la_c),y
        and     #$7F
        sta     (la_c),y
fin:    rts
.endproc
.endif

; CF = 0 when la_c lies inside the tile buffer (30FD spr_tile_ptr_check's test, done here); A changed, X and Y kept
.assert >TB + 1 < >TBFIN && <TB > 0, error, "la_en_tb: the tile buffer's first and last pages"
.proc la_en_tb
        lda     la_c+1
        cmp     #>TB
        bcc     fuera                   ; below the buffer's first page
        bne     :+
        lda     #<TB - 1                ; its first page: inside from <TB on
        cmp     la_c
        rts
:       cmp     #>TBFIN
        bcc     dentro                  ; the pages in between (C = 0)
        bne     dentro                  ; past the last page (C = 1)
        lda     la_c                    ; the last page: inside below <TBFIN
        cmp     #<TBFIN
dentro: rts
fuera:  sec
        rts
.endproc

; 4925 spr_draw_tiles_in_depth_range: the tiles of the rectangle (tile buffer from spr_tile_pos, size
; spr_rect_size) whose depth lies between the previous limit and BC + 0101h: spr_depth_lower := spr_depth_upper,
; spr_depth_upper := (C + 1, B + 1).  The destination starts at spr_cur_buffer, +16 a tile, +4w a row of tiles.
; Per cell spr_tile_test_jump := 497F; per layer (entry bytes 0-2, 3-5: depth x, depth y, tile): tile 0 skipped;
; drawn (bit 7): drawn again only when spr_tile_test_jump = 49AA; else the depth test ((x >= lower.x or y >=
; lower.y) and y < upper.y and x < upper.x): 49AA, bit 7 set when the entry lies in the tile buffer, drawn; after
; each layer the hook (491B, the final pass: the bit cleared again).  Row and cell counts 0 mean 256.  (The C64's
; spr_draw_all calls la_capas, with the I/O already off: only the host's per-routine checks call this entry.)
.ifdef PRUEBA
.proc spr_draw_tiles_in_depth_range
        lda     CPU
        pha
        lda     #MEM_RAM
        sta     CPU
        jsr     la_capas
        pla
        sta     CPU
        rts
.endproc
.endif

; la_capas: spr_draw_tiles_in_depth_range with the I/O off.  The cells' entries are 6 bytes apart and at the
; tile buffer's own cell offsets (spr_tile_pos = 8594h + 12 y + 1.5 x, x a multiple of 4), so both layers of a cell
; lie inside the buffer or both outside: la_en_tb tests the cell.  zt0+6: the layer's first byte (0, 3), zt0+7: its
; tile.
.proc la_capas
        lda     D64_SPR_DEPTH_UPPER
        sta     D64_SPR_DEPTH_LOWER
        lda     D64_SPR_DEPTH_UPPER+1
        sta     D64_SPR_DEPTH_LOWER+1
        ldx     zbc
        inx
        stx     D64_SPR_DEPTH_UPPER
        ldx     zbc+1
        inx
        stx     D64_SPR_DEPTH_UPPER+1
        lda     #0
        sta     D64_SPR_TILE_DST_SKIP_HI
        sta     D64_SPR_TILE_COPY_SKIP_HI
        sta     la_f4w+1
        lda     LA_RECT_SIZE
        sec
        sbc     #4
        sta     D64_SPR_TILE_DST_SKIP
        sta     D64_SPR_TILE_COPY_SKIP
        lda     LA_RECT_SIZE            ; 4w
        asl
        rol     la_f4w+1
        asl
        rol     la_f4w+1
        sta     la_f4w
        lda     LA_RECT_SIZE+1
        lsr
        lsr
        lsr
        sta     la_t                    ; rows
        lda     LA_RECT_SIZE
        lsr
        lsr
        sta     la_t+1                  ; cells a row
        lda     #$60                    ; the hook after each layer: RTS, or JSR la_en_tb in the final pass (491B)
        ldx     D64_SPR_TILE_UNMARK_HOOK
        bne     :+
        lda     #$20
:       sta     gancho
        lda     D64_SPR_TILE_POS
        sta     la_p
        lda     D64_SPR_TILE_POS+1
        sta     la_p+1
        lda     D64_SPR_CUR_BUFFER
        sta     la_q
        lda     D64_SPR_CUR_BUFFER+1
        sta     la_q+1
        lda     #$49
        sta     TJ+1
fila:   lda     la_p
        sta     la_c
        lda     la_p+1
        sta     la_c+1
        lda     la_q
        sta     zp0+2
        lda     la_q+1
        sta     zp0+3
        lda     la_t+1
        sta     la_t+2
celda:  lda     #$7F
        sta     TJ
        ldy     #0
        jsr     capa
        ldy     #3
        jsr     capa
        lda     la_c                    ; the next cell: 6 entry bytes on, 16 bytes on in the rectangle
        clc
        adc     #6
        sta     la_c
        bcc     :+
        inc     la_c+1
:       lda     zp0+2
        clc
        adc     #16
        sta     zp0+2
        bcc     :+
        inc     zp0+3
:       dec     la_t+2
        bne     celda
        lda     la_p
        clc
        adc     #$60
        sta     la_p
        bcc     :+
        inc     la_p+1
:       lda     la_q
        clc
        adc     la_f4w
        sta     la_q
        lda     la_q+1
        adc     la_f4w+1
        sta     la_q+1
        dec     la_t
        bne     fila
        rts

; one layer: Y = its first byte in the cell (0, 3)
capa:   sty     zt0+6
        iny
        iny
        lda     (la_c),y                ; its tile: 0, none
        beq     gancho
        sta     zt0+7
        ldy     zt0+6
        lda     (la_c),y                ; depth x, bit 7: drawn
        bpl     prueba
        ldx     TJ                      ; drawn already: again only after a layer of this cell passed (49AA)
        cpx     #$AA
        beq     pinta
        bne     gancho
prueba: cmp     D64_SPR_DEPTH_LOWER
        iny
        bcs     :+
        lda     (la_c),y                ; depth y
        cmp     D64_SPR_DEPTH_LOWER+1
        bcc     gancho
        .byte   $2C                     ; (BIT abs: skips the next LDA)
:       lda     (la_c),y
        cmp     D64_SPR_DEPTH_UPPER+1
        bcs     gancho
        dey
        lda     (la_c),y
        cmp     D64_SPR_DEPTH_UPPER
        bcs     gancho
        lda     #$AA
        sta     TJ
        jsr     la_en_tb
        bcs     pinta
        lda     (la_c),y
        ora     #$80
        sta     (la_c),y
pinta:  lda     zt0+7
        jsr     la_baldosa
gancho: jsr     la_en_tb                ; 491B (RTS but in the final pass): the mark cleared again
        bcs     sig
        ldy     zt0+6
        lda     (la_c),y
        and     #$7F
        sta     (la_c),y
sig:    rts
.endproc

; ==== 47E7: the blit ===================================================================================

; 47E7 spr_blit_to_screen: the composed rectangle of the sprite IX (buffer [IX+10h], x [IX+0Ch] bytes, y [IX+0Dh]
; lines, w [IX+0Eh], h [IX+0Fh]) copied to the screen, clipped to the play area (sprite space: lines 28h-C7h, bytes
; 8-47h): spr_blit_skip, spr_blit_width (low byte), spr_blit_lines as the Z80 computes them; the copy goes by
; rows of cells (the cuts are whole cells: the rectangles are tile-aligned).  A rectangle cut on both sides (wider
; than the play area) is copied right here, where the CPC skipped only the right cut after each line.
.proc spr_blit_to_screen
        lda     #0
        sta     D64_SPR_BLIT_SKIP
        sta     zt0+6                   ; bytes cut on the left
        ldy     #$0D
        lda     (zix),y
        cmp     #$C8
        bcc     :+
        rts
:       sec
        sbc     #$28
        ldy     #$0F
        bcs     abajo
        eor     #$FF
        adc     #1                      ; lines above the play area
        cmp     (zix),y
        bcc     :+
        rts
:       sta     zt0+5                   ; lines cut
        lda     (zix),y
        sec
        sbc     zt0+5
        sta     la_t+1                  ; lines left
        lda     #0
        beq     :+                      ; (always)
abajo:  tax
        lda     (zix),y
        sta     la_t+1
        lda     #0
        sta     zt0+5
        txa
:       sta     la_t                    ; the screen line
        ldy     #$0E
        lda     (zix),y
        sta     la_t+3                  ; the width
        ldy     #$0C
        lda     (zix),y
        cmp     #$48
        bcc     :+
        rts
:       sec
        sbc     #8
        bcs     dentro
        eor     #$FF
        adc     #1                      ; bytes left of the play area
        cmp     la_t+3
        bcc     :+
        rts
:       sta     D64_SPR_BLIT_SKIP
        sta     zt0+6
        lda     la_t+3
        sec
        sbc     zt0+6
        sta     la_t+3
        lda     #0
dentro: sta     la_t+2                  ; the screen byte
        clc
        adc     la_t+3
        sec
        sbc     #$40
        bcc     :+
        sta     D64_SPR_BLIT_SKIP
        eor     #$FF
        sec
        adc     la_t+3
        sta     la_t+3
:       lda     la_t+3
        sta     D64_SPR_BLIT_WIDTH
        lda     la_t+1
        clc
        adc     la_t
        sec
        sbc     #$A0
        bcc     :+
        eor     #$FF
        sec
        adc     la_t+1
        sta     la_t+1
:       lda     la_t+1
        sta     D64_SPR_BLIT_LINES
        ; the source: [IX+10h] + (lines cut / 8) 4w + 4 (bytes cut)
        ldy     #$0E
        lda     (zix),y
        sta     zt0+2                   ; 4w (16 bits) in zt0+2
        lda     #0
        sta     zt0+3
        asl     zt0+2
        rol     zt0+3
        asl     zt0+2
        rol     zt0+3
        ldy     #$10
        lda     (zix),y
        sta     zp0
        iny
        lda     (zix),y
        sta     zp0+1
        lda     zt0+5                   ; whole rows cut
        lsr
        lsr
        lsr
        tax
        beq     :++
:       lda     zp0
        clc
        adc     zt0+2
        sta     zp0
        lda     zp0+1
        adc     zt0+3
        sta     zp0+1
        dex
        bne     :-
:       lda     zt0+6                   ; + 4 (bytes cut on the left)
        asl
        asl
        bcc     :+
        inc     zp0+1
:       clc
        adc     zp0
        sta     zp0
        bcc     :+
        inc     zp0+1
:       lda     la_t                    ; the bitmap: row la_t / 8, byte 4 la_t+2
        lsr
        lsr
        lsr
        tax
        lda     la_t+2
        asl
        asl
        clc
        adc     la_fila_lo,x
        sta     zp0+2
        lda     la_fila_hi,x
        adc     #0
        sta     zp0+3
        lda     la_t+3                  ; bytes a row: 4 (width)
        asl
        asl
        sta     la_t+3
        lda     la_t+1                  ; rows
        lsr
        lsr
        lsr
        tax
        beq     fin
.ifdef C128
        php                             ; (the caller's interrupt flag, back at the end)
        sei                             ; the C128: the check and the copy not interrupted (la_haz)
        jsr     la_haz
.endif
copia:                                  ; (the copy's start: vice/haz.py)
fila:   ldy     la_t+3                  ; (a multiple of 16; 0: 256)
:       dey
        lda     (zp0),y
        sta     (zp0+2),y
        dey
        lda     (zp0),y
        sta     (zp0+2),y
        dey
        lda     (zp0),y
        sta     (zp0+2),y
        dey
        lda     (zp0),y
        sta     (zp0+2),y
        tya
        bne     :-
        lda     zp0
        clc
        adc     zt0+2
        sta     zp0
        lda     zp0+1
        adc     zt0+3
        sta     zp0+1
        lda     zp0+2
        clc
        adc     #<320
        sta     zp0+2
        lda     zp0+3
        adc     #>320
        sta     zp0+3
        dex
        bne     fila
.ifdef C128
        plp
.endif
fin:    rts
.endproc
.ifdef C128
blit_copia = spr_blit_to_screen::copia  ; (for vice/haz.py)
blit_fin = spr_blit_to_screen::fin
        .export blit_copia, blit_fin
.endif

.ifdef C128
; la_haz (the C128; H7's: to see the sprites well they must be drawn under control of
; the screen's raster beam): waits until the raster beam cannot meet the rectangle's lines while they are copied.  In: X =
; its cell rows (kept), la_t = its first play-area line L, la_t+1 its lines n, la_t+3 the bytes of a cell row b; the
; interrupts off.  The copy takes about (14 b + 40) / 63 raster lines a cell row: D = rows * (b / 4 + 1) lines.  The
; play area's line L is the raster line L + 51; the beam must not be in [L + 51 - D - 2, L + 51 + n + 2) when the
; copy starts: in half lines (156 a frame) lo = (L + 49 - D) / 2, + 156 below 0 (wrapped, bit 7 of zt0+1), hi = (L +
; n + 53) / 2 rounded up.  The I/O visible while the beam is read.  A, Y and zt0, zt0+1, zt0+5-zt0+7 changed.
la_haz: stx     zt0+5
        lda     la_t+3
        lsr
        lsr
        adc     #1                      ; (C = 0: b is a multiple of 16)
        sta     zt0+6
        lda     #0
:       clc                             ; D = rows * (b / 4 + 1), at most FFh
        adc     zt0+6
        bcs     :+
        dex
        bne     :-
        .byte   $2C                     ; (BIT abs: skips the LDA)
:       lda     #$FF
        sta     zt0+6
        ldx     zt0+5
        lda     la_t
        clc
        adc     la_t+1
        adc     #53                     ; (L + n <= 160: no carry)
        lsr
        adc     #0                      ; (rounded up)
        sta     zt0+7                   ; hi
        lda     la_t
        clc
        adc     #49
        sec
        sbc     zt0+6
        php
        lsr
        plp
        ldy     #0
        bcs     :+
        adc     #28                     ; (C = 0) (v + 256) / 2 + 28 = v / 2 + 156
        ldy     #$80
:       sty     zt0+1
        sta     zt0
        lda     MEMCFG
        pha
        lda     #MEM_IO
        sta     MEMCFG
        jsr     haz_espera
        pla
        sta     MEMCFG
        rts
; haz_espera (also cabezas128.s's window): waits while the raster line / 2 lies in [zt0, zt0+7) (not wrapped, bit 7
; of zt0+1 clear) or outside [zt0+7, zt0) (wrapped).  The I/O visible.  A changed.
.ifdef P500
; The P500: $D811 and $D812 of bank 15 through the indirect bank register ($01 = 15 while it waits, 0 after; Y on
; the stack, not in P5_Y: an interrupt's macros use that).
haz_espera:
        tya
        pha
        lda     #<(P5_VIC + $11)
        sta     P5_PIO
        lda     #>(P5_VIC + $11)
        sta     P5_PIO+1
        lda     #P5_SISTEMA
        sta     P5_IND
@lee:   ldy     #0
        lda     (P5_PIO),y
        asl
        iny
        lda     (P5_PIO),y
        ror                             ; the raster line / 2
        cmp     zt0+7
        bcs     @alto
        bit     zt0+1                   ; below hi: forbidden when wrapped, or from lo on
        bmi     @lee
        cmp     zt0
        bcs     @lee
        bcc     @fin
@alto:  bit     zt0+1                   ; from hi on: forbidden when wrapped and from lo on
        bpl     @fin
        cmp     zt0
        bcs     @lee
@fin:   lda     #0
        sta     P5_IND
        pla
        tay
        rts
.else
haz_espera:
:       lda     $D011
        asl
        lda     $D012
        ror                             ; the raster line / 2
        cmp     zt0+7
        bcs     @alto
        bit     zt0+1                   ; below hi: forbidden when wrapped, or from lo on
        bmi     :-
        cmp     zt0
        bcs     :-
        rts
@alto:  bit     zt0+1                   ; from hi on: forbidden when wrapped and from lo on
        bpl     @fin
        cmp     zt0
        bcs     :-
@fin:   rts
.endif
.endif

; ==== 447D-47E6: the sprites ===========================================================================

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
        lda     CPU
        pha
        lda     #MEM_RAM
        sta     CPU
otra:   lda     #<D64_SPR_BUFFER
        sta     D64_SPR_BUF_FREE
        lda     #>D64_SPR_BUFFER
        sta     D64_SPR_BUF_FREE+1
        lda     #<D64_SPR_TABLE         ; first a look for a changed sprite (80h-FDh)
        sta     la_s
        lda     #>D64_SPR_TABLE
        sta     la_s+1
        ldy     #0
mira:   lda     (la_s),y
        bpl     :+
        cmp     #$FE
        bcc     cambio
        bne     nada                    ; FFh: the end
:       lda     la_s
        clc
        adc     #$14
        sta     la_s
        bcc     mira
        inc     la_s+1
        bne     mira                    ; (always)
nada:   pla                             ; nothing changed: EI and out
        sta     CPU
        jsr     plat_ei
        lda     la_s
        sta     zhl
        lda     la_s+1
        sta     zhl+1
        lda     #$14
        sta     zde
        lda     #0
        sta     zde+1
        sta     zbc
        rts
cambio: lda     #<D64_SPR_TABLE         ; the list: the active sprites on the 6502 stack, then into LISTA
        sta     la_s
        lda     #>D64_SPR_TABLE
        sta     la_s+1
        ldx     #0                      ; the sprites listed
lista:  lda     (la_s),y
        cmp     #$FE
        bcs     ff                      ; FEh: not active, FFh: the end
        lda     la_s
        pha
        lda     la_s+1
        pha
        inx
sig:    lda     la_s
        clc
        adc     #$14
        sta     la_s
        bcc     lista
        inc     la_s+1
        bne     lista                   ; (always)
ff:     beq     sig
:       pla                             ; (X > 0: a changed sprite is active)
        sta     LISTA+1,y
        pla
        sta     LISTA,y
        iny
        iny
        dex
        bne     :-
        txa
        sta     LISTA,y
        sta     LISTA+1,y
ordena: ldx     #0                      ; one pass: X = the swaps
        ldy     #0
        lda     LISTA
        sta     la_c
        lda     LISTA+1
        sta     la_c+1
par:    lda     LISTA+2,y
        sta     la_s
        lda     LISTA+3,y
        sta     la_s+1
        ora     la_s
        beq     pasada
        sty     la_t+1
        ldy     #0
        lda     (la_s),y
        and     #$3F
        sta     la_t+2
        lda     (la_c),y
        and     #$3F
        ldy     la_t+1
        cmp     la_t+2
        beq     igual
        bcc     igual
        lda     la_s                    ; the lower depth goes up
        sta     LISTA,y
        lda     la_s+1
        sta     LISTA+1,y
        lda     la_c
        sta     LISTA+2,y
        lda     la_c+1
        sta     LISTA+3,y
        inx
        bne     :+                      ; (always)
igual:  lda     la_s
        sta     la_c
        lda     la_s+1
        sta     la_c+1
:       iny
        iny
        bne     par                     ; (always)
pasada: txa
        bne     ordena
        sta     la_cur
compone:
        ldy     la_cur                  ; 44E0: the next sprite of the list
        lda     LISTA,y
        sta     zix
        lda     LISTA+1,y
        sta     zix+1
        iny
        iny
        sty     la_cur
        ora     zix
        bne     :+
        jmp     paso5
:       ldy     #0
        lda     (zix),y
        and     #$BF
        sta     (zix),y
        bpl     compone
        ldy     #1                      ; the new rectangle, aligned
        lda     (zix),y
        sta     zhl
        iny
        lda     (zix),y
        sta     zhl+1
        ldy     #5
        lda     (zix),y
        and     #$7F
        sta     zde
        iny
        lda     (zix),y
        sta     zde+1
        jsr     spr_rect_tile_align
        lda     zde
        sta     LA_RECT_SIZE
        lda     zde+1
        sta     LA_RECT_SIZE+1
        lda     zhl
        sta     D64_SPR_RECT_POS
        lda     zhl+1
        sta     D64_SPR_RECT_POS+1
        ldy     #3                      ; and the old one
        lda     (zix),y
        sta     zhl
        iny
        lda     (zix),y
        sta     zhl+1
        ldy     #9
        lda     (zix),y
        sta     zde
        iny
        lda     (zix),y
        sta     zde+1
        jsr     spr_rect_union_old
        ldy     #$0C
        lda     D64_SPR_RECT_POS
        sta     (zix),y
        iny
        lda     D64_SPR_RECT_POS+1
        sta     (zix),y
        ldx     #12                     ; spr_tile_pos = 8594h + 12 y + 1.5 (x & FCh)
        jsr     la_mul                  ; (A = y)
        lda     D64_SPR_RECT_POS
        and     #$FC
        sta     zt0+4
        lsr
        clc
        adc     zt0+4
        php
        clc
        adc     zt0
        sta     zt0
        lda     zt0+1
        adc     #0
        plp
        adc     #0
        sta     zt0+1
        lda     zt0
        clc
        adc     #<(TB + $8594 - $8780)
        sta     D64_SPR_TILE_POS
        lda     zt0+1
        adc     #>(TB + $8594 - $8780)
        sta     D64_SPR_TILE_POS+1
        ldy     #$0E
        lda     LA_RECT_SIZE
        sta     (zix),y
        sta     zhl
        iny
        lda     LA_RECT_SIZE+1
        sta     (zix),y
        lda     #0
        sta     zhl+1
        lda     LA_RECT_SIZE+1
        jsr     util_mul_al_bx          ; DE = w h, the CPC's bytes
        lda     D64_SPR_BUF_FREE
        sta     D64_SPR_CUR_BUFFER
        sta     zp0
        ldy     #$10
        sta     (zix),y
        lda     D64_SPR_BUF_FREE+1
        sta     D64_SPR_CUR_BUFFER+1
        sta     zp0+1
        iny
        sta     (zix),y
        lda     zp0
        clc
        adc     zde
        sta     D64_SPR_BUF_FREE
        tax
        lda     zp0+1
        adc     zde+1
        sta     D64_SPR_BUF_FREE+1
        bcs     lleno
        cpx     #<D64_PATH_QUEUE
        sbc     #>D64_PATH_QUEUE
        bcc     :+
lleno:  jmp     paso5
:       ldy     #0
        lda     (zix),y
        ora     #$40
        sta     (zix),y
        lsr     zde+1                   ; the C64 rectangle: w h / 2 bytes of pen 0
        ror     zde
        lda     #$55                    ; (a multiple of 16 bytes: four a step)
        ldx     zde+1
        beq     :++
:       sta     (zp0),y
        iny
        sta     (zp0),y
        iny
        sta     (zp0),y
        iny
        sta     (zp0),y
        iny
        bne     :-
        inc     zp0+1
        dex
        bne     :-
:       ldy     zde
        beq     :++
:       dey
        sta     (zp0),y
        dey
        sta     (zp0),y
        dey
        sta     (zp0),y
        dey
        sta     (zp0),y
        bne     :-
:       lda     #0
        sta     D64_SPR_DEPTH_UPPER
        sta     D64_SPR_DEPTH_UPPER+1
        sta     la_ocur
encima: ldy     la_ocur                 ; 4597: the next sprite to overlay
        lda     LISTA,y
        sta     zt0
        lda     LISTA+1,y
        iny
        iny
        sty     la_ocur
        ora     zt0
        bne     :+
        lda     #0                      ; the end: the tiles in front of everything
        sta     D64_SPR_TILE_UNMARK_HOOK
        lda     #$FC
        sta     zbc
        sta     zbc+1
        jsr     la_capas
        lda     #$C9
        sta     D64_SPR_TILE_UNMARK_HOOK
.ifdef C128
        jsr     cab_fin_rect            ; the registered head's image: its black AND NOT what was drawn over it
.endif
        jmp     compone
:       lda     zt0
        sta     ziy
        lda     LISTA-1,y
        sta     ziy+1
        ldy     #5
        lda     (ziy),y
        bmi     encima
        lda     D64_SPR_RECT_POS        ; clipped in x: L = rectangle x, E = its w, H = sprite x, D = its w
        sta     zhl
        lda     LA_RECT_SIZE
        sta     zde
        ldy     #1
        lda     (ziy),y
        sta     zhl+1
        ldy     #5
        lda     (ziy),y
        sta     zde+1
        jsr     util_clip_span
        bcc     encima
        sta     D64_SPR_OV_WIDTH
        lda     zhl+1
        sta     D64_SPR_OV_SRC_X
        sta     D64_SPR_OV_SRC_X_ROBE
        lda     zhl
        sta     D64_SPR_OV_DST_X
        lda     D64_SPR_RECT_POS+1      ; and in y
        sta     zhl
        lda     LA_RECT_SIZE+1
        sta     zde
        ldy     #2
        lda     (ziy),y
        sta     zhl+1
        ldy     #6
        lda     (ziy),y
        sta     zde+1
        jsr     util_clip_span
        bcc     encima
        sta     D64_SPR_OV_LINES
        lda     zhl+1
        sta     D64_SPR_OV_SRC_Y
        lda     zhl
        sta     D64_SPR_OV_DST_Y
        ldy     #$12
        lda     (ziy),y
        sta     zbc
        iny
        lda     (ziy),y
        sta     zbc+1
        jsr     la_capas
        jsr     la_mezcla
.ifdef C128
        jsr     cab_despues             ; a head merged in its own rectangle: registered, its snapshot
.endif
        jmp     encima
paso5:
.ifdef C128
        jsr     cab_paso5               ; the heads' rows and their hardware sprites in one raster window
.endif
        lda     #<D64_SPR_TABLE         ; 47AC: the composed sprites to the screen
        sta     zix
        lda     #>D64_SPR_TABLE
        sta     zix+1
        ldy     #0
p5:     lda     (zix),y
        cmp     #$FE
        bcs     p5ff                    ; FEh: not active, FFh: the end
        and     #$40
        beq     p5sig
        jsr     spr_blit_to_screen
        ldy     #0
        lda     (zix),y
        and     #$3F
        sta     (zix),y
        ldy     #5
        lda     (zix),y
        bpl     p5y
        and     #$7F
        sta     (zix),y
        ldy     #0
        lda     #$FE
        sta     (zix),y
p5y:    ldy     #0
p5sig:  lda     zix
        clc
        adc     #$14
        sta     zix
        bcc     p5
        inc     zix+1
        bne     p5                      ; (always)
p5ff:   beq     p5sig
        jmp     otra
.endproc

; ==== 4612-4714: one sprite merged into the rectangle ====================================================

; The sprite IY into the rectangle being composed, after the clipping stored in spr_ov_*: the first line of its
; graphic is [IY+7] + skipped lines * stride, or for a monk ([IY+0Bh] bit 7 clear) already past line 10 his robe
; (spr_monk_robes[[IY+0Bh]], bit 14 = mirrored) + (lines - 10) * stride; plus the skipped bytes (mirrored: counted
; from the right, w - skip - 1).  The destination: spr_cur_buffer, line spr_ov_dst_y, byte spr_ov_dst_x.  A graphic
; 0 is the light.  The lines are merged by la_tramo; a monk switches to his robe after his line 9 (the Z80 checks
; after each line: the lines up to 9 are one part, the rest another, and the switch is made, its bytes written,
; even when line 9 is the last one).  The Z80's self-modified bytes (46AE, 46C3, 467C, 4703, 46A1, 46C9, 470B) are
; stored as it stores them.
.proc la_mezcla
        lda     #$CC
        sta     D64_SPR_OV_MIRROR_CALL
        lda     #$23
        sta     D64_SPR_OV_SRC_STEP
        lda     #0
        sta     la_esp
        lda     D64_SPR_OV_SRC_Y
        sta     D64_SPR_OV_LINE
        ldy     #5
        lda     (ziy),y
        sta     D64_SPR_OV_SRC_STRIDE
        clc
        adc     #1
        lsr
        sta     la_sw
        lda     LA_RECT_SIZE
        sta     D64_SPR_OV_DST_STRIDE
        lda     D64_SPR_OV_SRC_Y
        cmp     #10
        bcc     liso
        ldy     #$0B
        lda     (ziy),y
        bmi     liso
        ldx     D64_SPR_OV_SRC_X        ; already in the robe: la_s = the robe (the skip mirrored with it)
        jsr     la_habito
        lda     D64_SPR_OV_SRC_Y
        sec
        sbc     #10
        bcs     suma                    ; (always)
liso:   ldy     #7
        lda     (ziy),y
        sta     la_s
        iny
        lda     (ziy),y
        sta     la_s+1
        ora     la_s
        bne     normal
        lda     D64_SPR_OV_SRC_Y        ; graphic 0: the light (nothing to read: a clipped light, not drawn)
        ora     D64_SPR_OV_SRC_Y+1
        ora     D64_SPR_OV_SRC_X
        bne     nada
        jmp     la_luz
nada:   rts
normal: lda     D64_SPR_OV_SRC_Y
suma:   beq     origen                  ; + lines * stride + the skipped bytes
        ldx     la_sw
        jsr     la_mul
        lda     la_s
        clc
        adc     zt0
        sta     la_s
        lda     la_s+1
        adc     zt0+1
        sta     la_s+1
origen: lda     D64_SPR_OV_SRC_X
        jsr     la_fuente               ; la_s += A / 2, the stream's parity
        ; the destination: the cell of the first line, spr_cur_buffer + (y >> 3) 4w + (x >> 1) 8, and its line y & 7
        ; (la_f4w = 4w: la_capas, which runs right before)
        lda     D64_SPR_OV_DST_Y
        and     #7
        sta     la_yl
        lda     D64_SPR_OV_DST_Y
        lsr
        lsr
        lsr
        tax
        lda     D64_SPR_CUR_BUFFER
        sta     la_q
        lda     D64_SPR_CUR_BUFFER+1
        sta     la_q+1
        cpx     #0
        beq     :++
:       lda     la_q
        clc
        adc     la_f4w
        sta     la_q
        lda     la_q+1
        adc     la_f4w+1
        sta     la_q+1
        dex
        bne     :-
:       lda     D64_SPR_OV_DST_X
        and     #$FE
        asl
        asl
        bcc     :+
        inc     la_q+1
:       clc
        adc     la_q
        sta     la_q
        bcc     :+
        inc     la_q+1
:       lda     D64_SPR_OV_DST_X        ; the line's shape
        and     #1
        sta     la_dp
.ifdef C128
        jsr     cab_q                   ; (where the own record's first line goes, for cab_despues)
.endif
        lda     D64_SPR_OV_WIDTH        ; la_m = (dp + n + 1) >> 1 (9 bits), la_ult = not 0 when dp + n is odd
        sec
        adc     la_dp
        ror
        sta     la_m
        lda     #0
        sbc     #0
        sta     la_ult
        lda     D64_SPR_OV_LINES        ; the parts: a monk's lines before his line 10, then the rest
        sta     la_lineas
        ldx     #$FF                    ; la_resto: the lines from his line 10 on (FFh: no switch)
        lda     D64_SPR_OV_SRC_Y
        cmp     #10
        bcs     una
        ldy     #$0B
        lda     (ziy),y
        bmi     una
        lda     #11                     ; (C = 0) 10 - y: the lines before the switch
        sbc     D64_SPR_OV_SRC_Y
        cmp     la_lineas
        beq     :+
        bcs     una                     ; line 10 not reached
:       sta     la_lineas
        eor     #$FF
        sec
        adc     D64_SPR_OV_LINES
        tax
una:    stx     la_resto
        jsr     la_tramo
        ldx     la_resto
        inx
        beq     fin
        ldx     D64_SPR_OV_SRC_X_ROBE   ; line 10 of a monk: his robe
        jsr     la_habito_l
        lda     D64_SPR_OV_SRC_X_ROBE
        jsr     la_fuente
        lda     la_resto
        beq     fin
        lda     la_yl                   ; the destination la_lineas lines down
        clc
        adc     la_lineas
baja:   cmp     #8
        bcc     :+
        tay
        lda     la_q
        clc
        adc     la_f4w
        sta     la_q
        lda     la_q+1
        adc     la_f4w+1
        sta     la_q+1
        tya
        sbc     #7                      ; (C = 0) - 8
        bcs     baja                    ; (always)
:       sta     la_yl
        lda     la_resto
        sta     la_lineas
        jmp     la_tramo
fin:    rts
.endproc

; the robe of the sprite IY at its line 10 (the Z80's 46D3-4708): spr_monk_robes[[IY+0Bh]]; mirrored (bit 14):
; the patches set (46AE = C4h, 46C3 = 2Bh) and the skip X counted from the right (w - X - 1) into the operand A
; points at (4703).  Out: la_s = the robe (C64 address, bit 14 cleared), la_esp.
.proc la_habito_l
        lda     #<D64_SPR_OV_SRC_X_ROBE
        bne     la_habito_c                     ; (always)
.endproc
.proc la_habito
        lda     #<D64_SPR_OV_SRC_X
.endproc
.proc la_habito_c
        sta     zt0+6                   ; the operand to mirror (a zero-page variable)
        ldy     #$0B
        lda     (ziy),y
        asl
        tay
        lda     D64_SPR_MONK_ROBES,y
        sta     la_s
        lda     D64_SPR_MONK_ROBES+1,y
        and     #$BF
        sta     la_s+1
        lda     D64_SPR_MONK_ROBES+1,y
        and     #$40
        beq     fin
        lda     #$C4
        sta     D64_SPR_OV_MIRROR_CALL
        lda     #$2B
        sta     D64_SPR_OV_SRC_STEP
        sta     la_esp
        stx     zt0+7
        ldy     #5
        lda     (ziy),y
        clc
        sbc     zt0+7                   ; w - X - 1
        ldx     zt0+6
        sta     0,x
fin:    rts
.endproc

; la_s += A >> 1 (the source byte of nibble A); la_fuente's parity: the stream starts at nibble A & 1, or for a
; mirrored source (read backwards through espejo_byte) at 1 - (A & 1)
.proc la_fuente
        pha
        lsr
        clc
        adc     la_s
        sta     la_s
        bcc     :+
        inc     la_s+1
:       pla
        and     #1
        ldx     la_esp
        beq     :+
        eor     #1
:       sta     zt0+5                   ; the stream's start parity
        rts
.endproc

; la_tramo: la_lineas lines of the sprite merged into the rectangle (la_s: the source byte of the first line's first
; nibble, zt0+5: that nibble, la_esp: the source mirrored; la_q: the cell of the first line, column 0, la_yl: the
; line in it; la_m bytes a line, la_dp: the first one's high nibble kept, la_ult: the last one's low nibble kept),
; one destination byte column at a time, a cell (8 lines) at a time: X is the source offset (+ la_sw a line), Y the
; line in the cell.  The fetch is patched for the part: the byte as it is (source and destination nibbles
; aligned, not mirrored), or T[(a AND 0Fh) OR (b AND F0h)] with a = the byte at X and b = the next one, or a again:
; T = espejo_byte (mirrored, aligned: b = a), nibbles (shifted: the low nibble of a, then the high nibble of b) or
; espejo_nibble (mirrored and shifted, the line read backwards: the high nibble of b, then the low nibble of a,
; each mirrored; the three tables work on each nibble alone, so one lookup does both).  The edges are made
; transparent (nibble 5), then merged with pen 0 transparent: d = ((d EOR v) AND and_spr[v]) EOR v, the same as
; (d AND and_spr[v]) OR or_spr[v] (or_spr[v] = v AND NOT and_spr[v]).  X stays below 256: (lines - 1) stride + 1
; is at most 118 for the game's sprites (40 lines, 3 bytes: the door; the light is la_luz); the rectangle's
; height (at most F8h) bounds yl + lines.
.proc la_tramo
        lda     la_s
        sta     zp0                     ; zp0: the column's first source byte
        lda     la_s+1
        sta     zp0+1
        lda     zt0+5
        eor     la_dp
        bne     des
        lda     la_esp
        beq     llano
        ldx     #0                      ; mirrored, aligned: espejo_byte of one byte (b = a)
        ldy     #>G_TABLA_ESPEJO_BYTE
        bne     tabla                   ; (always)
des:    lda     la_dp                   ; shifted: column 0 from the byte before when dp (mirrored: when not dp)
        ldy     #>G_TABLA_ESPEJO_NIBBLE
        ldx     la_esp
        bne     :+
        eor     #1
        ldy     #>G_TABLA_NIBBLES
:       lsr                             ; C = 0: one byte back
        lda     zp0
        sbc     #0
        sta     zp0
        bcs     :+
        dec     zp0+1
:       ldx     #1                      ; b: the next byte
tabla:  stx     zt0+4                   ; zt0+4: b's offset from a
        sty     t+2
        lda     #$B0                    ; BCS (never taken): the lookups
        .byte   $2C
llano:  lda     #$90                    ; BCC (always taken): the byte as it is
        sta     br
        lda     la_sw
        sta     paso+1
        lda     la_yl                   ; the cells: (yl + lines - 1) >> 3 after the first, the last ending at
        clc                             ; line ((yl + lines - 1) AND 7) + 1
        adc     la_lineas
        sbc     #0                      ; (C = 0) - 1; C = 1
        tax
        and     #7
        adc     #0
        sta     zt0+6
        txa
        lsr
        lsr
        lsr
        sta     la_ncel
        lda     la_q                    ; zt0: the column's first cell
        sta     zt0
        lda     la_q+1
        sta     zt0+1
        lda     la_m
        sta     zt0+3                   ; the columns left
col:    ldx     #$FF                    ; the edge masks: the first column's high nibble, the last one's low nibble
        lda     zt0+3                   ; made transparent (AND 0Fh / F0h, then OR 55h AND NOT the mask)
        cmp     la_m
        bne     :+
        lda     la_dp
        beq     :+
        ldx     #$0F
:       lda     zt0+3
        cmp     #1
        bne     :+
        lda     la_ult
        beq     :+
        txa
        and     #$F0
        tax
:       stx     am+1
        txa
        eor     #$FF
        and     #$55
        sta     om+1
        lda     zp0
        sta     hd+1
        clc
        adc     zt0+4
        sta     b2+1
        lda     zp0+1
        sta     hd+2
        adc     #0
        sta     b2+2
        lda     zt0
        sta     zp0+2
        lda     zt0+1
        sta     zp0+3
        lda     la_ncel
        sta     zt0+2                   ; the cells left after this one
        ldy     la_yl
        ldx     #0
celda:  lda     zt0+2
        bne     :+
        lda     zt0+6
        .byte   $2C
:       lda     #8
        sta     fin+1
        clc
hd:     lda     $FFFF,x                 ; (C = 0 in the loop)
br:     bcc     cola
        and     #$0F
        sta     zt0+7
b2:     lda     $FFFF,x
        and     #$F0
        ora     zt0+7
        sta     t+1
t:      lda     G_TABLA_NIBBLES
cola:
am:     and     #$FF
om:     ora     #0
        sta     zt0+7
        sta     ta+1
        eor     (zp0+2),y
ta:     and     G_TABLA_AND_SPR
        eor     zt0+7
        sta     (zp0+2),y
        txa
paso:   adc     #0                      ; + la_sw
        tax
        iny
fin:    cpy     #8
        bne     hd
        lda     zt0+2
        beq     sigcol
        dec     zt0+2
        lda     zp0+2                   ; the next cell down: + 4w
        clc
        adc     la_f4w
        sta     zp0+2
        lda     zp0+3
        adc     la_f4w+1
        sta     zp0+3
        ldy     #0
        beq     celda                   ; (always)
sigcol: lda     la_esp                  ; the next column: its source byte (the one before when mirrored), its
        bne     :+                      ; cell 8 bytes on
        inc     zp0
        bne     :+++
        inc     zp0+1
        bne     :+++                    ; (always)
:       lda     zp0
        bne     :+
        dec     zp0+1
:       dec     zp0
:       lda     zt0
        clc
        adc     #8
        sta     zt0
        bcc     :+
        inc     zt0+1
:       dec     zt0+3
        beq     :+
        jmp     col
:       rts
.endproc

; ==== 472D-47A9: the light ============================================================================

; The same CPC light mask, applied two nibbles at a time in the cell-major C64 buffer. spr_place_light and
; tile alignment guarantee even x, fill counts 159/239, dx 0..3 and dx_rest = 4-dx. Each 16-bit pattern row,
; with its dark margins, is expanded to ten byte masks only once, then reused for its four lines. The cursor
; retains the original linear wrapping at the rectangle's width (not at the light's width of 20 nibbles).
; la_q is the destination pointer, la_s the logical x/y; la_f4w was set by la_capas. No multiply per pixel.
.proc la_luz
        lda     D64_SPR_OV_DST_X
        sta     la_s
        lda     D64_SPR_OV_DST_Y
        sta     la_s+1
        lsr
        lsr
        lsr
        ldx     LA_RECT_SIZE
        jsr     la_mul
        asl     zt0
        rol     zt0+1
        asl     zt0
        rol     zt0+1
        lda     la_s+1
        and     #7
        clc
        adc     zt0
        sta     zt0
        bcc     :+
        inc     zt0+1
:       lda     #0
        sta     zt0+3
        lda     la_s
        asl
        rol     zt0+3                  ; even x: x * 4, added to the line address
        asl
        rol     zt0+3
        clc
        adc     zt0
        sta     zt0
        lda     zt0+1
        adc     zt0+3
        sta     zt0+1
        lda     zt0
        clc
        adc     D64_SPR_CUR_BUFFER
        sta     la_q
        lda     zt0+1
        adc     D64_SPR_CUR_BUFFER+1
        sta     la_q+1
        lda     D64_SPR_LIGHT_FILL_A
        jsr     banda
        lda     #<G_LUZ
        sta     la_p
        lda     #>G_LUZ
        sta     la_p+1
        lda     #15
        sta     la_t
fila:   ldy     #0
        lda     (la_p),y
        sta     zt0+4
        iny
        lda     (la_p),y
        sta     zt0+5
        lda     la_p
        clc
        adc     #2
        sta     la_p
        bcc     :+
        inc     la_p+1
:       lda     D64_SPR_LIGHT_FLIP
        cmp     #$29
        bne     :+
        asl     zt0+5
        rol     zt0+4
:       lda     #0
        sta     zt0+6
        ldy     D64_SPR_LIGHT_DX
        beq     expandir
:       lsr     zt0+4
        ror     zt0+5
        ror     zt0+6
        dey
        bne     :-
expandir:
        ldx     #0
:       lda     #0
        asl     zt0+6
        rol     zt0+5
        rol     zt0+4
        rol
        asl     zt0+6
        rol     zt0+5
        rol     zt0+4
        rol
        tay
        lda     mascaras,y
        sta     la_mascara,x
        inx
        cpx     #10
        bne     :-
        lda     #4
        sta     la_t+1
:       ldx     #0
linea:  lda     la_mascara,x
        jsr     aplica
        inx
        cpx     #10
        bne     linea
        dec     la_t+1
        bne     :-
        dec     la_t
        beq     :+
        jmp     fila
:       lda     D64_SPR_LIGHT_FILL_B
        jmp     banda

mascaras:
        .byte   $00, $0F, $F0, $FF

; The original bands have an even length (fill + 1): 160 or 240 CPC nibbles.
banda:  lsr
        tax
        inx
:       lda     #0
        jsr     aplica
        dex
        bne     :-
        rts

; AND mask A into one byte, advance two logical nibbles; X and the pattern scratch are kept.
aplica: ldy     la_s+1
        cpy     LA_RECT_SIZE+1
        bcs     avanza
        cmp     #$FF
        beq     avanza
        ldy     #0
        and     (la_q),y
        sta     (la_q),y
avanza: lda     la_s
        clc
        adc     #2
        cmp     LA_RECT_SIZE
        bcs     nueva
        sta     la_s
        lda     #8
        bne     suma
nueva:  lda     #0
        sta     la_s
        inc     la_s+1
        beq     reinicia                  ; preserve the original 8-bit line cursor's wrap
        lda     la_s+1
        and     #7
        beq     bloque
        lda     la_q
        sec
        sbc     la_f4w
        sta     la_q
        lda     la_q+1
        sbc     la_f4w+1
        sta     la_q+1
        lda     #9
        bne     suma
bloque: lda     #1
suma:   clc
        adc     la_q
        sta     la_q
        bcc     :+
        inc     la_q+1
:       rts
reinicia:
        lda     D64_SPR_CUR_BUFFER
        sta     la_q
        lda     D64_SPR_CUR_BUFFER+1
        sta     la_q+1
        rts
.endproc
