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

; abadia64ks, 6502 code of the game: the zero-page registers (c64/CODIGO6502.md).  The Z80's register
; pairs, low byte first (zbc = C, zbc+1 = B), the alternate set, scratch.
zbc     = $02
zde     = $04
zhl     = $06
zix     = $08
ziy     = $0A
zbc2    = $0C
zde2    = $0E
zhl2    = $10
za2     = $12
zf2     = $13
zt0     = $14                   ; scratch $14-$1B
zp0     = $1C                   ; pointers $1C-$23

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
