; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_cmd_write_bits at 0959 (64K)   PC: 118E   CPC 6128: 0CE9   called 31743 times by 06E0 4327 434B 4375
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0959 * ld a,(iy+009h)
095C * cp 008h
095E * jr nz,$+25
0960 * ld (iy+009h),000h
0964 * ld a,(iy+00bh)
0967 * add a,(iy+00ch)
096A * ld e,a
096B * adc a,(iy+00dh)
096E * sub e
096F * ld d,a
0970 * inc (iy+00bh)
0973 * ld a,(iy+00ah)
0976 * ld (de),a
0977 * add hl,hl
0978 * rl (iy+00ah)
097C * inc (iy+009h)
097F * dec b
0980 * jr nz,$-39
0982 * ret
