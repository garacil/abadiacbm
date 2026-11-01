; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_mark_hbuf at 2444 (64K)   PC: 2315   CPC 6128: 28EF   called 287505 times by 0587 0590 05B5 05BF 08B4 08E1
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2444 * call iso_grid_cell_of
2447 * ret c
2448 * ld a,(ix+000h)
244B * and 00fh
244D * or c
244E * ld (ix+000h),a
2451 * bit 7,(iy+005h)
2455 * ret nz
2456 * ld a,(ix-001h)
2459 * and 00fh
245B * or c
245C * ld (ix-001h),a
245F * ld a,(ix-018h)
2462 * and 00fh
2464 * or c
2465 * ld (ix-018h),a
2468 * ld a,(ix-019h)
246B * and 00fh
246D * or c
246E * ld (ix-019h),a
2471 * ret
