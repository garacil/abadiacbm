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

; abadia64ks, 6502 code of the game: group camino (Z80 0000-0982; C reference juego/f_camino.c, funciones.c).
        .include "zp.inc"
        .include "mapa64.inc"
        .export iso_grid_cell_ptr

.segment "CODE"

; 0944 iso_grid_cell_ptr: the cell (x = L, y = H) of the 24-column height buffer whose base is [28DB]:
; t = 8 y; lo = (t & FF00) | (x + t) (8-bit sum); idx = 2 t + lo.  Out: IX = base + idx (a C64 address: the
; base is relocated), DE = idx, HL = lo, A = low byte of lo, C clear.
.proc iso_grid_cell_ptr
        lda     zhl+1                   ; t = 8 y
        sta     zt0
        lda     #0
        sta     zt0+1
        asl     zt0
        rol     zt0+1
        asl     zt0
        rol     zt0+1
        asl     zt0
        rol     zt0+1
        lda     zhl                     ; lo = (t high, x + t low)
        clc
        adc     zt0
        sta     zde
        lda     zt0+1
        sta     zde+1
        asl     zt0                     ; idx = 2 t + lo
        rol     zt0+1
        lda     zt0
        clc
        adc     zde
        sta     zt0
        lda     zt0+1
        adc     zde+1
        sta     zt0+1
        lda     zde                     ; HL = lo, DE = idx (EX DE,HL)
        sta     zhl
        lda     zde+1
        sta     zhl+1
        lda     zt0
        sta     zde
        lda     zt0+1
        sta     zde+1
        lda     D64_CHR_HBUF_PTR        ; IX = base + idx
        clc
        adc     zde
        sta     zix
        lda     D64_CHR_HBUF_PTR+1
        adc     zde+1
        sta     zix+1
        lda     zhl
        clc
        rts
.endproc
