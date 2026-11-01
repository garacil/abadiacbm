; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; ai_update_adso at 04EB (64K)   PC: 0C72   CPC 6128: 087B   called 26960 times by 2226
; '*' = executed in the exploration sessions; the listing runs to the next known entry
04EB * ld iy,02b96h
04EF * ld ix,03861h
04F3 * xor a
04F4 * ld (037e9h),a
04F7 * call f_58F7
04FA * ld c,03ch
04FC * call f_39F1
04FF * ld hl,0270dh
0502 * call chr_update
0505 * ld ix,03861h
0509 * ld a,(03860h)
050C * cp 0ffh
050E * jp nz,003ach
0511 * ld a,(037dch)
0514 * cp 002h
0516 * ret nc
0517 * bit 7,(iy+009h)
051B * jr nz,$+36
051D * ld hl,028fbh
0520 * ld a,(02912h)
0523 * cp 0ffh
0525 * ret z
0526 * ld a,(hl)
0527 * inc a
0528 * ld (hl),a
0529 * cp 00ah
052B * ret c
052C * xor a
052D * ld (hl),a
