; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; util_read_indirect_pair at 0BEC (64K)   PC: 1486   CPC 6128: 0F7C   called 674000 times by 0B60 0BE0
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0BEC * ld a,(hl)
0BED * inc hl
0BEE * ld b,(hl)
0BEF * inc hl
0BF0 * push hl
0BF1 * ld l,a
0BF2 * ld h,b
0BF3 * ld a,(hl)
0BF4 * inc hl
0BF5 * ld b,(hl)
0BF6 * pop hl
0BF7 * ret
