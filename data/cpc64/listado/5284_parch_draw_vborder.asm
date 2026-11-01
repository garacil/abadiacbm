; abadia64ks - La Abadia del Crimen (the Amstrad CPC 64 KiB tape version) for the Commodore 64 and other machines
;
; Copyright (C) 2016-2026 Germán Luis Aracil Boned <garacilb@gmail.com> (Spain)
;
; I made this file from the original game, La Abadía del Crimen (Opera Soft): what it holds of the original (its
; code, data, music or texts) belongs to the original and is not under my licence.  The rest is free software:
; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the
; Free Software Foundation, either version 3 of the License, or (at your option) any later version, WITHOUT ANY
; WARRANTY (see COPYING or <https://www.gnu.org/licenses/>).
; parch_draw_vborder at 5284 (64K)   PC: 07A8   CPC 6128: 662E   called 0 times by -
; '*' = executed in the exploration sessions; the listing runs to the next known entry
5284   and h
5285   ld b,b
5286   jr nz,$+44
5288   ld b,b
5289   jr nz,$+63
528B   jr nz,$+8
528D   rst 10h
528E   cp a
528F   cp a
5290   ld b,b
5291   add a,b
5292   ld h,0cfh
