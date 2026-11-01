; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; iso_rotate_cam2 at 20AF (64K)   PC: 1EB8   CPC 6128: 248B   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
20AF   ld a,028h
20B1   sub h
20B2   ld h,a
20B3   ld a,028h
20B5   sub l
20B6   ld l,a
20B7   ret
