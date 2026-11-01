; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_438F at 438F (64K)   PC: -   CPC 6128: -   called 3583 times by 073D
; '*' = executed in the exploration sessions; the listing runs to the next known entry
438F * ld hl,(02905h)
4392 * call f_441E
4395 * set 6,(ix+000h)
4399 * ld (02901h),sp
439D * ld sp,0877eh
43A0 * ld de,(02903h)
43A4 * push de
43A5 * ex de,hl
43A6 * call f_441E
43A9 * set 7,(ix+000h)
43AD * ld hl,0ffffh
43B0 * push hl
43B1 * ld hl,0877eh
43B4 * dec hl
43B5 * ld d,(hl)
43B6 * dec hl
43B7 * ld e,(hl)
43B8 * ld a,e
43B9 * and 080h
43BB * jr z,$+15
43BD * xor a
43BE * ld b,h
43BF * ld c,l
43C0 * sbc hl,sp
43C2 * ld l,c
43C3 * ld h,b
43C4 * jp z,040deh
