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


; "FINAL" on the P500 (abadia128ks for the CBM-II 510, c64/discop500/NOTAS.md): the menu's options, which the game's
; ending left at bank 1's FINAL_OPCIONES (the loader's last stage, c64/discop500/etapa500.s `final`), read into
; opciones500 by a constructor of cc65's start-up (LDA (zp),Y with the 6509's indirect bank register IndReg = 1): the
; ending's language (presentacion.h CINTA_INGLES).

        .export _opciones500, _unidad500
        .constructor lee_opciones500
        .importzp ptr1
        .include "cbm510.inc"           ; ExecReg, IndReg
        .include "disco500.inc"         ; FINAL_OPCIONES

.segment "BSS"
_opciones500: .res 1
_unidad500: .res 1

.segment "ONCE"
lee_opciones500:
        lda     #<FINAL_OPCIONES
        sta     ptr1
        lda     #>FINAL_OPCIONES
        sta     ptr1+1
        lda     #1
        sta     IndReg
        ldy     #0
        lda     (ptr1),y
        ldx     ExecReg
        stx     IndReg
        sta     _opciones500
        rts
