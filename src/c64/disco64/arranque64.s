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


; abadia64ks, the C64 disk's two KERNAL programs (c64/disco64/NOTAS.md): "ABADIA64KS" (LOAD"ABADIA64KS",8 and RUN, or
; LOAD"*",8 and RUN) and, with -D FINAL, "FINAL" (loaded by the game when it is won at 100 %: plataforma/disco.s
; plat_final, run at $080D).  A BASIC line (10 SYS 2061) and the stage it carries, copied to ETAPA ($C000) and run:
; the menu (c64/cinta/menu.s -D DISCO), or the ending's stage (c64/cinta/etapa_final.s -D DISCO).  "FINAL" first
; takes the game's options from FINAL_OPCIONES ($C3FF, where the game left them, before the copy reaches it) into
; OPCIONES, and the drive it was loaded from (FA) into UNIDAD.

        .include "cinta.inc"
UNIDAD  = $02A8                         ; (cargador.s -D DISCO)

        .segment "LOADADDR"
        .word   $0801
        .segment "CODE"
        .word   siguiente, 10           ; 10 SYS2061
        .byte   $9E, "2061", 0
siguiente:
        .word   0
        sei
.ifdef FINAL
        lda     FINAL_OPCIONES
        sta     OPCIONES
        lda     $BA
        sta     UNIDAD
.endif
        lda     #<etapa                 ; the stage to ETAPA, whole pages ($FB-$FE: free for programs)
        sta     $FB
        lda     #>etapa
        sta     $FC
        lda     #<ETAPA
        sta     $FD
        lda     #>ETAPA
        sta     $FE
        ldx     #PAGINAS
        ldy     #0
:       lda     ($FB),y
        sta     ($FD),y
        iny
        bne     :-
        inc     $FC
        inc     $FE
        dex
        bne     :-
        cli
        jmp     ETAPA

etapa:
.ifdef FINAL
        .incbin "etapa_final.bin"
.else
        .incbin "menu.bin"
.endif
etapa_fin:
PAGINAS = (etapa_fin - etapa + 255) / 256      ; (FINAL_OPCIONES is read before the copy)
