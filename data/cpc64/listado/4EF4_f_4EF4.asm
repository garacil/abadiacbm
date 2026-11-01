; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_4EF4 at 4EF4 (64K)   PC: -   CPC 6128: -   called 26960 times by 4EE0
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4EF4 * push bc
4EF5 * call f_4F03
4EF8 * pop bc
4EF9 * ld a,l
4EFA * ld (bc),a
4EFB * cp 0feh
4EFD * ret nz
4EFE * res 7,(ix+00bh)
4F02 * ret
