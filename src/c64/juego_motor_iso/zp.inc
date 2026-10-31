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
