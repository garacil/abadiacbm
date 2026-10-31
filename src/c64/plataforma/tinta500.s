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


; abadia128ks on the P500: plat_tinta, the CPC gate array's inks (tinta.s's, for the CBM-II's I/O in bank 15).
;
; plat_tinta: A = pen 0-16 (16 = the border), X = the colour.  A and X kept, Y clobbered.
;   pen 3  -> the VIC-II's background ($D821, bank 15)
;   pen 0  -> the high nibble of the screen RAM of the game's 32 x 24 cells (bank 0, as on the C64)
;   pen 1  -> their low nibble
;   pen 2  -> their colour RAM ($D400, bank 15: STA (P5_PIO),Y with $01 = 15, row by row)
;   pen 16 -> the border ($D820);  pens 4-15: nothing.
; The screen RAM's fill is tinta.s's unrolled one (24 STA abs,X a column); the colour RAM's goes through the 6509's
; indirect bank register, 32 STA (zp),Y a row.

        .include "plat64.inc"
        .export plat_tinta

.segment "DATA"
pen01:  .byte   0, 0                    ; the colours of pens 0 and 1

.segment "CODE"

.proc plat_tinta
        cmp     #16
        beq     borde
        cmp     #3
        bcc     cambia
        bne     fin                     ; pens 4-15, 17-: nothing
        pha
        txa
        VIC_STA $21                     ; the background
        tax
        pla
fin:    rts
borde:  pha
        txa
        VIC_STA $20                     ; the border
        tax
        pla
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
        ldx     #CELDAS_X-1
filas:
        .repeat ::CELDAS_Y, r
        sta     PANTALLA + CELDA0 + 40 * r, x
        .endrep
        dex
        bpl     filas
        bmi     vuelve
tinta2: lda     #<(P5_COLOR + CELDA0)   ; the colour RAM, a row of CELDAS_X cells at a time
        sta     P5_PIO
        lda     #>(P5_COLOR + CELDA0)
        sta     P5_PIO+1
        lda     #P5_SISTEMA
        sta     P5_IND
        ldx     #CELDAS_Y
fila:   tya
        ldy     #CELDAS_X-1
:       sta     (P5_PIO),y
        dey
        bpl     :-
        tay                             ; (the colour back in Y)
        lda     P5_PIO
        clc
        adc     #40
        sta     P5_PIO
        bcc     :+
        inc     P5_PIO+1
:       dex
        bne     fila
        lda     #0
        sta     P5_IND
vuelve: pla
        tax
        pla
        rts
.endproc
