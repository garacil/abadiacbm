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

; abadia64ks, the C64 platform layer: the machine's set-up, the 300 Hz interrupt, the Z80's DI / EI, and the
; calls with little or nothing to do on the C64 (CRTC, mode, the random byte).
;
; plat_inicio: the C64 as the game needs it (all registers clobbered; the interrupts stay off: the game's EI
;   at 2178h lets them in).  Call it once, first, with the stack set (the game's entry: LDX #$FF / TXS /
;   JSR plat_inicio).  $01 = $35 (RAM everywhere but the I/O); CIA 1 timer A every 3279 cycles (the CPC's
;   interrupt: 52 lines of 64 us = 3328 us, 300.48 Hz), its interrupt the only one (CIA 2's NMIs and the
;   VIC-II's off); the IRQ vector at $FFFE (RAM) -> plat_irq, the NMI vector (RESTORE) -> an RTI; the
;   keyboard ports; VIC bank 3, bitmap $E000, screen RAM $C000, multicolour; the border and the background
;   black, the screen RAM and the colour RAM all black (the game's palette fills its cells: plat_tinta);
;   the SID at rest (psg_inicio).
; plat_irq: the 300 Hz interrupt.  Keeps A and $01 (the game may be reading under the I/O, $01 = $34); the
;   flags come back with the RTI; X and Y are kept by the callees (they save them only on the paths that use them:
;   nothing to do is the common case).  The game's build (-D JUEGO) has sys_tick inline (below); without JUEGO
;   (the platform's tests): $01 = $35, CLD, CIA 1 acknowledged, JSR sys_tick (the game's 2899h: the I flag is set
;   from the interrupt's entry to the RTI but for t_frase's character, its CLI).
; plat_di / plat_ei: SEI / CLI (A, X, Y kept).
; plat_crtc (A = register, X = value): nothing.  The game programs the CRTC only for its screen's geometry:
;   R1 = 20h, R2 = 2Bh, R6 = 18h (32 x 24 characters, the 256 x 192 picture) at every new game (20C8h), and
;   back to the standard screen in the developers' exit, which is never reached (1E63h).  On the C64 the game's
;   picture is fixed by plat_inicio (cells 4-35 of rows 0-23, the rest black).
; plat_modo (A = mode): nothing.  The game sets mode 1 only (its start-up, 3568h): the multicolour bitmap.
; plat_aleatorio: A = a random byte (the Z80's LD A,R at 518Ah: the mirror's numeral when the manuscript is
;   read): CIA 1 timer A's low byte (the cycle within the tick) EOR the raster line.  X, Y kept.

        .include "plat64.inc"
        .export plat_inicio, plat_irq, plat_nmi, plat_di, plat_ei, plat_crtc, plat_modo, plat_aleatorio
        .import psg_inicio
.ifdef JUEGO
        .include "mapa.inc"             ; D64_SYS_TICKS, D64_TXT_SCROLL_TIMER (the game's map)
        .import s_interrupcion, t_frase
        .export plat_irq_sonido
.else
        .import sys_tick
.endif
.ifdef C128
        .import c128_inicio
.endif

.segment "CODE"

.proc plat_inicio
        sei
        cld
        lda     #MEM_IO
        sta     MEMCFG
        lda     #$7F                    ; no interrupts from the CIAs
        sta     CIA1_ICR
        sta     CIA2_ICR
        lda     CIA1_ICR
        lda     CIA2_ICR
        lda     #0                      ; none from the VIC-II, no sprites
        sta     VIC_D01A
        sta     VIC_D015
        sta     VIC_BORDE
        sta     VIC_FONDO
        lda     #$FF
        sta     VIC_D019
        sta     CIA1_DDRA               ; the keyboard: columns out, rows in
        sta     CIA1_PRA
        lda     #0
        sta     CIA1_DDRB
        lda     #<plat_nmi              ; the vectors (RAM: the KERNAL is off)
        sta     $FFFA
        sta     $FFFC
        lda     #>plat_nmi
        sta     $FFFB
        sta     $FFFD
        lda     #<plat_irq
        sta     $FFFE
        lda     #>plat_irq
        sta     $FFFF
.ifdef C128
        jsr     c128_inicio             ; the common RAM, block 1's vectors (plataforma/c128.s)
.endif
        lda     CIA2_DDRA               ; VIC bank 3 ($C000-$FFFF): bits 0-1 = 00 (the serial bus bits kept)
        ora     #$03
        sta     CIA2_DDRA
        lda     CIA2_PRA
        and     #$FC
        sta     CIA2_PRA
        lda     #$08                    ; screen RAM $C000, bitmap $E000
        sta     VIC_D018
        lda     #$18                    ; multicolour, 40 columns
        sta     VIC_D016
        ldx     #0                      ; the screen RAM and the colour RAM black
        txa
:       sta     PANTALLA,x
        sta     PANTALLA+$100,x
        sta     PANTALLA+$200,x
        sta     PANTALLA+$2E8,x
        sta     COLOR_RAM,x
        sta     COLOR_RAM+$100,x
        sta     COLOR_RAM+$200,x
        sta     COLOR_RAM+$2E8,x
        inx
        bne     :-
        lda     #$3B                    ; bitmap mode, display on, 25 rows
        sta     VIC_D011
        jsr     psg_inicio
        lda     #<(CICLOS_TICK - 1)     ; CIA 1 timer A: the tick
        sta     CIA1_TAL
        lda     #>(CICLOS_TICK - 1)
        sta     CIA1_TAH
        lda     #$11                    ; load, start, continuous
        sta     $DC0E
        lda     #$81                    ; its interrupt on
        sta     CIA1_ICR
        rts
.endproc

.ifdef C128
.segment "COMUN"                        ; (the C128: in the common RAM, for an interrupt while block 1 is mapped)
.endif
.ifdef JUEGO
; the game's build (-D JUEGO; the speed work's round 5, brought back: the
; interrupt routines in their most optimised form): the game's sys_tick (2899h) inline: CIA 1 acknowledged,
; the tick counter [289C] + 1 kept at FFh, the sound (0CD0) and the phrase scroller (368A).  The sound's test is the
; opcode at plat_irq_sonido: JSR s_interrupcion while a channel plays (state bit 0), BIT abs (no call) else, written
; by objetos_sonido.s where a state's bit 0 changes (s_pon, a sequence's end, snd_silence_all).  The memory
; configuration kept and the I/O in (the C64: $01's bit 0 set, $34 -> $35, $35 stays; the C128: MEM_IO).  No CLD on
; the C64 (nothing in the game sets the decimal mode: no SED in its sources); the C128 keeps it (its KERNAL runs
; between games' frames).  Measured then: an empty tick 96 -> 69 cycles; the outputs, the SID's writes, identical.
.proc plat_irq
        pha
        lda     MEMCFG
        pha
.ifdef C128
        lda     #MEM_IO
        sta     MEMCFG
        cld
.else
        ora     #$01
        sta     MEMCFG
.endif
        lda     CIA1_ICR                ; acknowledged
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
        sta     MEMCFG
        pla
        rti
.endproc
.else
.proc plat_irq
        pha
        lda     MEMCFG
        pha
        lda     #MEM_IO
        sta     MEMCFG
        cld
        lda     CIA1_ICR                ; acknowledged
        jsr     sys_tick                ; (X and Y kept)
        pla
        sta     MEMCFG
        pla
        rti                             ; (its own: on the C128 plat_nmi's body follows)
.endproc
.endif
.ifdef C128
; the C128: CIA 2's timers switch the 8502's clock (plataforma/c128.s, c128_rapido): A below the display -> 2 MHz,
; B above it -> 1 MHz; the RESTORE key's NMI (no CIA 2 flag) changes nothing.  The I/O made visible meanwhile (the
; game may be reading or writing the RAM under it, MEMCFG = MEM_RAM, or block 1): A, the flags and MEMCFG kept.
.proc plat_nmi
        pha
        lda     MEMCFG
        pha
        lda     #MEM_IO
        sta     MEMCFG
        lda     CIA2_ICR                ; the flags (and acknowledged)
        lsr     a
        bcc     :+
        lda     #1
        sta     $D030
        bne     fin                     ; (always)
:       lsr     a
        bcc     fin
        lda     #0
        sta     $D030
fin:    pla
        sta     MEMCFG
        pla
        rti
.endproc
.else
.proc plat_nmi
        rti
.endproc
.endif
.segment "CODE"

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
        lda     CIA1_TAL
        eor     VIC_D012
        rts
.endproc
