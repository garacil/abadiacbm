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


; abadia128ks on the P500 (the CBM-II 510, -D P500: doc/referencias/p500.md): the I/O chips, all of them in bank 15,
; and the macros through which the code shared with the C64 and the C128 reaches the VIC-II and the SID.
;
; The MOS 6509 has the 6502's instructions and no others; what it adds is two registers at $0000 and $0001 of every
; bank: the execution bank (where the program runs) and the indirect bank, used by two instructions only, LDA (zp),Y
; and STA (zp),Y, which read or write that bank (Commodore's 700 reference manual; cc65's cbm510 runtime works so).
; The game runs in bank 0 with $01 = 0, so its own (zp),Y accesses stay in bank 0; an I/O register is reached by
; $01 = 15, LDA/STA (pointer),Y, $01 = 0.
;
; VIC_STA reg[, x|y]   STA $D000 + reg (,X or ,Y): the VIC-II register reg (0-$2E)
; VIC_LDA reg          LDA $D000 + reg
; SID_STA reg[, x]     STA SID + reg (,X)
; On the C64 and the C128 each one is that plain instruction (the same bytes as before the P500 existed).  On the P500
; each one is PHP, SEI, the value into P5_A, LDA #reg, JSR to a routine of plataforma/p500.s (p5_vic_k / _x / _y,
; p5_sid_k / _x, p5_vic_lee), PLP: the routine runs with the interrupts held off (P5_A, P5_Y and P5_PIO are its own
; meanwhile), $01 = 15 for the access and 0 after; VIC_STA and SID_STA keep A, X, Y and every flag, VIC_LDA keeps X,
; Y, C and V and sets N and Z of A.  About 60 cycles against 5: they are for the head sprites and the sound, not for
; the drawing.

.ifndef IO500_INC
IO500_INC = 1

.ifdef P500
P5_EXEC   = $00                         ; the 6509's execution bank register
P5_IND    = $01                         ; its indirect bank register
P5_SISTEMA = $0F                        ; bank 15: the KERNAL, BASIC, the I/O
P5_VIC    = $D800                       ; the VIC-II (its registers in the C64's order)
P5_SID    = $DA00                       ; the SID
P5_CIA    = $DC00                       ; the 6526: timers; port B and port A bits 6-7 the two game ports
P5_TPI1   = $DE00                       ; 6525 TPI 1: the interrupt controller (AIR +7, mask +5); its CA / CB (control
                                        ; register +6, bits 4-7): the VIC-II's video from bank 0
P5_TPI2   = $DF00                       ; 6525 TPI 2: the keyboard (port A +0 / B +1: the 16 column lines out, port C +2
                                        ; bits 0-5: the 6 row lines in); port C bits 6-7: the VIC-II's 16 KiB of bank 0
P5_COLOR  = $D400                       ; the colour RAM
; zero page (bytes the game leaves free in the C128's layout: the game's own end at $F1, logica_b.s's lb_t3; the
; linker puts no segment above $9D, c128/juego.map)
P5_PIO    = $F2                         ; 2: any I/O register, set before each use (the interrupt keeps it)
P5_PCIA   = $F4                         ; 2: $DC00 (fixed)
P5_PTPI1  = $F6                         ; 2: $DE00 (fixed)
P5_PSID   = $F8                         ; 2: $DA00 (fixed)
P5_PVIC   = $FA                         ; 2: $D800 (fixed)
P5_A      = $FC                         ; the macros' A and Y
P5_Y      = $FD
.endif

.if .defined(P500) && !.defined(P500_PROPIO)
        .import p5_vic_k, p5_vic_x, p5_vic_y, p5_vic_lee, p5_sid_k, p5_sid_x   ; (P500_PROPIO: plataforma/p500.s)
.endif

.macro P5_STA rutina, reg               ; (the P500's STA: A to the register through the routine)
        php
        sei                             ; (before P5_A: an interrupt's own macros use it)
        sta     P5_A
        lda     #reg
        jsr     rutina
        plp
.endmacro

.macro VIC_STA reg, ind
  .ifdef P500
    .if .xmatch({ind}, {x})
        P5_STA  p5_vic_x, reg
    .elseif .xmatch({ind}, {y})
        P5_STA  p5_vic_y, reg
    .else
        P5_STA  p5_vic_k, reg
    .endif
  .elseif .xmatch({ind}, {x})
        sta     $D000 + reg, x
  .elseif .xmatch({ind}, {y})
        sta     $D000 + reg, y
  .else
        sta     $D000 + reg
  .endif
.endmacro

.macro SID_STA reg, ind
  .ifdef P500
    .if .xmatch({ind}, {x})
        P5_STA  p5_sid_x, reg
    .else
        P5_STA  p5_sid_k, reg
    .endif
  .elseif .xmatch({ind}, {x})
        sta     SID + reg, x
  .else
        sta     SID + reg
  .endif
.endmacro

.macro VIC_LDA reg
  .ifdef P500
        php
        sei
        lda     #reg
        jsr     p5_vic_lee
        plp
        ora     #0                      ; (N and Z of A; C and V as they were)
  .else
        lda     $D000 + reg
  .endif
.endmacro

.endif
