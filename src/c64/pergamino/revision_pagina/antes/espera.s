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

; Timing and keyboard helpers of the C64 parchment.
;
; espera(n): the CPC delay loop of the parchment (672Ch: NOP / DEC BC / LD A,B / OR C / JR NZ, n passes,
; 0 = 65536).  Measured on the CPC in the simulator, one pass with the music interrupt takes about
; 9.2 microseconds, i.e. 9.06 C64 (PAL) cycles, and the drawing between two waits is a small part of
; each step.  CIA 2 timer A runs free from $FFFF at the CPU clock.  The waits work as deadlines: each
; one adds n * 9 + n / 16 cycles to the time still owed (`falta`, kept between calls) and waits until
; the timer has run that long since the previous wait, so the time the C64 spends drawing between two
; waits is absorbed and the pace is the CPC's.  An overshoot carried to the next wait is limited to
; 4096 cycles, so a long drawing (the page turn) does not make the text that follows run faster.

        .export _espera, _tecla_espacio
        .importzp ptr1, ptr2, tmp1, tmp2, tmp3

CIA2_TA_LO = $DD04
CIA2_TA_HI = $DD05
CIA2_CRA   = $DD0E

.segment "BSS"
falta:  .res 3          ; cycles still owed (24 bits, signed), kept between waits
antes:  .res 2          ; timer value at the last reading, kept between waits
nueve:  .res 3          ; n * 9

.segment "CODE"

; void __fastcall__ espera(unsigned int n)   (n in A/X)
.proc _espera
        sta     ptr1
        stx     ptr1+1
        ora     ptr1+1
        bne     :+
        lda     #1              ; 0 = 65536 passes
        sta     tmp3
        bne     calcula
:       lda     #0
        sta     tmp3            ; n as 24 bits: ptr1 (lo, mid), tmp3 (hi)
calcula:
        ; the overshoot carried from the previous wait (falta < 0) is limited to -4096
        lda     falta+2
        bpl     :+
        cmp     #$FF
        bne     tope
        lda     falta+1
        cmp     #$F0
        bcs     :+
tope:   lda     #0
        sta     falta
        lda     #$F0
        sta     falta+1
        lda     #$FF
        sta     falta+2
:       ; nueve = n * 9 = n * 8 + n, added to falta
        lda     ptr1
        sta     nueve
        lda     ptr1+1
        sta     nueve+1
        lda     tmp3
        sta     nueve+2
        ldy     #3
:       asl     nueve
        rol     nueve+1
        rol     nueve+2
        dey
        bne     :-
        clc
        lda     nueve
        adc     ptr1
        sta     nueve
        lda     nueve+1
        adc     ptr1+1
        sta     nueve+1
        lda     nueve+2
        adc     tmp3
        sta     nueve+2
        clc
        lda     falta
        adc     nueve
        sta     falta
        lda     falta+1
        adc     nueve+1
        sta     falta+1
        lda     falta+2
        adc     nueve+2
        sta     falta+2
        ; + n / 16
        lda     ptr1+1
        sta     tmp2
        lda     ptr1
        sta     tmp1
        lda     tmp3
        ldy     #4
:       lsr     a
        ror     tmp2
        ror     tmp1
        dey
        bne     :-
        clc
        lda     falta
        adc     tmp1
        sta     falta
        lda     falta+1
        adc     tmp2
        sta     falta+1
        lda     falta+2
        adc     #0
        sta     falta+2
        ; start the free-running timer if it is not running (first wait)
        lda     CIA2_CRA
        and     #$01
        bne     bucle
        lda     #$FF
        sta     CIA2_TA_LO
        sta     CIA2_TA_HI
        lda     #%00010001      ; force load, start, continuous
        sta     CIA2_CRA
        jsr     lee
        sta     antes
        stx     antes+1
bucle:  jsr     lee
        sta     tmp1
        stx     tmp2
        sec                     ; elapsed = antes - now (the timer counts down)
        lda     antes
        sbc     tmp1
        sta     ptr2
        lda     antes+1
        sbc     tmp2
        sta     ptr2+1
        lda     tmp1
        sta     antes
        lda     tmp2
        sta     antes+1
        sec                     ; falta -= elapsed
        lda     falta
        sbc     ptr2
        sta     falta
        lda     falta+1
        sbc     ptr2+1
        sta     falta+1
        lda     falta+2
        sbc     #0
        sta     falta+2
        bpl     bucle           ; still owed
        rts
.endproc

; the timer value, read so that the high byte is consistent: A = lo, X = hi
.proc lee
:       ldx     CIA2_TA_HI
        lda     CIA2_TA_LO
        cpx     CIA2_TA_HI
        bne     :-
        rts
.endproc

; unsigned char tecla_espacio(void): 1 while space (row 7, column 4) is down
.proc _tecla_espacio
        sei
        lda     #%01111111
        sta     $DC00
        lda     $DC01
        ldx     #$FF
        stx     $DC00
        cli
        and     #%00010000
        bne     no
        lda     #1
        ldx     #0
        rts
no:     lda     #0
        tax
        rts
.endproc
