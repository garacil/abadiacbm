; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_3994 at 3994 (64K)   PC: -   CPC 6128: -   called 5099644 times by 3926 3963
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3994 * ld a,(hl)
3995 * inc hl
3996 * cp 040h
3998 * jr nz,$+5
399A * ld c,(hl)
399B * inc hl
399C * ret
399D * cp 080h
399F * ld c,a
39A0 * ret c
39A1 * push hl
39A2 * call f_3910
39A5 * ld c,(hl)
39A6 * pop hl
39A7 * ret
39A8 * ld a,001h
39AA * ld (037e9h),a
39AD * ret
