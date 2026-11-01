; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; obj_door_flip_graphics at 0AD6 (64K)   PC: 1332   CPC 6128: 0E66   called 26960 times by 21D0
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0AD6 * ld a,(02900h)
0AD9 * ld c,a
0ADA * ld a,(028c9h)
0ADD * xor c
0ADE * ret z
0ADF * ld a,c
0AE0 * ld (028c9h),a
0AE3 * ld bc,02806h
0AE6 * ld hl,0aa49h
0AE9 * jp spr_flip_graphics_h
