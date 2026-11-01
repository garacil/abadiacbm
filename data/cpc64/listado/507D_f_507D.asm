; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_507D at 507D (64K)   PC: -   CPC 6128: -   called 26973 times by 510F
; '*' = executed in the exploration sessions; the listing runs to the next known entry
507D * ld a,006h
507F * call sys_key_pressed
5082 * call f_3D05
5085 * jr nz,$+15
5087 * ld hl,(028d7h)
508A * ld a,h
508B * or l
508C * ret z
508D   dec hl
508E   ld (028d7h),hl
5091   ld a,h
5092   or l
5093   ret nz
5094 * ld a,(028d2h)
5097 * inc a
5098 * cp 007h
509A * jr nz,$+49
509C   ld hl,04b12h
509F   ld (028d3h),hl
50A2   ld a,(028d1h)
50A5   inc a
50A6   ld (028d1h),a
50A9   cp 008h
50AB   jr c,$+7
50AD   ld a,001h
