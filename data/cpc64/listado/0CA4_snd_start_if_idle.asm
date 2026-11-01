; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; snd_start_if_idle at 0CA4 (64K)   PC: 0543   CPC 6128: 1034   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
0CA4 * ld ix,00c40h
0CA8 * ld a,(ix+00eh)
0CAB * and a
0CAC * ret nz
0CAD   jr $+18
0CAF * ld ix,00c10h
0CB3 * jr $+12
0CB5 * ld ix,00c28h
0CB9 * jr $+6
0CBB * ld ix,00c40h
