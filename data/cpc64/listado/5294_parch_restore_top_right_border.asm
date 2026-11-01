; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; parch_restore_top_right_border at 5294 (64K)   PC: 07C8   CPC 6128: 663E   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
5294   cp b
5295   ld b,b
5296   add a,b
5297   ld hl,(08040h)
529A   dec a
529B   jr nz,$+8
529D   rst 10h
529E   cp a
529F   cp a
52A0   ld b,b
52A1   jr nz,$+40
52A3   rst 10h
52A4   cp a
52A5   cp a
52A6   djnz $+40
52A8 * rst 8
52A9   sbc a,d
52AA   ld (hl),d
52AB   dec a
52AC * jr nz,$+7
52AE   rst 10h
52AF   ret nz
52B0   ret nz
52B1   ld (bc),a
52B2   ld h,0c9h
