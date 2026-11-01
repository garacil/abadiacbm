; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_5035 at 5035 (64K)   PC: -   CPC 6128: -   called 21 times by 216E
; '*' = executed in the exploration sessions; the listing runs to the next known entry
5035 * ld a,(028d2h)
5038 * dec a
5039 * cp 005h
503B * push af
503C * call c,f_3A88
503F * pop af
5040 * push af
5041 * call nc,03a8dh
5044 * ld a,(028d1h)
5047 * call f_50AF
504A * ld hl,04b12h
504D * pop af
504E * ld (028d2h),a
5051 * inc a
5052 * ld b,a
5053 * add a,a
5054 * ld c,a
5055 * add a,a
5056 * add a,c
5057 * add a,b
5058 * call util_add_bx_al
505B * ld (028d3h),hl
505E * jr $+54
