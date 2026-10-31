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


; abadia128ks, the last stage of the game's loading on the C128 (c64/disco128/NOTAS.md), at $C000-$C3E7: the game's
; screen RAM, which its start-up clears (plat_inicio), so nothing of the game's image is there.  The loader in the
; presentation (c64/presentacion/carga128.s) has put into block 1, with the KERNAL: the game's block 0 crunched by
; Exomizer in pieces (J: $0200-$BFFF, $C400-$FEFF, $FF05-$FFFF; the MMU's registers at $FF00-$FF04 and this stage
; left out), the game's zero page and stack page raw (B, at B1_PAGINAS), the game's block 1 (B, from $1000) and, for
; English, the bytes the English image has different (E, at B1_INGLES: block 0's, then block 1's, the texts); then it
; copied this stage here and jumped.
; Here, with no KERNAL any more: the display blanked and the 8502 at 2 MHz (the MMU's CLKRATE $D030 bit 0: the
; VIC-II cannot show anything meanwhile; "Mapping the Commodore 128"), 16 KiB of common RAM at the top ($D506 = $0B:
; $C000-$FFFF always block 0, so this code runs whichever block is mapped), each piece decrunched with Exomizer's own
; decruncher (exodecrunch.s) from block 1 into block 0, the English bytes, the game's two pages, the options
; (plat_opciones, plat_unidad; the sound calls the menu turned off become 3 NOPs), 1 MHz again, and the game.
; The MMU: $3F (block 0, all RAM) while writing, $7F (block 1, all RAM) while reading block 1, $3E (block 0 with the
; I/O) for the I/O.  Interrupts off all along.

        .include "disco128.inc"
        .include "juego128_gen.inc"     ; the pieces' ends, the game's labels (made by piezas128.py)
        .export get_crunched_byte
        .import decrunch

CLKRATE = $D030
MMU_RCR = $D506

; a byte of block 0 (origen,X) into block 1 (destino,X); block 0 mapped again (A, Y clobbered)
.macro FOTO_PAGINA origen, destino
        lda     a:origen,x
        ldy     #$7F
        sty     MMU_CR
        sta     destino,x
        ldy     #$3F
        sty     MMU_CR
.endmacro

.segment "CODE"
inicio: sei
        lda     #$7F                    ; no interrupt from CIA 1, no NMI from CIA 2 (an NMI halfway would find the
        sta     $DC0D                   ;   game's vectors before the game's code is in place)
        sta     $DD0D
        lda     $DC0D
        lda     $DD0D
        lda     #0                      ; nor from the VIC-II
        sta     $D01A
        lda     OPCIONES                ; kept here: the decrunching overwrites both
        sta     opciones
        lda     UNIDAD
        sta     unidad
        lda     #$3E
        sta     MMU_CR
        lda     #$0B                    ; blanked: bitmap mode kept, display off
        sta     $D011
        lda     #$0B                    ; 16 KiB of common RAM at the top
        sta     MMU_RCR
        lda     #1                      ; 2 MHz
        sta     CLKRATE
; the KERNAL's RAM photographed into block 1 (J_FOTO, the game's kernal_foto: plataforma/c128.s reads it): the zero
; page, the stack page, $0200-$03FF, $0A00-$0AFF, $1000-$10FF (no stack used meanwhile)
        lda     #$3F
        sta     MMU_CR
        ldx     #0
foto:   FOTO_PAGINA $0000, J_FOTO
        FOTO_PAGINA $0100, J_FOTO + $100
        FOTO_PAGINA $0200, J_FOTO + $200
        FOTO_PAGINA $0300, J_FOTO + $300
        FOTO_PAGINA $0A00, J_FOTO + $400
        FOTO_PAGINA $1000, J_FOTO + $500
        inx
        bne     foto
        lda     #<PIEZA1_FIN            ; J1's piece: the game's code and most of its data
        sta     fuente
        lda     #>PIEZA1_FIN
        sta     fuente + 1
        jsr     decrunch
        ldx     #0                      ; the KERNAL's page $0A00 back (the game keeps it free: KERNAL128)
:       lda     #$7F
        sta     MMU_CR
        lda     J_FOTO + $400,x
        ldy     #$3F
        sty     MMU_CR
        sta     $0A00,x
        inx
        bne     :-
        lda     unidad                  ; J2 with the game's own KERNAL call (plataforma/c128.s c128_carga: 4 KiB
        sta     J_PLAT_UNIDAD           ;   of common RAM at the bottom meanwhile), where J1 was
        jsr     comun_abajo
        lda     #nombre_j2_fin - nombre_j2
        ldx     #<nombre_j2
        ldy     #>nombre_j2
        jsr     J_CARGA
        bcc     :+
        jmp     error
:       jsr     comun_arriba
        ldx     #NPIEZAS2 - 1           ; J2's pieces, each from its end in block 1
pieza:  lda     piezas_lo,x
        sta     fuente
        lda     piezas_hi,x
        sta     fuente + 1
        txa
        pha
        jsr     decrunch
        pla
        tax
        dex
        bpl     pieza
        lda     opciones
        and     #OPC_INGLES
        beq     paginas
; the English bytes: records (address lo, address hi, length 1-255, the bytes), ended by an address 0: block 0's, then
; block 1's (ingles1)
ingles: jsr     lee1                    ; the address
        sta     destino
        jsr     lee1
        sta     destino + 1
        ora     destino
        beq     ingles1
        jsr     lee1                    ; the length
        tay
:       jsr     lee1
destino = * + 1
        sta     $FFFF
        inc     destino
        bne     :+
        inc     destino + 1
:       dey
        bne     :--
        beq     ingles
ingles1:
        jsr     lee1                    ; the address
        sta     destino1
        jsr     lee1
        sta     destino1 + 1
        ora     destino1
        beq     paginas
        jsr     lee1                    ; the length
        tay
:       jsr     lee1
        ldx     #$7F                    ; block 1
        stx     MMU_CR
destino1 = * + 1
        sta     $FFFF
        ldx     #$3F
        stx     MMU_CR
        inc     destino1
        bne     :+
        inc     destino1 + 1
:       dey
        bne     :--
        beq     ingles1
; the game's zero page ($02-$FF: $00-$01 are the 8502's port) and stack page, from block 1, using no zero page nor
; stack (they are being written)
paginas:
; the Ave Maria, before the game's two pages (the KERNAL's calls use the stack): its samples loaded (c128_carga_ave)
; or its call 3 NOPs (option 4 off, or a load error)
        lda     opciones
        and     #OPC_SIN_AVE
        bne     sin_ave
        jsr     comun_abajo
        jsr     J_CARGA_AVE
        php
        jsr     comun_arriba
        plp
        bcc     con_ave
sin_ave:
        lda     #$EA
        sta     J_AVE
        sta     J_AVE + 1
        sta     J_AVE + 2
con_ave:
        ldx     #2
:       lda     #$7F
        sta     MMU_CR
        lda     B1_PAGINAS,x
        ldy     #$3F
        sty     MMU_CR
        sta     $0000,x
        inx
        bne     :-
:       lda     #$7F
        sta     MMU_CR
        lda     B1_PAGINAS + $100,x
        ldy     #$3F
        sty     MMU_CR
        sta     $0100,x
        inx
        bne     :-
; the options
        lda     opciones
        sta     J_PLAT_OPCIONES
        lda     opciones
        and     #OPC_SIN_PASOS
        beq     :+
        lda     #$0F                    ; the footstep's note a rest: played as before, silent (objetos_sonido.s)
        sta     J_PASO
:       lda     opciones
        and     #OPC_SIN_TEXTO
        beq     :+
        lda     #$0F                    ; the beep's note, the same
        sta     J_PITIDO
:       lda     #$3E
        sta     MMU_CR
        lda     #0                      ; 1 MHz again
        sta     CLKRATE
        jmp     J_PRINCIPAL_INICIO

; the game's common RAM (4 KiB at the bottom: its KERNAL calls map block 1 and bank 15) / this stage's (16 KiB at the
; top) again, block 0 all RAM.  A clobbered
comun_abajo:
        lda     #$3E
        sta     MMU_CR
        lda     #$05
        sta     MMU_RCR
        rts
comun_arriba:
        lda     #$3E
        sta     MMU_CR
        lda     #$0B
        sta     MMU_RCR
        lda     #$3F
        sta     MMU_CR
        rts
error:  lda     #$3E                    ; a load error: the border flashes for ever
        sta     MMU_CR
:       inc     $D020
        jmp     :-

; A = the next byte of block 1 at `ing` (forwards); X, Y kept (no stack while block 1 is mapped)
lee1:   lda     #$7F
        sta     MMU_CR
ing = * + 1
        lda     B1_INGLES
        sta     byte
        lda     #$3F
        sta     MMU_CR
        inc     ing
        bne     :+
        inc     ing + 1
:       lda     byte
        rts

; the previous crunched byte (backwards from `fuente`), for exodecrunch.s: X, Y and the carry kept
get_crunched_byte:
        lda     fuente
        bne     :+
        dec     fuente + 1
:       dec     fuente
        lda     #$7F
        sta     MMU_CR
fuente = * + 1
        lda     $FFFF
        sta     byte
        lda     #$3F
        sta     MMU_CR
        lda     byte
        rts

.segment "RODATA"
piezas_lo: .byte PIEZAS2_LO
piezas_hi: .byte PIEZAS2_HI
nombre_j2: .byte $4A, $32               ; "J2" in PETSCII
nombre_j2_fin:
.segment "BSS"
byte:   .res    1
opciones: .res  1
unidad: .res    1
