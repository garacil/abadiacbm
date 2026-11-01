; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; spr_project_entity at 0ABC (64K)   PC: 1314   CPC 6128: 0E4C   called 190360 times by 09B4 09F4
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0ABC * ld a,0c9h
0ABE * ld (02684h),a
0AC1 * call spr_project_entity_inner
0AC4 * ld c,a
0AC5 * xor a
0AC6 * ld (02684h),a
0AC9 * ret
