; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_load_params at 274B (64K)   PC: 2681   CPC 6128: 2BF6   called 163900 times by 2472
; '*' = executed in the exploration sessions; the listing runs to the next known entry
274B * ld b,005h
274D * ld ix,02741h
2751 * ld e,(ix+000h)
2754 * ld d,(ix+001h)
2757 * inc ix
2759 * inc ix
275B * ld a,(hl)
275C * ld (de),a
275D * inc hl
275E * inc de
275F * ld a,(hl)
2760 * ld (de),a
2761 * inc hl
2762 * djnz $-17
2764 * ret
