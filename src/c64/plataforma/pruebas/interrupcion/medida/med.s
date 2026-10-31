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

; abadia64ks, a measurement only (pruebas/medida/medida.sh), never part of the game: the cycles of the window
; around plat_irq's JSR sys_tick, timed with CIA 1 timer B (latch FFFFh, continuous: the game does not use it).
; med_ini at $0100: T0 = TB; med_fin at $0114: ACC += T0 - TB, N += 1.  They clobber A, X and Y (the measuring
; plat_irq saves them outside the window).  The stack page's bottom is free in the C64 build: the game's stack
; stays above $01B0 (mide.py checks it): this code at $0100-$015F, the measuring plat_irq at $0160-$0187, these
; variables at $0188-$0192.  ($079D-$07FF is the build's BAJO now; $C3E8-$C3FF, where the variables were, is
; written by the game.)
ACC = $0188             ; 4 bytes
N   = $018C             ; 3 bytes
T0  = $018F             ; 2 bytes
TMP = $0191             ; 2 bytes
TBL = $DC06
TBH = $DC07
.segment "CODE"
med_ini:
:       lda     TBH
        ldx     TBL
        cmp     TBH
        bne     :-
        stx     T0
        sta     T0+1
        rts
        .res    $14 - (* - med_ini), $EA
med_fin:
:       lda     TBH
        ldx     TBL
        cmp     TBH
        bne     :-
        sta     TMP+1
        txa
        eor     #$FF            ; T0 - TB = T0 + ~TB + 1
        sec
        adc     T0
        tax
        lda     TMP+1
        eor     #$FF
        adc     T0+1
        tay
        clc
        txa
        adc     ACC
        sta     ACC
        tya
        adc     ACC+1
        sta     ACC+1
        bcc     :+
        inc     ACC+2
        bne     :+
        inc     ACC+3
:       inc     N
        bne     :+
        inc     N+1
        bne     :+
        inc     N+2
:       rts
