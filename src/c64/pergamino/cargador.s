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

; abadia64ks, the first stage's end: the loader of the game (c64/cinta/FLUJO.md).  It runs at $C3E8 (copied there by
; carga.s once the parchment is over and the loading screen is set up) and reads the file "juego" (the stream that
; c64/cinta/flujo.py makes from the game's image) byte by byte with the KERNAL (OPEN / CHKIN / CHRIN), as the CPC
; tape's loader read the block 20h: the loading picture appears in the CPC's byte order as the bytes arrive, the
; game's memory fills, and at the end it jumps to the game (principal_inicio).
;
; Memory.  The game needs nearly all the RAM, so the loader lives where the game needs nothing at its start
; (checked: c64/cinta/libres.py): $C3E8-$C6FF (the screen RAM's unused tail, the tiles' merge tables, rebuilt by the
; game's start-up 3607), the zero page $02-$23, the stack page.  What the game needs where the loader or the KERNAL
; work during the load is held aside and put in place at the end:
;   $0200-$03FF (the KERNAL's pages: vectors, file tables)  -> $BF00 and $C700 (merge tables)
;   $0090-$009D (the game's operands in the KERNAL's zero page) -> $0100-$010D
;   the score bar, bitmap rows 20-23, cells 4-35 (the picture is shown there) -> $BB00-$BEFF (merge tables)
; The picture is shown where the game's screen is: VIC bank 3, screen RAM $C000, bitmap $E000, cells 4-35 of rows
; 0-23; $D021 and the border black; the cells outside are black and their bitmap bytes are the game's data,
; loaded as they come.
;
; The stream (c64/cinta/FLUJO.md, "The stream"): a load address (2 bytes, ignored), the header (the CPC position
; step a byte, 16 bits, 8.8; principal_inicio; the address of plat_unidad), the scheduled bytes, a checksum (the
; 16-bit sum of every byte before it).  The scheduled bytes are of two kinds, told apart by the schedule alone:
;   the picture: 6144 bitmap bytes (the C64 conversion with black as $D021) in the CPC's order (line 7 of every
;     character row from the bottom row up, right to left, then line 6, ...): each is two CPC bytes, two nibbles;
;   the data: segments the decoder below writes into the memory, then 00 00.
; Each byte read moves a counter of the CPC tape's position on by `zpaso` (65024 / the bytes of the stream: the
; whole stream stands for the CPC's 65024 bytes); a nibble of the picture is due when that position reaches its
; CPC byte (the screen's bytes are the first 16384 of the CPC block, the 512 hidden ones of each 2 KiB line block
; included): the next byte is then a picture byte (its low nibble shown at once, its high nibble at the next
; due position), else a data byte.  When the picture is complete the true colours of the cells that lent a
; colour to the pink are read (`arreglos`).
;
; $01 = $34 (all RAM) all the time but around CHRIN ($36: KERNAL and I/O); no interrupt (CIA 1 and 2 and the VIC-II
; masked; NMI -> an RTI).  A read error or a wrong checksum flashes the border for ever.

        .export inicio, fin_linea, arreglos, fin, salto, error, leer
        .export MARCADOR, PAGINA2, PAGINA3, ZP_KERNAL

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

LINEA7  = $E000 + 23 * 320 + 35 * 8 + 7 ; the first picture byte: row 23, cell 35, line 7

; the zero page ($02-$23: nothing of the game's)
zdst    = $02                           ; where the data go
zsrc    = $04                           ; a copy's source
zpic    = $06                           ; the picture byte being shown
zval    = $08                           ; gamma value, counts
zacc    = $0A                           ; 3: the CPC position x 256
zpaso   = $0D                           ; 2: added a byte
zpos    = $0F                           ; 2: the CPC position of the next nibble
zbits   = $11                           ; the bit buffer (a 1 marks its end)
zpicb   = $12                           ; the picture byte
zcel    = $13                           ; cells left in the row
zfil    = $14                           ; rows left in the line
zlin    = $15                           ; lines left: 0 = the picture is complete
zalto   = $16                           ; 1: its high nibble is the next
zsuma   = $17                           ; 2: the checksum
zofs    = $19                           ; 2
ztmp    = $1B
zarr    = $1C                           ; 2: the colour fixes' pointer
zn      = $1E                           ; fixes left
ZP_FIN  = $23

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
        ldx     #ZP_FIN - zdst
:       sta     zdst,x
        dex
        bpl     :-
        lda     #<LINEA7
        sta     zpic
        lda     #>LINEA7
        sta     zpic+1
        lda     #<512                   ; the first visible byte: the CPC position 512
        sta     zpos
        lda     #>512
        sta     zpos+1
        lda     #32
        sta     zcel
        lda     #24
        sta     zfil
        lda     #8
        sta     zlin
        lda     #$80
        sta     zbits
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
        lda     #$34
        sta     $01
        jsr     crudo                   ; the load address
        jsr     crudo
        jsr     crudo                   ; the header
        sta     zpaso
        jsr     crudo
        sta     zpaso+1
        jsr     crudo
        sta     salto+1
        jsr     crudo
        sta     salto+2
        jsr     crudo
        sta     unidad+1
        jsr     crudo
        sta     unidad+2

; ---- the data: segments of tokens (c64/cinta/lz64.c) ----
segmento:
        jsr     leer                    ; the address; 0: the end
        sta     zdst
        jsr     leer
        sta     zdst+1
        ora     zdst
        bne     token
        jmp     fin
token:  jsr     lee_bit
        bcs     copia
        jsr     gamma                   ; 0: n literal bytes
literal:
        jsr     leer
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
        jsr     leer                    ; the offset's low byte
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
        jsr     leer
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

; ---- leer: the next data byte in A, the picture shown on the way ----
leer:   lda     zlin
        beq     paso                    ; the picture is complete
        lda     zacc+1                  ; a nibble due: the CPC position (zacc >> 8) >= zpos
        cmp     zpos
        lda     zacc+2
        sbc     zpos+1
        bcc     paso
        ldy     #0
        lda     zalto
        bne     alto
        jsr     paso                    ; a picture byte: its low nibble now (the CPC's odd byte, which
        sta     zpicb                   ; comes first)
        and     #$0F
        sta     ztmp
        ldy     #0
        lda     (zpic),y
        and     #$F0
        ora     ztmp
        sta     (zpic),y
        inc     zalto
        bne     siguiente
alto:   lda     zpicb                   ; its high nibble
        and     #$F0
        sta     ztmp
        lda     (zpic),y
        and     #$0F
        ora     ztmp
        sta     (zpic),y
        sty     zalto
        sec                             ; the next byte: the cell to the left, the row above, the next line
        lda     zpic
        sbc     #8
        sta     zpic
        bcs     :+
        dec     zpic+1
:       dec     zcel
        bne     siguiente
        lda     #32
        sta     zcel
        sec
        lda     zpic
        sbc     #64
        sta     zpic
        bcs     :+
        dec     zpic+1
:       dec     zfil
        bne     siguiente
fin_linea:
        lda     #24
        sta     zfil
        clc                             ; row 23, cell 35 of the line above: + 24 * 320 - 1
        lda     zpic
        adc     #<(24 * 320 - 1)
        sta     zpic
        lda     zpic+1
        adc     #>(24 * 320 - 1)
        sta     zpic+1
        inc     zpos+1                  ; the next 2 KiB block's 512 hidden bytes
        inc     zpos+1
        dec     zlin
        bne     siguiente
        jsr     arreglos
siguiente:
        inc     zpos
        bne     leer
        inc     zpos+1
        jmp     leer

; a byte of the file, the CPC position moved on
paso:   jsr     crudo
        pha
        clc
        lda     zacc
        adc     zpaso
        sta     zacc
        lda     zacc+1
        adc     zpaso+1
        sta     zacc+1
        bcc     :+
        inc     zacc+2
:       pla
        rts

; a byte of the file (CHRIN), added to the checksum
crudo:  lda     #$36
        sta     $01
        jsr     CHRIN
        tax
        lda     ST                      ; a timeout or no device: an error (bit 6, the end, is not)
        and     #$83
        bne     error
        lda     #$34
        sta     $01
        txa
        clc
        adc     zsuma
        sta     zsuma
        bcc     :+
        inc     zsuma+1
:       txa
        rts

error:  sei
        lda     #$35
        sta     $01
:       inc     $D020
        jmp     :-

; the picture is complete: the true colours of the cells whose least used colour was pink while they loaded
; (n entries: a step d 1-255 along the screen RAM from $C000 and the byte to put there; d = 0: 255 on, no byte)
arreglos:
        jsr     paso
        sta     zn
        lda     #<$C000
        sta     zarr
        lda     #>$C000
        sta     zarr+1
@e:     lda     zn
        beq     @f
        dec     zn
        jsr     paso
        tax
        beq     @lejos
        clc
        adc     zarr
        sta     zarr
        bcc     :+
        inc     zarr+1
:       jsr     paso
        ldy     #0
        sta     (zarr),y
        jmp     @e
@lejos: clc
        lda     zarr
        adc     #255
        sta     zarr
        bcc     @e
        inc     zarr+1
        bcs     @e
@f:     rts

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
        lda     zlin                    ; (the picture must be complete)
        bne     error
        lda     #$36                    ; the file closed
        sta     $01
        jsr     CLRCHN
        lda     #2
        jsr     CLOSE
        sei
        lda     #$35
        sta     $01
        lda     #$0B                    ; the picture hidden: the display blanked (black, as the CPC's black inks)
        sta     $D011
        lda     #$34
        sta     $01
        lda     FA                      ; the game's disk calls use the device it was loaded from
        cmp     #8
        bcs     unidad
        lda     #8
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
        ldx     #ZP_FIN - 2
:       sta     $02,x
        dex
        bpl     :-
salto:  jmp     $FFFF                   ; (principal_inicio, from the header)

nada:   rti

.segment "RODATA"
paginas_src: .byte >MARCADOR, >MARCADOR + 1, >MARCADOR + 2, >MARCADOR + 3, >PAGINA2, >PAGINA3
paginas_lo:  .byte <$F920, <$FA60, <$FBA0, <$FCE0, <$0200, <$0300
paginas_hi:  .byte >$F920, >$FA60, >$FBA0, >$FCE0, >$0200, >$0300
nombre: .byte   $4A, $55, $45, $47, $4F ; "JUEGO" in PETSCII (c1541 writes "juego" so)
nombre_fin:
