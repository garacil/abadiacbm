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

; abadia64ks on tape: Exomizer's standard decruncher (exodecrunch.s, exomizer 2.0) on data in memory, as its own
; example (exodecrs/main.s): `exomizer mem` crunches backwards, get_crunched_byte reads the crunched bytes from
; their end down.  exo_desde: A/X = the crunched data's end (exclusive), then decrunched where the data says (its
; first bytes read: the destination's end); $01 must show RAM where the data is (the menu: $36).  The decruncher's
; zero page: $A7, $AE-$AF, $FC-$FF.

        .export exo_desde, get_crunched_byte
        .import decrunch

        .segment "CODE"
exo_desde:
        sta     _byte_lo
        stx     _byte_hi
        jmp     decrunch

; the previous crunched byte (X, Y and the carry kept)
get_crunched_byte:
        lda     _byte_lo
        bne     :+
        dec     _byte_hi
:       dec     _byte_lo
_byte_lo = * + 1
_byte_hi = * + 2
        lda     $FFFF                   ; (the address, set by exo_desde)
        rts
