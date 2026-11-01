; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_3D15 at 3D15 (64K)   PC: -   CPC 6128: -   called 26960 times by 21A3
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3D15 * call f_3CC5
3D18 * ld hl,03d30h
3D1B * ld a,(037dch)
3D1E * add a,a
3D1F * call util_add_bx_al
3D22 * ld e,(hl)
3D23 * inc hl
3D24 * ld d,(hl)
3D25 * ld (028d9h),de
3D29 * ret
3D2A   ld sp,03938h
3D2D   ld b,c
3D2E   ld b,b
3D2F   ld (de),a
3D30   add a,a
3D31   dec hl
3D32   sub (hl)
3D33   dec hl
3D34   and l
3D35   dec hl
3D36   or h
3D37   dec hl
3D38   jp 0d22bh
3D3B   dec hl
