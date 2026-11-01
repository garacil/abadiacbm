; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; f_510C at 510C (64K)   PC: -   CPC 6128: -   called 26973 times by 2191
; '*' = executed in the exploration sessions; the listing runs to the next known entry
510C * push bc
510D * push hl
510E * push de
510F * call f_507D
5112 * call f_3D3C
5115 * ld a,c
5116 * ld (037dah),a
5119 * call f_3D6A
511C * ld a,c
511D * ld (037d9h),a
5120 * pop de
5121 * pop hl
5122 * pop bc
5123 * ret
