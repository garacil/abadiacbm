; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_4B57 at 4B57 (64K)   PC: -   CPC 6128: -   called 306 times by 2175 4B79
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4B57 * ld b,008h
4B59 * ld hl,0e510h
4B5C * ld c,01fh
4B5E * push bc
4B5F * push hl
4B60 * ld e,l
4B61 * ld d,h
4B62 * inc de
4B63 * ld (hl),0ffh
4B65 * ld b,000h
4B67 * ldir
4B69 * pop hl
4B6A * call f_3558
4B6D * pop bc
4B6E * djnz $-16
4B70 * ret
