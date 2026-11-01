; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_3AAF at 3AAF (64K)   PC: -   CPC 6128: -   called 21 times by 5AFC
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3AAF * xor a
3AB0 * push ix
3AB2 * ld e,0ffh
3AB4 * call f_3AC3
3AB7 * ld e,000h
3AB9 * call f_3AC3
3ABC * pop ix
3ABE * xor a
3ABF * ld (028c6h),a
3AC2 * ret
