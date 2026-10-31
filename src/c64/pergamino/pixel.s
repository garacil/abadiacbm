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

; CPC mode 1 bytes on the C64 hires bitmap (_pon_byte_rapido: the page turn's general path), and the page turn
; itself (pagina.s, assembled at the end of this file, so the disk's build needs no change).
;
; A CPC byte holds 4 pixels of 2 bits; pixel i has pen bit (7 - i) | bit (3 - i) << 1.  The parchment
; window starts 32 pixels from the left, so window byte column xb covers screen pixels 4 xb + 32 ..
; + 3: always one half (nibble) of one bitmap byte, of cell column (xb + 8) / 2.  Each 8x8 cell has
; two colours in its screen-RAM byte (fg << 4 | bg).  A pixel whose pen colour (perg_color_pluma) is
; the cell's bg clears its bit, the fg sets it; another colour becomes the cell's fg when the cell
; has a single colour or no bit set, or when it is pen 1 (the dark red back of the turning page,
; which covers the text it passes over); else the pen's stand-in (suplente: 0<->3, 1<->2) is used.
; Bytes of one colour (00, 0F, F0, FF) are decided once for their 4 pixels.
;
; Rows where a capital sprite lies are marked in _perg_fila_cap (bit i: capital i, set by main.c); a byte written
; on such a row calls borra_cap (pagina.s), which clears what the byte covers of the capitals' sprites.

        .export _pon_byte_rapido, _pb_x, _pb_y, _pb_v, _perg_fila_cap
        .import _perg_color_pluma
        .importzp ptr1, ptr2, ptr3, ptr4, tmp1, tmp2, tmp3, tmp4

BITMAP = $A000
CELDAS = $8000

.segment "BSS"
_pb_x:  .res 1
_pb_y:  .res 1
_pb_v:  .res 1
_perg_fila_cap: .res 200
mascara: .res 1         ; the nibble of this byte: $F0 or $0F
fg:     .res 1
bg:     .res 1
pluma:  .res 4          ; the 4 pens

.segment "RODATA"
bm_lo:  .repeat 25, i
        .byte <(BITMAP + i * 320)
        .endrep
bm_hi:  .repeat 25, i
        .byte >(BITMAP + i * 320)
        .endrep
ce_lo:  .repeat 25, i
        .byte <(CELDAS + i * 40)
        .endrep
ce_hi:  .repeat 25, i
        .byte >(CELDAS + i * 40)
        .endrep
c8_lo:  .repeat 40, i
        .byte <(i * 8)
        .endrep
c8_hi:  .repeat 40, i
        .byte >(i * 8)
        .endrep
bits:   .byte $80, $40, $20, $10, $08, $04, $02, $01
suplente: .byte 3, 2, 1, 0
; pen + 1 of the bytes whose 4 pixels have the same pen, else 0
uniforme:
        .repeat 256, v
        .if v = $00
        .byte 1
        .elseif v = $F0
        .byte 2
        .elseif v = $0F
        .byte 3
        .elseif v = $FF
        .byte 4
        .else
        .byte 0
        .endif
        .endrep

.segment "CODE"

.proc _pon_byte_rapido
        ; row = y / 8
        lda     _pb_y
        lsr     a
        lsr     a
        lsr     a
        tax
        ; column of the cell and nibble
        lda     _pb_x
        clc
        adc     #8
        lsr     a               ; C = 1: low nibble
        tay                     ; cell column 0-39
        lda     #$F0
        bcc     :+
        lda     #$0F
:       sta     mascara
        ; ptr1 = the cell's colour byte
        tya
        clc
        adc     ce_lo,x
        sta     ptr1
        lda     ce_hi,x
        adc     #0
        sta     ptr1+1
        ; ptr2 = the bitmap byte: row base + column * 8 + (y & 7)
        lda     c8_lo,y
        clc
        adc     bm_lo,x
        sta     ptr2
        lda     c8_hi,y
        adc     bm_hi,x
        sta     ptr2+1
        lda     _pb_y
        and     #7
        clc
        adc     ptr2
        sta     ptr2
        bcc     :+
        inc     ptr2+1
:       ; the cell's colours
        ldy     #0
        lda     (ptr1),y
        tax
        and     #$0F
        sta     bg
        txa
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        sta     fg
        ; one pen for the 4 pixels?
        ldx     _pb_v
        lda     uniforme,x
        beq     mezcla
        sec
        sbc     #1
        tay                     ; Y = the pen
        jsr     decide          ; C = 1: set the bits, C = 0: clear
        lda     mascara
        bcc     :+
        ldy     #0
        ora     (ptr2),y
        sta     (ptr2),y
        jmp     capitales
:       eor     #$FF
        ldy     #0
        and     (ptr2),y
        sta     (ptr2),y
        jmp     capitales

        ; pixel by pixel
mezcla: ldx     #0
pens:   lda     _pb_v
        and     bits,x          ; bit 7 - i
        beq     :+
        lda     #1
:       sta     tmp4
        lda     _pb_v
        and     bits+4,x        ; bit 3 - i
        beq     :+
        lda     #2
        ora     tmp4
        sta     tmp4
:       lda     tmp4
        sta     pluma,x
        inx
        cpx     #4
        bne     pens
        ldx     #0
pixel:  ldy     pluma,x
        stx     tmp3
        jsr     decide
        ldx     tmp3
        php
        txa
        bit     mascara
        bmi     :+              ; high nibble: bits 7-4
        clc
        adc     #4              ; low nibble: bits 3-0
:       tay
        lda     bits,y
        plp
        bcc     :+
        ldy     #0
        ora     (ptr2),y
        sta     (ptr2),y
        jmp     sig
:       eor     #$FF
        ldy     #0
        and     (ptr2),y
        sta     (ptr2),y
sig:    inx
        cpx     #4
        bne     pixel

capitales:
        jmp     mira_capitales

; Y = a pen -> C = 1 to set its bits (the cell's fg), C = 0 to clear them (bg); may change the cell's fg.
decide: lda     _perg_color_pluma,y
        cmp     bg
        beq     limpia
        cmp     fg
        beq     marca
        sta     tmp4            ; another colour
        lda     fg
        cmp     bg
        beq     nuevo
        cpy     #1
        beq     nuevo
        jsr     vacia
        beq     nuevo
        lda     suplente,y      ; the stand-in pen
        tay
        lda     _perg_color_pluma,y
        cmp     bg
        beq     limpia
marca:  sec
        rts
limpia: clc
        rts
nuevo:  lda     tmp4
        sta     fg
        asl     a
        asl     a
        asl     a
        asl     a
        ora     bg
        ldy     #0
        sta     (ptr1),y
        sec
        rts

; Z = 1 when the 8 bitmap bytes of the cell are all 0.  ptr2 points at line (y & 7) of the cell.
; Uses A, tmp2, ptr3; X and Y are kept.
vacia:  tya
        pha
        lda     _pb_y
        and     #7
        sta     tmp2
        lda     ptr2
        sec
        sbc     tmp2
        sta     ptr3
        lda     ptr2+1
        sbc     #0
        sta     ptr3+1
        lda     #0
        ldy     #7
:       ora     (ptr3),y
        dey
        bpl     :-
        sta     tmp2
        pla
        tay
        lda     tmp2
        rts
.endproc

; after a byte at (_pb_x, _pb_y): when a capital sprite lies on this row, borra_cap (pagina.s) clears what the byte
; covers of it (each capital's byte range, cap_xb_lo .. cap_xb_hi, set by main.c, is checked there)
.proc mira_capitales
        ldx     _pb_y
        lda     _perg_fila_cap,x
        beq     fin
        jmp     borra_cap
fin:    rts
.endproc

; the page turn (CPC 65FDh): pagina.s
        .include "pagina.s"
