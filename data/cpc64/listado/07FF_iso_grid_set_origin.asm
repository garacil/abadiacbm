; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; iso_grid_set_origin at 07FF (64K)   PC: 100B   CPC 6128: 0B8F   called 12456 times by 07F2 2880
; '*' = executed in the exploration sessions; the listing runs to the next known entry
07FF * ld a,(iy+002h)
0802 * and 0f0h
0804 * sub 004h
0806 * ld (022feh),a
0809 * ld a,(iy+003h)
080C * and 0f0h
080E * sub 004h
0810 * ld (022f2h),a
0813 * ld a,(iy+004h)
0816 * call iso_floor_base
0819 * ld a,b
081A * ld (0290bh),a
081D * ret
