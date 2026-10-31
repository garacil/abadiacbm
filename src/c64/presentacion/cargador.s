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

; abadia64ks, the game's loader (c64/presentacion/NOTAS.md, c64/cinta/FLUJO.md).  It runs at $C3E8 (copied there by
; carga.s once the presentation has put the picture, abadia.koa, on the game's screen: presentacion.c's gameload)
; and reads the file "juego" (the stream c64/cinta/flujo.py makes from the game's image) byte by byte with the KERNAL
; (OPEN / CHKIN / CHRIN), as the CPC tape's loader read the block 20h; at the end it jumps to the game
; (principal_inicio).  The picture stays on the screen while the game loads.
;
; Memory.  The game needs nearly all the RAM, so the loader lives where the game needs nothing at its start
; (checked: c64/cinta/libres.py): $C3E8-$C6FF (the screen RAM's unused tail, the tiles' merge tables, rebuilt by the
; game's start-up 3607), the zero page $02-$0C (of the game's free $02-$23), the stack page.  What the game needs
; where the loader, the KERNAL or the picture are during the load is held aside and put in place at the end:
;   $0200-$03FF (the KERNAL's pages: vectors, file tables)  -> $BF00 and $C700 (merge tables)
;   $0090-$009D (the game's operands in the KERNAL's zero page) -> $0100-$010D
;   the score bar, bitmap rows 20-23, cells 4-35 (the picture is shown there) -> $BB00-$BEFF (merge tables)
; The picture is where the game's screen is: VIC bank 3, screen RAM $C000, bitmap $E000, colour RAM $D800, all 40 x
; 25 cells.  The game's data that lives in the bitmap's cells outside the game's screen (columns 0-3 and 36-39 of
; rows 0-23, row 24: about 1 KB) comes last: before it the stream's mark blackens those cells (`negro`: their screen
; RAM and colour RAM to 0, $D021 is black), so their bytes arrive unseen.  The play area (rows 0-19, cells 4-35: the
; image's zeros) is cleared and the score bar put in place at the end, with the display blanked.
;
; The stream (c64/cinta/FLUJO.md, "The stream"): a load address (2 bytes, ignored), the header (principal_inicio, the
; address of plat_unidad), the data, a checksum (the 16-bit sum of every byte before it).  The data: segments, each
; its destination address (2 bytes) and tokens (c64/cinta/lz64.c); the address 0 ends the data, the address 1 is the
; mark (no tokens: the side cells blackened).
;
; $01 = $34 (all RAM) all the time but around CHRIN ($36: KERNAL and I/O) and the mark ($35: I/O); no interrupt
; (CIA 1 and 2 and the VIC-II masked; NMI -> an RTI).  A read error or a wrong checksum flashes the border for ever.
;
; -D CINTA (the tape, c64/cinta/NOTAS.md): the stream comes in the turbo blocks ID_JUEGO (up to the mark) and
; ID_JUEGO2 (after it: the tape runs on while the side cells are blackened, the second block has its own pilot),
; read with the turbo core (T_ABRE / T_BYTE / T_CIERRA, $01 = $35 around them); its header has a third address, the
; game's plat_opciones, given the menu's options (OPCIONES), and the addresses of the notes of the game's footstep and
; beep the options may silence (cinta_paso, cinta_pitido: 0Fh, a rest, written over them); plat_unidad := 1 (the tape).  When English was chosen
; the block ID_TEXTOS_EN follows: the bytes of the English image that differ, as segments of the same format
; (no header; its own checksum), written over the Spanish game before the end.

; -D DISCO (the C64's disk with the tape's menu, c64/disco64/NOTAS.md): the file "JUEGO" read with the KERNAL as
; here, with the tape's header (plat_opciones, the two sound calls) and, when English was chosen, the file "TEXTOS"
; after it (the tape's English block: segments of the same format, its own checksum); the drive the menu was loaded
; from is UNIDAD ($02A8: cc65's programs leave FA at 3, the screen).

        .export inicio, segmento, negro, tras_negro, fin, salto, error
        .export MARCADOR, PAGINA2, PAGINA3, ZP_KERNAL
.if .defined(CINTA) || .defined(DISCO)
        .include "cinta.inc"            ; OPCIONES and its bits (the tape's and the disk's menu)
.endif
.ifdef DISCO
UNIDAD  = $02A8                         ; the menu's drive (c64/disco64: the tape's turbo variables, unused here)
.endif

SETNAM  = $FFBD
SETLFS  = $FFBA
OPEN    = $FFC0
CLOSE   = $FFC3
CHKIN   = $FFC6
CLRCHN  = $FFCC
CHRIN   = $FFCF
ST      = $90                           ; the KERNAL's status
FA      = $BA                           ; the device of the last file

MARCADOR  = $BB00                       ; 4 pages: bitmap rows 20-23, cells 4-35 ($F920, $FA60, $FBA0, $FCE0)
PAGINA2   = $BF00                       ; the game's $0200-$02FF
PAGINA3   = $C700                       ; the game's $0300-$03FF
ZP_KERNAL = $0100                       ; the game's $0090-$009D

; the zero page ($02-$0C: nothing of the game's)
zdst    = $02                           ; where the data go
zsrc    = $04                           ; a copy's source
zval    = $06                           ; 2: gamma value, counts
zbits   = $08                           ; the bit buffer (a 1 marks its end)
zsuma   = $09                           ; 2: the checksum
zofs    = $0B                           ; 2
.ifdef CINTA
RAM_    = $14                           ; $01 while reading: all RAM, or the I/O, with the tape's motor on (bit 5 = 0:
IO_     = $15                           ; the 6510's port drives the datasette's motor)
.else
RAM_    = $34
IO_     = $35
.endif
.if .defined(CINTA) || .defined(DISCO)
zfase   = $0D                           ; 0: the game's stream; 1: the English bytes
zpaso   = $0E                           ; 2: the note of the game's footstep (cinta_paso)
zpitido = $10                           ; 2: the note of its text's beep (cinta_pitido)
ZP_FIN  = $12
.else
ZP_FIN  = $0D
.endif

.segment "CODE"

inicio:
        sei
        cld
        ldx     #$FF
        txs
        lda     #$7F                    ; no interrupts: CIA 1, CIA 2, the VIC-II
        sta     $DC0D
        sta     $DD0D
        lda     $DC0D
        lda     $DD0D
        lda     #0
        sta     $D01A
        lda     #$FF
        sta     $D019
        lda     #<nada                  ; NMI (RESTORE): nothing, with the KERNAL in or out
        sta     $0318
        sta     $FFFA
        lda     #>nada
        sta     $0319
        sta     $FFFB
        lda     #0                      ; the variables
        ldx     #ZP_FIN - zdst - 1
:       sta     zdst,x
        dex
        bpl     :-
        lda     #$80
        sta     zbits
.ifdef CINTA
        lda     #IO_                    ; the tape: the first block
        sta     $01
        lda     #ID_JUEGO
        jsr     T_ABRE
.elseif .defined(DISCO)
        lda     #nombre_fin - nombre    ; OPEN 2,device,2,"JUEGO": CHKIN 2
        ldx     #<nombre
        ldy     #>nombre
        jsr     abre
.else
        lda     #$36                    ; OPEN 2,device,2,"JUEGO": CHKIN 2
        sta     $01
        lda     #nombre_fin - nombre
        ldx     #<nombre
        ldy     #>nombre
        jsr     SETNAM
        lda     #2
        ldx     FA                      ; the device the first stage came from (8 if not a drive)
        cpx     #8
        bcs     :+
        ldx     #8
:       ldy     #2
        jsr     SETLFS
        jsr     OPEN
        bcs     mal
        ldx     #2
        jsr     CHKIN
        bcc     :+
mal:    jmp     error
:
.endif
        lda     #RAM_
        sta     $01
        jsr     crudo                   ; the load address
        jsr     crudo
        jsr     crudo                   ; the header
        sta     salto+1
        jsr     crudo
        sta     salto+2
        jsr     crudo
        sta     unidad+1
        jsr     crudo
        sta     unidad+2
.if .defined(CINTA) || .defined(DISCO)
        jsr     crudo                   ; the game's plat_opciones
        sta     opciones+1
        jsr     crudo
        sta     opciones+2
        ldy     #0                      ; the two notes the options may silence (Y: crudo keeps it, not X)
:       jsr     crudo
        sta     zpaso,y
        iny
        cpy     #4
        bne     :-
.endif

; ---- the data: segments of tokens (c64/cinta/lz64.c) ----
segmento:
        jsr     crudo                   ; the address; 0: the end; 1: the mark
        sta     zdst
        jsr     crudo
        sta     zdst+1
        bne     token
        lda     zdst
        beq     a_fin
        cmp     #1
        bne     token
.ifdef CINTA
        lda     #IO_                    ; the tape's first block ends at the mark: its checksum, the motor off
        sta     $01
        jsr     T_CIERRA
        bcc     :+
        jmp     error
:       jsr     negro
        lda     #IO_                    ; the second block
        sta     $01
        lda     #ID_JUEGO2
        jsr     T_ABRE
        lda     #RAM_
        sta     $01
.else
        jsr     negro
.endif
tras_negro:                             ; (for the tests)
        jmp     segmento
a_fin:  jmp     fin
token:  jsr     lee_bit
        bcs     copia
        jsr     gamma                   ; 0: n literal bytes
literal:
        jsr     crudo
        ldy     #0
        sta     (zdst),y
        inc     zdst
        bne     :+
        inc     zdst+1
:       jsr     cuenta
        bne     literal
        beq     token
copia:  jsr     gamma                   ; 1: h + 1 (257: the end of the segment)
        lda     zval
        sec
        sbc     #1
        tax
        lda     zval+1
        sbc     #0
        bne     segmento
        stx     zofs+1
        jsr     crudo                   ; the offset's low byte
        sta     zofs
        sec                             ; the source: dst - offset
        lda     zdst
        sbc     zofs
        sta     zsrc
        lda     zdst+1
        sbc     zofs+1
        sta     zsrc+1
        jsr     gamma                   ; the length - 1
        inc     zval
        bne     @c
        inc     zval+1
@c:     ldy     #0
        lda     (zsrc),y
        sta     (zdst),y
        inc     zsrc
        bne     :+
        inc     zsrc+1
:       inc     zdst
        bne     :+
        inc     zdst+1
:       jsr     cuenta
        bne     @c
        beq     token

; zval - 1; Z when it is 0
cuenta: lda     zval
        bne     :+
        dec     zval+1
:       dec     zval
        lda     zval
        ora     zval+1
        rts

; the next bit in C
lee_bit: asl     zbits
        bne     :+
        jsr     crudo
        sec
        rol     a
        sta     zbits
:       rts

; zval := gamma: 1, then for each 0 bit the next bit shifted in, until a 1 bit
gamma:  lda     #1
        sta     zval
        lda     #0
        sta     zval+1
@g:     jsr     lee_bit
        bcs     @f
        jsr     lee_bit
        rol     zval
        rol     zval+1
        jmp     @g
@f:     rts

; a byte of the file (CHRIN), added to the checksum
crudo:
.ifdef CINTA
        lda     #IO_
        sta     $01
        jsr     T_BYTE
        tax
.else
        lda     #$36
        sta     $01
        jsr     CHRIN
        tax
        lda     ST                      ; a timeout or no device: an error (bit 6, the end, is not)
        and     #$83
        bne     error
.endif
        lda     #RAM_
        sta     $01
        txa
        clc
        adc     zsuma
        sta     zsuma
        bcc     :+
        inc     zsuma+1
:       txa
        rts

.ifdef DISCO
; OPEN 2,UNIDAD,2,name (A = its length, X/Y = it): CHKIN 2
abre:   pha
        lda     #$36
        sta     $01
        pla
        jsr     SETNAM
        lda     #2
        ldx     UNIDAD
        ldy     #2
        jsr     SETLFS
        jsr     OPEN
        bcs     mal
        ldx     #2
        jsr     CHKIN
        bcc     :+
mal:    jmp     error
:       rts

; the file closed
cierra: lda     #$36
        sta     $01
        jsr     CLRCHN
        lda     #2
        jmp     CLOSE
.endif

error:  sei
        lda     #$35
        sta     $01
:       inc     $D020
        jmp     :-

; the mark: the picture's cells outside the game's screen blackened (columns 0-3 and 36-39 of rows 0-23, the 40 cells
; of row 24: screen RAM and colour RAM 0; $D021 is black), as the game's data in their bitmap bytes comes next
negro:  lda     #$35                    ; the I/O in: the colour RAM
        sta     $01
        lda     #<$C000
        sta     zsrc
        lda     #>$C000
        sta     zsrc+1
        lda     #<$D800
        sta     zdst
        lda     #>$D800
        sta     zdst+1
        ldx     #25                     ; rows left (1: row 24, every cell)
@fila:  ldy     #39
@celda: cpx     #1
        beq     @negra
        cpy     #4
        bcc     @negra
        cpy     #36
        bcc     @sigue
@negra: lda     #0
        sta     (zsrc),y
        sta     (zdst),y
@sigue: dey
        bpl     @celda
        clc
        lda     zsrc
        adc     #40
        sta     zsrc
        bcc     :+
        inc     zsrc+1
:       clc
        lda     zdst
        adc     #40
        sta     zdst
        bcc     :+
        inc     zdst+1
:       dex
        bne     @fila
        lda     #$34
        sta     $01
        rts

; ---- the end ----
fin:    lda     zsuma                   ; the checksum of everything before it
        sta     zofs
        lda     zsuma+1
        sta     zofs+1
        jsr     crudo
        cmp     zofs
        bne     error
        jsr     crudo
        cmp     zofs+1
        bne     error
.ifdef CINTA
        lda     #IO_                    ; the block's own checksum, the motor off
        sta     $01
        jsr     T_CIERRA
        bcc     :+
        jmp     error
:       lda     zfase
        bne     textos_hechos
        lda     OPCIONES
        and     #OPC_INGLES
        beq     textos_hechos
        inc     zfase                   ; English: its bytes, segments as the game's stream's
        lda     #ID_TEXTOS_EN
        jsr     T_ABRE
        lda     #RAM_
        sta     $01
        lda     #0
        sta     zsuma
        sta     zsuma+1
        lda     #$80
        sta     zbits
        jmp     segmento
textos_hechos:
.elseif .defined(DISCO)
        jsr     cierra                  ; the file closed
        lda     zfase
        bne     textos_hechos
        lda     OPCIONES
        and     #OPC_INGLES
        beq     textos_hechos
        inc     zfase                   ; English: the file TEXTOS, segments as the game's stream's
        lda     #textos_fin - textos
        ldx     #<textos
        ldy     #>textos
        jsr     abre
        lda     #RAM_
        sta     $01
        lda     #0
        sta     zsuma
        sta     zsuma+1
        lda     #$80
        sta     zbits
        jmp     segmento
textos_hechos:
.else
        lda     #$36                    ; the file closed
        sta     $01
        jsr     CLRCHN
        lda     #2
        jsr     CLOSE
.endif
        sei
        lda     #$35
        sta     $01
        lda     #$0B                    ; the picture hidden: the display blanked (black, as the CPC's black inks)
        sta     $D011
        lda     #$34
        sta     $01
.if .defined(CINTA) || .defined(DISCO)
        lda     OPCIONES                ; a sound off: its note a rest, so that the game plays
        and     #OPC_SIN_PASOS          ; it as before, silent (objetos_sonido.s, cinta_paso)
        beq     :+
        ldx     #zpaso
        jsr     silencio
:       lda     OPCIONES
        and     #OPC_SIN_TEXTO
        beq     :+
        ldx     #zpitido
        jsr     silencio
:       lda     OPCIONES                ; (before page 2 is put back) the menu's options for the game
opciones:
        sta     $FFFF                   ; (plat_opciones, from the header)
.endif
.ifdef CINTA
        lda     #1                      ; the game's ending and saves: the tape
.elseif .defined(DISCO)
        lda     UNIDAD                  ; the game's ending and saves: the menu's drive
.else
        lda     FA                      ; the game's disk calls use the device it was loaded from
        cmp     #8
        bcs     unidad
        lda     #8
.endif
unidad: sta     $FFFF                   ; (plat_unidad, from the header)
        ldx     #5                      ; the pages held aside: the score bar's rows, pages 2 and 3
@p:     lda     paginas_src,x
        sta     zsrc+1
        lda     paginas_lo,x
        sta     zdst
        lda     paginas_hi,x
        sta     zdst+1
        ldy     #0
        sty     zsrc
:       lda     (zsrc),y
        sta     (zdst),y
        iny
        bne     :-
        dex
        bpl     @p
        lda     #<$E020                 ; the play area (rows 0-19, cells 4-35) cleared, as in the image
        sta     zdst
        lda     #>$E020
        sta     zdst+1
        ldx     #20
@a:     lda     #0
        tay
:       sta     (zdst),y
        iny
        bne     :-
        clc
        lda     zdst
        adc     #<320
        sta     zdst
        lda     zdst+1
        adc     #>320
        sta     zdst+1
        dex
        bne     @a
        ldx     #$0D                    ; the zero page: the game's $90-$9D back, $02-$23 and $9E-$FF as in the
:       lda     ZP_KERNAL,x             ; image (0: nothing of the game's)
        sta     $90,x
        dex
        bpl     :-
        lda     #0
        ldx     #$9E
:       sta     $00,x
        inx
        bne     :-
        ldx     #$23 - $02
:       sta     $02,x
        dex
        bpl     :-
salto:  jmp     $FFFF                   ; (principal_inicio, from the header)

nada:   rti

.if .defined(CINTA) || .defined(DISCO)
; 0Fh (a rest) at the address in the zero page at X (the I/O out: $01 = $34 here)
silencio:
        lda     0,x
        sta     zsrc
        lda     1,x
        sta     zsrc+1
        ldy     #0
        lda     #$0F
        sta     (zsrc),y
        rts
.endif

.segment "RODATA"
paginas_src: .byte >MARCADOR, >MARCADOR + 1, >MARCADOR + 2, >MARCADOR + 3, >PAGINA2, >PAGINA3
paginas_lo:  .byte <$F920, <$FA60, <$FBA0, <$FCE0, <$0200, <$0300
paginas_hi:  .byte >$F920, >$FA60, >$FBA0, >$FCE0, >$0200, >$0300
nombre: .byte   $4A, $55, $45, $47, $4F ; "JUEGO" in PETSCII (c1541 writes "juego" so)
nombre_fin:
.ifdef DISCO
textos: .byte   $54, $45, $58, $54, $4F, $53 ; "TEXTOS"
textos_fin:
.endif
