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

; abadia64ks, 6502 code of the game, group logica_a: the group's own zero page ($DA-$E5, c64/CODIGO6502.md)
; and the names shared by its source files.
        .include "zp.inc"
        .include "mapa64.inc"

la_p    = $DA                   ; pointer: the queue word being expanded / source / generic
la_q    = $DC                   ; pointer: the queue's top - 6 / destination / generic
la_c    = $DE                   ; pointer: the cell (the Z80's IX) / generic
la_s    = $E0                   ; pointer: source / generic
la_t    = $E2                   ; 4 bytes of scratch kept across calls of other groups ($E2-$E5)

; D64_SPR_RECT_SIZE is in the block D64_CHR_BACKUP right after D64_SPR_RECT_POS (CPC 2928h); mapa64.inc gives
; it as a constant $2928 (a map bug, reported), so the group uses this name.
LA_RECT_SIZE = D64_SPR_RECT_POS + 2

; the CPC -> C64 distance of the path scratch (sprite buffer 7F80h .. tile buffer 8EFFh, contiguous on both)
LA_ESCRATCH = D64_SPR_BUFFER - $7F80
