; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; obj_open_left_wing_doors at 2FAD (64K)   PC: 30DB   CPC 6128: 3585   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2FAD   ld hl,0e002h
2FB0   ld (02b4eh),hl
2FB3   ld h,0c0h
2FB5   ld (02b53h),hl
2FB8   ret
