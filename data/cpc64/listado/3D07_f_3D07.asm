; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_3D07 at 3D07 (64K)   PC: -   CPC 6128: -   called 21 times by 5A5B
; '*' = executed in the exploration sessions; the listing runs to the next known entry
3D07 * pop hl
3D08 * ld a,(hl)
3D09 * inc hl
3D0A * ld (037e0h),a
3D0D * push hl
3D0E * ret
3D0F   ld a,b
3D10   dec a
3D11   ld (037dch),a
3D14   ret
