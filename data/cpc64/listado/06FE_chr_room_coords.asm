; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_room_coords at 06FE (64K)   PC: 0EE3   CPC 6128: 0A8E   called 3583 times by 0737
; '*' = executed in the exploration sessions; the listing runs to the next known entry
06FE * ld a,(iy+002h)
0701 * rrca
0702 * rrca
0703 * rrca
0704 * rrca
0705 * and 00fh
0707 * ld l,a
0708 * ld a,(iy+003h)
070B * rrca
070C * rrca
070D * rrca
070E * rrca
070F * and 00fh
0711 * ld h,a
0712 * ret
