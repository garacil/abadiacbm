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

; abadia64ks, 6502 code of the game: the platform's state in the build checked by the hybrid host
; (plataforma_prueba.s writes these mirrors; juego/m6502/sombra6502.c fills them from the CPC hardware state
; before a call and compares them after it).  In the free variable area $079D-$07FF of the map.
PLAT_TECLADO = $07C0                    ; 10 keyboard matrix rows, active low (input)
PLAT_AY      = $07CA                    ; 16 AY registers as written
PLAT_TINTAS  = $07DA                    ; 17 inks (hardware colour numbers), 16 = the border
PLAT_CRTC    = $07EB                    ; CRTC registers 0-15
PLAT_MODO    = $07FB                    ; screen mode
PLAT_IFF     = $07FC                    ; the Z80's interrupt flag: 0 DI, 1 EI
