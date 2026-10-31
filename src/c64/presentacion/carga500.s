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


; The P500's game loader (abadia128ks for the CBM-II 510, c64/discop500/NOTAS.md), the presentation's carga_juego500
; (gameload, after the parchment; cc65's cbm510 runtime: the program in bank 0, IndReg = ExecReg = 0, the KERNAL of
; bank 15 called through cc65's jump table at $FF6F-$FFF5 of bank 0 and its cross-bank call at $FEC3).
; 1. The picture (the koa at A/X: 8000 bytes of bitmap, 1000 of screen RAM, 1000 of colour RAM) on the game's screen:
;    bitmap $E000, screen RAM $C000 (bank 0, the VIC-II's 16 KiB at $C000 as cc65 set it), colour RAM $D400 (bank 15),
;    the VIC-II as the game has it ($D818 = $08, multicolour; TPI 1's CA and CB as cc65 and the game set them).  The
;    bitmap's bytes from $FEC0 on (row 24, cells 24-39)
;    are cc65's cross-bank call and jump table, needed by the loads: left out, those cells black.  cc65's C stack lies
;    under the bitmap too: no C from here on.
; 2. The game's files into bank 1 with the KERNAL (LOAD: A = bank 1, X = Y = $FF: at the file's own address), the
;    name, the file, the drive and the secondary address written directly into the KERNAL's zero page (bank 15: FNAM
;    $90-$92, FNAM_LEN $9D, LA $9E, FA $9F, SA $A0): "B" (the game's bank 1), "J" (its bank 0 crunched), "E" when
;    English was chosen.
; 3. The last stage (c64/discop500/etapa500.s) copied to bank 1's ETAPA with the menu's options and the drive; every
;    interrupt off (the 6526's, TPI 1's mask 0); bank 1's $FFF8 = JMP ETAPA; the CPU moved to bank 1 by bank 0's $FFF6
;    (cc65's STA ExecReg / RTS): never returns.  A load error flashes the border for ever.

        .export _carga_juego500
        .import _opciones500, _unidad500
        .importzp ptr1, ptr2, cia2, tpi1, vic
        .include "cbm510.inc"           ; ExecReg, IndReg
        .include "disco500.inc"         ; OPC_INGLES, ETAPA, ETAPA_OPCIONES, ETAPA_UNIDAD

; (FNAM $90 and FNAM_LEN $9D: cbm510.inc, as the ROM's SETNAM $FB40 writes them)
LA      = $9E
FA      = $9F
SA      = $A0
K_LOAD  = $FFD5

.segment "RODATA"
etapa:  .incbin "etapa500.bin"
etapa_fin:
LARGO = etapa_fin - etapa
        .assert LARGO <= $0E00, error, "the stage must fit $0200-$0FFF of bank 1"
nombre_b: .byte $42                     ; "B", "J", "E" in PETSCII (as c1541 wrote them)
nombre_j: .byte $4A
nombre_e: .byte $45
; the VIC-II as the game has it: (register, value), the display last
vic_reg: .byte  $11, $0B, $15, $00, $20, $00, $21, $00, $18, $08, $16, $18
VIC_N = * - vic_reg

.segment "CODE"

.proc _carga_juego500
        sta     ptr1                    ; the koa
        stx     ptr1+1
        ldx     #0                      ; the VIC-II blanked meanwhile, black, no sprite, the game's layout
:       lda     vic_reg+1,x
        ldy     vic_reg,x
        jsr     pon_vic
        inx
        inx
        cpx     #VIC_N
        bne     :-
        lda     #$0F                    ; TPI 1's control: CA and CB as cc65's start-up and the game set them (bits 4-7
        sta     IndReg                  ;   = 1010: the VIC-II's screen RAM and bitmap from bank 0's $C000-$FFFF); the
        ldy     #$06                    ;   parchment's io.c (screenbitmapmulticolor) left $03, with which the VIC-II
        lda     (tpi1),y                ;   shows nothing of the game's screen
        and     #$0F
        ora     #$A0
        sta     (tpi1),y
        lda     ExecReg
        sta     IndReg
        lda     #<$E000                 ; the bitmap, $E000-$FEBF
        sta     ptr2
        lda     #>$E000
        sta     ptr2+1
        ldx     #$1E                    ; 30 pages, then $C0 bytes
        ldy     #0
:       lda     (ptr1),y
        sta     (ptr2),y
        iny
        bne     :-
        inc     ptr1+1
        inc     ptr2+1
        dex
        bne     :-
:       lda     (ptr1),y
        sta     (ptr2),y
        iny
        cpy     #$C0
        bne     :-
        lda     ptr1                    ; ptr1 = the koa's screen RAM ($1F40 on)
        clc
        adc     #<($1F40 - $1E00)
        sta     ptr1
        lda     ptr1+1
        adc     #>($1F40 - $1E00)
        sta     ptr1+1
        lda     #<$C000                 ; the screen RAM
        sta     ptr2
        lda     #>$C000
        sta     ptr2+1
        ldx     #4
        ldy     #0
:       lda     (ptr1),y
        sta     (ptr2),y
        iny
        bne     :-
        inc     ptr1+1
        inc     ptr2+1
        dex
        bne     :-
        lda     #0                      ; row 24, cells 24-39 black (their bitmap bytes left out)
        ldx     #15
:       sta     $C000 + 24 * 40 + 24,x
        dex
        bpl     :-
        lda     ptr1                    ; the colour RAM: from the koa's $2328 (screen RAM + 1000)
        sec
        sbc     #<(1024 - 1000)
        sta     origen
        lda     ptr1+1
        sbc     #>(1024 - 1000)
        sta     origen+1
        lda     #<$D400
        sta     ptr2
        lda     #>$D400
        sta     ptr2+1
        ldx     #4
        ldy     #0
color:  .byte   $B9                     ; LDA abs,Y (bank 0 whatever IndReg: the 6509's LDA abs reads the
origen: .word   0                       ;   execution bank)
        pha
        lda     #$0F
        sta     IndReg
        pla
        sta     (ptr2),y
        lda     ExecReg
        sta     IndReg
        iny
        bne     color
        inc     origen+1
        inc     ptr2+1
        dex
        bne     color
        lda     #$0F
        sta     IndReg
        lda     #0
        ldy     #24 * 40 + 24 - $300    ; (the colour of row 24's cells 24-39: ptr2 is $D800 now, $D700 + ...)
        dec     ptr2+1
:       sta     (ptr2),y
        iny
        cpy     #24 * 40 + 40 - $300
        bne     :-
        lda     ExecReg
        sta     IndReg
        ldy     #$11                    ; the display on: bitmap mode
        lda     #$3B
        jsr     pon_vic
        ldx     #<nombre_b              ; the game's files
        ldy     #>nombre_b
        jsr     carga
        ldx     #<nombre_j
        ldy     #>nombre_j
        jsr     carga
        lda     _opciones500
        and     #OPC_INGLES
        beq     :+
        ldx     #<nombre_e
        ldy     #>nombre_e
        jsr     carga
:       sei
        lda     #<ETAPA                 ; the last stage into bank 1
        sta     ptr2
        lda     #>ETAPA
        sta     ptr2+1
        lda     #<etapa
        sta     etp
        lda     #>etapa
        sta     etp+1
        ldx     #>(LARGO + 255)
        ldy     #0
cp:     .byte   $B9                     ; LDA abs,Y
etp:    .word   0
        pha
        lda     #1
        sta     IndReg
        pla
        sta     (ptr2),y
        lda     ExecReg
        sta     IndReg
        iny
        bne     cp
        inc     etp+1
        inc     ptr2+1
        dex
        bne     cp
        lda     #1                      ; its options and drive; bank 1's $FFF8: JMP ETAPA
        sta     IndReg
        ldy     #0
        lda     #<ETAPA_OPCIONES
        sta     ptr2
        lda     #>ETAPA_OPCIONES
        sta     ptr2+1
        lda     _opciones500
        sta     (ptr2),y
        iny
        lda     _unidad500
        sta     (ptr2),y
        lda     #<$FFF8
        sta     ptr2
        lda     #>$FFF8
        sta     ptr2+1
        ldy     #0
        lda     #$4C
        sta     (ptr2),y
        iny
        lda     #<ETAPA
        sta     (ptr2),y
        iny
        lda     #>ETAPA
        sta     (ptr2),y
        lda     #$0F                    ; no interrupt any more: the 6526's off, TPI 1's mask 0, its active one ended
        sta     IndReg
        ldy     #$0D
        lda     #$7F
        sta     (cia2),y
        lda     (cia2),y
        ldy     #$05
        lda     #0
        sta     (tpi1),y
        ldy     #$07
        lda     (tpi1),y
        sta     (tpi1),y
        lda     ExecReg
        sta     IndReg
        lda     #1                      ; bank 1: bank 0's $FFF6 is STA ExecReg (cc65's), bank 1's $FFF8 the JMP
        jmp     $FFF6
.endproc

; A into the VIC-II's register Y ($D800 + Y, bank 15: cc65's pointer `vic`).  A, X kept
.proc pon_vic
        pha
        lda     #$0F
        sta     IndReg
        pla
        sta     (vic),y
        pha
        lda     ExecReg
        sta     IndReg
        pla
        rts
.endproc

; the one-letter file at X/Y (bank 0) into bank 1 at its own address, from the drive the menu found
.proc carga
        stx     nombre
        sty     nombre+1
        lda     #$0F
        sta     IndReg
        lda     #0
        sta     ptr2
        sta     ptr2+1
        ldy     #FNAM                   ; the name: its address, its bank (this one), its length
        lda     nombre
        sta     (ptr2),y
        iny
        lda     nombre+1
        sta     (ptr2),y
        iny
        lda     ExecReg
        sta     (ptr2),y
        ldy     #FNAM_LEN
        lda     #1
        sta     (ptr2),y
        ldy     #LA                     ; the file 1, the drive, secondary address 0
        sta     (ptr2),y
        ldy     #FA
        lda     _unidad500
        sta     (ptr2),y
        ldy     #SA
        lda     #0
        sta     (ptr2),y
        lda     ExecReg
        sta     IndReg
        lda     #1                      ; LOAD into bank 1 at the file's own address
        ldx     #$FF
        ldy     #$FF
        jsr     K_LOAD
        bcs     mal
        rts
mal:    lda     #$0F                    ; the border flashes for ever
        sta     IndReg
        ldy     #$20
:       lda     (vic),y
        clc
        adc     #1
        sta     (vic),y
        jmp     :-
.endproc

.segment "BSS"
nombre: .res    2
