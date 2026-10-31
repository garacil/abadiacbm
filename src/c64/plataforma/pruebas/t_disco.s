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

; Test of the disk calls with drive 8 (VICE's true drive emulation, a .d64 attached):
;   the zero page $02-$FF and $0200-$03FF full of a pattern (as the game's variables there), a 1500-byte block
;   at $9CCD (the game's D64_STATE_BUFFER) full of another; slot "3" (as if the digit key 3 was pressed);
;   save -> the zero page and $0200-$03FF intact; the block cleared, load -> the block back, intact again;
;   a slot with no file ("7") -> C = 1; a second save over the first (the old file scratched) and its load;
;   the interrupt still delivered after it all; the stack page below the SP marked to see how deep the KERNAL
;   went (its bottom, $0100-$01AE, is where the KERNAL's part of the zero page and pages 2-3 waits).
; With -DSOLO_FINAL: plat_final at once (the ending parchment "FINAL" loaded and run).
        .include "plat64.inc"
        .include "zp.inc"
        .import plat_inicio, plat_disco_guarda, plat_disco_carga, plat_final, plat_ranura, plat_ei, plat_di
        .export sys_tick, b_fin, resultados, ticks

BLOQUE  = $9CCD
LARGO   = 1500

.segment "BSS"
resultados: .res 16
copia:  .res $0400                      ; $0000-$03FF as they were before a call
ticks:  .res 2
patron: .res 1

.segment "CODE"
inicio: sei
        ldx     #$FF
        txs
        jsr     plat_inicio
.ifdef SOLO_FINAL
        jsr     plat_ei
        ldx     #0                      ; a few ticks of the game first
:       dey
        bne     :-
        dex
        bne     :-
        jsr     plat_di
        jmp     plat_final
.else
        jsr     plat_ei
        ; the stack below the SP marked
        tsx
        lda     #$EE
:       dex
        sta     $0100,x
        cpx     #$B0
        bne     :-
        ; zero page and $0200-$03FF: the pattern
        ldx     #2
:       txa
        eor     #$5A
        sta     $00,x
        inx
        bne     :-
:       txa
        eor     #$A5
        sta     $0200,x
        txa
        eor     #$3C
        sta     $0300,x
        inx
        bne     :-
        lda     #$11
        jsr     llena
        lda     #$33                    ; slot "3"
        sta     plat_ranura
        jsr     pon_bloque
        jsr     guarda_pagina
        jsr     plat_di                 ; (the tape menu's DI)
        jsr     plat_disco_guarda
        jsr     resultado_c             ; [0] the save's C
        jsr     compara_pagina          ; [1] bytes of $02-$03FF changed
        lda     #0
        jsr     llena
        jsr     pon_bloque
        jsr     guarda_pagina
        jsr     plat_disco_carga
        jsr     resultado_c             ; [2] the load's C
        jsr     compara_pagina          ; [3]
        lda     #$11
        jsr     verifica                ; [4] bytes of the block wrong
        lda     #$37                    ; slot "7": no file
        sta     plat_ranura
        jsr     plat_disco_carga
        jsr     resultado_c             ; [5] C (1)
        lda     #$33
        sta     plat_ranura
        lda     #$77                    ; save again over the first
        jsr     llena
        jsr     plat_disco_guarda
        jsr     resultado_c             ; [6]
        lda     #0
        jsr     llena
        jsr     plat_disco_carga
        jsr     resultado_c             ; [7]
        lda     #$77
        jsr     verifica                ; [8]
        lda     #0                      ; the interrupt: still delivered
        sta     ticks
        sta     ticks+1
        jsr     plat_ei
        ldx     #0
        ldy     #0
:       dey
        bne     :-
        dex
        bne     :-
        sei
        lda     ticks                   ; [9] interrupts in ~330000 cycles (~100)
        sta     resultados+9
        lda     #$EE                    ; [10] the lowest byte of the stack page the calls used
        ldx     #$B0
:       cmp     $0100,x
        bne     :+
        inx
        bne     :-
:       stx     resultados+10
        tsx                             ; [11] the SP at the calls
        stx     resultados+11
.endif
b_fin:  jmp     b_fin

; zhl = BLOQUE, zde = LARGO
pon_bloque:
        lda     #<BLOQUE
        sta     zhl
        lda     #>BLOQUE
        sta     zhl+1
        lda     #<LARGO
        sta     zde
        lda     #>LARGO
        sta     zde+1
        rts

; the block := pattern A + i
llena:  sta     patron
        jsr     bloque_ptr
        ldx     #>LARGO + 1
        ldy     #0
:       lda     patron
        sta     (zp0),y
        inc     patron
        iny
        bne     :-
        inc     zp0+1
        dex
        bne     :-
        rts                             ; (it writes a little past the block: up to $A2CD; free in this test)

; resultados[indice++] := the count of bytes of the block that are not pattern A + i
verifica:
        sta     patron
        jsr     bloque_ptr
        lda     #0
        sta     malos
        sta     malos+1
        lda     #<LARGO
        sta     cuenta
        lda     #>LARGO
        sta     cuenta+1
        ldy     #0
:       lda     (zp0),y
        cmp     patron
        beq     :+
        inc     malos
:       inc     patron
        inc     zp0
        bne     :+
        inc     zp0+1
:       lda     cuenta
        bne     :+
        dec     cuenta+1
:       dec     cuenta
        lda     cuenta
        ora     cuenta+1
        bne     :----
        lda     malos
        jmp     anota

bloque_ptr:
        lda     #<BLOQUE
        sta     zp0
        lda     #>BLOQUE
        sta     zp0+1
        rts

; $0000-$03FF to copia
guarda_pagina:
        ldx     #0
:       lda     $0000,x
        sta     copia,x
        lda     $0100,x
        sta     copia+$100,x
        lda     $0200,x
        sta     copia+$200,x
        lda     $0300,x
        sta     copia+$300,x
        inx
        bne     :-
        rts

; resultados[indice++] := bytes of $02-$FF, $0200-$03FF that differ from copia (zp0 is the test's: left out)
compara_pagina:
        lda     #0
        sta     malos
        ldx     #2
:       cpx     #zp0
        beq     :+
        cpx     #zp0+1
        beq     :+
        lda     $00,x
        cmp     copia,x
        beq     :+
        inc     malos
:       inx
        bne     :--
:       lda     $0200,x
        cmp     copia+$200,x
        beq     :+
        inc     malos
:       lda     $0300,x
        cmp     copia+$300,x
        beq     :+
        inc     malos
:       inx
        bne     :---
        lda     malos
        jmp     anota

resultado_c:
        lda     #0
        rol     a
anota:  ldx     indice
        sta     resultados,x
        inc     indice
        rts

sys_tick:
        inc     ticks
        bne     :+
        inc     ticks+1
:       rts

.segment "DATA"
indice: .byte   0

.segment "BSS"
malos:  .res 2
cuenta: .res 2
