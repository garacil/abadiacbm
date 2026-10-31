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

; Test of plat_teclado_fila: at the barrier the script sets the keys down and joystick port 2 (VICE snapshot:
; the keyboard matrix and the joystick are part of the machine's state), then the ten rows are read as the
; game's sys_read_keyboard does (rows 0-9, X the counter: plat_teclado_fila must keep X), with the save slot.
        .include "plat64.inc"
        .import plat_inicio, plat_teclado_fila, plat_ranura
        .export sys_tick, b_lee, leidas, ranura

.segment "BSS"
leidas: .res 10                         ; the CPC rows read
ranura: .res 1                          ; plat_ranura after the reading

.segment "CODE"
inicio: sei
        ldx     #$FF
        txs
        jsr     plat_inicio
b_lee:  jmp     b_lee
        ldx     #0
:       txa
        jsr     plat_teclado_fila
        sta     leidas,x
        inx
        cpx     #10
        bne     :-
        lda     plat_ranura
        sta     ranura
        jmp     b_lee

sys_tick:
        rts
