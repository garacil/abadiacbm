; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; sys_key_pressed at 2E7D (64K)   PC: 2F30   CPC 6128: 3472   called 130447 times by 2426 2430 2FBB 31E1 507F
; '*' = executed in the exploration sessions; the listing runs to the next known entry
2E7D * push hl
2E7E * push de
2E7F * ld de,02df2h
2E82 * call f_2E42
2E85 * push af
2E86 * ld a,(de)
2E87 * or (hl)
2E88 * ld (de),a
2E89 * pop af
2E8A * pop de
2E8B * pop hl
2E8C * ret
