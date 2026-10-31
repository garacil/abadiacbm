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

; abadia64ks, the C64 platform layer: plat_teclado_fila, the CPC keyboard matrix from the C64's keyboard and
; joystick port 2 (the map: c64/plataforma/TECLADO.md).
;
; plat_teclado_fila: A = CPC matrix row 0-9 -> A = the row, active low (bit b of row r = CPC key 8r + b).
; X kept, Y clobbered.  Needs the I/O visible ($01 = $35).
; The game reads the ten rows in order (sys_read_keyboard 2D50h, its only reader): reading row 0 scans the
; whole C64 matrix and the joystick into the ten rows, the other rows return that scan (one consistent picture,
; as the CPC's scan of a few hundred microseconds).
;   - joystick port 2 ($DC00 with no column selected): CPC row 9, the CPC's joystick 0: bits 0-3 up, down, left,
;     right as the C64's, fire -> bit 5 (fire 1).  The game's own aliases (2E2Eh-2E41h) then give, as on a
;     CPC: up = advance, left/right = turn, down = space, fire = cursor down.
;   - each C64 key -> one CPC key (tecla_cpc, by the C64 matrix position): letters, punctuation, space, return,
;     shift, CTRL -> CONTROL, RUN/STOP -> ESC, the left-arrow key -> TAB, INST/DEL -> DEL, C= -> COPY,
;     CRSR down / right -> cursor down / right, with SHIFT -> cursor up / left (the C64's own cursor keys).
;   - Q A O P as the cursors (the C64's cursors need SHIFT for up and left, so walking with
;     SHIFT + CRSR down and turning with CRSR right reads as left): A -> cursor down (Adso), O -> cursor left,
;     P -> cursor right, Q -> cursor up (walk) but when R is down too, then the CPC's Q (the mirror's Q + R:
;     press R first, or Guillermo walks up a step).
;   - the digit keys choose the save slot (the last character of the save file's name, disco.s), not CPC keys:
;     the game does not read them.
;   - rows that read low with no column selected (joystick port 1, or a key in a column joystick 2 pulls low)
;     are left out of the scan, so the joystick does not make phantom keys.

        .include "plat64.inc"
        .export plat_teclado_fila, mascara_cero
        .import plat_ranura

.segment "BSS"
filas:   .res 10                        ; the CPC rows of the last scan, active low
fantasma: .res 1                        ; rows to leave out (1 = low with no column selected)
pulsadas: .res 1                        ; keys down in the column being scanned (1 = down)
guarda_x: .res 1
guarda_y: .res 1
mascara: .res 1

.segment "RODATA"
mascara_cero:                           ; bit b clear: the column to select, the CPC bit to clear
        .byte   $FE, $FD, $FB, $F7, $EF, $DF, $BF, $7F
; the CPC key of each C64 key, by its matrix position 8 * column ($DC00 bit) + row ($DC01 bit); $5n = the
; digit n (the save slot); $FF none
tecla_cpc:
        ;       DEL  RETURN CRSR-> F7   F1   F3   F5   CRSR-down
        .byte   $4F, $12, $01, $0A, $0D, $05, $0C, $02
        ;       3    W    A=CRSR-down 4  Z    S    E    LSHIFT
        .byte   $53, $3B, $02, $54, $47, $3C, $3A, $15
        ;       5    R    D    6    C    F    T    X
        .byte   $55, $32, $3D, $56, $3E, $35, $33, $3F
        ;       7    Y    G    8    B    H    U    V
.ifdef INGLES                           ; English: the C64 key Y gives the CPC's S (yes, as the score bar's Y:N)
        .byte   $57, $3C, $34, $58, $36, $2C, $2A, $37
.else
        .byte   $57, $2B, $34, $58, $36, $2C, $2A, $37
.endif
        ;       9    I    J    0    M    K    O=CRSR-left N
        .byte   $59, $23, $2D, $50, $26, $25, $08, $2E
        ;       +    P=CRSR-> L  -    .    :    @    ,
        .byte   $FF, $01, $24, $19, $1F, $1D, $1A, $27
        ;       pound *   ;    HOME RSHIFT =  up-arrow /
        .byte   $FF, $FF, $1C, $10, $15, $FF, $18, $1E
        ;       1    <-   CTRL 2    SPACE C=  Q    RUN/STOP
        .byte   $51, $44, $17, $52, $2F, $09, $43, $42

.segment "CODE"

.proc plat_teclado_fila
        tay
        bne     lee
        stx     guarda_x
        jsr     escanea
        ldx     guarda_x
        ldy     #0
lee:    lda     filas,y
        rts
.endproc

.proc escanea
        lda     #$FF                    ; rows 0-8: nothing down
        ldx     #8
:       sta     filas,x
        dex
        bpl     :-
        sta     CIA1_PRA                ; no column selected: port A reads joystick 2 alone
        lda     CIA1_PRB                ; rows low now are not keys of the column scanned
        eor     #$FF
        sta     fantasma
        lda     CIA1_PRA                ; joystick 2: bit 4 fire, 3 right, 2 left, 1 down, 0 up (0 = on)
        tay
        and     #$10                    ; fire -> bit 5
        asl     a
        ora     #$DF
        sta     filas+9
        tya
        ora     #$F0                    ; the directions -> bits 0-3
        and     filas+9
        sta     filas+9
        ldx     #7                      ; the C64 columns 7..0
columna:
        lda     mascara_cero,x
        sta     CIA1_PRA
        lda     CIA1_PRB
        ora     fantasma
        eor     #$FF
        beq     siguiente
        sta     pulsadas                ; keys down in column x
        txa
        asl     a
        asl     a
        asl     a
        tay                             ; 8 x + row
tecla:  lsr     pulsadas
        bcc     :+
        jsr     aplica
:       iny
        lda     pulsadas
        bne     tecla
siguiente:
        dex
        bpl     columna
        lda     #$FF
        sta     CIA1_PRA
        lda     #$04                    ; Q (CPC 43h) without R (32h): cursor up (00h), Guillermo walks;
        bit     filas+6                 ; Q + R stays Q + R (the mirror)
        beq     :+
        lda     #$08
        bit     filas+8
        bne     :+
        ora     filas+8
        sta     filas+8
        dec     filas                   ; bit 0 of row 0 is 1 here (no key gives cursor up before the SHIFT rule)
:       lda     filas+2                 ; SHIFT (CPC key 15h): CRSR down -> up, CRSR right -> left
        and     #$20
        bne     fin
        lda     filas
        tay
        ora     #$06
        sta     filas
        tya
        and     #$04
        bne     :+
        lda     filas
        and     #$FE                    ; key 00h, up
        sta     filas
:       tya
        and     #$02
        bne     fin
        lda     filas+1
        and     #$FE                    ; key 08h, left
        sta     filas+1
fin:    rts
.endproc

; the C64 key Y is down: its CPC key's bit cleared, or a digit chooses the save slot.  X and Y kept.
.proc aplica
        lda     tecla_cpc,y
        cmp     #$50
        bcs     especial
        stx     guarda_x2
        sty     guarda_y
        tax
        and     #7
        tay
        lda     mascara_cero,y
        sta     mascara
        txa
        lsr     a
        lsr     a
        lsr     a
        tax                             ; the CPC row
        lda     filas,x
        and     mascara
        sta     filas,x
        ldx     guarda_x2
        ldy     guarda_y
        rts
especial:
        cmp     #$FF
        beq     :+
        eor     #$50 ^ $30              ; $5n -> the character "n"
        sta     plat_ranura
:       rts
.endproc

.segment "BSS"
guarda_x2: .res 1
