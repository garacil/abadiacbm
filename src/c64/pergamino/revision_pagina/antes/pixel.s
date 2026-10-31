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

; CPC mode 1 bytes on the C64 hires bitmap, and the turning corner of the parchment (CPC 686Ch).
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
; Rows where a capital sprite lies are marked in _perg_fila_cap (set by main.c); a byte written on
; such a row calls _borra_capitales (main.c), which clears what the byte covers of the sprite.

        .export _pon_byte_rapido, _pb_x, _pb_y, _pb_v, _esquina_asm, _perg_fila_cap
        .export _es_x, _es_y, _es_b
        .import _perg_color_pluma, _perg_esquina, _borra_capitales, _cap_xb_lo, _cap_xb_hi
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
_es_x:  .res 1          ; esquina_asm arguments
_es_y:  .res 1
_es_b:  .res 1
es_d:   .res 1
es_c:   .res 1
es_b:   .res 1
es_xb:  .res 1
es_pat: .res 1
es_n:   .res 1
es_lenta: .res 1        ; this line has a capital: every byte takes the full path

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
; per CPC byte v and pen p: the bits of the pixels of pen p, in the high nibble (mp<p>) of a bitmap
; byte; the low nibble is the same shifted right 4 (ml<p>)
.macro mascaras_pluma p, nib
        .repeat 256, v
        .byte ((((v >> 7) & 1) | (((v >> 3) & 1) << 1)) = p) * ($80 >> nib) | ((((v >> 6) & 1) | (((v >> 2) & 1) << 1)) = p) * ($40 >> nib) | ((((v >> 5) & 1) | (((v >> 1) & 1) << 1)) = p) * ($20 >> nib) | ((((v >> 4) & 1) | ((v & 1) << 1)) = p) * ($10 >> nib)
        .endrep
.endmacro
mh0:    mascaras_pluma 0, 0
mh1:    mascaras_pluma 1, 0
mh2:    mascaras_pluma 2, 0
mh3:    mascaras_pluma 3, 0
ml0:    mascaras_pluma 0, 4
ml1:    mascaras_pluma 1, 4
ml2:    mascaras_pluma 2, 4
ml3:    mascaras_pluma 3, 4
; window byte column xb (0-63) -> cell column (xb + 8) / 2 and its nibble mask
col_de: .repeat 64, i
        .byte (i + 8) / 2
        .endrep
nib_de: .repeat 64, i
        .if (i + 8) .mod 2
        .byte $0F
        .else
        .byte $F0
        .endif
        .endrep
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

lin_bm = ptr4          ; bitmap row base + (y & 7) of the current line (the cell-colour row base is
                        ; patched into the operand of `ce_op` in rapido)

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

; after a byte at (_pb_x, _pb_y): when a capital sprite lies on this row and this byte column is in its
; range (cap_xb_lo .. cap_xb_hi, set by main.c), borra_capitales (main.c) clears what the byte covers
.proc mira_capitales
        ldx     _pb_y
        lda     _perg_fila_cap,x
        beq     fin
        sta     tmp1
        ldx     #0
bucle:  asl     tmp1            ; bit 7 = capital 0
        bcc     sig
        lda     _pb_x
        cmp     _cap_xb_lo,x
        bcc     sig
        cmp     _cap_xb_hi,x
        beq     :+
        bcs     sig
:       jmp     _borra_capitales
sig:    inx
        lda     tmp1
        bne     bucle
fin:    rts
.endproc

; rapido: A = window byte column, _pb_v = the CPC byte, on the line of linea_ptrs.  When every pen
; of the byte has the colour of the cell's fg or bg, the nibble is written at once (fg pixels set,
; bg pixels cleared); else (or on a line with a capital) the full path _pon_byte_rapido.
.proc rapido
        tax
        ldy     col_de,x
ce_op:  lda     $8000,y         ; the cell's colours (operand patched by linea_ptrs)
        sta     tmp4
        and     #$0F
        sta     bg
        lda     tmp4
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        sta     fg
        stx     tmp3            ; xb
        sty     tmp2            ; cell column
        lda     #0
        sta     tmp1            ; bits to set
        ldx     _pb_v
        ldy     tmp3
        lda     nib_de,y
        bmi     alto
        ; low nibble
        lda     ml0,x
        beq     :+
        ldy     _perg_color_pluma+0
        jsr     una
        ora     tmp1
        sta     tmp1
:       lda     ml1,x
        beq     :+
        ldy     _perg_color_pluma+1
        jsr     una
        ora     tmp1
        sta     tmp1
:       lda     ml2,x
        beq     :+
        ldy     _perg_color_pluma+2
        jsr     una
        ora     tmp1
        sta     tmp1
:       lda     ml3,x
        beq     escribe
        ldy     _perg_color_pluma+3
        jsr     una
        ora     tmp1
        sta     tmp1
        jmp     escribe
alto:   lda     mh0,x
        beq     :+
        ldy     _perg_color_pluma+0
        jsr     una
        ora     tmp1
        sta     tmp1
:       lda     mh1,x
        beq     :+
        ldy     _perg_color_pluma+1
        jsr     una
        ora     tmp1
        sta     tmp1
:       lda     mh2,x
        beq     :+
        ldy     _perg_color_pluma+2
        jsr     una
        ora     tmp1
        sta     tmp1
:       lda     mh3,x
        beq     escribe
        ldy     _perg_color_pluma+3
        jsr     una
        ora     tmp1
        sta     tmp1
escribe:
        ldy     tmp2
        lda     c8_lo,y
        clc
        adc     lin_bm
        sta     ptr2
        lda     c8_hi,y
        adc     lin_bm+1
        sta     ptr2+1
        ldx     tmp3
        lda     nib_de,x
        eor     #$FF
        ldy     #0
        and     (ptr2),y
        ora     tmp1
        sta     (ptr2),y
        lda     tmp3
        sta     _pb_x
        jmp     mira_capitales
lento2: lda     tmp3
lento:  sta     _pb_x
        jmp     _pon_byte_rapido

; A = the pixels of a pen (mask), Y = the pen's colour: A = the mask to set (fg) or 0 (bg); when the
; colour is neither, the caller is abandoned (its return address dropped) for the full path.
una:    cpy     fg
        beq     :+
        cpy     bg
        bne     :++
        lda     #0
:       rts
:       pla
        pla
        jmp     lento2
.endproc

; the line pointers of _pb_y
.proc linea_ptrs
        lda     _pb_y
        lsr     a
        lsr     a
        lsr     a
        tax
        lda     _pb_y
        and     #7
        clc
        adc     bm_lo,x
        sta     lin_bm
        lda     bm_hi,x
        adc     #0
        sta     lin_bm+1
        lda     ce_lo,x
        sta     rapido::ce_op+1
        lda     ce_hi,x
        sta     rapido::ce_op+2
        ldx     _pb_y
        lda     _perg_fila_cap,x
        sta     es_lenta
        rts
.endproc

; void esquina_asm(void): CPC 686Ch, one frame of the turning corner: es_b bands of 4 lines from
; window (es_x, es_y).  In band d, line l: the edge byte perg_esquina[3 - l] at byte d (from x >> 2);
; F0 at byte 0 before it, and in the last band F0 at bytes 0 .. d - 1; 00 after it.
.proc _esquina_asm
        lda     #0
        sta     es_d
        lda     _es_b
        sta     es_b
banda:  lda     #4
        sta     es_c
linea:  ldx     es_c
        lda     _perg_esquina-1,x
        sta     es_pat
        lda     _es_x
        lsr     a
        lsr     a
        sta     es_xb
        lda     _es_y
        sta     _pb_y
        jsr     linea_ptrs
        lda     #$F0
        sta     _pb_v
        lda     es_b
        cmp     #1
        beq     ultima
        lda     es_xb           ; F0 at byte 0, then the edge at byte d
        jsr     rapido
        lda     es_xb
        clc
        adc     es_d
        sta     es_xb
        jmp     borde
ultima: lda     es_d            ; last band: F0 at bytes 0 .. d - 1
        sta     es_n
:       lda     es_n
        beq     borde
        lda     #$F0
        sta     _pb_v
        lda     es_xb
        jsr     rapido
        inc     es_xb
        dec     es_n
        jmp     :-
borde:  lda     es_pat
        sta     _pb_v
        lda     es_xb
        jsr     rapido
        lda     #0
        sta     _pb_v
        lda     es_xb
        clc
        adc     #1
        jsr     rapido
        inc     _es_y
        dec     es_c
        beq     :+
        jmp     linea
:       inc     es_d
        dec     es_b
        beq     :+
        jmp     banda
:       rts
.endproc
