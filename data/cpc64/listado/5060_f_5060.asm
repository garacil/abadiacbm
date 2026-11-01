; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_5060 at 5060 (64K)   PC: -   CPC 6128: -   called 42 times by 50D3
; '*' = executed in the exploration sessions; the listing runs to the next known entry
5060 * ld a,(028d1h)
5063 * dec a
5064 * ld b,a
5065 * add a,a
5066 * ld c,a
5067 * add a,a
5068 * add a,b
5069 * add a,c
506A * ld hl,04ad0h
506D * call util_add_bx_al
5070 * ld a,(028d2h)
5073 * call util_add_bx_al
5076 * ld h,(hl)
5077 * ld l,000h
5079 * ld (028d7h),hl
507C * ret
