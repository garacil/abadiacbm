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

; abadia64ks, 6502 code of the game: plat_aleatorio in the build checked by the hybrid host (logica_b's need of
; a platform call; the C64's own belongs in c64/plataforma/).
;   plat_aleatorio     -> A = a random byte (the CPC's LD A,R at 518Ah, obj_read_manuscript)   (nothing else)
; The checked build reads a mirror byte the host fills with the value the Z80's LD A,R reads.
        .export plat_aleatorio
PLAT_ALEATORIO = $07BF

.segment "CODE"

.proc plat_aleatorio
        lda     PLAT_ALEATORIO
        rts
.endproc
