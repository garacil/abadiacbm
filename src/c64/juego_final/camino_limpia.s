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
; abadia64ks, 6502 code of the game: PCG (the speed work's round 5): Adso's marks cleared in
; proportion to what his search marked; its four pieces are declared in mapa64.py (PIEZAS_CAMINO: CODELIMPIA01-04).  ai_update_adso (04EB) searches the screen's height buffer
; every frame (chr_path_room_to_marked from Guillermo's cell to Adso's) and then clears the search's marks with
; chr_path_clear_grid_marks (081E): AND 3Fh over the 576 cells, 7 212 cycles, though the search marked ~23 cells
; and the border.  The marks a search leaves (bits 6-7) are exactly: the border (la_sala: rows 0 and 23, columns 0
; and 23), every cell la_busca queued (each valid cell is marked and queued in the same step; the origin first; a
; target found has its bit 7 cleared again by meta), and chr_path_dest's bit 6 (chr_path_room_to_marked).  The
; queue is still in memory after the search: the words from la_q + 6 up to D64_PATH_QUEUE (positions, and FFFFh
; separators).  memo_limpia clears those cells only, when the buffer is the screen's and it is known clean apart
; from them: m_limpio = 1 after a full clear; 0 in the image (the first clear is a full one) and whenever the
; check-only square test may have marked cells (40C2 := RET: Adso's steps, chr_adso_step_prepare, which now goes
; through m_prep).  Nothing else marks the screen's buffer (the monks' searches run on the path grid, chr_path_build_grid;
; the exit bands and stairs marks too); a fill (chr_fill_height_buffer) clears all 576 cells anyway.  Positions
; outside 0..23 are left alone (the full clear does not touch memory outside the 576 cells either).
; Out (as chr_path_clear_grid_marks): A = 0, BC = 0.
.ifdef VELOZ                    ; (abadia128ks only: the 128ks optimised for speed)
        .include "zp.inc"
        .include "mapa.inc"
        .export memo_limpia, m_prep, m_anota
        .import chr_path_clear_grid_marks

la_q    = $DC                   ; logica_a's: the queue's top - 6 at the end of the search
la_c    = $DE                   ; logica_a's: the cell pointer of la_busca's cuadro
HB      = D64_CHR_HEIGHT_BUFFER

.segment "CODE"
memo_limpia:
        lda     D64_CHR_HBUF_PTR        ; the screen's buffer?
        cmp     #<HB
        bne     m_todo
        lda     D64_CHR_HBUF_PTR+1
        cmp     #>HB
        bne     m_todo
        lda     m_limpio
        beq     m_todo
        jmp     m_prop
m_todo: jsr     chr_path_clear_grid_marks       ; A = 0, BC = 0
        lda     D64_CHR_HBUF_PTR+1      ; the screen's buffer is clean now
        cmp     #>HB
        bne     :+
        lda     #1
        sta     m_limpio
        lda     #0
        sta     m_n                     ; (abadia128ks: the noted cells with it)
:       lda     #0
        rts
m_fin:  lda     #0
        sta     zbc
        sta     zbc+1
        rts

.segment "CODE"
m_prop: ldy     #23                     ; rows 0 and 23
@fila:  lda     HB,y
        and     #$3F
        sta     HB,y
        lda     HB+552,y
        and     #$3F
        sta     HB+552,y
        dey
        bpl     @fila
        lda     #<(HB + 24)             ; columns 0 and 23 of rows 1..22
        sta     zp0
        lda     #>(HB + 24)
        sta     zp0+1
        ldx     #22
@col:   ldy     #0
        lda     (zp0),y
        and     #$3F
        sta     (zp0),y
        ldy     #23
        lda     (zp0),y
        and     #$3F
        sta     (zp0),y
        lda     zp0
        clc
        adc     #24
        sta     zp0
        bcc     :+
        inc     zp0+1
:       dex
        bne     @col
        jmp     m_cola

.segment "CODE"
m_cola: lda     D64_CHR_PATH_DEST       ; chr_path_dest's cell
        ldx     D64_CHR_PATH_DEST+1
        jsr     m_celda
        lda     la_q                    ; the queued cells: the words from la_q + 6 to D64_PATH_QUEUE
        clc
        adc     #6
        sta     zp0+2
        lda     la_q+1
        adc     #0
        sta     zp0+3
@cola:  lda     zp0+3
        cmp     #>D64_PATH_QUEUE
        bne     :+
        lda     zp0+2
        cmp     #<D64_PATH_QUEUE
:       bcs     @fin
        ldy     #1
        lda     (zp0+2),y
        tax
        dey
        lda     (zp0+2),y
        jsr     m_celda
        lda     zp0+2
        clc
        adc     #2
        sta     zp0+2
        bcc     @cola
        inc     zp0+3
        bne     @cola                   ; (always)
@fin:   ldx     m_n                     ; (abadia128ks) the cells the check-only square test marked (m_anota)
        beq     @hecho
@ext:   lda     m_lista-2,x
        sta     zp0
        lda     m_lista-1,x
        sta     zp0+1
        ldy     #0
        lda     (zp0),y
        and     #$3F
        sta     (zp0),y
        dex
        dex
        bne     @ext
        stx     m_n
@hecho:
.ifdef VERIFICA                         ; (the invariant's check, scratch builds only: no mark may be left)
        jsr     m_verifica
.endif
        jmp     m_fin

.segment "CODE"
; m_celda: the cell x = A, y = X of the screen's buffer, when both are in 0..23: its marks cleared.  Uses A X Y, zp0..+1.
m_celda:
        cmp     #24
        bcs     @no
        cpx     #24
        bcs     @no
        clc
        adc     iso_mul24_lo,x
        sta     zp0
        lda     iso_mul24_hi,x
        adc     #0
        sta     zp0+1
        lda     zp0
        clc
        adc     #<HB
        sta     zp0
        lda     zp0+1
        adc     #>HB
        sta     zp0+1
        ldy     #0
        lda     (zp0),y
        and     #$3F
        sta     (zp0),y
@no:    rts
; m_prep: chr_adso_step_prepare's 40C2 := RET.  (On the 64 KiB game's round 5 the check-only square test made the
; next clear a full one; abadia128ks notes the cells it marks instead, m_anota: Adso's step tests run every frame
; in the full game's scenes, and every one of his clears was a full one, 13 % of the time with no keys.)
m_prep: lda     #$C9
        sta     D64_CHR_PATH_SMC_RET
        rts
; m_anota: la_busca's cuadro in the check-only mode (40C2 = RET) has just marked T = (la_c),Y (bit 7): on the
; screen's buffer its address is noted for the next proportional clear (up to NANOTA cells; more: the next clear is
; a full one).  On the path grid nothing (its users clear it whole).  A, X, Y and the flags kept.
NANOTA  = 32
m_anota:
        php
        pha
        lda     D64_CHR_HBUF_PTR
        cmp     #<HB
        bne     @fin
        lda     D64_CHR_HBUF_PTR+1
        cmp     #>HB
        bne     @fin
        stx     m_x
        ldx     m_n
        cpx     #2 * NANOTA
        bcs     @lleno
        tya
        clc
        adc     la_c
        sta     m_lista,x
        lda     la_c+1
        adc     #0
        sta     m_lista+1,x
        inx
        inx
        stx     m_n
@sig:   ldx     m_x
@fin:   pla
        plp
        rts
@lleno: lda     #0
        sta     m_limpio
        beq     @sig
m_n:    .byte   0                       ; 2 x the cells noted
m_x:    .byte   0
m_lista: .res   2 * NANOTA
.ifdef VERIFICA
m_verifica:                             ; every cell without bits 6-7, else m_fallo (counted by the tracer) and a full clear
        ldy     #0
@v:     lda     HB,y
        ora     HB+192,y
        ora     HB+384,y
        and     #$C0
        bne     m_fallo
        iny
        cpy     #192
        bne     @v
        rts
m_fallo:
        jmp     chr_path_clear_grid_marks
        .export m_fallo
.endif
m_limpio:
        .byte   0
        .import iso_mul24_lo, iso_mul24_hi
.endif
