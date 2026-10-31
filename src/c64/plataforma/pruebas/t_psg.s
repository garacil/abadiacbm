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

; Test of plat_psg: the 300 Hz interrupt (plat_irq) plays a stream of the game's AY writes (secuencia_ay.py:
; records delta, n, n x (register, value)) through plat_psg, tick by tick, as the game's sys_tick -> snd_interrupt
; does; VICE records the SID (prueba.py compares it with the AY's notes and with the GNU build's synthesis).
; The main code loops reading the keyboard (the game's main loop's work), so the interrupt comes at any point.
        .include "plat64.inc"
        .import plat_inicio, plat_psg, plat_teclado_fila, plat_ei
        .export sys_tick, ticks, terminado

PUNTERO = $FB

.segment "RODATA"
secuencia:
        .incbin "secuencia.bin"

.segment "BSS"
ticks:  .res 2                          ; interrupts delivered
espera: .res 1                          ; ticks to the next record
cuantas: .res 1
terminado: .res 1                       ; 1: the stream has ended
retraso: .res 2                         ; ticks of silence before the stream

.segment "CODE"
inicio: sei
        ldx     #$FF
        txs
        jsr     plat_inicio
        lda     #<secuencia
        sta     PUNTERO
        lda     #>secuencia
        sta     PUNTERO+1
        lda     #0
        sta     ticks
        sta     ticks+1
        sta     terminado
        ldy     #0                      ; one second of silence first (the click of the SID's volume, set by
        lda     (PUNTERO),y             ; plat_inicio, apart from the first note)
        sta     espera
        lda     #<300
        sta     retraso
        lda     #>300
        sta     retraso+1
        jsr     plat_ei
bucle:  lda     #0                      ; the main loop: the keyboard read as the game does
        jsr     plat_teclado_fila
        jmp     bucle

; the stand-in of the game's sys_tick: the record of this tick through plat_psg.  X and Y kept, as the game's
; sys_tick keeps them (plat_irq does not save them)
sys_tick:
        txa
        pha
        tya
        pha
        jsr     registro
        pla
        tay
        pla
        tax
        rts
registro:
        inc     ticks
        bne     :+
        inc     ticks+1
:       lda     retraso                 ; the second of silence
        ora     retraso+1
        beq     :++
        lda     retraso
        bne     :+
        dec     retraso+1
:       dec     retraso
        rts
:       lda     terminado
        bne     fin
        dec     espera
        bne     fin
        ldy     #1
        lda     (PUNTERO),y
        sta     cuantas
        iny
escr:   lda     cuantas
        beq     prox
        lda     (PUNTERO),y             ; register
        pha
        iny
        lda     (PUNTERO),y             ; value
        tax
        iny
        pla
        sty     guarda_y
        jsr     plat_psg
        ldy     guarda_y
        dec     cuantas
        jmp     escr
prox:   tya                             ; the next record
        clc
        adc     PUNTERO
        sta     PUNTERO
        bcc     :+
        inc     PUNTERO+1
:       ldy     #0
        lda     (PUNTERO),y
        sta     espera
        bne     fin
        lda     #1                      ; delta 0: the end
        sta     terminado
fin:    rts

.segment "BSS"
guarda_y: .res 1
