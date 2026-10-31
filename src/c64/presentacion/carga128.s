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


; The C128's game loader (abadia128ks, c64/disco128/NOTAS.md), the presentation's carga_juego on that disk: the
; picture is on the game's screen (gameload), the KERNAL alive (cc65's configuration, $FF00 = $0E).  The game's files
; into block 1 with the KERNAL (SETBNK: A = block 1 for the data, X = block 0 for the name): "B" (the game's zero page
; and stack page, then the game's block 1), "J" (the game's block 0 crunched by Exomizer in pieces), "E" (when English
; was chosen: the bytes of the English image that differ); then the last stage (c64/disco128/etapa128.s) copied to its
; place, $C000 (the game's screen RAM), and started with block 0's RAM visible ($FF00 = $3E): it never returns.  A
; load error flashes the border for ever.

        .export _carga_juego
        .include "disco128.inc"

.segment "RODATA"
etapa:  .incbin "etapa128.bin"
etapa_fin:
LARGO = etapa_fin - etapa
        .assert LARGO <= $03E8, error, "the stage must fit $C000-$C3E7"
nombre_b: .byte $42                     ; "B", "J", "E" in PETSCII (as c1541 wrote them; a string here would be
nombre_j: .byte $4A                     ;  translated by ca65's c128 target into the shifted letters)
nombre_e: .byte $45

.segment "CODE"

.proc _carga_juego
        ldx     #<nombre_b
        ldy     #>nombre_b
        jsr     carga
        ldx     #<nombre_j
        ldy     #>nombre_j
        jsr     carga
        lda     OPCIONES
        and     #OPC_INGLES
        beq     :+
        ldx     #<nombre_e
        ldy     #>nombre_e
        jsr     carga
:       sei
        ldx     #0                      ; the stage to $C000 (the screen editor's ROM: the writes reach the RAM)
:       lda     etapa,x
        sta     $C000,x
        lda     etapa + $100,x
        sta     $C100,x
        lda     etapa + $200,x
        sta     $C200,x
        lda     etapa + $300,x
        sta     $C300,x
        inx
        bne     :-
        lda     #$3E                    ; block 0's RAM with the I/O: the stage visible
        sta     MMU_CR
        jmp     $C000
.endproc

; the one-letter file at X/Y into block 1 at its own address, from the presentation's drive
.proc carga
        stx     nom_lo
        sty     nom_hi
        lda     #1                      ; the data into block 1, the name in block 0
        ldx     #0
        jsr     SETBNK
        lda     #1
        ldx     UNIDAD                  ; (the menu's: the boot drive)
        ldy     #1                      ; at the file's own address
        jsr     SETLFS
        lda     #1
nom_lo = * + 1
        ldx     #0
nom_hi = * + 1
        ldy     #0
        jsr     SETNAM
        lda     #0
        jsr     LOAD
        bcs     mal
        rts
mal:    inc     $D020
        jmp     mal
.endproc
