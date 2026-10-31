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

; abadia64ks on tape: the start menu (option 1 changes the language, option 2 turns the footsteps on or
; off, option 3 the sound of the text; the menu all black, white letters, everything centred and neat; the menu's own text in the chosen language, Spanish by default).  Runs at ETAPA ($C000), read by the
; first program (arranque.s).  The text screen at $0400, black border and background, white letters; the title,
; its rule and the footer centred, the three options a centred block of 32 columns (the key as a reversed button,
; the label, the value right-aligned).  Keys 1, 2, 3 change the options (OPCIONES, cinta.inc); SPACE or RETURN loads
; the presentation (ID_PRES: crunched with Exomizer, loaded where cinta.py put it, decrunched by Exomizer's
; standard decruncher to $0801) and runs it ($080D) with the KERNAL's interrupt on, as from BASIC.

.ifdef C128
; the C128's disk (milestone H10, c64/disco128): the same menu with a fourth option, the PC's Ave Maria at
; completas (the Ave Maria at mass on or off, played as on the PC), run at $1300 by
; the boot sector with the KERNAL's screen editor alive; it loads the presentation from the disk
        .include "disco128.inc"
        .include "disco128_gen.inc"     ; PRES_FIN: the crunched presentation's end (made by construye.sh)
.elseif .defined(DISCO)
; the C64's disk (c64/disco64): the tape's menu, run at ETAPA ($C000) by the disk's first program (arranque64.s);
; the presentation loaded with the KERNAL from the drive the menu came from (kept in UNIDAD for its loader)
        .include "cinta.inc"
        .include "disco64_gen.inc"      ; PRES_FIN (made by c64/disco64/construye.sh)
UNIDAD  = $02A8                         ; (cargador.s -D DISCO)
FA      = $BA
.else
        .include "cinta.inc"
        .include "cinta_gen.inc"        ; PRES_FIN: the crunched presentation's end (made by construye.sh)
.endif
        .import exo_desde

PANTALLA = $0400
COLOR    = $D800
GETIN    = $FFE4
BLANCO   = 1
zp       = $FB                          ; 2: the record being drawn ($FB-$FE: free for programs)
dst      = $FD                          ; 2: where it goes

; the text in the ROM's lower/upper-case set (the credits in lower case): A-Z are its screen
; codes $41-$5A (the same as ASCII), a-z its $01-$1A, @ its $00; space, digits, punctuation and the rule
; ($40) keep their codes; neither set has accented letters
        .charmap $61, $01               ; a
        .charmap $62, $02               ; b
        .charmap $63, $03               ; c
        .charmap $64, $04               ; d
        .charmap $65, $05               ; e
        .charmap $66, $06               ; f
        .charmap $67, $07               ; g
        .charmap $68, $08               ; h
        .charmap $69, $09               ; i
        .charmap $6A, $0A               ; j
        .charmap $6B, $0B               ; k
        .charmap $6C, $0C               ; l
        .charmap $6D, $0D               ; m
        .charmap $6E, $0E               ; n
        .charmap $6F, $0F               ; o
        .charmap $70, $10               ; p
        .charmap $71, $11               ; q
        .charmap $72, $12               ; r
        .charmap $73, $13               ; s
        .charmap $74, $14               ; t
        .charmap $75, $15               ; u
        .charmap $76, $16               ; v
        .charmap $77, $17               ; w
        .charmap $78, $18               ; x
        .charmap $79, $19               ; y
        .charmap $7A, $1A               ; z
        .charmap $40, $00               ; @

; a record: its row, its column, its length, its screen codes
.macro  TXT fila, col, texto
        .byte   fila, col, .strlen(texto), texto
.endmacro
.macro  CENTRO fila, texto              ; centred in the 40 columns
        TXT     fila, (40 - .strlen(texto)) / 2, texto
.endmacro
.macro  REGLA fila, largo               ; a horizontal rule (the line character, screen code $40), centred
        .byte   fila, (40 - largo) / 2, largo
        .res    largo, $40
.endmacro
.macro  VALOR fila, texto               ; an option's value, right-aligned to column 35
        TXT     fila, 36 - .strlen(texto), texto
.endmacro
ETIQ = 9                                ; the labels' column (the block: 4-35)
.ifdef C128                             ; the rows: the options, the footer
F1   = 10
F2   = 12
F3   = 14
F4   = 16
FPIE = 19
.else
F1   = 11
F2   = 13
F3   = 15
FPIE = 18
.endif

        .segment "CODE"
        lda     #0
        sta     OPCIONES                ; Spanish, footsteps on, text sound on (the C128: the Ave Maria on)
        sta     cargando
        sta     $D020
        sta     $D021
.ifdef C128
        sta     NDX                     ; the keyboard buffer emptied
        lda     FA                      ; the drive the disk booted from, for the presentation's loader
        sta     UNIDAD
        lda     #$16                    ; the screen at $0400, the ROM's lower/upper-case set (the editor's
        sta     VM1                     ;   shadow of $D018: its interrupt copies it)
        lda     #$80                    ; SHIFT + C= must not switch the set
        sta     LOCKS
.else
        sta     $C6                     ; the keyboard buffer emptied
.ifdef DISCO
        lda     FA                      ; the drive the disk was loaded from (8 if not a drive)
        cmp     #8
        bcs     :+
        lda     #8
:       sta     UNIDAD
.endif
        lda     #$17                    ; the screen at $0400, the ROM's lower/upper-case characters
        sta     $D018
        lda     #$80                    ; SHIFT + C= must not switch the set (the KERNAL's MODE)
        sta     $0291
        lda     #$81                    ; the KERNAL's interrupt (timer A) on again: GETIN reads the keys
        sta     $DC0D
.endif
        cli
dibuja: jsr     pinta
tecla:  jsr     GETIN
        beq     tecla
        ldx     #OPC_INGLES
        cmp     #'1'
        beq     cambia
        ldx     #OPC_SIN_PASOS
        cmp     #'2'
        beq     cambia
        ldx     #OPC_SIN_TEXTO
        cmp     #'3'
        beq     cambia
.ifdef C128
        ldx     #OPC_SIN_AVE
        cmp     #'4'
        beq     cambia
.endif
        cmp     #' '
        beq     carga
        cmp     #$0D
        bne     tecla
carga:  inc     cargando                ; the footer: "loading"
        jsr     pinta
.ifdef C128
        lda     #0                      ; "ABADIA" (crunched) into block 0 at its own address, from the boot drive
        tax
        jsr     SETBNK
        lda     #1
        ldx     FA
        ldy     #1
        jsr     SETLFS
        lda     #nombre_fin - nombre
        ldx     #<nombre
        ldy     #>nombre
        jsr     SETNAM
        lda     #0
        jsr     LOAD
        bcs     mal
        sei
        lda     #CFG_CC65               ; the RAM up to $BFFF (the crunched data and its place)
        sta     MMU_CR
        lda     #<PRES_FIN
        ldx     #>PRES_FIN
        jsr     exo_desde               ; the presentation at $1C01
        cli
        jmp     PRES_INICIO
.else
.ifdef DISCO
        lda     #nombre_fin - nombre    ; "ABADIA" (crunched) at its own address, from the menu's drive
        ldx     #<nombre
        ldy     #>nombre
        jsr     $FFBD                   ; SETNAM
        lda     #1
        ldx     UNIDAD
        ldy     #1
        jsr     $FFBA                   ; SETLFS
        lda     #0
        jsr     $FFD5                   ; LOAD
        bcs     mal
        sei
.else
        sei
        lda     #ID_PRES
        jsr     T_CARGA
        bcs     mal
.endif
        lda     #$36                    ; the RAM under BASIC visible (the crunched data may be there)
        sta     $01
        lda     #<PRES_FIN
        ldx     #>PRES_FIN
        jsr     exo_desde               ; the presentation at $0801
        lda     #$37
        sta     $01
        lda     #$81                    ; the KERNAL's interrupt again, as BASIC leaves it for a program
        sta     $DC0D
        lda     $DC0D
        cli
        jmp     $080D                   ; the presentation (its BASIC line: SYS 2061)
.endif
mal:    inc     $D020
        jmp     mal
cambia: txa
        eor     OPCIONES
        sta     OPCIONES
        jmp     dibuja

; the whole screen in the chosen language, from the options
pinta:  ldx     #0
:       lda     #' '                    ; cleared, white
        sta     PANTALLA,x
        sta     PANTALLA + $100,x
        sta     PANTALLA + $200,x
        sta     PANTALLA + $2E8,x
        lda     #BLANCO
        sta     COLOR,x
        sta     COLOR + $100,x
        sta     COLOR + $200,x
        sta     COLOR + $2E8,x
        inx
        bne     :-
        lda     OPCIONES
        and     #OPC_INGLES
        tax                             ; X = the language: 0 Spanish, 1 English
        lda     fijos_lo,x
        ldy     fijos_hi,x
        jsr     lista
        lda     #<botones
        ldy     #>botones
        jsr     lista
        lda     idioma_lo,x             ; the language's own name
        ldy     idioma_hi,x
        jsr     lista
        txa                             ; the footsteps: 2 x language + (off)
        asl     a
        sta     cargando + 1
        lda     OPCIONES
        and     #OPC_SIN_PASOS
        beq     :+
        inc     cargando + 1
:       ldy     cargando + 1
        lda     pasos_lo,y
        pha
        lda     pasos_hi,y
        tay
        pla
        jsr     lista
        txa                             ; the text sound: the same
        asl     a
        sta     cargando + 1
        lda     OPCIONES
        and     #OPC_SIN_TEXTO
        beq     :+
        inc     cargando + 1
:       ldy     cargando + 1
        lda     texto_lo,y
        pha
        lda     texto_hi,y
        tay
        pla
        jsr     lista
.ifdef C128
        txa                             ; the Ave Maria: the same
        asl     a
        sta     cargando + 1
        lda     OPCIONES
        and     #OPC_SIN_AVE
        beq     :+
        inc     cargando + 1
:       ldy     cargando + 1
        lda     ave_lo,y
        pha
        lda     ave_hi,y
        tay
        pla
        jsr     lista
.endif
        txa                             ; the footer: 2 x language + (loading)
        asl     a
        ora     cargando
        tay
        lda     pie_lo,y
        pha
        lda     pie_hi,y
        tay
        pla
        jmp     lista

; A/Y = a list of records ending with $FF: each drawn; X kept
lista:  sta     zp
        sty     zp + 1
        txa
        pha
@reg:   ldy     #0
        lda     (zp),y                  ; the row ($FF: the end)
        cmp     #$FF
        beq     @fin
        tax
        lda     #<PANTALLA              ; dst = $0400 + 40 x row
        sta     dst
        lda     #>PANTALLA
        sta     dst + 1
:       dex
        bmi     :+
        lda     dst
        clc
        adc     #40
        sta     dst
        bcc     :-
        inc     dst + 1
        bne     :-
:       iny
        lda     (zp),y                  ; + the column
        clc
        adc     dst
        sta     dst
        bcc     :+
        inc     dst + 1
:       iny
        lda     (zp),y                  ; the length
        tax
        lda     zp                      ; zp -> the text
        clc
        adc     #3
        sta     zp
        bcc     :+
        inc     zp + 1
:       ldy     #0
:       lda     (zp),y
        sta     (dst),y
        iny
        dex
        bne     :-
        tya                             ; zp -> the next record
        clc
        adc     zp
        sta     zp
        bcc     @reg
        inc     zp + 1
        bne     @reg
@fin:   pla
        tax
        rts

        .segment "RODATA"
fijos_lo:  .byte <fijos_es, <fijos_en
fijos_hi:  .byte >fijos_es, >fijos_en
idioma_lo: .byte <idioma_es, <idioma_en
idioma_hi: .byte >idioma_es, >idioma_en
pasos_lo:  .byte <si_13, <no_13, <on_13, <off_13
pasos_hi:  .byte >si_13, >no_13, >on_13, >off_13
texto_lo:  .byte <si_15, <no_15, <on_15, <off_15
texto_hi:  .byte >si_15, >no_15, >on_15, >off_15
pie_lo:    .byte <pie_es, <carga_es, <pie_en, <carga_en
pie_hi:    .byte >pie_es, >carga_es, >pie_en, >carga_en
.ifdef C128
ave_lo:    .byte <si_17, <no_17, <on_17, <off_17
ave_hi:    .byte >si_17, >no_17, >on_17, >off_17
.endif
.if .defined(C128) || .defined(DISCO)
nombre:    .byte "ABADIA"
nombre_fin:
.endif

fijos_es:
        CENTRO  4, "LA ABADIA DEL CRIMEN"
        REGLA   5, 20
        CENTRO  8, "OPCIONES"
        TXT     F1, ETIQ, "IDIOMA"
        TXT     F2, ETIQ, "PASOS"
        TXT     F3, ETIQ, "SONIDO DEL TEXTO"
.ifdef C128
        TXT     F4, ETIQ, "AVE MARIA"
.endif
        CENTRO  21, "2026  version commodore por"       ; (the credits at the bottom)
        CENTRO  22, "german luis aracil boned"
        CENTRO  23, "garacilb@gmail.com"
        .byte   $FF
fijos_en:
        CENTRO  4, "THE ABBEY OF CRIME"
        REGLA   5, 18
        CENTRO  8, "OPTIONS"
        TXT     F1, ETIQ, "LANGUAGE"
        TXT     F2, ETIQ, "FOOTSTEPS"
        TXT     F3, ETIQ, "TEXT SOUND"
.ifdef C128
        TXT     F4, ETIQ, "AVE MARIA"
.endif
        CENTRO  21, "2026  commodore version by"
        CENTRO  22, "german luis aracil boned"
        CENTRO  23, "garacilb@gmail.com"
        .byte   $FF
botones:                                ; " 1 ", " 2 ", " 3 " reversed, at column 4
        .byte   F1, 4, 3, $A0, $B1, $A0
        .byte   F2, 4, 3, $A0, $B2, $A0
        .byte   F3, 4, 3, $A0, $B3, $A0
.ifdef C128
        .byte   F4, 4, 3, $A0, $B4, $A0
.endif
        .byte   $FF
idioma_es: VALOR F1, "ESPANOL"                ; (the language is «español», not «castellano»; no Ñ in the ROM font)
        .byte   $FF
idioma_en: VALOR F1, "ENGLISH"
        .byte   $FF
si_13:  VALOR   F2, "SI"
        .byte   $FF
no_13:  VALOR   F2, "NO"
        .byte   $FF
on_13:  VALOR   F2, "ON"
        .byte   $FF
off_13: VALOR   F2, "OFF"
        .byte   $FF
si_15:  VALOR   F3, "SI"
        .byte   $FF
no_15:  VALOR   F3, "NO"
        .byte   $FF
on_15:  VALOR   F3, "ON"
        .byte   $FF
off_15: VALOR   F3, "OFF"
        .byte   $FF
.ifdef C128
si_17:  VALOR   F4, "SI"
        .byte   $FF
no_17:  VALOR   F4, "NO"
        .byte   $FF
on_17:  VALOR   F4, "ON"
        .byte   $FF
off_17: VALOR   F4, "OFF"
        .byte   $FF
.endif
pie_es: CENTRO  FPIE, "PULSA ESPACIO PARA CARGAR"
        .byte   $FF
carga_es: CENTRO FPIE, "CARGANDO"
        .byte   $FF
pie_en: CENTRO  FPIE, "PRESS SPACE TO LOAD"
        .byte   $FF
carga_en: CENTRO FPIE, "LOADING"
        .byte   $FF

        .segment "BSS"
cargando: .res  2                       ; 0/1: the footer says "loading"; +1: a work byte
