; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; obj_object_sprite_update at 0A2B (64K)   PC: 126E   CPC 6128: 0DBB   called 10 times by 09B9
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0A2B * bit 7,(iy+000h)
0A2F * ret nz
0A30 * set 7,c
0A32 * ld (ix+000h),c
0A35 * ld a,h
0A36 * sub 008h
0A38 * ld (ix+002h),a
0A3B * ld a,l
0A3C * sub 002h
0A3E * ld (ix+001h),a
0A41 * ret
