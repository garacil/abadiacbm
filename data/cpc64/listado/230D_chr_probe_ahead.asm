; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; chr_probe_ahead at 230D (64K)   PC: 21DC   CPC 6128: 27B8   called 66731 times by 243E 27FB 41C2 4268
; '*' = executed in the exploration sessions; the listing runs to the next known entry
230D * ld e,a
230E * ld a,(iy+004h)
2311 * call iso_floor_base
2314 * ld a,(0290bh)
2317 * cp b
2318 * scf
2319 * ld a,e
231A * ret nz
231B * ld a,(iy+004h)
231E * sub b
231F * ld b,e
