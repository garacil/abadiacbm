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

; Test of plat_tinta (and plat_crtc, plat_modo): the game's screen (room 16h with the score bar, the invisible
; bytes full of data) under the game's three palettes, as vid_set_palette sets them (pens 3, 2, 1, 0, then the
; border), and a test palette with pen 3 and the border in colour; a barrier after each (the script takes a
; picture); then the cycles of each call (CIA 2 timer A, the display blanked: no stolen cycles).
        .include "plat64.inc"
        .import plat_inicio, plat_tinta, plat_crtc, plat_modo
        .export sys_tick
        .export b_negra, b_dia, b_noche, b_prueba, b_ciclos, ciclos

PUNTERO = $FB

.segment "RODATA"
sala:   .incbin "sala_mapa.bin"
; C64 colours of pens 3, 2, 1, 0 and the border (the game's tables 3A7Ch.. converted, c64/datos/paleta.tsv)
negra:  .byte   0, 0, 0, 0, 0
dia:    .byte   0, 7, 8, 3, 0           ; black, yellow, orange, cyan, black
noche:  .byte   0, 12, 4, 6, 0          ; black, grey, purple, blue, black
prueba: .byte   2, 7, 8, 3, 5           ; pen 3 red (the invisible cells' 00 pairs show it), border green

.segment "BSS"
ciclos: .res 2 * 8                      ; JSR + routine + RTS: pen 0, 1, 2, 3, 16, 4, crtc, a bare RTS

.segment "CODE"
inicio: sei
        ldx     #$FF
        txs
        jsr     plat_inicio
        lda     #1                      ; the game's start-up: mode 1, its CRTC (nothing on the C64)
        jsr     plat_modo
        lda     #1
        ldx     #$20
        jsr     plat_crtc
        lda     #<sala                  ; the picture to $E000
        sta     PUNTERO
        lda     #>sala
        sta     PUNTERO+1
        lda     #<MAPA_BITS
        sta     PUNTERO+2
        lda     #>MAPA_BITS
        sta     PUNTERO+3
        ldx     #>8192
        ldy     #0
:       lda     (PUNTERO),y
        sta     (PUNTERO+2),y
        iny
        bne     :-
        inc     PUNTERO+1
        inc     PUNTERO+3
        dex
        bne     :-
        ldx     #0
        jsr     paleta
        jsr     dos_cuadros
b_negra: jmp    b_negra
        ldx     #dia - negra
        jsr     paleta
        jsr     dos_cuadros
b_dia:  jmp     b_dia
        ldx     #noche - negra
        jsr     paleta
        jsr     dos_cuadros
b_noche: jmp    b_noche
        ldx     #prueba - negra
        jsr     paleta
        jsr     dos_cuadros
b_prueba: jmp   b_prueba
        lda     VIC_D011                ; the cycles, the display blanked
        and     #$EF
        sta     VIC_D011
        lda     #0
        sta     cuenta
        ldx     #3
        jsr     mide
        lda     #1
        ldx     #8
        jsr     mide
        lda     #2
        ldx     #7
        jsr     mide
        lda     #3
        ldx     #0
        jsr     mide
        lda     #16
        ldx     #0
        jsr     mide
        lda     #4
        ldx     #1
        jsr     mide
        lda     #$FF                    ; plat_crtc
        jsr     mide
        lda     #$FE                    ; a bare RTS (the measure's own cost)
        jsr     mide
        lda     VIC_D011
        ora     #$10
        sta     VIC_D011
b_ciclos: jmp   b_ciclos

; pens 3, 2, 1, 0, border := the colours at negra + X (as vid_set_palette 3A90h)
paleta: stx     indice
        lda     #3
        sta     pen
:       ldx     indice
        lda     negra,x
        tax
        lda     pen
        jsr     plat_tinta
        inc     indice
        dec     pen
        bpl     :-
        ldx     indice
        lda     negra,x
        tax
        lda     #16
        jmp     plat_tinta

; A = pen (FF: plat_crtc, FE: an RTS), X = colour: its cycles into ciclos + cuenta, cuenta += 2
mide:   sta     pen
        stx     color
        lda     #$FF
        sta     $DD04
        sta     $DD05
        lda     #$11                    ; load and start
        sta     $DD0E
        lda     pen
        cmp     #$FE
        beq     m_rts
        cmp     #$FF
        beq     m_crtc
        ldx     color
        jsr     plat_tinta
        jmp     m_fin
m_crtc: lda     #1
        ldx     #$20
        jsr     plat_crtc
        jmp     m_fin
m_rts:  lda     #1
        ldx     #$20
        jsr     solo_rts
        jmp     m_fin
m_fin:  lda     #0                      ; stop
        sta     $DD0E
        ldy     cuenta
        sec
        lda     #$FF
        sbc     $DD04
        sta     ciclos,y
        lda     #$FF
        sbc     $DD05
        sta     ciclos+1,y
        iny
        iny
        sty     cuenta
        rts
solo_rts:
        rts

; wait until two whole frames have been drawn (the picture the monitor takes is the frame being drawn)
dos_cuadros:
        ldx     #3
:       bit     VIC_D011                ; line 256 and beyond
        bpl     :-
:       bit     VIC_D011                ; back to the top
        bmi     :-
        dex
        bne     :--
        rts

sys_tick:
        rts

.segment "BSS"
pen:    .res 1
color:  .res 1
indice: .res 1
cuenta: .res 1
