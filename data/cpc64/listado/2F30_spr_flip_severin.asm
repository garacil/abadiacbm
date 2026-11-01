; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; spr_flip_severin at 2F30 (64K)   PC: 3000   CPC 6128: 352B   called 73 times by 25AD
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2F30 * ld a,(02bd8h)
2F33 * xor 001h
2F35 * ld (02bd8h),a
2F38 * ld hl,(02beeh)
2F3B * ld bc,01405h
2F3E * jr $+25
