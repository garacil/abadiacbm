; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_2E42 at 2E42 (64K)   PC: -   CPC 6128: -   called 346854 times by 2E82 2E92
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2E42 * ld (02e6ah),de
2E46 * ld hl,02e2ch
2E49 * ld (hl),a
2E4A * inc hl
2E4B * inc hl
2E4C * cp 008h
2E4E * jr z,$+24
2E50 * ld hl,02e32h
2E53 * cp 02fh
2E55 * jr z,$+17
2E57 * ld hl,02e2ch
2E5A * cp 003h
2E5C * jr nc,$+10
2E5E * ld hl,02e36h
2E61 * add a,a
2E62 * add a,a
2E63 * call util_add_bx_al
2E66 * ld a,(hl)
2E67 * inc hl
2E68 * push hl
2E69 * ld de,00000h
2E6C * call sys_test_key
2E6F * ex (sp),hl
2E70 * jr nz,$+11
2E72 * ld a,(hl)
2E73 * cp 0ffh
2E75 * jr nc,$+5
2E77 * pop de
2E78 * jr $-18
2E7A * xor a
2E7B * pop hl
2E7C * ret
