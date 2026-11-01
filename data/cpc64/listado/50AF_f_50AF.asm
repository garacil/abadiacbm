; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_50AF at 50AF (64K)   PC: -   CPC 6128: -   called 21 times by 5047
; '*' = executed in the exploration sessions; the listing runs to the next known entry
50AF * ld (028d1h),a
50B2 * dec a
50B3 * ld c,a
50B4 * add a,a
50B5 * add a,c
50B6 * ld hl,04afdh
50B9 * call util_add_bx_al
50BC * ex de,hl
50BD * ld hl,0ed09h
50C0 * call f_50D9
50C3 * call f_50D9
50C6 * call f_50D9
50C9 * ld a,000h
50CB * ld (028d2h),a
50CE * ld a,009h
50D0 * ld (028f6h),a
50D3 * call f_5060
50D6 * ret
50D7   rst 38h
50D8   rst 38h
