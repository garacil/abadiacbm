; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; iso_op_mirror at 1D9B (64K)   PC: 2BEC   CPC 6128: 218D   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
1D9B * ld a,02dh
1D9D * ld (01c60h),a
1DA0 * ld (01d06h),a
1DA3 * dec a
1DA4 * ld (01c66h),a
1DA7 * ld a,001h
1DA9 * ld (01e3eh),a
1DAC * jp 01c2ch
