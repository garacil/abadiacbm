; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; iso_select_room at 2855 (64K)   PC: 27C8   CPC 6128: 2D00   called 102 times by 2017
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2855 * ld (0290eh),a
2858 * ld hl,06100h
285B * and a
285C * jr z,$+19
285E * di
285F * ld bc,07fc7h
2862 * ld b,a
2863 * ld a,(hl)
2864 * add a,l
2865 * ld l,a
2866 * adc a,h
2867 * sub l
2868 * ld h,a
2869 * djnz $-6
286B * ld bc,07fc0h
286E * ei
286F * ld (011dah),hl
2872 * ret
