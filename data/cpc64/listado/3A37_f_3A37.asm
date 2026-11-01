; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_3A37 at 3A37 (64K)   PC: -   CPC 6128: -   called 26960 times by 21A0
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3A37 * ld a,(028f3h)
3A3A * ld (028f2h),a
3A3D * ld hl,(028d9h)
3A40 * bit 0,(hl)
3A42 * ret nz
3A43 * ld a,(037e7h)
3A46 * and a
3A47 * jp z,05a4fh
3A4A   ld a,(028f2h)
3A4D   and a
3A4E   ret nz
3A4F   ld (037e7h),a
3A52   call 05094h
3A55   jp 05a4fh
3A58   call f_4B7C
3A5B   nop
3A5C   ret
