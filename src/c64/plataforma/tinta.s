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

; abadia64ks, the C64 platform layer: plat_tinta, the CPC gate array's inks.
;
; plat_tinta: A = pen 0-16 (16 = the border), X = the C64 colour (the game's palette tables hold C64 colours,
; c64/datos/paleta.tsv).  A and X kept, Y clobbered.  Needs the I/O visible ($01 = $35).
;   pen 3  -> $D021 (bit pair 00)
;   pen 0  -> the high nibble of the screen RAM of the game's 32 x 24 cells (bit pair 01)
;   pen 1  -> their low nibble (bit pair 10)
;   pen 2  -> their colour RAM (bit pair 11)
;   pen 16 -> $D020;  pens 4-15: nothing (mode 1 has four pens).
; As on the CPC no pixel is redrawn: the CPC's palette is global, so every game cell gets the same byte (the
; screen RAM byte holds both pens 0 and 1: their colours are kept here).  The cells outside columns 4-35 and
; rows 0-23 are not touched (they stay black: their bitmap bytes are data).  The fill is unrolled by rows: 24
; STA abs,X per column, 32 columns: 4000 cycles; one routine for both targets, its 24 operands' high bytes
; switched between the screen RAM ($C0-$C3) and the colour RAM ($D8-$DB) by EOR $18 when the target changes.

        .include "plat64.inc"
        .export plat_tinta

.segment "DATA"
pen01:  .byte   0, 0                    ; the C64 colours of pens 0 and 1

.segment "CODE"

.proc plat_tinta
        cmp     #16
        beq     borde
        cmp     #3
        bcc     cambia
        bne     fin                     ; pens 4-15, 17-: nothing
        stx     VIC_FONDO
fin:    rts
borde:  stx     VIC_BORDE
        rts
cambia: pha
        txa
        pha
        and     #$0F
        tay                             ; the colour
        tsx
        lda     $0102,x                 ; the pen (0, 1, 2)
        cmp     #2
        beq     tinta2
        tax
        tya
        sta     pen01,x
        lda     pen01                   ; screen RAM byte: pen 0 high, pen 1 low
        asl     a
        asl     a
        asl     a
        asl     a
        ora     pen01+1
        ldy     #>PANTALLA              ; the screen RAM
        bne     llena
tinta2: tya
        ldy     #>COLOR_RAM             ; the colour RAM
llena:  pha                             ; the fill byte
        tya
        eor     filas+2                 ; the operands point to the other target: switch the 24
        and     #$18
        beq     :++
        ldx     #(CELDAS_Y-1)*3
:       lda     filas+2,x
        eor     #$18
        sta     filas+2,x
        dex
        dex
        dex
        bpl     :-
:       pla
        ldx     #CELDAS_X-1
filas:
        .repeat ::CELDAS_Y, r
        sta     PANTALLA + CELDA0 + 40 * r, x
        .endrep
        dex
        bpl     filas
        pla
        tax
        pla
        rts
.endproc
