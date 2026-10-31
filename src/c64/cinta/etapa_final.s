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

; abadia64ks on tape: the ending's stage, at ETAPA ($C000), read by the KERNAL's "FINAL" (arranque.s, which put
; the game's options in OPCIONES).  The ending's program (ID_FINAL: the parchment with both languages' text,
; crunched with Exomizer) loaded and decrunched to $0801, then run ($080D) with the KERNAL's interrupt on.

        .include "cinta.inc"
.ifdef DISCO
; (the C64's disk, c64/disco64: "FINALZ" loaded with the KERNAL from UNIDAD, the drive "FINAL" came from)
        .include "disco64_gen.inc"      ; FINAL_FIN (made by c64/disco64/construye.sh)
UNIDAD  = $02A8
.else
        .include "cinta_gen.inc"        ; FINAL_FIN: the crunched ending's end (made by construye.sh)
.endif
        .import exo_desde

        .segment "CODE"
.ifdef DISCO
        lda     #nombre_fin - nombre
        ldx     #<nombre
        ldy     #>nombre
        jsr     $FFBD                   ; SETNAM
        lda     #1
        ldx     UNIDAD
        ldy     #1                      ; at its own address
        jsr     $FFBA                   ; SETLFS
        lda     #0
        jsr     $FFD5                   ; LOAD
        bcs     mal
        sei
.else
        sei
        lda     #ID_FINAL
        jsr     T_CARGA
        bcs     mal
.endif
        lda     #$36                    ; the RAM under BASIC visible
        sta     $01
        lda     #<FINAL_FIN
        ldx     #>FINAL_FIN
        jsr     exo_desde
        lda     #$37
        sta     $01
        lda     #$81                    ; the KERNAL's interrupt, as BASIC leaves it for a program
        sta     $DC0D
        lda     $DC0D
        cli
        jmp     $080D                   ; the ending (its BASIC line: SYS 2061)
mal:    inc     $D020
        jmp     mal
.ifdef DISCO
nombre: .byte   $46, $49, $4E, $41, $4C, $5A    ; "FINALZ" in PETSCII
nombre_fin:
.endif
