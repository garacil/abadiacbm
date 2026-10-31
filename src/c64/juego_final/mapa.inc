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

; The memory map of this build: the C64's (mapa64.inc, made by mapa64.py next to the sources), the C128's
; (c128/mapa64.inc: construye.sh with C128=1 runs the generators into c128/, or c128_en/ for English) or the P500's
; (P500=1: p500/, p500_en/; its build defines C128 too, so it is asked first)
.if .defined(P500) && .defined(INGLES)
        .include "p500_en/mapa64.inc"
.elseif .defined(P500)
        .include "p500/mapa64.inc"
.elseif .defined(C128) && .defined(INGLES)
        .include "c128_en/mapa64.inc"
.elseif .defined(C128)
        .include "c128/mapa64.inc"
.else
        .include "mapa64.inc"
.endif
