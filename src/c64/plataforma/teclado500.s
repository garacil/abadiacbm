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


; abadia128ks on the P500: plat_teclado_fila, the CPC keyboard matrix from the CBM-II keyboard and the two game
; ports (teclado.s's rules, for the P500's matrix; doc/referencias/p500.md).
;
; plat_teclado_fila: A = CPC matrix row 0-9 -> A = the row, active low (bit b of row r = CPC key 8r + b).
; X kept, Y clobbered.  Reading row 0 scans everything into the ten rows, rows 1-9 return that scan (as teclado.s).
;   - the keyboard: 16 columns x 6 rows, as the KERNAL ROM 901234-02 scans it ($E933-$E9EA): a column is selected by
;     a 0 on its line of TPI 2's port B ($DF01: columns 0-7) or port A ($DF00: columns 8-15), the rows are port C's
;     bits 0-5 ($DF02, 0 = down; read until two reads agree, as the KERNAL); key index 6 x column + row, the order of
;     the KERNAL's key table at $EAB1.
;   - the game ports ($DC00, Commodore's 700 reference manual: the 6526's port B bits 0-3 port 1's directions, 4-7
;     port 2's, port A bit 6 port 1's trigger, bit 7 port 2's; cc65's cbm510 joystick driver reads them so): both
;     ports, together, as the CPC's joystick 0 (row 9): up, down, left, right bits 0-3, the trigger fire 1 (bit 5).
;   - each P500 key -> one CPC key (tecla_cpc): letters, digits (the save slot), space, RETURN, the four cursors,
;     SHIFT, CTRL -> CONTROL, ESC and STOP -> ESC, TAB -> TAB, DEL -> DEL, the C= key -> COPY, CLR/HOME -> CLR,
;     F1, F3, F5, F7 -> f1, f3, f5, f7 (as the C64's), the punctuation the C64 also gives (, . ; / -).
;   - Q A O P as on the C64: A cursor down, O left, P right, Q up unless R is down too (the mirror's Q + R).  The P500
;     has four cursor keys: no SHIFT rule.
;   - the digit keys, the main ones and the numeric pad's, choose the save slot (plat_ranura).

        .include "plat64.inc"
        .export plat_teclado_fila
        .import plat_ranura

.segment "BSS"
filas:   .res 10                        ; the CPC rows of the last scan, active low
pulsadas: .res 1                        ; keys down in the column being scanned (1 = down)
puertos: .res 1
guarda_x: .res 1
guarda_x2: .res 1
guarda_y: .res 1
mascara: .res 1
filas_ant: .res 1

.segment "RODATA"
mascara_cero:                           ; bit b clear
        .byte   $FE, $FD, $FB, $F7, $EF, $DF, $BF, $7F
col_pa: .byte   $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF          ; columns 0-15: port A ($DF00)
        .byte   $FE, $FD, $FB, $F7, $EF, $DF, $BF, $7F
col_pb: .byte   $FE, $FD, $FB, $F7, $EF, $DF, $BF, $7F          ; and port B ($DF01)
        .byte   $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
seis:   .repeat 16, c                   ; 6 x column
        .byte   6 * c
        .endrep
; the CPC key of each P500 key, by 6 x column + row (the KERNAL's $EAB1 order); $5n = the digit n (the save slot);
; $FF none
tecla_cpc:
        ;       F1   ESC  TAB  -    SHIFT CTRL        (column 0; row 3: the C= key)
        .byte   $0D, $42, $44, $09, $15, $17
        ;       F2   1    Q    A=CRSR-down Z  -
        .byte   $FF, $51, $43, $02, $47, $FF
        ;       F3   2    W    S    X    C
        .byte   $05, $52, $3B, $3C, $3F, $3E
        ;       F4   3    E    D    F    V
        .byte   $FF, $53, $3A, $3D, $35, $37
        ;       F5   4    R    T    G    B
        .byte   $0C, $54, $32, $33, $34, $36
        ;       F6   5    6    Y    H    N
.ifdef INGLES                           ; English: the key Y gives the CPC's S (yes, as the score bar's Y:N)
        .byte   $FF, $55, $56, $3C, $2C, $2E
.else
        .byte   $FF, $55, $56, $2B, $2C, $2E
.endif
        ;       F7   7    U    J    M    SPACE
        .byte   $0A, $57, $2A, $2D, $26, $2F
        ;       F8   8    I    K    ,    .
        .byte   $FF, $58, $23, $25, $27, $1F
        ;       F9   9    O=CRSR-left L ;  /
        .byte   $FF, $59, $08, $24, $1C, $1E
        ;       F10  0    -    P=CRSR-right [ '
        .byte   $FF, $50, $19, $01, $FF, $FF
        ;       CRSR-down =  _    ]    RETURN pi
        .byte   $02, $FF, $FF, $FF, $12, $FF
        ;       CRSR-up CRSR-left CRSR-right DEL (row 4: CE) -
        .byte   $00, $08, $01, $4F, $FF, $FF
        ;       CLR/HOME pad-? pad-7 pad-4 pad-1 pad-0
        .byte   $10, $FF, $57, $54, $51, $50
        ;       RVS  pad-CE pad-8 pad-5 pad-2 pad-.
        .byte   $FF, $FF, $58, $55, $52, $FF
        ;       NORM pad-* pad-9 pad-6 pad-3 pad-00
        .byte   $FF, $FF, $59, $56, $53, $FF
        ;       STOP pad-/ pad-- pad-+ ENTER -
        .byte   $42, $FF, $FF, $FF, $12, $FF

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

; the scan, with $01 = 15 all along (filas, tecla_cpc, plat_ranura: absolute addresses of bank 0, not touched by the
; indirect bank register); P5_PIO = $DF00 (TPI 2)
.proc escanea
        lda     #$FF                    ; rows 0-8: nothing down
        ldx     #8
:       sta     filas,x
        dex
        bpl     :-
        lda     #P5_SISTEMA
        sta     P5_IND
        ldy     #1                      ; the game ports
        lda     (P5_PCIA),y             ; port B: port 1's directions in bits 0-3, port 2's in bits 4-7 (0 = on)
        sta     puertos
        lsr     a
        lsr     a
        lsr     a
        lsr     a
        and     puertos                 ; either port's
        ora     #$F0
        sta     filas+9
        dey
        lda     (P5_PCIA),y             ; port A: bit 6 port 1's trigger, bit 7 port 2's
        ora     #$3F
        cmp     #$FF
        beq     :+                      ; no trigger
        lda     filas+9
        and     #$DF                    ; fire 1 (bit 5)
        sta     filas+9
:       lda     #<P5_TPI2
        sta     P5_PIO
        lda     #>P5_TPI2
        sta     P5_PIO+1
        ldx     #15                     ; the columns 15..0
columna:
        ldy     #0
        lda     col_pa,x
        sta     (P5_PIO),y
        iny
        lda     col_pb,x
        sta     (P5_PIO),y
        iny
:       lda     (P5_PIO),y              ; the rows (until two reads agree: LDA (zp),Y twice, the 6509's CMP (zp),Y
        sta     filas_ant               ;   would read bank 0)
        lda     (P5_PIO),y
        cmp     filas_ant
        bne     :-
        ora     #$C0                    ; (bits 6-7: the VIC-II's bank lines)
        eor     #$FF
        beq     siguiente
        sta     pulsadas                ; keys down in column x
        ldy     seis,x                  ; 6 x + row
tecla:  lsr     pulsadas
        bcc     :+
        jsr     aplica
:       iny
        lda     pulsadas
        bne     tecla
siguiente:
        dex
        bpl     columna
        ldy     #0                      ; no column selected
        lda     #$FF
        sta     (P5_PIO),y
        iny
        sta     (P5_PIO),y
        lda     #0
        sta     P5_IND
        lda     #$04                    ; Q (CPC 43h) without R (32h): cursor up (00h), Guillermo walks;
        bit     filas+6                 ; Q + R stays Q + R (the mirror)
        beq     :+
        lda     #$08
        bit     filas+8
        bne     :+
        ora     filas+8
        sta     filas+8
        lda     filas
        and     #$FE                    ; key 00h, up
        sta     filas
:       rts
.endproc

; the P500 key Y is down: its CPC key's bit cleared, or a digit chooses the save slot.  X and Y kept.
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
