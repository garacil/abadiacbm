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

; The CPC screen on the C64: wscr(addr, v) writes the CPC mode 1 byte v at CPC screen address addr
; (C000h-FFFFh, 64 bytes a line: the game's CRTC setting) into the C64 multicolour bitmap.
;
; CPC address: line in the character row (a >> 11) & 7, row ((a & 7FFh) >> 6), byte column xb = a & 63.
; C64: the 256 CPC pixels are 128 multicolour pixels centred in 160 (4 cells from the left), so the
; byte goes to cell column xb / 2 + 4, high half when xb is even; bitmap address = BITMAP + 320 row +
; 8 column + line.  The byte's 4 pixels become 2 (tabla_pantalla.inc).  Rows 25-31 (outside the
; 200 lines) are ignored.
;
; void __fastcall__ wscr(unsigned int addr, unsigned char v)

        .export _wscr
        .import popax
        .importzp ptr1, tmp1, tmp2, tmp3

BITMAP = $A000                          ; VIC bank 2 (the first stage's layout; to move with the game's map)

.segment "RODATA"
tabla:  .include "tabla_pantalla.inc"
fila_lo: .repeat 25, i
        .byte <(BITMAP + 320 * i)
        .endrep
fila_hi: .repeat 25, i
        .byte >(BITMAP + 320 * i)
        .endrep
col_lo: .repeat 64, i
        .byte <((i / 2 + 4) * 8)
        .endrep
col_hi: .repeat 64, i
        .byte >((i / 2 + 4) * 8)
        .endrep

.segment "CODE"

.proc _wscr
        sta     tmp3                    ; v
        jsr     popax                   ; A = low, X = high byte of the CPC address
        sta     tmp1
        txa
        lsr     a
        lsr     a
        lsr     a
        and     #7
        sta     tmp2                    ; line in the character row
        txa
        and     #$07                    ; off = a & 7FFh: row = off >> 6
        sta     ptr1+1
        lda     tmp1
        asl     a                       ; (off << 2) >> 8 = off >> 6
        rol     ptr1+1
        asl     a
        rol     ptr1+1
        ldx     ptr1+1                  ; row 0-31
        cpx     #25
        bcs     fin
        lda     tmp1
        and     #63
        tay                             ; xb
        lda     fila_lo,x
        clc
        adc     col_lo,y
        sta     ptr1
        lda     fila_hi,x
        adc     col_hi,y
        sta     ptr1+1
        lda     ptr1
        clc
        adc     tmp2
        sta     ptr1
        bcc     :+
        inc     ptr1+1
:       ldx     tmp3
        lda     tabla,x                 ; the 2 multicolour pixels in the low half
        sta     tmp3
        tya
        lsr     a                       ; C = 1: odd column, low half
        ldy     #0
        bcs     bajo
        lda     tmp3
        asl     a
        asl     a
        asl     a
        asl     a
        sta     tmp3
        lda     (ptr1),y
        and     #$0F
        ora     tmp3
        sta     (ptr1),y
fin:    rts
bajo:   lda     (ptr1),y
        and     #$F0
        ora     tmp3
        sta     (ptr1),y
        rts
.endproc
