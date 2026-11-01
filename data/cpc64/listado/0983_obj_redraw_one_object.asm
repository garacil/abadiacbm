; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; obj_redraw_one_object at 0983 (64K)   PC: 11C1   CPC 6128: 0D13   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0983 * ld a,0c9h
0985 * ld (009d4h),a
0988 * ld hl,00a2bh
098B * call obj_for_each_visible
098E * xor a
098F * ld (009d4h),a
0992 * ret
