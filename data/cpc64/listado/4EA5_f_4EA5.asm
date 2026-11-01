; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_4EA5 at 4EA5 (64K)   PC: -   CPC 6128: -   called 161717 times by 4C5A 4DEA
; '*' = executed in the exploration sessions; the listing runs to the next known entry
4EA5 * ld e,(ix+001h)
4EA8 * ld d,(ix+002h)
4EAB * dec de
4EAC * ld a,(de)
4EAD * ld hl,023a8h
4EB0 * call f_22E7
4EB3 * inc de
4EB4 * ld a,(de)
4EB5 * add a,(hl)
4EB6 * add a,(hl)
4EB7 * ld (04cc4h),a
4EBA * ld c,a
4EBB * inc de
4EBC * inc hl
4EBD * ld a,(de)
4EBE * add a,(hl)
4EBF * add a,(hl)
4EC0 * ld (04cc9h),a
4EC3 * ld b,a
4EC4 * inc de
4EC5 * ld a,(de)
4EC6 * ld (04cbdh),a
4EC9 * ret
