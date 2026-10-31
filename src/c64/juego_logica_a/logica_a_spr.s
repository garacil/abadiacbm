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

        .export spr_draw_all, spr_mirror_byte, spr_blit_to_screen, spr_rect_union_old, util_mul_al_bx
        .export spr_rect_tile_align, spr_tile_unmark_hook, spr_draw_tiles_in_depth_range, spr_tile_to_buffer
        .export iso_draw_room_spiral, iso_draw_tile
        .export la_fila_lo, la_fila_hi

        .import util_clip_span, plat_ei

TB    = D64_ISO_TILE_BUFFER             ; the tile buffer (CPC 8780h)
TBFIN = D64_ISO_TILE_BUFFER + 1920
TJ    = D64_SPR_TILE_TEST_JUMP          ; 497F (the depth test) or 49AA (draw): Z80 addresses kept as values
LISTA = SPR_SORTED_LIST                 ; the sorted sprite list (the Z80 kept it on its stack), 0-terminated
CPU   = $01                             ; the 6510's port: $34 all RAM, $35 with the I/O

.segment "BSS"
la_cur:   .res 1                        ; the next entry of the list to compose (index)
la_ocur:  .res 1                        ; the next entry of the list to overlay (index)
la_f4w:   .res 2                        ; 4w: a row of cells of the rectangle (C64 bytes)
la_gancho: .res 1                       ; not 0: the final pass (491B = NOP), the drawn marks cleared
la_bal:   .res 1                        ; the tile being drawn
; the merge of a sprite
la_sw:    .res 1                        ; the sprite's C64 stride: ceil(w / 2)
la_n:     .res 1                        ; nibbles a line
la_m:     .res 1                        ; destination bytes a line
la_dp:    .res 1                        ; the destination's start parity (1: low nibble)
la_ult:   .res 1                        ; not 0: the last destination nibble is not drawn
la_esp:   .res 1                        ; not 0: the source is read backwards, mirrored
la_des:   .res 1                        ; not 0: the source stream is half a byte off the destination
la_off:   .res 1                        ; 1: the stream is stored from la_lin + 1
la_k:     .res 1                        ; source bytes a line
la_yl:    .res 1                        ; the destination line within its cell (0-7)
la_lineas: .res 1                       ; lines left
la_cl:    .res 1                        ; the sprite's line counter (the Z80's C from 46A1)
la_ki:    .res 1
la_lin:   .res 36                       ; one line of the source, aligned to the destination
; the light
la_lx:    .res 1
la_ly:    .res 1
la_ls:    .res 2                        ; the address of line la_ly, nibble 0
la_cuenta: .res 2
la_fila:  .res 4                        ; a saved cursor (x, y, line address)

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
; In: A.  Out: A.  (The engine mirrors whole lines through espejo_byte; this is the routine of the table.)
.proc spr_mirror_byte
        tax
        lda     G_TABLA_ESPEJO_NIBBLE,x
        rts
.endproc

; ==== 49E5, 4AC8: a tile ==============================================================================

; tile A merged into the 16 bytes at (zp0+2): tiles 01h-0Ah copied, 0Bh-7Fh pen 2 transparent, 80h-FFh pen 1
; transparent.  The I/O must be off.
.proc la_baldosa
        tax
        asl
        asl
        asl
        asl
        sta     zp0
        txa
        lsr
        lsr
        lsr
        lsr
        ora     #>G_BALDOSAS
        sta     zp0+1
        ldy     #15
        cpx     #$80
        bcs     b
        cpx     #$0B
        bcc     copia
:       lda     (zp0),y
        tax
        lda     (zp0+2),y
        and     G_TABLA_AND_TILE_A,x
        ora     G_TABLA_OR_TILE_A,x
        sta     (zp0+2),y
        dey
        bpl     :-
        rts
b:      lda     (zp0),y
        tax
        lda     (zp0+2),y
        and     G_TABLA_AND_TILE_B,x
        ora     G_TABLA_OR_TILE_B,x
        sta     (zp0+2),y
        dey
        bpl     b
        rts
copia:  lda     (zp0),y
        sta     (zp0+2),y
        dey
        bpl     copia
        rts
.endproc

; 49E5 spr_tile_to_buffer: tile A at the shadow DE (the sprite buffer or the bitmap: 16 consecutive bytes on the
; C64 in both).  The next-line steps of the CPC (4A28/4A2C, 4A44/4A48) are not needed.
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
        ldx     #$34
        stx     CPU
        jsr     la_baldosa
        lda     la_bal
        sta     CPU
        rts
.endproc

; 4AC8 iso_draw_tile: tile A at the bitmap address DE (2 cells).  Out: DE kept.
.proc iso_draw_tile
        ldx     zde
        stx     zp0+2
        ldx     zde+1
        stx     zp0+3
        jmp     la_baldosa_io
.endproc

; ==== 4A5F: the room ==================================================================================

; 4A5F iso_draw_room_spiral: the whole tile buffer drawn to the screen from the centre outwards: from the entry
; 8AAAh and the screen at C21Ch (bitmap row 8, cells 18-19), 8 rounds of runs down, right, up, left
; (iso_spiral_runs: lengths 4, 1, 5, 2, each 2 longer the next round; tile-buffer steps +60h, +6, -60h, -6;
; bitmap steps +320, +16, -320, -16); each entry's background tile [+2], then its foreground tile [+5], when not 0.
; The CPC's next-line steps 07FCh are stored as the Z80 does.
.proc iso_draw_room_spiral
        lda     CPU
        pha
        lda     #$34
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
; tile-buffer entry IX cleared when it lies in the tile buffer.
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

; CF = 0 when la_c lies inside the tile buffer (30FD spr_tile_ptr_check's test, done here)
.proc la_en_tb
        lda     la_c
        cmp     #<TB
        lda     la_c+1
        sbc     #>TB
        bcc     fuera
        lda     la_c
        cmp     #<TBFIN
        lda     la_c+1
        sbc     #>TBFIN
        rts                             ; CF = 1: past the end
fuera:  sec
        rts
.endproc

; 4925 spr_draw_tiles_in_depth_range: the tiles of the rectangle (tile buffer from spr_tile_pos, size
; spr_rect_size) whose depth lies between the previous limit and BC + 0101h: spr_depth_lower := spr_depth_upper,
; spr_depth_upper := (C + 1, B + 1).  The destination starts at spr_cur_buffer, +16 a tile, +4w a row of tiles.
; Per cell spr_tile_test_jump := 497F; per layer (entry bytes 0-2, 3-5: depth x, depth y, tile): tile 0 skipped;
; drawn (bit 7): drawn again only when spr_tile_test_jump = 49AA; else the depth test ((x >= lower.x or y >=
; lower.y) and y < upper.y and x < upper.x): 49AA, bit 7 set when the entry lies in the tile buffer, drawn; after
; each layer the hook (491B, the final pass: the bit cleared again).  Row and cell counts 0 mean 256.
.proc spr_draw_tiles_in_depth_range
        lda     CPU
        pha
        lda     #$34
        sta     CPU
        jsr     la_capas
        pla
        sta     CPU
        rts
.endproc

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
        lda     #0
        ldx     D64_SPR_TILE_UNMARK_HOOK
        bne     :+
        lda     #1
:       sta     la_gancho
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
        jsr     capa
        jsr     capa
        lda     zp0+2
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

; one layer of the entry la_c, then la_c += 3
capa:   ldy     #2
        lda     (la_c),y
        beq     gancho
        sta     la_bal
        ldy     #0
        lda     (la_c),y
        bpl     prueba
        ldx     TJ                      ; drawn already: again only after a layer of this cell passed (49AA)
        cpx     #$AA
        beq     pinta
        bne     gancho
prueba: cmp     D64_SPR_DEPTH_LOWER
        bcs     :+
        ldy     #1
        lda     (la_c),y
        cmp     D64_SPR_DEPTH_LOWER+1
        bcc     gancho
        bcs     :++
:       ldy     #1
        lda     (la_c),y
:       cmp     D64_SPR_DEPTH_UPPER+1
        bcs     gancho
        ldy     #0
        lda     (la_c),y
        cmp     D64_SPR_DEPTH_UPPER
        bcs     gancho
        lda     #$AA
        sta     TJ
        jsr     la_en_tb
        bcs     pinta
        ldy     #0
        lda     (la_c),y
        ora     #$80
        sta     (la_c),y
pinta:  lda     la_bal
        jsr     la_baldosa
gancho: lda     la_gancho               ; 491B: the final pass clears the mark again
        beq     sig
        jsr     la_en_tb
        bcs     sig
        ldy     #0
        lda     (la_c),y
        and     #$7F
        sta     (la_c),y
sig:    lda     la_c
        clc
        adc     #3
        sta     la_c
        bcc     :+
        inc     la_c+1
:       rts

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
fila:   ldy     la_t+3
:       dey
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
fin:    rts
.endproc

; ==== 447D-47E6: the sprites ===========================================================================

; 447D spr_draw_all: composes and draws every sprite that changed.  The active sprites (FE skipped, FF ends)
; listed (the Z80 pushed them on its stack: the last one first), counting those with bit 7; none: EI and out.
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
        lda     #$34
        sta     CPU
otra:   lda     #<D64_SPR_BUFFER
        sta     D64_SPR_BUF_FREE
        lda     #>D64_SPR_BUFFER
        sta     D64_SPR_BUF_FREE+1
        lda     #<D64_SPR_TABLE         ; the list: the active sprites on the 6502 stack, then into LISTA
        sta     la_s
        lda     #>D64_SPR_TABLE
        sta     la_s+1
        ldx     #0                      ; the sprites listed
        stx     la_t                    ; the changed ones
lista:  ldy     #0
        lda     (la_s),y
        cmp     #$FF
        beq     listo
        cmp     #$FE
        beq     :+
        asl
        bcc     no7
        inc     la_t
no7:    lda     la_s
        pha
        lda     la_s+1
        pha
        inx
:       lda     la_s
        clc
        adc     #$14
        sta     la_s
        bcc     lista
        inc     la_s+1
        bne     lista                   ; (always)
listo:  ldy     #0
:       txa
        beq     :+
        pla
        sta     LISTA+1,y
        pla
        sta     LISTA,y
        iny
        iny
        dex
        jmp     :-
:       sta     LISTA,y
        sta     LISTA+1,y
        lda     la_t
        bne     ordena
        pla                             ; nothing changed: EI and out
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
        lda     #$55
        ldx     zde+1
        beq     :++
:       sta     (zp0),y
        iny
        bne     :-
        inc     zp0+1
        dex
        bne     :-
:       ldx     zde
        beq     :++
:       sta     (zp0),y
        iny
        dex
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
        jmp     encima
paso5:  lda     #<D64_SPR_TABLE         ; 47AC: the composed sprites to the screen
        sta     zix
        lda     #>D64_SPR_TABLE
        sta     zix+1
p5:     ldy     #0
        lda     (zix),y
        cmp     #$FF
        beq     de_nuevo
        cmp     #$FE
        beq     p5sig
        and     #$40
        beq     p5sig
        jsr     spr_blit_to_screen
        ldy     #0
        lda     (zix),y
        and     #$3F
        sta     (zix),y
        ldy     #5
        lda     (zix),y
        bpl     p5sig
        and     #$7F
        sta     (zix),y
        ldy     #0
        lda     #$FE
        sta     (zix),y
p5sig:  lda     zix
        clc
        adc     #$14
        sta     zix
        bcc     p5
        inc     zix+1
        bne     p5                      ; (always)
de_nuevo:
        jmp     otra
.endproc

; ==== 4612-4714: one sprite merged into the rectangle ====================================================

; The sprite IY into the rectangle being composed, after the clipping stored in spr_ov_*: the first line of its
; graphic is [IY+7] + skipped lines * stride, or for a monk ([IY+0Bh] bit 7 clear) already past line 10 his robe
; (spr_monk_robes[[IY+0Bh]], bit 14 = mirrored) + (lines - 10) * stride; plus the skipped bytes (mirrored: counted
; from the right, w - skip - 1).  The destination: spr_cur_buffer, line spr_ov_dst_y, byte spr_ov_dst_x.  A graphic
; 0 is the light.  Each line: its nibbles taken from the source (backwards and mirrored for a mirrored robe),
; aligned to the destination's nibble, its edges made transparent, merged (pen 0 transparent).  At sprite line 10 a
; monk switches to his robe.  The Z80's self-modified bytes (46AE, 46C3, 467C, 4703, 46A1, 46C9, 470B) are stored
; as it stores them.
.proc la_mezcla
        lda     #$CC
        sta     D64_SPR_OV_MIRROR_CALL
        lda     #$23
        sta     D64_SPR_OV_SRC_STEP
        lda     #0
        sta     la_esp
        lda     D64_SPR_OV_SRC_Y
        sta     D64_SPR_OV_LINE
        sta     la_cl
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
suma:   ldx     la_sw                   ; + lines * stride + the skipped bytes
        jsr     la_mul
        lda     la_s
        clc
        adc     zt0
        sta     la_s
        lda     la_s+1
        adc     zt0+1
        sta     la_s+1
        lda     D64_SPR_OV_SRC_X
origen: jsr     la_fuente               ; la_s += A / 2, the stream's parity
        ; the destination: spr_cur_buffer + (y >> 3) 4w + (x >> 1) 8 + (y & 7)
        lda     LA_RECT_SIZE
        sta     la_f4w
        lda     #0
        sta     la_f4w+1
        asl     la_f4w
        rol     la_f4w+1
        asl     la_f4w
        rol     la_f4w+1
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
:       ora     la_yl
        clc
        adc     la_q
        sta     la_q
        bcc     :+
        inc     la_q+1
:       lda     D64_SPR_OV_DST_X        ; the line's shape
        and     #1
        sta     la_dp
        lda     D64_SPR_OV_WIDTH        ; (dp + n) & 1 -> la_ult, (dp + n + 1) >> 1 -> la_m (dp + n: 9 bits)
        sta     la_n
        clc
        adc     la_dp
        sta     zt0
        php
        and     #1
        sta     la_ult
        plp
        lda     zt0
        ror
        clc
        adc     la_ult
        sta     la_m
        jsr     la_forma
        lda     D64_SPR_OV_LINES
        sta     la_lineas
linea:  jsr     la_linea
        lda     la_s                    ; the next source line
        clc
        adc     la_sw
        sta     la_s
        bcc     :+
        inc     la_s+1
:       inc     la_cl
        lda     la_cl
        cmp     #10
        bne     baja
        ldy     #$0B
        lda     (ziy),y
        bmi     baja
        ldx     D64_SPR_OV_SRC_X_ROBE   ; line 10 of a monk: his robe
        jsr     la_habito_l
        lda     D64_SPR_OV_SRC_X_ROBE
        jsr     la_fuente
        jsr     la_forma
baja:   lda     la_yl                   ; the next destination line
        cmp     #7
        beq     :+
        inc     la_yl
        inc     la_q
        bne     sig
        inc     la_q+1
        bne     sig                     ; (always)
:       lda     #0
        sta     la_yl
        lda     la_q
        sec
        sbc     #7
        sta     la_q
        bcs     :+
        dec     la_q+1
:       lda     la_q
        clc
        adc     la_f4w
        sta     la_q
        lda     la_q+1
        adc     la_f4w+1
        sta     la_q+1
sig:    dec     la_lineas
        bne     linea
        rts
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

; the line's plan from the stream's parity (zt0+5) and the destination's: shift, offset, source bytes
.proc la_forma
        lda     #0
        sta     la_off
        sta     la_des
        lda     la_m
        sta     la_k
        lda     zt0+5
        cmp     la_dp
        beq     fin
        inc     la_des
        inc     la_k
        bcs     fin                     ; stream parity 1 > destination 0: the stream from la_lin
        inc     la_off                  ; stream 0 < destination 1: from la_lin + 1
fin:    rts
.endproc

; one line: la_k source bytes from la_s into la_lin + la_off (backwards through espejo_byte when mirrored),
; aligned (each byte the low nibble of one and the high nibble of the next), the edges transparent, merged at la_q
; (+8 a byte: the next cell)
.proc la_linea
        ldx     la_off
        lda     la_esp
        bne     espejo
        ldy     #0
:       lda     (la_s),y
        sta     la_lin,x
        inx
        iny
        cpy     la_k
        bne     :-
        jmp     alinea
espejo: lda     la_s                    ; zt0 = la_s - (k - 1): read from index k - 1 down to 0
        sec
        sbc     la_k
        sta     zt0
        lda     la_s+1
        sbc     #0
        sta     zt0+1
        inc     zt0
        bne     :+
        inc     zt0+1
:       ldy     la_k
        dey
:       sty     la_ki
        lda     (zt0),y
        tay
        lda     G_TABLA_ESPEJO_BYTE,y
        sta     la_lin,x
        inx
        ldy     la_ki
        dey
        bpl     :-
alinea: lda     la_des
        beq     bordes
        ldx     #0
:       ldy     la_lin,x
        lda     G_TABLA_NIBBLES,y
        and     #$F0
        sta     zt0
        ldy     la_lin+1,x
        lda     G_TABLA_NIBBLES,y
        and     #$0F
        ora     zt0
        sta     la_lin,x
        inx
        cpx     la_m
        bne     :-
bordes: lda     la_dp
        beq     :+
        lda     la_lin
        and     #$0F
        ora     #$50
        sta     la_lin
:       lda     la_ult
        beq     :+
        ldx     la_m
        lda     la_lin-1,x
        and     #$F0
        ora     #$05
        sta     la_lin-1,x
:       ldx     #0
        ldy     #0
mezcla: lda     la_lin,x
        cmp     #$55
        beq     :+
        stx     la_ki
        tax
        lda     (la_q),y
        and     G_TABLA_AND_SPR,x
        ora     G_TABLA_OR_SPR,x
        sta     (la_q),y
        ldx     la_ki
:       tya
        clc
        adc     #8
        tay
        inx
        cpx     la_m
        bne     mezcla
        rts
.endproc

; ==== 472D-47A9: the light ============================================================================

; the light sprite (graphic 0), composed from the CPC linear offset spr_ov_dst_y * w + spr_ov_dst_x of the
; rectangle (w = its width; the Z80 steps by 14h per line, its own width): a top band of dark bytes (one, then
; spr_light_fill_a more), 15 rows of 4 lines: spr_light_dx dark bytes, 16 bits of the pattern (a 0 bit is dark;
; one more shift first when spr_light_flip holds ADD HL,HL), spr_light_dx_rest dark bytes (0 = 256), the next row
; 50h on; then a bottom band (one, then spr_light_fill_b more).  Dark = pen 3 (nibble 0).  The offsets past the
; rectangle are not drawn (on the CPC they fell into the free part of the buffer).
.proc la_luz
        lda     D64_SPR_OV_DST_X
        sta     la_lx
        lda     D64_SPR_OV_DST_Y
        sta     la_ly
        jsr     la_luz_ls
        lda     D64_SPR_LIGHT_FILL_A
        ldx     D64_SPR_LIGHT_FILL_A+1
        jsr     banda
        lda     #<G_LUZ
        sta     la_p
        lda     #>G_LUZ
        sta     la_p+1
        lda     #15
        sta     la_t
fila:   jsr     guarda                  ; the row's start
        ldy     #0
        lda     (la_p),y
        sta     la_t+2
        iny
        lda     (la_p),y
        sta     la_t+3
        lda     la_p
        clc
        adc     #2
        sta     la_p
        bcc     :+
        inc     la_p+1
:       lda     D64_SPR_LIGHT_DX
        beq     :++
        sta     la_t+1
:       jsr     oscuro4
        dec     la_t+1
        bne     :-
:       lda     D64_SPR_LIGHT_FLIP
        cmp     #$29
        bne     :+
        asl     la_t+3
        rol     la_t+2
:       lda     #16
        sta     la_t+1
:       asl     la_t+3
        rol     la_t+2
        bcs     luz
        jsr     oscuro4
        jmp     :+
luz:    lda     #1
        jsr     la_luz_mas
:       dec     la_t+1
        bne     :--
        lda     D64_SPR_LIGHT_DX_REST
        sta     la_t+1
:       jsr     oscuro4
        dec     la_t+1
        bne     :-
        jsr     repone                  ; the next row: 50h after the row's start
        lda     #$50
        jsr     la_luz_mas
        dec     la_t
        bne     fila
        lda     D64_SPR_LIGHT_FILL_B
        ldx     D64_SPR_LIGHT_FILL_B+1
        jmp     banda

; one dark byte, then XA more (LDIR: 0 = 65536), from the cursor
banda:  sta     la_cuenta
        stx     la_cuenta+1
        jsr     la_oscuro
:       lda     #1
        jsr     la_luz_mas
        jsr     la_oscuro
        lda     la_cuenta
        bne     :+
        dec     la_cuenta+1
:       dec     la_cuenta
        lda     la_cuenta
        ora     la_cuenta+1
        bne     :--
        lda     #1
        jmp     la_luz_mas

; dark at the cursor and 14h, 28h, 3Ch after it; the cursor then one byte on
oscuro4:
        jsr     guarda2
        jsr     la_oscuro
        ldx     #3
:       txa
        pha
        lda     #$14
        jsr     la_luz_mas
        jsr     la_oscuro
        pla
        tax
        dex
        bne     :-
        jsr     repone2
        lda     #1
        jmp     la_luz_mas
guarda: ldx     #3
:       lda     la_lx,x
        sta     la_fila,x
        dex
        bpl     :-
        rts
repone: ldx     #3
:       lda     la_fila,x
        sta     la_lx,x
        dex
        bpl     :-
        rts
guarda2:
        ldx     #3
:       lda     la_lx,x
        sta     zt0+4,x
        dex
        bpl     :-
        rts
repone2:
        ldx     #3
:       lda     zt0+4,x
        sta     la_lx,x
        dex
        bpl     :-
        rts
.endproc

; the light's cursor A bytes on (wrapping at the rectangle's width)
.proc la_luz_mas
        clc
        adc     la_lx
:       cmp     LA_RECT_SIZE
        bcc     fin
        sec
        sbc     LA_RECT_SIZE
        pha
        inc     la_ly
        jsr     la_luz_ls
        pla
        jmp     :-
fin:    sta     la_lx
        rts
.endproc

; la_ls := the address of line la_ly, nibble 0 of the rectangle
.proc la_luz_ls
        lda     la_ly
        lsr
        lsr
        lsr
        ldx     LA_RECT_SIZE
        jsr     la_mul                  ; (y >> 3) w, then * 4
        asl     zt0
        rol     zt0+1
        asl     zt0
        rol     zt0+1
        lda     la_ly
        and     #7
        clc
        adc     zt0
        sta     zt0
        bcc     :+
        inc     zt0+1
:       lda     zt0
        clc
        adc     D64_SPR_CUR_BUFFER
        sta     la_ls
        lda     zt0+1
        adc     D64_SPR_CUR_BUFFER+1
        sta     la_ls+1
        rts
.endproc

; the nibble of the cursor dark (pen 3), when the cursor is inside the rectangle
.proc la_oscuro
        lda     la_ly
        cmp     LA_RECT_SIZE+1
        bcs     fin
        lda     la_lx
        and     #$FE
        asl
        asl
        tay
        lda     la_ls
        sta     zt0
        lda     la_ls+1
        adc     #0
        sta     zt0+1
        bcc     :+
        inc     zt0+1
:       lda     la_lx
        lsr
        lda     #$F0
        bcs     :+
        lda     #$0F
:       and     (zt0),y
        sta     (zt0),y
fin:    rts
.endproc
