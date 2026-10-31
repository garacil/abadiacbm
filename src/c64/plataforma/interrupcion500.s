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


; abadia128ks on the P500 (the CBM-II 510, doc/referencias/p500.md): the machine's set-up, the 300 Hz interrupt, the
; Z80's DI / EI and the calls with little or nothing to do (CRTC, mode, the random byte); the C64's interrupcion.s for
; the 6509 and the CBM-II's I/O.
;
; The game runs in bank 0 (code, data, the VIC-II's screen); every I/O chip is in bank 15 and is reached with the
; 6509's own cross-bank accesses, LDA (zp),Y and STA (zp),Y while its indirect bank register $01 holds 15; the game's
; own (zp),Y accesses want $01 = 0 (bank 0), or 1 for the data of bank 1 (plataforma/p500.s).
;
; plat_inicio: the P500 as the game needs it (all registers clobbered; the interrupts stay off: the game's EI at
;   2178h lets them in).  $01 = 0; the vectors of bank 0 (NMI, IRQ: an interrupt is taken in the bank that runs, its
;   vectors at $FFFA-$FFFF of that bank); the 6526 at $DC00: timer A every CICLOS_TICK cycles, its interrupt the only
;   one; the 6525 TPI 1 at $DE00 (the interrupt controller): only its input 2 (the 6526) unmasked, the 50 Hz one off;
;   CA and CB low (the VIC-II's video from bank 0) and TPI 2's PC 6-7 = 11 (the VIC-II's 16 KiB: $C000-$FFFF of bank
;   0); the VIC-II at $D800: bitmap $E000, screen RAM $C000, multicolour, no sprite, no interrupt; the border and the
;   background black, the screen RAM (bank 0) and the colour RAM ($D400, bank 15) black; the SID at rest (psg_inicio);
;   p500_inicio (plataforma/p500.s: the KERNAL's return path and its pointers).  The fixed zero-page pointers of
;   io500.inc (P5_PCIA, P5_PTPI1, P5_PSID, P5_PVIC) are set first.
; plat_irq: the 300 Hz interrupt.  Saves A, Y, $01 and the I/O pointer P5_PIO (X is kept by the callees, as on the
;   C64); $01 = 15 to acknowledge the 6526, end TPI 1's interrupt (its active interrupt register written back) and
;   read the 6526 again (see plat_irq: the order), then $01 = 0
;   for the game's sys_tick (inline as on the C64: the tick counter, the sound, the phrase scroller); everything back.
; plat_nmi: an RTI.
; plat_di / plat_ei: SEI / CLI (A, X, Y kept).
; plat_crtc, plat_modo: nothing (as on the C64).
; plat_aleatorio: A = a random byte: the 6526's timer A low byte EOR the VIC-II's raster line.  X, Y kept.

        .include "plat64.inc"
        .export plat_inicio, plat_irq, plat_nmi, plat_di, plat_ei, plat_crtc, plat_modo, plat_aleatorio
        .import psg_inicio, p500_inicio
.ifdef JUEGO
        .include "mapa.inc"             ; D64_SYS_TICKS, D64_TXT_SCROLL_TIMER (the game's map)
        .import s_interrupcion, t_frase
        .export plat_irq_sonido
.else
        .import sys_tick
.endif

.segment "CODE"

.proc plat_inicio
        sei
        cld
        ldx     #7                      ; the fixed pointers (io500.inc): P5_PCIA, P5_PTPI1, P5_PSID, P5_PVIC
:       lda     fijos,x
        sta     P5_PCIA,x
        dex
        bpl     :-
        ldx     #0
        jsr     escribe                 ; the 6526, TPI 1, the VIC-II (the table below)
        lda     #P5_SISTEMA
        sta     P5_IND
        ldy     #$0D
        lda     (P5_PCIA),y             ; the 6526's flags read: cleared
        ldy     #$06                    ; TPI 1's control: CA and CB low (bits 4-7 = 1010: the VIC-II's video from
        lda     (P5_PTPI1),y            ;   bank 0, as cc65's cbm510 crt0.s), the interrupt mode kept (bits 0-3)
        and     #$0F
        ora     #$A0
        sta     (P5_PTPI1),y
        lda     #<(P5_TPI2 + $02)       ; TPI 2's port C bits 6-7 = 11: the VIC-II's 16 KiB at $C000 of bank 0
        sta     P5_PIO
        lda     #>(P5_TPI2 + $02)
        sta     P5_PIO+1
        ldy     #0
        lda     (P5_PIO),y
        ora     #$C0
        sta     (P5_PIO),y
        lda     #<P5_COLOR              ; the colour RAM black
        sta     P5_PIO
        lda     #>P5_COLOR
        sta     P5_PIO+1
        ldx     #4
        tya
:       sta     (P5_PIO),y
        iny
        bne     :-
        inc     P5_PIO+1
        dex
        bne     :-
        stx     P5_IND                  ; bank 0 from here (X = 0)
        txa                             ; the screen RAM black
:       sta     PANTALLA,x
        sta     PANTALLA+$100,x
        sta     PANTALLA+$200,x
        sta     PANTALLA+$2E8,x
        inx
        bne     :-
        lda     #<plat_nmi              ; the vectors of bank 0
        sta     $FFFA
        sta     $FFFC
        lda     #>plat_nmi
        sta     $FFFB
        sta     $FFFD
        lda     #<plat_irq
        sta     $FFFE
        lda     #>plat_irq
        sta     $FFFF
        jsr     p500_inicio             ; the KERNAL's return path in bank 0 (plataforma/p500.s)
        ldx     #inicial2 - inicial
        jsr     escribe                 ; the display on
        jsr     psg_inicio
        ldx     #inicial3 - inicial
        jmp     escribe                 ; the tick
.endproc

; the bank 15 writes of inicial from X on (the register's address low, high, the value) up to a high byte 0; $01 = 15
; meanwhile, 0 after.  A, X, Y clobbered
.proc escribe
        lda     #P5_SISTEMA
        sta     P5_IND
        ldy     #0
:       lda     inicial,x
        sta     P5_PIO
        lda     inicial+1,x
        beq     fin
        sta     P5_PIO+1
        lda     inicial+2,x
        sta     (P5_PIO),y
        inx
        inx
        inx
        bne     :-
fin:    sty     P5_IND
        rts
.endproc

.segment "RODATA"
fijos:  .word   P5_CIA, P5_TPI1, P5_SID, P5_VIC
.macro REG direccion, valor
        .byte   <(direccion), >(direccion), valor
.endmacro
inicial:
        REG     P5_CIA + $0D, $7F       ; the 6526: no interrupt
        REG     P5_CIA + $0E, $00       ; timers A and B stopped
        REG     P5_CIA + $0F, $00
        REG     P5_CIA + $02, $00       ; ports A and B in: the game ports (as the KERNAL's reset, $FA3C)
        REG     P5_CIA + $03, $00
        REG     P5_TPI1 + $05, $04      ; TPI 1's interrupt mask: input 2 (the 6526) only
        REG     P5_TPI1 + $07, $00      ; TPI 1: any active interrupt ended
        REG     P5_VIC + $1A, $00       ; the VIC-II: no interrupt, no sprite
        REG     P5_VIC + $19, $FF
        REG     P5_VIC + $15, $00
        REG     P5_VIC + $20, $00       ; border and background black
        REG     P5_VIC + $21, $00
        REG     P5_VIC + $18, $08       ; screen RAM $C000, bitmap $E000
        REG     P5_VIC + $16, $18       ; multicolour, 40 columns
        .byte   0, 0
inicial2:
        REG     P5_VIC + $11, $3B       ; bitmap mode, display on, 25 rows
        .byte   0, 0
inicial3:
        REG     P5_CIA + $04, <(CICLOS_TICK - 1)        ; the 6526's timer A: the tick
        REG     P5_CIA + $05, >(CICLOS_TICK - 1)
        REG     P5_CIA + $0E, $11       ; load, start, continuous
        REG     P5_CIA + $0D, $81       ; its interrupt on
        .byte   0, 0

.segment "CODE"

.ifdef JUEGO
; the game's build: the game's sys_tick (2899h) inline, as interrupcion.s's: the 6526 and the 6525 acknowledged, the
; tick counter [289C] + 1 kept at FFh, the sound (0CD0: the opcode at plat_irq_sonido, JSR while a channel plays, BIT
; else) and the phrase scroller (368A).  t_frase lets a further tick in (its CLI): this handler is re-entrant.
.proc plat_irq
        pha
        tya
        pha
        lda     P5_IND
        pha
        lda     P5_PIO
        pha
        lda     P5_PIO+1
        pha
        lda     #P5_SISTEMA
        sta     P5_IND
        ldy     #$0D                    ; the 6526's flags read: its line up
        lda     (P5_PCIA),y
        ldy     #$07                    ; TPI 1's active interrupt ended (written back); with the 6526's line still
        lda     (P5_PTPI1),y            ;   down it would be taken again at once, an endless stream of interrupts
        sta     (P5_PTPI1),y
        ldy     #$0D                    ; the 6526's flags again: an underflow between the two reads, whose interrupt
        lda     (P5_PCIA),y             ;   TPI 1 has just ended, would leave its line down for ever (no new edge, no
                                        ;   tick any more); this read puts it up (that one tick is lost)
        lda     #0
        sta     P5_IND                  ; the game's data
        cld
        inc     D64_SYS_TICKS           ; 2899h: the tick counter, kept at FFh
        bne     :+
        dec     D64_SYS_TICKS
:
::plat_irq_sonido:
        bit     s_interrupcion          ; 0CD0: JSR ($20) while a channel plays (objetos_sonido.s), BIT ($2C) else
        inc     D64_TXT_SCROLL_TIMER    ; 368A's test: the scroller's 2Dh-th tick
        lda     D64_TXT_SCROLL_TIMER
        cmp     #$2D
        bne     :+
        jsr     t_frase                 ; (X and Y kept)
:       pla
        sta     P5_PIO+1
        pla
        sta     P5_PIO
        pla
        sta     P5_IND
        pla
        tay
        pla
        rti
.endproc
.else
.proc plat_irq
        pha
        tya
        pha
        lda     P5_IND
        pha
        lda     P5_PIO
        pha
        lda     P5_PIO+1
        pha
        lda     #P5_SISTEMA
        sta     P5_IND
        ldy     #$0D                    ; (as above: the 6526, TPI 1, the 6526 again)
        lda     (P5_PCIA),y
        ldy     #$07
        lda     (P5_PTPI1),y
        sta     (P5_PTPI1),y
        ldy     #$0D
        lda     (P5_PCIA),y
        lda     #0
        sta     P5_IND
        cld
        jsr     sys_tick                ; (X and Y kept)
        pla
        sta     P5_PIO+1
        pla
        sta     P5_PIO
        pla
        sta     P5_IND
        pla
        tay
        pla
        rti
.endproc
.endif

.proc plat_nmi
        rti
.endproc

.proc plat_di
        sei
        rts
.endproc

.proc plat_ei
        cli
        rts
.endproc

plat_crtc:
plat_modo:
        rts

.proc plat_aleatorio
        php
        sei
        tya
        pha
        lda     P5_IND
        pha
        lda     P5_PIO
        pha
        lda     P5_PIO+1
        pha
        lda     #P5_SISTEMA
        sta     P5_IND
        ldy     #$04
        lda     (P5_PCIA),y             ; the 6526's timer A, low byte
        sta     aleatorio
        lda     #<(P5_VIC + $12)
        sta     P5_PIO
        lda     #>(P5_VIC + $12)
        sta     P5_PIO+1
        ldy     #0
        lda     (P5_PIO),y              ; the raster line
        eor     aleatorio
        sta     aleatorio
        pla
        sta     P5_PIO+1
        pla
        sta     P5_PIO
        pla
        sta     P5_IND
        pla
        tay
        lda     aleatorio
        plp
        rts
.endproc

.segment "BSS"
aleatorio: .res 1
