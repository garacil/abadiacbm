; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_0EE5 at 0EE5 (64K)   PC: -   CPC 6128: -   called 751230 times by 0E71
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0EE5 * dec (ix+012h)
0EE8 * ret nz
0EE9 * dec (ix+00dh)
0EEC * call z,f_0F0B
0EEF * set 5,(ix+00eh)
0EF3 * ld a,(ix+010h)
0EF6 * ld (ix+012h),a
0EF9 * bit 4,(ix+00eh)
0EFD * ret nz
0EFE * ld a,(ix+007h)
0F01 * add a,(ix+014h)
0F04 * and 00fh
0F06 * ld (ix+007h),a
0F09 * ld c,a
0F0A * ret
