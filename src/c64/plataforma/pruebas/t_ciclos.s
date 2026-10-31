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

; Test of the 300 Hz interrupt and the cost of the calls, measured on the C64 (VICE) with CIA 2's timers, the
; display blanked (no cycles stolen by the VIC-II):
;   - the interrupt: a fixed loop timed with the interrupts off and on (CIA 2 timers A and B cascaded: 32 bits);
;     the difference over the interrupts delivered = the cycles of one interrupt with an empty sys_tick that
;     counts them (inc / bne / rts);
;   - the NMI: CIA 2's timer A raises one (as the RESTORE key would): plat_nmi's RTI returns, the program goes on;
;   - each call (CIA 2 timer A, 16 bits): JSR + routine + RTS, less a bare JSR / RTS.
        .include "plat64.inc"
        .import plat_inicio, plat_psg, plat_teclado_fila, plat_aleatorio, plat_di, plat_ei, plat_modo
        .export sys_tick, b_fin, interrupciones, sin_irq, con_irq, medidas, nmi_ok

.segment "BSS"
interrupciones: .res 2                  ; delivered during the timed loop with the interrupts on
sin_irq: .res 4                         ; the loop's cycles, the interrupts off
con_irq: .res 4                         ; the same, on
medidas: .res 2 * 24                    ; the calls' cycles (see the table `pruebas`)
nmi_ok: .res 1
indice: .res 1

.segment "RODATA"
; the calls measured: routine number, A, X (0: bare JSR/RTS, 1: plat_psg, 2: plat_teclado_fila, 3: plat_aleatorio,
; 4: plat_di, 5: plat_ei, 6: plat_modo)
pruebas:
        .byte   0, 0, 0
        .byte   2, 0, 0                 ; keyboard row 0 (the whole scan), nothing down
        .byte   2, 5, 0                 ; another row
        .byte   1, 7, $3F               ; mixer, nothing changes
        .byte   1, 4, 211               ; channel C fine period
        .byte   1, 5, 4                 ; coarse: P = 1235 (>= 256, shifted), voice silent
        .byte   1, 7, $3B               ; mixer: channel C tone on (gate, frequency)
        .byte   1, 10, 12               ; volume up: gate again
        .byte   1, 10, 9                ; volume down: the sustain level
        .byte   1, 4, 95                ; fine
        .byte   1, 5, 0                 ; coarse: P = 95 (< 128, shifted up), sounding
        .byte   1, 4, 200               ; fine
        .byte   1, 5, 0                 ; coarse: P = 200 (128-255, the table, odd index)
        .byte   1, 4, $AE               ; fine
        .byte   1, 5, $0E               ; coarse: P = 3758 (the longest shift)
        .byte   1, 6, 26                ; noise period
        .byte   1, 7, $33               ; mixer: channel C tone and noise -> noise
        .byte   1, 10, 0                ; volume 0: released
        .byte   1, 7, $3F               ; mixer: all off
        .byte   3, 0, 0
        .byte   4, 0, 0
        .byte   5, 0, 0
        .byte   6, 1, 0
NPRUEBAS = (* - pruebas) / 3

.segment "CODE"
inicio: sei
        ldx     #$FF
        txs
        jsr     plat_inicio
        lda     VIC_D011                ; the display blanked (from the next frame on: wait for it)
        and     #$EF
        sta     VIC_D011
:       bit     VIC_D011
        bpl     :-
:       bit     VIC_D011
        bmi     :-
        ; the loop with the interrupts off
        jsr     cronometro
        jsr     carga
        jsr     lee_crono
        ldx     #3
:       lda     crono,x
        sta     sin_irq,x
        dex
        bpl     :-
        ; the same with the interrupts on
        lda     #0
        sta     interrupciones
        sta     interrupciones+1
        lda     CIA1_ICR                ; a fresh tick
        jsr     cronometro
        cli
        jsr     carga
        sei
        jsr     lee_crono
        ldx     #3
:       lda     crono,x
        sta     con_irq,x
        dex
        bpl     :-
        ; an NMI from CIA 2 timer A
        lda     #0
        sta     nmi_ok
        lda     #<100
        sta     $DD04
        lda     #0
        sta     $DD05
        lda     #$81                    ; timer A's NMI on
        sta     CIA2_ICR
        lda     #$19                    ; one shot, load, start
        sta     $DD0E
        ldx     #0
:       dex                             ; wait for it
        bne     :-
        lda     #$7F
        sta     CIA2_ICR
        lda     CIA2_ICR
        lda     #1
        sta     nmi_ok                  ; reached: the RTI came back
        ; the calls (CIA 1's interrupt off: plat_ei must not let one in)
        lda     #$01
        sta     CIA1_ICR
        lda     CIA1_ICR
        lda     #0
        sta     indice
llamadas:
        lda     indice
        asl     a
        adc     indice
        tay
        lda     pruebas+1,y
        sta     arg_a
        lda     pruebas+2,y
        sta     arg_x
        lda     pruebas,y
        asl     a
        tax
        lda     rutinas,x
        sta     llama+1
        lda     rutinas+1,x
        sta     llama+2
        lda     #$FF
        sta     $DD04
        sta     $DD05
        lda     arg_a
        ldx     arg_x
        ldy     #$11
        sty     $DD0E                   ; start
llama:  jsr     $FFFF
        ldy     #0
        sty     $DD0E                   ; stop
        lda     indice
        asl     a
        tax
        sec
        lda     #$FF
        sbc     $DD04
        sta     medidas,x
        lda     #$FF
        sbc     $DD05
        sta     medidas+1,x
        inc     indice
        lda     indice
        cmp     #NPRUEBAS
        bne     llamadas
        lda     VIC_D011
        ora     #$10
        sta     VIC_D011
b_fin:  jmp     b_fin

rutinas:
        .word   solo_rts, plat_psg, plat_teclado_fila, plat_aleatorio, plat_di, plat_ei, plat_modo

; the workload: 256 x 256 passes of a 10-cycle loop
carga:  ldy     #0
:       ldx     #0
:       nop
        nop
        dex
        bne     :-
        dey
        bne     :--
solo_rts:
        rts

; CIA 2 timers A and B cascaded from $FFFFFFFF
cronometro:
        lda     #0
        sta     $DD0E
        sta     $DD0F
        lda     #$FF
        sta     $DD04
        sta     $DD05
        sta     $DD06
        sta     $DD07
        lda     #$51                    ; B: counts A's underflows, load, start
        sta     $DD0F
        lda     #$11                    ; A: load, start, continuous
        sta     $DD0E
        rts
lee_crono:
        lda     #0
        sta     $DD0E
        sta     $DD0F
        sec
        lda     #$FF
        sbc     $DD04
        sta     crono
        lda     #$FF
        sbc     $DD05
        sta     crono+1
        lda     #$FF
        sbc     $DD06
        sta     crono+2
        lda     #$FF
        sbc     $DD07
        sta     crono+3
        rts

; the stand-in of the game's sys_tick: counts the interrupts
sys_tick:
        inc     interrupciones
        bne     :+
        inc     interrupciones+1
:       rts

.segment "BSS"
crono:  .res 4
arg_a:  .res 1
arg_x:  .res 1
