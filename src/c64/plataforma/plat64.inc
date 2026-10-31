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

; abadia64ks, the C64 platform layer: the hardware it drives and its constants (c64/plataforma/README.md).
; The game's memory map: c64/MAPA.md.  VIC bank 3: screen RAM $C000, bitmap $E000; ROMs off ($01 = $35).

VIC_D011   = $D011                      ; control 1: bitmap mode, display on, 25 rows
VIC_D012   = $D012                      ; raster line
VIC_D015   = $D015                      ; sprites on
VIC_D016   = $D016                      ; control 2: multicolour, 40 columns
VIC_D018   = $D018                      ; memory pointers: screen RAM, bitmap
VIC_D019   = $D019                      ; interrupt flags
VIC_D01A   = $D01A                      ; interrupt mask
VIC_BORDE  = $D020                      ; border: the CPC border (pen 16)
VIC_FONDO  = $D021                      ; background: bit pair 00, the CPC pen 3
SID        = $D400                      ; 3 voices of 7 registers: freq lo/hi, pulse lo/hi, control, AD, SR
SID_VOLUMEN = $D418                     ; filters off, volume (bits 0-3)
COLOR_RAM  = $D800                      ; bit pair 11: the CPC pen 2 (low nibble)
CIA1_PRA   = $DC00                      ; keyboard columns (out) / joystick port 2 (in)
CIA1_PRB   = $DC01                      ; keyboard rows (in)
CIA1_DDRA  = $DC02
CIA1_DDRB  = $DC03
CIA1_TAL   = $DC04                      ; timer A: the 300 Hz interrupt
CIA1_TAH   = $DC05
CIA1_ICR   = $DC0D
CIA1_CRA   = $DC0E
CIA2_PRA   = $DD00                      ; bits 0-1: the VIC bank (00 = bank 3); bits 3-7: the serial bus
CIA2_DDRA  = $DD02
CIA2_ICR   = $DD0D
PANTALLA   = $C000                      ; screen RAM: high nibble the CPC pen 0, low nibble pen 1
MAPA_BITS  = $E000                      ; the multicolour bitmap

; the game's cells: columns 4-35 of rows 0-23 (the CPC's 256 x 192 screen); the rest keeps data, black
CELDA0     = 4
CELDAS_X   = 32
CELDAS_Y   = 24

; the 300 Hz interrupt: the CPC's (52 lines of 64 us = 3328 us, 300.48 Hz) on a PAL C64 (985248 Hz):
; 3279 cycles a period (CIA timer latch 3278)
CICLOS_TICK = 3279

; KERNAL entry points (used only by the disk calls, with the KERNAL switched in)
K_SETNAM   = $FFBD
K_SETLFS   = $FFBA
K_OPEN     = $FFC0
K_CLOSE    = $FFC3
K_LOAD     = $FFD5
K_SAVE     = $FFD8
K_IOINIT   = $FF84
K_RAMTAS   = $FF87
K_RESTOR   = $FF8A
K_CINT     = $FF81
K_CLRCHN   = $FFCC
K_VECTORES = $FD30                      ; the KERNAL ROM's table of the vectors $0314-$0333
K_FIN_IRQ  = $EA81                      ; the KERNAL's end of interrupt: PLA TAY, PLA TAX, PLA, RTI

; the memory configuration (c64/doc: the C128's MMU, doc/referencias/c128.md): on the C64 the 6510's port $01
; ($34 all RAM, $35 the I/O at $D000); on the C128 (-D C128) the MMU's configuration register $FF00, visible in every
; configuration ($3F all RAM of block 0, $3E the I/O at $D000)
.ifndef MEMCFG
.ifdef P500
; the P500 (doc/referencias/p500.md): the game runs in bank 0, which has RAM everywhere (no I/O there: its $D000-$DFFF
; is plain RAM); the 6509's indirect bank register $01 chooses the bank of LDA (zp),Y and STA (zp),Y only: 0 for the
; game's data, 1 for the data moved to bank 1, 15 for the I/O (plataforma/p500.s)
MEMCFG  = $01
MEM_RAM = $00
MEM_IO  = $00
MEM_B1  = $01
.elseif .defined(C128)
MEMCFG  = $FF00
MEM_RAM = $3F
MEM_IO  = $3E
MEM_B1  = $7F                           ; all RAM of block 1 (the data moved there: plataforma/c128.s)
.else
MEMCFG  = $01
MEM_RAM = $34
MEM_IO  = $35
.endif
; the room table (D64_ISO_ROOM_TABLE) read and written through (zhl),Y: on the C128 it lives in block 1
; (plataforma/c128.s far_lee / far_pon: A, X, Y and C as the plain instruction; far_lee sets N and Z of A)
.macro LEE_SALA
  .ifdef C128
        jsr     far_lee
  .else
        lda     (zhl),y
  .endif
.endmacro
.macro PON_SALA
  .ifdef C128
        jsr     far_pon
  .else
        sta     (zhl),y
  .endif
.endmacro
.if .defined(C128) && !.defined(C128_PROPIO)
        .import far_lee, far_pon                ; (C128_PROPIO: plataforma/c128.s, where they are)
.endif
.endif

        .include "io500.inc"            ; the I/O of the P500 (bank 15) and its macros, VIC_STA / SID_STA / VIC_LDA
