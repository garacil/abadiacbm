; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_3558 at 3558 (64K)   PC: -   CPC 6128: -   called 547936 times by 16C7 35BC 367D 36E6 3B33 4B6A
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3558 * ld a,h
3559 * add a,008h
355B * ld h,a
355C * ret nc
355D * ld a,040h
355F * add a,l
3560 * ld l,a
3561 * adc a,h
3562 * sub l
3563 * or 0c0h
3565 * ld h,a
3566 * ret
3567   ret
