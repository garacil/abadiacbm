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

; abadia64ks on tape: the programs the KERNAL loads (c64/cinta/NOTAS.md), kept short since the KERNAL reads about
; 50 bytes a second.  A BASIC line (10 SYS 2061) and: the turbo core put at $033C, the stage ETAPA_ID read with
; it to ETAPA ($C000) and run.  Two builds: the tape's first program, "ABADIA64KS" (the menu), and with -D
; CINTA_FIN "FINAL" (the ending's stage: loaded by the game's plat_final at the end of the game, from where the
; tape stopped).  A bad block flashes the border for ever.

        .include "cinta.inc"
.ifdef CINTA_FIN
ETAPA_ID = ID_ETAPA_FIN                 ; "FINAL"
.else
ETAPA_ID = ID_MENU                      ; "ABADIA64KS"
.endif

        .segment "LOADADDR"
        .word   $0801
        .segment "CODE"
        .word   siguiente, 10           ; 10 SYS2061
        .byte   $9E, "2061", 0
siguiente:
        .word   0
        sei
        ldx     #191                    ; the turbo core: its first 192 bytes to the cassette buffer,
:       lda     turbo,x                 ; the rest to $02B0 (turbo.cfg)
        sta     T_ABRE,x
        dex
        cpx     #$FF
        bne     :-
        ldx     #fin_turbo - turbo - 193
:       lda     turbo+192,x
        sta     T_PAG2,x
        dex
        bpl     :-
        lda     #$37                    ; BASIC, KERNAL and the I/O (the turbo core needs the I/O)
        sta     $01
.if ETAPA_ID = ID_ETAPA_FIN
        lda     FINAL_OPCIONES          ; "FINAL": the game left the menu's options there (plataforma/disco.s)
        sta     OPCIONES
.endif
        lda     #ETAPA_ID
        jsr     T_CARGA
        bcs     mal
        jmp     ETAPA
mal:    inc     $D020
        jmp     mal

turbo:  .incbin "turbo.bin"
fin_turbo:
        .assert fin_turbo - turbo > 192 && fin_turbo - turbo <= 192 + $50, error, "arranque.s: the turbo core's size"
